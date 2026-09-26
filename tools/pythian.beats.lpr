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
program pythian_beats;

{$mode delphi}
{$H+}

uses
  SysUtils,
  Math,
  fpjson,
  pythian.audio,
  pythian.analysis,
  pythian.activity,
  pythian.onset,
  pythian.onset.events,
  pythian.beat,
  pythian.beat.clock,
  pythian.beat.wave,
  pythian.beat.track,
  pythian.tools.files,
  pythian.tools.cues,
  pythian.tools.beat.report;


procedure Run(const AInput, AOutput, AAudition: String;
  const ARank: Integer; const AOptions: TBeatGridOptions;
  const ATrackEnabled, AClockEnabled: Boolean; const AClockOptions: TBeatClockOptions);
var
  LClip: TAudioClip;
  LWaveEvidence: TWaveBeatEvidence;
  LAnalysisOptions: TAnalysisOptions;
  LActivity: TActivityOptions;
  LLocationOptions: TOnsetLocationOptions;
  LLocations: TOnsetLocations;
  LEventOptions: TOnsetEventOptions;
  LEvents: TOnsetEventPlan;
  LObservations: TBeatObservations;
  LAnalysis: TBeatGridAnalysis;
  LTrack: TBeatTrack;
  LTrackOptions: TBeatTrackOptions;
  LClock: TBeatClock;
  LGrid: TBeatGridCandidate;
  LFrames: TBeatFrames;
  LCues: TCueFrames;
  LDocument: TJSONObject;
  LSettings: TJSONObject;
  LRow: TJSONObject;
  LRows: TJSONArray;
  LArray: TJSONArray;
  LSourceHash: String;
  LIndex: Integer;
  LFrameIndex: Integer;
begin
  if SameFileName(ExpandFileName(AInput), ExpandFileName(AOutput)) or
    ((AAudition <> '') and
      (SameFileName(ExpandFileName(AAudition), ExpandFileName(AInput)) or
       SameFileName(ExpandFileName(AAudition), ExpandFileName(AOutput)))) then
  begin
    raise EAudio.Create('Beat source, report and audition need distinct filenames');
  end;
  LClip := nil;
  LDocument := nil;
  LClock := Default(TBeatClock);
  try
    LClip := LoadWaveSource(AInput, LSourceHash);
    LWaveEvidence := MeasureWaveBeats(LClip, AOptions);
    LAnalysisOptions := LWaveEvidence.AnalysisOptions;
    LActivity := LWaveEvidence.ActivityOptions;
    LLocationOptions := LWaveEvidence.LocationOptions;
    LEventOptions := LWaveEvidence.EventOptions;
    LLocations := LWaveEvidence.Locations;
    LEvents := LWaveEvidence.Events;
    LObservations := LWaveEvidence.Observations;
    LAnalysis := LWaveEvidence.Grid;
    if ATrackEnabled then
    begin
      LTrackOptions := DefaultBeatTrackOptions(LClip.SampleRate);
      LTrack := TrackBeatGrids(LObservations, LClip.SampleRate, LClip.FrameCount,
        AOptions, LTrackOptions);
      if AClockEnabled then
      begin
        LClock := ReconstructBeatClock(SelectedBeatClockWindows(LTrack.Windows),
          LObservations, LClip.SampleRate, LClip.FrameCount, AClockOptions);
      end;
      if (AAudition <> '') and
        (((not AClockEnabled) and (Length(LTrack.Frames) = 0)) or
         (AClockEnabled and (Length(LClock.Frames) = 0))) then
      begin
        raise EAudio.Create('No locally tracked pulse points for audition');
      end;
    end;
    if not ATrackEnabled and (AAudition <> '') and
      ((ARank < 0) or (ARank >= Length(LAnalysis.Candidates))) then
    begin
      raise EAudio.Create('No beat candidate at the requested audition rank');
    end;
    LDocument := TJSONObject.Create;
    LDocument.Add('version', BeatGridVersion);
    LDocument.Add('source', ExtractFileName(AInput));
    LDocument.Add('source_sha256', LSourceHash);
    LDocument.Add('sample_rate', LClip.SampleRate);
    LDocument.Add('source_frames', LClip.FrameCount);
    LDocument.Add('channels', LClip.Channels);
    if ATrackEnabled then
    begin
      LDocument.Add('interpretation',
        'Local periodic hypotheses with tempo/phase continuity and explicit onset alignment; no meter or confidence claim');
    end
    else
    begin
      LDocument.Add('interpretation',
        'Ranked constant-period pulse hypotheses; no meter, downbeat, tempo-change or confidence claim');
    end;
    LDocument.Add('weight_policy', 'Square root of admitted energy rise divided by its maximum');
    LDocument.Add('measurement_policy', BeatGridMeasurementPolicy);
    LDocument.Add('candidate_policy', 'Strongest tempo anchor then distinct phase companion; selection order is not global score rank');
    LDocument.Add('score_policy', 'Positive phase concentration above uniform expectation times square root of distinct-beat coverage; not confidence');
    LDocument.Add('first_observation_frame', LAnalysis.FirstObservationFrame);
    LDocument.Add('last_observation_frame', LAnalysis.LastObservationFrame);
    LDocument.Add('trial_count', LAnalysis.TrialCount);
    LDocument.Add('onset_candidate_count', Length(LLocations));
    LDocument.Add('observation_count', Length(LObservations));
    LSettings := TJSONObject.Create;
    LDocument.Add('analysis_policy', LSettings);
    LSettings.Add('window_frames', LAnalysisOptions.WindowFrames);
    LSettings.Add('hop_frames', LAnalysisOptions.HopFrames);
    LSettings.Add('silence_rms', LAnalysisOptions.SilenceRms);
    LSettings.Add('minimum_flux', LActivity.MinimumFlux);
    LSettings.Add('adaptive_multiplier', LActivity.AdaptiveMultiplier);
    LSettings.Add('history_features', LActivity.HistoryFeatures);
    LSettings.Add('peak_radius', LActivity.PeakRadius);
    LSettings.Add('minimum_separation_features', LActivity.MinimumSeparationFeatures);
    LSettings.Add('maximum_segment_features', LActivity.MaximumSegmentFeatures);
    LSettings.Add('energy_window_frames', LLocationOptions.EnergyWindowFrames);
    LSettings.Add('minimum_energy_rise', LLocationOptions.MinimumEnergyRise);
    LSettings.Add('minimum_contrast', LLocationOptions.MinimumContrast);
    LSettings.Add('minimum_event_frames', LEventOptions.MinimumFrames);
    LSettings.Add('allow_clipped_context', LEventOptions.AllowClippedContext);
    LSettings.Add('allow_search_boundary', LEventOptions.AllowSearchBoundary);
    LSettings := TJSONObject.Create;
    LDocument.Add('grid_policy', LSettings);
    LSettings.Add('minimum_bpm', AOptions.MinimumBpm);
    LSettings.Add('maximum_bpm', AOptions.MaximumBpm);
    LSettings.Add('step_bpm', AOptions.StepBpm);
    LSettings.Add('minimum_separation_bpm', AOptions.MinimumSeparationBpm);
    LSettings.Add('tolerance_seconds', AOptions.ToleranceSeconds);
    LSettings.Add('minimum_matched_weight', AOptions.MinimumMatchedWeight);
    LSettings.Add('minimum_cycles', AOptions.MinimumCycles);
    LSettings.Add('maximum_candidates', AOptions.MaximumCandidates);
    LRows := TJSONArray.Create;
    LDocument.Add('onset_decisions', LRows);
    for LIndex := 0 to High(LLocations) do
    begin
      LRow := TJSONObject.Create;
      LRows.Add(LRow);
      LRow.Add('feature_index', LLocations[LIndex].FeatureIndex);
      LRow.Add('frame', LLocations[LIndex].Frame);
      LRow.Add('decision', OnsetEventDecisionName(LEvents.Decisions[LIndex]));
    end;
    LRows := TJSONArray.Create;
    LDocument.Add('observations', LRows);
    for LIndex := 0 to High(LObservations) do
    begin
      LRow := TJSONObject.Create;
      LRows.Add(LRow);
      LRow.Add('location_index', LEvents.LocationIndices[LIndex + 1]);
      LRow.Add('frame', LObservations[LIndex].Frame);
      LRow.Add('weight', LObservations[LIndex].Weight);
    end;
    LRows := TJSONArray.Create;
    LDocument.Add('candidates', LRows);
    for LIndex := 0 to High(LAnalysis.Candidates) do
    begin
      LGrid := LAnalysis.Candidates[LIndex];
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
      LRow.Add('at_search_edge', (Abs(LGrid.Bpm - AOptions.MinimumBpm) < AOptions.StepBpm) or
        (Abs(LGrid.Bpm - AOptions.MaximumBpm) < AOptions.StepBpm));
      LFrames := BeatGridFrames(LGrid, LAnalysis.FirstObservationFrame,
        LAnalysis.LastObservationFrame + 1);
      LArray := TJSONArray.Create;
      LRow.Add('frames_within_observed_span', LArray);
      for LFrameIndex := 0 to High(LFrames) do
      begin
        LArray.Add(LFrames[LFrameIndex]);
      end;
    end;
    if ATrackEnabled then
    begin
      LDocument.Add('local_track', TrackJson(LTrack, LTrackOptions));
    end;
    if AClockEnabled then
    begin
      LDocument.Add('continuous_clock', BeatClockJson(LClock, AClockOptions));
    end;
    if AAudition <> '' then
    begin
      if AClockEnabled then
      begin
        LFrames := Copy(LClock.Frames);
      end
      else if ATrackEnabled then
      begin
        LFrames := Copy(LTrack.Frames, 0, Length(LTrack.Frames));
      end
      else
      begin
        LFrames := BeatGridFrames(LAnalysis.Candidates[ARank],
          LAnalysis.FirstObservationFrame, LAnalysis.LastObservationFrame + 1);
      end;
      SetLength(LCues, Length(LFrames));
      for LIndex := 0 to High(LFrames) do
      begin
        LCues[LIndex] := LFrames[LIndex];
      end;
      if AClockEnabled then
      begin
        WriteCueAudition(LClip, LCues, AAudition,
          'Continuous phase from selected local pulse hypotheses; source recording retained', LDocument);
        LDocument.Objects['audition'].Add('selection', 'continuous_clock');
      end
      else if ATrackEnabled then
      begin
        WriteCueAudition(LClip, LCues, AAudition,
          'Locally tracked pulse positions with explicit onset adjustments; source recording retained', LDocument);
        LDocument.Objects['audition'].Add('selection', 'local_track');
      end
      else
      begin
        WriteCueAudition(LClip, LCues, AAudition,
          'Selected periodic hypothesis marked within observed span; source recording retained', LDocument);
        LDocument.Objects['audition'].Add('candidate_rank', ARank);
      end;
    end;
    WriteTextFile(AOutput, LDocument.FormatJSON);
    if ATrackEnabled then
    begin
      WriteLn(Length(LTrack.Windows), ' local windows; ', Length(LTrack.Frames),
        ' pulse positions; ', LTrack.SeamIssues, ' uncertain grid joins');
    end;
    if AClockEnabled then
    begin
      WriteLn(Length(LClock.Frames), ' reconstructed pulse positions; ',
        LClock.AmbiguousIntervals, ' numeric phase ties; ', LClock.RejectedIntervals,
        ' unavailable intervals; ', LClock.StepIntervals, ' feasible step intervals');
    end;
    WriteLn(Length(LObservations), ' admitted onsets; ',
      Length(LAnalysis.Candidates), ' constant-period candidates');
    for LIndex := 0 to Min(2, High(LAnalysis.Candidates)) do
    begin
      LGrid := LAnalysis.Candidates[LIndex];
      WriteLn('Rank ', LIndex, ': ', LGrid.Bpm:0:2, ' BPM; score ', LGrid.Score:0:4,
        '; support ', LGrid.SupportedBeats, '/', LGrid.GridBeats,
        '; mean error ', LGrid.MeanErrorFrames:0:2, ' frames');
    end;
  finally
    LDocument.Free;
    LClip.Free;
  end;
end;

procedure Main;
var
  LOptions: TBeatGridOptions;
  LAudition: String;
  LRank: Integer;
  LArgument: Integer;
  LTrackEnabled: Boolean;
  LClockEnabled: Boolean;
  LClockOptions: TBeatClockOptions;
begin
  if ParamCount < 2 then
  begin
    raise EAudio.Create('Usage: pythian.beats INPUT.wav OUTPUT.json ' +
      '[MIN_BPM MAX_BPM] [--track [--clock linear|step [--alignment-context]]] ' +
      '[--audition OUTPUT.wav [RANK]]');
  end;
  LOptions := DefaultBeatGridOptions;
  LAudition := '';
  LRank := 0;
  LArgument := 3;
  LTrackEnabled := False;
  LClockEnabled := False;
  LClockOptions := DefaultBeatClockOptions;
  if (LArgument <= ParamCount) and (ParamStr(LArgument) <> '--audition') and
    (ParamStr(LArgument) <> '--track') and (ParamStr(LArgument) <> '--clock') and
    (ParamStr(LArgument) <> '--alignment-context') then
  begin
    if LArgument + 1 > ParamCount then
    begin
      raise EAudio.Create('Expected minimum and maximum BPM');
    end;
    LOptions.MinimumBpm := StrToInt(ParamStr(LArgument));
    LOptions.MaximumBpm := StrToInt(ParamStr(LArgument + 1));
    Inc(LArgument, 2);
  end;
  if (LArgument <= ParamCount) and (ParamStr(LArgument) = '--track') then
  begin
    LTrackEnabled := True;
    Inc(LArgument);
  end;
  if (LArgument <= ParamCount) and (ParamStr(LArgument) = '--clock') then
  begin
    if not LTrackEnabled or (LArgument + 1 > ParamCount) then
    begin
      raise EAudio.Create('--clock requires --track and linear or step');
    end;
    if ParamStr(LArgument + 1) = 'step' then
    begin
      LClockOptions.Shape := bcsStepWhenFeasible;
    end
    else if ParamStr(LArgument + 1) <> 'linear' then
    begin
      raise EAudio.Create('Clock shape must be linear or step');
    end;
    LClockEnabled := True;
    Inc(LArgument, 2);
  end;
  if (LArgument <= ParamCount) and (ParamStr(LArgument) = '--alignment-context') then
  begin
    if not LClockEnabled then
    begin
      raise EAudio.Create('--alignment-context requires --track --clock linear|step');
    end;
    LClockOptions.AlignmentMode := bcaNeighbourSupported;
    Inc(LArgument);
  end;
  if (LArgument + 1 <= ParamCount) and (ParamStr(LArgument) = '--audition') then
  begin
    LAudition := ParamStr(LArgument + 1);
    Inc(LArgument, 2);
    if LArgument <= ParamCount then
    begin
      if LTrackEnabled then
      begin
        raise EAudio.Create('A global candidate rank does not select a local track');
      end;
      LRank := StrToInt(ParamStr(LArgument));
      Inc(LArgument);
    end;
  end;
  if LArgument <= ParamCount then
  begin
    raise EAudio.Create('Unexpected beat command arguments');
  end;
  Run(ParamStr(1), ParamStr(2), LAudition, LRank, LOptions,
    LTrackEnabled, LClockEnabled, LClockOptions);
end;

begin
  try
    Main;
  except
    on LError: Exception do
    begin
      WriteLn(StdErr, LError.Message);
      Halt(1);
    end;
  end;
end.
