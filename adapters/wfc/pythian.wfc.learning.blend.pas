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

unit pythian.wfc.learning.blend;

{$mode delphi}
{$H+}

interface

uses
  pythian.wfc.learning.profile;

{ Borrowed parents; returns a detached, caller-owned profile. Integer weights
  0..64 multiply existing evidence, without duration or ratio normalization.
  Shared exact source ranges coalesce and add multiplicities. Partial overlaps
  or conflicting cache identities reject. Generation weights default to one. }
function BlendJournalProfiles(const ALeft, ARight: TJournalModelProfile;
  const ALeftWeight, ARightWeight: Integer): TJournalModelProfile;

implementation

uses
  SysUtils,
  Math,
  fpjson,
  pythian.audio,
  pythian.analysis,
  pythian.hash,
  pythian.learning,
  pythian.learning.binding,
  pythian.learning.journal,
  pythian.learning.selection,
  pythian.learning.context,
  pythian.wfc.learning,
  wfc_model,
  wfc_sequence,
  wfc_sequence_text;

type
  TProfilePair = array[0..1] of TJournalModelProfile;
  TWeightPair = array[0..1] of Integer;
  TProfileSources = array of TJournalProfileSource;
  TSourceMaps = array[0..1] of array of Integer;
  TCountedState = record
    Key: Integer;
    Observations: Integer;
    Starts: Integer;
    Ends: Integer;
  end;

function TextDigest(const AText: UTF8String): String;
var
  LBytes: TAudioBytes;
begin
  SetLength(LBytes, Length(AText));
  if Length(LBytes) > 0 then
  begin
    Move(AText[1], LBytes[0], Length(LBytes));
  end;
  Result := Sha256Bytes(LBytes);
end;

procedure AddContribution(var AValues: TJournalProfileContributions;
  const AValue: TJournalProfileContribution);
var
  LIndex: Integer;
begin
  for LIndex := 0 to High(AValues) do
  begin
    if AValues[LIndex].ProfileSha256 = AValue.ProfileSha256 then
    begin
      if (AValues[LIndex].ModelSha256 <> AValue.ModelSha256) or
        (AValue.Weight > 4096 - AValues[LIndex].Weight) then
      begin
        raise EAudio.Create('Blend lineage conflicts or exceeds weight budget');
      end;
      Inc(AValues[LIndex].Weight, AValue.Weight);
      Exit;
    end;
  end;
  if (Length(AValues) = 64) or (AValue.Weight < 1) or (AValue.Weight > 4096) then
  begin
    raise EAudio.Create('Blend exceeds lineage budget');
  end;
  SetLength(AValues, Length(AValues) + 1);
  AValues[High(AValues)] := AValue;
end;

function ContributionJson(const AValues: TJournalProfileContributions): TJSONArray;
var
  LValue: TJournalProfileContribution;
  LRow: TJSONObject;
begin
  Result := TJSONArray.Create;
  try
    for LValue in AValues do
    begin
      LRow := TJSONObject.Create;
      Result.Add(LRow);
      LRow.Add('profile_sha256', LValue.ProfileSha256);
      LRow.Add('model_sha256', LValue.ModelSha256);
      LRow.Add('weight', LValue.Weight);
    end;
  except
    Result.Free;
    raise;
  end;
end;

function CombineCounts(const AParents: TProfilePair; const AWeights: TWeightPair;
  const ASources: TProfileSources): TWfcSequenceModel;
var
  LCounts: array of TCountedState;
  LValue: TCountedState;
  LStates: TWfcSequenceStates;
  LStateCounts: TWfcModelIntegerArray;
  LStarts: TWfcModelIntegerArray;
  LEnds: TWfcModelIntegerArray;
  LTokens: TWfcModelTokens;
  LLengths: TWfcSequenceSampleLengths;
  LTokenMap: array[0..31] of Integer;
  LUsed: array[0..31] of Boolean;
  LModel: TWfcSequenceModel;
  LHistory: TWfcSequenceHistoryItem;
  LSide: Integer;
  LIndex: Integer;
  LOther: Integer;
  LPosition: Integer;
  LKey: Integer;
  LToken: Integer;
  LFound: Integer;
  LLength: Integer;
  LRepeat: Integer;
  LSource: TJournalProfileSource;
begin
  LCounts := nil;
  FillChar(LUsed, SizeOf(LUsed), 0);
  for LSide := 0 to 1 do
  begin
    if AWeights[LSide] = 0 then
    begin
      Continue;
    end;
    LModel := AParents[LSide].Model;
    for LIndex := 0 to LModel.PublicTokenCount - 1 do
    begin
      LUsed[AcousticTokenIndex(LModel.PublicTokenAt(LIndex))] := True;
    end;
    for LIndex := 0 to LModel.StateCount - 1 do
    begin
      LKey := 0;
      for LPosition := 0 to LModel.Order - 2 do
      begin
        LHistory := LModel.HistoryItemAt(LIndex, LPosition);
        LToken := 32;
        if LHistory.Kind = wshToken then
        begin
          LToken := AcousticTokenIndex(LModel.PublicTokenAt(LHistory.TokenIndex));
        end;
        LKey := LKey * 33 + LToken;
      end;
      LKey := LKey * 33 + AcousticTokenIndex(LModel.ProjectStateToken(LIndex));
      LFound := -1;
      for LOther := 0 to High(LCounts) do
      begin
        if LCounts[LOther].Key = LKey then
        begin
          LFound := LOther;
          Break;
        end;
      end;
      if LFound < 0 then
      begin
        if Length(LCounts) = WFC_SEQUENCE_MAX_STATE_COUNT then
        begin
          raise EAudio.Create('Blend exceeds companion state budget');
        end;
        LFound := Length(LCounts);
        SetLength(LCounts, LFound + 1);
        LCounts[LFound].Key := LKey;
      end;
      Inc(LCounts[LFound].Observations,
        LModel.StateObservationCountAt(LIndex) * AWeights[LSide]);
      Inc(LCounts[LFound].Starts, LModel.StartCountAt(LIndex) * AWeights[LSide]);
      Inc(LCounts[LFound].Ends, LModel.EndCountAt(LIndex) * AWeights[LSide]);
    end;
  end;
  { Canonical palette-token and state ordering makes counted results independent
    of the parents' public-token ordering and associative grouping. }
  LTokens := nil;
  for LToken := 0 to High(LUsed) do
  begin
    LTokenMap[LToken] := -1;
    if LUsed[LToken] then
    begin
      LTokenMap[LToken] := Length(LTokens);
      SetLength(LTokens, Length(LTokens) + 1);
      LTokens[High(LTokens)] := AcousticToken(LToken);
    end;
  end;
  for LIndex := 1 to High(LCounts) do
  begin
    LValue := LCounts[LIndex];
    LOther := LIndex - 1;
    while (LOther >= 0) and (LCounts[LOther].Key > LValue.Key) do
    begin
      LCounts[LOther + 1] := LCounts[LOther];
      Dec(LOther);
    end;
    LCounts[LOther + 1] := LValue;
  end;
  SetLength(LStates, Length(LCounts));
  SetLength(LStateCounts, Length(LCounts));
  SetLength(LStarts, Length(LCounts));
  SetLength(LEnds, Length(LCounts));
  for LIndex := 0 to High(LCounts) do
  begin
    LKey := LCounts[LIndex].Key;
    LStates[LIndex].EmittedTokenIndex := LTokenMap[LKey mod 33];
    LKey := LKey div 33;
    SetLength(LStates[LIndex].History, AParents[0].Model.Order - 1);
    for LPosition := High(LStates[LIndex].History) downto 0 do
    begin
      LToken := LKey mod 33;
      LKey := LKey div 33;
      if LToken = 32 then
      begin
        LStates[LIndex].History[LPosition] := MakeWfcSequenceBosHistoryItem;
      end
      else
      begin
        LStates[LIndex].History[LPosition] :=
          MakeWfcSequenceTokenHistoryItem(LTokenMap[LToken]);
      end;
    end;
    LStateCounts[LIndex] := LCounts[LIndex].Observations;
    LStarts[LIndex] := LCounts[LIndex].Starts;
    LEnds[LIndex] := LCounts[LIndex].Ends;
  end;
  LLength := 0;
  for LSource in ASources do
  begin
    Inc(LLength, LSource.Multiplicity);
  end;
  SetLength(LLengths, LLength);
  LIndex := 0;
  for LSource in ASources do
  begin
    for LRepeat := 1 to LSource.Multiplicity do
    begin
      LLengths[LIndex] := LSource.FeatureCount;
      Inc(LIndex);
    end;
  end;
  Result := TWfcSequenceModel.Create(AParents[0].Model.Order, LLengths,
    LTokens, LStates, LStateCounts, LStarts, LEnds, wmbOpen);
end;

function BlendedContextJson(const AParents: TProfilePair; const AWeights: TWeightPair;
  const AMaps: TSourceMaps; const ASources: TProfileSources;
  const ACandidates: TJournalRepresentatives; const ABins: Integer): TJSONObject;
var
  LContexts: TJournalContextSets;
  LSources: TJournalContextSources;
  LWindows: TJournalContextWindows;
  LFallback: TJournalCandidatePool;
  LPool: TJournalContextPool;
  LSide: Integer;
  LIndex: Integer;
  LOther: Integer;
  LOffset: Integer;
  LFound: Integer;
  LPreviousLength: Integer;
  LWindowCount: Integer;
begin
  Result := nil;
  LContexts := nil;
  LWindowCount := 0;
  for LSide := 0 to 1 do
  begin
    if (AWeights[LSide] = 0) or (AParents[LSide].Contexts = nil) then
    begin
      Continue;
    end;
    for LIndex := 0 to AParents[LSide].Contexts.Count - 1 do
    begin
      SetLength(LWindows, AParents[LSide].Contexts.ContextLength(LIndex));
      for LOffset := 0 to High(LWindows) do
      begin
        LWindows[LOffset] := AParents[LSide].Contexts.WindowAt(LIndex, LOffset);
        LWindows[LOffset].Candidate.SegmentIndex :=
          AMaps[LSide][LWindows[LOffset].Candidate.SegmentIndex];
      end;
      LFound := -1;
      for LOther := 0 to High(LContexts) do
      begin
        if (LContexts[LOther][0].Candidate.SegmentIndex = LWindows[0].Candidate.SegmentIndex) and
          (LContexts[LOther][0].Candidate.FeatureIndex = LWindows[0].Candidate.FeatureIndex) then
        begin
          LFound := LOther;
          Break;
        end;
      end;
      if LFound < 0 then
      begin
        if Length(LContexts) = MaximumJournalContexts then
        begin
          raise EAudio.Create('Blended contexts exceed anchor budget');
        end;
        LFound := Length(LContexts);
        SetLength(LContexts, LFound + 1);
      end;
      LPreviousLength := Length(LContexts[LFound]);
      if Length(LWindows) > LPreviousLength then
      begin
        if Length(LWindows) - LPreviousLength > MaximumJournalContextWindows - LWindowCount then
        begin
          raise EAudio.Create('Blended contexts exceed window budget');
        end;
        Inc(LWindowCount, Length(LWindows) - LPreviousLength);
        SetLength(LContexts[LFound], Length(LWindows));
      end;
      for LOffset := 0 to High(LWindows) do
      begin
        if LOffset < LPreviousLength then
        begin
          if (LContexts[LFound][LOffset].Token <> LWindows[LOffset].Token) or
            (LContexts[LFound][LOffset].Candidate.SourceFrame <> LWindows[LOffset].Candidate.SourceFrame) or
            (LContexts[LFound][LOffset].Candidate.ValidFrames <> LWindows[LOffset].Candidate.ValidFrames) then
          begin
            raise EAudio.Create('Repeated source context has conflicting tokens or geometry');
          end;
          LContexts[LFound][LOffset].Candidate.Distance := Min(
            LContexts[LFound][LOffset].Candidate.Distance, LWindows[LOffset].Candidate.Distance);
        end
        else
        begin
          LContexts[LFound][LOffset] := LWindows[LOffset];
        end;
      end;
    end;
  end;
  if Length(LContexts) = 0 then
  begin
    Exit;
  end;
  SetLength(LSources, Length(ASources));
  for LIndex := 0 to High(LSources) do
  begin
    LSources[LIndex].Binding := ASources[LIndex].Binding;
    LSources[LIndex].FirstFeature := ASources[LIndex].FirstFeature;
    LSources[LIndex].FeatureCount := ASources[LIndex].FeatureCount;
  end;
  LFallback := TJournalCandidatePool.CreateFromCandidates(AParents[0].Palette.Count,
    Length(ASources), ABins, ACandidates);
  LPool := nil;
  try
    LPool := TJournalContextPool.CreateFromContexts(AParents[0].Palette,
      LFallback, LSources, LContexts);
    Result := JournalContextJson(LPool);
  finally
    LPool.Free;
    LFallback.Free;
  end;
end;

function BlendJournalProfiles(const ALeft, ARight: TJournalModelProfile;
  const ALeftWeight, ARightWeight: Integer): TJournalModelProfile;
var
  LParents: TProfilePair;
  LWeights: TWeightPair;
  LMaps: TSourceMaps;
  LSources: TProfileSources;
  LSource: TJournalProfileSource;
  LCandidates: TJournalRepresentatives;
  LCandidate: TJournalRepresentative;
  LLineage: TJournalProfileContributions;
  LDirect: TJournalProfileContributions;
  LInherited: TJournalProfileContributions;
  LContribution: TJournalProfileContribution;
  LModel: TWfcSequenceModel;
  LRoot: TJSONObject;
  LContextJson: TJSONObject;
  LRow: TJSONObject;
  LArray: TJSONArray;
  LVectorJson: TJSONArray;
  LVector: TAcousticVector;
  LModelText: UTF8String;
  LModelHash: String;
  LSide: Integer;
  LIndex: Integer;
  LOther: Integer;
  LFound: Integer;
  LSlot: Integer;
  LTarget: Integer;
  LToken: Integer;
  LComponent: Integer;
  LBins: Integer;
  LRaw: Int64;
  LWeighted: Int64;
  LSamples: Int64;
begin
  Result := nil;
  if (ALeft = nil) or (ARight = nil) or
    (ALeftWeight < 0) or (ALeftWeight > 64) or
    (ARightWeight < 0) or (ARightWeight > 64) or
    (ALeftWeight + ARightWeight = 0) then
  begin
    raise EAudio.Create('Blend requires two profiles and active integer weights 0..64');
  end;
  ALeft.RequireCompatible(ARight);
  LBins := ALeft.Pool.BinsPerSegment;
  if LBins <> ARight.Pool.BinsPerSegment then
  begin
    raise EAudio.Create('Blend candidate bin policies differ');
  end;
  LWeighted := Int64(ALeft.Model.ObservationCount) * ALeftWeight +
    Int64(ARight.Model.ObservationCount) * ARightWeight;
  LSamples := Int64(ALeft.Model.SampleCount) * ALeftWeight +
    Int64(ARight.Model.SampleCount) * ARightWeight;
  if (LWeighted > High(Integer)) or (LSamples > WFC_SEQUENCE_MAX_SAMPLE_COUNT) then
  begin
    raise EAudio.Create('Blend evidence exceeds companion count/sample budgets');
  end;
  LParents[0] := ALeft;
  LParents[1] := ARight;
  LWeights[0] := ALeftWeight;
  LWeights[1] := ARightWeight;
  LSources := nil;
  LLineage := nil;
  LDirect := nil;
  for LSide := 0 to 1 do
  begin
    if LWeights[LSide] = 0 then
    begin
      Continue;
    end;
    LContribution.ProfileSha256 := TextDigest(LParents[LSide].EncodeReport);
    LContribution.ModelSha256 := LParents[LSide].ModelSha256;
    LContribution.Weight := LWeights[LSide];
    AddContribution(LDirect, LContribution);
    LInherited := LParents[LSide].CopyTrainingLineage;
    for LIndex := 0 to High(LInherited) do
    begin
      LContribution := LInherited[LIndex];
      LContribution.Weight := LContribution.Weight * LWeights[LSide];
      AddContribution(LLineage, LContribution);
    end;
    SetLength(LMaps[LSide], LParents[LSide].SourceCount);
    for LIndex := 0 to LParents[LSide].SourceCount - 1 do
    begin
      LSource := LParents[LSide].SourceAt(LIndex);
      LFound := -1;
      for LOther := 0 to High(LSources) do
      begin
        if LSource.Binding.SourceSha256 <> LSources[LOther].Binding.SourceSha256 then
        begin
          Continue;
        end;
        if LSource.Binding.FrameCount <> LSources[LOther].Binding.FrameCount then
        begin
          raise EAudio.Create('Blend repeated source has conflicting geometry');
        end;
        if (LSource.FirstFeature = LSources[LOther].FirstFeature) and
          (LSource.FeatureCount = LSources[LOther].FeatureCount) then
        begin
          if LSource.CacheSha256 <> LSources[LOther].CacheSha256 then
          begin
            raise EAudio.Create('Blend repeated source range has conflicting cache identity');
          end;
          LFound := LOther;
          Break;
        end;
        if (LSource.FirstFeature < LSources[LOther].FirstFeature + LSources[LOther].FeatureCount) and
          (LSources[LOther].FirstFeature < LSource.FirstFeature + LSource.FeatureCount) then
        begin
          raise EAudio.Create('Blend source ranges partially overlap; normalize evidence first');
        end;
      end;
      if LFound < 0 then
      begin
        if Length(LSources) = 32 then
        begin
          raise EAudio.Create('Blend exceeds 32 distinct source ranges');
        end;
        LFound := Length(LSources);
        SetLength(LSources, LFound + 1);
        LSources[LFound] := LSource;
        LSources[LFound].Multiplicity := 0;
      end;
      Inc(LSources[LFound].Multiplicity, LSource.Multiplicity * LWeights[LSide]);
      LMaps[LSide][LIndex] := LFound;
    end;
  end;
  SetLength(LCandidates, ALeft.Palette.Count * Length(LSources) * LBins);
  for LSide := 0 to 1 do
  begin
    if LWeights[LSide] = 0 then
    begin
      Continue;
    end;
    for LSlot := 0 to LParents[LSide].Pool.SlotCount - 1 do
    begin
      LCandidate := LParents[LSide].Pool.CandidateAt(LSlot);
      if not LCandidate.Found then
      begin
        Continue;
      end;
      LToken := LParents[LSide].Pool.TokenAt(LSlot);
      LCandidate.SegmentIndex := LMaps[LSide][LCandidate.SegmentIndex];
      LTarget := (LToken * Length(LSources) + LCandidate.SegmentIndex) * LBins + LSlot mod LBins;
      if not LCandidates[LTarget].Found or
        (LCandidate.Distance < LCandidates[LTarget].Distance) or
        ((LCandidate.Distance = LCandidates[LTarget].Distance) and
        (LCandidate.FeatureIndex < LCandidates[LTarget].FeatureIndex)) then
      begin
        LCandidates[LTarget] := LCandidate;
      end;
    end;
  end;
  LModel := CombineCounts(LParents, LWeights, LSources);
  LRoot := nil;
  try
    LModelText := EncodeWfcSequenceText(LModel);
    LModelHash := TextDigest(LModelText);
    LRoot := TJSONObject.Create;
    LRoot.Add('contract', 'pythian.acoustic.journal-learning');
    LRoot.Add('analysis_version', AnalysisVersion);
    LRoot.Add('learning_version', AcousticLearningVersion);
    LRoot.Add('sample_rate', ALeft.SampleRate);
    LRoot.Add('channels', ALeft.Channels);
    LRoot.Add('window_frames', ALeft.Options.WindowFrames);
    LRoot.Add('hop_frames', ALeft.Options.HopFrames);
    LRoot.Add('silence_rms', ALeft.Options.SilenceRms);
    LRoot.Add('order', LModel.Order);
    LRoot.Add('wfc_states', LModel.StateCount);
    LRoot.Add('wfc_observations', LModel.ObservationCount);
    LRoot.Add('wfc_samples', LModel.SampleCount);
    LRoot.Add('weighted_observations', LWeighted);
    LRaw := 0;
    for LSource in LSources do
    begin
      Inc(LRaw, LSource.FeatureCount);
    end;
    LRoot.Add('raw_observations', LRaw);
    LRoot.Add('vocabulary_sha256', ALeft.VocabularySha256);
    LRoot.Add('model_sha256', LModelHash);
    LRoot.Add('model_binding_sha256',
      AcousticModelBindingSha256(ALeft.VocabularySha256, LModelHash));
    LRoot.Add('candidate_bins_per_segment', LBins);
    LRoot.Add('blend_parents', ContributionJson(LDirect));
    LRoot.Add('training_lineage', ContributionJson(LLineage));
    LRoot.Add('policy', 'Integer evidence multiplication and addition; exact repeated ranges coalesce; no duration normalization; independent generation weights; no semantic style acceptance');
    LArray := TJSONArray.Create;
    LRoot.Add('palette', LArray);
    for LToken := 0 to ALeft.Palette.Count - 1 do
    begin
      LVector := ALeft.Palette.CenterAt(LToken);
      LVectorJson := TJSONArray.Create;
      LArray.Add(LVectorJson);
      for LComponent := 0 to High(LVector) do
      begin
        LVectorJson.Add(LVector[LComponent]);
      end;
    end;
    LArray := TJSONArray.Create;
    LRoot.Add('sources', LArray);
    for LSource in LSources do
    begin
      LRow := TJSONObject.Create;
      LArray.Add(LRow);
      LRow.Add('source', LSource.Name);
      LRow.Add('source_sha256', LSource.Binding.SourceSha256);
      LRow.Add('cache_sha256', LSource.CacheSha256);
      LRow.Add('source_frames', LSource.Binding.FrameCount);
      LRow.Add('first_feature', LSource.FirstFeature);
      LRow.Add('observations', LSource.FeatureCount);
      LRow.Add('multiplicity', LSource.Multiplicity);
      LRow.Add('generation_weight', 1);
    end;
    LArray := TJSONArray.Create;
    LRoot.Add('candidates', LArray);
    for LSlot := 0 to High(LCandidates) do
    begin
      LCandidate := LCandidates[LSlot];
      if not LCandidate.Found then
      begin
        Continue;
      end;
      LRow := TJSONObject.Create;
      LArray.Add(LRow);
      LRow.Add('slot', LSlot);
      LRow.Add('token', LSlot div (Length(LSources) * LBins));
      LRow.Add('source_index', LCandidate.SegmentIndex);
      LRow.Add('feature_index', LCandidate.FeatureIndex);
      LRow.Add('source_frame', LCandidate.SourceFrame);
      LRow.Add('valid_frames', LCandidate.ValidFrames);
      LRow.Add('center_distance', LCandidate.Distance);
    end;
    LContextJson := BlendedContextJson(LParents, LWeights, LMaps, LSources, LCandidates, LBins);
    if LContextJson <> nil then
    begin
      LRoot.Add('source_contexts', LContextJson);
    end;
    Result := TJournalModelProfile.Create(LRoot.FormatJSON, LModelText);
  finally
    LRoot.Free;
    LModel.Free;
  end;
end;

end.
