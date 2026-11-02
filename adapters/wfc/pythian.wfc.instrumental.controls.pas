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

unit pythian.wfc.instrumental.controls;

{$mode delphi}
{$H+}

interface

uses
  pythian.music.controls,
  pythian.progress,
  pythian.wfc.voices,
  pythian.wfc.layers,
  pythian.wfc.providers,
  pythian.wfc.instrumental.policy,
  wfc_model,
  wfc_sequence,
  wfc_music_ensemble,
  wfc_music_voices_graph;

type
  TInstrumentalGraphControls = record
    Masks: TVoiceMasks;
    Preferences: TVoicePreferences;
  end;
  TInstrumentalContextProjections = array of TWfcModelTokens;
  TInstrumentalContextControls = record
    Projections: TInstrumentalContextProjections;
    Preferences: TLayerTokenPreferences;
    HasDomain: Boolean;
    AllowedTokens: TWfcModelTokens;
  end;

{ Compile portable musical controls against the actual supplied vocabularies.
  Hard pitch bounds intersect existing masks at every cell. Soft role activity
  biases act on upstream joint rhythm choices, before those actions pin voices;
  tonic bias acts on harmonic pitch-class sets. Joint weights remain bounded.
  Existing guide masks remain authoritative. No learning, solving or mutation.
  Empty intersections reject with the role/cell rather than relaxing a bound.
  These preferences are a complete new vector, not a merge with other preferences. }
function CompileInstrumentalControls(const AConfig: TWfcMusicVoicesGraphConfig;
  const ACellCount, ATonic, ATonicBias: Integer; const AParts: TMusicalPartControls;
  const ABaseMasks: TVoiceMasks;
  const AProgress: TWorkProgressCallback = nil): TInstrumentalGraphControls;
{ One primary rhythm-action bridge for finite controls and positioned form
  preferences. Only public vocabulary is inspected; no graph/learning occurs. }
function RhythmActivityWeight(const ARhythm: TWfcMusicRhythmFrame;
  const AParts: TMusicalPartControls): Integer;
function SequenceActivityPreferences(const AModel: TWfcSequenceModel;
  const AKind: TStyleProviderVocabulary; const AParts: TMusicalPartControls;
  const AProgress: TWorkProgressCallback = nil): TLayerTokenPreferences;
{ ACompiled is a one-cell musical control recipe, without a source guide. This
  is the shared upstream context projection used by passage editing and saved
  controls; provider observations/models are never changed. }
function ProjectInstrumentalContextControls(const AContext: TWfcSequenceModel;
  const ARoleCount: Integer; const ACompiled: TInstrumentalGraphControls;
  const AProgress: TWorkProgressCallback = nil): TInstrumentalContextControls;
function CompileInstrumentalScopedControls(const AConfig: TWfcMusicVoicesGraphConfig;
  const ARoleNames: TLayerNames; const AContext: TWfcSequenceModel;
  const AStartTick, AEndTick: Int64; const ATicksPerQuarter, AStepTicks,
  ATonic, ATonicBias: Integer; const AParts: TMusicalPartControls;
  const AOrigin: String; const AProgress: TWorkProgressCallback = nil): TInstrumentalProviderPolicies;

implementation

uses
  SysUtils,
  pythian.audio,
  pythian.wfc.musical.context,
  wfc_music,
  wfc_music_sequence;

function RhythmActivityWeight(const ARhythm: TWfcMusicRhythmFrame;
  const AParts: TMusicalPartControls): Integer;
var
  LAttacks: array of Boolean;
  LIndex: Integer;
begin
  if Length(ARhythm.Actions) <> Length(AParts) then
    raise EAudio.Create('Activity controls require the actual joint rhythm role order');
  SetLength(LAttacks, Length(AParts));
  for LIndex := 0 to High(LAttacks) do
    LAttacks[LIndex] := ARhythm.Actions[LIndex] = wmcaAttack;
  Result := MusicalActivityWeight(AParts, LAttacks);
end;

function SequenceActivityPreferences(const AModel: TWfcSequenceModel;
  const AKind: TStyleProviderVocabulary; const AParts: TMusicalPartControls;
  const AProgress: TWorkProgressCallback): TLayerTokenPreferences;
var
  LParts: TMusicalPartControls;
  LCandidate: TLayerTokenPreferences;
  LChoice: TStyleProviderChoice;
  LToken: String;
  LWeight: Integer;
  LIndex: Integer;
  LCount: Integer;
begin
  if (AModel = nil) or not (AKind in [spvRhythm, spvMusicalContext]) or
    (Length(AParts) < 1) or (Length(AParts) > MaximumMusicalControlParts) then
    raise EAudio.Create('Activity preferences need a rhythm/context model and ordered parts');
  LParts := Copy(AParts);
  for LIndex := 0 to High(LParts) do ValidateMusicalPartControl(LParts[LIndex]);
  LCandidate := nil;
  for LIndex := 0 to AModel.PublicTokenCount - 1 do
  begin
    if (LIndex mod 32) = 0 then
      ReportWork(AProgress, 'musical_activity_tokens', wuItems, LIndex, AModel.PublicTokenCount);
    LToken := AModel.PublicTokenAt(LIndex);
    LChoice := DecodeStyleProviderChoice(AKind, LToken);
    LWeight := RhythmActivityWeight(LChoice.Rhythm, LParts);
    if LWeight = 1 then Continue;
    LCount := Length(LCandidate);
    if LCount >= MaximumLayerPreferences then
      raise EAudio.Create('Activity preferences exceed the public token preference budget');
    SetLength(LCandidate, LCount + 1);
    LCandidate[LCount] := MakeLayerTokenPreference(LToken, LWeight);
  end;
  ReportWork(AProgress, 'musical_activity_preferences_ready', wuItems, 1, 1);
  Result := LCandidate;
end;

function CopyMasks(const ASource: TVoiceMasks;
  const AProgress: TWorkProgressCallback): TVoiceMasks;
var
  LProvider: Integer;
begin
  Result := nil;
  SetLength(Result, Length(ASource));
  for LProvider := 0 to High(ASource) do
  begin
    Result[LProvider] := CopyVoiceTokenConstraints(ASource[LProvider], AProgress, LProvider + 1);
  end;
end;

function Contains(const ATokens: TWfcModelTokens; const AToken: String): Boolean;
var
  LToken: String;
begin
  Result := False;
  for LToken in ATokens do
  begin
    if LToken = AToken then Exit(True);
  end;
end;

function CompileInstrumentalControls(const AConfig: TWfcMusicVoicesGraphConfig;
  const ACellCount, ATonic, ATonicBias: Integer; const AParts: TMusicalPartControls;
  const ABaseMasks: TVoiceMasks;
  const AProgress: TWorkProgressCallback): TInstrumentalGraphControls;
var
  LProvider: Integer;
  LRole: Integer;
  LCell: Integer;
  LToken: Integer;
  LMask: Integer;
  LIndex: Integer;
  LWeight: Integer;
  LCount: Integer;
  LAllowed: TWfcModelTokens;
  LIntersection: TWfcModelTokens;
  LModel: TWfcSequenceModel;
  LFrame: TWfcMusicEnsembleFrame;
  LRhythm: TWfcMusicRhythmFrame;
  LHarmony: TWfcMusicPitchClassSet;
  LTone: TWfcMusicTone;
  LChoice: String;
  LKeep: Boolean;
  LHasTonic: Boolean;
  LRange: Boolean;
  LHasMasks: Boolean;
  LHasPreferences: Boolean;
begin
  Result := Default(TInstrumentalGraphControls);
  if (AConfig.StepsPerOctave <> 12) or
    (Length(AParts) <> Length(AConfig.Voices)) or (Length(AParts) < 1) or
    (Length(AParts) > 6) or (ACellCount < 1) or (ACellCount > MaximumLayerCells) or
    (ACellCount <> Trunc(ACellCount)) or (ATonic < 0) or (ATonic > 11) or
    (ATonic <> Trunc(ATonic)) or ((Length(ABaseMasks) <> 0) and
    (Length(ABaseMasks) <> Length(AParts) + 2)) then
  begin
    raise EAudio.Create('Musical graph controls require matching twelve-step roles and bounded cells');
  end;
  MusicalBiasWeight(ATonicBias, True);
  for LRole := 0 to High(AParts) do
  begin
    ValidateMusicalPartControl(AParts[LRole]);
  end;
  Result.Masks := CopyMasks(ABaseMasks, AProgress);
  SetLength(Result.Masks, Length(AParts) + 2);
  SetLength(Result.Preferences, Length(AParts) + 2);
  for LProvider := 0 to High(Result.Masks) do
  begin
    LModel := WfcMusicVoicesModelAt(AConfig, LProvider);
    if LModel = nil then raise EAudio.Create('Musical controls require actual provider models');
    if Int64(LModel.PublicTokenCount) * ACellCount > MaximumLayerStateCells then
    begin
      raise EAudio.Create('Musical controls exceed the token/cell preparation budget');
    end;
    ValidateSequenceTokenConstraints(LModel, ACellCount, Result.Masks[LProvider]);
    LAllowed := nil;
    LRole := LProvider - 2;
    LRange := False;
    if LRole >= 0 then
    begin
      LRange := (AParts[LRole].MinimumPitch <> 0) or
        (AParts[LRole].MaximumPitch <> 127);
    end;
    for LToken := 0 to LModel.PublicTokenCount - 1 do
    begin
      if (LToken mod 32) = 0 then
      begin
        ReportWork(AProgress, 'musical_control_tokens', wuItems,
          LToken, LModel.PublicTokenCount, LProvider + 1);
      end;
      LChoice := LModel.PublicTokenAt(LToken);
      LWeight := 1;
      LKeep := True;
      if LProvider = 0 then
      begin
        LHarmony := DecodeWfcMusicPitchClassSet(LChoice);
        LHasTonic := False;
        for LIndex := 0 to High(LHarmony.PitchClasses) do
        begin
          LHasTonic := LHasTonic or (LHarmony.PitchClasses[LIndex] = ATonic);
        end;
        LWeight := MusicalBiasWeight(ATonicBias, LHasTonic);
      end
      else if LProvider = 1 then
      begin
        LRhythm := DecodeWfcMusicRhythmFrame(LChoice);
        LWeight := RhythmActivityWeight(LRhythm, AParts);
      end
      else if LRole >= 0 then
      begin
        LFrame := DecodeWfcMusicEnsembleFrame(LChoice);
        if Length(LFrame.Voices) <> 1 then
        begin
          raise EAudio.Create('A musical role control requires single-role tokens');
        end;
        for LTone in LFrame.Voices[0].Tones do
        begin
          LKeep := LKeep and (LTone.Pitch >= AParts[LRole].MinimumPitch) and
            (LTone.Pitch <= AParts[LRole].MaximumPitch);
        end;
      end;
      if LKeep then
      begin
        LCount := Length(LAllowed);
        SetLength(LAllowed, LCount + 1);
        LAllowed[LCount] := LChoice;
      end;
      if LWeight > 1 then
      begin
        LCount := Length(Result.Preferences[LProvider]);
        if LCount >= MaximumLayerPreferences then
        begin
          raise EAudio.Create('Musical preferences exceed the actual token preference budget');
        end;
        SetLength(Result.Preferences[LProvider], LCount + 1);
        Result.Preferences[LProvider][LCount] := MakeLayerTokenPreference(LChoice, LWeight);
      end;
    end;
    if not LRange then Continue;
    if Length(LAllowed) = 0 then
    begin
      raise EAudio.CreateFmt('Pitch bounds leave role %d with no available choices', [LRole + 1]);
    end;
    for LCell := 0 to ACellCount - 1 do
    begin
      if (LCell mod 32) = 0 then
      begin
        ReportWork(AProgress, 'musical_control_cells', wuItems,
          LCell, ACellCount, LProvider + 1);
      end;
      LMask := -1;
      for LIndex := 0 to High(Result.Masks[LProvider]) do
      begin
        if Result.Masks[LProvider][LIndex].Position = LCell then LMask := LIndex;
      end;
      LIntersection := nil;
      for LChoice in LAllowed do
      begin
        if (LMask < 0) or
          Contains(Result.Masks[LProvider][LMask].AllowedTokens, LChoice) then
        begin
          LCount := Length(LIntersection);
          SetLength(LIntersection, LCount + 1);
          LIntersection[LCount] := LChoice;
        end;
      end;
      if Length(LIntersection) = 0 then
      begin
        raise EAudio.CreateFmt('Pitch bounds conflict with role %d cell %d', [LRole + 1, LCell]);
      end;
      if LMask < 0 then
      begin
        LMask := Length(Result.Masks[LProvider]);
        SetLength(Result.Masks[LProvider], LMask + 1);
        Result.Masks[LProvider][LMask].Position := LCell;
      end;
      Result.Masks[LProvider][LMask].AllowedTokens := LIntersection;
    end;
  end;
  LHasMasks := False;
  LHasPreferences := False;
  for LProvider := 0 to High(Result.Masks) do
  begin
    LHasMasks := LHasMasks or (Length(Result.Masks[LProvider]) > 0);
    LHasPreferences := LHasPreferences or (Length(Result.Preferences[LProvider]) > 0);
  end;
  if not LHasMasks then Result.Masks := nil;
  if not LHasPreferences then Result.Preferences := nil;
  ReportWork(AProgress, 'musical_controls_ready', wuItems, 1, 1);
end;

function ProjectInstrumentalContextControls(const AContext: TWfcSequenceModel;
  const ARoleCount: Integer; const ACompiled: TInstrumentalGraphControls;
  const AProgress: TWorkProgressCallback): TInstrumentalContextControls;
var T, P: Integer; LMask: TWfcSequenceTokenConstraint; LPreference: TLayerTokenPreference;
  LMasks: TVoiceMasks; LKeep: Boolean; LWeight: Integer;
begin
  Result := Default(TInstrumentalContextControls);
  if AContext = nil then Exit;
  for P := 0 to High(ACompiled.Masks) do
    Result.HasDomain := Result.HasDomain or (Length(ACompiled.Masks[P]) > 0);
  SetLength(Result.Projections, AContext.PublicTokenCount);
  for T := 0 to AContext.PublicTokenCount - 1 do
  begin
    if (T mod 32) = 0 then
      ReportWork(AProgress, 'musical_context_controls', wuItems, T, AContext.PublicTokenCount);
    LMasks := BindMusicalContextTokens([AContext.PublicTokenAt(T)], ARoleCount, nil, True);
    SetLength(Result.Projections[T], ARoleCount + 2);
    LKeep := True; LWeight := 1;
    for P := 0 to ARoleCount + 1 do
    begin
      Result.Projections[T][P] := LMasks[P][0].AllowedTokens[0];
      if P < Length(ACompiled.Masks) then for LMask in ACompiled.Masks[P] do
      begin
        if LMask.Position <> 0 then
          raise EAudio.Create('Context control projection requires a one-cell recipe');
        LKeep := LKeep and Contains(LMask.AllowedTokens, Result.Projections[T][P]);
      end;
      if P < Length(ACompiled.Preferences) then for LPreference in ACompiled.Preferences[P] do
        if LPreference.Token = Result.Projections[T][P] then
        begin
          if LWeight > MaximumLayerPreferenceMultiplier div LPreference.Multiplier then
            raise EAudio.Create('Combined musical context preference exceeds its bound');
          LWeight := LWeight * LPreference.Multiplier;
        end;
    end;
    if LKeep and Result.HasDomain then
    begin
      SetLength(Result.AllowedTokens, Length(Result.AllowedTokens) + 1);
      Result.AllowedTokens[High(Result.AllowedTokens)] := AContext.PublicTokenAt(T);
    end;
    if LWeight > 1 then
    begin
      SetLength(Result.Preferences, Length(Result.Preferences) + 1);
      Result.Preferences[High(Result.Preferences)] := MakeLayerTokenPreference(AContext.PublicTokenAt(T), LWeight);
    end;
  end;
  if Result.HasDomain and (Length(Result.AllowedTokens) = 0) then
    raise EAudio.Create('Pitch bounds leave no supported musical context');
end;

function CompileInstrumentalScopedControls(const AConfig: TWfcMusicVoicesGraphConfig;
  const ARoleNames: TLayerNames; const AContext: TWfcSequenceModel;
  const AStartTick, AEndTick: Int64; const ATicksPerQuarter, AStepTicks,
  ATonic, ATonicBias: Integer; const AParts: TMusicalPartControls;
  const AOrigin: String; const AProgress: TWorkProgressCallback): TInstrumentalProviderPolicies;
var LCompiled: TInstrumentalGraphControls; LContext: TInstrumentalContextControls;
  P: Integer; LKey: String; LAllowed: TWfcModelTokens; LPreferences: TLayerTokenPreferences;
  procedure Add(const AKey: String; const AHasDomain: Boolean;
    const ATokens: TWfcModelTokens; const APreferences: TLayerTokenPreferences);
  var N: Integer;
  begin
    if not AHasDomain and (Length(APreferences) = 0) then Exit;
    N := Length(Result); SetLength(Result, N + 1); Result[N].Key := AKey;
    SetLength(Result[N].Scopes, 1);
    with Result[N].Scopes[0] do
    begin
      StartTick := AStartTick; EndTick := AEndTick;
      TicksPerQuarter := ATicksPerQuarter; StepTicks := AStepTicks; Origin := AOrigin;
      HasDomain := AHasDomain; AllowedTokens := Copy(ATokens); Preferences := Copy(APreferences);
    end;
  end;
begin
  Result := nil;
  if Length(ARoleNames) <> Length(AConfig.Voices) then
    raise EAudio.Create('Scoped controls require the actual role order');
  LCompiled := CompileInstrumentalControls(AConfig, 1, ATonic, ATonicBias, AParts, nil, AProgress);
  for P := 0 to Length(ARoleNames) + 1 do
  begin
    LKey := 'harmony';
    if P = 1 then LKey := 'rhythm';
    if P >= 2 then LKey := ARoleNames[P - 2];
    LAllowed := nil; LPreferences := nil;
    if (P < Length(LCompiled.Masks)) and (Length(LCompiled.Masks[P]) > 0) then
      LAllowed := LCompiled.Masks[P][0].AllowedTokens;
    if P < Length(LCompiled.Preferences) then LPreferences := LCompiled.Preferences[P];
    Add(LKey, Length(LAllowed) > 0, LAllowed, LPreferences);
  end;
  LContext := ProjectInstrumentalContextControls(AContext, Length(ARoleNames), LCompiled, AProgress);
  Add(MusicalContextPassName, LContext.HasDomain, LContext.AllowedTokens, LContext.Preferences);
end;

end.
