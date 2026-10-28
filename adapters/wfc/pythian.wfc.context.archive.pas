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
unit pythian.wfc.context.archive;

{$mode delphi}
{$H+}

interface

uses
  pythian.audio,
  pythian.music.context,
  pythian.wfc.context,
  pythian.progress,
  pythian.text,
  pythian.corpus.text,
  wfc_model,
  wfc_sequence;

const
  ContextLearningArchiveVersion = 1;
  MaximumContextArchiveBytes = 16 * 1024 * 1024;
  MaximumContextMetadataBytes = 4 * 1024 * 1024;

type
  TContextEvidence = record
    Name: TCorpusText;
    SourceSha256: String;
    SourceFrameOffset: Integer; { Source frame corresponding to the clock's tick zero. }
    AdmissionPolicy: TCorpusText;
    Grid: TMusicContextGrid;
  end;
  TContextEvidenceArray = array of TContextEvidence;

  { Owns copied admitted evidence and actual WFC models. Source hashes identify
    external bytes; construction does not independently verify those bytes. }
  TContextLearningBundle = class
  strict private
    FEvidence: TContextEvidenceArray;
    FKeyModel: TWfcSequenceModel;
    FTempoModel: TWfcSequenceModel;
    FKeyOrder: Integer;
    FTempoOrder: Integer;
    function ContextModel(const ADimension: TContextDimension): TWfcSequenceModel;
    function GetTicksPerQuarter: Integer;
    function GetStepTicks: Integer;
  public
    { Borrowed progress covers evidence validation/copy and actual model learning.
      An exception, including final publication, releases the private candidate. }
    constructor Create(const AEvidence: TContextEvidenceArray;
      const AKeyOrder: Integer = 2; const ATempoOrder: Integer = 2;
      const AProgress: TWorkProgressCallback = nil);
    destructor Destroy; override;
    function CopyEvidence(const AProgress: TWorkProgressCallback = nil): TContextEvidenceArray;
    function CopyModel(const ADimension: TContextDimension;
      const AProgress: TWorkProgressCallback = nil): TWfcSequenceModel;
    function ModelText(const ADimension: TContextDimension): TWfcModelToken;
    property KeyOrder: Integer read FKeyOrder;
    property TempoOrder: Integer read FTempoOrder;
    property TicksPerQuarter: Integer read GetTicksPerQuarter;
    property StepTicks: Integer read GetStepTicks;
  end;

{ Canonical bounded binary payload and SHA256 trailer; not a signature.
  Returns detached bytes, with the original bundle unchanged on failure. }
function EncodeContextLearning(const ABundle: TContextLearningBundle;
  const AProgress: TWorkProgressCallback = nil): TAudioBytes;

{ Caller owns the result. Rebuilds both actual models from saved admitted grids
  and requires byte-identical canonical model text. No WAV analysis or policy
  execution occurs. Invalid input never publishes a partial bundle. }
function DecodeContextLearning(const ABytes: TAudioBytes;
  const AProgress: TWorkProgressCallback = nil): TContextLearningBundle;

implementation

uses
  SysUtils,
  pythian.corpus,
  pythian.hash,
  pythian.binary,
  pythian.stream.bytes,
  pythian.tonal,
  wfc_sequence_learn,
  wfc_sequence_text;

const
  ContextMagic = $31435450; { PTC1 }

type
  TContextBundleProgress = class
  public
    Callback: TWorkProgressCallback;
    Pass: Integer;
    procedure ObserveGrid(const AWork: TWorkProgress);
    procedure ObserveModel(const AWork: TWfcSequencePreparationProgress);
  end;
  TContextCursor = record
    Bytes: TAudioBytes;
    Offset: Integer;
    Limit: Integer;
    NextCheckpoint: Integer;
    Progress: TWorkProgressCallback;
    Stage: String;
    procedure ObserveOffset;
    procedure Need(const ACount: Integer);
    procedure PutNumber(const AValue: Integer);
    function GetNumber: Integer;
    procedure PutText(const AValue: TScalarText);
    function GetText(const AMaximumBytes: Integer): TScalarText;
  end;

procedure TContextBundleProgress.ObserveGrid(const AWork: TWorkProgress);
begin
  ReportWork(Callback, 'context_evidence_validate_cells', wuItems,
    AWork.Done, AWork.Total, Pass);
end;

procedure TContextBundleProgress.ObserveModel(const AWork: TWfcSequencePreparationProgress);
begin
  if AWork.Phase <> wspModelBuildVisits then
  begin
    raise EAudio.Create('Unexpected WFC context-model copy phase');
  end;
  ReportWork(Callback, 'context_copy_model_visits', wuItems,
    AWork.Done, AWork.Total, Pass);
end;

function CloneEvidence(const AEvidence: TContextEvidenceArray;
  const AProgress: TWorkProgressCallback): TContextEvidenceArray;
var
  LIndex: Integer;
  LCell: Integer;
  LTotal: Integer;
  LDone: Integer;
  LCopy: TContextEvidenceArray;
begin
  LTotal := 0;
  for LIndex := 0 to High(AEvidence) do
  begin
    Inc(LTotal, Length(AEvidence[LIndex].Grid.Keys));
  end;
  ReportWork(AProgress, 'context_evidence_copy_cells', wuItems, 0, LTotal);
  LCopy := nil;
  SetLength(LCopy, Length(AEvidence));
  LDone := 0;
  for LIndex := 0 to High(LCopy) do
  begin
    LCopy[LIndex] := AEvidence[LIndex];
    LCopy[LIndex].Grid.Keys := nil;
    LCopy[LIndex].Grid.Tempos := nil;
    SetLength(LCopy[LIndex].Grid.Keys, Length(AEvidence[LIndex].Grid.Keys));
    SetLength(LCopy[LIndex].Grid.Tempos, Length(AEvidence[LIndex].Grid.Tempos));
    for LCell := 0 to High(LCopy[LIndex].Grid.Keys) do
    begin
      LCopy[LIndex].Grid.Keys[LCell] := AEvidence[LIndex].Grid.Keys[LCell];
      LCopy[LIndex].Grid.Tempos[LCell] := AEvidence[LIndex].Grid.Tempos[LCell];
      Inc(LDone);
      if Assigned(AProgress) and ((LDone mod 256) = 0) and (LDone < LTotal) then
      begin
        ReportWork(AProgress, 'context_evidence_copy_cells', wuItems, LDone, LTotal);
      end;
    end;
  end;
  ReportWork(AProgress, 'context_evidence_copy_cells', wuItems, LDone, LTotal);
  { Native managed return slots can alias a caller's array through wrappers. }
  Result := LCopy;
end;

constructor TContextLearningBundle.Create(const AEvidence: TContextEvidenceArray;
  const AKeyOrder: Integer; const ATempoOrder: Integer;
  const AProgress: TWorkProgressCallback);
var
  LGrids: TMusicContextGrids;
  LTotal: Int64;
  LMetadata: Int64;
  LIndex: Integer;
  LCharacter: Integer;
  LWork: TContextBundleProgress;
  LGridProgress: TWorkProgressCallback;
begin
  inherited Create;
  if (Length(AEvidence) < 1) or
    (Length(AEvidence) > WFC_SEQUENCE_MAX_SAMPLE_COUNT) or
    (AKeyOrder < 1) or (AKeyOrder > 4) or (ATempoOrder < 1) or (ATempoOrder > 4) then
  begin
    raise EAudio.Create('Context bundle requires 1..4096 excerpts and model orders 1..4');
  end;
  LWork := nil;
  LGridProgress := nil;
  try
    if Assigned(AProgress) then
    begin
      LWork := TContextBundleProgress.Create;
      LWork.Callback := AProgress;
      LGridProgress := LWork.ObserveGrid;
    end;
    ReportWork(AProgress, 'context_bundle_ready', wuItems, 0, 1);
    ReportWork(AProgress, 'context_evidence_rows', wuItems, 0, Length(AEvidence));
    LTotal := 0;
    LMetadata := 0;
    for LIndex := 0 to High(AEvidence) do
    begin
      ValidateCorpusText(AEvidence[LIndex].Name);
      ValidateCorpusText(AEvidence[LIndex].AdmissionPolicy);
      if AEvidence[LIndex].SourceFrameOffset < 0 then
      begin
        raise EAudio.Create('Context source frame offset must be nonnegative');
      end;
      if (AEvidence[LIndex].Name = '') or (AEvidence[LIndex].AdmissionPolicy = '') or
        (Length(AEvidence[LIndex].SourceSha256) <> 64) then
      begin
        raise EAudio.Create('Context evidence requires a name, source SHA256 and admission policy');
      end;
      for LCharacter := 1 to 64 do
      begin
        if not (AEvidence[LIndex].SourceSha256[LCharacter] in ['0'..'9', 'a'..'f']) then
        begin
          raise EAudio.Create('Context source SHA256 must be lowercase hexadecimal');
        end;
      end;
      Inc(LMetadata, ScalarTextByteCount(AEvidence[LIndex].Name, MaximumCorpusTextBytes) +
        ScalarTextByteCount(AEvidence[LIndex].AdmissionPolicy, MaximumCorpusTextBytes) + 64);
      Inc(LTotal, Length(AEvidence[LIndex].Grid.Keys));
      if (LTotal > MaximumContextCells) or (LMetadata > MaximumContextMetadataBytes) then
      begin
        raise EAudio.Create('Context bundle exceeds observation or metadata budget');
      end;
      if LWork <> nil then
      begin
        LWork.Pass := LIndex + 1;
      end;
      ValidateContextGrid(AEvidence[LIndex].Grid, LGridProgress);
      ReportWork(AProgress, 'context_evidence_rows', wuItems, LIndex + 1, Length(AEvidence));
    end;
    SetLength(LGrids, Length(AEvidence));
    for LIndex := 0 to High(AEvidence) do
    begin
      LGrids[LIndex] := AEvidence[LIndex].Grid;
    end;
    FKeyModel := LearnContextModel(LGrids, cdKey, AKeyOrder, AProgress);
    FTempoModel := LearnContextModel(LGrids, cdTempo, ATempoOrder, AProgress);
    FEvidence := CloneEvidence(AEvidence, AProgress);
    FKeyOrder := AKeyOrder;
    FTempoOrder := ATempoOrder;
    ReportWork(AProgress, 'context_bundle_ready', wuItems, 1, 1);
  finally
    LWork.Free;
  end;
end;

destructor TContextLearningBundle.Destroy;
begin
  FTempoModel.Free;
  FKeyModel.Free;
  inherited Destroy;
end;

function TContextLearningBundle.CopyEvidence(
  const AProgress: TWorkProgressCallback): TContextEvidenceArray;
begin
  Result := CloneEvidence(FEvidence, AProgress);
end;

function TContextLearningBundle.ContextModel(
  const ADimension: TContextDimension): TWfcSequenceModel;
begin
  Result := nil;
  case ADimension of
    cdKey:
    begin
      Result := FKeyModel;
    end;
    cdTempo:
    begin
      Result := FTempoModel;
    end;
  end;
  if Result = nil then
  begin
    raise EAudio.Create('Context model dimension is unavailable');
  end;
end;

function TContextLearningBundle.ModelText(const ADimension: TContextDimension): TWfcModelToken;
begin
  Result := EncodeWfcSequenceText(ContextModel(ADimension));
end;

function TContextLearningBundle.CopyModel(const ADimension: TContextDimension;
  const AProgress: TWorkProgressCallback): TWfcSequenceModel;
var
  LModel: TWfcSequenceModel;
  LWork: TContextBundleProgress;
  LObserver: TWfcSequencePreparationObserver;
begin
  LModel := ContextModel(ADimension);
  LWork := nil;
  LObserver := nil;
  try
    if Assigned(AProgress) then
    begin
      LWork := TContextBundleProgress.Create;
      LWork.Callback := AProgress;
      LWork.Pass := Ord(ADimension) + 1;
      LObserver := LWork.ObserveModel;
    end;
    Result := TWfcSequenceModel.Create(LModel.Order, LModel.CopySampleLengths,
      LModel.CopyPublicTokens, LModel.CopyStates, LModel.CopyStateCounts,
      LModel.CopyStartCounts, LModel.CopyEndCounts, LModel.Boundary, LObserver);
  finally
    LWork.Free;
  end;
end;

function TContextLearningBundle.GetTicksPerQuarter: Integer;
begin
  Result := FEvidence[0].Grid.TicksPerQuarter;
end;

function TContextLearningBundle.GetStepTicks: Integer;
begin
  Result := FEvidence[0].Grid.StepTicks;
end;

procedure TContextCursor.Need(const ACount: Integer);
begin
  if (ACount < 0) or (ACount > Limit - Offset) then
  begin
    raise EAudio.Create('Context archive field exceeds payload extent');
  end;
end;

procedure TContextCursor.ObserveOffset;
begin
  if Assigned(Progress) and (Offset >= NextCheckpoint) and (Offset < Limit) then
  begin
    ReportWork(Progress, Stage, wuBytes, Offset, Limit);
    NextCheckpoint := Offset + 8192;
  end;
end;

procedure TContextCursor.PutNumber(const AValue: Integer);
begin
  Need(4);
  if AValue < 0 then
  begin
    raise EAudio.Create('Context archive integer must be nonnegative');
  end;
  WriteUInt32LE(Bytes, Offset, AValue);
  Inc(Offset, 4);
  ObserveOffset;
end;

function TContextCursor.GetNumber: Integer;
var
  LBits: Cardinal;
begin
  Need(4);
  LBits := ReadUInt32LE(Bytes, Offset);
  Inc(Offset, 4);
  if LBits > High(Integer) then
  begin
    raise EAudio.Create('Context archive integer exceeds signed range');
  end;
  Result := LBits;
  ObserveOffset;
end;

procedure TContextCursor.PutText(const AValue: TScalarText);
var
  LBytes: TAudioBytes;
  LStream: TAudioBytesReadStream;
  LDone: Integer;
  LBlock: Integer;
begin
  LBytes := EncodeUTF8Text(AValue, MaximumContextArchiveBytes, True, True, Progress);
  PutNumber(Length(LBytes));
  Need(Length(LBytes));
  LStream := TAudioBytesReadStream.Create(LBytes);
  try
    LDone := 0;
    while LDone < Length(LBytes) do
    begin
      LBlock := Length(LBytes) - LDone;
      if LBlock > 8192 then LBlock := 8192;
      if ReadStreamBytes(LStream, Bytes, Offset, LBlock) <> LBlock then
      begin
        raise EAudio.Create('Incomplete context text byte copy');
      end;
      Inc(LDone, LBlock);
      Inc(Offset, LBlock);
      ObserveOffset;
    end;
  finally
    LStream.Free;
  end;
  ObserveOffset;
end;

function TContextCursor.GetText(const AMaximumBytes: Integer): TScalarText;
var
  LCount: Integer;
begin
  LCount := GetNumber;
  if LCount > AMaximumBytes then
  begin
    raise EAudio.Create('Context archive text exceeds its byte budget');
  end;
  Need(LCount);
  Result := DecodeUTF8Text(Copy(Bytes, Offset, LCount), AMaximumBytes, True, True, Progress);
  Inc(Offset, LCount);
  ObserveOffset;
end;

function EncodeContextLearning(const ABundle: TContextLearningBundle;
  const AProgress: TWorkProgressCallback): TAudioBytes;
var
  LEvidence: TContextEvidenceArray;
  LKeyText: TWfcModelToken;
  LTempoText: TWfcModelToken;
  LHash: String;
  LSize: Int64;
  LCursor: TContextCursor;
  LKey: TKeyContext;
  I: Integer;
  J: Integer;
begin
  if ABundle = nil then
  begin
    raise EAudio.Create('Context archive requires a learning bundle');
  end;
  ReportWork(AProgress, 'context_archive_encode_ready', wuItems, 0, 1);
  LEvidence := ABundle.CopyEvidence(AProgress);
  LKeyText := ABundle.ModelText(cdKey);
  LTempoText := ABundle.ModelText(cdTempo);
  LSize := 40 + 8 + ScalarTextByteCount(LKeyText, MaximumContextArchiveBytes, True, True, AProgress) +
    ScalarTextByteCount(LTempoText, MaximumContextArchiveBytes, True, True, AProgress);
  for I := 0 to High(LEvidence) do
  begin
    Inc(LSize, 32 + ScalarTextByteCount(LEvidence[I].Name, MaximumCorpusTextBytes) + 64 +
      ScalarTextByteCount(LEvidence[I].AdmissionPolicy, MaximumCorpusTextBytes) +
      Int64(Length(LEvidence[I].Grid.Keys)) * 8);
  end;
  if LSize > MaximumContextArchiveBytes - 64 then
  begin
    raise EAudio.Create('Context archive exceeds 16 MiB');
  end;
  LCursor := Default(TContextCursor);
  LCursor.Limit := LSize;
  LCursor.Progress := AProgress;
  LCursor.Stage := 'context_archive_encode_bytes';
  LCursor.NextCheckpoint := 8192;
  ReportWork(AProgress, LCursor.Stage, wuBytes, 0, LCursor.Limit);
  SetLength(LCursor.Bytes, LCursor.Limit);
  LCursor.PutNumber(ContextMagic);
  LCursor.PutNumber(ContextLearningArchiveVersion);
  LCursor.PutNumber(MusicContextVersion);
  LCursor.PutNumber(WfcMusicContextVersion);
  LCursor.PutNumber(WFC_SEQUENCE_MODEL_VERSION);
  LCursor.PutNumber(WFC_SEQUENCE_LEARN_ALGORITHM_VERSION);
  LCursor.PutNumber(WFC_SEQUENCE_TEXT_VERSION);
  LCursor.PutNumber(ABundle.KeyOrder);
  LCursor.PutNumber(ABundle.TempoOrder);
  LCursor.PutNumber(Length(LEvidence));
  for I := 0 to High(LEvidence) do
  begin
    LCursor.PutText(LEvidence[I].Name);
    LCursor.PutText(LEvidence[I].SourceSha256);
    LCursor.PutNumber(LEvidence[I].SourceFrameOffset);
    LCursor.PutText(LEvidence[I].AdmissionPolicy);
    LCursor.PutNumber(LEvidence[I].Grid.TicksPerQuarter);
    LCursor.PutNumber(LEvidence[I].Grid.StartTick);
    LCursor.PutNumber(LEvidence[I].Grid.StepTicks);
    LCursor.PutNumber(Length(LEvidence[I].Grid.Keys));
    for J := 0 to High(LEvidence[I].Grid.Keys) do
    begin
      LKey := LEvidence[I].Grid.Keys[J];
      if LKey.Root = -1 then
      begin
        LCursor.PutNumber(24);
      end
      else
      begin
        LCursor.PutNumber(LKey.Root * 2 + Ord(LKey.Mode));
      end;
      LCursor.PutNumber(LEvidence[I].Grid.Tempos[J]);
    end;
  end;
  LCursor.PutText(LKeyText);
  LCursor.PutText(LTempoText);
  if LCursor.Offset <> LCursor.Limit then
  begin
    raise EAudio.Create('Context archive size mismatch');
  end;
  ReportWork(AProgress, LCursor.Stage, wuBytes, LCursor.Offset, LCursor.Limit);
  LHash := Sha256Bytes(LCursor.Bytes, AProgress);
  SetLength(LCursor.Bytes, LCursor.Limit + 64);
  WriteSha256Hex(LCursor.Bytes, LCursor.Limit, LHash);
  ReportWork(AProgress, 'context_archive_encode_ready', wuItems, 1, 1);
  Result := LCursor.Bytes;
end;

function DecodeContextLearning(const ABytes: TAudioBytes;
  const AProgress: TWorkProgressCallback): TContextLearningBundle;
var
  LCursor: TContextCursor;
  LEvidence: TContextEvidenceArray;
  LBundle: TContextLearningBundle;
  LHash: String;
  LKeyText: TWfcModelToken;
  LTempoText: TWfcModelToken;
  LKeyOrder: Integer;
  LTempoOrder: Integer;
  LCount: Integer;
  LCells: Integer;
  LTotal: Integer;
  LCode: Integer;
  LMetadata: Integer;
  I: Integer;
  J: Integer;
begin
  if (Length(ABytes) < 112) or (Length(ABytes) > MaximumContextArchiveBytes) then
  begin
    raise EAudio.Create('Context archive byte extent is invalid');
  end;
  LCursor := Default(TContextCursor);
  LCursor.Bytes := ABytes;
  LCursor.Limit := Length(ABytes) - 64;
  LCursor.Progress := AProgress;
  LCursor.Stage := 'context_archive_decode_bytes';
  LCursor.NextCheckpoint := 8192;
  ReportWork(AProgress, 'context_archive_decode_ready', wuItems, 0, 1);
  LHash := Sha256Bytes(Copy(ABytes, 0, LCursor.Limit), AProgress);
  if not Sha256HexMatches(ABytes, LCursor.Limit, LHash) then
  begin
    raise EAudio.Create('Context archive SHA256 mismatch');
  end;
  ReportWork(AProgress, LCursor.Stage, wuBytes, 0, LCursor.Limit);
  if (LCursor.GetNumber <> ContextMagic) or
    (LCursor.GetNumber <> ContextLearningArchiveVersion) or
    (LCursor.GetNumber <> MusicContextVersion) or
    (LCursor.GetNumber <> WfcMusicContextVersion) or
    (LCursor.GetNumber <> WFC_SEQUENCE_MODEL_VERSION) or
    (LCursor.GetNumber <> WFC_SEQUENCE_LEARN_ALGORITHM_VERSION) or
    (LCursor.GetNumber <> WFC_SEQUENCE_TEXT_VERSION) then
  begin
    raise EAudio.Create('Unsupported context archive contract version');
  end;
  LKeyOrder := LCursor.GetNumber;
  LTempoOrder := LCursor.GetNumber;
  if (LKeyOrder < 1) or (LKeyOrder > 4) or (LTempoOrder < 1) or (LTempoOrder > 4) then
  begin
    raise EAudio.Create('Unsupported context model order');
  end;
  LCount := LCursor.GetNumber;
  if (LCount < 1) or (LCount > WFC_SEQUENCE_MAX_SAMPLE_COUNT) then
  begin
    raise EAudio.Create('Context archive excerpt count exceeds bounds');
  end;
  LCursor.Need(LCount * 28);
  SetLength(LEvidence, LCount);
  LTotal := 0;
  LMetadata := 0;
  for I := 0 to LCount - 1 do
  begin
    LEvidence[I].Name := LCursor.GetText(MaximumCorpusTextBytes);
    LEvidence[I].SourceSha256 := String(LCursor.GetText(64));
    LEvidence[I].SourceFrameOffset := LCursor.GetNumber;
    LEvidence[I].AdmissionPolicy := LCursor.GetText(MaximumCorpusTextBytes);
    Inc(LMetadata, ScalarTextByteCount(LEvidence[I].Name, MaximumCorpusTextBytes) +
      ScalarTextByteCount(LEvidence[I].AdmissionPolicy, MaximumCorpusTextBytes) + 64);
    if LMetadata > MaximumContextMetadataBytes then
    begin
      raise EAudio.Create('Context archive metadata budget exceeded');
    end;
    LEvidence[I].Grid.TicksPerQuarter := LCursor.GetNumber;
    LEvidence[I].Grid.StartTick := LCursor.GetNumber;
    LEvidence[I].Grid.StepTicks := LCursor.GetNumber;
    LCells := LCursor.GetNumber;
    if (LCells < 1) or (LCells > MaximumContextCells - LTotal) then
    begin
      raise EAudio.Create('Context archive cell count exceeds observation budget');
    end;
    Inc(LTotal, LCells);
    LCursor.Need(LCells * 8);
    SetLength(LEvidence[I].Grid.Keys, LCells);
    SetLength(LEvidence[I].Grid.Tempos, LCells);
    for J := 0 to LCells - 1 do
    begin
      LCode := LCursor.GetNumber;
      if LCode = 24 then
      begin
        LEvidence[I].Grid.Keys[J] := MakeKeyContext(-1, dmMajor);
      end
      else if LCode < 24 then
      begin
        LEvidence[I].Grid.Keys[J] := MakeKeyContext(LCode div 2, TDiatonicMode(LCode mod 2));
      end
      else
      begin
        raise EAudio.Create('Context archive key code is invalid');
      end;
      LEvidence[I].Grid.Tempos[J] := LCursor.GetNumber;
    end;
  end;
  LKeyText := LCursor.GetText(WFC_SEQUENCE_MAX_ENCODED_TEXT_LENGTH);
  LTempoText := LCursor.GetText(WFC_SEQUENCE_MAX_ENCODED_TEXT_LENGTH);
  if LCursor.Offset <> LCursor.Limit then
  begin
    raise EAudio.Create('Context archive has trailing payload bytes');
  end;
  ReportWork(AProgress, LCursor.Stage, wuBytes, LCursor.Offset, LCursor.Limit);
  LBundle := TContextLearningBundle.Create(LEvidence, LKeyOrder, LTempoOrder, AProgress);
  try
    if (LBundle.ModelText(cdKey) <> LKeyText) or
      (LBundle.ModelText(cdTempo) <> LTempoText) then
    begin
      raise EAudio.Create('Saved context models disagree with admitted source evidence');
    end;
    ReportWork(AProgress, 'context_archive_decode_ready', wuItems, 1, 1);
    Result := LBundle;
    LBundle := nil;
  finally
    LBundle.Free;
  end;
end;

end.
