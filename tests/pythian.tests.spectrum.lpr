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

program pythian_tests_spectrum;

{$mode delphi}
{$H+}

uses
  SysUtils,
  Math,
  pythian.audio,
  pythian.fourier,
  pythian.spectrum;

procedure Check(const ACondition: Boolean; const AMessage: String);
begin
  if not ACondition then
  begin
    raise Exception.Create(AMessage);
  end;
end;

procedure Run;
var
  LPower: TFourierValues;
  LOriginal: TFourierValues;
  LBands: TSpectrumBinRanges;
  LResult: TSpectrumPowerPartition;
  LOther: TSpectrumPowerPartition;
  LRejected: Boolean;
  I: Integer;
  K: Integer;
begin
  SetLength(LPower, 9);
  for I := 0 to High(LPower) do
  begin
    LPower[I] := I;
  end;
  LPower[0] := 1000;
  LPower[6] := 5;
  LOriginal := Copy(LPower);
  SetLength(LBands, 2);
  LBands[0].FirstBin := 2;
  LBands[0].LastBin := 3;
  LBands[1].FirstBin := 5;
  LBands[1].LastBin := 6;
  LResult := PartitionPowerSpectrum(LPower, LBands, 1, 8);
  Check((LResult.TotalPower = 35) and (LResult.Bands[0].Power = 5) and
    (LResult.Bands[1].Power = 10), 'Known scope and band sums');
  Check((LResult.Gaps[0].Power = 1) and (LResult.Gaps[1].Power = 4) and
    (LResult.Gaps[2].Power = 15), 'Before/between/after partition');
  Check((LResult.Bands[1].PeakBin = 5) and (LResult.Gaps[2].PeakBin = 8),
    'First positive tie and residual peak');
  LOther := PartitionPowerSpectrum(LPower, LBands, 1, 8);
  LOther.Bands[0].Power := 999;
  Check(LResult.Bands[0].Power = 5, 'Separate calls own detached arrays');
  for I := 0 to High(LPower) do
  begin
    Check(LPower[I] = LOriginal[I], 'Input powers preserved');
  end;

  for K := 0 to 7 do
  begin
    LPower := Copy(LOriginal);
    SetLength(LBands, 2);
    LBands[1].FirstBin := 5;
    LBands[1].LastBin := 6;
    case K of
      0: LBands[1].FirstBin := 3;
      1: LBands[1].LastBin := 9;
      2: LPower[0] := -1;
      3: LPower[0] := Infinity;
      4: LPower[0] := MaxDouble;
      5: LBands[1].FirstBin := 7;
      6: SetLength(LBands, MaximumSpectrumBands + 1);
      7: SetLength(LPower, MaximumSpectrumBins + 1);
    end;
    LRejected := False;
    try
      LResult := PartitionPowerSpectrum(LPower, LBands, 1, 8);
    except
      on LException: EAudio do
      begin
        LRejected := True;
      end;
    end;
    Check(LRejected, 'Invalid power/range must reject');
    Check((LResult.TotalPower = 35) and (Length(LResult.Bands) = 2) and
      (LResult.Bands[0].Power = 5), 'Rejected managed result preserves prior value');
  end;

  SetLength(LBands, 0);
  LPower := Copy(LOriginal);
  LResult := PartitionPowerSpectrum(LPower, LBands, 1, 8);
  Check((Length(LResult.Bands) = 0) and (Length(LResult.Gaps) = 1) and
    (LResult.Gaps[0].Power = 35), 'No bands leaves the whole scope residual');
  SetLength(LBands, 2);
  LBands[0].FirstBin := 1;
  LBands[0].LastBin := 4;
  LBands[1].FirstBin := 5;
  LBands[1].LastBin := 8;
  LResult := PartitionPowerSpectrum(LPower, LBands, 1, 8);
  for I := 0 to High(LResult.Gaps) do
  begin
    Check((LResult.Gaps[I].LastBin = LResult.Gaps[I].FirstBin - 1) and
      (LResult.Gaps[I].Power = 0) and (LResult.Gaps[I].PeakBin = -1),
      'Adjacent bands leave explicit empty gaps');
  end;
  SetLength(LBands, 0);
  SetLength(LPower, MaximumSpectrumBins);
  for I := 0 to High(LPower) do
  begin
    LPower[I] := 0;
  end;
  LResult := PartitionPowerSpectrum(LPower, LBands, 0, High(LPower));
  Check((LResult.TotalPower = 0) and (LResult.Gaps[0].PeakBin = -1),
    'Maximum-size silence has no positive peak');
  SetLength(LBands, MaximumSpectrumBands);
  for I := 0 to High(LBands) do
  begin
    LBands[I].FirstBin := 2 * I;
    LBands[I].LastBin := 2 * I;
    LPower[2 * I] := 1;
  end;
  LResult := PartitionPowerSpectrum(LPower, LBands, 0, High(LPower));
  Check((LResult.TotalPower = MaximumSpectrumBands) and
    (Length(LResult.Gaps) = MaximumSpectrumBands + 1),
    'Maximum band count retains complete scope');
  WriteLn('PASS spectrum power conservation, residual geometry, peaks, bounds and ownership');
end;

begin
  try
    Run;
  except
    on LException: Exception do
    begin
      WriteLn(StdErr, LException.Message);
      ExitCode := 1;
    end;
  end;
end.
