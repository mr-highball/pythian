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

program pythian_tests_learning_profile;

{$mode delphi}
{$H+}

uses
  Classes,
  SysUtils,
  fpjson,
  jsonparser,
  pythian.audio,
  pythian.analysis,
  pythian.learning,
  pythian.learning.binding,
  pythian.learning.journal,
  pythian.learning.selection,
  pythian.learning.context,
  pythian.wfc.learning,
  pythian.wfc.learning.profile,
  pythian.wfc.learning.blend,
  pythian.hash,
  wfc_sequence,
  wfc_sequence_text;

type
  TFixtureWindows = class
    Reads: Integer;
    Truncate: Boolean;
    function ReadWindow(const ACandidate: TJournalRepresentative): TAudioSamples;
  end;

function TFixtureWindows.ReadWindow(const ACandidate: TJournalRepresentative): TAudioSamples;
var
  LIndex: Integer;
begin
  Inc(Reads);
  Result := nil;
  SetLength(Result, ACandidate.ValidFrames - Ord(Truncate));
  for LIndex := 0 to High(Result) do
  begin
    Result[LIndex] := 0.25;
  end;
end;

procedure Check(const ACondition: Boolean; const AMessage: String);
begin
  if not ACondition then
  begin
    raise Exception.Create(AMessage);
  end;
end;

function TextHash(const AValue: String): String;
var
  LBytes: TAudioBytes;
begin
  SetLength(LBytes, Length(AValue));
  if Length(LBytes) > 0 then
  begin
    Move(AValue[1], LBytes[0], Length(LBytes));
  end;
  Result := Sha256Bytes(LBytes);
end;

procedure ExpectRejected(const AReport, AModel, AMessage: String);
var
  LProfile: TJournalModelProfile;
  LRejected: Boolean;
begin
  LProfile := nil;
  LRejected := False;
  try
    try
      LProfile := TJournalModelProfile.Create(AReport, AModel);
    except
      on EAudio do
      begin
        LRejected := True;
      end;
      on EJSON do
      begin
        LRejected := True;
      end;
    end;
    Check(LRejected, AMessage);
  finally
    LProfile.Free;
  end;
end;

procedure CheckModelCounts(const AActual, AExpected: TWfcSequenceModel);
var
  LIndex: Integer;
  LOther: Integer;
  LPosition: Integer;
  LMatches: Boolean;
  LFound: Boolean;
  LLeft: TWfcSequenceHistoryItem;
  LRight: TWfcSequenceHistoryItem;
begin
  Check((AActual.StateCount = AExpected.StateCount) and
    (AActual.ObservationCount = AExpected.ObservationCount) and
    (AActual.SampleCount = AExpected.SampleCount), 'Blend totals differ from actual learner');
  for LIndex := 0 to AActual.StateCount - 1 do
  begin
    LFound := False;
    for LOther := 0 to AExpected.StateCount - 1 do
    begin
      LMatches := AActual.ProjectStateToken(LIndex) = AExpected.ProjectStateToken(LOther);
      for LPosition := 0 to AActual.Order - 2 do
      begin
        LLeft := AActual.HistoryItemAt(LIndex, LPosition);
        LRight := AExpected.HistoryItemAt(LOther, LPosition);
        LMatches := LMatches and (LLeft.Kind = LRight.Kind);
        if (LLeft.Kind = wshToken) and (LRight.Kind = wshToken) then
        begin
          LMatches := LMatches and
            (AActual.PublicTokenAt(LLeft.TokenIndex) = AExpected.PublicTokenAt(LRight.TokenIndex));
        end;
      end;
      if LMatches then
      begin
        Check((AActual.StateObservationCountAt(LIndex) = AExpected.StateObservationCountAt(LOther)) and
          (AActual.StartCountAt(LIndex) = AExpected.StartCountAt(LOther)) and
          (AActual.EndCountAt(LIndex) = AExpected.EndCountAt(LOther)),
          'Blend state/start/end counts differ from independently repeated corpus');
        LFound := True;
        Break;
      end;
    end;
    Check(LFound, 'Blend introduced or lost a learned state');
  end;
end;

procedure CheckBlends(const AProfile: TJournalModelProfile);
var
  LRight: TJournalModelProfile;
  LBlend: TJournalModelProfile;
  LReloaded: TJournalModelProfile;
  LSecond: TJournalModelProfile;
  LSelf: TJournalModelProfile;
  LExcluded: TJournalModelProfile;
  LRejectedProfile: TJournalModelProfile;
  LConflict: TJournalModelProfile;
  LRightModel: TWfcSequenceModel;
  LExpected: TWfcSequenceModel;
  LDocument: TJSONObject;
  LSources: TJSONArray;
  LCorpus: TAcousticCorpus;
  LText: UTF8String;
  LOriginal: UTF8String;
  LLineage: TJournalProfileContributions;
  LIndex: Integer;
  LRejected: Boolean;
  LTokens: TAcousticIndices;
  LSlots: TAcousticIndices;
  LWeights: TJournalSelectionWeights;
begin
  LRight := nil;
  LBlend := nil;
  LReloaded := nil;
  LSecond := nil;
  LSelf := nil;
  LExcluded := nil;
  LRejectedProfile := nil;
  LConflict := nil;
  LRightModel := nil;
  LExpected := nil;
  LDocument := nil;
  LOriginal := AProfile.EncodeReport;
  try
    LCorpus := TAcousticCorpus.Create(TAcousticIndices.Create(1, 1), TAcousticIndices.Create(0, 0));
    LRightModel := LearnAcousticModel(LCorpus, AProfile.Palette, AProfile.Model.Order);
    LText := EncodeWfcSequenceText(LRightModel);
    LDocument := TJSONObject(GetJSON(AProfile.EncodeReport));
    LDocument.Elements['model_sha256'] := TJSONString.Create(TextHash(LText));
    LDocument.Elements['model_binding_sha256'] :=
      TJSONString.Create(AcousticModelBindingSha256(AProfile.VocabularySha256, TextHash(LText)));
    LDocument.Elements['wfc_states'] := TJSONIntegerNumber.Create(LRightModel.StateCount);
    LSources := TJSONArray(LDocument.Find('sources'));
    TJSONObject(LSources.Items[0]).Elements['source_sha256'] := TJSONString.Create(StringOfChar('e', 64));
    TJSONObject(LSources.Items[1]).Elements['source_sha256'] := TJSONString.Create(StringOfChar('f', 64));
    LRight := TJournalModelProfile.Create(LDocument.FormatJSON, LText);
    Check(AProfile.Model.PublicTokenAt(0) <> LRight.Model.PublicTokenAt(0),
      'Fixture must exercise different public-token order');
    LBlend := BlendJournalProfiles(AProfile, LRight, 2, 1);
    LCorpus := TAcousticCorpus.Create(
      TAcousticIndices.Create(0, 1), TAcousticIndices.Create(1, 0),
      TAcousticIndices.Create(0, 1), TAcousticIndices.Create(1, 0),
      TAcousticIndices.Create(1, 1), TAcousticIndices.Create(0, 0));
    LExpected := LearnAcousticModel(LCorpus, AProfile.Palette, AProfile.Model.Order);
    CheckModelCounts(LBlend.Model, LExpected);
    FreeAndNil(LExpected);
    Check((LBlend.SourceCount = 4) and (LBlend.SourceAt(0).Multiplicity = 2) and
      (LBlend.SourceAt(2).Multiplicity = 1), 'Blend source weights must be explicit');
    LReloaded := TJournalModelProfile.Create(LBlend.EncodeReport, LBlend.EncodeModel);
    LSecond := BlendJournalProfiles(LReloaded, LRight, 2, 1);
    SetLength(LCorpus, 14);
    for LIndex := 0 to 3 do
    begin
      LCorpus[LIndex * 2] := TAcousticIndices.Create(0, 1);
      LCorpus[LIndex * 2 + 1] := TAcousticIndices.Create(1, 0);
    end;
    for LIndex := 0 to 2 do
    begin
      LCorpus[8 + LIndex * 2] := TAcousticIndices.Create(1, 1);
      LCorpus[9 + LIndex * 2] := TAcousticIndices.Create(0, 0);
    end;
    LExpected := LearnAcousticModel(LCorpus, AProfile.Palette, AProfile.Model.Order);
    CheckModelCounts(LSecond.Model, LExpected);
    Check((LSecond.SourceCount = 4) and (LSecond.SourceAt(0).Multiplicity = 4) and
      (LSecond.SourceAt(2).Multiplicity = 3), 'Second blend must coalesce repeated source ranges');
    LLineage := LSecond.CopyTrainingLineage;
    Check((Length(LLineage) = 2) and (LLineage[0].Weight = 4) and
      (LLineage[1].Weight = 3), 'Second blend must preserve cumulative training contributions');
    LLineage[0].Weight := 99;
    LLineage := LSecond.CopyTrainingLineage;
    Check(LLineage[0].Weight = 4, 'Lineage accessor must be detached');
    LSelf := BlendJournalProfiles(AProfile, AProfile, 2, 1);
    Check((LSelf.SourceCount = 2) and (LSelf.SourceAt(0).Multiplicity = 3) and
      (LSelf.Model.ObservationCount = AProfile.Model.ObservationCount * 3),
      'Repeated parent adds evidence without inventing independent sources');
    LExcluded := BlendJournalProfiles(AProfile, LRight, 0, 1);
    CheckModelCounts(LExcluded.Model, LRight.Model);
    Check(LExcluded.SourceCount = 2, 'Zero-weight parent contributes no sources');
    Check(AProfile.EncodeReport = LOriginal, 'Blending must preserve input profiles');
    LTokens := TAcousticIndices.Create(0, 1, 1, 0);
    LWeights := TJournalSelectionWeights.Create(0, 0, 1, 1);
    LSlots := LSecond.Pool.Select(LTokens, LWeights, 731);
    for LIndex := 0 to High(LSlots) do
    begin
      Check((LSecond.Pool.TokenAt(LSlots[LIndex]) = LTokens[LIndex]) and
        (LSecond.Pool.CandidateAt(LSlots[LIndex]).SegmentIndex >= 2),
        'Derived candidate remapping must retain tokens and independent source exclusion');
    end;
    TJSONObject(LSources.Items[0]).Elements['source_sha256'] :=
      TJSONString.Create(AProfile.SourceAt(0).Binding.SourceSha256);
    TJSONObject(LSources.Items[0]).Elements['cache_sha256'] :=
      TJSONString.Create(StringOfChar('f', 64));
    LConflict := TJournalModelProfile.Create(LDocument.FormatJSON, LText);
    LRejected := False;
    try
      LRejectedProfile := BlendJournalProfiles(AProfile, LConflict, 1, 1);
    except
      on EAudio do
      begin
        LRejected := True;
      end;
    end;
    Check(LRejected, 'Repeated source with conflicting feature identity must reject');
    LRejected := False;
    try
      LRejectedProfile := BlendJournalProfiles(LSecond, LSecond, 64, 64);
    except
      on EAudio do
      begin
        LRejected := True;
      end;
    end;
    { Fourteen samples times 128 is legal; use a further multiplication to
      exercise preflight rejection without constructing a huge corpus. }
    if not LRejected then
    begin
      try
        LSelf.Free;
        LSelf := nil;
        LSelf := BlendJournalProfiles(LRejectedProfile, LSecond, 64, 1);
      except
        on EAudio do
        begin
          LRejected := True;
        end;
      end;
    end;
    Check(LRejected, 'Oversized derived blend must reject before count overflow');
    WriteLn('Weighted saved blends match independent learner; second blend, lineage and budgets PASS');
  finally
    LDocument.Free;
    LExpected.Free;
    LRightModel.Free;
    LRejectedProfile.Free;
    LConflict.Free;
    LExcluded.Free;
    LSelf.Free;
    LSecond.Free;
    LReloaded.Free;
    LBlend.Free;
    LRight.Free;
  end;
end;

procedure CheckSavedContexts(const AProfile: TJournalModelProfile);
var
  LSources: TJournalContextSources;
  LSets: TJournalContextSets;
  LPool: TJournalContextPool;
  LEnriched: TJournalModelProfile;
  LRight: TJournalModelProfile;
  LFirst: TJournalModelProfile;
  LSecond: TJournalModelProfile;
  LReloaded: TJournalModelProfile;
  LExcluded: TJournalModelProfile;
  LConflict: TJournalModelProfile;
  LRejectedProfile: TJournalModelProfile;
  LRoot: TJSONObject;
  LContextObject: TJSONObject;
  LRows: TJSONArray;
  LRow: TJSONObject;
  LSource: TJournalProfileSource;
  LOptions: TJournalContextOptions;
  LReport: TJournalContextReport;
  LPlan: TJournalContextWindows;
  LReplay: TJournalContextWindows;
  LTokens: TAcousticIndices;
  LSlots: TAcousticIndices;
  LWeights: TJournalSelectionWeights;
  LLocks: TJournalContextLocks;
  LIndex: Integer;
  LOffset: Integer;
  LCase: Integer;
  LRejected: Boolean;
  LOriginal: UTF8String;
begin
  LPool := nil;
  LEnriched := nil;
  LRight := nil;
  LFirst := nil;
  LSecond := nil;
  LReloaded := nil;
  LExcluded := nil;
  LConflict := nil;
  LRejectedProfile := nil;
  LRoot := nil;
  try
    SetLength(LSources, AProfile.SourceCount);
    SetLength(LSets, AProfile.SourceCount);
    for LIndex := 0 to High(LSources) do
    begin
      LSource := AProfile.SourceAt(LIndex);
      LSources[LIndex].Binding := LSource.Binding;
      LSources[LIndex].FirstFeature := LSource.FirstFeature;
      LSources[LIndex].FeatureCount := LSource.FeatureCount;
      SetLength(LSets[LIndex], 2);
      for LOffset := 0 to 1 do
      begin
        LSets[LIndex][LOffset].Token := (LIndex + LOffset) mod 2;
        LSets[LIndex][LOffset].Candidate.Found := True;
        LSets[LIndex][LOffset].Candidate.SegmentIndex := LIndex;
        LSets[LIndex][LOffset].Candidate.FeatureIndex := LOffset;
        LSets[LIndex][LOffset].Candidate.SourceFrame := LOffset * 32;
        LSets[LIndex][LOffset].Candidate.ValidFrames := 64 - LOffset * 32;
      end;
    end;
    LPool := TJournalContextPool.CreateFromContexts(AProfile.Palette, AProfile.Pool, LSources, LSets);
    LSets[0][0].Token := 1;
    Check(LPool.WindowAt(0, 0).Token = 0, 'Restored contexts detach nested input arrays');
    LEnriched := AProfile.WithContexts(LPool);
    Check((AProfile.Contexts = nil) and (LEnriched.Contexts.Count = 2) and
      (LEnriched.EncodeModel = AProfile.EncodeModel), 'Attaching contexts leaves parent/model unchanged');
    LOriginal := LEnriched.EncodeReport;
    LRoot := TJSONObject(GetJSON(LOriginal));
    TJSONObject(TJSONArray(LRoot.Find('sources')).Items[0]).Elements['source_sha256'] :=
      TJSONString.Create(StringOfChar('e', 64));
    TJSONObject(TJSONArray(LRoot.Find('sources')).Items[1]).Elements['source_sha256'] :=
      TJSONString.Create(StringOfChar('f', 64));
    LRight := TJournalModelProfile.Create(LRoot.FormatJSON, LEnriched.EncodeModel);
    FreeAndNil(LRoot);
    LFirst := BlendJournalProfiles(LEnriched, LRight, 1, 2);
    LSecond := BlendJournalProfiles(LFirst, LEnriched, 2, 3);
    LReloaded := TJournalModelProfile.Create(LSecond.EncodeReport, LSecond.EncodeModel);
    Check((LSecond.SourceCount = 4) and (LSecond.Contexts.Count = 4) and
      (LReloaded.Contexts.WindowCount = 8), 'Further blends remap sources and coalesce repeated contexts');
    for LIndex := 0 to 3 do
    begin
      Check((LReloaded.Contexts.WindowAt(LIndex, 0).Candidate.SegmentIndex = LIndex) and
        (LReloaded.Contexts.WindowAt(LIndex, 1).Candidate.ValidFrames = 32),
        'Reload preserves canonical source mapping and partial EOF');
    end;
    LTokens := TAcousticIndices.Create(0, 1, 0, 1, 0, 1, 0, 1);
    LWeights := TJournalSelectionWeights.Create(1, 1, 1, 1);
    LSlots := LSecond.Pool.Select(LTokens, LWeights);
    SetLength(LLocks, Length(LTokens));
    LLocks[0] := True;
    LOptions := DefaultJournalContextOptions;
    LPlan := LSecond.Contexts.Plan(LSlots, LLocks, LOptions, LReport);
    LReplay := LReloaded.Contexts.Plan(LSlots, LLocks, LOptions, LReport);
    for LIndex := 0 to High(LPlan) do
    begin
      Check((LPlan[LIndex].Token = LTokens[LIndex]) and
        (LPlan[LIndex].Candidate.SourceFrame = LReplay[LIndex].Candidate.SourceFrame) and
        (LPlan[LIndex].Candidate.SegmentIndex = LReplay[LIndex].Candidate.SegmentIndex),
        'Saved further-blend context selection replays exactly');
    end;
    LExcluded := BlendJournalProfiles(LEnriched, AProfile, 0, 1);
    Check(LExcluded.Contexts = nil, 'Excluded parent contributes no context capability');
    for LCase := 0 to 5 do
    begin
      LRoot := TJSONObject(GetJSON(LOriginal));
      LContextObject := TJSONObject(LRoot.Find('source_contexts'));
      LRows := TJSONArray(LContextObject.Find('contexts'));
      LRow := TJSONObject(LRows.Items[0]);
      case LCase of
        0:
          begin
            LContextObject.Elements['vocabulary_sha256'] := TJSONString.Create(StringOfChar('0', 64));
          end;
        1:
          begin
            TJSONArray(LRow.Find('tokens')).Items[0] := TJSONFloatNumber.Create(0.5);
          end;
        2:
          begin
            LRow.Elements['source_index'] := TJSONIntegerNumber.Create(2);
          end;
        3:
          begin
            LRow.Elements['first_feature'] := TJSONIntegerNumber.Create(1);
          end;
        4:
          begin
            LRows.Add(LRow.Clone);
          end;
        5:
          begin
            TJSONArray(LRow.Find('center_distances')).Delete(0);
          end;
      end;
      ExpectRejected(LRoot.FormatJSON, LEnriched.EncodeModel, 'Malformed context binding/geometry rejects');
      FreeAndNil(LRoot);
    end;
    LRoot := TJSONObject(GetJSON(LOriginal));
    LRow := TJSONObject(TJSONArray(TJSONObject(LRoot.Find('source_contexts')).Find('contexts')).Items[0]);
    TJSONArray(LRow.Find('tokens')).Items[0] := TJSONIntegerNumber.Create(1);
    LConflict := TJournalModelProfile.Create(LRoot.FormatJSON, LEnriched.EncodeModel);
    LRejected := False;
    try
      LRejectedProfile := BlendJournalProfiles(LEnriched, LConflict, 1, 1);
    except
      on EAudio do
      begin
        LRejected := True;
      end;
    end;
    Check(LRejected and (LEnriched.EncodeReport = LOriginal),
      'Conflicting repeated context rejects without mutating its parent');
    WriteLn('Saved contexts, source remapping, further blends, exact replay and malformed input PASS');
  finally
    LRoot.Free;
    LRejectedProfile.Free;
    LConflict.Free;
    LExcluded.Free;
    LReloaded.Free;
    LSecond.Free;
    LFirst.Free;
    LRight.Free;
    LEnriched.Free;
    LPool.Free;
  end;
end;

procedure Run(const AOrder: Integer);
var
  LOptions: TAnalysisOptions;
  LCenters: TAcousticVectors;
  LPalette: TAcousticPalette;
  LChangedPalette: TAcousticPalette;
  LCorpus: TAcousticCorpus;
  LModel: TWfcSequenceModel;
  LText: String;
  LVocabulary: String;
  LDocument: TJSONObject;
  LChanged: TJSONObject;
  LSources: TJSONArray;
  LCandidates: TJSONArray;
  LPaletteJson: TJSONArray;
  LRow: TJSONObject;
  LVector: TJSONArray;
  LProfile: TJournalModelProfile;
  LReloaded: TJournalModelProfile;
  LIncompatible: TJournalModelProfile;
  LWide: TJournalModelProfile;
  LSource: Integer;
  LFeature: Integer;
  LToken: Integer;
  LIndex: Integer;
  LComponent: Integer;
  LTokens: TAcousticIndices;
  LSelected: TAcousticIndices;
  LWeights: TJournalSelectionWeights;
  LWindowReader: TFixtureWindows;
  LClip: TAudioClip;
  LRejected: Boolean;
begin
  LOptions := DefaultAnalysisOptions;
  LOptions.WindowFrames := 64;
  LOptions.HopFrames := 32;
  SetLength(LCenters, 2);
  LCenters[0][0] := 1;
  LCenters[1][4] := 1;
  LPalette := TAcousticPalette.CreateFromCenters(LCenters);
  LModel := nil;
  LDocument := nil;
  LProfile := nil;
  LReloaded := nil;
  LIncompatible := nil;
  LWide := nil;
  LChangedPalette := nil;
  LWindowReader := nil;
  LClip := nil;
  try
    SetLength(LCorpus, 2);
    LCorpus[0] := TAcousticIndices.Create(0, 1);
    LCorpus[1] := TAcousticIndices.Create(1, 0);
    LModel := LearnAcousticModel(LCorpus, LPalette, AOrder);
    LText := EncodeWfcSequenceText(LModel);
    LVocabulary := AcousticVocabularySha256(LPalette, LOptions, 8000, 1);
    LDocument := TJSONObject.Create;
    LDocument.Add('contract', 'pythian.acoustic.journal-learning');
    LDocument.Add('analysis_version', AnalysisVersion);
    LDocument.Add('learning_version', AcousticLearningVersion);
    LDocument.Add('sample_rate', 8000);
    LDocument.Add('channels', 1);
    LDocument.Add('window_frames', 64);
    LDocument.Add('hop_frames', 32);
    LDocument.Add('silence_rms', LOptions.SilenceRms);
    LDocument.Add('raw_observations', 4);
    LDocument.Add('weighted_observations', 4);
    LDocument.Add('wfc_observations', 4);
    LDocument.Add('wfc_samples', 2);
    LDocument.Add('wfc_states', LModel.StateCount);
    LDocument.Add('order', AOrder);
    LDocument.Add('candidate_bins_per_segment', 2);
    LDocument.Add('model_sha256', TextHash(LText));
    LDocument.Add('vocabulary_sha256', LVocabulary);
    LDocument.Add('model_binding_sha256', AcousticModelBindingSha256(LVocabulary, TextHash(LText)));
    LPaletteJson := TJSONArray.Create;
    LDocument.Add('palette', LPaletteJson);
    for LToken := 0 to 1 do
    begin
      LVector := TJSONArray.Create;
      LPaletteJson.Add(LVector);
      for LComponent := 0 to High(TAcousticVector) do
      begin
        LVector.Add(LCenters[LToken][LComponent]);
      end;
    end;
    LSources := TJSONArray.Create;
    LDocument.Add('sources', LSources);
    LCandidates := TJSONArray.Create;
    LDocument.Add('candidates', LCandidates);
    for LSource := 0 to 1 do
    begin
      LRow := TJSONObject.Create;
      LSources.Add(LRow);
      LRow.Add('source', 'fixture-' + IntToStr(LSource) + '.wav');
      LRow.Add('source_sha256', StringOfChar(Chr(Ord('a') + LSource), 64));
      LRow.Add('cache_sha256', StringOfChar('c', 64));
      LRow.Add('source_frames', 64);
      LRow.Add('first_feature', 0);
      LRow.Add('observations', 2);
      LRow.Add('multiplicity', 1);
      for LFeature := 0 to 1 do
      begin
        LToken := LCorpus[LSource][LFeature];
        LRow := TJSONObject.Create;
        LCandidates.Add(LRow);
        LRow.Add('slot', (LToken * 2 + LSource) * 2 + LFeature);
        LRow.Add('token', LToken);
        LRow.Add('source_index', LSource);
        LRow.Add('source_frame', LFeature * 32);
        LRow.Add('feature_index', LFeature);
        LRow.Add('valid_frames', 64 - LFeature * 32);
        LRow.Add('center_distance', Double(0));
      end;
    end;
    LProfile := TJournalModelProfile.Create(LDocument.FormatJSON, LText);
    LReloaded := TJournalModelProfile.Create(LDocument.AsJSON, LText);
    LProfile.RequireCompatible(LReloaded);
    Check((LProfile.VocabularySha256 = LVocabulary) and
      (EncodeWfcSequenceText(LProfile.Model) = LText),
      'Saved profile restores exact vocabulary/model without training');
    Check(LProfile.SourceAt(1).Binding.FrameCount = 64, 'Source extent survives reload');
    CheckBlends(LProfile);
    CheckSavedContexts(LProfile);
    for LIndex := 0 to LProfile.Pool.SlotCount - 1 do
    begin
      Check(LProfile.Pool.CandidateAt(LIndex).Found = LReloaded.Pool.CandidateAt(LIndex).Found,
        'Formatting does not change restored candidate slots');
    end;

    LChanged := TJSONObject(LDocument.Clone);
    try
      LChanged.Elements['hop_frames'] := TJSONIntegerNumber.Create(16);
      ExpectRejected(LChanged.AsJSON, LText, 'Changed timebase must reject unchanged binding');
    finally
      LChanged.Free;
    end;
    LChanged := TJSONObject(LDocument.Clone);
    try
      TJSONArray(TJSONArray(LChanged.Find('palette')).Items[0]).Items[0] :=
        TJSONFloatNumber.Create(0.75);
      ExpectRejected(LChanged.AsJSON, LText, 'Changed palette must reject unchanged binding');
      LCenters[0][0] := 0.75;
      LChangedPalette := TAcousticPalette.CreateFromCenters(LCenters);
      LVocabulary := AcousticVocabularySha256(LChangedPalette, LOptions, 8000, 1);
      LChanged.Elements['vocabulary_sha256'] := TJSONString.Create(LVocabulary);
      LChanged.Elements['model_binding_sha256'] :=
        TJSONString.Create(AcousticModelBindingSha256(LVocabulary, TextHash(LText)));
      LIncompatible := TJournalModelProfile.Create(LChanged.AsJSON, LText);
      LRejected := False;
      try
        LProfile.RequireCompatible(LIncompatible);
      except
        on EAudio do
        begin
          LRejected := True;
        end;
      end;
      Check(LRejected, 'Same token names/model bytes do not make different palettes compatible');
    finally
      LChanged.Free;
    end;
    ExpectRejected(LDocument.AsJSON, LText + #10, 'Changed exact model bytes must reject');
    ExpectRejected(StringOfChar('[', 9) + '0' + StringOfChar(']', 9), LText,
      'Deep JSON must reject before tree parsing');
    LChanged := TJSONObject(LDocument.Clone);
    try
      LRow := TJSONObject(TJSONArray(LChanged.Find('sources')).Items[0]);
      LRow.Elements['source_frames'] := TJSONInt64Number.Create(Int64(2147483648) + 64);
      LRow.Elements['first_feature'] := TJSONInt64Number.Create(Int64(2147483648) div 32);
      for LIndex := 0 to 1 do
      begin
        LRow := TJSONObject(TJSONArray(LChanged.Find('candidates')).Items[LIndex]);
        LRow.Elements['source_frame'] := TJSONInt64Number.Create(Int64(2147483648) + LIndex * 32);
        LRow.Elements['feature_index'] := TJSONInt64Number.Create(Int64(2147483648) div 32 + LIndex);
      end;
      LWide := TJournalModelProfile.Create(LChanged.AsJSON, LText);
      Check(LWide.Pool.CandidateAt(0).SourceFrame = Int64(2147483648),
        'Saved candidate coordinates retain Int64 positions beyond signed 32-bit');
    finally
      LChanged.Free;
    end;
    LChanged := TJSONObject(LDocument.Clone);
    try
      TJSONObject(TJSONArray(LChanged.Find('candidates')).Items[0]).Elements['source_frame'] :=
        TJSONIntegerNumber.Create(1);
      ExpectRejected(LChanged.AsJSON, LText, 'Off-grid candidate must reject');
    finally
      LChanged.Free;
    end;
    ExpectRejected('{"order":2,' + Copy(LDocument.AsJSON, 2, Length(LDocument.AsJSON)),
      LText, 'Duplicate members must reject');
    LChanged := TJSONObject(LDocument.Clone);
    try
      LChanged.Elements['raw_observations'] := TJSONIntegerNumber.Create(5);
      ExpectRejected(LChanged.AsJSON, LText, 'Model/source observation inconsistency must reject');
    finally
      LChanged.Free;
    end;

    LTokens := TAcousticIndices.Create(1, 1);
    LWeights := TJournalSelectionWeights.Create(1, 0);
    LSelected := LProfile.Pool.Select(LTokens, LWeights);
    LWindowReader := TFixtureWindows.Create;
    LClip := RenderJournalSelection(LProfile.Pool, LSelected, LWindowReader.ReadWindow,
      8000, 1, 64, 32);
    Check((LClip.FrameCount = 96) and (LClip.SampleAt(20, 0) > 0) and
      (LClip.SampleAt(95, 0) = 0) and (LWindowReader.Reads = 1),
      'Shared renderer reads a repeated slot once and preserves padded EOF clock');
    LWindowReader.Truncate := True;
    LRejected := False;
    try
      LClip.Free;
      LClip := nil;
      LClip := RenderJournalSelection(LProfile.Pool, LSelected, LWindowReader.ReadWindow,
        8000, 1, 64, 32);
    except
      on EAudio do
      begin
        LRejected := True;
      end;
    end;
    Check(LRejected, 'Short source callback must reject');
    WriteLn('Bound journal profile, palette/timebase/model rejection and shared rendering PASS');
  finally
    LClip.Free;
    LWindowReader.Free;
    LIncompatible.Free;
    LWide.Free;
    LChangedPalette.Free;
    LReloaded.Free;
    LProfile.Free;
    LDocument.Free;
    LModel.Free;
    LPalette.Free;
  end;
end;

function ReadText(const APath: String): UTF8String;
var
  LStream: TFileStream;
begin
  LStream := TFileStream.Create(APath, fmOpenRead or fmShareDenyWrite);
  try
    if (LStream.Size < 1) or (LStream.Size > MaximumJournalProfileBytes) then
    begin
      raise EAudio.Create('Profile test input exceeds byte budget');
    end;
    SetLength(Result, LStream.Size);
    LStream.ReadBuffer(Result[1], Length(Result));
  finally
    LStream.Free;
  end;
end;

procedure CheckSavedProfiles;
var
  LLeft: TJournalModelProfile;
  LRight: TJournalModelProfile;
begin
  if ParamCount <> 2 then
  begin
    raise EAudio.Create('Supply two saved profile prefixes');
  end;
  LLeft := TJournalModelProfile.Create(ReadText(ParamStr(1) + '.json'),
    ReadText(ParamStr(1) + '.wfcs'));
  try
    LRight := TJournalModelProfile.Create(ReadText(ParamStr(2) + '.json'),
      ReadText(ParamStr(2) + '.wfcs'));
    try
      LLeft.RequireCompatible(LRight);
      WriteLn('Compatible saved vocabulary/timebase: ', LLeft.VocabularySha256);
      WriteLn('Model states: ', LLeft.Model.StateCount, ' / ', LRight.Model.StateCount);
      WriteLn('Model bytes equal: ', LLeft.ModelSha256 = LRight.ModelSha256);
    finally
      LRight.Free;
    end;
  finally
    LLeft.Free;
  end;
end;

procedure CheckPartitionOutput;
var
  LBaseline: TJSONObject;
  LSelected: TJSONObject;
  LAudit: TJSONObject;
  LRows: TJSONArray;
  LRow: TJSONObject;
  LSources: TJSONArray;
  LSource: TJSONObject;
  LProfile: TJournalModelProfile;
  LIndex: Integer;
  LSelectedCount: Integer;
begin
  if ParamCount <> 5 then
  begin
    raise EAudio.Create('Supply partition BASELINE_PREFIX SELECTED_PREFIX INPUT_COUNT PARTITION');
  end;
  LBaseline := nil;
  LSelected := nil;
  LProfile := nil;
  try
    LBaseline := TJSONObject(GetJSON(ReadText(ParamStr(2) + '.json')));
    LSelected := TJSONObject(GetJSON(ReadText(ParamStr(3) + '.json')));
    LProfile := TJournalModelProfile.Create(ReadText(ParamStr(3) + '.json'),
      ReadText(ParamStr(3) + '.wfcs'));
    LAudit := LSelected.Objects['partition_selection'];
    Check(LAudit.Strings['selected_partition'] = ParamStr(5), 'Selected partition recorded');
    LRows := LAudit.Arrays['inputs'];
    LSources := LSelected.Arrays['sources'];
    Check(LRows.Count = StrToInt(ParamStr(4)), 'Complete declared plan recorded');
    LSelectedCount := 0;
    for LIndex := 0 to LRows.Count - 1 do
    begin
      LRow := LRows.Objects[LIndex];
      Check(LRow.Booleans['selected'] = (LRow.Strings['partition'] = ParamStr(5)),
        'Audit selection matches declared partition');
      Check(LRow.Strings['group_id'] <> '', 'Audit retains recording-family identity');
      if LRow.Booleans['selected'] then
      begin
        Check(LSelectedCount < LSources.Count, 'Audit has no extra selected input');
        LSource := LSources.Objects[LSelectedCount];
        Check((LRow.Strings['source_sha256'] = LSource.Strings['source_sha256']) and
          (LRow.Strings['cache_sha256'] = LSource.Strings['cache_sha256']) and
          (LRow.Int64s['first_feature'] = LSource.Int64s['first_feature']) and
          (LRow.Int64s['observations'] = LSource.Int64s['observations']) and
          (LRow.Integers['multiplicity'] = LSource.Integers['multiplicity']) and
          (LRow.Floats['generation_weight'] = LSource.Floats['generation_weight']),
          'Selected source, range and weights retain their plan bindings');
        Inc(LSelectedCount);
      end;
    end;
    Check(LSelectedCount = LSources.Count, 'Only selected sources enter the profile');
    LSelected.Delete('partition_selection');
    Check(LSelected.AsJSON = LBaseline.AsJSON,
      'All learning, generation and source fields equal explicit selected-only input');
    Check(ReadText(ParamStr(2) + '.wfcs') = ReadText(ParamStr(3) + '.wfcs'),
      'Partitioned model bytes equal explicit selected-only model');
    WriteLn('Complete partition audit, selected bindings, profile reload and exact output parity PASS');
  finally
    LProfile.Free;
    LSelected.Free;
    LBaseline.Free;
  end;
end;

procedure CheckManyRangesOneSource;
var
  LOptions: TAnalysisOptions;
  LCenters: TAcousticVectors;
  LPalette: TAcousticPalette;
  LCorpus: TAcousticCorpus;
  LModel: TWfcSequenceModel;
  LProfile: TJournalModelProfile;
  LBlend: TJournalModelProfile;
  LDocument: TJSONObject;
  LSources: TJSONArray;
  LCandidates: TJSONArray;
  LPaletteRows: TJSONArray;
  LRow: TJSONObject;
  LVector: TJSONArray;
  LText: String;
  LVocabulary: String;
  LIndex: Integer;
  LComponent: Integer;
begin
  LOptions := DefaultAnalysisOptions;
  LOptions.WindowFrames := 64;
  LOptions.HopFrames := 32;
  SetLength(LCenters, 1);
  LPalette := TAcousticPalette.CreateFromCenters(LCenters);
  LModel := nil;
  LProfile := nil;
  LBlend := nil;
  LDocument := nil;
  try
    SetLength(LCorpus, 33);
    for LIndex := 0 to High(LCorpus) do
    begin
      LCorpus[LIndex] := TAcousticIndices.Create(0);
    end;
    LModel := LearnAcousticModel(LCorpus, LPalette, 2);
    LText := EncodeWfcSequenceText(LModel);
    LVocabulary := AcousticVocabularySha256(LPalette, LOptions, 8000, 1);
    LDocument := TJSONObject.Create;
    LDocument.Add('contract', 'pythian.acoustic.journal-learning');
    LDocument.Add('analysis_version', AnalysisVersion);
    LDocument.Add('learning_version', AcousticLearningVersion);
    LDocument.Add('sample_rate', 8000);
    LDocument.Add('channels', 1);
    LDocument.Add('window_frames', 64);
    LDocument.Add('hop_frames', 32);
    LDocument.Add('silence_rms', LOptions.SilenceRms);
    LDocument.Add('raw_observations', 33);
    LDocument.Add('weighted_observations', 33);
    LDocument.Add('wfc_observations', 33);
    LDocument.Add('wfc_samples', 33);
    LDocument.Add('wfc_states', LModel.StateCount);
    LDocument.Add('order', 2);
    LDocument.Add('candidate_bins_per_segment', 1);
    LDocument.Add('model_sha256', TextHash(LText));
    LDocument.Add('vocabulary_sha256', LVocabulary);
    LDocument.Add('model_binding_sha256', AcousticModelBindingSha256(LVocabulary, TextHash(LText)));
    LPaletteRows := TJSONArray.Create;
    LDocument.Add('palette', LPaletteRows);
    LVector := TJSONArray.Create;
    LPaletteRows.Add(LVector);
    for LComponent := 0 to High(TAcousticVector) do
    begin
      LVector.Add(LCenters[0][LComponent]);
    end;
    LSources := TJSONArray.Create;
    LDocument.Add('sources', LSources);
    LCandidates := TJSONArray.Create;
    LDocument.Add('candidates', LCandidates);
    for LIndex := 0 to 32 do
    begin
      LRow := TJSONObject.Create;
      LSources.Add(LRow);
      LRow.Add('source', 'one.wav');
      LRow.Add('source_sha256', StringOfChar('a', 64));
      LRow.Add('cache_sha256', StringOfChar('c', 64));
      LRow.Add('source_frames', 1056);
      LRow.Add('first_feature', LIndex);
      LRow.Add('observations', 1);
      LRow.Add('multiplicity', 1);
      LRow := TJSONObject.Create;
      LCandidates.Add(LRow);
      LRow.Add('slot', LIndex);
      LRow.Add('token', 0);
      LRow.Add('source_index', LIndex);
      LRow.Add('source_frame', LIndex * 32);
      LRow.Add('feature_index', LIndex);
      if LIndex = 32 then
      begin
        LRow.Add('valid_frames', 32);
      end
      else
      begin
        LRow.Add('valid_frames', 64);
      end;
      LRow.Add('center_distance', Double(0));
    end;
    LProfile := TJournalModelProfile.Create(LDocument.AsJSON, LText);
    Check((LProfile.SourceCount = 33) and (LProfile.Model.SampleCount = 33),
      'More than 32 disjoint ranges retain one sample boundary each');
    LBlend := BlendJournalProfiles(LProfile, LProfile, 1, 1);
    Check((LBlend.SourceCount = 33) and (LBlend.Model.SampleCount = 66) and
      (LBlend.SourceAt(32).Multiplicity = 2),
      'Repeated blend coalesces matching ranges without losing contributions');
    TJSONObject(LSources.Items[32]).Elements['cache_sha256'] :=
      TJSONString.Create(StringOfChar('d', 64));
    ExpectRejected(LDocument.AsJSON, LText,
      'One physical source cannot claim different cache bytes across ranges');
    TJSONObject(LSources.Items[32]).Elements['cache_sha256'] :=
      TJSONString.Create(StringOfChar('c', 64));
    TJSONObject(LSources.Items[32]).Elements['first_feature'] :=
      TJSONIntegerNumber.Create(31);
    ExpectRejected(LDocument.AsJSON, LText,
      'Overlapping ranges cannot contribute duplicate observations');
    TJSONObject(LSources.Items[32]).Elements['first_feature'] :=
      TJSONIntegerNumber.Create(32);
    for LIndex := 0 to 32 do
    begin
      TJSONObject(LSources.Items[LIndex]).Elements['source_sha256'] :=
        TJSONString.Create(StringOfChar('0', 62) + IntToHex(LIndex, 2));
    end;
    ExpectRejected(LDocument.AsJSON, LText,
      'Thirty-three physical sources exceed the independent source budget');
    WriteLn('Thirty-three ranges, one physical source, blend and source cap PASS');
  finally
    LDocument.Free;
    LBlend.Free;
    LProfile.Free;
    LModel.Free;
    LPalette.Free;
  end;
end;

begin
  try
    if ParamStr(1) = 'partition' then
    begin
      CheckPartitionOutput;
    end
    else if ParamCount = 0 then
    begin
      Run(1);
      Run(2);
      Run(4);
      CheckManyRangesOneSource;
    end
    else
    begin
      CheckSavedProfiles;
    end;
  except
    on LError: Exception do
    begin
      WriteLn(StdErr, LError.ClassName, ': ', LError.Message);
      Halt(1);
    end;
  end;
end.
