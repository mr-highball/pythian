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

program pythian_tests_musical_corpus;

{$mode delphi}
{$H+}

uses Classes, SysUtils, Math, pythian.audio, pythian.hash, pythian.text, pythian.chord,
  pythian.time, pythian.wave, pythian.progress, pythian.music.observations,
  pythian.music.proposal, pythian.music.sound, pythian.instrument, pythian.synth,
  pythian.oscillator, pythian.bus, pythian.schedule,
  pythian.wfc.musical.corpus, pythian.wfc.instrumental, pythian.wfc.percussion,
  pythian.wfc.providers, pythian.wfc.layers, pythian.wfc.learning,
  pythian.wfc.voices,
  wfc_model, wfc_sequence, wfc_sequence_text, wfc_music_ensemble, wfc_music_voices_graph;

type
  TProbe = class
    Stage: String;
    Calls: Integer;
    procedure Observe(const AProgress: TWorkProgress);
  end;

var Checks: Integer;

procedure Check(const ACondition: Boolean; const AMessage: String);
begin
  Inc(Checks);
  if not ACondition then raise Exception.Create(AMessage);
end;

procedure TProbe.Observe(const AProgress: TWorkProgress);
begin
  Inc(Calls);
  if AProgress.Stage = Stage then raise EAbort.Create('Requested cancellation');
end;

function SourceAudio(const AIndex: Integer): TAudioClip;
const CNotes: array[0..1, 0..3] of Integer = ((60, 64, 60, 64), (67, 69, 67, 69));
var
  LSamples: TAudioSamples;
  I, LCell, LWithin: Integer;
  LFrequency, LTime, LTransient: Double;
begin
  SetLength(LSamples, 64000);
  for I := 0 to High(LSamples) do
  begin
    LCell := I div 2000;
    LWithin := I mod 2000;
    LFrequency := 440 * Power(2, (CNotes[AIndex, (LCell div 2) mod 4] - 69) / 12);
    LTime := LWithin / 8000;
    LTransient := 0.035 * Exp(-LTime * 100) *
      (Sin(2 * Pi * 80 * LTime) + Sin(2 * Pi * 1300 * LTime) + Sin(2 * Pi * 3300 * LTime));
    LSamples[I] := 0.25 * Sin(2 * Pi * LFrequency * I / 8000) + LTransient;
  end;
  Result := TAudioClip.Create(8000, 1, LSamples);
end;

function Build(const ASources: TMusicalCorpusSources;
  const ASelections: TMusicalCorpusSelections; const ARuns: TMusicalCorpusRuns;
  const AProgress: TWorkProgressCallback = nil; const ABudget: Integer = 65536): TMusicalCorpus;
begin
  Result := TMusicalCorpus.Create(ASources, ASelections, ARuns, 1, 2, ABudget, AProgress);
end;

function Render(const APlan: TInstrumentalPlan): TAudioClip;
var
  LGraph: TBusGraph;
  LPlayer: TScheduledSynth;
  LBlock: TAudioClip;
  LSamples, LBlockSamples: TAudioSamples;
  LOffset, LFrames: Integer;
begin
  LGraph := TBusGraph.Create(8000, [DefaultBusSettings]);
  LPlayer := nil;
  try
    LPlayer := APlan.CreatePlayer(LGraph);
    SetLength(LSamples, APlan.FrameCount * 2);
    LOffset := 0;
    while LOffset < APlan.FrameCount do
    begin
      LFrames := Min(512, APlan.FrameCount - LOffset);
      LBlock := RenderScheduledFrames(LPlayer, LFrames);
      try
        LBlockSamples := LBlock.CopySamples;
        CopyAudioSampleRange(LBlockSamples, 0, LSamples, LOffset * 2, LFrames * 2);
      finally LBlock.Free end;
      Inc(LOffset, LFrames);
    end;
    Result := TAudioClip.Create(8000, 2, LSamples);
  finally
    LPlayer.Free;
    LGraph.Free;
  end;
end;

function DecisionHash(const APlan: TInstrumentalPlan): String;
var
  LMusic: TWfcMusicVoicesGenerated;
  LHits: TPercussionHits;
  LText: String;
  I: Integer;
begin
  LText := '';
  LMusic := APlan.CopyMusic;
  for I := 0 to High(LMusic.Frames) do
    LText := LText + EncodeWfcMusicEnsembleFrame(LMusic.Frames[I]) + #10;
  LHits := APlan.CopyPercussionHits;
  for I := 0 to High(LHits) do
    LText := LText + IntToStr(LHits[I].Part) + ':' + IntToStr(LHits[I].Cell) + ':' +
      IntToStr(LHits[I].Velocity) + #10;
  Result := Sha256Bytes(EncodeUTF8Text(LText, 1048576));
end;

procedure RunWeightedBoundaries;
var
  LSamples: TWeightedSequenceSamples;
  LModel: TWfcSequenceModel;
  LFound, LFailed: Boolean;
  I, J: Integer;
begin
  SetLength(LSamples, 3);
  LSamples[0].Tokens := ['a', 'b'];
  LSamples[0].Weight := 3;
  LSamples[1].Tokens := ['c', 'd'];
  LSamples[1].Weight := 1;
  LSamples[2].Tokens := ['excluded'];
  LSamples[2].Weight := 0;
  LModel := LearnWeightedSequenceModel(LSamples, 2);
  try
    Check((LModel.ObservationCount = 8) and (LModel.SampleCount = 4) and
      (LModel.FindPublicToken('excluded') = -1), 'Training weights and explicit exclusion change actual statistics');
    LFound := False;
    for I := 0 to LModel.StateCount - 1 do
      for J := 0 to LModel.StateCount - 1 do
        if (LModel.ProjectStateToken(I) = 'b') and (LModel.ProjectStateToken(J) = 'c') then
        begin
          LFound := True;
          Check(not LModel.StatesCompatible(I, J), 'Weighted learning invents no transition between source samples');
        end;
    Check(LFound, 'Actual learned boundary states inspected');
  finally LModel.Free end;
  LSamples[0].Weight := 0;
  LSamples[1].Weight := 0;
  LFailed := False;
  LModel := nil;
  try LModel := LearnWeightedSequenceModel(LSamples, 1);
  except on E: EAudio do LFailed := True end;
  try Check(LFailed and (LModel = nil), 'All-zero evidence cannot publish a model');
  finally LModel.Free end;
end;

procedure CheckMeanings(const ABefore, AAfter: TMusicalCorpus);
var
  LBefore: TMusicalProviderVocabularies;
  LAfter: TMusicalProviderVocabularies;
  LAt: Integer;
  I: Integer;
  J: Integer;
begin
  LBefore := ABefore.CopyVocabularies;
  LAfter := AAfter.CopyVocabularies;
  Check(Length(LBefore) = Length(LAfter), 'Rebuild retains the actual provider schema');
  for I := 0 to High(LBefore) do
  begin
    Check((LBefore[I].Key = LAfter[I].Key) and (LBefore[I].Codec = LAfter[I].Codec),
      'Meanings retain their explicit provider and decoder');
    for J := 0 to High(LBefore[I].Tokens) do
    begin
      LAt := AAfter.ResolveToken(LBefore[I].Key, LBefore[I].Tokens[J].Identity);
      Check((LAt >= 0) and (LAt < Length(LAfter[I].Tokens)),
        'Every retained meaning resolves in the rebuilt model');
      Check(LAfter[I].Tokens[LAt].Value = LBefore[I].Tokens[J].Value,
        'Stable identity cannot silently change its musical value');
    end;
  end;
end;

procedure CheckRebuilds(const ACorpus: TMusicalCorpus;
  const ASources: TMusicalCorpusSources; const ASelections: TMusicalCorpusSelections;
  const ARuns: TMusicalCorpusRuns);
var
  LSources: TMusicalCorpusSources;
  LSelections: TMusicalCorpusSelections;
  LRuns: TMusicalCorpusRuns;
  LSingle: TMusicalCorpus;
  LReordered: TMusicalCorpus;
  LRepeated: TMusicalCorpus;
  LRenamed: TMusicalCorpus;
  LBefore: TMusicalProviderVocabularies;
  LAfter: TMusicalProviderVocabularies;
  LLeaves: TMusicalCorpusContributions;
  LOtherLeaves: TMusicalCorpusContributions;
  LModel: TWfcSequenceModel;
  LMissing: Boolean;
  LMoved: Boolean;
  LAt: Integer;
  I: Integer;
  J: Integer;
begin
  LSingle := nil;
  LReordered := nil;
  LRepeated := nil;
  LRenamed := nil;
  try
    LSources := [ASources[0]];
    LSelections := [ASelections[0]];
    LRuns := [ARuns[0]];
    LSingle := Build(LSources, LSelections, LRuns);
    CheckMeanings(LSingle, ACorpus);
    Check((LSingle.Config.HarmonyModel.ObservationCount = 128) and
      (ACorpus.Config.HarmonyModel.ObservationCount = 144),
      'Adding one recording rebuilds128+16 observations, not old+old+new');
    LBefore := LSingle.CopyVocabularies;
    LAfter := ACorpus.CopyVocabularies;
    Check((LSingle.RevisionIdentity <> ACorpus.RevisionIdentity) and
      (LBefore[0].ModelSha256 <> LAfter[0].ModelSha256),
      'A changed learned model gets a distinct revision binding');
    LMissing := False;
    for I := 0 to High(LAfter) do
    begin
      LModel := DecodeWfcSequenceText(ACorpus.CopyModelTexts[I]);
      try
        Check(LAfter[I].ModelSha256 = Sha256Bytes(
          EncodeUTF8Text(ACorpus.CopyModelTexts[I], 16777216)),
          'Vocabulary binds the exact saved model bytes');
        for J := 0 to High(LAfter[I].Tokens) do
        begin
          Check(LModel.PublicTokenAt(J) = LAfter[I].Tokens[J].Value,
            'Local index mapping describes the actual reloaded provider');
          if LSingle.ResolveToken(LAfter[I].Key, LAfter[I].Tokens[J].Identity) < 0 then
          begin
            LMissing := True;
          end;
        end;
      finally
        LModel.Free;
      end;
    end;
    Check(LMissing, 'Removing a source leaves its unique meanings absent instead of reassigning IDs');
    Check(ACorpus.ResolveToken('missing-provider', LAfter[0].Tokens[0].Identity) = -1,
      'Stable meaning cannot cross provider roles');
    Check(ACorpus.ResolveToken(LAfter[0].Key, StringOfChar('f', 64)) = -1,
      'Unknown identity has no numeric fallback');

    LSources := [ASources[1], ASources[0]];
    LSelections := [ASelections[1], ASelections[0]];
    LSelections[0].SourceIndex := 0;
    LSelections[1].SourceIndex := 1;
    LRuns := [ARuns[1], ARuns[0]];
    LRuns[0].SourceIndex := 0;
    LRuns[1].SourceIndex := 1;
    LReordered := Build(LSources, LSelections, LRuns);
    CheckMeanings(ACorpus, LReordered);
    LMoved := False;
    LBefore := ACorpus.CopyVocabularies;
    for I := 0 to High(LBefore) do
    begin
      for J := 0 to High(LBefore[I].Tokens) do
      begin
        LAt := LReordered.ResolveToken(LBefore[I].Key, LBefore[I].Tokens[J].Identity);
        LMoved := LMoved or (LAt <> J);
      end;
    end;
    Check(LMoved, 'Fixture exercises real local-index changes after recording reorder');
    LLeaves := ACorpus.CopyContributions;
    LOtherLeaves := LReordered.CopyContributions;
    Check((Length(LLeaves) = 2) and (Length(LOtherLeaves) = 2) and
      (LLeaves[0].Identity = LOtherLeaves[1].Identity) and
      (LLeaves[1].Identity = LOtherLeaves[0].Identity),
      'Source/run ordinals change without duplicating or renaming original evidence');
    Check((LLeaves[0].StartFrame = 8000) and (LLeaves[0].EndFrame = 40000) and
      (LLeaves[0].CellCount = 16) and (LLeaves[0].TrainingWeight = 8),
      'Contribution binds original clock, admitted cells and explicit multiplicity');
    LRepeated := Build(ASources, ASelections, ARuns);
    Check((LRepeated.RevisionIdentity = ACorpus.RevisionIdentity) and
      (LRepeated.Config.HarmonyModel.ObservationCount = 144) and
      (Length(LRepeated.CopyContributions) = 2),
      'Repeated full rebuild neither doubles ancestry nor changes the accepted revision');
    LBefore[0].Tokens[0].Value := 'corrupted';
    LBefore[0].Tokens[0].Identity := 'corrupted';
    LBefore[0].Key := 'corrupted';
    LLeaves[0].StartFrame := 0;
    Check((ACorpus.CopyVocabularies[0].Key = 'harmony') and
      (ACorpus.CopyVocabularies[0].Tokens[0].Value <> 'corrupted') and
      (ACorpus.CopyContributions[0].StartFrame = 8000),
      'Returned vocabulary and evidence records are detached');
    WriteLn('Corpus revision SHA256: ', ACorpus.RevisionIdentity);
    WriteLn('First stable token SHA256: ', ACorpus.CopyVocabularies[0].Tokens[0].Identity);
    WriteLn('First contribution SHA256: ', ACorpus.CopyContributions[0].Identity);
    LSources := [ASources[0]];
    LSelections := [ASelections[0]];
    LRuns := LSingle.CopyRuns;
    { Identical canonical input on both targets: an explicit native String cast
      from a tagged UTF-8 scalar would transcode through the host code page. }
    {$ifdef pas2js}
    LRuns[0].Grid.RoleNames[2] := 'lead-' + ScalarText($1F3B5);
    {$else}
    LRuns[0].Grid.RoleNames[2] := 'lead-' + #$F0#$9F#$8E#$B5;
    {$endif}
    LRenamed := Build(LSources, LSelections, LRuns);
    LBefore := LSingle.CopyVocabularies;
    LAfter := LRenamed.CopyVocabularies;
    Check((LBefore[0].Tokens[0].Identity = LAfter[0].Tokens[0].Identity) and
      (LBefore[1].Tokens[0].Identity <> LAfter[1].Tokens[0].Identity) and
      (LBefore[5].Tokens[0].Identity <> LAfter[5].Tokens[0].Identity),
      'Role-schema edits change joint rhythm/context meanings while preserving pitch classes');
    Check((LSingle.CopyContributions[0].Identity <> LRenamed.CopyContributions[0].Identity) and
      (LBefore[4].Tokens[0].Identity <> LAfter[4].Tokens[0].Identity),
      'Unicode role identity binds its actual evidence and named-voice vocabulary');
    WriteLn('Unicode stable token SHA256: ', LAfter[4].Tokens[0].Identity);
  finally
    LRenamed.Free;
    LRepeated.Free;
    LReordered.Free;
    LSingle.Free;
  end;
end;

procedure Run;
var
  LClips: array[0..1] of TAudioClip;
  LWindow: TAudioClip;
  LGrids: array[0..1] of TProposedMusicalGrid;
  LMeasured: TMusicalObservations;
  LCopyGrid: TProposedMusicalGrid;
  LSources, LSourceCopy: TMusicalCorpusSources;
  LSelections, LSelectionCopy: TMusicalCorpusSelections;
  LRuns, LRunCopy: TMusicalCorpusRuns;
  LCorpus, LChanged, LGap, LCandidate: TMusicalCorpus;
  LCoverage: TMusicalCorpusCoverages;
  LTexts, LOtherTexts, LReplayTexts: TLayerModelTexts;
  LDrums: TPercussionDefinitions;
  LModel: TWfcSequenceModel;
  LLoadedModels: array of TWfcSequenceModel;
  LLoadedConfig: TWfcMusicVoicesGraphConfig;
  LRoles: TInstrumentalRoles;
  LZones: TInstrumentZones;
  LPlan, LOther, LReplay: TInstrumentalPlan;
  LOptions: TInstrumentalOptions;
  LReport: TInstrumentalReport;
  LProbe: TProbe;
  LFailed, LTokenChanged: Boolean;
  LRendered, LOtherRendered, LReplayRendered: TAudioClip;
  LSound: TMusicalSound;
  LTones: TFrameTones;
  LOriginalSamples, LWindowSamples: TAudioSamples;
  I, J, LKnown: Integer;
  LPasses: TVoiceGraphPasses;
  {$ifndef pas2js}
  LModelFile: TStringStream;
  {$endif}
begin
  LCorpus := nil; LChanged := nil; LGap := nil; LCandidate := nil;
  LPlan := nil; LOther := nil; LReplay := nil;
  LRendered := nil; LOtherRendered := nil; LReplayRendered := nil;
  LProbe := TProbe.Create;
  for I := 0 to 1 do LClips[I] := nil;
  try
    SetLength(LSources, 2);
    SetLength(LSelections, 2);
    SetLength(LRuns, 2);
    for I := 0 to 1 do
    begin
      LClips[I] := SourceAudio(I);
      LOriginalSamples := LClips[I].CopySamples;
      SetLength(LWindowSamples, 32000);
      CopyAudioSampleRange(LOriginalSamples, 8000, LWindowSamples, 0, 32000);
      LWindow := TAudioClip.Create(8000, 1, LWindowSamples);
      try
        LMeasured := MeasureMusicalObservations(LWindow);
      finally LWindow.Free end;
      Check(Length(LMeasured.Bands) = 3, 'Shared FFT supplies all three spectral bands');
      LGrids[I] := ProposeMusicalGrid(LMeasured, 8000, 32000, 500000);
      Check((Length(LGrids[I].Frames) = 16) and (Length(LGrids[I].RoleNames) = 3),
        'Actual measured source produces complete three-role musical cells');
      LKnown := 0;
      for J := 0 to High(LGrids[I].Frames) do
        if LGrids[I].Known[J] then Inc(LKnown);
      Check(LKnown = 16, 'Controlled tonal recording has full proposed coverage');
      Check(LGrids[I].HasSound and (LGrids[I].Sound.CutoffHz > 100),
        'Source measurement supplies an explicit proposed sound recipe');
      LSources[I].Sha256 := Sha256Bytes(EncodeWavePcm16(LClips[I]));
      LSources[I].GroupId := 'controlled-recording-' + IntToStr(I);
      LSources[I].SampleRate := 8000;
      LSources[I].FrameCount := 64000;
      LSources[I].TrainingWeight := 1;
      LSources[I].Classifications := ['operator collection'];
      LSelections[I].SourceIndex := I;
      LSelections[I].StartFrame := 8000;
      LSelections[I].EndFrame := 40000;
      LSelections[I].Classifications := ['warm'];
      LRuns[I].SourceIndex := I;
      LRuns[I].StartFrame := 8000;
      LRuns[I].Grid := LGrids[I];
    end;
    Check(LSources[0].Sha256 <> LSources[1].Sha256, 'Distinct measured source identities');
    LCopyGrid := CopyProposedMusicalGrid(LGrids[0]);
    LCopyGrid.Frames[0][0].Tones[0].Pitch := 1;
    LCopyGrid.RoleNames[0] := 'changed';
    Check((LGrids[0].Frames[0][0].Tones[0].Pitch <> 1) and (LGrids[0].RoleNames[0] = 'bass'),
      'Portable proposal copy detaches nested musical records');

    LSources[0].TrainingWeight := 8;
    LCorpus := Build(LSources, LSelections, LRuns);
    CheckRebuilds(LCorpus, LSources, LSelections, LRuns);
    LCoverage := LCorpus.CopyCoverage;
    for I := 0 to 1 do
    begin
      Check((LCoverage[I].IncludedFrames = 32000) and (LCoverage[I].ExcludedFrames = 32000) and
        (LCoverage[I].ProcessedFrames = 32000) and (LCoverage[I].ModelUsedFrames = 32000) and
        (LCoverage[I].UnmodeledFrames = 0), 'Included, excluded, processed and model-used durations differ explicitly');
      Check((LCoverage[I].ModelCells = 16) and (LCoverage[I].WeightedCells = 16 * LSources[I].TrainingWeight) and
        (LCoverage[I].Samples = 1) and (LCoverage[I].WeightedSamples = LSources[I].TrainingWeight),
        'Track influence multiplies actual samples and observations');
    end;
    Check((LCorpus.Config.HarmonyModel.ObservationCount = 144) and
      (LCorpus.ContextModel.ObservationCount = 144), 'Actual companion models contain weighted observations');
    LTexts := LCorpus.CopyModelTexts;
    Check(Length(LTexts) = 9, 'Harmony, rhythm, three voice, paired context and three drum providers');
    for I := 0 to High(LTexts) do
    begin
      LModel := DecodeWfcSequenceText(LTexts[I]);
      try
        Check((LModel.ObservationCount = 144) and (LModel.SampleCount = 9),
          'Every saved provider retains real weights and recording boundaries');
      finally LModel.Free end;
      Writeln('Provider ', I, ' SHA256: ', Sha256Bytes(EncodeUTF8Text(LTexts[I], 16777216)));
    end;
    LSourceCopy := LCorpus.CopySources;
    LSourceCopy[0].Classifications[0] := 'changed';
    LSourceCopy[0].TrainingWeight := 2;
    LRunCopy := LCorpus.CopyRuns;
    LRunCopy[0].Grid.Frames[0][0].Tones[0].Pitch := 2;
    LSelectionCopy := LCorpus.CopySelections;
    LSelectionCopy[0].StartFrame := 0;
    LSelectionCopy[0].Classifications[0] := 'changed';
    Check((LCorpus.CopySources[0].Classifications[0] = 'operator collection') and
      (LCorpus.CopySources[0].TrainingWeight = 8) and
      (LCorpus.CopyRuns[0].Grid.Frames[0][0].Tones[0].Pitch <> 2) and
      (LCorpus.CopySelections[0].StartFrame = 8000) and
      (LCorpus.CopySelections[0].Classifications[0] = 'warm'),
      'Corpus evidence, classification arrays and source clocks are detached');

    LSources[0].TrainingWeight := 1;
    LSources[1].TrainingWeight := 8;
    LChanged := Build(LSources, LSelections, LRuns);
    CheckMeanings(LCorpus, LChanged);
    Check((LCorpus.CopyContributions[0].Identity = LChanged.CopyContributions[0].Identity) and
      (LCorpus.CopyContributions[1].Identity = LChanged.CopyContributions[1].Identity) and
      (LChanged.CopyContributions[0].TrainingWeight = 1) and
      (LChanged.CopyContributions[1].TrainingWeight = 8) and
      (LCorpus.RevisionIdentity <> LChanged.RevisionIdentity),
      'Reweighting changes the revision and counts without inventing new source ancestry');
    LOtherTexts := LChanged.CopyModelTexts;
    LTokenChanged := False;
    for I := 0 to High(LTexts) do
      if LTexts[I] <> LOtherTexts[I] then LTokenChanged := True;
    Check(LTokenChanged, 'Influence changes actual saved learned models');
    Check(LCorpus.ProposedSound(LSound), 'Used source seconds produce a proposed sound recipe');

    LRunCopy := LCorpus.CopyRuns;
    LRunCopy[0].Grid.Known[4] := False;
    LRunCopy[0].Grid.PitchOrigins[4] := mppUnknown;
    LRunCopy[0].Grid.Frames[4] := nil;
    for I := 0 to 2 do
      if Length(LRunCopy[0].Grid.Frames[5][I].Tones) > 0 then
        LRunCopy[0].Grid.Frames[5][I].Action := caAttack;
    LGap := Build(LSources, LSelections, LRunCopy);
    LCoverage := LGap.CopyCoverage;
    Check((LCoverage[0].Samples = 2) and (LCoverage[0].ModelCells = 15) and
      (LCoverage[0].UnmodeledFrames = 2000), 'Unknown cell splits samples without an invented rest or join');
    Check((LGap.CopyRuns[0].StartFrame = 8000) and not LGap.CopyRuns[0].Grid.Known[4],
      'Unknown timing and exact original offset survive learning');
    Check((Length(LGap.CopyContributions) = 3) and
      (LGap.CopyContributions[0].EndFrame = 16000) and
      (LGap.CopyContributions[1].StartFrame = 18000),
      'Unknown time splits actual evidence leaves on the original source clock');
    FreeAndNil(LGap);
    LRunCopy := LCorpus.CopyRuns;
    SetLength(LRunCopy[0].AdmittedCells, 16);
    LRunCopy[0].AdmittedCells[4] := True;
    LRunCopy[0].AdmittedCells[5] := True;
    LRunCopy[0].AdmittedCells[10] := True;
    LRunCopy[0].AdmittedCells[11] := True;
    LGap := Build(LSources, LSelections, LRunCopy);
    LCoverage := LGap.CopyCoverage;
    Check((LCoverage[0].ProposedFrames = 32000) and (LCoverage[0].ModelUsedFrames = 8000) and
      (LCoverage[0].BudgetOmittedFrames = 24000) and (LCoverage[0].Samples = 2),
      'Representative masks retain exact proposal coverage without training across omitted time');
    Check(LGap.CopyRuns[0].Grid.Known[0] and not LGap.CopyRuns[0].AdmittedCells[0],
      'Budget omissions remain separate from measured unknown cells');
    Check((LGap.CopyContributions[0].StartFrame = 16000) and
      (LGap.CopyContributions[0].EndFrame = 20000) and
      (LGap.CopyContributions[1].StartFrame = 28000) and
      (LGap.CopyContributions[1].EndFrame = 32000),
      'Representative omissions never acquire a synthetic joined ancestor');
    LRunCopy := LGap.CopyRuns;
    LRunCopy[0].AdmittedCells[4] := False;
    Check(LGap.CopyRuns[0].AdmittedCells[4], 'Returned representative masks are detached');
    FreeAndNil(LGap);

    LFailed := False;
    LSelectionCopy := Copy(LSelections);
    LSelectionCopy[0].EndFrame := 39999;
    try LCandidate := Build(LSources, LSelectionCopy, LRuns);
    except on E: EAudio do LFailed := True end;
    Check(LFailed and (LCandidate = nil), 'Out-of-selection processing rejects before model publication');
    LSourceCopy := Copy(LSources);
    LSourceCopy[1].Sha256 := LSourceCopy[0].Sha256;
    LFailed := False;
    try LCandidate := Build(LSourceCopy, LSelections, LRuns);
    except on E: EAudio do LFailed := True end;
    Check(LFailed and (LCandidate = nil), 'Duplicate source cannot silently double evidence');
    LFailed := False;
    try LCandidate := Build(LSources, LSelections, LRuns, nil, 4);
    except on E: EAudio do LFailed := True end;
    Check(LFailed and (LCandidate = nil), 'Declared model observation budget is enforced');
    for I := 0 to 5 do
    begin
      case I of
        0: LProbe.Stage := 'musical_corpus_runs';
        1: LProbe.Stage := 'musical_corpus_tokens';
        2: LProbe.Stage := 'wfc_weighted_admission';
        3: LProbe.Stage := 'musical_corpus_contributions';
        4: LProbe.Stage := 'musical_corpus_vocabulary';
        5: LProbe.Stage := 'musical_corpus_vocabulary_ready';
      end;
      LFailed := False;
      try LCandidate := Build(LSources, LSelections, LRuns, LProbe.Observe);
      except on E: EAbort do LFailed := True end;
      Check(LFailed and (LCandidate = nil), 'Cancellation preserves caller result at admission, projection and learning');
    end;
    Check(LCorpus.CopyModelTexts[0] = LTexts[0], 'Failed candidates preserve the accepted learned corpus');
    LProbe.Stage := 'musical_corpus_encode';
    LReplayTexts := ['accepted'];
    LFailed := False;
    try LReplayTexts := LCorpus.CopyModelTexts(LProbe.Observe);
    except on E: EAbort do LFailed := True end;
    Check(LFailed and (Length(LReplayTexts) = 1) and (LReplayTexts[0] = 'accepted'),
      'Cancelled model publication preserves forwarded managed output');

    SetLength(LRoles, 3);
    SetLength(LZones, 1);
    for I := 0 to 2 do
    begin
      LZones[0] := Default(TInstrumentZone);
      LZones[0].MinimumKey := 0;
      LZones[0].MaximumKey := 127;
      LZones[0].MinimumVelocity := 1;
      LZones[0].MaximumVelocity := 127;
      LZones[0].Voice := DefaultSynthVoice;
      LZones[0].Voice.Shape := TWaveShape(I);
      LZones[0].Voice.Gain := 0.10;
      LRoles[I].Name := LCorpus.CopyRoleNames[I];
      LRoles[I].InstrumentId := 'explicit-primary-oscillator-' + IntToStr(I);
      LRoles[I].Instrument := TInstrument.Create(LZones);
    end;
    LOptions := DefaultInstrumentalOptions;
    LOptions.SampleRate := 8000;
    LOptions.Session.CellCount := 16;
    LOptions.Session.RequireObservedEnd := False;
    LOptions.MaterialOrigin := 'Experimental measured source proposals; ' + MusicalCorpusPolicy;
    LOptions.Tempos := [MakeTempoChange(0, 500000)];
    LDrums := LCorpus.CopyPercussion(8000);
    if not TryCreateInstrumentalPlan(LCorpus.Config, LRoles, LOptions,
      nil, nil, LPlan, LReport, nil, LDrums, LCorpus.ContextModel) then
      raise Exception.Create('Measured musical corpus rejected: ' + LReport.Detail);
    Check(LPlan.RoleCount = 6, 'Actual primary runtime performs three pitched roles plus three synthesized drums');
    LPasses := LPlan.CopyGraph;
    Check((Length(LPasses) >= 10) and (LPasses[0].Name = 'musical-context') and
      (LPasses[High(LPasses)].GroupIndex = 2),
      'Paired context, actual vocabulary-dependent pitched graph and dependent drums');
    Writeln('Actual learned graph passes: ', Length(LPasses));
    for I := 0 to LPlan.RoleCount - 1 do
    begin
      LTones := LPlan.CopyPartTones(I);
      Check(Length(LTones) > 0, 'Each learned role has an audible synthesized event');
      for J := 0 to High(LTones) do
        Check(LTones[J].Voice.SourceFactory = nil, 'No original-audio source factory enters synthesized output');
    end;
    SetLength(LLoadedModels, Length(LTexts));
    for I := 0 to High(LTexts) do LLoadedModels[I] := DecodeWfcSequenceText(LTexts[I]);
    LLoadedConfig := LCorpus.Config;
    LLoadedConfig.HarmonyModel := LLoadedModels[0];
    LLoadedConfig.RhythmModel := LLoadedModels[1];
    for I := 0 to 2 do
    begin
      LLoadedConfig.Voices[I].Model := LLoadedModels[2 + I];
      LDrums[I].Model := LLoadedModels[6 + I];
    end;
    if not TryCreateInstrumentalPlan(LLoadedConfig, LRoles, LOptions,
      nil, nil, LReplay, LReport, nil, LDrums, LLoadedModels[5]) then
      raise Exception.Create('Saved-model measured replay rejected: ' + LReport.Detail);
    LRendered := Render(LPlan);
    LReplayRendered := Render(LReplay);
    Check(Sha256Bytes(EncodeWavePcm16(LRendered)) = Sha256Bytes(EncodeWavePcm16(LReplayRendered)),
      'Saved/reloaded providers, source weights, graph and seed replay actual synthesized PCM');
    LDrums := LChanged.CopyPercussion(8000);
    if not TryCreateInstrumentalPlan(LChanged.Config, LRoles, LOptions,
      nil, nil, LOther, LReport, nil, LDrums, LChanged.ContextModel) then
      raise Exception.Create('Influence edit rejected: ' + LReport.Detail);
    LOtherRendered := Render(LOther);
    Check(Sha256Bytes(EncodeWavePcm16(LRendered)) <> Sha256Bytes(EncodeWavePcm16(LOtherRendered)),
      'Swapped training influence changes actual synthesized music at the same seed');
    Writeln('Decisions 8:1 SHA256: ', DecisionHash(LPlan));
    Writeln('Decisions 1:8 SHA256: ', DecisionHash(LOther));
    Writeln('Synthesized 8:1 SHA256: ', Sha256Bytes(EncodeWavePcm16(LRendered)));
    Writeln('Synthesized 1:8 SHA256: ', Sha256Bytes(EncodeWavePcm16(LOtherRendered)));
    {$ifndef pas2js}
    if ParamCount > 0 then
    begin
      ForceDirectories(ParamStr(1));
      SaveWavePcm16(IncludeTrailingPathDelimiter(ParamStr(1)) + 'source-a.wav', LClips[0]);
      SaveWavePcm16(IncludeTrailingPathDelimiter(ParamStr(1)) + 'source-b.wav', LClips[1]);
      SaveWavePcm16(IncludeTrailingPathDelimiter(ParamStr(1)) + 'influence-8-1.wav', LRendered);
      SaveWavePcm16(IncludeTrailingPathDelimiter(ParamStr(1)) + 'influence-1-8.wav', LOtherRendered);
      for I := 0 to High(LTexts) do
      begin
        LModelFile := TStringStream.Create(LTexts[I]);
        try LModelFile.SaveToFile(IncludeTrailingPathDelimiter(ParamStr(1)) + 'provider-' + IntToStr(I) + '.txt');
        finally LModelFile.Free end;
      end;
    end;
    {$endif}
  finally
    LReplayRendered.Free; LOtherRendered.Free; LRendered.Free;
    LReplay.Free; LOther.Free; LPlan.Free;
    for I := 0 to High(LLoadedModels) do LLoadedModels[I].Free;
    for I := 0 to High(LRoles) do LRoles[I].Instrument.Free;
    LCandidate.Free; LGap.Free; LChanged.Free; LCorpus.Free;
    for I := 0 to 1 do LClips[I].Free;
    LProbe.Free;
  end;
end;

begin
  RunWeightedBoundaries;
  Run;
  Writeln('PASS musical corpus: ', Checks, ' checks');
end.
