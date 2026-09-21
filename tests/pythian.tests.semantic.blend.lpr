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
program pythian_tests_semantic_blend;

{$mode delphi}
{$H+}

uses
  Classes, SysUtils, Math, pythian.audio, pythian.hash, pythian.analysis, pythian.onset, pythian.time,
  pythian.wave, pythian.synth, pythian.envelope, pythian.source.wavetable,
  pythian.music.context, pythian.tonal, pythian.wfc.context,
  pythian.wfc.context.profile, pythian.wfc.context.archive, pythian.wfc.style,
  pythian.wfc.semantic.style, pythian.wfc.provider.contracts, pythian.wfc.providers,
  pythian.wfc.layers, pythian.wfc.voices, pythian.wfc.instrument,
  wfc, wfc_model, wfc_sequence, wfc_sequence_learn, wfc_sequence_text, wfc_sequence_graph,
  wfc_music, wfc_music_sequence, wfc_music_ensemble, wfc_music_ensemble_graph, wfc_music_voices_graph;

procedure Check(const ACondition: Boolean; const AMessage: String);
begin
  if not ACondition then
  begin
    raise EAudio.Create(AMessage);
  end;
end;

procedure SaveFixture(const ASuffix: String; const ABytes: TAudioBytes);
var
  LStream: TFileStream;
begin
  if ParamCount = 0 then
  begin
    Exit;
  end;
  LStream := TFileStream.Create(ParamStr(1) + ASuffix, fmCreate);
  try
    if Length(ABytes) > 0 then
    begin
      LStream.WriteBuffer(ABytes[0], Length(ABytes));
    end;
  finally
    LStream.Free;
  end;
end;

procedure LearnProviders(var ADefinition: TSemanticStyleDefinition);
var
  LProvider: Integer;
  LRun: Integer;
  LWeight: Integer;
  LCount: Integer;
  LOrder: Integer;
  LSamples: TWfcSequenceSamples;
  LModel: TWfcSequenceModel;
begin
  LOrder := 1;
  if ADefinition.NamedVoices then
  begin
    { A hold requires predecessor context. Order one admits structural
      rest-to-hold edges even when the observed run is attack/hold/rest. }
    LOrder := 2;
  end;
  for LProvider := 0 to High(ADefinition.Providers) do
  begin
    LSamples := nil;
    for LRun := 0 to High(ADefinition.Runs) do
    begin
      for LWeight := 1 to ADefinition.Runs[LRun].Weights[LProvider] do
      begin
        LCount := Length(LSamples);
        SetLength(LSamples, LCount + 1);
        LSamples[LCount] := MakeWfcSequenceSample(ADefinition.Runs[LRun].Tokens[LProvider]);
      end;
    end;
    LModel := LearnSequenceModelCorpus(LSamples, LOrder);
    try
      ADefinition.Providers[LProvider].ModelText := EncodeWfcSequenceText(LModel);
      ADefinition.Providers[LProvider].VocabularySha256 :=
        SemanticVocabularyIdentity(ADefinition.Providers[LProvider].ModelText);
    finally
      LModel.Free;
    end;
  end;
end;

function Provider(const AName: String; const AVocabulary: TStyleProviderVocabulary;
  const ACells: Integer): TSemanticProvider;
begin
  Result := Default(TSemanticProvider);
  Result.Contract.Name := AName;
  Result.Contract.Vocabulary := AVocabulary;
  Result.Contract.MusicalDomain := 'controlled-semantic-fixture';
  Result.Contract.TicksPerQuarter := 480;
  Result.Contract.Scope := MakeLayerScope(ACells, wseWhole);
  Result.Contract.TimeGrid := MakeLayerTimeGrid(0, 240);
  Result.Contract.UnknownPolicy := ProviderUnknownPolicy(AVocabulary);
  Result.ExtractionPolicy := 'Caller-authored controlled observations; no recorded inference claim';
end;

function Source(const AIndex: Integer): TSemanticSource;
begin
  Result := Default(TSemanticSource);
  Result.Sha256 := StringOfChar(Char(Ord('a') + AIndex), 64);
  Result.GroupId := 'controlled-group-' + IntToStr(AIndex);
  Result.Split := ssTraining;
  Result.Exposure := [seTraining, seVocabulary];
  Result.SampleRate := 1000;
  Result.FrameCount := 2000;
  Result.ExternalRequirement := 'Controlled symbolic fixture declarations';
  Result.OriginSha256 := Result.Sha256;
  Result.OriginSampleRate := Result.SampleRate;
  Result.OriginFrameCount := Result.FrameCount;
  Result.OriginEndFrame := Result.FrameCount;
  Result.PreparationEvidence := [Ord('i'), Ord('d'), Ord('e'), Ord('n'), Ord('t'), Ord('i'), Ord('t'), Ord('y')];
  Result.PreparationSha256 := SemanticPreparationIdentity(Result);
end;

function GridDefinition: TSemanticStyleDefinition;
var
  LRun: Integer;
  LCell: Integer;
begin
  Result := Default(TSemanticStyleDefinition);
  SetLength(Result.Providers, 3);
  Result.Providers[0] := Provider('tempo', spvTempo, 2);
  Result.Providers[1] := Provider('onsets', spvOnsets, 2);
  Result.Providers[2] := Provider('key', spvKey, 2);
  SetLength(Result.Sources, 2);
  Result.Sources[0] := Source(0);
  Result.Sources[1] := Source(1);
  SetLength(Result.Runs, 3);
  for LRun := 0 to 2 do
  begin
    Result.Runs[LRun].Identity := 'independent-run-' + IntToStr(LRun);
    Result.Runs[LRun].SourceIndex := Ord(LRun = 2);
    if LRun = 1 then
    begin
      Result.Runs[LRun].StartFrame := 600;
      Result.Runs[LRun].GapBeforeFrames := 100;
    end;
    Result.Runs[LRun].EndFrame := Result.Runs[LRun].StartFrame + 500;
    SetLength(Result.Runs[LRun].Tokens, 3);
    SetLength(Result.Runs[LRun].Weights, 3);
    Result.Runs[LRun].TicksPerQuarter := 480;
    Result.Runs[LRun].TempoChanges := [MakeTempoChange(0, 500000)];
    SetLength(Result.Runs[LRun].TimeGrids, 3);
    for LCell := 0 to 2 do
    begin
      Result.Runs[LRun].Weights[LCell] := 1;
      SetLength(Result.Runs[LRun].Tokens[LCell], 2);
      Result.Runs[LRun].TimeGrids[LCell] := MakeLayerTimeGrid(0, 240);
    end;
    for LCell := 0 to 1 do
    begin
      Result.Runs[LRun].Tokens[2][LCell] := KeyContextToken(MakeKeyContext(-1, dmMajor));
      if LRun = 1 then
      begin
        Result.Runs[LRun].Tokens[0][LCell] := TempoContextToken(600000);
        Result.Runs[LRun].Tokens[1][LCell] := RhythmEmptyToken;
      end
      else
      begin
        Result.Runs[LRun].Tokens[0][LCell] := TempoContextToken(500000);
        Result.Runs[LRun].Tokens[1][LCell] := RhythmOnsetToken;
      end;
    end;
  end;
  SetLength(Result.Projections, 1);
  Result.Projections[0].Provider := 0;
  Result.Projections[0].Consumer := 1;
  Result.Projections[0].TimeMapping := ltmWholeCell;
  SetLength(Result.Projections[0].Rules, 2);
  Result.Projections[0].Rules[0] := MakeWfcSequenceProjectionRule(RhythmOnsetToken, [TempoContextToken(500000)]);
  Result.Projections[0].Rules[1] := MakeWfcSequenceProjectionRule(RhythmEmptyToken, [TempoContextToken(600000)]);
  LearnProviders(Result);
end;

procedure SameGrid(const ALeft, ARight: TSemanticStyle);
var
  LLeft: TCompatibleProviderSession;
  LRight: TCompatibleProviderSession;
  LBefore: TLayerSequences;
  LAfter: TLayerSequences;
  LReport: TGraphNegotiationReport;
  LSeed: Integer;
  LProvider: Integer;
  LCell: Integer;
begin
  for LSeed := 1 to 8 do
  begin
    LLeft := ALeft.CreateSession(LSeed);
    LRight := nil;
    try
      LRight := ARight.CreateSession(LSeed);
      Check(LLeft.TryGenerate(LBefore, LReport), 'Source/derived semantic graph generates');
      Check(LRight.TryGenerate(LAfter, LReport), 'Reloaded semantic graph generates');
      for LProvider := 0 to High(LBefore) do
      begin
        for LCell := 0 to High(LBefore[LProvider].Tokens) do
        begin
          Check((LBefore[LProvider].Tokens[LCell] = LAfter[LProvider].Tokens[LCell]) and
            (LBefore[LProvider].StateIndices[LCell] = LAfter[LProvider].StateIndices[LCell]),
            'Semantic archive retains exact actual generation states');
        end;
      end;
    finally
      LRight.Free;
      LLeft.Free;
    end;
  end;
end;

function SoundProfile(const ASecond: Boolean): TWaveStyleProfile;
var
  LSamples: TAudioSamples;
  LClip: TAudioClip;
  LDecoded: TAudioClip;
  LBytes: TAudioBytes;
  LTrace: TEnvelopeTrace;
  LEvidence: TRhythmStyleEvidence;
  LContextEvidence: TContextEvidenceArray;
  LBundle: TContextLearningBundle;
  LContext: TContextProfile;
  LIndex: Integer;
  LLevel: Double;
begin
  LClip := nil;
  LDecoded := nil;
  LTrace := nil;
  LBundle := nil;
  LContext := nil;
  try
    SetLength(LSamples, 2000);
    for LIndex := 0 to High(LSamples) do
    begin
      LSamples[LIndex] := 0.2 * Sin(2 * Pi * 50 * LIndex / 1000);
      if ASecond then
      begin
        LSamples[LIndex] := LSamples[LIndex] + 0.1 * Sin(2 * Pi * 100 * LIndex / 1000);
      end;
      if LIndex < 96 then
      begin
        LLevel := 0;
        case LIndex div 16 of
          1, 3: LLevel := 0.5;
          2: LLevel := 1;
          4: LLevel := 0.25;
        end;
        if ASecond and (LIndex div 16 = 3) then
        begin
          LLevel := 0.75;
        end;
        LSamples[LIndex] := LLevel * (1 - 2 * (LIndex mod 2));
      end;
    end;
    LClip := TAudioClip.Create(1000, 1, LSamples);
    LBytes := EncodeWavePcm16(LClip);
    SaveFixture('-sound-' + IntToStr(Ord(ASecond)) + '.wav', LBytes);
    LDecoded := DecodeWave(LBytes);
    LEvidence := Default(TRhythmStyleEvidence);
    LEvidence.Source.Name := 'Native semantic sound fixture';
    LEvidence.Source.Sha256 := Sha256Bytes(LBytes);
    LEvidence.Source.Provenance := 'Controlled authored waveform; not recorded accuracy evidence';
    LEvidence.Source.SampleRate := 1000;
    LEvidence.Source.Channels := 1;
    LEvidence.Source.FrameCount := 2000;
    LEvidence.OnsetReportSha256 := StringOfChar('c', 64);
    LEvidence.Analysis := DefaultAnalysisOptions;
    LEvidence.OnsetVersion := OnsetLocationVersion;
    LEvidence.Policy := 'Declared exact fixture onset coordinates';
    LEvidence.TempoMicroseconds := 500000;
    LEvidence.OnsetFrames := [0, 500, 1000, 1500];
    LEvidence.Timbre.StartFrame := 128;
    LEvidence.Timbre.FrameCount := 200;
    LEvidence.Timbre.MaximumRelativeError := 0.001;
    LEvidence.Timbre.MinimumAcRms := 0.00001;
    LEvidence.Timbre.Policy := 'Controlled 50-Hz stationary window';
    LEvidence.Timbre.Fit := FitWavetableHarmonics(LDecoded, 128, 200, 0, 3, 50);
    LTrace := TEnvelopeTrace.Create(LDecoded, 0, 96, 0, 16);
    LEvidence.Envelope.FrameCount := 96;
    LEvidence.Envelope.WindowFrames := 16;
    LEvidence.Envelope.GateFrame := 39;
    LEvidence.Envelope.MaximumTailRatio := 0.01;
    LEvidence.Envelope.MinimumRms := 0.00001;
    LEvidence.Envelope.Policy := 'Controlled 16-frame amplitude regions with gate39';
    LEvidence.Envelope.RmsPoints := LTrace.CopyRmsPoints;
    SetLength(LContextEvidence, 1);
    LContextEvidence[0].Name := LEvidence.Source.Name;
    LContextEvidence[0].SourceSha256 := LEvidence.Source.Sha256;
    LContextEvidence[0].AdmissionPolicy := 'Declared controlled 120-BPM source clock';
    LContextEvidence[0].Grid.TicksPerQuarter := 480;
    LContextEvidence[0].Grid.StepTicks := 240;
    SetLength(LContextEvidence[0].Grid.Keys, 8);
    SetLength(LContextEvidence[0].Grid.Tempos, 8);
    for LIndex := 0 to 7 do
    begin
      LContextEvidence[0].Grid.Keys[LIndex] := MakeKeyContext(0, dmMajor);
      LContextEvidence[0].Grid.Tempos[LIndex] := 500000;
    end;
    LBundle := TContextLearningBundle.Create(LContextEvidence);
    LContext := TContextProfile.Create(LBundle);
    Result := TWaveStyleProfile.CreateSource(LContext, LEvidence);
    SaveFixture('-sound-' + IntToStr(Ord(ASecond)) + '.pys', Result.Encode);
  finally
    LContext.Free;
    LBundle.Free;
    LTrace.Free;
    LDecoded.Free;
    LClip.Free;
  end;
end;

function VoiceToken(const AAction: TWfcMusicCellAction; const APitch, AVelocity: Integer): String;
var
  LFrame: TWfcMusicEnsembleFrame;
begin
  LFrame := Default(TWfcMusicEnsembleFrame);
  SetLength(LFrame.Voices, 1);
  LFrame.Voices[0].Action := AAction;
  if AAction <> wmcaRest then
  begin
    LFrame.Voices[0].Tones := [MakeWfcMusicTone(APitch, AVelocity)];
  end;
  Result := EncodeWfcMusicEnsembleFrame(LFrame);
end;

function NamedDefinition(const ASecond: Boolean; const ASound: TWaveStyleProfile): TSemanticStyleDefinition;
var
  LRun: Integer;
  LProvider: Integer;
  LPitch: Integer;
  LVelocity: Integer;
  LAction: TWfcMusicCellAction;
  LHarmony: String;
  LEmpty: String;
begin
  Result := Default(TSemanticStyleDefinition);
  Result.NamedVoices := True;
  Result.HarmonyMode := wmehmExact;
  SetLength(Result.Providers, 4);
  Result.Providers[0] := Provider('harmony', spvHarmony, 3);
  Result.Providers[1] := Provider('rhythm', spvRhythm, 3);
  Result.Providers[1].Contract.RoleOrder := ['bass', 'lead'];
  Result.Providers[2] := Provider('bass', spvVoice, 3);
  Result.Providers[3] := Provider('lead', spvVoice, 3);
  Result.Providers[2].Contract.RoleId := 'bass';
  Result.Providers[3].Contract.RoleId := 'lead';
  Result.Providers[2].Contract.PitchBasis := ppbAbsoluteMidi;
  Result.Providers[3].Contract.PitchBasis := ppbAbsoluteMidi;
  SetLength(Result.VoiceRanges, 2);
  Result.VoiceRanges[0].MinimumPitch := 48;
  Result.VoiceRanges[0].MaximumPitch := 50;
  Result.VoiceRanges[1].MinimumPitch := 60;
  Result.VoiceRanges[1].MaximumPitch := 62;
  SetLength(Result.VoicePairs, 1);
  Result.VoicePairs[0].LowerVoice := 0;
  Result.VoicePairs[0].UpperVoice := 1;
  Result.VoicePairs[0].MinGap := 12;
  Result.VoicePairs[0].MaxGap := 12;
  Result.VoicePairs[0].RestPolicy := wmvprSuspend;
  SetLength(Result.Sources, 2);
  Result.Sources[0] := Source(Ord(ASecond));
  Result.Sources[0].FrameCount := 4000;
  Result.Sources[0].OriginFrameCount := 4000;
  Result.Sources[0].OriginEndFrame := 4000;
  Result.Sources[0].PreparationSha256 := SemanticPreparationIdentity(Result.Sources[0]);
  Result.Sources[1] := Source(Ord(ASecond) + 2);
  Result.Sources[1].Sha256 := ASound.EvidenceAt(0).Source.Sha256;
  Result.Sources[1].OriginSha256 := Result.Sources[1].Sha256;
  Result.Sources[1].PreparationSha256 := SemanticPreparationIdentity(Result.Sources[1]);
  SetLength(Result.Runs, 4);
  LEmpty := EncodeWfcMusicPitchClassSet(MakeWfcMusicPitchClassSet(12, []));
  for LRun := 0 to 3 do
  begin
    LPitch := 60 + (LRun mod 2) * 2;
    LVelocity := 90;
    if LRun >= 2 then
    begin
      LVelocity := 70;
    end;
    LAction := wmcaHold;
    if Odd(LRun) then
    begin
      LAction := wmcaAttack;
    end;
    LHarmony := EncodeWfcMusicPitchClassSet(MakeWfcMusicPitchClassSet(12, [LPitch mod 12]));
    Result.Runs[LRun].Identity := 'song-run-' + IntToStr(LRun);
    Result.Runs[LRun].StartFrame := LRun * 1000;
    Result.Runs[LRun].EndFrame := LRun * 1000 + 750;
    if LRun > 0 then
    begin
      Result.Runs[LRun].GapBeforeFrames := 250;
    end;
    Result.Runs[LRun].TicksPerQuarter := 480;
    Result.Runs[LRun].TempoChanges := [MakeTempoChange(0, 500000)];
    SetLength(Result.Runs[LRun].Tokens, 4);
    SetLength(Result.Runs[LRun].Weights, 4);
    SetLength(Result.Runs[LRun].TimeGrids, 4);
    for LProvider := 0 to 3 do
    begin
      Result.Runs[LRun].TimeGrids[LProvider] := MakeLayerTimeGrid(0, 240);
      Result.Runs[LRun].Weights[LProvider] := 1;
      if LRun = Ord(ASecond) then
      begin
        Result.Runs[LRun].Weights[LProvider] := 3;
      end;
    end;
    Result.Runs[LRun].Tokens[0] := [LHarmony, LHarmony, LEmpty];
    Result.Runs[LRun].Tokens[1] := [
      EncodeWfcMusicRhythmFrame(MakeWfcMusicRhythmFrame([wmcaAttack, wmcaAttack])),
      EncodeWfcMusicRhythmFrame(MakeWfcMusicRhythmFrame([LAction, LAction])),
      EncodeWfcMusicRhythmFrame(MakeWfcMusicRhythmFrame([wmcaRest, wmcaRest]))];
    Result.Runs[LRun].Tokens[2] := [VoiceToken(wmcaAttack, LPitch - 12, 90),
      VoiceToken(LAction, LPitch - 12, 90), VoiceToken(wmcaRest, 0, 0)];
    Result.Runs[LRun].Tokens[3] := [VoiceToken(wmcaAttack, LPitch, LVelocity),
      VoiceToken(LAction, LPitch, LVelocity), VoiceToken(wmcaRest, 0, 0)];
  end;
  LearnProviders(Result);
  Result.Providers[3].Preferences := [MakeLayerTokenPreference(VoiceToken(wmcaAttack, 60, 90), 2)];
  Result.Providers[3].Constraints := [MakeWfcSequenceTokenConstraint(2, [VoiceToken(wmcaRest, 0, 0)])];
  SetLength(Result.Sounds, 1);
  Result.Sounds[0].RoleId := 'lead';
  Result.Sounds[0].Timbre := ASound.Encode;
  Result.Sounds[0].Envelope := ASound.Encode;
end;

function Recipe: TSemanticBlendRecipe;
begin
  Result := Default(TSemanticBlendRecipe);
  SetLength(Result.Providers, 4);
  Result.Providers[0].LeftWeight := 1;
  Result.Providers[0].RightWeight := 1;
  Result.Providers[1].LeftWeight := 3;
  Result.Providers[1].RightWeight := 1;
  Result.Providers[2].LeftWeight := 0;
  Result.Providers[2].RightWeight := 1;
  Result.Providers[3].LeftWeight := 1;
  Result.Providers[3].RightWeight := 4;
  Result.Providers[3].ControlParent := 1;
  SetLength(Result.Sounds, 1);
  Result.Sounds[0].RoleId := 'lead';
  Result.Sounds[0].LeftTimbreWeight := 1;
  Result.Sounds[0].RightTimbreWeight := 3;
  Result.Sounds[0].LeftEnvelopeWeight := 3;
  Result.Sounds[0].RightEnvelopeWeight := 1;
end;

function EqualRecipe(const AProviderCount: Integer; const APolicy: TSemanticRepeatPolicy): TSemanticBlendRecipe;
var
  LProvider: Integer;
begin
  Result := Default(TSemanticBlendRecipe);
  Result.RepeatPolicy := APolicy;
  SetLength(Result.Providers, AProviderCount);
  for LProvider := 0 to AProviderCount - 1 do
  begin
    Result.Providers[LProvider].LeftWeight := 1;
    Result.Providers[LProvider].RightWeight := 1;
  end;
end;

procedure SameSequence(const ALeft, ARight: TWfcGeneratedSequenceSegment; const AMessage: String);
var
  LCell: Integer;
begin
  Check(Length(ALeft.Tokens) = Length(ARight.Tokens), AMessage + ' cell count');
  for LCell := 0 to High(ALeft.Tokens) do
  begin
    Check((ALeft.Tokens[LCell] = ARight.Tokens[LCell]) and
      (ALeft.StateIndices[LCell] = ARight.StateIndices[LCell]), AMessage + ' token/state');
  end;
end;

procedure SameGeneration(const ALeft, ARight: TSemanticStyle);
const
  CSeeds: array[0..2] of Integer = (731, 1731, 2731);
var
  LLeft: TNamedVoiceSession;
  LRight: TNamedVoiceSession;
  LFirst: TWfcMusicVoicesGenerated;
  LSecond: TWfcMusicVoicesGenerated;
  LReport: TGraphNegotiationReport;
  LProof: TWfcMusicVoicesValidationReport;
  LSeed: Integer;
  LProvider: Integer;
begin
  for LSeed in CSeeds do
  begin
    LLeft := ALeft.CreateVoiceSession(LSeed);
    LRight := nil;
    try
      LRight := ARight.CreateVoiceSession(LSeed);
      Check(LLeft.TryGenerate(LFirst, LReport, LProof) and LProof.Valid, 'Blend actual generation');
      Check(LRight.TryGenerate(LSecond, LReport, LProof) and LProof.Valid, 'Reloaded blend actual generation');
      for LProvider := 0 to High(LFirst.Layers) do
      begin
        SameSequence(LFirst.Layers[LProvider], LSecond.Layers[LProvider], 'Reloaded actual graph');
      end;
    finally
      LRight.Free;
      LLeft.Free;
    end;
  end;
end;

procedure RejectBlend(const ALeft, ARight: TSemanticStyle; const ARecipe: TSemanticBlendRecipe);
var
  LRejected: Boolean;
  LCandidate: TSemanticStyle;
  LLeftHash: String;
  LRightHash: String;
begin
  LCandidate := nil;
  LRejected := False;
  LLeftHash := Sha256Bytes(ALeft.Encode);
  LRightHash := Sha256Bytes(ARight.Encode);
  try
    try
      LCandidate := TSemanticStyle.CreateBlend(ALeft, ARight, ARecipe);
    except
      on E: Exception do
      begin
        LRejected := True;
      end;
    end;
    Check(LRejected and (LCandidate = nil), 'Incompatible blend must reject before publication');
    Check((Sha256Bytes(ALeft.Encode) = LLeftHash) and (Sha256Bytes(ARight.Encode) = LRightHash),
      'Rejected blend changed immutable parent');
  finally
    LCandidate.Free;
  end;
end;

procedure CheckModelsAndControls(const AFirst, ASecond: TSemanticStyle;
  const AChangedProvider: Integer);
var
  LFirst: TSemanticStyleDefinition;
  LSecond: TSemanticStyleDefinition;
  LProvider: Integer;
  LControl: Integer;
begin
  LFirst := AFirst.CopyDefinition;
  LSecond := ASecond.CopyDefinition;
  for LProvider := 0 to High(LFirst.Providers) do
  begin
    if LProvider <> AChangedProvider then
    begin
      Check(LFirst.Providers[LProvider].ModelText = LSecond.Providers[LProvider].ModelText,
        'Unrelated model changed under paired provider weights');
    end;
    Check(Length(LFirst.Providers[LProvider].Preferences) = Length(LSecond.Providers[LProvider].Preferences),
      'Preferences changed with training weights');
    for LControl := 0 to High(LFirst.Providers[LProvider].Preferences) do
    begin
      Check((LFirst.Providers[LProvider].Preferences[LControl].Token =
        LSecond.Providers[LProvider].Preferences[LControl].Token) and
        (LFirst.Providers[LProvider].Preferences[LControl].Multiplier =
        LSecond.Providers[LProvider].Preferences[LControl].Multiplier), 'Independent preference retained');
    end;
    Check(Length(LFirst.Providers[LProvider].Constraints) = Length(LSecond.Providers[LProvider].Constraints),
      'Locks changed with training weights');
    for LControl := 0 to High(LFirst.Providers[LProvider].Constraints) do
    begin
      Check((LFirst.Providers[LProvider].Constraints[LControl].Position =
        LSecond.Providers[LProvider].Constraints[LControl].Position) and
        (LFirst.Providers[LProvider].Constraints[LControl].AllowedTokens[0] =
        LSecond.Providers[LProvider].Constraints[LControl].AllowedTokens[0]), 'Independent lock retained');
    end;
  end;
end;

procedure PairedAcceptedEdit(const AFirst, ASecond: TSemanticStyle);
var
  LSession: TNamedVoiceSession;
  LDefinition: TSemanticStyleDefinition;
  LModel: TWfcSequenceModel;
  LBefore: TWfcMusicVoicesGenerated;
  LAfter: TWfcMusicVoicesGenerated;
  LReport: TGraphNegotiationReport;
  LReplacement: TLayerModelReplacementReport;
  LProof: TWfcMusicVoicesValidationReport;
  LProvider: Integer;
begin
  LSession := AFirst.CreateVoiceSession(731);
  LModel := nil;
  try
    Check(LSession.TryGenerate(LBefore, LReport, LProof), 'Paired provider baseline');
    LDefinition := ASecond.CopyDefinition;
    LModel := DecodeWfcSequenceText(LDefinition.Providers[3].ModelText);
    Check(LSession.TryReplaceProvider('lead', LModel, LDefinition.Providers[3].Contract,
      1731, LAfter, LReplacement, LProof), 'Compatible independently weighted voice replacement');
    for LProvider := 0 to 2 do
    begin
      SameSequence(LBefore.Layers[LProvider], LAfter.Layers[LProvider], 'Unrelated accepted provider');
    end;
    Check(LProof.Valid, 'Changed voice still has complete joint graph proof');
  finally
    LModel.Free;
    LSession.Free;
  end;
end;

function RenderSound(const AStyle: TSemanticStyle): TAudioBytes;
var
  LZones: TStyleInstrumentZones;
  LInstrument: TStyleInstrument;
  LClip: TAudioClip;
begin
  SetLength(LZones, 1);
  LZones[0].Zone.MinimumKey := 60;
  LZones[0].Zone.MaximumKey := 60;
  LZones[0].Zone.MinimumVelocity := 1;
  LZones[0].Zone.MaximumVelocity := 127;
  LZones[0].Zone.Voice := DefaultSynthVoice;
  LInstrument := AStyle.CreateInstrument('lead', LZones, 8000);
  LClip := nil;
  try
    LClip := RenderFrameTones(LInstrument.PlanNote(60, 90, 0, 8000, 71), 8000);
    Result := EncodeWavePcm16(LClip);
  finally
    LClip.Free;
    LInstrument.Free;
  end;
end;

procedure NoCrossSongTransition(const AStyle: TSemanticStyle);
var
  LSession: TNamedVoiceSession;
  LGenerated: TWfcMusicVoicesGenerated;
  LReport: TGraphNegotiationReport;
  LProof: TWfcMusicVoicesValidationReport;
  LValidation: TWfcSequenceGraphValidationReport;
  LModel: TWfcSequenceModel;
  LStates: TWfcSequenceStateIndices;
  LIndex: Integer;
begin
  LSession := AStyle.CreateVoiceSession(731);
  LModel := nil;
  try
    Check(LSession.TryGenerate(LGenerated, LReport, LProof), 'Independent boundary baseline');
    LModel := DecodeWfcSequenceText(AStyle.CopyDefinition.Providers[3].ModelText);
    SetLength(LStates, 6);
    for LIndex := 0 to 5 do
    begin
      LStates[LIndex] := LGenerated.Layers[3].StateIndices[LIndex mod 3];
    end;
    Check(not ValidateSequenceStatePath(LModel, LStates, wseWhole, LValidation),
      'Blend must not introduce an end-to-start cross-song transition');
  finally
    LModel.Free;
    LSession.Free;
  end;
end;

procedure ConflictChecks(const ASoundA, ASoundB: TWaveStyleProfile;
  const ALeft, ARight: TSemanticStyle);
var
  LDefinition: TSemanticStyleDefinition;
  LOther: TSemanticStyle;
  LRecipe: TSemanticBlendRecipe;
  LCase: Integer;
  LProvider: Integer;
  LBytes: TAudioBytes;
  LRejected: Boolean;
  LContract: TProviderContract;
begin
  LOther := nil;
  try
    for LCase := 0 to 5 do
    begin
      LDefinition := NamedDefinition(False, ASoundA);
      case LCase of
        0:
          begin
            LDefinition.Providers[3].Contract.Name := 'upper';
            LDefinition.Providers[3].Contract.RoleId := 'upper';
            LDefinition.Providers[1].Contract.RoleOrder[1] := 'upper';
            LDefinition.Sounds[0].RoleId := 'upper';
          end;
        1:
          begin
            for LProvider := 0 to 3 do
            begin
              LDefinition.Providers[LProvider].Contract.TicksPerQuarter := 240;
              LDefinition.Providers[LProvider].Contract.TimeGrid.TicksPerCell := 120;
            end;
          end;
        2:
          begin
            LDefinition.VoicePairs[0].MaxGap := 24;
          end;
        3:
          begin
            LDefinition.Sources[0].Sha256 := StringOfChar('e', 64);
            LDefinition.Sources[0].OriginSha256 := StringOfChar('a', 64);
            LDefinition.Sources[0].OriginStartFrame := 250;
            LDefinition.Sources[0].FrameCount := 3750;
            LDefinition.Sources[0].PreparationEvidence := [Ord('c'), Ord('r'), Ord('o'), Ord('p')];
            LDefinition.Sources[0].PreparationSha256 := SemanticPreparationIdentity(LDefinition.Sources[0]);
          end;
        4:
          begin
            LDefinition.Sources[0].Sha256 := StringOfChar('e', 64);
            LDefinition.Sources[0].OriginSha256 := StringOfChar('a', 64);
            LDefinition.Sources[0].PreparationEvidence := [Ord('r'), Ord('e'), Ord('c'), Ord('o'), Ord('d'), Ord('e')];
            LDefinition.Sources[0].PreparationSha256 := SemanticPreparationIdentity(LDefinition.Sources[0]);
            LDefinition.Providers[3].ExtractionPolicy := 'Conflicting independent annotation policy';
          end;
        5:
          begin
            LDefinition.Runs[0].Tokens[3][0] := VoiceToken(wmcaAttack, 60, 40);
            LDefinition.Runs[0].Tokens[3][1] := VoiceToken(wmcaHold, 60, 40);
            LDefinition.Providers[3].Preferences := nil;
            LearnProviders(LDefinition);
          end;
      end;
      LOther := TSemanticStyle.CreateSource(LDefinition);
      RejectBlend(ALeft, LOther, EqualRecipe(4, srpMaximum));
      FreeAndNil(LOther);
    end;

    LContract := ALeft.CopyDefinition.Providers[3].Contract;
    LContract.PitchBasis := ppbRelativeKey;
    LRejected := False;
    try
      RequireCompatibleProvider(ALeft.CopyDefinition.Providers[3].Contract, LContract);
    except
      on E: EAudio do
      begin
        LRejected := True;
      end;
    end;
    Check(LRejected, 'Relative pitch cannot silently replace absolute MIDI roles');

    LDefinition := NamedDefinition(True, ASoundB);
    SetLength(LDefinition.Sources, 3);
    LDefinition.Sources[2] := Source(4);
    LDefinition.Sources[2].GroupId := 'controlled-group-0';
    LDefinition.Sources[2].Exposure := [seCalibration];
    LOther := TSemanticStyle.CreateSource(LDefinition);
    LRecipe := EqualRecipe(4, srpMaximum);
    for LProvider := 0 to 3 do
    begin
      LRecipe.Providers[LProvider].RightWeight := 0;
    end;
    RejectBlend(ALeft, LOther, LRecipe);
    FreeAndNil(LOther);

    LRecipe := EqualRecipe(4, srpMaximum);
    LRecipe.Providers[0].LeftWeight := 0;
    LRecipe.Providers[0].RightWeight := 0;
    RejectBlend(ALeft, ARight, LRecipe);
    LRecipe := EqualRecipe(4, srpMaximum);
    LRecipe.Providers[0].LeftWeight := 65;
    RejectBlend(ALeft, ARight, LRecipe);
    LRecipe := EqualRecipe(4, srpMaximum);
    LRecipe.Providers[0].LeftWeight := 64;
    RejectBlend(ALeft, ARight, LRecipe); { Product192 survives GCD and exceeds64. }
    LRecipe := EqualRecipe(4, srpMaximum);
    LRecipe.Providers[0].ControlParent := 2;
    RejectBlend(ALeft, ARight, LRecipe);

    LOther := TSemanticStyle.CreateBlend(ALeft, ARight, Recipe);
    LBytes := LOther.Encode;
    FreeAndNil(LOther);
    LBytes[Length(LBytes) div 2] := LBytes[Length(LBytes) div 2] xor 1;
    LRejected := False;
    try
      LOther := DecodeSemanticStyle(LBytes);
    except
      on E: EAudio do
      begin
        LRejected := True;
      end;
    end;
    Check(LRejected and (LOther = nil), 'Corrupt blend lineage cannot publish a partial result');
  finally
    LOther.Free;
  end;
end;

procedure MappedBlendChecks;
var
  LDefinition: TSemanticStyleDefinition;
  LLeft: TSemanticStyle;
  LRight: TSemanticStyle;
  LBlend: TSemanticStyle;
  LLoaded: TSemanticStyle;
  LRecipe: TSemanticBlendRecipe;
begin
  LLeft := nil;
  LRight := nil;
  LBlend := nil;
  LLoaded := nil;
  try
    LLeft := TSemanticStyle.CreateSource(GridDefinition);
    LDefinition := GridDefinition;
    LDefinition.Sources[0] := Source(2);
    LDefinition.Sources[1] := Source(3);
    LRight := TSemanticStyle.CreateSource(LDefinition);
    LRecipe := EqualRecipe(3, srpMaximum);
    LRecipe.Providers[0].LeftWeight := 3;
    LRecipe.Providers[1].RightWeight := 3;
    LBlend := TSemanticStyle.CreateBlend(LLeft, LRight, LRecipe);
    LDefinition := LBlend.CopyDefinition;
    Check((LDefinition.Runs[0].Weights[0] = 3) and (LDefinition.Runs[0].Weights[1] = 1),
      'Connected mapped providers retain independently selected marginal weights');
    LLoaded := DecodeSemanticStyle(LBlend.Encode);
    SameGrid(LBlend, LLoaded);
    SaveFixture('-mapped.pysg', LBlend.Encode);
    FreeAndNil(LRight);
    LDefinition := GridDefinition;
    LDefinition.Projections[0].TimeMapping := ltmStartTick;
    LRight := TSemanticStyle.CreateSource(LDefinition);
    RejectBlend(LLeft, LRight, LRecipe);
  finally
    LLoaded.Free;
    LBlend.Free;
    LRight.Free;
    LLeft.Free;
  end;
end;
procedure MainChecks;
var
  LSoundA: TWaveStyleProfile;
  LSoundB: TWaveStyleProfile;
  LA: TSemanticStyle;
  LB: TSemanticStyle;
  LBlend: TSemanticStyle;
  LLoaded: TSemanticStyle;
  LFurther: TSemanticStyle;
  LDiamond: TSemanticStyle;
  LAdd: TSemanticStyle;
  LChanged: TSemanticStyle;
  LDerived: TSemanticStyle;
  LParent: TSemanticStyle;
  LRecipe: TSemanticBlendRecipe;
  LDefinition: TSemanticStyleDefinition;
  LOriginal: TSemanticStyleDefinition;
  LBytes: TAudioBytes;
  LRendered: TAudioBytes;
  LProvider: Integer;
  LRun: Integer;
  LWeightA: Integer;
  LWeightB: Integer;
  LIndex: Integer;
  LHash: String;
begin
  LSoundA := nil;
  LSoundB := nil;
  LA := nil;
  LB := nil;
  LBlend := nil;
  LLoaded := nil;
  LFurther := nil;
  LDiamond := nil;
  LAdd := nil;
  LChanged := nil;
  LDerived := nil;
  LParent := nil;
  try
    LSoundA := SoundProfile(False);
    LSoundB := SoundProfile(True);
    LA := TSemanticStyle.CreateSource(NamedDefinition(False, LSoundA));
    LB := TSemanticStyle.CreateSource(NamedDefinition(True, LSoundB));
    LBlend := TSemanticStyle.CreateBlend(LA, LB, Recipe);
    LLoaded := DecodeSemanticStyle(LBlend.Encode);
    Check(LBlend.Identity = LLoaded.Identity, 'Canonical unequal-weight blend reload');
    SameGeneration(LBlend, LLoaded);
    NoCrossSongTransition(LBlend);
    ConflictChecks(LSoundA, LSoundB, LA, LB);
    LDefinition := LBlend.CopyDefinition;
    Check(Length(LDefinition.Sources) = 4, 'Both musical and sound source ledgers retained');
    for LProvider := 0 to 3 do
    begin
      LWeightA := 0;
      LWeightB := 0;
      for LRun := 0 to High(LDefinition.Runs) do
      begin
        if LDefinition.Sources[LDefinition.Runs[LRun].SourceIndex].Sha256 = StringOfChar('a', 64) then
        begin
          Inc(LWeightA, LDefinition.Runs[LRun].Weights[LProvider]);
        end
        else
        begin
          Inc(LWeightB, LDefinition.Runs[LRun].Weights[LProvider]);
        end;
      end;
      case LProvider of
        0: Check((LWeightA = 6) and (LWeightB = 6), 'Harmony equal contribution');
        1: Check((LWeightA = 18) and (LWeightB = 6), 'Rhythm genuinely unequal contribution');
        2: Check((LWeightA = 0) and (LWeightB = 6), 'Independent bass selection');
        3: Check((LWeightA = 6) and (LWeightB = 24), 'Voice independent unequal contribution');
      end;
    end;
    LOriginal := LA.CopyDefinition;
    Check(LDefinition.Runs[0].ProviderEvidence[3] = LOriginal.Runs[0].ProviderEvidence[3],
      'Original provider annotation identity survives marginal weighting');
    LParent := LBlend.CopyParent(0);
    Check(LParent.Identity = LA.Identity, 'Exact joint observation owner retained');
    FreeAndNil(LParent);
    LHash := LBlend.Identity;
    LRecipe := LBlend.CopyBlendRecipe;
    LRecipe.Providers[0].LeftWeight := 64;
    LDefinition.Runs[0].ProviderEvidence[0] := 'mutated';
    Check(LBlend.Identity = LHash, 'Detached recipe and lineage outputs');
    LRendered := RenderSound(LBlend);
    Check(Sha256Bytes(LRendered) = Sha256Bytes(RenderSound(LLoaded)), 'Reloaded independent sound blend exact PCM');
    SaveFixture('-blend.pysg', LBlend.Encode);
    SaveFixture('-blend.wav', LRendered);

    LRecipe := Recipe;
    LRecipe.Providers[3].LeftWeight := 4;
    LRecipe.Providers[3].RightWeight := 1;
    LChanged := TSemanticStyle.CreateBlend(LA, LB, LRecipe);
    CheckModelsAndControls(LBlend, LChanged, 3);
    Check(LBlend.CopyDefinition.Providers[3].ModelText <> LChanged.CopyDefinition.Providers[3].ModelText,
      'Voice weight change reaches actual learned model');
    PairedAcceptedEdit(LBlend, LChanged);
    Check(Sha256Bytes(RenderSound(LBlend)) = Sha256Bytes(RenderSound(LChanged)),
      'Musical training edit leaves independent sound bytes/audio unchanged');
    FreeAndNil(LChanged);

    LRecipe := Recipe;
    LRecipe.Sounds[0].LeftTimbreWeight := 4;
    LRecipe.Sounds[0].RightTimbreWeight := 1;
    LChanged := TSemanticStyle.CreateBlend(LA, LB, LRecipe);
    CheckModelsAndControls(LBlend, LChanged, -1);
    SameGeneration(LBlend, LChanged);
    Check(Sha256Bytes(LBlend.CopyDefinition.Sounds[0].Envelope) =
      Sha256Bytes(LChanged.CopyDefinition.Sounds[0].Envelope), 'Timbre edit preserves exact envelope binding');
    LBytes := RenderSound(LChanged);
    Check(Sha256Bytes(LRendered) <> Sha256Bytes(LBytes), 'Independent timbre edit is audible');
    SaveFixture('-changed-timbre.wav', LBytes);
    FreeAndNil(LChanged);

    LRecipe := Recipe;
    LRecipe.Sounds[0].LeftEnvelopeWeight := 1;
    LRecipe.Sounds[0].RightEnvelopeWeight := 4;
    LChanged := TSemanticStyle.CreateBlend(LA, LB, LRecipe);
    CheckModelsAndControls(LBlend, LChanged, -1);
    Check(Sha256Bytes(LBlend.CopyDefinition.Sounds[0].Timbre) =
      Sha256Bytes(LChanged.CopyDefinition.Sounds[0].Timbre), 'Envelope edit preserves exact timbre binding');
    LBytes := RenderSound(LChanged);
    Check(Sha256Bytes(LRendered) <> Sha256Bytes(LBytes), 'Independent envelope edit is audible');
    SaveFixture('-changed-envelope.wav', LBytes);
    FreeAndNil(LChanged);

    LRecipe := Recipe;
    for LProvider := 0 to 3 do
    begin
      LRecipe.Providers[LProvider].LeftWeight := LRecipe.Providers[LProvider].LeftWeight * 2;
      LRecipe.Providers[LProvider].RightWeight := LRecipe.Providers[LProvider].RightWeight * 2;
    end;
    LChanged := TSemanticStyle.CreateBlend(LA, LB, LRecipe);
    CheckModelsAndControls(LBlend, LChanged, -1);
    SameGeneration(LBlend, LChanged);
    FreeAndNil(LChanged);

    LRecipe := EqualRecipe(4, srpMaximum);
    SetLength(LRecipe.Sounds, 1);
    LRecipe.Sounds[0].RoleId := 'lead';
    LRecipe.Sounds[0].LeftTimbreWeight := 1;
    LRecipe.Sounds[0].LeftEnvelopeWeight := 1;
    LFurther := TSemanticStyle.CreateBlend(LBlend, LA, LRecipe);
    FreeAndNil(LLoaded);
    LLoaded := DecodeSemanticStyle(LFurther.Encode);
    Check((LFurther.NodeCount = 5) and (LFurther.Depth = 3), 'Further blend node/depth ownership');
    SameGeneration(LFurther, LLoaded);
    SaveFixture('-further.pysg', LFurther.Encode);
    Check(Sha256Bytes(RenderSound(LFurther)) = Sha256Bytes(RenderSound(LLoaded)),
      'Further blend retains reusable owned sound on reload');
    SaveFixture('-further.wav', RenderSound(LFurther));
    LParent := LLoaded.CopyParent(0);
    Check(LParent.Identity = LBlend.Identity, 'Further blend retains complete intermediate lineage');
    FreeAndNil(LParent);
    LDiamond := TSemanticStyle.CreateBlend(LBlend, LBlend, LRecipe);
    Check(LDiamond.NodeCount = 7, 'Diamond counts repeated encoded parent occurrences');
    LDefinition := LDiamond.CopyDefinition;
    LOriginal := LBlend.CopyDefinition;
    for LProvider := 0 to 3 do
    begin
      Check(LDefinition.Providers[LProvider].ModelText = LOriginal.Providers[LProvider].ModelText,
        'Maximum policy prevents accidental diamond double-counting');
    end;
    RejectBlend(LDiamond, LA, LRecipe);
    SaveFixture('-diamond.pysg', LDiamond.Encode);
    LRecipe.RepeatPolicy := srpAddExplicit;
    LAdd := TSemanticStyle.CreateBlend(LBlend, LA, LRecipe);
    Check(LAdd.CopyDefinition.Providers[0].ModelText <> LFurther.CopyDefinition.Providers[0].ModelText,
      'Explicit addition differs from canonical maximum coverage');
    SaveFixture('-explicit-add.pysg', LAdd.Encode);

    LDefinition := LFurther.CopyDefinition;
    LDefinition.Providers[3].Preferences := [MakeLayerTokenPreference(VoiceToken(wmcaAttack, 60, 90), 5)];
    LDerived := TSemanticStyle.CreateDerived(LFurther, LDefinition);
    FreeAndNil(LLoaded);
    LLoaded := DecodeSemanticStyle(LDerived.Encode);
    Check(LLoaded.CopyDefinition.Providers[3].Preferences[0].Multiplier = 5,
      'Further blend supports independent preference-only derivation');
    SameGeneration(LDerived, LLoaded);
    SaveFixture('-preferred-further.pysg', LDerived.Encode);

    LRecipe := Recipe;
    for LIndex := 0 to 3 do
    begin
      LRecipe.Providers[LIndex].RightWeight := 0;
      LRecipe.Providers[LIndex].LeftWeight := 1;
    end;
    LRecipe.Sounds[0].RightTimbreWeight := 0;
    LRecipe.Sounds[0].RightEnvelopeWeight := 0;
    LChanged := TSemanticStyle.CreateBlend(LA, LB, LRecipe);
    Check(Length(LChanged.CopyDefinition.Sources) = 4, 'Zero-selected parent exposure remains retained');
    LParent := LChanged.CopyParent(1);
    Check(LParent.Identity = LB.Identity, 'Zero-selected full joint parent remains auditable');
    FreeAndNil(LParent);
    FreeAndNil(LChanged);

    LRecipe := Recipe;
    RejectBlend(LA, LA, LRecipe); { Repeated sound requires explicit addition. }
    LRecipe.Sounds[0].RepeatPolicy := ssrpAddExact;
    LChanged := TSemanticStyle.CreateBlend(LA, LA, LRecipe);
    Check(Sha256Bytes(RenderSound(LChanged)) = Sha256Bytes(RenderSound(LA)),
      'Explicit exact repeated sound normalizes through actual PYS composition');
  finally
    LParent.Free;
    LDerived.Free;
    LChanged.Free;
    LAdd.Free;
    LDiamond.Free;
    LFurther.Free;
    LLoaded.Free;
    LBlend.Free;
    LB.Free;
    LA.Free;
    LSoundB.Free;
    LSoundA.Free;
  end;
end;

begin
  Check(ParamCount <= 1, 'Usage: pythian.tests.semantic.blend [OUTPUT_PREFIX]');
  MainChecks;
  MappedBlendChecks;
  WriteLn('Semantic blends: independent weights, joint ancestry, canonical contributions and owned generation/sound replay pass');
end.
