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
unit pythian.beat.track;

{$mode delphi}
{$H+}

interface

uses
  pythian.beat,
  pythian.beat.clock;

const
  BeatTrackVersion = 1;
  MaximumBeatTrackWindows = 512;
  MaximumBeatTrackWork = 64000000;
  MaximumBeatPathCandidates = 32;
  MaximumBeatPathWork = 524288;

type
  TBeatTrackOptions = record
    WindowFrames: Integer;
    HopFrames: Integer;
    MaximumTempoRatio: Double;
    TempoPenalty: Double;
    PhasePenalty: Double;
    TaperWindows: Boolean;
    SnapToleranceSeconds: Double;
  end;
  TBeatTrackWindow = record
    StartFrame: Integer;
    EndFrame: Integer;
    OwnerStartFrame: Integer;
    OwnerEndFrame: Integer;
    Analysis: TBeatGridAnalysis;
    SelectedCandidate: Integer;
    StartsNewPath: Boolean;
    JoinGapRatio: Double;
    JoinUncertain: Boolean;
  end;
  TBeatTrackWindows = array of TBeatTrackWindow;
  TBeatTrack = record
    Windows: TBeatTrackWindows;
    Frames: TBeatFrames;
    GridFrames: TBeatFrames;
    ObservationIndices: TBeatFrames;
    FrameWindows: TBeatFrames;
    SeamIssues: Integer;
    FitWork: Int64;
  end;

function DefaultBeatTrackOptions(const ASampleRate: Integer): TBeatTrackOptions;

{ Detached scalar windows for optional continuous-clock reconstruction. Each
  window links its selection to the caller's retained track candidate pool,
  including -1 for a missing selection; alternatives remain with that pool.
  Source bounds and pulse geometry are validated by ReconstructBeatClock. }
function SelectedBeatClockWindows(const AWindows: TBeatTrackWindows): TBeatClockWindows;

{ Reselect a path from caller-supplied candidate windows without measuring onsets
  or rendering frames. Only MaximumTempoRatio, TempoPenalty and PhasePenalty are
  used from AOptions. Ordered contiguous owners must be sample-frame bounded;
  each candidate supplies finite BPM, period, phase and a score in [0,1]. BPM and
  period must describe the same source clock; its identity/rate and the meaning
  of candidate scores remain caller-owned. Other analysis metadata is copied.

  Callers may filter candidates using explicit base context. Returned indices
  address that supplied pool, not a prior unfiltered pool. Input StartsNewPath
  forces a break; missing candidates and impossible joins also break continuity.
  Earlier candidates win score ties within 1e-12; ties are not confidence.
  This is an offline optimum, not automatic tempo/beat admission or a frozen
  streaming prefix. Windows and candidate arrays are detached, and invalid
  input preserves the caller's previously assigned result. }
function SelectBeatTrackPath(const AWindows: TBeatTrackWindows;
  const AOptions: TBeatTrackOptions): TBeatTrackWindows;

{ Offline bounded window analysis and dynamic programming over real candidate
  grids. Keeps alternatives and explicit gaps/restarts; no meter or confidence.
  Each hop interval owns its raw grid points. Optional bounded onset alignment
  retains raw positions and source observation indices (-1 if unaligned).
  Short/long grid seam intervals remain reported. No extrapolation beyond local
  observation spans plus the grid tolerance. Invalid calls preserve results. }
function TrackBeatGrids(const AObservations: TBeatObservations;
  const ASampleRate, ASourceFrames: Integer; const AGridOptions: TBeatGridOptions;
  const ATrackOptions: TBeatTrackOptions): TBeatTrack;

implementation

uses
  Math,
  pythian.audio;

type
  TPathEntry = record
    Score: Double;
    Parent: Integer;
  end;
  TPathEntries = array of TPathEntry;
  TPathWindows = array of TPathEntries;
  TFrameBlocks = array of TBeatFrames;

function DefaultBeatTrackOptions(const ASampleRate: Integer): TBeatTrackOptions;
begin
  ValidateAudioFormat(ASampleRate, 1);
  Result.WindowFrames := ASampleRate * 6;
  Result.HopFrames := Result.WindowFrames div 2;
  Result.MaximumTempoRatio := 1.5;
  Result.TempoPenalty := 0.5;
  Result.PhasePenalty := 0.5;
  Result.TaperWindows := True;
  Result.SnapToleranceSeconds := 0.1;
end;

function SelectedBeatClockWindows(const AWindows: TBeatTrackWindows): TBeatClockWindows;
var
  LResult: TBeatClockWindows;
  LIndex: Integer;
  LChoice: Integer;
begin
  LResult := nil;
  if Length(AWindows) > MaximumBeatClockWindows then
  begin
    raise EAudio.Create('Selected clock exceeds window budget');
  end;
  SetLength(LResult, Length(AWindows));
  for LIndex := 0 to High(AWindows) do
  begin
    LChoice := AWindows[LIndex].SelectedCandidate;
    if (LChoice < -1) or (LChoice >= Length(AWindows[LIndex].Analysis.Candidates)) then
    begin
      raise EAudio.Create('Selected clock candidate is invalid');
    end;
    LResult[LIndex].OwnerStartFrame := AWindows[LIndex].OwnerStartFrame;
    LResult[LIndex].OwnerEndFrame := AWindows[LIndex].OwnerEndFrame;
    LResult[LIndex].HasTrackSelection := True;
    LResult[LIndex].TrackWindowIndex := LIndex;
    LResult[LIndex].SelectedCandidateIndex := LChoice;
    LResult[LIndex].HasPulse := LChoice >= 0;
    LResult[LIndex].StartsNewRun := AWindows[LIndex].StartsNewPath;
    if LChoice >= 0 then
    begin
      LResult[LIndex].FirstObservationFrame := AWindows[LIndex].Analysis.FirstObservationFrame;
      LResult[LIndex].LastObservationFrame := AWindows[LIndex].Analysis.LastObservationFrame;
      LResult[LIndex].PeriodFrames := AWindows[LIndex].Analysis.Candidates[LChoice].PeriodFrames;
      LResult[LIndex].PhaseFrame := AWindows[LIndex].Analysis.Candidates[LChoice].PhaseFrame;
    end;
  end;
  Result := LResult;
end;

function TransitionCost(const ALeft, ARight: TBeatGridCandidate;
  const AFrame: Integer; const AOptions: TBeatTrackOptions): Double;
var
  LRatio: Double;
  LPulse: Double;
  LCycle: Double;
begin
  LRatio := ARight.Bpm / ALeft.Bpm;
  if (LRatio > AOptions.MaximumTempoRatio) or
    (LRatio < 1 / AOptions.MaximumTempoRatio) then
  begin
    Exit(-1);
  end;
  LPulse := ALeft.PhaseFrame + Floor((AFrame - ALeft.PhaseFrame) /
    ALeft.PeriodFrames + 0.5) * ALeft.PeriodFrames;
  LCycle := (LPulse - ARight.PhaseFrame) / ARight.PeriodFrames;
  Result := AOptions.TempoPenalty * Abs(Ln(LRatio) / Ln(2)) +
    AOptions.PhasePenalty * Abs(LCycle - Floor(LCycle + 0.5));
end;

procedure SelectPath(var AWindows: TBeatTrackWindows; const AOptions: TBeatTrackOptions;
  const ARespectRestarts: Boolean);
var
  LPaths: TPathWindows;
  LWindow: Integer;
  LCurrent: Integer;
  LPrevious: Integer;
  LLastActive: Integer;
  LCost: Double;
  LScore: Double;
  LHasEdge: Boolean;

  procedure PublishPath(const ALast: Integer);
  var
    LRow: Integer;
    LChoice: Integer;
    LIndex: Integer;
    LBest: Double;
  begin
    LChoice := -1;
    LBest := -1E300;
    for LIndex := 0 to High(LPaths[ALast]) do
    begin
      if (LPaths[ALast][LIndex].Parent <> -2) and
        (LPaths[ALast][LIndex].Score > LBest + 1E-12) then
      begin
        LChoice := LIndex;
        LBest := LPaths[ALast][LIndex].Score;
      end;
    end;
    LRow := ALast;
    while (LRow >= 0) and (LChoice >= 0) do
    begin
      AWindows[LRow].SelectedCandidate := LChoice;
      AWindows[LRow].StartsNewPath := LPaths[LRow][LChoice].Parent = -1;
      LChoice := LPaths[LRow][LChoice].Parent;
      Dec(LRow);
    end;
  end;

begin
  SetLength(LPaths, Length(AWindows));
  LLastActive := -1;
  for LWindow := 0 to High(AWindows) do
  begin
    if ARespectRestarts and AWindows[LWindow].StartsNewPath and (LLastActive >= 0) then
    begin
      PublishPath(LLastActive);
      LLastActive := -1;
    end;
    SetLength(LPaths[LWindow], Length(AWindows[LWindow].Analysis.Candidates));
    if Length(LPaths[LWindow]) = 0 then
    begin
      if LLastActive >= 0 then
      begin
        PublishPath(LLastActive);
      end;
      LLastActive := -1;
      Continue;
    end;
    LHasEdge := False;
    for LCurrent := 0 to High(LPaths[LWindow]) do
    begin
      LPaths[LWindow][LCurrent].Parent := -2;
      LPaths[LWindow][LCurrent].Score := -1E300;
      if LLastActive < 0 then
      begin
        Continue;
      end;
      for LPrevious := 0 to High(LPaths[LLastActive]) do
      begin
        if LPaths[LLastActive][LPrevious].Parent = -2 then
        begin
          Continue;
        end;
        LCost := TransitionCost(
          AWindows[LLastActive].Analysis.Candidates[LPrevious],
          AWindows[LWindow].Analysis.Candidates[LCurrent],
          AWindows[LWindow].OwnerStartFrame, AOptions);
        if LCost < 0 then
        begin
          Continue;
        end;
        LScore := LPaths[LLastActive][LPrevious].Score +
          AWindows[LWindow].Analysis.Candidates[LCurrent].Score - LCost;
        if LScore > LPaths[LWindow][LCurrent].Score + 1E-12 then
        begin
          LPaths[LWindow][LCurrent].Score := LScore;
          LPaths[LWindow][LCurrent].Parent := LPrevious;
          LHasEdge := True;
        end;
      end;
    end;
    if not LHasEdge then
    begin
      if LLastActive >= 0 then
      begin
        PublishPath(LLastActive);
      end;
      for LCurrent := 0 to High(LPaths[LWindow]) do
      begin
        LPaths[LWindow][LCurrent].Score :=
          AWindows[LWindow].Analysis.Candidates[LCurrent].Score;
        LPaths[LWindow][LCurrent].Parent := -1;
      end;
    end;
    LLastActive := LWindow;
  end;
  if LLastActive >= 0 then
  begin
    PublishPath(LLastActive);
  end;
end;

function SelectBeatTrackPath(const AWindows: TBeatTrackWindows;
  const AOptions: TBeatTrackOptions): TBeatTrackWindows;
var
  LResult: TBeatTrackWindows;
  LVisits: Integer;
  LWindow: Integer;
  LChoice: Integer;
begin
  if (Length(AWindows) < 1) or (Length(AWindows) > MaximumBeatTrackWindows) then
  begin
    raise EAudio.Create('Candidate path window count exceeds bounds');
  end;
  RequireFinite(AOptions.MaximumTempoRatio, 'Candidate path tempo ratio');
  RequireFinite(AOptions.TempoPenalty, 'Candidate path tempo penalty');
  RequireFinite(AOptions.PhasePenalty, 'Candidate path phase penalty');
  if (AOptions.MaximumTempoRatio < 1) or (AOptions.MaximumTempoRatio > 4) or
    (AOptions.TempoPenalty < 0) or (AOptions.TempoPenalty > 10) or
    (AOptions.PhasePenalty < 0) or (AOptions.PhasePenalty > 10) then
  begin
    raise EAudio.Create('Candidate path options exceed bounds');
  end;
  LVisits := 0;
  for LWindow := 0 to High(AWindows) do
  begin
    if (Length(AWindows[LWindow].Analysis.Candidates) > MaximumBeatPathCandidates) or
      (AWindows[LWindow].OwnerStartFrame < 0) or
      (AWindows[LWindow].OwnerEndFrame <= AWindows[LWindow].OwnerStartFrame) or
      (AWindows[LWindow].OwnerEndFrame > MaximumClipSamples) then
    begin
      raise EAudio.Create('Invalid candidate path owner or candidate count');
    end;
    if LWindow > 0 then
    begin
      if AWindows[LWindow].OwnerStartFrame <> AWindows[LWindow - 1].OwnerEndFrame then
      begin
        raise EAudio.Create('Candidate path owners must be contiguous');
      end;
      Inc(LVisits, Length(AWindows[LWindow].Analysis.Candidates) *
        Length(AWindows[LWindow - 1].Analysis.Candidates));
    end;
    for LChoice := 0 to High(AWindows[LWindow].Analysis.Candidates) do
    begin
      RequireFinite(AWindows[LWindow].Analysis.Candidates[LChoice].Bpm, 'Candidate BPM');
      RequireFinite(AWindows[LWindow].Analysis.Candidates[LChoice].PeriodFrames, 'Candidate period');
      RequireFinite(AWindows[LWindow].Analysis.Candidates[LChoice].PhaseFrame, 'Candidate phase');
      RequireFinite(AWindows[LWindow].Analysis.Candidates[LChoice].Score, 'Candidate score');
      if (AWindows[LWindow].Analysis.Candidates[LChoice].Bpm < 20) or
        (AWindows[LWindow].Analysis.Candidates[LChoice].Bpm > 400) or
        (AWindows[LWindow].Analysis.Candidates[LChoice].PeriodFrames < 60 / 400) or
        (AWindows[LWindow].Analysis.Candidates[LChoice].PeriodFrames > MaximumSampleRate * 60 / 20) or
        (Abs(AWindows[LWindow].Analysis.Candidates[LChoice].PhaseFrame) > MaximumClipSamples) or
        (AWindows[LWindow].Analysis.Candidates[LChoice].Score < 0) or
        (AWindows[LWindow].Analysis.Candidates[LChoice].Score > 1) then
      begin
        raise EAudio.Create('Candidate path values exceed bounds');
      end;
    end;
  end;
  if LVisits > MaximumBeatPathWork then
  begin
    raise EAudio.Create('Candidate path exceeds transition budget');
  end;
  LResult := Copy(AWindows);
  for LWindow := 0 to High(LResult) do
  begin
    LResult[LWindow].SelectedCandidate := -1;
    LResult[LWindow].Analysis.Candidates := Copy(AWindows[LWindow].Analysis.Candidates);
  end;
  SelectPath(LResult, AOptions, True);
  Result := LResult;
end;

procedure RenderTrack(var ATrack: TBeatTrack; const ASampleRate: Integer;
  const AGridOptions: TBeatGridOptions);
var
  LBlocks: TFrameBlocks;
  LWindow: Integer;
  LIndex: Integer;
  LCount: Integer;
  LWrite: Integer;
  LTolerance: Integer;
  LStart: Integer;
  LEnd: Integer;
  LPreviousWindow: Integer;
  LPeriod: Double;
  LPreviousPeriod: Double;
begin
  SetLength(LBlocks, Length(ATrack.Windows));
  LCount := 0;
  LTolerance := Ceil(ASampleRate * AGridOptions.ToleranceSeconds);
  for LWindow := 0 to High(ATrack.Windows) do
  begin
    if ATrack.Windows[LWindow].SelectedCandidate < 0 then
    begin
      Continue;
    end;
    LStart := Max(ATrack.Windows[LWindow].OwnerStartFrame,
      ATrack.Windows[LWindow].Analysis.FirstObservationFrame - LTolerance);
    LEnd := Min(ATrack.Windows[LWindow].OwnerEndFrame,
      ATrack.Windows[LWindow].Analysis.LastObservationFrame + LTolerance + 1);
    if LEnd <= LStart then
    begin
      Continue;
    end;
    LBlocks[LWindow] := BeatGridFrames(
      ATrack.Windows[LWindow].Analysis.Candidates[ATrack.Windows[LWindow].SelectedCandidate],
      LStart, LEnd);
    if Length(LBlocks[LWindow]) > MaximumBeatFrames - LCount then
    begin
      raise EAudio.Create('Tracked beat output exceeds position budget');
    end;
    Inc(LCount, Length(LBlocks[LWindow]));
  end;
  SetLength(ATrack.Frames, LCount);
  SetLength(ATrack.FrameWindows, LCount);
  LWrite := 0;
  LPreviousWindow := -1;
  for LWindow := 0 to High(ATrack.Windows) do
  begin
    for LIndex := 0 to High(LBlocks[LWindow]) do
    begin
      ATrack.Frames[LWrite] := LBlocks[LWindow][LIndex];
      ATrack.FrameWindows[LWrite] := LWindow;
      if (LWrite > 0) and (LIndex = 0) then
      begin
        LPeriod := ATrack.Windows[LWindow].Analysis.Candidates[
          ATrack.Windows[LWindow].SelectedCandidate].PeriodFrames;
        LPreviousPeriod := ATrack.Windows[LPreviousWindow].Analysis.Candidates[
          ATrack.Windows[LPreviousWindow].SelectedCandidate].PeriodFrames;
        ATrack.Windows[LWindow].JoinGapRatio :=
          (ATrack.Frames[LWrite] - ATrack.Frames[LWrite - 1]) /
          ((LPeriod + LPreviousPeriod) / 2);
        ATrack.Windows[LWindow].JoinUncertain :=
          (ATrack.Windows[LWindow].JoinGapRatio < 0.5) or
          (ATrack.Windows[LWindow].JoinGapRatio > 1.5);
        if ATrack.Windows[LWindow].JoinUncertain then
        begin
          Inc(ATrack.SeamIssues);
        end;
      end;
      LPreviousWindow := LWindow;
      Inc(LWrite);
    end;
  end;
end;

procedure AlignTrack(var ATrack: TBeatTrack; const AObservations: TBeatObservations;
  const ASampleRate: Integer; const AOptions: TBeatTrackOptions);
var
  LPoint: Integer;
  LFirst: Integer;
  LObservation: Integer;
  LWindow: Integer;
  LTolerance: Integer;
  LStart: Integer;
  LEnd: Integer;
  LBest: Integer;
  LWeight: Double;
  LBestWeight: Double;
  LPeriod: Double;
  LScale: Double;
begin
  ATrack.GridFrames := Copy(ATrack.Frames, 0, Length(ATrack.Frames));
  SetLength(ATrack.ObservationIndices, Length(ATrack.Frames));
  LFirst := 0;
  LScale := 0;
  for LObservation := 0 to High(AObservations) do
  begin
    LScale := Max(LScale, AObservations[LObservation].Weight);
  end;
  for LPoint := 0 to High(ATrack.Frames) do
  begin
    ATrack.ObservationIndices[LPoint] := -1;
    if AOptions.SnapToleranceSeconds = 0 then
    begin
      Continue;
    end;
    LWindow := ATrack.FrameWindows[LPoint];
    LPeriod := ATrack.Windows[LWindow].Analysis.Candidates[
      ATrack.Windows[LWindow].SelectedCandidate].PeriodFrames;
    LTolerance := Floor(Min(ASampleRate * AOptions.SnapToleranceSeconds, LPeriod / 5));
    LStart := ATrack.GridFrames[LPoint] - LTolerance;
    LEnd := ATrack.GridFrames[LPoint] + LTolerance;
    { Disjoint nearest-grid cells preserve order and prevent sharing an onset.
      A midpoint tie belongs to the earlier raw point. }
    if LPoint > 0 then
    begin
      LStart := Max(LStart, (ATrack.GridFrames[LPoint - 1] +
        ATrack.GridFrames[LPoint]) div 2 + 1);
    end;
    if LPoint < High(ATrack.GridFrames) then
    begin
      LEnd := Min(LEnd, (ATrack.GridFrames[LPoint] +
        ATrack.GridFrames[LPoint + 1]) div 2);
    end;
    while (LFirst < Length(AObservations)) and (AObservations[LFirst].Frame < LStart) do
    begin
      Inc(LFirst);
    end;
    LObservation := LFirst;
    LBest := -1;
    LBestWeight := 0;
    while (LObservation < Length(AObservations)) and
      (AObservations[LObservation].Frame <= LEnd) do
    begin
      LWeight := (AObservations[LObservation].Weight / LScale) *
        (1 - Abs(AObservations[LObservation].Frame - ATrack.GridFrames[LPoint]) /
          (LTolerance + 1));
      if LWeight > LBestWeight then
      begin
        LBest := LObservation;
        LBestWeight := LWeight;
      end;
      Inc(LObservation);
    end;
    if LBest >= 0 then
    begin
      ATrack.Frames[LPoint] := AObservations[LBest].Frame;
      ATrack.ObservationIndices[LPoint] := LBest;
    end;
  end;
end;

function TrackBeatGrids(const AObservations: TBeatObservations;
  const ASampleRate, ASourceFrames: Integer; const AGridOptions: TBeatGridOptions;
  const ATrackOptions: TBeatTrackOptions): TBeatTrack;
var
  LTrack: TBeatTrack;
  LEmpty: TBeatGridAnalysis;
  LSubset: TBeatObservations;
  LFirstIndices: array of Integer;
  LCounts: array of Integer;
  LWindowCount: Integer;
  LWindow: Integer;
  LIndex: Integer;
  LFirst: Integer;
  LLast: Integer;
  LPrevious: Integer;
  LCenter: Integer;
  LFitWork: Int64;
  LPeak: Double;
  LTaper: Double;
  LWrite: Integer;
begin
  LTrack := Default(TBeatTrack);
  LEmpty := EstimateBeatGrids(nil, ASampleRate, ASourceFrames, AGridOptions);
  RequireFinite(ATrackOptions.MaximumTempoRatio, 'Maximum tracked tempo ratio');
  RequireFinite(ATrackOptions.TempoPenalty, 'Tempo transition penalty');
  RequireFinite(ATrackOptions.PhasePenalty, 'Phase transition penalty');
  RequireFinite(ATrackOptions.SnapToleranceSeconds, 'Onset alignment tolerance');
  if (ATrackOptions.WindowFrames < 1) or
    (ATrackOptions.WindowFrames > MaximumClipSamples) or
    (ATrackOptions.HopFrames < 1) or
    (ATrackOptions.HopFrames > ATrackOptions.WindowFrames) or
    (ATrackOptions.MaximumTempoRatio < 1) or (ATrackOptions.MaximumTempoRatio > 4) or
    (ATrackOptions.TempoPenalty < 0) or (ATrackOptions.TempoPenalty > 10) or
    (ATrackOptions.PhasePenalty < 0) or (ATrackOptions.PhasePenalty > 10) or
    (ATrackOptions.SnapToleranceSeconds < 0) or
    (ATrackOptions.SnapToleranceSeconds > 0.2) or
    (Length(AObservations) > MaximumBeatObservations) then
  begin
    raise EAudio.Create('Beat tracking options or observations exceed bounds');
  end;
  LWindowCount := (ASourceFrames - 1) div ATrackOptions.HopFrames + 1;
  if LWindowCount > MaximumBeatTrackWindows then
  begin
    raise EAudio.Create('Beat tracking exceeds window budget');
  end;
  LPrevious := -1;
  for LIndex := 0 to High(AObservations) do
  begin
    RequireFinite(AObservations[LIndex].Weight, 'Tracked onset weight');
    if (AObservations[LIndex].Frame <= LPrevious) or
      (AObservations[LIndex].Frame >= ASourceFrames) or
      (AObservations[LIndex].Weight <= 0) or (AObservations[LIndex].Weight > 1) then
    begin
      raise EAudio.Create('Tracked onsets require ordered unique frames and positive weights');
    end;
    LPrevious := AObservations[LIndex].Frame;
  end;
  SetLength(LTrack.Windows, LWindowCount);
  SetLength(LFirstIndices, LWindowCount);
  SetLength(LCounts, LWindowCount);
  LFirst := 0;
  LLast := 0;
  for LWindow := 0 to LWindowCount - 1 do
  begin
    LTrack.Windows[LWindow].SelectedCandidate := -1;
    LTrack.Windows[LWindow].OwnerStartFrame := LWindow * ATrackOptions.HopFrames;
    LTrack.Windows[LWindow].OwnerEndFrame := Min(ASourceFrames,
      LTrack.Windows[LWindow].OwnerStartFrame + ATrackOptions.HopFrames);
    LCenter := LTrack.Windows[LWindow].OwnerStartFrame +
      (LTrack.Windows[LWindow].OwnerEndFrame -
       LTrack.Windows[LWindow].OwnerStartFrame) div 2;
    LTrack.Windows[LWindow].StartFrame := Max(0, LCenter - ATrackOptions.WindowFrames div 2);
    LTrack.Windows[LWindow].EndFrame := Min(ASourceFrames,
      LCenter + ATrackOptions.WindowFrames - ATrackOptions.WindowFrames div 2);
    while (LFirst < Length(AObservations)) and
      (AObservations[LFirst].Frame < LTrack.Windows[LWindow].StartFrame) do
    begin
      Inc(LFirst);
    end;
    while (LLast < Length(AObservations)) and
      (AObservations[LLast].Frame < LTrack.Windows[LWindow].EndFrame) do
    begin
      Inc(LLast);
    end;
    LFirstIndices[LWindow] := LFirst;
    LCounts[LWindow] := LLast - LFirst;
    LFitWork := BeatGridFitWork(LCounts[LWindow], LEmpty.TrialCount);
    if (LFitWork > MaximumBeatWork) or
      (LFitWork > MaximumBeatTrackWork - LTrack.FitWork) then
    begin
      raise EAudio.Create('Beat tracking exceeds aggregate fit budget');
    end;
    Inc(LTrack.FitWork, LFitWork);
  end;
  for LWindow := 0 to LWindowCount - 1 do
  begin
    LSubset := Copy(AObservations, LFirstIndices[LWindow], LCounts[LWindow]);
    if ATrackOptions.TaperWindows then
    begin
      LCenter := LTrack.Windows[LWindow].OwnerStartFrame +
        (LTrack.Windows[LWindow].OwnerEndFrame -
         LTrack.Windows[LWindow].OwnerStartFrame) div 2;
      LPeak := 0;
      for LIndex := 0 to High(LSubset) do
      begin
        LPeak := Max(LPeak, LSubset[LIndex].Weight);
      end;
      LWrite := 0;
      for LIndex := 0 to High(LSubset) do
      begin
        LTaper := (1 + Cos(2 * Pi * (LSubset[LIndex].Frame - LCenter) /
          ATrackOptions.WindowFrames)) / 2;
        if LTaper > 0 then
        begin
          LSubset[LWrite] := LSubset[LIndex];
          LSubset[LWrite].Weight := (LSubset[LWrite].Weight / LPeak) * LTaper;
          if LSubset[LWrite].Weight > 0 then
          begin
            Inc(LWrite);
          end;
        end;
      end;
      SetLength(LSubset, LWrite);
    end;
    LTrack.Windows[LWindow].Analysis :=
      EstimateBeatGrids(LSubset, ASampleRate, ASourceFrames, AGridOptions);
  end;
  SelectPath(LTrack.Windows, ATrackOptions, False);
  RenderTrack(LTrack, ASampleRate, AGridOptions);
  AlignTrack(LTrack, AObservations, ASampleRate, ATrackOptions);
  Result := LTrack;
end;

end.
