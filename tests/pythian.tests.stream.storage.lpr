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
program pythian_tests_stream_storage;

{$mode delphi}
{$H+}

uses
  Classes, SysUtils, pythian.audio, pythian.stream.bytes, pythian.hash;

type
  TCallerStream = class(TAudioBytesStream)
    procedure ResizeFromInteger(const ASize: Integer);
  end;

var
  GChecks: Integer;

procedure TCallerStream.ResizeFromInteger(const ASize: Integer);
begin
  SetSize(ASize);
end;

procedure Check(const ACondition: Boolean; const AMessage: String);
begin
  if not ACondition then
  begin
    raise EAudio.Create(AMessage);
  end;
  Inc(GChecks);
end;

procedure RejectedBounds(const AStream: TAudioBytesStream);
var
  LBefore: String;
  LPosition: Int64;
  LSize: Int64;
  LBytes: TAudioBytes;
  LCase: Integer;
  LRejected: Boolean;
begin
  SetLength(LBytes, 17);
  AStream.Position := 4;
  LBefore := Sha256Bytes(AStream.Snapshot);
  LPosition := AStream.Position;
  LSize := AStream.Size;
  for LCase := 0 to 7 do
  begin
    LRejected := False;
    try
      case LCase of
        0: AStream.Size := -1;
        1: AStream.Size := 17;
        2: AStream.Seek(-High(Integer), soEnd);
        3: AStream.Seek(High(Integer), soCurrent);
        4: AStream.Seek(-1, soBeginning);
        5: WriteStreamBytesExact(AStream, LBytes, 0, 17);
        6: WriteStreamBytesExact(AStream, LBytes, -1, 0);
        7: ReadStreamBytesExact(AStream, LBytes, 0, 18);
      end;
    except
      on EAudio do
      begin
        LRejected := True;
      end;
    end;
    Check(LRejected and (AStream.Position = LPosition) and
      (AStream.Size = LSize) and (Sha256Bytes(AStream.Snapshot) = LBefore),
      'Invalid bounds changed bytes, size or cursor');
  end;
end;

procedure Run;
var
  LStream: TAudioBytesStream;
  LReadOnly: TAudioBytesReadStream;
  LBytes: TAudioBytes;
  LSnapshot: TAudioBytes;
  LCurrent: TAudioBytes;
  LIndex: Integer;
  LRejected: Boolean;
begin
  SetLength(LBytes, 70000);
  for LIndex := 0 to High(LBytes) do
  begin
    LBytes[LIndex] := (LIndex * 17) mod 251;
  end;
  LStream := TAudioBytesStream.Create(200000);
  try
    WriteStreamBytesExact(LStream, LBytes, 0, Length(LBytes));
    LSnapshot := LStream.Snapshot;
    Check((LStream.Size = 70000) and (LStream.Position = 70000) and
      (Sha256Bytes(LSnapshot) = Sha256Bytes(LBytes)), 'Large initial write changed');
    LStream.Size := 172;
    LCurrent := LStream.Snapshot;
    Check((LStream.Size = 172) and (LStream.Position = 172) and
      (Length(LCurrent) = 172), 'Large shrink did not clamp logical size/cursor');
    for LIndex := 0 to High(LCurrent) do
    begin
      Check(LCurrent[LIndex] = LBytes[LIndex], 'Shrink changed retained prefix');
    end;
    LStream.Size := 70000;
    LCurrent := LStream.Snapshot;
    for LIndex := 172 to High(LCurrent) do
    begin
      Check(LCurrent[LIndex] = 0, 'Regrowth exposed stale bytes');
    end;
    Check(Sha256Bytes(LSnapshot) = Sha256Bytes(LBytes), 'Snapshot aliases mutable storage');
    LCurrent[0] := 255;
    LCurrent := LStream.Snapshot;
    Check(LCurrent[0] = LBytes[0], 'Mutating snapshot changed owned storage');
    LStream.Size := 2;
    LStream.Position := 9;
    SetLength(LCurrent, 2);
    LCurrent[0] := 5;
    LCurrent[1] := 6;
    WriteStreamBytesExact(LStream, LCurrent, 0, 2);
    LCurrent := LStream.Snapshot;
    Check((Length(LCurrent) = 11) and (LStream.Position = 11) and
      (LCurrent[0] = LBytes[0]) and (LCurrent[1] = LBytes[1]) and
      (LCurrent[9] = 5) and (LCurrent[10] = 6), 'Sparse write geometry/bytes differ');
    for LIndex := 2 to 8 do
    begin
      Check(LCurrent[LIndex] = 0, 'Sparse write gap is not zero');
    end;
    LStream.Position := 9;
    SetLength(LCurrent, 4);
    LCurrent[2] := 199;
    LCurrent[3] := 201;
    Check(ReadStreamBytes(LStream, LCurrent, 0, 4) = 2, 'Read did not stop at logical end');
    Check((LCurrent[0] = 5) and (LCurrent[1] = 6) and (LCurrent[2] = 199) and
      (LCurrent[3] = 201) and (LStream.Position = 11), 'Partial read changed buffer suffix');
    Check(ReadStreamBytes(LStream, LCurrent, 0, 4) = 0, 'End read did not return zero');
    LStream.Size := 0;
    Check((LStream.Position = 0) and (LStream.Size = 0) and
      (Length(LStream.Snapshot) = 0), 'Clearing logical bytes failed');
  finally
    LStream.Free;
  end;

  LStream := TCallerStream.Create(16);
  LReadOnly := nil;
  try
    SetLength(LBytes, 16);
    TCallerStream(LStream).ResizeFromInteger(16);
    Check(LStream.Size = 16, 'Caller integer resize selected a silent RTL overload');
    WriteStreamBytesExact(LStream, LBytes, 0, Length(LBytes));
    RejectedBounds(LStream);
    LReadOnly := TAudioBytesReadStream.Create(LBytes);
    RejectedBounds(LReadOnly);
    LSnapshot := LReadOnly.Snapshot;
    LSnapshot[0] := 255;
    LCurrent := LReadOnly.Snapshot;
    Check((LBytes[0] <> 255) and (LCurrent[0] <> 255),
      'Read-only snapshot aliases its borrowed input');
  finally
    LReadOnly.Free;
    LStream.Free;
  end;

  LStream := TAudioBytesStream.Create(0);
  try
    Check((LStream.Size = 0) and (LStream.MaximumBytes = 0), 'Empty budget rejected');
    LRejected := False;
    try
      LStream.Size := 1;
    except
      on EAudio do
      begin
        LRejected := True;
      end;
    end;
    Check(LRejected and (LStream.Size = 0), 'Empty budget allocated data');
  finally
    LStream.Free;
  end;
  LStream := TAudioBytesStream.Create(High(Integer));
  try
    LStream.Position := High(Integer);
    Check((LStream.Size = 0) and (Length(LStream.Snapshot) = 0),
      'Forward seek allocated storage');
    LRejected := False;
    try
      LStream.Seek(1, soCurrent);
    except
      on EAudio do
      begin
        LRejected := True;
      end;
    end;
    Check(LRejected and (LStream.Position = High(Integer)), 'Seek overflow changed cursor');
    LStream.Size := 0;
    Check(LStream.Position = 0, 'Resize did not clamp a distant cursor');
  finally
    LStream.Free;
  end;
end;

begin
  try
    Run;
    WriteLn('PASS bounded byte storage checks=', GChecks);
  except
    on LException: Exception do
    begin
      WriteLn(LException.ClassName, ': ', LException.Message);
      ExitCode := 1;
    end;
  end;
end.
