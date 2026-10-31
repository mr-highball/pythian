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

unit pythian.music.observations;

{$mode delphi}
{$H+}

interface

uses pythian.audio, pythian.analysis, pythian.tonal, pythian.pitch.track,
  pythian.progress;

const
  MusicalObservationVersion = 1;
  MaximumMusicalObservationFrames = 2000000;
  MusicalObservationSeconds = 30;
  MusicalPitchSeconds = 8;
  MusicalPitchRate = 8000;

type
  TChannelPitchSpans = array of TPitchSpans;
  TMusicalObservations = record
    AnalysisOptions: TAnalysisOptions;
    Features: TAudioFeatures;
    { Same FFT pass, explicit low/mid/high spectral-change measurements.
      These are bands of the mix, never separated instrument tracks. }
    Bands: TAudioBandSeriesArray;
    Tonal: TTonalReport;
    ChannelPitches: TChannelPitchSpans;
    PitchFrames: Integer;
    MeanCentroidHz: Double;
    MinimumRms: Double;
    MaximumRms: Double;
  end;

{ Experimental measurements, never admitted notes, roles or key truth.
  Chroma and sound features cover the complete bounded clip. Each channel's
  periodic-pitch hypotheses cover only its first eight seconds at 8 kHz.
  Reuses primary analysis, tonal, resampling and pitch implementations.
  Callback exceptions propagate; no partial result is published. }
function MeasureMusicalObservations(const AClip: TAudioClip;
  const AProgress: TWorkProgressCallback = nil): TMusicalObservations;

implementation

uses Math, pythian.onset, pythian.resample;

function MeasureMusicalObservations(const AClip: TAudioClip;
  const AProgress: TWorkProgressCallback): TMusicalObservations;
var
  LResult: TMusicalObservations;
  LSamples: TAudioSamples;
  LMono: TAudioClip;
  LResampled: TAudioClip;
  LTrack: TPitchTrack;
  LPitchOptions: TPitchTrackOptions;
  LChannel: Integer;
  LFrame: Integer;
  LFrames: Integer;
  LFeature: TAudioFeature;
  LWeight: Double;
  LWeightSum: Double;
  LBandAnalysis: TAudioBandAnalysis;
begin
  if (AClip = nil) then
  begin
    raise EAudio.Create('Musical observation requires audio');
  end;
  if (AClip.FrameCount < 1) or
    (AClip.FrameCount > MaximumMusicalObservationFrames) or
    (AClip.FrameCount > Int64(AClip.SampleRate) * MusicalObservationSeconds) or
    (AClip.SampleRate < 8000) or (AClip.SampleRate > 192000) or
    not (AClip.Channels in [1, 2]) then
  begin
    raise EAudio.Create('Musical observation supports up to 30 seconds of mono/stereo at 8–192 kHz');
  end;
  LResult := Default(TMusicalObservations);
  LResult.AnalysisOptions := DefaultOnsetAnalysisOptions(AClip.SampleRate);
  LBandAnalysis := AnalyzeAudioBands(AClip, LResult.AnalysisOptions,
    [0, 200, 2000, AClip.SampleRate / 2], AProgress);
  LResult.Features := LBandAnalysis.Features;
  LResult.Bands := LBandAnalysis.Bands;
  LResult.Tonal := RankDiatonicFits(FeaturePitchClassWeights(LResult.Features,
    LResult.AnalysisOptions, AClip.FrameCount, True));
  LResult.MinimumRms := LResult.Features[0].Rms;
  LWeightSum := 0;
  for LFeature in LResult.Features do
  begin
    LResult.MinimumRms := Min(LResult.MinimumRms, LFeature.Rms);
    LResult.MaximumRms := Max(LResult.MaximumRms, LFeature.Rms);
    LWeight := Sqr(LFeature.Rms) *
      Min(LResult.AnalysisOptions.HopFrames, AClip.FrameCount - LFeature.StartFrame);
    LResult.MeanCentroidHz := LResult.MeanCentroidHz + LFeature.CentroidHz * LWeight;
    LWeightSum := LWeightSum + LWeight;
  end;
  if LWeightSum > 0 then
  begin
    LResult.MeanCentroidHz := LResult.MeanCentroidHz / LWeightSum;
  end;
  LFrames := Min(AClip.FrameCount, AClip.SampleRate * MusicalPitchSeconds);
  SetLength(LResult.ChannelPitches, AClip.Channels);
  for LChannel := 0 to AClip.Channels - 1 do
  begin
    ReportWork(AProgress, 'musical_pitch_channel', wuItems, LChannel, AClip.Channels);
    SetLength(LSamples, LFrames);
    for LFrame := 0 to LFrames - 1 do
    begin
      LSamples[LFrame] := AClip.SampleAt(LFrame, LChannel);
    end;
    LMono := TAudioClip.Create(AClip.SampleRate, 1, LSamples);
    LResampled := nil;
    LTrack := nil;
    try
      LResampled := ResampleClip(LMono, MusicalPitchRate, AProgress);
      LResult.PitchFrames := LResampled.FrameCount;
      LPitchOptions := DefaultPitchTrackOptions(MusicalPitchRate);
      if LResampled.FrameCount < PitchTrackRequiredFrames(MusicalPitchRate, LPitchOptions) then
      begin
        Continue;
      end;
      LTrack := TPitchTrack.Create(LResampled, 0,
        LPitchOptions, 0, AProgress);
      LResult.ChannelPitches[LChannel] := LTrack.CopySpans;
    finally
      LTrack.Free;
      LResampled.Free;
      LMono.Free;
    end;
  end;
  ReportWork(AProgress, 'musical_pitch_channel', wuItems, AClip.Channels, AClip.Channels);
  Result := LResult;
end;

end.
