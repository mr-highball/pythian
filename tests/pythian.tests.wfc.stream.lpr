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
  wfc_sequence_graph;

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

begin
  try
    CheckHistoryAndFailure;
    CheckLongSequence;
    WriteLn('Learned streaming history, retry preservation, reset and 1601-cell path passed');
  except
    on LException: Exception do
    begin
      WriteLn(StdErr, LException.ClassName, ': ', LException.Message);
      Halt(1);
    end;
  end;
end.

