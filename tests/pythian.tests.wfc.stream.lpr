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
program pythian_tests_wfc_stream;

{$mode delphi}
{$H+}

uses
  SysUtils,
  pythian.audio,
  pythian.wfc.stream,
  wfc,
  wfc_model,
  wfc_sequence,
  wfc_sequence_learn,
  wfc_sequence_text,
  wfc_music_arrangement,
  wfc_sequence_graph;

{ Big Boss: exact context provider from the synthetic Studio hour request
  music-1793435527277-762351. It contains no recording bytes or operator data. }
const
  RetainedContextModel =
    'wfcs=1'#10 +
    'order=2'#10 +
    'samples=5'#10 +
    's=0,120'#10 + 's=1,120'#10 + 's=2,60'#10 + 's=3,120'#10 + 's=4,120'#10 +
    'tokens=10'#10 +
    't=0,ctx2%3A2%3Awme1%3A3%3Aa%3A1%3A45%3A112%3Aa%3A1%3A69%3A112%3Aa%3A1%3A57%3A112'#10 +
    't=1,ctx2%3A2%3Awme1%3A3%3Ah%3A1%3A45%3A112%3Ah%3A1%3A69%3A112%3Ah%3A1%3A57%3A112'#10 +
    't=2,ctx2%3A2%3Awme1%3A3%3Ah%3A1%3A45%3A112%3Ah%3A1%3A69%3A112%3Aa%3A1%3A81%3A112'#10 +
    't=3,ctx2%3A2%3Awme1%3A3%3Ah%3A1%3A45%3A112%3Ah%3A1%3A69%3A112%3Ah%3A1%3A81%3A112'#10 +
    't=4,ctx2%3A2%3Awme1%3A3%3Aa%3A1%3A45%3A112%3Aa%3A1%3A69%3A112%3Aa%3A1%3A81%3A112'#10 +
    't=5,ctx2%3A2%3Awme1%3A3%3Aa%3A1%3A41%3A112%3Aa%3A2%3A63%3A112%3A65%3A112%3Aa%3A1%3A64%3A112'#10 +
    't=6,ctx2%3A2%3Awme1%3A3%3Ah%3A1%3A41%3A112%3Ah%3A2%3A63%3A112%3A65%3A112%3Ah%3A1%3A64%3A112'#10 +
    't=7,ctx2%3A2%3Awme1%3A3%3Ah%3A1%3A41%3A112%3Ah%3A2%3A63%3A112%3A65%3A112%3Aa%3A1%3A77%3A112'#10 +
    't=8,ctx2%3A2%3Awme1%3A3%3Ah%3A1%3A41%3A112%3Ah%3A2%3A63%3A112%3A65%3A112%3Ah%3A1%3A77%3A112'#10 +
    't=9,ctx2%3A2%3Awme1%3A3%3Aa%3A1%3A41%3A112%3Aa%3A2%3A63%3A112%3A65%3A112%3Aa%3A1%3A77%3A112'#10 +
    'states=14'#10 +
    'q=0,3,3,0,B,E0'#10 + 'q=1,3,0,0,T0,E1'#10 + 'q=2,90,0,0,T1,E1'#10 +
    'q=3,3,0,0,T1,E2'#10 + 'q=4,3,0,0,T2,E3'#10 + 'q=5,195,0,0,T3,E3'#10 +
    'q=6,3,0,3,T3,E4'#10 + 'q=7,2,2,0,B,E5'#10 + 'q=8,2,0,0,T5,E6'#10 +
    'q=9,60,0,0,T6,E6'#10 + 'q=10,2,0,0,T6,E7'#10 + 'q=11,2,0,0,T7,E8'#10 +
    'q=12,170,0,0,T8,E8'#10 + 'q=13,2,0,2,T8,E9'#10 + 'end'#10;

procedure Check(const ACondition: Boolean; const AMessage: String);
begin
  if not ACondition then
  begin
    raise Exception.Create(AMessage);
  end;
end;

procedure CheckHistoryAndFailure;
var
  LSamples: TWfcSequenceSamples;
  LModel: TWfcSequenceModel;
  LStream: TLearnedSequenceStream;
  LOptions: TSequenceChunkOptions;
  LConstraints: TWfcSequenceTokenConstraints;
  LChunk: TWfcGeneratedSequenceSegment;
  LReport: TGraphSolveReport;
  LRejected: Boolean;
  LRun: Integer;
begin
  SetLength(LSamples, 2);
  LSamples[0] := MakeWfcSequenceSample(['a', 'x', 'c', 'end']);
  LSamples[1] := MakeWfcSequenceSample(['b', 'x', 'd', 'end']);
  LModel := LearnSequenceModelCorpus(LSamples, 3);
  LStream := nil;
  try
    LStream := TLearnedSequenceStream.Create(LModel);
    LOptions := DefaultSequenceChunkOptions;
    LOptions.CellCount := 2;
    SetLength(LConstraints, 1);
    for LRun := 0 to 2 do
    begin
      LStream.Reset;
      LOptions.RequireObservedEnd := False;
      if LRun = 2 then
      begin
        LConstraints[0] := MakeWfcSequenceTokenConstraint(0, ['b']);
      end
      else
      begin
        LConstraints[0] := MakeWfcSequenceTokenConstraint(0, ['a']);
      end;
      Check(LStream.TryNext(LOptions, LConstraints, LChunk, LReport), 'Initial segment');
      Check((LChunk.Tokens[1] = 'x') and (LStream.CellCount = 2), 'Shared public suffix');
      { Hostile caller edits must not forge the retained order-3 predecessor. }
      LChunk.StateIndices[1] := -1;
      LChunk.Tokens[0] := 'sentinel';
      LOptions.RequireObservedEnd := True;
      if LRun = 2 then
      begin
        LConstraints[0] := MakeWfcSequenceTokenConstraint(0, ['c']);
      end
      else
      begin
        LConstraints[0] := MakeWfcSequenceTokenConstraint(0, ['d']);
      end;
      Check(not LStream.TryNext(LOptions, LConstraints, LChunk, LReport),
        'Wrong continuation must contradict retained latent history');
      Check((LReport.Status = gssContradiction) and (LStream.CellCount = 2) and
        not LStream.Completed and (LChunk.Tokens[0] = 'sentinel') and
        (LChunk.StateIndices[1] = -1), 'Failed chunk preserves cursor and complete prior output');
      LOptions.CellCount := 0;
      LRejected := False;
      try
        LStream.TryNext(LOptions, nil, LChunk, LReport);
      except
        on EAudio do
        begin
          LRejected := True;
        end;
      end;
      Check(LRejected and (LStream.CellCount = 2), 'Invalid request preserves history');
      LOptions.CellCount := 2;
      Check(LStream.TryNext(LOptions, nil, LChunk, LReport), 'Retry after failure');
      if LRun = 2 then
      begin
        Check(LChunk.Tokens[0] = 'd', 'Reset accepts a different full history');
      end
      else
      begin
        Check(LChunk.Tokens[0] = 'c', 'Higher-order context survives chunk boundary and replay');
      end;
      Check((LChunk.Tokens[1] = 'end') and LStream.Completed and
        (LStream.CellCount = 4), 'Observed end seals stream');
      LRejected := False;
      try
        LStream.TryNext(LOptions, nil, LChunk, LReport);
      except
        on EAudio do
        begin
          LRejected := True;
        end;
      end;
      Check(LRejected and (LStream.CellCount = 4) and (LChunk.Tokens[1] = 'end'),
        'Completed stream rejects further generation without losing output');
    end;
  finally
    LStream.Free;
    LModel.Free;
  end;
end;

procedure CheckLongSequence;
var
  LSamples: TWfcSequenceSamples;
  LModel: TWfcSequenceModel;
  LStream: TLearnedSequenceStream;
  LOptions: TSequenceChunkOptions;
  LChunk: TWfcGeneratedSequenceSegment;
  LReport: TGraphSolveReport;
  LStates: TWfcSequenceStateIndices;
  LValidation: TWfcSequenceGraphValidationReport;
  LSegment: Integer;
  LIndex: Integer;
  LCount: Integer;
begin
  SetLength(LSamples, 1);
  LSamples[0] := MakeWfcSequenceSample(['a', 'b', 'a', 'b', 'a']);
  LModel := LearnSequenceModelCorpus(LSamples, 2);
  LStream := nil;
  try
    LStream := TLearnedSequenceStream.Create(LModel);
    LOptions := DefaultSequenceChunkOptions;
    SetLength(LStates, 1601);
    LCount := 0;
    for LSegment := 0 to 49 do
    begin
      LOptions.CellCount := 32;
      LOptions.Seed := 731 + LSegment;
      LOptions.RequireObservedEnd := LSegment = 49;
      if LOptions.RequireObservedEnd then
      begin
        Inc(LOptions.CellCount);
      end;
      Check(LStream.TryNext(LOptions, nil, LChunk, LReport), 'Long sequence chunk');
      for LIndex := 0 to High(LChunk.Tokens) do
      begin
        if LCount mod 2 = 0 then
        begin
          Check(LChunk.Tokens[LIndex] = 'a', 'Independent even-token oracle');
        end
        else
        begin
          Check(LChunk.Tokens[LIndex] = 'b', 'Independent odd-token oracle');
        end;
        LStates[LCount] := LChunk.StateIndices[LIndex];
        Inc(LCount);
      end;
    end;
    Check((LStream.CellCount = 1601) and LStream.Completed, 'Beyond single-graph extent');
    Check(ValidateSequenceStatePath(LModel, LStates, wseWhole, LValidation),
      'Combined chunks form one valid actual WFC path including every seam and endpoints');
  finally
    LStream.Free;
    LModel.Free;
  end;
end;

procedure CheckRetainedContextContinuation;
var
  LModel: TWfcSequenceModel;
  LStream: TLearnedSequenceStream;
  LOptions: TSequenceChunkOptions;
  LChunk: TWfcGeneratedSequenceSegment;
  LReport: TGraphSolveReport;
  LStates: TWfcSequenceStateIndices;
  LValidation: TWfcSequenceGraphValidationReport;
  LSegment: Integer;
  I: Integer;
begin
  LModel := DecodeWfcSequenceText(RetainedContextModel);
  LStream := nil;
  try
    LStream := TLearnedSequenceStream.Create(LModel);
    LOptions := DefaultSequenceChunkOptions;
    LOptions.CellCount := 16;
    for LSegment := 0 to 41 do
    begin
      LOptions.Seed := WfcMusicArrangementSectionSeed(2066483829, LSegment);
      if LSegment < 41 then
        Check(LStream.TryNext(LOptions, nil, LChunk, LReport), 'Retained original prefix')
      else
      begin
        Check(not LStream.TryNext(LOptions, nil, LChunk, LReport) and
          (LReport.Status = gssContradiction) and (LStream.CellCount = 656),
          'Exact original seed reproduces terminal-exit failure at656 without exit support');
      end;
    end;
    LStream.Reset;
    SetLength(LStates, 14400);
    for LSegment := 0 to 899 do
    begin
      LOptions.Seed := WfcMusicArrangementSectionSeed(2066483829, LSegment);
      LOptions.MinimumFollowingCells := 14400 - (LSegment + 1) * 16;
      Check(LStream.TryNext(LOptions, nil, LChunk, LReport),
        'Retained provider and exact seed plan the requested hour with supported exits');
      for I := 0 to High(LChunk.StateIndices) do
        LStates[LSegment * 16 + I] := LChunk.StateIndices[I];
    end;
    Check((LStream.CellCount = 14400) and
      ValidateSequenceStatePath(LModel, LStates, wsePrefix, LValidation),
      'Whole retained hour path independently validates every learned transition');
    LChunk.Tokens[0] := 'preserved';
    LOptions.MinimumFollowingCells := -1;
    try
      LStream.TryNext(LOptions, nil, LChunk, LReport);
      Check(False, 'Negative continuation requirement must reject');
    except
      on E: EAudio do
        Check((LStream.CellCount = 14400) and (LChunk.Tokens[0] = 'preserved'),
          'Bad continuation request preserves the accepted cursor and output');
    end;
  finally
    LStream.Free;
    LModel.Free;
  end;
end;

begin
  CheckHistoryAndFailure;
  CheckLongSequence;
  CheckRetainedContextContinuation;
  WriteLn('Learned stream history, retry,1601-cell path and retained14400-cell continuation passed');
end.

