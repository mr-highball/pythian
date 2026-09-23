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
  Result[0] := Abs(AWindow[1200]);
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

procedure WriteToneWave(const AFileName: String; const ASampleRate,
  AFrameCount: Integer);
var
  LFile: TFileStream;
  LByteSink: TStreamAudioSink;
  LWriter: TWavePcm16Writer;
  LSamples: TAudioSamples;
  LIndex: Integer;
begin
  SetLength(LSamples, AFrameCount);
  for LIndex := 0 to High(LSamples) do
    LSamples[LIndex] := 0.4 * Sin(2 * Pi * 440 * LIndex / ASampleRate);
  LFile := TFileStream.Create(AFileName, fmCreate);
  LByteSink := TStreamAudioSink.Create(LFile);
  LWriter := TWavePcm16Writer.Create(LByteSink, ASampleRate, 1, AFrameCount);
  try
    LWriter.AppendSamples(LSamples);
    LWriter.Finish;
  finally
    LWriter.Free;
    LByteSink.Free;
    LFile.Free;
  end;
end;

procedure CompareReplay(const ALeftBackend: TGeometryBackend;
  const ALeftSink: TCaptureSink; const ARightBackend: TGeometryBackend;
  const ARightSink: TCaptureSink);
var
  LIndex: Integer;
begin
  Check(ALeftSink.Completed and ARightSink.Completed and
    not ALeftSink.Aborted and not ARightSink.Aborted,
    'Resampling jobs complete');
  Check(Length(ALeftBackend.Windows) = Length(ARightBackend.Windows),
    'Resampling replay window counts match');
  Check(Length(ALeftSink.Observations) = Length(ARightSink.Observations),
    'Resampling replay observation counts match');
  for LIndex := 0 to High(ALeftBackend.Windows) do
  begin
    Check((Length(ALeftBackend.Windows[LIndex]) = InferenceWindowFrames) and
      (Length(ARightBackend.Windows[LIndex]) = InferenceWindowFrames),
      'Resampling window size remains fixed');
    Check(CompareMem(@ALeftBackend.Windows[LIndex][0],
      @ARightBackend.Windows[LIndex][0],
      InferenceWindowFrames * SizeOf(Single)), 'Resampled windows are byte-identical');
  end;
  for LIndex := 0 to High(ALeftSink.Observations) do
  begin
    Check(CompareMem(@ALeftSink.Observations[LIndex],
      @ARightSink.Observations[LIndex], SizeOf(TInferenceObservation)),
      'Resampled observations are byte-identical');
  end;
end;

procedure CheckSupportedSourceRate(const AIdentity: TInferenceIdentity;
  const ASampleRate: Integer);
var
  LIdentity: TInferenceIdentity;
begin
  LIdentity := AIdentity;
  LIdentity.SourceRate := ASampleRate;
  LIdentity.SourceFrames := ASampleRate;
  Check(Length(InferenceIdentityText(LIdentity)) > 0,
    'Supported original source rate retains identity');
end;

procedure CheckUnsupportedSourceRate(const AIdentity: TInferenceIdentity);
var
  LIdentity: TInferenceIdentity;
  LRejected: Boolean;
begin
  LIdentity := AIdentity;
  LIdentity.SourceRate := 22051;
  LIdentity.SourceFrames := 22051;
  LRejected := False;
  try
    InferenceIdentityText(LIdentity);
  except
    on EAudio do
      LRejected := True;
  end;
  Check(LRejected, 'Unsupported original source rate remains rejected');
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

procedure CompareScope(const AScopeBackend: TGeometryBackend;
  const AScopeSink: TCaptureSink; const AWholeBackend: TGeometryBackend;
  const AWholeSink: TCaptureSink; const AWholeOffset: Integer);
var
  LIndex: Integer;
begin
  Check(AScopeSink.Completed and not AScopeSink.Aborted,
    'Adjacent source scope completed without abort');
  Check((Length(AScopeBackend.Windows) = 50) and
    (Length(AScopeSink.Observations) = 50),
    'Eight-thousand-frame scope has exactly fifty observations');
  Check(Length(AScopeBackend.Windows) = Length(AScopeSink.Observations),
    'Scoped backend and sink retain matching window counts');
  Check(Length(AScopeBackend.Windows) + AWholeOffset <=
    Length(AWholeBackend.Windows), 'Scoped outputs fit whole-source outputs');
  for LIndex := 0 to High(AScopeBackend.Windows) do
  begin
    Check(CompareMem(@AScopeBackend.Windows[LIndex][0],
      @AWholeBackend.Windows[AWholeOffset + LIndex][0],
      InferenceWindowFrames * SizeOf(Single)),
      'Adjacent source scope window equals whole-source window');
    Check(CompareMem(@AScopeSink.Observations[LIndex],
      @AWholeSink.Observations[AWholeOffset + LIndex],
      SizeOf(TInferenceObservation)),
      'Adjacent source scope observation equals whole-source observation');
  end;
end;

procedure Run22050;
var
  LDirectory: String;
  LFileName: String;
  LHash: String;
  LWholeRequest: TInferenceRequest;
  LFirstRequest: TInferenceRequest;
  LSecondRequest: TInferenceRequest;
  LWholeJob: TInferenceWaveJob;
  LFirstJob: TInferenceWaveJob;
  LSecondJob: TInferenceWaveJob;
  LReplayJob: TInferenceWaveJob;
  LWholeBackend: TGeometryBackend;
  LReplayBackend: TGeometryBackend;
  LFirstBackend: TGeometryBackend;
  LSecondBackend: TGeometryBackend;
  LWholeSink: TCaptureSink;
  LReplaySink: TCaptureSink;
  LFirstSink: TCaptureSink;
  LSecondSink: TCaptureSink;
begin
  LDirectory := IncludeTrailingPathDelimiter(GetCurrentDir) + 'build' +
    DirectorySeparator + 'native-inference-wave';
  ForceDirectories(LDirectory);
  LFileName := IncludeTrailingPathDelimiter(LDirectory) + '22050-tone.wav';
  WriteToneWave(LFileName, 22050, 22050);
  try
    LHash := HashInferenceFile(LFileName);
    LWholeRequest := DefaultInferenceRequest(LHash, 16000);
    LWholeRequest.InputEnd16k := 16000;
    LWholeRequest.Hop16k := 160;
    LWholeRequest.BatchSize := 17;
    LFirstRequest := DefaultInferenceRequest(LHash, 8000);
    LFirstRequest.InputEnd16k := 16000;
    LFirstRequest.Hop16k := 160;
    LFirstRequest.BatchSize := 11;
    LSecondRequest := LFirstRequest;
    LSecondRequest.ScopeStart16k := 8000;
    LSecondRequest.ScopeEnd16k := 16000;
    LSecondRequest.FirstCenter16k := 8000;
    ValidateInferenceRequest(LWholeRequest);
    ValidateInferenceRequest(LFirstRequest);
    ValidateInferenceRequest(LSecondRequest);

    LWholeBackend := TGeometryBackend.Create;
    LReplayBackend := TGeometryBackend.Create;
    LFirstBackend := TGeometryBackend.Create;
    LSecondBackend := TGeometryBackend.Create;
    LWholeSink := TCaptureSink.Create;
    LReplaySink := TCaptureSink.Create;
    LFirstSink := TCaptureSink.Create;
    LSecondSink := TCaptureSink.Create;
    try
      LWholeJob := TInferenceWaveJob.Create(LFileName, LWholeRequest);
      try
        LWholeJob.Execute(LWholeBackend, LWholeSink);
      finally
        LWholeJob.Free;
      end;
      LReplayJob := TInferenceWaveJob.Create(LFileName, LWholeRequest);
      try
        LReplayJob.Execute(LReplayBackend, LReplaySink);
      finally
        LReplayJob.Free;
      end;
      LFirstJob := TInferenceWaveJob.Create(LFileName, LFirstRequest);
      try
        LFirstJob.Execute(LFirstBackend, LFirstSink);
      finally
        LFirstJob.Free;
      end;
      LSecondJob := TInferenceWaveJob.Create(LFileName, LSecondRequest);
      try
        LSecondJob.Execute(LSecondBackend, LSecondSink);
      finally
        LSecondJob.Free;
      end;

      Check(LWholeSink.Identity.SourceRate = 22050,
        'Original 22050-Hz source rate retained in identity');
      Check(LWholeSink.Identity.SourceChannels = 1,
        'Original mono channel count retained in identity');
      Check(LWholeSink.Identity.SourceFrames = 22050,
        'Original source frame count retained in identity');
      Check(LWholeSink.Identity.Request.SourceHash = LHash,
        'Exact original WAV SHA retained in identity');
      Check((Length(LWholeSink.Observations) = 100) and
        (Length(LWholeBackend.Windows) = 100),
        'One-second source yields 100 observations at 100 windows per second');
      Check((LWholeSink.Observations[0].Center16k = 0) and
        (LWholeSink.Observations[99].Center16k = 15840),
        'Centers remain on the rational 16-kHz source clock');
      CompareReplay(LWholeBackend, LWholeSink, LReplayBackend, LReplaySink);
      CompareScope(LFirstBackend, LFirstSink, LWholeBackend, LWholeSink, 0);
      CompareScope(LSecondBackend, LSecondSink, LWholeBackend, LWholeSink, 50);
      CheckSupportedSourceRate(LWholeSink.Identity, 16000);
      CheckSupportedSourceRate(LWholeSink.Identity, 22050);
      CheckSupportedSourceRate(LWholeSink.Identity, 44100);
      CheckSupportedSourceRate(LWholeSink.Identity, 48000);
      CheckUnsupportedSourceRate(LWholeSink.Identity);
    finally
      LSecondSink.Free;
      LFirstSink.Free;
      LReplaySink.Free;
      LWholeSink.Free;
      LSecondBackend.Free;
      LFirstBackend.Free;
      LReplayBackend.Free;
      LWholeBackend.Free;
    end;
  finally
    DeleteFile(LFileName);
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
    Run22050;
    WriteLn('PASS inference wave geometry, source-rate identities, adjacent-scope resampling and replay');
  except
    on E: Exception do
    begin
      WriteLn(StdErr, 'FAIL ', E.ClassName, ': ', E.Message);
      ExitCode := 1;
    end;
  end;
end.
