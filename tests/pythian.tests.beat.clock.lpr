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
program pythian_tests_beat_clock;
{$mode delphi}
{$H+}
uses SysUtils, Math, pythian.audio, pythian.beat, pythian.beat.track, pythian.beat.clock,
  pythian.beat.alignment, pythian.music.context.admission, pythian.music.context, pythian.tonal;
function BuildClock(const AWindows: TBeatClockWindows; const AObservations: TBeatObservations;
  const ARate, AFrames: Integer): TBeatClock;
begin
  Result := ReconstructBeatClock(AWindows, AObservations, ARate, AFrames,
    DefaultBeatClockOptions);
end;
function BuildStepClock(const AWindows: TBeatClockWindows; const AObservations: TBeatObservations;
  const ARate, AFrames: Integer): TBeatClock;
var
  LOptions: TBeatClockOptions;
begin
  LOptions := DefaultBeatClockOptions;
  LOptions.Shape := bcsStepWhenFeasible;
  Result := ReconstructBeatClock(AWindows, AObservations, ARate, AFrames, LOptions);
end;
procedure Check(const AOk: Boolean; const AMessage: String);
begin
  if not AOk then
  begin
    raise EAudio.Create(AMessage);
  end;
end;
function Windows(const ACount: Integer; const APeriod, APhase: Double): TBeatClockWindows;
var
  I: Integer;
begin
  Result := nil;
  SetLength(Result, ACount);
  for I := 0 to ACount - 1 do
  begin
    Result[I].OwnerStartFrame := I * 1000;
    Result[I].OwnerEndFrame := (I + 1) * 1000;
    Result[I].HasPulse := True;
    Result[I].FirstObservationFrame := 0;
    Result[I].LastObservationFrame := ACount * 1000 - 1;
    Result[I].PeriodFrames := APeriod;
    Result[I].PhaseFrame := APhase;
  end;
end;

procedure CheckAlignment;
var
  LCells: TBeatAlignmentCells;
  LObservations: TBeatObservations;
  LResult: TBeatAlignmentChoices;
  LReplay: TBeatAlignmentChoices;
  I: Integer;
begin
  SetLength(LCells, 9);
  SetLength(LObservations, 9);
  for I := 0 to 8 do
  begin
    LCells[I].RawFrame := 1000 + I * 500;
    LCells[I].FirstFrame := LCells[I].RawFrame - 100;
    LCells[I].LastFrame := LCells[I].RawFrame + 100;
    LCells[I].Tolerance := 100;
    LCells[I].RunId := 0;
    LObservations[I].Frame := LCells[I].RawFrame + 20;
    LObservations[I].Weight := 0.5;
  end;
  LResult := AlignBeatObservationsWithContext(LCells, LObservations, 6000);
  for I := 0 to 8 do
  begin
    Check((LResult[I].Frame = LObservations[I].Frame) and not LResult[I].Unknown,
      'Consistent offset must survive');
  end;
  SetLength(LObservations, 10);
  LObservations[9] := LObservations[8];
  LObservations[8].Frame := LCells[8].RawFrame - 30;
  LObservations[8].Weight := 0.7;
  LResult := AlignBeatObservationsWithContext(LCells, LObservations, 6000);
  Check((LResult[8].OriginalObservation = 8) and (LResult[8].Observation = 9),
    'Neighbours distinguish competing late beat from earlier stronger event');
  SetLength(LObservations, 9);
  LResult := AlignBeatObservationsWithContext(LCells, LObservations, 6000);
  Check(LResult[8].Unknown and (LResult[8].Frame = LCells[8].RawFrame),
    'Unsupported candidate retains raw and explicit uncertainty');
  LReplay := AlignBeatObservationsWithContext(LCells, LObservations, 6000);
  Check(LReplay[8].Unknown, 'Identical expressive and distractor labels cannot be distinguished');
  for I := 0 to 8 do
  begin
    LObservations[I].Frame := LCells[I].RawFrame + 40 * (2 * (I mod 2) - 1);
  end;
  LResult := AlignBeatObservationsWithContext(LCells, LObservations, 6000);
  for I := 0 to 8 do
  begin
    Check((LResult[I].Frame = LObservations[I].Frame) and not LResult[I].Unknown,
      'Alternating timing must retain both phases');
  end;
  for I := 0 to 8 do
  begin
    LObservations[I].Frame := LCells[I].RawFrame + I * 3;
  end;
  LResult := AlignBeatObservationsWithContext(LCells, LObservations, 6000);
  for I := 1 to 7 do
  begin
    Check(LResult[I].Frame = LObservations[I].Frame, 'Interior gradual drift');
  end;
  Check(LResult[8].Unknown, 'Unwitnessed endpoint extrapolation stays unknown');
  LCells[8].RunId := 1;
  LResult := AlignBeatObservationsWithContext(LCells, LObservations, 6000);
  Check(LResult[8].ContextUnavailable and (LResult[8].WitnessCount = 0),
    'No evidence crosses run boundary');
  SetLength(LCells, 2);
  SetLength(LObservations, 2);
  LResult := AlignBeatObservationsWithContext(LCells, LObservations, 6000);
  Check(LResult[0].ContextUnavailable and LResult[1].ContextUnavailable,
    'Two beats do not fabricate sufficient neighbours');
  WriteLn('PASS constant/competing offsets, unknown expressive ambiguity, alternating timing, interior drift, endpoint unknown and run isolation');
end;

procedure CheckAlignmentBoundary;
var
  LWindows: TBeatClockWindows;
  LOptions: TBeatClockOptions;
  LObservations: TBeatObservations;
  LClock: TBeatClock;
  LCells: TBeatAlignmentCells;
  LChoices: TBeatAlignmentChoices;
  LRejected: Boolean;
  I: Integer;

  procedure RejectCells;
  begin
    LRejected := False;
    try
      LChoices := AlignBeatObservationsWithContext(LCells, LObservations, 6000);
    except
      on EAudio do
      begin
        LRejected := True;
      end;
    end;
    Check(LRejected and (Length(LChoices) = 1) and (LChoices[0].Frame = 1000),
      'Invalid alignment input preserves assigned result');
  end;

begin
  LWindows := Windows(5, 1000, 100);
  SetLength(LObservations, 6);
  for I := 0 to 3 do
  begin
    LObservations[I].Frame := 120 + I * 1000;
    LObservations[I].Weight := 0.5;
  end;
  LObservations[4].Frame := 4070;
  LObservations[4].Weight := 0.7;
  LObservations[5].Frame := 4120;
  LObservations[5].Weight := 0.5;
  LOptions := DefaultBeatClockOptions;
  LClock := ReconstructBeatClock(LWindows, LObservations, 1000, 5000, LOptions);
  Check((Length(LClock.AlignmentChoices) = 0) and (LClock.Frames[4] = 4070),
    'Default independent alignment remains unchanged');
  LOptions.AlignmentMode := bcaNeighbourSupported;
  LClock := ReconstructBeatClock(LWindows, LObservations, 1000, 5000, LOptions);
  Check((LClock.Frames[4] = 4120) and (LClock.RawFrames[4] = 4100) and
    (LClock.AlignmentChoices[4].OriginalObservation = 4) and
    (LClock.AlignmentChoices[4].Observation = 5), 'Clock consumes public context alignment');
  LWindows[3].StartsNewRun := True;
  LClock := ReconstructBeatClock(LWindows, LObservations, 1000, 5000, LOptions);
  Check(LClock.AlignmentChoices[4].ContextUnavailable and
    (LClock.AlignmentChoices[4].WitnessCount = 1), 'Clock restart stops witnesses');
  LWindows[3].StartsNewRun := False;
  LWindows[3].HasPulse := False;
  LClock := ReconstructBeatClock(LWindows, LObservations, 1000, 5000, LOptions);
  Check((Length(LClock.Frames) = 4) and LClock.AlignmentChoices[3].ContextUnavailable and
    (LClock.AlignmentChoices[3].WitnessCount = 0), 'Missing clock window stops witnesses');
  LOptions.SnapToleranceSeconds := 0;
  LRejected := False;
  try
    LClock := ReconstructBeatClock(LWindows, LObservations, 1000, 5000, LOptions);
  except
    on EAudio do
    begin
      LRejected := True;
    end;
  end;
  Check(LRejected and (Length(LClock.Frames) = 4), 'Disabled contextual snap preserves result');

  SetLength(LCells, 1);
  LCells[0] := Default(TBeatAlignmentCell);
  LCells[0].RawFrame := 1000;
  LCells[0].FirstFrame := 900;
  LCells[0].LastFrame := 1100;
  LCells[0].Tolerance := 100;
  SetLength(LObservations, MaximumBeatAlignmentCandidates);
  for I := 0 to High(LObservations) do
  begin
    LObservations[I].Frame := 968 + I;
    LObservations[I].Weight := 1;
  end;
  LChoices := AlignBeatObservationsWithContext(LCells, LObservations, 6000);
  Check(LChoices[0].Frame = 1000, 'Exact candidate budget accepts central onset');
  SetLength(LObservations, MaximumBeatAlignmentCandidates + 1);
  LObservations[High(LObservations)].Frame := 1032;
  LObservations[High(LObservations)].Weight := 1;
  RejectCells;
  SetLength(LObservations, 1);
  LObservations[0].Frame := 1000;
  LObservations[0].Weight := NaN;
  RejectCells;
  LObservations[0].Weight := 1;
  LCells[0].LastFrame := MaxInt;
  RejectCells;
  LCells[0].LastFrame := 1100;
  LCells[0].Tolerance := 1;
  RejectCells;
  LCells[0].Tolerance := 100;
  LObservations[0].Weight := 1e-250;
  LChoices := AlignBeatObservationsWithContext(LCells, LObservations, 6000);
  Check(LChoices[0].Frame = 1000, 'Relative alignment weights retain quiet evidence');
  LChoices[0].Frame := 17;
  Check((LObservations[0].Frame = 1000) and (LCells[0].RawFrame = 1000),
    'Alignment output is detached from borrowed inputs');
  WriteLn('PASS public alignment bounds, quiet evidence, ownership, failed-result preservation and clock run barriers');
end;

procedure CheckAdmission;
var
  LWindows: TBeatClockWindows;
  LOptions: TBeatClockOptions;
  LAdmission: TBeatTrackAdmission;
  LClock: TBeatClock;
  LRejected: Boolean;
  LFirst: Integer;
  LLast: Integer;
  LFrames: Integer;
  I: Integer;

  procedure Reject;
  begin
    LRejected := False;
    try
      LAdmission := AdmitBeatClockRange(LWindows, nil, LOptions, 1000, LFrames,
        LFirst, LLast, 480, 240, MakeKeyContext(-1, dmMajor));
    except
      on EAudio do
      begin
        LRejected := True;
      end;
    end;
    Check(LRejected and (LAdmission.SourceEndFrame = 3500) and
      (Length(LAdmission.Grid.Keys) = 10), 'Clock admission rejects without replacing result');
  end;

begin
  LOptions := DefaultBeatClockOptions;
  LOptions.Shape := bcsStepWhenFeasible;
  LWindows := Windows(4, 1000, 0);
  LWindows[2].PeriodFrames := 500;
  LWindows[3].PeriodFrames := 500;
  LAdmission := AdmitBeatClockRange(LWindows, nil, LOptions, 1000, 4000,
    0, 5, 480, 240, MakeKeyContext(-1, dmMajor));
  Check((LAdmission.SourceStartFrame = 0) and (LAdmission.SourceEndFrame = 3500) and
    (Length(LAdmission.Grid.Keys) = 10) and (Length(LAdmission.Changes) = 5),
    'Step clock enters quarter-grid scope');
  for I := 0 to 9 do
  begin
    Check(LAdmission.Grid.Keys[I].Root = -1, 'Unknown key is preserved');
    if I < 4 then
    begin
      Check(LAdmission.Grid.Tempos[I] = 1000000, 'Pre-step admitted quarters');
    end
    else
    begin
      Check(LAdmission.Grid.Tempos[I] = 500000, 'Post-step admitted quarters');
    end;
  end;
  for I := 0 to High(LAdmission.BoundaryErrors) do
  begin
    Check(LAdmission.BoundaryErrors[I] = 0, 'Admitted clock exact independent boundaries');
  end;
  LFrames := 3000;
  LFirst := 1;
  LLast := 2;
  LWindows := Windows(3, 500, 100);
  LWindows[1].HasPulse := False;
  Reject;
  LWindows[1].HasPulse := True;
  LWindows[1].StartsNewRun := True;
  Reject;
  LFrames := 2000;
  LFirst := 0;
  LLast := 1;
  LWindows := Windows(2, 2000, 500);
  LWindows[1].PhaseFrame := 1500;
  LClock := BuildClock(LWindows, nil, 1000, 2000);
  Check((Length(LClock.Frames) = 2) and (LClock.AmbiguousIntervals = 1), 'Ambiguous range control');
  Reject;
  LFrames := 4000;
  LWindows := Windows(4, 3000, 500);
  LWindows[1].PhaseFrame := -500;
  LClock := BuildClock(LWindows, nil, 1000, 4000);
  Check((Length(LClock.Frames) = 2) and (LClock.RejectedIntervals = 1), 'Unavailable range control');
  Reject;
  LWindows := Windows(3, 500, 100);
  LWindows[1].HasPulse := False;
  LAdmission := AdmitBeatClockRange(LWindows, nil, LOptions, 1000, 3000,
    2, 3, 480, 240, MakeKeyContext(-1, dmMajor));
  Check((LAdmission.SourceStartFrame = 2100) and (LAdmission.SourceEndFrame = 2600),
    'Separate supported range after gap retains source offset');
  WriteLn('PASS reconstructed context admission, explicit quarters, source offset and gap/phase rejection');
end;

procedure CheckContracts;
var
  LWindows: TBeatClockWindows;
  LConverted: TBeatClockWindows;
  LTrack: TBeatTrackWindows;
  LObservations: TBeatObservations;
  LClock: TBeatClock;
  LOther: TBeatClock;
  LOptions: TBeatClockOptions;
  LFrames: Integer;
  LRejected: Boolean;
  LNotFiniteBits: QWord;
  I: Integer;

  procedure Reject;
  begin
    LRejected := False;
    try
      LClock := ReconstructBeatClock(LWindows, LObservations, 1000, LFrames, LOptions);
    except
      on EAudio do
      begin
        LRejected := True;
      end;
    end;
    Check(LRejected and (Length(LClock.RawFrames) = 8) and
      (LClock.RawFrames[0] = 100), 'Rejected call preserves assigned clock');
  end;

begin
  LOptions := DefaultBeatClockOptions;
  LFrames := 4000;
  LWindows := Windows(4, 500, 100);
  LClock := BuildClock(LWindows, nil, 1000, 4000);
  LOther := BuildClock(LWindows, nil, 1000, 4000);
  LOther.RawFrames[0] := 0;
  Check((LClock.RawFrames[0] = 100) and (LOther.Frames[0] = 100) and
    (LWindows[0].PhaseFrame = 100), 'Outputs and inputs are detached');
  LWindows[1].OwnerStartFrame := 1001;
  Reject;
  LWindows[1].OwnerStartFrame := 1000;
  LWindows[0].LastObservationFrame := 4000;
  Reject;
  LWindows[0].LastObservationFrame := 3999;
  LWindows[0].PeriodFrames := 0;
  Reject;
  LWindows[0].PeriodFrames := 500;
  LNotFiniteBits := QWord($7FF8000000000000);
  Move(LNotFiniteBits, LWindows[0].PhaseFrame, SizeOf(Double));
  Reject;
  LWindows[0].PhaseFrame := 100;
  LOptions.SnapToleranceSeconds := -1;
  Reject;
  LOptions := DefaultBeatClockOptions;
  SetLength(LObservations, 2);
  LObservations[0].Frame := 100;
  LObservations[0].Weight := 1;
  LObservations[1] := LObservations[0];
  Reject;
  LObservations[1].Frame := 200;
  Move(LNotFiniteBits, LObservations[1].Weight, SizeOf(Double));
  Reject;
  LObservations := nil;
  LWindows := Windows(1, 150, 0);
  LFrames := MaximumClipSamples;
  LWindows[0].OwnerEndFrame := LFrames;
  LWindows[0].LastObservationFrame := LFrames - 1;
  Reject;
  LWindows := Windows(MaximumBeatClockWindows + 1, 500, 100);
  LFrames := Length(LWindows) * 1000;
  Reject;
  LWindows := Windows(MaximumBeatClockWindows, 500, 100);
  LOther := BuildClock(LWindows, nil, 1000, Length(LWindows) * 1000);
  Check((Length(LOther.RawFrames) = 2 * MaximumBeatClockWindows) and
    (LOther.CrossingWork = Length(LOther.RawFrames)), 'Maximum window span/work');

  LWindows := Windows(3, 500, 450);
  LWindows[1].HasPulse := False;
  LWindows[2].PhaseFrame := 50;
  SetLength(LObservations, 2);
  LObservations[0].Frame := 1020;
  LObservations[0].Weight := 1;
  LObservations[1].Frame := 1990;
  LObservations[1].Weight := 1;
  LOther := BuildClock(LWindows, LObservations, 1000, 3000);
  for I := 0 to High(LOther.Frames) do
  begin
    Check(LOther.Frames[I] = LOther.RawFrames[I], 'Alignment cannot enter a missing run');
    Check(LOther.ObservationIndices[I] = -1, 'Gap onset is not assigned');
  end;
  LWindows := Windows(2, 500, 450);
  LWindows[1].PhaseFrame := 50;
  LWindows[1].StartsNewRun := True;
  SetLength(LObservations, 1);
  LOther := BuildClock(LWindows, LObservations, 1000, 2000);
  Check((LOther.RawFrames[1] = 950) and (LOther.Frames[1] = 950) and
    (LOther.RawFrames[2] = 1050) and (LOther.Frames[2] = 1020),
    'Alignment respects restart and retains source onset on its own side');
  LOptions.SnapToleranceSeconds := 0;
  LOther := ReconstructBeatClock(LWindows, LObservations, 1000, 2000, LOptions);
  Check((LOther.Frames[2] = 1050) and (LOther.ObservationIndices[2] = -1), 'Alignment disabled');
  LWindows := Windows(2, 3000, 500);
  LWindows[1].PhaseFrame := 1500;
  LObservations[0].Frame := 1450;
  LOther := BuildClock(LWindows, LObservations, 1000, 2000);
  Check((LOther.RejectedIntervals = 1) and (Length(LOther.Frames) = 1) and
    (LOther.RawFrames[0] = 1500) and (LOther.Frames[0] = 1500),
    'Alignment cannot enter a rejected phase interval');
  LOptions := DefaultBeatClockOptions;
  LOptions.AlignmentMode := bcaNeighbourSupported;
  LOther := ReconstructBeatClock(LWindows, LObservations, 1000, 2000, LOptions);
  Check((LOther.RejectedIntervals = 1) and (LOther.Frames[0] = 1500) and
    LOther.AlignmentChoices[0].Unknown, 'Context alignment retains rejected-phase barrier');
  LOptions := DefaultBeatClockOptions;
  LWindows[0].HasPulse := False;
  LWindows[1].HasPulse := False;
  LOther := BuildClock(LWindows, nil, 1000, 2000);
  Check((Length(LOther.Frames) = 0) and (Length(LOther.Segments) = 0), 'All missing remains empty');

  SetLength(LTrack, 2);
  LTrack[0].OwnerStartFrame := 0;
  LTrack[0].OwnerEndFrame := 1000;
  LTrack[0].SelectedCandidate := -1;
  LTrack[1].OwnerStartFrame := 1000;
  LTrack[1].OwnerEndFrame := 2000;
  LTrack[1].StartsNewPath := True;
  SetLength(LTrack[1].Analysis.Candidates, 2);
  LTrack[1].SelectedCandidate := 1;
  LTrack[1].Analysis.Candidates[0].PeriodFrames := 250;
  LTrack[1].Analysis.Candidates[1].PeriodFrames := 500;
  LTrack[1].Analysis.Candidates[1].PhaseFrame := 1100;
  LConverted := SelectedBeatClockWindows(LTrack);
  Check(not LConverted[0].HasPulse and LConverted[1].StartsNewRun and
    (LConverted[1].PeriodFrames = 500) and
    LConverted[0].HasTrackSelection and (LConverted[0].TrackWindowIndex = 0) and
    (LConverted[0].SelectedCandidateIndex = -1) and
    LConverted[1].HasTrackSelection and (LConverted[1].TrackWindowIndex = 1) and
    (LConverted[1].SelectedCandidateIndex = 1) and
    (LConverted[1].OwnerStartFrame = LTrack[1].OwnerStartFrame) and
    (LConverted[1].OwnerEndFrame = LTrack[1].OwnerEndFrame) and
    (LConverted[1].PeriodFrames =
      LTrack[LConverted[1].TrackWindowIndex].Analysis.Candidates[
        LConverted[1].SelectedCandidateIndex].PeriodFrames) and
    (LConverted[1].PhaseFrame =
      LTrack[LConverted[1].TrackWindowIndex].Analysis.Candidates[
        LConverted[1].SelectedCandidateIndex].PhaseFrame),
    'Track adapter preserves exact pool selection, missing selection and restart');
  LWindows := SelectedBeatClockWindows(LTrack);
  Check((LWindows[1].SelectedCandidateIndex = LConverted[1].SelectedCandidateIndex) and
    (LWindows[1].PeriodFrames = LConverted[1].PeriodFrames),
    'Track selection projection replays');
  LConverted[1].PeriodFrames := 999;
  Check((LTrack[1].Analysis.Candidates[1].PeriodFrames = 500) and
    (LTrack[1].Analysis.Candidates[0].PeriodFrames = 250),
    'Track conversion detached and unused alternative retained');
  LTrack[1].SelectedCandidate := 2;
  LRejected := False;
  try
    LConverted := SelectedBeatClockWindows(LTrack);
  except
    on EAudio do
    begin
      LRejected := True;
    end;
  end;
  Check(LRejected and (LConverted[1].PeriodFrames = 999) and
    (LConverted[1].SelectedCandidateIndex = 1),
    'Invalid selection preserves conversion and provenance');
  WriteLn('PASS public clock bounds, failure preservation, ownership, alignment gaps/restarts and selection adapter');
end;
var
  LWindows: TBeatClockWindows;
  LClock: TBeatClock;
  LReplay: TBeatClock;
  LTime: Double;
  LPhase: Double;
  LRate: Double;
  LExpected: Double;
  LMaximum: Double;
  LCount: Integer;
  I: Integer;
begin
  CheckAlignment;
  CheckAlignmentBoundary;
  CheckContracts;
  CheckAdmission;
  LWindows := Windows(4, 500, 125.5);
  LClock := BuildClock(LWindows, nil, 1000, 4000);
  Check(Length(LClock.RawFrames) = 8, 'Constant count');
  for I := 0 to 7 do
  begin
    Check(LClock.RawFrames[I] = 126 + I * 500, 'Half-frame rounds later');
    Check(LClock.FrameWindows[I] = I div 2, 'Owner boundary assignment');
  end;
  LReplay := BuildClock(LWindows, nil, 1000, 4000);
  for I := 0 to High(LClock.RawFrames) do
  begin
    Check(LClock.RawFrames[I] = LReplay.RawFrames[I], 'Deterministic replay');
  end;
  LWindows := Windows(4, 500, 125.5 - 1e-6);
  LClock := BuildClock(LWindows, nil, 1000, 4000);
  Check(LClock.RawFrames[0] = 125, 'Below-half outside rounding guard');
  LWindows := Windows(4, 500, 125.5 + 1e-6);
  LClock := BuildClock(LWindows, nil, 1000, 4000);
  Check(LClock.RawFrames[0] = 126, 'Above-half outside rounding guard');
  LWindows[1].HasPulse := False;
  LClock := BuildClock(LWindows, nil, 1000, 4000);
  Check(Length(LClock.RawFrames) = 6, 'Missing owner gap count');
  for I := 0 to High(LClock.RawFrames) do
  begin
    Check((LClock.RawFrames[I] < 1000) or (LClock.RawFrames[I] >= 2000), 'No gap interpolation');
  end;
  LWindows := Windows(2, 500, 0);
  LWindows[1].PeriodFrames := 1000;
  LClock := BuildClock(LWindows, nil, 1000, 2000);
  Check((Length(LClock.RawFrames) = 3) and (LClock.RawFrames[0] = 0) and
    (LClock.RawFrames[1] = 500) and (LClock.RawFrames[2] = 1167), 'Known piecewise-linear phase');
  LWindows := Windows(2, 2000, 500);
  LWindows[1].PhaseFrame := 1500;
  LClock := BuildClock(LWindows, nil, 1000, 2000);
  Check(LClock.AmbiguousIntervals = 1, 'Half-cycle ambiguity retained');
  LWindows := Windows(2, 3000, 500);
  LWindows[1].PhaseFrame := 1500;
  LClock := BuildClock(LWindows, nil, 1000, 2000);
  Check(LClock.RejectedIntervals = 1, 'Stalled interval not coerced forward');
  LWindows := Windows(4, 1000, 0);
  for I := 2 to 3 do
  begin
    LWindows[I].PeriodFrames := 500;
  end;
  LClock := BuildClock(LWindows, nil, 1000, 4000);
  Check((Length(LClock.RawFrames) = 6) and (LClock.RawFrames[2] = 1833),
    'Abrupt-clock interpolation diagnostic changed');
  WriteLn('abrupt_control_displacement_ms=', 2000 - LClock.RawFrames[2],
    ' (known exact change beat at 2000 ms; this is a limitation)');
  LClock := BuildStepClock(LWindows, nil, 1000, 4000);
  Check((LClock.StepIntervals = 1) and (Length(LClock.RawFrames) = 6), 'One feasible step');
  for I := 0 to 5 do
  begin
    if I < 2 then
    begin
      Check(LClock.RawFrames[I] = I * 1000, 'Step left clock');
    end
    else
    begin
      Check(LClock.RawFrames[I] = 2000 + (I - 2) * 500, 'Step right clock');
    end;
  end;
  WriteLn('PASS exact abrupt clock recovered from endpoint constraints');
  LWindows := Windows(2, 1000, 0);
  LWindows[1].PeriodFrames := 900;
  LClock := BuildStepClock(LWindows, nil, 1000, 2000);
  Check(LClock.StepIntervals = 0, 'Out-of-interval step falls back');
  LWindows := Windows(4, 1000, 0);
  for I := 0 to 3 do
  begin
    LTime := I + 0.5;
    LPhase := LTime + 0.1 * Sqr(LTime);
    LRate := 1 + 0.2 * LTime;
    LWindows[I].PeriodFrames := 1000 / LRate;
    LWindows[I].PhaseFrame :=
      LTime * 1000 - (LPhase - Floor(LPhase)) * 1000 / LRate;
  end;
  LClock := BuildClock(LWindows, nil, 1000, 4000);
  LCount := 0;
  LMaximum := 0;
  for I := 0 to High(LClock.RawFrames) do
  begin
    { True phase t + .1t^2, including the first beat only if not clipped by
      edge extrapolation. Assign its known integer cycle by analytic phase. }
    LTime := LClock.RawFrames[I] / 1000;
    LPhase := Round(LTime + 0.1 * Sqr(LTime));
    LExpected := 1000 * (Sqrt(1 + 0.4 * LPhase) - 1) / 0.2;
    LMaximum := Max(LMaximum, Abs(LClock.RawFrames[I] - LExpected));
    Inc(LCount);
  end;
  Check((LCount = 6) and (LMaximum <= 25.5), 'Analytic smooth-clock error bound');
  WriteLn('smooth_control_max_error_ms=', LMaximum:0:6, ' analytic_bound_ms=25.5');
  LClock := BuildStepClock(LWindows, nil, 1000, 4000);
  LMaximum := 0;
  for I := 0 to High(LClock.RawFrames) do
  begin
    LTime := LClock.RawFrames[I] / 1000;
    LPhase := Round(LTime + 0.1 * Sqr(LTime));
    LExpected := 1000 * (Sqrt(1 + 0.4 * LPhase) - 1) / 0.2;
    LMaximum := Max(LMaximum, Abs(LClock.RawFrames[I] - LExpected));
  end;
  Check((Length(LClock.RawFrames) = 6) and (LMaximum <= 25.5), 'Step smooth-clock bound');
  WriteLn('step_smooth_max_error_ms=', LMaximum:0:6, ' steps=', LClock.StepIntervals);
  WriteLn('PASS exact constant/piecewise phase, rounding, owners, gap, ambiguity, stalled interval and replay');
end.
