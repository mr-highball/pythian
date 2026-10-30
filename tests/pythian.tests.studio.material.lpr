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

program pythian_tests_studio_material;
{$mode delphi}
{$H+}
{$codepage utf8}

uses Classes, SysUtils, Math, Base64, fpjson,
  pythian.audio, pythian.hash, pythian.music.pattern, pythian.pitch.track, pythian.wave.stream,
  pythian.tools.studio.material, pythian.tools.studio.projects,
  pythian.tools.studio.capture, pythian.tools.studio.jobs, pythian.tests.studio.material.support;

var
  GChecks: Integer;
  GRoot, GCatalog: String;

procedure Check(const ACondition: Boolean; const AMessage: String);
begin
  Inc(GChecks);
  if not ACondition then
  begin
    raise EAudio.Create(AMessage);
  end;
end;

function ProjectWrite(const AId: String; const ARevision: Integer;
  const AMaterial: TJSONObject): TJSONObject;
begin
  Result := TJSONObject.Create;
  Result.Add('format', StudioProjectWriteFormat);
  Result.Add('project_id', AId);
  Result.Add('expected_revision', ARevision);
  Result.Add('name', 'Experimental musical input');
  Result.Add('style_intent', 'Operator-controlled motif');
  Result.Add('learning_mode', 'instrumental');
  Result.Add('sources', TJSONArray.Create);
  Result.Add('parked_sources', TJSONArray.Create);
  if AMaterial <> nil then
  begin
    Result.Add('musical_material', AMaterial.Clone);
  end;
end;

procedure Reject(const AObject: TJSONObject; const AAction: Integer;
  const AMessage: String);
var
  LResult: TJSONObject;
  LFailed: Boolean;
begin
  LResult := nil;
  LFailed := False;
  try
    try
      case AAction of
        0: LResult := CanonicalStudioMaterial(AObject);
        1: ValidateStudioMaterialBinding(GCatalog, AObject);
        2: LResult := SaveStudioProject(GCatalog, AObject);
        3: LResult := PrepareStudioJob(GCatalog, AObject);
      end;
    except
      on E: EAudio do
      begin
        LFailed := True;
      end;
    end;
  finally
    LResult.Free;
  end;
  Check(LFailed, AMessage);
end;

function JobCount: Integer;
var
  LJobs: TJSONObject;
begin
  LJobs := ListStudioJobs(GCatalog);
  try
    Result := LJobs.Arrays['jobs'].Count;
  finally
    LJobs.Free;
  end;
end;

function FirstPitch(const AMaterial: TJSONObject): Integer;
var
  LPattern: TPitchPattern;
  LCell: TPitchPatternCell;
begin
  LPattern := DecodeStudioPitchPattern(AMaterial.Arrays['pattern']);
  Result := -1;
  for LCell in LPattern do
  begin
    if LCell.Kind = pskPitch then
    begin
      Exit(LCell.Note);
    end;
  end;
end;

procedure Run;
var
  LMaterial, LCanonical, LWrite, LSaved, LRead, LOther, LJob: TJSONObject;
  LRow: TJSONObject;
  LPattern: TPitchPattern;
  LFirstHash, LAnalysisHash: String;
  LOriginal, LJobText, LInvalid: TJSONStringType;
  LBytes: TAudioBytes;
  LIndex: Integer;
  LFailed: Boolean;
begin
  Check(not DirectoryExists(GRoot), 'Fixture root must be fresh');
  Check(ForceDirectories(GRoot), 'Fixture root created on the explicit output drive');
  Check(ForceDirectories(GCatalog), 'Private fixture catalog created');
  LMaterial := DefaultStudioMaterial;
  LCanonical := nil;
  LWrite := nil;
  LSaved := nil;
  LRead := nil;
  LOther := nil;
  LJob := nil;
  try
    LCanonical := CanonicalStudioMaterial(LMaterial);
    Check((LCanonical.Integers['part'] = -1) and
      (LCanonical.Strings['pitch_decision'] = 'bypassed'), 'Default authored route bypasses pitch observations');
    Check(LCanonical.Objects['source'].Strings['kind'] = 'manual', 'Manual input has no invented source');
    LCanonical.Free;
    LCanonical := nil;
    LMaterial.Integers['part'] := 2;
    LMaterial.Strings['pitch_decision'] := 'manual';
    SetLength(LPattern, 4);
    for LIndex := 0 to 3 do
    begin
      LPattern[LIndex] := Default(TPitchPatternCell);
      LPattern[LIndex].Kind := pskUnknown;
      LPattern[LIndex].Note := -1;
    end;
    LPattern[0].Kind := pskPitch;
    LPattern[0].Note := 60;
    LPattern[0].Velocity := 80;
    LPattern[0].Attack := True;
    LPattern[2].Kind := pskSilence;
    LPattern[3] := LPattern[0];
    LPattern[3].Note := 62;
    LMaterial.Delete('pattern');
    LMaterial.Add('pattern', EncodeStudioPitchPattern(LPattern));
    LMaterial.Strings['notes'] := 'Operator says: "D♯", keep uncertainty.';
    LOriginal := LMaterial.AsJSON;
    LCanonical := CanonicalStudioMaterial(LMaterial);
    LPattern := DecodeStudioPitchPattern(LCanonical.Arrays['pattern']);
    Check((LPattern[1].Kind = pskUnknown) and (LPattern[2].Kind = pskSilence),
      'Unknown and silence remain distinct through the native JSON bridge');
    LCanonical.Strings['notes'] := 'Detached';
    Check(LMaterial.AsJSON = LOriginal, 'Canonical choices are detached from the caller');
    LCanonical.Free;
    LCanonical := nil;
    LOther := TJSONObject(LMaterial.Clone);
    LOther.Strings['key_decision'] := 'accepted';
    Reject(LOther, 0, 'Manual context cannot claim an accepted key observation');
    LOther.Free;
    LOther := TJSONObject(LMaterial.Clone);
    LOther.Strings['pitch_decision'] := 'accepted';
    Reject(LOther, 0, 'Manual pitches cannot claim source observations');
    LOther.Free;
    LOther := TJSONObject(LMaterial.Clone);
    LOther.Arrays['pattern'].Objects[0].Integers['note'] := 128;
    Reject(LOther, 0, 'Out-of-domain pitches reject before saving');
    LOther.Free;
    LOther := TJSONObject(LMaterial.Clone);
    LOther.Add('unrelated', True);
    Reject(LOther, 0, 'Unrelated choice fields reject');
    FreeAndNil(LOther);
    LOther := TJSONObject(LMaterial.Clone);
    SetLength(LInvalid, 1);
    LInvalid[1] := AnsiChar($FF);
    LOther.Strings['notes'] := LInvalid;
    Reject(LOther, 0, 'Direct native callers cannot admit malformed UTF-8 musical notes');
    FreeAndNil(LOther);
    LWrite := ProjectWrite('manual-motif', 0, LMaterial);
    LSaved := SaveStudioProject(GCatalog, LWrite);
    LFirstHash := LSaved.Strings['snapshot_sha256'];
    Check(LSaved.Integers['revision'] = 1, 'Manual choices save in the existing immutable project revisions');
    Check(LSaved.Objects['musical_material'].Strings['notes'] = LMaterial.Strings['notes'],
      'Quoted Unicode operator notes survive the snapshot');
    Check((LSaved.Strings['training_status'] = 'not_started') and
      not LSaved.Booleans['model_available'] and (JobCount = 0),
      'Save performs no model learning or job submission');
    FreeAndNil(LSaved);
    LSaved := SaveStudioProject(GCatalog, LWrite);
    Check(LSaved.Booleans['already_saved'] and
      (LSaved.Strings['snapshot_sha256'] = LFirstHash), 'Exact save retry reconciles without a new revision');
    FreeAndNil(LSaved);
    LWrite.Integers['expected_revision'] := 1;
    LWrite.Objects['musical_material'].Strings['notes'] := 'Explicit correction only';
    LWrite.Objects['musical_material'].Arrays['pattern'].Objects[3].Integers['note'] := 63;
    LSaved := SaveStudioProject(GCatalog, LWrite);
    Check((LSaved.Integers['revision'] = 2) and (JobCount = 0), 'Corrected manual motif saves without generation');
    FreeAndNil(LSaved);
    LRead := ReadStudioProjectRevision(GCatalog, 'manual-motif', 1);
    Check(LRead.Strings['snapshot_sha256'] = LFirstHash, 'The preceding manual evidence stays immutable');
    FreeAndNil(LRead);
    LWrite.Integers['expected_revision'] := 2;
    LWrite.Objects['musical_material'].Arrays['pattern'].Objects[0].Integers['note'] := 128;
    Reject(LWrite, 2, 'Invalid correction cannot replace the saved project');
    LRead := ReadStudioProject(GCatalog, 'manual-motif');
    Check(LRead.Integers['revision'] = 2, 'Rejected correction preserves the last accepted revision');
    FreeAndNil(LRead);
    FreeAndNil(LWrite);
    LWrite := ProjectWrite('authored-only', 0, nil);
    LSaved := SaveStudioProject(GCatalog, LWrite);
    Check(LSaved.Find('musical_material') = nil, 'Existing authored-only projects need no new choice record');
    FreeAndNil(LSaved);
    FreeAndNil(LWrite);
    FreeAndNil(LMaterial);

    AnalyzeAuthoredStudioCapture(GCatalog);
    Check(JobCount = 1, 'Only the explicit analysis job exists');
    LJob := ReadStudioJob(GCatalog, 'musical-analysis');
    LAnalysisHash := StudioTextHash(LJob.Objects['results'].AsJSON);
    LJobText := LJob.AsJSON;
    LMaterial := ProposeStudioMaterial(GCatalog, 'musical-analysis');
    Check((LMaterial.Strings['analysis_result_sha256'] = LAnalysisHash) and
      (LMaterial.Strings['analysis_job_id'] = 'musical-analysis'), 'Suggestions bind exact native analysis evidence');
    Check((LMaterial.Objects['source'].Strings['kind'] = 'capture') and
      (LMaterial.Objects['source'].Strings['id'] = 'musical-input'), 'Retained capture identity is explicit');
    Check((LMaterial.Objects['source'].Integers['sample_rate'] = 8000) and
      (LMaterial.Objects['source'].Int64s['start_frame'] = 0) and
      (LMaterial.Objects['source'].Int64s['end_frame'] = 32000), 'Original recording coordinates survive preparation');
    Check((LMaterial.Integers['part'] = -1) and
      (LMaterial.Strings['pitch_decision'] = 'bypassed'), 'Channels are not silently assigned to an instrument');
    Check((Length(DecodeStudioPitchPattern(LMaterial.Arrays['pattern'])) = 16) and
      (FirstPitch(LMaterial) = 57), 'Actual Pascal analysis supplies the selected-channel grid');
    LMaterial.Integers['part'] := 2;
    LMaterial.Strings['pitch_decision'] := 'accepted';
    ValidateStudioMaterialBinding(GCatalog, LMaterial);
    Check(True, 'Explicitly accepted source cells bind to their real analysis');
    LWrite := ProjectWrite('recording-motif', 0, LMaterial);
    LSaved := SaveStudioProject(GCatalog, LWrite);
    Check((LSaved.Integers['revision'] = 1) and (JobCount = 1), 'Accepting suggestions saves choices without learning');
    Check(LSaved.Objects['musical_material'].Objects['source'].Strings['license'] =
      'unknown; caller-supplied private audio', 'Original private-audio license receipt is preserved');
    FreeAndNil(LSaved);
    for LIndex := 0 to LWrite.Objects['musical_material'].Arrays['pattern'].Count - 1 do
    begin
      LRow := LWrite.Objects['musical_material'].Arrays['pattern'].Objects[LIndex];
      if LRow.Strings['kind'] = 'pitch' then
      begin
        LRow.Integers['note'] := LRow.Integers['note'] + 1;
      end;
    end;
    LWrite.Integers['expected_revision'] := 1;
    Reject(LWrite, 2, 'Edited pitches cannot remain falsely attributed as accepted observations');
    LWrite.Objects['musical_material'].Strings['pitch_decision'] := 'corrected';
    LSaved := SaveStudioProject(GCatalog, LWrite);
    Check((LSaved.Integers['revision'] = 2) and
      (FirstPitch(LSaved.Objects['musical_material']) = 58), 'Operator-corrected pitch cells save with their actual origin');
    FreeAndNil(LSaved);
    FreeAndNil(LWrite);
    LOther := ProposeStudioMaterial(GCatalog, 'musical-analysis', 120, 1);
    Check((FirstPitch(LOther) = 69) and (LOther.Integers['channel'] = 1),
      'Selecting another channel changes real source-derived pitches');
    LOther.Integers['part'] := 0;
    LOther.Strings['pitch_decision'] := 'accepted';
    ValidateStudioMaterialBinding(GCatalog, LOther);
    Check(True, 'Channel two can be explicitly assigned to bass without a separation claim');
    FreeAndNil(LOther);
    LOther := ProposeStudioMaterial(GCatalog, 'musical-analysis', 60, 0);
    Check(LOther.Arrays['pattern'].Count = 8, 'An explicit clock change requantizes through the primary library');
    FreeAndNil(LOther);
    LOther := TJSONObject(LMaterial.Clone);
    LOther.Strings['analysis_result_sha256'] := StringOfChar('0', 64);
    Reject(LOther, 1, 'A changed analysis digest cannot replace original evidence');
    FreeAndNil(LOther);
    LOther := TJSONObject(LMaterial.Clone);
    LOther.Objects['source'].Int64s['start_frame'] := 1;
    Reject(LOther, 1, 'A changed source range cannot be silently accepted');
    FreeAndNil(LOther);
    LFailed := False;
    try
      LOther := ProposeStudioMaterial(GCatalog, 'musical-analysis', 120, 2);
    except
      on E: EAudio do
      begin
        LFailed := True;
      end;
    end;
    Check(LFailed, 'Missing channels reject without a fallback channel');
    LRead := ReadStudioJob(GCatalog, 'musical-analysis');
    Check((StudioTextHash(LRead.Objects['results'].AsJSON) = LAnalysisHash) and
      (LRead.AsJSON = LJobText), 'Operator corrections preserve the original analysis and job');
    Check(JobCount = 1, 'Preparing and saving all choices creates no hidden training or regeneration');
    FreeAndNil(LRead);
    FreeAndNil(LJob);
    LWrite := TJSONObject.Create;
    LWrite.Add('capture_id', 'musical-input');
    LWrite.Add('collection_name', 'Authored Unicode control');
    LWrite.Add('title', 'D♯ étude 音');
    LSaved := SaveStudioCapture(GCatalog, 'save-musical-input', GRoot + '/library', LWrite);
    LFirstHash := LSaved.Strings['source_sha256'];
    FreeAndNil(LSaved);
    FreeAndNil(LWrite);
    LWrite := ProjectWrite('unicode-tags', 0, nil);
    LWrite.Strings['name'] := 'D♯ étude 音';
    LOriginal := LWrite.Strings['name'];
    Check((Ord(LOriginal[2]) = $E2) and (Ord(LOriginal[3]) = $99) and
      (Ord(LOriginal[4]) = $AF), 'Fixture supplies the actual UTF-8 sharp sign');
    LWrite.Strings['style_intent'] := 'Δ warmth · 音色';
    LRow := TJSONObject.Create;
    LWrite.Arrays['sources'].Add(LRow);
    LRow.Add('source_sha256', LFirstHash);
    LRow.Add('selection', 'full');
    LRow.Add('classifications', TJSONArray.Create(['D♯', '音色']));
    LSaved := SaveStudioProject(GCatalog, LWrite);
    Check(LSaved.Strings['name'] = LWrite.Strings['name'], 'Unicode project names retain their actual scalars');
    LRead := ReadStudioProject(GCatalog, 'unicode-tags');
    Check(LRead.Strings['style_intent'] = LWrite.Strings['style_intent'], 'Unicode direction text survives reload');
    Check(LRead.Arrays['sources'].Objects[0].Strings['title'] = LWrite.Strings['name'],
      'Actual catalog title survives source admission');
    Check((LRead.Arrays['sources'].Objects[0].Arrays['classifications'].Strings[0] =
      LWrite.Arrays['sources'].Objects[0].Arrays['classifications'].Strings[0]) and
      (LRead.Arrays['sources'].Objects[0].Arrays['classifications'].Strings[1] =
      LWrite.Arrays['sources'].Objects[0].Arrays['classifications'].Strings[1]),
      'Unicode classifications preserve their actual bytes');
    Check(JobCount = 1, 'Classifying source material still performs no learning');
    FreeAndNil(LWrite);
    LWrite := TJSONObject.Create;
    LWrite.Add('format', StudioJobWriteFormat);
    LWrite.Add('job_id', 'explicit-unicode-generation');
    LWrite.Add('kind', 'instrumental_generate');
    LWrite.Add('project_id', 'unicode-tags');
    LWrite.Add('project_revision', 1);
    LWrite.Add('project_snapshot_sha256', LSaved.Strings['snapshot_sha256']);
    LWrite.Add('seeds', TJSONArray.Create([731]));
    LRow := TJSONObject.Create;
    LWrite.Add('instrumental', LRow);
    LRow.Add('tempo_bpm', 120);
    LRow.Add('tonic', 0);
    LRow.Add('cells', 8);
    LRow.Add('instruments', TJSONArray.Create(['saw', 'triangle', 'square']));
    LRow.Add('levels', TJSONArray.Create([100, 100, 100, 100, 100, 100]));
    LOther := TJSONObject(LWrite.Clone);
    FreeAndNil(LRead);
    LRead := ReadStudioProject(GCatalog, 'recording-motif');
    LOther.Strings['project_id'] := 'recording-motif';
    LOther.Integers['project_revision'] := LRead.Integers['revision'];
    LOther.Strings['project_snapshot_sha256'] := LRead.Strings['snapshot_sha256'];
    LCanonical := PrepareStudioJob(GCatalog, LOther);
    Check(LCanonical.Find('musical_material') <> nil,
      'Explicit generation preflight carries the actual saved musical choices');
    FreeAndNil(LCanonical);
    FreeAndNil(LOther);
    LOther := EnqueueStudioJob(GCatalog, LWrite);
    FreeAndNil(LOther);
    LJob := ReadStudioJobRequest(GCatalog, 'explicit-unicode-generation');
    Check(LJob.Objects['project_snapshot'].Strings['name'] = LSaved.Strings['name'],
      'Actual immutable job request carries original Unicode project identity');
    LOriginal := LJob.AsJSON;
    SetLength(LBytes, Length(LOriginal));
    Move(LOriginal[1], LBytes[0], Length(LBytes));
    Check(StudioTextHash(LJob.AsJSON) = Sha256Bytes(LBytes), 'Shared hash consumes exact JSON bytes');
    LOther := CancelStudioJob(GCatalog, 'explicit-unicode-generation');
    Check(LOther.Strings['status'] = 'cancelled', 'Explicit queued test job is cancelled before any worker');
    FreeAndNil(LOther);
    FreeAndNil(LWrite);
    LWrite := ProjectWrite('http-motif', 0, LMaterial);
    LWrite.Strings['name'] := 'D♯ étude 音';
    LWrite.Objects['musical_material'].Strings['notes'] := 'D♯ · Δ · 音色';
    WriteStudioJSONNew(GRoot + '/http-write.json', LWrite);
  finally
    LRead.Free;
    LJob.Free;
    LOther.Free;
    LSaved.Free;
    LWrite.Free;
    LCanonical.Free;
    LMaterial.Free;
  end;
end;

begin
  try
    Check(ParamCount = 1, 'Usage: studio material test FRESH_ROOT');
    GRoot := ExpandFileName(ParamStr(1));
    GCatalog := GRoot + '/catalog';
    Run;
    WriteLn('PASS Studio musical choices: ', GChecks, ' checks');
  except
    on E: Exception do
    begin
      WriteLn(StdErr, E.ClassName, ' after ', GChecks, ' checks: ', E.Message);
      DumpExceptionBackTrace(StdErr);
      ExitCode := 1;
    end;
  end;
end.
