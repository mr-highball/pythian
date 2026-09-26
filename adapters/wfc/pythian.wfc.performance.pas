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
unit pythian.wfc.performance;

{$mode delphi}
{$H+}

interface

uses
  pythian.time,
  pythian.music.context,
  pythian.pitch.track,
  pythian.wfc.style,
  pythian.wfc.layers,
  pythian.wfc.providers,
  wfc,
  wfc_sequence,
  wfc_sequence_analyze;

type
  TPerformanceProvider = (ppKey, ppTempo, ppPerformance);
  TStylePerformanceOptions = record
    SpanCount: Integer;
    KeyCells: Integer; { Zero explicitly holds a single-valued model. }
    TempoCells: Integer;
    Seed: TGraphSeed;
    MaxBacktracks: Integer;
    MaxPassBacktracks: Integer;
  end;
  TPerformanceValueLock = record
    Cell: Integer;
    Value: Integer;
  end;
  TPerformanceValueLocks = array of TPerformanceValueLock;
  TPerformanceKeyLock = record
    Cell: Integer;
    Key: TKeyContext;
  end;
  TPerformanceKeyLocks = array of TPerformanceKeyLock;

  { Detached musical-time result. No synthesis voice, fixed PPQ, JSON or file I/O.
    Unknown key and unknown/silent performance spans remain explicit. }
  TStylePerformancePlan = class
  private
    FContext: TMusicContext;
    FSpans: TTimedPitchSpans;
    function GetSpanCount: Integer;
  public
    { Owns copies of a complete contiguous span partition and its context. }
    constructor Create(const ASpans: TTimedPitchSpans; const AClock: TTempoMap;
      const AKeys: TKeyChanges);
    destructor Destroy; override;
    function CopySpans: TTimedPitchSpans;
    function CopyClock: TTempoMap;
    function CopyKeys: TKeyChanges;
    function KeyAtTick(const ATick: Integer): TKeyContext;
    property SpanCount: Integer read GetSpanCount;
  end;

  { Owns models copied from the style. CreateSession returns an independent
    caller-owned actual WFC session with key, tempo and performance passes.
    The style may be freed after construction. A session and captured plan may
    each outlive this definition. Constraints replace a pass's complete mask.
    Capture validates model paths and musical coverage; the session validates
    caller constraints. Capture does not mutate or roll back a solved session.
    Failure preserves a previously assigned plan. }
  TStylePerformance = class
  private
    FLayers: TLearnedLayers;
    FOptions: TLayerGenerationOptions;
    FKeyCells: Integer;
    FTempoCells: Integer;
    FTicksPerQuarter: Integer;
    FStepTicks: Integer;
    FIdentity: String;
  public
    constructor Create(const AStyle: TWaveStyleProfile; const AOptions: TStylePerformanceOptions);
    destructor Destroy; override;
    function CreateSession: TLearnedLayerSession;
    function CopyProvider(const AProvider: TPerformanceProvider): TStyleProviderDescription;
    function ModelText(const AProvider: TPerformanceProvider): String;
    { Exact structural feasibility for the definition's provider scope and supplied
      token masks. Does not solve, mutate a session, or establish musical coverage.
      Bounded by layer state-cell and projection-work limits. }
    function AnalyzeProvider(const AProvider: TPerformanceProvider;
      const AConstraints: TWfcSequenceTokenConstraints;
      out AAnalysis: TWfcSequenceDomainAnalysis): Boolean;
    { One lock per cell per dimension; pitch and duration on the same cell
      intersect into one mask, including for a one-span request. }
    function PerformanceConstraints(const ADurations, APitches: TPerformanceValueLocks):
      TWfcSequenceTokenConstraints;
    function TempoConstraints(const ALocks: TPerformanceValueLocks): TWfcSequenceTokenConstraints;
    function KeyConstraints(const ALocks: TPerformanceKeyLocks): TWfcSequenceTokenConstraints;
    function Capture(const ASequences: TLayerSequences): TStylePerformancePlan;
    property TicksPerQuarter: Integer read FTicksPerQuarter;
    property StepTicks: Integer read FStepTicks;
    property StyleIdentity: String read FIdentity;
  end;

function DefaultStylePerformanceOptions: TStylePerformanceOptions;
function MakePerformanceValueLock(const ACell, AValue: Integer): TPerformanceValueLock;
function MakePerformanceKeyLock(const ACell: Integer; const AKey: TKeyContext): TPerformanceKeyLock;

implementation

uses
  pythian.audio,
  pythian.wfc.context,
  pythian.wfc.context.profile,
  pythian.wfc.pitch,
  wfc_model,
  wfc_sequence_graph,
  wfc_sequence_text;

function DefaultStylePerformanceOptions: TStylePerformanceOptions;
var
  LOptions: TLayerGenerationOptions;
begin
  LOptions := DefaultLayerGenerationOptions;
  Result := Default(TStylePerformanceOptions);
  Result.SpanCount := 32;
  Result.Seed := LOptions.Seed;
  Result.MaxBacktracks := LOptions.MaxBacktracks;
  Result.MaxPassBacktracks := LOptions.MaxPassBacktracks;
end;

function MakePerformanceValueLock(const ACell, AValue: Integer): TPerformanceValueLock;
begin
  Result.Cell := ACell;
  Result.Value := AValue;
end;

function MakePerformanceKeyLock(const ACell: Integer; const AKey: TKeyContext): TPerformanceKeyLock;
begin
  Result.Cell := ACell;
  Result.Key := AKey;
end;

constructor TStylePerformance.Create(const AStyle: TWaveStyleProfile;
  const AOptions: TStylePerformanceOptions);
var
  LContext: TContextProfile;
  LPreferences: TStyleGenerationPreferences;
  LProvider: TStylePreferenceProvider;
begin
  inherited Create;
  if AStyle = nil then
  begin
    raise EAudio.Create('Performance definition requires a saved style');
  end;
  if not AStyle.HasDuration then
  begin
    raise EAudio.Create('Performance definition requires measured duration evidence');
  end;
  if (AOptions.SpanCount < 1) or (AOptions.SpanCount > MaximumLayerCells) or
    (AOptions.KeyCells < 0) or (AOptions.KeyCells > MaximumLayerCells) or
    (AOptions.TempoCells < 0) or (AOptions.TempoCells > MaximumLayerCells) or
    (AOptions.MaxBacktracks < 0) or (AOptions.MaxPassBacktracks < 0) then
  begin
    raise EAudio.Create('Performance scope or search budget exceeds layer bounds');
  end;
  SetLength(FLayers, 3);
  LContext := AStyle.CopyContext;
  try
    FTicksPerQuarter := LContext.TicksPerQuarter;
    FStepTicks := LContext.StepTicks;
    if AStyle.DurationTicksPerQuarter <> FTicksPerQuarter then
    begin
      raise EAudio.Create('Performance and context must share a PPQ timebase');
    end;
    FLayers[0].Model := LContext.CopyModel(cdKey);
    FLayers[1].Model := LContext.CopyModel(cdTempo);
    FLayers[2].Model := AStyle.CopyDurationModel;
    LPreferences := AStyle.CopyGenerationPreferences;
    for LProvider := sppRhythm to High(LProvider) do
    begin
      if Length(LPreferences[LProvider]) > 0 then
      begin
        raise EAudio.Create('Duration performance cannot consume grid-model preferences');
      end;
    end;
    FLayers[0].Preferences := LPreferences[sppKey];
    FLayers[1].Preferences := LPreferences[sppTempo];
    FLayers[2].Preferences := LPreferences[sppPerformance];
  finally
    LContext.Free;
  end;
  FIdentity := AStyle.Identity;
  FKeyCells := AOptions.KeyCells;
  FTempoCells := AOptions.TempoCells;
  FOptions := DefaultLayerGenerationOptions;
  FOptions.Seed := AOptions.Seed;
  FOptions.MaxBacktracks := AOptions.MaxBacktracks;
  FOptions.MaxPassBacktracks := AOptions.MaxPassBacktracks;
  SetLength(FOptions.Scopes, 3);
  FOptions.Scopes[0] := MakeLayerScope(1, wsePrefix);
  FOptions.Scopes[1] := MakeLayerScope(1, wsePrefix);
  FOptions.Scopes[2] := MakeLayerScope(AOptions.SpanCount, wsePrefix);
  if FKeyCells = 0 then
  begin
    HeldContextToken(FLayers[0].Model, cdKey);
  end
  else
  begin
    FOptions.Scopes[0] := MakeLayerScope(FKeyCells, wsePrefix);
  end;
  if FTempoCells = 0 then
  begin
    HeldContextToken(FLayers[1].Model, cdTempo);
  end
  else
  begin
    FOptions.Scopes[1] := MakeLayerScope(FTempoCells, wsePrefix);
  end;
end;

destructor TStylePerformance.Destroy;
var
  LIndex: Integer;
begin
  for LIndex := 0 to High(FLayers) do
  begin
    FLayers[LIndex].Model.Free;
  end;
  inherited;
end;

function TStylePerformance.CreateSession: TLearnedLayerSession;
begin
  Result := TLearnedLayerSession.Create(FLayers, nil, ['key', 'tempo', 'performance'], FOptions);
end;

function TStylePerformance.AnalyzeProvider(const AProvider: TPerformanceProvider;
  const AConstraints: TWfcSequenceTokenConstraints;
  out AAnalysis: TWfcSequenceDomainAnalysis): Boolean;
var
  LScope: TLayerScope;
  LModel: TWfcSequenceModel;
  LCells: Int64;
begin
  AAnalysis := Default(TWfcSequenceDomainAnalysis);
  if not (AProvider in [ppKey, ppTempo, ppPerformance]) then
  begin
    raise EAudio.Create('Unknown performance provider');
  end;
  LScope := ResolveLayerScope(FOptions, Ord(AProvider));
  LModel := FLayers[Ord(AProvider)].Model;
  LCells := Int64(LScope.CellCount) * LModel.StateCount;
  if (LCells > MaximumLayerStateCells) or
    (LCells * LModel.StateCount > MaximumLayerProjectionWork) then
  begin
    raise EAudio.Create('Performance feasibility analysis exceeds bounded work');
  end;
  Result := AnalyzeSequenceTokenDomains(LModel, LScope.CellCount,
    LScope.Extent, AConstraints, AAnalysis);
end;

function TStylePerformance.ModelText(const AProvider: TPerformanceProvider): String;
begin
  if not (AProvider in [ppKey, ppTempo, ppPerformance]) then
  begin
    raise EAudio.Create('Unknown performance provider');
  end;
  Result := EncodeWfcSequenceText(FLayers[Ord(AProvider)].Model);
end;

function TStylePerformance.CopyProvider(const AProvider: TPerformanceProvider):
  TStyleProviderDescription;
const
  CNames: array[TPerformanceProvider] of String = ('key', 'tempo', 'performance');
  CVocabularies: array[TPerformanceProvider] of TStyleProviderVocabulary =
    (spvKey, spvTempo, spvPerformance);
var
  LDescription: TStyleProviderDescription;
begin
  if not (AProvider in [ppKey, ppTempo, ppPerformance]) then
  begin
    raise EAudio.Create('Unknown performance provider');
  end;
  LDescription := Default(TStyleProviderDescription);
  LDescription.Name := CNames[AProvider];
  LDescription.Vocabulary := CVocabularies[AProvider];
  LDescription.TicksPerQuarter := FTicksPerQuarter;
  LDescription.Scope := ResolveLayerScope(FOptions, Ord(AProvider));
  LDescription.Timing := sptUniform;
  LDescription.StepTicks := FStepTicks;
  if AProvider = ppPerformance then
  begin
    LDescription.Timing := sptGeneratedSpans;
    LDescription.StepTicks := 0;
  end
  else if ((AProvider = ppKey) and (FKeyCells = 0)) or
    ((AProvider = ppTempo) and (FTempoCells = 0)) then
  begin
    LDescription.Timing := sptHeld;
    LDescription.StepTicks := 0;
  end;
  LDescription.Choices := CopyStyleProviderChoices(FLayers[Ord(AProvider)].Model,
    LDescription.Vocabulary);
  LDescription.Preferences := Copy(FLayers[Ord(AProvider)].Preferences, 0,
    Length(FLayers[Ord(AProvider)].Preferences));
  Result := LDescription;
end;

function TStylePerformance.PerformanceConstraints(const ADurations,
  APitches: TPerformanceValueLocks): TWfcSequenceTokenConstraints;
var
  LDurations: array of Integer;
  LPitches: array of Integer;
  LLock: TPerformanceValueLock;
  LCell: Integer;
  LToken: Integer;
  LCount: Integer;
  LSpan: TPitchDurationCell;
  LAllowed: TWfcModelTokens;
  LResult: TWfcSequenceTokenConstraints;
begin
  LCount := FOptions.Scopes[2].CellCount;
  if (Length(ADurations) > LCount) or (Length(APitches) > LCount) then
  begin
    raise EAudio.Create('Too many performance locks');
  end;
  SetLength(LDurations, LCount);
  SetLength(LPitches, LCount);
  for LCell := 0 to LCount - 1 do
  begin
    LPitches[LCell] := -1;
  end;
  for LLock in ADurations do
  begin
    if (LLock.Cell < 0) or (LLock.Cell >= LCount) or (LLock.Value < 1) then
    begin
      raise EAudio.Create('Duration lock requires an in-scope cell and positive PPQ ticks');
    end;
    if LDurations[LLock.Cell] <> 0 then
    begin
      raise EAudio.Create('Duplicate duration lock cell');
    end;
    LDurations[LLock.Cell] := LLock.Value;
  end;
  for LLock in APitches do
  begin
    if (LLock.Cell < 0) or (LLock.Cell >= LCount) or
      (LLock.Value < 0) or (LLock.Value > 127) then
    begin
      raise EAudio.Create('Pitch lock requires an in-scope cell and MIDI pitch');
    end;
    if LPitches[LLock.Cell] <> -1 then
    begin
      raise EAudio.Create('Duplicate pitch lock cell');
    end;
    LPitches[LLock.Cell] := LLock.Value;
  end;
  LCount := 0;
  for LCell := 0 to High(LDurations) do
  begin
    if (LDurations[LCell] > 0) or (LPitches[LCell] >= 0) then
    begin
      Inc(LCount);
    end;
  end;
  if Int64(LCount) * FLayers[2].Model.PublicTokenCount > MaximumLayerProjectionWork then
  begin
    raise EAudio.Create('Performance lock vocabulary work exceeds budget');
  end;
  LResult := nil;
  for LCell := 0 to High(LDurations) do
  begin
    if (LDurations[LCell] = 0) and (LPitches[LCell] < 0) then
    begin
      Continue;
    end;
    LAllowed := nil;
    for LToken := 0 to FLayers[2].Model.PublicTokenCount - 1 do
    begin
      LSpan := DecodePitchDurationToken(FLayers[2].Model.PublicTokenAt(LToken));
      if ((LDurations[LCell] = 0) or (LDurations[LCell] = LSpan.Duration)) and
        ((LPitches[LCell] < 0) or ((LSpan.Kind = pskPitch) and (LPitches[LCell] = LSpan.Note))) then
      begin
        SetLength(LAllowed, Length(LAllowed) + 1);
        LAllowed[High(LAllowed)] := FLayers[2].Model.PublicTokenAt(LToken);
      end;
    end;
    if Length(LAllowed) = 0 then
    begin
      raise EAudio.Create('Performance lock has no observed joint alternative');
    end;
    SetLength(LResult, Length(LResult) + 1);
    LResult[High(LResult)] := MakeWfcSequenceTokenConstraint(LCell, LAllowed);
  end;
  Result := LResult;
end;

function TStylePerformance.TempoConstraints(const ALocks: TPerformanceValueLocks):
  TWfcSequenceTokenConstraints;
var
  LResult: TWfcSequenceTokenConstraints;
  LIndex: Integer;
  LSeen: array of Boolean;
begin
  if Length(ALocks) > FOptions.Scopes[1].CellCount then
  begin
    raise EAudio.Create('Too many tempo locks');
  end;
  SetLength(LResult, Length(ALocks));
  SetLength(LSeen, FOptions.Scopes[1].CellCount);
  for LIndex := 0 to High(ALocks) do
  begin
    if (ALocks[LIndex].Cell < 0) or (ALocks[LIndex].Cell >= Length(LSeen)) then
    begin
      raise EAudio.Create('Tempo lock outside provider scope');
    end;
    if LSeen[ALocks[LIndex].Cell] then
    begin
      raise EAudio.Create('Duplicate tempo lock cell');
    end;
    LSeen[ALocks[LIndex].Cell] := True;
    LResult[LIndex] := MakeWfcSequenceTokenConstraint(ALocks[LIndex].Cell,
      [TempoContextToken(ALocks[LIndex].Value)]);
  end;
  ValidateSequenceTokenConstraints(FLayers[1].Model, FOptions.Scopes[1].CellCount, LResult);
  Result := LResult;
end;

function TStylePerformance.KeyConstraints(const ALocks: TPerformanceKeyLocks):
  TWfcSequenceTokenConstraints;
var
  LResult: TWfcSequenceTokenConstraints;
  LIndex: Integer;
  LSeen: array of Boolean;
begin
  if Length(ALocks) > FOptions.Scopes[0].CellCount then
  begin
    raise EAudio.Create('Too many key locks');
  end;
  SetLength(LResult, Length(ALocks));
  SetLength(LSeen, FOptions.Scopes[0].CellCount);
  for LIndex := 0 to High(ALocks) do
  begin
    if (ALocks[LIndex].Cell < 0) or (ALocks[LIndex].Cell >= Length(LSeen)) then
    begin
      raise EAudio.Create('Key lock outside provider scope');
    end;
    if LSeen[ALocks[LIndex].Cell] then
    begin
      raise EAudio.Create('Duplicate key lock cell');
    end;
    LSeen[ALocks[LIndex].Cell] := True;
    LResult[LIndex] := MakeWfcSequenceTokenConstraint(ALocks[LIndex].Cell,
      [KeyContextToken(ALocks[LIndex].Key)]);
  end;
  ValidateSequenceTokenConstraints(FLayers[0].Model, FOptions.Scopes[0].CellCount, LResult);
  Result := LResult;
end;

function TStylePerformance.Capture(const ASequences: TLayerSequences): TStylePerformancePlan;
var
  LSpans: TTimedPitchSpans;
  LLayer: Integer;
  LCell: Integer;
  LTick: Integer;
  LSpan: TPitchDurationCell;
  LClock: TTempoMap;
  LKeys: TKeyChanges;
  LReport: TWfcSequenceGraphValidationReport;
begin
  if Length(ASequences) <> 3 then
  begin
    raise EAudio.Create('Performance capture requires key, tempo and performance sequences');
  end;
  for LLayer := 0 to 2 do
  begin
    if (Length(ASequences[LLayer].Tokens) <> FOptions.Scopes[LLayer].CellCount) or
      (Length(ASequences[LLayer].StateIndices) <> FOptions.Scopes[LLayer].CellCount) or
      not ValidateSequenceStatePath(FLayers[LLayer].Model,
        ASequences[LLayer].StateIndices, wsePrefix, LReport) then
    begin
      raise EAudio.Create('Performance provider fails its scoped actual model path');
    end;
    for LCell := 0 to High(ASequences[LLayer].Tokens) do
    begin
      if ASequences[LLayer].Tokens[LCell] <> FLayers[LLayer].Model.PublicTokenAt(
        FLayers[LLayer].Model.StateEmittedTokenIndexAt(ASequences[LLayer].StateIndices[LCell])) then
      begin
        raise EAudio.Create('Performance token differs from its latent model state');
      end;
    end;
  end;
  LClock := nil;
  try
    SetLength(LSpans, FOptions.Scopes[2].CellCount);
    LTick := 0;
    for LCell := 0 to High(LSpans) do
    begin
      LSpan := DecodePitchDurationToken(ASequences[2].Tokens[LCell]);
      if Int64(LTick) + LSpan.Duration > High(Integer) then
      begin
        raise EAudio.Create('Performance exceeds native PPQ extent');
      end;
      LSpans[LCell].StartTick := LTick;
      Inc(LTick, LSpan.Duration);
      LSpans[LCell].EndTick := LTick;
      LSpans[LCell].Kind := LSpan.Kind;
      LSpans[LCell].Note := LSpan.Note;
    end;
    if FTempoCells = 0 then
    begin
      LClock := TTempoMap.Create(FTicksPerQuarter, LTick,
        [MakeTempoChange(0, TempoContextFromToken(ASequences[1].Tokens[0]))]);
    end
    else
    begin
      LClock := TempoClockFromTokens(ASequences[1].Tokens, FTicksPerQuarter, FStepTicks, LTick);
    end;
    if FKeyCells = 0 then
    begin
      LKeys := KeyChangesFromTokens(ASequences[0].Tokens, LTick, LTick);
    end
    else
    begin
      LKeys := KeyChangesFromTokens(ASequences[0].Tokens, FStepTicks, LTick);
    end;
    Result := TStylePerformancePlan.Create(LSpans, LClock, LKeys);
  finally
    LClock.Free;
  end;
end;

constructor TStylePerformancePlan.Create(const ASpans: TTimedPitchSpans;
  const AClock: TTempoMap; const AKeys: TKeyChanges);
var
  LIndex: Integer;
  LTick: Integer;
begin
  inherited Create;
  if (AClock = nil) or (Length(ASpans) < 1) or (Length(ASpans) > MaximumLayerCells) then
  begin
    raise EAudio.Create('Performance plan requires a clock and 1..1024 spans');
  end;
  LTick := 0;
  for LIndex := 0 to High(ASpans) do
  begin
    if (ASpans[LIndex].StartTick <> LTick) or (ASpans[LIndex].EndTick <= LTick) or
      not (ASpans[LIndex].Kind in [pskPitch, pskSilence, pskUnknown]) or
      ((ASpans[LIndex].Kind = pskPitch) and
        ((ASpans[LIndex].Note < 0) or (ASpans[LIndex].Note > 127))) or
      ((ASpans[LIndex].Kind <> pskPitch) and (ASpans[LIndex].Note <> -1)) then
    begin
      raise EAudio.Create('Performance plan spans must be contiguous and canonical');
    end;
    LTick := ASpans[LIndex].EndTick;
  end;
  if AClock.LengthTicks <> LTick then
  begin
    raise EAudio.Create('Performance plan and clock must have the same extent');
  end;
  FContext := TMusicContext.Create(AClock, AKeys);
  FSpans := Copy(ASpans);
end;

destructor TStylePerformancePlan.Destroy;
begin
  FContext.Free;
  inherited;
end;

function TStylePerformancePlan.GetSpanCount: Integer;
begin
  Result := Length(FSpans);
end;

function TStylePerformancePlan.CopySpans: TTimedPitchSpans;
begin
  Result := Copy(FSpans);
end;

function TStylePerformancePlan.CopyClock: TTempoMap;
begin
  Result := FContext.CopyClock;
end;

function TStylePerformancePlan.CopyKeys: TKeyChanges;
begin
  Result := FContext.CopyKeys;
end;

function TStylePerformancePlan.KeyAtTick(const ATick: Integer): TKeyContext;
begin
  Result := FContext.KeyAtTick(ATick);
end;

end.
