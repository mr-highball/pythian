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

uses fpjson, pythian.progress;

type
  TStudioInstrumentalCheck = procedure of object;

function RunStudioInstrumental(const ACatalogRoot, AJobId: String;
  const ARequest: TJSONObject; const ACheck: TStudioInstrumentalCheck;
  const AProgress: TWorkProgressCallback): TJSONObject;

implementation

uses Classes, SysUtils, Math,
  pythian.audio, pythian.time, pythian.bus, pythian.effects,
  pythian.instrument, pythian.synth, pythian.oscillator, pythian.schedule,
  pythian.wave.stream, pythian.music.pattern, pythian.music.sound, pythian.music.controls,
  pythian.wfc.instrumental.controls,
  pythian.wfc.instrumental, pythian.wfc.instrumental.starter,
  pythian.wfc.percussion, pythian.wfc.voices, pythian.wfc.musical.context,
  wfc_model, wfc_sequence, wfc_sequence_text,
  pythian.tools.studio.jobs, pythian.tools.studio.instrumental.config,
  pythian.tools.studio.material, pythian.tools.studio.material.reference,
  pythian.tools.listen.catalog;

const
  CPartNames: array[0..5] of String = ('Bass', 'Harmony', 'Lead', 'Kick', 'Snare', 'Hat');

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
  const AProgress: TWorkProgressCallback): TJSONObject;
var
  LStarter: TInstrumentalStarter;
  LPlan: TInstrumentalPlan;
  LOptions: TInstrumentalOptions;
  LReport: TInstrumentalReport;
  LRoles: TInstrumentalRoles;
  LInstruments: array[0..2] of TInstrument;
  LZones: TInstrumentZones;
  LDrums: TPercussionDefinitions;
  LConfig, LMeta, LRow, LOutput, LAsset, LProvenance: TJSONObject;
  LQueue, LItem, LSpec, LChoice, LRange, LStaged, LPublished: TJSONObject;
  LPasses, LParts, LDependencies, LAssets: TJSONArray;
  LGraphInfo: TVoiceGraphPasses;
  LModel: TWfcSequenceModel;
  LTokens: TWfcModelTokens;
  LTokenArray: TJSONArray;
  LModelText, LPath, LDirectory, LModelHash, LMaterialHash, LId: String;
  LSeed: Cardinal;
  LRole, LIndex, LPass, LRender, LCount: Integer;
  LDone: Int64;
  LSettings: array[0..6] of TBusSettings;
  LGraph: TBusGraph;
  LPlayer: TScheduledSynth;
  LFile: TFileStream;
  LSink: TStreamAudioSink;
  LWriter: TWavePcm16Writer;
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
begin
  LConfig := ARequest.Objects['instrumental'];
  ValidateStudioInstrumentalConfig(LConfig);
  LSeed := ARequest.Arrays['seeds'].Integers[0];
  LDirectory := StudioJobDirectory(ACatalogRoot, AJobId);
  LStarter := nil; LPlan := nil; LModel := nil;
  LQueue := nil; LMeta := nil;
  LMaterial := nil;
  LReference := nil;
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
    if ARequest.Objects['project_snapshot'].Find('musical_material') <> nil then
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
    LStarter := TInstrumentalStarter.Create(LConfig.Integers['tonic'],
      LMode = 'natural_minor', LPattern, LPatternRole, AProgress);
    LRoles := LStarter.CopyRoles;
    for LRole := 0 to 2 do
    begin
      LZones := LRoles[LRole].Instrument.CopyZones;
      for LIndex := 0 to High(LZones) do
      begin
        LZones[LIndex].Voice.Shape := Shape(LConfig.Arrays['instruments'].Strings[LRole]);
        if LRole = LSoundRole then
          LZones[LIndex].Voice := ApplyMusicalSound(LZones[LIndex].Voice, LSound, StudioInstrumentalRate);
      end;
      LInstruments[LRole] := TInstrument.Create(LZones);
      LRoles[LRole].Instrument := LInstruments[LRole];
      LRoles[LRole].InstrumentId := 'starter-' + LConfig.Arrays['instruments'].Strings[LRole];
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
    LDrums := LStarter.CopyPercussion(LOptions.SampleRate);
    LBaseMasks := LStarter.GuideMasks(LOptions.Session.CellCount);
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
          LCompiled := CompileInstrumentalControls(LStarter.Config, LOptions.Session.CellCount,
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
    if not TryCreateInstrumentalPlan(LStarter.Config, LRoles, LOptions,
      LCompiled.Masks, LCompiled.Preferences, LPlan, LReport,
      AProgress, LDrums, LStarter.ContextModel) then
      raise EAudio.Create('Instrumental graph rejected: ' + LReport.Detail);
    LMeta := TJSONObject.Create;
    LMeta.Add('material_origin', LOrigin);
    LMeta.Add('settings', LConfig.Clone);
    LMeta.Objects['settings'].Strings['mode'] := LMode;
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
      if LStarter.ContextModel <> nil then
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
    LReference := StageStudioMaterialReference(ACatalogRoot, AJobId, LMaterial, AProgress);
    if LReference <> nil then
    begin
      Result.Add('original_reference', LReference.Clone);
      Result.Arrays['sources'].Add(LMaterial.Objects['source'].Clone);
    end;
    LParts := TJSONArray.Create;
    Result.Add('parts', LParts);
    LOutput := nil;
    { Big Boss: seven fresh primary scheduler/bus performances of ONE immutable
      plan. No second renderer or inference; bounded WAV blocks stay on the host.
      Dry stems have the saved mix level baked in; mute/solo never changes notes. }
    for LRender := 0 to 6 do
    begin
      LGraph := nil; LPlayer := nil; LFile := nil; LSink := nil; LWriter := nil;
      try
        for LRole := 0 to 6 do
        begin
          LSettings[LRole] := Default(TBusSettings);
          if LRole = 6 then LSettings[LRole].Gain := 0.7
          else if (LRender = 6) or (LRender = LRole) then
            LSettings[LRole].Gain := LConfig.Arrays['levels'].Integers[LRole] / 100;
        end;
        LGraph := TBusGraph.Create(LPlan.SampleRate, LSettings);
        for LRole := 0 to 5 do LGraph.AddSend(LRole, 6, stPostFader, 1, 0);
        LGraph.AddEffect(6, TLimiterEffect.Create(LPlan.SampleRate, -1, 0.08));
        LPlayer := LPlan.CreatePlayer(LGraph);
        LPath := 'part-' + IntToStr(LRender) + '.wav';
        LFile := TFileStream.Create(LDirectory + PathDelim + LPath, fmCreate);
        LSink := TStreamAudioSink.Create(LFile);
        LWriter := TWavePcm16Writer.Create(LSink, LPlan.SampleRate, 2, LPlan.FrameCount);
        LDone := 0;
        while LDone < LPlan.FrameCount do
        begin
          if Assigned(ACheck) then ACheck;
          LCount := Min(Int64(4096), LPlan.FrameCount - LDone);
          SetLength(LSamples, LCount * 2);
          for LIndex := 0 to LCount - 1 do
          begin
            LPlayer.Process(LLeft, LRight);
            LSamples[LIndex * 2] := LLeft;
            LSamples[LIndex * 2 + 1] := LRight;
          end;
          LWriter.AppendSamples(LSamples);
          Inc(LDone, LCount);
          ReportWork(AProgress, 'instrumental_render', wuFrames,
            Int64(LRender) * LPlan.FrameCount + LDone, 7 * LPlan.FrameCount);
        end;
        LWriter.Finish;
      finally
        LWriter.Free; LSink.Free; LFile.Free; LPlayer.Free; LGraph.Free;
      end;
      ReportWork(AProgress, 'instrumental_publish', wuItems, LRender, 7);
      LStaged := StageListeningAsset(ACatalogRoot, LDirectory + PathDelim + LPath);
      try
        LRow := TJSONObject.Create;
        LRow.Add('relative_file', LPath);
        LRow.Add('wav_sha256', LStaged.Strings['sha256']);
        LRow.Add('wav_bytes', LStaged.Int64s['bytes']);
        LRow.Add('sample_rate', LPlan.SampleRate);
        LRow.Add('channels', 2);
        LRow.Add('frame_count', LPlan.FrameCount);
        LRow.Add('seed', Int64(LSeed));
        LRow.Add('status', 'verified');
        if LRender < 6 then
        begin
          LRow.Add('name', CPartNames[LRender]);
          LRow.Add('part_index', LRender);
          LParts.Add(LRow);
        end
        else
        begin
          LOutput := LRow;
          Result.Add('outputs', TJSONArray.Create([LOutput]));
        end;
      finally
        LStaged.Free;
      end;
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
    LMeta.Add('models', LModelText);
    WriteStudioJSONNew(LDirectory + PathDelim + 'instrumental-plan.json', LMeta);
    Result.Add('plan_sha256', StudioTextHash(LMeta.AsJSON));
    LId := 'studio_' + AJobId + '_0';
    LOutput.Add('listening_request_id', LId);
    LQueue := TJSONObject.Create;
    LQueue.Add('version', 1);
    LItem := TJSONObject.Create;
    LQueue.Add('items', TJSONArray.Create([LItem]));
    LItem.Add('id', LId);
    LItem.Add('task_id', 'NS-6_instrumental-studio_01');
    LItem.Add('kind', 'single');
    LItem.Add('question', 'Do these instruments work together as music you want to develop?');
    if LReference <> nil then
    begin
      LItem.Strings['kind'] := 'pair';
      LItem.Strings['question'] := 'Do the synthesized parts carry musical qualities you want from this original?';
    end;
    LAssets := TJSONArray.Create;
    LItem.Add('assets', LAssets);
    LAsset := TJSONObject.Create;
    LAssets.Add(LAsset);
    LAsset.Add('id', 'audition'); LAsset.Add('storage', 'listening');
    LAsset.Add('role', 'generated');
    LAsset.Add('sha256', LOutput.Strings['wav_sha256']);
    LAsset.Add('sample_rate', LPlan.SampleRate); LAsset.Add('channels', 2);
    LAsset.Add('frames', LPlan.FrameCount); LAsset.Add('bytes', LOutput.Int64s['wav_bytes']);
    LProvenance := TJSONObject.Create;
    LAsset.Add('provenance', LProvenance);
    LProvenance.Add('material_sha256', LMaterialHash);
    LProvenance.Add('material_origin', LOrigin);
    LProvenance.Add('model_sha256', LModelHash);
    LProvenance.Add('policy_sha256', StudioTextHash('pythian instrumental starter studio v1'));
    LProvenance.Add('parameter_sha256', ARequest.Strings['request_sha256']);
    LProvenance.Add('split', 'development'); LProvenance.Add('seed', Int64(LSeed));
    LRange := TJSONObject.Create;
    LItem.Add('ranges', TJSONArray.Create([LRange]));
    LRange.Add('asset_id', 'audition'); LRange.Add('start_frame', 0);
    LRange.Add('end_frame', LPlan.FrameCount);
    if LReference <> nil then
    begin
      LAsset := TJSONObject.Create;
      LAssets.Add(LAsset);
      LAsset.Add('id', 'original_reference');
      LAsset.Add('storage', 'listening');
      LAsset.Add('role', 'reference');
      LAsset.Add('sha256', LReference.Strings['wav_sha256']);
      LAsset.Add('sample_rate', LReference.Integers['sample_rate']);
      LAsset.Add('channels', LReference.Integers['channels']);
      LAsset.Add('frames', LReference.Int64s['frame_count']);
      LAsset.Add('bytes', LReference.Int64s['wav_bytes']);
      LProvenance := TJSONObject.Create;
      LAsset.Add('provenance', LProvenance);
      LProvenance.Add('source_sha256', LReference.Strings['wav_sha256']);
      LProvenance.Add('source_group', LReference.Strings['source_group']);
      LProvenance.Add('clock_id', LReference.Strings['clock_id']);
      LProvenance.Add('partition', LReference.Strings['partition']);
      LRange := TJSONObject.Create;
      LItem.Arrays['ranges'].Add(LRange);
      LRange.Add('asset_id', 'original_reference');
      LRange.Add('start_frame', 0);
      LRange.Add('end_frame', LReference.Int64s['frame_count']);
    end;
    LSpec := TJSONObject.Create; LItem.Add('answer_spec', LSpec);
    LChoice := TJSONObject.Create; LSpec.Add('choices', TJSONArray.Create([LChoice]));
    LSpec.Add('scores', TJSONArray.Create);
    LChoice.Add('id', 'instrumental_fit');
    LChoice.Add('values', TJSONArray.Create(['yes', 'no', 'unknown']));
    WriteStudioJSONNew(LDirectory + PathDelim + 'listening-publication.json', LQueue);
    if Assigned(ACheck) then ACheck;
    LPublished := AppendListeningQueue(ACatalogRoot, LDirectory + PathDelim + 'listening-publication.json');
    LPublished.Free;
    Result.Add('publication_status', 'published');
    WriteStudioJSONNew(LDirectory + PathDelim + 'result.json', Result);
  except
    Result.Free;
    Result := nil;
    raise;
    end;
  finally
    LReference.Free;
    LMaterial.Free;
    LModel.Free; LMeta.Free; LQueue.Free; LPlan.Free; LStarter.Free;
    for LRole := 0 to 2 do LInstruments[LRole].Free;
  end;
end;

end.
