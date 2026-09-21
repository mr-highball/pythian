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
program pythian_tests_evaluation;

{$mode delphi}
{$H+}

uses
  SysUtils, Math, pythian.audio, pythian.evaluation;

procedure Check(const ACondition: Boolean; const AMessage: String);
begin
  if not ACondition then
  begin
    raise Exception.Create(AMessage);
  end;
end;

function Binding: TEvaluationBinding;
begin
  Result := Default(TEvaluationBinding);
  Result.SourceSha256 := StringOfChar('1', 64);
  Result.PreparationSha256 := StringOfChar('2', 64);
  Result.ReferenceSha256 := StringOfChar('3', 64);
  Result.AnnotationPolicySha256 := StringOfChar('4', 64);
  Result.ScoringPolicySha256 := StringOfChar('5', 64);
  Result.EstimatorSha256 := StringOfChar('6', 64);
  Result.GroupId := 'authored-reference';
  Result.SampleRate := 44100;
  Result.SourceFrames := 10000;
  Result.FirstFrame := 0;
  Result.EndFrame := 10000;
  Result.Partition := epEvaluation;
  Result.GroupVerified := True;
  Result.ReferenceComplete := True;
  Result.EstimatorTrainingOverlap := etoNotApplicable;
end;

procedure CheckBindings;
var
  LExpected: TEvaluationBinding;
  LActual: TEvaluationBinding;
  LRejected: Boolean;
  I: Integer;
begin
  LExpected := Binding;
  RequireSameEvaluationBinding(LExpected, LExpected);
  Check(IsIndependentEvaluation(LExpected), 'Untouched authored reference eligibility');
  LActual := LExpected;
  LActual.Partition := epDevelopment;
  LActual.PreviouslyUsedForTuning := True;
  Check(not IsIndependentEvaluation(LActual), 'Development never becomes independent acceptance');
  LActual := LExpected;
  LActual.ReferenceComplete := False;
  Check(not IsIndependentEvaluation(LActual), 'Incomplete references remain diagnostic');
  LActual := LExpected;
  LActual.EstimatorTrainingOverlap := etoUnknown;
  Check(not IsIndependentEvaluation(LActual), 'Unknown model overlap is not disjointness');
  LActual.EstimatorTrainingOverlap := etoOverlap;
  Check(not IsIndependentEvaluation(LActual), 'External training exposure prevents independent verdict');
  for I := 0 to 7 do
  begin
    LActual := LExpected;
    case I of
      0: LActual.PreviouslyUsedForTuning := True;
      1: LActual.SampleRate := 48000;
      2: LActual.ScoringPolicySha256 := StringOfChar('7', 64);
      3: LActual.ReferenceSha256 := '';
      4: LActual.PreparationSha256 := StringOfChar('8', 64);
      5: LActual.GroupVerified := False;
      6: LActual.EndFrame := LActual.SourceFrames + 1;
      7: LActual.AnnotationPolicySha256 := StringOfChar('9', 64);
    end;
    LRejected := False;
    try
      RequireSameEvaluationBinding(LExpected, LActual);
    except
      on EAudio do
      begin
        LRejected := True;
      end;
    end;
    Check(LRejected, 'Changed/missing/exposed evaluation binding accepted');
  end;
  Check((EvaluationToleranceFrames(44100, 5) = 221) and
    (EvaluationToleranceFrames(44100, 30) = 1323) and
    (EvaluationToleranceFrames(8000, 50) = 400), 'Exact positive-half timing rounding');
end;

function OrderedMaximum(const AReference, APrediction: TEvaluationFrames;
  const ATolerance: Int64): Integer;
var
  LTable: array[0..4, 0..4] of Integer;
  I: Integer;
  J: Integer;
begin
  FillChar(LTable, SizeOf(LTable), 0);
  for I := 1 to Length(AReference) do
  begin
    for J := 1 to Length(APrediction) do
    begin
      LTable[I, J] := Max(LTable[I - 1, J], LTable[I, J - 1]);
      if Abs(AReference[I - 1] - APrediction[J - 1]) <= ATolerance then
      begin
        LTable[I, J] := Max(LTable[I, J], LTable[I - 1, J - 1] + 1);
      end;
    end;
  end;
  Result := LTable[Length(AReference), Length(APrediction)];
end;

function EventSubset(const AMask, AOffset: Integer): TEvaluationFrames;
var
  I: Integer;
  LCount: Integer;
begin
  Result := nil;
  SetLength(Result, 4);
  LCount := 0;
  for I := 0 to 3 do
  begin
    if (AMask and (1 shl I)) <> 0 then
    begin
      Result[LCount] := 10 * I + AOffset;
      Inc(LCount);
    end;
  end;
  SetLength(Result, LCount);
end;

procedure CheckEvents;
var
  LReference: TEvaluationFrames;
  LPrediction: TEvaluationFrames;
  LResult: TEventEvaluation;
  LRejected: Boolean;
  I: Integer;
  J: Integer;
begin
  { One bounded independent cardinality audit; no audio/model experiment sweep. }
  for I := 0 to 15 do
  begin
    LReference := EventSubset(I, 1);
    for J := 0 to 15 do
    begin
      LPrediction := EventSubset(J, 2);
      LResult := EvaluateEvents(LReference, LPrediction, 0, 40, 11);
      Check(LResult.Matches = OrderedMaximum(LReference, LPrediction, 11),
        'Greedy timing count differs from independent dynamic program');
    end;
  end;
  LReference := EventSubset(15, 1);
  LPrediction := EventSubset(7, 2);
  LResult := EvaluateEvents(LReference, LPrediction, 0, 40, 1);
  Check((LResult.Matches = 3) and (LResult.Misses = 1) and
    (LResult.Extras = 0) and (LResult.AbsoluteErrorFrames = 3) and
    (Abs(LResult.F1 - Double(6 / 7)) < 1E-12), 'Independent event counts and ratio');
  LPrediction[1] := LPrediction[0];
  LRejected := False;
  try
    LResult := EvaluateEvents(LReference, LPrediction, 0, 40, 1);
  except
    on EAudio do
    begin
      LRejected := True;
    end;
  end;
  Check(LRejected, 'Duplicate predictions must not multiply matches');
  LPrediction := EventSubset(15, 2);
  LPrediction[3] := 40;
  LRejected := False;
  try
    LResult := EvaluateEvents(LReference, LPrediction, 0, 40, 1);
  except
    on EAudio do
    begin
      LRejected := True;
    end;
  end;
  Check(LRejected, 'Half-open scope must not silently crop an extra endpoint');
end;

procedure CheckCells;
var
  LReference: TEvaluationCells;
  LPrediction: TEvaluationCells;
  LResult: TCellEvaluation;
  LRejected: Boolean;
  I: Integer;
begin
  SetLength(LReference, 9);
  SetLength(LPrediction, 9);
  for I := 0 to High(LReference) do
  begin
    LReference[I].Frame := I * 10;
    LReference[I].State := esValue;
    LReference[I].LabelValue := 60 + I;
    LPrediction[I] := LReference[I];
  end;
  LPrediction[1].LabelValue := 73;
  LPrediction[2].State := esUnsupported;
  LReference[3].State := esRest;
  LReference[4].State := esAmbiguous;
  LReference[5].State := esUnknown;
  LPrediction[5].State := esRest;
  LPrediction[6].State := esRest;
  LReference[7].State := esRest;
  LPrediction[7].State := esUnknown;
  LReference[8].State := esRest;
  LPrediction[8].State := esRest;
  LResult := EvaluateCells(LReference, LPrediction, 0, 90, emLabel);
  Check((LResult.ReferenceActive = 4) and (LResult.ReferenceRest = 3) and
    (LResult.ReferenceAmbiguous = 1) and (LResult.ReferenceUnknown = 1) and
    (LResult.Correct = 1) and (LResult.Wrong = 1) and
    (LResult.UnknownActive = 2) and (LResult.RestInActive = 1) and
    (LResult.FalseValueInRest = 1) and (LResult.AdmittedUnscorable = 1) and
    (LResult.RestInRest = 1) and (LResult.UnknownRest = 1) and
    (LResult.Coverage = 0.25) and (Abs(LResult.Precision - Double(1 / 3)) < 1E-12),
    'Wrong, unsupported prediction, unknown, rest and ambiguous reference accounting');
  Inc(LPrediction[0].Frame);
  LRejected := False;
  try
    LResult := EvaluateCells(LReference, LPrediction, 0, 90, emLabel);
  except
    on EAudio do
    begin
      LRejected := True;
    end;
  end;
  Check(LRejected, 'Misaligned centers must not be scored');
  SetLength(LReference, 3);
  SetLength(LPrediction, 3);
  for I := 0 to 2 do
  begin
    LReference[I].State := esValue;
    LReference[I].ScalarValue := I;
    LPrediction[I] := LReference[I];
  end;
  LPrediction[0].ScalarValue := 0.25;
  LPrediction[1].ScalarValue := 1.5;
  LPrediction[2].State := esUnknown;
  LResult := EvaluateCells(LReference, LPrediction, 0, 90, emScalar, 0.25);
  Check((LResult.Correct = 1) and (LResult.Wrong = 1) and
    (LResult.UnknownActive = 1) and (LResult.ScalarCompared = 2) and
    (LResult.AbsoluteErrorSum = 0.75) and (LResult.MaximumAbsoluteError = 0.5),
    'Scalar error cannot hide unavailable or inaccurate observations');
end;

begin
  CheckBindings;
  CheckEvents;
  CheckCells;
  WriteLn('Evaluation: identity/exposure, event matching, cells and clock boundaries pass');
end.
