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

program pythian_tests_learning_journal;

{$mode delphi}
{$H+}

uses
  Classes,
  SysUtils,
  Math,
  pythian.audio,
  pythian.granular,
  pythian.analysis,
  pythian.analysis.wave,
  pythian.analysis.journal,
  pythian.learning,
  pythian.learning.journal,
  pythian.learning.selection,
  pythian.learning.continuity,
  pythian.learning.context,
  pythian.wfc.learning,
  pythian.wfc.learning.journal,
  wfc_sequence,
  wfc_sequence_text;

type
  TJoinFixtureSource = class
    Reads: Integer;
    function ReadWindow(const ACandidate: TJournalRepresentative): TAudioSamples;
  end;

  TMemoryCommit = class(TMemoryStream)
    Reads: Integer;
    function Read(var ABuffer; ACount: LongInt): LongInt; override;
    procedure Commit;
  end;

function TJoinFixtureSource.ReadWindow(const ACandidate: TJournalRepresentative): TAudioSamples;
var
  LIndex: Integer;
begin
  Inc(Reads);
  Result := nil;
  SetLength(Result, ACandidate.ValidFrames);
  for LIndex := 0 to High(Result) do
  begin
    if ACandidate.SegmentIndex = 0 then
    begin
      Result[LIndex] := 0.5;
    end
    else
    begin
      Result[LIndex] := -0.5;
    end;
  end;
end;

procedure TMemoryCommit.Commit;
begin
end;

function TMemoryCommit.Read(var ABuffer; ACount: LongInt): LongInt;
begin
  Inc(Reads);
  Result := inherited Read(ABuffer, ACount);
end;

procedure Check(const ACondition: Boolean; const AMessage: String);
begin
  if not ACondition then
  begin
    raise Exception.Create(AMessage);
  end;
end;

procedure CheckContextBoundaries;
var
  LSource: TJoinFixtureSource;
  LInput: TJournalContextWindows;
  LPlan: TJournalContextWindows;
  LReplay: TJournalContextWindows;
  LLocks: TJournalContextLocks;
  LOptions: TJournalContextJoinOptions;
  LReport: TJournalContextJoinReport;
  LReplayReport: TJournalContextJoinReport;
  LProbe: TGrainJoinProbe;
  LSamples: TAudioSamples;
  LIndex: Integer;
  LOther: Integer;
  LMatches: Integer;
  LSwitches: Integer;
  LRejected: Boolean;
begin
  LSource := TJoinFixtureSource.Create;
  try
    SetLength(LInput, 16);
    SetLength(LLocks, 16);
    for LIndex := 0 to High(LInput) do
    begin
      LInput[LIndex].Token := LIndex mod 2;
      LInput[LIndex].Candidate.Found := True;
      LInput[LIndex].Candidate.SegmentIndex := (LIndex div 2) mod 2;
      LInput[LIndex].Candidate.SourceFrame := (LIndex div 2) * 128 + (LIndex mod 2) * 32;
      LInput[LIndex].Candidate.FeatureIndex := LInput[LIndex].Candidate.SourceFrame div 32;
      LInput[LIndex].Candidate.ValidFrames := 64;
      LInput[LIndex].Candidate.Distance := (LIndex + 1) / 32;
    end;
    LLocks[0] := True;
    LLocks[15] := True;
    LOptions := DefaultJournalContextJoinOptions;
    LPlan := PlanJournalContextJoins(LInput, LLocks, LSource.ReadWindow,
      64, 32, 1, LOptions, LReport);
    Check((LReport.ChunkCount = 8) and (LReport.AcceptedSwaps > 0) and
      (LSource.Reads = 16), 'Whole-chunk boundary refinement reads each coordinate once and edits');
    LReplay := PlanJournalContextJoins(LInput, LLocks, LSource.ReadWindow,
      64, 32, 1, LOptions, LReplayReport);
    LSwitches := 0;
    for LIndex := 0 to High(LPlan) do
    begin
      Check(LPlan[LIndex].Token = LInput[LIndex].Token, 'Chunk swaps retain exact token positions');
      Check((LPlan[LIndex].Candidate.SourceFrame = LReplay[LIndex].Candidate.SourceFrame) and
        (LPlan[LIndex].Candidate.SegmentIndex = LReplay[LIndex].Candidate.SegmentIndex),
        'Boundary refinement replays exactly');
      Check(LInput[LIndex].Candidate.SourceFrame =
        (LIndex div 2) * 128 + (LIndex mod 2) * 32, 'Boundary refinement leaves input unchanged');
      LMatches := 0;
      for LOther := 0 to High(LInput) do
      begin
        if (LPlan[LIndex].Candidate.SourceFrame = LInput[LOther].Candidate.SourceFrame) and
          (LPlan[LIndex].Candidate.SegmentIndex = LInput[LOther].Candidate.SegmentIndex) then
        begin
          Inc(LMatches);
          Check(LPlan[LIndex].Candidate.Distance = LInput[LOther].Candidate.Distance,
            'Selected observation metadata travels with its window');
        end;
      end;
      Check(LMatches = 1, 'Every refined window is an original observation');
      LMatches := 0;
      for LOther := 0 to High(LPlan) do
      begin
        if (LPlan[LOther].Candidate.SourceFrame = LInput[LIndex].Candidate.SourceFrame) and
          (LPlan[LOther].Candidate.SegmentIndex = LInput[LIndex].Candidate.SegmentIndex) then
        begin
          Inc(LMatches);
        end;
      end;
      Check(LMatches = 1, 'Every input window multiplicity is retained');
      if LLocks[LIndex] then
      begin
        Check((LPlan[LIndex].Candidate.SourceFrame = LInput[LIndex].Candidate.SourceFrame) and
          (LPlan[LIndex].Candidate.Distance = LInput[LIndex].Candidate.Distance),
          'Boundary refinement preserves locked observations');
      end;
      if (LIndex > 0) and
        (LPlan[LIndex - 1].Candidate.SegmentIndex <> LPlan[LIndex].Candidate.SegmentIndex) then
      begin
        Inc(LSwitches);
      end;
    end;
    Check((LSwitches < 7) and (LReport.After.RepeatedWindows = 0) and
      (Abs(LReport.Before.MeanSeamError - 14 / 15) < 1E-12) and
      (Abs(LReport.After.MeanSeamError - 2 * LSwitches / 15) < 1E-12) and
      (LReport.After.MeanAssembledSeamError < LReport.Before.MeanAssembledSeamError),
      Format('Independent constant oracle: switches=%d repeats=%d before=%.15f after=%.15f assembled=%.15f -> %.15f',
        [LSwitches, LReport.After.RepeatedWindows, LReport.Before.MeanSeamError,
        LReport.After.MeanSeamError, LReport.Before.MeanAssembledSeamError,
        LReport.After.MeanAssembledSeamError]));
    for LIndex := 0 to High(LInput) do
    begin
      LInput[LIndex].Token := LIndex;
    end;
    LPlan := PlanJournalContextJoins(LInput, nil, LSource.ReadWindow,
      64, 32, 1, LOptions, LReport);
    Check(LReport.AcceptedSwaps = 0, 'Incompatible token sequences cannot exchange chunks');
    for LIndex := 0 to High(LInput) do
    begin
      Check((LPlan[LIndex].Token = LInput[LIndex].Token) and
        (LPlan[LIndex].Candidate.SourceFrame = LInput[LIndex].Candidate.SourceFrame),
        'No compatible proposal leaves the exact path intact');
    end;
    SetLength(LInput, 2);
    SetLength(LLocks, 2);
    LLocks[0] := True;
    LLocks[1] := True;
    LInput[1] := LInput[0];
    LInput[1].Candidate.Distance := 0.75;
    LSource.Reads := 0;
    LPlan := PlanJournalContextJoins(LInput, LLocks, LSource.ReadWindow,
      64, 32, 1, LOptions, LReport);
    Check((LSource.Reads = 1) and (LPlan[1].Candidate.Distance = 0.75) and
      (LReport.AcceptedSwaps = 0), 'Probe deduplication retains distinct locked metadata');
    SetLength(LSamples, 2);
    LSamples[0] := 0.25;
    LSamples[1] := 0.5;
    LProbe := ExtractGrainJoinProbe(LSamples, 4, 2, 1, 2);
    Check((LProbe.Incoming[0] = 0.25) and (LProbe.Incoming[1] = 0.5) and
      (LProbe.Outgoing[0] = 0) and (LProbe.Outgoing[1] = 0),
      'Shared overlap probes pad partial EOF exactly');
    LProbe := ExtractGrainJoinProbe(LSamples, 2, 2, 1, 64);
    Check((Length(LProbe.Incoming) = 1) and (LProbe.Outgoing[0] = 0.5),
      'Nonoverlapping grains compare actual endpoints');
    SetLength(LInput, MaximumJournalSelectionGrains);
    for LIndex := 0 to High(LInput) do
    begin
      LInput[LIndex] := LInput[0];
      LInput[LIndex].Candidate.SourceFrame := LIndex * 128;
    end;
    LOptions.SwapRadius := 64;
    LSource.Reads := 0;
    LRejected := False;
    try
      LPlan := PlanJournalContextJoins(LInput, nil, LSource.ReadWindow,
        64, 32, 1, LOptions, LReport);
    except
      on EAudio do
      begin
        LRejected := True;
      end;
    end;
    Check(LRejected and (LSource.Reads = 0), 'Boundary work budget rejects before source reads');
    WriteLn('Context boundary swaps, exact windows/tokens/locks, independent costs and probe boundaries PASS');
  finally
    LSource.Free;
  end;
end;

procedure CheckJoins(const APool: TJournalCandidatePool; const AInitial: TAcousticIndices);
var
  LSource: TJoinFixtureSource;
  LPlanner: TJournalJoinPlanner;
  LOptions: TJournalJoinOptions;
  LBefore: TJournalJoinReport;
  LAfter: TJournalJoinReport;
  LPlan: TAcousticIndices;
  LReplay: TAcousticIndices;
  LLocks: TJournalSelectionLocks;
  LCounts: array of Integer;
  LOriginal: TAcousticIndices;
  LTooLong: TAcousticIndices;
  LRejected: Boolean;
  LIndex: Integer;
  LReads: Integer;
begin
  LSource := TJoinFixtureSource.Create;
  LOriginal := Copy(AInitial);
  LPlanner := nil;
  try
    LOptions := DefaultJournalJoinOptions;
    LOptions.CenterWeight := 0;
    LPlanner := TJournalJoinPlanner.Create(APool, LSource.ReadWindow, 64, 32, 1, LOptions);
    LReads := LSource.Reads;
    LBefore := LPlanner.Evaluate(AInitial);
    SetLength(LLocks, Length(AInitial));
    LLocks[0] := True;
    LLocks[High(LLocks)] := True;
    LPlan := LPlanner.Plan(AInitial, LLocks, LAfter);
    Check((LAfter.TotalCost < LBefore.TotalCost) and
      (LAfter.SourceSwitches < LBefore.SourceSwitches) and
      (LAfter.MeanSeamError < LBefore.MeanSeamError),
      'Opposite-constant joins and switching improve from independently scored baseline');
    Check((LAfter.RepeatedWindows <= LBefore.RepeatedWindows) and
      (LPlan[0] = AInitial[0]) and (LPlan[High(LPlan)] = AInitial[High(AInitial)]),
      'Join planning preserves locks and initial repeat ceiling');
    SetLength(LCounts, APool.SlotCount div APool.BinsPerSegment);
    for LIndex := 0 to High(LPlan) do
    begin
      Check(APool.TokenAt(LPlan[LIndex]) = APool.TokenAt(AInitial[LIndex]),
        'Join planning preserves every token');
      Inc(LCounts[LPlan[LIndex] div APool.BinsPerSegment]);
      Dec(LCounts[AInitial[LIndex] div APool.BinsPerSegment]);
    end;
    for LIndex := 0 to High(LCounts) do
    begin
      Check(LCounts[LIndex] = 0, 'Join planning preserves per-token/segment contribution');
    end;
    LReplay := LPlanner.Plan(AInitial, LLocks, LAfter);
    for LIndex := 0 to High(LPlan) do
    begin
      Check(LPlan[LIndex] = LReplay[LIndex], 'Join planning replays without waveform rereads');
      LLocks[LIndex] := True;
    end;
    LReplay := LPlanner.Plan(AInitial, LLocks, LAfter);
    for LIndex := 0 to High(LReplay) do
    begin
      Check(LReplay[LIndex] = AInitial[LIndex], 'All locked windows remain exact');
      Check(AInitial[LIndex] = LOriginal[LIndex], 'Join planning leaves caller selection untouched');
    end;
    SetLength(LTooLong, 512);
    for LIndex := 0 to High(LTooLong) do
    begin
      LTooLong[LIndex] := AInitial[LIndex mod Length(AInitial)];
    end;
    LRejected := False;
    try
      LReplay := LPlanner.Plan(LTooLong, nil, LAfter);
    except
      on EAudio do
      begin
        LRejected := True;
      end;
    end;
    Check(LRejected and (LAfter.GrainCount = 0), 'Oversized join search rejects before planning');
    Check(LSource.Reads = LReads, 'Planning retains probes rather than rereading audio');
    FreeAndNil(LPlanner);
    LOptions.SwapRadius := 4;
    LPlanner := TJournalJoinPlanner.Create(APool, LSource.ReadWindow, 64, 32, 1, LOptions);
    LReads := LSource.Reads;
    SetLength(LTooLong, 1024);
    for LIndex := 0 to High(LTooLong) do
    begin
      LTooLong[LIndex] := AInitial[LIndex mod Length(AInitial)];
    end;
    SetLength(LLocks, Length(LTooLong));
    for LIndex := 0 to High(LLocks) do
    begin
      LLocks[LIndex] := LIndex mod 17 = 0;
    end;
    LBefore := LPlanner.Evaluate(LTooLong);
    LPlan := LPlanner.Plan(LTooLong, LLocks, LAfter);
    Check((LAfter.TotalCost <= LBefore.TotalCost) and
      (LAfter.RepeatedWindows <= LBefore.RepeatedWindows) and
      (LAfter.ProbeWorkBound > 0) and (LAfter.ProbeWorkBound <= 64000000),
      'Local swaps admit sustained planning within unchanged cost/repeat/work bounds');
    for LIndex := 0 to High(LCounts) do
    begin
      LCounts[LIndex] := 0;
    end;
    for LIndex := 0 to High(LPlan) do
    begin
      Check(APool.TokenAt(LPlan[LIndex]) = APool.TokenAt(LTooLong[LIndex]),
        'Local planning preserves generated tokens');
      Check(not LLocks[LIndex] or (LPlan[LIndex] = LTooLong[LIndex]),
        'Local planning preserves sparse locks');
      Inc(LCounts[LPlan[LIndex] div APool.BinsPerSegment]);
      Dec(LCounts[LTooLong[LIndex] div APool.BinsPerSegment]);
    end;
    for LIndex := 0 to High(LCounts) do
    begin
      Check(LCounts[LIndex] = 0, 'Local planning preserves every token/source count');
    end;
    LReplay := LPlanner.Plan(LTooLong, LLocks, LAfter);
    for LIndex := 0 to High(LPlan) do
    begin
      Check(LReplay[LIndex] = LPlan[LIndex], 'Sustained local planning replays exactly');
    end;
    Check(LSource.Reads = LReads, 'Local planning does not reread waveforms');
  finally
    LPlanner.Free;
    LSource.Free;
  end;
end;

procedure CheckContexts(const AReader: TJournalTrainingReader;
  const APalette: TAcousticPalette; const APool: TJournalCandidatePool;
  const AFeatures: TAudioFeatures);
var
  LContexts: TJournalContextPool;
  LOptions: TJournalContextOptions;
  LReport: TJournalContextReport;
  LReplayReport: TJournalContextReport;
  LPlan: TJournalContextWindows;
  LReplay: TJournalContextWindows;
  LWindow: TJournalContextWindow;
  LSource: TJournalContextSource;
  LTokens: TAcousticIndices;
  LInitial: TAcousticIndices;
  LWeights: TJournalSelectionWeights;
  LLocks: TJournalContextLocks;
  LCounts: array of Integer;
  LAudio: TJoinFixtureSource;
  LRendered: TAudioClip;
  LReference: TAudioClip;
  LIndex: Integer;
  LOffset: Integer;
  LFeature: Integer;
  LRejected: Boolean;
begin
  LContexts := TJournalContextPool.Create(AReader, APalette, APool, 8);
  LAudio := TJoinFixtureSource.Create;
  LRendered := nil;
  LReference := nil;
  try
    Check(LContexts.WindowCount <= MaximumJournalContextWindows, 'Context storage is bounded');
    for LIndex := 0 to LContexts.Count - 1 do
    begin
      LWindow := LContexts.WindowAt(LIndex, 0);
      LSource := LContexts.SourceAt(LWindow.Candidate.SegmentIndex);
      for LOffset := 0 to LContexts.ContextLength(LIndex) - 1 do
      begin
        LWindow := LContexts.WindowAt(LIndex, LOffset);
        LFeature := LWindow.Candidate.FeatureIndex;
        Check((LFeature >= LSource.FirstFeature) and
          (LFeature < LSource.FirstFeature + LSource.FeatureCount),
          'Context stops at declared recording boundaries');
        Check((LWindow.Token = APalette.EncodeFeature(AFeatures[LFeature])) and
          (LWindow.Candidate.SourceFrame = LFeature * 64),
          'Every retained context window matches independent source observations');
        Check(LFeature = LContexts.WindowAt(LIndex, 0).Candidate.FeatureIndex + LOffset,
          'Context windows follow consecutive source observations');
      end;
    end;
    SetLength(LTokens, 96);
    for LIndex := 0 to High(LTokens) do
    begin
      LTokens[LIndex] := APalette.EncodeFeature(AFeatures[LIndex mod 18]);
    end;
    SetLength(LWeights, 3);
    LWeights[0] := 1;
    LWeights[1] := 1;
    LWeights[2] := 0;
    LInitial := APool.Select(LTokens, LWeights);
    SetLength(LLocks, Length(LTokens));
    LLocks[0] := True;
    LLocks[15] := True;
    LLocks[High(LLocks)] := True;
    LOptions := DefaultJournalContextOptions;
    LOptions.MaximumContextUses := 3;
    LPlan := LContexts.Plan(LInitial, LLocks, LOptions, LReport);
    LReplay := LContexts.Plan(LInitial, LLocks, LOptions, LReplayReport);
    Check(not LReport.Reverted and (LReport.ContextGrains > 0) and
      (LReport.ContiguousLinks > 0), 'Supported contexts are actually selected');
    Check(LReport.ContextRuns <= LContexts.Count * 3, 'Context-start reuse cap holds');
    SetLength(LCounts, APalette.Count * APool.SegmentCount);
    for LIndex := 0 to High(LPlan) do
    begin
      Inc(LCounts[LTokens[LIndex] * 3 + APool.CandidateAt(LInitial[LIndex]).SegmentIndex]);
      Dec(LCounts[LPlan[LIndex].Token * 3 + LPlan[LIndex].Candidate.SegmentIndex]);
      Check((LPlan[LIndex].Token = LTokens[LIndex]) and
        (LPlan[LIndex].Candidate.SegmentIndex <> 2), 'Context preserves tokens and disabled source');
      Check((LPlan[LIndex].Candidate.SourceFrame = LReplay[LIndex].Candidate.SourceFrame) and
        (LPlan[LIndex].Candidate.SegmentIndex = LReplay[LIndex].Candidate.SegmentIndex),
        'Context selection replays exactly');
      if LLocks[LIndex] then
      begin
        Check((LPlan[LIndex].Candidate.SourceFrame = APool.CandidateAt(LInitial[LIndex]).SourceFrame) and
          (LPlan[LIndex].Candidate.SegmentIndex = APool.CandidateAt(LInitial[LIndex]).SegmentIndex),
          'Context planning preserves exact locked source windows');
      end;
    end;
    for LIndex in LCounts do
    begin
      Check(LIndex = 0, 'Context preserves exact per-token/source contributions');
    end;
    LRendered := RenderJournalContexts(LPlan, LAudio.ReadWindow, 8000, 1, 64, 32);
    Check(LRendered.FrameCount = (Length(LPlan) - 1) * 32 + 64,
      'Context rendering preserves the overlap-add clock');
    FreeAndNil(LRendered);
    LOptions.MaximumRunGrains := 1;
    LPlan := LContexts.Plan(LInitial, LLocks, LOptions, LReport);
    LRendered := RenderJournalContexts(LPlan, LAudio.ReadWindow, 8000, 1, 64, 32);
    LReference := RenderJournalSelection(APool, LInitial, LAudio.ReadWindow, 8000, 1, 64, 32);
    for LIndex := 0 to LReference.FrameCount - 1 do
    begin
      Check(LReference.SampleAt(LIndex, 0) = LRendered.SampleAt(LIndex, 0),
        'Disabled context rendering exactly matches existing selection renderer');
    end;
    FreeAndNil(LRendered);
    FreeAndNil(LReference);
    LOptions := DefaultJournalContextOptions;
    for LIndex := 0 to High(LLocks) do
    begin
      LLocks[LIndex] := True;
    end;
    LPlan := LContexts.Plan(LInitial, LLocks, LOptions, LReport);
    Check(LReport.ContextGrains = 0, 'Fully locked selection remains fallback-only');
    SetLength(LPlan, 1);
    LPlan[0].Candidate.ValidFrames := 7;
    LRendered := RenderJournalContexts(LPlan, LAudio.ReadWindow, 8000, 1, 64, 32);
    Check((LRendered.FrameCount = 64) and (LRendered.SampleAt(20, 0) = 0),
      'Partial EOF context is padded without shortening output clock');
    SetLength(LTokens, 64);
    SetLength(LLocks, 64);
    for LIndex := 0 to High(LTokens) do
    begin
      LTokens[LIndex] := APalette.EncodeFeature(AFeatures[0]);
      LLocks[LIndex] := False;
    end;
    LLocks[0] := True;
    LLocks[High(LLocks)] := True;
    LWeights[0] := 1;
    LWeights[1] := 0;
    LWeights[2] := 1;
    LInitial := APool.Select(LTokens, LWeights);
    LPlan := LContexts.Plan(LInitial, LLocks, LOptions, LReport);
    Check(not LReport.Reverted and (LReport.RepairEdits > 0) and
      (LReport.RepeatedWindows = 0) and (LReport.ContextGrains > 0),
      'Equal-token swaps repair exhausted single-window source quotas without repeats');
    FillChar(LCounts[0], Length(LCounts) * SizeOf(Integer), 0);
    for LIndex := 0 to High(LPlan) do
    begin
      Check(LPlan[LIndex].Token = LTokens[LIndex], 'Quota repair preserves each token');
      Inc(LCounts[LTokens[LIndex] * 3 + APool.CandidateAt(LInitial[LIndex]).SegmentIndex]);
      Dec(LCounts[LPlan[LIndex].Token * 3 + LPlan[LIndex].Candidate.SegmentIndex]);
      if LLocks[LIndex] then
      begin
        Check((LPlan[LIndex].Candidate.SourceFrame = APool.CandidateAt(LInitial[LIndex]).SourceFrame) and
          (LPlan[LIndex].Candidate.SegmentIndex = APool.CandidateAt(LInitial[LIndex]).SegmentIndex),
          'Quota repair preserves locked windows');
      end;
    end;
    for LIndex in LCounts do
    begin
      Check(LIndex = 0, 'Quota repair preserves exact per-token/source counts');
    end;
    LOptions.MaximumRunGrains := 33;
    LRejected := False;
    try
      LReplay := LContexts.Plan(LInitial, LLocks, LOptions, LReport);
    except
      on EAudio do
      begin
        LRejected := True;
      end;
    end;
    Check(LRejected, 'Oversized context request rejects');
    LOptions := DefaultJournalContextOptions;
    SetLength(LInitial, MaximumJournalSelectionGrains);
    for LIndex := 0 to High(LInitial) do
    begin
      LInitial[LIndex] := 0;
    end;
    LRejected := False;
    try
      LReplay := LContexts.Plan(LInitial, nil, LOptions, LReport);
    except
      on EAudio do
      begin
        LRejected := True;
      end;
    end;
    Check(LRejected and (LReport.ContextRuns = 0),
      'Oversized repair-work bound rejects before publishing a selection');
  finally
    LReference.Free;
    LRendered.Free;
    LAudio.Free;
    LContexts.Free;
  end;
end;

procedure CheckSelection(const AReader: TJournalTrainingReader;
  const APalette: TAcousticPalette; const AFeatures: TAudioFeatures;
  var ABaseline: TJournalRepresentatives);
var
  LPool: TJournalCandidatePool;
  LTokens: TAcousticIndices;
  LSelected: TAcousticIndices;
  LReplay: TAcousticIndices;
  LVariant: TAcousticIndices;
  LWeights: TJournalSelectionWeights;
  LCandidate: TJournalRepresentative;
  LOther: TJournalRepresentative;
  LSegment: TJournalTrainingSegment;
  LCounts: array[0..2] of Integer;
  LIndex: Integer;
  LSlot: Integer;
  LBin: Integer;
  LWidth: Integer;
  LFeature: Integer;
  LFirst: Integer;
  LLast: Integer;
  LToken: Integer;
  LChanged: Boolean;
  LRejected: Boolean;
begin
  LPool := TJournalCandidatePool.Create(AReader, APalette, 4);
  try
    CheckContexts(AReader, APalette, LPool, AFeatures);
    Check(LPool.SlotCount = APalette.Count * 3 * 4, 'Bounded candidate geometry');
    for LSlot := 0 to LPool.SlotCount - 1 do
    begin
      LCandidate := LPool.CandidateAt(LSlot);
      if not LCandidate.Found then
      begin
        Continue;
      end;
      LSegment := AReader.SegmentAt(LCandidate.SegmentIndex);
      Check((LCandidate.FeatureIndex >= LSegment.FirstFeature) and
        (LCandidate.FeatureIndex < LSegment.FirstFeature + LSegment.FeatureCount),
        'Candidate stays inside declared segment');
      Check((LCandidate.SourceFrame = LCandidate.FeatureIndex * 64) and
        (LCandidate.ValidFrames = 64), 'Source coordinates retained');
      LToken := LPool.TokenAt(LSlot);
      Check(APalette.EncodeFeature(AFeatures[LCandidate.FeatureIndex]) = LToken,
        'Candidate preserves palette assignment');
      LWidth := (LSegment.FeatureCount - 1) div 4 + 1;
      LBin := LSlot mod 4;
      LFirst := LSegment.FirstFeature + LBin * LWidth;
      LLast := Min(LSegment.FirstFeature + LSegment.FeatureCount, LFirst + LWidth) - 1;
      Check((LCandidate.FeatureIndex >= LFirst) and (LCandidate.FeatureIndex <= LLast),
        'Candidate stays inside temporal bin');
      for LFeature := LFirst to LLast do
      begin
        if APalette.EncodeFeature(AFeatures[LFeature]) = LToken then
        begin
          Check(LCandidate.Distance <= APalette.FeatureDistance(AFeatures[LFeature], LToken),
            'Candidate is nearest assigned observation in its bin');
        end;
      end;
    end;
    SetLength(LTokens, 128);
    for LIndex := 0 to High(LTokens) do
    begin
      LTokens[LIndex] := APalette.EncodeFeature(AFeatures[0]);
    end;
    SetLength(LWeights, 3);
    LWeights[0] := 1;
    LWeights[1] := 3;
    LWeights[2] := 0;
    LSelected := LPool.Select(LTokens, LWeights, 731);
    LReplay := LPool.Select(LTokens, LWeights, 731);
    LVariant := LPool.Select(LTokens, LWeights, 732);
    FillChar(LCounts, SizeOf(LCounts), 0);
    LChanged := False;
    for LIndex := 0 to High(LSelected) do
    begin
      Check(LSelected[LIndex] = LReplay[LIndex], 'Selection replay is exact');
      LChanged := LChanged or (LSelected[LIndex] <> LVariant[LIndex]);
      LCandidate := LPool.CandidateAt(LSelected[LIndex]);
      Inc(LCounts[LCandidate.SegmentIndex]);
      Check(LPool.TokenAt(LSelected[LIndex]) = LTokens[LIndex], 'Selection preserves token');
      if LIndex > 0 then
      begin
        Check(LSelected[LIndex] <> LSelected[LIndex - 1],
          'Multiple eligible windows avoid immediate repetition');
      end;
      if Length(ABaseline) > 0 then
      begin
        LOther := ABaseline[LIndex];
        Check((LCandidate.SourceFrame = LOther.SourceFrame) and
          (LCandidate.SegmentIndex = LOther.SegmentIndex),
          'Stored batch geometry does not change selected windows');
      end;
    end;
    Check(LChanged, 'Independent selection seed changes windows');
    { Use a token with at least three source-B candidates, so the strict repeat
      ceiling permits a local source swap between its alternating neighbors. }
    for LIndex := 0 to High(LTokens) do
    begin
      LTokens[LIndex] := APalette.EncodeFeature(AFeatures[6]);
    end;
    LReplay := LPool.Select(LTokens, LWeights, 731);
    CheckJoins(LPool, LReplay);
    for LIndex := 0 to High(LTokens) do
    begin
      LTokens[LIndex] := APalette.EncodeFeature(AFeatures[0]);
    end;
    Check((LCounts[0] = 32) and (LCounts[1] = 96) and (LCounts[2] = 0),
      'Independent 1:3 generation weights control feasible source contribution');
    if Length(ABaseline) = 0 then
    begin
      SetLength(ABaseline, Length(LSelected));
      for LIndex := 0 to High(LSelected) do
      begin
        ABaseline[LIndex] := LPool.CandidateAt(LSelected[LIndex]);
      end;
    end;
    LWeights[0] := 0;
    LWeights[1] := 0;
    LWeights[2] := 1;
    LSelected := LPool.Select(LTokens, LWeights, High(Integer));
    for LIndex := 0 to High(LSelected) do
    begin
      Check(LPool.CandidateAt(LSelected[LIndex]).FeatureIndex = 36,
        'Single available window repeats explicitly when unavoidable');
    end;
    LTokens[High(LTokens)] := APalette.EncodeFeature(AFeatures[3]);
    LRejected := False;
    try
      LSelected := LPool.Select(LTokens, LWeights);
    except
      on EAudio do
      begin
        LRejected := True;
      end;
    end;
    Check(LRejected, 'Unavailable token rejects without enabling an excluded segment');
    LWeights[2] := -1;
    LRejected := False;
    try
      LSelected := LPool.Select(LTokens, LWeights);
    except
      on EAudio do
      begin
        LRejected := True;
      end;
    end;
    Check(LRejected, 'Negative selection weight rejects');
  finally
    LPool.Free;
  end;
end;

procedure CheckPaletteFit;
var
  LStorage: TMemoryCommit;
  LJournal: TFeatureJournal;
  LReader: TJournalTrainingReader;
  LPalette: TAcousticPalette;
  LBinding: TFeatureJournalBinding;
  LBatch: TWaveFeatureBatch;
  LSegments: TJournalTrainingSegments;
  LFeatures: TAudioFeatures;
  LCenters: TAcousticVectors;
  LFits: TJournalPaletteFits;
  LOther: TJournalPaletteFits;
  LObservation: TJournalTrainingObservation;
  LFirst: Integer;
  LCount: Integer;
  LIndex: Integer;
  LSize: Integer;
  LRejected: Boolean;
begin
  LBinding := Default(TFeatureJournalBinding);
  LBinding.SourceSha256 := StringOfChar('f', 64);
  LBinding.SampleRate := 8000;
  LBinding.Channels := 1;
  LBinding.FrameCount := 7 * 64;
  LBinding.Options := DefaultAnalysisOptions;
  LBinding.Options.WindowFrames := 64;
  LBinding.Options.HopFrames := 64;
  SetLength(LFeatures, 7);
  for LIndex := 0 to High(LFeatures) do
  begin
    LFeatures[LIndex].ValidFrames := 64;
    LFeatures[LIndex].Silent := LIndex >= 5;
    if LIndex < 5 then
    begin
      LFeatures[LIndex].Rms := 0.001;
      LFeatures[LIndex].Peak := 0.001;
    end;
  end;
  LFeatures[1].Flux := 0.5;
  LFeatures[2].Flux := 0.5;
  LFeatures[3].Flux := 1;
  LFeatures[4].Flux := 1;
  SetLength(LCenters, 2);
  LCenters[1][14] := 1;
  LPalette := TAcousticPalette.CreateFromCenters(LCenters);
  try
    for LSize in [1, 3] do
    begin
      LStorage := TMemoryCommit.Create;
      LJournal := nil;
      LReader := nil;
      try
        LJournal := TFeatureJournal.Create(LStorage, LBinding, LStorage.Commit, True);
        LFirst := 0;
        while LFirst < Length(LFeatures) do
        begin
          LCount := Min(LSize, Length(LFeatures) - LFirst);
          LBatch := Default(TWaveFeatureBatch);
          LBatch.FirstFeature := LFirst;
          LBatch.SourceStartFrame := LFirst * 64;
          LBatch.NextFeature := LFirst + LCount;
          LBatch.Completed := LBatch.NextFeature = Length(LFeatures);
          LBatch.Features := Copy(LFeatures, LFirst, LCount);
          for LIndex := 0 to LCount - 1 do
          begin
            LBatch.Features[LIndex].StartFrame := LIndex * 64;
          end;
          LJournal.Append(LBatch);
          Inc(LFirst, LCount);
        end;
        SetLength(LSegments, 3);
        LSegments[0] := WholeJournalSegment(LJournal, 3);
        LSegments[0].FeatureCount := 4;
        LSegments[1] := WholeJournalSegment(LJournal);
        LSegments[1].FirstFeature := 4;
        LSegments[1].FeatureCount := 1;
        LSegments[2] := WholeJournalSegment(LJournal);
        LSegments[2].FirstFeature := 5;
        LSegments[2].FeatureCount := 2;
        LReader := TJournalTrainingReader.Create(LSegments);
        LFits := MeasureJournalPaletteFit(LReader, LPalette, 0.25);
        Check((Length(LFits) = 3) and (LFits[0].ObservationCount = 4) and
          (LFits[0].WeightedObservationCount = 12), 'Fit separates observation and training mass');
        Check((Abs(LFits[0].MeanSquaredDistance - 0.125) < 1E-12) and
          (Abs(LFits[0].NonSilentMeanSquaredDistance - 0.125) < 1E-12) and
          (LFits[0].NonSilentCount = 4) and (LFits[0].MaximumSquaredDistance = 0.25),
          'Known one-component distances and nonsilent denominator');
        Check((LFits[0].WithinLimitCount = 4) and (LFits[0].TokenCounts[0] = 3) and
          (LFits[0].TokenCounts[1] = 1) and (LFits[0].OccupiedTokens = 2) and
          (Abs(LFits[0].EffectiveTokens - 1.754765350603323) < 1E-12),
          'Inclusive distance boundary and known 3:1 occupancy entropy');
        Check((LFits[0].SelfTransitions = 2) and (LFits[0].LongestRun = 3) and
          (LFits[1].SelfTransitions = 0) and (LFits[1].LongestRun = 1),
          'Runs cross storage batches but reset at declared segments');
        Check((LFits[2].ObservationCount = 2) and (LFits[2].NonSilentCount = 0) and
          (LFits[2].NonSilentMeanSquaredDistance = 0) and (LFits[2].EffectiveTokens = 1),
          'All-silent range explicitly reports absent nonsilent evidence');
        LOther := MeasureJournalPaletteFit(LReader, LPalette, 0.125);
        Check(LOther[0].WithinLimitCount = 2, 'Caller limit changes only declared coverage');
        LOther[0].TokenCounts[0] := 99;
        Check(LFits[0].TokenCounts[0] = 3, 'Returned fits own their counts');
        LReader.Rewind;
        Check(LReader.ReadObservation(LObservation), 'Read before invalid fit');
        LRejected := False;
        try
          LFits := MeasureJournalPaletteFit(LReader, LPalette, NaN);
        except
          on EAudio do
          begin
            LRejected := True;
          end;
        end;
        Check(LRejected and (LFits[0].ObservationCount = 4),
          'Invalid limit rejects without publishing a partial result');
        Check(LReader.ReadObservation(LObservation) and (LObservation.FeatureIndex = 1),
          'Invalid limit does not rewind borrowed reader');
      finally
        LReader.Free;
        LJournal.Free;
        LStorage.Free;
      end;
    end;
  finally
    LPalette.Free;
  end;
  WriteLn('Palette fit distances, weights, silence, range/storage boundaries and rejection PASS');
end;

procedure CheckPartitions;
var
  LStorage: array[0..2] of TMemoryCommit;
  LJournals: array[0..2] of TFeatureJournal;
  LBinding: TFeatureJournalBinding;
  LBatch: TWaveFeatureBatch;
  LPlan: TJournalPartitionPlan;
  LInvalid: TJournalPartitionPlan;
  LSelected: TJournalTrainingSegments;
  LExpected: TJournalTrainingSegments;
  LReader: TJournalTrainingReader;
  LOracleReader: TJournalTrainingReader;
  LPalette: TAcousticPalette;
  LOraclePalette: TAcousticPalette;
  LModel: TWfcSequenceModel;
  LOracle: TWfcSequenceModel;
  LCenters: TAcousticVectors;
  LExpectedCenters: TAcousticVectors;
  LObservation: TJournalTrainingObservation;
  LSource: Integer;
  LIndex: Integer;
  LComponent: Integer;
  LCase: Integer;
  LRejected: Boolean;
begin
  FillChar(LStorage, SizeOf(LStorage), 0);
  FillChar(LJournals, SizeOf(LJournals), 0);
  LReader := nil;
  LOracleReader := nil;
  LPalette := nil;
  LOraclePalette := nil;
  try
    for LSource := 0 to High(LJournals) do
    begin
      LBinding := Default(TFeatureJournalBinding);
      LBinding.SourceSha256 := StringOfChar(Chr(Ord('a') + LSource), 64);
      LBinding.SampleRate := 8000;
      LBinding.Channels := 1;
      LBinding.FrameCount := 8 * 64;
      LBinding.Options := DefaultAnalysisOptions;
      LBinding.Options.WindowFrames := 64;
      LBinding.Options.HopFrames := 64;
      LStorage[LSource] := TMemoryCommit.Create;
      LJournals[LSource] := TFeatureJournal.Create(LStorage[LSource], LBinding,
        LStorage[LSource].Commit, True);
      LBatch := Default(TWaveFeatureBatch);
      LBatch.NextFeature := 8;
      LBatch.Completed := True;
      SetLength(LBatch.Features, 8);
      for LIndex := 0 to 7 do
      begin
        LBatch.Features[LIndex].StartFrame := LIndex * 64;
        LBatch.Features[LIndex].ValidFrames := 64;
        LBatch.Features[LIndex].Rms := 0.1 + LSource * 0.3 + (LIndex mod 2) * 0.1;
        LBatch.Features[LIndex].Peak := LBatch.Features[LIndex].Rms;
      end;
      LJournals[LSource].Append(LBatch);
      LJournals[LSource].Rewind;
      LStorage[LSource].Reads := 0;
    end;
    SetLength(LPlan, 4);
    for LIndex := 0 to High(LPlan) do
    begin
      LSource := Max(0, LIndex - 1);
      LPlan[LIndex].Segment := WholeJournalSegment(LJournals[LSource]);
      LPlan[LIndex].GroupId := 'recording-' + IntToStr(LSource);
      LPlan[LIndex].Partition := TJournalPartition(LSource);
      LPlan[LIndex].GroupVerified := True;
    end;
    LPlan[0].Segment.FeatureCount := 3;
    LPlan[0].Segment.Multiplicity := 2;
    LPlan[1].Segment.FirstFeature := 3;
    LPlan[1].Segment.FeatureCount := 5;
    LPlan[2].GroupVerified := False;
    LPlan[2].PreviouslyUsed := True;
    SetLength(LExpected, 2);
    LExpected[0] := LPlan[0].Segment;
    LExpected[1] := LPlan[1].Segment;
    LSelected := SelectJournalPartition(LPlan, jpTraining);
    Check((Length(LSelected) = 2) and (LSelected[0].Multiplicity = 2) and
      (LSelected[1].FirstFeature = 3), 'Partition preserves order, ranges and weights');
    LSelected[0].FeatureCount := 1;
    Check(LPlan[0].Segment.FeatureCount = 3, 'Partition result owns its descriptors');
    LSelected := SelectJournalPartition(LPlan, jpTraining);
    LReader := TJournalTrainingReader.Create(LSelected);
    LOracleReader := TJournalTrainingReader.Create(LExpected);
    LPalette := TAcousticPalette.CreateFromReader(LReader, 2);
    LOraclePalette := TAcousticPalette.CreateFromReader(LOracleReader, 2);
    LCenters := LPalette.CopyCenters;
    LExpectedCenters := LOraclePalette.CopyCenters;
    Check(Length(LCenters) = Length(LExpectedCenters), 'Training palette center count');
    for LIndex := 0 to High(LCenters) do
    begin
      for LComponent := 0 to High(TAcousticVector) do
      begin
        Check(LCenters[LIndex][LComponent] = LExpectedCenters[LIndex][LComponent],
          'Partition palette equals explicit training-only palette');
      end;
    end;
    LModel := LearnJournalAcousticModel(LReader, LPalette, 2);
    try
      LOracle := LearnJournalAcousticModel(LOracleReader, LOraclePalette, 2);
      try
        Check(EncodeWfcSequenceText(LModel) = EncodeWfcSequenceText(LOracle),
          'Partition WFC model equals explicit training-only model');
      finally
        LOracle.Free;
      end;
    finally
      LModel.Free;
    end;
    Check((LStorage[1].Reads = 0) and (LStorage[2].Reads = 0),
      'Development and evaluation observations never enter training');
    LReader.Rewind;
    Check(LReader.ReadObservation(LObservation), 'Start an active training read');
    LSelected := SelectJournalPartition(LPlan, jpEvaluation);
    Check((Length(LSelected) = 1) and (LSelected[0].Journal = LJournals[2]),
      'Evaluation selection contains only evaluation');
    Check(not LJournals[0].ReadNext(LBatch), 'Selection does not rewind borrowed journal');
    Check(LReader.ReadObservation(LObservation) and (LObservation.FeatureIndex = 1),
      'Valid selection preserves active journal cursors');
    LSelected := SelectJournalPartition(LPlan, jpDevelopment);
    Check((Length(LSelected) = 1) and (LSelected[0].Journal = LJournals[1]),
      'Unverified and previously used material remains available for development');
    for LCase := 0 to 11 do
    begin
      LInvalid := Copy(LPlan);
      case LCase of
        0: LInvalid[3].PreviouslyUsed := True;
        1: LInvalid[3].GroupVerified := False;
        2: LInvalid[0].GroupVerified := False;
        3: LInvalid[3].GroupId := LInvalid[0].GroupId;
        4: LInvalid[1].GroupId := 'disguised-same-source';
        5: LInvalid[1].Segment.FirstFeature := 2;
        6: LInvalid[3].Segment.Journal := nil;
        7: LInvalid[3].GroupId := '';
        8: LInvalid[3].GroupId := StringOfChar('x', 257);
        9: LInvalid[3].Segment.FeatureCount := High(Int64);
        10: LInvalid := nil;
        11: SetLength(LInvalid, MaximumJournalTrainingSegments + 1);
      end;
      LRejected := False;
      try
        LSelected := SelectJournalPartition(LInvalid, jpTraining);
      except
        on EAudio do
        begin
          LRejected := True;
        end;
      end;
      Check(LRejected and (Length(LSelected) = 1) and
        (LSelected[0].Journal = LJournals[1]),
        'Invalid whole plan rejects without replacing caller result: ' + IntToStr(LCase));
    end;
    LInvalid := Copy(LPlan, 0, 2);
    LRejected := False;
    try
      LSelected := SelectJournalPartition(LInvalid, jpEvaluation);
    except
      on EAudio do
      begin
        LRejected := True;
      end;
    end;
    Check(LRejected, 'Empty requested partition rejects');
    Check(LReader.ReadObservation(LObservation) and (LObservation.FeatureIndex = 2),
      'Rejected selections preserve active journal cursors');
  finally
    LOraclePalette.Free;
    LPalette.Free;
    LOracleReader.Free;
    LReader.Free;
    for LSource := 0 to High(LJournals) do
    begin
      LJournals[LSource].Free;
      LStorage[LSource].Free;
    end;
  end;
  WriteLn('Partition isolation, training-only palette/WFC parity, bounds and ownership PASS');
end;

procedure Run;
var
  LBaseline: TJournalRepresentatives;
  LStorage: TMemoryCommit;
  LJournal: TFeatureJournal;
  LBinding: TFeatureJournalBinding;
  LBatch: TWaveFeatureBatch;
  LFeatures: TAudioFeatures;
  LWeighted: TAudioFeatures;
  LSegments: TJournalTrainingSegments;
  LReader: TJournalTrainingReader;
  LPalette: TAcousticPalette;
  LOraclePalette: TAcousticPalette;
  LCorpus: TAcousticCorpus;
  LModel: TWfcSequenceModel;
  LOracle: TWfcSequenceModel;
  LCenters: TAcousticVectors;
  LExpectedCenters: TAcousticVectors;
  LFirst: Integer;
  LIndex: Integer;
  LComponent: Integer;
  LSize: Integer;
  LCount: Integer;
  LGroup: Integer;
  LOrder: Integer;
  LReplica: Integer;
  LSample: Integer;
  LPosition: Integer;
  LSegment: Integer;
  LRejected: Boolean;
begin
  LBaseline := nil;
  LBinding := Default(TFeatureJournalBinding);
  LBinding.SourceSha256 := StringOfChar('a', 64);
  LBinding.SampleRate := 8000;
  LBinding.Channels := 1;
  LBinding.FrameCount := 37 * 64;
  LBinding.Options := DefaultAnalysisOptions;
  LBinding.Options.WindowFrames := 64;
  LBinding.Options.HopFrames := 64;
  SetLength(LFeatures, 37);
  for LIndex := 0 to High(LFeatures) do
  begin
    LGroup := (LIndex div 3) mod 3;
    LFeatures[LIndex].StartFrame := LIndex * 64;
    LFeatures[LIndex].ValidFrames := 64;
    LFeatures[LIndex].Rms := 0.1 + LGroup * 0.2;
    LFeatures[LIndex].Peak := LFeatures[LIndex].Rms + 0.1;
    LFeatures[LIndex].CentroidHz := 200 + LGroup * 300;
    LFeatures[LIndex].Flux := (LIndex mod 5) * 0.1;
    LFeatures[LIndex].Chroma[LGroup * 4] := 1;
  end;
  for LSize in [1, 7, 13] do
  begin
    LStorage := TMemoryCommit.Create;
    LJournal := nil;
    LReader := nil;
    LPalette := nil;
    LOraclePalette := nil;
    try
      LJournal := TFeatureJournal.Create(LStorage, LBinding, LStorage.Commit, True);
      LFirst := 0;
      while LFirst < Length(LFeatures) do
      begin
        LCount := Min(LSize, Length(LFeatures) - LFirst);
        LBatch := Default(TWaveFeatureBatch);
        LBatch.FirstFeature := LFirst;
        LBatch.SourceStartFrame := LFirst * 64;
        LBatch.NextFeature := LFirst + LCount;
        LBatch.Completed := LBatch.NextFeature = Length(LFeatures);
        LBatch.Features := Copy(LFeatures, LFirst, LCount);
        for LIndex := 0 to LCount - 1 do
        begin
          LBatch.Features[LIndex].StartFrame := LIndex * 64;
        end;
        LJournal.Append(LBatch);
        Inc(LFirst, LCount);
      end;
      SetLength(LSegments, 3);
      LSegments[0] := WholeJournalSegment(LJournal, 2);
      LSegments[0].FeatureCount := 19;
      LSegments[1] := WholeJournalSegment(LJournal, 1);
      LSegments[1].FirstFeature := 19;
      LSegments[1].FeatureCount := 17;
      LSegments[2] := WholeJournalSegment(LJournal, 1);
      LSegments[2].FirstFeature := 36;
      LSegments[2].FeatureCount := 1;
      LReader := TJournalTrainingReader.Create(LSegments);
      Check((LReader.ObservationCount = 37) and (LReader.WeightedObservationCount = 56),
        'Declared multiplicity counts whole recordings');
      LPalette := TAcousticPalette.CreateFromReader(LReader, 3);
      SetLength(LWeighted, 56);
      LPosition := 0;
      for LSegment := 0 to High(LSegments) do
      begin
        for LReplica := 1 to LSegments[LSegment].Multiplicity do
        begin
          for LIndex := 0 to LSegments[LSegment].FeatureCount - 1 do
          begin
            LWeighted[LPosition] := LFeatures[LSegments[LSegment].FirstFeature + LIndex];
            Inc(LPosition);
          end;
        end;
      end;
      LOraclePalette := TAcousticPalette.Create(LWeighted, 3);
      LCenters := LPalette.CopyCenters;
      LExpectedCenters := LOraclePalette.CopyCenters;
      Check(Length(LCenters) = Length(LExpectedCenters), 'Weighted palette center count');
      for LIndex := 0 to High(LCenters) do
      begin
        for LComponent := 0 to High(TAcousticVector) do
        begin
          Check(Abs(LCenters[LIndex][LComponent] - LExpectedCenters[LIndex][LComponent]) < 1E-12,
            'Weighted streaming palette matches expanded evidence');
        end;
      end;
      SetLength(LCorpus, 4);
      LSample := 0;
      for LSegment := 0 to High(LSegments) do
      begin
        for LReplica := 1 to LSegments[LSegment].Multiplicity do
        begin
          LCorpus[LSample] := LPalette.Encode(Copy(LFeatures,
            LSegments[LSegment].FirstFeature, LSegments[LSegment].FeatureCount));
          Inc(LSample);
        end;
      end;
      for LOrder := 1 to 4 do
      begin
        LModel := LearnJournalAcousticModel(LReader, LPalette, LOrder);
        try
          LOracle := LearnAcousticModel(LCorpus, LPalette, LOrder);
          try
            Check(EncodeWfcSequenceText(LModel) = EncodeWfcSequenceText(LOracle),
              'Counted model exactly matches companion learner across storage/recording boundaries');
          finally
            LOracle.Free;
          end;
        finally
          LModel.Free;
        end;
      end;
      CheckSelection(LReader, LPalette, LFeatures, LBaseline);
      LSegments[1].FirstFeature := 18;
      LRejected := False;
      try
        LReader.Free;
        LReader := nil;
        LReader := TJournalTrainingReader.Create(LSegments);
      except
        on EAudio do LRejected := True;
      end;
      Check(LRejected, 'Overlapping ranges reject instead of duplicating evidence');
    finally
      LOraclePalette.Free;
      LPalette.Free;
      LReader.Free;
      LJournal.Free;
      LStorage.Free;
    end;
  end;
  WriteLn('Bounded weighted palette, exact WFC count parity, recording boundaries, candidate selection and overlap checks PASS');
end;

begin
  try
    CheckContextBoundaries;
    CheckPaletteFit;
    CheckPartitions;
    Run;
  except
    on LException: Exception do
    begin
      WriteLn(StdErr, LException.ClassName, ': ', LException.Message);
      Halt(1);
    end;
  end;
end.
