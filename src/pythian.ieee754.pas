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
unit pythian.ieee754;

{$mode delphi}
{$H+}

interface

const
  MaximumFiniteFloat32 = 3.40282346638528859811704183484516925440E38;

type
  { Two exact words also represent the complete binary64 payload on pas2js,
    where a single integer cannot represent all 64-bit patterns. }
  TBinary64Words = record
    LowWord: Cardinal;
    HighWord: Cardinal;
  end;

{ Interpret one finite IEEE-754 binary32 bit pattern. Exact powers of two keep
  all finite normal/subnormal values and signed zero; no endian or host memory
  layout is assumed. NaN and infinities reject as invalid audio. }
function DecodeFloat32Bits(const ABits: Cardinal): Single;
function EncodeFloat64Bits(const AValue: Double): TBinary64Words;
function DecodeFloat64Bits(const ABits: TBinary64Words): Double;

implementation

uses
  {$ifdef pas2js}
  JS,
  {$endif}
  pythian.audio;

var
  GFloat32Scales: array[0..254] of Double;
  {$ifdef pas2js}
  { Private synchronous platform bit view. Each call overwrites all eight
    bytes; no borrowed buffer, callback or view escapes this unit. }
  GFloat64View: TJSDataView;
  {$endif}

function EncodeFloat64Bits(const AValue: Double): TBinary64Words;
{$ifndef pas2js}
var
  LBits: QWord;
{$endif}
begin
  RequireFinite(AValue, 'Binary64 value');
  {$ifdef pas2js}
  GFloat64View.setFloat64(0, AValue, True);
  Result.LowWord := GFloat64View.getUint32(0, True);
  Result.HighWord := GFloat64View.getUint32(4, True);
  {$else}
  Move(AValue, LBits, SizeOf(LBits));
  Result.LowWord := Cardinal(LBits and $FFFFFFFF);
  Result.HighWord := Cardinal(LBits shr 32);
  {$endif}
end;

function DecodeFloat64Bits(const ABits: TBinary64Words): Double;
{$ifndef pas2js}
var
  LBits: QWord;
{$endif}
begin
  if (ABits.HighWord and $7FF00000) = $7FF00000 then
  begin
    raise EAudio.Create('Non-finite binary64 value');
  end;
  {$ifdef pas2js}
  GFloat64View.setUint32(0, ABits.LowWord, True);
  GFloat64View.setUint32(4, ABits.HighWord, True);
  Result := GFloat64View.getFloat64(0, True);
  {$else}
  LBits := QWord(ABits.LowWord) or (QWord(ABits.HighWord) shl 32);
  Move(LBits, Result, SizeOf(Result));
  {$endif}
end;

function DecodeFloat32Bits(const ABits: Cardinal): Single;
var
  LExponent: Integer;
  LFraction: Cardinal;
  LValue: Double;
begin
  LExponent := (ABits shr 23) and $FF;
  if LExponent = 255 then
  begin
    raise EAudio.Create('Non-finite WAVE float sample');
  end;
  LFraction := ABits and $7FFFFF;
  if LExponent <> 0 then
  begin
    LFraction := LFraction + $800000;
  end;
  LValue := LFraction * GFloat32Scales[LExponent];
  if (ABits and $80000000) <> 0 then
  begin
    LValue := -LValue;
  end;
  Result := LValue;
end;

procedure InitializeScales;
var
  LIndex: Integer;
begin
  GFloat32Scales[0] := 1.401298464324817070923729583289916131280E-45;
  GFloat32Scales[1] := GFloat32Scales[0];
  for LIndex := 2 to High(GFloat32Scales) do
  begin
    GFloat32Scales[LIndex] := GFloat32Scales[LIndex - 1] * 2;
  end;
end;

initialization
  InitializeScales;
  {$ifdef pas2js}
  GFloat64View := TJSDataView.new(TJSArrayBuffer.new(8));
  {$endif}

end.
