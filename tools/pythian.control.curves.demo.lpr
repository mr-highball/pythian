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
program pythian_control_curves_demo;

{$mode delphi}
{$H+}

uses
  SysUtils,
  pythian.audio,
  pythian.automation,
  pythian.oscillator,
  pythian.synth,
  pythian.wave;

const
  CRate = 24000;
  CSectionFrames = 72000;
  CVibratoDepthCents = 15;

procedure RenderDemo(const AFileName: string);
var
  LFast: TAutomationCurve;
  LSlow: TAutomationCurve;
  LPitch: TAutomationCurve;
  LGain: TAutomationCurve;
  LPan: TAutomationCurve;
  LCutoff: TAutomationCurve;
  LTones: TFrameTones;
  LClip: TAudioClip;
  I: Integer;
begin
  LFast := nil;
  LSlow := nil;
  LPitch := nil;
  LGain := nil;
  LPan := nil;
  LCutoff := nil;
  LClip := nil;
  try
    LFast := TAutomationCurve.CreateLfo(CRate div 5, alsSine);
    LSlow := TAutomationCurve.CreateLfo(CRate * 2, alsTriangle);
    LPitch := TAutomationCurve.CreateAffine(LFast, CVibratoDepthCents, 0);
    LGain := TAutomationCurve.CreateAffine(LFast, 0.35, 0.65);
    LPan := TAutomationCurve.CreateAffine(LSlow, 0.8, 0);
    LCutoff := TAutomationCurve.CreateAffine(LSlow, 1200, 1600);
    { Derived controls own copies; shared definitions need no playback state. }
    FreeAndNil(LFast);
    FreeAndNil(LSlow);
    SetLength(LTones, 4);
    for I := 0 to High(LTones) do
    begin
      LTones[I].Voice := DefaultSynthVoice;
      LTones[I].Voice.Shape := wsSaw;
      LTones[I].Voice.Gain := 0.2;
      LTones[I].Voice.Envelope.AttackSeconds := 0.02;
      LTones[I].Voice.Envelope.DecaySeconds := 0.05;
      LTones[I].Voice.Envelope.SustainLevel := 0.8;
      LTones[I].Voice.Envelope.ReleaseSeconds := 0.1;
      LTones[I].StartFrame := I * CSectionFrames;
      LTones[I].GateFrames := CSectionFrames - CRate div 4;
      LTones[I].FrequencyHz := 220;
      LTones[I].Velocity := 0.8;
      LTones[I].Seed := 731;
    end;
    LTones[1].Voice.Automation.PitchCents := LPitch;
    LTones[2].Voice.Automation.GainMultiplier := LGain;
    LTones[3].Voice.Automation.Pan := LPan;
    LTones[3].Voice.Automation.CutoffHz := LCutoff;
    LClip := RenderFrameTones(LTones, CRate, 4 * CSectionFrames);
    SaveWavePcm16(AFileName, LClip);
    WriteLn(LClip.FrameCount, ' stereo frames at ', CRate, ' Hz');
  finally
    LClip.Free;
    LCutoff.Free;
    LPan.Free;
    LGain.Free;
    LPitch.Free;
    LSlow.Free;
    LFast.Free;
  end;
end;

begin
  try
    if ParamCount <> 1 then
    begin
      WriteLn('Usage: pythian.control.curves.demo OUTPUT.wav');
      Halt(2);
    end;
    RenderDemo(ParamStr(1));
    WriteLn('Four 3-second sections: plain; 5 Hz +/-15-cent vibrato; ',
      '5 Hz tremolo; cutoff and pan motion.');
  except
    on LException: Exception do
    begin
      WriteLn(StdErr, LException.ClassName, ': ', LException.Message);
      Halt(1);
    end;
  end;
end.
