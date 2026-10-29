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
program pythian_tests_fourier_window;

{$mode delphi}
{$H+}

uses
  SysUtils,
  Math,
  pythian.audio,
  pythian.fourier;

var
  GChecks: Integer;

procedure Check(const ACondition: Boolean; const AMessage: String);
begin
  if not ACondition then
  begin
    raise Exception.Create(AMessage);
  end;
  Inc(GChecks);
end;

procedure Reject(const AFrame, ACount: Integer);
var
  LRejected: Boolean;
begin
  LRejected := False;
  try
    PeriodicHannWeight(AFrame, ACount);
  except
    on EAudio do
    begin
      LRejected := True;
    end;
  end;
  Check(LRejected, 'Invalid Hann coordinate must reject');
end;

procedure KnownCoefficients;
var
  LRoot: Double;
begin
  LRoot := Sqrt(2) / 4;
  Check(PeriodicHannWeight(0, 2) = 0, 'Minimum period starts at zero');
  Check(PeriodicHannWeight(1, 2) = 1, 'Minimum period reaches one');
  Check(Abs(PeriodicHannWeight(1, 3) - 0.75) < 2E-15,
    'Nonradix coefficient is supported');
  Check(PeriodicHannWeight(0, 8) = 0, 'Periodic phase starts at zero');
  Check(Abs(PeriodicHannWeight(1, 8) - (0.5 - LRoot)) < 2E-15,
    'First eighth-period coefficient distinguishes shifted windows');
  Check(Abs(PeriodicHannWeight(2, 8) - 0.5) < 2E-15, 'Quarter-period value');
  Check(Abs(PeriodicHannWeight(3, 8) - (0.5 + LRoot)) < 2E-15,
    'Three-eighth-period value');
  Check(PeriodicHannWeight(4, 8) = 1, 'Periodic midpoint reaches one');
  Check(Abs(PeriodicHannWeight(7, 8) - (0.5 - LRoot)) < 2E-15,
    'Final coefficient is not the zero of a symmetric window');
  Reject(0, 0);
  Reject(0, 1);
  Reject(0, -1);
  Reject(0, MaximumFourierSize + 1);
  Reject(-1, 8);
  Reject(8, 8);
  Reject(High(Integer), MaximumFourierSize);
end;

procedure SpectralSupport(const ACount: Integer);
const
  CSpectralTolerance = 1E-8;
var
  LReal: TFourierValues;
  LImaginary: TFourierValues;
  LIndex: Integer;
  LExpected: Double;
  LSum: Double;
begin
  SetLength(LReal, ACount);
  SetLength(LImaginary, ACount);
  LSum := 0;
  for LIndex := 0 to ACount - 1 do
  begin
    LReal[LIndex] := PeriodicHannWeight(LIndex, ACount);
    Check((LReal[LIndex] >= 0) and (LReal[LIndex] <= 1), 'Bounded coefficient');
    if LIndex > 0 then
    begin
      Check(Abs(LReal[LIndex] - PeriodicHannWeight(ACount - LIndex, ACount)) <
        2E-15, 'Periodic reflection');
    end;
    LSum := LSum + LReal[LIndex];
  end;
  Check(Abs(LSum - ACount / 2) < CSpectralTolerance, 'Exact analytic DC gain');
  Fourier(LReal, LImaginary);
  { Multiplying DC by this period has only DC and the two adjacent bins.
    A shifted or symmetric Hann does not have these real-only coefficients. }
  for LIndex := 0 to ACount - 1 do
  begin
    LExpected := 0;
    if LIndex = 0 then
    begin
      LExpected := ACount / 2;
    end
    else if (LIndex = 1) or (LIndex = ACount - 1) then
    begin
      LExpected := -ACount / 4;
    end;
    Check(Abs(LReal[LIndex] - LExpected) < CSpectralTolerance,
      'Periodic Hann analytic real spectral support');
    Check(Abs(LImaginary[LIndex]) < CSpectralTolerance,
      'Periodic Hann has no imaginary spectral component');
  end;
end;

begin
  try
    KnownCoefficients;
    SpectralSupport(8);
    SpectralSupport(64);
    SpectralSupport(512);
    SpectralSupport(2048);
    SpectralSupport(MaximumFourierSize);
    WriteLn('Periodic Hann: ', GChecks, ' checks passed');
  except
    on LException: Exception do
    begin
      WriteLn(LException.ClassName, ': ', LException.Message);
      ExitCode := 1;
    end;
  end;
end.
