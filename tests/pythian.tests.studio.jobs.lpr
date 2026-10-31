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
program StudioJobsConformance;

{$mode delphi}
{$H+}

uses
  Classes,
  Process,
  SysUtils,
  fpjson,
  pythian.audio,
  pythian.hash,
  pythian.wave.stream,
  pythian.tools.annotations.catalog,
  pythian.tools.studio.projects,
  pythian.tools.studio.jobs;

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

procedure PartialPreferenceCheck(const AInbox, ACatalog, AFirstHash: String);
var
  LSamples: TAudioSamples;
  LClip: TAudioClip;
  LStream: TFileStream;
  LHash: String;
  LManifest: TJSONObject;
  LRows: TJSONArray;
  LRow: TJSONObject;
  LProjectWrite: TJSONObject;
  LProject: TJSONObject;
  LWrite: TJSONObject;
  LReport: TJSONObject;
  LIndex: Integer;
  LFailed: Boolean;
begin
  SetLength(LSamples, 16000);
  for LIndex := 0 to High(LSamples) do
  begin
    if LIndex mod 120 < 60 then LSamples[LIndex] := 0.25;
  end;
  LClip := TAudioClip.Create(8000, 1, LSamples);
  try
    LStream := TFileStream.Create(AInbox + PathDelim + 'second.wav', fmCreate);
    try
      WriteWavePcm16(LStream, LClip);
    finally
      LStream.Free;
    end;
  finally
    LClip.Free;
  end;
  LStream := TFileStream.Create(AInbox + PathDelim + 'second.wav', fmOpenRead);
  try
    LHash := Sha256Stream(LStream, LStream.Size);
  finally
    LStream.Free;
  end;
  LManifest := TJSONObject.Create;
  try
    LManifest.Add('version', 1);
    LRows := TJSONArray.Create;
    LManifest.Add('tracks', LRows);
    LRow := TJSONObject.Create;
    LRows.Add(LRow);
    LRow.Add('file', 'second.wav');
    LRow.Add('sha256', LHash);
    LRow.Add('source_group', 'second-preflight');
    LRow.Add('clock_id', '');
    LRow.Add('partition', 'unassigned');
    LRow.Add('title', 'Second authored preflight control');
    LRow.Add('provenance', 'First-party synthetic control');
    LRow.Add('license', 'MIT');
    DeleteFile(AInbox + PathDelim + 'manifest.json');
    WriteStudioJSONNew(AInbox + PathDelim + 'manifest.json', LManifest);
  finally
    LManifest.Free;
  end;
  LReport := ImportLabelInbox(AInbox, ACatalog);
  try
    Check(LReport.Integers['imported'] = 1, 'Import second selected source');
  finally
    LReport.Free;
  end;
  LProjectWrite := TJSONObject.Create;
  try
    LProjectWrite.Add('format', StudioProjectWriteFormat);
    LProjectWrite.Add('project_id', 'two-sources');
    LProjectWrite.Add('expected_revision', 0);
    LProjectWrite.Add('name', 'Two recordings');
    LProjectWrite.Add('style_intent', '');
    LProjectWrite.Add('learning_mode', 'raw_acoustic');
    LRows := TJSONArray.Create;
    LProjectWrite.Add('sources', LRows);
    for LIndex := 0 to 1 do
    begin
      LRow := TJSONObject.Create;
      LRows.Add(LRow);
      if LIndex = 0 then LRow.Add('source_sha256', AFirstHash)
      else LRow.Add('source_sha256', LHash);
      LRow.Add('selection', 'full');
    end;
    LProject := SaveStudioProject(ACatalog, LProjectWrite);
  finally
    LProjectWrite.Free;
  end;
  try
    LWrite := TJSONObject.Create;
    try
      LWrite.Add('format', StudioJobWriteFormat);
      LWrite.Add('job_id', 'partial-preference');
      LWrite.Add('kind', 'train_generate');
      LWrite.Add('project_id', LProject.Strings['project_id']);
      LWrite.Add('project_revision', LProject.Int64s['revision']);
      LWrite.Add('project_snapshot_sha256', LProject.Strings['snapshot_sha256']);
      LWrite.Add('duration_ms', 20000);
      LWrite.Add('seeds', TJSONArray.Create([731]));
      LWrite.Add('maximum_tokens', 4);
      LWrite.Add('model_order', 2);
      LWrite.Add('resolve_unassigned', 'development');
      LRows := TJSONArray.Create;
      LWrite.Add('source_weights', LRows);
      for LIndex := 0 to 1 do
      begin
        LRow := TJSONObject.Create;
        LRows.Add(LRow);
        if LIndex = 0 then LRow.Add('source_sha256', AFirstHash)
        else LRow.Add('source_sha256', LHash);
        LRow.Add('weight', 1);
      end;
      LRows := TJSONArray.Create;
      LWrite.Add('generation_weights', LRows);
      LRow := TJSONObject.Create;
      LRows.Add(LRow);
      LRow.Add('source_sha256', AFirstHash);
      LRow.Add('weight', 1);
      LFailed := False;
      try
        LReport := PrepareStudioJob(ACatalog, LWrite);
        LReport.Free;
      except
        on LException: EAudio do LFailed := True;
      end;
      Check(LFailed, 'Partial vector for two selected recordings rejected');
      LRow := TJSONObject.Create;
      LRows.Add(LRow);
      LRow.Add('source_sha256', LHash);
      LRow.Add('weight', 2);
      LReport := PrepareStudioJob(ACatalog, LWrite);
      try
        Check(LReport.Arrays['generation_weights'].Count = 2,
          'Complete vector for two selected recordings accepted');
      finally
        LReport.Free;
      end;
    finally
      LWrite.Free;
    end;
  finally
    LProject.Free;
  end;
end;

procedure LiveSuccessorPreflight(const ARoot: String);
const
  CDurations: array[0..2] of Integer = (120000, 7200000, 86400000);
var
  LInbox: String;
  LCatalog: String;
  LSamples: TAudioSamples;
  LClip: TAudioClip;
  LStream: TFileStream;
  LHash: String;
  LManifest: TJSONObject;
  LRows: TJSONArray;
  LRow: TJSONObject;
  LProjectWrite: TJSONObject;
  LProject: TJSONObject;
  LWrite: TJSONObject;
  LReport: TJSONObject;
  LQueued: TJSONObject;
  LDuration: Integer;
  LIndex: Integer;
  LIndexBytes: Int64;
  LBefore: String;
  LSuccessorHash: String;
  LFailed: Boolean;
  LConfig: TJSONObject;
  LGeneration: TJSONArray;
begin
  LInbox := ARoot + PathDelim + 'preflight-inbox';
  LCatalog := ARoot + PathDelim + 'preflight-catalog';
  Check(ForceDirectories(LInbox), 'Create isolated authored inbox');
  SetLength(LSamples, 16000);
  for LIndex := 0 to High(LSamples) do
  begin
    if LIndex mod 100 < 50 then
    begin
      LSamples[LIndex] := 0.125;
    end;
  end;
  LClip := TAudioClip.Create(8000, 1, LSamples);
  try
    LStream := TFileStream.Create(LInbox + PathDelim + 'source.wav', fmCreate);
    try
      WriteWavePcm16(LStream, LClip);
    finally
      LStream.Free;
    end;
  finally
    LClip.Free;
  end;
  LStream := TFileStream.Create(LInbox + PathDelim + 'source.wav', fmOpenRead);
  try
    LHash := Sha256Stream(LStream, LStream.Size);
  finally
    LStream.Free;
  end;
  LManifest := TJSONObject.Create;
  try
    LManifest.Add('version', 1);
    LRows := TJSONArray.Create;
    LManifest.Add('tracks', LRows);
    LRow := TJSONObject.Create;
    LRows.Add(LRow);
    LRow.Add('file', 'source.wav');
    LRow.Add('sha256', LHash);
    LRow.Add('source_group', 'live-preflight');
    LRow.Add('clock_id', '');
    LRow.Add('partition', 'unassigned');
    LRow.Add('title', 'Authored preflight control');
    LRow.Add('provenance', 'First-party synthetic control');
    LRow.Add('license', 'MIT');
    WriteStudioJSONNew(LInbox + PathDelim + 'manifest.json', LManifest);
  finally
    LManifest.Free;
  end;
  LReport := ImportLabelInbox(LInbox, LCatalog);
  try
    Check((LReport.Integers['imported'] = 1) and (LReport.Integers['failed'] = 0),
      'Import authored preflight source');
  finally
    LReport.Free;
  end;
  LProjectWrite := TJSONObject.Create;
  try
    LProjectWrite.Add('format', StudioProjectWriteFormat);
    LProjectWrite.Add('project_id', 'live-preflight');
    LProjectWrite.Add('expected_revision', 0);
    LProjectWrite.Add('name', 'Live preflight control');
    LProjectWrite.Add('style_intent', '');
    LProjectWrite.Add('learning_mode', 'raw_acoustic');
    LRows := TJSONArray.Create;
    LProjectWrite.Add('sources', LRows);
    LRow := TJSONObject.Create;
    LRows.Add(LRow);
    LRow.Add('source_sha256', LHash);
    LRow.Add('selection', 'full');
    LProject := SaveStudioProject(LCatalog, LProjectWrite);
  finally
    LProjectWrite.Free;
  end;
  try
    LWrite := TJSONObject.Create;
    try
      LWrite.Add('format', StudioJobWriteFormat);
      LWrite.Add('job_id', 'live-plan');
      LWrite.Add('kind', 'stream_generate');
      LWrite.Add('project_id', LProject.Strings['project_id']);
      LWrite.Add('project_revision', LProject.Int64s['revision']);
      LWrite.Add('project_snapshot_sha256', LProject.Strings['snapshot_sha256']);
      LWrite.Add('duration_ms', CDurations[0]);
      LWrite.Add('seeds', TJSONArray.Create([731]));
      LWrite.Add('maximum_tokens', 4);
      LWrite.Add('model_order', 2);
      LWrite.Add('resolve_unassigned', 'development');
      LRows := TJSONArray.Create;
      LWrite.Add('source_weights', LRows);
      LRow := TJSONObject.Create;
      LRows.Add(LRow);
      LRow.Add('source_sha256', LHash);
      LRow.Add('weight', 1);
      LWrite.Add('reconstruction', 'source_successor');
      LIndexBytes := -1;
      for LDuration in CDurations do
      begin
        LWrite.Integers['duration_ms'] := LDuration;
        LReport := PrepareStudioJob(LCatalog, LWrite);
        try
          Check((LReport.Strings['reconstruction'] = 'source_successor') and
            (LReport.Integers['duration_ms'] = LDuration), 'Live policy and duration retained');
          Check((LReport.Objects['limits'].Int64s['successor_index_bytes'] > 0) and
            (LReport.Objects['limits'].Int64s['successor_index_budget_bytes'] =
              MaximumStudioJobMemoryBytes div 4) and
            (LReport.Objects['limits'].Int64s['successor_observations_upper_bound'] =
              LReport.Int64s['estimated_analyzed_features']), 'Index and observation bounds declared');
          Check(Pos('retained journals', LReport.Strings['reconstruction_note']) > 0,
            'Reuse requires retained journals');
          if LIndexBytes >= 0 then
          begin
            Check(LIndexBytes = LReport.Objects['limits'].Int64s['successor_index_bytes'],
              'Index estimate independent of output duration');
          end;
          LIndexBytes := LReport.Objects['limits'].Int64s['successor_index_bytes'];
        finally
          LReport.Free;
        end;
      end;
      LWrite.Integers['duration_ms'] := CDurations[0];
      LReport := PrepareStudioJob(LCatalog, LWrite);
      try
        LSuccessorHash := LReport.Strings['request_sha256'];
      finally
        LReport.Free;
      end;
      LWrite.Strings['reconstruction'] := 'sparse';
      LReport := PrepareStudioJob(LCatalog, LWrite);
      try
        Check(LReport.Strings['request_sha256'] <> LSuccessorHash,
          'Reconstruction participates in immutable request identity');
        Check(LReport.Objects['limits'].Find('successor_index_bytes') = nil,
          'Sparse preflight does not allocate a successor index');
      finally
        LReport.Free;
      end;
      LWrite.Strings['reconstruction'] := 'source_successor';
      LWrite.Int64s['duration_ms'] := 86400001;
      LFailed := False;
      try
        LReport := PrepareStudioJob(LCatalog, LWrite);
        LReport.Free;
      except
        on LException: EAudio do LFailed := True;
      end;
      Check(LFailed, 'Live policy cannot exceed the 24-hour limit');
      LWrite.Integers['duration_ms'] := CDurations[0];
      LQueued := EnqueueStudioJob(LCatalog, LWrite);
      try
        LBefore := LQueued.Strings['request_sha256'];
      finally
        LQueued.Free;
      end;
      LWrite.Strings['reconstruction'] := 'sparse';
      LFailed := False;
      try
        LQueued := EnqueueStudioJob(LCatalog, LWrite);
        LQueued.Free;
      except
        on LException: EAudio do LFailed := True;
      end;
      Check(LFailed, 'Accepted policy cannot be silently replaced');
      LReport := ReadStudioJob(LCatalog, 'live-plan');
      try
        Check(LReport.Strings['request_sha256'] = LBefore, 'Immutable request hash retained');
      finally
        LReport.Free;
      end;
      LWrite.Strings['reconstruction'] := 'unknown';
      LFailed := False;
      try
        LReport := PrepareStudioJob(LCatalog, LWrite);
        LReport.Free;
      except
        on LException: EAudio do LFailed := True;
      end;
      Check(LFailed, 'Unknown reconstruction rejected at preflight');
      LWrite.Delete('reconstruction');
      LWrite.Strings['job_id'] := 'prepared-plan';
      LConfig := TJSONObject.Create;
      LConfig.Add('channels', 2);
      LConfig.Add('gain', 1.0);
      LConfig.Add('sample_rate', 48000);
      LWrite.Add('preparation', LConfig);
      LReport := PrepareStudioJob(LCatalog, LWrite);
      try
        LBefore := LReport.Strings['request_sha256'];
        Check(LReport.Int64s['prepared_frames'] = 96000, 'Prepared frames use target clock');
        Check(Abs(LReport.Floats['selected_seconds'] - 2.0) < 0.000001,
          'Original seconds retain original clock');
        Check(LReport.Integers['sample_rate'] = 48000, 'Target sample rate is explicit');
        Check(LReport.Arrays['prepared_ranges'].Objects[0].Int64s['prepared_frames'] = 96000,
          'Per-range prepared geometry is explicit');
      finally
        LReport.Free;
      end;
      LWrite.Delete('preparation');
      LConfig := TJSONObject.Create;
      LConfig.Add('sample_rate', 48000);
      LConfig.Add('channels', 2);
      LConfig.Add('gain', 1.0);
      LWrite.Add('preparation', LConfig);
      LReport := PrepareStudioJob(LCatalog, LWrite);
      try
        Check(LReport.Strings['request_sha256'] = LBefore, 'Preparation key ordering is canonical');
      finally
        LReport.Free;
      end;
      LConfig.Floats['gain'] := 0.5;
      LReport := PrepareStudioJob(LCatalog, LWrite);
      try
        Check(LReport.Strings['request_sha256'] <> LBefore, 'Preparation gain changes request identity');
      finally
        LReport.Free;
      end;
      LConfig.Floats['gain'] := 0.0;
      LFailed := False;
      try
        LReport := PrepareStudioJob(LCatalog, LWrite);
        LReport.Free;
      except
        on LException: EAudio do LFailed := True;
      end;
      Check(LFailed, 'Zero preparation gain is rejected');
      LWrite.Delete('preparation');
      LReport := PrepareStudioJob(LCatalog, LWrite);
      try
        Check(LReport.Strings['reconstruction'] = 'sparse', 'Omitted policy remains sparse');
        Check((LReport.Strings['generation_preference_policy'] = 'inherited_training_weights') and
          (LReport.Arrays['generation_weights'].Objects[0].Integers['weight'] = 1),
          'Omitted generation preference inherits training weights');
      finally
        LReport.Free;
      end;
      LGeneration := TJSONArray.Create;
      LWrite.Add('generation_weights', LGeneration);
      LRow := TJSONObject.Create;
      LRow.Add('source_sha256', LHash);
      LRow.Add('weight', 3);
      LGeneration.Add(LRow);
      LWrite.Strings['job_id'] := 'preference-live';
      LReport := PrepareStudioJob(LCatalog, LWrite);
      try
        Check((LReport.Strings['generation_preference_policy'] = 'explicit') and
          (LReport.Arrays['training_weights'].Objects[0].Integers['weight'] = 1) and
          (LReport.Arrays['generation_weights'].Objects[0].Integers['weight'] = 3),
          'Preflight distinguishes training and generation preferences');
        Check(Pos('not learning', LReport.Strings['generation_preference_note']) > 0,
          'Preflight explains soft preference scope');
      finally
        LReport.Free;
      end;
      LQueued := EnqueueStudioJob(LCatalog, LWrite);
      LQueued.Free;
      LQueued := EnqueueStudioJob(LCatalog, LWrite);
      try
        Check(LQueued.Booleans['already_queued'], 'Identical live preference retry reconciles');
      finally
        LQueued.Free;
      end;
      LRow.Integers['weight'] := 4;
      LFailed := False;
      try
        LQueued := EnqueueStudioJob(LCatalog, LWrite);
        LQueued.Free;
      except
        on LException: EAudio do LFailed := True;
      end;
      Check(LFailed, 'Live preference cannot replace immutable request');
      LWrite.Strings['job_id'] := 'preference-finite';
      LWrite.Strings['kind'] := 'train_generate';
      LWrite.Integers['duration_ms'] := 20000;
      LReport := PrepareStudioJob(LCatalog, LWrite);
      try
        Check((LReport.Strings['generation_preference_policy'] = 'explicit') and
          (LReport.Arrays['generation_weights'].Objects[0].Integers['weight'] = 4),
          'Finite audition accepts explicit generation preference');
      finally
        LReport.Free;
      end;
      LQueued := EnqueueStudioJob(LCatalog, LWrite);
      LQueued.Free;
      LQueued := EnqueueStudioJob(LCatalog, LWrite);
      try
        Check(LQueued.Booleans['already_queued'], 'Identical finite preference retry reconciles');
      finally
        LQueued.Free;
      end;
      LRow.Integers['weight'] := 0;
      LFailed := False;
      try
        LReport := PrepareStudioJob(LCatalog, LWrite);
        LReport.Free;
      except
        on LException: EAudio do LFailed := True;
      end;
      Check(LFailed, 'Zero generation preference is rejected');
      LRow.Delete('weight');
      LRow.Add('weight', 1.5);
      LFailed := False;
      try
        LReport := PrepareStudioJob(LCatalog, LWrite);
        LReport.Free;
      except
        on LException: EAudio do LFailed := True;
      end;
      Check(LFailed, 'Noninteger generation preference is rejected');
      LRow.Delete('weight');
      LRow.Add('weight', 1);
      LRow.Strings['source_sha256'] := StringOfChar('f', 64);
      LFailed := False;
      try
        LReport := PrepareStudioJob(LCatalog, LWrite);
        LReport.Free;
      except
        on LException: EAudio do LFailed := True;
      end;
      Check(LFailed, 'Foreign recording preference is rejected');
      LRow.Strings['source_sha256'] := LHash;
      LGeneration.Add(LRow.Clone);
      LFailed := False;
      try
        LReport := PrepareStudioJob(LCatalog, LWrite);
        LReport.Free;
      except
        on LException: EAudio do LFailed := True;
      end;
      Check(LFailed, 'Duplicate recording preference is rejected');
      LGeneration.Clear;
      LFailed := False;
      try
        LReport := PrepareStudioJob(LCatalog, LWrite);
        LReport.Free;
      except
        on LException: EAudio do LFailed := True;
      end;
      Check(LFailed, 'Missing recording preference is rejected');
    finally
      LWrite.Free;
    end;
  finally
    LProject.Free;
  end;
  PartialPreferenceCheck(LInbox, LCatalog, LHash);
end;

function NewWrite(const AId: String): TJSONObject;
begin
  Result := TJSONObject.Create;
  Result.Add('format', StudioJobWriteFormat);
  Result.Add('job_id', AId);
  Result.Add('kind', 'library_refresh');
end;

procedure WriterSignal(const ARoot, AName: String);
var
  LSignal: TJSONObject;
begin
  LSignal := TJSONObject.Create;
  try
    LSignal.Add('process_id', GetProcessID);
    WriteStudioJSONNew(ARoot + PathDelim + AName + '.json', LSignal);
  finally
    LSignal.Free;
  end;
end;

procedure HoldWriter(const ARoot: String);
var
  LLock: String;
  LStarted: QWord;
begin
  LLock := ARoot + PathDelim + 'studio' + PathDelim + 'jobs' + PathDelim + '.write-lock';
  if not CreateDir(LLock) then
    raise Exception.Create('Test writer could not acquire its lock');
  try
    WriterSignal(ARoot, 'writer-ready');
    LStarted := GetTickCount64;
    while not FileExists(ARoot + PathDelim + 'writer-attempt.json') do
    begin
      if GetTickCount64 - LStarted > 30000 then
        raise Exception.Create('Test caller never attempted cancellation');
      Sleep(10);
    end;
    Sleep(3000);
    if not DirectoryExists(LLock) then
      raise Exception.Create('Cancellation removed another writer lock');
  finally
    RemoveDir(LLock);
  end;
  WriterSignal(ARoot, 'writer-released');
end;

procedure WriterContention(const ARoot: String);
var
  LWrite: TJSONObject;
  LResult: TJSONObject;
  LChild: TProcess;
  LStarted: QWord;
  LLock: String;
  LFailed: Boolean;
  LRead: LongInt;
  LBuffer: array[0..4095] of Char;
  LText: String;
begin
  LWrite := NewWrite('writer-contention');
  try
    LResult := EnqueueStudioJob(ARoot, LWrite);
    LResult.Free;
  finally
    LWrite.Free;
  end;
  LResult := ClaimStudioJob(ARoot, 'writer-contention');
  LResult.Free;
  LChild := TProcess.Create(nil);
  try
    LChild.Executable := ParamStr(0);
    LChild.Parameters.Add('--hold-writer');
    LChild.Parameters.Add(ARoot);
    LChild.Options := [poUsePipes, poStderrToOutPut, poNoConsole];
    LChild.Execute;
    LStarted := GetTickCount64;
    while not FileExists(ARoot + PathDelim + 'writer-ready.json') and
      LChild.Running and (GetTickCount64 - LStarted < 30000) do
      Sleep(10);
    WriteLn('Writer helper readiness wait: ', GetTickCount64 - LStarted, ' ms');
    Check(FileExists(ARoot + PathDelim + 'writer-ready.json') and LChild.Running,
      'Independent writer owns the lock before cancellation');
    WriterSignal(ARoot, 'writer-attempt');
    LResult := CancelStudioJob(ARoot, 'writer-contention');
    try
      Check(LResult.Booleans['cancel_requested'] and
        (LResult.Strings['status'] = 'running'),
        'Running cancellation waits for a live writer without fabricating completion');
    finally
      LResult.Free;
    end;
    if LChild.Running then
      LChild.WaitOnExit(30000);
    Check(not LChild.Running, 'Owned writer process finishes');
    Check((LChild.ExitStatus = 0) and FileExists(ARoot + PathDelim + 'writer-released.json'),
      'Only the owning writer releases its lock');
  finally
    if LChild.Running then
    begin
      LChild.Terminate(1);
      if LChild.Running then LChild.WaitOnExit(30000);
    end;
    while LChild.Output.NumBytesAvailable > 0 do
    begin
      LRead := LChild.Output.Read(LBuffer, SizeOf(LBuffer));
      if LRead <= 0 then Break;
      SetString(LText, PChar(@LBuffer[0]), LRead);
      Write(LText);
    end;
    LChild.Free;
    ReleaseStudioWorker(ARoot);
  end;
  AdvanceStudioJob(ARoot, 'writer-contention', 'cancelled', 'cancelled', 0, 0);
  LLock := ARoot + PathDelim + 'studio' + PathDelim + 'jobs' + PathDelim + '.write-lock';
  Check(not DirectoryExists(LLock), 'Completed writers leave no lock behind');
  LWrite := NewWrite('stale-writer');
  try
    LResult := EnqueueStudioJob(ARoot, LWrite);
    LResult.Free;
  finally
    LWrite.Free;
  end;
  Check(CreateDir(LLock), 'Create test-owned unavailable writer lock');
  try
    LStarted := GetTickCount64;
    LFailed := False;
    try
      LResult := CancelStudioJob(ARoot, 'stale-writer');
      LResult.Free;
    except
      on E: EAudio do LFailed := True;
    end;
    Check(LFailed and (GetTickCount64 - LStarted < 13000),
      'Unavailable writer fails within a finite request bound');
    Check(DirectoryExists(LLock) and not StudioJobCancelled(ARoot, 'stale-writer'),
      'A timed-out caller cannot steal the lock or publish cancellation');
    LResult := ReadStudioJob(ARoot, 'stale-writer');
    try
      Check((LResult.Strings['status'] = 'queued') and
        (LResult.Integers['event_revision'] = 1), 'Failed writer acquisition preserves accepted state');
    finally
      LResult.Free;
    end;
  finally
    RemoveDir(LLock);
  end;
  LResult := CancelStudioJob(ARoot, 'stale-writer');
  try
    Check(LResult.Strings['status'] = 'cancelled',
      'Explicit retry works after the owning test releases its lock');
  finally
    LResult.Free;
  end;
end;

procedure Run(const ARoot: String);
var
  LWrite: TJSONObject;
  LResult: TJSONObject;
  LRequest: TJSONObject;
  LOther: TJSONObject;
  LFailed: Boolean;
  LBefore: String;
begin
  Check(not DirectoryExists(ARoot), 'Conformance root must be fresh');
  Check(ForceDirectories(ARoot), 'Create first-party empty catalog');
  LiveSuccessorPreflight(ARoot);
  LWrite := NewWrite('refresh-1');
  try
    LResult := PrepareStudioJob(ARoot, LWrite);
    try
      Check(LResult.Strings['source_validation'] =
        'metadata_only_pending_worker_content_verification', 'Preparation never certifies source bytes');
      Check(not DirectoryExists(ARoot + PathDelim + 'studio'), 'Preparation does not publish queue storage');
      Check(LResult.Objects['limits'].Integers['worker_seconds'] = 7200,
        'Collection preparation declares its independent finite verification budget');
    finally
      LResult.Free;
    end;
    LResult := EnqueueStudioJob(ARoot, LWrite);
    try
      Check(LResult.Strings['status'] = 'queued', 'Queued state');
      Check(LResult.Integers['event_revision'] = 1, 'Initial revision');
      Check(not LResult.Booleans['already_queued'], 'First enqueue is fresh');
      Check(LResult.Integers['maximum_worker_seconds'] = 7200,
        'Queued collection detail agrees with preparation budget');
      LBefore := LResult.Strings['request_sha256'];
      LResult.Strings['stage'] := 'caller-mutated';
    finally
      LResult.Free;
    end;
    LResult := EnqueueStudioJob(ARoot, LWrite);
    try
      Check(LResult.Booleans['already_queued'], 'Lost response retry reconciles');
      Check(LResult.Integers['event_revision'] = 1, 'Retry creates no event');
      Check(LResult.Strings['stage'] = 'queued', 'Returned JSON is detached');
      Check(LResult.Strings['request_sha256'] = LBefore, 'Request identity survives retry');
      Check(LResult.Objects['request'].AsJSON = LWrite.AsJSON,
        'Detail supplies exact detached transport write for reload retry');
      Check((LResult.Objects['request'].Find('request_sha256') = nil) and
        (LResult.Objects['request'].Find('project_snapshot') = nil),
        'Detail never exposes internal snapshot as a transport control');
    finally
      LResult.Free;
    end;
    LWrite.Add('unexpected', True);
    LFailed := False;
    try
      LResult := EnqueueStudioJob(ARoot, LWrite);
      LResult.Free;
    except
      on E: EStudioConflict do
      begin
        LFailed := True;
      end;
    end;
    Check(LFailed, 'Different duplicate request conflicts');
    LWrite.Delete('unexpected');
    LOther := NewWrite('refresh-2');
    try
      LResult := EnqueueStudioJob(ARoot, LOther);
      LResult.Free;
    finally
      LOther.Free;
    end;
    LRequest := ClaimStudioJob(ARoot, 'refresh-1');
    try
      Check(LRequest.Strings['request_sha256'] = LBefore, 'Claim binds immutable request');
      Check(StudioJobRequestRuntimeSeconds(LRequest) = 7200,
        'Worker claim carries the same immutable collection budget');
      LRequest.Delete('worker_seconds');
      Check(StudioJobRequestRuntimeSeconds(LRequest) = 600,
        'Legacy jobs retain their historical budget');
      LRequest.Add('worker_seconds', 7201);
      LFailed := False;
      try
        StudioJobRequestRuntimeSeconds(LRequest);
      except
        on E: EAudio do LFailed := True;
      end;
      Check(LFailed, 'An oversized stored budget cannot bypass worker policy');
    finally
      LRequest.Free;
    end;
    LFailed := False;
    try
      LRequest := ClaimStudioJob(ARoot, 'refresh-2');
      LRequest.Free;
    except
      on E: EAudio do
      begin
        LFailed := True;
      end;
    end;
    Check(LFailed, 'One worker per catalog');
    LResult := CancelStudioJob(ARoot, 'refresh-1');
    try
      Check(LResult.Booleans['cancel_requested'], 'Running cancellation marker');
      Check(LResult.Strings['status'] = 'running', 'Cancellation does not fabricate worker completion');
    finally
      LResult.Free;
    end;
    LFailed := False;
    try
      AdvanceStudioJob(ARoot, 'refresh-1', 'completed', 'completed', 1, 1);
    except
      on E: EAudio do
      begin
        LFailed := True;
      end;
    end;
    Check(LFailed, 'Cancellation cannot be reported completed');
    AdvanceStudioJob(ARoot, 'refresh-1', 'cancelled', 'cancelled', 0, 0);
    ReleaseStudioWorker(ARoot);
    LRequest := ClaimStudioJob(ARoot, 'refresh-2');
    LRequest.Free;
    ReleaseStudioWorker(ARoot);
    LFailed := False;
    try
      RecoverStudioJobs(ARoot, False);
    except
      on E: EAudio do
      begin
        LFailed := True;
      end;
    end;
    Check(LFailed, 'Recovery requires stopped-worker evidence');
    RecoverStudioJobs(ARoot, True);
    LResult := ReadStudioJob(ARoot, 'refresh-2');
    try
      Check(LResult.Strings['status'] = 'failed', 'Interrupted work stays failed');
      Check(LResult.Strings['error_code'] = 'interrupted', 'Interrupted reason retained');
    finally
      LResult.Free;
    end;
    LOther := NewWrite('refresh-3');
    try
      LOther.Add('retry_of', 'refresh-2');
      LResult := EnqueueStudioJob(ARoot, LOther);
      LResult.Free;
      LRequest := ReadStudioJobRequest(ARoot, 'refresh-3');
      try
        Check(LRequest.Strings['retry_of'] = 'refresh-2', 'Retry creates explicit ancestry');
      finally
        LRequest.Free;
      end;
      LResult := CancelStudioJob(ARoot, 'refresh-3');
      try
        Check(LResult.Strings['status'] = 'cancelled', 'Queued cancellation terminal');
      finally
        LResult.Free;
      end;
    finally
      LOther.Free;
    end;
    LFailed := False;
    try
      LRequest := ClaimStudioJob(ARoot, 'refresh-3');
      LRequest.Free;
    except
      on E: EAudio do
      begin
        LFailed := True;
      end;
    end;
    Check(LFailed, 'Terminal job cannot be claimed');
    LFailed := False;
    try
      LResult := ParseStudioJobWrite('{"x":?}');
      LResult.Free;
    except
      on E: EAudio do
      begin
        LFailed := True;
      end;
    end;
    Check(LFailed, 'Malformed syntax raises sanitized validation error');
    LResult := ListStudioJobs(ARoot);
    try
      Check(LResult.Integers['count'] = 3, 'Retained job count');
      Check((LResult.Integers['maximum_library_refresh_seconds'] = 7200) and
        (LResult.Integers['maximum_generation_seconds'] = MaximumStudioSessionSeconds) and
        (LResult.Integers['maximum_training_seconds'] = MaximumStudioTrainingSeconds),
        'Job inventory exposes separate collection and generation budgets');
      Check(LResult.Arrays['jobs'].Objects[0].Find('results') = nil,
        'List uses compact summaries');
      Check(LResult.Arrays['jobs'].Objects[0].Find('request') = nil,
        'List does not repeat full requests');
    finally
      LResult.Free;
    end;
    LOther := NewWrite('bad-write');
    try
      LOther.Add('unexpected', True);
      LFailed := False;
      try
        LResult := EnqueueStudioJob(ARoot, LOther);
        LResult.Free;
      except
        on E: EAudio do
        begin
          LFailed := True;
        end;
      end;
      Check(LFailed, 'Unsupported keys reject before enqueue');
      Check(not DirectoryExists(StudioJobDirectory(ARoot, 'bad-write')), 'Rejected request publishes nothing');
    finally
      LOther.Free;
    end;
  finally
    LWrite.Free;
  end;
end;

procedure DiscoveryPolicy(const ARoot: String);
var
  LWrite: TJSONObject;
  LResult: TJSONObject;
  LRequest: TJSONObject;
  LFailed: Boolean;
  LBefore: String;
  LCase: Integer;
begin
  Check(not DirectoryExists(ARoot), 'Discovery jobs fixture must be fresh');
  Check(ForceDirectories(ARoot), 'Create discovery job catalog');
  LWrite := NewWrite('discover');
  try
    LWrite.Strings['kind'] := 'library_discover';
    LResult := PrepareStudioJob(ARoot, LWrite);
    try
      Check((LResult.Objects['limits'].Integers['worker_seconds'] = 600) and
        (LResult.Objects['limits'].Integers['header_read_bytes_per_file'] = 65536),
        'Discovery has metadata header and short worker budgets');
      Check(LResult.Strings['content_validation'] = 'metadata_discovery_only',
        'Preflight never advertises content admission');
    finally
      LResult.Free;
    end;
    LResult := EnqueueStudioJob(ARoot, LWrite);
    try
      Check(LResult.Integers['maximum_worker_seconds'] = 600, 'Immutable discovery budget');
    finally
      LResult.Free;
    end;
    LResult := EnqueueStudioJob(ARoot, LWrite);
    try
      Check(LResult.Strings['job_id'] = 'discover', 'Identical discovery retry reconciles');
    finally
      LResult.Free;
    end;
    LRequest := ClaimStudioJob(ARoot, 'discover');
    try
      Check(StudioJobRequestRuntimeSeconds(LRequest) = 600, 'Worker reads discovery request budget');
      Check(LRequest.Strings['request_sha256'] <> '', 'Discovery request has durable identity');
    finally
      LRequest.Free;
    end;
    AdvanceStudioJob(ARoot, 'discover', 'running', 'checking_patterns', 257, 0,
      nil, '', '', 'items', 3);
    LResult := ReadStudioJob(ARoot, 'discover');
    try
      Check((LResult.Int64s['done'] = 257) and (LResult.Int64s['total'] = 0) and
        (LResult.Strings['progress_unit'] = 'items') and
        (LResult.Integers['progress_pass'] = 3),
        'Unknown-total activity preserves exact counters, units and pass');
      LBefore := LResult.AsJSON;
    finally
      LResult.Free;
    end;
    for LCase := 0 to 4 do
    begin
      LFailed := False;
      try
        case LCase of
          0: AdvanceStudioJob(ARoot, 'discover', 'running', 'bad', -1, 0);
          1: AdvanceStudioJob(ARoot, 'discover', 'running', 'bad', 0, -1);
          2: AdvanceStudioJob(ARoot, 'discover', 'running', 'bad', 3, 2);
          3: AdvanceStudioJob(ARoot, 'discover', 'running', 'bad', 1, 0,
               nil, '', '', 'unsupported', 0);
          4: AdvanceStudioJob(ARoot, 'discover', 'running', 'bad', 1, 0,
               nil, '', '', 'items', -1);
        end;
      except
        on E: Exception do LFailed := True;
      end;
      Check(LFailed, 'Malformed progress must reject');
      LResult := ReadStudioJob(ARoot, 'discover');
      try
        Check(LResult.AsJSON = LBefore, 'Rejected progress changed the accepted event');
      finally
        LResult.Free;
      end;
    end;
    AdvanceStudioJob(ARoot, 'discover', 'running', 'reading_headers', 1, 2);
    LResult := CancelStudioJob(ARoot, 'discover');
    try
      Check(LResult.Booleans['cancel_requested'], 'Discovery running cancellation flag');
    finally
      LResult.Free;
    end;
    Check(StudioJobCancelled(ARoot, 'discover'), 'Worker observes discovery cancellation');
    AdvanceStudioJob(ARoot, 'discover', 'cancelled', 'cancelled', 1, 2);
    ReleaseStudioWorker(ARoot);
    LWrite.Strings['job_id'] := 'prepare-rejected';
    LWrite.Strings['kind'] := 'library_prepare';
    LWrite.Add('discovery_revision', 1);
    LWrite.Add('entries', TJSONArray.Create);
    LFailed := False;
    try
      LResult := EnqueueStudioJob(ARoot, LWrite);
      LResult.Free;
    except
      on EAudio do LFailed := True;
    end;
    Check(LFailed and not DirectoryExists(StudioJobDirectory(ARoot, 'prepare-rejected')),
      'Empty preparation selection rejects before publication');
    Check(StudioJobRuntimeSeconds('library_prepare') = 7200,
      'Selected full verification retains separate long budget');
    Check(StudioJobRuntimeSeconds('train_generate') = MaximumStudioTrainingSeconds,
      'Long-source training gets a finite two-hour budget');
  finally
    LWrite.Free;
  end;
end;

begin
  try
    if (ParamCount = 2) and (ParamStr(1) = '--hold-writer') then
    begin
      HoldWriter(ExpandFileName(ParamStr(2)));
    end
    else if ParamCount = 1 then
    begin
      Run(ExpandFileName(ParamStr(1)));
      WriterContention(ExpandFileName(ParamStr(1)));
      DiscoveryPolicy(ExpandFileName(ParamStr(1)) + '-discovery');
      WriteLn('PASS ', GChecks, ' Studio job lifecycle checks');
    end
    else if (ParamCount = 2) and (ParamStr(1) = '--writer-only') then
    begin
      Check(not DirectoryExists(ParamStr(2)), 'Writer-only root must be fresh');
      Check(ForceDirectories(ParamStr(2)), 'Create isolated writer catalog');
      WriterContention(ExpandFileName(ParamStr(2)));
      WriteLn('PASS ', GChecks, ' focused writer ownership checks');
    end
    else if (ParamCount = 2) and (ParamStr(1) = '--discovery-only') then
    begin
      DiscoveryPolicy(ExpandFileName(ParamStr(2)));
      WriteLn('PASS ', GChecks, ' Studio discovery job checks');
    end
    else
    begin
      raise Exception.Create('Usage: studio jobs test FRESH_ROOT');
    end;
  except
    on E: Exception do
    begin
      WriteLn(StdErr, E.ClassName, ': ', E.Message);
      ExitCode := 1;
    end;
  end;
end.
