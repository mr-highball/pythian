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
  wfc_sequence;

const
  ContextLearningArchiveVersion = 1;
  MaximumContextArchiveBytes = 16 * 1024 * 1024;
  MaximumContextMetadataBytes = 4 * 1024 * 1024;

type
  TContextEvidence = record
    Name: UTF8String;
    SourceSha256: String;
    SourceFrameOffset: Integer; { Source frame corresponding to the clock's tick zero. }
    AdmissionPolicy: UTF8String;
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
    function GetTicksPerQuarter: Integer;
    function GetStepTicks: Integer;
  public
    constructor Create(const AEvidence: TContextEvidenceArray;
      const AKeyOrder: Integer = 2; const ATempoOrder: Integer = 2);
    destructor Destroy; override;
    function CopyEvidence: TContextEvidenceArray;
    function CopyModel(const ADimension: TContextDimension): TWfcSequenceModel;
    function ModelText(const ADimension: TContextDimension): UTF8String;
    property KeyOrder: Integer read FKeyOrder;
    property TempoOrder: Integer read FTempoOrder;
    property TicksPerQuarter: Integer read GetTicksPerQuarter;
    property StepTicks: Integer read GetStepTicks;
  end;

{ Canonical bounded binary payload and SHA256 trailer; not a signature.
  Returns detached bytes, with the original bundle unchanged on failure. }
function EncodeContextLearning(const ABundle: TContextLearningBundle): TAudioBytes;

{ Caller owns the result. Rebuilds both actual models from saved admitted grids
  and requires byte-identical canonical model text. No WAV analysis or policy
  execution occurs. Invalid input never publishes a partial bundle. }
function DecodeContextLearning(const ABytes: TAudioBytes): TContextLearningBundle;

implementation

uses
  SysUtils,
  pythian.corpus,
  pythian.hash,
  pythian.tonal,
  wfc_sequence_learn,
  wfc_sequence_text;

const
  ContextMagic = $31435450; { PTC1 }

type
  TContextCursor = record
    Bytes: TAudioBytes;
    Offset: Integer;
    Limit: Integer;
    procedure Need(const ACount: Integer);
    procedure PutNumber(const AValue: Integer);
    function GetNumber: Integer;
    procedure PutText(const AValue: UTF8String);
    function GetText(const AMaximumBytes: Integer): UTF8String;
  end;

function CloneEvidence(const AEvidence: TContextEvidenceArray): TContextEvidenceArray;
var
  LIndex: Integer;
begin
  Result := Copy(AEvidence);
  for LIndex := 0 to High(Result) do
  begin
    Result[LIndex].Grid.Keys := Copy(AEvidence[LIndex].Grid.Keys);
    Result[LIndex].Grid.Tempos := Copy(AEvidence[LIndex].Grid.Tempos);
  end;
end;

constructor TContextLearningBundle.Create(const AEvidence: TContextEvidenceArray;
  const AKeyOrder: Integer; const ATempoOrder: Integer);
var
  LGrids: TMusicContextGrids;
  LTotal: Int64;
  LMetadata: Int64;
  LIndex: Integer;
  LCharacter: Integer;
begin
  inherited Create;
  if (Length(AEvidence) < 1) or
    (Length(AEvidence) > WFC_SEQUENCE_MAX_SAMPLE_COUNT) or
    (AKeyOrder < 1) or (AKeyOrder > 4) or (ATempoOrder < 1) or (ATempoOrder > 4) then
  begin
    raise EAudio.Create('Context bundle requires 1..4096 excerpts and model orders 1..4');
  end;
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
    Inc(LMetadata, Length(AEvidence[LIndex].Name) +
      Length(AEvidence[LIndex].AdmissionPolicy) + 64);
    Inc(LTotal, Length(AEvidence[LIndex].Grid.Keys));
    if (LTotal > MaximumContextCells) or (LMetadata > MaximumContextMetadataBytes) then
    begin
      raise EAudio.Create('Context bundle exceeds observation or metadata budget');
    end;
    ValidateContextGrid(AEvidence[LIndex].Grid);
  end;
  SetLength(LGrids, Length(AEvidence));
  for LIndex := 0 to High(AEvidence) do
  begin
    LGrids[LIndex] := AEvidence[LIndex].Grid;
  end;
  FKeyModel := LearnContextModel(LGrids, cdKey, AKeyOrder);
  FTempoModel := LearnContextModel(LGrids, cdTempo, ATempoOrder);
  FEvidence := CloneEvidence(AEvidence);
  FKeyOrder := AKeyOrder;
  FTempoOrder := ATempoOrder;
end;

destructor TContextLearningBundle.Destroy;
begin
  FTempoModel.Free;
  FKeyModel.Free;
  inherited Destroy;
end;

function TContextLearningBundle.CopyEvidence: TContextEvidenceArray;
begin
  Result := CloneEvidence(FEvidence);
end;

function TContextLearningBundle.ModelText(const ADimension: TContextDimension): UTF8String;
var
  LModel: TWfcSequenceModel;
begin
  LModel := nil;
  case ADimension of
    cdKey:
    begin
      LModel := FKeyModel;
    end;
    cdTempo:
    begin
      LModel := FTempoModel;
    end;
  end;
  if LModel = nil then
  begin
    raise EAudio.Create('Context model dimension is unavailable');
  end;
  Result := EncodeWfcSequenceText(LModel);
end;

function TContextLearningBundle.CopyModel(const ADimension: TContextDimension): TWfcSequenceModel;
begin
  Result := DecodeWfcSequenceText(ModelText(ADimension));
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

procedure TContextCursor.PutNumber(const AValue: Integer);
var
  LIndex: Integer;
begin
  Need(4);
  if AValue < 0 then
  begin
    raise EAudio.Create('Context archive integer must be nonnegative');
  end;
  for LIndex := 0 to 3 do
  begin
    Bytes[Offset + LIndex] := (Cardinal(AValue) shr (8 * LIndex)) and $FF;
  end;
  Inc(Offset, 4);
end;

function TContextCursor.GetNumber: Integer;
var
  LBits: Cardinal;
  LIndex: Integer;
begin
  Need(4);
  LBits := 0;
  for LIndex := 0 to 3 do
  begin
    LBits := LBits or (Cardinal(Bytes[Offset + LIndex]) shl (8 * LIndex));
  end;
  Inc(Offset, 4);
  if LBits > High(Integer) then
  begin
    raise EAudio.Create('Context archive integer exceeds signed range');
  end;
  Result := LBits;
end;

procedure TContextCursor.PutText(const AValue: UTF8String);
begin
  PutNumber(Length(AValue));
  Need(Length(AValue));
  if AValue <> '' then
  begin
    Move(AValue[1], Bytes[Offset], Length(AValue));
  end;
  Inc(Offset, Length(AValue));
end;

function TContextCursor.GetText(const AMaximumBytes: Integer): UTF8String;
var
  LCount: Integer;
begin
  LCount := GetNumber;
  if LCount > AMaximumBytes then
  begin
    raise EAudio.Create('Context archive text exceeds its byte budget');
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

function EncodeContextLearning(const ABundle: TContextLearningBundle): TAudioBytes;
var
  LEvidence: TContextEvidenceArray;
  LKeyText: UTF8String;
  LTempoText: UTF8String;
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
  LEvidence := ABundle.CopyEvidence;
  LKeyText := ABundle.ModelText(cdKey);
  LTempoText := ABundle.ModelText(cdTempo);
  LSize := 40 + 8 + Length(LKeyText) + Length(LTempoText);
  for I := 0 to High(LEvidence) do
  begin
    Inc(LSize, 32 + Length(LEvidence[I].Name) + 64 +
      Length(LEvidence[I].AdmissionPolicy) + Int64(Length(LEvidence[I].Grid.Keys)) * 8);
  end;
  if LSize > MaximumContextArchiveBytes - 64 then
  begin
    raise EAudio.Create('Context archive exceeds 16 MiB');
  end;
  LCursor := Default(TContextCursor);
  LCursor.Limit := LSize;
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
    LCursor.PutText(UTF8String(LEvidence[I].SourceSha256));
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
  LHash := Sha256Bytes(LCursor.Bytes);
  SetLength(LCursor.Bytes, LCursor.Limit + 64);
  Move(LHash[1], LCursor.Bytes[LCursor.Limit], 64);
  Result := LCursor.Bytes;
end;

function DecodeContextLearning(const ABytes: TAudioBytes): TContextLearningBundle;
var
  LCursor: TContextCursor;
  LEvidence: TContextEvidenceArray;
  LBundle: TContextLearningBundle;
  LHash: String;
  LKeyText: UTF8String;
  LTempoText: UTF8String;
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
  LHash := Sha256Bytes(Copy(ABytes, 0, LCursor.Limit));
  for I := 1 to 64 do
  begin
    if Byte(LHash[I]) <> ABytes[LCursor.Limit + I - 1] then
    begin
      raise EAudio.Create('Context archive SHA256 mismatch');
    end;
  end;
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
    Inc(LMetadata, Length(LEvidence[I].Name) + Length(LEvidence[I].AdmissionPolicy) + 64);
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
  LBundle := TContextLearningBundle.Create(LEvidence, LKeyOrder, LTempoOrder);
  try
    if (LBundle.ModelText(cdKey) <> LKeyText) or
      (LBundle.ModelText(cdTempo) <> LTempoText) then
    begin
      raise EAudio.Create('Saved context models disagree with admitted source evidence');
    end;
    Result := LBundle;
    LBundle := nil;
  finally
    LBundle.Free;
  end;
end;

end.
