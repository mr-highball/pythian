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
program TimePortable;
{$mode delphi}
{$H+}
uses
  SysUtils,
  {$ifndef pas2js}Classes,{$endif}
  pythian.audio,
  pythian.time,
  pythian.synth,
  pythian.instrument;
var
  Checks: Integer;
procedure Check(const AValue: Boolean; const AMessage: String);
begin
  Inc(Checks);
  if not AValue then
  begin
    raise Exception.Create(AMessage);
  end;
end;
procedure Emit(const ALabel: String; const AState: TTempoClockSnapshot);
begin
  WriteLn(ALabel, ' ', AState.TickCount, ' ', AState.FrameCount, ' ', AState.FractionNumerator);
end;
procedure Same(const A, B: TTempoClockSnapshot);
begin
  Check((A.TicksPerQuarter = B.TicksPerQuarter) and (A.SampleRate = B.SampleRate) and
    (A.TickCount = B.TickCount) and (A.FrameCount = B.FrameCount) and
    (A.FractionNumerator = B.FractionNumerator), 'Clock state differs');
end;
{$ifndef pas2js}
procedure CompareLogs(const AFirst, ASecond: String);
var
  A: TStringList;
  B: TStringList;
  I: Integer;
  J: Integer;
  Parts: TStringList;
  Value: Int64;
begin
  A := TStringList.Create;
  B := TStringList.Create;
  Parts := TStringList.Create;
  Parts.Delimiter := ' ';
  Parts.StrictDelimiter := True;
  try
    A.LoadFromFile(AFirst);
    B.LoadFromFile(ASecond);
    Check((A.Count = 8) and (B.Count = 8), 'Timing row count differs');
    Check((Pos('maximum-ppq ', A[0]) = 1) and (Pos('large-ticks ', A[1]) = 1) and
      (Pos('tempo 0 ', A[2]) = 1) and (Pos('tempo 1 ', A[3]) = 1) and
      (Pos('tempo 2 ', A[4]) = 1) and (Pos('replay ', A[5]) = 1) and
      (Pos('large-frames ', A[6]) = 1) and (A[7] = 'pass timing-portable'),
      'Expected timing rows and pass marker required');
    for I := 0 to A.Count - 1 do
    begin
      Check(A[I] = B[I], 'Timing state or coordinate differs');
      if I < 7 then
      begin
        Parts.DelimitedText := A[I];
        if I in [2, 3, 4] then
          Check(Parts.Count = 6, 'Tempo row shape')
        else
          Check(Parts.Count = 4, 'Clock row shape');
        for J := 1 to Parts.Count - 1 do
        begin
          Check(TryStrToInt64(Parts[J], Value), 'Timing integer row');
        end;
      end;
    end;
  finally
    Parts.Free;
    B.Free;
    A.Free;
  end;
  WriteLn('PASS exact timing comparison');
end;
{$endif}
var
  Clock: TIncrementalTempoClock;
  Map: TTempoMap;
  Changes: TTempoChanges;
  Saved: TTempoClockSnapshot;
  Expected: TTempoClockSnapshot;
  Invalid: TTempoClockSnapshot;
  I: Integer;
  Failed: Boolean;
  F: Int64;
  Tone: TFrameTone;
  Zones: TInstrumentZones;
  Instrument: TInstrument;
  Plan: TFrameTones;
  MusicTime: TMusicTime;
  LengthFrames: Int64;
begin
  {$ifndef pas2js}
  if (ParamCount = 3) and (ParamStr(1) = '--compare') then
  begin
    CompareLogs(ParamStr(2), ParamStr(3));
    Exit;
  end;
  {$endif}
  Clock := TIncrementalTempoClock.Create(High(Integer), 384000);
  try
    Clock.Advance(1, MaximumTempoMicroseconds);
    Clock.Advance(High(Integer) - 1, MaximumTempoMicroseconds);
    Saved := Clock.Snapshot;
    Check((Saved.TickCount = 2147483647) and (Saved.FrameCount = 6442450) and
      (Saved.FractionNumerator = 1202590842320000), 'Maximum PPQ exact product');
    Emit('maximum-ppq', Saved);
    Clock.Restore(Saved);
    Clock.Advance(High(Integer), MaximumTempoMicroseconds);
    Clock.Advance(3, MaximumTempoMicroseconds);
    Saved := Clock.Snapshot;
    Check((Saved.TickCount > 4294967296) and (Saved.FrameCount > 0), 'Tick count exceeds 32 bits');
    Emit('large-ticks', Saved);
    Invalid := Saved;
    Invalid.FractionNumerator := -1;
    Failed := False;
    try
      Clock.Restore(Invalid);
    except
      on EAudio do
      begin
        Failed := True;
      end;
    end;
    Check(Failed, 'Invalid snapshot rejected');
    Same(Saved, Clock.Snapshot);
    Failed := False;
    try
      Clock.Advance(-1, 500000);
    except
      on EAudio do
      begin
        Failed := True;
      end;
    end;
    Check(Failed, 'Negative increment rejected');
    Same(Saved, Clock.Snapshot);
    Invalid := Saved;
    Invalid.TickCount := MaximumTimingInteger;
    Clock.Restore(Invalid);
    Failed := False;
    try
      Clock.Advance(1, 500000);
    except
      on EAudio do
      begin
        Failed := True;
      end;
    end;
    Check(Failed, 'Tick overflow rejected');
    Same(Invalid, Clock.Snapshot);
    Clock.Restore(Saved);
    Invalid := Saved;
    Invalid.FrameCount := MaximumTimingInteger;
    Clock.Restore(Invalid);
    Failed := False;
    try
      Clock.Advance(High(Integer), MaximumTempoMicroseconds);
    except
      on EAudio do
      begin
        Failed := True;
      end;
    end;
    Check(Failed, 'Frame overflow rejected');
    Same(Invalid, Clock.Snapshot);
    Clock.Restore(Saved);
    {$ifdef pas2js}
    Invalid := Saved;
    asm $mod.Invalid.FractionNumerator = 0.5; end;
    Failed := False;
    try
      Clock.Restore(Invalid);
    except
      on EAudio do
      begin
        Failed := True;
      end;
    end;
    Check(Failed, 'Fractional JavaScript snapshot rejected');
    Same(Saved, Clock.Snapshot);
    Invalid := Saved;
    asm $mod.Invalid.FractionNumerator = NaN; end;
    Failed := False;
    try
      Clock.Restore(Invalid);
    except
      on EAudio do
      begin
        Failed := True;
      end;
    end;
    Check(Failed, 'Nonfinite JavaScript snapshot rejected');
    Same(Saved, Clock.Snapshot);
    {$endif}
    {$ifdef pas2js}
    Invalid := Saved;
    Invalid.TickCount := MaximumTimingInteger;
    Inc(Invalid.TickCount);
    Failed := False;
    try
      Clock.Restore(Invalid);
    except
      on EAudio do
      begin
        Failed := True;
      end;
    end;
    Check(Failed, 'Unsafe JavaScript snapshot rejected');
    Same(Saved, Clock.Snapshot);
    Invalid := Saved;
    Invalid.TickCount := MaximumTimingInteger;
    Clock.Restore(Invalid);
    Failed := False;
    try
      Clock.Advance(1, 500000);
    except
      on EAudio do
      begin
        Failed := True;
      end;
    end;
    Check(Failed, 'Unsafe JavaScript increment rejected');
    Same(Invalid, Clock.Snapshot);
    {$endif}
  finally
    Clock.Free;
  end;
  SetLength(Changes, 3);
  Changes[0] := MakeTempoChange(0, 500001);
  Changes[1] := MakeTempoChange(480, 333333);
  Changes[2] := MakeTempoChange(960, 750001);
  Map := TTempoMap.Create(480, 1440, Changes);
  Clock := TIncrementalTempoClock.Create(480, 384000);
  try
    for I := 0 to 2 do
    begin
      Clock.Advance(480, Changes[I].MicrosecondsPerQuarter);
      Saved := Clock.Snapshot;
      Check(Saved.FrameCount = Map.FrameAtTick((I + 1) * 480, 384000, frFloor),
        'Incremental and map floor clock');
      F := Map.FrameAtTick((I + 1) * 480, 384000, frCeiling);
      Check((F = Saved.FrameCount) or (F = Saved.FrameCount + 1), 'Ceiling geometry');
      WriteLn('tempo ', I, ' ', Saved.TickCount, ' ', Saved.FrameCount, ' ',
        Saved.FractionNumerator, ' ', F);
    end;
    Failed := False;
    try
      Map.NextGridTick(-1, 384000, 1);
    except
      on EAudio do
      begin
        Failed := True;
      end;
    end;
    Check(Failed, 'Negative grid frame rejected');
    {$ifdef pas2js}
    F := MaximumTimingInteger;
    Inc(F);
    Failed := False;
    try
      Map.NextGridTick(F, 384000, 1);
    except
      on EAudio do
      begin
        Failed := True;
      end;
    end;
    Check(Failed, 'Unsafe grid frame rejected');
    {$endif}
    Saved := Clock.Snapshot;
    Clock.Advance(11, 222223);
    Expected := Clock.Snapshot;
    Clock.Restore(Saved);
    Clock.Advance(11, 222223);
    Same(Expected, Clock.Snapshot);
    Emit('replay', Expected);
  finally
    Clock.Free;
    Map.Free;
  end;
  Clock := TIncrementalTempoClock.Create(1, 384000);
  try
    Clock.Advance(2000, MaximumTempoMicroseconds);
    Saved := Clock.Snapshot;
    Check(Saved.FrameCount > 4294967296, 'Frame count exceeds 32 bits');
    Emit('large-frames', Saved);
  finally
    Clock.Free;
  end;
  Tone := Default(TFrameTone);
  Tone.Voice := DefaultSynthVoice;
  Tone.FrequencyHz := 440;
  Tone.Velocity := 0.5;
  Tone.GateFrames := 100;
  LengthFrames := ValidateFrameTone(Tone, 8000);
  Tone.StartFrame := MaximumTimingInteger - LengthFrames;
  Check(ValidateFrameTone(Tone, 8000) = LengthFrames, 'Voice ending at target maximum accepted');
  SetLength(Zones, 1);
  Zones[0].MinimumKey := 0;
  Zones[0].MaximumKey := 127;
  Zones[0].MinimumVelocity := 1;
  Zones[0].MaximumVelocity := 127;
  Zones[0].Voice := Tone.Voice;
  Instrument := TInstrument.Create(Zones);
  try
    Plan := Instrument.PlanNote(69, 100, 8000, Tone.StartFrame, 100, 731);
    Check((Length(Plan) = 1) and (Plan[0].StartFrame = Tone.StartFrame),
      'Instrument retains valid near-limit start');
    Tone.StartFrame := Tone.StartFrame + 1;
    Failed := False;
    try
      ValidateFrameTone(Tone, 8000);
    except
      on EAudio do
      begin
        Failed := True;
      end;
    end;
    Check(Failed, 'Voice end overflow rejected');
    Failed := False;
    try
      Plan := Instrument.PlanNote(69, 100, 8000, Tone.StartFrame, 100, 731);
    except
      on EAudio do
      begin
        Failed := True;
      end;
    end;
    Check(Failed and (Length(Plan) = 1) and (Plan[0].StartFrame = Tone.StartFrame - 1),
      'Rejected instrument plan preserves caller plan');
    {$ifndef pas2js}
    Tone.StartFrame := 9007199254740992;
    Check(ValidateFrameTone(Tone, 8000) = LengthFrames, 'Native retains values above 2^53');
    {$else}
    Tone.StartFrame := MaximumTimingInteger;
    Inc(Tone.StartFrame);
    Failed := False;
    try
      ValidateFrameTone(Tone, 8000);
    except
      on EAudio do
      begin
        Failed := True;
      end;
    end;
    Check(Failed, 'JavaScript rejects unsafe voice start');
    {$endif}
  finally
    Instrument.Free;
  end;
  MusicTime := Default(TMusicTime);
  MusicTime.Denominator := 1;
  MusicTime.FractionNumerator := 1;
  Failed := False;
  try
    MusicTimeToFrame(MusicTime, 8000);
  except
    on EAudio do
    begin
      Failed := True;
    end;
  end;
  Check(Failed, 'Invalid rational fraction rejected');
  MusicTime.Denominator := 0;
  Failed := False;
  try
    MusicTimeToFrame(MusicTime, 8000);
  except
    on EAudio do
    begin
      Failed := True;
    end;
  end;
  Check(Failed, 'Invalid rational denominator rejected');
  WriteLn('pass timing-portable');
end.
