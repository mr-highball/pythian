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
unit pythian.wfc.progress;

{$mode delphi}
{$H+}

interface

uses pythian.progress, wfc_solve_progress, wfc_sequence;

type
  { A call-scoped borrowed observer adapter. It owns no graph and preserves the
    companion's original exception/cancellation semantics. Derivatives may reuse
    the same primary callback for their own measured preparation work. }
  TWfcSolveProgressBridge = class
  protected
    FCallback: TWorkProgressCallback;
  private
    procedure ObserveSolve(const AWork: TWfcSolveProgress);
    procedure ObserveSequenceWork(const AWork: TWfcSequencePreparationProgress);
  public
    constructor Create(const ACallback: TWorkProgressCallback);
    function SolveObserver: TWfcSolveObserver;
    function SequenceWorkObserver: TWfcSequencePreparationObserver;
  end;

function WfcSolveObserver(const ABridge: TWfcSolveProgressBridge): TWfcSolveObserver;
function WfcSequenceWorkObserver(const ABridge: TWfcSolveProgressBridge):
  TWfcSequencePreparationObserver;

implementation

uses pythian.audio;

constructor TWfcSolveProgressBridge.Create(const ACallback: TWorkProgressCallback);
begin
  inherited Create;
  FCallback := ACallback;
end;

procedure TWfcSolveProgressBridge.ObserveSolve(const AWork: TWfcSolveProgress);
var
  LStage: String;
  LTotal: Int64;
begin
  case AWork.Phase of
    wspPrepare: LStage := 'wfc_solve_prepare_visits';
    wspSearch: LStage := 'wfc_solve_search_visits';
    wspCommit: LStage := 'wfc_solve_commit_visits';
  else
    raise EAudio.Create('Unknown companion solve progress phase');
  end;
  LTotal := 0;
  if AWork.KnownTotal then
  begin
    LTotal := AWork.Total;
  end;
  { Primary Pass0 denotes pipeline work. Companion pass indices are zero based,
    so public per-pass counts use1..N; zero/unknown totals remain truthful. }
  ReportWork(FCallback, LStage, wuItems, AWork.Done, LTotal, AWork.PassIndex + 1);
end;

function TWfcSolveProgressBridge.SolveObserver: TWfcSolveObserver;
begin
  Result := nil;
  if Assigned(FCallback) then
  begin
    Result := ObserveSolve;
  end;
end;

procedure TWfcSolveProgressBridge.ObserveSequenceWork(
  const AWork: TWfcSequencePreparationProgress);
var
  LStage: String;
begin
  case AWork.Phase of
    wspValidateConstraints: LStage := 'wfc_sequence_constraint_rows';
    wspValidateGraphModel: LStage := 'wfc_sequence_model_rows';
    wspSnapshotDomains: LStage := 'wfc_sequence_snapshot_cells';
    wspIntersectDomains: LStage := 'wfc_sequence_mask_rows';
    wspLearnTokenRows: LStage := 'wfc_sequence_learn_token_rows';
    wspLearnStateRows: LStage := 'wfc_sequence_learn_state_rows';
    wspModelBuildVisits: LStage := 'wfc_sequence_model_build_visits';
    wspCaptureSequenceCells: LStage := 'wfc_sequence_capture_cells';
    wspValidatePathStates: LStage := 'wfc_sequence_path_states';
    wspValidatePathTransitions: LStage := 'wfc_sequence_path_transitions';
    wspValidateEntryCells: LStage := 'wfc_sequence_entry_cells';
    wspValidateProjectionStates: LStage := 'wfc_sequence_projection_states';
    wspProjectStateTokens: LStage := 'wfc_sequence_project_tokens';
    wspCaptureReady: LStage := 'wfc_sequence_capture_ready';
  else
    raise EAudio.Create('Unknown companion sequence work phase');
  end;
  ReportWork(FCallback, LStage, wuItems, AWork.Done, AWork.Total);
end;

function TWfcSolveProgressBridge.SequenceWorkObserver: TWfcSequencePreparationObserver;
begin
  Result := nil;
  if Assigned(FCallback) then
  begin
    Result := ObserveSequenceWork;
  end;
end;

function WfcSequenceWorkObserver(const ABridge: TWfcSolveProgressBridge):
  TWfcSequencePreparationObserver;
begin
  Result := nil;
  if ABridge <> nil then
  begin
    Result := ABridge.SequenceWorkObserver();
  end;
end;

function WfcSolveObserver(const ABridge: TWfcSolveProgressBridge): TWfcSolveObserver;
begin
  Result := nil;
  if ABridge <> nil then
  begin
    Result := ABridge.SolveObserver();
  end;
end;

end.
