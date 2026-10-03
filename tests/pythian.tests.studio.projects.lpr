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
program PythianStudioProjectConformance;

{$mode delphi}
{$H+}

uses
  Classes,
  SysUtils,
  fpjson,
  pythian.audio,
  pythian.hash,
  pythian.wave,
  pythian.wave.stream,
  pythian.tools.annotations.catalog,
  pythian.tools.studio.projects;

var
  GChecks: Integer;

procedure Check(const ACondition: Boolean; const AMessage: String);
begin
  Inc(GChecks);
  if not ACondition then
  begin
    raise Exception.Create(AMessage);
  end;
end;

function HashFile(const APath: String): String;
var
  LStream: TFileStream;
begin
  LStream := TFileStream.Create(APath, fmOpenRead);
  try
    Result := Sha256Stream(LStream, LStream.Size);
  finally
    LStream.Free;
  end;
end;

procedure WriteJson(const APath: String; const AData: TJSONObject);
var
  LStream: TFileStream;
  LText: String;
begin
  LText := AData.AsJSON + #10;
  LStream := TFileStream.Create(APath, fmCreate);
  try
    LStream.WriteBuffer(LText[1], Length(LText));
  finally
    LStream.Free;
  end;
end;

function PrepareSource(const ARoot, AName, APartition: String;
  const APhase: Integer): String;
var
  LSamples: TAudioSamples;
  LClip: TAudioClip;
  LStream: TFileStream;
  LManifest: TJSONObject;
  LRows: TJSONArray;
  LRow: TJSONObject;
  LReport: TJSONObject;
  LInbox: String;
  LPath: String;
  LIndex: Integer;
begin
  LInbox := IncludeTrailingPathDelimiter(ARoot) + 'inbox-' + AName;
  Check(ForceDirectories(LInbox), 'Create synthetic inbox');
  SetLength(LSamples, 16000);
  for LIndex := 0 to High(LSamples) do
  begin
    if (LIndex + APhase) mod 400 < 40 then
    begin
      LSamples[LIndex] := 0.125;
    end
    else
    begin
      LSamples[LIndex] := 0;
    end;
  end;
  LClip := TAudioClip.Create(8000, 1, LSamples);
  try
    LPath := IncludeTrailingPathDelimiter(LInbox) + 'source.wav';
    LStream := TFileStream.Create(LPath, fmCreate);
    try
      WriteWavePcm16(LStream, LClip);
    finally
      LStream.Free;
    end;
  finally
    LClip.Free;
  end;
  Result := HashFile(LPath);
  LManifest := TJSONObject.Create;
  try
    LManifest.Add('version', 1);
    LRows := TJSONArray.Create;
    LManifest.Add('tracks', LRows);
    LRow := TJSONObject.Create;
    LRows.Add(LRow);
    LRow.Add('file', 'source.wav');
    LRow.Add('sha256', Result);
    LRow.Add('source_group', 'studio_' + AName);
    LRow.Add('clock_id', 'studio_clock_' + AName);
    LRow.Add('partition', APartition);
    LRow.Add('title', 'Pascal-authored Studio ' + AName + ' control');
    LRow.Add('provenance', 'MIT first-party synthetic pulse fixture; no musical truth claim');
    LRow.Add('license', 'MIT');
    WriteJson(IncludeTrailingPathDelimiter(LInbox) + 'manifest.json', LManifest);
  finally
    LManifest.Free;
  end;
  LReport := ImportLabelInbox(LInbox, IncludeTrailingPathDelimiter(ARoot) + 'catalog');
  try
    Check((LReport.Integers['imported'] = 1) and (LReport.Integers['failed'] = 0),
      'Actual native source import: ' + LReport.AsJSON);
  finally
    LReport.Free;
  end;
end;

function MakeWrite(const AHash: String): TJSONObject;
var
  LRows: TJSONArray;
  LRow: TJSONObject;
begin
  Result := TJSONObject.Create;
  Result.Add('format', StudioProjectWriteFormat);
  Result.Add('project_id', 'evening');
  Result.Add('expected_revision', 0);
  Result.Add('name', 'Evening ideas');
  Result.Add('style_intent', '');
  Result.Add('learning_mode', 'raw_acoustic');
  LRows := TJSONArray.Create;
  Result.Add('sources', LRows);
  LRow := TJSONObject.Create;
  LRows.Add(LRow);
  LRow.Add('source_sha256', AHash);
  LRow.Add('selection', 'full');
end;

procedure ExpectSaveFailure(const ACatalog: String; const AWrite: TJSONObject;
  const AExpectedSnapshot: String; const AConflict: Boolean = False);
var
  LResult: TJSONObject;
  LFailed: Boolean;
  LConflict: Boolean;
begin
  LFailed := False;
  LConflict := False;
  try
    LResult := SaveStudioProject(ACatalog, AWrite);
    LResult.Free;
  except
    on LException: EStudioConflict do
    begin
      LFailed := True;
      LConflict := True;
    end;
    on LException: EAudio do
    begin
      LFailed := True;
    end;
  end;
  Check(LFailed, 'Expected rejected save');
  if AConflict then
  begin
    Check(LConflict, 'Conflict is explicitly classified');
  end;
  LResult := ReadStudioProject(ACatalog, 'evening');
  try
    Check(LResult.AsJSON = AExpectedSnapshot, 'Failed save preserves accepted snapshot');
  finally
    LResult.Free;
  end;
end;

procedure ExpectParseFailure(const AText: String);
var
  LResult: TJSONObject;
  LFailed: Boolean;
begin
  LFailed := False;
  try
    LResult := ParseStudioProjectWrite(AText);
    LResult.Free;
  except
    on LException: EAudio do
    begin
      LFailed := True;
    end;
  end;
  Check(LFailed, 'Expected bounded parser rejection');
end;

procedure Run(const ARoot: String);
var
  LCatalog: String;
  LHash: String;
  LEvaluationHash: String;
  LUnassignedHash: String;
  LWrite: TJSONObject;
  LBad: TJSONObject;
  LResult: TJSONObject;
  LParsed: TJSONObject;
  LRow: TJSONObject;
  LTrack: TJSONObject;
  LList: TJSONArray;
  LBefore: String;
  LInputBefore: String;
  LRevisionOneHash: String;
  LTrackPath: String;
  LLockPath: String;
  LStream: TFileStream;
  LByte: Byte;
  LIndex: Integer;
  LFoundEvaluation: Boolean;
begin
  Check(not DirectoryExists(ARoot) and not FileExists(ARoot), 'Fixture root must be fresh');
  Check(ForceDirectories(ARoot), 'Create isolated fixture root');
  LHash := PrepareSource(ARoot, 'development', 'development', 0);
  LEvaluationHash := PrepareSource(ARoot, 'evaluation', 'evaluation', 3);
  LUnassignedHash := PrepareSource(ARoot, 'unassigned', 'unassigned', 7);
  LCatalog := IncludeTrailingPathDelimiter(ARoot) + 'catalog';
  LResult := ListStudioProjects(LCatalog);
  try
    Check(LResult.Integers['count'] = 0, 'No projects is a valid empty state');
  finally
    LResult.Free;
  end;
  LResult := ListStudioSources(LCatalog);
  try
    Check(LResult.Integers['count'] = 3, 'List all original catalog sources');
    Check(LResult.Integers['maximum_selected_sources'] = 32, 'Expose selected-source limit');
    Check(Pos(ExpandFileName(ARoot), LResult.AsJSON) = 0, 'Source listing contains no local paths');
    LFoundEvaluation := False;
    LList := LResult.Arrays['sources'];
    for LIndex := 0 to LList.Count - 1 do
    begin
      LRow := TJSONObject(LList.Items[LIndex]);
      Check(LRow.Strings['source_validation'] = StudioSourceValidation,
        'Source bytes are pending asynchronous training verification');
      Check(LRow.Strings['song_boundaries'] = 'unknown', 'No invented single-song truth');
      if LRow.Strings['source_sha256'] = LEvaluationHash then
      begin
        LFoundEvaluation := LRow.Strings['selection_status'] = 'evaluation_only';
      end;
      if LRow.Strings['source_sha256'] = LUnassignedHash then
      begin
        Check(LRow.Strings['selection_status'] = 'pending_partition',
          'Unassigned source selection remains pending, not silently relabelled');
      end;
    end;
    Check(LFoundEvaluation, 'Evaluation source is read-only in training selection');
  finally
    LResult.Free;
  end;
  LWrite := MakeWrite(LHash);
  try
    LInputBefore := LWrite.AsJSON;
    LParsed := ParseStudioProjectWrite(LInputBefore);
    try
      Check(LParsed.AsJSON = LInputBefore, 'Strict write parser reproduces valid input');
    finally
      LParsed.Free;
    end;
    LResult := SaveStudioProject(LCatalog, LWrite);
    try
      Check(LResult.Integers['revision'] = 1, 'First durable revision');
      Check(not LResult.Booleans['already_saved'], 'New save is explicit');
      Check(LResult.Strings['training_status'] = 'not_started', 'Draft never implies training');
      Check(not LResult.Booleans['model_available'], 'Draft never implies usable model');
      Check(LResult.Arrays['used_sources'].Count = 0, 'Selected material is not used material');
      Check(LResult.Strings['style_intent'] = '', 'Optional intent is retained');
      LRow := TJSONObject(LResult.Arrays['sources'].Items[0]);
      Check((LRow.Int64s['start_frame'] = 0) and (LRow.Int64s['end_frame'] = 16000),
        'Full recording selection retains exact original clock');
      Check(LRow.Strings['partition'] = 'development', 'Source partition is preserved');
      Check(LRow.Strings['usage_status'] = 'selected_not_used', 'No fabricated learning admission');
    finally
      LResult.Free;
    end;
    Check(LWrite.AsJSON = LInputBefore, 'Save does not mutate caller input');
    LResult := ReadStudioProject(LCatalog, 'evening');
    try
      LBefore := LResult.AsJSON;
      LResult.Strings['name'] := 'Caller-owned mutation';
    finally
      LResult.Free;
    end;
    LResult := ReadStudioProject(LCatalog, 'evening');
    try
      Check(LResult.AsJSON = LBefore, 'Reload detaches returned JSON from durable state');
    finally
      LResult.Free;
    end;
    LRevisionOneHash := HashFile(IncludeTrailingPathDelimiter(LCatalog) +
      'studio/projects/evening/00000001.json');
    LResult := SaveStudioProject(LCatalog, LWrite);
    try
      Check(LResult.Booleans['already_saved'] and (LResult.Integers['revision'] = 1),
        'Lost-response identical retry appends no revision');
    finally
      LResult.Free;
    end;
    LBad := TJSONObject(LWrite.Clone);
    try
      LBad.Strings['name'] := 'Different stale draft';
      ExpectSaveFailure(LCatalog, LBad, LBefore, True);
      LBad.Int64s['expected_revision'] := 1;
      TJSONObject(LBad.Arrays['sources'].Items[0]).Strings['source_sha256'] := LEvaluationHash;
      ExpectSaveFailure(LCatalog, LBad, LBefore);
      TJSONObject(LBad.Arrays['sources'].Items[0]).Strings['source_sha256'] := StringOfChar('0', 64);
      ExpectSaveFailure(LCatalog, LBad, LBefore);
      TJSONObject(LBad.Arrays['sources'].Items[0]).Strings['source_sha256'] := LHash;
      LBad.Strings['project_id'] := '../escape';
      ExpectSaveFailure(LCatalog, LBad, LBefore);
      LBad.Strings['project_id'] := 'CON';
      ExpectSaveFailure(LCatalog, LBad, LBefore);
      LBad.Strings['project_id'] := 'evening';
      LBad.Strings['learning_mode'] := 'pretend_trained';
      ExpectSaveFailure(LCatalog, LBad, LBefore);
      LBad.Strings['learning_mode'] := 'raw_acoustic';
      LBad.Add('training_status', 'completed');
      ExpectSaveFailure(LCatalog, LBad, LBefore);
      LBad.Delete('training_status');
      LBad.Arrays['sources'].Add(LBad.Arrays['sources'].Items[0].Clone);
      ExpectSaveFailure(LCatalog, LBad, LBefore);
      LBad.Arrays['sources'].Delete(1);
      LRow := TJSONObject(LBad.Arrays['sources'].Items[0]);
      LRow.Strings['selection'] := 'range';
      LRow.Add('start_frame', -1);
      LRow.Add('end_frame', 8000);
      ExpectSaveFailure(LCatalog, LBad, LBefore);
      LRow.Int64s['start_frame'] := 4000;
      LRow.Int64s['end_frame'] := 16001;
      ExpectSaveFailure(LCatalog, LBad, LBefore);
      LRow.Int64s['end_frame'] := 4000;
      ExpectSaveFailure(LCatalog, LBad, LBefore);
      LRow.Delete('start_frame');
      LRow.Add('start_frame', 0.5);
      LRow.Int64s['end_frame'] := 8000;
      ExpectSaveFailure(LCatalog, LBad, LBefore);
    finally
      LBad.Free;
    end;
    LWrite.Int64s['expected_revision'] := 1;
    LWrite.Strings['style_intent'] := 'Calm, varied phrases';
    LRow := TJSONObject(LWrite.Arrays['sources'].Items[0]);
    LRow.Strings['selection'] := 'range';
    LRow.Add('start_frame', 4000);
    LRow.Add('end_frame', 12000);
    LResult := SaveStudioProject(LCatalog, LWrite);
    try
      Check(LResult.Integers['revision'] = 2, 'Updated project receives stable second revision');
      LRow := TJSONObject(LResult.Arrays['sources'].Items[0]);
      Check((LRow.Int64s['start_frame'] = 4000) and (LRow.Int64s['end_frame'] = 12000),
        'Explicit half-open original frames survive update');
    finally
      LResult.Free;
    end;
    Check(HashFile(IncludeTrailingPathDelimiter(LCatalog) +
      'studio/projects/evening/00000001.json') = LRevisionOneHash,
      'Updating preserves immutable first revision bytes');
    LResult := ReadStudioProject(LCatalog, 'evening');
    try
      LBefore := LResult.AsJSON;
    finally
      LResult.Free;
    end;
    LResult := SaveStudioProject(LCatalog, LWrite);
    try
      Check(LResult.Booleans['already_saved'] and (LResult.Integers['revision'] = 2),
        'Updated identical retry preserves current revision');
    finally
      LResult.Free;
    end;
    LResult := ListStudioProjects(LCatalog);
    try
      Check(LResult.Integers['count'] = 1, 'List accepted project');
      LRow := TJSONObject(LResult.Arrays['projects'].Items[0]);
      Check((LRow.Integers['source_count'] = 1) and (LRow.Find('sources') = nil),
        'Project summaries omit full source snapshots');
    finally
      LResult.Free;
    end;
    LLockPath := IncludeTrailingPathDelimiter(LCatalog) + 'studio/projects/.write-lock';
    Check(CreateDir(LLockPath), 'Create explicit crash-leftover control');
    try
      ExpectSaveFailure(LCatalog, LWrite, LBefore, True);
      Check(DirectoryExists(LLockPath), 'Busy writer evidence is never silently erased');
    finally
      Check(RemoveDir(LLockPath), 'Recover only owned lock control');
    end;
    LStream := TFileStream.Create(IncludeTrailingPathDelimiter(LCatalog) +
      'sources/' + LHash + '.wav', fmOpenReadWrite);
    try
      LStream.Position := 44;
      LByte := 1;
      LStream.WriteBuffer(LByte, 1);
    finally
      LStream.Free;
    end;
    LWrite.Int64s['expected_revision'] := 2;
    LWrite.Strings['name'] := 'Header-only draft';
    LResult := SaveStudioProject(LCatalog, LWrite);
    try
      Check(LResult.Integers['revision'] = 3, 'Header admission does not hash PCM payload');
      LRow := TJSONObject(LResult.Arrays['sources'].Items[0]);
      Check(LRow.Strings['source_validation'] = StudioSourceValidation,
        'Changed payload remains explicitly unverified until training');
    finally
      LResult.Free;
    end;
    LStream := TFileStream.Create(IncludeTrailingPathDelimiter(LCatalog) +
      'sources/' + LHash + '.wav', fmOpenReadWrite);
    try
      LStream.Position := 44;
      LByte := 0;
      LStream.WriteBuffer(LByte, 1);
    finally
      LStream.Free;
    end;
    Check(HashFile(IncludeTrailingPathDelimiter(LCatalog) + 'sources/' + LHash + '.wav') = LHash,
      'Restore only controlled PCM mutation for later exact-fixture browser checks');
    LResult := ReadStudioProject(LCatalog, 'evening');
    try
      LBefore := LResult.AsJSON;
    finally
      LResult.Free;
    end;
    LTrackPath := IncludeTrailingPathDelimiter(LCatalog) + 'tracks/' + LHash + '.json';
    LTrack := ReadCatalogTrack(LCatalog, LHash);
    try
      LTrack.Int64s['frame_count'] := 15999;
      WriteJson(LTrackPath, LTrack);
      ExpectSaveFailure(LCatalog, LWrite, LBefore);
      LTrack.Int64s['frame_count'] := 16000;
      WriteJson(LTrackPath, LTrack);
    finally
      LTrack.Free;
    end;
    ExpectParseFailure('{');
    ExpectParseFailure('{"value":}');
    ExpectParseFailure('{"value":tru}');
    ExpectParseFailure('[]');
    ExpectParseFailure(StringOfChar('[', 9) + '0' + StringOfChar(']', 9));
    ExpectParseFailure(StringOfChar(' ', MaximumStudioDocumentBytes + 1));
    ExpectParseFailure('{"format":"a","format":"b"}');
    LBad := MakeWrite(LUnassignedHash);
    try
      LBad.Strings['project_id'] := 'pending';
      LBad.Strings['name'] := 'Unassigned draft';
      LBad.Strings['learning_mode'] := 'reference_events';
      LResult := SaveStudioProject(LCatalog, LBad);
      try
        LRow := TJSONObject(LResult.Arrays['sources'].Items[0]);
        Check((LRow.Strings['partition'] = 'unassigned') and
          (LRow.Strings['selection_status'] = 'pending_partition'),
          'Draft preserves unassigned partition without admission');
        Check((LRow.Strings['usage_status'] = 'selected_not_used') and
          (LResult.Arrays['used_sources'].Count = 0), 'Unassigned selection is never trained use');
      finally
        LResult.Free;
      end;
      LResult := ReadStudioProject(LCatalog, 'pending');
      try
        Check(LResult.Strings['learning_mode'] = 'reference_events',
          'Requested route survives durable reload as preference');
      finally
        LResult.Free;
      end;
      LResult := SaveStudioProject(LCatalog, LBad);
      try
        Check(LResult.Booleans['already_saved'] and (LResult.Integers['revision'] = 1),
          'Unassigned project identical retry creates no duplicate revision');
      finally
        LResult.Free;
      end;
    finally
      LBad.Free;
    end;
    LBad := MakeWrite(LHash);
    try
      LBad.Strings['project_id'] := 'classified-passages';
      LRow := TJSONObject(LBad.Arrays['sources'].Items[0]);
      LRow.Strings['selection'] := 'range';
      LRow.Add('start_frame', 0);
      LRow.Add('end_frame', 4000);
      LRow.Add('classifications', TJSONArray.Create(['gentle', 'intro']));
      LRow := TJSONObject(LRow.Clone);
      LBad.Arrays['sources'].Add(LRow);
      LRow.Int64s['start_frame'] := 8000;
      LRow.Int64s['end_frame'] := 12000;
      LRow.Arrays['classifications'].Strings[1] := 'outro';
      LResult := SaveStudioProject(LCatalog, LBad);
      try
        Check(LResult.Arrays['sources'].Count = 2,
          'Disjoint passages from one recording form two corpus selections');
        Check(TJSONObject(LResult.Arrays['sources'].Items[1]).Arrays['classifications'].
          Strings[1] = 'outro', 'Passage-specific classification is preserved');
      finally
        LResult.Free;
      end;
      LBad.Integers['expected_revision'] := 1;
      LRow.Arrays['classifications'].Strings[1] := 'sustained';
      LResult := SaveStudioProject(LCatalog, LBad);
      try
        Check(LResult.Integers['revision'] = 2, 'Classification edit creates a corpus revision');
      finally
        LResult.Free;
      end;
      LResult := ReadStudioProjectRevision(LCatalog, 'classified-passages', 1);
      try
        Check(TJSONObject(LResult.Arrays['sources'].Items[1]).Arrays['classifications'].
          Strings[1] = 'outro', 'Original corpus classification remains immutable');
      finally
        LResult.Free;
      end;
      LBad.Integers['expected_revision'] := 2;
      LRow.Int64s['start_frame'] := 3999;
      ExpectSaveFailure(LCatalog, LBad, LBefore);
      LRow.Int64s['start_frame'] := 8000;
      LRow.Arrays['classifications'].Strings[1] := 'gentle';
      ExpectSaveFailure(LCatalog, LBad, LBefore);
      LRow.Arrays['classifications'].Strings[1] := StringOfChar('x', 65);
      ExpectSaveFailure(LCatalog, LBad, LBefore);
    finally
      LBad.Free;
    end;
    { Big Boss: unchecked passages are durable, but never job inputs. }
    LBad := MakeWrite(LHash);
    try
      LBad.Strings['project_id'] := 'training-choices';
      LBad.Add('parked_sources', TJSONArray.Create);
      LRow := TJSONObject(LBad.Arrays['sources'].Items[0].Clone);
      LRow.Strings['selection'] := 'range';
      LRow.Add('start_frame', 0);
      LRow.Add('end_frame', 4000);
      LRow.Add('classifications', TJSONArray.Create(['kept for later']));
      LBad.Arrays['parked_sources'].Add(LRow);
      LResult := SaveStudioProject(LCatalog, LBad);
      try
        Check((LResult.Arrays['sources'].Count = 1) and
          (LResult.Arrays['parked_sources'].Count = 1),
          'Whole selection parks its overlapping passage without deleting it');
      finally
        LResult.Free;
      end;
      LResult := ReadStudioProject(LCatalog, 'training-choices');
      try
        Check(LResult.Arrays['parked_sources'].Objects[0].Arrays['classifications'].
          Strings[0] = 'kept for later', 'Unchecked passage labels survive disk reload');
      finally
        LResult.Free;
      end;
      LBad.Integers['expected_revision'] := 1;
      LBad.Arrays['parked_sources'].Add(LBad.Arrays['sources'].Items[0].Clone);
      LBad.Arrays['sources'].Delete(0);
      LBad.Arrays['sources'].Add(LBad.Arrays['parked_sources'].Items[0].Clone);
      LBad.Arrays['parked_sources'].Delete(0);
      LResult := SaveStudioProject(LCatalog, LBad);
      try
        Check((LResult.Arrays['sources'].Objects[0].Strings['selection'] = 'range') and
          (LResult.Arrays['parked_sources'].Objects[0].Strings['selection'] = 'full'),
          'Passage selection excludes the whole recording from training');
      finally
        LResult.Free;
      end;
      LBad.Integers['expected_revision'] := 2;
      LBad.Arrays['parked_sources'].Add(LBad.Arrays['sources'].Items[0].Clone);
      LBad.Arrays['sources'].Delete(0);
      LResult := SaveStudioProject(LCatalog, LBad);
      try
        Check((LResult.Arrays['sources'].Count = 0) and
          (LResult.Arrays['parked_sources'].Count = 2),
          'All unchecked choices can be saved without implicit whole-track inclusion');
      finally
        LResult.Free;
      end;
      LBad.Integers['expected_revision'] := 3;
      LBad.Arrays['parked_sources'].Objects[1].Int64s['end_frame'] := 16001;
      ExpectSaveFailure(LCatalog, LBad, LBefore);
    finally
      LBad.Free;
    end;
    LStream := OpenStudioSourceAudio(LCatalog, LHash);
    try
      Check(LStream.Size > 44, 'Original audition opens a streaming WAV');
    finally
      LStream.Free;
    end;
    Check(not DirectoryExists(IncludeTrailingPathDelimiter(LCatalog) + 'reviews'),
      'Project drafts create no reviewed labels');
    Check(not DirectoryExists(IncludeTrailingPathDelimiter(LCatalog) + 'proposals'),
      'Project drafts execute no proposal/training work');
  finally
    LWrite.Free;
  end;
  WriteLn('PASS ', GChecks, ' Studio project checks; catalog_snapshot_pending_training_verification');
end;

begin
  try
    Check(ParamCount = 1, 'Usage: pythian.tests.studio.projects FRESH_ROOT');
    Run(ParamStr(1));
  except
    on LException: Exception do
    begin
      WriteLn(StdErr, LException.ClassName, ': ', LException.Message);
      ExitCode := 1;
    end;
  end;
end.
