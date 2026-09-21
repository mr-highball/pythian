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
program pythian_tests_inference;

{$mode delphi}
{$H+}

uses
  Windows,
  Classes,
  SysUtils,
  Math,
  pythian.audio,
  pythian.wave.stream,
  pythian.wave.read,
  pythian.resample.stream,
  pythian.inference.observation,
  pythian.inference.wave,
  pythian.inference.process,
  pythian.tools.files;

type
  TProbeBackend = class(TInferenceBackend)
    Calls: Integer;
    FailAt: Integer;
    function Activate(const AWindow: TAudioSamples): TPitchSalience; override;
    function EstimatorIdentity: String; override;
  end;
  TCapture = class(TInferenceSink)
    Working: TInferenceBatch;
    Accepted: TInferenceBatch;
    Aborted: Boolean;
    AppendCalls: Integer;
    FailAppend: Boolean;
    procedure Start(const AIdentity: TInferenceIdentity); override;
    procedure Append(const ABatch: TInferenceBatch); override;
    procedure Complete; override;
    procedure Abort; override;
  end;
  TCancelAt = class
    Deadline: QWord;
    Backend: TProbeBackend;
    function Cancelled: Boolean;
  end;

procedure Check(const ACondition: Boolean; const AMessage: String);
begin
  if not ACondition then
  begin
    raise Exception.Create(AMessage);
  end;
end;

function TProbeBackend.Activate(const AWindow: TAudioSamples): TPitchSalience;
var
  I: Integer;
begin
  Inc(Calls);
  if (FailAt > 0) and (Calls = FailAt) then
  begin
    raise EAudio.Create('Injected backend failure');
  end;
  for I := 0 to High(Result) do
  begin
    Result[I] := 0.5 + AWindow[(I * 17) mod 1024] * 0.25;
  end;
end;

function TProbeBackend.EstimatorIdentity: String;
begin
  Result := 'fixture-window-probe-v1';
end;

procedure TCapture.Start(const AIdentity: TInferenceIdentity);
begin
  Working := nil;
  Aborted := False;
  AppendCalls := 0;
  Check(AIdentity.ObservationCount > 0, 'Missing identity count');
end;

procedure TCapture.Append(const ABatch: TInferenceBatch);
var
  LOld: Integer;
  I: Integer;
begin
  Inc(AppendCalls);
  Check((Length(ABatch) >= 1) and (Length(ABatch) <= 32), 'Unbounded delivery');
  if FailAppend then
  begin
    raise EAudio.Create('Injected sink failure');
  end;
  LOld := Length(Working);
  SetLength(Working, LOld + Length(ABatch));
  for I := 0 to High(ABatch) do
  begin
    Working[LOld + I] := ABatch[I];
  end;
end;

procedure TCapture.Complete;
begin
  Accepted := Copy(Working);
  Working := nil;
end;

procedure TCapture.Abort;
begin
  Aborted := True;
  Working := nil;
end;

function TCancelAt.Cancelled: Boolean;
begin
  if Backend <> nil then
  begin
    Result := Backend.Calls >= 7;
  end
  else
  begin
    Result := GetTickCount64 >= Deadline;
  end;
end;

procedure Generate(const AName: String; const ASeconds, ARate, AChannels: Integer);
var
  LStream: TFileStream;
  LSink: TStreamAudioSink;
  LWriter: TWavePcm16Writer;
  LSamples: TAudioSamples;
  LPosition: Int64;
  LCount: Integer;
  LTime: Double;
  LAmplitude: Double;
  I: Integer;
  J: Integer;
begin
  Check((ASeconds > 0) and (ASeconds <= 300), 'Controlled duration outside fixture bound');
  LStream := TFileStream.Create(AName, fmCreate);
  LSink := nil;
  LWriter := nil;
  try
    LSink := TStreamAudioSink.Create(LStream);
    LWriter := TWavePcm16Writer.Create(LSink, ARate, AChannels, Int64(ASeconds) * ARate);
    LPosition := 0;
    while LPosition < Int64(ASeconds) * ARate do
    begin
      LCount := Min(Int64(4096), Int64(ASeconds) * ARate - LPosition);
      SetLength(LSamples, LCount * AChannels);
      for I := 0 to LCount - 1 do
      begin
        LTime := (LPosition + I) / ARate;
        LAmplitude := 0.3;
        if (Trunc(LTime * 4) mod 8) = 3 then
        begin
          LAmplitude := 0;
        end;
        for J := 0 to AChannels - 1 do
        begin
          LSamples[I * AChannels + J] := LAmplitude *
            Sin(2 * Pi * (220 + J * 110) * LTime + 0.17);
        end;
      end;
      LWriter.AppendSamples(LSamples);
      Inc(LPosition, LCount);
    end;
    LWriter.Finish;
  finally
    LWriter.Free;
    LSink.Free;
    LStream.Free;
  end;
end;

procedure EqualObservation(const ALeft, ARight: TInferenceObservation;
  const AMessage: String);
begin
  Check(CompareMem(@ALeft, @ARight, SizeOf(ALeft)), AMessage);
end;

function Capture(const ASource: String; const ARequest: TInferenceRequest): TInferenceBatch;
var
  LJob: TInferenceWaveJob;
  LBackend: TProbeBackend;
  LSink: TCapture;
begin
  LJob := nil;
  LBackend := TProbeBackend.Create;
  LSink := TCapture.Create;
  try
    LJob := TInferenceWaveJob.Create(ASource, ARequest);
    LJob.Execute(LBackend, LSink);
    Result := Copy(LSink.Accepted);
  finally
    LJob.Free;
    LBackend.Free;
    LSink.Free;
  end;
end;

procedure FakeWorker;
var
  LHandle: THandle;
  LProgress: PInferenceWorkerProgress;
  LMemory: Pointer;
begin
  Check(ParamCount = 16, 'Fake worker protocol differs');
  LHandle := 0;
  LProgress := OpenInferenceProgress(ParamStr(6), LHandle);
  try
    LProgress^.Phase := 1;
    LProgress^.Tick := GetTickCount64;
    if ExtractFileName(ParamStr(2)) = 'setup-stall' then
    begin
      LProgress^.Phase := 0;
      Sleep(35000);
      ExitCode := 22;
    end
    else if ExtractFileName(ParamStr(2)) = 'memory-failure' then
    begin
      LMemory := VirtualAlloc(nil, QWord(3) * 1024 * 1024 * 1024,
        MEM_RESERVE or MEM_COMMIT, PAGE_READWRITE);
      if LMemory = nil then
      begin
        ExitCode := 19;
      end
      else
      begin
        VirtualFree(LMemory, 0, MEM_RELEASE);
        ExitCode := 20;
      end;
    end
    else
    begin
      Sleep(10000);
      ExitCode := 21;
    end;
  finally
    CloseInferenceProgress(LProgress, LHandle);
  end;
end;

procedure SupervisorControls(const ASource, AOutput: String);
var
  LRequest: TInferenceRequest;
  LBefore: String;
  LFailed: Boolean;
  LMessage: String;
  LCancel: TCancelAt;
  LStarted: QWord;
  I: Integer;
begin
  LRequest := DefaultInferenceRequest(HashInferenceFile(ASource), 32000);
  WriteTextFile(AOutput, 'previous accepted output');
  LBefore := HashInferenceFile(AOutput);
  LCancel := TCancelAt.Create;
  try
    for I := 0 to 3 do
    begin
      LFailed := False;
      LMessage := '';
      LStarted := GetTickCount64;
      try
        if I = 0 then
        begin
          RunInferenceProcess(ParamStr(0), 'memory-failure', '.', ASource, AOutput, LRequest);
        end
        else if I = 1 then
        begin
          RunInferenceProcess(ParamStr(0), 'stall', '.', ASource, AOutput, LRequest);
        end
        else if I = 2 then
        begin
          LCancel.Deadline := GetTickCount64 + 200;
          RunInferenceProcess(ParamStr(0), 'stall', '.', ASource, AOutput,
            LRequest, LCancel.Cancelled);
        end
        else
        begin
          RunInferenceProcess(ParamStr(0), 'setup-stall', '.', ASource, AOutput, LRequest);
        end;
      except
        on LError: EAudio do
        begin
          LFailed := True;
          LMessage := LError.Message;
        end;
      end;
      Check(LFailed, 'Worker memory/stall/cancellation case did not fail');
      if I = 0 then
      begin
        Check(Pos('exit 19', LMessage) > 0, 'OS job did not reject excessive commitment');
      end;
      if I = 1 then
      begin
        Check((Pos('observing-stall budget', LMessage) > 0) and
          (Pos('phase=observing', LMessage) > 0) and (Pos('limit_ms=5000', LMessage) > 0),
          'Worker stall diagnostic omitted its exact boundary');
      end;
      if I = 3 then
      begin
        Check((Pos('setup budget', LMessage) > 0) and (Pos('phase=setup', LMessage) > 0) and
          (Pos('limit_ms=30000', LMessage) > 0) and
          (Pos('source_ready=0', LMessage) > 0) and (Pos('runtime_ready=0', LMessage) > 0),
          'Setup timeout diagnostic omitted phase, limit or lane state');
      end;
      if I = 2 then
      begin
        Check(GetTickCount64 - LStarted <= 2200, 'Hard cancellation exceeded bound');
      end;
      Check(HashInferenceFile(AOutput) = LBefore, 'Failed supervisor replaced accepted output');
    end;
  finally
    LCancel.Free;
  end;
end;

procedure SinkOwnership(const APrefix: String; const AIdentity: TInferenceIdentity);
var
  LFirst: TInferenceFileSink;
  LSecond: TInferenceFileSink;
  LLock: TFileStream;
  LBatch: TInferenceBatch;
  LPath: String;
  LBefore: String;
  LFailed: Boolean;
  I: Int64;
begin
  LPath := APrefix + '-ownership.pinf';
  SysUtils.DeleteFile(LPath);
  LFirst := TInferenceFileSink.Create(LPath);
  LSecond := nil;
  try
    LSecond := TInferenceFileSink.Create(LPath);
    LFirst.Start(AIdentity);
    SetLength(LBatch, 1);
    LBatch[0] := Default(TInferenceObservation);
    for I := 0 to AIdentity.ObservationCount - 1 do
    begin
      LBatch[0].Center16k := AIdentity.Request.FirstCenter16k + I * AIdentity.Request.Hop16k;
      LFirst.Append(LBatch);
    end;
    LFirst.Complete;
    LBefore := HashInferenceFile(LPath);
    LFailed := False;
    try
      LSecond.Start(AIdentity);
    except
      on Exception do
      begin
        LFailed := True;
      end;
    end;
    FreeAndNil(LSecond);
    Check(LFailed, 'Second constructed sink truncated a completed artifact');
    Check(HashInferenceFile(LPath) = LBefore, 'Collision changed completed bytes');
  finally
    LSecond.Free;
    LFirst.Free;
  end;

  LPath := APrefix + '-failed-start.pinf';
  SysUtils.DeleteFile(LPath);
  LFirst := TInferenceFileSink.Create(LPath);
  LLock := nil;
  try
    { The file arrives after construction. An exclusive external handle forces
      even a truncating implementation's open to fail; release it before the
      failed sink destructor to expose deletion of a file it never owned. }
    WriteTextFile(LPath, 'external bytes must survive failed open');
    LBefore := HashInferenceFile(LPath);
    LLock := TFileStream.Create(LPath, fmOpenRead or fmShareExclusive);
    LFailed := False;
    try
      LFirst.Start(AIdentity);
    except
      on Exception do
      begin
        LFailed := True;
      end;
    end;
    FreeAndNil(LLock);
    FreeAndNil(LFirst);
    Check(LFailed, 'Start unexpectedly opened an externally owned file');
    Check(HashInferenceFile(LPath) = LBefore, 'Failed-start destructor deleted external bytes');
  finally
    LLock.Free;
    LFirst.Free;
  end;

  LPath := APrefix + '-aborted-owner.pinf';
  SysUtils.DeleteFile(LPath);
  LFirst := TInferenceFileSink.Create(LPath);
  try
    LFirst.Start(AIdentity);
    LFirst.Abort;
    Check(not FileExists(LPath), 'Owned incomplete file was not removed');
    WriteTextFile(LPath, 'replacement after ownership ended');
    LBefore := HashInferenceFile(LPath);
    LFirst.Abort;
    FreeAndNil(LFirst);
    Check(HashInferenceFile(LPath) = LBefore, 'Repeated abort deleted a later owner file');
  finally
    LFirst.Free;
  end;
end;

procedure Contract(const APrefix: String);
const
  CRates: array[0..2] of Integer = (16000, 44100, 48000);
var
  LRequest: TInferenceRequest;
  LBad: TInferenceRequest;
  LWhole: TInferenceBatch;
  LSplit: TInferenceBatch;
  LSource: String;
  LJob: TInferenceWaveJob;
  LBackend: TProbeBackend;
  LSink: TCapture;
  LFileSink: TInferenceFileSink;
  LReader: TInferenceFileReader;
  LIdentity: TInferenceIdentity;
  LCancel: TCancelAt;
  LFailed: Boolean;
  LBytes: TAudioBytes;
  I: Integer;
  J: Integer;
  K: Integer;
begin
  for I := 0 to High(CRates) do
  begin
    for J := 1 to 2 do
    begin
      LSource := APrefix + '-' + IntToStr(CRates[I]) + '-' + IntToStr(J) + '.wav';
      Generate(LSource, 2, CRates[I], J);
      LRequest := DefaultInferenceRequest(HashInferenceFile(LSource), 32000);
      LRequest.Channel := J - 1;
      LWhole := Capture(LSource, LRequest);
      LRequest.BatchSize := 1;
      LSplit := Capture(LSource, LRequest);
      Check(Length(LWhole) = 200, 'Dense observation count differs');
      for K := 0 to High(LWhole) do
      begin
        EqualObservation(LWhole[K], LSplit[K], 'Batch size changed measurements');
      end;
      LRequest.ScopeStart16k := 16000;
      LRequest.FirstCenter16k := 16000;
      LSplit := Capture(LSource, LRequest);
      Check(Length(LSplit) = 100, 'Internal scope count differs');
      for K := 0 to High(LSplit) do
      begin
        EqualObservation(LWhole[K + 100], LSplit[K], 'Internal scope lost actual source halo');
      end;
    end;
  end;
  LRequest := DefaultInferenceRequest(HashInferenceFile(LSource), 32000);
  LBad := LRequest;
  LBad.Policy := 'changed-policy';
  LFailed := False;
  try
    ValidateInferenceRequest(LBad);
  except
    on EAudio do
    begin
      LFailed := True;
    end;
  end;
  Check(LFailed, 'Changed policy admitted');
  LBad := LRequest;
  LBad.Hop16k := 159;
  LFailed := False;
  try
    ValidateInferenceRequest(LBad);
  except
    on EAudio do
    begin
      LFailed := True;
    end;
  end;
  Check(LFailed, 'Excess observation density admitted');
  LBad := LRequest;
  LBad.SourceHash[1] := '0';
  if LBad.SourceHash = LRequest.SourceHash then
  begin
    LBad.SourceHash[1] := '1';
  end;
  LFailed := False;
  LJob := nil;
  try
    LJob := TInferenceWaveJob.Create(LSource, LBad);
  except
    on EAudio do
    begin
      LFailed := True;
    end;
  end;
  LJob.Free;
  Check(LFailed, 'Changed source admitted');
  LBackend := TProbeBackend.Create;
  LSink := TCapture.Create;
  LCancel := TCancelAt.Create;
  try
    LJob := TInferenceWaveJob.Create(LSource, LRequest);
    try
      LJob.Execute(LBackend, LSink);
    finally
      LJob.Free;
    end;
    LWhole := Copy(LSink.Accepted);
    for I := 0 to 2 do
    begin
      LBackend.Calls := 0;
      LBackend.FailAt := 0;
      LSink.FailAppend := I = 1;
      if I = 0 then
      begin
        LBackend.FailAt := 8;
      end;
      LJob := TInferenceWaveJob.Create(LSource, LRequest);
      LFailed := False;
      try
        try
          if I = 2 then
          begin
            LCancel.Backend := LBackend;
            LJob.Execute(LBackend, LSink, LCancel.Cancelled);
          end
          else
          begin
            LJob.Execute(LBackend, LSink);
          end;
        except
          on EAudio do
          begin
            LFailed := True;
          end;
        end;
        Check(LFailed and LSink.Aborted, 'Failure/cancel did not abort sink');
        Check(Length(LSink.Accepted) = Length(LWhole), 'Prior accepted output changed');
        for K := 0 to High(LWhole) do
        begin
          EqualObservation(LWhole[K], LSink.Accepted[K], 'Rollback changed accepted observation');
        end;
      finally
        LJob.Free;
      end;
    end;
    LBackend.FailAt := 0;
    LBackend.Calls := 0;
    LJob := TInferenceWaveJob.Create(LSource, LRequest);
    LFileSink := nil;
    try
      SysUtils.DeleteFile(APrefix + '.pinf');
      LFileSink := TInferenceFileSink.Create(APrefix + '.pinf');
      LJob.Execute(LBackend, LFileSink);
      LIdentity := LJob.Identity;
    finally
      LFileSink.Free;
      LJob.Free;
    end;
    LReader := TInferenceFileReader.Create(APrefix + '.pinf', LIdentity);
    try
      K := 0;
      repeat
        LSplit := LReader.ReadBatch;
        for I := 0 to High(LSplit) do
        begin
          EqualObservation(LWhole[K], LSplit[I], 'Artifact replay differs');
          Inc(K);
        end;
      until Length(LSplit) = 0;
      Check(K = Length(LWhole), 'Artifact replay missing rows');
    finally
      LReader.Free;
    end;
    LIdentity.Estimator := InferenceEstimator;
    LReader := nil;
    LFailed := False;
    try
      LReader := TInferenceFileReader.Create(APrefix + '.pinf', LIdentity);
    except
      on EAudio do
      begin
        LFailed := True;
      end;
    end;
    LReader.Free;
    Check(LFailed, 'Custom backend artifact masqueraded as pinned estimator');
    LIdentity.Estimator := LBackend.EstimatorIdentity;
    LBytes := ReadFileBytes(APrefix + '.pinf', 1024 * 1024);
    LBytes[High(LBytes)] := LBytes[High(LBytes)] xor 1;
    WriteFileBytes(APrefix + '-damaged.pinf', LBytes);
    LReader := nil;
    LFailed := False;
    try
      LReader := TInferenceFileReader.Create(APrefix + '-damaged.pinf', LIdentity);
    except
      on EAudio do
      begin
        LFailed := True;
      end;
    end;
    LReader.Free;
    Check(LFailed, 'Damaged checksum admitted');
    SetLength(LBytes, Length(LBytes) - 64);
    WriteFileBytes(APrefix + '-incomplete.pinf', LBytes);
    LReader := nil;
    LFailed := False;
    try
      LReader := TInferenceFileReader.Create(APrefix + '-incomplete.pinf', LIdentity);
    except
      on EAudio do
      begin
        LFailed := True;
      end;
    end;
    LReader.Free;
    Check(LFailed, 'Incomplete artifact admitted');
  finally
    LCancel.Free;
    LSink.Free;
    LBackend.Free;
  end;
  SinkOwnership(APrefix, LIdentity);
  SupervisorControls(LSource, APrefix + '-supervisor.pinf');
  WriteLn('PASS contract: rates/channels, exact batches/halos, identity, failure/cancel rollback, artifact integrity, worker memory/stall/cancel');
end;

procedure StartupChecks(const AModel, ARuntime, AWorker, APrefix,
  ALongSource, ALongHash: String);
var
  LSource: String;
  LOutput: String;
  LBefore: String;
  LRequest: TInferenceRequest;
  LBad: TInferenceRequest;
  LRun: TInferenceRun;
  LFailed: Boolean;
  LCancel: TCancelAt;
  LStarted: QWord;
  LStream: TFileStream;
  LWave: TWaveFrameReader;
  LEnd: Int64;
begin
  { Reuse the previously qualified final matrix case; do not regenerate its
    source or repeat the rate matrix/recorded arithmetic sweeps. }
  LSource := APrefix + '-48000-2.wav';
  LOutput := APrefix + '-startup.pinf';
  LBefore := HashInferenceFile(LSource + '.pinf');
  LRequest := DefaultInferenceRequest(HashInferenceFile(LSource), 480000);
  LRequest.Channel := 1;
  LRun := RunInferenceProcess(AWorker, AModel, ARuntime, LSource, LOutput, LRequest);
  Check(HashInferenceFile(LOutput) = LBefore, 'Parallel startup changed qualified artifact bytes');
  WriteLn('STARTUP total_ms=', LRun.ElapsedMs, ' cold_ms=', LRun.ColdMs,
    ' source_setup_ms=', LRun.SourceSetupMs, ' runtime_setup_ms=', LRun.RuntimeSetupMs,
    ' peak_private_bytes=', LRun.PeakPrivateBytes);
  LBad := LRequest;
  LBad.SourceHash[1] := '0';
  if LBad.SourceHash = LRequest.SourceHash then
  begin
    LBad.SourceHash[1] := '1';
  end;
  LFailed := False;
  try
    RunInferenceProcess(AWorker, AModel, ARuntime, LSource, LOutput, LBad);
  except
    on LError: EAudio do
    begin
      LFailed := Pos('Source initialization failed:', LError.Message) > 0;
    end;
  end;
  Check(LFailed, 'Parallel source initialization failure was not propagated');
  Check(HashInferenceFile(LOutput) = LBefore, 'Failed source initialization changed accepted bytes');
  LFailed := False;
  try
    RunInferenceProcess(AWorker, AModel + '-missing', ARuntime, LSource, LOutput, LRequest);
  except
    on EAudio do
    begin
      LFailed := True;
    end;
  end;
  Check(LFailed, 'Parallel runtime initialization failure was not propagated');
  Check(HashInferenceFile(LOutput) = LBefore, 'Failed runtime initialization changed accepted bytes');
  LStream := TFileStream.Create(ALongSource, fmOpenRead or fmShareDenyWrite);
  LWave := nil;
  try
    LWave := TWaveFrameReader.Create(LStream);
    LEnd := StreamResampleFrameCount(LWave.FrameCount, LWave.SampleRate, InferenceRate);
  finally
    LWave.Free;
    LStream.Free;
  end;
  LRequest := DefaultInferenceRequest(ALongHash, Min(LEnd, Int64(3600) * InferenceRate));
  LRequest.InputEnd16k := LEnd;
  LCancel := TCancelAt.Create;
  try
    LStarted := GetTickCount64;
    LCancel.Deadline := LStarted + 200;
    LFailed := False;
    try
      RunInferenceProcess(AWorker, AModel, ARuntime, ALongSource, LOutput,
        LRequest, LCancel.Cancelled);
    except
      on EInferenceCancelled do
      begin
        LFailed := True;
      end;
    end;
    Check(LFailed, 'Concurrent source/runtime setup was not cancelled');
    Check(GetTickCount64 - LStarted <= 2200, 'Parallel-setup cancellation exceeded two seconds');
    Check(HashInferenceFile(LOutput) = LBefore, 'Parallel-setup cancellation changed accepted bytes');
  finally
    LCancel.Free;
  end;
  WriteLn('PASS startup: exact prior bytes, both initialization failures, long-source startup cancellation');
end;

procedure RuntimeChecks(const AModel, ARuntime, AWorker, APrefix: String);
const
  CRates: array[0..2] of Integer = (16000, 44100, 48000);
var
  LSource: String;
  LOutput: String;
  LRequest: TInferenceRequest;
  LRun: TInferenceRun;
  LFirstHash: String;
  LCancel: TCancelAt;
  LFailed: Boolean;
  LStarted: QWord;
  I: Integer;
  J: Integer;
begin
  for I := 0 to High(CRates) do
  begin
    for J := 1 to 2 do
    begin
      LSource := APrefix + '-' + IntToStr(CRates[I]) + '-' + IntToStr(J) + '.wav';
      LOutput := LSource + '.pinf';
      Generate(LSource, 30, CRates[I], J);
      LRequest := DefaultInferenceRequest(HashInferenceFile(LSource), 480000);
      LRequest.Channel := J - 1;
      LRun := RunInferenceProcess(AWorker, AModel, ARuntime, LSource, LOutput, LRequest);
      WriteLn('RUNTIME rate=', CRates[I], ' channels=', J, ' total_ms=', LRun.ElapsedMs,
        ' cold_ms=', LRun.ColdMs, ' first_ms=', LRun.FirstObservationMs,
        ' warm_ms=', LRun.WarmObservationMs, ' peak_private_bytes=', LRun.PeakPrivateBytes);
    end;
  end;
  LFirstHash := HashInferenceFile(LOutput);
  LFailed := False;
  try
    RunInferenceProcess(AWorker, AModel + '-missing', ARuntime, LSource, LOutput, LRequest);
  except
    on EAudio do
    begin
      LFailed := True;
    end;
  end;
  Check(LFailed, 'Missing pinned model assets were accepted');
  Check(HashInferenceFile(LOutput) = LFirstHash, 'Asset rejection replaced accepted output');
  LRequest.BatchSize := 1;
  RunInferenceProcess(AWorker, AModel, ARuntime, LSource, LOutput, LRequest);
  Check(HashInferenceFile(LOutput) = LFirstHash, 'Actual runtime batch replay differs');
  LCancel := TCancelAt.Create;
  try
    LCancel.Deadline := GetTickCount64 + 200;
    LStarted := GetTickCount64;
    LFailed := False;
    try
      RunInferenceProcess(AWorker, AModel, ARuntime, LSource, LOutput, LRequest, LCancel.Cancelled);
    except
      on EInferenceCancelled do
      begin
        LFailed := True;
      end;
    end;
    Check(LFailed, 'Supervised cancellation did not report cancellation');
    Check(GetTickCount64 - LStarted <= 2200, 'Supervised cancellation exceeded two seconds');
    Check(HashInferenceFile(LOutput) = LFirstHash, 'Cancelled worker replaced accepted output');
  finally
    LCancel.Free;
  end;
  WriteLn('PASS runtime: resources, batch replay, hard cancellation and accepted-output preservation');
end;

{ Diagnostic centroid in cents of the local nine-bin peak. This comparison is
  numerical fidelity, not musical note/confidence admission. The constant offset
  cancels in paired differences, so compare weighted bin indices *20 cents. }
function LocalCents(const AScores: TPitchSalience; out APeak: Integer): Double;
var
  LSum: Double;
  LWeight: Double;
  I: Integer;
begin
  APeak := 0;
  for I := 1 to High(AScores) do
  begin
    if AScores[I] > AScores[APeak] then
    begin
      APeak := I;
    end;
  end;
  LSum := 0;
  LWeight := 0;
  for I := Max(0, APeak - 4) to Min(359, APeak + 4) do
  begin
    LSum := LSum + AScores[I] * I * 20;
    LWeight := LWeight + AScores[I];
  end;
  if LWeight > 0 then
  begin
    Result := LSum / LWeight;
  end
  else
  begin
    Result := 0;
  end;
end;

procedure CompareReference;
var
  LRequest: TInferenceRequest;
  LJob: TInferenceWaveJob;
  LReader: TInferenceFileReader;
  LRaw: TFileStream;
  LBatch: TInferenceBatch;
  LExpected: TInferenceObservation;
  LCount: Int64;
  LRows: Int64;
  LMaximum: Double;
  LCents: Double;
  LCurrent: Double;
  LPeakA: Integer;
  LPeakB: Integer;
  LChanges: Integer;
  I: Integer;
  J: Integer;
begin
  Check(ParamCount = 10, 'compare SOURCE SHA256 ARTIFACT RAW RAW_SHA FIRST COUNT INPUT_END HOP');
  LCount := StrToInt64(ParamStr(8));
  LRequest := DefaultInferenceRequest(ParamStr(3), StrToInt64(ParamStr(9)));
  LRequest.FirstCenter16k := StrToInt64(ParamStr(7));
  LRequest.Hop16k := StrToInt(ParamStr(10));
  LRequest.ScopeEnd16k := LRequest.FirstCenter16k + LCount * LRequest.Hop16k;
  Check(HashInferenceFile(ParamStr(5)) = ParamStr(6), 'Reference raw SHA256 differs');
  LJob := TInferenceWaveJob.Create(ParamStr(2), LRequest);
  LReader := nil;
  LRaw := nil;
  try
    LReader := TInferenceFileReader.Create(ParamStr(4), LJob.Identity);
    LRaw := TFileStream.Create(ParamStr(5), fmOpenRead or fmShareDenyWrite);
    Check(LRaw.Size = LCount * SizeOf(LExpected), 'Reference raw size differs');
    LMaximum := 0;
    LCents := 0;
    LChanges := 0;
    LRows := 0;
    repeat
      LBatch := LReader.ReadBatch;
      for I := 0 to High(LBatch) do
      begin
        LRaw.ReadBuffer(LExpected, SizeOf(LExpected));
        ValidateInferenceObservation(LExpected);
        Check(LBatch[I].Center16k = LExpected.Center16k, 'Reference center mismatch');
        Check(Abs(LBatch[I].AcRms - LExpected.AcRms) <= 1e-12, 'Reference input RMS mismatch');
        for J := 0 to 359 do
        begin
          LCurrent := LExpected.Salience[J];
          LCurrent := Abs(LBatch[I].Salience[J] - LCurrent);
          LMaximum := Max(LMaximum, LCurrent);
        end;
        LCurrent := Abs(LocalCents(LBatch[I].Salience, LPeakA) -
          LocalCents(LExpected.Salience, LPeakB));
        LCents := Max(LCents, LCurrent);
        if LPeakA <> LPeakB then
        begin
          Inc(LChanges);
        end;
        Inc(LRows);
      end;
    until Length(LBatch) = 0;
    WriteLn('FIDELITY rows=', LRows, ' max_activation=', LMaximum:0:12,
      ' max_cents=', LCents:0:12, ' peak_changes=', LChanges);
    Check((LRows = LCount) and (LMaximum <= 0.0002) and (LCents <= 0.5),
      'Declared numerical fidelity tolerance exceeded');
  finally
    LRaw.Free;
    LReader.Free;
    LJob.Free;
  end;
end;

begin
  try
    if ParamStr(1) = '--worker' then
    begin
      FakeWorker;
    end
    else if (ParamStr(1) = 'contract') and (ParamCount = 2) then
    begin
      Contract(ParamStr(2));
    end
    else if (ParamStr(1) = 'runtime') and (ParamCount = 5) then
    begin
      RuntimeChecks(ParamStr(2), ParamStr(3), ParamStr(4), ParamStr(5));
    end
    else if (ParamStr(1) = 'startup') and (ParamCount = 7) then
    begin
      StartupChecks(ParamStr(2), ParamStr(3), ParamStr(4), ParamStr(5), ParamStr(6), ParamStr(7));
    end
    else if (ParamStr(1) = 'diagnostics') and (ParamCount = 3) then
    begin
      SupervisorControls(ParamStr(2), ParamStr(3));
      WriteLn('PASS exact setup/stall boundary diagnostics and process cancellation/memory');
    end
    else if (ParamStr(1) = 'generate') and (ParamCount = 5) then
    begin
      Generate(ParamStr(2), StrToInt(ParamStr(3)), StrToInt(ParamStr(4)), StrToInt(ParamStr(5)));
      WriteLn('source_sha256=', HashInferenceFile(ParamStr(2)));
    end
    else if ParamStr(1) = 'compare' then
    begin
      CompareReference;
    end
    else
    begin
      raise Exception.Create('Expected contract PREFIX; runtime MODEL RUNTIME WORKER PREFIX; ' +
        'generate WAV SECONDS RATE CHANNELS; or compare SOURCE SHA ARTIFACT RAW RAW_SHA FIRST COUNT INPUT_END HOP');
    end;
  except
    on LError: Exception do
    begin
      WriteLn(StdErr, LError.ClassName, ': ', LError.Message);
      ExitCode := 1;
    end;
  end;
end.
