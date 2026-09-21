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
unit pythian.wfc.provider.contracts;

{$mode delphi}
{$H+}

interface

uses
  pythian.time,
  pythian.wfc.layers,
  pythian.wfc.providers,
  wfc,
  wfc_sequence;

type
  TProviderPitchBasis = (ppbNone, ppbAbsoluteMidi, ppbRelativeKey);
  { Optional original measurement binding. Empty SourceSha256 means no measured
    source is claimed. Otherwise each retained original tick/frame boundary must
    agree with the exact source clock and explicit rational PPQ conversion. }
  TProviderSourceEvidence = record
    SourceSha256: String;
    MeasurementIdentity: String;
    ConversionIdentity: String;
    SampleRate: Integer;
    SourceFrames: Integer;
    FrameOffset: Integer;
    SourceTicksPerQuarter: Integer;
    SourceLengthTicks: Integer;
    SourceStartTick: Integer;
    TempoChanges: TTempoChanges;
    OriginalTicks: TLayerTickBoundaries;
    OriginalFrames: TLayerTickBoundaries;
  end;
  TProviderContract = record
    Name: String;
    Vocabulary: TStyleProviderVocabulary;
    RoleId: String;
    RoleOrder: TLayerNames;
    PitchBasis: TProviderPitchBasis;
    KeyReference: String;
    PaletteIdentity: String;
    MusicalDomain: String;
    TicksPerQuarter: Integer;
    Scope: TLayerScope;
    TimeGrid: TLayerTimeGrid;
    { Exact codec meaning, including unknown/rest distinctions. }
    UnknownPolicy: String;
    Source: TProviderSourceEvidence;
  end;
  TProviderContracts = array of TProviderContract;

  { Semantic admission around the existing uniform/partitioned layer session.
    Projections are explicit required inputs; they keep the actual WFC mapping,
    coverage, dependency and replacement semantics. No model is relearned. }
  TCompatibleProviderSession = class
  private
    FSession: TLearnedLayerSession;
    FContracts: TProviderContracts;
    FInputs: array of TStyleProviderDependencies;
    function IndexOf(const AName: String): Integer;
  public
    constructor Create(const ALayers: TLearnedLayers;
      const AProjections: TLayerProjections; const AContracts: TProviderContracts;
      const AOptions: TLayerGenerationOptions);
    destructor Destroy; override;
    function CopyContract(const AName: String): TProviderContract;
    function CopyInputs(const AName: String): TStyleProviderDependencies;
    procedure SetConstraints(const AName: String;
      const AMask: TWfcSequenceTokenConstraints);
    function CopyAccepted: TLayerSequences;
    function TryGenerate(var ASequences: TLayerSequences;
      out AReport: TGraphNegotiationReport): Boolean;
    function TryRegenerate(const ARoots: array of String; const ASeed: TGraphSeed;
      var ASequences: TLayerSequences; out AReport: TGraphSelectiveNegotiationReport): Boolean;
    function TryReplaceProvider(const AName: String; const AModel: TWfcSequenceModel;
      const AContract: TProviderContract; const ASeed: TGraphSeed;
      var ASequences: TLayerSequences; out AReport: TLayerModelReplacementReport): Boolean;
  end;

function ProviderUnknownPolicy(const AVocabulary: TStyleProviderVocabulary): String;
function CopyProviderContract(const AContract: TProviderContract): TProviderContract;
function ProviderContractFromDescription(const ADescription: TStyleProviderDescription;
  const AMusicalDomain: String): TProviderContract;
procedure ValidateProviderContract(const AModel: TWfcSequenceModel;
  const AContract: TProviderContract);
procedure RequireCompatibleProvider(const AExpected, ACandidate: TProviderContract);

implementation

uses
  SysUtils,
  pythian.audio,
  pythian.music.grid.frames,
  pythian.wfc.music,
  wfc_music_ensemble_graph;

function ProviderUnknownPolicy(const AVocabulary: TStyleProviderVocabulary): String;
begin
  case AVocabulary of
    spvKey: Result := 'canonical-unknown-key';
    spvOnsets: Result := 'empty-is-not-silence';
    spvIntensity: Result := 'zero-is-no-onset';
    spvPerformance: Result := 'unknown-rest-pitch-distinct';
    spvVoice: Result := 'rest-attack-hold-no-unknown';
    spvRhythm: Result := 'joint-rest-attack-hold-no-unknown';
    spvHarmony: Result := 'empty-pitch-set-no-unknown';
    spvTempo, spvPitch, spvPitchRhythm: Result := 'no-unknown-token';
  else
    raise EAudio.Create('Unsupported provider vocabulary');
  end;
end;

function CopyProviderContract(const AContract: TProviderContract): TProviderContract;
begin
  Result := AContract;
  Result.RoleOrder := Copy(AContract.RoleOrder);
  Result.TimeGrid.Boundaries := Copy(AContract.TimeGrid.Boundaries);
  Result.Source.TempoChanges := Copy(AContract.Source.TempoChanges);
  Result.Source.OriginalTicks := Copy(AContract.Source.OriginalTicks);
  Result.Source.OriginalFrames := Copy(AContract.Source.OriginalFrames);
end;

function ProviderContractFromDescription(const ADescription: TStyleProviderDescription;
  const AMusicalDomain: String): TProviderContract;
begin
  if ADescription.Timing <> sptUniform then
  begin
    raise EAudio.Create('Provider contract needs an explicit uniform or fixed-partition grid');
  end;
  Result := Default(TProviderContract);
  Result.Name := ADescription.Name;
  Result.Vocabulary := ADescription.Vocabulary;
  Result.RoleId := ADescription.RoleId;
  Result.RoleOrder := Copy(ADescription.RoleOrder);
  if ADescription.Vocabulary in [spvPitch, spvPitchRhythm, spvPerformance, spvVoice] then
  begin
    Result.PitchBasis := ppbAbsoluteMidi;
  end;
  Result.MusicalDomain := AMusicalDomain;
  Result.TicksPerQuarter := ADescription.TicksPerQuarter;
  Result.Scope := ADescription.Scope;
  Result.TimeGrid := MakeLayerTimeGrid(0, ADescription.StepTicks);
  Result.UnknownPolicy := ProviderUnknownPolicy(Result.Vocabulary);
end;

function Boundaries(const AContract: TProviderContract): TLayerTickBoundaries;
var
  LIndex: Integer;
  LTick: Int64;
  LGrid: TLayerTimeGrid;
begin
  if (AContract.Scope.CellCount < 1) or (AContract.Scope.CellCount > MaximumLayerCells) then
  begin
    raise EAudio.Create('Provider scope requires 1..1024 cells');
  end;
  if Length(AContract.TimeGrid.Boundaries) <> 0 then
  begin
    if (Length(AContract.TimeGrid.Boundaries) <> AContract.Scope.CellCount + 1) or
      (AContract.TimeGrid.OriginTick <> 0) or (AContract.TimeGrid.TicksPerCell <> 0) then
    begin
      raise EAudio.Create('Provider partition must match its scope without mixed uniform fields');
    end;
    LGrid := MakeLayerTimePartition(AContract.TimeGrid.Boundaries);
    Exit(LGrid.Boundaries);
  end;
  LGrid := MakeLayerTimeGrid(AContract.TimeGrid.OriginTick, AContract.TimeGrid.TicksPerCell);
  Result := nil;
  SetLength(Result, AContract.Scope.CellCount + 1);
  for LIndex := 0 to High(Result) do
  begin
    LTick := Int64(LGrid.OriginTick) + Int64(LIndex) * LGrid.TicksPerCell;
    if (LTick < Low(Integer)) or (LTick > High(Integer)) then
    begin
      raise EAudio.Create('Provider time boundary exceeds Integer');
    end;
    Result[LIndex] := LTick;
  end;
end;

procedure ValidateSource(const AContract: TProviderContract;
  const ATicks: TLayerTickBoundaries);
var
  LSource: TProviderSourceEvidence;
  LClock: TTempoMap;
  LGrid: TMusicGridFrames;
  LIndex: Integer;
  LScaled: Int64;
  LTick: Int64;
begin
  LSource := AContract.Source;
  if LSource.SourceSha256 = '' then
  begin
    if (LSource.MeasurementIdentity <> '') or (LSource.ConversionIdentity <> '') or
      (LSource.SampleRate <> 0) or (LSource.SourceFrames <> 0) or (LSource.FrameOffset <> 0) or
      (LSource.SourceTicksPerQuarter <> 0) or (LSource.SourceLengthTicks <> 0) or
      (LSource.SourceStartTick <> 0) or (Length(LSource.TempoChanges) <> 0) or
      (Length(LSource.OriginalTicks) <> 0) or (Length(LSource.OriginalFrames) <> 0) then
    begin
      raise EAudio.Create('Unbound provider source must not carry hidden measurement fields');
    end;
    Exit;
  end;
  if (Length(LSource.SourceSha256) <> 64) or (LSource.MeasurementIdentity = '') or
    (LSource.SourceTicksPerQuarter < 1) or (LSource.SourceStartTick < 0) or
    (Length(LSource.OriginalTicks) <> Length(ATicks)) or
    (Length(LSource.OriginalFrames) <> Length(ATicks)) or
    (Int64(Length(LSource.TempoChanges)) * Length(ATicks) > MaximumLayerProjectionWork) then
  begin
    raise EAudio.Create('Measured provider needs exact source, clock and original boundary evidence');
  end;
  for LIndex := 1 to 64 do
  begin
    if not (LSource.SourceSha256[LIndex] in ['0'..'9', 'a'..'f']) then
    begin
      raise EAudio.Create('Provider source SHA256 must be lowercase hexadecimal');
    end;
  end;
  if ((LSource.SourceTicksPerQuarter <> AContract.TicksPerQuarter) or
    (LSource.SourceStartTick <> ATicks[0])) and (LSource.ConversionIdentity = '') then
  begin
    raise EAudio.Create('Provider PPQ/origin conversion requires an explicit retained identity');
  end;
  LClock := TTempoMap.Create(LSource.SourceTicksPerQuarter, LSource.SourceLengthTicks,
    LSource.TempoChanges);
  try
    for LIndex := 0 to High(ATicks) do
    begin
      LScaled := (Int64(ATicks[LIndex]) - ATicks[0]) * LSource.SourceTicksPerQuarter;
      if LScaled mod AContract.TicksPerQuarter <> 0 then
      begin
        raise EAudio.Create('Provider PPQ conversion loses an original tick boundary');
      end;
      LTick := LSource.SourceStartTick + LScaled div AContract.TicksPerQuarter;
      if (LTick > High(Integer)) or (LSource.OriginalTicks[LIndex] <> LTick) then
      begin
        raise EAudio.Create('Provider original ticks disagree with the declared exact conversion');
      end;
      if LIndex > 0 then
      begin
        LGrid := TMusicGridFrames.Create(LClock, LSource.SampleRate, LSource.SourceFrames,
          LSource.FrameOffset, LSource.OriginalTicks[LIndex - 1],
          LSource.OriginalTicks[LIndex] - LSource.OriginalTicks[LIndex - 1], 1);
        try
          if (LGrid.BoundaryAt(0) <> LSource.OriginalFrames[LIndex - 1]) or
            (LGrid.BoundaryAt(1) <> LSource.OriginalFrames[LIndex]) then
          begin
            raise EAudio.Create('Provider original frames disagree with the source clock');
          end;
        finally
          LGrid.Free;
        end;
      end;
    end;
  finally
    LClock.Free;
  end;
end;

procedure ValidateProviderContract(const AModel: TWfcSequenceModel;
  const AContract: TProviderContract);
var
  LTicks: TLayerTickBoundaries;
  LChoices: TStyleProviderChoices;
  LIndex: Integer;
  LOther: Integer;
begin
  if (AModel = nil) or (AContract.Name = '') or (Length(AContract.Name) > 128) or
    (AContract.MusicalDomain = '') or (AContract.TicksPerQuarter < 1) or
    (Ord(AContract.PitchBasis) < Ord(Low(TProviderPitchBasis))) or
    (Ord(AContract.PitchBasis) > Ord(High(TProviderPitchBasis))) or
    (Ord(AContract.Scope.Extent) < Ord(Low(TWfcSequenceExtent))) or
    (Ord(AContract.Scope.Extent) > Ord(High(TWfcSequenceExtent))) then
  begin
    raise EAudio.Create('Provider requires a model, named output, musical domain and finite PPQ scope');
  end;
  if AContract.UnknownPolicy <> ProviderUnknownPolicy(AContract.Vocabulary) then
  begin
    raise EAudio.Create('Provider unknown/rest semantics differ from the canonical codec');
  end;
  if (AContract.PitchBasis = ppbRelativeKey) or (AContract.KeyReference <> '') then
  begin
    raise EAudio.Create('Relative/key-referenced pitch providers require an explicit supported conversion');
  end;
  if (AContract.Vocabulary in [spvPitch, spvPitchRhythm, spvPerformance, spvVoice]) <>
    (AContract.PitchBasis = ppbAbsoluteMidi) then
  begin
    raise EAudio.Create('Provider pitch basis disagrees with its canonical vocabulary');
  end;
  if ((AContract.Vocabulary = spvVoice) and (AContract.RoleId = '')) or
    ((AContract.Vocabulary <> spvVoice) and (AContract.RoleId <> '')) then
  begin
    raise EAudio.Create('Only independent voice outputs require a declared role identity');
  end;
  if ((AContract.Vocabulary = spvRhythm) and
    ((Length(AContract.RoleOrder) < 1) or (Length(AContract.RoleOrder) > 6))) or
    ((AContract.Vocabulary <> spvRhythm) and (Length(AContract.RoleOrder) <> 0)) then
  begin
    raise EAudio.Create('Joint rhythm requires 1..6 ordered role identities; other vocabularies have no role vector');
  end;
  for LIndex := 0 to High(AContract.RoleOrder) do
  begin
    if (Length(AContract.RoleOrder[LIndex]) < 1) or (Length(AContract.RoleOrder[LIndex]) > 128) then
    begin
      raise EAudio.Create('Joint rhythm role identity must contain 1..128 characters');
    end;
    for LOther := 0 to LIndex - 1 do
    begin
      if AContract.RoleOrder[LOther] = AContract.RoleOrder[LIndex] then
      begin
        raise EAudio.Create('Joint rhythm role identities must be unique');
      end;
    end;
  end;
  { These are semantic codecs, not acoustic palette indices. }
  if AContract.PaletteIdentity <> '' then
  begin
    raise EAudio.Create('Acoustic palette providers are unsupported by these semantic codecs');
  end;
  if AModel.PublicTokenCount > 4096 then
  begin
    raise EAudio.Create('Provider vocabulary exceeds 4096 choices');
  end;
  if (AModel.StateCount > MaximumLayerStateCells) or (AModel.Order > 64) then
  begin
    raise EAudio.Create('Provider model exceeds the state/order preparation bound');
  end;
  if (Int64(AModel.StateCount) * AContract.Scope.CellCount > MaximumLayerStateCells) or
    (Int64(AModel.StateCount) * AModel.StateCount * (AModel.Order + 1) >
      MaximumLayerProjectionWork) then
  begin
    raise EAudio.Create('Provider model exceeds the state/cell or preparation budget');
  end;
  LTicks := Boundaries(AContract);
  ValidateSource(AContract, LTicks);
  LChoices := CopyStyleProviderChoices(AModel, AContract.Vocabulary);
  if AContract.Vocabulary = spvVoice then
  begin
    WfcIndependentVoiceCapacities([AModel]);
    ValidateWfcMusicEnsembleModel(AModel, 1);
  end;
  for LIndex := 0 to High(LChoices) do
  begin
    if (AContract.Vocabulary = spvHarmony) and
      (LChoices[LIndex].Harmony.StepsPerOctave <> 12) then
    begin
      raise EAudio.Create('Semantic harmony contract requires 12-TET pitch classes');
    end;
    if (AContract.Vocabulary = spvRhythm) and
      (Length(LChoices[LIndex].Rhythm.Actions) <> Length(AContract.RoleOrder)) then
    begin
      raise EAudio.Create('Joint rhythm action vector does not match its declared ordered roles');
    end;
  end;
end;

procedure RequireCompatibleProvider(const AExpected, ACandidate: TProviderContract);
var
  LExpected: TLayerTickBoundaries;
  LCandidate: TLayerTickBoundaries;
  LIndex: Integer;
begin
  if (AExpected.Name <> ACandidate.Name) or (AExpected.RoleId <> ACandidate.RoleId) then
  begin
    raise EAudio.Create('Provider substitution changes its output or declared role identity');
  end;
  if Length(AExpected.RoleOrder) <> Length(ACandidate.RoleOrder) then
  begin
    raise EAudio.Create('Provider substitution changes its joint role-vector length');
  end;
  for LIndex := 0 to High(AExpected.RoleOrder) do
  begin
    if AExpected.RoleOrder[LIndex] <> ACandidate.RoleOrder[LIndex] then
    begin
      raise EAudio.Create('Provider substitution permutes a joint role identity');
    end;
  end;
  if (AExpected.Vocabulary <> ACandidate.Vocabulary) or
    (AExpected.PitchBasis <> ACandidate.PitchBasis) or
    (AExpected.KeyReference <> ACandidate.KeyReference) or
    (AExpected.PaletteIdentity <> ACandidate.PaletteIdentity) or
    (AExpected.UnknownPolicy <> ACandidate.UnknownPolicy) then
  begin
    raise EAudio.Create('Provider vocabulary, pitch reference, palette or unknown semantics differ');
  end;
  if (AExpected.TicksPerQuarter <> ACandidate.TicksPerQuarter) or
    (AExpected.MusicalDomain <> ACandidate.MusicalDomain) or
    (AExpected.Scope.CellCount <> ACandidate.Scope.CellCount) or
    (AExpected.Scope.Extent <> ACandidate.Scope.Extent) then
  begin
    raise EAudio.Create('Provider PPQ, musical clock domain or scope differs');
  end;
  LExpected := Boundaries(AExpected);
  LCandidate := Boundaries(ACandidate);
  for LIndex := 0 to High(LExpected) do
  begin
    if LExpected[LIndex] <> LCandidate[LIndex] then
    begin
      raise EAudio.Create('Provider replacement changes an effective musical-time boundary');
    end;
  end;
end;

constructor TCompatibleProviderSession.Create(const ALayers: TLearnedLayers;
  const AProjections: TLayerProjections; const AContracts: TProviderContracts;
  const AOptions: TLayerGenerationOptions);
var
  LOptions: TLayerGenerationOptions;
  LNames: TLayerNames;
  LIndex: Integer;
  LInput: Integer;
  LProjection: TLayerProjection;
  LRole: Integer;
  LRoleIndex: Integer;
  LRule: Integer;
  LToken: Integer;
  LVoiceChoice: TStyleProviderChoice;
  LRhythmChoice: TStyleProviderChoice;
begin
  inherited Create;
  if (Length(AContracts) <> Length(ALayers)) or (Length(ALayers) < 1) or
    (Length(ALayers) > MaximumLearnedLayers) then
  begin
    raise EAudio.Create('Provider composition requires one contract per bounded musical layer');
  end;
  if (Length(AOptions.Scopes) <> 0) or (Length(AOptions.TimeGrids) <> 0) then
  begin
    raise EAudio.Create('Provider contracts own the scopes and grids; duplicate option layouts are unsupported');
  end;
  LOptions := AOptions;
  LOptions.Scopes := nil;
  LOptions.TimeGrids := nil;
  SetLength(LOptions.Scopes, Length(ALayers));
  SetLength(LOptions.TimeGrids, Length(ALayers));
  SetLength(FContracts, Length(ALayers));
  SetLength(LNames, Length(ALayers));
  for LIndex := 0 to High(ALayers) do
  begin
    ValidateProviderContract(ALayers[LIndex].Model, AContracts[LIndex]);
    if (AContracts[LIndex].TicksPerQuarter <> AContracts[0].TicksPerQuarter) or
      (AContracts[LIndex].MusicalDomain <> AContracts[0].MusicalDomain) then
    begin
      raise EAudio.Create('Composed providers must share an explicit PPQ and musical clock domain');
    end;
    FContracts[LIndex] := CopyProviderContract(AContracts[LIndex]);
    LNames[LIndex] := AContracts[LIndex].Name;
    LOptions.Scopes[LIndex] := FContracts[LIndex].Scope;
    LOptions.TimeGrids[LIndex] := FContracts[LIndex].TimeGrid;
  end;
  FSession := TLearnedLayerSession.Create(ALayers, AProjections, LNames, LOptions);
  SetLength(FInputs, Length(ALayers));
  for LProjection in AProjections do
  begin
    if (FContracts[LProjection.Provider].Vocabulary = spvRhythm) and
      (FContracts[LProjection.Consumer].Vocabulary = spvVoice) then
    begin
      LRoleIndex := -1;
      for LRole := 0 to High(FContracts[LProjection.Provider].RoleOrder) do
      begin
        if FContracts[LProjection.Provider].RoleOrder[LRole] =
          FContracts[LProjection.Consumer].RoleId then
        begin
          LRoleIndex := LRole;
        end;
      end;
      if LRoleIndex < 0 then
      begin
        raise EAudio.Create('Voice input role is absent from the joint rhythm contract');
      end;
      for LRule := 0 to High(LProjection.Rules) do
      begin
        LVoiceChoice := DecodeStyleProviderChoice(spvVoice, LProjection.Rules[LRule].TargetToken);
        for LToken := 0 to High(LProjection.Rules[LRule].SourceTokens) do
        begin
          LRhythmChoice := DecodeStyleProviderChoice(spvRhythm,
            LProjection.Rules[LRule].SourceTokens[LToken]);
          if LVoiceChoice.Voice.Action <> LRhythmChoice.Rhythm.Actions[LRoleIndex] then
          begin
            raise EAudio.Create('Voice projection uses a different joint rhythm role slot');
          end;
        end;
      end;
    end;
    LInput := Length(FInputs[LProjection.Consumer]);
    SetLength(FInputs[LProjection.Consumer], LInput + 1);
    FInputs[LProjection.Consumer][LInput].Name := FContracts[LProjection.Provider].Name;
    FInputs[LProjection.Consumer][LInput].TimeMapping := LProjection.TimeMapping;
  end;
end;

destructor TCompatibleProviderSession.Destroy;
begin
  FSession.Free;
  inherited Destroy;
end;

function TCompatibleProviderSession.IndexOf(const AName: String): Integer;
begin
  for Result := 0 to High(FContracts) do
  begin
    if FContracts[Result].Name = AName then
    begin
      Exit;
    end;
  end;
  raise EAudio.Create('Unknown compatible provider: ' + AName);
end;

function TCompatibleProviderSession.CopyContract(const AName: String): TProviderContract;
begin
  Result := CopyProviderContract(FContracts[IndexOf(AName)]);
end;

function TCompatibleProviderSession.CopyInputs(const AName: String): TStyleProviderDependencies;
begin
  Result := Copy(FInputs[IndexOf(AName)]);
end;

procedure TCompatibleProviderSession.SetConstraints(const AName: String;
  const AMask: TWfcSequenceTokenConstraints);
begin
  FSession.SetConstraints(AName, AMask);
end;

function TCompatibleProviderSession.CopyAccepted: TLayerSequences;
begin
  Result := FSession.CopyAccepted;
end;

function TCompatibleProviderSession.TryGenerate(var ASequences: TLayerSequences;
  out AReport: TGraphNegotiationReport): Boolean;
begin
  Result := FSession.TryGenerate(ASequences, AReport);
end;

function TCompatibleProviderSession.TryRegenerate(const ARoots: array of String;
  const ASeed: TGraphSeed; var ASequences: TLayerSequences;
  out AReport: TGraphSelectiveNegotiationReport): Boolean;
begin
  Result := FSession.TryRegenerate(ARoots, ASeed, ASequences, AReport);
end;

function TCompatibleProviderSession.TryReplaceProvider(const AName: String;
  const AModel: TWfcSequenceModel; const AContract: TProviderContract;
  const ASeed: TGraphSeed; var ASequences: TLayerSequences;
  out AReport: TLayerModelReplacementReport): Boolean;
var
  LIndex: Integer;
  LContract: TProviderContract;
begin
  AReport := Default(TLayerModelReplacementReport);
  AReport.ReplacedLayerIndex := -1;
  LIndex := IndexOf(AName);
  ValidateProviderContract(AModel, AContract);
  RequireCompatibleProvider(FContracts[LIndex], AContract);
  LContract := CopyProviderContract(AContract);
  Result := FSession.TryReplaceModel(AName, AModel, ASeed, ASequences, AReport);
  if Result then
  begin
    FContracts[LIndex] := LContract;
  end;
end;

end.
