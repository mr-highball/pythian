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
  backtracking. Invalid requests raise before publishing any output. }
function TryGenerateAcousticSequence(const AModel: TWfcSequenceModel;
  const AOptions: TAcousticGenerationOptions;
  const AConstraints: TWfcSequenceTokenConstraints;
  var AIndices: TAcousticIndices; out AReport: TGraphSolveReport): Boolean;

function TryGenerateTokenSequence(const AModel: TWfcSequenceModel;
  const AOptions: TAcousticGenerationOptions;
  const AConstraints: TWfcSequenceTokenConstraints;
  var ATokens: TWfcModelTokens; out AReport: TGraphSolveReport): Boolean;

implementation

uses
  pythian.audio,
  pythian.wfc.learning,
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
  var ATokens: TWfcModelTokens; out AReport: TGraphSolveReport): Boolean;
var
  LGraph: TGraph;
  LSolveOptions: TGraphSolveOptions;
  LGenerated: TWfcGeneratedSequence;
  LValidation: TWfcSequenceGraphValidationReport;
  LFalsePosition: Integer;
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
  try
    LGraph.Reshape(AOptions.FrameCount, 1, 1);
    LGraph.WrapNeighbors := AOptions.Extent = wseWrap;
    LGraph.Seed := AOptions.Seed;
    ApplySequenceModelToGraph(AModel, LGraph, AOptions.Extent);
    IntersectSequenceTokenConstraints(AModel, LGraph, AConstraints);
    LSolveOptions := DefaultGraphSolveOptions;
    LSolveOptions.MaxBacktracks := AOptions.MaxBacktracks;
    Result := LGraph.TrySolve(LSolveOptions, AReport);
    if not Result then
    begin
      Exit;
    end;
    if not CaptureSolvedSequence(AModel, LGraph, AOptions.Extent,
      LGenerated, LValidation) then
    begin
      raise EAudio.Create('Generated acoustic path failed WFC validation');
    end;
    if not SequenceStatesSatisfyEntryConstraints(AModel, LGraph,
      LGenerated.StateIndices, LFalsePosition) then
    begin
      raise EAudio.Create('Generated acoustic path violated a caller constraint');
    end;
    ATokens := Copy(LGenerated.Tokens);
  finally
    LGraph.Free;
  end;
end;

function TryGenerateAcousticSequence(const AModel: TWfcSequenceModel;
  const AOptions: TAcousticGenerationOptions;
  const AConstraints: TWfcSequenceTokenConstraints;
  var AIndices: TAcousticIndices; out AReport: TGraphSolveReport): Boolean;
var
  LTokens: TWfcModelTokens;
  LIndices: TAcousticIndices;
  LIndex: Integer;
begin
  if AModel = nil then
  begin
    raise EAudio.Create('Acoustic sequence model is required');
  end;
  for LIndex := 0 to AModel.PublicTokenCount - 1 do
  begin
    AcousticTokenIndex(AModel.PublicTokenAt(LIndex));
  end;
  Result := TryGenerateTokenSequence(AModel, AOptions, AConstraints, LTokens, AReport);
  if not Result then
  begin
    Exit;
  end;
  SetLength(LIndices, Length(LTokens));
  for LIndex := 0 to High(LTokens) do
  begin
    LIndices[LIndex] := AcousticTokenIndex(LTokens[LIndex]);
  end;
  AIndices := LIndices;
end;

end.
