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
program StudioWorkerConformance;

{$mode delphi}
{$H+}

uses
  {$IFDEF UNIX}cthreads,{$ENDIF}
  Classes,
  SysUtils,
  Math,
  fpjson,
  pythian.audio,
  pythian.hash,
  pythian.wave.read,
  pythian.wave.stream,
  pythian.tools.annotations.catalog,
  pythian.tools.studio.projects,
  pythian.tools.studio.jobs,
  pythian.tools.studio.worker,
  pythian.tools.studio.live,
  pythian.tools.studio.references,
  pythian.tools.studio.&library.discovery,
  pythian.tools.listen.catalog;

var
  GChecks: Integer;

type
  TLiveWorker = class(TThread)
    Catalog: String;
    JobId: String;
    Succeeded: Boolean;
    Failure: String;
    procedure Execute; override;
  end;

procedure TLiveWorker.Execute;
begin
  try
    Succeeded := RunStudioWorker(Catalog, JobId, ExtractFileDir(Catalog) + PathDelim + 'library');
  except
    on E: Exception do Failure := E.Message;
  end;
end;

procedure Check(const ACondition: Boolean; const AMessage: String);
begin
  Inc(GChecks);
  if not ACondition then
  begin
    raise Exception.Create(AMessage);
  end;
end;

procedure CheckProgressEvents(const ACatalog, AId: String; const AReused: Boolean);
var
  LJob, LEvent: TJSONObject;
  LIndex, LEvents, LLearning, LPasses: Integer;
  LAnalysis, LRender, LBytes, LReuse: Boolean;
  LStage: String;
begin
  LLearning := 0; LPasses := 0;
  LAnalysis := False; LRender := False; LBytes := False; LReuse := False;
  LJob := ReadStudioJob(ACatalog, AId);
  try
    LEvents := LJob.Integers['event_revision'];
    Check(LEvents < 300, 'Small job has bounded checkpoint writes, not one event per observation/frame');
    Check((LJob.Get('progress_unit', '') = '') and (LJob.Get('progress_pass', 0) = 0),
      'Terminal status clears intermediate progress metadata');
    for LIndex := 1 to LEvents do
    begin
      LEvent := ReadStudioJSON(StudioJobDirectory(ACatalog, AId) + PathDelim +
        Format('%.8d.event.json', [LIndex]));
      try
        Check((LEvent.Int64s['done'] >= 0) and (LEvent.Int64s['done'] <= LEvent.Int64s['total']),
          'Persisted progress has valid measured bounds');
        LStage := LEvent.Strings['stage'];
        if LStage = 'reload_verified_model' then LReuse := True;
        if LStage = 'analyze_selected_ranges' then
          LAnalysis := LAnalysis or ((LEvent.Strings['progress_unit'] = 'observations') and
            (LEvent.Int64s['done'] = LEvent.Int64s['total']) and (LEvent.Int64s['done'] > 1));
        if LStage = 'verify_sources' then
          LBytes := LBytes or ((LEvent.Get('progress_unit', '') = 'bytes') and (LEvent.Int64s['done'] > 1));
        if LStage = 'generate_auditions' then
          LRender := LRender or ((LEvent.Strings['progress_unit'] = 'frames') and
            (LEvent.Int64s['done'] = LEvent.Int64s['total']) and (LEvent.Int64s['done'] > 1));
        if (LStage = 'learn_raw_palette') or (LStage = 'learn_wfc_model') then
        begin
          Inc(LLearning);
          LPasses := Max(LPasses, LEvent.Integers['progress_pass']);
          Check(LEvent.Strings['progress_unit'] = 'observations', 'Learning uses actual observation units');
        end;
      finally LEvent.Free end;
    end;
    Check(LBytes and LRender, 'Source verification and rendering have real measured completion');
    if AReused then Check(LReuse and not LAnalysis and (LLearning = 0), 'Reuse explicitly skips learning')
    else Check(LAnalysis and (LLearning > 2) and (LPasses > 8), 'Cold analysis and multiple learning passes are observable');
  finally LJob.Free end;
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

function MakeSource(const ARoot, AName: String; const APhase: Integer;
  const ARate: Integer = 8000; const AChannels: Integer = 1;
  const AInvert: Boolean = False): String;
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
  LFrequency: Double;
  LChannel: Integer;
begin
  LInbox := ARoot + PathDelim + 'inbox-' + AName;
  Check(ForceDirectories(LInbox), 'Create first-party source inbox');
  SetLength(LSamples, 64000 * AChannels);
  for LIndex := 0 to 63999 do
  begin
    LFrequency := 220 + (((LIndex div 4000) + APhase) mod 4) * 55;
    for LChannel := 0 to AChannels - 1 do
    begin
      LSamples[LIndex * AChannels + LChannel] :=
        0.15 * Sin(2 * Pi * (LFrequency + LChannel * 110) * LIndex / ARate);
      if AInvert then
        LSamples[LIndex * AChannels + LChannel] := -LSamples[LIndex * AChannels + LChannel];
    end;
  end;
  LClip := TAudioClip.Create(ARate, AChannels, LSamples);
  try
    LPath := LInbox + PathDelim + 'source.wav';
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
    LRow.Add('source_group', 'studio_worker_' + AName);
    LRow.Add('clock_id', '');
    LRow.Add('partition', 'unassigned');
    LRow.Add('title', 'First-party authored periodic control ' + AName);
    LRow.Add('provenance', 'Pascal-authored oscillator fixture; no recorded musical truth');
    LRow.Add('license', 'MIT');
    WriteStudioJSONNew(LInbox + PathDelim + 'manifest.json', LManifest);
  finally
    LManifest.Free;
  end;
  LReport := ImportLabelInbox(LInbox, ARoot + PathDelim + 'catalog');
  try
    Check((LReport.Integers['imported'] = 1) and (LReport.Integers['failed'] = 0),
      'Native import of authored source');
  finally
    LReport.Free;
  end;
end;

function ProjectWrite(const AProjectId, AHash: String): TJSONObject;
var
  LRows: TJSONArray;
  LRow: TJSONObject;
  LLabels: TJSONArray;
  LIndex: Integer;
begin
  Result := TJSONObject.Create;
  Result.Add('format', StudioProjectWriteFormat);
  Result.Add('project_id', AProjectId);
  Result.Add('expected_revision', 0);
  Result.Add('name', 'Authored control ' + AProjectId);
  Result.Add('style_intent', '');
  Result.Add('learning_mode', 'raw_acoustic');
  LRows := TJSONArray.Create;
  Result.Add('sources', LRows);
  for LIndex := 0 to 1 do
  begin
    LRow := TJSONObject.Create;
    LRows.Add(LRow);
    LRow.Add('source_sha256', AHash);
    LRow.Add('selection', 'range');
    LRow.Add('start_frame', LIndex * 32000);
    LRow.Add('end_frame', LIndex * 32000 + 24000);
    LLabels := TJSONArray.Create;
    LLabels.Add('caller control');
    LRow.Add('classifications', LLabels);
  end;
  LRows := TJSONArray.Create;
  Result.Add('parked_sources', LRows);
  LRow := TJSONObject.Create;
  LRows.Add(LRow);
  LRow.Add('source_sha256', AHash);
  LRow.Add('selection', 'full');
  LRow.Add('classifications', TJSONArray.Create(['unchecked whole recording']));

end;

function JobWrite(const AId, AHash: String; const AProject: TJSONObject): TJSONObject;
var
  LSeeds: TJSONArray;
  LWeights: TJSONArray;
  LWeight: TJSONObject;
begin
  Result := TJSONObject.Create;
  Result.Add('format', StudioJobWriteFormat);
  Result.Add('job_id', AId);
  Result.Add('kind', 'train_generate');
  Result.Add('project_id', AProject.Strings['project_id']);
  Result.Add('project_revision', AProject.Int64s['revision']);
  Result.Add('project_snapshot_sha256', AProject.Strings['snapshot_sha256']);
  Result.Add('duration_ms', 20000);
  LSeeds := TJSONArray.Create;
  LSeeds.Add(731);
  Result.Add('seeds', LSeeds);
  Result.Add('maximum_tokens', 4);
  Result.Add('model_order', 2);
  Result.Add('resolve_unassigned', 'development');
  LWeights := TJSONArray.Create;
  Result.Add('source_weights', LWeights);
  LWeight := TJSONObject.Create;
  LWeight.Add('source_sha256', AHash);
  LWeight.Add('weight', 1);
  LWeights.Add(LWeight);
end;

procedure CheckEmptyTraining(const ACatalog, AHash: String);
var
  LWrite: TJSONObject;
  LProject: TJSONObject;
  LJob: TJSONObject;
  LResult: TJSONObject;
  LFailed: Boolean;
begin
  LWrite := ProjectWrite('all-unchecked', AHash);
  try
    LWrite.Arrays['sources'].Clear;
    LProject := SaveStudioProject(ACatalog, LWrite);
    try
      LJob := JobWrite('empty-training', AHash, LProject);
      try
        LFailed := False;
        try
          LResult := PrepareStudioJob(ACatalog, LJob);
          LResult.Free;
        except
          on E: Exception do
          begin
            LFailed := Pos('range count', E.Message) > 0;
          end;
        end;
        Check(LFailed, 'All unchecked project cannot prepare generation');
      finally
        LJob.Free;
      end;
    finally
      LProject.Free;
    end;
  finally
    LWrite.Free;
  end;
end;

procedure CheckAtomicListening(const ACatalog: String);
var
  LOriginalCount: Integer;
  LPacket: TJSONObject;
  LResult: TJSONObject;
  LFirst: String;
  LSecond: String;
  LConflict: String;
  LQueuePath: String;
  LQueueHash: String;
  LLock: TFileStream;
  LFailed: Boolean;
begin
  LResult := ReadListeningQueue(ACatalog);
  try
    LOriginalCount := LResult.Integers['waiting_count'];
  finally
    LResult.Free;
  end;
  LFirst := ACatalog + PathDelim + 'append-first.json';
  LSecond := ACatalog + PathDelim + 'append-second.json';
  LConflict := ACatalog + PathDelim + 'append-conflict.json';
  LQueuePath := ACatalog + PathDelim + 'listening' + PathDelim + 'queue.json';
  LPacket := ReadStudioJSON(StudioJobDirectory(ACatalog, 'first') +
    PathDelim + 'listening-publication.json');
  try
    LPacket.Arrays['items'].Objects[0].Strings['id'] := 'independent-one';
    WriteStudioJSONNew(LFirst, LPacket);
    LPacket.Arrays['items'].Objects[0].Strings['id'] := 'independent-two';
    WriteStudioJSONNew(LSecond, LPacket);
    LPacket.Arrays['items'].Objects[0].Strings['id'] := 'independent-one';
    LPacket.Arrays['items'].Objects[0].Strings['question'] := 'Changed question must not replace old request';
    WriteStudioJSONNew(LConflict, LPacket);
  finally
    LPacket.Free;
  end;
  LResult := AppendListeningQueue(ACatalog, LFirst);
  LResult.Free;
  LResult := AppendListeningQueue(ACatalog, LSecond);
  try
    Check(LResult.Integers['waiting_count'] = LOriginalCount + 2, 'Independent packets both retained');
  finally
    LResult.Free;
  end;
  LQueueHash := HashFile(LQueuePath);
  LResult := AppendListeningQueue(ACatalog, LFirst);
  LResult.Free;
  Check(HashFile(LQueuePath) = LQueueHash, 'Identical append exactly once');
  LFailed := False;
  try
    LResult := AppendListeningQueue(ACatalog, LConflict);
    LResult.Free;
  except
    on E: EAudio do
    begin
      LFailed := True;
    end;
  end;
  Check(LFailed and (HashFile(LQueuePath) = LQueueHash), 'Conflict preserves existing queue');
  LLock := TFileStream.Create(ACatalog + PathDelim + 'listening' + PathDelim +
    'queue.lock', fmOpenReadWrite or fmShareExclusive);
  try
    LFailed := False;
    try
      LResult := AppendListeningQueue(ACatalog, LFirst);
      LResult.Free;
    except
      on E: EFCreateError do
      begin
        LFailed := True;
      end;
      on E: EFOpenError do
      begin
        LFailed := True;
      end;
    end;
    Check(LFailed and (HashFile(LQueuePath) = LQueueHash), 'Owned writer lock prevents publication');
  finally
    LLock.Free;
  end;
  LResult := AppendListeningQueue(ACatalog, LFirst);
  LResult.Free;
  Check(HashFile(LQueuePath) = LQueueHash, 'Exact retry after released lock reconciles');
end;

procedure CheckExperiments(const ACatalog: String);
var
  LPacket, LRow, LReference, LAsset, LStaged, LProvenance, LReport,
    LDefinition, LPrepared, LRaw, LProjected, LTransaction, LChoice: TJSONObject;
  LPath, LBeforeHash, LReplayRoot, LExportPath, LExportHash: String;
  LCount, I, J: Integer;
  LRejected: Boolean;
begin
  { Big Boss: synthetic originals and copied generated clips, never operator votes. }
  LPath := ACatalog + PathDelim + 'experiment-fixture.json';
  LPacket := ReadStudioJSON(StudioJobDirectory(ACatalog, 'successor') +
    PathDelim + 'listening-publication.json');
  try
    LRow := LPacket.Arrays['items'].Objects[0];
    Check((LRow.Strings['kind'] = 'pair') and
      (LRow.Objects['experiment'].Objects['parent'].Strings['request_id'] <> ''),
      'Source continuity publishes exact parent comparison identity');
    LRow.Delete('experiment');
    LRow.Strings['id'] := 'experiment-before-after';
    LReference := TJSONObject(LRow.Clone);
    LPacket.Arrays['items'].Add(LReference);
    LReference.Strings['id'] := 'experiment-original';
    LReference.Strings['kind'] := 'single';
    LReference.Arrays['assets'].Delete(1);
    LReference.Arrays['ranges'].Delete(1);
    LAsset := LReference.Arrays['assets'].Objects[0];
    LStaged := StageListeningAsset(ACatalog, ExtractFileDir(ACatalog) + PathDelim +
      'inbox-one' + PathDelim + 'source.wav');
    try
      LAsset.Strings['role'] := 'reference';
      LAsset.Strings['sha256'] := LStaged.Strings['sha256'];
      LAsset.Int64s['bytes'] := LStaged.Int64s['bytes'];
      LAsset.Int64s['frames'] := LStaged.Int64s['frames'];
      LAsset.Integers['sample_rate'] := LStaged.Integers['sample_rate'];
      LAsset.Integers['channels'] := LStaged.Integers['channels'];
      LAsset.Delete('provenance');
      LProvenance := TJSONObject.Create;
      LAsset.Add('provenance', LProvenance);
      LProvenance.Add('source_sha256', LStaged.Strings['sha256']);
      LProvenance.Add('source_group', 'authored-synthetic');
      LProvenance.Add('clock_id', 'synthetic-original');
      LProvenance.Add('partition', 'development');
      LReference.Arrays['ranges'].Objects[0].Int64s['end_frame'] := LStaged.Int64s['frames'];
      LReference.Arrays['ranges'].Objects[0].Strings['asset_id'] := LAsset.Strings['id'];
    finally
      LStaged.Free;
    end;
    WriteStudioJSONNew(LPath, LPacket);
  finally
    LPacket.Free;
  end;
  LReport := AppendListeningQueue(ACatalog, LPath);
  LReport.Free;
  LRaw := ReadListeningQueue(ACatalog);
  try
    LCount := LRaw.Arrays['items'].Count;
    LBeforeHash := StudioTextHash(LRaw.AsJSON);
    LDefinition := TJSONObject.Create;
    try
      LDefinition.Add('id', 'guided-continuity');
      LDefinition.Add('task_id', 'NS-5_continuity_01');
      LDefinition.Add('comparison_id', 'experiment-before-after');
      LDefinition.Add('reference_id', 'experiment-original');
      LDefinition.Add('title', 'Smoother notes');
      LDefinition.Add('question', 'Which version has fewer broken or jittery notes?');
      LDefinition.Add('change', 'Keep matching neighbors together.');
      LDefinition.Add('decision', 'Decide whether to keep this core change.');
      LPrepared := PrepareListeningExperiment(ACatalog, LDefinition);
    finally
      LDefinition.Free;
    end;
    try
      LRow := LPrepared.Arrays['items'].Objects[0];
      Check((LRow.Arrays['assets'].Count = 2) and
        (LRow.Objects['answer_spec'].Arrays['choices'].Count = 1),
        'Prepared experiment has two voting clips and one question');
      LPath := ACatalog + PathDelim + 'experiment-prepared.json';
      WriteStudioJSONNew(LPath, LPrepared);
      LReport := AppendListeningQueue(ACatalog, LPath);
      LReport.Free;
      LReport := ReadListeningQueue(ACatalog);
      try
        Check(LReport.Arrays['items'].Count = LCount + 1, 'Raw history keeps original requests');
        for I := 0 to LCount - 1 do
          Check(LReport.Arrays['items'].Objects[I].AsJSON = LRaw.Arrays['items'].Objects[I].AsJSON,
            'Existing request, answer and hash remain unchanged');
        LProjected := TJSONObject(LReport.Clone);
        try
          ProjectListeningExperiments(LProjected);
          Check(LProjected.Arrays['items'].Count = LCount - 1,
            'Prepared context replaces only the two pending context rows');
          Check(StudioTextHash(LRaw.AsJSON) = LBeforeHash, 'Projection never mutates durable readback');
        finally
          LProjected.Free;
        end;
        LRow := LReport.Arrays['items'].Objects[LCount];
        LTransaction := TJSONObject.Create;
        try
          LTransaction.Add('version', 1);
          LTransaction.Add('request_id', LRow.Strings['id']);
          LTransaction.Add('request_sha256', LRow.Strings['request_sha256']);
          LTransaction.Add('expected_revision', 0);
          LTransaction.Add('reviewer', 'synthetic-qa');
          LTransaction.Add('status', 'submitted');
          LTransaction.Add('choices', TJSONArray.Create);
          LChoice := TJSONObject.Create;
          LTransaction.Arrays['choices'].Add(LChoice);
          LChoice.Add('id', 'continuity_preference'); LChoice.Add('value', 'unknown');
          LTransaction.Add('scores', TJSONArray.Create);
          LTransaction.Add('comments', TJSONArray.Create);
          LReference := CommitListeningReview(ACatalog, LTransaction); LReference.Free;
          LReference := CommitListeningReview(ACatalog, LTransaction);
          try
            Check(LReference.Integers['revision'] = 1, 'Lost-response retry commits exactly once');
          finally LReference.Free; end;
        finally LTransaction.Free; end;
      finally LReport.Free; end;
      LReport := ReadListeningQueue(ACatalog);
      try
        ProjectListeningExperiments(LReport);
        Check(LReport.Arrays['items'].Count = LCount - 2,
          'Save and reload do not resurrect the superseded context questions');
      finally LReport.Free; end;
      LRow := LPrepared.Arrays['items'].Objects[0];
      LRow.Strings['id'] := 'bad-guided-binding';
      LRow.Objects['experiment'].Objects['reference'].Strings['request_sha256'] := StringOfChar('0', 64);
      LPath := ACatalog + PathDelim + 'experiment-bad.json';
      WriteStudioJSONNew(LPath, LPrepared);
      LRejected := False;
      try
        LReport := AppendListeningQueue(ACatalog, LPath); LReport.Free;
      except on E: EAudio do LRejected := True; end;
      Check(LRejected, 'Changed original-reference identity is rejected');
    finally LPrepared.Free; end;
  finally LRaw.Free; end;
  LReplayRoot := ACatalog + '-listening-replay';
  Check(ForceDirectories(LReplayRoot), 'Create fresh experiment replay catalog');
  LRaw := ReadStudioJSON(ACatalog + PathDelim + 'listening' + PathDelim + 'queue.json');
  try
    for I := 0 to LRaw.Arrays['items'].Count - 1 do
      for J := 0 to LRaw.Arrays['items'].Objects[I].Arrays['assets'].Count - 1 do
      begin
        LAsset := LRaw.Arrays['items'].Objects[I].Arrays['assets'].Objects[J];
        Check(LAsset.Strings['storage'] = 'listening', 'Replay fixture uses staged first-party audio');
        LReport := StageListeningAsset(LReplayRoot, ACatalog + PathDelim + 'listening' +
          PathDelim + 'assets' + PathDelim + LAsset.Strings['sha256'] + '.wav');
        LReport.Free;
      end;
  finally LRaw.Free; end;
  LExportPath := ACatalog + PathDelim + 'experiment-export.json';
  LReport := ExportListeningPacket(ACatalog, LExportPath);
  try LExportHash := LReport.Strings['sha256']; finally LReport.Free; end;
  LReport := ReplayListeningPacket(LReplayRoot, LExportPath);
  try
    Check(LReport.Integers['events'] = 1, 'Fresh replay retains the explicit saved answer only');
  finally LReport.Free; end;
  LReport := ExportListeningPacket(LReplayRoot, LReplayRoot + PathDelim + 'reexport.json');
  try
    Check(LReport.Strings['sha256'] = LExportHash,
      'Fresh experiment export/replay preserves exact requests, context and response history');
  finally LReport.Free; end;
end;

procedure Run(const ARoot: String);
var
  LHash: String;
  LHash2: String;
  LCatalog: String;
  LWrite: TJSONObject;
  LProject: TJSONObject;
  LProjectWrite: TJSONObject;
  LJob: TJSONObject;
  LPreparation: TJSONObject;
  LQueue: TJSONObject;
  LOutput: TJSONObject;
  LArtifact: TJSONObject;
  LStream: TFileStream;
  LWave: TWaveFrameReader;
  LModelHash: String;
  LWaveHash: String;
  LSuccessorHash: String;
  LJournalPath: String;
  LJournalBytes: Int64;
  LBaselineLedger: TJSONObject;
  LSuccessorLedger: TJSONObject;
  LIndex: Integer;
  LFailed: Boolean;
  LByte: Byte;
begin
  Check(not DirectoryExists(ARoot), 'Worker fixture root must be fresh');
  Check(ForceDirectories(ARoot), 'Create first-party fixture root');
  LHash := MakeSource(ARoot, 'one', 0);
  LHash2 := MakeSource(ARoot, 'two', 1);
  LCatalog := ARoot + PathDelim + 'catalog';
  CheckEmptyTraining(LCatalog, LHash);
  LProjectWrite := ProjectWrite('one', LHash);
  try
    LProject := SaveStudioProject(LCatalog, LProjectWrite);
    try
      LWrite := JobWrite('first', LHash, LProject);
      try
        LPreparation := PrepareStudioJob(LCatalog, LWrite);
        try
          Check(LPreparation.Integers['source_count'] = 1, 'Distinct source count separate from ranges');
          Check(LPreparation.Integers['range_count'] = 2, 'Two original disjoint ranges');
          Check(LPreparation.Int64s['selected_frames'] = 48000, 'Selected original clock');
          Check(LPreparation.Int64s['unique_source_bytes_to_verify'] =
            LProject.Arrays['sources'].Objects[0].Int64s['source_bytes'],
            'Original bytes counted once for two selected ranges');
          Check(LPreparation.Arrays['used_sources'].Count = 0, 'Preparation does not invent used material');
          Check(LPreparation.Objects['limits'].Integers['worker_seconds'] = MaximumStudioTrainingSeconds,
            'Long training gets a declared finite two-hour budget');
        finally
          LPreparation.Free;
        end;
        LJob := EnqueueStudioJob(LCatalog, LWrite);
        LJob.Free;
        Check(RunStudioWorker(LCatalog, 'first', ARoot + PathDelim + 'library'),
          'Actual source-to-WFC-to-20-second-audio pipeline; inspect first/failure.txt on failure');
        CheckProgressEvents(LCatalog, 'first', False);
        LJob := ReadStudioJob(LCatalog, 'first');
        try
          Check(LJob.Strings['status'] = 'completed', 'Actual job terminal state');
          Check(LJob.Integers['maximum_worker_seconds'] = MaximumStudioTrainingSeconds,
            'Generation completion detail agrees with its declared budget');
          Check((LJob.Objects['results'].Integers['completed_render_count'] = 1) and
            (LJob.Objects['results'].Integers['expected_render_count'] = 1) and
            (LJob.Objects['results'].Arrays['seed_outcomes'].Objects[0].Strings['status'] = 'verified') and
            (LJob.Objects['results'].Strings['publication_status'] = 'published'),
            'Complete seed outcomes and actual publication status');
          Check((LJob.Objects['results'].Integers['retained_token_count'] > 0) and
            (LJob.Objects['results'].Integers['retained_candidate_count'] > 0) and
            (LJob.Objects['results'].Integers['retained_model_state_count'] > 0),
            'Actual retained model/palette counts reported');
          Check(not LJob.Objects['results'].Booleans['grounded_acceptance'], 'No musical acceptance');
          Check(LJob.Objects['results'].Arrays['sources'].Count = 2, 'Only the two checked passages reach training; parked whole recording excluded');
          Check(LJob.Objects['results'].Arrays['sources'].Objects[0].Strings['source_sha256'] = LHash,
            'Original source hash not analysis coordinate identity');
          Check(LJob.Objects['results'].Arrays['sources'].Objects[1].Int64s['start_frame'] = 32000,
            'Second range origin retained');
          Check(LJob.Objects['results'].Arrays['sources'].Objects[0].Strings['source_partition'] = 'unassigned',
            'Catalog partition unchanged');
          Check(LJob.Objects['results'].Arrays['sources'].Objects[0].Strings['effective_partition'] = 'development',
            'Explicit effective admission retained');
          LModelHash := LJob.Objects['results'].Strings['model_sha256'];
          LOutput := LJob.Objects['results'].Arrays['outputs'].Objects[0];
          LWaveHash := LOutput.Strings['wav_sha256'];
          LArtifact := ReadStudioJSON(StudioJobDirectory(LCatalog, 'first') +
            PathDelim + 'seed-0.receipt.json');
          try
            Check((LOutput.Find('grain_map') = nil) and
              (LArtifact.Arrays['grain_map'].Count = LOutput.Integers['grain_map_count']) and
              (StudioTextHash(LArtifact.Arrays['grain_map'].AsJSON) =
              LOutput.Strings['grain_map_sha256']), 'Compact output binds actual immutable grain ledger');
          finally
            LArtifact.Free;
          end;
          Check(LOutput.Int64s['frame_count'] = 160000, 'Exact production20second clock');
          Check(LOutput.Booleans['generated_from_reloaded_model'], 'Actual saved model used');
          LStream := TFileStream.Create(StudioJobDirectory(LCatalog, 'first') + PathDelim + 'seed-0.wav', fmOpenRead);
          try
            Check(Sha256Stream(LStream, LStream.Size) = LWaveHash, 'Saved WAV actual hash');
            LStream.Position := 0;
            LWave := TWaveFrameReader.Create(LStream);
            try
              Check((LWave.FrameCount = 160000) and (LWave.SampleRate = 8000) and
                (LWave.Channels = 1), 'Actual saved WAV geometry');
            finally
              LWave.Free;
            end;
          finally
            LStream.Free;
          end;
        finally
          LJob.Free;
        end;
        LJob := EnqueueStudioJob(LCatalog, LWrite);
        try
          Check(LJob.Booleans['already_queued'], 'Completed duplicate reconciles');
        finally
          LJob.Free;
        end;
        LWrite.Strings['job_id'] := 'replay';
        LWrite.Add('parent_job_id', 'first');
        LJob := EnqueueStudioJob(LCatalog, LWrite);
        LJob.Free;
        Check(RunStudioWorker(LCatalog, 'replay', ARoot + PathDelim + 'library'), 'Same model explicit new batch');
        CheckProgressEvents(LCatalog, 'replay', True);
        LJob := ReadStudioJob(LCatalog, 'replay');
        try
          Check(LJob.Objects['results'].Booleans['model_reused'], 'Verified dependencies permit model reuse');
          Check(LJob.Objects['results'].Strings['model_sha256'] = LModelHash, 'Immutable model identity');
          Check(LJob.Objects['results'].Arrays['outputs'].Objects[0].Strings['wav_sha256'] = LWaveHash,
            'Fixed-seed actual audio replay');
        finally
          LJob.Free;
        end;
        LWrite.Strings['job_id'] := 'successor';
        LWrite.Add('reconstruction', 'source_successor');
        LPreparation := PrepareStudioJob(LCatalog, LWrite);
        try
          Check((LPreparation.Strings['reconstruction'] = 'source_successor') and
            (LPreparation.Objects['limits'].Int64s['successor_index_bytes'] > 0),
            'Source continuity preflight declares its bounded index');
        finally
          LPreparation.Free;
        end;
        LJob := EnqueueStudioJob(LCatalog, LWrite);
        LJob.Free;
        Check(RunStudioWorker(LCatalog, 'successor', ARoot + PathDelim + 'library'),
          'Source continuity reuses the actual retained multi-range journals');
        LJob := ReadStudioJob(LCatalog, 'successor');
        try
          Check(LJob.Objects['results'].Booleans['model_reused'] and
            (LJob.Objects['results'].Strings['model_sha256'] = LModelHash),
            'Changing reconstruction reuses exact training model');
          Check((LJob.Objects['results'].Arrays['reconstruction_journals'].Count = 2) and
            not DirectoryExists(StudioJobDirectory(LCatalog, 'successor') + PathDelim + 'analysis'),
            'No hidden reanalysis for source continuity');
          Check(LJob.Objects['results'].Integers['successor_observations'] > 0,
            'Actual completed observation index recorded');
          LSuccessorHash := LJob.Objects['results'].Arrays['outputs'].Objects[0].Strings['wav_sha256'];
        finally
          LJob.Free;
        end;
        LBaselineLedger := ReadStudioJSON(StudioJobDirectory(LCatalog, 'first') + PathDelim + 'seed-0.receipt.json');
        LSuccessorLedger := ReadStudioJSON(StudioJobDirectory(LCatalog, 'successor') + PathDelim + 'seed-0.receipt.json');
        try
          Check(LBaselineLedger.Arrays['grain_map'].Count = LSuccessorLedger.Arrays['grain_map'].Count,
            'Same generated clock and grain count');
          for LIndex := 0 to LBaselineLedger.Arrays['grain_map'].Count - 1 do
          begin
            Check((LBaselineLedger.Arrays['grain_map'].Objects[LIndex].Integers['token'] =
              LSuccessorLedger.Arrays['grain_map'].Objects[LIndex].Integers['token']) and
              (LBaselineLedger.Arrays['grain_map'].Objects[LIndex].Integers['range_index'] =
              LSuccessorLedger.Arrays['grain_map'].Objects[LIndex].Integers['range_index']),
              'Source successor preserves each requested token and fallback range');
          end;
        finally
          LSuccessorLedger.Free;
          LBaselineLedger.Free;
        end;
        LWrite.Strings['job_id'] := 'successor-replay';
        LJob := EnqueueStudioJob(LCatalog, LWrite);
        LJob.Free;
        Check(RunStudioWorker(LCatalog, 'successor-replay', ARoot + PathDelim + 'library'),
          'Second source-continuity job completes from retained observations');
        Check(HashFile(StudioJobDirectory(LCatalog, 'successor-replay') + PathDelim + 'seed-0.wav') =
          LSuccessorHash, 'Source continuity output replays exactly');
        LJournalPath := StudioJobDirectory(LCatalog, 'first') + PathDelim + 'analysis' + PathDelim + '0.pyaf';
        LStream := TFileStream.Create(LJournalPath, fmOpenReadWrite);
        try
          LJournalBytes := LStream.Size;
          LStream.Position := LJournalBytes;
          LByte := 123;
          LStream.WriteBuffer(LByte, 1);
        finally LStream.Free; end;
        try
          LWrite.Strings['job_id'] := 'invalid-journal';
          LJob := EnqueueStudioJob(LCatalog, LWrite); LJob.Free;
          Check(not RunStudioWorker(LCatalog, 'invalid-journal', ARoot + PathDelim + 'library'),
            'Uncommitted journal tail rejects reused source continuity');
          Check(not DirectoryExists(StudioJobDirectory(LCatalog, 'invalid-journal') + PathDelim + 'analysis'),
            'Invalid retained journal never triggers hidden reanalysis');
        finally
          LStream := TFileStream.Create(LJournalPath, fmOpenReadWrite);
          try LStream.Size := LJournalBytes; finally LStream.Free; end;
        end;
        Check(RenameFile(LJournalPath, LJournalPath + '.qa-held'), 'Hold the retained journal for missing-input check');
        try
          LWrite.Strings['job_id'] := 'missing-journal';
          LJob := EnqueueStudioJob(LCatalog, LWrite); LJob.Free;
          Check(not RunStudioWorker(LCatalog, 'missing-journal', ARoot + PathDelim + 'library'),
            'Missing retained observations reject instead of silently using sparse selection');
        finally
          Check(RenameFile(LJournalPath + '.qa-held', LJournalPath), 'Restore retained journal');
        end;
        LWrite.Strings['reconstruction'] := 'unsupported';
        LFailed := False;
        try
          LPreparation := PrepareStudioJob(LCatalog, LWrite);
          LPreparation.Free;
        except
          on E: EAudio do LFailed := True;
        end;
        Check(LFailed, 'Unknown reconstruction fails before execution');
        LWrite.Delete('reconstruction');
        LProjectWrite.Integers['expected_revision'] := 1;
        LProjectWrite.Strings['name'] := 'edited draft';
        LJob := SaveStudioProject(LCatalog, LProjectWrite);
        LJob.Free;
        LWrite.Strings['job_id'] := 'first';
        LWrite.Delete('parent_job_id');
        LJob := EnqueueStudioJob(LCatalog, LWrite);
        try
          Check(LJob.Booleans['already_queued'], 'Lost response reconciles after project edit');
        finally
          LJob.Free;
        end;
        LWrite.Strings['job_id'] := 'old-revision';
        LPreparation := PrepareStudioJob(LCatalog, LWrite);
        LPreparation.Free;
        LWrite.Integers['duration_ms'] := 1000;
        LFailed := False;
        try
          LJob := EnqueueStudioJob(LCatalog, LWrite);
          LJob.Free;
        except
          on E: EAudio do
          begin
            LFailed := True;
          end;
        end;
        Check(LFailed, 'No test-only short duration production bypass');
        LWrite.Integers['duration_ms'] := 20000;
        LWrite.Strings['job_id'] := 'corrupt-source';
        LJob := EnqueueStudioJob(LCatalog, LWrite);
        LJob.Free;
        LStream := TFileStream.Create(LCatalog + PathDelim + 'sources' + PathDelim + LHash + '.wav', fmOpenReadWrite);
        try
          LStream.Position := 44;
          LStream.ReadBuffer(LByte, 1);
          LByte := LByte xor 1;
          LStream.Position := 44;
          LStream.WriteBuffer(LByte, 1);
        finally
          LStream.Free;
        end;
        Check(not RunStudioWorker(LCatalog, 'corrupt-source', ARoot + PathDelim + 'library'),
          'Corrupt actual source fails worker');
        LJob := ReadStudioJob(LCatalog, 'corrupt-source');
        try
          Check(LJob.Strings['status'] = 'failed', 'Corrupt input retained terminal failure');
          Check((LJob.Objects['results'].Integers['completed_render_count'] = 0) and
            (LJob.Objects['results'].Integers['expected_render_count'] = 1) and
            (LJob.Objects['results'].Arrays['seed_outcomes'].Objects[0].Strings['status'] = 'not_attempted') and
            (LJob.Objects['results'].Arrays['outputs'].Count = 0) and
            (LJob.Objects['results'].Find('verified_model') = nil),
            'Rejected source reports each unattempted seed without verified model');
        finally
          LJob.Free;
        end;
        Check(HashFile(StudioJobDirectory(LCatalog, 'first') + PathDelim + 'seed-0.wav') = LWaveHash,
          'Prior accepted output preserved on failure');
      finally
        LWrite.Free;
      end;
    finally
      LProject.Free;
    end;
  finally
    LProjectWrite.Free;
  end;
  LProjectWrite := ProjectWrite('two', LHash2);
  try
    LProject := SaveStudioProject(LCatalog, LProjectWrite);
    try
      LWrite := JobWrite('changed-corpus', LHash2, LProject);
      try
        LJob := EnqueueStudioJob(LCatalog, LWrite);
        LJob.Free;
        Check(RunStudioWorker(LCatalog, 'changed-corpus', ARoot + PathDelim + 'library'),
          'Second project changed source actual pipeline');
        LJob := ReadStudioJob(LCatalog, 'changed-corpus');
        try
          Check(not LJob.Objects['results'].Booleans['model_reused'], 'Changed corpus produces new profile');
          Check(LJob.Objects['results'].Arrays['sources'].Objects[0].Strings['source_sha256'] = LHash2,
            'Second source ancestry');
        finally
          LJob.Free;
        end;
      finally
        LWrite.Free;
      end;
    finally
      LProject.Free;
    end;
  finally
    LProjectWrite.Free;
  end;
  LQueue := ReadListeningQueue(LCatalog);
  try
    Check(LQueue.Integers['waiting_count'] = 5, 'Exactly one listening request per successful seed/batch');
  finally
    LQueue.Free;
  end;
  CheckAtomicListening(LCatalog);
  CheckExperiments(LCatalog);
  LWrite := TJSONObject.Create;
  try
    LWrite.Add('format', StudioJobWriteFormat);
    LWrite.Add('job_id', 'inspect');
    LWrite.Add('kind', 'inspect_source');
    LWrite.Add('source_sha256', LHash2);
    LWrite.Add('start_frame', 4000);
    LWrite.Add('end_frame', 20000);
    LJob := EnqueueStudioJob(LCatalog, LWrite);
    LJob.Free;
    Check(RunStudioWorker(LCatalog, 'inspect', ARoot + PathDelim + 'library'),
      'Actual bounded existing feature/beat inspection');
    LJob := ReadStudioJob(LCatalog, 'inspect');
    try
      Check((LJob.Objects['results'].FloatS['rms'] > 0) and
        (LJob.Objects['results'].FloatS['peak'] >= LJob.Objects['results'].FloatS['rms']),
        'Actual measured energy/peak');
      Check(LJob.Objects['results'].Objects['beat_proposal'].Strings['source_sha256'] = LHash2,
        'Unreviewed beat packet preserves original source identity');
    finally
      LJob.Free;
    end;
  finally
    LWrite.Free;
  end;
end;

procedure LiveRun(const ARoot: String);
var
  LHash, LCatalog, LDirectory, LText: String;
  LWrite, LProject, LReply, LCommand, LState: TJSONObject;
  LWorker, LColdWorker: TLiveWorker;
  LMemory, LExcerptMemory: TStringStream;
  LWave, LExcerptWave: TWaveFrameReader;
  LSamples, LExpected, LActual: TAudioSamples;
  LDeadline: QWord;
  LSequence, LRun, LFrames, LIndex: Integer;
  LFailed: Boolean;
  LReplay: String;
  LCombined: TMemoryStream;

  procedure WaitReady(const ASequence: Integer);
  begin
    LDeadline := GetTickCount64;
    repeat
      FreeAndNil(LState);
      LState := ReadStudioLiveState(LCatalog, LWorker.JobId);
      Check(LState.Strings['job_status'] <> 'failed', 'Live worker must not fail');
      if (LState.Find('total_frames') <> nil) and
        (LState.Int64s['sequence'] = ASequence) then Exit;
      Sleep(10);
    until GetTickCount64 - LDeadline > 30000;
    raise Exception.Create('Live worker did not become ready');
  end;

begin
  Check(not DirectoryExists(ARoot), 'Live fixture root is fresh');
  LCatalog := ARoot + PathDelim + 'catalog';
  LHash := MakeSource(ARoot, 'live', 0);
  LWrite := ProjectWrite('live-project', LHash);
  try LProject := SaveStudioProject(LCatalog, LWrite) finally LWrite.Free end;
  LState := nil;
  LReplay := '';
  try
    for LRun := 0 to 3 do
    begin
      LWrite := JobWrite('live-' + IntToStr(LRun), LHash, LProject);
      LWorker := nil;
      LColdWorker := nil;
      LCommand := nil;
      LCombined := TMemoryStream.Create;
      try
        LWrite.Strings['kind'] := 'stream_generate';
        if LRun < 2 then LWrite.Integers['duration_ms'] := 120000
        else if LRun = 2 then LWrite.Integers['duration_ms'] := 7200000
        else LWrite.Integers['duration_ms'] := 86400000;
        LReply := PrepareStudioJob(LCatalog, LWrite);
        try
          Check(LReply.Objects['limits'].Integers['pull_frames'] = 65536,
            'Long plan declares fixed pull budget');
        finally LReply.Free end;
        LReply := EnqueueStudioJob(LCatalog, LWrite);
        LReply.Free;
        LWorker := TLiveWorker.Create(True);
        LWorker.FreeOnTerminate := False;
        LWorker.Catalog := LCatalog;
        LWorker.JobId := LWrite.Strings['job_id'];
        LDirectory := StudioJobDirectory(LCatalog, LWorker.JobId);
        if LRun = 0 then
        begin
          LReply := JobWrite('cold-alongside-live', LHash, LProject);
          try
            LCommand := EnqueueStudioJob(LCatalog, LReply);
            FreeAndNil(LCommand);
          finally LReply.Free end;
          LColdWorker := TLiveWorker.Create(True);
          LColdWorker.Catalog := LCatalog;
          LColdWorker.JobId := 'cold-alongside-live';
          LColdWorker.Start;
        end;
        LWorker.Start;
        WaitReady(-1);
        if LColdWorker <> nil then
        begin
          LColdWorker.WaitFor;
          Check(LColdWorker.Succeeded and (LColdWorker.Failure = ''),
            'Cold ordinary and live learning share immutable model publication');
          FreeAndNil(LColdWorker);
        end;
        Check(LState.Int64s['position'] = 0, 'Preparation does not generate without demand');
        if LRun = 0 then
        begin
          LReply := TJSONObject.Create;
          try
            LReply.Add('format', StudioJobWriteFormat);
            LReply.Add('job_id', 'alongside-live');
            LReply.Add('kind', 'inspect_source');
            LReply.Add('source_sha256', LHash);
            LReply.Add('start_frame', 0);
            LReply.Add('end_frame', 8000);
            LCommand := EnqueueStudioJob(LCatalog, LReply);
            FreeAndNil(LCommand);
          finally LReply.Free end;
          Check(RunStudioWorker(LCatalog, 'alongside-live', ARoot + PathDelim + 'library'),
            'Ordinary inspection remains available during live playback');
        end;
        Sleep(60);
        WaitReady(-1);
        LCommand := TJSONObject.Create;
        LCommand.Add('job_id', LWorker.JobId);
        LCommand.Add('action', 'excerpt');
        if LRun = 0 then
        begin
          LReply := RequestStudioLive(LCatalog, LCommand);
          LReply.Free;
        end;
        LCommand.Strings['action'] := 'pull';
        LCommand.Add('sequence', 1);
        LFailed := False;
        try
          LReply := RequestStudioLive(LCatalog, LCommand);
          LReply.Free;
        except on EAudio do LFailed := True end;
        Check(LFailed, 'Skipped first live chunk rejects before generation');
        for LSequence := 0 to 119 do
        begin
          LCommand.Int64s['sequence'] := LSequence;
          LReply := RequestStudioLive(LCatalog, LCommand);
          LReply.Free;
          WaitReady(LSequence);
          LText := ReadStudioLiveAudio(LCatalog, LWorker.JobId, LSequence);
          LReply := RequestStudioLive(LCatalog, LCommand);
          try
            Check(LReply.Int64s['position'] = LState.Int64s['position'],
              'Lost-response retry does not advance generation');
          finally LReply.Free end;
          LMemory := TStringStream.Create(LText);
          try
            LWave := TWaveFrameReader.Create(LMemory);
            try
              LFrames := LWave.FrameCount;
              Check((LFrames > 0) and (LFrames <= 8000) and (LWave.SampleRate = 8000),
                'Bounded playable WAV chunk retains source clock');
              LSamples := LWave.ReadFrames(LFrames);
              LCombined.WriteBuffer(LSamples[0], Length(LSamples) * SizeOf(Single));
              if (LRun = 0) and (LSequence < 20) then
              begin
                LIndex := Length(LExpected);
                SetLength(LExpected, LIndex + Length(LSamples));
                Move(LSamples[0], LExpected[LIndex], Length(LSamples) * SizeOf(Single));
              end;
            finally LWave.Free end;
          finally LMemory.Free end;
          if LRun >= 2 then Break;
        end;
        if LRun = 2 then
        begin
          LReply := CancelStudioJob(LCatalog, LWorker.JobId);
          LReply.Free;
        end
        else if LRun = 3 then
        begin
          LReply := TJSONObject.Create;
          try
            LReply.Add('tick_ms', Int64(0));
            ReplaceStudioJSON(LDirectory + PathDelim + StudioLiveLeaseFile, LReply);
          finally LReply.Free end;
        end;
        LWorker.WaitFor;
        Check(LWorker.Failure = '', 'Worker thread released its resources normally');
        LReply := ReadStudioJob(LCatalog, LWorker.JobId);
        try
          if LRun < 2 then
          begin
            Check(LWorker.Succeeded and (LReply.Strings['status'] = 'completed'),
              'Actual two-minute live generation completes');
            Check(LCombined.Size = 120 * 8000 * SizeOf(Single), 'Complete consumed PCM extent');
            LCombined.Position := 0;
            if LRun = 0 then LReplay := Sha256Stream(LCombined, LCombined.Size)
            else Check(LReplay = Sha256Stream(LCombined, LCombined.Size), 'Live session exact replay');
            Check(FileExists(LDirectory + PathDelim + 'live-chunk-0.wav') and
              FileExists(LDirectory + PathDelim + 'live-chunk-1.wav') and
              not FileExists(LDirectory + PathDelim + 'seed-0.wav'), 'No whole-session WAV retained');
          end
          else if LRun = 2 then
            Check(LReply.Strings['status'] = 'cancelled', 'Two-hour session cancels after bounded startup')
          else Check(LReply.Strings['status'] = 'failed', '24-hour session expires after client lease ends');
        finally LReply.Free end;
        if LRun = 0 then
        begin
          LReply := ReadStudioJSON(LDirectory + PathDelim + 'stream-excerpt.receipt.json');
          try
            Check((LReply.Int64s['session_start_frame'] = 0) and
              (LReply.Int64s['session_total_frames'] = 960000) and
              (LReply.Int64s['frame_count'] = 160000) and
              (LReply.Strings['listening_request_id'] <> ''), 'Excerpt retains live position and listening identity');
          finally LReply.Free end;
          LExcerptMemory := TStringStream.Create('');
          try
            LExcerptMemory.LoadFromFile(LDirectory + PathDelim + 'stream-excerpt.wav');
            LExcerptWave := TWaveFrameReader.Create(LExcerptMemory);
            try
              SetLength(LActual, 160000);
              LIndex := 0;
              while LIndex < Length(LActual) do
              begin
                LSamples := LExcerptWave.ReadFrames(Min(65536, Length(LActual) - LIndex));
                Check(Length(LSamples) > 0, 'Saved excerpt reader advances');
                Move(LSamples[0], LActual[LIndex], Length(LSamples) * SizeOf(Single));
                Inc(LIndex, Length(LSamples));
              end;
              Check((Length(LActual) = Length(LExpected)) and
                (CompareByte(LActual[0], LExpected[0], Length(LActual) * SizeOf(Single)) = 0),
                'Saved review is exact live PCM, not a restarted generation');
            finally LExcerptWave.Free end;
          finally LExcerptMemory.Free end;
        end;
      finally
        if LColdWorker <> nil then
        begin
          if not LColdWorker.Finished then
          begin
            LReply := CancelStudioJob(LCatalog, LColdWorker.JobId);
            LReply.Free;
            LColdWorker.WaitFor;
          end;
          LColdWorker.Free;
        end;
        if LWorker <> nil then
        begin
          if not LWorker.Finished then
          begin
            LReply := CancelStudioJob(LCatalog, LWorker.JobId);
            LReply.Free;
            LWorker.WaitFor;
          end;
          LWorker.Free;
        end;
        LCombined.Free;
        LCommand.Free;
        LWrite.Free;
      end;
    end;
  finally
    LState.Free;
    LProject.Free;
  end;
end;

procedure LiveSuccessorRun(const ARoot: String);
var
  LCatalog, LHash, LDirectory, LReplay, LPath, LQueueId: String;
  LProject, LWrite, LJob, LState, LCommand, LReply, LReceipt, LReferences, LQueue: TJSONObject;
  LWorker: TLiveWorker;
  LCombined: TMemoryStream;
  LStream: TFileStream;
  LWave: TWaveFrameReader;
  LSamples, LExpected: TAudioSamples;
  LMemory: TStringStream;
  LDeadline: QWord;
  LIndex, LSequence, LOffset: Integer;
  LOriginalSize: Int64;
  LByte: Byte;
  LFound: Boolean;

  procedure WaitReady(const ASequence: Integer);
  begin
    LDeadline:=GetTickCount64;
    repeat
      FreeAndNil(LState);
      LState:=ReadStudioLiveState(LCatalog,LWorker.JobId);
      Check(LState.Strings['job_status']<>'failed','Successor live worker remains valid');
      if (LState.Find('total_frames')<>nil) and (LState.Int64s['sequence']=ASequence) then Exit;
      Sleep(10);
    until GetTickCount64-LDeadline>30000;
    raise Exception.Create('Successor live worker did not become ready');
  end;

  procedure RunLive(const AId: String; const ADuration, APulls: Integer;
    const AExcerpt, ACancel: Boolean);
  var LTurn, LQueueIndex: Integer; LPayload: String;
  begin
    LCombined.Clear; LWorker:=nil; LWrite:=JobWrite(AId,LHash,LProject);
    LCommand:=nil;
    try
      LWrite.Strings['kind']:='stream_generate';
      LWrite.Integers['duration_ms']:=ADuration;
      LWrite.Add('reconstruction','source_successor');
      LReply:=EnqueueStudioJob(LCatalog,LWrite); LReply.Free;
      LWorker:=TLiveWorker.Create(True); LWorker.FreeOnTerminate:=False;
      LWorker.Catalog:=LCatalog; LWorker.JobId:=AId; LWorker.Start;
      LDirectory:=StudioJobDirectory(LCatalog,AId); WaitReady(-1);
      Check((LState.Strings['reconstruction']='source_successor') and
        (LState.Strings['reconstruction_policy']='exact_source_successor_v1'),
        'Live status publishes explicit shared reconstruction policy');
      Check((LState.Int64s['position']=0) and
        (LState.Int64s['total_frames']=Int64(ADuration)*8),'Exact long clock, no work without pull');
      LCommand:=TJSONObject.Create; LCommand.Add('job_id',AId);
      LCommand.Add('action','pull'); LCommand.Add('sequence',0);
      for LTurn:=0 to APulls-1 do
      begin
        if AExcerpt and (LTurn=5) then
        begin
          LCommand.Strings['action']:='excerpt'; LReply:=RequestStudioLive(LCatalog,LCommand);
          LReply.Free; LCommand.Strings['action']:='pull';
        end;
        LCommand.Int64s['sequence']:=LTurn; LReply:=RequestStudioLive(LCatalog,LCommand); LReply.Free;
        WaitReady(LTurn); LPayload:=ReadStudioLiveAudio(LCatalog,AId,LTurn);
        LMemory:=TStringStream.Create(LPayload);
        try
          LWave:=TWaveFrameReader.Create(LMemory);
          try
            Check(LWave.FrameCount=8000,'Bounded one-second native successor pull');
            LSamples:=LWave.ReadFrames(8000);
            LCombined.WriteBuffer(LSamples[0],Length(LSamples)*SizeOf(Single));
          finally LWave.Free end;
        finally LMemory.Free end;
        if AExcerpt and (LTurn=24) then
        begin
          LReceipt:=ReadStudioJSON(LDirectory+PathDelim+'stream-excerpt.receipt.json');
          try
            Check((LReceipt.Int64s['session_start_frame']=40000) and
              (LReceipt.Strings['reconstruction']='source_successor') and
              (LReceipt.Strings['reconstruction_policy_sha256']=LState.Strings['reconstruction_policy_sha256']),
              'Later excerpt preserves policy and actual session offset');
            LQueueId:=LReceipt.Strings['listening_request_id'];
            LReferences:=ReadListeningSourceReferences(LCatalog,LQueueId,'audition');
            try
              Check((LReferences.Strings['status']='ready') and
                (LReferences.Arrays['sources'].Count=2) and
                (LReferences.Arrays['sources'].Objects[1].Int64s['start_frame']=32000),
                'Running live excerpt resolves its exact original selections');
            finally LReferences.Free end;
            LQueue:=ReadListeningQueue(LCatalog); LFound:=False;
            try
              for LQueueIndex:=0 to LQueue.Arrays['items'].Count-1 do
                if LQueue.Arrays['items'].Objects[LQueueIndex].Strings['id']=LQueueId then
                begin
                  LFound:=True;
                  Check(LQueue.Arrays['items'].Objects[LQueueIndex].Arrays['assets'].Count=1,
                    'Later live excerpt is never paired with a zero-offset finite baseline');
                  Check((LQueue.Arrays['items'].Objects[LQueueIndex].Strings['task_id']='NS-5_continuity_05') and
                    (LQueue.Arrays['items'].Objects[LQueueIndex].Objects['answer_spec'].Arrays['choices'].Objects[0].Strings['id']='continuity') and
                    (LQueue.Arrays['items'].Objects[LQueueIndex].Find('experiment')<>nil),
                    'Live successor asks one task-bound continuity question, not general style fit');
                end;
              Check(LFound,'Exact live excerpt appears in existing review queue');
            finally LQueue.Free end;
          finally LReceipt.Free end;
        end;
      end;
      if ACancel then begin LReply:=CancelStudioJob(LCatalog,AId); LReply.Free end;
      LWorker.WaitFor;
      Check(LWorker.Failure='','Worker thread releases resources normally');
      LJob:=ReadStudioJob(LCatalog,AId);
      try
        if ACancel then
          Check((LJob.Strings['status']='cancelled') and
            (LJob.Objects['results'].Find('verified_model')<>nil),
            'Stopped live session retains verified preparation')
        else
        begin
          Check(LWorker.Succeeded and (LJob.Strings['status']='completed'),
            'Complete declared source-successor session');
          Check(LJob.Objects['results'].Booleans['model_reused'] and
            (LJob.Objects['results'].Strings['reconstruction_journal_job_id']='cold-live'),
            'Completed journals from stopped cold live job are reused');
          Check(not DirectoryExists(LDirectory+PathDelim+'analysis'),
            'Warm long session performs no hidden reanalysis');
        end;
        Check(not FileExists(LDirectory+PathDelim+'seed-0.wav') and
          not FileExists(LDirectory+PathDelim+'seed-0.receipt.json'),
          'Long playback retains no whole-output WAV or grain ledger');
      finally LJob.Free end;
    finally
      if LWorker<>nil then
      begin
        if not LWorker.Finished then begin LReply:=CancelStudioJob(LCatalog,AId); LReply.Free; LWorker.WaitFor end;
        LWorker.Free;
      end;
      LCommand.Free; LWrite.Free;
    end;
  end;

  procedure RunFinite(const AId: String; const ADuration: Integer; const APolicy: String);
  begin
    LWrite:=JobWrite(AId,LHash,LProject);
    try
      LWrite.Integers['duration_ms']:=ADuration; LWrite.Add('reconstruction',APolicy);
      LReply:=EnqueueStudioJob(LCatalog,LWrite); LReply.Free;
      Check(RunStudioWorker(LCatalog,AId,ARoot+PathDelim+'library'),'Finite retained-model consumer');
    finally LWrite.Free end;
  end;

begin
  Check(not DirectoryExists(ARoot),'Live successor fixture root is fresh');
  LCatalog:=ARoot+PathDelim+'catalog'; LHash:=MakeSource(ARoot,'successor',0);
  LWrite:=ProjectWrite('successor-project',LHash);
  try LProject:=SaveStudioProject(LCatalog,LWrite) finally LWrite.Free end;
  LState:=nil; LCombined:=TMemoryStream.Create;
  try
    RunLive('cold-live',86400000,25,True,True);
    RunFinite('finite-before',20000,'sparse');
    RunLive('warm-live',120000,120,True,False);
    LCombined.Position:=0; LReplay:=Sha256Stream(LCombined,LCombined.Size);
    RunLive('replay-live',120000,120,False,False);
    LCombined.Position:=0;
    Check(Sha256Stream(LCombined,LCombined.Size)=LReplay,'Complete successor live session replays exactly');
    RunLive('finite-length-live',20000,20,False,False);
    RunFinite('finite-successor',20000,'source_successor');
    LStream:=TFileStream.Create(StudioJobDirectory(LCatalog,'finite-successor')+PathDelim+'seed-0.wav',fmOpenRead);
    try
      LWave:=TWaveFrameReader.Create(LStream);
      try
        Check(LWave.FrameCount=160000,'Finite and live consumers use the same planned clock');
        LCombined.Position:=0; LOffset:=0;
        repeat
          LSamples:=LWave.ReadFrames(4096);
          SetLength(LExpected,Length(LSamples));
          if Length(LSamples)>0 then
          begin
            LCombined.ReadBuffer(LExpected[0],Length(LExpected)*SizeOf(Single));
            Check(CompareByte(LSamples[0],LExpected[0],Length(LSamples)*SizeOf(Single))=0,
              'Every finite/live PCM sample agrees across native pull boundaries');
          end;
          Inc(LOffset,Length(LSamples));
        until Length(LSamples)=0;
        Check(LOffset=160000,'Compared the full matched-clock output');
      finally LWave.Free end;
    finally LStream.Free end;
    LPath:=StudioJobDirectory(LCatalog,'cold-live')+PathDelim+'analysis'+PathDelim+'0.pyaf';
    LStream:=TFileStream.Create(LPath,fmOpenReadWrite);
    try LOriginalSize:=LStream.Size; LStream.Position:=LOriginalSize; LByte:=123; LStream.WriteBuffer(LByte,1)
    finally LStream.Free end;
    try
      LWrite:=JobWrite('damaged-live',LHash,LProject);
      try
        LWrite.Strings['kind']:='stream_generate'; LWrite.Add('reconstruction','source_successor');
        LReply:=EnqueueStudioJob(LCatalog,LWrite); LReply.Free;
        Check(not RunStudioWorker(LCatalog,'damaged-live',ARoot+PathDelim+'library'),
          'Damaged retained live journal fails without sparse fallback');
        LDirectory:=StudioJobDirectory(LCatalog,'damaged-live');
        Check(not DirectoryExists(LDirectory+PathDelim+'analysis') and
          not FileExists(LDirectory+PathDelim+StudioLiveStateFile),
          'Damaged journal performs no hidden reanalysis or audio publication');
      finally LWrite.Free end;
    finally
      LStream:=TFileStream.Create(LPath,fmOpenReadWrite);
      try LStream.Size:=LOriginalSize finally LStream.Free end;
    end;
  finally LCombined.Free; LState.Free; LProject.Free end;
end;
procedure CheckLiveReplay(const ACatalog: String; const AWrite: TJSONObject;
  const AJobId, AReferenceJobId: String; const ARate, AChannels: Integer);
var
  LWrite: TJSONObject;
  LReply: TJSONObject;
  LCommand: TJSONObject;
  LState: TJSONObject;
  LWorker: TLiveWorker;
  LBody: TStringStream;
  LActual: TMemoryStream;
  LExpected: TMemoryStream;
  LFile: TFileStream;
  LWave: TWaveFrameReader;
  LSamples: TAudioSamples;
  LSequence: Integer;
  LDeadline: QWord;
begin
  LWrite := TJSONObject(AWrite.Clone);
  LCommand := TJSONObject.Create;
  LActual := TMemoryStream.Create;
  LExpected := TMemoryStream.Create;
  LWorker := nil;
  try
    LWrite.Strings['job_id'] := AJobId;
    LWrite.Strings['kind'] := 'stream_generate';
    LReply := EnqueueStudioJob(ACatalog, LWrite);
    LReply.Free;
    LWorker := TLiveWorker.Create(True);
    LWorker.FreeOnTerminate := False;
    LWorker.Catalog := ACatalog;
    LWorker.JobId := AJobId;
    LWorker.Start;
    LDeadline := GetTickCount64;
    repeat
      LState := ReadStudioLiveState(ACatalog, AJobId);
      try
        Check(LState.Strings['job_status'] <> 'failed', 'Prepared live model starts');
        if LState.Find('total_frames') <> nil then Break;
      finally
        LState.Free;
      end;
      Check(GetTickCount64 - LDeadline < 30000, 'Prepared live model meets fixture deadline');
      Sleep(10);
    until False;
    LCommand.Add('job_id', AJobId);
    LCommand.Add('action', 'pull');
    LCommand.Add('sequence', 0);
    for LSequence := 0 to 19 do
    begin
      LCommand.Integers['sequence'] := LSequence;
      LReply := RequestStudioLive(ACatalog, LCommand);
      LReply.Free;
      LDeadline := GetTickCount64;
      repeat
        LState := ReadStudioLiveState(ACatalog, AJobId);
        try
          Check(LState.Strings['job_status'] <> 'failed', 'Prepared live worker remains valid');
          if (LState.Find('sequence') <> nil) and
            (LState.Int64s['sequence'] = LSequence) then Break;
        finally
          LState.Free;
        end;
        Check(GetTickCount64 - LDeadline < 30000, 'Prepared live chunk meets fixture deadline');
        Sleep(10);
      until False;
      LBody := TStringStream.Create(ReadStudioLiveAudio(ACatalog, AJobId, LSequence));
      try
        LWave := TWaveFrameReader.Create(LBody);
        try
          Check((LWave.SampleRate = ARate) and (LWave.Channels = AChannels) and
            (LWave.FrameCount = ARate), 'Live output uses requested clock and layout');
          LSamples := LWave.ReadFrames(ARate);
          LActual.WriteBuffer(LSamples[0], Length(LSamples) * SizeOf(Single));
        finally
          LWave.Free;
        end;
      finally
        LBody.Free;
      end;
    end;
    LWorker.WaitFor;
    Check(LWorker.Succeeded and (LWorker.Failure = ''), 'Prepared live session completes after bounded pulls');
    LFile := TFileStream.Create(StudioJobDirectory(ACatalog, AReferenceJobId) + PathDelim + 'seed-0.wav', fmOpenRead);
    try
      LWave := TWaveFrameReader.Create(LFile);
      try
        repeat
          LSamples := LWave.ReadFrames(ARate);
          if Length(LSamples) = 0 then Break;
          LExpected.WriteBuffer(LSamples[0], Length(LSamples) * SizeOf(Single));
        until False;
      finally
        LWave.Free;
      end;
    finally
      LFile.Free;
    end;
    Check((LActual.Size = LExpected.Size) and
      (CompareByte(LActual.Memory^, LExpected.Memory^, LActual.Size) = 0),
      'Prepared live and finite consumers produce identical complete PCM');
  finally
    if LWorker <> nil then
    begin
      if not LWorker.Finished then
      begin
        LReply := CancelStudioJob(ACatalog, AJobId);
        LReply.Free;
        LWorker.WaitFor;
      end;
      LWorker.Free;
    end;
    LExpected.Free;
    LActual.Free;
    LCommand.Free;
    LWrite.Free;
  end;
end;

procedure MixedRun(const ARoot: String);
var
  LCatalog: String;
  LLibrary: String;
  LHashes: array[0..1] of String;
  LRates: array[0..1] of Integer;
  LWrite: TJSONObject;
  LProject: TJSONObject;
  LJob: TJSONObject;
  LCold: TJSONObject;
  LWarm: TJSONObject;
  LPlan: TJSONObject;
  LRow: TJSONObject;
  LRecipe: TJSONObject;
  LRefs: TJSONObject;
  LLedger: TJSONObject;
  LStream: TFileStream;
  LWave: TWaveFrameReader;
  LCache: String;
  LChangedPath: String;
  LIndex: Integer;
  LPart: Integer;
  LRate: Integer;
  LByte: Byte;
begin
  Check(not DirectoryExists(ARoot), 'Mixed fixture root must be fresh');
  LCatalog := ARoot + PathDelim + 'catalog';
  LLibrary := ARoot + PathDelim + 'library';
  LRates[0] := 44100;
  LRates[1] := 48000;
  LHashes[0] := MakeSource(ARoot, 'mixed-stereo', 0, LRates[0], 2);
  LHashes[1] := MakeSource(ARoot, 'mixed-mono', 1, LRates[1], 1);
  LWrite := ProjectWrite('mixed-formats', LHashes[0]);
  LProject := nil;
  LCold := nil;
  LWarm := nil;
  try
    LWrite.Arrays['sources'].Clear;
    for LIndex := 0 to 1 do
      for LPart := 0 to 1 do
      begin
        LRow := TJSONObject.Create;
        LWrite.Arrays['sources'].Add(LRow);
        LRow.Add('source_sha256', LHashes[LIndex]);
        LRow.Add('selection', 'range');
        LRow.Add('start_frame', LRates[LIndex] div 8 + LPart * (LRates[LIndex] div 2));
        LRow.Add('end_frame', LRates[LIndex] div 8 + LPart * (LRates[LIndex] div 2) + LRates[LIndex] div 4);
        LRow.Add('classifications', TJSONArray.Create(['authored mixed-clock control']));
      end;
    LProject := SaveStudioProject(LCatalog, LWrite);
    FreeAndNil(LWrite);
    LWrite := JobWrite('mixed-cold', LHashes[0], LProject);
    LRow := TJSONObject.Create;
    LWrite.Arrays['source_weights'].Add(LRow);
    LRow.Add('source_sha256', LHashes[1]);
    LRow.Add('weight', 2);
    LWrite.Add('preparation', TJSONObject.Create(['sample_rate', 48000, 'channels', 2, 'gain', 0.8]));
    LWrite.Add('reconstruction', 'source_successor');
    LPlan := PrepareStudioJob(LCatalog, LWrite);
    try
      Check((LPlan.Arrays['prepared_ranges'].Count = 4) and
        (LPlan.Int64s['prepared_frames'] = 48000) and
        (Abs(LPlan.Floats['selected_seconds'] - 1) < 1E-12), 'Mixed preflight uses original seconds and prepared clock');
      Check((LPlan.Arrays['used_sources'].Count = 0) and
        not DirectoryExists(LCatalog + PathDelim + 'studio' + PathDelim + 'models'),
        'Mixed preflight does not fabricate verified use or train');
    finally
      LPlan.Free;
    end;
    LJob := EnqueueStudioJob(LCatalog, LWrite);
    LJob.Free;
    Check(RunStudioWorker(LCatalog, 'mixed-cold', LLibrary), 'Actual mixed-rate/layout WFC worker completes');
    LJob := ReadStudioJob(LCatalog, 'mixed-cold');
    try
      LCold := TJSONObject(LJob.Objects['results'].Clone);
    finally
      LJob.Free;
    end;
    Check((LCold.Arrays['sources'].Count = 4) and not LCold.Booleans['model_reused'], 'Cold model uses all four original selections');
    for LIndex := 0 to 3 do
    begin
      LRow := LCold.Arrays['sources'].Objects[LIndex];
      LRecipe := LRow.Objects['prepared'];
      Check((LRow.Strings['source_sha256'] = LHashes[LIndex div 2]) and
        (LRow.Integers['sample_rate'] = LRates[LIndex div 2]) and
        (LRecipe.Int64s['frame_count'] = 12000) and
        (LRecipe.Integers['sample_rate'] = 48000) and (LRecipe.Integers['channels'] = 2),
        'Receipt retains separate original/prepared identities and geometry');
      Check((LRow.Int64s['start_frame'] = LProject.Arrays['sources'].Objects[LIndex].Int64s['start_frame']) and
        (LRow.Arrays['classifications'].AsJSON = LProject.Arrays['sources'].Objects[LIndex].Arrays['classifications'].AsJSON) and
        (LRow.Strings['source_partition'] = 'unassigned') and
        (LRow.Strings['effective_partition'] = 'development') and
        (LRow.Integers['weight'] = 1 + LIndex div 2), 'Original classification, scope, use and weight survive conversion');
    end;
    LRow := LCold.Arrays['outputs'].Objects[0];
    Check((LRow.Int64s['frame_count'] = 960000) and
      (LRow.Integers['channels'] = 2) and (LRow.Integers['sample_rate'] = 48000) and
      LRow.Booleans['generated_from_reloaded_model'], 'Actual reloaded WFC output has exact twenty-second target clock');
    LStream := TFileStream.Create(StudioJobDirectory(LCatalog, 'mixed-cold') + PathDelim + 'seed-0.wav', fmOpenRead);
    try
      LWave := TWaveFrameReader.Create(LStream);
      try
        Check((LWave.FrameCount = 960000) and (LWave.SampleRate = 48000) and (LWave.Channels = 2),
          'Independently parsed mixed output WAV geometry');
      finally
        LWave.Free;
      end;
    finally
      LStream.Free;
    end;
    LLedger := ReadStudioJSON(StudioJobDirectory(LCatalog, 'mixed-cold') + PathDelim + 'seed-0.receipt.json');
    try
      for LIndex := 0 to LLedger.Arrays['grain_map'].Count - 1 do
      begin
        LRow := LLedger.Arrays['grain_map'].Objects[LIndex];
        LRate := LRates[LRow.Integers['range_index'] div 2];
        Check((LRow.Find('original_source_frame') = nil) and
          (LRow.Int64s['original_source_frame_denominator'] = 48000) and
          (LRow.Int64s['original_source_frame_numerator'] =
            LCold.Arrays['sources'].Objects[LRow.Integers['range_index']].Int64s['start_frame'] * 48000 +
            LRow.Int64s['prepared_source_frame'] * LRate), 'Every grain retains exact rational original coordinate');
      end;
    finally
      LLedger.Free;
    end;
    LRefs := ReadListeningSourceReferences(LCatalog,
      LCold.Arrays['outputs'].Objects[0].Strings['listening_request_id'], 'audition');
    try
      Check((LRefs.Strings['status'] = 'ready') and (LRefs.Arrays['sources'].Count = 4) and
        (LRefs.Arrays['sources'].Objects[0].Integers['sample_rate'] = 44100) and
        (LRefs.Arrays['sources'].Objects[2].Integers['sample_rate'] = 48000),
        'Listening publication points back to exact original clocks');
    finally
      LRefs.Free;
    end;
    LWrite.Strings['job_id'] := 'mixed-warm';
    LJob := EnqueueStudioJob(LCatalog, LWrite);
    LJob.Free;
    Check(RunStudioWorker(LCatalog, 'mixed-warm', LLibrary), 'Verified mixed model reuse completes');
    LJob := ReadStudioJob(LCatalog, 'mixed-warm');
    try
      LWarm := TJSONObject(LJob.Objects['results'].Clone);
      Check(LWarm.Booleans['model_reused'] and
        (LWarm.Strings['training_identity_sha256'] = LCold.Strings['training_identity_sha256']) and
        (LWarm.Arrays['sources'].AsJSON = LCold.Arrays['sources'].AsJSON) and
        (LWarm.Arrays['outputs'].Objects[0].Strings['wav_sha256'] = LCold.Arrays['outputs'].Objects[0].Strings['wav_sha256']),
        'Prepared reuse preserves identity, complete receipts and every output byte');
    finally
      LJob.Free;
    end;
    CheckLiveReplay(LCatalog, LWrite, 'mixed-live', 'mixed-cold', 48000, 2);
    LCache := GetEnvironmentVariable('PYTHIAN_STUDIO_PREPARED_CACHE');
    Check(LCache <> '', 'Mixed fixture requires an isolated explicit cache root');
    LChangedPath := IncludeTrailingPathDelimiter(LCache) +
      LCold.Arrays['sources'].Objects[0].Objects['prepared'].Strings['recipe_sha256'] + PathDelim + 'audio.wav';
    LStream := TFileStream.Create(LChangedPath, fmOpenReadWrite);
    try
      LStream.Position := 60;
      LStream.ReadBuffer(LByte, 1);
      LByte := LByte xor 1;
      LStream.Position := 60;
      LStream.WriteBuffer(LByte, 1);
    finally
      LStream.Free;
    end;
    try
      LWrite.Strings['job_id'] := 'mixed-corrupt';
      LJob := EnqueueStudioJob(LCatalog, LWrite);
      LJob.Free;
      Check(not RunStudioWorker(LCatalog, 'mixed-corrupt', LLibrary), 'Corrupt prepared bytes fail before saved model reuse');
      LJob := ReadStudioJob(LCatalog, 'mixed-corrupt');
      try
        Check((LJob.Strings['status'] = 'failed') and
          not FileExists(StudioJobDirectory(LCatalog, 'mixed-corrupt') + PathDelim + 'seed-0.wav'),
          'Corrupt cache never silently falls back or publishes generated audio');
        Check(Pos('Prepared WAV hash differs', LJob.Strings['error_message']) > 0,
          'Preparation failures expose a useful path-free explanation');
      finally
        LJob.Free;
      end;
    finally
      LStream := TFileStream.Create(LChangedPath, fmOpenReadWrite);
      try
        LStream.Position := 60;
        LByte := LByte xor 1;
        LStream.WriteBuffer(LByte, 1);
      finally
        LStream.Free;
      end;
    end;
    LWrite.Strings['job_id'] := 'mixed-changed';
    LWrite.Objects['preparation'].Floats['gain'] := 0.5;
    LJob := EnqueueStudioJob(LCatalog, LWrite);
    LJob.Free;
    Check(RunStudioWorker(LCatalog, 'mixed-changed', LLibrary), 'Changed preparation recipe learns a distinct model identity');
    LJob := ReadStudioJob(LCatalog, 'mixed-changed');
    try
      Check(not LJob.Objects['results'].Booleans['model_reused'] and
        (LJob.Objects['results'].Strings['training_identity_sha256'] <> LCold.Strings['training_identity_sha256']),
        'Preparation configuration participates in saved learning identity');
    finally
      LJob.Free;
    end;
    for LIndex := 0 to 1 do
      Check(HashFile(LCatalog + PathDelim + 'sources' + PathDelim + LHashes[LIndex] + '.wav') = LHashes[LIndex],
        'Mixed preparation never replaces original source bytes');
  finally
    LWarm.Free;
    LCold.Free;
    LWrite.Free;
    LProject.Free;
  end;
end;

procedure PreferenceRun(const ARoot: String);
var
  LCatalog: String;
  LLibrary: String;
  LHashes: array[0..1] of String;
  LProjectWrite: TJSONObject;
  LProject: TJSONObject;
  LWrite: TJSONObject;
  LJob: TJSONObject;
  LRow: TJSONObject;
  LCold: TJSONObject;
  LMatched: TJSONObject;
  LBiased: TJSONObject;
  LReplay: TJSONObject;
  LTraining: TJSONObject;
  LColdLedger: TJSONObject;
  LBiasedLedger: TJSONObject;
  LProfile: TJSONObject;
  LPreferences: TJSONArray;
  LModelRoot: String;
  LProfileHash: String;
  LModelHash: String;
  LJournalHashes: array[0..2] of String;
  LIndex: Integer;
  LBeforeSecond: Integer;
  LAfterSecond: Integer;
  LRange: Integer;
  LFailed: Boolean;

  function ExecuteJob(const AId: String): TJSONObject;
  var
    LDetail: TJSONObject;
  begin
    LWrite.Strings['job_id'] := AId;
    LDetail := EnqueueStudioJob(LCatalog, LWrite);
    LDetail.Free;
    Check(RunStudioWorker(LCatalog, AId, LLibrary), 'Preference job completes: ' + AId);
    LDetail := ReadStudioJob(LCatalog, AId);
    try
      Result := TJSONObject(LDetail.Objects['results'].Clone);
    finally
      LDetail.Free;
    end;
  end;

  procedure SetPreferences(const AFirst, ASecond: Integer);
  begin
    if LWrite.Find('generation_weights') <> nil then
      LWrite.Delete('generation_weights');
    LPreferences := TJSONArray.Create;
    LPreferences.Add(TJSONObject.Create(['source_sha256', LHashes[0], 'weight', AFirst]));
    LPreferences.Add(TJSONObject.Create(['source_sha256', LHashes[1], 'weight', ASecond]));
    LWrite.Add('generation_weights', LPreferences);
  end;

begin
  Check(not DirectoryExists(ARoot), 'Preference fixture root must be fresh');
  Check(ForceDirectories(ARoot), 'Create preference fixture root');
  LCatalog := ARoot + PathDelim + 'catalog';
  LLibrary := ARoot + PathDelim + 'library';
  { Identical sign-independent acoustic features, distinct original PCM/identity.
    This checks eligible candidate choice, not musical discrimination or quality. }
  LHashes[0] := MakeSource(ARoot, 'preference-one', 0);
  LHashes[1] := MakeSource(ARoot, 'preference-two', 0, 8000, 1, True);
  Check(LHashes[0] <> LHashes[1], 'Preference originals have distinct identities');
  LProjectWrite := ProjectWrite('preferences', LHashes[0]);
  LProject := nil;
  LWrite := nil;
  LCold := nil;
  LMatched := nil;
  LBiased := nil;
  LReplay := nil;
  LTraining := nil;
  LColdLedger := nil;
  LBiasedLedger := nil;
  LProfile := nil;
  try
    LRow := TJSONObject.Create(['source_sha256', LHashes[1], 'selection', 'full']);
    LRow.Add('classifications', TJSONArray.Create(['second authored control']));
    LProjectWrite.Arrays['sources'].Add(LRow);
    LProject := SaveStudioProject(LCatalog, LProjectWrite);
    LWrite := JobWrite('preference-legacy', LHashes[0], LProject);
    LWrite.Arrays['source_weights'].Objects[0].Integers['weight'] := 2;
    LWrite.Arrays['source_weights'].Add(TJSONObject.Create([
      'source_sha256', LHashes[1], 'weight', 1]));
    LWrite.Add('reconstruction', 'source_successor');
    LCold := ExecuteJob('preference-legacy');
    Check(not LCold.Booleans['model_reused'], 'First preference model is actually learned');
    Check((LCold.Strings['generation_preference_policy'] = 'inherited_training_weights') and
      (LCold.Arrays['generation_weights'].AsJSON = LWrite.Arrays['source_weights'].AsJSON),
      'Historical omission binds inherited choices without changing request');
    LModelRoot := LCatalog + PathDelim + 'studio' + PathDelim + 'models' + PathDelim +
      LCold.Strings['training_identity_sha256'];
    LProfileHash := HashFile(LModelRoot + PathDelim + 'profile.json');
    LModelHash := HashFile(LModelRoot + PathDelim + 'model.wfcs');
    LProfile := ReadStudioJSON(LModelRoot + PathDelim + 'profile.json');
    Check(LProfile.Find('generation_weights') = nil,
      'Per-job generation preference does not enter immutable trained profile');
    for LIndex := 0 to 2 do
      Check(LProfile.Objects['journal_profile'].Arrays['sources'].Objects[LIndex].Find(
        'generation_weight') = nil, 'New learned profiles do not retain unused playback metadata');
    for LIndex := 0 to 2 do
      LJournalHashes[LIndex] := HashFile(StudioJobDirectory(LCatalog, 'preference-legacy') +
        PathDelim + 'analysis' + PathDelim + IntToStr(LIndex) + '.pyaf');
    LColdLedger := ReadStudioJSON(StudioJobDirectory(LCatalog, 'preference-legacy') +
      PathDelim + 'seed-0.receipt.json');

    SetPreferences(2, 1);
    LMatched := ExecuteJob('preference-matched');
    Check(LMatched.Booleans['model_reused'] and
      (LMatched.Strings['training_identity_sha256'] = LCold.Strings['training_identity_sha256']) and
      (LMatched.Arrays['outputs'].Objects[0].Strings['wav_sha256'] =
        LCold.Arrays['outputs'].Objects[0].Strings['wav_sha256']),
      'Explicit legacy-equivalent preferences reuse exact model and original audio');

    SetPreferences(1, 8);
    LBiased := ExecuteJob('preference-biased');
    Check(LBiased.Booleans['model_reused'] and
      (LBiased.Strings['training_identity_sha256'] = LCold.Strings['training_identity_sha256']) and
      (LBiased.Strings['model_sha256'] = LCold.Strings['model_sha256']) and
      (LBiased.Arrays['sources'].AsJSON = LCold.Arrays['sources'].AsJSON),
      'Generation preference preserves learned sources, weights, identity and WFC model');
    Check((LBiased.Strings['generation_preference_policy'] = 'explicit') and
      (LBiased.Arrays['generation_weights'].AsJSON = LWrite.Arrays['generation_weights'].AsJSON),
      'Per-job receipt binds explicit generation preferences');
    Check(not DirectoryExists(StudioJobDirectory(LCatalog, 'preference-biased') + PathDelim + 'analysis'),
      'Preference-only change does not regenerate feature journals');
    LBiasedLedger := ReadStudioJSON(StudioJobDirectory(LCatalog, 'preference-biased') +
      PathDelim + 'seed-0.receipt.json');
    Check(LBiasedLedger.Arrays['grain_map'].Count = LColdLedger.Arrays['grain_map'].Count,
      'Preference change preserves complete grain clock');
    LBeforeSecond := 0;
    LAfterSecond := 0;
    for LIndex := 0 to LColdLedger.Arrays['grain_map'].Count - 1 do
    begin
      Check(LColdLedger.Arrays['grain_map'].Objects[LIndex].Integers['token'] =
        LBiasedLedger.Arrays['grain_map'].Objects[LIndex].Integers['token'],
        'Preference preserves every WFC token at the same fixed-hop ordinal');
      LRange := LColdLedger.Arrays['grain_map'].Objects[LIndex].Integers['range_index'];
      if LCold.Arrays['sources'].Objects[LRange].Strings['source_sha256'] = LHashes[1] then
        Inc(LBeforeSecond);
      LRange := LBiasedLedger.Arrays['grain_map'].Objects[LIndex].Integers['range_index'];
      if LBiased.Arrays['sources'].Objects[LRange].Strings['source_sha256'] = LHashes[1] then
        Inc(LAfterSecond);
    end;
    Check((LAfterSecond > LBeforeSecond) and (LBeforeSecond > 0) and
      (LAfterSecond < LBiasedLedger.Arrays['grain_map'].Count),
      'Higher preference increases eligible recording choices without a hard lock');
    Check((LBiased.Arrays['outputs'].Objects[0].Strings['wav_sha256'] <>
      LCold.Arrays['outputs'].Objects[0].Strings['wav_sha256']) and
      (LBiased.Arrays['outputs'].Objects[0].Int64s['frame_count'] = 160000),
      'Candidate choice affects actual PCM while twenty-second clock stays exact');
    LReplay := ExecuteJob('preference-replay');
    Check(LReplay.Booleans['model_reused'] and
      (LReplay.Arrays['outputs'].Objects[0].Strings['wav_sha256'] =
        LBiased.Arrays['outputs'].Objects[0].Strings['wav_sha256']) and
      (LReplay.Arrays['outputs'].Objects[0].Strings['grain_map_sha256'] =
        LBiased.Arrays['outputs'].Objects[0].Strings['grain_map_sha256']),
      'Preference replay repeats complete PCM and source choices');
    CheckLiveReplay(LCatalog, LWrite, 'preference-live', 'preference-biased', 8000, 1);
    LJob := ReadStudioJob(LCatalog, 'preference-live');
    try
      Check(LJob.Objects['results'].Booleans['model_reused'] and
        (LJob.Objects['results'].Arrays['generation_weights'].AsJSON =
          LWrite.Arrays['generation_weights'].AsJSON),
        'Live session reuses model and retains the exact generation preference');
    finally
      LJob.Free;
    end;
    LJob := EnqueueStudioJob(LCatalog, LWrite);
    try
      Check(LJob.Strings['status'] = 'completed', 'Lost-response retry reconciles exact preference request');
    finally
      LJob.Free;
    end;
    SetPreferences(8, 1);
    LFailed := False;
    try
      LJob := EnqueueStudioJob(LCatalog, LWrite);
      LJob.Free;
    except
      on EAudio do LFailed := True;
    end;
    Check(LFailed, 'Existing immutable job cannot acquire different preferences');
    LWrite.Arrays['source_weights'].Objects[0].Integers['weight'] := 3;
    LTraining := ExecuteJob('preference-new-training');
    Check(not LTraining.Booleans['model_reused'] and
      (LTraining.Strings['training_identity_sha256'] <> LCold.Strings['training_identity_sha256']),
      'Actual training-weight change creates a separate learned identity');
    Check((HashFile(LModelRoot + PathDelim + 'profile.json') = LProfileHash) and
      (HashFile(LModelRoot + PathDelim + 'model.wfcs') = LModelHash),
      'All preference changes leave the original saved model bytes intact');
    for LIndex := 0 to 2 do
      Check(HashFile(StudioJobDirectory(LCatalog, 'preference-legacy') + PathDelim +
        'analysis' + PathDelim + IntToStr(LIndex) + '.pyaf') = LJournalHashes[LIndex],
        'Original verified feature journals remain byte-identical');
    Check((HashFile(ARoot + PathDelim + 'inbox-preference-one' + PathDelim + 'source.wav') = LHashes[0]) and
      (HashFile(ARoot + PathDelim + 'inbox-preference-two' + PathDelim + 'source.wav') = LHashes[1]),
      'Preference learning never replaces original recordings');
    WriteLn('Preference source choices: ', LBeforeSecond, ' -> ', LAfterSecond,
      ' of ', LBiasedLedger.Arrays['grain_map'].Count);
  finally
    LProfile.Free;
    LBiasedLedger.Free;
    LColdLedger.Free;
    LTraining.Free;
    LReplay.Free;
    LBiased.Free;
    LMatched.Free;
    LCold.Free;
    LWrite.Free;
    LProject.Free;
    LProjectWrite.Free;
  end;
end;

procedure LibraryRun(const ARoot: String);
var
  LCatalog: String;
  LLibrary: String;
  LSamples: TAudioSamples;
  LClip: TAudioClip;
  LStream: TFileStream;
  LWrite: TJSONObject;
  LJob: TJSONObject;
  LDiscovery: TJSONObject;
  LRow: TJSONObject;
  LSelection: TJSONObject;
  LPreparation: TJSONObject;
  LEvent: TJSONObject;
  LHash: String;
  LOrdinal: Integer;
  LFailed: Boolean;
  LImportHash: Boolean;
  LImportCopy: Boolean;
  LImportVerify: Boolean;
begin
  Check(not DirectoryExists(ARoot), 'Library worker fixture root must be fresh');
  LCatalog := ARoot + PathDelim + 'catalog';
  LLibrary := ARoot + PathDelim + 'library';
  Check(ForceDirectories(LCatalog), 'Create library worker catalog');
  Check(ForceDirectories(LLibrary + PathDelim + 'collections' + PathDelim + 'authored'),
    'Create private first-party library fixture');
  SetLength(LSamples, 800);
  for LOrdinal := 0 to High(LSamples) do
    LSamples[LOrdinal] := 0.125;
  LClip := TAudioClip.Create(8000, 1, LSamples);
  try
    LStream := TFileStream.Create(LLibrary + '/collections/authored/one.wav', fmCreate);
    try
      WriteWavePcm16(LStream, LClip);
    finally
      LStream.Free;
    end;
  finally
    LClip.Free;
  end;
  LHash := HashFile(LLibrary + '/collections/authored/one.wav');
  LWrite := TJSONObject.Create;
  LDiscovery := nil;
  try
    LWrite.Add('format', StudioJobWriteFormat);
    LWrite.Add('job_id', 'discover-library');
    LWrite.Add('kind', 'library_discover');
    LJob := EnqueueStudioJob(LCatalog, LWrite);
    LJob.Free;
    Check(RunStudioWorker(LCatalog, 'discover-library', LLibrary),
      'Actual metadata-only discovery worker executes');
    LJob := ReadStudioJob(LCatalog, 'discover-library');
    try
      Check((LJob.Strings['status'] = 'completed') and
        (LJob.Integers['maximum_worker_seconds'] = 600), 'Discovery actual terminal and budget');
      Check(LJob.Objects['results'].Int64s['content_read_bytes'] = 0,
        'Actual worker reports no PCM discovery reads');
    finally
      LJob.Free;
    end;
    Check(not DirectoryExists(LCatalog + '/sources'), 'Discovery worker imports nothing');
    LDiscovery := ListStudioLibraryDiscovery(LCatalog);
    LRow := LDiscovery.Arrays['entries'].Objects[0];
    LWrite.Strings['job_id'] := 'prepare-one';
    LWrite.Strings['kind'] := 'library_prepare';
    LWrite.Add('discovery_revision', LDiscovery.Integers['revision']);
    LWrite.Add('entries', TJSONArray.Create);
    LSelection := TJSONObject.Create;
    LSelection.Add('entry_id', LRow.Strings['entry_id']);
    LSelection.Add('entry_snapshot_sha256', LRow.Strings['entry_snapshot_sha256']);
    LWrite.Arrays['entries'].Add(LSelection);
    LPreparation := PrepareStudioJob(LCatalog, LWrite);
    try
      Check((LPreparation.Integers['selected_entry_count'] = 1) and
        (LPreparation.Objects['limits'].Integers['worker_seconds'] = 7200),
        'Selected preparation preflight binds actual count/long budget');
      Check(LPreparation.Arrays['used_sources'].Count = 0,
        'Preflight does not fabricate verified usage');
    finally
      LPreparation.Free;
    end;
    LJob := EnqueueStudioJob(LCatalog, LWrite);
    LJob.Free;
    Check(RunStudioWorker(LCatalog, 'prepare-one', LLibrary), 'Actual selected verification worker');
    LJob := ReadStudioJob(LCatalog, 'prepare-one');
    try
      Check((LJob.Strings['status'] = 'completed') and
        (LJob.Integers['maximum_worker_seconds'] = 7200), 'Preparation budget retained in actual detail');
      Check((LJob.Objects['results'].Arrays['mappings'].Count = 1) and
        (LJob.Objects['results'].Arrays['mappings'].Objects[0].Strings['source_sha256'] = LHash),
        'Worker returns only actual selected content identity');
      Check(LJob.Objects['results'].Strings['content_validation'] = 'selected_content_verified',
        'Completed preparation carries distinct verified status');
      LImportHash := False;
      LImportCopy := False;
      LImportVerify := False;
      for LOrdinal := 1 to LJob.Integers['event_revision'] do
      begin
        LEvent := ReadStudioJSON(StudioJobDirectory(LCatalog, 'prepare-one') + PathDelim +
          Format('%.8d.event.json', [LOrdinal]));
        try
          if (LEvent.Strings['stage'] = 'import_hash_bytes') or
            (LEvent.Strings['stage'] = 'import_copy_bytes') or
            (LEvent.Strings['stage'] = 'import_verify_bytes') then
          begin
            Check((LEvent.Strings['progress_unit'] = 'bytes') and
              (LEvent.Int64s['total'] = 1644) and (LEvent.Int64s['done'] >= 0) and
              (LEvent.Int64s['done'] <= 1644), 'Actual worker persists measured import bytes');
            if LEvent.Int64s['done'] = 1644 then
            begin
              LImportHash := LImportHash or (LEvent.Strings['stage'] = 'import_hash_bytes');
              LImportCopy := LImportCopy or (LEvent.Strings['stage'] = 'import_copy_bytes');
              LImportVerify := LImportVerify or (LEvent.Strings['stage'] = 'import_verify_bytes');
            end;
          end;
        finally
          LEvent.Free;
        end;
      end;
      Check(LImportHash and LImportCopy and LImportVerify,
        'Actual selected preparation exposes completed importer byte phases');
    finally
      LJob.Free;
    end;
    LJob := EnqueueStudioJob(LCatalog, LWrite);
    try
      Check(LJob.Strings['status'] = 'completed', 'Same-body lost-response retry reconciles completed preparation');
    finally
      LJob.Free;
    end;
    LWrite.Strings['job_id'] := 'prepare-cancelled';
    LJob := EnqueueStudioJob(LCatalog, LWrite);
    LJob.Free;
    LJob := CancelStudioJob(LCatalog, 'prepare-cancelled');
    try
      Check(LJob.Strings['status'] = 'cancelled', 'Selected queued cancellation terminal');
    finally
      LJob.Free;
    end;
    LFailed := False;
    try
      RunStudioWorker(LCatalog, 'prepare-cancelled', LLibrary);
    except
      on EAudio do LFailed := True;
    end;
    Check(LFailed, 'Cancelled preparation cannot be claimed/executed');
    LWrite.Strings['job_id'] := 'prepare-retry';
    LWrite.Add('retry_of', 'prepare-cancelled');
    LJob := EnqueueStudioJob(LCatalog, LWrite);
    LJob.Free;
    Check(RunStudioWorker(LCatalog, 'prepare-retry', LLibrary), 'Explicit preparation retry executes');
    LJob := ReadStudioJob(LCatalog, 'prepare-retry');
    try
      Check((LJob.Objects['request'].Strings['retry_of'] = 'prepare-cancelled') and
        (LJob.Objects['results'].Arrays['mappings'].Objects[0].Strings['status'] = 'existing'),
        'Retry lineage and verified reuse are durable');
    finally
      LJob.Free;
    end;
  finally
    LDiscovery.Free;
    LWrite.Free;
  end;
end;

begin
  try
    if (ParamCount = 2) and (ParamStr(1) = '--preferences-only') then
    begin
      PreferenceRun(ExpandFileName(ParamStr(2)));
      WriteLn('PASS ', GChecks, ' source-preference worker checks');
    end
    else if (ParamCount = 2) and (ParamStr(1) = '--mixed-only') then
    begin
      MixedRun(ExpandFileName(ParamStr(2)));
      WriteLn('PASS ', GChecks, ' mixed-format Studio worker checks');
    end
    else if (ParamCount = 2) and (ParamStr(1) = '--successor-live-only') then
    begin
      LiveSuccessorRun(ExpandFileName(ParamStr(2)));
      WriteLn('PASS ', GChecks, ' long source-continuity Studio checks');
    end
    else if (ParamCount = 2) and (ParamStr(1) = '--live-only') then
    begin
      LiveRun(ExpandFileName(ParamStr(2)));
      WriteLn('PASS ', GChecks, ' live Studio worker checks');
    end
    else if (ParamCount = 2) and (ParamStr(1) = '--library-only') then
    begin
      LibraryRun(ExpandFileName(ParamStr(2)));
      WriteLn('PASS ', GChecks, ' Studio library worker checks');
    end
    else if ParamCount = 1 then
    begin
      Run(ExpandFileName(ParamStr(1)));
      LibraryRun(ExpandFileName(ParamStr(1)) + '-library');
      WriteLn('PASS ', GChecks, ' real Studio worker checks');
    end
    else
    begin
      raise Exception.Create('Usage: studio worker test FRESH_ROOT');
    end;
  except
    on E: Exception do
    begin
      WriteLn(StdErr, E.ClassName, ': ', E.Message);
      ExitCode := 1;
    end;
  end;
end.
