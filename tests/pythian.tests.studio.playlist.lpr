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
  pythian.wfc.musical.corpus, pythian.wfc.layers, pythian.hash,
  pythian.instrument, pythian.synth, pythian.oscillator, pythian.percussion, pythian.bus,
  pythian.time, pythian.music.sound, pythian.music.stream, pythian.music.replay,
  pythian.wave.read, pythian.wfc.semantic.style,
  pythian.wfc.instrumental.stream,
  pythian.music.decisions,
  pythian.tools.studio.decisions, pythian.tools.studio.instrumental.output,
  pythian.tools.listen.assets,
  pythian.tools.path,
  pythian.tools.studio.style.candidate,
  pythian.tools.studio.styles,
  wfc_sequence, wfc_sequence_text;
var GChecks: Integer;
type
  TSelectionProgress = class
    Done: Int64;
    Total: Int64;
    Updates: Integer;
    procedure Observe(const AProgress: TWorkProgress);
  end;
  TCandidateAbort = class
    procedure Observe(const AProgress: TWorkProgress);
    procedure CheckWork;
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
procedure TCandidateAbort.CheckWork;
begin
  raise EAbort.Create('style-snapshot-test-cancel');
end;
procedure TCandidateAbort.Observe(const AProgress: TWorkProgress);
begin
  CheckWork;
end;
procedure CheckCandidateCancellation(const ACatalog: String; const ACorpus: TMusicalCorpus);
var
  LAbort: TCandidateAbort;
  LResult: TJSONObject;
  LRevision: String;
  LCancelled: Boolean;
  I: Integer;
begin
  LAbort := TCandidateAbort.Create;
  LResult := nil;
  LRevision := ACorpus.RevisionIdentity;
  try
    for I := 0 to 1 do
    begin
      LCancelled := False;
      try
        if I = 0 then
          LResult := RetainStudioStyleCandidate(ACatalog, ACorpus, nil,
            Default(TSemanticInstrumentalRecipe), nil, LAbort.Observe)
        else
          LResult := RetainStudioStyleCandidate(ACatalog, ACorpus, nil,
            Default(TSemanticInstrumentalRecipe), LAbort.CheckWork, nil);
      except
        on E: EAbort do LCancelled := E.Message = 'style-snapshot-test-cancel';
      end;
      Check(LCancelled and (LResult = nil),
        'Optional snapshot handling must propagate callback/check cancellation unchanged');
      Check(ACorpus.RevisionIdentity = LRevision,
        'Snapshot cancellation must preserve the actual learned corpus');
    end;
  finally
    LResult.Free;
    LAbort.Free;
  end;
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
    CheckCandidateCancellation(ACatalog, LCold);
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
      Check((Length(LWarm.CopyCoverage) = 3) and
        (LWarm.CopyCoverage[1].IncludedFrames + LWarm.CopyCoverage[2].IncludedFrames = 6 * LRate) and
        (LReceipt.Arrays['audio_sources'].Objects[1].Int64s['original_start_frame'] = LRate) and
        (LReceipt.Arrays['audio_sources'].Objects[2].Int64s['original_start_frame'] = 50 * LRate),
        'Actual corpus reads independent clips with exact original-time lineage');
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

procedure CheckSavedStyle(const ACatalog, AJobId: String; const AResults: TJSONObject);
var
  LReceipt, LMeta: TJSONObject;
  LFile: TFileStream;
  LBytes: TAudioBytes;
  LStyle: TSemanticStyle;
  LStream: TSemanticInstrumentalStream;
  LOptions: TInstrumentalStreamOptions;
  LReader: TWaveFrameReader;
  LExpected: array[0..6] of TAudioClip;
  LMaster: TAudioSamples;
  LStems: TBusSampleBlocks;
  LHash: String;
  LPosition: Integer;
  I: Integer;
  J: Integer;
begin
  Check(AResults.Find('style_candidate') <> nil, 'Ordinary playlist job retains a style candidate receipt');
  LReceipt := AResults.Objects['style_candidate'];
  Check(LReceipt.Strings['status'] = 'ready',
    'Ordinary playlist style is available: ' + LReceipt.Get('reason', ''));
  Check(LReceipt.Integers['provider_count'] = 9,
    'Native style candidate retains the actual nine-provider model layout');
  if AResults.Find('playlist_learning') <> nil then
    Check(LReceipt.Strings['corpus_revision'] = AResults.Objects['playlist_learning'].Objects['vocabulary'].Strings['revision_sha256'],
      'Native style candidate retains the actual learned model revision')
  else
    Check(LReceipt.Strings['corpus_revision'] = AResults.Objects['style_source'].Strings['corpus_revision'],
      'Reused style retains its frozen corpus revision');
  LStyle := nil;
  LStream := nil;
  LMeta := nil;
  for I := 0 to 6 do LExpected[I] := nil;
  try
    LFile := OpenStudioReadStream(ListeningAssetDirectory(ACatalog) + '/' + LReceipt.Strings['artifact']);
    try
      Check((LFile.Size = LReceipt.Int64s['bytes']) and
        (LFile.Size <= MaximumSemanticStyleBytes), 'Saved style artifact matches its declared size');
      SetLength(LBytes, LFile.Size);
      LFile.ReadBuffer(LBytes[0], Length(LBytes));
    finally LFile.Free end;
    LStyle := DecodeSemanticStyle(LBytes);
    Check(LStyle.Identity = LReceipt.Strings['sha256'], 'Native style artifact retains its immutable identity');
    LOptions := LStyle.CopyDefinition.Instrumental.Options;
    LOptions.MusicFrames := AResults.Objects['decisions'].Int64s['music_frames'];
    LOptions.TailFrames := AResults.Objects['output_resources'].Int64s['tail_frames'];
    if FileExists(NativeFilePath(StudioJobDirectory(ACatalog, AJobId) + '/instrumental-stream-completed.json')) then
    begin
      LMeta := ReadStudioJSON(StudioJobDirectory(ACatalog, AJobId) + '/instrumental-stream-completed.json');
      LOptions.Seed := LMeta.Int64s['seed'];
    end;
    LStream := LStyle.CreateInstrumentalStream(LOptions);
    for I := 0 to 6 do
    begin
      LFile := OpenStudioInstrumentalAudio(ACatalog, AJobId, I, LHash);
      try
        LReader := TWaveFrameReader.Create(LFile);
        try
          Check(LReader.FrameCount = LStream.Stream.FrameCount,
            'Saved style and native output use the same performed clock');
          LExpected[I] := LReader.ReadClip(0, LReader.FrameCount);
        finally LReader.Free end;
      finally LFile.Free end;
    end;
    LPosition := 0;
    while LStream.Stream.ReadOutputs(2048, [6,7,8,9,10,11], LMaster, LStems) do
    begin
      for I := 0 to High(LMaster) do
      begin
        Check(Abs(LMaster[I] - LExpected[6].SampleAt(LPosition + I div 2, I mod 2)) <= 2 / 32768,
          'Saved style does not perform the actual native mix recipe/notes');
        for J := 0 to 5 do
          Check(Abs(LStems[J][I] - LExpected[J].SampleAt(LPosition + I div 2, I mod 2)) <= 2 / 32768,
            'Saved style changes an actual native instrumental stem');
      end;
      Inc(LPosition, Length(LMaster) div 2);
    end;
    Check(LPosition = LExpected[6].FrameCount, 'Saved style replay ends before the native output');
  finally
    for I := 0 to 6 do LExpected[I].Free;
    LMeta.Free;
    LStream.Free;
    LStyle.Free;
  end;
end;

function SoundWrite(const AParentId, AId, AName: String;
  const AParent: TJSONObject): TJSONObject; forward;
function NoteWrite(const AParentId, AId: String;
  const AParent: TJSONObject): TJSONObject; forward;

procedure CheckNamedStyle(const ACatalog, ALibrary: String;
  const AJob, AResults: TJSONObject);
var
  LWrite, LSaved, LAgain, LList, LJob, LStatus, LParent: TJSONObject;
  LModelGuard, LSourceA, LSourceB: TFileStream;
  LId, LText, LArtifact, LSoundStyleId, LNoteStyleId: String;
  LAbort: TCandidateAbort;
  LBytes: TAudioBytes;
  LCancelled: Boolean;
  I: Integer;
begin
  LWrite := TJSONObject.Create(['format', 'pythian.studio.style.write.v1',
    'name', 'Night music', 'job_id', AJob.Strings['job_id']]);
  LSaved := nil;
  LJob := nil;
  LStatus := nil;
  LParent := nil;
  try
    LText := AResults.AsJSON;
    LSaved := SaveStudioStyle(ACatalog, LWrite);
    LId := LSaved.Strings['id'];
    Check((LSaved.Strings['sha256'] = AResults.Objects['style_candidate'].Strings['sha256']) and
      (AResults.AsJSON = LText), 'Naming retains the complete model and never changes the finished song');
    LAgain := SaveStudioStyle(ACatalog, LWrite);
    try Check(LAgain.AsJSON = LSaved.AsJSON, 'Saving a name is idempotent');
    finally LAgain.Free end;
    LArtifact := ListeningAssetDirectory(ACatalog) + '/' + AResults.Objects['style_candidate'].Strings['artifact'];
    LModelGuard := TFileStream.Create(NativeFilePath(LArtifact), fmOpenReadWrite or fmShareExclusive);
    try
      LList := ListStudioStyles(ACatalog);
      try
        Check((LList.Arrays['styles'].Count = 1) and (LList.Arrays['errors'].Count = 0) and
          (LList.Arrays['styles'].Objects[0].Find('settings') = nil),
          'Catalog lists metadata only while the complete model is exclusively locked');
      finally LList.Free end;
    finally LModelGuard.Free end;
    LAbort := TCandidateAbort.Create;
    try
      LCancelled := False;
      try LBytes := ReadStudioStyleBytes(ACatalog, LSaved.Strings['sha256'], LAbort.Observe);
      except on E: EAbort do LCancelled := E.Message = 'style-snapshot-test-cancel' end;
      Check(LCancelled, 'Retained style reads propagate cancellation without changing the artifact');
    finally LAbort.Free end;
    LJob := TJSONObject.Create(['format', StudioJobWriteFormat,
      'kind', 'instrumental_style', 'style_id', LId,
      'project_id', AJob.Strings['project_id'], 'project_revision', AJob.Int64s['project_revision'],
      'project_snapshot_sha256', AJob.Strings['project_snapshot_sha256']]);
    LJob.Add('seeds', AJob.Arrays['seeds'].Clone);
    for I := 0 to 1 do
    begin
      LJob.Strings['job_id'] := 'named-style-' + IntToStr(I);
      LJob.Int64s['duration_ms'] := 2000 + I * 1000;
      LStatus := PrepareStudioJob(ACatalog, LJob);
      Check((LStatus.Int64s['unique_source_bytes_to_verify'] = 0) and
        not LStatus.Booleans['learning_performed'] and
        (LStatus.Objects['limits'].Integers['worker_seconds'] = MaximumStudioSessionSeconds),
        'Saved style admission declares no source scan or relearning and uses the durable long-job policy');
      FreeAndNil(LStatus);
      LStatus := EnqueueStudioJob(ACatalog, LJob);
      FreeAndNil(LStatus);
      LSourceA := TFileStream.Create(ALibrary + '/collections/Chillsynth/Evening.wav', fmOpenReadWrite or fmShareExclusive);
      try
        LSourceB := TFileStream.Create(ALibrary + '/collections/lofi/Soft steps.wav', fmOpenReadWrite or fmShareExclusive);
        try Check(RunStudioWorker(ACatalog, LJob.Strings['job_id'], ALibrary),
          'Actual saved-style worker runs with every original recording exclusively locked');
        finally LSourceB.Free end;
      finally LSourceA.Free end;
      LStatus := ReadStudioJob(ACatalog, LJob.Strings['job_id']);
      Check(LStatus.Strings['status'] = 'completed', 'Saved style generation completes: ' + LStatus.Get('error_message', ''));
      Check((not LStatus.Objects['results'].Booleans['learning_performed']) and
        (LStatus.Objects['results'].Find('playlist_learning') = nil) and
        (LStatus.Objects['results'].Objects['style_source'].Strings['sha256'] = LSaved.Strings['sha256']) and
        (LStatus.Objects['results'].Objects['decisions'].Int64s['music_frames'] = (2 + I) * 24000),
        'Actual saved-style job keeps source lineage, frozen learning and requested performance duration');
      if I = 0 then CheckSavedStyle(ACatalog, LJob.Strings['job_id'], LStatus.Objects['results']);
      FreeAndNil(LStatus);
    end;
    LParent := ReadStudioJob(ACatalog, 'named-style-1');
    for I := 0 to 1 do
    begin
      FreeAndNil(LJob);
      if I = 0 then LJob := SoundWrite('named-style-1', 'style-sound-edit', 'square', LParent.Objects['results'])
      else
      begin
        LJob := NoteWrite('named-style-1', 'style-note-edit', LParent.Objects['results']);
        LJob.Objects['note_edit'].Booleans['rhythm'] := True;
        LJob.Objects['note_edit'].Int64s['start_frame'] := 12000;
        LJob.Objects['note_edit'].Int64s['end_frame'] := 48000;
        LJob.Objects['note_edit'].Objects['controls'].Arrays['parts'].Objects[0].Integers['activity_bias'] := 1;
      end;
      LStatus := EnqueueStudioJob(ACatalog, LJob);
      FreeAndNil(LStatus);
      Check(RunStudioWorker(ACatalog, LJob.Strings['job_id'], ALibrary),
        'Saved-style result remains a valid source for retained sound/note editing');
      LStatus := ReadStudioJob(ACatalog, LJob.Strings['job_id']);
      Check((LStatus.Strings['status'] = 'completed') and
        (LStatus.Objects['results'].Objects['style_source'].Strings['id'] = LId),
        'Edited performance preserves its actual selected style origin');
      if I = 0 then
      begin
        Check((LStatus.Objects['results'].Objects['style_candidate'].Strings['status'] = 'ready') and
          (LStatus.Objects['results'].Objects['style_candidate'].Strings['parent_sha256'] = LSaved.Strings['sha256']) and
          (LStatus.Objects['results'].Objects['style_candidate'].Strings['sha256'] <> LSaved.Strings['sha256']),
          'Sound edit retains an actual new recipe with its complete frozen model parent');
        CheckSavedStyle(ACatalog, LJob.Strings['job_id'], LStatus.Objects['results']);
        LWrite.Strings['name'] := 'Sound style';
        LWrite.Strings['job_id'] := LJob.Strings['job_id'];
        LAgain := SaveStudioStyle(ACatalog, LWrite);
        try
          LSoundStyleId := LAgain.Strings['id'];
          Check(LAgain.Strings['sha256'] = LStatus.Objects['results'].Objects['style_candidate'].Strings['sha256'],
            'Saving a sound-edited song keeps its actual new style recipe');
        finally LAgain.Free end;
      end
      else
      begin
        Check((LStatus.Objects['results'].Objects['style_candidate'].Strings['status'] = 'ready') and
          (LStatus.Objects['results'].Objects['style_candidate'].Strings['derivation'] = 'scoped_musical_controls') and
          (LStatus.Objects['results'].Objects['style_candidate'].Strings['source_parent_sha256'] = LSaved.Strings['sha256']) and
          (LStatus.Objects['results'].Strings['model_sha256'] = LParent.Objects['results'].Strings['model_sha256']),
          'Actual passage saving preserves its scope, model and complete source parent');
        LWrite.Strings['name'] := 'Passage style'; LWrite.Strings['job_id'] := LJob.Strings['job_id'];
        LAgain := SaveStudioStyle(ACatalog, LWrite);
        try LNoteStyleId := LAgain.Strings['id'] finally LAgain.Free end;
      end;
      FreeAndNil(LStatus);
    end;
    FreeAndNil(LJob);
    LJob := TJSONObject.Create(['format', StudioJobWriteFormat,
      'kind', 'instrumental_style', 'style_id', LSoundStyleId, 'job_id', 'reused-sound-style',
      'project_id', AJob.Strings['project_id'], 'project_revision', AJob.Int64s['project_revision'],
      'project_snapshot_sha256', AJob.Strings['project_snapshot_sha256'], 'duration_ms', 3000]);
    LJob.Add('seeds', AJob.Arrays['seeds'].Clone);
    LStatus := EnqueueStudioJob(ACatalog, LJob);
    FreeAndNil(LStatus);
    Check(RunStudioWorker(ACatalog, 'reused-sound-style', ALibrary),
      'Actual native job reuses the named sound-edit variant');
    LStatus := ReadStudioJob(ACatalog, 'reused-sound-style');
    Check((LStatus.Strings['status'] = 'completed') and
      not LStatus.Objects['results'].Booleans['learning_performed'] and
      (LStatus.Objects['results'].Strings['model_sha256'] = LParent.Objects['results'].Strings['model_sha256']) and
      (LStatus.Objects['results'].Arrays['outputs'].Objects[0].Strings['wav_sha256'] <>
        LParent.Objects['results'].Arrays['outputs'].Objects[0].Strings['wav_sha256']),
      'Saved sound recipe changes actual audio while preserving learned models and source lineage');
    CheckSavedStyle(ACatalog, 'reused-sound-style', LStatus.Objects['results']);
    FreeAndNil(LStatus);
    LJob.Strings['job_id'] := 'reused-passage-style'; LJob.Strings['style_id'] := LNoteStyleId;
    LJob.Int64s['duration_ms'] := 4000;
    LStatus := EnqueueStudioJob(ACatalog, LJob); FreeAndNil(LStatus);
    Check(RunStudioWorker(ACatalog, 'reused-passage-style', ALibrary), 'Actual native job reuses named scoped controls');
    LStatus := ReadStudioJob(ACatalog, 'reused-passage-style');
    Check((LStatus.Strings['status'] = 'completed') and
      not LStatus.Objects['results'].Booleans['learning_performed'] and
      (LStatus.Objects['results'].Strings['model_sha256'] = LParent.Objects['results'].Strings['model_sha256']),
      'Extended passage-style reuse performs without changing learned evidence');
    CheckSavedStyle(ACatalog, 'reused-passage-style', LStatus.Objects['results']);
  finally
    LParent.Free;
    LStatus.Free;
    LJob.Free;
    LSaved.Free;
    LWrite.Free;
  end;
end;

procedure CheckUnavailableStyle(const ACatalog, ALibrary: String;
  const AJob, AResults: TJSONObject);
var
  LPath: String;
  LJob: TJSONObject;
  LStatus: TJSONObject;
  LFile: TFileStream;
  LByte: Byte;
begin
  LPath := ListeningAssetDirectory(ACatalog) + '/' + AResults.Objects['style_candidate'].Strings['artifact'];
  Check(RenameFile(NativeFilePath(LPath), NativeFilePath(LPath + '.held')),
    'Preserve the isolated accepted style for a corruption check');
  LJob := nil;
  LStatus := nil;
  try
    LByte := 0;
    LFile := TFileStream.Create(NativeFilePath(LPath), fmCreate);
    try LFile.WriteBuffer(LByte, 1) finally LFile.Free end;
    LJob := TJSONObject(AJob.Clone);
    LJob.Strings['job_id'] := 'style-unavailable-song';
    LStatus := EnqueueStudioJob(ACatalog, LJob);
    FreeAndNil(LStatus);
    Check(RunStudioWorker(ACatalog, 'style-unavailable-song', ALibrary),
      'Optional style failure must not fail an otherwise completed song');
    LStatus := ReadStudioJob(ACatalog, 'style-unavailable-song');
    Check((LStatus.Strings['status'] = 'completed') and
      (LStatus.Objects['results'].Arrays['parts'].Count = 6) and
      (LStatus.Objects['results'].Objects['style_candidate'].Strings['status'] = 'unavailable') and
      (Pos('Existing style content differs',
        LStatus.Objects['results'].Objects['style_candidate'].Strings['reason']) > 0),
      'Completed native song explains unavailable style without replacing existing content');
  finally
    LStatus.Free;
    LJob.Free;
    Check(SysUtils.DeleteFile(NativeFilePath(LPath)), 'Remove only the isolated corrupt fixture payload');
    Check(RenameFile(NativeFilePath(LPath + '.held'), NativeFilePath(LPath)),
      'Restore the isolated accepted style');
  end;
end;

procedure CheckClassifiedLearning(const ARoot, ACatalog, ALibrary: String;
  const APlaylist: TJSONObject);
var
  LWrite: TJSONObject;
  LPlaylist: TJSONObject;
  LSaved: TJSONObject;
  LJob: TJSONObject;
  LConfig: TJSONObject;
  LStatus: TJSONObject;
  LReceipt: TJSONObject;
  LClip: TJSONObject;
  LCanonical: TJSONObject;
  LUnicode: TJSONObject;
  LCorpus: TMusicalCorpus;
  LGuard: TFileStream;
  LAudio: TFileStream;
  LHashes: array[0..1] of String;
  LModels: array[0..1] of String;
  LHash: String;
  LId: String;
  LText: String;
  LExcludedFile: String;
  LRate: Integer;
  LFailed: Boolean;
  LLeaves: TMusicalCorpusContributions;
  I: Integer;
  J: Integer;
  K: Integer;
begin
  for I := 0 to 1 do
  begin
    LWrite := TJSONObject.Create(['format', StudioProjectWriteFormat,
      'project_id', 'classified-' + IntToStr(I), 'expected_revision', 0,
      'name', 'Classified ' + IntToStr(I), 'style_intent', '', 'learning_mode', 'instrumental']);
    LSaved := nil;
    LJob := nil;
    LStatus := nil;
    try
      LWrite.Add('sources', TJSONArray.Create);
      LPlaylist := TJSONObject(APlaylist.Clone);
      LWrite.Add('playlist', LPlaylist);
      LPlaylist.Add('learning_label', 'focus-' + IntToStr(I));
      for J := 0 to 1 do
      begin
        LPlaylist.Arrays['items'].Objects[J].Add('classifications',
          TJSONArray.Create(['focus-' + IntToStr(J)]));
        LPlaylist.Arrays['items'].Objects[J].Integers['influence'] := 1;
      end;
      LText := LWrite.AsJSON;
      LSaved := SaveStudioProject(ACatalog, LWrite);
      Check((LWrite.AsJSON = LText) and (LSaved.Objects['playlist'].Arrays['items'].Count = 2),
        'Classification save preserves caller data and nonmatching saved tracks');
      Check((LSaved.Objects['playlist'].Arrays['items'].Objects[I].Strings['extent'] = 'whole') and
        (LSaved.Objects['playlist'].Arrays['items'].Objects[1 - I].Strings['extent'] = 'clips'),
        'Native canonical selection applies the label instead of trusting stale included flags');
      LId := 'classified-job-' + IntToStr(I);
      LJob := TJSONObject.Create(['format', StudioJobWriteFormat, 'job_id', LId,
        'kind', 'instrumental_generate', 'project_id', 'classified-' + IntToStr(I),
        'project_revision', 1, 'project_snapshot_sha256', LSaved.Strings['snapshot_sha256'],
        'duration_ms', 2000]);
      LJob.Add('seeds', TJSONArray.Create([731]));
      LConfig := TJSONObject.Create(['tempo_bpm', 120, 'tonic', 0, 'cells', 16]);
      LConfig.Add('instruments', TJSONArray.Create(['sine', 'triangle', 'saw']));
      LConfig.Add('levels', TJSONArray.Create([70, 65, 60, 80, 60, 50]));
      LJob.Add('instrumental', LConfig);
      LStatus := PrepareStudioJob(ACatalog, LJob);
      Check(LStatus.Integers['source_count'] = 1,
        'Native preflight counts only the teaching source selected by classification');
      FreeAndNil(LStatus);
      LStatus := EnqueueStudioJob(ACatalog, LJob);
      FreeAndNil(LStatus);
      LExcludedFile := ALibrary + '/collections/Chillsynth/Evening.wav';
      if LPlaylist.Arrays['items'].Objects[1 - I].Strings['title'] <> 'Evening.wav' then
        LExcludedFile := ALibrary + '/collections/lofi/Soft steps.wav';
      LGuard := TFileStream.Create(LExcludedFile, fmOpenReadWrite or fmShareExclusive);
      try
        Check(RunStudioWorker(ACatalog, LId, ALibrary),
          'Actual classified native worker generates without opening the excluded recording');
      finally
        LGuard.Free;
      end;
      LStatus := ReadStudioJob(ACatalog, LId);
      Check(LStatus.Strings['status'] = 'completed', 'Classified instrumental generation completes');
      CheckSavedStyle(ACatalog, LId, LStatus.Objects['results']);
      if I = 0 then
      begin
        CheckUnavailableStyle(ACatalog, ALibrary, LJob, LStatus.Objects['results']);
        CheckNamedStyle(ACatalog, ALibrary, LJob, LStatus.Objects['results']);
      end;
      LReceipt := LStatus.Objects['results'].Objects['playlist_learning'];
      Check((LReceipt.Arrays['sources'].Count = 1) and
        (LReceipt.Arrays['excluded_sources'].Count = 1) and
        (LReceipt.Objects['classification_selection'].Strings['label'] = 'focus-' + IntToStr(I)),
        'Actual result explains classification, teaching source and excluded saved material');
      Check((LReceipt.Arrays['sources'].Objects[0].Arrays['providers_taught'].Count = 9) and
        (LStatus.Objects['results'].Arrays['parts'].Count = 6),
        'Selected source teaches actual providers performed through all six instrumental parts');
      LModels[I] := LStatus.Objects['results'].Strings['model_sha256'];
      LAudio := OpenStudioInstrumentalAudio(ACatalog, LId, 6, LHash);
      try
        Check(LAudio.Size = 288044, 'Both classification experiments keep the same declared PCM clock');
        LHashes[I] := Sha256Stream(LAudio, LAudio.Size);
        Check(LHashes[I] = LHash, 'Actual generated WAV matches its published identity');
      finally
        LAudio.Free;
      end;
    finally
      LStatus.Free;
      LJob.Free;
      LSaved.Free;
      LWrite.Free;
    end;
  end;
  Check((LModels[0] <> LModels[1]) and (LHashes[0] <> LHashes[1]),
    'Changing only the teaching classification changes learned models and actual synthesized music');

  LPlaylist := TJSONObject(APlaylist.Clone);
  LReceipt := nil;
  LCorpus := nil;
  LCanonical := nil;
  LUnicode := nil;
  try
    LPlaylist.Add('learning_label', 'warm');
    LRate := LPlaylist.Arrays['items'].Objects[0].Integers['sample_rate'];
    for I := 0 to 1 do
    begin
      LClip := TJSONObject.Create(['start_frame', I * 5 * LRate,
        'end_frame', (I * 5 + 4) * LRate, 'included', False]);
      LClip.Add('classifications', TJSONArray.Create(['warm']));
      LPlaylist.Arrays['items'].Objects[0].Arrays['clips'].Add(LClip);
    end;
    LCorpus := LearnStudioPlaylist(ACatalog, ALibrary, ARoot + '/cc',
      'classified-clips', LPlaylist, LReceipt);
    Check((LReceipt.Arrays['sources'].Count = 1) and
      (LReceipt.Arrays['sources'].Objects[0].Int64s['included_frames'] = 8 * LRate) and
      (LReceipt.Arrays['sources'].Objects[0].Int64s['analyzed_frames'] = 8 * LRate),
      'Clip classification traverses only its two disjoint original ranges');
    Check((Length(LCorpus.CopySelections) = 2) and
      (LCorpus.CopySelections[0].Classifications[0] = 'warm'),
      'Shared corpus retains classifications on their actual selected source ranges');
    LLeaves := LCorpus.CopyContributions;
    for K := 0 to High(LLeaves) do
      Check((LReceipt.Objects['vocabulary'].Arrays['contributions'].Objects[K].Int64s['original_end_frame'] <= 4 * LRate) or
        (LReceipt.Objects['vocabulary'].Arrays['contributions'].Objects[K].Int64s['original_start_frame'] >= 5 * LRate),
        'Classification never teaches the original gap between selected clips');
    FreeAndNil(LCorpus);
    FreeAndNil(LReceipt);
    LPlaylist.Arrays['items'].Objects[0].Arrays['clips'].Objects[1].Int64s['start_frame'] := 3 * LRate;
    LText := LPlaylist.AsJSON;
    LFailed := False;
    try LCanonical := CanonicalStudioPlaylist(LPlaylist);
    except on E: EAudio do LFailed := Pos('overlap', E.Message) > 0 end;
    Check(LFailed and (LCanonical = nil) and (LPlaylist.AsJSON = LText),
      'Native classification overlap failure preserves caller choices before any learning');
    LPlaylist.Arrays['items'].Objects[0].Arrays['clips'].Objects[1].Int64s['start_frame'] := 5 * LRate;
    LPlaylist.Strings['learning_label'] := 'not-a-label';
    LFailed := False;
    try LCanonical := CanonicalStudioPlaylist(LPlaylist);
    except on E: EAudio do LFailed := Pos('No music', E.Message) > 0 end;
    Check(LFailed and (LCanonical = nil), 'Unknown classifications never fall back to unrelated music');
    LUnicode := ParseStudioProjectWrite('{"label":"\ud83c\udfb5","classifications":["\ud83c\udfb5"]}');
    LPlaylist.Strings['learning_label'] := LUnicode.Strings['label'];
    LPlaylist.Arrays['items'].Objects[1].Add('classifications', LUnicode.Arrays['classifications'].Clone);
    LCanonical := CanonicalStudioPlaylist(LPlaylist);
    Check((LCanonical.Strings['learning_label'] = LUnicode.Strings['label']) and
      (LCanonical.Arrays['items'].Objects[1].Strings['extent'] = 'whole') and
      (LCanonical.Arrays['items'].Objects[0].Strings['extent'] = 'clips') and
      not LCanonical.Arrays['items'].Objects[0].Arrays['clips'].Objects[0].Booleans['included'],
      'Native canonical label matching preserves supplementary Unicode without host transcoding');
  finally
    LUnicode.Free;
    LCanonical.Free;
    LCorpus.Free;
    LReceipt.Free;
    LPlaylist.Free;
  end;
end;

procedure CheckSavedDecisions(const ACatalog, AJobId: String; const AResult: TJSONObject);
var
  LMeta, LStored, LBad: TJSONObject;
  LFile: TFileStream;
  LOutput: TStudioInstrumentalOutput;
  LReplay: TMusicDecisionReplay;
  LReader: TMusicDecisionReader;
  LDuplicate: TStudioDecisionWriter;
  LChunk: TMusicDecisionChunk;
  LDuplicateReceipt: TJSONObject;
  LOptions: TInstrumentStreamOptions;
  LBindings: TInstrumentStreamBindings;
  LInstruments: array[0..2] of TInstrument;
  LDrums: array[0..2] of TPercussionInstrument;
  LSettings: TPercussionSettings;
  LZones: TInstrumentZones;
  LSound: TMusicalSound;
  LMaster: TAudioSamples;
  LStems: TBusSampleBlocks;
  LName: String;
  I: Integer;
  LRejected: Boolean;
begin
  LMeta := ReadStudioJSON(StudioJobDirectory(ACatalog, AJobId) +
    PathDelim + 'instrumental-stream-completed.json');
  LFile := nil;
  LOutput := nil;
  LReplay := nil;
  LReader := nil;
  LDuplicate := nil;
  LDuplicateReceipt := nil;
  LStored := nil;
  LBad := nil;
  FillChar(LInstruments, SizeOf(LInstruments), 0);
  FillChar(LDrums, SizeOf(LDrums), 0);
  try
    Check((AResult.Objects['decisions'].AsJSON = LMeta.Objects['decisions'].AsJSON) and
      (AResult.Objects['decisions'].Int64s['music_frames'] =
        AResult.Objects['output_resources'].Int64s['music_frames']) and
      (AResult.Objects['decisions'].Int64s['cells'] = LMeta.Int64s['total_cells']),
      'Actual worker binds complete decisions to the same job/model/settings clock');
    LFile := OpenStudioDecisionJournal(ACatalog, AResult.Objects['decisions']);
    SetLength(LBindings, 6);
    for I := 0 to 2 do
    begin
      LZones := nil;
      SetLength(LZones, 1);
      LZones[0].MinimumKey := 0;
      LZones[0].MaximumKey := 127;
      LZones[0].MinimumVelocity := 1;
      LZones[0].MaximumVelocity := 127;
      LZones[0].Voice := DefaultSynthVoice;
      LZones[0].Voice.Gain := 0.14;
      LName := LMeta.Objects['settings'].Arrays['instruments'].Strings[I];
      if LName = 'sine' then LZones[0].Voice.Shape := wsSine
      else if LName = 'triangle' then LZones[0].Voice.Shape := wsTriangle
      else if LName = 'saw' then LZones[0].Voice.Shape := wsSaw
      else if LName = 'square' then LZones[0].Voice.Shape := wsSquare
      else raise Exception.Create('Unknown test instrument');
      if LMeta.Find('applied_sound') <> nil then
      begin
        LSound.CutoffHz := LMeta.Objects['applied_sound'].Integers['cutoff_hz'];
        LSound.SustainPercent := LMeta.Objects['applied_sound'].Integers['sustain_percent'];
        LZones[0].Voice := ApplyMusicalSound(LZones[0].Voice, LSound, 24000);
      end;
      LInstruments[I] := TInstrument.Create(LZones);
      LBindings[I].Instrument := LInstruments[I];
      LBindings[I].Bus := I;
      LBindings[I].MaximumTones := 128;
      LSettings := DefaultPercussionSettings(TPercussionKind(I), 24000);
      LSettings.Gain := LMeta.Arrays['percussion'].Objects[I].Floats['gain'];
      LSettings.Pan := LMeta.Arrays['percussion'].Objects[I].Floats['pan'];
      LSettings.GateSeconds := LMeta.Arrays['percussion'].Objects[I].Floats['gate_seconds'];
      LSettings.ReleaseSeconds := LMeta.Arrays['percussion'].Objects[I].Floats['release_seconds'];
      LSettings.ToneHz := LMeta.Arrays['percussion'].Objects[I].Floats['tone_hz'];
      LSettings.CutoffHz := LMeta.Arrays['percussion'].Objects[I].Floats['cutoff_hz'];
      LDrums[I] := TPercussionInstrument.Create(24000, LSettings);
      LBindings[I + 3].Instrument := LDrums[I].Instrument;
      LBindings[I + 3].Bus := I + 3;
      LBindings[I + 3].MaximumTones := 1;
      LBindings[I + 3].GateFrames := SampleFramesFromSeconds(LSettings.GateSeconds, 24000);
    end;
    LOptions := DefaultInstrumentStreamOptions(AResult.Objects['decisions'].Int64s['music_frames']);
    LOptions.TailFrames := AResult.Objects['output_resources'].Int64s['tail_frames'];
    LOptions.Seed := LMeta.Int64s['seed'];
    LOutput := TStudioInstrumentalOutput.Create(ACatalog, AJobId + '-replay', 24000,
      AResult.Objects['output_resources'].Int64s['frame_count'],
      LMeta.Objects['settings'].Arrays['levels'], LOptions.Seed);
    LReplay := TMusicDecisionReplay.Create(LFile, LBindings, LOutput.Graph, LOptions);
    while LReplay.ReadOutputs(173, StudioInstrumentalStemBuses, LMaster, LStems) do
      LOutput.Append(LMaster, LStems);
    Check(LReplay.State = issCompleted, 'Saved ordinary native decisions replay without learning or solving');
    LStored := LOutput.Finish;
    Check(LStored.Arrays['outputs'].Objects[0].Strings['wav_sha256'] =
      AResult.Arrays['outputs'].Objects[0].Strings['wav_sha256'],
      'Actual worker mix WAV replays with exact bytes');
    for I := 0 to 5 do
      Check(LStored.Arrays['parts'].Objects[I].Strings['wav_sha256'] =
        AResult.Arrays['parts'].Objects[I].Strings['wav_sha256'],
        'Each actual worker stem WAV replays with exact bytes');
    LBad := TJSONObject(AResult.Objects['decisions'].Clone);
    LBad.Strings['status'] := 'pending';
    LRejected := False;
    try OpenStudioDecisionJournal(ACatalog, LBad).Free;
    except on EAudio do LRejected := True; end;
    Check(LRejected, 'A partial decision journal cannot be opened as completed');
    LBad.Strings['status'] := 'completed';
    LBad.Int64s['bytes'] := LBad.Int64s['bytes'] + 1;
    LRejected := False;
    try OpenStudioDecisionJournal(ACatalog, LBad).Free;
    except on EAudio do LRejected := True; end;
    Check(LRejected, 'Native opening verifies completed size and digest');
    LFile.Position := 0;
    LReader := TMusicDecisionReader.Create(LFile);
    LDuplicate := TStudioDecisionWriter.Create(ACatalog, AJobId + '-duplicate');
    while LReader.TryNext(LChunk) do LDuplicate.Append(LChunk);
    LDuplicateReceipt := LDuplicate.Finish(LReader.CellCount, LReader.FrameCount);
    Check(LDuplicateReceipt.AsJSON = AResult.Objects['decisions'].AsJSON,
      'A duplicate publisher verifies/reuses the same flushed immutable journal');
  finally
    LDuplicateReceipt.Free;
    LDuplicate.Free;
    LReader.Free;
    LBad.Free;
    LReplay.Free;
    LOutput.Free;
    for I := 0 to 2 do
    begin
      LInstruments[I].Free;
      LDrums[I].Free;
    end;
    LFile.Free;
    LStored.Free;
    LMeta.Free;
  end;
end;

function SoundWrite(const AParentId, AId, AName: String;
  const AParent: TJSONObject): TJSONObject;
begin
  Result := TJSONObject.Create(['format', StudioJobWriteFormat, 'job_id', AId,
    'kind', 'instrumental_reperform', 'parent_job_id', AParentId,
    'parent_plan_sha256', AParent.Strings['plan_sha256'],
    'project_id', AParent.Strings['project_id'],
    'project_revision', AParent.Int64s['project_revision'],
    'project_snapshot_sha256', AParent.Strings['project_snapshot_sha256']]);
  Result.Add('instruments', AParent.Objects['settings'].Arrays['instruments'].Clone);
  Result.Arrays['instruments'].Strings[0] := AName;
end;

procedure CheckSoundChanges(const ACatalog, ALibrary, AParentId: String;
  const AParentResult: TJSONObject);
var
  LWrite, LState, LPrevious, LPrepared, LBeforeJob: TJSONObject;
  LParentId, LParentText, LRootShape, LShape, LJournal, LRequestText: String;
  LPaths: array[0..1] of String;
  LChanged, LRejected: Boolean;
  I, J: Integer;
begin
  LPrevious := TJSONObject(AParentResult.Clone);
  LParentId := AParentId;
  LWrite := nil;
  LState := nil;
  LPrepared := nil;
  LBeforeJob := ReadStudioJob(ACatalog, AParentId);
  LParentText := LBeforeJob.AsJSON;
  LBeforeJob.Free;
  LRootShape := AParentResult.Objects['settings'].Arrays['instruments'].Strings[0];
  LPaths[0] := ALibrary + '/collections/Chillsynth/Evening.wav';
  LPaths[1] := ALibrary + '/collections/lofi/Soft steps.wav';
  for I := 0 to 1 do
    Check(RenameFile(LPaths[I], LPaths[I] + '.sound-check-held'),
      'Hold isolated original recordings unavailable during sound-only jobs');
  try
    for I := 0 to 1 do
    begin
      if I = 0 then
      begin
        if LRootShape = 'square' then LShape := 'sine' else LShape := 'square';
      end
      else LShape := LRootShape;
      LWrite := SoundWrite(LParentId, 'sound-change-' + IntToStr(I), LShape, LPrevious);
      LRequestText := LWrite.AsJSON;
      LPrepared := PrepareStudioJob(ACatalog, LWrite);
      Check((LPrepared.Integers['source_count'] = 0) and
        not LPrepared.Booleans['learning_performed'] and
        not LPrepared.Booleans['notes_changed'] and
        (LPrepared.Objects['limits'].Integers['worker_seconds'] = MaximumStudioSessionSeconds),
        'Sound preflight reuses saved notes without source verification or new learning');
      FreeAndNil(LPrepared);
      LState := EnqueueStudioJob(ACatalog, LWrite);
      Check(LState.Strings['parent_job_id'] = LParentId, 'Queued edit retains its previous version');
      FreeAndNil(LState);
      LState := EnqueueStudioJob(ACatalog, LWrite);
      Check(LState.Booleans['already_queued'] and (LWrite.AsJSON = LRequestText),
        'Sound-edit submission retries reconcile without mutating the caller');
      FreeAndNil(LState);
      Check(RunStudioWorker(ACatalog, LWrite.Strings['job_id'], ALibrary),
        'Actual sound-only worker completes while original recordings are unavailable');
      LState := ReadStudioJob(ACatalog, LWrite.Strings['job_id']);
      Check((LState.Strings['status'] = 'completed') and
        (LState.Objects['workflow'].Integers['done'] = 8) and
        not LState.Objects['results'].Booleans['learning_performed'] and
        not LState.Objects['results'].Booleans['notes_changed'],
        'Durable sound edit completes its native progress without retraining');
      Check((LState.Objects['results'].Objects['decisions'].AsJSON =
          AParentResult.Objects['decisions'].AsJSON) and
        (LState.Objects['results'].Strings['model_sha256'] = AParentResult.Strings['model_sha256']) and
        (LState.Objects['results'].Arrays['graph'].AsJSON = AParentResult.Arrays['graph'].AsJSON) and
        (LState.Objects['results'].Objects['playlist_learning'].AsJSON =
          AParentResult.Objects['playlist_learning'].AsJSON),
        'Every saved note, latent decision, model and original learning receipt stays exact');
      Check(LState.Objects['results'].Strings['replay_source_job_id'] = AParentId,
        'Chained sound edits retain one direct immutable score source');
      for J := 0 to 5 do
      begin
        LChanged := LState.Objects['results'].Arrays['parts'].Objects[J].Strings['wav_sha256'] <>
          LPrevious.Arrays['parts'].Objects[J].Strings['wav_sha256'];
        Check(LChanged = (J = 0), 'Only the edited Bass stem changes; all other stem bytes stay exact');
      end;
      Check((LState.Objects['results'].Objects['before'].Strings['job_id'] = LParentId) and
        (LState.Objects['results'].Objects['original_reference'].AsJSON =
          AParentResult.Objects['original_reference'].AsJSON),
        'Before and original comparison keep their actual separate origins');
      if I = 1 then
        Check(LState.Objects['results'].Arrays['outputs'].Objects[0].Strings['wav_sha256'] =
          AParentResult.Arrays['outputs'].Objects[0].Strings['wav_sha256'],
          'Restoring the original instrument reproduces the original mix exactly');
      LParentId := LWrite.Strings['job_id'];
      LPrevious.Free;
      LPrevious := TJSONObject(LState.Objects['results'].Clone);
      FreeAndNil(LState);
      FreeAndNil(LWrite);
    end;
    LWrite := SoundWrite(AParentId, 'sound-no-change', LRootShape, AParentResult);
    LRejected := False;
    try LPrepared := PrepareStudioJob(ACatalog, LWrite);
    except on EAudio do LRejected := True; end;
    FreeAndNil(LPrepared);
    Check(LRejected, 'A no-op edit cannot queue another job');
    FreeAndNil(LWrite);
    LWrite := SoundWrite(AParentId, 'sound-stale', LShape, AParentResult);
    LWrite.Strings['parent_plan_sha256'] := StringOfChar('0', 64);
    LRejected := False;
    try LPrepared := PrepareStudioJob(ACatalog, LWrite);
    except on EAudio do LRejected := True; end;
    FreeAndNil(LPrepared);
    Check(LRejected, 'Stale previous-version binding rejects before queuing');
    FreeAndNil(LWrite);
    LWrite := SoundWrite(AParentId, 'sound-missing-notes', 'square', AParentResult);
    LState := EnqueueStudioJob(ACatalog, LWrite);
    FreeAndNil(LState);
    LJournal := ListeningAssetDirectory(ACatalog) + PathDelim + 'decisions' + PathDelim +
      AParentResult.Objects['decisions'].Strings['sha256'] + '.pmd';
    Check(RenameFile(LJournal, LJournal + '.sound-check-held'), 'Hold isolated saved notes unavailable');
    try
      Check(not RunStudioWorker(ACatalog, LWrite.Strings['job_id'], ALibrary),
        'Missing notes fail without silently generating replacements');
    finally
      Check(RenameFile(LJournal + '.sound-check-held', LJournal), 'Restore exact isolated saved notes');
    end;
    LState := ReadStudioJob(ACatalog, LWrite.Strings['job_id']);
    Check((LState.Strings['status'] = 'failed') and
      (LState.Strings['parent_job_id'] = AParentId) and
      (LState.Objects['results'].Find('outputs') = nil),
      'Failed edit retains its previous-version link without a false completed output');
    FreeAndNil(LState);
    LBeforeJob := ReadStudioJob(ACatalog, AParentId);
    try Check(LBeforeJob.AsJSON = LParentText, 'Sound edits never mutate the accepted parent job');
    finally LBeforeJob.Free end;
  finally
    for I := 0 to 1 do
      Check(RenameFile(LPaths[I] + '.sound-check-held', LPaths[I]), 'Restore exact isolated source recordings');
    LPrepared.Free;
    LState.Free;
    LWrite.Free;
    LPrevious.Free;
  end;
end;

function NoteWrite(const AParentId, AId: String;
  const AParent: TJSONObject): TJSONObject;
var
  LEdit: TJSONObject;
  LParts: TJSONArray;
  I: Integer;
begin
  Result := SoundWrite(AParentId, AId,
    AParent.Objects['settings'].Arrays['instruments'].Strings[0], AParent);
  Result.Delete('instruments');
  Result.Strings['kind'] := 'instrumental_regenerate';
  LEdit := TJSONObject.Create(['start_frame', 0,
    'end_frame', AParent.Objects['decisions'].Int64s['music_frames'],
    'parts', TJSONArray.Create([False, False, True, False, False, False]),
    'harmony', False, 'rhythm', False, 'tonic', 0, 'seed', 991]);
  Result.Add('note_edit', LEdit);
  LParts := TJSONArray.Create;
  LEdit.Add('controls', TJSONObject.Create(['guide', False, 'tonic_bias', 0, 'parts', LParts]));
  for I := 0 to 2 do
    LParts.Add(TJSONObject.Create(['minimum_pitch', 0, 'maximum_pitch', 127,
      'activity_bias', 0, 'velocity_percent', 100, 'gate_percent', 100]));
end;

procedure CheckNoteChanges(const ACatalog, ALibrary, AParentId: String;
  const AParentResult: TJSONObject);
var
  LWrite: TJSONObject;
  LState: TJSONObject;
  LPrevious: TJSONObject;
  LPrepared: TJSONObject;
  LMeta: TJSONObject;
  LBefore: TJSONObject;
  LParentId: String;
  LParentText: String;
  LRequestText: String;
  LPaths: array[0..1] of String;
  LRejected: Boolean;
  LChanged: Boolean;
  LAnyChanged: Boolean;
  I: Integer;
  J: Integer;
begin
  LWrite := nil;
  LState := nil;
  LPrepared := nil;
  LMeta := nil;
  LPrevious := TJSONObject(AParentResult.Clone);
  LParentId := AParentId;
  LBefore := ReadStudioJob(ACatalog, AParentId);
  LParentText := LBefore.AsJSON;
  LBefore.Free;
  LPaths[0] := ALibrary + '/collections/Chillsynth/Evening.wav';
  LPaths[1] := ALibrary + '/collections/lofi/Soft steps.wav';
  for I := 0 to 1 do
    Check(RenameFile(LPaths[I], LPaths[I] + '.note-check-held'),
      'Hold isolated original recordings unavailable during graph edits');
  LAnyChanged := False;
  try
    for I := 0 to 1 do
    begin
      LWrite := NoteWrite(LParentId, 'note-change-' + IntToStr(I), LPrevious);
      if I = 1 then
      begin
        for J := 0 to 2 do LWrite.Objects['note_edit'].Arrays['parts'].Booleans[J] := True;
        LWrite.Objects['note_edit'].Booleans['harmony'] := True;
        LWrite.Objects['note_edit'].Booleans['rhythm'] := True;
        LWrite.Objects['note_edit'].Objects['controls'].Arrays['parts'].Objects[2].Integers['minimum_pitch'] := 57;
        LWrite.Objects['note_edit'].Objects['controls'].Arrays['parts'].Objects[2].Integers['maximum_pitch'] := 57;
      end;
      LRequestText := LWrite.AsJSON;
      LPrepared := PrepareStudioJob(ACatalog, LWrite);
      Check((LPrepared.Integers['source_count'] = 0) and
        (LPrepared.Int64s['unique_source_bytes_to_verify'] = 0) and
        not LPrepared.Booleans['learning_performed'] and
        LPrepared.Booleans['notes_change_requested'],
        'Graph edit preflight needs no source payload or new learning');
      FreeAndNil(LPrepared);
      LState := EnqueueStudioJob(ACatalog, LWrite);
      FreeAndNil(LState);
      LState := EnqueueStudioJob(ACatalog, LWrite);
      Check(LState.Booleans['already_queued'] and (LWrite.AsJSON = LRequestText),
        'Graph submission retries are idempotent and preserve the request');
      FreeAndNil(LState);
      Check(RunStudioWorker(ACatalog, LWrite.Strings['job_id'], ALibrary),
        'Actual retained graph worker completes without original recordings');
      LState := ReadStudioJob(ACatalog, LWrite.Strings['job_id']);
      Check((LState.Strings['status'] = 'completed') and
        not LState.Objects['results'].Booleans['learning_performed'] and
        (LState.Objects['results'].Objects['playlist_learning'].AsJSON =
          AParentResult.Objects['playlist_learning'].AsJSON) and
        (LState.Objects['results'].Strings['model_sha256'] = AParentResult.Strings['model_sha256']),
        'Graph child preserves actual model and learning lineage');
      Check((LState.Objects['results'].Objects['before'].Strings['job_id'] = LParentId) and
        (LState.Objects['results'].Strings['replay_source_job_id'] = LWrite.Strings['job_id']) and
        (LState.Objects['results'].Objects['original_reference'].AsJSON =
          AParentResult.Objects['original_reference'].AsJSON),
        'Graph child retains Before/Original and becomes its own exact note source');
      LMeta := ReadStudioJSON(StudioJobDirectory(ACatalog, LWrite.Strings['job_id']) +
        PathDelim + 'instrumental-stream-completed.json');
      Check((StudioTextHash(LMeta.AsJSON) = LState.Objects['results'].Strings['plan_sha256']) and
        (LMeta.Objects['decisions'].AsJSON = LState.Objects['results'].Objects['decisions'].AsJSON),
        'Completed graph child binds its saved journal and full musical plan');
      FreeAndNil(LMeta);
      for J := 0 to 5 do
      begin
        LChanged := LState.Objects['results'].Arrays['parts'].Objects[J].Strings['wav_sha256'] <>
          LPrevious.Arrays['parts'].Objects[J].Strings['wav_sha256'];
        LAnyChanged := LAnyChanged or LChanged;
        if ((I = 0) and (J <> 2)) or (J >= 3) then
          Check(not LChanged, 'Unrequested native instrumental stems stay exact after graph edits');
      end;
      LParentId := LWrite.Strings['job_id'];
      LPrevious.Free;
      LPrevious := TJSONObject(LState.Objects['results'].Clone);
      FreeAndNil(LState);
      FreeAndNil(LWrite);
    end;
    Check(LAnyChanged, 'Actual retained native graph edits change instrumental output');
    LWrite := SoundWrite(LParentId, 'sound-after-notes', 'square', LPrevious);
    if LPrevious.Objects['settings'].Arrays['instruments'].Strings[0] = 'square' then
      LWrite.Arrays['instruments'].Strings[0] := 'sine';
    LState := EnqueueStudioJob(ACatalog, LWrite);
    FreeAndNil(LState);
    Check(RunStudioWorker(ACatalog, LWrite.Strings['job_id'], ALibrary),
      'Sound changes reuse an edited graph child as the exact note source');
    LState := ReadStudioJob(ACatalog, LWrite.Strings['job_id']);
    Check((LState.Objects['results'].Objects['decisions'].AsJSON = LPrevious.Objects['decisions'].AsJSON) and
      (LState.Objects['results'].Strings['replay_source_job_id'] = LParentId),
      'Sound-after-note edits preserve the new notes and their direct source');
    FreeAndNil(LWrite);
    LWrite := NoteWrite(LState.Strings['job_id'], 'notes-after-sounds', LState.Objects['results']);
    FreeAndNil(LState);
    LState := EnqueueStudioJob(ACatalog, LWrite);
    FreeAndNil(LState);
    Check(RunStudioWorker(ACatalog, LWrite.Strings['job_id'], ALibrary),
      'Note edits after sound edits share the same retained renderer and current instruments');
    FreeAndNil(LWrite);
    LWrite := NoteWrite(AParentId, 'note-conflict', AParentResult);
    LWrite.Objects['note_edit'].Objects['controls'].Arrays['parts'].Objects[2].Integers['maximum_pitch'] := 1;
    LState := EnqueueStudioJob(ACatalog, LWrite);
    FreeAndNil(LState);
    Check(not RunStudioWorker(ACatalog, LWrite.Strings['job_id'], ALibrary),
      'Contradictory native graph request fails without silently relaxing pitch bounds');
    LState := ReadStudioJob(ACatalog, LWrite.Strings['job_id']);
    Check((LState.Strings['status'] = 'failed') and (LState.Strings['error_message'] <> '') and
      (LState.Objects['results'].Find('outputs') = nil) and
      (LState.Objects['results'].Find('decisions') = nil),
      'Failed note edit publishes no partial accepted audio or decision receipt');
    FreeAndNil(LState);
    FreeAndNil(LWrite);
    LWrite := NoteWrite(AParentId, 'note-stale', AParentResult);
    LWrite.Strings['parent_plan_sha256'] := StringOfChar('0', 64);
    LRejected := False;
    try LPrepared := PrepareStudioJob(ACatalog, LWrite);
    except on E: Exception do LRejected := True end;
    Check(LRejected, 'Stale native graph parent is rejected before queueing');
    FreeAndNil(LWrite);
    LWrite := NoteWrite(AParentId, 'note-cancelled', AParentResult);
    LState := EnqueueStudioJob(ACatalog, LWrite);
    FreeAndNil(LState);
    LState := CancelStudioJob(ACatalog, LWrite.Strings['job_id']);
    Check(LState.Strings['status'] = 'cancelled', 'Queued graph edit supports ordinary cancellation');
    LBefore := ReadStudioJob(ACatalog, AParentId);
    try Check(LBefore.AsJSON = LParentText, 'Native graph jobs never mutate the accepted parent');
    finally LBefore.Free end;
  finally
    for I := 0 to 1 do
      Check(RenameFile(LPaths[I] + '.note-check-held', LPaths[I]), 'Restore isolated original recordings');
    LMeta.Free;
    LWrite.Free;
    LState.Free;
    LPrepared.Free;
    LPrevious.Free;
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
          CheckSavedDecisions(LCatalog, LJob.Strings['job_id'], LResult.Objects['results']);
          CheckSoundChanges(LCatalog, LLibrary, LJob.Strings['job_id'], LResult.Objects['results']);
          CheckNoteChanges(LCatalog, LLibrary, LJob.Strings['job_id'], LResult.Objects['results']);
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
    CheckClassifiedLearning(ExpandFileName(ARoot), LCatalog, LLibrary, LPlaylist);
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
