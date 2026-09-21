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
program pythian.tests.articulation;

{$mode delphi}
{$H+}

uses
  SysUtils,
  Math,
  pythian.audio,
  pythian.wave,
  pythian.time,
  pythian.music,
  pythian.articulation;

procedure Check(const ACondition: Boolean; const AMessage: String);
begin
  if not ACondition then
  begin
    raise EAudio.Create(AMessage);
  end;
end;

procedure CheckGrid;
const
  Expected: array[0..11] of Integer = (0, 1, 1, 1, 0, 0, 0, 0, 0, 1, 1, 0);
var
  LTempos: TTempoChanges;
  LClock: TTempoMap;
  LPlan: TArticulationPlan;
  LSource: TAudioClip;
  LOutput: TAudioClip;
  LSamples: TAudioSamples;
  LIndex: Integer;
  LGate: TArticulationGate;
  LRejected: Boolean;
begin
  SetLength(LTempos, 2);
  LTempos[0] := MakeTempoChange(0, 500000);
  LTempos[1] := MakeTempoChange(480, 750000);
  LClock := TTempoMap.Create(480, 960, LTempos);
  try
    LPlan := PlanGridArticulation(LClock, 0, 240, 'ahra', 10, 1, 1);
    try
      Check((LPlan.FrameCount = 12) and (LPlan.GateCount = 2), 'Tempo-change grid extent');
      LGate := LPlan.GateAt(0);
      Check((LGate.StartFrame = 0) and (LGate.EndFrame = 5), 'Hold extends across cells');
      LGate := LPlan.GateAt(1);
      Check((LGate.StartFrame = 8) and (LGate.EndFrame = 12), 'Second gate floor timing');
      SetLength(LSamples, 26);
      for LIndex := 0 to 12 do
      begin
        LSamples[2 * LIndex] := 0.5;
        LSamples[2 * LIndex + 1] := -0.25;
      end;
      LSource := TAudioClip.Create(10, 2, LSamples);
      try
        LOutput := RenderArticulatedClip(LSource, LPlan);
        try
          Check(LOutput.FrameCount = 12, 'Exact plan length trims extra source');
          for LIndex := 0 to 11 do
          begin
            Check(LOutput.SampleAt(LIndex, 0) = Expected[LIndex] * 0.5,
              'Independent exact fade and rest samples');
            Check(LOutput.SampleAt(LIndex, 1) = Expected[LIndex] * -0.25,
              'Stereo balance and polarity');
            Check(LSource.SampleAt(LIndex, 0) = 0.5, 'Input remains unchanged');
          end;
        finally
          LOutput.Free;
        end;
      finally
        LSource.Free;
      end;
    finally
      LPlan.Free;
    end;
    LPlan := PlanGridArticulation(LClock, 240, 240, 'ar', 10, 0, 0);
    try
      Check((LPlan.FrameCount = 6) and (LPlan.GateAt(0).EndFrame = 3),
        'Nonzero origin subtracts absolute floors without resetting fractional clock');
    finally
      LPlan.Free;
    end;
    LPlan := PlanGridArticulation(LClock, 0, 240, 'aaaa', 10, 0, 0);
    try
      Check(LPlan.GateCount = 4, 'Attacks retrigger rather than merge');
    finally
      LPlan.Free;
    end;
    LRejected := False;
    try
      LPlan := PlanGridArticulation(LClock, 0, 240, 'arh', 10, 0, 0);
      LPlan.Free;
    except
      on EAudio do
      begin
        LRejected := True;
      end;
    end;
    Check(LRejected, 'Hold after rest rejects');
    LRejected := False;
    try
      LPlan := PlanGridArticulation(LClock, 0, 1, 'a', 10, 0, 0);
      LPlan.Free;
    except
      on EAudio do
      begin
        LRejected := True;
      end;
    end;
    Check(LRejected, 'Sub-frame grid cell rejects');
  finally
    LClock.Free;
  end;
end;

procedure CheckNotes;
var
  LTempos: TTempoChanges;
  LNotes: TNoteGates;
  LSequence: TNoteSequence;
  LPlan: TArticulationPlan;
  LSource: TAudioClip;
  LOutput: TAudioClip;
  LSamples: TAudioSamples;
  LIndex: Integer;
  LOmitted: Integer;
begin
  SetLength(LTempos, 1);
  LTempos[0] := MakeTempoChange(0, 500000);
  SetLength(LNotes, 3);
  for LIndex := 0 to 2 do
  begin
    LNotes[LIndex] := Default(TNoteGate);
    LNotes[LIndex].Pitch := 60;
    LNotes[LIndex].Velocity := 64;
  end;
  LNotes[0].EndTick := 720;
  LNotes[1].StartTick := 480;
  LNotes[1].EndTick := 960;
  LNotes[1].Velocity := 127;
  LNotes[2].EndTick := 1;
  LSequence := TNoteSequence.Create(480, 1440, LTempos, LNotes);
  try
    LPlan := PlanNoteArticulation(LSequence, 10, 0, 0, LOmitted);
    try
      Check((LOmitted = 1) and (LPlan.GateCount = 2) and (LPlan.FrameCount = 15),
        'Note sub-frame accounting and trailing rest');
      SetLength(LSamples, 15);
      for LIndex := 0 to 14 do
      begin
        LSamples[LIndex] := 1;
      end;
      LSource := TAudioClip.Create(10, 1, LSamples);
      try
        LOutput := RenderArticulatedClip(LSource, LPlan);
        try
          for LIndex := 0 to 4 do
          begin
            Check(Abs(LOutput.SampleAt(LIndex, 0) - 64 / 127) < 0.0000001,
              'MIDI velocity gain');
          end;
          for LIndex := 5 to 9 do
          begin
            Check(LOutput.SampleAt(LIndex, 0) = 1, 'Overlapping notes use maximum');
          end;
          for LIndex := 10 to 14 do
          begin
            Check(LOutput.SampleAt(LIndex, 0) = 0, 'Exact trailing silence');
          end;
        finally
          LOutput.Free;
        end;
      finally
        LSource.Free;
      end;
    finally
      LPlan.Free;
    end;
  finally
    LSequence.Free;
  end;
end;

procedure CheckLimits;
var
  LGates: TArticulationGates;
  LPlan: TArticulationPlan;
  LSource: TAudioClip;
  LOutput: TAudioClip;
  LSamples: TAudioSamples;
  LRejected: Boolean;
  LIndex: Integer;
begin
  SetLength(LGates, 1);
  LGates[0].StartFrame := 0;
  LGates[0].EndFrame := 3;
  LGates[0].Gain := 1;
  LPlan := TArticulationPlan.Create(10, 3, 4, 4, LGates);
  try
    LGates[0].Gain := 0;
    Check(LPlan.GateAt(0).Gain = 1, 'Plan detaches input array');
    SetLength(LSamples, 3);
    for LIndex := 0 to 2 do
    begin
      LSamples[LIndex] := 1;
    end;
    LSource := TAudioClip.Create(10, 1, LSamples);
    try
      LOutput := RenderArticulatedClip(LSource, LPlan);
      try
        Check((LOutput.SampleAt(0, 0) = 0) and (LOutput.SampleAt(1, 0) = 0.25) and
          (LOutput.SampleAt(2, 0) = 0), 'Overlapping fades on a short gate');
      finally
        LOutput.Free;
      end;
    finally
      LSource.Free;
    end;
    SetLength(LSamples, 2);
    LSource := TAudioClip.Create(10, 1, LSamples);
    try
      LRejected := False;
      try
        LOutput := RenderArticulatedClip(LSource, LPlan);
        LOutput.Free;
      except
        on EAudio do
        begin
          LRejected := True;
        end;
      end;
      Check(LRejected, 'Short source rejects instead of looping or padding');
    finally
      LSource.Free;
    end;
  finally
    LPlan.Free;
  end;
  SetLength(LGates, 5);
  for LIndex := 0 to High(LGates) do
  begin
    LGates[LIndex].StartFrame := 0;
    LGates[LIndex].EndFrame := MaximumArticulationSamples;
    LGates[LIndex].Gain := 1;
  end;
  LRejected := False;
  try
    LPlan := TArticulationPlan.Create(10, MaximumArticulationSamples, 0, 0, LGates);
    LPlan.Free;
  except
    on EAudio do
    begin
      LRejected := True;
    end;
  end;
  Check(LRejected, 'Overlapping work budget rejects before sample allocation');
end;

procedure CheckPublished(const ASourceName, AOutputName: String);
var
  LSource: TAudioClip;
  LOutput: TAudioClip;
  LFrame: Integer;
  LChannel: Integer;
  LOffset: Integer;
  LGain: Double;
  LExpected: Single;
begin
  { Independent oracle for eight ahrr groups at 120 BPM / eighth-note cells.
    Do not call the planner or renderer while checking the published bytes. }
  LSource := LoadWave(ASourceName);
  try
    LOutput := LoadWave(AOutputName);
    try
      Check((LSource.SampleRate = 44100) and (LOutput.SampleRate = 44100) and
        (LSource.Channels = 2) and (LOutput.Channels = 2) and
        (LOutput.FrameCount = 352800), 'Published stereo grid format and eight-second extent');
      for LFrame := 0 to LOutput.FrameCount - 1 do
      begin
        LOffset := LFrame mod 44100;
        LGain := 0;
        if LOffset < 22050 then
        begin
          LGain := Min(1.0, Min(LOffset / 221, (22049 - LOffset) / 441));
        end;
        for LChannel := 0 to 1 do
        begin
          LExpected := LSource.SampleAt(LFrame, LChannel) * LGain;
          Check(QuantizePcm16(LOutput.SampleAt(LFrame, LChannel)) = QuantizePcm16(LExpected),
            'Published sample differs from independent gate/fade/PCM calculation');
        end;
      end;
      WriteLn('Published grid: 352800 stereo frames checked, including 176400 exact rest frames');
    finally
      LOutput.Free;
    end;
  finally
    LSource.Free;
  end;
end;

begin
  try
    CheckGrid;
    CheckNotes;
    CheckLimits;
    if ParamCount = 2 then
    begin
      CheckPublished(ParamStr(1), ParamStr(2));
    end
    else if ParamCount <> 0 then
    begin
      raise EAudio.Create('Optional fixture arguments: SOURCE.wav ARTICULATED.wav');
    end;
    WriteLn('Articulation timing, signal, ownership and budget checks passed');
  except
    on LException: Exception do
    begin
      WriteLn(StdErr, LException.Message);
      Halt(1);
    end;
  end;
end.
