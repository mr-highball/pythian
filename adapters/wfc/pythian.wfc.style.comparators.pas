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
unit pythian.wfc.style.comparators;

{$mode delphi}
{$H+}

interface

uses
  pythian.audio,
  pythian.wfc.admitted.pitch,
  pythian.wfc.generation,
  pythian.wfc.pitch,
  wfc,
  wfc_model;

const
  StyleComparatorDimension = 'note_duration_order_v1';
  MaximumStyleComparatorSpans = 1024;
  MaximumStyleComparatorTokens = 1024;

type
  TStyleComparatorCase = (sccSingleRecording, sccShuffled, sccUnlearned);
  TStyleComparatorStrings = array of String;
  TStyleComparatorIndices = array of Integer;
  TStyleComparatorTokenRuns = array of TWfcModelTokens;
  TStyleComparatorVocabulary = array of TPitchDurationCell;

  { File authentication belongs to the maintained tools reader. This portable
    adapter validates caller-admitted declarations and never opens a file. }
  TStyleComparatorInput = record
    Source: TAdmittedNoteSource;
    SpanIds: TStyleComparatorStrings;
    PolicySha256: String;
    AuthoredVocabulary: TStyleComparatorVocabulary;
    AuthoredVocabularySha256: String;
    AuthoredProvenance: String;
    SourceProvenance: String;
    SourceChannels: Integer;
    Exposure: String;
  end;

  TStyleComparatorUnit = record
    Id: String;
    OriginalSpanIndices: TStyleComparatorIndices;
    FirstFrame: Int64;
    EndFrame: Int64;
  end;
  TStyleComparatorUnits = array of TStyleComparatorUnit;

  TStyleComparatorRunPermutation = record
    Id: String;
    FirstFrame: Int64;
    EndFrame: Int64;
    LeadingSilenceEndFrame: Int64;
    Units: TStyleComparatorUnits;
    OutputOrdinals: TStyleComparatorIndices;
    SeedDigests: TStyleComparatorStrings;
    IdentityRotated: Boolean;
    Supported: Boolean;
    Reason: String;
  end;
  TStyleComparatorRunPermutations = array of TStyleComparatorRunPermutation;

  TStyleComparatorDerivedSpan = record
    OriginalSpanIndex: Integer;
    Span: TAdmittedNoteSpan;
  end;
  TStyleComparatorDerivedSpans = array of TStyleComparatorDerivedSpan;

  TStyleComparatorModels = record
    Seed: Cardinal;
    Source: TAdmittedNoteSource;
    OriginalSpanIds: TStyleComparatorStrings;
    Permutations: TStyleComparatorRunPermutations;
    DerivedSpans: TStyleComparatorDerivedSpans;
    ModelTexts: array[TStyleComparatorCase] of String;
    CaseSupported: array[TStyleComparatorCase] of Boolean;
    CaseReasons: array[TStyleComparatorCase] of String;
    MarginalDistance: Double;
    RelationshipDistance: Double;
    RelationshipComparable: Boolean;
  end;

  TStyleComparatorRenderOptions = record
    Seed: Cardinal;
    OutputMilliseconds: Integer;
    SampleRate: Integer;
    Level: Double;
    MaximumTokens: Integer;
  end;

  TStyleComparatorRenderLedger = record
    SolverOptions: TAcousticGenerationOptions;
    SolveAttempted: Boolean;
    SolveReport: TGraphSolveReport;
    GeneratedTokens: TWfcModelTokens;
    RenderedTokens: TWfcModelTokens;
    RequestedTokens: Integer;
    UsedTokens: Integer;
    GeneratedDurationMilliseconds: Int64;
    FinalSpanMilliseconds: Integer;
    FinalSpanClipped: Boolean;
    OutputFrames: Int64;
    ModelSha256: String;
  end;

function DefaultStyleComparatorRenderOptions(const ASeed: Cardinal):
  TStyleComparatorRenderOptions;
procedure ValidateStyleComparatorInput(const AInput: TStyleComparatorInput);
function BuildStyleComparatorModels(const AInput: TStyleComparatorInput;
  const ASeed: Cardinal): TStyleComparatorModels;
function StyleComparatorInputTokenRuns(const ASource: TAdmittedNoteSource):
  TStyleComparatorTokenRuns;
function StyleComparatorTokenPairDistance(const ALeft,
  ARight: TStyleComparatorTokenRuns): Double;
function StyleComparatorTokenRelationshipDistance(const ALeft,
  ARight: TStyleComparatorTokenRuns): Double;
function StyleComparatorTokenMarginalDistance(const ALeft,
  ARight: TStyleComparatorTokenRuns): Double;
function GenerateStyleComparator(const AModelText: String;
  const AOptions: TStyleComparatorRenderOptions;
  out ALedger: TStyleComparatorRenderLedger): TAudioClip;

implementation

uses
  Classes,
  SysUtils,
  Math,
  pythian.pitch.track,
  pythian.hash,
  pythian.pitch,
  pythian.synth,
  wfc_sequence,
  wfc_sequence_text;

function HashText(const AText: String): String;
var
  LBytes: TAudioBytes;
begin
  SetLength(LBytes, Length(AText));
  if Length(AText) > 0 then
  begin
    Move(AText[1], LBytes[0], Length(AText));
  end;
  Result := Sha256Bytes(LBytes);
end;

function ValidIdentity(const AValue: String): Boolean;
var
  LIndex: Integer;
begin
  Result := (Length(AValue) > 0) and (Length(AValue) <= 128);
  for LIndex := 1 to Length(AValue) do
  begin
    if not (AValue[LIndex] in ['a'..'z', 'A'..'Z', '0'..'9', '.', '_', ':', '-']) then
    begin
      Exit(False);
    end;
  end;
end;

procedure RequireHash(const AValue: String);
var
  LIndex: Integer;
begin
  if Length(AValue) <> 64 then
  begin
    raise EAudio.Create('Comparator requires canonical SHA256 declarations');
  end;
  for LIndex := 1 to Length(AValue) do
  begin
    if not (AValue[LIndex] in ['0'..'9', 'a'..'f']) then
    begin
      raise EAudio.Create('Comparator requires canonical SHA256 declarations');
    end;
  end;
end;

procedure ValidateSource(const ASource: TAdmittedNoteSource);
var
  LIndex: Integer;
  LSpan: TAdmittedNoteSpan;
begin
  if not ValidIdentity(ASource.GroupId) or not ValidIdentity(ASource.RecordingId) or
    not ValidIdentity(ASource.SourceAnnotationId) or
    (Length(ASource.SourceAnnotationPublisher) < 1) or
    (Length(ASource.SourceAnnotationPublisher) > 4096) or
    (Length(ASource.SourceAnnotationMethod) < 1) or
    (Length(ASource.SourceAnnotationMethod) > 4096) then
  begin
    raise EAudio.Create('Comparator source identities or annotation declarations are invalid');
  end;
  RequireHash(ASource.SourceSha256);
  RequireHash(ASource.SourceAnnotationSha256);
  if (ASource.SampleRate < 1000) or (ASource.SampleRate > 384000) or
    (ASource.SourceFrameCount < 1) or (ASource.SourceFrameCount > High(Integer)) or
    (Length(ASource.Spans) < 1) or
    (Length(ASource.Spans) > MaximumStyleComparatorSpans) then
  begin
    raise EAudio.Create('Comparator source geometry exceeds supported bounds');
  end;
  for LIndex := 0 to High(ASource.Spans) do
  begin
    LSpan := ASource.Spans[LIndex];
    if not (LSpan.Kind in [pskPitch, pskSilence, pskUnknown]) or
      (LSpan.StartFrame < 0) or (LSpan.EndFrame <= LSpan.StartFrame) or
      (LSpan.EndFrame > ASource.SourceFrameCount) or
      ((LIndex > 0) and (LSpan.StartFrame < ASource.Spans[LIndex - 1].EndFrame)) or
      ((LSpan.Kind = pskPitch) and ((LSpan.Note < 0) or (LSpan.Note > 127))) or
      ((LSpan.Kind <> pskPitch) and (LSpan.Note <> -1)) then
    begin
      raise EAudio.Create('Comparator spans require ordered valid original intervals');
    end;
    if (RoundAdmittedFrameToMilliseconds(LSpan.EndFrame, ASource.SampleRate) -
      RoundAdmittedFrameToMilliseconds(LSpan.StartFrame, ASource.SampleRate) < 1) or
      (RoundAdmittedFrameToMilliseconds(LSpan.EndFrame, ASource.SampleRate) -
      RoundAdmittedFrameToMilliseconds(LSpan.StartFrame, ASource.SampleRate) > 1048576) then
    begin
      raise EAudio.Create('Comparator span does not fit positive integer milliseconds');
    end;
  end;
end;

procedure ValidateStyleComparatorInput(const AInput: TStyleComparatorInput);
var
  LIndex: Integer;
  LOther: Integer;
  LToken: String;
begin
  ValidateSource(AInput.Source);
  RequireHash(AInput.PolicySha256);
  RequireHash(AInput.AuthoredVocabularySha256);
  if (Length(AInput.SpanIds) <> Length(AInput.Source.Spans)) or
    (Length(AInput.AuthoredVocabulary) < 1) or
    (Length(AInput.AuthoredVocabulary) > MaximumStyleComparatorTokens) or
    (Length(AInput.AuthoredProvenance) < 1) or
    (Length(AInput.AuthoredProvenance) > 4096) or
    (Length(AInput.SourceProvenance) > 4096) or
    (AInput.SourceChannels < 0) or (AInput.SourceChannels > 2) or
    not ((AInput.Exposure = 'development') or (AInput.Exposure = 'caller-control')) then
  begin
    raise EAudio.Create('Comparator input declarations are incomplete or unsupported');
  end;
  for LIndex := 0 to High(AInput.SpanIds) do
  begin
    if not ValidIdentity(AInput.SpanIds[LIndex]) then
    begin
      raise EAudio.Create('Comparator span identity is invalid');
    end;
    for LOther := 0 to LIndex - 1 do
    begin
      if AInput.SpanIds[LOther] = AInput.SpanIds[LIndex] then
      begin
        raise EAudio.Create('Comparator span identities must be unique');
      end;
    end;
  end;
  for LIndex := 0 to High(AInput.AuthoredVocabulary) do
  begin
    if AInput.AuthoredVocabulary[LIndex].Kind = pskUnknown then
    begin
      raise EAudio.Create('Unlearned authored choices must have declared known meaning');
    end;
    LToken := String(PitchDurationToken(AInput.AuthoredVocabulary[LIndex]));
    for LOther := 0 to LIndex - 1 do
    begin
      if LToken = String(PitchDurationToken(AInput.AuthoredVocabulary[LOther])) then
      begin
        raise EAudio.Create('Unlearned authored choices must be unique');
      end;
    end;
  end;
end;

function SourceTracks(const ASource: TAdmittedNoteSource): TTimedPitchTracks;
var
  LIndex: Integer;
  LRun: Integer;
  LCount: Integer;
  LStart: Integer;
  LEnd: Integer;
  LPreviousEnd: Int64;
  LPreviousKnown: Boolean;
begin
  Result := nil;
  LRun := -1;
  LPreviousEnd := -1;
  LPreviousKnown := False;
  for LIndex := 0 to High(ASource.Spans) do
  begin
    if ASource.Spans[LIndex].Kind = pskUnknown then
    begin
      LPreviousKnown := False;
      Continue;
    end;
    if not LPreviousKnown or (ASource.Spans[LIndex].StartFrame <> LPreviousEnd) then
    begin
      Inc(LRun);
      if LRun >= 32 then
      begin
        raise EAudio.Create('Comparator exceeds 32 independently bounded training runs');
      end;
      SetLength(Result, LRun + 1);
    end;
    LStart := RoundAdmittedFrameToMilliseconds(ASource.Spans[LIndex].StartFrame,
      ASource.SampleRate);
    LEnd := RoundAdmittedFrameToMilliseconds(ASource.Spans[LIndex].EndFrame,
      ASource.SampleRate);
    LCount := Length(Result[LRun]);
    if (LCount > 0) and (ASource.Spans[LIndex].Kind = pskSilence) and
      (Result[LRun][LCount - 1].Kind = pskSilence) then
    begin
      Result[LRun][LCount - 1].EndTick := LEnd;
      if LEnd - Result[LRun][LCount - 1].StartTick > 1048576 then
      begin
        raise EAudio.Create('Coalesced comparator rest exceeds token duration');
      end;
    end
    else
    begin
      SetLength(Result[LRun], LCount + 1);
      Result[LRun][LCount].Kind := ASource.Spans[LIndex].Kind;
      Result[LRun][LCount].Note := ASource.Spans[LIndex].Note;
      Result[LRun][LCount].StartTick := LStart;
      Result[LRun][LCount].EndTick := LEnd;
    end;
    LPreviousKnown := True;
    LPreviousEnd := ASource.Spans[LIndex].EndFrame;
  end;
  if Length(Result) = 0 then
  begin
    raise EAudio.Create('Comparator has no known training runs');
  end;
end;

function StyleComparatorInputTokenRuns(const ASource: TAdmittedNoteSource):
  TStyleComparatorTokenRuns;
var
  LTracks: TTimedPitchTracks;
  LRun: Integer;
  LIndex: Integer;
  LCell: TPitchDurationCell;
begin
  ValidateSource(ASource);
  LTracks := SourceTracks(ASource);
  Result := nil;
  SetLength(Result, Length(LTracks));
  for LRun := 0 to High(LTracks) do
  begin
    SetLength(Result[LRun], Length(LTracks[LRun]));
    for LIndex := 0 to High(LTracks[LRun]) do
    begin
      LCell.Kind := LTracks[LRun][LIndex].Kind;
      LCell.Note := LTracks[LRun][LIndex].Note;
      LCell.Duration := LTracks[LRun][LIndex].EndTick - LTracks[LRun][LIndex].StartTick;
      Result[LRun][LIndex] := PitchDurationToken(LCell);
    end;
  end;
end;

procedure CountRelations(const ARuns: TStyleComparatorTokenRuns;
  const AWidth: Integer; const ACounts: TStringList; out ATotal: Integer);
var
  LRun: Integer;
  LIndex: Integer;
  LPart: Integer;
  LKey: String;
  LFound: Integer;
  LTokenCount: Integer;
begin
  ATotal := 0;
  LTokenCount := 0;
  if Length(ARuns) > 32 then
  begin
    raise EAudio.Create('Comparator scoring exceeds 32 runs');
  end;
  for LRun := 0 to High(ARuns) do
  begin
    if Length(ARuns[LRun]) > MaximumStyleComparatorTokens then
    begin
      raise EAudio.Create('Comparator scoring exceeds per-run token bounds');
    end;
    Inc(LTokenCount, Length(ARuns[LRun]));
    if LTokenCount > MaximumStyleComparatorSpans then
    begin
      raise EAudio.Create('Comparator scoring exceeds aggregate token bounds');
    end;
    for LIndex := 0 to High(ARuns[LRun]) do
    begin
      if Length(ARuns[LRun][LIndex]) > 128 then
      begin
        raise EAudio.Create('Comparator scoring token exceeds canonical size');
      end;
      if DecodePitchDurationToken(ARuns[LRun][LIndex]).Kind = pskUnknown then
      begin
        raise EAudio.Create('Comparator relationships require known run tokens; unknown splits runs');
      end;
    end;
  end;
  for LRun := 0 to High(ARuns) do
  begin
    for LIndex := 0 to Length(ARuns[LRun]) - AWidth do
    begin
      LKey := '';
      for LPart := 0 to AWidth - 1 do
      begin
        LKey := LKey + IntToStr(Length(ARuns[LRun][LIndex + LPart])) + ':' +
          String(ARuns[LRun][LIndex + LPart]);
      end;
      LFound := ACounts.IndexOf(LKey);
      if LFound < 0 then
      begin
        ACounts.AddObject(LKey, TObject(PtrInt(1)));
      end
      else
      begin
        ACounts.Objects[LFound] := TObject(PtrInt(ACounts.Objects[LFound]) + 1);
      end;
      Inc(ATotal);
      if ATotal > 65536 then
      begin
        raise EAudio.Create('Comparator relationship accounting exceeds bounded observations');
      end;
    end;
  end;
end;

function RelationDistance(const ALeft, ARight: TStyleComparatorTokenRuns;
  const AWidth: Integer): Double;
var
  LLeft: TStringList;
  LRight: TStringList;
  LLeftTotal: Integer;
  LRightTotal: Integer;
  LIndex: Integer;
  LOther: Integer;
  LLeftCount: Int64;
  LRightCount: Int64;
  LNumerator: Int64;
  LDifference: Int64;
begin
  LLeft := TStringList.Create;
  LRight := TStringList.Create;
  try
    LLeft.Sorted := True;
    LRight.Sorted := True;
    CountRelations(ALeft, AWidth, LLeft, LLeftTotal);
    CountRelations(ARight, AWidth, LRight, LRightTotal);
    if (LLeftTotal = 0) or (LRightTotal = 0) then
    begin
      raise EAudio.Create('Comparator relationship mass is missing and unscorable');
    end;
    LNumerator := 0;
    for LIndex := 0 to LLeft.Count - 1 do
    begin
      LLeftCount := PtrInt(LLeft.Objects[LIndex]);
      LRightCount := 0;
      LOther := LRight.IndexOf(LLeft[LIndex]);
      if LOther >= 0 then
      begin
        LRightCount := PtrInt(LRight.Objects[LOther]);
      end;
      LDifference := LLeftCount * Int64(LRightTotal) - LRightCount * Int64(LLeftTotal);
      Inc(LNumerator, Abs(LDifference));
    end;
    for LIndex := 0 to LRight.Count - 1 do
    begin
      if LLeft.IndexOf(LRight[LIndex]) < 0 then
      begin
        LRightCount := PtrInt(LRight.Objects[LIndex]);
        Inc(LNumerator, LRightCount * Int64(LLeftTotal));
      end;
    end;
    Result := LNumerator / (Int64(2) * LLeftTotal * LRightTotal);
  finally
    LRight.Free;
    LLeft.Free;
  end;
end;

function StyleComparatorTokenPairDistance(const ALeft,
  ARight: TStyleComparatorTokenRuns): Double;
begin
  Result := RelationDistance(ALeft, ARight, 2);
end;

function StyleComparatorTokenRelationshipDistance(const ALeft,
  ARight: TStyleComparatorTokenRuns): Double;
begin
  Result := RelationDistance(ALeft, ARight, 3);
end;

function StyleComparatorTokenMarginalDistance(const ALeft,
  ARight: TStyleComparatorTokenRuns): Double;
begin
  Result := RelationDistance(ALeft, ARight, 1);
end;

procedure AppendInteger(const AStream: TMemoryStream; const AValue: Cardinal);
var
  LBytes: array[0..3] of Byte;
  LIndex: Integer;
begin
  for LIndex := 0 to 3 do
  begin
    LBytes[LIndex] := Byte((AValue shr (LIndex * 8)) and $ff);
  end;
  AStream.WriteBuffer(LBytes[0], 4);
end;

procedure AppendText(const AStream: TMemoryStream; const AValue: String);
begin
  AppendInteger(AStream, Length(AValue));
  if Length(AValue) > 0 then
  begin
    AStream.WriteBuffer(AValue[1], Length(AValue));
  end;
end;

procedure AppendHash(const AStream: TMemoryStream; const AHash: String);
var
  LIndex: Integer;
  LByte: Byte;
begin
  for LIndex := 0 to 31 do
  begin
    LByte := StrToInt('$' + Copy(AHash, LIndex * 2 + 1, 2));
    AStream.WriteBuffer(LByte, 1);
  end;
end;

function PermutationDigest(const AInput: TStyleComparatorInput;
  const AScope: String; const ASeed: Cardinal; const AOrdinal: Integer): String;
const
  Prefix: String = 'pythian-style-shuffle-v1';
var
  LStream: TMemoryStream;
  LZero: Byte;
begin
  LStream := TMemoryStream.Create;
  try
    LStream.WriteBuffer(Prefix[1], Length(Prefix));
    LZero := 0;
    LStream.WriteBuffer(LZero, 1);
    AppendHash(LStream, AInput.Source.SourceSha256);
    AppendHash(LStream, AInput.PolicySha256);
    AppendInteger(LStream, ASeed);
    AppendText(LStream, AInput.Source.RecordingId);
    AppendText(LStream, StyleComparatorDimension);
    AppendText(LStream, AScope);
    AppendInteger(LStream, AOrdinal);
    LStream.Position := 0;
    Result := Sha256Stream(LStream, LStream.Size);
  finally
    LStream.Free;
  end;
end;

procedure AppendFrozenSpans(const ASource: TAdmittedNoteSource;
  const AFirst, ALast: Integer; var ATrack: TTimedPitchSpans;
  var APosition: Integer);
var
  LIndex: Integer;
  LEndIndex: Integer;
  LCount: Integer;
  LDuration: Integer;
begin
  LIndex := AFirst;
  while LIndex <= ALast do
  begin
    LEndIndex := LIndex;
    if ASource.Spans[LIndex].Kind = pskSilence then
    begin
      while (LEndIndex < ALast) and
        (ASource.Spans[LEndIndex + 1].Kind = pskSilence) do
      begin
        Inc(LEndIndex);
      end;
    end;
    LDuration := RoundAdmittedFrameToMilliseconds(ASource.Spans[LEndIndex].EndFrame,
      ASource.SampleRate) -
      RoundAdmittedFrameToMilliseconds(ASource.Spans[LIndex].StartFrame, ASource.SampleRate);
    if (LDuration < 1) or (LDuration > 1048576) then
    begin
      raise EAudio.Create('Frozen comparator duration exceeds supported token bounds');
    end;
    LCount := Length(ATrack);
    SetLength(ATrack, LCount + 1);
    ATrack[LCount].Kind := ASource.Spans[LIndex].Kind;
    ATrack[LCount].Note := ASource.Spans[LIndex].Note;
    ATrack[LCount].StartTick := APosition;
    Inc(APosition, LDuration);
    ATrack[LCount].EndTick := APosition;
    LIndex := LEndIndex + 1;
  end;
end;

function TracksToRuns(const ATracks: TTimedPitchTracks): TStyleComparatorTokenRuns;
var
  LRun: Integer;
  LIndex: Integer;
  LCell: TPitchDurationCell;
begin
  Result := nil;
  SetLength(Result, Length(ATracks));
  for LRun := 0 to High(ATracks) do
  begin
    SetLength(Result[LRun], Length(ATracks[LRun]));
    for LIndex := 0 to High(ATracks[LRun]) do
    begin
      LCell.Kind := ATracks[LRun][LIndex].Kind;
      LCell.Note := ATracks[LRun][LIndex].Note;
      LCell.Duration := ATracks[LRun][LIndex].EndTick - ATracks[LRun][LIndex].StartTick;
      Result[LRun][LIndex] := PitchDurationToken(LCell);
    end;
  end;
end;

function AuthoredModel(const AVocabulary: TStyleComparatorVocabulary): TWfcSequenceModel;
var
  LLengths: TWfcSequenceSampleLengths;
  LTokens: TWfcModelTokens;
  LStates: TWfcSequenceStates;
  LCounts: TWfcModelIntegerArray;
  LIndex: Integer;
begin
  SetLength(LLengths, Length(AVocabulary));
  SetLength(LTokens, Length(AVocabulary));
  SetLength(LStates, Length(AVocabulary));
  SetLength(LCounts, Length(AVocabulary));
  for LIndex := 0 to High(AVocabulary) do
  begin
    LLengths[LIndex] := 1;
    LTokens[LIndex] := PitchDurationToken(AVocabulary[LIndex]);
    LStates[LIndex] := MakeWfcSequenceState(nil, LIndex);
    LCounts[LIndex] := 1;
  end;
  Result := TWfcSequenceModel.Create(1, LLengths, LTokens, LStates,
    LCounts, LCounts, LCounts);
end;

function BuildStyleComparatorModels(const AInput: TStyleComparatorInput;
  const ASeed: Cardinal): TStyleComparatorModels;
var
  LIndex: Integer;
  LFirst: Integer;
  LLast: Integer;
  LLeadingLast: Integer;
  LRunIndex: Integer;
  LUnitIndex: Integer;
  LUnitLast: Integer;
  LPart: Integer;
  LOther: Integer;
  LOrdinal: Integer;
  LSwap: Integer;
  LIdentity: Boolean;
  LPosition: Int64;
  LModelPosition: Integer;
  LDuration: Int64;
  LRun: TStyleComparatorRunPermutation;
  LOriginalTracks: TTimedPitchTracks;
  LShuffledTracks: TTimedPitchTracks;
  LOriginalRuns: TStyleComparatorTokenRuns;
  LShuffledRuns: TStyleComparatorTokenRuns;
  LRunLeft: TStyleComparatorTokenRuns;
  LRunRight: TStyleComparatorTokenRuns;
  LWeights: array of Integer;
  LModel: TWfcSequenceModel;
  LCase: TStyleComparatorCase;
  LSupportedRuns: Integer;
begin
  ValidateStyleComparatorInput(AInput);
  Result := Default(TStyleComparatorModels);
  Result.Seed := ASeed;
  Result.Source := AInput.Source;
  Result.Source.Spans := Copy(AInput.Source.Spans);
  Result.OriginalSpanIds := Copy(AInput.SpanIds);
  SetLength(Result.DerivedSpans, Length(AInput.Source.Spans));
  for LIndex := 0 to High(AInput.Source.Spans) do
  begin
    Result.DerivedSpans[LIndex].OriginalSpanIndex := LIndex;
    Result.DerivedSpans[LIndex].Span := AInput.Source.Spans[LIndex];
  end;
  LOriginalTracks := SourceTracks(AInput.Source);
  SetLength(LShuffledTracks, Length(LOriginalTracks));
  LIndex := 0;
  LRunIndex := 0;
  LSupportedRuns := 0;
  while LIndex < Length(AInput.Source.Spans) do
  begin
    if AInput.Source.Spans[LIndex].Kind = pskUnknown then
    begin
      Inc(LIndex);
      Continue;
    end;
    LFirst := LIndex;
    LLast := LFirst;
    while (LLast < High(AInput.Source.Spans)) and
      (AInput.Source.Spans[LLast + 1].Kind <> pskUnknown) and
      (AInput.Source.Spans[LLast + 1].StartFrame = AInput.Source.Spans[LLast].EndFrame) do
    begin
      Inc(LLast);
    end;
    LRun := Default(TStyleComparatorRunPermutation);
    LRun.Id := AInput.Source.RecordingId + ':run:' + IntToStr(LRunIndex);
    LRun.FirstFrame := AInput.Source.Spans[LFirst].StartFrame;
    LRun.EndFrame := AInput.Source.Spans[LLast].EndFrame;
    LRun.LeadingSilenceEndFrame := LRun.FirstFrame;
    LLeadingLast := LFirst - 1;
    while (LLeadingLast < LLast) and
      (AInput.Source.Spans[LLeadingLast + 1].Kind = pskSilence) do
    begin
      Inc(LLeadingLast);
      LRun.LeadingSilenceEndFrame := AInput.Source.Spans[LLeadingLast].EndFrame;
    end;
    LUnitIndex := LLeadingLast + 1;
    while LUnitIndex <= LLast do
    begin
      LUnitLast := LUnitIndex;
      while (LUnitLast < LLast) and
        (AInput.Source.Spans[LUnitLast + 1].Kind = pskSilence) do
      begin
        Inc(LUnitLast);
      end;
      LOrdinal := Length(LRun.Units);
      SetLength(LRun.Units, LOrdinal + 1);
      LRun.Units[LOrdinal].Id := AInput.SpanIds[LUnitIndex];
      LRun.Units[LOrdinal].FirstFrame := AInput.Source.Spans[LUnitIndex].StartFrame;
      LRun.Units[LOrdinal].EndFrame := AInput.Source.Spans[LUnitLast].EndFrame;
      SetLength(LRun.Units[LOrdinal].OriginalSpanIndices, LUnitLast - LUnitIndex + 1);
      for LPart := LUnitIndex to LUnitLast do
      begin
        LRun.Units[LOrdinal].OriginalSpanIndices[LPart - LUnitIndex] := LPart;
      end;
      LUnitIndex := LUnitLast + 1;
    end;
    SetLength(LRun.OutputOrdinals, Length(LRun.Units));
    SetLength(LRun.SeedDigests, Length(LRun.Units));
    for LUnitIndex := 0 to High(LRun.Units) do
    begin
      LRun.OutputOrdinals[LUnitIndex] := LUnitIndex;
      LRun.SeedDigests[LUnitIndex] := PermutationDigest(AInput, LRun.Id, ASeed, LUnitIndex);
    end;
    for LUnitIndex := 1 to High(LRun.Units) do
    begin
      LOther := LUnitIndex;
      while (LOther > 0) and
        (LRun.SeedDigests[LRun.OutputOrdinals[LOther]] <
        LRun.SeedDigests[LRun.OutputOrdinals[LOther - 1]]) do
      begin
        LSwap := LRun.OutputOrdinals[LOther];
        LRun.OutputOrdinals[LOther] := LRun.OutputOrdinals[LOther - 1];
        LRun.OutputOrdinals[LOther - 1] := LSwap;
        Dec(LOther);
      end;
    end;
    LIdentity := True;
    for LUnitIndex := 0 to High(LRun.OutputOrdinals) do
    begin
      if LRun.OutputOrdinals[LUnitIndex] <> LUnitIndex then
      begin
        LIdentity := False;
      end;
    end;
    if LIdentity and (Length(LRun.Units) >= 2) then
    begin
      for LUnitIndex := 0 to High(LRun.OutputOrdinals) do
      begin
        LRun.OutputOrdinals[LUnitIndex] := (LUnitIndex + 1) mod Length(LRun.Units);
      end;
      LRun.IdentityRotated := True;
    end;
    LModelPosition := LOriginalTracks[LRunIndex][0].StartTick;
    AppendFrozenSpans(AInput.Source, LFirst, LLeadingLast,
      LShuffledTracks[LRunIndex], LModelPosition);
    LPosition := LRun.LeadingSilenceEndFrame;
    for LUnitIndex := 0 to High(LRun.OutputOrdinals) do
    begin
      LOrdinal := LRun.OutputOrdinals[LUnitIndex];
      AppendFrozenSpans(AInput.Source,
        LRun.Units[LOrdinal].OriginalSpanIndices[0],
        LRun.Units[LOrdinal].OriginalSpanIndices[High(LRun.Units[LOrdinal].OriginalSpanIndices)],
        LShuffledTracks[LRunIndex], LModelPosition);
      for LPart := 0 to High(LRun.Units[LOrdinal].OriginalSpanIndices) do
      begin
        LOther := LRun.Units[LOrdinal].OriginalSpanIndices[LPart];
        LDuration := AInput.Source.Spans[LOther].EndFrame - AInput.Source.Spans[LOther].StartFrame;
        Result.DerivedSpans[LOther].Span.StartFrame := LPosition;
        Inc(LPosition, LDuration);
        Result.DerivedSpans[LOther].Span.EndFrame := LPosition;
      end;
    end;
    if LPosition <> LRun.EndFrame then
    begin
      raise EAudio.Create('Comparator derivation changed the original run clock');
    end;
    SetLength(LRunLeft, 1);
    SetLength(LRunRight, 1);
    LOriginalRuns := TracksToRuns(LOriginalTracks);
    LShuffledRuns := TracksToRuns(LShuffledTracks);
    LRunLeft[0] := LOriginalRuns[LRunIndex];
    LRunRight[0] := LShuffledRuns[LRunIndex];
    LRun.Supported := False;
    if (Length(LRun.Units) >= 2) and
      (Length(LRunLeft[0]) >= 3) and (Length(LRunRight[0]) >= 3) then
    begin
      LRun.Supported := StyleComparatorTokenRelationshipDistance(LRunLeft, LRunRight) > 0;
    end;
    if LRun.Supported then
    begin
      Inc(LSupportedRuns);
      LRun.Reason := 'changed_source_token_trigram_relationships';
    end
    else if Length(LRun.Units) < 2 then
    begin
      LRun.Reason := 'fewer_than_two_complete_note_units';
    end
    else
    begin
      LRun.Reason := 'unchanged_targeted_token_relationships_no_redraw';
    end;
    SetLength(Result.Permutations, LRunIndex + 1);
    Result.Permutations[LRunIndex] := LRun;
    Inc(LRunIndex);
    LIndex := LLast + 1;
  end;
  LOriginalRuns := TracksToRuns(LOriginalTracks);
  LShuffledRuns := TracksToRuns(LShuffledTracks);
  Result.MarginalDistance := StyleComparatorTokenMarginalDistance(LOriginalRuns, LShuffledRuns);
  Result.RelationshipComparable := False;
  for LIndex := 0 to High(LOriginalRuns) do
  begin
    if Length(LOriginalRuns[LIndex]) >= 3 then
    begin
      Result.RelationshipComparable := True;
    end;
  end;
  if Result.RelationshipComparable then
  begin
    Result.RelationshipDistance := StyleComparatorTokenRelationshipDistance(LOriginalRuns, LShuffledRuns);
  end
  else
  begin
    Result.RelationshipDistance := NaN;
  end;
  SetLength(LWeights, Length(LOriginalTracks));
  for LIndex := 0 to High(LWeights) do
  begin
    LWeights[LIndex] := 1;
  end;
  for LCase := Low(TStyleComparatorCase) to High(TStyleComparatorCase) do
  begin
    case LCase of
      sccSingleRecording:
        LModel := LearnPitchDurationModel(LOriginalTracks, LWeights, 3);
      sccShuffled:
        LModel := LearnPitchDurationModel(LShuffledTracks, LWeights, 3);
      sccUnlearned:
        LModel := AuthoredModel(AInput.AuthoredVocabulary);
    end;
    try
      Result.ModelTexts[LCase] := EncodeWfcSequenceText(LModel);
    finally
      LModel.Free;
    end;
    Result.CaseSupported[LCase] := (LCase <> sccShuffled) or
      ((LSupportedRuns > 0) and Result.RelationshipComparable and (Result.RelationshipDistance > 0));
    if Result.CaseSupported[LCase] then
    begin
      Result.CaseReasons[LCase] := 'mechanical_execution_supported_no_grounded_acceptance';
    end
    else
    begin
      Result.CaseReasons[LCase] := 'shuffle_targeted_relationships_unsupported';
    end;
  end;
end;

function DefaultStyleComparatorRenderOptions(const ASeed: Cardinal):
  TStyleComparatorRenderOptions;
begin
  Result.Seed := ASeed;
  Result.OutputMilliseconds := 120000;
  Result.SampleRate := 16000;
  Result.Level := 0.1;
  Result.MaximumTokens := MaximumStyleComparatorTokens;
end;

function GenerateStyleComparator(const AModelText: String;
  const AOptions: TStyleComparatorRenderOptions;
  out ALedger: TStyleComparatorRenderLedger): TAudioClip;
var
  LModel: TWfcSequenceModel;
  LOptions: TAcousticGenerationOptions;
  LCell: TPitchDurationCell;
  LIndex: Integer;
  LMinimum: Integer;
  LUsedDuration: Integer;
  LRemaining: Integer;
  LPosition: Integer;
  LToneCount: Integer;
  LTones: TFrameTones;
  LVoice: TSynthVoice;
  LCanonical: String;
begin
  ALedger := Default(TStyleComparatorRenderLedger);
  Result := nil;
  if (AOptions.OutputMilliseconds < 1) or (AOptions.OutputMilliseconds > 120000) or
    (AOptions.SampleRate < 1000) or (AOptions.SampleRate > 384000) or
    (Int64(AOptions.OutputMilliseconds) * AOptions.SampleRate mod 1000 <> 0) or
    IsNan(AOptions.Level) or IsInfinite(AOptions.Level) or
    (AOptions.Level < 0) or (AOptions.Level > 1) or
    (AOptions.MaximumTokens < 1) or (AOptions.MaximumTokens > MaximumStyleComparatorTokens) then
  begin
    raise EAudio.Create('Comparator rendering options exceed the exact bounded clock');
  end;
  LModel := DecodeWfcSequenceText(AModelText);
  try
    LCanonical := EncodeWfcSequenceText(LModel);
    if LCanonical <> AModelText then
    begin
      raise EAudio.Create('Comparator requires canonical saved model text');
    end;
    LMinimum := High(Integer);
    for LIndex := 0 to LModel.PublicTokenCount - 1 do
    begin
      LCell := DecodePitchDurationToken(LModel.PublicTokenAt(LIndex));
      if LCell.Kind = pskUnknown then
      begin
        raise EAudio.Create('Comparator generation cannot render unknown meaning');
      end;
      LMinimum := Min(LMinimum, LCell.Duration);
    end;
    ALedger.RequestedTokens := (AOptions.OutputMilliseconds + LMinimum - 1) div LMinimum;
    if ALedger.RequestedTokens > AOptions.MaximumTokens then
    begin
      raise EAudio.Create('Comparator exact output clock exceeds declared token budget');
    end;
    LOptions := DefaultAcousticGenerationOptions;
    LOptions.Seed := AOptions.Seed;
    LOptions.FrameCount := ALedger.RequestedTokens;
    LOptions.Extent := wsePrefix;
    ALedger.SolverOptions := LOptions;
    ALedger.ModelSha256 := HashText(LCanonical);
    ALedger.SolveAttempted := True;
    if not TryGenerateTokenSequence(LModel, LOptions, nil, ALedger.GeneratedTokens,
      ALedger.SolveReport) then
    begin
      raise EAudio.Create('Comparator WFC solve did not support the declared output clock');
    end;
  finally
    LModel.Free;
  end;
  LVoice := DefaultSynthVoice;
  LVoice.Gain := AOptions.Level;
  LVoice.Envelope.ReleaseSeconds := 0;
  LPosition := 0;
  LToneCount := 0;
  for LIndex := 0 to High(ALedger.GeneratedTokens) do
  begin
    LCell := DecodePitchDurationToken(ALedger.GeneratedTokens[LIndex]);
    Inc(ALedger.GeneratedDurationMilliseconds, LCell.Duration);
    if LPosition >= AOptions.OutputMilliseconds then
    begin
      Continue;
    end;
    LRemaining := AOptions.OutputMilliseconds - LPosition;
    LUsedDuration := Min(LCell.Duration, LRemaining);
    Inc(ALedger.UsedTokens);
    SetLength(ALedger.RenderedTokens, ALedger.UsedTokens);
    if LCell.Duration > LRemaining then
    begin
      ALedger.FinalSpanClipped := True;
    end;
    LCell.Duration := LUsedDuration;
    ALedger.RenderedTokens[ALedger.UsedTokens - 1] := PitchDurationToken(LCell);
    ALedger.FinalSpanMilliseconds := LUsedDuration;
    if LCell.Kind = pskPitch then
    begin
      SetLength(LTones, LToneCount + 1);
      LTones[LToneCount].StartFrame := Int64(LPosition) * AOptions.SampleRate div 1000;
      LTones[LToneCount].GateFrames :=
        Int64(LPosition + LUsedDuration) * AOptions.SampleRate div 1000 -
        LTones[LToneCount].StartFrame;
      LTones[LToneCount].FrequencyHz := 440 * Power(2, (LCell.Note - 69) / 12);
      LTones[LToneCount].Velocity := 1;
      LTones[LToneCount].Voice := LVoice;
      LTones[LToneCount].Seed := AOptions.Seed;
      Inc(LToneCount);
    end;
    Inc(LPosition, LUsedDuration);
  end;
  if LPosition <> AOptions.OutputMilliseconds then
  begin
    raise EAudio.Create('Comparator generated path did not fill declared output clock');
  end;
  ALedger.OutputFrames := Int64(AOptions.OutputMilliseconds) * AOptions.SampleRate div 1000;
  Result := RenderFrameTones(LTones, AOptions.SampleRate, ALedger.OutputFrames);
  if (Result.FrameCount <> ALedger.OutputFrames) or (Result.Channels <> 2) then
  begin
    FreeAndNil(Result);
    raise EAudio.Create('Comparator render changed the exact declared output geometry');
  end;
end;

end.
