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
program pythian_delay_modulated_demo;

{$mode delphi}
{$H+}

uses
  SysUtils,
  Math,
  pythian.audio,
  pythian.automation,
  pythian.delay.modulated,
  pythian.effects,
  pythian.oscillator,
  pythian.synth,
  pythian.wave;

const
  CRate = 24000;
  CInputFrames = CRate * 4;
  CTailFrames = CRate div 2;
  CSectionFrames = CInputFrames + CTailFrames;

function ProcessPhrase(const AInput: TAudioClip; const AFlanger: Boolean): TAudioClip;
var
  LSettings: TModulatedDelaySettings;
  LLeftLfo: TAutomationCurve;
  LRightLfo: TAutomationCurve;
  LLeftDelay: TAutomationCurve;
  LRightDelay: TAutomationCurve;
  LEffect: TModulatedDelayEffect;
  LChain: TEffectChain;
begin
  LLeftLfo := nil;
  LRightLfo := nil;
  LLeftDelay := nil;
  LRightDelay := nil;
  LEffect := nil;
  LChain := nil;
  try
    LSettings := Default(TModulatedDelaySettings);
    if AFlanger then
    begin
      { Four-second period; opposing 1..5 ms delays, with feedback. }
      LLeftLfo := TAutomationCurve.CreateLfo(CRate * 4, alsSine);
      LRightLfo := TAutomationCurve.CreateLfo(CRate * 4, alsSine, CRate * 2);
      LLeftDelay := TAutomationCurve.CreateAffine(LLeftLfo, 48, 72);
      LRightDelay := TAutomationCurve.CreateAffine(LRightLfo, 48, 72);
      LSettings.MaximumDelayFrames := 144;
      LSettings.Feedback := 0.55;
      LSettings.DryGain := 0.65;
      LSettings.WetGain := 0.5;
    end
    else
    begin
      { Two-second period; 14..26 ms delays, quarter-cycle stereo offset. }
      LLeftLfo := TAutomationCurve.CreateLfo(CRate * 2, alsSine);
      LRightLfo := TAutomationCurve.CreateLfo(CRate * 2, alsSine, CRate div 2);
      LLeftDelay := TAutomationCurve.CreateAffine(LLeftLfo, 144, 480);
      LRightDelay := TAutomationCurve.CreateAffine(LRightLfo, 144, 480);
      LSettings.MaximumDelayFrames := 720;
      LSettings.Feedback := 0;
      LSettings.DryGain := 0.8;
      LSettings.WetGain := 0.5;
    end;
    LEffect := TModulatedDelayEffect.Create(CRate, LSettings, LLeftDelay, LRightDelay);
    FreeAndNil(LLeftLfo);
    FreeAndNil(LRightLfo);
    FreeAndNil(LLeftDelay);
    FreeAndNil(LRightDelay);
    LChain := TEffectChain.Create(CRate);
    LChain.Add(LEffect);
    LEffect := nil;
    Result := RenderEffectClip(AInput, LChain, CTailFrames);
  finally
    LChain.Free;
    LEffect.Free;
    LRightDelay.Free;
    LLeftDelay.Free;
    LRightLfo.Free;
    LLeftLfo.Free;
  end;
end;

procedure RenderDemo(const AFileName: String);
const
  CPitches: array[0..5] of Integer = (57, 60, 64, 67, 64, 62);
var
  LTones: TFrameTones;
  LDry: TAudioClip;
  LChorus: TAudioClip;
  LFlanger: TAudioClip;
  LCombined: TAudioClip;
  LSections: array[0..2] of TAudioClip;
  LSamples: TAudioSamples;
  LPeak: Double;
  LFrame: Integer;
  LChannel: Integer;
  LSection: Integer;
  I: Integer;
begin
  LDry := nil;
  LChorus := nil;
  LFlanger := nil;
  LCombined := nil;
  try
    SetLength(LTones, Length(CPitches));
    for I := 0 to High(LTones) do
    begin
      LTones[I].Voice := DefaultSynthVoice;
      LTones[I].Voice.Shape := wsSaw;
      LTones[I].Voice.Gain := 0.22;
      LTones[I].Voice.Envelope.AttackSeconds := 0.01;
      LTones[I].Voice.Envelope.ReleaseSeconds := 0.12;
      LTones[I].StartFrame := I * (CRate * 3 div 5);
      LTones[I].GateFrames := CRate * 9 div 20;
      LTones[I].FrequencyHz := MidiFrequency(CPitches[I]);
      LTones[I].Velocity := 0.8;
      LTones[I].Seed := I + 1;
    end;
    LDry := RenderFrameTones(LTones, CRate, CInputFrames);
    LChorus := ProcessPhrase(LDry, False);
    LFlanger := ProcessPhrase(LDry, True);
    LSections[0] := LDry;
    LSections[1] := LChorus;
    LSections[2] := LFlanger;
    SetLength(LSamples, 3 * CSectionFrames * 2);
    LPeak := 0;
    for LSection := 0 to 2 do
    begin
      for LFrame := 0 to LSections[LSection].FrameCount - 1 do
      begin
        for LChannel := 0 to 1 do
        begin
          LSamples[(LSection * CSectionFrames + LFrame) * 2 + LChannel] :=
            LSections[LSection].SampleAt(LFrame, LChannel);
          LPeak := Max(LPeak, Abs(LSections[LSection].SampleAt(LFrame, LChannel)));
        end;
      end;
    end;
    if LPeak >= 1 then
    begin
      raise EAudio.Create('Demonstration exceeds PCM16 headroom');
    end;
    LCombined := TAudioClip.Create(CRate, 2, LSamples);
    SaveWavePcm16(AFileName, LCombined);
    WriteLn(LCombined.FrameCount, ' stereo frames at ', CRate, ' Hz; peak ', LPeak:0:10);
  finally
    LCombined.Free;
    LFlanger.Free;
    LChorus.Free;
    LDry.Free;
  end;
end;

begin
  try
    if ParamCount <> 1 then
    begin
      WriteLn('Usage: pythian.delay.modulated.demo OUTPUT.wav');
      Halt(2);
    end;
    RenderDemo(ParamStr(1));
    WriteLn('13.5 seconds: dry at 0; chorus at 4.5; feedback flanger at 9.');
    WriteLn('Same native phrase, explicit half-second tails; comparison is not loudness matched.');
  except
    on LException: Exception do
    begin
      WriteLn(StdErr, LException.ClassName, ': ', LException.Message);
      Halt(1);
    end;
  end;
end.

