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
unit pythian.tools.evaluate;

{$mode delphi}
{$H+}

interface

{ Native file boundary. Returns a complete JSON report only after all identities,
  clocks, exposure declarations and scoring inputs validate. Paths in the case
  are relative to that case. Does not run inference or write/modify input files. }
function EvaluateCaseFile(const APath: String): UTF8String;

implementation

uses
  Classes, SysUtils, Math, fpjson, jsonparser, jsonscanner,
  pythian.audio, pythian.hash, pythian.wave.read, pythian.evaluation,
  pythian.pitch.evaluate,
  pythian.tools.files;

const
  MaximumDocumentBytes = 8 * 1024 * 1024;
  MaximumSourceBytes: Int64 = 1024 * 1024 * 1024;
  { Match parsed Double thresholds on targets with Extended real constants. }
  MinimumPhraseCoverage: Double = 0.80;
  MinimumPhrasePrecision: Double = 0.98;
  MinimumPhraseOnsetF1: Double = 0.80;
  MinimumPhraseNoteF1: Double = 0.70;

procedure Require(const ACondition: Boolean; const AMessage: String);
begin
  if not ACondition then
  begin
    raise EAudio.Create(AMessage);
  end;
end;

function Item(const AObject: TJSONObject; const AName: String;
  const AType: TJSONType): TJSONData;
begin
  Result := AObject.Find(AName);
  Require((Result <> nil), 'Missing evaluation field: ' + AName);
  Require(Result.JSONType = AType, 'Invalid evaluation field type: ' + AName);
end;

procedure Fields(const AObject: TJSONObject; const ANames: String);
var
  LNames: TStringList;
  I: Integer;
begin
  LNames := TStringList.Create;
  try
    LNames.StrictDelimiter := True;
    LNames.Delimiter := ',';
    LNames.DelimitedText := ANames;
    Require(AObject.Count = LNames.Count, 'Unexpected evaluation object fields');
    for I := 0 to LNames.Count - 1 do
    begin
      Require(AObject.Find(LNames[I]) <> nil, 'Missing evaluation field: ' + LNames[I]);
    end;
  finally
    LNames.Free;
  end;
end;

function TextField(const AObject: TJSONObject; const AName: String): String;
begin
  Result := Item(AObject, AName, jtString).AsString;
end;

function IntValue(const AData: TJSONData): Int64;
begin
  Require(AData.JSONType = jtNumber, 'Evaluation requires an integer');
  Require(TryStrToInt64(AData.AsJSON, Result), 'Evaluation requires an exact integer');
end;

function IntField(const AObject: TJSONObject; const AName: String): Int64;
begin
  Result := IntValue(Item(AObject, AName, jtNumber));
end;

function BoolField(const AObject: TJSONObject; const AName: String): Boolean;
begin
  Result := Item(AObject, AName, jtBoolean).AsBoolean;
end;

function NumberField(const AObject: TJSONObject; const AName: String): Double;
begin
  Result := Item(AObject, AName, jtNumber).AsFloat;
  Require(not IsNan(Result) and not IsInfinite(Result), 'Nonfinite evaluation number');
end;

function ObjectAt(const AArray: TJSONArray; const AIndex: Integer): TJSONObject;
begin
  Require(AArray.Items[AIndex].JSONType = jtObject, 'Expected evaluation object');
  Result := TJSONObject(AArray.Items[AIndex]);
end;

function ParseObject(const ABytes: TAudioBytes): TJSONObject;
var
  LText: UTF8String;
  LParser: TJSONParser;
  LData: TJSONData;
  LDepth: Integer;
  LQuoted: Boolean;
  LEscaped: Boolean;
  I: Integer;
begin
  { Bound nesting before the recursive JSON parser. Syntax remains its job. }
  LDepth := 0;
  LQuoted := False;
  LEscaped := False;
  for I := 0 to Length(ABytes) - 1 do
  begin
    if LQuoted then
    begin
      if LEscaped then
      begin
        LEscaped := False;
      end
      else if ABytes[I] = 92 then
      begin
        LEscaped := True;
      end
      else if ABytes[I] = 34 then
      begin
        LQuoted := False;
      end;
    end
    else if ABytes[I] = 34 then
    begin
      LQuoted := True;
    end
    else if ABytes[I] in [91, 123] then
    begin
      Inc(LDepth);
      Require(LDepth <= 16, 'Evaluation JSON nesting exceeds budget');
    end
    else if ABytes[I] in [93, 125] then
    begin
      Dec(LDepth);
    end;
  end;
  LText := '';
  if Length(ABytes) > 0 then
  begin
    SetString(LText, PAnsiChar(@ABytes[0]), Length(ABytes));
  end;
  LParser := TJSONParser.Create(LText, [joUTF8, joStrict]);
  try
    LData := LParser.Parse;
    try
      Require((LData <> nil) and (LData.JSONType = jtObject),
        'Evaluation JSON root must be an object');
      Result := TJSONObject(LData);
      LData := nil;
    finally
      LData.Free;
    end;
  finally
    LParser.Free;
  end;
end;

function ReadObject(const APath, ADigest: String): TJSONObject;
var
  LBytes: TAudioBytes;
begin
  LBytes := ReadFileBytes(APath, MaximumDocumentBytes);
  Require(Length(LBytes) > 0, 'Empty evaluation document');
  Require(Sha256Bytes(LBytes) = ADigest, 'Evaluation document digest mismatch: ' +
    ExtractFileName(APath));
  Result := ParseObject(LBytes);
end;

function Partition(const AValue: String): TEvaluationPartition;
begin
  if AValue = 'training' then
  begin
    Result := epTraining;
  end
  else if AValue = 'development' then
  begin
    Result := epDevelopment;
  end
  else
  begin
    Require(AValue = 'evaluation', 'Unknown evaluation partition');
    Result := epEvaluation;
  end;
end;

function Overlap(const AValue: String): TEstimatorTrainingOverlap;
begin
  if AValue = 'unknown' then
  begin
    Result := etoUnknown;
  end
  else if AValue = 'not-applicable' then
  begin
    Result := etoNotApplicable;
  end
  else if AValue = 'disjoint' then
  begin
    Result := etoDisjoint;
  end
  else
  begin
    Require(AValue = 'overlap', 'Unknown estimator training overlap');
    Result := etoOverlap;
  end;
end;

function Binding(const AObject: TJSONObject): TEvaluationBinding;
var
  LRate: Int64;
begin
  Fields(AObject, 'source_sha256,preparation_sha256,reference_sha256,' +
    'annotation_policy_sha256,scoring_policy_sha256,estimator_sha256,group_id,' +
    'sample_rate,source_frames,first_frame,end_frame,partition,group_verified,' +
    'previously_used_for_tuning,reference_complete,estimator_training_overlap');
  Result := Default(TEvaluationBinding);
  Result.SourceSha256 := TextField(AObject, 'source_sha256');
  Result.PreparationSha256 := TextField(AObject, 'preparation_sha256');
  Result.ReferenceSha256 := TextField(AObject, 'reference_sha256');
  Result.AnnotationPolicySha256 := TextField(AObject, 'annotation_policy_sha256');
  Result.ScoringPolicySha256 := TextField(AObject, 'scoring_policy_sha256');
  Result.EstimatorSha256 := TextField(AObject, 'estimator_sha256');
  Result.GroupId := TextField(AObject, 'group_id');
  LRate := IntField(AObject, 'sample_rate');
  Require((LRate >= 1) and (LRate <= High(Integer)), 'Invalid evaluation rate');
  Result.SampleRate := LRate;
  Result.SourceFrames := IntField(AObject, 'source_frames');
  Result.FirstFrame := IntField(AObject, 'first_frame');
  Result.EndFrame := IntField(AObject, 'end_frame');
  Result.Partition := Partition(TextField(AObject, 'partition'));
  Result.GroupVerified := BoolField(AObject, 'group_verified');
  Result.PreviouslyUsedForTuning := BoolField(AObject, 'previously_used_for_tuning');
  Result.ReferenceComplete := BoolField(AObject, 'reference_complete');
  Result.EstimatorTrainingOverlap := Overlap(TextField(AObject, 'estimator_training_overlap'));
  ValidateEvaluationBinding(Result);
end;

function FilePath(const ABase: String; const AFiles: TJSONObject;
  const AName: String): String;
var
  LName: String;
begin
  LName := TextField(AFiles, AName);
  Require((LName <> '') and (Pos(#0, LName) = 0), 'Empty/invalid evaluation asset path');
  if (ExtractFileDrive(LName) <> '') or (LName[1] in ['/', '\']) then
  begin
    Result := ExpandFileName(LName);
  end
  else
  begin
    Result := ExpandFileName(ABase + LName);
  end;
end;

procedure VerifyDocument(const APath, ADigest: String);
var
  LBytes: TAudioBytes;
begin
  LBytes := ReadFileBytes(APath, MaximumDocumentBytes);
  Require((Length(LBytes) > 0) and (Sha256Bytes(LBytes) = ADigest),
    'Evaluation evidence missing or changed: ' + ExtractFileName(APath));
end;

procedure CheckLedger(const ALedger: TJSONObject; const ABinding: TEvaluationBinding);
var
  LGroups: TJSONArray;
  LEstimators: TJSONArray;
  LSources: TJSONArray;
  LRow: TJSONObject;
  LGroupCount: Integer;
  LEstimatorCount: Integer;
  LFoundSource: Boolean;
  I: Integer;
  J: Integer;
begin
  Fields(ALedger, 'format,groups,estimators');
  Require(TextField(ALedger, 'format') = 'pythian-evaluation-ledger',
    'Unexpected evaluation ledger format');
  LGroups := TJSONArray(Item(ALedger, 'groups', jtArray));
  LEstimators := TJSONArray(Item(ALedger, 'estimators', jtArray));
  Require((LGroups.Count <= 4096) and (LEstimators.Count <= 4096),
    'Evaluation ledger exceeds entry budget');
  LGroupCount := 0;
  LEstimatorCount := 0;
  for I := 0 to LGroups.Count - 1 do
  begin
    LRow := ObjectAt(LGroups, I);
    Fields(LRow, 'group_id,group_verified,previously_used_for_tuning,partition,sources');
    LSources := TJSONArray(Item(LRow, 'sources', jtArray));
    LFoundSource := False;
    for J := 0 to LSources.Count - 1 do
    begin
      Require(LSources.Items[J].JSONType = jtString, 'Ledger source must be a hash');
      if LSources.Strings[J] = ABinding.SourceSha256 then
      begin
        Require(not LFoundSource, 'Duplicate source in evaluation ledger');
        LFoundSource := True;
      end;
    end;
    if TextField(LRow, 'group_id') = ABinding.GroupId then
    begin
      Inc(LGroupCount);
      Require(LFoundSource, 'Source absent from declared evaluation family');
      Require((BoolField(LRow, 'group_verified') = ABinding.GroupVerified) and
        (BoolField(LRow, 'previously_used_for_tuning') = ABinding.PreviouslyUsedForTuning) and
        (Partition(TextField(LRow, 'partition')) = ABinding.Partition),
        'Evaluation family exposure or partition differs from ledger');
    end
    else
    begin
      Require(not LFoundSource, 'Evaluation source belongs to another family');
    end;
  end;
  for I := 0 to LEstimators.Count - 1 do
  begin
    LRow := ObjectAt(LEstimators, I);
    Fields(LRow, 'estimator_sha256,training_overlap');
    if TextField(LRow, 'estimator_sha256') = ABinding.EstimatorSha256 then
    begin
      Inc(LEstimatorCount);
      Require(Overlap(TextField(LRow, 'training_overlap')) =
        ABinding.EstimatorTrainingOverlap, 'Estimator exposure differs from ledger');
    end;
  end;
  Require((LGroupCount = 1) and (LEstimatorCount = 1),
    'Evaluation requires unique ledger family and estimator entries');
end;

procedure CheckClock(const AObject: TJSONObject; const ABinding: TEvaluationBinding;
  const AReference: Boolean);
var
  LClock: TJSONObject;
begin
  LClock := TJSONObject(Item(AObject, 'clock', jtObject));
  Fields(LClock, 'source_sha256,preparation_sha256,scoring_policy_sha256,' +
    'sample_rate,source_frames,first_frame,end_frame');
  Require((TextField(LClock, 'source_sha256') = ABinding.SourceSha256) and
    (TextField(LClock, 'preparation_sha256') = ABinding.PreparationSha256) and
    (TextField(LClock, 'scoring_policy_sha256') = ABinding.ScoringPolicySha256) and
    (IntField(LClock, 'sample_rate') = ABinding.SampleRate) and
    (IntField(LClock, 'source_frames') = ABinding.SourceFrames) and
    (IntField(LClock, 'first_frame') = ABinding.FirstFrame) and
    (IntField(LClock, 'end_frame') = ABinding.EndFrame),
    'Reference/prediction clock or policy differs from case');
  if AReference then
  begin
    Require(TextField(AObject, 'annotation_policy_sha256') = ABinding.AnnotationPolicySha256,
      'Reference annotation policy differs');
  end
  else
  begin
    Require(TextField(AObject, 'estimator_sha256') = ABinding.EstimatorSha256,
      'Prediction estimator differs');
  end;
end;

function Cells(const AArray: TJSONArray; const AMetric: String;
  const AVocabularyCount: Integer): TEvaluationCells;
var
  LRow: TJSONObject;
  LState: String;
  LValue: Int64;
  I: Integer;
begin
  Require(AArray.Count <= MaximumEvaluationItems, 'Evaluation cell budget exceeded');
  Result := nil;
  SetLength(Result, AArray.Count);
  for I := 0 to AArray.Count - 1 do
  begin
    LRow := ObjectAt(AArray, I);
    LState := TextField(LRow, 'state');
    Result[I].Frame := IntField(LRow, 'frame');
    if LState = 'value' then
    begin
      Fields(LRow, 'frame,state,value');
      Result[I].State := esValue;
      if (AMetric = 'label') or (AMetric = 'notes') then
      begin
        LValue := IntField(LRow, 'value');
        Require((LValue >= 0) and (LValue < AVocabularyCount),
          'Evaluation label outside frozen vocabulary');
        Result[I].LabelValue := LValue;
      end
      else
      begin
        Result[I].ScalarValue := NumberField(LRow, 'value');
      end;
    end
    else
    begin
      Fields(LRow, 'frame,state');
      if LState = 'rest' then
      begin
        Result[I].State := esRest;
      end
      else if LState = 'unknown' then
      begin
        Result[I].State := esUnknown;
      end
      else if LState = 'ambiguous' then
      begin
        Result[I].State := esAmbiguous;
      end
      else
      begin
        Require(LState = 'unsupported', 'Unknown evaluation cell state');
        Result[I].State := esUnsupported;
      end;
    end;
  end;
end;

function Events(const AArray: TJSONArray): TEvaluationFrames;
var
  I: Integer;
begin
  Require(AArray.Count <= MaximumEvaluationItems, 'Evaluation event budget exceeded');
  Result := nil;
  SetLength(Result, AArray.Count);
  for I := 0 to AArray.Count - 1 do
  begin
    Result[I] := IntValue(AArray.Items[I]);
  end;
end;

function Ratio(const AObject: TJSONObject; const AName: String): Double;
begin
  Result := NumberField(AObject, AName);
  Require((Result >= 0) and (Result <= 1), 'Evaluation threshold outside [0,1]');
end;

function Notes(const AArray: TJSONArray; const AReference: Boolean;
  const ASourceFrames: Int64): TPitchReferenceNotes;
var
  LRow: TJSONObject;
  LNote: Int64;
  I: Integer;
begin
  Require(AArray.Count <= MaximumPitchReferenceNotes, 'Evaluation note budget exceeded');
  Result := nil;
  SetLength(Result, AArray.Count);
  for I := 0 to AArray.Count - 1 do
  begin
    LRow := ObjectAt(AArray, I);
    Fields(LRow, 'start_frame,end_frame,note');
    LNote := IntField(LRow, 'note');
    Require((LNote >= 0) and (LNote <= 127), 'Evaluation note outside MIDI range');
    Result[I].Note := LNote;
    Result[I].StartFrame := IntField(LRow, 'start_frame');
    Result[I].EndFrame := IntField(LRow, 'end_frame');
    Require(Result[I].EndFrame <= ASourceFrames, 'Evaluation note exceeds source clock');
    if (I > 0) and not AReference then
    begin
      Require(Result[I].StartFrame >= Result[I - 1].EndFrame,
        'Note evaluation requires separately attributed nonoverlapping predictions');
    end;
  end;
end;

procedure CheckNoteCells(const ACells: TEvaluationCells; const ANotes: TPitchReferenceNotes;
  const AReference: Boolean);
var
  LMatches: Integer;
  LNote: Integer;
  I: Integer;
  J: Integer;
begin
  Require(Int64(Length(ACells)) * Length(ANotes) <= MaximumPitchEvaluationPairs,
    'Note/cell consistency check exceeds work budget');
  for I := 0 to High(ACells) do
  begin
    LMatches := 0;
    LNote := -1;
    for J := 0 to High(ANotes) do
    begin
      if (ACells[I].Frame >= ANotes[J].StartFrame) and
        (ACells[I].Frame < ANotes[J].EndFrame) then
      begin
        Inc(LMatches);
        LNote := ANotes[J].Note;
      end;
    end;
    if LMatches = 1 then
    begin
      Require((ACells[I].State = esValue) and (ACells[I].LabelValue = LNote),
        'Evaluation note intervals disagree with observed pitch cells');
    end
    else if LMatches > 1 then
    begin
      Require(AReference and (ACells[I].State = esAmbiguous),
        'Overlapping reference notes must remain ambiguous');
    end
    else
    begin
      Require(ACells[I].State in [esRest, esUnknown, esUnsupported],
        'Evaluation cell has no corresponding note interval');
      if AReference then
      begin
        Require(ACells[I].State = esRest, 'Unannotated note cells cannot imply reference rests');
      end;
    end;
  end;
end;

function Score(const AReference, APrediction, APolicy: TJSONObject;
  const ABinding: TEvaluationBinding; out APass: Boolean): TJSONObject;
var
  LMetric: String;
  LVocabulary: TJSONArray;
  LLabels: TStringList;
  LMinimumCoverage: Double;
  LMinimumPrecision: Double;
  LMinimumF1: Double;
  LMinimumReference: Double;
  LScalarTolerance: Double;
  LTolerance: Int64;
  LCells: TCellEvaluation;
  LEvents: TEventEvaluation;
  LCellMetric: TEvaluationMetric;
  LReferenceCells: TEvaluationCells;
  LPredictionCells: TEvaluationCells;
  LReferenceNotes: TPitchReferenceNotes;
  LPredictionNotes: TPitchReferenceNotes;
  LNoteOptions: TPitchEvaluationOptions;
  LNoteScore: TPitchNoteEvaluation;
  LOnsetF1: Double;
  LNoteF1: Double;
  I: Integer;
begin
  Fields(APolicy, 'metric,unit,vocabulary,tolerance_frames,scalar_tolerance,' +
    'minimum_coverage,minimum_precision,minimum_f1,minimum_reference_coverage');
  LMetric := TextField(APolicy, 'metric');
  Require((LMetric = 'label') or (LMetric = 'scalar') or (LMetric = 'events') or
    (LMetric = 'notes'),
    'Unsupported evaluation metric');
  Require(Trim(TextField(APolicy, 'unit')) <> '', 'Evaluation policy needs a unit/meaning');
  LMinimumCoverage := Ratio(APolicy, 'minimum_coverage');
  LMinimumPrecision := Ratio(APolicy, 'minimum_precision');
  LMinimumF1 := Ratio(APolicy, 'minimum_f1');
  LMinimumReference := Ratio(APolicy, 'minimum_reference_coverage');
  Require((LMinimumCoverage > 0) and (LMinimumPrecision > 0) and
    (LMinimumReference > 0) and ((LMetric <> 'events') or (LMinimumF1 > 0)),
    'Evaluation admission thresholds must require positive evidence');
  LTolerance := IntField(APolicy, 'tolerance_frames');
  LScalarTolerance := NumberField(APolicy, 'scalar_tolerance');
  Require((LTolerance >= 0) and (LTolerance <= MaximumEvaluationTolerance) and
    (LScalarTolerance >= 0), 'Invalid evaluation tolerance');
  LVocabulary := TJSONArray(Item(APolicy, 'vocabulary', jtArray));
  LLabels := TStringList.Create;
  try
    LLabels.Sorted := True;
    LLabels.CaseSensitive := True;
    for I := 0 to LVocabulary.Count - 1 do
    begin
      Require(LVocabulary.Items[I].JSONType = jtString, 'Vocabulary labels must be strings');
      Require((Trim(LVocabulary.Strings[I]) <> '') and
        (LLabels.IndexOf(LVocabulary.Strings[I]) < 0), 'Empty/duplicate vocabulary label');
      LLabels.Add(LVocabulary.Strings[I]);
    end;
  finally
    LLabels.Free;
  end;
  Require((((LMetric = 'label') or (LMetric = 'notes')) and (LVocabulary.Count > 0)) or
    (((LMetric = 'scalar') or (LMetric = 'events')) and (LVocabulary.Count = 0)),
    'Metric/vocabulary mismatch');
  Require((LMetric = 'events') or (LMetric = 'notes') or
    ((LTolerance = 0) and (LMinimumF1 = 0)),
    'Non-event policy has event thresholds');
  Require((LMetric = 'scalar') or (LScalarTolerance = 0),
    'Non-scalar policy has scalar tolerance');
  if LMetric = 'notes' then
  begin
    Require((LMinimumCoverage >= MinimumPhraseCoverage) and
      (LMinimumPrecision >= MinimumPhrasePrecision) and
      (LMinimumF1 >= MinimumPhraseNoteF1) and (LMinimumReference = 1) and (LTolerance = 0),
      'Note evaluation must preserve phrase gates and complete reference coverage');
    Require((TextField(APolicy, 'unit') = 'absolute-MIDI-semitone') and
      (LVocabulary.Count = 128), 'Note evaluation needs the complete MIDI vocabulary');
    for I := 0 to 127 do
    begin
      Require(LVocabulary.Strings[I] = 'midi-' + IntToStr(I), 'MIDI vocabulary order differs');
    end;
    Fields(AReference, 'format,clock,annotation_policy_sha256,observations,notes');
    Fields(APrediction, 'format,clock,estimator_sha256,observations,notes');
  end
  else
  begin
    Fields(AReference, 'format,clock,annotation_policy_sha256,observations');
    Fields(APrediction, 'format,clock,estimator_sha256,observations');
  end;
  Require(TextField(AReference, 'format') = 'pythian-evaluation-reference',
    'Unexpected reference format');
  Require(TextField(APrediction, 'format') = 'pythian-evaluation-prediction',
    'Unexpected prediction format');
  CheckClock(AReference, ABinding, True);
  CheckClock(APrediction, ABinding, False);
  Result := TJSONObject.Create;
  try
    if LMetric = 'events' then
    begin
      LEvents := EvaluateEvents(Events(TJSONArray(Item(AReference, 'observations', jtArray))),
        Events(TJSONArray(Item(APrediction, 'observations', jtArray))),
        ABinding.FirstFrame, ABinding.EndFrame, LTolerance);
      Result.Add('reference_count', LEvents.ReferenceCount);
      Result.Add('prediction_count', LEvents.PredictionCount);
      Result.Add('matches', LEvents.Matches);
      Result.Add('misses', LEvents.Misses);
      Result.Add('extras', LEvents.Extras);
      Result.Add('absolute_error_frames', LEvents.AbsoluteErrorFrames);
      Result.Add('recall', LEvents.Recall);
      Result.Add('precision', LEvents.Precision);
      Result.Add('f1', LEvents.F1);
      APass := (LEvents.ReferenceCount > 0) and
        (LEvents.Recall >= LMinimumCoverage) and (LEvents.Precision >= LMinimumPrecision) and
        (LEvents.F1 >= LMinimumF1);
    end
    else
    begin
      LCellMetric := emLabel;
      if LMetric = 'scalar' then
      begin
        LCellMetric := emScalar;
      end;
      LReferenceCells := Cells(TJSONArray(Item(AReference, 'observations', jtArray)),
        LMetric, LVocabulary.Count);
      LPredictionCells := Cells(TJSONArray(Item(APrediction, 'observations', jtArray)),
        LMetric, LVocabulary.Count);
      LCells := EvaluateCells(LReferenceCells, LPredictionCells,
        ABinding.FirstFrame, ABinding.EndFrame, LCellMetric, LScalarTolerance);
      Result.Add('cell_count', LCells.CellCount);
      Result.Add('reference_active', LCells.ReferenceActive);
      Result.Add('reference_rest', LCells.ReferenceRest);
      Result.Add('reference_unknown', LCells.ReferenceUnknown);
      Result.Add('reference_ambiguous', LCells.ReferenceAmbiguous);
      Result.Add('reference_unsupported', LCells.ReferenceUnsupported);
      Result.Add('correct', LCells.Correct);
      Result.Add('wrong', LCells.Wrong);
      Result.Add('unknown_active', LCells.UnknownActive);
      Result.Add('rest_in_active', LCells.RestInActive);
      Result.Add('false_value_in_rest', LCells.FalseValueInRest);
      Result.Add('no_value_in_rest', LCells.NoValueInRest);
      Result.Add('rest_in_rest', LCells.RestInRest);
      Result.Add('unknown_rest', LCells.UnknownRest);
      Result.Add('admitted_unscorable', LCells.AdmittedUnscorable);
      Result.Add('coverage', LCells.Coverage);
      Result.Add('precision', LCells.Precision);
      Result.Add('reference_coverage', LCells.ReferenceCoverage);
      Result.Add('scalar_compared', LCells.ScalarCompared);
      Result.Add('absolute_error_sum', LCells.AbsoluteErrorSum);
      Result.Add('maximum_absolute_error', LCells.MaximumAbsoluteError);
      APass := (LCells.ReferenceActive > 0) and (LCells.Coverage >= LMinimumCoverage) and
        (LCells.Precision >= LMinimumPrecision) and
        (LCells.ReferenceCoverage >= LMinimumReference);
      if LMetric = 'notes' then
      begin
        LReferenceNotes := Notes(TJSONArray(Item(AReference, 'notes', jtArray)),
          True, ABinding.SourceFrames);
        LPredictionNotes := Notes(TJSONArray(Item(APrediction, 'notes', jtArray)),
          False, ABinding.SourceFrames);
        LNoteOptions := DefaultPitchEvaluationOptions(ABinding.SampleRate);
        LNoteScore := EvaluatePitchNoteIntervals(LPredictionNotes, LReferenceNotes,
          ABinding.FirstFrame, ABinding.EndFrame, LNoteOptions);
        CheckNoteCells(LReferenceCells, LReferenceNotes, True);
        CheckNoteCells(LPredictionCells, LPredictionNotes, False);
        LOnsetF1 := NoteF1(LNoteScore.MatchedOnsets, LNoteScore.ReferenceNotes,
          LNoteScore.EstimatedNotes);
        LNoteF1 := NoteF1(LNoteScore.MatchedNotes, LNoteScore.ReferenceNotes,
          LNoteScore.EstimatedNotes);
        Result.Add('reference_notes', LNoteScore.ReferenceNotes);
        Result.Add('estimated_notes', LNoteScore.EstimatedNotes);
        Result.Add('matched_onsets', LNoteScore.MatchedOnsets);
        Result.Add('matched_notes', LNoteScore.MatchedNotes);
        Result.Add('onset_f1', LOnsetF1);
        Result.Add('full_note_f1', LNoteF1);
        Result.Add('matched_onset_error_frames', LNoteScore.MatchedOnsetErrorFrames);
        Result.Add('matched_offset_error_frames', LNoteScore.MatchedOffsetErrorFrames);
        Result.Add('onset_tolerance_frames', LNoteOptions.OnsetToleranceFrames);
        Result.Add('minimum_offset_tolerance_frames', LNoteOptions.MinimumOffsetToleranceFrames);
        Result.Add('offset_duration_fraction', LNoteOptions.OffsetDurationFraction);
        Result.Add('note_edge_frames', LNoteOptions.NoteEdgeFrames);
        Result.Add('minimum_onset_f1', MinimumPhraseOnsetF1);
        APass := APass and (LNoteScore.ReferenceNotes > 0) and
          (LOnsetF1 >= MinimumPhraseOnsetF1) and
          (LNoteF1 >= LMinimumF1);
      end;
    end;
    APass := APass and ABinding.ReferenceComplete;
  except
    Result.Free;
    raise;
  end;
end;

function EvaluateCaseFile(const APath: String): UTF8String;
var
  LCase: TJSONObject;
  LFiles: TJSONObject;
  LReference: TJSONObject;
  LPrediction: TJSONObject;
  LPolicy: TJSONObject;
  LLedger: TJSONObject;
  LReport: TJSONObject;
  LBinding: TEvaluationBinding;
  LSource: TFileStream;
  LReader: TWaveFrameReader;
  LCaseBytes: TAudioBytes;
  LSourceSize: Int64;
  LBase: String;
  LPass: Boolean;
  LIndependent: Boolean;
begin
  LCase := nil;
  LReference := nil;
  LPrediction := nil;
  LPolicy := nil;
  LLedger := nil;
  LReport := nil;
  LSource := nil;
  LReader := nil;
  try
    LCaseBytes := ReadFileBytes(APath, MaximumDocumentBytes);
    LCase := ParseObject(LCaseBytes);
    Fields(LCase, 'format,binding,files,prediction_sha256,ledger_sha256');
    Require(TextField(LCase, 'format') = 'pythian-evaluation-case',
      'Unexpected evaluation case format');
    LBinding := Binding(TJSONObject(Item(LCase, 'binding', jtObject)));
    LFiles := TJSONObject(Item(LCase, 'files', jtObject));
    Fields(LFiles, 'source,preparation,reference,annotation_policy,scoring_policy,' +
      'estimator,prediction,ledger');
    LBase := ExtractFilePath(ExpandFileName(APath));
    { Metadata stays in byte snapshots. Source stays open denying writes where
      supported, and is hashed again after scoring; concurrent mutation is unsupported. }
    VerifyDocument(FilePath(LBase, LFiles, 'preparation'), LBinding.PreparationSha256);
    VerifyDocument(FilePath(LBase, LFiles, 'annotation_policy'), LBinding.AnnotationPolicySha256);
    VerifyDocument(FilePath(LBase, LFiles, 'estimator'), LBinding.EstimatorSha256);
    LReference := ReadObject(FilePath(LBase, LFiles, 'reference'), LBinding.ReferenceSha256);
    LPrediction := ReadObject(FilePath(LBase, LFiles, 'prediction'),
      TextField(LCase, 'prediction_sha256'));
    LLedger := ReadObject(FilePath(LBase, LFiles, 'ledger'), TextField(LCase, 'ledger_sha256'));
    LPolicy := ReadObject(FilePath(LBase, LFiles, 'scoring_policy'), LBinding.ScoringPolicySha256);
    CheckLedger(LLedger, LBinding);
    LSource := TFileStream.Create(FilePath(LBase, LFiles, 'source'),
      fmOpenRead or fmShareDenyWrite);
    LSourceSize := LSource.Size;
    Require((LSourceSize >= 12) and (LSourceSize <= MaximumSourceBytes),
      'Evaluation WAV exceeds source budget');
    Require(Sha256Stream(LSource, LSourceSize) = LBinding.SourceSha256,
      'Evaluation WAV digest mismatch');
    LSource.Position := 0;
    LReader := TWaveFrameReader.Create(LSource);
    Require((LReader.SampleRate = LBinding.SampleRate) and
      (LReader.FrameCount = LBinding.SourceFrames), 'Evaluation WAV clock differs from case');
    LReport := TJSONObject.Create;
    LReport.Add('scores', Score(LReference, LPrediction, LPolicy, LBinding, LPass));
    LIndependent := IsIndependentEvaluation(LBinding);
    LSource.Position := 0;
    Require((LSource.Size = LSourceSize) and
      (Sha256Stream(LSource, LSourceSize) = LBinding.SourceSha256),
      'Evaluation WAV changed during scoring');
    LReport.Add('format', 'pythian-evaluation-report');
    LReport.Add('case_sha256', Sha256Bytes(LCaseBytes));
    LReport.Add('binding', LCase.Objects['binding'].Clone);
    LReport.Add('prediction_sha256', TextField(LCase, 'prediction_sha256'));
    LReport.Add('ledger_sha256', TextField(LCase, 'ledger_sha256'));
    LReport.Add('metric', TextField(LPolicy, 'metric'));
    LReport.Add('unit', TextField(LPolicy, 'unit'));
    LReport.Add('metrics_pass', LPass);
    LReport.Add('independent_eligible', LIndependent);
    LReport.Add('independent_case_pass', LPass and LIndependent);
    LReport.Add('scope', 'One declared comparison; no provider or style acceptance inferred');
    Result := LReport.FormatJSON;
  finally
    LReader.Free;
    LSource.Free;
    LReport.Free;
    LLedger.Free;
    LPolicy.Free;
    LPrediction.Free;
    LReference.Free;
    LCase.Free;
  end;
end;

end.
