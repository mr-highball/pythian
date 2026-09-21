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
program pythian_tests_voices;

{$mode delphi}
{$H+}

uses
  SysUtils,
  pythian.audio,
  pythian.wfc.voices,
  pythian.wfc.providers,
  pythian.wfc.layers,
  wfc,
  wfc_model,
  wfc_sequence,
  wfc_sequence_learn,
  wfc_sequence_text,
  wfc_music,
  wfc_music_sequence,
  wfc_music_ensemble,
  wfc_music_ensemble_graph,
  wfc_music_voices_graph;

procedure Check(const AValue: Boolean; const AMessage: String);
begin
  if not AValue then
  begin
    raise EAudio.Create(AMessage);
  end;
end;

function VoiceToken(const AAction: TWfcMusicCellAction;
  const APitches: array of Integer): String;
var
  LFrame: TWfcMusicEnsembleFrame;
  LIndex: Integer;
begin
  LFrame := Default(TWfcMusicEnsembleFrame);
  SetLength(LFrame.Voices, 1);
  LFrame.Voices[0].Action := AAction;
  SetLength(LFrame.Voices[0].Tones, Length(APitches));
  for LIndex := 0 to High(APitches) do
  begin
    LFrame.Voices[0].Tones[LIndex] := MakeWfcMusicTone(APitches[LIndex], 90);
  end;
  Result := EncodeWfcMusicEnsembleFrame(LFrame);
end;

function Learn(const AFirst, ASecond, AThird: TWfcModelTokens): TWfcSequenceModel;
var
  LSamples: TWfcSequenceSamples;
begin
  SetLength(LSamples, 3);
  LSamples[0] := MakeWfcSequenceSample(AFirst);
  LSamples[1] := MakeWfcSequenceSample(ASecond);
  LSamples[2] := MakeWfcSequenceSample(AThird);
  Result := LearnSequenceModelCorpus(LSamples, 2);
end;

function SingleModel(const AFirst, ASecond, AThird: String): TWfcSequenceModel;
begin
  Result := Learn([AFirst, ASecond, AThird], [AFirst, ASecond, AThird],
    [AFirst, ASecond, AThird]);
end;

procedure FreeConfig(var AConfig: TWfcMusicVoicesGraphConfig);
var
  LIndex: Integer;
begin
  for LIndex := 0 to High(AConfig.Voices) do
  begin
    AConfig.Voices[LIndex].Model.Free;
  end;
  AConfig.RhythmModel.Free;
  AConfig.HarmonyModel.Free;
  AConfig := Default(TWfcMusicVoicesGraphConfig);
end;

function Config: TWfcMusicVoicesGraphConfig;
var
  LHarmony: String;
  LEmpty: String;
  LRest: String;
begin
  Result := Default(TWfcMusicVoicesGraphConfig);
  try
    LHarmony := EncodeWfcMusicPitchClassSet(MakeWfcMusicPitchClassSet(12, [0, 4, 7]));
    LEmpty := EncodeWfcMusicPitchClassSet(MakeWfcMusicPitchClassSet(12, []));
    LRest := VoiceToken(wmcaRest, []);
    Result.HarmonyModel := SingleModel(LHarmony, LHarmony, LEmpty);
    Result.RhythmModel := SingleModel(
      EncodeWfcMusicRhythmFrame(MakeWfcMusicRhythmFrame([wmcaAttack, wmcaAttack, wmcaAttack])),
      EncodeWfcMusicRhythmFrame(MakeWfcMusicRhythmFrame([wmcaHold, wmcaHold, wmcaHold])),
      EncodeWfcMusicRhythmFrame(MakeWfcMusicRhythmFrame([wmcaRest, wmcaRest, wmcaRest])));
    SetLength(Result.Voices, 3);
    Result.Voices[0].Model := Learn(
      [VoiceToken(wmcaAttack, [36]), VoiceToken(wmcaHold, [36]), LRest],
      [VoiceToken(wmcaAttack, [48]), VoiceToken(wmcaHold, [48]), LRest],
      [VoiceToken(wmcaAttack, [48]), VoiceToken(wmcaHold, [48]), LRest]);
    Result.Voices[1].Model := SingleModel(VoiceToken(wmcaAttack, [60, 64]),
      VoiceToken(wmcaHold, [60, 64]), LRest);
    Result.Voices[2].Model := Learn(
      [VoiceToken(wmcaAttack, [67]), VoiceToken(wmcaHold, [67]), LRest],
      [VoiceToken(wmcaAttack, [79]), VoiceToken(wmcaHold, [79]), LRest],
      [VoiceToken(wmcaAttack, [76]), VoiceToken(wmcaHold, [76]), LRest]);
    Result.Voices[0].MinPitch := 36;
    Result.Voices[0].MaxPitch := 48;
    Result.Voices[1].MinPitch := 60;
    Result.Voices[1].MaxPitch := 64;
    Result.Voices[2].MinPitch := 67;
    Result.Voices[2].MaxPitch := 79;
    Result.StepsPerOctave := 12;
    Result.HarmonyMode := wmehmExact;
    SetLength(Result.PairConstraints, 2);
    Result.PairConstraints[0].LowerVoice := 0;
    Result.PairConstraints[0].UpperVoice := 1;
    Result.PairConstraints[0].MinGap := 12;
    Result.PairConstraints[0].MaxGap := 28;
    Result.PairConstraints[0].RestPolicy := wmvprSuspend;
    Result.PairConstraints[1].LowerVoice := 1;
    Result.PairConstraints[1].UpperVoice := 2;
    Result.PairConstraints[1].MinGap := 3;
    Result.PairConstraints[1].MaxGap := 15;
    Result.PairConstraints[1].RestPolicy := wmvprSuspend;
  except
    FreeConfig(Result);
    raise;
  end;
end;

function PitchMask(const APitch: Integer): TWfcSequenceTokenConstraints;
begin
  Result := nil;
  SetLength(Result, 2);
  Result[0] := MakeWfcSequenceTokenConstraint(0, [VoiceToken(wmcaAttack, [APitch])]);
  Result[1] := MakeWfcSequenceTokenConstraint(1, [VoiceToken(wmcaHold, [APitch])]);
end;

procedure SameLayer(const ALeft, ARight: TWfcMusicVoicesGenerated; const ALayer: Integer);
var
  LCell: Integer;
begin
  Check(Length(ALeft.Layers[ALayer].Tokens) = Length(ARight.Layers[ALayer].Tokens),
    'Preserved voice scope');
  for LCell := 0 to High(ALeft.Layers[ALayer].Tokens) do
  begin
    Check(ALeft.Layers[ALayer].Tokens[LCell] = ARight.Layers[ALayer].Tokens[LCell],
      'Unrelated accepted token changed');
    Check(ALeft.Layers[ALayer].StateIndices[LCell] = ARight.Layers[ALayer].StateIndices[LCell],
      'Unrelated accepted latent state changed');
  end;
end;

procedure Exercise;
var
  LConfig: TWfcMusicVoicesGraphConfig;
  LSession: TNamedVoiceSession;
  LReplay: TNamedVoiceSession;
  LOptions: TVoiceSessionOptions;
  LGenerated: TWfcMusicVoicesGenerated;
  LBefore: TWfcMusicVoicesGenerated;
  LCopy: TWfcMusicVoicesGenerated;
  LReport: TGraphNegotiationReport;
  LSelective: TGraphSelectiveNegotiationReport;
  LProof: TWfcMusicVoicesValidationReport;
  LDescription: TStyleProviderDescription;
  LMask: TWfcSequenceTokenConstraints;
  LModel: TWfcSequenceModel;
  LVoice: Integer;
  LLead: Integer;
  LBass: Integer;
  LRejected: Boolean;
  LChoice: Integer;
  LFoundChord: Boolean;
begin
  LConfig := Config;
  LSession := nil;
  LReplay := nil;
  LModel := nil;
  try
    LOptions := DefaultVoiceSessionOptions;
    LOptions.CellCount := 3;
    LSession := TNamedVoiceSession.Create(LConfig, ['bass', 'chords', 'lead'], LOptions);
    LReplay := TNamedVoiceSession.Create(LConfig, ['bass', 'chords', 'lead'], LOptions);
    FreeConfig(LConfig);
    Check(LSession.ProviderCount = 5, 'Five independent musical models');
    Check(LSession.ProofPassCount = 3, 'Three bounded exact-coverage proof passes');
    LDescription := LSession.CopyProvider('lead');
    Check((LDescription.Vocabulary = spvVoice) and (LDescription.RoleId = 'lead') and
      (LDescription.PitchIdentity = spiAbsoluteMidi) and (LDescription.MinimumPitch = 67) and
      (LDescription.MaximumPitch = 79), 'Explicit owned role/pitch description');
    Check((Length(LDescription.Dependencies) = 3) and
      (LDescription.Dependencies[2].Name = 'chords'), 'Actual pair dependency');
    Check(scdVoice in LDescription.Choices[0].Dimensions, 'Typed voice choices');
    LDescription.Choices[0].Voice.Tones := nil;
    LDescription := LSession.CopyProvider('chords');
    LFoundChord := False;
    for LChoice := 0 to High(LDescription.Choices) do
    begin
      if Length(LDescription.Choices[LChoice].Voice.Tones) = 2 then
      begin
        LFoundChord := True;
        LDescription.Choices[LChoice].Voice.Tones[0].Pitch := 1;
        LDescription := LSession.CopyProvider('chords');
        Check(LDescription.Choices[LChoice].Voice.Tones[0].Pitch = 60,
          'Typed chord choices own their complete tone arrays');
        Break;
      end;
    end;
    Check(LFoundChord, 'Chord vocabulary retains multi-tone choices');
    LDescription := LSession.CopyProvider('harmony');
    Check(scdHarmony in LDescription.Choices[0].Dimensions, 'Typed collective harmony');
    LDescription := LSession.CopyProvider('rhythm');
    Check(Length(LDescription.Choices[0].Rhythm.Actions) = 3, 'Typed joint action vector');
    LModel := LSession.CopyModel('lead');
    Check(LModel.PublicTokenCount = 7, 'Caller-owned model copy');
    FreeAndNil(LModel);
    Check(LSession.TryGenerate(LGenerated, LReport, LProof), 'Initial independent voice solve');
    Check(LProof.Valid and (LProof.CheckedModels = 5), 'Independent full musical proof');
    Check(LGenerated.Frames[1].Voices[1].Action = wmcaHold, 'Chord holds retained');
    Check(LGenerated.Frames[2].Voices[2].Action = wmcaRest, 'Rests retained');
    Check(LReplay.TryGenerate(LCopy, LReport, LProof), 'Separate owned replay');
    for LVoice := 0 to 4 do
    begin
      SameLayer(LGenerated, LCopy, LVoice);
    end;
    LBefore := LSession.CopyAccepted;
    LGenerated.Frames[0].Voices[0].Tones[0].Pitch := 1;
    LGenerated.Layers[0].StateIndices[0] := -1;
    LGenerated.Coverage[0].Suppliers[0] := -1;
    LGenerated := LSession.CopyAccepted;
    SameLayer(LBefore, LGenerated, 0);
    Check(LGenerated.Frames[0].Voices[0].Tones[0].Pitch <> 1, 'Detached nested frames');
    Check(LGenerated.Coverage[0].Suppliers[0] >= 0, 'Detached coverage');
    LLead := 67;
    if LGenerated.Frames[0].Voices[2].Tones[0].Pitch = 67 then
    begin
      LLead := 79;
    end;
    LBass := 36;
    if LGenerated.Frames[0].Voices[0].Tones[0].Pitch = 36 then
    begin
      LBass := 48;
    end;
    LSession.SetConstraints('bass', PitchMask(LBass));
    LMask := LSession.CopyConstraints('bass');
    LMask[0].AllowedTokens[0] := 'damaged-copy';
    LMask := LSession.CopyConstraints('bass');
    Check(LMask[0].AllowedTokens[0] = VoiceToken(wmcaAttack, [LBass]), 'Detached pending mask');
    LSession.SetConstraints('lead', PitchMask(LLead));
    Check(LSession.TryRegenerate(['lead'], 937, LGenerated, LSelective, LProof),
      'Independent caller changes one declared role');
    Check(LGenerated.Frames[0].Voices[2].Tones[0].Pitch = LLead, 'Requested alternate lead');
    for LVoice := 0 to 3 do
    begin
      SameLayer(LBefore, LGenerated, LVoice);
    end;
    Check(LSession.HasPending('bass') and not LSession.HasPending('lead'),
      'Unrelated pending edit stays pending');
    LBefore := LSession.CopyAccepted;
    LSession.SetConstraints('lead', PitchMask(76));
    Check(not LSession.TryRegenerate(['lead'], 1, LGenerated, LSelective, LProof),
      'In-palette voice lacking collective G coverage must reject');
    LCopy := LSession.CopyAccepted;
    for LVoice := 0 to 4 do
    begin
      SameLayer(LBefore, LGenerated, LVoice);
      SameLayer(LBefore, LCopy, LVoice);
    end;
    Check(LSession.HasPending('lead') and LSession.HasPending('bass'), 'Failure retains pending edits');
    LMask := PitchMask(76);
    LMask[0].AllowedTokens[0] := 'unsupported';
    LRejected := False;
    try
      LSession.SetConstraints('lead', LMask);
    except
      on Exception do
      begin
        LRejected := True;
      end;
    end;
    Check(LRejected, 'Unknown tokens reject before changing pending masks');
    LMask := LSession.CopyConstraints('lead');
    Check(LMask[0].AllowedTokens[0] = VoiceToken(wmcaAttack, [76]), 'Invalid edit preserves pending mask');
    LMask := PitchMask(LLead);
    LMask[1].Position := LMask[0].Position;
    LRejected := False;
    try
      LSession.SetConstraints('lead', LMask);
    except
      on Exception do
      begin
        LRejected := True;
      end;
    end;
    Check(LRejected, 'Duplicate position rejected');
    LSession.SetConstraints('lead', PitchMask(LLead));
    Check(LSession.TryRegenerate(['lead'], 19, LGenerated, LSelective, LProof), 'Recovery after rejection');
    Check(LSession.HasPending('bass'), 'Recovery still preserves unrelated pending edit');
    Check(LSession.TryRegenerate(['bass'], 23, LGenerated, LSelective, LProof), 'Apply named pending ancestor');
    Check((LGenerated.Frames[0].Voices[0].Tones[0].Pitch = LBass) and
      not LSession.HasPending('bass'), 'Ancestor edit committed through dependent roles');
    LSession.SetConstraints('lead', nil);
    Check(LSession.TryRegenerate(['lead'], 23, LGenerated, LSelective, LProof), 'Clearing restores bounded domains');
    LRejected := False;
    try
      LSession.SetConstraints('unknown-role', nil);
    except
      on EAudio do
      begin
        LRejected := True;
      end;
    end;
    Check(LRejected, 'Unknown role rejected');
  finally
    LModel.Free;
    LReplay.Free;
    LSession.Free;
    FreeConfig(LConfig);
  end;
end;

procedure Boundaries;
var
  LConfig: TWfcMusicVoicesGraphConfig;
  LSession: TNamedVoiceSession;
  LOptions: TVoiceSessionOptions;
  LRejected: Boolean;
  LCase: Integer;
begin
  for LCase := 0 to 3 do
  begin
    LConfig := Config;
    LSession := nil;
    try
      LOptions := DefaultVoiceSessionOptions;
      LOptions.CellCount := 3;
      case LCase of
        0: LOptions.CellCount := 1025;
        1: LConfig.StepsPerOctave := 24;
        2: LConfig.Voices[0].MaxPitch := 128;
        3: LOptions.StepTicks := High(Integer);
      end;
      LRejected := False;
      try
        LSession := TNamedVoiceSession.Create(LConfig, ['bass', 'chords', 'lead'], LOptions);
      except
        on EAudio do
        begin
          LRejected := True;
        end;
      end;
      Check(LRejected, 'Bounded timing/pitch request rejected');
    finally
      LSession.Free;
      FreeConfig(LConfig);
    end;
  end;
end;

procedure PairAndRange;
var
  LConfig: TWfcMusicVoicesGraphConfig;
  LSession: TNamedVoiceSession;
  LOptions: TVoiceSessionOptions;
  LGenerated: TWfcMusicVoicesGenerated;
  LBefore: TWfcMusicVoicesGenerated;
  LReport: TGraphNegotiationReport;
  LSelective: TGraphSelectiveNegotiationReport;
  LProof: TWfcMusicVoicesValidationReport;
  LCase: Integer;
  LLayer: Integer;
begin
  for LCase := 0 to 1 do
  begin
    LConfig := Config;
    LSession := nil;
    try
      if LCase = 0 then
      begin
        LConfig.Voices[2].MaxPitch := 70;
      end
      else
      begin
        LConfig.PairConstraints[1].MaxGap := 10;
      end;
      LOptions := DefaultVoiceSessionOptions;
      LOptions.CellCount := 3;
      LSession := TNamedVoiceSession.Create(LConfig, ['bass', 'chords', 'lead'], LOptions);
      Check(LSession.TryGenerate(LGenerated, LReport, LProof), 'Constrained range/pair baseline');
      Check(LGenerated.Frames[0].Voices[2].Tones[0].Pitch = 67, 'Range/pair applied to vocabulary');
      LBefore := LSession.CopyAccepted;
      LSession.SetConstraints('lead', PitchMask(79));
      Check(not LSession.TryRegenerate(['lead'], 12, LGenerated, LSelective, LProof),
        'Range/pair rejects otherwise valid harmony and voice history');
      for LLayer := 0 to 4 do
      begin
        SameLayer(LBefore, LGenerated, LLayer);
      end;
    finally
      LSession.Free;
      FreeConfig(LConfig);
    end;
  end;
end;

procedure LayerCapacity;
var
  LConfig: TWfcMusicVoicesGraphConfig;
  LSession: TNamedVoiceSession;
  LOptions: TVoiceSessionOptions;
  LNames: TLayerNames;
  LGenerated: TWfcMusicVoicesGenerated;
  LReport: TGraphNegotiationReport;
  LProof: TWfcMusicVoicesValidationReport;
  LIndex: Integer;
  LRejected: Boolean;
  LHarmony: String;
begin
  LConfig := Default(TWfcMusicVoicesGraphConfig);
  LSession := nil;
  try
    LConfig.StepsPerOctave := 12;
    LConfig.HarmonyMode := wmehmExact;
    LHarmony := EncodeWfcMusicPitchClassSet(MakeWfcMusicPitchClassSet(12, [0]));
    LConfig.HarmonyModel := SingleModel(LHarmony, LHarmony,
      EncodeWfcMusicPitchClassSet(MakeWfcMusicPitchClassSet(12, [])));
    LConfig.RhythmModel := SingleModel(
      EncodeWfcMusicRhythmFrame(MakeWfcMusicRhythmFrame(
        [wmcaAttack, wmcaAttack, wmcaAttack, wmcaAttack, wmcaAttack, wmcaAttack])),
      EncodeWfcMusicRhythmFrame(MakeWfcMusicRhythmFrame(
        [wmcaHold, wmcaHold, wmcaHold, wmcaHold, wmcaHold, wmcaHold])),
      EncodeWfcMusicRhythmFrame(MakeWfcMusicRhythmFrame(
        [wmcaRest, wmcaRest, wmcaRest, wmcaRest, wmcaRest, wmcaRest])));
    SetLength(LConfig.Voices, 6);
    SetLength(LNames, 6);
    for LIndex := 0 to 5 do
    begin
      LNames[LIndex] := 'role-' + IntToStr(LIndex);
      LConfig.Voices[LIndex].Model := SingleModel(VoiceToken(wmcaAttack, [60]),
        VoiceToken(wmcaHold, [60]), VoiceToken(wmcaRest, []));
      LConfig.Voices[LIndex].MinPitch := 60;
      LConfig.Voices[LIndex].MaxPitch := 60;
    end;
    LOptions := DefaultVoiceSessionOptions;
    LOptions.CellCount := 3;
    LSession := TNamedVoiceSession.Create(LConfig, LNames, LOptions);
    Check((LSession.ProviderCount = 8) and (LSession.ProofPassCount = 1),
      'Eight musical layers plus separate collective proof');
    Check(LSession.TryGenerate(LGenerated, LReport, LProof), 'Six independently declared roles solve');
    FreeAndNil(LSession);
    LNames[1] := LNames[0];
    LRejected := False;
    try
      LSession := TNamedVoiceSession.Create(LConfig, LNames, LOptions);
    except
      on EAudio do
      begin
        LRejected := True;
      end;
    end;
    Check(LRejected, 'Duplicate declared role rejected');
    SetLength(LConfig.Voices, 7);
    SetLength(LNames, 7);
    LRejected := False;
    try
      LSession := TNamedVoiceSession.Create(LConfig, LNames, LOptions);
    except
      on EAudio do
      begin
        LRejected := True;
      end;
    end;
    Check(LRejected, 'Ninth musical layer rejected before graph construction');
  finally
    LSession.Free;
    FreeConfig(LConfig);
  end;
end;

begin
  Exercise;
  Boundaries;
  PairAndRange;
  LayerCapacity;
  WriteLn('Named voices: owned typed roles, collective proof, selective edits, pending preservation and recovery pass');
end.
