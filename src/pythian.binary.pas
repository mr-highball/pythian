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
unit pythian.binary;

{ Extracted from Pythian's WAV and archive field code. The WAV precursor
  provenance and derived notices remain in docs/REFERENCE-REMOVAL.md. }

{$mode delphi}
{$H+}

interface

const
  {$ifdef pas2js}
  MaximumBinaryInteger = 9007199254740991;
  {$else}
  MaximumBinaryInteger = High(Int64);
  {$endif}

{ All fields are little-endian. Unsigned fields have widths 1..8 and a maximum
  value of MaximumBinaryInteger. Signed 64-bit fields cover the full native
  Int64 range; pas2js rejects values outside +/- (2^53 - 1). UInt32 and signed
  32-bit fields retain their physical 32-bit domain on every target.
  Readers borrow bytes. Writers validate the complete field and value before
  changing any byte, including failures for nonfinite binary64 values. }
function ReadUnsignedLE(const ABytes: array of Byte;
  const AOffset, ACount: Integer): Int64;
{ A valid field above AMaximum returns False without changing AValue.
  Malformed windows or maxima still raise. This lets formats retain their own
  unknown/overflow sentinel policy without duplicating integer assembly. }
function TryReadUnsignedLE(const ABytes: array of Byte;
  const AOffset, ACount: Integer; var AValue: Int64;
  const AMaximum: Int64 = MaximumBinaryInteger): Boolean;
procedure WriteUnsignedLE(var ABytes: array of Byte;
  const AOffset, ACount: Integer; const AValue: Int64);
function ReadUInt32LE(const ABytes: array of Byte; const AOffset: Integer): Cardinal;
procedure WriteUInt32LE(var ABytes: array of Byte;
  const AOffset: Integer; const AValue: Cardinal);
function ReadInt32LE(const ABytes: array of Byte; const AOffset: Integer): Integer;
procedure WriteInt32LE(var ABytes: array of Byte;
  const AOffset, AValue: Integer);
function ReadInt64LE(const ABytes: array of Byte; const AOffset: Integer): Int64;
procedure WriteInt64LE(var ABytes: array of Byte;
  const AOffset: Integer; const AValue: Int64);
function ReadFloat64LE(const ABytes: array of Byte; const AOffset: Integer): Double;
procedure WriteFloat64LE(var ABytes: array of Byte;
  const AOffset: Integer; const AValue: Double);

implementation

uses
  Math,
  pythian.audio,
  pythian.ieee754;

procedure RequireWindow(const ALength, AOffset, ACount: Integer);
begin
  if (AOffset < 0) or (ACount < 1) or (ACount > 8) or (AOffset > ALength) then
  begin
    raise EAudio.Create('Binary field window exceeds bounds');
  end;
  if ACount > ALength - AOffset then
  begin
    raise EAudio.Create('Truncated binary field');
  end;
end;

procedure RequireInteger(const AValue: Int64);
begin
  {$ifdef pas2js}
  RequireFinite(AValue, 'Binary integer');
  if (AValue < -MaximumBinaryInteger) or (AValue > MaximumBinaryInteger) or
    (AValue <> Trunc(AValue)) then
  begin
    raise EAudio.Create('Binary integer exceeds exact target domain');
  end;
  {$endif}
end;

function ReadUnsignedLE(const ABytes: array of Byte;
  const AOffset, ACount: Integer): Int64;
begin
  if not TryReadUnsignedLE(ABytes, AOffset, ACount, Result) then
  begin
    raise EAudio.Create('Unsigned binary field exceeds exact target domain');
  end;
end;

function TryReadUnsignedLE(const ABytes: array of Byte;
  const AOffset, ACount: Integer; var AValue: Int64;
  const AMaximum: Int64): Boolean;
var
  LIndex: Integer;
  LValue: Int64;
  LQuotient: Int64;
  LMaximumByte: Int64;
begin
  RequireWindow(Length(ABytes), AOffset, ACount);
  RequireInteger(AMaximum);
  if AMaximum < 0 then
  begin
    raise EAudio.Create('Binary field maximum must be nonnegative');
  end;
  if ACount = 4 then
  begin
    LValue := ReadUInt32LE(ABytes, AOffset);
    if LValue > AMaximum then
    begin
      Exit(False);
    end;
    AValue := LValue;
    Exit(True);
  end;
  LQuotient := AMaximum div 256;
  LMaximumByte := AMaximum mod 256;
  LValue := 0;
  for LIndex := ACount - 1 downto 0 do
  begin
    if (LValue > LQuotient) or ((LValue = LQuotient) and
      (ABytes[AOffset + LIndex] > LMaximumByte)) then
    begin
      Exit(False);
    end;
    LValue := LValue * 256 + ABytes[AOffset + LIndex];
  end;
  AValue := LValue;
  Result := True;
end;

procedure WriteUnsignedLE(var ABytes: array of Byte;
  const AOffset, ACount: Integer; const AValue: Int64);
var
  LRemaining: Int64;
  LIndex: Integer;
begin
  RequireWindow(Length(ABytes), AOffset, ACount);
  RequireInteger(AValue);
  if AValue < 0 then
  begin
    raise EAudio.Create('Unsigned binary field requires a nonnegative value');
  end;
  if ACount = 4 then
  begin
    if AValue > 4294967295 then
    begin
      raise EAudio.Create('Unsigned binary value exceeds field width');
    end;
    WriteUInt32LE(ABytes, AOffset, Cardinal(AValue));
    Exit;
  end;
  LRemaining := AValue;
  for LIndex := 1 to ACount do
  begin
    LRemaining := LRemaining div 256;
  end;
  if LRemaining <> 0 then
  begin
    raise EAudio.Create('Unsigned binary value exceeds field width');
  end;
  LRemaining := AValue;
  for LIndex := 0 to ACount - 1 do
  begin
    ABytes[AOffset + LIndex] := LRemaining mod 256;
    LRemaining := LRemaining div 256;
  end;
end;

function ReadUInt32LE(const ABytes: array of Byte; const AOffset: Integer): Cardinal;
begin
  RequireWindow(Length(ABytes), AOffset, 4);
  { Arithmetic keeps the high word unsigned on pas2js as well as native. }
  Result := Cardinal(ABytes[AOffset]) + Cardinal(ABytes[AOffset + 1]) * 256 +
    Cardinal(ABytes[AOffset + 2]) * 65536 + Cardinal(ABytes[AOffset + 3]) * 16777216;
end;

procedure WriteUInt32LE(var ABytes: array of Byte;
  const AOffset: Integer; const AValue: Cardinal);
begin
  RequireWindow(Length(ABytes), AOffset, 4);
  {$ifdef pas2js}
  RequireInteger(AValue);
  if (AValue < 0) or (AValue > 4294967295) then
  begin
    raise EAudio.Create('Unsigned binary value exceeds 32 bits');
  end;
  {$endif}
  ABytes[AOffset] := AValue and $FF;
  ABytes[AOffset + 1] := (AValue shr 8) and $FF;
  ABytes[AOffset + 2] := (AValue shr 16) and $FF;
  ABytes[AOffset + 3] := (AValue shr 24) and $FF;
end;

function ReadInt32LE(const ABytes: array of Byte; const AOffset: Integer): Integer;
var
  LBits: Cardinal;
begin
  LBits := ReadUInt32LE(ABytes, AOffset);
  if LBits > $7FFFFFFF then
  begin
    Result := -1 - Integer(Cardinal($FFFFFFFF) - LBits);
  end
  else
  begin
    Result := Integer(LBits);
  end;
end;

procedure WriteInt32LE(var ABytes: array of Byte;
  const AOffset, AValue: Integer);
var
  LBits: Cardinal;
begin
  if (Int64(AValue) < -2147483648) or (Int64(AValue) > 2147483647) then
  begin
    raise EAudio.Create('Signed binary value exceeds 32 bits');
  end;
  if AValue < 0 then
  begin
    LBits := Cardinal($FFFFFFFF) - Cardinal(-(AValue + 1));
  end
  else
  begin
    LBits := Cardinal(AValue);
  end;
  WriteUInt32LE(ABytes, AOffset, LBits);
end;

function ReadInt64LE(const ABytes: array of Byte; const AOffset: Integer): Int64;
var
  LLow: Cardinal;
  LHigh: Cardinal;
  {$ifdef pas2js}
  LTop: Double;
  {$else}
  LBits: QWord;
  {$endif}
begin
  RequireWindow(Length(ABytes), AOffset, 8);
  LLow := ReadUInt32LE(ABytes, AOffset);
  LHigh := ReadUInt32LE(ABytes, AOffset + 4);
  {$ifdef pas2js}
  LTop := LHigh;
  if LHigh > $7FFFFFFF then
  begin
    LTop := LTop - 4294967296.0;
  end;
  LTop := LTop * 4294967296.0 + LLow;
  if (LTop < -MaximumBinaryInteger) or (LTop > MaximumBinaryInteger) then
  begin
    raise EAudio.Create('Signed binary field exceeds exact target domain');
  end;
  Result := Trunc(LTop);
  {$else}
  LBits := QWord(LLow) or (QWord(LHigh) shl 32);
  Move(LBits, Result, SizeOf(Result));
  {$endif}
end;

procedure WriteInt64LE(var ABytes: array of Byte;
  const AOffset: Integer; const AValue: Int64);
var
  LLow: Cardinal;
  LHigh: Cardinal;
  {$ifdef pas2js}
  LTop: Double;
  {$else}
  LBits: QWord;
  {$endif}
begin
  RequireWindow(Length(ABytes), AOffset, 8);
  RequireInteger(AValue);
  {$ifdef pas2js}
  LTop := Floor(AValue / 4294967296.0);
  LLow := Cardinal(Trunc(AValue - LTop * 4294967296.0));
  if LTop < 0 then
  begin
    LTop := LTop + 4294967296.0;
  end;
  LHigh := Cardinal(Trunc(LTop));
  {$else}
  Move(AValue, LBits, SizeOf(LBits));
  LLow := Cardinal(LBits and $FFFFFFFF);
  LHigh := Cardinal(LBits shr 32);
  {$endif}
  WriteUInt32LE(ABytes, AOffset, LLow);
  WriteUInt32LE(ABytes, AOffset + 4, LHigh);
end;

function ReadFloat64LE(const ABytes: array of Byte; const AOffset: Integer): Double;
var
  LBits: TBinary64Words;
begin
  RequireWindow(Length(ABytes), AOffset, 8);
  LBits.LowWord := ReadUInt32LE(ABytes, AOffset);
  LBits.HighWord := ReadUInt32LE(ABytes, AOffset + 4);
  Result := DecodeFloat64Bits(LBits);
end;

procedure WriteFloat64LE(var ABytes: array of Byte;
  const AOffset: Integer; const AValue: Double);
var
  LBits: TBinary64Words;
begin
  RequireWindow(Length(ABytes), AOffset, 8);
  LBits := EncodeFloat64Bits(AValue);
  WriteUInt32LE(ABytes, AOffset, LBits.LowWord);
  WriteUInt32LE(ABytes, AOffset + 4, LBits.HighWord);
end;

end.
