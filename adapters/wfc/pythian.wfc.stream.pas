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
unit pythian.wfc.stream;

{$mode delphi}
{$H+}

interface

uses
  wfc,
  wfc_sequence,
  wfc_sequence_graph;

const
  SequenceStreamVersion = 1;

type
  TSequenceChunkOptions = record
    CellCount: Integer;
    Seed: TGraphSeed;
    MaxBacktracks: Integer;
    RequireObservedEnd: Boolean;
  end;

  { Sequential owner of one authenticated latent boundary. Model is immutable,
    borrowed and must outlive this object. Returned chunks are detached.
    No caller can replace the predecessor state. Reset starts a new sequence. }
  TLearnedSequenceStream = class
  strict private
    FModel: TWfcSequenceModel;
    FPreviousState: Integer;
    FCellCount: Int64;
    FCompleted: Boolean;
  public
    constructor Create(const AModel: TWfcSequenceModel);
    procedure Reset;
    { False means finite solver failure; report retains its reason. Exceptions
      and False preserve the cursor and caller's previous chunk. A successful
      end-marked chunk seals this stream until Reset. No future solvability claim. }
    function TryNext(const AOptions: TSequenceChunkOptions;
      const AConstraints: TWfcSequenceTokenConstraints;
      var AChunk: TWfcGeneratedSequenceSegment; out AReport: TGraphSolveReport): Boolean;
    property CellCount: Int64 read FCellCount;
    property Completed: Boolean read FCompleted;
  end;

function DefaultSequenceChunkOptions: TSequenceChunkOptions;

implementation

uses
  pythian.audio,
  pythian.wfc.generation;

function DefaultSequenceChunkOptions: TSequenceChunkOptions;
begin
  Result.CellCount := 256;
  Result.Seed := 731;
  Result.MaxBacktracks := 256;
  Result.RequireObservedEnd := False;
end;

constructor TLearnedSequenceStream.Create(const AModel: TWfcSequenceModel);
begin
  inherited Create;
  if AModel = nil then
  begin
    raise EAudio.Create('Sequence stream requires a model');
  end;
  FModel := AModel;
  Reset;
end;

procedure TLearnedSequenceStream.Reset;
begin
  FPreviousState := -1;
  FCellCount := 0;
  FCompleted := False;
end;

function TLearnedSequenceStream.TryNext(const AOptions: TSequenceChunkOptions;
  const AConstraints: TWfcSequenceTokenConstraints;
  var AChunk: TWfcGeneratedSequenceSegment; out AReport: TGraphSolveReport): Boolean;
var
  LGraph: TGraph;
  LBoundary: TWfcSequenceSegmentBoundary;
  LCandidate: TWfcGeneratedSequenceSegment;
  LValidation: TWfcSequenceGraphValidationReport;
  LSolve: TGraphSolveOptions;
  LFalsePosition: Integer;
begin
  if FCompleted then
  begin
    raise EAudio.Create('Sequence stream is complete; reset before generating again');
  end;
  if (AOptions.CellCount < 1) or
    (AOptions.CellCount > MaximumGeneratedAcousticFrames) or
    (Int64(AOptions.CellCount) * FModel.StateCount > DefaultAcousticStateCells) or
    (AOptions.MaxBacktracks < 0) or (AOptions.MaxBacktracks > 65536) or
    (Length(AConstraints) > AOptions.CellCount) or
    (FCellCount > High(Int64) - AOptions.CellCount) then
  begin
    raise EAudio.Create('Sequence chunk exceeds graph, constraint or timeline bounds');
  end;
  if FCellCount = 0 then
  begin
    LBoundary := MakeWfcSequenceInitialSegmentBoundary(AOptions.RequireObservedEnd);
  end
  else
  begin
    LBoundary := MakeWfcSequenceContinuingSegmentBoundary(FPreviousState,
      AOptions.RequireObservedEnd);
  end;
  LGraph := TGraph.Create;
  try
    LGraph.Reshape(AOptions.CellCount, 1, 1);
    LGraph.WrapNeighbors := False;
    LGraph.Seed := AOptions.Seed;
    ApplySequenceModelSegmentToGraph(FModel, LGraph, LBoundary);
    IntersectSequenceTokenConstraints(FModel, LGraph, AConstraints);
    LSolve := DefaultGraphSolveOptions;
    LSolve.MaxBacktracks := AOptions.MaxBacktracks;
    Result := LGraph.TrySolve(LSolve, AReport);
    if not Result then
    begin
      Exit;
    end;
    if not CaptureSolvedSequenceSegment(FModel, LGraph, LBoundary,
      LCandidate, LValidation) or
      not SequenceStatesSatisfyEntryConstraints(FModel, LGraph,
        LCandidate.StateIndices, LFalsePosition) then
    begin
      raise EAudio.Create('Solved sequence chunk failed boundary or constraint validation');
    end;
    { The only retained history is an integer from our own validated result.
      Caller edits to either returned array cannot change the next boundary. }
    AChunk := LCandidate;
    FPreviousState := LCandidate.StateIndices[High(LCandidate.StateIndices)];
    Inc(FCellCount, AOptions.CellCount);
    FCompleted := AOptions.RequireObservedEnd;
  finally
    LGraph.Free;
  end;
end;

end.
