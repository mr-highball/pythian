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
  pythian.synth,
  pythian.automation,
  pythian.envelope,
  pythian.oscillator,
  pythian.wfc.instrument,
  pythian.wfc.voices,
  pythian.wfc.providers,
  pythian.wfc.layers,
  pythian.wfc.provider.contracts,
  pythian.wfc.context,
  pythian.wfc.style,
  pythian.time,
  wfc,
  wfc_model,
  wfc_sequence,
  wfc_sequence_learn,
  wfc_sequence_text,
  wfc_sequence_graph,
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

procedure ProviderReplacement;
var
  LConfig: TWfcMusicVoicesGraphConfig;
  LSession: TNamedVoiceSession;
  LOptions: TVoiceSessionOptions;
  LContract: TProviderContract;
  LBad: TProviderContract;
  LGenerated: TWfcMusicVoicesGenerated;
  LBefore: TWfcMusicVoicesGenerated;
  LModel: TWfcSequenceModel;
  LBadModel: TWfcSequenceModel;
  LReport: TGraphNegotiationReport;
  LReplacement: TLayerModelReplacementReport;
  LProof: TWfcMusicVoicesValidationReport;
  LIndex: Integer;
  LCase: Integer;
  LLead: Integer;
  LRejected: Boolean;
begin
  LConfig := Config;
  LSession := nil;
  LModel := nil;
  LBadModel := nil;
  try
    LOptions := DefaultVoiceSessionOptions;
    LOptions.CellCount := 3;
    LSession := TNamedVoiceSession.Create(LConfig, ['bass', 'chords', 'lead'], LOptions);
    FreeConfig(LConfig);
    Check(LSession.TryGenerate(LGenerated, LReport, LProof), 'Replacement baseline');
    LBefore := LSession.CopyAccepted;
    LLead := 67;
    if LGenerated.Frames[0].Voices[2].Tones[0].Pitch = 67 then
    begin
      LLead := 79;
    end;
    LModel := SingleModel(VoiceToken(wmcaAttack, [LLead]), VoiceToken(wmcaHold, [LLead]),
      VoiceToken(wmcaRest, []));
    LBadModel := SingleModel(VoiceToken(wmcaAttack, [76]), VoiceToken(wmcaHold, [76]),
      VoiceToken(wmcaRest, []));
    LSession.SetConstraints('bass', PitchMask(36));
    LContract := LSession.CopyContract('lead');
    LContract.Source.SourceSha256 := StringOfChar('a', 64);
    LContract.Source.MeasurementIdentity := 'authored-clock-fixture';
    LContract.Source.ConversionIdentity := 'explicit-exact-ppq-960-to-480';
    LContract.Source.SampleRate := 44100;
    LContract.Source.SourceFrames := 33075;
    LContract.Source.SourceTicksPerQuarter := 960;
    LContract.Source.SourceLengthTicks := 1440;
    SetLength(LContract.Source.TempoChanges, 1);
    LContract.Source.TempoChanges[0].MicrosecondsPerQuarter := 500000;
    SetLength(LContract.Source.OriginalTicks, 4);
    SetLength(LContract.Source.OriginalFrames, 4);
    for LIndex := 0 to 3 do
    begin
      LContract.Source.OriginalTicks[LIndex] := LIndex * 480;
      LContract.Source.OriginalFrames[LIndex] := LIndex * 11025;
    end;
    Check(LSession.TryReplaceProvider('lead', LModel, LContract, 531,
      LGenerated, LReplacement, LProof), 'Compatible declared role/model replacement');
    Check(LGenerated.Frames[0].Voices[2].Tones[0].Pitch = LLead, 'Replacement changed the role');
    Check(LReplacement.ReplacedLayerIndex = 4, 'Named replacement identity');
    for LIndex := 0 to 3 do
    begin
      SameLayer(LBefore, LGenerated, LIndex);
    end;
    Check(LSession.HasPending('bass'), 'Replacement preserves unrelated pending edits');
    LContract.Source.OriginalFrames[1] := 1;
    LContract := LSession.CopyContract('lead');
    Check(LContract.Source.OriginalFrames[1] = 11025, 'Original measurement mapping owned');
    Check((LContract.Source.SourceTicksPerQuarter = 960) and
      (LContract.TicksPerQuarter = 480), 'Original and converted PPQ both recoverable');
    LBefore := LSession.CopyAccepted;
    for LCase := 0 to 10 do
    begin
      LBad := CopyProviderContract(LContract);
      case LCase of
        0: LBad.RoleId := 'bass';
        1: LBad.TicksPerQuarter := 240;
        2: LBad.MusicalDomain := 'unrelated-clock';
        3: LBad.Vocabulary := spvOnsets;
        4: LBad.PitchBasis := ppbRelativeKey;
        5: LBad.KeyReference := 'different-key';
        6: LBad.PaletteIdentity := 'numeric-palette';
        7: LBad.TimeGrid.TicksPerCell := 241;
        8: LBad.UnknownPolicy := 'unknown-is-rest';
        9: Inc(LBad.Source.OriginalFrames[1]);
        10: LBad.Source.ConversionIdentity := '';
      end;
      LRejected := False;
      try
        LSession.TryReplaceProvider('lead', LModel, LBad, 99, LGenerated, LReplacement, LProof);
      except
        on LException: Exception do
        begin
          LRejected := LException.Message <> '';
        end;
      end;
      Check(LRejected, 'Incompatible provider must reject with a diagnostic');
      for LIndex := 0 to 4 do
      begin
        SameLayer(LBefore, LGenerated, LIndex);
      end;
      Check(LSession.HasPending('bass'), 'Incompatible replacement retains unrelated pending edits');
    end;
    Check(not LSession.TryReplaceProvider('lead', LBadModel, LContract, 77,
      LGenerated, LReplacement, LProof), 'Collectively infeasible candidate preserves old model');
    for LIndex := 0 to 4 do
    begin
      SameLayer(LBefore, LGenerated, LIndex);
    end;
    FreeAndNil(LModel);
    LModel := LSession.CopyModel('lead');
    Check(LModel.FindPublicToken(VoiceToken(wmcaAttack, [LLead])) >= 0,
      'Failed replacement retains accepted model');
    FreeAndNil(LModel);
    LModel := LSession.CopyModel('rhythm');
    LBad := LSession.CopyContract('rhythm');
    Check((LBad.RoleOrder[0] = 'bass') and (LBad.RoleOrder[2] = 'lead'),
      'Joint rhythm declares actual ordered role identities');
    LBad.RoleOrder[0] := 'lead';
    LBad.RoleOrder[2] := 'bass';
    LRejected := False;
    try
      LSession.TryReplaceProvider('rhythm', LModel, LBad, 99, LGenerated, LReplacement, LProof);
    except
      on EAudio do LRejected := True;
    end;
    Check(LRejected, 'Equal-length joint role permutation rejects before mutation');
    LBad := LSession.CopyContract('rhythm');
    Check(LBad.RoleOrder[0] = 'bass', 'Joint role metadata owns its vector');
    for LIndex := 0 to 4 do SameLayer(LBefore, LGenerated, LIndex);
    Check(LSession.HasPending('bass'), 'Rejected role permutation retains pending edit');
  finally
    LBadModel.Free;
    LModel.Free;
    LSession.Free;
    FreeConfig(LConfig);
  end;
end;

function ContractFor(const AName: String; const AVocabulary: TStyleProviderVocabulary;
  const ACount, AStep: Integer): TProviderContract;
begin
  Result := Default(TProviderContract);
  Result.Name := AName;
  Result.Vocabulary := AVocabulary;
  Result.MusicalDomain := 'authored-composition';
  Result.TicksPerQuarter := 480;
  Result.Scope := MakeLayerScope(ACount, wseWhole);
  Result.TimeGrid := MakeLayerTimeGrid(0, AStep);
  Result.UnknownPolicy := ProviderUnknownPolicy(AVocabulary);
end;

function LearnOne(const AFirst, ASecond: TWfcModelTokens): TWfcSequenceModel;
var
  LSamples: TWfcSequenceSamples;
begin
  SetLength(LSamples, 2);
  LSamples[0] := MakeWfcSequenceSample(AFirst);
  LSamples[1] := MakeWfcSequenceSample(ASecond);
  Result := LearnSequenceModelCorpus(LSamples, 1);
end;

procedure MappedComposition;
var
  LLayers: TLearnedLayers;
  LProjections: TLayerProjections;
  LContracts: TProviderContracts;
  LSession: TCompatibleProviderSession;
  LOptions: TLayerGenerationOptions;
  LGenerated: TLayerSequences;
  LBefore: TLayerSequences;
  LReport: TGraphNegotiationReport;
  LReplacement: TLayerModelReplacementReport;
  LModel: TWfcSequenceModel;
  LIndex: Integer;
  LCase: Integer;
  LRejected: Boolean;
begin
  LLayers := nil;
  LSession := nil;
  LModel := nil;
  SetLength(LLayers, 3);
  SetLength(LContracts, 3);
  SetLength(LProjections, 1);
  try
    LLayers[0].Model := LearnOne([TempoContextToken(500000)], [TempoContextToken(600000)]);
    LLayers[1].Model := LearnOne([RhythmOnsetToken, RhythmOnsetToken],
      [RhythmEmptyToken, RhythmEmptyToken]);
    LLayers[2].Model := SingleModel(TempoContextToken(700000), TempoContextToken(700000),
      TempoContextToken(700000));
    LContracts[0] := ContractFor('clock-choice', spvTempo, 1, 960);
    LContracts[1] := ContractFor('onsets', spvOnsets, 2, 480);
    LContracts[1].TimeGrid := MakeLayerTimePartition([0, 240, 960]);
    LContracts[2] := ContractFor('independent', spvTempo, 3, 320);
    LProjections[0].Provider := 0;
    LProjections[0].Consumer := 1;
    LProjections[0].TimeMapping := ltmWholeCell;
    SetLength(LProjections[0].Rules, 2);
    LProjections[0].Rules[0] := MakeWfcSequenceProjectionRule(RhythmOnsetToken,
      [TempoContextToken(500000)]);
    LProjections[0].Rules[1] := MakeWfcSequenceProjectionRule(RhythmEmptyToken,
      [TempoContextToken(600000)]);
    LOptions := DefaultLayerGenerationOptions;
    LSession := TCompatibleProviderSession.Create(LLayers, LProjections, LContracts, LOptions);
    Check(LSession.TryGenerate(LGenerated, LReport), 'Uniform broadcast to fixed unequal cells');
    LBefore := LSession.CopyAccepted;
    { The mapping rules intentionally include both provider alternatives. A model
      replacement must retain all referenced tokens, even if its chosen path changes. }
    LModel := LearnOne([TempoContextToken(600000)], [TempoContextToken(500000)]);
    LLayers[0].Constraints := nil;
    SetLength(LLayers[0].Constraints, 1);
    LLayers[0].Constraints[0] := MakeWfcSequenceTokenConstraint(0, [TempoContextToken(600000)]);
    LSession.SetConstraints('clock-choice', LLayers[0].Constraints);
    Check(LSession.TryReplaceProvider('clock-choice', LModel, LContracts[0], 33,
      LGenerated, LReplacement), 'Mapped compatible provider replacement');
    Check((LGenerated[1].Tokens[0] = RhythmEmptyToken) and
      (LGenerated[1].Tokens[1] = RhythmEmptyToken), 'Dependent mapped choices rebuilt');
    for LIndex := 0 to High(LBefore[2].StateIndices) do
    begin
      Check(LBefore[2].StateIndices[LIndex] = LGenerated[2].StateIndices[LIndex],
        'Mapped replacement retains unrelated latent states');
    end;
    FreeAndNil(LSession);
    FreeAndNil(LModel);
    FreeAndNil(LLayers[0].Model);
    FreeAndNil(LLayers[1].Model);
    LLayers[0].Constraints := nil;
    LLayers[0].Model := LearnOne([TempoContextToken(500000), TempoContextToken(600000)],
      [TempoContextToken(500000), TempoContextToken(600000)]);
    LLayers[1].Model := LearnOne([RhythmOnsetToken], [RhythmOnsetToken]);
    LContracts[0] := ContractFor('clock-choice', spvTempo, 2, 480);
    LContracts[0].TimeGrid := MakeLayerTimePartition([0, 240, 960]);
    LContracts[1] := ContractFor('onsets', spvOnsets, 1, 960);
    SetLength(LProjections[0].Rules, 1);
    for LCase := 0 to 1 do
    begin
      if LCase = 0 then
      begin
        LProjections[0].TimeMapping := ltmStartTick;
      end
      else
      begin
        LProjections[0].TimeMapping := ltmWholeCell;
      end;
      LSession := TCompatibleProviderSession.Create(LLayers, LProjections, LContracts, LOptions);
      Check(LSession.TryGenerate(LGenerated, LReport) = (LCase = 0),
        'Start-tick sample differs from whole-span conjunction');
      FreeAndNil(LSession);
    end;
    LContracts[1].TimeGrid := MakeLayerTimeGrid(960, 240);
    LRejected := False;
    try
      LSession := TCompatibleProviderSession.Create(LLayers, LProjections, LContracts, LOptions);
    except
      on EAudio do
      begin
        LRejected := True;
      end;
    end;
    Check(LRejected, 'Exclusive endpoint cannot supply a consumer');
    LContracts[1].TimeGrid := MakeLayerTimeGrid(0, 960);
    LContracts[0].TicksPerQuarter := 960;
    LRejected := False;
    try
      LSession := TCompatibleProviderSession.Create(LLayers, LProjections, LContracts, LOptions);
    except
      on EAudio do
      begin
        LRejected := True;
      end;
    end;
    Check(LRejected, 'No implicit PPQ normalization across composed providers');
  finally
    LSession.Free;
    LModel.Free;
    for LIndex := 0 to High(LLayers) do
    begin
      LLayers[LIndex].Model.Free;
    end;
  end;
end;

function SameAudio(const ALeft, ARight: TAudioClip): Boolean;
var
  LFrame: Integer;
  LChannel: Integer;
begin
  Result := False;
  if ALeft.FrameCount <> ARight.FrameCount then
  begin
    Exit;
  end;
  for LFrame := 0 to ALeft.FrameCount - 1 do
  begin
    for LChannel := 0 to 1 do
    begin
      if ALeft.SampleAt(LFrame, LChannel) <> ARight.SampleAt(LFrame, LChannel) then
      begin
        Exit;
      end;
    end;
  end;
  Result := True;
end;

function RenderFixtureRole(const AGenerated: TWfcMusicVoicesGenerated;
  const ARole: Integer): TAudioClip;
var
  LTones: TFrameTones;
  LIndex: Integer;
begin
  { This fixture has an attack, one hold and one rest at 240 ticks/cell,
    480 PPQ, 500000 microseconds/quarter and 8000 frames/second. }
  SetLength(LTones, Length(AGenerated.Frames[0].Voices[ARole].Tones));
  for LIndex := 0 to High(LTones) do
  begin
    LTones[LIndex].GateFrames := 4000;
    LTones[LIndex].FrequencyHz := MidiFrequency(AGenerated.Frames[0].Voices[ARole].Tones[LIndex].Pitch);
    LTones[LIndex].Velocity := AGenerated.Frames[0].Voices[ARole].Tones[LIndex].Velocity / 127;
    LTones[LIndex].Voice := DefaultSynthVoice;
    LTones[LIndex].Seed := Cardinal(ARole + 1);
  end;
  Result := RenderFrameTones(LTones, 8000, 6000);
end;

procedure SoundControls;
var
  LZones: TStyleInstrumentZones;
  LInstrument: TStyleInstrument;
  LCurve: TAutomationCurve;
  LRelease: TAutomationCurve;
  LEnvelope: TGateEnvelope;
  LPoints: TAutomationPoints;
  LBase: array[0..2] of TAudioClip;
  LRendered: TAudioClip;
  LPlan: TFrameTones;
  LRole: Integer;
  LEdit: Integer;
begin
  FillChar(LBase, SizeOf(LBase), 0);
  LInstrument := nil;
  LCurve := nil;
  LRelease := nil;
  LEnvelope := nil;
  LRendered := nil;
  try
    SetLength(LZones, 1);
    for LEdit := 0 to 6 do
    begin
      for LRole := 0 to 2 do
      begin
        LZones[0] := Default(TStyleInstrumentZone);
        LZones[0].Zone.MinimumKey := 48;
        LZones[0].Zone.MaximumKey := 72;
        LZones[0].Zone.MinimumVelocity := 1;
        LZones[0].Zone.MaximumVelocity := 127;
        LZones[0].Zone.Voice := DefaultSynthVoice;
        LZones[0].Zone.Voice.CutoffHz := 3000;
        if (LRole = 2) and (LEdit > 0) then
        begin
          SetLength(LPoints, 2);
          LPoints[0].Frame := 0;
          LPoints[0].Transition := atLinear;
          LPoints[1].Frame := 100;
          LPoints[1].Transition := atHold;
          case LEdit of
            1:
            begin
              LPoints[0].Value := 0;
              LPoints[1].Value := 1200;
            end;
            2:
            begin
              LPoints[0].Value := 1;
              LPoints[1].Value := 0.2;
            end;
            3:
            begin
              LPoints[0].Value := -0.8;
              LPoints[1].Value := 0.8;
            end;
            4:
            begin
              LPoints[0].Value := 3000;
              LPoints[1].Value := 100;
            end;
          else
            LPoints[0].Value := 0.3;
            LPoints[1].Value := 0.8;
          end;
          LCurve := TAutomationCurve.Create(LPoints);
          case LEdit of
            1: LZones[0].Zone.Voice.Automation.PitchCents := LCurve;
            2: LZones[0].Zone.Voice.Automation.GainMultiplier := LCurve;
            3: LZones[0].Zone.Voice.Automation.Pan := LCurve;
            4: LZones[0].Zone.Voice.Automation.CutoffHz := LCurve;
            5: LZones[0].Zone.Voice.Shape := wsSine;
            6:
            begin
              LPoints[0].Value := 1;
              LPoints[1].Value := 0;
              LRelease := TAutomationCurve.Create(LPoints);
              LEnvelope := TGateEnvelope.Create(LCurve, LRelease, 100);
              Check(Abs(LEnvelope.ValueAt(50, 50) - 0.55) < 1E-12,
                'Early release starts at interrupted held level');
              Check(LEnvelope.ValueAt(150, 50) = 0, 'Explicit release endpoint is silent');
              LZones[0].Zone.Voice.GateEnvelope := LEnvelope;
            end;
          end;
          LPoints[1].Value := -999;
          Check(LCurve.ValueAt(100) = LCurve.ValueAt(999), 'Note-relative endpoint holds');
        end;
        LInstrument := TStyleInstrument.Create(LZones, 8000);
        FreeAndNil(LCurve);
        FreeAndNil(LRelease);
        FreeAndNil(LEnvelope);
        LZones[0] := Default(TStyleInstrumentZone);
        LPlan := LInstrument.PlanNote(48 + LRole * 12, 90, 37, 400, Cardinal(LRole + 1));
        LRendered := RenderFrameTones(LPlan, 8000, 1000);
        if LEdit = 0 then
        begin
          LBase[LRole] := LRendered;
          LRendered := nil;
        end
        else
        begin
          Check(SameAudio(LBase[LRole], LRendered) = (LRole <> 2),
            'Independent pitch/gain/pan/cutoff/timbre/envelope edit preserves other role audio');
        end;
        FreeAndNil(LRendered);
        FreeAndNil(LInstrument);
      end;
    end;
  finally
    LRendered.Free;
    LInstrument.Free;
    LCurve.Free;
    LRelease.Free;
    LEnvelope.Free;
    for LRole := 0 to 2 do
    begin
      LBase[LRole].Free;
    end;
  end;
end;

procedure RolePreferences;
var
  LConfig: TWfcMusicVoicesGraphConfig;
  LSession: TNamedVoiceSession;
  LOptions: TVoiceSessionOptions;
  LGenerated: TWfcMusicVoicesGenerated;
  LBefore: TWfcMusicVoicesGenerated;
  LReport: TGraphNegotiationReport;
  LSelective: TGraphSelectiveNegotiationReport;
  LProof: TWfcMusicVoicesValidationReport;
  LPreferences: TLayerTokenPreferences;
  LModel: TWfcSequenceModel;
  LText: String;
  LIndex: Integer;
  LSeed: Integer;
  LBaselineCount: Integer;
  LPreferredCount: Integer;
  LRejected: Boolean;
  LBeforeAudio: TAudioClip;
  LAfterAudio: TAudioClip;
  LImpossible: TWfcSequenceTokenConstraints;
begin
  LConfig := Config;
  LSession := nil;
  LModel := nil;
  try
    LOptions := DefaultVoiceSessionOptions;
    LOptions.CellCount := 3;
    LSession := TNamedVoiceSession.Create(LConfig, ['bass', 'chords', 'lead'], LOptions);
    LModel := LSession.CopyModel('lead');
    LText := EncodeWfcSequenceText(LModel);
    FreeAndNil(LModel);
    Check(LSession.TryGenerate(LGenerated, LReport, LProof), 'Preference baseline');
    LBefore := LSession.CopyAccepted;
    LBaselineCount := 0;
    LPreferredCount := 0;
    for LSeed := 1 to 32 do
    begin
      LSession.SetPreferences('lead', nil);
      Check(LSession.TryRegenerate(['lead'], LSeed, LGenerated, LSelective, LProof),
        'Unpreferred role replay');
      if LGenerated.Frames[0].Voices[2].Tones[0].Pitch = 79 then
      begin
        Inc(LBaselineCount);
      end;
      SetLength(LPreferences, 2);
      LPreferences[0] := MakeLayerTokenPreference(VoiceToken(wmcaAttack, [79]), 1024);
      LPreferences[1] := MakeLayerTokenPreference(VoiceToken(wmcaHold, [79]), 1024);
      LSession.SetPreferences('lead', LPreferences);
      Check(LSession.TryRegenerate(['lead'], LSeed, LGenerated, LSelective, LProof),
        'Preferred role replay');
      if LGenerated.Frames[0].Voices[2].Tones[0].Pitch = 79 then
      begin
        Inc(LPreferredCount);
      end;
      for LIndex := 0 to 3 do
      begin
        SameLayer(LBefore, LGenerated, LIndex);
      end;
    end;
    Check(LPreferredCount > LBaselineCount, 'Preferences affect actual WFC choices');
    LPreferences[0].Multiplier := 0;
    Check(LSession.CopyPreferences('lead')[0].Multiplier = 1024, 'Preference array detached');
    LRejected := False;
    try
      LSession.SetPreferences('lead', LPreferences);
    except
      on EAudio do
      begin
        LRejected := True;
      end;
    end;
    Check(LRejected, 'Unsupported preference diagnoses instead of ignoring');
    LSession.SetConstraints('lead', PitchMask(67));
    SetLength(LPreferences, 1);
    LPreferences[0] := MakeLayerTokenPreference(VoiceToken(wmcaAttack, [36]), 2);
    LSession.SetPreferences('bass', LPreferences);
    Check(LSession.TryRegenerate(['lead'], 731, LGenerated, LSelective, LProof),
      'Hard lock remains feasible despite opposite preference');
    Check(LGenerated.Frames[0].Voices[2].Tones[0].Pitch = 67,
      'Preference cannot override hard role lock');
    Check(LSession.HasPending('bass'), 'Unrelated preference remains staged');
    if LBefore.Frames[0].Voices[2].Tones[0].Pitch = 67 then
    begin
      LSession.SetConstraints('lead', PitchMask(79));
    end
    else
    begin
      LSession.SetConstraints('lead', PitchMask(67));
    end;
    Check(LSession.TryRegenerate(['lead'], 731, LGenerated, LSelective, LProof),
      'Paired sounding role edit');
    for LIndex := 0 to 2 do
    begin
      LBeforeAudio := RenderFixtureRole(LBefore, LIndex);
      LAfterAudio := nil;
      try
        LAfterAudio := RenderFixtureRole(LGenerated, LIndex);
        Check(SameAudio(LBeforeAudio, LAfterAudio) = (LIndex <> 2),
          'Changed lead audio and exact unrelated role audio');
      finally
        LBeforeAudio.Free;
        LAfterAudio.Free;
      end;
    end;
    LModel := LSession.CopyModel('lead');
    Check(EncodeWfcSequenceText(LModel) = LText, 'Preference leaves training model unchanged');
    LBefore := LSession.CopyAccepted;
    SetLength(LImpossible, 1);
    LImpossible[0] := MakeWfcSequenceTokenConstraint(0, [VoiceToken(wmcaRest, [])]);
    LSession.SetConstraints('lead', LImpossible);
    Check(not LSession.TryRegenerate(['lead'], 731, LGenerated, LSelective, LProof),
      'Contradictory lock cannot be discarded in favor of preference');
    for LIndex := 0 to 4 do
    begin
      SameLayer(LBefore, LGenerated, LIndex);
    end;
    Check(LSession.HasPending('lead') and LSession.HasPending('bass'),
      'Failed preference/lock attempt keeps requested controls staged');
  finally
    LModel.Free;
    LSession.Free;
    FreeConfig(LConfig);
  end;
end;

procedure JointRoleAdmission;
var
  LLayers: TLearnedLayers;
  LContracts: TProviderContracts;
  LProjections: TLayerProjections;
  LSession: TCompatibleProviderSession;
  LRhythm: String;
  LVoice: String;
  LCase: Integer;
  LRejected: Boolean;
begin
  SetLength(LLayers, 2);
  SetLength(LContracts, 2);
  SetLength(LProjections, 1);
  LSession := nil;
  try
    LRhythm := EncodeWfcMusicRhythmFrame(MakeWfcMusicRhythmFrame([wmcaRest, wmcaAttack]));
    LVoice := VoiceToken(wmcaAttack, [60]);
    LLayers[0].Model := LearnOne([LRhythm], [LRhythm]);
    LLayers[1].Model := LearnOne([LVoice], [LVoice]);
    LContracts[0] := ContractFor('joint', spvRhythm, 1, 240);
    SetLength(LContracts[0].RoleOrder, 2);
    LContracts[0].RoleOrder[0] := 'bass';
    LContracts[0].RoleOrder[1] := 'lead';
    LContracts[1] := ContractFor('line', spvVoice, 1, 240);
    LContracts[1].PitchBasis := ppbAbsoluteMidi;
    LProjections[0].Provider := 0;
    LProjections[0].Consumer := 1;
    LProjections[0].TimeMapping := ltmStartTick;
    SetLength(LProjections[0].Rules, 1);
    LProjections[0].Rules[0] := MakeWfcSequenceProjectionRule(LVoice, [LRhythm]);
    for LCase := 0 to 2 do
    begin
      case LCase of
        0: LContracts[1].RoleId := 'lead';
        1: LContracts[1].RoleId := 'bass';
        2: LContracts[1].RoleId := 'missing';
      end;
      LRejected := False;
      try
        LSession := TCompatibleProviderSession.Create(LLayers, LProjections, LContracts,
          DefaultLayerGenerationOptions);
      except
        on EAudio do LRejected := True;
      end;
      Check(LRejected = (LCase <> 0), 'Joint action projection binds named role slot');
      FreeAndNil(LSession);
    end;
  finally
    LSession.Free;
    LLayers[0].Model.Free;
    LLayers[1].Model.Free;
  end;
end;

begin
  Exercise;
  Boundaries;
  PairAndRange;
  LayerCapacity;
  ProviderReplacement;
  MappedComposition;
  JointRoleAdmission;
  RolePreferences;
  SoundControls;
  WriteLn('Named voices: owned typed roles, collective proof, selective edits, pending preservation and recovery pass');
end.
