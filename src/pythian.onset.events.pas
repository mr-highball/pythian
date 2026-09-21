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
unit pythian.onset.events;

{$mode delphi}
{$H+}

interface

uses
  pythian.onset,
  pythian.passage;

const
  OnsetEventVersion = 1;

type
  TOnsetEventDecision = (oedUnresolved, oedClippedContext, oedSearchBoundary,
    oedNearEndpoint, oedTooClose, oedDuplicate, oedSelected);
  TOnsetEventDecisions = array of TOnsetEventDecision;
  TOnsetEventOptions = record
    MinimumFrames: Integer;
    AllowClippedContext: Boolean;
    AllowSearchBoundary: Boolean;
  end;
  TOnsetEventPlan = record
    Bounds: TPassageBounds;
    LocationIndices: TPassageIndices;
    Decisions: TOnsetEventDecisions;
  end;

function DefaultOnsetEventOptions(const ASampleRate: Integer): TOnsetEventOptions;
{ Covers the complete source with strictly increasing passage bounds. Interior
  boundaries retain original location indices; synthetic source endpoints use -1.
  Candidates are sorted by frame, then original index. The first eligible point
  at least MinimumFrames from the previous boundary wins. Every input row has an
  explicit decision. No beat grid, source hash or onset accuracy is inferred. }
function PlanOnsetEvents(const ALocations: TOnsetLocations; const ASourceFrames: Integer;
  const AOptions: TOnsetEventOptions): TOnsetEventPlan;
function OnsetEventDecisionName(const ADecision: TOnsetEventDecision): String;

implementation

uses
  Math,
  pythian.audio,
  pythian.analysis;

function DefaultOnsetEventOptions(const ASampleRate: Integer): TOnsetEventOptions;
begin
  ValidateAudioFormat(ASampleRate, 1);
  Result.MinimumFrames := Max(1, ASampleRate div 100);
  Result.AllowClippedContext := False;
  Result.AllowSearchBoundary := False;
end;

function OnsetEventDecisionName(const ADecision: TOnsetEventDecision): String;
const
  CNames: array[TOnsetEventDecision] of String = ('unresolved', 'clipped_context',
    'search_boundary', 'near_endpoint', 'too_close', 'duplicate', 'selected');
begin
  Result := CNames[ADecision];
end;

procedure SortLocations(var AIndices: TPassageIndices; const ALocations: TOnsetLocations);
var
  LScratch: TPassageIndices;
  LWidth: Integer;
  LStart: Integer;
  LMiddle: Integer;
  LEnd: Integer;
  LLeft: Integer;
  LRight: Integer;
  LOutput: Integer;
  LTakeLeft: Boolean;
begin
  SetLength(LScratch, Length(AIndices));
  LWidth := 1;
  while LWidth < Length(AIndices) do
  begin
    LStart := 0;
    while LStart < Length(AIndices) do
    begin
      LMiddle := Min(Length(AIndices), LStart + LWidth);
      LEnd := Min(Length(AIndices), LMiddle + LWidth);
      LLeft := LStart;
      LRight := LMiddle;
      for LOutput := LStart to LEnd - 1 do
      begin
        LTakeLeft := LRight = LEnd;
        if (LLeft < LMiddle) and (LRight < LEnd) then
        begin
          LTakeLeft := ALocations[AIndices[LLeft]].Frame <= ALocations[AIndices[LRight]].Frame;
        end;
        if (LLeft < LMiddle) and LTakeLeft then
        begin
          LScratch[LOutput] := AIndices[LLeft];
          Inc(LLeft);
        end
        else
        begin
          LScratch[LOutput] := AIndices[LRight];
          Inc(LRight);
        end;
      end;
      LStart := LEnd;
    end;
    for LOutput := 0 to High(AIndices) do
    begin
      AIndices[LOutput] := LScratch[LOutput];
    end;
    LWidth := LWidth * 2;
  end;
end;

function PlanOnsetEvents(const ALocations: TOnsetLocations; const ASourceFrames: Integer;
  const AOptions: TOnsetEventOptions): TOnsetEventPlan;
var
  LPlan: TOnsetEventPlan;
  LEligible: TPassageIndices;
  LLocation: TOnsetLocation;
  LIndex: Integer;
  LOriginal: Integer;
  LCount: Integer;
  LSelected: Integer;
  LPrevious: Integer;
  LLastFrame: Integer;
begin
  if (ASourceFrames < 1) or (ASourceFrames > MaximumClipSamples) or
    (Length(ALocations) > MaximumAnalysisFrames) or (AOptions.MinimumFrames < 1) or
    (AOptions.MinimumFrames > MaximumClipSamples) then
  begin
    raise EAudio.Create('Onset event request exceeds source or candidate bounds');
  end;
  LPlan := Default(TOnsetEventPlan);
  SetLength(LPlan.Decisions, Length(ALocations));
  SetLength(LEligible, Length(ALocations));
  LCount := 0;
  for LIndex := 0 to High(ALocations) do
  begin
    LLocation := ALocations[LIndex];
    if (LLocation.WindowStartFrame < 0) or (LLocation.WindowFrameCount < 1) or
      (LLocation.WindowStartFrame > ASourceFrames) or
      (LLocation.WindowFrameCount > ASourceFrames - LLocation.WindowStartFrame) or
      (not LLocation.Resolved and (LLocation.Frame <> -1)) then
    begin
      raise EAudio.Create('Onset event location has an invalid source window or unresolved frame');
    end;
    if not LLocation.Resolved then
    begin
      LPlan.Decisions[LIndex] := oedUnresolved;
      Continue;
    end;
    if (LLocation.Frame < LLocation.WindowStartFrame) or
      (LLocation.Frame >= LLocation.WindowStartFrame + LLocation.WindowFrameCount) then
    begin
      raise EAudio.Create('Resolved onset event is outside its source window');
    end;
    if LLocation.ContextClipped and not AOptions.AllowClippedContext then
    begin
      LPlan.Decisions[LIndex] := oedClippedContext;
    end
    else if LLocation.SearchBoundary and not AOptions.AllowSearchBoundary then
    begin
      LPlan.Decisions[LIndex] := oedSearchBoundary;
    end
    else if (LLocation.Frame < AOptions.MinimumFrames) or
      (LLocation.Frame > ASourceFrames - AOptions.MinimumFrames) then
    begin
      LPlan.Decisions[LIndex] := oedNearEndpoint;
    end
    else
    begin
      LEligible[LCount] := LIndex;
      Inc(LCount);
    end;
  end;
  SetLength(LEligible, LCount);
  SortLocations(LEligible, ALocations);
  SetLength(LPlan.Bounds, Min(MaximumPassages + 1, LCount + 2));
  SetLength(LPlan.LocationIndices, Length(LPlan.Bounds));
  LPlan.Bounds[0] := 0;
  LPlan.LocationIndices[0] := -1;
  LSelected := 0;
  LPrevious := -1;
  for LIndex := 0 to High(LEligible) do
  begin
    LOriginal := LEligible[LIndex];
    LLastFrame := ALocations[LOriginal].Frame;
    if LLastFrame = LPrevious then
    begin
      LPlan.Decisions[LOriginal] := oedDuplicate;
    end
    else if LLastFrame - LPlan.Bounds[LSelected] < AOptions.MinimumFrames then
    begin
      LPlan.Decisions[LOriginal] := oedTooClose;
    end
    else
    begin
      if LSelected >= MaximumPassages - 1 then
      begin
        raise EAudio.Create('Selected onset events exceed the passage budget');
      end;
      Inc(LSelected);
      LPlan.Bounds[LSelected] := LLastFrame;
      LPlan.LocationIndices[LSelected] := LOriginal;
      LPlan.Decisions[LOriginal] := oedSelected;
    end;
    LPrevious := LLastFrame;
  end;
  SetLength(LPlan.Bounds, LSelected + 2);
  SetLength(LPlan.LocationIndices, LSelected + 2);
  LPlan.Bounds[LSelected + 1] := ASourceFrames;
  LPlan.LocationIndices[LSelected + 1] := -1;
  Result := LPlan;
end;

end.
