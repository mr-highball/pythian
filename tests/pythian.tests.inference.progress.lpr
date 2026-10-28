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
program pythian_tests_inference_progress;

{$mode delphi}{$H+}

uses
  Windows, Classes, SysUtils, Math,
  pythian.audio, pythian.progress, pythian.wave.stream,
  pythian.inference.observation, pythian.inference.wave,
  pythian.inference.process, pythian.tools.files;

type
  TStopPoint = (spStart, spInterior, spFinal);
  TObserver = class
  public
    Stages: TStringList;
    Stage: String;
    Point: TStopPoint;
    Marker: Exception;
    CancelStage: String;
    CancelNow: Boolean;
    Calls: Integer;
    SawInterior: Boolean;
    constructor Create;
    destructor Destroy; override;
    procedure Observe(const AWork: TWorkProgress);
    function Cancelled: Boolean;
  end;

var
  GChecks: Integer;
  GAborts: Integer;
  GDirectory: String;
  GSource: String;
  GOutput: String;
  GHash: String;
  GRequest: TInferenceRequest;
  GIdentity: TInferenceIdentity;

procedure Check(const AValue: Boolean; const AMessage: String);
begin
  Inc(GChecks);
  if not AValue then
    raise Exception.Create(AMessage);
end;

constructor TObserver.Create;
begin
  inherited Create;
  Stages := TStringList.Create;
end;

destructor TObserver.Destroy;
begin
  Marker.Free;
  Stages.Free;
  inherited Destroy;
end;

procedure TObserver.Observe(const AWork: TWorkProgress);
var
  LStop: Boolean;
begin
  Inc(Calls);
  Check((AWork.Done >= 0) and (AWork.Total >= 0) and (AWork.Pass = 0), 'Work geometry');
  Check((AWork.Total = 0) or (AWork.Done <= AWork.Total), 'Work exceeds total');
  if Stages.IndexOf(AWork.Stage) < 0 then
    Stages.Add(AWork.Stage);
  if AWork.Stage = 'inference_observe_rows' then
  begin
    Check(AWork.Units = wuObservations, 'Computed-row units');
    Check(AWork.Total = InferenceCount(GRequest), 'Actual computed-row denominator');
    SawInterior := SawInterior or ((AWork.Done > 0) and (AWork.Done < AWork.Total));
  end
  else if AWork.Stage = 'inference_verify_rows' then
  begin
    Check(AWork.Units = wuObservations, 'Verified-row units');
    Check(AWork.Total = InferenceCount(GRequest), 'Actual verified-row denominator');
  end
  else if (AWork.Stage = 'inference_worker_setup') or
    (AWork.Stage = 'inference_worker_verify_source') then
  begin
    Check((AWork.Done = 0) and (AWork.Total = 0), 'Unknown phase invented a total');
  end;
  if AWork.Stage = CancelStage then
    CancelNow := True;
  if (Marker = nil) or (AWork.Stage <> Stage) then
    Exit;
  case Point of
    spStart: LStop := AWork.Done = 0;
    spInterior: LStop := (AWork.Done > 0) and (AWork.Total > AWork.Done);
    spFinal: LStop := (AWork.Total > 0) and (AWork.Done = AWork.Total);
  end;
  if LStop then
    raise Marker;
end;

function TObserver.Cancelled: Boolean;
begin
  Result := CancelNow;
end;

procedure WriteSource(const AName: String);
var
  LFile: TFileStream;
  LSink: TStreamAudioSink;
  LWriter: TWavePcm16Writer;
  LSamples: TAudioSamples;
  LIndex: Integer;
begin
  SetLength(LSamples, 32000);
  for LIndex := 0 to High(LSamples) do
    LSamples[LIndex] := 0.25 * Sin(2 * Pi * 440 * LIndex / InferenceRate);
  LFile := TFileStream.Create(AName, fmCreate);
  LSink := TStreamAudioSink.Create(LFile);
  LWriter := TWavePcm16Writer.Create(LSink, InferenceRate, 1, Length(LSamples));
  try
    LWriter.AppendSamples(LSamples);
    LWriter.Finish;
  finally
    LWriter.Free;
    LSink.Free;
    LFile.Free;
  end;
end;

{ An actual isolated Pascal process exercises the supervisor protocol and real
  artifact writer. It supplies authored observations, not inference accuracy. }
procedure Worker;
var
  LHandle: THandle;
  LProgress: PInferenceWorkerProgress;
  LWave: TInferenceWaveJob;
  LSink: TInferenceFileSink;
  LRequest: TInferenceRequest;
  LIdentity: TInferenceIdentity;
  LBatch: TInferenceBatch;
  LIndex: Integer;
  LCount: Integer;
  LMode: String;
begin
  LRequest := DefaultInferenceRequest(ParamStr(7), StrToInt64(ParamStr(11)));
  LRequest.Policy := ParamStr(8);
  LRequest.Channel := StrToInt(ParamStr(9));
  LRequest.ScopeStart16k := StrToInt64(ParamStr(10));
  LRequest.InputStart16k := StrToInt64(ParamStr(12));
  LRequest.InputEnd16k := StrToInt64(ParamStr(13));
  LRequest.FirstCenter16k := StrToInt64(ParamStr(14));
  LRequest.Hop16k := StrToInt(ParamStr(15));
  LRequest.BatchSize := StrToInt(ParamStr(16));
  LProgress := nil;
  LHandle := 0;
  LWave := nil;
  LSink := nil;
  try
    LProgress := OpenInferenceProgress(ParamStr(6), LHandle);
    WriteTextFile(ParamStr(5) + '.pid', IntToStr(GetCurrentProcessId));
    LMode := GetEnvironmentVariable('PYTHIAN_TEST_INFERENCE_WORKER');
    PublishInferenceProgress(LProgress, 1, GetTickCount64);
    if LMode = 'stall' then
    begin
      Sleep(10000);
      Exit;
    end;
    LWave := TInferenceWaveJob.Create(ParamStr(4), LRequest);
    LIdentity := LWave.Identity;
    if LMode = 'wrong-identity' then
      LIdentity.Request.SourceHash := StringOfChar('b', 64);
    LSink := TInferenceFileSink.Create(ParamStr(5));
    LSink.Start(LIdentity);
    Sleep(100);
    LCount := 0;
    SetLength(LBatch, 1);
    for LIndex := 0 to LIdentity.ObservationCount - 1 do
    begin
      LBatch[0] := Default(TInferenceObservation);
      LBatch[0].Center16k := LRequest.FirstCenter16k + LIndex * LRequest.Hop16k;
      LBatch[0].AcRms := 0.125;
      LBatch[0].Salience[0] := LIndex / LIdentity.ObservationCount;
      LSink.Append(LBatch);
      Inc(LCount);
      InterlockedExchange64(LProgress^.Completed, LCount);
      PublishInferenceProgress(LProgress, 1, GetTickCount64);
      if LCount mod 32 = 0 then
        Sleep(15);
    end;
    PublishInferenceProgress(LProgress, 2, GetTickCount64);
    Sleep(100);
    LSink.Complete;
    PublishInferenceProgress(LProgress, 3, GetTickCount64);
  finally
    LSink.Free;
    LWave.Free;
    CloseInferenceProgress(LProgress, LHandle);
  end;
end;

procedure CheckCleanup;
var
  LSearch: TSearchRec;
  LName: String;
  LPid: Cardinal;
  LProcess: THandle;
  LText: TStringList;
begin
  if FindFirst(GOutput + '.pending-*', faAnyFile, LSearch) <> 0 then
    Exit;
  try
    repeat
      LName := GDirectory + LSearch.Name;
      Check(ExtractFileExt(LName) = '.pid', 'Provisional artifact leaked: ' + LName);
      LText := TStringList.Create;
      try
        LText.LoadFromFile(LName);
        LPid := StrToInt(Trim(LText.Text));
      finally
        LText.Free;
      end;
      LProcess := OpenProcess(SYNCHRONIZE, False, LPid);
      if LProcess = 0 then
        Check(GetLastError = ERROR_INVALID_PARAMETER, 'Cannot establish worker termination')
      else
      begin
        try
          Check(WaitForSingleObject(LProcess, 0) = WAIT_OBJECT_0, 'Owned worker is still alive');
        finally
          CloseHandle(LProcess);
        end;
      end;
      Check(DeleteFile(LName), 'Cannot remove owned PID marker');
    until FindNext(LSearch) <> 0;
  finally
    FindClose(LSearch);
  end;
end;

function PriorRun: TInferenceRun;
begin
  Result := Default(TInferenceRun);
  Result.Identity := GIdentity;
  Result.Identity.Request.SourceHash := StringOfChar('a', 64);
  Result.ElapsedMs := 789;
  Result.ColdMs := 11;
  Result.SourceSetupMs := 12;
  Result.BackendSetupMs := 13;
  Result.FirstObservationMs := 14;
  Result.WarmObservationMs := 15;
  Result.PeakPrivateBytes := 16;
end;

function RunText(const ARun: TInferenceRun): String;
begin
  Result := InferenceIdentityText(ARun.Identity) + IntToStr(ARun.ElapsedMs) + ':' +
    IntToStr(ARun.ColdMs) + ':' + IntToStr(ARun.SourceSetupMs) + ':' +
    IntToStr(ARun.BackendSetupMs) + ':' + IntToStr(ARun.FirstObservationMs) + ':' +
    IntToStr(ARun.WarmObservationMs) + ':' + IntToStr(ARun.PeakPrivateBytes);
end;

procedure CheckAbort(const AStage: String; const APoint: TStopPoint;
  const ACancel: Boolean = False);
var
  LObserver: TObserver;
  LRun: TInferenceRun;
  LBefore: String;
  LOutputHash: String;
  LStopped: Boolean;
begin
  WriteTextFile(GOutput, 'accepted-before');
  LOutputHash := HashInferenceFile(GOutput);
  LRun := PriorRun;
  LBefore := RunText(LRun);
  LObserver := TObserver.Create;
  try
    if ACancel then
      LObserver.CancelStage := AStage
    else
    begin
      LObserver.Stage := AStage;
      LObserver.Point := APoint;
      LObserver.Marker := Exception.Create('original-progress-marker');
    end;
    LStopped := False;
    try
      LRun := RunInferenceProcess(ParamStr(0), InferenceEstimator, InferencePolicy,
        GSource, GOutput, GRequest, LObserver.Cancelled, LObserver.Observe);
    except
      on LError: Exception do
      begin
        if ACancel then
          Check(LError is EInferenceCancelled, 'Original cancellation class lost')
        else
        begin
          Check(LError = LObserver.Marker, 'Original callback exception lost');
          LObserver.Marker := nil;
        end;
        LStopped := True;
        Inc(GAborts);
      end;
    end;
    Check(LStopped, 'Selected checkpoint did not abort: ' + AStage);
    Check(HashInferenceFile(GOutput) = LOutputHash, 'Abort replaced accepted artifact');
    Check(RunText(LRun) = LBefore, 'Abort published partial run metadata');
    CheckCleanup;
  finally
    LObserver.Free;
  end;
end;

procedure Run;
var
  LObserver: TObserver;
  LRun: TInferenceRun;
  LHash: String;
  LStableHash: String;
  LPoint: TStopPoint;
  LFailed: Boolean;
  LStarted: QWord;
  LOldMode: String;
  LWave: TInferenceWaveJob;
begin
  Check(ParamCount = 1, 'Supply an isolated output directory');
  GDirectory := IncludeTrailingPathDelimiter(ExpandFileName(ParamStr(1)));
  ForceDirectories(GDirectory);
  GSource := GDirectory + 'source.wav';
  GOutput := GDirectory + 'observations.pinf';
  WriteSource(GSource);
  GHash := HashInferenceFile(GSource);
  GRequest := DefaultInferenceRequest(GHash, 32000);
  LWave := TInferenceWaveJob.Create(GSource, GRequest);
  try
    GIdentity := LWave.Identity;
  finally
    LWave.Free;
  end;
  LOldMode := GetEnvironmentVariable('PYTHIAN_TEST_INFERENCE_WORKER');
  SetEnvironmentVariable('PYTHIAN_TEST_INFERENCE_WORKER', 'success');
  try
    LRun := RunInferenceProcess(ParamStr(0), InferenceEstimator, InferencePolicy,
      GSource, GOutput, GRequest);
    Check(LRun.Identity.ObservationCount = 200, 'Exact actual worker row count');
    LHash := HashInferenceFile(GOutput);
    LStableHash := LHash;
    CheckCleanup;
    LObserver := TObserver.Create;
    try
      LRun := RunInferenceProcess(ParamStr(0), InferenceEstimator, InferencePolicy,
        GSource, GOutput, GRequest, nil, LObserver.Observe);
      Check(HashInferenceFile(GOutput) = LHash, 'Observation changed artifact bytes');
      Check(LObserver.SawInterior, 'Actual worker interior count absent');
      Check(LObserver.Stages.Count = 6, 'Actual stage map incomplete');
      Check(LObserver.Stages.IndexOf('inference_publication_ready') = 5,
        'Publication-ready must be the final stage');
      CheckCleanup;
    finally
      LObserver.Free;
    end;
    CheckAbort('inference_worker_setup', spStart);
    CheckAbort('inference_worker_verify_source', spStart);
    for LPoint := Low(TStopPoint) to High(TStopPoint) do
    begin
      CheckAbort('inference_observe_rows', LPoint);
      CheckAbort('verify_audio_bytes', LPoint);
      CheckAbort('inference_verify_rows', LPoint);
    end;
    CheckAbort('inference_publication_ready', spFinal);
    CheckAbort('inference_observe_rows', spStart, True);
    CheckAbort('inference_publication_ready', spFinal, True);
    LHash := HashInferenceFile(GOutput);
    Check((InferenceSetupLimitMs = 30000) and (InferenceStallLimitMs = 5000) and
      (InferencePrivateByteLimit = 2147483648), 'Supervisor limits changed');
    SetEnvironmentVariable('PYTHIAN_TEST_INFERENCE_WORKER', 'stall');
    LFailed := False;
    LStarted := GetTickCount64;
    LObserver := TObserver.Create;
    try
      try
        RunInferenceProcess(ParamStr(0), InferenceEstimator, InferencePolicy,
          GSource, GOutput, GRequest, nil, LObserver.Observe);
      except
        on LError: EAudio do
        begin
          Check(Pos('observing-stall budget exceeded', LError.Message) > 0, 'Wrong stall failure');
          LFailed := True;
        end;
      end;
      Check(LObserver.Stages.IndexOf('inference_observe_rows') >= 0,
        'Stall did not exercise observed worker state');
    finally
      LObserver.Free;
    end;
    Check(LFailed and (GetTickCount64 - LStarted >= 5000), 'Original stall gate weakened');
    Check(HashInferenceFile(GOutput) = LHash, 'Stalled worker replaced accepted artifact');
    CheckCleanup;
    SetEnvironmentVariable('PYTHIAN_TEST_INFERENCE_WORKER', 'wrong-identity');
    LFailed := False;
    try
      RunInferenceProcess(ParamStr(0), InferenceEstimator, InferencePolicy,
        GSource, GOutput, GRequest);
    except
      on LError: EAudio do
      begin
        Check(Pos('identity differs', LError.Message) > 0, 'Wrong identity failure');
        LFailed := True;
      end;
    end;
    Check(LFailed, 'Completed worker bypassed final identity validation');
    Check(HashInferenceFile(GOutput) = LHash, 'Invalid worker replaced accepted artifact');
    CheckCleanup;
    SetEnvironmentVariable('PYTHIAN_TEST_INFERENCE_WORKER', 'success');
    LRun := RunInferenceProcess(ParamStr(0), InferenceEstimator, InferencePolicy,
      GSource, GOutput, GRequest);
    Check(HashInferenceFile(GOutput) = LStableHash, 'Post-abort retry changed artifact');
    CheckCleanup;
    WriteLn('PASS checks=', GChecks, ' original_aborts=', GAborts,
      ' actual worker completion/replay, callback/cancel cleanup and original stall/identity gates');
  finally
    if LOldMode = '' then
      SetEnvironmentVariable('PYTHIAN_TEST_INFERENCE_WORKER', nil)
    else
      SetEnvironmentVariable('PYTHIAN_TEST_INFERENCE_WORKER', PChar(LOldMode));
  end;
end;

begin
  try
    if ParamStr(1) = '--worker' then
      Worker
    else
      Run;
  except
    on LError: Exception do
    begin
      WriteLn(StdErr, LError.ClassName, ': ', LError.Message);
      ExitCode := 1;
    end;
  end;
end.
