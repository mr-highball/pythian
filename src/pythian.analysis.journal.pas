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

unit pythian.analysis.journal;

{$mode delphi}
{$H+}

interface

uses
  Classes,
  pythian.audio,
  pythian.analysis,
  pythian.analysis.wave;

const
  MaximumFeatureJournalBatch = 4096;

type
  TFeatureJournalBinding = record
    SourceSha256: String;
    SampleRate: Integer;
    Channels: Integer;
    FrameCount: Int64;
    Options: TAnalysisOptions;
  end;

  TFeatureJournalFlush = procedure of object;

  { Borrows a seekable stream exclusively from byte zero. Flush must commit
    writes to the caller's storage before returning; a memory stream may use
    an explicit no-op. Calls are sequential and non-reentrant. The source hash
    is supplied/verified by the caller, never inferred from a pathname.
    Opening scans bounded records without mutation. Only incomplete final
    records are recoverable; complete corrupt records reject. }
  TFeatureJournal = class
  strict private
    FStream: TStream;
    FFlush: TFeatureJournalFlush;
    FBinding: TFeatureJournalBinding;
    FHeaderHash: String;
    FLastHash: String;
    FNextFeature: Int64;
    FTotalFeatures: Int64;
    FValidBytes: Int64;
    FExpectedSize: Int64;
    FReadPosition: Int64;
    FReadNext: Int64;
    FReadHash: String;
    FFailed: Boolean;
    FBusy: Boolean;
    function DecodeRecord(const APosition, ANext: Int64; const APrevious: String;
      out ABatch: TWaveFeatureBatch; out AHash: String; out AEnd: Int64): Boolean;
    procedure CheckAvailable;
    function GetTailBytes: Int64;
    function GetCompleted: Boolean;
  public
    constructor Create(const AStream: TStream; const ABinding: TFeatureJournalBinding;
      const AFlush: TFeatureJournalFlush; const ACreateNew: Boolean);
    { Complete validation precedes writes. Write/flush failure poisons this
      instance; reopen to discover the last complete committed record. }
    procedure Append(const ABatch: TWaveFeatureBatch);
    { Explicitly drops only a previously scanned incomplete final record. }
    procedure RecoverTail;
    procedure Rewind;
    function ReadNext(var ABatch: TWaveFeatureBatch): Boolean;
    property NextFeature: Int64 read FNextFeature;
    property Binding: TFeatureJournalBinding read FBinding;
    property TotalFeatures: Int64 read FTotalFeatures;
    property TailBytes: Int64 read GetTailBytes;
    property Completed: Boolean read GetCompleted;
    property Failed: Boolean read FFailed;
  end;

implementation

uses
  SysUtils,
  Math,
  pythian.hash,
  pythian.learning;

const
  CHeaderBytes = 172;
  CRecordHeaderBytes = 140;
  CFeatureBytes = 136;
  CHashBytes = 64;
  CMagic: AnsiString = 'PYAFJ001';

procedure PutNumber(var ABytes: TAudioBytes; var AOffset: Integer;
  const AValue: QWord; const AWidth: Integer);
var
  LIndex: Integer;
begin
  for LIndex := 0 to AWidth - 1 do
  begin
    ABytes[AOffset] := (AValue shr (LIndex * 8)) and $FF;
    Inc(AOffset);
  end;
end;

function GetNumber(const ABytes: TAudioBytes; var AOffset: Integer;
  const AWidth: Integer): QWord;
var
  LIndex: Integer;
begin
  Result := 0;
  for LIndex := 0 to AWidth - 1 do
  begin
    Result := Result or (QWord(ABytes[AOffset]) shl (LIndex * 8));
    Inc(AOffset);
  end;
end;

procedure PutReal(var ABytes: TAudioBytes; var AOffset: Integer; const AValue: Double);
var
  LBits: QWord;
begin
  RequireFinite(AValue, 'Journal feature value');
  Move(AValue, LBits, SizeOf(LBits));
  PutNumber(ABytes, AOffset, LBits, 8);
end;

function GetReal(const ABytes: TAudioBytes; var AOffset: Integer): Double;
var
  LBits: QWord;
begin
  LBits := GetNumber(ABytes, AOffset, 8);
  if (LBits and QWord($7FF0000000000000)) = QWord($7FF0000000000000) then
  begin
    raise EAudio.Create('Nonfinite journal value');
  end;
  Move(LBits, Result, SizeOf(Result));
end;

procedure PutText(var ABytes: TAudioBytes; var AOffset: Integer; const AValue: AnsiString);
begin
  if AValue <> '' then
  begin
    Move(AValue[1], ABytes[AOffset], Length(AValue));
    Inc(AOffset, Length(AValue));
  end;
end;

function TextAt(const ABytes: TAudioBytes; const AOffset, ACount: Integer): AnsiString;
begin
  SetLength(Result, ACount);
  if ACount > 0 then
  begin
    Move(ABytes[AOffset], Result[1], ACount);
  end;
end;

function Header(const ABinding: TFeatureJournalBinding): TAudioBytes;
var
  LOffset: Integer;
  LCount: Integer;
  LWork: Int64;
  LIndex: Integer;
  LHash: String;
begin
  ValidateAudioFormat(ABinding.SampleRate, ABinding.Channels);
  PlanAudioAnalysis(0, ABinding.Channels, ABinding.Options, LCount, LWork);
  if (ABinding.FrameCount < 0) or (Length(ABinding.SourceSha256) <> 64) then
  begin
    raise EAudio.Create('Invalid feature journal source identity');
  end;
  for LIndex := 1 to Length(ABinding.SourceSha256) do
  begin
    if not (ABinding.SourceSha256[LIndex] in ['0'..'9', 'a'..'f']) then
    begin
      raise EAudio.Create('Journal source digest must be lowercase SHA256');
    end;
  end;
  Result := nil;
  SetLength(Result, CHeaderBytes - CHashBytes);
  LOffset := 0;
  PutText(Result, LOffset, CMagic);
  PutNumber(Result, LOffset, AnalysisVersion, 4);
  PutNumber(Result, LOffset, ABinding.SampleRate, 4);
  PutNumber(Result, LOffset, ABinding.Channels, 4);
  PutNumber(Result, LOffset, ABinding.FrameCount, 8);
  PutText(Result, LOffset, ABinding.SourceSha256);
  PutNumber(Result, LOffset, ABinding.Options.WindowFrames, 4);
  PutNumber(Result, LOffset, ABinding.Options.HopFrames, 4);
  PutReal(Result, LOffset, ABinding.Options.SilenceRms);
  LHash := Sha256Bytes(Result);
  SetLength(Result, CHeaderBytes);
  PutText(Result, LOffset, LHash);
end;

procedure ValidateBatch(const ABatch: TWaveFeatureBatch;
  const ABinding: TFeatureJournalBinding; const ANext, ATotal: Int64);
var
  LIndex: Integer;
  LPitch: Integer;
  LFeature: TAudioFeature;
  LStart: Int64;
  LSum: Double;
  LCount: Integer;
begin
  LCount := Length(ABatch.Features);
  if (LCount < 1) or (LCount > MaximumFeatureJournalBatch) or
    (ANext > ATotal) or (LCount > ATotal - ANext) or
    (ABatch.FirstFeature <> ANext) or
    (ABatch.NextFeature <> ANext + LCount) or
    (ABatch.Completed <> (ABatch.NextFeature = ATotal)) then
  begin
    raise EAudio.Create('Journal batch must continue the next observation exactly once');
  end;
  if ABatch.SourceStartFrame <> ANext * ABinding.Options.HopFrames then
  begin
    raise EAudio.Create('Journal batch source origin differs');
  end;
  for LIndex := 0 to LCount - 1 do
  begin
    LFeature := ABatch.Features[LIndex];
    LStart := ABatch.SourceStartFrame + Int64(LIndex) * ABinding.Options.HopFrames;
    AcousticVector(LFeature);
    RequireFinite(LFeature.Peak, 'Journal feature peak');
    if (LFeature.StartFrame <> LIndex * ABinding.Options.HopFrames) or
      (LFeature.ValidFrames <> Min(Int64(ABinding.Options.WindowFrames),
        ABinding.FrameCount - LStart)) or
      (LFeature.ValidFrames < 1) or (LFeature.Peak < 0) or
      (LFeature.Peak > MaxSingle) or
      (LFeature.Rms > LFeature.Peak + 1E-9 * Max(1, LFeature.Peak)) or
      (LFeature.CentroidHz > ABinding.SampleRate / 2 + 1E-6) or
      (LFeature.Silent <> (LFeature.Rms <= ABinding.Options.SilenceRms)) then
    begin
      raise EAudio.Create('Journal feature geometry or measurement differs');
    end;
    LSum := 0;
    for LPitch := 0 to 11 do
    begin
      LSum := LSum + LFeature.Chroma[LPitch];
    end;
    if ((LSum <> 0) and (Abs(LSum - 1) > 1E-9)) or
      (LFeature.Silent and ((LSum <> 0) or (LFeature.CentroidHz <> 0) or
      (LFeature.Flux <> 0))) then
    begin
      raise EAudio.Create('Journal chroma or silence fields differ');
    end;
  end;
end;

constructor TFeatureJournal.Create(const AStream: TStream;
  const ABinding: TFeatureJournalBinding; const AFlush: TFeatureJournalFlush;
  const ACreateNew: Boolean);
var
  LHeader: TAudioBytes;
  LStored: TAudioBytes;
  LBatch: TWaveFeatureBatch;
  LHash: String;
  LEnd: Int64;
begin
  inherited Create;
  if (AStream = nil) or not Assigned(AFlush) then
  begin
    raise EAudio.Create('Journal requires an exclusive stream and commit callback');
  end;
  LHeader := Header(ABinding);
  FStream := AStream;
  FFlush := AFlush;
  FBinding := ABinding;
  FHeaderHash := TextAt(LHeader, CHeaderBytes - CHashBytes, CHashBytes);
  FLastHash := FHeaderHash;
  FTotalFeatures := FBinding.FrameCount div FBinding.Options.HopFrames;
  if FBinding.FrameCount mod FBinding.Options.HopFrames <> 0 then
  begin
    Inc(FTotalFeatures);
  end;
  if ACreateNew then
  begin
    if FStream.Size <> 0 then
    begin
      raise EAudio.Create('New feature journal requires an empty stream');
    end;
    FStream.Position := 0;
    FStream.WriteBuffer(LHeader[0], Length(LHeader));
    FFlush;
  end
  else
  begin
    if FStream.Size < CHeaderBytes then
    begin
      raise EAudio.Create('Incomplete journal header; no source-bound progress is recoverable');
    end;
    SetLength(LStored, CHeaderBytes);
    FStream.Position := 0;
    FStream.ReadBuffer(LStored[0], Length(LStored));
    if not CompareMem(@LStored[0], @LHeader[0], CHeaderBytes) then
    begin
      raise EAudio.Create('Journal source, options, analysis contract or header integrity differs');
    end;
  end;
  FExpectedSize := FStream.Size;
  FValidBytes := CHeaderBytes;
  while FValidBytes < FExpectedSize do
  begin
    if not DecodeRecord(FValidBytes, FNextFeature, FLastHash, LBatch, LHash, LEnd) then
    begin
      Break;
    end;
    FNextFeature := LBatch.NextFeature;
    FLastHash := LHash;
    FValidBytes := LEnd;
  end;
  Rewind;
end;

procedure TFeatureJournal.CheckAvailable;
begin
  if FFailed then
  begin
    raise EAudio.Create('Feature journal failed; reopen to recover');
  end;
  if FBusy or (FStream.Size <> FExpectedSize) then
  begin
    FFailed := True;
    raise EAudio.Create('Feature journal reentered or borrowed stream changed');
  end;
end;

function TFeatureJournal.GetTailBytes: Int64;
begin
  Result := FExpectedSize - FValidBytes;
end;

function TFeatureJournal.GetCompleted: Boolean;
begin
  Result := not FFailed and (FNextFeature = FTotalFeatures) and (TailBytes = 0);
end;

function TFeatureJournal.DecodeRecord(const APosition, ANext: Int64;
  const APrevious: String; out ABatch: TWaveFeatureBatch;
  out AHash: String; out AEnd: Int64): Boolean;
var
  LBytes: TAudioBytes;
  LHead: TAudioBytes;
  LOffset: Integer;
  LCount: QWord;
  LFirst: QWord;
  LPayloadBytes: Integer;
  LIndex: Integer;
  LPitch: Integer;
  LFlag: QWord;
begin
  Result := False;
  if FExpectedSize - APosition < CRecordHeaderBytes then
  begin
    Exit;
  end;
  SetLength(LHead, CRecordHeaderBytes);
  FStream.Position := APosition;
  FStream.ReadBuffer(LHead[0], Length(LHead));
  if Sha256Bytes(Copy(LHead, 0, CRecordHeaderBytes - CHashBytes)) <>
    TextAt(LHead, CRecordHeaderBytes - CHashBytes, CHashBytes) then
  begin
    raise EAudio.Create('Journal record header checksum differs');
  end;
  LOffset := 0;
  LFirst := GetNumber(LHead, LOffset, 8);
  LCount := GetNumber(LHead, LOffset, 4);
  if (LFirst <> QWord(ANext)) or (LCount < 1) or
    (LCount > MaximumFeatureJournalBatch) or
    (LCount > QWord(FTotalFeatures - ANext)) or
    (TextAt(LHead, LOffset, CHashBytes) <> APrevious) then
  begin
    raise EAudio.Create('Journal record order, chain or count differs');
  end;
  LPayloadBytes := Integer(LCount) * CFeatureBytes;
  if FExpectedSize - APosition - CRecordHeaderBytes < LPayloadBytes + CHashBytes then
  begin
    Exit;
  end;
  LBytes := Copy(LHead);
  SetLength(LBytes, CRecordHeaderBytes + LPayloadBytes + CHashBytes);
  FStream.ReadBuffer(LBytes[CRecordHeaderBytes], LPayloadBytes + CHashBytes);
  AHash := TextAt(LBytes, Length(LBytes) - CHashBytes, CHashBytes);
  SetLength(LBytes, Length(LBytes) - CHashBytes);
  if Sha256Bytes(LBytes) <> AHash then
  begin
    raise EAudio.Create('Complete journal batch checksum differs');
  end;
  ABatch := Default(TWaveFeatureBatch);
  ABatch.FirstFeature := ANext;
  ABatch.NextFeature := ANext + Integer(LCount);
  ABatch.SourceStartFrame := ANext * FBinding.Options.HopFrames;
  ABatch.Completed := ABatch.NextFeature = FTotalFeatures;
  SetLength(ABatch.Features, Integer(LCount));
  LOffset := CRecordHeaderBytes;
  for LIndex := 0 to High(ABatch.Features) do
  begin
    ABatch.Features[LIndex].StartFrame := LIndex * FBinding.Options.HopFrames;
    LFlag := GetNumber(LBytes, LOffset, 4);
    if LFlag > QWord(FBinding.Options.WindowFrames) then
    begin
      raise EAudio.Create('Journal valid-frame count exceeds window');
    end;
    ABatch.Features[LIndex].ValidFrames := Integer(LFlag);
    LFlag := GetNumber(LBytes, LOffset, 4);
    if LFlag > 1 then
    begin
      raise EAudio.Create('Journal silence flag differs');
    end;
    ABatch.Features[LIndex].Silent := LFlag = 1;
    ABatch.Features[LIndex].Rms := GetReal(LBytes, LOffset);
    ABatch.Features[LIndex].Peak := GetReal(LBytes, LOffset);
    ABatch.Features[LIndex].CentroidHz := GetReal(LBytes, LOffset);
    ABatch.Features[LIndex].Flux := GetReal(LBytes, LOffset);
    for LPitch := 0 to 11 do
    begin
      ABatch.Features[LIndex].Chroma[LPitch] := GetReal(LBytes, LOffset);
    end;
  end;
  ValidateBatch(ABatch, FBinding, ANext, FTotalFeatures);
  AEnd := APosition + Length(LBytes) + CHashBytes;
  Result := True;
end;

procedure TFeatureJournal.Append(const ABatch: TWaveFeatureBatch);
var
  LBytes: TAudioBytes;
  LOffset: Integer;
  LIndex: Integer;
  LPitch: Integer;
  LHash: String;
  LHeadHash: String;
  LFeature: TAudioFeature;
  LNext: Int64;
begin
  CheckAvailable;
  if TailBytes <> 0 then
  begin
    raise EAudio.Create('Recover incomplete journal tail before appending');
  end;
  ValidateBatch(ABatch, FBinding, FNextFeature, FTotalFeatures);
  LNext := ABatch.NextFeature;
  SetLength(LBytes, CRecordHeaderBytes - CHashBytes);
  LOffset := 0;
  PutNumber(LBytes, LOffset, ABatch.FirstFeature, 8);
  PutNumber(LBytes, LOffset, Length(ABatch.Features), 4);
  PutText(LBytes, LOffset, FLastHash);
  LHeadHash := Sha256Bytes(LBytes);
  SetLength(LBytes, CRecordHeaderBytes + Length(ABatch.Features) * CFeatureBytes);
  PutText(LBytes, LOffset, LHeadHash);
  for LIndex := 0 to High(ABatch.Features) do
  begin
    LFeature := ABatch.Features[LIndex];
    PutNumber(LBytes, LOffset, LFeature.ValidFrames, 4);
    PutNumber(LBytes, LOffset, Ord(LFeature.Silent), 4);
    PutReal(LBytes, LOffset, LFeature.Rms);
    PutReal(LBytes, LOffset, LFeature.Peak);
    PutReal(LBytes, LOffset, LFeature.CentroidHz);
    PutReal(LBytes, LOffset, LFeature.Flux);
    for LPitch := 0 to 11 do
    begin
      PutReal(LBytes, LOffset, LFeature.Chroma[LPitch]);
    end;
  end;
  LHash := Sha256Bytes(LBytes);
  SetLength(LBytes, Length(LBytes) + CHashBytes);
  PutText(LBytes, LOffset, LHash);
  if FValidBytes > High(Int64) - Length(LBytes) then
  begin
    raise EAudio.Create('Journal file extent exceeds Int64');
  end;
  FBusy := True;
  try
    try
      FStream.Position := FValidBytes;
      FStream.WriteBuffer(LBytes[0], Length(LBytes));
      FFlush;
      if FFailed or (FStream.Size <> FValidBytes + Length(LBytes)) then
      begin
        raise EAudio.Create('Journal storage changed during commit or callback reentered');
      end;
      Inc(FValidBytes, Length(LBytes));
      FExpectedSize := FValidBytes;
      FNextFeature := LNext;
      FLastHash := LHash;
    except
      FFailed := True;
      raise;
    end;
  finally
    FBusy := False;
  end;
end;

procedure TFeatureJournal.RecoverTail;
begin
  CheckAvailable;
  if TailBytes = 0 then
  begin
    Exit;
  end;
  FBusy := True;
  try
    try
      FStream.Size := FValidBytes;
      FFlush;
      if FFailed or (FStream.Size <> FValidBytes) then
      begin
        raise EAudio.Create('Journal recovery callback reentered');
      end;
      FExpectedSize := FValidBytes;
    except
      FFailed := True;
      raise;
    end;
  finally
    FBusy := False;
  end;
end;

procedure TFeatureJournal.Rewind;
begin
  CheckAvailable;
  FReadPosition := CHeaderBytes;
  FReadNext := 0;
  FReadHash := FHeaderHash;
end;

function TFeatureJournal.ReadNext(var ABatch: TWaveFeatureBatch): Boolean;
var
  LBatch: TWaveFeatureBatch;
  LHash: String;
  LEnd: Int64;
begin
  CheckAvailable;
  if FReadPosition = FValidBytes then
  begin
    Exit(False);
  end;
  FBusy := True;
  try
    try
      if not DecodeRecord(FReadPosition, FReadNext, FReadHash, LBatch, LHash, LEnd) then
      begin
        raise EAudio.Create('Committed journal record became incomplete');
      end;
      if FFailed then
      begin
        raise EAudio.Create('Journal read reentered');
      end;
      FReadPosition := LEnd;
      FReadNext := LBatch.NextFeature;
      FReadHash := LHash;
      ABatch := LBatch;
      Result := True;
    except
      FFailed := True;
      raise;
    end;
  finally
    FBusy := False;
  end;
end;

end.
