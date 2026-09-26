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
unit pythian.wfc.grid;

{$mode delphi}
{$H+}

interface

uses
  pythian.music.context,
  pythian.pitch,
  pythian.wfc.style,
  pythian.wfc.layers,
  pythian.wfc.providers,
  wfc,
  wfc_sequence,
  wfc_sequence_analyze;

type
  TStyleGridProvider = (gpKey, gpTempo, gpPitchRhythm, gpOnsets, gpIntensity, gpPitch);
  TStyleGridOptions = record
    CellCount: Integer;
    Extent: TWfcSequenceExtent;
    CouplePitch: Boolean;
    Seed: TGraphSeed;
    MaxBacktracks: Integer;
    MaxPassBacktracks: Integer;
  end;
  TGridValueLock = record
    Cell: Integer;
    Value: Integer;
  end;
  TGridValueLocks = array of TGridValueLock;
  TGridKeyLock = record
    Cell: Integer;
    Key: TKeyContext;
  end;
  TGridKeyLocks = array of TGridKeyLock;
  TGridOnsets = array of Boolean;
  TGridIntensities = array of Integer;
  { Every capture owns fresh arrays, detached from the definition and session.
    Absent intensity/pitch providers produce empty arrays, not invented values.
    Onsets are generation choices, not an assertion of measured source silence. }
  TStyleGridResult = record
    Context: TMusicContextGrid;
    Onsets: TGridOnsets;
    Intensities: TGridIntensities;
    Pitches: TPitchNotes;
  end;

  { Saved uniform-grid providers in actual WFC pass order. The definition owns
    copied models/preferences; CreateSession returns an independently owned
    session. Both can outlive the source style; a session can outlive this object.
    Capture validates original model paths and observed relationships, not edited
    session masks/preferences or replacement models. No file I/O, authored voices,
    fixed PPQ or implicit transposition/role inference belongs here. }
  TStyleGrid = class
  private
    FLayers: TLearnedLayers;
    FMaps: TLayerProjections;
    FNames: TLayerNames;
    FIndices: array[TStyleGridProvider] of Integer;
    FOptions: TLayerGenerationOptions;
    FTicksPerQuarter: Integer;
    FStepTicks: Integer;
    FIdentity: String;
    function GetProviderCount: Integer;
    function RequireIndex(const AProvider: TStyleGridProvider): Integer;
    procedure ValidateLocks(const ALocks: TGridValueLocks);
  public
    constructor Create(const AStyle: TWaveStyleProfile; const AOptions: TStyleGridOptions);
    destructor Destroy; override;
    function ProviderIndex(const AProvider: TStyleGridProvider): Integer;
    function ProviderName(const AIndex: Integer): String;
    function CopyProvider(const AIndex: Integer): TStyleProviderDescription;
    function CreateSession: TLearnedLayerSession;
    function ModelText(const AIndex: Integer): String;
    function CopyPreferences(const AIndex: Integer): TLayerTokenPreferences;
    function AnalyzeProvider(const AIndex: Integer;
      const AConstraints: TWfcSequenceTokenConstraints;
      out AAnalysis: TWfcSequenceDomainAnalysis): Boolean;
    { One lock per cell/dimension. Onsets: 0/1; intensity: 0..4;
      pitch: MIDI 0..127; tempo: microseconds per quarter.
      Masks replace the entire named pass's constraints; nil clears that mask. }
    function ValueConstraints(const AProvider: TStyleGridProvider;
      const ALocks: TGridValueLocks): TWfcSequenceTokenConstraints;
    function KeyConstraints(const ALocks: TGridKeyLocks): TWfcSequenceTokenConstraints;
    { Intersects requested dimensions into observed joint choices. Use together
      with the consumer masks; regenerate from pitch-rhythm for coupled edits. }
    function CoupledConstraints(const AOnsets, AIntensities, APitches: TGridValueLocks):
      TWfcSequenceTokenConstraints;
    function Capture(const ASequences: TLayerSequences): TStyleGridResult;
    property TicksPerQuarter: Integer read FTicksPerQuarter;
    property StepTicks: Integer read FStepTicks;
    property StyleIdentity: String read FIdentity;
    property ProviderCount: Integer read GetProviderCount;
  end;

function DefaultStyleGridOptions: TStyleGridOptions;
function MakeGridValueLock(const ACell, AValue: Integer): TGridValueLock;
function MakeGridKeyLock(const ACell: Integer; const AKey: TKeyContext): TGridKeyLock;

implementation

uses
  pythian.audio,
  pythian.wfc.context,
  pythian.wfc.context.profile,
  pythian.wfc.pitch,
  wfc_model,
  wfc_sequence_graph,
  wfc_sequence_text;

function DefaultStyleGridOptions: TStyleGridOptions;
var
  LOptions: TLayerGenerationOptions;
begin
  LOptions := DefaultLayerGenerationOptions;
  Result := Default(TStyleGridOptions);
  Result.CellCount := 32;
  Result.Extent := wseFragment;
  Result.Seed := LOptions.Seed;
  Result.MaxBacktracks := LOptions.MaxBacktracks;
  Result.MaxPassBacktracks := LOptions.MaxPassBacktracks;
end;

function MakeGridValueLock(const ACell, AValue: Integer): TGridValueLock;
begin
  Result.Cell := ACell;
  Result.Value := AValue;
end;

function MakeGridKeyLock(const ACell: Integer; const AKey: TKeyContext): TGridKeyLock;
begin
  Result.Cell := ACell;
  Result.Key := AKey;
end;

function JointRules(const AProvider, AConsumer: TWfcSequenceModel;
  const ADimension: TStyleGridProvider): TWfcSequenceProjectionRules;
var
  LConsumer: Integer;
  LProvider: Integer;
  LToken: UTF8String;
  LPair: TPitchRhythmCell;
  LAllowed: TWfcModelTokens;
  LMatches: Boolean;
begin
  Result := nil;
  if Int64(AProvider.PublicTokenCount) * AConsumer.PublicTokenCount >
    MaximumLayerProjectionWork then
  begin
    raise EAudio.Create('Grid relation preparation exceeds bounded work');
  end;
  SetLength(Result, AConsumer.PublicTokenCount);
  for LConsumer := 0 to AConsumer.PublicTokenCount - 1 do
  begin
    LToken := AConsumer.PublicTokenAt(LConsumer);
    LAllowed := nil;
    for LProvider := 0 to AProvider.PublicTokenCount - 1 do
    begin
      LPair := DecodePitchRhythmToken(AProvider.PublicTokenAt(LProvider));
      case ADimension of
        gpOnsets:
        begin
          LMatches := ((LPair.Level > 0) and (LToken = RhythmOnsetToken)) or
            ((LPair.Level = 0) and (LToken = RhythmEmptyToken));
        end;
        gpIntensity:
        begin
          LMatches := LPair.Level = DecodeStyleIntensityToken(LToken);
        end;
        gpPitch:
        begin
          LMatches := LPair.Note = DecodePitchNoteToken(LToken);
        end;
      else
        raise EAudio.Create('Unknown grid joint projection');
      end;
      if LMatches then
      begin
        SetLength(LAllowed, Length(LAllowed) + 1);
        LAllowed[High(LAllowed)] := AProvider.PublicTokenAt(LProvider);
      end;
    end;
    Result[LConsumer] := MakeWfcSequenceProjectionRule(LToken, LAllowed);
  end;
end;

constructor TStyleGrid.Create(const AStyle: TWaveStyleProfile;
  const AOptions: TStyleGridOptions);
var
  LContext: TContextProfile;
  LPreferences: TStyleGenerationPreferences;
  LProvider: TStyleGridProvider;
  LIndex: Integer;
  LCount: Integer;
  LMap: Integer;
  LToken: UTF8String;
begin
  inherited Create;
  if AStyle = nil then
  begin
    raise EAudio.Create('Grid definition requires a saved style');
  end;
  if (AOptions.CellCount < 1) or (AOptions.CellCount > MaximumLayerCells) or
    not (AOptions.Extent in [wseWhole, wsePrefix, wseFragment]) or
    (AOptions.MaxBacktracks < 0) or (AOptions.MaxPassBacktracks < 0) then
  begin
    raise EAudio.Create('Grid scope or search budget exceeds layer bounds');
  end;
  LPreferences := AStyle.CopyGenerationPreferences;
  if Length(LPreferences[sppPerformance]) > 0 then
  begin
    raise EAudio.Create('Performance preferences require duration generation');
  end;
  if (Length(LPreferences[sppPitchRhythm]) > 0) and not AOptions.CouplePitch then
  begin
    raise EAudio.Create('Joint pitch/rhythm preferences require coupled generation');
  end;
  if AOptions.CouplePitch and (not AStyle.HasPitchRhythm or not AStyle.HasPitch) then
  begin
    raise EAudio.Create('Coupled pitch requires observed relationships and equal source weights');
  end;
  LCount := 0;
  for LProvider := Low(LProvider) to High(LProvider) do
  begin
    FIndices[LProvider] := -1;
    if ((LProvider = gpPitchRhythm) and not AOptions.CouplePitch) or
      ((LProvider = gpIntensity) and not AStyle.HasDynamics) or
      ((LProvider = gpPitch) and not AStyle.HasPitch) then
    begin
      Continue;
    end;
    FIndices[LProvider] := LCount;
    Inc(LCount);
  end;
  SetLength(FLayers, LCount);
  SetLength(FNames, LCount);
  LContext := AStyle.CopyContext;
  try
    FTicksPerQuarter := LContext.TicksPerQuarter;
    FStepTicks := LContext.StepTicks;
    if Int64(FStepTicks) * AOptions.CellCount > High(Integer) then
    begin
      raise EAudio.Create('Grid exceeds native PPQ extent');
    end;
    FLayers[0].Model := LContext.CopyModel(cdKey);
    FLayers[1].Model := LContext.CopyModel(cdTempo);
  finally
    LContext.Free;
  end;
  FNames[0] := 'key';
  FNames[1] := 'tempo';
  FLayers[0].Preferences := LPreferences[sppKey];
  FLayers[1].Preferences := LPreferences[sppTempo];
  LIndex := FIndices[gpOnsets];
  FLayers[LIndex].Model := AStyle.CopyRhythmModel;
  FLayers[LIndex].Preferences := LPreferences[sppRhythm];
  FNames[LIndex] := 'onsets';
  if AStyle.HasDynamics then
  begin
    LIndex := FIndices[gpIntensity];
    FLayers[LIndex].Model := AStyle.CopyIntensityModel;
    FLayers[LIndex].Preferences := LPreferences[sppIntensity];
    FNames[LIndex] := 'intensity';
    SetLength(FMaps, 1);
    FMaps[0].Provider := FIndices[gpOnsets];
    FMaps[0].Consumer := LIndex;
    SetLength(FMaps[0].Rules, FLayers[LIndex].Model.PublicTokenCount);
    for LCount := 0 to FLayers[LIndex].Model.PublicTokenCount - 1 do
    begin
      LToken := FLayers[LIndex].Model.PublicTokenAt(LCount);
      if DecodeStyleIntensityToken(LToken) = 0 then
      begin
        FMaps[0].Rules[LCount] := MakeWfcSequenceProjectionRule(LToken, [RhythmEmptyToken]);
      end
      else
      begin
        FMaps[0].Rules[LCount] := MakeWfcSequenceProjectionRule(LToken, [RhythmOnsetToken]);
      end;
    end;
  end;
  if AStyle.HasPitch then
  begin
    LIndex := FIndices[gpPitch];
    FLayers[LIndex].Model := AStyle.CopyPitchModel;
    FLayers[LIndex].Preferences := LPreferences[sppPitch];
    FNames[LIndex] := 'pitch';
  end;
  if AOptions.CouplePitch then
  begin
    LIndex := FIndices[gpPitchRhythm];
    FLayers[LIndex].Model := AStyle.CopyPitchRhythmModel;
    FLayers[LIndex].Preferences := LPreferences[sppPitchRhythm];
    FNames[LIndex] := 'pitch-rhythm';
    { Preserve the established projection order: onset, pitch, intensity. }
    LMap := Length(FMaps);
    SetLength(FMaps, LMap + 2 + Ord(AStyle.HasDynamics));
    FMaps[LMap].Provider := LIndex;
    FMaps[LMap].Consumer := FIndices[gpOnsets];
    FMaps[LMap].Rules := JointRules(FLayers[LIndex].Model,
      FLayers[FIndices[gpOnsets]].Model, gpOnsets);
    Inc(LMap);
    FMaps[LMap].Provider := LIndex;
    FMaps[LMap].Consumer := FIndices[gpPitch];
    FMaps[LMap].Rules := JointRules(FLayers[LIndex].Model,
      FLayers[FIndices[gpPitch]].Model, gpPitch);
    if AStyle.HasDynamics then
    begin
      Inc(LMap);
      FMaps[LMap].Provider := LIndex;
      FMaps[LMap].Consumer := FIndices[gpIntensity];
      FMaps[LMap].Rules := JointRules(FLayers[LIndex].Model,
        FLayers[FIndices[gpIntensity]].Model, gpIntensity);
    end;
  end;
  FIdentity := AStyle.Identity;
  FOptions := DefaultLayerGenerationOptions;
  FOptions.CellCount := AOptions.CellCount;
  FOptions.Extent := AOptions.Extent;
  FOptions.Seed := AOptions.Seed;
  FOptions.MaxBacktracks := AOptions.MaxBacktracks;
  FOptions.MaxPassBacktracks := AOptions.MaxPassBacktracks;
end;

destructor TStyleGrid.Destroy;
var
  LIndex: Integer;
begin
  for LIndex := 0 to High(FLayers) do
  begin
    FLayers[LIndex].Model.Free;
  end;
  inherited;
end;

function TStyleGrid.ProviderIndex(const AProvider: TStyleGridProvider): Integer;
begin
  if not (AProvider in [gpKey, gpTempo, gpPitchRhythm, gpOnsets, gpIntensity, gpPitch]) then
  begin
    raise EAudio.Create('Unknown grid provider');
  end;
  Result := FIndices[AProvider];
end;

function TStyleGrid.GetProviderCount: Integer;
begin
  Result := Length(FLayers);
end;

function TStyleGrid.RequireIndex(const AProvider: TStyleGridProvider): Integer;
begin
  Result := ProviderIndex(AProvider);
  if Result < 0 then
  begin
    raise EAudio.Create('Requested provider is absent from the grid definition');
  end;
end;

function TStyleGrid.ProviderName(const AIndex: Integer): String;
begin
  if (AIndex < 0) or (AIndex >= Length(FNames)) then
  begin
    raise EAudio.Create('Grid provider index outside definition');
  end;
  Result := FNames[AIndex];
end;

function TStyleGrid.CreateSession: TLearnedLayerSession;
begin
  Result := TLearnedLayerSession.Create(FLayers, FMaps, FNames, FOptions);
end;

function TStyleGrid.CopyProvider(const AIndex: Integer): TStyleProviderDescription;
const
  CVocabularies: array[TStyleGridProvider] of TStyleProviderVocabulary =
    (spvKey, spvTempo, spvPitchRhythm, spvOnsets, spvIntensity, spvPitch);
var
  LDescription: TStyleProviderDescription;
  LProvider: TStyleGridProvider;
  LMap: Integer;
  LCount: Integer;
begin
  LDescription := Default(TStyleProviderDescription);
  LDescription.Name := ProviderName(AIndex);
  for LProvider := Low(LProvider) to High(LProvider) do
  begin
    if FIndices[LProvider] = AIndex then
    begin
      LDescription.Vocabulary := CVocabularies[LProvider];
      Break;
    end;
  end;
  LDescription.TicksPerQuarter := FTicksPerQuarter;
  LDescription.Timing := sptUniform;
  LDescription.StepTicks := FStepTicks;
  LDescription.Scope := ResolveLayerScope(FOptions, AIndex);
  LDescription.Choices := CopyStyleProviderChoices(FLayers[AIndex].Model,
    LDescription.Vocabulary);
  LDescription.Preferences := CopyPreferences(AIndex);
  for LMap := 0 to High(FMaps) do
  begin
    if FMaps[LMap].Consumer = AIndex then
    begin
      LCount := Length(LDescription.Dependencies);
      SetLength(LDescription.Dependencies, LCount + 1);
      LDescription.Dependencies[LCount].Name := FNames[FMaps[LMap].Provider];
      LDescription.Dependencies[LCount].TimeMapping := FMaps[LMap].TimeMapping;
    end;
  end;
  Result := LDescription;
end;

function TStyleGrid.ModelText(const AIndex: Integer): String;
begin
  ProviderName(AIndex);
  Result := EncodeWfcSequenceText(FLayers[AIndex].Model);
end;

function TStyleGrid.CopyPreferences(const AIndex: Integer): TLayerTokenPreferences;
begin
  ProviderName(AIndex);
  Result := Copy(FLayers[AIndex].Preferences, 0, Length(FLayers[AIndex].Preferences));
end;

function TStyleGrid.AnalyzeProvider(const AIndex: Integer;
  const AConstraints: TWfcSequenceTokenConstraints;
  out AAnalysis: TWfcSequenceDomainAnalysis): Boolean;
var
  LModel: TWfcSequenceModel;
  LCells: Int64;
begin
  AAnalysis := Default(TWfcSequenceDomainAnalysis);
  ProviderName(AIndex);
  LModel := FLayers[AIndex].Model;
  LCells := Int64(FOptions.CellCount) * LModel.StateCount;
  if (LCells > MaximumLayerStateCells) or
    (LCells * LModel.StateCount > MaximumLayerProjectionWork) then
  begin
    raise EAudio.Create('Grid feasibility analysis exceeds bounded work');
  end;
  Result := AnalyzeSequenceTokenDomains(LModel, FOptions.CellCount,
    FOptions.Extent, AConstraints, AAnalysis);
end;

procedure TStyleGrid.ValidateLocks(const ALocks: TGridValueLocks);
var
  LSeen: array of Boolean;
  LLock: TGridValueLock;
begin
  if Length(ALocks) > FOptions.CellCount then
  begin
    raise EAudio.Create('Too many grid locks');
  end;
  SetLength(LSeen, FOptions.CellCount);
  for LLock in ALocks do
  begin
    if (LLock.Cell < 0) or (LLock.Cell >= FOptions.CellCount) then
    begin
      raise EAudio.Create('Grid lock cell outside definition');
    end;
    if LSeen[LLock.Cell] then
    begin
      raise EAudio.Create('Duplicate grid lock cell in one dimension');
    end;
    LSeen[LLock.Cell] := True;
  end;
end;

function TStyleGrid.ValueConstraints(const AProvider: TStyleGridProvider;
  const ALocks: TGridValueLocks): TWfcSequenceTokenConstraints;
var
  LIndex: Integer;
  LToken: UTF8String;
begin
  Result := nil;
  RequireIndex(AProvider);
  if not (AProvider in [gpTempo, gpOnsets, gpIntensity, gpPitch]) then
  begin
    raise EAudio.Create('Grid value locks require tempo, onset, intensity or pitch');
  end;
  ValidateLocks(ALocks);
  SetLength(Result, Length(ALocks));
  for LIndex := 0 to High(ALocks) do
  begin
    case AProvider of
      gpTempo:
      begin
        LToken := TempoContextToken(ALocks[LIndex].Value);
      end;
      gpIntensity:
      begin
        LToken := StyleIntensityToken(ALocks[LIndex].Value);
      end;
      gpPitch:
      begin
        LToken := PitchNoteToken(ALocks[LIndex].Value);
      end;
      gpOnsets:
      begin
        if not (ALocks[LIndex].Value in [0, 1]) then
        begin
          raise EAudio.Create('Grid onset lock must be zero or one');
        end;
        if ALocks[LIndex].Value = 0 then
        begin
          LToken := RhythmEmptyToken;
        end
        else
        begin
          LToken := RhythmOnsetToken;
        end;
      end;
    else
      raise EAudio.Create('Unsupported grid value lock');
    end;
    Result[LIndex] := MakeWfcSequenceTokenConstraint(ALocks[LIndex].Cell, [LToken]);
  end;
end;

function TStyleGrid.KeyConstraints(const ALocks: TGridKeyLocks): TWfcSequenceTokenConstraints;
var
  LValues: TGridValueLocks;
  LIndex: Integer;
begin
  Result := nil;
  if Length(ALocks) > FOptions.CellCount then
  begin
    raise EAudio.Create('Too many grid key locks');
  end;
  SetLength(LValues, Length(ALocks));
  for LIndex := 0 to High(ALocks) do
  begin
    LValues[LIndex].Cell := ALocks[LIndex].Cell;
  end;
  ValidateLocks(LValues);
  SetLength(Result, Length(ALocks));
  for LIndex := 0 to High(ALocks) do
  begin
    Result[LIndex] := MakeWfcSequenceTokenConstraint(ALocks[LIndex].Cell,
      [KeyContextToken(ALocks[LIndex].Key)]);
  end;
end;

function TStyleGrid.CoupledConstraints(const AOnsets, AIntensities,
  APitches: TGridValueLocks): TWfcSequenceTokenConstraints;
var
  LOnsets: array of Integer;
  LIntensities: array of Integer;
  LPitches: array of Integer;
  LLock: TGridValueLock;
  LCell: Integer;
  LIndex: Integer;
  LModel: TWfcSequenceModel;
  LPair: TPitchRhythmCell;
  LAllowed: TWfcModelTokens;
begin
  Result := nil;
  LModel := FLayers[RequireIndex(gpPitchRhythm)].Model;
  { Validate dimensions even if an inconsistent intersection would be empty. }
  ValueConstraints(gpOnsets, AOnsets);
  if Length(AIntensities) > 0 then
  begin
    ValueConstraints(gpIntensity, AIntensities);
  end;
  ValueConstraints(gpPitch, APitches);
  if Int64(FOptions.CellCount) * LModel.PublicTokenCount > MaximumLayerProjectionWork then
  begin
    raise EAudio.Create('Grid lock preparation exceeds bounded work');
  end;
  SetLength(LOnsets, FOptions.CellCount);
  SetLength(LIntensities, FOptions.CellCount);
  SetLength(LPitches, FOptions.CellCount);
  for LCell := 0 to FOptions.CellCount - 1 do
  begin
    LOnsets[LCell] := -1;
    LIntensities[LCell] := -1;
    LPitches[LCell] := -1;
  end;
  for LLock in AOnsets do
  begin
    LOnsets[LLock.Cell] := LLock.Value;
  end;
  for LLock in AIntensities do
  begin
    LIntensities[LLock.Cell] := LLock.Value;
  end;
  for LLock in APitches do
  begin
    LPitches[LLock.Cell] := LLock.Value;
  end;
  for LCell := 0 to FOptions.CellCount - 1 do
  begin
    if (LOnsets[LCell] < 0) and (LIntensities[LCell] < 0) and (LPitches[LCell] < 0) then
    begin
      Continue;
    end;
    LAllowed := nil;
    for LIndex := 0 to LModel.PublicTokenCount - 1 do
    begin
      LPair := DecodePitchRhythmToken(LModel.PublicTokenAt(LIndex));
      if ((LOnsets[LCell] < 0) or (LOnsets[LCell] = Ord(LPair.Level > 0))) and
        ((LIntensities[LCell] < 0) or (LIntensities[LCell] = LPair.Level)) and
        ((LPitches[LCell] < 0) or (LPitches[LCell] = LPair.Note)) then
      begin
        SetLength(LAllowed, Length(LAllowed) + 1);
        LAllowed[High(LAllowed)] := LModel.PublicTokenAt(LIndex);
      end;
    end;
    if Length(LAllowed) = 0 then
    begin
      raise EAudio.Create('Coupled locks have no observed pitch/onset/intensity alternative');
    end;
    SetLength(Result, Length(Result) + 1);
    Result[High(Result)] := MakeWfcSequenceTokenConstraint(LCell, LAllowed);
  end;
end;

function TStyleGrid.Capture(const ASequences: TLayerSequences): TStyleGridResult;
var
  LLayer: Integer;
  LCell: Integer;
  LOnset: Integer;
  LIntensity: Integer;
  LPitch: Integer;
  LJoint: Integer;
  LToken: UTF8String;
  LPair: TPitchRhythmCell;
  LContext: TMusicContext;
  LReport: TWfcSequenceGraphValidationReport;
  LCandidate: TStyleGridResult;
begin
  { FPC may write a managed record result directly into its assignment target.
    Keep failure paths local until the complete candidate is validated. }
  LCandidate := Default(TStyleGridResult);
  if Length(ASequences) <> Length(FLayers) then
  begin
    raise EAudio.Create('Grid capture requires every defined provider');
  end;
  for LLayer := 0 to High(FLayers) do
  begin
    if (Length(ASequences[LLayer].Tokens) <> FOptions.CellCount) or
      (Length(ASequences[LLayer].StateIndices) <> FOptions.CellCount) or
      not ValidateSequenceStatePath(FLayers[LLayer].Model,
        ASequences[LLayer].StateIndices, FOptions.Extent, LReport) then
    begin
      raise EAudio.Create('Grid provider fails its scoped actual model path');
    end;
    for LCell := 0 to FOptions.CellCount - 1 do
    begin
      if ASequences[LLayer].Tokens[LCell] <> FLayers[LLayer].Model.PublicTokenAt(
        FLayers[LLayer].Model.StateEmittedTokenIndexAt(ASequences[LLayer].StateIndices[LCell])) then
      begin
        raise EAudio.Create('Grid token differs from its latent model state');
      end;
    end;
  end;
  LOnset := FIndices[gpOnsets];
  LIntensity := FIndices[gpIntensity];
  LPitch := FIndices[gpPitch];
  LJoint := FIndices[gpPitchRhythm];
  SetLength(LCandidate.Onsets, FOptions.CellCount);
  if LIntensity >= 0 then
  begin
    SetLength(LCandidate.Intensities, FOptions.CellCount);
  end;
  if LPitch >= 0 then
  begin
    SetLength(LCandidate.Pitches, FOptions.CellCount);
  end;
  for LCell := 0 to FOptions.CellCount - 1 do
  begin
    LToken := ASequences[LOnset].Tokens[LCell];
    if (LToken <> RhythmEmptyToken) and (LToken <> RhythmOnsetToken) then
    begin
      raise EAudio.Create('Unknown grid onset token');
    end;
    LCandidate.Onsets[LCell] := LToken = RhythmOnsetToken;
    if LIntensity >= 0 then
    begin
      LCandidate.Intensities[LCell] := DecodeStyleIntensityToken(ASequences[LIntensity].Tokens[LCell]);
      if (LCandidate.Intensities[LCell] > 0) <> LCandidate.Onsets[LCell] then
      begin
        raise EAudio.Create('Grid intensity disagrees with its observed onset');
      end;
    end;
    if LPitch >= 0 then
    begin
      LCandidate.Pitches[LCell] := DecodePitchNoteToken(ASequences[LPitch].Tokens[LCell]);
    end;
    if LJoint >= 0 then
    begin
      LPair := DecodePitchRhythmToken(ASequences[LJoint].Tokens[LCell]);
      if (LPair.Note <> LCandidate.Pitches[LCell]) or
        ((LPair.Level > 0) <> LCandidate.Onsets[LCell]) then
      begin
        raise EAudio.Create('Grid consumers disagree with observed joint pitch/onset');
      end;
      if (LIntensity >= 0) and (LPair.Level <> LCandidate.Intensities[LCell]) then
      begin
        raise EAudio.Create('Grid intensity disagrees with observed joint level');
      end;
    end;
  end;
  LContext := MusicContextFromTokens(ASequences[0].Tokens, ASequences[1].Tokens,
    FTicksPerQuarter, FStepTicks);
  try
    LCandidate.Context := LContext.Grid(0, FStepTicks, FOptions.CellCount);
  finally
    LContext.Free;
  end;
  Result := LCandidate;
end;

end.
