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
program pythian_tests_studio_sounds;

{$mode delphi}{$H+}

uses Classes, SysUtils, fpjson, pythian.audio, pythian.text, pythian.synth,
  pythian.instrument.recipe, pythian.instrument.catalog,
  pythian.mix.recipe, pythian.tools.studio.sounds, pythian.tools.json,
  pythian.tests.text.fixture, pythian.tools.studio.sound.patches,
  pythian.tools.studio.jobs, pythian.tools.studio.projects,
  pythian.tools.studio.worker, pythian.effects.catalog, pythian.wave.read;

var
  GChecks: Integer;

procedure Check(const ACondition: Boolean; const AMessage: String);
begin
  Inc(GChecks);
  if not ACondition then raise Exception.Create(AMessage);
end;

procedure CheckRoundTrip;
var
  LRecipes: TInstrumentRecipes;
  LRecipe: TInstrumentRecipe;
  LJSON: TJSONObject;
  LParsed: TJSONData;
  LBank: TRecipeInstrument;
  LDecodedBank: TRecipeInstrument;
  LA: TAudioClip;
  LB: TAudioClip;
  I: Integer;
  J: Integer;
  K: Integer;
begin
  LRecipes := BuiltInInstrumentRecipes;
  for I := 0 to High(LRecipes) do
  begin
    LRecipe := CopyInstrumentRecipe(LRecipes[I]);
    LRecipe.Caption := FixtureText(['Sound ', ScalarText($E000), ScalarText($10000)]);
    LJSON := EncodeStudioInstrumentRecipe(LRecipe);
    try
      LParsed := ParseNativeJSON(WriteNativeJSON(LJSON, 262144), 262144, 16);
      try
        LRecipe := DecodeStudioInstrumentRecipe(LParsed);
      finally
        LParsed.Free;
      end;
      Check(CompareScalarText(LRecipe.Caption,
        FixtureText(['Sound ', ScalarText($E000), ScalarText($10000)]), 128) = 0,
        'Sound caption changed through the host code page');
      LBank := TRecipeInstrument.Create(LRecipes[I], 24000);
      LDecodedBank := nil;
      try
        LDecodedBank := TRecipeInstrument.Create(LRecipe, 24000);
        LA := RenderFrameTones(LBank.Instrument.PlanNote(69, 110, 24000, 0, 1200, 731), 24000);
        LB := nil;
        try
          LB := RenderFrameTones(LDecodedBank.Instrument.PlanNote(69, 110, 24000, 0, 1200, 731), 24000);
          Check(LA.FrameCount = LB.FrameCount, 'Saved recipe changed its release extent');
          for J := 0 to LA.FrameCount - 1 do
            for K := 0 to 1 do
              if Abs(LA.SampleAt(J, K) - LB.SampleAt(J, K)) > 0.000001 then
                raise Exception.Create('Saved recipe changed the performed samples');
          Check(True, 'All saved recipe PCM matches');
        finally
          LA.Free;
          LB.Free;
        end;
      finally
        LBank.Free;
        LDecodedBank.Free;
      end;
    finally
      LJSON.Free;
    end;
  end;
end;

function MakeDesign: TJSONObject;
var
  LRecipes: TInstrumentRecipes;
  LRows: TJSONArray;
  I: Integer;
begin
  Result := TJSONObject.Create(['version', 1, 'mix', EncodeStudioMixRecipe(DefaultStemMixRecipe(6))]);
  try
    LRecipes := BuiltInInstrumentRecipes;
    LRows := TJSONArray.Create;
    Result.Add('instruments', LRows);
    for I := 0 to 2 do LRows.Add(EncodeStudioInstrumentRecipe(LRecipes[I]));
  except
    Result.Free;
    raise;
  end;
end;

procedure CheckDesign;
var
  LDesign: TJSONObject;
  LFirst: TJSONObject;
  LSecond: TJSONObject;
begin
  LDesign := MakeDesign;
  try
    LFirst := CanonicalStudioSoundDesign(LDesign, 24000);
    try
      LSecond := CanonicalStudioSoundDesign(LFirst, 24000);
      try
        Check(WriteNativeJSON(LFirst, 262144) = WriteNativeJSON(LSecond, 262144),
          'Sound design canonicalization is unstable');
      finally
        LSecond.Free;
      end;
    finally
      LFirst.Free;
    end;
  finally
    LDesign.Free;
  end;
end;

procedure CheckPatchStore(const ARoot: String);
var
  LWrite: TJSONObject;
  LFirst: TJSONObject;
  LAgain: TJSONObject;
  LChanged: TJSONObject;
  LList: TJSONObject;
  LRead: TJSONObject;
  LBad: TJSONObject;
  LInput: TJSONStringType;
  LName: TScalarText;
  LPath: String;
  LRejected: Boolean;
begin
  Check(not DirectoryExists(ARoot), 'Patch test needs a fresh isolated root');
  Check(ForceDirectories(ARoot), 'Create patch test root');
  LWrite := TJSONObject.Create(['format', 'pythian.studio.sound-patch.write.v1', 'design', MakeDesign]);
  LFirst := nil;
  LAgain := nil;
  LChanged := nil;
  try
    LName := FixtureText(['Blue ', ScalarText($10000)]);
    LWrite.Add('name', NativeJSONText(LName));
    LInput := WriteNativeJSON(LWrite, 262144);
    LFirst := SaveStudioSoundPatch(ARoot, LWrite);
    Check(WriteNativeJSON(LWrite, 262144) = LInput, 'Saving mutated the caller setup');
    Check(CompareScalarText(LFirst.Strings['name'], LName, 128) = 0,
      'Saved patch name changed Unicode bytes');
    LAgain := SaveStudioSoundPatch(ARoot, LWrite);
    Check(LAgain.Strings['id'] = LFirst.Strings['id'], 'Retry created another sound setup');
    LList := ListStudioSoundPatches(ARoot);
    try
      Check((LList.Arrays['patches'].Count = 1) and (LList.Arrays['errors'].Count = 0),
        'Sound setup listing changed membership');
      Check(LList.Arrays['patches'].Objects[0].Find('design') = nil,
        'Listing fetched a full sound definition');
    finally
      LList.Free;
    end;
    LWrite.Objects['design'].Arrays['instruments'].Objects[0].Arrays['zones'].Objects[0].Objects['voice'].Floats['gain'] := 0.05;
    LChanged := SaveStudioSoundPatch(ARoot, LWrite);
    Check(LChanged.Strings['id'] <> LFirst.Strings['id'], 'Editing overwrote the saved setup identity');
    LRead := ReadStudioSoundPatch(ARoot, LFirst.Strings['id']);
    try
      Check(Abs(LRead.Objects['design'].Arrays['instruments'].Objects[0].Arrays['zones'].Objects[0].Objects['voice'].Floats['gain'] - 0.18) < 1E-12,
        'Earlier setup was changed by a later save');
    finally
      LRead.Free;
    end;
    LPath := IncludeTrailingPathDelimiter(ARoot) + 'studio' + PathDelim + 'sound-patches' +
      PathDelim + LFirst.Strings['id'] + '.json';
    LBad := TJSONObject(LFirst.Clone);
    try
      LBad.Objects['design'].Objects['mix'].Floats['tail_seconds'] := 2;
      ReplaceStudioJSON(LPath, LBad);
    finally
      LBad.Free;
    end;
    LList := ListStudioSoundPatches(ARoot);
    try
      Check((LList.Arrays['patches'].Count = 1) and (LList.Arrays['errors'].Count = 1),
        'Tampered setup was silently accepted or hid a valid setup');
    finally
      LList.Free;
    end;
    ReplaceStudioJSON(LPath, LFirst);
    LRejected := False;
    try
      LRead := ReadStudioSoundPatch(ARoot, '../other');
      LRead.Free;
    except
      on EAudio do LRejected := True;
    end;
    Check(LRejected, 'Sound setup identity allowed a path traversal');
    Check(not DirectoryExists(IncludeTrailingPathDelimiter(ARoot) + 'studio' + PathDelim + 'jobs'),
      'Saving sound settings started a job');
  finally
    LChanged.Free;
    LAgain.Free;
    LFirst.Free;
    LWrite.Free;
  end;
end;

function SoundVariant(const ARoot, AId: String; const AParent, ADesign: TJSONObject): TJSONObject;
var
  LWrite: TJSONObject;
  LJob: TJSONObject;
begin
  LWrite := TJSONObject.Create(['format', StudioJobWriteFormat, 'kind', 'instrumental_reperform',
    'job_id', AId, 'project_id', AParent.Objects['results'].Strings['project_id'],
    'project_revision', AParent.Objects['results'].Int64s['project_revision'],
    'project_snapshot_sha256', AParent.Objects['results'].Strings['project_snapshot_sha256'],
    'parent_job_id', AParent.Strings['job_id'],
    'parent_plan_sha256', AParent.Objects['results'].Strings['plan_sha256'], 'sound_design', ADesign.Clone]);
  try
    LJob := PrepareStudioJob(ARoot, LWrite);
    LJob.Free;
    LJob := EnqueueStudioJob(ARoot, LWrite);
    LJob.Free;
    Check(RunStudioWorker(ARoot, AId, ARoot + '-absent-library'), 'Sound variant did not render: ' + AId);
    Result := ReadStudioJob(ARoot, AId);
    Check(Result.Strings['status'] = 'completed', 'Sound variant did not complete');
    Check(Result.Objects['results'].Objects['decisions'].AsJSON =
      AParent.Objects['results'].Objects['decisions'].AsJSON, 'Sound edits changed saved notes');
    Check((Result.Objects['results'].Strings['model_sha256'] = AParent.Objects['results'].Strings['model_sha256']) and
      not Result.Objects['results'].Booleans['learning_performed'] and
      not Result.Objects['results'].Booleans['notes_changed'], 'Sound edits learned or changed a model');
  finally
    LWrite.Free;
  end;
end;

procedure CheckWorker(const ARoot: String);
var
  LSettings: TJSONObject;
  LWrite: TJSONObject;
  LProject: TJSONObject;
  LBase: TJSONObject;
  LFX: TJSONObject;
  LDry: TJSONObject;
  LTimbre: TJSONObject;
  LTail: TJSONObject;
  LDesign: TJSONObject;
  LMix: TStemMixRecipe;
  LRecipes: TInstrumentRecipes;
  LStream: TFileStream;
  LReader: TWaveFrameReader;
  LSamples: TAudioSamples;
  LHash: String;
  LEnergy: Double;
  I: Integer;
begin
  Check(not DirectoryExists(ARoot), 'Worker sound test needs a fresh root');
  Check(ForceDirectories(ARoot), 'Create worker sound root');
  LSettings := TJSONObject.Create(['tempo_bpm', 120, 'tonic', 0, 'cells', 16,
    'instruments', TJSONArray.Create(['saw', 'triangle', 'square']),
    'levels', TJSONArray.Create([100, 100, 100, 100, 100, 100]),
    'form', TJSONArray.Create([TJSONObject.Create(['section', 'Opening', 'name', 'Opening',
      'cells', 16, 'repeat_from', -1, 'keep', TJSONArray.Create, 'energy', 50])])]);
  LWrite := TJSONObject.Create(['format', StudioProjectWriteFormat, 'project_id', 'sounds',
    'expected_revision', 0, 'name', 'Sound controls', 'style_intent', '',
    'learning_mode', 'instrumental', 'sources', TJSONArray.Create, 'instrumental', LSettings.Clone]);
  LProject := nil;
  LBase := nil;
  LDesign := nil;
  LFX := nil;
  LDry := nil;
  LTimbre := nil;
  LTail := nil;
  try
    LProject := SaveStudioProject(ARoot, LWrite);
    FreeAndNil(LWrite);
    LWrite := TJSONObject.Create(['format', StudioJobWriteFormat, 'kind', 'instrumental_generate',
      'job_id', 'base', 'project_id', 'sounds', 'project_revision', 1,
      'project_snapshot_sha256', LProject.Strings['snapshot_sha256'],
      'seeds', TJSONArray.Create([731]), 'instrumental', LSettings.Clone]);
    LBase := EnqueueStudioJob(ARoot, LWrite);
    FreeAndNil(LBase);
    Check(RunStudioWorker(ARoot, 'base', ARoot + '-absent-library'), 'Base sound score did not render');
    LBase := ReadStudioJob(ARoot, 'base');
    LMix := DefaultStemMixRecipe(6);
    SetLength(LMix.Parts[0].Effects, 1);
    LMix.Parts[0].Effects[0].Settings := DefaultCatalogEffect(ceGain);
    LMix.Parts[0].Effects[0].Settings.Values[0] := -6;
    LDesign := TJSONObject.Create(['version', 1,
      'instruments', LBase.Objects['results'].Arrays['instrument_recipes'].Clone,
      'mix', EncodeStudioMixRecipe(LMix)]);
    LFX := SoundVariant(ARoot, 'effects', LBase, LDesign);
    Check(LFX.Objects['results'].Arrays['parts'].Objects[0].Strings['wav_sha256'] <>
      LBase.Objects['results'].Arrays['parts'].Objects[0].Strings['wav_sha256'], 'Part gain effect did not change actual PCM');
    for I := 1 to 5 do
    begin
      Check(LFX.Objects['results'].Arrays['parts'].Objects[I].Strings['wav_sha256'] =
        LBase.Objects['results'].Arrays['parts'].Objects[I].Strings['wav_sha256'], 'Part effect changed an unselected stem');
    end;
    LDesign.Objects['mix'].Booleans['bypass'] := True;
    LDry := SoundVariant(ARoot, 'dry', LFX, LDesign);
    for I := 0 to 5 do
    begin
      Check(LDry.Objects['results'].Arrays['parts'].Objects[I].Strings['wav_sha256'] =
        LBase.Objects['results'].Arrays['parts'].Objects[I].Strings['wav_sha256'], 'Dry score replay differs from the actual base stem');
    end;
    LRecipes := BuiltInInstrumentRecipes;
    LDesign.Arrays['instruments'].Delete(2);
    LDesign.Arrays['instruments'].Add(EncodeStudioInstrumentRecipe(FindInstrumentRecipe(LRecipes, 'fm-bell')));
    LTimbre := SoundVariant(ARoot, 'timbre', LBase, LDesign);
    Check(LTimbre.Objects['results'].Arrays['parts'].Objects[2].Strings['wav_sha256'] <>
      LBase.Objects['results'].Arrays['parts'].Objects[2].Strings['wav_sha256'], 'FM instrument did not change the actual lead');
    for I := 0 to 5 do
    begin
      if I <> 2 then
      begin
        Check(LTimbre.Objects['results'].Arrays['parts'].Objects[I].Strings['wav_sha256'] =
          LBase.Objects['results'].Arrays['parts'].Objects[I].Strings['wav_sha256'], 'FM edit changed another part');
      end;
    end;
    LDesign.Arrays['instruments'].Objects[2].Arrays['zones'].Objects[0].Objects['voice'].Arrays['envelope'].Floats[3] := 8;
    LDesign.Objects['mix'].Floats['tail_seconds'] := 0.05;
    LTail := SoundVariant(ARoot, 'release', LTimbre, LDesign);
    Check(LTail.Objects['results'].Objects['output_resources'].Int64s['tail_frames'] = 192000,
      'Actual output admission truncated the declared note release');
    LStream := OpenStudioInstrumentalAudio(ARoot, 'release', 2, LHash);
    LReader := nil;
    try
      LReader := TWaveFrameReader.Create(LStream);
      Check(LReader.FrameCount = LTail.Objects['results'].Objects['output_resources'].Int64s['frame_count'],
        'Saved audio has a different resource clock');
      LReader.SeekFrame(LTail.Objects['results'].Objects['decisions'].Int64s['music_frames'] + 24000);
      LSamples := LReader.ReadFrames(4096);
      LEnergy := 0;
      for I := 0 to High(LSamples) do
      begin
        LEnergy := LEnergy + Abs(LSamples[I]);
      end;
      Check(LEnergy > 0.01, 'Long edited release has no actual tail beyond the old one-second limit');
    finally
      LReader.Free;
      LStream.Free;
    end;
  finally
    LTail.Free;
    LTimbre.Free;
    LDry.Free;
    LFX.Free;
    LDesign.Free;
    LBase.Free;
    LProject.Free;
    LWrite.Free;
    LSettings.Free;
  end;
end;

begin
  CheckRoundTrip;
  CheckDesign;
  if (ParamCount = 2) and (ParamStr(1) = '--worker') then
  begin
    CheckWorker(ExpandFileName(ParamStr(2)));
  end
  else if ParamCount = 1 then
  begin
    CheckPatchStore(ExpandFileName(ParamStr(1)));
  end;
  WriteLn('Studio sound codec checks=', GChecks);
end.
