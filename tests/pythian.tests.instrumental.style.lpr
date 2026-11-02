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
{$if defined(PYTHIAN_CAPACITY_ONLY) and defined(PYTHIAN_PERFORMANCE_ONLY)}
  {$fatal Select only one focused instrumental fixture mode}
{$endif}

uses SysUtils, Math, pythian.audio, pythian.time, pythian.hash, pythian.text,
  pythian.stream.bytes, pythian.binary,
  pythian.instrument.catalog, pythian.instrument.recipe, pythian.sound.recipe.codec,
  pythian.mix.recipe, pythian.effects.catalog, pythian.effects.rack,
  pythian.percussion, pythian.bus, pythian.progress,
  pythian.music.controls, pythian.music.decisions, pythian.music.blend,
  pythian.chord, pythian.music.proposal,
  pythian.wfc.semantic.corpus, pythian.wfc.musical.corpus,
  pythian.wfc.music,
  pythian.wfc.semantic.style, pythian.wfc.instrumental.stream, pythian.wfc.instrumental.blend,
  pythian.wfc.instrumental.policy, pythian.wfc.instrumental.edit, pythian.wfc.semantic.archive,
  pythian.wfc.instrumental.edit.stream,
  pythian.wfc.layers, pythian.wfc.voices, pythian.wfc.providers, pythian.wfc.provider.contracts,
  pythian.wfc.learning, pythian.wfc.percussion,
  wfc_model, wfc_sequence, wfc_sequence_text, wfc_sequence_learn, wfc_music_ensemble,
  wfc_music_sequence, wfc_music_ensemble_graph, wfc_music_voices_graph;

const CRate = 24000;
  CNames: array[0..8] of String =
    ('harmony', 'rhythm', 'bass', 'chords', 'lead', 'context', 'kick', 'snare', 'hat');
var GChecks: Integer;

type
  TCancel = class
    AtStage: String;
    procedure Observe(const AWork: TWorkProgress);
  end;
  TDecisionReceipt = class
    Cells: Int64;
    Frames: Int64;
    Calls: Integer;
    Cancel: Boolean;
    Writer: TMusicDecisionWriter;
    procedure Append(const AChunk: TMusicDecisionChunk);
  end;

procedure TCancel.Observe(const AWork: TWorkProgress);
begin
  if (AWork.Stage = 'semantic_instrumental_ready') or
    ((AtStage <> '') and (AWork.Stage = AtStage)) then
    raise EAbort.Create('Requested construction cancellation');
end;

procedure Check(const ACondition: Boolean; const AMessage: String);
begin
  Inc(GChecks);
  if not ACondition then raise Exception.Create(AMessage);
end;

procedure TDecisionReceipt.Append(const AChunk: TMusicDecisionChunk);
var I: Integer;
begin
  if Cancel then raise EAbort.Create('Requested decision cancellation');
  if Writer <> nil then Writer.Append(AChunk);
  Check((AChunk.FirstCell = Cells) and (AChunk.StartFrame = Frames),
    'Style decision sink receives a discontinuous score');
  Check(Length(AChunk.Providers) = 9, 'Style decision sink omits an actual provider');
  Inc(Calls);
  Inc(Cells, Length(AChunk.Cells));
  for I := 0 to High(AChunk.Cells) do Inc(Frames, AChunk.Cells[I].FrameCount);
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

procedure SameStreams(const LA, LB: TSemanticInstrumentalStream);
var
  LMasterA: TAudioSamples;
  LMasterB: TAudioSamples;
  LStemsA: TBusSampleBlocks;
  LStemsB: TBusSampleBlocks;
  I: Integer;
  P: Integer;
begin
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
  Check(not LB.Stream.ReadOutputs(511, [6, 7, 8, 9, 10, 11], LMasterB, LStemsB),
    'Instrumental replay has additional audio after its reference ended');
  Check(LA.Stream.PercussionHits > 0, 'Instrumental blend has no actual drums');
end;

procedure SameInstrumental(const ALeft, ARight: TSemanticStyle);
var LA, LB: TSemanticInstrumentalStream;
begin
  LA := ALeft.CreateInstrumentalStream;
  LB := nil;
  try
    LB := ARight.CreateInstrumentalStream;
    SameStreams(LA, LB);
  finally
    LB.Free;
    LA.Free;
  end;
end;

procedure Performance;
var
  LDefinition: TSemanticStyleDefinition;
  LStyle, LExpected, LFormStyle: TSemanticStyle;
  LA, LB: TSemanticInstrumentalStream;
  LGraph, LWrongRate: TBusGraph;
  LOptions, LInvalid: TInstrumentalStreamOptions;
  LReceipt: TDecisionReceipt;
  LCancel: TCancel;
  LIdentity: String;
  LMaster: TAudioSamples;
  LStems: TBusSampleBlocks;
  LRejected: Boolean;
begin
  LStyle := nil;
  LExpected := nil;
  LFormStyle := nil;
  LA := nil;
  LB := nil;
  LGraph := nil;
  LWrongRate := nil;
  LReceipt := TDecisionReceipt.Create;
  LCancel := TCancel.Create;
  try
    LDefinition := Definition;
    LDefinition.Instrumental.Form := nil;
    LStyle := TSemanticStyle.CreateSource(LDefinition);
    LIdentity := LStyle.Identity;
    LOptions := LDefinition.Instrumental.Options;
    LGraph := CreateStemMixGraph(LDefinition.Instrumental.Mix, CRate);
    LA := LStyle.CreateInstrumentalStream;
    LB := LStyle.CreateInstrumentalStream(LOptions, LReceipt.Append, LGraph);
    SameStreams(LA, LB);
    Check((LReceipt.Calls > 0) and (LReceipt.Frames = LOptions.MusicFrames) and
      (LReceipt.Cells = LB.Stream.TotalCells), 'Style sink does not retain the performed score clock');
    FreeAndNil(LA);
    FreeAndNil(LB);
    LGraph.Reset;
    LWrongRate := CreateStemMixGraph(LDefinition.Instrumental.Mix, CRate * 2);
    LRejected := False;
    try LB := LStyle.CreateInstrumentalStream(LOptions, nil, LWrongRate);
    except on EAudio do LRejected := True end;
    Check(LRejected and (LB = nil), 'Borrowed mixer changes the saved sample clock');
    LWrongRate.Reset;
    FreeAndNil(LWrongRate);
    LInvalid := LOptions;
    LInvalid.StepTicks := LOptions.StepTicks + 1;
    LRejected := False;
    try LB := LStyle.CreateInstrumentalStream(LInvalid, nil, LGraph);
    except on EAudio do LRejected := True end;
    Check(LRejected and (LB = nil), 'A performance override rewrites the learned provider clock');
    LGraph.Reset;
    LRejected := False;
    try LB := LStyle.CreateInstrumentalStream(LOptions, nil, LGraph, LCancel.Observe);
    except on EAbort do LRejected := True end;
    Check(LRejected and (LB = nil), 'Canceled borrowed-mixer construction publishes an owner');
    LGraph.Reset;
    LReceipt.Cancel := True;
    LB := LStyle.CreateInstrumentalStream(LOptions, LReceipt.Append, LGraph);
    LRejected := False;
    try LB.Stream.ReadOutputs(511, [6, 7, 8, 9, 10, 11], LMaster, LStems);
    except on EAbort do LRejected := True end;
    Check(LRejected and (LMaster = nil) and (LStems = nil),
      'Decision cancellation publishes partial audio or loses its exception');
    FreeAndNil(LB);
    LReceipt.Cancel := False;
    LReceipt.Cells := 0;
    LReceipt.Frames := 0;
    LReceipt.Calls := 0;
    LGraph.Reset;
    LOptions.MusicFrames := CRate * 6 div 5;
    LOptions.TempoMicroseconds := 400000;
    LOptions.Seed := $8000001F;
    LOptions.SegmentCells := 2;
    LFormStyle := TSemanticStyle.CreateSource(Definition);
    LRejected := False;
    try LB := LFormStyle.CreateInstrumentalStream(LOptions, nil, LGraph);
    except on EAudio do LRejected := True end;
    Check(LRejected and (LB = nil), 'Performance silently drops a saved form to change duration');
    FreeAndNil(LFormStyle);
    LGraph.Reset;
    LDefinition.Instrumental.Options := LOptions;
    LExpected := TSemanticStyle.CreateSource(LDefinition);
    LA := LExpected.CreateInstrumentalStream;
    LB := LStyle.CreateInstrumentalStream(LOptions, LReceipt.Append, LGraph);
    Check(LB.Stream.FrameCount = LOptions.MusicFrames + LOptions.TailFrames,
      'Style playback ignores the requested performance duration');
    Check((LStyle.Identity = LIdentity) and (Sha256Bytes(LStyle.Encode) = LIdentity),
      'Performance overrides mutate saved style bytes or identity');
    FreeAndNil(LExpected);
    FreeAndNil(LStyle);
    LDefinition := Default(TSemanticStyleDefinition);
    SameStreams(LA, LB);
    Check((LReceipt.Cells = 6) and (LReceipt.Frames = LOptions.MusicFrames),
      'Requested tempo/duration or detached decision sink ownership was lost');
    FreeAndNil(LA);
    FreeAndNil(LB);
    LGraph.Reset;
  finally
    LB.Free;
    LA.Free;
    LGraph.Free;
    LWrongRate.Free;
    LFormStyle.Free;
    LExpected.Free;
    LStyle.Free;
    LCancel.Free;
    LReceipt.Free;
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

procedure Variants;
var
  LSource, LVariant, LLoaded, LExpected, LFurther, LParent, LBlend, LBad: TSemanticStyle;
  LDefinition, LCopy: TSemanticStyleDefinition;
  LRecipe: TSemanticInstrumentalRecipe;
  LCatalog: TInstrumentRecipes;
  LBlendRecipe: TSemanticBlendRecipe;
  LCancel: TCancel;
  LRejected: Boolean;
  LIdentity: String;
  I: Integer;
begin
  LSource := nil; LVariant := nil; LLoaded := nil; LExpected := nil;
  LFurther := nil; LParent := nil;
  LBlend := nil; LBad := nil; LCancel := TCancel.Create;
  try
    LDefinition := Definition;
    LSource := TSemanticStyle.CreateSource(LDefinition);
    LIdentity := LSource.Identity;
    LRecipe := LSource.CopyDefinition.Instrumental;
    LRecipe.LabelText := 'Caller sound and expression variant';
    LRecipe.Origin := 'Explicit operator recipe; frozen authored musical evidence';
    LCatalog := BuiltInInstrumentRecipes;
    LRecipe.Instruments[0] := LCatalog[6];
    LRecipe.Mix.Parts[0].Gain := 0.36;
    LRecipe.Mix.Parts[0].Pan := 0.47;
    LRecipe.Expression[0].VelocityPercent := 70;
    LCancel.AtStage := 'semantic_validate_runs';
    LRejected := False;
    try LBad := TSemanticStyle.CreateInstrumentalVariant(LSource, LRecipe, nil, nil, LCancel.Observe);
    except on EAbort do LRejected := True end;
    Check(LRejected and (LBad = nil) and (LSource.Identity = LIdentity),
      'Cancelled variant changes or leaks its frozen parent');
    LVariant := TSemanticStyle.CreateInstrumentalVariant(LSource, LRecipe);
    LLoaded := DecodeSemanticStyle(LVariant.Encode);
    Check((LLoaded.Identity = LVariant.Identity) and (LLoaded.Depth = 2) and
      (LLoaded.NodeCount = 2) and (LSource.Identity = LIdentity),
      'Instrumental variant loses its exact archive, parent or ancestry accounting');
    LCopy := LLoaded.CopyDefinition;
    for I := 0 to High(LDefinition.Providers) do
      Check((LCopy.Providers[I].ModelText = LDefinition.Providers[I].ModelText) and
        (LCopy.Providers[I].VocabularySha256 = LDefinition.Providers[I].VocabularySha256) and
        (Length(LCopy.Providers[I].Preferences) = Length(LDefinition.Providers[I].Preferences)) and
        (Length(LCopy.Providers[I].Constraints) = Length(LDefinition.Providers[I].Constraints)),
        'A performed recipe changes frozen musical models, vocabulary or provider policy');
    Check((LCopy.Sources[0].PreparationSha256 = LDefinition.Sources[0].PreparationSha256) and
      (LCopy.Runs[0].Tokens[2][0] = LDefinition.Runs[0].Tokens[2][0]) and
      (LCopy.Runs[0].Weights[2] = LDefinition.Runs[0].Weights[2]),
      'Operator sound editing becomes invented source evidence');
    Check((LCopy.Providers[2].Preferences[0].Token = LDefinition.Providers[2].Preferences[0].Token) and
      (LCopy.Providers[2].Preferences[0].Multiplier = LDefinition.Providers[2].Preferences[0].Multiplier) and
      (LCopy.Providers[5].Constraints[0].AllowedTokens[0] = LDefinition.Providers[5].Constraints[0].AllowedTokens[0]),
      'A sound variant rewrites independent token preferences or hard locks');
    LParent := LLoaded.CopyParent(0);
    Check(LParent.Identity = LIdentity, 'Variant does not retain the exact original parent');
    FreeAndNil(LParent);
    LDefinition.Instrumental := LRecipe;
    LExpected := TSemanticStyle.CreateSource(LDefinition);
    FreeAndNil(LSource);
    SameInstrumental(LVariant, LExpected);
    SameInstrumental(LVariant, LLoaded);
    LRecipe := LLoaded.CopyDefinition.Instrumental;
    LRecipe.LabelText := 'Further sound variant';
    LRecipe.Instruments[2] := LCatalog[3];
    LFurther := TSemanticStyle.CreateInstrumentalVariant(LLoaded, LRecipe);
    LParent := LFurther.CopyParent(0);
    Check((LParent.Identity = LLoaded.Identity) and (LFurther.NodeCount = 3),
      'A further variant flattens its actual instrumental parent');
    FreeAndNil(LParent);
    FreeAndNil(LLoaded);
    LLoaded := DecodeSemanticStyle(LFurther.Encode);
    SameInstrumental(LFurther, LLoaded);
    Check(LFurther.Identity = LLoaded.Identity, 'Further variant is not canonical');
    LBlendRecipe := Default(TSemanticBlendRecipe);
    SetLength(LBlendRecipe.Providers, 9);
    for I := 0 to 8 do LBlendRecipe.Providers[I].LeftWeight := 1;
    LBlendRecipe.Instrumental.Enabled := True;
    LBlendRecipe.Instrumental.LabelText := 'Blend with a sound variant';
    SetLength(LBlendRecipe.Instrumental.Parts, 6);
    LBlendRecipe.Instrumental.Parts[2].InstrumentParent := 1;
    LBlend := TSemanticStyle.CreateBlend(LVariant, LFurther, LBlendRecipe);
    FreeAndNil(LLoaded);
    LLoaded := DecodeSemanticStyle(LBlend.Encode);
    Check((LBlend.NodeCount = 4) and
      (LLoaded.CopyDefinition.Instrumental.Instruments[2].Id = LRecipe.Instruments[2].Id),
      'Selective blend loses the chosen variant instrument or actual parent ancestry');
    SameInstrumental(LBlend, LLoaded);
    FreeAndNil(LFurther);
    LBlendRecipe.Instrumental.LabelText := 'Further blend of variant-backed music';
    LBlendRecipe.Instrumental.Parts[2].InstrumentParent := 0;
    LFurther := TSemanticStyle.CreateBlend(LBlend, LExpected, LBlendRecipe);
    FreeAndNil(LLoaded);
    LLoaded := DecodeSemanticStyle(LFurther.Encode);
    Check((LLoaded.Identity = LFurther.Identity) and (LFurther.NodeCount = 6),
      'A variant-backed blend cannot be reused as a further parent');
    SameInstrumental(LFurther, LLoaded);
    WriteLn('Instrumental variant ', LVariant.Identity, '; further ', LFurther.Identity);
  finally
    LCancel.Free; LBad.Free; LBlend.Free; LParent.Free; LFurther.Free; LExpected.Free; LLoaded.Free;
    LVariant.Free; LSource.Free;
  end;
end;

procedure ScopedControls;
const Pattern: array[0..7] of Integer = (0, 0, 1, 0, 1, 1, 0, 1);
var LDefinition, LCopy, LBadDefinition: TSemanticStyleDefinition;
  LSource, LScoped, LLoaded, LBad, LBlended, LReblended: TSemanticStyle;
  LBlendRecipe: TSemanticBlendRecipe;
  LParts: TMusicalPartControls; LOriginal: array[0..5, 0..1] of String;
  LPolicies, LDetached: TInstrumentalProviderPolicies;
  LRows: TLayerPositionPreferences; LMasks: TVoiceMasks;
  LOptions: TInstrumentalStreamOptions; LOwner: TSemanticInstrumentalStream;
  LMaster: TAudioSamples; LStems: TBusSampleBlocks;
  LObserver: TDecisionReceipt; LBytes: TAudioBytesStream;
  LWriter: TMusicDecisionWriter; LReader, LBeforeReader: TMusicDecisionReader;
  LBeforeBytes: TAudioBytesReadStream; LEditor: TInstrumentalPassageStream;
  LEdit: TInstrumentalPassageEdit; LReport: TInstrumentalPassageReport;
  LBefore, LAfter: TMusicDecisionChunk; LModels: TInstrumentalPolicyModels;
  LConfig: TWfcMusicVoicesGraphConfig; LDrums: TPercussionDefinitions;
  LCancel: TCancel; LRejected: Boolean; LIdentity: String;
  P, C, I, LCase, LFrames: Integer;
begin
  LSource := nil; LScoped := nil; LLoaded := nil; LBad := nil; LOwner := nil;
  LBlended := nil; LReblended := nil;
  LBytes := nil; LWriter := nil; LReader := nil; LBeforeReader := nil;
  LBeforeBytes := nil; LEditor := nil; LCancel := TCancel.Create;
  LObserver := TDecisionReceipt.Create;
  try
    LDefinition := Definition;
    LDefinition.Instrumental.Form := nil;
    for P := 0 to 5 do for C := 0 to 1 do LOriginal[P, C] := LDefinition.Runs[0].Tokens[P][C];
    for P := 0 to 5 do for C := 0 to 7 do
      LDefinition.Runs[0].Tokens[P][C] := LOriginal[P, Pattern[C]];
    Relearn(LDefinition);
    LDefinition.Providers[6].Constraints := [MakeWfcSequenceTokenConstraint(4, [PercussionToken(100)])];
    LSource := TSemanticStyle.CreateSource(LDefinition); LIdentity := LSource.Identity;
    SetLength(LParts, 3);
    for P := 0 to 2 do LParts[P] := DefaultMusicalPartControl;
    LParts[2].MaximumPitch := 60;
    LScoped := LSource.DeriveMusicalControls(720, 1200, 0, 1, LParts,
      'Explicit lead register over cells three and four');
    LLoaded := DecodeSemanticStyle(LScoped.Encode);
    Check((LLoaded.Identity = LScoped.Identity) and (LLoaded.NodeCount = 2) and
      (LSource.Identity = LIdentity), 'Scoped derivation loses its parent or exact archive');
    LCopy := LLoaded.CopyDefinition;
    for P := 0 to 8 do Check((LCopy.Providers[P].ModelText = LDefinition.Providers[P].ModelText) and
      (LCopy.Providers[P].VocabularySha256 = LDefinition.Providers[P].VocabularySha256),
      'Scoped controls change learned models or vocabulary');
    Check((LCopy.Runs[0].Tokens[4][4] = LDefinition.Runs[0].Tokens[4][4]) and
      (LCopy.Providers[4].Scopes[0].StartTick = 720) and
      (LCopy.Providers[4].Scopes[0].EndTick = 1200), 'Scoped request becomes new observed notes or a global bound');
    LPolicies := SemanticStylePolicies(LCopy);
    LDetached := CopyInstrumentalPolicies(LPolicies);
    LDetached[4].Scopes[0].AllowedTokens[0] := 'caller mutation';
    Check(LPolicies[4].Scopes[0].AllowedTokens[0] <> 'caller mutation', 'Scoped policy copy aliases its source');
    LMasks := InstrumentalPolicyMasks(LPolicies, ['lead', 'bass'], 2, 4);
    Check((Length(LMasks[0]) = 2) and (LMasks[0][0].Position = 1) and
      (LMasks[0][1].Position = 2) and (Length(LMasks[1]) = 0),
      'Actual planning window globalizes scope or swaps provider order');
    LRows := InstrumentalPolicyRows(LPolicies, 'bass', 2, 4);
    Check((Length(LRows) = 4) and (LRows[0].Preferences[0].Multiplier = 3),
      'A scoped recipe loses unrelated saved global preferences');
    LRows := InstrumentalPolicyRows(LPolicies, 'harmony', 2, 4);
    Check((Length(LRows) = 2) and (LRows[0].Position = 1) and (LRows[1].Position = 2) and
      (LRows[0].Preferences[0].Multiplier > 1), 'Soft chord preference leaks outside its saved passage');
    SameInstrumental(LScoped, LLoaded);
    LBlendRecipe := Default(TSemanticBlendRecipe);
    SetLength(LBlendRecipe.Providers, 9);
    for P := 0 to 8 do LBlendRecipe.Providers[P].LeftWeight := 1;
    LBlendRecipe.Instrumental.Enabled := True;
    LBlendRecipe.Instrumental.LabelText := 'Explicit scoped control parent';
    SetLength(LBlendRecipe.Instrumental.Parts, 6);
    LBlended := TSemanticStyle.CreateBlend(LScoped, LSource, LBlendRecipe);
    Check((Length(LBlended.CopyDefinition.Providers[4].Scopes) = 1) and
      (LBlended.CopyDefinition.Providers[4].Scopes[0].StartTick = 720),
      'Selective control parent loses its scoped policy in a blend');
    SameInstrumental(LBlended, LScoped);
    LReblended := TSemanticStyle.CreateBlend(LBlended, LSource, LBlendRecipe);
    FreeAndNil(LLoaded); LLoaded := DecodeSemanticStyle(LReblended.Encode);
    Check((LLoaded.NodeCount = 4) and (LLoaded.Identity = LReblended.Identity),
      'A further blend loses scoped controls or actual ancestry');
    SameInstrumental(LReblended, LLoaded);
    FreeAndNil(LLoaded); LLoaded := DecodeSemanticStyle(LScoped.Encode);
    for LCase := 0 to 6 do
    begin
      LBadDefinition := LScoped.CopyDefinition;
      case LCase of
        0: LBadDefinition.Providers[4].Scopes[0].StepTicks := 120;
        1: LBadDefinition.Providers[4].Scopes[0].AllowedTokens[0] := 'unknown note';
        2: LBadDefinition.Providers[4].Scopes[0].EndTick := 2400;
        3: LBadDefinition.Providers[4].Scopes[0].StartTick := 721;
        4: LBadDefinition.Providers[4].Scopes[0].AllowedTokens := nil;
        5: LBadDefinition.Providers[4].Constraints := [MakeWfcSequenceTokenConstraint(3,
          [LDefinition.Runs[0].Tokens[4][2]])];
        6: begin
          SetLength(LBadDefinition.Providers[4].Scopes, 2);
          LBadDefinition.Providers[4].Scopes[0].Preferences :=
            [MakeLayerTokenPreference(LDefinition.Runs[0].Tokens[4][0], 1024)];
          LBadDefinition.Providers[4].Scopes[1] := LBadDefinition.Providers[4].Scopes[0];
        end;
      end;
      LRejected := False;
      try LBad := TSemanticStyle.CreateDerived(LScoped, LBadDefinition);
      except
        on EAudio do LRejected := True;
        on EArgumentException do LRejected := LCase = 1;
      end;
      Check(LRejected and (LBad = nil) and (LSource.Identity = LIdentity), 'Invalid/conflicting scoped policy admitted');
    end;
    LCancel.AtStage := 'instrumental_policy_validate'; LRejected := False;
    try LBad := TSemanticStyle.CreateDerived(LScoped, LScoped.CopyDefinition, nil, nil, LCancel.Observe);
    except on EAbort do LRejected := True end;
    Check(LRejected and (LBad = nil) and (LSource.Identity = LIdentity), 'Scoped cancellation publishes partial state');
    LOptions := LCopy.Instrumental.Options; LOptions.MusicFrames := CRate;
    LRejected := False;
    try LOwner := LLoaded.CreateInstrumentalStream(LOptions);
    except on EAudio do LRejected := True end;
    Check(LRejected and (LOwner = nil), 'Shortened music silently truncates its scoped controls');
    LOptions.MusicFrames := CRate * 3;
    LBytes := TAudioBytesStream.Create(MaximumMusicDecisionBytes * 2);
    LWriter := TMusicDecisionWriter.Create(LBytes); LObserver.Writer := LWriter;
    LOwner := LLoaded.CreateInstrumentalStream(LOptions, LObserver.Append);
    LFrames := 0;
    while LOwner.Stream.ReadOutputs(511, [], LMaster, LStems) do Inc(LFrames, Length(LMaster) div 2);
    Check((LFrames = CRate * 4) and (LObserver.Cells = 12), 'Extended scope performance does not complete on its actual clock');
    Check(LWriter.Seal <> '', 'Actual scoped performance has no sealed score');
    FreeAndNil(LOwner); LObserver.Writer := nil;
    SetLength(LModels, 9);
    for P := 0 to 8 do LModels[P] := DecodeWfcSequenceText(LCopy.Providers[P].ModelText);
    LConfig := SemanticStyleVoiceLayout(LCopy);
    LConfig.HarmonyModel := LModels[0]; LConfig.RhythmModel := LModels[1];
    for P := 0 to 2 do LConfig.Voices[P].Model := LModels[P + 2];
    LDrums := CopyPercussionDefinitions(LCopy.Instrumental.Percussion);
    for P := 0 to 2 do LDrums[P].Model := LModels[P + 6];
    LBytes.Position := 0; LReader := TMusicDecisionReader.Create(LBytes);
    LBeforeBytes := TAudioBytesReadStream.Create(LBytes.Snapshot);
    LBeforeReader := TMusicDecisionReader.Create(LBeforeBytes);
    LEdit := Default(TInstrumentalPassageEdit);
    LEdit.StartFrame := CRate div 2; LEdit.EndFrame := CRate * 7 div 4;
    LEdit.Parts := [False, False, True, False, False, False];
    LEdit.Controls := LParts; LEdit.Controls[2] := DefaultMusicalPartControl;
    LEdit.Seed := 624; LEdit.MaxBacktracks := 256; LEdit.MaxPassBacktracks := 16;
    LEditor := TInstrumentalPassageStream.Create(LConfig, ['bass', 'chords', 'lead'], LDrums,
      LModels[5], LReader, 12, LEdit, 32, LPolicies, 480, 240);
    while LEditor.TryNext(LAfter, LReport) do
    begin
      Check(LBeforeReader.TryNext(LBefore), 'Edited scope has no original score chunk');
      for C := 0 to High(LAfter.Cells) do
      begin
        I := LAfter.FirstCell + C;
        if (I >= 3) and (I < 5) then
          Check(LAfter.Cells[C].Parts[2].Tones[0].Pitch <= 60, 'Retained edit dropped the saved scoped pitch domain');
        for P := 0 to High(LBefore.Providers) do
          if (I < 2) or (I >= 7) or (LBefore.Providers[P].Key <> 'lead') then
            Check((LBefore.Providers[P].Tokens[C] = LAfter.Providers[P].Tokens[C]) and
              (LBefore.Providers[P].States[C] = LAfter.Providers[P].States[C]),
              'Saved policy edit changes an unrequested provider or outside-range state');
      end;
    end;
    Check(LEditor.State = ipesCompleted, 'Scoped policy does not survive actual retained lookahead/seams');
    FreeAndNil(LEditor); FreeAndNil(LReader); FreeAndNil(LBeforeReader);
    LBytes.Position := 0; LBeforeBytes.Position := 0;
    LReader := TMusicDecisionReader.Create(LBytes);
    LBeforeReader := TMusicDecisionReader.Create(LBeforeBytes);
    LEdit.Parts := [True, True, True, True, True, True]; LEdit.Harmony := True; LEdit.Rhythm := True;
    LEditor := TInstrumentalPassageStream.Create(LConfig, ['bass', 'chords', 'lead'], LDrums,
      LModels[5], LReader, 12, LEdit, 32, LPolicies, 480, 240);
    while LEditor.TryNext(LAfter, LReport) do
    begin
      Check(LBeforeReader.TryNext(LBefore), 'All-part policy edit has no original score');
      for C := 0 to High(LAfter.Cells) do
      begin
        I := LAfter.FirstCell + C;
        if (I >= 3) and (I < 5) then
          Check(LAfter.Cells[C].Parts[2].Tones[0].Pitch <= 60, 'All-part edit relaxed a saved scoped bound');
        for P := 0 to High(LAfter.Providers) do
        begin
          if (I = 4) and (LAfter.Providers[P].Key = 'kick') then
            Check(LAfter.Providers[P].Tokens[C] = PercussionToken(100), 'Selected drum loses its saved hard lock');
          if (I < 2) or (I >= 7) then Check((LAfter.Providers[P].Tokens[C] = LBefore.Providers[P].Tokens[C]) and
            (LAfter.Providers[P].States[C] = LBefore.Providers[P].States[C]), 'All-part edit changes an outside-scope state');
        end;
      end;
    end;
    Check(LEditor.State = ipesCompleted, 'Complete saved policy does not survive an all-part edit');
    WriteLn('Scoped instrumental policy ', LScoped.Identity, '; native/JS scope, replay and edit consumer pass');
  finally
    LEditor.Free; LBeforeReader.Free; LReader.Free; LBeforeBytes.Free;
    for P := 0 to High(LModels) do LModels[P].Free;
    LWriter.Free; LBytes.Free; LOwner.Free; LObserver.Free; LCancel.Free;
    LReblended.Free; LBlended.Free;
    LBad.Free; LLoaded.Free; LScoped.Free; LSource.Free;
  end;
end;

procedure BlendSoundTails;
var
  LPlan: TMusicBlendPlan;
  LRejected: Boolean;
begin
  LPlan := DefaultMusicBlendPlan(9, 6);
  LPlan.Parts[0].ExpressionParent := 1;
  LPlan.FormParent := 1;
  Check(MusicBlendSoundTailFrames(0, 0, LPlan.Parts, 1, 48000) = 1,
    'Music/expression/form contributions select an unused sound tail');
  Check(MusicBlendSoundTailFrames(0, 0, LPlan.Parts, 0, 48000) = 0,
    'Zero sound tail silently becomes a default second');
  LPlan.Parts[0].InstrumentParent := 1;
  Check(MusicBlendSoundTailFrames(0, 0, LPlan.Parts, 24000, 48000) = 48000,
    'Part instrument tail is shortened by its master choice');
  LPlan.Parts[0].InstrumentParent := 0;
  LPlan.Parts[2].EffectsParent := 1;
  Check(MusicBlendSoundTailFrames(0, 0, LPlan.Parts, 24000, 48000) = 48000,
    'Part effect tail is not retained');
  LPlan.Parts[2].EffectsParent := 0;
  Check(MusicBlendSoundTailFrames(1, 0, LPlan.Parts, 24000, 48000) = 48000,
    'Base performance tail is not retained');
  Check(MusicBlendSoundTailFrames(0, 1, LPlan.Parts, 24000, 48000) = 48000,
    'Master effect tail is not retained');
  LRejected := False;
  try MusicBlendSoundTailFrames(0, 0, LPlan.Parts, -1, 48000);
  except on EAudio do LRejected := True end;
  Check(LRejected, 'Negative declared sound tail admitted');
  LPlan.Parts[0].EffectsParent := 2;
  LRejected := False;
  try MusicBlendSoundTailFrames(0, 0, LPlan.Parts, 24000, 48000);
  except on EAudio do LRejected := True end;
  Check(LRejected, 'Invalid tail parent admitted');
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
  LPlan: TMusicBlendPlan;
  LPlanCopy: TMusicBlendPlan;
  LCopy: TSemanticStyleDefinition;
  LRightDefinition: TSemanticStyleDefinition;
  LBefore: String;
  LRejected: Boolean;
  LBad: TSemanticStyle;
  LCancel: TCancel;
  I: Integer;
begin
  BlendSoundTails;
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
    LPlan := DefaultMusicBlendPlan(9, 6);
    for I := 0 to 8 do
    begin
      LPlan.Providers[I] := LRecipe.Providers[I];
    end;
    for I := 0 to 5 do
    begin
      LPlan.Parts[I] := LRecipe.Instrumental.Parts[I];
    end;
    LPlan.UnionPitchRanges := True;
    LPlan.Context := mbcDrivenRole;
    LLoaded := BlendInstrumentalStyles(LLeft, LRight, LPlan, LRecipe.Instrumental.LabelText);
    Check(LLoaded.Identity = LBlend.Identity,
      'Shared instrumental choice contract differs from the existing explicit primary recipe');
    SameInstrumental(LBlend, LLoaded);
    FreeAndNil(LLoaded);
    LPlanCopy := CopyMusicBlendPlan(LPlan);
    LPlanCopy.Providers[0].LeftWeight := -1;
    LRejected := False;
    try
      LBad := BlendInstrumentalStyles(LLeft, LRight, LPlanCopy, 'Invalid negative weight');
    except
      on EAudio do LRejected := True;
    end;
    Check(LRejected and (LBad = nil) and (LPlan.Providers[0].LeftWeight = 1),
      'Invalid detached blend choices were admitted or changed the original plan');
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
      LBad := BlendInstrumentalStyles(LLeft, LRight, LPlan,
        LRecipe.Instrumental.LabelText, LCancel.Observe);
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
    for I := 0 to 8 do
    begin
      LPlan.Providers[I] := LRecipe.Providers[I];
    end;
    LLoaded := BlendInstrumentalStyles(LBlend, LLeft, LPlan, LRecipe.Instrumental.LabelText);
    Check(LLoaded.Identity = LFurther.Identity, 'Shared choice contract changes a further blend');
    FreeAndNil(LLoaded);
    Check(LFurther.NodeCount = 4, 'Further instrumental blend loses a unique ancestor');
    LLoaded := DecodeSemanticStyle(LFurther.Encode);
    SameInstrumental(LFurther, LLoaded);
    FreeAndNil(LLoaded);
    LRightDefinition.Instrumental.Options.TailFrames := CRate * 2;
    LRightDefinition.Instrumental.Mix.TailSeconds := 2;
    LParent := TSemanticStyle.CreateSource(LRightDefinition);
    LPlanCopy := DefaultMusicBlendPlan(9, 6);
    for I := 0 to High(LPlanCopy.Providers) do LPlanCopy.Providers[I].RightWeight := 0;
    LLoaded := BlendInstrumentalStyles(LLeft, LParent, LPlanCopy, 'Only A sounds');
    Check(LLoaded.CopyDefinition.Instrumental.Options.TailFrames = CRate,
      'Primary factory imports the unused B tail');
    FreeAndNil(LLoaded);
    LPlanCopy.Parts[0].InstrumentParent := 1;
    LLoaded := BlendInstrumentalStyles(LLeft, LParent, LPlanCopy, 'Bass B with master A');
    Check((LLoaded.CopyDefinition.Instrumental.Options.TailFrames = CRate * 2) and
      (LLoaded.CopyDefinition.Instrumental.Mix.TailSeconds = 1),
      'Primary factory and shared tail selection disagree');
    FreeAndNil(LParent);
    LParent := DecodeSemanticStyle(LLoaded.Encode);
    SameInstrumental(LLoaded, LParent);
    FreeAndNil(LLoaded);
    FreeAndNil(LParent);
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

function CorruptSharedParent(const ABytes: TAudioBytes; const AParent: Integer): TAudioBytes;
var LIO: TStyleIO; I, J, N, C, LOffset: Integer;
begin
  LIO := TStyleIO.Create(ABytes, True);
  try
    Check(LIO.Text = 'pythian.semantic.style.v7', 'Ancestry fixture is not the shared format');
    N := LIO.Count(0, MaximumSemanticArchiveSections);
    for I := 0 to N - 1 do LIO.Blob(nil);
    N := LIO.Count(0, MaximumSemanticArchiveNodes); LOffset := -1;
    for I := 0 to N - 1 do
    begin
      LIO.Text; LIO.N; LIO.N;
      if I = N - 1 then LOffset := LIO.Position;
      LIO.N; LIO.N; LIO.N;
      C := LIO.Count(0, MaximumSemanticArchiveSections);
      for J := 0 to C - 1 do LIO.N;
    end;
    Check(LOffset >= 0, 'Missing shared root parent offset');
    Result := Copy(ABytes); WriteInt32LE(Result, LOffset, AParent);
    WriteSha256Hex(Result, Length(Result) - 64,
      Sha256Bytes(Copy(Result, 0, Length(Result) - 68)));
  finally LIO.Free end;
end;


procedure ArchiveStorage;
var LArchive, LNext: TSemanticArchive; LNode: TSemanticArchiveNode;
  LWork: TSemanticArchiveWork; LBytes, LBaseline: TAudioBytes;
  LIdentity: String; I: Integer; LRejected: Boolean;
begin
  LArchive := nil; LNext := nil; LWork := TSemanticArchiveWork.Create;
  try
    LNode := Default(TSemanticArchiveNode); LNode.Format := 7; LNode.Kind := 0;
    SetLength(LBytes, 4096);
    for I := 0 to High(LBytes) do LBytes[I] := I mod 251;
    SetLength(LNode.Definition, 1); LNode.Definition[0] := LBytes;
    LArchive := TSemanticArchive.Create(nil, nil, LNode, LWork, nil);
    LBaseline := LArchive.Encode(0, LWork);
    LIdentity := Sha256Bytes(LBaseline); LArchive.SealRoot(LIdentity);
    LBytes[0] := 255;
    Check(Sha256Bytes(LArchive.Encode(0, LWork)) = LIdentity,
      'Caller byte mutation reaches immutable archive payloads');
    LNode.Definition[0] := Copy(LNode.Definition[0]);
    LNode.Definition[0][0] := 0;
    LNode.Kind := 1;
    for I := 2 to MaximumSemanticArchiveNodes do
    begin
      LNode.Parent := LIdentity;
      LNext := TSemanticArchive.Create(LArchive, nil, LNode, LWork, nil);
      FreeAndNil(LArchive); LArchive := LNext; LNext := nil;
      Check(LArchive.PayloadBytes = 4096, 'Shared ancestor evidence is retained more than once');
      LBaseline := LArchive.Encode(LArchive.Count - 1, LWork);
      LIdentity := Sha256Bytes(LBaseline); LArchive.SealRoot(LIdentity);
    end;
    Check(LArchive.Count = MaximumSemanticArchiveNodes, 'Declared node capacity is unreachable');
    LNode.Parent := LIdentity; LRejected := False;
    try LNext := TSemanticArchive.Create(LArchive, nil, LNode, LWork, nil)
    except on EAudio do LRejected := True end;
    Check(LRejected and (LNext = nil) and
      (Sha256Bytes(LArchive.Encode(LArchive.Count - 1, LWork)) = LIdentity),
      'Excess ancestry publishes a candidate or changes the existing archive');
  finally LNext.Free; LArchive.Free; LWork.Free end;
end;

procedure Ancestry(const ABase: TSemanticStyleDefinition; const ALabel: String);
var LVersions: array[0..5] of TSemanticStyle; LBlend, LFurther, LLoaded, LParent, LBad: TSemanticStyle;
  LDefinition, LCopy: TSemanticStyleDefinition; LRecipe: TSemanticInstrumentalRecipe;
  LBlendRecipe: TSemanticBlendRecipe; LParts: TMusicalPartControls; LCatalog: TInstrumentRecipes;
  LA, LB: TSemanticInstrumentalStream; LBytes, LInvalid: TAudioBytes;
  LCancel: TCancel; I, P, LCase: Integer; LRejected: Boolean; LIdentity: String;
  LWork: TSemanticArchiveWork; LLearning: Int64;
begin
  for I := 0 to High(LVersions) do LVersions[I] := nil;
  LBlend := nil; LFurther := nil; LLoaded := nil; LParent := nil; LBad := nil;
  LA := nil; LB := nil; LCancel := TCancel.Create;
  LWork := TSemanticArchiveWork.Create;
  try
    LDefinition := ABase;
    LVersions[0] := TSemanticStyle.CreateSource(LDefinition, nil, nil, nil, LWork);
    LLearning := LWork.Budget.Used;
    LCatalog := BuiltInInstrumentRecipes;
    LRecipe := LVersions[0].CopyDefinition.Instrumental;
    LRecipe.Form := nil; LRecipe.Instruments[0] := LCatalog[5];
    LVersions[1] := TSemanticStyle.CreateInstrumentalVariant(LVersions[0], LRecipe, nil, nil, nil, LWork);
    Check(LWork.Budget.Used = LLearning, 'Recipe-only edit relearns frozen source models');
    LRecipe.Options.MusicFrames := CRate * 3;
    LVersions[2] := TSemanticStyle.CreateInstrumentalVariant(LVersions[1], LRecipe);
    SetLength(LParts, 3); for I := 0 to 2 do LParts[I] := DefaultMusicalPartControl;
    LVersions[3] := LVersions[2].DeriveMusicalControls(240, 720, 0, 1, LParts,
      'Authored first passage root preference');
    LRecipe.Options.MusicFrames := CRate * 4;
    LVersions[4] := TSemanticStyle.CreateInstrumentalVariant(LVersions[3], LRecipe);
    LVersions[5] := LVersions[4].DeriveMusicalControls(960, 1440, 7, 2, LParts,
      'Authored second passage root preference');
    Check(LVersions[5].NodeCount = 6, 'Edited input does not retain its six actual nodes');
    LBlendRecipe := Default(TSemanticBlendRecipe); SetLength(LBlendRecipe.Providers, 9);
    for P := 0 to 8 do LBlendRecipe.Providers[P].LeftWeight := 1;
    LBlendRecipe.Instrumental.Enabled := True; LBlendRecipe.Instrumental.LabelText := 'Edited shared ancestry';
    SetLength(LBlendRecipe.Instrumental.Parts, 6);
    LBlend := TSemanticStyle.CreateBlend(LVersions[5], LVersions[0], LBlendRecipe, nil, nil, nil, LWork);
    Check(LWork.Budget.Used = LLearning, 'Unchanged effective blend contributions are relearned');
    WriteLn('Unique retained ancestry payload bytes: ', LBlend.ArchivePayloadBytes);
    Check(LBlend.NodeCount = 7, 'First blend counts a shared source twice');
    LLoaded := DecodeSemanticStyle(LBlend.Encode);
    LFurther := TSemanticStyle.CreateBlend(LLoaded, LVersions[0], LBlendRecipe);
    FreeAndNil(LLoaded); LLoaded := DecodeSemanticStyle(LFurther.Encode);
    Check((LLoaded.NodeCount = 8) and (LLoaded.Identity = LFurther.Identity),
      'Actual edited style cannot be reused through a further blend');
    LParent := LLoaded.CopyParent(0);
    Check(LParent.Identity = LBlend.Identity, 'Shared graph drops its exact intermediate parent');
    FreeAndNil(LParent);
    LCopy := LLoaded.CopyDefinition;
    Check((LCopy.Providers[0].Scopes[0].StartTick = 240) and
      (LCopy.Providers[0].Scopes[1].StartTick = 960) and
      (LCopy.Providers[5].Scopes[1].EndTick = 1440), 'Further blend rewrites passage positions');
    for P := 0 to 8 do Check(LCopy.Providers[P].ModelText = LDefinition.Providers[P].ModelText,
      'Shared ancestry changes a frozen model');
    Check(LCopy.Instrumental.Instruments[0].Id = LCatalog[5].Id, 'Shared ancestry loses its actual edited sound');
    LBytes := LLoaded.Encode; LIdentity := LLoaded.Identity;
    Check(Sha256Bytes(LBytes) = LIdentity, 'Shared identity is not its actual archive digest');
    for LCase := 0 to 2 do
    begin
      case LCase of
        0: LInvalid := CorruptSharedParent(LBytes, -2);
        1: LInvalid := CorruptSharedParent(LBytes, 7);
        2: LInvalid := CorruptSharedParent(LBytes, 99);
      end;
      LRejected := False;
      try LBad := DecodeSemanticStyle(LInvalid) except on EAudio do LRejected := True end;
      Check(LRejected and (LBad = nil), 'Rehashed dangling/cyclic ancestry publishes a style');
    end;
    LCancel.AtStage := 'semantic_archive_nodes'; LRejected := False;
    try LBad := DecodeSemanticStyle(LBytes, nil, nil, LCancel.Observe)
    except on EAbort do LRejected := True end;
    Check(LRejected and (LBad = nil) and (LLoaded.Identity = LIdentity),
      'Canceled shared reload changes its source or publishes partial ownership');
    LA := LLoaded.CreateInstrumentalStream; LB := LVersions[5].CreateInstrumentalStream;
    FreeAndNil(LLoaded); FreeAndNil(LFurther); FreeAndNil(LBlend);
    for I := 0 to High(LVersions) do FreeAndNil(LVersions[I]);
    SameStreams(LA, LB);
    WriteLn('Edited ancestry ', ALabel, ' native/JS mix and six stems: ', LIdentity, ' bytes=', Length(LBytes));
  finally
    LA.Free; LB.Free; LWork.Free; LCancel.Free; LBad.Free; LParent.Free; LLoaded.Free; LFurther.Free; LBlend.Free;
    for I := 0 to High(LVersions) do LVersions[I].Free;
  end;
end;

procedure MetadataOrigin;
var
  LDefinition: TSemanticStyleDefinition;
  LStart: Int64;
  LEnd: Int64;
begin
  LDefinition := Definition;
  LDefinition.Sources[0].OriginSha256 := '';
  LDefinition.Sources[0].OriginMetadataIdentity := StringOfChar('c', 64);
  LDefinition.Sources[0].OriginFrameCount := 4000000000;
  LDefinition.Sources[0].OriginStartFrame := 3000000000;
  LDefinition.Sources[0].OriginEndFrame := Int64(3000000000) + LDefinition.Sources[0].FrameCount;
  LDefinition.Sources[0].PreparationSha256 := SemanticPreparationIdentity(LDefinition.Sources[0]);
  SemanticRunOriginRange(LDefinition.Sources[0], LDefinition.Runs[0], LStart, LEnd);
  Check((LStart = Int64(3000000000) + LDefinition.Runs[0].StartFrame) and
    (LEnd = Int64(3000000000) + LDefinition.Runs[0].EndFrame),
    'Metadata-only parent loses original time or invents a content hash');
  Replay(LDefinition);
end;

type
  TCapacityObserver = class
  public
    CancelStage: String;
    Calls: Integer;
    procedure Observe(const AWork: TWorkProgress);
  end;

procedure TCapacityObserver.Observe(const AWork: TWorkProgress);
begin
  Inc(Calls);
  if ((AWork.Stage = 'semantic_validate_runs') and (AWork.Done mod 128 = 0)) or
    (AWork.Stage = 'semantic_validate_providers') or (Calls mod 1000000 = 0) then
  begin
    WriteLn('Corpus snapshot work ', AWork.Stage, ' ', AWork.Done, '/', AWork.Total);
    {$ifndef pas2js}Flush(Output);{$endif}
  end;
  if AWork.Stage = CancelStage then raise EAbort.Create('Requested large-corpus cancellation');
end;

procedure Capacity;
var
  LBase: TSemanticStyleDefinition;
  LSources: TMusicalCorpusSources;
  LLedger: TSemanticSources;
  LSelections: TMusicalCorpusSelections;
  LRuns: TMusicalCorpusRuns;
  LCorpus: TMusicalCorpus;
  LStyle: TSemanticStyle;
  LCaptured: TSemanticStyleDefinition;
  LContext: TMusicalContextCell;
  LCoverage: TMusicalCorpusCoverages;
  LUsed: Int64;
  LWeighted: Integer;
  LRejected: Boolean;
  LLoaded: TSemanticStyle;
  LBytes: TAudioBytes;
  LRevision: String;
  LOriginalStart: Int64;
  LOriginalEnd: Int64;
  LObserver: TCapacityObserver;
  LWeightedSamples: TWeightedSequenceSamples;
  LModel: TWfcSequenceModel;
  LShared: TWorkBudget;
  LActualContributions: TMusicalCorpusContributions;
  LActualModels: TLayerModelTexts;
  I: Integer;
  R: Integer;
  C: Integer;
  P: Integer;
begin
  LBase := Definition;
  SetLength(LSources, 64);
  SetLength(LLedger, 64);
  SetLength(LSelections, 64);
  for I := 0 to 63 do
  begin
    LSources[I].Sha256 := LowerCase(IntToHex(I + 1, 64));
    LSources[I].GroupId := 'authored-capacity-' + IntToStr(I);
    LSources[I].SampleRate := 48000;
    LSources[I].FrameCount := 4147200000;
    LSources[I].TrainingWeight := 1;
    LLedger[I] := Default(TSemanticSource);
    LLedger[I].Sha256 := LSources[I].Sha256;
    LLedger[I].GroupId := LSources[I].GroupId;
    LLedger[I].Split := ssTraining;
    LLedger[I].Exposure := [seTraining, seVocabulary];
    LLedger[I].SampleRate := 48000;
    LLedger[I].FrameCount := 4147200000;
    LLedger[I].ExternalRequirement := 'Authored symbolic capacity geometry; no PCM or inference claim';
    LLedger[I].OriginSha256 := LowerCase(IntToHex(I + 1001, 64));
    LLedger[I].OriginSampleRate := 96000;
    LLedger[I].OriginFrameCount := 8294400000;
    LLedger[I].OriginEndFrame := 8294400000;
    LLedger[I].PreparationEvidence := EncodeUTF8Text('Authored exact 2:1 original clock', 1024);
    LLedger[I].PreparationSha256 := SemanticPreparationIdentity(LLedger[I]);
    LSelections[I].SourceIndex := I;
    LSelections[I].EndFrame := 4147200000;
    LSources[I].Classifications := ['caller-style', 'long-recording'];
    LSelections[I].Classifications := ['warm', 'selected'];
  end;
  SetLength(LRuns, 1024);
  for R := 0 to 1023 do
  begin
    LRuns[R].SourceIndex := R div 16;
    LRuns[R].StartFrame := Int64(3000000000) + (R mod 16) * 960000;
    with LRuns[R].Grid do
    begin
      Version := MusicalProposalVersion;
      Policy := 'Authored capacity observations; no WAV inference claim';
      SampleRate := 48000;
      SourceFrames := 768000;
      TempoMicroseconds := 500000;
      RoleNames := ['bass', 'chords', 'lead'];
      RoleOrigins := ['Authored bass', 'Authored chords', 'Authored lead'];
      SetLength(Frames, 64);
      SetLength(Known, 64);
      SetLength(PitchOrigins, 64);
      SetLength(Drums, 64);
      for C := 0 to 63 do
      begin
        LContext := DecodeMusicalContextToken(LBase.Runs[0].Tokens[5][C mod 8]);
        Frames[C] := ProjectWfcChordFrame(LContext.Frame);
        Known[C] := True;
        PitchOrigins[C] := mppPeriodic;
        for P := 0 to 2 do
          Drums[C][P] := PercussionVelocity(LBase.Runs[0].Tokens[P + 6][C mod 8]);
      end;
    end;
  end;
  LCorpus := TMusicalCorpus.Create(LSources, LSelections, LRuns);
  LStyle := nil;
  LLoaded := nil;
  LObserver := TCapacityObserver.Create;
  LModel := nil;
  try
    LCoverage := LCorpus.CopyCoverage;
    LUsed := 0;
    LWeighted := 0;
    for I := 0 to High(LCoverage) do
    begin
      Inc(LUsed, LCoverage[I].ModelUsedFrames);
      Inc(LWeighted, LCoverage[I].WeightedCells);
    end;
    WriteLn('Actual producer: sources=', Length(LCorpus.CopySources),
      '; contributions=', Length(LCorpus.CopyContributions),
      '; providers=', Length(LCorpus.CopyModelTexts),
      '; weighted_cells=', LWeighted, '; model_used_seconds=', LUsed div 48000);
    LCaptured := MusicalCorpusStyleDefinition(LCorpus, LLedger, LBase.Instrumental, LObserver.Observe);
    LActualContributions := LCorpus.CopyContributions;
    LActualModels := LCorpus.CopyModelTexts;
    LRevision := LCorpus.RevisionIdentity;
    WriteLn('Corpus capture ready; validating source');
    {$ifndef pas2js}Flush(Output);{$endif}
    LStyle := TSemanticStyle.CreateSource(LCaptured, nil, nil, LObserver.Observe);
    WriteLn('Corpus source validated; encoding');
    {$ifndef pas2js}Flush(Output);{$endif}
    LBytes := LStyle.Encode;
    Check(Length(LBytes) < 8 * 1024 * 1024, 'Corpus archive expands repeated token strings');
    LObserver.CancelStage := 'wfc_sequence_learn_state_rows';
    LRejected := False;
    try
      LLoaded := DecodeSemanticStyle(LBytes, nil, nil, LObserver.Observe);
    except
      on EAbort do LRejected := True;
    end;
    Check(LRejected and (LLoaded = nil), 'Canceled corpus reload published a partial style');
    LObserver.CancelStage := '';
    WriteLn('Corpus cancellation preserved; retrying reload');
    {$ifndef pas2js}Flush(Output);{$endif}
    LLoaded := DecodeSemanticStyle(LBytes, nil, nil, LObserver.Observe);
    Check(LLoaded.Identity = LStyle.Identity, 'Complete corpus archive changes on reload');
    LCaptured := LLoaded.CopyDefinition;
    Check((Length(LCaptured.Sources) = 64) and (Length(LCaptured.Runs) = 1024) and
      (Length(LCaptured.Providers) = 9), 'Complete corpus snapshot loses admitted sources/runs/providers');
    Check(LCaptured.Corpus.RevisionIdentity = LRevision, 'Actual corpus model revision changes');
    Check((LCaptured.Corpus.Sources[0].Classifications[0] = 'caller-style') and
      (LCaptured.Corpus.Selections[0].Classifications[0] = 'warm') and
      (LCaptured.Corpus.Coverage[0].WeightedCells = 1024) and
      (LCaptured.Sources[0].FrameCount = 4147200000), 'Corpus context or long prepared geometry changes');
    SemanticRunOriginRange(LCaptured.Sources[0], LCaptured.Runs[0], LOriginalStart, LOriginalEnd);
    Check((LOriginalStart = 6000000000) and (LOriginalEnd = 6001536000),
      'Long original source coordinates are truncated or rounded');
    for I := 0 to High(LCaptured.Runs) do
      Check((LCaptured.Runs[I].Identity = LActualContributions[I].Identity) and
        (LCaptured.Runs[I].Weights[0] = 1), 'Admitted corpus contribution or influence changes');
    for P := 0 to 8 do
      Check(LCaptured.Providers[P].ModelText = LActualModels[P],
        'Large corpus snapshot changes an actual provider model');
    LCaptured.Corpus.Sources[0].Classifications[0] := 'mutated copy';
    LCaptured := LLoaded.CopyDefinition;
    Ancestry(LCaptured, 'complete corpus');
    LCaptured := Default(TSemanticStyleDefinition);
    FreeAndNil(LCorpus);
    LLedger := nil;
    LSources := nil;
    LSelections := nil;
    LRuns := nil;
    SameInstrumental(LStyle, LLoaded);
    Check(LObserver.Calls > 100, 'Large corpus validation exposes no actual progress');
    SetLength(LWeightedSamples, 1);
    LWeightedSamples[0].Tokens := ['a', 'b', 'a'];
    LWeightedSamples[0].Weight := 1;
    LRejected := False;
    try
      LModel := LearnWeightedSequenceModel(LWeightedSamples, 1, 3, nil, 1);
    except
      on EAudio do LRejected := True;
    end;
    Check(LRejected and (LModel = nil), 'Nil-callback learning bypasses its work budget');
    LModel := LearnWeightedSequenceModel(LWeightedSamples, 1, 3, nil, MaximumSemanticStyleLearningWork);
    Check(LModel <> nil, 'Work-limit rejection poisons a valid learning retry');
    FreeAndNil(LModel);
    LShared := TWorkBudget.Create(1048576, 'Compound model validation');
    try
      LModel := LearnWeightedSequenceModel(LWeightedSamples, 1, 3, nil, 0, LShared);
      Check((LModel <> nil) and (LShared.Used > 0), 'Shared nil-callback learning is not charged');
      FreeAndNil(LModel); LShared.Charge(LShared.Remaining); LRejected := False;
      try LModel := LearnWeightedSequenceModel(LWeightedSamples, 1, 3, nil, 0, LShared)
      except on EAudio do LRejected := True end;
      Check(LRejected and (LModel = nil) and (LShared.Remaining = 0),
        'A later model resets or bypasses the compound work budget');
    finally LShared.Free end;
    WriteLn('Complete large corpus archive ', LStyle.Identity, ' bytes=', Length(LBytes),
      '; actual_progress_callbacks=', LObserver.Calls);
  finally
    LModel.Free;
    LObserver.Free;
    LLoaded.Free;
    LStyle.Free;
    LCorpus.Free;
  end;
end;
begin
  {$ifdef PYTHIAN_BLENDS_ONLY}
  Blends;
  {$else}
  {$ifdef PYTHIAN_ANCESTRY_ONLY}
  ArchiveStorage;
  Ancestry(Definition, 'authored');
  {$else}
  {$ifdef PYTHIAN_SCOPES_ONLY}
  ScopedControls;
  {$else}
  {$ifdef PYTHIAN_VARIANTS_ONLY}
  Variants;
  {$else}
  {$ifndef PYTHIAN_CAPACITY_ONLY}
  Performance;
  {$ifndef PYTHIAN_PERFORMANCE_ONLY}
  Replay(Definition);
  Replay(CorpusDefinition);
  Failures;
  Blends;
  Seeds;
  MetadataOrigin;
  Variants;
  ScopedControls;
  ArchiveStorage;
  Ancestry(Definition, 'authored');
  {$endif}
  {$endif}
  {$ifndef PYTHIAN_PERFORMANCE_ONLY}
  Capacity;
  {$endif}
  {$endif}
  {$endif}
  {$endif}
  {$endif}
  WriteLn('Complete instrumental style checks passed: ', GChecks);
end.
