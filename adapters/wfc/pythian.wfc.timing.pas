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
unit pythian.wfc.timing;

{$mode delphi}
{$H+}

interface

uses
  pythian.alignment,
  pythian.articulation,
  pythian.wfc.joint;

const
  JointTimingVersion = 1;

type
  TJointAttackPlan = record
    CellCount: Integer;
    Anchors: TFeatureAnchors;
    Constraints: TJointConstraints;
  end;

{ Requires source-onset labels near the start of every positive-gain output
  gate. Exact coincident attacks (chords) share one constraint. Distinct attacks
  landing on one cell reject. Rests and holds do not add source-label locks:
  use RenderArticulatedClip after reconstruction to enforce their output gates.
  Plan sample rate must match the corpus when used for generation. }
function PlanJointAttacks(const AArticulation: TArticulationPlan;
  const AHopFrames, AMaximumErrorFrames: Integer): TJointAttackPlan;

implementation

uses
  pythian.audio,
  pythian.activity,
  pythian.wfc.generation;

function PlanJointAttacks(const AArticulation: TArticulationPlan;
  const AHopFrames, AMaximumErrorFrames: Integer): TJointAttackPlan;
var
  LPlan: TJointAttackPlan;
  LFrames: TFrameAnchors;
  LSeen: array of Int64;
  LGate: TArticulationGate;
  LIndex: Integer;
  LCount: Integer;
  LCell: Integer;
begin
  if (AArticulation = nil) or (AHopFrames < 1) then
  begin
    raise EAudio.Create('Joint timing requires an articulation plan and positive hop');
  end;
  if (AArticulation.FrameCount < 1) or
    ((Int64(AArticulation.FrameCount) + AHopFrames - 1) div AHopFrames >
      MaximumGeneratedAcousticFrames) then
  begin
    raise EAudio.Create('Joint timing extent exceeds generated analysis-cell budget');
  end;
  LPlan := Default(TJointAttackPlan);
  LPlan.CellCount := (Int64(AArticulation.FrameCount) + AHopFrames - 1) div AHopFrames;
  LFrames := nil;
  SetLength(LFrames, AArticulation.GateCount);
  LCount := 0;
  for LIndex := 0 to AArticulation.GateCount - 1 do
  begin
    LGate := AArticulation.GateAt(LIndex);
    if LGate.Gain > 0 then
    begin
      LFrames[LCount] := LGate.StartFrame;
      Inc(LCount);
    end;
  end;
  SetLength(LFrames, LCount);
  LPlan.Anchors := AlignFeatureAnchors(LFrames, 0, AHopFrames, LPlan.CellCount,
    AMaximumErrorFrames);
  SetLength(LSeen, LPlan.CellCount);
  for LIndex := 0 to High(LSeen) do
  begin
    LSeen[LIndex] := -1;
  end;
  SetLength(LPlan.Constraints, Length(LPlan.Anchors));
  LCount := 0;
  for LIndex := 0 to High(LPlan.Anchors) do
  begin
    LCell := LPlan.Anchors[LIndex].Cell;
    if LSeen[LCell] >= 0 then
    begin
      if LSeen[LCell] <> LPlan.Anchors[LIndex].RequestedFrame then
      begin
        raise EAudio.Create('Distinct output attacks collide on one analysis cell');
      end;
      Continue;
    end;
    LSeen[LCell] := LPlan.Anchors[LIndex].RequestedFrame;
    LPlan.Constraints[LCount].Position := LCell;
    LPlan.Constraints[LCount].AcousticToken := -1;
    LPlan.Constraints[LCount].AllowedActions := [aaOnset];
    Inc(LCount);
  end;
  SetLength(LPlan.Constraints, LCount);
  Result := LPlan;
end;

end.

