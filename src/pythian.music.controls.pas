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

unit pythian.music.controls;

{$mode delphi}
{$H+}

interface

uses
  pythian.music,
  pythian.progress;

const
  MaximumMusicalControlParts = 4096;
  MaximumMusicalBiasWeight = 31;

type
  TMusicalExpression = record
    VelocityPercent: Integer;
    GatePercent: Integer;
  end;
  TMusicalExpressions = array of TMusicalExpression;
  TMusicalPartControl = record
    MinimumPitch: Integer;
    MaximumPitch: Integer;
    ActivityBias: Integer;
    Expression: TMusicalExpression;
  end;
  TMusicalPartControls = array of TMusicalPartControl;
  TMusicalAffectMapping = record
    VelocityPercent: Integer;
    ActivityBias: Integer;
    TonicBias: Integer;
  end;

function DefaultMusicalPartControl: TMusicalPartControl;
function DefaultMusicalExpression: TMusicalExpression;
procedure ValidateMusicalExpression(const AExpression: TMusicalExpression);
procedure ValidateMusicalPartControl(const AControl: TMusicalPartControl);
{ Explicit editable hypotheses, not learned mood semantics:
  energy -> 50..150% velocity; density -> -100..100 attack preference;
  tension -> +100..-100 preference for harmony containing the key root. }
function MapMusicalAffect(const AEnergy, ADensity, ATension: Integer): TMusicalAffectMapping;
{ Soft bias never excludes a choice. Zero gives 1; a favored choice gets 2..31.
  The bounded curve permits paired musical preferences to compose safely. }
function MusicalBiasWeight(const ABias: Integer; const AHasTrait: Boolean): Integer;
{ Joint rhythm weight: ceiling mean of active roles' favored increments.
  Neutral roles do not dilute an explicit preference. Result remains 1..31. }
function MusicalActivityWeight(const AControls: TMusicalPartControls;
  const AAttacks: array of Boolean): Integer;
{ Detached performed score. Role indices select controls. Pitch, attack timing,
  source indices and clock stay exact; velocity saturates at 127 and shortened
  gates retain at least one tick. Pitch/activity controls belong to graph admission,
  not post-hoc note filtering. Nil/invalid input or cancellation preserves the source. }
function ApplyMusicalExpression(const ASequence: TNoteSequence;
  const AControls: TMusicalExpressions;
  const AProgress: TWorkProgressCallback = nil): TNoteSequence;

implementation

uses
  pythian.audio,
  pythian.time;

procedure IntegerRange(const AValue, AMinimum, AMaximum: Integer; const AName: String);
begin
  if (AValue <> Trunc(AValue)) or (AValue < AMinimum) or (AValue > AMaximum) then
  begin
    raise EAudio.Create('Musical control is outside its whole-number bounds: ' + AName);
  end;
end;

function DefaultMusicalPartControl: TMusicalPartControl;
begin
  Result := Default(TMusicalPartControl);
  Result.MaximumPitch := 127;
  Result.Expression := DefaultMusicalExpression;
end;

function DefaultMusicalExpression: TMusicalExpression;
begin
  Result := Default(TMusicalExpression);
  Result.VelocityPercent := 100;
  Result.GatePercent := 100;
end;

procedure ValidateMusicalExpression(const AExpression: TMusicalExpression);
begin
  IntegerRange(AExpression.VelocityPercent, 1, 200, 'velocity percent');
  IntegerRange(AExpression.GatePercent, 1, 100, 'gate percent');
end;

procedure ValidateMusicalPartControl(const AControl: TMusicalPartControl);
begin
  IntegerRange(AControl.MinimumPitch, 0, 127, 'minimum pitch');
  IntegerRange(AControl.MaximumPitch, 0, 127, 'maximum pitch');
  if AControl.MinimumPitch > AControl.MaximumPitch then
  begin
    raise EAudio.Create('Lowest pitch must not exceed highest pitch');
  end;
  IntegerRange(AControl.ActivityBias, -100, 100, 'activity preference');
  ValidateMusicalExpression(AControl.Expression);
end;

function MapMusicalAffect(const AEnergy, ADensity, ATension: Integer): TMusicalAffectMapping;
begin
  IntegerRange(AEnergy, 0, 100, 'energy');
  IntegerRange(ADensity, 0, 100, 'density');
  IntegerRange(ATension, 0, 100, 'tension');
  Result.VelocityPercent := 50 + AEnergy;
  Result.ActivityBias := 2 * (ADensity - 50);
  Result.TonicBias := 2 * (50 - ATension);
end;

function MusicalBiasWeight(const ABias: Integer; const AHasTrait: Boolean): Integer;
begin
  IntegerRange(ABias, -100, 100, 'soft preference');
  Result := 1;
  if ((ABias > 0) and AHasTrait) or ((ABias < 0) and not AHasTrait) then
  begin
    Result := 1 + (Abs(ABias) * (MaximumMusicalBiasWeight - 1) + 99) div 100;
  end;
end;

function MusicalActivityWeight(const AControls: TMusicalPartControls;
  const AAttacks: array of Boolean): Integer;
var
  LIndex: Integer;
  LActive: Integer;
  LIncrements: Integer;
begin
  if (Length(AControls) < 1) or (Length(AControls) > MaximumMusicalControlParts) or
    (Length(AAttacks) <> Length(AControls)) then
  begin
    raise EAudio.Create('Activity requires matching ordered part controls and attack actions');
  end;
  LActive := 0;
  LIncrements := 0;
  for LIndex := 0 to High(AControls) do
  begin
    IntegerRange(AControls[LIndex].ActivityBias, -100, 100, 'activity preference');
    if AControls[LIndex].ActivityBias = 0 then Continue;
    Inc(LActive);
    Inc(LIncrements, MusicalBiasWeight(AControls[LIndex].ActivityBias, AAttacks[LIndex]) - 1);
  end;
  Result := 1;
  if LActive > 0 then Result := 1 + (LIncrements + LActive - 1) div LActive;
end;

function ApplyMusicalExpression(const ASequence: TNoteSequence;
  const AControls: TMusicalExpressions;
  const AProgress: TWorkProgressCallback): TNoteSequence;
var
  LGates: TNoteGates;
  LClock: TTempoMap;
  LControl: TMusicalExpression;
  LIndex: Integer;
  LDuration: Integer;
  LVelocity: Integer;
begin
  if (ASequence = nil) or (Length(AControls) < 1) or
    (Length(AControls) > MaximumMusicalControlParts) then
  begin
    raise EAudio.Create('Musical expression requires a score and bounded part controls');
  end;
  for LIndex := 0 to High(AControls) do
  begin
    ValidateMusicalExpression(AControls[LIndex]);
  end;
  LGates := ASequence.CopyGates;
  for LIndex := 0 to High(LGates) do
  begin
    if (LIndex mod 256) = 0 then
    begin
      ReportWork(AProgress, 'musical_expression', wuItems, LIndex, Length(LGates));
    end;
    if LGates[LIndex].Voice >= Length(AControls) then
    begin
      raise EAudio.Create('Musical expression has no control for a score role');
    end;
    LControl := AControls[LGates[LIndex].Voice];
    LVelocity := (LGates[LIndex].Velocity * LControl.VelocityPercent + 50) div 100;
    if LVelocity < 1 then LVelocity := 1;
    if LVelocity > 127 then LVelocity := 127;
    LGates[LIndex].Velocity := LVelocity;
    LDuration := (LGates[LIndex].EndTick - LGates[LIndex].StartTick);
    LDuration := Integer(Int64(LDuration) * LControl.GatePercent div 100);
    if LDuration < 1 then LDuration := 1;
    LGates[LIndex].EndTick := LGates[LIndex].StartTick + LDuration;
  end;
  ReportWork(AProgress, 'musical_expression', wuItems, Length(LGates), Length(LGates));
  LClock := ASequence.CopyClock;
  try
    Result := TNoteSequence.Create(ASequence.TicksPerQuarter, ASequence.LengthTicks,
      LClock.CopyChanges, LGates);
  finally
    LClock.Free;
  end;
end;

end.
