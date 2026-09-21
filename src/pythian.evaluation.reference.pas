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
unit pythian.evaluation.reference;

{$mode delphi}
{$H+}

interface

uses
  pythian.evaluation, pythian.evaluation.notes, pythian.evaluation.parts;

const
  MaximumReferenceCenterWork = 50000000;
  MaximumReferenceRegionWork = 16777216;

type
  TPartNoteReference = record
    Events: TEvaluationNotes;
    Regions: TEvaluationNoteRegions;
  end;
  TPartNoteReferences = array of TPartNoteReference;

{ Expands caller-reviewed interval truth to a complete regular center grid.
  Does not infer acoustic notes, roles, crossings or reference independence.
  Regions partition [first,end). esValue asserts complete events, including
  known gaps; those gaps become esRest cells. Explicit uncertainty is preserved.
  Events overlapping uncertainty remain visible at known centers; the separate
  timing scorer retains its whole-event exclusion rule. Half-open events and
  repeated same-pitch events form a sorted set at each center without modifying
  their original IDs/multiplicity. Unassigned events supply known pitch only.
  All IDs are unique across roles AND unassigned events, and all intervals stay
  inside source frames. First center must be in the first hop of the scope.
  Inputs and any previously assigned result remain unchanged on rejection. }
function BuildPartReferenceCells(const ARoleIds: TPartRoleIds;
  const AReferences: TPartNoteReferences; const AUnassigned: TEvaluationNotes;
  const ASourceFrames, AFirstFrame, AEndFrame, AFirstCenter, AHopFrames: Int64):
  TPartEvaluationCells;

implementation

uses
  SysUtils, pythian.audio;

procedure Require(const AValue: Boolean; const AMessage: String);
begin
  if not AValue then
  begin
    raise EAudio.Create(AMessage);
  end;
end;

function PitchUnion(const ANotes: TEvaluationNotes; const AFrame: Int64): TPartPitchSet;
var
  LPresent: array[0..127] of Boolean;
  LCount: Integer;
  I: Integer;
begin
  FillChar(LPresent, SizeOf(LPresent), 0);
  for I := 0 to High(ANotes) do
  begin
    if (ANotes[I].StartFrame <= AFrame) and (AFrame < ANotes[I].EndFrame) then
    begin
      LPresent[ANotes[I].Pitch] := True;
    end;
  end;
  LCount := 0;
  for I := 0 to 127 do
  begin
    if LPresent[I] then
    begin
      Inc(LCount);
    end;
  end;
  Result := nil;
  SetLength(Result, LCount);
  LCount := 0;
  for I := 0 to 127 do
  begin
    if LPresent[I] then
    begin
      Result[LCount] := I;
      Inc(LCount);
    end;
  end;
end;

function BuildPartReferenceCells(const ARoleIds: TPartRoleIds;
  const AReferences: TPartNoteReferences; const AUnassigned: TEvaluationNotes;
  const ASourceFrames, AFirstFrame, AEndFrame, AFirstCenter, AHopFrames: Int64):
  TPartEvaluationCells;
var
  LAll: TEvaluationNotes;
  LUnknown: TEvaluationNoteRegions;
  LOptions: TOverlappingNoteOptions;
  LValidation: TOverlappingNoteEvaluation;
  LCells: TPartEvaluationCells;
  LRegionIndices: array of Integer;
  LCount: Int64;
  LNoteCount: Int64;
  LRegionWork: Int64;
  LEntries: Int64;
  LFrame: Int64;
  LState: TEvaluationState;
  LPosition: Integer;
  I: Integer;
  J: Integer;

  procedure AddEvents(const AEvents: TEvaluationNotes);
  var
    K: Integer;
  begin
    for K := 0 to High(AEvents) do
    begin
      Require(AEvents[K].EndFrame <= ASourceFrames, 'Reference event exceeds source');
      LAll[LPosition] := AEvents[K];
      Inc(LPosition);
    end;
  end;

begin
  Require((ASourceFrames > 0) and (ASourceFrames <= MaximumEvaluationFrame) and
    (AFirstFrame >= 0) and (AEndFrame > AFirstFrame) and (AEndFrame <= ASourceFrames) and
    (AEndFrame - AFirstFrame <= MaximumNoteScopeFrames), 'Invalid reference scope');
  Require((AHopFrames > 0) and (AHopFrames <= MaximumNoteScopeFrames) and
    (AFirstCenter >= AFirstFrame) and (AFirstCenter < AEndFrame) and
    (AFirstCenter - AFirstFrame < AHopFrames), 'Invalid complete reference grid');
  Require((Length(ARoleIds) > 0) and (Length(ARoleIds) <= MaximumPartRoles) and
    (Length(AReferences) = Length(ARoleIds)), 'Invalid reference role count');
  LCount := 1 + (AEndFrame - 1 - AFirstCenter) div AHopFrames;
  Require((LCount <= MaximumPartEvaluationCells) and
    (LCount * Length(ARoleIds) <= MaximumEvaluationItems), 'Reference grid exceeds budget');
  LNoteCount := Length(AUnassigned);
  LRegionWork := 0;
  for I := 0 to High(ARoleIds) do
  begin
    Require((Length(ARoleIds[I]) > 0) and (Length(ARoleIds[I]) <= 256) and
      (Trim(ARoleIds[I]) = ARoleIds[I]) and (Pos(#0, ARoleIds[I]) = 0),
      'Invalid reference role ID');
    for J := 0 to I - 1 do
    begin
      Require(ARoleIds[I] <> ARoleIds[J], 'Duplicate reference role ID');
    end;
    Inc(LNoteCount, Length(AReferences[I].Events));
    Require(LNoteCount <= MaximumOverlappingNotes, 'Combined reference events exceed budget');
    Require((Length(AReferences[I].Regions) > 0) and
      (Length(AReferences[I].Regions) <= MaximumNoteRegions), 'Reference region count');
    Inc(LRegionWork, Int64(Length(AReferences[I].Events)) * Length(AReferences[I].Regions));
  end;
  Require((LNoteCount <= MaximumOverlappingNotes) and
    (LRegionWork + LNoteCount <= MaximumReferenceRegionWork), 'Reference region work bound');
  Require(LCount * LNoteCount <= MaximumReferenceCenterWork, 'Reference center work bound');

  SetLength(LAll, LNoteCount);
  LPosition := 0;
  AddEvents(AUnassigned);
  for I := 0 to High(AReferences) do
  begin
    AddEvents(AReferences[I].Events);
  end;
  LOptions := Default(TOverlappingNoteOptions);
  LOptions.OffsetFractionDenominator := 1;
  SetLength(LUnknown, 1);
  LUnknown[0].FirstFrame := AFirstFrame;
  LUnknown[0].EndFrame := AEndFrame;
  LUnknown[0].State := esUnknown;
  { Reuse authoritative ID/interval/region validation with no predictions and
    zero permitted matching work. These results do not constitute a score claim. }
  LValidation := EvaluateOverlappingNotes(LAll, nil, LUnknown,
    AFirstFrame, AEndFrame, LOptions, 0);
  Require(LValidation.MatchingWork = 0, 'Unexpected reference-validation matching');
  for I := 0 to High(AReferences) do
  begin
    LValidation := EvaluateOverlappingNotes(AReferences[I].Events, nil,
      AReferences[I].Regions, AFirstFrame, AEndFrame, LOptions, 0);
    Require(LValidation.MatchingWork = 0, 'Unexpected role-validation matching');
  end;

  LCells := nil;
  SetLength(LCells, LCount);
  SetLength(LRegionIndices, Length(ARoleIds));
  LEntries := 0;
  for I := 0 to High(LCells) do
  begin
    LFrame := AFirstCenter + Int64(I) * AHopFrames;
    LCells[I].Frame := LFrame;
    LCells[I].UnassignedNotes := PitchUnion(AUnassigned, LFrame);
    Inc(LEntries, Length(LCells[I].UnassignedNotes));
    SetLength(LCells[I].Parts, Length(ARoleIds));
    for J := 0 to High(ARoleIds) do
    begin
      while AReferences[J].Regions[LRegionIndices[J]].EndFrame <= LFrame do
      begin
        Inc(LRegionIndices[J]);
      end;
      LState := AReferences[J].Regions[LRegionIndices[J]].State;
      if LState = esValue then
      begin
        LCells[I].Parts[J].Notes := PitchUnion(AReferences[J].Events, LFrame);
        if Length(LCells[I].Parts[J].Notes) = 0 then
        begin
          LState := esRest;
        end;
      end;
      LCells[I].Parts[J].State := LState;
      Inc(LEntries, Length(LCells[I].Parts[J].Notes));
      { Leave room for an equally dense counterpart in the two-sided scorer. }
      Require(LEntries <= MaximumPartNoteEntries div 2, 'Reference pitch-entry budget');
    end;
  end;
  Result := LCells;
end;

end.
