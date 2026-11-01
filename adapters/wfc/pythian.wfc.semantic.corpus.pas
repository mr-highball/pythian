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
unit pythian.wfc.semantic.corpus;

{$mode delphi}{$H+}

interface

uses pythian.progress, pythian.wfc.musical.corpus, pythian.wfc.semantic.style;

{ Big Boss: captures the learner's actual admitted samples and models. The caller
  supplies real prepared/original source geometry and sound choices, never an
  inferred instrument identification. No recording is reopened or reanalyzed.
  The result is detached; CreateSource performs ordinary archive admission.
  Existing explicit semantic archive limits apply and reject rather than omit
  sources, contributions or providers. Corpus excerpt-origin digests must be
  present in caller preparation evidence; they never replace audio hashes. }
function MusicalCorpusStyleDefinition(const ACorpus: TMusicalCorpus;
  const ASources: TSemanticSources; const ARecipe: TSemanticInstrumentalRecipe;
  const AProgress: TWorkProgressCallback = nil): TSemanticStyleDefinition;

implementation

uses SysUtils, pythian.audio, pythian.time, pythian.text,
  pythian.instrument.recipe, pythian.mix.recipe, pythian.music.form,
  pythian.music.pattern, pythian.music.proposal,
  pythian.wfc.providers, pythian.wfc.provider.contracts, pythian.wfc.layers,
  pythian.wfc.percussion,
  wfc_sequence, wfc_music_voices_graph;

procedure Need(const AValue: Boolean; const AMessage: String);
begin
  if not AValue then raise EAudio.Create(AMessage);
end;

function MusicalCorpusStyleDefinition(const ACorpus: TMusicalCorpus;
  const ASources: TSemanticSources; const ARecipe: TSemanticInstrumentalRecipe;
  const AProgress: TWorkProgressCallback): TSemanticStyleDefinition;
var
  LSources: TMusicalCorpusSources;
  LRuns: TMusicalCorpusRuns;
  LContributions: TMusicalCorpusContributions;
  LSamples: TMusicalProviderSamples;
  LModels: TLayerModelTexts;
  LProviderNames: TLayerModelTexts;
  LDrums: TPercussionDefinitions;
  LNames: TMusicalProposalNames;
  LConfig: TWfcMusicVoicesGraphConfig;
  LContext: TMusicalContextCell;
  LPrevious: array of Int64;
  LContribution: TMusicalCorpusContribution;
  LRun: TSemanticRun;
  LGrid: TProposedMusicalGrid;
  LContextIndex: Integer;
  I: Integer;
  P: Integer;
begin
  Need(ACorpus <> nil, 'Musical style capture requires an actual corpus');
  LSources := ACorpus.CopySources;
  LRuns := ACorpus.CopyRuns;
  LContributions := ACorpus.CopyContributions;
  LSamples := ACorpus.CopyTrainingSamples;
  LModels := ACorpus.CopyModelTexts(AProgress);
  LProviderNames := ACorpus.CopyProviderNames;
  LDrums := ACorpus.CopyPercussion(ARecipe.SampleRate);
  LNames := ACorpus.CopyRoleNames;
  LConfig := ACorpus.Config;
  LContextIndex := 2 + Length(LNames);
  Need((Length(ASources) = Length(LSources)) and
    (Length(ASources) <= MaximumMusicalCorpusSources),
    'Musical style capture needs the complete supported corpus source ledger');
  Need(Length(LContributions) <= MaximumSemanticStyleRuns,
    'Musical style capture exceeds the retained contribution limit');
  Need(ARecipe.Enabled and (Length(ARecipe.Percussion) = 3),
    'Musical corpus style requires an enabled recipe with kick/snare/hat');
  Result := Default(TSemanticStyleDefinition);
  Result.Corpus.RevisionIdentity := ACorpus.RevisionIdentity;
  Result.Corpus.Sources := LSources;
  Result.Corpus.Selections := ACorpus.CopySelections;
  Result.Corpus.Coverage := ACorpus.CopyCoverage;
  Result.Corpus.RoleNames := Copy(LNames);
  Result.Corpus.ProviderNames := Copy(LProviderNames);
  Result.Corpus.Contributions := Copy(LContributions);
  Result.NamedVoices := True;
  Result.HarmonyMode := LConfig.HarmonyMode;
  Result.VoicePairs := Copy(LConfig.PairConstraints);
  Result.Instrumental := ARecipe;
  Result.Instrumental.Instruments := Copy(ARecipe.Instruments);
  for I := 0 to High(ARecipe.Instruments) do
  begin
    Result.Instrumental.Instruments[I] := CopyInstrumentRecipe(ARecipe.Instruments[I]);
  end;
  Result.Instrumental.Mix := CopyStemMixRecipe(ARecipe.Mix);
  Result.Instrumental.Form := CopyMusicForm(ARecipe.Form);
  Result.Instrumental.Expression := Copy(ARecipe.Expression);
  Result.Instrumental.Percussion := CopyPercussionDefinitions(ARecipe.Percussion);
  for I := 0 to High(ARecipe.Percussion) do
  begin
    Need((ARecipe.Percussion[I].Model = nil) or
      (ARecipe.Percussion[I].Model = LDrums[I].Model), 'Sound recipe borrows a foreign percussion model');
    Result.Instrumental.Percussion[I].Model := nil;
    if Length(ARecipe.Percussion[I].AllowedHitRhythms) = 0 then
      Result.Instrumental.Percussion[I].AllowedHitRhythms := Copy(LDrums[I].AllowedHitRhythms);
  end;
  SetLength(Result.VoiceRanges, Length(LNames));
  for I := 0 to High(LNames) do
  begin
    Result.VoiceRanges[I].MinimumPitch := LConfig.Voices[I].MinPitch;
    Result.VoiceRanges[I].MaximumPitch := LConfig.Voices[I].MaxPitch;
  end;
  Result.Sources := Copy(ASources);
  SetLength(LPrevious, Length(LSources));
  for I := 0 to High(LSources) do
  begin
    Need((ASources[I].Sha256 = LSources[I].Sha256) and
      (ASources[I].GroupId = LSources[I].GroupId) and
      (ASources[I].SampleRate = LSources[I].SampleRate) and
      (ASources[I].FrameCount = LSources[I].FrameCount),
      'Musical style source ledger differs from actual learned source geometry');
    if LSources[I].OriginIdentity <> '' then
    begin
      Need(Pos(LSources[I].OriginIdentity, String(DecodeUTF8Text(
        ASources[I].PreparationEvidence, 65536, True, True))) > 0,
        'Musical style preparation evidence loses the independent excerpt origin');
    end;
    Result.Sources[I].PreparationEvidence := Copy(ASources[I].PreparationEvidence);
    LPrevious[I] := -1;
  end;
  SetLength(Result.Runs, Length(LContributions));
  for I := 0 to High(LContributions) do
  begin
    ReportWork(AProgress, 'semantic_capture_contributions', wuItems, I, Length(LContributions));
    LContribution := LContributions[I];
    LGrid := LRuns[LContribution.RunIndex].Grid;
    LRun := Default(TSemanticRun);
    LRun.SourceIndex := LContribution.SourceIndex;
    LRun.Identity := LContribution.Identity;
    LRun.ProposalPolicy := LGrid.Policy;
    LRun.RoleOrigins := Copy(LGrid.RoleOrigins);
    LRun.StartFrame := LContribution.StartFrame;
    LRun.EndFrame := LContribution.EndFrame;
    if LPrevious[LRun.SourceIndex] >= 0 then
      LRun.GapBeforeFrames := LRun.StartFrame - LPrevious[LRun.SourceIndex];
    LPrevious[LRun.SourceIndex] := LRun.EndFrame;
    LRun.TicksPerQuarter := PitchPatternPpq;
    LRun.ClockStartTick := LContribution.FirstCell * PitchPatternStepTicks;
    LRun.ClockRounding := frCeiling;
    LRun.TempoChanges := [MakeTempoChange(0, LGrid.TempoMicroseconds)];
    SetLength(LRun.Tokens, Length(LModels));
    SetLength(LRun.Weights, Length(LModels));
    SetLength(LRun.TimeGrids, Length(LModels));
    for P := 0 to High(LModels) do
    begin
      LRun.Tokens[P] := Copy(LSamples[P][I].Tokens);
      LRun.Weights[P] := LSamples[P][I].Weight;
      LRun.TimeGrids[P] := MakeLayerTimeGrid(0, PitchPatternStepTicks);
    end;
    Result.Runs[I] := LRun;
  end;
  SetLength(Result.Providers, Length(LModels));
  for P := 0 to High(LModels) do
  begin
    with Result.Providers[P] do
    begin
      ModelText := LModels[P];
      Contract.Name := LProviderNames[P];
      Contract.MusicalDomain := 'instrumental-musical-proposals';
      Contract.TicksPerQuarter := PitchPatternPpq;
      Contract.Scope := MakeLayerScope(LContributions[0].CellCount, wseWhole);
      Contract.TimeGrid := MakeLayerTimeGrid(0, PitchPatternStepTicks);
      if P = 0 then Contract.Vocabulary := spvHarmony
      else if P = 1 then Contract.Vocabulary := spvRhythm
      else if P < LContextIndex then
      begin
        Contract.Vocabulary := spvVoice;
        Contract.RoleId := LNames[P - 2];
        Contract.PitchBasis := ppbAbsoluteMidi;
      end
      else if P = LContextIndex then
      begin
        Contract.Vocabulary := spvMusicalContext;
        Contract.PitchBasis := ppbAbsoluteMidi;
        LContext := DecodeMusicalContextToken(LSamples[P][0].Tokens[0]);
        if LContext.DrivenRole >= 0 then Contract.RoleId := LNames[LContext.DrivenRole];
      end
      else
      begin
        Contract.Vocabulary := spvPercussion;
        Contract.Name := ARecipe.Percussion[P - LContextIndex - 1].Name;
      end;
      if (P = 1) or (P = LContextIndex) then Contract.RoleOrder := Copy(LNames);
      Contract.UnknownPolicy := ProviderUnknownPolicy(Contract.Vocabulary);
      ExtractionPolicy := MusicalCorpusPolicy + '; actual proposal policies/role origins retained in observed runs';
      VocabularySha256 := SemanticVocabularyIdentity(ModelText, Contract, AProgress);
    end;
  end;
  ReportWork(AProgress, 'semantic_capture_ready', wuItems, 1, 1);
end;

end.
