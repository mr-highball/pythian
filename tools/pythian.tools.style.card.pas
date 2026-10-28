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
unit pythian.tools.style.card;

{$mode delphi}
{$H+}

interface

uses
  pythian.evaluation.style.card, pythian.progress;

const
  MaximumStyleCardDocumentBytes = 8 * 1024 * 1024;
  MaximumStyleCardAssetBytes: Int64 = 1024 * 1024 * 1024;

{ Reads strict current JSON, rejects unknown/duplicate fields and budgets before
  recursion, then verifies all bound asset bytes and each declared WAV clock.
  Paths are resolved relative to this card, retained as declared for writing.
  Total verification work per card is bounded to MaximumStyleCardAssetBytes,
  including repeated paths. Hash binding is not annotation validation or proof
  that the supplied histogram was derived from those bytes. Concurrent asset
  modification is unsupported; no files are written. Borrowed callbacks expose
  actual scan/value/hash work; bounded file reads, RTL JSON and WAV header parsing
  have synchronous endpoints, not interior or event-loop cancellation guarantees.
  A final callback precedes result publication; any original exception propagates. }
function ReadStyleCardFile(const APath: String;
  const AProgress: TWorkProgressCallback = nil): TStyleCard;
{ Pure deterministic current encoding; does not qualify or verify evidence. }
function WriteStyleCardJSON(const ACard: TStyleCard;
  const AProgress: TWorkProgressCallback = nil): UTF8String;
function WriteStyleCardResultJSON(const AResult: TStyleCardResult;
  const AProgress: TWorkProgressCallback = nil): UTF8String;
function CompareStyleCardFiles(const AReferencePath, ACandidatePath: String;
  const AProgress: TWorkProgressCallback = nil): UTF8String;

implementation

uses
  Classes, SysUtils, Math, fpjson, pythian.tools.json,
  pythian.audio, pythian.hash, pythian.wave.read, pythian.tools.files,
  pythian.evaluation, pythian.evaluation.style, pythian.text;

const
  AssetNames: array[0..5] of String = ('source', 'preparation', 'reference',
    'annotation_policy', 'scoring_policy', 'estimator');
  PartitionNames: array[TEvaluationPartition] of String =
    ('training', 'development', 'evaluation');
  OverlapNames: array[TEstimatorTrainingOverlap] of String =
    ('unknown', 'not-applicable', 'disjoint', 'overlap');

procedure Require(const ACondition: Boolean; const AMessage: String);
begin
  if not ACondition then
  begin
    raise EAudio.Create(AMessage);
  end;
end;

procedure VisitStyleValue(const AProgress: TWorkProgressCallback;
  const AStage: String; var AVisits: Int64);
begin
  Inc(AVisits);
  if AVisits mod 4096 = 0 then
  begin
    ReportWork(AProgress, AStage, wuItems, AVisits, 0);
  end;
end;

procedure Fields(const AObject: TJSONObject; const ANames: String);
var
  LNames: TStringList;
  I: Integer;
  J: Integer;
begin
  LNames := TStringList.Create;
  try
    LNames.StrictDelimiter := True;
    LNames.Delimiter := ',';
    LNames.DelimitedText := ANames;
    Require(AObject.Count = LNames.Count, 'Unexpected style card fields');
    for I := 0 to AObject.Count - 1 do
    begin
      Require(LNames.IndexOf(AObject.Names[I]) >= 0, 'Unknown style card field');
      for J := 0 to I - 1 do
      begin
        Require(AObject.Names[J] <> AObject.Names[I], 'Duplicate style card field');
      end;
    end;
  finally
    LNames.Free;
  end;
end;

function Item(const AObject: TJSONObject; const AName: String;
  const AType: TJSONType): TJSONData;
begin
  Result := AObject.Find(AName);
  Require((Result <> nil) and (Result.JSONType = AType), 'Missing/invalid style field: ' + AName);
end;

function TextField(const AObject: TJSONObject; const AName: String): UTF8String;
begin
  Result := Item(AObject, AName, jtString).AsString;
end;

function IntegerValue(const AData: TJSONData): Int64;
begin
  Require(AData.JSONType = jtNumber, 'Style count requires an integer');
  Require(TryStrToInt64(AData.AsJSON, Result), 'Style count requires an exact integer');
end;

function IntegerField(const AObject: TJSONObject; const AName: String): Int64;
begin
  Result := IntegerValue(Item(AObject, AName, jtNumber));
end;

function BooleanField(const AObject: TJSONObject; const AName: String): Boolean;
begin
  Result := Item(AObject, AName, jtBoolean).AsBoolean;
end;

function NumberField(const AObject: TJSONObject; const AName: String): Double;
begin
  Result := Item(AObject, AName, jtNumber).AsFloat;
  Require(not IsNan(Result) and not IsInfinite(Result), 'Nonfinite style number');
end;

function ObjectAt(const AArray: TJSONArray; const AIndex: Integer): TJSONObject;
begin
  Require(AArray.Items[AIndex].JSONType = jtObject, 'Style array requires objects');
  Result := TJSONObject(AArray.Items[AIndex]);
end;

function ParseDocument(const ABytes: TAudioBytes;
  const AProgress: TWorkProgressCallback): TJSONObject;
var
  LText: TScalarText;
  LData: TJSONData;
begin
  Require((Length(ABytes) > 0) and (Length(ABytes) <= MaximumStyleCardDocumentBytes),
    'Style JSON byte budget exceeded');
  SetString(LText, PAnsiChar(@ABytes[0]), Length(ABytes));
  LData := ParseNativeJSON(LText, MaximumStyleCardDocumentBytes, 16, AProgress);
  try
    Require((LData <> nil) and (LData.JSONType = jtObject), 'Style root requires an object');
    Result := TJSONObject(LData);
    LData := nil;
  finally
    LData.Free;
  end;
end;

function ReadBinding(const AObject: TJSONObject): TEvaluationBinding;
var
  LRate: Int64;
  LText: String;
  P: TEvaluationPartition;
  O: TEstimatorTrainingOverlap;
  LFound: Boolean;
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
  LRate := IntegerField(AObject, 'sample_rate');
  Require((LRate > 0) and (LRate <= High(Integer)), 'Invalid style sample rate');
  Result.SampleRate := Integer(LRate);
  Result.SourceFrames := IntegerField(AObject, 'source_frames');
  Result.FirstFrame := IntegerField(AObject, 'first_frame');
  Result.EndFrame := IntegerField(AObject, 'end_frame');
  LText := TextField(AObject, 'partition');
  LFound := False;
  for P := Low(P) to High(P) do
  begin
    if LText = PartitionNames[P] then
    begin
      Result.Partition := P;
      LFound := True;
    end;
  end;
  Require(LFound, 'Invalid style partition');
  Result.GroupVerified := BooleanField(AObject, 'group_verified');
  Result.PreviouslyUsedForTuning := BooleanField(AObject, 'previously_used_for_tuning');
  Result.ReferenceComplete := BooleanField(AObject, 'reference_complete');
  LText := TextField(AObject, 'estimator_training_overlap');
  LFound := False;
  for O := Low(O) to High(O) do
  begin
    if LText = OverlapNames[O] then
    begin
      Result.EstimatorTrainingOverlap := O;
      LFound := True;
    end;
  end;
  Require(LFound, 'Invalid style estimator overlap');
  ValidateEvaluationBinding(Result);
end;

function ReadTrait(const AObject: TJSONObject;
  const AProgress: TWorkProgressCallback; var AVisits: Int64): TStyleCardTrait;
var
  LArray: TJSONArray;
  LCounts: TJSONArray;
  LBins: TJSONArray;
  LGroup: TJSONObject;
  LAssets: TJSONObject;
  I: Integer;
  J: Integer;
  LText: UTF8String;
begin
  Fields(AObject, 'id,requirement,support,units,denominator,minimum_coverage,' +
    'maximum_distance,policy_sha256,bins,groups');
  Result := Default(TStyleCardTrait);
  Result.Id := TextField(AObject, 'id');
  LText := TextField(AObject, 'requirement');
  Require((LText = 'required') or (LText = 'optional'), 'Invalid style requirement');
  if LText = 'optional' then
  begin
    Result.Requirement := strOptional;
  end;
  LText := TextField(AObject, 'support');
  Require((LText = 'supported') or (LText = 'unsupported'), 'Invalid style support');
  if LText = 'unsupported' then
  begin
    Result.Support := stsUnsupported;
  end;
  Result.Units := TextField(AObject, 'units');
  Result.Denominator := TextField(AObject, 'denominator');
  Result.MinimumCoverage := NumberField(AObject, 'minimum_coverage');
  Result.MaximumDistance := NumberField(AObject, 'maximum_distance');
  Result.Distribution.PolicySha256 := TextField(AObject, 'policy_sha256');
  LBins := TJSONArray(Item(AObject, 'bins', jtArray));
  Require(LBins.Count <= MaximumStyleBins, 'Style bin budget exceeded');
  SetLength(Result.Distribution.Bins, LBins.Count);
  for I := 0 to LBins.Count - 1 do
  begin
    Require(LBins.Items[I].JSONType = jtString, 'Style bin requires text');
    Result.Distribution.Bins[I] := LBins.Strings[I];
    VisitStyleValue(AProgress, 'style_card_read_values', AVisits);
  end;
  LArray := TJSONArray(Item(AObject, 'groups', jtArray));
  Require(LArray.Count <= MaximumStyleGroups, 'Style group budget exceeded');
  SetLength(Result.Groups, LArray.Count);
  SetLength(Result.Distribution.Groups, LArray.Count);
  for I := 0 to LArray.Count - 1 do
  begin
    VisitStyleValue(AProgress, 'style_card_read_values', AVisits);
    LGroup := ObjectAt(LArray, I);
    Fields(LGroup, 'id,binding,assets,method,uncertainty,counts,unknown,ambiguous,unsupported');
    Result.Groups[I].Id := TextField(LGroup, 'id');
    Result.Groups[I].Binding := ReadBinding(TJSONObject(Item(LGroup, 'binding', jtObject)));
    Result.Groups[I].Method := TextField(LGroup, 'method');
    Result.Groups[I].Uncertainty := TextField(LGroup, 'uncertainty');
    LAssets := TJSONObject(Item(LGroup, 'assets', jtObject));
    Fields(LAssets, 'source,preparation,reference,annotation_policy,scoring_policy,estimator');
    for J := 0 to 5 do
    begin
      Result.Groups[I].Assets[J] := TextField(LAssets, AssetNames[J]);
    end;
    Result.Distribution.Groups[I].GroupId := Result.Groups[I].Id;
    LCounts := TJSONArray(Item(LGroup, 'counts', jtArray));
    Require(LCounts.Count = LBins.Count, 'Style counts differ from bin count');
    SetLength(Result.Distribution.Groups[I].Counts, LCounts.Count);
    for J := 0 to LCounts.Count - 1 do
    begin
      Result.Distribution.Groups[I].Counts[J] := IntegerValue(LCounts.Items[J]);
      VisitStyleValue(AProgress, 'style_card_read_values', AVisits);
    end;
    Result.Distribution.Groups[I].Unknown := IntegerField(LGroup, 'unknown');
    Result.Distribution.Groups[I].Ambiguous := IntegerField(LGroup, 'ambiguous');
    Result.Distribution.Groups[I].Unsupported := IntegerField(LGroup, 'unsupported');
  end;
end;

function ResolveAsset(const ABase: String; const APath: UTF8String): String;
begin
  if (ExtractFileDrive(APath) <> '') or (APath[1] in ['/', '\']) then
  begin
    Result := ExpandFileName(APath);
  end
  else
  begin
    Result := ExpandFileName(ABase + APath);
  end;
end;

procedure VerifyGroup(const ABase: String; const AGroup: TStyleCardGroup;
  var AVerifiedBytes, AVerifiedAssets: Int64; const AProgress: TWorkProgressCallback);
var
  LDigest: array[0..5] of String;
  I: Integer;
  LStream: TFileStream;
  LReader: TWaveFrameReader;
begin
  LDigest[0] := AGroup.Binding.SourceSha256;
  LDigest[1] := AGroup.Binding.PreparationSha256;
  LDigest[2] := AGroup.Binding.ReferenceSha256;
  LDigest[3] := AGroup.Binding.AnnotationPolicySha256;
  LDigest[4] := AGroup.Binding.ScoringPolicySha256;
  LDigest[5] := AGroup.Binding.EstimatorSha256;
  for I := 0 to 5 do
  begin
    LStream := TFileStream.Create(ResolveAsset(ABase, AGroup.Assets[I]), fmOpenRead or fmShareDenyWrite);
    try
      Require((LStream.Size > 0) and (LStream.Size <= MaximumStyleCardAssetBytes),
        'Style asset byte budget exceeded');
      Require(AVerifiedBytes <= MaximumStyleCardAssetBytes - LStream.Size,
        'Style total asset verification byte budget exceeded');
      Inc(AVerifiedBytes, LStream.Size);
      Require(Sha256Stream(LStream, LStream.Size, AProgress) = LDigest[I],
        'Style bound asset digest mismatch: ' + AssetNames[I]);
      if I = 0 then
      begin
        LStream.Position := 0;
        ReportWork(AProgress, 'style_card_wave_clock', wuItems, 0, 1);
        LReader := TWaveFrameReader.Create(LStream);
        try
          Require((LReader.SampleRate = AGroup.Binding.SampleRate) and
            (LReader.FrameCount = AGroup.Binding.SourceFrames), 'Style WAV clock differs from binding');
          ReportWork(AProgress, 'style_card_wave_clock', wuItems, 1, 1);
        finally
          LReader.Free;
        end;
      end;
      Inc(AVerifiedAssets);
      ReportWork(AProgress, 'style_card_assets', wuItems, AVerifiedAssets, 0);
    finally
      LStream.Free;
    end;
  end;
end;

function ReadStyleCardFile(const APath: String;
  const AProgress: TWorkProgressCallback): TStyleCard;
var
  LRoot: TJSONObject;
  LTraits: TJSONArray;
  LCard: TStyleCard;
  I: Integer;
  J: Integer;
  LBase: String;
  LVerifiedBytes: Int64;
  LVerifiedAssets: Int64;
  LVisits: Int64;
  LBytes: TAudioBytes;
begin
  ReportWork(AProgress, 'style_card_document_read', wuItems, 0, 1);
  LBytes := ReadFileBytes(APath, MaximumStyleCardDocumentBytes);
  ReportWork(AProgress, 'style_card_document_read', wuItems, 1, 1);
  LRoot := ParseDocument(LBytes, AProgress);
  try
    Fields(LRoot, 'version,id,traits');
    Require(IntegerField(LRoot, 'version') = StyleCardVersion, 'Unsupported style card version');
    LCard := Default(TStyleCard);
    LCard.Id := TextField(LRoot, 'id');
    LTraits := TJSONArray(Item(LRoot, 'traits', jtArray));
    Require((LTraits.Count > 0) and (LTraits.Count <= MaximumStyleCardTraits), 'Style trait budget exceeded');
    SetLength(LCard.Traits, LTraits.Count);
    LVisits := 0;
    ReportWork(AProgress, 'style_card_read_values', wuItems, 0, 0);
    for I := 0 to LTraits.Count - 1 do
    begin
      VisitStyleValue(AProgress, 'style_card_read_values', LVisits);
      LCard.Traits[I] := ReadTrait(ObjectAt(LTraits, I), AProgress, LVisits);
    end;
    ReportWork(AProgress, 'style_card_read_values', wuItems, LVisits, LVisits);
    ValidateStyleCard(LCard, AProgress);
    LBase := IncludeTrailingPathDelimiter(ExtractFilePath(ExpandFileName(APath)));
    LVerifiedBytes := 0;
    LVerifiedAssets := 0;
    ReportWork(AProgress, 'style_card_assets', wuItems, 0, 0);
    for I := 0 to High(LCard.Traits) do
    begin
      for J := 0 to High(LCard.Traits[I].Groups) do
      begin
        VerifyGroup(LBase, LCard.Traits[I].Groups[J], LVerifiedBytes,
          LVerifiedAssets, AProgress);
      end;
    end;
    ReportWork(AProgress, 'style_card_assets', wuItems, LVerifiedAssets, LVerifiedAssets);
    ReportWork(AProgress, 'style_card_read_ready', wuItems, 1, 1);
    Result := LCard;
  finally
    LRoot.Free;
  end;
end;

function BindingJSON(const ABinding: TEvaluationBinding): TJSONObject;
begin
  Result := TJSONObject.Create;
  Result.Add('source_sha256', ABinding.SourceSha256);
  Result.Add('preparation_sha256', ABinding.PreparationSha256);
  Result.Add('reference_sha256', ABinding.ReferenceSha256);
  Result.Add('annotation_policy_sha256', ABinding.AnnotationPolicySha256);
  Result.Add('scoring_policy_sha256', ABinding.ScoringPolicySha256);
  Result.Add('estimator_sha256', ABinding.EstimatorSha256);
  Result.Add('group_id', NativeJSONText(ABinding.GroupId));
  Result.Add('sample_rate', ABinding.SampleRate);
  Result.Add('source_frames', ABinding.SourceFrames);
  Result.Add('first_frame', ABinding.FirstFrame);
  Result.Add('end_frame', ABinding.EndFrame);
  Result.Add('partition', PartitionNames[ABinding.Partition]);
  Result.Add('group_verified', ABinding.GroupVerified);
  Result.Add('previously_used_for_tuning', ABinding.PreviouslyUsedForTuning);
  Result.Add('reference_complete', ABinding.ReferenceComplete);
  Result.Add('estimator_training_overlap', OverlapNames[ABinding.EstimatorTrainingOverlap]);
end;

function WriteStyleCardJSON(const ACard: TStyleCard;
  const AProgress: TWorkProgressCallback): UTF8String;
var
  LRoot: TJSONObject;
  LTrait: TJSONObject;
  LGroup: TJSONObject;
  LAssets: TJSONObject;
  LTraits: TJSONArray;
  LGroups: TJSONArray;
  LBins: TJSONArray;
  LCounts: TJSONArray;
  I: Integer;
  J: Integer;
  K: Integer;
  LVisits: Int64;
  LText: UTF8String;
begin
  ValidateStyleCard(ACard, AProgress);
  LRoot := TJSONObject.Create;
  try
    LRoot.Add('version', StyleCardVersion);
    LRoot.Add('id', NativeJSONText(ACard.Id));
    LTraits := TJSONArray.Create;
    LRoot.Add('traits', LTraits);
    LVisits := 0;
    ReportWork(AProgress, 'style_card_write_values', wuItems, 0, 0);
    for I := 0 to High(ACard.Traits) do
    begin
      VisitStyleValue(AProgress, 'style_card_write_values', LVisits);
      LTrait := TJSONObject.Create;
      LTraits.Add(LTrait);
      LTrait.Add('id', NativeJSONText(ACard.Traits[I].Id));
      if ACard.Traits[I].Requirement = strRequired then
      begin
        LTrait.Add('requirement', 'required');
      end
      else
      begin
        LTrait.Add('requirement', 'optional');
      end;
      if ACard.Traits[I].Support = stsSupported then
      begin
        LTrait.Add('support', 'supported');
      end
      else
      begin
        LTrait.Add('support', 'unsupported');
      end;
      LTrait.Add('units', NativeJSONText(ACard.Traits[I].Units));
      LTrait.Add('denominator', NativeJSONText(ACard.Traits[I].Denominator));
      LTrait.Add('minimum_coverage', ACard.Traits[I].MinimumCoverage);
      LTrait.Add('maximum_distance', ACard.Traits[I].MaximumDistance);
      LTrait.Add('policy_sha256', ACard.Traits[I].Distribution.PolicySha256);
      LBins := TJSONArray.Create;
      LTrait.Add('bins', LBins);
      for J := 0 to High(ACard.Traits[I].Distribution.Bins) do
      begin
        LBins.Add(NativeJSONText(ACard.Traits[I].Distribution.Bins[J]));
        VisitStyleValue(AProgress, 'style_card_write_values', LVisits);
      end;
      LGroups := TJSONArray.Create;
      LTrait.Add('groups', LGroups);
      for J := 0 to High(ACard.Traits[I].Groups) do
      begin
        VisitStyleValue(AProgress, 'style_card_write_values', LVisits);
        LGroup := TJSONObject.Create;
        LGroups.Add(LGroup);
        LGroup.Add('id', NativeJSONText(ACard.Traits[I].Groups[J].Id));
        LGroup.Add('binding', BindingJSON(ACard.Traits[I].Groups[J].Binding));
        LAssets := TJSONObject.Create;
        LGroup.Add('assets', LAssets);
        for K := 0 to 5 do
        begin
          LAssets.Add(AssetNames[K], NativeJSONText(ACard.Traits[I].Groups[J].Assets[K]));
        end;
        LGroup.Add('method', NativeJSONText(ACard.Traits[I].Groups[J].Method));
        LGroup.Add('uncertainty', NativeJSONText(ACard.Traits[I].Groups[J].Uncertainty));
        LCounts := TJSONArray.Create;
        LGroup.Add('counts', LCounts);
        for K := 0 to High(ACard.Traits[I].Distribution.Groups[J].Counts) do
        begin
          LCounts.Add(ACard.Traits[I].Distribution.Groups[J].Counts[K]);
          VisitStyleValue(AProgress, 'style_card_write_values', LVisits);
        end;
        LGroup.Add('unknown', ACard.Traits[I].Distribution.Groups[J].Unknown);
        LGroup.Add('ambiguous', ACard.Traits[I].Distribution.Groups[J].Ambiguous);
        LGroup.Add('unsupported', ACard.Traits[I].Distribution.Groups[J].Unsupported);
      end;
    end;
    ReportWork(AProgress, 'style_card_write_values', wuItems, LVisits, LVisits);
    ReportWork(AProgress, 'style_card_json_encode', wuItems, 0, 1);
    LText := LRoot.AsJSON;
    ReportWork(AProgress, 'style_card_json_encode', wuItems, 1, 1);
    Result := LText;
  finally
    LRoot.Free;
  end;
end;

function CoverageJSON(const ACoverage: TStyleDistributionCoverage): TJSONObject;
begin
  Result := TJSONObject.Create;
  Result.Add('groups', ACoverage.Groups);
  Result.Add('groups_with_values', ACoverage.GroupsWithValues);
  Result.Add('known', ACoverage.Known);
  Result.Add('unknown', ACoverage.Unknown);
  Result.Add('ambiguous', ACoverage.Ambiguous);
  Result.Add('unsupported', ACoverage.Unsupported);
  Result.Add('total', ACoverage.Total);
  Result.Add('pooled_coverage', ACoverage.PooledCoverage);
  Result.Add('mean_group_coverage', ACoverage.MeanGroupCoverage);
  Result.Add('minimum_group_coverage', ACoverage.MinimumGroupCoverage);
end;

function WriteStyleCardResultJSON(const AResult: TStyleCardResult;
  const AProgress: TWorkProgressCallback): UTF8String;
var
  LRoot: TJSONObject;
  LTrait: TJSONObject;
  LTraits: TJSONArray;
  I: Integer;
  LText: UTF8String;
begin
  Require(not AResult.GroundedAcceptance, 'Style contract cannot certify grounded acceptance');
  LRoot := TJSONObject.Create;
  try
    LRoot.Add('reference_id', NativeJSONText(AResult.ReferenceId));
    LRoot.Add('candidate_id', NativeJSONText(AResult.CandidateId));
    LRoot.Add('grounded_acceptance', False);
    LRoot.Add('passed_required_declared_limits', AResult.PassedRequiredDeclaredLimits);
    LTraits := TJSONArray.Create;
    LRoot.Add('traits', LTraits);
    ReportWork(AProgress, 'style_card_report_traits', wuItems, 0, Length(AResult.Traits));
    for I := 0 to High(AResult.Traits) do
    begin
      LTrait := TJSONObject.Create;
      LTraits.Add(LTrait);
      LTrait.Add('id', NativeJSONText(AResult.Traits[I].Id));
      if AResult.Traits[I].Requirement = strRequired then
      begin
        LTrait.Add('requirement', 'required');
      end
      else
      begin
        LTrait.Add('requirement', 'optional');
      end;
      LTrait.Add('present', AResult.Traits[I].Present);
      LTrait.Add('supported', AResult.Traits[I].Supported);
      LTrait.Add('comparable', AResult.Traits[I].Comparison.Comparable);
      LTrait.Add('passed_declared_limits', AResult.Traits[I].PassedDeclaredLimits);
      if AResult.Traits[I].Comparison.Comparable then
      begin
        LTrait.Add('distance', AResult.Traits[I].Comparison.Distance);
      end
      else
      begin
        LTrait.Add('distance', TJSONNull.Create);
      end;
      LTrait.Add('reference_coverage', CoverageJSON(AResult.Traits[I].Comparison.Reference));
      LTrait.Add('candidate_coverage', CoverageJSON(AResult.Traits[I].Comparison.Candidate));
      ReportWork(AProgress, 'style_card_report_traits', wuItems, I + 1, Length(AResult.Traits));
    end;
    ReportWork(AProgress, 'style_card_json_encode', wuItems, 0, 1);
    LText := LRoot.AsJSON;
    ReportWork(AProgress, 'style_card_json_encode', wuItems, 1, 1);
    Result := LText;
  finally
    LRoot.Free;
  end;
end;

function CompareStyleCardFiles(const AReferencePath, ACandidatePath: String;
  const AProgress: TWorkProgressCallback): UTF8String;
var
  LReference: TStyleCard;
  LCandidate: TStyleCard;
  LText: UTF8String;
begin
  LReference := ReadStyleCardFile(AReferencePath, AProgress);
  LCandidate := ReadStyleCardFile(ACandidatePath, AProgress);
  LText := WriteStyleCardResultJSON(CompareStyleCards(LReference, LCandidate, AProgress), AProgress);
  ReportWork(AProgress, 'style_card_files_ready', wuItems, 1, 1);
  Result := LText;
end;

end.
