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
program pythian_tests_beat_pulse;

{$mode delphi}
{$H+}

uses
  SysUtils,
  pythian.beat,
  pythian.beat.track,
  pythian.beat.pulse;

procedure Check(const ACondition: Boolean; const AMessage: String);
begin
  if not ACondition then
  begin
    raise Exception.Create(AMessage);
  end;
end;

procedure SameFrames(const ALeft, ARight: TBeatFrames; const AMessage: String);
var
  LIndex: Integer;
begin
  Check(Length(ALeft) = Length(ARight), AMessage + ' length');
  for LIndex := 0 to High(ALeft) do
  begin
    Check(ALeft[LIndex] = ARight[LIndex], AMessage + ' frame ' +
      IntToStr(LIndex));
  end;
end;

function Frames(const AValues: array of Integer): TBeatFrames;
var
  LIndex: Integer;
begin
  Result := nil;
  SetLength(Result, Length(AValues));
  for LIndex := 0 to High(AValues) do
  begin
    Result[LIndex] := AValues[LIndex];
  end;
end;

function MakeWindows: TBeatTrackWindows;
var
  LIndex: Integer;
begin
  Result := nil;
  SetLength(Result, 2);
  for LIndex := 0 to 1 do
  begin
    Result[LIndex].StartFrame := LIndex * 3000;
    Result[LIndex].EndFrame := (LIndex + 1) * 3000;
    Result[LIndex].OwnerStartFrame := LIndex * 3000;
    Result[LIndex].OwnerEndFrame := (LIndex + 1) * 3000;
    Result[LIndex].Analysis.FirstObservationFrame := 100 + LIndex * 3000;
    Result[LIndex].Analysis.LastObservationFrame := 2600 + LIndex * 3000;
    SetLength(Result[LIndex].Analysis.Candidates, 1);
    Result[LIndex].Analysis.Candidates[0].Bpm := 120;
    Result[LIndex].Analysis.Candidates[0].PeriodFrames := 500;
    Result[LIndex].Analysis.Candidates[0].PhaseFrame := 100;
    Result[LIndex].Analysis.Candidates[0].Score := 0.8;
    Result[LIndex].SelectedCandidate := 0;
  end;
end;

function Explicit(const ATrack: TBeatPulseTrack; const AWindow: Integer;
  const APositions, AParents, ADropped: TBeatFrames): TBeatPulseAlternative;
begin
  Result := Default(TBeatPulseAlternative);
  Result.Kind := bpakExplicit;
  Result.SourceId := ATrack.SourceId;
  Result.WindowIndex := AWindow;
  Result.OwnerStartFrame := ATrack.Windows[AWindow].OwnerStartFrame;
  Result.OwnerEndFrame := ATrack.Windows[AWindow].OwnerEndFrame;
  Result.AlternativeIndex := Length(ATrack.Windows[AWindow].Alternatives);
  Result.BaseGridIndex := 0;
  Result.Score := 0.7;
  Result.Frames := Copy(APositions);
  Result.ParentSeedFrames := Copy(AParents);
  Result.DroppedSeedFrames := Copy(ADropped);
end;

procedure ExpectAppendFailure(const ATrack: TBeatPulseTrack;
  const AWindow: Integer; const AAlternative: TBeatPulseAlternative;
  const AName: String);
var
  LRejected: Boolean;
  LOther: TBeatPulseTrack;
  LOriginal: TBeatFrames;
begin
  LOriginal := BeatPulseAlternativeFrames(ATrack, 0, 0);
  LRejected := False;
  try
    LOther := AppendBeatPulseAlternative(ATrack, AWindow, AAlternative);
  except
    on Exception do
    begin
      LRejected := True;
    end;
  end;
  if not LRejected then
  begin
    raise Exception.Create(AName + ' was accepted with ' +
      IntToStr(Length(LOther.Windows)) + ' windows');
  end;
  Check(LRejected, AName + ' was accepted');
  SameFrames(BeatPulseAlternativeFrames(ATrack, 0, 0), LOriginal,
    AName + ' changed retained grid');
  Check(Length(ATrack.Windows[AWindow].Alternatives) = 1,
    AName + ' changed retained alternatives');
end;

procedure ExpectWrapFailure(const AWindows: TBeatTrackWindows;
  const AName, AReason: String);
var
  LRejected: Boolean;
  LOther: TBeatPulseTrack;
  LMessage: String;
begin
  LRejected := False;
  LMessage := '';
  try
    LOther := WrapBeatTrackWindows(AWindows, 'invalid-source', 1000, 6000, 0);
  except
    on LError: Exception do
    begin
      LRejected := True;
      LMessage := LError.Message;
    end;
  end;
  if not LRejected then
  begin
    raise Exception.Create(AName + ' was accepted with ' +
      IntToStr(Length(LOther.Windows)) + ' windows');
  end;
  Check(LRejected and (Pos(AReason, LMessage) > 0),
    AName + ' had wrong wrapper result: ' + LMessage);
end;

procedure ExpectRenderFailure(const ATrack: TBeatPulseTrack;
  const AWindow: Integer; const AName, AReason: String);
var
  LRejected: Boolean;
  LFrames: TBeatFrames;
  LClock: TBeatPulseClock;
  LMessage: String;
begin
  LRejected := False;
  LMessage := '';
  try
    LFrames := BeatPulseAlternativeFrames(ATrack, AWindow, 0);
  except
    on LError: Exception do
    begin
      LRejected := True;
      LMessage := LError.Message;
    end;
  end;
  if not LRejected then
  begin
    raise Exception.Create(AName + ' was rendered with ' +
      IntToStr(Length(LFrames)) + ' frames');
  end;
  Check(LRejected and (Pos(AReason, LMessage) > 0),
    AName + ' had wrong renderer result: ' + LMessage);
  LRejected := False;
  LMessage := '';
  try
    LClock := SelectedBeatPulseClock(ATrack);
  except
    on LError: Exception do
    begin
      LRejected := True;
      LMessage := LError.Message;
    end;
  end;
  if not LRejected then
  begin
    raise Exception.Create(AName + ' clock was accepted with ' +
      IntToStr(Length(LClock.RawFrames)) + ' frames');
  end;
  Check(LRejected and (Pos(AReason, LMessage) > 0),
    AName + ' had wrong clock result: ' + LMessage);
end;

var
  LWindows: TBeatTrackWindows;
  LBase: TBeatPulseTrack;
  LBirth: TBeatPulseTrack;
  LDeath: TBeatPulseTrack;
  LMissing: TBeatPulseTrack;
  LVariable: TBeatPulseTrack;
  LSelected: TBeatPulseTrack;
  LClock: TBeatPulseClock;
  LAlternative: TBeatPulseAlternative;
  LExpected: TBeatFrames;
  LIndex: Integer;
  LObservations: TBeatObservations;
  LMeasured: TBeatTrack;
  LGridOptions: TBeatGridOptions;
  LTrackOptions: TBeatTrackOptions;
  LManyWindows: TBeatTrackWindows;
  LTooLong: TBeatPulseTrack;
  LRejected: Boolean;
  LInvalid: TBeatTrackWindows;
  LMutated: TBeatPulseTrack;
begin
  LWindows := MakeWindows;
  LBase := WrapBeatTrackWindows(LWindows, 'authored-source-1', 1000, 6000, 0);
  Check((Length(LBase.Windows) = 2) and
    (Length(LBase.Windows[0].Alternatives) = 1) and
    (LBase.Windows[0].Alternatives[0].AlternativeIndex = 0) and
    (LBase.Windows[1].SourceWindowIndex = 1) and
    (LBase.Windows[1].SelectedAlternative = 0),
    'v1 grid rank, owner or selection changed');
  LInvalid := MakeWindows;
  LInvalid[0].StartFrame := -1;
  ExpectWrapFailure(LInvalid, 'negative analysis start', 'analysis window');
  LInvalid := MakeWindows;
  LInvalid[1].StartFrame := 1000;
  LInvalid[1].Analysis.FirstObservationFrame := 0;
  LInvalid[1].Analysis.LastObservationFrame := 1900;
  ExpectWrapFailure(LInvalid, 'observation outside analysis window',
    'observation span');
  LMutated := SelectBeatPulseAlternative(LBase, 0, 0);
  LMutated.Windows[0].AnalysisStartFrame := -1;
  ExpectRenderFailure(LMutated, 0, 'mutated negative analysis start',
    'analysis window');
  LMutated := SelectBeatPulseAlternative(LBase, 1, 0);
  LMutated.Windows[1].AnalysisStartFrame := 1000;
  LMutated.Windows[1].FirstObservationFrame := 0;
  LMutated.Windows[1].LastObservationFrame := 1900;
  ExpectRenderFailure(LMutated, 1, 'mutated observation span',
    'observation span');
  LMutated := SelectBeatPulseAlternative(LBase, 0, 0);
  LMutated.SupportToleranceFrames := -1;
  ExpectRenderFailure(LMutated, 0, 'negative support tolerance',
    'support tolerance');
  LMutated := SelectBeatPulseAlternative(LBase, 0, 0);
  LMutated.SupportToleranceFrames := 201;
  ExpectRenderFailure(LMutated, 0, 'over-limit support tolerance',
    'support tolerance');
  Check((LBase.Windows[0].AnalysisStartFrame = 0) and
    (LBase.Windows[1].FirstObservationFrame = 3100),
    'negative controls changed retained wrapped source');
  SameFrames(BeatPulseAlternativeFrames(LBase, 0, 0),
    BeatGridFrames(LWindows[0].Analysis.Candidates[0], 100, 2601),
    'v1 first owner parity');
  SameFrames(BeatPulseAlternativeFrames(LBase, 1, 0),
    BeatGridFrames(LWindows[1].Analysis.Candidates[0], 3100, 5601),
    'v1 second owner parity');
  LClock := SelectedBeatPulseClock(LBase);
  Check((Length(LClock.RawFrames) = 12) and
    (LClock.FrameWindows[0] = 0) and (LClock.FrameWindows[6] = 1) and
    (LClock.AlternativeIndices[6] = 0) and
    (LClock.SourceId = 'authored-source-1'),
    'v1 clock owner or identity parity');
  SetLength(LObservations, 12);
  for LIndex := 0 to High(LObservations) do
  begin
    LObservations[LIndex].Frame := 100 + LIndex * 500;
    LObservations[LIndex].Weight := 1;
  end;
  LGridOptions := DefaultBeatGridOptions;
  LTrackOptions := DefaultBeatTrackOptions(1000);
  LMeasured := TrackBeatGrids(LObservations, 1000, 6000,
    LGridOptions, LTrackOptions);
  Check(Length(LMeasured.GridFrames) > 0,
    'authored v1 tracker did not select a grid');
  LSelected := WrapBeatTrackWindows(LMeasured.Windows,
    'authored-measured-source', 1000, 6000,
    Round(1000 * LGridOptions.ToleranceSeconds));
  LClock := SelectedBeatPulseClock(LSelected);
  SameFrames(LClock.RawFrames, LMeasured.GridFrames,
    'maintained tracker raw-grid parity');
  SameFrames(LClock.FrameWindows, LMeasured.FrameWindows,
    'maintained tracker owner parity');

  LAlternative := Explicit(LBase, 0,
    Frames([0, 100, 600, 1100, 1600, 2100, 2600]),
    Frames([-1, 100, 600, 1100, 1600, 2100, 2600]), nil);
  LBirth := AppendBeatPulseAlternative(LBase, 0, LAlternative);
  Check((Length(LBirth.Windows[0].Alternatives) = 2) and
    (LBirth.Windows[0].Alternatives[0].BaseGridIndex = 0) and
    (Length(LBase.Windows[0].Alternatives) = 1),
    'birth changed retained v1 pool');
  LSelected := SelectBeatPulseAlternative(LBirth, 0, 1);
  LClock := SelectedBeatPulseClock(LSelected);
  Check((LClock.RawFrames[0] = 0) and (LClock.SeedFrames[0] = -1) and
    (LClock.FrameWindows[0] = 0) and (LClock.AlternativeIndices[0] = 1) and
    (LClock.FrameWindows[7] = 1) and (LClock.AlternativeIndices[7] = 0) and
    LClock.GapBefore[7], 'frame-zero birth or explicit seam lost');
  Writeln('BIRTH ', LClock.RawFrames[0], ':', LClock.SeedFrames[0],
    ' seam_gap=', Ord(LClock.GapBefore[7]));
  LClock.RawFrames[0] := 77;
  Check(BeatPulseAlternativeFrames(LSelected, 0, 1)[0] = 0,
    'clock output aliases selected alternative');
  LSelected.Windows[0].Alternatives[1].Frames[0] := 42;
  Check(LBirth.Windows[0].Alternatives[1].Frames[0] = 0,
    'selected track aliases appended alternative');

  LAlternative := Explicit(LBase, 0,
    Frames([100, 600, 1100, 1600, 2100]),
    Frames([100, 600, 1100, 1600, 2100]), Frames([2600]));
  LDeath := AppendBeatPulseAlternative(LBase, 0, LAlternative);
  LSelected := SelectBeatPulseAlternative(LDeath, 0, 1);
  LClock := SelectedBeatPulseClock(LSelected);
  Check((Length(LClock.RawFrames) = 11) and
    (LClock.RawFrames[5] = 3100) and LClock.GapBefore[5] and
    (LClock.RunIds[5] = 1), 'edge death did not break next run');
  Writeln('DEATH next=', LClock.RawFrames[5],
    ' gap=', Ord(LClock.GapBefore[5]));

  LAlternative := Explicit(LBase, 0,
    Frames([100, 600, 900, 2100, 2600]),
    Frames([100, 600, 1600, 2100, 2600]), Frames([1100]));
  LMissing := AppendBeatPulseAlternative(LBase, 0, LAlternative);
  LSelected := SelectBeatPulseAlternative(LMissing, 0, 1);
  LClock := SelectedBeatPulseClock(LSelected);
  Check((LClock.RawFrames[2] = 900) and LClock.GapBefore[2] and
    (LClock.RunIds[2] = 1),
    'missing interior pulse was reinterpreted as slow beat');
  Writeln('MISSING next=', LClock.RawFrames[2], ':',
    LClock.SeedFrames[2], ' gap=', Ord(LClock.GapBefore[2]));

  LAlternative := Explicit(LBase, 0,
    Frames([100, 620, 1080, 1650, 2100, 2600]),
    Frames([100, 600, 1100, 1600, 2100, 2600]), nil);
  LVariable := AppendBeatPulseAlternative(LBase, 0, LAlternative);
  LSelected := SelectBeatPulseAlternative(LVariable, 0, 1);
  LClock := SelectedBeatPulseClock(LSelected);
  SameFrames(Copy(LClock.RawFrames, 0, 6), LAlternative.Frames,
    'variable timing round-trip');
  Check((LClock.SeedFrames[1] = 600) and
    (LClock.AlternativeIndices[1] = 1) and (LClock.RunIds[2] = 0),
    'variable timing lineage or continuity changed');

  LAlternative := Explicit(LBase, 0, Frames([100, 600, 1100, 1600, 2100, 2600]),
    Frames([100, 600, 1100, 1600, 2100, 2600]), nil);
  LAlternative.SourceId := 'wrong-source';
  ExpectAppendFailure(LBase, 0, LAlternative, 'wrong source');
  LAlternative.SourceId := LBase.SourceId;
  LAlternative.WindowIndex := 1;
  ExpectAppendFailure(LBase, 0, LAlternative, 'wrong window');
  LAlternative.WindowIndex := 0;
  LAlternative.AlternativeIndex := 3;
  ExpectAppendFailure(LBase, 0, LAlternative, 'wrong alternative rank');
  LAlternative.AlternativeIndex := 1;
  LAlternative.Frames := Frames([100, 600, 600, 1600, 2100, 2600]);
  ExpectAppendFailure(LBase, 0, LAlternative, 'duplicate output');
  LAlternative.Frames := Frames([100, 600, 1100, 1600, 2100, 3000]);
  ExpectAppendFailure(LBase, 0, LAlternative, 'out-of-owner output');
  LAlternative.Frames := Frames([100, 600, 1100, 1600, 2100, 2600]);
  LAlternative.DroppedSeedFrames := Frames([1100]);
  ExpectAppendFailure(LBase, 0, LAlternative, 'reused dropped seed');
  LAlternative.DroppedSeedFrames := nil;
  LAlternative.ParentSeedFrames := Frames([100, 1100, 600, 1600, 2100, 2600]);
  ExpectAppendFailure(LBase, 0, LAlternative, 'reordered seed lineage');
  LAlternative.ParentSeedFrames := Frames([100, 600, 1100, 1600, 2100, 2600]);
  SetLength(LAlternative.Frames, 32769);
  SetLength(LAlternative.ParentSeedFrames, 32769);
  for LIndex := 0 to High(LAlternative.Frames) do
  begin
    LAlternative.Frames[LIndex] := LIndex;
    LAlternative.ParentSeedFrames[LIndex] := -1;
  end;
  LAlternative.DroppedSeedFrames := nil;
  ExpectAppendFailure(LBase, 0, LAlternative, 'stored-frame budget');
  LExpected := BeatPulseAlternativeFrames(LBase, 0, 0);
  Check((Length(LBase.Windows[0].Alternatives) = 1) and
    (LBase.Windows[0].SelectedAlternative = 0) and
    (Length(LExpected) = 6), 'failure changed prior value');
  SetLength(LManyWindows, 512);
  for LIndex := 0 to High(LManyWindows) do
  begin
    LManyWindows[LIndex].StartFrame := LIndex * 20000;
    LManyWindows[LIndex].EndFrame := (LIndex + 1) * 20000;
    LManyWindows[LIndex].OwnerStartFrame := LIndex * 20000;
    LManyWindows[LIndex].OwnerEndFrame := (LIndex + 1) * 20000;
    LManyWindows[LIndex].Analysis.FirstObservationFrame := LIndex * 20000;
    LManyWindows[LIndex].Analysis.LastObservationFrame :=
      (LIndex + 1) * 20000 - 1;
    SetLength(LManyWindows[LIndex].Analysis.Candidates, 1);
    LManyWindows[LIndex].Analysis.Candidates[0].Bpm := 400;
    LManyWindows[LIndex].Analysis.Candidates[0].PeriodFrames := 150;
    LManyWindows[LIndex].Analysis.Candidates[0].PhaseFrame := 0;
    LManyWindows[LIndex].Analysis.Candidates[0].Score := 0.5;
    LManyWindows[LIndex].SelectedCandidate := 0;
  end;
  LTooLong := WrapBeatTrackWindows(LManyWindows, 'budget-source',
    1000, 10240000, 0);
  LRejected := False;
  try
    LClock := SelectedBeatPulseClock(LTooLong);
  except
    on Exception do
    begin
      LRejected := True;
    end;
  end;
  Check(LRejected and (Length(LTooLong.Windows) = 512) and
    (LTooLong.Windows[0].SelectedAlternative = 0),
    'selected clock output budget failed or changed input');
  Writeln('PASS pulse contract: grid parity; birth; edge death; interior gap; ',
    'variable timing; identities; rejects; detached clock');
  Write('CLOCK ', LClock.SourceId, ' ', Length(LClock.RawFrames));
  for LIndex := 0 to High(LClock.RawFrames) do
  begin
    Write(' ', LClock.RawFrames[LIndex], ':', LClock.SeedFrames[LIndex],
      ':', LClock.FrameWindows[LIndex], ':',
      LClock.AlternativeIndices[LIndex], ':', LClock.RunIds[LIndex], ':',
      Ord(LClock.GapBefore[LIndex]));
  end;
  Writeln;
end.
