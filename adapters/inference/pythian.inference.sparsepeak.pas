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
unit pythian.inference.sparsepeak;

{$mode delphi}
{$H+}

interface

uses
  pythian.audio,
  pythian.inference.observation;

const
  SparsePeakInferenceEstimator = 'pythian-interpolated-peakmap-sparse35cents-midi24-20cent-v1';
  SparsePeakInferencePolicy = 'raw-f32-16k2048-hann8192-peak64-q003-h23-octave-35cent-8sigma-v1';
  SparsePeakWindowFrames = 2048;
  SparsePeakFftFrames = 8192;
  SparsePeakConcentrationGate = 0.03;
  SparsePeakGaussianWidthCents = 35.0;
  SparsePeakProjectionLimitCents = 280.0;
  SparsePeakHarmonicAmbiguityMaximum = 0.4;
  SparsePeakSilenceRms = 1.0E-8;

type
  TSparsePeakInferenceBackend = class(TInferenceBackend)
  strict private
    FWindow: array[0..SparsePeakWindowFrames - 1] of Double;
  public
    constructor Create;
    function Activate(const AWindow: TAudioSamples): TPitchSalience; override;
    function EstimatorIdentity: String; override;
  end;

function SparsePeakBinFrequencyHz(const AIndex: Integer): Double;

implementation

uses
  Math,
  SysUtils,
  pythian.fourier;

const
  CFirstMidiNote = 24;
  CBinsPerSemitone = 5;
  CMaximumDetectedPeaks = 64;
  CPeakCentsTolerance = 35.0;

type
  TDetectedPeak = record
    BinIndex: Integer;
    FrequencyHz: Double;
    Magnitude: Double;
  end;
  TDetectedPeaks = array of TDetectedPeak;

procedure SortPeaksByMagnitudeDescending(var APeaks: TDetectedPeaks;
  const ALeft, ARight: Integer);
var
  LI, LJ, LPivotBin: Integer;
  LPivot: Double;
  LTemp: TDetectedPeak;
begin
  LI := ALeft;
  LJ := ARight;
  LPivot := APeaks[(ALeft + ARight) div 2].Magnitude;
  LPivotBin := APeaks[(ALeft + ARight) div 2].BinIndex;
  repeat
    while (APeaks[LI].Magnitude > LPivot) or
      ((APeaks[LI].Magnitude = LPivot) and
      (APeaks[LI].BinIndex < LPivotBin)) do Inc(LI);
    while (APeaks[LJ].Magnitude < LPivot) or
      ((APeaks[LJ].Magnitude = LPivot) and
      (APeaks[LJ].BinIndex > LPivotBin)) do Dec(LJ);
    if LI <= LJ then
    begin
      LTemp := APeaks[LI];
      APeaks[LI] := APeaks[LJ];
      APeaks[LJ] := LTemp;
      Inc(LI);
      Dec(LJ);
    end;
  until LI > LJ;
  if ALeft < LJ then SortPeaksByMagnitudeDescending(APeaks, ALeft, LJ);
  if LI < ARight then SortPeaksByMagnitudeDescending(APeaks, LI, ARight);
end;

function SparsePeakBinFrequencyHz(const AIndex: Integer): Double;
var
  LMidiNote: Double;
begin
  if (AIndex < Low(TPitchSalience)) or (AIndex > High(TPitchSalience)) then
    raise EAudio.Create('Sparse peak bin is outside 0..359');
  LMidiNote := CFirstMidiNote + AIndex / CBinsPerSemitone;
  Result := 440.0 * Power(2.0, (LMidiNote - 69.0) / 12.0);
end;

constructor TSparsePeakInferenceBackend.Create;
var
  LIndex: Integer;
begin
  inherited Create;
  for LIndex := 0 to SparsePeakWindowFrames - 1 do
    FWindow[LIndex] := 0.5 - 0.5 * Cos(2 * Pi * LIndex /
      (SparsePeakWindowFrames - 1));
end;

function TSparsePeakInferenceBackend.EstimatorIdentity: String;
begin
  Result := SparsePeakInferenceEstimator;
end;

function TSparsePeakInferenceBackend.Activate(
  const AWindow: TAudioSamples): TPitchSalience;
var
  LReal, LImaginary, LPower: TFourierValues;
  LPeaks: TDetectedPeaks;
  LMean, LRms, LTotalPower, LMaxPeakPower, LMaxPeakMagnitude: Double;
  LConcentration, LTonalness, LValue, LDelta, LMagnitude: Double;
  LLeftPower, LCenterPower, LRightPower, LRelativeMagnitude: Double;
  LSupport, LCents, LGaussian: Double;
  LPeakF0Left, LPeakF0Right, LPeakF0, LPairSupport: Double;
  LIndex, LPeakCount, LPeakIndex, LPairLeftIndex, LPairRightIndex: Integer;

  procedure Project(const AFrequency, ASupport: Double);
  var
    LCoordinate, LFirstBinValue, LLastBinValue, LBinCents: Double;
    LFirstBin, LLastBin, LBin: Integer;
  begin
    LCoordinate := 5 * (69 + 12 * Log2(AFrequency / 440) - 24);
    LFirstBinValue := Ceil(LCoordinate -
      SparsePeakProjectionLimitCents / 20);
    LLastBinValue := Floor(LCoordinate +
      SparsePeakProjectionLimitCents / 20);
    LFirstBin := Max(Low(Result), Trunc(LFirstBinValue));
    LLastBin := Min(High(Result), Trunc(LLastBinValue));
    for LBin := LFirstBin to LLastBin do
    begin
      LBinCents := 20 * (LCoordinate - LBin);
      if Abs(LBinCents) <= SparsePeakProjectionLimitCents then
      begin
        LGaussian := Exp(-0.5 * Sqr(LBinCents /
          SparsePeakGaussianWidthCents));
        LSupport := ASupport * LGaussian;
        Result[LBin] := Max(Result[LBin], LSupport);
      end;
    end;
  end;

begin
  if Length(AWindow) <> SparsePeakWindowFrames then
    raise EAudio.Create('Sparse peak inference requires exactly 2048 samples');
  LMean := 0;
  for LIndex := 0 to SparsePeakWindowFrames - 1 do
  begin
    RequireFinite(AWindow[LIndex], 'Sparse peak inference sample');
    LMean := LMean + AWindow[LIndex];
  end;
  LMean := LMean / SparsePeakWindowFrames;
  SetLength(LReal, SparsePeakFftFrames);
  SetLength(LImaginary, SparsePeakFftFrames);
  LRms := 0;
  for LIndex := 0 to SparsePeakWindowFrames - 1 do
  begin
    LValue := AWindow[LIndex] - LMean;
    LRms := LRms + Sqr(LValue);
    LReal[LIndex] := LValue * FWindow[LIndex];
  end;
  LRms := Sqrt(LRms / SparsePeakWindowFrames);
  if LRms <= SparsePeakSilenceRms then
  begin
    Result := Default(TPitchSalience);
    Exit;
  end;

  Fourier(LReal, LImaginary);
  SetLength(LPower, SparsePeakFftFrames div 2 + 1);
  for LIndex := 0 to High(LPower) do
    LPower[LIndex] := Sqr(LReal[LIndex]) + Sqr(LImaginary[LIndex]);
  LTotalPower := 0;
  for LIndex := 1 to High(LPower) - 1 do
    LTotalPower := LTotalPower + LPower[LIndex];
  if IsNan(LTotalPower) or IsInfinite(LTotalPower) or (LTotalPower <= 0) then
  begin
    Result := Default(TPitchSalience);
    Exit;
  end;

  SetLength(LPeaks, High(LPower) div 2);
  LPeakCount := 0;
  for LIndex := 1 to High(LPower) - 1 do
  begin
    if (((LIndex = 1) and (LPower[LIndex] > LPower[LIndex + 1])) or
      ((LIndex = High(LPower) - 1) and
      (LPower[LIndex] >= LPower[LIndex - 1])) or
      ((LIndex > 1) and (LIndex < High(LPower) - 1) and
      (LPower[LIndex] >= LPower[LIndex - 1]) and
      (LPower[LIndex] > LPower[LIndex + 1]))) then
    begin
      LLeftPower := LPower[LIndex - 1];
      LCenterPower := LPower[LIndex];
      LRightPower := LPower[LIndex + 1];
      LDelta := 0;
      if (LLeftPower > 0) and (LCenterPower > 0) and (LRightPower > 0) and
        not IsNan(LLeftPower) and not IsNan(LCenterPower) and
        not IsNan(LRightPower) and not IsInfinite(LLeftPower) and
        not IsInfinite(LCenterPower) and not IsInfinite(LRightPower) then
      begin
        LLeftPower := Ln(LLeftPower);
        LCenterPower := Ln(LCenterPower);
        LRightPower := Ln(LRightPower);
        LValue := LLeftPower - 2 * LCenterPower + LRightPower;
        if not IsNan(LValue) and not IsInfinite(LValue) and
          (Abs(LValue) > 1E-20) then
          LDelta := 0.5 * (LLeftPower - LRightPower) / LValue;
        LDelta := EnsureRange(LDelta, -0.5, 0.5);
        LMagnitude := Sqrt(Exp(LCenterPower + 0.25 *
          (LRightPower - LLeftPower) * LDelta));
      end
      else
        LMagnitude := Sqrt(LCenterPower);
      LPeaks[LPeakCount].BinIndex := LIndex;
      LPeaks[LPeakCount].FrequencyHz :=
        (LIndex + LDelta) * InferenceRate / SparsePeakFftFrames;
      LPeaks[LPeakCount].Magnitude := LMagnitude;
      Inc(LPeakCount);
    end;
  end;
  if LPeakCount = 0 then
  begin
    Result := Default(TPitchSalience);
    Exit;
  end;
  SortPeaksByMagnitudeDescending(LPeaks, 0, LPeakCount - 1);
  if LPeakCount > CMaximumDetectedPeaks then
    LPeakCount := CMaximumDetectedPeaks;
  SetLength(LPeaks, LPeakCount);
  LMaxPeakMagnitude := LPeaks[0].Magnitude;
  LMaxPeakPower := Sqr(LMaxPeakMagnitude);
  LConcentration := LMaxPeakPower / LTotalPower;
  LTonalness := Min(1.0, LConcentration / SparsePeakConcentrationGate);
  Result := Default(TPitchSalience);

  for LPeakIndex := 0 to LPeakCount - 1 do
  begin
    LRelativeMagnitude := LPeaks[LPeakIndex].Magnitude / LMaxPeakMagnitude;
    Project(LPeaks[LPeakIndex].FrequencyHz, LTonalness * LRelativeMagnitude);
    Project(LPeaks[LPeakIndex].FrequencyHz / 2,
      SparsePeakHarmonicAmbiguityMaximum * LTonalness * LRelativeMagnitude);
  end;

  for LPairLeftIndex := 0 to LPeakCount - 1 do
  begin
    LPeakF0Left := LPeaks[LPairLeftIndex].FrequencyHz / 2;
    for LPairRightIndex := 0 to LPeakCount - 1 do
    begin
      if LPairRightIndex = LPairLeftIndex then
        Continue;
      LPeakF0Right := LPeaks[LPairRightIndex].FrequencyHz / 3;
      LCents := 1200 * Log2(LPeakF0Left / LPeakF0Right);
      if Abs(LCents) <= CPeakCentsTolerance then
      begin
        LPeakF0 := Sqrt(LPeakF0Left * LPeakF0Right);
        LPairSupport := SparsePeakHarmonicAmbiguityMaximum * LTonalness *
          Min(LPeaks[LPairLeftIndex].Magnitude / LMaxPeakMagnitude,
          LPeaks[LPairRightIndex].Magnitude / LMaxPeakMagnitude);
        Project(LPeakF0, LPairSupport);
      end;
    end;
  end;
end;

end.
