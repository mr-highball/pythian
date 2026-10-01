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
    finally
      LResult.Free;
    end;
    LResult := EnqueueStudioJob(ARoot, LWrite);
    try
      Check(LResult.Strings['status'] = 'queued', 'Queued state');
      Check(LResult.Integers['event_revision'] = 1, 'Initial revision');
      Check(not LResult.Booleans['already_queued'], 'First enqueue is fresh');
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

begin
  try
    if ParamCount <> 1 then
    begin
      raise Exception.Create('Usage: studio jobs test FRESH_ROOT');
    end;
    Run(ExpandFileName(ParamStr(1)));
    WriteLn('PASS ', GChecks, ' Studio job lifecycle checks');
  except
    on E: Exception do
    begin
      WriteLn(StdErr, E.ClassName, ': ', E.Message);
      ExitCode := 1;
    end;
  end;
end.
