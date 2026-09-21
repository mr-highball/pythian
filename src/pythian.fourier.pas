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
unit pythian.fourier;

{$mode delphi}
{$H+}

interface

const
  MaximumFourierSize = 65536;

type
  TFourierValues = array of Double;

{ Complex radix-two transform, sizes 2..65536. Forward uses negative phase and
  no scaling; inverse uses positive phase and divides by N. Results detach from
  shared input arrays. Pass distinct real/imaginary variables (their buffers may
  alias). Invalid geometry/nonfinite or conservatively overflowing inputs leave
  both variables unchanged. This offline primitive allocates candidate buffers. }
procedure Fourier(var AReal, AImaginary: TFourierValues; const AInverse: Boolean = False);

implementation

uses
  Math,
  pythian.audio;

procedure Fourier(var AReal, AImaginary: TFourierValues; const AInverse: Boolean);
var
  LRe: TFourierValues;
  LIm: TFourierValues;
  LSize: Integer;
  LIndex: Integer;
  LReverse: Integer;
  LBit: Integer;
  LBlock: Integer;
  LBase: Integer;
  LOffset: Integer;
  LOther: Integer;
  LTemp: Double;
  LAngle: Double;
  LCos: Double;
  LSin: Double;
  LReal: Double;
  LImaginary: Double;
  LLimit: Double;
begin
  LSize := Length(AReal);
  if (@AReal = @AImaginary) or (LSize < 2) or (LSize > MaximumFourierSize) or
    ((LSize and (LSize - 1)) <> 0) or (Length(AImaginary) <> LSize) then
  begin
    raise EAudio.Create('Fourier transform requires distinct variables and equal power-of-two arrays');
  end;
  LLimit := MaxDouble / (4.0 * LSize);
  for LIndex := 0 to LSize - 1 do
  begin
    RequireFinite(AReal[LIndex], 'Fourier real component');
    RequireFinite(AImaginary[LIndex], 'Fourier imaginary component');
    if (Abs(AReal[LIndex]) > LLimit) or (Abs(AImaginary[LIndex]) > LLimit) then
    begin
      raise EAudio.Create('Fourier input exceeds conservative finite butterfly bound');
    end;
  end;
  LRe := Copy(AReal);
  LIm := Copy(AImaginary);
  LReverse := 0;
  for LIndex := 1 to LSize - 1 do
  begin
    LBit := LSize shr 1;
    while (LReverse and LBit) <> 0 do
    begin
      LReverse := LReverse xor LBit;
      LBit := LBit shr 1;
    end;
    LReverse := LReverse xor LBit;
    if LIndex < LReverse then
    begin
      LTemp := LRe[LIndex];
      LRe[LIndex] := LRe[LReverse];
      LRe[LReverse] := LTemp;
      LTemp := LIm[LIndex];
      LIm[LIndex] := LIm[LReverse];
      LIm[LReverse] := LTemp;
    end;
  end;
  LBlock := 2;
  while LBlock <= LSize do
  begin
    for LOffset := 0 to LBlock div 2 - 1 do
    begin
      LAngle := -2 * Pi * LOffset / LBlock;
      if AInverse then
      begin
        LAngle := -LAngle;
      end;
      LCos := Cos(LAngle);
      LSin := Sin(LAngle);
      LBase := 0;
      while LBase < LSize do
      begin
        LIndex := LBase + LOffset;
        LOther := LIndex + LBlock div 2;
        LReal := LRe[LOther] * LCos - LIm[LOther] * LSin;
        LImaginary := LRe[LOther] * LSin + LIm[LOther] * LCos;
        LRe[LOther] := LRe[LIndex] - LReal;
        LIm[LOther] := LIm[LIndex] - LImaginary;
        LRe[LIndex] := LRe[LIndex] + LReal;
        LIm[LIndex] := LIm[LIndex] + LImaginary;
        Inc(LBase, LBlock);
      end;
    end;
    LBlock := LBlock * 2;
  end;
  if AInverse then
  begin
    for LIndex := 0 to LSize - 1 do
    begin
      LRe[LIndex] := LRe[LIndex] / LSize;
      LIm[LIndex] := LIm[LIndex] / LSize;
    end;
  end;
  AReal := LRe;
  AImaginary := LIm;
end;

end.
