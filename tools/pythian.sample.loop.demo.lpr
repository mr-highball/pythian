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

program pythian_sample_loop_demo;

{$mode delphi}
{$H+}

uses
  SysUtils,
  Math,
  pythian.audio,
  pythian.source.sample,
  pythian.synth,
  pythian.wave;

procedure Run(const AOutput: String);
const
  CRate = 12000;
var
  LSamples: TAudioSamples;
  LSource: TAudioClip;
  LOneShot: TSampleSourceFactory;
  LLoop: TSampleSourceFactory;
  LTones: TFrameTones;
  LOutput: TAudioClip;
  LFrame: Integer;
  LIndex: Integer;
  LLevel: Double;
  LTime: Double;
begin
  LSource := nil;
  LOneShot := nil;
  LLoop := nil;
  LOutput := nil;
  try
    SetLength(LSamples, 6000 * 2);
    for LFrame := 0 to 5999 do
    begin
      LTime := LFrame / CRate;
      LLevel := 0.6;
      if LFrame < 1200 then
      begin
        LLevel := LLevel * LFrame / 1200;
      end;
      if LFrame >= 2400 then
      begin
        LLevel := LLevel * Sqr((6000 - LFrame) / 3600);
      end;
      LSamples[2 * LFrame] := LLevel * Sin(2 * Pi * 220 * LTime);
      LSamples[2 * LFrame + 1] := LLevel * Sin(2 * Pi * 330 * LTime);
    end;
    LSource := TAudioClip.Create(CRate, 2, LSamples);
    LOneShot := TSampleSourceFactory.Create(LSource, 0, 6000, 220,
      spOneShot, sqSinc, 2);
    LLoop := TSampleSourceFactory.CreateLoopRegion(LSource, 0, 6000, 1200, 2400,
      220, spSustainLoop, sqSinc, 2);
    FreeAndNil(LSource);
    SetLength(LTones, 3);
    for LIndex := 0 to 2 do
    begin
      LTones[LIndex].Voice := DefaultSynthVoice;
      LTones[LIndex].Voice.SourceFactory := LLoop;
      if LIndex = 0 then
      begin
        LTones[LIndex].Voice.SourceFactory := LOneShot;
      end;
      LTones[LIndex].Voice.Gain := 0.8;
      LTones[LIndex].Voice.Envelope.AttackSeconds := 0;
      LTones[LIndex].Voice.Envelope.DecaySeconds := 0;
      LTones[LIndex].Voice.Envelope.SustainLevel := 1;
      LTones[LIndex].Voice.Envelope.ReleaseSeconds := 0.8;
      LTones[LIndex].StartFrame := LIndex * 2 * CRate;
      LTones[LIndex].GateFrames := 18000;
      LTones[LIndex].FrequencyHz := 220;
      if LIndex = 2 then
      begin
        LTones[LIndex].FrequencyHz := 330;
      end;
      LTones[LIndex].Velocity := 1;
      LTones[LIndex].Seed := 731;
    end;
    LOutput := RenderFrameTones(LTones, CRate);
    SaveWavePcm16(AOutput, LOutput);
    WriteLn('Authored stereo sample: one-shot at 0 s, interior sustain loop at 2 s, pitched loop at 4 s');
    WriteLn('Native frames: ', LOutput.FrameCount, '; rate: ', CRate,
      '; gate: 1.5 s; source tail: 0.3 s at root pitch');
  finally
    LOutput.Free;
    LLoop.Free;
    LOneShot.Free;
    LSource.Free;
  end;
end;

begin
  try
    if ParamCount <> 1 then
    begin
      raise EAudio.Create('Usage: pythian.sample.loop.demo OUTPUT.wav');
    end;
    Run(ParamStr(1));
  except
    on LException: Exception do
    begin
      WriteLn(StdErr, LException.ClassName, ': ', LException.Message);
      Halt(1);
    end;
  end;
end.

