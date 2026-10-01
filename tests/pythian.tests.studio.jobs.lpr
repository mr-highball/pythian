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
  Process,
  SysUtils,
  fpjson,
  pythian.audio,
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
      if GetTickCount64 - LStarted > 10000 then
        raise Exception.Create('Test caller never attempted cancellation');
      Sleep(10);
    end;
    Sleep(350);
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
      LChild.Running and (GetTickCount64 - LStarted < 5000) do
      Sleep(10);
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
      LChild.WaitOnExit(3000);
    Check(not LChild.Running, 'Owned writer process finishes');
    while LChild.Output.NumBytesAvailable > 0 do
    begin
      LRead := LChild.Output.Read(LBuffer, SizeOf(LBuffer));
      if LRead <= 0 then Break;
      SetString(LText, PChar(@LBuffer[0]), LRead);
      Write(LText);
    end;
    Check((LChild.ExitStatus = 0) and FileExists(ARoot + PathDelim + 'writer-released.json'),
      'Only the owning writer releases its lock');
  finally
    if LChild.Running then
    begin
      LChild.Terminate(1);
      if LChild.Running then LChild.WaitOnExit(2000);
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
    Check(LFailed and (GetTickCount64 - LStarted < 5000),
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
        (LResult.Integers['maximum_generation_seconds'] = 600),
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
    Check(StudioJobRuntimeSeconds('train_generate') = 600, 'Generation budget unchanged');
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
