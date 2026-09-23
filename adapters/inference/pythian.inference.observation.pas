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
unit pythian.inference.observation;

{$mode delphi}
{$H+}

interface

uses
  Classes,
  SysUtils,
  pythian.audio;

const
  InferenceMaximumBatch = 32;
  InferenceMaximumSeconds = 3600;
  InferenceRate = 16000;
  InferenceWindowFrames = 2048;
  InferencePolicy = 'raw-f32-16k2048-hann8192-peak64-q003-h23-octave-35cent-8sigma-v1';
  InferenceEstimator = 'pythian-interpolated-peakmap-sparse35cents-midi24-20cent-v1';

type
  EInferenceCancelled = class(EAudio);
  TPitchSalience = array[0..359] of Single;
  TInferenceBackend = class
  public
    function Activate(const AWindow: TAudioSamples): TPitchSalience; virtual; abstract;
    function EstimatorIdentity: String; virtual; abstract;
  end;
  { Raw acoustic observations, never probabilities of admitted notes/rests. }
  TInferenceObservation = packed record
    Center16k: Int64;
    AcRms: Double;
    Salience: TPitchSalience;
  end;
  TInferenceBatch = array of TInferenceObservation;
  TInferenceCancel = function: Boolean of object;
  TInferenceProgress = procedure(const APhase: String; const ACompleted: Int64) of object;
  TInferenceRequest = record
    SourceHash: String;
    Policy: String;
    Channel: Integer;
    { All scope/center coordinates use the resampled 16 kHz source clock. }
    ScopeStart16k: Int64;
    ScopeEnd16k: Int64;
    { Window padding boundaries may enclose several adjacent processing scopes.
      A batch/scope boundary is never implicitly a waveform boundary. }
    InputStart16k: Int64;
    InputEnd16k: Int64;
    FirstCenter16k: Int64;
    Hop16k: Integer;
    BatchSize: Integer;
  end;
  TInferenceIdentity = record
    Estimator: String;
    Request: TInferenceRequest;
    SourceRate: Integer;
    SourceChannels: Integer;
    SourceFrames: Int64;
    ObservationCount: Int64;
  end;
  { Sinks own their copies. Batches are provisional until Complete returns.
    Failure/cancellation calls Abort; implementations must preserve any prior
    accepted output. Callbacks must not reenter the same execution object. }
  TInferenceSink = class
  public
    procedure Start(const AIdentity: TInferenceIdentity); virtual; abstract;
    procedure Append(const ABatch: TInferenceBatch); virtual; abstract;
    procedure Complete; virtual; abstract;
    procedure Abort; virtual; abstract;
  end;
  { Writes a new staging file only. Complete closes a checksummed artifact;
    publication/replacement belongs to the supervisor after worker success. }
  TInferenceFileSink = class(TInferenceSink)
  strict private
    FName: String;
    FStream: THandleStream;
    FFileHandle: THandle;
    FOwnsFile: Boolean;
    FIdentity: TInferenceIdentity;
    FCount: Int64;
    FStarted: Boolean;
    FComplete: Boolean;
  public
    constructor Create(const ANewStagingFile: String);
    destructor Destroy; override;
    procedure Start(const AIdentity: TInferenceIdentity); override;
    procedure Append(const ABatch: TInferenceBatch); override;
    procedure Complete; override;
    procedure Abort; override;
  end;
  { Validates exact caller-supplied identity, complete byte extent/checksum and
    every observation before exposing a read cursor. Borrows no caller state. }
  TInferenceFileReader = class
  strict private
    FStream: TFileStream;
    FRemaining: Int64;
  public
    constructor Create(const AFileName: String; const AExpected: TInferenceIdentity;
      const ACancel: TInferenceCancel = nil);
    destructor Destroy; override;
    function ReadBatch(const AMaximum: Integer = InferenceMaximumBatch): TInferenceBatch;
  end;

function DefaultInferenceRequest(const ASourceHash: String;
  const AEnd16k: Int64): TInferenceRequest;
procedure ValidateInferenceRequest(const ARequest: TInferenceRequest);
procedure ValidateInferenceObservation(const AObservation: TInferenceObservation);
function InferenceCount(const ARequest: TInferenceRequest): Int64;
function InferenceIdentityText(const AIdentity: TInferenceIdentity): String;
procedure CheckInferenceCancel(const ACancel: TInferenceCancel);
function HashInferenceFile(const AFileName: String): String;
function HashInferenceStream(const AStream: TStream; const ACount: Int64;
  const ACancel: TInferenceCancel): String;

implementation

uses
  Windows,
  Math,
  pythian.hash,
  pythian.resample.stream;

{ FileDispositionInfo applies to the owned handle, avoiding a close/delete-path
  race. CREATE_NEW plus sharing0 excludes both truncation and path replacement. }
function SetInferenceFileInformation(AFile: THandle; AClass: Integer;
  AInformation: Pointer; ASize: DWORD): BOOL; stdcall;
  external 'kernel32.dll' name 'SetFileInformationByHandle';

type
  TInferenceHashStream = class(TStream)
  private
    FSource: TStream;
    FCancel: TInferenceCancel;
  public
    function Read(var ABuffer; ACount: LongInt): LongInt; override;
  end;

function TInferenceHashStream.Read(var ABuffer; ACount: LongInt): LongInt;
begin
  CheckInferenceCancel(FCancel);
  Result := FSource.Read(ABuffer, ACount);
end;

function HashInferenceStream(const AStream: TStream; const ACount: Int64;
  const ACancel: TInferenceCancel): String;
var
  LStream: TInferenceHashStream;
begin
  LStream := TInferenceHashStream.Create;
  try
    LStream.FSource := AStream;
    LStream.FCancel := ACancel;
    Result := Sha256Stream(LStream, ACount);
  finally
    LStream.Free;
  end;
end;

function DefaultInferenceRequest(const ASourceHash: String;
  const AEnd16k: Int64): TInferenceRequest;
begin
  Result := Default(TInferenceRequest);
  Result.SourceHash := ASourceHash;
  Result.Policy := InferencePolicy;
  Result.ScopeEnd16k := AEnd16k;
  Result.InputEnd16k := AEnd16k;
  Result.Hop16k := 160;
  Result.BatchSize := InferenceMaximumBatch;
end;

procedure ValidateInferenceRequest(const ARequest: TInferenceRequest);
var
  LCharacter: Char;
begin
  if Length(ARequest.SourceHash) <> 64 then
  begin
    raise EAudio.Create('Inference requires an exact source SHA256');
  end;
  for LCharacter in ARequest.SourceHash do
  begin
    if not (LCharacter in ['0'..'9', 'a'..'f']) then
    begin
      raise EAudio.Create('Inference source SHA256 must be lowercase hexadecimal');
    end;
  end;
  if (ARequest.Policy <> InferencePolicy) or (ARequest.Channel < 0) or
    (ARequest.Channel > 1) or (ARequest.ScopeStart16k < 0) or
    (ARequest.ScopeEnd16k <= ARequest.ScopeStart16k) or
    (ARequest.ScopeEnd16k > High(Int64) - InferenceWindowFrames) or
    (ARequest.InputStart16k < 0) or
    (ARequest.InputStart16k > ARequest.ScopeStart16k) or
    (ARequest.InputEnd16k < ARequest.ScopeEnd16k) or
    (ARequest.ScopeEnd16k - ARequest.ScopeStart16k >
      Int64(InferenceMaximumSeconds) * InferenceRate) or
    (ARequest.FirstCenter16k < ARequest.ScopeStart16k) or
    (ARequest.FirstCenter16k >= ARequest.ScopeEnd16k) or
    (ARequest.Hop16k < 160) or (ARequest.Hop16k > InferenceRate) or
    (ARequest.BatchSize < 1) or (ARequest.BatchSize > InferenceMaximumBatch) then
  begin
    raise EAudio.Create('Unsupported inference policy, scope, density or batch size');
  end;
end;

function InferenceCount(const ARequest: TInferenceRequest): Int64;
begin
  ValidateInferenceRequest(ARequest);
  Result := 1 + (ARequest.ScopeEnd16k - 1 - ARequest.FirstCenter16k) div ARequest.Hop16k;
end;

procedure ValidateInferenceObservation(const AObservation: TInferenceObservation);
var
  LValue: Single;
begin
  RequireFinite(AObservation.AcRms, 'Inference AC RMS');
  if (AObservation.Center16k < 0) or (AObservation.AcRms < 0) then
  begin
    raise EAudio.Create('Invalid inference observation coordinates or RMS');
  end;
  for LValue in AObservation.Salience do
  begin
    RequireFinite(LValue, 'Inference salience');
    if (LValue < 0) or (LValue > 1) then
    begin
      raise EAudio.Create('Inference raw support outside 0..1');
    end;
  end;
end;

function InferenceIdentityText(const AIdentity: TInferenceIdentity): String;
var
  LCharacter: Char;
begin
  ValidateInferenceRequest(AIdentity.Request);
  if (AIdentity.ObservationCount <> InferenceCount(AIdentity.Request)) or
    ((AIdentity.SourceRate <> 16000) and (AIdentity.SourceRate <> 22050) and
      (AIdentity.SourceRate <> 44100) and (AIdentity.SourceRate <> 48000)) or
    (AIdentity.SourceChannels < 1) or (AIdentity.SourceChannels > 2) or
    (AIdentity.Request.Channel >= AIdentity.SourceChannels) or
    (AIdentity.SourceFrames < 1) then
  begin
    raise EAudio.Create('Invalid inference source identity');
  end;
  if (Length(AIdentity.Estimator) < 1) or (Length(AIdentity.Estimator) > 256) then
  begin
    raise EAudio.Create('Inference requires a bounded explicit estimator identity');
  end;
  for LCharacter in AIdentity.Estimator do
  begin
    if (Ord(LCharacter) < 33) or (Ord(LCharacter) > 126) then
    begin
      raise EAudio.Create('Inference estimator identity contains unsupported characters');
    end;
  end;
  if AIdentity.Request.InputEnd16k > StreamResampleFrameCount(
    AIdentity.SourceFrames, AIdentity.SourceRate, InferenceRate) then
  begin
    raise EAudio.Create('Inference identity support exceeds source extent');
  end;
  Result := 'PINF1' + #10 + AIdentity.Request.SourceHash + #10 +
    AIdentity.Estimator + #10 +
    AIdentity.Request.Policy + #10 +
    IntToStr(AIdentity.SourceRate) + #10 + IntToStr(AIdentity.SourceChannels) + #10 +
    IntToStr(AIdentity.SourceFrames) + #10 + IntToStr(AIdentity.Request.Channel) + #10 +
    IntToStr(AIdentity.Request.ScopeStart16k) + #10 +
    IntToStr(AIdentity.Request.ScopeEnd16k) + #10 +
    IntToStr(AIdentity.Request.InputStart16k) + #10 +
    IntToStr(AIdentity.Request.InputEnd16k) + #10 +
    IntToStr(AIdentity.Request.FirstCenter16k) + #10 +
    IntToStr(AIdentity.Request.Hop16k) + #10 +
    IntToStr(AIdentity.ObservationCount) + #10;
  { Batch size is execution scheduling, not a measurement-policy difference. }
end;

procedure CheckInferenceCancel(const ACancel: TInferenceCancel);
begin
  if Assigned(ACancel) and ACancel() then
  begin
    raise EInferenceCancelled.Create('Inference cancelled');
  end;
end;

function HashInferenceFile(const AFileName: String): String;
var
  LStream: TFileStream;
begin
  LStream := TFileStream.Create(AFileName, fmOpenRead or fmShareDenyWrite);
  try
    Result := Sha256Stream(LStream, LStream.Size);
  finally
    LStream.Free;
  end;
end;

constructor TInferenceFileSink.Create(const ANewStagingFile: String);
begin
  inherited Create;
  if (ANewStagingFile = '') or FileExists(ANewStagingFile) then
  begin
    raise EAudio.Create('Inference staging output must be a new path');
  end;
  FName := ANewStagingFile;
end;

destructor TInferenceFileSink.Destroy;
begin
  if not FComplete then
  begin
    Abort;
  end;
  inherited Destroy;
end;

procedure TInferenceFileSink.Start(const AIdentity: TInferenceIdentity);
var
  LHeader: String;
  LLength: Cardinal;
  LHandle: THandle;
begin
  if FStarted then
  begin
    raise EAudio.Create('Inference sink was already started');
  end;
  LHeader := InferenceIdentityText(AIdentity);
  if Length(LHeader) > 4096 then
  begin
    raise EAudio.Create('Inference identity exceeds header bound');
  end;
  FIdentity := AIdentity;
  LHandle := Windows.CreateFile(PChar(FName), GENERIC_READ or GENERIC_WRITE or $00010000,
    0, nil, CREATE_NEW, FILE_ATTRIBUTE_NORMAL, 0);
  if LHandle = INVALID_HANDLE_VALUE then
  begin
    RaiseLastOSError;
  end;
  FFileHandle := LHandle;
  FOwnsFile := True;
  FStarted := True;
  FStream := THandleStream.Create(FFileHandle);
  LLength := Length(LHeader);
  FStream.WriteBuffer(LLength, SizeOf(LLength));
  FStream.WriteBuffer(LHeader[1], LLength);
end;

procedure TInferenceFileSink.Append(const ABatch: TInferenceBatch);
var
  LObservation: TInferenceObservation;
  LCount: Int64;
begin
  if (FStream = nil) or FComplete or (Length(ABatch) < 1) or
    (Length(ABatch) > InferenceMaximumBatch) or
    (FCount + Length(ABatch) > FIdentity.ObservationCount) then
  begin
    raise EAudio.Create('Invalid inference sink batch/state');
  end;
  LCount := FCount;
  for LObservation in ABatch do
  begin
    ValidateInferenceObservation(LObservation);
    if LObservation.Center16k <> FIdentity.Request.FirstCenter16k +
      LCount * FIdentity.Request.Hop16k then
    begin
      raise EAudio.Create('Inference batch centers differ from declared source clock');
    end;
    Inc(LCount);
  end;
  FStream.WriteBuffer(ABatch[0], Length(ABatch) * SizeOf(TInferenceObservation));
  FCount := LCount;
end;

procedure TInferenceFileSink.Complete;
var
  LHash: String;
begin
  if (FStream = nil) or FComplete or (FCount <> FIdentity.ObservationCount) then
  begin
    raise EAudio.Create('Inference artifact is incomplete');
  end;
  FStream.Position := 0;
  LHash := Sha256Stream(FStream, FStream.Size);
  FStream.WriteBuffer(LHash[1], Length(LHash));
  FreeAndNil(FStream);
  CloseHandle(FFileHandle);
  FFileHandle := 0;
  FOwnsFile := False;
  FComplete := True;
end;

procedure TInferenceFileSink.Abort;
var
  LDelete: Byte;
begin
  if FOwnsFile then
  begin
    LDelete := 1;
    { If the OS refuses cleanup, leave an incomplete staging file; never fall
      back to deleting a pathname after relinquishing its exclusive handle. }
    SetInferenceFileInformation(FFileHandle, 4, @LDelete, SizeOf(LDelete));
  end;
  FreeAndNil(FStream);
  if FOwnsFile then
  begin
    CloseHandle(FFileHandle);
    FFileHandle := 0;
    FOwnsFile := False;
  end;
end;

constructor TInferenceFileReader.Create(const AFileName: String;
  const AExpected: TInferenceIdentity; const ACancel: TInferenceCancel);
var
  LExpected: String;
  LHeader: String;
  LHash: String;
  LStored: String;
  LLength: Cardinal;
  LDataStart: Int64;
  LIndex: Int64;
  LObservation: TInferenceObservation;
begin
  inherited Create;
  LExpected := InferenceIdentityText(AExpected);
  FStream := TFileStream.Create(AFileName, fmOpenRead or fmShareDenyWrite);
  FStream.ReadBuffer(LLength, SizeOf(LLength));
  if LLength <> Length(LExpected) then
  begin
    raise EAudio.Create('Inference artifact identity length differs');
  end;
  SetLength(LHeader, LLength);
  FStream.ReadBuffer(LHeader[1], LLength);
  if LHeader <> LExpected then
  begin
    raise EAudio.Create('Inference artifact source/preparation/estimator identity differs');
  end;
  LDataStart := FStream.Position;
  if FStream.Size <> LDataStart + AExpected.ObservationCount *
    SizeOf(TInferenceObservation) + 64 then
  begin
    raise EAudio.Create('Inference artifact is incomplete or has trailing bytes');
  end;
  FStream.Position := 0;
  LHash := HashInferenceStream(FStream, FStream.Size - 64, ACancel);
  SetLength(LStored, 64);
  FStream.ReadBuffer(LStored[1], 64);
  if LHash <> LStored then
  begin
    raise EAudio.Create('Inference artifact checksum differs');
  end;
  FStream.Position := LDataStart;
  LIndex := 0;
  while LIndex < AExpected.ObservationCount do
  begin
    if LIndex mod InferenceMaximumBatch = 0 then
    begin
      CheckInferenceCancel(ACancel);
    end;
    FStream.ReadBuffer(LObservation, SizeOf(LObservation));
    ValidateInferenceObservation(LObservation);
    if LObservation.Center16k <> AExpected.Request.FirstCenter16k +
      LIndex * AExpected.Request.Hop16k then
    begin
      raise EAudio.Create('Inference artifact center sequence differs');
    end;
    Inc(LIndex);
  end;
  FStream.Position := LDataStart;
  FRemaining := AExpected.ObservationCount;
end;

destructor TInferenceFileReader.Destroy;
begin
  FStream.Free;
  inherited Destroy;
end;

function TInferenceFileReader.ReadBatch(const AMaximum: Integer): TInferenceBatch;
var
  LCount: Integer;
begin
  Result := nil;
  if (AMaximum < 1) or (AMaximum > InferenceMaximumBatch) then
  begin
    raise EAudio.Create('Inference read batch exceeds bound');
  end;
  LCount := Min(Int64(AMaximum), FRemaining);
  SetLength(Result, LCount);
  if LCount > 0 then
  begin
    FStream.ReadBuffer(Result[0], LCount * SizeOf(TInferenceObservation));
    Dec(FRemaining, LCount);
  end;
end;

end.
