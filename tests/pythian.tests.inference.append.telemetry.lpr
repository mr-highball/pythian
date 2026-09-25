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
program pythian_tests_inference_append_telemetry;

{$mode delphi}
{$H+}

uses
  Classes,
  SysUtils,
  pythian.audio,
  pythian.inference.observation,
  pythian.inference.process;

const
  CRoot = 'build/inference-append-telemetry';
  CSourceHash = 'dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd';

type
  TProbeFileSink = class(TInferenceFileSink)
  public
    Progress: PInferenceWorkerProgress;
    StartCountSeen, CompleteCountSeen: Int64;
    StartRowsSeen: Int64;
    StartTickSeen: QWord;
    procedure Append(const ABatch: TInferenceBatch); override;
  end;

procedure Check(const ACondition: Boolean; const AMessage: String);
begin
  if not ACondition then
    raise EAudio.Create(AMessage);
end;

procedure TProbeFileSink.Append(const ABatch: TInferenceBatch);
begin
  StartCountSeen := InterlockedCompareExchange64(
    Progress^.AppendStartedCount, 0, 0);
  CompleteCountSeen := InterlockedCompareExchange64(
    Progress^.AppendCompletedCount, 0, 0);
  StartRowsSeen := Progress^.AppendStartRows;
  StartTickSeen := Progress^.AppendStartTick;
  inherited Append(ABatch);
end;

function MakeIdentity: TInferenceIdentity;
begin
  Result := Default(TInferenceIdentity);
  Result.Estimator := InferenceEstimator;
  Result.Request := DefaultInferenceRequest(CSourceHash, 320);
  Result.Request.ScopeEnd16k := 320;
  Result.Request.InputEnd16k := 320;
  Result.Request.BatchSize := 2;
  Result.SourceRate := 16000;
  Result.SourceChannels := 1;
  Result.SourceFrames := 320;
  Result.ObservationCount := InferenceCount(Result.Request);
end;

procedure ClearOwnedOutput(const APath: String);
begin
  if FileExists(APath) and not DeleteFile(APath) then
    raise EAudio.Create('Unable to remove a prior fixture-owned output');
end;

procedure Run;
var
  LIdentity: TInferenceIdentity;
  LBaseline, LInstrumented: TInferenceFileSink;
  LProbe: TProbeFileSink;
  LTelemetry: TInferenceAppendTelemetrySink;
  LProgress: TInferenceWorkerProgress;
  LBatch: TInferenceBatch;
  LBasePath, LInstrumentedPath: String;
begin
  ForceDirectories(CRoot);
  LBasePath := IncludeTrailingPathDelimiter(CRoot) + 'baseline.pinf';
  LInstrumentedPath := IncludeTrailingPathDelimiter(CRoot) + 'instrumented.pinf';
  ClearOwnedOutput(LBasePath);
  ClearOwnedOutput(LInstrumentedPath);
  LIdentity := MakeIdentity;
  SetLength(LBatch, 2);
  LBatch[0] := Default(TInferenceObservation);
  LBatch[0].Center16k := 0;
  LBatch[0].AcRms := 0.25;
  LBatch[0].Salience[12] := 0.7;
  LBatch[1] := Default(TInferenceObservation);
  LBatch[1].Center16k := 160;
  LBatch[1].AcRms := 0.125;
  LBatch[1].Salience[24] := 0.9;

  LBaseline := TInferenceFileSink.Create(LBasePath);
  try
    LBaseline.Start(LIdentity);
    LBaseline.Append(LBatch);
    LBaseline.Complete;
  finally
    LBaseline.Free;
  end;

  FillChar(LProgress, SizeOf(LProgress), 0);
  LProgress.Completed := 2;
  LProbe := TProbeFileSink.Create(LInstrumentedPath);
  LProbe.Progress := @LProgress;
  LInstrumented := LProbe;
  LTelemetry := TInferenceAppendTelemetrySink.Create(LInstrumented, @LProgress);
  try
    LTelemetry.Start(LIdentity);
    LTelemetry.Append(LBatch);
    Check(LProbe.StartCountSeen = 1, 'Append start count is visible inside sink call');
    Check(LProbe.CompleteCountSeen = 0,
      'Append is not marked complete while the sink call is active');
    Check(LProbe.StartRowsSeen = 2, 'Append start records computed observation count');
    Check(LProbe.StartTickSeen > 0, 'Append start records a monotonic tick');
    Check(InterlockedCompareExchange64(LProgress.AppendStartedCount, 0, 0) = 1,
      'Append-start call count advances exactly once');
    Check(InterlockedCompareExchange64(LProgress.AppendCompletedCount, 0, 0) = 1,
      'Append-complete count advances only after the sink returns');
    Check((LProgress.AppendCompletedRows = 2) and
      (LProgress.AppendCompletedTick >= LProgress.AppendStartTick),
      'Append completion records its row count and terminal tick');
    LTelemetry.Complete;
  finally
    LTelemetry.Free;
    LInstrumented.Free;
  end;
  Check(HashInferenceFile(LBasePath) = HashInferenceFile(LInstrumentedPath),
    'Telemetry leaves PINF bytes identical to direct sink output');
  WriteLn('PASS append telemetry start/in-flight/complete markers');
  WriteLn('PASS telemetry-wrapped PINF bytes exactly match direct sink baseline');
end;

begin
  try
    Run;
  except
    on E: Exception do
    begin
      WriteLn(StdErr, E.ClassName + ': ' + E.Message);
      ExitCode := 1;
    end;
  end;
end.
