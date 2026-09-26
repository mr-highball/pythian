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
program pythian_tests_beat_track;

{$mode delphi}
{$H+}

uses
  SysUtils,
  Math,
  pythian.audio,
  pythian.beat,
  pythian.music.context,
  pythian.music.context.admission,
  pythian.tonal,
  pythian.beat.track;

procedure Check(const ACondition: Boolean; const AMessage: String);
begin
  if not ACondition then
  begin
    raise Exception.Create(AMessage);
  end;
end;

function CandidateWindows(const ACount: Integer): TBeatTrackWindows;
var
  I: Integer;
  J: Integer;
begin
  Result := nil;
  SetLength(Result, ACount);
  for I := 0 to ACount - 1 do
  begin
    Result[I].OwnerStartFrame := I * 1000;
    Result[I].OwnerEndFrame := (I + 1) * 1000;
    Result[I].SelectedCandidate := -1;
    SetLength(Result[I].Analysis.Candidates, 2);
    for J := 0 to 1 do
    begin
      Result[I].Analysis.Candidates[J].Bpm := 120;
      Result[I].Analysis.Candidates[J].PeriodFrames := 500;
      Result[I].Analysis.Candidates[J].PhaseFrame := J * 250;
      Result[I].Analysis.Candidates[J].Score := 0.5;
    end;
  end;
end;

procedure CheckCandidatePaths;
var
  LWindows: TBeatTrackWindows;
  LChosen: TBeatTrackWindows;
  LReplay: TBeatTrackWindows;
  LOptions: TBeatTrackOptions;
  LBest: Double;
  LScore: Double;
  LActual: Double;
  LMask: Integer;
  LPrevious: Integer;
  LChoice: Integer;
  LFailed: Boolean;
  I: Integer;
begin
  LOptions := DefaultBeatTrackOptions(1000);
  LWindows := CandidateWindows(3);
  LWindows[0].Analysis.Candidates[0].Score := 0.9;
  LWindows[0].Analysis.Candidates[1].Score := 0.65;
  LWindows[1].Analysis.Candidates[0].Score := 0.7;
  LWindows[1].Analysis.Candidates[1].Score := 0.8;
  LWindows[2].Analysis.Candidates[0].Score := 0.9;
  LWindows[2].Analysis.Candidates[1].Score := 0.65;
  LChosen := SelectBeatTrackPath(LWindows, LOptions);
  LReplay := SelectBeatTrackPath(LWindows, LOptions);
  LBest := -1E300;
  for LMask := 0 to 7 do
  begin
    LScore := 0;
    LPrevious := -1;
    for I := 0 to 2 do
    begin
      LChoice := (LMask shr I) and 1;
      LScore := LScore + LWindows[I].Analysis.Candidates[LChoice].Score;
      if (LPrevious >= 0) and (LPrevious <> LChoice) then
      begin
        LScore := LScore - 0.25;
      end;
      LPrevious := LChoice;
    end;
    LBest := Max(LBest, LScore);
  end;
  LActual := 0;
  for I := 0 to 2 do
  begin
    Check((LChosen[I].SelectedCandidate = 0) and
      (LReplay[I].SelectedCandidate = LChosen[I].SelectedCandidate), 'Stable phase and replay');
    Check(LWindows[I].SelectedCandidate = -1, 'Borrowed input unchanged');
    LActual := LActual + LChosen[I].Analysis.Candidates[0].Score;
  end;
  Check(Abs(LActual - LBest) < 1e-12, 'Exhaustive independent maximum');
  LChosen[0].Analysis.Candidates[0].Score := 0;
  Check(Abs(LWindows[0].Analysis.Candidates[0].Score - 0.9) < 1e-12, 'Detached candidates');

  LWindows := CandidateWindows(3);
  LChosen := SelectBeatTrackPath(LWindows, LOptions);
  for I := 0 to 2 do
  begin
    Check(LChosen[I].SelectedCandidate = 0, 'Earlier equal alternative; no confidence claim');
  end;
  LWindows := CandidateWindows(2);
  LWindows[0].Analysis.Candidates[0].Score := 0.8;
  LWindows[0].Analysis.Candidates[1].Score := 0.1;
  LWindows[1].Analysis.Candidates[0].Score := 0.5;
  LWindows[1].Analysis.Candidates[1].Score := 0.65;
  LChosen := SelectBeatTrackPath(LWindows, LOptions);
  Check(LChosen[1].SelectedCandidate = 0, 'Unbroken phase support');
  LWindows[1].StartsNewPath := True;
  LChosen := SelectBeatTrackPath(LWindows, LOptions);
  Check((LChosen[1].SelectedCandidate = 1) and LChosen[1].StartsNewPath, 'Explicit restart');

  LWindows := CandidateWindows(3);
  LWindows[1].Analysis.Candidates := nil;
  LWindows[2].Analysis.Candidates[1].Score := 0.8;
  LChosen := SelectBeatTrackPath(LWindows, LOptions);
  Check((LChosen[1].SelectedCandidate = -1) and (LChosen[2].SelectedCandidate = 1) and
    LChosen[2].StartsNewPath, 'Missing owner breaks continuity');
  LWindows := CandidateWindows(2);
  for I := 0 to 1 do
  begin
    LWindows[0].Analysis.Candidates[I].Bpm := 80;
    LWindows[0].Analysis.Candidates[I].PeriodFrames := 750;
    LWindows[1].Analysis.Candidates[I].Bpm := 200;
    LWindows[1].Analysis.Candidates[I].PeriodFrames := 300;
  end;
  LChosen := SelectBeatTrackPath(LWindows, LOptions);
  Check(LChosen[1].StartsNewPath, 'Incompatible ratio restarts');
  LWindows[0].Analysis.Candidates[0].Score := NaN;
  LFailed := False;
  try
    LChosen := SelectBeatTrackPath(LWindows, LOptions);
  except
    on EAudio do
    begin
      LFailed := True;
    end;
  end;
  Check(LFailed and LChosen[1].StartsNewPath, 'Invalid input preserves result');
  LWindows := CandidateWindows(1);
  SetLength(LWindows[0].Analysis.Candidates, MaximumBeatPathCandidates + 1);
  LFailed := False;
  try
    LChosen := SelectBeatTrackPath(LWindows, LOptions);
  except
    on EAudio do
    begin
      LFailed := True;
    end;
  end;
  Check(LFailed and (Length(LChosen) = 2), 'Candidate count rejects without replacing result');
  LWindows := CandidateWindows(1);
  LWindows[0].Analysis.Candidates[0].PeriodFrames := 1E-300;
  LFailed := False;
  try
    LChosen := SelectBeatTrackPath(LWindows, LOptions);
  except
    on EAudio do
    begin
      LFailed := True;
    end;
  end;
  Check(LFailed, 'Tiny unsafe period rejects before arithmetic');
  LWindows := CandidateWindows(MaximumBeatTrackWindows);
  for I := 0 to High(LWindows) do
  begin
    LWindows[I].Analysis.Candidates := nil;
  end;
  LChosen := SelectBeatTrackPath(LWindows, LOptions);
  Check((Length(LChosen) = MaximumBeatTrackWindows) and
    (LChosen[High(LChosen)].SelectedCandidate = -1), 'Maximum empty windows retain unknown');
  WriteLn('PASS phase continuity, exhaustive optimum, ties, explicit/missing/incompatible breaks, replay and ownership');
end;

procedure Run;
const
  CRate = 8000;
var
  LObservations: TBeatObservations;
  LTrack: TBeatTrack;
  LOther: TBeatTrack;
  LOptions: TBeatTrackOptions;
  LGridOptions: TBeatGridOptions;
  LIndex: Integer;
  LWindow: Integer;
  LSelected: Integer;
  LStartCount: Integer;
  LRejected: Boolean;
  LBefore: Integer;
  LAdmitted: TBeatTrackAdmission;
begin
  LOptions := DefaultBeatTrackOptions(CRate);
  { Preserve the previously checked one-second-hop path as an explicit caller
    option while the default uses bounded half-overlap for long sources. }
  LOptions.HopFrames := CRate;
  LGridOptions := DefaultBeatGridOptions;
  SetLength(LObservations, 24);
  for LIndex := 0 to High(LObservations) do
  begin
    if LIndex < 12 then
    begin
      LObservations[LIndex].Frame := 973 + LIndex * 4000;
    end
    else
    begin
      LObservations[LIndex].Frame := 973 + 12 * 4000 + (LIndex - 12) * 4800;
    end;
    LObservations[LIndex].Weight := 1;
  end;
  LTrack := TrackBeatGrids(LObservations, CRate, CRate * 14, LGridOptions, LOptions);
  Check(Length(LTrack.Frames) = 24, 'Tempo change retains one point per authored beat');
  for LIndex := 0 to High(LTrack.Frames) do
  begin
    Check(Abs(LTrack.Frames[LIndex] - LObservations[LIndex].Frame) <= 240,
      'Tempo change frame ' + IntToStr(LIndex) + ' differs by ' +
      IntToStr(LTrack.Frames[LIndex] - LObservations[LIndex].Frame));
    Check(LObservations[LIndex].Weight = 1, 'Taper does not mutate borrowed observations');
    if LIndex > 0 then
    begin
      Check(LTrack.Frames[LIndex] > LTrack.Frames[LIndex - 1], 'Tracked frames are ordered and unique');
    end;
    LWindow := LTrack.FrameWindows[LIndex];
    Check((LTrack.GridFrames[LIndex] >= LTrack.Windows[LWindow].OwnerStartFrame) and
      (LTrack.GridFrames[LIndex] < LTrack.Windows[LWindow].OwnerEndFrame),
      'Every raw point belongs to its declared half-open hop interval');
    Check((LTrack.ObservationIndices[LIndex] = LIndex) and
      (LTrack.Frames[LIndex] = LObservations[LIndex].Frame),
      'Aligned point retains its actual source onset identity');
  end;
  LSelected := LTrack.Windows[1].SelectedCandidate;
  Check(Abs(LTrack.Windows[1].Analysis.Candidates[LSelected].Bpm - 120) < 0.5,
    'Early window retains 120 BPM');
  LSelected := LTrack.Windows[11].SelectedCandidate;
  Check(Abs(LTrack.Windows[11].Analysis.Candidates[LSelected].Bpm - 100) < 0.5,
    'Late window follows 100 BPM');
  Check(LTrack.SeamIssues = 0, 'Authored tempo change has no severe seam interval');
  LAdmitted := AdmitBeatTrackRange(LTrack, CRate, CRate * 14, 0, 23, 480, 240,
    MakeKeyContext(-1, dmMajor));
  Check((LAdmitted.SourceStartFrame = 973) and (Length(LAdmitted.Grid.Tempos) = 46) and
    (LAdmitted.Grid.Tempos[0] = 500000) and (LAdmitted.Grid.Tempos[24] = 600000) and
    (LAdmitted.Grid.Keys[24].Root = -1), 'Changing source clock reaches context without key inference');
  for LIndex := 0 to High(LAdmitted.BoundaryErrors) do
  begin
    Check(LAdmitted.BoundaryErrors[LIndex] = 0, 'Exact integer source beat boundary');
  end;
  LAdmitted := AdmitBeatTrackRange(LTrack, 44100, CRate * 14, 0, 23, 480, 240,
    MakeKeyContext(-1, dmMajor));
  for LIndex := 0 to High(LAdmitted.BoundaryErrors) do
  begin
    Check(Abs(LAdmitted.BoundaryErrors[LIndex]) <= 1, 'Cumulative rounding bounds source-clock error');
  end;
  LBefore := LTrack.Frames[0];
  LOther := TrackBeatGrids(LObservations, CRate, CRate * 14, LGridOptions, LOptions);
  LOther.Windows[0].Analysis.Candidates[0].Bpm := 333;
  LOther.Frames[0] := 0;
  Check((LTrack.Frames[0] = LBefore) and
    (LTrack.Windows[0].Analysis.Candidates[0].Bpm <> 333),
    'Separate track results own detached candidate and frame arrays');
  LOptions.SnapToleranceSeconds := 0;
  LOther := TrackBeatGrids(LObservations, CRate, CRate * 14, LGridOptions, LOptions);
  for LIndex := 0 to High(LOther.Frames) do
  begin
    Check((LOther.Frames[LIndex] = LOther.GridFrames[LIndex]) and
      (LOther.ObservationIndices[LIndex] = -1), 'Explicitly disabled alignment retains raw grids');
  end;
  LOptions := DefaultBeatTrackOptions(CRate);

  LOptions.HopFrames := 1;
  LRejected := False;
  try
    LTrack := TrackBeatGrids(LObservations, CRate, CRate * 14, LGridOptions, LOptions);
  except
    on EAudio do
    begin
      LRejected := True;
    end;
  end;
  Check(LRejected and (LTrack.Frames[0] = LBefore),
    'Window budget rejection preserves the prior complete result');
  LOptions := DefaultBeatTrackOptions(CRate);
  LOptions.HopFrames := CRate;
  SetLength(LObservations, MaximumBeatObservations);
  for LIndex := 0 to High(LObservations) do
  begin
    LObservations[LIndex].Frame := LIndex * 29;
    LObservations[LIndex].Weight := 1;
  end;
  LRejected := False;
  try
    LTrack := TrackBeatGrids(LObservations, CRate, CRate * 30, LGridOptions, LOptions);
  except
    on EAudio do
    begin
      LRejected := True;
    end;
  end;
  Check(LRejected and (LTrack.Frames[0] = LBefore),
    'Aggregate fitting budget rejects valid dense observations before fitting');

  SetLength(LObservations, 20);
  for LIndex := 0 to 9 do
  begin
    LObservations[LIndex].Frame := 973 + LIndex * 4000;
    LObservations[LIndex].Weight := 1;
    LObservations[LIndex + 10].Frame := 144973 + LIndex * 4000;
    LObservations[LIndex + 10].Weight := 1;
  end;
  LTrack := TrackBeatGrids(LObservations, CRate, CRate * 24, LGridOptions, LOptions);
  Check(LTrack.Windows[10].SelectedCandidate = -1, 'Evidence-free central window remains a gap');
  LRejected := False;
  try
    LAdmitted := AdmitBeatTrackRange(LTrack, CRate, CRate * 24, 0,
      High(LTrack.Frames), 480, 240, MakeKeyContext(-1, dmMajor));
  except
    on EAudio do
    begin
      LRejected := True;
    end;
  end;
  Check(LRejected and (LAdmitted.SourceStartFrame = 973),
    'Gap admission rejects without replacing accepted timing');
  LStartCount := 0;
  for LWindow := 0 to High(LTrack.Windows) do
  begin
    if LTrack.Windows[LWindow].StartsNewPath then
    begin
      Inc(LStartCount);
    end;
  end;
  Check(LStartCount = 2, 'Disconnected evidence begins two explicit paths');
  for LIndex := 0 to High(LTrack.Frames) do
  begin
    Check((LTrack.Frames[LIndex] < CRate * 6) or
      (LTrack.Frames[LIndex] >= CRate * 17), 'No extrapolation through long silence');
  end;
  LTrack := TrackBeatGrids(nil, CRate, CRate * MaximumBeatTrackWindows,
    LGridOptions, LOptions);
  Check((Length(LTrack.Frames) = 0) and (LTrack.SeamIssues = 0) and
    (LTrack.FitWork = 0) and (Length(LTrack.Windows) = MaximumBeatTrackWindows),
    'Silent source reaches window bound without invented pulses or fitting charges');

  LObservations[1].Frame := LObservations[0].Frame;
  LRejected := False;
  try
    LTrack := TrackBeatGrids(LObservations, CRate, CRate * 24, LGridOptions, LOptions);
  except
    on EAudio do
    begin
      LRejected := True;
    end;
  end;
  Check(LRejected and (Length(LTrack.Frames) = 0), 'Duplicate input rejects without changing silence result');
  WriteLn('Beat tracking: changing tempo, half-open ownership, gaps, detached results and work limits pass');
end;

procedure CheckDefaultHalfOverlap;
const
  CRate = 8000;
  CFrames = CRate * 30;
var
  LObservations: TBeatObservations;
  LTrack: TBeatTrack;
  LOptions: TBeatTrackOptions;
  LGridOptions: TBeatGridOptions;
  LFitWork: Int64;
  LRejected: Boolean;
  LIndex: Integer;
begin
  LOptions := DefaultBeatTrackOptions(CRate);
  LGridOptions := DefaultBeatGridOptions;
  Check((LOptions.WindowFrames = CRate * 6) and
    (LOptions.HopFrames = CRate * 3),
    'Default tracked windows have half overlap');
  SetLength(LObservations, 750);
  for LIndex := 0 to High(LObservations) do
  begin
    LObservations[LIndex].Frame := LIndex * 320;
    LObservations[LIndex].Weight := 1;
  end;
  LTrack := TrackBeatGrids(LObservations, CRate, CFrames,
    LGridOptions, LOptions);
  Check((Length(LTrack.Windows) = 10) and
    (LTrack.FitWork > 0) and
    (LTrack.FitWork <= MaximumBeatTrackWork),
    'Authored dense thirty-second source fits unchanged aggregate budget');
  SetLength(LObservations, 60);
  for LIndex := 0 to High(LObservations) do
  begin
    LObservations[LIndex].Frame := 973 + LIndex * 4000;
    LObservations[LIndex].Weight := 1;
  end;
  LTrack := TrackBeatGrids(LObservations, CRate, CFrames,
    LGridOptions, LOptions);
  Check((Length(LTrack.Windows) = 10) and
    (Length(LTrack.Frames) = Length(LObservations)) and
    (LTrack.SeamIssues = 0),
    'Default half-overlap retains an authored 120 BPM pulse through seams');
  for LIndex := 0 to High(LTrack.Frames) do
  begin
    Check(Abs(LTrack.Frames[LIndex] - LObservations[LIndex].Frame) <= 240,
      'Default half-overlap pulse remains source aligned');
  end;
  LFitWork := LTrack.FitWork;
  SetLength(LObservations, 6000);
  for LIndex := 0 to High(LObservations) do
  begin
    LObservations[LIndex].Frame := LIndex * 40;
    LObservations[LIndex].Weight := 1;
  end;
  LRejected := False;
  try
    LTrack := TrackBeatGrids(LObservations, CRate, CFrames,
      LGridOptions, LOptions);
  except
    on EAudio do
    begin
      LRejected := True;
    end;
  end;
  Check(LRejected and (LTrack.FitWork = LFitWork),
    'Extreme authored density rejects without replacing prior result');
  WriteLn('Default half-overlap: dense capacity, 120 BPM seams and extreme rejection pass');
end;

begin
  try
    CheckCandidatePaths;
    Run;
    CheckDefaultHalfOverlap;
  except
    on LError: Exception do
    begin
      WriteLn(StdErr, LError.Message);
      Halt(1);
    end;
  end;
end.
