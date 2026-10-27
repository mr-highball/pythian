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
program pythian_tests_binary_portable;

{$mode delphi}
{$H+}

uses
  Classes,
  SysUtils,
  {$ifdef pas2js}
  JS,
  {$endif}
  pythian.audio,
  pythian.ieee754,
  pythian.stream.bytes;

var
  GChecks: Integer;
  {$ifdef pas2js}
  GView: TJSDataView;
  {$endif}

{$ifdef pas2js}
function SameNumber(const ALeft, ARight: Double): Boolean; external name 'Object.is';
{$endif}

procedure Check(const AValue: Boolean; const AMessage: String);
begin
  if not AValue then
  begin
    raise Exception.Create(AMessage);
  end;
  Inc(GChecks);
end;

procedure CheckFloat(const ABits: Cardinal);
var
  LSample: Single;
  {$ifndef pas2js}
  LRoundTrip: Cardinal;
  {$endif}
begin
  LSample := DecodeFloat32Bits(ABits);
  {$ifdef pas2js}
  GView.setUint32(0, ABits, True);
  Check(SameNumber(LSample, GView.getFloat32(0, True)),
    'Float32 differs from independent DataView interpretation');
  {$else}
  Move(LSample, LRoundTrip, SizeOf(LRoundTrip));
  Check(LRoundTrip = ABits, 'Float32 differs from original native bit pattern');
  {$endif}
end;

procedure CheckInvalidFloat(const ABits: Cardinal);
var
  LRejected: Boolean;
begin
  LRejected := False;
  try
    DecodeFloat32Bits(ABits);
  except
    on LException: EAudio do
    begin
      LRejected := True;
    end;
  end;
  Check(LRejected, 'Nonfinite float admitted');
end;

procedure TestFloat;
const
  CFractions: array[0..7] of Cardinal =
    (0, 1, 2, 17, $3FFFFF, $400000, $7FFFFE, $7FFFFF);
var
  LSign: Integer;
  LExponent: Integer;
  LIndex: Integer;
  LBits: Cardinal;
  LSeed: Int64;
begin
  {$ifdef pas2js}
  GView := TJSDataView.new(TJSArrayBuffer.new(4));
  {$endif}
  for LSign := 0 to 1 do
  begin
    for LExponent := 0 to 254 do
    begin
      for LIndex := 0 to High(CFractions) do
      begin
        LBits := Cardinal(LSign) * $80000000 +
          Cardinal(LExponent) * $800000 + CFractions[LIndex];
        CheckFloat(LBits);
      end;
    end;
  end;
  LSeed := 731;
  for LIndex := 1 to 10000 do
  begin
    LSeed := (LSeed * 1664525 + 1013904223) mod Int64(4294967296);
    LBits := Cardinal(LSeed);
    if ((LBits shr 23) and $FF) <> 255 then
    begin
      CheckFloat(LBits);
    end;
  end;
  CheckInvalidFloat($7F800000);
  CheckInvalidFloat($FF800000);
  CheckInvalidFloat($7F800001);
  CheckInvalidFloat($FFC00000);
end;

procedure TestStreams;
var
  LStream: TMemoryStream;
  LSource: TAudioBytes;
  LDestination: TAudioBytes;
  LRejected: Boolean;
  LIndex: Integer;
begin
  LStream := TMemoryStream.Create;
  try
    SetLength(LSource, 8);
    SetLength(LDestination, 8);
    for LIndex := 0 to 7 do
    begin
      LSource[LIndex] := 120 + LIndex;
      LDestination[LIndex] := 33;
    end;
    Check(WriteStreamBytes(LStream, LSource, 2, 4) = 4, 'Write exact byte window');
    Check((LStream.Size = 4) and (LSource[2] = 122), 'Write borrows source');
    LStream.Position := 0;
    Check(ReadStreamBytes(LStream, LDestination, 3, 4) = 4, 'Read exact byte window');
    Check((LDestination[2] = 33) and (LDestination[3] = 122) and
      (LDestination[6] = 125) and (LDestination[7] = 33), 'Read preserves surrounding bytes');
    Check(ReadStreamBytes(LStream, LDestination, 0, 1) = 0, 'Read EOF');
    Check(ReadStreamBytes(LStream, LDestination, 8, 0) = 0, 'Empty window at end');
    Check(WriteStreamBytes(LStream, LSource, 8, 0) = 0, 'Empty write at end');
    LRejected := False;
    try
      ReadStreamBytes(LStream, LDestination, 7, 2);
    except
      on LException: EAudio do
      begin
        LRejected := True;
      end;
    end;
    Check(LRejected and (LStream.Position = 4), 'Invalid read preserves stream');
    LRejected := False;
    try
      WriteStreamBytes(LStream, LSource, -1, 1);
    except
      on LException: EAudio do
      begin
        LRejected := True;
      end;
    end;
    Check(LRejected and (LStream.Size = 4), 'Invalid write preserves stream');
    LRejected := False;
    try
      ReadStreamBytes(nil, LDestination, 0, 0);
    except
      on LException: EAudio do
      begin
        LRejected := True;
      end;
    end;
    Check(LRejected, 'Nil stream rejected before empty read');
  finally
    LStream.Free;
  end;
end;

begin
  TestFloat;
  TestStreams;
  WriteLn('PASS ', GChecks, ' binary portability checks');
end.
