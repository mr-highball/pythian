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
  pythian.instrument, pythian.instrument.recipe, pythian.synth, pythian.oscillator, pythian.schedule,
  pythian.music.pattern, pythian.music.sound, pythian.music.controls, pythian.music.form,
  pythian.wfc.instrumental.controls,
  pythian.wfc.instrumental, pythian.wfc.instrumental.starter,
  pythian.wfc.percussion, pythian.wfc.voices, pythian.wfc.musical.context,
  pythian.wfc.musical.corpus, wfc_music_voices_graph,
  wfc_model, wfc_sequence, wfc_sequence_text,
  pythian.tools.studio.jobs, pythian.tools.studio.instrumental.config,
  pythian.tools.studio.instrumental.settings,
  pythian.tools.studio.material, pythian.tools.studio.material.reference,
  pythian.tools.studio.playlist.learning,
  pythian.tools.studio.instrumental.output,
  pythian.tools.studio.instrumental.stream, pythian.tools.studio.form,
  pythian.wfc.instrumental.stream, pythian.tools.studio.sounds,
  pythian.tools.json, pythian.wfc.semantic.style, pythian.tools.studio.styles;

function RunSavedStyle(const ACatalogRoot, AJobId: String;
  const ARequest: TJSONObject; const ACheck: TStudioInstrumentalCheck;
  const AProgress: TWorkProgressCallback): TJSONObject;
var
  LStyle: TSemanticStyle;
  LDefinition: TSemanticStyleDefinition;
  LMaterial: TStudioStreamMaterial;
  LRoles: TInstrumentalRoles;
  LSettings, LDesign, LSource: TJSONObject;
  LRecipes: TJSONArray;
  I: Integer;
begin
  LStyle := nil;
  LSettings := nil;
  LSource := ARequest.Objects['style_source'];
  try
    if Assigned(ACheck) then ACheck;
    ReportWork(AProgress, 'instrumental_prepare', wuItems, 0, 1);
    LStyle := DecodeSemanticStyle(ReadStudioStyleBytes(ACatalogRoot,
      LSource.Strings['sha256'], AProgress), nil, nil, AProgress);
    LDefinition := LStyle.CopyDefinition(AProgress);
    if not LDefinition.Instrumental.Enabled or
      (LDefinition.Instrumental.SampleRate <> StudioInstrumentalRate) or
      (Length(LDefinition.Instrumental.Instruments) <> 3) or
      (Length(LDefinition.Instrumental.Percussion) <> 3) then
      raise EAudio.Create('This saved style needs the Studio three-voice/three-drum layout at24kHz');
    LSettings := TJSONObject(LSource.Objects['settings'].Clone);
    { The retained mix already includes its original level controls. Apply it
      once; changing the performance length/seed never changes frozen learning. }
    LSettings.Delete('levels');
    LSettings.Add('levels', TJSONArray.Create([100, 100, 100, 100, 100, 100]));
    LSettings.Delete('sound_design');
    LDesign := TJSONObject.Create(['version', 1]);
    LSettings.Add('sound_design', LDesign);
    LRecipes := TJSONArray.Create;
    LDesign.Add('instruments', LRecipes);
    for I := 0 to High(LDefinition.Instrumental.Instruments) do
      LRecipes.Add(EncodeStudioInstrumentRecipe(LDefinition.Instrumental.Instruments[I]));
    LDesign.Add('mix', EncodeStudioMixRecipe(LDefinition.Instrumental.Mix));
    LMaterial := Default(TStudioStreamMaterial);
    LMaterial.Style := LStyle;
    LMaterial.SavedStyle := LSource;
    LMaterial.StyleOptions := LDefinition.Instrumental.Options;
    LMaterial.Config := SemanticStyleVoiceLayout(LDefinition);
    LMaterial.ContextBinding := LDefinition.Instrumental.Options.ContextBinding;
    LMaterial.Form := LDefinition.Instrumental.Form;
    LMaterial.TempoMicroseconds := LDefinition.Instrumental.Options.TempoMicroseconds;
    LMaterial.Origin := 'Saved style: ' + LSource.Strings['name'] + '; ' + LDefinition.Instrumental.Origin;
    LMaterial.SoundRecipes := LDefinition.Instrumental.Instruments;
    SetLength(LMaterial.Models, Length(LDefinition.Providers));
    SetLength(LMaterial.Labels, Length(LDefinition.Providers));
    for I := 0 to High(LDefinition.Providers) do
    begin
      LMaterial.Models[I] := LDefinition.Providers[I].ModelText;
      LMaterial.Labels[I] := LDefinition.Providers[I].Contract.Name;
      if I >= Length(LMaterial.Config.Voices) + 3 then
        LMaterial.Labels[I] := 'percussion:' + LMaterial.Labels[I];
    end;
    SetLength(LRoles, Length(LMaterial.Config.Voices));
    for I := 0 to High(LRoles) do
    begin
      LRoles[I].Name := LDefinition.Providers[I + 2].Contract.RoleId;
      LRoles[I].InstrumentId := String(LDefinition.Instrumental.Instruments[I].Id);
      LRoles[I].OutputBus := I;
    end;
    if Assigned(ACheck) then ACheck;
    Result := RunStudioInstrumentalStream(ACatalogRoot, AJobId, ARequest,
      LSettings, nil, LMaterial, LRoles, LDefinition.Instrumental.Percussion, ACheck, AProgress);
  finally
    LSettings.Free;
    LStyle.Free;
  end;
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
  LInstruments: array[0..2] of TRecipeInstrument;
  LSoundRecipes: TInstrumentRecipes;
  LZones: TInstrumentZones;
  LDrums: TPercussionDefinitions;
  LConfig, LMeta, LRow: TJSONObject;
  LPasses, LDependencies: TJSONArray;
  LRecipeRows: TJSONArray;
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
  LStreamMaterial: TStudioStreamMaterial;
  LHasForm: Boolean;
  LForm: TMusicForm;
  procedure SetStreamModels;
  var
    I, LAt: Integer;
    procedure AddModel(const AName: String; const AModel: TWfcSequenceModel);
    begin
      LAt := Length(LStreamMaterial.Models);
      SetLength(LStreamMaterial.Models, LAt + 1);
      SetLength(LStreamMaterial.Labels, LAt + 1);
      LStreamMaterial.Models[LAt] := EncodeWfcSequenceText(AModel);
      LStreamMaterial.Labels[LAt] := AName;
    end;
  begin
    LStreamMaterial.Models := nil;
    LStreamMaterial.Labels := nil;
    AddModel('harmony', LGraphConfig.HarmonyModel);
    AddModel('rhythm', LGraphConfig.RhythmModel);
    for I := 0 to High(LRoles) do AddModel('voice:' + LRoles[I].Name, LGraphConfig.Voices[I].Model);
    if LStreamMaterial.Context <> nil then
      AddModel(MusicalContextPassName, LStreamMaterial.Context);
    for I := 0 to High(LDrums) do AddModel('percussion:' + LDrums[I].Name, LDrums[I].Model);
  end;
begin
  if ARequest.Strings['kind'] = 'instrumental_style' then
    Exit(RunSavedStyle(ACatalogRoot, AJobId, ARequest, ACheck, AProgress));
  LConfig := ARequest.Objects['instrumental'];
  ValidateStudioInstrumentalConfig(LConfig);
  LHasForm := LConfig.Find('form') <> nil;
  LForm := DecodeStudioForm(LConfig.Find('form'));
  LSound := Default(TMusicalSound);
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
      AdmitStudioInstrumentalOutput(ACatalogRoot, ARequest.Int64s['duration_ms'],
        StudioSoundTailFrames(LConfig, StudioInstrumentalRate));
      LCache := ACacheRoot;
      if LCache = '' then LCache := SysUtils.GetEnvironmentVariable('PYTHIAN_STUDIO_LEARNING_CACHE_ROOT');
      if LCache = '' then LCache := IncludeTrailingPathDelimiter(ACatalogRoot) +
        'studio' + PathDelim + 'musical-cache';
      LCorpus := LearnStudioPlaylist(ACatalogRoot, ALibraryRoot, LCache, AJobId,
        ARequest.Objects['project_snapshot'].Objects['playlist'], LLearning, AProgress,
        ALibraryProgress);
      LModelArtifact := StudioMusicalVocabulary(LCorpus, True, AProgress, LLearning.Arrays['audio_sources']);
      try
        WriteStudioJSONNew(LDirectory + PathDelim + 'musical-vocabulary.json', LModelArtifact);
      finally
        LModelArtifact.Free;
      end;
      LLearning.Objects['vocabulary'].Add('artifact', 'musical-vocabulary.json');
      LOrigin := StudioPlaylistOrigin;
      LRecipeHash := StudioTextHash(StudioPlaylistLearningPolicy +
        ARequest.Objects['project_snapshot'].Objects['playlist'].AsJSON);
      LWorkingConfig := TJSONObject(LConfig.Clone);
      LConfig := LWorkingConfig;
      LTempo := LLearning.Integers['output_tempo_microseconds'];
      LConfig.Integers['tempo_bpm'] := Round(60000000 / LTempo);
      if not LHasForm then LConfig.Integers['cells'] := 16;
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
    if LConfig.Find('sound_design') <> nil then
    begin
      LPlaylistHasSound := False;
      LSoundRole := -1;
    end;
    SetLength(LSoundRecipes, 3);
    for LRole := 0 to 2 do
    begin
      if LIsPlaylist or LHasForm then
      begin
        LZones := StudioPlaylistInstrumentZones;
        LRoles[LRole].OutputBus := LRole;
      end
      else LZones := LRoles[LRole].Instrument.CopyZones;
      LInstruments[LRole] := CreateStudioRecipeInstrument(LZones,
        LConfig.Arrays['instruments'].Strings[LRole], LSound,
        (LRole = LSoundRole) or LPlaylistHasSound, StudioInstrumentalRate, LConfig, LRole);
      LRoles[LRole].Instrument := LInstruments[LRole].Instrument;
      LSoundRecipes[LRole] := LInstruments[LRole].CopyRecipe;
      if LIsPlaylist then
        LRoles[LRole].InstrumentId := 'playlist-primary-v1-' + LConfig.Arrays['instruments'].Strings[LRole]
      else if LHasForm then
        LRoles[LRole].InstrumentId := 'structured-primary-v1-' + LConfig.Arrays['instruments'].Strings[LRole]
      else LRoles[LRole].InstrumentId := 'starter-' + LConfig.Arrays['instruments'].Strings[LRole];
      if LConfig.Find('sound_design') <> nil then
      begin
        LRow := EncodeStudioInstrumentRecipe(LSoundRecipes[LRole]);
        try
          LRoles[LRole].InstrumentId := 'operator-patch-v1-' +
            HashNativeText(WriteNativeJSON(LRow, 262144));
        finally
          LRow.Free;
        end;
      end;
      if LRole = LSoundRole then
        LRoles[LRole].InstrumentId := LRoles[LRole].InstrumentId + '-cutoff' +
          IntToStr(LSound.CutoffHz) + '-sustain' + IntToStr(LSound.SustainPercent);
    end;
    LOptions := DefaultInstrumentalOptions;
    LOptions.SampleRate := StudioInstrumentalRate;
    if LConfig.Find('sound_design') <> nil then
    begin
      LOptions.EffectTailFrames := StudioSoundTailFrames(LConfig, StudioInstrumentalRate);
    end;
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
      LStreamMaterial := Default(TStudioStreamMaterial);
      LStreamMaterial.Corpus := LCorpus;
      LStreamMaterial.SoundRecipes := LSoundRecipes;
      LStreamMaterial.Config := CopyWfcMusicVoicesGraphConfig(LGraphConfig);
      LStreamMaterial.Context := LContextModel;
      LStreamMaterial.ContextBinding := icbAllRoles;
      LStreamMaterial.Models := LCorpus.CopyModelTexts(AProgress);
      LStreamMaterial.Labels := LCorpus.CopyProviderNames;
      LStreamMaterial.Form := LForm;
      LStreamMaterial.TempoMicroseconds := LTempo;
      LStreamMaterial.Origin := LOrigin;
      LStreamMaterial.Reference := LReferenceMaterial;
      LStreamMaterial.HasSound := LPlaylistHasSound;
      LStreamMaterial.Sound := LSound;
      LStreamMaterial.SoundPart := -1;
      Result := RunStudioInstrumentalStream(ACatalogRoot, AJobId, ARequest, LConfig,
        LLearning, LStreamMaterial, LRoles, LDrums, ACheck, AProgress);
      Exit;
    end
    else
    begin
      LDrums := LStarter.CopyPercussion(LOptions.SampleRate);
      if not LHasForm then LBaseMasks := LStarter.GuideMasks(LOptions.Session.CellCount);
    end;
    if LHasForm then
    begin
      LStreamMaterial := Default(TStudioStreamMaterial);
      LStreamMaterial.SoundRecipes := LSoundRecipes;
      LStreamMaterial.Config := CopyWfcMusicVoicesGraphConfig(LGraphConfig);
      LStreamMaterial.Context := LContextModel;
      LStreamMaterial.ContextBinding := icbDrivenRole;
      LStreamMaterial.Form := LForm;
      LStreamMaterial.TempoMicroseconds := Round(60000000 / LConfig.Integers['tempo_bpm']);
      LStreamMaterial.Origin := LOrigin + '; caller-authored section structure';
      LStreamMaterial.Reference := LMaterial;
      LStreamMaterial.HasSound := LSoundRole >= 0;
      LStreamMaterial.Sound := LSound;
      LStreamMaterial.SoundPart := LSoundRole;
      if LConfig.Find('controls') <> nil then
      begin
        LMusicalControls := DecodeStudioMusicalControls(LConfig.Objects['controls']);
        for LRole := 0 to 2 do
        begin
          LStreamMaterial.Config.Voices[LRole].MinPitch := Max(LGraphConfig.Voices[LRole].MinPitch,
            LMusicalControls[LRole].MinimumPitch);
          LStreamMaterial.Config.Voices[LRole].MaxPitch := Min(LGraphConfig.Voices[LRole].MaxPitch,
            LMusicalControls[LRole].MaximumPitch);
        end;
      end;
      if (LConfig.Find('controls') = nil) or LConfig.Objects['controls'].Booleans['guide'] then
      begin
        LStreamMaterial.DomainProvider := LStarter.GuideMasksRange;
        LStreamMaterial.ContextBinding := icbAllRoles;
        if Length(LPattern) = 0 then LStreamMaterial.Context := nil;
      end;
      SetStreamModels;
      FreeAndNil(Result);
      Result := RunStudioInstrumentalStream(ACatalogRoot, AJobId, ARequest, LConfig,
        nil, LStreamMaterial, LRoles, LDrums, ACheck, AProgress);
      Exit;
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
    LRecipeRows := TJSONArray.Create;
    Result.Add('instrument_recipes', LRecipeRows);
    for LRole := 0 to 2 do
    begin
      LRecipeRows.Add(EncodeStudioInstrumentRecipe(LSoundRecipes[LRole]));
    end;
    if LConfig.Find('sound_design') <> nil then
    begin
      Result.Add('sound_design_origin', 'operator_selected');
    end;
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
    if ARequest.Find('comparison_before') <> nil then
      Result.Add('before', ARequest.Objects['comparison_before'].Clone);
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
      LPlan.SampleRate, LPlan.FrameCount, LConfig.Arrays['levels'], LSeed,
      StudioSoundMix(LConfig, StudioInstrumentalRate));
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
