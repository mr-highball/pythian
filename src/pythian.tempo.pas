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

unit pythian.tempo;

{$mode delphi}
{$H+}

interface

uses
  pythian.analysis;

const
  TempoMeasurementVersion = 1;
  MaximumTempoWork = 32000000;

type
  TTempoOptions = record
    MinimumBpm: Double;
    MaximumBpm: Double;
    MinimumFlux: Double;
    MinimumCorrelation: Double;
    MinimumCycles: Integer;
    MaximumCandidates: Integer;
  end;

  TTempoCandidate = record
    LagFeatures: Integer;
    PeriodFrames: Double;
    MicrosecondsPerQuarter: Integer;
    Bpm: Double;
    Correlation: Double;
    SupportingPairs: Integer;
  end;
  TTempoCandidates = array of TTempoCandidate;
  TTempoStatus = (tsInsufficientDuration, tsInsufficientActivity, tsNoPeriod, tsCandidates);
  TTempoReport = record
    Status: TTempoStatus;
    CompleteFeatures: Integer;
    ActiveFeatures: Integer;
    EnvelopeEnergy: Double;
    Candidates: TTempoCandidates;
  end;

function DefaultTempoOptions: TTempoOptions;
{ Ranks global periodicity in existing nonnegative spectral-flux measurements.
  Uses complete windows, removes local mean and retains positive onset strength.
  Normalized lag correlation has no preferred BPM or half/double-time folding.
  Peaks are interpolated within one lag; scores are not probabilities.
  A candidate is a pulse-rate interpretation, not a beat/downbeat or meter claim.
  Source identity and choice of musical pulse level remain caller-owned.
  Features must match the complete supplied source grid. No WFC dependency. }
function RankTempoCandidates(const AFeatures: TAudioFeatures;
  const AAnalysis: TAnalysisOptions; const ASampleRate, ASourceFrames: Integer;
  const AOptions: TTempoOptions): TTempoReport;

implementation

uses
  Math,
  SysUtils,
  pythian.audio;

type
  TTempoNumbers = array of Double;

function DefaultTempoOptions: TTempoOptions;
begin
  Result.MinimumBpm := 40;
  Result.MaximumBpm := 240;
  Result.MinimumFlux := 0.05;
  Result.MinimumCorrelation := 0.2;
  Result.MinimumCycles := 4;
  Result.MaximumCandidates := 8;
end;

function RankTempoCandidates(const AFeatures: TAudioFeatures;
  const AAnalysis: TAnalysisOptions; const ASampleRate, ASourceFrames: Integer;
  const AOptions: TTempoOptions): TTempoReport;
var
  LResult: TTempoReport;
  LEnvelope: TTempoNumbers;
  LPrefix: TTempoNumbers;
  LCorrelation: TTempoNumbers;
  LSupport: array of Integer;
  LCandidate: TTempoCandidate;
  LCount: Integer;
  LExpected: Integer;
  LIndex: Integer;
  LLag: Integer;
  LFirstLag: Integer;
  LLastLag: Integer;
  LRadius: Integer;
  LLeft: Integer;
  LRight: Integer;
  LPosition: Integer;
  LWork: Int64;
  LSum: Double;
  LEnergyLeft: Double;
  LEnergyRight: Double;
  LOffset: Double;
  LCurvature: Double;
  LFeatureRate: Double;
begin
  ValidateAudioFormat(ASampleRate, 1);
  RequireFinite(AOptions.MinimumBpm, 'Minimum tempo');
  RequireFinite(AOptions.MaximumBpm, 'Maximum tempo');
  RequireFinite(AOptions.MinimumFlux, 'Minimum tempo flux');
  RequireFinite(AOptions.MinimumCorrelation, 'Minimum tempo correlation');
  if (AOptions.MinimumBpm < 20) or (AOptions.MaximumBpm > 400) or
    (AOptions.MinimumBpm >= AOptions.MaximumBpm) or
    (AOptions.MinimumFlux < 0) or (AOptions.MinimumFlux > 1) or
    (AOptions.MinimumCorrelation <= 0) or (AOptions.MinimumCorrelation > 1) or
    (AOptions.MinimumCycles < 3) or (AOptions.MinimumCycles > 32) or
    (AOptions.MaximumCandidates < 1) or (AOptions.MaximumCandidates > 16) then
  begin
    raise EAudio.Create('Tempo measurement options exceed their bounds');
  end;
  PlanAudioAnalysis(ASourceFrames, 1, AAnalysis, LExpected, LWork);
  if Length(AFeatures) <> LExpected then
  begin
    raise EAudio.Create('Tempo features must cover the exact source grid');
  end;
  LResult := Default(TTempoReport);
  LCount := 0;
  for LIndex := 0 to High(AFeatures) do
  begin
    RequireFinite(AFeatures[LIndex].Flux, 'Tempo spectral flux');
    if (AFeatures[LIndex].StartFrame <> LIndex * AAnalysis.HopFrames) or
      (AFeatures[LIndex].ValidFrames <> Min(AAnalysis.WindowFrames,
        ASourceFrames - AFeatures[LIndex].StartFrame)) then
    begin
      raise EAudio.Create('Tempo feature geometry is invalid');
    end;
    { Existing spectral accumulation can exceed one by single-precision rounding. }
    if (AFeatures[LIndex].Flux < 0) or (AFeatures[LIndex].Flux > 1 + 0.000001) then
    begin
      raise EAudio.Create('Tempo spectral flux outside normalized range at feature ' +
        IntToStr(LIndex) + ': ' + FloatToStr(AFeatures[LIndex].Flux));
    end;
    if AFeatures[LIndex].ValidFrames = AAnalysis.WindowFrames then
    begin
      Inc(LCount);
    end;
  end;
  LResult.CompleteFeatures := LCount;
  LFeatureRate := ASampleRate / AAnalysis.HopFrames;
  { One extra lag on each side supplies interpolation neighbors. }
  LFirstLag := Max(2, Integer(Ceil(60 * LFeatureRate / AOptions.MaximumBpm)));
  LLastLag := Min(Integer(Floor(60 * LFeatureRate / AOptions.MinimumBpm)),
    (LCount - 1) div AOptions.MinimumCycles);
  if LLastLag < LFirstLag then
  begin
    Result := LResult;
    Exit;
  end;
  if Int64(LLastLag - LFirstLag + 3) * LCount > MaximumTempoWork then
  begin
    raise EAudio.Create('Tempo lag correlation exceeds its work budget; use an excerpt');
  end;
  SetLength(LEnvelope, LCount);
  SetLength(LPrefix, LCount + 1);
  for LIndex := 1 to LCount - 1 do
  begin
    { First spectrum has no previous window; silence cannot provide an onset. }
    if not AFeatures[LIndex].Silent then
    begin
      LEnvelope[LIndex] := Min(1.0, AFeatures[LIndex].Flux);
    end;
    LPrefix[LIndex + 1] := LPrefix[LIndex] + LEnvelope[LIndex];
  end;
  LRadius := Max(1, Integer(Round(LFeatureRate / 2)));
  for LIndex := 0 to LCount - 1 do
  begin
    LLeft := Max(0, LIndex - LRadius);
    LRight := Min(LCount, LIndex + LRadius + 1);
    if LEnvelope[LIndex] >= AOptions.MinimumFlux then
    begin
      LEnvelope[LIndex] := Max(0, LEnvelope[LIndex] -
        (LPrefix[LRight] - LPrefix[LLeft]) / (LRight - LLeft));
    end
    else
    begin
      LEnvelope[LIndex] := 0;
    end;
    if LEnvelope[LIndex] > 0 then
    begin
      Inc(LResult.ActiveFeatures);
    end;
    LResult.EnvelopeEnergy := LResult.EnvelopeEnergy + Sqr(LEnvelope[LIndex]);
  end;
  if (LResult.ActiveFeatures < AOptions.MinimumCycles + 1) or
    (LResult.EnvelopeEnergy = 0) then
  begin
    LResult.Status := tsInsufficientActivity;
    Result := LResult;
    Exit;
  end;
  SetLength(LCorrelation, LLastLag + 2);
  SetLength(LSupport, LLastLag + 2);
  for LLag := LFirstLag - 1 to LLastLag + 1 do
  begin
    LSum := 0;
    LEnergyLeft := 0;
    LEnergyRight := 0;
    for LIndex := LLag to LCount - 1 do
    begin
      LSum := LSum + LEnvelope[LIndex] * LEnvelope[LIndex - LLag];
      LEnergyLeft := LEnergyLeft + Sqr(LEnvelope[LIndex - LLag]);
      LEnergyRight := LEnergyRight + Sqr(LEnvelope[LIndex]);
      if (LEnvelope[LIndex] > 0) and (LEnvelope[LIndex - LLag] > 0) then
      begin
        Inc(LSupport[LLag]);
      end;
    end;
    if (LEnergyLeft > 0) and (LEnergyRight > 0) then
    begin
      LCorrelation[LLag] := Min(1, LSum / Sqrt(LEnergyLeft * LEnergyRight));
    end;
  end;
  LResult.Status := tsNoPeriod;
  for LLag := LFirstLag to LLastLag do
  begin
    if (LCorrelation[LLag] < AOptions.MinimumCorrelation) or
      (LSupport[LLag] < AOptions.MinimumCycles) or
      (LCorrelation[LLag] <= LCorrelation[LLag - 1]) or
      (LCorrelation[LLag] < LCorrelation[LLag + 1]) then
    begin
      Continue;
    end;
    LOffset := 0;
    LCurvature := LCorrelation[LLag - 1] - 2 * LCorrelation[LLag] + LCorrelation[LLag + 1];
    if LCurvature < 0 then
    begin
      LOffset := EnsureRange(0.5 * (LCorrelation[LLag - 1] -
        LCorrelation[LLag + 1]) / LCurvature, -0.5, 0.5);
    end;
    LCandidate.LagFeatures := LLag;
    LCandidate.PeriodFrames := (LLag + LOffset) * AAnalysis.HopFrames;
    LCandidate.Bpm := 60 * ASampleRate / LCandidate.PeriodFrames;
    if (LCandidate.Bpm < AOptions.MinimumBpm) or (LCandidate.Bpm > AOptions.MaximumBpm) then
    begin
      Continue;
    end;
    LCandidate.MicrosecondsPerQuarter := Round(1000000 * LCandidate.PeriodFrames / ASampleRate);
    LCandidate.Correlation := LCorrelation[LLag];
    LCandidate.SupportingPairs := LSupport[LLag];
    LPosition := 0;
    while (LPosition < Length(LResult.Candidates)) and
      (LResult.Candidates[LPosition].Correlation >= LCandidate.Correlation) do
    begin
      Inc(LPosition);
    end;
    if LPosition >= AOptions.MaximumCandidates then
    begin
      Continue;
    end;
    SetLength(LResult.Candidates, Min(AOptions.MaximumCandidates, Length(LResult.Candidates) + 1));
    for LIndex := High(LResult.Candidates) downto LPosition + 1 do
    begin
      LResult.Candidates[LIndex] := LResult.Candidates[LIndex - 1];
    end;
    LResult.Candidates[LPosition] := LCandidate;
    LResult.Status := tsCandidates;
  end;
  Result := LResult;
end;

end.
