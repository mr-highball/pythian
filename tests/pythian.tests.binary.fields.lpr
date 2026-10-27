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
program pythian_tests_binary_fields;

{$mode delphi}
{$H+}

uses
  SysUtils,
  Math,
  pythian.audio,
  pythian.binary,
  pythian.ieee754;

var
  GChecks: Integer;
  GBytes: TAudioBytes;

procedure Check(const ACondition: Boolean; const AMessage: String);
begin
  Inc(GChecks);
  if not ACondition then
  begin
    raise Exception.Create(AMessage);
  end;
end;

procedure ResetBytes;
var
  LIndex: Integer;
begin
  SetLength(GBytes, 12);
  for LIndex := 0 to High(GBytes) do
  begin
    GBytes[LIndex] := $A5;
  end;
end;

procedure GuardBytes;
begin
  Check((GBytes[0] = $A5) and (GBytes[1] = $A5) and
    (GBytes[10] = $A5) and (GBytes[11] = $A5), 'Surrounding bytes changed');
end;

procedure FloatCase(const ALow, AHigh: Cardinal; const AExpected: Double);
var
  LValue: Double;
  LWords: TBinary64Words;
begin
  ResetBytes;
  WriteUInt32LE(GBytes, 2, ALow);
  WriteUInt32LE(GBytes, 6, AHigh);
  LValue := ReadFloat64LE(GBytes, 2);
  Check(LValue = AExpected, 'Authored binary64 value differs');
  LWords := EncodeFloat64Bits(LValue);
  Check((LWords.LowWord = ALow) and (LWords.HighWord = AHigh),
    'Authored binary64 bits, including signed zero, differ');
  ResetBytes;
  WriteFloat64LE(GBytes, 2, AExpected);
  LWords := EncodeFloat64Bits(AExpected);
  Check((ReadUInt32LE(GBytes, 2) = LWords.LowWord) and
    (ReadUInt32LE(GBytes, 6) = LWords.HighWord), 'Binary64 field differs from value bits');
  GuardBytes;
end;

procedure FloatPatterns;
var
  LSign: Integer;
  LExponent: Integer;
  LPattern: Integer;
  LLow: Cardinal;
  LHigh: Cardinal;
  LWords: TBinary64Words;
  LValue: Double;
begin
  for LSign := 0 to 1 do
  begin
    for LExponent := 0 to 2046 do
    begin
      for LPattern := 0 to 3 do
      begin
        LLow := 0;
        LHigh := Cardinal(LExponent) shl 20;
        if LSign = 1 then
        begin
          LHigh := LHigh + Cardinal($80000000);
        end;
        case LPattern of
          1:
            begin
              LLow := 1;
            end;
          2:
            begin
              LLow := $FFFFFFFF;
            end;
          3:
            begin
              LLow := $FFFFFFFF;
              LHigh := LHigh + $FFFFF;
            end;
        end;
        ResetBytes;
        WriteUInt32LE(GBytes, 2, LLow);
        WriteUInt32LE(GBytes, 6, LHigh);
        LValue := ReadFloat64LE(GBytes, 2);
        WriteFloat64LE(GBytes, 2, LValue);
        LWords := EncodeFloat64Bits(LValue);
        Check((ReadUInt32LE(GBytes, 2) = LLow) and
          (ReadUInt32LE(GBytes, 6) = LHigh) and
          (LWords.LowWord = LLow) and (LWords.HighWord = LHigh),
          'Finite binary64 pattern or signed zero lost');
        GuardBytes;
      end;
    end;
  end;
end;

procedure RejectCase(const AVariant: Integer);
var
  LRejected: Boolean;
  LIndex: Integer;
  LInteger: Int64;
  LReal: Double;
  {$ifdef pas2js}
  LUnsafeInteger: Int64;
  {$endif}
begin
  ResetBytes;
  LRejected := False;
  LInteger := 0;
  LReal := 0;
  {$ifdef pas2js}
  LUnsafeInteger := MaximumBinaryInteger;
  Inc(LUnsafeInteger);
  {$endif}
  try
    case AVariant of
      0: WriteUnsignedLE(GBytes, -1, 4, 1);
      1: WriteUnsignedLE(GBytes, High(Integer), 4, 1);
      2: WriteUnsignedLE(GBytes, 2, 0, 1);
      3: WriteUnsignedLE(GBytes, 2, 9, 1);
      4: WriteUnsignedLE(GBytes, 10, 4, 1);
      5: WriteUnsignedLE(GBytes, 2, 1, 256);
      6: WriteUnsignedLE(GBytes, 2, 4, -1);
      7: WriteFloat64LE(GBytes, 6, 1);
      8: WriteFloat64LE(GBytes, 2, Infinity);
      9: WriteFloat64LE(GBytes, 2, NaN);
      10: LInteger := ReadUnsignedLE(GBytes, -1, 4);
      11: LInteger := ReadUnsignedLE(GBytes, 0, 9);
      12: LReal := ReadFloat64LE(GBytes, 6);
      16: TryReadUnsignedLE(GBytes, 2, 1, LInteger, -1);
      {$ifdef pas2js}
      13: WriteInt64LE(GBytes, 2, LUnsafeInteger);
      14: WriteInt32LE(GBytes, 2, 2147483648);
      15: WriteUInt32LE(GBytes, 2, 4294967296);
      {$endif}
    end;
  except
    on EAudio do
    begin
      LRejected := True;
    end;
  end;
  Check(LRejected, 'Invalid field/value was accepted: ' + IntToStr(AVariant));
  for LIndex := 0 to High(GBytes) do
  begin
    Check(GBytes[LIndex] = $A5, 'Rejected write changed bytes');
  end;
  Check((LInteger = 0) and (LReal = 0), 'Failed read published a value');
end;

procedure NonfiniteReads;
var
  LSign: Integer;
  LFraction: Integer;
  LRejected: Boolean;
  LValue: Double;
begin
  for LSign := 0 to 1 do
  begin
    for LFraction := 0 to 2 do
    begin
      ResetBytes;
      WriteUInt32LE(GBytes, 2, Cardinal(LFraction));
      WriteUInt32LE(GBytes, 6, Cardinal($7FF00000) +
        Cardinal(LSign) * Cardinal($80000000));
      LRejected := False;
      LValue := 7;
      try
        LValue := ReadFloat64LE(GBytes, 2);
      except
        on EAudio do
        begin
          LRejected := True;
        end;
      end;
      Check(LRejected and (LValue = 7), 'Nonfinite read must fail before publication');
      GuardBytes;
    end;
  end;
end;

procedure IntegerCases;
var
  LWidth: Integer;
  LIndex: Integer;
  LValue: Int64;
  LRejected: Boolean;
begin
  ResetBytes;
  WriteUInt32LE(GBytes, 2, $FEDCBA98);
  Check((GBytes[2] = $98) and (GBytes[3] = $BA) and
    (GBytes[4] = $DC) and (GBytes[5] = $FE), 'UInt32 authored endian oracle');
  Check(ReadUInt32LE(GBytes, 2) = $FEDCBA98, 'UInt32 high bit changed');
  WriteInt32LE(GBytes, 2, -2147483648);
  Check((ReadUInt32LE(GBytes, 2) = $80000000) and
    (ReadInt32LE(GBytes, 2) = -2147483648), 'Signed32 minimum');
  WriteInt32LE(GBytes, 2, -1);
  Check((ReadUInt32LE(GBytes, 2) = $FFFFFFFF) and
    (ReadInt32LE(GBytes, 2) = -1), 'Signed32 negative one');
  WriteInt32LE(GBytes, 2, 2147483647);
  Check(ReadInt32LE(GBytes, 2) = 2147483647, 'Signed32 maximum');
  GBytes[2] := 1;
  LValue := 7;
  Check(not TryReadUnsignedLE(GBytes, 2, 1, LValue, 0) and (LValue = 7),
    'Failed bounded read must preserve the caller sentinel');
  GBytes[2] := 0;
  Check(TryReadUnsignedLE(GBytes, 2, 1, LValue, 0) and (LValue = 0),
    'Zero maximum accepts only zero');
  GBytes[2] := 2;
  GBytes[3] := 1;
  LValue := 7;
  Check(not TryReadUnsignedLE(GBytes, 2, 2, LValue, 257) and (LValue = 7),
    'Bounded read must check the low-byte remainder');
  Check(TryReadUnsignedLE(GBytes, 2, 2, LValue, 258) and (LValue = 258),
    'Bounded read must accept its exact maximum');
  for LWidth := 1 to 8 do
  begin
    ResetBytes;
    LValue := 0;
    for LIndex := LWidth - 1 downto 0 do
    begin
      if LIndex < 6 then
      begin
        LValue := LValue * 256 + LIndex + 1;
      end;
    end;
    WriteUnsignedLE(GBytes, 2, LWidth, LValue);
    Check(ReadUnsignedLE(GBytes, 2, LWidth) = LValue, 'Unsigned field width');
    for LIndex := 0 to LWidth - 1 do
    begin
      if LIndex < 6 then
      begin
        Check(GBytes[2 + LIndex] = LIndex + 1, 'Authored unsigned byte order');
      end
      else
      begin
        Check(GBytes[2 + LIndex] = 0, 'Wide unsigned zero extension');
      end;
    end;
    GuardBytes;
  end;
  WriteUnsignedLE(GBytes, 2, 8, MaximumBinaryInteger);
  Check(ReadUnsignedLE(GBytes, 2, 8) = MaximumBinaryInteger, 'Exact target ceiling');
  WriteInt64LE(GBytes, 2, -9007199254740991);
  Check(ReadInt64LE(GBytes, 2) = -9007199254740991, 'Negative exact wide boundary');
  WriteInt64LE(GBytes, 2, 9007199254740991);
  Check(ReadInt64LE(GBytes, 2) = 9007199254740991, 'Positive exact wide boundary');
  WriteInt64LE(GBytes, 2, -4294967297);
  Check((ReadInt64LE(GBytes, 2) = -4294967297) and
    (ReadUInt32LE(GBytes, 2) = $FFFFFFFF) and
    (ReadUInt32LE(GBytes, 6) = $FFFFFFFE), 'Negative wide authored limbs');
  {$ifndef pas2js}
  WriteInt64LE(GBytes, 2, Low(Int64));
  Check(ReadInt64LE(GBytes, 2) = Low(Int64), 'Full native signed64 minimum');
  WriteInt64LE(GBytes, 2, High(Int64));
  Check(ReadInt64LE(GBytes, 2) = High(Int64), 'Full native signed64 maximum');
  {$else}
  WriteUInt32LE(GBytes, 2, 0);
  WriteUInt32LE(GBytes, 6, $200000);
  LRejected := False;
  try
    LValue := ReadInt64LE(GBytes, 2);
  except
    on EAudio do
    begin
      LRejected := True;
    end;
  end;
  Check(LRejected, 'Browser must reject unsafe signed64 input');
  LRejected := False;
  try
    LValue := ReadUnsignedLE(GBytes, 2, 8);
  except
    on EAudio do
    begin
      LRejected := True;
    end;
  end;
  Check(LRejected, 'Browser must reject unsafe unsigned64 input');
  {$endif}
end;

var
  LVariant: Integer;
begin
  IntegerCases;
  FloatCase(0, 0, 0);
  FloatCase(0, $80000000, 0);
  FloatCase(0, $3FF00000, 1);
  FloatCase(0, $BFF00000, -1);
  FloatCase($9999999A, $3FB99999, 0.1);
  FloatCase($54442D18, $400921FB, 3.141592653589793);
  FloatCase(1, $3FF00000, 1.0000000000000002);
  FloatCase(1, 0, 4.9406564584124654E-324);
  FloatCase(0, $00100000, 2.2250738585072014E-308);
  FloatCase($FFFFFFFF, $7FEFFFFF, 1.7976931348623157E308);
  FloatCase(0, $43400000, 9007199254740992.0);
  FloatPatterns;
  NonfiniteReads;
  for LVariant := 0 to 12 do
  begin
    RejectCase(LVariant);
  end;
  RejectCase(16);
  {$ifdef pas2js}
  for LVariant := 13 to 15 do
  begin
    RejectCase(LVariant);
  end;
  {$endif}
  WriteLn('Binary fields: ', GChecks, ' checks passed');
end.
