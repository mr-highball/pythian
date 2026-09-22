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
unit pythian.inference.wave;

{$mode delphi}
{$H+}

interface

uses
  Classes,
  pythian.audio,
  pythian.wave.read,
  pythian.inference.observation;

type
  { Holds the exact source open denying mutation; owns no backend/sink.
    One execution only. Any execution failure poisons this job. }
  TInferenceWaveJob = class
  strict private
    FStream: TFileStream;
    FReader: TWaveFrameReader;
    FIdentity: TInferenceIdentity;
    FStarted: Boolean;
  public
    constructor Create(const AFileName: String; const ARequest: TInferenceRequest);
    destructor Destroy; override;
    procedure Execute(const ABackend: TInferenceBackend; const ASink: TInferenceSink;
      const ACancel: TInferenceCancel = nil; const AProgress: TInferenceProgress = nil);
    property Identity: TInferenceIdentity read FIdentity;
  end;

implementation

uses
  SysUtils,
  Math,
  pythian.hash,
  pythian.resample,
  pythian.resample.stream,
  pythian.wave.resample;

constructor TInferenceWaveJob.Create(const AFileName: String;
  const ARequest: TInferenceRequest);
var
  LFrames: Int64;
begin
  inherited Create;
  ValidateInferenceRequest(ARequest);
  FStream := TFileStream.Create(AFileName, fmOpenRead or fmShareDenyWrite);
  if Sha256Stream(FStream, FStream.Size) <> ARequest.SourceHash then
  begin
    raise EAudio.Create('Inference source SHA256 differs');
  end;
  FStream.Position := 0;
  FReader := TWaveFrameReader.Create(FStream);
  FIdentity := Default(TInferenceIdentity);
  FIdentity.Estimator := InferenceEstimator;
  FIdentity.Request := ARequest;
  FIdentity.SourceRate := FReader.SampleRate;
  FIdentity.SourceChannels := FReader.Channels;
  FIdentity.SourceFrames := FReader.FrameCount;
  FIdentity.ObservationCount := InferenceCount(ARequest);
  InferenceIdentityText(FIdentity);
  LFrames := StreamResampleFrameCount(FReader.FrameCount, FReader.SampleRate, InferenceRate);
  if ARequest.InputEnd16k > LFrames then
  begin
    raise EAudio.Create('Inference waveform boundary exceeds source extent');
  end;
end;

destructor TInferenceWaveJob.Destroy;
begin
  FReader.Free;
  FStream.Free;
  inherited Destroy;
end;

procedure TInferenceWaveJob.Execute(const ABackend: TInferenceBackend;
  const ASink: TInferenceSink; const ACancel: TInferenceCancel;
  const AProgress: TInferenceProgress);
var
  LPcm: TWavePcmReader;
  LResampler: TSincResampleStream;
  LRing: array[0..1023] of Single;
  LWindow: TAudioSamples;
  LBatch: TInferenceBatch;
  LObservation: TInferenceObservation;
  LRequest: TInferenceRequest;
  LInputOrigin: Int64;
  LOutputPosition: Int64;
  LCenter: Int64;
  LPosition: Int64;
  LThrough: Int64;
  LIndex: Int64;
  LDivisor: Integer;
  LOther: Integer;
  LRemainder: Integer;
  LPhasePeriod: Integer;
  LBatchCount: Integer;
  LRadius: Integer;
  LMean: Double;
  LRms: Double;
  LLeft: Double;
  LRight: Double;
  LSample: Double;
  I: Integer;
begin
  if FStarted or (ABackend = nil) or (ASink = nil) then
  begin
    raise EAudio.Create('Inference job requires fresh state, backend and sink');
  end;
  FStarted := True;
  FIdentity.Estimator := ABackend.EstimatorIdentity;
  InferenceIdentityText(FIdentity);
  LPcm := nil;
  LResampler := nil;
  LRequest := FIdentity.Request;
  try
    CheckInferenceCancel(ACancel);
    { Seek at a rational phase boundary, retaining the actual left filter halo.
      Therefore an internal job scope does not become a new resampler endpoint. }
    LDivisor := FReader.SampleRate;
    LOther := InferenceRate;
    while LOther <> 0 do
    begin
      LRemainder := LDivisor mod LOther;
      LDivisor := LOther;
      LOther := LRemainder;
    end;
    LPhasePeriod := FReader.SampleRate div LDivisor;
    LRadius := SincTapBudget(FReader.SampleRate / InferenceRate) div 2;
    LPosition := Max(LRequest.InputStart16k, LRequest.FirstCenter16k - 512);
    LInputOrigin := Max(Int64(0), (LPosition div InferenceRate) * FReader.SampleRate +
      (LPosition mod InferenceRate) * FReader.SampleRate div InferenceRate - LRadius - 2);
    LInputOrigin := (LInputOrigin div LPhasePeriod) * LPhasePeriod;
    LOutputPosition := (LInputOrigin div LPhasePeriod) * (InferenceRate div LDivisor);
    FReader.SeekFrame(LInputOrigin);
    LPcm := TWavePcmReader.Create(FReader);
    LResampler := TSincResampleStream.Create(LPcm, InferenceRate);
    SetLength(LWindow, InferenceWindowFrames);
    SetLength(LBatch, LRequest.BatchSize);
    LBatchCount := 0;
    FillChar(LRing, SizeOf(LRing), 0);
    ASink.Start(FIdentity);
    LIndex := 0;
    while LIndex < FIdentity.ObservationCount do
    begin
      CheckInferenceCancel(ACancel);
      LCenter := LRequest.FirstCenter16k + LIndex * LRequest.Hop16k;
      LThrough := Min(LRequest.InputEnd16k - 1, LCenter + 511);
      while LOutputPosition <= LThrough do
      begin
        if not LResampler.ReadFrame(LLeft, LRight) then
        begin
          raise EAudio.Create('Inference source ended before declared support');
        end;
        if LRequest.Channel = 0 then
        begin
          LSample := LLeft;
        end
        else
        begin
          LSample := LRight;
        end;
        RequireFinite(LSample, 'Prepared inference sample');
        LRing[LOutputPosition mod InferenceWindowFrames] := LSample;
        Inc(LOutputPosition);
      end;
      LMean := 0;
      for I := 0 to High(LWindow) do
      begin
        LPosition := LCenter - 512 + I;
        if (LPosition < LRequest.InputStart16k) or (LPosition >= LRequest.InputEnd16k) then
        begin
          LWindow[I] := 0;
        end
        else
        begin
          LWindow[I] := LRing[LPosition mod InferenceWindowFrames];
        end;
        LMean := LMean + LWindow[I];
      end;
      LMean := LMean / InferenceWindowFrames;
      LRms := 0;
      for I := 0 to High(LWindow) do
      begin
        LRms := LRms + Sqr(LWindow[I] - LMean);
      end;
      LObservation.Center16k := LCenter;
      LObservation.AcRms := Sqrt(LRms / InferenceWindowFrames);
      LObservation.Salience := ABackend.Activate(LWindow);
      ValidateInferenceObservation(LObservation);
      CheckInferenceCancel(ACancel);
      LBatch[LBatchCount] := LObservation;
      Inc(LBatchCount);
      if Assigned(AProgress) then
      begin
        AProgress('observing', LIndex + 1);
      end;
      if (LBatchCount = LRequest.BatchSize) or (LIndex + 1 = FIdentity.ObservationCount) then
      begin
        SetLength(LBatch, LBatchCount);
        ASink.Append(LBatch);
        LBatchCount := 0;
        SetLength(LBatch, LRequest.BatchSize);
      end;
      Inc(LIndex);
    end;
    CheckInferenceCancel(ACancel);
    if Assigned(AProgress) then
    begin
      AProgress('verifying', FIdentity.ObservationCount);
    end;
    FStream.Position := 0;
    if Sha256Stream(FStream, FStream.Size) <> LRequest.SourceHash then
    begin
      raise EAudio.Create('Inference source changed during measurement');
    end;
    CheckInferenceCancel(ACancel);
    ASink.Complete;
  except
    LResampler.Free;
    LPcm.Free;
    ASink.Abort;
    raise;
  end;
  { These readers own no source and may be released after terminal callbacks. }
  LResampler.Free;
  LPcm.Free;
end;

end.
