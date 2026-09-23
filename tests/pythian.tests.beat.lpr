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
program pythian_tests_beat;

{$mode delphi}
{$H+}

uses
  SysUtils,
  Math,
  pythian.audio,
  pythian.beat;

procedure Check(const ACondition: Boolean; const AMessage: String);
begin
  if not ACondition then
  begin
    raise Exception.Create(AMessage);
  end;
end;

procedure SubdivisionChecks;
var
  LObservations: TBeatObservations;
  LAnalysis: TBeatGridAnalysis;
  LBounded: TBeatGridAnalysis;
  LOptions: TBeatGridOptions;
  LSwap: TBeatObservation;
  LCase: Integer;
  LSubdivisions: Integer;
  LIndex: Integer;
  LOther: Integer;
  LLimit: Integer;
  LFound120: Boolean;
  LFound90: Boolean;
  LPhaseZero: Boolean;
  LPhaseHalf: Boolean;
begin
  for LCase := 0 to 6 do
  begin
    LOptions := DefaultBeatGridOptions;
    case LCase of
      0: LSubdivisions := 1;
      2: LSubdivisions := 4;
      5: LSubdivisions := 3;
    else
      LSubdivisions := 2;
    end;
    SetLength(LObservations, 16 * LSubdivisions);
    for LIndex := 0 to High(LObservations) do
    begin
      LObservations[LIndex].Frame := 4800 + LIndex * 24000 div LSubdivisions;
      LObservations[LIndex].Weight := 1;
      if ((LCase = 3) and Odd(LIndex)) or ((LCase = 4) and not Odd(LIndex)) then
      begin
        LObservations[LIndex].Weight := 0.5;
      end;
    end;
    if LCase = 6 then
    begin
      SetLength(LObservations, 28);
      for LIndex := 0 to 15 do
      begin
        LObservations[LIndex].Frame := 4800 + LIndex * 24000;
        LObservations[LIndex].Weight := 1;
      end;
      for LIndex := 0 to 11 do
      begin
        LObservations[LIndex + 16].Frame := 9600 + LIndex * 32000;
        LObservations[LIndex + 16].Weight := 0.8;
      end;
      for LIndex := 1 to High(LObservations) do
      begin
        LOther := LIndex;
        while (LOther > 0) and
          (LObservations[LOther].Frame < LObservations[LOther - 1].Frame) do
        begin
          LSwap := LObservations[LOther];
          LObservations[LOther] := LObservations[LOther - 1];
          LObservations[LOther - 1] := LSwap;
          Dec(LOther);
        end;
      end;
    end;
    LAnalysis := EstimateBeatGrids(LObservations, 48000, 432000, LOptions);
    LFound120 := False;
    LFound90 := False;
    LPhaseZero := False;
    LPhaseHalf := False;
    for LIndex := 0 to High(LAnalysis.Candidates) do
    begin
      LFound90 := LFound90 or (Abs(LAnalysis.Candidates[LIndex].Bpm - 90) <= 0.5);
      if Abs(LAnalysis.Candidates[LIndex].Bpm - 120) < 1E-9 then
      begin
        LFound120 := True;
        LPhaseZero := LPhaseZero or
          (Abs(LAnalysis.Candidates[LIndex].PhaseFrame - 4800) < 1E-6);
        LPhaseHalf := LPhaseHalf or
          (Abs(LAnalysis.Candidates[LIndex].PhaseFrame - 16800) < 1E-6);
        if (LCase = 3) and (Abs(LAnalysis.Candidates[LIndex].PhaseFrame - 4800) < 1E-6) then
        begin
          Check(Abs(LAnalysis.Candidates[LIndex].MatchedWeightFraction - 2 / 3) < 1E-12,
            'Matched weight measures strong attacks separately from concentration');
          Check(Abs(LAnalysis.Candidates[LIndex].PhaseConcentration -
            (2 / 3 - 0.06) / 0.94) < 1E-12, 'Analytic triangular support above uniform mass');
        end;
      end;
    end;
    Check(LFound120, 'Authored tempo remains available with subdivisions');
    Check((LCase <> 6) or LFound90, 'Both mixture tempos remain available');
    Check(not (LCase in [1, 3, 4]) or (LPhaseZero and LPhaseHalf),
      'Equal/accented eighth alternatives retain both exact phases');
    if LCase = 3 then
    begin
      for LLimit in [1, 3] do
      begin
        LOptions.MaximumCandidates := LLimit;
        LBounded := EstimateBeatGrids(LObservations, 48000, 432000, LOptions);
        Check(Length(LBounded.Candidates) = LLimit, 'One/odd capacity is honored');
        for LIndex := 0 to LLimit - 1 do
        begin
          Check((LBounded.Candidates[LIndex].Bpm = LAnalysis.Candidates[LIndex].Bpm) and
            (LBounded.Candidates[LIndex].PhaseFrame = LAnalysis.Candidates[LIndex].PhaseFrame),
            'Capacity preserves deterministic selection prefix');
        end;
      end;
      LOptions := DefaultBeatGridOptions;
      LOptions.MinimumMatchedWeight := 0.7;
      LBounded := EstimateBeatGrids(LObservations, 48000, 432000, LOptions);
      Check(Length(LBounded.Candidates) > 0, 'Fully supported faster grid remains available');
      for LIndex := 0 to High(LBounded.Candidates) do
      begin
        Check(LBounded.Candidates[LIndex].MatchedWeightFraction >= 0.7,
          'Matched-weight threshold admits its declared measurement');
        Check(Abs(LBounded.Candidates[LIndex].Bpm - 120) > 0.5,
          'Threshold rejects the two-thirds-supported phase');
      end;
    end;
  end;
  Check((BeatGridFitWork(0, MaximumBeatTrials) = 0) and
    (BeatGridFitWork(3, MaximumBeatTrials) = 0), 'Insufficient observations do no fitting');
  WriteLn('Pulse phases: seven subdivision/mixture controls, measurement semantics and capacity pass');
end;

procedure BeatLevelAvailabilityChecks;
var
  LObservations: TBeatObservations;
  LAnalysis: TBeatGridAnalysis;
  LInspected: TBeatGridAnalysis;
  LTrace: TBeatCandidateTrace;
  LOptions: TBeatGridOptions;
  LIndex: Integer;
  LChoice: Integer;
  LLimit: Integer;
  LTrial: Integer;
  LRankMatches: Integer;
  LSuppressed: Boolean;
  LCapacity: Boolean;
  LFast: Boolean;
  LHalf: Boolean;
  LDouble: Boolean;
  LPhaseZero: Boolean;
  LPhaseHalf: Boolean;
begin
  SetLength(LObservations, 32);
  for LIndex := 0 to High(LObservations) do
  begin
    LObservations[LIndex].Frame := 4800 + 12000 * LIndex;
    if LIndex mod 4 = 0 then
    begin
      LObservations[LIndex].Weight := 1;
    end
    else if LIndex mod 4 = 2 then
    begin
      LObservations[LIndex].Weight := 0.75;
    end
    else
    begin
      LObservations[LIndex].Weight := 0.5;
    end;
  end;
  for LLimit in [8, 16] do
  begin
    LOptions := DefaultBeatGridOptions;
    LOptions.MaximumCandidates := LLimit;
    LAnalysis := EstimateBeatGrids(LObservations, 48000, 432000, LOptions);
    LInspected := InspectBeatGridCandidates(LObservations, 48000, 432000,
      LOptions, LTrace);
    Check((Length(LInspected.Candidates) = Length(LAnalysis.Candidates)) and
      (Length(LTrace.Trials) = LAnalysis.TrialCount * 2),
      'Optional candidate trace retains the fitted pool and bounded trial count');
    LSuppressed := False;
    LCapacity := False;
    for LTrial := 0 to High(LTrace.Trials) do
    begin
      if LTrace.SuppressedBy[LTrial] >= 0 then
      begin
        Check(LTrace.PeakEligible[LTrial] and
          (LTrace.SelectedRank[LTrial] < 0) and
          (LTrace.SuppressedBy[LTrial] < Length(LTrace.Trials)),
          'Suppression names a selected trial after peak eligibility');
        LSuppressed := True;
      end;
      if LTrace.PeakEligible[LTrial] and
        (LTrace.SelectedRank[LTrial] < 0) and
        (LTrace.SuppressedBy[LTrial] < 0) then
      begin
        LCapacity := True;
      end;
    end;
    Check(LSuppressed and LCapacity,
      'Authored phase hierarchy exposes suppression and capacity separately');
    for LChoice := 0 to High(LAnalysis.Candidates) do
    begin
      LRankMatches := 0;
      for LTrial := 0 to High(LTrace.Trials) do
      begin
        if LTrace.SelectedRank[LTrial] = LChoice then
        begin
          Inc(LRankMatches);
          Check((LTrace.Trials[LTrial].Bpm = LAnalysis.Candidates[LChoice].Bpm) and
            (LTrace.Trials[LTrial].PhaseFrame =
             LAnalysis.Candidates[LChoice].PhaseFrame) and
            (LTrace.Trials[LTrial].Score = LAnalysis.Candidates[LChoice].Score),
            'Trace rank identifies the exact production candidate');
        end;
      end;
      Check(LRankMatches = 1, 'Every retained candidate has one trial identity');
    end;
    LFast := False;
    LHalf := False;
    LDouble := False;
    LPhaseZero := False;
    LPhaseHalf := False;
    for LChoice := 0 to High(LAnalysis.Candidates) do
    begin
      LFast := LFast or (Abs(LAnalysis.Candidates[LChoice].Bpm - 240) <= 0.5);
      LHalf := LHalf or (Abs(LAnalysis.Candidates[LChoice].Bpm - 120) <= 0.5);
      LDouble := LDouble or (Abs(LAnalysis.Candidates[LChoice].Bpm - 60) <= 0.5);
      if Abs(LAnalysis.Candidates[LChoice].Bpm - 120) <= 0.5 then
      begin
        LPhaseZero := LPhaseZero or
          (Abs(LAnalysis.Candidates[LChoice].PhaseFrame - 4800) < 1E-6);
        LPhaseHalf := LPhaseHalf or
          (Abs(LAnalysis.Candidates[LChoice].PhaseFrame - 16800) < 1E-6);
      end;
    end;
    Check(LFast and LHalf and LDouble and LPhaseZero and LPhaseHalf,
      'True fast, half/double and competing phases remain available');
  end;
  LObservations := nil;
  LAnalysis := EstimateBeatGrids(LObservations, 48000, 432000,
    DefaultBeatGridOptions);
  Check(Length(LAnalysis.Candidates) = 0, 'Empty beat source remains unknown');
  LInspected := InspectBeatGridCandidates(LObservations, 48000, 432000,
    DefaultBeatGridOptions, LTrace);
  Check((Length(LInspected.Candidates) = 0) and
    (Length(LTrace.Trials) = 0),
    'Trace of an empty source cannot invent fitted pulses');
  SetLength(LObservations, 3);
  for LIndex := 0 to High(LObservations) do
  begin
    LObservations[LIndex].Frame := 4800 + 12000 * LIndex;
    LObservations[LIndex].Weight := 1;
  end;
  LAnalysis := EstimateBeatGrids(LObservations, 48000, 432000,
    DefaultBeatGridOptions);
  Check(Length(LAnalysis.Candidates) = 0, 'Three beat onsets remain insufficient');
  LInspected := InspectBeatGridCandidates(LObservations, 48000, 432000,
    DefaultBeatGridOptions, LTrace);
  Check((Length(LInspected.Candidates) = 0) and
    (Length(LTrace.Trials) = 0),
    'Trace preserves the insufficient-observation boundary');
  WriteLn('Beat levels: fast, half/double, phase and insufficient evidence pass');
end;

procedure Run;
var
  LObservations: TBeatObservations;
  LOptions: TBeatGridOptions;
  LAnalysis: TBeatGridAnalysis;
  LGrid: TBeatGridCandidate;
  LFrames: TBeatFrames;
  LIndex: Integer;
  LAlias: Boolean;
  LRejected: Boolean;
  LPhaseError: Double;
begin
  SubdivisionChecks;
  BeatLevelAvailabilityChecks;
  LOptions := DefaultBeatGridOptions;
  SetLength(LObservations, 16);
  for LIndex := 0 to High(LObservations) do
  begin
    LObservations[LIndex].Frame := 1234 + LIndex * 22050;
    LObservations[LIndex].Weight := 1;
  end;
  LAnalysis := EstimateBeatGrids(LObservations, 44100, 400000, LOptions);
  Check(Length(LAnalysis.Candidates) >= 2, 'Retain competing periodic grids');
  LGrid := LAnalysis.Candidates[0];
  Check(Abs(LGrid.Bpm - 120) < 0.001, 'Known 120 BPM leads a regular pulse train');
  Check((LGrid.PhaseConcentration > 0.999999) and (LGrid.Coverage = 1) and
    (LGrid.SupportedBeats = 16) and (LGrid.MeanErrorFrames < 0.001),
    'Exact pulse timing and full distinct-beat coverage');
  LFrames := BeatGridFrames(LGrid, 1234, 331985);
  Check(Length(LFrames) = 16, 'Half-open grid includes sixteen authored beats');
  for LIndex := 0 to High(LFrames) do
  begin
    Check(LFrames[LIndex] = LObservations[LIndex].Frame, 'Known frame sequence');
  end;
  LAlias := False;
  for LIndex := 1 to High(LAnalysis.Candidates) do
  begin
    if Abs(LAnalysis.Candidates[LIndex].Bpm - 240) < 0.001 then
    begin
      LAlias := True;
      Check(LAnalysis.Candidates[LIndex].Coverage < 0.6,
        'Double-tempo alias exposes unsupported intervening beats');
    end;
  end;
  Check(LAlias, 'Double-tempo ambiguity remains inspectable');

  for LIndex := 0 to High(LObservations) do
  begin
    LObservations[LIndex].Weight := 1E-200;
  end;
  LAnalysis := EstimateBeatGrids(LObservations, 44100, 400000, LOptions);
  Check((Abs(LAnalysis.Candidates[0].Bpm - 120) < 0.001) and
    (LAnalysis.Candidates[0].Score > 0.999999), 'Common weight scaling preserves alignment');
  for LIndex := 0 to High(LObservations) do
  begin
    LObservations[LIndex].Weight := 1;
  end;

  LObservations[7].Weight := 0.01;
  for LIndex := 0 to High(LObservations) do
  begin
    Inc(LObservations[LIndex].Frame, 567);
    if Odd(LIndex) then
    begin
      Inc(LObservations[LIndex].Frame, 100);
    end;
  end;
  LAnalysis := EstimateBeatGrids(LObservations, 44100, 400000, LOptions);
  Check(Abs(LAnalysis.Candidates[0].Bpm - 120) <= 0.25,
    'Shifted and mildly jittered beat train retains tempo');
  LPhaseError := Abs(LAnalysis.Candidates[0].PhaseFrame - 1801);
  Check(LPhaseError < 120, 'Phase follows timing offset, not clip start');

  LObservations[1].Frame := LObservations[0].Frame;
  LRejected := False;
  try
    LAnalysis := EstimateBeatGrids(LObservations, 44100, 400000, LOptions);
  except
    on EAudio do
    begin
      LRejected := True;
    end;
  end;
  Check(LRejected and (Length(LAnalysis.Candidates) > 0),
    'Duplicate admission preserves previous managed result');
  LObservations[1].Frame := LObservations[0].Frame + 22050;
  LObservations[0].Weight := Infinity;
  LRejected := False;
  try
    LAnalysis := EstimateBeatGrids(LObservations, 44100, 400000, LOptions);
  except
    on EAudio do
    begin
      LRejected := True;
    end;
  end;
  Check(LRejected, 'Nonfinite weight rejects before fitting');

  LObservations := nil;
  LAnalysis := EstimateBeatGrids(LObservations, 44100, 400000, LOptions);
  Check((Length(LAnalysis.Candidates) = 0) and
    (LAnalysis.FirstObservationFrame = -1), 'Silence does not invent a grid');
  SetLength(LObservations, 4);
  for LIndex := 0 to High(LObservations) do
  begin
    LObservations[LIndex].Frame := 100 + LIndex * 100;
    LObservations[LIndex].Weight := 1;
  end;
  LAnalysis := EstimateBeatGrids(LObservations, 44100, 400000, LOptions);
  Check(Length(LAnalysis.Candidates) = 0, 'Short burst is insufficient periodic evidence');
  SetLength(LObservations, MaximumBeatObservations);
  for LIndex := 0 to High(LObservations) do
  begin
    LObservations[LIndex].Frame := LIndex * 40;
    LObservations[LIndex].Weight := 1;
  end;
  LOptions.MaximumBpm := 400;
  LRejected := False;
  try
    LAnalysis := EstimateBeatGrids(LObservations, 44100, 400000, LOptions);
  except
    on EAudio do
    begin
      LRejected := True;
    end;
  end;
  Check(LRejected, 'Aggregate observation/trial work budget rejects before fitting');
  LOptions.StepBpm := 0.01;
  LRejected := False;
  try
    LAnalysis := EstimateBeatGrids(nil, 44100, 400000, LOptions);
  except
    on EAudio do
    begin
      LRejected := True;
    end;
  end;
  Check(LRejected, 'Tempo trial budget rejects before allocation');

  LGrid.PeriodFrames := 2;
  LGrid.PhaseFrame := 0.5;
  LFrames := BeatGridFrames(LGrid, 1, 5);
  Check((Length(LFrames) = 2) and (LFrames[0] = 1) and (LFrames[1] = 3),
    'Grid rounding uses later half-frame ties and exclusive end');
  LFrames := BeatGridFrames(LGrid, 5, 5);
  Check(Length(LFrames) = 0, 'Empty interval yields no beats');
  LRejected := False;
  try
    LFrames := BeatGridFrames(LGrid, 0, MaximumClipSamples);
  except
    on EAudio do
    begin
      LRejected := True;
    end;
  end;
  Check(LRejected and (Length(LFrames) = 0), 'Grid allocation cap preserves previous result');
  WriteLn('Beat grids: known tempo/phase, alias coverage, jitter, silence and admission pass');
end;

begin
  try
    Run;
  except
    on LError: Exception do
    begin
      WriteLn(StdErr, LError.Message);
      Halt(1);
    end;
  end;
end.
