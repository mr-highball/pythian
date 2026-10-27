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
program pythian_tests_hash_portable;
{$mode delphi}
{$H+}
uses SysUtils, Classes, pythian.audio, pythian.progress, pythian.hash,
  pythian.stream.bytes;
type
  TFragmentStream = class(TMemoryStream)
  public
    FailRead: Boolean;
    {$ifdef pas2js}
    function Read(ABuffer: TBytes; AOffset, ACount: LongInt): LongInt; override;
    {$else}
    function Read(var ABuffer; ACount: LongInt): LongInt; override;
    {$endif}
  end;
  TObserver = class
    Calls: Integer;
    LastTotal: Int64;
    Abort: Boolean;
    procedure Progress(const AProgress: TWorkProgress);
  end;
var
  LChecks: Integer;

{$ifdef pas2js}
function TFragmentStream.Read(ABuffer: TBytes; AOffset, ACount: LongInt): LongInt;
begin
  if FailRead then
  begin
    raise Exception.Create('Read marker');
  end;
  if ACount > 7 then
  begin
    ACount := 7;
  end;
  Result := inherited Read(ABuffer, AOffset, ACount);
end;
{$else}
function TFragmentStream.Read(var ABuffer; ACount: LongInt): LongInt;
begin
  if FailRead then
  begin
    raise Exception.Create('Read marker');
  end;
  if ACount > 7 then
  begin
    ACount := 7;
  end;
  Result := inherited Read(ABuffer, ACount);
end;
{$endif}

procedure TObserver.Progress(const AProgress: TWorkProgress);
begin
  Inc(Calls);
  LastTotal := AProgress.Total;
  if (AProgress.Stage <> 'verify_audio_bytes') or (AProgress.Units <> wuBytes) then
    raise Exception.Create('Progress identity');
  if Abort then
  begin
    raise Exception.Create('Abort marker');
  end;
end;

procedure Check(const ACondition: Boolean; const AMessage: String);
begin
  if not ACondition then
  begin
    raise Exception.Create(AMessage);
  end;
  Inc(LChecks);
end;

procedure Vector(const ASize: Integer; const AExpected: String);
var
  LBytes: TAudioBytes;
  LStream: TFragmentStream;
  LIndex: Integer;
  LObserver: TObserver;
begin
  SetLength(LBytes, ASize);
  for LIndex := 0 to ASize - 1 do
  begin
    LBytes[LIndex] := LIndex mod 256;
  end;
  LObserver := TObserver.Create;
  LStream := TFragmentStream.Create;
  try
    Check(Sha256Bytes(LBytes, LObserver.Progress) = AExpected, 'Bytes vector');
    Check(LObserver.Calls >= 2, 'Progress endpoints');
    if ASize > 0 then
    begin
      Check(WriteStreamBytes(LStream, LBytes, 0, ASize) = ASize, 'Stream preparation');
    end;
    LStream.Position := 0;
    Check(Sha256Stream(LStream, ASize) = AExpected, 'Fragmented stream vector');
    for LIndex := 0 to ASize - 1 do
    begin
      Check(LBytes[LIndex] = LIndex mod 256, 'Input mutation');
    end;
  finally
    LObserver.Free;
    LStream.Free;
  end;
end;
var
  LBytes: TAudioBytes;
  LStream: TFragmentStream;
  LObserver: TObserver;
  LRejected: Boolean;
  {$ifdef pas2js}
  LUnsafeCount: Int64;
  {$endif}
begin
  Vector(0, 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855');
  Vector(55, '463eb28e72f82e0a96c0a4cc53690c571281131f672aa229e0d45ae59b598b59');
  Vector(56, 'da2ae4d6b36748f2a318f23e7ab1dfdf45acdc9d049bd80e59de82a60895f562');
  Vector(63, '29af2686fd53374a36b0846694cc342177e428d1647515f078784d69cdb9e488');
  Vector(64, 'fdeab9acf3710362bd2658cdc9a29e8f9c757fcf9811603a8c447cd1d9151108');
  Vector(65, '4bfd2c8b6f1eec7a2afeb48b934ee4b2694182027e6d0fc075074f2fabb31781');
  Vector(8193, 'db8e82fcacaeceb336ecb8be90fad31da698c72a6c10fd1ea68a2e5874b78b17');
  SetLength(LBytes, 3);
  LBytes[0] := 97;
  LBytes[1] := 98;
  LBytes[2] := 99;
  Check(Sha256Bytes(LBytes) = 'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad', 'abc');
  LStream := TFragmentStream.Create;
  LObserver := TObserver.Create;
  try
    LRejected := False;
    try
      Sha256Stream(LStream, 1);
    except
      on E: EAudio do
      begin
        LRejected := True;
      end;
    end;
    Check(LRejected, 'Early EOF');
    LStream.FailRead := True;
    LRejected := False;
    try
      Sha256Stream(LStream, 1);
    except
      on E: Exception do
      begin
        LRejected := E.Message = 'Read marker';
      end;
    end;
    Check(LRejected, 'Stream error propagation');
    LStream.FailRead := False;
    LObserver.Abort := True;
    LRejected := False;
    try
      Sha256Stream(LStream, 1, LObserver.Progress);
    except
      on E: Exception do
      begin
        LRejected := E.Message = 'Abort marker';
      end;
    end;
    Check(LRejected and (LStream.Position = 0), 'Callback abort');
    LRejected := False;
    try
      Sha256Stream(LStream, 4294967297, LObserver.Progress);
    except
      on E: Exception do
      begin
        LRejected := E.Message = 'Abort marker';
      end;
    end;
    Check(LRejected and (LObserver.LastTotal = 4294967297), 'Large progress count');
    {$ifdef pas2js}
    LRejected := False;
    LUnsafeCount := 9007199254740991;
    Inc(LUnsafeCount);
    try
      Sha256Stream(LStream, LUnsafeCount);
    except
      on E: EAudio do
      begin
        LRejected := True;
      end;
    end;
    Check(LRejected, 'Unsafe byte count');
    {$endif}
  finally
    LObserver.Free;
    LStream.Free;
  end;
  WriteLn('Portable SHA256: ', LChecks, ' checks passed');
end.
