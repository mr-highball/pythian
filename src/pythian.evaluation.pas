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
unit pythian.evaluation;

{$mode delphi}
{$H+}

interface

uses
  pythian.audio;

const
  MaximumEvaluationItems = 1048576;
  MaximumEvaluationFrame: Int64 = 9007199254740991;
  MaximumEvaluationTolerance = 1000000000;

type
  TEvaluationPartition = (epTraining, epDevelopment, epEvaluation);
  TEstimatorTrainingOverlap = (etoUnknown, etoNotApplicable, etoDisjoint, etoOverlap);
  { Hashes are caller-verified SHA256 identities, not authentication. Preparation
    identifies the exact decoding/resampling/channel policy even for identity
    preparation. Annotation policy identifies uncertainty/edge conventions.
    Scope is an absolute half-open interval on the declared prepared WAV clock. }
  TEvaluationBinding = record
    SourceSha256: String;
    PreparationSha256: String;
    ReferenceSha256: String;
    AnnotationPolicySha256: String;
    ScoringPolicySha256: String;
    EstimatorSha256: String;
    GroupId: UTF8String;
    SampleRate: Integer;
    SourceFrames: Int64;
    FirstFrame: Int64;
    EndFrame: Int64;
    Partition: TEvaluationPartition;
    GroupVerified: Boolean;
    PreviouslyUsedForTuning: Boolean;
    ReferenceComplete: Boolean;
    EstimatorTrainingOverlap: TEstimatorTrainingOverlap;
  end;

  TEvaluationFrames = array of Int64;
  TEventEvaluation = record
    ReferenceCount: Integer;
    PredictionCount: Integer;
    Matches: Integer;
    Misses: Integer;
    Extras: Integer;
    AbsoluteErrorFrames: Int64;
    Precision: Double;
    Recall: Double;
    F1: Double;
  end;

  TEvaluationState = (esValue, esRest, esUnknown, esAmbiguous, esUnsupported);
  TEvaluationCell = record
    Frame: Int64;
    State: TEvaluationState;
    LabelValue: Integer;
    ScalarValue: Double;
  end;
  TEvaluationCells = array of TEvaluationCell;
  TEvaluationMetric = (emLabel, emScalar);
  TCellEvaluation = record
    CellCount: Integer;
    ReferenceActive: Integer;
    ReferenceRest: Integer;
    ReferenceUnknown: Integer;
    ReferenceAmbiguous: Integer;
    ReferenceUnsupported: Integer;
    Correct: Integer;
    Wrong: Integer;
    UnknownActive: Integer;
    RestInActive: Integer;
    FalseValueInRest: Integer;
    NoValueInRest: Integer;
    RestInRest: Integer;
    UnknownRest: Integer;
    AdmittedUnscorable: Integer;
    ScalarCompared: Integer;
    AbsoluteErrorSum: Double;
    MaximumAbsoluteError: Double;
    Coverage: Double;
    Precision: Double;
    ReferenceCoverage: Double;
  end;

procedure ValidateEvaluationBinding(const ABinding: TEvaluationBinding);
{ Requires exact identity, scope, clock, split AND exposure declarations. Does not
  hash external assets or infer source families. Callers must consult the complete
  family/exposure/estimator ledger, including uses outside the current input plan. }
procedure RequireSameEvaluationBinding(const AExpected, AActual: TEvaluationBinding);
{ Development can be scored but never supplies independent acceptance.
  Unknown model-training overlap or incomplete references cannot grant it. }
function IsIndependentEvaluation(const ABinding: TEvaluationBinding): Boolean;
{ Nonnegative integer milliseconds, nearest frame, exact half ties round up. }
function EvaluationToleranceFrames(const ASampleRate, AMilliseconds: Integer): Int64;
{ Both arrays strictly increase, lie in [first,end), and include the WHOLE declared
  scope. No prediction-derived cropping. Greedy ordered one-to-one matching
  maximizes cardinality for unlabeled equal-tolerance events. Error belongs to
  that deterministic earliest match, not a minimum-error assignment.
  Empty references have zero recall/F1 and cannot establish positive coverage. }
function EvaluateEvents(const AReference, APrediction: TEvaluationFrames;
  const AFirstFrame, AEndFrame, AToleranceFrames: Int64): TEventEvaluation;
{ Explicitly aligned centers; missing estimates are represented as esUnknown,
  never deleted. Reference esValue means an annotated active value, including a
  value outside the estimator's supported range. Such predictions are unknown/
  unsupported and still count in coverage. Reference esUnsupported means the
  annotation itself is outside the scoring contract, reported separately.
  Label values must be nonnegative; vocabulary and scalar units belong to the
  bound scoring policy. Scalars compare using absolute tolerance, no confidence
  interpretation. Unknown/rest are distinct, even where neither admits a value. }
function EvaluateCells(const AReference, APrediction: TEvaluationCells;
  const AFirstFrame, AEndFrame: Int64; const AMetric: TEvaluationMetric;
  const AScalarTolerance: Double = 0): TCellEvaluation;

implementation

uses
  SysUtils,
  Math;

procedure ValidateScope(const AFirstFrame, AEndFrame: Int64);
begin
  if (AFirstFrame < 0) or (AEndFrame <= AFirstFrame) or
    (AEndFrame > MaximumEvaluationFrame) then
  begin
    raise EAudio.Create('Evaluation requires a bounded nonempty half-open frame scope');
  end;
end;

procedure RequireDigest(const ADigest: String);
var
  LIndex: Integer;
begin
  if Length(ADigest) <> 64 then
  begin
    raise EAudio.Create('Evaluation requires every source/reference/policy/estimator digest');
  end;
  for LIndex := 1 to Length(ADigest) do
  begin
    if not (ADigest[LIndex] in ['0'..'9', 'a'..'f']) then
    begin
      raise EAudio.Create('Evaluation digest must be lowercase SHA256');
    end;
  end;
end;

procedure ValidateEvaluationBinding(const ABinding: TEvaluationBinding);
begin
  ValidateAudioFormat(ABinding.SampleRate, 1);
  ValidateScope(ABinding.FirstFrame, ABinding.EndFrame);
  if (ABinding.SourceFrames < ABinding.EndFrame) or
    (ABinding.SourceFrames > MaximumEvaluationFrame) then
  begin
    raise EAudio.Create('Evaluation scope exceeds its source clock');
  end;
  RequireDigest(ABinding.SourceSha256);
  RequireDigest(ABinding.PreparationSha256);
  RequireDigest(ABinding.ReferenceSha256);
  RequireDigest(ABinding.AnnotationPolicySha256);
  RequireDigest(ABinding.ScoringPolicySha256);
  RequireDigest(ABinding.EstimatorSha256);
  if (Length(ABinding.GroupId) < 1) or (Length(ABinding.GroupId) > 256) or
    (Trim(ABinding.GroupId) <> ABinding.GroupId) then
  begin
    raise EAudio.Create('Evaluation requires a nonempty exact family identity');
  end;
  if not (ABinding.Partition in [epTraining, epDevelopment, epEvaluation]) or
    not (ABinding.EstimatorTrainingOverlap in
      [etoUnknown, etoNotApplicable, etoDisjoint, etoOverlap]) then
  begin
    raise EAudio.Create('Invalid evaluation partition or estimator exposure');
  end;
  if (not ABinding.GroupVerified and (ABinding.Partition <> epDevelopment)) or
    (ABinding.PreviouslyUsedForTuning and (ABinding.Partition = epEvaluation)) then
  begin
    raise EAudio.Create('Unknown or tuned-on family cannot be untouched evaluation');
  end;
end;

procedure RequireSameEvaluationBinding(const AExpected, AActual: TEvaluationBinding);
begin
  ValidateEvaluationBinding(AExpected);
  ValidateEvaluationBinding(AActual);
  if (AExpected.SourceSha256 <> AActual.SourceSha256) or
    (AExpected.PreparationSha256 <> AActual.PreparationSha256) or
    (AExpected.ReferenceSha256 <> AActual.ReferenceSha256) or
    (AExpected.AnnotationPolicySha256 <> AActual.AnnotationPolicySha256) or
    (AExpected.ScoringPolicySha256 <> AActual.ScoringPolicySha256) or
    (AExpected.EstimatorSha256 <> AActual.EstimatorSha256) or
    (AExpected.GroupId <> AActual.GroupId) or
    (AExpected.SampleRate <> AActual.SampleRate) or
    (AExpected.SourceFrames <> AActual.SourceFrames) or
    (AExpected.FirstFrame <> AActual.FirstFrame) or
    (AExpected.EndFrame <> AActual.EndFrame) or
    (AExpected.Partition <> AActual.Partition) or
    (AExpected.GroupVerified <> AActual.GroupVerified) or
    (AExpected.PreviouslyUsedForTuning <> AActual.PreviouslyUsedForTuning) or
    (AExpected.ReferenceComplete <> AActual.ReferenceComplete) or
    (AExpected.EstimatorTrainingOverlap <> AActual.EstimatorTrainingOverlap) then
  begin
    raise EAudio.Create('Evaluation evidence identity, clock, policy or exposure differs');
  end;
end;

function IsIndependentEvaluation(const ABinding: TEvaluationBinding): Boolean;
begin
  ValidateEvaluationBinding(ABinding);
  Result := (ABinding.Partition = epEvaluation) and ABinding.GroupVerified and
    not ABinding.PreviouslyUsedForTuning and ABinding.ReferenceComplete and
    (ABinding.EstimatorTrainingOverlap in [etoNotApplicable, etoDisjoint]);
end;

function EvaluationToleranceFrames(const ASampleRate, AMilliseconds: Integer): Int64;
begin
  ValidateAudioFormat(ASampleRate, 1);
  if (AMilliseconds < 0) or (AMilliseconds > 60000) then
  begin
    raise EAudio.Create('Evaluation timing tolerance must be 0..60000 milliseconds');
  end;
  Result := (Int64(ASampleRate) * AMilliseconds + 500) div 1000;
end;

procedure ValidateEvents(const AFrames: TEvaluationFrames;
  const AFirstFrame, AEndFrame: Int64);
var
  LIndex: Integer;
begin
  if Length(AFrames) > MaximumEvaluationItems then
  begin
    raise EAudio.Create('Evaluation event count exceeds budget');
  end;
  for LIndex := 0 to High(AFrames) do
  begin
    if (AFrames[LIndex] < AFirstFrame) or (AFrames[LIndex] >= AEndFrame) or
      ((LIndex > 0) and (AFrames[LIndex] <= AFrames[LIndex - 1])) then
    begin
      raise EAudio.Create('Evaluation events must strictly increase within the declared scope');
    end;
  end;
end;

function EvaluateEvents(const AReference, APrediction: TEvaluationFrames;
  const AFirstFrame, AEndFrame, AToleranceFrames: Int64): TEventEvaluation;
var
  LReference: Integer;
  LPrediction: Integer;
  LDifference: Int64;
begin
  ValidateScope(AFirstFrame, AEndFrame);
  if (AToleranceFrames < 0) or (AToleranceFrames > MaximumEvaluationTolerance) then
  begin
    raise EAudio.Create('Evaluation event tolerance exceeds budget');
  end;
  ValidateEvents(AReference, AFirstFrame, AEndFrame);
  ValidateEvents(APrediction, AFirstFrame, AEndFrame);
  Result := Default(TEventEvaluation);
  Result.ReferenceCount := Length(AReference);
  Result.PredictionCount := Length(APrediction);
  LReference := 0;
  LPrediction := 0;
  while (LReference < Length(AReference)) and (LPrediction < Length(APrediction)) do
  begin
    LDifference := APrediction[LPrediction] - AReference[LReference];
    if Abs(LDifference) <= AToleranceFrames then
    begin
      Inc(Result.Matches);
      Inc(Result.AbsoluteErrorFrames, Abs(LDifference));
      Inc(LReference);
      Inc(LPrediction);
    end
    else if LDifference < 0 then
    begin
      Inc(LPrediction);
    end
    else
    begin
      Inc(LReference);
    end;
  end;
  Result.Misses := Result.ReferenceCount - Result.Matches;
  Result.Extras := Result.PredictionCount - Result.Matches;
  if Result.ReferenceCount > 0 then
  begin
    Result.Recall := Result.Matches / Result.ReferenceCount;
  end;
  if Result.PredictionCount > 0 then
  begin
    Result.Precision := Result.Matches / Result.PredictionCount;
  end;
  if Result.ReferenceCount + Result.PredictionCount > 0 then
  begin
    Result.F1 := Result.Matches;
    Result.F1 := Result.F1 * 2 / (Result.ReferenceCount + Result.PredictionCount);
  end;
end;

procedure ValidateCell(const ACell: TEvaluationCell; const AMetric: TEvaluationMetric);
begin
  if not (ACell.State in [esValue, esRest, esUnknown, esAmbiguous, esUnsupported]) then
  begin
    raise EAudio.Create('Invalid evaluation cell state');
  end;
  if ACell.State <> esValue then
  begin
    Exit;
  end;
  if AMetric = emScalar then
  begin
    RequireFinite(ACell.ScalarValue, 'Evaluation scalar');
  end
  else if ACell.LabelValue < 0 then
  begin
    raise EAudio.Create('Evaluation labels must be nonnegative; use explicit unknown/rest states');
  end;
end;

function EvaluateCells(const AReference, APrediction: TEvaluationCells;
  const AFirstFrame, AEndFrame: Int64; const AMetric: TEvaluationMetric;
  const AScalarTolerance: Double): TCellEvaluation;
var
  LIndex: Integer;
  LReference: TEvaluationCell;
  LPrediction: TEvaluationCell;
  LCorrect: Boolean;
  LError: Double;
  LAdmitted: Integer;
begin
  ValidateScope(AFirstFrame, AEndFrame);
  RequireFinite(AScalarTolerance, 'Evaluation scalar tolerance');
  if not (AMetric in [emLabel, emScalar]) or (AScalarTolerance < 0) or
    ((AMetric = emLabel) and (AScalarTolerance <> 0)) then
  begin
    raise EAudio.Create('Invalid evaluation cell metric or tolerance');
  end;
  if (Length(AReference) <> Length(APrediction)) or
    (Length(AReference) > MaximumEvaluationItems) then
  begin
    raise EAudio.Create('Evaluation cells require a bounded common reference-center grid');
  end;
  Result := Default(TCellEvaluation);
  Result.CellCount := Length(AReference);
  for LIndex := 0 to High(AReference) do
  begin
    LReference := AReference[LIndex];
    LPrediction := APrediction[LIndex];
    if (LReference.Frame <> LPrediction.Frame) or (LReference.Frame < AFirstFrame) or
      (LReference.Frame >= AEndFrame) or
      ((LIndex > 0) and (LReference.Frame <= AReference[LIndex - 1].Frame)) then
    begin
      raise EAudio.Create('Evaluation cell clocks differ or exceed the declared scope');
    end;
    ValidateCell(LReference, AMetric);
    ValidateCell(LPrediction, AMetric);
    case LReference.State of
      esValue:
        begin
          Inc(Result.ReferenceActive);
          if LPrediction.State = esValue then
          begin
            if AMetric = emLabel then
            begin
              LCorrect := LReference.LabelValue = LPrediction.LabelValue;
            end
            else
            begin
              LError := Abs(LReference.ScalarValue - LPrediction.ScalarValue);
              RequireFinite(LError, 'Evaluation scalar error');
              Result.AbsoluteErrorSum := Result.AbsoluteErrorSum + LError;
              RequireFinite(Result.AbsoluteErrorSum, 'Evaluation scalar error sum');
              Result.MaximumAbsoluteError := Max(Result.MaximumAbsoluteError, LError);
              Inc(Result.ScalarCompared);
              LCorrect := LError <= AScalarTolerance;
            end;
            if LCorrect then
            begin
              Inc(Result.Correct);
            end
            else
            begin
              Inc(Result.Wrong);
            end;
          end
          else
          begin
            Inc(Result.UnknownActive);
            if LPrediction.State = esRest then
            begin
              Inc(Result.RestInActive);
            end;
          end;
        end;
      esRest:
        begin
          Inc(Result.ReferenceRest);
          if LPrediction.State = esValue then
          begin
            Inc(Result.FalseValueInRest);
          end
          else
          begin
            Inc(Result.NoValueInRest);
            if LPrediction.State = esRest then
            begin
              Inc(Result.RestInRest);
            end
            else
            begin
              Inc(Result.UnknownRest);
            end;
          end;
        end;
      esUnknown: Inc(Result.ReferenceUnknown);
      esAmbiguous: Inc(Result.ReferenceAmbiguous);
      esUnsupported: Inc(Result.ReferenceUnsupported);
    end;
    if (LReference.State in [esUnknown, esAmbiguous, esUnsupported]) and
      (LPrediction.State = esValue) then
    begin
      Inc(Result.AdmittedUnscorable);
    end;
  end;
  if Result.ReferenceActive > 0 then
  begin
    Result.Coverage := Result.Correct / Result.ReferenceActive;
  end;
  LAdmitted := Result.Correct + Result.Wrong + Result.FalseValueInRest;
  if LAdmitted > 0 then
  begin
    Result.Precision := Result.Correct / LAdmitted;
  end;
  if Result.CellCount > 0 then
  begin
    Result.ReferenceCoverage :=
      (Result.ReferenceActive + Result.ReferenceRest) / Result.CellCount;
  end;
end;

end.
