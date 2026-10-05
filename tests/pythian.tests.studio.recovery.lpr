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
program StudioRecovery;

{$mode delphi}
{$H+}

uses JS, Web, SysUtils, pythian.studio.batches, pythian.studio.progress;

type
  TChecks = class
    Reads: Integer;
    Writes: Integer;
    Mode: String;
    Job: TJSObject;
    Stale: TJSPromiseResolver;
    function Fetch(const APath, AMethod, ABody: String): TJSPromise;
    procedure Run; async;
  end;
var
  GChecks: Integer;

procedure Check(AValue: Boolean; const AMessage: String);
begin
  Inc(GChecks);
  if not AValue then
  begin
    raise Exception.Create(AMessage);
  end;
end;

function Response(AData: TJSObject): TJSObject;
begin
  Result := TJSObject.new;
  Result['status'] := 200;
  Result['json'] := function: TJSPromise
    begin
      Result := TJSPromise.resolve(AData);
    end;
end;

function TChecks.Fetch(const APath, AMethod, ABody: String): TJSPromise;
var
  Data: TJSObject;
  Request: TJSObject;
begin
  if AMethod <> 'GET' then Inc(Writes)
  else Inc(Reads);
  if APath = '/api/studio/cancel' then
  begin
    Job['status'] := 'cancelled';
    Job['stage'] := 'cancelled';
    Job['event_revision'] := 6;
  end;
  if Mode = 'hang' then
  begin
    Result := TJSPromise.new(procedure(Resolve, Reject: TJSPromiseResolver)
      begin
        Stale := Resolve;
      end);
    Exit;
  end;
  if Mode = 'offline' then Exit(TJSPromise.reject('Disconnected'));
  if APath = '/api/studio/preflight' then
  begin
    Request := TJSObject(TJSJSON.parse(ABody));
    Data := TJSObject(TJSJSON.parse('{"format":"pythian.studio.job.preparation.v1","learning_mode":"raw_acoustic","selected_seconds":156.171,"source_count":1,"range_count":2,"unique_source_bytes_to_verify":1966128086,"output_count":1}'));
    Data['job_id'] := Request['job_id'];
    Data['request_sha256'] := StringOfChar('0', 64);
  end
  else if APath = '/api/studio/jobs' then
  begin
    Data := TJSObject.new;
    Data['format'] := 'pythian.studio.jobs.v1';
    Data['jobs'] := TJSArray.new(Job);
  end
  else Data := Job;
  Result := TJSPromise.resolve(Response(Data));
end;

function WaitTurn: TJSPromise;
begin
  Result := TJSPromise.new(procedure(Resolve, Reject: TJSPromiseResolver)
    begin
      window.setTimeout(
        procedure()
        begin
          Resolve(Undefined);
        end, 1);
    end);
end;

procedure Visibility(const AState: String);
var
  Descriptor: TJSObject;
begin
  Descriptor := TJSObject.new;
  Descriptor['value'] := AState;
  Descriptor['configurable'] := True;
  TJSObject.defineProperty(document, 'visibilityState', Descriptor);
  document.dispatchEvent(TJSEvent.new('visibilitychange'));
end;

procedure TChecks.Run; async;
var
  Batches: TStudioBatches;
  Project: TJSObject;
  Other: TJSObject;
  History: TJSObject;
  Before: Integer;
  I: Integer;
begin
  try
    Job := TJSObject(TJSJSON.parse('{"format":"pythian.studio.job.v1","job_id":"batch-qa","project_id":"qa","kind":"train_generate","status":"running","stage":"verify_sources","done":100,"total":200,"progress_unit":"bytes","event_revision":2,"maximum_worker_seconds":7200,"results":{}}'));
    Project := TJSObject(TJSJSON.parse('{"project_id":"qa","snapshot_sha256":"qa-snapshot","name":"QA","revision":1,"learning_mode":"raw_acoustic","sources":[]}'));
    Job['cancel_requested'] := False;
    Mode := 'hang';
    Batches := TStudioBatches.Create(@Fetch);
    try
      Batches.SetProject(Project, False);
      await(WaitTurn);
      Check(Reads >= 1, 'Initial page load requests status');
      Mode := 'ok';
      for I := 1 to 80 do await(WaitTurn);
      Check(Reads >= 3, 'Timed-out history automatically retries and restores selected job');
      Check(Pos('Runs on this computer', document.getElementById('batch-detail').textContent) > 0,
        'Restored finite job explains background lifetime');
      Check(Pos('original file', document.getElementById('batch-detail').textContent) > 0,
        'Identity bytes are distinguished from learned audio');
      Check(Pos('up to date', document.getElementById('batch-notice').textContent) > 0,
        'Successful reconnect clears stale warning');
      Visibility('hidden');
      Before := Reads;
      for I := 1 to 20 do await(WaitTurn);
      Check(Reads = Before, 'Hidden page does not keep polling');
      Job['done'] := 150;
      Job['event_revision'] := 3;
      Visibility('visible');
      for I := 1 to 4 do await(WaitTurn);
      Check(Reads > Before, 'Visibility return immediately reconnects');
      Check(Pos('75%', document.getElementById('batch-detail').textContent) > 0,
        'Returned page displays current native work');
      History := TJSObject.new;
      History['format'] := 'pythian.studio.jobs.v1';
      History['jobs'] := TJSArray.new;
      Stale(Response(History));
      await(WaitTurn);
      Check(Pos('75%', document.getElementById('batch-detail').textContent) > 0,
        'Late timed-out response cannot overwrite recovered job');
      Mode := 'offline';
      window.dispatchEvent(TJSEvent.new('online'));
      for I := 1 to 4 do await(WaitTurn);
      Before := Reads;
      Mode := 'ok';
      for I := 1 to 15 do await(WaitTurn);
      Check(Reads > Before, 'Rejected requests keep retrying');
      Job['status'] := 'failed';
      Job['stage'] := 'runtime_budget';
      Job['error_code'] := 'runtime_budget';
      Job['maximum_worker_seconds'] := 600;
      Job['event_revision'] := 4;
      window.dispatchEvent(TJSEvent.new('pageshow'));
      for I := 1 to 4 do await(WaitTurn);
      Check(Pos('Time limit reached', document.getElementById('batch-detail').textContent) > 0,
        'Persisted timeout has an explicit failure heading');
      Check(Pos('10-minute time limit', document.getElementById('batch-detail').textContent) > 0,
        'Old immutable job displays its original budget');
      Check(Writes = 0, 'Recovery never submits, cancels or duplicates work');
      Job['status'] := 'running';
      Job['stage'] := 'analyze_selected_ranges';
      Job['event_revision'] := 5;
      window.dispatchEvent(TJSEvent.new('pageshow'));
      for I := 1 to 4 do await(WaitTurn);
      TJSHTMLElement(document.getElementById('batch-cancel')).click;
      for I := 1 to 4 do await(WaitTurn);
      Check((Writes = 1) and
        (Pos('Cancelled', document.getElementById('batch-detail').textContent) > 0),
        'Explicit cancellation still makes exactly one write and displays terminal status');
      Project['snapshot_sha256'] := 'qa-preflight';
      Project['sources'] := TJSJSON.parse('[{"source_sha256":"test-source","title":"Original mix","partition":"training"}]');
      Batches.SetProject(Project, False);
      for I := 1 to 4 do await(WaitTurn);
      TJSHTMLElement(document.getElementById('batch-check')).click;
      for I := 1 to 4 do await(WaitTurn);
      Check(Pos('2:36.171', document.getElementById('batch-preflight').textContent) > 0,
        'Setup shows selected training duration');
      Check(Pos(StudioByteSize(1966128086), document.getElementById('batch-preflight').textContent) > 0,
        'Setup separately shows original file size');
      Check(Pos('1 × 20-second auditions', document.getElementById('batch-preflight').textContent) > 0,
        'Requested output is distinct from the training duration');
      Check(Writes = 2, 'Checking setup adds no enqueue or cancellation');
      Other := TJSObject(TJSJSON.parse(TJSJSON.stringify(Project)));
      Other['project_id'] := 'different';
      Other['snapshot_sha256'] := 'different';
      Batches.SetProject(Other, False);
      for I := 1 to 4 do await(WaitTurn);
      Check(document.getElementById('batch-detail').textContent = '',
        'Switching projects does not misattribute a previous job');
    finally
      Batches.Free;
    end;
    Before := Reads;
    window.dispatchEvent(TJSEvent.new('pageshow'));
    Visibility('visible');
    for I := 1 to 10 do await(WaitTurn);
    Check(Reads = Before, 'Destroyed component removes listeners and timers');
    document.body.setAttribute('data-test-result', 'PASS ' + IntToStr(GChecks) + ' recovery checks');
  except
    on E: Exception do document.body.setAttribute('data-test-result', 'FAIL ' + E.Message);
  else
    console.error(JSExceptValue);
    document.body.setAttribute('data-test-result', 'FAIL unhandled test exception');
  end;
end;

var
  Runner: TChecks;
begin
  Runner := TChecks.Create;
  Runner.Run;
end.
