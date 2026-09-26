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

unit pythian.wfc.context.profile;

{$mode delphi}
{$H+}

interface

uses
  pythian.audio,
  pythian.wfc.context,
  pythian.wfc.context.archive,
  wfc_sequence;

const
  ContextProfileVersion = 1;
  MaximumContextProfileBytes = 16 * 1024 * 1024;
  MaximumContextProfileDepth = 8;
  MaximumContextProfileNodes = 63;

type
  { Immutable source bundle or selective composition: key from one parent,
    tempo from another. Complete parent archives retain derived lineage.
    These are independent context models, with no joint or weighted blending. }
  TContextProfile = class
  private
    FBytes: TAudioBytes;
    FKeyOffset: Integer;
    FKeyLength: Integer;
    FTempoOffset: Integer;
    FTempoLength: Integer;
    FParentOffsets: array[TContextDimension] of Integer;
    FParentLengths: array[TContextDimension] of Integer;
    FTicksPerQuarter: Integer;
    FStepTicks: Integer;
    FDepth: Integer;
    FNodeCount: Integer;
    FEvidenceCells: Integer;
    FIdentity: String;
    function GetIsSelection: Boolean;
  public
    constructor Create(const ABundle: TContextLearningBundle);
    constructor CreateArchive(const ABytes: TAudioBytes);
    function CopyBundle(const ADimension: TContextDimension): TContextLearningBundle;
    function CopyModel(const ADimension: TContextDimension): TWfcSequenceModel;
    function CopyParent(const ADimension: TContextDimension): TContextProfile;
    function ParentIdentity(const ADimension: TContextDimension): String;
    function ProviderIdentity(const ADimension: TContextDimension): String;
    property TicksPerQuarter: Integer read FTicksPerQuarter;
    property StepTicks: Integer read FStepTicks;
    property Depth: Integer read FDepth;
    property NodeCount: Integer read FNodeCount;
    property EvidenceCells: Integer read FEvidenceCells;
    property Identity: String read FIdentity;
    property IsSelection: Boolean read GetIsSelection;
  end;

{ Caller owns each result. Inputs remain unchanged and may be freed afterwards.
  Selection copies providers; it never pools/reweights observations or creates
  key/tempo joint evidence. Equal PPQ and step are required across both parents. }
function SelectContextProfile(const AKeyParent, ATempoParent: TContextProfile): TContextProfile;
function EncodeContextProfile(const AProfile: TContextProfile): TAudioBytes;
{ Validates complete bounded ancestry, checks digests and replays each embedded
  context bundle's actual WFC models. No source-file access or WAV inference. }
function DecodeContextProfile(const ABytes: TAudioBytes): TContextProfile;

implementation

uses
  Math,
  SysUtils,
  pythian.hash,
  pythian.music.context;

const
  ContextProfileMagic = $31504350; { PCP1 }

type
  TProfileInfo = record
    KeyOffset: Integer;
    KeyLength: Integer;
    TempoOffset: Integer;
    TempoLength: Integer;
    ParentOffsets: array[TContextDimension] of Integer;
    ParentLengths: array[TContextDimension] of Integer;
    TicksPerQuarter: Integer;
    StepTicks: Integer;
    Depth: Integer;
  end;

procedure CheckDimension(const ADimension: TContextDimension);
begin
  if not (ADimension in [cdKey, cdTempo]) then
  begin
    raise EAudio.Create('Context profile dimension is unavailable');
  end;
end;

procedure PutNumber(var ABytes: TAudioBytes; var AOffset: Integer; const AValue: Integer);
var
  LIndex: Integer;
begin
  for LIndex := 0 to 3 do
  begin
    ABytes[AOffset + LIndex] := (Cardinal(AValue) shr (LIndex * 8)) and $FF;
  end;
  Inc(AOffset, 4);
end;

function GetNumber(const ABytes: TAudioBytes; var AOffset: Integer;
  const ALimit: Integer): Integer;
var
  LValue: Cardinal;
  LIndex: Integer;
begin
  if (AOffset < 0) or (AOffset > ALimit - 4) then
  begin
    raise EAudio.Create('Context profile field exceeds payload');
  end;
  LValue := 0;
  for LIndex := 0 to 3 do
  begin
    LValue := LValue or (Cardinal(ABytes[AOffset + LIndex]) shl (LIndex * 8));
  end;
  Inc(AOffset, 4);
  if LValue > High(Integer) then
  begin
    raise EAudio.Create('Context profile field exceeds integer bound');
  end;
  Result := Integer(LValue);
end;

function MakeArchive(const AFirst, ASecond: TAudioBytes; const ASelection: Boolean): TAudioBytes;
var
  LSize: Int64;
  LOffset: Integer;
  LBytes: TAudioBytes;
  LHash: String;
begin
  LSize := 16 + Int64(Length(AFirst));
  if ASelection then
  begin
    Inc(LSize, 4 + Int64(Length(ASecond)));
  end;
  if LSize > MaximumContextProfileBytes - 64 then
  begin
    raise EAudio.Create('Context profile exceeds 16 MiB');
  end;
  SetLength(LBytes, Integer(LSize));
  LOffset := 0;
  PutNumber(LBytes, LOffset, ContextProfileMagic);
  PutNumber(LBytes, LOffset, ContextProfileVersion);
  PutNumber(LBytes, LOffset, Ord(ASelection));
  PutNumber(LBytes, LOffset, Length(AFirst));
  if Length(AFirst) > 0 then
  begin
    Move(AFirst[0], LBytes[LOffset], Length(AFirst));
  end;
  Inc(LOffset, Length(AFirst));
  if ASelection then
  begin
    PutNumber(LBytes, LOffset, Length(ASecond));
    if Length(ASecond) > 0 then
    begin
      Move(ASecond[0], LBytes[LOffset], Length(ASecond));
    end;
  end;
  LHash := Sha256Bytes(LBytes);
  SetLength(LBytes, Integer(LSize) + 64);
  Move(LHash[1], LBytes[Integer(LSize)], 64);
  Result := LBytes;
end;

function ParseProfile(const ABytes: TAudioBytes; const AStart, ALength, ADepth: Integer;
  var ANodes, ACells: Integer): TProfileInfo;
var
  LOffset: Integer;
  LLimit: Integer;
  LKind: Integer;
  LFirstLength: Integer;
  LSecondLength: Integer;
  LFirstOffset: Integer;
  LSecondOffset: Integer;
  LFirst: TProfileInfo;
  LSecond: TProfileInfo;
  LHash: String;
  LBundle: TContextLearningBundle;
  LEvidence: TContextEvidenceArray;
  LIndex: Integer;
begin
  Result := Default(TProfileInfo);
  Inc(ANodes);
  if (ADepth > MaximumContextProfileDepth) or (ANodes > MaximumContextProfileNodes) or
    (ALength < 80) or (ALength > MaximumContextProfileBytes) or
    (AStart < 0) or (AStart > Length(ABytes) - ALength) then
  begin
    raise EAudio.Create('Context profile ancestry or byte extent exceeds budget');
  end;
  LLimit := AStart + ALength - 64;
  LHash := Sha256Bytes(Copy(ABytes, AStart, ALength - 64));
  if not CompareMem(@LHash[1], @ABytes[LLimit], 64) then
  begin
    raise EAudio.Create('Context profile digest mismatch');
  end;
  LOffset := AStart;
  if GetNumber(ABytes, LOffset, LLimit) <> ContextProfileMagic then
  begin
    raise EAudio.Create('Context profile magic mismatch');
  end;
  if GetNumber(ABytes, LOffset, LLimit) <> ContextProfileVersion then
  begin
    raise EAudio.Create('Unsupported context profile version');
  end;
  LKind := GetNumber(ABytes, LOffset, LLimit);
  if LKind > 1 then
  begin
    raise EAudio.Create('Unknown context profile operation');
  end;
  LFirstLength := GetNumber(ABytes, LOffset, LLimit);
  LFirstOffset := LOffset;
  if LFirstLength > LLimit - LOffset then
  begin
    raise EAudio.Create('Context profile child exceeds payload');
  end;
  Inc(LOffset, LFirstLength);
  if LKind = 0 then
  begin
    if LOffset <> LLimit then
    begin
      raise EAudio.Create('Trailing context source profile data');
    end;
    LBundle := DecodeContextLearning(Copy(ABytes, LFirstOffset, LFirstLength));
    try
      LEvidence := LBundle.CopyEvidence;
      for LIndex := 0 to High(LEvidence) do
      begin
        Inc(ACells, Length(LEvidence[LIndex].Grid.Keys));
        if ACells > MaximumContextCells then
        begin
          raise EAudio.Create('Context profile ancestry exceeds 65536 evidence cells');
        end;
      end;
      Result.KeyOffset := LFirstOffset;
      Result.KeyLength := LFirstLength;
      Result.TempoOffset := LFirstOffset;
      Result.TempoLength := LFirstLength;
      Result.TicksPerQuarter := LBundle.TicksPerQuarter;
      Result.StepTicks := LBundle.StepTicks;
      Result.Depth := 1;
    finally
      LBundle.Free;
    end;
  end
  else
  begin
    LSecondLength := GetNumber(ABytes, LOffset, LLimit);
    LSecondOffset := LOffset;
    if LSecondLength <> LLimit - LOffset then
    begin
      raise EAudio.Create('Context selection child or trailing extent is invalid');
    end;
    LFirst := ParseProfile(ABytes, LFirstOffset, LFirstLength, ADepth + 1, ANodes, ACells);
    LSecond := ParseProfile(ABytes, LSecondOffset, LSecondLength, ADepth + 1, ANodes, ACells);
    if (LFirst.TicksPerQuarter <> LSecond.TicksPerQuarter) or
      (LFirst.StepTicks <> LSecond.StepTicks) then
    begin
      raise EAudio.Create('Context selection requires matching PPQ and step');
    end;
    Result.KeyOffset := LFirst.KeyOffset;
    Result.KeyLength := LFirst.KeyLength;
    Result.TempoOffset := LSecond.TempoOffset;
    Result.TempoLength := LSecond.TempoLength;
    Result.ParentOffsets[cdKey] := LFirstOffset;
    Result.ParentLengths[cdKey] := LFirstLength;
    Result.ParentOffsets[cdTempo] := LSecondOffset;
    Result.ParentLengths[cdTempo] := LSecondLength;
    Result.TicksPerQuarter := LFirst.TicksPerQuarter;
    Result.StepTicks := LFirst.StepTicks;
    Result.Depth := 1 + Max(LFirst.Depth, LSecond.Depth);
  end;
end;

constructor TContextProfile.CreateArchive(const ABytes: TAudioBytes);
var
  LInfo: TProfileInfo;
begin
  inherited Create;
  LInfo := ParseProfile(ABytes, 0, Length(ABytes), 1, FNodeCount, FEvidenceCells);
  FBytes := Copy(ABytes);
  FKeyOffset := LInfo.KeyOffset;
  FKeyLength := LInfo.KeyLength;
  FTempoOffset := LInfo.TempoOffset;
  FTempoLength := LInfo.TempoLength;
  FParentOffsets[cdKey] := LInfo.ParentOffsets[cdKey];
  FParentOffsets[cdTempo] := LInfo.ParentOffsets[cdTempo];
  FParentLengths[cdKey] := LInfo.ParentLengths[cdKey];
  FParentLengths[cdTempo] := LInfo.ParentLengths[cdTempo];
  FTicksPerQuarter := LInfo.TicksPerQuarter;
  FStepTicks := LInfo.StepTicks;
  FDepth := LInfo.Depth;
  FIdentity := Sha256Bytes(FBytes);
end;

constructor TContextProfile.Create(const ABundle: TContextLearningBundle);
begin
  CreateArchive(MakeArchive(EncodeContextLearning(ABundle), nil, False));
end;

function TContextProfile.GetIsSelection: Boolean;
begin
  Result := FParentLengths[cdKey] > 0;
end;

function TContextProfile.CopyBundle(const ADimension: TContextDimension): TContextLearningBundle;
begin
  CheckDimension(ADimension);
  if ADimension = cdKey then
  begin
    Result := DecodeContextLearning(Copy(FBytes, FKeyOffset, FKeyLength));
  end
  else
  begin
    Result := DecodeContextLearning(Copy(FBytes, FTempoOffset, FTempoLength));
  end;
end;

function TContextProfile.CopyModel(const ADimension: TContextDimension): TWfcSequenceModel;
var
  LBundle: TContextLearningBundle;
begin
  LBundle := CopyBundle(ADimension);
  try
    Result := LBundle.CopyModel(ADimension);
  finally
    LBundle.Free;
  end;
end;

function TContextProfile.CopyParent(const ADimension: TContextDimension): TContextProfile;
begin
  CheckDimension(ADimension);
  if not IsSelection then
  begin
    raise EAudio.Create('A source context profile has no selection parents');
  end;
  Result := DecodeContextProfile(Copy(FBytes, FParentOffsets[ADimension], FParentLengths[ADimension]));
end;

function TContextProfile.ParentIdentity(const ADimension: TContextDimension): String;
begin
  CheckDimension(ADimension);
  if not IsSelection then
  begin
    raise EAudio.Create('A source context profile has no selection parents');
  end;
  Result := Sha256Bytes(Copy(FBytes, FParentOffsets[ADimension], FParentLengths[ADimension]));
end;

function TContextProfile.ProviderIdentity(const ADimension: TContextDimension): String;
begin
  CheckDimension(ADimension);
  if ADimension = cdKey then
  begin
    Result := Sha256Bytes(Copy(FBytes, FKeyOffset, FKeyLength));
  end
  else
  begin
    Result := Sha256Bytes(Copy(FBytes, FTempoOffset, FTempoLength));
  end;
end;

function SelectContextProfile(const AKeyParent, ATempoParent: TContextProfile): TContextProfile;
begin
  if (AKeyParent = nil) or (ATempoParent = nil) then
  begin
    raise EAudio.Create('Context selection requires both parents');
  end;
  if (AKeyParent.TicksPerQuarter <> ATempoParent.TicksPerQuarter) or
    (AKeyParent.StepTicks <> ATempoParent.StepTicks) then
  begin
    raise EAudio.Create('Context selection requires matching PPQ and step');
  end;
  if (Max(AKeyParent.Depth, ATempoParent.Depth) >= MaximumContextProfileDepth) or
    (AKeyParent.NodeCount + ATempoParent.NodeCount + 1 > MaximumContextProfileNodes) or
    (AKeyParent.EvidenceCells + ATempoParent.EvidenceCells > MaximumContextCells) then
  begin
    raise EAudio.Create('Context selection exceeds ancestry budget');
  end;
  Result := TContextProfile.CreateArchive(MakeArchive(AKeyParent.FBytes, ATempoParent.FBytes, True));
end;

function EncodeContextProfile(const AProfile: TContextProfile): TAudioBytes;
begin
  if AProfile = nil then
  begin
    raise EAudio.Create('Context profile is required');
  end;
  Result := Copy(AProfile.FBytes);
end;

function DecodeContextProfile(const ABytes: TAudioBytes): TContextProfile;
begin
  Result := TContextProfile.CreateArchive(ABytes);
end;

end.
