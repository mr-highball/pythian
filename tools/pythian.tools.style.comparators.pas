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
unit pythian.tools.style.comparators;

{$mode delphi}
{$H+}

interface

uses
  pythian.wfc.style.comparators;

const
  StyleComparatorInputFormat = 'pythian.style.comparators.input.v1';
  StyleComparatorAnnotationFormat = 'pythian.style.comparators.annotations.v1';
  StyleComparatorAuthoredFormat = 'pythian.style.comparators.authored.v1';
  StyleComparatorPacketFormat = 'pythian.style.comparators.packet.v1';
  MaximumStyleComparatorSourceBytes = 64 * 1024 * 1024;
  MaximumStyleComparatorDocumentBytes = 1024 * 1024;

{ Strict current manifests authenticate actual bytes and WAV geometry.
  Policy bytes are an opaque caller declaration, never calibration evidence.
  The caller must keep all input assets stable during admission. }
function ReadStyleComparatorInputFile(const AManifestPath: String): TStyleComparatorInput;
{ Malformed input publishes nothing. Execution is staged at OUTPUT.attempt.
  A failed/unsupported execution retains its explicit incomplete packet there;
  only all nine complete outputs permit rename to the fresh OUTPUT directory. }
procedure RunStyleComparatorPacket(const AManifestPath, AOutputDirectory: String);

implementation

uses
  Classes,
  SysUtils,
  Math,
  fpjson,
  jsonparser,
  jsonscanner,
  pythian.audio,
  pythian.pitch.track,
  pythian.wfc.admitted.pitch,
  pythian.wfc.pitch,
  pythian.tools.files,
  pythian.hash,
  pythian.wave,
  pythian.wave.read,
  wfc_model;

procedure Require(const ACondition: Boolean; const AMessage: String);
begin
  if not ACondition then
  begin
    raise EAudio.Create(AMessage);
  end;
end;

procedure Fields(const AObject: TJSONObject; const ANames: String);
var
  LNames: TStringList;
  LIndex: Integer;
  LOther: Integer;
begin
  LNames := TStringList.Create;
  try
    LNames.StrictDelimiter := True;
    LNames.Delimiter := ',';
    LNames.DelimitedText := ANames;
    Require(AObject.Count = LNames.Count, 'Unexpected comparator fields');
    for LIndex := 0 to AObject.Count - 1 do
    begin
      Require(LNames.IndexOf(AObject.Names[LIndex]) >= 0, 'Unknown comparator field');
      for LOther := 0 to LIndex - 1 do
      begin
        Require(AObject.Names[LOther] <> AObject.Names[LIndex], 'Duplicate comparator field');
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
  Require((Result <> nil) and (Result.JSONType = AType),
    'Missing or invalid comparator field: ' + AName);
end;

function TextField(const AObject: TJSONObject; const AName: String): String;
begin
  Result := String(Item(AObject, AName, jtString).AsString);
end;

function IntegerField(const AObject: TJSONObject; const AName: String): Int64;
begin
  Require(TryStrToInt64(Item(AObject, AName, jtNumber).AsJSON, Result),
    'Comparator field requires an exact bounded integer: ' + AName);
end;

function BoundedInteger(const AObject: TJSONObject; const AName: String;
  const AMinimum, AMaximum: Integer): Integer;
var
  LValue: Int64;
begin
  LValue := IntegerField(AObject, AName);
  Require((LValue >= AMinimum) and (LValue <= AMaximum),
    'Comparator integer outside supported bounds: ' + AName);
  Result := LValue;
end;

function ObjectField(const AObject: TJSONObject; const AName: String): TJSONObject;
begin
  Result := TJSONObject(Item(AObject, AName, jtObject));
end;

function ParseDocument(const ABytes: TAudioBytes): TJSONObject;
var
  LIndex: Integer;
  LDepth: Integer;
  LQuoted: Boolean;
  LEscaped: Boolean;
  LText: String;
  LParser: TJSONParser;
  LData: TJSONData;
begin
  Require((Length(ABytes) > 0) and
    (Length(ABytes) <= MaximumStyleComparatorDocumentBytes), 'Comparator JSON byte budget exceeded');
  LDepth := 0;
  LQuoted := False;
  LEscaped := False;
  for LIndex := 0 to High(ABytes) do
  begin
    if LQuoted then
    begin
      if LEscaped then
      begin
        LEscaped := False;
      end
      else if ABytes[LIndex] = 92 then
      begin
        LEscaped := True;
      end
      else if ABytes[LIndex] = 34 then
      begin
        LQuoted := False;
      end;
    end
    else if ABytes[LIndex] = 34 then
    begin
      LQuoted := True;
    end
    else if ABytes[LIndex] in [91, 123] then
    begin
      Inc(LDepth);
      Require(LDepth <= 8, 'Comparator JSON nesting budget exceeded');
    end
    else if ABytes[LIndex] in [93, 125] then
    begin
      Dec(LDepth);
    end;
  end;
  SetString(LText, PAnsiChar(@ABytes[0]), Length(ABytes));
  LParser := TJSONParser.Create(LText, [joUTF8, joStrict]);
  try
    LData := LParser.Parse;
    try
      Require((LData <> nil) and (LData.JSONType = jtObject), 'Comparator root must be object');
      Result := TJSONObject(LData);
      LData := nil;
    finally
      LData.Free;
    end;
  finally
    LParser.Free;
  end;
end;

function AssetPath(const ADirectory, AName: String): String;
var
  LIndex: Integer;
begin
  Require((Length(AName) > 0) and (Length(AName) <= 128) and
    (AName <> '.') and (AName <> '..'), 'Comparator assets require safe relative basenames');
  for LIndex := 1 to Length(AName) do
  begin
    Require(AName[LIndex] in ['a'..'z', 'A'..'Z', '0'..'9', '.', '_', '-'],
      'Comparator assets require safe relative basenames');
  end;
  Result := IncludeTrailingPathDelimiter(ADirectory) + AName;
end;

function ReadBoundAsset(const ADirectory: String; const AObject: TJSONObject): TAudioBytes;
var
  LPath: String;
begin
  LPath := AssetPath(ADirectory, TextField(AObject, 'file'));
  Result := ReadFileBytes(LPath, MaximumStyleComparatorDocumentBytes);
  Require(Sha256Bytes(Result) = TextField(AObject, 'sha256'), 'Comparator asset content hash mismatch');
end;

function ReadKind(const AText: String; const AAllowUnknown: Boolean): TPitchSpanKind;
begin
  if AText = 'pitch' then
  begin
    Exit(pskPitch);
  end;
  if AText = 'silence' then
  begin
    Exit(pskSilence);
  end;
  if AAllowUnknown and (AText = 'unknown') then
  begin
    Exit(pskUnknown);
  end;
  raise EAudio.Create('Unsupported comparator span meaning');
end;

procedure ReadSource(const ADirectory: String; const AObject: TJSONObject;
  var AInput: TStyleComparatorInput);
var
  LStream: TFileStream;
  LReader: TWaveFrameReader;
  LChannels: Integer;
  LSize: Int64;
  LSamples: TAudioSamples;
begin
  Fields(AObject, 'file,sha256,sample_rate,channels,frames,recording_id,group_id,provenance,exposure');
  AInput.Source.SourceSha256 := TextField(AObject, 'sha256');
  AInput.Source.SampleRate := BoundedInteger(AObject, 'sample_rate', 1000, 384000);
  LChannels := BoundedInteger(AObject, 'channels', 1, 2);
  AInput.SourceChannels := LChannels;
  AInput.Source.SourceFrameCount := IntegerField(AObject, 'frames');
  Require((AInput.Source.SourceFrameCount > 0) and
    (AInput.Source.SourceFrameCount <= High(Integer)), 'Unsupported comparator source frame count');
  AInput.Source.RecordingId := TextField(AObject, 'recording_id');
  AInput.Source.GroupId := TextField(AObject, 'group_id');
  AInput.SourceProvenance := TextField(AObject, 'provenance');
  Require((Length(AInput.SourceProvenance) > 0) and (Length(AInput.SourceProvenance) <= 4096),
    'Comparator source provenance declaration is required');
  AInput.Exposure := TextField(AObject, 'exposure');
  LStream := TFileStream.Create(AssetPath(ADirectory, TextField(AObject, 'file')),
    fmOpenRead or fmShareDenyWrite);
  try
    LSize := LStream.Size;
    Require((LSize > 0) and (LSize <= MaximumStyleComparatorSourceBytes),
      'Comparator source byte budget exceeded');
    Require(Sha256Stream(LStream, LSize) = AInput.Source.SourceSha256,
      'Comparator source content hash mismatch');
    LStream.Position := 0;
    LReader := TWaveFrameReader.Create(LStream);
    try
      Require((LReader.SampleRate = AInput.Source.SampleRate) and
        (LReader.Channels = LChannels) and
        (LReader.FrameCount = AInput.Source.SourceFrameCount), 'Comparator source WAV geometry mismatch');
      repeat
        LSamples := LReader.ReadFrames(4096);
      until Length(LSamples) = 0;
    finally
      LReader.Free;
    end;
    Require(LStream.Size = LSize, 'Comparator source changed during validation');
  finally
    LStream.Free;
  end;
end;

procedure ReadAnnotations(const ADirectory: String; const AObject: TJSONObject;
  var AInput: TStyleComparatorInput);
var
  LDocument: TJSONObject;
  LArray: TJSONArray;
  LSpan: TJSONObject;
  LIndex: Integer;
begin
  Fields(AObject, 'file,sha256,id,publisher,method');
  AInput.Source.SourceAnnotationSha256 := TextField(AObject, 'sha256');
  AInput.Source.SourceAnnotationId := TextField(AObject, 'id');
  AInput.Source.SourceAnnotationPublisher := TextField(AObject, 'publisher');
  AInput.Source.SourceAnnotationMethod := TextField(AObject, 'method');
  LDocument := ParseDocument(ReadBoundAsset(ADirectory, AObject));
  try
    Fields(LDocument, 'format,spans');
    Require(TextField(LDocument, 'format') = StyleComparatorAnnotationFormat, 'Unsupported annotation format');
    LArray := TJSONArray(Item(LDocument, 'spans', jtArray));
    Require((LArray.Count > 0) and (LArray.Count <= MaximumStyleComparatorSpans),
      'Comparator annotation span budget exceeded');
    SetLength(AInput.Source.Spans, LArray.Count);
    SetLength(AInput.SpanIds, LArray.Count);
    for LIndex := 0 to LArray.Count - 1 do
    begin
      Require(LArray.Items[LIndex].JSONType = jtObject, 'Comparator span must be object');
      LSpan := TJSONObject(LArray.Items[LIndex]);
      Fields(LSpan, 'id,kind,note,start_frame,end_frame');
      AInput.SpanIds[LIndex] := TextField(LSpan, 'id');
      AInput.Source.Spans[LIndex].Kind := ReadKind(TextField(LSpan, 'kind'), True);
      AInput.Source.Spans[LIndex].Note := BoundedInteger(LSpan, 'note', -1, 127);
      AInput.Source.Spans[LIndex].StartFrame := IntegerField(LSpan, 'start_frame');
      AInput.Source.Spans[LIndex].EndFrame := IntegerField(LSpan, 'end_frame');
    end;
  finally
    LDocument.Free;
  end;
end;

procedure ReadAuthored(const ADirectory: String; const AObject: TJSONObject;
  var AInput: TStyleComparatorInput);
var
  LDocument: TJSONObject;
  LArray: TJSONArray;
  LChoice: TJSONObject;
  LIndex: Integer;
begin
  Fields(AObject, 'file,sha256');
  AInput.AuthoredVocabularySha256 := TextField(AObject, 'sha256');
  LDocument := ParseDocument(ReadBoundAsset(ADirectory, AObject));
  try
    Fields(LDocument, 'format,provenance,choices');
    Require(TextField(LDocument, 'format') = StyleComparatorAuthoredFormat, 'Unsupported authored format');
    AInput.AuthoredProvenance := TextField(LDocument, 'provenance');
    LArray := TJSONArray(Item(LDocument, 'choices', jtArray));
    Require((LArray.Count > 0) and (LArray.Count <= MaximumStyleComparatorTokens),
      'Comparator authored choice budget exceeded');
    SetLength(AInput.AuthoredVocabulary, LArray.Count);
    for LIndex := 0 to LArray.Count - 1 do
    begin
      Require(LArray.Items[LIndex].JSONType = jtObject, 'Comparator authored choice must be object');
      LChoice := TJSONObject(LArray.Items[LIndex]);
      Fields(LChoice, 'kind,note,duration_ms');
      AInput.AuthoredVocabulary[LIndex].Kind := ReadKind(TextField(LChoice, 'kind'), False);
      AInput.AuthoredVocabulary[LIndex].Note := BoundedInteger(LChoice, 'note', -1, 127);
      AInput.AuthoredVocabulary[LIndex].Duration := BoundedInteger(LChoice, 'duration_ms', 1, 1048576);
    end;
  finally
    LDocument.Free;
  end;
end;

function ReadStyleComparatorInputFile(const AManifestPath: String): TStyleComparatorInput;
var
  LDocument: TJSONObject;
  LPolicy: TJSONObject;
  LDirectory: String;
  LPolicyBytes: TAudioBytes;
begin
  Result := Default(TStyleComparatorInput);
  LDirectory := ExtractFileDir(ExpandFileName(AManifestPath));
  LDocument := ParseDocument(ReadFileBytes(AManifestPath, MaximumStyleComparatorDocumentBytes));
  try
    Fields(LDocument, 'format,source,annotations,policy,authored_baseline');
    Require(TextField(LDocument, 'format') = StyleComparatorInputFormat, 'Unsupported comparator input format');
    ReadSource(LDirectory, ObjectField(LDocument, 'source'), Result);
    ReadAnnotations(LDirectory, ObjectField(LDocument, 'annotations'), Result);
    LPolicy := ObjectField(LDocument, 'policy');
    Fields(LPolicy, 'file,sha256');
    LPolicyBytes := ReadBoundAsset(LDirectory, LPolicy);
    Require(Length(LPolicyBytes) > 0, 'Comparator policy declaration must not be empty');
    Result.PolicySha256 := TextField(LPolicy, 'sha256');
    ReadAuthored(LDirectory, ObjectField(LDocument, 'authored_baseline'), Result);
    ValidateStyleComparatorInput(Result);
  finally
    LDocument.Free;
  end;
end;

function KindName(const AKind: TPitchSpanKind): String;
begin
  case AKind of
    pskPitch:
      Result := 'pitch';
    pskSilence:
      Result := 'silence';
    pskUnknown:
      Result := 'unknown';
  end;
end;

function CaseName(const ACase: TStyleComparatorCase): String;
begin
  case ACase of
    sccSingleRecording:
      Result := 'single_recording_baseline';
    sccShuffled:
      Result := 'source_local_shuffled';
    sccUnlearned:
      Result := 'independently_authored_equal_choice';
  end;
end;

function TokenJSON(const ATokens: TWfcModelTokens; const AFirst: Integer = 0): TJSONArray;
var
  LIndex: Integer;
begin
  Result := TJSONArray.Create;
  for LIndex := AFirst to High(ATokens) do
  begin
    Result.Add(String(ATokens[LIndex]));
  end;
end;

function SpanJSON(const ASpan: TAdmittedNoteSpan): TJSONObject;
begin
  Result := TJSONObject.Create;
  Result.Add('kind', KindName(ASpan.Kind));
  Result.Add('note', ASpan.Note);
  Result.Add('start_frame', ASpan.StartFrame);
  Result.Add('end_frame', ASpan.EndFrame);
end;

function InputEvidenceJSON(const AInput: TStyleComparatorInput): TJSONObject;
var
  LSpans: TJSONArray;
  LSpan: TJSONObject;
  LIndex: Integer;
begin
  Result := TJSONObject.Create;
  Result.Add('recording_id', AInput.Source.RecordingId);
  Result.Add('group_id', AInput.Source.GroupId);
  Result.Add('source_sha256', AInput.Source.SourceSha256);
  Result.Add('source_provenance', AInput.SourceProvenance);
  Result.Add('exposure', AInput.Exposure);
  Result.Add('source_sample_rate', AInput.Source.SampleRate);
  Result.Add('source_channels', AInput.SourceChannels);
  Result.Add('source_frame_count', AInput.Source.SourceFrameCount);
  Result.Add('annotation_id', AInput.Source.SourceAnnotationId);
  Result.Add('annotation_sha256', AInput.Source.SourceAnnotationSha256);
  Result.Add('annotation_publisher', AInput.Source.SourceAnnotationPublisher);
  Result.Add('annotation_method', AInput.Source.SourceAnnotationMethod);
  Result.Add('policy_sha256', AInput.PolicySha256);
  Result.Add('policy_semantics', 'opaque_caller_declaration_no_calibration');
  Result.Add('authored_vocabulary_sha256', AInput.AuthoredVocabularySha256);
  Result.Add('authored_provenance', AInput.AuthoredProvenance);
  LSpans := TJSONArray.Create;
  Result.Add('original_spans', LSpans);
  for LIndex := 0 to High(AInput.Source.Spans) do
  begin
    LSpan := SpanJSON(AInput.Source.Spans[LIndex]);
    LSpan.Add('id', AInput.SpanIds[LIndex]);
    LSpans.Add(LSpan);
  end;
end;

function DerivationJSON(const AModels: TStyleComparatorModels): TJSONObject;
var
  LRuns: TJSONArray;
  LRun: TJSONObject;
  LUnits: TJSONArray;
  LUnit: TJSONObject;
  LIndices: TJSONArray;
  LOrdinals: TJSONArray;
  LDigests: TJSONArray;
  LSpans: TJSONArray;
  LSpan: TJSONObject;
  LIndex: Integer;
  LOther: Integer;
  LPart: Integer;
begin
  Result := TJSONObject.Create;
  Result.Add('seed', Int64(AModels.Seed));
  Result.Add('dimension', StyleComparatorDimension);
  Result.Add('learned_shuffled_order', 3);
  Result.Add('unlearned_order', 1);
  Result.Add('original_model_token_marginal_distance', AModels.MarginalDistance);
  Result.Add('training_token_trigram_comparable', AModels.RelationshipComparable);
  if AModels.RelationshipComparable then
  begin
    Result.Add('training_token_trigram_distance', AModels.RelationshipDistance);
  end
  else
  begin
    Result.Add('training_token_trigram_distance', TJSONNull.Create);
  end;
  Result.Add('duration_policy', 'original_endpoint_integer_ms_frozen_before_permutation');
  Result.Add('derived_frame_policy', 'separate_moved_exact_original_frame_extents_not_annotation_truth');
  LRuns := TJSONArray.Create;
  Result.Add('runs', LRuns);
  for LIndex := 0 to High(AModels.Permutations) do
  begin
    LRun := TJSONObject.Create;
    LRuns.Add(LRun);
    LRun.Add('scope_id', AModels.Permutations[LIndex].Id);
    LRun.Add('first_frame', AModels.Permutations[LIndex].FirstFrame);
    LRun.Add('end_frame', AModels.Permutations[LIndex].EndFrame);
    LRun.Add('leading_silence_end_frame', AModels.Permutations[LIndex].LeadingSilenceEndFrame);
    LRun.Add('supported', AModels.Permutations[LIndex].Supported);
    LRun.Add('reason', AModels.Permutations[LIndex].Reason);
    LRun.Add('identity_rotated', AModels.Permutations[LIndex].IdentityRotated);
    LUnits := TJSONArray.Create;
    LRun.Add('canonical_units', LUnits);
    LOrdinals := TJSONArray.Create;
    LRun.Add('output_to_original_ordinals', LOrdinals);
    LDigests := TJSONArray.Create;
    LRun.Add('canonical_unit_sha256_keys', LDigests);
    for LOther := 0 to High(AModels.Permutations[LIndex].Units) do
    begin
      LUnit := TJSONObject.Create;
      LUnits.Add(LUnit);
      LUnit.Add('id', AModels.Permutations[LIndex].Units[LOther].Id);
      LUnit.Add('original_first_frame', AModels.Permutations[LIndex].Units[LOther].FirstFrame);
      LUnit.Add('original_end_frame', AModels.Permutations[LIndex].Units[LOther].EndFrame);
      LIndices := TJSONArray.Create;
      LUnit.Add('original_span_indices', LIndices);
      for LPart := 0 to High(AModels.Permutations[LIndex].Units[LOther].OriginalSpanIndices) do
      begin
        LIndices.Add(AModels.Permutations[LIndex].Units[LOther].OriginalSpanIndices[LPart]);
      end;
      LOrdinals.Add(AModels.Permutations[LIndex].OutputOrdinals[LOther]);
      LDigests.Add(AModels.Permutations[LIndex].SeedDigests[LOther]);
    end;
  end;
  LSpans := TJSONArray.Create;
  Result.Add('derived_frame_spans_by_original_index', LSpans);
  for LIndex := 0 to High(AModels.DerivedSpans) do
  begin
    LSpan := SpanJSON(AModels.DerivedSpans[LIndex].Span);
    LSpan.Add('original_span_index', AModels.DerivedSpans[LIndex].OriginalSpanIndex);
    LSpans.Add(LSpan);
  end;
end;

function RenderLedgerJSON(const ALedger: TStyleComparatorRenderLedger): TJSONObject;
var
  LSolver: TJSONObject;
begin
  Result := TJSONObject.Create;
  LSolver := TJSONObject.Create;
  Result.Add('solver', LSolver);
  LSolver.Add('attempted', ALedger.SolveAttempted);
  LSolver.Add('seed', Int64(ALedger.SolverOptions.Seed));
  LSolver.Add('frame_count_means_tokens', ALedger.SolverOptions.FrameCount);
  LSolver.Add('extent', 'prefix');
  LSolver.Add('max_backtracks', ALedger.SolverOptions.MaxBacktracks);
  LSolver.Add('state_cell_budget', ALedger.SolverOptions.StateCellBudget);
  if ALedger.SolveAttempted then
  begin
    LSolver.Add('status_ordinal', Ord(ALedger.SolveReport.Status));
    LSolver.Add('random_algorithm_version', ALedger.SolveReport.RandomAlgorithmVersion);
    LSolver.Add('solver_algorithm_version', ALedger.SolveReport.SolverAlgorithmVersion);
    LSolver.Add('graph_model_version', ALedger.SolveReport.GraphModelVersion);
    LSolver.Add('pipeline_algorithm_version', ALedger.SolveReport.PipelineAlgorithmVersion);
    LSolver.Add('failed_pass_index', ALedger.SolveReport.FailedPassIndex);
    LSolver.Add('contradiction_kind_ordinal', Ord(ALedger.SolveReport.Contradiction.Kind));
    LSolver.Add('trace_captured', ALedger.SolveReport.TraceCaptured);
  end;
  Result.Add('requested_token_count', ALedger.RequestedTokens);
  Result.Add('used_token_count', ALedger.UsedTokens);
  Result.Add('full_solved_duration_ms', ALedger.GeneratedDurationMilliseconds);
  Result.Add('final_rendered_span_ms', ALedger.FinalSpanMilliseconds);
  Result.Add('final_span_clipped', ALedger.FinalSpanClipped);
  Result.Add('output_frames', ALedger.OutputFrames);
  Result.Add('model_sha256', ALedger.ModelSha256);
  Result.Add('full_solved_tokens', TokenJSON(ALedger.GeneratedTokens));
  Result.Add('actually_rendered_tokens', TokenJSON(ALedger.RenderedTokens));
  Result.Add('unused_solved_suffix', TokenJSON(ALedger.GeneratedTokens, ALedger.UsedTokens));
end;

function ValidateOutputWave(const APath: String; const AFrames: Int64): String;
var
  LStream: TFileStream;
  LReader: TWaveFrameReader;
  LSamples: TAudioSamples;
begin
  LStream := TFileStream.Create(APath, fmOpenRead or fmShareDenyWrite);
  try
    Result := Sha256Stream(LStream, LStream.Size);
    LStream.Position := 0;
    LReader := TWaveFrameReader.Create(LStream);
    try
      Require((LReader.SampleRate = 16000) and (LReader.Channels = 2) and
        (LReader.FrameCount = AFrames) and (LReader.BitsPerSample = 16),
        'Saved comparator WAV geometry mismatch');
      repeat
        LSamples := LReader.ReadFrames(4096);
      until Length(LSamples) = 0;
    finally
      LReader.Free;
    end;
  finally
    LStream.Free;
  end;
end;

function ModelFileText(const APath: String; out ASha256: String): String;
var
  LBytes: TAudioBytes;
begin
  LBytes := ReadFileBytes(APath, 16 * 1024 * 1024);
  Require(Length(LBytes) > 0, 'Saved comparator model is empty');
  ASha256 := Sha256Bytes(LBytes);
  SetString(Result, PAnsiChar(@LBytes[0]), Length(LBytes));
end;

procedure RunStyleComparatorPacket(const AManifestPath, AOutputDirectory: String);
const
  Seeds: array[0..2] of Cardinal = (731, 1731, 2731);
var
  LInput: TStyleComparatorInput;
  LModels: array[0..2] of TStyleComparatorModels;
  LRoot: TJSONObject;
  LSeeds: TJSONArray;
  LExecutions: TJSONArray;
  LExecution: TJSONObject;
  LOptions: TStyleComparatorRenderOptions;
  LLedger: TStyleComparatorRenderLedger;
  LClip: TAudioClip;
  LSourceRuns: TStyleComparatorTokenRuns;
  LRenderedRuns: TStyleComparatorTokenRuns;
  LOutput: String;
  LStage: String;
  LStem: String;
  LModelPath: String;
  LWavePath: String;
  LModelText: String;
  LModelHash: String;
  LWaveHash: String;
  LSeedIndex: Integer;
  LExecutionIndex: Integer;
  LCompleted: Integer;
  LCase: TStyleComparatorCase;
  LFailed: Boolean;
begin
  LOutput := ExcludeTrailingPathDelimiter(ExpandFileName(AOutputDirectory));
  LStage := LOutput + '.attempt';
  Require(not FileExists(LOutput) and not DirectoryExists(LOutput) and
    not FileExists(LStage) and not DirectoryExists(LStage), 'Comparator output and attempt must be fresh');
  Require(DirectoryExists(ExtractFileDir(LOutput)), 'Comparator output parent must exist');
  LInput := ReadStyleComparatorInputFile(AManifestPath);
  for LSeedIndex := 0 to High(Seeds) do
  begin
    LModels[LSeedIndex] := BuildStyleComparatorModels(LInput, Seeds[LSeedIndex]);
  end;
  LSourceRuns := StyleComparatorInputTokenRuns(LInput.Source);
  LRoot := TJSONObject.Create;
  LClip := nil;
  try
    LRoot.Add('format', StyleComparatorPacketFormat);
    LRoot.Add('status', 'incomplete');
    LRoot.Add('grounded_acceptance', False);
    LRoot.Add('expected_render_count', 9);
    LRoot.Add('completed_render_count', 0);
    LRoot.Add('output_ms', 120000);
    LRoot.Add('sample_rate', 16000);
    LRoot.Add('channels', 2);
    LRoot.Add('level', 0.1);
    LRoot.Add('release_ms', 0);
    LRoot.Add('extent', 'prefix');
    LRoot.Add('maximum_tokens', MaximumStyleComparatorTokens);
    LRoot.Add('input_evidence', InputEvidenceJSON(LInput));
    LSeeds := TJSONArray.Create;
    LRoot.Add('derivations', LSeeds);
    LExecutions := TJSONArray.Create;
    LRoot.Add('executions', LExecutions);
    for LSeedIndex := 0 to High(Seeds) do
    begin
      LSeeds.Add(DerivationJSON(LModels[LSeedIndex]));
      for LCase := Low(TStyleComparatorCase) to High(TStyleComparatorCase) do
      begin
        LExecution := TJSONObject.Create;
        LExecution.Add('seed', Int64(Seeds[LSeedIndex]));
        LExecution.Add('case', CaseName(LCase));
        LExecution.Add('status', 'not_executed');
        LExecutions.Add(LExecution);
      end;
    end;
    Require(CreateDir(LStage), 'Could not create comparator attempt directory');
    WriteTextFile(IncludeTrailingPathDelimiter(LStage) + 'packet.json', LRoot.AsJSON);
    LCompleted := 0;
    LExecutionIndex := 0;
    LFailed := False;
    try
      for LSeedIndex := 0 to High(Seeds) do
      begin
        for LCase := Low(TStyleComparatorCase) to High(TStyleComparatorCase) do
        begin
          LLedger := Default(TStyleComparatorRenderLedger);
          LExecution := TJSONObject(LExecutions.Items[LExecutionIndex]);
          Inc(LExecutionIndex);
          if not LModels[LSeedIndex].CaseSupported[LCase] then
          begin
            LExecution.Strings['status'] := 'unsupported';
            LExecution.Add('reason', LModels[LSeedIndex].CaseReasons[LCase]);
            raise EAudio.Create('Comparator shuffle relationship unsupported; no redraw');
          end;
          LStem := IntToStr(Seeds[LSeedIndex]) + '-' + CaseName(LCase);
          LModelPath := IncludeTrailingPathDelimiter(LStage) + LStem + '.model.txt';
          LWavePath := IncludeTrailingPathDelimiter(LStage) + LStem + '.wav';
          WriteTextFile(LModelPath, LModels[LSeedIndex].ModelTexts[LCase]);
          LModelText := ModelFileText(LModelPath, LModelHash);
          LOptions := DefaultStyleComparatorRenderOptions(Seeds[LSeedIndex]);
          LClip := GenerateStyleComparator(LModelText, LOptions, LLedger);
          Require(LModelHash = LLedger.ModelSha256, 'Saved comparator model hash changed');
          SaveWavePcm16(LWavePath, LClip);
          FreeAndNil(LClip);
          LWaveHash := ValidateOutputWave(LWavePath, LLedger.OutputFrames);
          LExecution.Strings['status'] := 'completed_mechanical_execution';
          LExecution.Add('model_file', LStem + '.model.txt');
          LExecution.Add('model_sha256', LModelHash);
          LExecution.Add('wave_file', LStem + '.wav');
          LExecution.Add('wave_sha256', LWaveHash);
          LExecution.Add('render', RenderLedgerJSON(LLedger));
          SetLength(LRenderedRuns, 1);
          LRenderedRuns[0] := LLedger.RenderedTokens;
          LExecution.Add('rendered_token_marginal_distance',
            StyleComparatorTokenMarginalDistance(LSourceRuns, LRenderedRuns));
          if LModels[LSeedIndex].RelationshipComparable and (Length(LLedger.RenderedTokens) >= 3) then
          begin
            LExecution.Add('rendered_token_trigram_distance',
              StyleComparatorTokenRelationshipDistance(LSourceRuns, LRenderedRuns));
          end
          else
          begin
            LExecution.Add('rendered_token_trigram_distance', TJSONNull.Create);
          end;
          Inc(LCompleted);
          LRoot.Integers['completed_render_count'] := LCompleted;
          WriteTextFile(IncludeTrailingPathDelimiter(LStage) + 'packet.json', LRoot.AsJSON);
        end;
      end;
    except
      on E: Exception do
      begin
        FreeAndNil(LClip);
        LFailed := True;
        LRoot.Strings['status'] := 'failed_incomplete';
        LRoot.Add('failure_reason', E.Message);
        if LExecution.Strings['status'] = 'not_executed' then
        begin
          LExecution.Strings['status'] := 'failed';
          LExecution.Add('reason', E.Message);
          LExecution.Add('failed_render', RenderLedgerJSON(LLedger));
        end;
        WriteTextFile(IncludeTrailingPathDelimiter(LStage) + 'packet.json', LRoot.AsJSON);
      end;
    end;
    if LFailed then
    begin
      raise EAudio.Create('Comparator packet incomplete; retained attempt with explicit failure');
    end;
    Require(LCompleted = 9, 'Comparator packet did not complete all nine outputs');
    LRoot.Strings['status'] := 'completed_mechanical_execution';
    WriteTextFile(IncludeTrailingPathDelimiter(LStage) + 'packet.json', LRoot.AsJSON);
    if DirectoryExists(LOutput) or FileExists(LOutput) or not RenameFile(LStage, LOutput) then
    begin
      LRoot.Strings['status'] := 'failed_publication';
      LRoot.Add('failure_reason', 'candidate_could_not_be_published_to_fresh_output');
      WriteTextFile(IncludeTrailingPathDelimiter(LStage) + 'packet.json', LRoot.AsJSON);
      raise EAudio.Create('Comparator candidate could not be published to fresh output');
    end;
  finally
    LClip.Free;
    LRoot.Free;
  end;
end;

end.
