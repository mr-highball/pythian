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
unit pythian.tools.studio.supervisor;

{$mode delphi}
{$H+}

interface

uses
  Classes,
  SyncObjs;

type
  { Owns only the configured worker child. No WFC dependency, request-thread
    source hashing, arbitrary executable command, or external process cleanup. }
  TStudioJobSupervisor = class
  private
    FCatalogRoot: String;
    FLibraryRoot: String;
    FWorkerExecutable: String;
    FThread: TThread;
    FWake: TEvent;
    FLock: TFileStream;
    FMessageLock: TRTLCriticalSection;
    FLastError: String;
    procedure SetLastError(const AMessage: String);
    function GetLastError: String;
  public
    constructor Create(const ACatalogRoot, ALibraryRoot, AWorkerExecutable: String);
    destructor Destroy; override;
    procedure Notify;
    property LastError: String read GetLastError;
  end;

implementation

uses
  SysUtils,
  Process,
  fpjson,
  pythian.audio,
  pythian.tools.studio.jobs
  {$IFDEF MSWINDOWS}, Windows{$ELSE}, BaseUnix, Unix{$ENDIF};

type
  TStudioPump = class(TThread)
  private
    FOwner: TStudioJobSupervisor;
    FProcess: TProcess;
    FJobId: String;
    FStarted: QWord;
    FCancelAt: QWord;
    FLog: TFileStream;
    procedure Drain;
    procedure StopChild(const ACode, AMessage: String);
    procedure Poll;
  protected
    procedure Execute; override;
  public
    constructor Create(const AOwner: TStudioJobSupervisor);
    destructor Destroy; override;
  end;

function ProcessAlive(const AId: Int64): Boolean;
{$IFDEF MSWINDOWS}
var
  LHandle: THandle;
{$ENDIF}
begin
  if (AId <= 0) or (AId > High(Cardinal)) then
  begin
    Exit(False);
  end;
  {$IFDEF MSWINDOWS}
  LHandle := OpenProcess(SYNCHRONIZE, False, Cardinal(AId));
  if LHandle = 0 then
  begin
    if GetLastError = ERROR_INVALID_PARAMETER then
    begin
      Exit(False);
    end;
    raise EAudio.Create('Cannot establish stopped Studio worker identity');
  end;
  try
    Result := WaitForSingleObject(LHandle, 0) = WAIT_TIMEOUT;
  finally
    CloseHandle(LHandle);
  end;
  {$ELSE}
  Result := (fpKill(AId, 0) = 0) or (fpGetErrno <> ESysESRCH);
  {$ENDIF}
end;

constructor TStudioJobSupervisor.Create(const ACatalogRoot, ALibraryRoot,
  AWorkerExecutable: String);
var
  LRoot: String;
  LOwner: TJSONObject;
begin
  inherited Create;
  InitCriticalSection(FMessageLock);
  FCatalogRoot := ExpandFileName(ACatalogRoot);
  FLibraryRoot := ExpandFileName(ALibraryRoot);
  FWorkerExecutable := ExpandFileName(AWorkerExecutable);
  if not DirectoryExists(FCatalogRoot) or not FileExists(FWorkerExecutable) then
  begin
    raise EAudio.Create('Studio catalog or configured native worker is unavailable');
  end;
  LRoot := IncludeTrailingPathDelimiter(FCatalogRoot) + 'studio' + PathDelim + 'jobs';
  ForceDirectories(LRoot);
  FLock := TFileStream.Create(LRoot + PathDelim + '.supervisor.lock',
    fmCreate or fmShareExclusive);
  {$IFNDEF MSWINDOWS}
  if fpFlock(FLock.Handle, LOCK_EX or LOCK_NB) <> 0 then
  begin
    raise EAudio.Create('A Studio supervisor already owns this catalog');
  end;
  {$ENDIF}
  if DirectoryExists(LRoot + PathDelim + '.worker-lock') then
  begin
    LOwner := ReadStudioJSON(LRoot + PathDelim + '.worker-lock' + PathDelim + 'owner.json');
    try
      if ProcessAlive(LOwner.Int64s['process_id']) then
      begin
        raise EAudio.Create('An earlier Studio worker is still running; do not start another');
      end;
    finally
      LOwner.Free;
    end;
  end;
  RecoverStudioJobs(FCatalogRoot, True);
  FWake := TEvent.Create(nil, False, False, '');
  FThread := TStudioPump.Create(Self);
  FThread.Start;
end;

destructor TStudioJobSupervisor.Destroy;
begin
  if FThread <> nil then
  begin
    FThread.Terminate;
    Notify;
    FThread.WaitFor;
    FThread.Free;
  end;
  FWake.Free;
  FLock.Free;
  DoneCriticalSection(FMessageLock);
  inherited Destroy;
end;

procedure TStudioJobSupervisor.Notify;
begin
  if FWake <> nil then
  begin
    FWake.SetEvent;
  end;
end;

procedure TStudioJobSupervisor.SetLastError(const AMessage: String);
begin
  EnterCriticalSection(FMessageLock);
  try
    FLastError := AMessage;
  finally
    LeaveCriticalSection(FMessageLock);
  end;
end;

function TStudioJobSupervisor.GetLastError: String;
begin
  EnterCriticalSection(FMessageLock);
  try
    Result := FLastError;
  finally
    LeaveCriticalSection(FMessageLock);
  end;
end;

constructor TStudioPump.Create(const AOwner: TStudioJobSupervisor);
begin
  inherited Create(True);
  FreeOnTerminate := False;
  FOwner := AOwner;
end;

destructor TStudioPump.Destroy;
begin
  FLog.Free;
  FProcess.Free;
  inherited Destroy;
end;

procedure TStudioPump.Drain;
var
  LBytes: array[0..65535] of Byte;
  LCount: Integer;
begin
  if (FProcess = nil) or (FLog = nil) then
  begin
    Exit;
  end;
  while FProcess.Output.NumBytesAvailable > 0 do
  begin
    LCount := FProcess.Output.Read(LBytes, SizeOf(LBytes));
    if LCount <= 0 then
    begin
      Break;
    end;
    if FLog.Size + LCount > 1048576 then
    begin
      raise EAudio.Create('Studio worker diagnostic output exceeds its bound');
    end;
    FLog.WriteBuffer(LBytes, LCount);
  end;
end;

procedure TStudioPump.StopChild(const ACode, AMessage: String);
var
  LState: TJSONObject;
  LStatus: String;
begin
  if FProcess = nil then
  begin
    Exit;
  end;
  if FProcess.Running then
  begin
    FProcess.Terminate(1);
    FProcess.WaitOnExit(5000);
    if FProcess.Running then
    begin
      raise EAudio.Create('Owned Studio worker did not terminate; retain lock and stop supervision');
    end;
  end;
  Drain;
  LState := ReadStudioJob(FOwner.FCatalogRoot, FJobId);
  try
    if (LState.Strings['status'] = 'running') or (LState.Strings['status'] = 'queued') then
    begin
      LStatus := 'failed';
      if StudioJobCancelled(FOwner.FCatalogRoot, FJobId) then
      begin
        LStatus := 'cancelled';
      end;
      AdvanceStudioJob(FOwner.FCatalogRoot, FJobId, LStatus, ACode, 0, 0,
        nil, ACode, AMessage);
    end;
  finally
    LState.Free;
  end;
  ReleaseStudioWorker(FOwner.FCatalogRoot);
  FreeAndNil(FLog);
  FreeAndNil(FProcess);
  FJobId := '';
end;

procedure TStudioPump.Poll;
var
  LJobs: TJSONObject;
  LRow: TJSONObject;
  LIndex: Integer;
begin
  if FProcess <> nil then
  begin
    Drain;
    if not FProcess.Running then
    begin
      StopChild('worker_exit', 'Native worker stopped without a completed receipt');
      Exit;
    end;
    if GetTickCount64 - FStarted > QWord(MaximumStudioJobSeconds) * 1000 then
    begin
      StopChild('runtime_budget', 'Native worker exceeded the declared wall-clock limit');
      Exit;
    end;
    if StudioJobCancelled(FOwner.FCatalogRoot, FJobId) then
    begin
      if FCancelAt = 0 then
      begin
        FCancelAt := GetTickCount64;
      end;
      if GetTickCount64 - FCancelAt > 5000 then
      begin
        StopChild('cancelled', 'Stopped the owned worker after its cancellation grace period');
      end;
    end;
    Exit;
  end;
  LJobs := ListStudioJobs(FOwner.FCatalogRoot);
  try
    for LIndex := 0 to LJobs.Arrays['jobs'].Count - 1 do
    begin
      LRow := LJobs.Arrays['jobs'].Objects[LIndex];
      if LRow.Strings['status'] = 'queued' then
      begin
        FJobId := LRow.Strings['job_id'];
        FProcess := TProcess.Create(nil);
        FProcess.Executable := FOwner.FWorkerExecutable;
        FProcess.Parameters.Add(FOwner.FCatalogRoot);
        FProcess.Parameters.Add(FJobId);
        FProcess.Parameters.Add(FOwner.FLibraryRoot);
        FProcess.Options := [poUsePipes, poStderrToOutput, poNoConsole];
        {$IFDEF MSWINDOWS}
        FProcess.ShowWindow := swoHIDE;
        {$ENDIF}
        FLog := TFileStream.Create(StudioJobDirectory(FOwner.FCatalogRoot, FJobId) +
          PathDelim + 'worker.log', fmCreate or fmShareDenyWrite);
        FStarted := GetTickCount64;
        FCancelAt := 0;
        FProcess.Execute;
        Break;
      end;
    end;
  finally
    LJobs.Free;
  end;
end;

procedure TStudioPump.Execute;
begin
  try
    while not Terminated do
    begin
      try
        Poll;
        FOwner.SetLastError('');
      except
        on E: Exception do
        begin
          FOwner.SetLastError(E.ClassName + ': Studio queue supervision failed; inspect retained worker log');
          if FProcess <> nil then
          begin
            StopChild('supervisor_error', 'Studio worker supervision failed');
          end;
        end;
      end;
      FOwner.FWake.WaitFor(250);
    end;
  finally
    StopChild('service_stopped', 'Review service stopped; completed files retained, unfinished work rejected');
  end;
end;

end.
