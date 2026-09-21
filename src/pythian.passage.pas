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
unit pythian.passage;

{$mode delphi}
{$H+}

interface

uses
  pythian.audio,
  pythian.wave,
  pythian.analysis,
  pythian.granular,
  pythian.corpus;

const
  PassageVersion = 1;
  MaximumPassages = 4096;
  MaximumPassageSamples = 16000000;

type
  TPassageBounds = array of Integer;
  TPassageIndices = array of Integer;
  TRecordedPassage = record
    SourceIndex: Integer;
    StartFrame: Integer;
    FrameCount: Integer;
  end;
  TRecordedPassages = array of TRecordedPassage;

{ Full-loop bar grid from declared beat count and meter. Requires a looping
  source, complete bars and tempo/duration agreement within max(1 frame, 1 ppm).
  Frame zero as downbeat is an explicit assumption; metadata does not prove it.
  Uses rational floor boundaries, including the exact final source frame. }
function LoopBarBounds(const AInfo: TWaveLoopInfo;
  const ASourceFrames, ASampleRate: Integer): TPassageBounds;

{ Duration/energy aggregates of validated stored measurements. A feature owns
  its hop interval here, not its entire overlapping FFT window. Exact audio
  boundaries may cut that grid; these descriptors remain window estimates. }
function MeasurePassages(const ACorpus: TAcousticCorpusData; const ASourceIndex: Integer;
  const ABounds: TPassageBounds): TAudioFeatures;

{ Concatenate full recorded passages at unity playback rate. Optional linear
  fades lie inside edges at jumps and at output endpoints; contiguous source
  neighbors retain every original sample across their join. No time stretching. }
function RenderPassages(const ASource: TAudioClip; const ABounds: TPassageBounds;
  const AIndices: TPassageIndices; const AFadeFrames: Integer): TAudioClip; overload;

{ Explicit passages across 1..32 borrowed, same-format sources. Contiguity
  requires both source identity and adjacent frame coordinates. All source and
  output extents are admitted before allocating the detached output clip. }
function RenderPassages(const ASources: TAudioSources; const APassages: TRecordedPassages;
  const AFadeFrames: Integer): TAudioClip; overload;

implementation

uses
  Math;

procedure ValidateBounds(const ABounds: TPassageBounds; const ASourceFrames: Integer);
var
  LIndex: Integer;
begin
  if (Length(ABounds) < 2) or (Length(ABounds) > MaximumPassages + 1) then
  begin
    raise EAudio.Create('Passage boundaries require 1..4096 intervals');
  end;
  for LIndex := 0 to High(ABounds) do
  begin
    if (ABounds[LIndex] < 0) or (ABounds[LIndex] > ASourceFrames) then
    begin
      raise EAudio.Create('Passage boundary outside source');
    end;
    if (LIndex > 0) and (ABounds[LIndex] <= ABounds[LIndex - 1]) then
    begin
      raise EAudio.Create('Passage boundaries must increase strictly');
    end;
  end;
end;

function LoopBarBounds(const AInfo: TWaveLoopInfo;
  const ASourceFrames, ASampleRate: Integer): TPassageBounds;
var
  LCount: Integer;
  LIndex: Integer;
  LExpected: Double;
  LBounds: TPassageBounds;
begin
  ValidateAudioFormat(ASampleRate, 1);
  RequireFinite(AInfo.TempoBpm, 'Loop tempo');
  if not AInfo.Found or ((AInfo.Flags and 1) <> 0) or (ASourceFrames < 1) or
    (AInfo.BeatCount < 1) or (AInfo.BeatCount > 65536) or
    (AInfo.MeterNumerator < 1) or (AInfo.MeterNumerator > 64) or
    (AInfo.MeterDenominator < 1) or (AInfo.MeterDenominator > 64) or
    ((AInfo.MeterDenominator and (AInfo.MeterDenominator - 1)) <> 0) or
    (AInfo.TempoBpm < 1) or (AInfo.TempoBpm > 1000) then
  begin
    raise EAudio.Create('Loop declaration cannot define a bounded bar grid');
  end;
  if AInfo.BeatCount mod AInfo.MeterNumerator <> 0 then
  begin
    raise EAudio.Create('Loop declaration has an incomplete bar');
  end;
  LCount := AInfo.BeatCount div AInfo.MeterNumerator;
  if (LCount < 1) or (LCount > MaximumPassages) or (LCount > ASourceFrames) then
  begin
    raise EAudio.Create('Loop bar count exceeds bounds or sample resolution');
  end;
  LExpected := AInfo.BeatCount;
  LExpected := LExpected * 4 / AInfo.MeterDenominator *
    60 * ASampleRate / AInfo.TempoBpm;
  if Abs(LExpected - ASourceFrames) > Max(1, ASourceFrames * 1E-6) then
  begin
    raise EAudio.Create('Loop tempo and beat count disagree with source duration');
  end;
  SetLength(LBounds, LCount + 1);
  for LIndex := 0 to LCount do
  begin
    LBounds[LIndex] := Int64(ASourceFrames) * LIndex div LCount;
  end;
  Result := LBounds;
end;

function MeasurePassages(const ACorpus: TAcousticCorpusData; const ASourceIndex: Integer;
  const ABounds: TPassageBounds): TAudioFeatures;
var
  LRecording: TAcousticRecording;
  LResult: TAudioFeatures;
  LFeature: TAudioFeature;
  LHop: Integer;
  LPassage: Integer;
  LIndex: Integer;
  LPitch: Integer;
  LWeight: Integer;
  LEnergy: Double;
  LTotalEnergy: Double;
  LChromaSum: Double;
begin
  if ACorpus = nil then
  begin
    raise EAudio.Create('Passage measurements require a validated corpus');
  end;
  LRecording := ACorpus.RecordingAt(ASourceIndex);
  ValidateBounds(ABounds, LRecording.Info.FrameCount);
  LHop := ACorpus.Options.HopFrames;
  SetLength(LResult, Length(ABounds) - 1);
  for LPassage := 0 to High(LResult) do
  begin
    LFeature := Default(TAudioFeature);
    LFeature.StartFrame := ABounds[LPassage];
    LFeature.ValidFrames := ABounds[LPassage + 1] - ABounds[LPassage];
    LTotalEnergy := 0;
    for LIndex := ABounds[LPassage] div LHop to (ABounds[LPassage + 1] - 1) div LHop do
    begin
      LWeight := Min(ABounds[LPassage + 1], (LIndex + 1) * Int64(LHop)) -
        Max(ABounds[LPassage], LIndex * Int64(LHop));
      LEnergy := Sqr(LRecording.Features[LIndex].Rms) * LWeight;
      LTotalEnergy := LTotalEnergy + LEnergy;
      LFeature.Peak := Max(LFeature.Peak, LRecording.Features[LIndex].Peak);
      LFeature.CentroidHz := LFeature.CentroidHz +
        LRecording.Features[LIndex].CentroidHz * LEnergy;
      LFeature.Flux := LFeature.Flux + LRecording.Features[LIndex].Flux * LWeight;
      for LPitch := 0 to 11 do
      begin
        LFeature.Chroma[LPitch] := LFeature.Chroma[LPitch] +
          LRecording.Features[LIndex].Chroma[LPitch] * LEnergy;
      end;
    end;
    LFeature.Rms := Sqrt(LTotalEnergy / LFeature.ValidFrames);
    LFeature.Silent := LFeature.Rms <= ACorpus.Options.SilenceRms;
    if LFeature.Silent then
    begin
      LFeature.CentroidHz := 0;
      LFeature.Flux := 0;
      for LPitch := 0 to 11 do
      begin
        LFeature.Chroma[LPitch] := 0;
      end;
    end
    else
    begin
      LFeature.CentroidHz := LFeature.CentroidHz / LTotalEnergy;
      LFeature.Flux := LFeature.Flux / LFeature.ValidFrames;
      LChromaSum := 0;
      for LPitch := 0 to 11 do
      begin
        LChromaSum := LChromaSum + LFeature.Chroma[LPitch];
      end;
      if LChromaSum > 0 then
      begin
        for LPitch := 0 to 11 do
        begin
          LFeature.Chroma[LPitch] := LFeature.Chroma[LPitch] / LChromaSum;
        end;
      end;
    end;
    LResult[LPassage] := LFeature;
  end;
  Result := LResult;
end;

function RenderPassages(const ASource: TAudioClip; const ABounds: TPassageBounds;
  const AIndices: TPassageIndices; const AFadeFrames: Integer): TAudioClip;
var
  LSources: TAudioSources;
  LPassages: TRecordedPassages;
  LIndex: Integer;
begin
  if ASource = nil then
  begin
    raise EAudio.Create('Passage renderer requires source audio');
  end;
  ValidateBounds(ABounds, ASource.FrameCount);
  if (Length(AIndices) < 1) or (Length(AIndices) > MaximumPassages) then
  begin
    raise EAudio.Create('Passage sequence exceeds bounds');
  end;
  SetLength(LSources, 1);
  LSources[0] := ASource;
  SetLength(LPassages, Length(AIndices));
  for LIndex := 0 to High(AIndices) do
  begin
    if (AIndices[LIndex] < 0) or (AIndices[LIndex] >= High(ABounds)) then
    begin
      raise EAudio.Create('Unknown source passage');
    end;
    LPassages[LIndex].StartFrame := ABounds[AIndices[LIndex]];
    LPassages[LIndex].FrameCount := ABounds[AIndices[LIndex] + 1] -
      LPassages[LIndex].StartFrame;
  end;
  Result := RenderPassages(LSources, LPassages, AFadeFrames);
end;

function RenderPassages(const ASources: TAudioSources; const APassages: TRecordedPassages;
  const AFadeFrames: Integer): TAudioClip;
var
  LSource: TAudioClip;
  LPassage: TRecordedPassage;
  LSamples: TAudioSamples;
  LTotal: Int64;
  LIndex: Integer;
  LFrame: Integer;
  LChannel: Integer;
  LOffset: Integer;
  LStart: Integer;
  LLength: Integer;
  LFade: Integer;
  LFadeIn: Boolean;
  LFadeOut: Boolean;
  LGain: Double;
begin
  if (Length(ASources) < 1) or (Length(ASources) > MaximumCorpusSources) then
  begin
    raise EAudio.Create('Passage renderer requires 1..32 sources');
  end;
  for LIndex := 0 to High(ASources) do
  begin
    if ASources[LIndex] = nil then
    begin
      raise EAudio.Create('Passage source is missing');
    end;
    if (ASources[LIndex].SampleRate <> ASources[0].SampleRate) or
      (ASources[LIndex].Channels <> ASources[0].Channels) then
    begin
      raise EAudio.Create('Passage sources must share sample rate and channels');
    end;
  end;
  if (Length(APassages) < 1) or (Length(APassages) > MaximumPassages) or
    (AFadeFrames < 0) or (AFadeFrames > ASources[0].SampleRate) then
  begin
    raise EAudio.Create('Passage sequence or fade exceeds bounds');
  end;
  LTotal := 0;
  for LPassage in APassages do
  begin
    if (LPassage.SourceIndex < 0) or (LPassage.SourceIndex >= Length(ASources)) then
    begin
      raise EAudio.Create('Unknown passage source');
    end;
    LSource := ASources[LPassage.SourceIndex];
    if (LPassage.StartFrame < 0) or (LPassage.FrameCount < 1) or
      (LPassage.StartFrame > LSource.FrameCount) or
      (LPassage.FrameCount > LSource.FrameCount - LPassage.StartFrame) then
    begin
      raise EAudio.Create('Passage extent is outside source audio');
    end;
    Inc(LTotal, LPassage.FrameCount);
  end;
  if LTotal > MaximumPassageSamples div ASources[0].Channels then
  begin
    raise EAudio.Create('Passage output exceeds scalar-sample budget');
  end;
  SetLength(LSamples, LTotal * ASources[0].Channels);
  LOffset := 0;
  for LIndex := 0 to High(APassages) do
  begin
    LPassage := APassages[LIndex];
    LSource := ASources[LPassage.SourceIndex];
    LStart := LPassage.StartFrame;
    LLength := LPassage.FrameCount;
    LFade := Min(AFadeFrames, Max(1, LLength div 2));
    LFadeIn := (LIndex = 0) or
      (APassages[LIndex - 1].SourceIndex <> LPassage.SourceIndex) or
      (APassages[LIndex - 1].StartFrame + APassages[LIndex - 1].FrameCount <> LStart);
    LFadeOut := (LIndex = High(APassages)) or
      (APassages[LIndex + 1].SourceIndex <> LPassage.SourceIndex) or
      (LStart + LLength <> APassages[LIndex + 1].StartFrame);
    for LFrame := 0 to LLength - 1 do
    begin
      LGain := 1;
      if LFadeIn and (LFrame < LFade) then
      begin
        LGain := LFrame / LFade;
      end;
      if LFadeOut and (LLength - 1 - LFrame < LFade) then
      begin
        LGain := Min(LGain, (LLength - 1 - LFrame) / LFade);
      end;
      for LChannel := 0 to LSource.Channels - 1 do
      begin
        LSamples[(LOffset + LFrame) * LSource.Channels + LChannel] :=
          LSource.SampleAt(LStart + LFrame, LChannel) * LGain;
      end;
    end;
    Inc(LOffset, LLength);
  end;
  Result := TAudioClip.Create(ASources[0].SampleRate, ASources[0].Channels, LSamples);
end;

end.
