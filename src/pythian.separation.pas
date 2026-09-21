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
unit pythian.separation;

{$mode delphi}
{$H+}

interface

uses
  pythian.audio;

const
  MaximumSeparationCells = 8000000;
  MaximumSeparationWork = 2000000000;
  MaximumSeparationMedian = 63;

type
  THarmonicPercussiveOptions = record
    WindowFrames: Integer;
    HopFrames: Integer;
    HarmonicMedianFrames: Integer;
    PercussiveMedianBins: Integer;
  end;
  TSeparationPlan = record
    AnalysisFrames: Integer;
    FrequencyBins: Integer;
    SpectralCells: Integer;
    Work: Int64;
  end;

  { Offline median-filter harmonic/percussive separation. Centered periodic Hann
    windows zero-pad source edges. Shared stereo RMS-magnitude masks retain
    channel phase/panning, including opposite-polarity content. Soft masks use
    squared medians; both-zero bins split equally. Median edges clamp to the
    closest available frame/bin. Harmonic inverse STFT uses sum-of-squared-window
    normalization; percussive output is its complementary source residual.
    Both clips retain source rate, channels and exact frame count. These are
    spectral components, not isolated instruments or a monophonic declaration.
    Returned clip properties are borrowed: this object owns both clips. The
    source may be released after construction. No normalization or clipping.
    Based on FitzGerald, DAFx 2010, Harmonic/Percussive Separation using Median Filtering. }
  THarmonicPercussive = class
  private
    FHarmonic: TAudioClip;
    FPercussive: TAudioClip;
    FPlan: TSeparationPlan;
  public
    constructor Create(const ASource: TAudioClip; const AOptions: THarmonicPercussiveOptions);
    destructor Destroy; override;
    property Harmonic: TAudioClip read FHarmonic;
    property Percussive: TAudioClip read FPercussive;
    property Plan: TSeparationPlan read FPlan;
  end;

function DefaultHarmonicPercussiveOptions: THarmonicPercussiveOptions;
{ Validates geometry and conservative FFT/median work before large allocation.
  Window 64..16384 power-of-two, hop 1..window/2, odd medians 3..63. }
function PlanHarmonicPercussive(const ASourceFrames, AChannels: Integer;
  const AOptions: THarmonicPercussiveOptions): TSeparationPlan;

implementation

uses
  Math,
  pythian.fourier;

type
  TMedianValues = array[0..MaximumSeparationMedian - 1] of Double;

function DefaultHarmonicPercussiveOptions: THarmonicPercussiveOptions;
begin
  Result.WindowFrames := 4096;
  Result.HopFrames := 1024;
  Result.HarmonicMedianFrames := 17;
  Result.PercussiveMedianBins := 17;
end;

function PlanHarmonicPercussive(const ASourceFrames, AChannels: Integer;
  const AOptions: THarmonicPercussiveOptions): TSeparationPlan;
var
  LSize: Integer;
  LStages: Integer;
  LCells: Int64;
  LMedianWork: Int64;
begin
  LSize := AOptions.WindowFrames;
  if (ASourceFrames < 1) or (AChannels < 1) or (AChannels > 2) or
    (ASourceFrames > MaximumClipSamples div AChannels) or
    (LSize < 64) or (LSize > 16384) or ((LSize and (LSize - 1)) <> 0) or
    (AOptions.HopFrames < 1) or (AOptions.HopFrames > LSize div 2) or
    (AOptions.HarmonicMedianFrames < 3) or
    (AOptions.HarmonicMedianFrames > MaximumSeparationMedian) or
    not Odd(AOptions.HarmonicMedianFrames) or (AOptions.PercussiveMedianBins < 3) or
    (AOptions.PercussiveMedianBins > MaximumSeparationMedian) or
    not Odd(AOptions.PercussiveMedianBins) then
  begin
    raise EAudio.Create('Invalid bounded harmonic/percussive geometry or median lengths');
  end;
  Result := Default(TSeparationPlan);
  Result.AnalysisFrames := ASourceFrames div AOptions.HopFrames + 1;
  Result.FrequencyBins := LSize div 2 + 1;
  LCells := Int64(Result.AnalysisFrames) * Result.FrequencyBins;
  if LCells > MaximumSeparationCells then
  begin
    raise EAudio.Create('Harmonic/percussive spectrogram exceeds cell budget');
  end;
  Result.SpectralCells := LCells;
  LStages := 0;
  while LSize > 1 do
  begin
    Inc(LStages);
    LSize := LSize shr 1;
  end;
  LMedianWork := (Sqr(AOptions.HarmonicMedianFrames) + Sqr(AOptions.PercussiveMedianBins) +
    AOptions.HarmonicMedianFrames + AOptions.PercussiveMedianBins) div 2;
  Result.Work := Int64(Result.AnalysisFrames) * AOptions.WindowFrames * LStages * AChannels * 3 +
    LCells * LMedianWork;
  if Result.Work > MaximumSeparationWork then
  begin
    raise EAudio.Create('Harmonic/percussive processing exceeds FFT/median work budget');
  end;
end;

function Median(var AValues: TMedianValues; const ACount: Integer): Double;
var
  LIndex: Integer;
  LPosition: Integer;
  LValue: Double;
begin
  for LIndex := 1 to ACount - 1 do
  begin
    LValue := AValues[LIndex];
    LPosition := LIndex;
    while (LPosition > 0) and (AValues[LPosition - 1] > LValue) do
    begin
      AValues[LPosition] := AValues[LPosition - 1];
      Dec(LPosition);
    end;
    AValues[LPosition] := LValue;
  end;
  Result := AValues[ACount div 2];
end;

constructor THarmonicPercussive.Create(const ASource: TAudioClip;
  const AOptions: THarmonicPercussiveOptions);
var
  LMagnitudes: TFourierValues;
  LWindow: TFourierValues;
  LReal: TFourierValues;
  LImaginary: TFourierValues;
  LMask: TFourierValues;
  LAccumulated: TFourierValues;
  LWeights: TFourierValues;
  LHarmonic: TAudioSamples;
  LPercussive: TAudioSamples;
  LMedian: TMedianValues;
  LFrame: Integer;
  LChannel: Integer;
  LBin: Integer;
  LIndex: Integer;
  LStart: Integer;
  LSourceFrame: Integer;
  LPosition: Integer;
  LOther: Integer;
  LSize: Integer;
  LH: Double;
  LP: Double;
  LScale: Double;
  LValue: Double;
  LResidual: Double;

  procedure ReadSpectrum;
  var
    LRead: Integer;
    LAt: Integer;
  begin
    for LRead := 0 to LSize - 1 do
    begin
      LAt := LStart + LRead;
      LValue := 0;
      if (LAt >= 0) and (LAt < ASource.FrameCount) then
      begin
        LValue := ASource.SampleAt(LAt, LChannel);
      end;
      LReal[LRead] := LValue * LWindow[LRead];
      LImaginary[LRead] := 0;
    end;
    Fourier(LReal, LImaginary);
  end;

begin
  inherited Create;
  if ASource = nil then
  begin
    raise EAudio.Create('Harmonic/percussive separation requires a source clip');
  end;
  FPlan := PlanHarmonicPercussive(ASource.FrameCount, ASource.Channels, AOptions);
  LSize := AOptions.WindowFrames;
  SetLength(LMagnitudes, FPlan.SpectralCells);
  SetLength(LWindow, LSize);
  SetLength(LReal, LSize);
  SetLength(LImaginary, LSize);
  SetLength(LMask, FPlan.FrequencyBins);
  SetLength(LAccumulated, ASource.FrameCount * ASource.Channels);
  SetLength(LWeights, ASource.FrameCount);
  for LIndex := 0 to LSize - 1 do
  begin
    LWindow[LIndex] := 0.5 - 0.5 * Cos(2 * Pi * LIndex / LSize);
  end;
  for LFrame := 0 to FPlan.AnalysisFrames - 1 do
  begin
    LStart := LFrame * AOptions.HopFrames - LSize div 2;
    for LChannel := 0 to ASource.Channels - 1 do
    begin
      ReadSpectrum;
      for LBin := 0 to FPlan.FrequencyBins - 1 do
      begin
        LPosition := LFrame * FPlan.FrequencyBins + LBin;
        LMagnitudes[LPosition] := LMagnitudes[LPosition] +
          (Sqr(LReal[LBin]) + Sqr(LImaginary[LBin])) / ASource.Channels;
      end;
    end;
  end;
  for LIndex := 0 to High(LMagnitudes) do
  begin
    LMagnitudes[LIndex] := Sqrt(LMagnitudes[LIndex]);
  end;
  for LFrame := 0 to FPlan.AnalysisFrames - 1 do
  begin
    LStart := LFrame * AOptions.HopFrames - LSize div 2;
    for LBin := 0 to FPlan.FrequencyBins - 1 do
    begin
      for LIndex := 0 to AOptions.HarmonicMedianFrames - 1 do
      begin
        LOther := EnsureRange(LFrame + LIndex - AOptions.HarmonicMedianFrames div 2,
          0, FPlan.AnalysisFrames - 1);
        LMedian[LIndex] := LMagnitudes[LOther * FPlan.FrequencyBins + LBin];
      end;
      LH := Median(LMedian, AOptions.HarmonicMedianFrames);
      for LIndex := 0 to AOptions.PercussiveMedianBins - 1 do
      begin
        LOther := EnsureRange(LBin + LIndex - AOptions.PercussiveMedianBins div 2,
          0, FPlan.FrequencyBins - 1);
        LMedian[LIndex] := LMagnitudes[LFrame * FPlan.FrequencyBins + LOther];
      end;
      LP := Median(LMedian, AOptions.PercussiveMedianBins);
      LScale := Max(LH, LP);
      if LScale = 0 then
      begin
        LMask[LBin] := 0.5;
      end
      else
      begin
        LH := LH / LScale;
        LP := LP / LScale;
        LMask[LBin] := Sqr(LH) / (Sqr(LH) + Sqr(LP));
      end;
    end;
    for LChannel := 0 to ASource.Channels - 1 do
    begin
      ReadSpectrum;
      for LBin := 0 to LSize - 1 do
      begin
        LOther := Min(LBin, LSize - LBin);
        LReal[LBin] := LReal[LBin] * LMask[LOther];
        LImaginary[LBin] := LImaginary[LBin] * LMask[LOther];
      end;
      Fourier(LReal, LImaginary, True);
      for LIndex := 0 to LSize - 1 do
      begin
        LSourceFrame := LStart + LIndex;
        if (LSourceFrame >= 0) and (LSourceFrame < ASource.FrameCount) then
        begin
          LPosition := LSourceFrame * ASource.Channels + LChannel;
          LAccumulated[LPosition] := LAccumulated[LPosition] + LReal[LIndex] * LWindow[LIndex];
          if LChannel = 0 then
          begin
            LWeights[LSourceFrame] := LWeights[LSourceFrame] + Sqr(LWindow[LIndex]);
          end;
        end;
      end;
    end;
  end;
  SetLength(LHarmonic, Length(LAccumulated));
  SetLength(LPercussive, Length(LAccumulated));
  for LSourceFrame := 0 to ASource.FrameCount - 1 do
  begin
    if LWeights[LSourceFrame] <= 0 then
    begin
      raise EAudio.Create('Harmonic/percussive synthesis left an uncovered source frame');
    end;
    for LChannel := 0 to ASource.Channels - 1 do
    begin
      LPosition := LSourceFrame * ASource.Channels + LChannel;
      LValue := LAccumulated[LPosition] / LWeights[LSourceFrame];
      RequireFinite(LValue, 'Separated harmonic sample');
      if Abs(LValue) > MaxSingle then
      begin
        raise EAudio.Create('Separated harmonic sample exceeds native clip headroom');
      end;
      LHarmonic[LPosition] := LValue;
      LResidual := ASource.SampleAt(LSourceFrame, LChannel);
      LResidual := LResidual - LHarmonic[LPosition];
      if Abs(LResidual) > MaxSingle then
      begin
        raise EAudio.Create('Separated percussive sample exceeds native clip headroom');
      end;
      LPercussive[LPosition] := LResidual;
    end;
  end;
  FHarmonic := TAudioClip.Create(ASource.SampleRate, ASource.Channels, LHarmonic);
  FPercussive := TAudioClip.Create(ASource.SampleRate, ASource.Channels, LPercussive);
end;

destructor THarmonicPercussive.Destroy;
begin
  FPercussive.Free;
  FHarmonic.Free;
  inherited Destroy;
end;

end.
