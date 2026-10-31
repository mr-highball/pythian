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
program StudioPlaylistConformance;
{$mode delphi}
{$H+}
uses Classes, SysUtils, Math, fpjson, pythian.audio, pythian.wave, pythian.progress,
  pythian.tools.studio.projects, pythian.tools.studio.&library.discovery,
  pythian.tools.studio.jobs, pythian.tools.studio.playlist.learning,
  pythian.tools.studio.worker, pythian.tools.listen.catalog,
  pythian.wfc.musical.corpus, pythian.wfc.layers,
  wfc_sequence, wfc_sequence_text;
var GChecks: Integer;
type
  TSelectionProgress = class
    Done: Int64;
    Total: Int64;
    Updates: Integer;
    procedure Observe(const AProgress: TWorkProgress);
  end;
procedure Check(const AValue: Boolean; const AMessage: String);
begin
  Inc(GChecks);
  if not AValue then raise Exception.Create(AMessage);
end;
procedure TSelectionProgress.Observe(const AProgress: TWorkProgress);
begin
  if AProgress.Stage <> 'playlist_selection_progress' then Exit;
  Check((AProgress.Units = wuMilliseconds) and (AProgress.Total > 0),
    'Whole selection progress uses actual audio time');
  Check((Updates = 0) or ((AProgress.Total = Total) and (AProgress.Done >= Done)),
    'Whole selection counters stay monotonic across windows and mixed-rate tracks');
  Total := AProgress.Total;
  Done := AProgress.Done;
  Inc(Updates);
end;
procedure Audio(const APath: String; const AFrequency, ARate, ASeconds: Integer);
var LSamples: TAudioSamples; LClip: TAudioClip; I: Integer;
begin
  Check(ForceDirectories(ExtractFileDir(APath)), 'Create private fixture collection');
  SetLength(LSamples, ARate * ASeconds);
  for I := 0 to High(LSamples) do LSamples[I] := 0.03 * Sin(I * 2 * Pi * AFrequency / ARate);
  LClip := TAudioClip.Create(ARate, 1, LSamples);
  try SaveWavePcm16(APath, LClip) finally LClip.Free end;
end;
procedure CheckLearning(const ARoot, ACatalog, ALibrary: String; const APlaylist: TJSONObject);
var
  LCold: TMusicalCorpus;
  LWarm: TMusicalCorpus;
  LReceipt: TJSONObject;
  LBefore: TLayerModelTexts;
  LAfter: TLayerModelTexts;
  LClip: TJSONObject;
  LItem: TJSONObject;
  LClips: TJSONArray;
  LDirectory: String;
  I: Integer;
  LDifferent: Boolean;
  LProgress: TSelectionProgress;
  LRate: Integer;
begin
  LCold := nil;
  LWarm := nil;
  LReceipt := nil;
  LProgress := TSelectionProgress.Create;
  LDirectory := GetCurrentDir;
  try
    { Existing native importer staging is relative to runtime cwd. Keep it in
      this isolated E-drive fixture, as the deployed service does. }
    SetCurrentDir(ARoot);
    LCold := LearnStudioPlaylist(ACatalog, ALibrary, ARoot + '/cache',
      'playlist-learning', APlaylist, LReceipt, LProgress.Observe);
    Check((LProgress.Done = 135000) and (LProgress.Total = 135000),
      'Unequal75s/60s mixed-rate recordings aggregate to135s');
    try
      for I := 0 to 1 do
      begin
        Check(LReceipt.Arrays['sources'].Objects[I].Int64s['analyzed_frames'] =
          APlaylist.Arrays['items'].Objects[I].Int64s['frame_count'],
          'Whole75-second recording is analyzed beyond a first-eight-second proposal');
        Check((LReceipt.Arrays['sources'].Objects[I].Integers['measured_windows'] = 3 - I) and
          (LReceipt.Arrays['sources'].Objects[I].Integers['cache_hits'] = 0),
          'Cold learning uses bounded30/30/15-second windows');
        Check((LReceipt.Arrays['sources'].Objects[I].Int64s['model_used_frames'] > 0) and
          (LReceipt.Arrays['sources'].Objects[I].Int64s['model_used_frames'] <=
            APlaylist.Arrays['items'].Objects[I].Int64s['frame_count']),
          'Model-used coverage is separate from analyzed duration');
      end;
      LBefore := LCold.CopyModelTexts;
      Check((LReceipt.Objects['vocabulary'].Strings['revision_sha256'] = LCold.RevisionIdentity) and
        (LReceipt.Objects['vocabulary'].Arrays['providers'].Count = 9) and
        (LReceipt.Objects['vocabulary'].Arrays['contributions'].Count = Length(LCold.CopyContributions)),
        'Learning receipt carries actual provider identities and unique original contributions');
      Check(LReceipt.Objects['vocabulary'].Arrays['providers'].Objects[0].Find('tokens') = nil,
        'Ordinary learning receipt avoids duplicating full token text');
    finally FreeAndNil(LReceipt) end;
    LProgress.Updates := 0;
    LWarm := LearnStudioPlaylist(ACatalog, ALibrary, ARoot + '/cache',
      'playlist-learning-warm', APlaylist, LReceipt, LProgress.Observe);
    Check((LProgress.Done = 135000) and (LProgress.Total = 135000),
      'Warm analysis reuse preserves the full selection denominator');
    try
      for I := 0 to 1 do
        Check((LReceipt.Arrays['sources'].Objects[I].Integers['measured_windows'] = 0) and
          (LReceipt.Arrays['sources'].Objects[I].Integers['cache_hits'] = 3 - I),
          'Unchanged source-bound measurements reuse all cached windows');
      LAfter := LWarm.CopyModelTexts;
      for I := 0 to High(LBefore) do
        Check(LBefore[I] = LAfter[I], 'Warm reuse preserves every actual musical provider');
      Check(LWarm.RevisionIdentity = LCold.RevisionIdentity,
        'Warm rebuild preserves the exact learning revision rather than appending ancestry');
    finally FreeAndNil(LReceipt) end;
    FreeAndNil(LWarm);
    APlaylist.Arrays['items'].Objects[0].Integers['influence'] := 7;
    LWarm := LearnStudioPlaylist(ACatalog, ALibrary, ARoot + '/cache',
      'playlist-learning-weight', APlaylist, LReceipt);
    try
      Check(LReceipt.Arrays['sources'].Objects[0].Integers['measured_windows'] = 0,
        'Changing influence does not repeat source analysis');
      LAfter := LWarm.CopyModelTexts;
      LDifferent := False;
      for I := 0 to High(LBefore) do
        if LBefore[I] <> LAfter[I] then LDifferent := True;
      Check(LDifferent, 'Influence changes actual whole-recording learned models');
      Check((LWarm.RevisionIdentity <> LCold.RevisionIdentity) and
        (LWarm.CopyContributions[0].Identity = LCold.CopyContributions[0].Identity),
        'Actual native reweighting changes the revision while retaining original evidence identity');
    finally FreeAndNil(LReceipt) end;
    FreeAndNil(LWarm);
    LItem := APlaylist.Arrays['items'].Objects[1];
    LRate := LItem.Integers['sample_rate'];
    LItem.Strings['extent'] := 'clips';
    LClips := LItem.Arrays['clips'];
    LClip := TJSONObject.Create(['start_frame', LRate, 'end_frame', 2 * LRate, 'included', True]);
    LClip.Add('classifications', TJSONArray.Create(['intro']));
    LClips.Add(LClip);
    LClip := TJSONObject.Create(['start_frame', 50 * LRate, 'end_frame', 55 * LRate, 'included', True]);
    LClip.Add('classifications', TJSONArray.Create(['warm']));
    LClips.Add(LClip);
    LProgress.Updates := 0;
    LWarm := LearnStudioPlaylist(ACatalog, ALibrary, ARoot + '/cache',
      'playlist-learning-clips', APlaylist, LReceipt, LProgress.Observe);
    Check((LProgress.Total = 81000) and (LProgress.Done = 81000),
      'Whole75s plus disjoint1s/5s clips count only81s of selected audio');
    try
      Check((LReceipt.Arrays['sources'].Objects[1].Int64s['included_frames'] = 6 * LRate) and
        (LReceipt.Arrays['sources'].Objects[1].Int64s['analyzed_frames'] = 6 * LRate),
        'Disjoint selected clips analyze only their actual original time');
      Check(LWarm.CopyCoverage[1].IncludedFrames = 6 * LRate,
        'Actual musical corpus receives exact selected ranges');
    finally FreeAndNil(LReceipt) end;
    FreeAndNil(LWarm);
    LItem := APlaylist.Arrays['items'].Objects[0];
    LItem.Strings['extent'] := 'clips';
    LItem.Strings['id'] := StringOfChar('c', 64);
    LWarm := LearnStudioPlaylist(ACatalog, ALibrary, ARoot + '/cache',
      'playlist-learning-excluded', APlaylist, LReceipt);
    try
      Check((LReceipt.Integers['excluded_playlist_item_count'] = 1) and
        (LReceipt.Arrays['sources'].Count = 1),
        'An excluded unavailable recording is not opened or prepared');
      Check((APlaylist.Arrays['items'].Count = 2) and
        (APlaylist.Arrays['items'].Objects[0].Strings['id'] = StringOfChar('c', 64)),
        'Learning never removes saved excluded choices from the caller playlist');
    finally FreeAndNil(LReceipt) end;
  finally
    LProgress.Free;
    LReceipt.Free;
    LWarm.Free;
    LCold.Free;
    SetCurrentDir(LDirectory);
  end;
end;

procedure CheckSavedVocabulary(const ACatalog, AJobId: String; const AResults: TJSONObject);
var
  LSummary: TJSONObject;
  LFull: TJSONObject;
  LReplay: TJSONObject;
  LProvider: TJSONObject;
  LLeaf: TJSONObject;
  LModel: TWfcSequenceModel;
  LDirectory: String;
  I: Integer;
  J: Integer;
begin
  LSummary := AResults.Objects['playlist_learning'].Objects['vocabulary'];
  Check(LSummary.Strings['artifact'] = 'musical-vocabulary.json',
    'Actual worker references its saved full musical vocabulary');
  LDirectory := StudioJobDirectory(ACatalog, AJobId);
  LFull := ReadStudioJSON(LDirectory + PathDelim + 'musical-vocabulary.json');
  LReplay := nil;
  try
    LReplay := ReadStudioJSON(LDirectory + PathDelim + 'instrumental-stream.json');
    Check((LFull.Strings['format'] = 'pythian.musical.vocabulary.v1') and
      (LFull.Strings['revision_sha256'] = LSummary.Strings['revision_sha256']) and
      (LFull.Arrays['providers'].Count = LReplay.Arrays['models'].Count),
      'Saved identity artifact belongs to the actual worker learning/model revision');
    for I := 0 to LFull.Arrays['providers'].Count - 1 do
    begin
      LProvider := LFull.Arrays['providers'].Objects[I];
      Check((LProvider.Strings['model_sha256'] = StudioTextHash(LReplay.Arrays['models'].Strings[I])) and
        (LProvider.Strings['key'] = LReplay.Arrays['model_labels'].Strings[I]),
        'Saved provider binding uses actual replay model bytes and the shared role layout');
      LModel := DecodeWfcSequenceText(LReplay.Arrays['models'].Strings[I]);
      try
        Check(LProvider.Arrays['tokens'].Count = LModel.PublicTokenCount,
          'Saved full vocabulary covers every actual public token');
        for J := 0 to LModel.PublicTokenCount - 1 do
        begin
          Check((LProvider.Arrays['tokens'].Objects[J].Integers['local_index'] = J) and
            (LProvider.Arrays['tokens'].Objects[J].Strings['value'] = LModel.PublicTokenAt(J)) and
            (Length(LProvider.Arrays['tokens'].Objects[J].Strings['identity']) = 64),
            'Saved stable meaning maps to its exact local index in the reloaded model');
        end;
      finally
        LModel.Free;
      end;
    end;
    for I := 0 to LFull.Arrays['contributions'].Count - 1 do
    begin
      LLeaf := LFull.Arrays['contributions'].Objects[I];
      Check((Length(LLeaf.Strings['identity']) = 64) and
        (LLeaf.Int64s['start_frame'] < LLeaf.Int64s['end_frame']) and
        (LLeaf.Integers['training_weight'] > 0),
        'Saved original evidence retains its source clock and separate training multiplicity');
      for J := 0 to I - 1 do
      begin
        Check(LLeaf.Strings['identity'] <> LFull.Arrays['contributions'].Objects[J].Strings['identity'],
          'Actual worker publication contains no duplicated contribution ancestry');
      end;
    end;
  finally
    LReplay.Free;
    LFull.Free;
  end;
end;

procedure Run(const ARoot: String);
var
  LCatalog, LLibrary, LFile: String;
  LDiscovery, LWrite, LPlaylist, LItem, LResult, LRead: TJSONObject;
  LJob, LConfig: TJSONObject;
  LEntries, LItems: TJSONArray;
  LGuard: TFileStream;
  I: Integer;
  LText: String;
  LRejected: Boolean;
begin
  Check(not DirectoryExists(ARoot), 'Use fresh fixture root');
  LCatalog := IncludeTrailingPathDelimiter(ARoot) + 'catalog';
  LLibrary := IncludeTrailingPathDelimiter(ARoot) + 'library';
  Check(ForceDirectories(LCatalog), 'Create isolated catalog');
  Check(ForceDirectories(IncludeTrailingPathDelimiter(ARoot) + 'inbox'), 'Create QA inbox');
  Audio(LLibrary + '/collections/Chillsynth/Evening.wav', 220, 8000, 75);
  Audio(LLibrary + '/collections/lofi/Soft steps.wav', 330, 16000, 60);
  LDiscovery := DiscoverStudioLibrary(LCatalog, LLibrary);
  LWrite := TJSONObject.Create;
  try
    LEntries := LDiscovery.Arrays['entries'];
    Check(LEntries.Count = 2, 'Discover two music collections');
    LWrite.Add('format', StudioProjectWriteFormat);
    LWrite.Add('project_id', 'simple-playlist');
    LWrite.Add('expected_revision', 0);
    LWrite.Add('name', 'Evening playlist');
    LWrite.Add('style_intent', '');
    LWrite.Add('learning_mode', 'instrumental');
    LWrite.Add('sources', TJSONArray.Create);
    LPlaylist := TJSONObject.Create;
    LWrite.Add('playlist', LPlaylist);
    LPlaylist.Add('format', StudioPlaylistFormat);
    LItems := TJSONArray.Create;
    LPlaylist.Add('items', LItems);
    for I := 0 to LEntries.Count - 1 do
    begin
      LItem := TJSONObject.Create;
      LItems.Add(LItem);
      LItem.Add('kind', 'library');
      LItem.Add('id', LEntries.Objects[I].Strings['entry_id']);
      LItem.Add('snapshot_sha256', LEntries.Objects[I].Strings['entry_snapshot_sha256']);
      LItem.Add('discovery_revision', LDiscovery.Integers['revision']);
      LItem.Add('title', LEntries.Objects[I].Strings['original_name']);
      LItem.Add('sample_rate', LEntries.Objects[I].Int64s['sample_rate']);
      LItem.Add('frame_count', LEntries.Objects[I].Int64s['frame_count']);
      LItem.Add('influence', I + 1);
      LItem.Add('extent', 'whole');
      LItem.Add('clips', TJSONArray.Create);
    end;
    LFile := LLibrary + '/collections/Chillsynth/Evening.wav';
    LGuard := TFileStream.Create(LFile, fmOpenReadWrite or fmShareExclusive);
    try
      LText := LWrite.AsJSON;
      LResult := SaveStudioProject(LCatalog, LWrite);
      try
        Check(LWrite.AsJSON = LText, 'Saving leaves borrowed playlist unchanged');
        Check(LResult.Objects['playlist'].Arrays['items'].Count = 2, 'Save both unprepared tracks');
        Check(not LResult.Booleans['model_available'] and
          (LResult.Strings['training_status'] = 'not_started'), 'Save never claims learning');
        Check(not DirectoryExists(LCatalog + '/sources'), 'Adding a playlist does not copy audio');
      finally LResult.Free end;
    finally LGuard.Free end;
    Check(RenameFile(LFile, LFile + '.moved'), 'Temporarily remove original');
    try
      LRead := ReadStudioProject(LCatalog, 'simple-playlist');
      try
        Check(LRead.Objects['playlist'].Arrays['items'].Count = 2,
          'Missing original does not destroy saved playlist');
      finally LRead.Free end;
      LWrite.Integers['expected_revision'] := 1;
      LItems.Objects[0].Integers['influence'] := 6;
      LResult := SaveStudioProject(LCatalog, LWrite);
      try
        Check(LResult.Integers['revision'] = 2,
          'Metadata-only edit works without audio; Generate must verify content separately');
      finally LResult.Free end;
    finally
      Check(RenameFile(LFile + '.moved', LFile), 'Restore original fixture');
    end;
    LRead := ReadStudioProjectRevision(LCatalog, 'simple-playlist', 1);
    try
      Check(LRead.Objects['playlist'].Arrays['items'].Objects[0].Integers['influence'] = 1,
        'Earlier weight and source identity remain immutable');
      LJob := TJSONObject.Create(['format', StudioJobWriteFormat,
        'job_id', 'no-authored-substitution', 'kind', 'instrumental_generate',
        'project_id', 'simple-playlist', 'project_revision', 1,
        'project_snapshot_sha256', LRead.Strings['snapshot_sha256']]);
      try
        LJob.Add('seeds', TJSONArray.Create([731]));
        LConfig := TJSONObject.Create(['tempo_bpm', 120, 'tonic', 0, 'cells', 16]);
        LConfig.Add('instruments', TJSONArray.Create(['sine', 'triangle', 'saw']));
        LConfig.Add('levels', TJSONArray.Create([70, 65, 60, 80, 60, 50]));
        LJob.Add('instrumental', LConfig);
        LRejected := False;
        try
          LResult := PrepareStudioJob(LCatalog, LJob);
          LResult.Free;
        except
          on E: EAudio do LRejected := Pos('duration_ms', E.Message) > 0;
        end;
        Check(LRejected, 'Playlist generation requires an explicit duration instead of an authored fallback');
        LJob.Add('duration_ms', 2000);
        LResult := PrepareStudioJob(LCatalog, LJob);
        try
          Check((LResult.Integers['source_count'] = 2) and
            (LResult.Objects['limits'].Integers['worker_seconds'] = MaximumStudioSessionSeconds),
            'Playlist preflight declares actual source learning and its durable runtime budget');
          Check((LResult.Objects['output_resources'].Integers['retained_outputs'] = 7) and
            (LResult.Objects['output_resources'].Int64s['music_frames'] = 48000),
            'Preflight counts mix and six stems on the native output clock');
        finally LResult.Free end;
        LJob.Int64s['duration_ms'] := 86400000;
        LResult := PrepareStudioJob(LCatalog, LJob);
        try
          Check((LResult.Objects['output_resources'].Int64s['frame_count'] = 2073624000) and
            (LResult.Objects['output_resources'].Int64s['wav_bytes_each'] = 8294496080) and
            (LResult.Objects['output_resources'].Int64s['audio_bytes'] = 58061472560),
            '24-hour admission uses wide RF64 bytes without allocating score or PCM');
        finally LResult.Free end;
        LJob.Int64s['duration_ms'] := 2000;
        LResult := EnqueueStudioJob(LCatalog, LJob);
        LResult.Free;
        Check(RunStudioWorker(LCatalog, LJob.Strings['job_id'], LLibrary),
          'Actual native worker learns the selected music and synthesizes a queued job');
        LResult := ReadStudioJob(LCatalog, LJob.Strings['job_id']);
        try
          Check(LResult.Strings['status'] = 'completed', 'Queued playlist generation completes');
          Check((LResult.Objects['workflow'].Integers['phase'] = 4) and
            (LResult.Objects['workflow'].Integers['phases'] = 4),
            'Durable completed job retains its native workflow for reconnect');
          Check((LResult.Objects['workflow'].Integers['done'] = 8) and
            (LResult.Objects['workflow'].Integers['total'] = 8),
            'Success atomically closes final saving work without a premature running100percent');
          Check((LResult.Objects['results'].Objects['playlist_learning'].Arrays['sources'].Count = 2) and
            (LResult.Objects['results'].Arrays['parts'].Count = 6),
            'Actual worker result retains source contributions and all six synthesized parts');
          CheckSavedVocabulary(LCatalog, LJob.Strings['job_id'], LResult.Objects['results']);
        finally LResult.Free end;
        LResult := ReadListeningQueue(LCatalog);
        try
          Check(LResult.Arrays['items'].Objects[0].Strings['task_id'] =
            'NS-3_style-vocabulary_01', 'Review names the actual playlist-learning task');
        finally LResult.Free end;
      finally
        LJob.Free;
      end;
    finally LRead.Free end;
    CheckLearning(ExpandFileName(ARoot), LCatalog, LLibrary, LPlaylist);
  finally
    LWrite.Free;
    LDiscovery.Free;
  end;
  WriteLn('PASS ', GChecks, ' lazy playlist checks');
end;
begin
  try
    Check(ParamCount = 1, 'Usage: playlist FRESH_ROOT');
    Run(ParamStr(1));
  except
    on E: Exception do begin WriteLn(StdErr, E.ClassName, ': ', E.Message); ExitCode := 1 end;
  end;
end.
