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

unit pythian.wfc.musical.corpus;

{$mode delphi}
{$H+}

interface

uses pythian.music.proposal, pythian.music.sound, pythian.progress, pythian.music.selection,
  pythian.wfc.percussion, pythian.wfc.layers,
  wfc_model, wfc_sequence, wfc_music_voices_graph;

const
  MusicalCorpusPolicy = 'weighted-source-musical-proposals-v1';
  MaximumMusicalCorpusSources = 32;
  MaximumMusicalCorpusSelections = 64;
  MaximumMusicalCorpusRuns = 1024;

type
  TMusicalCorpusSource = record
    Sha256: String;
    GroupId: String;
    SampleRate: Integer;
    FrameCount: Int64;
    TrainingWeight: Integer;
    Classifications: TMusicClassifications;
  end;
  TMusicalCorpusSources = array of TMusicalCorpusSource;
  TMusicalCorpusSelection = record
    SourceIndex: Integer;
    StartFrame: Int64;
    EndFrame: Int64;
    Classifications: TMusicClassifications;
  end;
  TMusicalCorpusSelections = array of TMusicalCorpusSelection;
  TMusicalCorpusRun = record
    SourceIndex: Integer;
    StartFrame: Int64;
    Grid: TProposedMusicalGrid;
    { Empty admits every known cell. Otherwise this separate mask selects
      representative material without relabeling measured unknowns or history. }
    AdmittedCells: TMusicalProposalFlags;
  end;
  TMusicalCorpusRuns = array of TMusicalCorpusRun;
  TMusicalCorpusCoverage = record
    IncludedFrames: Int64;
    ExcludedFrames: Int64;
    ProcessedFrames: Int64;
    ModelUsedFrames: Int64;
    ProposedFrames: Int64;
    BudgetOmittedFrames: Int64;
    UnmodeledFrames: Int64;
    ModelCells: Integer;
    WeightedCells: Integer;
    Samples: Integer;
    WeightedSamples: Integer;
  end;
  TMusicalCorpusCoverages = array of TMusicalCorpusCoverage;
  TMusicalTokenMeaning = record
    Identity: String;
    Value: String;
  end;
  TMusicalTokenMeanings = array of TMusicalTokenMeaning;
  TMusicalProviderVocabulary = record
    Key: String;
    Codec: String;
    SchemaSha256: String;
    ModelSha256: String;
    { Array position is local to ModelSha256. Identity binds codec/key/value,
      never the model's encounter-order token number or observation count. }
    Tokens: TMusicalTokenMeanings;
  end;
  TMusicalProviderVocabularies = array of TMusicalProviderVocabulary;
  TMusicalCorpusContribution = record
    Identity: String;
    SourceIndex: Integer;
    RunIndex: Integer;
    FirstCell: Integer;
    CellCount: Integer;
    StartFrame: Int64;
    EndFrame: Int64;
    TrainingWeight: Integer;
  end;
  TMusicalCorpusContributions = array of TMusicalCorpusContribution;

  { Big Boss: owns learned symbolic models and detached source/proposal evidence.
    It owns no source PCM or instrument. Every known run is a separate open
    sample; unknowns, omitted time and different recordings never gain joins.
    Starting holds are explicitly rearticulated at each admitted sample boundary.
    Harmony/rhythm and the optional driven role stay paired by a context model;
    the remaining voices use learned models under those actual dependencies.
    Training weights multiply observations, not generation preferences.
    Classifications retain exact caller source/selection context. The primary
    music.selection rule can explicitly choose teaching examples before learning;
    labels alone do not identify instruments or alter the proposal policy. }
  TMusicalCorpus = class
  private
    FSources: TMusicalCorpusSources;
    FSelections: TMusicalCorpusSelections;
    FRuns: TMusicalCorpusRuns;
    FCoverage: TMusicalCorpusCoverages;
    FModels: array of TWfcSequenceModel;
    FConfig: TWfcMusicVoicesGraphConfig;
    FAllowedDrumRhythms: array[0..2] of TWfcModelTokens;
    FHasSound: Boolean;
    FSound: TMusicalSound;
    FRoleNames: TMusicalProposalNames;
    FVocabularies: TMusicalProviderVocabularies;
    FContributions: TMusicalCorpusContributions;
    FRevisionIdentity: String;
    procedure CaptureVocabularies(const AProgress: TWorkProgressCallback);
  public
    constructor Create(const ASources: TMusicalCorpusSources;
      const ASelections: TMusicalCorpusSelections; const ARuns: TMusicalCorpusRuns;
      const AOrder: Integer = 1; const ADrivenRole: Integer = 2;
      const AMaximumObservations: Integer = 65536;
      const AProgress: TWorkProgressCallback = nil);
    destructor Destroy; override;
    function CopySources: TMusicalCorpusSources;
    function CopySelections: TMusicalCorpusSelections;
    function CopyRuns: TMusicalCorpusRuns;
    function CopyCoverage: TMusicalCorpusCoverages;
    function CopyRoleNames: TMusicalProposalNames;
    function CopyProviderNames: TLayerModelTexts;
    function CopyVocabularies: TMusicalProviderVocabularies;
    function CopyContributions: TMusicalCorpusContributions;
    { Resolve a stable meaning in this exact revision. -1 means absent, not
      a fallback to the same numeric position in a different vocabulary. }
    function ResolveToken(const AProviderKey, ATokenIdentity: String): Integer;
    property RevisionIdentity: String read FRevisionIdentity;
    function CopyModelTexts(const AProgress: TWorkProgressCallback = nil): TLayerModelTexts;
    { Borrowed immutable models, detached config arrays. Keep this owner alive
      during the synchronous instrumental-plan construction, which clones them. }
    function Config: TWfcMusicVoicesGraphConfig;
    function ContextModel: TWfcSequenceModel;
    function CopyPercussion(const ASampleRate: Integer): TPercussionDefinitions;
    { Explicit spectral-brightness/dynamics recipe, weighted by used seconds
      times training influence, never claimed as source instrument recovery. }
    function ProposedSound(out ASound: TMusicalSound): Boolean;
  end;

implementation

uses SysUtils, Math, pythian.audio, pythian.time, pythian.hash,
  pythian.music.pattern, pythian.percussion, pythian.wfc.music,
  pythian.wfc.learning, pythian.wfc.providers,
  wfc_music, wfc_music_sequence, wfc_music_ensemble, wfc_music_ensemble_graph,
  wfc_sequence_text, pythian.text, pythian.binary;

type
  TProviderSamples = array of TWeightedSequenceSamples;

procedure Need(const ACondition: Boolean; const AMessage: String);
begin
  if not ACondition then
  begin
    raise EAudio.Create(AMessage);
  end;
end;

procedure CheckSourceIndex(const AIndex, ACount: Integer);
begin
  Need((AIndex >= 0) and (AIndex < ACount) and (AIndex = Trunc(AIndex)),
    'Musical corpus source index is outside its catalog');
end;

procedure AppendUnique(var ATokens: TWfcModelTokens; const AToken: String);
var
  I: Integer;
begin
  for I := 0 to High(ATokens) do
  begin
    if ATokens[I] = AToken then
    begin
      Exit;
    end;
  end;
  SetLength(ATokens, Length(ATokens) + 1);
  ATokens[High(ATokens)] := AToken;
end;

{ Big Boss: primary UTF-8/binary/SHA own encoding and hashing. Length-framed
  fields avoid separator ambiguity and native-byte/pas2js UTF-16 differences. }
function HashFields(const ADomain: String; const AFields: array of String): String;
var
  LHash: TSha256Hasher;
  LBytes: TAudioBytes;
  LSize: array[0..3] of Byte;
  I: Integer;
  procedure Field(const AText: String);
  begin
    LBytes := EncodeUTF8Text(AText, 16 * 1024 * 1024);
    WriteInt32LE(LSize, 0, Length(LBytes));
    LHash.Update(LSize, 0, 4);
    LHash.Update(LBytes, 0, Length(LBytes));
  end;
begin
  LHash := TSha256Hasher.Create;
  try
    Field(ADomain);
    WriteInt32LE(LSize, 0, Length(AFields));
    LHash.Update(LSize, 0, 4);
    for I := 0 to High(AFields) do
    begin
      Field(AFields[I]);
    end;
    Result := LHash.Finish;
  finally
    LHash.Free;
  end;
end;

constructor TMusicalCorpus.Create(const ASources: TMusicalCorpusSources;
  const ASelections: TMusicalCorpusSelections; const ARuns: TMusicalCorpusRuns;
  const AOrder, ADrivenRole, AMaximumObservations: Integer;
  const AProgress: TWorkProgressCallback);
var
  LBytes: TAudioBytes;
  LPreviousEnds: array of Int64;
  LSamples: TProviderSamples;
  LFrame: TWfcMusicEnsembleFrame;
  LSingle: TWfcMusicEnsembleFrame;
  LContext: TMusicalContextCell;
  LClock: TTempoMap;
  LRun: TMusicalCorpusRun;
  LSource: TMusicalCorpusSource;
  LInside: Boolean;
  LInSample: Boolean;
  LRoleCount: Integer;
  LProviderCount: Integer;
  LContextIndex: Integer;
  LSample: Integer;
  LToken: Integer;
  I: Integer;
  J: Integer;
  K: Integer;
  P: Integer;
  R: Integer;
  C: Integer;
  LRole: Integer;
  LSourceIndex: Integer;
  LPitch: Integer;
  LStart: Int64;
  LEnd: Int64;
  LRunUsed: Int64;
  LSecondsWeight: Double;
  LTotalSoundWeight: Double;
  LCutoff: Double;
  LSustain: Double;
  LFields: TLayerModelTexts;
  LProviderNames: TLayerModelTexts;
  LContribution: TMusicalCorpusContribution;
begin
  inherited Create;
  Need((Length(ASources) >= 1) and (Length(ASources) <= MaximumMusicalCorpusSources),
    'Musical learning requires 1..32 declared source recordings');
  Need((Length(ASelections) >= 1) and (Length(ASelections) <= MaximumMusicalCorpusSelections),
    'Musical learning requires 1..64 included whole/range selections');
  Need((Length(ARuns) >= 1) and (Length(ARuns) <= MaximumMusicalCorpusRuns),
    'Musical proposal run count exceeds its declared budget');
  SetLength(FCoverage, Length(ASources));
  SetLength(LPreviousEnds, Length(ASources));
  SetLength(LBytes, 64);
  for I := 0 to High(ASources) do
  begin
    ReportWork(AProgress, 'musical_corpus_sources', wuItems, I, Length(ASources));
    LSource := ASources[I];
    WriteSha256Hex(LBytes, 0, LSource.Sha256);
    ValidateAudioFormat(LSource.SampleRate, 1);
    RequireExactTimingCounter(LSource.FrameCount, 'Corpus source extent');
    Need((LSource.FrameCount > 0) and (LSource.GroupId <> '') and
      (Length(LSource.GroupId) <= 256), 'Musical sources require extent and group identity');
    Need((LSource.TrainingWeight >= 1) and (LSource.TrainingWeight <= 16) and
      (LSource.TrainingWeight = Trunc(LSource.TrainingWeight)), 'Track influence must be an integer 1..16');
    Need(Length(LSource.Classifications) <= MaximumMusicClassifications,
      'Too many source classifications');
    for J := 0 to High(LSource.Classifications) do
    begin
      ValidateMusicClassification(LSource.Classifications[J]);
    end;
    for J := 0 to I - 1 do
    begin
      Need(LSource.Sha256 <> ASources[J].Sha256, 'A recording may occur only once; use multiple selections');
    end;
  end;
  for I := 0 to High(ASelections) do
  begin
    LSourceIndex := ASelections[I].SourceIndex;
    CheckSourceIndex(LSourceIndex, Length(ASources));
    LStart := ASelections[I].StartFrame;
    LEnd := ASelections[I].EndFrame;
    RequireExactTimingCounter(LStart, 'Selection start');
    RequireExactTimingCounter(LEnd, 'Selection end');
    Need((LStart < LEnd) and (LEnd <= ASources[LSourceIndex].FrameCount),
      'Musical selection must be inside the original source clock');
    Need(Length(ASelections[I].Classifications) <= MaximumMusicClassifications,
      'Too many musical selection classifications');
    for J := 0 to High(ASelections[I].Classifications) do
    begin
      ValidateMusicClassification(ASelections[I].Classifications[J]);
    end;
    for J := 0 to I - 1 do
    begin
      if ASelections[J].SourceIndex = LSourceIndex then
      begin
        Need((LEnd <= ASelections[J].StartFrame) or (LStart >= ASelections[J].EndFrame),
          'Overlapping selections would count the same source time twice');
      end;
    end;
    Inc(FCoverage[LSourceIndex].IncludedFrames, LEnd - LStart);
  end;
  LRoleCount := Length(ARuns[0].Grid.RoleNames);
  Need((ADrivenRole >= -1) and (ADrivenRole < LRoleCount) and
    (ADrivenRole = Trunc(ADrivenRole)), 'Context-driven role is outside the musical arrangement');
  for I := 0 to High(ARuns) do
  begin
    ReportWork(AProgress, 'musical_corpus_runs', wuItems, I, Length(ARuns));
    LRun := ARuns[I];
    LSourceIndex := LRun.SourceIndex;
    CheckSourceIndex(LSourceIndex, Length(ASources));
    RequireExactTimingCounter(LRun.StartFrame, 'Proposal run start');
    ValidateProposedMusicalGrid(LRun.Grid, AProgress);
    Need((Length(LRun.AdmittedCells) = 0) or
      (Length(LRun.AdmittedCells) = Length(LRun.Grid.Frames)),
      'Musical admission mask differs from its original proposal grid');
    Need(LRun.Grid.SampleRate = ASources[LSourceIndex].SampleRate,
      'Proposal and original source sample rates differ');
    Need(LRun.StartFrame <= ASources[LSourceIndex].FrameCount - LRun.Grid.SourceFrames,
      'Proposal run exceeds original source time');
    LEnd := LRun.StartFrame + LRun.Grid.SourceFrames;
    Need(LRun.StartFrame >= LPreviousEnds[LSourceIndex],
      'Proposal runs must increase without overlap within each source');
    LPreviousEnds[LSourceIndex] := LEnd;
    LInside := False;
    for J := 0 to High(ASelections) do
    begin
      if (ASelections[J].SourceIndex = LSourceIndex) and
        (LRun.StartFrame >= ASelections[J].StartFrame) and
        (LEnd <= ASelections[J].EndFrame) then
      begin
        LInside := True;
      end;
    end;
    Need(LInside, 'A measured proposal must belong to an explicitly included selection');
    Need(Length(LRun.Grid.RoleNames) = LRoleCount, 'Musical runs require the same ordered role contract');
    for J := 0 to LRoleCount - 1 do
    begin
      Need(LRun.Grid.RoleNames[J] = ARuns[0].Grid.RoleNames[J], 'Musical run role order differs');
    end;
    Need(LRun.Grid.Policy = ARuns[0].Grid.Policy, 'Different proposal policies cannot silently share a vocabulary');
    Inc(FCoverage[LSourceIndex].ProcessedFrames, LRun.Grid.SourceFrames);
  end;
  FSources := Copy(ASources);
  for I := 0 to High(FSources) do
  begin
    FSources[I].Classifications := Copy(ASources[I].Classifications);
  end;
  FSelections := Copy(ASelections);
  for I := 0 to High(FSelections) do
  begin
    FSelections[I].Classifications := Copy(ASelections[I].Classifications);
  end;
  SetLength(FRuns, Length(ARuns));
  for I := 0 to High(ARuns) do
  begin
    FRuns[I] := ARuns[I];
    FRuns[I].Grid := CopyProposedMusicalGrid(ARuns[I].Grid);
    FRuns[I].AdmittedCells := Copy(ARuns[I].AdmittedCells);
  end;
  FRoleNames := Copy(ARuns[0].Grid.RoleNames);
  LContextIndex := LRoleCount + 2;
  LProviderCount := LRoleCount + 6;
  SetLength(LSamples, LProviderCount);
  SetLength(FModels, LProviderCount);
  SetLength(FConfig.Voices, LRoleCount);
  FConfig.StepsPerOctave := 12;
  FConfig.HarmonyMode := wmehmExact;
  for LRole := 0 to LRoleCount - 1 do
  begin
    FConfig.Voices[LRole].MinPitch := 127;
    FConfig.Voices[LRole].MaxPitch := 0;
  end;
  LTotalSoundWeight := 0;
  LCutoff := 0;
  LSustain := 0;
  for R := 0 to High(FRuns) do
  begin
    LRun := FRuns[R];
    LSourceIndex := LRun.SourceIndex;
    LInSample := False;
    LRunUsed := 0;
    LClock := TTempoMap.Create(PitchPatternPpq,
      Length(LRun.Grid.Frames) * PitchPatternStepTicks,
      [MakeTempoChange(0, LRun.Grid.TempoMicroseconds)]);
    try
      for C := 0 to High(LRun.Grid.Frames) do
      begin
        ReportWork(AProgress, 'musical_corpus_tokens', wuItems, C,
          Length(LRun.Grid.Frames), R);
        LStart := LClock.FrameAtTick(C * PitchPatternStepTicks, LRun.Grid.SampleRate, frCeiling);
        LEnd := LClock.FrameAtTick((C + 1) * PitchPatternStepTicks, LRun.Grid.SampleRate, frCeiling);
        if LRun.Grid.Known[C] then
        begin
          Inc(FCoverage[LSourceIndex].ProposedFrames, LEnd - LStart);
        end;
        if not LRun.Grid.Known[C] or
          ((Length(LRun.AdmittedCells) > 0) and not LRun.AdmittedCells[C]) then
        begin
          LInSample := False;
          Continue;
        end;
        LFrame := ImportWfcChordFrame(LRun.Grid.Frames[C]);
        if not LInSample then
        begin
          for P := 0 to LProviderCount - 1 do
          begin
            LSample := Length(LSamples[P]);
            SetLength(LSamples[P], LSample + 1);
            LSamples[P][LSample].Weight := FSources[LSourceIndex].TrainingWeight;
          end;
          for LRole := 0 to LRoleCount - 1 do
          begin
            if Length(LFrame.Voices[LRole].Tones) > 0 then
            begin
              LFrame.Voices[LRole].Action := wmcaAttack;
            end;
          end;
          Inc(FCoverage[LSourceIndex].Samples);
          Inc(FCoverage[LSourceIndex].WeightedSamples, FSources[LSourceIndex].TrainingWeight);
          SetLength(FContributions, Length(FContributions) + 1);
          LContribution := Default(TMusicalCorpusContribution);
          LContribution.SourceIndex := LSourceIndex;
          LContribution.RunIndex := R;
          LContribution.FirstCell := C;
          LContribution.StartFrame := LRun.StartFrame + LStart;
          LContribution.TrainingWeight := FSources[LSourceIndex].TrainingWeight;
          FContributions[High(FContributions)] := LContribution;
        end;
        LInSample := True;
        LSample := High(LSamples[0]);
        Inc(FContributions[LSample].CellCount);
        FContributions[LSample].EndFrame := LRun.StartFrame + LEnd;
        LToken := Length(LSamples[0][LSample].Tokens);
        for P := 0 to LProviderCount - 1 do
        begin
          SetLength(LSamples[P][LSample].Tokens, LToken + 1);
        end;
        LSamples[0][LSample].Tokens[LToken] :=
          EncodeWfcMusicPitchClassSet(ProjectWfcMusicEnsembleFrameToPitchClassSet(LFrame, 12));
        LSamples[1][LSample].Tokens[LToken] :=
          EncodeWfcMusicRhythmFrame(ProjectWfcMusicEnsembleFrameToRhythm(LFrame));
        LSingle := Default(TWfcMusicEnsembleFrame);
        SetLength(LSingle.Voices, 1);
        for LRole := 0 to LRoleCount - 1 do
        begin
          LSingle.Voices[0] := LFrame.Voices[LRole];
          LSamples[LRole + 2][LSample].Tokens[LToken] := EncodeWfcMusicEnsembleFrame(LSingle);
          for K := 0 to High(LFrame.Voices[LRole].Tones) do
          begin
            LPitch := LFrame.Voices[LRole].Tones[K].Pitch;
            FConfig.Voices[LRole].MinPitch := Min(FConfig.Voices[LRole].MinPitch, LPitch);
            FConfig.Voices[LRole].MaxPitch := Max(FConfig.Voices[LRole].MaxPitch, LPitch);
          end;
        end;
        LContext.Frame := LFrame;
        LContext.DrivenRole := ADrivenRole;
        LSamples[LContextIndex][LSample].Tokens[LToken] := EncodeMusicalContextToken(LContext);
        for J := 0 to 2 do
        begin
          LSamples[LContextIndex + 1 + J][LSample].Tokens[LToken] := PercussionToken(LRun.Grid.Drums[C][J]);
          if LRun.Grid.Drums[C][J] > 0 then
          begin
            AppendUnique(FAllowedDrumRhythms[J], LSamples[1][LSample].Tokens[LToken]);
          end;
        end;
        Inc(LRunUsed, LEnd - LStart);
        Inc(FCoverage[LSourceIndex].ModelCells);
        Inc(FCoverage[LSourceIndex].WeightedCells, FSources[LSourceIndex].TrainingWeight);
      end;
    finally
      LClock.Free;
    end;
    Inc(FCoverage[LSourceIndex].ModelUsedFrames, LRunUsed);
    if LRun.Grid.HasSound and (LRunUsed > 0) then
    begin
      LSecondsWeight := LRunUsed / LRun.Grid.SampleRate * FSources[LSourceIndex].TrainingWeight;
      LTotalSoundWeight := LTotalSoundWeight + LSecondsWeight;
      LCutoff := LCutoff + LRun.Grid.Sound.CutoffHz * LSecondsWeight;
      LSustain := LSustain + LRun.Grid.Sound.SustainPercent * LSecondsWeight;
    end;
  end;
  for I := 0 to High(FSources) do
  begin
    FCoverage[I].ExcludedFrames := FSources[I].FrameCount - FCoverage[I].IncludedFrames;
    FCoverage[I].UnmodeledFrames := FCoverage[I].ProcessedFrames - FCoverage[I].ModelUsedFrames;
    FCoverage[I].BudgetOmittedFrames := FCoverage[I].ProposedFrames - FCoverage[I].ModelUsedFrames;
  end;
  { Exactly the current selected evidence is rebuilt, never parent counts plus
    those same observations again. Multiplicity stays separate from leaf identity. }
  for I := 0 to High(FContributions) do
  begin
    ReportWork(AProgress, 'musical_corpus_contributions', wuItems, I, Length(FContributions));
    LContribution := FContributions[I];
    LRun := FRuns[LContribution.RunIndex];
    LFields := [FSources[LContribution.SourceIndex].Sha256,
      IntToStr(LRun.Grid.SampleRate), IntToStr(LContribution.StartFrame),
      IntToStr(LContribution.EndFrame), LRun.Grid.Policy,
      IntToStr(LRun.Grid.TempoMicroseconds), IntToStr(LProviderCount)];
    LProviderNames := CopyProviderNames;
    for P := 0 to LProviderCount - 1 do
    begin
      SetLength(LFields, Length(LFields) + 2);
      LFields[High(LFields) - 1] := LProviderNames[P];
      LFields[High(LFields)] := IntToStr(Length(LSamples[P][I].Tokens));
      for J := 0 to High(LSamples[P][I].Tokens) do
      begin
        SetLength(LFields, Length(LFields) + 1);
        LFields[High(LFields)] := LSamples[P][I].Tokens[J];
      end;
    end;
    FContributions[I].Identity := HashFields('pythian.musical.contribution.v1', LFields);
    for J := 0 to I - 1 do
    begin
      Need(FContributions[J].Identity <> FContributions[I].Identity,
        'Repeated musical source evidence cannot acquire duplicate ancestry');
    end;
  end;
  for P := 0 to LProviderCount - 1 do
  begin
    ReportWork(AProgress, 'musical_corpus_learn', wuItems, P, LProviderCount);
    FModels[P] := LearnWeightedSequenceModel(LSamples[P], AOrder, AMaximumObservations, AProgress);
  end;
  FConfig.HarmonyModel := FModels[0];
  FConfig.RhythmModel := FModels[1];
  for LRole := 0 to LRoleCount - 1 do
  begin
    FConfig.Voices[LRole].Model := FModels[LRole + 2];
    if FConfig.Voices[LRole].MinPitch > FConfig.Voices[LRole].MaxPitch then
    begin
      FConfig.Voices[LRole].MinPitch := 0;
      FConfig.Voices[LRole].MaxPitch := 127;
    end;
  end;
  FHasSound := LTotalSoundWeight > 0;
  if FHasSound then
  begin
    FSound.CutoffHz := Round(LCutoff / LTotalSoundWeight);
    FSound.SustainPercent := Round(LSustain / LTotalSoundWeight);
    ValidateMusicalSound(FSound);
  end;
  CaptureVocabularies(AProgress);
  ReportWork(AProgress, 'musical_corpus_learn', wuItems, LProviderCount, LProviderCount);
end;

destructor TMusicalCorpus.Destroy;
var
  I: Integer;
begin
  for I := 0 to High(FModels) do
  begin
    FModels[I].Free;
  end;
  inherited Destroy;
end;

function TMusicalCorpus.CopySources: TMusicalCorpusSources;
var
  I: Integer;
begin
  Result := Copy(FSources);
  for I := 0 to High(FSources) do
  begin
    Result[I].Classifications := Copy(FSources[I].Classifications);
  end;
end;

function TMusicalCorpus.CopySelections: TMusicalCorpusSelections;
var
  I: Integer;
begin
  Result := Copy(FSelections);
  for I := 0 to High(Result) do
  begin
    Result[I].Classifications := Copy(FSelections[I].Classifications);
  end;
end;

function TMusicalCorpus.CopyRuns: TMusicalCorpusRuns;
var
  I: Integer;
begin
  Result := nil;
  SetLength(Result, Length(FRuns));
  for I := 0 to High(FRuns) do
  begin
    Result[I] := FRuns[I];
    Result[I].Grid := CopyProposedMusicalGrid(FRuns[I].Grid);
    Result[I].AdmittedCells := Copy(FRuns[I].AdmittedCells);
  end;
end;

function TMusicalCorpus.CopyCoverage: TMusicalCorpusCoverages;
begin
  Result := Copy(FCoverage);
end;

function TMusicalCorpus.CopyRoleNames: TMusicalProposalNames;
begin
  Result := Copy(FRoleNames);
end;

function TMusicalCorpus.CopyProviderNames: TLayerModelTexts;
const
  CDrums: array[0..2] of String = ('kick', 'snare', 'hat');
var
  I: Integer;
begin
  Result := nil;
  SetLength(Result, Length(FRoleNames) + 6);
  Result[0] := 'harmony';
  Result[1] := 'rhythm';
  for I := 0 to High(FRoleNames) do
  begin
    Result[I + 2] := 'voice:' + FRoleNames[I];
  end;
  Result[Length(FRoleNames) + 2] := 'musical-context';
  for I := 0 to 2 do
  begin
    Result[Length(FRoleNames) + 3 + I] := 'percussion:' + CDrums[I];
  end;
end;

procedure TMusicalCorpus.CaptureVocabularies(const AProgress: TWorkProgressCallback);
var
  LNames: TLayerModelTexts;
  LRevision: TLayerModelTexts;
  LCodec: String;
  LSchema: String;
  I: Integer;
  J: Integer;
begin
  LNames := CopyProviderNames;
  SetLength(FVocabularies, Length(FModels));
  SetLength(LRevision, 1 + Length(FModels) * 2 + Length(FContributions) * 2);
  LRevision[0] := MusicalCorpusPolicy;
  for I := 0 to High(FModels) do
  begin
    if I = 0 then
    begin
      LCodec := 'wfc.music.pitch-class-set.v1';
    end
    else if I = 1 then
    begin
      LCodec := 'wfc.music.rhythm-frame.v1';
    end
    else if I < Length(FRoleNames) + 2 then
    begin
      LCodec := 'wfc.music.ensemble-frame.v1';
    end
    else if I = Length(FRoleNames) + 2 then
    begin
      LCodec := 'pythian.musical-context.v1';
    end
    else
    begin
      LCodec := 'pythian.percussion.velocity.v1';
    end;
    FVocabularies[I].Key := LNames[I];
    FVocabularies[I].Codec := LCodec;
    LSchema := '';
    if (I = 1) or (I = Length(FRoleNames) + 2) then
    begin
      LSchema := HashFields('pythian.musical.ordered-roles.v1', FRoleNames);
    end;
    FVocabularies[I].SchemaSha256 := LSchema;
    FVocabularies[I].ModelSha256 := Sha256Bytes(
      EncodeUTF8Text(EncodeWfcSequenceText(FModels[I]), 16 * 1024 * 1024));
    SetLength(FVocabularies[I].Tokens, FModels[I].PublicTokenCount);
    for J := 0 to FModels[I].PublicTokenCount - 1 do
    begin
      ReportWork(AProgress, 'musical_corpus_vocabulary', wuItems, J,
        FModels[I].PublicTokenCount, I);
      FVocabularies[I].Tokens[J].Value := FModels[I].PublicTokenAt(J);
      FVocabularies[I].Tokens[J].Identity := HashFields('pythian.musical.token.v1',
        [LNames[I], LCodec, LSchema, FModels[I].PublicTokenAt(J)]);
    end;
    LRevision[1 + I * 2] := LNames[I];
    LRevision[2 + I * 2] := FVocabularies[I].ModelSha256;
  end;
  for I := 0 to High(FContributions) do
  begin
    LRevision[1 + Length(FModels) * 2 + I * 2] := FContributions[I].Identity;
    LRevision[2 + Length(FModels) * 2 + I * 2] := IntToStr(FContributions[I].TrainingWeight);
  end;
  ReportWork(AProgress, 'musical_corpus_vocabulary_ready', wuItems, 0, 1);
  FRevisionIdentity := HashFields('pythian.musical.corpus-revision.v1', LRevision);
end;

function TMusicalCorpus.CopyVocabularies: TMusicalProviderVocabularies;
var
  I: Integer;
begin
  Result := Copy(FVocabularies);
  for I := 0 to High(Result) do
  begin
    Result[I].Tokens := Copy(FVocabularies[I].Tokens);
  end;
end;

function TMusicalCorpus.CopyContributions: TMusicalCorpusContributions;
begin
  Result := Copy(FContributions);
end;

function TMusicalCorpus.ResolveToken(const AProviderKey, ATokenIdentity: String): Integer;
var
  I: Integer;
  J: Integer;
begin
  for I := 0 to High(FVocabularies) do
  begin
    if FVocabularies[I].Key <> AProviderKey then
    begin
      Continue;
    end;
    for J := 0 to High(FVocabularies[I].Tokens) do
    begin
      if FVocabularies[I].Tokens[J].Identity = ATokenIdentity then
      begin
        Exit(J);
      end;
    end;
    Exit(-1);
  end;
  Result := -1;
end;

function TMusicalCorpus.CopyModelTexts(const AProgress: TWorkProgressCallback): TLayerModelTexts;
var
  I: Integer;
  LResult: TLayerModelTexts;
begin
  LResult := nil;
  SetLength(LResult, Length(FModels));
  for I := 0 to High(FModels) do
  begin
    ReportWork(AProgress, 'musical_corpus_encode', wuItems, I, Length(FModels));
    LResult[I] := EncodeWfcSequenceText(FModels[I]);
  end;
  ReportWork(AProgress, 'musical_corpus_encode', wuItems, Length(FModels), Length(FModels));
  Result := LResult;
end;

function TMusicalCorpus.Config: TWfcMusicVoicesGraphConfig;
begin
  Result := FConfig;
  Result.Voices := Copy(FConfig.Voices);
  Result.PairConstraints := Copy(FConfig.PairConstraints);
end;

function TMusicalCorpus.ContextModel: TWfcSequenceModel;
begin
  Result := FModels[Length(FConfig.Voices) + 2];
end;

function TMusicalCorpus.CopyPercussion(const ASampleRate: Integer): TPercussionDefinitions;
const
  CNames: array[0..2] of String = ('kick', 'snare', 'hat');
var
  I: Integer;
begin
  Result := nil;
  SetLength(Result, 3);
  for I := 0 to 2 do
  begin
    Result[I].Name := CNames[I];
    Result[I].Origin := 'Experimental spectral-band change proposal; ' + MusicalCorpusPolicy;
    Result[I].Model := FModels[Length(FConfig.Voices) + 3 + I];
    Result[I].Settings := DefaultPercussionSettings(TPercussionKind(I), ASampleRate);
    Result[I].OutputBus := 0;
    Result[I].Enabled := True;
    Result[I].HitWeight := 1;
    Result[I].AllowedHitRhythms := Copy(FAllowedDrumRhythms[I]);
  end;
end;

function TMusicalCorpus.ProposedSound(out ASound: TMusicalSound): Boolean;
begin
  ASound := FSound;
  Result := FHasSound;
end;

end.
