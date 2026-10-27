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
program pythian_tests_measurement_progress;

{$mode delphi}{$H+}

uses
  {$ifdef pas2js}JS,{$endif}
  Classes, SysUtils, Math,
  pythian.audio, pythian.progress, pythian.time,
  pythian.music.grid.frames, pythian.passage, pythian.rhythm.admission,
  pythian.pitch, pythian.pitch.cells, pythian.onset.dynamics;

type
  TObserver = class
  public
    Calls: Integer;
    AbortStage: String;
    AbortMinimum: Int64;
    Interior: Boolean;
    Marker: Exception;
    Cells: Int64;
    Estimates: Int64;
    CopiedFrames: Int64;
    DynamicsFrames: Int64;
    DynamicsWindows: Int64;
    procedure Observe(const AWork: TWorkProgress);
  end;

var
  GChecks: Integer;
  GObserver: TObserver;
  GClip: TAudioClip;
  GGrid: TMusicGridFrames;
  GOptions: TPitchOptions;
  GEvidence: TPitchCellEvidence;
  GDynamics: TOnsetDynamics;
  GFrames: TPassageBounds;
  GAdmission: TRhythmAdmission;

procedure Check(const ACondition: Boolean; const AMessage: String);
begin
  Inc(GChecks);
  if not ACondition then
  begin
    raise Exception.Create(AMessage);
  end;
end;

procedure TObserver.Observe(const AWork: TWorkProgress);
begin
  Inc(Calls);
  if (AWork.Done < 0) or (AWork.Total < 0) or
    ((AWork.Total > 0) and (AWork.Done > AWork.Total)) then
  begin
    raise Exception.Create('Invalid work counters');
  end;
  if AWork.Done = AWork.Total then
  begin
    if AWork.Stage = 'pitch_cell_measure' then
    begin
      Cells := AWork.Done;
    end;
    if AWork.Stage = 'pitch_cell_estimates' then
    begin
      Estimates := AWork.Done;
    end;
    if AWork.Stage = 'pitch_cell_window_frames' then
    begin
      CopiedFrames := AWork.Done;
    end;
    if AWork.Stage = 'dynamics_window_frames' then
    begin
      DynamicsFrames := AWork.Done;
    end;
    if AWork.Stage = 'dynamics_windows' then
    begin
      DynamicsWindows := AWork.Done;
    end;
  end;
  if (AWork.Stage = AbortStage) and (AWork.Done >= AbortMinimum) and
    (not Interior or (AWork.Total = 0) or (AWork.Done < AWork.Total)) then
  begin
    raise Marker;
  end;
end;

function EvidenceStamp(const AEvidence: TPitchCellEvidence): String;
var
  LCell: TPitchCell;
begin
  Result := IntToStr(AEvidence.WindowFrames) + '/' + IntToStr(AEvidence.Channel) + '/';
  for LCell in AEvidence.Cells do
  begin
    Result := Result + IntToStr(Ord(LCell.Measured)) + ':' +
      IntToStr(Ord(LCell.Estimate.Status)) + ':' +
      FloatToStr(LCell.Estimate.FrequencyHz) + ':' +
      FloatToStr(LCell.Estimate.PeriodFrames) + ':' +
      FloatToStr(LCell.Estimate.NormalizedDifference) + ':' +
      FloatToStr(LCell.Estimate.AcRms) + ':' +
      IntToStr(LCell.Estimate.NearestMidi) + ':' +
      FloatToStr(LCell.Estimate.CentsError) + ';';
  end;
end;

function DynamicsStamp(const AData: TOnsetDynamics): String;
var
  LValue: Double;
begin
  Result := IntToStr(AData.WindowFrames) + '/';
  for LValue in AData.Rms do
  begin
    Result := Result + FloatToStr(LValue) + ';';
  end;
end;

procedure CompareEvidence(const ALeft, ARight: TPitchCellEvidence);
var
  LIndex: Integer;
begin
  Check((ALeft.WindowFrames = ARight.WindowFrames) and
    (ALeft.Channel = ARight.Channel) and (ALeft.MaximumCents = ARight.MaximumCents) and
    (ALeft.Options.MinimumHz = ARight.Options.MinimumHz) and
    (ALeft.Options.MaximumHz = ARight.Options.MaximumHz) and
    (ALeft.Options.DifferenceThreshold = ARight.Options.DifferenceThreshold) and
    (ALeft.Options.SilenceRms = ARight.Options.SilenceRms) and
    (Length(ALeft.Cells) = Length(ARight.Cells)), 'Pitch metadata differs');
  for LIndex := 0 to High(ALeft.Cells) do
  begin
    Check((ALeft.Cells[LIndex].Measured = ARight.Cells[LIndex].Measured) and
      (ALeft.Cells[LIndex].Estimate.Status = ARight.Cells[LIndex].Estimate.Status) and
      (ALeft.Cells[LIndex].Estimate.FrequencyHz = ARight.Cells[LIndex].Estimate.FrequencyHz) and
      (ALeft.Cells[LIndex].Estimate.PeriodFrames = ARight.Cells[LIndex].Estimate.PeriodFrames) and
      (ALeft.Cells[LIndex].Estimate.NormalizedDifference = ARight.Cells[LIndex].Estimate.NormalizedDifference) and
      (ALeft.Cells[LIndex].Estimate.AcRms = ARight.Cells[LIndex].Estimate.AcRms) and
      (ALeft.Cells[LIndex].Estimate.NearestMidi = ARight.Cells[LIndex].Estimate.NearestMidi) and
      (ALeft.Cells[LIndex].Estimate.CentsError = ARight.Cells[LIndex].Estimate.CentsError),
      'Observed estimate fields differ');
  end;
end;

function Exercise(const AOperation: Integer;
  const ACallback: TWorkProgressCallback): String;
var
  LNotes: TPitchNotes;
  LSummary: TPitchCellSummary;
  LIndex: Integer;
  LEvidence: TPitchCellEvidence;
begin
  Result := '';
  case AOperation of
    0: Result := EvidenceStamp(MeasurePitchCells(GClip, GGrid, 1, GOptions, 50, ACallback));
    1: Result := EvidenceStamp(MeasurePitchCells(GClip, 500000, 480, 240,
      1, GOptions, 50, 0, ACallback));
    2: LNotes := AdmitPitchCells(GEvidence, GGrid, 2, ACallback);
    3: LSummary := SummarizePitchCells(GEvidence, GGrid, 2, ACallback);
    4: Result := DynamicsStamp(MeasureOnsetDynamics(GClip, GFrames, 64, ACallback));
    5:
      begin
        ValidateOnsetDynamics(GDynamics, Length(GFrames), 2, ACallback);
        Result := DynamicsStamp(GDynamics);
      end;
    6: Result := OnsetIntensityPattern(GAdmission, GDynamics, ACallback);
    7, 8:
      begin
        LEvidence := MeasurePitchCells(GClip, 500000, 480, 240, 1, GOptions, 50);
        if AOperation = 7 then
        begin
          LNotes := AdmitPitchCells(LEvidence, 1000, 2, 12000, 500000, 480, 240,
            0, ACallback);
        end
        else
        begin
          LSummary := SummarizePitchCells(LEvidence, 1000, 2, 12000, 500000,
            480, 240, 0, ACallback);
        end;
      end;
  end;
  if AOperation in [2, 7] then
  begin
    for LIndex := 0 to High(LNotes) do
    begin
      Result := Result + IntToStr(LNotes[LIndex]) + ',';
    end;
  end;
  if AOperation in [3, 8] then
  begin
    Result := IntToStr(LSummary.Cells) + '/' + IntToStr(LSummary.AdmittedPitch) + '/' +
      IntToStr(LSummary.MeasuredSilence) + '/' + IntToStr(LSummary.UncertainPitch) + '/' +
      IntToStr(LSummary.Unmeasured) + '/' + IntToStr(LSummary.KnownRuns) + '/' +
      IntToStr(LSummary.LongestKnownRun);
  end;
end;

procedure AbortAndRetry(const AOperation: Integer; const AStage: String;
  const AMinimum: Int64; const AInterior: Boolean);
var
  LExpected: String;
  LRetained: String;
  LRejected: Boolean;
  LPitchRetained: TPitchCellEvidence;
  LDynamicsRetained: TOnsetDynamics;
  LNotesRetained: TPitchNotes;
  LSummaryRetained: TPitchCellSummary;
begin
  LExpected := Exercise(AOperation, nil);
  LRetained := 'unpublished sentinel';
  LPitchRetained := Default(TPitchCellEvidence);
  LPitchRetained.WindowFrames := 123;
  LDynamicsRetained := Default(TOnsetDynamics);
  LDynamicsRetained.WindowFrames := 123;
  LNotesRetained := [999];
  LSummaryRetained := Default(TPitchCellSummary);
  LSummaryRetained.Cells := 123;
  LRejected := False;
  GObserver.AbortStage := AStage;
  GObserver.AbortMinimum := AMinimum;
  GObserver.Interior := AInterior;
  GObserver.Marker := Exception.Create('Big Boss measurement observer marker');
  try
    try
      case AOperation of
        0: LPitchRetained := MeasurePitchCells(GClip, GGrid, 1, GOptions, 50,
          GObserver.Observe);
        1: LPitchRetained := MeasurePitchCells(GClip, 500000, 480, 240, 1,
          GOptions, 50, 0, GObserver.Observe);
        2: LNotesRetained := AdmitPitchCells(GEvidence, GGrid, 2, GObserver.Observe);
        3: LSummaryRetained := SummarizePitchCells(GEvidence, GGrid, 2, GObserver.Observe);
        4: LDynamicsRetained := MeasureOnsetDynamics(GClip, GFrames, 64, GObserver.Observe);
        5: ValidateOnsetDynamics(GDynamics, Length(GFrames), 2, GObserver.Observe);
        6: LRetained := OnsetIntensityPattern(GAdmission, GDynamics, GObserver.Observe);
      end;
    except
      on LException: Exception do
      begin
        if LException <> GObserver.Marker then
        begin
          raise;
        end;
        GObserver.Marker := nil;
        LRejected := True;
      end;
    end;
  finally
    GObserver.Marker.Free;
    GObserver.Marker := nil;
    GObserver.AbortStage := '';
  end;
  Check(LRejected, 'Missing original observer exception: ' + AStage);
  case AOperation of
    0, 1: Check((LPitchRetained.WindowFrames = 123) and
      (Length(LPitchRetained.Cells) = 0), 'Partial pitch record escaped: ' + AStage);
    2: Check((Length(LNotesRetained) = 1) and (LNotesRetained[0] = 999),
      'Partial notes escaped: ' + AStage);
    3: Check(LSummaryRetained.Cells = 123, 'Partial summary escaped: ' + AStage);
    4: Check((LDynamicsRetained.WindowFrames = 123) and
      (Length(LDynamicsRetained.Rms) = 0), 'Partial dynamics escaped: ' + AStage);
    6: Check(LRetained = 'unpublished sentinel', 'Partial pattern escaped: ' + AStage);
  end;
  Check(Exercise(AOperation, GObserver.Observe) = LExpected, 'Retry differs: ' + AStage);
end;

function MeasurementTick: Int64;
begin
  {$ifdef pas2js}
  Result := TJSDate.now;
  {$else}
  Result := GetTickCount64;
  {$endif}
end;

procedure MeasureResidual;
var
  LSamples: TAudioSamples;
  LOptions: TPitchOptions;
  LIndex: Integer;
  LStart: Int64;
  LEstimate: TPitchEstimate;
begin
  SetLength(LSamples, MaximumPitchWindowFrames);
  for LIndex := 0 to High(LSamples) do
  begin
    LSamples[LIndex] := 0.3 * Sin(2 * Pi * 125 * LIndex / 1000);
  end;
  LOptions := GOptions;
  LOptions.MinimumHz := 1000 / 4094;
  LStart := MeasurementTick;
  LEstimate := EstimatePitch(LSamples, 1000, 1, 0, LOptions);
  WriteLn('Synchronous EstimatePitch: 8192 frames, ',
    PitchEstimateWork(8192, 1000, 1, 0, LOptions), ' squared-difference terms, ',
    MeasurementTick - LStart, ' ms; local observation, no latency bound');
  Check(LEstimate.Status = psEstimated, 'Residual fixture must exercise an estimate');
end;

var
  LSamples: TAudioSamples;
  LBefore: TAudioSamples;
  LClock: TTempoMap;
  LCellBefore: String;
  LDynamicsBefore: String;
  LIndex: Integer;
  LTotalFrames: Int64;
  LEmpty: TOnsetDynamics;
  LShort: TPitchCellSummary;
  LObservedEvidence: TPitchCellEvidence;
  LObservedDynamics: TOnsetDynamics;
begin
  GObserver := TObserver.Create;
  LClock := nil;
  try
    SetLength(LSamples, 24000);
    for LIndex := 0 to 11999 do
    begin
      LSamples[2 * LIndex] := 0.3 * Sin(2 * Pi * 125 * LIndex / 1000);
      LSamples[2 * LIndex + 1] := -LSamples[2 * LIndex];
    end;
    GClip := TAudioClip.Create(1000, 2, LSamples);
    LBefore := GClip.CopySamples;
    LClock := TTempoMap.Create(480, 64 * 240,
      [MakeTempoChange(0, 500000), MakeTempoChange(32 * 240, 75000)]);
    GGrid := TMusicGridFrames.Create(LClock, 1000, 12000, 0, 0, 240, 64);
    GOptions := DefaultPitchOptions;
    GOptions.MaximumHz := 440;
    GEvidence := MeasurePitchCells(GClip, GGrid, 1, GOptions, 50);
    LCellBefore := EvidenceStamp(GEvidence);
    Check(Exercise(0, GObserver.Observe) = LCellBefore, 'Changing-grid estimates differ');
    LObservedEvidence := MeasurePitchCells(GClip, GGrid, 1, GOptions, 50, GObserver.Observe);
    CompareEvidence(GEvidence, LObservedEvidence);
    Check((GObserver.Cells = 64) and (GObserver.Estimates = 32) and
      (GObserver.CopiedFrames = 32 * GEvidence.WindowFrames),
      'Skipped cells must not become measured frames/estimates');
    LShort := SummarizePitchCells(GEvidence, GGrid, 2);
    Check(LShort.Unmeasured = 32, 'Short cells stay explicitly unmeasured');
    SetLength(GFrames, 600);
    SetLength(GAdmission.Cells, 600);
    SetLength(GAdmission.Decisions, 600);
    GAdmission.Pattern := StringOfChar('x', 600);
    LTotalFrames := 0;
    for LIndex := 0 to 599 do
    begin
      GFrames[LIndex] := LIndex * 20;
      Inc(LTotalFrames, Min(64, 12000 - GFrames[LIndex]));
      GAdmission.Cells[LIndex] := LIndex;
      GAdmission.Decisions[LIndex] := rodAccepted;
    end;
    GDynamics := MeasureOnsetDynamics(GClip, GFrames, 64);
    LDynamicsBefore := DynamicsStamp(GDynamics);
    Check(Exercise(4, GObserver.Observe) = LDynamicsBefore, 'Stereo/EOF dynamics differ');
    LObservedDynamics := MeasureOnsetDynamics(GClip, GFrames, 64, GObserver.Observe);
    for LIndex := 0 to High(GDynamics.Rms) do
    begin
      Check(GDynamics.Rms[LIndex] = LObservedDynamics.Rms[LIndex],
        'Observed RMS fields differ');
    end;
    Check((GObserver.DynamicsWindows = 600) and
      (GObserver.DynamicsFrames = LTotalFrames) and (LTotalFrames < 600 * 64),
      'EOF-shortened frame visits are inaccurate');
    Check(Abs(GDynamics.Rms[0] - 0.3 / Sqrt(2)) < 1E-7,
      'Opposite stereo channels must not cancel before RMS');
    GAdmission.Decisions[2] := rodTooFar;
    GAdmission.Pattern[3] := '.';
    for LIndex := 0 to 8 do
    begin
      Check(Exercise(LIndex, nil) = Exercise(LIndex, GObserver.Observe),
        'Observed result differs for operation ' + IntToStr(LIndex));
    end;
    AbortAndRetry(0, 'pitch_cell_measure', 8, True);
    AbortAndRetry(0, 'pitch_cell_window_frames', 1024, True);
    AbortAndRetry(0, 'pitch_cell_estimates', 8, True);
    AbortAndRetry(0, 'pitch_cell_validate', 8, True);
    AbortAndRetry(1, 'pitch_cell_grid', 1, False);
    AbortAndRetry(2, 'pitch_cell_validate', 8, True);
    AbortAndRetry(2, 'pitch_cell_validate', 64, False);
    AbortAndRetry(3, 'pitch_cell_summary', 8, True);
    AbortAndRetry(4, 'dynamics_validate_values', 256, True);
    AbortAndRetry(4, 'dynamics_validate_onsets', 256, True);
    AbortAndRetry(4, 'dynamics_window_frames', 1024, True);
    AbortAndRetry(4, 'dynamics_windows', 256, True);
    AbortAndRetry(5, 'dynamics_validate_values', 256, True);
    AbortAndRetry(6, 'dynamics_reference', 256, True);
    AbortAndRetry(6, 'dynamics_projection', 256, True);
    AbortAndRetry(6, 'dynamics_projection_cells', 256, True);
    LEmpty := MeasureOnsetDynamics(GClip, [], 64, GObserver.Observe);
    Check((Length(LEmpty.Rms) = 0) and (GObserver.DynamicsFrames = 0) and
      (GObserver.DynamicsWindows = 0), 'Empty measurement invented work');
    Check((EvidenceStamp(GEvidence) = LCellBefore) and
      (DynamicsStamp(GDynamics) = LDynamicsBefore), 'Borrowed evidence changed');
    LSamples := GClip.CopySamples;
    for LIndex := 0 to High(LBefore) do
    begin
      Check(LSamples[LIndex] = LBefore[LIndex], 'Borrowed audio changed');
    end;
    Check(GObserver.Calls < 4000, 'Measurement callbacks must remain aggregated');
    MeasureResidual;
    WriteLn('Measurement progress: ', GChecks,
      ' checks, 16 original abort/retry selections; unchanged output and actual work pass');
  finally
    GGrid.Free;
    LClock.Free;
    GClip.Free;
    GObserver.Free;
  end;
end.
