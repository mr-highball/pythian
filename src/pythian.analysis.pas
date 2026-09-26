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
unit pythian.analysis;

{$mode delphi}
{$H+}

interface

uses
  pythian.audio;

const
  AnalysisVersion = 1;
  MaximumAnalysisFrames = 65536;
  MaximumAnalysisWork = 2000000000;
  MaximumAnalysisBands = 32;

type
  TAnalysisOptions = record
    WindowFrames: Integer;
    HopFrames: Integer;
    SilenceRms: Double;
  end;

  TAudioFeature = record
    StartFrame: Integer;
    ValidFrames: Integer;
    Rms: Double;
    Peak: Double;
    CentroidHz: Double;
    Flux: Double;
    Chroma: array[0..11] of Double;
    Silent: Boolean;
  end;
  TAudioFeatures = array of TAudioFeature;

  TAnalysisBandEdges = array of Double;
  TAnalysisBandValues = array of Double;
  TAudioBandSeries = record
    LowerHz: Double;
    UpperHz: Double;
    Magnitude: TAnalysisBandValues;
    PositiveFlux: TAnalysisBandValues;
  end;
  TAudioBandSeriesArray = array of TAudioBandSeries;
  TAudioBandAnalysis = record
    Features: TAudioFeatures;
    Bands: TAudioBandSeriesArray;
  end;

  { Immutable source geometry; ReadWindow supplies exactly the requested
    interleaved samples. Callers keep source content stable during analysis.
    Implementations may seek/cache; no whole-clip storage is required. }
  TAudioAnalysisSource = class abstract
  strict private
    FSampleRate: Integer;
    FChannels: Integer;
    FFrameCount: Integer;
  public
    constructor Create(const ASampleRate, AChannels, AFrameCount: Integer);
    procedure ReadWindow(const AStartFrame, AValidFrames: Integer;
      var ASamples: TAudioSamples); virtual; abstract;
    property SampleRate: Integer read FSampleRate;
    property Channels: Integer read FChannels;
    property FrameCount: Integer read FFrameCount;
  end;

function DefaultAnalysisOptions: TAnalysisOptions;
{ Shared preflight for individual recordings and bounded multi-file corpora. }
procedure PlanAudioAnalysis(const AFrameCount, AChannels: Integer;
  const AOptions: TAnalysisOptions; out AFeatureCount: Integer; out AWork: Int64);
{ Per-channel spectra are combined as power, avoiding stereo phase cancellation.
  Final windows are zero-padded; RMS excludes padding. Chroma is spectral energy
  folded to equal-tempered pitch classes, not a note/chord transcription. }
function AnalyzeAudio(const AClip: TAudioClip;
  const AOptions: TAnalysisOptions): TAudioFeatures;
{ Shares the same FFT/feature engine and budgets as clip analysis. Source
  exceptions propagate; the caller's previously assigned features survive.
  Source position/history may advance. The source is borrowed for this call. }
function AnalyzeAudioSource(const ASource: TAudioAnalysisSource;
  const AOptions: TAnalysisOptions): TAudioFeatures;
{ Bounded feature-index range. Recomputes the preceding spectrum when starting
  after zero, so flux agrees with uninterrupted analysis. Returned coordinates
  remain relative to the source. Budgets include this one context observation. }
function AnalyzeAudioSourceRange(const ASource: TAudioAnalysisSource;
  const AOptions: TAnalysisOptions; const AFirstFeature, AFeatureCount: Integer): TAudioFeatures;

{ Optional measurements from the same FFT pass, leaving TAudioFeature unchanged.
  Supply 2..33 strictly increasing finite edges within [0, sample rate/2].
  Bins belong to [lower,upper), with the final upper edge included. Magnitude is
  the sum of raw windowed FFT magnitudes after channel-power combination.
  PositiveFlux uses the full-spectrum current/previous magnitude denominator,
  exactly as Features.Flux; silent features have zero band flux. Full-spectrum
  partitions sum to Features.Flux within floating summation tolerance.
  Bands are measurements, not separated instruments or tempo confidence.
  Range context and FFT budgets match AnalyzeAudioSourceRange. At most 32 pairs
  of value arrays are allocated, each with the returned feature count; no extra
  FFTs. Values share Features' indices and source coordinates, and are detached
  from edges/source. Invalid admission preserves an assigned result. }
function AnalyzeAudioSourceRangeBands(const ASource: TAudioAnalysisSource;
  const AOptions: TAnalysisOptions; const ABandEdges: TAnalysisBandEdges;
  const AFirstFeature, AFeatureCount: Integer): TAudioBandAnalysis;
function AnalyzeAudioBands(const AClip: TAudioClip; const AOptions: TAnalysisOptions;
  const ABandEdges: TAnalysisBandEdges): TAudioBandAnalysis;

implementation

uses
  Math,
  pythian.fourier;

type
  TDoubleArray = TFourierValues;

  TClipAnalysisSource = class(TAudioAnalysisSource)
  strict private
    FClip: TAudioClip;
  public
    constructor Create(const AClip: TAudioClip);
    procedure ReadWindow(const AStartFrame, AValidFrames: Integer;
      var ASamples: TAudioSamples); override;
  end;

constructor TAudioAnalysisSource.Create(const ASampleRate, AChannels, AFrameCount: Integer);
begin
  inherited Create;
  ValidateAudioFormat(ASampleRate, AChannels);
  if (AFrameCount < 0) or (AFrameCount > MaximumClipSamples) then
  begin
    raise EAudio.Create('Analysis source frame extent exceeds its current budget');
  end;
  FSampleRate := ASampleRate;
  FChannels := AChannels;
  FFrameCount := AFrameCount;
end;

constructor TClipAnalysisSource.Create(const AClip: TAudioClip);
begin
  if AClip = nil then
  begin
    raise EAudio.Create('Analysis clip is required');
  end;
  inherited Create(AClip.SampleRate, AClip.Channels, AClip.FrameCount);
  FClip := AClip;
end;

procedure TClipAnalysisSource.ReadWindow(const AStartFrame, AValidFrames: Integer;
  var ASamples: TAudioSamples);
var
  LFrame: Integer;
  LChannel: Integer;
begin
  SetLength(ASamples, AValidFrames * Channels);
  for LFrame := 0 to AValidFrames - 1 do
  begin
    for LChannel := 0 to Channels - 1 do
    begin
      ASamples[LFrame * Channels + LChannel] := FClip.SampleAt(AStartFrame + LFrame, LChannel);
    end;
  end;
end;

function DefaultAnalysisOptions: TAnalysisOptions;
begin
  Result.WindowFrames := 4096;
  Result.HopFrames := 1024;
  Result.SilenceRms := 0.0001;
end;

procedure PlanAudioAnalysis(const AFrameCount, AChannels: Integer;
  const AOptions: TAnalysisOptions; out AFeatureCount: Integer; out AWork: Int64);
var
  LSize: Integer;
  LStages: Integer;
  LIndex: Integer;
begin
  LSize := AOptions.WindowFrames;
  RequireFinite(AOptions.SilenceRms, 'Silence threshold');
  if (AFrameCount < 0) or (AFrameCount > MaximumClipSamples) or
    (AChannels < 1) or (AChannels > 2) or
    (LSize < 64) or (LSize > 16384) or ((LSize and (LSize - 1)) <> 0) or
    (AOptions.HopFrames < 1) or (AOptions.HopFrames > LSize) or
    (AOptions.SilenceRms < 0) then
  begin
    raise EAudio.Create('Invalid analysis source, window, hop, or silence threshold');
  end;
  AFeatureCount := (AFrameCount + AOptions.HopFrames - 1) div AOptions.HopFrames;
  LStages := 0;
  LIndex := LSize;
  while LIndex > 1 do
  begin
    Inc(LStages);
    LIndex := LIndex shr 1;
  end;
  AWork := Int64(AFeatureCount) * LSize * LStages * AChannels;
  if (AFeatureCount > MaximumAnalysisFrames) or (AWork > MaximumAnalysisWork) then
  begin
    raise EAudio.Create('Analysis exceeds frame or FFT work budget; use a larger hop or excerpt');
  end;
end;

function AnalyzeAudioSourceRangeCore(const ASource: TAudioAnalysisSource;
  const AOptions: TAnalysisOptions; const AFirstFeature, AFeatureCount: Integer;
  const ABandEdges: TAnalysisBandEdges; out ABands: TAudioBandSeriesArray): TAudioFeatures;
var
  LFeatures: TAudioFeatures;
  LSamples: TAudioSamples;
  LReal: TDoubleArray;
  LImaginary: TDoubleArray;
  LWindow: TDoubleArray;
  LPower: TDoubleArray;
  LPrevious: TDoubleArray;
  LBinPitch: array of Integer;
  LBinBand: array of Integer;
  LFeature: TAudioFeature;
  LCount: Integer;
  LFirst: Integer;
  LTotalCount: Integer;
  LPlanned: Integer;
  LFrame: Integer;
  LChannel: Integer;
  LIndex: Integer;
  LBin: Integer;
  LBand: Integer;
  LOutputIndex: Integer;
  LSize: Integer;
  LWork: Int64;
  LValue: Double;
  LFrequency: Double;
  LTotal: Double;
  LChromaTotal: Double;
  LMagnitude: Double;
  LPreviousTotal: Double;
begin
  if ASource = nil then
  begin
    raise EAudio.Create('Analysis source is required');
  end;
  LSize := AOptions.WindowFrames;
  PlanAudioAnalysis(0, ASource.Channels, AOptions, LPlanned, LWork);
  LTotalCount := (ASource.FrameCount + AOptions.HopFrames - 1) div AOptions.HopFrames;
  if (AFirstFeature < 0) or (AFirstFeature > LTotalCount) or
    (AFeatureCount < 0) or (AFeatureCount > LTotalCount - AFirstFeature) then
  begin
    raise EAudio.Create('Invalid analysis feature range');
  end;
  LCount := AFeatureCount;
  LFirst := AFirstFeature;
  if (LCount > 0) and (LFirst > 0) then
  begin
    Dec(LFirst);
  end;
  LPlanned := LCount + AFirstFeature - LFirst;
  if LPlanned > 0 then
  begin
    LWork := Int64(LPlanned - 1) * AOptions.HopFrames + 1;
  end
  else
  begin
    LWork := 0;
  end;
  if LWork > MaximumClipSamples then
  begin
    raise EAudio.Create('Analysis range exceeds frame budget');
  end;
  PlanAudioAnalysis(Integer(LWork),
    ASource.Channels, AOptions, LPlanned, LWork);
  ABands := nil;
  if Length(ABandEdges) > 0 then
  begin
    SetLength(ABands, Length(ABandEdges) - 1);
    for LBand := 0 to High(ABands) do
    begin
      ABands[LBand].LowerHz := ABandEdges[LBand];
      ABands[LBand].UpperHz := ABandEdges[LBand + 1];
      SetLength(ABands[LBand].Magnitude, LCount);
      SetLength(ABands[LBand].PositiveFlux, LCount);
    end;
  end;
  SetLength(LFeatures, LCount);
  SetLength(LReal, LSize);
  SetLength(LImaginary, LSize);
  SetLength(LWindow, LSize);
  SetLength(LPower, LSize div 2 + 1);
  SetLength(LPrevious, Length(LPower));
  SetLength(LBinPitch, Length(LPower));
  SetLength(LBinBand, Length(LPower));
  for LIndex := 0 to LSize - 1 do
  begin
    LWindow[LIndex] := 0.5 - 0.5 * Cos(2 * Pi * LIndex / LSize);
  end;
  for LBin := 0 to High(LBinPitch) do
  begin
    LFrequency := ASource.SampleRate;
    LFrequency := LBin * LFrequency / LSize;
    LBinBand[LBin] := -1;
    for LBand := 0 to High(ABands) do
    begin
      if (LFrequency >= ABands[LBand].LowerHz) and
        ((LFrequency < ABands[LBand].UpperHz) or
         ((LBand = High(ABands)) and (LFrequency = ABands[LBand].UpperHz))) then
      begin
        LBinBand[LBin] := LBand;
        Break;
      end;
    end;
    LBinPitch[LBin] := -1;
    if (LFrequency >= 27.5) and (LFrequency <= 5000) then
    begin
      LBinPitch[LBin] := Floor(69 + 12 * Log2(LFrequency / 440) + 0.5) mod 12;
    end;
  end;
  LPreviousTotal := 0;
  for LFrame := LFirst to AFirstFeature + LCount - 1 do
  begin
    LFeature := Default(TAudioFeature);
    LFeature.StartFrame := LFrame * AOptions.HopFrames;
    LFeature.ValidFrames := Min(LSize, ASource.FrameCount - LFeature.StartFrame);
    ASource.ReadWindow(LFeature.StartFrame, LFeature.ValidFrames, LSamples);
    if Length(LSamples) <> LFeature.ValidFrames * ASource.Channels then
    begin
      raise EAudio.Create('Analysis source returned an incomplete window');
    end;
    for LIndex := 0 to High(LSamples) do
    begin
      RequireFinite(LSamples[LIndex], 'Analysis source sample');
    end;
    for LBin := 0 to High(LPower) do
    begin
      LPower[LBin] := 0;
    end;
    for LChannel := 0 to ASource.Channels - 1 do
    begin
      for LIndex := 0 to LSize - 1 do
      begin
        LValue := 0;
        if LIndex < LFeature.ValidFrames then
        begin
          LValue := LSamples[LIndex * ASource.Channels + LChannel];
          LFeature.Rms := LFeature.Rms + Sqr(LValue);
          LFeature.Peak := Max(LFeature.Peak, Abs(LValue));
        end;
        LReal[LIndex] := LValue * LWindow[LIndex];
        LImaginary[LIndex] := 0;
      end;
      Fourier(LReal, LImaginary);
      for LBin := 0 to High(LPower) do
      begin
        LPower[LBin] := LPower[LBin] +
          (Sqr(LReal[LBin]) + Sqr(LImaginary[LBin])) / ASource.Channels;
      end;
    end;
    LFeature.Rms := Sqrt(LFeature.Rms / (LFeature.ValidFrames * ASource.Channels));
    LFeature.Silent := LFeature.Rms <= AOptions.SilenceRms;
    LTotal := 0;
    LChromaTotal := 0;
    for LBin := 0 to High(LPower) do
    begin
      LMagnitude := Sqrt(LPower[LBin]);
      LTotal := LTotal + LMagnitude;
      LFeature.CentroidHz := LFeature.CentroidHz +
        LMagnitude * LBin * ASource.SampleRate / LSize;
      LFeature.Flux := LFeature.Flux + Max(0, LMagnitude - LPrevious[LBin]);
      LBand := LBinBand[LBin];
      if (LBand >= 0) and (LFrame >= AFirstFeature) then
      begin
        LOutputIndex := LFrame - AFirstFeature;
        ABands[LBand].Magnitude[LOutputIndex] :=
          ABands[LBand].Magnitude[LOutputIndex] + LMagnitude;
        ABands[LBand].PositiveFlux[LOutputIndex] :=
          ABands[LBand].PositiveFlux[LOutputIndex] + Max(0, LMagnitude - LPrevious[LBin]);
      end;
      LPrevious[LBin] := LMagnitude;
      if LBinPitch[LBin] >= 0 then
      begin
        LFeature.Chroma[LBinPitch[LBin]] := LFeature.Chroma[LBinPitch[LBin]] + LPower[LBin];
        LChromaTotal := LChromaTotal + LPower[LBin];
      end;
    end;
    if LTotal > 0 then
    begin
      LFeature.CentroidHz := LFeature.CentroidHz / LTotal;
    end;
    if Max(LTotal, LPreviousTotal) > 0 then
    begin
      LFeature.Flux := LFeature.Flux / Max(LTotal, LPreviousTotal);
    end;
    if LFrame >= AFirstFeature then
    begin
      LOutputIndex := LFrame - AFirstFeature;
      for LBand := 0 to High(ABands) do
      begin
        if LFeature.Silent or (Max(LTotal, LPreviousTotal) = 0) then
        begin
          ABands[LBand].PositiveFlux[LOutputIndex] := 0;
        end
        else
        begin
          ABands[LBand].PositiveFlux[LOutputIndex] :=
            ABands[LBand].PositiveFlux[LOutputIndex] / Max(LTotal, LPreviousTotal);
        end;
      end;
    end;
    LPreviousTotal := LTotal;
    if LFeature.Silent then
    begin
      LFeature.CentroidHz := 0;
      LFeature.Flux := 0;
    end;
    for LIndex := 0 to 11 do
    begin
      if LFeature.Silent or (LChromaTotal = 0) then
      begin
        LFeature.Chroma[LIndex] := 0;
      end
      else
      begin
        LFeature.Chroma[LIndex] := LFeature.Chroma[LIndex] / LChromaTotal;
      end;
    end;
    if LFrame >= AFirstFeature then
    begin
      LFeatures[LFrame - AFirstFeature] := LFeature;
    end;
  end;
  Result := LFeatures;
end;

function AnalyzeAudioSourceRange(const ASource: TAudioAnalysisSource;
  const AOptions: TAnalysisOptions; const AFirstFeature, AFeatureCount: Integer): TAudioFeatures;
var
  LBands: TAudioBandSeriesArray;
begin
  Result := AnalyzeAudioSourceRangeCore(ASource, AOptions, AFirstFeature,
    AFeatureCount, nil, LBands);
end;

function AnalyzeAudioSourceRangeBands(const ASource: TAudioAnalysisSource;
  const AOptions: TAnalysisOptions; const ABandEdges: TAnalysisBandEdges;
  const AFirstFeature, AFeatureCount: Integer): TAudioBandAnalysis;
var
  LIndex: Integer;
  LResult: TAudioBandAnalysis;
begin
  if ASource = nil then
  begin
    raise EAudio.Create('Analysis source is required');
  end;
  if (Length(ABandEdges) < 2) or (Length(ABandEdges) > MaximumAnalysisBands + 1) then
  begin
    raise EAudio.Create('Analysis requires one to 32 frequency bands');
  end;
  for LIndex := 0 to High(ABandEdges) do
  begin
    RequireFinite(ABandEdges[LIndex], 'Analysis band edge');
    if (ABandEdges[LIndex] < 0) or (ABandEdges[LIndex] > ASource.SampleRate / 2) then
    begin
      raise EAudio.Create('Analysis band edge outside source frequency range');
    end;
    if (LIndex > 0) and (ABandEdges[LIndex] <= ABandEdges[LIndex - 1]) then
    begin
      raise EAudio.Create('Analysis band edges must strictly increase');
    end;
  end;
  LResult := Default(TAudioBandAnalysis);
  LResult.Features := AnalyzeAudioSourceRangeCore(ASource, AOptions, AFirstFeature,
    AFeatureCount, ABandEdges, LResult.Bands);
  Result := LResult;
end;

function AnalyzeAudioBands(const AClip: TAudioClip; const AOptions: TAnalysisOptions;
  const ABandEdges: TAnalysisBandEdges): TAudioBandAnalysis;
var
  LSource: TClipAnalysisSource;
  LCount: Integer;
  LWork: Int64;
begin
  LSource := TClipAnalysisSource.Create(AClip);
  try
    PlanAudioAnalysis(LSource.FrameCount, LSource.Channels, AOptions, LCount, LWork);
    Result := AnalyzeAudioSourceRangeBands(LSource, AOptions, ABandEdges, 0, LCount);
  finally
    LSource.Free;
  end;
end;

function AnalyzeAudioSource(const ASource: TAudioAnalysisSource;
  const AOptions: TAnalysisOptions): TAudioFeatures;
var
  LCount: Integer;
  LWork: Int64;
begin
  if ASource = nil then
  begin
    raise EAudio.Create('Analysis source is required');
  end;
  PlanAudioAnalysis(ASource.FrameCount, ASource.Channels, AOptions, LCount, LWork);
  Result := AnalyzeAudioSourceRange(ASource, AOptions, 0, LCount);
end;

function AnalyzeAudio(const AClip: TAudioClip;
  const AOptions: TAnalysisOptions): TAudioFeatures;
var
  LSource: TClipAnalysisSource;
begin
  LSource := TClipAnalysisSource.Create(AClip);
  try
    Result := AnalyzeAudioSource(LSource, AOptions);
  finally
    LSource.Free;
  end;
end;

end.
