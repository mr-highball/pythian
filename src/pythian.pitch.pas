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

unit pythian.pitch;

{$mode delphi}
{$H+}

interface

uses
  pythian.audio;

const
  PitchEstimatorVersion = 1;
  MaximumPitchWindowFrames = 8192;
  MaximumPitchBatchWork = 268435456;

type
  TPitchStatus = (psEstimated, psSilence, psNoPeriod, psOutsideRange);
  TPitchOptions = record
    MinimumHz: Double;
    MaximumHz: Double;
    DifferenceThreshold: Double;
    SilenceRms: Double;
  end;
  TPitchEstimate = record
    Status: TPitchStatus;
    FrequencyHz: Double;
    PeriodFrames: Double;
    NormalizedDifference: Double;
    AcRms: Double;
    NearestMidi: Integer;
    CentsError: Double;
  end;
  TPitchEstimates = array of TPitchEstimate;
  TPitchNotes = array of Integer; { -1 means unknown, never a musical rest. }

function DefaultPitchOptions: TPitchOptions;
function PitchEstimateWork(const AWindowFrames, ASampleRate, AChannels, AChannel: Integer;
  const AOptions: TPitchOptions): Int64;
{ One selected interleaved channel; fixed half-window difference integration.
  YIN-derived difference, cumulative normalization and parabolic interpolation.
  Rejects weak minima instead of using YIN's unconditional fallback; no temporal
  best-local-estimate stage or claim of polyphonic source separation.
  Reference: de Cheveigne and Kawahara, JASA 111 (2002), DOI 10.1121/1.1458024. }
function EstimatePitch(const ASamples: TAudioSamples; const ASampleRate,
  AChannels, AChannel: Integer; const AOptions: TPitchOptions): TPitchEstimate;
{ Explicit centered measurement for time-varying periodic sources. Every lag's
  sample-pair support has the same center, (FrameCount - 1) / 2. Half-frame
  offsets average the two adjacent difference sums, without interpolating audio.
  Uses the same range/unknown policy; does not resolve octave or voice ambiguity.
  Existing prefix-integrated measurements and saved contracts are unchanged. }
function EstimatePitchCentered(const ASamples: TAudioSamples; const ASampleRate,
  AChannels, AChannel: Integer; const AOptions: TPitchOptions): TPitchEstimate;
{ Upper bound in squared-difference terms, at most twice the prefix work. }
function CenteredPitchEstimateWork(const AWindowFrames, ASampleRate, AChannels,
  AChannel: Integer; const AOptions: TPitchOptions): Int64;
{ Validates saved diagnostics against the declared measurement policy. }
procedure ValidatePitchEstimate(const AEstimate: TPitchEstimate;
  const ASampleRate: Integer; const AOptions: TPitchOptions);
{ Equal-tempered A4=440 admission with caller-selected tuning tolerance 0..50 cents.
  Non-estimated/out-of-MIDI-range/off-grid results remain unknown (-1). }
function AdmitPitchNote(const AEstimate: TPitchEstimate; const AMaximumCents: Double): Integer;

implementation

uses
  Math;

type
  TPitchValues = array of Double;

function DefaultPitchOptions: TPitchOptions;
begin
  Result.MinimumHz := 55;
  Result.MaximumHz := 1200;
  Result.DifferenceThreshold := 0.1;
  Result.SilenceRms := 0.00001;
end;

function PitchEstimateWork(const AWindowFrames, ASampleRate, AChannels, AChannel: Integer;
  const AOptions: TPitchOptions): Int64;
var
  LMaximumLag: Integer;
begin
  ValidateAudioFormat(ASampleRate, AChannels);
  RequireFinite(AOptions.MinimumHz, 'Minimum pitch frequency');
  RequireFinite(AOptions.MaximumHz, 'Maximum pitch frequency');
  RequireFinite(AOptions.DifferenceThreshold, 'Pitch difference threshold');
  RequireFinite(AOptions.SilenceRms, 'Pitch silence threshold');
  if (AWindowFrames < 16) or (AWindowFrames > MaximumPitchWindowFrames) or
    (AChannel < 0) or (AChannel >= AChannels) or
    (AOptions.MinimumHz <= 0) or (AOptions.MaximumHz <= AOptions.MinimumHz) or
    (AOptions.MaximumHz > ASampleRate / 2) or
    (AOptions.MinimumHz < ASampleRate / (MaximumPitchWindowFrames div 2 - 1)) or
    (AOptions.DifferenceThreshold <= 0) or (AOptions.DifferenceThreshold >= 1) or
    (AOptions.SilenceRms < 0) then
  begin
    raise EAudio.Create('Invalid bounded pitch geometry, range or threshold');
  end;
  LMaximumLag := Ceil(ASampleRate / AOptions.MinimumHz);
  if LMaximumLag + 1 > AWindowFrames div 2 then
  begin
    raise EAudio.Create('Pitch window does not cover the minimum frequency and interpolation neighbor');
  end;
  Result := Int64(AWindowFrames div 2) * (LMaximumLag + 1);
end;

procedure ValidatePitchEstimate(const AEstimate: TPitchEstimate;
  const ASampleRate: Integer; const AOptions: TPitchOptions);
var
  LMidi: Double;
  LNearest: Integer;
begin
  PitchEstimateWork(MaximumPitchWindowFrames, ASampleRate, 1, 0, AOptions);
  if (Ord(AEstimate.Status) > Ord(High(TPitchStatus))) or
    (AEstimate.NearestMidi < -1024) or (AEstimate.NearestMidi > 1024) then
  begin
    raise EAudio.Create('Pitch estimate status/note exceeds diagnostic bounds');
  end;
  RequireFinite(AEstimate.FrequencyHz, 'Pitch frequency');
  RequireFinite(AEstimate.PeriodFrames, 'Pitch period');
  RequireFinite(AEstimate.NormalizedDifference, 'Pitch normalized difference');
  RequireFinite(AEstimate.AcRms, 'Pitch AC RMS');
  RequireFinite(AEstimate.CentsError, 'Pitch cents error');
  if (AEstimate.NormalizedDifference < 0) or (AEstimate.AcRms < 0) or
    (AEstimate.FrequencyHz < 0) or (AEstimate.PeriodFrames < 0) then
  begin
    raise EAudio.Create('Pitch evidence contains negative measurements');
  end;
  if AEstimate.Status = psEstimated then
  begin
    if (AEstimate.FrequencyHz < AOptions.MinimumHz) or
      (AEstimate.FrequencyHz > AOptions.MaximumHz) or
      (AEstimate.AcRms <= AOptions.SilenceRms) or
      (AEstimate.NormalizedDifference >= AOptions.DifferenceThreshold) or
      (Abs(AEstimate.FrequencyHz * AEstimate.PeriodFrames - ASampleRate) > 0.00001) then
    begin
      raise EAudio.Create('Accepted pitch disagrees with measurement policy');
    end;
    LMidi := 69 + 12 * Log2(AEstimate.FrequencyHz / 440);
    LNearest := Floor(LMidi + 0.5);
    if (LNearest <> AEstimate.NearestMidi) or
      (Abs(100 * (LMidi - LNearest) - AEstimate.CentsError) > 0.000001) then
    begin
      raise EAudio.Create('Pitch tuning admission disagrees with measured frequency');
    end;
  end;
  if (AEstimate.Status = psSilence) <> (AEstimate.AcRms <= AOptions.SilenceRms) then
  begin
    raise EAudio.Create('Pitch silence status disagrees with measured AC energy');
  end;
  if AEstimate.Status <> psEstimated then
  begin
    if (AEstimate.NearestMidi <> -1) or (AEstimate.CentsError <> 0) then
    begin
      raise EAudio.Create('Unadmitted pitch estimate must not claim tuning');
    end;
    if AEstimate.Status = psOutsideRange then
    begin
      if (AEstimate.FrequencyHz <= 0) or (AEstimate.PeriodFrames <= 0) or
        ((AEstimate.FrequencyHz >= AOptions.MinimumHz) and
        (AEstimate.FrequencyHz <= AOptions.MaximumHz)) or
        (Abs(AEstimate.FrequencyHz * AEstimate.PeriodFrames - ASampleRate) > 0.00001) then
      begin
        raise EAudio.Create('Outside-range pitch diagnostics disagree');
      end;
    end
    else if (AEstimate.FrequencyHz <> 0) or (AEstimate.PeriodFrames <> 0) then
    begin
      raise EAudio.Create('Unresolved pitch must not claim a frequency or period');
    end;
  end;
end;

function DipOffset(const AValues: TPitchValues; const AIndex: Integer): Double;
var
  LDenominator: Double;
begin
  LDenominator := AValues[AIndex - 1] - 2 * AValues[AIndex] + AValues[AIndex + 1];
  Result := 0;
  if LDenominator > 0 then
  begin
    Result := 0.5 * (AValues[AIndex - 1] - AValues[AIndex + 1]) / LDenominator;
    Result := Max(-0.5, Min(0.5, Result));
  end;
end;

function MeasurePitch(const ASamples: TAudioSamples; const ASampleRate,
  AChannels, AChannel: Integer; const AOptions: TPitchOptions;
  const ACentered: Boolean): TPitchEstimate;
var
  LResult: TPitchEstimate;
  LValues: TPitchValues;
  LDifference: TPitchValues;
  LNormalized: TPitchValues;
  LFrames: Integer;
  LWindow: Integer;
  LMinLag: Integer;
  LMaxLag: Integer;
  LIndex: Integer;
  LLag: Integer;
  LSelected: Integer;
  LBest: Integer;
  LStart: Integer;
  LHalfFrame: Boolean;
  LMean: Double;
  LSum: Double;
  LDelta: Double;
  LOffset: Double;
  LMinimum: Double;
  LBestValue: Double;
  LMidi: Double;
begin
  ValidateAudioFormat(ASampleRate, AChannels);
  if Length(ASamples) mod AChannels <> 0 then
  begin
    raise EAudio.Create('Pitch samples contain a partial frame');
  end;
  LFrames := Length(ASamples) div AChannels;
  PitchEstimateWork(LFrames, ASampleRate, AChannels, AChannel, AOptions);
  LResult := Default(TPitchEstimate);
  LResult.Status := psNoPeriod;
  LResult.NearestMidi := -1;
  LResult.NormalizedDifference := 1;
  SetLength(LValues, LFrames);
  LMean := 0;
  for LIndex := 0 to High(ASamples) do
  begin
    RequireFinite(ASamples[LIndex], 'Pitch input sample');
  end;
  for LIndex := 0 to LFrames - 1 do
  begin
    LValues[LIndex] := ASamples[LIndex * AChannels + AChannel];
    LMean := LMean + LValues[LIndex];
  end;
  LMean := LMean / LFrames;
  LSum := 0;
  for LIndex := 0 to LFrames - 1 do
  begin
    LValues[LIndex] := LValues[LIndex] - LMean;
    LSum := LSum + Sqr(LValues[LIndex]);
  end;
  LResult.AcRms := Sqrt(LSum / LFrames);
  if LResult.AcRms <= AOptions.SilenceRms then
  begin
    LResult.Status := psSilence;
    Exit(LResult);
  end;
  LWindow := LFrames div 2;
  LMinLag := Max(2, Floor(ASampleRate / AOptions.MaximumHz));
  LMaxLag := Ceil(ASampleRate / AOptions.MinimumHz);
  SetLength(LDifference, LMaxLag + 2);
  SetLength(LNormalized, LMaxLag + 2);
  LNormalized[0] := 1;
  LSum := 0;
  for LLag := 1 to LMaxLag + 1 do
  begin
    LStart := 0;
    LHalfFrame := False;
    if ACentered then
    begin
      LStart := (LFrames - LWindow - LLag) div 2;
      LHalfFrame := Odd(LFrames - LWindow - LLag);
    end;
    for LIndex := 0 to LWindow - 1 do
    begin
      LDelta := LValues[LStart + LIndex] - LValues[LStart + LIndex + LLag];
      LDifference[LLag] := LDifference[LLag] + LDelta * LDelta;
      if LHalfFrame then
      begin
        LDelta := LValues[LStart + LIndex + 1] - LValues[LStart + LIndex + LLag + 1];
        LDifference[LLag] := LDifference[LLag] + LDelta * LDelta;
      end;
    end;
    if LHalfFrame then
    begin
      LDifference[LLag] := LDifference[LLag] * 0.5;
    end;
    LSum := LSum + LDifference[LLag];
    LNormalized[LLag] := 1;
    if LSum > 0 then
    begin
      LNormalized[LLag] := LDifference[LLag] * LLag / LSum;
    end;
  end;
  LSelected := -1;
  LBest := LMinLag;
  LBestValue := LNormalized[LBest];
  for LLag := LMinLag to LMaxLag do
  begin
    if LNormalized[LLag] < LBestValue then
    begin
      LBest := LLag;
      LBestValue := LNormalized[LLag];
    end;
    if (LNormalized[LLag] <= LNormalized[LLag - 1]) and
      (LNormalized[LLag] < LNormalized[LLag + 1]) then
    begin
      LOffset := DipOffset(LNormalized, LLag);
      LMinimum := Max(0, LNormalized[LLag] -
        0.25 * (LNormalized[LLag - 1] - LNormalized[LLag + 1]) * LOffset);
      if LMinimum < AOptions.DifferenceThreshold then
      begin
        LSelected := LLag;
        LResult.NormalizedDifference := LMinimum;
        Break;
      end;
    end;
  end;
  if LSelected < 0 then
  begin
    LResult.NormalizedDifference := Max(0, LBestValue);
    Exit(LResult);
  end;
  LResult.PeriodFrames := LSelected + DipOffset(LDifference, LSelected);
  LResult.FrequencyHz := ASampleRate / LResult.PeriodFrames;
  if (LResult.FrequencyHz < AOptions.MinimumHz) or
    (LResult.FrequencyHz > AOptions.MaximumHz) then
  begin
    LResult.Status := psOutsideRange;
    Exit(LResult);
  end;
  LResult.Status := psEstimated;
  LMidi := 69 + 12 * Log2(LResult.FrequencyHz / 440);
  LResult.NearestMidi := Floor(LMidi + 0.5);
  LResult.CentsError := 100 * (LMidi - LResult.NearestMidi);
  Result := LResult;
end;

function EstimatePitch(const ASamples: TAudioSamples; const ASampleRate,
  AChannels, AChannel: Integer; const AOptions: TPitchOptions): TPitchEstimate;
begin
  Result := MeasurePitch(ASamples, ASampleRate, AChannels, AChannel, AOptions, False);
end;

function EstimatePitchCentered(const ASamples: TAudioSamples; const ASampleRate,
  AChannels, AChannel: Integer; const AOptions: TPitchOptions): TPitchEstimate;
begin
  Result := MeasurePitch(ASamples, ASampleRate, AChannels, AChannel, AOptions, True);
end;

function CenteredPitchEstimateWork(const AWindowFrames, ASampleRate, AChannels,
  AChannel: Integer; const AOptions: TPitchOptions): Int64;
begin
  Result := 2 * PitchEstimateWork(AWindowFrames, ASampleRate, AChannels, AChannel, AOptions);
end;

function AdmitPitchNote(const AEstimate: TPitchEstimate; const AMaximumCents: Double): Integer;
begin
  RequireFinite(AMaximumCents, 'Pitch admission cents tolerance');
  if (AMaximumCents < 0) or (AMaximumCents > 50) then
  begin
    raise EAudio.Create('Pitch admission tolerance must be 0..50 cents');
  end;
  RequireFinite(AEstimate.CentsError, 'Estimated tuning error');
  Result := -1;
  if (AEstimate.Status = psEstimated) and (AEstimate.NearestMidi >= 0) and
    (AEstimate.NearestMidi <= 127) and (Abs(AEstimate.CentsError) <= AMaximumCents) then
  begin
    Result := AEstimate.NearestMidi;
  end;
end;

end.
