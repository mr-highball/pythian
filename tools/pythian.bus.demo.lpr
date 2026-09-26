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
program pythian_bus_demo;

{$mode delphi}
{$H+}

uses
  SysUtils,
  Classes,
  pythian.audio,
  pythian.wave.stream,
  pythian.oscillator,
  pythian.synth,
  pythian.effects,
  pythian.dynamics,
  pythian.echo,
  pythian.bus;

const
  CSampleRate = 48000;
  CFrames = CSampleRate * 6;
  CBlockFrames = 1024;
  CPitches: array[0..7] of Integer = (60, 64, 67, 71, 69, 67, 64, 62);

procedure AddOwnedEffect(const AGraph: TBusGraph; const ABus: Integer;
  const AEffect: TAudioEffect);
var
  LEffect: TAudioEffect;
begin
  LEffect := AEffect;
  try
    AGraph.AddEffect(ABus, LEffect);
    LEffect := nil;
  finally
    LEffect.Free;
  end;
end;

function CreateGraph: TBusGraph;
var
  LSettings: array[0..4] of TBusSettings;
  LEcho: TEchoSettings;
  LIndex: Integer;
begin
  for LIndex := 0 to High(LSettings) do
  begin
    LSettings[LIndex] := DefaultBusSettings;
    LSettings[LIndex].SmoothingSeconds := 0;
  end;
  LSettings[2].Gain := 0.7;
  LSettings[2].SmoothingSeconds := 0.035;
  LSettings[3].Gain := 0.4;
  LSettings[3].SmoothingSeconds := 0.015;
  Result := TBusGraph.Create(CSampleRate, LSettings);
  try
    { 0 music input, 1 echo return, 2 music output, 3 effects, 4 master. }
    LEcho := DefaultEchoSettings(CSampleRate);
    LEcho.DryGain := 0;
    AddOwnedEffect(Result, 1, TEchoEffect.Create(CSampleRate, LEcho));
    AddOwnedEffect(Result, 4, TCompressorEffect.Create(CSampleRate,
      DefaultCompressorSettings));
    AddOwnedEffect(Result, 4, TLimiterEffect.Create(CSampleRate, -1, 0.05));
    Result.AddSend(0, 1, stPostFader, 1, 0);
    Result.AddSend(0, 2, stPostFader, 1, 0);
    Result.AddSend(1, 2, stPostFader, 1, 0);
    Result.AddSend(2, 4, stPostFader, 1, 0);
    Result.AddSend(3, 4, stPostFader, 1, 0);
  except
    Result.Free;
    raise;
  end;
end;

function MusicClip: TAudioClip;
var
  LTones: TFrameTones;
  LIndex: Integer;
begin
  SetLength(LTones, 8);
  for LIndex := 0 to High(LTones) do
  begin
    LTones[LIndex].Voice := DefaultSynthVoice;
    LTones[LIndex].Voice.Shape := wsSaw;
    LTones[LIndex].Voice.OscillatorQuality := oqPolynomial;
    LTones[LIndex].Voice.Gain := 0.5;
    LTones[LIndex].Voice.CutoffHz := 2800;
    LTones[LIndex].Voice.Pan := (LIndex mod 3 - 1) * 0.7;
    LTones[LIndex].Voice.Envelope.ReleaseSeconds := 0.08;
    LTones[LIndex].StartFrame := LIndex * (CSampleRate div 2);
    LTones[LIndex].GateFrames := CSampleRate div 5;
    LTones[LIndex].FrequencyHz := MidiFrequency(CPitches[LIndex]);
    LTones[LIndex].Velocity := 0.8;
    LTones[LIndex].Seed := 731;
  end;
  Result := RenderFrameTones(LTones, CSampleRate);
end;

function EffectsClip: TAudioClip;
var
  LTones: TFrameTones;
  LIndex: Integer;
begin
  SetLength(LTones, 3);
  for LIndex := 0 to High(LTones) do
  begin
    LTones[LIndex].Voice := DefaultSynthVoice;
    LTones[LIndex].Voice.Shape := wsNoise;
    LTones[LIndex].Voice.Gain := 0.8;
    LTones[LIndex].Voice.CutoffHz := 7000;
    LTones[LIndex].Voice.Pan := 0.6;
    LTones[LIndex].Voice.Envelope.AttackSeconds := 0.002;
    LTones[LIndex].Voice.Envelope.ReleaseSeconds := 0.06;
    LTones[LIndex].StartFrame := (3 + LIndex * 2) * (CSampleRate div 2);
    LTones[LIndex].GateFrames := CSampleRate div 40;
    LTones[LIndex].FrequencyHz := 440;
    LTones[LIndex].Velocity := 0.8;
    LTones[LIndex].Seed := 731 + LIndex;
  end;
  Result := RenderFrameTones(LTones, CSampleRate);
end;

procedure RenderDemo(const AFileName: String);
var
  LMusic: TAudioClip;
  LEffects: TAudioClip;
  LGraph: TBusGraph;
  LStream: TFileStream;
  LSink: TStreamAudioSink;
  LWriter: TWavePcm16Writer;
  LInputs: array[0..4] of TStereoFrame;
  LBlock: TAudioSamples;
  LFrame: Integer;
  LOffset: Integer;
  LCount: Integer;
  LBus: Integer;
  LLeft: Double;
  LRight: Double;
begin
  LMusic := nil;
  LEffects := nil;
  LGraph := nil;
  LStream := nil;
  LSink := nil;
  LWriter := nil;
  try
    LMusic := MusicClip;
    LEffects := EffectsClip;
    LGraph := CreateGraph;
    LStream := TFileStream.Create(AFileName, fmCreate);
    LSink := TStreamAudioSink.Create(LStream);
    LWriter := TWavePcm16Writer.Create(LSink, CSampleRate, 2, CFrames);
    LFrame := 0;
    while LFrame < CFrames do
    begin
      LCount := CBlockFrames;
      if LCount > CFrames - LFrame then
      begin
        LCount := CFrames - LFrame;
      end;
      SetLength(LBlock, LCount * 2);
      for LOffset := 0 to LCount - 1 do
      begin
        if LFrame = CSampleRate * 2 then
        begin
          LGraph.SetBusGain(2, 0);
        end;
        if LFrame = CSampleRate * 3 then
        begin
          LGraph.SetBusGain(2, 0.7);
        end;
        for LBus := 0 to High(LInputs) do
        begin
          LInputs[LBus].Left := 0;
          LInputs[LBus].Right := 0;
        end;
        if LFrame < LMusic.FrameCount then
        begin
          LInputs[0].Left := LMusic.SampleAt(LFrame, 0);
          LInputs[0].Right := LMusic.SampleAt(LFrame, 1);
        end;
        if LFrame < LEffects.FrameCount then
        begin
          LInputs[3].Left := LEffects.SampleAt(LFrame, 0);
          LInputs[3].Right := LEffects.SampleAt(LFrame, 1);
        end;
        LGraph.Process(LInputs, LLeft, LRight);
        LBlock[LOffset * 2] := LLeft;
        LBlock[LOffset * 2 + 1] := LRight;
        Inc(LFrame);
      end;
      LWriter.AppendSamples(LBlock);
    end;
    LWriter.Finish;
    WriteLn('Rendered ', LWriter.FrameCount, ' stereo frames at ', CSampleRate, ' Hz.');
  finally
    LWriter.Free;
    LSink.Free;
    LStream.Free;
    LGraph.Free;
    LEffects.Free;
    LMusic.Free;
  end;
end;

begin
  try
    if ParamCount <> 1 then
    begin
      WriteLn('Usage: pythian.bus.demo OUTPUT.wav');
      Halt(2);
    end;
    RenderDemo(ParamStr(1));
    WriteLn('0-2s: music with filtered echo; 2-3s: music fades out, effects remain.');
    WriteLn('3-4s: music and retained echo return; 4-6s: echo decay.');
    WriteLn('Five buses feed linked master compression and a sample limiter.');
  except
    on LException: Exception do
    begin
      WriteLn(StdErr, LException.ClassName, ': ', LException.Message);
      Halt(1);
    end;
  end;
end.

