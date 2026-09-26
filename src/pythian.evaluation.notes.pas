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
unit pythian.evaluation.notes;

{$mode delphi}
{$H+}

interface

uses
  pythian.evaluation;

const
  MaximumOverlappingNotes = 4096;
  MaximumNotesPerPitch = 256;
  MaximumNoteRegions = 16384;
  MaximumNoteCandidateEdges = 262144;
  MaximumNoteMatchingWork = 50000000;
  MaximumNoteScopeFrames: Int64 = 1000000000000;

type
  TEvaluationNote = record
    Id: UTF8String;
    StartFrame: Int64;
    EndFrame: Int64;
    Pitch: Integer;
  end;
  TEvaluationNotes = array of TEvaluationNote;
  TEvaluationNoteRegion = record
    FirstFrame: Int64;
    EndFrame: Int64;
    State: TEvaluationState;
  end;
  TEvaluationNoteRegions = array of TEvaluationNoteRegion;
  TOverlappingNoteOptions = record
    OnsetToleranceFrames: Int64;
    MinimumOffsetToleranceFrames: Int64;
    OffsetFractionNumerator: Integer;
    OffsetFractionDenominator: Integer;
    EdgeFrames: Int64;
  end;
  TEvaluationNoteIds = array of UTF8String;
  TEvaluationNotePair = record
    ReferenceId: UTF8String;
    PredictionId: UTF8String;
    OnsetErrorFrames: Int64;
    OffsetErrorFrames: Int64;
  end;
  TEvaluationNotePairs = array of TEvaluationNotePair;
  TNoteAssignment = record
    Pairs: TEvaluationNotePairs;
    MissedIds: TEvaluationNoteIds;
    ExtraIds: TEvaluationNoteIds;
    OnsetErrorFrames: Int64;
    OffsetErrorFrames: Int64;
    Recall: Double;
    Precision: Double;
    F1: Double;
  end;
  TOverlappingNoteEvaluation = record
    ReferenceNotes: Integer;
    PredictionNotes: Integer;
    ReferenceCensored: TEvaluationNoteIds;
    PredictionCensored: TEvaluationNoteIds;
    ReferenceUncertain: TEvaluationNoteIds;
    PredictionUnscorable: TEvaluationNoteIds;
    RegionFrames: array[TEvaluationState] of Int64;
    ReferenceCoverage: Double;
    CandidateChecks: Int64;
    CandidateEdges: Int64;
    MatchingWork: Int64;
    Onsets: TNoteAssignment;
    FullNotes: TNoteAssignment;
  end;

{ Score ONE declared role/scope. Role assignment and source binding are caller
  obligations. Arbitrary input order and overlapping repeated pitches are valid;
  IDs are unique within each side. No input is changed. Regions partition the
  entire [first,end) scope: esValue means complete exact note annotations including
  gaps; esRest additionally forbids reference notes. Other states explicitly
  exclude intersecting notes on BOTH sides. This is region exclusion, not matching
  uncertain timestamps. Edge-censored notes are reported before uncertainty.
  For each of onset/full-note matching: maximize unrestricted one-to-one count,
  then minimize onset error, then offset error. Exact ties use deterministic
  canonical-ID traversal, not a promised lexicographically minimal pair list.
  Separate assignments retain their own pairs/errors. No acceptance is inferred. }
function EvaluateOverlappingNotes(const AReference, APrediction: TEvaluationNotes;
  const ARegions: TEvaluationNoteRegions; const AFirstFrame, AEndFrame: Int64;
  const AOptions: TOverlappingNoteOptions;
  const AMatchingWorkLimit: Int64 = MaximumNoteMatchingWork): TOverlappingNoteEvaluation;

implementation

uses
  SysUtils, pythian.audio;

type
  TIndices = array of Integer;
  TCost = record
    Known: Boolean;
    Onset: Int64;
    Offset: Int64;
  end;
  TCosts = array of TCost;
  TEdge = record
    ReferenceIndex: Integer;
    PredictionIndex: Integer;
    Onset: Int64;
    Offset: Int64;
    Full: Boolean;
  end;
  TEdges = array of TEdge;

procedure Require(const ACondition: Boolean; const AMessage: String);
begin
  if not ACondition then
  begin
    raise EAudio.Create(AMessage);
  end;
end;

procedure AddId(var AIds: TEvaluationNoteIds; const AId: UTF8String);
begin
  SetLength(AIds, Length(AIds) + 1);
  AIds[High(AIds)] := AId;
end;

procedure AddIndex(var AIndices: TIndices; const AIndex: Integer);
begin
  SetLength(AIndices, Length(AIndices) + 1);
  AIndices[High(AIndices)] := AIndex;
end;

function CompareIds(const AFirst, ASecond: UTF8String): Integer;
var
  I: Integer;
begin
  for I := 1 to Length(AFirst) do
  begin
    if I > Length(ASecond) then
    begin
      Exit(1);
    end;
    Result := Ord(AFirst[I]) - Ord(ASecond[I]);
    if Result <> 0 then
    begin
      Exit;
    end;
  end;
  Result := Length(AFirst) - Length(ASecond);
end;

function CanonicalOrder(const AIds: TEvaluationNoteIds): TIndices;
var
  LTemporary: TIndices;
  LSwap: TIndices;
  LWidth: Integer;
  LFirst: Integer;
  LMiddle: Integer;
  LEnd: Integer;
  LLeft: Integer;
  LRight: Integer;
  I: Integer;
begin
  Result := nil;
  SetLength(Result, Length(AIds));
  SetLength(LTemporary, Length(AIds));
  for I := 0 to High(Result) do
  begin
    Result[I] := I;
  end;
  LWidth := 1;
  while LWidth < Length(Result) do
  begin
    LFirst := 0;
    while LFirst < Length(Result) do
    begin
      LMiddle := LFirst + LWidth;
      if LMiddle > Length(Result) then
      begin
        LMiddle := Length(Result);
      end;
      LEnd := LMiddle + LWidth;
      if LEnd > Length(Result) then
      begin
        LEnd := Length(Result);
      end;
      LLeft := LFirst;
      LRight := LMiddle;
      for I := LFirst to LEnd - 1 do
      begin
        if (LRight >= LEnd) or ((LLeft < LMiddle) and
          (CompareIds(AIds[Result[LLeft]], AIds[Result[LRight]]) <= 0)) then
        begin
          LTemporary[I] := Result[LLeft];
          Inc(LLeft);
        end
        else
        begin
          LTemporary[I] := Result[LRight];
          Inc(LRight);
        end;
      end;
      LFirst := LEnd;
    end;
    LSwap := Result;
    Result := LTemporary;
    LTemporary := LSwap;
    LWidth := LWidth * 2;
  end;
end;

function CanonicalNotes(const ANotes: TEvaluationNotes): TIndices;
var
  LIds: TEvaluationNoteIds;
  I: Integer;
begin
  Require(Length(ANotes) <= MaximumOverlappingNotes, 'Note count exceeds budget');
  Result := nil;
  SetLength(LIds, Length(ANotes));
  for I := 0 to High(ANotes) do
  begin
    Require((Length(ANotes[I].Id) > 0) and (Length(ANotes[I].Id) <= 256) and
      (Trim(ANotes[I].Id) = ANotes[I].Id) and (Pos(#0, ANotes[I].Id) = 0),
      'Invalid note event ID');
    Require((ANotes[I].StartFrame >= 0) and (ANotes[I].EndFrame > ANotes[I].StartFrame) and
      (ANotes[I].EndFrame <= MaximumEvaluationFrame) and
      (ANotes[I].Pitch >= 0) and (ANotes[I].Pitch <= 127), 'Invalid note interval/pitch');
    LIds[I] := ANotes[I].Id;
  end;
  Result := CanonicalOrder(LIds);
  for I := 1 to High(Result) do
  begin
    Require(LIds[Result[I]] <> LIds[Result[I - 1]], 'Duplicate note event ID');
  end;
end;

function SelectNotes(const ANotes: TEvaluationNotes; const AIndices: TIndices;
  const ARegions: TEvaluationNoteRegions; const AFirst, AEnd: Int64;
  const AReference: Boolean; var ACensored, AUncertain: TEvaluationNoteIds): TIndices;
var
  LNote: TEvaluationNote;
  LUncertain: Boolean;
  I: Integer;
  J: Integer;
begin
  Result := nil;
  for I := 0 to High(AIndices) do
  begin
    LNote := ANotes[AIndices[I]];
    LUncertain := False;
    for J := 0 to High(ARegions) do
    begin
      if (LNote.StartFrame < ARegions[J].EndFrame) and
        (LNote.EndFrame > ARegions[J].FirstFrame) then
      begin
        Require(not AReference or (ARegions[J].State <> esRest),
          'Reference event contradicts an annotated rest');
        LUncertain := LUncertain or
          (ARegions[J].State in [esUnknown, esAmbiguous, esUnsupported]);
      end;
    end;
    if (LNote.StartFrame < AFirst) or (LNote.EndFrame > AEnd) then
    begin
      AddId(ACensored, LNote.Id);
      Continue;
    end;
    if LUncertain then
    begin
      AddId(AUncertain, LNote.Id);
    end
    else
    begin
      AddIndex(Result, AIndices[I]);
    end;
  end;
end;

function PitchIndices(const ANotes: TEvaluationNotes; const AIndices: TIndices;
  const APitch: Integer): TIndices;
var
  I: Integer;
begin
  Result := nil;
  for I := 0 to High(AIndices) do
  begin
    if ANotes[AIndices[I]].Pitch = APitch then
    begin
      AddIndex(Result, AIndices[I]);
    end;
  end;
  Require(Length(Result) <= MaximumNotesPerPitch, 'Per-pitch note count exceeds budget');
end;

function Edges(const AReference, APrediction: TEvaluationNotes;
  const AReferences, APredictions: TIndices; const AOptions: TOverlappingNoteOptions;
  var AResult: TOverlappingNoteEvaluation): TEdges;
var
  LOnset: Int64;
  LOffset: Int64;
  LDuration: Int64;
  LCount: Integer;
  I: Integer;
  J: Integer;
begin
  Result := nil;
  SetLength(Result, Length(AReferences) * Length(APredictions));
  LCount := 0;
  for I := 0 to High(AReferences) do
  begin
    for J := 0 to High(APredictions) do
    begin
      Inc(AResult.CandidateChecks);
      LOnset := Abs(AReference[AReferences[I]].StartFrame - APrediction[APredictions[J]].StartFrame);
      if LOnset > AOptions.OnsetToleranceFrames then
      begin
        Continue;
      end;
      LOffset := Abs(AReference[AReferences[I]].EndFrame - APrediction[APredictions[J]].EndFrame);
      LDuration := AReference[AReferences[I]].EndFrame - AReference[AReferences[I]].StartFrame;
      Inc(AResult.CandidateEdges);
      Require(AResult.CandidateEdges <= MaximumNoteCandidateEdges, 'Note edge budget exceeded');
      Result[LCount].ReferenceIndex := I;
      Result[LCount].PredictionIndex := J;
      Result[LCount].Onset := LOnset;
      Result[LCount].Offset := LOffset;
      Result[LCount].Full := (LOffset <= AOptions.MinimumOffsetToleranceFrames) or
        (LOffset * AOptions.OffsetFractionDenominator <=
        LDuration * AOptions.OffsetFractionNumerator);
      Inc(LCount);
    end;
  end;
  SetLength(Result, LCount);
end;

function BetterCost(const AOnset, AOffset: Int64; const AOld: TCost): Boolean;
begin
  Result := not AOld.Known or (AOnset < AOld.Onset) or
    ((AOnset = AOld.Onset) and (AOffset < AOld.Offset));
end;

procedure SetCost(var ACost: TCost; const AOnset, AOffset: Int64);
begin
  ACost.Known := True;
  ACost.Onset := AOnset;
  ACost.Offset := AOffset;
end;

procedure MatchGroup(const AReference, APrediction: TEvaluationNotes;
  const AReferences, APredictions: TIndices; const AEdges: TEdges;
  const AFull: Boolean; var AAssignment: TNoteAssignment; var AWork: Int64;
  const AWorkLimit: Int64);
var
  LMatchR: TIndices;
  LMatchP: TIndices;
  LPreviousP: TIndices;
  LDistanceR: TCosts;
  LDistanceP: TCosts;
  LChanged: Boolean;
  LOnset: Int64;
  LOffset: Int64;
  LBest: Integer;
  LOld: Integer;
  LSteps: Integer;
  LPair: TEvaluationNotePair;
  R: Integer;
  P: Integer;
  I: Integer;
  J: Integer;
begin
  SetLength(LMatchR, Length(AReferences));
  SetLength(LMatchP, Length(APredictions));
  SetLength(LPreviousP, Length(APredictions));
  SetLength(LDistanceR, Length(AReferences));
  SetLength(LDistanceP, Length(APredictions));
  for I := 0 to High(LMatchR) do
  begin
    LMatchR[I] := -1;
  end;
  for I := 0 to High(LMatchP) do
  begin
    LMatchP[I] := -1;
  end;
  while True do
  begin
    for I := 0 to High(LDistanceR) do
    begin
      LDistanceR[I] := Default(TCost);
      if LMatchR[I] < 0 then
      begin
        SetCost(LDistanceR[I], 0, 0);
      end;
    end;
    for I := 0 to High(LDistanceP) do
    begin
      LDistanceP[I] := Default(TCost);
      LPreviousP[I] := -1;
    end;
    { Successive shortest augmenting paths in the residual bipartite graph.
      A matched edge reverses with negative tuple cost. Bellman-Ford avoids
      scalar cost packing and accommodates those negative reverse edges. }
    for I := 0 to Length(LDistanceR) + Length(LDistanceP) do
    begin
      LChanged := False;
      for J := 0 to High(AEdges) do
      begin
        Inc(AWork);
        Require(AWork <= AWorkLimit, 'Note matching work budget exceeded');
        if AFull and not AEdges[J].Full then
        begin
          Continue;
        end;
        R := AEdges[J].ReferenceIndex;
        P := AEdges[J].PredictionIndex;
        if LMatchR[R] = P then
        begin
          if LDistanceP[P].Known then
          begin
            LOnset := LDistanceP[P].Onset - AEdges[J].Onset;
            LOffset := LDistanceP[P].Offset - AEdges[J].Offset;
            if BetterCost(LOnset, LOffset, LDistanceR[R]) then
            begin
              SetCost(LDistanceR[R], LOnset, LOffset);
              LChanged := True;
            end;
          end;
        end
        else if LDistanceR[R].Known then
        begin
          LOnset := LDistanceR[R].Onset + AEdges[J].Onset;
          LOffset := LDistanceR[R].Offset + AEdges[J].Offset;
          if BetterCost(LOnset, LOffset, LDistanceP[P]) then
          begin
            SetCost(LDistanceP[P], LOnset, LOffset);
            LPreviousP[P] := R;
            LChanged := True;
          end;
        end;
      end;
      if not LChanged then
      begin
        Break;
      end;
      Require(I < Length(LDistanceR) + Length(LDistanceP), 'Invalid negative matching cycle');
    end;
    LBest := -1;
    for P := 0 to High(LMatchP) do
    begin
      if (LMatchP[P] < 0) and LDistanceP[P].Known then
      begin
        if (LBest < 0) or BetterCost(LDistanceP[P].Onset, LDistanceP[P].Offset,
          LDistanceP[LBest]) then
        begin
          LBest := P;
        end;
      end;
    end;
    if LBest < 0 then
    begin
      Break;
    end;
    P := LBest;
    LSteps := 0;
    while P >= 0 do
    begin
      Inc(LSteps);
      Require(LSteps <= Length(LMatchR), 'Invalid augmenting predecessor chain');
      R := LPreviousP[P];
      Require(R >= 0, 'Missing augmenting predecessor');
      LOld := LMatchR[R];
      LMatchR[R] := P;
      LMatchP[P] := R;
      P := LOld;
    end;
  end;
  for R := 0 to High(LMatchR) do
  begin
    P := LMatchR[R];
    if P < 0 then
    begin
      AddId(AAssignment.MissedIds, AReference[AReferences[R]].Id);
    end
    else
    begin
      LPair := Default(TEvaluationNotePair);
      LPair.ReferenceId := AReference[AReferences[R]].Id;
      LPair.PredictionId := APrediction[APredictions[P]].Id;
      LPair.OnsetErrorFrames := Abs(AReference[AReferences[R]].StartFrame -
        APrediction[APredictions[P]].StartFrame);
      LPair.OffsetErrorFrames := Abs(AReference[AReferences[R]].EndFrame -
        APrediction[APredictions[P]].EndFrame);
      Inc(AAssignment.OnsetErrorFrames, LPair.OnsetErrorFrames);
      Inc(AAssignment.OffsetErrorFrames, LPair.OffsetErrorFrames);
      SetLength(AAssignment.Pairs, Length(AAssignment.Pairs) + 1);
      AAssignment.Pairs[High(AAssignment.Pairs)] := LPair;
    end;
  end;
  for P := 0 to High(LMatchP) do
  begin
    if LMatchP[P] < 0 then
    begin
      AddId(AAssignment.ExtraIds, APrediction[APredictions[P]].Id);
    end;
  end;
end;

procedure FinishAssignment(var AAssignment: TNoteAssignment;
  const AReferenceCount, APredictionCount: Integer);
var
  LIds: TEvaluationNoteIds;
  LOrderedIds: TEvaluationNoteIds;
  LOrder: TIndices;
  LPairs: TEvaluationNotePairs;
  I: Integer;
begin
  if AReferenceCount > 0 then
  begin
    AAssignment.Recall := Length(AAssignment.Pairs) / AReferenceCount;
  end;
  if APredictionCount > 0 then
  begin
    AAssignment.Precision := Length(AAssignment.Pairs) / APredictionCount;
  end;
  if AReferenceCount + APredictionCount > 0 then
  begin
    AAssignment.F1 := 2 * Length(AAssignment.Pairs) / (AReferenceCount + APredictionCount);
  end;
  SetLength(LIds, Length(AAssignment.Pairs));
  for I := 0 to High(AAssignment.Pairs) do
  begin
    LIds[I] := AAssignment.Pairs[I].ReferenceId;
  end;
  LOrder := CanonicalOrder(LIds);
  SetLength(LPairs, Length(LOrder));
  for I := 0 to High(LOrder) do
  begin
    LPairs[I] := AAssignment.Pairs[LOrder[I]];
  end;
  AAssignment.Pairs := LPairs;
  LOrder := CanonicalOrder(AAssignment.MissedIds);
  SetLength(LOrderedIds, Length(LOrder));
  for I := 0 to High(LOrder) do
  begin
    LOrderedIds[I] := AAssignment.MissedIds[LOrder[I]];
  end;
  AAssignment.MissedIds := LOrderedIds;
  LOrderedIds := nil;
  LOrder := CanonicalOrder(AAssignment.ExtraIds);
  SetLength(LOrderedIds, Length(LOrder));
  for I := 0 to High(LOrder) do
  begin
    LOrderedIds[I] := AAssignment.ExtraIds[LOrder[I]];
  end;
  AAssignment.ExtraIds := LOrderedIds;
end;

function EvaluateOverlappingNotes(const AReference, APrediction: TEvaluationNotes;
  const ARegions: TEvaluationNoteRegions; const AFirstFrame, AEndFrame: Int64;
  const AOptions: TOverlappingNoteOptions;
  const AMatchingWorkLimit: Int64): TOverlappingNoteEvaluation;
var
  LReferences: TIndices;
  LPredictions: TIndices;
  LReferencePitch: TIndices;
  LPredictionPitch: TIndices;
  LEdges: TEdges;
  LEnd: Int64;
  LFirst: Int64;
  I: Integer;
begin
  Require((AMatchingWorkLimit >= 0) and (AMatchingWorkLimit <= MaximumNoteMatchingWork),
    'Invalid caller matching work budget');
  Require((AFirstFrame >= 0) and (AEndFrame > AFirstFrame) and
    (AEndFrame <= MaximumEvaluationFrame) and
    (AEndFrame - AFirstFrame <= MaximumNoteScopeFrames), 'Invalid note evaluation scope');
  Require((AOptions.OnsetToleranceFrames >= 0) and
    (AOptions.OnsetToleranceFrames <= MaximumEvaluationTolerance) and
    (AOptions.MinimumOffsetToleranceFrames >= 0) and
    (AOptions.MinimumOffsetToleranceFrames <= MaximumEvaluationTolerance) and
    (AOptions.OffsetFractionDenominator > 0) and
    (AOptions.OffsetFractionDenominator <= 1000000) and
    (AOptions.OffsetFractionNumerator >= 0) and
    (AOptions.OffsetFractionNumerator <= AOptions.OffsetFractionDenominator) and
    (AOptions.EdgeFrames >= 0) and
    (AOptions.EdgeFrames <= (AEndFrame - AFirstFrame) div 2), 'Invalid note timing policy');
  LFirst := AFirstFrame + AOptions.EdgeFrames;
  LEnd := AEndFrame - AOptions.EdgeFrames;
  Require(LEnd > LFirst, 'Note edge exclusion removes the entire scope');
  LReferences := CanonicalNotes(AReference);
  LPredictions := CanonicalNotes(APrediction);
  Require((Length(ARegions) > 0) and (Length(ARegions) <= MaximumNoteRegions) and
    (Int64(Length(AReference) + Length(APrediction)) * Length(ARegions) <= 16777216),
    'Note annotation region/work budget exceeded');
  Result := Default(TOverlappingNoteEvaluation);
  for I := 0 to High(ARegions) do
  begin
    Require((Ord(ARegions[I].State) >= Ord(Low(TEvaluationState))) and
      (Ord(ARegions[I].State) <= Ord(High(TEvaluationState))) and
      (ARegions[I].EndFrame > ARegions[I].FirstFrame) and
      (ARegions[I].FirstFrame >= AFirstFrame) and (ARegions[I].EndFrame <= AEndFrame),
      'Invalid annotation region');
    if I = 0 then
    begin
      Require(ARegions[I].FirstFrame = AFirstFrame, 'Annotation scope start differs');
    end
    else
    begin
      Require(ARegions[I].FirstFrame = ARegions[I - 1].EndFrame,
        'Annotation regions must partition the complete scope');
    end;
    Inc(Result.RegionFrames[ARegions[I].State], ARegions[I].EndFrame - ARegions[I].FirstFrame);
  end;
  Require(ARegions[High(ARegions)].EndFrame = AEndFrame, 'Annotation scope end differs');
  Result.ReferenceCoverage := (Result.RegionFrames[esValue] + Result.RegionFrames[esRest]) /
    (AEndFrame - AFirstFrame);
  LReferences := SelectNotes(AReference, LReferences, ARegions, LFirst, LEnd, True,
    Result.ReferenceCensored, Result.ReferenceUncertain);
  LPredictions := SelectNotes(APrediction, LPredictions, ARegions, LFirst, LEnd, False,
    Result.PredictionCensored, Result.PredictionUnscorable);
  Result.ReferenceNotes := Length(LReferences);
  Result.PredictionNotes := Length(LPredictions);
  for I := 0 to 127 do
  begin
    LReferencePitch := PitchIndices(AReference, LReferences, I);
    LPredictionPitch := PitchIndices(APrediction, LPredictions, I);
    LEdges := Edges(AReference, APrediction, LReferencePitch, LPredictionPitch, AOptions, Result);
    MatchGroup(AReference, APrediction, LReferencePitch, LPredictionPitch, LEdges, False,
      Result.Onsets, Result.MatchingWork, AMatchingWorkLimit);
    MatchGroup(AReference, APrediction, LReferencePitch, LPredictionPitch, LEdges, True,
      Result.FullNotes, Result.MatchingWork, AMatchingWorkLimit);
  end;
  FinishAssignment(Result.Onsets, Result.ReferenceNotes, Result.PredictionNotes);
  FinishAssignment(Result.FullNotes, Result.ReferenceNotes, Result.PredictionNotes);
end;

end.
