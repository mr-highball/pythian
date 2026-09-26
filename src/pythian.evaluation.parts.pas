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
unit pythian.evaluation.parts;

{$mode delphi}
{$H+}

interface

uses
  pythian.evaluation;

const
  MaximumPartRoles = 32;
  MaximumPartEvaluationCells = 262144;
  MaximumPartNoteEntries = 4194304;
  MaximumPartCrossings = 4096;

type
  TPartRoleIds = array of UTF8String;
  TPartPitchSet = array of Integer;
  TPartObservation = record
    State: TEvaluationState;
    Notes: TPartPitchSet;
  end;
  TPartObservations = array of TPartObservation;
  TPartEvaluationCell = record
    Frame: Int64;
    Parts: TPartObservations;
    { Known pitch, unspecified owner. This never earns per-role credit. }
    UnassignedNotes: TPartPitchSet;
  end;
  TPartEvaluationCells = array of TPartEvaluationCell;
  TPartCrossing = record
    FirstRole: Integer;
    SecondRole: Integer;
    BeforeFrame: Int64;
    AfterFrame: Int64;
  end;
  TPartCrossings = array of TPartCrossing;
  TPartStateCounts = array[TEvaluationState] of Int64;
  TPartRoleEvaluation = record
    RoleId: UTF8String;
    ReferenceStates: TPartStateCounts;
    PredictionStates: TPartStateCounts;
    ReferenceNotes: Int64;
    PredictedScorableNotes: Int64;
    CorrectNotes: Int64;
    MissedNotes: Int64;
    ExtraNotes: Int64;
    FalseNotesInRest: Int64;
    AdmittedUnscorable: Int64;
    UniqueOwnerMatches: Int64;
    UncertainOwnerMatches: Int64;
    WrongOwnerNotes: Int64;
    AmbiguousWrongOwnerNotes: Int64;
    UnresolvedExtraNotes: Int64;
    NovelPitchNotes: Int64;
    Coverage: Double;
    Precision: Double;
    ReferenceCoverage: Double;
  end;
  TPartRoleEvaluations = array of TPartRoleEvaluation;
  TPartLeakageMatrix = array of array of Int64;
  TPartEvaluation = record
    CellCount: Integer;
    Roles: TPartRoleEvaluations;
    { Rows: uniquely annotated source role; columns: incorrectly predicted role. }
    Leakage: TPartLeakageMatrix;
    ReferenceUnassignedNotes: Int64;
    PredictionUnassignedNotes: Int64;
    UnassignedPitchMatches: Int64;
    UnassignedExtraPitches: Int64;
    UnassignedUnscorable: Int64;
    CrossingSpans: Integer;
    CrossingEndpointsCorrect: Integer;
    CrossingEndpointsWrong: Integer;
    CrossingEndpointsUnavailable: Integer;
  end;

{ Stable caller-declared role IDs, not roles inferred from frequency or channels.
  Both arrays retain the complete, identical center grid in [first,end). Pitch
  sets are strictly increasing MIDI 0..127. esValue requires a nonempty set;
  all other states require an empty set. Unassigned notes preserve pitch without
  asserting ownership; uncertain reference roles remain explicitly unscorable.
  Scores count pitch/center pairs, not duration. Reference unisons can agree with
  predicted role labels but do not establish a unique acoustic owner.
  Crossings are caller-annotated pairs of sampled endpoints, not inferred events
  or proof of continuous identity between endpoints. Inputs remain unchanged. }
function EvaluatePartCells(const ARoleIds: TPartRoleIds;
  const AReference, APrediction: TPartEvaluationCells;
  const ACrossings: TPartCrossings; const AFirstFrame, AEndFrame: Int64): TPartEvaluation;

implementation

uses
  SysUtils, pythian.audio;

type
  TNoteOwners = array[0..127] of Integer;
  TNoteFlags = array[0..127] of Boolean;

procedure Require(const ACondition: Boolean; const AMessage: String);
begin
  if not ACondition then
  begin
    raise EAudio.Create(AMessage);
  end;
end;

procedure ValidateSet(const ASet: TPartPitchSet; var AEntries: Int64);
var
  I: Integer;
begin
  Require(Length(ASet) <= 128, 'Part pitch set exceeds MIDI range');
  Inc(AEntries, Length(ASet));
  Require(AEntries <= MaximumPartNoteEntries, 'Part evaluation note-entry budget exceeded');
  for I := 0 to High(ASet) do
  begin
    Require((ASet[I] >= 0) and (ASet[I] <= 127), 'Part pitch must be MIDI 0..127');
    if I > 0 then
    begin
      Require(ASet[I] > ASet[I - 1], 'Part pitch sets must be sorted and unique');
    end;
  end;
end;

procedure ValidateCells(const ACells: TPartEvaluationCells; const ARoleCount: Integer;
  const AFirstFrame, AEndFrame: Int64; var AEntries: Int64);
var
  I: Integer;
  J: Integer;
begin
  for I := 0 to High(ACells) do
  begin
    Require((ACells[I].Frame >= AFirstFrame) and (ACells[I].Frame < AEndFrame),
      'Part center outside declared scope');
    if I > 0 then
    begin
      Require(ACells[I].Frame > ACells[I - 1].Frame, 'Part centers must increase');
    end;
    Require(Length(ACells[I].Parts) = ARoleCount, 'Every center must retain every role');
    ValidateSet(ACells[I].UnassignedNotes, AEntries);
    for J := 0 to ARoleCount - 1 do
    begin
      Require(ACells[I].Parts[J].State in
        [esValue, esRest, esUnknown, esAmbiguous, esUnsupported], 'Invalid part state');
      ValidateSet(ACells[I].Parts[J].Notes, AEntries);
      Require((ACells[I].Parts[J].State = esValue) =
        (Length(ACells[I].Parts[J].Notes) > 0), 'Part state and pitch set disagree');
    end;
  end;
end;

function FindCell(const ACells: TPartEvaluationCells; const AFrame: Int64): Integer;
var
  LFirst: Integer;
  LEnd: Integer;
  LMiddle: Integer;
begin
  LFirst := 0;
  LEnd := Length(ACells);
  while LFirst < LEnd do
  begin
    LMiddle := LFirst + (LEnd - LFirst) div 2;
    if ACells[LMiddle].Frame < AFrame then
    begin
      LFirst := LMiddle + 1;
    end
    else
    begin
      LEnd := LMiddle;
    end;
  end;
  Require((LFirst < Length(ACells)) and (ACells[LFirst].Frame = AFrame),
    'Crossing endpoint is not a declared center');
  Result := LFirst;
end;

function ComparePitchOrder(const ACell: TPartEvaluationCell;
  const AFirstRole, ASecondRole: Integer): Integer;
begin
  Require((ACell.Parts[AFirstRole].State = esValue) and
    (ACell.Parts[ASecondRole].State = esValue) and
    (Length(ACell.Parts[AFirstRole].Notes) = 1) and
    (Length(ACell.Parts[ASecondRole].Notes) = 1),
    'Crossing references require two known monophonic endpoints');
  Result := ACell.Parts[AFirstRole].Notes[0] - ACell.Parts[ASecondRole].Notes[0];
end;

procedure EvaluateCrossings(const AReference, APrediction: TPartEvaluationCells;
  const ACrossings: TPartCrossings; const ARoleCount: Integer;
  var AResult: TPartEvaluation);
var
  LBefore: Integer;
  LAfter: Integer;
  LOrderBefore: Integer;
  LOrderAfter: Integer;
  LCell: Integer;
  LRole: Integer;
  LKnown: Boolean;
  LCorrect: Boolean;
  I: Integer;
  J: Integer;
  K: Integer;
begin
  AResult.CrossingSpans := Length(ACrossings);
  for I := 0 to High(ACrossings) do
  begin
    Require((ACrossings[I].FirstRole >= 0) and
      (ACrossings[I].SecondRole > ACrossings[I].FirstRole) and
      (ACrossings[I].SecondRole < ARoleCount) and
      (ACrossings[I].BeforeFrame < ACrossings[I].AfterFrame), 'Invalid crossing identity');
    { A canonical order prevents counting one annotated span twice. }
    if I > 0 then
    begin
      Require((ACrossings[I].BeforeFrame > ACrossings[I - 1].BeforeFrame) or
        ((ACrossings[I].BeforeFrame = ACrossings[I - 1].BeforeFrame) and
        ((ACrossings[I].AfterFrame > ACrossings[I - 1].AfterFrame) or
        ((ACrossings[I].AfterFrame = ACrossings[I - 1].AfterFrame) and
        ((ACrossings[I].FirstRole > ACrossings[I - 1].FirstRole) or
        ((ACrossings[I].FirstRole = ACrossings[I - 1].FirstRole) and
        (ACrossings[I].SecondRole > ACrossings[I - 1].SecondRole)))))),
        'Crossing spans must be unique and canonically ordered');
    end;
    LBefore := FindCell(AReference, ACrossings[I].BeforeFrame);
    LAfter := FindCell(AReference, ACrossings[I].AfterFrame);
    LOrderBefore := ComparePitchOrder(AReference[LBefore], ACrossings[I].FirstRole,
      ACrossings[I].SecondRole);
    LOrderAfter := ComparePitchOrder(AReference[LAfter], ACrossings[I].FirstRole,
      ACrossings[I].SecondRole);
    Require(((LOrderBefore < 0) and (LOrderAfter > 0)) or
      ((LOrderBefore > 0) and (LOrderAfter < 0)), 'Crossing reference order must reverse');
    LKnown := True;
    LCorrect := True;
    for J := 0 to 1 do
    begin
      LCell := LBefore;
      if J = 1 then
      begin
        LCell := LAfter;
      end;
      for K := 0 to 1 do
      begin
        LRole := ACrossings[I].FirstRole;
        if K = 1 then
        begin
          LRole := ACrossings[I].SecondRole;
        end;
        LKnown := LKnown and (APrediction[LCell].Parts[LRole].State in [esValue, esRest]);
        LCorrect := LCorrect and (Length(APrediction[LCell].Parts[LRole].Notes) = 1);
        if Length(APrediction[LCell].Parts[LRole].Notes) = 1 then
        begin
          LCorrect := LCorrect and (APrediction[LCell].Parts[LRole].Notes[0] =
            AReference[LCell].Parts[LRole].Notes[0]);
        end;
      end;
    end;
    if not LKnown then
    begin
      Inc(AResult.CrossingEndpointsUnavailable);
    end
    else if LCorrect then
    begin
      Inc(AResult.CrossingEndpointsCorrect);
    end
    else
    begin
      Inc(AResult.CrossingEndpointsWrong);
    end;
  end;
end;

function EvaluatePartCells(const ARoleIds: TPartRoleIds;
  const AReference, APrediction: TPartEvaluationCells;
  const ACrossings: TPartCrossings; const AFirstFrame, AEndFrame: Int64): TPartEvaluation;
var
  LEntries: Int64;
  LOwners: TNoteOwners;
  LOwnerRole: TNoteOwners;
  LUnassigned: TNoteFlags;
  LRoleNotes: TNoteFlags;
  LComplete: Boolean;
  LScorable: Boolean;
  LUnique: Boolean;
  LReferenceState: TEvaluationState;
  LNote: Integer;
  I: Integer;
  J: Integer;
  K: Integer;
begin
  Require((Length(ARoleIds) > 0) and (Length(ARoleIds) <= MaximumPartRoles),
    'Part evaluation requires 1..32 declared roles');
  Require((AFirstFrame >= 0) and (AEndFrame > AFirstFrame) and
    (AEndFrame <= MaximumEvaluationFrame), 'Invalid part evaluation scope');
  Require((Length(AReference) > 0) and (Length(AReference) <= MaximumPartEvaluationCells) and
    (Length(AReference) = Length(APrediction)) and
    (Int64(Length(AReference)) * Length(ARoleIds) <= MaximumEvaluationItems) and
    (Length(ACrossings) <= MaximumPartCrossings), 'Part evaluation geometry/work limit');
  for I := 0 to High(ARoleIds) do
  begin
    Require((Length(ARoleIds[I]) > 0) and (Length(ARoleIds[I]) <= 256) and
      (Trim(ARoleIds[I]) = ARoleIds[I]) and (Pos(#0, ARoleIds[I]) = 0),
      'Invalid stable role ID');
    for J := 0 to I - 1 do
    begin
      Require(ARoleIds[I] <> ARoleIds[J], 'Duplicate stable role ID');
    end;
  end;
  LEntries := 0;
  ValidateCells(AReference, Length(ARoleIds), AFirstFrame, AEndFrame, LEntries);
  ValidateCells(APrediction, Length(ARoleIds), AFirstFrame, AEndFrame, LEntries);
  for I := 0 to High(AReference) do
  begin
    Require(AReference[I].Frame = APrediction[I].Frame, 'Part center grids differ');
  end;
  Result := Default(TPartEvaluation);
  Result.CellCount := Length(AReference);
  SetLength(Result.Roles, Length(ARoleIds));
  SetLength(Result.Leakage, Length(ARoleIds));
  for J := 0 to High(ARoleIds) do
  begin
    Result.Roles[J].RoleId := ARoleIds[J];
    SetLength(Result.Leakage[J], Length(ARoleIds));
  end;
  EvaluateCrossings(AReference, APrediction, ACrossings, Length(ARoleIds), Result);
  for I := 0 to High(AReference) do
  begin
    LOwners := Default(TNoteOwners);
    LOwnerRole := Default(TNoteOwners);
    LUnassigned := Default(TNoteFlags);
    LComplete := True;
    for K := 0 to High(AReference[I].UnassignedNotes) do
    begin
      LUnassigned[AReference[I].UnassignedNotes[K]] := True;
    end;
    Inc(Result.ReferenceUnassignedNotes, Length(AReference[I].UnassignedNotes));
    for J := 0 to High(ARoleIds) do
    begin
      LComplete := LComplete and (AReference[I].Parts[J].State in [esValue, esRest]);
      for K := 0 to High(AReference[I].Parts[J].Notes) do
      begin
        LNote := AReference[I].Parts[J].Notes[K];
        Inc(LOwners[LNote]);
        LOwnerRole[LNote] := J;
      end;
    end;
    for J := 0 to High(ARoleIds) do
    begin
      LReferenceState := AReference[I].Parts[J].State;
      Inc(Result.Roles[J].ReferenceStates[LReferenceState]);
      Inc(Result.Roles[J].PredictionStates[APrediction[I].Parts[J].State]);
      LScorable := LReferenceState in [esValue, esRest];
      if not LScorable then
      begin
        Inc(Result.Roles[J].AdmittedUnscorable, Length(APrediction[I].Parts[J].Notes));
        Continue;
      end;
      Inc(Result.Roles[J].ReferenceNotes, Length(AReference[I].Parts[J].Notes));
      Inc(Result.Roles[J].PredictedScorableNotes, Length(APrediction[I].Parts[J].Notes));
      if LReferenceState = esRest then
      begin
        Inc(Result.Roles[J].FalseNotesInRest, Length(APrediction[I].Parts[J].Notes));
      end;
      LRoleNotes := Default(TNoteFlags);
      for K := 0 to High(AReference[I].Parts[J].Notes) do
      begin
        LRoleNotes[AReference[I].Parts[J].Notes[K]] := True;
      end;
      for K := 0 to High(APrediction[I].Parts[J].Notes) do
      begin
        LNote := APrediction[I].Parts[J].Notes[K];
        LUnique := LComplete and (LOwners[LNote] = 1) and not LUnassigned[LNote];
        if LRoleNotes[LNote] then
        begin
          Inc(Result.Roles[J].CorrectNotes);
          if LUnique then
          begin
            Inc(Result.Roles[J].UniqueOwnerMatches);
          end
          else
          begin
            Inc(Result.Roles[J].UncertainOwnerMatches);
          end;
        end
        else if LUnique then
        begin
          Inc(Result.Roles[J].WrongOwnerNotes);
          Inc(Result.Leakage[LOwnerRole[LNote]][J]);
        end
        else if LOwners[LNote] > 1 then
        begin
          Inc(Result.Roles[J].AmbiguousWrongOwnerNotes);
        end
        else if not LComplete or LUnassigned[LNote] then
        begin
          Inc(Result.Roles[J].UnresolvedExtraNotes);
        end
        else
        begin
          Inc(Result.Roles[J].NovelPitchNotes);
        end;
      end;
    end;
    Inc(Result.PredictionUnassignedNotes, Length(APrediction[I].UnassignedNotes));
    for K := 0 to High(APrediction[I].UnassignedNotes) do
    begin
      LNote := APrediction[I].UnassignedNotes[K];
      if (LOwners[LNote] > 0) or LUnassigned[LNote] then
      begin
        Inc(Result.UnassignedPitchMatches);
      end
      else if LComplete then
      begin
        Inc(Result.UnassignedExtraPitches);
      end
      else
      begin
        Inc(Result.UnassignedUnscorable);
      end;
    end;
  end;
  for J := 0 to High(ARoleIds) do
  begin
    Result.Roles[J].MissedNotes := Result.Roles[J].ReferenceNotes - Result.Roles[J].CorrectNotes;
    Result.Roles[J].ExtraNotes := Result.Roles[J].PredictedScorableNotes - Result.Roles[J].CorrectNotes;
    if Result.Roles[J].ReferenceNotes > 0 then
    begin
      Result.Roles[J].Coverage := Result.Roles[J].CorrectNotes / Result.Roles[J].ReferenceNotes;
    end;
    if Result.Roles[J].PredictedScorableNotes > 0 then
    begin
      Result.Roles[J].Precision := Result.Roles[J].CorrectNotes / Result.Roles[J].PredictedScorableNotes;
    end;
    Result.Roles[J].ReferenceCoverage :=
      (Result.Roles[J].ReferenceStates[esValue] + Result.Roles[J].ReferenceStates[esRest]) /
      Result.CellCount;
  end;
end;

end.
