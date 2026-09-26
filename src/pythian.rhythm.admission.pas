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

unit pythian.rhythm.admission;

{$mode delphi}
{$H+}

interface

uses
  pythian.music.grid.frames,
  pythian.passage;

const
  RhythmAdmissionVersion = 1;

type
  TRhythmOnsetDecision = (rodAccepted, rodOutsideScope, rodTooFar, rodCollision);
  TRhythmOnsetDecisions = array of TRhythmOnsetDecision;
  TRhythmAdmission = record
    Pattern: String;
    Cells: TPassageIndices;
    FrameErrors: TPassageIndices;
    Decisions: TRhythmOnsetDecisions;
    Accepted: Integer;
  end;

{ Maps strictly ordered, previously admitted source onset frames to a constant
  declared PPQ clock with an explicit source start tick. Nearest floor-frame boundary wins;
  half ties choose the earlier cell. End boundary/tail, excessive error and
  collisions retain explicit decisions. x means an admitted onset; . means no
  admitted onset, not measured silence, note hold or an inferred voice rest.
  The complete-cell scope uses the existing exact WAV context admission. }
function AdmitWaveRhythm(const ASampleRate, ASourceFrames, ATempoMicroseconds,
  ATicksPerQuarter, AStepTicks, AMaximumErrorFrames: Integer;
  const AOnsetFrames: TPassageBounds; const AStartTick: Integer = 0): TRhythmAdmission; overload;

{ Explicit mapped scope, including changing tempo and a source frame offset. }
function AdmitWaveRhythm(const AGrid: TMusicGridFrames; const AMaximumErrorFrames: Integer;
  const AOnsetFrames: TPassageBounds): TRhythmAdmission; overload;

implementation

uses
  Math,
  pythian.audio,
  pythian.time,
  pythian.tonal,
  pythian.music.context,
  pythian.music.context.admission;

function AdmitWaveRhythm(const ASampleRate, ASourceFrames, ATempoMicroseconds,
  ATicksPerQuarter, AStepTicks, AMaximumErrorFrames: Integer;
  const AOnsetFrames: TPassageBounds; const AStartTick: Integer): TRhythmAdmission;
var
  LScope: TWaveContextScope;
  LClock: TTempoMap;
  LGrid: TMusicGridFrames;
begin
  LScope := WaveContextScope(ASampleRate, ASourceFrames, ATempoMicroseconds,
    ATicksPerQuarter, AStepTicks, MakeKeyContext(-1, dmMajor), AStartTick);
  LClock := TTempoMap.Create(ATicksPerQuarter,
    AStartTick + Length(LScope.Grid.Keys) * AStepTicks, [MakeTempoChange(0, ATempoMicroseconds)]);
  LGrid := nil;
  try
    LGrid := TMusicGridFrames.Create(LClock, ASampleRate, ASourceFrames, 0,
      AStartTick, AStepTicks, Length(LScope.Grid.Keys));
    Result := AdmitWaveRhythm(LGrid, AMaximumErrorFrames, AOnsetFrames);
  finally
    LGrid.Free;
    LClock.Free;
  end;
end;

function AdmitWaveRhythm(const AGrid: TMusicGridFrames; const AMaximumErrorFrames: Integer;
  const AOnsetFrames: TPassageBounds): TRhythmAdmission;
var
  LResult: TRhythmAdmission;
  LBoundaries: TPassageBounds;
  LCount: Integer;
  LIndex: Integer;
  LLow: Integer;
  LHigh: Integer;
  LMiddle: Integer;
  LCell: Integer;
begin
  if (AGrid = nil) or (AMaximumErrorFrames < 0) or (AMaximumErrorFrames > MaximumClipSamples) or
    (Length(AOnsetFrames) > 65536) then
  begin
    raise EAudio.Create('Rhythm admission error/count exceeds bounds');
  end;
  LCount := AGrid.CellCount;
  SetLength(LBoundaries, LCount + 1);
  for LIndex := 0 to LCount do
  begin
    LBoundaries[LIndex] := AGrid.BoundaryAt(LIndex);
    if (LIndex > 0) and (LBoundaries[LIndex] <= LBoundaries[LIndex - 1]) then
    begin
      raise EAudio.Create('Rhythm grid contains sub-frame cells');
    end;
  end;
  LResult := Default(TRhythmAdmission);
  LResult.Pattern := StringOfChar('.', LCount);
  SetLength(LResult.Cells, Length(AOnsetFrames));
  SetLength(LResult.FrameErrors, Length(AOnsetFrames));
  SetLength(LResult.Decisions, Length(AOnsetFrames));
  for LIndex := 0 to High(AOnsetFrames) do
  begin
    if (AOnsetFrames[LIndex] < 0) or (AOnsetFrames[LIndex] >= AGrid.SourceFrames) or
      ((LIndex > 0) and (AOnsetFrames[LIndex] <= AOnsetFrames[LIndex - 1])) then
    begin
      raise EAudio.Create('Rhythm source onset frames must be strictly ordered within the recording');
    end;
    LLow := 0;
    LHigh := LCount;
    while LLow < LHigh do
    begin
      LMiddle := LLow + (LHigh - LLow) div 2;
      if LBoundaries[LMiddle] < AOnsetFrames[LIndex] then
      begin
        LLow := LMiddle + 1;
      end
      else
      begin
        LHigh := LMiddle;
      end;
    end;
    LCell := LLow;
    if (LCell > 0) and
      (AOnsetFrames[LIndex] - LBoundaries[LCell - 1] <=
       Abs(LBoundaries[LCell] - AOnsetFrames[LIndex])) then
    begin
      Dec(LCell);
    end;
    LResult.Cells[LIndex] := LCell;
    LResult.FrameErrors[LIndex] := LBoundaries[LCell] - AOnsetFrames[LIndex];
    LResult.Decisions[LIndex] := rodAccepted;
    if (AOnsetFrames[LIndex] < AGrid.BoundaryAt(0)) or
      (LCell = LCount) or (AOnsetFrames[LIndex] >= AGrid.EndFrameCeiling) then
    begin
      LResult.Decisions[LIndex] := rodOutsideScope;
    end
    else if Abs(LResult.FrameErrors[LIndex]) > AMaximumErrorFrames then
    begin
      LResult.Decisions[LIndex] := rodTooFar;
    end
    else if LResult.Pattern[LCell + 1] = 'x' then
    begin
      LResult.Decisions[LIndex] := rodCollision;
    end
    else
    begin
      LResult.Pattern[LCell + 1] := 'x';
      Inc(LResult.Accepted);
    end;
  end;
  Result := LResult;
end;

end.
