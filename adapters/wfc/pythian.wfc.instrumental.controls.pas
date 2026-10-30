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
  wfc_music_voices_graph;

type
  TInstrumentalGraphControls = record
    Masks: TVoiceMasks;
    Preferences: TVoicePreferences;
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

implementation

uses
  SysUtils,
  pythian.audio,
  pythian.wfc.layers,
  wfc_model,
  wfc_sequence,
  wfc_music,
  wfc_music_sequence,
  wfc_music_ensemble;

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
  LAttacks: array of Boolean;
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
        if Length(LRhythm.Actions) <> Length(AParts) then
          raise EAudio.Create('Activity controls require the actual joint rhythm role order');
        SetLength(LAttacks, Length(AParts));
        for LIndex := 0 to High(LAttacks) do
          LAttacks[LIndex] := LRhythm.Actions[LIndex] = wmcaAttack;
        LWeight := MusicalActivityWeight(AParts, LAttacks);
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

end.
