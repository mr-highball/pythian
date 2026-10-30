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
program pythian_tests_schedule_progress;
{$mode delphi}{$H+}

uses
  SysUtils, pythian.audio, pythian.bus, pythian.echo, pythian.synth,
  pythian.schedule, pythian.progress;

type
  { Big Boss: inspects accepted state during real preparation callbacks and
    aborts each checkpoint by original exception identity. No scheduler copy
    or rendering algorithm is duplicated by this observer. }
  TObserver = class
  public
    Synth: TScheduledSynth;
    Calls, AbortAt, ExpectedCount, ExpectedWork, InputCount: Integer;
    ExpectedFrame: Int64;
    Stage: String;
    Done: Int64;
    Interior, Ready, Reenter: Boolean;
    Marker: Exception;
    procedure Observe(const AWork: TWorkProgress);
    procedure Attach(const ASynth: TScheduledSynth; const AInputs: Integer);
  end;

var
  Checks, Aborts: Integer;

procedure Check(const ACondition: Boolean; const AWhy: String);
begin
  if not ACondition then
  begin
    raise Exception.Create(AWhy);
  end;
  Inc(Checks);
end;

procedure TObserver.Attach(const ASynth: TScheduledSynth; const AInputs: Integer);
begin
  Synth := ASynth;
  ExpectedCount := Synth.ScheduledCount;
  ExpectedWork := Synth.ReservedWork;
  ExpectedFrame := Synth.NextFrame;
  InputCount := AInputs;
  Calls := 0;
  AbortAt := 0;
  Stage := '';
  Done := 0;
  Interior := False;
  Ready := False;
  Reenter := False;
  Marker := nil;
end;

procedure TObserver.Observe(const AWork: TWorkProgress);
var
  LTotal: Integer;
begin
  Inc(Calls);
  Check((Synth.ScheduledCount = ExpectedCount) and
    (Synth.ReservedWork = ExpectedWork) and
    (Synth.NextFrame = ExpectedFrame) and not Synth.Failed,
    'Callback sees complete unchanged accepted scheduler');
  Check((AWork.Units = wuItems) and (AWork.Pass = 0), 'Real item/pass mapping');

  if (AWork.Stage = 'schedule_keep_scan') or (AWork.Stage = 'schedule_keep_copy') then
  begin
    LTotal := ExpectedCount;
  end
  else if (AWork.Stage = 'schedule_tone_validation') or
    (AWork.Stage = 'schedule_voice_construction') then
  begin
    LTotal := InputCount;
  end
  else
  begin
    Check(AWork.Stage = 'schedule_replace_ready', 'Declared preparation stage');
    LTotal := 1;
    Ready := True;
  end;
  Check(AWork.Total = LTotal, 'Stage total counts actual input items');

  if Stage <> AWork.Stage then
  begin
    Stage := AWork.Stage;
    Done := 0;
  end;
  Check((AWork.Done >= Done) and (AWork.Done - Done <= 128) and
    (AWork.Done <= AWork.Total), 'Bounded actual loop visits');
  Done := AWork.Done;
  Interior := Interior or ((Done > 0) and (Done < AWork.Total));

  if Reenter then
  begin
    Synth.Reset;
  end;

  if Calls = AbortAt then
  begin
    Marker := Exception.Create('Original scheduler callback cancellation');
    raise Marker;
  end;
end;

function Graph: TBusGraph;
var
  LSettings: array[0..0] of TBusSettings;
  LEcho: TEchoSettings;
begin
  LSettings[0] := DefaultBusSettings;
  Result := TBusGraph.Create(8000, LSettings);
  try
    LEcho := DefaultEchoSettings(8000);
    LEcho.DelayFrames := 16;
    LEcho.Feedback := 0.5;
    LEcho.WetGain := 0.5;
    Result.AddEffect(0, TEchoEffect.Create(8000, LEcho));
  except
    Result.Free;
    raise;
  end;
end;

function Tone(const AStart: Int64; const AFrequency: Double): TFrameTone;
begin
  Result := Default(TFrameTone);
  Result.Voice := DefaultSynthVoice;
  Result.Voice.Gain := 0.05;
  Result.Voice.Envelope.AttackSeconds := 0.002;
  Result.Voice.Envelope.DecaySeconds := 0.003;
  Result.Voice.Envelope.SustainLevel := 0.6;
  Result.Voice.Envelope.ReleaseSeconds := 0.002;
  Result.StartFrame := AStart;
  Result.GateFrames := 40;
  Result.FrequencyHz := AFrequency;
  Result.Velocity := 0.8;
  Result.Seed := 731;
end;

procedure Seed(const ASynth: TScheduledSynth);
var
  LId: Int64;
  LLeft, LRight: Double;
  I: Integer;
begin
  Check(ASynth.TrySchedule(Tone(0, 330), 0, 3, LId) = srScheduled, 'Committed voice');
  Check(ASynth.TrySchedule(Tone(40, 440), 0, 7, LId) = srScheduled, 'Replaced future voice');
  Check(ASynth.TrySchedule(Tone(50, 550), 0, 8, LId) = srScheduled, 'Untouched future group');

  for I := 1 to 8 do
  begin
    ASynth.Process(LLeft, LRight);
  end;
end;

function Exercise(const APoint: Integer; const ARetry, AReenter: Boolean;
  const AEmpty: Boolean = False): Integer;
var
  LGraph, LControlGraph: TBusGraph;
  LSynth, LControl: TScheduledSynth;
  LObserver: TObserver;
  LTones: TFrameTones;
  LId, LExpectedId: Int64;
  LRejected: Boolean;
  LCalls: Integer;
  LLeft, LRight, LExpectedLeft, LExpectedRight: Double;
  I: Integer;
begin
  LGraph := Graph;
  LControlGraph := nil;
  LSynth := nil;
  LControl := nil;
  LObserver := nil;
  try
    LControlGraph := Graph;
    LSynth := TScheduledSynth.Create(LGraph, 16);
    LControl := TScheduledSynth.Create(LControlGraph, 16);
    Seed(LSynth);
    Seed(LControl);
    if not AEmpty then
    begin
      SetLength(LTones, 2);
      LTones[0] := Tone(24, 220);
      LTones[1] := Tone(64, 660);
    end;
    LObserver := TObserver.Create;
    LObserver.Attach(LSynth, Length(LTones));
    LObserver.AbortAt := APoint;
    LObserver.Reenter := AReenter;
    LRejected := False;
    LId := 999;
    try
      Check(LSynth.TryReplaceFuture(7, 24, 0, LTones, LId,
        LObserver.Observe) = srScheduled, 'Observed replacement admission');
    except
      on E: Exception do
      begin
        LRejected := True;

        if AReenter then
        begin
          Check(E is EAudio, 'Existing scheduler reentry guard');
        end
        else
        begin
          Check(E = LObserver.Marker, 'Original callback exception identity');
        end;
      end;
    end;
    Result := LObserver.Calls;
    Check(LRejected = ((APoint > 0) or AReenter), 'Expected cancellation disposition');

    if LRejected then
    begin
      Inc(Aborts);
      Check((LId = 999) and (LSynth.ScheduledCount = 3) and
        (LSynth.ReservedWork = LObserver.ExpectedWork) and
        (LSynth.NextFrame = 8) and not LSynth.Failed,
        'Failed preparation preserves IDs, voices, work, clock and health');
    end;

    if not LRejected or ARetry then
    begin
      if ARetry then
      begin
        LObserver.Attach(LSynth, Length(LTones));
        Check(LSynth.TryReplaceFuture(7, 24, 0, LTones, LId,
          LObserver.Observe) = srScheduled, 'Same-instance observed retry');
      end;
      Check(LControl.TryReplaceFuture(7, 24, 0, LTones, LExpectedId) = srScheduled,
        'Original nil-observer reference');
      if AEmpty then
      begin
        Check((LId = 0) and (LId = LExpectedId), 'Empty replacement consumes no identity');
      end
      else
      begin
        Check((LId = 4) and (LId = LExpectedId), 'Cancellation consumes no identities');
      end;
      Check(LObserver.Ready, 'Final ready callback before successful publication');
    end;
    LCalls := LObserver.Calls;

    for I := 1 to 160 do
    begin
      LSynth.Process(LLeft, LRight);
      LControl.Process(LExpectedLeft, LExpectedRight);
      Check((LLeft = LExpectedLeft) and (LRight = LExpectedRight),
        'Exact original future stereo and retained bus-history replay');
    end;
    Check(LObserver.Calls = LCalls, 'Scheduler retains no preparation observer');
    if not AEmpty then
    begin
      Check((LTones[0].StartFrame = 24) and (LTones[1].StartFrame = 64) and
        (LTones[0].FrequencyHz = 220) and (LTones[1].FrequencyHz = 660),
        'Borrowed replacement tones unchanged');
    end;
  finally
    LObserver.Free;
    LSynth.Free;
    LControl.Free;
    LGraph.Free;
    LControlGraph.Free;
  end;
end;

function ExerciseBulk(const APoint: Integer): Integer;
var
  LGraph: TBusGraph;
  LSynth: TScheduledSynth;
  LObserver: TObserver;
  LTones: TFrameTones;
  LId: Int64;
  LRejected: Boolean;
  I: Integer;
begin
  LGraph := Graph;
  LSynth := nil;
  LObserver := nil;
  try
    LSynth := TScheduledSynth.Create(LGraph, 512);

    for I := 0 to 299 do
    begin
      Check(LSynth.TrySchedule(Tone(8 + I * 2, 330), 0, I mod 2, LId) =
        srScheduled, 'Bulk original voice admission');
    end;
    SetLength(LTones, 260);

    for I := 0 to High(LTones) do
    begin
      LTones[I] := Tone(8 + I * 2, 440);
    end;
    LObserver := TObserver.Create;
    LObserver.Attach(LSynth, Length(LTones));
    LObserver.AbortAt := APoint;
    LId := 999;
    LRejected := False;
    try
      Check(LSynth.TryReplaceFuture(0, 0, 0, LTones, LId, LObserver.Observe) =
        srScheduled, 'Bulk observed replacement');
    except
      on E: Exception do
      begin
        LRejected := True;
        Check(E = LObserver.Marker, 'Bulk original exception identity');
      end;
    end;
    Result := LObserver.Calls;
    Check(LRejected = (APoint > 0), 'Bulk cancellation disposition');

    if LRejected then
    begin
      Inc(Aborts);
      Check((LId = 999) and (LSynth.ScheduledCount = 300) and
        (LSynth.ReservedWork = LObserver.ExpectedWork) and
        (LSynth.NextFrame = 0) and not LSynth.Failed,
        'Bulk cancellation preserves complete accepted state');
      LObserver.Attach(LSynth, Length(LTones));
      Check(LSynth.TryReplaceFuture(0, 0, 0, LTones, LId, LObserver.Observe) =
        srScheduled, 'Bulk same-instance retry');
    end;
    Check(LId = 301, 'Bulk abort consumes no identities');
    Check(LObserver.Interior and LObserver.Ready and (LSynth.ScheduledCount = 410),
      'Bulk scans and construction expose interior work before atomic commit');
  finally
    LObserver.Free;
    LSynth.Free;
    LGraph.Free;
  end;
end;

var
  CallCount, EmptyCallCount, BulkCallCount, I: Integer;
begin
  CallCount := Exercise(0, False, False);

  for I := 1 to CallCount do
  begin
    Exercise(I, False, False);
    Exercise(I, True, False);
  end;
  Exercise(0, False, True);
  Exercise(0, True, True);
  EmptyCallCount := Exercise(0, False, False, True);

  for I := 1 to EmptyCallCount do
  begin
    Exercise(I, False, False, True);
    Exercise(I, True, False, True);
  end;
  BulkCallCount := ExerciseBulk(0);

  for I := 1 to BulkCallCount do
  begin
    ExerciseBulk(I);
  end;
  WriteLn('Scheduler replacement progress: ', Checks, ' checks / ', Aborts,
    ' original aborts; ', CallCount, '/', EmptyCallCount, '/', BulkCallCount,
    ' small/empty/bulk checkpoints');
end.
