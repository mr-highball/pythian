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
unit pythian.tools.studio.instrumental.stream;
{$mode delphi}
{$H+}

interface
uses fpjson, pythian.progress, pythian.wfc.musical.corpus,
  pythian.wfc.instrumental, pythian.wfc.percussion,
  pythian.tools.studio.instrumental.publication;

{ Borrows the learned corpus, instruments and percussion models. The ordinary
  durable worker owns scheduling/cancellation. No browser lease or source PCM is
  performed. Models/options/actual origins are saved without a full score. }
function RunStudioPlaylistStream(const ACatalogRoot, AJobId: String;
  const ARequest, ASettings, ALearning: TJSONObject; const ACorpus: TMusicalCorpus;
  const ARoles: TInstrumentalRoles; const ADrums: TPercussionDefinitions;
  const ACheck: TInstrumentalWorkCheck; const AProgress: TWorkProgressCallback): TJSONObject;

implementation
uses SysUtils, pythian.audio, pythian.bus, pythian.music.sound,
  pythian.music.stream, pythian.wfc.layers, pythian.wfc.instrumental.stream,
  pythian.tools.studio.jobs, pythian.tools.studio.projects,
  pythian.tools.studio.instrumental.output, pythian.tools.studio.instrumental.config,
  pythian.tools.studio.material.reference, wfc_music_voices_graph;

function RunStudioPlaylistStream(const ACatalogRoot, AJobId: String;
  const ARequest, ASettings, ALearning: TJSONObject; const ACorpus: TMusicalCorpus;
  const ARoles: TInstrumentalRoles; const ADrums: TPercussionDefinitions;
  const ACheck: TInstrumentalWorkCheck; const AProgress: TWorkProgressCallback): TJSONObject;
var
  LOptions: TInstrumentalStreamOptions;
  LStream: TInstrumentalMusicStream;
  LOutput: TStudioInstrumentalOutput;
  LMaster: TAudioSamples;
  LStems: TBusSampleBlocks;
  LModels: TLayerModelTexts;
  LMeta, LStored, LReference, LMaterial, LEstimate, LRow: TJSONObject;
  LProviders, LGraph, LModelsJson, LModelNames: TJSONArray;
  LRhythms, LConstraints, LTokens: TJSONArray;
  LDirectory, LModelText, LModelHash: String;
  LSound: TMusicalSound;
  LConfig: TWfcMusicVoicesGraphConfig;
  LReplayConfig: TJSONObject;
  LPairs, LDrumRecipes: TJSONArray;
  I, J, K: Integer;
begin
  Result := nil;
  LStream := nil;
  LOutput := nil;
  LReference := nil;
  LMaterial := nil;
  LStored := nil;
  LEstimate := StudioInstrumentalOutputEstimate(ARequest.Int64s['duration_ms']);
  LMeta := TJSONObject.Create;
  try
    LDirectory := StudioJobDirectory(ACatalogRoot, AJobId);
    LOptions := DefaultInstrumentalStreamOptions(LEstimate.Int64s['music_frames']);
    LOptions.TailFrames := LEstimate.Int64s['tail_frames'];
    LOptions.TempoMicroseconds := ALearning.Integers['output_tempo_microseconds'];
    LOptions.Seed := ARequest.Arrays['seeds'].Int64s[0];
    LConfig := ACorpus.Config;
    LModels := ACorpus.CopyModelTexts(AProgress);
    LModelsJson := TJSONArray.Create;
    LMeta.Add('models', LModelsJson);
    LModelText := '';
    for I := 0 to High(LModels) do
    begin
      LModelsJson.Add(LModels[I]);
      LModelText := LModelText + IntToStr(Length(LModels[I])) + ':' + LModels[I];
    end;
    LModelHash := StudioTextHash(LModelText);
    LMeta.Add('format', 'pythian.studio.instrumental.stream.v1');
    LMeta.Add('runtime_version', InstrumentalStreamVersion);
    LMeta.Add('math_target', {$I %FPCTARGETCPU%} + '-' + {$I %FPCTARGETOS%} + '/FPC' + {$I %FPCVERSION%});
    LMeta.Add('material_origin', StudioPlaylistOrigin);
    LMeta.Add('model_sha256', LModelHash);
    LMeta.Add('settings', ASettings.Clone);
    LMeta.Objects['settings'].Delete('tonic');
    LMeta.Objects['settings'].Delete('mode');
    LMeta.Add('seed', Int64(LOptions.Seed));
    LMeta.Add('tempo_microseconds', LOptions.TempoMicroseconds);
    LMeta.Add('ticks_per_quarter', LOptions.TicksPerQuarter);
    LMeta.Add('step_ticks', LOptions.StepTicks);
    LMeta.Add('context_binding', 'all_roles');
    LMeta.Add('continuation_policy', 'require_structural_support_for_remaining_cells');
    LMeta.Add('lookahead_cells', LOptions.SegmentCells);
    LMeta.Add('voice_limit', LOptions.VoiceLimit);
    LMeta.Add('work_limit', LOptions.WorkLimit);
    LMeta.Add('max_backtracks', LOptions.MaxBacktracks);
    LMeta.Add('max_pass_backtracks', LOptions.MaxPassBacktracks);
    LMeta.Add('output', LEstimate.Clone);
    LMeta.Add('playlist_learning', ALearning.Clone);
    if ACorpus.ProposedSound(LSound) then
      LMeta.Add('applied_sound', TJSONObject.Create(['cutoff_hz', LSound.CutoffHz,
        'sustain_percent', LSound.SustainPercent,
        'origin', 'Experimental brightness/dynamics mapping applied to all pitched roles']));
    LProviders := TJSONArray.Create;
    LMeta.Add('roles', LProviders);
    LModelNames := TJSONArray.Create(['harmony', 'rhythm']);
    LMeta.Add('model_labels', LModelNames);
    for I := 0 to High(ARoles) do
    begin
      LModelNames.Add('voice:' + ARoles[I].Name);
      LProviders.Add(TJSONObject.Create(['name', ARoles[I].Name,
        'instrument_id', ARoles[I].InstrumentId, 'output_bus', ARoles[I].OutputBus,
        'minimum_pitch', LConfig.Voices[I].MinPitch, 'maximum_pitch', LConfig.Voices[I].MaxPitch]));
    end;
    LModelNames.Add('musical-context');
    LReplayConfig := TJSONObject.Create;
    LMeta.Add('musical_config', LReplayConfig);
    LReplayConfig.Add('steps_per_octave', LConfig.StepsPerOctave);
    LReplayConfig.Add('harmony_mode', Ord(LConfig.HarmonyMode));
    LPairs := TJSONArray.Create;
    LReplayConfig.Add('voice_pairs', LPairs);
    for I := 0 to High(LConfig.PairConstraints) do
      LPairs.Add(TJSONObject.Create(['lower', LConfig.PairConstraints[I].LowerVoice,
        'upper', LConfig.PairConstraints[I].UpperVoice, 'min_gap', LConfig.PairConstraints[I].MinGap,
        'max_gap', LConfig.PairConstraints[I].MaxGap, 'rest_policy', Ord(LConfig.PairConstraints[I].RestPolicy)]));
    LDrumRecipes := TJSONArray.Create;
    LMeta.Add('percussion', LDrumRecipes);
    for I := 0 to High(ADrums) do
    begin
      LModelNames.Add('percussion:' + ADrums[I].Name);
      LRow := TJSONObject.Create(['name', ADrums[I].Name,
        'kind', Ord(ADrums[I].Settings.Kind), 'gain', ADrums[I].Settings.Gain,
        'pan', ADrums[I].Settings.Pan, 'gate_seconds', ADrums[I].Settings.GateSeconds,
        'release_seconds', ADrums[I].Settings.ReleaseSeconds, 'tone_hz', ADrums[I].Settings.ToneHz,
        'cutoff_hz', ADrums[I].Settings.CutoffHz, 'output_bus', ADrums[I].OutputBus,
        'enabled', ADrums[I].Enabled, 'hit_weight', ADrums[I].HitWeight]);
      LDrumRecipes.Add(LRow);
      LRhythms := TJSONArray.Create;
      LRow.Add('allowed_hit_rhythms', LRhythms);
      for J := 0 to High(ADrums[I].AllowedHitRhythms) do LRhythms.Add(ADrums[I].AllowedHitRhythms[J]);
      LConstraints := TJSONArray.Create;
      LRow.Add('constraints', LConstraints);
      for J := 0 to High(ADrums[I].Constraints) do
      begin
        LTokens := TJSONArray.Create;
        LConstraints.Add(TJSONObject.Create(['position', ADrums[I].Constraints[J].Position,
          'allowed_tokens', LTokens]));
        for K := 0 to High(ADrums[I].Constraints[J].AllowedTokens) do
          LTokens.Add(ADrums[I].Constraints[J].AllowedTokens[K]);
      end;
    end;
    if LModelNames.Count <> Length(LModels) then
      raise EAudio.Create('Musical corpus model layout differs from stream replay metadata');
    LOutput := TStudioInstrumentalOutput.Create(ACatalogRoot, AJobId,
      StudioInstrumentalRate, LEstimate.Int64s['frame_count'], ASettings.Arrays['levels'], LOptions.Seed);
    ReportWork(AProgress, 'instrumental_plan_begin', wuItems, 0, 1);
    LStream := TInstrumentalMusicStream.Create(LConfig, ARoles, ADrums,
      LOutput.Graph, LOptions, ACorpus.ContextModel);
    LMeta.Add('total_cells', LStream.TotalCells);
    LGraph := TJSONArray.Create;
    LMeta.Add('graph', LGraph);
    LGraph.Add(TJSONObject.Create(['name', 'Musical context', 'kind', 'sequence',
      'maximum_width', LOptions.SegmentCells, 'height', 1, 'depth', 1]));
    LGraph.Add(TJSONObject.Create(['name', 'Joint harmony, rhythm and pitched roles',
      'kind', 'joint_voices_graph_with_coverage', 'providers', 2 + Length(ARoles),
      'maximum_width', LOptions.SegmentCells, 'height', 1, 'depth', 1]));
    for I := 0 to High(ADrums) do
      LGraph.Add(TJSONObject.Create(['name', ADrums[I].Name, 'kind', 'rhythm_conditioned_sequence',
        'maximum_width', LOptions.SegmentCells, 'height', 1, 'depth', 1]));
    WriteStudioJSONNew(LDirectory + PathDelim + 'instrumental-stream.json', LMeta);
    ReportWork(AProgress, 'instrumental_render', wuFrames, 0, LStream.FrameCount);
    while LStream.ReadOutputs(2048, StudioInstrumentalStemBuses, LMaster, LStems, AProgress) do
    begin
      if Assigned(ACheck) then ACheck;
      LOutput.Append(LMaster, LStems);
      ReportWork(AProgress, 'instrumental_render', wuFrames, LStream.Position, LStream.FrameCount);
    end;
    if LStream.State <> issCompleted then raise EAudio.Create('Instrumental stream ended before the requested clock');
    ReportWork(AProgress, 'instrumental_save', wuItems, 0, 1);
    LStored := LOutput.Finish(AProgress);
    LMeta.Add('completed_frames', LStream.Position);
    LMeta.Add('planned_segments', LStream.PlannedSegments);
    LMeta.Add('peak_voices', LStream.PeakVoices);
    LMeta.Add('percussion_hits', LStream.PercussionHits);
    { Requested replay metadata is immutable; completion is a separate receipt. }
    WriteStudioJSONNew(LDirectory + PathDelim + 'instrumental-stream-completed.json', LMeta);
    LMaterial := TJSONObject.Create;
    LMaterial.Add('source', ALearning.Objects['reference_source'].Clone);
    LReference := StageStudioMaterialReference(ACatalogRoot, AJobId, LMaterial, AProgress);
    Result := TJSONObject.Create;
    try
      Result.Add('kind', 'instrumental');
      Result.Add('runtime', 'bounded_instrumental_stream');
      Result.Add('completed_render_count', 1);
      Result.Add('expected_render_count', 1);
      Result.Add('experimental', True);
      Result.Add('material_origin', StudioPlaylistOrigin);
      Result.Add('settings', LMeta.Objects['settings'].Clone);
      Result.Add('playlist_learning', ALearning.Clone);
      Result.Add('output_resources', LEstimate.Clone);
      Result.Add('stream', TJSONObject.Create(['version', InstrumentalStreamVersion,
        'lookahead_cells', LOptions.SegmentCells, 'total_cells', LStream.TotalCells,
        'planned_segments', LStream.PlannedSegments, 'peak_voices', LStream.PeakVoices,
        'percussion_hits', LStream.PercussionHits, 'frame_count', LStream.FrameCount,
        'replay_artifact', 'instrumental-stream.json',
        'completed_artifact', 'instrumental-stream-completed.json']));
      Result.Add('graph', LGraph.Clone);
      Result.Add('model_sha256', LModelHash);
      Result.Add('material_sha256', StudioTextHash(StudioPlaylistOrigin +
        ARequest.Strings['project_snapshot_sha256'] + LModelHash));
      Result.Add('plan_sha256', StudioTextHash(LMeta.AsJSON));
      Result.Add('project_id', ARequest.Strings['project_id']);
      Result.Add('project_revision', ARequest.Int64s['project_revision']);
      Result.Add('project_snapshot_sha256', ARequest.Strings['project_snapshot_sha256']);
      Result.Add('request_sha256', ARequest.Strings['request_sha256']);
      Result.Add('sources', TJSONArray.Create([ALearning.Objects['reference_source'].Clone]));
      Result.Add('used_sources', TJSONArray.Create);
      Result.Add('parts', LStored.Arrays['parts'].Clone);
      Result.Add('outputs', LStored.Arrays['outputs'].Clone);
      if LReference <> nil then Result.Add('original_reference', LReference.Clone);
      PublishStudioInstrumental(ACatalogRoot, AJobId, ARequest, Result, LReference,
        True, ACheck, AProgress);
    except
      FreeAndNil(Result);
      raise;
    end;
  finally
    LStream.Free;
    LOutput.Free;
    LStored.Free;
    LMaterial.Free;
    LReference.Free;
    LMeta.Free;
    LEstimate.Free;
  end;
end;
end.
