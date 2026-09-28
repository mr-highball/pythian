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
program pythian_tests_journal_context_guard;

{$mode delphi}
{$H+}

uses
  SysUtils, pythian.audio, pythian.learning, pythian.learning.journal,
  pythian.learning.selection, pythian.learning.context,
  pythian.learning.context.guard;

procedure Require(const AValue: Boolean; const AMessage: String);
begin
  if not AValue then raise EAudio.Create(AMessage);
end;

function Slots(const AValues: array of Integer): TAcousticIndices;
var LIndex: Integer;
begin
  SetLength(Result, Length(AValues));
  for LIndex := 0 to High(Result) do Result[LIndex] := AValues[LIndex];
end;

function Windows(const APool: TJournalCandidatePool;
  const AValues: array of Integer): TJournalContextWindows;
var LIndex: Integer;
begin
  SetLength(Result, Length(AValues));
  for LIndex := 0 to High(Result) do
  begin
    Result[LIndex].Token := APool.TokenAt(AValues[LIndex]);
    Result[LIndex].Candidate := APool.CandidateAt(AValues[LIndex]);
  end;
end;

function MakePool: TJournalCandidatePool;
var LRows: TJournalRepresentatives; LIndex: Integer;
begin
  SetLength(LRows, 16);
  for LIndex := 0 to High(LRows) do
  begin
    LRows[LIndex].Found := True;
    LRows[LIndex].SegmentIndex := 0;
    LRows[LIndex].FeatureIndex := LIndex;
    LRows[LIndex].SourceFrame := LIndex * 4;
    LRows[LIndex].ValidFrames := 8;
  end;
  Result := TJournalCandidatePool.CreateFromCandidates(1, 1, 16, LRows);
end;

procedure RejectUnchanged(const AGuard: TJournalGlobalRepetitionGuard;
  const ABase: TAcousticIndices; const AContext: TJournalContextWindows);
var
  LOldCount: Integer;
  LOldVisits: Int64;
  LReport: TJournalNoveltyReport;
  LFailed: Boolean;
begin
  LOldCount := AGuard.GrainCount;
  LOldVisits := AGuard.WorkVisits;
  LFailed := False;
  try AGuard.SelectChunk(ABase, AContext, LReport)
  except on EAudio do LFailed := True end;
  Require(LFailed and (AGuard.GrainCount = LOldCount) and
    (AGuard.WorkVisits = LOldVisits), 'Failed guard chunk mutated history');
end;

procedure CheckGuard(const APool: TJournalCandidatePool);
var
  LGuard, LLowCap: TJournalGlobalRepetitionGuard;
  LReport: TJournalNoveltyReport;
  LOut, LBad: TJournalContextWindows;
begin
  LGuard := TJournalGlobalRepetitionGuard.Create(APool, 12);
  try
    LOut := LGuard.SelectChunk(Slots([0,1,2,3]),
      Windows(APool,[0,1,2,3]), LReport);
    Require(LReport.ContextAccepted and (LReport.SelectedRepeatedFour = 0) and
      (LReport.FirstRejectedGrain = -1) and (Length(LOut) = 4),
      'Initial chunk not accepted');
    LOut := LGuard.SelectChunk(Slots([4,5,6,7]),
      Windows(APool,[4,5,6,7]), LReport);
    Require(LReport.ContextAccepted and (LGuard.GrainCount = 8),
      'Second chunk not accepted');
    LOut := LGuard.SelectChunk(Slots([8,9,10,11]),
      Windows(APool,[2,3,4,5]), LReport);
    Require((not LReport.ContextAccepted) and
      (LReport.FirstRejectedGrain = 11) and
      (LReport.BaselineRepeatedFour = 0) and
      (LReport.SelectedRepeatedFour = 0) and
      (LOut[0].Candidate.FeatureIndex = 8) and
      (LGuard.GrainCount = 12), 'Cross-chunk four-tuple fallback failed');
    RejectUnchanged(LGuard, Slots([0]), Windows(APool,[0]));
  finally LGuard.Free end;

  LGuard := TJournalGlobalRepetitionGuard.Create(APool, 8);
  try
    LOut := LGuard.SelectChunk(Slots([0,1,2,3]),
      Windows(APool,[4,5,6,7]), LReport);
    Require(LReport.ContextAccepted and (LOut[0].Candidate.FeatureIndex = 4),
      'Context selection missing');
    { The candidate repeats the first selected tuple. The baseline fallback
      differs, so this is a valid whole-chunk rejection. }
    LOut := LGuard.SelectChunk(Slots([8,9,10,11]),
      Windows(APool,[4,5,6,7]), LReport);
    Require((not LReport.ContextAccepted) and
      (LReport.FirstRejectedGrain = 7) and
      (LOut[0].Candidate.FeatureIndex = 8),
      'Repeated context chunk was not rejected');
  finally LGuard.Free end;

  LGuard := TJournalGlobalRepetitionGuard.Create(APool, 8);
  try
    LGuard.SelectChunk(Slots([0,1,2,3]),
      Windows(APool,[4,5,6,7]), LReport);
    { Both the context and the baseline fallback repeat 4,5,6,7. }
    RejectUnchanged(LGuard, Slots([4,5,6,7]),
      Windows(APool,[4,5,6,7]));
    LBad := Windows(APool,[8,9,10,11]);
    LBad[1].Candidate.SourceFrame := -1;
    RejectUnchanged(LGuard, Slots([8,9,10,11]), LBad);
    LBad := Windows(APool,[8,9,10,11]);
    LBad[1].Token := 1;
    RejectUnchanged(LGuard, Slots([8,9,10,11]), LBad);
    LOut := LGuard.SelectChunk(Slots([8,9,10,11]),
      Windows(APool,[8,9,10,11]), LReport);
    Require(LReport.ContextAccepted and (LGuard.GrainCount = 8),
      'Guard could not continue after rollback');
  finally LGuard.Free end;

  LLowCap := TJournalGlobalRepetitionGuard.Create(APool, 8, 1);
  try
    RejectUnchanged(LLowCap, Slots([0,1,2,3]),
      Windows(APool,[0,1,2,3]));
  finally LLowCap.Free end;
end;

var LPool: TJournalCandidatePool; LFailed: Boolean;
begin
  LPool := MakePool;
  try
    CheckGuard(LPool);
    LFailed := False;
    try TJournalGlobalRepetitionGuard.Create(LPool,
      MaximumJournalGuardGrains + 1)
    except on EAudio do LFailed := True end;
    Require(LFailed, 'Excess guard capacity accepted');
    WriteLn('PASS journal global repetition guard');
  finally LPool.Free end;
end.
