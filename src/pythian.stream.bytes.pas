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
  pythian.audio;

type
  { Consolidates the former private WAV byte view into the shared I/O boundary.
    Borrows the caller's array without copying it. The caller must not mutate
    its contents while the stream is in use. Seeking outside its extent and
    writes fail without changing the cursor. }
  TAudioBytesReadStream = class(TStream)
  private
    FBytes: TAudioBytes;
    FPosition: Integer;
  public
    constructor Create(const ABytes: TAudioBytes);
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
  movement and never promises storage rollback. }
procedure ReadStreamBytesExact(const AStream: TStream; var ABytes: TAudioBytes;
  const AOffset, ACount: Integer);
procedure WriteStreamBytesExact(const AStream: TStream; const ABytes: array of Byte;
  const AOffset, ACount: Integer);

implementation

constructor TAudioBytesReadStream.Create(const ABytes: TAudioBytes);
begin
  inherited Create;
  FBytes := ABytes;
  FPosition := 0;
end;

{$ifdef pas2js}
function TAudioBytesReadStream.Read(ABuffer: TBytes; AOffset, ACount: LongInt): LongInt;
var
  LIndex: Integer;
begin
  if (AOffset < 0) or (ACount < 0) or (AOffset > Length(ABuffer)) or
    (ACount > Length(ABuffer) - AOffset) then
  begin
    raise EAudio.Create('Stream byte window is outside its buffer');
  end;
  Result := ACount;
  if Result > Length(FBytes) - FPosition then
  begin
    Result := Length(FBytes) - FPosition;
  end;
  for LIndex := 0 to Result - 1 do
  begin
    ABuffer[AOffset + LIndex] := FBytes[FPosition + LIndex];
  end;
  Inc(FPosition, Result);
end;

function TAudioBytesReadStream.Write(const ABuffer: TBytes;
  AOffset, ACount: LongInt): LongInt;
begin
  raise EAudio.Create('Byte stream is read-only');
end;

function TAudioBytesReadStream.Seek(const AOffset: NativeInt;
  AOrigin: TSeekOrigin): NativeInt;
{$else}
function TAudioBytesReadStream.Read(var ABuffer; ACount: LongInt): LongInt;
begin
  if ACount < 0 then
  begin
    raise EAudio.Create('Stream byte window is outside its buffer');
  end;
  Result := ACount;
  if Result > Length(FBytes) - FPosition then
  begin
    Result := Length(FBytes) - FPosition;
  end;
  if Result > 0 then
  begin
    Move(FBytes[FPosition], ABuffer, Result);
  end;
  Inc(FPosition, Result);
end;

function TAudioBytesReadStream.Write(const ABuffer; ACount: LongInt): LongInt;
begin
  raise EAudio.Create('Byte stream is read-only');
end;

function TAudioBytesReadStream.Seek(const AOffset: Int64;
  AOrigin: TSeekOrigin): Int64;
{$endif}
var
  LBase: Integer;
begin
  case AOrigin of
    soBeginning: LBase := 0;
    soCurrent: LBase := FPosition;
    soEnd: LBase := Length(FBytes);
  else
    raise EAudio.Create('Invalid byte stream seek origin');
  end;
  if (AOffset < -Int64(LBase)) or (AOffset > Length(FBytes) - LBase) then
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
  const AOffset, ACount: Integer);
var
  LDone: Integer;
  LRead: Integer;
begin
  ValidateWindow(AStream, Length(ABytes), AOffset, ACount);
  LDone := 0;
  while LDone < ACount do
  begin
    LRead := ReadStreamBytes(AStream, ABytes, AOffset + LDone, ACount - LDone);
    if (LRead <= 0) or (LRead > ACount - LDone) then
    begin
      raise EReadError.Create('Stream read error');
    end;
    Inc(LDone, LRead);
  end;
end;

procedure WriteStreamBytesExact(const AStream: TStream; const ABytes: array of Byte;
  const AOffset, ACount: Integer);
var
  LDone: Integer;
  LWritten: Integer;
begin
  ValidateWindow(AStream, Length(ABytes), AOffset, ACount);
  LDone := 0;
  while LDone < ACount do
  begin
    LWritten := WriteStreamBytes(AStream, ABytes, AOffset + LDone, ACount - LDone);
    if (LWritten <= 0) or (LWritten > ACount - LDone) then
    begin
      raise EWriteError.Create('Stream write error');
    end;
    Inc(LDone, LWritten);
  end;
end;

end.
