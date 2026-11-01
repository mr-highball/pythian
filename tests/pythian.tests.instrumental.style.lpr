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
program instrumental_style_checks;

{$mode delphi}{$H+}

uses SysUtils, Math, pythian.audio, pythian.time, pythian.hash, pythian.text,
  pythian.instrument.catalog, pythian.instrument.recipe, pythian.sound.recipe.codec,
  pythian.mix.recipe, pythian.effects.catalog, pythian.effects.rack,
  pythian.percussion, pythian.bus, pythian.progress,
  pythian.music.controls, pythian.music.decisions,
  pythian.chord, pythian.music.proposal,
  pythian.wfc.semantic.corpus, pythian.wfc.musical.corpus,
  pythian.wfc.music,
  pythian.wfc.semantic.style, pythian.wfc.instrumental.stream,
  pythian.wfc.layers, pythian.wfc.providers, pythian.wfc.provider.contracts,
  pythian.wfc.learning, pythian.wfc.percussion,
  wfc_model, wfc_sequence, wfc_sequence_text, wfc_sequence_learn, wfc_music_ensemble,
  wfc_music_sequence, wfc_music_ensemble_graph;

const CRate = 24000;
  CNames: array[0..8] of String =
    ('harmony', 'rhythm', 'bass', 'chords', 'lead', 'context', 'kick', 'snare', 'hat');
var GChecks: Integer;

type
  TCancel = class
    procedure Observe(const AWork: TWorkProgress);
  end;

procedure TCancel.Observe(const AWork: TWorkProgress);
begin
  if AWork.Stage = 'semantic_instrumental_ready' then
    raise EAbort.Create('Requested construction cancellation');
end;

procedure Check(const ACondition: Boolean; const AMessage: String);
begin
  Inc(GChecks);
  if not ACondition then raise Exception.Create(AMessage);
end;

function Definition: TSemanticStyleDefinition;
var
  LModel: TWfcSequenceModel;
  LContext: TMusicalContextCell;
  LSingle: TWfcMusicEnsembleFrame;
  LCatalog: TInstrumentRecipes;
  LSample: TWfcSequenceSamples;
  LEffect: TCatalogEffect;
  P: Integer;
  C: Integer;
  R: Integer;
begin
  Result := Default(TSemanticStyleDefinition);
  Result.NamedVoices := True;
  Result.HarmonyMode := wmehmExact;
  SetLength(Result.VoiceRanges, 3);
  SetLength(Result.Providers, 9);
  SetLength(Result.Sources, 1);
  with Result.Sources[0] do
  begin
    Sha256 := StringOfChar('a', 64);
    GroupId := 'authored-complete-instrumental-example';
    Split := ssTraining;
    Exposure := [seTraining, seVocabulary];
    SampleRate := 1000;
    FrameCount := 2000;
    ExternalRequirement := 'Authored symbolic declaration; no inferred recording claim';
    OriginSha256 := Sha256;
    OriginSampleRate := SampleRate;
    OriginFrameCount := FrameCount;
    OriginEndFrame := FrameCount;
    PreparationEvidence := EncodeUTF8Text('Authored score', 1024);
    PreparationSha256 := SemanticPreparationIdentity(Result.Sources[0]);
  end;
  SetLength(Result.Runs, 1);
  with Result.Runs[0] do
  begin
    Identity := 'authored-eight-cells';
    EndFrame := 2000;
    TicksPerQuarter := 480;
    TempoChanges := [MakeTempoChange(0, 500000)];
    SetLength(TimeGrids, 9);
    SetLength(Tokens, 9);
    SetLength(Weights, 9);
    for P := 0 to 8 do
    begin
      TimeGrids[P] := MakeLayerTimeGrid(0, 240);
      SetLength(Tokens[P], 8);
      Weights[P] := 1;
    end;
  end;
  LContext := Default(TMusicalContextCell);
  LContext.DrivenRole := 2;
  SetLength(LContext.Frame.Voices, 3);
  SetLength(LSingle.Voices, 1);
  for C := 0 to 7 do
  begin
    for R := 0 to 2 do
    begin
      LContext.Frame.Voices[R].Action := wmcaAttack;
      SetLength(LContext.Frame.Voices[R].Tones, 1);
      LContext.Frame.Voices[R].Tones[0].Pitch := 36 + R * 12 + (C mod 2) * 7;
      LContext.Frame.Voices[R].Tones[0].Velocity := 92 + R * 5;
      LSingle.Voices[0] := LContext.Frame.Voices[R];
      Result.Runs[0].Tokens[R + 2][C] := EncodeWfcMusicEnsembleFrame(LSingle);
    end;
    Result.Runs[0].Tokens[0][C] := EncodeWfcMusicPitchClassSet(
      ProjectWfcMusicEnsembleFrameToPitchClassSet(LContext.Frame, 12));
    Result.Runs[0].Tokens[1][C] := EncodeWfcMusicRhythmFrame(
      ProjectWfcMusicEnsembleFrameToRhythm(LContext.Frame));
    Result.Runs[0].Tokens[5][C] := EncodeMusicalContextToken(LContext);
    Result.Runs[0].Tokens[6][C] := PercussionToken(100 * Ord((C mod 2) = 0));
    Result.Runs[0].Tokens[7][C] := PercussionToken(95 * Ord((C mod 2) = 1));
    Result.Runs[0].Tokens[8][C] := PercussionToken(75);
  end;
  SetLength(LSample, 1);
  for P := 0 to 8 do
  begin
    with Result.Providers[P] do
    begin
      Contract.Name := CNames[P];
      Contract.MusicalDomain := 'caller-defined instrumental experiment';
      Contract.TicksPerQuarter := 480;
      Contract.Scope := MakeLayerScope(8, wseWhole);
      Contract.TimeGrid := MakeLayerTimeGrid(0, 240);
      case P of
        0: Contract.Vocabulary := spvHarmony;
        1: Contract.Vocabulary := spvRhythm;
        2..4: Contract.Vocabulary := spvVoice;
        5: Contract.Vocabulary := spvMusicalContext;
        6..8: Contract.Vocabulary := spvPercussion;
      end;
      if P in [1, 5] then Contract.RoleOrder := ['bass', 'chords', 'lead'];
      if P in [2..5] then Contract.PitchBasis := ppbAbsoluteMidi;
      if P in [2..4] then Contract.RoleId := CNames[P];
      if P = 5 then Contract.RoleId := 'lead';
      Contract.UnknownPolicy := ProviderUnknownPolicy(Contract.Vocabulary);
      ExtractionPolicy := 'Authored; not measured or learned from source PCM';
      LSample[0] := MakeWfcSequenceSample(Result.Runs[0].Tokens[P]);
      LModel := LearnSequenceModelCorpus(LSample, 1);
      try
        ModelText := EncodeWfcSequenceText(LModel);
        VocabularySha256 := SemanticVocabularyIdentity(ModelText, Contract);
      finally
        LModel.Free;
      end;
    end;
  end;
  for R := 0 to 2 do
  begin
    Result.VoiceRanges[R].MinimumPitch := 36 + R * 12;
    Result.VoiceRanges[R].MaximumPitch := 43 + R * 12;
  end;
  LCatalog := BuiltInInstrumentRecipes;
  with Result.Instrumental do
  begin
    Enabled := True;
    LabelText := String(ScalarText($4F60) + ScalarText($1F3B5));
    Origin := 'Authored musical graph and operator-selected primary instruments';
    SampleRate := CRate;
    Options := DefaultInstrumentalStreamOptions(CRate * 2);
    Options.TailFrames := CRate;
    Options.SegmentCells := 4;
    Instruments := [LCatalog[0], LCatalog[4], LCatalog[5]];
    Mix := DefaultStemMixRecipe(6);
    SetLength(Mix.Parts[2].Effects, 1);
    Mix.Parts[2].Effects[0] := DefaultEffectRecipe(ceDelay);
    SetLength(Mix.MasterEffects, Ord(High(TCatalogEffect)) + 1);
    for LEffect := Low(TCatalogEffect) to High(TCatalogEffect) do
    begin
      Mix.MasterEffects[Ord(LEffect)] := DefaultEffectRecipe(LEffect);
    end;
    SetLength(Percussion, 3);
    SetLength(Expression, 6);
    for R := 0 to 5 do Expression[R] := DefaultMusicalExpression;
    Expression[2].VelocityPercent := 80;
    for R := 0 to 2 do
    begin
      Percussion[R].Name := CNames[6 + R];
      Percussion[R].Origin := 'Authored primary percussion';
      Percussion[R].Settings := DefaultPercussionSettings(TPercussionKind(R), CRate);
      Percussion[R].OutputBus := 3 + R;
      Percussion[R].Enabled := True;
      Percussion[R].HitWeight := 1;
    end;
    SetLength(Form, 2);
    for R := 0 to 1 do
    begin
      Form[R].Section := 'Verse';
      Form[R].Name := 'Phrase';
      Form[R].Cells := 4;
      Form[R].RepeatFrom := -1;
    end;
    Form[1].RepeatFrom := 0;
    Form[1].Keep := ['rhythm', 'bass'];
    Form[1].EnergyOffset := 10;
    Form[1].DensityOffset := 5;
  end;
  Result.Providers[2].Preferences := [MakeLayerTokenPreference(Result.Runs[0].Tokens[2][0], 3)];
  Result.Providers[5].Constraints := [MakeWfcSequenceTokenConstraint(0,
    [Result.Runs[0].Tokens[5][0]])];
end;

procedure Failures;
var
  LDefinition: TSemanticStyleDefinition;
  LStyle: TSemanticStyle;
  LBytes: TAudioBytes;
  LRejected: Boolean;
  LCase: Integer;
  LCancel: TCancel;
  LStream: TSemanticInstrumentalStream;
begin
  LStyle := nil;
  LStream := nil;
  LCancel := TCancel.Create;
  try
    for LCase := 0 to 3 do
    begin
      LDefinition := Definition;
      case LCase of
        0: LDefinition.Instrumental.Percussion[1].OutputBus := 0;
        1: LDefinition.Providers[2].Preferences[0].Token := 'absent';
        2: LDefinition.Instrumental.Expression[0].GatePercent := 75;
        3: LDefinition.Instrumental.Options.TicksPerQuarter := 960;
      end;
      LRejected := False;
      try
        LStyle := TSemanticStyle.CreateSource(LDefinition);
      except
        on EAudio do LRejected := True;
      end;
      Check(LRejected and (LStyle = nil), 'Invalid binding or unsupported control admitted');
    end;
    LDefinition := Definition;
    LStyle := TSemanticStyle.CreateSource(LDefinition);
    LRejected := False;
    try
      LStream := LStyle.CreateInstrumentalStream(LCancel.Observe);
    except
      on EAbort do LRejected := True;
    end;
    Check(LRejected and (LStream = nil), 'Canceled complete stream was published');
    LBytes := LStyle.Encode;
    FreeAndNil(LStyle);
    LBytes[Length(LBytes) div 2] := LBytes[Length(LBytes) div 2] xor 1;
    LRejected := False;
    try
      LStyle := DecodeSemanticStyle(LBytes);
    except
      on EAudio do LRejected := True;
    end;
    Check(LRejected and (LStyle = nil), 'Damaged complete style admitted');
  finally
    LStream.Free;
    LCancel.Free;
    LStyle.Free;
  end;
end;

function CorpusDefinition: TSemanticStyleDefinition;
var
  LBase: TSemanticStyleDefinition;
  LSources: TMusicalCorpusSources;
  LSelections: TMusicalCorpusSelections;
  LRuns: TMusicalCorpusRuns;
  LCorpus: TMusicalCorpus;
  LContext: TMusicalContextCell;
  LCopy: TMusicalProviderSamples;
  LTexts: TLayerModelTexts;
  I: Integer;
  P: Integer;
begin
  LBase := Definition;
  SetLength(LSources, 1);
  LSources[0].Sha256 := LBase.Sources[0].Sha256;
  LSources[0].GroupId := LBase.Sources[0].GroupId;
  LSources[0].SampleRate := 1000;
  LSources[0].FrameCount := 2401;
  LSources[0].TrainingWeight := 2;
  LBase.Sources[0].FrameCount := 2401;
  LBase.Sources[0].OriginFrameCount := 2401;
  LBase.Sources[0].OriginEndFrame := 2401;
  LBase.Sources[0].PreparationSha256 := SemanticPreparationIdentity(LBase.Sources[0]);
  SetLength(LSelections, 1);
  LSelections[0].EndFrame := 2401;
  SetLength(LRuns, 1);
  LRuns[0].Grid.Version := MusicalProposalVersion;
  LRuns[0].Grid.Policy := 'Authored synthetic proposal; no source inference claim';
  LRuns[0].Grid.SampleRate := 1000;
  LRuns[0].Grid.SourceFrames := 2401;
  LRuns[0].Grid.TempoMicroseconds := 600001;
  LRuns[0].Grid.RoleNames := ['bass', 'chords', 'lead'];
  LRuns[0].Grid.RoleOrigins := ['Authored bass', 'Authored chords', 'Authored lead'];
  SetLength(LRuns[0].Grid.Frames, 8);
  SetLength(LRuns[0].Grid.Known, 8);
  SetLength(LRuns[0].Grid.PitchOrigins, 8);
  SetLength(LRuns[0].Grid.Drums, 8);
  SetLength(LRuns[0].AdmittedCells, 8);
  for I := 0 to 7 do
  begin
    LContext := DecodeMusicalContextToken(LBase.Runs[0].Tokens[5][I]);
    LRuns[0].Grid.Frames[I] := ProjectWfcChordFrame(LContext.Frame);
    LRuns[0].Grid.Known[I] := True;
    LRuns[0].Grid.PitchOrigins[I] := mppPeriodic;
    LRuns[0].AdmittedCells[I] := (I <> 0) and (I <> 4);
    for P := 0 to 2 do
      LRuns[0].Grid.Drums[I][P] := PercussionVelocity(LBase.Runs[0].Tokens[P + 6][I]);
  end;
  LCorpus := TMusicalCorpus.Create(LSources, LSelections, LRuns);
  try
    Result := MusicalCorpusStyleDefinition(LCorpus, LBase.Sources, LBase.Instrumental);
    LTexts := LCorpus.CopyModelTexts;
    Check(Length(Result.Providers) = Length(LTexts), 'Corpus capture loses a provider');
    for P := 0 to High(LTexts) do
      Check(Result.Providers[P].ModelText = LTexts[P], 'Corpus capture substitutes a learned model');
    Check((Length(Result.Runs) = 2) and (Result.Runs[0].ClockStartTick = 240) and
      (Result.Runs[0].Weights[0] = 2) and (Result.Runs[1].GapBeforeFrames > 0),
      'Corpus capture loses fractional phase, training influence or an omitted gap');
    Check((Result.Runs[0].ProposalPolicy = LRuns[0].Grid.Policy) and
      (Result.Runs[0].RoleOrigins[0] = LRuns[0].Grid.RoleOrigins[0]),
      'Corpus capture loses actual proposal origins');
    LCopy := LCorpus.CopyTrainingSamples;
    LCopy[0][0].Tokens[0] := 'mutated detached sample';
    Check(LCorpus.CopyTrainingSamples[0][0].Tokens[0] <> LCopy[0][0].Tokens[0],
      'Saved learning samples alias the corpus');
  finally
    LCorpus.Free;
  end;
end;

procedure Replay(const ADefinition: TSemanticStyleDefinition);
var
  LDefinition: TSemanticStyleDefinition;
  LStyle: TSemanticStyle;
  LLoaded: TSemanticStyle;
  LA: TSemanticInstrumentalStream;
  LB: TSemanticInstrumentalStream;
  LMasterA: TAudioSamples;
  LMasterB: TAudioSamples;
  LStemsA: TBusSampleBlocks;
  LStemsB: TBusSampleBlocks;
  LEnergy: array[0..5] of Double;
  LDecisionsA: TMusicDecisionChunk;
  LDecisionsB: TMusicDecisionChunk;
  LBefore: TAudioBytes;
  I: Integer;
  P: Integer;
  LFrames: Int64;
begin
  LDefinition := ADefinition;
  LStyle := TSemanticStyle.CreateSource(LDefinition);
  LLoaded := nil;
  LA := nil;
  LB := nil;
  try
    LBefore := LStyle.Encode;
    WriteLn('Complete instrumental archive ', Sha256Bytes(LBefore));
    LLoaded := DecodeSemanticStyle(LBefore);
    Check(LLoaded.Identity = LStyle.Identity, 'Instrumental archive identity differs');
    Check(Length(LLoaded.CopyDefinition.Providers) = 9, 'Context or drums were lost');
    Check(LLoaded.CopyDefinition.Instrumental.LabelText = LDefinition.Instrumental.LabelText,
      'Caller Unicode style label was lost');
    LA := LStyle.CreateInstrumentalStream;
    LB := LLoaded.CreateInstrumentalStream;
    FreeAndNil(LStyle);
    FreeAndNil(LLoaded);
    LDefinition.Instrumental.Instruments[0].Zones[0].Voice.Gain := 0;
    LFrames := 0;
    for P := 0 to 5 do LEnergy[P] := 0;
    while LA.Stream.ReadOutputs(511, [6, 7, 8, 9, 10, 11], LMasterA, LStemsA) do
    begin
      Check(LB.Stream.ReadOutputs(511, [6, 7, 8, 9, 10, 11], LMasterB, LStemsB), 'Reloaded stream ended early');
      Check(Length(LMasterA) = Length(LMasterB), 'Reloaded stream clock differs');
      for I := 0 to High(LMasterA) do
      begin
        Check(Abs(LMasterA[I] - LMasterB[I]) < 1E-12, 'Reloaded mix changed');
        for P := 0 to 5 do
        begin
          Check(Abs(LStemsA[P][I] - LStemsB[P][I]) < 1E-12, 'Reloaded part changed');
          LEnergy[P] := LEnergy[P] + Sqr(LStemsA[P][I]);
        end;
      end;
      Inc(LFrames, Length(LMasterA) div 2);
      LDecisionsA := LA.Stream.CopyLastDecisions;
      LDecisionsB := LB.Stream.CopyLastDecisions;
      Check(Sha256Bytes(EncodeMusicDecisions(LDecisionsA)) =
        Sha256Bytes(EncodeMusicDecisions(LDecisionsB)), 'Reloaded graph or expression changed');
    end;
    Check(LFrames = CRate * 3, 'Music and effect tail clock changed');
    for P := 0 to 5 do Check(LEnergy[P] > 0.0001, 'A complete pitched/drum stem is silent');
    Check(LA.Stream.PercussionHits > 0, 'No synthesized percussion was planned');
  finally
    LB.Free;
    LA.Free;
    LLoaded.Free;
    LStyle.Free;
  end;
end;

procedure Relearn(var ADefinition: TSemanticStyleDefinition);
var
  LModel: TWfcSequenceModel;
  LSamples: TWfcSequenceSamples;
  P: Integer;
begin
  SetLength(LSamples, 1);
  for P := 0 to High(ADefinition.Providers) do
  begin
    LSamples[0] := MakeWfcSequenceSample(ADefinition.Runs[0].Tokens[P]);
    LModel := LearnSequenceModelCorpus(LSamples, 1);
    try
      ADefinition.Providers[P].ModelText := EncodeWfcSequenceText(LModel);
      ADefinition.Providers[P].VocabularySha256 := SemanticVocabularyIdentity(
        ADefinition.Providers[P].ModelText, ADefinition.Providers[P].Contract);
    finally
      LModel.Free;
    end;
  end;
end;

function OtherDefinition: TSemanticStyleDefinition;
var
  LContext: TMusicalContextCell;
  LSingle: TWfcMusicEnsembleFrame;
  LCatalog: TInstrumentRecipes;
  C: Integer;
  R: Integer;
begin
  Result := Definition;
  Result.Sources[0].Sha256 := StringOfChar('b', 64);
  Result.Sources[0].GroupId := 'second-independent-authored-example';
  Result.Sources[0].OriginSha256 := Result.Sources[0].Sha256;
  Result.Sources[0].PreparationSha256 := SemanticPreparationIdentity(Result.Sources[0]);
  SetLength(LSingle.Voices, 1);
  for C := 0 to 7 do
  begin
    LContext := DecodeMusicalContextToken(Result.Runs[0].Tokens[5][C]);
    for R := 0 to 2 do
    begin
      Inc(LContext.Frame.Voices[R].Tones[0].Pitch, 12);
      LSingle.Voices[0] := LContext.Frame.Voices[R];
      Result.Runs[0].Tokens[R + 2][C] := EncodeWfcMusicEnsembleFrame(LSingle);
    end;
    Result.Runs[0].Tokens[5][C] := EncodeMusicalContextToken(LContext);
    Result.Runs[0].Tokens[7][C] := PercussionToken(113 * Ord((C mod 2) = 1));
    Result.Runs[0].Tokens[8][C] := PercussionToken(80);
  end;
  for R := 0 to 2 do
  begin
    Inc(Result.VoiceRanges[R].MinimumPitch, 12);
    Inc(Result.VoiceRanges[R].MaximumPitch, 12);
  end;
  for R := 0 to 8 do
  begin
    Result.Providers[R].Preferences := nil;
    Result.Providers[R].Constraints := nil;
  end;
  Result.Instrumental.LabelText := 'Another caller style';
  LCatalog := BuiltInInstrumentRecipes;
  Result.Instrumental.Instruments := [LCatalog[5], LCatalog[3], LCatalog[6]];
  Result.Instrumental.Expression[0].VelocityPercent := 140;
  Result.Instrumental.Mix.Parts[0].Gain := 0.4;
  Result.Instrumental.Mix.Parts[0].Pan := 0.25;
  Relearn(Result);
end;

procedure SameInstrumental(const ALeft, ARight: TSemanticStyle);
var
  LA: TSemanticInstrumentalStream;
  LB: TSemanticInstrumentalStream;
  LMasterA: TAudioSamples;
  LMasterB: TAudioSamples;
  LStemsA: TBusSampleBlocks;
  LStemsB: TBusSampleBlocks;
  I: Integer;
  P: Integer;
begin
  LA := ALeft.CreateInstrumentalStream;
  LB := nil;
  try
    LB := ARight.CreateInstrumentalStream;
    while LA.Stream.ReadOutputs(511, [6, 7, 8, 9, 10, 11], LMasterA, LStemsA) do
    begin
      Check(LB.Stream.ReadOutputs(511, [6, 7, 8, 9, 10, 11], LMasterB, LStemsB),
        'Instrumental blend replay ended early');
      Check(Length(LMasterA) = Length(LMasterB), 'Instrumental blend replay clock differs');
      for I := 0 to High(LMasterA) do
      begin
        Check(Abs(LMasterA[I] - LMasterB[I]) < 1E-12, 'Instrumental blend mix changed on reload');
        for P := 0 to 5 do
        begin
          Check(Abs(LStemsA[P][I] - LStemsB[P][I]) < 1E-12,
            'Instrumental blend stem changed on reload');
        end;
      end;
      Check(Sha256Bytes(EncodeMusicDecisions(LA.Stream.CopyLastDecisions)) =
        Sha256Bytes(EncodeMusicDecisions(LB.Stream.CopyLastDecisions)),
        'Instrumental blend decisions or expression changed on reload');
    end;
    Check(LA.Stream.PercussionHits > 0, 'Instrumental blend has no actual drums');
  finally
    LB.Free;
    LA.Free;
  end;
end;

procedure Seeds;
const
  CSeeds: array[0..3] of Cardinal = (0, $7FFFFFFF, $80000000, $FFFFFFFF);
var
  LDefinition: TSemanticStyleDefinition;
  LStyle: TSemanticStyle;
  LLoaded: TSemanticStyle;
  I: Integer;
begin
  for I := 0 to High(CSeeds) do
  begin
    LDefinition := Definition;
    LDefinition.Instrumental.Options.Seed := CSeeds[I];
    LStyle := TSemanticStyle.CreateSource(LDefinition);
    LLoaded := nil;
    try
      LLoaded := DecodeSemanticStyle(LStyle.Encode);
      Check(LLoaded.CopyDefinition.Instrumental.Options.Seed = CSeeds[I],
        'Instrumental archive changes an unsigned graph seed');
    finally
      LLoaded.Free;
      LStyle.Free;
    end;
  end;
end;

procedure Blends;
var
  LLeft: TSemanticStyle;
  LRight: TSemanticStyle;
  LBlend: TSemanticStyle;
  LLoaded: TSemanticStyle;
  LFurther: TSemanticStyle;
  LParent: TSemanticStyle;
  LRecipe: TSemanticBlendRecipe;
  LCopy: TSemanticStyleDefinition;
  LRightDefinition: TSemanticStyleDefinition;
  LBefore: String;
  LRejected: Boolean;
  LBad: TSemanticStyle;
  LCancel: TCancel;
  I: Integer;
begin
  LLeft := TSemanticStyle.CreateSource(Definition);
  LRight := nil;
  LBlend := nil;
  LLoaded := nil;
  LFurther := nil;
  LParent := nil;
  LBad := nil;
  LCancel := TCancel.Create;
  try
    LRightDefinition := OtherDefinition;
    LRight := TSemanticStyle.CreateSource(LRightDefinition);
    LBefore := LLeft.Identity;
    LRecipe := Default(TSemanticBlendRecipe);
    SetLength(LRecipe.Providers, 9);
    for I := 0 to 8 do LRecipe.Providers[I].LeftWeight := 1;
    for I in [2, 4, 5, 7] do
    begin
      LRecipe.Providers[I].LeftWeight := 0;
      LRecipe.Providers[I].RightWeight := 1;
      LRecipe.Providers[I].ControlParent := 1;
    end;
    LRecipe.Providers[3].RightWeight := 1;
    LRecipe.Providers[8].LeftWeight := 2;
    LRecipe.Providers[8].RightWeight := 1;
    LRecipe.Instrumental.Enabled := True;
    LRecipe.Instrumental.LabelText := 'Bass from B; harmony from both; independently selected sound';
    LRecipe.Instrumental.UnionPitchRanges := True;
    LRecipe.Instrumental.OverrideContextBinding := True;
    LRecipe.Instrumental.ContextBinding := icbDrivenRole;
    SetLength(LRecipe.Instrumental.Parts, 6);
    LRecipe.Instrumental.Parts[0].ExpressionParent := 1;
    LRecipe.Instrumental.Parts[0].EffectsParent := 1;
    LRecipe.Instrumental.Parts[1].InstrumentParent := 1;
    LBlend := TSemanticStyle.CreateBlend(LLeft, LRight, LRecipe);
    Check(LLeft.Identity = LBefore, 'Blending changed its source');
    Check(LBlend.NodeCount = 3, 'Instrumental blend lost a parent');
    LCopy := LBlend.CopyDefinition;
    Check(LCopy.Instrumental.Expression[0].VelocityPercent =
      LRightDefinition.Instrumental.Expression[0].VelocityPercent,
      'Instrumental blend loses the independently selected expression');
    { Big Boss: compare the stored Double with its selected parent. An untyped
      decimal literal can retain higher precision on Extended targets. }
    Check(LCopy.Instrumental.Mix.Parts[0].Gain =
      LRightDefinition.Instrumental.Mix.Parts[0].Gain,
      'Instrumental blend loses the independently selected part effects');
    Check(LCopy.Instrumental.Instruments[0].Id = Definition.Instrumental.Instruments[0].Id,
      'Instrumental blend changes the independently selected bass instrument');
    Check(LCopy.Instrumental.Instruments[1].Id = LRightDefinition.Instrumental.Instruments[1].Id,
      'Instrumental blend loses the independently selected harmony instrument');
    Check((LCopy.VoiceRanges[1].MinimumPitch = 48) and
      (LCopy.VoiceRanges[1].MaximumPitch = 67), 'Explicit union lost a selected register');
    Check(Length(LCopy.Sources) = 2, 'Instrumental blend loses original sources');
    Check((LCopy.Providers[2].ModelText = LRightDefinition.Providers[2].ModelText) and
      (LCopy.Providers[6].ModelText = Definition.Providers[6].ModelText) and
      (LCopy.Providers[3].VocabularySha256 <> Definition.Providers[3].VocabularySha256),
      'Musical parent choice or actual weighted vocabulary union was not applied');
    LRejected := False;
    try
      LBad := TSemanticStyle.CreateBlend(LLeft, LRight, LRecipe, nil, nil, LCancel.Observe);
    except
      on EAbort do LRejected := True;
    end;
    Check(LRejected and (LBad = nil) and (LLeft.Identity = LBefore),
      'Canceled instrumental blend was published or changed its parent');
    LRecipe.Providers[2].ControlParent := 0;
    LRejected := False;
    try
      LBad := TSemanticStyle.CreateBlend(LLeft, LRight, LRecipe);
    except
      on EAudio do LRejected := True;
    end;
    Check(LRejected and (LBad = nil) and (LLeft.Identity = LBefore),
      'Absent selected control was silently dropped instead of rejecting');
    LRecipe.Providers[2].ControlParent := 1;
    LLoaded := DecodeSemanticStyle(LBlend.Encode);
    Check(LLoaded.Identity = LBlend.Identity, 'Instrumental blend archive identity changed');
    SameInstrumental(LBlend, LLoaded);
    FreeAndNil(LLoaded);
    LParent := LBlend.CopyParent(1);
    Check(LParent.Identity = LRight.Identity, 'Instrumental parent was not retained exactly');
    FreeAndNil(LParent);
    for I := 0 to 8 do
    begin
      LRecipe.Providers[I].LeftWeight := 1;
      LRecipe.Providers[I].RightWeight := 1;
      LRecipe.Providers[I].ControlParent := 0;
    end;
    LRecipe.Instrumental.LabelText := 'Reusable further blend';
    LFurther := TSemanticStyle.CreateBlend(LBlend, LLeft, LRecipe);
    Check(LFurther.NodeCount = 5, 'Further instrumental blend loses repeated ancestry');
    LLoaded := DecodeSemanticStyle(LFurther.Encode);
    SameInstrumental(LFurther, LLoaded);
    FreeAndNil(LLoaded);
    LRightDefinition.Providers[4].Contract.Name := 'another-lead';
    LRightDefinition.Providers[4].Contract.RoleId := 'another-lead';
    LRightDefinition.Providers[1].Contract.RoleOrder[2] := 'another-lead';
    LRightDefinition.Providers[5].Contract.RoleOrder[2] := 'another-lead';
    LRightDefinition.Providers[5].Contract.RoleId := 'another-lead';
    LParent := TSemanticStyle.CreateSource(LRightDefinition);
    LRejected := False;
    try
      LBad := TSemanticStyle.CreateBlend(LLeft, LParent, LRecipe);
    except
      on EAudio do LRejected := True;
    end;
    Check(LRejected and (LBad = nil), 'A different role schema was silently coerced into a blend');
    WriteLn('Instrumental blend/reblend ', LBlend.Identity, ' ', LFurther.Identity);
  finally
    LBad.Free;
    LCancel.Free;
    LParent.Free;
    LLoaded.Free;
    LFurther.Free;
    LBlend.Free;
    LRight.Free;
    LLeft.Free;
  end;
end;

begin
  Replay(Definition);
  Replay(CorpusDefinition);
  Failures;
  Blends;
  Seeds;
  WriteLn('Complete instrumental style checks passed: ', GChecks);
end.
