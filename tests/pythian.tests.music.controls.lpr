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
program pythian_tests_music_controls;
{$mode delphi}
{$H+}
uses
  SysUtils,
  pythian.audio,
  pythian.music,
  pythian.music.controls,
  pythian.time,
  pythian.progress;

type
  TCancelExpression = class
    procedure Observe(const AWork: TWorkProgress);
  end;

var
  Checks: Integer;

procedure Check(const ACondition: Boolean; const ADetail: String);
begin
  Inc(Checks);
  if not ACondition then raise EAudio.Create(ADetail);
end;

procedure TCancelExpression.Observe(const AWork: TWorkProgress);
begin
  if AWork.Done = AWork.Total then raise EAbort.Create('Expected cancellation');
end;

procedure Run;
var
  LControls: TMusicalExpressions;
  LPart: TMusicalPartControl;
  LAffect: TMusicalAffectMapping;
  LNotes: TNoteGates;
  LTempos: TTempoChanges;
  LSource: TNoteSequence;
  LResult: TNoteSequence;
  LSaved: TNoteSequence;
  LCancel: TCancelExpression;
  LParts: TMusicalPartControls;
  LRaised: Boolean;
begin
  LPart := DefaultMusicalPartControl;
  ValidateMusicalPartControl(LPart);
  Check((LPart.MinimumPitch = 0) and (LPart.MaximumPitch = 127) and
    (LPart.ActivityBias = 0) and (LPart.Expression.VelocityPercent = 100) and
    (LPart.Expression.GatePercent = 100), 'Neutral control defaults');
  LAffect := MapMusicalAffect(50, 50, 50);
  Check((LAffect.VelocityPercent = 100) and (LAffect.ActivityBias = 0) and
    (LAffect.TonicBias = 0), 'Neutral explicit affect mapping');
  LAffect := MapMusicalAffect(0, 100, 0);
  Check((LAffect.VelocityPercent = 50) and (LAffect.ActivityBias = 100) and
    (LAffect.TonicBias = 100), 'Low energy, active/root-favoring mapping');
  LAffect := MapMusicalAffect(100, 0, 100);
  Check((LAffect.VelocityPercent = 150) and (LAffect.ActivityBias = -100) and
    (LAffect.TonicBias = -100), 'High energy, sparse/root-avoiding mapping');
  Check((MusicalBiasWeight(0, True) = 1) and (MusicalBiasWeight(0, False) = 1),
    'Zero bias is neutral');
  Check((MusicalBiasWeight(100, True) = 31) and
    (MusicalBiasWeight(100, False) = 1), 'Positive bias leaves all choices possible');
  Check((MusicalBiasWeight(-100, True) = 1) and
    (MusicalBiasWeight(-100, False) = 31), 'Negative bias favors the opposite trait');
  SetLength(LParts, 2);
  LParts[0] := DefaultMusicalPartControl;
  LParts[1] := DefaultMusicalPartControl;
  Check(MusicalActivityWeight(LParts, [True, False]) = 1, 'Neutral rhythm weight');
  LParts[0].ActivityBias := 100;
  Check(MusicalActivityWeight(LParts, [True, False]) = 31,
    'Neutral roles do not dilute the requested active role');
  LParts[1].ActivityBias := 100;
  Check(MusicalActivityWeight(LParts, [True, False]) = 16,
    'Conflicting joint actions use a bounded mean');
  Check((MusicalActivityWeight(LParts, [True, True]) = 31) and
    (MusicalActivityWeight(LParts, [False, False]) = 1), 'Joint activity stays bounded');
  LRaised := False;
  try MapMusicalAffect(101, 50, 50); except on E: EAudio do LRaised := True end;
  Check(LRaised, 'Invalid affect value rejects');
  LRaised := False;
  try MusicalActivityWeight(LParts, [True]); except on E: EAudio do LRaised := True end;
  Check(LRaised, 'Mismatched rhythm role order rejects');
  LPart.MinimumPitch := 80;
  LPart.MaximumPitch := 60;
  LRaised := False;
  try ValidateMusicalPartControl(LPart); except on E: EAudio do LRaised := True end;
  Check(LRaised, 'Inverted pitch bounds reject');
  LPart := DefaultMusicalPartControl;
  LPart.Expression.GatePercent := 0;
  LRaised := False;
  try ValidateMusicalPartControl(LPart); except on E: EAudio do LRaised := True end;
  Check(LRaised, 'Zero gate percent rejects');

  SetLength(LTempos, 2);
  LTempos[0] := MakeTempoChange(0, 500000);
  LTempos[1] := MakeTempoChange(240, 750000);
  SetLength(LNotes, 3);
  LNotes[0] := Default(TNoteGate);
  LNotes[0].EndTick := 480;
  LNotes[0].Pitch := 60;
  LNotes[0].Velocity := 80;
  LNotes[0].Channel := -1;
  LNotes[1] := LNotes[0];
  LNotes[1].StartTick := 120;
  LNotes[1].EndTick := 360;
  LNotes[1].Pitch := 48;
  LNotes[1].Voice := 1;
  LNotes[2] := LNotes[0];
  LNotes[2].StartTick := 479;
  LNotes[2].EndTick := 480;
  SetLength(LControls, 2);
  LControls[0] := DefaultMusicalExpression;
  LControls[1] := DefaultMusicalExpression;
  LSource := TNoteSequence.Create(480, 480, LTempos, LNotes);
  LResult := nil;
  LCancel := TCancelExpression.Create;
  try
    LResult := ApplyMusicalExpression(LSource, LControls);
    Check((LResult <> LSource) and (LResult.NoteCount = 3), 'Detached performed score');
    Check((LResult.GateAt(0).EndTick = 480) and (LResult.GateAt(0).Velocity = 80),
      'Neutral expression preserves the actual note');
    Check(LResult.FrameAtTick(480, 8000) = LSource.FrameAtTick(480, 8000),
      'Tempo-change clock is preserved');
    FreeAndNil(LResult);
    LControls[0].VelocityPercent := 200;
    LControls[0].GatePercent := 25;
    LResult := ApplyMusicalExpression(LSource, LControls);
    Check((LResult.GateAt(0).Velocity = 127) and (LResult.GateAt(0).EndTick = 120),
      'Velocity saturates and gate shortens in ticks');
    Check((LResult.GateAt(0).Pitch = 60) and (LResult.GateAt(0).StartTick = 0) and
      (LResult.GateAt(0).Channel = -1), 'Expression preserves pitch, attacks and source');
    Check((LResult.GateAt(1).StartTick = 120) and (LResult.GateAt(1).EndTick = 360) and
      (LResult.GateAt(1).Velocity = 80), 'Other role remains exact');
    Check((LResult.GateAt(2).StartTick = 479) and (LResult.GateAt(2).EndTick = 480),
      'One-tick notes stay positive');
    Check((LSource.GateAt(0).EndTick = 480) and (LSource.GateAt(0).Velocity = 80),
      'Accepted source remains unchanged');
    Check((LControls[1].VelocityPercent = 100) and (LControls[1].GatePercent = 100),
      'Applying one role does not mutate the borrowed control records');
    LSaved := LResult;
    SetLength(LControls, 1);
    LRaised := False;
    try LResult := ApplyMusicalExpression(LSource, LControls);
    except on E: EAudio do LRaised := True end;
    Check(LRaised and (LResult = LSaved), 'Missing role rejects without replacing accepted result');
    SetLength(LControls, 2);
    LControls[1] := DefaultMusicalExpression;
    LRaised := False;
    try LResult := ApplyMusicalExpression(LSource, LControls, LCancel.Observe);
    except on E: EAbort do LRaised := True end;
    Check(LRaised and (LResult = LSaved), 'Cancellation leaves accepted result and source intact');
  finally
    LCancel.Free;
    LResult.Free;
    LSource.Free;
  end;
end;

begin
  try
    Run;
    WriteLn('PASS musical controls: ', Checks, ' checks');
  except
    on E: Exception do
    begin
      WriteLn(E.ClassName, ': ', E.Message);
      {$IFDEF PAS2JS}
      raise;
      {$ELSE}
      ExitCode := 1;
      {$ENDIF}
    end;
  end;
end.
