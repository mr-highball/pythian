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

unit pythian.tools.journal.learning;

{$mode delphi}
{$H+}

interface

{ Command arguments: journals OUTPUT_PREFIX [OPTIONS] INPUT.wav CACHE.pyaf ... }
procedure LearnJournalFiles;
procedure ReplayJournalFiles;
procedure BlendJournalFiles;
procedure AttachJournalContexts;
procedure FitJournalFiles;

implementation

uses
  Classes,
  SysUtils,
  fpjson,
  jsonparser,
  pythian.audio,
  pythian.analysis,
  pythian.analysis.journal,
  pythian.corpus,
  pythian.learning,
  pythian.learning.journal,
  pythian.learning.selection,
  pythian.learning.continuity,
  pythian.learning.context,
  pythian.learning.binding,
  pythian.wfc.learning.profile,
  pythian.wfc.learning.blend,
  pythian.wfc.learning.journal,
  pythian.wfc.generation,
  pythian.wave.read,
  pythian.wave,
  pythian.granular,
  pythian.meter,
  pythian.hash,
  pythian.tools.files,
  wfc,
  wfc_sequence,
  wfc_sequence_text;

type
  TJournalInput = record
    SourcePath: String;
    CachePath: String;
    FirstFeature: Int64;
    FeatureCount: Int64;
    HasPartition: Boolean;
    GroupId: UTF8String;
    Partition: TJournalPartition;
    GroupVerified: Boolean;
    PreviouslyUsed: Boolean;
  end;
  TJournalInputs = array of TJournalInput;

  TJournalAudioAccess = class
    Waves: array of TWaveFrameReader;
    function ReadWindow(const ACandidate: TJournalRepresentative): TAudioSamples;
    procedure RejectWrite;
  end;

  TBoundJournal = class
  private
    FSource: TFileStream;
    FWave: TWaveFrameReader;
    FCache: TFileStream;
    FJournal: TFeatureJournal;
    FSourceBytes: Int64;
    FBinding: TFeatureJournalBinding;
    FCacheHash: String;
    procedure RejectWrite;
  public
    constructor Create(const ASourcePath, ACachePath: String; const AOptions: TAnalysisOptions);
    destructor Destroy; override;
    procedure VerifySource;
    property Journal: TFeatureJournal read FJournal;
    property Wave: TWaveFrameReader read FWave;
    property Binding: TFeatureJournalBinding read FBinding;
    property CacheHash: String read FCacheHash;
  end;

function ReadProfileText(const APath: String): UTF8String; forward;

{ A fresh prefix and the report published last make an interrupted result
  visibly incomplete. The sibling staging directory also excludes another
  learner using the same prefix. This is not a multi-file atomic transaction. }
procedure PublishJournalResult(const APrefix, AModel, AReport: String;
  const AHasWave: Boolean; const AWave: TAudioBytes);
var
  LStage: String;
  LModelMoved: Boolean;
  LWaveMoved: Boolean;
  LSuffix: String;
begin
  for LSuffix in ['.json', '.wfcs', '.wav'] do
  begin
    if FileExists(APrefix + LSuffix) then
    begin
      raise EAudio.Create('Journal publication requires a fresh output prefix');
    end;
  end;
  LStage := APrefix + '.publishing';
  if not CreateDir(LStage) then
  begin
    raise EAudio.Create('Cannot reserve journal publication prefix; inspect its .publishing directory');
  end;
  LModelMoved := False;
  LWaveMoved := False;
  try
    try
      WriteTextFile(LStage + PathDelim + 'model.wfcs', AModel);
      if AHasWave then
      begin
        WriteFileBytes(LStage + PathDelim + 'audition.wav', AWave);
      end;
      WriteTextFile(LStage + PathDelim + 'report.json', AReport);
      { Reject a late competing output before moving any staged artifact. }
      for LSuffix in ['.json', '.wfcs', '.wav'] do
      begin
        if FileExists(APrefix + LSuffix) then
        begin
          raise EAudio.Create('Journal output appeared during publication');
        end;
      end;
      if not RenameFile(LStage + PathDelim + 'model.wfcs', APrefix + '.wfcs') then
      begin
        raise EAudio.Create('Cannot publish journal model');
      end;
      LModelMoved := True;
      if AHasWave then
      begin
        if not RenameFile(LStage + PathDelim + 'audition.wav', APrefix + '.wav') then
        begin
          raise EAudio.Create('Cannot publish journal audition');
        end;
        LWaveMoved := True;
      end;
      if not RenameFile(LStage + PathDelim + 'report.json', APrefix + '.json') then
      begin
        raise EAudio.Create('Cannot publish journal report');
      end;
    except
      if LWaveMoved then DeleteFile(APrefix + '.wav');
      if LModelMoved then DeleteFile(APrefix + '.wfcs');
      raise;
    end;
  finally
    DeleteFile(LStage + PathDelim + 'model.wfcs');
    DeleteFile(LStage + PathDelim + 'audition.wav');
    DeleteFile(LStage + PathDelim + 'report.json');
    RemoveDir(LStage);
  end;
end;

function ReadPartition(const AValue: String): TJournalPartition;
begin
  if AValue = 'training' then
  begin
    Exit(jpTraining);
  end;
  if AValue = 'development' then
  begin
    Exit(jpDevelopment);
  end;
  if AValue = 'evaluation' then
  begin
    Exit(jpEvaluation);
  end;
  raise EAudio.Create('Partition must be training, development or evaluation');
end;

function PartitionName(const APartition: TJournalPartition): String;
begin
  case APartition of
    jpTraining: Result := 'training';
    jpDevelopment: Result := 'development';
    jpEvaluation: Result := 'evaluation';
  end;
end;

function ReadJournalInput(var AArgument: Integer;
  const AAllowPartition: Boolean = False): TJournalInput;
begin
  Result := Default(TJournalInput);
  if AAllowPartition and (ParamStr(AArgument) = '--group') then
  begin
    if AArgument + 6 > ParamCount then
    begin
      raise EAudio.Create('Group requires ID SPLIT verified|unverified unused|used then a WAV/cache pair');
    end;
    Result.HasPartition := True;
    Result.GroupId := ParamStr(AArgument + 1);
    Result.Partition := ReadPartition(ParamStr(AArgument + 2));
    if (ParamStr(AArgument + 3) <> 'verified') and
      (ParamStr(AArgument + 3) <> 'unverified') then
    begin
      raise EAudio.Create('Group identity declaration must be verified or unverified');
    end;
    Result.GroupVerified := ParamStr(AArgument + 3) = 'verified';
    if (ParamStr(AArgument + 4) <> 'unused') and
      (ParamStr(AArgument + 4) <> 'used') then
    begin
      raise EAudio.Create('Group exposure declaration must be unused or used');
    end;
    Result.PreviouslyUsed := ParamStr(AArgument + 4) = 'used';
    Inc(AArgument, 5);
  end;
  if ParamStr(AArgument) = '--range' then
  begin
    if AArgument + 4 > ParamCount then
    begin
      raise EAudio.Create('Range requires FIRST_FEATURE COUNT followed by a WAV/cache pair');
    end;
    Result.FirstFeature := StrToInt64(ParamStr(AArgument + 1));
    Result.FeatureCount := StrToInt64(ParamStr(AArgument + 2));
    if (Result.FirstFeature < 0) or (Result.FeatureCount < 1) then
    begin
      raise EAudio.Create('Range requires a nonnegative first feature and positive count');
    end;
    Inc(AArgument, 3);
  end;
  if (AArgument + 1 > ParamCount) or
    (Copy(ParamStr(AArgument), 1, 2) = '--') or
    (Copy(ParamStr(AArgument + 1), 1, 2) = '--') then
  begin
    raise EAudio.Create('Expected a WAV/cache pair; range applies only to its immediately following pair');
  end;
  Result.SourcePath := ParamStr(AArgument);
  Result.CachePath := ParamStr(AArgument + 1);
  Inc(AArgument, 2);
end;

function InputSegment(const AInput: TJournalInput; const AJournal: TFeatureJournal;
  const AMultiplicity: Integer = 1): TJournalTrainingSegment;
begin
  Result := WholeJournalSegment(AJournal, AMultiplicity);
  if AInput.FeatureCount > 0 then
  begin
    Result.FirstFeature := AInput.FirstFeature;
    Result.FeatureCount := AInput.FeatureCount;
  end;
  { The shared reader validates bounds and source overlap before learning. }
end;

procedure TJournalAudioAccess.RejectWrite;
begin
  raise EAudio.Create('Context attachment borrows read-only journals');
end;

function TJournalAudioAccess.ReadWindow(const ACandidate: TJournalRepresentative): TAudioSamples;
begin
  if (ACandidate.SegmentIndex < 0) or (ACandidate.SegmentIndex >= Length(Waves)) then
  begin
    raise EAudio.Create('Journal candidate source is outside the bound readers');
  end;
  Waves[ACandidate.SegmentIndex].SeekFrame(ACandidate.SourceFrame);
  Result := Waves[ACandidate.SegmentIndex].ReadFrames(ACandidate.ValidFrames);
end;

constructor TBoundJournal.Create(const ASourcePath, ACachePath: String;
  const AOptions: TAnalysisOptions);
begin
  inherited Create;
  FSource := TFileStream.Create(ASourcePath, fmOpenRead or fmShareDenyWrite);
  FWave := TWaveFrameReader.Create(FSource);
  FSourceBytes := FSource.Size;
  FSource.Position := 0;
  FBinding.SourceSha256 := Sha256Stream(FSource, FSourceBytes);
  FBinding.FrameCount := FWave.FrameCount;
  FBinding.SampleRate := FWave.SampleRate;
  FBinding.Channels := FWave.Channels;
  FBinding.Options := AOptions;
  FCache := TFileStream.Create(ACachePath, fmOpenRead or fmShareDenyWrite);
  FCacheHash := Sha256Stream(FCache, FCache.Size);
  FJournal := TFeatureJournal.Create(FCache, FBinding, RejectWrite, False);
  if not FJournal.Completed then
  begin
    raise EAudio.Create('Complete the feature cache before training');
  end;
end;

destructor TBoundJournal.Destroy;
begin
  FJournal.Free;
  FCache.Free;
  FWave.Free;
  FSource.Free;
  inherited Destroy;
end;

procedure TBoundJournal.RejectWrite;
begin
  raise EAudio.Create('Training journals are read-only');
end;

procedure TBoundJournal.VerifySource;
begin
  FSource.Position := 0;
  if (FSource.Size <> FSourceBytes) or
    (Sha256Stream(FSource, FSourceBytes) <> FBinding.SourceSha256) then
  begin
    raise EAudio.Create('Training source changed; no outputs published');
  end;
end;

procedure FitJournalFiles;
var
  LInputs: TJournalInputs;
  LProfile: TJournalModelProfile;
  LBound: array of TBoundJournal;
  LOwnedBound: array of TBoundJournal;
  LSegments: TJournalTrainingSegments;
  LReader: TJournalTrainingReader;
  LFits: TJournalPaletteFits;
  LDocument: TJSONObject;
  LRows: TJSONArray;
  LRow: TJSONObject;
  LCounts: TJSONArray;
  LReportText: UTF8String;
  LSavedSource: TJournalProfileSource;
  LLimit: Double;
  LFormat: TFormatSettings;
  LCount: Integer;
  LArgument: Integer;
  LIndex: Integer;
  LOther: Integer;
  LToken: Integer;
  LKnown: Boolean;
  LOutput: String;
  LInput: String;
begin
  if ParamCount < 6 then
  begin
    raise EAudio.Create('Usage: pythian.learn fit PROFILE_PREFIX OUTPUT.json MAX_SQUARED_DISTANCE [--range FIRST_FEATURE COUNT] INPUT.wav CACHE.pyaf [...]');
  end;
  LOutput := ExpandFileName(ParamStr(3));
  if SameFileName(LOutput, ExpandFileName(ParamStr(2) + '.json')) or
    SameFileName(LOutput, ExpandFileName(ParamStr(2) + '.wfcs')) then
  begin
    raise EAudio.Create('Fit output must differ from the input profile');
  end;
  LCount := 0;
  LArgument := 5;
  while LArgument <= ParamCount do
  begin
    if LCount = MaximumJournalTrainingSegments then
    begin
      raise EAudio.Create('Fit requires 1..4096 WAV/cache ranges');
    end;
    SetLength(LInputs, LCount + 1);
    LInputs[LCount] := ReadJournalInput(LArgument);
    if SameFileName(LOutput, ExpandFileName(LInputs[LCount].SourcePath)) or
      SameFileName(LOutput, ExpandFileName(LInputs[LCount].CachePath)) then
    begin
      raise EAudio.Create('Fit output must differ from every source and cache');
    end;
    Inc(LCount);
  end;
  LFormat := DefaultFormatSettings;
  LFormat.DecimalSeparator := '.';
  LLimit := StrToFloat(ParamStr(4), LFormat);
  RequireFinite(LLimit, 'Fit squared-distance limit');
  if (LLimit < 0) or (LLimit > 15) then
  begin
    raise EAudio.Create('Fit squared-distance limit must be in 0..15');
  end;
  SetLength(LBound, LCount);
  SetLength(LOwnedBound, LCount);
  SetLength(LSegments, LCount);
  LProfile := nil;
  LReader := nil;
  LDocument := nil;
  try
    LReportText := ReadProfileText(ParamStr(2) + '.json');
    LProfile := TJournalModelProfile.Create(LReportText, ReadProfileText(ParamStr(2) + '.wfcs'));
    for LIndex := 0 to LCount - 1 do
    begin
      for LOther := 0 to LIndex - 1 do
      begin
        if SameFileName(ExpandFileName(LInputs[LIndex].SourcePath),
          ExpandFileName(LInputs[LOther].SourcePath)) and
          SameFileName(ExpandFileName(LInputs[LIndex].CachePath),
          ExpandFileName(LInputs[LOther].CachePath)) then
        begin
          LBound[LIndex] := LBound[LOther];
          Break;
        end;
      end;
      if LBound[LIndex] = nil then
      begin
        LOwnedBound[LIndex] := TBoundJournal.Create(LInputs[LIndex].SourcePath,
          LInputs[LIndex].CachePath, LProfile.Options);
        LBound[LIndex] := LOwnedBound[LIndex];
      end;
      if (LBound[LIndex].Binding.SampleRate <> LProfile.SampleRate) or
        (LBound[LIndex].Binding.Channels <> LProfile.Channels) then
      begin
        raise EAudio.Create('Fit source must share the saved vocabulary analysis/timebase');
      end;
      LSegments[LIndex] := InputSegment(LInputs[LIndex], LBound[LIndex].Journal);
    end;
    LReader := TJournalTrainingReader.Create(LSegments);
    LFits := MeasureJournalPaletteFit(LReader, LProfile.Palette, LLimit);
    LDocument := TJSONObject.Create;
    LDocument.Add('contract', 'pythian.acoustic.palette-fit');
    LDocument.Add('learning_version', AcousticLearningVersion);
    LDocument.Add('profile_report_sha256', HashText(LReportText));
    LDocument.Add('model_sha256', LProfile.ModelSha256);
    LDocument.Add('vocabulary_sha256', LProfile.VocabularySha256);
    LDocument.Add('palette_size', LProfile.Palette.Count);
    LDocument.Add('model_states', LProfile.Model.StateCount);
    LDocument.Add('maximum_squared_distance', LLimit);
    LDocument.Add('policy', 'One pass over distinct observations; frozen palette; no learning or generation. Explicit vector-distance limit is not musical accuracy. Outside-profile sources are not automatically held-out evidence.');
    LRows := TJSONArray.Create;
    LDocument.Add('sources', LRows);
    for LIndex := 0 to LCount - 1 do
    begin
      LKnown := False;
      for LOther := 0 to LProfile.SourceCount - 1 do
      begin
        LSavedSource := LProfile.SourceAt(LOther);
        LKnown := LKnown or
          (LSavedSource.Binding.SourceSha256 = LBound[LIndex].Binding.SourceSha256);
      end;
      LInput := LInputs[LIndex].SourcePath;
      LRow := TJSONObject.Create;
      LRows.Add(LRow);
      LRow.Add('source', ExtractFileName(LInput));
      LRow.Add('source_sha256', LBound[LIndex].Binding.SourceSha256);
      LRow.Add('cache_sha256', LBound[LIndex].CacheHash);
      LRow.Add('recording_in_profile', LKnown);
      LRow.Add('first_feature', LSegments[LIndex].FirstFeature);
      LRow.Add('observations', LFits[LIndex].ObservationCount);
      LRow.Add('weighted_observations', LFits[LIndex].WeightedObservationCount);
      LRow.Add('non_silent_observations', LFits[LIndex].NonSilentCount);
      LRow.Add('mean_squared_distance', LFits[LIndex].MeanSquaredDistance);
      LRow.Add('non_silent_mean_squared_distance', LFits[LIndex].NonSilentMeanSquaredDistance);
      LRow.Add('maximum_squared_distance', LFits[LIndex].MaximumSquaredDistance);
      LRow.Add('within_limit_count', LFits[LIndex].WithinLimitCount);
      LRow.Add('within_limit_fraction', LFits[LIndex].WithinLimitCount / LFits[LIndex].ObservationCount);
      LRow.Add('occupied_tokens', LFits[LIndex].OccupiedTokens);
      LRow.Add('effective_tokens', LFits[LIndex].EffectiveTokens);
      LRow.Add('self_transitions', LFits[LIndex].SelfTransitions);
      LRow.Add('longest_same_token_run', LFits[LIndex].LongestRun);
      LCounts := TJSONArray.Create;
      LRow.Add('token_counts', LCounts);
      for LToken := 0 to LProfile.Palette.Count - 1 do
      begin
        LCounts.Add(LFits[LIndex].TokenCounts[LToken]);
      end;
      if LOwnedBound[LIndex] <> nil then
      begin
        LOwnedBound[LIndex].VerifySource;
      end;
    end;
    WriteTextFile(ParamStr(3), LDocument.FormatJSON);
    WriteLn('Measured ', LReader.ObservationCount, ' distinct observations across ',
      LCount, ' source ranges; palette/model unchanged');
  finally
    LDocument.Free;
    LReader.Free;
    for LIndex := 0 to High(LOwnedBound) do
    begin
      LOwnedBound[LIndex].Free;
    end;
    LProfile.Free;
  end;
end;

procedure LearnJournalFiles;
var
  LInputs: TJournalInputs;
  LPaths: array of String;
  LCaches: array of String;
  LWeights: array of Integer;
  LBound: array of TBoundJournal;
  LOwnedBound: array of TBoundJournal;
  LPartitioned: Boolean;
  LPartition: TJournalPartition;
  LPlan: TJournalPartitionPlan;
  LPartitionAudit: TJSONObject;
  LPlanRows: TJSONArray;
  LSelectedCount: Integer;
  LSegments: TJournalTrainingSegments;
  LReader: TJournalTrainingReader;
  LStarter: TJournalModelProfile;
  LStarterSource: TJournalProfileSource;
  LPlanIndex: Integer;
  LPaletteInput: String;
  LMaximumTokens: Integer;
  LExplicitMaximumTokens: Boolean;
  LPalette: TAcousticPalette;
  LModel: TWfcSequenceModel;
  LReloaded: TWfcSequenceModel;
  LJoinPlanner: TJournalJoinPlanner;
  LAudioAccess: TJournalAudioAccess;
  LJoinOptions: TJournalJoinOptions;
  LJoinPasses: Integer;
  LJoinBefore: TJournalJoinReport;
  LJoinAfter: TJournalJoinReport;
  LJoinJson: TJSONObject;
  LFloatSettings: TFormatSettings;
  LJoinWeight: Double;
  LPool: TJournalCandidatePool;
  LRepresentative: TJournalRepresentative;
  LPrevious: TJournalRepresentative;
  LSelection: TAcousticIndices;
  LSourceWeights: TJournalSelectionWeights;
  LSourceUse: array of Integer;
  LBins: Integer;
  LSelectionSeed: Integer;
  LSourceWeight: Integer;
  LSlot: Integer;
  LUnique: Integer;
  LRepeats: Integer;
  LContiguous: Integer;
  LSwitches: Integer;
  LUsedSlots: array of Boolean;
  LVocabularyHash: String;
  LRendered: TAudioClip;
  LGeneration: TAcousticGenerationOptions;
  LIndices: TAcousticIndices;
  LSolve: TGraphSolveReport;
  LLevels: TAudioLevels;
  LWaveBytes: TAudioBytes;
  LDocument: TJSONObject;
  LSourcesJson: TJSONArray;
  LPaletteJson: TJSONArray;
  LRepresentativesJson: TJSONArray;
  LEvents: TJSONArray;
  LSelectionsJson: TJSONArray;
  LRow: TJSONObject;
  LCenter: TJSONArray;
  LVector: TAcousticVector;
  LModelText: String;
  LPrefix: String;
  LSuffix: String;
  LArgument: Integer;
  LCount: Integer;
  LEffectiveSamples: Integer;
  LWeight: Integer;
  LIndex: Integer;
  LComponent: Integer;
  LToken: Integer;
  LSource: Integer;
  LPhysicalSources: Integer;
  LKnownSource: Boolean;
  LBinding: TFeatureJournalBinding;
begin
  if ParamCount < 4 then
  begin
    raise EAudio.Create('Usage: pythian.learn journals OUTPUT_PREFIX [--multiplicity N] INPUT.wav CACHE.pyaf [...]');
  end;
  LPrefix := ParamStr(2);
  LArgument := 3;
  LPartitioned := ParamStr(LArgument) = '--partition';
  LPartition := jpDevelopment;
  if LPartitioned then
  begin
    LPartition := ReadPartition(ParamStr(LArgument + 1));
    if LPartition = jpEvaluation then
    begin
      raise EAudio.Create('Evaluation cannot be selected for learning');
    end;
    Inc(LArgument, 2);
  end;
  LWeight := 1;
  LCount := 0;
  LEffectiveSamples := 0;
  LPaletteInput := '';
  LMaximumTokens := 16;
  LExplicitMaximumTokens := False;
  LBins := 4;
  LSelectionSeed := 731;
  LSourceWeight := 1;
  LJoinOptions := DefaultJournalJoinOptions;
  LJoinPasses := 0;
  LFloatSettings := DefaultFormatSettings;
  LFloatSettings.DecimalSeparator := '.';
  while LArgument <= ParamCount do
  begin
    if ParamStr(LArgument) = '--max-tokens' then
    begin
      if LArgument = ParamCount then
      begin
        raise EAudio.Create('Maximum token count requires an integer');
      end;
      LMaximumTokens := StrToInt(ParamStr(LArgument + 1));
      if (LMaximumTokens < 1) or (LMaximumTokens > MaximumAcousticVocabulary) then
      begin
        raise EAudio.Create('Maximum token count must be 1..32');
      end;
      LExplicitMaximumTokens := True;
      Inc(LArgument, 2);
      Continue;
    end;
    if ParamStr(LArgument) = '--palette-from' then
    begin
      if LArgument = ParamCount then
      begin
        raise EAudio.Create('Palette starter requires a saved profile prefix');
      end;
      LPaletteInput := ParamStr(LArgument + 1);
      for LSuffix in ['.json', '.wfcs', '.wav'] do
      begin
        if SameFileName(ExpandFileName(LPrefix + LSuffix),
          ExpandFileName(LPaletteInput + LSuffix)) then
        begin
          raise EAudio.Create('Training output must differ from its palette starter');
        end;
      end;
      Inc(LArgument, 2);
      Continue;
    end;
    if (ParamStr(LArgument) = '--join-switch-weight') or
      (ParamStr(LArgument) = '--join-seam-weight') or
      (ParamStr(LArgument) = '--join-center-weight') then
    begin
      if LArgument = ParamCount then
      begin
        raise EAudio.Create('Join weight requires a finite number');
      end;
      LJoinWeight := StrToFloat(ParamStr(LArgument + 1), LFloatSettings);
      RequireFinite(LJoinWeight, 'Join weight');
      if (LJoinWeight < 0) or (LJoinWeight > 16) then
      begin
        raise EAudio.Create('Join weights must be 0..16');
      end;
      if ParamStr(LArgument) = '--join-switch-weight' then
      begin
        LJoinOptions.SourceSwitchWeight := LJoinWeight;
      end
      else if ParamStr(LArgument) = '--join-seam-weight' then
      begin
        LJoinOptions.SeamWeight := LJoinWeight;
      end
      else
      begin
        LJoinOptions.CenterWeight := LJoinWeight;
      end;
      Inc(LArgument, 2);
      Continue;
    end;
    if (ParamStr(LArgument) = '--join-passes') or
      (ParamStr(LArgument) = '--join-swap-radius') or
      (ParamStr(LArgument) = '--candidate-bins') or
      (ParamStr(LArgument) = '--selection-seed') or
      (ParamStr(LArgument) = '--source-weight') then
    begin
      if LArgument = ParamCount then
      begin
        raise EAudio.Create('Selection option requires an integer');
      end;
      LIndex := StrToInt(ParamStr(LArgument + 1));
      if ParamStr(LArgument) = '--join-passes' then
      begin
        if (LIndex < 0) or (LIndex > 8) then
        begin
          raise EAudio.Create('Join passes must be 0..8');
        end;
        LJoinPasses := LIndex;
      end
      else if ParamStr(LArgument) = '--join-swap-radius' then
      begin
        if (LIndex < 0) or (LIndex >= MaximumJournalSelectionGrains) then
        begin
          raise EAudio.Create('Join swap radius must be 0..4095');
        end;
        LJoinOptions.SwapRadius := LIndex;
      end
      else if ParamStr(LArgument) = '--candidate-bins' then
      begin
        if (LIndex < 1) or (LIndex > 32) then
        begin
          raise EAudio.Create('Candidate bins must be 1..32');
        end;
        LBins := LIndex;
      end
      else if ParamStr(LArgument) = '--selection-seed' then
      begin
        if LIndex < 0 then
        begin
          raise EAudio.Create('Selection seed must be nonnegative');
        end;
        LSelectionSeed := LIndex;
      end
      else
      begin
        if (LIndex < 0) or (LIndex > 4096) then
        begin
          raise EAudio.Create('Source weight must be 0..4096');
        end;
        LSourceWeight := LIndex;
        if LArgument + 2 > ParamCount then
        begin
          raise EAudio.Create('Source weight must precede a source/cache pair');
        end;
      end;
      Inc(LArgument, 2);
      Continue;
    end;
    if ParamStr(LArgument) = '--multiplicity' then
    begin
      if LArgument = ParamCount then
      begin
        raise EAudio.Create('Multiplicity requires a positive integer');
      end;
      LWeight := StrToInt(ParamStr(LArgument + 1));
      if (LWeight < 1) or (LWeight > 4096) then
      begin
        raise EAudio.Create('Multiplicity must be 1..4096');
      end;
      Inc(LArgument, 2);
      if LArgument > ParamCount then
      begin
        raise EAudio.Create('Multiplicity must precede a source/cache pair');
      end;
      Continue;
    end;
    if (LArgument = ParamCount) or (LCount = MaximumJournalTrainingSegments) then
    begin
      raise EAudio.Create('Journal training requires 1..4096 WAV/cache ranges');
    end;
    SetLength(LPaths, LCount + 1);
    SetLength(LCaches, LCount + 1);
    SetLength(LInputs, LCount + 1);
    SetLength(LWeights, LCount + 1);
    SetLength(LSourceWeights, LCount + 1);
    LInputs[LCount] := ReadJournalInput(LArgument, True);
    if LInputs[LCount].HasPartition <> LPartitioned then
    begin
      raise EAudio.Create('Partitioned learning requires --partition immediately after OUTPUT_PREFIX and --group for every pair');
    end;
    LPaths[LCount] := LInputs[LCount].SourcePath;
    LCaches[LCount] := LInputs[LCount].CachePath;
    LWeights[LCount] := LWeight;
    LSourceWeights[LCount] := LSourceWeight;
    if LWeight > WFC_SEQUENCE_MAX_SAMPLE_COUNT - LEffectiveSamples then
    begin
      raise EAudio.Create('Recording multiplicities exceed the companion sample budget');
    end;
    Inc(LEffectiveSamples, LWeight);
    for LSuffix in ['.json', '.wfcs', '.wav'] do
    begin
      if SameFileName(ExpandFileName(LPrefix + LSuffix), ExpandFileName(LPaths[LCount])) or
        SameFileName(ExpandFileName(LPrefix + LSuffix), ExpandFileName(LCaches[LCount])) then
      begin
        raise EAudio.Create('Training output must differ from every source and cache');
      end;
    end;
    Inc(LCount);
  end;
  if LExplicitMaximumTokens and (LPaletteInput <> '') then
  begin
    raise EAudio.Create('A saved palette fixes its vocabulary; omit --max-tokens');
  end;
  LJoinPlanner := nil;
  LStarter := nil;
  LAudioAccess := nil;
  LPool := nil;
  LReader := nil;
  LPalette := nil;
  LModel := nil;
  LReloaded := nil;
  LRendered := nil;
  LDocument := nil;
  LPartitionAudit := nil;
  SetLength(LBound, LCount);
  SetLength(LOwnedBound, LCount);
  SetLength(LSegments, LCount);
  try
    LPhysicalSources := 0;
    for LIndex := 0 to LCount - 1 do
    begin
      LBound[LIndex] := nil;
      for LPlanIndex := 0 to LIndex - 1 do
      begin
        if SameFileName(ExpandFileName(LPaths[LIndex]), ExpandFileName(LPaths[LPlanIndex])) and
          SameFileName(ExpandFileName(LCaches[LIndex]), ExpandFileName(LCaches[LPlanIndex])) then
        begin
          LBound[LIndex] := LBound[LPlanIndex];
          Break;
        end;
      end;
      if LBound[LIndex] = nil then
      begin
        LOwnedBound[LIndex] := TBoundJournal.Create(LPaths[LIndex], LCaches[LIndex], DefaultAnalysisOptions);
        LBound[LIndex] := LOwnedBound[LIndex];
        LKnownSource := False;
        for LPlanIndex := 0 to LIndex - 1 do
        begin
          if LBound[LIndex].Binding.SourceSha256 = LBound[LPlanIndex].Binding.SourceSha256 then
          begin
            if (LBound[LIndex].Binding.FrameCount <> LBound[LPlanIndex].Binding.FrameCount) or
              (LBound[LIndex].CacheHash <> LBound[LPlanIndex].CacheHash) then
            begin
              raise EAudio.Create('Repeated physical source has conflicting cache or geometry');
            end;
            LKnownSource := True;
            Break;
          end;
        end;
        if not LKnownSource then
        begin
          Inc(LPhysicalSources);
          if LPhysicalSources > MaximumCorpusSources then
          begin
            raise EAudio.Create('Journal training exceeds 32 physical sources');
          end;
        end;
      end;
      LSegments[LIndex] := InputSegment(LInputs[LIndex], LBound[LIndex].Journal, LWeights[LIndex]);
    end;
    if LPartitioned then
    begin
      SetLength(LPlan, LCount);
      for LIndex := 0 to LCount - 1 do
      begin
        LPlan[LIndex].Segment := LSegments[LIndex];
        LPlan[LIndex].GroupId := LInputs[LIndex].GroupId;
        LPlan[LIndex].Partition := LInputs[LIndex].Partition;
        LPlan[LIndex].GroupVerified := LInputs[LIndex].GroupVerified;
        LPlan[LIndex].PreviouslyUsed := LInputs[LIndex].PreviouslyUsed;
      end;
      LSegments := SelectJournalPartition(LPlan, LPartition);
      LPartitionAudit := TJSONObject.Create;
      LPartitionAudit.Add('selected_partition', PartitionName(LPartition));
      LPartitionAudit.Add('policy', 'Caller-declared identities and family exposure; complete supplied plan checked before learning. Source/cache hashes bind this invocation. Derivative overlap and uses outside the plan require caller audit; no independent style verdict.');
      LPlanRows := TJSONArray.Create;
      LPartitionAudit.Add('inputs', LPlanRows);
      LSelectedCount := 0;
      for LIndex := 0 to LCount - 1 do
      begin
        LRow := TJSONObject.Create;
        LPlanRows.Add(LRow);
        LRow.Add('group_id', LInputs[LIndex].GroupId);
        LRow.Add('partition', PartitionName(LInputs[LIndex].Partition));
        LRow.Add('group_verified', LInputs[LIndex].GroupVerified);
        LRow.Add('previously_used', LInputs[LIndex].PreviouslyUsed);
        LRow.Add('source_sha256', LBound[LIndex].Binding.SourceSha256);
        LRow.Add('cache_sha256', LBound[LIndex].CacheHash);
        LRow.Add('source_frames', LBound[LIndex].Binding.FrameCount);
        LRow.Add('first_feature', LPlan[LIndex].Segment.FirstFeature);
        LRow.Add('observations', LPlan[LIndex].Segment.FeatureCount);
        LRow.Add('multiplicity', LWeights[LIndex]);
        LRow.Add('generation_weight', LSourceWeights[LIndex]);
        LRow.Add('selected', LInputs[LIndex].Partition = LPartition);
        if LInputs[LIndex].Partition = LPartition then
        begin
          LBound[LSelectedCount] := LBound[LIndex];
          LPaths[LSelectedCount] := LPaths[LIndex];
          LCaches[LSelectedCount] := LCaches[LIndex];
          LWeights[LSelectedCount] := LWeights[LIndex];
          LSourceWeights[LSelectedCount] := LSourceWeights[LIndex];
          Inc(LSelectedCount);
        end;
      end;
      LCount := LSelectedCount;
      SetLength(LBound, LCount);
      SetLength(LPaths, LCount);
      SetLength(LCaches, LCount);
      SetLength(LWeights, LCount);
      SetLength(LSourceWeights, LCount);
    end;
    LReader := TJournalTrainingReader.Create(LSegments);
    if LReader.WeightedObservationCount > High(Integer) then
    begin
      raise EAudio.Create('Weighted observations exceed companion Integer counts');
    end;
    if LPaletteInput = '' then
    begin
      LPalette := TAcousticPalette.CreateFromReader(LReader, LMaximumTokens);
    end
    else
    begin
      LStarter := TJournalModelProfile.Create(ReadProfileText(LPaletteInput + '.json'),
        ReadProfileText(LPaletteInput + '.wfcs'));
      if LPartitioned then
      begin
        for LIndex := 0 to LStarter.SourceCount - 1 do
        begin
          LStarterSource := LStarter.SourceAt(LIndex);
          for LPlanIndex := 0 to High(LPlan) do
          begin
            if (LPlan[LPlanIndex].Partition = jpEvaluation) and
              (LStarterSource.Binding.SourceSha256 =
                LPlan[LPlanIndex].Segment.Journal.Binding.SourceSha256) then
            begin
              raise EAudio.Create('Palette starter includes a declared evaluation source');
            end;
          end;
        end;
      end;
      LBinding := LBound[0].Binding;
      if AcousticVocabularySha256(LStarter.Palette, LBinding.Options,
        LBinding.SampleRate, LBinding.Channels) <> LStarter.VocabularySha256 then
      begin
        raise EAudio.Create('Palette starter analysis/timebase differs from the new sources');
      end;
      LPalette := TAcousticPalette.CreateFromCenters(LStarter.Palette.CopyCenters);
    end;
    LModel := LearnJournalAcousticModel(LReader, LPalette, 2);
    LPool := TJournalCandidatePool.Create(LReader, LPalette, LBins);
    LModelText := EncodeWfcSequenceText(LModel);
    LReloaded := DecodeWfcSequenceText(LModelText);
    LGeneration := DefaultAcousticGenerationOptions;
    LGeneration.FrameCount := 128;
    LGeneration.Seed := 731;
    if not TryGenerateAcousticSequence(LReloaded, LGeneration, nil, LIndices, LSolve) then
    begin
      raise EAudio.Create('Journal-trained WFC generation failed; no outputs published');
    end;
    LBinding := LBound[0].Binding;
    LSelection := LPool.Select(LIndices, LSourceWeights, LSelectionSeed);
    LAudioAccess := TJournalAudioAccess.Create;
    SetLength(LAudioAccess.Waves, LCount);
    for LIndex := 0 to LCount - 1 do
    begin
      LAudioAccess.Waves[LIndex] := LBound[LIndex].Wave;
    end;
    if LJoinPasses > 0 then
    begin
      LJoinOptions.Passes := LJoinPasses;
      LJoinPlanner := TJournalJoinPlanner.Create(LPool, LAudioAccess.ReadWindow,
        LBinding.Options.WindowFrames, LBinding.Options.HopFrames, LBinding.Channels,
        LJoinOptions);
      LJoinBefore := LJoinPlanner.Evaluate(LSelection);
      LSelection := LJoinPlanner.Plan(LSelection, nil, LJoinAfter);
    end;
    SetLength(LUsedSlots, LPool.SlotCount);
    SetLength(LSourceUse, LCount);
    LUnique := 0;
    LRepeats := 0;
    LContiguous := 0;
    LSwitches := 0;
    LPrevious := Default(TJournalRepresentative);
    for LIndex := 0 to High(LIndices) do
    begin
      LSlot := LSelection[LIndex];
      LRepresentative := LPool.CandidateAt(LSlot);
      LSource := LRepresentative.SegmentIndex;
      Inc(LSourceUse[LSource]);
      if not LUsedSlots[LSlot] then
      begin
        LUsedSlots[LSlot] := True;
        Inc(LUnique);
      end;
      if LIndex > 0 then
      begin
        if LPrevious.SegmentIndex <> LSource then
        begin
          Inc(LSwitches);
        end
        else if LPrevious.SourceFrame = LRepresentative.SourceFrame then
        begin
          Inc(LRepeats);
        end
        else if LPrevious.SourceFrame + LBinding.Options.HopFrames =
          LRepresentative.SourceFrame then
        begin
          Inc(LContiguous);
        end;
      end;
      LPrevious := LRepresentative;
    end;
    LRendered := RenderJournalSelection(LPool, LSelection, LAudioAccess.ReadWindow,
      LBinding.SampleRate, LBinding.Channels, LBinding.Options.WindowFrames,
      LBinding.Options.HopFrames);
    if LRendered.FrameCount <> (Length(LIndices) - 1) * LBinding.Options.HopFrames +
      LBinding.Options.WindowFrames then
    begin
      raise EAudio.Create('Candidate selection changed the audition timebase');
    end;
    LLevels := MeasureAudio(LRendered);
    for LIndex := 0 to High(LLevels) do
    begin
      if LLevels[LIndex].Peak > 1 then
      begin
        raise EAudio.Create('Representative audition exceeds PCM16 headroom; prepare source gain');
      end;
    end;
    LWaveBytes := EncodeWavePcm16(LRendered);
    for LIndex := 0 to High(LOwnedBound) do
    begin
      if LOwnedBound[LIndex] <> nil then
      begin
        LOwnedBound[LIndex].VerifySource;
      end;
    end;
    LDocument := TJSONObject.Create;
    if LPartitionAudit <> nil then
    begin
      LDocument.Add('partition_selection', LPartitionAudit);
      LPartitionAudit := nil;
    end;
    LDocument.Add('contract', 'pythian.acoustic.journal-learning');
    LDocument.Add('analysis_version', AnalysisVersion);
    LDocument.Add('learning_version', AcousticLearningVersion);
    LDocument.Add('raw_observations', LReader.ObservationCount);
    LDocument.Add('weighted_observations', LReader.WeightedObservationCount);
    LDocument.Add('wfc_observations', LModel.ObservationCount);
    LDocument.Add('wfc_samples', LModel.SampleCount);
    LDocument.Add('wfc_states', LModel.StateCount);
    LDocument.Add('order', LModel.Order);
    LVocabularyHash := AcousticVocabularySha256(LPalette, LBinding.Options,
      LBinding.SampleRate, LBinding.Channels);
    LDocument.Add('vocabulary_sha256', LVocabularyHash);
    LDocument.Add('model_binding_sha256', AcousticModelBindingSha256(
      LVocabularyHash, HashText(LModelText)));
    LDocument.Add('model_sha256', HashText(LModelText));
    if LStarter <> nil then
    begin
      LDocument.Add('palette_parent_vocabulary_sha256', LStarter.VocabularySha256);
      LDocument.Add('palette_parent_model_sha256', LStarter.ModelSha256);
    end;
    LDocument.Add('audition_sha256', HashAudioBytes(LWaveBytes));
    LDocument.Add('audition_frames', LRendered.FrameCount);
    LDocument.Add('sample_rate', LBinding.SampleRate);
    LDocument.Add('channels', LBinding.Channels);
    LDocument.Add('window_frames', LBinding.Options.WindowFrames);
    LDocument.Add('hop_frames', LBinding.Options.HopFrames);
    LDocument.Add('silence_rms', LBinding.Options.SilenceRms);
    LDocument.Add('generated_from_serialized_model', True);
    LDocument.Add('seed', 731);
    LDocument.Add('candidate_bins_per_segment', LBins);
    LDocument.Add('selection_seed', LSelectionSeed);
    LDocument.Add('join_passes', LJoinPasses);
    if LJoinPasses > 0 then
    begin
      LJoinJson := TJSONObject.Create;
      LDocument.Add('join_planning', LJoinJson);
      LJoinJson.Add('probe_frames', LJoinOptions.ProbeFrames);
      LJoinJson.Add('seam_weight', LJoinOptions.SeamWeight);
      LJoinJson.Add('source_switch_weight', LJoinOptions.SourceSwitchWeight);
      LJoinJson.Add('center_weight', LJoinOptions.CenterWeight);
      LJoinJson.Add('passes_completed', LJoinAfter.Passes);
      LJoinJson.Add('swap_radius', LJoinOptions.SwapRadius);
      LJoinJson.Add('probe_work_bound', LJoinAfter.ProbeWorkBound);
      LJoinJson.Add('accepted_edits', LJoinAfter.AcceptedEdits);
      LJoinJson.Add('before_mean_seam', LJoinBefore.MeanSeamError);
      LJoinJson.Add('after_mean_seam', LJoinAfter.MeanSeamError);
      LJoinJson.Add('before_mean_center_distance', LJoinBefore.MeanCenterError);
      LJoinJson.Add('after_mean_center_distance', LJoinAfter.MeanCenterError);
      LJoinJson.Add('before_cost', LJoinBefore.TotalCost);
      LJoinJson.Add('after_cost', LJoinAfter.TotalCost);
      LJoinJson.Add('before_source_switches', LJoinBefore.SourceSwitches);
      LJoinJson.Add('after_source_switches', LJoinAfter.SourceSwitches);
      LJoinJson.Add('before_repeated_windows', LJoinBefore.RepeatedWindows);
      LJoinJson.Add('after_repeated_windows', LJoinAfter.RepeatedWindows);
    end;
    LDocument.Add('unique_selected_windows', LUnique);
    LDocument.Add('adjacent_same_window', LRepeats);
    LDocument.Add('contiguous_source_links', LContiguous);
    LDocument.Add('source_switches', LSwitches);
    LDocument.Add('policy', 'Integer training multiplicity; fixed shared palette/model; nearest token candidate per segment/time bin; independent soft source weights among eligible segments; rotating candidate bins; optional join edits preserve tokens, per-token/source counts and repeat ceiling; no semantic style acceptance');
    LSourcesJson := TJSONArray.Create;
    LDocument.Add('sources', LSourcesJson);
    for LIndex := 0 to High(LBound) do
    begin
      LRow := TJSONObject.Create;
      LSourcesJson.Add(LRow);
      LRow.Add('source', ExtractFileName(LPaths[LIndex]));
      LRow.Add('source_sha256', LBound[LIndex].Binding.SourceSha256);
      LRow.Add('cache_sha256', LBound[LIndex].CacheHash);
      LRow.Add('source_frames', LBound[LIndex].Binding.FrameCount);
      LRow.Add('first_feature', LSegments[LIndex].FirstFeature);
      LRow.Add('observations', LSegments[LIndex].FeatureCount);
      LRow.Add('multiplicity', LWeights[LIndex]);
      LRow.Add('generation_weight', LSourceWeights[LIndex]);
      LRow.Add('generated_grains', LSourceUse[LIndex]);
    end;
    LPaletteJson := TJSONArray.Create;
    LDocument.Add('palette', LPaletteJson);
    LRepresentativesJson := TJSONArray.Create;
    LDocument.Add('candidates', LRepresentativesJson);
    for LToken := 0 to LPalette.Count - 1 do
    begin
      LCenter := TJSONArray.Create;
      LPaletteJson.Add(LCenter);
      LVector := LPalette.CenterAt(LToken);
      for LComponent := 0 to High(LVector) do
      begin
        LCenter.Add(LVector[LComponent]);
      end;
    end;
    for LSlot := 0 to LPool.SlotCount - 1 do
    begin
      LRepresentative := LPool.CandidateAt(LSlot);
      if not LRepresentative.Found then
      begin
        Continue;
      end;
      LRow := TJSONObject.Create;
      LRepresentativesJson.Add(LRow);
      LRow.Add('slot', LSlot);
      LRow.Add('token', LPool.TokenAt(LSlot));
      LRow.Add('source_index', LRepresentative.SegmentIndex);
      LRow.Add('source_frame', LRepresentative.SourceFrame);
      LRow.Add('feature_index', LRepresentative.FeatureIndex);
      LRow.Add('valid_frames', LRepresentative.ValidFrames);
      LRow.Add('center_distance', LRepresentative.Distance);
    end;
    LSelectionsJson := TJSONArray.Create;
    LDocument.Add('generated_candidate_slots', LSelectionsJson);
    for LIndex := 0 to High(LSelection) do
    begin
      LSelectionsJson.Add(LSelection[LIndex]);
    end;
    LEvents := TJSONArray.Create;
    LDocument.Add('generated_tokens', LEvents);
    for LIndex := 0 to High(LIndices) do
    begin
      LEvents.Add(LIndices[LIndex]);
    end;
    PublishJournalResult(LPrefix, LModelText, LDocument.FormatJSON, True, LWaveBytes);
    WriteLn('Learned ', LModel.ObservationCount, ' weighted observations, ',
      LModel.StateCount, ' WFC states; rendered ', LRendered.FrameCount, ' frames');
  finally
    LPartitionAudit.Free;
    LDocument.Free;
    LRendered.Free;
    LReloaded.Free;
    LModel.Free;
    LJoinPlanner.Free;
    LAudioAccess.Free;
    LPool.Free;
    LPalette.Free;
    LStarter.Free;
    LReader.Free;
    for LIndex := 0 to High(LOwnedBound) do
    begin
      LOwnedBound[LIndex].Free;
    end;
  end;
end;

function ReadProfileText(const APath: String): UTF8String;
var
  LBytes: TAudioBytes;
begin
  LBytes := ReadFileBytes(APath, MaximumJournalProfileBytes);
  SetLength(Result, Length(LBytes));
  if Length(LBytes) > 0 then
  begin
    Move(LBytes[0], Result[1], Length(LBytes));
  end;
end;

procedure AttachJournalContexts;
var
  LProfile: TJournalModelProfile;
  LAttached: TJournalModelProfile;
  LContexts: TJournalContextPool;
  LReader: TJournalTrainingReader;
  LGuard: TJournalAudioAccess;
  LStreams: array of TFileStream;
  LJournals: array of TFeatureJournal;
  LSegments: TJournalTrainingSegments;
  LSource: TJournalProfileSource;
  LDocument: TJSONObject;
  LPrefix: String;
  LSuffix: String;
  LIndex: Integer;
  LOther: Integer;
  LMaximum: Integer;
  LFirstReference: Boolean;
begin
  if ParamCount < 5 then
  begin
    raise EAudio.Create('Usage: pythian.learn contexts INPUT_PREFIX OUTPUT_PREFIX MAX_GRAINS CACHE.pyaf [...]');
  end;
  LPrefix := ParamStr(3);
  LMaximum := StrToInt(ParamStr(4));
  for LSuffix in ['.json', '.wfcs', '.wav'] do
  begin
    if FileExists(LPrefix + LSuffix) or
      SameFileName(ExpandFileName(LPrefix + LSuffix), ExpandFileName(ParamStr(2) + LSuffix)) then
    begin
      raise EAudio.Create('Context attachment requires a fresh output prefix');
    end;
    for LIndex := 5 to ParamCount do
    begin
      if SameFileName(ExpandFileName(LPrefix + LSuffix), ExpandFileName(ParamStr(LIndex))) then
      begin
        raise EAudio.Create('Context output must differ from every input cache');
      end;
    end;
  end;
  LProfile := nil;
  LAttached := nil;
  LContexts := nil;
  LReader := nil;
  LDocument := nil;
  LGuard := TJournalAudioAccess.Create;
  try
    LProfile := TJournalModelProfile.Create(ReadProfileText(ParamStr(2) + '.json'),
      ReadProfileText(ParamStr(2) + '.wfcs'));
    if ParamCount - 4 <> LProfile.SourceCount then
    begin
      raise EAudio.Create('Supply one exact cache per saved source, in profile order');
    end;
    SetLength(LStreams, LProfile.SourceCount);
    SetLength(LJournals, LProfile.SourceCount);
    SetLength(LSegments, LProfile.SourceCount);
    for LIndex := 0 to LProfile.SourceCount - 1 do
    begin
      LSource := LProfile.SourceAt(LIndex);
      for LOther := 0 to LIndex - 1 do
      begin
        if SameFileName(ExpandFileName(ParamStr(5 + LIndex)),
          ExpandFileName(ParamStr(5 + LOther))) and
          (LSource.Binding.SourceSha256 =
            LProfile.SourceAt(LOther).Binding.SourceSha256) then
        begin
          LStreams[LIndex] := LStreams[LOther];
          LJournals[LIndex] := LJournals[LOther];
          Break;
        end;
      end;
      if LJournals[LIndex] = nil then
      begin
        LStreams[LIndex] := TFileStream.Create(ParamStr(5 + LIndex), fmOpenRead or fmShareDenyWrite);
        if Sha256Stream(LStreams[LIndex], LStreams[LIndex].Size) <> LSource.CacheSha256 then
        begin
          raise EAudio.Create('Context cache bytes differ from saved identity');
        end;
        LJournals[LIndex] := TFeatureJournal.Create(LStreams[LIndex], LSource.Binding,
          LGuard.RejectWrite, False);
      end;
      LSegments[LIndex].Journal := LJournals[LIndex];
      LSegments[LIndex].FirstFeature := LSource.FirstFeature;
      LSegments[LIndex].FeatureCount := LSource.FeatureCount;
      LSegments[LIndex].Multiplicity := 1;
    end;
    LReader := TJournalTrainingReader.Create(LSegments);
    LContexts := TJournalContextPool.Create(LReader, LProfile.Palette, LProfile.Pool, LMaximum);
    LAttached := LProfile.WithContexts(LContexts);
    LDocument := TJSONObject(GetJSON(LAttached.EncodeReport));
    LDocument.Delete('audition_sha256');
    LDocument.Delete('audition_frames');
    LDocument.Elements['contexts_attached_without_rendering'] := TJSONBoolean.Create(True);
    PublishJournalResult(LPrefix, LAttached.EncodeModel, LDocument.FormatJSON, False, nil);
    WriteLn('Attached ', LContexts.Count, ' source contexts / ', LContexts.WindowCount,
      ' windows without changing the model; use replay --context-grains to audition');
  finally
    LDocument.Free;
    LAttached.Free;
    LContexts.Free;
    LReader.Free;
    for LIndex := 0 to High(LJournals) do
    begin
      LFirstReference := True;
      for LOther := 0 to LIndex - 1 do
      begin
        if LJournals[LIndex] = LJournals[LOther] then
        begin
          LFirstReference := False;
          Break;
        end;
      end;
      if LFirstReference then
      begin
        LJournals[LIndex].Free;
        LStreams[LIndex].Free;
      end;
    end;
    LGuard.Free;
    LProfile.Free;
  end;
end;

procedure BlendJournalFiles;
var
  LLeft: TJournalModelProfile;
  LRight: TJournalModelProfile;
  LBlend: TJournalModelProfile;
  LPrefix: String;
  LSuffix: String;
  LIndex: Integer;
begin
  if ParamCount <> 6 then
  begin
    raise EAudio.Create('Usage: pythian.learn blend LEFT_PREFIX RIGHT_PREFIX OUTPUT_PREFIX LEFT_WEIGHT RIGHT_WEIGHT');
  end;
  LPrefix := ParamStr(4);
  for LIndex := 2 to 3 do
  begin
    for LSuffix in ['.json', '.wfcs', '.wav'] do
    begin
      if SameFileName(ExpandFileName(LPrefix + LSuffix),
        ExpandFileName(ParamStr(LIndex) + LSuffix)) then
      begin
        raise EAudio.Create('Blend output must differ from each parent');
      end;
    end;
  end;
  if FileExists(LPrefix + '.wav') then
  begin
    raise EAudio.Create('Blend output prefix contains an audition; choose a fresh prefix');
  end;
  LLeft := nil;
  LRight := nil;
  LBlend := nil;
  try
    LLeft := TJournalModelProfile.Create(ReadProfileText(ParamStr(2) + '.json'),
      ReadProfileText(ParamStr(2) + '.wfcs'));
    LRight := TJournalModelProfile.Create(ReadProfileText(ParamStr(3) + '.json'),
      ReadProfileText(ParamStr(3) + '.wfcs'));
    LBlend := BlendJournalProfiles(LLeft, LRight, StrToInt(ParamStr(5)), StrToInt(ParamStr(6)));
    PublishJournalResult(LPrefix, LBlend.EncodeModel, LBlend.EncodeReport, False, nil);
    WriteLn('Blended ', LBlend.Model.ObservationCount, ' observations, ',
      LBlend.Model.SampleCount, ' weighted samples, ', LBlend.SourceCount,
      ' distinct source ranges; use replay with explicit WAVs to audition');
  finally
    LBlend.Free;
    LRight.Free;
    LLeft.Free;
  end;
end;

procedure ReplaceJson(const AObject: TJSONObject; const AName: String; const AValue: TJSONData);
begin
  AObject.Elements[AName] := AValue;
end;

procedure ReplayJournalFiles;
var
  LProfile: TJournalModelProfile;
  LAudioAccess: TJournalAudioAccess;
  LPlanner: TJournalJoinPlanner;
  LContextOptions: TJournalContextOptions;
  LContextReport: TJournalContextReport;
  LContextPlan: TJournalContextWindows;
  LBoundaryOptions: TJournalContextJoinOptions;
  LBoundaryReport: TJournalContextJoinReport;
  LBoundaryPasses: Integer;
  LContextGrains: Integer;
  LChosenWindows: TJournalRepresentatives;
  LContextWindowsJson: TJSONArray;
  LContextJson: TJSONObject;
  LOther: Integer;
  LSeen: Boolean;
  LRendered: TAudioClip;
  LDocument: TJSONObject;
  LSourcesJson: TJSONArray;
  LRow: TJSONObject;
  LJoinJson: TJSONObject;
  LEvents: TJSONArray;
  LSlotsJson: TJSONArray;
  LOptions: TAcousticGenerationOptions;
  LJoinOptions: TJournalJoinOptions;
  LBefore: TJournalJoinReport;
  LAfter: TJournalJoinReport;
  LSource: TJournalProfileSource;
  LPaths: array of String;
  LInputWeights: array of Integer;
  LStreams: array of TFileStream;
  LReaders: array of TWaveFrameReader;
  LHashes: array of String;
  LWeights: TJournalSelectionWeights;
  LUsage: array of Integer;
  LUsed: array of Boolean;
  LIndices: TAcousticIndices;
  LSelection: TAcousticIndices;
  LSolve: TGraphSolveReport;
  LLevels: TAudioLevels;
  LBytes: TAudioBytes;
  LReportText: UTF8String;
  LModelText: UTF8String;
  LInputPrefix: String;
  LOutputPrefix: String;
  LSuffix: String;
  LArgument: Integer;
  LValue: Integer;
  LWeight: Integer;
  LSelectionSeed: Integer;
  LJoinPasses: Integer;
  LIndex: Integer;
  LSourceIndex: Integer;
  LCount: Integer;
  LMatched: Boolean;
  LCandidate: TJournalRepresentative;
  LPrevious: TJournalRepresentative;
  LUnique: Integer;
  LRepeats: Integer;
  LSwitches: Integer;
  LContiguous: Integer;
begin
  if ParamCount < 4 then
  begin
    raise EAudio.Create('Usage: pythian.learn replay INPUT_PREFIX OUTPUT_PREFIX [OPTIONS] SOURCE.wav [...]');
  end;
  LInputPrefix := ParamStr(2);
  LOutputPrefix := ParamStr(3);
  for LSuffix in ['.json', '.wfcs', '.wav'] do
  begin
    if SameFileName(ExpandFileName(LOutputPrefix + LSuffix),
      ExpandFileName(LInputPrefix + LSuffix)) then
    begin
      raise EAudio.Create('Replay output must differ from the saved input profile');
    end;
  end;
  LProfile := nil;
  LAudioAccess := nil;
  LPlanner := nil;
  LRendered := nil;
  LDocument := nil;
  try
    LReportText := ReadProfileText(LInputPrefix + '.json');
    LModelText := ReadProfileText(LInputPrefix + '.wfcs');
    LProfile := TJournalModelProfile.Create(LReportText, LModelText);
    LDocument := TJSONObject(GetJSON(LReportText));
    LSourcesJson := TJSONArray(LDocument.Find('sources'));
    LOptions := DefaultAcousticGenerationOptions;
    LOptions.StateCellBudget := LDocument.Get('state_cell_budget', DefaultAcousticStateCells);
    LOptions.Seed := LDocument.Get('seed', 731);
    LOptions.FrameCount := 128;
    if (LDocument.Find('generated_tokens') <> nil) and
      (LDocument.Find('generated_tokens').JSONType = jtArray) then
    begin
      LOptions.FrameCount := LDocument.Find('generated_tokens').Count;
    end;
    LSelectionSeed := LDocument.Get('selection_seed', 731);
    LContextGrains := LDocument.Get('context_grains', 0);
    LContextOptions := DefaultJournalContextOptions;
    LContextOptions.MaximumContextUses := LDocument.Get('context_uses', 0);
    LBoundaryOptions := DefaultJournalContextJoinOptions;
    LBoundaryPasses := LDocument.Get('context_join_passes', 0);
    LBoundaryOptions.ProbeFrames := LDocument.Get('context_join_probes', 64);
    LBoundaryOptions.SwapRadius := LDocument.Get('context_join_radius', 8);
    LJoinPasses := LDocument.Get('join_passes', 0);
    LJoinOptions := DefaultJournalJoinOptions;
    if LDocument.Find('join_planning') <> nil then
    begin
      if LDocument.Find('join_planning').JSONType <> jtObject then
      begin
        raise EAudio.Create('Saved join policy must be an object');
      end;
      LJoinJson := TJSONObject(LDocument.Find('join_planning'));
      LJoinOptions.ProbeFrames := LJoinJson.Get('probe_frames', 16);
      LJoinOptions.SwapRadius := LJoinJson.Get('swap_radius', 0);
      LJoinOptions.SeamWeight := LJoinJson.Get('seam_weight', Double(1));
      LJoinOptions.SourceSwitchWeight := LJoinJson.Get('source_switch_weight', Double(0.2));
      LJoinOptions.CenterWeight := LJoinJson.Get('center_weight', Double(0.05));
    end;
    SetLength(LWeights, LProfile.SourceCount);
    for LIndex := 0 to High(LWeights) do
    begin
      LWeights[LIndex] := TJSONObject(LSourcesJson.Items[LIndex]).Get('generation_weight', 1);
    end;
    LArgument := 4;
    LWeight := -1;
    LCount := 0;
    while LArgument <= ParamCount do
    begin
      if Copy(ParamStr(LArgument), 1, 2) = '--' then
      begin
        if LArgument = ParamCount then
        begin
          raise EAudio.Create('Replay option requires an integer');
        end;
        LValue := StrToInt(ParamStr(LArgument + 1));
        if LValue < 0 then
        begin
          raise EAudio.Create('Replay options must be nonnegative');
        end;
        if ParamStr(LArgument) = '--seed' then
        begin
          LOptions.Seed := LValue;
        end
        else if ParamStr(LArgument) = '--selection-seed' then
        begin
          LSelectionSeed := LValue;
        end
        else if ParamStr(LArgument) = '--frames' then
        begin
          LOptions.FrameCount := LValue;
        end
        else if ParamStr(LArgument) = '--state-cells' then
        begin
          LOptions.StateCellBudget := LValue;
        end
        else if ParamStr(LArgument) = '--join-passes' then
        begin
          LJoinPasses := LValue;
        end
        else if ParamStr(LArgument) = '--join-swap-radius' then
        begin
          LJoinOptions.SwapRadius := LValue;
        end
        else if ParamStr(LArgument) = '--context-grains' then
        begin
          LContextGrains := LValue;
        end
        else if ParamStr(LArgument) = '--context-uses' then
        begin
          LContextOptions.MaximumContextUses := LValue;
        end
        else if ParamStr(LArgument) = '--context-join-passes' then
        begin
          LBoundaryPasses := LValue;
        end
        else if ParamStr(LArgument) = '--context-join-probes' then
        begin
          LBoundaryOptions.ProbeFrames := LValue;
        end
        else if ParamStr(LArgument) = '--context-join-radius' then
        begin
          LBoundaryOptions.SwapRadius := LValue;
        end
        else if ParamStr(LArgument) = '--source-weight' then
        begin
          LWeight := LValue;
          if LArgument + 2 > ParamCount then
          begin
            raise EAudio.Create('Replay source weight must precede a source');
          end;
        end
        else
        begin
          raise EAudio.Create('Unknown journal replay option');
        end;
        Inc(LArgument, 2);
        Continue;
      end;
      if LCount = 32 then
      begin
        raise EAudio.Create('Replay accepts at most 32 explicit source files');
      end;
      SetLength(LPaths, LCount + 1);
      SetLength(LInputWeights, LCount + 1);
      LPaths[LCount] := ParamStr(LArgument);
      LInputWeights[LCount] := LWeight;
      for LSuffix in ['.json', '.wfcs', '.wav'] do
      begin
        if SameFileName(ExpandFileName(LOutputPrefix + LSuffix), ExpandFileName(LPaths[LCount])) then
        begin
          raise EAudio.Create('Replay output must differ from each source file');
        end;
      end;
      Inc(LCount);
      Inc(LArgument);
    end;
    if (LCount < 1) or (LSelectionSeed < 0) or (LJoinPasses < 0) or
      (LJoinOptions.SwapRadius < 0) or (LJoinOptions.SwapRadius >= MaximumJournalSelectionGrains) or
      (LJoinPasses > 8) or (LOptions.FrameCount < 1) or (LOptions.FrameCount > 1024) then
    begin
      raise EAudio.Create('Replay source count, frame count or selection policy invalid');
    end;
    if (LOptions.StateCellBudget < 1) or
      (LOptions.StateCellBudget > MaximumAcousticStateCells) then
    begin
      raise EAudio.Create('Replay state-cell budget must be 1..1048576');
    end;
    if (LContextGrains < 0) or (LContextGrains > MaximumJournalContextGrains) or
      (LContextOptions.MaximumContextUses < 0) or
      (LContextOptions.MaximumContextUses > MaximumJournalSelectionGrains) or
      ((LContextGrains > 0) and (LProfile.Contexts = nil)) then
    begin
      raise EAudio.Create('Context policy invalid or saved contexts are absent');
    end;
    if (LBoundaryPasses < 0) or (LBoundaryPasses > 8) or
      (LBoundaryOptions.ProbeFrames < 1) or (LBoundaryOptions.ProbeFrames > 64) or
      (LBoundaryOptions.SwapRadius < 1) or (LBoundaryOptions.SwapRadius > 64) or
      ((LBoundaryPasses > 0) and (LContextGrains = 0)) then
    begin
      raise EAudio.Create('Context boundary policy invalid or context stage is disabled');
    end;
    SetLength(LStreams, LCount);
    SetLength(LReaders, LCount);
    SetLength(LHashes, LCount);
    LAudioAccess := TJournalAudioAccess.Create;
    SetLength(LAudioAccess.Waves, LProfile.SourceCount);
    for LIndex := 0 to LCount - 1 do
    begin
      LStreams[LIndex] := TFileStream.Create(LPaths[LIndex], fmOpenRead or fmShareDenyWrite);
      LReaders[LIndex] := TWaveFrameReader.Create(LStreams[LIndex]);
      LStreams[LIndex].Position := 0;
      LHashes[LIndex] := Sha256Stream(LStreams[LIndex], LStreams[LIndex].Size);
      LMatched := False;
      for LSourceIndex := 0 to LProfile.SourceCount - 1 do
      begin
        LSource := LProfile.SourceAt(LSourceIndex);
        if LSource.Binding.SourceSha256 <> LHashes[LIndex] then
        begin
          Continue;
        end;
        if (LAudioAccess.Waves[LSourceIndex] <> nil) or
          (LReaders[LIndex].SampleRate <> LProfile.SampleRate) or
          (LReaders[LIndex].Channels <> LProfile.Channels) or
          (LReaders[LIndex].FrameCount <> LSource.Binding.FrameCount) then
        begin
          raise EAudio.Create('Replay source is duplicated or has mismatched geometry');
        end;
        LMatched := True;
        LAudioAccess.Waves[LSourceIndex] := LReaders[LIndex];
        if LInputWeights[LIndex] >= 0 then
        begin
          LWeights[LSourceIndex] := LInputWeights[LIndex];
        end;
      end;
      if not LMatched then
      begin
        raise EAudio.Create('Explicit WAV does not match a saved source hash');
      end;
    end;
    for LSourceIndex := 0 to LProfile.SourceCount - 1 do
    begin
      if LAudioAccess.Waves[LSourceIndex] = nil then
      begin
        raise EAudio.Create('Supply every saved source by its exact file hash');
      end;
    end;
    if not TryGenerateAcousticSequence(LProfile.Model, LOptions, nil, LIndices, LSolve) then
    begin
      raise EAudio.Create('Saved journal model cannot satisfy generation request');
    end;
    LSelection := LProfile.Pool.Select(LIndices, LWeights, LSelectionSeed);
    if LJoinPasses > 0 then
    begin
      LJoinOptions.Passes := LJoinPasses;
      LPlanner := TJournalJoinPlanner.Create(LProfile.Pool, LAudioAccess.ReadWindow,
        LProfile.Options.WindowFrames, LProfile.Options.HopFrames, LProfile.Channels, LJoinOptions);
      LBefore := LPlanner.Evaluate(LSelection);
      LSelection := LPlanner.Plan(LSelection, nil, LAfter);
    end;
    if LContextGrains > 0 then
    begin
      LContextOptions.MaximumRunGrains := LContextGrains;
      LContextOptions.Seed := LSelectionSeed;
      LContextPlan := LProfile.Contexts.Plan(LSelection, nil, LContextOptions, LContextReport);
      if LBoundaryPasses > 0 then
      begin
        LBoundaryOptions.Passes := LBoundaryPasses;
        LContextPlan := PlanJournalContextJoins(LContextPlan, nil, LAudioAccess.ReadWindow,
          LProfile.Options.WindowFrames, LProfile.Options.HopFrames, LProfile.Channels,
          LBoundaryOptions, LBoundaryReport);
      end;
      LRendered := RenderJournalContexts(LContextPlan, LAudioAccess.ReadWindow,
        LProfile.SampleRate, LProfile.Channels, LProfile.Options.WindowFrames, LProfile.Options.HopFrames);
    end
    else
    begin
      LRendered := RenderJournalSelection(LProfile.Pool, LSelection, LAudioAccess.ReadWindow,
        LProfile.SampleRate, LProfile.Channels, LProfile.Options.WindowFrames, LProfile.Options.HopFrames);
    end;
    LLevels := MeasureAudio(LRendered);
    for LIndex := 0 to High(LLevels) do
    begin
      if LLevels[LIndex].Peak > 1 then
      begin
        raise EAudio.Create('Saved-source audition exceeds PCM16 headroom');
      end;
    end;
    LBytes := EncodeWavePcm16(LRendered);
    for LIndex := 0 to LCount - 1 do
    begin
      LStreams[LIndex].Position := 0;
      if Sha256Stream(LStreams[LIndex], LStreams[LIndex].Size) <> LHashes[LIndex] then
      begin
        raise EAudio.Create('Replay source changed; no outputs published');
      end;
    end;
    SetLength(LUsage, LProfile.SourceCount);
    SetLength(LUsed, LProfile.Pool.SlotCount);
    LUnique := 0;
    LRepeats := 0;
    LSwitches := 0;
    LContiguous := 0;
    LPrevious := Default(TJournalRepresentative);
    LEvents := TJSONArray.Create;
    ReplaceJson(LDocument, 'generated_tokens', LEvents);
    LSlotsJson := TJSONArray.Create;
    LDocument.Delete('generated_candidate_slots');
    LDocument.Delete('base_candidate_slots');
    LDocument.Delete('generated_context_windows');
    LDocument.Delete('context_planning');
    LDocument.Delete('contexts_attached_without_rendering');
    LContextWindowsJson := nil;
    SetLength(LChosenWindows, Length(LSelection));
    if LContextGrains > 0 then
    begin
      LDocument.Add('base_candidate_slots', LSlotsJson);
      LContextWindowsJson := TJSONArray.Create;
      LDocument.Add('generated_context_windows', LContextWindowsJson);
      LContextJson := TJSONObject.Create;
      LDocument.Add('context_planning', LContextJson);
      LContextJson.Add('context_runs', LContextReport.ContextRuns);
      LContextJson.Add('context_grains', LContextReport.ContextGrains);
      LContextJson.Add('fallback_grains', LContextReport.FallbackGrains);
      LContextJson.Add('repair_edits', LContextReport.RepairEdits);
      LContextJson.Add('reverted', LContextReport.Reverted);
      LContextJson.Add('work_bound', LContextReport.WorkBound);
    end
    else
    begin
      LDocument.Add('generated_candidate_slots', LSlotsJson);
    end;
    for LIndex := 0 to High(LSelection) do
    begin
      LEvents.Add(LIndices[LIndex]);
      LSlotsJson.Add(LSelection[LIndex]);
      if LContextGrains > 0 then
      begin
        LCandidate := LContextPlan[LIndex].Candidate;
        LRow := TJSONObject.Create;
        LContextWindowsJson.Add(LRow);
        LRow.Add('source_index', LCandidate.SegmentIndex);
        LRow.Add('feature_index', LCandidate.FeatureIndex);
        LRow.Add('source_frame', LCandidate.SourceFrame);
        LRow.Add('valid_frames', LCandidate.ValidFrames);
        LSeen := False;
        for LOther := 0 to LIndex - 1 do
        begin
          if (LChosenWindows[LOther].SegmentIndex = LCandidate.SegmentIndex) and
            (LChosenWindows[LOther].SourceFrame = LCandidate.SourceFrame) then
          begin
            LSeen := True;
            Break;
          end;
        end;
        if not LSeen then
        begin
          Inc(LUnique);
        end;
      end
      else
      begin
        LCandidate := LProfile.Pool.CandidateAt(LSelection[LIndex]);
        if not LUsed[LSelection[LIndex]] then
        begin
          Inc(LUnique);
          LUsed[LSelection[LIndex]] := True;
        end;
      end;
      LChosenWindows[LIndex] := LCandidate;
      Inc(LUsage[LCandidate.SegmentIndex]);
      if LIndex > 0 then
      begin
        if LCandidate.SegmentIndex <> LPrevious.SegmentIndex then
        begin
          Inc(LSwitches);
        end
        else if LCandidate.SourceFrame = LPrevious.SourceFrame then
        begin
          Inc(LRepeats);
        end
        else if LCandidate.SourceFrame = LPrevious.SourceFrame + LProfile.Options.HopFrames then
        begin
          Inc(LContiguous);
        end;
      end;
      LPrevious := LCandidate;
    end;
    for LIndex := 0 to LProfile.SourceCount - 1 do
    begin
      LRow := TJSONObject(LSourcesJson.Items[LIndex]);
      ReplaceJson(LRow, 'generation_weight', TJSONIntegerNumber.Create(LWeights[LIndex]));
      ReplaceJson(LRow, 'generated_grains', TJSONIntegerNumber.Create(LUsage[LIndex]));
    end;
    ReplaceJson(LDocument, 'seed', TJSONInt64Number.Create(LOptions.Seed));
    ReplaceJson(LDocument, 'state_cell_budget', TJSONIntegerNumber.Create(LOptions.StateCellBudget));
    ReplaceJson(LDocument, 'selection_seed', TJSONIntegerNumber.Create(LSelectionSeed));
    ReplaceJson(LDocument, 'join_passes', TJSONIntegerNumber.Create(LJoinPasses));
    ReplaceJson(LDocument, 'context_grains', TJSONIntegerNumber.Create(LContextGrains));
    ReplaceJson(LDocument, 'context_uses', TJSONIntegerNumber.Create(LContextOptions.MaximumContextUses));
    ReplaceJson(LDocument, 'context_join_passes', TJSONIntegerNumber.Create(LBoundaryPasses));
    ReplaceJson(LDocument, 'context_join_probes', TJSONIntegerNumber.Create(LBoundaryOptions.ProbeFrames));
    ReplaceJson(LDocument, 'context_join_radius', TJSONIntegerNumber.Create(LBoundaryOptions.SwapRadius));
    LDocument.Delete('context_join_planning');
    if LBoundaryPasses > 0 then
    begin
      LJoinJson := TJSONObject.Create;
      LDocument.Add('context_join_planning', LJoinJson);
      LJoinJson.Add('chunks', LBoundaryReport.ChunkCount);
      LJoinJson.Add('accepted_swaps', LBoundaryReport.AcceptedSwaps);
      LJoinJson.Add('passes_completed', LBoundaryReport.Passes);
      LJoinJson.Add('work_bound', LBoundaryReport.WorkBound);
      LJoinJson.Add('before_mean_seam', LBoundaryReport.Before.MeanSeamError);
      LJoinJson.Add('after_mean_seam', LBoundaryReport.After.MeanSeamError);
      LJoinJson.Add('before_mean_assembled_seam', LBoundaryReport.Before.MeanAssembledSeamError);
      LJoinJson.Add('after_mean_assembled_seam', LBoundaryReport.After.MeanAssembledSeamError);
      LJoinJson.Add('before_assembled_boundaries', LBoundaryReport.Before.AssembledBoundaries);
      LJoinJson.Add('after_assembled_boundaries', LBoundaryReport.After.AssembledBoundaries);
      LJoinJson.Add('before_repeated_windows', LBoundaryReport.Before.RepeatedWindows);
      LJoinJson.Add('after_repeated_windows', LBoundaryReport.After.RepeatedWindows);
    end;
    ReplaceJson(LDocument, 'unique_selected_windows', TJSONIntegerNumber.Create(LUnique));
    ReplaceJson(LDocument, 'adjacent_same_window', TJSONIntegerNumber.Create(LRepeats));
    ReplaceJson(LDocument, 'contiguous_source_links', TJSONIntegerNumber.Create(LContiguous));
    ReplaceJson(LDocument, 'source_switches', TJSONIntegerNumber.Create(LSwitches));
    ReplaceJson(LDocument, 'audition_frames', TJSONIntegerNumber.Create(LRendered.FrameCount));
    ReplaceJson(LDocument, 'audition_sha256', TJSONString.Create(HashAudioBytes(LBytes)));
    ReplaceJson(LDocument, 'replayed_without_learning', TJSONBoolean.Create(True));
    LDocument.Delete('join_planning');
    if LJoinPasses > 0 then
    begin
      LJoinJson := TJSONObject.Create;
      LDocument.Add('join_planning', LJoinJson);
      LJoinJson.Add('probe_frames', LJoinOptions.ProbeFrames);
      LJoinJson.Add('seam_weight', LJoinOptions.SeamWeight);
      LJoinJson.Add('source_switch_weight', LJoinOptions.SourceSwitchWeight);
      LJoinJson.Add('center_weight', LJoinOptions.CenterWeight);
      LJoinJson.Add('passes_completed', LAfter.Passes);
      LJoinJson.Add('swap_radius', LJoinOptions.SwapRadius);
      LJoinJson.Add('probe_work_bound', LAfter.ProbeWorkBound);
      LJoinJson.Add('accepted_edits', LAfter.AcceptedEdits);
      LJoinJson.Add('before_mean_seam', LBefore.MeanSeamError);
      LJoinJson.Add('after_mean_seam', LAfter.MeanSeamError);
      LJoinJson.Add('before_cost', LBefore.TotalCost);
      LJoinJson.Add('after_cost', LAfter.TotalCost);
      LJoinJson.Add('before_mean_center_distance', LBefore.MeanCenterError);
      LJoinJson.Add('after_mean_center_distance', LAfter.MeanCenterError);
      LJoinJson.Add('before_source_switches', LBefore.SourceSwitches);
      LJoinJson.Add('after_source_switches', LAfter.SourceSwitches);
      LJoinJson.Add('before_repeated_windows', LBefore.RepeatedWindows);
      LJoinJson.Add('after_repeated_windows', LAfter.RepeatedWindows);
    end;
    PublishJournalResult(LOutputPrefix, LModelText, LDocument.FormatJSON, True, LBytes);
    WriteLn('Replayed saved vocabulary/model without caches or learning; rendered ',
      LRendered.FrameCount, ' frames');
  finally
    LRendered.Free;
    LPlanner.Free;
    LAudioAccess.Free;
    for LIndex := 0 to High(LReaders) do
    begin
      LReaders[LIndex].Free;
    end;
    for LIndex := 0 to High(LStreams) do
    begin
      LStreams[LIndex].Free;
    end;
    LDocument.Free;
    LProfile.Free;
  end;
end;

end.
