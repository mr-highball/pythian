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
  pythian.progress,
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
    FBusy: Boolean;
    procedure RequireIdle;
  public
    constructor Create(const AModel: TWfcSequenceModel);
    procedure Reset;
    { False means finite solver failure; report retains its reason. Exceptions
      and False preserve the cursor and caller's previous chunk. A successful
      end-marked chunk seals this stream until Reset. No future solvability claim.
      Optional progress is synchronous and borrowed for this call only. It may
      abort, but must not mutate the model/inputs or reenter/reset this stream. }
    function TryNext(const AOptions: TSequenceChunkOptions;
      const AConstraints: TWfcSequenceTokenConstraints;
      var AChunk: TWfcGeneratedSequenceSegment; out AReport: TGraphSolveReport;
      const AProgress: TWorkProgressCallback = nil): Boolean;
    property CellCount: Int64 read FCellCount;
    property Completed: Boolean read FCompleted;
  end;

function DefaultSequenceChunkOptions: TSequenceChunkOptions;

implementation

uses
  pythian.audio,
  pythian.time,
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

procedure TLearnedSequenceStream.RequireIdle;
begin
  if FBusy then
  begin
    raise EAudio.Create('Sequence stream calls cannot reenter');
  end;
end;

procedure TLearnedSequenceStream.Reset;
begin
  RequireIdle;
  FPreviousState := -1;
  FCellCount := 0;
  FCompleted := False;
end;

function TLearnedSequenceStream.TryNext(const AOptions: TSequenceChunkOptions;
  const AConstraints: TWfcSequenceTokenConstraints;
  var AChunk: TWfcGeneratedSequenceSegment; out AReport: TGraphSolveReport;
  const AProgress: TWorkProgressCallback): Boolean;
var
  LBoundary: TWfcSequenceSegmentBoundary;
  LCandidate: TWfcGeneratedSequenceSegment;
  LOptions: TSequenceSegmentOptions;
  LPreviousState: Integer;
  LCellCount: Int64;
begin
  RequireIdle;
  if FCompleted then
  begin
    raise EAudio.Create('Sequence stream is complete; reset before generating again');
  end;
  if (AOptions.CellCount < 1) or
    (AOptions.CellCount > MaximumGeneratedAcousticFrames) or
    (Int64(AOptions.CellCount) * FModel.StateCount > DefaultAcousticStateCells) or
    (AOptions.MaxBacktracks < 0) or (AOptions.MaxBacktracks > 65536) or
    (Length(AConstraints) > AOptions.CellCount) or
    (FCellCount > MaximumTimingInteger - AOptions.CellCount) then
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
  LOptions := DefaultSequenceSegmentOptions;
  LOptions.CellCount := AOptions.CellCount;
  LOptions.Seed := AOptions.Seed;
  LOptions.MaxBacktracks := AOptions.MaxBacktracks;
  AReport := Default(TGraphSolveReport);
  FBusy := True;
  try
    ReportWork(AProgress, 'sequence_stream_chunk_ready', wuItems, 0, 1);
    Result := TryGenerateSequenceSegment(FModel, LOptions, LBoundary, AConstraints,
      LCandidate, AReport, AProgress);
    if not Result then
    begin
      Exit;
    end;
    LPreviousState := LCandidate.StateIndices[High(LCandidate.StateIndices)];
    LCellCount := FCellCount + AOptions.CellCount;
    ReportWork(AProgress, 'sequence_stream_chunk_ready', wuItems, 1, 1);
    { Detached music and all potentially failing work precede cursor acceptance. }
    AChunk := LCandidate;
    FPreviousState := LPreviousState;
    FCellCount := LCellCount;
    FCompleted := AOptions.RequireObservedEnd;
  finally
    FBusy := False;
  end;
end;

end.
