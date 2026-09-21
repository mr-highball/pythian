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
unit pythian.tools.beat.report;

{$mode delphi}
{$H+}

interface

uses
  fpjson,
  pythian.beat,
  pythian.beat.alignment,
  pythian.beat.clock,
  pythian.beat.wave,
  pythian.beat.track;

function TrackJson(const ATrack: TBeatTrack; const AOptions: TBeatTrackOptions): TJSONObject;
function BeatEvidenceJson(const AEvidence: TWaveBeatEvidence;
  const AOptions: TBeatGridOptions): TJSONObject;
function BeatClockJson(const AClock: TBeatClock; const AOptions: TBeatClockOptions): TJSONObject;

implementation

function BeatClockJson(const AClock: TBeatClock; const AOptions: TBeatClockOptions): TJSONObject;
var
  LRows: TJSONArray;
  LRow: TJSONObject;
  LIndex: Integer;
begin
  Result := TJSONObject.Create;
  try
    Result.Add('measurement_policy', BeatClockMeasurementPolicy);
    Result.Add('interpretation',
      'Continuous phase from selected pulse hypotheses; feasible steps and numeric ties are not musical change/confidence admission');
    if AOptions.Shape = bcsLinear then
    begin
      Result.Add('shape', 'linear');
    end
    else
    begin
      Result.Add('shape', 'step');
    end;
    Result.Add('support_tolerance_seconds', AOptions.SupportToleranceSeconds);
    Result.Add('snap_tolerance_seconds', AOptions.SnapToleranceSeconds);
    Result.Add('ambiguous_intervals', AClock.AmbiguousIntervals);
    Result.Add('rejected_intervals', AClock.RejectedIntervals);
    Result.Add('step_intervals', AClock.StepIntervals);
    Result.Add('crossing_work', AClock.CrossingWork);
    if AOptions.AlignmentMode = bcaNeighbourSupported then
    begin
      Result.Add('alignment_policy', BeatAlignmentContextPolicy);
      Result.Add('alignment_interpretation',
        'Optional neighbour support; unknown retains raw clock, unavailable retains original alignment; neither is musical admission');
    end;
    LRows := TJSONArray.Create;
    Result.Add('segments', LRows);
    for LIndex := 0 to High(AClock.Segments) do
    begin
      LRow := TJSONObject.Create;
      LRows.Add(LRow);
      LRow.Add('start_frame', AClock.Segments[LIndex].StartFrame);
      LRow.Add('end_frame', AClock.Segments[LIndex].EndFrame);
      LRow.Add('start_cycle', AClock.Segments[LIndex].StartCycle);
      LRow.Add('end_cycle', AClock.Segments[LIndex].EndCycle);
      LRow.Add('period_frames', AClock.Segments[LIndex].PeriodFrames);
      LRow.Add('integral_residual', AClock.Segments[LIndex].IntegralResidual);
      LRow.Add('available', AClock.Segments[LIndex].Available);
      LRow.Add('ambiguous', AClock.Segments[LIndex].Ambiguous);
      LRow.Add('step_part', AClock.Segments[LIndex].StepPart);
      LRow.Add('left_window', AClock.Segments[LIndex].LeftWindow);
      LRow.Add('right_window', AClock.Segments[LIndex].RightWindow);
    end;
    LRows := TJSONArray.Create;
    Result.Add('points', LRows);
    for LIndex := 0 to High(AClock.Frames) do
    begin
      LRow := TJSONObject.Create;
      LRows.Add(LRow);
      LRow.Add('frame', AClock.Frames[LIndex]);
      LRow.Add('grid_frame', AClock.RawFrames[LIndex]);
      LRow.Add('adjustment_frames', AClock.Frames[LIndex] - AClock.RawFrames[LIndex]);
      LRow.Add('period_frames', AClock.Periods[LIndex]);
      LRow.Add('window_index', AClock.FrameWindows[LIndex]);
      LRow.Add('observation_index', AClock.ObservationIndices[LIndex]);
      if AOptions.AlignmentMode = bcaNeighbourSupported then
      begin
        LRow.Add('original_observation_index', AClock.AlignmentChoices[LIndex].OriginalObservation);
        LRow.Add('alignment_unknown', AClock.AlignmentChoices[LIndex].Unknown);
        LRow.Add('context_unavailable', AClock.AlignmentChoices[LIndex].ContextUnavailable);
        LRow.Add('witness_count', AClock.AlignmentChoices[LIndex].WitnessCount);
        LRow.Add('minimum_offset_frames', AClock.AlignmentChoices[LIndex].MinimumOffset);
        LRow.Add('maximum_offset_frames', AClock.AlignmentChoices[LIndex].MaximumOffset);
      end;
    end;
  except
    Result.Free;
    raise;
  end;
end;

function BeatEvidenceJson(const AEvidence: TWaveBeatEvidence;
  const AOptions: TBeatGridOptions): TJSONObject;
var
  LRows: TJSONArray;
  LRow: TJSONObject;
  LGrid: TBeatGridCandidate;
  LIndex: Integer;
begin
  Result := TJSONObject.Create;
  try
    Result.Add('beat_grid_version', BeatGridVersion);
    Result.Add('measurement_policy', BeatGridMeasurementPolicy);
    Result.Add('score_is_probability', False);
    Result.Add('interpretation', 'Localized onset pulse hypotheses; no downbeat or meter inference');
    Result.Add('weight_policy', 'Square root of admitted energy rise divided by its maximum');
    Result.Add('analysis_window', AEvidence.AnalysisOptions.WindowFrames);
    Result.Add('analysis_hop', AEvidence.AnalysisOptions.HopFrames);
    Result.Add('silence_rms', AEvidence.AnalysisOptions.SilenceRms);
    Result.Add('minimum_flux', AEvidence.ActivityOptions.MinimumFlux);
    Result.Add('adaptive_multiplier', AEvidence.ActivityOptions.AdaptiveMultiplier);
    Result.Add('history_features', AEvidence.ActivityOptions.HistoryFeatures);
    Result.Add('peak_radius', AEvidence.ActivityOptions.PeakRadius);
    Result.Add('minimum_separation_features', AEvidence.ActivityOptions.MinimumSeparationFeatures);
    Result.Add('maximum_segment_features', AEvidence.ActivityOptions.MaximumSegmentFeatures);
    Result.Add('energy_window_frames', AEvidence.LocationOptions.EnergyWindowFrames);
    Result.Add('minimum_energy_rise', AEvidence.LocationOptions.MinimumEnergyRise);
    Result.Add('minimum_contrast', AEvidence.LocationOptions.MinimumContrast);
    Result.Add('minimum_event_frames', AEvidence.EventOptions.MinimumFrames);
    Result.Add('allow_clipped_context', AEvidence.EventOptions.AllowClippedContext);
    Result.Add('allow_search_boundary', AEvidence.EventOptions.AllowSearchBoundary);
    Result.Add('minimum_bpm', AOptions.MinimumBpm);
    Result.Add('maximum_bpm', AOptions.MaximumBpm);
    Result.Add('step_bpm', AOptions.StepBpm);
    Result.Add('minimum_separation_bpm', AOptions.MinimumSeparationBpm);
    Result.Add('tolerance_seconds', AOptions.ToleranceSeconds);
    Result.Add('minimum_matched_weight', AOptions.MinimumMatchedWeight);
    Result.Add('minimum_cycles', AOptions.MinimumCycles);
    Result.Add('maximum_candidates', AOptions.MaximumCandidates);
    LRows := TJSONArray.Create;
    Result.Add('observations', LRows);
    for LIndex := 0 to High(AEvidence.Observations) do
    begin
      LRow := TJSONObject.Create;
      LRows.Add(LRow);
      LRow.Add('frame', AEvidence.Observations[LIndex].Frame);
      LRow.Add('weight', AEvidence.Observations[LIndex].Weight);
    end;
    LRows := TJSONArray.Create;
    Result.Add('candidates', LRows);
    for LIndex := 0 to High(AEvidence.Grid.Candidates) do
    begin
      LGrid := AEvidence.Grid.Candidates[LIndex];
      LRow := TJSONObject.Create;
      LRows.Add(LRow);
      LRow.Add('rank', LIndex);
      LRow.Add('bpm', LGrid.Bpm);
      LRow.Add('period_frames', LGrid.PeriodFrames);
      LRow.Add('phase_frame', LGrid.PhaseFrame);
      LRow.Add('phase_concentration', LGrid.PhaseConcentration);
      LRow.Add('matched_weight_fraction', LGrid.MatchedWeightFraction);
      LRow.Add('coverage', LGrid.Coverage);
      LRow.Add('score', LGrid.Score);
      LRow.Add('mean_error_frames', LGrid.MeanErrorFrames);
      LRow.Add('supported_onsets', LGrid.SupportedOnsets);
      LRow.Add('supported_beats', LGrid.SupportedBeats);
      LRow.Add('grid_beats', LGrid.GridBeats);
    end;
  except
    Result.Free;
    raise;
  end;
end;

function TrackJson(const ATrack: TBeatTrack; const AOptions: TBeatTrackOptions): TJSONObject;
var
  LWindows: TJSONArray;
  LCandidates: TJSONArray;
  LPoints: TJSONArray;
  LWindow: TJSONObject;
  LRow: TJSONObject;
  LIndex: Integer;
  LChoice: Integer;
  LGrid: TBeatGridCandidate;
begin
  Result := TJSONObject.Create;
  Result.Add('version', BeatTrackVersion);
  Result.Add('measurement_policy', BeatGridMeasurementPolicy);
  Result.Add('window_frames', AOptions.WindowFrames);
  Result.Add('hop_frames', AOptions.HopFrames);
  Result.Add('maximum_tempo_ratio', AOptions.MaximumTempoRatio);
  Result.Add('tempo_penalty', AOptions.TempoPenalty);
  Result.Add('phase_penalty', AOptions.PhasePenalty);
  Result.Add('taper_windows', AOptions.TaperWindows);
  Result.Add('snap_tolerance_seconds', AOptions.SnapToleranceSeconds);
  Result.Add('alignment_policy',
    'Strong nearby onset weighted by linear distance; capped at one fifth period and disjoint nearest-grid cells');
  Result.Add('path_policy',
    'Maximum summed candidate score minus tempo/phase transition penalties; gaps and impossible transitions restart');
  Result.Add('fit_work', ATrack.FitWork);
  Result.Add('grid_seam_issues', ATrack.SeamIssues);
  LWindows := TJSONArray.Create;
  Result.Add('windows', LWindows);
  for LIndex := 0 to High(ATrack.Windows) do
  begin
    LWindow := TJSONObject.Create;
    LWindows.Add(LWindow);
    LWindow.Add('start_frame', ATrack.Windows[LIndex].StartFrame);
    LWindow.Add('end_frame', ATrack.Windows[LIndex].EndFrame);
    LWindow.Add('owner_start_frame', ATrack.Windows[LIndex].OwnerStartFrame);
    LWindow.Add('owner_end_frame', ATrack.Windows[LIndex].OwnerEndFrame);
    LWindow.Add('first_observation_frame', ATrack.Windows[LIndex].Analysis.FirstObservationFrame);
    LWindow.Add('last_observation_frame', ATrack.Windows[LIndex].Analysis.LastObservationFrame);
    LWindow.Add('observation_count', ATrack.Windows[LIndex].Analysis.ObservationCount);
    LWindow.Add('selected_candidate', ATrack.Windows[LIndex].SelectedCandidate);
    LWindow.Add('starts_new_path', ATrack.Windows[LIndex].StartsNewPath);
    LWindow.Add('join_gap_ratio', ATrack.Windows[LIndex].JoinGapRatio);
    LWindow.Add('join_uncertain', ATrack.Windows[LIndex].JoinUncertain);
    LCandidates := TJSONArray.Create;
    LWindow.Add('candidates', LCandidates);
    for LChoice := 0 to High(ATrack.Windows[LIndex].Analysis.Candidates) do
    begin
      LGrid := ATrack.Windows[LIndex].Analysis.Candidates[LChoice];
      LRow := TJSONObject.Create;
      LCandidates.Add(LRow);
      LRow.Add('bpm', LGrid.Bpm);
      LRow.Add('period_frames', LGrid.PeriodFrames);
      LRow.Add('phase_frame', LGrid.PhaseFrame);
      LRow.Add('phase_concentration', LGrid.PhaseConcentration);
      LRow.Add('matched_weight_fraction', LGrid.MatchedWeightFraction);
      LRow.Add('coverage', LGrid.Coverage);
      LRow.Add('score', LGrid.Score);
      LRow.Add('mean_error_frames', LGrid.MeanErrorFrames);
      LRow.Add('supported_onsets', LGrid.SupportedOnsets);
      LRow.Add('supported_beats', LGrid.SupportedBeats);
      LRow.Add('grid_beats', LGrid.GridBeats);
    end;
  end;
  LPoints := TJSONArray.Create;
  Result.Add('points', LPoints);
  for LIndex := 0 to High(ATrack.Frames) do
  begin
    LRow := TJSONObject.Create;
    LPoints.Add(LRow);
    LRow.Add('frame', ATrack.Frames[LIndex]);
    LRow.Add('grid_frame', ATrack.GridFrames[LIndex]);
    LRow.Add('adjustment_frames', ATrack.Frames[LIndex] - ATrack.GridFrames[LIndex]);
    LRow.Add('window_index', ATrack.FrameWindows[LIndex]);
    LRow.Add('observation_index', ATrack.ObservationIndices[LIndex]);
  end;
end;

end.
