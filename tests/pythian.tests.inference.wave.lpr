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
program pythian_tests_inference_wave;

{$mode delphi}
{$H+}

uses
  Classes,
  SysUtils,
  Math,
  pythian.audio,
  pythian.wave.stream,
  pythian.inference.observation,
  pythian.inference.wave;

const
  CSourceFrames = 4096;

type
  TGeometryBackend = class(TInferenceBackend)
  public
    Windows: array of TAudioSamples;
    function Activate(const AWindow: TAudioSamples): TPitchSalience; override;
    function EstimatorIdentity: String; override;
  end;

  TCaptureSink = class(TInferenceSink)
  public
    Identity: TInferenceIdentity;
    Observations: TInferenceBatch;
    Started, Completed, Aborted: Boolean;
    procedure Start(const AIdentity: TInferenceIdentity); override;
    procedure Append(const ABatch: TInferenceBatch); override;
    procedure Complete; override;
    procedure Abort; override;
  end;

procedure Check(const ACondition: Boolean; const AMessage: String);
begin
  if not ACondition then
    raise EAudio.Create(AMessage);
end;

function TGeometryBackend.EstimatorIdentity: String;
begin
  Result := InferenceEstimator;
end;

function TGeometryBackend.Activate(const AWindow: TAudioSamples): TPitchSalience;
var
  LCount: Integer;
begin
  if Length(AWindow) <> InferenceWindowFrames then
    raise EAudio.Create('Wave adapter did not provide accepted window size');
  LCount := Length(Windows);
  SetLength(Windows, LCount + 1);
  Windows[LCount] := Copy(AWindow);
  Result := Default(TPitchSalience);
  Result[0] := AWindow[1200];
end;

procedure TCaptureSink.Start(const AIdentity: TInferenceIdentity);
begin
  Check(not Started, 'Sink starts once');
  Identity := AIdentity;
  Started := True;
end;

procedure TCaptureSink.Append(const ABatch: TInferenceBatch);
var
  LCount, LIndex: Integer;
begin
  Check(Started and not Completed and not Aborted, 'Append follows Start');
  LCount := Length(Observations);
  SetLength(Observations, LCount + Length(ABatch));
  for LIndex := 0 to High(ABatch) do
    Observations[LCount + LIndex] := ABatch[LIndex];
end;

procedure TCaptureSink.Complete;
begin
  Check(Started and not Aborted, 'Complete follows Start');
  Completed := True;
end;

procedure TCaptureSink.Abort;
begin
  Aborted := True;
end;

procedure ExpectBadPolicy(const ARequest: TInferenceRequest);
var
  LRejected: Boolean;
  LRequest: TInferenceRequest;
begin
  LRequest := ARequest;
  LRequest.Policy := 'different-policy';
  LRejected := False;
  try
    ValidateInferenceRequest(LRequest);
  except
    on EAudio do
      LRejected := True;
  end;
  Check(LRejected, 'Changed policy must reject before source processing');
end;

procedure WriteConstantWave(const AFileName: String);
var
  LFile: TFileStream;
  LByteSink: TStreamAudioSink;
  LWriter: TWavePcm16Writer;
  LSamples: TAudioSamples;
  LIndex: Integer;
begin
  SetLength(LSamples, CSourceFrames);
  for LIndex := 0 to High(LSamples) do
    LSamples[LIndex] := 0.25;
  LFile := TFileStream.Create(AFileName, fmCreate);
  LByteSink := TStreamAudioSink.Create(LFile);
  LWriter := TWavePcm16Writer.Create(LByteSink, InferenceRate, 1,
    CSourceFrames);
  try
    LWriter.AppendSamples(LSamples);
    LWriter.Finish;
  finally
    LWriter.Free;
    LByteSink.Free;
    LFile.Free;
  end;
end;

procedure CompareRuns(const ALeftBackend: TGeometryBackend;
  const ALeftSink: TCaptureSink; const ARightBackend: TGeometryBackend;
  const ARightSink: TCaptureSink);
var
  LIndex, LSample: Integer;
begin
  Check(ALeftSink.Completed and ARightSink.Completed and
    not ALeftSink.Aborted and not ARightSink.Aborted, 'Both jobs complete');
  Check(Length(ALeftSink.Observations) = 2, 'Expected two observation centers');
  Check(Length(ALeftBackend.Windows) = 2, 'Backend receives two windows');
  Check(Length(ALeftBackend.Windows) = Length(ARightBackend.Windows),
    'Replay window counts match');
  for LIndex := 0 to High(ALeftBackend.Windows) do
  begin
    Check(Length(ALeftBackend.Windows[LIndex]) = 2048,
      'Each center receives exactly 2048 samples');
    for LSample := 0 to High(ALeftBackend.Windows[LIndex]) do
      Check(ALeftBackend.Windows[LIndex][LSample] =
        ARightBackend.Windows[LIndex][LSample], 'Window replay is exact');
  end;
  for LSample := 0 to 1023 do
    Check(ALeftBackend.Windows[0][LSample] = 0,
      'First centered window zero-pads its 1024-sample left edge');
  Check(ALeftBackend.Windows[0][1200] > 0.2,
    'First window contains source samples after its center');
  for LSample := 0 to 863 do
    Check(ALeftBackend.Windows[1][LSample] = 0,
      'Second centered window pads only positions before source start');
  Check(ALeftBackend.Windows[1][1200] > 0.2,
    'Second window retains centered source samples');
  Check((ALeftSink.Observations[0].Center16k = 0) and
    (ALeftSink.Observations[1].Center16k = 160),
    'Source-clock centers remain 0 and 160');
  Check(ALeftSink.Identity.Estimator = InferenceEstimator,
    'Output identity uses accepted estimator');
  Check(ALeftSink.Identity.Request.Policy = InferencePolicy,
    'Output request is bound to accepted policy');
  for LIndex := 0 to High(ALeftSink.Observations) do
  begin
    Check(ALeftSink.Observations[LIndex].Center16k =
      ARightSink.Observations[LIndex].Center16k, 'Replay centers match');
    Check(ALeftSink.Observations[LIndex].AcRms =
      ARightSink.Observations[LIndex].AcRms, 'Replay RMS matches');
    for LSample := Low(TPitchSalience) to High(TPitchSalience) do
      Check(ALeftSink.Observations[LIndex].Salience[LSample] =
        ARightSink.Observations[LIndex].Salience[LSample],
        'Replay support matches');
  end;
end;

procedure Run;
var
  LDirectory, LFileName, LHash: String;
  LRequest: TInferenceRequest;
  LJob: TInferenceWaveJob;
  LBackend1, LBackend2: TGeometryBackend;
  LSink1, LSink2: TCaptureSink;
begin
  Check(InferenceWindowFrames = 2048, 'Observation contract is 2048 samples');
  Check(InferenceEstimator =
    'pythian-interpolated-peakmap-sparse35cents-midi24-20cent-v1',
    'Accepted estimator identity is exact');
  Check(InferencePolicy =
    'raw-f32-16k2048-hann8192-peak64-q003-h23-octave-35cent-8sigma-v1',
    'Accepted request policy is exact');

  LDirectory := IncludeTrailingPathDelimiter(GetCurrentDir) +
    'build' + DirectorySeparator + 'native-inference-wave';
  ForceDirectories(LDirectory);
  LFileName := IncludeTrailingPathDelimiter(LDirectory) + 'geometry.wav';
  WriteConstantWave(LFileName);
  try
    LHash := HashInferenceFile(LFileName);
    LRequest := DefaultInferenceRequest(LHash, 320);
    LRequest.InputEnd16k := CSourceFrames;
    LRequest.Hop16k := 160;
    LRequest.BatchSize := 2;
    ValidateInferenceRequest(LRequest);
    ExpectBadPolicy(LRequest);

    LBackend1 := TGeometryBackend.Create;
    LBackend2 := TGeometryBackend.Create;
    LSink1 := TCaptureSink.Create;
    LSink2 := TCaptureSink.Create;
    try
      LJob := TInferenceWaveJob.Create(LFileName, LRequest);
      try
        LJob.Execute(LBackend1, LSink1);
      finally
        LJob.Free;
      end;
      LJob := TInferenceWaveJob.Create(LFileName, LRequest);
      try
        LJob.Execute(LBackend2, LSink2);
      finally
        LJob.Free;
      end;
      CompareRuns(LBackend1, LSink1, LBackend2, LSink2);
    finally
      LSink2.Free;
      LSink1.Free;
      LBackend2.Free;
      LBackend1.Free;
    end;
  finally
    DeleteFile(LFileName);
  end;
end;

begin
  try
    Run;
    WriteLn('PASS inference wave geometry, policy rejection and replay');
  except
    on E: Exception do
    begin
      WriteLn(StdErr, 'FAIL ', E.ClassName, ': ', E.Message);
      ExitCode := 1;
    end;
  end;
end.
