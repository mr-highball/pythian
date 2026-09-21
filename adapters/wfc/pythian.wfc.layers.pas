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
unit pythian.wfc.layers;

{$mode delphi}
{$H+}

interface

uses
  wfc,
  wfc_sequence,
  wfc_sequence_graph;

const
  LearnedLayersVersion = 4;
  MaximumLearnedLayers = 8;
  MaximumLayerCells = 1024;
  MaximumLayerStateCells = 262144;
  MaximumLayerProjectionWork = 16777216;
  MaximumLayerMappingPreparationWork = 16777216;
  MaximumLayerPositionValues = 1024;
  MaximumLayerPositionMatrixBytes = 16777216;
  MaximumLayerPositionPreparationWork = 16777216;
  MaximumLayerPositionRequirements = 65536;
  MaximumLayerPositionProjectionWork = 1048576;
  MaximumLayerPreferences = 1024;
  MaximumLayerPreferenceMultiplier = 1024;
  MaximumLayerPreferencePreparationWork = 16777216;

type
  TLayerTokenPreference = record
    Token: String;
    Multiplier: Integer;
  end;
  TLayerTokenPreferences = array of TLayerTokenPreference;
  TLearnedLayer = record
    Model: TWfcSequenceModel;
    Constraints: TWfcSequenceTokenConstraints;
    { Positive relative choice multipliers; omitted tokens retain multiplier 1. }
    Preferences: TLayerTokenPreferences;
  end;
  TLearnedLayers = array of TLearnedLayer;
  TLayerTimeMapping = (ltmCellIndex, ltmStartTick, ltmWholeCell);
  TLayerProjection = record
    Consumer: Integer;
    Provider: Integer;
    Rules: TWfcSequenceProjectionRules;
    TimeMapping: TLayerTimeMapping;
  end;
  TLayerProjections = array of TLayerProjection;
  TLayerSequences = array of TWfcGeneratedSequence;
  TLayerScope = record
    CellCount: Integer;
    Extent: TWfcSequenceExtent;
  end;
  TLayerScopes = array of TLayerScope;
  TLayerTickBoundaries = array of Integer;
  TLayerTimeGrid = record
    OriginTick: Integer;
    TicksPerCell: Integer;
    { Empty uses the uniform grid; otherwise count+1 strictly increasing ticks.
      Explicit partitions require zero OriginTick/TicksPerCell. }
    Boundaries: TLayerTickBoundaries;
  end;
  TLayerTimeGrids = array of TLayerTimeGrid;
  TLayerGenerationOptions = record
    CellCount: Integer;
    Seed: TGraphSeed;
    Extent: TWfcSequenceExtent;
    MaxBacktracks: Integer;
    MaxPassBacktracks: Integer;
    { Empty uses the shared CellCount/Extent; otherwise one scope per layer. }
    Scopes: TLayerScopes;
    { Optional common tick domain, one uniform grid or contiguous partition per layer. }
    TimeGrids: TLayerTimeGrids;
  end;
  TLayerNames = array of String;
  TLayerDomains = array of TGraphValues;
  TLayerDomainFlags = array of Boolean;
  TLayerModelReplacementReport = record
    ReplacedLayerIndex: Integer;
    RootLayerIndices: TGraphPassIndices;
    AffectedLayerIndices: TGraphPassIndices;
    PreservedLayerIndices: TGraphPassIndices;
    { Full candidate solve with fixed independent domains, not selective reuse. }
    Search: TGraphNegotiationReport;
  end;

  { Owns detached models, relations and accepted results. Names identify layers
    for this session; schema/time compatibility remains the caller's contract.
    Constraints replace a layer's complete mask. A failed solve retains accepted
    results and pending edits. Actual WFC closes the dependency scope and retains
    inactive passes, including latent state identities. Not a stream checkpoint. }
  TLearnedLayerSession = class
  private
    FGraph: TGraph;
    FLayers: TLearnedLayers;
    FProjections: TLayerProjections;
    FNames: TLayerNames;
    FOptions: TLayerGenerationOptions;
    FBaseline: array of TLayerDomains;
    FHasBaseline: array of TLayerDomainFlags;
    FDirty: array of Boolean;
    FAccepted: TLayerSequences;
    function LayerIndex(const AName: String): Integer;
    function RegenerationRoots(const ARoots: array of String): TGraphPassLabels;
    procedure AcceptSolved;
  public
    constructor Create(const ALayers: TLearnedLayers;
      const AProjections: TLayerProjections; const ANames: TLayerNames;
      const AOptions: TLayerGenerationOptions);
    destructor Destroy; override;
    procedure SetConstraints(const AName: String;
      const AConstraints: TWfcSequenceTokenConstraints);
    { Replaces the complete preference list, retaining accepted output until solve.
      Detached ownership; nil restores learned choice weights. Not a hard mask. }
    procedure SetPreferences(const AName: String;
      const APreferences: TLayerTokenPreferences);
    function CopyPreferences(const AName: String): TLayerTokenPreferences;
    function TryGenerate(var ASequences: TLayerSequences;
      out AReport: TGraphNegotiationReport): Boolean;
    function TryRegenerate(const ARoots: array of String; const ASeed: TGraphSeed;
      var ASequences: TLayerSequences;
      out AReport: TGraphSelectiveNegotiationReport): Boolean;
    { Replace one model after initial acceptance, keeping scopes, relations and
      masks. Clones AModel; never takes its ownership. Includes pending edits.
      False/exception preserves the entire session and caller output. Independent
      tokens/states survive; candidate solve uses fresh seeded random streams. }
    function TryReplaceModel(const AName: String; const AModel: TWfcSequenceModel;
      const ASeed: TGraphSeed; var ASequences: TLayerSequences;
      out AReport: TLayerModelReplacementReport): Boolean;
    function CopyAccepted: TLayerSequences;
  end;

function DefaultLayerGenerationOptions: TLayerGenerationOptions;
function MakeLayerTokenPreference(const AToken: String;
  const AMultiplier: Integer): TLayerTokenPreference;
function MakeLayerScope(const ACellCount: Integer;
  const AExtent: TWfcSequenceExtent): TLayerScope;
function MakeLayerTimeGrid(const AOriginTick, ATicksPerCell: Integer): TLayerTimeGrid;
function MakeLayerTimePartition(const ABoundaries: array of Integer): TLayerTimeGrid;
function ResolveLayerScope(const AOptions: TLayerGenerationOptions;
  const ALayerIndex: Integer): TLayerScope;

{ Models are borrowed and immutable for the duration of this synchronous call.
  Layers are in dependency order: each provider must precede its consumer.
  Uses actual WFC overlay passes and negotiated solving, without a second learner.
  Relations cover every consumer token, with distinct providers conjunctive.
  Success publishes detached tokens and latent states; False or any exception
  preserves ASequences. AReport distinguishes contradiction from either budget. }
function TryGenerateLayers(const ALayers: TLearnedLayers;
  const AProjections: TLayerProjections; const AOptions: TLayerGenerationOptions;
  var ASequences: TLayerSequences; out AReport: TGraphNegotiationReport): Boolean;

implementation

uses
  SysUtils,
  pythian.audio,
  wfc_sequence_text,
  wfc_lattice;

type
  TLayerCellIndices = array of Integer;
  TPositionedLayer = class
  private
    FModel: TWfcSequenceModel;
    FCount: Integer;
    FExtent: TWfcSequenceExtent;
    FDomains: array of TGraphValues;
    FValues: array of TGraphValues;
  public
    constructor Create(const AModel: TWfcSequenceModel; const ACount: Integer;
      const AExtent: TWfcSequenceExtent);
    procedure Apply(const APass: TGraph);
    procedure SetMasks(const APass: TGraph; const AMasks: TWfcSequenceTokenConstraints);
    function ValueAt(const APosition, AState: Integer): TGraphValue;
    function Capture(const APass: TGraph): TWfcGeneratedSequence;
  end;
  { Private graph/compiler lifetime is shorter than its borrowed model lifetime.
    Public sessions own detached models and partitions. No caller graph escapes. }
  TPositionedLayerGraph = class(TGraph)
  public
    Compilers: array of TPositionedLayer;
    destructor Destroy; override;
  end;
  TLayerWeightChange = record
    Group: TGraphRuleGroup;
    Original: TGraphWeight;
    Preferred: TGraphWeight;
  end;
  { Borrowed graph; all keys are resolved before applying any weight change.
    Destruction restores model identity before capture or later domain edits. }
  TLayerPreferenceScope = class
  private
    FChanges: array of TLayerWeightChange;
    FApplied: Boolean;
  public
    constructor Create(const ALayers: TLearnedLayers; const AGraph: TGraph;
      const AOptions: TLayerGenerationOptions);
    destructor Destroy; override;
  end;

function MakeLayerTokenPreference(const AToken: String;
  const AMultiplier: Integer): TLayerTokenPreference;
begin
  if (AMultiplier < 1) or (AMultiplier > MaximumLayerPreferenceMultiplier) then
  begin
    raise EAudio.Create('Layer preference multiplier must be in 1..1024');
  end;
  Result.Token := AToken;
  Result.Multiplier := AMultiplier;
end;

procedure ValidatePreferences(const ALayer: TLearnedLayer; const AValueCopies: Integer;
  const APartitioned: Boolean; var AWork: Int64);
var
  LIndex: Integer;
  LOther: Integer;
  LState: Integer;
  LMultipliers: array of Integer;
  LToken: Integer;
  LWeight: Int64;
  LTotal: Int64;
begin
  if Length(ALayer.Preferences) = 0 then
  begin
    Exit;
  end;
  if Length(ALayer.Preferences) > MaximumLayerPreferences then
  begin
    raise EAudio.Create('Layer preference count exceeds 1024');
  end;
  if not APartitioned then
  begin
    Inc(AWork, Int64(ALayer.Model.StateCount) * ALayer.Model.StateCount *
      (ALayer.Model.Order + 1) * (ALayer.Model.PublicTokenCount + 1));
  end
  else
  begin
    Inc(AWork, Int64(ALayer.Model.StateCount) * AValueCopies *
      Length(ALayer.Preferences));
  end;
  if AWork > MaximumLayerPreferencePreparationWork then
  begin
    raise EAudio.Create('Layer preference preparation exceeds work budget');
  end;
  SetLength(LMultipliers, ALayer.Model.PublicTokenCount);
  for LIndex := 0 to High(LMultipliers) do
  begin
    LMultipliers[LIndex] := 1;
  end;
  for LIndex := 0 to High(ALayer.Preferences) do
  begin
    LToken := ALayer.Model.FindPublicToken(ALayer.Preferences[LIndex].Token);
    if (LToken < 0) or (ALayer.Preferences[LIndex].Multiplier < 1) or
      (ALayer.Preferences[LIndex].Multiplier > MaximumLayerPreferenceMultiplier) then
    begin
      raise EAudio.Create('Layer preference requires a known token and multiplier in 1..1024');
    end;
    for LOther := 0 to LIndex - 1 do
    begin
      if ALayer.Preferences[LOther].Token = ALayer.Preferences[LIndex].Token then
      begin
        raise EAudio.Create('Duplicate layer preference token');
      end;
    end;
    LMultipliers[LToken] := ALayer.Preferences[LIndex].Multiplier;
  end;
  LTotal := 0;
  for LState := 0 to ALayer.Model.StateCount - 1 do
  begin
    LToken := ALayer.Model.FindPublicToken(ALayer.Model.ProjectStateToken(LState));
    LWeight := Int64(ALayer.Model.StateObservationCountAt(LState)) * LMultipliers[LToken];
    Inc(LTotal, LWeight * AValueCopies);
    if LTotal > High(Integer) then
    begin
      raise EAudio.Create('Preferred graph weight sum exceeds signed 32-bit budget');
    end;
  end;
end;

destructor TPositionedLayerGraph.Destroy;
var
  LCompiler: TPositionedLayer;
begin
  for LCompiler in Compilers do
  begin
    LCompiler.Free;
  end;
  inherited Destroy;
end;

constructor TPositionedLayer.Create(const AModel: TWfcSequenceModel;
  const ACount: Integer; const AExtent: TWfcSequenceExtent);
var
  LPosition: Integer;
  LState: Integer;
  LAllowed: Boolean;
begin
  inherited Create;
  FModel := AModel;
  FCount := ACount;
  FExtent := AExtent;
  SetLength(FValues, ACount);
  SetLength(FDomains, ACount);
  for LPosition := 0 to ACount - 1 do
  begin
    SetLength(FValues[LPosition], AModel.StateCount);
    for LState := 0 to AModel.StateCount - 1 do
    begin
      FValues[LPosition][LState] := 'pythian-position:' + IntToStr(LPosition) +
        ':state:' + IntToStr(LState);
      LAllowed := True;
      if (AExtent = wseWrap) or
        ((LPosition = 0) and (AExtent in [wseFragment, wseSuffix])) then
      begin
        LAllowed := AModel.StateLeadingBosCountAt(LState) = 0;
      end;
      if (LPosition = 0) and (AExtent in [wseWhole, wsePrefix]) then
      begin
        LAllowed := LAllowed and (AModel.StartCountAt(LState) > 0);
      end;
      if (LPosition = ACount - 1) and (AExtent in [wseWhole, wseSuffix]) then
      begin
        LAllowed := LAllowed and (AModel.EndCountAt(LState) > 0);
      end;
      if LAllowed then
      begin
        SetLength(FDomains[LPosition], Length(FDomains[LPosition]) + 1);
        FDomains[LPosition][High(FDomains[LPosition])] := FValues[LPosition][LState];
      end;
    end;
  end;
end;

function TPositionedLayer.ValueAt(const APosition, AState: Integer): TGraphValue;
begin
  Result := FValues[APosition][AState];
end;

procedure TPositionedLayer.Apply(const APass: TGraph);
var
  LPosition: Integer;
  LNeighbor: Integer;
  LState: Integer;
  LOther: Integer;
  LStep: Integer;
  LTargets: TGraphValues;
  LRules: TGraphRules;
  LDirection: TGraphDirection;
  LDeny: array of TGraphDirections;
  LCompatible: Boolean;
begin
  if APass.HasDefinition or (APass.PassLayout.Cells.X <> FCount) or
    (APass.PassLayout.Cells.Y <> 1) or (APass.PassLayout.Cells.Z <> 1) or
    (APass.PassLayout.Wrap <> (FExtent = wseWrap)) then
  begin
    raise EAudio.Create('Position compilation needs a matching empty pass');
  end;
  SetLength(LDeny, FCount * FModel.StateCount);
  for LPosition := 0 to FCount - 1 do
  begin
    for LState := 0 to FModel.StateCount - 1 do
    begin
      APass.AddValue(ValueAt(LPosition, LState), FModel.StateObservationCountAt(LState));
    end;
  end;
  for LPosition := 0 to FCount - 1 do
  begin
    for LState := 0 to FModel.StateCount - 1 do
    begin
      LRules := nil;
      for LStep := 0 to 1 do
      begin
        LNeighbor := LPosition + 1;
        LDirection := gdWest;
        if LStep = 0 then
        begin
          LNeighbor := LPosition - 1;
          LDirection := gdEast;
        end;
        if FExtent = wseWrap then
        begin
          LNeighbor := (LNeighbor + FCount) mod FCount;
        end;
        LTargets := nil;
        if (LNeighbor >= 0) and (LNeighbor < FCount) then
        begin
          for LOther := 0 to FModel.StateCount - 1 do
          begin
            if LStep = 0 then
            begin
              LCompatible := FModel.StatesCompatible(LOther, LState);
            end
            else
            begin
              LCompatible := FModel.StatesCompatible(LState, LOther);
            end;
            if LCompatible then
            begin
              SetLength(LTargets, Length(LTargets) + 1);
              LTargets[High(LTargets)] := ValueAt(LNeighbor, LOther);
            end;
          end;
        end;
        if Length(LTargets) = 0 then
        begin
          Include(LDeny[LPosition * FModel.StateCount + LState], LDirection);
        end
        else
        begin
          SetLength(LRules, Length(LRules) + 1);
          LRules[High(LRules)].Key := LDirection;
          LRules[High(LRules)].Value := LTargets;
          LRules[High(LRules)].Info := False;
        end;
      end;
      { Both directions are prepared from the same public compatibility
        predicate; avoid a full inverse-closure walk for every individual edge. }
      APass.Rules[ValueAt(LPosition, LState)].Rules := LRules;
    end;
  end;
  for LPosition := 0 to FCount - 1 do
  begin
    for LState := 0 to FModel.StateCount - 1 do
    begin
      if LDeny[LPosition * FModel.StateCount + LState] <> [] then
      begin
        APass.Rules[ValueAt(LPosition, LState)].DenyAll(
          LDeny[LPosition * FModel.StateCount + LState]);
      end;
    end;
  end;
  SetMasks(APass, nil);
end;

procedure TPositionedLayer.SetMasks(const APass: TGraph;
  const AMasks: TWfcSequenceTokenConstraints);
var
  LCandidates: array of TGraphValues;
  LPosition: Integer;
  LValue: TGraphValue;
  LState: Integer;
  LMask: Integer;
  LToken: UTF8String;
  LMatch: Boolean;
  LAllowed: Boolean;
begin
  ValidateSequenceTokenConstraints(FModel, FCount, AMasks);
  SetLength(LCandidates, FCount);
  for LPosition := 0 to FCount - 1 do
  begin
    for LValue in FDomains[LPosition] do
    begin
      LState := 0;
      while ValueAt(LPosition, LState) <> LValue do
      begin
        Inc(LState);
      end;
      LAllowed := True;
      for LMask := 0 to High(AMasks) do
      begin
        if AMasks[LMask].Position <> LPosition then
        begin
          Continue;
        end;
        LMatch := False;
        for LToken in AMasks[LMask].AllowedTokens do
        begin
          LMatch := LMatch or (LToken = FModel.ProjectStateToken(LState));
        end;
        LAllowed := LAllowed and LMatch;
      end;
      if LAllowed then
      begin
        SetLength(LCandidates[LPosition], Length(LCandidates[LPosition]) + 1);
        LCandidates[LPosition][High(LCandidates[LPosition])] := LValue;
      end;
    end;
  end;
  for LPosition := 0 to FCount - 1 do
  begin
    APass.SetAllowedValues(LPosition, 0, 0, LCandidates[LPosition]);
  end;
end;

function TPositionedLayer.Capture(const APass: TGraph): TWfcGeneratedSequence;
var
  LPosition: Integer;
  LState: Integer;
  LFound: Boolean;
  LReport: TWfcSequenceGraphValidationReport;
  LDomain: TGraphValues;
  LValue: TGraphValue;
begin
  Result := Default(TWfcGeneratedSequence);
  Result.Boundary := FModel.Boundary;
  Result.Extent := FExtent;
  SetLength(Result.StateIndices, FCount);
  for LPosition := 0 to FCount - 1 do
  begin
    LFound := False;
    for LState := 0 to FModel.StateCount - 1 do
    begin
      if APass.Entry[LPosition, 0, 0].Value = ValueAt(LPosition, LState) then
      begin
        Result.StateIndices[LPosition] := LState;
        LFound := True;
        Break;
      end;
    end;
    if not LFound then
    begin
      raise EAudio.Create('Captured value has no original position/state identity');
    end;
    if APass.HasAllowedValues(LPosition, 0, 0) then
    begin
      LDomain := APass.CopyAllowedValues(LPosition, 0, 0);
      LFound := False;
      for LValue in LDomain do
      begin
        LFound := LFound or (LValue = APass.Entry[LPosition, 0, 0].Value);
      end;
      if not LFound then
      begin
        raise EAudio.Create('Captured positioned layer violates its entry domain');
      end;
    end;
  end;
  if not ValidateSequenceStatePath(FModel, Result.StateIndices, FExtent, LReport) then
  begin
    raise EAudio.Create('Compiled result violates original learned state path');
  end;
  Result.Tokens := FModel.ProjectStateIndices(Result.StateIndices);
end;

function DefaultLayerGenerationOptions: TLayerGenerationOptions;
begin
  Result.CellCount := 32;
  Result.Seed := 731;
  Result.Extent := wseFragment;
  Result.MaxBacktracks := 512;
  Result.MaxPassBacktracks := 64;
  Result.Scopes := nil;
  Result.TimeGrids := nil;
end;

function MakeLayerTimeGrid(const AOriginTick, ATicksPerCell: Integer): TLayerTimeGrid;
begin
  Result := Default(TLayerTimeGrid);
  if ATicksPerCell < 1 then
  begin
    raise EAudio.Create('Layer time grid requires positive ticks per cell');
  end;
  Result.OriginTick := AOriginTick;
  Result.TicksPerCell := ATicksPerCell;
end;

function MakeLayerTimePartition(const ABoundaries: array of Integer): TLayerTimeGrid;
var
  LIndex: Integer;
begin
  Result := Default(TLayerTimeGrid);
  if (Length(ABoundaries) < 2) or (Length(ABoundaries) > MaximumLayerCells + 1) then
  begin
    raise EAudio.Create('Layer time partition requires 2..1025 boundaries');
  end;
  SetLength(Result.Boundaries, Length(ABoundaries));
  for LIndex := 0 to High(ABoundaries) do
  begin
    if (LIndex > 0) and (ABoundaries[LIndex] <= ABoundaries[LIndex - 1]) then
    begin
      raise EAudio.Create('Layer time partition boundaries must strictly increase');
    end;
    Result.Boundaries[LIndex] := ABoundaries[LIndex];
  end;
end;

function MakeLayerScope(const ACellCount: Integer;
  const AExtent: TWfcSequenceExtent): TLayerScope;
begin
  if (ACellCount < 1) or (ACellCount > MaximumLayerCells) or
    not (AExtent in [wseWhole, wsePrefix, wseSuffix, wseFragment, wseWrap]) then
  begin
    raise EAudio.Create('Layer scope requires a bounded cell count and known extent');
  end;
  Result.CellCount := ACellCount;
  Result.Extent := AExtent;
end;

function ResolveLayerScope(const AOptions: TLayerGenerationOptions;
  const ALayerIndex: Integer): TLayerScope;
begin
  if (ALayerIndex < 0) or
    ((Length(AOptions.Scopes) > 0) and (ALayerIndex >= Length(AOptions.Scopes))) then
  begin
    raise EAudio.Create('Layer scope index is outside the supplied scopes');
  end;
  if Length(AOptions.Scopes) = 0 then
  begin
    Result := MakeLayerScope(AOptions.CellCount, AOptions.Extent);
  end
  else
  begin
    Result := MakeLayerScope(AOptions.Scopes[ALayerIndex].CellCount,
      AOptions.Scopes[ALayerIndex].Extent);
  end;
end;

function LayerName(const AIndex: Integer): String;
begin
  Result := 'pythian-layer-' + IntToStr(AIndex);
end;

function LayerLayout(const AOptions: TLayerGenerationOptions;
  const AIndex: Integer): TWfcLatticeLayout;
var
  LScope: TLayerScope;
  LGrid: TLayerTimeGrid;
begin
  LScope := ResolveLayerScope(AOptions, AIndex);
  LGrid := MakeLayerTimeGrid(0, 1);
  if Length(AOptions.TimeGrids) > 0 then
  begin
    LGrid := AOptions.TimeGrids[AIndex];
  end;
  if Length(LGrid.Boundaries) > 0 then
  begin
    Exit(MakeWfcLatticeLayout(LScope.CellCount, 1, 1, LScope.Extent = wseWrap));
  end;
  Result := MakeWfcLatticeLayout(LScope.CellCount, 1, 1,
    MakeWfcLatticeVector(LGrid.OriginTick, 0, 0),
    MakeWfcLatticeVector(LGrid.TicksPerCell, 1, 1), LScope.Extent = wseWrap);
end;

function HasTimePartitions(const AOptions: TLayerGenerationOptions): Boolean;
var
  LGrid: TLayerTimeGrid;
begin
  for LGrid in AOptions.TimeGrids do
  begin
    if Length(LGrid.Boundaries) > 0 then
    begin
      Exit(True);
    end;
  end;
  Result := False;
end;

function LayerTick(const AOptions: TLayerGenerationOptions;
  const ALayer, ABoundary: Integer): Int64;
var
  LGrid: TLayerTimeGrid;
begin
  if Length(AOptions.TimeGrids) = 0 then
  begin
    Exit(ABoundary);
  end;
  LGrid := AOptions.TimeGrids[ALayer];
  if Length(LGrid.Boundaries) > 0 then
  begin
    Exit(LGrid.Boundaries[ABoundary]);
  end;
  Result := Int64(LGrid.OriginTick) + Int64(ABoundary) * LGrid.TicksPerCell;
end;

function SameLayerTime(const AOptions: TLayerGenerationOptions;
  const ALeft, ARight: Integer): Boolean;
var
  LLeft: TLayerScope;
  LRight: TLayerScope;
  LBoundary: Integer;
begin
  LLeft := ResolveLayerScope(AOptions, ALeft);
  LRight := ResolveLayerScope(AOptions, ARight);
  if (LLeft.CellCount <> LRight.CellCount) or
    ((LLeft.Extent = wseWrap) <> (LRight.Extent = wseWrap)) then
  begin
    Exit(False);
  end;
  for LBoundary := 0 to LLeft.CellCount do
  begin
    if LayerTick(AOptions, ALeft, LBoundary) <> LayerTick(AOptions, ARight, LBoundary) then
    begin
      Exit(False);
    end;
  end;
  Result := True;
end;

function PartitionCoverage(const AProjection: TLayerProjection;
  const AOptions: TLayerGenerationOptions; const APosition: Integer): TLayerCellIndices;
var
  LProvider: TLayerScope;
  LStart: Int64;
  LFinish: Int64;
  LLength: Int64;
  LMinimum: Int64;
  LMaximum: Int64;
  LPeriod: Int64;
  LLeft: Int64;
  LRight: Int64;
  LCell: Integer;
  LHit: Boolean;
begin
  Result := nil;
  if AProjection.TimeMapping = ltmCellIndex then
  begin
    SetLength(Result, 1);
    Result[0] := APosition;
    Exit;
  end;
  LProvider := ResolveLayerScope(AOptions, AProjection.Provider);
  LStart := LayerTick(AOptions, AProjection.Consumer, APosition);
  LFinish := LayerTick(AOptions, AProjection.Consumer, APosition + 1);
  LLength := LFinish - LStart;
  LMinimum := LayerTick(AOptions, AProjection.Provider, 0);
  LMaximum := LayerTick(AOptions, AProjection.Provider, LProvider.CellCount);
  LPeriod := LMaximum - LMinimum;
  if LProvider.Extent = wseWrap then
  begin
    LStart := LMinimum + ((LStart - LMinimum) mod LPeriod + LPeriod) mod LPeriod;
    LFinish := LStart + LLength;
  end
  else if (LStart < LMinimum) or (LStart >= LMaximum) or
    ((AProjection.TimeMapping = ltmWholeCell) and (LFinish > LMaximum)) then
  begin
    raise EAudio.Create('Provider time partition does not cover the consumer query');
  end;
  for LCell := 0 to LProvider.CellCount - 1 do
  begin
    LLeft := LayerTick(AOptions, AProjection.Provider, LCell);
    LRight := LayerTick(AOptions, AProjection.Provider, LCell + 1);
    if AProjection.TimeMapping = ltmStartTick then
    begin
      LHit := (LStart >= LLeft) and (LStart < LRight);
    end
    else
    begin
      LHit := (LStart < LRight) and (LFinish > LLeft);
      if LProvider.Extent = wseWrap then
      begin
        LHit := LHit or (LLength >= LPeriod) or
          ((LFinish > LMaximum) and (LMinimum + LFinish - LMaximum > LLeft));
      end;
    end;
    if LHit then
    begin
      SetLength(Result, Length(Result) + 1);
      Result[High(Result)] := LCell;
    end;
  end;
end;

function ProjectionCoverage(const AProjection: TLayerProjection;
  const AOptions: TLayerGenerationOptions; const APosition: Integer): TWfcLatticeCoverage;
var
  LBox: TWfcLatticeBox;
  LPoint: TWfcLatticeVector;
  LLayout: TWfcLatticeLayout;
begin
  Result := Default(TWfcLatticeCoverage);
  LLayout := LayerLayout(AOptions, AProjection.Provider);
  LBox := WfcLatticeCellBox(LayerLayout(AOptions, AProjection.Consumer),
    MakeWfcLatticeVector(APosition, 0, 0));
  if AProjection.TimeMapping = ltmWholeCell then
  begin
    if not TryWfcLatticeCoverage(LLayout, LBox, Result) then
    begin
      raise EAudio.Create('Provider time grid does not cover the complete consumer cell');
    end;
  end
  else
  begin
    LPoint := MakeWfcLatticeVector(APosition, 0, 0);
    if (AProjection.TimeMapping = ltmStartTick) and
      not TryWfcLatticePoint(LLayout, LBox.Minimum, LPoint) then
    begin
      raise EAudio.Create('Provider time grid does not cover the consumer start tick');
    end;
    { Build a canonical singleton from a provider cell, including wrapped grids. }
    LBox := WfcLatticeCellBox(LLayout, LPoint);
    if not TryWfcLatticeCoverage(LLayout, LBox, Result) then
    begin
      raise EAudio.Create('Invalid provider cell coverage');
    end;
  end;
end;

function ProjectionCells(const AProjection: TLayerProjection;
  const AOptions: TLayerGenerationOptions; const APosition: Integer): TLayerCellIndices;
var
  LCoverage: TWfcLatticeCoverage;
  LIndex: Integer;
begin
  if HasTimePartitions(AOptions) then
  begin
    Exit(PartitionCoverage(AProjection, AOptions, APosition));
  end;
  LCoverage := ProjectionCoverage(AProjection, AOptions, APosition);
  Result := nil;
  SetLength(Result, WfcLatticeCoverageCellCount(LCoverage));
  for LIndex := 0 to High(Result) do
  begin
    Result[LIndex] := WfcLatticeCoverageCell(LCoverage, LIndex).X;
  end;
end;

procedure ValidateMappedRules(const AProjection: TLayerProjection;
  const ALayers: TLearnedLayers);
var
  LSeen: array of Boolean;
  LRule: Integer;
  LToken: Integer;
  LAlternative: Integer;
  LPrevious: Integer;
begin
  if Length(AProjection.Rules) <> ALayers[AProjection.Consumer].Model.PublicTokenCount then
  begin
    raise EAudio.Create('Mapped projection must cover every consumer public token');
  end;
  SetLength(LSeen, Length(AProjection.Rules));
  for LRule := 0 to High(AProjection.Rules) do
  begin
    LToken := ALayers[AProjection.Consumer].Model.FindPublicToken(
      AProjection.Rules[LRule].TargetToken);
    if (LToken < 0) or LSeen[LToken] then
    begin
      raise EAudio.Create('Mapped projection has an unknown or repeated consumer token');
    end;
    LSeen[LToken] := True;
    if Length(AProjection.Rules[LRule].SourceTokens) = 0 then
    begin
      raise EAudio.Create('Mapped projection needs a provider token alternative');
    end;
    for LAlternative := 0 to High(AProjection.Rules[LRule].SourceTokens) do
    begin
      if ALayers[AProjection.Provider].Model.FindPublicToken(
        AProjection.Rules[LRule].SourceTokens[LAlternative]) < 0 then
      begin
        raise EAudio.Create('Mapped projection has an unknown provider token');
      end;
      for LPrevious := 0 to LAlternative - 1 do
      begin
        if AProjection.Rules[LRule].SourceTokens[LPrevious] =
          AProjection.Rules[LRule].SourceTokens[LAlternative] then
        begin
          raise EAudio.Create('Mapped projection repeats a provider alternative');
        end;
      end;
    end;
  end;
end;

procedure ValidateRequest(const ALayers: TLearnedLayers;
  const AProjections: TLayerProjections; const AOptions: TLayerGenerationOptions);
var
  LIndex: Integer;
  LOther: Integer;
  LRule: Integer;
  LStates: Int64;
  LScope: TLayerScope;
  LWork: Int64;
  LRules: Int64;
  LAlternatives: Int64;
  LProjection: TLayerProjection;
  LMapped: array of Boolean;
  LPosition: Integer;
  LPairs: Int64;
  LPreparation: Int64;
  LPartitioned: Boolean;
  LGrid: TLayerTimeGrid;
  LBoundary: Integer;
  LExpanded: Int64;
  LMatrixBytes: Int64;
  LPositionWork: Int64;
  LGeometryWork: Int64;
  LRequirements: Int64;
  LProjectionAlternatives: Int64;
  LPreferenceWork: Int64;
begin
  if (Length(ALayers) < 1) or (Length(ALayers) > MaximumLearnedLayers) or
    ((Length(AOptions.Scopes) = 0) and
      ((AOptions.CellCount < 1) or (AOptions.CellCount > MaximumLayerCells))) or
    (AOptions.MaxBacktracks < 0) or (AOptions.MaxBacktracks > 65536) or
    (AOptions.MaxPassBacktracks < 0) or (AOptions.MaxPassBacktracks > 1024) or
    (Length(AProjections) > MaximumLearnedLayers * (MaximumLearnedLayers - 1) div 2) then
  begin
    raise EAudio.Create('Layer request exceeds bounded search contract');
  end;
  if (Length(AOptions.Scopes) = 0) and
    not (AOptions.Extent in [wseWhole, wsePrefix, wseSuffix, wseFragment, wseWrap]) then
  begin
    raise EAudio.Create('Unknown layer sequence extent');
  end;
  if (Length(AOptions.Scopes) <> 0) and (Length(AOptions.Scopes) <> Length(ALayers)) then
  begin
    raise EAudio.Create('Explicit scopes require one entry per layer');
  end;
  if (Length(AOptions.TimeGrids) <> 0) and
    (Length(AOptions.TimeGrids) <> Length(ALayers)) then
  begin
    raise EAudio.Create('Explicit time grids require one entry per layer');
  end;
  SetLength(LMapped, Length(ALayers));
  LPartitioned := HasTimePartitions(AOptions);
  LMatrixBytes := 0;
  LPositionWork := 0;
  LGeometryWork := 0;
  LRequirements := 0;
  LStates := 0;
  LPreferenceWork := 0;
  for LIndex := 0 to High(ALayers) do
  begin
    if ALayers[LIndex].Model = nil then
    begin
      raise EAudio.Create('Layer requires a learned model');
    end;
    LScope := ResolveLayerScope(AOptions, LIndex);
    if LPartitioned then
    begin
      ValidatePreferences(ALayers[LIndex], LScope.CellCount, True, LPreferenceWork);
    end
    else
    begin
      ValidatePreferences(ALayers[LIndex], 1, False, LPreferenceWork);
    end;
    if Length(AOptions.TimeGrids) > 0 then
    begin
      LGrid := AOptions.TimeGrids[LIndex];
      if Length(LGrid.Boundaries) > 0 then
      begin
        if (Length(LGrid.Boundaries) <> LScope.CellCount + 1) or
          (LGrid.OriginTick <> 0) or (LGrid.TicksPerCell <> 0) then
        begin
          raise EAudio.Create('Time partition needs count+1 boundaries and no uniform grid');
        end;
        for LBoundary := 1 to High(LGrid.Boundaries) do
        begin
          if LGrid.Boundaries[LBoundary] <= LGrid.Boundaries[LBoundary - 1] then
          begin
            raise EAudio.Create('Layer time partition boundaries must strictly increase');
          end;
        end;
      end;
    end;
    LayerLayout(AOptions, LIndex);
    if LPartitioned then
    begin
      LExpanded := Int64(LScope.CellCount) * ALayers[LIndex].Model.StateCount;
      if LExpanded > MaximumLayerPositionValues then
      begin
        raise EAudio.Create('Position-expanded layer value budget exceeded');
      end;
      Inc(LMatrixBytes, 12 * LExpanded * LExpanded + LScope.CellCount * LExpanded);
      Inc(LPositionWork, 2 * LExpanded * ALayers[LIndex].Model.StateCount *
        (ALayers[LIndex].Model.Order + 1) + 4 * LExpanded * LExpanded);
      if (LMatrixBytes > MaximumLayerPositionMatrixBytes) or
        (LPositionWork > MaximumLayerPositionPreparationWork) then
      begin
        raise EAudio.Create('Combined position-expanded matrix or preparation budget exceeded');
      end;
    end;
    Inc(LStates, Int64(ALayers[LIndex].Model.StateCount) * LScope.CellCount);
    if LStates > MaximumLayerStateCells then
    begin
      raise EAudio.Create('Combined layer state/cell budget exceeded');
    end;
    if Length(ALayers[LIndex].Constraints) > LScope.CellCount then
    begin
      raise EAudio.Create('Layer has too many position constraints');
    end;
    ValidateSequenceTokenConstraints(ALayers[LIndex].Model, LScope.CellCount,
      ALayers[LIndex].Constraints);
  end;
  LWork := 0;
  LRules := 0;
  LAlternatives := 0;
  for LIndex := 0 to High(AProjections) do
  begin
    LProjection := AProjections[LIndex];
    if (LProjection.Provider < 0) or (LProjection.Consumer >= Length(ALayers)) or
      (LProjection.Provider >= LProjection.Consumer) then
    begin
      raise EAudio.Create('Projection requires an earlier provider and a valid consumer');
    end;
    for LOther := 0 to LIndex - 1 do
    begin
      if (AProjections[LOther].Consumer = LProjection.Consumer) and
        (AProjections[LOther].Provider = LProjection.Provider) then
      begin
        raise EAudio.Create('Duplicate layer provider would obscure AND/OR semantics');
      end;
    end;
    LScope := ResolveLayerScope(AOptions, LProjection.Consumer);
    if not (LProjection.TimeMapping in [ltmCellIndex, ltmStartTick, ltmWholeCell]) then
    begin
      raise EAudio.Create('Unknown layer time mapping');
    end;
    LPairs := LScope.CellCount;
    if LProjection.TimeMapping = ltmCellIndex then
    begin
      if not SameLayerTime(AOptions, LProjection.Consumer, LProjection.Provider) then
      begin
        raise EAudio.Create('Positional projections require identical layouts; declare a time mapping');
      end;
    end
    else
    begin
      if Length(AOptions.TimeGrids) = 0 then
      begin
        raise EAudio.Create('Mapped projections require explicit common tick grids');
      end;
      LMapped[LProjection.Consumer] := True;
      LMapped[LProjection.Provider] := True;
      if LPartitioned then
      begin
        Inc(LGeometryWork, Int64(LScope.CellCount) *
          ResolveLayerScope(AOptions, LProjection.Provider).CellCount);
        if LGeometryWork > MaximumLayerMappingPreparationWork then
        begin
          raise EAudio.Create('Partition coverage preparation exceeds work budget');
        end;
      end;
      LPairs := 0;
      for LPosition := 0 to LScope.CellCount - 1 do
      begin
        Inc(LPairs, Length(ProjectionCells(LProjection, AOptions, LPosition)));
      end;
    end;
    Inc(LWork, Int64(ALayers[LProjection.Consumer].Model.StateCount) *
      ALayers[LProjection.Provider].Model.StateCount * LPairs);
    if LWork > MaximumLayerProjectionWork then
    begin
      raise EAudio.Create('Layer projection work budget exceeded');
    end;
    if LPartitioned then
    begin
      Inc(LRequirements, LPairs * ALayers[LProjection.Consumer].Model.StateCount);
      if (LRequirements > MaximumLayerPositionRequirements) or
        (LWork > MaximumLayerPositionProjectionWork) then
      begin
        raise EAudio.Create('Position-expanded projection or requirement budget exceeded');
      end;
    end;
    Inc(LRules, Length(LProjection.Rules));
    if LRules > 4096 then
    begin
      raise EAudio.Create('Layer projection rule budget exceeded');
    end;
    LProjectionAlternatives := 0;
    for LRule := 0 to High(LProjection.Rules) do
    begin
      Inc(LAlternatives, Length(LProjection.Rules[LRule].SourceTokens));
      Inc(LProjectionAlternatives, Length(LProjection.Rules[LRule].SourceTokens));
      if LAlternatives > 16384 then
      begin
        raise EAudio.Create('Layer projection alternatives exceed budget');
      end;
    end;
    if LPartitioned then
    begin
      Inc(LPositionWork, LPairs *
        (ALayers[LProjection.Provider].Model.StateCount * LProjectionAlternatives +
          Int64(ALayers[LProjection.Consumer].Model.StateCount) * Length(LProjection.Rules)));
      if LPositionWork > MaximumLayerPositionPreparationWork then
      begin
        raise EAudio.Create('Position-expanded projection preparation exceeds work budget');
      end;
    end;
    if LPartitioned or (LProjection.TimeMapping <> ltmCellIndex) then
    begin
      ValidateMappedRules(LProjection, ALayers);
    end;
  end;
  LPreparation := 0;
  for LIndex := 0 to High(ALayers) do
  begin
    if LMapped[LIndex] and not LPartitioned then
    begin
      { Public token-domain extraction validates the applied model each time.
        Bound those state-pair/history scans once per participating model. }
      Inc(LPreparation, Int64(ALayers[LIndex].Model.StateCount) *
        ALayers[LIndex].Model.StateCount * (ALayers[LIndex].Model.Order + 1) *
        (ALayers[LIndex].Model.PublicTokenCount + 1));
      if LPreparation > MaximumLayerMappingPreparationWork then
      begin
        raise EAudio.Create('Mapped token-domain preparation exceeds work budget');
      end;
    end;
  end;
end;

procedure ValidateCapturedRelations(const AProjections: TLayerProjections;
  const ASequences: TLayerSequences; const AOptions: TLayerGenerationOptions);
var
  LProjection: TLayerProjection;
  LPosition: Integer;
  LRule: Integer;
  LAlternative: Integer;
  LFound: Boolean;
  LCells: TLayerCellIndices;
  LOrdinal: Integer;
  LProviderCell: Integer;
begin
  for LProjection in AProjections do
  begin
    for LPosition := 0 to High(ASequences[LProjection.Consumer].Tokens) do
    begin
      LCells := ProjectionCells(LProjection, AOptions, LPosition);
      for LOrdinal := 0 to High(LCells) do
      begin
        LProviderCell := LCells[LOrdinal];
        LFound := False;
        for LRule := 0 to High(LProjection.Rules) do
        begin
          if LProjection.Rules[LRule].TargetToken <>
            ASequences[LProjection.Consumer].Tokens[LPosition] then
          begin
            Continue;
          end;
          for LAlternative := 0 to High(LProjection.Rules[LRule].SourceTokens) do
          begin
            if LProjection.Rules[LRule].SourceTokens[LAlternative] =
              ASequences[LProjection.Provider].Tokens[LProviderCell] then
            begin
              LFound := True;
              Break;
            end;
          end;
          Break;
        end;
        if not LFound then
        begin
          raise EAudio.Create('Captured layers violate a declared projection');
        end;
      end;
    end;
  end;
end;

function CopyTokenDomains(const AModel: TWfcSequenceModel;
  const APass: TGraph): TLayerDomains;
var
  LHadDomain: Boolean;
  LDomain: TGraphValues;
  LToken: Integer;
begin
  { Resolve latent graph keys only through the public sequence-domain API.
    No private key codec or registration-order assumption belongs here. }
  Result := nil;
  SetLength(Result, AModel.PublicTokenCount);
  LHadDomain := APass.HasAllowedValues(0, 0, 0);
  LDomain := APass.CopyAllowedValues(0, 0, 0);
  try
    for LToken := 0 to AModel.PublicTokenCount - 1 do
    begin
      APass.ClearAllowedValues(0, 0, 0);
      IntersectSequenceAllowedTokens(AModel, APass, 0, AModel.PublicTokenAt(LToken));
      Result[LToken] := APass.CopyAllowedValues(0, 0, 0);
    end;
  finally
    APass.ClearAllowedValues(0, 0, 0);
    if LHadDomain then
    begin
      APass.SetAllowedValues(0, 0, 0, LDomain);
    end;
  end;
end;

constructor TLayerPreferenceScope.Create(const ALayers: TLearnedLayers;
  const AGraph: TGraph; const AOptions: TLayerGenerationOptions);
var
  LLayer: Integer;
  LPreference: TLayerTokenPreference;
  LDomains: TLayerDomains;
  LValue: TGraphValue;
  LState: Integer;
  LPosition: Integer;
  LCapacity: Integer;
  LCount: Integer;
  LIndex: Integer;
  LPass: TGraph;
  LCompiler: TPositionedLayer;
  procedure AddChange(const AValue: TGraphValue; const AMultiplier: Integer);
  begin
    FChanges[LCount].Group := LPass.Rules[AValue];
    FChanges[LCount].Original := FChanges[LCount].Group.Weight;
    FChanges[LCount].Preferred := Integer(Int64(FChanges[LCount].Original) * AMultiplier);
    Inc(LCount);
  end;
begin
  inherited Create;
  LCapacity := 0;
  for LLayer := 0 to High(ALayers) do
  begin
    if Length(ALayers[LLayer].Preferences) > 0 then
    begin
      if AGraph is TPositionedLayerGraph then
      begin
        Inc(LCapacity, ALayers[LLayer].Model.StateCount *
          ResolveLayerScope(AOptions, LLayer).CellCount);
      end
      else
      begin
        Inc(LCapacity, ALayers[LLayer].Model.StateCount);
      end;
    end;
  end;
  SetLength(FChanges, LCapacity);
  LCount := 0;
  for LLayer := 0 to High(ALayers) do
  begin
    if Length(ALayers[LLayer].Preferences) = 0 then
    begin
      Continue;
    end;
    LPass := AGraph.PassGraph[LLayer];
    if AGraph is TPositionedLayerGraph then
    begin
      LCompiler := TPositionedLayerGraph(AGraph).Compilers[LLayer];
      for LPreference in ALayers[LLayer].Preferences do
      begin
        for LState := 0 to ALayers[LLayer].Model.StateCount - 1 do
        begin
          if ALayers[LLayer].Model.ProjectStateToken(LState) = LPreference.Token then
          begin
            for LPosition := 0 to ResolveLayerScope(AOptions, LLayer).CellCount - 1 do
            begin
              AddChange(LCompiler.ValueAt(LPosition, LState), LPreference.Multiplier);
            end;
          end;
        end;
      end;
    end
    else
    begin
      LDomains := CopyTokenDomains(ALayers[LLayer].Model, LPass);
      for LPreference in ALayers[LLayer].Preferences do
      begin
        for LValue in LDomains[ALayers[LLayer].Model.FindPublicToken(LPreference.Token)] do
        begin
          AddChange(LValue, LPreference.Multiplier);
        end;
      end;
    end;
  end;
  SetLength(FChanges, LCount);
  FApplied := True;
  for LIndex := 0 to High(FChanges) do
  begin
    FChanges[LIndex].Group.Weight := FChanges[LIndex].Preferred;
  end;
end;

destructor TLayerPreferenceScope.Destroy;
var
  LIndex: Integer;
begin
  if FApplied then
  begin
    for LIndex := 0 to High(FChanges) do
    begin
      FChanges[LIndex].Group.Weight := FChanges[LIndex].Original;
    end;
  end;
  inherited Destroy;
end;

procedure ApplyMappedProjection(const AProjection: TLayerProjection;
  const ALayers: TLearnedLayers; const AGraph: TGraph;
  const AConsumerDomains, AProviderDomains: TLayerDomains);
var
  LRule: Integer;
  LToken: Integer;
  LAlternative: Integer;
  LValue: TGraphValue;
  LAllowed: TGraphValues;
  LCount: Integer;
  LQuery: TGraphPassMapQuery;
begin
  for LRule := 0 to High(AProjection.Rules) do
  begin
    LAllowed := nil;
    for LAlternative := 0 to High(AProjection.Rules[LRule].SourceTokens) do
    begin
      LToken := ALayers[AProjection.Provider].Model.FindPublicToken(
        AProjection.Rules[LRule].SourceTokens[LAlternative]);
      LCount := Length(LAllowed);
      SetLength(LAllowed, LCount + Length(AProviderDomains[LToken]));
      for LValue in AProviderDomains[LToken] do
      begin
        LAllowed[LCount] := LValue;
        Inc(LCount);
      end;
    end;
    if AProjection.TimeMapping = ltmStartTick then
    begin
      LQuery := MakeGraphPassPointQuery(MakeGraphOffset(0, 0, 0), LAllowed);
    end
    else
    begin
      LQuery := MakeGraphPassCellQuery(LAllowed);
    end;
    LToken := ALayers[AProjection.Consumer].Model.FindPublicToken(
      AProjection.Rules[LRule].TargetToken);
    for LValue in AConsumerDomains[LToken] do
    begin
      AGraph.PassGraph[AProjection.Consumer].Rules[LValue].RequireMappedFromPass(
        LayerName(AProjection.Provider), LQuery);
    end;
  end;
end;

function BuildPositionedGraph(const ALayers: TLearnedLayers;
  const AProjections: TLayerProjections; const AOptions: TLayerGenerationOptions): TGraph;
var
  LGraph: TPositionedLayerGraph;
  LLayouts: TWfcLatticeLayouts;
  LIndex: Integer;
  LScope: TLayerScope;
  LProjection: TLayerProjection;
  LPosition: Integer;
  LProviderCell: Integer;
  LCells: TLayerCellIndices;
  LRule: Integer;
  LState: Integer;
  LSourceState: Integer;
  LAlternative: Integer;
  LAllowed: TGraphValues;
  LMatch: Boolean;
  LQuery: TGraphPassMapQuery;
begin
  LGraph := TPositionedLayerGraph.Create;
  try
    LGraph.Seed := AOptions.Seed;
    SetLength(LLayouts, Length(ALayers));
    SetLength(LGraph.Compilers, Length(ALayers));
    for LIndex := 0 to High(ALayers) do
    begin
      if LIndex = 0 then
      begin
        LGraph.CurrentPass := LayerName(LIndex);
      end
      else
      begin
        LGraph.SwitchToPass(LayerName(LIndex));
      end;
      LGraph.PassMode := gpmOverlay;
      LGraph.ClearDependencies;
      LScope := ResolveLayerScope(AOptions, LIndex);
      LLayouts[LIndex] := MakeWfcLatticeLayout(LScope.CellCount, 1, 1,
        LScope.Extent = wseWrap);
      LGraph.Compilers[LIndex] := TPositionedLayer.Create(ALayers[LIndex].Model,
        LScope.CellCount, LScope.Extent);
    end;
    LGraph.ConfigurePassLayouts(LLayouts);
    for LIndex := 0 to High(ALayers) do
    begin
      LGraph.Compilers[LIndex].Apply(LGraph.PassGraph[LIndex]);
      LGraph.Compilers[LIndex].SetMasks(LGraph.PassGraph[LIndex], ALayers[LIndex].Constraints);
    end;
    for LProjection in AProjections do
    begin
      LScope := ResolveLayerScope(AOptions, LProjection.Consumer);
      for LPosition := 0 to LScope.CellCount - 1 do
      begin
        LCells := ProjectionCells(LProjection, AOptions, LPosition);
        for LRule := 0 to High(LProjection.Rules) do
        begin
          for LProviderCell in LCells do
          begin
            LAllowed := nil;
            for LSourceState := 0 to ALayers[LProjection.Provider].Model.StateCount - 1 do
            begin
              LMatch := False;
              for LAlternative := 0 to High(LProjection.Rules[LRule].SourceTokens) do
              begin
                if ALayers[LProjection.Provider].Model.ProjectStateToken(LSourceState) =
                  LProjection.Rules[LRule].SourceTokens[LAlternative] then
                begin
                  LMatch := True;
                  Break;
                end;
              end;
              if LMatch then
              begin
                SetLength(LAllowed, Length(LAllowed) + 1);
                LAllowed[High(LAllowed)] := LGraph.Compilers[LProjection.Provider].ValueAt(
                  LProviderCell, LSourceState);
              end;
            end;
            LQuery := MakeGraphPassPointQuery(
              MakeGraphOffset(LProviderCell - LPosition, 0, 0), LAllowed);
            for LState := 0 to ALayers[LProjection.Consumer].Model.StateCount - 1 do
            begin
              if ALayers[LProjection.Consumer].Model.ProjectStateToken(LState) =
                LProjection.Rules[LRule].TargetToken then
              begin
                LGraph.PassGraph[LProjection.Consumer].Rules[
                  LGraph.Compilers[LProjection.Consumer].ValueAt(LPosition, LState)].
                  RequireMappedFromPass(LayerName(LProjection.Provider), LQuery);
              end;
            end;
          end;
        end;
      end;
    end;
    Result := LGraph;
  except
    LGraph.Free;
    raise;
  end;
end;

function BuildLayerGraph(const ALayers: TLearnedLayers;
  const AProjections: TLayerProjections; const AOptions: TLayerGenerationOptions): TGraph;
var
  LGraph: TGraph;
  LIndex: Integer;
  LOther: Integer;
  LBindings: TWfcSequenceProjectionBindings;
  LLayouts: TWfcLatticeLayouts;
  LScope: TLayerScope;
  LTokenDomains: array of TLayerDomains;
  LProvider: Integer;
begin
  if HasTimePartitions(AOptions) then
  begin
    Exit(BuildPositionedGraph(ALayers, AProjections, AOptions));
  end;
  LGraph := TGraph.Create;
  try
    LScope := ResolveLayerScope(AOptions, 0);
    LGraph.Reshape(LScope.CellCount, 1, 1);
    LGraph.WrapNeighbors := LScope.Extent = wseWrap;
    SetLength(LLayouts, Length(ALayers));
    SetLength(LTokenDomains, Length(ALayers));
    LGraph.Seed := AOptions.Seed;
    for LIndex := 0 to High(ALayers) do
    begin
      if LIndex = 0 then
      begin
        LGraph.CurrentPass := LayerName(LIndex);
      end
      else
      begin
        LGraph.SwitchToPass(LayerName(LIndex));
      end;
      LGraph.PassMode := gpmOverlay;
      { WFC retains a legacy predecessor edge when switching to overlay mode.
        Our dependency contract consists only of the declared projections. }
      LGraph.ClearDependencies;
      LLayouts[LIndex] := LayerLayout(AOptions, LIndex);
    end;
    LGraph.ConfigurePassLayouts(LLayouts);
    for LIndex := 0 to High(ALayers) do
    begin
      LGraph.SwitchToPass(LayerName(LIndex));
      LScope := ResolveLayerScope(AOptions, LIndex);
      ApplySequenceModelToGraph(ALayers[LIndex].Model, LGraph, LScope.Extent);
      IntersectSequenceTokenConstraints(ALayers[LIndex].Model, LGraph,
        ALayers[LIndex].Constraints);
    end;
    for LIndex := 0 to High(ALayers) do
    begin
      LGraph.SwitchToPass(LayerName(LIndex));
      LBindings := nil;
      for LOther := 0 to High(AProjections) do
      begin
        if AProjections[LOther].Consumer = LIndex then
        begin
          if AProjections[LOther].TimeMapping <> ltmCellIndex then
          begin
            LProvider := AProjections[LOther].Provider;
            if Length(LTokenDomains[LIndex]) = 0 then
            begin
              LTokenDomains[LIndex] := CopyTokenDomains(ALayers[LIndex].Model,
                LGraph.PassGraph[LIndex]);
            end;
            if Length(LTokenDomains[LProvider]) = 0 then
            begin
              LTokenDomains[LProvider] := CopyTokenDomains(ALayers[LProvider].Model,
                LGraph.PassGraph[LProvider]);
            end;
            ApplyMappedProjection(AProjections[LOther], ALayers, LGraph,
              LTokenDomains[LIndex], LTokenDomains[LProvider]);
            Continue;
          end;
          SetLength(LBindings, Length(LBindings) + 1);
          LBindings[High(LBindings)] := MakeWfcSequenceProjectionBinding(
            ALayers[AProjections[LOther].Provider].Model,
            LayerName(AProjections[LOther].Provider), AProjections[LOther].Rules);
        end;
      end;
      if Length(LBindings) > 0 then
      begin
        RequireSequenceProjectionMapsFromPasses(ALayers[LIndex].Model, LGraph, LBindings);
      end;
    end;
    Result := LGraph;
  except
    LGraph.Free;
    raise;
  end;
end;

function CaptureLayers(const ALayers: TLearnedLayers;
  const AProjections: TLayerProjections; const AOptions: TLayerGenerationOptions;
  const AGraph: TGraph): TLayerSequences;
var
  LSequences: TLayerSequences;
  LIndex: Integer;
  LValidation: TWfcSequenceGraphValidationReport;
  LFalsePosition: Integer;
begin
  SetLength(LSequences, Length(ALayers));
  for LIndex := 0 to High(ALayers) do
  begin
    if AGraph is TPositionedLayerGraph then
    begin
      LSequences[LIndex] := TPositionedLayerGraph(AGraph).Compilers[LIndex].Capture(
        AGraph.PassGraph[LIndex]);
      Continue;
    end;
    if not CaptureSolvedSequence(ALayers[LIndex].Model, AGraph.PassGraph[LIndex],
      ResolveLayerScope(AOptions, LIndex).Extent, LSequences[LIndex], LValidation) then
    begin
      raise EAudio.Create('Captured layer failed actual WFC path validation');
    end;
    if not SequenceStatesSatisfyEntryConstraints(ALayers[LIndex].Model,
      AGraph.PassGraph[LIndex], LSequences[LIndex].StateIndices, LFalsePosition) then
    begin
      raise EAudio.Create('Captured layer violates position constraints');
    end;
  end;
  ValidateCapturedRelations(AProjections, LSequences, AOptions);
  Result := LSequences;
end;

function NegotiationOptions(const AOptions: TLayerGenerationOptions): TGraphNegotiationOptions;
begin
  Result := DefaultGraphNegotiationOptions;
  Result.SolveOptions.MaxBacktracks := AOptions.MaxBacktracks;
  Result.MaxPassBacktracks := AOptions.MaxPassBacktracks;
end;

function SolvePreferredLayers(const ALayers: TLearnedLayers; const AGraph: TGraph;
  const AOptions: TLayerGenerationOptions; out AReport: TGraphNegotiationReport): Boolean;
var
  LPreferenceScope: TLayerPreferenceScope;
begin
  LPreferenceScope := TLayerPreferenceScope.Create(ALayers, AGraph, AOptions);
  try
    Result := AGraph.TrySolveNegotiated(NegotiationOptions(AOptions), AReport);
  finally
    LPreferenceScope.Free;
  end;
end;

function TryGenerateLayers(const ALayers: TLearnedLayers;
  const AProjections: TLayerProjections; const AOptions: TLayerGenerationOptions;
  var ASequences: TLayerSequences; out AReport: TGraphNegotiationReport): Boolean;
var
  LGraph: TGraph;
begin
  AReport := Default(TGraphNegotiationReport);
  ValidateRequest(ALayers, AProjections, AOptions);
  LGraph := BuildLayerGraph(ALayers, AProjections, AOptions);
  try
    Result := SolvePreferredLayers(ALayers, LGraph, AOptions, AReport);
    if Result then
    begin
      ASequences := CaptureLayers(ALayers, AProjections, AOptions, LGraph);
    end;
  finally
    LGraph.Free;
  end;
end;

constructor TLearnedLayerSession.Create(const ALayers: TLearnedLayers;
  const AProjections: TLayerProjections; const ANames: TLayerNames;
  const AOptions: TLayerGenerationOptions);
var
  LIndex: Integer;
  LOther: Integer;
  LRule: Integer;
  LCell: Integer;
  LPass: TGraph;
  LScope: TLayerScope;
begin
  inherited Create;
  ValidateRequest(ALayers, AProjections, AOptions);
  if Length(ANames) <> Length(ALayers) then
  begin
    raise EAudio.Create('Session requires one unique name per layer');
  end;
  for LIndex := 0 to High(ANames) do
  begin
    if (Length(ANames[LIndex]) < 1) or (Length(ANames[LIndex]) > 128) or
      (Trim(ANames[LIndex]) <> ANames[LIndex]) then
    begin
      raise EAudio.Create('Layer names must contain 1..128 characters without surrounding spaces');
    end;
    for LOther := 1 to Length(ANames[LIndex]) do
    begin
      if Ord(ANames[LIndex][LOther]) < 32 then
      begin
        raise EAudio.Create('Layer names cannot contain control characters');
      end;
    end;
    for LOther := 0 to LIndex - 1 do
    begin
      if ANames[LOther] = ANames[LIndex] then
      begin
        raise EAudio.Create('Duplicate session layer name');
      end;
    end;
  end;
  FOptions := AOptions;
  FOptions.Scopes := Copy(AOptions.Scopes);
  FOptions.TimeGrids := Copy(AOptions.TimeGrids);
  for LIndex := 0 to High(FOptions.TimeGrids) do
  begin
    FOptions.TimeGrids[LIndex].Boundaries := Copy(AOptions.TimeGrids[LIndex].Boundaries);
  end;
  FNames := Copy(ANames);
  SetLength(FLayers, Length(ALayers));
  SetLength(FDirty, Length(ALayers));
  SetLength(FBaseline, Length(ALayers));
  SetLength(FHasBaseline, Length(ALayers));
  for LIndex := 0 to High(ALayers) do
  begin
    FLayers[LIndex].Model := DecodeWfcSequenceText(EncodeWfcSequenceText(ALayers[LIndex].Model));
    FLayers[LIndex].Preferences := Copy(ALayers[LIndex].Preferences);
  end;
  SetLength(FProjections, Length(AProjections));
  for LIndex := 0 to High(AProjections) do
  begin
    FProjections[LIndex].Provider := AProjections[LIndex].Provider;
    FProjections[LIndex].Consumer := AProjections[LIndex].Consumer;
    FProjections[LIndex].TimeMapping := AProjections[LIndex].TimeMapping;
    SetLength(FProjections[LIndex].Rules, Length(AProjections[LIndex].Rules));
    for LRule := 0 to High(AProjections[LIndex].Rules) do
    begin
      FProjections[LIndex].Rules[LRule] := AProjections[LIndex].Rules[LRule];
      FProjections[LIndex].Rules[LRule].SourceTokens :=
        Copy(AProjections[LIndex].Rules[LRule].SourceTokens);
    end;
  end;
  { Capture model/extent domains before adding caller masks. Clearing a mask
    must restore endpoint restrictions as well as the full token vocabulary. }
  FGraph := BuildLayerGraph(FLayers, FProjections, FOptions);
  for LIndex := 0 to High(FLayers) do
  begin
    LPass := FGraph.PassGraph[LIndex];
    LScope := ResolveLayerScope(FOptions, LIndex);
    SetLength(FBaseline[LIndex], LScope.CellCount);
    SetLength(FHasBaseline[LIndex], LScope.CellCount);
    for LCell := 0 to LScope.CellCount - 1 do
    begin
      FHasBaseline[LIndex][LCell] := LPass.HasAllowedValues(LCell, 0, 0);
      FBaseline[LIndex][LCell] := LPass.CopyAllowedValues(LCell, 0, 0);
    end;
    SetConstraints(FNames[LIndex], ALayers[LIndex].Constraints);
  end;
end;

destructor TLearnedLayerSession.Destroy;
var
  LIndex: Integer;
begin
  FGraph.Free;
  for LIndex := 0 to High(FLayers) do
  begin
    FLayers[LIndex].Model.Free;
  end;
  inherited Destroy;
end;

function TLearnedLayerSession.LayerIndex(const AName: String): Integer;
begin
  for Result := 0 to High(FNames) do
  begin
    if FNames[Result] = AName then
    begin
      Exit;
    end;
  end;
  raise EAudio.CreateFmt('Unknown session layer "%s"', [AName]);
end;

procedure TLearnedLayerSession.SetConstraints(const AName: String;
  const AConstraints: TWfcSequenceTokenConstraints);
var
  LIndex: Integer;
  LCell: Integer;
  LPass: TGraph;
  LScope: TLayerScope;
  LPrevious: TLayerDomains;
  LHadPrevious: TLayerDomainFlags;
  LConstraints: TWfcSequenceTokenConstraints;
  LConstraint: Integer;
begin
  LIndex := LayerIndex(AName);
  LScope := ResolveLayerScope(FOptions, LIndex);
  if Length(AConstraints) > LScope.CellCount then
  begin
    raise EAudio.Create('Layer has too many position constraints');
  end;
  ValidateSequenceTokenConstraints(FLayers[LIndex].Model, LScope.CellCount, AConstraints);
  LConstraints := Copy(AConstraints);
  for LConstraint := 0 to High(LConstraints) do
  begin
    LConstraints[LConstraint].AllowedTokens := Copy(AConstraints[LConstraint].AllowedTokens);
  end;
  LPass := FGraph.PassGraph[LIndex];
  SetLength(LPrevious, LScope.CellCount);
  SetLength(LHadPrevious, LScope.CellCount);
  for LCell := 0 to LScope.CellCount - 1 do
  begin
    LHadPrevious[LCell] := LPass.HasAllowedValues(LCell, 0, 0);
    LPrevious[LCell] := LPass.CopyAllowedValues(LCell, 0, 0);
  end;
  try
    for LCell := 0 to LScope.CellCount - 1 do
    begin
      LPass.ClearAllowedValues(LCell, 0, 0);
      if FHasBaseline[LIndex][LCell] then
      begin
        LPass.SetAllowedValues(LCell, 0, 0, FBaseline[LIndex][LCell]);
      end;
    end;
    if FGraph is TPositionedLayerGraph then
    begin
      TPositionedLayerGraph(FGraph).Compilers[LIndex].SetMasks(LPass, AConstraints);
    end
    else
    begin
      IntersectSequenceTokenConstraints(FLayers[LIndex].Model, LPass, AConstraints);
    end;
  except
    for LCell := 0 to LScope.CellCount - 1 do
    begin
      LPass.ClearAllowedValues(LCell, 0, 0);
      if LHadPrevious[LCell] then
      begin
        LPass.SetAllowedValues(LCell, 0, 0, LPrevious[LCell]);
      end;
    end;
    raise;
  end;
  FLayers[LIndex].Constraints := LConstraints;
  FDirty[LIndex] := True;
end;

procedure TLearnedLayerSession.SetPreferences(const AName: String;
  const APreferences: TLayerTokenPreferences);
var
  LIndex: Integer;
  LRequested: TLearnedLayers;
begin
  LIndex := LayerIndex(AName);
  LRequested := Copy(FLayers);
  LRequested[LIndex].Preferences := Copy(APreferences);
  ValidateRequest(LRequested, FProjections, FOptions);
  FLayers[LIndex].Preferences := LRequested[LIndex].Preferences;
  FDirty[LIndex] := True;
end;

function TLearnedLayerSession.CopyPreferences(const AName: String): TLayerTokenPreferences;
begin
  Result := Copy(FLayers[LayerIndex(AName)].Preferences);
end;

procedure TLearnedLayerSession.AcceptSolved;
var
  LIndex: Integer;
begin
  FAccepted := CaptureLayers(FLayers, FProjections, FOptions, FGraph);
  for LIndex := 0 to High(FDirty) do
  begin
    FDirty[LIndex] := False;
  end;
end;

function TLearnedLayerSession.CopyAccepted: TLayerSequences;
var
  LResult: TLayerSequences;
  LIndex: Integer;
begin
  SetLength(LResult, Length(FAccepted));
  for LIndex := 0 to High(FAccepted) do
  begin
    LResult[LIndex] := FAccepted[LIndex];
    LResult[LIndex].Tokens := Copy(FAccepted[LIndex].Tokens);
    LResult[LIndex].StateIndices := Copy(FAccepted[LIndex].StateIndices);
  end;
  Result := LResult;
end;

function TLearnedLayerSession.TryGenerate(var ASequences: TLayerSequences;
  out AReport: TGraphNegotiationReport): Boolean;
begin
  AReport := Default(TGraphNegotiationReport);
  if Length(FAccepted) <> 0 then
  begin
    raise EAudio.Create('Session already has accepted results; use selective regeneration');
  end;
  Result := SolvePreferredLayers(FLayers, FGraph, FOptions, AReport);
  if Result then
  begin
    AcceptSolved;
    ASequences := CopyAccepted;
  end;
end;

function TLearnedLayerSession.RegenerationRoots(
  const ARoots: array of String): TGraphPassLabels;
var
  LSelected: array of Boolean;
  LCovered: array of Boolean;
  LLabels: TGraphPassLabels;
  LIndex: Integer;
  LConsumer: Integer;
  LProjection: TLayerProjection;
begin
  if (Length(FAccepted) = 0) or (Length(ARoots) < 1) or
    (Length(ARoots) > MaximumLearnedLayers) then
  begin
    raise EAudio.Create('Regeneration requires accepted results and 1..8 named roots');
  end;
  SetLength(LSelected, Length(FLayers));
  for LIndex := 0 to High(ARoots) do
  begin
    LSelected[LayerIndex(ARoots[LIndex])] := True;
  end;
  LCovered := Copy(LSelected);
  LLabels := nil;
  { Close requested roots in dependency order. Include pending edits outside
    that closure so an unrelated changed mask cannot be silently ignored. }
  for LConsumer := 0 to High(FLayers) do
  begin
    for LProjection in FProjections do
    begin
      if (LProjection.Consumer = LConsumer) and LCovered[LProjection.Provider] then
      begin
        LCovered[LConsumer] := True;
      end;
    end;
    if FDirty[LConsumer] and not LCovered[LConsumer] then
    begin
      LSelected[LConsumer] := True;
      LCovered[LConsumer] := True;
    end;
  end;
  for LIndex := 0 to High(LSelected) do
  begin
    if LSelected[LIndex] then
    begin
      SetLength(LLabels, Length(LLabels) + 1);
      LLabels[High(LLabels)] := LayerName(LIndex);
    end;
  end;
  Result := LLabels;
end;

function TLearnedLayerSession.TryRegenerate(const ARoots: array of String;
  const ASeed: TGraphSeed; var ASequences: TLayerSequences;
  out AReport: TGraphSelectiveNegotiationReport): Boolean;
var
  LLabels: TGraphPassLabels;
  LPreferenceScope: TLayerPreferenceScope;
begin
  AReport := Default(TGraphSelectiveNegotiationReport);
  LLabels := RegenerationRoots(ARoots);
  FGraph.Seed := ASeed;
  LPreferenceScope := TLayerPreferenceScope.Create(FLayers, FGraph, FOptions);
  try
    Result := FGraph.TryRegenerateNegotiatedFrom(LLabels, NegotiationOptions(FOptions), AReport);
  finally
    LPreferenceScope.Free;
  end;
  if Result then
  begin
    AcceptSolved;
    ASequences := CopyAccepted;
  end;
end;

function TLearnedLayerSession.TryReplaceModel(const AName: String;
  const AModel: TWfcSequenceModel; const ASeed: TGraphSeed;
  var ASequences: TLayerSequences; out AReport: TLayerModelReplacementReport): Boolean;
var
  LLabels: TGraphPassLabels;
  LRequested: TLearnedLayers;
  LCandidate: TLearnedLayerSession;
  LAffected: TLayerDomainFlags;
  LPublished: TLayerSequences;
  LOldGraph: TGraph;
  LOldLayers: TLearnedLayers;
  LIndex: Integer;
  LCell: Integer;
begin
  AReport := Default(TLayerModelReplacementReport);
  AReport.ReplacedLayerIndex := -1;
  LLabels := RegenerationRoots([AName]);
  LIndex := LayerIndex(AName);
  AReport.ReplacedLayerIndex := LIndex;
  LRequested := Copy(FLayers);
  LRequested[LIndex].Model := AModel;
  { Constructor validates all existing masks/relations against the replacement
    and detaches every input. No accepted state is mutated before publication. }
  LCandidate := TLearnedLayerSession.Create(LRequested, FProjections, FNames, FOptions);
  try
    LCandidate.FGraph.ResolveRegenerationScope(LLabels, AReport.RootLayerIndices,
      AReport.AffectedLayerIndices);
    SetLength(LAffected, Length(FLayers));
    for LIndex in AReport.AffectedLayerIndices do
    begin
      LAffected[LIndex] := True;
    end;
    for LIndex := 0 to High(FLayers) do
    begin
      if LAffected[LIndex] then
      begin
        Continue;
      end;
      SetLength(AReport.PreservedLayerIndices, Length(AReport.PreservedLayerIndices) + 1);
      AReport.PreservedLayerIndices[High(AReport.PreservedLayerIndices)] := LIndex;
      for LCell := 0 to High(FAccepted[LIndex].StateIndices) do
      begin
        { Identical cloned models use identical state keys. Restrict domains,
          not entry Value: caller-pinned entries would obstruct later edits. }
        LCandidate.FGraph.PassGraph[LIndex].SetAllowedValues(LCell, 0, 0,
          [FGraph.PassGraph[LIndex][LCell, 0, 0].Value]);
      end;
    end;
    LCandidate.FGraph.Seed := ASeed;
    Result := SolvePreferredLayers(LCandidate.FLayers, LCandidate.FGraph,
      FOptions, AReport.Search);
    if not Result then
    begin
      Exit;
    end;
    for LIndex in AReport.PreservedLayerIndices do
    begin
      { Restore original domains before capture and future selective solving. }
      LCandidate.SetConstraints(FNames[LIndex], FLayers[LIndex].Constraints);
    end;
    LCandidate.AcceptSolved;
    for LIndex in AReport.PreservedLayerIndices do
    begin
      for LCell := 0 to High(FAccepted[LIndex].StateIndices) do
      begin
        if (LCandidate.FAccepted[LIndex].StateIndices[LCell] <>
          FAccepted[LIndex].StateIndices[LCell]) or
          (LCandidate.FAccepted[LIndex].Tokens[LCell] <> FAccepted[LIndex].Tokens[LCell]) then
        begin
          raise EAudio.Create('Model replacement changed an independent accepted layer');
        end;
      end;
    end;
    LPublished := LCandidate.CopyAccepted;
    { All validation/allocation is finished. Transfer owned graphs/models;
      destroying the candidate releases the old session state after publication. }
    LOldGraph := FGraph;
    FGraph := LCandidate.FGraph;
    LCandidate.FGraph := LOldGraph;
    LOldLayers := FLayers;
    FLayers := LCandidate.FLayers;
    LCandidate.FLayers := LOldLayers;
    FBaseline := LCandidate.FBaseline;
    FHasBaseline := LCandidate.FHasBaseline;
    FDirty := LCandidate.FDirty;
    FAccepted := LCandidate.FAccepted;
    ASequences := LPublished;
  finally
    LCandidate.Free;
  end;
end;

end.
