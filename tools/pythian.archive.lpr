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
program pythian_archive;

{$mode delphi}
{$H+}

uses
  SysUtils,
  fpjson,
  pythian.audio,
  pythian.wave,
  pythian.analysis,
  pythian.activity,
  pythian.continuity,
  pythian.learning,
  pythian.corpus,
  pythian.corpus.archive,
  pythian.granular,
  pythian.wfc.corpus,
  pythian.wfc.generation,
  pythian.wfc.activity,
  pythian.wfc.joint,
  pythian.wfc.joint.archive,
  pythian.wfc.stream,
  pythian.tools.files,
  pythian.tools.sources,
  wfc,
  wfc_music_arrangement,
  wfc_sequence,
  wfc_sequence_graph,
  wfc_sequence_text;

procedure ProtectInput(const AInput, AOutput: String);
begin
  if SameFileName(ExpandFileName(AInput), ExpandFileName(AOutput)) then
  begin
    raise EAudio.Create('Corpus output must not replace an input file');
  end;
end;

procedure FreeSources(var ASources: TAudioSources);
var
  LIndex: Integer;
begin
  for LIndex := 0 to High(ASources) do
  begin
    ASources[LIndex].Free;
  end;
  ASources := nil;
end;

procedure Learn;
var
  LSources: TAudioSources;
  LInfo: TAcousticSourceInfos;
  LCorpus: TAcousticCorpusData;
  LBytes: TAudioBytes;
  LIndex: Integer;
  LArgument: Integer;
  LCount: Integer;
  LSamples: Int64;
  LPaths: array of String;
  LProvenance: UTF8String;
begin
  if ParamCount < 3 then
  begin
    raise EAudio.Create('Usage: pythian.archive learn OUTPUT.pyac ' +
      '[--provenance TEXT] INPUT.wav [INPUT.wav ...]');
  end;
  SetLength(LPaths, MaximumCorpusSources);
  SetLength(LInfo, MaximumCorpusSources);
  LCount := 0;
  LProvenance := '';
  LArgument := 3;
  while LArgument <= ParamCount do
  begin
    if ParamStr(LArgument) = '--provenance' then
    begin
      Inc(LArgument);
      if LArgument > ParamCount then
      begin
        raise EAudio.Create('Provenance option requires text');
      end;
      LProvenance := UTF8Encode(UnicodeString(ParamStr(LArgument)));
      ValidateCorpusText(LProvenance);
    end
    else
    begin
      if LCount = MaximumCorpusSources then
      begin
        raise EAudio.Create('Corpus supports at most 32 recordings');
      end;
      ProtectInput(ParamStr(LArgument), ParamStr(2));
      LPaths[LCount] := ParamStr(LArgument);
      LInfo[LCount].Provenance := LProvenance;
      Inc(LCount);
    end;
    Inc(LArgument);
  end;
  if LCount = 0 then
  begin
    raise EAudio.Create('At least one WAV source is required');
  end;
  SetLength(LPaths, LCount);
  SetLength(LInfo, LCount);
  SetLength(LSources, LCount);
  try
    LSamples := 0;
    for LIndex := 0 to High(LSources) do
    begin
      LSources[LIndex] := LoadWaveSource(LPaths[LIndex], LInfo[LIndex].Sha256);
      LInfo[LIndex].Name := UTF8Encode(UnicodeString(ExtractFileName(LPaths[LIndex])));
      LInfo[LIndex].SampleRate := LSources[LIndex].SampleRate;
      LInfo[LIndex].Channels := LSources[LIndex].Channels;
      LInfo[LIndex].FrameCount := LSources[LIndex].FrameCount;
      Inc(LSamples, Int64(LSources[LIndex].FrameCount) * LSources[LIndex].Channels);
      if LSamples > MaximumClipSamples then
      begin
        raise EAudio.Create('Combined source recordings exceed sample budget');
      end;
    end;
    LCorpus := TrainAcousticCorpus(LSources, LInfo, DefaultAnalysisOptions);
    try
      LBytes := EncodeWfcAcousticCorpus(LCorpus);
      WriteFileBytes(ParamStr(2), LBytes);
      WriteLn('Saved ', LCorpus.SourceCount, ' recordings, ', LCorpus.FeatureCount,
        ' observations and ', LCorpus.PaletteCount, ' shared tokens');
      WriteLn('Archive SHA256: ', HashAudioBytes(LBytes));
    finally
      LCorpus.Free;
    end;
  finally
    FreeSources(LSources);
  end;
end;

function DescribeCorpus(const ACorpus: TAcousticCorpusData;
  const AModel: TWfcSequenceModel; const AArchiveHash: String): TJSONObject;
var
  LArray: TJSONArray;
  LSource: TJSONObject;
  LInfo: TAcousticSourceInfo;
  LIndex: Integer;
begin
  Result := TJSONObject.Create;
  try
    Result.Add('contract', 'pythian.corpus.v1');
    Result.Add('archive_sha256', AArchiveHash);
    Result.Add('analysis_version', AnalysisVersion);
    Result.Add('learning_version', AcousticLearningVersion);
    Result.Add('window_frames', ACorpus.Options.WindowFrames);
    Result.Add('hop_frames', ACorpus.Options.HopFrames);
    Result.Add('silence_rms', ACorpus.Options.SilenceRms);
    Result.Add('observations', ACorpus.FeatureCount);
    Result.Add('palette_tokens', ACorpus.PaletteCount);
    Result.Add('model_order', AModel.Order);
    Result.Add('model_states', AModel.StateCount);
    LArray := TJSONArray.Create;
    Result.Add('sources', LArray);
    for LIndex := 0 to ACorpus.SourceCount - 1 do
    begin
      LInfo := ACorpus.SourceInfoAt(LIndex);
      LSource := TJSONObject.Create;
      LArray.Add(LSource);
      LSource.Add('index', LIndex);
      LSource.Add('name', String(LInfo.Name));
      LSource.Add('sha256', LInfo.Sha256);
      LSource.Add('provenance', String(LInfo.Provenance));
      LSource.Add('sample_rate', LInfo.SampleRate);
      LSource.Add('channels', LInfo.Channels);
      LSource.Add('frames', LInfo.FrameCount);
    end;
  except
    Result.Free;
    raise;
  end;
end;

function ActivityOptionsJson(const AOptions: TActivityOptions): TJSONObject;
begin
  Result := TJSONObject.Create;
  try
    Result.Add('version', AcousticActivityVersion);
    Result.Add('minimum_flux', AOptions.MinimumFlux);
    Result.Add('adaptive_multiplier', AOptions.AdaptiveMultiplier);
    Result.Add('history_features', AOptions.HistoryFeatures);
    Result.Add('peak_radius', AOptions.PeakRadius);
    Result.Add('minimum_separation_features', AOptions.MinimumSeparationFeatures);
    Result.Add('maximum_segment_features', AOptions.MaximumSegmentFeatures);
  except
    Result.Free;
    raise;
  end;
end;

function ContinuityReportJson(const AReport: TContinuityReport): TJSONObject;
begin
  Result := TJSONObject.Create;
  try
    Result.Add('grains', AReport.GrainCount);
    Result.Add('contiguous_links', AReport.ContiguousLinks);
    Result.Add('source_jumps', AReport.SourceJumps);
    Result.Add('source_switches', AReport.SourceSwitches);
    Result.Add('jumps_into_sustain', AReport.JumpsIntoSustain);
    Result.Add('selected_onsets', AReport.SelectedOnsets);
    Result.Add('mean_center_error', AReport.MeanCenterError);
    Result.Add('mean_seam_error', AReport.MeanSeamError);
    Result.Add('total_cost', AReport.TotalCost);
  except
    Result.Free;
    raise;
  end;
end;

procedure AddActivity(const ADocument: TJSONObject; const ACorpus: TAcousticCorpusData);
const
  CActionNames: array[TAcousticAction] of String = ('silence', 'onset', 'sustain');
var
  LOptions: TActivityOptions;
  LRecording: TAcousticRecording;
  LActivity: TAcousticActivity;
  LSegments: TJSONArray;
  LSegment: TJSONObject;
  LSource: TJSONObject;
  LModel: TWfcSequenceModel;
  LSourceIndex: Integer;
  LIndex: Integer;
  LOnsets: Integer;
begin
  LOptions := DefaultActivityOptions;
  ADocument.Add('activity', ActivityOptionsJson(LOptions));
  for LSourceIndex := 0 to ACorpus.SourceCount - 1 do
  begin
    LRecording := ACorpus.RecordingAt(LSourceIndex);
    LActivity := AnalyzeAcousticActivity(LRecording.Features, ACorpus.Options,
      LRecording.Info.FrameCount, LOptions);
    LSource := ADocument.Arrays['sources'].Objects[LSourceIndex];
    LSegments := TJSONArray.Create;
    LSource.Add('segments', LSegments);
    LOnsets := 0;
    for LIndex := 0 to High(LActivity.Actions) do
    begin
      if LActivity.Actions[LIndex] = aaOnset then
      begin
        Inc(LOnsets);
      end;
    end;
    LSource.Add('onset_candidates', LOnsets);
    for LIndex := 0 to High(LActivity.Segments) do
    begin
      LSegment := TJSONObject.Create;
      LSegments.Add(LSegment);
      LSegment.Add('start_feature', LActivity.Segments[LIndex].StartFeature);
      LSegment.Add('feature_count', LActivity.Segments[LIndex].FeatureCount);
      LSegment.Add('start_frame', LActivity.Segments[LIndex].StartFrame);
      LSegment.Add('frame_count', LActivity.Segments[LIndex].FrameCount);
      LSegment.Add('action', CActionNames[LActivity.Segments[LIndex].Action]);
      if LActivity.Segments[LIndex].Action = aaOnset then
      begin
        LSegment.Add('onset_flux', LActivity.Strengths[LActivity.Segments[LIndex].StartFeature]);
        LSegment.Add('onset_window_frames',
          LRecording.Features[LActivity.Segments[LIndex].StartFeature].ValidFrames);
      end;
    end;
  end;
  LModel := LearnAcousticRhythmModel(ACorpus, LOptions);
  try
    ADocument.Add('rhythm_quantum_source_frames', ACorpus.Options.HopFrames);
    ADocument.Add('rhythm_model_states', LModel.StateCount);
    ADocument.Add('rhythm_model_text', EncodeWfcSequenceText(LModel));
  finally
    LModel.Free;
  end;
end;

procedure LoadBoundSources(const ACorpus: TAcousticCorpusData; out ASources: TAudioSources;
  const AFirstArgument: Integer);
var
  LPaths: array of String;
  LIndex: Integer;
begin
  if (AFirstArgument < 1) or (AFirstArgument > ParamCount + 1) then
  begin
    raise EAudio.Create('Source argument range is invalid');
  end;
  SetLength(LPaths, ParamCount - AFirstArgument + 1);
  for LIndex := 0 to High(LPaths) do
  begin
    LPaths[LIndex] := ParamStr(AFirstArgument + LIndex);
  end;
  ASources := LoadBoundCorpusSources(ACorpus, LPaths);
end;

function GenerateJointChunks(const AModel: TWfcSequenceModel;
  const AGeneration: TAcousticGenerationOptions; const AChunkCells: Integer;
  const AConstraints: TJointConstraints; var ASequence: TJointSequence;
  out AReport: TGraphSolveReport; const ADocument: TJSONObject): Boolean;
var
  LStream: TLearnedSequenceStream;
  LOptions: TSequenceChunkOptions;
  LChunk: TWfcGeneratedSequenceSegment;
  LConstraints: TJointConstraints;
  LCandidate: TJointSequence;
  LStates: TWfcSequenceStateIndices;
  LValidation: TWfcSequenceGraphValidationReport;
  LChunks: TJSONArray;
  LItem: TJSONObject;
  LStateJson: TJSONArray;
  LIndex: Integer;
  LCount: Integer;
  LOffset: Integer;
  LSection: Integer;
begin
  Result := False;
  SetLength(LCandidate.Tokens, AGeneration.FrameCount);
  SetLength(LCandidate.Actions, AGeneration.FrameCount);
  SetLength(LStates, AGeneration.FrameCount);
  LStream := TLearnedSequenceStream.Create(AModel);
  try
    LChunks := TJSONArray.Create;
    ADocument.Add('chunks', LChunks);
    LOptions := DefaultSequenceChunkOptions;
    LOptions.MaxBacktracks := AGeneration.MaxBacktracks;
    LOffset := 0;
    LSection := 0;
    while LOffset < AGeneration.FrameCount do
    begin
      LOptions.CellCount := AChunkCells;
      if LOptions.CellCount > AGeneration.FrameCount - LOffset then
      begin
        LOptions.CellCount := AGeneration.FrameCount - LOffset;
      end;
      LOptions.Seed := WfcMusicArrangementSectionSeed(AGeneration.Seed, LSection);
      LOptions.RequireObservedEnd := LOffset + LOptions.CellCount = AGeneration.FrameCount;
      LConstraints := nil;
      for LIndex := 0 to High(AConstraints) do
      begin
        if (AConstraints[LIndex].Position >= LOffset) and
          (AConstraints[LIndex].Position < LOffset + LOptions.CellCount) then
        begin
          LCount := Length(LConstraints);
          SetLength(LConstraints, LCount + 1);
          LConstraints[LCount] := AConstraints[LIndex];
          Dec(LConstraints[LCount].Position, LOffset);
        end;
      end;
      if not LStream.TryNext(LOptions, JointTokenConstraints(AModel, LConstraints),
        LChunk, AReport) then
      begin
        Exit;
      end;
      LItem := TJSONObject.Create;
      LChunks.Add(LItem);
      LItem.Add('start_cell', LOffset);
      LItem.Add('cell_count', LOptions.CellCount);
      LItem.Add('seed', Int64(LOptions.Seed));
      LItem.Add('previous_state', LChunk.Boundary.PreviousState);
      LItem.Add('require_observed_end', LOptions.RequireObservedEnd);
      LStateJson := TJSONArray.Create;
      LItem.Add('states', LStateJson);
      for LIndex := 0 to High(LChunk.Tokens) do
      begin
        DecodeJointAcousticToken(LChunk.Tokens[LIndex], LCandidate.Tokens[LOffset + LIndex],
          LCandidate.Actions[LOffset + LIndex]);
        LStates[LOffset + LIndex] := LChunk.StateIndices[LIndex];
        LStateJson.Add(LChunk.StateIndices[LIndex]);
      end;
      Inc(LOffset, LOptions.CellCount);
      Inc(LSection);
    end;
    if not ValidateSequenceStatePath(AModel, LStates, wseWhole, LValidation) then
    begin
      raise EAudio.Create('Combined stream failed complete WFC path validation');
    end;
    ADocument.Add('sequence_stream_version', SequenceStreamVersion);
    ADocument.Add('chunk_cells', AChunkCells);
    ADocument.Add('section_seed_version', WFC_MUSIC_ARRANGEMENT_VERSION);
    ADocument.Add('complete_path_validated', True);
    ASequence := LCandidate;
    Result := True;
  finally
    LStream.Free;
  end;
end;

procedure InspectOrRemix(const ARemix, AContinuous, ASegments: Boolean;
  const AJoint: Boolean = False; const ASavedJoint: Boolean = False;
  const AStream: Boolean = False);
var
  LBytes: TAudioBytes;
  LCorpus: TAcousticCorpusData;
  LModel: TWfcSequenceModel;
  LDocument: TJSONObject;
  LSources: TAudioSources;
  LInfo: TAcousticSourceInfo;
  LGeneration: TAcousticGenerationOptions;
  LReport: TGraphSolveReport;
  LIndices: TAcousticIndices;
  LGrains: TAudioGrains;
  LOutput: TAudioClip;
  LEvents: TJSONArray;
  LEvent: TJSONObject;
  LIndex: Integer;
  LSeed: QWord;
  LSourceUse: array of Integer;
  LPlanner: TCorpusGrainPlanner;
  LContinuityOptions: TContinuityOptions;
  LContinuityReport: TContinuityReport;
  LBaselineReport: TContinuityReport;
  LPolicy: TJSONObject;
  LFirstSource: Integer;
  LPattern: String;
  LJointConstraints: TJointConstraints;
  LJointModel: TWfcSequenceModel;
  LJointSequence: TJointSequence;
  LGenerated: Boolean;
  LModelText: String;
  LActivity: TActivityOptions;
  LChunkCells: Integer;
  LMaximumCells: Integer;
begin
  LFirstSource := 6;
  if AJoint then
  begin
    LFirstSource := 7;
  end;
  LChunkCells := 0;
  LMaximumCells := MaximumGeneratedAcousticFrames;
  if AStream then
  begin
    LFirstSource := 8;
    LMaximumCells := MaximumContinuityGrains;
    LChunkCells := StrToInt(ParamStr(7));
    if (LChunkCells < 1) or (LChunkCells > MaximumGeneratedAcousticFrames) then
    begin
      raise EAudio.Create('Stream chunk must have 1..1024 cells');
    end;
  end;
  LGeneration := DefaultAcousticGenerationOptions;
  if ARemix then
  begin
    if ParamCount < LFirstSource then
    begin
      raise EAudio.Create('Usage: pythian.archive ' + ParamStr(1) + ' INPUT.pyac OUTPUT.wav ' +
        'SEED ACOUSTIC_FRAMES [ACTIVITY_PATTERN for joint] ' +
        '[CHUNK_CELLS for remix-stream-joint] SOURCE.wav [SOURCE.wav ...]');
    end;
    ProtectInput(ParamStr(2), ParamStr(3));
    ProtectInput(ParamStr(2), ParamStr(3) + '.json');
    for LIndex := LFirstSource to ParamCount do
    begin
      ProtectInput(ParamStr(LIndex), ParamStr(3));
      ProtectInput(ParamStr(LIndex), ParamStr(3) + '.json');
    end;
    if not TryStrToQWord(ParamStr(4), LSeed) or (LSeed > High(TGraphSeed)) then
    begin
      raise EAudio.Create('Seed must fit WFC seed type');
    end;
    LGeneration.Seed := LSeed;
    LGeneration.FrameCount := StrToInt(ParamStr(5));
    if (LGeneration.FrameCount < 1) or
      (LGeneration.FrameCount > LMaximumCells) then
    begin
      raise EAudio.Create('Acoustic output cells must be 1..' + IntToStr(LMaximumCells));
    end;
  end
  else if ParamCount <> 2 then
  begin
    raise EAudio.Create('Usage: pythian.archive ' + ParamStr(1) + ' INPUT.pyac');
  end;
  if AJoint then
  begin
    LPattern := ParamStr(6);
    if (Length(LPattern) < 1) or (Length(LPattern) > LGeneration.FrameCount) then
    begin
      raise EAudio.Create('Activity pattern must have 1..ACOUSTIC_FRAMES characters');
    end;
    SetLength(LJointConstraints, Length(LPattern));
    for LIndex := 1 to Length(LPattern) do
    begin
      LJointConstraints[LIndex - 1].Position := LIndex - 1;
      LJointConstraints[LIndex - 1].AcousticToken := -1;
      case LPattern[LIndex] of
        '?':
        begin
          LJointConstraints[LIndex - 1].AllowedActions := [aaSilence, aaOnset, aaSustain];
        end;
        'r':
        begin
          LJointConstraints[LIndex - 1].AllowedActions := [aaSilence];
        end;
        'a':
        begin
          LJointConstraints[LIndex - 1].AllowedActions := [aaOnset];
        end;
        'h':
        begin
          LJointConstraints[LIndex - 1].AllowedActions := [aaSustain];
        end;
      else
        raise EAudio.Create('Activity pattern accepts only ?, r, a, h');
      end;
    end;
  end;
  LBytes := ReadFileBytes(ParamStr(2), MaximumCorpusArchiveBytes);
  LActivity := DefaultActivityOptions;
  if ASavedJoint then
  begin
    LCorpus := DecodeWfcJointCorpus(LBytes, LModel, LActivity);
  end
  else
  begin
    LCorpus := DecodeWfcAcousticCorpus(LBytes, LModel);
  end;
  try
    LDocument := DescribeCorpus(LCorpus, LModel, HashAudioBytes(LBytes));
    try
      if ASavedJoint then
      begin
        LDocument.Add('model_attachment', WfcJointAttachmentContract);
        LDocument.Add('joint_activity', ActivityOptionsJson(LActivity));
        LDocument.Add('model_public_tokens', LModel.PublicTokenCount);
        LDocument.Add('model_sha256', HashText(EncodeWfcSequenceText(LModel)));
      end;
      if not ARemix then
      begin
        if ASegments then
        begin
          AddActivity(LDocument, LCorpus);
        end;
        WriteLn(LDocument.FormatJSON);
        Exit;
      end;
      LoadBoundSources(LCorpus, LSources, LFirstSource);
      try
        if AJoint then
        begin
          if ASavedJoint then
          begin
            LJointModel := LModel;
          end
          else
          begin
            LJointModel := LearnJointAcousticModel(LCorpus, LActivity, LModel.Order);
          end;
          try
            if AStream then
            begin
              LGenerated := GenerateJointChunks(LJointModel, LGeneration, LChunkCells,
                LJointConstraints, LJointSequence, LReport, LDocument);
            end
            else
            begin
              LGenerated := TryGenerateJointSequence(LJointModel, LGeneration,
                LJointConstraints, LJointSequence, LReport);
            end;
            if LGenerated then
            begin
              LIndices := LJointSequence.Tokens;
              LPolicy := TJSONObject.Create;
              LDocument.Add('joint', LPolicy);
              LPolicy.Add('version', JointAcousticVersion);
              LPolicy.Add('activity_version', AcousticActivityVersion);
              LPolicy.Add('activity', ActivityOptionsJson(LActivity));
              LPolicy.Add('loaded_without_learning', ASavedJoint);
              LPolicy.Add('pattern', LPattern);
              LPolicy.Add('grid', 'analysis_hop');
              LPolicy.Add('states', LJointModel.StateCount);
              LPolicy.Add('observations', LJointModel.ObservationCount);
              LModelText := EncodeWfcSequenceText(LJointModel);
              LPolicy.Add('model_sha256', HashText(LModelText));
              LPolicy.Add('model_text', LModelText);
              LPolicy.Add('nearest_baseline_ignores_activity', True);
            end;
          finally
            if not ASavedJoint then
            begin
              LJointModel.Free;
            end;
          end;
        end
        else
        begin
          LGenerated := TryGenerateAcousticSequence(LModel, LGeneration, nil, LIndices, LReport);
        end;
        if not LGenerated then
        begin
          if LReport.Status = gssBacktrackLimit then
          begin
            raise EAudio.Create('WFC backtrack budget exhausted; no remix published');
          end;
          raise EAudio.Create('WFC acoustic request is contradictory; no remix published');
        end;
        LGrains := LCorpus.PlanGrains(LIndices);
        if AContinuous then
        begin
          LContinuityOptions := DefaultContinuityOptions;
          LContinuityOptions.Activity := LActivity;
          LPlanner := TCorpusGrainPlanner.Create(LCorpus, LSources, LContinuityOptions);
          try
            LBaselineReport := LPlanner.Evaluate(LIndices, LGrains);
            if AJoint then
            begin
              LGrains := LPlanner.PlanActions(LIndices, LJointSequence.Actions, LContinuityReport);
            end
            else
            begin
              LGrains := LPlanner.Plan(LIndices, LContinuityReport);
            end;
          finally
            LPlanner.Free;
          end;
          LPolicy := TJSONObject.Create;
          LDocument.Add('continuity', LPolicy);
          LPolicy.Add('version', AcousticContinuityVersion);
          LPolicy.Add('beam_width', LContinuityOptions.BeamWidth);
          LPolicy.Add('candidates_per_token', LContinuityOptions.CandidatesPerToken);
          LPolicy.Add('join_probe_frames', LContinuityOptions.JoinProbeFrames);
          LPolicy.Add('center_weight', LContinuityOptions.CenterWeight);
          LPolicy.Add('seam_weight', LContinuityOptions.SeamWeight);
          LPolicy.Add('jump_weight', LContinuityOptions.JumpWeight);
          LPolicy.Add('sustain_jump_weight', LContinuityOptions.SustainJumpWeight);
          LPolicy.Add('activity', ActivityOptionsJson(LContinuityOptions.Activity));
          LPolicy.Add('nearest_baseline', ContinuityReportJson(LBaselineReport));
          LPolicy.Add('selected_plan', ContinuityReportJson(LContinuityReport));
        end;
        SetLength(LSourceUse, LCorpus.SourceCount);
        LInfo := LCorpus.SourceInfoAt(0);
        LOutput := RenderGrains(LSources, LGrains,
          DefaultGrainRenderOptions(LInfo.SampleRate, LInfo.Channels));
        try
          LDocument.Add('output_sha256', HashAudioBytes(EncodeWavePcm16(LOutput)));
          LDocument.Add('output_frames', LOutput.FrameCount);
          LDocument.Add('seed', Int64(LGeneration.Seed));
          if AStream then
          begin
            LDocument.Add('extent', 'whole_in_chunks');
          end
          else
          begin
            LDocument.Add('extent', 'fragment');
          end;
          LDocument.Add('max_backtracks', LGeneration.MaxBacktracks);
          LDocument.Add('generation_version', AcousticGenerationVersion);
          LDocument.Add('granular_version', GranularVersion);
          LDocument.Add('wfc_solver_version', LReport.SolverAlgorithmVersion);
          LDocument.Add('wfc_random_version', LReport.RandomAlgorithmVersion);
          LEvents := TJSONArray.Create;
          LDocument.Add('grains', LEvents);
          for LIndex := 0 to High(LGrains) do
          begin
            LEvent := TJSONObject.Create;
            LEvents.Add(LEvent);
            LEvent.Add('token', LIndices[LIndex]);
            if AJoint then
            begin
              LEvent.Add('activity', Ord(LJointSequence.Actions[LIndex]));
            end;
            LEvent.Add('source_index', LGrains[LIndex].SourceIndex);
            LEvent.Add('source_start_frame', LGrains[LIndex].SourceStartFrame);
            LEvent.Add('output_start_frame', LGrains[LIndex].OutputStartFrame);
            LEvent.Add('frame_count', LGrains[LIndex].FrameCount);
            LEvent.Add('playback_rate', LGrains[LIndex].PlaybackRate);
            LEvent.Add('gain', LGrains[LIndex].Gain);
            LEvent.Add('window', 'hann');
            Inc(LSourceUse[LGrains[LIndex].SourceIndex]);
          end;
          for LIndex := 0 to High(LSourceUse) do
          begin
            LDocument.Arrays['sources'].Objects[LIndex].Add('selected_grains', LSourceUse[LIndex]);
          end;
          SaveWavePcm16(ParamStr(3), LOutput);
          WriteTextFile(ParamStr(3) + '.json', LDocument.FormatJSON);
          WriteLn('Loaded corpus and reconstructed ', Length(LGrains), ' grains into ',
            LOutput.FrameCount, ' frames without FFT');
          if AJoint then
          begin
            if ASavedJoint then
            begin
              WriteLn('Joint WFC model loaded without learning; stored activity policy used: ', LPattern);
            end
            else
            begin
              WriteLn('Joint WFC model derived from stored measurements; activity pattern: ', LPattern);
            end;
          end;
          for LIndex := 0 to High(LSourceUse) do
          begin
            WriteLn('Source ', LIndex, ': ', LSourceUse[LIndex], ' selected grains');
          end;
          if AContinuous then
          begin
            WriteLn('Contiguous links: ', LBaselineReport.ContiguousLinks, ' -> ',
              LContinuityReport.ContiguousLinks, '; source jumps: ',
              LBaselineReport.SourceJumps, ' -> ', LContinuityReport.SourceJumps);
            WriteLn('Mean normalized seam error: ', LBaselineReport.MeanSeamError:0:6,
              ' -> ', LContinuityReport.MeanSeamError:0:6);
            WriteLn('Total planning cost: ', LBaselineReport.TotalCost:0:6,
              ' -> ', LContinuityReport.TotalCost:0:6);
          end;
        finally
          LOutput.Free;
        end;
      finally
        FreeSources(LSources);
      end;
    finally
      LDocument.Free;
    end;
  finally
    LModel.Free;
    LCorpus.Free;
  end;
end;

procedure PrepareJoint;
var
  LBytes: TAudioBytes;
  LCorpus: TAcousticCorpusData;
  LModel: TWfcSequenceModel;
  LJoint: TWfcSequenceModel;
  LOrder: Integer;
begin
  if (ParamCount <> 3) and (ParamCount <> 4) then
  begin
    raise EAudio.Create('Usage: pythian.archive prepare-joint INPUT.pyac OUTPUT.pyac [ORDER]');
  end;
  ProtectInput(ParamStr(2), ParamStr(3));
  LBytes := ReadFileBytes(ParamStr(2), MaximumCorpusArchiveBytes);
  LCorpus := DecodeWfcAcousticCorpus(LBytes, LModel);
  try
    LOrder := LModel.Order;
    if ParamCount = 4 then
    begin
      LOrder := StrToInt(ParamStr(4));
    end;
    LJoint := LearnJointAcousticModel(LCorpus, DefaultActivityOptions, LOrder);
    try
      LBytes := EncodeWfcJointCorpus(LCorpus, LJoint, DefaultActivityOptions);
      WriteFileBytes(ParamStr(3), LBytes);
      WriteLn('Saved joint model: ', LJoint.PublicTokenCount, ' paired tokens, ',
        LJoint.StateCount, ' states, ', LJoint.ObservationCount, ' observations');
      WriteLn('Measured corpus retained; no FFT or palette training performed.');
    finally
      LJoint.Free;
    end;
  finally
    LModel.Free;
    LCorpus.Free;
  end;
end;

begin
  try
    if ParamStr(1) = 'learn' then
    begin
      Learn;
    end
    else if ParamStr(1) = 'inspect' then
    begin
      InspectOrRemix(False, False, False);
    end
    else if ParamStr(1) = 'prepare-joint' then
    begin
      PrepareJoint;
    end
    else if ParamStr(1) = 'inspect-joint' then
    begin
      InspectOrRemix(False, False, False, False, True);
    end
    else if ParamStr(1) = 'segments' then
    begin
      InspectOrRemix(False, False, True);
    end
    else if ParamStr(1) = 'remix' then
    begin
      InspectOrRemix(True, False, False);
    end
    else if ParamStr(1) = 'remix-joint' then
    begin
      InspectOrRemix(True, True, False, True);
    end
    else if ParamStr(1) = 'remix-saved-joint' then
    begin
      InspectOrRemix(True, True, False, True, True);
    end
    else if ParamStr(1) = 'remix-stream-joint' then
    begin
      InspectOrRemix(True, True, False, True, True, True);
    end
    else if ParamStr(1) = 'remix-continuous' then
    begin
      InspectOrRemix(True, True, False);
    end
    else
    begin
      raise EAudio.Create('Usage: pythian.archive learn|inspect|segments|remix|' +
        'remix-continuous|remix-joint|prepare-joint|inspect-joint|remix-saved-joint|' +
        'remix-stream-joint ...');
    end;
  except
    on LException: Exception do
    begin
      WriteLn(StdErr, LException.Message);
      Halt(1);
    end;
  end;
end.
