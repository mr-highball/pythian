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
unit pythian.wfc.admitted.pitch;

{$mode delphi}
{$H+}

interface

uses
  pythian.pitch.track,
  pythian.wfc.generation,
  wfc,
  wfc_model,
  wfc_sequence,
  wfc_sequence_graph;

const
  AdmittedPitchPolicyIdentity = 'pythian.admitted-pitch-duration.v1';
  MaximumAdmittedSources = 32;
  MaximumAdmittedInputSpans = 65536;
  MaximumAdmittedTrainingRuns = 32;

type
  TAdmittedNoteSpan = record
    Kind: TPitchSpanKind;
    Note: Integer;
    StartFrame: Int64;
    EndFrame: Int64;
  end;
  TAdmittedNoteSpans = array of TAdmittedNoteSpan;

  { SHA fields bind caller-verified source and annotation bytes. This unit
    checks their canonical spelling and retains them; it does not open files. }
  TAdmittedNoteSource = record
    GroupId: String;
    RecordingId: String;
    SourceSha256: String;
    SourceAnnotationId: String;
    SourceAnnotationSha256: String;
    SourceAnnotationPublisher: String;
    SourceAnnotationMethod: String;
    SampleRate: Integer;
    SourceFrameCount: Int64;
    Spans: TAdmittedNoteSpans;
  end;
  TAdmittedNoteSources = array of TAdmittedNoteSource;

  { Immutable saved WFC text plus a source/annotation/run ledger. All model
    coordinates use integer milliseconds; exact original frames stay in the
    evidence ledger. Caller owns this object and any model returned by Load. }
  TAdmittedPitchDurationModel = class
  private
    FModelText: String;
    FEvidenceText: String;
    FModelSha256: String;
    FEvidenceSha256: String;
    FOrder: Integer;
    FSourceCount: Integer;
    FGroupCount: Integer;
    FTrainingRunCount: Integer;
    FTrainingSpanCount: Integer;
  public
    function Load: TWfcSequenceModel;
    function TryGenerate(const AOptions: TAcousticGenerationOptions;
      const AConstraints: TWfcSequenceTokenConstraints;
      var ATokens: TWfcModelTokens; out AReport: TGraphSolveReport): Boolean;
    property ModelText: String read FModelText;
    property EvidenceText: String read FEvidenceText;
    property ModelSha256: String read FModelSha256;
    property EvidenceSha256: String read FEvidenceSha256;
    property Order: Integer read FOrder;
    property SourceCount: Integer read FSourceCount;
    property GroupCount: Integer read FGroupCount;
    property TrainingRunCount: Integer read FTrainingRunCount;
    property TrainingSpanCount: Integer read FTrainingSpanCount;
  end;

function RoundAdmittedFrameToMilliseconds(const AFrame: Int64;
  const ASampleRate: Integer): Integer;
function LearnAdmittedPitchDurationModel(const ASources: TAdmittedNoteSources;
  const AOrder: Integer): TAdmittedPitchDurationModel;
function LearnWeightedAdmittedPitchDurationModel(const ASources: TAdmittedNoteSources;
  const ASourceWeights: array of Integer; const AOrder: Integer;
  const AWeightPolicyId: String): TAdmittedPitchDurationModel;

implementation

uses
  Classes,
  SysUtils,
  pythian.audio,
  pythian.hash,
  pythian.wfc.pitch,
  wfc_sequence_text;

type
  TAdmittedTrackArray = array of TTimedPitchSpans;
  TAdmittedRunSourceIndices = array of Integer;

function HashText(const AValue: String): String;
var
  LBytes: TAudioBytes;
begin
  SetLength(LBytes, Length(AValue));
  if Length(AValue) > 0 then
  begin
    Move(AValue[1], LBytes[0], Length(AValue));
  end;
  Result := Sha256Bytes(LBytes);
end;

function ValidIdentity(const AValue: String): Boolean;
var
  LIndex: Integer;
begin
  Result := (Length(AValue) >= 1) and (Length(AValue) <= 128);
  if not Result then
  begin
    Exit;
  end;
  for LIndex := 1 to Length(AValue) do
  begin
    if not (AValue[LIndex] in ['a'..'z', 'A'..'Z', '0'..'9', '.', '_', ':', '-']) then
    begin
      Exit(False);
    end;
  end;
end;

function ValidSha256(const AValue: String): Boolean;
var
  LIndex: Integer;
begin
  Result := Length(AValue) = 64;
  if not Result then
  begin
    Exit;
  end;
  for LIndex := 1 to Length(AValue) do
  begin
    if not (AValue[LIndex] in ['0'..'9', 'a'..'f']) then
    begin
      Exit(False);
    end;
  end;
end;

function RoundAdmittedFrameToMilliseconds(const AFrame: Int64;
  const ASampleRate: Integer): Integer;
var
  LScaled: Int64;
  LRounded: Int64;
begin
  if (AFrame < 0) or (ASampleRate < 1000) or (ASampleRate > 384000) then
  begin
    raise EAudio.Create('Admitted frame timebase or source coordinate is invalid');
  end;
  if AFrame > (High(Int64) - ASampleRate div 2) div 1000 then
  begin
    raise EAudio.Create('Admitted frame coordinate exceeds rational conversion bound');
  end;
  LScaled := AFrame * 1000;
  LRounded := (LScaled + ASampleRate div 2) div ASampleRate;
  if LRounded > High(Integer) then
  begin
    raise EAudio.Create('Admitted millisecond coordinate exceeds model bound');
  end;
  Result := Integer(LRounded);
end;

procedure ValidateSource(const ASource: TAdmittedNoteSource;
  var AInputSpanCount: Integer; out AHasTrainingRun: Boolean);
var
  LIndex: Integer;
  LSpan: TAdmittedNoteSpan;
  LStartMs: Integer;
  LEndMs: Integer;
  LPriorEnd: Int64;
begin
  if not ValidIdentity(ASource.GroupId) or not ValidIdentity(ASource.RecordingId) or
    not ValidIdentity(ASource.SourceAnnotationId) or
    not ValidIdentity(ASource.SourceAnnotationPublisher) or
    not ValidIdentity(ASource.SourceAnnotationMethod) or
    not ValidSha256(ASource.SourceSha256) or
    not ValidSha256(ASource.SourceAnnotationSha256) then
  begin
    raise EAudio.Create('Admitted source ownership or evidence identity is invalid');
  end;
  if (ASource.SampleRate < 1000) or (ASource.SampleRate > 384000) or
    (ASource.SourceFrameCount < 1) or (ASource.SourceFrameCount > High(Integer)) then
  begin
    raise EAudio.Create('Admitted source sample rate or frame extent is out of bounds');
  end;
  Inc(AInputSpanCount, Length(ASource.Spans));
  if AInputSpanCount > MaximumAdmittedInputSpans then
  begin
    raise EAudio.Create('Admitted evidence exceeds input span bound');
  end;
  AHasTrainingRun := False;
  LPriorEnd := -1;
  for LIndex := 0 to High(ASource.Spans) do
  begin
    LSpan := ASource.Spans[LIndex];
    if not (LSpan.Kind in [pskPitch, pskSilence, pskUnknown]) or
      (LSpan.StartFrame < 0) or (LSpan.EndFrame <= LSpan.StartFrame) or
      (LSpan.EndFrame > ASource.SourceFrameCount) or
      ((LIndex > 0) and (LSpan.StartFrame < LPriorEnd)) then
    begin
      raise EAudio.Create('Admitted source spans must be positive, ordered and inside source geometry');
    end;
    if (LSpan.Kind = pskPitch) then
    begin
      if (LSpan.Note < 0) or (LSpan.Note > 127) then
      begin
        raise EAudio.Create('Admitted pitch span note must be MIDI 0..127');
      end;
      AHasTrainingRun := True;
      LStartMs := RoundAdmittedFrameToMilliseconds(LSpan.StartFrame, ASource.SampleRate);
      LEndMs := RoundAdmittedFrameToMilliseconds(LSpan.EndFrame, ASource.SampleRate);
      if (LEndMs <= LStartMs) or (LEndMs - LStartMs > 1048576) then
      begin
        raise EAudio.Create('Admitted pitch collapses or exceeds millisecond duration bound');
      end;
    end
    else
    begin
      if LSpan.Note <> -1 then
      begin
        raise EAudio.Create('Silence and unknown spans must use note -1');
      end;
      if LSpan.Kind = pskSilence then
      begin
        AHasTrainingRun := True;
        LStartMs := RoundAdmittedFrameToMilliseconds(LSpan.StartFrame, ASource.SampleRate);
        LEndMs := RoundAdmittedFrameToMilliseconds(LSpan.EndFrame, ASource.SampleRate);
        if (LEndMs <= LStartMs) or (LEndMs - LStartMs > 1048576) then
        begin
          raise EAudio.Create('Admitted silence collapses or exceeds millisecond duration bound');
        end;
      end;
    end;
    LPriorEnd := LSpan.EndFrame;
  end;
end;

procedure AppendRun(var ATracks: TAdmittedTrackArray;
  var ARunSources: TAdmittedRunSourceIndices; const ASource: TAdmittedNoteSource;
  const ASourceIndex, AFirstIndex, AEndIndex: Integer);
var
  LTrackIndex: Integer;
  LSpanIndex: Integer;
  LSpan: TAdmittedNoteSpan;
  LTimed: TTimedPitchSpans;
begin
  LTrackIndex := Length(ATracks);
  if LTrackIndex >= MaximumAdmittedTrainingRuns then
  begin
    raise EAudio.Create('Admitted pitch corpus exceeds 32 independent training runs');
  end;
  SetLength(LTimed, AEndIndex - AFirstIndex);
  for LSpanIndex := AFirstIndex to AEndIndex - 1 do
  begin
    LSpan := ASource.Spans[LSpanIndex];
    LTimed[LSpanIndex - AFirstIndex].Kind := LSpan.Kind;
    LTimed[LSpanIndex - AFirstIndex].Note := LSpan.Note;
    LTimed[LSpanIndex - AFirstIndex].StartTick :=
      RoundAdmittedFrameToMilliseconds(LSpan.StartFrame, ASource.SampleRate);
    LTimed[LSpanIndex - AFirstIndex].EndTick :=
      RoundAdmittedFrameToMilliseconds(LSpan.EndFrame, ASource.SampleRate);
    if (LTimed[LSpanIndex - AFirstIndex].EndTick <=
      LTimed[LSpanIndex - AFirstIndex].StartTick) then
    begin
      raise EAudio.Create('Admitted span collapses at millisecond training resolution');
    end;
    if (LSpanIndex > AFirstIndex) and
      (LTimed[LSpanIndex - AFirstIndex].StartTick < LTimed[LSpanIndex - AFirstIndex - 1].EndTick) then
    begin
      raise EAudio.Create('Admitted spans overlap after millisecond projection');
    end;
  end;
  SetLength(ATracks, LTrackIndex + 1);
  ATracks[LTrackIndex] := LTimed;
  SetLength(ARunSources, LTrackIndex + 1);
  ARunSources[LTrackIndex] := ASourceIndex;
end;

procedure BuildTracks(const ASources: TAdmittedNoteSources;
  var ATracks: TAdmittedTrackArray; var ARunSources: TAdmittedRunSourceIndices);
var
  LSourceIndex: Integer;
  LSpanIndex: Integer;
  LRunStart: Integer;
  LSource: TAdmittedNoteSource;
begin
  ATracks := nil;
  ARunSources := nil;
  for LSourceIndex := 0 to High(ASources) do
  begin
    LSource := ASources[LSourceIndex];
    LSpanIndex := 0;
    while LSpanIndex < Length(LSource.Spans) do
    begin
      if LSource.Spans[LSpanIndex].Kind = pskUnknown then
      begin
        Inc(LSpanIndex);
        Continue;
      end;
      LRunStart := LSpanIndex;
      Inc(LSpanIndex);
      while (LSpanIndex < Length(LSource.Spans)) and
        (LSource.Spans[LSpanIndex].Kind <> pskUnknown) and
        (LSource.Spans[LSpanIndex].StartFrame = LSource.Spans[LSpanIndex - 1].EndFrame) do
      begin
        Inc(LSpanIndex);
      end;
      AppendRun(ATracks, ARunSources, LSource, LSourceIndex, LRunStart, LSpanIndex);
    end;
  end;
end;

function EvidenceText(const ASources: TAdmittedNoteSources; const ATracks: TAdmittedTrackArray;
  const AModelSha256: String; const AOrder, AGroupCount,
  ATrainingSpanCount: Integer): String;
var
  LIndex: Integer;
  LSpanIndex: Integer;
  LPreviousEnd: Int64;
  LRunIndex: Integer;
  LRunStart: Integer;
  LRunEnd: Integer;
  LRunSpanCount: Integer;
  LExpectedRunIndex: Integer;
  LSource: TAdmittedNoteSource;
  LSpan: TAdmittedNoteSpan;
  LBuilder: TMemoryStream;

  procedure AppendEvidence(const AText: String);
  begin
    if Length(AText) > 0 then
    begin
      LBuilder.WriteBuffer(AText[1], Length(AText));
    end;
  end;
begin
  LBuilder := TMemoryStream.Create;
  try
  AppendEvidence(AdmittedPitchPolicyIdentity + #10 +
    'model_timebase=integer-milliseconds;frame_projection=nearest-half-up;' + #10 +
    'unknown=excluded-hard-boundary;implicit-gap=excluded-hard-boundary;' + #10 +
    'silence=explicit-trainable-token;recording-and-group=hard-boundary;' + #10 +
    'span_kind=0:pitch,1:silence,2:unknown;' + #10 +
    'source_hashes=caller-verified-identities;annotation_hashes=reference-evidence-identities;' + #10 +
    'annotation_gaps=unknown-not-acoustic-silence;max_training_runs=32' + #10 +
    'order=' + IntToStr(AOrder) + #10 +
    'model_sha256=' + AModelSha256 + #10 +
    'source_count=' + IntToStr(Length(ASources)) + #10 +
    'training_group_count=' + IntToStr(AGroupCount) + #10 +
    'training_run_count=' + IntToStr(Length(ATracks)) + #10 +
    'training_span_count=' + IntToStr(ATrainingSpanCount) + #10 +
    'source<TAB>group_id<TAB>recording_id<TAB>source_sha256<TAB>annotation_id<TAB>annotation_sha256<TAB>annotation_publisher<TAB>annotation_method<TAB>sample_rate<TAB>source_frames' + #10);
  for LIndex := 0 to High(ASources) do
  begin
    LSource := ASources[LIndex];
    AppendEvidence('source' + #9 + LSource.GroupId + #9 + LSource.RecordingId + #9 +
      LSource.SourceSha256 + #9 + LSource.SourceAnnotationId + #9 +
      LSource.SourceAnnotationSha256 + #9 + LSource.SourceAnnotationPublisher + #9 +
      LSource.SourceAnnotationMethod + #9 +
      IntToStr(LSource.SampleRate) + #9 + IntToStr(LSource.SourceFrameCount) + #10);
    LPreviousEnd := 0;
    for LSpanIndex := 0 to High(LSource.Spans) do
    begin
      LSpan := LSource.Spans[LSpanIndex];
      if (LPreviousEnd >= 0) and (LSpan.StartFrame > LPreviousEnd) then
      begin
        AppendEvidence('excluded_gap' + #9 + LSource.GroupId + #9 + LSource.RecordingId + #9 +
          IntToStr(LPreviousEnd) + #9 + IntToStr(LSpan.StartFrame) + #10);
      end;
      AppendEvidence('span' + #9 + LSource.GroupId + #9 + LSource.RecordingId + #9 +
        IntToStr(LSpanIndex) + #9 + IntToStr(Ord(LSpan.Kind)) + #9 + IntToStr(LSpan.Note) + #9 +
        IntToStr(LSpan.StartFrame) + #9 + IntToStr(LSpan.EndFrame) + #9 +
        IntToStr(RoundAdmittedFrameToMilliseconds(LSpan.StartFrame, LSource.SampleRate)) + #9 +
        IntToStr(RoundAdmittedFrameToMilliseconds(LSpan.EndFrame, LSource.SampleRate)) + #10);
      LPreviousEnd := LSpan.EndFrame;
    end;
    if LPreviousEnd < LSource.SourceFrameCount then
    begin
      AppendEvidence('excluded_gap' + #9 + LSource.GroupId + #9 + LSource.RecordingId + #9 +
        IntToStr(LPreviousEnd) + #9 + IntToStr(LSource.SourceFrameCount) + #10);
    end;
  end;
  LRunIndex := 0;
  LExpectedRunIndex := 0;
  for LIndex := 0 to High(ASources) do
  begin
    LSpanIndex := 0;
    while LSpanIndex < Length(ASources[LIndex].Spans) do
    begin
      if ASources[LIndex].Spans[LSpanIndex].Kind = pskUnknown then
      begin
        Inc(LSpanIndex);
        Continue;
      end;
      LRunStart := LSpanIndex;
      Inc(LSpanIndex);
      while (LSpanIndex < Length(ASources[LIndex].Spans)) and
        (ASources[LIndex].Spans[LSpanIndex].Kind <> pskUnknown) and
        (ASources[LIndex].Spans[LSpanIndex].StartFrame =
          ASources[LIndex].Spans[LSpanIndex - 1].EndFrame) do
      begin
        Inc(LSpanIndex);
      end;
      LRunEnd := ASources[LIndex].Spans[LRunStart].StartFrame;
      LRunSpanCount := 0;
      while LRunStart < LSpanIndex do
      begin
        LRunEnd := ASources[LIndex].Spans[LRunStart].EndFrame;
        Inc(LRunSpanCount);
        Inc(LRunStart);
      end;
      if LExpectedRunIndex >= Length(ATracks) then
      begin
        raise EAudio.Create('Admitted run ledger disagrees with prepared training tracks');
      end;
      AppendEvidence('training_run' + #9 + IntToStr(LRunIndex) + #9 +
        ASources[LIndex].GroupId + #9 + ASources[LIndex].RecordingId + #9 +
        IntToStr(ASources[LIndex].Spans[LSpanIndex - LRunSpanCount].StartFrame) + #9 +
        IntToStr(LRunEnd) + #9 + IntToStr(LRunSpanCount) + #9 +
        IntToStr(Length(ATracks[LExpectedRunIndex])) + #10);
      Inc(LExpectedRunIndex);
      Inc(LRunIndex);
    end;
  end;
  if LExpectedRunIndex <> Length(ATracks) then
  begin
    raise EAudio.Create('Admitted run ledger omits prepared training tracks');
  end;
  SetLength(Result, LBuilder.Size);
  if Length(Result) > 0 then
  begin
    LBuilder.Position := 0;
    LBuilder.ReadBuffer(Result[1], Length(Result));
  end;
  finally
    LBuilder.Free;
  end;
end;

function CountDistinctGroups(const ASources: TAdmittedNoteSources;
  const AHasRuns: array of Boolean): Integer;
var
  LIndex: Integer;
  LOther: Integer;
  LFound: Boolean;
begin
  Result := 0;
  for LIndex := 0 to High(ASources) do
  begin
    if not AHasRuns[LIndex] then
    begin
      Continue;
    end;
    LFound := False;
    for LOther := 0 to LIndex - 1 do
    begin
      if AHasRuns[LOther] and (ASources[LOther].GroupId = ASources[LIndex].GroupId) then
      begin
        LFound := True;
        Break;
      end;
    end;
    if not LFound then
    begin
      Inc(Result);
    end;
  end;
end;

function LearnWeightedAdmittedPitchDurationModel(const ASources: TAdmittedNoteSources;
  const ASourceWeights: array of Integer; const AOrder: Integer;
  const AWeightPolicyId: String): TAdmittedPitchDurationModel;
var
  LHasRuns: array of Boolean;
  LInputSpanCount: Integer;
  LGroupCount: Integer;
  LTrainingSpanCount: Integer;
  LSourceIndex: Integer;
  LIndex: Integer;
  LTracks: TAdmittedTrackArray;
  LRunSources: TAdmittedRunSourceIndices;
  LTimedTracks: TTimedPitchTracks;
  LWeights: array of Integer;
  LModel: TWfcSequenceModel;
  LReloaded: TWfcSequenceModel;
  LModelText: String;
  LEvidence: String;
  LResult: TAdmittedPitchDurationModel;
  LTrackCount: Integer;
  LModelTokens: TWfcModelTokens;
begin
  Result := nil;
  if (Length(ASources) < 2) or (Length(ASources) > MaximumAdmittedSources) or
    (AOrder < 1) or (AOrder > 4) or
    (Length(ASourceWeights) <> Length(ASources)) then
  begin
    raise EAudio.Create('Admitted pitch learning requires 2..32 weighted sources and order 1..4');
  end;
  if (AWeightPolicyId <> '') and not ValidIdentity(AWeightPolicyId) then
  begin
    raise EAudio.Create('Admitted pitch weight policy identity is invalid');
  end;
  LInputSpanCount := 0;
  SetLength(LHasRuns, Length(ASources));
  for LSourceIndex := 0 to High(ASources) do
  begin
    ValidateSource(ASources[LSourceIndex], LInputSpanCount, LHasRuns[LSourceIndex]);
    if (ASourceWeights[LSourceIndex] < 0) or (ASourceWeights[LSourceIndex] > 64) or
      (LHasRuns[LSourceIndex] and (ASourceWeights[LSourceIndex] = 0)) then
    begin
      raise EAudio.Create('Admitted source weight must be 1..64 when it has training evidence');
    end;
    if (AWeightPolicyId = '') and (ASourceWeights[LSourceIndex] <> 1) then
    begin
      raise EAudio.Create('Non-default admitted source weights need a policy identity');
    end;
    for LIndex := 0 to LSourceIndex - 1 do
    begin
      if ASources[LIndex].RecordingId = ASources[LSourceIndex].RecordingId then
      begin
        raise EAudio.Create('Admitted recording identities must be unique');
      end;
      if ASources[LIndex].SourceSha256 = ASources[LSourceIndex].SourceSha256 then
      begin
        raise EAudio.Create('Distinct admitted recordings cannot reuse one source hash');
      end;
      if (ASources[LIndex].SourceAnnotationId = ASources[LSourceIndex].SourceAnnotationId) or
        (ASources[LIndex].SourceAnnotationSha256 = ASources[LSourceIndex].SourceAnnotationSha256) then
      begin
        raise EAudio.Create('Each admitted source needs distinct annotation evidence identity');
      end;
    end;
  end;
  LGroupCount := CountDistinctGroups(ASources, LHasRuns);
  if LGroupCount < 2 then
  begin
    raise EAudio.Create('Admitted pitch learning requires two training groups');
  end;
  BuildTracks(ASources, LTracks, LRunSources);
  LTrackCount := Length(LTracks);
  if (LTrackCount < 1) or (LTrackCount > MaximumAdmittedTrainingRuns) then
  begin
    raise EAudio.Create('Admitted pitch corpus has no run or exceeds 32 training runs');
  end;
  LTrainingSpanCount := 0;
  SetLength(LTimedTracks, LTrackCount);
  SetLength(LWeights, LTrackCount);
  for LIndex := 0 to LTrackCount - 1 do
  begin
    LTimedTracks[LIndex] := LTracks[LIndex];
    LWeights[LIndex] := ASourceWeights[LRunSources[LIndex]];
    Inc(LTrainingSpanCount, Length(LTracks[LIndex]));
  end;
  LModel := nil;
  LReloaded := nil;
  LResult := nil;
  try
    LModel := LearnPitchDurationModel(LTimedTracks, LWeights, AOrder);
    LModelText := EncodeWfcSequenceText(LModel);
    LReloaded := DecodeWfcSequenceText(LModelText);
    if EncodeWfcSequenceText(LReloaded) <> LModelText then
    begin
      raise EAudio.Create('Saved admitted pitch model does not reload canonically');
    end;
    LModelTokens := LReloaded.CopyPublicTokens;
    for LIndex := 0 to High(LModelTokens) do
    begin
      if DecodePitchDurationToken(LReloaded.PublicTokenAt(LIndex)).Kind = pskUnknown then
      begin
        raise EAudio.Create('Unknown span entered the admitted pitch model vocabulary');
      end;
    end;
    LEvidence := EvidenceText(ASources, LTracks, HashText(LModelText), AOrder,
      LGroupCount, LTrainingSpanCount);
    if AWeightPolicyId <> '' then
    begin
      LEvidence := LEvidence + 'weight_policy=' + AWeightPolicyId + #10 +
        'source_weight<TAB>group_id<TAB>recording_id<TAB>integer_run_weight' + #10;
      for LIndex := 0 to High(ASources) do
      begin
        LEvidence := LEvidence + 'source_weight' + #9 + ASources[LIndex].GroupId + #9 +
          ASources[LIndex].RecordingId + #9 + IntToStr(ASourceWeights[LIndex]) + #10;
      end;
    end;
    LResult := TAdmittedPitchDurationModel.Create;
    LResult.FModelText := LModelText;
    LResult.FEvidenceText := LEvidence;
    LResult.FModelSha256 := HashText(LModelText);
    LResult.FEvidenceSha256 := HashText(LEvidence);
    LResult.FOrder := AOrder;
    LResult.FSourceCount := Length(ASources);
    LResult.FGroupCount := LGroupCount;
    LResult.FTrainingRunCount := LTrackCount;
    LResult.FTrainingSpanCount := LTrainingSpanCount;
    Result := LResult;
    LResult := nil;
  finally
    LResult.Free;
    LReloaded.Free;
    LModel.Free;
  end;
end;

function LearnAdmittedPitchDurationModel(const ASources: TAdmittedNoteSources;
  const AOrder: Integer): TAdmittedPitchDurationModel;
var
  LWeights: array of Integer;
  LIndex: Integer;
begin
  SetLength(LWeights, Length(ASources));
  for LIndex := 0 to High(LWeights) do
  begin
    LWeights[LIndex] := 1;
  end;
  Result := LearnWeightedAdmittedPitchDurationModel(ASources, LWeights, AOrder, '');
end;

function TAdmittedPitchDurationModel.Load: TWfcSequenceModel;
var
  LModel: TWfcSequenceModel;
begin
  Result := nil;
  LModel := DecodeWfcSequenceText(FModelText);
  try
    if EncodeWfcSequenceText(LModel) <> FModelText then
    begin
      raise EAudio.Create('Admitted pitch model text is not canonical on reload');
    end;
    Result := LModel;
    LModel := nil;
  finally
    LModel.Free;
  end;
end;

function TAdmittedPitchDurationModel.TryGenerate(const AOptions: TAcousticGenerationOptions;
  const AConstraints: TWfcSequenceTokenConstraints;
  var ATokens: TWfcModelTokens; out AReport: TGraphSolveReport): Boolean;
var
  LModel: TWfcSequenceModel;
  LGenerated: TWfcModelTokens;
  LTokenIndex: Integer;
begin
  LModel := Load;
  try
    LGenerated := Copy(ATokens);
    Result := TryGenerateTokenSequence(LModel, AOptions, AConstraints, LGenerated, AReport);
    if not Result then
    begin
      Exit;
    end;
    for LTokenIndex := 0 to High(LGenerated) do
    begin
      if DecodePitchDurationToken(LGenerated[LTokenIndex]).Kind = pskUnknown then
      begin
        Result := False;
        Exit;
      end;
    end;
    ATokens := LGenerated;
  finally
    LModel.Free;
  end;
end;

end.
