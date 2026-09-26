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
program pythian_tests_hash;

{$mode delphi}
{$H+}

uses
  Classes,
  SysUtils,
  pythian.audio,
  pythian.hash
  {$IFDEF FCL_SHA256_PARITY}
  , FpSHA256
  {$ENDIF}
  ;

type
  ESourceFailure = class(Exception);
  TShortStream = class(TMemoryStream)
  public
    FailAt: Int64;
    function Read(var ABuffer; ACount: LongInt): LongInt; override;
  end;

function TShortStream.Read(var ABuffer; ACount: LongInt): LongInt;
begin
  if (FailAt > 0) and (Position >= FailAt) then
  begin
    raise ESourceFailure.Create('Deliberate source failure');
  end;
  if ACount > 3 then
  begin
    ACount := 3;
  end;
  Result := inherited Read(ABuffer, ACount);
end;

procedure Check(const ACondition: Boolean; const AMessage: String);
begin
  if not ACondition then
  begin
    raise Exception.Create(AMessage);
  end;
end;

function Bytes(const AText: AnsiString): TAudioBytes;
begin
  Result := nil;
  SetLength(Result, Length(AText));
  if Length(AText) > 0 then
  begin
    Move(AText[1], Result[0], Length(AText));
  end;
end;

procedure Run;
var
  LBytes: TAudioBytes;
  LIndex: Integer;
  {$IFDEF FCL_SHA256_PARITY}
  LLength: Integer;
  LHex: AnsiString;
  {$ENDIF}
begin
  Check(Sha256Bytes(nil) =
    'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855', 'Empty SHA256');
  Check(Sha256Bytes(Bytes('abc')) =
    'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad', 'abc SHA256');
  Check(Sha256Bytes(Bytes('abcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmnomnopnopq')) =
    '248d6a61d20638b8e5c026930c3e6039a33ce45964ff2167f6ecedd419db06c1', 'Two-block SHA256');
  SetLength(LBytes, 1000000);
  for LIndex := 0 to High(LBytes) do
  begin
    LBytes[LIndex] := Ord('a');
  end;
  Check(Sha256Bytes(LBytes) =
    'cdc76e5c9914fb9281a1c7e284d73e67f1809a48a497200e046d39ccc7112cd0', 'Million-a SHA256');
  Check(LBytes[High(LBytes)] = Ord('a'), 'Input remains unchanged');
  {$IFDEF FCL_SHA256_PARITY}
  for LLength := 0 to 256 do
  begin
    SetLength(LBytes, LLength);
    for LIndex := 0 to High(LBytes) do
    begin
      LBytes[LIndex] := (LIndex * 131 + LLength * 17) and $FF;
    end;
    TSHA256.DigestHexa(TBytes(LBytes), LHex);
    Check(Sha256Bytes(LBytes) = LowerCase(LHex), 'Actual FCL padding/block-boundary parity');
  end;
  WriteLn('Actual FCL parity passes across binary lengths 0..256');
  {$ENDIF}
  WriteLn('SHA256 known-answer and input-preservation checks pass');
end;

procedure StreamChecks;
const
  CLengths: array[0..10] of Integer = (0, 1, 55, 56, 63, 64, 65, 8191, 8192, 8193, 17003);
var
  LStream: TShortStream;
  LBytes: TAudioBytes;
  LIndex: Integer;
  LLength: Integer;
  LHash: String;
  LRejected: Boolean;
begin
  LStream := TShortStream.Create;
  try
    for LLength in CLengths do
    begin
      SetLength(LBytes, LLength);
      for LIndex := 0 to High(LBytes) do
      begin
        LBytes[LIndex] := (LIndex * 131 + LLength * 17) and $FF;
      end;
      LStream.Clear;
      LStream.WriteByte(123);
      if LLength > 0 then
      begin
        LStream.WriteBuffer(LBytes[0], LLength);
      end;
      LStream.WriteByte(231);
      LStream.Position := 1;
      Check(Sha256Stream(LStream, LLength) = Sha256Bytes(LBytes),
        'Short-read stream digest at padding/buffer boundary');
      Check(LStream.Position = LLength + 1, 'Hash consumes exact declared span');
    end;
    LStream.Position := 0;
    LRejected := False;
    try
      Sha256Stream(LStream, High(Int64));
    except
      on EAudio do LRejected := True;
    end;
    Check(LRejected and (LStream.Position = 0), 'Invalid count rejects before reading');
    LStream.FailAt := 9;
    LHash := 'prior digest';
    LRejected := False;
    try
      LHash := Sha256Stream(LStream, 100);
    except
      on ESourceFailure do LRejected := True;
    end;
    Check(LRejected and (LHash = 'prior digest') and (LStream.Position = 9),
      'Original exception and prior digest survive partial source failure');
    LStream.FailAt := 0;
    LStream.Position := LStream.Size - 1;
    LRejected := False;
    try
      LHash := Sha256Stream(LStream, 2);
    except
      on EAudio do LRejected := True;
    end;
    Check(LRejected and (LHash = 'prior digest'), 'Early EOF preserves prior digest');
    LStream.Clear;
    Check(Sha256Stream(LStream, 0) =
      'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
      'Empty stream known answer');
  finally
    LStream.Free;
  end;
  WriteLn('Bounded stream SHA256 boundary, ownership and failure checks pass');
end;

begin
  try
    Run;
    StreamChecks;
  except
    on LException: Exception do
    begin
      WriteLn(StdErr, LException.ClassName, ': ', LException.Message);
      Halt(1);
    end;
  end;
end.
