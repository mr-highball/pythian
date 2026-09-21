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
unit pythian.beat.clock;

{$mode delphi}
{$H+}

interface

uses
  pythian.beat,
  pythian.beat.alignment;

const
  BeatClockMeasurementPolicy = 'owner-center-continuous-phase';
  MaximumBeatClockWindows = 512;
  MaximumBeatClockSegments = 2 * MaximumBeatClockWindows;

type
  TBeatClockShape = (bcsLinear, bcsStepWhenFeasible);
  TBeatClockAlignment = (bcaIndependent, bcaNeighbourSupported);
  TBeatClockOptions = record
    Shape: TBeatClockShape;
    SupportToleranceSeconds: Double;
    SnapToleranceSeconds: Double;
    AlignmentMode: TBeatClockAlignment;
  end;
  TBeatClockWindow = record
    OwnerStartFrame: Integer;
    OwnerEndFrame: Integer;
    HasPulse: Boolean;
    StartsNewRun: Boolean;
    FirstObservationFrame: Integer;
    LastObservationFrame: Integer;
    PeriodFrames: Double;
    PhaseFrame: Double;
  end;
  TBeatClockWindows = array of TBeatClockWindow;
  TBeatClockSegment = record
    StartFrame: Double;
    EndFrame: Double;
    StartCycle: Double;
    EndCycle: Double;
    IntegralResidual: Double;
    PeriodFrames: Double;
    Available: Boolean;
    Ambiguous: Boolean;
    StepPart: Boolean;
    LeftWindow: Integer;
    RightWindow: Integer;
  end;
  TBeatClockSegments = array of TBeatClockSegment;
  TBeatClockPeriods = array of Double;
  TBeatClock = record
    Segments: TBeatClockSegments;
    RawFrames: TBeatFrames;
    Frames: TBeatFrames;
    FrameWindows: TBeatFrames;
    Periods: TBeatClockPeriods;
    ObservationIndices: TBeatFrames;
    AmbiguousIntervals: Integer;
    RejectedIntervals: Integer;
    StepIntervals: Integer;
    CrossingWork: Integer;
    AlignmentChoices: TBeatAlignmentChoices;
  end;

function DefaultBeatClockOptions: TBeatClockOptions;

{ Reconstruct caller-selected pulse hypotheses; no tempo, meter or confidence
  admission. Ordered, contiguous half-open owners must cover the source. Missing
  pulses and StartsNewRun break continuity. Active windows require source-bounded
  observation spans and finite 20..400 BPM-equivalent periods. Observation spans
  and pulse meaning are caller-owned; this function does not measure a WAV.

  Linear phase joins center anchors. The optional step shape solves a feasible
  interior rate switch; it does not detect a musical change. Nonpositive segments
  remain unavailable; exact half-cycle ties remain marked ambiguous. Cycles are
  local to each run. These numerical flags do not establish musical certainty.

  Raw crossings retain owner/support bounds. Optional alignment uses weighted
  nearby observations, disjoint nearest-crossing cells and period/5 caps, and
  cannot enter a missing run or rejected phase interval. Aligned
  frames may cross owner edges; FrameWindows describes the raw crossing. Input
  arrays are borrowed; result arrays are detached. All work/output is bounded,
  and a failed call preserves a previously assigned result. }
{ Neighbour-supported alignment is opt-in and requires positive snap tolerance.
  AlignmentChoices retains unknown/unavailable decisions; independent mode leaves
  it empty and preserves the original policy. Raw fallback is not observed-beat
  admission. Reconstruction, pulse meaning and phase uncertainty are unchanged. }
function ReconstructBeatClock(const AWindows: TBeatClockWindows;
  const AObservations: TBeatObservations; const ASampleRate, ASourceFrames: Integer;
  const AOptions: TBeatClockOptions): TBeatClock;

implementation

uses
  Math,
  pythian.audio;

type
  TAnchor = record
    Frame: Double;
    Cycle: Double;
    Rate: Double;
    Residual: Double;
    Ambiguous: Boolean;
    Window: Integer;
  end;

function DefaultBeatClockOptions: TBeatClockOptions;
begin
  Result.Shape := bcsLinear;
  Result.SupportToleranceSeconds := 0.03;
  Result.SnapToleranceSeconds := 0.1;
  Result.AlignmentMode := bcaIndependent;
end;

function ReconstructBeatClock(const AWindows: TBeatClockWindows;
  const AObservations: TBeatObservations;
  const ASampleRate, ASourceFrames: Integer; const AOptions: TBeatClockOptions): TBeatClock;
var
  LResult: TBeatClock;
  LPrevious: TAnchor;
  LCurrent: TAnchor;
  LFirst: TAnchor;
  LLast: TAnchor;
  LStep: TAnchor;
  LSegment: TBeatClockSegment;
  LFraction: Double;
  LExpected: Double;
  LInteger: Double;
  LTime: Double;
  LRoundingGuard: Double;
  LDuration: Double;
  LContrast: Double;
  LSwitch: Double;
  LCycle: Integer;
  LFrame: Integer;
  LOwner: Integer;
  LTolerance: Integer;
  LPoint: Integer;
  LStart: Integer;
  LEnd: Integer;
  LFirstObservation: Integer;
  LObservation: Integer;
  LBest: Integer;
  LScale: Double;
  LWeight: Double;
  LBestWeight: Double;
  LCount: Integer;
  LCapacity: Integer;
  LCrossings: Integer;
  LInRun: Boolean;
  LHasStep: Boolean;
  LRunStarts: TBeatFrames;
  LRunEnds: TBeatFrames;
  LSpanStarts: TBeatFrames;
  LSpanEnds: TBeatFrames;
  LPointSegments: TBeatFrames;
  LAlignmentCells: TBeatAlignmentCells;
  I: Integer;

  procedure AddSegment(const ALeft, ARight: TAnchor);
  var
    LIndex: Integer;
  begin
    LIndex := Length(LResult.Segments);
    if LIndex >= MaximumBeatClockSegments then
    begin
      raise EAudio.Create('Clock segment bound exceeded');
    end;
    SetLength(LResult.Segments, LIndex + 1);
    LResult.Segments[LIndex].StartFrame := ALeft.Frame;
    LResult.Segments[LIndex].EndFrame := ARight.Frame;
    LResult.Segments[LIndex].StartCycle := ALeft.Cycle;
    LResult.Segments[LIndex].EndCycle := ARight.Cycle;
    LResult.Segments[LIndex].IntegralResidual := ARight.Residual;
    LResult.Segments[LIndex].Ambiguous := ARight.Ambiguous;
    LResult.Segments[LIndex].LeftWindow := ALeft.Window;
    LResult.Segments[LIndex].RightWindow := ARight.Window;
    LResult.Segments[LIndex].Available :=
      (ARight.Frame > ALeft.Frame) and (ARight.Cycle > ALeft.Cycle);
    if LResult.Segments[LIndex].Available then
    begin
      LResult.Segments[LIndex].PeriodFrames :=
        (ARight.Frame - ALeft.Frame) / (ARight.Cycle - ALeft.Cycle);
    end
    else
    begin
      Inc(LResult.RejectedIntervals);
    end;
    if ARight.Ambiguous then
    begin
      Inc(LResult.AmbiguousIntervals);
    end;
  end;

  procedure EndRun;
  begin
    if not LInRun then
    begin
      Exit;
    end;
    LLast := LPrevious;
    LLast.Frame := AWindows[LPrevious.Window].OwnerEndFrame;
    LLast.Cycle := LPrevious.Cycle + (LLast.Frame - LPrevious.Frame) * LPrevious.Rate;
    LLast.Residual := 0;
    LLast.Ambiguous := False;
    AddSegment(LPrevious, LLast);
    LInRun := False;
  end;

begin
  LResult := Default(TBeatClock);
  LPrevious := Default(TAnchor);
  ValidateAudioFormat(ASampleRate, 1);
  RequireFinite(AOptions.SupportToleranceSeconds, 'Clock support tolerance');
  RequireFinite(AOptions.SnapToleranceSeconds, 'Clock alignment tolerance');
  if (Length(AWindows) < 1) or (Length(AWindows) > MaximumBeatClockWindows) or
    (ASourceFrames < 1) or
    (ASourceFrames > MaximumClipSamples) or (Length(AObservations) > MaximumBeatObservations) then
  begin
    raise EAudio.Create('Clock input bounds exceeded');
  end;
  if (Ord(AOptions.Shape) < Ord(Low(TBeatClockShape))) or
    (Ord(AOptions.Shape) > Ord(High(TBeatClockShape))) or
    (Ord(AOptions.AlignmentMode) < Ord(Low(TBeatClockAlignment))) or
    (Ord(AOptions.AlignmentMode) > Ord(High(TBeatClockAlignment))) or
    ((AOptions.AlignmentMode = bcaNeighbourSupported) and
      (AOptions.SnapToleranceSeconds = 0)) or
    (AOptions.SupportToleranceSeconds < 0) or (AOptions.SupportToleranceSeconds > 0.2) or
    (AOptions.SnapToleranceSeconds < 0) or (AOptions.SnapToleranceSeconds > 0.2) then
  begin
    raise EAudio.Create('Clock options exceed bounds');
  end;
  LEnd := 0;
  for I := 0 to High(AWindows) do
  begin
    if (AWindows[I].OwnerStartFrame <> LEnd) or
      (AWindows[I].OwnerEndFrame <= LEnd) or
      (AWindows[I].OwnerEndFrame > ASourceFrames) then
    begin
      raise EAudio.Create('Invalid clock owner/candidate');
    end;
    LEnd := AWindows[I].OwnerEndFrame;
    if AWindows[I].HasPulse then
    begin
      RequireFinite(AWindows[I].PeriodFrames, 'Clock period');
      RequireFinite(AWindows[I].PhaseFrame, 'Clock phase');
      if (AWindows[I].PeriodFrames < ASampleRate * 60 / 400) or
        (AWindows[I].PeriodFrames > ASampleRate * 60 / 20) or
        (Abs(AWindows[I].PhaseFrame) > ASourceFrames) or
        (AWindows[I].FirstObservationFrame < 0) or
        (AWindows[I].LastObservationFrame < AWindows[I].FirstObservationFrame) or
        (AWindows[I].LastObservationFrame >= ASourceFrames) then
      begin
        raise EAudio.Create('Clock pulse or observation span exceeds bounds');
      end;
    end;
  end;
  if LEnd <> ASourceFrames then
  begin
    raise EAudio.Create('Clock owners do not cover source');
  end;
  SetLength(LRunStarts, Length(AWindows));
  SetLength(LRunEnds, Length(AWindows));
  LStart := 0;
  for I := 0 to High(AWindows) do
  begin
    if (I = 0) or AWindows[I].StartsNewRun or not AWindows[I].HasPulse then
    begin
      LStart := AWindows[I].OwnerStartFrame;
    end
    else if not AWindows[I - 1].HasPulse then
    begin
      LStart := AWindows[I].OwnerStartFrame;
    end;
    LRunStarts[I] := LStart;
  end;
  LEnd := ASourceFrames;
  for I := High(AWindows) downto 0 do
  begin
    if (I = High(AWindows)) or not AWindows[I].HasPulse then
    begin
      LEnd := AWindows[I].OwnerEndFrame;
    end
    else if AWindows[I + 1].StartsNewRun or not AWindows[I + 1].HasPulse then
    begin
      LEnd := AWindows[I].OwnerEndFrame;
    end;
    LRunEnds[I] := LEnd;
  end;
  LFrame := -1;
  LScale := 0;
  for I := 0 to High(AObservations) do
  begin
    RequireFinite(AObservations[I].Weight, 'Clock observation weight');
    if (AObservations[I].Frame <= LFrame) or (AObservations[I].Frame >= ASourceFrames) or
      (AObservations[I].Weight <= 0) or (AObservations[I].Weight > 1) then
    begin
      raise EAudio.Create('Invalid clock observation');
    end;
    LFrame := AObservations[I].Frame;
    LScale := Max(LScale, AObservations[I].Weight);
  end;
  LInRun := False;
  for I := 0 to High(AWindows) do
  begin
    if AWindows[I].StartsNewRun then
    begin
      EndRun;
    end;
    if not AWindows[I].HasPulse then
    begin
      EndRun;
      Continue;
    end;
    LCurrent := Default(TAnchor);
    LCurrent.Frame := (AWindows[I].OwnerStartFrame + AWindows[I].OwnerEndFrame) / 2;
    LCurrent.Window := I;
    LCurrent.Rate := 1 / AWindows[I].PeriodFrames;
    LFraction := (LCurrent.Frame - AWindows[I].PhaseFrame) * LCurrent.Rate;
    LFraction := LFraction - Floor(LFraction);
    if not LInRun then
    begin
      LCurrent.Cycle := LFraction;
      LFirst := LCurrent;
      LFirst.Frame := AWindows[I].OwnerStartFrame;
      LFirst.Cycle := LCurrent.Cycle - (LCurrent.Frame - LFirst.Frame) * LCurrent.Rate;
      AddSegment(LFirst, LCurrent);
      LInRun := True;
    end
    else
    begin
      LExpected := LPrevious.Cycle +
        (LCurrent.Frame - LPrevious.Frame) * (LPrevious.Rate + LCurrent.Rate) / 2;
      LInteger := LExpected - LFraction;
      LCurrent.Ambiguous := Abs((LInteger - Floor(LInteger)) - 0.5) <= 1e-10;
      LCurrent.Cycle := LFraction + Floor(LInteger + 0.5);
      LCurrent.Residual := LCurrent.Cycle - LExpected;
      LHasStep := False;
      LDuration := LCurrent.Frame - LPrevious.Frame;
      LContrast := LPrevious.Rate - LCurrent.Rate;
      if (AOptions.Shape = bcsStepWhenFeasible) and not LCurrent.Ambiguous and not LPrevious.Ambiguous and
        (LCurrent.Cycle > LPrevious.Cycle) and
        (Abs(LContrast) > 64 * 2.2204460492503131e-16 * Max(LPrevious.Rate, LCurrent.Rate)) then
      begin
        LSwitch := (LCurrent.Cycle - LPrevious.Cycle - LCurrent.Rate * LDuration) / LContrast;
        if (LSwitch > 0) and (LSwitch < LDuration) then
        begin
          LStep := LPrevious;
          LStep.Frame := LPrevious.Frame + LSwitch;
          LStep.Cycle := LPrevious.Cycle + LPrevious.Rate * LSwitch;
          LStep.Residual := 0;
          LStep.Ambiguous := False;
          AddSegment(LPrevious, LStep);
          LResult.Segments[High(LResult.Segments)].StepPart := True;
          AddSegment(LStep, LCurrent);
          LResult.Segments[High(LResult.Segments)].StepPart := True;
          Inc(LResult.StepIntervals);
          LHasStep := True;
        end;
      end;
      if not LHasStep then
      begin
        AddSegment(LPrevious, LCurrent);
      end;
    end;
    LPrevious := LCurrent;
  end;
  EndRun;
  { Rejected phase intervals are alignment barriers as well as missing raw
    evidence. Use integer sample positions in [ceil(start), ceil(end)). }
  SetLength(LSpanStarts, Length(LResult.Segments));
  SetLength(LSpanEnds, Length(LResult.Segments));
  LStart := 0;
  for I := 0 to High(LResult.Segments) do
  begin
    if not LResult.Segments[I].Available then
    begin
      LStart := Ceil(LResult.Segments[I].EndFrame);
    end;
    LSpanStarts[I] := LStart;
  end;
  LEnd := ASourceFrames - 1;
  for I := High(LResult.Segments) downto 0 do
  begin
    if not LResult.Segments[I].Available then
    begin
      LEnd := Ceil(LResult.Segments[I].StartFrame) - 1;
    end;
    LSpanEnds[I] := LEnd;
  end;
  { Bound all candidate crossings before filtering to supported owner spans.
    This also bounds repeated allocations and work on sparse observations. }
  for I := 0 to High(LResult.Segments) do
  begin
    if LResult.Segments[I].Available then
    begin
      LCrossings := Ceil(LResult.Segments[I].EndCycle - 1e-12) -
        Ceil(LResult.Segments[I].StartCycle - 1e-12);
      if (LCrossings < 0) or (LCrossings > MaximumBeatFrames - LResult.CrossingWork) then
      begin
        raise EAudio.Create('Clock crossing work exceeds budget');
      end;
      Inc(LResult.CrossingWork, LCrossings);
    end;
  end;
  LCount := 0;
  LCapacity := 0;
  LOwner := 0;
  LTolerance := Ceil(ASampleRate * AOptions.SupportToleranceSeconds);
  for I := 0 to High(LResult.Segments) do
  begin
    LSegment := LResult.Segments[I];
    if not LSegment.Available then
    begin
      Continue;
    end;
    if LSegment.EndCycle - LSegment.StartCycle > MaximumBeatFrames then
    begin
      raise EAudio.Create('Clock interval output exceeds bound');
    end;
    LCycle := Ceil(LSegment.StartCycle - 1e-12);
    while LCycle < LSegment.EndCycle - 1e-12 do
    begin
      LTime := LSegment.StartFrame + (LCycle - LSegment.StartCycle) * LSegment.PeriodFrames;
      LRoundingGuard := 64 * 2.2204460492503131e-16 *
        Max(1.0, Max(Abs(LTime), Max(Abs(LSegment.StartFrame), Abs(LSegment.EndFrame))));
      if Abs(LTime - Floor(LTime) - 0.5) <= LRoundingGuard then
      begin
        LFrame := Floor(LTime) + 1;
      end
      else
      begin
        LFrame := Floor(LTime + 0.5);
      end;
      Inc(LCycle);
      if (LFrame < LRunStarts[LSegment.LeftWindow]) or
        (LFrame >= LRunEnds[LSegment.LeftWindow]) then
      begin
        Continue;
      end;
      while LFrame >= AWindows[LOwner].OwnerEndFrame do
      begin
        Inc(LOwner);
      end;
      if not AWindows[LOwner].HasPulse or
        (LFrame < AWindows[LOwner].FirstObservationFrame - LTolerance) or
        (LFrame > AWindows[LOwner].LastObservationFrame + LTolerance) then
      begin
        Continue;
      end;
      if (LCount > 0) and (LFrame <= LResult.RawFrames[LCount - 1]) then
      begin
        raise EAudio.Create('Clock produced duplicate or reversed frames');
      end;
      if LCount >= MaximumBeatFrames then
      begin
        raise EAudio.Create('Clock output bound exceeded');
      end;
      if LCount = LCapacity then
      begin
        LCapacity := Min(MaximumBeatFrames, Max(64, LCapacity * 2));
        SetLength(LResult.RawFrames, LCapacity);
        SetLength(LResult.FrameWindows, LCapacity);
        SetLength(LResult.Periods, LCapacity);
        SetLength(LPointSegments, LCapacity);
      end;
      LResult.RawFrames[LCount] := LFrame;
      LResult.FrameWindows[LCount] := LOwner;
      LResult.Periods[LCount] := LSegment.PeriodFrames;
      LPointSegments[LCount] := I;
      Inc(LCount);
    end;
  end;
  SetLength(LResult.RawFrames, LCount);
  SetLength(LResult.FrameWindows, LCount);
  SetLength(LResult.Periods, LCount);
  LResult.Frames := Copy(LResult.RawFrames);
  SetLength(LResult.ObservationIndices, LCount);
  if AOptions.AlignmentMode = bcaNeighbourSupported then
  begin
    SetLength(LAlignmentCells, LCount);
  end;
  LFirstObservation := 0;
  for LPoint := 0 to LCount - 1 do
  begin
    LResult.ObservationIndices[LPoint] := -1;
    if AOptions.SnapToleranceSeconds = 0 then
    begin
      Continue;
    end;
    LTolerance := Floor(Min(ASampleRate * AOptions.SnapToleranceSeconds,
      LResult.Periods[LPoint] / 5));
    LOwner := LResult.FrameWindows[LPoint];
    LStart := Max(LRunStarts[LOwner], LResult.RawFrames[LPoint] - LTolerance);
    LEnd := Min(LRunEnds[LOwner] - 1, LResult.RawFrames[LPoint] + LTolerance);
    LStart := Max(LStart, LSpanStarts[LPointSegments[LPoint]]);
    LEnd := Min(LEnd, LSpanEnds[LPointSegments[LPoint]]);
    if LPoint > 0 then
    begin
      LStart := Max(LStart, (LResult.RawFrames[LPoint - 1] + LResult.RawFrames[LPoint]) div 2 + 1);
    end;
    if LPoint < LCount - 1 then
    begin
      LEnd := Min(LEnd, (LResult.RawFrames[LPoint] + LResult.RawFrames[LPoint + 1]) div 2);
    end;
    if AOptions.AlignmentMode = bcaNeighbourSupported then
    begin
      LAlignmentCells[LPoint].RawFrame := LResult.RawFrames[LPoint];
      LAlignmentCells[LPoint].FirstFrame := LStart;
      LAlignmentCells[LPoint].LastFrame := LEnd;
      LAlignmentCells[LPoint].Tolerance := LTolerance;
      LAlignmentCells[LPoint].RunId :=
        Max(LRunStarts[LOwner], LSpanStarts[LPointSegments[LPoint]]);
    end;
    while (LFirstObservation < Length(AObservations)) and
      (AObservations[LFirstObservation].Frame < LStart) do
    begin
      Inc(LFirstObservation);
    end;
    LObservation := LFirstObservation;
    LBest := -1;
    LBestWeight := 0;
    while (LObservation < Length(AObservations)) and (AObservations[LObservation].Frame <= LEnd) do
    begin
      LWeight := AObservations[LObservation].Weight / LScale *
        (1 - Abs(AObservations[LObservation].Frame - LResult.RawFrames[LPoint]) / (LTolerance + 1));
      if LWeight > LBestWeight then
      begin
        LBest := LObservation;
        LBestWeight := LWeight;
      end;
      Inc(LObservation);
    end;
    if LBest >= 0 then
    begin
      LResult.Frames[LPoint] := AObservations[LBest].Frame;
      LResult.ObservationIndices[LPoint] := LBest;
    end;
  end;
  if AOptions.AlignmentMode = bcaNeighbourSupported then
  begin
    LResult.AlignmentChoices := AlignBeatObservationsWithContext(LAlignmentCells,
      AObservations, ASourceFrames);
    for LPoint := 0 to LCount - 1 do
    begin
      LResult.Frames[LPoint] := LResult.AlignmentChoices[LPoint].Frame;
      LResult.ObservationIndices[LPoint] := LResult.AlignmentChoices[LPoint].Observation;
    end;
  end;
  Result := LResult;
end;

end.
