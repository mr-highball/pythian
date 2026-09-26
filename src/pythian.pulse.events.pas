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
unit pythian.pulse.events;

{$mode delphi}
{$H+}

interface

uses
  pythian.beat,
  pythian.beat.track,
  pythian.passage;

const
  PulseEventVersion = 1;

type
  TPulseEventDecision = (pedSelected, pedPathBreak, pedUncertainJoin,
    pedDuration, pedUnaligned);
  TPulseEventDecisions = array of TPulseEventDecision;
  TPulseEventOptions = record
    MinimumPeriodRatio: Double;
    MaximumPeriodRatio: Double;
    RequireAlignedEndpoints: Boolean;
  end;
  TPulseEventPlan = record
    Bounds: TPassageBounds;
    Decisions: TPulseEventDecisions;
    RunIndices: TPassageIndices;
    RunCount: Integer;
    SelectedCount: Integer;
  end;

function DefaultPulseEventOptions: TPulseEventOptions;
function PulseEventDecisionName(const ADecision: TPulseEventDecision): String;

{ Each adjacent pair of final pulse positions is one candidate interval.
  Bounds retain every point, including excluded intervals; no prefix or suffix
  is invented. RunIndices is -1 for exclusion, otherwise a dense chronological
  training-sample index. Raw path breaks and uncertain joins take precedence,
  then final interval/mean-period ratio, then optional source-onset alignment.
  Passing this policy does not prove beat accuracy. Inputs are borrowed; the
  returned plan owns detached arrays and is published only after validation. }
function PlanPulseEvents(const ATrack: TBeatTrack; const AObservations: TBeatObservations;
  const ASourceFrames: Integer; const AOptions: TPulseEventOptions): TPulseEventPlan;

implementation

uses
  Math,
  pythian.audio;

function DefaultPulseEventOptions: TPulseEventOptions;
begin
  Result.MinimumPeriodRatio := 0.5;
  Result.MaximumPeriodRatio := 1.5;
  Result.RequireAlignedEndpoints := True;
end;

function PulseEventDecisionName(const ADecision: TPulseEventDecision): String;
const
  CNames: array[TPulseEventDecision] of String = ('selected', 'path_break',
    'uncertain_join', 'duration_ratio', 'unaligned_endpoint');
begin
  Result := CNames[ADecision];
end;

function PlanPulseEvents(const ATrack: TBeatTrack; const AObservations: TBeatObservations;
  const ASourceFrames: Integer; const AOptions: TPulseEventOptions): TPulseEventPlan;
var
  LPlan: TPulseEventPlan;
  LIndex: Integer;
  LWindow: Integer;
  LChoice: Integer;
  LPreviousWindow: Integer;
  LPreviousObservation: Integer;
  LObservation: Integer;
  LCount: Integer;
  LRatio: Double;
  LPeriods: array of Double;
  LBreaks: array of Integer;
  LUncertain: array of Integer;
begin
  RequireFinite(AOptions.MinimumPeriodRatio, 'Minimum pulse interval ratio');
  RequireFinite(AOptions.MaximumPeriodRatio, 'Maximum pulse interval ratio');
  if (AOptions.MinimumPeriodRatio < 0.25) or (AOptions.MinimumPeriodRatio > 1) or
    (AOptions.MaximumPeriodRatio < 1) or (AOptions.MaximumPeriodRatio > 2) or
    (ASourceFrames < 1) or (ASourceFrames > MaximumClipSamples) then
  begin
    raise EAudio.Create('Pulse event source or interval ratio exceeds bounds');
  end;
  LCount := Length(ATrack.Frames);
  if (LCount > MaximumPassages + 1) or
    (Length(ATrack.GridFrames) <> LCount) or
    (Length(ATrack.ObservationIndices) <> LCount) or
    (Length(ATrack.FrameWindows) <> LCount) or
    (Length(ATrack.Windows) < 1) or
    (Length(ATrack.Windows) > MaximumBeatTrackWindows) or
    (Length(AObservations) > MaximumBeatObservations) then
  begin
    raise EAudio.Create('Pulse event track shape exceeds bounds');
  end;
  for LIndex := 0 to High(AObservations) do
  begin
    RequireFinite(AObservations[LIndex].Weight, 'Pulse observation weight');
    if (AObservations[LIndex].Frame < 0) or
      (AObservations[LIndex].Frame >= ASourceFrames) or
      (AObservations[LIndex].Weight <= 0) or (AObservations[LIndex].Weight > 1) then
    begin
      raise EAudio.Create('Pulse observation outside source or weight bounds');
    end;
    if (LIndex > 0) and
      (AObservations[LIndex].Frame <= AObservations[LIndex - 1].Frame) then
    begin
      raise EAudio.Create('Pulse observations must increase strictly');
    end;
  end;
  SetLength(LPeriods, Length(ATrack.Windows));
  SetLength(LBreaks, Length(ATrack.Windows) + 1);
  SetLength(LUncertain, Length(ATrack.Windows) + 1);
  for LWindow := 0 to High(ATrack.Windows) do
  begin
    if (ATrack.Windows[LWindow].OwnerStartFrame < 0) or
      (ATrack.Windows[LWindow].OwnerEndFrame > ASourceFrames) or
      (ATrack.Windows[LWindow].OwnerEndFrame <= ATrack.Windows[LWindow].OwnerStartFrame) then
    begin
      raise EAudio.Create('Pulse window ownership outside source');
    end;
    if LWindow = 0 then
    begin
      if ATrack.Windows[LWindow].OwnerStartFrame <> 0 then
      begin
        raise EAudio.Create('Pulse ownership must start at source zero');
      end;
    end
    else if ATrack.Windows[LWindow].OwnerStartFrame <>
      ATrack.Windows[LWindow - 1].OwnerEndFrame then
    begin
      raise EAudio.Create('Pulse ownership must be contiguous');
    end;
    LChoice := ATrack.Windows[LWindow].SelectedCandidate;
    if (LChoice < -1) or (LChoice >= Length(ATrack.Windows[LWindow].Analysis.Candidates)) or
      (Length(ATrack.Windows[LWindow].Analysis.Candidates) > 32) then
    begin
      raise EAudio.Create('Pulse selected candidate is outside its window');
    end;
    if LChoice >= 0 then
    begin
      LPeriods[LWindow] := ATrack.Windows[LWindow].Analysis.Candidates[LChoice].PeriodFrames;
      RequireFinite(LPeriods[LWindow], 'Pulse period');
      if (LPeriods[LWindow] < 2) or (LPeriods[LWindow] > MaximumClipSamples) then
      begin
        raise EAudio.Create('Pulse period outside bounds');
      end;
    end;
    LBreaks[LWindow + 1] := LBreaks[LWindow] +
      Ord((LChoice < 0) or ATrack.Windows[LWindow].StartsNewPath);
    LUncertain[LWindow + 1] := LUncertain[LWindow] +
      Ord(ATrack.Windows[LWindow].JoinUncertain);
  end;
  if ATrack.Windows[High(ATrack.Windows)].OwnerEndFrame <> ASourceFrames then
  begin
    raise EAudio.Create('Pulse ownership must cover the source');
  end;
  LPreviousWindow := -1;
  LPreviousObservation := -1;
  for LIndex := 0 to LCount - 1 do
  begin
    LWindow := ATrack.FrameWindows[LIndex];
    if (LWindow < 0) or (LWindow >= Length(ATrack.Windows)) or
      (LWindow < LPreviousWindow) then
    begin
      raise EAudio.Create('Pulse point window identity is invalid');
    end;
    if (LPeriods[LWindow] = 0) or
      (ATrack.GridFrames[LIndex] < ATrack.Windows[LWindow].OwnerStartFrame) or
      (ATrack.GridFrames[LIndex] >= ATrack.Windows[LWindow].OwnerEndFrame) or
      (ATrack.Frames[LIndex] < 0) or (ATrack.Frames[LIndex] >= ASourceFrames) then
    begin
      raise EAudio.Create('Pulse point violates raw ownership or final source bounds');
    end;
    if (LIndex > 0) and
      ((ATrack.Frames[LIndex] <= ATrack.Frames[LIndex - 1]) or
       (ATrack.GridFrames[LIndex] <= ATrack.GridFrames[LIndex - 1])) then
    begin
      raise EAudio.Create('Raw and aligned pulse points must increase strictly');
    end;
    LObservation := ATrack.ObservationIndices[LIndex];
    if (LObservation < -1) or (LObservation >= Length(AObservations)) then
    begin
      raise EAudio.Create('Pulse observation index is invalid');
    end;
    if LObservation >= 0 then
    begin
      if (LObservation <= LPreviousObservation) or
        (ATrack.Frames[LIndex] <> AObservations[LObservation].Frame) then
      begin
        raise EAudio.Create('Aligned pulse must identify a unique source observation');
      end;
      LPreviousObservation := LObservation;
    end
    else if ATrack.Frames[LIndex] <> ATrack.GridFrames[LIndex] then
    begin
      raise EAudio.Create('Unaligned pulse must retain its raw grid position');
    end;
    LPreviousWindow := LWindow;
  end;
  LPlan.Bounds := Copy(ATrack.Frames, 0, LCount);
  SetLength(LPlan.Decisions, Max(0, LCount - 1));
  SetLength(LPlan.RunIndices, Length(LPlan.Decisions));
  LPlan.RunCount := 0;
  LPlan.SelectedCount := 0;
  for LIndex := 0 to High(LPlan.Decisions) do
  begin
    LPreviousWindow := ATrack.FrameWindows[LIndex];
    LWindow := ATrack.FrameWindows[LIndex + 1];
    LRatio := (ATrack.Frames[LIndex + 1] - ATrack.Frames[LIndex]) /
      ((LPeriods[LPreviousWindow] + LPeriods[LWindow]) / 2);
    LPlan.Decisions[LIndex] := pedSelected;
    if LBreaks[LWindow + 1] <> LBreaks[LPreviousWindow + 1] then
    begin
      LPlan.Decisions[LIndex] := pedPathBreak;
    end
    else if LUncertain[LWindow + 1] <> LUncertain[LPreviousWindow + 1] then
    begin
      LPlan.Decisions[LIndex] := pedUncertainJoin;
    end
    else if (LRatio < AOptions.MinimumPeriodRatio) or
      (LRatio > AOptions.MaximumPeriodRatio) then
    begin
      LPlan.Decisions[LIndex] := pedDuration;
    end
    else if AOptions.RequireAlignedEndpoints and
      ((ATrack.ObservationIndices[LIndex] < 0) or (ATrack.ObservationIndices[LIndex + 1] < 0)) then
    begin
      LPlan.Decisions[LIndex] := pedUnaligned;
    end;
    LPlan.RunIndices[LIndex] := -1;
    if LPlan.Decisions[LIndex] = pedSelected then
    begin
      if (LIndex = 0) or (LPlan.Decisions[LIndex - 1] <> pedSelected) then
      begin
        Inc(LPlan.RunCount);
      end;
      LPlan.RunIndices[LIndex] := LPlan.RunCount - 1;
      Inc(LPlan.SelectedCount);
    end;
  end;
  Result := LPlan;
end;

end.
