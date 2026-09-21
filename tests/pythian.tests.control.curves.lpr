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
program pythian_control_curves_test;

{$mode delphi}
{$H+}

uses
  SysUtils, Math, pythian.audio, pythian.automation, pythian.synth,
  pythian.bus, pythian.schedule, pythian.envelope, pythian.source.sample, pythian.wave;

procedure Check(const ACondition: Boolean; const AMessage: String);
begin
  if not ACondition then
  begin
    raise Exception.Create(AMessage);
  end;
end;

procedure CheckDefinitions;
var
  LCurve: TAutomationCurve;
  LAffine: TAutomationCurve;
  LNext: TAutomationCurve;
  LRejected: Boolean;
  I: Integer;
begin
  LCurve := TAutomationCurve.CreateLfo(64, alsSine);
  LAffine := nil;
  try
    Check((Abs(LCurve.ValueAt(16) - 1) < 1E-15) and
      (Abs(LCurve.ValueAt(48) + 1) < 1E-15), 'Sine quarter phases');
    Check(LCurve.ValueAt(High(Int64)) = LCurve.ValueAt(63),
      'Exact modulo phase at High(Int64)');
    LAffine := TAutomationCurve.CreateAffine(LCurve, -0.5, 0.5);
    FreeAndNil(LCurve);
    Check((LAffine.Minimum = 0) and (LAffine.Maximum = 1) and
      (Abs(LAffine.ValueAt(16)) < 1E-15), 'Negative scale bounds and independent source lifetime');
    LRejected := False;
    try
      LAffine.CopyPoints;
    except
      on EAudio do
      begin
        LRejected := True;
      end;
    end;
    Check(LRejected, 'Generated curves cannot masquerade as finite points');
    LCurve := LAffine.Clone;
    Check(LCurve.ValueAt(23) = LAffine.ValueAt(23), 'Clone preserves generated composition');
  finally
    LAffine.Free;
    LCurve.Free;
  end;
  LCurve := TAutomationCurve.CreateLfo(High(Int64), alsTriangle, High(Int64) - 1);
  try
    Check(Abs(LCurve.ValueAt(1)) < 1E-15, 'Overflow-safe phase wrap');
  finally
    LCurve.Free;
  end;
  LCurve := TAutomationCurve.CreateLfo(16, alsTriangle, 4);
  try
    Check((LCurve.ValueAt(0) = 1) and (LCurve.ValueAt(4) = 0) and
      (LCurve.ValueAt(8) = -1) and (LCurve.ValueAt(12) = 0), 'Triangle phase convention');
    for I := 2 to MaximumAutomationDepth do
    begin
      LNext := TAutomationCurve.CreateAffine(LCurve, 1, 0);
      LCurve.Free;
      LCurve := LNext;
    end;
    LRejected := False;
    try
      LCurve := TAutomationCurve.CreateAffine(LCurve, 1, 0);
    except
      on EAudio do
      begin
        LRejected := True;
      end;
    end;
    Check(LRejected and (LCurve.Depth = MaximumAutomationDepth) and
      (LCurve.ValueAt(0) = 1), 'Depth rejection preserves prior curve');
  finally
    LCurve.Free;
  end;
end;

procedure CheckRendering;
var
  LBase: TAutomationCurve;
  LControls: array[0..3] of TAutomationCurve;
  LReferences: array[0..3] of TAutomationCurve;
  LPoints: TAutomationPoints;
  LTones: TFrameTones;
  LReferenceTones: TFrameTones;
  LActual: TAudioClip;
  LExpected: TAudioClip;
  LStreamed: TAudioClip;
  LGraph: TBusGraph;
  LSynth: TScheduledSynth;
  LId: Int64;
  LSin: Double;
  LMaximumError: Double;
  LBad: TAutomationCurve;
  LRejected: Boolean;
  I: Integer;
  J: Integer;
  K: Integer;
begin
  LBase := nil;
  LActual := nil;
  LExpected := nil;
  LStreamed := nil;
  LGraph := nil;
  LSynth := nil;
  LBad := nil;
  for I := 0 to 3 do
  begin
    LControls[I] := nil;
    LReferences[I] := nil;
  end;
  try
    LBase := TAutomationCurve.CreateLfo(64, alsSine);
    LControls[0] := TAutomationCurve.CreateAffine(LBase, 24, 0);
    LControls[1] := TAutomationCurve.CreateAffine(LBase, 0.5, 0);
    LControls[2] := TAutomationCurve.CreateAffine(LBase, 0.25, 0.75);
    LControls[3] := TAutomationCurve.CreateAffine(LBase, 500, 1200);
    SetLength(LPoints, 512);
    for I := 0 to 3 do
    begin
      for J := 0 to High(LPoints) do
      begin
        LSin := Sin(2 * Pi * (J mod 64) / 64);
        LPoints[J].Frame := J;
        case I of
          0: LPoints[J].Value := 24 * LSin;
          1: LPoints[J].Value := 0.5 * LSin;
          2: LPoints[J].Value := 0.75 + 0.25 * LSin;
          3: LPoints[J].Value := 1200 + 500 * LSin;
        end;
      end;
      LReferences[I] := TAutomationCurve.Create(LPoints);
    end;
    SetLength(LTones, 1);
    LTones[0].Voice := DefaultSynthVoice;
    LTones[0].Voice.Envelope.ReleaseSeconds := 0;
    LTones[0].Voice.Automation.PitchCents := LControls[0];
    LTones[0].Voice.Automation.Pan := LControls[1];
    LTones[0].Voice.Automation.GainMultiplier := LControls[2];
    LTones[0].Voice.Automation.CutoffHz := LControls[3];
    LTones[0].FrequencyHz := 220;
    LTones[0].Velocity := 0.8;
    LTones[0].StartFrame := 11;
    LTones[0].GateFrames := 512;
    LTones[0].Seed := 731;
    LReferenceTones := Copy(LTones);
    LReferenceTones[0].Voice.Automation.PitchCents := LReferences[0];
    LReferenceTones[0].Voice.Automation.Pan := LReferences[1];
    LReferenceTones[0].Voice.Automation.GainMultiplier := LReferences[2];
    LReferenceTones[0].Voice.Automation.CutoffHz := LReferences[3];
    LExpected := RenderFrameTones(LReferenceTones, 8000);
    LActual := RenderFrameTones(LTones, 8000);
    LGraph := TBusGraph.Create(8000, [DefaultBusSettings]);
    LSynth := TScheduledSynth.Create(LGraph, 1);
    Check(LSynth.TrySchedule(LTones[0], 0, 1, LId) = srScheduled, 'Periodic note admission');
    FreeAndNil(LBase);
    for I := 0 to 3 do
    begin
      FreeAndNil(LControls[I]);
    end;
    LStreamed := RenderScheduledFrames(LSynth, LExpected.FrameCount);
    LMaximumError := 0;
    for I := 0 to LExpected.FrameCount - 1 do
    begin
      for J := 0 to 1 do
      begin
        for K := 0 to 1 do
        begin
          if K = 0 then
          begin
            LSin := LActual.SampleAt(I, J);
          end
          else
          begin
            LSin := LStreamed.SampleAt(I, J);
          end;
          LMaximumError := Max(LMaximumError, Abs(LSin - LExpected.SampleAt(I, J)));
          Check(QuantizePcm16(LSin) = QuantizePcm16(LExpected.SampleAt(I, J)),
            'Periodic and retained streaming PCM match independent frame controls');
        end;
      end;
    end;
    Check(LMaximumError < 1E-8, 'Periodic signal error remains below sample precision');
    WriteLn('Maximum periodic/reference sample difference: ', LMaximumError);
    LBase := TAutomationCurve.CreateLfo(64, alsSine);
    LBad := TAutomationCurve.CreateAffine(LBase, 2400, 0);
    LTones[0].Voice := DefaultSynthVoice;
    LTones[0].Voice.Automation.PitchCents := LBad;
    LTones[0].FrequencyHz := 2500;
    LRejected := False;
    try
      ValidateFrameTone(LTones[0], 8000);
    except
      on EAudio do
      begin
        LRejected := True;
      end;
    end;
    Check(LRejected, 'Full LFO excursion rejects Nyquist crossing before playback');
  finally
    LBad.Free;
    LSynth.Free;
    LGraph.Free;
    LStreamed.Free;
    LExpected.Free;
    LActual.Free;
    LBase.Free;
    for I := 0 to 3 do
    begin
      LReferences[I].Free;
      LControls[I].Free;
    end;
  end;
end;

procedure CheckGateEnvelopes;
var
  LHeld: TAutomationCurve;
  LRelease: TAutomationCurve;
  LEnvelope: TGateEnvelope;
  LCandidate: TGateEnvelope;
  LPoints: TAutomationPoints;
  LSamples: TAudioSamples;
  LSource: TAudioClip;
  LFactory: TSampleSourceFactory;
  LTones: TFrameTones;
  LSeconds: TTones;
  LActual: TAudioClip;
  LExpected: TAudioClip;
  LSecondsClip: TAudioClip;
  LPrefix: TAudioClip;
  LTail: TAudioClip;
  LGraph: TBusGraph;
  LSynth: TScheduledSynth;
  LId: Int64;
  LLevel: Double;
  LValue: Double;
  LFrame: Integer;
  LChannel: Integer;
  LNoteFrame: Integer;
  LRejected: Boolean;
begin
  LHeld := nil;
  LRelease := nil;
  LEnvelope := nil;
  LCandidate := nil;
  LFactory := nil;
  LSource := nil;
  LActual := nil;
  LExpected := nil;
  LSecondsClip := nil;
  LPrefix := nil;
  LTail := nil;
  LGraph := nil;
  LSynth := nil;
  try
    SetLength(LPoints, 4);
    LPoints[0].Transition := atLinear;
    LPoints[1].Frame := 8;
    LPoints[1].Value := 1;
    LPoints[1].Transition := atLinear;
    LPoints[2].Frame := 16;
    LPoints[2].Value := 0.5;
    LPoints[2].Transition := atLinear;
    LPoints[3].Frame := 24;
    LPoints[3].Value := 0.8;
    LHeld := TAutomationCurve.Create(LPoints);
    SetLength(LPoints, 3);
    LPoints[0].Value := 1;
    LPoints[1].Frame := 4;
    LPoints[1].Value := 0.25;
    LPoints[2].Frame := 8;
    LPoints[2].Value := 0;
    LRelease := TAutomationCurve.Create(LPoints);
    LEnvelope := TGateEnvelope.Create(LHeld, LRelease, 8);
    Check((LEnvelope.ValueAt(4, 4) = 0.5) and
      (Abs(LEnvelope.ValueAt(6, 4) - 0.3125) < 1E-15) and
      (LEnvelope.ValueAt(12, 4) = 0), 'Release captures held level and follows its own curve');
    Check(Abs(LEnvelope.ValueAt(High(Int64), High(Int64) - 4) - 0.2) < 1E-15,
      'Envelope evaluation avoids gate-plus-release overflow');
    LRejected := False;
    try
      LCandidate := TGateEnvelope.Create(LHeld, LHeld, 8);
    except
      on EAudio do
      begin
        LRejected := True;
      end;
    end;
    Check(LRejected and (LCandidate = nil), 'Invalid release endpoints preserve candidate');
    LCandidate := TGateEnvelope.Create(LHeld, nil, 0);
    Check(LCandidate.ValueAt(4, 4) = 0, 'Immediate cut ends exactly at the gate');
    FreeAndNil(LCandidate);
    LCandidate := TGateEnvelope.Create(LHeld, LRelease, High(Int64));
    SetLength(LTones, 1);
    LTones[0].Voice := DefaultSynthVoice;
    LTones[0].Voice.GateEnvelope := LCandidate;
    LTones[0].FrequencyHz := 220;
    LTones[0].Velocity := 1;
    LTones[0].GateFrames := 1;
    LRejected := False;
    try
      ValidateFrameTone(LTones[0], 8000);
    except
      on EAudio do
      begin
        LRejected := True;
      end;
    end;
    Check(LRejected, 'Unbounded custom release rejects before frame addition');
    FreeAndNil(LCandidate);
    FreeAndNil(LHeld);
    FreeAndNil(LRelease);
    LSamples := [0.25, -0.125, 0.25, -0.125, 0.25, -0.125, 0.25, -0.125];
    LSource := TAudioClip.Create(8000, 2, LSamples);
    LFactory := TSampleSourceFactory.Create(LSource, 0, 4, 220, spLoop, sqLinear);
    FreeAndNil(LSource);
    SetLength(LTones, 1);
    LTones[0].Voice := DefaultSynthVoice;
    LTones[0].Voice.SourceFactory := LFactory;
    LTones[0].Voice.GateEnvelope := LEnvelope;
    LTones[0].Voice.Envelope.ReleaseSeconds := -1; { Inactive ADSR must not determine extent. }
    LTones[0].StartFrame := 3;
    LTones[0].GateFrames := 12;
    LTones[0].FrequencyHz := 220;
    LTones[0].Velocity := 1;
    LActual := RenderFrameTones(LTones, 8000);
    Check((LActual.FrameCount = 23) and (SynthReleaseFrames(LTones[0].Voice, 8000) = 8),
      'Custom envelope defines exact note extent');
    SetLength(LSeconds, 1);
    LSeconds[0].Voice := LTones[0].Voice;
    LSeconds[0].StartSeconds := 3 / 8000;
    LSeconds[0].GateSeconds := 12 / 8000;
    LSeconds[0].FrequencyHz := 220;
    LSeconds[0].Velocity := 1;
    LSecondsClip := RenderTones(LSeconds, 8000);
    Check(LSecondsClip.FrameCount = 23, 'Seconds-based custom envelope uses the admitted integer gate');
    LGraph := TBusGraph.Create(8000, [DefaultBusSettings]);
    LSynth := TScheduledSynth.Create(LGraph, 1, SynthFrameCost(LTones[0].Voice, 8000) + 15);
    Check((LSynth.TrySchedule(LTones[0], 0, 1, LId) = srWorkLimit) and
      (LSynth.ScheduledCount = 0) and (LSynth.ReservedWork = 0),
      'Envelope work participates in transactional scheduler admission');
    FreeAndNil(LSynth);
    LSynth := TScheduledSynth.Create(LGraph, 1);
    LTones[0].GateFrames := 40;
    Check(LSynth.TrySchedule(LTones[0], 0, 1, LId) = srScheduled, 'Scheduled curve-envelope admission');
    FreeAndNil(LEnvelope);
    LPrefix := RenderScheduledFrames(LSynth, 15);
    Check(LSynth.ReleaseVoice(LId), 'Early note-off releases the admitted curve envelope');
    LSynth.ReleaseVoice(LId);
    LTail := RenderScheduledFrames(LSynth, 8);
    Check(LSynth.ActiveCount = 0, 'Released custom envelope ends after its exact tail');
    LTones[0].Voice.GateEnvelope := nil;
    LTones[0].Voice.Envelope.AttackSeconds := 0;
    LTones[0].Voice.Envelope.DecaySeconds := 0;
    LTones[0].Voice.Envelope.SustainLevel := 1;
    LTones[0].Voice.Envelope.ReleaseSeconds := 0;
    LTones[0].GateFrames := 20;
    LExpected := RenderFrameTones(LTones, 8000);
    for LFrame := 0 to 22 do
    begin
      LNoteFrame := LFrame - 3;
      LLevel := 0;
      if LNoteFrame >= 0 then
      begin
        if LNoteFrame < 8 then
        begin
          LLevel := LNoteFrame / 8;
        end
        else if LNoteFrame < 12 then
        begin
          LLevel := 1 - (LNoteFrame - 8) / 16;
        end
        else if LNoteFrame < 16 then
        begin
          LLevel := 0.75 * (1 - 0.75 * (LNoteFrame - 12) / 4);
        end
        else
        begin
          LLevel := 0.75 * 0.25 * (1 - (LNoteFrame - 16) / 4);
        end;
      end;
      for LChannel := 0 to 1 do
      begin
        LValue := LExpected.SampleAt(LFrame, LChannel) * LLevel;
        Check(Abs(LActual.SampleAt(LFrame, LChannel) - LValue) < 1E-8,
          'Both channels match independent held/release arithmetic');
        Check(LSecondsClip.SampleAt(LFrame, LChannel) = LActual.SampleAt(LFrame, LChannel),
          'Seconds and frame rendering match');
        if LFrame < 15 then
        begin
          LValue := LPrefix.SampleAt(LFrame, LChannel);
        end
        else
        begin
          LValue := LTail.SampleAt(LFrame - 15, LChannel);
        end;
        Check(Abs(LValue - LActual.SampleAt(LFrame, LChannel)) < 1E-8,
          'Scheduled early release matches offline gate after definitions are freed');
      end;
    end;
    WriteLn('Gated curves: independent stereo arithmetic, exact tails, seconds/frame parity, detached scheduled release and rejection passed');
  finally
    LSynth.Free;
    LGraph.Free;
    LTail.Free;
    LPrefix.Free;
    LSecondsClip.Free;
    LExpected.Free;
    LActual.Free;
    LFactory.Free;
    LSource.Free;
    LCandidate.Free;
    LEnvelope.Free;
    LRelease.Free;
    LHeld.Free;
  end;
end;

procedure CheckMeasuredEnvelope;
const
  CLevels: array[0..6] of Double = (0.125, 0.5, 1, 0.5, 0.125, 0, 0.03125);
var
  LSamples: TAudioSamples;
  LClip: TAudioClip;
  LTrace: TEnvelopeTrace;
  LEnvelope: TGateEnvelope;
  LCandidate: TGateEnvelope;
  LPoints: TAutomationPoints;
  I: Integer;
  LRejected: Boolean;
begin
  LClip := nil;
  LTrace := nil;
  LEnvelope := nil;
  LCandidate := nil;
  try
    SetLength(LSamples, 5156 * 2);
    for I := 0 to 5155 do
    begin
      LSamples[I * 2] := 0.75;
      LSamples[I * 2 + 1] := 0.9;
      if (I >= 3) and (I < 5153) then
      begin
        LSamples[I * 2 + 1] := CLevels[(I - 3) div 800] * (1 - 2 * (I mod 2));
      end;
    end;
    LClip := TAudioClip.Create(8000, 2, LSamples);
    LTrace := TEnvelopeTrace.Create(LClip, 3, 5150, 1, 800);
    if ParamCount > 0 then
    begin
      SaveWavePcm16(ParamStr(1), LClip);
    end;
    FreeAndNil(LClip);
    LPoints := LTrace.CopyRmsPoints;
    Check((Length(LPoints) = 7) and (LTrace.PeakRms = 1) and
      (LTrace.StartFrame = 3) and (LTrace.Channel = 1), 'Detached selected-channel RMS evidence');
    for I := 0 to 6 do
    begin
      Check(LPoints[I].Value = CLevels[I], 'RMS matches independent piecewise amplitudes');
    end;
    Check(LPoints[6].Frame = 4974, 'Partial RMS window uses its actual center and sample count');
    LPoints[0].Value := 0.99;
    LPoints := LTrace.CopyRmsPoints;
    Check(LPoints[0].Value = 0.125, 'RMS evidence copies are detached');
    LEnvelope := LTrace.CreateGateEnvelope(1999, 16000, 0.04);
    Check((LEnvelope.ReleaseFrames = 6302) and (LEnvelope.ValueAt(3998, 3998) = 1) and
      (LEnvelope.ValueAt(5598, 3998) = 0.5) and
      (LEnvelope.ValueAt(9948, 3998) = 0.03125) and
      (LEnvelope.ValueAt(10300, 3998) = 0), 'Measured envelope preserves knots, retiming and tail');
    LRejected := False;
    try
      LCandidate := LTrace.CreateGateEnvelope(1999, 16000, 0.01);
    except
      on EAudio do
      begin
        LRejected := True;
      end;
    end;
    Check(LRejected and (LCandidate = nil), 'Tail admission preserves the accepted envelope');
    LRejected := False;
    try
      LCandidate := LTrace.CreateGateEnvelope(1199, 16000, 0.1);
    except
      on EAudio do
      begin
        LRejected := True;
      end;
    end;
    Check(LRejected and (LCandidate = nil), 'A later rise above the declared gate rejects');
    LRejected := False;
    try
      LCandidate := LTrace.CreateGateEnvelope(1999, 1, 0.04);
    except
      on EAudio do
      begin
        LRejected := True;
      end;
    end;
    Check(LRejected and (LCandidate = nil), 'Collapsed retimed gate rejects');
    FreeAndNil(LTrace);
    Check(LEnvelope.ValueAt(5598, 3998) = 0.5, 'Measured envelope survives source and evidence release');
    LSamples := nil;
    SetLength(LSamples, 64);
    LClip := TAudioClip.Create(8000, 1, LSamples);
    LTrace := TEnvelopeTrace.Create(LClip, 0, 64, 0, 16);
    Check(LTrace.PeakRms = 0, 'Silence remains measurable evidence');
    LRejected := False;
    try
      LCandidate := LTrace.CreateGateEnvelope(23, 8000, 0.04);
    except
      on EAudio do
      begin
        LRejected := True;
      end;
    end;
    Check(LRejected and (LCandidate = nil), 'Silent evidence cannot become a normalized envelope');
    WriteLn('Measured RMS envelope: selected region/channel, partial window, detached evidence, retiming and admission passed');
  finally
    LCandidate.Free;
    LEnvelope.Free;
    LTrace.Free;
    LClip.Free;
  end;
end;

begin
  try
    CheckDefinitions;
    CheckRendering;
    CheckGateEnvelopes;
    CheckMeasuredEnvelope;
    WriteLn('Periodic automation: exact phase, affine ownership, bounds, native and scheduled PCM passed');
  except
    on LException: Exception do
    begin
      WriteLn(StdErr, LException.Message);
      Halt(1);
    end;
  end;
end.
