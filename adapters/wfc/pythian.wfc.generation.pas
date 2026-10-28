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
unit pythian.wfc.generation;

{$mode delphi}
{$H+}

interface

uses
  pythian.learning,
  pythian.progress,
  wfc,
  wfc_model,
  wfc_sequence;

const
  AcousticGenerationVersion = 1;
  MaximumGeneratedAcousticFrames = 1024;
  DefaultAcousticStateCells = 262144;
  MaximumAcousticStateCells = 1048576;

type
  TAcousticGenerationOptions = record
    FrameCount: Integer;
    Seed: TGraphSeed;
    Extent: TWfcSequenceExtent;
    MaxBacktracks: Integer;
    { Logical positions times model states, not a byte or elapsed-time limit.
      Explicit opt-in above the default; bounded by MaximumAcousticStateCells. }
    StateCellBudget: Integer;
  end;

function DefaultAcousticGenerationOptions: TAcousticGenerationOptions;
{ The model is borrowed. Constraints use actual WFC token/position semantics.
  Failure preserves AIndices; AReport distinguishes contradiction from exhausted
  backtracking. Invalid requests raise before publishing any output. Optional
  borrowed progress reaches primary WFC preparation/search/guarded commit work.
  Observer cancellation preserves caller output. Primary capture/path/domain
  checks forward companion sequence work. Graph setup, RTL copies and bounded
  accessors remain synchronous; solve completion does not certify publication. }
function TryGenerateAcousticSequence(const AModel: TWfcSequenceModel;
  const AOptions: TAcousticGenerationOptions;
  const AConstraints: TWfcSequenceTokenConstraints;
  var AIndices: TAcousticIndices; out AReport: TGraphSolveReport;
  const AProgress: TWorkProgressCallback = nil): Boolean;

function TryGenerateTokenSequence(const AModel: TWfcSequenceModel;
  const AOptions: TAcousticGenerationOptions;
  const AConstraints: TWfcSequenceTokenConstraints;
  var ATokens: TWfcModelTokens; out AReport: TGraphSolveReport;
  const AProgress: TWorkProgressCallback = nil): Boolean;

implementation

uses
  pythian.audio,
  pythian.wfc.learning,
  pythian.wfc.progress,
  wfc_sequence_graph;

function DefaultAcousticGenerationOptions: TAcousticGenerationOptions;
begin
  Result.FrameCount := 256;
  Result.Seed := 731;
  Result.Extent := wseFragment;
  Result.MaxBacktracks := 256;
  Result.StateCellBudget := DefaultAcousticStateCells;
end;

function TryGenerateTokenSequence(const AModel: TWfcSequenceModel;
  const AOptions: TAcousticGenerationOptions;
  const AConstraints: TWfcSequenceTokenConstraints;
  var ATokens: TWfcModelTokens; out AReport: TGraphSolveReport;
  const AProgress: TWorkProgressCallback): Boolean;
var
  LGraph: TGraph;
  LSolveOptions: TGraphSolveOptions;
  LGenerated: TWfcGeneratedSequence;
  LValidation: TWfcSequenceGraphValidationReport;
  LFalsePosition: Integer;
  LProgress: TWfcSolveProgressBridge;
  LPublished: TWfcModelTokens;
begin
  if AModel = nil then
  begin
    raise EAudio.Create('Acoustic sequence model is required');
  end;
  if (AOptions.FrameCount < 1) or
    (AOptions.FrameCount > MaximumGeneratedAcousticFrames) or
    (AOptions.MaxBacktracks < 0) or (AOptions.MaxBacktracks > 65536) or
    (AOptions.StateCellBudget < 1) or
    (AOptions.StateCellBudget > MaximumAcousticStateCells) then
  begin
    raise EAudio.Create('Acoustic generation request exceeds bounded graph contract');
  end;
  if Int64(AOptions.FrameCount) * AModel.StateCount > AOptions.StateCellBudget then
  begin
    raise EAudio.CreateFmt(
      'Acoustic generation requires %d state cells (%d frames x %d states); ' +
      'limit is %d (%d frames for this model)',
      [Int64(AOptions.FrameCount) * AModel.StateCount, AOptions.FrameCount,
      AModel.StateCount, AOptions.StateCellBudget,
      AOptions.StateCellBudget div AModel.StateCount]);
  end;
  if Length(AConstraints) > AOptions.FrameCount then
  begin
    raise EAudio.Create('Too many acoustic position constraints');
  end;
  LGraph := TGraph.Create;
  LProgress := nil;
  try
    if Assigned(AProgress) then
    begin
      LProgress := TWfcSolveProgressBridge.Create(AProgress);
    end;
    LGraph.Reshape(AOptions.FrameCount, 1, 1);
    LGraph.WrapNeighbors := AOptions.Extent = wseWrap;
    LGraph.Seed := AOptions.Seed;
    ApplySequenceModelToGraph(AModel, LGraph, AOptions.Extent);
    IntersectSequenceTokenConstraints(AModel, LGraph, AConstraints);
    LSolveOptions := DefaultGraphSolveOptions;
    LSolveOptions.MaxBacktracks := AOptions.MaxBacktracks;
    Result := LGraph.TrySolve(LSolveOptions, AReport, WfcSolveObserver(LProgress));
    if not Result then
    begin
      Exit;
    end;
    if not CaptureSolvedSequence(AModel, LGraph, AOptions.Extent,
      LGenerated, LValidation, WfcSequenceWorkObserver(LProgress)) then
    begin
      raise EAudio.Create('Generated acoustic path failed WFC validation');
    end;
    if not SequenceStatesSatisfyEntryConstraints(AModel, LGraph,
      LGenerated.StateIndices, LFalsePosition, WfcSequenceWorkObserver(LProgress)) then
    begin
      raise EAudio.Create('Generated acoustic path violated a caller constraint');
    end;
    LPublished := Copy(LGenerated.Tokens);
    ReportWork(AProgress, 'sequence_publication_ready', wuItems, 1, 1);
    ATokens := LPublished;
  finally
    LProgress.Free;
    LGraph.Free;
  end;
end;

function TryGenerateAcousticSequence(const AModel: TWfcSequenceModel;
  const AOptions: TAcousticGenerationOptions;
  const AConstraints: TWfcSequenceTokenConstraints;
  var AIndices: TAcousticIndices; out AReport: TGraphSolveReport;
  const AProgress: TWorkProgressCallback): Boolean;
var
  LTokens: TWfcModelTokens;
  LIndices: TAcousticIndices;
  LIndex: Integer;
begin
  if AModel = nil then
  begin
    raise EAudio.Create('Acoustic sequence model is required');
  end;
  ReportWork(AProgress, 'acoustic_validate_tokens', wuItems, 0, AModel.PublicTokenCount);
  for LIndex := 0 to AModel.PublicTokenCount - 1 do
  begin
    AcousticTokenIndex(AModel.PublicTokenAt(LIndex));
    if ((LIndex + 1) mod 64 = 0) or (LIndex + 1 = AModel.PublicTokenCount) then
      ReportWork(AProgress, 'acoustic_validate_tokens', wuItems, LIndex + 1, AModel.PublicTokenCount);
  end;
  Result := TryGenerateTokenSequence(AModel, AOptions, AConstraints, LTokens, AReport, AProgress);
  if not Result then
  begin
    Exit;
  end;
  SetLength(LIndices, Length(LTokens));
  ReportWork(AProgress, 'acoustic_project_tokens', wuItems, 0, Length(LTokens));
  for LIndex := 0 to High(LTokens) do
  begin
    LIndices[LIndex] := AcousticTokenIndex(LTokens[LIndex]);
    if ((LIndex + 1) mod 64 = 0) or (LIndex + 1 = Length(LTokens)) then
      ReportWork(AProgress, 'acoustic_project_tokens', wuItems, LIndex + 1, Length(LTokens));
  end;
  ReportWork(AProgress, 'acoustic_publication_ready', wuItems, 1, 1);
  AIndices := LIndices;
end;

end.
