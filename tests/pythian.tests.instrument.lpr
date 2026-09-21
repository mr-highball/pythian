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
program pythian_instrument_test;
{$mode delphi}{$H+}
uses
  SysUtils, pythian.audio, pythian.synth, pythian.source.sample,
  pythian.instrument, pythian.bus, pythian.schedule;
procedure Check(const AValue: Boolean; const AText: String);
begin
  if not AValue then
  begin
    raise Exception.Create(AText);
  end;
end;
procedure Run;
var
  LData: TAudioSamples;
  LClip: TAudioClip;
  LActual: TAudioClip;
  LExpected: TAudioClip;
  LStreamed: TAudioClip;
  LGraph: TBusGraph;
  LSynth: TScheduledSynth;
  LId: Int64;
  LMaximumDifference: Double;
  LDifference: Double;
  LFactory: TSampleSourceFactory;
  LZones: TInstrumentZones;
  LCopy: TInstrumentZones;
  LMap: TInstrument;
  LBad: TInstrument;
  LPlan: TFrameTones;
  LManual: TFrameTones;
  LIndices: TInstrumentZoneIndices;
  LFailed: Boolean;
  I: Integer;
  J: Integer;
begin
  SetLength(LData, 4);
  LData[0] := 0.5;
  LData[1] := 0.25;
  LData[2] := -0.5;
  LData[3] := -0.25;
  LClip := TAudioClip.Create(8000, 1, LData);
  try
    LFactory := TSampleSourceFactory.Create(LClip, 0, 4, 440, spSustainLoop, sqLinear);
  finally
    LClip.Free;
  end;
  try
    SetLength(LZones, 3);
    for I := 0 to 2 do
    begin
      LZones[I].MinimumKey := 60;
      LZones[I].MaximumKey := 72;
      LZones[I].MinimumVelocity := 1;
      LZones[I].MaximumVelocity := 127;
      LZones[I].Voice := DefaultSynthVoice;
      LZones[I].Voice.SourceFactory := LFactory;
      LZones[I].Voice.Gain := 0.2 + I * 0.1;
      LZones[I].Voice.Pan := -0.5 + I * 0.5;
      LZones[I].Voice.Envelope.ReleaseSeconds := 0.002;
    end;
    LZones[0].MaximumVelocity := 63;
    LZones[1].MinimumVelocity := 64;
    LZones[2].MinimumVelocity := 100;
    LMap := TInstrument.Create(LZones);
    try
      LZones[1].Voice.Gain := 9;
      LCopy := LMap.CopyZones;
      LCopy[1].MinimumKey := 0;
      LIndices := LMap.SelectZones(60, 63);
      Check((Length(LIndices) = 1) and (LIndices[0] = 0), 'Lower inclusive bounds');
      LIndices := LMap.SelectZones(72, 64);
      Check((Length(LIndices) = 1) and (LIndices[0] = 1), 'Velocity split');
      LIndices := LMap.SelectZones(69, 100);
      Check((Length(LIndices) = 2) and (LIndices[0] = 1) and
        (LIndices[1] = 2), 'Overlaps retain ordered layers');
      LFailed := False;
      try
        LMap.SelectZones(59, 100);
      except
        on EAudio do
        begin
          LFailed := True;
        end;
      end;
      Check(LFailed, 'Missing zone rejects; copied edits do not extend it');
      LFailed := False;
      try
        LMap.SelectZones(69, 0);
      except
        on EAudio do
        begin
          LFailed := True;
        end;
      end;
      Check(LFailed, 'Zero velocity is not note admission');
      LPlan := LMap.PlanNote(69, 100, 8000, 11, 80, 731);
    finally
      LMap.Free;
    end;
    SetLength(LManual, 2);
    for I := 0 to 1 do
    begin
      LManual[I] := Default(TFrameTone);
      LManual[I].StartFrame := 11;
      LManual[I].GateFrames := 80;
      LManual[I].FrequencyHz := 440;
      LManual[I].Velocity := 100 / 127;
      LManual[I].Seed := 731;
      LManual[I].Voice := DefaultSynthVoice;
      LManual[I].Voice.SourceFactory := LFactory;
      LManual[I].Voice.Gain := 0.2 + (I + 1) * 0.1;
      LManual[I].Voice.Pan := I * 0.5;
      LManual[I].Voice.Envelope.ReleaseSeconds := 0.002;
    end;
    LActual := RenderFrameTones(LPlan, 8000);
    try
      LGraph := TBusGraph.Create(8000, [DefaultBusSettings]);
      try
        LSynth := TScheduledSynth.Create(LGraph, 1);
        try
          Check(LSynth.TryReplaceFuture(1, 0, 0, LPlan, LId) = srVoiceLimit,
            'Insufficient scheduler capacity rejects the whole layered note');
          Check(LSynth.ScheduledCount = 0, 'No partial layer was scheduled');
        finally
          LSynth.Free;
        end;
        LSynth := TScheduledSynth.Create(LGraph, 2);
        try
          Check(LSynth.TryReplaceFuture(1, 0, 0, LPlan, LId) = srScheduled,
            'Layered note uses existing atomic scheduler admission');
          LStreamed := RenderScheduledFrames(LSynth, LActual.FrameCount);
          try
            LMaximumDifference := 0;
            for I := 0 to LActual.FrameCount - 1 do
            begin
              for J := 0 to 1 do
              begin
                LDifference := Abs(LActual.SampleAt(I, J) - LStreamed.SampleAt(I, J));
                if LDifference > LMaximumDifference then
                begin
                  LMaximumDifference := LDifference;
                end;
                { Offline accumulates into Single after each voice; the bus
                  accumulates Double before the final clip conversion. }
                Check(LDifference <= 1E-8, 'Instrument schedule/offline sample tolerance');
                Check(QuantizePcm16(LActual.SampleAt(I, J)) =
                  QuantizePcm16(LStreamed.SampleAt(I, J)), 'Instrument schedule PCM16');
              end;
            end;
            WriteLn('Scheduler/offline maximum sample difference: ', LMaximumDifference);
          finally
            LStreamed.Free;
          end;
        finally
          LSynth.Free;
        end;
      finally
        LGraph.Free;
      end;
      LExpected := RenderFrameTones(LManual, 8000);
      try
        Check(LActual.FrameCount = LExpected.FrameCount, 'Layered duration');
        for I := 0 to LActual.FrameCount - 1 do
        begin
          for J := 0 to 1 do
          begin
            Check(LActual.SampleAt(I, J) = LExpected.SampleAt(I, J),
              'Detached instrument plan agrees with independently authored layered PCM');
          end;
        end;
      finally
        LExpected.Free;
      end;
    finally
      LActual.Free;
    end;
    LZones[1].Voice.Gain := 0.3;
    LZones[2].Voice.Gain := -1;
    LBad := TInstrument.Create(LZones);
    try
      LFailed := False;
      try
        LPlan := LBad.PlanNote(69, 100, 8000, 5, 80, 731);
      except
        on EAudio do
        begin
          LFailed := True;
        end;
      end;
      Check(LFailed and (LPlan[0].StartFrame = 11), 'Late layer failure preserves prior plan');
    finally
      LBad.Free;
    end;
    SetLength(LZones, MaximumInstrumentLayers + 1);
    for I := 1 to High(LZones) do
    begin
      LZones[I] := LZones[0];
    end;
    LBad := nil;
    LFailed := False;
    try
      LBad := TInstrument.Create(LZones);
    except
      on EAudio do
      begin
        LFailed := True;
      end;
    end;
    LBad.Free;
    Check(LFailed, 'Overlap limit rejects before retaining zones');
    SetLength(LZones, MaximumInstrumentLayers);
    LBad := TInstrument.Create(LZones);
    try
      LPlan := LBad.PlanNote(69, 63, 8000, 0, 80, 731);
      Check(Length(LPlan) = MaximumInstrumentLayers, 'Maximum overlap is admitted');
    finally
      LBad.Free;
    end;
  finally
    LFactory.Free;
  end;
end;
begin
  try
    Run;
    WriteLn('Instrument zones: boundaries, layers, detached plans, PCM and failure checks passed');
  except
    on LException: Exception do
    begin
      WriteLn(StdErr, LException.Message);
      Halt(1);
    end;
  end;
end.
