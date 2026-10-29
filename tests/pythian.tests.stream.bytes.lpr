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
program pythian_tests_stream_bytes;
{$mode delphi}
{$H+}
uses SysUtils, Classes, pythian.audio, pythian.stream.bytes;
type
  { Platform I/O signatures only; the shared exact-transfer algorithm receives
    the same short, zero, invalid-count and original-exception cases. }
  TShortStream = class(TMemoryStream)
    ReadBudget: Integer;
    WriteBudget: Integer;
    Reads: Integer;
    Writes: Integer;
    RaiseRead: Boolean;
    RaiseWrite: Boolean;
    Oversize: Boolean;
    NegativeCount: Boolean;
    Raised: Exception;
    constructor Create;
    {$ifdef pas2js}
    function Read(ABuffer: TBytes; AOffset, ACount: LongInt): LongInt; override;
    function Write(const ABuffer: TBytes; AOffset, ACount: LongInt): LongInt; override;
    {$else}
    function Read(var ABuffer; ACount: LongInt): LongInt; override;
    function Write(const ABuffer; ACount: LongInt): LongInt; override;
    {$endif}
  end;
var
  LChecks: Integer;
procedure Check(const ACondition: Boolean; const AMessage: String);
begin
  if not ACondition then
  begin
    raise Exception.Create(AMessage);
  end;
  Inc(LChecks);
end;

constructor TShortStream.Create;
begin
  inherited Create;
  ReadBudget := -1;
  WriteBudget := -1;
end;

{$ifdef pas2js}
function TShortStream.Read(ABuffer: TBytes; AOffset, ACount: LongInt): LongInt;
{$else}
function TShortStream.Read(var ABuffer; ACount: LongInt): LongInt;
{$endif}
var
  LCount: Integer;
begin
  Inc(Reads);
  if RaiseRead then
  begin
    Raised := Exception.Create('Original read failure');
    raise Raised;
  end;
  LCount := ACount;
  if LCount > 2 then
  begin
    LCount := 2;
  end;
  if (ReadBudget >= 0) and (LCount > ReadBudget) then
  begin
    LCount := ReadBudget;
  end;
  {$ifdef pas2js}
  Result := inherited Read(ABuffer, AOffset, LCount);
  {$else}
  Result := inherited Read(ABuffer, LCount);
  {$endif}
  if ReadBudget >= 0 then
  begin
    Dec(ReadBudget, Result);
  end;
  if Oversize then
  begin
    Result := ACount + 1;
  end;
  if NegativeCount then
  begin
    Result := -1;
  end;
end;

{$ifdef pas2js}
function TShortStream.Write(const ABuffer: TBytes; AOffset, ACount: LongInt): LongInt;
{$else}
function TShortStream.Write(const ABuffer; ACount: LongInt): LongInt;
{$endif}
var
  LCount: Integer;
begin
  Inc(Writes);
  if RaiseWrite then
  begin
    Raised := EAudio.Create('Original write failure');
    raise Raised;
  end;
  LCount := ACount;
  if LCount > 2 then
  begin
    LCount := 2;
  end;
  if (WriteBudget >= 0) and (LCount > WriteBudget) then
  begin
    LCount := WriteBudget;
  end;
  {$ifdef pas2js}
  Result := inherited Write(ABuffer, AOffset, LCount);
  {$else}
  Result := inherited Write(ABuffer, LCount);
  {$endif}
  if WriteBudget >= 0 then
  begin
    Dec(WriteBudget, Result);
  end;
  if Oversize then
  begin
    Result := ACount + 1;
  end;
  if NegativeCount then
  begin
    Result := -1;
  end;
end;

procedure CheckExact;
var
  LSource: TAudioBytes;
  LDest: TAudioBytes;
  LStream: TShortStream;
  LIndex: Integer;
  LAction: Integer;
  LCalls: Integer;
  LRejected: Boolean;
begin
  SetLength(LSource, 8);
  SetLength(LDest, 10);
  for LIndex := 0 to High(LSource) do
  begin
    LSource[LIndex] := LIndex + 11;
  end;
  LStream := TShortStream.Create;
  try
    WriteStreamBytesExact(LStream, LSource, 2, 5);
    Check((LStream.Writes = 3) and (LStream.Size = 5), 'Exact writer accumulates short writes');
    LStream.Position := 0;
    for LIndex := 0 to High(LDest) do
    begin
      LDest[LIndex] := 77;
    end;
    ReadStreamBytesExact(LStream, LDest, 2, 5);
    Check((LStream.Reads = 3) and (LStream.Position = 5), 'Exact reader accumulates short reads');
    for LIndex := 0 to 4 do
    begin
      Check(LDest[LIndex + 2] = LSource[LIndex + 2], 'Exact subwindow bytes');
    end;
    Check((LDest[0] = 77) and (LDest[1] = 77) and (LDest[7] = 77) and
      (LDest[9] = 77), 'Exact read preserves outside destination');
    LCalls := LStream.Reads + LStream.Writes;
    ReadStreamBytesExact(LStream, LDest, Length(LDest), 0);
    WriteStreamBytesExact(LStream, LSource, Length(LSource), 0);
    Check(LCalls = LStream.Reads + LStream.Writes, 'Zero count performs no I/O');
    for LAction := 0 to 3 do
    begin
      LRejected := False;
      try
        case LAction of
          0: ReadStreamBytesExact(LStream, LDest, -1, 1);
          1: WriteStreamBytesExact(LStream, LSource, 0, 9);
          2: ReadStreamBytesExact(nil, LDest, 0, 0);
          3: WriteStreamBytesExact(LStream, LSource, 0, -1);
        end;
      except
        on EAudio do
        begin
          LRejected := True;
        end;
      end;
      Check(LRejected and (LCalls = LStream.Reads + LStream.Writes),
        'Invalid exact window rejects before I/O');
    end;
    LStream.Position := 0;
    LStream.ReadBudget := 3;
    for LIndex := 0 to High(LDest) do
    begin
      LDest[LIndex] := 77;
    end;
    LRejected := False;
    try
      ReadStreamBytesExact(LStream, LDest, 1, 5);
    except
      on EReadError do
      begin
        LRejected := True;
      end;
    end;
    Check(LRejected and (LStream.Position = 3), 'Zero read rejects after partial cursor movement');
    Check((LDest[1] = 13) and (LDest[3] = 15) and (LDest[4] = 77),
      'Partial read evidence retained without invented completion');
    LStream.Position := 0;
    LStream.ReadBudget := -1;
    LStream.Oversize := True;
    LRejected := False;
    try
      ReadStreamBytesExact(LStream, LDest, 0, 1);
    except
      on EReadError do
      begin
        LRejected := True;
      end;
    end;
    Check(LRejected, 'Invalid returned read count rejects');
    LStream.Oversize := False;
    LStream.NegativeCount := True;
    LRejected := False;
    try
      ReadStreamBytesExact(LStream, LDest, 0, 1);
    except
      on EReadError do
      begin
        LRejected := True;
      end;
    end;
    Check(LRejected, 'Negative returned read count rejects');
    LStream.NegativeCount := False;
    LStream.RaiseRead := True;
    LRejected := False;
    try
      ReadStreamBytesExact(LStream, LDest, 0, 1);
    except
      on LException: Exception do
      begin
        Check(LException = LStream.Raised, 'Original read exception replaced');
        LStream.Raised := nil;
        LRejected := True;
      end;
    end;
    Check(LRejected, 'Original reader failure propagates');
  finally
    LStream.Free;
  end;
  LStream := TShortStream.Create;
  try
    LStream.WriteBudget := 3;
    LRejected := False;
    try
      WriteStreamBytesExact(LStream, LSource, 0, 5);
    except
      on EWriteError do
      begin
        LRejected := True;
      end;
    end;
    Check(LRejected and (LStream.Position = 3) and (LStream.Size = 3),
      'Zero write rejects without claiming physical rollback');
    LStream.WriteBudget := -1;
    LStream.Oversize := True;
    LRejected := False;
    try
      WriteStreamBytesExact(LStream, LSource, 0, 1);
    except
      on EWriteError do
      begin
        LRejected := True;
      end;
    end;
    Check(LRejected, 'Invalid returned write count rejects');
    LStream.Oversize := False;
    LStream.NegativeCount := True;
    LRejected := False;
    try
      WriteStreamBytesExact(LStream, LSource, 0, 1);
    except
      on EWriteError do
      begin
        LRejected := True;
      end;
    end;
    Check(LRejected, 'Negative returned write count rejects');
    LStream.NegativeCount := False;
    LStream.RaiseWrite := True;
    LRejected := False;
    try
      WriteStreamBytesExact(LStream, LSource, 0, 1);
    except
      on LException: Exception do
      begin
        Check(LException = LStream.Raised, 'Original write exception replaced');
        LStream.Raised := nil;
        LRejected := True;
      end;
    end;
    Check(LRejected, 'Original writer failure propagates');
  finally
    LStream.Free;
  end;
end;

var
  LBytes: TAudioBytes;
  LDest: TAudioBytes;
  LStream: TAudioBytesReadStream;
  LRejected: Boolean;
begin
  SetLength(LBytes, 4);
  LBytes[0] := 17;
  LBytes[1] := 34;
  LBytes[2] := 51;
  LBytes[3] := 68;
  SetLength(LDest, 6);
  LStream := TAudioBytesReadStream.Create(LBytes);
  try
    Check((LStream.Size = 4) and (LStream.Position = 0), 'Initial geometry');
    Check(ReadStreamBytes(LStream, LDest, 1, 2) = 2, 'Read subrange');
    Check((LDest[0] = 0) and (LDest[1] = 17) and (LDest[2] = 34), 'Subrange data');
    Check(LStream.Seek(-1, soCurrent) = 1, 'Relative seek');
    Check(ReadStreamBytes(LStream, LDest, 2, 4) = 3, 'Short read');
    Check((LDest[2] = 34) and (LDest[3] = 51) and (LDest[4] = 68), 'Short read data');
    Check(ReadStreamBytes(LStream, LDest, 0, 1) = 0, 'End of stream');
    Check(LStream.Seek(-1, soEnd) = 3, 'End seek');
    LRejected := False;
    try
      LStream.Seek(2, soCurrent);
    except
      on E: EAudio do
      begin
        LRejected := True;
      end;
    end;
    Check(LRejected and (LStream.Position = 3), 'Invalid seek preserves cursor');
    LRejected := False;
    try
      WriteStreamBytes(LStream, LDest, 0, 1);
    except
      on E: EAudio do
      begin
        LRejected := True;
      end;
    end;
    Check(LRejected and (LStream.Position = 3), 'Write rejects and preserves cursor');
    Check(LStream.Seek(0, soBeginning) = 0, 'Beginning seek');
  finally
    LStream.Free;
  end;
  Check((LBytes[0] = 17) and (LBytes[1] = 34) and (LBytes[2] = 51) and
    (LBytes[3] = 68), 'Borrowed input unmodified');
  LStream := TAudioBytesReadStream.Create(LBytes);
  LBytes := nil;
  try
    Check((ReadStreamBytes(LStream, LDest, 0, 4) = 4) and
      (LDest[0] = 17) and (LDest[3] = 68), 'Retained borrowed array lifetime');
  finally
    LStream.Free;
  end;
  LStream := TAudioBytesReadStream.Create(LBytes);
  try
    Check((LStream.Size = 0) and (ReadStreamBytes(LStream, LDest, 0, 1) = 0),
      'Empty source');
  finally
    LStream.Free;
  end;
  CheckExact;
  WriteLn('Portable byte stream: ', LChecks, ' checks passed');
end.
