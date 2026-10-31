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
unit pythian.tools.studio.reperform;

{$mode delphi}
{$H+}

interface

uses fpjson, pythian.progress, pythian.tools.studio.instrumental.publication;

function RunStudioReperformance(const ACatalogRoot, AJobId: String;
  const ARequest: TJSONObject; const ACheck: TInstrumentalWorkCheck;
  const AProgress: TWorkProgressCallback): TJSONObject;

implementation

uses Classes, SysUtils, pythian.audio, pythian.bus, pythian.time,
  pythian.instrument, pythian.percussion, pythian.music.sound,
  pythian.music.stream, pythian.music.replay,
  pythian.tools.studio.jobs, pythian.tools.studio.decisions,
  pythian.tools.studio.instrumental.config, pythian.tools.studio.instrumental.output;

procedure Need(const AValue: Boolean; const AMessage: String);
begin
  if not AValue then raise EAudio.Create(AMessage);
end;

function RunStudioReperformance(const ACatalogRoot, AJobId: String;
  const ARequest: TJSONObject; const ACheck: TInstrumentalWorkCheck;
  const AProgress: TWorkProgressCallback): TJSONObject;
var
  LParent, LRoot, LMeta, LSettings, LReplayMeta, LStored, LResult: TJSONObject;
  LParentResult, LRootResult, LDecisions, LRow: TJSONObject;
  LFile: TFileStream;
  LOutput: TStudioInstrumentalOutput;
  LReplay: TMusicDecisionReplay;
  LBindings: TInstrumentStreamBindings;
  LOptions: TInstrumentStreamOptions;
  LInstruments: array[0..2] of TInstrument;
  LDrums: array[0..2] of TPercussionInstrument;
  LSound: TMusicalSound;
  LDrumSettings: TPercussionSettings;
  LMaster: TAudioSamples;
  LStems: TBusSampleBlocks;
  LRootId, LRootPlan, LPlanHash: String;
  LHasSound: Boolean;
  I: Integer;
begin
  Result := nil;
  LParent := nil;
  LRoot := nil;
  LMeta := nil;
  LSettings := nil;
  LReplayMeta := nil;
  LStored := nil;
  LResult := nil;
  LFile := nil;
  LOutput := nil;
  LReplay := nil;
  FillChar(LInstruments, SizeOf(LInstruments), 0);
  FillChar(LDrums, SizeOf(LDrums), 0);
  try
    ReportWork(AProgress, 'instrumental_prepare', wuItems, 0, 1);
    LParent := ReadStudioSoundParent(ACatalogRoot, ARequest);
    LParentResult := LParent.Objects['results'];
    LRootId := ARequest.Strings['replay_source_job_id'];
    LRootPlan := ARequest.Strings['replay_source_plan_sha256'];
    LRoot := ReadStudioJob(ACatalogRoot, LRootId);
    Need((LRoot.Strings['kind'] = 'instrumental_generate') and
      (LRoot.Strings['status'] = 'completed'), 'Saved note source is unavailable');
    LRootResult := LRoot.Objects['results'];
    Need((LRootResult.Strings['plan_sha256'] = LRootPlan) and
      (LRootResult.Objects['decisions'].AsJSON = LParentResult.Objects['decisions'].AsJSON),
      'Saved notes differ from the previous track');
    LMeta := ReadStudioJSON(StudioJobDirectory(ACatalogRoot, LRootId) +
      PathDelim + 'instrumental-stream-completed.json');
    Need((LMeta.Strings['format'] = 'pythian.studio.instrumental.stream.v1') and
      (StudioTextHash(LMeta.AsJSON) = LRootPlan), 'Saved musical plan differs from its completed track');
    Need((LMeta.Arrays['roles'].Count = 3) and (LMeta.Arrays['percussion'].Count = 3),
      'This sound editor requires the three pitched parts and three drum parts');
    AdmitStudioInstrumentalOutput(ACatalogRoot, ARequest.Int64s['duration_ms']);
    LDecisions := LParentResult.Objects['decisions'];
    LFile := OpenStudioDecisionJournal(ACatalogRoot, LDecisions, AProgress);
    ReportWork(AProgress, 'instrumental_plan_begin', wuItems, 0, 1);
    LSettings := TJSONObject(LParentResult.Objects['settings'].Clone);
    LSettings.Delete('instruments');
    LSettings.Add('instruments', ARequest.Arrays['instruments'].Clone);
    LSound := Default(TMusicalSound);
    LHasSound := LMeta.Find('applied_sound') <> nil;
    if LHasSound then
    begin
      LSound.CutoffHz := LMeta.Objects['applied_sound'].Integers['cutoff_hz'];
      LSound.SustainPercent := LMeta.Objects['applied_sound'].Integers['sustain_percent'];
    end;
    SetLength(LBindings, 6);
    for I := 0 to 2 do
    begin
      Need(Pos('playlist-primary-v1-', LMeta.Arrays['roles'].Objects[I].Strings['instrument_id']) = 1,
        'Saved instrument recipe is unsupported by this sound editor');
      LInstruments[I] := CreateStudioInstrument(StudioPlaylistInstrumentZones,
        LSettings.Arrays['instruments'].Strings[I], LSound, LHasSound, StudioInstrumentalRate);
      LBindings[I].Instrument := LInstruments[I];
      LBindings[I].Bus := LMeta.Arrays['roles'].Objects[I].Integers['output_bus'];
      LBindings[I].MaximumTones := 128;
      LRow := LMeta.Arrays['percussion'].Objects[I];
      LDrumSettings := DecodeStudioPercussionSettings(LRow, StudioInstrumentalRate);
      LDrums[I] := TPercussionInstrument.Create(StudioInstrumentalRate, LDrumSettings);
      LBindings[I + 3].Instrument := LDrums[I].Instrument;
      LBindings[I + 3].Bus := LRow.Integers['output_bus'];
      LBindings[I + 3].MaximumTones := 1;
      LBindings[I + 3].GateFrames :=
        SampleFramesFromSeconds(LDrumSettings.GateSeconds, StudioInstrumentalRate);
    end;
    LOptions := DefaultInstrumentStreamOptions(LDecisions.Int64s['music_frames']);
    LOptions.TailFrames := LParentResult.Objects['output_resources'].Int64s['tail_frames'];
    LOptions.Seed := LMeta.Int64s['seed'];
    LOptions.VoiceLimit := LMeta.Integers['voice_limit'];
    LOptions.WorkLimit := LMeta.Integers['work_limit'];
    LOutput := TStudioInstrumentalOutput.Create(ACatalogRoot, AJobId,
      StudioInstrumentalRate, LParentResult.Objects['output_resources'].Int64s['frame_count'],
      LSettings.Arrays['levels'], LOptions.Seed);
    LReplay := TMusicDecisionReplay.Create(LFile, LBindings, LOutput.Graph, LOptions);
    ReportWork(AProgress, 'instrumental_render', wuFrames, 0,
      LParentResult.Objects['output_resources'].Int64s['frame_count']);
    while LReplay.ReadOutputs(2048, StudioInstrumentalStemBuses, LMaster, LStems, AProgress) do
    begin
      if Assigned(ACheck) then ACheck;
      LOutput.Append(LMaster, LStems);
      ReportWork(AProgress, 'instrumental_render', wuFrames, LReplay.Position,
        LParentResult.Objects['output_resources'].Int64s['frame_count']);
    end;
    Need((LReplay.State = issCompleted) and (LReplay.CellCount = LDecisions.Int64s['cells']),
      'Saved notes did not complete on their declared cell clock');
    ReportWork(AProgress, 'instrumental_save', wuItems, 0, 1);
    LStored := LOutput.Finish(AProgress);
    LReplayMeta := TJSONObject.Create(['format', 'pythian.studio.reperformance.v1',
      'parent_job_id', ARequest.Strings['parent_job_id'],
      'parent_plan_sha256', ARequest.Strings['parent_plan_sha256'],
      'replay_source_job_id', LRootId, 'replay_source_plan_sha256', LRootPlan,
      'model_sha256', LParentResult.Strings['model_sha256'],
      'seed', Int64(LOptions.Seed), 'learning_performed', False, 'notes_changed', False,
      'math_target', {$I %FPCTARGETCPU%} + '-' + {$I %FPCTARGETOS%} + '/FPC' + {$I %FPCVERSION%}]);
    LReplayMeta.Add('settings', LSettings.Clone);
    LReplayMeta.Add('decisions', LDecisions.Clone);
    LReplayMeta.Add('output_resources', LParentResult.Objects['output_resources'].Clone);
    LPlanHash := StudioTextHash(LReplayMeta.AsJSON);
    WriteStudioJSONNew(StudioJobDirectory(ACatalogRoot, AJobId) +
      PathDelim + 'instrumental-reperformance.json', LReplayMeta);
    LResult := TJSONObject(LParentResult.Clone);
    for I := LResult.Count - 1 downto 0 do
      if Pos('|' + LResult.Names[I] + '|',
        '|outputs|parts|settings|stream|before|') > 0 then LResult.Delete(I);
    LResult.Add('outputs', LStored.Arrays['outputs'].Clone);
    LResult.Add('parts', LStored.Arrays['parts'].Clone);
    LResult.Add('settings', LSettings.Clone);
    LResult.Strings['runtime'] := 'retained_instrumental_score_replay';
    LResult.Strings['parent_job_id'] := ARequest.Strings['parent_job_id'];
    LResult.Strings['parent_plan_sha256'] := ARequest.Strings['parent_plan_sha256'];
    LResult.Strings['replay_source_job_id'] := LRootId;
    LResult.Strings['replay_source_plan_sha256'] := LRootPlan;
    LResult.Strings['plan_sha256'] := LPlanHash;
    LResult.Strings['request_sha256'] := ARequest.Strings['request_sha256'];
    LResult.Booleans['learning_performed'] := False;
    LResult.Booleans['notes_changed'] := False;
    LResult.Add('before', TJSONObject.Create(['job_id', ARequest.Strings['parent_job_id'],
      'plan_sha256', ARequest.Strings['parent_plan_sha256'],
      'wav_sha256', LParentResult.Arrays['outputs'].Objects[0].Strings['wav_sha256']]));
    if Assigned(ACheck) then ACheck;
    { The durable job publishes this explicit Before/After result. Do not create
      another generic source-style listening question for a sound-only edit. }
    Result := LResult;
    LResult := nil;
  finally
    LReplay.Free;
    LOutput.Free;
    LFile.Free;
    for I := 0 to 2 do
    begin
      LInstruments[I].Free;
      LDrums[I].Free;
    end;
    LResult.Free;
    LStored.Free;
    LReplayMeta.Free;
    LSettings.Free;
    LMeta.Free;
    LRoot.Free;
    LParent.Free;
  end;
end;

end.
