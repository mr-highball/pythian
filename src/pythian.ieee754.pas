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

{ Interpret one finite IEEE-754 binary32 bit pattern. Exact powers of two keep
  all finite normal/subnormal values and signed zero; no endian or host memory
  layout is assumed. NaN and infinities reject as invalid audio. }
function DecodeFloat32Bits(const ABits: Cardinal): Single;

implementation

uses
  pythian.audio;

var
  GFloat32Scales: array[0..254] of Double;

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

end.
