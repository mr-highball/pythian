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
program pythian_effects_demo;

{$mode delphi}
{$H+}

uses
  SysUtils,
  pythian.audio,
  pythian.wave,
  pythian.meter,
  pythian.oscillator,
  pythian.synth,
  pythian.biquad,
  pythian.dynamics,
  pythian.effects;

procedure RenderDemo(const AFileName: String);
const
  CPitches: array[0..7] of Integer = (48, 55, 60, 58, 51, 55, 62, 60);
var
  LTones: TFrameTones;
  LDry: TAudioClip;
  LWet: TAudioClip;
  LCombined: TAudioClip;
  LChain: TEffectChain;
  LGain: TGainEffect;
  LFilter: TBiquadSettings;
  LCompressor: TCompressorSettings;
  LSamples: TAudioSamples;
  LLevels: TAudioLevels;
  LIndex: Integer;
  LFrame: Integer;
  LChannel: Integer;
begin
  SetLength(LTones, 12);
  for LIndex := 0 to High(LTones) do
  begin
    LTones[LIndex].Voice := DefaultSynthVoice;
    LTones[LIndex].Voice.Shape := wsSaw;
    LTones[LIndex].Voice.OscillatorQuality := oqPolynomial;
    LTones[LIndex].Voice.FilterModel := vfmBiquad;
    LTones[LIndex].Voice.BiquadQ := 1.2;
    LTones[LIndex].Voice.CutoffHz := 1200 + (LIndex mod 3) * 800;
    LTones[LIndex].Voice.Gain := 0.5;
    LTones[LIndex].Voice.Pan := (LIndex mod 3 - 1) * 0.6;
    LTones[LIndex].Voice.Envelope.ReleaseSeconds := 0.04;
    LTones[LIndex].StartFrame := LIndex * 12000;
    LTones[LIndex].GateFrames := 8000;
    LTones[LIndex].FrequencyHz := MidiFrequency(CPitches[LIndex mod 8]);
    LTones[LIndex].Velocity := 0.3;
    if LIndex mod 4 = 0 then
    begin
      LTones[LIndex].Velocity := 1;
    end;
    LTones[LIndex].Seed := 731;
  end;
  LDry := RenderFrameTones(LTones, 48000, 144000);
  try
    LChain := TEffectChain.Create(48000);
    try
      LGain := TGainEffect.Create(48000, 1, 0.035);
      LChain.Add(LGain);
      LGain.SetTarget(2);
      LFilter := DefaultBiquadSettings;
      LFilter.Kind := bkHighPass;
      LFilter.FrequencyHz := 60;
      LChain.Add(TBiquadEffect.Create(48000, LFilter));
      LFilter.Kind := bkHighShelf;
      LFilter.FrequencyHz := 3000;
      LFilter.GainDb := 6;
      LChain.Add(TBiquadEffect.Create(48000, LFilter));
      LCompressor := DefaultCompressorSettings;
      LCompressor.MakeupDb := 8;
      LChain.Add(TCompressorEffect.Create(48000, LCompressor));
      LChain.Add(TLimiterEffect.Create(48000, -1, 0.05));
      LWet := RenderEffectClip(LDry, LChain);
      try
        SetLength(LSamples, LDry.FrameCount * 4);
        for LFrame := 0 to LDry.FrameCount - 1 do
        begin
          for LChannel := 0 to 1 do
          begin
            LSamples[LFrame * 2 + LChannel] := LDry.SampleAt(LFrame, LChannel);
            LSamples[(LDry.FrameCount + LFrame) * 2 + LChannel] :=
              LWet.SampleAt(LFrame, LChannel);
          end;
        end;
        LLevels := MeasureAudio(LDry);
        WriteLn('Dry left peak=', LLevels[0].Peak:0:9, ' rms=', LLevels[0].Rms:0:9);
        LLevels := MeasureAudio(LWet);
        WriteLn('Processed left peak=', LLevels[0].Peak:0:9, ' rms=', LLevels[0].Rms:0:9);
      finally
        LWet.Free;
      end;
    finally
      LChain.Free;
    end;
    LCombined := TAudioClip.Create(48000, 2, LSamples);
    try
      SaveWavePcm16(AFileName, LCombined);
    finally
      LCombined.Free;
    end;
  finally
    LDry.Free;
  end;
end;

begin
  try
    if ParamCount <> 1 then
    begin
      WriteLn('Usage: pythian.effects.demo OUTPUT.wav');
      Halt(2);
    end;
    RenderDemo(ParamStr(1));
    WriteLn('6 seconds, stereo 48000 Hz: dry phrase at 0s; processed repeat at 3s.');
    WriteLn('Processing: smoothed gain, high-pass, high shelf, linked compressor and sample limiter.');
    WriteLn('This comparison is not loudness matched.');
  except
    on LException: Exception do
    begin
      WriteLn(StdErr, LException.ClassName, ': ', LException.Message);
      Halt(1);
    end;
  end;
end.

