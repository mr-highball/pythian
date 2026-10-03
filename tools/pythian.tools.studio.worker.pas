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
unit pythian.tools.studio.worker;

{$mode delphi}
{$H+}

interface

uses
  fpjson, pythian.progress;

type
  TStudioWorkerCheck = procedure of object;
  TStudioWorkerExtension = function(const ACatalogRoot, AJobId, ALibraryRoot: String;
    const ARequest: TJSONObject; const ACheck: TStudioWorkerCheck;
    const AProgress: TWorkProgressCallback): TJSONObject;

{ One claimed job, no service/session/browser dependency. Exact production
  durations are 20..40 seconds; missing modes never fall back to inferred notes. }
function RunStudioWorker(const ACatalogRoot, AJobId, ALibraryRoot: String;
  const AExtension: TStudioWorkerExtension = nil): Boolean;

implementation

uses
  Classes,
  SysUtils,
  Math,
  pythian.audio,
  pythian.hash,
  pythian.wave.read,
  pythian.wave.stream,
  pythian.analysis,
  pythian.analysis.wave,
  pythian.analysis.journal,
  pythian.learning,
  pythian.learning.journal,
  pythian.learning.selection,
  pythian.learning.render.stream,
  pythian.learning.binding,
  pythian.wfc.learning,
  pythian.wfc.learning.journal,
  pythian.wfc.learning.profile,
  pythian.wfc.stream,
  pythian.wfc.audio.stream,
  wfc,
  wfc_sequence,
  wfc_sequence_graph,
  wfc_sequence_text,
  pythian.tools.annotations.catalog,
  pythian.tools.annotations.proposal,
  pythian.tools.listen.catalog,
  pythian.tools.studio.jobs,
  pythian.tools.studio.live,
  pythian.tools.studio.&library,
  pythian.tools.studio.&library.discovery;

const
  CProfileFormat = 'pythian.studio.acoustic.profile.v1';
  CPolicy = 'studio_raw_grain_v1;range-relative journals;4096-frame Hann windows;' +
    '1024-frame hops;source-aware weighted candidate bins;128-cell WFC chunks;' +
    'exact output clock by final-grain clipping;no semantic note or style acceptance';
  CBatchFeatures = 128;
  CCandidateBins = 4;

type
  TStudioWork = class;

  TCheckedStream = class(TFileStream)
  private
    FWork: TStudioWork;
    FHashStage: String;
  public
    constructor Create(const APath: String; const AWork: TStudioWork);
    function Read(var ABuffer; ACount: LongInt): LongInt; override;
    procedure HashProgress(const AProgress: TWorkProgress);
    function HashWithProgress(const AStage: String): String;
  end;

  TRangeAnalysis = class(TAudioAnalysisSource)
  private
    FWave: TWaveFrameReader;
    FOrigin: Int64;
  public
    constructor Create(const AWave: TWaveFrameReader; const AOrigin: Int64;
      const AFrames: Integer);
    procedure ReadWindow(const AStartFrame, AValidFrames: Integer;
      var ASamples: TAudioSamples); override;
  end;

  TSourceHandle = record
    Hash: String;
    Stream: TCheckedStream;
    Wave: TWaveFrameReader;
  end;

  TRangeHandle = record
    SourceIndex: Integer;
    Origin: Int64;
    Frames: Int64;
    Weight: Integer;
    JournalStream: TFileStream;
    Journal: TFeatureJournal;
  end;

  TStudioWork = class
  private
    FCatalogRoot: String;
    FJobId: String;
    FDirectory: String;
    FRequest: TJSONObject;
    FStarted: QWord;
    FSources: array of TSourceHandle;
    FRanges: array of TRangeHandle;
    FOptions: TAnalysisOptions;
    FReceipt: TJSONObject;
    FProfile: TJournalModelProfile;
    FTrainingHash: String;
    FModelRoot: String;
    FModelReused: Boolean;
    FPartial: TJSONObject;
    FCurrentOrdinal: Integer;
    FGrainLedger: TJSONArray;
    FStreaming: Boolean;
    FLastProgressAt: QWord;
    FLastProgressStage: String;
    FLastProgressPass: Integer;
    FLastProgressDone: Int64;
    FLastProgressTotal: Int64;
    FLearningStage: String;
    FFirstLearningPass: Integer;
    procedure FlushJournal;
    procedure Progress(const AStage: String; const ADone, ATotal: Int64;
      const AUnit: String = ''; const APass: Integer = 0);
    procedure LearningProgress(const AProgress: TWorkProgress);
    procedure WorkProgress(const AProgress: TWorkProgress);
    procedure LibraryProgress(const AStage: String; const ADone, ATotal: Int64);
    procedure Preflight;
    procedure VerifySources(const AStage: String = 'verify_output_sources');
    function TryReuseModel(const AExpected: TJSONObject = nil;
      const AModelText: String = ''): Boolean;
    procedure Train;
    function MakeProfile(const AReader: TJournalTrainingReader;
      const APalette: TAcousticPalette; const AModel: TWfcSequenceModel;
      const APool: TJournalCandidatePool; const AModelText: String): TJSONObject;
    function ReadCandidate(const ACandidate: TJournalRepresentative): TAudioSamples;
    procedure RecordGrain(const AOrdinal: Int64; const AToken: Integer;
      const ACandidate: TJournalRepresentative);
    function RenderSeed(const ASeed, AOrdinal: Integer): TJSONObject;
    procedure RenderLive(const AResult: TJSONObject);
    procedure PublishListening(const AOutputs: TJSONArray);
    function InspectSource: TJSONObject;
  public
    constructor Create(const ACatalogRoot, AJobId: String; const ARequest: TJSONObject);
    destructor Destroy; override;
    procedure Check;
    function FailureResults(const AStatus: String): TJSONObject;
    function Run(const ALibraryRoot: String;
      const AExtension: TStudioWorkerExtension): TJSONObject;
  end;

procedure Need(const ACondition: Boolean; const AMessage: String);
begin
  if not ACondition then
  begin
    raise EAudio.Create(AMessage);
  end;
end;

function HashFile(const AStream: TStream): String;
begin
  AStream.Position := 0;
  Result := Sha256Stream(AStream, AStream.Size);
end;

procedure WriteTextNew(const APath, AText: String);
var
  LStream: TFileStream;
begin
  Need(not FileExists(APath), 'Model artifact already exists');
  LStream := TFileStream.Create(APath, fmCreate or fmShareExclusive);
  try
    if Length(AText) > 0 then
    begin
      LStream.WriteBuffer(AText[1], Length(AText));
    end;
    Need(FileFlush(LStream.Handle), 'Cannot flush model artifact');
  finally
    LStream.Free;
  end;
end;

function ReadText(const APath: String): String;
var
  LStream: TFileStream;
begin
  LStream := TFileStream.Create(APath, fmOpenRead or fmShareDenyWrite);
  try
    Need((LStream.Size > 0) and (LStream.Size <= 16777216), 'Model text exceeds bound');
    SetLength(Result, Integer(LStream.Size));
    LStream.ReadBuffer(Result[1], Length(Result));
  finally
    LStream.Free;
  end;
end;

constructor TCheckedStream.Create(const APath: String; const AWork: TStudioWork);
begin
  inherited Create(APath, fmOpenRead or fmShareDenyWrite);
  FWork := AWork;
end;

function TCheckedStream.Read(var ABuffer; ACount: LongInt): LongInt;
begin
  FWork.Check;
  Result := inherited Read(ABuffer, ACount);
end;

procedure TCheckedStream.HashProgress(const AProgress: TWorkProgress);
begin
  FWork.Progress(FHashStage, AProgress.Done, AProgress.Total, WorkUnitName(AProgress.Units));
end;

function TCheckedStream.HashWithProgress(const AStage: String): String;
begin
  FHashStage := AStage;
  try
    Position := 0;
    Result := Sha256Stream(Self, Size, HashProgress);
  finally
    FHashStage := '';
  end;
end;

constructor TRangeAnalysis.Create(const AWave: TWaveFrameReader;
  const AOrigin: Int64; const AFrames: Integer);
begin
  inherited Create(AWave.SampleRate, AWave.Channels, AFrames);
  Need((AOrigin >= 0) and (AFrames >= 0) and
    (AOrigin + AFrames <= AWave.FrameCount), 'Analysis range leaves original source');
  FWave := AWave;
  FOrigin := AOrigin;
end;

procedure TRangeAnalysis.ReadWindow(const AStartFrame, AValidFrames: Integer;
  var ASamples: TAudioSamples);
begin
  FWave.SeekFrame(FOrigin + AStartFrame);
  ASamples := FWave.ReadFrames(AValidFrames);
  Need(Length(ASamples) = AValidFrames * Channels, 'Analysis source window is incomplete');
end;

constructor TStudioWork.Create(const ACatalogRoot, AJobId: String;
  const ARequest: TJSONObject);
var
  LRows: TJSONArray;
  LRow: TJSONObject;
  LIndex: Integer;
begin
  inherited Create;
  FCatalogRoot := ExpandFileName(ACatalogRoot);
  FJobId := AJobId;
  FDirectory := StudioJobDirectory(FCatalogRoot, FJobId);
  FRequest := ARequest;
  FStarted := GetTickCount64;
  FOptions := DefaultAnalysisOptions;
  FCurrentOrdinal := -1;
  FPartial := TJSONObject.Create;
  FPartial.Add('grounded_acceptance', False);
  if FRequest.Strings['kind'] = 'train_generate' then
  begin
    FPartial.Add('expected_render_count', FRequest.Arrays['seeds'].Count);
    FPartial.Add('completed_render_count', 0);
    FPartial.Add('publication_status', 'not_published');
    FPartial.Add('outputs', TJSONArray.Create);
    LRows := TJSONArray.Create;
    FPartial.Add('seed_outcomes', LRows);
    for LIndex := 0 to FRequest.Arrays['seeds'].Count - 1 do
    begin
      LRow := TJSONObject.Create;
      LRows.Add(LRow);
      LRow.Add('seed', FRequest.Arrays['seeds'].Integers[LIndex]);
      LRow.Add('ordinal', LIndex);
      LRow.Add('status', 'not_attempted');
    end;
  end;
end;

destructor TStudioWork.Destroy;
var
  LIndex: Integer;
begin
  FProfile.Free;
  FReceipt.Free;
  FPartial.Free;
  for LIndex := 0 to High(FRanges) do
  begin
    FRanges[LIndex].Journal.Free;
    FRanges[LIndex].JournalStream.Free;
  end;
  for LIndex := 0 to High(FSources) do
  begin
    FSources[LIndex].Wave.Free;
    FSources[LIndex].Stream.Free;
  end;
  inherited Destroy;
end;

function TStudioWork.FailureResults(const AStatus: String): TJSONObject;
begin
  if (FCurrentOrdinal >= 0) and (FPartial.Find('seed_outcomes') <> nil) then
  begin
    if FPartial.Arrays['seed_outcomes'].Objects[FCurrentOrdinal].Strings['status'] = 'rendering' then
    begin
      FPartial.Arrays['seed_outcomes'].Objects[FCurrentOrdinal].Strings['status'] := AStatus;
    end;
  end;
  Result := TJSONObject(FPartial.Clone);
end;

procedure TStudioWork.Check;
begin
  if StudioJobCancelled(FCatalogRoot, FJobId) then
  begin
    raise EStudioJobCancelled.Create('Studio job cancellation requested');
  end;
  Need(GetTickCount64 - FStarted <= QWord(StudioJobRequestRuntimeSeconds(FRequest)) * 1000,
    'Studio worker exceeded its wall-clock budget');
  if FRequest.Strings['kind'] = 'stream_generate' then
  begin
    Need(FStreaming or (GetTickCount64 - FStarted <= QWord(MaximumStudioJobSeconds) * 1000),
      'Live preparation exceeded ten minutes; reduce the selected source material');
    Need(StudioLiveClientActive(FDirectory, FStarted),
      'Playback disconnected for 90 seconds; start a new session');
  end;
end;

procedure TStudioWork.Progress(const AStage: String; const ADone, ATotal: Int64;
  const AUnit: String; const APass: Integer);
begin
  Check;
  { Big Boss: cancellation is checked at every callback, immutable status writes
    at most twice a second within a pass. Boundaries are always published. }
  if (AStage = FLastProgressStage) and (APass = FLastProgressPass) and
    (ATotal = FLastProgressTotal) and (ADone >= FLastProgressDone) and
    ((ADone = FLastProgressDone) or
     ((ADone < ATotal) and (GetTickCount64 - FLastProgressAt < 500))) then Exit;
  AdvanceStudioJob(FCatalogRoot, FJobId, 'running', AStage, ADone, ATotal,
    nil, '', '', AUnit, APass);
  FLastProgressAt := GetTickCount64;
  FLastProgressStage := AStage;
  FLastProgressPass := APass;
  FLastProgressDone := ADone;
  FLastProgressTotal := ATotal;
end;

procedure TStudioWork.LearningProgress(const AProgress: TWorkProgress);
begin
  if FFirstLearningPass = 0 then FFirstLearningPass := AProgress.Pass;
  Progress(FLearningStage, AProgress.Done, AProgress.Total, 'observations', AProgress.Pass - FFirstLearningPass + 1);
end;

procedure TStudioWork.WorkProgress(const AProgress: TWorkProgress);
begin
  if AProgress.Total = 0 then Progress(AProgress.Stage, 0, 0)
  else Progress(AProgress.Stage, AProgress.Done, AProgress.Total,
    WorkUnitName(AProgress.Units), AProgress.Pass);
end;

procedure TStudioWork.LibraryProgress(const AStage: String; const ADone, ATotal: Int64);
begin
  if Pos('_bytes', AStage) > 0 then Progress(AStage, ADone, ATotal, 'bytes')
  else Progress(AStage, ADone, ATotal, 'items');
end;

procedure TStudioWork.FlushJournal;
begin
  Check;
end;

procedure TStudioWork.Preflight;
var
  LSelections: TJSONArray;
  LWeights: TJSONArray;
  LRows: TJSONArray;
  LRow: TJSONObject;
  LTrack: TJSONObject;
  LSnapshot: TJSONObject;
  LProject: TJSONObject;
  LIdentity: TJSONObject;
  LHash: String;
  LPath: String;
  LPartition: String;
  LIndex: Integer;
  LSourceIndex: Integer;
  LWeightIndex: Integer;
  LUniqueBytes: Int64;
  LFeatures: Int64;
  LTotalFeatures: Int64;
  LStart: Int64;
  LEnd: Int64;
  LClassifications: TJSONData;
begin
  LProject := FRequest.Objects['project_snapshot'];
  LSelections := LProject.Arrays['sources'];
  LWeights := FRequest.Arrays['source_weights'];
  FReceipt := TJSONObject.Create;
  FReceipt.Add('format', CProfileFormat);
  FReceipt.Add('mode', 'raw_acoustic');
  FReceipt.Add('policy', CPolicy);
  FReceipt.Add('policy_sha256', StudioTextHash(CPolicy));
  FReceipt.Add('meaning', 'Acoustic recombination of selected recorded windows; no note transcription or learned musical acceptance');
  FReceipt.Add('song_boundaries', 'unknown');
  FReceipt.Add('source_validation', 'full_content_hash_verified_for_this_job');
  FReceipt.Add('classifications_usage', 'Caller corpus observations retained in identity; not semantically inferred by raw learning');
  LRows := TJSONArray.Create;
  FReceipt.Add('sources', LRows);
  SetLength(FRanges, LSelections.Count);
  LUniqueBytes := 0;
  LTotalFeatures := 0;
  for LIndex := 0 to LSelections.Count - 1 do
  begin
    Progress('verify_sources', 0, 0);
    LSnapshot := LSelections.Objects[LIndex];
    LHash := LSnapshot.Strings['source_sha256'];
    LTrack := ReadCatalogTrack(FCatalogRoot, LHash);
    try
      Need(StudioTextHash(LTrack.AsJSON) = LSnapshot.Strings['metadata_sha256'],
        'Selected catalog metadata changed; save a new project revision');
      LPartition := LTrack.Strings['partition'];
      Need(LPartition <> 'evaluation', 'Evaluation source cannot train an operator model');
      if LPartition = 'unassigned' then
      begin
        LPartition := FRequest.Strings['resolve_unassigned'];
      end;
      Need((LPartition = 'development') or (LPartition = 'training'),
        'Source has no explicit usable partition');
      LSourceIndex := 0;
      while (LSourceIndex < Length(FSources)) and (FSources[LSourceIndex].Hash <> LHash) do
      begin
        Inc(LSourceIndex);
      end;
      if LSourceIndex = Length(FSources) then
      begin
        Need(Length(FSources) < 32, 'Worker source count exceeds bound');
        SetLength(FSources, Length(FSources) + 1);
        FSources[LSourceIndex] := Default(TSourceHandle);
        FSources[LSourceIndex].Hash := LHash;
        LPath := IncludeTrailingPathDelimiter(FCatalogRoot) + 'sources' + PathDelim + LHash + '.wav';
        FSources[LSourceIndex].Stream := TCheckedStream.Create(LPath, Self);
        Inc(LUniqueBytes, FSources[LSourceIndex].Stream.Size);
        Need(LUniqueBytes <= MaximumStudioJobSourceBytes, 'Source byte budget exceeded');
        Need((FSources[LSourceIndex].Stream.Size = LSnapshot.Int64s['source_bytes']) and
          (FSources[LSourceIndex].Stream.HashWithProgress('verify_sources') = LHash), 'Actual source bytes differ from imported identity');
        FSources[LSourceIndex].Stream.Position := 0;
        FSources[LSourceIndex].Wave := TWaveFrameReader.Create(FSources[LSourceIndex].Stream);
        Need((FSources[LSourceIndex].Wave.SampleRate = LSnapshot.Integers['sample_rate']) and
          (FSources[LSourceIndex].Wave.Channels = LSnapshot.Integers['channels']) and
          (FSources[LSourceIndex].Wave.FrameCount = LSnapshot.Int64s['frame_count']),
          'Source WAV clock differs from project snapshot');
        Need(FSources[LSourceIndex].Wave.Channels <= 2, 'Raw Studio supports mono or stereo sources');
        if LSourceIndex > 0 then
        begin
          Need((FSources[LSourceIndex].Wave.SampleRate = FSources[0].Wave.SampleRate) and
            (FSources[LSourceIndex].Wave.Channels = FSources[0].Wave.Channels),
            'Raw sources must share a sample rate and channel count; no implicit conversion');
        end;
      end;
      LStart := LSnapshot.Int64s['start_frame'];
      LEnd := LSnapshot.Int64s['end_frame'];
      Need((LStart >= 0) and (LEnd > LStart) and
        (LEnd <= FSources[LSourceIndex].Wave.FrameCount), 'Selected source range is invalid');
      FRanges[LIndex] := Default(TRangeHandle);
      FRanges[LIndex].SourceIndex := LSourceIndex;
      FRanges[LIndex].Origin := LStart;
      FRanges[LIndex].Frames := LEnd - LStart;
      FRanges[LIndex].Weight := 0;
      for LWeightIndex := 0 to LWeights.Count - 1 do
      begin
        if LWeights.Objects[LWeightIndex].Strings['source_sha256'] = LHash then
        begin
          FRanges[LIndex].Weight := LWeights.Objects[LWeightIndex].Integers['weight'];
        end;
      end;
      Need(FRanges[LIndex].Weight >= 1, 'Every selected source needs an explicit weight');
      LFeatures := (FRanges[LIndex].Frames + FOptions.HopFrames - 1) div FOptions.HopFrames;
      Inc(LTotalFeatures, LFeatures);
      Need(LTotalFeatures <= MaximumStudioJobFeatures, 'Analyzed feature budget exceeded');
      LRow := TJSONObject.Create;
      LRows.Add(LRow);
      LRow.Add('source_sha256', LHash);
      LRow.Add('source_group', LSnapshot.Strings['source_group']);
      LRow.Add('source_partition', LTrack.Strings['partition']);
      LRow.Add('effective_partition', LPartition);
      LRow.Add('exposure', LSnapshot.Strings['exposure']);
      LRow.Add('license', LSnapshot.Strings['license']);
      LRow.Add('provenance', LSnapshot.Strings['provenance']);
      LRow.Add('metadata_sha256', LSnapshot.Strings['metadata_sha256']);
      LRow.Add('source_frames', LSnapshot.Int64s['frame_count']);
      LRow.Add('start_frame', LStart);
      LRow.Add('end_frame', LEnd);
      LRow.Add('sample_rate', FSources[LSourceIndex].Wave.SampleRate);
      LRow.Add('channels', FSources[LSourceIndex].Wave.Channels);
      LRow.Add('weight', FRanges[LIndex].Weight);
      LRow.Add('selected_frames', LEnd - LStart);
      LRow.Add('analyzed_frames', LEnd - LStart);
      LRow.Add('observations', LFeatures);
      LClassifications := LSnapshot.Find('classifications');
      if LClassifications <> nil then
      begin
        LRow.Add('classifications', LClassifications.Clone);
      end
      else
      begin
        LRow.Add('classifications', TJSONArray.Create);
      end;
      LRow.Add('analysis_range_sha256', StudioTextHash('pythian.studio.analysis.range.v1|' +
        LHash + '|' + IntToStr(LStart) + '|' + IntToStr(LEnd)));
    finally
      LTrack.Free;
    end;
  end;
  Need(LWeights.Count = Length(FSources), 'Weights must match exactly the selected source set');
  { Journals live on disk. Estimate simultaneous fixed feature batches, palette
    sampling, candidate slots, source/window caches and solver cells conservatively. }
  Need(Int64(CBatchFeatures) * 136 * 4 + Int64(65536) * 15 * SizeOf(Double) +
    Int64(Length(FRanges)) * 16 * CCandidateBins * 128 +
    Int64(Length(FSources)) * FOptions.WindowFrames * 2 * SizeOf(Single) +
    Int64(262144) * 64 < MaximumStudioJobMemoryBytes, 'Logical worker memory budget exceeded');
  FReceipt.Add('total_analyzed_observations', LTotalFeatures);
  FReceipt.Add('unique_source_bytes_verified', LUniqueBytes);
  FReceipt.Add('logical_memory_budget_bytes', MaximumStudioJobMemoryBytes);
  LIdentity := TJSONObject.Create;
  try
    LIdentity.Add('policy', CPolicy);
    LIdentity.Add('maximum_tokens', FRequest.Integers['maximum_tokens']);
    LIdentity.Add('model_order', FRequest.Integers['model_order']);
    LIdentity.Add('sources', LRows.Clone);
    FTrainingHash := StudioTextHash(LIdentity.AsJSON);
  finally
    LIdentity.Free;
  end;
  FReceipt.Add('training_identity_sha256', FTrainingHash);
  FModelRoot := IncludeTrailingPathDelimiter(FCatalogRoot) + 'studio' + PathDelim +
    'models' + PathDelim + FTrainingHash;
end;

procedure TStudioWork.VerifySources(const AStage: String);
var
  LIndex: Integer;
begin
  for LIndex := 0 to High(FSources) do
  begin
    Check;
    Need(FSources[LIndex].Stream.HashWithProgress(AStage) = FSources[LIndex].Hash,
      'Source content changed during Studio work; no accepted publication');
  end;
end;

function TStudioWork.MakeProfile(const AReader: TJournalTrainingReader;
  const APalette: TAcousticPalette; const AModel: TWfcSequenceModel;
  const APool: TJournalCandidatePool; const AModelText: String): TJSONObject;
var
  LSources: TJSONArray;
  LCenters: TJSONArray;
  LCandidates: TJSONArray;
  LCenter: TJSONArray;
  LRow: TJSONObject;
  LIndex: Integer;
  LComponent: Integer;
  LCandidate: TJournalRepresentative;
  LVector: TAcousticVector;
  LVocabulary: String;
begin
  Result := TJSONObject.Create;
  try
    Result.Add('contract', 'pythian.acoustic.journal-learning');
    Result.Add('analysis_version', AnalysisVersion);
    Result.Add('learning_version', AcousticLearningVersion);
    Result.Add('raw_observations', AReader.ObservationCount);
    Result.Add('weighted_observations', AReader.WeightedObservationCount);
    Result.Add('wfc_observations', AModel.ObservationCount);
    Result.Add('wfc_samples', AModel.SampleCount);
    Result.Add('wfc_states', AModel.StateCount);
    Result.Add('order', AModel.Order);
    LVocabulary := AcousticVocabularySha256(APalette, FOptions,
      FSources[0].Wave.SampleRate, FSources[0].Wave.Channels);
    Result.Add('vocabulary_sha256', LVocabulary);
    Result.Add('model_binding_sha256', AcousticModelBindingSha256(LVocabulary,
      StudioTextHash(AModelText)));
    Result.Add('model_sha256', StudioTextHash(AModelText));
    Result.Add('sample_rate', FSources[0].Wave.SampleRate);
    Result.Add('channels', FSources[0].Wave.Channels);
    Result.Add('window_frames', FOptions.WindowFrames);
    Result.Add('hop_frames', FOptions.HopFrames);
    Result.Add('silence_rms', FOptions.SilenceRms);
    Result.Add('candidate_bins_per_segment', CCandidateBins);
    LSources := TJSONArray.Create;
    Result.Add('sources', LSources);
    for LIndex := 0 to High(FRanges) do
    begin
      LRow := TJSONObject.Create;
      LSources.Add(LRow);
      LRow.Add('source', 'analysis-range-' + IntToStr(LIndex));
      LRow.Add('source_sha256', FRanges[LIndex].Journal.Binding.SourceSha256);
      LRow.Add('cache_sha256', HashFile(FRanges[LIndex].JournalStream));
      LRow.Add('source_frames', FRanges[LIndex].Frames);
      LRow.Add('first_feature', 0);
      LRow.Add('observations', FRanges[LIndex].Journal.TotalFeatures);
      LRow.Add('multiplicity', FRanges[LIndex].Weight);
      LRow.Add('generation_weight', FRanges[LIndex].Weight);
    end;
    LCenters := TJSONArray.Create;
    Result.Add('palette', LCenters);
    for LIndex := 0 to APalette.Count - 1 do
    begin
      LCenter := TJSONArray.Create;
      LCenters.Add(LCenter);
      LVector := APalette.CenterAt(LIndex);
      for LComponent := 0 to High(LVector) do
      begin
        LCenter.Add(LVector[LComponent]);
      end;
    end;
    LCandidates := TJSONArray.Create;
    Result.Add('candidates', LCandidates);
    for LIndex := 0 to APool.SlotCount - 1 do
    begin
      LCandidate := APool.CandidateAt(LIndex);
      if LCandidate.Found then
      begin
        LRow := TJSONObject.Create;
        LCandidates.Add(LRow);
        LRow.Add('slot', LIndex);
        LRow.Add('token', APool.TokenAt(LIndex));
        LRow.Add('source_index', LCandidate.SegmentIndex);
        LRow.Add('source_frame', LCandidate.SourceFrame);
        LRow.Add('feature_index', LCandidate.FeatureIndex);
        LRow.Add('valid_frames', LCandidate.ValidFrames);
        LRow.Add('center_distance', LCandidate.Distance);
      end;
    end;
  except
    Result.Free;
    raise;
  end;
end;

function TStudioWork.TryReuseModel(const AExpected: TJSONObject;
  const AModelText: String): Boolean;
var
  LOuter: TJSONObject;
  LModelText: String;
  LProfile: TJournalModelProfile;
begin
  Result := DirectoryExists(FModelRoot);
  if not Result then Exit;
  LProfile := nil;
  LOuter := ReadStudioJSON(FModelRoot + PathDelim + 'profile.json');
  try
    Need((LOuter.Strings['format'] = CProfileFormat) and
      (LOuter.Strings['training_identity_sha256'] = FTrainingHash) and
      (LOuter.Arrays['sources'].AsJSON = FReceipt.Arrays['sources'].AsJSON),
      'Saved model source/range/classification identity differs');
    LModelText := ReadText(FModelRoot + PathDelim + 'model.wfcs');
    if AExpected <> nil then
      Need((LOuter.AsJSON = AExpected.AsJSON) and (LModelText = AModelText),
        'Concurrent model publication differs from this verified candidate');
    LProfile := TJournalModelProfile.Create(LOuter.Objects['journal_profile'].AsJSON, LModelText);
    Need(LProfile.ModelSha256 = LOuter.Strings['model_sha256'], 'Saved model hash differs');
    FProfile.Free;
    FProfile := LProfile;
    LProfile := nil;
    FReceipt.Strings['model_sha256'] := FProfile.ModelSha256;
    FModelReused := True;
  finally
    LProfile.Free;
    LOuter.Free;
  end;
end;

procedure TStudioWork.Train;
var
  LIndex: Integer;
  LFirst: Int64;
  LTotal: Int64;
  LCount: Integer;
  LContext: Integer;
  LExtent: Integer;
  LOffset: Int64;
  LBinding: TFeatureJournalBinding;
  LSource: TRangeAnalysis;
  LBatch: TWaveFeatureBatch;
  LSegments: TJournalTrainingSegments;
  LReader: TJournalTrainingReader;
  LPalette: TAcousticPalette;
  LModel: TWfcSequenceModel;
  LPool: TJournalCandidatePool;
  LInner: TJSONObject;
  LOuter: TJSONObject;
  LStage: String;
  LModelText: String;
  LGuid: TGuid;
  LFeatureIndex: Integer;
  LAnalyzed: Int64;
  LAllFeatures: Int64;
begin
  Progress('find_saved_model', 0, 0);
  if TryReuseModel then
  begin
    Progress('reload_verified_model', 1, 1, 'items');
    Exit;
  end;
  LAnalyzed := 0;
  LAllFeatures := FReceipt.Int64s['total_analyzed_observations'];
  Progress('analyze_selected_ranges', 0, LAllFeatures, 'observations');
  Need(ForceDirectories(FDirectory + PathDelim + 'analysis'), 'Cannot create private analysis stage');
  SetLength(LSegments, Length(FRanges));
  for LIndex := 0 to High(FRanges) do
  begin
    LBinding := Default(TFeatureJournalBinding);
    LBinding.SourceSha256 := FReceipt.Arrays['sources'].Objects[LIndex].Strings['analysis_range_sha256'];
    LBinding.SampleRate := FSources[FRanges[LIndex].SourceIndex].Wave.SampleRate;
    LBinding.Channels := FSources[FRanges[LIndex].SourceIndex].Wave.Channels;
    LBinding.FrameCount := FRanges[LIndex].Frames;
    LBinding.Options := FOptions;
    FRanges[LIndex].JournalStream := TFileStream.Create(FDirectory + PathDelim +
      'analysis' + PathDelim + IntToStr(LIndex) + '.pyaf', fmCreate or fmShareExclusive);
    FRanges[LIndex].Journal := TFeatureJournal.Create(FRanges[LIndex].JournalStream,
      LBinding, FlushJournal, True);
    LTotal := (FRanges[LIndex].Frames + FOptions.HopFrames - 1) div FOptions.HopFrames;
    LFirst := 0;
    while LFirst < LTotal do
    begin
      Check;
      LCount := Integer(Min(Int64(CBatchFeatures), LTotal - LFirst));
      LContext := Ord(LFirst > 0);
      LOffset := (LFirst - LContext) * FOptions.HopFrames;
      LExtent := Integer(Min(FRanges[LIndex].Frames - LOffset,
        Int64(LCount + LContext - 1) * FOptions.HopFrames + FOptions.WindowFrames));
      LSource := TRangeAnalysis.Create(FSources[FRanges[LIndex].SourceIndex].Wave,
        FRanges[LIndex].Origin + LOffset, LExtent);
      try
        LBatch := Default(TWaveFeatureBatch);
        LBatch.FirstFeature := LFirst;
        LBatch.SourceStartFrame := LFirst * FOptions.HopFrames;
        LBatch.Features := AnalyzeAudioSourceRange(LSource, FOptions, LContext, LCount);
        for LFeatureIndex := 0 to High(LBatch.Features) do
        begin
          Dec(LBatch.Features[LFeatureIndex].StartFrame, LContext * FOptions.HopFrames);
        end;
        LBatch.NextFeature := LFirst + LCount;
        LBatch.Completed := LBatch.NextFeature = LTotal;
        FRanges[LIndex].Journal.Append(LBatch);
        LFirst := LBatch.NextFeature;
        Inc(LAnalyzed, LCount);
        Progress('analyze_selected_ranges', LAnalyzed, LAllFeatures, 'observations');
      finally
        LSource.Free;
      end;
    end;
    Need(FileFlush(FRanges[LIndex].JournalStream.Handle), 'Cannot flush completed feature journal');
    LSegments[LIndex] := WholeJournalSegment(FRanges[LIndex].Journal, FRanges[LIndex].Weight);
  end;
  LReader := nil;
  LPalette := nil;
  LModel := nil;
  LPool := nil;
  LInner := nil;
  LOuter := nil;
  try
    LReader := TJournalTrainingReader.Create(LSegments);
    LReader.OnProgress := LearningProgress;
    FLearningStage := 'learn_raw_palette';
    FFirstLearningPass := 0;
    LPalette := TAcousticPalette.CreateFromReader(LReader, FRequest.Integers['maximum_tokens']);
    Check;
    FLearningStage := 'learn_wfc_model';
    FFirstLearningPass := 0;
    LModel := LearnJournalAcousticModel(LReader, LPalette, FRequest.Integers['model_order']);
    FLearningStage := 'select_sound_examples';
    FFirstLearningPass := 0;
    LPool := TJournalCandidatePool.Create(LReader, LPalette, CCandidateBins);
    Progress('check_learned_model', 0, 0);
    LModelText := EncodeWfcSequenceText(LModel);
    LInner := MakeProfile(LReader, LPalette, LModel, LPool, LModelText);
    FProfile := TJournalModelProfile.Create(LInner.AsJSON, LModelText);
    Need(FProfile.EncodeModel = LModelText, 'Reloaded model canonical text differs');
    VerifySources('verify_model_sources');
    Progress('save_learned_model', 0, 0);
    FReceipt.Add('model_sha256', FProfile.ModelSha256);
    LOuter := TJSONObject(FReceipt.Clone);
    LOuter.Add('journal_profile', LInner.Clone);
    CreateGUID(LGuid);
    LStage := ExtractFileDir(FModelRoot) + PathDelim + GUIDToString(LGuid) + '.stage';
    Need(not FileExists(LStage) and not DirectoryExists(LStage), 'Model stage must be fresh');
    Need(ForceDirectories(LStage), 'Cannot create model candidate stage');
    WriteTextNew(LStage + PathDelim + 'model.wfcs', LModelText);
    WriteStudioJSONNew(LStage + PathDelim + 'profile.json', LOuter);
    Check;
    if DirectoryExists(FModelRoot) or not RenameFile(LStage, FModelRoot) then
    begin
      { Big Boss: ordinary and live jobs can finish the same cold model together.
        Reuse only the identical published candidate through the primary verifier. }
      Need(TryReuseModel(LOuter, LModelText), 'Cannot publish immutable verified model');
      Need(SysUtils.DeleteFile(LStage + PathDelim + 'model.wfcs') and
        SysUtils.DeleteFile(LStage + PathDelim + 'profile.json') and RemoveDir(LStage),
        'Cannot release duplicate model candidate stage');
    end;
  finally
    LOuter.Free;
    LInner.Free;
    LPool.Free;
    LModel.Free;
    LPalette.Free;
    LReader.Free;
  end;
end;

function TStudioWork.ReadCandidate(const ACandidate: TJournalRepresentative): TAudioSamples;
var
  LRange: TRangeHandle;
begin
  Check;
  Need((ACandidate.SegmentIndex >= 0) and (ACandidate.SegmentIndex < Length(FRanges)),
    'Candidate range identity differs');
  LRange := FRanges[ACandidate.SegmentIndex];
  Need((ACandidate.SourceFrame >= 0) and
    (ACandidate.SourceFrame + ACandidate.ValidFrames <= LRange.Frames),
    'Candidate exceeds its selected source range');
  FSources[LRange.SourceIndex].Wave.SeekFrame(LRange.Origin + ACandidate.SourceFrame);
  Result := FSources[LRange.SourceIndex].Wave.ReadFrames(ACandidate.ValidFrames);
end;

procedure TStudioWork.RecordGrain(const AOrdinal: Int64; const AToken: Integer;
  const ACandidate: TJournalRepresentative);
var
  LRow: TJSONObject;
begin
  Need((FGrainLedger <> nil) and (AOrdinal = FGrainLedger.Count),
    'Finite audition grain receipt is out of sequence');
  LRow := TJSONObject.Create;
  FGrainLedger.Add(LRow);
  LRow.Add('token', AToken);
  LRow.Add('range_index', ACandidate.SegmentIndex);
  LRow.Add('original_source_frame', FRanges[ACandidate.SegmentIndex].Origin +
    ACandidate.SourceFrame);
  LRow.Add('valid_frames', ACandidate.ValidFrames);
end;

function TStudioWork.RenderSeed(const ASeed, AOrdinal: Integer): TJSONObject;
var
  LFinalPath: String;
  LOutput: TFileStream;
  LSink: TStreamAudioSink;
  LWriter: TWavePcm16Writer;
  LSession: TJournalAudioSession;
  LSamples: TAudioSamples;
  LWeights: TJournalSelectionWeights;
  LLedger: TJSONArray;
  LRequestedFrames: Int64;
  LNaturalFrames: Int64;
  LGrains: Integer;
  LIndex: Integer;
  LInput: TCheckedStream;
  LWave: TWaveFrameReader;
  LArtifact: TJSONObject;
  LRendered: Int64;
begin
  LRequestedFrames := Int64(FRequest.Integers['duration_ms']) * FProfile.SampleRate div 1000;
  LGrains := Integer(Max(Int64(1), (Max(Int64(0), LRequestedFrames - FOptions.WindowFrames) +
    FOptions.HopFrames - 1) div FOptions.HopFrames + 1));
  LNaturalFrames := JournalStreamFrames(FOptions.WindowFrames, FOptions.HopFrames, LGrains);
  Need(Int64(LGrains) * FOptions.WindowFrames * FProfile.Channels <=
    MaximumJournalStreamVisits, 'Audition render work exceeds bounded visits');
  Need(LGrains <= 6000, 'Audition grain receipt exceeds bounded rows');
  LFinalPath := FDirectory + PathDelim + 'seed-' + IntToStr(AOrdinal) + '.wav';
  Need(not FileExists(LFinalPath), 'Seed output already exists');
  LOutput := nil;
  LSink := nil;
  LWriter := nil;
  LSession := nil;
  Result := TJSONObject.Create;
  try
    try
      LLedger := TJSONArray.Create;
      Result.Add('grain_map', LLedger);
      FGrainLedger := LLedger;
      SetLength(LWeights, Length(FRanges));
      for LIndex := 0 to High(LWeights) do
      begin
        LWeights[LIndex] := FRanges[LIndex].Weight;
      end;
      LOutput := TFileStream.Create(LFinalPath, fmCreate or fmShareExclusive);
      LSink := TStreamAudioSink.Create(LOutput);
      LWriter := TWavePcm16Writer.Create(LSink, FProfile.SampleRate, FProfile.Channels, LRequestedFrames);
      LSession := TJournalAudioSession.Create(FProfile, ReadCandidate, LWeights,
        ASeed, LRequestedFrames, RecordGrain);
      LRendered := 0;
      Progress('generate_auditions', Int64(AOrdinal) * LRequestedFrames,
        Int64(FRequest.Arrays['seeds'].Count) * LRequestedFrames, 'frames');
      while LSession.State <> assCompleted do
      begin
        Check;
        LSamples := LSession.ReadFrames(4096);
        Need(Length(LSamples) > 0, 'Audio session made no progress');
        LWriter.AppendSamples(LSamples);
        Inc(LRendered, Length(LSamples) div FProfile.Channels);
        Progress('generate_auditions', Int64(AOrdinal) * LRequestedFrames + LRendered,
          Int64(FRequest.Arrays['seeds'].Count) * LRequestedFrames, 'frames');
      end;
      LWriter.Finish;
      Need(FileFlush(LOutput.Handle), 'Cannot flush audition');
      FreeAndNil(LSession);
      FreeAndNil(LWriter);
      FreeAndNil(LSink);
      FreeAndNil(LOutput);
      LInput := TCheckedStream.Create(LFinalPath, Self);
      try
        Result.Add('wav_sha256', HashFile(LInput));
        LInput.Position := 0;
        LWave := TWaveFrameReader.Create(LInput);
        try
          Need((LWave.SampleRate = FProfile.SampleRate) and (LWave.Channels = FProfile.Channels) and
            (LWave.FrameCount = LRequestedFrames), 'Saved WAV geometry differs');
        finally
          LWave.Free;
        end;
      finally
        LInput.Free;
      end;
      Result.Add('seed', ASeed);
      Result.Add('ordinal', AOrdinal);
      Result.Add('sample_rate', FProfile.SampleRate);
      Result.Add('channels', FProfile.Channels);
      Result.Add('frame_count', LRequestedFrames);
      Result.Add('natural_frame_count', LNaturalFrames);
      Result.Add('final_frames_clipped', LNaturalFrames - LRequestedFrames);
      Result.Add('requested_duration_ms', FRequest.Integers['duration_ms']);
      Result.Add('generated_grains', LGrains);
      Result.Add('model_sha256', FProfile.ModelSha256);
      Result.Add('chunk_cells', 128);
      Result.Add('max_backtracks', 256);
      Result.Add('generated_from_reloaded_model', True);
      Result.Add('status', 'verified');
      Result.Add('relative_file', 'seed-' + IntToStr(AOrdinal) + '.wav');
      LArtifact := TJSONObject(Result.Clone);
      try
        WriteStudioJSONNew(FDirectory + PathDelim + 'seed-' + IntToStr(AOrdinal) + '.receipt.json', LArtifact);
      finally
        LArtifact.Free;
      end;
      Result.Add('grain_map_sha256', StudioTextHash(LLedger.AsJSON));
      Result.Add('grain_map_count', LLedger.Count);
      FGrainLedger := nil;
      Result.Delete('grain_map');
    except
      Result.Free;
      raise;
    end;
  finally
    FGrainLedger := nil;
    LSession.Free;
    LWriter.Free;
    LSink.Free;
    LOutput.Free;
  end;
end;

procedure TStudioWork.RenderLive(const AResult: TJSONObject);
var
  LSession: TJournalAudioSession;
  LWeights: TJournalSelectionWeights;
  LState, LCommand, LExcerpt: TJSONObject;
  LOutputs: TJSONArray;
  LSamples, LSlice: TAudioSamples;
  LOutput: TFileStream;
  LSink: TStreamAudioSink;
  LWriter: TWavePcm16Writer;
  LTotal, LSequence, LStart, LExcerptStart, LExcerptFrames: Int64;
  LIndex, LTake: Integer;
  LExcerptDone: Boolean;
begin
  LSession := nil;
  LState := nil;
  LOutput := nil;
  LSink := nil;
  LWriter := nil;
  LExcerptDone := False;
  LSequence := -1;
  LExcerptStart := 0;
  LExcerptFrames := 0;
  LOutputs := TJSONArray.Create;
  AResult.Add('outputs', LOutputs);
  LTotal := Int64(FRequest.Integers['duration_ms']) * FProfile.SampleRate div 1000;
  try
    SetLength(LWeights, Length(FRanges));
    for LIndex := 0 to High(LWeights) do LWeights[LIndex] := FRanges[LIndex].Weight;
    LSession := TJournalAudioSession.Create(FProfile, ReadCandidate, LWeights,
      FRequest.Arrays['seeds'].Integers[0], LTotal);
    FStreaming := True;
    LState := TJSONObject.Create;
    LState.Add('sample_rate', FProfile.SampleRate);
    LState.Add('channels', FProfile.Channels);
    LState.Add('total_frames', LTotal);
    LState.Add('position', Int64(0));
    LState.Add('sequence', LSequence);
    LState.Add('model_sha256', FProfile.ModelSha256);
    LState.Add('request_sha256', FRequest.Strings['request_sha256']);
    LState.Add('seed', FRequest.Arrays['seeds'].Integers[0]);
    LState.Add('excerpt_status', 'available');
    Progress('streaming', 0, LTotal);
    ReplaceStudioJSON(FDirectory + PathDelim + StudioLiveStateFile, LState);
    while LSession.State <> assCompleted do
    begin
      Check;
      if not FileExists(FDirectory + PathDelim + StudioLiveCommandFile) then
      begin
        Sleep(25);
        Continue;
      end;
      LCommand := ReadStudioJSON(FDirectory + PathDelim + StudioLiveCommandFile);
      try
        if LCommand.Int64s['sequence'] <= LSequence then
        begin
          Sleep(25);
          Continue;
        end;
        Need(LCommand.Int64s['sequence'] = LSequence + 1, 'Live pull skipped a chunk');
      finally
        LCommand.Free;
      end;
      LStart := LSession.Position;
      if not LExcerptDone and (LWriter = nil) and
        FileExists(FDirectory + PathDelim + StudioLiveExcerptFile) then
      begin
        LExcerptStart := LStart;
        LExcerptFrames := Min(Int64(20) * FProfile.SampleRate, LTotal - LStart);
        LOutput := TFileStream.Create(FDirectory + PathDelim + 'stream-excerpt.wav',
          fmCreate or fmShareExclusive);
        LSink := TStreamAudioSink.Create(LOutput);
        LWriter := TWavePcm16Writer.Create(LSink, FProfile.SampleRate,
          FProfile.Channels, LExcerptFrames);
        LState.Strings['excerpt_status'] := 'recording';
        LState.Int64s['excerpt_start_frame'] := LExcerptStart;
        LState.Int64s['excerpt_frames'] := LExcerptFrames;
      end;
      LSamples := LSession.ReadFrames(Min(FProfile.SampleRate, StudioLiveChunkFrames));
      Need(Length(LSamples) > 0, 'Native live session made no progress');
      if LWriter <> nil then
      begin
        LTake := Min(Int64(Length(LSamples) div FProfile.Channels),
          LExcerptFrames - LWriter.FrameCount);
        LSlice := Copy(LSamples, 0, LTake * FProfile.Channels);
        LWriter.AppendSamples(LSlice);
        if LWriter.FrameCount = LExcerptFrames then
        begin
          LWriter.Finish;
          Need(FileFlush(LOutput.Handle), 'Cannot flush review excerpt');
          LExcerpt := TJSONObject.Create;
          LOutputs.Add(LExcerpt);
          LExcerpt.Add('seed', FRequest.Arrays['seeds'].Integers[0]);
          LExcerpt.Add('sample_rate', FProfile.SampleRate);
          LExcerpt.Add('channels', FProfile.Channels);
          LExcerpt.Add('frame_count', LExcerptFrames);
          LExcerpt.Add('session_start_frame', LExcerptStart);
          LExcerpt.Add('session_total_frames', LTotal);
          LExcerpt.Add('model_sha256', FProfile.ModelSha256);
          LExcerpt.Add('request_sha256', FRequest.Strings['request_sha256']);
          LExcerpt.Add('wav_sha256', HashFile(LOutput));
          LExcerpt.Add('relative_file', 'stream-excerpt.wav');
          FreeAndNil(LWriter);
          FreeAndNil(LSink);
          FreeAndNil(LOutput);
          VerifySources;
          PublishListening(LOutputs);
          WriteStudioJSONNew(FDirectory + PathDelim + 'stream-excerpt.receipt.json', LExcerpt);
          FPartial.Add('outputs', LOutputs.Clone);
          LState.Strings['excerpt_status'] := 'saved';
          LState.Strings['listening_request_id'] := LExcerpt.Strings['listening_request_id'];
          LExcerptDone := True;
        end;
      end;
      Inc(LSequence);
      LState.Int64s['sequence'] := LSequence;
      LState.Int64s['start_frame'] := LStart;
      LState.Int64s['position'] := LSession.Position;
      LState.Booleans['complete'] := LSession.State = assCompleted;
      PublishStudioLiveChunk(FDirectory, LState, LSamples);
      FPartial.Int64s['generated_frames'] := LSession.Position;
      FPartial.Int64s['total_frames'] := LTotal;
      FPartial.Integers['sample_rate'] := FProfile.SampleRate;
    end;
    AResult.Add('generated_frames', LSession.Position);
    AResult.Add('total_frames', LTotal);
    AResult.Add('whole_output_retained', False);
    AResult.Add('transport', 'bounded_pcm16_wav_chunks');
    AResult.Add('replay', 'new session with identical request; progress alone does not restore state');
    VerifySources;
  finally
    LWriter.Free;
    LSink.Free;
    LOutput.Free;
    LState.Free;
    LSession.Free;
  end;
end;

procedure TStudioWork.PublishListening(const AOutputs: TJSONArray);
var
  LQueue: TJSONObject;
  LItems: TJSONArray;
  LOutput: TJSONObject;
  LRequest: TJSONObject;
  LAsset: TJSONObject;
  LProvenance: TJSONObject;
  LAssets: TJSONArray;
  LRanges: TJSONArray;
  LRange: TJSONObject;
  LSpec: TJSONObject;
  LChoices: TJSONArray;
  LChoice: TJSONObject;
  LOptions: TJSONArray;
  LReports: TJSONObject;
  LStaged: TJSONObject;
  LSourceHashes: TJSONArray;
  LIndex: Integer;
  LOptionIndex: Integer;
  LNames: array[0..2] of String;
  LId: String;
begin
  LNames[0] := 'fits';
  LNames[1] := 'does_not_fit';
  LNames[2] := 'unknown';
  LQueue := TJSONObject.Create;
  LQueue.Add('version', 1);
  LQueue.Add('items', TJSONArray.Create);
  try
    LItems := LQueue.Arrays['items'];
    for LIndex := 0 to AOutputs.Count - 1 do
    begin
      Check;
      LOutput := AOutputs.Objects[LIndex];
      LId := 'studio_' + FJobId + '_' + IntToStr(LIndex);
      LStaged := StageListeningAsset(FCatalogRoot,
        FDirectory + PathDelim + LOutput.Strings['relative_file']);
      try
        Need(LStaged.Strings['sha256'] = LOutput.Strings['wav_sha256'], 'Staged audio hash differs');
        LOutput.Add('wav_bytes', LStaged.Int64s['bytes']);
      finally
        LStaged.Free;
      end;
      LRequest := TJSONObject.Create;
      LItems.Add(LRequest);
      LRequest.Add('id', LId);
      LRequest.Add('task_id', 'NS-6_studio_03');
      LRequest.Add('kind', 'single');
      LRequest.Add('question', 'Does this generated music fit the style you want?');
      LAssets := TJSONArray.Create;
      LRequest.Add('assets', LAssets);
      LAsset := TJSONObject.Create;
      LAssets.Add(LAsset);
      LAsset.Add('id', 'audition');
      LAsset.Add('storage', 'listening');
      LAsset.Add('role', 'generated');
      LAsset.Add('sha256', LOutput.Strings['wav_sha256']);
      LAsset.Add('sample_rate', LOutput.Integers['sample_rate']);
      LAsset.Add('channels', LOutput.Integers['channels']);
      LAsset.Add('frames', LOutput.Int64s['frame_count']);
      LAsset.Add('bytes', LOutput.Int64s['wav_bytes']);
      LProvenance := TJSONObject.Create;
      LAsset.Add('provenance', LProvenance);
      LProvenance.Add('source_sha256', FSources[0].Hash);
      if Length(FSources) > 1 then
      begin
        LSourceHashes := TJSONArray.Create;
        for LOptionIndex := 0 to High(FSources) do
        begin
          LSourceHashes.Add(FSources[LOptionIndex].Hash);
        end;
        LProvenance.Add('source_sha256s', LSourceHashes);
      end;
      LProvenance.Add('model_sha256', FProfile.ModelSha256);
      LProvenance.Add('policy_sha256', StudioTextHash(CPolicy));
      LProvenance.Add('parameter_sha256', FRequest.Strings['request_sha256']);
      LProvenance.Add('split', 'development');
      LProvenance.Add('seed', LOutput.Integers['seed']);
      LRanges := TJSONArray.Create;
      LRequest.Add('ranges', LRanges);
      LRange := TJSONObject.Create;
      LRanges.Add(LRange);
      LRange.Add('asset_id', 'audition');
      LRange.Add('start_frame', 0);
      LRange.Add('end_frame', LOutput.Int64s['frame_count']);
      LSpec := TJSONObject.Create;
      LRequest.Add('answer_spec', LSpec);
      LChoices := TJSONArray.Create;
      LSpec.Add('choices', LChoices);
      LSpec.Add('scores', TJSONArray.Create);
      LChoice := TJSONObject.Create;
      LChoices.Add(LChoice);
      LChoice.Add('id', 'style_fit');
      LOptions := TJSONArray.Create;
      LChoice.Add('values', LOptions);
      for LOptionIndex := 0 to 2 do
      begin
        LOptions.Add(LNames[LOptionIndex]);
      end;
      LOutput.Add('listening_request_id', LId);
    end;
    WriteStudioJSONNew(FDirectory + PathDelim + 'listening-publication.json', LQueue);
    Check;
    LReports := AppendListeningQueue(FCatalogRoot, FDirectory + PathDelim + 'listening-publication.json');
    LReports.Free;
  finally
    LQueue.Free;
  end;
end;

function TStudioWork.InspectSource: TJSONObject;
var
  LTrack: TJSONObject;
  LProposal: TJSONObject;
  LStream: TCheckedStream;
  LWave: TWaveFrameReader;
  LSamples: TAudioSamples;
  LPosition: Int64;
  LEnd: Int64;
  LCount: Integer;
  LSample: Single;
  LSum: Double;
  LPeak: Double;
  LMeasured: Int64;
begin
  LTrack := ReadCatalogTrack(FCatalogRoot, FRequest.Strings['source_sha256']);
  try
    Need(LTrack.Strings['partition'] <> 'evaluation', 'Evaluation source inspection is unavailable');
    LStream := TCheckedStream.Create(IncludeTrailingPathDelimiter(FCatalogRoot) +
      'sources' + PathDelim + FRequest.Strings['source_sha256'] + '.wav', Self);
    try
      Need(LStream.HashWithProgress('verify_audio_bytes') = FRequest.Strings['source_sha256'], 'Inspection source hash differs');
      LStream.Position := 0;
      LWave := TWaveFrameReader.Create(LStream);
      try
        LPosition := FRequest.Int64s['start_frame'];
        LEnd := FRequest.Int64s['end_frame'];
        Need((LEnd <= LWave.FrameCount) and
          (LEnd - LPosition <= Int64(LWave.SampleRate) * 30), 'Inspection range exceeds30seconds');
        LWave.SeekFrame(LPosition);
        LSum := 0;
        LPeak := 0;
        LMeasured := 0;
        while LPosition < LEnd do
        begin
          LCount := Integer(Min(Int64(4096), LEnd - LPosition));
          LSamples := LWave.ReadFrames(LCount);
          for LSample in LSamples do
          begin
            LSum := LSum + Sqr(LSample);
            LPeak := Max(LPeak, Abs(LSample));
            Inc(LMeasured);
          end;
          Inc(LPosition, LCount);
          Progress('inspect_levels', LPosition - FRequest.Int64s['start_frame'],
            LEnd - FRequest.Int64s['start_frame'], 'frames');
        end;
        Result := TJSONObject.Create;
        Result.Add('source_sha256', FRequest.Strings['source_sha256']);
        Result.Add('start_frame', FRequest.Int64s['start_frame']);
        Result.Add('end_frame', LEnd);
        Result.Add('sample_rate', LWave.SampleRate);
        Result.Add('rms', Sqrt(LSum / LMeasured));
        Result.Add('peak', LPeak);
      finally
        LWave.Free;
      end;
    finally
      LStream.Free;
    end;
    try
      Check;
      LProposal := PublishCatalogBeatProposals(FCatalogRoot, FRequest.Strings['source_sha256'],
        FRequest.Int64s['start_frame'], FRequest.Int64s['end_frame'], WorkProgress);
      Result.Add('beat_proposal', LProposal);
      Result.Add('uncertainty', 'Unreviewed native pulse hypotheses; not admitted beat truth');
    except
      Result.Free;
      raise;
    end;
  finally
    LTrack.Free;
  end;
end;

function TStudioWork.Run(const ALibraryRoot: String;
  const AExtension: TStudioWorkerExtension): TJSONObject;
var
  LOutputs: TJSONArray;
  LIndex: Integer;
begin
  if FRequest.Strings['kind'] = 'library_discover' then
  begin
    Exit(DiscoverStudioLibrary(FCatalogRoot, ALibraryRoot, LibraryProgress));
  end;
  if FRequest.Strings['kind'] = 'library_prepare' then
  begin
    Exit(PrepareStudioLibraryEntries(FCatalogRoot, ALibraryRoot,
      ReserveStudioJobStage(FCatalogRoot, ALibraryRoot, FJobId, 'library-prepare'),
      FRequest.Integers['discovery_revision'], FRequest.Arrays['entries'], LibraryProgress));
  end;
  if FRequest.Strings['kind'] = 'library_refresh' then
  begin
    Exit(RefreshStudioLibrary(FCatalogRoot, ALibraryRoot,
      ReserveStudioJobStage(FCatalogRoot, ALibraryRoot, FJobId, 'library-refresh'), LibraryProgress));
  end;
  if FRequest.Strings['kind'] = 'inspect_source' then
  begin
    Exit(InspectSource);
  end;
  if (FRequest.Strings['kind'] <> 'train_generate') and
    (FRequest.Strings['kind'] <> 'stream_generate') then
  begin
    Need(Assigned(AExtension), 'Studio worker does not support this job kind');
    Exit(AExtension(FCatalogRoot, FJobId, ALibraryRoot, FRequest, Check, WorkProgress));
  end;
  Preflight;
  Train;
  FReceipt.Add('retained_token_count', FProfile.Palette.Count);
  FReceipt.Add('retained_candidate_count', FProfile.Pool.SlotCount);
  FReceipt.Add('retained_model_state_count', FProfile.Model.StateCount);
  Result := TJSONObject(FReceipt.Clone);
  try
    Result.Add('model_reused', FModelReused);
    Result.Add('project_id', FRequest.Strings['project_id']);
    Result.Add('project_revision', FRequest.Int64s['project_revision']);
    Result.Add('project_snapshot_sha256', FRequest.Strings['project_snapshot_sha256']);
    Result.Add('request_sha256', FRequest.Strings['request_sha256']);
    Result.Add('grounded_acceptance', False);
    FPartial.Add('verified_model', Result.Clone);
    if FRequest.Strings['kind'] = 'stream_generate' then
    begin
      RenderLive(Result);
      WriteStudioJSONNew(FDirectory + PathDelim + 'result.json', Result);
      Exit;
    end;
    LOutputs := TJSONArray.Create;
    Result.Add('outputs', LOutputs);
    for LIndex := 0 to FRequest.Arrays['seeds'].Count - 1 do
    begin
      FCurrentOrdinal := LIndex;
      FPartial.Arrays['seed_outcomes'].Objects[LIndex].Strings['status'] := 'rendering';
      LOutputs.Add(RenderSeed(FRequest.Arrays['seeds'].Integers[LIndex], LIndex));
      FPartial.Arrays['seed_outcomes'].Objects[LIndex].Strings['status'] := 'verified';
      FPartial.Arrays['outputs'].Add(LOutputs.Objects[LIndex].Clone);
      FPartial.Integers['completed_render_count'] := LOutputs.Count;
    end;
    VerifySources;
    Progress('publish_listening', 0, 0);
    PublishListening(LOutputs);
    FPartial.Strings['publication_status'] := 'published';
    Result.Add('completed_render_count', LOutputs.Count);
    Result.Add('expected_render_count', FRequest.Arrays['seeds'].Count);
    Result.Add('seed_outcomes', FPartial.Arrays['seed_outcomes'].Clone);
    Result.Add('publication_status', 'published');
    WriteStudioJSONNew(FDirectory + PathDelim + 'result.json', Result);
  except
    Result.Free;
    raise;
  end;
end;

function RunStudioWorker(const ACatalogRoot, AJobId, ALibraryRoot: String;
  const AExtension: TStudioWorkerExtension): Boolean;
var
  LRequest: TJSONObject;
  LResults: TJSONObject;
  LWork: TStudioWork;
  LMessage: String;
begin
  Result := False;
  LRequest := ClaimStudioJob(ACatalogRoot, AJobId);
  try
    LWork := TStudioWork.Create(ACatalogRoot, AJobId, LRequest);
    try
      try
        LResults := LWork.Run(ALibraryRoot, AExtension);
        try
          LWork.Check;
          AdvanceStudioJob(ACatalogRoot, AJobId, 'completed', 'completed', 1, 1, LResults);
          Result := True;
        finally
          LResults.Free;
        end;
      except
        on E: EStudioJobCancelled do
        begin
          LResults := LWork.FailureResults('cancelled');
          try
            AdvanceStudioJob(ACatalogRoot, AJobId, 'cancelled', 'cancelled', 0, 0,
              LResults, 'cancelled', 'Cancelled; completed artifacts and partial diagnostics retained');
          finally
            LResults.Free;
          end;
        end;
        on E: Exception do
        begin
          WriteTextNew(StudioJobDirectory(ACatalogRoot, AJobId) + PathDelim + 'failure.txt',
            E.ClassName + ': ' + E.Message);
          LResults := LWork.FailureResults('failed');
          try
            WriteStudioJSONNew(StudioJobDirectory(ACatalogRoot, AJobId) +
              PathDelim + 'attempt-result.json', LResults);
            LMessage := 'Native Studio work failed; inspect retained details and correct the input';
            if (LRequest.Strings['kind'] = 'stream_generate') and (E is EAudio) then
              LMessage := Copy(E.Message, 1, 256);
            AdvanceStudioJob(ACatalogRoot, AJobId, 'failed', 'failed', 0, 0,
              LResults, 'worker_failure', LMessage);
          finally
            LResults.Free;
          end;
        end;
      end;
    finally
      LWork.Free;
    end;
  finally
    ReleaseStudioWorker(ACatalogRoot, LRequest.Strings['kind'] = 'stream_generate');
    LRequest.Free;
  end;
end;

end.
