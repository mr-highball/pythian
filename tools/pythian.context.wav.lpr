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

program pythian_context_wav;

{$mode delphi}
{$H+}

uses
  Classes,
  SysUtils,
  Math,
  fpjson,
  pythian.audio,
  pythian.analysis,
  pythian.onset,
  pythian.tempo,
  pythian.beat,
  pythian.beat.wave,
  pythian.tonal,
  pythian.music.context,
  pythian.music.context.admission,
  pythian.music.grid.frames,
  pythian.time,
  pythian.wfc.context.archive,
  pythian.wfc.context.profile,
  pythian.tools.files,
  pythian.tools.beat.report;

function DescribeTonal(const AWeights: TPitchClassWeights;
  const AReport: TTonalReport): TJSONObject;
var
  LWeights: TJSONArray;
  LFits: TJSONArray;
  LFit: TJSONObject;
  LIndex: Integer;
begin
  Result := TJSONObject.Create;
  try
    Result.Add('total_weight', AReport.TotalWeight);
    Result.Add('score_gap', AReport.ScoreGap);
    Result.Add('score_is_probability', False);
    LWeights := TJSONArray.Create;
    Result.Add('pitch_class_weights', LWeights);
    for LIndex := 0 to 11 do
    begin
      LWeights.Add(AWeights[LIndex]);
    end;
    LFits := TJSONArray.Create;
    Result.Add('ranked_fits', LFits);
    for LIndex := 0 to AReport.CandidateCount - 1 do
    begin
      LFit := TJSONObject.Create;
      LFits.Add(LFit);
      LFit.Add('rank', LIndex);
      LFit.Add('root', AReport.Fits[LIndex].Root);
      LFit.Add('mode_ordinal', Ord(AReport.Fits[LIndex].Mode));
      LFit.Add('raw_score', AReport.Fits[LIndex].RawScore);
      LFit.Add('score', AReport.Fits[LIndex].Score);
      LFit.Add('coverage', AReport.Fits[LIndex].Coverage);
    end;
  except
    Result.Free;
    raise;
  end;
end;

function DescribeTempo(const AReport: TTempoReport; const AOptions: TTempoOptions;
  const AAnalysis: TAnalysisOptions): TJSONObject;
var
  LRows: TJSONArray;
  LRow: TJSONObject;
  LIndex: Integer;
begin
  Result := TJSONObject.Create;
  try
    Result.Add('measurement_version', TempoMeasurementVersion);
    Result.Add('analysis_window', AAnalysis.WindowFrames);
    Result.Add('analysis_hop', AAnalysis.HopFrames);
    Result.Add('silence_rms', AAnalysis.SilenceRms);
    Result.Add('minimum_bpm', AOptions.MinimumBpm);
    Result.Add('maximum_bpm', AOptions.MaximumBpm);
    Result.Add('minimum_flux', AOptions.MinimumFlux);
    Result.Add('minimum_correlation', AOptions.MinimumCorrelation);
    Result.Add('minimum_cycles', AOptions.MinimumCycles);
    Result.Add('maximum_candidates', AOptions.MaximumCandidates);
    Result.Add('status_ordinal', Ord(AReport.Status));
    Result.Add('complete_features', AReport.CompleteFeatures);
    Result.Add('active_features', AReport.ActiveFeatures);
    Result.Add('envelope_energy', AReport.EnvelopeEnergy);
    Result.Add('score_is_probability', False);
    Result.Add('interpretation', 'Ranked global pulse periodicity; half/double-time alternatives retained; no beat phase, meter or downbeat inference');
    LRows := TJSONArray.Create;
    Result.Add('candidates', LRows);
    for LIndex := 0 to High(AReport.Candidates) do
    begin
      LRow := TJSONObject.Create;
      LRows.Add(LRow);
      LRow.Add('rank', LIndex);
      LRow.Add('lag_features', AReport.Candidates[LIndex].LagFeatures);
      LRow.Add('period_frames', AReport.Candidates[LIndex].PeriodFrames);
      LRow.Add('microseconds_per_quarter', AReport.Candidates[LIndex].MicrosecondsPerQuarter);
      LRow.Add('bpm', AReport.Candidates[LIndex].Bpm);
      LRow.Add('correlation', AReport.Candidates[LIndex].Correlation);
      LRow.Add('supporting_pairs', AReport.Candidates[LIndex].SupportingPairs);
    end;
  except
    Result.Free;
    raise;
  end;
end;

procedure AdmitKeyRegions;
var
  LClip: TAudioClip;
  LHash: String;
  LScope: TWaveContextScope;
  LClock: TTempoMap;
  LGrid: TMusicGridFrames;
  LRegions: TTonalKeyRegions;
  LMeasured: TTonalRegionAdmissions;
  LOptions: TAnalysisOptions;
  LEntries: TStringList;
  LFields: TStringList;
  LIndex: Integer;
  LCell: Integer;
  LDocument: TJSONObject;
  LRows: TJSONArray;
  LRow: TJSONObject;
  LText: String;
  LPrefix: String;
  LEvidence: TContextEvidenceArray;
  LBundle: TContextLearningBundle;
  LProfile: TContextProfile;
  LBytes: TAudioBytes;
begin
  if (ParamCount <> 6) or (Length(ParamStr(3)) <> 64) or
    (Length(ParamStr(5)) > 65536) then
  begin
    raise EAudio.Create('Usage: pythian.context.wav admit-key-regions INPUT.wav ' +
      'EXPECTED_SHA256 TEMPO_US FIRST_CELL:ROOT:MODE,... OUTPUT_PREFIX');
  end;
  LPrefix := ParamStr(6);
  if SameFileName(ExpandFileName(ParamStr(2)), ExpandFileName(LPrefix + '.json')) or
    SameFileName(ExpandFileName(ParamStr(2)), ExpandFileName(LPrefix + '.pcp')) then
  begin
    raise EAudio.Create('Local key outputs must not replace the source WAV');
  end;
  LClip := nil;
  LClock := nil;
  LGrid := nil;
  LEntries := nil;
  LFields := nil;
  LDocument := nil;
  LBundle := nil;
  LProfile := nil;
  try
    LClip := LoadWaveSource(ParamStr(2), LHash);
    if LHash <> LowerCase(ParamStr(3)) then
    begin
      raise EAudio.Create('WAV source differs from the reviewed SHA256');
    end;
    LScope := WaveContextScope(LClip.SampleRate, LClip.FrameCount, StrToInt(ParamStr(4)),
      480, 240, MakeKeyContext(-1, dmMajor));
    LClock := TTempoMap.Create(480, Length(LScope.Grid.Keys) * 240,
      [MakeTempoChange(0, StrToInt(ParamStr(4)))]);
    LGrid := TMusicGridFrames.Create(LClock, LClip.SampleRate, LClip.FrameCount,
      0, 0, 240, Length(LScope.Grid.Keys));
    LEntries := TStringList.Create;
    LEntries.StrictDelimiter := True;
    LEntries.Delimiter := ',';
    LEntries.DelimitedText := ParamStr(5);
    if (LEntries.Count < 1) or (LEntries.Count > LGrid.CellCount) then
    begin
      raise EAudio.Create('Local key selection requires bounded nonempty regions');
    end;
    LFields := TStringList.Create;
    LFields.StrictDelimiter := True;
    LFields.Delimiter := ':';
    SetLength(LRegions, LEntries.Count);
    for LIndex := 0 to High(LRegions) do
    begin
      LFields.DelimitedText := LEntries[LIndex];
      if LFields.Count <> 3 then
      begin
        raise EAudio.Create('Local key region must be FIRST_CELL:ROOT:major|minor');
      end;
      LRegions[LIndex].FirstCell := StrToInt(LFields[0]);
      if LFields[2] = 'major' then
      begin
        LRegions[LIndex].Key := MakeKeyContext(StrToInt(LFields[1]), dmMajor);
      end
      else if LFields[2] = 'minor' then
      begin
        LRegions[LIndex].Key := MakeKeyContext(StrToInt(LFields[1]), dmNaturalMinor);
      end
      else
      begin
        raise EAudio.Create('Local key mode must be major or minor; unknown is -1:major');
      end;
      if (LRegions[LIndex].FirstCell < 0) or
        (LRegions[LIndex].FirstCell >= LGrid.CellCount) or
        ((LIndex = 0) and (LRegions[LIndex].FirstCell <> 0)) then
      begin
        raise EAudio.Create('Local key regions must begin at zero and stay in the grid');
      end;
      if LIndex > 0 then
      begin
        if LRegions[LIndex].FirstCell <= LRegions[LIndex - 1].FirstCell then
        begin
          raise EAudio.Create('Local key region starts must be strictly increasing');
        end;
        LRegions[LIndex - 1].CellCount :=
          LRegions[LIndex].FirstCell - LRegions[LIndex - 1].FirstCell;
      end;
    end;
    LRegions[High(LRegions)].CellCount := LGrid.CellCount - LRegions[High(LRegions)].FirstCell;
    LOptions := DefaultAnalysisOptions;
    LMeasured := AdmitWaveKeyRegions(LClip, LGrid, LRegions, LOptions);
    LDocument := TJSONObject.Create;
    LDocument.Add('contract', 'pythian.wave-context-admission.v1');
    LDocument.Add('source', ExtractFileName(ParamStr(2)));
    LDocument.Add('source_sha256', LHash);
    LDocument.Add('sample_rate', LClip.SampleRate);
    LDocument.Add('channels', LClip.Channels);
    LDocument.Add('source_frames', LClip.FrameCount);
    LDocument.Add('analysis_version', AnalysisVersion);
    LDocument.Add('tonal_profile_version', TonalProfileVersion);
    LDocument.Add('fit_version', DiatonicFitVersion);
    LDocument.Add('window_frames', LOptions.WindowFrames);
    LDocument.Add('hop_frames', LOptions.HopFrames);
    LDocument.Add('silence_rms', LOptions.SilenceRms);
    LDocument.Add('weighting', 'sample_frames');
    LDocument.Add('key_decision', 'explicit_local_region_selection');
    LDocument.Add('region_boundary_decision', 'caller_selected_cells; floor frame boundaries');
    LDocument.Add('region_analysis', 'independent windows; final zero padding; no cross-region samples');
    LDocument.Add('tempo_decision', 'caller_declared_constant_clock');
    LDocument.Add('tempo_microseconds_per_quarter', StrToInt(ParamStr(4)));
    LDocument.Add('frame_zero_is_verified_downbeat', False);
    LDocument.Add('admitted', True);
    LDocument.Add('ticks_per_quarter', 480);
    LDocument.Add('start_tick', 0);
    LDocument.Add('step_ticks', 240);
    LDocument.Add('cells', LGrid.CellCount);
    LDocument.Add('end_frame_floor', LScope.EndFrameFloor);
    LDocument.Add('end_frame_ceiling', LScope.EndFrameCeiling);
    LDocument.Add('unassigned_whole_frames', LScope.UnassignedWholeFrames);
    LRows := TJSONArray.Create;
    LDocument.Add('key_regions', LRows);
    for LIndex := 0 to High(LMeasured) do
    begin
      LRow := TJSONObject.Create;
      LRows.Add(LRow);
      LRow.Add('first_cell', LRegions[LIndex].FirstCell);
      LRow.Add('cell_count', LRegions[LIndex].CellCount);
      LRow.Add('start_frame', LMeasured[LIndex].StartFrame);
      LRow.Add('end_frame', LMeasured[LIndex].EndFrame);
      LRow.Add('key_root', LRegions[LIndex].Key.Root);
      LRow.Add('key_mode_ordinal', Ord(LRegions[LIndex].Key.Mode));
      LRow.Add('selected_rank', LMeasured[LIndex].Tonal.SelectedRank);
      LRow.Add('tonal', DescribeTonal(LMeasured[LIndex].Weights, LMeasured[LIndex].Tonal.Report));
      for LCell := LRegions[LIndex].FirstCell to
        LRegions[LIndex].FirstCell + LRegions[LIndex].CellCount - 1 do
      begin
        LScope.Grid.Keys[LCell] := LRegions[LIndex].Key;
      end;
    end;
    LText := LDocument.FormatJSON;
    SetLength(LEvidence, 1);
    LEvidence[0].Name := ExtractFileName(ParamStr(2));
    LEvidence[0].SourceSha256 := LHash;
    LEvidence[0].AdmissionPolicy := 'pythian.wave-context-admission.v1; explicit local key regions; ' +
      'declared constant tempo; no downbeat inference; report_sha256=' + HashText(LText);
    LEvidence[0].Grid := LScope.Grid;
    LBundle := TContextLearningBundle.Create(LEvidence);
    LProfile := TContextProfile.Create(LBundle);
    LBytes := EncodeContextProfile(LProfile);
    WriteFileBytes(LPrefix + '.pcp', LBytes);
    WriteTextFile(LPrefix + '.json', LText);
    WriteLn('Admitted ', Length(LMeasured), ' local key regions; profile ', LProfile.Identity);
  finally
    LProfile.Free;
    LBundle.Free;
    LDocument.Free;
    LFields.Free;
    LEntries.Free;
    LGrid.Free;
    LClock.Free;
    LClip.Free;
  end;
end;

procedure Run;
var
  LAdmit: Boolean;
  LMeasureTempo: Boolean;
  LMeasureBeats: Boolean;
  LBeatEvidence: TWaveBeatEvidence;
  LBeatOptions: TBeatGridOptions;
  LBeatAdmission: TBeatContextAdmission;
  LBeatClip: TAudioClip;
  LBeatHash: String;
  LOriginPolicy: String;
  LReportName: String;
  LProfileName: String;
  LInfo: TWaveAnalysisInfo;
  LOptions: TAnalysisOptions;
  LFeatures: TAudioFeatures;
  LTempoFeatures: TAudioFeatures;
  LTempoAnalysis: TAnalysisOptions;
  LTempoOptions: TTempoOptions;
  LTempoReport: TTempoReport;
  LTempoInfo: TWaveAnalysisInfo;
  LTempoRank: Integer;
  LTempoPolicy: String;
  LWeights: TPitchClassWeights;
  LKey: TKeyContext;
  LAdmission: TTonalContextAdmission;
  LScope: TWaveContextScope;
  LTempo: Integer;
  LDocument: TJSONObject;
  LText: String;
  LEvidence: TContextEvidenceArray;
  LBundle: TContextLearningBundle;
  LProfile: TContextProfile;
  LBytes: TAudioBytes;
begin
  LMeasureTempo := (ParamStr(1) = 'inspect-tempo') or (ParamStr(1) = 'admit-tempo');
  LMeasureBeats := (ParamStr(1) = 'inspect-beats') or (ParamStr(1) = 'admit-beats');
  LAdmit := (ParamCount = 7) and ((ParamStr(1) = 'admit') or
    (ParamStr(1) = 'admit-tempo') or (ParamStr(1) = 'admit-beats'));
  if not LAdmit and not ((ParamCount = 3) and
    ((ParamStr(1) = 'inspect') or (ParamStr(1) = 'inspect-tempo') or
    (ParamStr(1) = 'inspect-beats'))) then
  begin
    raise EAudio.Create('Usage: pythian.context.wav inspect INPUT.wav REPORT.json; or ' +
      'admit INPUT.wav EXPECTED_SHA256 TEMPO_US ROOT MODE OUTPUT_PREFIX; or ' +
      'inspect-tempo INPUT.wav REPORT.json; or ' +
      'admit-tempo INPUT.wav EXPECTED_SHA256 CANDIDATE_RANK ROOT MODE OUTPUT_PREFIX; or ' +
      'inspect-beats INPUT.wav REPORT.json; or ' +
      'admit-beats INPUT.wav EXPECTED_SHA256 CANDIDATE_RANK ROOT MODE OUTPUT_PREFIX');
  end;
  LKey := MakeKeyContext(-1, dmMajor);
  LTempo := 0;
  LTempoRank := -1;
  LTempoPolicy := 'declared constant tempo';
  LOriginPolicy := 'frame-zero origin';
  LProfileName := '';
  if LAdmit then
  begin
    if Length(ParamStr(3)) <> 64 then
    begin
      raise EAudio.Create('Admission requires the reviewed source SHA256');
    end;
    if not ((ParamStr(6) = 'major') or (ParamStr(6) = 'minor')) then
    begin
      raise EAudio.Create('Mode must be major or minor; unknown is root -1 with major');
    end;
    if ParamStr(6) = 'minor' then
    begin
      LKey := MakeKeyContext(StrToInt(ParamStr(5)), dmNaturalMinor);
    end
    else
    begin
      LKey := MakeKeyContext(StrToInt(ParamStr(5)), dmMajor);
    end;
    if LMeasureTempo or LMeasureBeats then
    begin
      LTempoRank := StrToInt(ParamStr(4));
    end
    else
    begin
      LTempo := StrToInt(ParamStr(4));
    end;
    LReportName := ParamStr(7) + '.json';
    LProfileName := ParamStr(7) + '.pcp';
  end
  else
  begin
    LReportName := ParamStr(3);
  end;
  if SameFileName(ExpandFileName(ParamStr(2)), ExpandFileName(LReportName)) or
    (LAdmit and SameFileName(ExpandFileName(ParamStr(2)), ExpandFileName(LProfileName))) then
  begin
    raise EAudio.Create('Context outputs must not replace the source WAV');
  end;
  LOptions := DefaultAnalysisOptions;
  LFeatures := AnalyzeWaveSource(ParamStr(2), LOptions, LInfo);
  if LAdmit and (LowerCase(ParamStr(3)) <> LInfo.Sha256) then
  begin
    raise EAudio.Create('WAV source differs from the reviewed SHA256');
  end;
  LWeights := FeaturePitchClassWeights(LFeatures, LOptions, LInfo.FrameCount);
  LAdmission := AdmitTonalContext(LWeights, LKey);
  if LMeasureTempo then
  begin
    LTempoAnalysis := DefaultOnsetAnalysisOptions(LInfo.SampleRate);
    LTempoOptions := DefaultTempoOptions;
    LTempoFeatures := AnalyzeWaveSource(ParamStr(2), LTempoAnalysis, LTempoInfo);
    if LTempoInfo.Sha256 <> LInfo.Sha256 then
    begin
      raise EAudio.Create('Source changed between tonal and tempo measurement');
    end;
    LTempoReport := RankTempoCandidates(LTempoFeatures, LTempoAnalysis,
      LInfo.SampleRate, LInfo.FrameCount, LTempoOptions);
    if LAdmit then
    begin
      if (LTempoRank < 0) or (LTempoRank >= Length(LTempoReport.Candidates)) then
      begin
        raise EAudio.Create('Selected tempo rank is unavailable; inspect the measured candidates');
      end;
      LTempo := LTempoReport.Candidates[LTempoRank].MicrosecondsPerQuarter;
      LTempoPolicy := 'explicitly selected measured global pulse candidate';
    end;
  end;
  if LMeasureBeats then
  begin
    LBeatClip := LoadWaveSource(ParamStr(2), LBeatHash);
    try
      if LBeatHash <> LInfo.Sha256 then
      begin
        raise EAudio.Create('Source changed between tonal and beat measurement');
      end;
      LBeatOptions := DefaultBeatGridOptions;
      LBeatEvidence := MeasureWaveBeats(LBeatClip, LBeatOptions);
      if LAdmit then
      begin
        if (LTempoRank < 0) or (LTempoRank >= Length(LBeatEvidence.Grid.Candidates)) then
        begin
          raise EAudio.Create('Selected beat rank is unavailable; inspect the measured candidates');
        end;
        LBeatAdmission := AdmitBeatContext(LBeatEvidence.Grid.Candidates[LTempoRank],
          LInfo.SampleRate, LInfo.FrameCount, 480, 240, LKey);
        LScope := LBeatAdmission.Scope;
        LTempo := LBeatAdmission.TempoMicroseconds;
        LTempoPolicy := 'explicitly selected localized-onset pulse candidate';
        LOriginPolicy := 'selected pulse phase rounded to source PPQ tick';
      end;
    finally
      LBeatClip.Free;
    end;
  end;
  if LAdmit and not LMeasureBeats then
  begin
    LScope := WaveContextScope(LInfo.SampleRate, LInfo.FrameCount, LTempo, 480, 240, LKey);
  end;
  LDocument := TJSONObject.Create;
  LBundle := nil;
  LProfile := nil;
  try
    LDocument.Add('contract', 'pythian.wave-context-admission.v1');
    LDocument.Add('admission_version', WaveContextAdmissionVersion);
    LDocument.Add('source', ExtractFileName(ParamStr(2)));
    LDocument.Add('source_sha256', LInfo.Sha256);
    LDocument.Add('sample_rate', LInfo.SampleRate);
    LDocument.Add('channels', LInfo.Channels);
    LDocument.Add('source_frames', LInfo.FrameCount);
    LDocument.Add('analysis_version', AnalysisVersion);
    LDocument.Add('tonal_profile_version', TonalProfileVersion);
    LDocument.Add('fit_version', DiatonicFitVersion);
    LDocument.Add('window_frames', LOptions.WindowFrames);
    LDocument.Add('hop_frames', LOptions.HopFrames);
    LDocument.Add('silence_rms', LOptions.SilenceRms);
    LDocument.Add('weighting', 'sample_frames');
    LDocument.Add('tonal', DescribeTonal(LWeights, LAdmission.Report));
    LDocument.Add('admitted', LAdmit);
    if LMeasureTempo then
    begin
      LDocument.Add('tempo_measurement', DescribeTempo(LTempoReport, LTempoOptions, LTempoAnalysis));
    end;
    if LMeasureBeats then
    begin
      LDocument.Add('beat_measurement', BeatEvidenceJson(LBeatEvidence, LBeatOptions));
    end;
    if LAdmit then
    begin
      LDocument.Add('key_root', LKey.Root);
      LDocument.Add('key_mode_ordinal', Ord(LKey.Mode));
      LDocument.Add('selected_rank', LAdmission.SelectedRank);
      LDocument.Add('key_decision', 'explicit_caller_selection');
      LDocument.Add('tempo_microseconds_per_quarter', LTempo);
      if LMeasureBeats then
      begin
        LDocument.Add('tempo_decision', 'explicit_measured_beat_selection');
        LDocument.Add('beat_selected_rank', LTempoRank);
        LDocument.Add('origin_decision', LOriginPolicy);
        LDocument.Add('start_frame_floor', LScope.StartFrameFloor);
        LDocument.Add('start_frame_ceiling', LScope.StartFrameCeiling);
        LDocument.Add('phase_error_frames', LBeatAdmission.PhaseErrorFrames);
        LDocument.Add('period_error_frames', LBeatAdmission.PeriodErrorFrames);
      end
      else if LMeasureTempo then
      begin
        LDocument.Add('tempo_decision', 'explicit_measured_candidate_selection');
        LDocument.Add('tempo_selected_rank', LTempoRank);
      end
      else
      begin
        LDocument.Add('tempo_decision', 'caller_declared_constant_clock');
      end;
      LDocument.Add('frame_zero_is_verified_downbeat', False);
      LDocument.Add('ticks_per_quarter', LScope.Grid.TicksPerQuarter);
      LDocument.Add('start_tick', LScope.Grid.StartTick);
      LDocument.Add('step_ticks', LScope.Grid.StepTicks);
      LDocument.Add('cells', Length(LScope.Grid.Keys));
      LDocument.Add('end_frame_floor', LScope.EndFrameFloor);
      LDocument.Add('end_frame_ceiling', LScope.EndFrameCeiling);
      LDocument.Add('unassigned_whole_frames', LScope.UnassignedWholeFrames);
    end;
    LText := LDocument.FormatJSON;
    if LAdmit then
    begin
      SetLength(LEvidence, 1);
      LEvidence[0].Name := ExtractFileName(ParamStr(2));
      LEvidence[0].SourceSha256 := LInfo.Sha256;
      LEvidence[0].AdmissionPolicy := 'pythian.wave-context-admission.v1; explicit key; ' +
        LTempoPolicy + '; ' + LOriginPolicy + '; no downbeat inference; report_sha256=' +
        HashText(LText);
      LEvidence[0].Grid := LScope.Grid;
      LBundle := TContextLearningBundle.Create(LEvidence);
      LProfile := TContextProfile.Create(LBundle);
      LBytes := EncodeContextProfile(LProfile);
      { Construct/validate both artifacts before individual non-atomic writes. }
      WriteFileBytes(LProfileName, LBytes);
      WriteLn('Admitted profile ', LProfile.Identity, '; cells ', Length(LScope.Grid.Keys));
    end;
    WriteTextFile(LReportName, LText);
    WriteLn('Measured source ', LInfo.Sha256, '; tonal candidates ', LAdmission.Report.CandidateCount);
  finally
    LProfile.Free;
    LBundle.Free;
    LDocument.Free;
  end;
end;

begin
  try
    if ParamStr(1) = 'admit-key-regions' then
    begin
      AdmitKeyRegions;
    end
    else
    begin
      Run;
    end;
  except
    on LException: Exception do
    begin
      WriteLn(StdErr, LException.ClassName, ': ', LException.Message);
      Halt(1);
    end;
  end;
end.
