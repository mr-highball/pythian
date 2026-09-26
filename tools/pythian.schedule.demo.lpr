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
program pythian_schedule_demo;

{$mode delphi}
{$H+}

uses
  SysUtils,
  Classes,
  pythian.audio,
  pythian.time,
  pythian.resample.stream,
  pythian.wave.stream,
  pythian.oscillator,
  pythian.automation,
  pythian.source,
  pythian.source.oscillator,
  pythian.synth,
  pythian.effects,
  pythian.dynamics,
  pythian.echo,
  pythian.bus,
  pythian.schedule;

const
  CSampleRate = 48000;
  CFrames = CSampleRate * 7;
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


procedure Admit(const ASynth: TScheduledSynth; const ATone: TFrameTone;
  const ABus, AGroup: Integer);
var
  LId: Int64;
begin
  if ASynth.TrySchedule(ATone, ABus, AGroup, LId) <> srScheduled then
  begin
    raise EAudio.Create('Demo exceeded declared voice capacity/work budget');
  end;
end;

procedure ScheduleMusic(const ASynth: TScheduledSynth; const AFactory: TAudioSourceFactory;
  const AStart: Int64; const AStepMicroseconds, ACount, ATranspose: Integer;
  const AReplace: Boolean = False);
var
  LTone: TFrameTone;
  LCurve: TAutomationCurve;
  LPoints: TAutomationPoints;
  LReplacements: TFrameTones;
  LFirstId: Int64;
  LIndex: Integer;
  LClock: TIncrementalTempoClock;
begin
  SetLength(LPoints, 2);
  LPoints[0].Frame := 0;
  LPoints[0].Value := 2800;
  LPoints[0].Transition := atExponential;
  LPoints[1].Frame := CSampleRate * 35 div 100;
  LPoints[1].Value := 500;
  LPoints[1].Transition := atHold;
  LCurve := TAutomationCurve.Create(LPoints);
  LClock := nil;
  try
    LClock := TIncrementalTempoClock.Create(1, CSampleRate);
    LClock.Advance(0, AStepMicroseconds);
    SetLength(LReplacements, ACount);
    for LIndex := 0 to ACount - 1 do
    begin
      LTone := Default(TFrameTone);
      LTone.Voice := DefaultSynthVoice;
      LTone.Voice.SourceFactory := AFactory;
      LTone.Voice.FilterModel := vfmBiquad;
      LTone.Voice.BiquadQ := 0.7;
      LTone.Voice.Automation.CutoffHz := LCurve;
      LTone.Voice.Gain := 0.3;
      LTone.Voice.Pan := (LIndex mod 3 - 1) * 0.6;
      LTone.Voice.Envelope.ReleaseSeconds := 0.6;
      LTone.StartFrame := AStart + LClock.Snapshot.FrameCount;
      LTone.GateFrames := CSampleRate * 35 div 100;
      LTone.FrequencyHz := MidiFrequency(CPitches[LIndex mod 8] + ATranspose);
      LTone.Velocity := 0.8;
      LTone.Seed := 731 + LIndex;
      LReplacements[LIndex] := LTone;
      if not AReplace then
      begin
        Admit(ASynth, LTone, 0, 1);
      end;
      LClock.Advance(1, AStepMicroseconds);
    end;
    if AReplace then
    begin
      if ASynth.TryReplaceFuture(1, AStart, 0, LReplacements, LFirstId) <> srScheduled then
      begin
        raise EAudio.Create('Demo replacement exceeded admission budget');
      end;
      WriteLn('Atomically replaced future music; first new voice ID=', LFirstId);
    end;
  finally
    { Admission owns independent copies; this definition is no longer needed. }
    LClock.Free;
    LCurve.Free;
  end;
end;

procedure ScheduleEffects(const ASynth: TScheduledSynth; const AFactory: TAudioSourceFactory);
const
  CStartQuarters: array[0..2] of Integer = (6, 11, 17);
var
  LTone: TFrameTone;
  LIndex: Integer;
begin
  for LIndex := 0 to 2 do
  begin
    LTone := Default(TFrameTone);
    LTone.Voice := DefaultSynthVoice;
    LTone.Voice.SourceFactory := AFactory;
    LTone.Voice.CutoffHz := 6500;
    LTone.Voice.Gain := 0.7;
    LTone.Voice.Pan := 0.6;
    LTone.Voice.Envelope.AttackSeconds := 0.002;
    LTone.Voice.Envelope.ReleaseSeconds := 0.08;
    LTone.StartFrame := CStartQuarters[LIndex] * (CSampleRate div 4);
    LTone.GateFrames := CSampleRate div 40;
    LTone.FrequencyHz := 440;
    LTone.Velocity := 0.8;
    LTone.Seed := 731 + LIndex;
    Admit(ASynth, LTone, 3, 2);
  end;
end;

type
  TScheduledDemoReader = class(TPcmFrameReader)
  private
    FSynth: TScheduledSynth;
    FFactory: TAudioSourceFactory;
  public
    constructor Create(const ASynth: TScheduledSynth; const AFactory: TAudioSourceFactory);
    function ReadFrame(out ALeft, ARight: Double): Boolean; override;
  end;

constructor TScheduledDemoReader.Create(const ASynth: TScheduledSynth;
  const AFactory: TAudioSourceFactory);
begin
  inherited Create(CSampleRate, 2);
  FSynth := ASynth;
  FFactory := AFactory;
end;

function TScheduledDemoReader.ReadFrame(out ALeft, ARight: Double): Boolean;
begin
  if FSynth.NextFrame = CFrames then
  begin
    Exit(False);
  end;
  if FSynth.NextFrame = CSampleRate * 2 then
  begin
    ScheduleMusic(FSynth, FFactory, CSampleRate * 5 div 2,
      375000, 7, 5, True);
  end;
  if FSynth.NextFrame = CSampleRate * 4 then
  begin
    WriteLn('Released/cancelled music at 4s: ', FSynth.StopGroup(1));
  end;
  FSynth.Process(ALeft, ARight);
  Result := True;
end;

procedure RenderDemo(const AFileName: String; const AOutputRate: Integer);
var
  LMusicFactory: TWaveSourceFactory;
  LEffectsFactory: TWaveSourceFactory;
  LGraph: TBusGraph;
  LSynth: TScheduledSynth;
  LStream: TFileStream;
  LSink: TStreamAudioSink;
  LWriter: TWavePcm16Writer;
  LReader: TScheduledDemoReader;
  LConverter: TSincResampleStream;
  LBlock: TAudioSamples;
  LCount: Integer;
  LLeft: Double;
  LRight: Double;
begin
  LMusicFactory := nil;
  LEffectsFactory := nil;
  LGraph := nil;
  LSynth := nil;
  LStream := nil;
  LSink := nil;
  LWriter := nil;
  LReader := nil;
  LConverter := nil;
  try
    LMusicFactory := TWaveSourceFactory.Create(wsSaw, oqPolynomial);
    LEffectsFactory := TWaveSourceFactory.Create(wsNoise, oqNaive);
    LGraph := CreateGraph;
    LSynth := TScheduledSynth.Create(LGraph, 64);
    ScheduleMusic(LSynth, LMusicFactory, 0, 500000, 12, 0);
    ScheduleEffects(LSynth, LEffectsFactory);
    LReader := TScheduledDemoReader.Create(LSynth, LMusicFactory);
    LConverter := TSincResampleStream.Create(LReader, AOutputRate);
    LStream := TFileStream.Create(AFileName, fmCreate);
    LSink := TStreamAudioSink.Create(LStream);
    LWriter := TWavePcm16Writer.Create(LSink, AOutputRate, 2, Int64(AOutputRate) * 7);
    SetLength(LBlock, CBlockFrames * 2);
    LCount := 0;
    while LConverter.ReadFrame(LLeft, LRight) do
    begin
      LBlock[LCount * 2] := LLeft;
      LBlock[LCount * 2 + 1] := LRight;
      Inc(LCount);
      if LCount = CBlockFrames then
      begin
        LWriter.AppendSamples(LBlock);
        LCount := 0;
      end;
    end;
    if LCount > 0 then
    begin
      SetLength(LBlock, LCount * 2);
      LWriter.AppendSamples(LBlock);
    end;
    LWriter.Finish;
    WriteLn('Rendered ', LWriter.FrameCount, ' frames; remaining voices=', LSynth.ScheduledCount);
    WriteLn('Synthesis rate=', CSampleRate, '; output rate=', AOutputRate,
      '; resampling lookahead=', LConverter.LookaheadFrames,
      '; history frames=', LConverter.HistoryFrames);
  finally
    LWriter.Free;
    LSink.Free;
    LStream.Free;
    LConverter.Free;
    LReader.Free;
    LSynth.Free;
    LGraph.Free;
    LEffectsFactory.Free;
    LMusicFactory.Free;
  end;
end;

var
  LOutputRate: Integer;
begin
  try
    if (ParamCount <> 1) and (ParamCount <> 2) then
    begin
      WriteLn('Usage: pythian.schedule.demo OUTPUT.wav [OUTPUT_RATE]');
      Halt(2);
    end;
    LOutputRate := CSampleRate;
    if ParamCount = 2 then
    begin
      LOutputRate := StrToInt(ParamStr(2));
    end;
    RenderDemo(ParamStr(1), LOutputRate);
    WriteLn('7 seconds, stereo, generated directly in <=1024-frame output blocks.');
    WriteLn('2.5s: future phrase changes pitch and spacing; sounding notes and echo continue.');
    WriteLn('4s: release music; independent effects burst at 4.25s; retained tails decay.');
  except
    on LException: Exception do
    begin
      WriteLn(StdErr, LException.ClassName, ': ', LException.Message);
      Halt(1);
    end;
  end;
end.
