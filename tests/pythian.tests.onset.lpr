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
program pythian_tests_onset;

{$mode delphi}
{$H+}

uses
  SysUtils,
  Math,
  pythian.audio,
  pythian.analysis,
  pythian.activity,
  pythian.onset;

procedure Check(const ACondition: Boolean; const AMessage: String);
begin
  if not ACondition then
  begin
    raise Exception.Create(AMessage);
  end;
end;

procedure CheckDenseEvents;
const
  CFirstFrame = 5093;
  CSpacing = 2646;
  CEventCount = 8;
var
  LSamples: TAudioSamples;
  LClip: TAudioClip;
  LAnalysis: TAnalysisOptions;
  LFeatures: TAudioFeatures;
  LLocations: TOnsetLocations;
  LEvent: Integer;
  LFrame: Integer;
  LIndex: Integer;
  LMatches: Integer;
  LResolved: Integer;
begin
  SetLength(LSamples, 30000 * 2);
  for LEvent := 0 to CEventCount - 1 do
  begin
    for LFrame := CFirstFrame + LEvent * CSpacing to
      CFirstFrame + LEvent * CSpacing + 299 do
    begin
      LSamples[LFrame * 2] := 0.5;
      LSamples[LFrame * 2 + 1] := -0.5;
    end;
  end;
  LClip := TAudioClip.Create(44100, 2, LSamples);
  try
    LAnalysis := DefaultOnsetAnalysisOptions(LClip.SampleRate);
    LFeatures := AnalyzeAudio(LClip, LAnalysis);
    LLocations := LocalizeAcousticOnsets(LClip, LFeatures, LAnalysis,
      DefaultActivityOptions, DefaultOnsetLocationOptions(LClip.SampleRate));
    LResolved := 0;
    for LIndex := 0 to High(LLocations) do
    begin
      if LLocations[LIndex].Resolved then
      begin
        Inc(LResolved);
      end;
    end;
    Check(LResolved = CEventCount, 'Dense power-step sequence has no extra resolved events');
    for LEvent := 0 to CEventCount - 1 do
    begin
      LMatches := 0;
      for LIndex := 0 to High(LLocations) do
      begin
        if LLocations[LIndex].Resolved and
          (LLocations[LIndex].Frame = CFirstFrame + LEvent * CSpacing) then
        begin
          Inc(LMatches);
        end;
      end;
      Check(LMatches = 1, 'Each 60 ms spaced power step localizes exactly once');
    end;
  finally
    LClip.Free;
  end;
end;

procedure CheckEnergyFalls;
var
  LSamples: TAudioSamples;
  LClip: TAudioClip;
  LOptions: TEnergyFallOptions;
  LLocation: TEnergyFallLocation;
  LFrame: Integer;
  LOffset: Integer;
  LWindow: Integer;
  LBestFrame: Integer;
  LBefore: Double;
  LAfter: Double;
  LBest: Double;
  LValue: Double;
  LRejected: Boolean;
begin
  SetLength(LSamples, 512);
  for LFrame := 0 to 255 do
  begin
    if (LFrame < 97) or ((LFrame >= 130) and (LFrame < 163)) then
    begin
      LSamples[LFrame * 2] := 0.5;
    end
    else
    begin
      LSamples[LFrame * 2] := 0.25;
    end;
    LSamples[LFrame * 2 + 1] := -LSamples[LFrame * 2];
  end;
  LClip := TAudioClip.Create(8000, 2, LSamples);
  try
    LOptions := DefaultEnergyFallOptions(8000);
    LOptions.EnergyWindowFrames := 8;
    LLocation := LocateEnergyFallWindow(LClip, 80, 100, LOptions);
    Check(LLocation.Resolved and (LLocation.Frame = 97) and
      (LLocation.BeforeRms = 0.5) and (LLocation.AfterRms = 0.25) and
      (LLocation.EnergyFall = 0.1875) and (Abs(LLocation.Contrast - 0.6) < 1E-12),
      'Anti-phase energy falls retain exact levels and choose earliest equal peak');
    Check(not LLocation.SearchBoundary and not LLocation.ContextClipped,
      'Interior fall has complete context');
    LLocation := LocateEnergyFallWindow(LClip, 125, 12, LOptions);
    Check(not LLocation.Resolved and (LLocation.Frame = -1),
      'Energy rise is not an energy fall');
    LOptions.MinimumEnergyFall := 0.2;
    LLocation := LocateEnergyFallWindow(LClip, 80, 40, LOptions);
    Check(not LLocation.Resolved and (LLocation.Frame = -1) and
      (LLocation.EnergyFall = 0.1875), 'Rejected fall retains positive measurement evidence');
    LOptions.MinimumEnergyFall := 0.000001;
    LLocation := LocateEnergyFallWindow(LClip, 96, 2, LOptions);
    Check(LLocation.Resolved and (LLocation.Frame = 97) and LLocation.SearchBoundary,
      'Fall at search edge is explicitly marked');
    LRejected := False;
    try
      LLocation := LocateEnergyFallWindow(LClip, -1, 10, LOptions);
    except
      on EAudio do
      begin
        LRejected := True;
      end;
    end;
    Check(LRejected and (LLocation.Frame = 97), 'Invalid fall search preserves prior result');
    LLocation := LocateEnergyFallWindow(LClip, 240, 16, LOptions);
    Check(LLocation.Resolved and LLocation.ContextClipped and LLocation.SearchBoundary,
      'Zero-padded fall at clip end remains explicitly clipped');
    for LWindow in [8, 17] do
    begin
      LOptions.EnergyWindowFrames := LWindow;
      LBest := 0;
      LBestFrame := -1;
      for LFrame := 40 to 210 do
      begin
        LBefore := 0;
        LAfter := 0;
        for LOffset := 0 to LWindow - 1 do
        begin
          LValue := LSamples[(LFrame - 1 - LOffset) * 2];
          LBefore := LBefore + Sqr(LValue);
          LValue := LSamples[(LFrame + LOffset) * 2];
          LAfter := LAfter + Sqr(LValue);
        end;
        if LBefore - LAfter > LBest then
        begin
          LBest := LBefore - LAfter;
          LBestFrame := LFrame;
        end;
      end;
      LLocation := LocateEnergyFallWindow(LClip, 40, 171, LOptions);
      Check((LLocation.Frame = LBestFrame) and
        (Abs(LLocation.EnergyFall - LBest / LWindow) < 1E-12),
        'Sliding fall agrees with independent full-window summation');
    end;
  finally
    LClip.Free;
  end;
  LClip := TAudioClip.Create(MaximumSampleRate, 2, LSamples);
  try
    LOptions := DefaultEnergyFallOptions(LClip.SampleRate);
    LLocation := LocateEnergyFallWindow(LClip, 80, 100, LOptions);
    Check(not LLocation.Resolved or LLocation.ContextClipped,
      'Maximum-rate default remains valid and marks incomplete energy support');
  finally
    LClip.Free;
  end;
  WriteLn('Energy falls: independent sums, stereo, tie order, retained rejects and edge flags pass');
end;

procedure CheckEnvelopeValleys;
const
  CLevels: array[0..12] of Single =
    (0.5, 0.5, 0.25, 0.125, 0.125, 0.25, 0.5, 0.5, 0.25, 0.125, 0.25, 0.5, 0.5);
var
  LSamples: TAudioSamples;
  LClip: TAudioClip;
  LOptions: TEnvelopeValleyOptions;
  LValleys: TEnvelopeValleys;
  LRejected: Boolean;
  I: Integer;
begin
  LOptions := DefaultEnvelopeValleyOptions(8000);
  Check((LOptions.EnergyWindowFrames = 80) and (LOptions.HopFrames = 16) and
    (LOptions.MinimumRadiusPoints = 10) and (LOptions.PeakRadiusPoints = 40),
    'Envelope preset retains declared time scales');
  LOptions.EnergyWindowFrames := 4;
  LOptions.HopFrames := 4;
  LOptions.MinimumRadiusPoints := 1;
  LOptions.PeakRadiusPoints := 3;
  LOptions.MinimumDepth := 0.75;
  SetLength(LSamples, Length(CLevels) * 4 * 2);
  for I := 0 to Length(CLevels) * 4 - 1 do
  begin
    LSamples[I * 2] := CLevels[I div 4];
    LSamples[I * 2 + 1] := -CLevels[I div 4];
  end;
  LClip := TAudioClip.Create(8000, 2, LSamples);
  try
    LValleys := MeasureEnvelopeValleys(LClip, LOptions);
    Check(Length(LValleys) = 2, 'Two analytic envelope dips, including a flat minimum');
    Check((LValleys[0].Frame = 14) and (LValleys[0].LeftPeakFrame = 2) and
      (LValleys[0].RightPeakFrame = 26) and (LValleys[1].Frame = 38) and
      (LValleys[1].LeftPeakFrame = 26) and (LValleys[1].RightPeakFrame = 46),
      'Complete-window centers and earliest equal minima/peaks are exact');
    Check((LValleys[0].Rms = 0.125) and (LValleys[0].LeftPeakRms = 0.5) and
      (LValleys[0].RightPeakRms = 0.5) and (LValleys[0].Depth = 0.75),
      'Independent constant-power oracle retains opposite-phase stereo');
    LValleys[0].Frame := 999;
    LValleys := MeasureEnvelopeValleys(LClip, LOptions);
    Check(LValleys[0].Frame = 14, 'Returned valley measurements are detached');
    LOptions.MinimumDepth := 0.75001;
    Check(Length(MeasureEnvelopeValleys(LClip, LOptions)) = 0,
      'Depth boundary is inclusive without admitting a shallower dip');
    LOptions.MinimumDepth := 0.75;
    LOptions.MinimumPeakRms := 0.5;
    Check(Length(MeasureEnvelopeValleys(LClip, LOptions)) = 0,
      'Both flanking peaks must exceed the absolute floor');
    LOptions.MinimumPeakRms := 0;
    LOptions.PeakRadiusPoints := 7;
    Check(Length(MeasureEnvelopeValleys(LClip, LOptions)) = 0,
      'Incomplete peak context cannot supply a valley');
    LOptions.PeakRadiusPoints := 0;
    LRejected := False;
    try
      LValleys := MeasureEnvelopeValleys(LClip, LOptions);
    except
      on EAudio do
      begin
        LRejected := True;
      end;
    end;
    Check(LRejected and (Length(LValleys) = 2) and (LValleys[0].Frame = 14),
      'Invalid geometry preserves the caller result');
  finally
    LClip.Free;
  end;
  SetLength(LSamples, MaximumEnvelopePoints + 1);
  for I := 0 to High(LSamples) do
  begin
    LSamples[I] := 0;
  end;
  LClip := TAudioClip.Create(8000, 1, LSamples);
  try
    LOptions := DefaultEnvelopeValleyOptions(8000);
    LOptions.EnergyWindowFrames := 1;
    LOptions.HopFrames := 1;
    LRejected := False;
    try
      MeasureEnvelopeValleys(LClip, LOptions);
    except
      on EAudio do
      begin
        LRejected := True;
      end;
    end;
    Check(LRejected, 'Envelope point budget rejects before measurement');
    LOptions.EnergyWindowFrames := 4096;
    LRejected := False;
    try
      MeasureEnvelopeValleys(LClip, LOptions);
    except
      on EAudio do
      begin
        LRejected := True;
      end;
    end;
    Check(LRejected, 'Combined sample/comparison budget rejects below the point limit');
    LOptions := DefaultEnvelopeValleyOptions(8000);
    Check(Length(MeasureEnvelopeValleys(LClip, LOptions)) = 0, 'Silence invents no valleys');
  finally
    LClip.Free;
  end;
  SetLength(LSamples, 8000);
  for I := 0 to High(LSamples) do
  begin
    LSamples[I] := 0.3 * (1 + 0.6 * Cos(2 * Pi * 4 * I / 8000)) *
      Sin(2 * Pi * 1000 * I / 8000);
  end;
  LClip := TAudioClip.Create(8000, 1, LSamples);
  try
    LOptions := DefaultEnvelopeValleyOptions(8000);
    LValleys := MeasureEnvelopeValleys(LClip, LOptions);
    Check(Length(LValleys) = 4, 'One smoothly modulated held tone produces four envelope valleys');
    for I := 0 to High(LValleys) do
    begin
      Check(Abs(LValleys[I].Frame - (1000 + 2000 * I)) <= 16,
        'Modulation valleys follow analytic quarter-cycle times within one hop');
    end;
  finally
    LClip.Free;
  end;
  for I := 0 to High(LSamples) do
  begin
    if I < 4000 then
    begin
      LSamples[I] := 0.3 * Sin(2 * Pi * 1000 * I / 8000);
    end
    else
    begin
      LSamples[I] := 0.3 * Sin(2 * Pi * 2000 * I / 8000);
    end;
  end;
  LClip := TAudioClip.Create(8000, 1, LSamples);
  try
    Check(Length(MeasureEnvelopeValleys(LClip, LOptions)) = 0,
      'A constant-power octave transition need not produce an envelope valley');
  finally
    LClip.Free;
  end;
  WriteLn('Envelope valleys: analytic powers, stereo phase, ties, context, ownership and budgets pass');
end;

procedure Run;
var
  LSamples: TAudioSamples;
  LClip: TAudioClip;
  LOptions: TOnsetLocationOptions;
  LLocation: TOnsetLocation;
  LLocations: TOnsetLocations;
  LAnalysis: TAnalysisOptions;
  LFeatures: TAudioFeatures;
  LIndex: Integer;
  LRejected: Boolean;
begin
  LAnalysis := DefaultOnsetAnalysisOptions(44100);
  Check((LAnalysis.WindowFrames = 1024) and (LAnalysis.HopFrames = 256),
    'Onset timing uses a finer independent grid');
  LAnalysis := DefaultAnalysisOptions;
  Check((LAnalysis.WindowFrames = 4096) and (LAnalysis.HopFrames = 1024),
    'Existing acoustic learning defaults are preserved');
  LAnalysis := DefaultOnsetAnalysisOptions(MaximumSampleRate);
  Check((LAnalysis.WindowFrames = 8192) and (LAnalysis.HopFrames = 2048),
    'Onset preset retains time scale at the maximum sample rate');
  LOptions := DefaultOnsetLocationOptions(8000);
  LOptions.EnergyWindowFrames := 5;
  SetLength(LSamples, 256 * 2);
  for LIndex := 97 to 149 do
  begin
    LSamples[LIndex * 2] := 0.5;
    LSamples[LIndex * 2 + 1] := -0.5;
  end;
  LClip := TAudioClip.Create(8000, 2, LSamples);
  try
    LLocation := LocateOnsetWindow(LClip, 80, 60, LOptions);
    Check(LLocation.Resolved and (LLocation.Frame = 97) and
      (LLocation.EnergyRise = 0.25) and (LLocation.Contrast = 1) and
      not LLocation.ContextClipped, 'Exact anti-phase power step');
    LRejected := False;
    try
      LLocation := LocateOnsetWindow(LClip, -1, 10, LOptions);
    except
      on EAudio do
      begin
        LRejected := True;
      end;
    end;
    Check(LRejected and (LLocation.Frame = 97), 'Rejected window preserves prior result');
    LLocation := LocateOnsetWindow(LClip, 90, 8, LOptions);
    Check(LLocation.Resolved and (LLocation.Frame = 97) and LLocation.SearchBoundary,
      'A maximum at the search edge is explicitly marked');
    LLocation := LocateOnsetWindow(LClip, 110, 20, LOptions);
    Check(not LLocation.Resolved and (LLocation.Frame = -1), 'Steady energy is unresolved');
    LLocation := LocateOnsetWindow(LClip, 180, 20, LOptions);
    Check(not LLocation.Resolved and (LLocation.Frame = -1), 'Silence is unresolved');
    LAnalysis := DefaultAnalysisOptions;
    LAnalysis.WindowFrames := 64;
    LAnalysis.HopFrames := 16;
    LFeatures := AnalyzeAudio(LClip, LAnalysis);
    LLocations := LocalizeAcousticOnsets(LClip, LFeatures, LAnalysis,
      DefaultActivityOptions, LOptions);
    Check(Length(LLocations) > 0, 'Measured onset candidates are present');
    Check(LLocations[0].Resolved and (LLocations[0].Frame = 97) and
      (LLocations[0].WindowStartFrame < 97), 'Forward-window candidate localizes to the true step');
    LLocations[0].Frame := 13;
    LLocations := LocalizeAcousticOnsets(LClip, LFeatures, LAnalysis,
      DefaultActivityOptions, LOptions);
    Check(LLocations[0].Frame = 97, 'Caller mutation cannot alter analysis or source');
  finally
    LClip.Free;
  end;
  for LIndex := 0 to High(LSamples) do
  begin
    LSamples[LIndex] := 0.5;
  end;
  LClip := TAudioClip.Create(8000, 2, LSamples);
  try
    LLocation := LocateOnsetWindow(LClip, 0, 16, LOptions);
    Check(LLocation.Resolved and (LLocation.Frame = 0) and LLocation.ContextClipped,
      'Clip-edge assumption is explicitly marked');
  finally
    LClip.Free;
  end;
  CheckDenseEvents;
  WriteLn('Onset localization: dense stereo steps, unresolved energy, edges, preset and ownership pass');
end;

begin
  try
    Run;
    CheckEnergyFalls;
    CheckEnvelopeValleys;
  except
    on LException: Exception do
    begin
      WriteLn(StdErr, LException.ClassName, ': ', LException.Message);
      Halt(1);
    end;
  end;
end.
