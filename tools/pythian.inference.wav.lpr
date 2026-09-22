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
program pythian_inference_wav;

{$mode delphi}
{$H+}

uses
  Windows,
  Classes,
  SysUtils,
  fpjson,
  pythian.inference.observation,
  pythian.inference.native,
  pythian.inference.wave,
  pythian.inference.process,
  pythian.tools.files;

type
  { The source is an immutable input. An initialization thread verifies and
    prepares it while the Pascal backend is constructed; it never infers. }
  TSourceInitialization = class(TThread)
  private
    FName: String;
    FRequest: TInferenceRequest;
    FProgress: PInferenceWorkerProgress;
  protected
    procedure Execute; override;
  public
    Job: TInferenceWaveJob;
    Failure: String;
    constructor Create(const AName: String; const ARequest: TInferenceRequest;
      const AProgress: PInferenceWorkerProgress);
  end;
  TWorkerMonitor = class
  private
    FObservationStart: QWord;
    FFirstDone: QWord;
  public
    Progress: PInferenceWorkerProgress;
    procedure Update(const APhase: String; const ACompleted: Int64);
  end;
  TConsoleCancellation = class
  public
    function Cancelled: Boolean;
  end;

var
  GCancelled: LongInt = 0;

constructor TSourceInitialization.Create(const AName: String;
  const ARequest: TInferenceRequest; const AProgress: PInferenceWorkerProgress);
begin
  inherited Create(True);
  FreeOnTerminate := False;
  FName := AName;
  FRequest := ARequest;
  FProgress := AProgress;
  Start;
end;

procedure TSourceInitialization.Execute;
var
  LStarted: QWord;
begin
  LStarted := GetTickCount64;
  try
    Job := TInferenceWaveJob.Create(FName, FRequest);
    FProgress^.SourceSetupMs := GetTickCount64 - LStarted;
    InterlockedExchange(FProgress^.SourceReady, 1);
  except
    on LError: Exception do
    begin
      Failure := LError.ClassName + ': ' + LError.Message;
      FProgress^.SourceSetupMs := GetTickCount64 - LStarted;
      InterlockedExchange(FProgress^.SourceReady, -1);
    end;
  end;
end;

function ConsoleHandler(AEvent: DWORD): BOOL; stdcall;
begin
  Result := (AEvent = CTRL_C_EVENT) or (AEvent = CTRL_BREAK_EVENT) or
    (AEvent = CTRL_CLOSE_EVENT);
  if Result then
  begin
    InterlockedExchange(GCancelled, 1);
  end;
end;

function TConsoleCancellation.Cancelled: Boolean;
begin
  Result := InterlockedCompareExchange(GCancelled, 0, 0) <> 0;
end;

procedure TWorkerMonitor.Update(const APhase: String; const ACompleted: Int64);
begin
  Progress^.Completed := ACompleted;
  if APhase = 'verifying' then
  begin
    Progress^.WarmObservationMs := GetTickCount64 - FFirstDone;
    PublishInferenceProgress(Progress, 2, GetTickCount64);
  end
  else
  begin
    if ACompleted = 0 then
    begin
      FObservationStart := GetTickCount64;
    end
    else if ACompleted = 1 then
    begin
      FFirstDone := GetTickCount64;
      Progress^.FirstObservationMs := FFirstDone - FObservationStart;
    end;
    PublishInferenceProgress(Progress, 1, GetTickCount64);
  end;
end;

function ReadRequest(const AWorker: Boolean): TInferenceRequest;
var
  LFirst: Integer;
begin
  Result := Default(TInferenceRequest);
  Result.Policy := InferencePolicy;
  if AWorker then
  begin
    Result.SourceHash := ParamStr(7);
    Result.Policy := ParamStr(8);
    LFirst := 9;
  end
  else
  begin
    Result.SourceHash := ParamStr(4);
    LFirst := 5;
  end;
  Result.Channel := StrToInt(ParamStr(LFirst));
  Result.ScopeStart16k := StrToInt64(ParamStr(LFirst + 1));
  Result.ScopeEnd16k := StrToInt64(ParamStr(LFirst + 2));
  Result.InputStart16k := StrToInt64(ParamStr(LFirst + 3));
  Result.InputEnd16k := StrToInt64(ParamStr(LFirst + 4));
  Result.FirstCenter16k := StrToInt64(ParamStr(LFirst + 5));
  Result.Hop16k := StrToInt(ParamStr(LFirst + 6));
  Result.BatchSize := StrToInt(ParamStr(LFirst + 7));
  ValidateInferenceRequest(Result);
end;

procedure Worker;
var
  LMapping: THandle;
  LMonitor: TWorkerMonitor;
  LBackend: TNativeInferenceBackend;
  LWave: TInferenceWaveJob;
  LSink: TInferenceFileSink;
  LStarted: QWord;
  LBackendStarted: QWord;
  LSource: TSourceInitialization;
begin
  if ParamCount <> 16 then
  begin
    raise Exception.Create('Invalid dedicated worker argument count');
  end;
  if (ParamStr(2) <> InferenceEstimator) or
    (ParamStr(3) <> InferencePolicy) then
  begin
    raise Exception.Create('Dedicated worker producer identity differs');
  end;
  LMapping := 0;
  LBackend := nil;
  LWave := nil;
  LSink := nil;
  LSource := nil;
  LMonitor := TWorkerMonitor.Create;
  try
    LStarted := GetTickCount64;
    LMonitor.Progress := OpenInferenceProgress(ParamStr(6), LMapping);
    LSource := TSourceInitialization.Create(ParamStr(4), ReadRequest(True), LMonitor.Progress);
    LBackendStarted := GetTickCount64;
    try
      LBackend := TNativeInferenceBackend.Create;
      if LBackend.EstimatorIdentity <> InferenceEstimator then
      begin
        raise Exception.Create('Pascal backend estimator identity differs');
      end;
      LMonitor.Progress^.BackendSetupMs := GetTickCount64 - LBackendStarted;
      InterlockedExchange(LMonitor.Progress^.BackendReady, 1);
    except
      LMonitor.Progress^.BackendSetupMs := GetTickCount64 - LBackendStarted;
      InterlockedExchange(LMonitor.Progress^.BackendReady, -1);
      raise;
    end;
    LSource.WaitFor;
    if LSource.Failure <> '' then
    begin
      raise Exception.Create('Source initialization failed: ' + LSource.Failure);
    end;
    LWave := LSource.Job;
    LSource.Job := nil;
    FreeAndNil(LSource);
    LSink := TInferenceFileSink.Create(ParamStr(5));
    LMonitor.Progress^.ColdMs := GetTickCount64 - LStarted;
    LMonitor.Update('observing', 0);
    LWave.Execute(LBackend, LSink, nil, LMonitor.Update);
    { Destruction is part of successful worker completion and its time budget. }
    FreeAndNil(LSink);
    FreeAndNil(LBackend);
    FreeAndNil(LWave);
    PublishInferenceProgress(LMonitor.Progress, 3, GetTickCount64);
  finally
    if LSource <> nil then
    begin
      LSource.WaitFor;
      LSource.Job.Free;
      LSource.Free;
    end;
    LSink.Free;
    LBackend.Free;
    LWave.Free;
    CloseInferenceProgress(LMonitor.Progress, LMapping);
    LMonitor.Free;
  end;
end;

procedure Measure;
var
  LCancel: TConsoleCancellation;
  LRun: TInferenceRun;
  LReport: TJSONObject;
begin
  if ParamCount <> 12 then
  begin
    raise Exception.Create('Usage: inference.wav measure ' +
      'SOURCE.wav OUTPUT.pinf SOURCE_SHA256 CHANNEL SCOPE_START16K SCOPE_END16K ' +
      'INPUT_START16K INPUT_END16K FIRST_CENTER16K HOP16K BATCH_SIZE');
  end;
  LCancel := TConsoleCancellation.Create;
  LReport := TJSONObject.Create;
  try
    SetConsoleCtrlHandler(@ConsoleHandler, True);
    LRun := RunInferenceProcess(ParamStr(0), InferenceEstimator, InferencePolicy,
      ParamStr(2), ParamStr(3), ReadRequest(False), LCancel.Cancelled);
    LReport.Add('status', 'complete');
    LReport.Add('policy', InferencePolicy);
    LReport.Add('source_sha256', LRun.Identity.Request.SourceHash);
    LReport.Add('estimator', LRun.Identity.Estimator);
    LReport.Add('source_rate', LRun.Identity.SourceRate);
    LReport.Add('source_channels', LRun.Identity.SourceChannels);
    LReport.Add('source_frames', LRun.Identity.SourceFrames);
    LReport.Add('observations', LRun.Identity.ObservationCount);
    LReport.Add('cold_setup_ms', Int64(LRun.ColdMs));
    LReport.Add('source_setup_ms', Int64(LRun.SourceSetupMs));
    LReport.Add('backend_setup_ms', Int64(LRun.BackendSetupMs));
    LReport.Add('first_observation_ms', Int64(LRun.FirstObservationMs));
    LReport.Add('warm_observation_ms', Int64(LRun.WarmObservationMs));
    LReport.Add('total_ms', Int64(LRun.ElapsedMs));
    LReport.Add('worker_peak_private_bytes', Int64(LRun.PeakPrivateBytes));
    LReport.Add('admission', 'Raw observations only; no admitted notes or confidence calibration');
    WriteLn(LReport.FormatJSON);
  finally
    SetConsoleCtrlHandler(@ConsoleHandler, False);
    LReport.Free;
    LCancel.Free;
  end;
end;

begin
  try
    if ParamStr(1) = '--worker' then
    begin
      Worker;
    end
    else if ParamStr(1) = 'measure' then
    begin
      Measure;
    end
    else
    begin
      raise Exception.Create('Expected measure; use documented explicit source/policy arguments');
    end;
  except
    on LError: Exception do
    begin
      if (ParamStr(1) = '--worker') and (ParamCount = 16) then
      begin
        try
          WriteTextFile(ParamStr(5) + '.error', Copy(LError.ClassName + ': ' + LError.Message, 1, 4000));
        except
          { Preserve the original failure exit if diagnostic storage also fails. }
        end;
      end;
      WriteLn(StdErr, LError.ClassName, ': ', LError.Message);
      ExitCode := 1;
    end;
  end;
end.
