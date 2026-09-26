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
unit pythian.beat.alignment;

{$mode delphi}
{$H+}

interface

uses
  pythian.beat;

const
  BeatAlignmentContextPolicy = 'two-neighbour-offset-envelope';
  MaximumBeatAlignmentCandidates = 64;
  MaximumBeatAlignmentVisits = 262144;

type
  TBeatAlignmentCell = record
    RawFrame: Integer;
    FirstFrame: Integer;
    LastFrame: Integer;
    Tolerance: Integer;
    RunId: Integer;
  end;
  TBeatAlignmentCells = array of TBeatAlignmentCell;
  TBeatAlignmentChoice = record
    Frame: Integer;
    Observation: Integer;
    OriginalObservation: Integer;
    WitnessCount: Integer;
    MinimumOffset: Integer;
    MaximumOffset: Integer;
    Unknown: Boolean;
    ContextUnavailable: Boolean;
  end;
  TBeatAlignmentChoices = array of TBeatAlignmentChoice;

{ Sample-frame cells are ordered, disjoint, source-bounded and contain their raw
  positions. Candidate bounds must stay within Tolerance of RawFrame. RunId is a
  nonnegative, nondecreasing caller-owned continuity identifier; witnesses never
  cross it. Observations are strictly ordered, finite and positively weighted.

  Up to two original observed alignments on either side constrain an onset's
  offset, with zero included and one sample of rounding allowance. At least two
  witnesses are required. Unknown retains RawFrame and Observation=-1; missing
  context retains the original choice with ContextUnavailable=True. Neither
  flag establishes a musical beat or confidence. Genuine isolated timing and a
  distractor can be indistinguishable. The policy is deliberately fixed.

  Inputs are borrowed; output is detached. MaximumBeatFrames cells and
  MaximumBeatObservations observations are supported, subject to the candidate
  bounds above. Invalid calls preserve the caller's previously assigned result. }
function AlignBeatObservationsWithContext(const ACells: TBeatAlignmentCells;
  const AObservations: TBeatObservations; const ASourceFrames: Integer): TBeatAlignmentChoices;
implementation

uses
  Math,
  pythian.audio;

type
  TIndices = array of Integer;
  TCandidateLists = array of TIndices;

function AlignBeatObservationsWithContext(const ACells: TBeatAlignmentCells;
  const AObservations: TBeatObservations; const ASourceFrames: Integer): TBeatAlignmentChoices;
var
  LChoices: TBeatAlignmentChoices;
  LCandidates: TCandidateLists;
  LFirst: Integer;
  LPoint: Integer;
  LOffset: Integer;
  LIndex: Integer;
  LVisits: Integer;
  LScore: Double;
  LScale: Double;
  LBest: Double;
  I: Integer;
  J: Integer;
begin
  if (ASourceFrames < 1) or (ASourceFrames > MaximumClipSamples) or
    (Length(ACells) > MaximumBeatFrames) or (Length(AObservations) > MaximumBeatObservations) then
  begin
    raise EAudio.Create('Alignment work bounds');
  end;
  LScale := 0;
  for I := 0 to High(AObservations) do
  begin
    RequireFinite(AObservations[I].Weight, 'Alignment weight');
    if (AObservations[I].Frame < 0) or (AObservations[I].Frame >= ASourceFrames) or
      (AObservations[I].Weight <= 0) or
      (AObservations[I].Weight > 1) then
    begin
      raise EAudio.Create('Invalid alignment observation');
    end;
    LScale := Max(LScale, AObservations[I].Weight);
    if (I > 0) and (AObservations[I].Frame <= AObservations[I - 1].Frame) then
    begin
      raise EAudio.Create('Unordered observations');
    end;
  end;
  LChoices := nil;
  SetLength(LChoices, Length(ACells));
  SetLength(LCandidates, Length(ACells));
  LFirst := 0;
  LVisits := 0;
  for I := 0 to High(ACells) do
  begin
    if (ACells[I].Tolerance < 0) or (ACells[I].Tolerance > MaximumClipSamples) or
      (ACells[I].FirstFrame < 0) or (ACells[I].LastFrame >= ASourceFrames) or
      (Int64(ACells[I].RawFrame) - ACells[I].FirstFrame > ACells[I].Tolerance) or
      (Int64(ACells[I].LastFrame) - ACells[I].RawFrame > ACells[I].Tolerance) or
      (ACells[I].FirstFrame > ACells[I].RawFrame) or
      (ACells[I].LastFrame < ACells[I].RawFrame) or (ACells[I].RunId < 0) then
    begin
      raise EAudio.Create('Invalid alignment cell');
    end;
    if (I > 0) and ((ACells[I].RawFrame <= ACells[I - 1].RawFrame) or
      (ACells[I].FirstFrame <= ACells[I - 1].LastFrame) or
      (ACells[I].RunId < ACells[I - 1].RunId)) then
    begin
      raise EAudio.Create('Unordered or overlapping alignment cells');
    end;
    LChoices[I].Frame := ACells[I].RawFrame;
    LChoices[I].Observation := -1;
    LChoices[I].OriginalObservation := -1;
    while (LFirst < Length(AObservations)) and
      (AObservations[LFirst].Frame < ACells[I].FirstFrame) do
    begin
      Inc(LFirst);
    end;
    LPoint := LFirst;
    LBest := 0;
    while (LPoint < Length(AObservations)) and
      (AObservations[LPoint].Frame <= ACells[I].LastFrame) do
    begin
      Inc(LVisits);
      if (LVisits > MaximumBeatAlignmentVisits) or
        (Length(LCandidates[I]) >= MaximumBeatAlignmentCandidates) then
      begin
        raise EAudio.Create('Eligible alignment candidate budget');
      end;
      SetLength(LCandidates[I], Length(LCandidates[I]) + 1);
      LCandidates[I][High(LCandidates[I])] := LPoint;
      LScore := AObservations[LPoint].Weight / LScale * (1 -
        Abs(AObservations[LPoint].Frame - ACells[I].RawFrame) / (ACells[I].Tolerance + 1));
      if LScore > LBest then
      begin
        LBest := LScore;
        LChoices[I].OriginalObservation := LPoint;
      end;
      Inc(LPoint);
    end;
  end;
  for I := 0 to High(ACells) do
  begin
    for J := Max(0, I - 2) to Min(High(ACells), I + 2) do
    begin
      LPoint := LChoices[J].OriginalObservation;
      if (I = J) or (ACells[J].RunId <> ACells[I].RunId) or (LPoint < 0) then
      begin
        Continue;
      end;
      Inc(LChoices[I].WitnessCount);
      LOffset := AObservations[LPoint].Frame - ACells[J].RawFrame;
      LChoices[I].MinimumOffset := Min(LChoices[I].MinimumOffset, LOffset);
      LChoices[I].MaximumOffset := Max(LChoices[I].MaximumOffset, LOffset);
    end;
    if LChoices[I].WitnessCount < 2 then
    begin
      LChoices[I].ContextUnavailable := True;
      LChoices[I].Observation := LChoices[I].OriginalObservation;
    end
    else
    begin
      LBest := 0;
      for J := 0 to High(LCandidates[I]) do
      begin
        LPoint := LCandidates[I][J];
        LOffset := AObservations[LPoint].Frame - ACells[I].RawFrame;
        if (LOffset < LChoices[I].MinimumOffset - 1) or
          (LOffset > LChoices[I].MaximumOffset + 1) then
        begin
          Continue;
        end;
        LScore := AObservations[LPoint].Weight / LScale * (1 - Abs(LOffset) / (ACells[I].Tolerance + 1));
        if LScore > LBest then
        begin
          LBest := LScore;
          LChoices[I].Observation := LPoint;
        end;
      end;
    end;
    LIndex := LChoices[I].Observation;
    if LIndex >= 0 then
    begin
      LChoices[I].Frame := AObservations[LIndex].Frame;
    end
    else
    begin
      LChoices[I].Unknown := True;
    end;
  end;
  Result := LChoices;
end;

end.
