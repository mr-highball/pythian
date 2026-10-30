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

unit pythian.wfc.musical.context;

{$mode delphi}
{$H+}

interface

uses pythian.progress, pythian.wfc.layers, pythian.wfc.providers,
  pythian.wfc.voices, wfc, wfc_model, wfc_sequence, wfc_sequence_graph,
  wfc_music_voices_graph;

const
  MusicalContextPassName = 'musical-context';

type
  { Owns one actual WFC context pass. Its paired choices become immutable
    harmonic/rhythmic inputs to the next conditional graph; no cross-group
    backtracking is claimed. Named instrumental roles remain independently solved. }
  TMusicalContextPlan = class
  private
    FSession: TLearnedLayerSession;
    FAccepted: TLayerSequences;
    FMasks: TWfcSequenceTokenConstraints;
    FPreferences: TLayerTokenPreferences;
    FOptions: TVoiceSessionOptions;
    FRoleNames: TLayerNames;
  public
    constructor Create(const AModel: TWfcSequenceModel;
      const ARoleNames: TLayerNames; const AOptions: TVoiceSessionOptions;
      const AMasks: TVoiceMasks; const APreferences: TVoicePreferences;
      const AProgress: TWorkProgressCallback = nil);
    destructor Destroy; override;
    function TryGenerate(out AReport: TGraphNegotiationReport;
      const AProgress: TWorkProgressCallback = nil): Boolean;
    function CopyGraph: TLayerGraphPasses;
    function CopyTokens: TWfcModelTokens;
    function CopyStates: TWfcSequenceStateIndices;
    function CopyModel: TWfcSequenceModel;
    function CopyProvider: TStyleProviderDescription;
    function CopyConstraints: TWfcSequenceTokenConstraints;
    function CopyPreferences: TLayerTokenPreferences;
    function BindMasks(const AMasks: TVoiceMasks): TVoiceMasks;
  end;

implementation

uses SysUtils, pythian.audio;

function TokenAllowed(const AMasks: TVoiceMasks; const AProvider, ACell: Integer;
  const AToken: String): Boolean;
var
  LMask: TWfcSequenceTokenConstraint;
  LAlternative: String;
  LFound: Boolean;
begin
  Result := True;
  if AProvider >= Length(AMasks) then Exit;
  for LMask in AMasks[AProvider] do
  begin
    if LMask.Position <> ACell then Continue;
    LFound := False;
    for LAlternative in LMask.AllowedTokens do
      if LAlternative = AToken then LFound := True;
    if not LFound then Exit(False);
  end;
end;

constructor TMusicalContextPlan.Create(const AModel: TWfcSequenceModel;
  const ARoleNames: TLayerNames; const AOptions: TVoiceSessionOptions;
  const AMasks: TVoiceMasks; const APreferences: TVoicePreferences;
  const AProgress: TWorkProgressCallback);
var
  LLayers: TLearnedLayers;
  LOptions: TLayerGenerationOptions;
  LContext: String;
  LHarmony: String;
  LRhythm: String;
  LTokens: TWfcModelTokens;
  LHarmonies: TWfcModelTokens;
  LRhythms: TWfcModelTokens;
  LChoice: TStyleProviderChoice;
  LCell, LIndex, LProvider, LCount: Integer;
  LWeight: Int64;
  LPreference: TLayerTokenPreference;
begin
  inherited Create;
  if (AModel = nil) or (Length(ARoleNames) < 1) or (Length(ARoleNames) > 6) then
    raise EAudio.Create('Musical context requires a model and ordered roles');
  if (AOptions.CellCount < 1) or (AOptions.CellCount > MaximumLayerCells) or
    (Int64(AModel.StateCount) * AOptions.CellCount > MaximumLayerStateCells) or
    ((Length(AMasks) <> 0) and (Length(AMasks) <> Length(ARoleNames) + 2)) or
    ((Length(APreferences) <> 0) and (Length(APreferences) <> Length(ARoleNames) + 2)) then
    raise EAudio.Create('Musical context exceeds its cell/state or role-control bounds');
  FOptions := AOptions;
  FRoleNames := Copy(ARoleNames);
  SetLength(LHarmonies, AModel.PublicTokenCount);
  SetLength(LRhythms, AModel.PublicTokenCount);
  for LIndex := 0 to AModel.PublicTokenCount - 1 do
  begin
    LContext := AModel.PublicTokenAt(LIndex);
    DecodeMusicalContextToken(LContext, LHarmony, LRhythm);
    LHarmonies[LIndex] := LHarmony;
    LRhythms[LIndex] := LRhythm;
    LChoice := DecodeStyleProviderChoice(spvMusicalContext, LContext);
    if (LChoice.Harmony.StepsPerOctave <> 12) or
      (Length(LChoice.Rhythm.Actions) <> Length(ARoleNames)) then
      raise EAudio.Create('Joint context must use the same twelve-step pitch domain and ordered roles');
  end;
  SetLength(FMasks, AOptions.CellCount);
  for LCell := 0 to AOptions.CellCount - 1 do
  begin
    ReportWork(AProgress, 'context_prepare_masks', wuItems, LCell, AOptions.CellCount);
    LTokens := nil;
    for LIndex := 0 to AModel.PublicTokenCount - 1 do
    begin
      LContext := AModel.PublicTokenAt(LIndex);
      LHarmony := LHarmonies[LIndex];
      LRhythm := LRhythms[LIndex];
      if TokenAllowed(AMasks, 0, LCell, LHarmony) and
        TokenAllowed(AMasks, 1, LCell, LRhythm) then
      begin
        LCount := Length(LTokens);
        SetLength(LTokens, LCount + 1);
        LTokens[LCount] := LContext;
      end;
    end;
    FMasks[LCell] := MakeWfcSequenceTokenConstraint(LCell, LTokens);
  end;
  for LIndex := 0 to AModel.PublicTokenCount - 1 do
  begin
    LContext := AModel.PublicTokenAt(LIndex);
    LHarmony := LHarmonies[LIndex];
    LRhythm := LRhythms[LIndex];
    LWeight := 1;
    for LProvider := 0 to 1 do
      if LProvider < Length(APreferences) then
        for LPreference in APreferences[LProvider] do
          if ((LProvider = 0) and (LPreference.Token = LHarmony)) or
            ((LProvider = 1) and (LPreference.Token = LRhythm)) then
          begin
            if (LPreference.Multiplier < 1) or
              (LWeight > MaximumLayerPreferenceMultiplier div LPreference.Multiplier) then
              raise EAudio.Create('Combined context preferences exceed their exact weight bound');
            LWeight := LWeight * LPreference.Multiplier;
          end;
    if LWeight > 1 then
    begin
      LCount := Length(FPreferences);
      SetLength(FPreferences, LCount + 1);
      FPreferences[LCount].Token := LContext;
      FPreferences[LCount].Multiplier := LWeight;
    end;
  end;
  SetLength(LLayers, 1);
  LLayers[0].Model := AModel;
  LLayers[0].Constraints := FMasks;
  LLayers[0].Preferences := FPreferences;
  LOptions := DefaultLayerGenerationOptions;
  LOptions.CellCount := AOptions.CellCount;
  LOptions.Seed := AOptions.Seed xor Cardinal($434F4E54);
  LOptions.Extent := wsePrefix;
  if AOptions.RequireObservedEnd then LOptions.Extent := wseWhole;
  LOptions.MaxBacktracks := AOptions.MaxBacktracks;
  LOptions.MaxPassBacktracks := AOptions.MaxPassBacktracks;
  FSession := TLearnedLayerSession.Create(LLayers, nil, [MusicalContextPassName],
    LOptions, AProgress);
end;

destructor TMusicalContextPlan.Destroy;
begin
  FSession.Free;
  inherited Destroy;
end;

function TMusicalContextPlan.TryGenerate(out AReport: TGraphNegotiationReport;
  const AProgress: TWorkProgressCallback): Boolean;
begin
  Result := FSession.TryGenerate(FAccepted, AReport, AProgress);
end;

function TMusicalContextPlan.CopyGraph: TLayerGraphPasses;
begin
  Result := FSession.CopyGraph;
end;

function TMusicalContextPlan.CopyTokens: TWfcModelTokens;
begin
  Result := Copy(FAccepted[0].Tokens);
end;

function TMusicalContextPlan.CopyStates: TWfcSequenceStateIndices;
begin
  Result := Copy(FAccepted[0].StateIndices);
end;

function TMusicalContextPlan.CopyModel: TWfcSequenceModel;
begin
  Result := FSession.CopyModel(MusicalContextPassName);
end;

function TMusicalContextPlan.CopyProvider: TStyleProviderDescription;
var
  LModel: TWfcSequenceModel;
begin
  Result := Default(TStyleProviderDescription);
  Result.Name := MusicalContextPassName;
  Result.Vocabulary := spvMusicalContext;
  Result.TicksPerQuarter := FOptions.TicksPerQuarter;
  Result.StepTicks := FOptions.StepTicks;
  Result.Timing := sptUniform;
  Result.Scope := MakeLayerScope(FOptions.CellCount, wsePrefix);
  if FOptions.RequireObservedEnd then Result.Scope.Extent := wseWhole;
  Result.RoleOrder := Copy(FRoleNames);
  Result.Preferences := CopyPreferences;
  LModel := CopyModel;
  try
    Result.Choices := CopyStyleProviderChoices(LModel, spvMusicalContext);
  finally
    LModel.Free;
  end;
end;

function TMusicalContextPlan.CopyConstraints: TWfcSequenceTokenConstraints;
var I: Integer;
begin
  Result := Copy(FMasks);
  for I := 0 to High(Result) do
    Result[I].AllowedTokens := Copy(FMasks[I].AllowedTokens);
end;

function TMusicalContextPlan.CopyPreferences: TLayerTokenPreferences;
begin
  Result := Copy(FPreferences);
end;

function TMusicalContextPlan.BindMasks(const AMasks: TVoiceMasks): TVoiceMasks;
var
  LProvider, LMask, LCell, LCount: Integer;
  LHarmony, LRhythm: String;
begin
  Result := nil;
  SetLength(Result, Length(FRoleNames) + 2);
  for LProvider := 0 to High(AMasks) do
  begin
    Result[LProvider] := Copy(AMasks[LProvider]);
    for LMask := 0 to High(Result[LProvider]) do
      Result[LProvider][LMask].AllowedTokens := Copy(AMasks[LProvider][LMask].AllowedTokens);
  end;
  for LCell := 0 to FOptions.CellCount - 1 do
  begin
    DecodeMusicalContextToken(FAccepted[0].Tokens[LCell], LHarmony, LRhythm);
    for LProvider := 0 to 1 do
    begin
      LCount := Length(Result[LProvider]);
      SetLength(Result[LProvider], LCount + 1);
      if LProvider = 0 then
        Result[LProvider][LCount] := MakeWfcSequenceTokenConstraint(LCell, [LHarmony])
      else
        Result[LProvider][LCount] := MakeWfcSequenceTokenConstraint(LCell, [LRhythm]);
    end;
  end;
end;

end.
