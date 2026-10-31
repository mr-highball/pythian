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
program StudioSavedClips;

{$mode delphi}
{$H+}

uses Classes, SysUtils, Math, fpjson, fphttpclient, pythian.tools.json,
  pythian.audio, pythian.progress,
  pythian.wave.read, pythian.wave.stream, pythian.stream.bytes,
  pythian.binary, pythian.tools.studio.clips,
  pythian.tools.studio.&library.discovery, pythian.tools.listen.assets,
  pythian.tools.studio.projects, pythian.tools.studio.jobs,
  pythian.tools.studio.worker;

type
  TProbe = class
    MaximumByteTotal: Int64;
    Updates: Integer;
    StopStage: String;
    procedure Observe(const AProgress: TWorkProgress);
  end;

var GChecks: Integer;

function HttpJson(const AText: RawByteString): TJSONObject;
begin
  Result := TJSONObject(ParseNativeJSON(AText, 1048576, 12));
end;

procedure CheckHttp(const ABase: String);
var
  LClient: TFPHTTPClient; LInput: TStringStream;
  LProject, LWrite, LSaved, LReload, LState, LSession: TJSONObject;
begin
  if Pos('http://127.0.0.1:', ABase) <> 1 then raise EAudio.Create('Use isolated loopback QA');
  LClient := TFPHTTPClient.Create(nil);
  LProject := nil; LWrite := nil; LSaved := nil; LReload := nil; LState := nil; LSession := nil;
  try
    LSession := HttpJson(LClient.Get(ABase + '/api/session'));
    LClient.AddHeader('X-Pythian-Token', LSession.Strings['token']);
    LClient.AddHeader('Origin', ABase);
    LClient.AddHeader('Content-Type', 'application/json; charset=utf-8');
    LProject := HttpJson(LClient.Get(ABase + '/api/studio/project?id=independent-clips'));
    LWrite := TJSONObject.Create(['format', StudioProjectWriteFormat,
      'project_id', 'clip-http-final', 'expected_revision', 0, 'name', 'HTTP saved clip',
      'style_intent', '', 'learning_mode', 'instrumental']);
    LWrite.Add('sources', TJSONArray.Create);
    LWrite.Add('playlist', LProject.Objects['playlist'].Clone);
    LWrite.Objects['playlist'].Arrays['items'].Objects[0].Arrays['clips'].Objects[0].Int64s['start_frame'] := 336000;
    LWrite.Objects['playlist'].Arrays['items'].Objects[0].Arrays['clips'].Objects[0].Int64s['end_frame'] := 368000;
    LInput := TStringStream.Create(WriteNativeJSON(LWrite, 32768));
    try
      LClient.RequestBody := LInput;
      LSaved := HttpJson(LClient.Post(ABase + '/api/studio/project'));
    finally LClient.RequestBody := nil; LInput.Free end;
    LReload := HttpJson(LClient.Get(ABase + '/api/studio/project?id=clip-http-final'));
    LSaved.Delete('already_saved');
    if LSaved.AsJSON <> LReload.AsJSON then raise EAudio.Create('Clip queue changed signed project response');
    LState := HttpJson(LClient.Get(ABase + '/api/studio/clips?project=clip-http-final&revision=1'));
    if (LState.Integers['total'] <> 1) or (LState.Find('job') = nil) or
      (LState.Objects['job'].Strings['kind'] <> 'clip_save') then
      raise EAudio.Create('HTTP Save did not queue independent clip creation');
    Writeln('PASS actual clip HTTP: signed save/reload and automatic durable queue');
  finally
    LSession.Free; LState.Free; LReload.Free; LSaved.Free; LWrite.Free; LProject.Free; LClient.Free;
  end;
end;

procedure Check(const ACondition: Boolean; const AMessage: String);
begin
  Inc(GChecks);
  if not ACondition then raise Exception.Create(AMessage);
end;

procedure TProbe.Observe(const AProgress: TWorkProgress);
begin
  Inc(Updates);
  if (AProgress.Units = wuBytes) and (AProgress.Total > MaximumByteTotal) then
    MaximumByteTotal := AProgress.Total;
  if (StopStage <> '') and (AProgress.Stage = StopStage) then
    raise EAbort.Create('Requested saved-clip cancellation');
end;

procedure WriteOriginal(const APath: String);
var LFormat: TWaveSampleFormat; LFile: TFileStream; LBytes: TAudioBytes;
  LDone, LCount, I, LValue: Integer;
begin
  ForceDirectories(ExtractFileDir(APath));
  LFormat := Default(TWaveSampleFormat);
  LFormat.SampleRate := 8000;
  LFormat.Channels := 1;
  LFormat.FormatTag := $FFFE;
  LFormat.EncodingTag := 1;
  LFormat.BitsPerSample := 24;
  LFormat.ValidBitsPerSample := 20;
  LFormat.ChannelMask := 4;
  LFile := TFileStream.Create(APath, fmCreate);
  try
    LBytes := WaveSampleHeader(LFormat, 480000);
    WriteStreamBytesExact(LFile, LBytes, 0, Length(LBytes));
    LDone := 0;
    while LDone < 480000 do
    begin
      LCount := 1024;
      if LCount > 480000 - LDone then LCount := 480000 - LDone;
      SetLength(LBytes, LCount * 3);
      for I := 0 to LCount - 1 do
      begin
        LValue := Round((120000 + (LDone + I) div 8) *
          Sin(2 * Pi * 220 * (LDone + I) / 8000)) * 16;
        if LValue < 0 then Inc(LValue, 16777216);
        WriteUnsignedLE(LBytes, I * 3, 3, LValue);
      end;
      WriteStreamBytesExact(LFile, LBytes, 0, Length(LBytes));
      Inc(LDone, LCount);
    end;
  finally LFile.Free end;
end;

procedure CheckJobs(const ACatalog, ALibrary, AOriginal: String; const AItem: TJSONObject);
var
  LWrite, LPlaylist, LItem, LRange, LSaved, LState, LAgain, LJob, LStatus, LSources: TJSONObject;
  LId, LRetry, LClipId, LAudioPath: String;
begin
  LWrite := TJSONObject.Create(['format', StudioProjectWriteFormat,
    'project_id', 'independent-clips', 'expected_revision', 0,
    'name', 'Independent clips', 'style_intent', '', 'learning_mode', 'instrumental']);
  LSaved := nil; LState := nil; LAgain := nil; LJob := nil; LStatus := nil; LSources := nil;
  try
    LWrite.Add('sources', TJSONArray.Create);
    LPlaylist := TJSONObject.Create(['format', StudioPlaylistFormat]);
    LWrite.Add('playlist', LPlaylist);
    LPlaylist.Add('items', TJSONArray.Create);
    LItem := TJSONObject(AItem.Clone);
    LPlaylist.Arrays['items'].Add(LItem);
    LItem.Delete('classifications');
    LItem.Add('influence', 3); LItem.Add('extent', 'clips'); LItem.Add('clips', TJSONArray.Create);
    LRange := TJSONObject.Create(['start_frame', 240000, 'end_frame', 272000, 'included', True]);
    LRange.Add('classifications', TJSONArray.Create(['warm']));
    LItem.Arrays['clips'].Add(LRange);
    LClipId := StudioClipIdentity(LItem, LRange);
    LSaved := SaveStudioProject(ACatalog, LWrite);
    LState := QueueStudioProjectClips(ACatalog, LSaved);
    LId := LState.Objects['job'].Strings['job_id'];
    Check((LState.Integers['ready'] = 0) and (LState.Objects['job'].Strings['status'] = 'queued'),
      'Saving queues a native clip job without synchronous parent copying');
    LAgain := QueueStudioProjectClips(ACatalog, LSaved);
    Check(LAgain.Objects['job'].Strings['job_id'] = LId, 'Repeated queue request reconciles to the same clip job');
    FreeAndNil(LAgain);
    LStatus := CancelStudioJob(ACatalog, LId); FreeAndNil(LStatus);
    LAgain := QueueStudioProjectClips(ACatalog, LSaved, LId);
    LRetry := LAgain.Objects['job'].Strings['job_id']; FreeAndNil(LAgain);
    LAgain := QueueStudioProjectClips(ACatalog, LSaved, LId);
    Check((LRetry <> LId) and (LAgain.Objects['job'].Strings['job_id'] = LRetry),
      'Explicit stopped-job retry is itself idempotent');
    FreeAndNil(LAgain);
    Check(RunStudioWorker(ACatalog, LRetry, ALibrary), 'Actual native clip worker succeeds');
    LAgain := StudioProjectClipState(ACatalog, LSaved);
    Check((LAgain.Integers['ready'] = 1) and
      (LAgain.Objects['job'].Strings['status'] = 'completed'), 'Completed native clip storage survives status reconnect');
    FreeAndNil(LAgain);
    Check(RenameFile(AOriginal, AOriginal + '.held'), 'Hold original during actual clip learning');
    try
      LJob := TJSONObject.Create(['format', StudioJobWriteFormat, 'job_id', 'learn-saved-clip',
        'kind', 'instrumental_generate', 'project_id', LSaved.Strings['project_id'],
        'project_revision', LSaved.Integers['revision'],
        'project_snapshot_sha256', LSaved.Strings['snapshot_sha256'], 'duration_ms', 2000]);
      LJob.Add('seeds', TJSONArray.Create([719]));
      LJob.Add('instrumental', TJSONObject.Create(['tempo_bpm', 120, 'tonic', 0, 'cells', 16]));
      LJob.Objects['instrumental'].Add('instruments', TJSONArray.Create(['sine', 'triangle', 'saw']));
      LJob.Objects['instrumental'].Add('levels', TJSONArray.Create([70,65,60,80,60,50]));
      LStatus := EnqueueStudioJob(ACatalog, LJob); FreeAndNil(LStatus);
      Check(RunStudioWorker(ACatalog, 'learn-saved-clip', ALibrary),
        'Actual synthesis learns and stages its reference while the original is unavailable');
      LStatus := ReadStudioJob(ACatalog, 'learn-saved-clip');
      Check((LStatus.Strings['status'] = 'completed') and
        (LStatus.Objects['results'].Objects['playlist_learning'].Arrays['audio_sources'].Objects[0].Objects['clip_receipt'].Strings['clip_id'] = LClipId) and
        (LStatus.Objects['results'].Objects['playlist_learning'].Objects['reference_source'].Strings['kind'] = 'saved_clip'),
        'Actual output binds the saved clip and its selected-audio comparison');
      Check(not DirectoryExists(ACatalog + '/sources'), 'Clip-only learning never creates a full-parent catalog copy');
      LAudioPath := ListeningAssetPath(ACatalog,
        LStatus.Objects['results'].Objects['playlist_learning'].Arrays['audio_sources'].Objects[0].Strings['source_sha256']);
      FreeAndNil(LStatus);
      Check(RenameFile(LAudioPath, LAudioPath + '.held'), 'Hold accepted clip for actual failure-path check');
      try
        LJob.Strings['job_id'] := 'missing-saved-clip';
        LStatus := EnqueueStudioJob(ACatalog, LJob); FreeAndNil(LStatus);
        Check(not RunStudioWorker(ACatalog, 'missing-saved-clip', ALibrary),
          'Actual learning rejects a missing accepted clip');
        LStatus := ReadStudioJob(ACatalog, 'missing-saved-clip');
        Check((LStatus.Strings['status'] = 'failed') and
          (Pos('original is not substituted', LStatus.Strings['error_message']) > 0),
          'Missing-clip failure is retained without silently rebuilding from its parent');
      finally
        Check(RenameFile(LAudioPath + '.held', LAudioPath), 'Restore accepted clip after actual failure check');
      end;
      LSources := ListStudioSources(ACatalog);
      Check(LSources.Arrays['sources'].Count = 0, 'Metadata listing remains available without a full-parent catalog asset');
    finally
      Check(RenameFile(AOriginal + '.held', AOriginal), 'Restore original after unavailable-parent checks');
    end;
  finally
    LSources.Free; LStatus.Free; LJob.Free; LAgain.Free; LState.Free; LSaved.Free; LWrite.Free;
  end;
end;

procedure Run(const ARoot: String);
var
  LCatalog, LLibrary, LOriginal, LId, LAudio, LHash: String;
  LDiscovery, LItem, LClip, LReceipt, LRead, LCancelled: TJSONObject;
  LInput, LCorrupt: TFileStream;
  LWave: TWaveFrameReader;
  LProbe: TProbe;
  LRejected: Boolean;
  LByte: Byte;
begin
  Check(not DirectoryExists(ARoot), 'Use a fresh isolated clip fixture');
  LCatalog := IncludeTrailingPathDelimiter(ARoot) + 'catalog';
  LLibrary := IncludeTrailingPathDelimiter(ARoot) + 'library';
  LOriginal := LLibrary + '/collections/Examples/Original.wav';
  ForceDirectories(LCatalog);
  ForceDirectories(LCatalog + '/tracks');
  ForceDirectories(ARoot + '/inbox');
  WriteOriginal(LOriginal);
  LDiscovery := DiscoverStudioLibrary(LCatalog, LLibrary);
  LItem := TJSONObject.Create(['kind', 'library',
    'id', LDiscovery.Arrays['entries'].Objects[0].Strings['entry_id'],
    'snapshot_sha256', LDiscovery.Arrays['entries'].Objects[0].Strings['entry_snapshot_sha256'],
    'discovery_revision', LDiscovery.Integers['revision'], 'title', 'Original',
    'sample_rate', 8000, 'frame_count', 480000]);
  LClip := TJSONObject.Create(['start_frame', 160000, 'end_frame', 200000]);
  LReceipt := nil;
  LRead := nil;
  LInput := nil;
  LWave := nil;
  LCancelled := nil;
  LProbe := TProbe.Create;
  try
    LId := StudioClipIdentity(LItem, LClip);
    LReceipt := PrepareStudioClip(LCatalog, LLibrary, 'clip-capture', LItem, LClip, LProbe.Observe);
    Check((LReceipt.Strings['clip_id'] = LId) and
      (LReceipt.Objects['audio'].Int64s['frames'] = 40000), 'Independent clip has its exact range and identity');
    Check((LProbe.Updates > 3) and (LProbe.MaximumByteTotal = 120000),
      'Native clip creation reports only the selected PCM extent, not the full parent');
    Check(Pos('not_hashed', LReceipt.Strings['parent_content_validation']) > 0,
      'Metadata-only parent admission is not presented as a measured full-file hash');
    Check(LReceipt.Objects['parent_metadata'].Strings['license'] <> '', 'Private source license context survives');
    LHash := LReceipt.Objects['audio'].Strings['sha256'];
    LAudio := ListeningAssetPath(LCatalog, LHash);
    Check(RenameFile(LOriginal, LOriginal + '.held'), 'Temporarily hold the isolated original');
    try
      LInput := OpenStudioClip(LCatalog, LId, LHash, LRead, LProbe.Observe);
      LWave := TWaveFrameReader.Create(LInput);
      Check((LWave.FrameCount = 40000) and (LWave.BitsPerSample = 24) and
        (LWave.ValidBitsPerSample = 20) and (LWave.ChannelMask = 4),
        'Independent clip preserves extensible precision/layout with original unavailable');
      FreeAndNil(LWave);
      FreeAndNil(LInput);
      FreeAndNil(LRead);
      LRead := PrepareStudioClip(LCatalog, LLibrary, 'clip-reuse', LItem, LClip, LProbe.Observe);
      Check(LRead.AsJSON = LReceipt.AsJSON, 'An existing clip reuses its immutable receipt without opening parent');
      FreeAndNil(LRead);
      LClip.Add('classifications', TJSONArray.Create(['warm']));
      Check(StudioClipIdentity(LItem, LClip) = LId, 'Labels do not duplicate saved audio');
      LCorrupt := TFileStream.Create(LAudio, fmOpenReadWrite);
      try
        LCorrupt.Position := 100;
        LCorrupt.ReadBuffer(LByte, 1);
        LCorrupt.Position := 100;
        LCorrupt.WriteByte(LByte xor 1);
      finally LCorrupt.Free end;
      try
        LRejected := False;
        try LInput := OpenStudioClip(LCatalog, LId, LHash, LRead);
        except on E: EAudio do LRejected := True end;
        Check(LRejected and (LInput = nil) and (LRead = nil), 'Corrupt clip cannot fall back to a parent or publish a handle');
      finally
        LCorrupt := TFileStream.Create(LAudio, fmOpenReadWrite);
        try LCorrupt.Position := 100; LCorrupt.WriteByte(LByte) finally LCorrupt.Free end;
      end;
      Check(RenameFile(LAudio, LAudio + '.held'), 'Temporarily hold independent clip');
      try
        LRejected := False;
        try LRead := PrepareStudioClip(LCatalog, LLibrary, 'clip-missing', LItem, LClip);
        except on E: EAudio do LRejected := True end;
        Check(LRejected and (LRead = nil), 'A missing accepted clip is not silently recreated from its original');
      finally Check(RenameFile(LAudio + '.held', LAudio), 'Restore independent clip') end;
    finally Check(RenameFile(LOriginal + '.held', LOriginal), 'Restore isolated original') end;
    LClip.Int64s['start_frame'] := 240000;
    LClip.Int64s['end_frame'] := 280000;
    LProbe.StopStage := 'clip_ready';
    LRejected := False;
    try LCancelled := PrepareStudioClip(LCatalog, LLibrary, 'clip-cancel', LItem, LClip, LProbe.Observe);
    except on E: EAbort do LRejected := True end;
    Check(LRejected and (LCancelled = nil), 'Final readiness cancellation returns no accepted clip');
    LRead := ReadStudioClip(LCatalog, StudioClipIdentity(LItem, LClip));
    Check(LRead = nil, 'Cancelled publication leaves no accepted origin receipt');
    LProbe.StopStage := '';
    LRead := PrepareStudioClip(LCatalog, LLibrary, 'clip-after-cancel', LItem, LClip, LProbe.Observe);
    Check(LRead.Strings['status'] = 'completed', 'Fresh capture succeeds while preserving prior failure evidence');
    CheckJobs(LCatalog, LLibrary, LOriginal, LItem);
  finally
    LCancelled.Free;
    LWave.Free;
    LInput.Free;
    LRead.Free;
    LReceipt.Free;
    LProbe.Free;
    LClip.Free;
    LItem.Free;
    LDiscovery.Free;
  end;
end;

begin
  try
    if (ParamCount = 2) and (ParamStr(1) = '--http') then
      CheckHttp(ParamStr(2))
    else
    begin
      if ParamCount <> 1 then raise EAudio.Create('Usage: clip checks FRESH_ROOT, or --http LOOPBACK_BASE');
      Run(ExpandFileName(ParamStr(1)));
      Writeln('PASS saved clips: ', GChecks, ' checks');
    end;
  except
    on E: Exception do begin Writeln(StdErr, E.ClassName, ': ', E.Message); ExitCode := 1 end;
  end;
end.
