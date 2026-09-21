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

unit pythian.spectrum;

{$mode delphi}
{$H+}

interface

uses
  pythian.fourier;

const
  MaximumSpectrumBins = MaximumFourierSize div 2 + 1;
  MaximumSpectrumBands = 128;

type
  TSpectrumBinRange = record
    FirstBin: Integer;
    LastBin: Integer;
  end;
  TSpectrumBinRanges = array of TSpectrumBinRange;

  TSpectrumPowerRegion = record
    FirstBin: Integer;
    LastBin: Integer;
    Power: Double;
    PeakBin: Integer;
    PeakPower: Double;
  end;
  TSpectrumPowerRegions = array of TSpectrumPowerRegion;

  TSpectrumPowerPartition = record
    TotalPower: Double;
    Bands: TSpectrumPowerRegions;
    Gaps: TSpectrumPowerRegions;
  end;

{ Summarizes caller-provided nonnegative bin powers over inclusive scope.
  Bands must be nonempty, ordered, disjoint and entirely within the scope.
  Zero bands is valid: one gap then covers the whole scope. Gaps precede,
  separate and follow the bands; empty gaps have LastBin = FirstBin - 1.
  PeakBin is -1 for empty/zero-power regions; positive ties choose the first bin.
  All input bins, including those outside the scope, must be finite and no
  greater than MaxDouble/(4*Length(APower)). No FFT, weighting, normalization,
  frequency interpretation or harmonic/pitch admission is performed here.
  Results own detached arrays. Rejected calls preserve inputs and a previously
  assigned result. Work is O(input bins + scoped bins + bands), at most
  32769 input bins and 128 bands; offline allocation is bounded by those limits. }
function PartitionPowerSpectrum(const APower: TFourierValues;
  const ABands: TSpectrumBinRanges; const AFirstBin, ALastBin: Integer):
  TSpectrumPowerPartition;

implementation

uses
  Math,
  pythian.audio;

function SummarizeRegion(const APower: TFourierValues;
  const AFirstBin, ALastBin: Integer): TSpectrumPowerRegion;
var
  LIndex: Integer;
begin
  Result := Default(TSpectrumPowerRegion);
  Result.FirstBin := AFirstBin;
  Result.LastBin := ALastBin;
  Result.PeakBin := -1;
  for LIndex := AFirstBin to ALastBin do
  begin
    Result.Power := Result.Power + APower[LIndex];
    if APower[LIndex] > Result.PeakPower then
    begin
      Result.PeakPower := APower[LIndex];
      Result.PeakBin := LIndex;
    end;
  end;
end;

function PartitionPowerSpectrum(const APower: TFourierValues;
  const ABands: TSpectrumBinRanges; const AFirstBin, ALastBin: Integer):
  TSpectrumPowerPartition;
var
  LCandidate: TSpectrumPowerPartition;
  LLimit: Double;
  LPrevious: Integer;
  LIndex: Integer;
begin
  if (Length(APower) < 1) or (Length(APower) > MaximumSpectrumBins) or
    (Length(ABands) > MaximumSpectrumBands) or
    (AFirstBin < 0) or (ALastBin < AFirstBin) or (ALastBin >= Length(APower)) then
  begin
    raise EAudio.Create('Spectrum partition exceeds bin, band or scope bounds');
  end;
  LLimit := MaxDouble / (4.0 * Length(APower));
  for LIndex := 0 to High(APower) do
  begin
    RequireFinite(APower[LIndex], 'Spectrum bin power');
    if (APower[LIndex] < 0) or (APower[LIndex] > LLimit) then
    begin
      raise EAudio.Create('Spectrum bin power exceeds finite nonnegative sum bound');
    end;
  end;
  LPrevious := AFirstBin - 1;
  for LIndex := 0 to High(ABands) do
  begin
    if (ABands[LIndex].FirstBin <= LPrevious) or
      (ABands[LIndex].LastBin < ABands[LIndex].FirstBin) or
      (ABands[LIndex].LastBin > ALastBin) then
    begin
      raise EAudio.Create('Spectrum bands must be ordered disjoint ranges within scope');
    end;
    LPrevious := ABands[LIndex].LastBin;
  end;
  LCandidate := Default(TSpectrumPowerPartition);
  SetLength(LCandidate.Bands, Length(ABands));
  SetLength(LCandidate.Gaps, Length(ABands) + 1);
  LPrevious := AFirstBin;
  for LIndex := 0 to High(ABands) do
  begin
    LCandidate.Gaps[LIndex] := SummarizeRegion(APower, LPrevious,
      ABands[LIndex].FirstBin - 1);
    LCandidate.Bands[LIndex] := SummarizeRegion(APower,
      ABands[LIndex].FirstBin, ABands[LIndex].LastBin);
    LPrevious := ABands[LIndex].LastBin + 1;
  end;
  LCandidate.Gaps[High(LCandidate.Gaps)] :=
    SummarizeRegion(APower, LPrevious, ALastBin);
  for LIndex := AFirstBin to ALastBin do
  begin
    LCandidate.TotalPower := LCandidate.TotalPower + APower[LIndex];
  end;
  Result := LCandidate;
end;

end.

