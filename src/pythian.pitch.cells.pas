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


unit pythian.pitch.cells;

{$mode delphi}
{$H+}

interface

uses
  pythian.audio,
  pythian.music.grid.frames,
  pythian.pitch;

const
  PitchCellsVersion = 1;
  MaximumPitchCells = 1024;

type
  TPitchCell = record
    Measured: Boolean;
    Estimate: TPitchEstimate;
  end;
  TPitchCells = array of TPitchCell;
  TPitchCellEvidence = record
    WindowFrames: Integer; { Zero with empty cells means unavailable. }
    Channel: Integer;
    Options: TPitchOptions;
    MaximumCents: Double;
    Cells: TPitchCells;
  end;

  TPitchCellSummary = record
    Cells: Integer;
    AdmittedPitch: Integer;
    MeasuredSilence: Integer;
    UncertainPitch: Integer;
    Unmeasured: Integer;
    KnownRuns: Integer;
    LongestKnownRun: Integer;
  end;

{ Caller declares monophony and a constant clock with an explicit source start tick.
  Cell centers are analysis windows, not inferred note boundaries. }
function MeasurePitchCells(const AClip: TAudioClip; const ATempo, APpq, AStep,
  AChannel: Integer; const AOptions: TPitchOptions;
  const AMaximumCents: Double; const AStartTick: Integer = 0): TPitchCellEvidence; overload;
function AdmitPitchCells(const AEvidence: TPitchCellEvidence; const ASampleRate,
  AChannels, AFrames, ATempo, APpq, AStep: Integer;
  const AStartTick: Integer = 0): TPitchNotes; overload;

{ Summarizes validated source evidence, not confidence or maximum generatable
  length. Silence remains distinct from uncertain and unmeasured cells. }
function SummarizePitchCells(const AEvidence: TPitchCellEvidence; const ASampleRate,
  AChannels, AFrames, ATempo, APpq, AStep: Integer;
  const AStartTick: Integer = 0): TPitchCellSummary; overload;

{ Explicit mapped cells share the same changing clock and physical source origin. }
function MeasurePitchCells(const AClip: TAudioClip; const AGrid: TMusicGridFrames;
  const AChannel: Integer; const AOptions: TPitchOptions;
  const AMaximumCents: Double): TPitchCellEvidence; overload;
function AdmitPitchCells(const AEvidence: TPitchCellEvidence; const AGrid: TMusicGridFrames;
  const AChannels: Integer): TPitchNotes; overload;
function SummarizePitchCells(const AEvidence: TPitchCellEvidence; const AGrid: TMusicGridFrames;
  const AChannels: Integer): TPitchCellSummary; overload;

implementation

uses
  Math,
  pythian.time,
  pythian.tonal,
  pythian.music.context,
  pythian.music.context.admission;

function ConstantGrid(const ASampleRate, AFrames, ATempo, APpq, AStep,
  AStartTick: Integer): TMusicGridFrames;
var
  LScope: TWaveContextScope;
  LClock: TTempoMap;
begin
  LScope := WaveContextScope(ASampleRate, AFrames, ATempo, APpq, AStep,
    MakeKeyContext(-1, dmMajor), AStartTick);
  LClock := TTempoMap.Create(APpq, AStartTick + Length(LScope.Grid.Keys) * AStep,
    [MakeTempoChange(0, ATempo)]);
  try
    Result := TMusicGridFrames.Create(LClock, ASampleRate, AFrames, 0,
      AStartTick, AStep, Length(LScope.Grid.Keys));
  finally
    LClock.Free;
  end;
end;

procedure ValidateCellWork(const AEvidence: TPitchCellEvidence;
  const AGrid: TMusicGridFrames; const AChannels: Integer);
var
  LWork: Int64;
begin
  if AGrid = nil then
  begin
    raise EAudio.Create('Pitch cells require an explicit source grid');
  end;
  LWork := PitchEstimateWork(AEvidence.WindowFrames, AGrid.SampleRate, AChannels,
    AEvidence.Channel, AEvidence.Options);
  RequireFinite(AEvidence.MaximumCents, 'Pitch cell tuning tolerance');
  if (AEvidence.MaximumCents < 0) or (AEvidence.MaximumCents > 50) then
  begin
    raise EAudio.Create('Pitch cell tuning tolerance must be 0..50 cents');
  end;
  if (AGrid.CellCount > MaximumPitchCells) or
    (LWork * AGrid.CellCount > MaximumPitchBatchWork) then
  begin
    raise EAudio.Create('Pitch cells exceed bounded measurement work; select an excerpt');
  end;
end;

function AdmitPitchCells(const AEvidence: TPitchCellEvidence;
  const AGrid: TMusicGridFrames; const AChannels: Integer): TPitchNotes;
var
  LCell: Integer;
  LWidth: Integer;
  LEstimate: TPitchEstimate;
begin
  Result := nil;
  if AEvidence.WindowFrames = 0 then
  begin
    if Length(AEvidence.Cells) <> 0 then
    begin
      raise EAudio.Create('Unavailable pitch evidence must have no cells');
    end;
    Exit;
  end;
  ValidateCellWork(AEvidence, AGrid, AChannels);
  if Length(AEvidence.Cells) <> AGrid.CellCount then
  begin
    raise EAudio.Create('Pitch evidence must cover the complete declared source grid');
  end;
  SetLength(Result, AGrid.CellCount);
  for LCell := 0 to AGrid.CellCount - 1 do
  begin
    Result[LCell] := -1;
    LWidth := AGrid.BoundaryAt(LCell + 1) - AGrid.BoundaryAt(LCell);
    if AEvidence.Cells[LCell].Measured <> (LWidth >= AEvidence.WindowFrames) then
    begin
      raise EAudio.Create('Pitch measurement availability disagrees with cell window geometry');
    end;
    if not AEvidence.Cells[LCell].Measured then
    begin
      Continue;
    end;
    LEstimate := AEvidence.Cells[LCell].Estimate;
    ValidatePitchEstimate(LEstimate, AGrid.SampleRate, AEvidence.Options);
    Result[LCell] := AdmitPitchNote(LEstimate, AEvidence.MaximumCents);
  end;
end;

function AdmitPitchCells(const AEvidence: TPitchCellEvidence; const ASampleRate,
  AChannels, AFrames, ATempo, APpq, AStep: Integer;
  const AStartTick: Integer): TPitchNotes;
var
  LGrid: TMusicGridFrames;
begin
  if AEvidence.WindowFrames = 0 then
  begin
    Exit(AdmitPitchCells(AEvidence, nil, AChannels));
  end;
  LGrid := ConstantGrid(ASampleRate, AFrames, ATempo, APpq, AStep, AStartTick);
  try
    Result := AdmitPitchCells(AEvidence, LGrid, AChannels);
  finally
    LGrid.Free;
  end;
end;

function SummarizePitchCells(const AEvidence: TPitchCellEvidence;
  const AGrid: TMusicGridFrames; const AChannels: Integer): TPitchCellSummary;
var
  LNotes: TPitchNotes;
  LResult: TPitchCellSummary;
  LRun: Integer;
  LIndex: Integer;
begin
  LNotes := AdmitPitchCells(AEvidence, AGrid, AChannels);
  LResult := Default(TPitchCellSummary);
  LResult.Cells := Length(LNotes);
  LRun := 0;
  for LIndex := 0 to High(LNotes) do
  begin
    if LNotes[LIndex] >= 0 then
    begin
      Inc(LResult.AdmittedPitch);
      if LRun = 0 then
      begin
        Inc(LResult.KnownRuns);
      end;
      Inc(LRun);
      LResult.LongestKnownRun := Max(LResult.LongestKnownRun, LRun);
    end
    else
    begin
      LRun := 0;
      if not AEvidence.Cells[LIndex].Measured then
      begin
        Inc(LResult.Unmeasured);
      end
      else if AEvidence.Cells[LIndex].Estimate.Status = psSilence then
      begin
        Inc(LResult.MeasuredSilence);
      end
      else
      begin
        Inc(LResult.UncertainPitch);
      end;
    end;
  end;
  Result := LResult;
end;

function SummarizePitchCells(const AEvidence: TPitchCellEvidence; const ASampleRate,
  AChannels, AFrames, ATempo, APpq, AStep: Integer;
  const AStartTick: Integer): TPitchCellSummary;
var
  LGrid: TMusicGridFrames;
begin
  if AEvidence.WindowFrames = 0 then
  begin
    Exit(SummarizePitchCells(AEvidence, nil, AChannels));
  end;
  LGrid := ConstantGrid(ASampleRate, AFrames, ATempo, APpq, AStep, AStartTick);
  try
    Result := SummarizePitchCells(AEvidence, LGrid, AChannels);
  finally
    LGrid.Free;
  end;
end;

function MeasurePitchCells(const AClip: TAudioClip; const AGrid: TMusicGridFrames;
  const AChannel: Integer; const AOptions: TPitchOptions;
  const AMaximumCents: Double): TPitchCellEvidence;
var
  LResult: TPitchCellEvidence;
  LCell: Integer;
  LFrame: Integer;
  LStart: Integer;
  LEnd: Integer;
  LSamples: TAudioSamples;
begin
  if (AClip = nil) or (AGrid = nil) then
  begin
    raise EAudio.Create('Pitch measurement requires a WAV clip and source grid');
  end;
  if (AClip.SampleRate <> AGrid.SampleRate) or (AClip.FrameCount <> AGrid.SourceFrames) then
  begin
    raise EAudio.Create('Pitch source and mapped grid geometry disagree');
  end;
  LResult := Default(TPitchCellEvidence);
  LResult.Options := AOptions;
  PitchEstimateWork(MaximumPitchWindowFrames, AClip.SampleRate,
    AClip.Channels, AChannel, AOptions);
  LResult.WindowFrames := 2 * (Ceil(AClip.SampleRate / AOptions.MinimumHz) + 1);
  LResult.Channel := AChannel;
  LResult.MaximumCents := AMaximumCents;
  ValidateCellWork(LResult, AGrid, AClip.Channels);
  SetLength(LResult.Cells, AGrid.CellCount);
  SetLength(LSamples, LResult.WindowFrames);
  for LCell := 0 to AGrid.CellCount - 1 do
  begin
    LStart := AGrid.BoundaryAt(LCell);
    LEnd := AGrid.BoundaryAt(LCell + 1);
    LResult.Cells[LCell].Measured := LEnd - LStart >= LResult.WindowFrames;
    if not LResult.Cells[LCell].Measured then
    begin
      Continue;
    end;
    Inc(LStart, (LEnd - LStart - LResult.WindowFrames) div 2);
    for LFrame := 0 to High(LSamples) do
    begin
      LSamples[LFrame] := AClip.SampleAt(LStart + LFrame, AChannel);
    end;
    LResult.Cells[LCell].Estimate := EstimatePitch(LSamples, AClip.SampleRate, 1, 0, AOptions);
  end;
  AdmitPitchCells(LResult, AGrid, AClip.Channels);
  Result := LResult;
end;

function MeasurePitchCells(const AClip: TAudioClip; const ATempo, APpq, AStep,
  AChannel: Integer; const AOptions: TPitchOptions;
  const AMaximumCents: Double; const AStartTick: Integer): TPitchCellEvidence;
var
  LGrid: TMusicGridFrames;
begin
  if AClip = nil then
  begin
    raise EAudio.Create('Pitch measurement requires a WAV clip');
  end;
  LGrid := ConstantGrid(AClip.SampleRate, AClip.FrameCount, ATempo, APpq, AStep, AStartTick);
  try
    Result := MeasurePitchCells(AClip, LGrid, AChannel, AOptions, AMaximumCents);
  finally
    LGrid.Free;
  end;
end;

end.
