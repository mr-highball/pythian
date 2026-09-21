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
unit pythian.beat;

{$mode delphi}
{$H+}

interface

uses
  pythian.audio;

const
  BeatGridVersion = 1;
  BeatGridMeasurementPolicy = 'phase-concentration-64-two-phase';
  MaximumBeatObservations = 8192;
  MaximumBeatTrials = 4096;
  MaximumBeatWork = 16000000;
  MaximumBeatFrames = 65536;

type
  TBeatObservation = record
    Frame: Integer;
    Weight: Double;
  end;
  TBeatObservations = array of TBeatObservation;
  TBeatGridOptions = record
    MinimumBpm: Double;
    MaximumBpm: Double;
    StepBpm: Double;
    MinimumSeparationBpm: Double;
    ToleranceSeconds: Double;
    MinimumMatchedWeight: Double;
    MinimumCycles: Integer;
    MaximumCandidates: Integer;
  end;
  TBeatGridCandidate = record
    Bpm: Double;
    PeriodFrames: Double;
    PhaseFrame: Double;
    PhaseConcentration: Double;
    MatchedWeightFraction: Double;
    Coverage: Double;
    Score: Double;
    MeanErrorFrames: Double;
    SupportedOnsets: Integer;
    SupportedBeats: Integer;
    GridBeats: Integer;
  end;
  TBeatGridCandidates = array of TBeatGridCandidate;
  TBeatGridAnalysis = record
    ObservationCount: Integer;
    FirstObservationFrame: Integer;
    LastObservationFrame: Integer;
    TrialCount: Integer;
    Candidates: TBeatGridCandidates;
  end;
  TBeatFrames = array of Integer;

function DefaultBeatGridOptions: TBeatGridOptions;

{ Conservative fit visits for validated observation/trial counts. Fewer than
  four observations do no fitting. This excludes candidate-selection scans;
  the estimator and tracker use this same bound before fitting. }
function BeatGridFitWork(const AObservationCount, ATrialCount: Integer): Int64;

{ Positive weights in (0,1], strictly increasing source frames. Caller owns
  source identity, observation admission and weight meaning. Fits constant
  periodic pulse hypotheses over the complete observed span; no meter/downbeat,
  tempo-change tracking or calibrated confidence. An empty candidate array is
  valid insufficient evidence. Two phases per trial can survive; candidate order
  is strongest tempo anchor then its distinct phase companion, not globally
  descending score. Invalid admission preserves an assigned result. }
function EstimateBeatGrids(const AObservations: TBeatObservations;
  const ASampleRate, ASourceFrames: Integer;
  const AOptions: TBeatGridOptions): TBeatGridAnalysis;

{ Rounded grid points in [AStartFrame,AEndFrame), with half-frame ties later.
  Phase is canonical in [0,period). Explicit caller-selected hypothesis; this
  function does not verify its musical meaning or restrict extrapolation. }
function BeatGridFrames(const ACandidate: TBeatGridCandidate;
  const AStartFrame, AEndFrame: Integer): TBeatFrames;

implementation

uses
  Math;

function DefaultBeatGridOptions: TBeatGridOptions;
begin
  Result.MinimumBpm := 40;
  Result.MaximumBpm := 240;
  Result.StepBpm := 0.25;
  Result.MinimumSeparationBpm := 3;
  Result.ToleranceSeconds := 0.03;
  Result.MinimumMatchedWeight := 0.15;
  Result.MinimumCycles := 3;
  Result.MaximumCandidates := 8;
end;

function TrialCount(const AOptions: TBeatGridOptions): Integer;
begin
  RequireFinite(AOptions.MinimumBpm, 'Minimum BPM');
  RequireFinite(AOptions.MaximumBpm, 'Maximum BPM');
  RequireFinite(AOptions.StepBpm, 'BPM step');
  RequireFinite(AOptions.MinimumSeparationBpm, 'BPM separation');
  RequireFinite(AOptions.ToleranceSeconds, 'Beat tolerance');
  RequireFinite(AOptions.MinimumMatchedWeight, 'Minimum matched-weight fraction');
  if (AOptions.MinimumBpm < 20) or (AOptions.MaximumBpm > 400) or
    (AOptions.MaximumBpm < AOptions.MinimumBpm) or (AOptions.StepBpm < 0.01) or
    (AOptions.StepBpm > 20) or (AOptions.MinimumSeparationBpm < AOptions.StepBpm) or
    (AOptions.MinimumSeparationBpm > 40) or
    (AOptions.ToleranceSeconds <= 0) or (AOptions.ToleranceSeconds > 0.1) or
    (AOptions.MinimumMatchedWeight < 0) or (AOptions.MinimumMatchedWeight > 1) or
    (AOptions.MinimumCycles < 2) or (AOptions.MinimumCycles > 32) or
    (AOptions.MaximumCandidates < 1) or (AOptions.MaximumCandidates > 32) then
  begin
    raise EAudio.Create('Beat grid options exceed their bounds');
  end;
  Result := Floor((AOptions.MaximumBpm - AOptions.MinimumBpm) / AOptions.StepBpm +
    0.000000001) + 1;
  if Result > MaximumBeatTrials then
  begin
    raise EAudio.Create('Beat tempo trials exceed budget');
  end;
end;

const
  CPhaseCount = 2;
  CObservationWalks = 1 + 2 * CPhaseCount;
  { Logical histogram/phase visits, not elapsed time or machine instructions. }
  CFixedFitWork = 2368;

function BeatGridFitWork(const AObservationCount, ATrialCount: Integer): Int64;
begin
  if (AObservationCount < 0) or (AObservationCount > MaximumBeatObservations) or
    (ATrialCount < 1) or (ATrialCount > MaximumBeatTrials) then
  begin
    raise EAudio.Create('Beat work counts exceed bounds');
  end;
  Result := 0;
  if AObservationCount >= 4 then
  begin
    Result := Int64(ATrialCount) * (AObservationCount * CObservationWalks + CFixedFitWork);
  end;
end;

type
  TPhaseGrids = array[0..CPhaseCount - 1] of TBeatGridCandidate;

function FitGrids(const AObservations: TBeatObservations; const ASampleRate: Integer;
  const ABpm, AWeightScale: Double; const AOptions: TBeatGridOptions): TPhaseGrids;
const
  CBins = 64;
var
  LHistogram: array[0..CBins - 1] of Double;
  LSmoothed: array[0..CBins - 1] of Double;
  LPeakBins: array[0..CPhaseCount - 1] of Integer;
  LGrid: TBeatGridCandidate;
  LIndex: Integer;
  LBin: Integer;
  LOther: Integer;
  LOffset: Integer;
  LReach: Integer;
  LPhaseIndex: Integer;
  LPrior: Integer;
  LBest: Integer;
  LFirst: Integer;
  LLast: Integer;
  LBeat: Integer;
  LPreviousBeat: Integer;
  LFirstBeat: Integer;
  LLastBeat: Integer;
  LSeparated: Boolean;
  LWeight: Double;
  LCurrentWeight: Double;
  LCoordinate: Double;
  LFraction: Double;
  LDistance: Double;
  LSum: Double;
  LBestSum: Double;
  LRadius: Double;
  LPhase: Double;
  LPeriod: Double;
  LTolerance: Double;
  LError: Double;
  LMatchedWeight: Double;
  LShift: Double;
  LUniform: Double;
  LConcentrated: Double;
begin
  Result := Default(TPhaseGrids);
  LPeriod := ASampleRate * 60.0 / ABpm;
  LFirst := AObservations[0].Frame;
  LLast := AObservations[High(AObservations)].Frame;
  if LLast - LFirst < AOptions.MinimumCycles * LPeriod then
  begin
    Exit;
  end;
  LTolerance := Min(LPeriod / 4, ASampleRate * AOptions.ToleranceSeconds);
  LRadius := LTolerance / LPeriod * CBins;
  LReach := Ceil(LRadius);
  FillChar(LHistogram, SizeOf(LHistogram), 0);
  FillChar(LPeakBins, SizeOf(LPeakBins), 0);
  LWeight := 0;
  for LIndex := 0 to High(AObservations) do
  begin
    LCoordinate := Frac((AObservations[LIndex].Frame - LFirst) / LPeriod) * CBins;
    LBin := Floor(LCoordinate);
    LFraction := LCoordinate - LBin;
    LCurrentWeight := AObservations[LIndex].Weight / AWeightScale;
    LWeight := LWeight + LCurrentWeight;
    LHistogram[LBin] := LHistogram[LBin] + LCurrentWeight * (1 - LFraction);
    LOther := (LBin + 1) mod CBins;
    LHistogram[LOther] := LHistogram[LOther] + LCurrentWeight * LFraction;
  end;
  for LBin := 0 to CBins - 1 do
  begin
    LSum := 0;
    for LOffset := -LReach to LReach do
    begin
      LDistance := Abs(LOffset);
      if LDistance < LRadius then
      begin
        LOther := (LBin + LOffset + CBins) mod CBins;
        LSum := LSum + LHistogram[LOther] * (1 - LDistance / LRadius);
      end;
    end;
    LSmoothed[LBin] := LSum;
  end;
  for LPhaseIndex := 0 to CPhaseCount - 1 do
  begin
    LBest := -1;
    LBestSum := 0;
    for LBin := 0 to CBins - 1 do
    begin
      LSeparated := True;
      for LPrior := 0 to LPhaseIndex - 1 do
      begin
        if LPeakBins[LPrior] >= 0 then
        begin
          LDistance := Abs(LBin - LPeakBins[LPrior]);
          LDistance := Min(LDistance, CBins - LDistance);
          LSeparated := LSeparated and (LDistance >= CBins / 4);
        end;
      end;
      if LSeparated and (LSmoothed[LBin] > LBestSum + 1E-12) then
      begin
        LBestSum := LSmoothed[LBin];
        LBest := LBin;
      end;
    end;
    LPeakBins[LPhaseIndex] := LBest;
    if LBest < 0 then
    begin
      Continue;
    end;
    LGrid := Default(TBeatGridCandidate);
    LGrid.Bpm := ABpm;
    LGrid.PeriodFrames := LPeriod;
    LPhase := LFirst + LBest / CBins * LPeriod;
    LShift := 0;
    LMatchedWeight := 0;
    for LIndex := 0 to High(AObservations) do
    begin
      LBeat := Floor((AObservations[LIndex].Frame - LPhase) / LPeriod + 0.5);
      LDistance := AObservations[LIndex].Frame - (LPhase + LBeat * LPeriod);
      if Abs(LDistance) <= LTolerance then
      begin
        LCurrentWeight := AObservations[LIndex].Weight / AWeightScale;
        LShift := LShift + LDistance * LCurrentWeight;
        LMatchedWeight := LMatchedWeight + LCurrentWeight;
      end;
    end;
    if LMatchedWeight = 0 then
    begin
      Continue;
    end;
    LPhase := LPhase + LShift / LMatchedWeight;
    LGrid.PhaseFrame := LPhase - Floor(LPhase / LPeriod) * LPeriod;
    if LGrid.PhaseFrame >= LPeriod - 1E-7 then
    begin
      LGrid.PhaseFrame := 0;
    end;
    LFirstBeat := Ceil((LFirst - LTolerance - LGrid.PhaseFrame) / LPeriod);
    LLastBeat := Floor((LLast + LTolerance - LGrid.PhaseFrame) / LPeriod);
    LGrid.GridBeats := Max(0, LLastBeat - LFirstBeat + 1);
    LPreviousBeat := Low(Integer);
    LError := 0;
    LMatchedWeight := 0;
    LConcentrated := 0;
    for LIndex := 0 to High(AObservations) do
    begin
      LBeat := Floor((AObservations[LIndex].Frame - LGrid.PhaseFrame) / LPeriod + 0.5);
      LDistance := Abs(AObservations[LIndex].Frame - (LGrid.PhaseFrame + LBeat * LPeriod));
      if LDistance <= LTolerance then
      begin
        Inc(LGrid.SupportedOnsets);
        if LBeat <> LPreviousBeat then
        begin
          Inc(LGrid.SupportedBeats);
          LPreviousBeat := LBeat;
        end;
        LCurrentWeight := AObservations[LIndex].Weight / AWeightScale;
        LError := LError + LDistance * LCurrentWeight;
        LMatchedWeight := LMatchedWeight + LCurrentWeight;
        LConcentrated := LConcentrated + LCurrentWeight * (1 - LDistance / LTolerance);
      end;
    end;
    LGrid.MatchedWeightFraction := LMatchedWeight / LWeight;
    if (LGrid.SupportedOnsets < 4) or (LGrid.GridBeats = 0) or
      (LGrid.MatchedWeightFraction < AOptions.MinimumMatchedWeight) then
    begin
      Continue;
    end;
    LUniform := LTolerance / LPeriod;
    LGrid.PhaseConcentration := (LConcentrated / LWeight - LUniform) / (1 - LUniform);
    if LGrid.PhaseConcentration < 0 then
    begin
      LGrid.PhaseConcentration := 0;
    end;
    LGrid.MeanErrorFrames := LError / LMatchedWeight;
    LGrid.Coverage := LGrid.SupportedBeats / LGrid.GridBeats;
    LGrid.Score := LGrid.PhaseConcentration * Sqrt(LGrid.Coverage);
    Result[LPhaseIndex] := LGrid;
  end;
end;

function SamePulsePhase(const ALeft, ARight: TBeatGridCandidate; const AFrame: Integer): Boolean;
var
  LPulse: Double;
  LCycle: Double;
begin
  LPulse := ALeft.PhaseFrame + Floor((AFrame - ALeft.PhaseFrame) /
    ALeft.PeriodFrames + 0.5) * ALeft.PeriodFrames;
  LCycle := (LPulse - ARight.PhaseFrame) / ARight.PeriodFrames;
  Result := Abs(LCycle - Floor(LCycle + 0.5)) < 0.25;
end;
function EstimateBeatGrids(const AObservations: TBeatObservations;
  const ASampleRate, ASourceFrames: Integer;
  const AOptions: TBeatGridOptions): TBeatGridAnalysis;
var
  LResult: TBeatGridAnalysis;
  LTrials: TBeatGridCandidates;
  LEligible: array of Boolean;
  LPair: TPhaseGrids;
  LPhaseIndex: Integer;
  LIndex: Integer;
  LPartner: Integer;
  LCenter: Integer;
  LBest: Integer;
  LCount: Integer;
  LPrevious: Integer;
  LBestScore: Double;
  LMaximumWeight: Double;
begin
  LResult := Default(TBeatGridAnalysis);
  LResult.FirstObservationFrame := -1;
  LResult.LastObservationFrame := -1;
  ValidateAudioFormat(ASampleRate, 1);
  LResult.TrialCount := TrialCount(AOptions);
  if (ASourceFrames < 1) or (ASourceFrames > MaximumClipSamples) or
    (ASampleRate * 60.0 / AOptions.MaximumBpm < 2) or
    (Length(AObservations) > MaximumBeatObservations) or
    (BeatGridFitWork(Length(AObservations), LResult.TrialCount) > MaximumBeatWork) then
  begin
    raise EAudio.Create('Beat observations, source geometry or work exceed bounds');
  end;
  LPrevious := -1;
  LMaximumWeight := 0;
  for LIndex := 0 to High(AObservations) do
  begin
    RequireFinite(AObservations[LIndex].Weight, 'Beat observation weight');
    if (AObservations[LIndex].Frame <= LPrevious) or
      (AObservations[LIndex].Frame >= ASourceFrames) or
      (AObservations[LIndex].Weight <= 0) or (AObservations[LIndex].Weight > 1) then
    begin
      raise EAudio.Create('Beat observations require ordered unique frames and positive weights');
    end;
    LPrevious := AObservations[LIndex].Frame;
    LMaximumWeight := Max(LMaximumWeight, AObservations[LIndex].Weight);
  end;
  LResult.ObservationCount := Length(AObservations);
  if Length(AObservations) > 0 then
  begin
    LResult.FirstObservationFrame := AObservations[0].Frame;
    LResult.LastObservationFrame := AObservations[High(AObservations)].Frame;
  end;
  if Length(AObservations) >= 4 then
  begin
    SetLength(LTrials, LResult.TrialCount * CPhaseCount);
    SetLength(LEligible, Length(LTrials));
    for LIndex := 0 to LResult.TrialCount - 1 do
    begin
      LPair := FitGrids(AObservations, ASampleRate,
        AOptions.MinimumBpm + LIndex * AOptions.StepBpm, LMaximumWeight, AOptions);
      for LPhaseIndex := 0 to CPhaseCount - 1 do
      begin
        LTrials[LIndex * CPhaseCount + LPhaseIndex] := LPair[LPhaseIndex];
      end;
    end;
    for LIndex := 0 to High(LTrials) do
    begin
      LEligible[LIndex] := LTrials[LIndex].Score > 0;
      if LIndex >= CPhaseCount then
      begin
        LEligible[LIndex] := LEligible[LIndex] and
          (LTrials[LIndex].Score > LTrials[LIndex - CPhaseCount].Score + 1E-12);
      end;
      if LIndex < Length(LTrials) - CPhaseCount then
      begin
        LEligible[LIndex] := LEligible[LIndex] and
          (LTrials[LIndex].Score >= LTrials[LIndex + CPhaseCount].Score - 1E-12);
      end;
    end;
    SetLength(LResult.Candidates, AOptions.MaximumCandidates);
    LCount := 0;
    LCenter := LResult.FirstObservationFrame +
      (LResult.LastObservationFrame - LResult.FirstObservationFrame) div 2;
    while LCount < AOptions.MaximumCandidates do
    begin
      LBest := -1;
      LBestScore := 0;
      for LIndex := 0 to High(LTrials) do
      begin
        if LEligible[LIndex] and (LTrials[LIndex].Score > LBestScore + 1E-12) then
        begin
          LBest := LIndex;
          LBestScore := LTrials[LIndex].Score;
        end;
      end;
      if LBest < 0 then
      begin
        Break;
      end;
      LResult.Candidates[LCount] := LTrials[LBest];
      Inc(LCount);
      if LCount < AOptions.MaximumCandidates then
      begin
        LPartner := -1;
        LBestScore := 0;
        for LIndex := 0 to High(LTrials) do
        begin
          if LEligible[LIndex] and (LTrials[LIndex].Score > LBestScore + 1E-12) and
            (Abs(LTrials[LIndex].Bpm - LTrials[LBest].Bpm) < AOptions.MinimumSeparationBpm) and
            not SamePulsePhase(LTrials[LIndex], LTrials[LBest], LCenter) then
          begin
            LPartner := LIndex;
            LBestScore := LTrials[LIndex].Score;
          end;
        end;
        if LPartner >= 0 then
        begin
          LResult.Candidates[LCount] := LTrials[LPartner];
          Inc(LCount);
        end;
      end;
      for LIndex := 0 to High(LTrials) do
      begin
        if Abs(LTrials[LIndex].Bpm - LTrials[LBest].Bpm) < AOptions.MinimumSeparationBpm then
        begin
          LEligible[LIndex] := False;
        end;
      end;
    end;
    SetLength(LResult.Candidates, LCount);
  end;
  Result := LResult;
end;

function BeatGridFrames(const ACandidate: TBeatGridCandidate;
  const AStartFrame, AEndFrame: Integer): TBeatFrames;
var
  LFrames: TBeatFrames;
  LFirst: Integer;
  LLast: Integer;
  LBeat: Integer;
  LFrame: Integer;
  LCount: Integer;
begin
  RequireFinite(ACandidate.PeriodFrames, 'Beat period');
  RequireFinite(ACandidate.PhaseFrame, 'Beat phase');
  if (ACandidate.PeriodFrames < 2) or (ACandidate.PeriodFrames > MaximumClipSamples) or
    (ACandidate.PhaseFrame < 0) or (ACandidate.PhaseFrame >= ACandidate.PeriodFrames) or
    (AStartFrame < 0) or (AEndFrame < AStartFrame) or (AEndFrame > MaximumClipSamples) then
  begin
    raise EAudio.Create('Beat grid geometry exceeds bounds');
  end;
  LFirst := Ceil((AStartFrame - 0.5 - ACandidate.PhaseFrame) / ACandidate.PeriodFrames);
  LLast := Floor((AEndFrame - 0.5 - ACandidate.PhaseFrame) / ACandidate.PeriodFrames);
  if LLast - LFirst + 1 > MaximumBeatFrames then
  begin
    raise EAudio.Create('Rendered beat grid exceeds frame-count budget');
  end;
  LFrames := nil;
  SetLength(LFrames, Max(0, LLast - LFirst + 1));
  LCount := 0;
  for LBeat := LFirst to LLast do
  begin
    LFrame := Floor(ACandidate.PhaseFrame + LBeat * ACandidate.PeriodFrames + 0.5);
    if (LFrame >= AStartFrame) and (LFrame < AEndFrame) then
    begin
      LFrames[LCount] := LFrame;
      Inc(LCount);
    end;
  end;
  SetLength(LFrames, LCount);
  Result := LFrames;
end;

end.
