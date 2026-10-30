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
  { One actual WFC context pass retains synchronized symbolic role histories.
    H/R and the explicitly selected role constrain the next conditional graph.
    Other role pitches are not pinned; their named graphs remain independently solved.
    No cross-group backtracking is claimed. }
  TMusicalContextPlan = class
  private
    FSession: TLearnedLayerSession;
    FAccepted: TLayerSequences;
    FMasks: TWfcSequenceTokenConstraints;
    FPreferences: TLayerTokenPreferences;
    FOptions: TVoiceSessionOptions;
    FRoleNames: TLayerNames;
    FDrivenRole: Integer;
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
    property DrivenRole: Integer read FDrivenRole;
  end;

implementation

uses SysUtils, pythian.audio, wfc_music_ensemble;

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

function DrivenVoiceToken(const AChoice: TStyleProviderChoice): String;
var
  LFrame: TWfcMusicEnsembleFrame;
begin
  Result := '';
  if AChoice.Context.DrivenRole < 0 then Exit;
  SetLength(LFrame.Voices, 1);
  LFrame.Voices[0] := AChoice.Context.Frame.Voices[AChoice.Context.DrivenRole];
  Result := EncodeWfcMusicEnsembleFrame(LFrame);
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
  LDrivenTokens: TWfcModelTokens;
  LChoice: TStyleProviderChoice;
  LCell, LIndex, LProvider, LCount: Integer;
  LTargetProvider: Integer;
  LLastProvider: Integer;
  LTargetToken: String;
  LWeight: Int64;
  LPreference: TLayerTokenPreference;
begin
  inherited Create;
  FDrivenRole := -1;
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
  SetLength(LDrivenTokens, AModel.PublicTokenCount);
  if AModel.PublicTokenCount < 1 then
    raise EAudio.Create('Musical context has no symbolic vocabulary');
  for LIndex := 0 to AModel.PublicTokenCount - 1 do
  begin
    LContext := AModel.PublicTokenAt(LIndex);
    LChoice := DecodeStyleProviderChoice(spvMusicalContext, LContext);
    if LIndex = 0 then FDrivenRole := LChoice.Context.DrivenRole;
    if LChoice.Context.DrivenRole <> FDrivenRole then
      raise EAudio.Create('Musical context cannot mix driven-role assignments');
    LHarmony := EncodeWfcMusicPitchClassSet(LChoice.Harmony);
    LRhythm := EncodeWfcMusicRhythmFrame(LChoice.Rhythm);
    LHarmonies[LIndex] := LHarmony;
    LRhythms[LIndex] := LRhythm;
    LDrivenTokens[LIndex] := DrivenVoiceToken(LChoice);
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
        TokenAllowed(AMasks, 1, LCell, LRhythm) and
        ((FDrivenRole < 0) or TokenAllowed(AMasks, FDrivenRole + 2, LCell,
          LDrivenTokens[LIndex])) then
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
    LLastProvider := 1;
    if FDrivenRole >= 0 then LLastProvider := 2;
    for LProvider := 0 to LLastProvider do
    begin
      LTargetProvider := LProvider;
      if LProvider = 2 then LTargetProvider := FDrivenRole + 2;
      case LProvider of
        0: LTargetToken := LHarmony;
        1: LTargetToken := LRhythm;
      else LTargetToken := LDrivenTokens[LIndex];
      end;
      if LTargetProvider < Length(APreferences) then
        for LPreference in APreferences[LTargetProvider] do
          if LPreference.Token = LTargetToken then
          begin
            if (LPreference.Multiplier < 1) or
              (LWeight > MaximumLayerPreferenceMultiplier div LPreference.Multiplier) then
              raise EAudio.Create('Combined context preferences exceed their exact weight bound');
            LWeight := LWeight * LPreference.Multiplier;
          end;
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
var
  LFrames: TWfcMusicEnsembleFrames;
  LIndex: Integer;
begin
  Result := FSession.TryGenerate(FAccepted, AReport, AProgress);
  if not Result then Exit;
  SetLength(LFrames, Length(FAccepted[0].Tokens));
  for LIndex := 0 to High(LFrames) do
  begin
    ReportWork(AProgress, 'context_validate_witness', wuItems, LIndex, Length(LFrames));
    LFrames[LIndex] := DecodeMusicalContextToken(FAccepted[0].Tokens[LIndex]).Frame;
  end;
  ValidateWfcMusicEnsembleFrames(LFrames);
  ReportWork(AProgress, 'context_validate_witness', wuItems, Length(LFrames), Length(LFrames));
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
  Result.PitchIdentity := spiAbsoluteMidi;
  Result.MinimumPitch := 0;
  Result.MaximumPitch := 127;
  Result.TicksPerQuarter := FOptions.TicksPerQuarter;
  Result.StepTicks := FOptions.StepTicks;
  Result.Timing := sptUniform;
  Result.Scope := MakeLayerScope(FOptions.CellCount, wsePrefix);
  if FOptions.RequireObservedEnd then Result.Scope.Extent := wseWhole;
  Result.RoleOrder := Copy(FRoleNames);
  if FDrivenRole >= 0 then Result.RoleId := FRoleNames[FDrivenRole];
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
  LChoice: TStyleProviderChoice;
  LTargetProvider: Integer;
  LLastProvider: Integer;
  LTargetToken: String;
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
    LChoice := DecodeStyleProviderChoice(spvMusicalContext, FAccepted[0].Tokens[LCell]);
    LHarmony := EncodeWfcMusicPitchClassSet(LChoice.Harmony);
    LRhythm := EncodeWfcMusicRhythmFrame(LChoice.Rhythm);
    LLastProvider := 1;
    if FDrivenRole >= 0 then LLastProvider := 2;
    for LProvider := 0 to LLastProvider do
    begin
      LTargetProvider := LProvider;
      if LProvider = 2 then LTargetProvider := FDrivenRole + 2;
      case LProvider of
        0: LTargetToken := LHarmony;
        1: LTargetToken := LRhythm;
      else LTargetToken := DrivenVoiceToken(LChoice);
      end;
      LCount := Length(Result[LTargetProvider]);
      SetLength(Result[LTargetProvider], LCount + 1);
      Result[LTargetProvider][LCount] := MakeWfcSequenceTokenConstraint(LCell, [LTargetToken]);
    end;
  end;
end;

end.
