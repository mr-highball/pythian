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
  pythian.progress,
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
  MaximumSessionSnapshotTextUnits = 16777216;

type
  TLayerTokenPreference = record
    Token: String;
    Multiplier: Integer;
  end;
  TLayerTokenPreferences = array of TLayerTokenPreference;
  { Borrowed single-pass graph/model; dispose before the graph. Reuses the
    primary layer preference validation, weight mapping and restoration.
    Original weights must be restored before authenticating captured paths. }
  TSequencePreferenceScope = class
  private
    FInner: TObject;
  public
    constructor Create(const AModel: TWfcSequenceModel; const AGraph: TGraph;
      const APreferences: TLayerTokenPreferences;
      const AProgress: TWorkProgressCallback = nil);
    destructor Destroy; override;
    procedure UseOriginal(const AProgress: TWorkProgressCallback = nil);
  end;
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
  TLayerModelTexts = array of String;
  { Accepted, clean session state. Layers' model pointers are nil; Models owns
    their canonical text. Other vectors and assignments are detached. }
  TLayerAcceptedSnapshot = record
    Version: Integer;
    Options: TLayerGenerationOptions;
    Names: TLayerNames;
    Layers: TLearnedLayers;
    Models: TLayerModelTexts;
    Projections: TLayerProjections;
    Assignments: TGraphAssignmentSnapshot;
  end;
  { Big Boss: one detached pass-description contract for all primary sessions.
    Model counts are zero for proof passes. Dependencies index this snapshot.
    GroupIndex identifies separate executed graphs; InputSourcePassIndex is a
    pinned-input lineage edge, not a solver dependency across graph instances. }
  TLayerGraphPass = record
    Name: String;
    Width: Integer;
    Height: Integer;
    Depth: Integer;
    IsProof: Boolean;
    PublicTokenCount: Integer;
    StateCount: Integer;
    Dependencies: TGraphPassIndices;
    GroupIndex: Integer;
    InputSourcePassIndex: Integer;
  end;
  TLayerGraphPasses = array of TLayerGraphPass;
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
    FSnapshotBusy: Boolean;
    procedure CheckSnapshotIdle;
    function LayerIndex(const AName: String): Integer;
    function RegenerationRoots(const ARoots: array of String): TGraphPassLabels;
    procedure AcceptSolved(const APrepared: TLayerSequences);
  public
    { Observer covers request/graph/model/domain preparation, not companion solve
      internals or later capture. Borrowed only during this construction. }
    constructor Create(const ALayers: TLearnedLayers;
      const AProjections: TLayerProjections; const ANames: TLayerNames;
      const AOptions: TLayerGenerationOptions;
      const AProgress: TWorkProgressCallback = nil);
    destructor Destroy; override;
    procedure SetConstraints(const AName: String;
      const AConstraints: TWfcSequenceTokenConstraints;
      const AProgress: TWorkProgressCallback = nil);
    { Replaces the complete preference list, retaining accepted output until solve.
      Detached ownership; nil restores learned choice weights. Not a hard mask. }
    procedure SetPreferences(const AName: String;
      const APreferences: TLayerTokenPreferences;
      const AProgress: TWorkProgressCallback = nil);
    function CopyPreferences(const AName: String): TLayerTokenPreferences;
    { Borrowed solve/capture/copy observation runs before accepted publication.
      Observer failure preserves accepted output and supports exact retry.
      Do not reenter or mutate inputs from an observer. Phase counts are local
      work, never overall generation percentages. }
    function TryGenerate(var ASequences: TLayerSequences;
      out AReport: TGraphNegotiationReport;
      const AProgress: TWorkProgressCallback = nil): Boolean;
    function TryRegenerate(const ARoots: array of String; const ASeed: TGraphSeed;
      var ASequences: TLayerSequences;
      out AReport: TGraphSelectiveNegotiationReport;
      const AProgress: TWorkProgressCallback = nil): Boolean;
    { Replace one model after initial acceptance, keeping scopes, relations and
      masks. Clones AModel; never takes its ownership. Includes pending edits.
      False/exception preserves the entire session and caller output. Independent
      tokens/states survive; candidate solve uses fresh seeded random streams. }
    function TryReplaceModel(const AName: String; const AModel: TWfcSequenceModel;
      const ASeed: TGraphSeed; var ASequences: TLayerSequences;
      out AReport: TLayerModelReplacementReport;
      const AProgress: TWorkProgressCallback = nil): Boolean;
    function CopyAccepted(const AProgress: TWorkProgressCallback = nil): TLayerSequences;
    function CopyGraph: TLayerGraphPasses;
    function CopyModel(const AName: String;
      const AProgress: TWorkProgressCallback = nil): TWfcSequenceModel;
    { Requires acceptance and no pending edits. These operations copy/decode
      saved models and rebuild configuration, but never learn or solve.
      Independent model/path/projection proof runs before returning restoration.
      The observer must not mutate/free inputs or reenter the source session. }
    function CopyAcceptedSnapshot(const AProgress: TWorkProgressCallback = nil): TLayerAcceptedSnapshot;
    class function FromAcceptedSnapshot(const ASnapshot: TLayerAcceptedSnapshot;
      const AProgress: TWorkProgressCallback = nil): TLearnedLayerSession; static;
  end;

function DefaultLayerGenerationOptions: TLayerGenerationOptions;
{ Shared detached mask copy for layer, voice and musical-control consumers. }
function CopyVoiceTokenConstraints(const AMask: TWfcSequenceTokenConstraints;
  const AProgress: TWorkProgressCallback = nil;
  const APass: Integer = 0): TWfcSequenceTokenConstraints;
function DescribeLayerGraph(const AGraph: TGraph; const ANames: array of String;
  const AModels: array of TWfcSequenceModel): TLayerGraphPasses;
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
  var ASequences: TLayerSequences; out AReport: TGraphNegotiationReport;
  const AProgress: TWorkProgressCallback = nil): Boolean;

implementation

uses
  SysUtils,
  pythian.audio,
  wfc_model,
  wfc_sequence_text,
  wfc_lattice,
  pythian.wfc.progress;

type
  { Call-scoped, never retained by a graph or session. Visits count owned loop
    iterations, not companion internals or estimated overall work. }
  TLayerPreparation = class(TWfcObservedWork)
  public
    procedure ObserveSequence(const AWork: TWfcSequencePreparationProgress);
    function SequenceObserver: TWfcSequencePreparationObserver;
  end;
  TLayerPublication = class;
  { The receiver is borrowed only during one solve. It is never copied into
    an accepted session and is cleared even when a callback raises. }
  TObservedLayerGraph = class(TGraph)
  protected
    function DoValidateCommit(out AFailedPassIndex,
      AFailedEntryIndex: Integer): Boolean; override;
  public
    Publication: TLayerPublication;
  end;
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
      const AExtent: TWfcSequenceExtent; const APreparation: TLayerPreparation = nil);
    procedure Apply(const APass: TGraph; const APreparation: TLayerPreparation = nil);
    procedure SetMasks(const APass: TGraph; const AMasks: TWfcSequenceTokenConstraints;
      const APreparation: TLayerPreparation = nil);
    function ValueAt(const APosition, AState: Integer): TGraphValue;
    function Capture(const APass: TGraph;
      const APreparation: TLayerPreparation = nil): TWfcGeneratedSequence;
  end;
  { Private graph/compiler lifetime is shorter than its borrowed model lifetime.
    Public sessions own detached models and partitions. No caller graph escapes. }
  TPositionedLayerGraph = class(TObservedLayerGraph)
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
      const AOptions: TLayerGenerationOptions;
      const APreparation: TLayerPreparation = nil);
    procedure UseOriginal(const APreparation: TLayerPreparation = nil);
    procedure UsePreferred(const APreparation: TLayerPreparation = nil);
    destructor Destroy; override;
  end;
  TLayerPublication = class
  private
    FGraph: TObservedLayerGraph;
    FLayers: TLearnedLayers;
    FProjections: TLayerProjections;
    FOptions: TLayerGenerationOptions;
    FPreferences: TLayerPreferenceScope;
    FCallback: TWorkProgressCallback;
    FGuardedCapture: Boolean;
    FDetachedCaller: Boolean;
  public
    Captured: TLayerSequences;
    CallerCopy: TLayerSequences;
    constructor Create(const ALayers: TLearnedLayers;
      const AProjections: TLayerProjections; const AGraph: TGraph;
      const AOptions: TLayerGenerationOptions; const ADetachedCaller,
      AGuardedCapture: Boolean; const AProgress: TWorkProgressCallback);
    destructor Destroy; override;
    procedure Capture;
  end;

procedure TLayerPreparation.ObserveSequence(const AWork: TWfcSequencePreparationProgress);
var
  LStage: String;
begin
  case AWork.Phase of
    wspValidateConstraints: LStage := 'layer_wfc_constraint_rows';
    wspValidateGraphModel: LStage := 'layer_wfc_model_rows';
    wspSnapshotDomains: LStage := 'layer_wfc_snapshot_cells';
    wspIntersectDomains: LStage := 'layer_wfc_mask_rows';
  else
    raise EAudio.Create('Unknown companion preparation phase');
  end;
  { Companion counts remain phase-local. They never inflate owned visit totals. }
  ReportWork(FCallback, LStage, wuItems, AWork.Done, AWork.Total);
end;

function TLayerPreparation.SequenceObserver: TWfcSequencePreparationObserver;
begin
  Result := nil;
  if Assigned(FCallback) then
  begin
    Result := ObserveSequence;
  end;
end;

function LayerSequenceObserver(const APreparation: TLayerPreparation): TWfcSequencePreparationObserver;
begin
  Result := nil;
  if APreparation <> nil then
  begin
    Result := APreparation.SequenceObserver();
  end;
end;

procedure VisitLayer(const APreparation: TLayerPreparation); inline;
begin
  if APreparation <> nil then
  begin
    APreparation.Visit;
  end;
end;

procedure LayerCheckpoint(const APreparation: TLayerPreparation);
begin
  if APreparation <> nil then
  begin
    APreparation.Checkpoint;
  end;
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
  const APartitioned: Boolean; var AWork: Int64;
  const APreparation: TLayerPreparation = nil);
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
    VisitLayer(APreparation);
    LMultipliers[LIndex] := 1;
  end;
  for LIndex := 0 to High(ALayer.Preferences) do
  begin
    VisitLayer(APreparation);
    LToken := ALayer.Model.FindPublicToken(ALayer.Preferences[LIndex].Token);
    if (LToken < 0) or (ALayer.Preferences[LIndex].Multiplier < 1) or
      (ALayer.Preferences[LIndex].Multiplier > MaximumLayerPreferenceMultiplier) then
    begin
      raise EAudio.Create('Layer preference requires a known token and multiplier in 1..1024');
    end;
    for LOther := 0 to LIndex - 1 do
    begin
      VisitLayer(APreparation);
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
    VisitLayer(APreparation);
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
  const ACount: Integer; const AExtent: TWfcSequenceExtent;
  const APreparation: TLayerPreparation);
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
    VisitLayer(APreparation);
    SetLength(FValues[LPosition], AModel.StateCount);
    for LState := 0 to AModel.StateCount - 1 do
    begin
      VisitLayer(APreparation);
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

procedure TPositionedLayer.Apply(const APass: TGraph;
  const APreparation: TLayerPreparation);
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
    VisitLayer(APreparation);
    for LState := 0 to FModel.StateCount - 1 do
    begin
      VisitLayer(APreparation);
      APass.AddValue(ValueAt(LPosition, LState), FModel.StateObservationCountAt(LState));
    end;
  end;
  for LPosition := 0 to FCount - 1 do
  begin
    VisitLayer(APreparation);
    for LState := 0 to FModel.StateCount - 1 do
    begin
      VisitLayer(APreparation);
      LRules := nil;
      for LStep := 0 to 1 do
      begin
        VisitLayer(APreparation);
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
            VisitLayer(APreparation);
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
    VisitLayer(APreparation);
    for LState := 0 to FModel.StateCount - 1 do
    begin
      VisitLayer(APreparation);
      if LDeny[LPosition * FModel.StateCount + LState] <> [] then
      begin
        APass.Rules[ValueAt(LPosition, LState)].DenyAll(
          LDeny[LPosition * FModel.StateCount + LState]);
      end;
    end;
  end;
  SetMasks(APass, nil, APreparation);
end;

procedure TPositionedLayer.SetMasks(const APass: TGraph;
  const AMasks: TWfcSequenceTokenConstraints; const APreparation: TLayerPreparation);
var
  LCandidates: array of TGraphValues;
  LPosition: Integer;
  LValue: TGraphValue;
  LState: Integer;
  LMask: Integer;
  LToken: TWfcModelToken;
  LMatch: Boolean;
  LAllowed: Boolean;
begin
  LayerCheckpoint(APreparation);
  ValidateSequenceTokenConstraints(FModel, FCount, AMasks, LayerSequenceObserver(APreparation));
  LayerCheckpoint(APreparation);
  SetLength(LCandidates, FCount);
  for LPosition := 0 to FCount - 1 do
  begin
    VisitLayer(APreparation);
    for LValue in FDomains[LPosition] do
    begin
      VisitLayer(APreparation);
      LState := 0;
      while ValueAt(LPosition, LState) <> LValue do
      begin
        VisitLayer(APreparation);
        Inc(LState);
      end;
      LAllowed := True;
      for LMask := 0 to High(AMasks) do
      begin
        VisitLayer(APreparation);
        if AMasks[LMask].Position <> LPosition then
        begin
          Continue;
        end;
        LMatch := False;
        for LToken in AMasks[LMask].AllowedTokens do
        begin
          VisitLayer(APreparation);
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
    VisitLayer(APreparation);
    APass.SetAllowedValues(LPosition, 0, 0, LCandidates[LPosition]);
  end;
end;

function TPositionedLayer.Capture(const APass: TGraph;
  const APreparation: TLayerPreparation): TWfcGeneratedSequence;
var
  LPosition: Integer;
  LState: Integer;
  LFound: Boolean;
  LReport: TWfcSequenceGraphValidationReport;
  LDomain: TGraphValues;
  LValue: TGraphValue;
  LSequence: TWfcGeneratedSequence;
begin
  LSequence := Default(TWfcGeneratedSequence);
  LSequence.Boundary := FModel.Boundary;
  LSequence.Extent := FExtent;
  SetLength(LSequence.StateIndices, FCount);
  for LPosition := 0 to FCount - 1 do
  begin
    VisitLayer(APreparation);
    LFound := False;
    for LState := 0 to FModel.StateCount - 1 do
    begin
      VisitLayer(APreparation);
      if APass.Entry[LPosition, 0, 0].Value = ValueAt(LPosition, LState) then
      begin
        LSequence.StateIndices[LPosition] := LState;
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
        VisitLayer(APreparation);
        LFound := LFound or (LValue = APass.Entry[LPosition, 0, 0].Value);
      end;
      if not LFound then
      begin
        raise EAudio.Create('Captured positioned layer violates its entry domain');
      end;
    end;
  end;
  if not ValidateSequenceStatePath(FModel, LSequence.StateIndices, FExtent, LReport,
    WfcSequenceWorkObserver(APreparation)) then
  begin
    raise EAudio.Create('Compiled result violates original learned state path');
  end;
  LSequence.Tokens := FModel.ProjectStateIndices(LSequence.StateIndices,
    WfcSequenceWorkObserver(APreparation));
  Result := LSequence;
end;

function CopyVoiceTokenConstraints(const AMask: TWfcSequenceTokenConstraints;
  const AProgress: TWorkProgressCallback;
  const APass: Integer): TWfcSequenceTokenConstraints;
var
  LCandidate: TWfcSequenceTokenConstraints;
  LIndex: Integer;
  LToken: Integer;
  LWork: TWfcObservedWork;
begin
  LWork := TWfcObservedWork.Create(AProgress, 'voice_mask_copy_visits', APass);
  try
    SetLength(LCandidate, Length(AMask));
    for LIndex := 0 to High(AMask) do
    begin
      LCandidate[LIndex].Position := AMask[LIndex].Position;
      SetLength(LCandidate[LIndex].AllowedTokens, Length(AMask[LIndex].AllowedTokens));
      for LToken := 0 to High(AMask[LIndex].AllowedTokens) do
      begin
        LCandidate[LIndex].AllowedTokens[LToken] := AMask[LIndex].AllowedTokens[LToken];
        LWork.Visit;
      end;
      LWork.Visit;
    end;
    LWork.Finish;
    Result := LCandidate;
  finally
    LWork.Free;
  end;
end;

function CopyLayerOptions(const ASource: TLayerGenerationOptions;
  const AWork: TWfcObservedWork = nil): TLayerGenerationOptions;
var
  LIndex: Integer;
begin
  Result := ASource;
  Result.Scopes := Copy(ASource.Scopes);
  Result.TimeGrids := Copy(ASource.TimeGrids);
  for LIndex := 0 to High(Result.TimeGrids) do
  begin
    Result.TimeGrids[LIndex].Boundaries := Copy(ASource.TimeGrids[LIndex].Boundaries);
    if AWork <> nil then AWork.Visit;
  end;
end;

function CopyLayerProjections(const ASource: TLayerProjections;
  const AWork: TWfcObservedWork = nil): TLayerProjections;
var
  LIndex: Integer;
  LRule: Integer;
begin
  Result := nil;
  SetLength(Result, Length(ASource));
  for LIndex := 0 to High(ASource) do
  begin
    Result[LIndex] := ASource[LIndex];
    { Copy detaches the vector before editing its nested token vectors. }
    Result[LIndex].Rules := Copy(ASource[LIndex].Rules);
    for LRule := 0 to High(Result[LIndex].Rules) do
    begin
      Result[LIndex].Rules[LRule].SourceTokens := Copy(ASource[LIndex].Rules[LRule].SourceTokens);
      if AWork <> nil then AWork.Visit;
    end;
    if AWork <> nil then AWork.Visit;
  end;
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

function DescribeLayerGraph(const AGraph: TGraph; const ANames: array of String;
  const AModels: array of TWfcSequenceModel): TLayerGraphPasses;
var
  LIndex: Integer;
  LDependency: Integer;
  LPass: TGraph;
begin
  if (AGraph = nil) or (Length(ANames) <> Length(AModels)) or
    (Length(ANames) > AGraph.TotalPassCount) then
  begin
    raise EAudio.Create('Graph description requires matching actual providers');
  end;
  Result := nil;
  SetLength(Result, AGraph.TotalPassCount);
  for LIndex := 0 to High(Result) do
  begin
    LPass := AGraph.PassGraph[LIndex];
    Result[LIndex].Name := LPass.CurrentPass;
    Result[LIndex].Width := LPass.Dimension.Width;
    Result[LIndex].Height := LPass.Dimension.Height;
    Result[LIndex].Depth := LPass.Dimension.Depth;
    Result[LIndex].IsProof := LIndex >= Length(ANames);
    Result[LIndex].InputSourcePassIndex := -1;
    if not Result[LIndex].IsProof then
    begin
      if AModels[LIndex] = nil then
      begin
        raise EAudio.Create('Graph description requires a provider model');
      end;
      Result[LIndex].Name := ANames[LIndex];
      Result[LIndex].PublicTokenCount := AModels[LIndex].PublicTokenCount;
      Result[LIndex].StateCount := AModels[LIndex].StateCount;
    end;
    SetLength(Result[LIndex].Dependencies, LPass.DependencyCount);
    for LDependency := 0 to LPass.DependencyCount - 1 do
    begin
      Result[LIndex].Dependencies[LDependency] := LPass.DependencyIndex[LDependency];
    end;
  end;
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
  const AOptions: TLayerGenerationOptions; const APosition: Integer;
  const APreparation: TLayerPreparation = nil): TLayerCellIndices;
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
    VisitLayer(APreparation);
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
  const AOptions: TLayerGenerationOptions; const APosition: Integer;
  const APreparation: TLayerPreparation = nil): TLayerCellIndices;
var
  LCoverage: TWfcLatticeCoverage;
  LIndex: Integer;
begin
  if HasTimePartitions(AOptions) then
  begin
    Exit(PartitionCoverage(AProjection, AOptions, APosition, APreparation));
  end;
  LCoverage := ProjectionCoverage(AProjection, AOptions, APosition);
  Result := nil;
  SetLength(Result, WfcLatticeCoverageCellCount(LCoverage));
  for LIndex := 0 to High(Result) do
  begin
    VisitLayer(APreparation);
    Result[LIndex] := WfcLatticeCoverageCell(LCoverage, LIndex).X;
  end;
end;

procedure ValidateMappedRules(const AProjection: TLayerProjection;
  const ALayers: TLearnedLayers; const APreparation: TLayerPreparation = nil);
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
    VisitLayer(APreparation);
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
      VisitLayer(APreparation);
      if ALayers[AProjection.Provider].Model.FindPublicToken(
        AProjection.Rules[LRule].SourceTokens[LAlternative]) < 0 then
      begin
        raise EAudio.Create('Mapped projection has an unknown provider token');
      end;
      for LPrevious := 0 to LAlternative - 1 do
      begin
        VisitLayer(APreparation);
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
  const AProjections: TLayerProjections; const AOptions: TLayerGenerationOptions;
  const APreparation: TLayerPreparation = nil);
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
    VisitLayer(APreparation);
    if ALayers[LIndex].Model = nil then
    begin
      raise EAudio.Create('Layer requires a learned model');
    end;
    LScope := ResolveLayerScope(AOptions, LIndex);
    if LPartitioned then
    begin
      ValidatePreferences(ALayers[LIndex], LScope.CellCount, True, LPreferenceWork, APreparation);
    end
    else
    begin
      ValidatePreferences(ALayers[LIndex], 1, False, LPreferenceWork, APreparation);
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
          VisitLayer(APreparation);
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
    LayerCheckpoint(APreparation);
    ValidateSequenceTokenConstraints(ALayers[LIndex].Model, LScope.CellCount,
      ALayers[LIndex].Constraints, LayerSequenceObserver(APreparation));
    LayerCheckpoint(APreparation);
  end;
  LWork := 0;
  LRules := 0;
  LAlternatives := 0;
  for LIndex := 0 to High(AProjections) do
  begin
    VisitLayer(APreparation);
    LProjection := AProjections[LIndex];
    if (LProjection.Provider < 0) or (LProjection.Consumer >= Length(ALayers)) or
      (LProjection.Provider >= LProjection.Consumer) then
    begin
      raise EAudio.Create('Projection requires an earlier provider and a valid consumer');
    end;
    for LOther := 0 to LIndex - 1 do
    begin
      VisitLayer(APreparation);
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
        VisitLayer(APreparation);
        Inc(LPairs, Length(ProjectionCells(LProjection, AOptions, LPosition, APreparation)));
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
      VisitLayer(APreparation);
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
      ValidateMappedRules(LProjection, ALayers, APreparation);
    end;
  end;
  LPreparation := 0;
  for LIndex := 0 to High(ALayers) do
  begin
    VisitLayer(APreparation);
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
  const ASequences: TLayerSequences; const AOptions: TLayerGenerationOptions;
  const APreparation: TLayerPreparation = nil);
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
    VisitLayer(APreparation);
    for LPosition := 0 to High(ASequences[LProjection.Consumer].Tokens) do
    begin
      VisitLayer(APreparation);
      LCells := ProjectionCells(LProjection, AOptions, LPosition, APreparation);
      for LOrdinal := 0 to High(LCells) do
      begin
        VisitLayer(APreparation);
        LProviderCell := LCells[LOrdinal];
        LFound := False;
        for LRule := 0 to High(LProjection.Rules) do
        begin
          VisitLayer(APreparation);
          if LProjection.Rules[LRule].TargetToken <>
            ASequences[LProjection.Consumer].Tokens[LPosition] then
          begin
            Continue;
          end;
          for LAlternative := 0 to High(LProjection.Rules[LRule].SourceTokens) do
          begin
            VisitLayer(APreparation);
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
  const APass: TGraph; const APreparation: TLayerPreparation = nil): TLayerDomains;
var
  LHadDomain: Boolean;
  LDomain: TGraphValues;
  LToken: Integer;
  LMask: TWfcSequenceTokenConstraints;
begin
  { Resolve latent graph keys only through the public sequence-domain API.
    No private key codec or registration-order assumption belongs here. }
  Result := nil;
  SetLength(Result, AModel.PublicTokenCount);
  LHadDomain := APass.HasAllowedValues(0, 0, 0);
  LDomain := APass.CopyAllowedValues(0, 0, 0);
  SetLength(LMask, 1);
  LMask[0].Position := 0;
  SetLength(LMask[0].AllowedTokens, 1);
  try
    for LToken := 0 to AModel.PublicTokenCount - 1 do
    begin
      VisitLayer(APreparation);
      APass.ClearAllowedValues(0, 0, 0);
      LayerCheckpoint(APreparation);
      LMask[0].AllowedTokens[0] := AModel.PublicTokenAt(LToken);
      IntersectSequenceTokenConstraints(AModel, APass, LMask,
        WfcSequenceWorkObserver(APreparation));
      LayerCheckpoint(APreparation);
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
  const AGraph: TGraph; const AOptions: TLayerGenerationOptions;
  const APreparation: TLayerPreparation);
var
  LLayer: Integer;
  LPreference: TLayerTokenPreference;
  LDomains: TLayerDomains;
  LValue: TGraphValue;
  LState: Integer;
  LPosition: Integer;
  LCapacity: Integer;
  LCount: Integer;
  LPass: TGraph;
  LCompiler: TPositionedLayer;
  procedure AddChange(const AValue: TGraphValue; const AMultiplier: Integer);
  begin
    VisitLayer(APreparation);
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
    VisitLayer(APreparation);
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
    VisitLayer(APreparation);
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
        VisitLayer(APreparation);
        for LState := 0 to ALayers[LLayer].Model.StateCount - 1 do
        begin
          VisitLayer(APreparation);
          if ALayers[LLayer].Model.ProjectStateToken(LState) = LPreference.Token then
          begin
            for LPosition := 0 to ResolveLayerScope(AOptions, LLayer).CellCount - 1 do
            begin
              VisitLayer(APreparation);
              AddChange(LCompiler.ValueAt(LPosition, LState), LPreference.Multiplier);
            end;
          end;
        end;
      end;
    end
    else
    begin
      LDomains := CopyTokenDomains(ALayers[LLayer].Model, LPass, APreparation);
      for LPreference in ALayers[LLayer].Preferences do
      begin
        VisitLayer(APreparation);
        for LValue in LDomains[ALayers[LLayer].Model.FindPublicToken(LPreference.Token)] do
        begin
          AddChange(LValue, LPreference.Multiplier);
        end;
      end;
    end;
  end;
  SetLength(FChanges, LCount);
  UsePreferred(APreparation);
end;

procedure TLayerPreferenceScope.UsePreferred(const APreparation: TLayerPreparation);
var
  LIndex: Integer;
begin
  FApplied := True;
  for LIndex := 0 to High(FChanges) do
  begin
    FChanges[LIndex].Group.Weight := FChanges[LIndex].Preferred;
    VisitLayer(APreparation);
  end;
end;

procedure TLayerPreferenceScope.UseOriginal(const APreparation: TLayerPreparation);
var
  LIndex: Integer;
begin
  for LIndex := 0 to High(FChanges) do
  begin
    FChanges[LIndex].Group.Weight := FChanges[LIndex].Original;
    VisitLayer(APreparation);
  end;
  FApplied := False;
end;

destructor TLayerPreferenceScope.Destroy;
begin
  if FApplied then
  begin
    UseOriginal;
  end;
  inherited Destroy;
end;

constructor TSequencePreferenceScope.Create(const AModel: TWfcSequenceModel;
  const AGraph: TGraph; const APreferences: TLayerTokenPreferences;
  const AProgress: TWorkProgressCallback);
var
  LLayers: TLearnedLayers;
  LOptions: TLayerGenerationOptions;
  LPreparation: TLayerPreparation;
  LWork: Int64;
begin
  inherited Create;
  if (AModel = nil) or (AGraph = nil) then
    raise EAudio.Create('Sequence preferences require a model and private graph');
  LLayers := nil;
  SetLength(LLayers, 1);
  LLayers[0].Model := AModel;
  LLayers[0].Preferences := Copy(APreferences);
  LOptions := DefaultLayerGenerationOptions;
  LOptions.CellCount := AGraph.Dimension.Width;
  LWork := 0;
  LPreparation := TLayerPreparation.Create(AProgress, 'sequence_preference_visits');
  try
    ValidatePreferences(LLayers[0], 1, False, LWork, LPreparation);
    if LWork > MaximumLayerPreferencePreparationWork then
      raise EAudio.Create('Sequence preference preparation exceeds its work budget');
    FInner := TLayerPreferenceScope.Create(LLayers, AGraph, LOptions, LPreparation);
    LPreparation.Finish;
  finally
    LPreparation.Free;
  end;
end;

destructor TSequencePreferenceScope.Destroy;
begin
  FInner.Free;
  inherited Destroy;
end;

procedure TSequencePreferenceScope.UseOriginal(const AProgress: TWorkProgressCallback);
var
  LPreparation: TLayerPreparation;
begin
  LPreparation := TLayerPreparation.Create(AProgress, 'sequence_restore_weight_visits');
  try
    TLayerPreferenceScope(FInner).UseOriginal(LPreparation);
    LPreparation.Finish;
  finally
    LPreparation.Free;
  end;
end;

procedure ApplyMappedProjection(const AProjection: TLayerProjection;
  const ALayers: TLearnedLayers; const AGraph: TGraph;
  const AConsumerDomains, AProviderDomains: TLayerDomains;
  const APreparation: TLayerPreparation = nil);
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
    VisitLayer(APreparation);
    LAllowed := nil;
    for LAlternative := 0 to High(AProjection.Rules[LRule].SourceTokens) do
    begin
      VisitLayer(APreparation);
      LToken := ALayers[AProjection.Provider].Model.FindPublicToken(
        AProjection.Rules[LRule].SourceTokens[LAlternative]);
      LCount := Length(LAllowed);
      SetLength(LAllowed, LCount + Length(AProviderDomains[LToken]));
      for LValue in AProviderDomains[LToken] do
      begin
        VisitLayer(APreparation);
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
      VisitLayer(APreparation);
      AGraph.PassGraph[AProjection.Consumer].Rules[LValue].RequireMappedFromPass(
        LayerName(AProjection.Provider), LQuery);
    end;
  end;
end;

function BuildPositionedGraph(const ALayers: TLearnedLayers;
  const AProjections: TLayerProjections; const AOptions: TLayerGenerationOptions;
  const APreparation: TLayerPreparation = nil): TGraph;
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
      VisitLayer(APreparation);
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
        LScope.CellCount, LScope.Extent, APreparation);
    end;
    LGraph.ConfigurePassLayouts(LLayouts);
    for LIndex := 0 to High(ALayers) do
    begin
      VisitLayer(APreparation);
      LGraph.Compilers[LIndex].Apply(LGraph.PassGraph[LIndex], APreparation);
      LGraph.Compilers[LIndex].SetMasks(LGraph.PassGraph[LIndex], ALayers[LIndex].Constraints, APreparation);
    end;
    for LProjection in AProjections do
    begin
      VisitLayer(APreparation);
      LScope := ResolveLayerScope(AOptions, LProjection.Consumer);
      for LPosition := 0 to LScope.CellCount - 1 do
      begin
        VisitLayer(APreparation);
        LCells := ProjectionCells(LProjection, AOptions, LPosition, APreparation);
        for LRule := 0 to High(LProjection.Rules) do
        begin
          VisitLayer(APreparation);
          for LProviderCell in LCells do
          begin
            VisitLayer(APreparation);
            LAllowed := nil;
            for LSourceState := 0 to ALayers[LProjection.Provider].Model.StateCount - 1 do
            begin
              VisitLayer(APreparation);
              LMatch := False;
              for LAlternative := 0 to High(LProjection.Rules[LRule].SourceTokens) do
              begin
                VisitLayer(APreparation);
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
              VisitLayer(APreparation);
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
  const AProjections: TLayerProjections; const AOptions: TLayerGenerationOptions;
  const APreparation: TLayerPreparation = nil): TGraph;
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
    Exit(BuildPositionedGraph(ALayers, AProjections, AOptions, APreparation));
  end;
  LGraph := TObservedLayerGraph.Create;
  try
    LScope := ResolveLayerScope(AOptions, 0);
    LGraph.Reshape(LScope.CellCount, 1, 1);
    LGraph.WrapNeighbors := LScope.Extent = wseWrap;
    SetLength(LLayouts, Length(ALayers));
    SetLength(LTokenDomains, Length(ALayers));
    LGraph.Seed := AOptions.Seed;
    for LIndex := 0 to High(ALayers) do
    begin
      VisitLayer(APreparation);
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
      VisitLayer(APreparation);
      LGraph.SwitchToPass(LayerName(LIndex));
      LScope := ResolveLayerScope(AOptions, LIndex);
      LayerCheckpoint(APreparation);
      ApplySequenceModelToGraph(ALayers[LIndex].Model, LGraph, LScope.Extent);
      LayerCheckpoint(APreparation);
      IntersectSequenceTokenConstraints(ALayers[LIndex].Model, LGraph,
        ALayers[LIndex].Constraints, LayerSequenceObserver(APreparation));
      LayerCheckpoint(APreparation);
    end;
    for LIndex := 0 to High(ALayers) do
    begin
      VisitLayer(APreparation);
      LGraph.SwitchToPass(LayerName(LIndex));
      LBindings := nil;
      for LOther := 0 to High(AProjections) do
      begin
        VisitLayer(APreparation);
        if AProjections[LOther].Consumer = LIndex then
        begin
          if AProjections[LOther].TimeMapping <> ltmCellIndex then
          begin
            LProvider := AProjections[LOther].Provider;
            if Length(LTokenDomains[LIndex]) = 0 then
            begin
              LTokenDomains[LIndex] := CopyTokenDomains(ALayers[LIndex].Model,
                LGraph.PassGraph[LIndex], APreparation);
            end;
            if Length(LTokenDomains[LProvider]) = 0 then
            begin
              LTokenDomains[LProvider] := CopyTokenDomains(ALayers[LProvider].Model,
                LGraph.PassGraph[LProvider], APreparation);
            end;
            ApplyMappedProjection(AProjections[LOther], ALayers, LGraph,
              LTokenDomains[LIndex], LTokenDomains[LProvider], APreparation);
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
      LayerCheckpoint(APreparation);
        RequireSequenceProjectionMapsFromPasses(ALayers[LIndex].Model, LGraph, LBindings);
      LayerCheckpoint(APreparation);
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
  const AGraph: TGraph; const AProgress: TWorkProgressCallback = nil): TLayerSequences;
var
  LSequences: TLayerSequences;
  LIndex: Integer;
  LValidation: TWfcSequenceGraphValidationReport;
  LFalsePosition: Integer;
  LPreparation: TLayerPreparation;
begin
  SetLength(LSequences, Length(ALayers));
  for LIndex := 0 to High(ALayers) do
  begin
    LPreparation := TLayerPreparation.Create(AProgress, 'layer_capture_visits', LIndex + 1);
    try
      VisitLayer(LPreparation);
      if AGraph is TPositionedLayerGraph then
      begin
        LSequences[LIndex] := TPositionedLayerGraph(AGraph).Compilers[LIndex].Capture(
          AGraph.PassGraph[LIndex], LPreparation);
      end
      else
      begin
        if not CaptureSolvedSequence(ALayers[LIndex].Model, AGraph.PassGraph[LIndex],
          ResolveLayerScope(AOptions, LIndex).Extent, LSequences[LIndex], LValidation,
          WfcSequenceWorkObserver(LPreparation)) then
        begin
          raise EAudio.Create('Captured layer failed actual WFC path validation');
        end;
        if not SequenceStatesSatisfyEntryConstraints(ALayers[LIndex].Model,
          AGraph.PassGraph[LIndex], LSequences[LIndex].StateIndices, LFalsePosition,
          WfcSequenceWorkObserver(LPreparation)) then
        begin
          raise EAudio.Create('Captured layer violates position constraints');
        end;
      end;
      LPreparation.Finish;
    finally
      LPreparation.Free;
    end;
  end;
  LPreparation := TLayerPreparation.Create(AProgress, 'layer_relation_visits');
  try
    ValidateCapturedRelations(AProjections, LSequences, AOptions, LPreparation);
    LPreparation.Finish;
  finally
    LPreparation.Free;
  end;
  ReportWork(AProgress, 'layer_capture_ready', wuItems, 1, 1);
  Result := LSequences;
end;

function NegotiationOptions(const AOptions: TLayerGenerationOptions): TGraphNegotiationOptions;
begin
  Result := DefaultGraphNegotiationOptions;
  Result.SolveOptions.MaxBacktracks := AOptions.MaxBacktracks;
  Result.MaxPassBacktracks := AOptions.MaxPassBacktracks;
end;

function CopyLayerSequences(const ASource: TLayerSequences;
  const AProgress: TWorkProgressCallback): TLayerSequences;
var
  LCandidate: TLayerSequences;
  LLayer: Integer;
  LCell: Integer;
  LPreparation: TLayerPreparation;
begin
  LPreparation := TLayerPreparation.Create(AProgress, 'layer_clone_visits');
  try
    SetLength(LCandidate, Length(ASource));
    for LLayer := 0 to High(ASource) do
    begin
      LPreparation.Visit;
      LCandidate[LLayer].Boundary := ASource[LLayer].Boundary;
      LCandidate[LLayer].Extent := ASource[LLayer].Extent;
      SetLength(LCandidate[LLayer].Tokens, Length(ASource[LLayer].Tokens));
      for LCell := 0 to High(ASource[LLayer].Tokens) do
      begin
        LCandidate[LLayer].Tokens[LCell] := ASource[LLayer].Tokens[LCell];
        LPreparation.Visit;
      end;
      SetLength(LCandidate[LLayer].StateIndices, Length(ASource[LLayer].StateIndices));
      for LCell := 0 to High(ASource[LLayer].StateIndices) do
      begin
        LCandidate[LLayer].StateIndices[LCell] := ASource[LLayer].StateIndices[LCell];
        LPreparation.Visit;
      end;
    end;
    LPreparation.Finish;
    Result := LCandidate;
  finally
    LPreparation.Free;
  end;
end;

constructor TLayerPublication.Create(const ALayers: TLearnedLayers;
  const AProjections: TLayerProjections; const AGraph: TGraph;
  const AOptions: TLayerGenerationOptions; const ADetachedCaller,
  AGuardedCapture: Boolean; const AProgress: TWorkProgressCallback);
var
  LPreparation: TLayerPreparation;
begin
  inherited Create;
  if not (AGraph is TObservedLayerGraph) then
  begin
    raise EAudio.Create('Layer publication requires its owned commit graph');
  end;
  FGraph := TObservedLayerGraph(AGraph);
  if FGraph.Publication <> nil then
  begin
    raise EAudio.Create('Layer publication cannot be re-entered');
  end;
  FLayers := ALayers;
  FProjections := AProjections;
  FOptions := AOptions;
  FCallback := AProgress;
  FDetachedCaller := ADetachedCaller;
  FGuardedCapture := AGuardedCapture;
  LPreparation := TLayerPreparation.Create(AProgress, 'layer_weight_visits');
  try
    FPreferences := TLayerPreferenceScope.Create(ALayers, AGraph, AOptions, LPreparation);
    LPreparation.Finish;
  finally
    LPreparation.Free;
  end;
  FGraph.Publication := Self;
end;

destructor TLayerPublication.Destroy;
begin
  if (FGraph <> nil) and (FGraph.Publication = Self) then
  begin
    FGraph.Publication := nil;
  end;
  FPreferences.Free;
  inherited Destroy;
end;

procedure TLayerPublication.Capture;
var
  LPreparation: TLayerPreparation;
begin
  if not FGuardedCapture then
  begin
    Exit;
  end;
  LPreparation := nil;
  try
    { Model identity includes original weights. Restore only for proof; a
      rejected negotiated attempt must resume with the same preferences. }
    LPreparation := TLayerPreparation.Create(FCallback, 'layer_capture_weight_visits');
    FPreferences.UseOriginal(LPreparation);
    LPreparation.Finish;
    Captured := CaptureLayers(FLayers, FProjections, FOptions, FGraph, FCallback);
    if FDetachedCaller then
    begin
      CallerCopy := CopyLayerSequences(Captured, FCallback);
    end
    else
    begin
      CallerCopy := Captured;
    end;
    ReportWork(FCallback, 'layer_publication_ready', wuItems, 1, 1);
  finally
    FPreferences.UsePreferred;
    LPreparation.Free;
  end;
end;

function TObservedLayerGraph.DoValidateCommit(out AFailedPassIndex,
  AFailedEntryIndex: Integer): Boolean;
begin
  Result := inherited DoValidateCommit(AFailedPassIndex, AFailedEntryIndex);
  if Result and (Publication <> nil) then
  begin
    Publication.Capture;
  end;
end;

function SolvePreferredLayers(const ALayers: TLearnedLayers;
  const AProjections: TLayerProjections; const AGraph: TGraph;
  const AOptions: TLayerGenerationOptions; out AReport: TGraphNegotiationReport;
  out ACaptured, APublished: TLayerSequences; const ADetachedCaller,
  AGuardedCapture: Boolean; const AProgress: TWorkProgressCallback;
  const APreparation: TLayerPreparation = nil): Boolean;
var
  LPublication: TLayerPublication;
begin
  LPublication := TLayerPublication.Create(ALayers, AProjections, AGraph, AOptions,
    ADetachedCaller, AGuardedCapture, AProgress);
  try
    Result := AGraph.TrySolveNegotiated(NegotiationOptions(AOptions), AReport,
      WfcSolveObserver(APreparation));
    if Result then
    begin
      ACaptured := LPublication.Captured;
      APublished := LPublication.CallerCopy;
    end;
  finally
    LPublication.Free;
  end;
end;

function TryGenerateLayers(const ALayers: TLearnedLayers;
  const AProjections: TLayerProjections; const AOptions: TLayerGenerationOptions;
  var ASequences: TLayerSequences; out AReport: TGraphNegotiationReport;
  const AProgress: TWorkProgressCallback): Boolean;
var
  LGraph: TGraph;
  LPreparation: TLayerPreparation;
  LCaptured: TLayerSequences;
  LPublished: TLayerSequences;
begin
  AReport := Default(TGraphNegotiationReport);
  LGraph := nil;
  LPreparation := TLayerPreparation.Create(AProgress, 'layer_prepare_visits');
  try
    ValidateRequest(ALayers, AProjections, AOptions, LPreparation);
    LGraph := BuildLayerGraph(ALayers, AProjections, AOptions, LPreparation);
    { This phase covers preparation. Solving/capture have their own audit;
      its final total does not mean that generation or publication succeeded. }
    LPreparation.Finish;
    Result := SolvePreferredLayers(ALayers, AProjections, LGraph, AOptions,
      AReport, LCaptured, LPublished, False, True, AProgress, LPreparation);
    if Result then
    begin
      ASequences := LPublished;
    end;
  finally
    LGraph.Free;
    LPreparation.Free;
  end;
end;

constructor TLearnedLayerSession.Create(const ALayers: TLearnedLayers;
  const AProjections: TLayerProjections; const ANames: TLayerNames;
  const AOptions: TLayerGenerationOptions; const AProgress: TWorkProgressCallback);
var
  LIndex: Integer;
  LOther: Integer;
  LCell: Integer;
  LPass: TGraph;
  LScope: TLayerScope;
  LPreparation: TLayerPreparation;
begin
  inherited Create;
  LPreparation := TLayerPreparation.Create(AProgress, 'layer_prepare_visits');
  try
    ValidateRequest(ALayers, AProjections, AOptions, LPreparation);
    if Length(ANames) <> Length(ALayers) then
    begin
      raise EAudio.Create('Session requires one unique name per layer');
    end;
    for LIndex := 0 to High(ANames) do
    begin
      LPreparation.Visit;
      if (Length(ANames[LIndex]) < 1) or (Length(ANames[LIndex]) > 128) or
        (Trim(ANames[LIndex]) <> ANames[LIndex]) then
      begin
        raise EAudio.Create('Layer names must contain 1..128 characters without surrounding spaces');
      end;
      for LOther := 1 to Length(ANames[LIndex]) do
      begin
        LPreparation.Visit;
        if Ord(ANames[LIndex][LOther]) < 32 then
        begin
          raise EAudio.Create('Layer names cannot contain control characters');
        end;
      end;
      for LOther := 0 to LIndex - 1 do
      begin
        LPreparation.Visit;
        if ANames[LOther] = ANames[LIndex] then
        begin
          raise EAudio.Create('Duplicate session layer name');
        end;
      end;
    end;
    FOptions := CopyLayerOptions(AOptions, LPreparation);
    FNames := Copy(ANames);
    SetLength(FLayers, Length(ALayers));
    SetLength(FDirty, Length(ALayers));
    SetLength(FBaseline, Length(ALayers));
    SetLength(FHasBaseline, Length(ALayers));
    for LIndex := 0 to High(ALayers) do
    begin
      LPreparation.Visit;
      LPreparation.Checkpoint;
      FLayers[LIndex].Model := CloneWfcSequenceModel(ALayers[LIndex].Model, AProgress);
      LPreparation.Checkpoint;
      FLayers[LIndex].Preferences := Copy(ALayers[LIndex].Preferences);
    end;
    FProjections := CopyLayerProjections(AProjections, LPreparation);
    { Capture model/extent domains before adding caller masks. Clearing a mask
      must restore endpoint restrictions as well as the full token vocabulary. }
    FGraph := BuildLayerGraph(FLayers, FProjections, FOptions, LPreparation);
    for LIndex := 0 to High(FLayers) do
    begin
      LPreparation.Visit;
      LPass := FGraph.PassGraph[LIndex];
      LScope := ResolveLayerScope(FOptions, LIndex);
      SetLength(FBaseline[LIndex], LScope.CellCount);
      SetLength(FHasBaseline[LIndex], LScope.CellCount);
      for LCell := 0 to LScope.CellCount - 1 do
      begin
        LPreparation.Visit;
        FHasBaseline[LIndex][LCell] := LPass.HasAllowedValues(LCell, 0, 0);
        FBaseline[LIndex][LCell] := LPass.CopyAllowedValues(LCell, 0, 0);
      end;
      SetConstraints(FNames[LIndex], ALayers[LIndex].Constraints, AProgress);
    end;
    LPreparation.Finish;
  finally
    LPreparation.Free;
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
  const AConstraints: TWfcSequenceTokenConstraints; const AProgress: TWorkProgressCallback);
var
  LIndex: Integer;
  LCell: Integer;
  LPass: TGraph;
  LScope: TLayerScope;
  LPrevious: TLayerDomains;
  LHadPrevious: TLayerDomainFlags;
  LConstraints: TWfcSequenceTokenConstraints;
  LPreparation: TLayerPreparation;
begin
  CheckSnapshotIdle;
  LPreparation := TLayerPreparation.Create(AProgress, 'layer_constraint_visits');
  try
    LIndex := LayerIndex(AName);
    LScope := ResolveLayerScope(FOptions, LIndex);
    if Length(AConstraints) > LScope.CellCount then
    begin
      raise EAudio.Create('Layer has too many position constraints');
    end;
    LPreparation.Checkpoint;
    ValidateSequenceTokenConstraints(FLayers[LIndex].Model, LScope.CellCount,
      AConstraints, LPreparation.SequenceObserver());
    LPreparation.Checkpoint;
    LConstraints := CopyVoiceTokenConstraints(AConstraints, AProgress, LIndex + 1);
    LPass := FGraph.PassGraph[LIndex];
    SetLength(LPrevious, LScope.CellCount);
    SetLength(LHadPrevious, LScope.CellCount);
    for LCell := 0 to LScope.CellCount - 1 do
    begin
      LPreparation.Visit;
      LHadPrevious[LCell] := LPass.HasAllowedValues(LCell, 0, 0);
      LPrevious[LCell] := LPass.CopyAllowedValues(LCell, 0, 0);
    end;
    try
      for LCell := 0 to LScope.CellCount - 1 do
      begin
        LPreparation.Visit;
        LPass.ClearAllowedValues(LCell, 0, 0);
        if FHasBaseline[LIndex][LCell] then
        begin
          LPass.SetAllowedValues(LCell, 0, 0, FBaseline[LIndex][LCell]);
        end;
      end;
      if FGraph is TPositionedLayerGraph then
      begin
        TPositionedLayerGraph(FGraph).Compilers[LIndex].SetMasks(LPass, AConstraints, LPreparation);
      end
      else
      begin
        LPreparation.Checkpoint;
        IntersectSequenceTokenConstraints(FLayers[LIndex].Model, LPass, AConstraints,
          LPreparation.SequenceObserver());
        LPreparation.Checkpoint;
      end;
      { Include the final observer call in rollback, before pending-mask publication. }
      LPreparation.Finish;
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
  finally
    LPreparation.Free;
  end;
end;

procedure TLearnedLayerSession.SetPreferences(const AName: String;
  const APreferences: TLayerTokenPreferences; const AProgress: TWorkProgressCallback);
var
  LIndex: Integer;
  LRequested: TLearnedLayers;
  LPreparation: TLayerPreparation;
begin
  CheckSnapshotIdle;
  LPreparation := TLayerPreparation.Create(AProgress, 'layer_preference_visits');
  try
    LIndex := LayerIndex(AName);
    LRequested := Copy(FLayers);
    LRequested[LIndex].Preferences := Copy(APreferences);
    ValidateRequest(LRequested, FProjections, FOptions, LPreparation);
    LPreparation.Finish;
    FLayers[LIndex].Preferences := LRequested[LIndex].Preferences;
    FDirty[LIndex] := True;
  finally
    LPreparation.Free;
  end;
end;

function TLearnedLayerSession.CopyPreferences(const AName: String): TLayerTokenPreferences;
begin
  Result := Copy(FLayers[LayerIndex(AName)].Preferences);
end;

procedure TLearnedLayerSession.AcceptSolved(const APrepared: TLayerSequences);
var
  LIndex: Integer;
begin
  FAccepted := APrepared;
  for LIndex := 0 to High(FDirty) do
  begin
    FDirty[LIndex] := False;
  end;
end;

function TLearnedLayerSession.CopyGraph: TLayerGraphPasses;
var
  LModels: array of TWfcSequenceModel;
  LIndex: Integer;
begin
  SetLength(LModels, Length(FLayers));
  for LIndex := 0 to High(LModels) do
  begin
    LModels[LIndex] := FLayers[LIndex].Model;
  end;
  Result := DescribeLayerGraph(FGraph, FNames, LModels);
end;

function TLearnedLayerSession.CopyModel(const AName: String;
  const AProgress: TWorkProgressCallback): TWfcSequenceModel;
begin
  Result := CloneWfcSequenceModel(FLayers[LayerIndex(AName)].Model, AProgress);
end;

function TLearnedLayerSession.CopyAccepted(
  const AProgress: TWorkProgressCallback): TLayerSequences;
begin
  Result := CopyLayerSequences(FAccepted, AProgress);
end;

procedure TLearnedLayerSession.CheckSnapshotIdle;
begin
  if FSnapshotBusy then raise EAudio.Create('Layer snapshot operation cannot be reentered');
end;

function TLearnedLayerSession.CopyAcceptedSnapshot(
  const AProgress: TWorkProgressCallback): TLayerAcceptedSnapshot;
var
  LIndex: Integer;
  LWork: TWfcObservedWork;
  LBridge: TWfcSolveProgressBridge;
  LTextUnits: Integer;
begin
  CheckSnapshotIdle;
  if Length(FAccepted) = 0 then raise EAudio.Create('Layer snapshot requires an accepted session');
  for LIndex := 0 to High(FDirty) do
    if FDirty[LIndex] then raise EAudio.Create('Layer snapshot requires no pending edits');
  Result := Default(TLayerAcceptedSnapshot);
  LWork := nil;
  LBridge := nil;
  FSnapshotBusy := True;
  try
    LWork := TWfcObservedWork.Create(AProgress, 'layer_snapshot_copy');
    Result.Version := 1;
    Result.Options := CopyLayerOptions(FOptions, LWork);
    Result.Names := Copy(FNames);
    Result.Projections := CopyLayerProjections(FProjections, LWork);
    SetLength(Result.Layers, Length(FLayers));
    SetLength(Result.Models, Length(FLayers));
    LTextUnits := 0;
    for LIndex := 0 to High(FLayers) do
    begin
      Result.Models[LIndex] := EncodeWfcSequenceText(FLayers[LIndex].Model);
      if Length(Result.Models[LIndex]) > MaximumSessionSnapshotTextUnits - LTextUnits then
        raise EAudio.Create('Layer snapshot model text exceeds its budget');
      Inc(LTextUnits, Length(Result.Models[LIndex]));
      Result.Layers[LIndex].Constraints := CopyVoiceTokenConstraints(
        FLayers[LIndex].Constraints, AProgress, LIndex + 1);
      Result.Layers[LIndex].Preferences := Copy(FLayers[LIndex].Preferences);
      LWork.Visit;
    end;
    LBridge := TWfcSolveProgressBridge.Create(AProgress);
    Result.Assignments := FGraph.CaptureAssignments(MaximumLayerStateCells,
      MaximumSessionSnapshotTextUnits, LBridge.SolveObserver());
    LWork.Finish;
    ReportWork(AProgress, 'layer_snapshot_ready', wuItems, 1, 1);
  finally
    LBridge.Free;
    LWork.Free;
    FSnapshotBusy := False;
  end;
end;

class function TLearnedLayerSession.FromAcceptedSnapshot(
  const ASnapshot: TLayerAcceptedSnapshot;
  const AProgress: TWorkProgressCallback): TLearnedLayerSession;
var
  LLayers: TLearnedLayers;
  LCandidate: TLearnedLayerSession;
  LBridge: TWfcSolveProgressBridge;
  LIndex: Integer;
  LTextUnits: Integer;
  LCaptured: TLayerSequences;
begin
  Result := nil;
  if (ASnapshot.Version <> 1) or (Length(ASnapshot.Layers) < 1) or
    (Length(ASnapshot.Layers) > MaximumLearnedLayers) or
    (Length(ASnapshot.Models) <> Length(ASnapshot.Layers)) or
    (Length(ASnapshot.Names) <> Length(ASnapshot.Layers)) then
    raise EAudio.Create('Layer snapshot version or provider counts differ');
  LTextUnits := 0;
  for LIndex := 0 to High(ASnapshot.Models) do
  begin
    if (ASnapshot.Layers[LIndex].Model <> nil) or
      (Length(ASnapshot.Models[LIndex]) > MaximumSessionSnapshotTextUnits - LTextUnits) then
      raise EAudio.Create('Layer snapshots require bounded model text without borrowed model pointers');
    Inc(LTextUnits, Length(ASnapshot.Models[LIndex]));
  end;
  LLayers := Copy(ASnapshot.Layers);
  LCandidate := nil;
  LBridge := nil;
  try
    for LIndex := 0 to High(LLayers) do
    begin
      ReportWork(AProgress, 'layer_snapshot_models', wuItems, LIndex, Length(LLayers));
      LLayers[LIndex].Model := DecodeWfcSequenceText(ASnapshot.Models[LIndex]);
    end;
    LCandidate := TLearnedLayerSession.Create(LLayers, ASnapshot.Projections,
      ASnapshot.Names, ASnapshot.Options, AProgress);
    LBridge := TWfcSolveProgressBridge.Create(AProgress);
    LCandidate.FGraph.RestoreAssignments(ASnapshot.Assignments, MaximumLayerStateCells,
      MaximumSessionSnapshotTextUnits, LBridge.SolveObserver());
    LCaptured := CaptureLayers(LCandidate.FLayers, LCandidate.FProjections,
      LCandidate.FOptions, LCandidate.FGraph, AProgress);
    LCandidate.AcceptSolved(LCaptured);
    ReportWork(AProgress, 'layer_snapshot_restored', wuItems, 1, 1);
    Result := LCandidate;
    LCandidate := nil;
  finally
    LBridge.Free;
    LCandidate.Free;
    for LIndex := 0 to High(LLayers) do LLayers[LIndex].Model.Free;
  end;
end;

function TLearnedLayerSession.TryGenerate(var ASequences: TLayerSequences;
  out AReport: TGraphNegotiationReport;
  const AProgress: TWorkProgressCallback): Boolean;
var
  LPreparation: TLayerPreparation;
  LCaptured: TLayerSequences;
  LPublished: TLayerSequences;
begin
  AReport := Default(TGraphNegotiationReport);
  if Length(FAccepted) <> 0 then
  begin
    raise EAudio.Create('Session already has accepted results; use selective regeneration');
  end;
  LPreparation := TLayerPreparation.Create(AProgress, 'layer_generate_visits');
  try
    Result := SolvePreferredLayers(FLayers, FProjections, FGraph, FOptions,
      AReport, LCaptured, LPublished, True, True, AProgress, LPreparation);
    if Result then
    begin
      AcceptSolved(LCaptured);
      ASequences := LPublished;
    end;
  finally
    LPreparation.Free;
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
  CheckSnapshotIdle;
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
  out AReport: TGraphSelectiveNegotiationReport;
  const AProgress: TWorkProgressCallback): Boolean;
var
  LLabels: TGraphPassLabels;
  LPublication: TLayerPublication;
  LPreparation: TLayerPreparation;
begin
  AReport := Default(TGraphSelectiveNegotiationReport);
  LPreparation := TLayerPreparation.Create(AProgress, 'layer_regenerate_visits');
  try
    LLabels := RegenerationRoots(ARoots);
    FGraph.Seed := ASeed;
    LPublication := TLayerPublication.Create(FLayers, FProjections, FGraph,
      FOptions, True, True, AProgress);
    try
      Result := FGraph.TryRegenerateNegotiatedFrom(LLabels, NegotiationOptions(FOptions),
        AReport, LPreparation.SolveObserver());
      if Result then
      begin
        AcceptSolved(LPublication.Captured);
        ASequences := LPublication.CallerCopy;
      end;
    finally
      LPublication.Free;
    end;
  finally
    LPreparation.Free;
  end;
end;

function TLearnedLayerSession.TryReplaceModel(const AName: String;
  const AModel: TWfcSequenceModel; const ASeed: TGraphSeed;
  var ASequences: TLayerSequences; out AReport: TLayerModelReplacementReport;
  const AProgress: TWorkProgressCallback): Boolean;
var
  LLabels: TGraphPassLabels;
  LRequested: TLearnedLayers;
  LCandidate: TLearnedLayerSession;
  LAffected: TLayerDomainFlags;
  LPublished: TLayerSequences;
  LCaptured: TLayerSequences;
  LOldGraph: TGraph;
  LOldLayers: TLearnedLayers;
  LIndex: Integer;
  LCell: Integer;
  LPreparation: TLayerPreparation;
begin
  AReport := Default(TLayerModelReplacementReport);
  AReport.ReplacedLayerIndex := -1;
  LPreparation := TLayerPreparation.Create(AProgress, 'layer_replace_visits');
  try
    LLabels := RegenerationRoots([AName]);
    LIndex := LayerIndex(AName);
    AReport.ReplacedLayerIndex := LIndex;
    LRequested := Copy(FLayers);
    LRequested[LIndex].Model := AModel;
    { Constructor validates all existing masks/relations against the replacement
      and detaches every input. No accepted state is mutated before publication. }
    LCandidate := TLearnedLayerSession.Create(LRequested, FProjections, FNames, FOptions, AProgress);
    try
      LCandidate.FGraph.ResolveRegenerationScope(LLabels, AReport.RootLayerIndices,
        AReport.AffectedLayerIndices);
      SetLength(LAffected, Length(FLayers));
      for LIndex in AReport.AffectedLayerIndices do
      begin
        LPreparation.Visit;
        LAffected[LIndex] := True;
      end;
      for LIndex := 0 to High(FLayers) do
      begin
        LPreparation.Visit;
        if LAffected[LIndex] then
        begin
          Continue;
        end;
        SetLength(AReport.PreservedLayerIndices, Length(AReport.PreservedLayerIndices) + 1);
        AReport.PreservedLayerIndices[High(AReport.PreservedLayerIndices)] := LIndex;
        for LCell := 0 to High(FAccepted[LIndex].StateIndices) do
        begin
          LPreparation.Visit;
          { Identical cloned models use identical state keys. Restrict domains,
            not entry Value: caller-pinned entries would obstruct later edits. }
          LCandidate.FGraph.PassGraph[LIndex].SetAllowedValues(LCell, 0, 0,
            [FGraph.PassGraph[LIndex].Entry[LCell, 0, 0].Value]);
        end;
      end;
      LCandidate.FGraph.Seed := ASeed;
      Result := SolvePreferredLayers(LCandidate.FLayers, FProjections,
        LCandidate.FGraph, FOptions, AReport.Search, LCaptured, LPublished,
        False, False, AProgress, LPreparation);
      if not Result then
      begin
        Exit;
      end;
      for LIndex in AReport.PreservedLayerIndices do
      begin
        { Restore original domains before capture and future selective solving. }
        LCandidate.SetConstraints(FNames[LIndex], FLayers[LIndex].Constraints, AProgress);
      end;
      LCandidate.AcceptSolved(CaptureLayers(LCandidate.FLayers, FProjections,
        FOptions, LCandidate.FGraph, AProgress));
      for LIndex in AReport.PreservedLayerIndices do
      begin
        for LCell := 0 to High(FAccepted[LIndex].StateIndices) do
        begin
          LPreparation.Visit;
          if (LCandidate.FAccepted[LIndex].StateIndices[LCell] <>
            FAccepted[LIndex].StateIndices[LCell]) or
            (LCandidate.FAccepted[LIndex].Tokens[LCell] <> FAccepted[LIndex].Tokens[LCell]) then
          begin
            raise EAudio.Create('Model replacement changed an independent accepted layer');
          end;
        end;
      end;
      LPreparation.Finish;
      LPublished := LCandidate.CopyAccepted(AProgress);
      ReportWork(AProgress, 'layer_publication_ready', wuItems, 1, 1);
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
  finally
    LPreparation.Free;
  end;
end;

end.
