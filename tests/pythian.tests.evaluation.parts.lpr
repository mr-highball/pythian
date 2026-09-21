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
program pythian_tests_evaluation_parts;

{$mode delphi}
{$H+}

uses
  SysUtils, pythian.audio, pythian.evaluation, pythian.evaluation.parts;

procedure Check(const ACondition: Boolean; const AMessage: String);
begin
  if not ACondition then
  begin
    raise Exception.Create(AMessage);
  end;
end;

function Notes(const AValues: array of Integer): TPartObservation;
var
  I: Integer;
begin
  Result := Default(TPartObservation);
  Result.State := esRest;
  SetLength(Result.Notes, Length(AValues));
  if Length(AValues) > 0 then
  begin
    Result.State := esValue;
  end;
  for I := 0 to High(AValues) do
  begin
    Result.Notes[I] := AValues[I];
  end;
end;

function MaskNotes(const AMask: Integer): TPartObservation;
var
  I: Integer;
  LCount: Integer;
begin
  Result := Notes([]);
  LCount := 0;
  for I := 0 to 2 do
  begin
    if (AMask and (1 shl I)) <> 0 then
    begin
      Inc(LCount);
      SetLength(Result.Notes, LCount);
      Result.Notes[LCount - 1] := 60 + I;
      Result.State := esValue;
    end;
  end;
end;

function CountMask(const AMask: Integer): Integer;
begin
  Result := (AMask and 1) + ((AMask shr 1) and 1) + ((AMask shr 2) and 1);
end;

function Cells(const ACount, ARoles: Integer): TPartEvaluationCells;
var
  I: Integer;
  J: Integer;
begin
  Result := nil;
  SetLength(Result, ACount);
  for I := 0 to ACount - 1 do
  begin
    Result[I].Frame := 100 + I * 100;
    SetLength(Result[I].Parts, ARoles);
    for J := 0 to ARoles - 1 do
    begin
      Result[I].Parts[J].State := esRest;
    end;
  end;
end;

procedure SetOracle;
var
  LIds: TPartRoleIds;
  LReference: TPartEvaluationCells;
  LPrediction: TPartEvaluationCells;
  LScore: TPartEvaluation;
  R0: Integer;
  R1: Integer;
  P0: Integer;
  P1: Integer;
begin
  SetLength(LIds, 2);
  LIds[0] := 'bass';
  LIds[1] := 'chordal';
  LReference := Cells(1, 2);
  LPrediction := Cells(1, 2);
  { Exhaustive tiny independent bit-mask oracle, not another pitch-set traversal.
    Three pitches allow chords, unisons and swapped ownership in 4096 cases. }
  for R0 := 0 to 7 do
  begin
    for R1 := 0 to 7 do
    begin
      LReference[0].Parts[0] := MaskNotes(R0);
      LReference[0].Parts[1] := MaskNotes(R1);
      for P0 := 0 to 7 do
      begin
        for P1 := 0 to 7 do
        begin
          LPrediction[0].Parts[0] := MaskNotes(P0);
          LPrediction[0].Parts[1] := MaskNotes(P1);
          LScore := EvaluatePartCells(LIds, LReference, LPrediction, nil, 0, 200);
          Check(LScore.Roles[0].CorrectNotes = CountMask(R0 and P0), 'Role zero intersection');
          Check(LScore.Roles[1].CorrectNotes = CountMask(R1 and P1), 'Role one intersection');
          Check(LScore.Roles[0].MissedNotes = CountMask(R0 and not P0), 'Missing chord members');
          Check(LScore.Roles[1].ExtraNotes = CountMask(P1 and not R1), 'Extra chord members');
          Check(LScore.Roles[0].UniqueOwnerMatches = CountMask(R0 and P0 and not R1),
            'Unique owner intersection');
          Check(LScore.Roles[0].UncertainOwnerMatches = CountMask(R0 and P0 and R1),
            'Unisons cannot establish unique ownership');
          Check(LScore.Leakage[0][1] = CountMask(R0 and not R1 and P1), 'Zero to one leakage');
          Check(LScore.Leakage[1][0] = CountMask(R1 and not R0 and P0), 'One to zero leakage');
          Check(LScore.Roles[0].NovelPitchNotes = CountMask(P0 and not (R0 or R1)),
            'Novel pitches separate from ownership errors');
          Check(LScore.Roles[0].ReferenceCoverage = 1, 'Known reference coverage');
        end;
      end;
    end;
  end;
end;

procedure IncompleteOwnership;
var
  LIds: TPartRoleIds;
  LReference: TPartEvaluationCells;
  LPrediction: TPartEvaluationCells;
  LScore: TPartEvaluation;
begin
  SetLength(LIds, 3);
  LIds[0] := 'first';
  LIds[1] := 'second';
  LIds[2] := 'third';
  LReference := Cells(1, 3);
  LPrediction := Cells(1, 3);
  LReference[0].Parts[0] := Notes([60]);
  LReference[0].Parts[1] := Notes([60]);
  LPrediction[0].Parts[2] := Notes([60, 61]);
  LScore := EvaluatePartCells(LIds, LReference, LPrediction, nil, 0, 200);
  Check((LScore.Roles[2].AmbiguousWrongOwnerNotes = 1) and
    (LScore.Roles[2].NovelPitchNotes = 1) and (LScore.Roles[2].FalseNotesInRest = 2) and
    (LScore.Leakage[0][2] = 0) and (LScore.Leakage[1][2] = 0),
    'Unison leakage cannot choose one of two reference owners');
  LReference[0].Parts[1] := Notes([]);
  LReference[0].Parts[1].State := esUnknown;
  LScore := EvaluatePartCells(LIds, LReference, LPrediction, nil, 0, 200);
  Check((LScore.Roles[2].UnresolvedExtraNotes = 2) and
    (LScore.Roles[2].WrongOwnerNotes = 0), 'Incomplete truth cannot assign leakage');
  LReference[0].Parts[1].State := esRest;
  SetLength(LReference[0].UnassignedNotes, 1);
  LReference[0].UnassignedNotes[0] := 60;
  LScore := EvaluatePartCells(LIds, LReference, LPrediction, nil, 0, 200);
  Check((LScore.Roles[2].UnresolvedExtraNotes = 1) and
    (LScore.Roles[2].NovelPitchNotes = 1) and (LScore.ReferenceUnassignedNotes = 1),
    'Unassigned reference pitch withholds owner claim');
end;

procedure UncertaintyAndCrossings;
var
  LIds: TPartRoleIds;
  LReference: TPartEvaluationCells;
  LPrediction: TPartEvaluationCells;
  LCrossings: TPartCrossings;
  LScore: TPartEvaluation;
  LPrevious: TPartEvaluation;
  LRejected: Boolean;
begin
  SetLength(LIds, 3);
  LIds[0] := 'voice-a';
  LIds[1] := 'voice-b';
  LIds[2] := 'chordal';
  LReference := Cells(2, 3);
  LPrediction := Cells(2, 3);
  LReference[0].Parts[0] := Notes([60]);
  LReference[0].Parts[1] := Notes([67]);
  LReference[1].Parts[0] := Notes([69]);
  LReference[1].Parts[1] := Notes([64]);
  LReference[0].Parts[2] := Notes([48, 52, 55]);
  LReference[1].Parts[2] := Notes([48, 52, 55]);
  LPrediction[0].Parts[0] := Notes([60]);
  LPrediction[0].Parts[1] := Notes([67]);
  LPrediction[1].Parts[0] := Notes([69]);
  LPrediction[1].Parts[1] := Notes([64]);
  LPrediction[0].Parts[2] := Notes([48, 52, 55]);
  LPrediction[1].Parts[2] := Notes([48, 52, 55]);
  SetLength(LCrossings, 1);
  LCrossings[0].FirstRole := 0;
  LCrossings[0].SecondRole := 1;
  LCrossings[0].BeforeFrame := 100;
  LCrossings[0].AfterFrame := 200;
  LScore := EvaluatePartCells(LIds, LReference, LPrediction, LCrossings, 0, 300);
  Check((LScore.CrossingEndpointsCorrect = 1) and (LScore.Roles[2].CorrectNotes = 6),
    'Stable roles through crossing with simultaneous chord');
  LPrediction[1].Parts[0] := Notes([64]);
  LPrediction[1].Parts[1] := Notes([69]);
  LScore := EvaluatePartCells(LIds, LReference, LPrediction, LCrossings, 0, 300);
  Check((LScore.CrossingEndpointsWrong = 1) and (LScore.Leakage[0][1] = 1) and
    (LScore.Leakage[1][0] = 1), 'Pitch-order relabeling fails ownership');
  LPrediction[1].Parts[0] := Notes([]);
  LPrediction[1].Parts[0].State := esUnknown;
  LPrediction[1].Parts[1] := Notes([]);
  LPrediction[1].Parts[1].State := esAmbiguous;
  SetLength(LPrediction[1].UnassignedNotes, 2);
  LPrediction[1].UnassignedNotes[0] := 64;
  LPrediction[1].UnassignedNotes[1] := 69;
  LScore := EvaluatePartCells(LIds, LReference, LPrediction, LCrossings, 0, 300);
  Check((LScore.CrossingEndpointsUnavailable = 1) and (LScore.UnassignedPitchMatches = 2) and
    (LScore.Roles[0].MissedNotes = 1), 'Unknown owner keeps pitch without role credit');
  LReference[0].Parts[2] := Notes([]);
  LReference[0].Parts[2].State := esUnsupported;
  LScore := EvaluatePartCells(LIds, LReference, LPrediction, LCrossings, 0, 300);
  Check((LScore.Roles[2].AdmittedUnscorable = 3) and
    (LScore.Roles[0].UncertainOwnerMatches = 1), 'Incomplete truth cannot certify unique owner');
  LPrevious := LScore;
  LPrediction[0].Parts[0] := Notes([60, 60]);
  LRejected := False;
  try
    LScore := EvaluatePartCells(LIds, LReference, LPrediction, LCrossings, 0, 300);
  except
    on LException: EAudio do
    begin
      LRejected := True;
    end;
  end;
  Check(LRejected and (LScore.Roles[2].AdmittedUnscorable = LPrevious.Roles[2].AdmittedUnscorable),
    'Rejected duplicate preserves previously assigned managed result');
  Check((LReference[1].Parts[0].Notes[0] = 69) and
    (LPrediction[0].Parts[0].Notes[1] = 60), 'Borrowed nested inputs preserved');
end;

begin
  try
    SetOracle;
    IncompleteOwnership;
    UncertaintyAndCrossings;
    WriteLn('Part set oracle, ownership uncertainty, crossings and preservation passed');
  except
    on LException: Exception do
    begin
      WriteLn(StdErr, LException.ClassName, ': ', LException.Message);
      ExitCode := 1;
    end;
  end;
end.
