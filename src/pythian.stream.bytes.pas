(*
MIT License

Copyright (c) 2021 mr-highball
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
unit pythian.stream.bytes;

{$mode delphi}
{$H+}

interface

uses
  Classes,
  SysUtils,
  pythian.progress,
  pythian.audio;

type
  { Owned bounded storage with one portable size/seek/zero-fill policy. Capacity
    grows geometrically up to the explicit limit and stays at its high-water
    mark until release. Shrinking clamps the cursor; regrowth/gaps are zeroed.
    Snapshot returns detached logical bytes, never unused capacity. Allocation
    and RTL array copies are synchronous; the caller chooses the byte budget. }
  TAudioBytesStream = class(TStream)
  private
    FBytes: TAudioBytes;
    FPosition: Integer;
    FSize: Integer;
    FMaximumBytes: Integer;
    FReadOnly: Boolean;
    procedure EnsureCapacity(const ARequired: Integer);
    function ReadCount(const ACount: Integer): Integer;
    function WriteCount(const ACount: Integer): Integer;
  protected
    constructor CreateBorrowed(const ABytes: TAudioBytes);
    {$ifdef pas2js}
    procedure SetSize(const ASize: NativeInt); override;
    {$else}
    procedure SetSize(ASize: LongInt); overload; override;
    procedure SetSize(const ASize: Int64); overload; override;
    {$endif}
  public
    constructor Create(const AMaximumBytes: Integer);
    function Snapshot: TAudioBytes;
    property MaximumBytes: Integer read FMaximumBytes;
    {$ifdef pas2js}
    function Read(ABuffer: TBytes; AOffset, ACount: LongInt): LongInt; override;
    function Write(const ABuffer: TBytes; AOffset, ACount: LongInt): LongInt; override;
    function Seek(const AOffset: NativeInt; AOrigin: TSeekOrigin): NativeInt; override;
    {$else}
    function Read(var ABuffer; ACount: LongInt): LongInt; override;
    function Write(const ABuffer; ACount: LongInt): LongInt; override;
    function Seek(const AOffset: Int64; AOrigin: TSeekOrigin): Int64; override;
    {$endif}
  end;

  { Borrows the caller's array without copying it, sharing the primary stream's
    read/seek logic. Do not mutate its bytes while in use. Writes, resizing and
    seeking outside its original extent reject without changing the cursor. }
  TAudioBytesReadStream = class(TAudioBytesStream)
  public
    constructor Create(const ABytes: TAudioBytes);
  end;

{ Borrowed byte windows. No resize, copy, retry or complete-transfer promise.
  Validate before touching a stream; zero count performs no I/O. The caller
  owns short-read/write policy and any physical position changed by failure. }
function ReadStreamBytes(const AStream: TStream; var ABytes: TAudioBytes;
  const AOffset, ACount: Integer): Integer;
function WriteStreamBytes(const AStream: TStream; const ABytes: array of Byte;
  const AOffset, ACount: Integer): Integer;

{ Complete byte windows using the same portable transfer boundary. Accumulate
  short positive transfers; zero/negative/oversized results raise EReadError or
  EWriteError. Underlying exceptions propagate. Validate the complete window
  before I/O; zero count performs none. Failure may leave partial bytes/cursor
  movement and never promises storage rollback. An optional per-call observer
  receives actual transferred bytes, within65536 bytes or128 short transfers.
  Its exception propagates, with any earlier transfer left intact. The callback
  must not re-enter or mutate the borrowed stream/arrays; no receiver is kept. }
procedure ReadStreamBytesExact(const AStream: TStream; var ABytes: TAudioBytes;
  const AOffset, ACount: Integer; const AProgress: TWorkProgressCallback = nil);
procedure WriteStreamBytesExact(const AStream: TStream; const ABytes: array of Byte;
  const AOffset, ACount: Integer; const AProgress: TWorkProgressCallback = nil);

implementation

constructor TAudioBytesStream.Create(const AMaximumBytes: Integer);
begin
  inherited Create;
  if AMaximumBytes < 0 then
  begin
    raise EAudio.Create('Byte stream requires a nonnegative allocation limit');
  end;
  FMaximumBytes := AMaximumBytes;
end;

constructor TAudioBytesStream.CreateBorrowed(const ABytes: TAudioBytes);
begin
  inherited Create;
  if Length(ABytes) > High(Integer) then
  begin
    raise EAudio.Create('Borrowed byte stream exceeds the exact index range');
  end;
  FBytes := ABytes;
  FSize := Length(ABytes);
  FMaximumBytes := FSize;
  FReadOnly := True;
end;

constructor TAudioBytesReadStream.Create(const ABytes: TAudioBytes);
begin
  inherited CreateBorrowed(ABytes);
end;

function TAudioBytesStream.Snapshot: TAudioBytes;
begin
  Result := Copy(FBytes, 0, FSize);
end;

procedure TAudioBytesStream.EnsureCapacity(const ARequired: Integer);
var
  LCapacity: Integer;
begin
  if ARequired <= Length(FBytes) then
  begin
    Exit;
  end;
  LCapacity := Length(FBytes);
  if LCapacity < 4096 then
  begin
    LCapacity := 4096;
    if LCapacity > FMaximumBytes then
    begin
      LCapacity := FMaximumBytes;
    end;
  end;
  while LCapacity < ARequired do
  begin
    if LCapacity > FMaximumBytes div 2 then
    begin
      LCapacity := FMaximumBytes;
    end
    else
    begin
      LCapacity := LCapacity * 2;
    end;
  end;
  SetLength(FBytes, LCapacity);
end;

{$ifndef pas2js}
procedure TAudioBytesStream.SetSize(ASize: LongInt);
begin
  SetSize(Int64(ASize));
end;
{$endif}

{$ifdef pas2js}
procedure TAudioBytesStream.SetSize(const ASize: NativeInt);
{$else}
procedure TAudioBytesStream.SetSize(const ASize: Int64);
{$endif}
var
  LIndex: Integer;
begin
  if FReadOnly then
  begin
    raise EAudio.Create('Byte stream is read-only');
  end;
  if (ASize < 0) or (ASize > FMaximumBytes) then
  begin
    raise EAudio.Create('Byte stream resize exceeds its allocation limit');
  end;
  EnsureCapacity(Integer(ASize));
  for LIndex := FSize to Integer(ASize) - 1 do
  begin
    FBytes[LIndex] := 0;
  end;
  FSize := Integer(ASize);
  if FPosition > FSize then
  begin
    FPosition := FSize;
  end;
end;

function TAudioBytesStream.ReadCount(const ACount: Integer): Integer;
begin
  if ACount < 0 then
  begin
    raise EAudio.Create('Stream byte window is outside its buffer');
  end;
  Result := 0;
  if FPosition < FSize then
  begin
    Result := ACount;
    if Result > FSize - FPosition then
    begin
      Result := FSize - FPosition;
    end;
  end;
end;

function TAudioBytesStream.WriteCount(const ACount: Integer): Integer;
begin
  if FReadOnly then
  begin
    raise EAudio.Create('Byte stream is read-only');
  end;
  if (ACount < 0) or (ACount > FMaximumBytes - FPosition) then
  begin
    raise EAudio.Create('Byte stream write exceeds its allocation limit');
  end;
  if (ACount > 0) and (FPosition + ACount > FSize) then
  begin
    { Select the shared wide override, including the native32 RTL overload set. }
    SetSize(Int64(FPosition) + ACount);
  end;
  Result := ACount;
end;

{$ifdef pas2js}
function TAudioBytesStream.Read(ABuffer: TBytes; AOffset, ACount: LongInt): LongInt;
var
  LIndex: Integer;
begin
  if (AOffset < 0) or (ACount < 0) or (AOffset > Length(ABuffer)) or
    (ACount > Length(ABuffer) - AOffset) then
  begin
    raise EAudio.Create('Stream byte window is outside its buffer');
  end;
  Result := ReadCount(ACount);
  for LIndex := 0 to Result - 1 do
  begin
    ABuffer[AOffset + LIndex] := FBytes[FPosition + LIndex];
  end;
  Inc(FPosition, Result);
end;

function TAudioBytesStream.Write(const ABuffer: TBytes;
  AOffset, ACount: LongInt): LongInt;
var
  LIndex: Integer;
begin
  if (AOffset < 0) or (ACount < 0) or (AOffset > Length(ABuffer)) or
    (ACount > Length(ABuffer) - AOffset) then
  begin
    raise EAudio.Create('Stream byte window is outside its buffer');
  end;
  Result := WriteCount(ACount);
  for LIndex := 0 to Result - 1 do
  begin
    FBytes[FPosition + LIndex] := ABuffer[AOffset + LIndex];
  end;
  Inc(FPosition, Result);
end;

function TAudioBytesStream.Seek(const AOffset: NativeInt;
  AOrigin: TSeekOrigin): NativeInt;
{$else}
function TAudioBytesStream.Read(var ABuffer; ACount: LongInt): LongInt;
begin
  Result := ReadCount(ACount);
  if Result > 0 then
  begin
    Move(FBytes[FPosition], ABuffer, Result);
  end;
  Inc(FPosition, Result);
end;

function TAudioBytesStream.Write(const ABuffer; ACount: LongInt): LongInt;
begin
  Result := WriteCount(ACount);
  if Result > 0 then
  begin
    Move(ABuffer, FBytes[FPosition], Result);
  end;
  Inc(FPosition, Result);
end;

function TAudioBytesStream.Seek(const AOffset: Int64;
  AOrigin: TSeekOrigin): Int64;
{$endif}
var
  LBase: Integer;
begin
  case AOrigin of
    soBeginning: LBase := 0;
    soCurrent: LBase := FPosition;
    soEnd: LBase := FSize;
  else
    raise EAudio.Create('Invalid byte stream seek origin');
  end;
  if (AOffset < -Int64(LBase)) or (AOffset > FMaximumBytes - LBase) then
  begin
    raise EAudio.Create('Byte stream seek is outside its extent');
  end;
  FPosition := LBase + Integer(AOffset);
  Result := FPosition;
end;

procedure ValidateWindow(const AStream: TStream;
  const ALength, AOffset, ACount: Integer);
begin
  if (AStream = nil) or (AOffset < 0) or (ACount < 0) or
    (AOffset > ALength) or (ACount > ALength - AOffset) then
  begin
    raise EAudio.Create('Stream byte window is outside its buffer');
  end;
end;

function ReadStreamBytes(const AStream: TStream; var ABytes: TAudioBytes;
  const AOffset, ACount: Integer): Integer;
begin
  ValidateWindow(AStream, Length(ABytes), AOffset, ACount);
  if ACount = 0 then
  begin
    Exit(0);
  end;
  {$ifdef pas2js}
  Result := AStream.Read(TBytes(ABytes), AOffset, ACount);
  {$else}
  Result := AStream.Read(ABytes[AOffset], ACount);
  {$endif}
end;

function WriteStreamBytes(const AStream: TStream; const ABytes: array of Byte;
  const AOffset, ACount: Integer): Integer;
begin
  ValidateWindow(AStream, Length(ABytes), AOffset, ACount);
  if ACount = 0 then
  begin
    Exit(0);
  end;
  {$ifdef pas2js}
  Result := AStream.Write(TBytes(ABytes), AOffset, ACount);
  {$else}
  Result := AStream.Write(ABytes[AOffset], ACount);
  {$endif}
end;

procedure ReadStreamBytesExact(const AStream: TStream; var ABytes: TAudioBytes;
  const AOffset, ACount: Integer; const AProgress: TWorkProgressCallback);
var
  LDone: Integer;
  LRead: Integer;
  LRequest: Integer;
  LReported: Integer;
  LTransfers: Integer;
begin
  ValidateWindow(AStream, Length(ABytes), AOffset, ACount);
  LDone := 0;
  LReported := 0;
  LTransfers := 0;
  ReportWork(AProgress, 'read_bytes', wuBytes, 0, ACount);
  while LDone < ACount do
  begin
    LRequest := ACount - LDone;
    if Assigned(AProgress) and (LRequest > 65536) then
    begin
      LRequest := 65536;
    end;
    LRead := ReadStreamBytes(AStream, ABytes, AOffset + LDone, LRequest);
    if (LRead <= 0) or (LRead > LRequest) then
    begin
      raise EReadError.Create('Stream read error');
    end;
    Inc(LDone, LRead);
    Inc(LTransfers);
    if Assigned(AProgress) and ((LDone - LReported >= 65536) or
      (LTransfers = 128) or (LDone = ACount)) then
    begin
      ReportWork(AProgress, 'read_bytes', wuBytes, LDone, ACount);
      LReported := LDone;
      LTransfers := 0;
    end;
  end;
end;

procedure WriteStreamBytesExact(const AStream: TStream; const ABytes: array of Byte;
  const AOffset, ACount: Integer; const AProgress: TWorkProgressCallback);
var
  LDone: Integer;
  LWritten: Integer;
  LRequest: Integer;
  LReported: Integer;
  LTransfers: Integer;
begin
  ValidateWindow(AStream, Length(ABytes), AOffset, ACount);
  LDone := 0;
  LReported := 0;
  LTransfers := 0;
  ReportWork(AProgress, 'write_bytes', wuBytes, 0, ACount);
  while LDone < ACount do
  begin
    LRequest := ACount - LDone;
    if Assigned(AProgress) and (LRequest > 65536) then
    begin
      LRequest := 65536;
    end;
    LWritten := WriteStreamBytes(AStream, ABytes, AOffset + LDone, LRequest);
    if (LWritten <= 0) or (LWritten > LRequest) then
    begin
      raise EWriteError.Create('Stream write error');
    end;
    Inc(LDone, LWritten);
    Inc(LTransfers);
    if Assigned(AProgress) and ((LDone - LReported >= 65536) or
      (LTransfers = 128) or (LDone = ACount)) then
    begin
      ReportWork(AProgress, 'write_bytes', wuBytes, LDone, ACount);
      LReported := LDone;
      LTransfers := 0;
    end;
  end;
end;

end.
