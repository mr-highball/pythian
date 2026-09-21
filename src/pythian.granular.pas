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
unit pythian.granular;

{$mode delphi}
{$H+}

interface

uses
  pythian.audio;

const
  GranularVersion = 1;
  MaximumGrainCount = 65536;
  MaximumGrainSamples = 16000000;
  MaximumGrainVisits = 64000000;

type
  TAudioSources = array of TAudioClip;
  TGrainWindow = (gwRectangular, gwHann);
  TGrainInterpolation = (giLinear, giSinc);

  TAudioGrain = record
    SourceIndex: Integer;
    SourceStartFrame: Integer;
    OutputStartFrame: Integer;
    FrameCount: Integer;
    { Source frames advanced per output frame. Zero holds one source sample.
      All source clips must match the output format. No implicit resampling. }
    PlaybackRate: Double;
    Gain: Double;
    Window: TGrainWindow;
  end;
  TAudioGrains = array of TAudioGrain;

  TGrainJoinProbe = record
    Incoming: TAudioSamples;
    Outgoing: TAudioSamples;
  end;

  TGrainRenderOptions = record
    SampleRate: Integer;
    Channels: Integer;
    MinimumFrames: Integer;
    NormalizeOverlap: Boolean;
    Interpolation: TGrainInterpolation;
  end;

function DefaultGrainRenderOptions(const ASampleRate, AChannels: Integer): TGrainRenderOptions;
{ Normalized squared difference of paired waveform probes; 1..128 finite samples.
  Equal signals score zero, opposite nonzero signals approach two. This is a
  local join diagnostic, not a perceptual quality score. }
function NormalizedGrainJoinError(const ALeft, ARight: TAudioSamples): Double;
{ Copies evenly spaced overlap probes; partial real-EOF samples are zero-padded.
  Validates every provided sample. Nonoverlapping grains compare endpoints. }
function ExtractGrainJoinProbe(const ASamples: TAudioSamples;
  const AWindowFrames, AHopFrames, AChannels, AProbeFrames: Integer): TGrainJoinProbe;
{ Sources are borrowed for this synchronous call; the output is detached and
  caller-owned. Linear or windowed-sinc interpolation supports rate variation.
  Sinc taps count toward the visit budget; rates zero and one retain exact samples.
  The sinc kernel can read neighboring source frames outside a grain's centers.
  Hann grains use
  sample-centered windows. Optional normalization divides by max(1, summed
  window weights), retaining boundary fades and each grain's explicit gain. }
function RenderGrains(const ASources: TAudioSources; const AGrains: TAudioGrains;
  const AOptions: TGrainRenderOptions): TAudioClip;

implementation

uses
  Math,
  pythian.resample;

function ExtractGrainJoinProbe(const ASamples: TAudioSamples;
  const AWindowFrames, AHopFrames, AChannels, AProbeFrames: Integer): TGrainJoinProbe;
var
  LIndex: Integer;
  LProbe: Integer;
  LChannel: Integer;
  LOffset: Integer;
  LPrevious: Integer;
  LOverlap: Integer;
  LCount: Integer;
begin
  if (AWindowFrames < 1) or (AWindowFrames > 65536) or
    (AHopFrames < 1) or (AHopFrames > AWindowFrames) or
    (AChannels < 1) or (AChannels > 2) or (AProbeFrames < 1) or (AProbeFrames > 64) then
  begin
    raise EAudio.Create('Grain join probe geometry invalid');
  end;
  if (Length(ASamples) < AChannels) or
    (Length(ASamples) > AWindowFrames * AChannels) or
    (Length(ASamples) mod AChannels <> 0) then
  begin
    raise EAudio.Create('Grain join probe samples have invalid extent');
  end;
  for LIndex := 0 to High(ASamples) do
  begin
    RequireFinite(ASamples[LIndex], 'Grain join sample');
  end;
  LOverlap := AWindowFrames - AHopFrames;
  LCount := Max(1, Min(AProbeFrames, LOverlap));
  Result := Default(TGrainJoinProbe);
  SetLength(Result.Incoming, LCount * AChannels);
  SetLength(Result.Outgoing, LCount * AChannels);
  for LProbe := 0 to LCount - 1 do
  begin
    LOffset := 0;
    if LCount > 1 then
    begin
      LOffset := LProbe * (LOverlap - 1) div (LCount - 1);
    end;
    LPrevious := AHopFrames + LOffset;
    if LOverlap = 0 then
    begin
      LPrevious := AWindowFrames - 1;
    end;
    for LChannel := 0 to AChannels - 1 do
    begin
      LIndex := LOffset * AChannels + LChannel;
      if LIndex < Length(ASamples) then
      begin
        Result.Incoming[LProbe * AChannels + LChannel] := ASamples[LIndex];
      end;
      LIndex := LPrevious * AChannels + LChannel;
      if LIndex < Length(ASamples) then
      begin
        Result.Outgoing[LProbe * AChannels + LChannel] := ASamples[LIndex];
      end;
    end;
  end;
end;

function NormalizedGrainJoinError(const ALeft, ARight: TAudioSamples): Double;
var
  LIndex: Integer;
  LLeft: Double;
  LRight: Double;
  LDifference: Double;
  LEnergy: Double;
begin
  if (Length(ALeft) < 1) or (Length(ALeft) > 128) or
    (Length(ALeft) <> Length(ARight)) then
  begin
    raise EAudio.Create('Join probes require 1..128 paired samples');
  end;
  LDifference := 0;
  LEnergy := 0;
  for LIndex := 0 to High(ALeft) do
  begin
    LLeft := ALeft[LIndex];
    LRight := ARight[LIndex];
    RequireFinite(LLeft, 'Left join probe');
    RequireFinite(LRight, 'Right join probe');
    LDifference := LDifference + Sqr(LLeft - LRight);
    LEnergy := LEnergy + Sqr(LLeft) + Sqr(LRight);
  end;
  Result := LDifference / (LEnergy + 1E-20);
end;

function DefaultGrainRenderOptions(const ASampleRate, AChannels: Integer): TGrainRenderOptions;
begin
  ValidateAudioFormat(ASampleRate, AChannels);
  Result.SampleRate := ASampleRate;
  Result.Channels := AChannels;
  Result.MinimumFrames := 0;
  Result.NormalizeOverlap := True;
  Result.Interpolation := giLinear;
end;

function RenderGrains(const ASources: TAudioSources; const AGrains: TAudioGrains;
  const AOptions: TGrainRenderOptions): TAudioClip;
var
  LMix: array of Double;
  LWeights: array of Double;
  LSamples: TAudioSamples;
  LGrain: TAudioGrain;
  LSource: TAudioClip;
  LFrames: Integer;
  LVisits: Int64;
  LIndex: Integer;
  LFrame: Integer;
  LChannel: Integer;
  LSourceFrame: Integer;
  LNextFrame: Integer;
  LOutputFrame: Integer;
  LSampleIndex: Integer;
  LPosition: Double;
  LFraction: Double;
  LWeight: Double;
  LValue: Double;
  LLeft: Double;
  LRight: Double;
  LSampler: TSincSampler;
  LTaps: Integer;
begin
  ValidateAudioFormat(AOptions.SampleRate, AOptions.Channels);
  if (AOptions.MinimumFrames < 0) or
    (AOptions.MinimumFrames > MaximumGrainSamples div AOptions.Channels) or
    (Length(AGrains) > MaximumGrainCount) or (Length(ASources) > MaximumGrainCount) then
  begin
    raise EAudio.Create('Granular output or event count exceeds its budget');
  end;
  LFrames := AOptions.MinimumFrames;
  LVisits := 0;
  for LIndex := 0 to High(AGrains) do
  begin
    LGrain := AGrains[LIndex];
    RequireFinite(LGrain.PlaybackRate, 'Grain playback rate');
    RequireFinite(LGrain.Gain, 'Grain gain');
    if (LGrain.SourceIndex < 0) or (LGrain.SourceIndex >= Length(ASources)) then
    begin
      raise EAudio.Create('Grain source index outside source list');
    end;
    LSource := ASources[LGrain.SourceIndex];
    if LSource = nil then
    begin
      raise EAudio.Create('Grain source clip is required');
    end;
    if (LSource.SampleRate <> AOptions.SampleRate) or
      (LSource.Channels <> AOptions.Channels) then
    begin
      raise EAudio.Create('Grain sources must match output sample rate and channels');
    end;
    if (LGrain.SourceStartFrame < 0) or (LGrain.SourceStartFrame >= LSource.FrameCount) or
      (LGrain.OutputStartFrame < 0) or (LGrain.FrameCount < 1) or
      (LGrain.PlaybackRate < 0) or (LGrain.PlaybackRate > 8) or
      (Abs(LGrain.Gain) > 16) then
    begin
      raise EAudio.Create('Grain parameters outside rendering contract');
    end;
    if Int64(LGrain.OutputStartFrame) + LGrain.FrameCount >
      MaximumGrainSamples div AOptions.Channels then
    begin
      raise EAudio.Create('Grain extends beyond output sample budget');
    end;
    LPosition := LGrain.SourceStartFrame + (LGrain.FrameCount - 1) * LGrain.PlaybackRate;
    if LPosition > LSource.FrameCount - 1 then
    begin
      raise EAudio.Create('Grain extends beyond source frames');
    end;
    LFrames := Max(LFrames, LGrain.OutputStartFrame + LGrain.FrameCount);
    LTaps := 1;
    if (AOptions.Interpolation = giSinc) and (LGrain.PlaybackRate <> 0) and
      (LGrain.PlaybackRate <> 1) then
    begin
      LTaps := SincTapBudget(LGrain.PlaybackRate);
    end;
    Inc(LVisits, Int64(LGrain.FrameCount) * AOptions.Channels * LTaps);
    if LVisits > MaximumGrainVisits then
    begin
      raise EAudio.Create('Granular rendering exceeds sample-visit budget');
    end;
  end;

  SetLength(LMix, LFrames * AOptions.Channels);
  SetLength(LWeights, LFrames);
  for LIndex := 0 to High(AGrains) do
  begin
    LGrain := AGrains[LIndex];
    LSource := ASources[LGrain.SourceIndex];
    LSampler := nil;
    if (AOptions.Interpolation = giSinc) and (LGrain.PlaybackRate <> 0) and
      (LGrain.PlaybackRate <> 1) then
    begin
      LSampler := TSincSampler.Create(LSource, LGrain.PlaybackRate);
    end;
    try
      for LFrame := 0 to LGrain.FrameCount - 1 do
      begin
        LPosition := LGrain.SourceStartFrame + LFrame * LGrain.PlaybackRate;
        LSourceFrame := Floor(LPosition);
        LNextFrame := Min(LSourceFrame + 1, LSource.FrameCount - 1);
        LFraction := LPosition - LSourceFrame;
        LOutputFrame := LGrain.OutputStartFrame + LFrame;
        LWeight := 1;
        if LGrain.Window = gwHann then
        begin
          LWeight := Sqr(Sin(Pi * (LFrame + 0.5) / LGrain.FrameCount));
        end;
        LWeights[LOutputFrame] := LWeights[LOutputFrame] + LWeight;
        if LSampler <> nil then
        begin
          LSampler.ReadFrame(LPosition, LLeft, LRight);
        end;
        for LChannel := 0 to AOptions.Channels - 1 do
        begin
          if LSampler = nil then
          begin
            LValue := (1 - LFraction) * LSource.SampleAt(LSourceFrame, LChannel) +
              LFraction * LSource.SampleAt(LNextFrame, LChannel);
          end
          else if LChannel = 0 then
          begin
            LValue := LLeft;
          end
          else
          begin
            LValue := LRight;
          end;
          LSampleIndex := LOutputFrame * AOptions.Channels + LChannel;
          LMix[LSampleIndex] := LMix[LSampleIndex] + LValue * LWeight * LGrain.Gain;
        end;
      end;
    finally
      LSampler.Free;
    end;
  end;
  SetLength(LSamples, Length(LMix));
  for LFrame := 0 to LFrames - 1 do
  begin
    LWeight := 1;
    if AOptions.NormalizeOverlap then
    begin
      LWeight := Max(1, LWeights[LFrame]);
    end;
    for LChannel := 0 to AOptions.Channels - 1 do
    begin
      LSampleIndex := LFrame * AOptions.Channels + LChannel;
      LValue := LMix[LSampleIndex] / LWeight;
      RequireFinite(LValue, 'Grain mix');
      if Abs(LValue) > MaxSingle then
      begin
        raise EAudio.Create('Grain mix exceeds Single range');
      end;
      LSamples[LSampleIndex] := LValue;
    end;
  end;
  Result := TAudioClip.Create(AOptions.SampleRate, AOptions.Channels, LSamples);
end;

end.
