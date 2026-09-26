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
unit pythian.wfc.event.archive;

{$mode delphi}
{$H+}

interface

uses
  pythian.audio, pythian.corpus, pythian.wfc.event.corpus;

const
  WfcEventAttachmentContract = 'pythian.wfc.recorded.events.v1';

{ Saves accepted interval definitions, exact palette centers, admission-policy
  text and actual model in the existing measured-corpus envelope. Source identity
  and all model observations/boundaries are admitted before publication. }
function EncodeRecordedEventCorpus(const ACorpus: TAcousticCorpusData;
  const ALearning: TRecordedEventLearning; const APolicy: UTF8String): TAudioBytes;

{ Caller owns both returned objects. Failure leaves learning=nil and policy empty.
  Loading recomputes interval descriptors and token assignments against saved
  centers, but performs no FFT, clustering, onset tracking or WFC learning.
  Policy describes the caller's prior admission; it is not re-executed here. }
function DecodeRecordedEventCorpus(const ABytes: TAudioBytes;
  out ALearning: TRecordedEventLearning; out APolicy: UTF8String): TAcousticCorpusData;

implementation

uses
  pythian.corpus.archive, pythian.learning, pythian.passage, pythian.wfc.events,
  wfc_sequence, wfc_sequence_text;

const
  EventMagic = $31545645;

type
  TEventCursor = record
    Bytes: TAudioBytes;
    Offset: Integer;
    procedure Need(const ACount: Integer);
    procedure PutNumber(const AValue: Integer);
    function GetNumber: Integer;
    procedure PutReal(const AValue: Double);
    function GetReal: Double;
    procedure PutText(const AValue: UTF8String);
    function GetText(const AMaximumBytes: Integer): UTF8String;
  end;

procedure TEventCursor.Need(const ACount: Integer);
begin
  if (ACount < 0) or (ACount > Length(Bytes) - Offset) then
  begin
    raise EAudio.Create('Recorded event attachment field exceeds byte extent');
  end;
end;

procedure TEventCursor.PutNumber(const AValue: Integer);
var
  I: Integer;
begin
  Need(4);
  if AValue < 0 then
  begin
    raise EAudio.Create('Recorded event attachment requires nonnegative integers');
  end;
  for I := 0 to 3 do
  begin
    Bytes[Offset + I] := (Cardinal(AValue) shr (8 * I)) and $FF;
  end;
  Inc(Offset, 4);
end;

function TEventCursor.GetNumber: Integer;
var
  LBits: Cardinal;
  I: Integer;
begin
  Need(4);
  LBits := 0;
  for I := 0 to 3 do
  begin
    LBits := LBits or (Cardinal(Bytes[Offset + I]) shl (8 * I));
  end;
  Inc(Offset, 4);
  if LBits > High(Integer) then
  begin
    raise EAudio.Create('Recorded event integer exceeds signed range');
  end;
  Result := LBits;
end;

procedure TEventCursor.PutReal(const AValue: Double);
var
  LBits: QWord;
  I: Integer;
begin
  Need(8);
  RequireFinite(AValue, 'Event palette center');
  Move(AValue, LBits, SizeOf(LBits));
  for I := 0 to 7 do
  begin
    Bytes[Offset + I] := (LBits shr (8 * I)) and $FF;
  end;
  Inc(Offset, 8);
end;

function TEventCursor.GetReal: Double;
var
  LBits: QWord;
  I: Integer;
begin
  Need(8);
  LBits := 0;
  for I := 0 to 7 do
  begin
    LBits := LBits or (QWord(Bytes[Offset + I]) shl (8 * I));
  end;
  Inc(Offset, 8);
  if (LBits and QWord($7FF0000000000000)) = QWord($7FF0000000000000) then
  begin
    raise EAudio.Create('Nonfinite recorded event center');
  end;
  Move(LBits, Result, SizeOf(Result));
end;

procedure TEventCursor.PutText(const AValue: UTF8String);
begin
  PutNumber(Length(AValue));
  Need(Length(AValue));
  if AValue <> '' then
  begin
    Move(AValue[1], Bytes[Offset], Length(AValue));
  end;
  Inc(Offset, Length(AValue));
end;

function TEventCursor.GetText(const AMaximumBytes: Integer): UTF8String;
var
  LCount: Integer;
begin
  LCount := GetNumber;
  if LCount > AMaximumBytes then
  begin
    raise EAudio.Create('Recorded event text exceeds its budget');
  end;
  Need(LCount);
  Result := '';
  SetLength(Result, LCount);
  if LCount > 0 then
  begin
    Move(Bytes[Offset], Result[1], LCount);
  end;
  Inc(Offset, LCount);
end;

function EncodeRecordedEventCorpus(const ACorpus: TAcousticCorpusData;
  const ALearning: TRecordedEventLearning; const APolicy: UTF8String): TAudioBytes;
var
  LInputs: TRecordedEventInputs;
  LVerified: TRecordedEventLearning;
  LInfo: TAcousticSourceInfo;
  LExpected: TAcousticSourceInfo;
  LCenters: TAcousticVectors;
  LCursor: TEventCursor;
  LText: String;
  LSize: Int64;
  I: Integer;
  J: Integer;
begin
  if (ACorpus = nil) or (ALearning = nil) then
  begin
    raise EAudio.Create('Recorded event saving requires measured corpus and learning');
  end;
  ValidateCorpusText(APolicy);
  if (APolicy = '') or (ACorpus.SourceCount <> ALearning.SourceCount) then
  begin
    raise EAudio.Create('Recorded event source count or admission policy is missing');
  end;
  for I := 0 to ACorpus.SourceCount - 1 do
  begin
    LInfo := ACorpus.SourceInfoAt(I);
    LExpected := ALearning.SourceInfoAt(I);
    if (LInfo.Sha256 <> LExpected.Sha256) or (LInfo.Name <> LExpected.Name) or
      (LInfo.Provenance <> LExpected.Provenance) or
      (LInfo.SampleRate <> LExpected.SampleRate) or (LInfo.Channels <> LExpected.Channels) or
      (LInfo.FrameCount <> LExpected.FrameCount) then
    begin
      raise EAudio.Create('Recorded event identity differs from measured corpus');
    end;
  end;
  LInputs := ALearning.CopyInputs;
  LCenters := ALearning.Palette.CopyCenters;
  LVerified := TRecordedEventLearning.CreateFromModel(ACorpus, LInputs,
    ALearning.QuantumFrames, LCenters, ALearning.Model);
  LVerified.Free;
  LText := EncodeWfcSequenceText(ALearning.Model);
  LSize := 32 + Length(APolicy) + Length(LText) + Length(LCenters) * 15 * 8;
  for I := 0 to High(LInputs) do
  begin
    Inc(LSize, 12 + Length(LInputs[I].RunIndices) * 12);
  end;
  if LSize > MaximumCorpusAttachmentBytes then
  begin
    raise EAudio.Create('Recorded event attachment exceeds byte budget');
  end;
  LCursor := Default(TEventCursor);
  SetLength(LCursor.Bytes, LSize);
  LCursor.PutNumber(EventMagic);
  LCursor.PutNumber(RecordedEventLearningVersion);
  LCursor.PutNumber(WfcEventAdapterVersion);
  LCursor.PutNumber(ALearning.QuantumFrames);
  LCursor.PutNumber(Length(LInputs));
  LCursor.PutNumber(Length(LCenters));
  LCursor.PutText(APolicy);
  for I := 0 to High(LCenters) do
  begin
    for J := 0 to 14 do
    begin
      LCursor.PutReal(LCenters[I][J]);
    end;
  end;
  for I := 0 to High(LInputs) do
  begin
    LCursor.PutNumber(LInputs[I].SourceIndex);
    LCursor.PutNumber(Length(LInputs[I].RunIndices));
    LCursor.PutNumber(LInputs[I].Bounds[0]);
    for J := 0 to High(LInputs[I].RunIndices) do
    begin
      LCursor.PutNumber(LInputs[I].Bounds[J + 1]);
      LCursor.PutNumber(LInputs[I].RunIndices[J] + 1);
      LCursor.PutNumber(Ord(LInputs[I].StartsAtOnset[J]));
    end;
  end;
  LCursor.PutText(LText);
  if LCursor.Offset <> Length(LCursor.Bytes) then
  begin
    raise EAudio.Create('Recorded event attachment size accounting disagrees');
  end;
  Result := EncodeAcousticArchive(ACorpus, WfcEventAttachmentContract, LCursor.Bytes);
end;

function DecodeRecordedEventCorpus(const ABytes: TAudioBytes;
  out ALearning: TRecordedEventLearning; out APolicy: UTF8String): TAcousticCorpusData;
var
  LCorpus: TAcousticCorpusData;
  LLearning: TRecordedEventLearning;
  LModel: TWfcSequenceModel;
  LInputs: TRecordedEventInputs;
  LCenters: TAcousticVectors;
  LCursor: TEventCursor;
  LContract: UTF8String;
  LPolicy: UTF8String;
  LText: String;
  LQuantum: Integer;
  LInputCount: Integer;
  LPaletteCount: Integer;
  LCount: Integer;
  LTotal: Integer;
  LFlag: Integer;
  I: Integer;
  J: Integer;
begin
  ALearning := nil;
  APolicy := '';
  LCorpus := nil;
  LLearning := nil;
  LModel := nil;
  LCursor := Default(TEventCursor);
  try
    LCorpus := DecodeAcousticArchive(ABytes, LContract, LCursor.Bytes);
    if LContract <> WfcEventAttachmentContract then
    begin
      raise EAudio.Create('Archive does not contain recorded event learning');
    end;
    if (LCursor.GetNumber <> EventMagic) or
      (LCursor.GetNumber <> RecordedEventLearningVersion) or
      (LCursor.GetNumber <> WfcEventAdapterVersion) then
    begin
      raise EAudio.Create('Unsupported recorded event attachment version');
    end;
    LQuantum := LCursor.GetNumber;
    LInputCount := LCursor.GetNumber;
    LPaletteCount := LCursor.GetNumber;
    if (LQuantum < 1) or (LQuantum > MaximumClipSamples) or (LInputCount < 1) or
      (LInputCount > MaximumCorpusSources) or (LPaletteCount < 1) or
      (LPaletteCount > MaximumAcousticVocabulary) then
    begin
      raise EAudio.Create('Recorded event attachment shape exceeds bounds');
    end;
    LPolicy := LCursor.GetText(MaximumCorpusTextBytes);
    ValidateCorpusText(LPolicy);
    if LPolicy = '' then
    begin
      raise EAudio.Create('Recorded event attachment lacks an admission policy');
    end;
    LCursor.Need(LPaletteCount * 15 * 8);
    SetLength(LCenters, LPaletteCount);
    for I := 0 to High(LCenters) do
    begin
      for J := 0 to 14 do
      begin
        LCenters[I][J] := LCursor.GetReal;
      end;
    end;
    SetLength(LInputs, LInputCount);
    LTotal := 0;
    for I := 0 to High(LInputs) do
    begin
      LInputs[I].SourceIndex := LCursor.GetNumber;
      LCount := LCursor.GetNumber;
      if (LCount < 1) or (LCount > MaximumPassages) or
        (LCount > MaximumRecordedEvents - LTotal) then
      begin
        raise EAudio.Create('Recorded event interval count exceeds bounds');
      end;
      Inc(LTotal, LCount);
      LCursor.Need(4 + LCount * 12);
      SetLength(LInputs[I].Bounds, LCount + 1);
      SetLength(LInputs[I].RunIndices, LCount);
      SetLength(LInputs[I].StartsAtOnset, LCount);
      LInputs[I].Bounds[0] := LCursor.GetNumber;
      for J := 0 to LCount - 1 do
      begin
        LInputs[I].Bounds[J + 1] := LCursor.GetNumber;
        LInputs[I].RunIndices[J] := LCursor.GetNumber - 1;
        LFlag := LCursor.GetNumber;
        if LFlag > 1 then
        begin
          raise EAudio.Create('Recorded event onset flag must be zero or one');
        end;
        LInputs[I].StartsAtOnset[J] := LFlag = 1;
      end;
    end;
    LText := LCursor.GetText(MaximumCorpusAttachmentBytes);
    if LCursor.Offset <> Length(LCursor.Bytes) then
    begin
      raise EAudio.Create('Trailing recorded event attachment bytes');
    end;
    LModel := DecodeWfcSequenceText(LText);
    if EncodeWfcSequenceText(LModel) <> LText then
    begin
      raise EAudio.Create('Recorded event model text must be canonical');
    end;
    LLearning := TRecordedEventLearning.CreateFromModel(LCorpus, LInputs, LQuantum,
      LCenters, LModel);
    Result := LCorpus;
    ALearning := LLearning;
    APolicy := LPolicy;
    LCorpus := nil;
    LLearning := nil;
  finally
    LModel.Free;
    LLearning.Free;
    LCorpus.Free;
  end;
end;

end.
