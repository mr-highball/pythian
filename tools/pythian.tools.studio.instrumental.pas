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

unit pythian.tools.studio.instrumental;

{$mode delphi}
{$H+}

interface

uses fpjson, pythian.progress, pythian.tools.studio.&library,
  pythian.tools.studio.instrumental.publication;

type
  TStudioInstrumentalCheck = TInstrumentalWorkCheck;

function RunStudioInstrumental(const ACatalogRoot, AJobId: String;
  const ARequest: TJSONObject; const ACheck: TStudioInstrumentalCheck;
  const AProgress: TWorkProgressCallback; const ALibraryRoot: String = '';
  const ACacheRoot: String = '';
  const ALibraryProgress: TStudioLibraryProgress = nil): TJSONObject;

implementation

uses Classes, SysUtils, Math,
  pythian.audio, pythian.time, pythian.bus,
  pythian.instrument, pythian.synth, pythian.oscillator, pythian.schedule,
  pythian.music.pattern, pythian.music.sound, pythian.music.controls,
  pythian.wfc.instrumental.controls,
  pythian.wfc.instrumental, pythian.wfc.instrumental.starter,
  pythian.wfc.percussion, pythian.wfc.voices, pythian.wfc.musical.context,
  pythian.wfc.musical.corpus, wfc_music_voices_graph,
  wfc_model, wfc_sequence, wfc_sequence_text,
  pythian.tools.studio.jobs, pythian.tools.studio.instrumental.config,
  pythian.tools.studio.material, pythian.tools.studio.material.reference,
  pythian.tools.studio.playlist.learning,
  pythian.tools.studio.instrumental.output,
  pythian.tools.studio.instrumental.stream;

function Shape(const AName: String): TWaveShape;
begin
  if AName = 'sine' then Exit(wsSine);
  if AName = 'triangle' then Exit(wsTriangle);
  if AName = 'saw' then Exit(wsSaw);
  if AName = 'square' then Exit(wsSquare);
  raise EAudio.Create('Unsupported instrumental oscillator');
end;

function RunStudioInstrumental(const ACatalogRoot, AJobId: String;
  const ARequest: TJSONObject; const ACheck: TStudioInstrumentalCheck;
  const AProgress: TWorkProgressCallback; const ALibraryRoot,
  ACacheRoot: String; const ALibraryProgress: TStudioLibraryProgress): TJSONObject;
var
  LStarter: TInstrumentalStarter;
  LPlan: TInstrumentalPlan;
  LOptions: TInstrumentalOptions;
  LReport: TInstrumentalReport;
  LRoles: TInstrumentalRoles;
  LInstruments: array[0..2] of TInstrument;
  LZones: TInstrumentZones;
  LDrums: TPercussionDefinitions;
  LConfig, LMeta, LRow: TJSONObject;
  LPasses, LDependencies: TJSONArray;
  LGraphInfo: TVoiceGraphPasses;
  LModel: TWfcSequenceModel;
  LTokens: TWfcModelTokens;
  LTokenArray: TJSONArray;
  LModelText, LDirectory, LModelHash, LMaterialHash: String;
  LSeed: Cardinal;
  LRole, LIndex, LPass, LCount: Integer;
  LDone: Int64;
  LPlayer: TScheduledSynth;
  LOutputWriter: TStudioInstrumentalOutput;
  LStored: TJSONObject;
  LStems: TBusSampleBlocks;
  LFrame: TStereoFrame;
  LSamples: TAudioSamples;
  LLeft, LRight: Double;
  LMaterial: TJSONObject;
  LReference: TJSONObject;
  LPattern: TPitchPattern;
  LOrigin: String;
  LMode: String;
  LRecipeHash: String;
  LPatternRole: Integer;
  LSoundRole: Integer;
  LSound: TMusicalSound;
  LMusicalControls: TMusicalPartControls;
  LCompiled: TInstrumentalGraphControls;
  LBaseMasks: TVoiceMasks;
  LTonicBias: Integer;
  LHasExpression: Boolean;
  LHasGraphControls: Boolean;
  LIsPlaylist: Boolean;
  LPlaylistHasSound: Boolean;
  LCorpus: TMusicalCorpus;
  LLearning: TJSONObject;
  LReferenceMaterial: TJSONObject;
  LWorkingConfig: TJSONObject;
  LGraphConfig: TWfcMusicVoicesGraphConfig;
  LContextModel: TWfcSequenceModel;
  LCache: String;
  LTempo: Integer;
  LModelArtifact: TJSONObject;
begin
  LConfig := ARequest.Objects['instrumental'];
  ValidateStudioInstrumentalConfig(LConfig);
  LSeed := ARequest.Arrays['seeds'].Integers[0];
  LDirectory := StudioJobDirectory(ACatalogRoot, AJobId);
  LStarter := nil; LPlan := nil; LModel := nil;
  LMeta := nil;
  LMaterial := nil;
  LReference := nil;
  LCorpus := nil;
  LLearning := nil;
  LWorkingConfig := nil;
  LReferenceMaterial := nil;
  LIsPlaylist := ARequest.Objects['project_snapshot'].Find('playlist') <> nil;
  LPlaylistHasSound := False;
  for LRole := 0 to 2 do LInstruments[LRole] := nil;
  Result := TJSONObject.Create;
  try
    try
    if Assigned(ACheck) then ACheck;
    ReportWork(AProgress, 'instrumental_prepare', wuItems, 0, 1);
    LOrigin := StudioInstrumentalOrigin;
    LMode := 'major';
    LPattern := nil;
    LPatternRole := 2;
    LRecipeHash := '';
    LSoundRole := -1;
    if LIsPlaylist then
    begin
      AdmitStudioInstrumentalOutput(ACatalogRoot, ARequest.Int64s['duration_ms']);
      LCache := ACacheRoot;
      if LCache = '' then LCache := SysUtils.GetEnvironmentVariable('PYTHIAN_STUDIO_LEARNING_CACHE_ROOT');
      if LCache = '' then LCache := IncludeTrailingPathDelimiter(ACatalogRoot) +
        'studio' + PathDelim + 'musical-cache';
      LCorpus := LearnStudioPlaylist(ACatalogRoot, ALibraryRoot, LCache, AJobId,
        ARequest.Objects['project_snapshot'].Objects['playlist'], LLearning, AProgress,
        ALibraryProgress);
      LOrigin := StudioPlaylistOrigin;
      LRecipeHash := StudioTextHash(StudioPlaylistLearningPolicy +
        ARequest.Objects['project_snapshot'].Objects['playlist'].AsJSON);
      LWorkingConfig := TJSONObject(LConfig.Clone);
      LConfig := LWorkingConfig;
      LTempo := LLearning.Integers['output_tempo_microseconds'];
      LConfig.Integers['tempo_bpm'] := Round(60000000 / LTempo);
      LConfig.Integers['cells'] := 16;
      ValidateStudioInstrumentalConfig(LConfig);
      LGraphConfig := LCorpus.Config;
      LContextModel := LCorpus.ContextModel;
      SetLength(LRoles, 3);
      for LRole := 0 to 2 do LRoles[LRole].Name := LCorpus.CopyRoleNames[LRole];
      LPlaylistHasSound := LCorpus.ProposedSound(LSound);
      LReferenceMaterial := TJSONObject.Create;
      LReferenceMaterial.Add('source', LLearning.Objects['reference_source'].Clone);
    end
    else if ARequest.Objects['project_snapshot'].Find('musical_material') <> nil then
    begin
      LMaterial := CanonicalStudioMaterial(ARequest.Objects['project_snapshot'].Objects['musical_material']);
      LRecipeHash := StudioTextHash(LMaterial.AsJSON);
      LMode := LMaterial.Strings['mode'];
      if (LMaterial.Find('sound') <> nil) and
        (LMaterial.Objects['sound'].Strings['decision'] <> 'bypassed') then
      begin
        LSoundRole := LMaterial.Objects['sound'].Integers['part'];
        LSound := DecodeStudioSound(LMaterial.Objects['sound']);
      end;
      if LMaterial.Integers['part'] >= 0 then
      begin
        LPatternRole := LMaterial.Integers['part'];
        LPattern := DecodeStudioPitchPattern(LMaterial.Arrays['pattern']);
      end;
      LOrigin := 'Operator musical choices with authored accompaniment; experimental pitch cells, explicit part assignment and WFC decisions; no source-audio grains';
    end;
    if LConfig.Find('mode') <> nil then LMode := LConfig.Strings['mode'];
    if not LIsPlaylist then
    begin
      LStarter := TInstrumentalStarter.Create(LConfig.Integers['tonic'],
        LMode = 'natural_minor', LPattern, LPatternRole, AProgress);
      LRoles := LStarter.CopyRoles;
      LGraphConfig := LStarter.Config;
      LContextModel := LStarter.ContextModel;
    end;
    for LRole := 0 to 2 do
    begin
      if LIsPlaylist then
      begin
        LZones := nil;
        SetLength(LZones, 1);
        LZones[0].MinimumKey := 0;
        LZones[0].MaximumKey := 127;
        LZones[0].MinimumVelocity := 1;
        LZones[0].MaximumVelocity := 127;
        LZones[0].Voice := DefaultSynthVoice;
        LZones[0].Voice.Gain := 0.14;
        LRoles[LRole].OutputBus := LRole;
      end
      else LZones := LRoles[LRole].Instrument.CopyZones;
      for LIndex := 0 to High(LZones) do
      begin
        LZones[LIndex].Voice.Shape := Shape(LConfig.Arrays['instruments'].Strings[LRole]);
        if (LRole = LSoundRole) or LPlaylistHasSound then
          LZones[LIndex].Voice := ApplyMusicalSound(LZones[LIndex].Voice, LSound, StudioInstrumentalRate);
      end;
      LInstruments[LRole] := TInstrument.Create(LZones);
      LRoles[LRole].Instrument := LInstruments[LRole];
      if LIsPlaylist then
        LRoles[LRole].InstrumentId := 'playlist-primary-v1-' + LConfig.Arrays['instruments'].Strings[LRole]
      else LRoles[LRole].InstrumentId := 'starter-' + LConfig.Arrays['instruments'].Strings[LRole];
      if LRole = LSoundRole then
        LRoles[LRole].InstrumentId := LRoles[LRole].InstrumentId + '-cutoff' +
          IntToStr(LSound.CutoffHz) + '-sustain' + IntToStr(LSound.SustainPercent);
    end;
    LOptions := DefaultInstrumentalOptions;
    LOptions.SampleRate := StudioInstrumentalRate;
    LOptions.Session.CellCount := LConfig.Integers['cells'];
    LOptions.Session.Seed := LSeed;
    LOptions.PercussionSeed := LSeed xor Cardinal($50455243);
    LOptions.Session.RequireObservedEnd := False;
    LOptions.Tempos[0] := MakeTempoChange(0, Round(60000000 / LConfig.Integers['tempo_bpm']));
    LOptions.MaterialOrigin := LOrigin;
    if LIsPlaylist then
    begin
      LOptions.Tempos[0] := MakeTempoChange(0, LTempo);
      LDrums := LCorpus.CopyPercussion(LOptions.SampleRate);
      for LRole := 0 to 2 do LDrums[LRole].OutputBus := LRole + 3;
      LBaseMasks := nil;
      FreeAndNil(Result);
      Result := RunStudioPlaylistStream(ACatalogRoot, AJobId, ARequest, LConfig,
        LLearning, LCorpus, LRoles, LDrums, ACheck, AProgress);
      Exit;
    end
    else
    begin
      LDrums := LStarter.CopyPercussion(LOptions.SampleRate);
      LBaseMasks := LStarter.GuideMasks(LOptions.Session.CellCount);
    end;
    LCompiled := Default(TInstrumentalGraphControls);
    LCompiled.Masks := LBaseMasks;
    LTonicBias := 0;
    if LConfig.Find('controls') <> nil then
    begin
      LMusicalControls := DecodeStudioMusicalControls(LConfig.Objects['controls']);
      LTonicBias := LConfig.Objects['controls'].Integers['tonic_bias'];
      if not LConfig.Objects['controls'].Booleans['guide'] then LBaseMasks := nil;
      LCompiled.Masks := LBaseMasks;
      LHasGraphControls := LTonicBias <> 0;
      LHasExpression := False;
      for LRole := 0 to High(LMusicalControls) do
      begin
        LHasGraphControls := LHasGraphControls or
          (LMusicalControls[LRole].MinimumPitch <> 0) or
          (LMusicalControls[LRole].MaximumPitch <> 127) or
          (LMusicalControls[LRole].ActivityBias <> 0);
        LHasExpression := LHasExpression or
          (LMusicalControls[LRole].Expression.VelocityPercent <> 100) or
          (LMusicalControls[LRole].Expression.GatePercent <> 100);
      end;
      { Big Boss: absent/neutral controls do not stage empty edits or duplicate
        mask-copy progress. Expression alone does not need graph compilation. }
      if LHasGraphControls then
      begin
        try
          LCompiled := CompileInstrumentalControls(LGraphConfig, LOptions.Session.CellCount,
            LConfig.Integers['tonic'], LTonicBias, LMusicalControls, LBaseMasks, AProgress);
        except
          on E: EAudio do
            raise EAudio.Create('Musical controls rejected: ' + E.Message);
        end;
      end;
      if LHasExpression then
      begin
        SetLength(LOptions.Expression, Length(LMusicalControls));
        for LRole := 0 to High(LMusicalControls) do
          LOptions.Expression[LRole] := LMusicalControls[LRole].Expression;
      end;
    end;
    ReportWork(AProgress, 'instrumental_plan_begin', wuItems, 0, 1);
    if not TryCreateInstrumentalPlan(LGraphConfig, LRoles, LOptions,
      LCompiled.Masks, LCompiled.Preferences, LPlan, LReport,
      AProgress, LDrums, LContextModel) then
      raise EAudio.Create('Instrumental graph rejected: ' + LReport.Detail);
    LMeta := TJSONObject.Create;
    LMeta.Add('material_origin', LOrigin);
    LMeta.Add('settings', LConfig.Clone);
    if not LIsPlaylist then LMeta.Objects['settings'].Strings['mode'] := LMode;
    if LLearning <> nil then
    begin
      LMeta.Add('playlist_learning', LLearning.Clone);
      Result.Add('playlist_learning', LLearning.Clone);
      LMeta.Add('pitch_policy', 'Source-derived proposed absolute pitches; no authored key/scale imposed');
      LMeta.Objects['settings'].Delete('tonic');
      LMeta.Objects['settings'].Delete('mode');
      LMeta.Objects['settings'].Add('tempo_microseconds', LTempo);
    end;
    if LMaterial <> nil then
    begin
      LMeta.Add('musical_material', LMaterial.Clone);
      LMeta.Add('recipe_sha256', LRecipeHash);
      if LSoundRole >= 0 then
      begin
        LMeta.Add('applied_sound', LMaterial.Objects['sound'].Clone);
        Result.Add('applied_sound', LMaterial.Objects['sound'].Clone);
        LMeta.Add('sound_policy', 'Experimental controls: twice centroid -> low-pass cutoff 100..10000 Hz; quiet/peak window RMS -> ADSR sustain 0..100 percent. Operator-selected/corrected target; not instrument identification or envelope reconstruction.');
      end;
      LMeta.Add('context_policy', 'Saved cells retain absolute MIDI notes. Context jointly decides harmony, rhythm and the selected part; other parts stay independently solved. Current tempo/root/sounds are explicit generation controls.');
      if LContextModel <> nil then
      begin
        LMeta.Add('context_role', LPlan.CopyProvider(MusicalContextPassName).RoleId);
        Result.Add('context_role', LMeta.Strings['context_role']);
      end;
    end;
    LMeta.Add('seed', Int64(LSeed));
    LMeta.Add('percussion_seed', Int64(LOptions.PercussionSeed));
    LMeta.Add('ticks_per_quarter', LOptions.Session.TicksPerQuarter);
    LMeta.Add('ticks_per_cell', LOptions.Session.StepTicks);
    LMeta.Add('sample_rate', LPlan.SampleRate);
    LMeta.Add('frame_count', LPlan.FrameCount);
    LPasses := TJSONArray.Create;
    LMeta.Add('passes', LPasses);
    LGraphInfo := LPlan.CopyGraph;
    LModelText := '';
    for LPass := 0 to High(LGraphInfo) do
    begin
      if Assigned(ACheck) then ACheck;
      LRow := TJSONObject.Create;
      LPasses.Add(LRow);
      LRow.Add('name', LGraphInfo[LPass].Name);
      LRow.Add('width', LGraphInfo[LPass].Width);
      LRow.Add('height', LGraphInfo[LPass].Height);
      LRow.Add('depth', LGraphInfo[LPass].Depth);
      LRow.Add('graph_group', LGraphInfo[LPass].GroupIndex);
      LRow.Add('proof', LGraphInfo[LPass].IsProof);
      LRow.Add('public_tokens', LGraphInfo[LPass].PublicTokenCount);
      LRow.Add('latent_states', LGraphInfo[LPass].StateCount);
      if LGraphInfo[LPass].InputSourcePassIndex >= 0 then
        LRow.Add('pinned_input_from', LGraphInfo[LPass].InputSourcePassIndex);
      LDependencies := TJSONArray.Create;
      LRow.Add('depends_on', LDependencies);
      for LIndex := 0 to High(LGraphInfo[LPass].Dependencies) do
        LDependencies.Add(LGraphInfo[LPass].Dependencies[LIndex]);
      if not LGraphInfo[LPass].IsProof then
      begin
        LModel := LPlan.CopyModel(LGraphInfo[LPass].Name);
        LModelText := LModelText + EncodeWfcSequenceText(LModel);
        LModelArtifact := TJSONObject.Create;
        try
          LModelArtifact.Add('format', 'pythian.studio.instrumental.provider.v1');
          LModelArtifact.Add('pass', LGraphInfo[LPass].Name);
          LModelArtifact.Add('model_text', EncodeWfcSequenceText(LModel));
          LRow.Add('model_artifact', 'provider-' + IntToStr(LPass) + '.json');
          WriteStudioJSONNew(LDirectory + PathDelim + LRow.Strings['model_artifact'], LModelArtifact);
        finally LModelArtifact.Free end;
        FreeAndNil(LModel);
      end;
    end;
    LModelHash := StudioTextHash(LModelText);
    LMaterialHash := StudioTextHash(LOrigin + LRecipeHash + LModelText);
    Result.Add('kind', 'instrumental');
    Result.Add('completed_render_count', 1);
    Result.Add('expected_render_count', 1);
    Result.Add('experimental', True);
    Result.Add('material_origin', LOrigin);
    Result.Add('settings', LMeta.Objects['settings'].Clone);
    if LMaterial <> nil then
    begin
      Result.Add('musical_material', LMaterial.Clone);
      Result.Add('recipe_sha256', LRecipeHash);
    end;
    Result.Add('model_sha256', LModelHash);
    Result.Add('material_sha256', LMaterialHash);
    Result.Add('graph', LPasses.Clone);
    Result.Add('project_id', ARequest.Strings['project_id']);
    Result.Add('project_revision', ARequest.Int64s['project_revision']);
    Result.Add('project_snapshot_sha256', ARequest.Strings['project_snapshot_sha256']);
    Result.Add('request_sha256', ARequest.Strings['request_sha256']);
    Result.Add('sources', TJSONArray.Create);
    Result.Add('used_sources', TJSONArray.Create);
    if LIsPlaylist then
      LReference := StageStudioMaterialReference(ACatalogRoot, AJobId, LReferenceMaterial, AProgress)
    else LReference := StageStudioMaterialReference(ACatalogRoot, AJobId, LMaterial, AProgress);
    if LReference <> nil then
    begin
      Result.Add('original_reference', LReference.Clone);
      if LIsPlaylist then
        Result.Arrays['sources'].Add(LReferenceMaterial.Objects['source'].Clone)
      else Result.Arrays['sources'].Add(LMaterial.Objects['source'].Clone);
    end;
    { Big Boss: one native performance supplies independently processed stems
      and the master through the same output owner as long playlist jobs. }
    LOutputWriter := TStudioInstrumentalOutput.Create(ACatalogRoot, AJobId,
      LPlan.SampleRate, LPlan.FrameCount, LConfig.Arrays['levels'], LSeed);
    LPlayer := nil;
    LStored := nil;
    try
      LPlayer := LPlan.CreatePlayer(LOutputWriter.Graph);
      LDone := 0;
      SetLength(LStems, 6);
      while LDone < LPlan.FrameCount do
      begin
        if Assigned(ACheck) then ACheck;
        LCount := Min(Int64(2048), LPlan.FrameCount - LDone);
        SetLength(LSamples, LCount * 2);
        for LRole := 0 to 5 do SetLength(LStems[LRole], LCount * 2);
        for LIndex := 0 to LCount - 1 do
        begin
          LPlayer.Process(LLeft, LRight);
          LSamples[LIndex * 2] := LLeft;
          LSamples[LIndex * 2 + 1] := LRight;
          for LRole := 0 to 5 do
          begin
            LFrame := LOutputWriter.Graph.LastOutput(StudioInstrumentalStemBuses[LRole]);
            LStems[LRole][LIndex * 2] := LFrame.Left;
            LStems[LRole][LIndex * 2 + 1] := LFrame.Right;
          end;
        end;
        LOutputWriter.Append(LSamples, LStems);
        Inc(LDone, LCount);
        ReportWork(AProgress, 'instrumental_render', wuFrames, LDone, LPlan.FrameCount);
      end;
      ReportWork(AProgress, 'instrumental_save', wuItems, 0, 1);
      LStored := LOutputWriter.Finish(AProgress);
      Result.Add('parts', LStored.Arrays['parts'].Clone);
      Result.Add('outputs', LStored.Arrays['outputs'].Clone);
    finally
      LStored.Free;
      LPlayer.Free;
      LOutputWriter.Free;
    end;
    { Persist actual per-pass symbolic decisions separately from the small API
      summary; model text and settings identify the authored material honestly. }
    for LPass := 0 to High(LGraphInfo) do
      if not LGraphInfo[LPass].IsProof then
      begin
        LTokens := LPlan.CopyPassTokens(LPass);
        LTokenArray := TJSONArray.Create;
        LPasses.Objects[LPass].Add('tokens', LTokenArray);
        for LIndex := 0 to High(LTokens) do LTokenArray.Add(LTokens[LIndex]);
      end;
    LMeta.Add('models_sha256', LModelHash);
    LMeta.Add('model_storage', 'Canonical provider text in each pass model_artifact');
    WriteStudioJSONNew(LDirectory + PathDelim + 'instrumental-plan.json', LMeta);
    Result.Add('plan_sha256', StudioTextHash(LMeta.AsJSON));
    PublishStudioInstrumental(ACatalogRoot, AJobId, ARequest, Result, LReference,
      LIsPlaylist, ACheck, AProgress);
  except
    Result.Free;
    Result := nil;
    raise;
    end;
  finally
    LReference.Free;
    LReferenceMaterial.Free;
    LLearning.Free;
    LWorkingConfig.Free;
    LMaterial.Free;
    LModel.Free; LMeta.Free; LPlan.Free; LStarter.Free;
    LCorpus.Free;
    for LRole := 0 to 2 do LInstruments[LRole].Free;
  end;
end;

end.
