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

program pythian_reverb_demo;

{$mode delphi}
{$H+}

uses
  SysUtils,
  Math,
  pythian.audio,
  pythian.effects,
  pythian.oscillator,
  pythian.reverb,
  pythian.synth,
  pythian.wave;

const
  CRate = 24000;
  CInputFrames = CRate * 3;
  CTailFrames = CRate * 4;
  CSectionFrames = CInputFrames + CTailFrames;

function ProcessPhrase(const AInput: TAudioClip; const ALong: Boolean): TAudioClip;
var
  LSettings: TReverbSettings;
  LEffect: TReverbEffect;
  LChain: TEffectChain;
begin
  LEffect := nil;
  LChain := nil;
  try
    LSettings := DefaultReverbSettings(CRate);
    LSettings.DryGain := 0.85;
    LSettings.WetGain := 0.5;
    if ALong then
    begin
      LSettings.DecaySeconds := 2.8;
      LSettings.Damping := 0.65;
    end
    else
    begin
      LSettings.DecaySeconds := 0.7;
      LSettings.Damping := 0.15;
    end;
    LEffect := TReverbEffect.Create(CRate, LSettings);
    LChain := TEffectChain.Create(CRate);
    LChain.Add(LEffect);
    LEffect := nil;
    Result := RenderEffectClip(AInput, LChain, CTailFrames);
  finally
    LChain.Free;
    LEffect.Free;
  end;
end;

procedure RenderDemo(const AFileName: String);
const
  CPitches: array[0..5] of Integer = (60, 67, 64, 72, 67, 62);
var
  LTones: TFrameTones;
  LDry: TAudioClip;
  LShort: TAudioClip;
  LLong: TAudioClip;
  LCombined: TAudioClip;
  LSections: array[0..2] of TAudioClip;
  LSamples: TAudioSamples;
  LPeak: Double;
  LTailEnergy: Double;
  LValue: Double;
  LFrame: Integer;
  LChannel: Integer;
  LSection: Integer;
  LIndex: Integer;
begin
  LDry := nil;
  LShort := nil;
  LLong := nil;
  LCombined := nil;
  try
    SetLength(LTones, Length(CPitches));
    for LIndex := 0 to High(LTones) do
    begin
      LTones[LIndex].Voice := DefaultSynthVoice;
      LTones[LIndex].Voice.Shape := wsTriangle;
      LTones[LIndex].Voice.Gain := 0.3;
      LTones[LIndex].Voice.Envelope.AttackSeconds := 0.003;
      LTones[LIndex].Voice.Envelope.ReleaseSeconds := 0.08;
      LTones[LIndex].StartFrame := LIndex * (CRate * 9 div 20);
      LTones[LIndex].GateFrames := CRate * 3 div 20;
      LTones[LIndex].FrequencyHz := MidiFrequency(CPitches[LIndex]);
      LTones[LIndex].Velocity := 0.8;
      LTones[LIndex].Seed := LIndex + 1;
    end;
    LDry := RenderFrameTones(LTones, CRate, CInputFrames);
    LShort := ProcessPhrase(LDry, False);
    LLong := ProcessPhrase(LDry, True);
    LSections[0] := LDry;
    LSections[1] := LShort;
    LSections[2] := LLong;
    SetLength(LSamples, 3 * CSectionFrames * 2);
    LPeak := 0;
    for LSection := 0 to 2 do
    begin
      LTailEnergy := 0;
      for LFrame := 0 to LSections[LSection].FrameCount - 1 do
      begin
        for LChannel := 0 to 1 do
        begin
          LValue := LSections[LSection].SampleAt(LFrame, LChannel);
          LSamples[(LSection * CSectionFrames + LFrame) * 2 + LChannel] := LValue;
          LPeak := Max(LPeak, Abs(LValue));
          if LFrame >= CInputFrames then
          begin
            LTailEnergy := LTailEnergy + Sqr(LValue);
          end;
        end;
      end;
      if LSection > 0 then
      begin
        if LTailEnergy <= 0 then
        begin
          raise EAudio.Create('Reverb demonstration has no tail energy');
        end;
        WriteLn('Section ', LSection, ' tail RMS: ', Sqrt(LTailEnergy / (CTailFrames * 2)):0:10);
      end;
    end;
    if (LPeak <= 0) or (LPeak >= 1) then
    begin
      raise EAudio.Create('Reverb demonstration is silent or exceeds PCM16 headroom');
    end;
    LCombined := TAudioClip.Create(CRate, 2, LSamples);
    SaveWavePcm16(AFileName, LCombined);
    WriteLn(LCombined.FrameCount, ' stereo frames at ', CRate, ' Hz; peak ', LPeak:0:10);
  finally
    LCombined.Free;
    LLong.Free;
    LShort.Free;
    LDry.Free;
  end;
end;

begin
  try
    if ParamCount <> 1 then
    begin
      WriteLn('Usage: pythian.reverb.demo OUTPUT.wav');
      Halt(2);
    end;
    RenderDemo(ParamStr(1));
    WriteLn('21 seconds: dry at 0; short/bright reverb at 7; long/damped reverb at 14.');
    WriteLn('Same native phrase with four-second tail slots; comparison is not loudness matched.');
  except
    on LException: Exception do
    begin
      WriteLn(StdErr, LException.ClassName, ': ', LException.Message);
      Halt(1);
    end;
  end;
end.
