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
unit pythian.wfc.compose;

{$mode delphi}
{$H+}

interface

uses
  pythian.music,
  pythian.music.compose,
  wfc,
  wfc_sequence;

const
  WfcCompositionChordBars = 16;
  WfcCompositionMaximumSources = 8;
  WfcCompositionModelOrder = 2;
  WfcCompositionMaximumStates = 256;
  WfcCompositionMaximumReachabilityWork = 16777216;
  WfcCompositionSolveBacktracks = 256;
  WfcCompositionSolveStateCells = 262144;

type
  TCompositionChordSources = array of TCompositionChordSchedule;
  TCompositionScheduleHashes = array of String;

  TWfcCompositionStatus = (
    wcsNotRun,
    wcsInvalidSources,
    wcsModelRejected,
    wcsNoNovelReachablePath,
    wcsContradiction,
    wcsBacktrackLimit,
    wcsCandidateRejected,
    wcsSolved
  );

  TWfcCompositionReport = record
    Status: TWfcCompositionStatus;
    FailureReason: String;
    SourceCount: Integer;
    SourceHashes: TCompositionScheduleHashes;
    SourceHash: String;
    ModelStateCount: Integer;
    ModelVocabularyCount: Integer;
    ModelTextHash: String;
    TokenHash: String;
    EventLedgerHash: String;
    SolveCalled: Boolean;
    Solve: TGraphSolveReport;
    HasLegalWholePath: Boolean;
    HasNovelWholePath: Boolean;
    ReachabilityWork: Int64;
    FullSourceCopy: Boolean;
    FullSourceCopyIndex: Integer;
    { Counts each matching four-bar source window; masks use the zero-based
      source index in caller input order. }
    PhraseUnionMatchCounts: array[0..3] of Integer;
    PhraseUnionSourceMasks: array[0..3] of Byte;
    ChangedBarCount: Integer;
    ChangedBassPitchCount: Integer;
    ChangedMelodyPitchCount: Integer;
    GeneratedSchedule: TCompositionChordSchedule;
    GeneratedScheduleText: String;
    Text: UTF8String;
  end;

{ Learn and generate the frozen bounded chord-path candidate from caller-owned
  source schedules. The WFC model is order-2/open; reachability proves a legal
  complete path outside the complete-source union before the one whole-extent
  solve. Seed, solve budget and 16-bar fixed positional constraints are
  recorded in the report. On success the prior owned AOutput is freed and
  replaced. On False or exception AOutput remains untouched. }
function TryGenerateWfcChordComposition(
  const ASources: TCompositionChordSources; const ASeed: Cardinal;
  var AOutput: TNoteSequence; out AReport: TWfcCompositionReport): Boolean;

function WfcCompositionStatusText(
  const AStatus: TWfcCompositionStatus): String;
function WfcGraphStatusText(const AReport: TWfcCompositionReport): String;
function WfcCompositionScheduleText(
  const ASchedule: TCompositionChordSchedule): String;

implementation

uses
  SysUtils,
  pythian.audio,
  pythian.hash,
  pythian.wfc.generation,
  wfc_model,
  wfc_sequence_learn,
  wfc_sequence_text;

type
  TReachabilityCells = array of Boolean;
  TCompatibilityCells = array of Boolean;
  TModelStateTokens = array of TWfcModelToken;

function ChordName(const AChord: TCompositionChord): String;
begin
  case AChord of
    ccC: Result := 'C';
    ccAm: Result := 'Am';
    ccF: Result := 'F';
    ccG: Result := 'G';
    ccEm: Result := 'Em';
  else
    raise EAudio.Create('Composition chord enum is outside the supported vocabulary');
  end;
end;

function ChordToken(const AChord: TCompositionChord): TWfcModelToken;
begin
  Result := UTF8String(ChordName(AChord));
end;

function TokenChord(const AToken: TWfcModelToken;
  out AChord: TCompositionChord): Boolean;
begin
  if AToken = 'C' then
    AChord := ccC
  else if AToken = 'Am' then
    AChord := ccAm
  else if AToken = 'F' then
    AChord := ccF
  else if AToken = 'G' then
    AChord := ccG
  else if AToken = 'Em' then
    AChord := ccEm
  else
    Exit(False);
  Result := True;
end;

function WfcCompositionScheduleText(
  const ASchedule: TCompositionChordSchedule): String;
var
  LIndex: Integer;
begin
  Result := '';
  for LIndex := 0 to High(ASchedule) do
  begin
    if LIndex > 0 then
    begin
      if (LIndex mod 4) = 0 then
        Result := Result + ' | '
      else
        Result := Result + ' ';
    end;
    Result := Result + ChordName(ASchedule[LIndex]);
  end;
end;

function WfcCompositionStatusText(
  const AStatus: TWfcCompositionStatus): String;
begin
  case AStatus of
    wcsNotRun: Result := 'not_run';
    wcsInvalidSources: Result := 'invalid_sources';
    wcsModelRejected: Result := 'model_rejected';
    wcsNoNovelReachablePath: Result := 'no_novel_reachable_path';
    wcsContradiction: Result := 'contradiction';
    wcsBacktrackLimit: Result := 'backtrack_limit';
    wcsCandidateRejected: Result := 'candidate_rejected';
    wcsSolved: Result := 'solved';
  else
    Result := 'unknown';
  end;
end;

function WfcGraphStatusText(const AReport: TWfcCompositionReport): String;
begin
  if not AReport.SolveCalled then
    Exit('not_run');
  case AReport.Solve.Status of
    gssSolved: Result := 'solved';
    gssContradiction: Result := 'contradiction';
    gssBacktrackLimit: Result := 'backtrack_limit';
  else
    Result := 'unknown';
  end;
end;

function HashUtf8(const AText: UTF8String): String;
var
  LBytes: TAudioBytes;
  LIndex: Integer;
begin
  SetLength(LBytes, Length(AText));
  for LIndex := 1 to Length(AText) do
    LBytes[LIndex - 1] := Byte(AText[LIndex]);
  Result := Sha256Bytes(LBytes);
end;

function ScheduleTokens(const ASchedule: TCompositionChordSchedule): TWfcModelTokens;
var
  LIndex: Integer;
begin
  Result := nil;
  SetLength(Result, WfcCompositionChordBars);
  for LIndex := 0 to High(ASchedule) do
    Result[LIndex] := ChordToken(ASchedule[LIndex]);
end;

function ScheduleSourceText(const ASchedule: TCompositionChordSchedule): UTF8String;
var
  LTokens: TWfcModelTokens;
  LIndex: Integer;
begin
  LTokens := ScheduleTokens(ASchedule);
  Result := '';
  for LIndex := 0 to High(LTokens) do
  begin
    if LIndex > 0 then
      Result := Result + ' ';
    Result := Result + LTokens[LIndex];
  end;
  Result := Result + #10;
end;

function HashSources(const ASources: TCompositionChordSources;
  out APerSource: TCompositionScheduleHashes): String;
var
  LText: UTF8String;
  LIndex: Integer;
  LSourceText: UTF8String;
begin
  SetLength(APerSource, Length(ASources));
  LText := UTF8String('source_count=') + UTF8String(IntToStr(Length(ASources))) + #10;
  for LIndex := 0 to High(ASources) do
  begin
    LSourceText := ScheduleSourceText(ASources[LIndex]);
    APerSource[LIndex] := HashUtf8(LSourceText);
    LText := LText + UTF8String('source_') + UTF8String(IntToStr(LIndex)) + '=' +
      LSourceText;
  end;
  Result := HashUtf8(LText);
end;

function AllowedAt(const APosition: Integer;
  const AChord: TCompositionChord): Boolean;
begin
  case APosition of
    0, 14, 15: Result := AChord = ccC;
    3, 7, 11, 13: Result := AChord = ccG;
    12: Result := AChord = ccF;
  else
    Result := True;
  end;
end;

procedure ValidateSources(const ASources: TCompositionChordSources);
var
  LSource: Integer;
  LBar: Integer;
begin
  if (Length(ASources) < 1) or
    (Length(ASources) > WfcCompositionMaximumSources) then
    raise EAudio.Create('WFC composition requires 1..8 chord source schedules');
  for LSource := 0 to High(ASources) do
  begin
    for LBar := 0 to WfcCompositionChordBars - 1 do
    begin
      if not AllowedAt(LBar, ASources[LSource][LBar]) then
        raise EAudio.CreateFmt('Source %d violates the fixed chord mask at bar %d',
          [LSource, LBar]);
    end;
    if ASources[LSource][15] <> ccC then
      raise EAudio.CreateFmt('Source %d does not end on the required C cadence',
        [LSource]);
  end;
end;

function MakeSamples(const ASources: TCompositionChordSources): TWfcSequenceSamples;
var
  LIndex: Integer;
begin
  Result := nil;
  SetLength(Result, Length(ASources));
  for LIndex := 0 to High(ASources) do
    Result[LIndex] := MakeWfcSequenceSample(ScheduleTokens(ASources[LIndex]));
end;

function NextSourceMask(const AMask, APosition: Integer;
  const AToken: TWfcModelToken; const ASamples: TWfcSequenceSamples): Integer;
var
  LSource: Integer;
begin
  Result := 0;
  for LSource := 0 to High(ASamples) do
    if ((AMask and (1 shl LSource)) <> 0) and
      (ASamples[LSource].Tokens[APosition] = AToken) then
      Result := Result or (1 shl LSource);
end;

function ReachabilityIndex(const APosition, AState, AMask,
  AStateCount, AMaskCount: Integer): Integer; inline;
begin
  Result := ((APosition * AStateCount) + AState) * AMaskCount + AMask;
end;

function CheckReachability(const AModel: TWfcSequenceModel;
  const ASamples: TWfcSequenceSamples; out AHasPath, AHasNovel: Boolean): Int64;
var
  LCells: TReachabilityCells;
  LCompatible: TCompatibilityCells;
  LStateTokens: TModelStateTokens;
  LPosition: Integer;
  LSource: Integer;
  LTarget: Integer;
  LMask: Integer;
  LNextMask: Integer;
  LMaskCount: Integer;
  LStateCount: Integer;
  LAllSources: Integer;
  LWork: Int64;
  LCellIndex: Integer;
  LChord: TCompositionChord;
begin
  LStateCount := AModel.StateCount;
  LMaskCount := 1 shl Length(ASamples);
  LAllSources := LMaskCount - 1;
  SetLength(LCells, WfcCompositionChordBars * LStateCount * LMaskCount);
  SetLength(LCompatible, LStateCount * LStateCount);
  SetLength(LStateTokens, LStateCount);
  for LSource := 0 to LStateCount - 1 do
  begin
    LStateTokens[LSource] := AModel.ProjectStateToken(LSource);
    for LTarget := 0 to LStateCount - 1 do
      LCompatible[LSource * LStateCount + LTarget] :=
        AModel.StatesCompatible(LSource, LTarget);
  end;
  LWork := Int64(LStateCount) * LStateCount;
  for LTarget := 0 to LStateCount - 1 do
  begin
    if AModel.StartCountAt(LTarget) = 0 then
      Continue;
    if not TokenChord(LStateTokens[LTarget], LChord) then
      Continue;
    if not AllowedAt(0, LChord) then
      Continue;
    LNextMask := NextSourceMask(LAllSources, 0, LStateTokens[LTarget], ASamples);
    LCellIndex := ReachabilityIndex(0, LTarget, LNextMask,
      LStateCount, LMaskCount);
    LCells[LCellIndex] := True;
  end;
  for LPosition := 1 to WfcCompositionChordBars - 1 do
  begin
    for LSource := 0 to LStateCount - 1 do
    begin
      for LMask := 0 to LMaskCount - 1 do
      begin
        LCellIndex := ReachabilityIndex(LPosition - 1, LSource, LMask,
          LStateCount, LMaskCount);
        if not LCells[LCellIndex] then
          Continue;
        for LTarget := 0 to LStateCount - 1 do
        begin
          Inc(LWork);
          if LWork > WfcCompositionMaximumReachabilityWork then
            raise EAudio.Create('WFC chord reachability exceeded fixed work bound');
          if not LCompatible[LSource * LStateCount + LTarget] then
            Continue;
          if not TokenChord(LStateTokens[LTarget], LChord) then
            Continue;
          if not AllowedAt(LPosition, LChord) then
            Continue;
          LNextMask := NextSourceMask(LMask, LPosition,
            LStateTokens[LTarget], ASamples);
          LCellIndex := ReachabilityIndex(LPosition, LTarget, LNextMask,
            LStateCount, LMaskCount);
          LCells[LCellIndex] := True;
        end;
      end;
    end;
  end;
  AHasPath := False;
  AHasNovel := False;
  for LTarget := 0 to LStateCount - 1 do
  begin
    if AModel.EndCountAt(LTarget) = 0 then
      Continue;
    for LMask := 0 to LMaskCount - 1 do
      if LCells[ReachabilityIndex(WfcCompositionChordBars - 1,
        LTarget, LMask, LStateCount, LMaskCount)] then
      begin
        AHasPath := True;
        if LMask = 0 then
          AHasNovel := True;
      end;
  end;
  Result := LWork;
end;

function BuildConstraints: TWfcSequenceTokenConstraints;
const
  CFixedPositionCount = 8;
  CPositions: array[0..CFixedPositionCount - 1] of Integer =
    (0, 3, 7, 11, 12, 13, 14, 15);
var
  LIndex: Integer;
  LChord: TCompositionChord;
  LAllowed: TWfcModelTokens;
begin
  Result := nil;
  SetLength(Result, CFixedPositionCount);
  for LIndex := 0 to CFixedPositionCount - 1 do
  begin
    case CPositions[LIndex] of
      0, 14, 15: LChord := ccC;
      12: LChord := ccF;
    else
      LChord := ccG;
    end;
    SetLength(LAllowed, 1);
    LAllowed[0] := ChordToken(LChord);
    Result[LIndex] := MakeWfcSequenceTokenConstraint(CPositions[LIndex], LAllowed);
  end;
end;

function TokensHash(const ATokens: TWfcModelTokens): String;
var
  LText: UTF8String;
  LIndex: Integer;
begin
  LText := '';
  for LIndex := 0 to High(ATokens) do
  begin
    if LIndex > 0 then
      LText := LText + ' ';
    LText := LText + ATokens[LIndex];
  end;
  LText := LText + #10;
  Result := HashUtf8(LText);
end;

function TokensEqualSchedule(const ATokens: TWfcModelTokens;
  const ASchedule: TCompositionChordSchedule): Boolean;
var
  LIndex: Integer;
begin
  Result := False;
  if Length(ATokens) <> WfcCompositionChordBars then
    Exit;
  for LIndex := 0 to High(ASchedule) do
    if ATokens[LIndex] <> ChordToken(ASchedule[LIndex]) then
      Exit;
  Result := True;
end;

procedure CalculateNovelty(const ATokens: TWfcModelTokens;
  const ASources: TCompositionChordSources;
  out AFullSourceCopy: Boolean; out AFullSourceIndex: Integer;
  out APhraseCounts: array of Integer; out APhraseMasks: array of Byte);
var
  LSource: Integer;
  LSourcePhrase: Integer;
  LPhrase: Integer;
  LOffset: Integer;
  LSourceOffset: Integer;
  LMatches: Boolean;
begin
  AFullSourceCopy := False;
  AFullSourceIndex := -1;
  for LSource := 0 to High(ASources) do
    if TokensEqualSchedule(ATokens, ASources[LSource]) then
    begin
      AFullSourceCopy := True;
      AFullSourceIndex := LSource;
      Break;
    end;
  for LPhrase := 0 to 3 do
  begin
    APhraseCounts[LPhrase] := 0;
    APhraseMasks[LPhrase] := 0;
    for LSource := 0 to High(ASources) do
    begin
      for LSourcePhrase := 0 to 3 do
      begin
        LMatches := True;
        for LOffset := 0 to 3 do
        begin
          LSourceOffset := LSourcePhrase * 4 + LOffset;
          if ATokens[LPhrase * 4 + LOffset] <>
            ChordToken(ASources[LSource][LSourceOffset]) then
          begin
            LMatches := False;
            Break;
          end;
        end;
        if LMatches then
        begin
          Inc(APhraseCounts[LPhrase]);
          APhraseMasks[LPhrase] := APhraseMasks[LPhrase] or Byte(1 shl LSource);
        end;
      end;
    end;
  end;
end;

function ComparePitchChanges(const ACandidate, ABaseline: TNoteSequence;
  out ABass, AMelody: Integer): Boolean;
var
  LIndex: Integer;
  LCandidateGate: TNoteGate;
  LBaselineGate: TNoteGate;
begin
  ABass := 0;
  AMelody := 0;
  Result := False;
  if ACandidate.NoteCount <> ABaseline.NoteCount then
    Exit;
  for LIndex := 0 to ACandidate.NoteCount - 1 do
  begin
    LCandidateGate := ACandidate.GateAt(LIndex);
    LBaselineGate := ABaseline.GateAt(LIndex);
    if (LCandidateGate.StartTick <> LBaselineGate.StartTick) or
      (LCandidateGate.EndTick <> LBaselineGate.EndTick) or
      (LCandidateGate.Track <> LBaselineGate.Track) or
      (LCandidateGate.Voice <> LBaselineGate.Voice) or
      (LCandidateGate.Channel <> LBaselineGate.Channel) or
      (LCandidateGate.Velocity <> LBaselineGate.Velocity) then
      Exit;
    if LCandidateGate.Pitch <> LBaselineGate.Pitch then
    begin
      if LCandidateGate.Track = 0 then
        Inc(ABass)
      else if LCandidateGate.Track = 1 then
        Inc(AMelody)
      else
        Exit;
    end;
  end;
  Result := True;
end;

procedure BuildReportText(var AReport: TWfcCompositionReport;
  const ASeed: Cardinal);
var
  LIndex: Integer;
begin
  AReport.Text := '';
  AReport.Text := AReport.Text + 'status=' +
    UTF8String(WfcCompositionStatusText(AReport.Status)) + #10;
  AReport.Text := AReport.Text + 'seed=' + UTF8String(IntToStr(ASeed)) + #10;
  AReport.Text := AReport.Text + 'source_count=' +
    UTF8String(IntToStr(AReport.SourceCount)) + #10;
  AReport.Text := AReport.Text + 'source_sha256=' +
    UTF8String(AReport.SourceHash) + #10;
  for LIndex := 0 to High(AReport.SourceHashes) do
    AReport.Text := AReport.Text + 'source_' + UTF8String(IntToStr(LIndex)) +
      '_sha256=' + UTF8String(AReport.SourceHashes[LIndex]) + #10;
  AReport.Text := AReport.Text + 'model_order=2' + #10;
  AReport.Text := AReport.Text + 'model_boundary=open' + #10;
  AReport.Text := AReport.Text + 'model_state_count=' +
    UTF8String(IntToStr(AReport.ModelStateCount)) + #10;
  AReport.Text := AReport.Text + 'model_vocabulary_count=' +
    UTF8String(IntToStr(AReport.ModelVocabularyCount)) + #10;
  AReport.Text := AReport.Text + 'model_text_sha256=' +
    UTF8String(AReport.ModelTextHash) + #10;
  AReport.Text := AReport.Text + 'has_legal_whole_path=' +
    UTF8String(LowerCase(BoolToStr(AReport.HasLegalWholePath, True))) + #10;
  AReport.Text := AReport.Text + 'has_novel_whole_path=' +
    UTF8String(LowerCase(BoolToStr(AReport.HasNovelWholePath, True))) + #10;
  AReport.Text := AReport.Text + 'reachability_work=' +
    UTF8String(IntToStr(AReport.ReachabilityWork)) + #10;
  AReport.Text := AReport.Text + 'solve_called=' +
    UTF8String(LowerCase(BoolToStr(AReport.SolveCalled, True))) + #10;
  AReport.Text := AReport.Text + 'graph_status=' +
    UTF8String(WfcGraphStatusText(AReport)) + #10;
  AReport.Text := AReport.Text + 'generated_schedule=' +
    UTF8String(AReport.GeneratedScheduleText) + #10;
  AReport.Text := AReport.Text + 'token_sha256=' +
    UTF8String(AReport.TokenHash) + #10;
  AReport.Text := AReport.Text + 'event_ledger_sha256=' +
    UTF8String(AReport.EventLedgerHash) + #10;
  AReport.Text := AReport.Text + 'full_source_copy=' +
    UTF8String(LowerCase(BoolToStr(AReport.FullSourceCopy, True))) + #10;
  AReport.Text := AReport.Text + 'full_source_copy_index=' +
    UTF8String(IntToStr(AReport.FullSourceCopyIndex)) + #10;
  for LIndex := 0 to 3 do
    AReport.Text := AReport.Text + 'phrase_' + UTF8String(IntToStr(LIndex)) +
      '_source_matches=' + UTF8String(IntToStr(AReport.PhraseUnionMatchCounts[LIndex])) + #10;
  AReport.Text := AReport.Text + 'changed_bars=' +
    UTF8String(IntToStr(AReport.ChangedBarCount)) + #10;
  AReport.Text := AReport.Text + 'changed_bass_pitches=' +
    UTF8String(IntToStr(AReport.ChangedBassPitchCount)) + #10;
  AReport.Text := AReport.Text + 'changed_melody_pitches=' +
    UTF8String(IntToStr(AReport.ChangedMelodyPitchCount)) + #10;
  if AReport.FailureReason <> '' then
    AReport.Text := AReport.Text + 'failure=' + UTF8String(AReport.FailureReason) + #10;
end;

function TryGenerateWfcChordComposition(
  const ASources: TCompositionChordSources; const ASeed: Cardinal;
  var AOutput: TNoteSequence; out AReport: TWfcCompositionReport): Boolean;
var
  LSamples: TWfcSequenceSamples;
  LModel: TWfcSequenceModel;
  LOptions: TAcousticGenerationOptions;
  LConstraints: TWfcSequenceTokenConstraints;
  LTokens: TWfcModelTokens;
  LModelText: String;
  LChord: TCompositionChord;
  LIndex: Integer;
  LWork: Int64;
  LDefaultSchedule: TCompositionChordSchedule;
  LFullSourceCopy: Boolean;
  LFullSourceIndex: Integer;
  LPhraseCounts: array[0..3] of Integer;
  LPhraseMasks: array[0..3] of Byte;
  LReachable: Boolean;
  LNovelReachable: Boolean;
  LGeneratedSchedule: TCompositionChordSchedule;
  LCandidate: TNoteSequence;
  LPrevious: TNoteSequence;
  LBaseline: TNoteSequence;
  LBaselineReport: TCompositionScaffoldReport;
  LCandidateReport: TCompositionScaffoldReport;
  LCandidateComplete: Boolean;
begin
  AReport := Default(TWfcCompositionReport);
  AReport.Status := wcsNotRun;
  AReport.FullSourceCopyIndex := -1;
  Result := False;
  LModel := nil;
  LCandidate := nil;
  LBaseline := nil;
  LReachable := False;
  LNovelReachable := False;
  LWork := 0;
  try
    try
      AReport.SourceCount := Length(ASources);
      ValidateSources(ASources);
      AReport.SourceHash := HashSources(ASources, AReport.SourceHashes);
      LSamples := MakeSamples(ASources);
      AReport.Status := wcsModelRejected;
      LModel := LearnSequenceModelCorpus(LSamples,
        WfcCompositionModelOrder, wmbOpen);
      AReport.ModelStateCount := LModel.StateCount;
      AReport.ModelVocabularyCount := LModel.PublicTokenCount;
      if (LModel.SampleCount <> Length(ASources)) or
        (LModel.StateCount > WfcCompositionMaximumStates) or
        (LModel.PublicTokenCount <> 5) then
      begin
        AReport.Status := wcsModelRejected;
        AReport.FailureReason := 'Learned model violates frozen sample/state/vocabulary bounds';
        BuildReportText(AReport, ASeed);
        Exit;
      end;
      LModelText := EncodeWfcSequenceText(LModel);
      AReport.ModelTextHash := HashUtf8(UTF8String(LModelText));
      AReport.Status := wcsNoNovelReachablePath;
      LWork := CheckReachability(LModel, LSamples, LReachable, LNovelReachable);
      AReport.ReachabilityWork := LWork;
      AReport.HasLegalWholePath := LReachable;
      AReport.HasNovelWholePath := LNovelReachable;
      if not (LReachable and LNovelReachable) then
      begin
        AReport.Status := wcsNoNovelReachablePath;
        AReport.FailureReason := 'No legal complete path outside the source progression union';
        BuildReportText(AReport, ASeed);
        Exit;
      end;
      LOptions := DefaultAcousticGenerationOptions;
      LOptions.FrameCount := WfcCompositionChordBars;
      LOptions.Seed := ASeed;
      LOptions.Extent := wseWhole;
      LOptions.MaxBacktracks := WfcCompositionSolveBacktracks;
      LOptions.StateCellBudget := WfcCompositionSolveStateCells;
      LConstraints := BuildConstraints;
      LTokens := nil;
      AReport.Status := wcsCandidateRejected;
      AReport.SolveCalled := True;
      if not TryGenerateTokenSequence(LModel, LOptions, LConstraints,
        LTokens, AReport.Solve) then
      begin
        if AReport.Solve.Status = gssBacktrackLimit then
          AReport.Status := wcsBacktrackLimit
        else
          AReport.Status := wcsContradiction;
        AReport.FailureReason := 'Fixed whole-extent WFC solve did not complete';
        BuildReportText(AReport, ASeed);
        Exit;
      end;
      if Length(LTokens) <> WfcCompositionChordBars then
      begin
        AReport.Status := wcsCandidateRejected;
        AReport.FailureReason := 'Solver returned a path with the wrong bar count';
        BuildReportText(AReport, ASeed);
        Exit;
      end;
      AReport.TokenHash := TokensHash(LTokens);
      LCandidateComplete := True;
      for LIndex := 0 to High(LGeneratedSchedule) do
      begin
        if not TokenChord(LTokens[LIndex], LChord) then
        begin
          LCandidateComplete := False;
          Break;
        end;
        if not AllowedAt(LIndex, LChord) then
        begin
          LCandidateComplete := False;
          Break;
        end;
        LGeneratedSchedule[LIndex] := LChord;
      end;
      if not LCandidateComplete then
      begin
        AReport.Status := wcsCandidateRejected;
        AReport.FailureReason := 'Generated path violates the frozen vocabulary or positional masks';
        BuildReportText(AReport, ASeed);
        Exit;
      end;
      CalculateNovelty(LTokens, ASources, LFullSourceCopy,
        LFullSourceIndex, LPhraseCounts, LPhraseMasks);
      AReport.FullSourceCopy := LFullSourceCopy;
      AReport.FullSourceCopyIndex := LFullSourceIndex;
      for LIndex := 0 to 3 do
      begin
        AReport.PhraseUnionMatchCounts[LIndex] := LPhraseCounts[LIndex];
        AReport.PhraseUnionSourceMasks[LIndex] := LPhraseMasks[LIndex];
      end;
      if LFullSourceCopy then
      begin
        AReport.Status := wcsCandidateRejected;
        AReport.FailureReason := 'Generated path copies a complete source progression';
        BuildReportText(AReport, ASeed);
        Exit;
      end;
      LDefaultSchedule := DefaultSourceFreeCompositionChordSchedule;
      AReport.ChangedBarCount := 0;
      for LIndex := 0 to High(LGeneratedSchedule) do
        if LGeneratedSchedule[LIndex] <> LDefaultSchedule[LIndex] then
          Inc(AReport.ChangedBarCount);
      if AReport.ChangedBarCount < 2 then
      begin
        AReport.Status := wcsCandidateRejected;
        AReport.FailureReason := 'Generated schedule changes fewer than two fixed-composer bars';
        BuildReportText(AReport, ASeed);
        Exit;
      end;
      AReport.GeneratedSchedule := LGeneratedSchedule;
      AReport.GeneratedScheduleText := WfcCompositionScheduleText(LGeneratedSchedule);
      LBaseline := GenerateSourceFreeComposition(ASeed, LBaselineReport);
      LCandidate := GenerateCompositionWithChordSchedule(LGeneratedSchedule,
        ASeed, LCandidateReport);
      AReport.EventLedgerHash := HashUtf8(LCandidateReport.EventLedger);
      if not ComparePitchChanges(LCandidate, LBaseline,
        AReport.ChangedBassPitchCount, AReport.ChangedMelodyPitchCount) then
      begin
        AReport.Status := wcsCandidateRejected;
        AReport.FailureReason := 'Schedule projection changed note ownership or timing';
        BuildReportText(AReport, ASeed);
        Exit;
      end;
      if (AReport.ChangedBassPitchCount = 0) or
        (AReport.ChangedMelodyPitchCount = 0) then
      begin
        AReport.Status := wcsCandidateRejected;
        AReport.FailureReason := 'Projected schedule did not change both note parts';
        BuildReportText(AReport, ASeed);
        Exit;
      end;
      AReport.Status := wcsSolved;
      BuildReportText(AReport, ASeed);
      LPrevious := AOutput;
      AOutput := LCandidate;
      LCandidate := nil;
      LPrevious.Free;
      Result := True;
    except
      on E: Exception do
      begin
        if AReport.Status = wcsNotRun then
          AReport.Status := wcsInvalidSources
        else if AReport.Status = wcsSolved then
          AReport.Status := wcsCandidateRejected;
        AReport.FailureReason := E.ClassName + ': ' + E.Message;
        Result := False;
      end;
    end;
    if not Result then
      BuildReportText(AReport, ASeed);
  finally
    LCandidate.Free;
    LBaseline.Free;
    LModel.Free;
  end;
end;

end.
