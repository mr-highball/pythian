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
unit pythian.onset;

{$mode delphi}
{$H+}

interface

uses
  pythian.audio,
  pythian.analysis,
  pythian.activity;

const
  OnsetLocationVersion = 1;
  MaximumOnsetEnergyWindow = 4096;
  MaximumOnsetLocationWork = 100000000;
  MaximumEnvelopePoints = 65536;

type
  TOnsetLocationOptions = record
    EnergyWindowFrames: Integer;
    MinimumEnergyRise: Double;
    MinimumContrast: Double;
  end;
  TOnsetLocation = record
    FeatureIndex: Integer;
    WindowStartFrame: Integer;
    WindowFrameCount: Integer;
    Frame: Integer;
    BeforeRms: Double;
    AfterRms: Double;
    EnergyRise: Double;
    Contrast: Double;
    Resolved: Boolean;
    ContextClipped: Boolean;
    SearchBoundary: Boolean;
  end;
  TOnsetLocations = array of TOnsetLocation;

  TEnergyFallOptions = record
    EnergyWindowFrames: Integer;
    MinimumEnergyFall: Double;
    MinimumContrast: Double;
  end;
  TEnergyFallLocation = record
    WindowStartFrame: Integer;
    WindowFrameCount: Integer;
    Frame: Integer;
    BeforeRms: Double;
    AfterRms: Double;
    EnergyFall: Double;
    Contrast: Double;
    Resolved: Boolean;
    ContextClipped: Boolean;
    SearchBoundary: Boolean;
  end;

  TEnvelopeValleyOptions = record
    EnergyWindowFrames: Integer;
    HopFrames: Integer;
    MinimumRadiusPoints: Integer;
    PeakRadiusPoints: Integer;
    MinimumPeakRms: Double;
    MinimumDepth: Double;
  end;
  TEnvelopeValley = record
    Frame: Integer;
    LeftPeakFrame: Integer;
    RightPeakFrame: Integer;
    Rms: Double;
    LeftPeakRms: Double;
    RightPeakRms: Double;
    Depth: Double;
  end;
  TEnvelopeValleys = array of TEnvelopeValley;

function DefaultEnvelopeValleyOptions(const ASampleRate: Integer): TEnvelopeValleyOptions;
{ Measure local RMS valleys with peaks on both sides. This is envelope evidence,
  not note-onset admission: modulation, tremolo and noise can also create valleys.
  Windows start at k*HopFrames; centers add EnergyWindowFrames div 2. Each channel
  contributes power independently. Only complete windows and peak neighborhoods
  are used; incomplete context supplies no candidate. Equal minima/peaks select
  the earliest point. Depth is 1 - valley/min(left peak, right peak).
  All radii are in envelope points. Work is preflighted before allocation/reads;
  the clip is borrowed and the returned measurements are detached. }
function MeasureEnvelopeValleys(const AClip: TAudioClip;
  const AOptions: TEnvelopeValleyOptions): TEnvelopeValleys;

function DefaultOnsetLocationOptions(const ASampleRate: Integer): TOnsetLocationOptions;

{ Independent timing-analysis preset. Chooses the smallest power-of-two window
  covering at least 20 ms (minimum 64 frames), with a quarter-window hop.
  Does not replace the wider default used for acoustic learning and archives. }
function DefaultOnsetAnalysisOptions(const ASampleRate: Integer): TAnalysisOptions;

{ Finds the largest positive difference between adjacent mean-power windows
  around a source frame. Channels contribute power independently. Search covers
  [AStartFrame, AStartFrame+AFrameCount); equal maxima choose the earlier frame.
  Outside-clip context is zero-padded and explicitly marked ContextClipped.
  SearchBoundary marks a maximum at either edge of the searched interval.
  Returns Frame=-1 when rise/contrast do not pass the thresholds. Strengths are
  measurements, not probabilities. Soft attacks may resolve near their steepest
  energy rise; constant-energy pitch changes may remain unresolved. }
function LocateOnsetWindow(const AClip: TAudioClip; const AStartFrame, AFrameCount: Integer;
  const AOptions: TOnsetLocationOptions): TOnsetLocation;

{ Defaults: 20-ms adjacent power windows (capped at 4096 frames), minimum
  mean-power fall 1E-6 and contrast 0.2. This is not a note-release rule. }
function DefaultEnergyFallOptions(const ASampleRate: Integer): TEnergyFallOptions;
{ Largest positive before-minus-after mean power in the requested interval.
  Same borrowed clip, stereo power, earliest-tie, bounded sliding work and
  explicit clipped/search-edge semantics as onset localization. RMS includes DC.
  No qualifying fall returns Frame=-1; measured levels remain available when a
  positive candidate fails thresholds. A dip, tremolo or transition can resolve
  without ending a note. Never infers silence, ownership or a synthesis gate. }
function LocateEnergyFallWindow(const AClip: TAudioClip;
  const AStartFrame, AFrameCount: Integer;
  const AOptions: TEnergyFallOptions): TEnergyFallLocation;

{ One detached result per original activity onset candidate, in feature order.
  Does not change source frames, activity labels or persisted feature/model data.
  Overlapping candidates may resolve to the same point; they are not merged.
  Features must describe this clip; byte/source identity remains caller-owned. }
function LocalizeAcousticOnsets(const AClip: TAudioClip; const AFeatures: TAudioFeatures;
  const AAnalysis: TAnalysisOptions; const AActivity: TActivityOptions;
  const AOptions: TOnsetLocationOptions): TOnsetLocations;

implementation

uses
  Math;

procedure ValidateOptions(const AOptions: TOnsetLocationOptions);
begin
  RequireFinite(AOptions.MinimumEnergyRise, 'Minimum directed energy change');
  RequireFinite(AOptions.MinimumContrast, 'Minimum energy contrast');
  if (AOptions.EnergyWindowFrames < 1) or
    (AOptions.EnergyWindowFrames > MaximumOnsetEnergyWindow) or
    (AOptions.MinimumEnergyRise < 0) or (AOptions.MinimumContrast < 0) or
    (AOptions.MinimumContrast > 1) then
  begin
    raise EAudio.Create('Energy-edge localization options exceed their bounds');
  end;
end;

function DefaultOnsetLocationOptions(const ASampleRate: Integer): TOnsetLocationOptions;
begin
  ValidateAudioFormat(ASampleRate, 1);
  Result.EnergyWindowFrames := Max(1, ASampleRate div 200);
  Result.MinimumEnergyRise := 0.000001;
  Result.MinimumContrast := 0.2;
end;

function DefaultOnsetAnalysisOptions(const ASampleRate: Integer): TAnalysisOptions;
begin
  ValidateAudioFormat(ASampleRate, 1);
  Result := DefaultAnalysisOptions;
  Result.WindowFrames := 64;
  while Result.WindowFrames * 50 < ASampleRate do
  begin
    Result.WindowFrames := Result.WindowFrames * 2;
  end;
  Result.HopFrames := Result.WindowFrames div 4;
end;

function WindowWork(const AFrames, AChannels: Integer;
  const AOptions: TOnsetLocationOptions): Int64;
begin
  Result := (Int64(AFrames) * 3 + Int64(AOptions.EnergyWindowFrames) * 2) * AChannels;
end;

function FramePower(const AClip: TAudioClip; const AFrame: Integer): Double;
var
  LChannel: Integer;
  LValue: Double;
begin
  Result := 0;
  if (AFrame < 0) or (AFrame >= AClip.FrameCount) then
  begin
    Exit;
  end;
  for LChannel := 0 to AClip.Channels - 1 do
  begin
    LValue := AClip.SampleAt(AFrame, LChannel);
    Result := Result + LValue * LValue;
  end;
  Result := Result / AClip.Channels;
end;

function DefaultEnvelopeValleyOptions(const ASampleRate: Integer): TEnvelopeValleyOptions;
begin
  ValidateAudioFormat(ASampleRate, 1);
  Result.EnergyWindowFrames := Max(1, ASampleRate div 100);
  Result.HopFrames := Max(1, ASampleRate div 500);
  Result.MinimumRadiusPoints := Max(1, Round(ASampleRate * 0.02 / Result.HopFrames));
  Result.PeakRadiusPoints := Max(1, Round(ASampleRate * 0.08 / Result.HopFrames));
  Result.MinimumPeakRms := 0.0001;
  Result.MinimumDepth := 0.35;
end;

function MeasureEnvelopeValleys(const AClip: TAudioClip;
  const AOptions: TEnvelopeValleyOptions): TEnvelopeValleys;
var
  LEnergy: array of Double;
  LValleys: TEnvelopeValleys;
  LPoints: Integer;
  LCount: Integer;
  LLeft: Integer;
  LRight: Integer;
  LFrame: Integer;
  LWork: Int64;
  LSum: Double;
  LScale: Double;
  LDepth: Double;
  LMinimum: Boolean;
  I: Integer;
  J: Integer;
begin
  if AClip = nil then
  begin
    raise EAudio.Create('Envelope valleys require a source clip');
  end;
  RequireFinite(AOptions.MinimumPeakRms, 'Envelope peak RMS floor');
  RequireFinite(AOptions.MinimumDepth, 'Envelope valley depth');
  if (AOptions.EnergyWindowFrames < 1) or
    (AOptions.EnergyWindowFrames > MaximumOnsetEnergyWindow) or
    (AOptions.HopFrames < 1) or (AOptions.HopFrames > MaximumOnsetEnergyWindow) or
    (AOptions.MinimumRadiusPoints < 1) or (AOptions.MinimumRadiusPoints > 128) or
    (AOptions.PeakRadiusPoints < AOptions.MinimumRadiusPoints) or
    (AOptions.PeakRadiusPoints > 1024) or (AOptions.MinimumPeakRms < 0) or
    (AOptions.MinimumDepth <= 0) or (AOptions.MinimumDepth > 1) then
  begin
    raise EAudio.Create('Envelope valley options exceed their bounds');
  end;
  Result := nil;
  if AClip.FrameCount < AOptions.EnergyWindowFrames then
  begin
    Exit;
  end;
  LPoints := (AClip.FrameCount - AOptions.EnergyWindowFrames) div AOptions.HopFrames + 1;
  LWork := Int64(LPoints) * (Int64(AOptions.EnergyWindowFrames) * AClip.Channels +
    2 * AOptions.MinimumRadiusPoints + 1 + 2 * AOptions.PeakRadiusPoints);
  if (LPoints > MaximumEnvelopePoints) or (LWork > MaximumOnsetLocationWork) then
  begin
    raise EAudio.Create('Envelope valleys exceed point or sample/neighborhood work budget');
  end;
  if LPoints <= 2 * AOptions.PeakRadiusPoints then
  begin
    Exit;
  end;
  SetLength(LEnergy, LPoints);
  for I := 0 to LPoints - 1 do
  begin
    LFrame := I * AOptions.HopFrames;
    LSum := 0;
    for J := 0 to AOptions.EnergyWindowFrames - 1 do
    begin
      LSum := LSum + FramePower(AClip, LFrame + J);
    end;
    LEnergy[I] := Sqrt(LSum / AOptions.EnergyWindowFrames);
  end;
  SetLength(LValleys, LPoints);
  LCount := 0;
  for I := AOptions.PeakRadiusPoints to LPoints - AOptions.PeakRadiusPoints - 1 do
  begin
    LMinimum := True;
    for J := I - AOptions.MinimumRadiusPoints to I + AOptions.MinimumRadiusPoints do
    begin
      if (LEnergy[J] < LEnergy[I]) or ((J < I) and (LEnergy[J] = LEnergy[I])) then
      begin
        LMinimum := False;
        Break;
      end;
    end;
    if not LMinimum then
    begin
      Continue;
    end;
    LLeft := I - AOptions.PeakRadiusPoints;
    LRight := I + 1;
    for J := LLeft + 1 to I - 1 do
    begin
      if LEnergy[J] > LEnergy[LLeft] then
      begin
        LLeft := J;
      end;
    end;
    for J := LRight + 1 to I + AOptions.PeakRadiusPoints do
    begin
      if LEnergy[J] > LEnergy[LRight] then
      begin
        LRight := J;
      end;
    end;
    LScale := LEnergy[LLeft];
    if LEnergy[LRight] < LScale then
    begin
      LScale := LEnergy[LRight];
    end;
    if (LScale <= AOptions.MinimumPeakRms) or (LScale = 0) then
    begin
      Continue;
    end;
    LDepth := 1 - LEnergy[I] / LScale;
    if LDepth < AOptions.MinimumDepth then
    begin
      Continue;
    end;
    LValleys[LCount].Frame := I * AOptions.HopFrames + AOptions.EnergyWindowFrames div 2;
    LValleys[LCount].LeftPeakFrame := LLeft * AOptions.HopFrames + AOptions.EnergyWindowFrames div 2;
    LValleys[LCount].RightPeakFrame := LRight * AOptions.HopFrames + AOptions.EnergyWindowFrames div 2;
    LValleys[LCount].Rms := LEnergy[I];
    LValleys[LCount].LeftPeakRms := LEnergy[LLeft];
    LValleys[LCount].RightPeakRms := LEnergy[LRight];
    LValleys[LCount].Depth := LDepth;
    Inc(LCount);
  end;
  SetLength(LValleys, LCount);
  Result := LValleys;
end;

{ Internal carrier stores the positive directed change in EnergyRise. Public
  fall results copy it into EnergyFall; onset callers keep their original API. }
function LocateEnergyWindow(const AClip: TAudioClip; const AStartFrame, AFrameCount: Integer;
  const AOptions: TOnsetLocationOptions; const AFalling: Boolean): TOnsetLocation;
var
  LBefore: Double;
  LAfter: Double;
  LCurrent: Double;
  LRise: Double;
  LBestRise: Double;
  LBestBefore: Double;
  LBestAfter: Double;
  LFrame: Integer;
  LOffset: Integer;
  LBestFrame: Integer;
  LWindow: Integer;
  LCandidate: TOnsetLocation;
begin
  ValidateOptions(AOptions);
  if AClip = nil then
  begin
    raise EAudio.Create('Energy-edge localization requires a source clip');
  end;
  if (AStartFrame < 0) or (AFrameCount < 1) or
    (AStartFrame > AClip.FrameCount) or
    (AFrameCount > AClip.FrameCount - AStartFrame) then
  begin
    raise EAudio.Create('Energy-edge search window is outside the source');
  end;
  if WindowWork(AFrameCount, AClip.Channels, AOptions) > MaximumOnsetLocationWork then
  begin
    raise EAudio.Create('Energy-edge search exceeds the PCM work budget');
  end;
  LCandidate := Default(TOnsetLocation);
  LCandidate.FeatureIndex := -1;
  LCandidate.Frame := -1;
  LCandidate.WindowStartFrame := AStartFrame;
  LCandidate.WindowFrameCount := AFrameCount;
  LWindow := AOptions.EnergyWindowFrames;
  LBefore := 0;
  LAfter := 0;
  for LOffset := 0 to LWindow - 1 do
  begin
    LBefore := LBefore + FramePower(AClip, AStartFrame - 1 - LOffset);
    LAfter := LAfter + FramePower(AClip, AStartFrame + LOffset);
  end;
  LBestRise := 0;
  LBestBefore := 0;
  LBestAfter := 0;
  LBestFrame := -1;
  for LFrame := AStartFrame to AStartFrame + AFrameCount - 1 do
  begin
    { Clamping removes tiny negative residues from sliding sum subtraction. }
    LBefore := Max(0, LBefore);
    LAfter := Max(0, LAfter);
    LRise := LAfter - LBefore;
    if AFalling then
    begin
      LRise := -LRise;
    end;
    if LRise > LBestRise then
    begin
      LBestRise := LRise;
      LBestBefore := LBefore;
      LBestAfter := LAfter;
      LBestFrame := LFrame;
    end;
    LCurrent := FramePower(AClip, LFrame);
    LBefore := LBefore + LCurrent - FramePower(AClip, LFrame - LWindow);
    LAfter := LAfter - LCurrent + FramePower(AClip, LFrame + LWindow);
  end;
  if LBestFrame >= 0 then
  begin
    LCandidate.BeforeRms := Sqrt(LBestBefore / LWindow);
    LCandidate.AfterRms := Sqrt(LBestAfter / LWindow);
    LCandidate.EnergyRise := LBestRise / LWindow;
    LCandidate.Contrast := LBestRise / (LBestBefore + LBestAfter);
    LCandidate.ContextClipped := (LBestFrame < LWindow) or
      (LBestFrame > AClip.FrameCount - LWindow);
    LCandidate.SearchBoundary := (LBestFrame = AStartFrame) or
      (LBestFrame = AStartFrame + AFrameCount - 1);
    LCandidate.Resolved := (LCandidate.EnergyRise >= AOptions.MinimumEnergyRise) and
      (LCandidate.Contrast >= AOptions.MinimumContrast);
    if LCandidate.Resolved then
    begin
      LCandidate.Frame := LBestFrame;
    end;
  end;
  Result := LCandidate;
end;

function LocateOnsetWindow(const AClip: TAudioClip; const AStartFrame, AFrameCount: Integer;
  const AOptions: TOnsetLocationOptions): TOnsetLocation;
begin
  Result := LocateEnergyWindow(AClip, AStartFrame, AFrameCount, AOptions, False);
end;

function DefaultEnergyFallOptions(const ASampleRate: Integer): TEnergyFallOptions;
begin
  ValidateAudioFormat(ASampleRate, 1);
  Result.EnergyWindowFrames := Min(MaximumOnsetEnergyWindow, Max(1, ASampleRate div 50));
  Result.MinimumEnergyFall := 0.000001;
  Result.MinimumContrast := 0.2;
end;

function LocateEnergyFallWindow(const AClip: TAudioClip;
  const AStartFrame, AFrameCount: Integer;
  const AOptions: TEnergyFallOptions): TEnergyFallLocation;
var
  LOptions: TOnsetLocationOptions;
  LLocation: TOnsetLocation;
begin
  LOptions.EnergyWindowFrames := AOptions.EnergyWindowFrames;
  LOptions.MinimumEnergyRise := AOptions.MinimumEnergyFall;
  LOptions.MinimumContrast := AOptions.MinimumContrast;
  LLocation := LocateEnergyWindow(AClip, AStartFrame, AFrameCount, LOptions, True);
  Result := Default(TEnergyFallLocation);
  Result.WindowStartFrame := LLocation.WindowStartFrame;
  Result.WindowFrameCount := LLocation.WindowFrameCount;
  Result.Frame := LLocation.Frame;
  Result.BeforeRms := LLocation.BeforeRms;
  Result.AfterRms := LLocation.AfterRms;
  Result.EnergyFall := LLocation.EnergyRise;
  Result.Contrast := LLocation.Contrast;
  Result.Resolved := LLocation.Resolved;
  Result.ContextClipped := LLocation.ContextClipped;
  Result.SearchBoundary := LLocation.SearchBoundary;
end;

function LocalizeAcousticOnsets(const AClip: TAudioClip; const AFeatures: TAudioFeatures;
  const AAnalysis: TAnalysisOptions; const AActivity: TActivityOptions;
  const AOptions: TOnsetLocationOptions): TOnsetLocations;
var
  LActivity: TAcousticActivity;
  LCandidate: TOnsetLocations;
  LIndex: Integer;
  LCount: Integer;
  LOutput: Integer;
  LWork: Int64;
begin
  ValidateOptions(AOptions);
  if AClip = nil then
  begin
    raise EAudio.Create('Onset localization requires a source clip');
  end;
  LActivity := AnalyzeAcousticActivity(AFeatures, AAnalysis, AClip.FrameCount, AActivity);
  LCount := 0;
  LWork := 0;
  for LIndex := 0 to High(LActivity.Actions) do
  begin
    if LActivity.Actions[LIndex] = aaOnset then
    begin
      Inc(LCount);
      Inc(LWork, WindowWork(AFeatures[LIndex].ValidFrames, AClip.Channels, AOptions));
      if LWork > MaximumOnsetLocationWork then
      begin
        raise EAudio.Create('Onset candidates exceed the combined PCM work budget');
      end;
    end;
  end;
  LCandidate := nil;
  SetLength(LCandidate, LCount);
  LOutput := 0;
  for LIndex := 0 to High(LActivity.Actions) do
  begin
    if LActivity.Actions[LIndex] = aaOnset then
    begin
      LCandidate[LOutput] := LocateOnsetWindow(AClip, AFeatures[LIndex].StartFrame,
        AFeatures[LIndex].ValidFrames, AOptions);
      LCandidate[LOutput].FeatureIndex := LIndex;
      Inc(LOutput);
    end;
  end;
  Result := LCandidate;
end;

end.
