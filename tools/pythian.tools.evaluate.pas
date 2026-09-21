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
  pythian.pitch.evaluate, pythian.evaluation.parts,
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

procedure CheckDigest(const ADigest: String);
var
  I: Integer;
begin
  Require(Length(ADigest) = 64, 'Ledger identity requires lowercase SHA256');
  for I := 1 to Length(ADigest) do
  begin
    Require(ADigest[I] in ['0'..'9', 'a'..'f'],
      'Ledger identity requires lowercase SHA256');
  end;
end;

procedure CheckLedger(const ALedger: TJSONObject; const ABinding: TEvaluationBinding;
  const APredictionDigest: String; out APredictionAncestryReason: String);
type
  TAncestorNode = record
    Digest: String;
    GroupIndex: Integer;
    Parents: array of Integer;
    HasSource: Boolean;
    HasEvaluationSource: Boolean;
  end;
var
  LGroups: TJSONArray;
  LEstimators: TJSONArray;
  LSources: TJSONArray;
  LArtifacts: TJSONArray;
  LParents: TJSONArray;
  LRow: TJSONObject;
  LGroupIds: TStringList;
  LSourceIds: TStringList;
  LArtifactIds: TStringList;
  LEstimatorIds: TStringList;
  LNodes: array of TAncestorNode;
  LSelected: array of Boolean;
  LReferenceAncestors: array of Boolean;
  LSharedInputs: array of Boolean;
  LCandidate: TEvaluationBinding;
  LDigest: String;
  LGroupId: String;
  LGroupIndex: Integer;
  LIndex: Integer;
  LParentIndex: Integer;
  LEdgeCount: Integer;
  I: Integer;
  J: Integer;

  function NewIndex: TStringList;
  begin
    Result := TStringList.Create;
    Result.CaseSensitive := True;
    Result.Sorted := True;
  end;

  procedure AddIndex(const AIndex: TStringList; const AKey: String;
    const AValue: Integer);
  begin
    Require(AIndex.IndexOf(AKey) < 0, 'Duplicate evaluation ledger identity');
    AIndex.AddObject(AKey, TObject(PtrInt(AValue)));
  end;

  function FindIndex(const AIndex: TStringList; const AKey: String): Integer;
  var
    LPosition: Integer;
  begin
    LPosition := AIndex.IndexOf(AKey);
    Require(LPosition >= 0, 'Missing evaluation ledger ancestor or identity');
    Result := PtrInt(AIndex.Objects[LPosition]);
  end;

  procedure SelectAncestors(const ARoot: String);
  var
    LNode: Integer;
    LParent: Integer;
  begin
    for LNode := 0 to High(LSelected) do
    begin
      LSelected[LNode] := False;
    end;
    LSelected[FindIndex(LArtifactIds, ARoot)] := True;
    { Parent-before-child order bounds traversal and excludes cycles without
      recursion. Every selected ancestor is visited once per root. }
    for LNode := High(LNodes) downto 0 do
    begin
      if LSelected[LNode] then
      begin
        for LParent := 0 to High(LNodes[LNode].Parents) do
        begin
          LSelected[LNodes[LNode].Parents[LParent]] := True;
        end;
      end;
    end;
  end;

  procedure CheckSourceFamily(const ARoot: String);
  var
    LNode: Integer;
  begin
    SelectAncestors(ARoot);
    Require(LSelected[FindIndex(LArtifactIds, ABinding.SourceSha256)],
      'Preparation must bind the evaluated source');
    for LNode := 0 to High(LNodes) do
    begin
      if LSelected[LNode] and (LNodes[LNode].GroupIndex >= 0) then
      begin
        Require(LNodes[LNode].GroupIndex = LGroupIndex,
          'Prepared source ancestry crosses declared recording families');
      end;
    end;
  end;

  procedure AllowInputAncestors;
  var
    LNode: Integer;
  begin
    for LNode := 0 to High(LSelected) do
    begin
      { Exempt declared recording material, not arbitrary models/helpers hidden
        beneath preparation. Both reference and prediction see that closure. }
      LSharedInputs[LNode] := LSharedInputs[LNode] or
        (LSelected[LNode] and (LNodes[LNode].GroupIndex >= 0));
    end;
  end;

  procedure ExcludeIndependent(const AReason: String);
  begin
    if APredictionAncestryReason = '' then
    begin
      APredictionAncestryReason := AReason;
    end;
  end;

begin
  APredictionAncestryReason := '';
  CheckDigest(APredictionDigest);
  Fields(ALedger, 'format,groups,estimators,artifacts');
  Require(TextField(ALedger, 'format') = 'pythian-evaluation-ledger',
    'Unexpected evaluation ledger format');
  LGroups := TJSONArray(Item(ALedger, 'groups', jtArray));
  LEstimators := TJSONArray(Item(ALedger, 'estimators', jtArray));
  LArtifacts := TJSONArray(Item(ALedger, 'artifacts', jtArray));
  Require((LGroups.Count > 0) and (LGroups.Count <= 4096) and
    (LEstimators.Count > 0) and (LEstimators.Count <= 4096) and
    (LArtifacts.Count > 0) and (LArtifacts.Count <= 4096),
    'Evaluation ledger exceeds entry budget');
  LGroupIds := NewIndex;
  LSourceIds := NewIndex;
  LArtifactIds := NewIndex;
  LEstimatorIds := NewIndex;
  try
    for I := 0 to LGroups.Count - 1 do
    begin
      LRow := ObjectAt(LGroups, I);
      Fields(LRow, 'group_id,group_verified,previously_used_for_tuning,partition,sources');
      LCandidate := ABinding;
      LCandidate.GroupId := TextField(LRow, 'group_id');
      LCandidate.GroupVerified := BoolField(LRow, 'group_verified');
      LCandidate.PreviouslyUsedForTuning := BoolField(LRow, 'previously_used_for_tuning');
      LCandidate.Partition := Partition(TextField(LRow, 'partition'));
      ValidateEvaluationBinding(LCandidate);
      AddIndex(LGroupIds, LCandidate.GroupId, I);
      LSources := TJSONArray(Item(LRow, 'sources', jtArray));
      Require((LSources.Count > 0) and
        (LSourceIds.Count + LSources.Count <= 4096), 'Ledger source budget exceeded');
      for J := 0 to LSources.Count - 1 do
      begin
        Require(LSources.Items[J].JSONType = jtString, 'Ledger source must be a hash');
        CheckDigest(LSources.Strings[J]);
        AddIndex(LSourceIds, LSources.Strings[J], I);
      end;
    end;
    LGroupIndex := FindIndex(LGroupIds, ABinding.GroupId);
    Require(FindIndex(LSourceIds, ABinding.SourceSha256) = LGroupIndex,
      'Evaluation source belongs to another family');
    LRow := ObjectAt(LGroups, LGroupIndex);
    Require((BoolField(LRow, 'group_verified') = ABinding.GroupVerified) and
      (BoolField(LRow, 'previously_used_for_tuning') = ABinding.PreviouslyUsedForTuning) and
      (Partition(TextField(LRow, 'partition')) = ABinding.Partition),
      'Evaluation family exposure or partition differs from ledger');
    for I := 0 to LEstimators.Count - 1 do
    begin
      LRow := ObjectAt(LEstimators, I);
      Fields(LRow, 'estimator_sha256,training_overlap');
      LDigest := TextField(LRow, 'estimator_sha256');
      CheckDigest(LDigest);
      AddIndex(LEstimatorIds, LDigest, I);
      Overlap(TextField(LRow, 'training_overlap'));
    end;
    LRow := ObjectAt(LEstimators, FindIndex(LEstimatorIds, ABinding.EstimatorSha256));
    Require(Overlap(TextField(LRow, 'training_overlap')) =
      ABinding.EstimatorTrainingOverlap, 'Estimator exposure differs from ledger');
    SetLength(LNodes, LArtifacts.Count);
    SetLength(LSelected, LArtifacts.Count);
    SetLength(LSharedInputs, LArtifacts.Count);
    LEdgeCount := 0;
    for I := 0 to LArtifacts.Count - 1 do
    begin
      LRow := ObjectAt(LArtifacts, I);
      Fields(LRow, 'sha256,group_id,parents');
      LDigest := TextField(LRow, 'sha256');
      CheckDigest(LDigest);
      LNodes[I].Digest := LDigest;
      LGroupId := TextField(LRow, 'group_id');
      LNodes[I].GroupIndex := -1;
      if LGroupId <> '' then
      begin
        LNodes[I].GroupIndex := FindIndex(LGroupIds, LGroupId);
        Require(FindIndex(LSourceIds, LDigest) = LNodes[I].GroupIndex,
          'Artifact recording family differs from source registry');
      end
      else
      begin
        Require(LSourceIds.IndexOf(LDigest) < 0,
          'Recording artifact cannot hide its family');
      end;
      LNodes[I].HasSource := LNodes[I].GroupIndex >= 0;
      if LNodes[I].HasSource then
      begin
        LNodes[I].HasEvaluationSource := Partition(TextField(
          ObjectAt(LGroups, LNodes[I].GroupIndex), 'partition')) = epEvaluation;
      end;
      LParents := TJSONArray(Item(LRow, 'parents', jtArray));
      Inc(LEdgeCount, LParents.Count);
      Require(LEdgeCount <= 32768, 'Evaluation ancestry edge budget exceeded');
      SetLength(LNodes[I].Parents, LParents.Count);
      for J := 0 to LParents.Count - 1 do
      begin
        Require(LParents.Items[J].JSONType = jtString, 'Ancestor must be a digest');
        LParentIndex := FindIndex(LArtifactIds, LParents.Strings[J]);
        { Canonical parent order also rejects duplicate dependencies. }
        if J > 0 then
        begin
          Require(LParentIndex > LNodes[I].Parents[J - 1],
            'Artifact parents must be unique in ledger order');
        end;
        LNodes[I].Parents[J] := LParentIndex;
        LNodes[I].HasSource := LNodes[I].HasSource or LNodes[LParentIndex].HasSource;
        LNodes[I].HasEvaluationSource := LNodes[I].HasEvaluationSource or
          LNodes[LParentIndex].HasEvaluationSource;
      end;
      AddIndex(LArtifactIds, LDigest, I);
    end;
    for I := 0 to LSourceIds.Count - 1 do
    begin
      FindIndex(LArtifactIds, LSourceIds[I]);
    end;
    for I := 0 to LEstimatorIds.Count - 1 do
    begin
      LIndex := FindIndex(LArtifactIds, LEstimatorIds[I]);
      Require(LNodes[LIndex].GroupIndex < 0, 'Estimator cannot be a source recording');
    end;
    CheckSourceFamily(ABinding.SourceSha256);
    AllowInputAncestors;
    CheckSourceFamily(ABinding.PreparationSha256);
    AllowInputAncestors;
    LSharedInputs[FindIndex(LArtifactIds, ABinding.PreparationSha256)] := True;
    { Shared annotation conventions are not answer observations. Do not exempt
      their ancestors: a shared annotation model must remain detectable. }
    LSharedInputs[FindIndex(LArtifactIds, ABinding.AnnotationPolicySha256)] := True;
    SelectAncestors(ABinding.ReferenceSha256);
    LReferenceAncestors := Copy(LSelected);
    Require(LSelected[FindIndex(LArtifactIds, ABinding.SourceSha256)] and
      LSelected[FindIndex(LArtifactIds, ABinding.PreparationSha256)] and
      LSelected[FindIndex(LArtifactIds, ABinding.AnnotationPolicySha256)],
      'Reference ancestry must bind source, preparation and annotation policy');
    for I := 0 to High(LNodes) do
    begin
      if LSelected[I] then
      begin
        Require((LNodes[I].Digest <> ABinding.EstimatorSha256) and
          (LNodes[I].Digest <> APredictionDigest),
          'Reference ancestry includes the evaluated estimator or its prediction');
      end;
    end;
    SelectAncestors(ABinding.EstimatorSha256);
    for I := 0 to High(LNodes) do
    begin
      if LSelected[I] and (LNodes[I].GroupIndex >= 0) then
      begin
        LRow := ObjectAt(LGroups, LNodes[I].GroupIndex);
        Require(Partition(TextField(LRow, 'partition')) <> epEvaluation,
          'Estimator ancestry includes an evaluation recording family');
        Require(ABinding.EstimatorTrainingOverlap <> etoNotApplicable,
          'Data-derived estimator cannot declare training overlap not applicable');
      end;
    end;
    SelectAncestors(APredictionDigest);
    Require(LSelected[FindIndex(LArtifactIds, ABinding.SourceSha256)] and
      LSelected[FindIndex(LArtifactIds, ABinding.PreparationSha256)] and
      LSelected[FindIndex(LArtifactIds, ABinding.EstimatorSha256)],
      'Prediction ancestry must bind source, preparation and estimator');
    if LSelected[FindIndex(LArtifactIds, ABinding.ReferenceSha256)] then
    begin
      ExcludeIndependent('prediction-depends-on-reference');
    end;
    for I := 0 to High(LNodes) do
    begin
      if not LSelected[I] then
      begin
        Continue;
      end;
      if LReferenceAncestors[I] and not LSharedInputs[I] then
      begin
        ExcludeIndependent('prediction-shares-reference-ancestry');
      end;
      if (LNodes[I].GroupIndex >= 0) and not LSharedInputs[I] then
      begin
        LRow := ObjectAt(LGroups, LNodes[I].GroupIndex);
        if Partition(TextField(LRow, 'partition')) = epEvaluation then
        begin
          ExcludeIndependent('prediction-uses-additional-evaluation-source');
        end;
      end;
    end;
    { Include every declared estimator consumed by the prediction, even when
      reached through a helper or a renamed model variant. Parent summaries
      keep this linear in the bounded graph instead of retraversing each model. }
    for I := 0 to LEstimators.Count - 1 do
    begin
      LRow := ObjectAt(LEstimators, I);
      LIndex := FindIndex(LArtifactIds, TextField(LRow, 'estimator_sha256'));
      if not LSelected[LIndex] then
      begin
        Continue;
      end;
      if LNodes[LIndex].HasEvaluationSource then
      begin
        ExcludeIndependent('prediction-estimator-uses-evaluation-source');
      end;
      if Overlap(TextField(LRow, 'training_overlap')) in [etoUnknown, etoOverlap] then
      begin
        ExcludeIndependent('prediction-estimator-training-overlap');
      end;
      Require(not LNodes[LIndex].HasSource or
        (Overlap(TextField(LRow, 'training_overlap')) <> etoNotApplicable),
        'Data-derived estimator cannot declare training overlap not applicable');
    end;
  finally
    LEstimatorIds.Free;
    LArtifactIds.Free;
    LSourceIds.Free;
    LGroupIds.Free;
  end;
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

function CheckAnnotation(const AAnnotation, APolicy: TJSONObject;
  const ABinding: TEvaluationBinding): Boolean;
var
  LOutput: String;
  LInput: String;
  LMetric: String;
  LUnit: String;
  LMethod: String;
  LPurpose: String;
  LText: String;
  I: Integer;
begin
  Fields(AAnnotation, 'format,output,input_class,scope_id,purpose,reference_method,' +
    'label_convention,time_convention,uncertainty_convention');
  Require(TextField(AAnnotation, 'format') = 'pythian-evaluation-annotation',
    'Unexpected annotation contract format');
  for I := 0 to AAnnotation.Count - 1 do
  begin
    Require(AAnnotation.Items[I].JSONType = jtString, 'Annotation fields must be strings');
    LText := AAnnotation.Items[I].AsString;
    Require((Length(LText) <= 4096) and (Trim(LText) <> '') and
      (Pos(#0, LText) = 0), 'Annotation convention must be nonempty bounded text');
  end;
  Require(Length(TextField(AAnnotation, 'scope_id')) <= 256,
    'Annotation scope identifier exceeds budget');
  LMethod := TextField(AAnnotation, 'reference_method');
  Require((LMethod = 'authored') or (LMethod = 'independently-annotated') or
    (LMethod = 'independently-measured'), 'Unsupported reference method');
  LPurpose := TextField(AAnnotation, 'purpose');
  Require((LPurpose = 'primary') or (LPurpose = 'diagnostic'),
    'Unsupported comparison purpose');
  Result := LPurpose = 'primary';
  LOutput := TextField(AAnnotation, 'output');
  LInput := '';
  LMetric := '';
  LUnit := '';
  if LOutput = 'notes' then
  begin
    LInput := 'attributed-voice';
    LMetric := 'notes';
    LUnit := 'absolute-MIDI-semitone';
  end
  else if (LOutput = 'onsets') or (LOutput = 'beats') then
  begin
    LInput := 'annotated-recording';
    LMetric := 'events';
    LUnit := 'source-frame';
    if LOutput = 'beats' then
    begin
      if Result then
      begin
        Require(IntField(APolicy, 'tolerance_frames') =
          EvaluationToleranceFrames(ABinding.SampleRate, 30),
          'Primary beat comparison requires the fixed 30-ms tolerance');
      end
      else
      begin
        Require(IntField(APolicy, 'tolerance_frames') =
          EvaluationToleranceFrames(ABinding.SampleRate, 70),
          'Diagnostic beat comparison requires the separate 70-ms tolerance');
      end;
    end;
  end
  else if LOutput = 'tempo' then
  begin
    LInput := 'annotated-recording';
    LMetric := 'scalar';
    LUnit := 'microseconds-per-quarter';
  end
  else if LOutput = 'key' then
  begin
    LInput := 'tonal-region';
    LMetric := 'label';
    LUnit := 'key-root-mode';
  end
  else if LOutput = 'part-note-sets' then
  begin
    LInput := 'attributed-parts';
    LMetric := 'part-note-sets';
    LUnit := 'role-MIDI-sets';
    Require(not Result, 'Part-set centers are diagnostic; note timing acceptance remains separate');
  end
  else if LOutput = 'part-ownership' then
  begin
    LInput := 'attributed-part';
    LMetric := 'label';
    LUnit := 'part-note-identity';
  end
  else if (LOutput = 'harmony') or (LOutput = 'harmony-changes') then
  begin
    LInput := 'harmonic-region';
    if LOutput = 'harmony' then
    begin
      LMetric := 'label';
      LUnit := 'chord-identity';
    end
    else
    begin
      LMetric := 'events';
      LUnit := 'source-frame';
    end;
  end
  else if (LOutput = 'groove-events') or (LOutput = 'groove-accent') or
    (LOutput = 'groove-offset') then
  begin
    LInput := 'attributed-part';
    LMetric := 'scalar';
    LUnit := 'normalized-amplitude';
    if LOutput = 'groove-events' then
    begin
      LMetric := 'events';
      LUnit := 'source-frame';
    end
    else if LOutput = 'groove-offset' then
    begin
      LUnit := 'quarter-note-offset';
    end;
  end
  else if (LOutput = 'sound-spectrum') or (LOutput = 'sound-envelope') then
  begin
    LInput := 'recorded-sound';
    LMetric := 'scalar';
    LUnit := 'normalized-amplitude';
    if LOutput = 'sound-spectrum' then
    begin
      LUnit := 'normalized-band-energy';
    end;
  end
  else
  begin
    Require(False, 'Unsupported musical comparison output');
  end;
  Require((TextField(AAnnotation, 'input_class') = LInput) and
    (TextField(APolicy, 'metric') = LMetric) and (TextField(APolicy, 'unit') = LUnit),
    'Annotation input/output does not match the scoring metric and unit');
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

procedure CheckScalarUnits(const ACells: TEvaluationCells; const AUnit: String);
var
  I: Integer;
begin
  for I := 0 to High(ACells) do
  begin
    if ACells[I].State <> esValue then
    begin
      Continue;
    end;
    if (AUnit = 'normalized-amplitude') or (AUnit = 'normalized-band-energy') then
    begin
      Require((ACells[I].ScalarValue >= 0) and (ACells[I].ScalarValue <= 1),
        'Normalized comparison value outside [0,1]');
    end
    else if AUnit = 'microseconds-per-quarter' then
    begin
      Require(ACells[I].ScalarValue > 0, 'Tempo comparison requires positive quarter duration');
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

function PartPitches(const AArray: TJSONArray): TPartPitchSet;
var
  LNote: Int64;
  I: Integer;
begin
  Require(AArray.Count <= 128, 'Part pitch set exceeds MIDI range');
  Result := nil;
  SetLength(Result, AArray.Count);
  for I := 0 to AArray.Count - 1 do
  begin
    LNote := IntValue(AArray.Items[I]);
    Require((LNote >= 0) and (LNote <= 127), 'Part pitch outside MIDI range');
    Result[I] := LNote;
  end;
end;

function PartCells(const AArray: TJSONArray; const ARoles: Integer): TPartEvaluationCells;
var
  LRow: TJSONObject;
  LPart: TJSONObject;
  LParts: TJSONArray;
  LState: String;
  I: Integer;
  J: Integer;
begin
  Require((AArray.Count <= MaximumPartEvaluationCells) and
    (Int64(AArray.Count) * ARoles <= MaximumEvaluationItems), 'Part center budget exceeded');
  Result := nil;
  SetLength(Result, AArray.Count);
  for I := 0 to AArray.Count - 1 do
  begin
    LRow := ObjectAt(AArray, I);
    Fields(LRow, 'frame,parts,unassigned_notes');
    Result[I].Frame := IntField(LRow, 'frame');
    Result[I].UnassignedNotes := PartPitches(TJSONArray(Item(LRow, 'unassigned_notes', jtArray)));
    LParts := TJSONArray(Item(LRow, 'parts', jtArray));
    Require(LParts.Count = ARoles, 'Every center requires every declared role');
    SetLength(Result[I].Parts, ARoles);
    for J := 0 to ARoles - 1 do
    begin
      LPart := ObjectAt(LParts, J);
      Fields(LPart, 'state,notes');
      LState := TextField(LPart, 'state');
      if LState = 'value' then
      begin
        Result[I].Parts[J].State := esValue;
      end
      else if LState = 'rest' then
      begin
        Result[I].Parts[J].State := esRest;
      end
      else if LState = 'unknown' then
      begin
        Result[I].Parts[J].State := esUnknown;
      end
      else if LState = 'ambiguous' then
      begin
        Result[I].Parts[J].State := esAmbiguous;
      end
      else
      begin
        Require(LState = 'unsupported', 'Unknown part state');
        Result[I].Parts[J].State := esUnsupported;
      end;
      Result[I].Parts[J].Notes := PartPitches(TJSONArray(Item(LPart, 'notes', jtArray)));
    end;
  end;
end;

function PartCrossings(const AArray: TJSONArray; const ARoles: Integer): TPartCrossings;
var
  LRow: TJSONObject;
  LFirst: Int64;
  LSecond: Int64;
  I: Integer;
begin
  Require(AArray.Count <= MaximumPartCrossings, 'Part crossing budget exceeded');
  Result := nil;
  SetLength(Result, AArray.Count);
  for I := 0 to AArray.Count - 1 do
  begin
    LRow := ObjectAt(AArray, I);
    Fields(LRow, 'first_role,second_role,before_frame,after_frame');
    LFirst := IntField(LRow, 'first_role');
    LSecond := IntField(LRow, 'second_role');
    Require((LFirst >= 0) and (LFirst < ARoles) and (LSecond >= 0) and
      (LSecond < ARoles), 'Crossing role outside vocabulary');
    Result[I].FirstRole := LFirst;
    Result[I].SecondRole := LSecond;
    Result[I].BeforeFrame := IntField(LRow, 'before_frame');
    Result[I].AfterFrame := IntField(LRow, 'after_frame');
  end;
end;

function PartStates(const ACounts: TPartStateCounts): TJSONObject;
begin
  Result := TJSONObject.Create;
  Result.Add('value', ACounts[esValue]);
  Result.Add('rest', ACounts[esRest]);
  Result.Add('unknown', ACounts[esUnknown]);
  Result.Add('ambiguous', ACounts[esAmbiguous]);
  Result.Add('unsupported', ACounts[esUnsupported]);
end;

procedure ScoreParts(const AReference, APrediction: TJSONObject;
  const AVocabulary: TJSONArray; const ABinding: TEvaluationBinding;
  const AMinimumCoverage, AMinimumPrecision, AMinimumReference: Double;
  const AReport: TJSONObject; out APass: Boolean);
var
  LIds: TPartRoleIds;
  LScore: TPartEvaluation;
  LRoles: TJSONArray;
  LMatrix: TJSONArray;
  LRow: TJSONArray;
  LRole: TJSONObject;
  LPass: Boolean;
  I: Integer;
  J: Integer;
begin
  Require((AVocabulary.Count > 0) and (AVocabulary.Count <= MaximumPartRoles),
    'Part evaluation needs 1..32 stable role IDs');
  SetLength(LIds, AVocabulary.Count);
  for I := 0 to High(LIds) do
  begin
    LIds[I] := AVocabulary.Strings[I];
  end;
  LScore := EvaluatePartCells(LIds,
    PartCells(TJSONArray(Item(AReference, 'observations', jtArray)), Length(LIds)),
    PartCells(TJSONArray(Item(APrediction, 'observations', jtArray)), Length(LIds)),
    PartCrossings(TJSONArray(Item(AReference, 'crossings', jtArray)), Length(LIds)),
    ABinding.FirstFrame, ABinding.EndFrame);
  AReport.Add('cell_count', LScore.CellCount);
  AReport.Add('count_unit', 'pitch-center-pair');
  AReport.Add('crossing_scope', 'declared-endpoints-only');
  AReport.Add('reference_unassigned_notes', LScore.ReferenceUnassignedNotes);
  AReport.Add('prediction_unassigned_notes', LScore.PredictionUnassignedNotes);
  AReport.Add('unassigned_pitch_matches', LScore.UnassignedPitchMatches);
  AReport.Add('unassigned_extra_pitches', LScore.UnassignedExtraPitches);
  AReport.Add('unassigned_unscorable', LScore.UnassignedUnscorable);
  AReport.Add('crossing_spans', LScore.CrossingSpans);
  AReport.Add('crossing_endpoints_correct', LScore.CrossingEndpointsCorrect);
  AReport.Add('crossing_endpoints_wrong', LScore.CrossingEndpointsWrong);
  AReport.Add('crossing_endpoints_unavailable', LScore.CrossingEndpointsUnavailable);
  APass := (LScore.ReferenceUnassignedNotes = 0) and
    (LScore.UnassignedExtraPitches = 0) and (LScore.UnassignedUnscorable = 0) and
    (LScore.CrossingEndpointsWrong = 0) and (LScore.CrossingEndpointsUnavailable = 0);
  LRoles := TJSONArray.Create;
  AReport.Add('roles', LRoles);
  LMatrix := TJSONArray.Create;
  AReport.Add('leakage_reference_to_prediction', LMatrix);
  for I := 0 to High(LIds) do
  begin
    LRole := TJSONObject.Create;
    LRoles.Add(LRole);
    LRole.Add('role_id', LIds[I]);
    LRole.Add('reference_states', PartStates(LScore.Roles[I].ReferenceStates));
    LRole.Add('prediction_states', PartStates(LScore.Roles[I].PredictionStates));
    LRole.Add('reference_notes', LScore.Roles[I].ReferenceNotes);
    LRole.Add('predicted_scorable_notes', LScore.Roles[I].PredictedScorableNotes);
    LRole.Add('correct_notes', LScore.Roles[I].CorrectNotes);
    LRole.Add('missed_notes', LScore.Roles[I].MissedNotes);
    LRole.Add('extra_notes', LScore.Roles[I].ExtraNotes);
    LRole.Add('false_notes_in_rest', LScore.Roles[I].FalseNotesInRest);
    LRole.Add('admitted_unscorable', LScore.Roles[I].AdmittedUnscorable);
    LRole.Add('unique_owner_matches', LScore.Roles[I].UniqueOwnerMatches);
    LRole.Add('uncertain_owner_matches', LScore.Roles[I].UncertainOwnerMatches);
    LRole.Add('wrong_owner_notes', LScore.Roles[I].WrongOwnerNotes);
    LRole.Add('ambiguous_wrong_owner_notes', LScore.Roles[I].AmbiguousWrongOwnerNotes);
    LRole.Add('unresolved_extra_notes', LScore.Roles[I].UnresolvedExtraNotes);
    LRole.Add('novel_pitch_notes', LScore.Roles[I].NovelPitchNotes);
    LRole.Add('coverage', LScore.Roles[I].Coverage);
    LRole.Add('precision', LScore.Roles[I].Precision);
    LRole.Add('reference_coverage', LScore.Roles[I].ReferenceCoverage);
    LPass := (LScore.Roles[I].ReferenceNotes > 0) and
      (LScore.Roles[I].Coverage >= AMinimumCoverage) and
      (LScore.Roles[I].Precision >= AMinimumPrecision) and
      (LScore.Roles[I].ReferenceCoverage >= AMinimumReference);
    LRole.Add('passes_declared_gates', LPass);
    APass := APass and LPass;
    LRow := TJSONArray.Create;
    LMatrix.Add(LRow);
    for J := 0 to High(LIds) do
    begin
      LRow.Add(LScore.Leakage[I][J]);
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
    (LMetric = 'notes') or (LMetric = 'part-note-sets'),
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
  Require((((LMetric = 'label') or (LMetric = 'notes') or (LMetric = 'part-note-sets')) and
    (LVocabulary.Count > 0)) or
    (((LMetric = 'scalar') or (LMetric = 'events')) and (LVocabulary.Count = 0)),
    'Metric/vocabulary mismatch');
  Require((LMetric = 'events') or (LMetric = 'notes') or
    ((LTolerance = 0) and (LMinimumF1 = 0)),
    'Non-event policy has event thresholds');
  Require((LMetric = 'scalar') or (LScalarTolerance = 0),
    'Non-scalar policy has scalar tolerance');
  if LMetric = 'part-note-sets' then
  begin
    Require((LMinimumCoverage >= MinimumPhraseCoverage) and
      (LMinimumPrecision >= MinimumPhrasePrecision) and (LMinimumReference = 1),
      'Part-set diagnostic gates require positive per-role evidence and complete references');
    Fields(AReference, 'format,clock,annotation_policy_sha256,observations,crossings');
    Fields(APrediction, 'format,clock,estimator_sha256,observations');
  end
  else if LMetric = 'notes' then
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
    if LMetric = 'part-note-sets' then
    begin
      ScoreParts(AReference, APrediction, LVocabulary, ABinding,
        LMinimumCoverage, LMinimumPrecision, LMinimumReference, Result, APass);
    end
    else if LMetric = 'events' then
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
      if LCellMetric = emScalar then
      begin
        CheckScalarUnits(LReferenceCells, TextField(APolicy, 'unit'));
        CheckScalarUnits(LPredictionCells, TextField(APolicy, 'unit'));
      end;
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
  LAnnotation: TJSONObject;
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
  LPrimary: Boolean;
  LPredictionAncestryReason: String;
begin
  LCase := nil;
  LReference := nil;
  LPrediction := nil;
  LPolicy := nil;
  LAnnotation := nil;
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
    LAnnotation := ReadObject(FilePath(LBase, LFiles, 'annotation_policy'),
      LBinding.AnnotationPolicySha256);
    VerifyDocument(FilePath(LBase, LFiles, 'estimator'), LBinding.EstimatorSha256);
    LReference := ReadObject(FilePath(LBase, LFiles, 'reference'), LBinding.ReferenceSha256);
    LPrediction := ReadObject(FilePath(LBase, LFiles, 'prediction'),
      TextField(LCase, 'prediction_sha256'));
    LLedger := ReadObject(FilePath(LBase, LFiles, 'ledger'), TextField(LCase, 'ledger_sha256'));
    LPolicy := ReadObject(FilePath(LBase, LFiles, 'scoring_policy'), LBinding.ScoringPolicySha256);
    LPrimary := CheckAnnotation(LAnnotation, LPolicy, LBinding);
    CheckLedger(LLedger, LBinding, TextField(LCase, 'prediction_sha256'),
      LPredictionAncestryReason);
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
    LIndependent := LPrimary and IsIndependentEvaluation(LBinding) and
      (LPredictionAncestryReason = '');
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
    LReport.Add('annotation', LAnnotation.Clone);
    LReport.Add('metrics_pass', LPass);
    LReport.Add('prediction_ancestry_independent', LPredictionAncestryReason = '');
    LReport.Add('prediction_ancestry_reason', LPredictionAncestryReason);
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
    LAnnotation.Free;
    LPrediction.Free;
    LReference.Free;
    LCase.Free;
  end;
end;

end.
