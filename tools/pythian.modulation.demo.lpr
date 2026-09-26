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
program pythian_modulation_demo;

{$mode delphi}
{$H+}

uses
  SysUtils,
  Math,
  pythian.audio,
  pythian.wave,
  pythian.automation,
  pythian.additive,
  pythian.modulation,
  pythian.oscillator,
  pythian.synth,
  pythian.resample;

const
  CRate = 48000;
  CSectionFrames = 72000;

function MakeCurve(const AFirst, ALast: Double; const AFrames: Int64;
  const ATransition: TAutomationTransition): TAutomationCurve;
var
  LPoints: TAutomationPoints;
begin
  SetLength(LPoints, 2);
  LPoints[0].Value := AFirst;
  LPoints[0].Transition := ATransition;
  LPoints[1].Frame := AFrames;
  LPoints[1].Value := ALast;
  Result := TAutomationCurve.Create(LPoints);
end;

function RenderFmSection(const APhaseModulation: Boolean): TAudioClip;
var
  LCurve: TAutomationCurve;
  LOscillator: TFmOscillator;
  LHighRate: TAudioClip;
  LSamples: TAudioSamples;
  LFrame: Integer;
  LTime: Double;
  LValue: Double;
  LFade: Double;
begin
  if APhaseModulation then
  begin
    LCurve := MakeCurve(5, 0.25, CSectionFrames * 4, atExponential);
  end
  else
  begin
    LCurve := MakeCurve(1100, 20, CSectionFrames * 4, atExponential);
  end;
  try
    LOscillator := TFmOscillator.Create(CRate * 4);
    try
      SetLength(LSamples, CSectionFrames * 4);
      for LFrame := 0 to High(LSamples) do
      begin
        LTime := LFrame / (CRate * 4);
        if APhaseModulation then
        begin
          LValue := LOscillator.NextPm(330, 467, LCurve.ValueAt(LFrame));
        end
        else
        begin
          LValue := LOscillator.NextFm(220, 440, LCurve.ValueAt(LFrame));
        end;
        LFade := Max(0, Min(1, Min(LTime / 0.005, (1.45 - LTime) / 0.05)));
        LSamples[LFrame] := 0.35 * LValue * LFade * Exp(-LTime);
      end;
    finally
      LOscillator.Free;
    end;
    LHighRate := TAudioClip.Create(CRate * 4, 1, LSamples);
    try
      Result := ResampleClip(LHighRate, CRate);
    finally
      LHighRate.Free;
    end;
  finally
    LCurve.Free;
  end;
end;

procedure RenderDemo(const AFileName: String);
var
  LPitch: TAutomationCurve;
  LCutoff: TAutomationCurve;
  LPan: TAutomationCurve;
  LTones: TFrameTones;
  LPartials: TAdditivePartials;
  LAdditive: TAdditiveOscillator;
  LLfo: TPhaseOscillator;
  LClip: TAudioClip;
  LSection: TAudioClip;
  LSamples: TAudioSamples;
  LFrame: Integer;
  LIndex: Integer;
  LTime: Double;
  LValue: Double;
  LFrequency: Double;
  LPartialGains: array[0..3] of Double;
  LPartial: Integer;
begin
  LPitch := MakeCurve(125, 42, 7200, atExponential);
  try
    LCutoff := MakeCurve(600, 160, 12000, atExponential);
    try
      LPan := MakeCurve(-0.6, 0.6, 19200, atLinear);
      try
        SetLength(LTones, 6);
        for LIndex := 0 to High(LTones) do
        begin
          LTones[LIndex].Voice := DefaultSynthVoice;
          LTones[LIndex].Voice.OscillatorQuality := oqPolynomial;
          LTones[LIndex].Voice.Gain := 0.5;
          LTones[LIndex].StartFrame := LIndex * 24000;
          LTones[LIndex].GateFrames := 16800;
          LTones[LIndex].Velocity := 1;
          LTones[LIndex].FrequencyHz := 110;
          if LIndex < 3 then
          begin
            LTones[LIndex].Voice.Shape := wsSine;
            LTones[LIndex].Voice.Envelope.AttackSeconds := 0.003;
            LTones[LIndex].Voice.Envelope.ReleaseSeconds := 0.08;
            LTones[LIndex].Voice.Automation.FrequencyHz := LPitch;
          end
          else
          begin
            LTones[LIndex].Voice.Shape := wsSaw;
            LTones[LIndex].Voice.Automation.CutoffHz := LCutoff;
            LTones[LIndex].Voice.Automation.Pan := LPan;
          end;
        end;
        LClip := RenderFrameTones(LTones, CRate, 5 * CSectionFrames);
        try
          LSamples := LClip.CopySamples;
        finally
          LClip.Free;
        end;
      finally
        LPan.Free;
      end;
    finally
      LCutoff.Free;
    end;
  finally
    LPitch.Free;
  end;

  SetLength(LPartials, 4);
  LPartials[0].Ratio := 1;
  LPartials[0].Gain := 0.7;
  LPartials[1].Ratio := 2.01;
  LPartials[1].Gain := 0.3;
  LPartials[2].Ratio := 2.76;
  LPartials[2].Gain := 0.15;
  LPartials[3].Ratio := 5.4;
  LPartials[3].Gain := 0.1;
  LAdditive := TAdditiveOscillator.Create(CRate, LPartials);
  try
    LLfo := TPhaseOscillator.Create(CRate);
    try
      for LFrame := 0 to CSectionFrames - 1 do
      begin
        LTime := LFrame / CRate;
        LFrequency := FrequencyWithCents(440, 15 * LLfo.Next(5));
        for LPartial := 0 to High(LPartialGains) do
        begin
          LPartialGains[LPartial] := Exp(-(2 + LPartial) * LTime);
        end;
        LValue := LAdditive.Next(LFrequency, LPartialGains) * 0.35 *
          Max(0, Min(1, Min(LTime / 0.005, (1.45 - LTime) / 0.05)));
        LSamples[(2 * CSectionFrames + LFrame) * 2] := LValue;
        LSamples[(2 * CSectionFrames + LFrame) * 2 + 1] := LValue;
      end;
    finally
      LLfo.Free;
    end;
  finally
    LAdditive.Free;
  end;
  for LIndex := 3 to 4 do
  begin
    LSection := RenderFmSection(LIndex = 4);
    try
      for LFrame := 0 to CSectionFrames - 1 do
      begin
        LValue := LSection.SampleAt(LFrame, 0);
        LSamples[(LIndex * CSectionFrames + LFrame) * 2] := LValue;
        LSamples[(LIndex * CSectionFrames + LFrame) * 2 + 1] := LValue;
      end;
    finally
      LSection.Free;
    end;
  end;
  LClip := TAudioClip.Create(CRate, 2, LSamples);
  try
    SaveWavePcm16(AFileName, LClip);
  finally
    LClip.Free;
  end;
end;

begin
  try
    if ParamCount <> 1 then
    begin
      WriteLn('Usage: pythian.modulation.demo OUTPUT.wav');
      Halt(2);
    end;
    RenderDemo(ParamStr(1));
    WriteLn('7.5 seconds, stereo 48000 Hz, five 1.5-second sections:');
    WriteLn('Pitch-fall kicks; cutoff/pan bass; additive vibrato; linear FM; phase modulation.');
    WriteLn('The final two sections render at 4x rate and use sinc downsampling.');
  except
    on LException: Exception do
    begin
      WriteLn(StdErr, LException.ClassName, ': ', LException.Message);
      Halt(1);
    end;
  end;
end.
