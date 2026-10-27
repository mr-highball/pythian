(*
MIT License

Copyright (c) 2026 mr-highball

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
*)

unit pythian.wfc.pitch;

{$mode delphi}
{$H+}

interface

uses
  pythian.progress,
  pythian.pitch,
  pythian.pitch.track,
  wfc_sequence;

type
  TPitchTracks = array of TPitchNotes;
  TMeasuredPitchTracks = array of TPitchTrack;
  TTimedPitchTracks = array of TTimedPitchSpans;
  TPitchDurationCell = record
    Kind: TPitchSpanKind;
    Note: Integer;
    Duration: Integer; { Caller-defined common units: PPQ ticks in saved styles, hops in raw tracks. }
  end;
  TPitchRhythmPatterns = array of String;
  TPitchRhythmCell = record
    Note: Integer;
    Level: Integer; { 0 = no onset, 1..4 = intensity band, 5 = onset without intensity. }
  end;

function PitchNoteToken(const ANote: Integer): UTF8String;
function PitchDurationToken(const ACell: TPitchDurationCell): UTF8String;
function DecodePitchDurationToken(const AToken: UTF8String): TPitchDurationCell;
{ Progress reports raw visited cells/spans separately from weighted sample
  observations. Totals are unknown until the corresponding pass completes.
  Generic WFC learning remains synchronous. }
function LearnPitchDurationModel(const ATracks: TMeasuredPitchTracks;
  const AWeights: array of Integer; const AOrder: Integer = 2;
  const AProgress: TWorkProgressCallback = nil): TWfcSequenceModel; overload;
function LearnPitchDurationModel(const ATracks: TTimedPitchTracks;
  const AWeights: array of Integer; const AOrder: Integer = 2;
  const AProgress: TWorkProgressCallback = nil): TWfcSequenceModel; overload;
function DecodePitchNoteToken(const AToken: UTF8String): Integer;
function PitchRhythmToken(const ANote, ALevel: Integer): UTF8String;
function DecodePitchRhythmToken(const AToken: UTF8String): TPitchRhythmCell;
function LearnPitchRhythmModel(const ATracks: TPitchTracks;
  const APatterns: TPitchRhythmPatterns; const AWeights: array of Integer;
  const AOrder: Integer = 2; const AProgress: TWorkProgressCallback = nil): TWfcSequenceModel;
{ Actual WFC learning over admitted pitch runs. Unknown cells split samples;
  recordings and repeated weighted samples never join across boundaries.
  Weights 0..64 repeat complete runs. They are not output quotas. }
function LearnPitchModel(const ATracks: TPitchTracks; const AWeights: array of Integer;
  const AOrder: Integer = 2; const AProgress: TWorkProgressCallback = nil): TWfcSequenceModel;

implementation

uses
  SysUtils,
  pythian.audio,
  wfc_model,
  wfc_sequence_learn;

const
  PitchDurationPrefix = 'pythian.pitch.span.v1.';
  PitchPrefix = 'pythian.pitch.midi.v1.';
  PitchRhythmPrefix = 'pythian.pitch.rhythm.v1.';

function PitchDurationToken(const ACell: TPitchDurationCell): UTF8String;
begin
  if not (ACell.Kind in [pskPitch, pskSilence, pskUnknown]) or
    (ACell.Duration < 1) or (ACell.Duration > 1048576) then
  begin
    raise EAudio.Create('Pitch duration kind or extent exceeds bounds');
  end;
  if ACell.Kind = pskPitch then
  begin
    PitchNoteToken(ACell.Note);
  end
  else if ACell.Note <> -1 then
  begin
    raise EAudio.Create('Silence and unknown spans must not claim a pitch');
  end;
  Result := PitchDurationPrefix + UTF8String(IntToStr(Ord(ACell.Kind)) + '.' +
    IntToStr(ACell.Note) + '.' + IntToStr(ACell.Duration));
end;

function DecodePitchDurationToken(const AToken: UTF8String): TPitchDurationCell;
var
  LSuffix: String;
  LDot: Integer;
  LKind: Integer;
begin
  if Copy(AToken, 1, Length(PitchDurationPrefix)) <> PitchDurationPrefix then
  begin
    raise EAudio.Create('Unknown pitch duration token');
  end;
  LSuffix := String(Copy(AToken, Length(PitchDurationPrefix) + 1, MaxInt));
  LDot := Pos('.', LSuffix);
  if (LDot < 2) or not TryStrToInt(Copy(LSuffix, 1, LDot - 1), LKind) or
    (LKind < Ord(Low(TPitchSpanKind))) or (LKind > Ord(High(TPitchSpanKind))) then
  begin
    raise EAudio.Create('Invalid pitch duration kind');
  end;
  Result.Kind := TPitchSpanKind(LKind);
  Delete(LSuffix, 1, LDot);
  LDot := Pos('.', LSuffix);
  if (LDot < 2) or not TryStrToInt(Copy(LSuffix, 1, LDot - 1), Result.Note) or
    not TryStrToInt(Copy(LSuffix, LDot + 1, MaxInt), Result.Duration) then
  begin
    raise EAudio.Create('Invalid pitch duration fields');
  end;
  if PitchDurationToken(Result) <> AToken then
  begin
    raise EAudio.Create('Noncanonical pitch duration token');
  end;
end;

function LearnPitchDurationModel(const ATracks: TMeasuredPitchTracks;
  const AWeights: array of Integer; const AOrder: Integer;
  const AProgress: TWorkProgressCallback): TWfcSequenceModel;
var
  LTracks: TTimedPitchTracks;
  LSpans: TPitchSpans;
  LReference: TPitchTrack;
  LSource: Integer;
  LIndex: Integer;
  LDone: Int64;
begin
  if (Length(ATracks) < 1) or (Length(ATracks) > 32) or
    (Length(AWeights) <> Length(ATracks)) then
  begin
    raise EAudio.Create('Pitch duration corpus requires 1..32 weighted sources');
  end;
  LReference := nil;
  LDone := 0;
  ReportWork(AProgress, 'pitch_measured_spans', wuItems, 0, 0);
  SetLength(LTracks, Length(ATracks));
  for LSource := 0 to High(ATracks) do
  begin
    if ATracks[LSource] = nil then
    begin
      raise EAudio.Create('Pitch duration source is missing');
    end;
    if AWeights[LSource] <> 0 then
    begin
      if LReference = nil then
      begin
        LReference := ATracks[LSource];
      end;
      if Int64(LReference.Options.HopFrames) * ATracks[LSource].SampleRate <>
        Int64(ATracks[LSource].Options.HopFrames) * LReference.SampleRate then
      begin
        raise EAudio.Create('Pitch duration sources must share an exact hop timebase');
      end;
    end;
    LSpans := ATracks[LSource].CopySpans;
    SetLength(LTracks[LSource], Length(LSpans));
    for LIndex := 0 to High(LSpans) do
    begin
      LTracks[LSource][LIndex].Kind := LSpans[LIndex].Kind;
      LTracks[LSource][LIndex].Note := LSpans[LIndex].Note;
      LTracks[LSource][LIndex].StartTick := LSpans[LIndex].FirstWindow;
      LTracks[LSource][LIndex].EndTick := LSpans[LIndex].FirstWindow + LSpans[LIndex].WindowCount;
      Inc(LDone);
      if LDone mod 256 = 0 then
      begin
        ReportWork(AProgress, 'pitch_measured_spans', wuItems, LDone, 0);
      end;
    end;
  end;
  ReportWork(AProgress, 'pitch_measured_spans', wuItems, LDone, LDone);
  Result := LearnPitchDurationModel(LTracks, AWeights, AOrder, AProgress);
end;

function LearnPitchDurationModel(const ATracks: TTimedPitchTracks;
  const AWeights: array of Integer; const AOrder: Integer;
  const AProgress: TWorkProgressCallback): TWfcSequenceModel;
var
  LSamples: TWfcSequenceSamples;
  LSpans: TTimedPitchSpans;
  LTokens: TWfcModelTokens;
  LCell: TPitchDurationCell;
  LSource: Integer;
  LIndex: Integer;
  LRepeat: Integer;
  LCount: Integer;
  LWork: Int64;
  LDone: Int64;
  LWeighted: Int64;
begin
  if (Length(ATracks) < 1) or (Length(ATracks) > 32) or
    (Length(AWeights) <> Length(ATracks)) or (AOrder < 1) or (AOrder > 4) then
  begin
    raise EAudio.Create('Pitch duration corpus requires 1..32 sources and order 1..4');
  end;
  LCount := 0;
  LWork := 0;
  for LSource := 0 to High(ATracks) do
  begin
    if (ATracks[LSource] = nil) or (AWeights[LSource] < 0) or (AWeights[LSource] > 64) then
    begin
      raise EAudio.Create('Pitch duration source or weight is invalid');
    end;
    if AWeights[LSource] = 0 then
    begin
      Continue;
    end;
    Inc(LCount, AWeights[LSource]);
    Inc(LWork, Int64(Length(ATracks[LSource])) * AWeights[LSource]);
  end;
  if (LCount < 1) or (LCount > WFC_SEQUENCE_MAX_SAMPLE_COUNT) or (LWork > 65536) then
  begin
    raise EAudio.Create('Pitch duration corpus exceeds weighted observation bounds');
  end;
  SetLength(LSamples, LCount);
  LCount := 0;
  LDone := 0;
  LWeighted := 0;
  ReportWork(AProgress, 'pitch_duration_spans', wuItems, 0, 0);
  ReportWork(AProgress, 'pitch_duration_weighted', wuObservations, 0, 0);
  for LSource := 0 to High(ATracks) do
  begin
    if AWeights[LSource] = 0 then
    begin
      Continue;
    end;
    LSpans := ATracks[LSource];
    SetLength(LTokens, Length(LSpans));
    for LIndex := 0 to High(LSpans) do
    begin
      LCell.Kind := LSpans[LIndex].Kind;
      LCell.Note := LSpans[LIndex].Note;
      if (LSpans[LIndex].StartTick < 0) or
        (LSpans[LIndex].EndTick <= LSpans[LIndex].StartTick) or
        ((LIndex > 0) and (LSpans[LIndex].StartTick <> LSpans[LIndex - 1].EndTick)) then
      begin
        raise EAudio.Create('Duration source spans require contiguous positive tick intervals');
      end;
      LCell.Duration := LSpans[LIndex].EndTick - LSpans[LIndex].StartTick;
      LTokens[LIndex] := PitchDurationToken(LCell);
      Inc(LDone);
      if LDone mod 256 = 0 then
      begin
        ReportWork(AProgress, 'pitch_duration_spans', wuItems, LDone, 0);
      end;
    end;
    for LRepeat := 1 to AWeights[LSource] do
    begin
      LSamples[LCount] := MakeWfcSequenceSample(LTokens);
      Inc(LCount);
      if (LWeighted div 256) <> ((LWeighted + Length(LTokens)) div 256) then
      begin
        Inc(LWeighted, Length(LTokens));
        ReportWork(AProgress, 'pitch_duration_weighted', wuObservations, LWeighted, 0);
      end
      else
      begin
        Inc(LWeighted, Length(LTokens));
      end;
    end;
  end;
  ReportWork(AProgress, 'pitch_duration_spans', wuItems, LDone, LDone);
  ReportWork(AProgress, 'pitch_duration_weighted', wuObservations, LWeighted, LWeighted);
  Result := LearnSequenceModelCorpus(LSamples, AOrder);
end;

function PitchNoteToken(const ANote: Integer): UTF8String;
begin
  if (ANote < 0) or (ANote > 127) then
  begin
    raise EAudio.Create('Pitch token requires an admitted MIDI note');
  end;
  Result := PitchPrefix + UTF8String(IntToStr(ANote));
end;

function DecodePitchNoteToken(const AToken: UTF8String): Integer;
var
  LNote: Integer;
begin
  if (Copy(AToken, 1, Length(PitchPrefix)) <> PitchPrefix) or
    not TryStrToInt(String(Copy(AToken, Length(PitchPrefix) + 1, MaxInt)), LNote) then
  begin
    raise EAudio.Create('Invalid pitch note token');
  end;
  if PitchNoteToken(LNote) <> AToken then
  begin
    raise EAudio.Create('Noncanonical pitch note token');
  end;
  Result := LNote;
end;

function PitchRhythmToken(const ANote, ALevel: Integer): UTF8String;
begin
  PitchNoteToken(ANote);
  if not (ALevel in [0..5]) then
  begin
    raise EAudio.Create('Pitch/rhythm level must be 0..5');
  end;
  Result := PitchRhythmPrefix + UTF8String(IntToStr(ANote) + '.' + IntToStr(ALevel));
end;

function DecodePitchRhythmToken(const AToken: UTF8String): TPitchRhythmCell;
var
  LSuffix: String;
  LDot: Integer;
begin
  if Copy(AToken, 1, Length(PitchRhythmPrefix)) <> PitchRhythmPrefix then
  begin
    raise EAudio.Create('Unknown pitch/rhythm token');
  end;
  LSuffix := String(Copy(AToken, Length(PitchRhythmPrefix) + 1, MaxInt));
  LDot := Pos('.', LSuffix);
  if (LDot < 2) or not TryStrToInt(Copy(LSuffix, 1, LDot - 1), Result.Note) or
    not TryStrToInt(Copy(LSuffix, LDot + 1, MaxInt), Result.Level) then
  begin
    raise EAudio.Create('Invalid pitch/rhythm fields');
  end;
  if PitchRhythmToken(Result.Note, Result.Level) <> AToken then
  begin
    raise EAudio.Create('Noncanonical pitch/rhythm token');
  end;
end;

function LearnPitchCorpus(const ATracks: TPitchTracks; const AWeights: array of Integer;
  const AOrder: Integer; const APatterns: TPitchRhythmPatterns;
  const AProgress: TWorkProgressCallback): TWfcSequenceModel;
var
  LSamples: TWfcSequenceSamples;
  LTokens: TWfcModelTokens;
  LSource: Integer;
  LCell: Integer;
  LStart: Integer;
  LIndex: Integer;
  LRepeat: Integer;
  LSampleCount: Integer;
  LWork: Int64;
  LPaired: Boolean;
  LDone: Int64;
  LTraversed: Int64;
  LWeighted: Int64;
begin
  LPaired := Length(APatterns) > 0;
  if LPaired and (Length(APatterns) <> Length(ATracks)) then
  begin
    raise EAudio.Create('Pitch/rhythm sources must align');
  end;
  if (Length(ATracks) < 1) or (Length(ATracks) > 32) or
    (Length(AWeights) <> Length(ATracks)) or (AOrder < 1) or (AOrder > 4) then
  begin
    raise EAudio.Create('Pitch corpus requires 1..32 weighted sources and order 1..4');
  end;
  LWork := 0;
  LSampleCount := 0;
  LDone := 0;
  ReportWork(AProgress, 'pitch_validate_cells', wuItems, 0, 0);
  for LSource := 0 to High(ATracks) do
  begin
    if LPaired and (Length(APatterns[LSource]) <> Length(ATracks[LSource])) then
    begin
      raise EAudio.Create('Pitch/rhythm cells must align');
    end;
    if (AWeights[LSource] < 0) or (AWeights[LSource] > 64) or
      (Length(ATracks[LSource]) > 65536) then
    begin
      raise EAudio.Create('Pitch source size or weight exceeds bounds');
    end;
    Inc(LWork, Int64(Length(ATracks[LSource])) * AWeights[LSource]);
    if LWork > 65536 then
    begin
      raise EAudio.Create('Weighted pitch corpus exceeds cell budget');
    end;
    for LCell := 0 to High(ATracks[LSource]) do
    begin
      if LPaired and not (APatterns[LSource][LCell + 1] in ['0'..'5']) then
      begin
        raise EAudio.Create('Pitch/rhythm pattern contains an invalid level');
      end;
      if (ATracks[LSource][LCell] < -1) or (ATracks[LSource][LCell] > 127) then
      begin
        raise EAudio.Create('Pitch track must contain MIDI notes or unknown -1');
      end;
      if (ATracks[LSource][LCell] >= 0) and
        ((LCell = 0) or (ATracks[LSource][LCell - 1] < 0)) then
      begin
        Inc(LSampleCount, AWeights[LSource]);
      end;
      Inc(LDone);
      if LDone mod 256 = 0 then
      begin
        ReportWork(AProgress, 'pitch_validate_cells', wuItems, LDone, 0);
      end;
    end;
  end;
  ReportWork(AProgress, 'pitch_validate_cells', wuItems, LDone, LDone);
  if (LSampleCount < 1) or (LSampleCount > WFC_SEQUENCE_MAX_SAMPLE_COUNT) then
  begin
    raise EAudio.Create('Pitch corpus has no admitted runs or too many weighted runs');
  end;
  SetLength(LSamples, LSampleCount);
  LSampleCount := 0;
  LDone := 0;
  LTraversed := 0;
  LWeighted := 0;
  ReportWork(AProgress, 'pitch_encode_cells', wuItems, 0, 0);
  ReportWork(AProgress, 'pitch_scan_cells', wuItems, 0, 0);
  ReportWork(AProgress, 'pitch_weighted_cells', wuObservations, 0, 0);
  for LSource := 0 to High(ATracks) do
  begin
    if AWeights[LSource] = 0 then
    begin
      Continue;
    end;
    LCell := 0;
    while LCell < Length(ATracks[LSource]) do
    begin
      if ATracks[LSource][LCell] < 0 then
      begin
        Inc(LCell);
        Inc(LTraversed);
        if LTraversed mod 256 = 0 then
        begin
          ReportWork(AProgress, 'pitch_scan_cells', wuItems, LTraversed, 0);
        end;
        Continue;
      end;
      LStart := LCell;
      while (LCell < Length(ATracks[LSource])) and (ATracks[LSource][LCell] >= 0) do
      begin
        Inc(LCell);
        Inc(LTraversed);
        if LTraversed mod 256 = 0 then
        begin
          ReportWork(AProgress, 'pitch_scan_cells', wuItems, LTraversed, 0);
        end;
      end;
      SetLength(LTokens, LCell - LStart);
      for LIndex := LStart to LCell - 1 do
      begin
        if LPaired then
        begin
          LTokens[LIndex - LStart] := PitchRhythmToken(ATracks[LSource][LIndex],
            Ord(APatterns[LSource][LIndex + 1]) - Ord('0'));
        end
        else
        begin
          LTokens[LIndex - LStart] := PitchNoteToken(ATracks[LSource][LIndex]);
        end;
        Inc(LDone);
        if LDone mod 256 = 0 then
        begin
          ReportWork(AProgress, 'pitch_encode_cells', wuItems, LDone, 0);
        end;
      end;
      for LRepeat := 1 to AWeights[LSource] do
      begin
        LSamples[LSampleCount] := MakeWfcSequenceSample(LTokens);
        Inc(LSampleCount);
        if (LWeighted div 256) <> ((LWeighted + Length(LTokens)) div 256) then
        begin
          Inc(LWeighted, Length(LTokens));
          ReportWork(AProgress, 'pitch_weighted_cells', wuObservations, LWeighted, 0);
        end
        else
        begin
          Inc(LWeighted, Length(LTokens));
        end;
      end;
    end;
  end;
  ReportWork(AProgress, 'pitch_encode_cells', wuItems, LDone, LDone);
  ReportWork(AProgress, 'pitch_scan_cells', wuItems, LTraversed, LTraversed);
  ReportWork(AProgress, 'pitch_weighted_cells', wuObservations, LWeighted, LWeighted);
  Result := LearnSequenceModelCorpus(LSamples, AOrder);
end;

function LearnPitchModel(const ATracks: TPitchTracks; const AWeights: array of Integer;
  const AOrder: Integer; const AProgress: TWorkProgressCallback): TWfcSequenceModel;
begin
  Result := LearnPitchCorpus(ATracks, AWeights, AOrder, nil, AProgress);
end;

function LearnPitchRhythmModel(const ATracks: TPitchTracks;
  const APatterns: TPitchRhythmPatterns; const AWeights: array of Integer;
  const AOrder: Integer; const AProgress: TWorkProgressCallback): TWfcSequenceModel;
begin
  if Length(APatterns) = 0 then
  begin
    raise EAudio.Create('Pitch/rhythm learning requires aligned source patterns');
  end;
  Result := LearnPitchCorpus(ATracks, AWeights, AOrder, APatterns, AProgress);
end;

end.
