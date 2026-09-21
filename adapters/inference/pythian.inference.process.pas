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
unit pythian.inference.process;

{$mode delphi}
{$H+}
{$packrecords c}

interface

uses
  Windows,
  pythian.inference.observation;

const
  InferencePrivateByteLimit = QWord(2147483648);
  InferenceSetupLimitMs = 30000;
  InferenceStallLimitMs = 5000;

type
  { Dedicated worker protocol, not a general process/runtime abstraction.
    Phase0 setup,1 observing,2 verifying,3 complete. The aligned first word
    publishes phase and clock together. Other live fields are diagnostics only;
    their final values are consumed after the worker has exited. }
  TInferenceProgressSnapshot = type Int64;
  TInferenceWorkerProgress = record
    PhaseClock: Int64;
    Completed: Int64;
    ColdMs: QWord;
    SourceSetupMs: QWord;
    RuntimeSetupMs: QWord;
    SourceReady: LongInt;
    RuntimeReady: LongInt;
    FirstObservationMs: QWord;
    WarmObservationMs: QWord;
  end;
  PInferenceWorkerProgress = ^TInferenceWorkerProgress;
  TInferenceRun = record
    ElapsedMs: QWord;
    ColdMs: QWord;
    SourceSetupMs: QWord;
    RuntimeSetupMs: QWord;
    FirstObservationMs: QWord;
    WarmObservationMs: QWord;
    PeakPrivateBytes: QWord;
    Identity: TInferenceIdentity;
  end;

function OpenInferenceProgress(const AName: String; out AHandle: THandle):
  PInferenceWorkerProgress;
procedure CloseInferenceProgress(var AProgress: PInferenceWorkerProgress;
  var AHandle: THandle);
{ One atomic load owns both decoded values, even if publication happens between
  decoding them. No retry loop or worker-held lock can delay cancellation. }
procedure PublishInferenceProgress(const AProgress: PInferenceWorkerProgress;
  const APhase: LongInt; const ATick: QWord);
function ReadInferenceProgress(const AProgress: PInferenceWorkerProgress):
  TInferenceProgressSnapshot;
function InferenceProgressPhase(const ASnapshot: TInferenceProgressSnapshot): LongInt;
function InferenceProgressTick(const ASnapshot: TInferenceProgressSnapshot): QWord;
{ Launches the exact worker executable suspended, assigns the memory/process
  job limit before resume, polls cancellation at50ms, validates staged output
  then atomically replaces AOutput. Existing accepted bytes survive any failure. }
function RunInferenceProcess(const AWorker, AModelDirectory, ARuntimeDirectory,
  ASource, AOutput: String; const ARequest: TInferenceRequest;
  const ACancel: TInferenceCancel = nil): TInferenceRun;

implementation

uses
  Classes,
  SysUtils,
  pythian.audio,
  pythian.wave.read,
  pythian.resample.stream,
  pythian.tools.files;

type
  TInferenceJobBasic = record
    ProcessTime: Int64;
    JobTime: Int64;
    Flags: Cardinal;
    MinimumWorkingSet: SizeUInt;
    MaximumWorkingSet: SizeUInt;
    ActiveProcesses: Cardinal;
    Affinity: SizeUInt;
    Priority: Cardinal;
    Scheduling: Cardinal;
  end;
  TInferenceJobLimits = record
    Basic: TInferenceJobBasic;
    Io: array[0..5] of QWord;
    ProcessMemory: SizeUInt;
    JobMemory: SizeUInt;
    PeakProcessMemory: SizeUInt;
    PeakJobMemory: SizeUInt;
  end;

function InferenceCreateJob(ASecurity, AName: Pointer): THandle; stdcall;
  external 'kernel32.dll' name 'CreateJobObjectW';
function InferenceSetJob(AJob: THandle; AClass: Integer; AData: Pointer;
  ALength: Cardinal): LongBool; stdcall;
  external 'kernel32.dll' name 'SetInformationJobObject';
function InferenceQueryJob(AJob: THandle; AClass: Integer; AData: Pointer;
  ALength: Cardinal; AReturned: Pointer): LongBool; stdcall;
  external 'kernel32.dll' name 'QueryInformationJobObject';
function InferenceAssignJob(AJob, AProcess: THandle): LongBool; stdcall;
  external 'kernel32.dll' name 'AssignProcessToJobObject';
function InferenceTerminateJob(AJob: THandle; ACode: Cardinal): LongBool; stdcall;
  external 'kernel32.dll' name 'TerminateJobObject';

function InferencePhaseName(const APhase: LongInt): String;
begin
  case APhase of
    0: Result := 'setup';
    1: Result := 'observing';
    2: Result := 'verifying';
    3: Result := 'complete';
  else
    Result := 'unknown-' + IntToStr(APhase);
  end;
end;

procedure PublishInferenceProgress(const AProgress: PInferenceWorkerProgress;
  const APhase: LongInt; const ATick: QWord);
begin
  { Keep the encoded word nonnegative under checked signed arithmetic. This
    clock range exceeds 73 million years; it is not a wrapping low-bit clock. }
  if (APhase < 0) or (APhase > 3) or (ATick > QWord(High(Int64)) shr 2) then
  begin
    raise EAudio.Create('Invalid inference progress phase or clock');
  end;
  InterlockedExchange64(AProgress^.PhaseClock, Int64((ATick shl 2) or QWord(APhase)));
end;

function ReadInferenceProgress(const AProgress: PInferenceWorkerProgress):
  TInferenceProgressSnapshot;
begin
  Result := TInferenceProgressSnapshot(InterlockedCompareExchange64(
    AProgress^.PhaseClock, 0, 0));
  if Result < 0 then
  begin
    raise EAudio.Create('Invalid inference progress snapshot');
  end;
end;

function InferenceProgressPhase(const ASnapshot: TInferenceProgressSnapshot): LongInt;
begin
  Result := LongInt(QWord(ASnapshot) and 3);
end;

function InferenceProgressTick(const ASnapshot: TInferenceProgressSnapshot): QWord;
begin
  Result := QWord(ASnapshot) shr 2;
end;

function QuoteArgument(const AText: String): String;
var
  LSlashes: Integer;
  LCharacter: Char;
begin
  Result := '"';
  LSlashes := 0;
  for LCharacter in AText do
  begin
    if LCharacter = '\' then
    begin
      Inc(LSlashes);
    end
    else
    begin
      if LCharacter = '"' then
      begin
        Result := Result + StringOfChar('\', LSlashes * 2 + 1) + '"';
      end
      else
      begin
        Result := Result + StringOfChar('\', LSlashes) + LCharacter;
      end;
      LSlashes := 0;
    end;
  end;
  Result := Result + StringOfChar('\', LSlashes * 2) + '"';
end;

function OpenInferenceProgress(const AName: String; out AHandle: THandle):
  PInferenceWorkerProgress;
begin
  AHandle := OpenFileMapping(FILE_MAP_ALL_ACCESS, False, PChar(AName));
  if AHandle = 0 then
  begin
    RaiseLastOSError;
  end;
  Result := MapViewOfFile(AHandle, FILE_MAP_ALL_ACCESS, 0, 0, SizeOf(TInferenceWorkerProgress));
  if Result = nil then
  begin
    CloseHandle(AHandle);
    AHandle := 0;
    RaiseLastOSError;
  end;
end;

procedure CloseInferenceProgress(var AProgress: PInferenceWorkerProgress;
  var AHandle: THandle);
begin
  if AProgress <> nil then
  begin
    UnmapViewOfFile(AProgress);
    AProgress := nil;
  end;
  if AHandle <> 0 then
  begin
    CloseHandle(AHandle);
    AHandle := 0;
  end;
end;

function RunInferenceProcess(const AWorker, AModelDirectory, ARuntimeDirectory,
  ASource, AOutput: String; const ARequest: TInferenceRequest;
  const ACancel: TInferenceCancel): TInferenceRun;
var
  LSource: TFileStream;
  LWave: TWaveFrameReader;
  LRead: TInferenceFileReader;
  LJob: THandle;
  LMapping: THandle;
  LProgress: PInferenceWorkerProgress;
  LProcess: TProcessInformation;
  LStartup: TStartupInfo;
  LLimits: TInferenceJobLimits;
  LCommand: String;
  LMappingName: String;
  LTemporary: String;
  LGuid: TGuid;
  LStarted: QWord;
  LWorkerStarted: QWord;
  LNow: QWord;
  LDeadline: QWord;
  LCode: Cardinal;
  LExited: Boolean;
  LErrorBytes: TAudioBytes;
  LError: String;
  LDiagnostic: String;
  LProgressTick: QWord;
  LPhase: LongInt;
  LSnapshot: TInferenceProgressSnapshot;
begin
  Result := Default(TInferenceRun);
  {$if SizeOf(Pointer) <> 8}
    {$fatal Inference supervisor requires Win64}
  {$endif}
  {$if SizeOf(TInferenceJobLimits) <> 144}
    {$fatal Inference supervisor job ABI layout differs}
  {$endif}
  ValidateInferenceRequest(ARequest);
  LStarted := GetTickCount64;
  LSource := nil;
  LWave := nil;
  LRead := nil;
  LJob := 0;
  LMapping := 0;
  LProgress := nil;
  LProcess := Default(TProcessInformation);
  LExited := False;
  LTemporary := '';
  try
    CheckInferenceCancel(ACancel);
    LSource := TFileStream.Create(ASource, fmOpenRead or fmShareDenyWrite);
    LWave := TWaveFrameReader.Create(LSource);
    Result.Identity.Request := ARequest;
    Result.Identity.Estimator := InferenceEstimator;
    Result.Identity.SourceRate := LWave.SampleRate;
    Result.Identity.SourceChannels := LWave.Channels;
    Result.Identity.SourceFrames := LWave.FrameCount;
    Result.Identity.ObservationCount := InferenceCount(ARequest);
    InferenceIdentityText(Result.Identity);
    if ARequest.InputEnd16k > StreamResampleFrameCount(LWave.FrameCount,
      LWave.SampleRate, InferenceRate) then
    begin
      raise EAudio.Create('Inference input boundary exceeds source duration');
    end;
    FreeAndNil(LWave);
    if CreateGUID(LGuid) <> 0 then
    begin
      raise EAudio.Create('Cannot create isolated inference worker identity');
    end;
    LMappingName := 'Local\PythianInference-' + GUIDToString(LGuid);
    LTemporary := ExpandFileName(AOutput) + '.pending-' + GUIDToString(LGuid);
    LMapping := CreateFileMapping(INVALID_HANDLE_VALUE, nil, PAGE_READWRITE,
      0, SizeOf(TInferenceWorkerProgress), PChar(LMappingName));
    if LMapping = 0 then
    begin
      RaiseLastOSError;
    end;
    LProgress := MapViewOfFile(LMapping, FILE_MAP_ALL_ACCESS, 0, 0,
      SizeOf(TInferenceWorkerProgress));
    if LProgress = nil then
    begin
      RaiseLastOSError;
    end;
    FillChar(LProgress^, SizeOf(LProgress^), 0);
    LJob := InferenceCreateJob(nil, nil);
    if LJob = 0 then
    begin
      RaiseLastOSError;
    end;
    LLimits := Default(TInferenceJobLimits);
    { Active-process1, process-memory, kill-on-close. Windows tracks the peak
      commitment even between polls, including external runtime allocations. }
    LLimits.Basic.Flags := $8 or $100 or $2000;
    LLimits.Basic.ActiveProcesses := 1;
    LLimits.ProcessMemory := InferencePrivateByteLimit;
    if not InferenceSetJob(LJob, 9, @LLimits, SizeOf(LLimits)) then
    begin
      RaiseLastOSError;
    end;
    LCommand := QuoteArgument(ExpandFileName(AWorker)) + ' --worker ' +
      QuoteArgument(ExpandFileName(AModelDirectory)) + ' ' +
      QuoteArgument(ExpandFileName(ARuntimeDirectory)) + ' ' +
      QuoteArgument(ExpandFileName(ASource)) + ' ' + QuoteArgument(LTemporary) + ' ' +
      QuoteArgument(LMappingName) + ' ' + ARequest.SourceHash + ' ' +
      QuoteArgument(ARequest.Policy) + ' ' + IntToStr(ARequest.Channel) + ' ' +
      IntToStr(ARequest.ScopeStart16k) + ' ' + IntToStr(ARequest.ScopeEnd16k) + ' ' +
      IntToStr(ARequest.InputStart16k) + ' ' + IntToStr(ARequest.InputEnd16k) + ' ' +
      IntToStr(ARequest.FirstCenter16k) + ' ' + IntToStr(ARequest.Hop16k) + ' ' +
      IntToStr(ARequest.BatchSize);
    LStartup := Default(TStartupInfo);
    LStartup.cb := SizeOf(LStartup);
    LStartup.dwFlags := STARTF_USESHOWWINDOW;
    LStartup.wShowWindow := SW_HIDE;
    if not CreateProcess(nil, PChar(LCommand), nil, nil, False,
      CREATE_SUSPENDED or $08000000, nil, nil, LStartup, LProcess) then
    begin
      RaiseLastOSError;
    end;
    if not InferenceAssignJob(LJob, LProcess.hProcess) then
    begin
      RaiseLastOSError;
    end;
    LWorkerStarted := GetTickCount64;
    PublishInferenceProgress(LProgress, 0, LWorkerStarted);
    if ResumeThread(LProcess.hThread) = Cardinal(-1) then
    begin
      RaiseLastOSError;
    end;
    LDeadline := InferenceSetupLimitMs +
      QWord(ARequest.ScopeEnd16k - ARequest.ScopeStart16k) * 1000 div InferenceRate;
    repeat
      CheckInferenceCancel(ACancel);
      LSnapshot := ReadInferenceProgress(LProgress);
      LProgressTick := InferenceProgressTick(LSnapshot);
      LPhase := InferenceProgressPhase(LSnapshot);
      LNow := GetTickCount64;
      LDiagnostic := ' phase=' + InferencePhaseName(LPhase) +
        ' total_ms=' + IntToStr(LNow - LStarted) +
        ' worker_ms=' + IntToStr(LNow - LWorkerStarted) +
        ' progress_age_ms=' + IntToStr(LNow - LProgressTick) +
        ' completed=' + IntToStr(LProgress^.Completed) +
        ' source_ready=' + IntToStr(LProgress^.SourceReady) +
        ' source_setup_ms=' + IntToStr(LProgress^.SourceSetupMs) +
        ' runtime_ready=' + IntToStr(LProgress^.RuntimeReady) +
        ' runtime_setup_ms=' + IntToStr(LProgress^.RuntimeSetupMs);
      if (LPhase = 0) and
        (LNow - LWorkerStarted > InferenceSetupLimitMs) then
      begin
        raise EAudio.Create('Inference setup budget exceeded: limit_ms=' +
          IntToStr(InferenceSetupLimitMs) + LDiagnostic);
      end;
      if LNow - LStarted > LDeadline then
      begin
        raise EAudio.Create('Inference total budget exceeded: limit_ms=' +
          IntToStr(LDeadline) + LDiagnostic);
      end;
      if (LPhase = 1) and
        (LNow - LProgressTick > InferenceStallLimitMs) then
      begin
        raise EAudio.Create('Inference observing-stall budget exceeded: limit_ms=' +
          IntToStr(InferenceStallLimitMs) + LDiagnostic);
      end;
      LCode := WaitForSingleObject(LProcess.hProcess, 50);
      if LCode = WAIT_FAILED then
      begin
        RaiseLastOSError;
      end;
    until LCode = WAIT_OBJECT_0;
    LExited := True;
    if not GetExitCodeProcess(LProcess.hProcess, LCode) then
    begin
      RaiseLastOSError;
    end;
    LSnapshot := ReadInferenceProgress(LProgress);
    if (LCode <> 0) or (InferenceProgressPhase(LSnapshot) <> 3) or
      (LProgress^.Completed <> Result.Identity.ObservationCount) then
    begin
      LError := '';
      if FileExists(LTemporary + '.error') then
      begin
        LErrorBytes := ReadFileBytes(LTemporary + '.error', 4096);
        if Length(LErrorBytes) > 0 then
        begin
          SetString(LError, PChar(@LErrorBytes[0]), Length(LErrorBytes));
        end;
      end;
      raise EAudio.CreateFmt('Inference worker failed or did not complete (exit %d): %s',
        [LCode, LError]);
    end;
    if not InferenceQueryJob(LJob, 9, @LLimits, SizeOf(LLimits), nil) then
    begin
      RaiseLastOSError;
    end;
    Result.PeakPrivateBytes := LLimits.PeakProcessMemory;
    Result.ColdMs := LProgress^.ColdMs;
    Result.SourceSetupMs := LProgress^.SourceSetupMs;
    Result.RuntimeSetupMs := LProgress^.RuntimeSetupMs;
    Result.FirstObservationMs := LProgress^.FirstObservationMs;
    Result.WarmObservationMs := LProgress^.WarmObservationMs;
    if Result.PeakPrivateBytes > InferencePrivateByteLimit then
    begin
      raise EAudio.Create('Inference private-memory budget exceeded: bytes=' +
        IntToStr(Result.PeakPrivateBytes) + ' limit_bytes=' + IntToStr(InferencePrivateByteLimit));
    end;
    if Result.ColdMs > InferenceSetupLimitMs then
    begin
      raise EAudio.Create('Inference completed setup budget exceeded: cold_ms=' +
        IntToStr(Result.ColdMs) + ' limit_ms=' + IntToStr(InferenceSetupLimitMs) +
        ' source_setup_ms=' + IntToStr(Result.SourceSetupMs) +
        ' runtime_setup_ms=' + IntToStr(Result.RuntimeSetupMs));
    end;
    CheckInferenceCancel(ACancel);
    LRead := TInferenceFileReader.Create(LTemporary, Result.Identity, ACancel);
    FreeAndNil(LRead);
    CheckInferenceCancel(ACancel);
    Result.ElapsedMs := GetTickCount64 - LStarted;
    if Result.ElapsedMs > LDeadline then
    begin
      raise EAudio.Create('Inference final-verification total budget exceeded: total_ms=' +
        IntToStr(Result.ElapsedMs) + ' limit_ms=' + IntToStr(LDeadline));
    end;
    if not MoveFileEx(PChar(LTemporary), PChar(ExpandFileName(AOutput)),
      MOVEFILE_REPLACE_EXISTING or $8) then
    begin
      RaiseLastOSError;
    end;
    LTemporary := '';
  finally
    LRead.Free;
    if (LProcess.hProcess <> 0) and not LExited then
    begin
      { Also terminates a suspended child if job assignment failed. }
      TerminateProcess(LProcess.hProcess, 1);
      if LJob <> 0 then
      begin
        InferenceTerminateJob(LJob, 1);
      end;
      WaitForSingleObject(LProcess.hProcess, 1500);
    end;
    if LProcess.hThread <> 0 then
    begin
      CloseHandle(LProcess.hThread);
    end;
    if LProcess.hProcess <> 0 then
    begin
      CloseHandle(LProcess.hProcess);
    end;
    if LJob <> 0 then
    begin
      CloseHandle(LJob);
    end;
    CloseInferenceProgress(LProgress, LMapping);
    if LTemporary <> '' then
    begin
      SysUtils.DeleteFile(LTemporary);
      SysUtils.DeleteFile(LTemporary + '.error');
    end;
    LWave.Free;
    LSource.Free;
  end;
end;

end.
