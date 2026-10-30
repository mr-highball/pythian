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
program pythian_example_instrumental;

{$mode delphi}
{$H+}

uses
  Classes,
  SysUtils,
  Math,
  fpjson,
  pythian.audio,
  pythian.time,
  pythian.bus,
  pythian.echo,
  pythian.effects,
  pythian.schedule,
  pythian.percussion,
  pythian.wave.stream,
  pythian.wfc.instrumental,
  pythian.wfc.instrumental.starter,
  pythian.wfc.voices,
  pythian.wfc.percussion,
  wfc_model,
  wfc_sequence,
  wfc_sequence_text,
  wfc_music_voices_graph;

procedure Run;
var
  LOutput: String;
  LCells: Integer;
  LSeed: Cardinal;
  LTempo: Integer;
  LTonic: Integer;
  LWithDrums: Boolean;
  LStarter: TInstrumentalStarter;
  LOptions: TInstrumentalOptions;
  LPlan: TInstrumentalPlan;
  LReport: TInstrumentalReport;
  LSettings: array of TBusSettings;
  LDrums: TPercussionDefinitions;
  LHits: TPercussionHits;
  LRecipe: TPercussionPart;
  LEcho: TEchoSettings;
  LGraph: TBusGraph;
  LPlayer: TScheduledSynth;
  LFile: TFileStream;
  LSink: TStreamAudioSink;
  LWriter: TWavePcm16Writer;
  LSamples: TAudioSamples;
  LDocument: TJSONObject;
  LPassRows: TJSONArray;
  LRow: TJSONObject;
  LDependencies: TJSONArray;
  LTokens: TJSONArray;
  LStates: TJSONArray;
  LPasses: TVoiceGraphPasses;
  LPublicTokens: TWfcModelTokens;
  LStateIndices: TWfcSequenceStateIndices;
  LModel: TWfcSequenceModel;
  LMetadata: TStringStream;
  LIndex: Integer;
  LCell: Integer;
  LCount: Integer;
  LDone: Int64;
  LLeft: Double;
  LRight: Double;
begin
  if (ParamCount < 1) or (ParamCount > 6) then
  begin
    raise EAudio.Create('Usage: pythian.example.instrumental OUTPUT.wav [CELLS [SEED [BPM [TONIC_0_TO_11 [--drums]]]]]');
  end;
  LOutput := ParamStr(1);
  LCells := 64;
  LSeed := 731;
  LTempo := 120;
  LTonic := 0;
  LWithDrums := False;
  if ParamCount >= 2 then
  begin
    LCells := StrToInt(ParamStr(2));
  end;
  if ParamCount >= 3 then
  begin
    LSeed := StrToDWord(ParamStr(3));
  end;
  if ParamCount >= 4 then
  begin
    LTempo := StrToInt(ParamStr(4));
  end;
  if ParamCount >= 5 then
  begin
    LTonic := StrToInt(ParamStr(5));
  end;
  if ParamCount = 6 then
  begin
    if ParamStr(6) <> '--drums' then
    begin
      raise EAudio.Create('Optional sixth argument is --drums');
    end;
    LWithDrums := True;
  end;
  if (LCells < 1) or (LCells > 1024) or (LTempo < 20) or (LTempo > 300) then
  begin
    raise EAudio.Create('Starter supports 1..1024 cells and 20..300 BPM');
  end;
  LStarter := TInstrumentalStarter.Create(LTonic);
  LPlan := nil;
  LGraph := nil;
  LPlayer := nil;
  LFile := nil;
  LSink := nil;
  LWriter := nil;
  LModel := nil;
  LMetadata := nil;
  LDocument := TJSONObject.Create;
  try
    LOptions := DefaultInstrumentalOptions;
    LOptions.Session.CellCount := LCells;
    LOptions.Session.Seed := LSeed;
    LOptions.PercussionSeed := LSeed xor Cardinal($50455243);
    LOptions.Session.RequireObservedEnd := False;
    LOptions.Tempos[0] := MakeTempoChange(0, Round(60000000 / LTempo));
    LOptions.EffectTailFrames := Int64(LOptions.SampleRate) * 3;
    LOptions.MaterialOrigin :=
      'Authored harmony/rhythm guide and two symbolic training phrases; WFC chooses pitched parts; no WAV learning';
    LDrums := nil;
    if LWithDrums then
    begin
      LDrums := LStarter.CopyPercussion(LOptions.SampleRate);
      LOptions.MaterialOrigin := LOptions.MaterialOrigin +
        '; authored percussion models and explicit rhythm projections';
    end;
    if not TryCreateInstrumentalPlan(LStarter.Config, LStarter.CopyRoles,
      LOptions, LStarter.GuideMasks(LCells), nil, LPlan, LReport, nil, LDrums) then
    begin
      raise EAudio.Create(LReport.Detail);
    end;
    LPasses := LPlan.CopyGraph;
    LDocument.Add('material_origin', LPlan.MaterialOrigin);
    LDocument.Add('experimental', True);
    LDocument.Add('seed', Int64(LSeed));
    LDocument.Add('percussion_seed', Int64(LOptions.PercussionSeed));
    LDocument.Add('tonic_pitch_class', LTonic);
    LDocument.Add('tempo_microseconds', LOptions.Tempos[0].MicrosecondsPerQuarter);
    LDocument.Add('ticks_per_quarter', LOptions.Session.TicksPerQuarter);
    LDocument.Add('ticks_per_cell', LOptions.Session.StepTicks);
    LDocument.Add('cells', LCells);
    LDocument.Add('percussion', LWithDrums);
    LDocument.Add('sample_rate', LPlan.SampleRate);
    LDocument.Add('frame_count', LPlan.FrameCount);
    LDocument.Add('effect_tail_frames', LOptions.EffectTailFrames);
    LDocument.Add('instruments',
      'source-free polynomial saw bass, triangle harmony, square lead; primary ADSR/filter/pan; authored starter v1');
    LDocument.Add('effects', 'Harmony bus: primary default filtered echo; three-second explicit effect tail');
    LPassRows := TJSONArray.Create;
    LDocument.Add('passes', LPassRows);
    for LIndex := 0 to High(LPasses) do
    begin
      LRow := TJSONObject.Create;
      LPassRows.Add(LRow);
      LRow.Add('name', LPasses[LIndex].Name);
      LRow.Add('width', LPasses[LIndex].Width);
      LRow.Add('height', LPasses[LIndex].Height);
      LRow.Add('depth', LPasses[LIndex].Depth);
      LRow.Add('proof', LPasses[LIndex].IsProof);
      LRow.Add('graph_group', LPasses[LIndex].GroupIndex);
      if LPasses[LIndex].InputSourcePassIndex >= 0 then
      begin
        LRow.Add('pinned_input_from', LPasses[LIndex].InputSourcePassIndex);
      end;
      LDependencies := TJSONArray.Create;
      LRow.Add('depends_on', LDependencies);
      for LCell := 0 to High(LPasses[LIndex].Dependencies) do
      begin
        LDependencies.Add(LPasses[LIndex].Dependencies[LCell]);
      end;
      if not LPasses[LIndex].IsProof then
      begin
        LRow.Add('public_tokens', LPasses[LIndex].PublicTokenCount);
        LRow.Add('latent_states', LPasses[LIndex].StateCount);
        LModel := LPlan.CopyModel(LPasses[LIndex].Name);
        LRow.Add('model', EncodeWfcSequenceText(LModel));
        FreeAndNil(LModel);
        LTokens := TJSONArray.Create;
        LStates := TJSONArray.Create;
        LRow.Add('tokens', LTokens);
        LRow.Add('states', LStates);
        LPublicTokens := LPlan.CopyPassTokens(LIndex);
        LStateIndices := LPlan.CopyPassStates(LIndex);
        for LCell := 0 to High(LPublicTokens) do
        begin
          LTokens.Add(LPublicTokens[LCell]);
          LStates.Add(LStateIndices[LCell]);
        end;
      end;
    end;
    if LWithDrums then
    begin
      LTokens := TJSONArray.Create;
      LDocument.Add('percussion_recipes', LTokens);
      for LIndex := 0 to 2 do
      begin
        LRecipe := LPlan.CopyPercussionPart(LIndex);
        LRow := TJSONObject.Create;
        LTokens.Add(LRow);
        LRow.Add('name', LRecipe.Name);
        LRow.Add('kind', Ord(LRecipe.Settings.Kind));
        LRow.Add('origin', LRecipe.Origin);
        LRow.Add('gm_key', PercussionKey(LRecipe.Settings.Kind));
        LRow.Add('output_bus', LRecipe.OutputBus);
        LRow.Add('gain', LRecipe.Settings.Gain);
        LRow.Add('pan', LRecipe.Settings.Pan);
        LRow.Add('gate_seconds', LRecipe.Settings.GateSeconds);
        LRow.Add('release_seconds', LRecipe.Settings.ReleaseSeconds);
        LRow.Add('physical_tone_hz', LRecipe.Settings.ToneHz);
        LRow.Add('cutoff_hz', LRecipe.Settings.CutoffHz);
        LRow.Add('hit_weight', LRecipe.HitWeight);
      end;
      LTokens := TJSONArray.Create;
      LDocument.Add('percussion_hits', LTokens);
      LHits := LPlan.CopyPercussionHits;
      for LIndex := 0 to High(LHits) do
      begin
        LRow := TJSONObject.Create;
        LTokens.Add(LRow);
        LRow.Add('part', LHits[LIndex].Part);
        LRow.Add('cell', LHits[LIndex].Cell);
        LRow.Add('velocity', LHits[LIndex].Velocity);
        LRow.Add('start_frame', LHits[LIndex].StartFrame);
        LRow.Add('gate_frames', LHits[LIndex].GateFrames);
      end;
    end;
    SetLength(LSettings, LPlan.RoleCount + 1);
    for LIndex := 0 to High(LSettings) do
    begin
      LSettings[LIndex] := DefaultBusSettings;
      LSettings[LIndex].SmoothingSeconds := 0;
    end;
    LGraph := TBusGraph.Create(LPlan.SampleRate, LSettings);
    for LIndex := 0 to LPlan.RoleCount - 1 do
    begin
      LGraph.AddSend(LIndex, LPlan.RoleCount, stPostFader, 1, 0);
    end;
    LEcho := DefaultEchoSettings(LPlan.SampleRate);
    LGraph.AddEffect(1, TEchoEffect.Create(LPlan.SampleRate, LEcho));
    if LWithDrums then
    begin
      LGraph.AddEffect(LPlan.RoleCount, TLimiterEffect.Create(LPlan.SampleRate, -1, 0.08));
    end;
    LPlayer := LPlan.CreatePlayer(LGraph);
    LFile := TFileStream.Create(LOutput, fmCreate);
    LSink := TStreamAudioSink.Create(LFile);
    LWriter := TWavePcm16Writer.Create(LSink, LPlan.SampleRate, 2, LPlan.FrameCount);
    LDone := 0;
    while LDone < LPlan.FrameCount do
    begin
      LCount := Min(997, LPlan.FrameCount - LDone);
      SetLength(LSamples, LCount * 2);
      for LIndex := 0 to LCount - 1 do
      begin
        LPlayer.Process(LLeft, LRight);
        LSamples[LIndex * 2] := LLeft;
        LSamples[LIndex * 2 + 1] := LRight;
      end;
      LWriter.AppendSamples(LSamples);
      Inc(LDone, LCount);
    end;
    LWriter.Finish;
    FreeAndNil(LWriter);
    FreeAndNil(LSink);
    FreeAndNil(LFile);
    LMetadata := TStringStream.Create(LDocument.FormatJSON);
    LFile := TFileStream.Create(LOutput + '.json', fmCreate);
    LFile.CopyFrom(LMetadata, 0);
    WriteLn('Instrumental synthesis: ', LPlan.RoleCount, ' roles; ', LCells, ' cells; ',
      Length(LPasses), ' actual passes; ', LPlan.FrameCount, ' stereo frames.');
    WriteLn('Experimental authored starter; no training-mix grains or source WAVs.');
  finally
    LMetadata.Free;
    LWriter.Free;
    LSink.Free;
    LFile.Free;
    LPlayer.Free;
    LGraph.Free;
    LModel.Free;
    LPlan.Free;
    LStarter.Free;
    LDocument.Free;
  end;
end;

begin
  try
    Run;
  except
    on LException: Exception do
    begin
      WriteLn(StdErr, LException.ClassName, ': ', LException.Message);
      ExitCode := 1;
    end;
  end;
end.
