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
unit pythian.wfc.instrumental.stream;

{$mode delphi}
{$H+}

interface

uses pythian.audio, pythian.time, pythian.progress, pythian.bus, pythian.chord,
  pythian.music.decisions, pythian.music.form,
  pythian.music.controls,
  pythian.percussion, pythian.music.stream, pythian.wfc.instrumental,
  pythian.wfc.percussion, pythian.wfc.stream, pythian.wfc.voices,
  pythian.wfc.layers, wfc, wfc_model, wfc_sequence,
  wfc_sequence_graph, wfc_music_ensemble, wfc_music_voices_graph,
  wfc_music_voices_stream;

const
  InstrumentalStreamVersion = 5;

type
  { Borrowed immutable authored/caller domain source. Positions in returned
    masks are local to this bounded request. The source must outlive the stream;
    its decisions cannot change or reenter the producer during generation. }
  TInstrumentalDomainProvider = function(const AFirstCell: Int64;
    const ACellCount: Integer): TVoiceMasks of object;
  TInstrumentalTokenStreams = array of TWfcModelTokens;
  TInstrumentalContextBinding = (icbDrivenRole, icbAllRoles);
  TInstrumentalStreamOptions = record
    MusicFrames: Int64;
    TailFrames: Int64;
    TicksPerQuarter: Integer;
    StepTicks: Integer;
    TempoMicroseconds: Integer;
    SegmentCells: Integer;
    Seed: TGraphSeed;
    MaxBacktracks: Integer;
    MaxPassBacktracks: Integer;
    VoiceLimit: Integer;
    WorkLimit: Integer;
    ContextBinding: TInstrumentalContextBinding;
  end;

  { Big Boss: context, pitched roles and percussion share one primary WFC
    transaction, validated future window and prefix frontier. Musical maps stay
    in Pythian; the companion owns negotiation and independent sequence proof.
    Borrows immutable models, pitched instruments and the matching exclusive bus
    graph. Owns percussion recipes and one persistent scheduler/effect stream.
    Plan failures and cancellation are terminal. Source PCM is not performed.
    Seed, model order, segmentation, tempo and sound recipes define replay. }
  TInstrumentalMusicStream = class
  private
    FOptions: TInstrumentalStreamOptions;
    FConfig: TWfcMusicVoicesGraphConfig;
    FVoices: TWfcMusicVoicesStream;
    FContextIndex: Integer;
    FContextLookaheadCells: Integer;
    FVoiceLookaheadCells: Integer;
    FLastVoicePlanningCells: Integer;
    FFormBoundCells: Int64;
    FDomainBoundCells: Int64;
    FDomainProvider: TInstrumentalDomainProvider;
    FForm: TMusicFormCursor;
    FHasExpression: Boolean;
    FHasDensity: Boolean;
    FProviderPreferences: TVoicePreferences;
    FExpression: TMusicalExpressions;
    FDensityProfiles: array of TObject;
    FVoiceProgress: TWorkProgressCallback;
    FDrumModelIndices: array of Integer;
    FDrums: array of TPercussionInstrument;
    FDefinitions: TPercussionDefinitions;
    FMusic: TInstrumentMusicStream;
    FClock: TIncrementalTempoClock;
    FFrames: TWfcMusicEnsembleFrames;
    FDecisions: TMusicDecisionChunk;
    FPreviousDecision: TChordFrame;
    FRoleNames: TMusicDecisionTokens;
    FDecisionSink: TMusicDecisionSink;
    FCell: Integer;
    FCells: Int64;
    FTotalCells: Int64;
    FSegments: Int64;
    FPercussionHits: Int64;
    FBusy: Boolean;
    FFailed: Boolean;
    procedure RequireIdle;
    function DensityRows(const AProvider: Integer; const AFirstCell: Int64;
      const ACellCount: Integer; const AProgress: TWorkProgressCallback): TLayerPositionPreferences;
    procedure ConfigureVoiceDensity(const AStartTick: Int64;
      const ACellCount: Integer; const AGraph: TGraph);
    procedure PlanSegment(const AProgress: TWorkProgressCallback);
    procedure AdmitCell(const AProgress: TWorkProgressCallback);
    function FormProviderIndex(const AKey: String): Integer;
    function GetPosition: Int64;
    function GetFrameCount: Int64;
    function GetState: TInstrumentStreamState;
    function GetPeakVoices: Integer;
    function GetPlannedCells: Int64;
  public
    constructor Create(const AConfig: TWfcMusicVoicesGraphConfig;
      const ARoles: TInstrumentalRoles; const APercussion: TPercussionDefinitions;
      const AGraph: TBusGraph; const AOptions: TInstrumentalStreamOptions;
      const AContext: TWfcSequenceModel = nil;
      const ADecisionSink: TMusicDecisionSink = nil;
      const AForm: TMusicForm = nil;
      const ADomainProvider: TInstrumentalDomainProvider = nil;
      { Detached global controls in actual composed model order: H/R/roles,
        optional context, then drums/other auxiliaries. Empty vectors mean none.
        Expression follows performed part order. Gate editing remains unsupported
        here and rejects rather than silently changing the held-note clock. }
      const AMasks: TVoiceMasks = nil;
      const APreferences: TVoicePreferences = nil;
      const AExpression: TMusicalExpressions = nil);
    destructor Destroy; override;
    function ReadSamples(const AMaximumFrames: Integer; out ASamples: TAudioSamples;
      const AProgress: TWorkProgressCallback = nil): Boolean;
    function ReadOutputs(const AMaximumFrames: Integer; const AOutputBuses: array of Integer;
      out ASamples: TAudioSamples; out AOutputs: TBusSampleBlocks;
      const AProgress: TWorkProgressCallback = nil): Boolean;
    procedure Pause;
    procedure Resume;
    procedure Stop;
    { Sparse constraints apply only beyond the already planned lookahead.
      Indices: harmony0, rhythm1, then ordered pitched roles. }
    procedure IntersectFutureTokens(const AProvider: Integer; const ACell: Int64;
      const ATokens: TWfcModelTokens);
    function CopyLastFrames: TWfcMusicEnsembleFrames;
    function CopyLastDecisions: TMusicDecisionChunk;
    property Position: Int64 read GetPosition;
    property FrameCount: Int64 read GetFrameCount;
    property State: TInstrumentStreamState read GetState;
    property PlannedCells: Int64 read GetPlannedCells;
    property TotalCells: Int64 read FTotalCells;
    property PlannedSegments: Int64 read FSegments;
    property PeakVoices: Integer read GetPeakVoices;
    property PercussionHits: Int64 read FPercussionHits;
    { Context and voice lookahead share one provisional graph. Only the
      returned prefix advances PlannedCells; uncommitted suffixes are editable. }
    property ContextLookaheadCells: Integer read FContextLookaheadCells;
    property VoiceLookaheadCells: Integer read FVoiceLookaheadCells;
    property LastVoicePlanningCells: Integer read FLastVoicePlanningCells;
  end;

function DefaultInstrumentalStreamOptions(const AMusicFrames: Int64): TInstrumentalStreamOptions;

implementation

uses SysUtils, Math, pythian.synth, pythian.wfc.music,
  pythian.wfc.musical.context, pythian.wfc.instrumental.controls,
  pythian.wfc.providers, pythian.wfc.progress,
  wfc_music_arrangement;

type
  TInstrumentalDensityKind = (idkRhythm, idkContext, idkPercussion);
  { Big Boss: bounded memoization of public vocabulary weights, never decisions.
    Models are borrowed and immutable for the owning stream's lifetime. }
  TInstrumentalDensityProfile = class
  private
    FModel: TWfcSequenceModel;
    FKind: TInstrumentalDensityKind;
    FParts: Integer;
    FReady: array[-50..50] of Boolean;
    FPreferences: array[-50..50] of TLayerTokenPreferences;
  public
    constructor Create(const AModel: TWfcSequenceModel;
      const AKind: TInstrumentalDensityKind; const AParts: Integer);
    function Preferences(const AOffset: Integer;
      const AProgress: TWorkProgressCallback): TLayerTokenPreferences;
  end;

  TInstrumentalFormVoices = class(TWfcMusicVoicesStream)
  private
    FOwner: TInstrumentalMusicStream;
  protected
    procedure ConfigureSegment(const AIndex, AStartTick: TWfcMusicArrangementWide;
      const ACellCount: Integer; const AGraph: TGraph); override;
  public
    constructor Create(const AConfig: TWfcMusicVoicesStreamConfig;
      const AOwner: TInstrumentalMusicStream);
  end;

constructor TInstrumentalDensityProfile.Create(const AModel: TWfcSequenceModel;
  const AKind: TInstrumentalDensityKind; const AParts: Integer);
begin
  inherited Create;
  FModel := AModel;
  FKind := AKind;
  FParts := AParts;
end;

function TInstrumentalDensityProfile.Preferences(const AOffset: Integer;
  const AProgress: TWorkProgressCallback): TLayerTokenPreferences;
var
  LParts: TMusicalPartControls;
  LCandidate: TLayerTokenPreferences;
  LKind: TStyleProviderVocabulary;
  LIndex: Integer;
  LBias: Integer;
begin
  if (AOffset < -50) or (AOffset > 50) then
    raise EAudio.Create('Section density offset must be -50..50');
  if not FReady[AOffset] then
  begin
    LBias := MapMusicalAffect(50, 50 + AOffset, 50).ActivityBias;
    if FKind = idkPercussion then
      LCandidate := PercussionActivityPreferences(FModel, LBias)
    else
    begin
      SetLength(LParts, FParts);
      for LIndex := 0 to High(LParts) do
      begin
        LParts[LIndex] := DefaultMusicalPartControl;
        LParts[LIndex].ActivityBias := LBias;
      end;
      LKind := spvRhythm;
      if FKind = idkContext then LKind := spvMusicalContext;
      LCandidate := SequenceActivityPreferences(FModel, LKind, LParts, AProgress);
    end;
    ReportWork(AProgress, 'instrumental_density_profile_ready', wuItems, 1, 1);
    FPreferences[AOffset] := LCandidate;
    FReady[AOffset] := True;
  end;
  { Private borrowed view. DensityRows detaches it before any caller can see it. }
  Result := FPreferences[AOffset];
end;

constructor TInstrumentalFormVoices.Create(const AConfig: TWfcMusicVoicesStreamConfig;
  const AOwner: TInstrumentalMusicStream);
begin
  inherited Create(AConfig);
  FOwner := AOwner;
end;

procedure TInstrumentalFormVoices.ConfigureSegment(
  const AIndex, AStartTick: TWfcMusicArrangementWide;
  const ACellCount: Integer; const AGraph: TGraph);
begin
  inherited ConfigureSegment(AIndex, AStartTick, ACellCount, AGraph);
  FOwner.ConfigureVoiceDensity(AStartTick, ACellCount, AGraph);
end;

function DefaultInstrumentalStreamOptions(const AMusicFrames: Int64): TInstrumentalStreamOptions;
begin
  Result := Default(TInstrumentalStreamOptions);
  Result.MusicFrames := AMusicFrames;
  Result.TicksPerQuarter := 480;
  Result.StepTicks := 240;
  Result.TempoMicroseconds := 500000;
  Result.SegmentCells := 16;
  Result.Seed := 731;
  Result.MaxBacktracks := 256;
  Result.MaxPassBacktracks := 16;
  Result.VoiceLimit := 128;
  Result.WorkLimit := 1000000;
  Result.ContextBinding := icbAllRoles;
end;

constructor TInstrumentalMusicStream.Create(const AConfig: TWfcMusicVoicesGraphConfig;
  const ARoles: TInstrumentalRoles; const APercussion: TPercussionDefinitions;
  const AGraph: TBusGraph; const AOptions: TInstrumentalStreamOptions;
  const AContext: TWfcSequenceModel; const ADecisionSink: TMusicDecisionSink;
  const AForm: TMusicForm; const ADomainProvider: TInstrumentalDomainProvider;
  const AMasks: TVoiceMasks; const APreferences: TVoicePreferences;
  const AExpression: TMusicalExpressions);
var
  LBindings: TInstrumentStreamBindings;
  LOptions: TInstrumentStreamOptions;
  LStreamConfig: TWfcMusicVoicesStreamConfig;
  LMap: TTempoMap;
  LTicks, LMaximumTicks: Integer;
  LIndex: Integer;
  LStates: Int64;
  LConstraint: TWfcSequenceTokenConstraint;
  LFormKeys: TMusicDecisionTokens;
  LProvider: Integer;
begin
  inherited Create;
  if (AGraph = nil) or (Length(ARoles) < 1) or (Length(ARoles) > 6) or
    (Length(ARoles) <> Length(AConfig.Voices)) or (Length(APercussion) > 6) or
    (AOptions.SegmentCells < 1) or (AOptions.SegmentCells > 256) or
    (AOptions.StepTicks < 1) or (AOptions.MaxBacktracks < 0) or
    (AOptions.MaxBacktracks > 65536) or (AOptions.MaxPassBacktracks < 0) or
    (AOptions.MaxPassBacktracks > 1024) or
    not (AOptions.ContextBinding in [icbDrivenRole, icbAllRoles]) then
    raise EAudio.Create('Instrumental stream needs ordered roles, bounded lookahead and search');
  FOptions := AOptions;
  FContextIndex := -1;
  FDecisionSink := ADecisionSink;
  FDomainProvider := ADomainProvider;
  for LIndex := 0 to High(AForm) do
  begin
    FHasExpression := FHasExpression or (AForm[LIndex].EnergyOffset <> 0);
    FHasDensity := FHasDensity or (AForm[LIndex].DensityOffset <> 0);
  end;
  SetLength(FRoleNames, Length(ARoles));
  for LIndex := 0 to High(ARoles) do FRoleNames[LIndex] := ARoles[LIndex].Name;
  SetLength(FPreviousDecision, Length(ARoles) + Length(APercussion));
  for LIndex := 0 to High(FPreviousDecision) do
    FPreviousDecision[LIndex] := Default(TChordVoice);
  FConfig := CopyWfcMusicVoicesGraphConfig(AConfig);
  if AContext <> nil then
  begin
    FContextIndex := WfcMusicVoicesModelCount(FConfig);
    FConfig := ComposeMusicalContextGraph(FConfig, AContext,
      AOptions.ContextBinding = icbAllRoles);
  end;
  FDefinitions := CopyPercussionDefinitions(APercussion);
  SetLength(FDrumModelIndices, Length(FDefinitions));
  for LIndex := 0 to High(FDefinitions) do
    FDrumModelIndices[LIndex] := WfcMusicVoicesModelCount(FConfig) + LIndex;
  FConfig := ComposePercussionGraph(FConfig, FDefinitions);
  if ((Length(AMasks) > 0) and
    (Length(AMasks) <> WfcMusicVoicesModelCount(FConfig))) or
    ((Length(APreferences) > 0) and
    (Length(APreferences) <> WfcMusicVoicesModelCount(FConfig))) then
  begin
    raise EAudio.Create('Stream controls must match every actual provider including context and drums');
  end;
  SetLength(FProviderPreferences, WfcMusicVoicesModelCount(FConfig));
  for LProvider := 0 to High(APreferences) do
  begin
    FProviderPreferences[LProvider] := Copy(APreferences[LProvider]);
  end;
  if (Length(AExpression) > 0) and
    (Length(AExpression) <> Length(ARoles) + Length(APercussion)) then
  begin
    raise EAudio.Create('Stream expression must match every performed part');
  end;
  FExpression := Copy(AExpression);
  for LIndex := 0 to High(FExpression) do
  begin
    ValidateMusicalExpression(FExpression[LIndex]);
    if FExpression[LIndex].GatePercent <> 100 then
    begin
      raise EAudio.Create('Stream articulation currently requires a 100 percent gate');
    end;
    FHasExpression := FHasExpression or (FExpression[LIndex].VelocityPercent <> 100);
  end;
  FClock := TIncrementalTempoClock.Create(AOptions.TicksPerQuarter, AGraph.SampleRate);
  if FClock.Advance(AOptions.StepTicks, AOptions.TempoMicroseconds) < 1 then
    raise EAudio.Create('Musical stream cells must span at least one sample frame');
  FClock.Reset;
  LMap := nil;
  try
    { Bracket only the requested clock span. A map extending to High(Integer)
      ticks can overflow exact frame arithmetic for otherwise valid short plans. }
    LMaximumTicks := (High(Integer) div AOptions.StepTicks) * AOptions.StepTicks;
    LTicks := AOptions.StepTicks;
    while True do
    begin
      FreeAndNil(LMap);
      LMap := TTempoMap.Create(AOptions.TicksPerQuarter, LTicks,
        [MakeTempoChange(0, AOptions.TempoMicroseconds)]);
      if LMap.FrameAtTick(LTicks, AGraph.SampleRate) >= AOptions.MusicFrames then Break;
      if LTicks = LMaximumTicks then
        raise EAudio.Create('Requested music exceeds the supported tick extent');
      LTicks := Min(Int64(LMaximumTicks), Int64(LTicks) * 2);
    end;
    LTicks := LMap.NextGridTick(AOptions.MusicFrames, AGraph.SampleRate, AOptions.StepTicks);
    FTotalCells := LTicks div AOptions.StepTicks;
  finally
    LMap.Free;
  end;
  if Length(AForm) > 0 then
  begin
    SetLength(LFormKeys, 2 + Length(ARoles) + Length(APercussion));
    LFormKeys[0] := 'harmony';
    LFormKeys[1] := 'rhythm';
    for LIndex := 0 to High(ARoles) do LFormKeys[LIndex + 2] := ARoles[LIndex].Name;
    for LIndex := 0 to High(APercussion) do
      LFormKeys[LIndex + 2 + Length(ARoles)] := APercussion[LIndex].Name;
    FForm := TMusicFormCursor.Create(AForm, LFormKeys);
    if FForm.TotalCells <> FTotalCells then
      raise EAudio.Create('Musical form must span the requested cell clock exactly');
    FOptions.SegmentCells := MusicFormLookahead(AForm, AOptions.SegmentCells);
  end;
  LStates := 0;
  for LIndex := 0 to WfcMusicVoicesModelCount(FConfig) - 1 do
    Inc(LStates, WfcMusicVoicesModelAt(FConfig, LIndex).StateCount);
  if LStates * FOptions.SegmentCells > MaximumLayerStateCells then
    raise EAudio.Create('Instrumental lookahead exceeds its explicit state-cell budget');
  FVoiceLookaheadCells := FOptions.SegmentCells;
  if FForm <> nil then
  begin
    FVoiceLookaheadCells := Min(MaximumMusicDecisionCells, MaximumLayerStateCells div LStates);
    FVoiceLookaheadCells := (FVoiceLookaheadCells div FOptions.SegmentCells) * FOptions.SegmentCells;
  end;
  FContextLookaheadCells := FVoiceLookaheadCells;
  LStreamConfig := DefaultWfcMusicVoicesStreamConfig(FConfig, AOptions.StepTicks,
    LTicks, AOptions.Seed);
  LStreamConfig.SegmentCellCount := FOptions.SegmentCells;
  LStreamConfig.PrepareProjectedDomains := True;
  LStreamConfig.LookaheadCellCount := FVoiceLookaheadCells;
  LStreamConfig.Search.SolveOptions.MaxBacktracks := AOptions.MaxBacktracks;
  LStreamConfig.Search.MaxPassBacktracks := AOptions.MaxPassBacktracks;
  FVoices := TInstrumentalFormVoices.Create(LStreamConfig, Self);
  for LProvider := 0 to High(AMasks) do
  begin
    ValidateSequenceTokenConstraints(WfcMusicVoicesModelAt(FConfig, LProvider),
      FTotalCells, AMasks[LProvider]);
    for LConstraint in AMasks[LProvider] do
    begin
      FVoices.IntersectAllowedTokens(LProvider, LConstraint.Position,
        LConstraint.AllowedTokens);
    end;
  end;
  if FHasDensity then
  begin
    SetLength(FDensityProfiles, 2 + Length(APercussion));
    if AContext <> nil then
      FDensityProfiles[0] := TInstrumentalDensityProfile.Create(AContext, idkContext,
        Length(ARoles))
    else
      FDensityProfiles[1] := TInstrumentalDensityProfile.Create(FConfig.RhythmModel,
        idkRhythm, Length(ARoles));
    for LIndex := 0 to High(APercussion) do
      FDensityProfiles[LIndex + 2] := TInstrumentalDensityProfile.Create(
        APercussion[LIndex].Model, idkPercussion, 0);
  end;
  SetLength(FDrums, Length(APercussion));
  LBindings := nil;
  SetLength(LBindings, Length(ARoles) + Length(APercussion));
  for LIndex := 0 to High(ARoles) do
  begin
    if ARoles[LIndex].IsPercussion then raise EAudio.Create('Pitched role cannot use drum binding');
    LBindings[LIndex].Instrument := ARoles[LIndex].Instrument;
    LBindings[LIndex].Bus := ARoles[LIndex].OutputBus;
    LBindings[LIndex].MaximumTones := 128;
  end;
  for LIndex := 0 to High(APercussion) do
  begin
    if (Trim(APercussion[LIndex].Origin) = '') or
      (APercussion[LIndex].HitWeight < 1) or
      (APercussion[LIndex].HitWeight > MaximumLayerPreferenceMultiplier) then
      raise EAudio.Create('Drum stream requires origin and hit weight1..1024');
    ValidateSequenceTokenConstraints(APercussion[LIndex].Model,
      FTotalCells, APercussion[LIndex].Constraints);
    for LConstraint in FDefinitions[LIndex].Constraints do
      FVoices.IntersectAllowedTokens(FDrumModelIndices[LIndex], LConstraint.Position,
        LConstraint.AllowedTokens);
    FDrums[LIndex] := TPercussionInstrument.Create(AGraph.SampleRate, APercussion[LIndex].Settings);
    LBindings[Length(ARoles) + LIndex].Instrument := FDrums[LIndex].Instrument;
    LBindings[Length(ARoles) + LIndex].Bus := APercussion[LIndex].OutputBus;
    LBindings[Length(ARoles) + LIndex].MaximumTones := 1;
    LBindings[Length(ARoles) + LIndex].GateFrames :=
      SampleFramesFromSeconds(APercussion[LIndex].Settings.GateSeconds, AGraph.SampleRate);
  end;
  LOptions := DefaultInstrumentStreamOptions(AOptions.MusicFrames);
  LOptions.TailFrames := AOptions.TailFrames;
  LOptions.Seed := AOptions.Seed;
  LOptions.VoiceLimit := AOptions.VoiceLimit;
  LOptions.WorkLimit := AOptions.WorkLimit;
  FMusic := TInstrumentMusicStream.Create(LBindings, AGraph, LOptions);
end;

destructor TInstrumentalMusicStream.Destroy;
var
  I: Integer;
begin
  FMusic.Free;
  FVoices.Free;
  FForm.Free;
  for I := 0 to High(FDrums) do FDrums[I].Free;
  for I := 0 to High(FDensityProfiles) do FDensityProfiles[I].Free;
  FClock.Free;
  inherited Destroy;
end;

procedure TInstrumentalMusicStream.RequireIdle;
begin
  if FBusy then raise EAudio.Create('Instrumental stream calls cannot reenter');
end;

function TInstrumentalMusicStream.DensityRows(const AProvider: Integer;
  const AFirstCell: Int64; const ACellCount: Integer;
  const AProgress: TWorkProgressCallback): TLayerPositionPreferences;
var
  LCell: Integer;
  LCount: Integer;
  LOffset: Integer;
  LPreferences: TLayerTokenPreferences;
begin
  Result := nil;
  if not FHasDensity then Exit;
  if (AProvider < 0) or (AProvider >= Length(FDensityProfiles)) or
    (FDensityProfiles[AProvider] = nil) or (ACellCount < 1) or
    (ACellCount > MaximumMusicDecisionCells) then
    raise EAudio.Create('Section density needs its actual bounded provider window');
  for LCell := 0 to ACellCount - 1 do
  begin
    if (LCell mod 32) = 0 then
      ReportWork(AProgress, 'instrumental_density_cells', wuItems, LCell, ACellCount);
    LOffset := FForm.DensityOffsetAt(AFirstCell + LCell);
    if LOffset = 0 then Continue;
    LPreferences := TInstrumentalDensityProfile(FDensityProfiles[AProvider]).Preferences(
      LOffset, AProgress);
    if Length(LPreferences) = 0 then Continue;
    LCount := Length(Result);
    SetLength(Result, LCount + 1);
    Result[LCount] := MakeLayerPositionPreference(LCell, LPreferences);
  end;
  ReportWork(AProgress, 'instrumental_density_cells_ready', wuItems, ACellCount, ACellCount);
end;

procedure TInstrumentalMusicStream.ConfigureVoiceDensity(const AStartTick: Int64;
  const ACellCount: Integer; const AGraph: TGraph);
var
  LRows: TLayerPositionPreferences;
  LIndex: Integer;
  LPreferences: TLayerTokenPreferences;
  LDrumPreferences: TLayerTokenPreferences;
  LToken: Integer;
  LOther: Integer;
  LProvider: Integer;
  LFound: Boolean;
begin
  { Big Boss: one application per provider combines saved global controls with
    positioned form controls. Reapplying weights would overwrite the first set. }
  for LIndex := 0 to WfcMusicVoicesModelCount(FConfig) - 1 do
  begin
    LRows := nil;
    if FHasDensity and (LIndex = FContextIndex) then
      LRows := DensityRows(0, AStartTick div FOptions.StepTicks, ACellCount, FVoiceProgress)
    else if FHasDensity and (FContextIndex < 0) and (LIndex = 1) then
      LRows := DensityRows(1, AStartTick div FOptions.StepTicks, ACellCount, FVoiceProgress);
    LPreferences := Copy(FProviderPreferences[LIndex]);
    for LOther := 0 to High(FDefinitions) do
    begin
      if LIndex <> FDrumModelIndices[LOther] then Continue;
      if FHasDensity then
        LRows := DensityRows(LOther + 2, AStartTick div FOptions.StepTicks,
          ACellCount, FVoiceProgress);
      LDrumPreferences := PercussionPreferences(FDefinitions[LOther]);
      for LToken := 0 to High(LDrumPreferences) do
      begin
        LFound := False;
        for LProvider := 0 to High(LPreferences) do
        begin
          if LPreferences[LProvider].Token <> LDrumPreferences[LToken].Token then Continue;
          if LPreferences[LProvider].Multiplier > MaximumLayerPreferenceMultiplier div
            LDrumPreferences[LToken].Multiplier then
            raise EAudio.Create('Saved drum preference and hit weight exceed the combined weight budget');
          LPreferences[LProvider].Multiplier := LPreferences[LProvider].Multiplier *
            LDrumPreferences[LToken].Multiplier;
          LFound := True;
        end;
        if not LFound then
        begin
          SetLength(LPreferences, Length(LPreferences) + 1);
          LPreferences[High(LPreferences)] := LDrumPreferences[LToken];
        end;
      end;
    end;
    if (Length(LRows) > 0) or (Length(LPreferences) > 0) then
    begin
      ApplySequencePositionPreferences(WfcMusicVoicesModelAt(FConfig, LIndex),
        AGraph.PassGraph[LIndex], LRows, LPreferences, FVoiceProgress);
    end;
  end;
end;

function TInstrumentalMusicStream.FormProviderIndex(const AKey: String): Integer;
var I: Integer;
begin
  if AKey = 'harmony' then Exit(0);
  if AKey = 'rhythm' then Exit(1);
  for I := 0 to High(FRoleNames) do
    if AKey = FRoleNames[I] then Exit(I + 2);
  for I := 0 to High(FDefinitions) do
    if AKey = FDefinitions[I].Name then Exit(FDrumModelIndices[I]);
  raise EAudio.Create('Retained motif refers to an unknown musical provider');
end;

procedure TInstrumentalMusicStream.PlanSegment(const AProgress: TWorkProgressCallback);
var
  LBridge: TWfcSolveProgressBridge;
  LVoiceReport: TGraphNegotiationReport;
  LSegment: TWfcMusicVoicesSegment;
  LMasks: TVoiceMasks;
  LMask: TWfcSequenceTokenConstraint;
  LProvider, I, J, LPlanningCells, LWindowCells, LCellCount: Integer;
  LBindCell: Int64;
  LFrames: TWfcMusicEnsembleFrames;
  LDrumCellTokens: TWfcModelTokens;
  LDrumTokens: TInstrumentalTokenStreams;
  LDecisions, LSinkCopy: TMusicDecisionChunk;
  LFutureRetained: TMusicDecisionProviders;
  LClock: TIncrementalTempoClock;
  LFrame: TChordFrame;
  LCell: Integer;
  LFrameCount, LFrameAt: Int64;
  LKnownProvider: Boolean;
  procedure KeepProvider(const AKey: String; const AGenerated: TWfcGeneratedSequenceSegment);
  var LAt, LCell: Integer;
  begin
    LAt := Length(LDecisions.Providers);
    SetLength(LDecisions.Providers, LAt + 1);
    LDecisions.Providers[LAt].Key := AKey;
    SetLength(LDecisions.Providers[LAt].Tokens, Length(AGenerated.Tokens));
    SetLength(LDecisions.Providers[LAt].States, Length(AGenerated.StateIndices));
    for LCell := 0 to High(AGenerated.Tokens) do
      LDecisions.Providers[LAt].Tokens[LCell] := AGenerated.Tokens[LCell];
    for LCell := 0 to High(AGenerated.StateIndices) do
      LDecisions.Providers[LAt].States[LCell] := AGenerated.StateIndices[LCell];
  end;
begin
  LDecisions := Default(TMusicDecisionChunk);
  LDecisions.Version := MusicDecisionVersion;
  if FHasExpression then LDecisions.Version := MusicDecisionExpressionVersion;
  LDecisions.FirstCell := FCells;
  LDecisions.StartFrame := FMusic.AdmittedFrames;
  LDecisions.Previous := CopyChordFrame(FPreviousDecision);
  LCellCount := Min(Int64(FOptions.SegmentCells), FTotalCells - FCells);
  ReportWork(AProgress, 'instrumental_stream_plan', wuItems, FCells, FTotalCells);
  LPlanningCells := LCellCount;
  if FForm <> nil then
    LPlanningCells := FForm.ReadyLookaheadCells(FVoiceLookaheadCells);
  if FForm <> nil then
  begin
    if LPlanningCells < LCellCount then
      raise EAudio.Create('Known future domains do not span the current musical prefix');
    LBindCell := Max(FCells, FFormBoundCells);
    while LBindCell < FCells + LPlanningCells do
    begin
      LWindowCells := FForm.WindowCellsAt(LBindCell, FCells + LPlanningCells - LBindCell);
      if not FForm.TryCopyLocksAt(LBindCell, LWindowCells, LFutureRetained) then
        raise EAudio.Create('Known future motif has no completed source decisions');
      for I := 0 to High(LFutureRetained) do
      begin
        LProvider := FormProviderIndex(LFutureRetained[I].Key);
        for LCell := 0 to LWindowCells - 1 do
          FVoices.IntersectAllowedTokens(LProvider, LBindCell + LCell,
            [LFutureRetained[I].Tokens[LCell]]);
      end;
      Inc(LBindCell, LWindowCells);
    end;
    FFormBoundCells := Max(FFormBoundCells, LBindCell);
  end;
  if Assigned(FDomainProvider) then
  begin
    LBindCell := Max(FCells, FDomainBoundCells);
    if LBindCell < FCells + LPlanningCells then
    begin
      LWindowCells := FCells + LPlanningCells - LBindCell;
      LMasks := FDomainProvider(LBindCell, LWindowCells);
      for LProvider := 0 to High(LMasks) do
        for LMask in LMasks[LProvider] do
        begin
          if (LMask.Position < 0) or (LMask.Position >= LWindowCells) then
            raise EAudio.Create('Authored domain lies outside its requested musical window');
          FVoices.IntersectAllowedTokens(LProvider, LBindCell + LMask.Position, LMask.AllowedTokens);
        end;
      FDomainBoundCells := FCells + LPlanningCells;
    end;
  end;
  LSegment := nil;
  LBridge := nil;
  SetLength(LDrumTokens, Length(FDefinitions));
  try
    FVoiceProgress := AProgress;
    LBridge := TWfcSolveProgressBridge.Create(AProgress);
    if FVoices.Next(LSegment, LVoiceReport, LPlanningCells,
        WfcSolveObserver(LBridge)) <> wmaspProduced then
      raise EAudio.Create('Musical frontier cannot continue at cell ' + IntToStr(FCells) +
        ', negotiation ' + IntToStr(Ord(LVoiceReport.Status)) + ', pass ' +
        IntToStr(LVoiceReport.FinalReport.FailedPassIndex) + ': ' + FVoices.Failure);
    FLastVoicePlanningCells := LSegment.PlanningCellCount;
    LFrames := LSegment.CopyFrames;
    if FContextIndex >= 0 then
      KeepProvider(MusicalContextPassName, LSegment.CopyGenerated(FContextIndex));
    KeepProvider('harmony', LSegment.CopyGenerated(0));
    KeepProvider('rhythm', LSegment.CopyGenerated(1));
    for I := 0 to High(FRoleNames) do
      KeepProvider(FRoleNames[I], LSegment.CopyGenerated(I + 2));
    for I := 0 to High(FDefinitions) do
    begin
      LDrumTokens[I] := LSegment.CopyGenerated(FDrumModelIndices[I]).Tokens;
      KeepProvider(FDefinitions[I].Name, LSegment.CopyGenerated(FDrumModelIndices[I]));
    end;
    for I := 2 + Length(FRoleNames) to WfcMusicVoicesModelCount(FConfig) - 1 do
    begin
      LKnownProvider := I = FContextIndex;
      for J := 0 to High(FDrumModelIndices) do
        LKnownProvider := LKnownProvider or (I = FDrumModelIndices[J]);
      if not LKnownProvider then
        KeepProvider(WfcMusicVoicesPassLabel(FConfig, I), LSegment.CopyGenerated(I));
    end;
  finally
    FVoiceProgress := nil;
    LBridge.Free;
    LSegment.Free;
  end;
  ReportWork(AProgress, 'instrumental_stream_voices', wuItems, FCells, FTotalCells);
  { Retain the exact performed cell clock, including fractional tempo carry and
    the clipped last cell. This uses the same primary frame projection and clock;
    AdmitCell below consumes this candidate instead of projecting a second copy. }
  SetLength(LDecisions.Cells, Length(LFrames));
  LFrameAt := LDecisions.StartFrame;
  LClock := TIncrementalTempoClock.Create(FOptions.TicksPerQuarter, FMusic.SampleRate);
  try
    LClock.Restore(FClock.Snapshot);
    for LCell := 0 to High(LFrames) do
    begin
      SetLength(LDrumCellTokens, Length(FDrums));
      for I := 0 to High(FDrums) do
      begin
        LDrumCellTokens[I] := LDrumTokens[I][LCell];
      end;
      LFrame := AppendPercussionDecisions(ProjectWfcChordFrame(LFrames[LCell]),
        LDrumCellTokens, FDefinitions);
      LFrameCount := LClock.Advance(FOptions.StepTicks, FOptions.TempoMicroseconds);
      LFrameCount := Min(LFrameCount, FOptions.MusicFrames - LFrameAt);
      LDecisions.Cells[LCell].FrameCount := LFrameCount;
      LDecisions.Cells[LCell].Parts := LFrame;
      if FHasExpression then
      begin
        SetLength(LDecisions.Cells[LCell].Expression, Length(LFrame));
        for I := 0 to High(LFrame) do
        begin
          LDecisions.Cells[LCell].Expression[I] := DefaultMusicalExpression;
          if Length(FExpression) > 0 then
          begin
            LDecisions.Cells[LCell].Expression[I] := FExpression[I];
          end;
          if FForm <> nil then
          begin
            LDecisions.Cells[LCell].Expression[I].VelocityPercent :=
              Min(200, (LDecisions.Cells[LCell].Expression[I].VelocityPercent *
              MapMusicalAffect(50 + FForm.EnergyOffsetAt(FCells + LCell),
                50, 50).VelocityPercent + 50) div 100);
          end;
        end;
      end;
      Inc(LFrameAt, LFrameCount);
    end;
  finally
    LClock.Free;
  end;
  ValidateMusicDecisionChunk(LDecisions, AProgress);
  ReportWork(AProgress, 'instrumental_stream_ready', wuItems,
    FCells + Length(LFrames), FTotalCells);
  if FForm <> nil then FForm.Append(LDecisions);
  if Assigned(FDecisionSink) then
  begin
    LSinkCopy := CopyMusicDecisionChunk(LDecisions);
    FDecisionSink(LSinkCopy);
  end;
  FFrames := LFrames;
  FDecisions := LDecisions;
  FCell := 0;
  Inc(FSegments);
end;

procedure TInstrumentalMusicStream.AdmitCell(const AProgress: TWorkProgressCallback);
var
  LFrame: TChordFrame;
  I, LHits: Integer;
  LFrames: Int64;
begin
  if FCell = Length(FFrames) then PlanSegment(AProgress);
  LFrame := FDecisions.Cells[FCell].Parts;
  LHits := 0;
  for I := 0 to High(FDrums) do
  begin
    if LFrame[Length(FRoleNames) + I].Action = caAttack then Inc(LHits);
  end;
  LFrames := FClock.Advance(FOptions.StepTicks, FOptions.TempoMicroseconds);
  LFrames := Min(LFrames, FOptions.MusicFrames - FMusic.AdmittedFrames);
  if LFrames <> FDecisions.Cells[FCell].FrameCount then
    raise EAudio.Create('Decision capture differs from the performed clock');
  FMusic.AdmitFrame(LFrame, LFrames, AProgress, FDecisions.Cells[FCell].Expression);
  FPreviousDecision := CopyChordFrame(LFrame);
  Inc(FPercussionHits, LHits);
  Inc(FCell);
  Inc(FCells);
end;

function TInstrumentalMusicStream.ReadSamples(const AMaximumFrames: Integer;
  out ASamples: TAudioSamples; const AProgress: TWorkProgressCallback): Boolean;
var
  LOutputs: TBusSampleBlocks;
begin
  Result := ReadOutputs(AMaximumFrames, [], ASamples, LOutputs, AProgress);
end;

function TInstrumentalMusicStream.ReadOutputs(const AMaximumFrames: Integer;
  const AOutputBuses: array of Integer; out ASamples: TAudioSamples;
  out AOutputs: TBusSampleBlocks; const AProgress: TWorkProgressCallback): Boolean;
begin
  RequireIdle;
  ASamples := nil;
  AOutputs := nil;
  FMusic.ValidatePull(AMaximumFrames, AOutputBuses);
  if FFailed then raise EAudio.Create('Instrumental stream failed; start a new replay');
  if State <> issReady then Exit(False);
  FBusy := True;
  try
    try
      if FMusic.NeedsInput then AdmitCell(AProgress);
      Result := FMusic.ReadOutputs(AMaximumFrames, AOutputBuses, ASamples, AOutputs, AProgress);
    except
      FFailed := True;
      ASamples := nil;
      AOutputs := nil;
      raise;
    end;
  finally
    FBusy := False;
  end;
end;

function TInstrumentalMusicStream.GetPosition: Int64;
begin
  Result := FMusic.Position;
end;

function TInstrumentalMusicStream.GetFrameCount: Int64;
begin
  Result := FMusic.FrameCount;
end;

function TInstrumentalMusicStream.GetState: TInstrumentStreamState;
begin
  if FFailed then Result := issFailed else Result := FMusic.State;
end;

function TInstrumentalMusicStream.GetPeakVoices: Integer;
begin
  Result := FMusic.PeakVoices;
end;

function TInstrumentalMusicStream.GetPlannedCells: Int64;
begin
  Result := FCells + Length(FFrames) - FCell;
end;

procedure TInstrumentalMusicStream.Pause;
begin
  RequireIdle;
  FMusic.Pause;
end;

procedure TInstrumentalMusicStream.Resume;
begin
  RequireIdle;
  FMusic.Resume;
end;

procedure TInstrumentalMusicStream.Stop;
begin
  RequireIdle;
  FVoices.Cancel;
  FMusic.Stop;
end;

procedure TInstrumentalMusicStream.IntersectFutureTokens(const AProvider: Integer;
  const ACell: Int64; const ATokens: TWfcModelTokens);
begin
  RequireIdle;
  if State <> issReady then raise EAudio.Create('Only ready musical streams accept future edits');
  if ACell < PlannedCells then
    raise EAudio.Create('Future edits cannot replace already planned musical context');
  FVoices.IntersectAllowedTokens(AProvider, ACell, ATokens);
end;

function TInstrumentalMusicStream.CopyLastFrames: TWfcMusicEnsembleFrames;
var
  I: Integer;
begin
  Result := Copy(FFrames);
  for I := 0 to High(Result) do
    Result[I] := DecodeWfcMusicEnsembleFrame(EncodeWfcMusicEnsembleFrame(FFrames[I]));
end;

function TInstrumentalMusicStream.CopyLastDecisions: TMusicDecisionChunk;
begin
  Result := CopyMusicDecisionChunk(FDecisions);
end;

end.
