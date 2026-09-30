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
unit pythian.tools.corpus.intake;

{$mode delphi}
{$H+}

interface

uses
  Classes, pythian.corpus.intake, pythian.analysis,
  pythian.analysis.journal, pythian.wave.read, pythian.learning.journal;

const
  MaximumIntakeDocumentBytes = 4 * 1024 * 1024;

function ReadCorpusIntake(const APath: String): TCorpusIntakePlan;
function EncodeCorpusIntake(const APlan: TCorpusIntakePlan): UTF8String;
function CorpusIntakeAuditJSON(const APlan: TCorpusIntakePlan): UTF8String;

{ Owns detached declarations and open WAV handles. All registered sources,
  including parents and nontraining sources, are verified before admission.
  Sources must remain immutable during this sequential borrowed use. }
type
  TCorpusAdmission = class
  private
    FPlan: TCorpusIntakePlan;
    FFiles: array of TFileStream;
    FWaves: array of TWaveFrameReader;
    FJournalStreams: array of TMemoryStream;
    FJournals: array of TFeatureJournal;
    FPrepared: Boolean;
    procedure MemoryFlush;
    procedure VerifySources;
  public
    constructor Create(const APlan: TCorpusIntakePlan; const ABaseDirectory: String);
    destructor Destroy; override;
    { Existing total analysis feature/work ceilings apply to this in-memory
      consumer. No long-recording or musical/style-quality claim is made. }
    function TrainingSegments(const AOptions: TAnalysisOptions): TJournalTrainingSegments;
    property Plan: TCorpusIntakePlan read FPlan;
  end;

{ Fresh prefix only. Candidate validation/learning precede writes; sibling
  staging reserves publication and the audit is the final completion marker.
  This is not an atomic replacement of an existing multi-file result. }
procedure LearnCorpusIntake(const AManifestPath, AOutputPrefix: String;
  const AHistoryPath: String = ''; const AMaximumTokens: Integer = 16;
  const AOrder: Integer = 2);

implementation

uses
  SysUtils, Math, fpjson, jsonparser, jsonscanner,
  pythian.audio, pythian.hash, pythian.wave, pythian.analysis.wave,
  pythian.learning, pythian.wfc.learning.journal,
  pythian.tools.files, wfc_sequence, wfc_sequence_text;

procedure Require(const ACondition: Boolean; const AMessage: String);
begin
  if not ACondition then raise EAudio.Create(AMessage);
end;

procedure Fields(const AObject: TJSONObject; const ANames: String);
var
  LNames: TStringList;
  I, J: Integer;
begin
  LNames := TStringList.Create;
  try
    LNames.StrictDelimiter := True;
    LNames.Delimiter := ',';
    LNames.DelimitedText := ANames;
    Require(AObject.Count = LNames.Count, 'Unexpected intake fields');
    for I := 0 to AObject.Count - 1 do
    begin
      Require(LNames.IndexOf(AObject.Names[I]) >= 0, 'Unknown intake field');
      for J := 0 to I - 1 do
        Require(AObject.Names[J] <> AObject.Names[I], 'Duplicate intake field');
    end;
  finally
    LNames.Free;
  end;
end;

function Item(const AObject: TJSONObject; const AName: String;
  const AType: TJSONType): TJSONData;
begin
  Result := AObject.Find(AName);
  Require((Result <> nil) and (Result.JSONType = AType), 'Missing/invalid intake field: ' + AName);
end;

function Text(const AObject: TJSONObject; const AName: String): UTF8String;
begin
  Result := Item(AObject, AName, jtString).AsString;
end;

function IntegerField(const AObject: TJSONObject; const AName: String): Int64;
begin
  Require(TryStrToInt64(Item(AObject, AName, jtNumber).AsJSON, Result),
    'Intake frame/index requires an exact integer');
end;

function IndexField(const AObject: TJSONObject; const AName: String): Integer;
var
  LValue: Int64;
begin
  LValue := IntegerField(AObject, AName);
  Require((LValue >= Low(Integer)) and (LValue <= High(Integer)), 'Intake index exceeds integer bounds');
  Result := Integer(LValue);
end;

function BooleanField(const AObject: TJSONObject; const AName: String): Boolean;
begin
  Result := Item(AObject, AName, jtBoolean).AsBoolean;
end;

function NumberField(const AObject: TJSONObject; const AName: String): Double;
begin
  Result := Item(AObject, AName, jtNumber).AsFloat;
  RequireFinite(Result, 'Intake number');
end;

function Partition(const AName: String): TCorpusPartition;
var
  P: TCorpusPartition;
begin
  for P := Low(TCorpusPartition) to High(TCorpusPartition) do
    if AName = CorpusPartitionName(P) then Exit(P);
  raise EAudio.Create('Unknown intake partition');
end;

function ObjectAt(const AArray: TJSONArray; const AIndex: Integer): TJSONObject;
begin
  Require(AArray.Items[AIndex].JSONType = jtObject, 'Intake array requires objects');
  Result := TJSONObject(AArray.Items[AIndex]);
end;

function Parse(const APath: String): TJSONObject;
var
  LBytes: TAudioBytes;
  LText: UTF8String;
  LParser: TJSONParser;
  LData: TJSONData;
  I, LDepth: Integer;
  LQuoted, LEscaped: Boolean;
begin
  LBytes := ReadFileBytes(APath, MaximumIntakeDocumentBytes);
  Require(Length(LBytes) > 0, 'Empty intake document');
  LDepth := 0;
  LQuoted := False;
  LEscaped := False;
  for I := 0 to High(LBytes) do
  begin
    if LQuoted then
    begin
      if LEscaped then LEscaped := False
      else if LBytes[I] = 92 then LEscaped := True
      else if LBytes[I] = 34 then LQuoted := False;
    end
    else if LBytes[I] = 34 then LQuoted := True
    else if LBytes[I] in [91, 123] then
    begin
      Inc(LDepth);
      Require(LDepth <= 8, 'Intake nesting budget exceeded');
    end
    else if LBytes[I] in [93, 125] then Dec(LDepth);
  end;
  SetString(LText, PAnsiChar(@LBytes[0]), Length(LBytes));
  LParser := TJSONParser.Create(LText, [joUTF8, joStrict]);
  try
    LData := LParser.Parse;
    try
      Require((LData <> nil) and (LData.JSONType = jtObject), 'Intake root requires an object');
      Result := TJSONObject(LData);
      LData := nil;
    finally
      LData.Free;
    end;
  finally
    LParser.Free;
  end;
end;

function ReadCorpusIntake(const APath: String): TCorpusIntakePlan;
var
  LRoot, LObject: TJSONObject;
  LArray, LExposure: TJSONArray;
  LDefinition: TCorpusIntakeDefinition;
  I, J: Integer;
  P: TCorpusPartition;
begin
  LDefinition := Default(TCorpusIntakeDefinition);
  LRoot := Parse(APath);
  try
    Fields(LRoot, 'kind,version,coordinate_units,style_id,families,sources,ranges');
    Require((Text(LRoot, 'kind') = 'pythian-corpus-intake') and
      (IntegerField(LRoot, 'version') = CorpusIntakeVersion) and
      (Text(LRoot, 'coordinate_units') = 'source_frames'), 'Unsupported intake format/coordinate units');
    LDefinition.StyleId := Text(LRoot, 'style_id');
    LArray := TJSONArray(Item(LRoot, 'families', jtArray));
    Require(LArray.Count <= MaximumIntakeSources, 'Intake family count exceeds bounds');
    SetLength(LDefinition.Families, LArray.Count);
    for I := 0 to LArray.Count - 1 do
    begin
      LObject := ObjectAt(LArray, I);
      Fields(LObject, 'id,work_id,identity_evidence,partition,verified,previously_used,prior_exposure');
      with LDefinition.Families[I] do
      begin
        Id := Text(LObject, 'id');
        WorkId := Text(LObject, 'work_id');
        IdentityEvidence := Text(LObject, 'identity_evidence');
        Partition := pythian.tools.corpus.intake.Partition(Text(LObject, 'partition'));
        Verified := BooleanField(LObject, 'verified');
        PreviouslyUsed := BooleanField(LObject, 'previously_used');
        LExposure := TJSONArray(Item(LObject, 'prior_exposure', jtArray));
        Require(LExposure.Count <= 3, 'Too many prior exposure partitions');
        for J := 0 to LExposure.Count - 1 do
        begin
          Require(LExposure.Items[J].JSONType = jtString, 'Exposure requires partition names');
          P := pythian.tools.corpus.intake.Partition(LExposure.Items[J].AsString);
          Require(not (P in PriorExposure), 'Duplicate prior exposure partition');
          Include(PriorExposure, P);
        end;
      end;
    end;
    LArray := TJSONArray(Item(LRoot, 'sources', jtArray));
    Require(LArray.Count <= MaximumIntakeSources, 'Intake source count exceeds bounds');
    SetLength(LDefinition.Sources, LArray.Count);
    for I := 0 to LArray.Count - 1 do
    begin
      LObject := ObjectAt(LArray, I);
      Fields(LObject, 'id,path,sha256,recording_id,family,sample_rate,channels,frame_count,' +
        'acquisition,license_notice,preparation_policy,preparation_sha256,preparation_accepted,' +
        'peak_ceiling,parent,parent_first_frame,parent_end_frame,parent_gain,single_song_id,song_evidence');
      with LDefinition.Sources[I] do
      begin
        Id := Text(LObject, 'id'); Path := Text(LObject, 'path');
        Sha256 := Text(LObject, 'sha256'); RecordingId := Text(LObject, 'recording_id');
        Family := IndexField(LObject, 'family'); SampleRate := IndexField(LObject, 'sample_rate');
        Channels := IndexField(LObject, 'channels'); FrameCount := IntegerField(LObject, 'frame_count');
        Acquisition := Text(LObject, 'acquisition'); LicenseNotice := Text(LObject, 'license_notice');
        PreparationPolicy := Text(LObject, 'preparation_policy');
        PreparationSha256 := Text(LObject, 'preparation_sha256');
        PreparationAccepted := BooleanField(LObject, 'preparation_accepted');
        PeakCeiling := NumberField(LObject, 'peak_ceiling'); Parent := IndexField(LObject, 'parent');
        ParentFirstFrame := IntegerField(LObject, 'parent_first_frame');
        ParentEndFrame := IntegerField(LObject, 'parent_end_frame'); ParentGain := NumberField(LObject, 'parent_gain');
        SingleSongId := Text(LObject, 'single_song_id'); SongEvidence := Text(LObject, 'song_evidence');
      end;
    end;
    LArray := TJSONArray(Item(LRoot, 'ranges', jtArray));
    Require(LArray.Count <= MaximumIntakeRanges, 'Intake range count exceeds bounds');
    SetLength(LDefinition.Ranges, LArray.Count);
    for I := 0 to LArray.Count - 1 do
    begin
      LObject := ObjectAt(LArray, I);
      Fields(LObject, 'source,first_frame,end_frame,song_id,boundary_evidence,multiplicity');
      with LDefinition.Ranges[I] do
      begin
        Source := IndexField(LObject, 'source'); FirstFrame := IntegerField(LObject, 'first_frame');
        EndFrame := IntegerField(LObject, 'end_frame'); SongId := Text(LObject, 'song_id');
        BoundaryEvidence := Text(LObject, 'boundary_evidence'); Multiplicity := IndexField(LObject, 'multiplicity');
      end;
    end;
    Result := TCorpusIntakePlan.Create(LDefinition);
  finally
    LRoot.Free;
  end;
end;

function EncodeCorpusIntake(const APlan: TCorpusIntakePlan): UTF8String;
var
  D: TCorpusIntakeDefinition;
  R, O: TJSONObject;
  A, E: TJSONArray;
  I: Integer;
  P: TCorpusPartition;
begin
  Require(APlan <> nil, 'Cannot encode absent intake plan');
  D := APlan.CopyDefinition;
  R := TJSONObject.Create;
  try
    R.Add('kind', 'pythian-corpus-intake'); R.Add('version', CorpusIntakeVersion);
    R.Add('coordinate_units', 'source_frames'); R.Add('style_id', D.StyleId);
    A := TJSONArray.Create; R.Add('families', A);
    for I := 0 to High(D.Families) do
    begin
      O := TJSONObject.Create; A.Add(O);
      with D.Families[I] do
      begin
        O.Add('id', Id); O.Add('work_id', WorkId); O.Add('identity_evidence', IdentityEvidence);
        O.Add('partition', CorpusPartitionName(Partition)); O.Add('verified', Verified);
        O.Add('previously_used', PreviouslyUsed);
        E := TJSONArray.Create; O.Add('prior_exposure', E);
        for P := Low(TCorpusPartition) to High(TCorpusPartition) do
          if P in PriorExposure then E.Add(CorpusPartitionName(P));
      end;
    end;
    A := TJSONArray.Create; R.Add('sources', A);
    for I := 0 to High(D.Sources) do
    begin
      O := TJSONObject.Create; A.Add(O);
      with D.Sources[I] do
      begin
        O.Add('id', Id); O.Add('path', Path); O.Add('sha256', Sha256);
        O.Add('recording_id', RecordingId); O.Add('family', Family);
        O.Add('sample_rate', SampleRate); O.Add('channels', Channels); O.Add('frame_count', FrameCount);
        O.Add('acquisition', Acquisition); O.Add('license_notice', LicenseNotice);
        O.Add('preparation_policy', PreparationPolicy); O.Add('preparation_sha256', PreparationSha256);
        O.Add('preparation_accepted', PreparationAccepted); O.Add('peak_ceiling', PeakCeiling);
        O.Add('parent', Parent); O.Add('parent_first_frame', ParentFirstFrame);
        O.Add('parent_end_frame', ParentEndFrame); O.Add('parent_gain', ParentGain);
        O.Add('single_song_id', SingleSongId); O.Add('song_evidence', SongEvidence);
      end;
    end;
    A := TJSONArray.Create; R.Add('ranges', A);
    for I := 0 to High(D.Ranges) do
    begin
      O := TJSONObject.Create; A.Add(O);
      with D.Ranges[I] do
      begin
        O.Add('source', Source); O.Add('first_frame', FirstFrame); O.Add('end_frame', EndFrame);
        O.Add('song_id', SongId); O.Add('boundary_evidence', BoundaryEvidence); O.Add('multiplicity', Multiplicity);
      end;
    end;
    Result := R.AsJSON;
    Require(Length(Result) <= MaximumIntakeDocumentBytes, 'Encoded intake exceeds document budget');
  finally
    R.Free;
  end;
end;

function CorpusIntakeAuditJSON(const APlan: TCorpusIntakePlan): UTF8String;
var
  C: TCorpusIntakeCoverage;
  R, O: TJSONObject;
  P: TCorpusPartition;
begin
  C := APlan.Coverage;
  R := TJSONObject.Create;
  try
    R.Add('kind', 'pythian-corpus-intake-audit'); R.Add('version', CorpusIntakeVersion);
    R.Add('musical_acceptance', False); R.Add('identity_basis', 'caller-declared family/work evidence');
    for P := Low(TCorpusPartition) to High(TCorpusPartition) do
    begin
      O := TJSONObject.Create; R.Add(CorpusPartitionName(P), O);
      O.Add('unique_source_seconds', C.UniqueSeconds[P]);
      O.Add('unknown_song_seconds', C.UnknownBoundarySeconds[P]);
      O.Add('declared_verified_groups', C.DeclaredVerifiedGroups[P]);
    end;
    Result := R.AsJSON;
  finally
    R.Free;
  end;
end;

constructor TCorpusAdmission.Create(const APlan: TCorpusIntakePlan; const ABaseDirectory: String);
var
  D: TCorpusIntakeDefinition;
  I, J: Integer;
  LPath: String;
  LSamples, LParentSamples: TAudioSamples;
  LOffset: Int64;
  LTolerance: Double;
begin
  inherited Create;
  Require(APlan <> nil, 'Admission requires an intake plan');
  FPlan := TCorpusIntakePlan.Create(APlan.CopyDefinition);
  D := FPlan.CopyDefinition;
  SetLength(FFiles, Length(D.Sources)); SetLength(FWaves, Length(D.Sources));
  SetLength(FJournalStreams, Length(D.Sources)); SetLength(FJournals, Length(D.Sources));
  for I := 0 to High(D.Sources) do
  begin
    LPath := D.Sources[I].Path;
    if (ExtractFileDrive(LPath) = '') and not (LPath[1] in ['/', '\']) then
      LPath := IncludeTrailingPathDelimiter(ABaseDirectory) + LPath;
    FFiles[I] := TFileStream.Create(LPath, fmOpenRead or fmShareDenyWrite);
    Require((FFiles[I].Size >= 12) and (FFiles[I].Size <= MaximumWaveBytes), 'Intake WAV exceeds file byte envelope');
    Require(Sha256Stream(FFiles[I], FFiles[I].Size) = D.Sources[I].Sha256,
      'Intake WAV source digest mismatch before decoding');
    FFiles[I].Position := 0;
    FWaves[I] := TWaveFrameReader.Create(FFiles[I]);
    Require((FWaves[I].SampleRate = D.Sources[I].SampleRate) and
      (FWaves[I].Channels = D.Sources[I].Channels) and (FWaves[I].FrameCount = D.Sources[I].FrameCount) and
      (FWaves[I].FrameCount <= MaximumClipSamples div FWaves[I].Channels), 'Intake WAV geometry/sample envelope mismatch');
    Require(HashText(D.Sources[I].PreparationPolicy) = D.Sources[I].PreparationSha256,
      'Intake preparation-policy digest mismatch');
    LOffset := 0;
    while LOffset < FWaves[I].FrameCount do
    begin
      FWaves[I].SeekFrame(LOffset);
      LSamples := FWaves[I].ReadFrames;
      Require(Length(LSamples) > 0, 'Unexpected empty WAV read');
      for J := 0 to High(LSamples) do
        Require(Abs(LSamples[J]) <= D.Sources[I].PeakCeiling, 'Intake WAV exceeds declared preparation headroom');
      if D.Sources[I].Parent >= 0 then
      begin
        FWaves[D.Sources[I].Parent].SeekFrame(D.Sources[I].ParentFirstFrame + LOffset);
        LParentSamples := FWaves[D.Sources[I].Parent].ReadFrames(Length(LSamples) div FWaves[I].Channels);
        Require(Length(LParentSamples) = Length(LSamples), 'Parent WAV mapping ended early');
        LTolerance := (1 + D.Sources[I].ParentGain) / 32768;
        for J := 0 to High(LSamples) do
          Require(Abs(LSamples[J] - LParentSamples[J] * D.Sources[I].ParentGain) <= LTolerance,
            'Prepared WAV is not the declared exact-frame crop/uniform gain of its parent');
      end;
      Inc(LOffset, Length(LSamples) div FWaves[I].Channels);
    end;
  end;
  VerifySources;
end;

destructor TCorpusAdmission.Destroy;
var
  I: Integer;
begin
  for I := 0 to High(FJournals) do FJournals[I].Free;
  for I := 0 to High(FJournalStreams) do FJournalStreams[I].Free;
  for I := 0 to High(FWaves) do FWaves[I].Free;
  for I := 0 to High(FFiles) do FFiles[I].Free;
  FPlan.Free;
  inherited Destroy;
end;

procedure TCorpusAdmission.MemoryFlush;
begin
  { Memory storage has no external durability boundary. }
end;

procedure TCorpusAdmission.VerifySources;
var
  D: TCorpusIntakeDefinition;
  I: Integer;
begin
  D := FPlan.CopyDefinition;
  for I := 0 to High(FFiles) do
  begin
    FFiles[I].Position := 0;
    Require(Sha256Stream(FFiles[I], FFiles[I].Size) = D.Sources[I].Sha256,
      'Intake WAV bytes differ from the declared source digest');
  end;
end;

function TCorpusAdmission.TrainingSegments(const AOptions: TAnalysisOptions): TJournalTrainingSegments;
var
  D: TCorpusIntakeDefinition;
  R: TCorpusIntakeRanges;
  LBinding: TFeatureJournalBinding;
  LBatch: TWaveFeatureBatch;
  LCounts: array of Integer;
  LTotalCount, LCount, I, J: Integer;
  LWork, LTotalWork, LFirst, LLast: Int64;
begin
  R := FPlan.TrainingRanges;
  D := FPlan.CopyDefinition;
  Require(not FPrepared, 'Admission learning preparation is single use');
  FPrepared := True;
  SetLength(LCounts, Length(D.Sources));
  LTotalCount := 0; LTotalWork := 0;
  for I := 0 to High(R) do
  begin
    J := R[I].Source;
    if LCounts[J] > 0 then Continue;
    PlanAudioAnalysis(Integer(D.Sources[J].FrameCount), D.Sources[J].Channels, AOptions, LCount, LWork);
    Require((LCount > 0) and (LCount <= MaximumAnalysisFrames - LTotalCount) and
      (LWork <= MaximumAnalysisWork - LTotalWork), 'Intake consumer aggregate analysis budget exceeded');
    LCounts[J] := LCount; Inc(LTotalCount, LCount); Inc(LTotalWork, LWork);
  end;
  for J := 0 to High(D.Sources) do
  begin
    if LCounts[J] = 0 then Continue;
    LBinding := Default(TFeatureJournalBinding);
    LBinding.SourceSha256 := D.Sources[J].Sha256; LBinding.SampleRate := D.Sources[J].SampleRate;
    LBinding.Channels := D.Sources[J].Channels; LBinding.FrameCount := D.Sources[J].FrameCount;
    LBinding.Options := AOptions;
    FJournalStreams[J] := TMemoryStream.Create;
    FJournals[J] := TFeatureJournal.Create(FJournalStreams[J], LBinding, MemoryFlush, True);
    repeat
      LBatch := AnalyzeWaveBatch(FWaves[J], AOptions, FJournals[J].NextFeature);
      if Length(LBatch.Features) > 0 then FJournals[J].Append(LBatch);
    until LBatch.Completed;
    Require(FJournals[J].Completed, 'Intake journal did not complete');
  end;
  Result := nil; SetLength(Result, Length(R));
  for I := 0 to High(R) do
  begin
    LFirst := (R[I].FirstFrame + AOptions.HopFrames - 1) div AOptions.HopFrames;
    { The preceding spectrum used by flux must also be inside this song. }
    if R[I].FirstFrame > 0 then Inc(LFirst);
    LLast := (R[I].EndFrame - AOptions.WindowFrames) div AOptions.HopFrames;
    Require((R[I].EndFrame - R[I].FirstFrame >= AOptions.WindowFrames) and
      (LLast >= LFirst), 'Song range has no complete context-contained analysis window');
    Result[I].Journal := FJournals[R[I].Source];
    Result[I].FirstFeature := LFirst; Result[I].FeatureCount := LLast - LFirst + 1;
    Result[I].Multiplicity := R[I].Multiplicity;
  end;
  VerifySources;
end;

procedure LearnCorpusIntake(const AManifestPath, AOutputPrefix, AHistoryPath: String;
  const AMaximumTokens, AOrder: Integer);
var
  P, H, Reloaded: TCorpusIntakePlan;
  Admission: TCorpusAdmission;
  Reader: TJournalTrainingReader;
  Palette: TAcousticPalette;
  Model: TWfcSequenceModel;
  LText, LAudit, LStage, S: String;
  LMoved: array[0..1] of Boolean;
  O: TJSONObject;
  LCenters, LCenter: TJSONArray;
  LDefinition: TCorpusIntakeDefinition;
  LPublished: TCorpusIntakePlan;
  LReserved: Boolean;
  I, J: Integer;
  LSegments: TJournalTrainingSegments;
begin
  P := nil; H := nil; Admission := nil; Reader := nil; Palette := nil; Model := nil;
  LPublished := nil; LReserved := False;
  for S in ['.json', '.wfcs', '.audit.json'] do
    Require(not FileExists(AOutputPrefix + S), 'Corpus publication requires a fresh prefix');
  LStage := AOutputPrefix + '.publishing';
  Require(not DirectoryExists(LStage), 'Corpus publication staging prefix already exists');
  try
    P := ReadCorpusIntake(AManifestPath);
    if AHistoryPath <> '' then
    begin
      H := ReadCorpusIntake(AHistoryPath);
      RequireIntakeHistory(H, P);
    end;
    Admission := TCorpusAdmission.Create(P, ExtractFilePath(ExpandFileName(AManifestPath)));
    LSegments := Admission.TrainingSegments(DefaultAnalysisOptions);
    Reader := TJournalTrainingReader.Create(LSegments);
    Palette := TAcousticPalette.CreateFromReader(Reader, AMaximumTokens);
    Model := LearnJournalAcousticModel(Reader, Palette, AOrder);
    LText := EncodeWfcSequenceText(Model);
    LDefinition := P.CopyDefinition;
    for I := 0 to High(LDefinition.Sources) do
    begin
      S := LDefinition.Sources[I].Path;
      if (ExtractFileDrive(S) = '') and not (S[1] in ['/', '\']) then
        S := ExtractFilePath(ExpandFileName(AManifestPath)) + S;
      LDefinition.Sources[I].Path := ExtractRelativePath(
        ExtractFilePath(ExpandFileName(AOutputPrefix)), ExpandFileName(S));
    end;
    LPublished := TCorpusIntakePlan.Create(LDefinition);
    O := TJSONObject(GetJSON(CorpusIntakeAuditJSON(P)));
    try
      O.Add('verified_file_bytes', True); O.Add('training_segments', Reader.SegmentCount);
      O.Add('training_observations', Reader.ObservationCount);
      O.Add('model_sha256', HashText(LText));
      O.Add('manifest_sha256', HashText(EncodeCorpusIntake(LPublished)));
      O.Add('analysis_window_frames', DefaultAnalysisOptions.WindowFrames);
      O.Add('analysis_hop_frames', DefaultAnalysisOptions.HopFrames);
      O.Add('analysis_silence_rms', DefaultAnalysisOptions.SilenceRms);
      LCenters := TJSONArray.Create; O.Add('acoustic_palette_centers', LCenters);
      for I := 0 to Palette.Count - 1 do
      begin
        LCenter := TJSONArray.Create; LCenters.Add(LCenter);
        for J := 0 to 14 do LCenter.Add(Palette.CenterAt(I)[J]);
      end;
      O.Add('model_scope', 'raw acoustic palette and WFC sequence, not inferred musical style');
      LAudit := O.AsJSON;
    finally
      O.Free;
    end;
    Admission.VerifySources;
    Require(CreateDir(LStage), 'Cannot reserve corpus publication prefix');
    LReserved := True;
    LMoved[0] := False; LMoved[1] := False;
    try
      WriteTextFile(LStage + PathDelim + 'intake.json', EncodeCorpusIntake(LPublished));
      Reloaded := ReadCorpusIntake(LStage + PathDelim + 'intake.json');
      try
        Require(EncodeCorpusIntake(Reloaded) = EncodeCorpusIntake(LPublished), 'Staged intake reload differs');
      finally
        Reloaded.Free;
      end;
      WriteTextFile(LStage + PathDelim + 'model.wfcs', LText);
      WriteTextFile(LStage + PathDelim + 'audit.json', LAudit);
      for S in ['.json', '.wfcs', '.audit.json'] do
        Require(not FileExists(AOutputPrefix + S), 'Corpus output appeared during publication');
      Require(RenameFile(LStage + PathDelim + 'intake.json', AOutputPrefix + '.json'), 'Cannot publish intake');
      LMoved[0] := True;
      Require(RenameFile(LStage + PathDelim + 'model.wfcs', AOutputPrefix + '.wfcs'), 'Cannot publish corpus model');
      LMoved[1] := True;
      Require(RenameFile(LStage + PathDelim + 'audit.json', AOutputPrefix + '.audit.json'), 'Cannot publish corpus audit');
    except
      if LMoved[1] then DeleteFile(AOutputPrefix + '.wfcs');
      if LMoved[0] then DeleteFile(AOutputPrefix + '.json');
      raise;
    end;
  finally
    if LReserved then
    begin
      DeleteFile(LStage + PathDelim + 'intake.json');
      DeleteFile(LStage + PathDelim + 'model.wfcs');
      DeleteFile(LStage + PathDelim + 'audit.json');
      RemoveDir(LStage);
    end;
    LPublished.Free; Model.Free; Palette.Free; Reader.Free; Admission.Free; H.Free; P.Free;
  end;
end;

end.
