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
unit pythian.wfc.admitted.pitch.balance;

{$mode delphi}
{$H+}

interface

uses
  pythian.wfc.admitted.pitch,
  pythian.wfc.admitted.pitch.journal;

const
  AdmittedPitchBalancePolicyIdentity = 'pythian.admitted-pitch-group-balance.v1';

type
  TAdmittedPitchBalancePlan = class
  private
    FJournalSha256: String;
    FReportText: String;
    FSourceWeights: array of Integer;
  public
    function Rebuild(const AJournal: TAdmittedPitchJournal): TAdmittedPitchDurationModel;
    property JournalSha256: String read FJournalSha256;
    property ReportText: String read FReportText;
  end;

{ Balances admitted pitch-duration token mass across source groups. Every run
  from one source keeps the same integer contribution, and source/unknown gaps
  remain hard WFC sample boundaries. Repeated musical sections are not inferred. }
function PlanAdmittedPitchGroupBalance(
  const AJournal: TAdmittedPitchJournal): TAdmittedPitchBalancePlan;

implementation

uses
  SysUtils,
  pythian.audio,
  pythian.pitch.track,
  wfc_sequence;

type
  TBalanceSource = record
    GroupIndex: Integer;
    TokenCount: Int64;
    RunCount: Int64;
    IncludedFrames: Int64;
  end;
  TBalanceSources = array of TBalanceSource;
  TBalanceGroup = record
    GroupId: String;
    TokenCount: Int64;
    RunCount: Int64;
  end;
  TBalanceGroups = array of TBalanceGroup;
  TIntegerWeights = array of Integer;

function MaxInt64(const ALeft, ARight: Int64): Int64;
begin
  if ALeft > ARight then
  begin
    Result := ALeft;
  end
  else
  begin
    Result := ARight;
  end;
end;

procedure CountSource(const ASource: TAdmittedNoteSource;
  out ATokenCount, ARunCount, AIncludedFrames: Int64);
var
  LIndex: Integer;
  LSpan: TAdmittedNoteSpan;
  LPriorTraining: Boolean;
  LPriorEnd: Int64;
begin
  ATokenCount := 0;
  ARunCount := 0;
  AIncludedFrames := 0;
  LPriorTraining := False;
  LPriorEnd := -1;
  for LIndex := 0 to High(ASource.Spans) do
  begin
    LSpan := ASource.Spans[LIndex];
    if LSpan.Kind in [pskPitch, pskSilence] then
    begin
      Inc(ATokenCount);
      Inc(AIncludedFrames, LSpan.EndFrame - LSpan.StartFrame);
      if not LPriorTraining or (LSpan.StartFrame <> LPriorEnd) then
      begin
        Inc(ARunCount);
      end;
      LPriorTraining := True;
    end
    else
    begin
      LPriorTraining := False;
    end;
    LPriorEnd := LSpan.EndFrame;
  end;
end;

function GroupAt(var AGroups: TBalanceGroups; const AGroupId: String): Integer;
var
  LIndex: Integer;
begin
  for LIndex := 0 to High(AGroups) do
  begin
    if AGroups[LIndex].GroupId = AGroupId then
    begin
      Exit(LIndex);
    end;
  end;
  Result := Length(AGroups);
  SetLength(AGroups, Result + 1);
  AGroups[Result] := Default(TBalanceGroup);
  AGroups[Result].GroupId := AGroupId;
end;

function WeightsLexLess(const ALeft, ARight: TIntegerWeights): Boolean;
var
  LIndex: Integer;
begin
  Result := False;
  for LIndex := 0 to High(ALeft) do
  begin
    if ALeft[LIndex] <> ARight[LIndex] then
    begin
      Exit(ALeft[LIndex] < ARight[LIndex]);
    end;
  end;
end;

function ChooseWeights(const AGroups: TBalanceGroups): TIntegerWeights;
var
  LMaximumRaw: Int64;
  LBase: Integer;
  LIndex: Integer;
  LCandidate: TIntegerWeights;
  LBest: TIntegerWeights;
  LTarget: Int64;
  LWeight: Int64;
  LGroupTokens: Int64;
  LMinimumTokens: Int64;
  LMaximumTokens: Int64;
  LTotalTokens: Int64;
  LTotalRuns: Int64;
  LBestTokens: Int64;
  LBestRuns: Int64;
  LValid: Boolean;
begin
  LMaximumRaw := 0;
  for LIndex := 0 to High(AGroups) do
  begin
    if AGroups[LIndex].TokenCount < 1 then
    begin
      raise EAudio.Create('Balance requires admitted tokens in every selected group');
    end;
    LMaximumRaw := MaxInt64(LMaximumRaw, AGroups[LIndex].TokenCount);
  end;
  LBest := nil;
  LBestTokens := High(Int64);
  LBestRuns := High(Int64);
  for LBase := 1 to 64 do
  begin
    LTarget := LMaximumRaw * LBase;
    LTotalTokens := 0;
    LTotalRuns := 0;
    LMinimumTokens := High(Int64);
    LMaximumTokens := 0;
    LValid := True;
    SetLength(LCandidate, Length(AGroups));
    for LIndex := 0 to High(AGroups) do
    begin
      LWeight := (LTarget + AGroups[LIndex].TokenCount div 2) div
        AGroups[LIndex].TokenCount;
      if (LWeight < 1) or (LWeight > 64) then
      begin
        LValid := False;
        Break;
      end;
      LCandidate[LIndex] := Integer(LWeight);
      LGroupTokens := AGroups[LIndex].TokenCount * LWeight;
      if LGroupTokens < LMinimumTokens then
      begin
        LMinimumTokens := LGroupTokens;
      end;
      LMaximumTokens := MaxInt64(LMaximumTokens, LGroupTokens);
      Inc(LTotalTokens, LGroupTokens);
      Inc(LTotalRuns, AGroups[LIndex].RunCount * LWeight);
    end;
    if not LValid or (LTotalTokens > 65536) or
      (LTotalRuns > WFC_SEQUENCE_MAX_SAMPLE_COUNT) or
      (LMaximumTokens * 10 > LMinimumTokens * 11) then
    begin
      Continue;
    end;
    if (LTotalTokens < LBestTokens) or
      ((LTotalTokens = LBestTokens) and (LTotalRuns < LBestRuns)) or
      ((LTotalTokens = LBestTokens) and (LTotalRuns = LBestRuns) and
        WeightsLexLess(LCandidate, LBest)) then
    begin
      LBest := Copy(LCandidate);
      LBestTokens := LTotalTokens;
      LBestRuns := LTotalRuns;
    end;
  end;
  if Length(LBest) <> Length(AGroups) then
  begin
    raise EAudio.Create('No bounded group-token balance plan meets the 110 percent gate');
  end;
  Result := LBest;
end;

function PlanAdmittedPitchGroupBalance(
  const AJournal: TAdmittedPitchJournal): TAdmittedPitchBalancePlan;
var
  LSources: TAdmittedNoteSources;
  LSourceRows: TBalanceSources;
  LGroups: TBalanceGroups;
  LGroupWeights: TIntegerWeights;
  LIndex: Integer;
  LGroupIndex: Integer;
  LResult: TAdmittedPitchBalancePlan;
  LReport: String;
  LRawTokens: Int64;
  LRawRuns: Int64;
  LWeightedTokens: Int64;
  LWeightedRuns: Int64;
begin
  Result := nil;
  if AJournal = nil then
  begin
    raise EAudio.Create('Balance needs a contribution journal');
  end;
  LSources := AJournal.CopySources;
  SetLength(LSourceRows, Length(LSources));
  LGroups := nil;
  for LIndex := 0 to High(LSources) do
  begin
    LGroupIndex := GroupAt(LGroups, LSources[LIndex].GroupId);
    LSourceRows[LIndex].GroupIndex := LGroupIndex;
    CountSource(LSources[LIndex], LSourceRows[LIndex].TokenCount,
      LSourceRows[LIndex].RunCount, LSourceRows[LIndex].IncludedFrames);
    Inc(LGroups[LGroupIndex].TokenCount, LSourceRows[LIndex].TokenCount);
    Inc(LGroups[LGroupIndex].RunCount, LSourceRows[LIndex].RunCount);
  end;
  if Length(LGroups) < 2 then
  begin
    raise EAudio.Create('Balance needs at least two source groups');
  end;
  LGroupWeights := ChooseWeights(LGroups);
  LResult := TAdmittedPitchBalancePlan.Create;
  try
    LResult.FJournalSha256 := AJournal.JournalSha256;
    SetLength(LResult.FSourceWeights, Length(LSources));
    LReport := AdmittedPitchBalancePolicyIdentity + #10 +
      'journal_sha256=' + LResult.FJournalSha256 + #10 +
      'mass=admitted_pitch_or_silence_tokens;unknown=excluded_hard_boundary;' +
      'repeated_section_identity=unknown;generation_preferences=separate' + #10 +
      'source_columns=group,recording,source_sha256,annotation_sha256,sample_rate,' +
      'source_frames,included_frames,excluded_frames,raw_tokens,raw_runs,weight,' +
      'weighted_tokens,weighted_runs' + #10 +
      'group_columns=group,raw_tokens,raw_runs,weight,weighted_tokens,weighted_runs' + #10 +
      'total_columns=raw_tokens,raw_runs,weighted_tokens,weighted_runs,' +
      'token_cap,run_cap' + #10;
    for LIndex := 0 to High(LSources) do
    begin
      LGroupIndex := LSourceRows[LIndex].GroupIndex;
      LResult.FSourceWeights[LIndex] := LGroupWeights[LGroupIndex];
      LReport := LReport + 'source' + #9 + LSources[LIndex].GroupId + #9 +
        LSources[LIndex].RecordingId + #9 + LSources[LIndex].SourceSha256 + #9 +
        LSources[LIndex].SourceAnnotationSha256 + #9 +
        IntToStr(LSources[LIndex].SampleRate) + #9 +
        IntToStr(LSources[LIndex].SourceFrameCount) + #9 +
        IntToStr(LSourceRows[LIndex].IncludedFrames) + #9 +
        IntToStr(LSources[LIndex].SourceFrameCount - LSourceRows[LIndex].IncludedFrames) + #9 +
        IntToStr(LSourceRows[LIndex].TokenCount) + #9 +
        IntToStr(LSourceRows[LIndex].RunCount) + #9 +
        IntToStr(LResult.FSourceWeights[LIndex]) + #9 +
        IntToStr(LSourceRows[LIndex].TokenCount * LResult.FSourceWeights[LIndex]) + #9 +
        IntToStr(LSourceRows[LIndex].RunCount * LResult.FSourceWeights[LIndex]) + #10;
    end;
    for LIndex := 0 to High(LGroups) do
    begin
      LReport := LReport + 'group' + #9 + LGroups[LIndex].GroupId + #9 +
        IntToStr(LGroups[LIndex].TokenCount) + #9 +
        IntToStr(LGroups[LIndex].RunCount) + #9 +
        IntToStr(LGroupWeights[LIndex]) + #9 +
        IntToStr(LGroups[LIndex].TokenCount * LGroupWeights[LIndex]) + #9 +
        IntToStr(LGroups[LIndex].RunCount * LGroupWeights[LIndex]) + #10;
    end;
    LRawTokens := 0;
    LRawRuns := 0;
    LWeightedTokens := 0;
    LWeightedRuns := 0;
    for LIndex := 0 to High(LGroups) do
    begin
      Inc(LRawTokens, LGroups[LIndex].TokenCount);
      Inc(LRawRuns, LGroups[LIndex].RunCount);
      Inc(LWeightedTokens, LGroups[LIndex].TokenCount * LGroupWeights[LIndex]);
      Inc(LWeightedRuns, LGroups[LIndex].RunCount * LGroupWeights[LIndex]);
    end;
    LReport := LReport + 'total' + #9 + IntToStr(LRawTokens) + #9 +
      IntToStr(LRawRuns) + #9 + IntToStr(LWeightedTokens) + #9 +
      IntToStr(LWeightedRuns) + #9 + '65536' + #9 +
      IntToStr(WFC_SEQUENCE_MAX_SAMPLE_COUNT) + #10;
    LResult.FReportText := LReport;
    Result := LResult;
    LResult := nil;
  finally
    LResult.Free;
  end;
end;

function TAdmittedPitchBalancePlan.Rebuild(
  const AJournal: TAdmittedPitchJournal): TAdmittedPitchDurationModel;
var
  LSources: TAdmittedNoteSources;
begin
  if (AJournal = nil) or (AJournal.JournalSha256 <> FJournalSha256) then
  begin
    raise EAudio.Create('Balance plan journal identity does not match');
  end;
  LSources := AJournal.CopySources;
  Result := LearnWeightedAdmittedPitchDurationModel(LSources, FSourceWeights,
    AJournal.Order, AdmittedPitchBalancePolicyIdentity);
end;

end.
