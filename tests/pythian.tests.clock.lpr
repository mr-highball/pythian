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
program pythian.tests.clock;

{$mode delphi}
{$H+}

uses
  SysUtils,
  pythian.audio,
  pythian.time
  {$IFDEF WFC_CLOCK_CHECKS}
  , wfc_music_ensemble_audio
  {$ENDIF}
  ;

procedure Check(const ACondition: Boolean; const AMessage: String);
begin
  if not ACondition then
  begin
    raise EAudio.Create(AMessage);
  end;
end;

function SameState(const ALeft, ARight: TTempoClockSnapshot): Boolean;
begin
  Result := (ALeft.TicksPerQuarter = ARight.TicksPerQuarter) and
    (ALeft.SampleRate = ARight.SampleRate) and (ALeft.TickCount = ARight.TickCount) and
    (ALeft.FrameCount = ARight.FrameCount) and
    (ALeft.FractionNumerator = ARight.FractionNumerator);
end;

procedure CheckIntervals;
var
  LMap: TTempoMap;
  LClock: TIncrementalTempoClock;
  LParts: TTempoIntervals;
  LIndex: Integer;
  LRejected: Boolean;
begin
  LMap := TTempoMap.Create(480, 1440, [MakeTempoChange(0, 500001),
    MakeTempoChange(480, 750001), MakeTempoChange(960, 250000)]);
  LClock := nil;
  try
    LParts := LMap.Intervals(240, 960);
    Check((Length(LParts) = 3) and (LParts[0].StartTick = 240) and
      (LParts[0].LengthTicks = 240) and (LParts[0].MicrosecondsPerQuarter = 500001) and
      (LParts[1].StartTick = 480) and (LParts[1].LengthTicks = 480) and
      (LParts[1].MicrosecondsPerQuarter = 750001) and (LParts[2].StartTick = 960) and
      (LParts[2].LengthTicks = 240) and (LParts[2].MicrosecondsPerQuarter = 250000),
      'Tempo partitions exactly cover independent interior range');
    LClock := TIncrementalTempoClock.Create(480, 44100);
    LClock.Advance(240, 500001);
    for LIndex := 0 to High(LParts) do
    begin
      LClock.Advance(LParts[LIndex].LengthTicks, LParts[LIndex].MicrosecondsPerQuarter);
    end;
    Check(LClock.Snapshot.FrameCount =
      (Int64(480) * 500001 + Int64(480) * 750001 + Int64(240) * 250000) *
      44100 div (Int64(480) * 1000000), 'Partitions carry exact fractional clock history');
    LParts := LMap.Intervals(480, 480);
    Check((Length(LParts) = 1) and (LParts[0].MicrosecondsPerQuarter = 750001),
      'Boundary change belongs to following interval');
    LRejected := False;
    try
      LMap.Intervals(1440, 1);
    except
      on EAudio do
      begin
        LRejected := True;
      end;
    end;
    Check(LRejected and (LMap.ChangeAt(1).Tick = 480), 'Out-of-scope partition preserves clock');
    WriteLn('Finite tempo partitions preserve interval boundaries and fractional timing');
  finally
    LClock.Free;
    LMap.Free;
  end;
end;

procedure CheckClock;
var
  LClock: TIncrementalTempoClock;
  LSaved: TTempoClockSnapshot;
  LBad: TTempoClockSnapshot;
  LWeightedTicks: Int64;
  LExpected: Int64;
  LPrevious: Int64;
  LDelta: Int64;
  LTicks: Integer;
  LTempo: Integer;
  LIndex: Integer;
  LRejected: Boolean;
begin
  LClock := TIncrementalTempoClock.Create(997, 384000);
  try
    LWeightedTicks := 0;
    LPrevious := 0;
    for LIndex := 1 to 128 do
    begin
      LTicks := 17 + LIndex mod 10;
      LTempo := 500001;
      if LIndex mod 2 = 0 then
      begin
        LTempo := MaximumTempoMicroseconds;
      end;
      LDelta := LClock.Advance(LTicks, LTempo);
      Inc(LWeightedTicks, Int64(LTicks) * LTempo);
      { This deliberately short oracle product fits Int64; no production
        decomposition is reused in the expected calculation. }
      LExpected := LWeightedTicks * 384000 div 997000000;
      Check((LClock.Snapshot.FrameCount = LExpected) and (LDelta = LExpected - LPrevious) and
        (LClock.Snapshot.FractionNumerator = LWeightedTicks * 384000 mod 997000000),
        'Independent rational oracle across native-rate and MIDI-tempo extremes');
      LPrevious := LExpected;
    end;
    LSaved := LClock.Snapshot;
    Check((LClock.Advance(0, 500000) = 0) and SameState(LSaved, LClock.Snapshot),
      'Zero interval validates without changing fractional state');
    LBad := LSaved;
    LBad.SampleRate := 44100;
    LRejected := False;
    try
      LClock.Restore(LBad);
    except
      on EAudio do
      begin
        LRejected := True;
      end;
    end;
    Check(LRejected and SameState(LSaved, LClock.Snapshot), 'Restore rejects changed clock units');
    LBad := LSaved;
    LBad.FractionNumerator := Int64(997) * 1000000;
    LRejected := False;
    try
      LClock.Restore(LBad);
    except
      on EAudio do
      begin
        LRejected := True;
      end;
    end;
    Check(LRejected and SameState(LSaved, LClock.Snapshot), 'Non-normalized restore preserves clock');
    LRejected := False;
    try
      LClock.Advance(-1, 500000);
    except
      on EAudio do
      begin
        LRejected := True;
      end;
    end;
    Check(LRejected and SameState(LSaved, LClock.Snapshot), 'Negative interval preserves clock');
    LRejected := False;
    try
      LClock.Advance(0, 0);
    except
      on EAudio do
      begin
        LRejected := True;
      end;
    end;
    Check(LRejected and SameState(LSaved, LClock.Snapshot), 'Invalid tempo still rejects on zero ticks');
    LClock.Reset;
    LClock.Advance(2048, 500001);
    LSaved := LClock.Snapshot;
    LClock.Reset;
    for LIndex := 1 to 2048 do
    begin
      LClock.Advance(1, 500001);
    end;
    Check(SameState(LSaved, LClock.Snapshot), 'Split intervals exactly equal whole interval');
    LClock.Restore(LSaved);
    LExpected := LClock.Advance(37, 123457);
    LBad := LClock.Snapshot;
    LClock.Restore(LSaved);
    Check((LClock.Advance(37, 123457) = LExpected) and SameState(LBad, LClock.Snapshot),
      'Restored fractional history replays exact future interval');
  finally
    LClock.Free;
  end;
  LClock := TIncrementalTempoClock.Create(1, 1);
  try
    LSaved := LClock.Snapshot;
    LSaved.TickCount := (Int64(1) shl 53) + 1;
    LSaved.FrameCount := LSaved.TickCount;
    LClock.Restore(LSaved);
    Check((LClock.Advance(1, 1000000) = 1) and
      (LClock.Snapshot.FrameCount = LSaved.FrameCount + 1), 'Native counters remain exact above 2^53');
    LSaved.TickCount := High(Int64);
    LSaved.FrameCount := High(Int64);
    LClock.Restore(LSaved);
    LRejected := False;
    try
      LClock.Advance(1, 1000000);
    except
      on EAudio do
      begin
        LRejected := True;
      end;
    end;
    Check(LRejected and SameState(LSaved, LClock.Snapshot), 'Tick-total overflow preserves clock');
  finally
    LClock.Free;
  end;
  LClock := TIncrementalTempoClock.Create(1, MaximumSampleRate);
  try
    LRejected := False;
    for LIndex := 1 to 1000 do
    begin
      LSaved := LClock.Snapshot;
      try
        LClock.Advance(High(Integer), MaximumTempoMicroseconds);
      except
        on EAudio do
        begin
          LRejected := True;
          Break;
        end;
      end;
    end;
    Check(LRejected and (LIndex > 1) and SameState(LSaved, LClock.Snapshot),
      'Reachable frame-total overflow rejects atomically without an invalid intermediate state');
  finally
    LClock.Free;
  end;
  LClock := TIncrementalTempoClock.Create(High(Integer), MaximumSampleRate);
  try
    LClock.Advance(1, MaximumTempoMicroseconds);
    LClock.Advance(High(Integer) - 1, MaximumTempoMicroseconds);
    LExpected := Int64(MaximumTempoMicroseconds) * MaximumSampleRate;
    Check((LClock.Snapshot.FrameCount = LExpected div 1000000) and
      (LClock.Snapshot.FractionNumerator =
        (LExpected mod 1000000) * High(Integer)), 'Largest PPQ and fractional carry remain bounded');
  finally
    LClock.Free;
  end;
end;

{$IFDEF WFC_CLOCK_CHECKS}
procedure CheckWfc;
var
  LReference: TWfcMusicEnsembleAudioClock;
  LClock: TIncrementalTempoClock;
  LIndex: Integer;
  LLength: Integer;
  LTempo: Integer;
begin
  LReference := Default(TWfcMusicEnsembleAudioClock);
  LClock := TIncrementalTempoClock.Create(997, 44100);
  try
    for LIndex := 0 to 199 do
    begin
      LLength := LIndex mod 19;
      LTempo := 1 + (LIndex * 39371) mod 4000000;
      if LIndex = 199 then
      begin
        LLength := High(Integer);
      end;
      AdvanceWfcMusicEnsembleAudioClock(LReference, LLength, LTempo, 997, 44100);
      LClock.Advance(LLength, LTempo);
      Check((LReference.TickCount = LClock.Snapshot.TickCount) and
        (LReference.FrameCount = LClock.Snapshot.FrameCount) and
        (LReference.FractionNumerator = LClock.Snapshot.FractionNumerator),
        'Exact agreement with actual WFC ensemble clock');
    end;
  finally
    LClock.Free;
  end;
  WriteLn('Actual WFC ensemble clock parity passed');
end;
{$ENDIF}

begin
  try
    CheckIntervals;
    CheckClock;
    {$IFDEF WFC_CLOCK_CHECKS}
    CheckWfc;
    {$ENDIF}
    WriteLn('Incremental clock fractions, restore, replay and overflow checks passed');
  except
    on LException: Exception do
    begin
      WriteLn(StdErr, LException.Message);
      Halt(1);
    end;
  end;
end.
