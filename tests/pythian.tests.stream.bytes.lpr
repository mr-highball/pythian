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
  WriteLn('Portable byte stream: ', LChecks, ' checks passed');
end.
