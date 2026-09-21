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

unit pythian.analysis.wave;

{$mode delphi}
{$H+}

interface

uses
  pythian.analysis,
  pythian.wave.read;

{ Borrows a reader and analyzes its complete audio from frame zero. Retains
  overlap between windows; sample storage is bounded by the window size.
  Existing analysis frame/work budgets apply. Reader position may advance;
  reader failures propagate. No clip or whole encoded-file buffer is created. }
function AnalyzeWave(const AReader: TWaveFrameReader;
  const AOptions: TAnalysisOptions): TAudioFeatures;

type
  TWaveFeatureBatch = record
    FirstFeature: Int64;
    SourceStartFrame: Int64;
    { StartFrame is relative to SourceStartFrame; only emitted observations. }
    Features: TAudioFeatures;
    NextFeature: Int64;
    Completed: Boolean;
  end;
  TWaveBandFeatureBatch = record
    Batch: TWaveFeatureBatch;
    Bands: TAudioBandSeriesArray;
  end;

{ Resume by the next feature index against the same immutable source/options.
  Reconstructs one preceding spectrum for flux; context is never emitted twice.
  Source geometry is Int64; sample and feature storage is bounded per call.
  Caller owns source identity/options verification and durable checkpointing. }
function AnalyzeWaveBatch(const AReader: TWaveFrameReader;
  const AOptions: TAnalysisOptions; const AFirstFeature: Int64;
  const AMaximumFeatures: Integer = 1024): TWaveFeatureBatch;

{ Same source coordinates, overlap/context and bounded resume behavior, with
  caller-selected spectral bands from the shared FFT pass. Band values align
  with Batch.Features. Completed empty batches retain edges and empty values.
  Band validation precedes source reads, including at EOF. }
function AnalyzeWaveBandBatch(const AReader: TWaveFrameReader;
  const AOptions: TAnalysisOptions; const ABandEdges: TAnalysisBandEdges;
  const AFirstFeature: Int64; const AMaximumFeatures: Integer = 1024): TWaveBandFeatureBatch;

implementation

uses
  Math,
  pythian.audio;

type
  TWaveAnalysisSource = class(TAudioAnalysisSource)
  strict private
    FReader: TWaveFrameReader;
    FCache: TAudioSamples;
    FStart: Integer;
    FOrigin: Int64;
  public
    constructor Create(const AReader: TWaveFrameReader);
    constructor CreateRange(const AReader: TWaveFrameReader;
      const AOrigin: Int64; const AFrameCount: Integer);
    procedure ReadWindow(const AStartFrame, AValidFrames: Integer;
      var ASamples: TAudioSamples); override;
  end;

constructor TWaveAnalysisSource.Create(const AReader: TWaveFrameReader);
begin
  if (AReader = nil) then
  begin
    raise EAudio.Create('WAV analysis reader is required');
  end;
  if AReader.Failed or (AReader.FrameCount > MaximumClipSamples) then
  begin
    raise EAudio.Create('WAV analysis reader failed or exceeds frame budget');
  end;
  inherited Create(AReader.SampleRate, AReader.Channels, Integer(AReader.FrameCount));
  FReader := AReader;
end;

procedure TWaveAnalysisSource.ReadWindow(const AStartFrame, AValidFrames: Integer;
  var ASamples: TAudioSamples);
var
  LCandidate: TAudioSamples;
  LNew: TAudioSamples;
  LKeep: Integer;
  LCacheEnd: Integer;
begin
  if (AStartFrame < 0) or (AStartFrame > FrameCount) or
    (AValidFrames < 1) or (AValidFrames > 16384) or
    (AValidFrames > FrameCount - AStartFrame) then
  begin
    raise EAudio.Create('Invalid WAV analysis window');
  end;
  LKeep := 0;
  LCacheEnd := FStart + Length(FCache) div Channels;
  if (AStartFrame >= FStart) and (AStartFrame < LCacheEnd) then
  begin
    LKeep := Min(AValidFrames, LCacheEnd - AStartFrame);
  end;
  SetLength(LCandidate, AValidFrames * Channels);
  if LKeep > 0 then
  begin
    Move(FCache[(AStartFrame - FStart) * Channels], LCandidate[0],
      LKeep * Channels * SizeOf(Single));
  end;
  if LKeep < AValidFrames then
  begin
    if FReader.FramePosition <> FOrigin + AStartFrame + LKeep then
    begin
      FReader.SeekFrame(FOrigin + AStartFrame + LKeep);
    end;
    LNew := FReader.ReadFrames(AValidFrames - LKeep);
    if Length(LNew) <> (AValidFrames - LKeep) * Channels then
    begin
      raise EAudio.Create('WAV analysis window ended early');
    end;
    Move(LNew[0], LCandidate[LKeep * Channels], Length(LNew) * SizeOf(Single));
  end;
  FCache := LCandidate;
  FStart := AStartFrame;
  ASamples := LCandidate;
end;

constructor TWaveAnalysisSource.CreateRange(const AReader: TWaveFrameReader;
  const AOrigin: Int64; const AFrameCount: Integer);
begin
  if (AReader = nil) then
  begin
    raise EAudio.Create('WAV analysis reader is required');
  end;
  if AReader.Failed or (AOrigin < 0) or (AOrigin > AReader.FrameCount) or
    (AFrameCount < 0) or (AFrameCount > AReader.FrameCount - AOrigin) then
  begin
    raise EAudio.Create('Invalid WAV analysis source range');
  end;
  inherited Create(AReader.SampleRate, AReader.Channels, AFrameCount);
  FReader := AReader;
  FOrigin := AOrigin;
end;

function AnalyzeWaveBatchCore(const AReader: TWaveFrameReader;
  const AOptions: TAnalysisOptions; const AFirstFeature: Int64;
  const AMaximumFeatures: Integer; const ABandEdges: TAnalysisBandEdges;
  out ABands: TAudioBandSeriesArray): TWaveFeatureBatch;
var
  LSource: TWaveAnalysisSource;
  LBandResult: TAudioBandAnalysis;
  LTotal: Int64;
  LOrigin: Int64;
  LExtent: Int64;
  LWork: Int64;
  LCount: Integer;
  LContext: Integer;
  LChecked: Integer;
  LIndex: Integer;
begin
  if AReader = nil then
  begin
    raise EAudio.Create('WAV analysis reader is required');
  end;
  PlanAudioAnalysis(0, AReader.Channels, AOptions, LChecked, LWork);
  LTotal := AReader.FrameCount div AOptions.HopFrames;
  if AReader.FrameCount mod AOptions.HopFrames <> 0 then
  begin
    Inc(LTotal);
  end;
  if AReader.Failed or (AFirstFeature < 0) or (AFirstFeature > LTotal) or
    (AMaximumFeatures < 1) or (AMaximumFeatures > MaximumAnalysisFrames - 1) then
  begin
    raise EAudio.Create('Invalid WAV feature batch or failed reader');
  end;
  Result := Default(TWaveFeatureBatch);
  ABands := nil;
  Result.FirstFeature := AFirstFeature;
  Result.NextFeature := AFirstFeature;
  Result.Completed := AFirstFeature = LTotal;
  if Result.Completed then
  begin
    Result.SourceStartFrame := AReader.FrameCount;
    if Length(ABandEdges) > 0 then
    begin
      LSource := TWaveAnalysisSource.CreateRange(AReader, AReader.FrameCount, 0);
      try
        LBandResult := AnalyzeAudioSourceRangeBands(LSource, AOptions, ABandEdges, 0, 0);
        ABands := LBandResult.Bands;
      finally
        LSource.Free;
      end;
    end;
    Exit;
  end;
  Result.SourceStartFrame := AFirstFeature * AOptions.HopFrames;
  LCount := Min(Int64(AMaximumFeatures), LTotal - AFirstFeature);
  LContext := Ord(AFirstFeature > 0);
  LOrigin := Result.SourceStartFrame - LContext * AOptions.HopFrames;
  LExtent := Min(AReader.FrameCount - LOrigin,
    Int64(LCount + LContext - 1) * AOptions.HopFrames + AOptions.WindowFrames);
  if LExtent > MaximumClipSamples then
  begin
    raise EAudio.Create('WAV feature batch exceeds local frame budget');
  end;
  LSource := TWaveAnalysisSource.CreateRange(AReader, LOrigin, Integer(LExtent));
  try
    if Length(ABandEdges) > 0 then
    begin
      LBandResult := AnalyzeAudioSourceRangeBands(LSource, AOptions, ABandEdges,
        LContext, LCount);
      Result.Features := LBandResult.Features;
      ABands := LBandResult.Bands;
    end
    else
    begin
      Result.Features := AnalyzeAudioSourceRange(LSource, AOptions, LContext, LCount);
    end;
  finally
    LSource.Free;
  end;
  for LIndex := 0 to High(Result.Features) do
  begin
    Dec(Result.Features[LIndex].StartFrame, LContext * AOptions.HopFrames);
  end;
  Result.NextFeature := AFirstFeature + LCount;
  Result.Completed := Result.NextFeature = LTotal;
end;

function AnalyzeWaveBatch(const AReader: TWaveFrameReader;
  const AOptions: TAnalysisOptions; const AFirstFeature: Int64;
  const AMaximumFeatures: Integer): TWaveFeatureBatch;
var
  LBands: TAudioBandSeriesArray;
begin
  Result := AnalyzeWaveBatchCore(AReader, AOptions, AFirstFeature, AMaximumFeatures, nil, LBands);
end;

function AnalyzeWaveBandBatch(const AReader: TWaveFrameReader;
  const AOptions: TAnalysisOptions; const ABandEdges: TAnalysisBandEdges;
  const AFirstFeature: Int64; const AMaximumFeatures: Integer): TWaveBandFeatureBatch;
var
  LResult: TWaveBandFeatureBatch;
begin
  if Length(ABandEdges) < 2 then
  begin
    raise EAudio.Create('WAV band analysis requires frequency band edges');
  end;
  LResult := Default(TWaveBandFeatureBatch);
  LResult.Batch := AnalyzeWaveBatchCore(AReader, AOptions, AFirstFeature,
    AMaximumFeatures, ABandEdges, LResult.Bands);
  Result := LResult;
end;

function AnalyzeWave(const AReader: TWaveFrameReader;
  const AOptions: TAnalysisOptions): TAudioFeatures;
var
  LSource: TWaveAnalysisSource;
begin
  LSource := TWaveAnalysisSource.Create(AReader);
  try
    Result := AnalyzeAudioSource(LSource, AOptions);
  finally
    LSource.Free;
  end;
end;

end.
