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
  pythian.tools.listen.catalog;

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

function MakeSource(const ARoot, AName: String; const APhase: Integer): String;
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
begin
  LInbox := ARoot + PathDelim + 'inbox-' + AName;
  Check(ForceDirectories(LInbox), 'Create first-party source inbox');
  SetLength(LSamples, 64000);
  for LIndex := 0 to High(LSamples) do
  begin
    LFrequency := 220 + (((LIndex div 4000) + APhase) mod 4) * 55;
    LSamples[LIndex] := 0.15 * Sin(2 * Pi * LFrequency * LIndex / 8000);
  end;
  LClip := TAudioClip.Create(8000, 1, LSamples);
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

procedure CheckAtomicListening(const ACatalog: String);
var
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
    Check(LResult.Integers['waiting_count'] = 5, 'Independent packets both retained');
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
  LFailed: Boolean;
  LByte: Byte;
begin
  Check(not DirectoryExists(ARoot), 'Worker fixture root must be fresh');
  Check(ForceDirectories(ARoot), 'Create first-party fixture root');
  LHash := MakeSource(ARoot, 'one', 0);
  LHash2 := MakeSource(ARoot, 'two', 1);
  LCatalog := ARoot + PathDelim + 'catalog';
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
          Check(LPreparation.Arrays['used_sources'].Count = 0, 'Preparation does not invent used material');
        finally
          LPreparation.Free;
        end;
        LJob := EnqueueStudioJob(LCatalog, LWrite);
        LJob.Free;
        Check(RunStudioWorker(LCatalog, 'first', ARoot + PathDelim + 'library'),
          'Actual source-to-WFC-to-20-second-audio pipeline; inspect first/failure.txt on failure');
        LJob := ReadStudioJob(LCatalog, 'first');
        try
          Check(LJob.Strings['status'] = 'completed', 'Actual job terminal state');
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
          Check(LJob.Objects['results'].Arrays['sources'].Count = 2, 'Original range ledger retained');
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
        LJob := ReadStudioJob(LCatalog, 'replay');
        try
          Check(LJob.Objects['results'].Booleans['model_reused'], 'Verified dependencies permit model reuse');
          Check(LJob.Objects['results'].Strings['model_sha256'] = LModelHash, 'Immutable model identity');
          Check(LJob.Objects['results'].Arrays['outputs'].Objects[0].Strings['wav_sha256'] = LWaveHash,
            'Fixed-seed actual audio replay');
        finally
          LJob.Free;
        end;
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
    Check(LQueue.Integers['waiting_count'] = 3, 'Exactly one listening request per successful seed/batch');
  finally
    LQueue.Free;
  end;
  CheckAtomicListening(LCatalog);
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

begin
  try
    if ParamCount <> 1 then
    begin
      raise Exception.Create('Usage: studio worker test FRESH_ROOT');
    end;
    Run(ExpandFileName(ParamStr(1)));
    WriteLn('PASS ', GChecks, ' real Studio worker checks');
  except
    on E: Exception do
    begin
      WriteLn(StdErr, E.ClassName, ': ', E.Message);
      ExitCode := 1;
    end;
  end;
end.
