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
    LastRequest: TJSObject;
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
    LastRequest := Request;
    if Request.hasOwnProperty('preparation') then
    begin
      Data['preparation'] := Request['preparation'];
      Data['sample_rate'] := 48000;
      Data['prepared_channels'] := 2;
      Data['prepared_bytes_upper_bound'] := 192080;
      Data['preparation_visits_upper_bound'] := 100000;
      Data['prepared_ranges'] := TJSJSON.parse('[{"source_sha256":"test-source","original_start_frame":0,"original_end_frame":44100,"original_sample_rate":44100,"original_channels":1,"prepared_frames":48000,"prepared_sample_rate":48000,"prepared_channels":2}]');
    end;
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
  LProgress: TJSElement;
  LImportJob: TJSObject;
  LStages: array of String;
begin
  try
    LProgress := document.createElement('div');
    document.body.appendChild(LProgress);
    try
      LImportJob := TJSObject(TJSJSON.parse('{"status":"running","done":65536,"total":131072,"progress_unit":"bytes"}'));
      LStages := ['import_hash_bytes', 'import_copy_bytes', 'import_verify_bytes'];
      for I := 0 to High(LStages) do
      begin
        LImportJob['stage'] := LStages[I];
        LProgress.textContent := '';
        DrawStudioProgress(LProgress, LImportJob);
        Check(Pos('50%', LProgress.textContent) > 0, 'Import phase shows actual byte ratio');
        Check(Pos('64.0 KiB / 128.0 KiB', LProgress.textContent) > 0,
          'Import reports the actual current byte extent');
        Check(Pos('Preparing music', LProgress.textContent) = 0, 'Import phase has a specific label');
      end;
      LImportJob['status'] := 'cancelled';
      LProgress.textContent := '';
      DrawStudioProgress(LProgress, LImportJob);
      Check(LProgress.querySelector('progress') = nil, 'Cancelled import removes running bar');
      LImportJob['status'] := 'running';
      LImportJob['stage'] := 'wfc_solve_search_visits';
      LImportJob['total'] := 0;
      LImportJob['done'] := 257;
      LImportJob['progress_unit'] := 'items';
      LImportJob['progress_pass'] := 3;
      LProgress.textContent := '';
      DrawStudioProgress(LProgress, LImportJob);
      Check(not LProgress.querySelector('progress').hasAttribute('value'),
        'Unknown work remains indeterminate');
      Check((Pos('257 work steps checked', LProgress.textContent) > 0) and
        (Pos('Find the next musical pattern', LProgress.textContent) > 0) and
        (Pos('%', LProgress.textContent) = 0),
        'Unknown work has useful phase/activity text without a guessed percentage');
      LImportJob['status'] := 'completed';
      LProgress.textContent := '';
      DrawStudioProgress(LProgress, LImportJob);
      Check(LProgress.querySelector('progress') = nil, 'Completed import leaves no partial byte bar');
    finally
      LProgress.remove;
    end;
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
      Check(not LastRequest.hasOwnProperty('preparation'), 'Preparation is opt-in');
      Check(Pos('Training weight', document.getElementById('batch-weights').textContent) > 0,
        'Training control is labelled');
      Check(Pos('Playback preference', document.getElementById('batch-weights').textContent) > 0,
        'Playback control is labelled');
      Check((TJSObject(TJSArray(LastRequest['source_weights'])[0])['weight'] = 1) and
        (TJSObject(TJSArray(LastRequest['generation_weights'])[0])['weight'] = 1),
        'Both recording preferences default to one');
      TJSHTMLInputElement(document.getElementById('batch-weight-test-source')).value := '3';
      TJSHTMLInputElement(document.getElementById('batch-playback-test-source')).value := '7';
      document.getElementById('batch-playback-test-source').dispatchEvent(TJSEvent.new('input'));
      TJSHTMLElement(document.getElementById('batch-check')).click;
      for I := 1 to 4 do await(WaitTurn);
      Check((TJSObject(TJSArray(LastRequest['source_weights'])[0])['weight'] = 3) and
        (TJSObject(TJSArray(LastRequest['generation_weights'])[0])['weight'] = 7),
        'Training and playback vectors remain separate');
      Other := TJSObject(TJSJSON.parse(TJSJSON.stringify(LastRequest)));
      Other['parent_job_id'] := 'reviewed';
      Batches.ApplyNextBatch(Other);
      Check(TJSHTMLInputElement(document.getElementById('batch-playback-test-source')).value = '7',
        'Reviewed explicit playback preference restored');
      asm delete Other.generation_weights; end;
      Batches.ApplyNextBatch(Other);
      Check(TJSHTMLInputElement(document.getElementById('batch-playback-test-source')).value = '3',
        'Legacy reviewed batch inherits training preference');
      Other['generation_weights'] := TJSJSON.parse('[{"source_sha256":"other","weight":2}]');
      try
        Batches.ApplyNextBatch(Other);
        Check(False, 'Mismatched reviewed preferences must fail');
      except
        on E: Exception do Check(True, 'Mismatched reviewed preferences are rejected');
      end;
      Check(TJSHTMLInputElement(document.getElementById('batch-playback-test-source')).value = '3',
        'Rejected reviewed preferences do not change controls');
      Project['snapshot_sha256'] := 'qa-preflight-updated';
      Batches.SetProject(Project, False);
      Check((TJSHTMLInputElement(document.getElementById('batch-weight-test-source')).value = '3') and
        (TJSHTMLInputElement(document.getElementById('batch-playback-test-source')).value = '3'),
        'Same-project redraw preserves unsaved recording preferences');
      Before := Writes;
      TJSHTMLInputElement(document.getElementById('batch-playback-test-source')).value := '17';
      document.getElementById('batch-playback-test-source').dispatchEvent(TJSEvent.new('input'));
      TJSHTMLElement(document.getElementById('batch-check')).click;
      for I := 1 to 4 do await(WaitTurn);
      Check(Writes = Before, 'Out-of-range playback preference is rejected before request');
      TJSHTMLInputElement(document.getElementById('batch-playback-test-source')).value := '3';
      document.getElementById('batch-playback-test-source').dispatchEvent(TJSEvent.new('input'));

      TJSHTMLInputElement(document.getElementById('batch-prepare')).checked := True;
      document.getElementById('batch-prepare').dispatchEvent(TJSEvent.new('change'));
      TJSHTMLElement(document.getElementById('batch-check')).click;
      for I := 1 to 4 do await(WaitTurn);
      Check(LastRequest.hasOwnProperty('preparation'), 'Opt-in reaches preflight');
      Check((TJSObject(LastRequest['preparation'])['sample_rate'] = 48000) and
        (TJSObject(LastRequest['preparation'])['channels'] = 2) and
        (TJSObject(LastRequest['preparation'])['gain'] = 1), 'Explicit preparation defaults retained');
      Check(document.querySelector('#batch-preflight details summary').textContent =
        'Preparation details', 'Range details are expandable');
      Check(Pos('Original mix: 0:00.000–0:01.000',
        document.querySelector('#batch-preflight details').textContent) > 0,
        'Selection leads with title and original time range');
      Check(Pos('filter visits', document.getElementById('batch-preflight').firstChild.textContent) = 0,
        'Filter work is absent from the main summary');
      Check(Pos('44100', document.getElementById('batch-preflight').textContent) > 0,
        'Preflight displays original clock');
      Check(Pos('48000 prepared frames', document.getElementById('batch-preflight').textContent) > 0,
        'Preflight displays prepared geometry');
      Before := Writes;
      TJSHTMLInputElement(document.getElementById('batch-prepare-gain')).value := '0';
      document.getElementById('batch-prepare-gain').dispatchEvent(TJSEvent.new('input'));
      TJSHTMLElement(document.getElementById('batch-check')).click;
      for I := 1 to 4 do await(WaitTurn);
      Check(Writes = Before, 'Invalid preparation gain does not submit a request');
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
