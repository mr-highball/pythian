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
  pythian.wfc.layers,
  wfc,
  wfc_model,
  wfc_sequence,
  wfc_sequence_graph;

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

  { Stateless finite-segment workload. The caller supplies its exact authenticated
    initial/continuing boundary separately; no cursor or observer is retained. }
  TSequenceSegmentOptions = record
    CellCount: Integer;
    Seed: TGraphSeed;
    MaxBacktracks: Integer;
    StateCellBudget: Integer;
    Preferences: TLayerTokenPreferences;
  end;

function DefaultSequenceSegmentOptions: TSequenceSegmentOptions;
{ Shared private-graph build/solve/proof path for sequential and duration users.
  Repeated constraint positions retain the companion's intersection semantics.
  False and original observer exceptions preserve ASequence. All callbacks run
  before its detached result is published. This does not advance a caller cursor. }
function TryGenerateSequenceSegment(const AModel: TWfcSequenceModel;
  const AOptions: TSequenceSegmentOptions;
  const ABoundary: TWfcSequenceSegmentBoundary;
  const AConstraints: TWfcSequenceTokenConstraints;
  var ASequence: TWfcGeneratedSequenceSegment; out AReport: TGraphSolveReport;
  const AProgress: TWorkProgressCallback = nil): Boolean;
{ Detached copies/joins remain private through their final callback. Joining
  requires an initial prefix and the exact suffix predecessor; these helpers
  copy already authenticated data and do not certify a model path. }
function CopySequenceSegment(const AValue: TWfcGeneratedSequenceSegment;
  const AProgress: TWorkProgressCallback = nil): TWfcGeneratedSequenceSegment;
function JoinSequenceSegments(const APrefix, ASuffix: TWfcGeneratedSequenceSegment;
  const APrefixCount: Integer;
  const AProgress: TWorkProgressCallback = nil): TWfcGeneratedSequenceSegment;

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
  pythian.wfc.progress;

procedure RequireGenerationBounds(const AModel: TWfcSequenceModel;
  const ACellCount, AMaxBacktracks, AStateCellBudget: Integer);
begin
  if AModel = nil then
  begin
    raise EAudio.Create('Acoustic sequence model is required');
  end;
  if (ACellCount < 1) or
    (ACellCount > MaximumGeneratedAcousticFrames) or
    (AMaxBacktracks < 0) or (AMaxBacktracks > 65536) or
    (AStateCellBudget < 1) or
    (AStateCellBudget > MaximumAcousticStateCells) then
  begin
    raise EAudio.Create('Acoustic generation request exceeds bounded graph contract');
  end;
  if Int64(ACellCount) * AModel.StateCount > AStateCellBudget then
  begin
    raise EAudio.CreateFmt(
      'Acoustic generation requires %d state cells (%d frames x %d states); ' +
      'limit is %d (%d frames for this model)',
      [Int64(ACellCount) * AModel.StateCount, ACellCount,
      AModel.StateCount, AStateCellBudget,
      AStateCellBudget div AModel.StateCount]);
  end;
end;

function DefaultSequenceSegmentOptions: TSequenceSegmentOptions;
begin
  Result := Default(TSequenceSegmentOptions);
  Result.CellCount := 256;
  Result.Seed := 731;
  Result.MaxBacktracks := 256;
  Result.StateCellBudget := DefaultAcousticStateCells;
end;

function CopySequenceSegment(const AValue: TWfcGeneratedSequenceSegment;
  const AProgress: TWorkProgressCallback): TWfcGeneratedSequenceSegment;
var
  LCandidate: TWfcGeneratedSequenceSegment;
  LIndex: Integer;
  LWork: TWfcObservedWork;
begin
  if Length(AValue.StateIndices) <> Length(AValue.Tokens) then
  begin
    raise EAudio.Create('Segment state and token lengths differ');
  end;
  LWork := TWfcObservedWork.Create(AProgress, 'sequence_segment_copy_visits');
  try
    LCandidate := Default(TWfcGeneratedSequenceSegment);
    LCandidate.Boundary := AValue.Boundary;
    SetLength(LCandidate.StateIndices, Length(AValue.StateIndices));
    SetLength(LCandidate.Tokens, Length(AValue.Tokens));
    for LIndex := 0 to High(AValue.StateIndices) do
    begin
      LCandidate.StateIndices[LIndex] := AValue.StateIndices[LIndex];
      LWork.Visit;
      LCandidate.Tokens[LIndex] := AValue.Tokens[LIndex];
      LWork.Visit;
    end;
    LWork.Finish;
    ReportWork(AProgress, 'sequence_segment_copy_ready', wuItems, 1, 1);
    Result := LCandidate;
  finally
    LWork.Free;
  end;
end;

function JoinSequenceSegments(const APrefix, ASuffix: TWfcGeneratedSequenceSegment;
  const APrefixCount: Integer;
  const AProgress: TWorkProgressCallback): TWfcGeneratedSequenceSegment;
var
  LCandidate: TWfcGeneratedSequenceSegment;
  LIndex: Integer;
  LWork: TWfcObservedWork;
begin
  if (APrefixCount < 0) or (APrefixCount > Length(APrefix.StateIndices)) or
    (Length(APrefix.StateIndices) <> Length(APrefix.Tokens)) or
    (Length(ASuffix.StateIndices) <> Length(ASuffix.Tokens)) or
    (Int64(APrefixCount) + Length(ASuffix.StateIndices) > High(Integer)) then
  begin
    raise EAudio.Create('Segment join lengths or prefix extent are invalid');
  end;
  if (ASuffix.Boundary.HasPrevious <> (APrefixCount > 0)) or
    ((APrefixCount > 0) and APrefix.Boundary.HasPrevious) then
  begin
    raise EAudio.Create('Segment join requires an initial prefix and matching continuation');
  end;
  if (APrefixCount > 0) and
    (ASuffix.Boundary.PreviousState <> APrefix.StateIndices[APrefixCount - 1]) then
  begin
    raise EAudio.Create('Segment join predecessor differs from its retained prefix');
  end;
  LWork := TWfcObservedWork.Create(AProgress, 'sequence_segment_join_visits');
  try
    LCandidate := Default(TWfcGeneratedSequenceSegment);
    LCandidate.Boundary := MakeWfcSequenceInitialSegmentBoundary(
      ASuffix.Boundary.RequireObservedEnd);
    SetLength(LCandidate.StateIndices, APrefixCount + Length(ASuffix.StateIndices));
    SetLength(LCandidate.Tokens, Length(LCandidate.StateIndices));
    for LIndex := 0 to High(LCandidate.Tokens) do
    begin
      if LIndex < APrefixCount then
      begin
        LCandidate.StateIndices[LIndex] := APrefix.StateIndices[LIndex];
        LCandidate.Tokens[LIndex] := APrefix.Tokens[LIndex];
      end
      else
      begin
        LCandidate.StateIndices[LIndex] := ASuffix.StateIndices[LIndex - APrefixCount];
        LCandidate.Tokens[LIndex] := ASuffix.Tokens[LIndex - APrefixCount];
      end;
      LWork.Visit;
      LWork.Visit;
    end;
    LWork.Finish;
    ReportWork(AProgress, 'sequence_segment_join_ready', wuItems, 1, 1);
    Result := LCandidate;
  finally
    LWork.Free;
  end;
end;

function TryGenerateSequenceSegment(const AModel: TWfcSequenceModel;
  const AOptions: TSequenceSegmentOptions;
  const ABoundary: TWfcSequenceSegmentBoundary;
  const AConstraints: TWfcSequenceTokenConstraints;
  var ASequence: TWfcGeneratedSequenceSegment; out AReport: TGraphSolveReport;
  const AProgress: TWorkProgressCallback): Boolean;
var
  LGraph: TGraph;
  LProgress: TWfcSolveProgressBridge;
  LCandidate: TWfcGeneratedSequenceSegment;
  LValidation: TWfcSequenceGraphValidationReport;
  LSolve: TGraphSolveOptions;
  LFalsePosition: Integer;
  LPreferences: TSequencePreferenceScope;
begin
  RequireGenerationBounds(AModel, AOptions.CellCount, AOptions.MaxBacktracks,
    AOptions.StateCellBudget);
  AReport := Default(TGraphSolveReport);
  LProgress := nil;
  LPreferences := nil;
  LGraph := TGraph.Create;
  try
    LProgress := TWfcSolveProgressBridge.Create(AProgress);
    LGraph.Reshape(AOptions.CellCount, 1, 1);
    LGraph.WrapNeighbors := False;
    LGraph.Seed := AOptions.Seed;
    ApplySequenceModelSegmentToGraph(AModel, LGraph, ABoundary,
      LProgress.PreparationWorkObserver());
    IntersectSequenceTokenConstraints(AModel, LGraph, AConstraints,
      LProgress.SequenceWorkObserver());
    LSolve := DefaultGraphSolveOptions;
    LSolve.MaxBacktracks := AOptions.MaxBacktracks;
    LPreferences := TSequencePreferenceScope.Create(AModel, LGraph,
      AOptions.Preferences, AProgress);
    Result := LGraph.TrySolve(LSolve, AReport, LProgress.SolveObserver());
    if not Result then
    begin
      Exit;
    end;
    LPreferences.UseOriginal(AProgress);
    if not CaptureSolvedSequenceSegment(AModel, LGraph, ABoundary,
      LCandidate, LValidation, LProgress.SequenceWorkObserver()) or
      not SequenceStatesSatisfyEntryConstraints(AModel, LGraph,
        LCandidate.StateIndices, LFalsePosition, LProgress.SequenceWorkObserver()) then
    begin
      raise EAudio.Create('Solved sequence segment failed boundary or constraint validation');
    end;
    ReportWork(AProgress, 'sequence_segment_publication_ready', wuItems, 1, 1);
    ASequence := LCandidate;
  finally
    LPreferences.Free;
    LProgress.Free;
    LGraph.Free;
  end;
end;

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
  RequireGenerationBounds(AModel, AOptions.FrameCount, AOptions.MaxBacktracks,
    AOptions.StateCellBudget);
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
    ApplySequenceModelToGraph(AModel, LGraph, AOptions.Extent,
      WfcPreparationWorkObserver(LProgress));
    IntersectSequenceTokenConstraints(AModel, LGraph, AConstraints,
      WfcSequenceWorkObserver(LProgress));
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
