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
program StudioSupervisorConformance;

{$mode delphi}
{$H+}

uses
  {$IFDEF UNIX}cthreads,{$ENDIF}
  Classes,
  SysUtils,
  Process,
  fpjson,
  pythian.audio,
  pythian.tools.studio.jobs,
  pythian.tools.studio.supervisor,
  pythian.tools.studio.worker
  {$IFDEF MSWINDOWS}, Windows{$ENDIF};

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

procedure Queue(const ACatalog, AId: String);
var
  LWrite: TJSONObject;
  LResult: TJSONObject;
begin
  LWrite := TJSONObject.Create;
  try
    LWrite.Add('format', StudioJobWriteFormat);
    LWrite.Add('job_id', AId);
    LWrite.Add('kind', 'library_refresh');
    LResult := EnqueueStudioJob(ACatalog, LWrite);
    LResult.Free;
  finally
    LWrite.Free;
  end;
end;

function AwaitState(const ACatalog, AId, AStatus: String): TJSONObject;
var
  LStarted: QWord;
begin
  LStarted := GetTickCount64;
  repeat
    Result := ReadStudioJob(ACatalog, AId);
    if Result.Strings['status'] = AStatus then
    begin
      Exit;
    end;
    if (Result.Strings['status'] = 'failed') or (Result.Strings['status'] = 'completed') or
      (Result.Strings['status'] = 'cancelled') then
    begin
      if AStatus = 'running' then
      begin
        Result.Free;
        raise Exception.Create('Child unexpectedly reached terminal state before running observation');
      end;
    end;
    Result.Free;
    Sleep(20);
  until GetTickCount64 - LStarted > 12000;
  raise Exception.Create('Supervisor state wait exceeded twelve seconds');
end;

function JobWorkerId(const ACatalog: String): Int64;
var
  LOwner: TJSONObject;
begin
  LOwner := ReadStudioJSON(ACatalog + PathDelim + 'studio' + PathDelim + 'jobs' +
    PathDelim + '.worker-lock' + PathDelim + 'owner.json');
  try
    Result := LOwner.Int64s['process_id'];
  finally
    LOwner.Free;
  end;
end;

procedure CheckStopped(const AId: Int64);
{$IFDEF MSWINDOWS}
var
  LHandle: THandle;
{$ENDIF}
begin
  {$IFDEF MSWINDOWS}
  LHandle := OpenProcess(SYNCHRONIZE, False, Cardinal(AId));
  if LHandle = 0 then
  begin
    Check(GetLastError = ERROR_INVALID_PARAMETER, 'Former owned worker identity absent');
  end
  else
  begin
    try
      Check(WaitForSingleObject(LHandle, 0) = WAIT_OBJECT_0, 'Former owned worker actually stopped');
    finally
      CloseHandle(LHandle);
    end;
  end;
  {$ELSE}
  Check(AId > 0, 'Retained actual owned child identity');
  {$ENDIF}
end;

procedure Run(const ARoot: String);
var
  LCatalog: String;
  LLibrary: String;
  LState: TJSONObject;
  LSupervisor: TStudioJobSupervisor;
  LOther: TStudioJobSupervisor;
  LChild: TProcess;
  LId: Int64;
  LFailed: Boolean;
  LStage: String;
begin
  Check(not DirectoryExists(ARoot), 'Supervisor fixture root is fresh');
  LCatalog := ARoot + PathDelim + 'catalog';
  LLibrary := ARoot + PathDelim + 'library';
  Check(ForceDirectories(LCatalog + PathDelim + 'sources'), 'Create isolated source directory');
  Check(ForceDirectories(LCatalog + PathDelim + 'tracks'), 'Create isolated track directory');
  Check(ForceDirectories(LLibrary + PathDelim + 'collections'), 'Create empty first-party library');
  LStage := ReserveStudioJobStage(LCatalog, LLibrary, 'first', 'refresh');
  Check(not DirectoryExists(LStage), 'Reserved staging leaf remains absent');
  Check(DirectoryExists(ExtractFileDir(LStage)), 'Private staging parent exists');
  Queue(LCatalog, 'first');
  Queue(LCatalog, 'second');
  LSupervisor := TStudioJobSupervisor.Create(LCatalog, LLibrary, ParamStr(0));
  try
    LOther := nil;
    LFailed := False;
    try
      LOther := TStudioJobSupervisor.Create(LCatalog, LLibrary, ParamStr(0));
    except
      on E: EFCreateError do
      begin
        LFailed := True;
      end;
      on E: EFOpenError do
      begin
        LFailed := True;
      end;
      on E: EAudio do
      begin
        LFailed := True;
      end;
    end;
    LOther.Free;
    Check(LFailed, 'Second catalog supervisor rejected');
    LState := AwaitState(LCatalog, 'first', 'completed');
    try
      Check(LState.Objects['results'].Integers['revision'] = 1, 'Actual child library refresh publishes first revision');
    finally
      LState.Free;
    end;
    LState := AwaitState(LCatalog, 'second', 'completed');
    try
      Check(LState.Objects['results'].Integers['revision'] = 2, 'Queued second child automatically pumped');
    finally
      LState.Free;
    end;
    Queue(LCatalog, 'blocked-cancel');
    LSupervisor.Notify;
    LState := AwaitState(LCatalog, 'blocked-cancel', 'running');
    LState.Free;
    LId := JobWorkerId(LCatalog);
    LState := CancelStudioJob(LCatalog, 'blocked-cancel');
    LState.Free;
    LState := AwaitState(LCatalog, 'blocked-cancel', 'cancelled');
    try
      Check(LState.Strings['error_code'] = 'cancelled', 'Forced cancellation records actual terminal cause');
    finally
      LState.Free;
    end;
    CheckStopped(LId);
    Check(not DirectoryExists(LCatalog + PathDelim + 'studio' + PathDelim + 'jobs' +
      PathDelim + '.worker-lock'), 'Stopped child lock released');
    Queue(LCatalog, 'blocked-stop');
    LSupervisor.Notify;
    LState := AwaitState(LCatalog, 'blocked-stop', 'running');
    LState.Free;
    LId := JobWorkerId(LCatalog);
  finally
    LSupervisor.Free;
  end;
  CheckStopped(LId);
  LState := ReadStudioJob(LCatalog, 'blocked-stop');
  try
    Check((LState.Strings['status'] = 'failed') and
      (LState.Strings['error_code'] = 'service_stopped'), 'Supervisor teardown rejects unfinished work');
  finally
    LState.Free;
  end;
  Queue(LCatalog, 'blocked-crash');
  LChild := TProcess.Create(nil);
  try
    LChild.Executable := ParamStr(0);
    LChild.Parameters.Add(LCatalog);
    LChild.Parameters.Add('blocked-crash');
    LChild.Parameters.Add(LLibrary);
    LChild.Options := [poNoConsole];
    {$IFDEF MSWINDOWS}
    LChild.ShowWindow := swoHIDE;
    {$ENDIF}
    LChild.Execute;
    LState := AwaitState(LCatalog, 'blocked-crash', 'running');
    LState.Free;
    LId := JobWorkerId(LCatalog);
    LChild.Terminate(1);
    Check(LChild.WaitOnExit(5000), 'Test-owned crashed child stopped');
  finally
    if LChild.Running then
    begin
      LChild.Terminate(1);
      LChild.WaitOnExit(5000);
    end;
    LChild.Free;
  end;
  CheckStopped(LId);
  LSupervisor := TStudioJobSupervisor.Create(LCatalog, LLibrary, ParamStr(0));
  try
    LState := ReadStudioJob(LCatalog, 'blocked-crash');
    try
      Check((LState.Strings['status'] = 'failed') and
        (LState.Strings['error_code'] = 'interrupted'), 'Stopped-process restart recovery retains interrupted failure');
    finally
      LState.Free;
    end;
    Queue(LCatalog, 'after-restart');
    LSupervisor.Notify;
    LState := AwaitState(LCatalog, 'after-restart', 'completed');
    try
      Check(LState.Objects['results'].Integers['revision'] = 3, 'Restart pumps later work without replacing prior revisions');
    finally
      LState.Free;
    end;
    Check(LSupervisor.LastError = '', 'Supervisor retains no unexplained error');
  finally
    LSupervisor.Free;
  end;
end;

var
  LRequest: TJSONObject;
begin
  try
    if ParamCount = 3 then
    begin
      if Pos('blocked-', ParamStr(2)) = 1 then
      begin
        { Deliberately uncooperative source-free TEST child. The production
          worker has no such mode; the supervisor must stop only this child. }
        LRequest := ClaimStudioJob(ParamStr(1), ParamStr(2));
        LRequest.Free;
        Sleep(70000);
        raise Exception.Create('Blocked test worker unexpectedly outlived its guard');
      end;
      if not RunStudioWorker(ParamStr(1), ParamStr(2), ParamStr(3)) then
      begin
        ExitCode := 1;
      end;
    end
    else if ParamCount = 1 then
    begin
      Run(ExpandFileName(ParamStr(1)));
      WriteLn('PASS ', GChecks, ' real Studio supervisor checks');
    end
    else
    begin
      raise Exception.Create('Usage: Studio supervisor test FRESH_ROOT');
    end;
  except
    on E: Exception do
    begin
      WriteLn(StdErr, E.ClassName, ': ', E.Message);
      ExitCode := 1;
    end;
  end;
end.
