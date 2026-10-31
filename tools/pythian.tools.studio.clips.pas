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
unit pythian.tools.studio.clips;

{$mode delphi}
{$H+}

interface

uses Classes, fpjson, pythian.progress;

{ Canonical playlist parent and half-open original range. Labels/influence do
  not change audio identity; the playlist retains those separate choices. }
function StudioClipRecipe(const AItem, AClip: TJSONObject): TJSONObject;
function StudioClipIdentity(const AItem, AClip: TJSONObject): String;
{ Nil means not yet captured. An existing invalid receipt/file is an error,
  never authorization to silently replace it from a parent recording. Metadata
  inspection does not read source or clip audio; learning uses Open below. }
function ReadStudioClip(const ACatalogRoot, AClipId: String): TJSONObject;
{ Verifies just the independent clip, returning an owned seekable handle and
  receipt. It never opens the parent. Expected hash may be empty for status-free
  callers; accepted learning/reference callers bind their recorded hash.
  AVerifyContent=False is only for bounded provisional audition or a media
  dispatcher that performs the canonical store's own integrity admission. }
function OpenStudioClip(const ACatalogRoot, AClipId, AExpectedHash: String;
  out AReceipt: TJSONObject;
  const AProgress: TWorkProgressCallback = nil;
  const AVerifyContent: Boolean = True): TFileStream;
function PrepareStudioClip(const ACatalogRoot, ALibraryRoot, AJobId: String;
  const AItem, AClip: TJSONObject;
  const AProgress: TWorkProgressCallback = nil): TJSONObject;
function PrepareStudioPlaylistClips(const ACatalogRoot, ALibraryRoot, AJobId: String;
  const APlaylist: TJSONObject;
  const AProgress: TWorkProgressCallback = nil): TJSONObject;
{ Metadata-only status and durable automatic save. The project must be an
  accepted immutable snapshot. A retry explicitly names the last failed or
  cancelled save; repeated submissions reconcile to one deterministic job. }
function StudioProjectClipState(const ACatalogRoot: String;
  const AProject: TJSONObject): TJSONObject;
function QueueStudioProjectClips(const ACatalogRoot: String;
  const AProject: TJSONObject; const ARetryOf: String = ''): TJSONObject;
function RequestStudioProjectClips(const ACatalogRoot: String;
  const ARequest: TJSONObject): TJSONObject;

implementation

uses SysUtils, pythian.audio, pythian.hash, pythian.wave.read,
  pythian.tools.listen.assets, pythian.tools.studio.jobs,
  pythian.tools.studio.projects, pythian.tools.studio.&library.discovery;

procedure Need(const ACondition: Boolean; const AMessage: String);
begin
  if not ACondition then raise EAudio.Create(AMessage);
end;

procedure RequireHash(const AHash: String);
var LBytes: array[0..63] of Byte;
begin
  WriteSha256Hex(LBytes, 0, AHash);
end;

function ClipRecordPath(const ACatalogRoot, AClipId: String): String;
begin
  RequireHash(AClipId);
  Result := ListeningAssetDirectory(ACatalogRoot) + PathDelim + 'clips' +
    PathDelim + AClipId + '.json';
end;

function StudioClipRecipe(const AItem, AClip: TJSONObject): TJSONObject;
begin
  Need((AItem <> nil) and (AClip <> nil), 'A saved clip needs its original recording and range');
  Need((AItem.Strings['kind'] = 'library') or (AItem.Strings['kind'] = 'catalog'),
    'Unsupported saved clip parent');
  RequireHash(AItem.Strings['id']);
  RequireHash(AItem.Strings['snapshot_sha256']);
  Need((AClip.Int64s['start_frame'] >= 0) and
    (AClip.Int64s['end_frame'] > AClip.Int64s['start_frame']) and
    (AClip.Int64s['end_frame'] <= AItem.Int64s['frame_count']),
    'Saved clip lies outside its original recording');
  Need((AItem.Integers['sample_rate'] > 0) and
    (AItem.Integers['sample_rate'] <= MaximumSampleRate), 'Saved clip has an invalid clock');
  Result := TJSONObject.Create(['format', 'pythian.studio.clip.recipe.v1',
    'parent_kind', AItem.Strings['kind'], 'parent_id', AItem.Strings['id'],
    'parent_snapshot_sha256', AItem.Strings['snapshot_sha256'],
    'discovery_revision', AItem.Integers['discovery_revision'],
    'sample_rate', AItem.Integers['sample_rate'],
    'parent_frame_count', AItem.Int64s['frame_count'],
    'start_frame', AClip.Int64s['start_frame'], 'end_frame', AClip.Int64s['end_frame']]);
end;

function StudioClipIdentity(const AItem, AClip: TJSONObject): String;
var LRecipe: TJSONObject;
begin
  LRecipe := StudioClipRecipe(AItem, AClip);
  try Result := StudioTextHash(LRecipe.AsJSON) finally LRecipe.Free end;
end;

function ReadStudioClip(const ACatalogRoot, AClipId: String): TJSONObject;
var LPath: String; LRecipe, LOutput: TJSONObject;
begin
  LPath := ClipRecordPath(ACatalogRoot, AClipId);
  if not FileExists(LPath) then Exit(nil);
  Result := ReadStudioJSON(LPath);
  try
    Need((Result.Strings['format'] = 'pythian.studio.clip.v1') and
      (Result.Strings['status'] = 'completed') and
      (Result.Strings['clip_id'] = AClipId), 'Saved clip receipt is incomplete');
    LRecipe := Result.Objects['recipe'];
    Need((LRecipe.Strings['format'] = 'pythian.studio.clip.recipe.v1') and
      (StudioTextHash(LRecipe.AsJSON) = AClipId), 'Saved clip origin differs from its identity');
    LOutput := Result.Objects['audio'];
    RequireHash(LOutput.Strings['sha256']);
    Need((LOutput.Int64s['bytes'] > 0) and
      (LOutput.Integers['sample_rate'] = LRecipe.Integers['sample_rate']) and
      (LOutput.Int64s['frames'] = LRecipe.Int64s['end_frame'] - LRecipe.Int64s['start_frame']),
      'Saved clip audio differs from its original range');
    Need(FileExists(ListeningAssetPath(ACatalogRoot, LOutput.Strings['sha256'])),
      'Saved clip audio is missing; its original is not substituted');
  except
    FreeAndNil(Result);
    raise;
  end;
end;

function OpenStudioClip(const ACatalogRoot, AClipId, AExpectedHash: String;
  out AReceipt: TJSONObject; const AProgress: TWorkProgressCallback;
  const AVerifyContent: Boolean): TFileStream;
var LReader: TWaveFrameReader; LOutput: TJSONObject;
begin
  Result := nil;
  AReceipt := ReadStudioClip(ACatalogRoot, AClipId);
  LReader := nil;
  try
    try
    Need(AReceipt <> nil, 'This clip has not finished saving');
    LOutput := AReceipt.Objects['audio'];
    Need((AExpectedHash = '') or (AExpectedHash = LOutput.Strings['sha256']),
      'Saved clip differs from the selected audio');
    Result := OpenStudioReadStream(ListeningAssetPath(ACatalogRoot, LOutput.Strings['sha256']));
    Need(Result.Size = LOutput.Int64s['bytes'],
      'Saved clip bytes differ; its original is not substituted');
    if AVerifyContent then
      Need(Sha256Stream(Result, Result.Size, AProgress) = LOutput.Strings['sha256'],
        'Saved clip bytes differ; its original is not substituted');
    Result.Position := 0;
    LReader := TWaveFrameReader.Create(Result);
    Need((LReader.FrameCount = LOutput.Int64s['frames']) and
      (LReader.SampleRate = LOutput.Integers['sample_rate']) and
      (LReader.Channels = LOutput.Integers['channels']), 'Saved clip geometry differs');
    Result.Position := 0;
    if AVerifyContent then ReportWork(AProgress, 'clip_verified', wuBytes, Result.Size, Result.Size)
    else ReportWork(AProgress, 'clip_open', wuItems, 1, 1);
  except
    FreeAndNil(Result);
    FreeAndNil(AReceipt);
    raise;
    end;
  finally
    LReader.Free;
  end;
end;

function PrepareStudioClip(const ACatalogRoot, ALibraryRoot, AJobId: String;
  const AItem, AClip: TJSONObject; const AProgress: TWorkProgressCallback): TJSONObject;
var
  LRecipe, LParent, LMetadata, LStored, LExisting: TJSONObject;
  LInput: TFileStream;
  LReader: TWaveFrameReader;
  LWriter: TListeningAssetWriter;
  LId: String;
begin
  Result := nil;
  LRecipe := StudioClipRecipe(AItem, AClip);
  LParent := nil;
  LMetadata := nil;
  LStored := nil;
  LExisting := nil;
  LInput := nil;
  LReader := nil;
  LWriter := nil;
  try
    try
    LId := StudioTextHash(LRecipe.AsJSON);
    LExisting := ReadStudioClip(ACatalogRoot, LId);
    if LExisting <> nil then
    begin
      LInput := OpenStudioClip(ACatalogRoot, LId, '', Result, AProgress);
      Exit;
    end;
    ReportWork(AProgress, 'clip_open_parent', wuItems, 0, 1);
    if AItem.Strings['kind'] = 'catalog' then
    begin
      LParent := ReadStudioSourceMetadata(ACatalogRoot, AItem.Strings['id']);
      Need(LParent.Strings['metadata_sha256'] = AItem.Strings['snapshot_sha256'],
        'Original metadata changed before clip saving');
      LInput := OpenStudioSourceAudio(ACatalogRoot, AItem.Strings['id']);
    end
    else
      LInput := OpenStudioLibraryEntrySource(ACatalogRoot, ALibraryRoot,
        AItem.Integers['discovery_revision'], AItem.Strings['id'],
        AItem.Strings['snapshot_sha256'], LParent);
    LReader := TWaveFrameReader.Create(LInput);
    Need((LReader.SampleRate = AItem.Integers['sample_rate']) and
      (LReader.FrameCount = AItem.Int64s['frame_count']), 'Original clock changed before clip saving');
    LMetadata := TJSONObject.Create(['title', AItem.Strings['title'],
      'source_group', LParent.Get('source_group', 'library_entry_' + AItem.Strings['id']),
      'clock_id', LParent.Get('clock_id', ''), 'partition', LParent.Get('partition', 'unassigned'),
      'license', LParent.Get('license', 'unknown/private; recording rights unverified'),
      'provenance', LParent.Get('provenance', 'Private operator folder input; recording origin unverified')]);
    Need(LMetadata.Strings['partition'] <> 'evaluation', 'Reserved evaluation audio cannot become a teaching clip');
    LWriter := TListeningAssetWriter.Create(ACatalogRoot, AJobId + '-clip');
    LReader.CopyRangeToWave(LWriter, AClip.Int64s['start_frame'], AClip.Int64s['end_frame'], AProgress);
    ReportWork(AProgress, 'clip_publish', wuItems, 0, 1);
    LStored := LWriter.Finish;
    Need((LStored.Int64s['frames'] = AClip.Int64s['end_frame'] - AClip.Int64s['start_frame']) and
      (LStored.Integers['sample_rate'] = AItem.Integers['sample_rate']), 'Saved clip output clock differs');
    Result := TJSONObject.Create(['format', 'pythian.studio.clip.v1', 'status', 'completed',
      'clip_id', LId,
      'parent_content_validation', 'metadata_snapshot_at_capture; full_parent_payload_not_hashed',
      'sample_encoding', 'unchanged_source_sample_bytes']);
    Result.Add('recipe', LRecipe.Clone);
    Result.Add('parent_metadata', LMetadata.Clone);
    Result.Add('audio', LStored.Clone);
    ReportWork(AProgress, 'clip_ready', wuItems, 1, 1);
    { Big Boss: primary audio publication precedes the immutable origin receipt.
      Cancellation/partial output cannot create an accepted clip reference. }
    WriteStudioJSONNew(ClipRecordPath(ACatalogRoot, LId), Result);
  except
    FreeAndNil(Result);
    raise;
    end;
  finally
    LWriter.Free;
    LReader.Free;
    LInput.Free;
    LExisting.Free;
    LStored.Free;
    LMetadata.Free;
    LParent.Free;
    LRecipe.Free;
  end;
end;

function PrepareStudioPlaylistClips(const ACatalogRoot, ALibraryRoot, AJobId: String;
  const APlaylist: TJSONObject; const AProgress: TWorkProgressCallback): TJSONObject;
var LPlaylist, LItem, LClip: TJSONObject; LRows: TJSONArray; I, J, LTotal, LDone: Integer;
begin
  Result := nil;
  LPlaylist := CanonicalStudioPlaylist(APlaylist);
  try
    try
    LTotal := 0;
    for I := 0 to LPlaylist.Arrays['items'].Count - 1 do
      Inc(LTotal, LPlaylist.Arrays['items'].Objects[I].Arrays['clips'].Count);
    Result := TJSONObject.Create(['format', 'pythian.studio.clips.v1']);
    LRows := TJSONArray.Create;
    Result.Add('clips', LRows);
    LDone := 0;
    for I := 0 to LPlaylist.Arrays['items'].Count - 1 do
    begin
      LItem := LPlaylist.Arrays['items'].Objects[I];
      for J := 0 to LItem.Arrays['clips'].Count - 1 do
      begin
        ReportWork(AProgress, 'clip_save_progress', wuItems, LDone, LTotal);
        LClip := PrepareStudioClip(ACatalogRoot, ALibraryRoot, AJobId,
          LItem, LItem.Arrays['clips'].Objects[J], AProgress);
        LRows.Add(LClip);
        Inc(LDone);
      end;
    end;
    ReportWork(AProgress, 'clip_save_progress', wuItems, LDone, LTotal);
  except
    FreeAndNil(Result);
    raise;
    end;
  finally
    LPlaylist.Free;
  end;
end;

function ClipJobId(const AProject: TJSONObject; const ARetryOf: String): String;
begin
  if ARetryOf = '' then Result := 'clips-' + Copy(AProject.Strings['snapshot_sha256'], 1, 48)
  else Result := 'clips-' + Copy(StudioTextHash('retry|' +
    AProject.Strings['snapshot_sha256'] + '|' + ARetryOf), 1, 48);
end;

function LastClipJob(const ACatalogRoot: String; const AProject: TJSONObject): TJSONObject;
var LId: String; LRequest: TJSONObject; I: Integer;
begin
  Result := nil;
  LId := ClipJobId(AProject, '');
  try
    for I := 0 to MaximumStudioJobs - 1 do
    begin
      if not FileExists(StudioJobDirectory(ACatalogRoot, LId) + PathDelim + 'request.json') then Exit;
      LRequest := ReadStudioJobRequest(ACatalogRoot, LId);
      try
        Need((LRequest.Strings['kind'] = 'clip_save') and
          (LRequest.Strings['project_id'] = AProject.Strings['project_id']) and
          (LRequest.Strings['project_snapshot_sha256'] = AProject.Strings['snapshot_sha256']),
          'Clip save history differs from its playlist');
      finally LRequest.Free end;
      FreeAndNil(Result);
      Result := ReadStudioJob(ACatalogRoot, LId);
      LId := ClipJobId(AProject, LId);
    end;
    raise EAudio.Create('Clip save retry history exceeds the retained job bound');
  except
    FreeAndNil(Result);
    raise;
  end;
end;

function StudioProjectClipState(const ACatalogRoot: String;
  const AProject: TJSONObject): TJSONObject;
var
  LRows: TJSONArray;
  LItem, LClip, LRow, LSaved, LJob: TJSONObject;
  I, J, LReady, LErrors: Integer;
  LId: String;
begin
  Result := TJSONObject.Create(['format', 'pythian.studio.clips.v1',
    'project_id', AProject.Strings['project_id'],
    'project_snapshot_sha256', AProject.Strings['snapshot_sha256']]);
  try
    LRows := TJSONArray.Create;
    Result.Add('clips', LRows);
    LReady := 0;
    LErrors := 0;
    if AProject.Find('playlist') <> nil then
      for I := 0 to AProject.Objects['playlist'].Arrays['items'].Count - 1 do
      begin
        LItem := AProject.Objects['playlist'].Arrays['items'].Objects[I];
        for J := 0 to LItem.Arrays['clips'].Count - 1 do
        begin
          LClip := LItem.Arrays['clips'].Objects[J];
          LId := StudioClipIdentity(LItem, LClip);
          LRow := TJSONObject.Create(['clip_id', LId, 'parent_kind', LItem.Strings['kind'],
            'parent_id', LItem.Strings['id'], 'parent_snapshot_sha256', LItem.Strings['snapshot_sha256'],
            'start_frame', LClip.Int64s['start_frame'], 'end_frame', LClip.Int64s['end_frame'],
            'status', 'not_saved']);
          LRows.Add(LRow);
          LSaved := nil;
          try
            try
              LSaved := ReadStudioClip(ACatalogRoot, LId);
              if LSaved <> nil then
              begin
                LRow.Strings['status'] := 'ready';
                LRow.Add('audio_sha256', LSaved.Objects['audio'].Strings['sha256']);
                LRow.Add('bytes', LSaved.Objects['audio'].Int64s['bytes']);
                Inc(LReady);
              end;
            except
              on E: EOutOfMemory do raise;
              on E: Exception do
              begin
                LRow.Strings['status'] := 'error';
                Inc(LErrors);
              end;
            end;
          finally LSaved.Free end;
        end;
      end;
    Result.Add('total', LRows.Count);
    Result.Add('ready', LReady);
    Result.Add('errors', LErrors);
    LJob := LastClipJob(ACatalogRoot, AProject);
    if LJob <> nil then
    begin
      LJob.Delete('results');
      Result.Add('job', LJob);
    end;
  except
    FreeAndNil(Result);
    raise;
  end;
end;

function QueueStudioProjectClips(const ACatalogRoot: String;
  const AProject: TJSONObject; const ARetryOf: String): TJSONObject;
var LState, LJob, LWrite, LQueued: TJSONObject; LTargetExists: Boolean;
begin
  LState := StudioProjectClipState(ACatalogRoot, AProject);
  LWrite := nil;
  LQueued := nil;
  try
    if LState.Integers['ready'] = LState.Integers['total'] then
    begin
      Result := LState;
      LState := nil;
      Exit;
    end;
    LTargetExists := FileExists(StudioJobDirectory(ACatalogRoot, ClipJobId(AProject, ARetryOf)) +
      PathDelim + 'request.json');
    if (ARetryOf <> '') and not LTargetExists then
    begin
      LJob := LState.Objects['job'];
      Need((LJob.Strings['job_id'] = ARetryOf) and
        ((LJob.Strings['status'] = 'failed') or (LJob.Strings['status'] = 'cancelled')),
        'Retry must name the last stopped clip save');
    end;
    LWrite := TJSONObject.Create(['format', StudioJobWriteFormat,
      'job_id', ClipJobId(AProject, ARetryOf), 'kind', 'clip_save',
      'project_id', AProject.Strings['project_id'], 'project_revision', AProject.Integers['revision'],
      'project_snapshot_sha256', AProject.Strings['snapshot_sha256']]);
    if ARetryOf <> '' then LWrite.Add('retry_of', ARetryOf);
    LQueued := EnqueueStudioJob(ACatalogRoot, LWrite);
    Result := StudioProjectClipState(ACatalogRoot, AProject);
  finally
    LQueued.Free;
    LWrite.Free;
    LState.Free;
  end;
end;

function RequestStudioProjectClips(const ACatalogRoot: String;
  const ARequest: TJSONObject): TJSONObject;
var LProject: TJSONObject; I: Integer; LName: String;
begin
  Need((ARequest <> nil) and (ARequest.Count >= 3) and (ARequest.Count <= 4),
    'Clip saving needs a saved playlist');
  for I := 0 to ARequest.Count - 1 do
  begin
    LName := ARequest.Names[I];
    Need(Pos('|' + LName + '|', '|project_id|project_revision|project_snapshot_sha256|retry_of|') > 0,
      'Unsupported clip save field');
  end;
  LProject := ReadStudioProjectRevision(ACatalogRoot, ARequest.Strings['project_id'],
    ARequest.Integers['project_revision']);
  try
    Need(LProject.Strings['snapshot_sha256'] = ARequest.Strings['project_snapshot_sha256'],
      'Playlist changed before clip saving; reopen the saved selection');
    Result := QueueStudioProjectClips(ACatalogRoot, LProject, ARequest.Get('retry_of', ''));
  finally LProject.Free end;
end;

end.
