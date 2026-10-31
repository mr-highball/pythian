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
program InstrumentalStreamConformance;
{$mode delphi}
{$H+}
uses SysUtils, Math, pythian.audio, pythian.progress, pythian.bus, pythian.echo,
  pythian.music.stream, pythian.music.pattern, pythian.pitch.track,
  pythian.wfc.instrumental.starter, pythian.wfc.instrumental.stream,
  wfc_music_ensemble, wfc_music_sequence;

type
  TObserver = class
    Abort: Boolean;
    procedure Observe(const AProgress: TWorkProgress);
  end;
var GChecks: Integer;
procedure Check(const AValue: Boolean; const AMessage: String);
begin
  Inc(GChecks);
  if not AValue then raise Exception.Create(AMessage);
end;
procedure TObserver.Observe(const AProgress: TWorkProgress);
begin
  if Abort and (AProgress.Stage = 'instrumental_stream_plan') then
    raise EAudio.Create('Caller stopped planning');
end;
function MakeGraph(const ARate: Integer = 8000): TBusGraph;
var
  LSettings: array[0..6] of TBusSettings;
  LEcho: TEchoSettings;
  I: Integer;
begin
  for I := 0 to 6 do
  begin
    LSettings[I] := DefaultBusSettings;
    LSettings[I].Gain := 0.2;
  end;
  LSettings[6].Gain := 1;
  Result := TBusGraph.Create(ARate, LSettings);
  for I := 0 to 5 do Result.AddSend(I, 6, stPostFader, 1, 0);
  LEcho := DefaultEchoSettings(ARate);
  LEcho.DelayFrames := 311;
  Result.AddEffect(6, TEchoEffect.Create(ARate, LEcho));
end;
function MakeStarter: TInstrumentalStarter;
var
  LPattern: TPitchPattern;
  I: Integer;
begin
  LPattern := nil;
  SetLength(LPattern, 8);
  for I := 0 to High(LPattern) do
  begin
    LPattern[I] := Default(TPitchPatternCell);
    LPattern[I].Kind := pskPitch;
    LPattern[I].Note := 60 + (I div 2) * 2;
    LPattern[I].Velocity := 80;
    LPattern[I].Attack := I mod 2 = 0;
  end;
  Result := TInstrumentalStarter.Create(0, False, LPattern);
end;
function Render(const APull: Integer): TAudioSamples;
var
  LStarter: TInstrumentalStarter;
  LGraph: TBusGraph;
  LStream: TInstrumentalMusicStream;
  LOptions: TInstrumentalStreamOptions;
  LFrames: TWfcMusicEnsembleFrames;
  LBlock: TAudioSamples;
  LTaps: TBusSampleBlocks;
  LBefore, LAt, LHold, I, J: Integer;
begin
  LStarter := MakeStarter;
  LGraph := MakeGraph;
  LOptions := DefaultInstrumentalStreamOptions(8000 * 36 + 19);
  LOptions.SegmentCells := 15;
  LOptions.TailFrames := 800;
  LStream := nil;
  try
    LStream := TInstrumentalMusicStream.Create(LStarter.Config, LStarter.CopyRoles,
      LStarter.CopyPercussion(8000), LGraph, LOptions, LStarter.ContextModel);
    Result := nil;
    SetLength(Result, LStream.FrameCount * 2);
    LAt := 0;
    LHold := 0;
    LBefore := 0;
    while LStream.ReadOutputs(APull, [6, 0], LBlock, LTaps) do
    begin
      for I := 0 to High(LBlock) do
      begin
        Check(not IsNan(LBlock[I]) and not IsInfinite(LBlock[I]), 'Finite instrumental PCM');
        Check((Length(LTaps) = 2) and (LBlock[I] = LTaps[0][I]),
          'WFC master and taps share one completed performance');
        Result[LAt] := LBlock[I];
        Inc(LAt);
      end;
      if LStream.PlannedSegments <> LBefore then
      begin
        LBefore := LStream.PlannedSegments;
        LFrames := LStream.CopyLastFrames;
        Check((Length(LFrames) > 0) and (Length(LFrames) <= LOptions.SegmentCells),
          'Only one bounded musical window is retained');
        if LBefore > 1 then
          for J := 0 to High(LFrames[0].Voices) do
            if LFrames[0].Voices[J].Action = wmcaHold then Inc(LHold);
      end;
    end;
    Check((LStream.State = issCompleted) and (LAt = Length(Result)) and
      (LStream.Position = LOptions.MusicFrames + LOptions.TailFrames),
      'Requested sample length plus tail survives a partial final cell');
    Check((LStream.PlannedSegments > 8) and (LStream.PlannedCells = LStream.TotalCells),
      'Multiple WFC frontiers extend beyond a finite preview');
    Check((LStream.PeakVoices > 3) and (LStream.PeakVoices <= 128),
      'Actual layered instruments/drums stay within their active voice budget');
    Check(LStream.PercussionHits > 0, 'Real synthesized drum hits join the pitched roles');
    Check(LHold > 0, 'Continued musical segments retain holds across planning boundaries');
  finally
    LStream.Free;
    LGraph.Free;
    LStarter.Free;
  end;
end;
procedure Replay;
var
  LFirst, LSecond: TAudioSamples;
  I: Integer;
  LEnergy: Double;
begin
  LFirst := Render(2048);
  LSecond := Render(173);
  LEnergy := 0;
  for I := 0 to High(LFirst) do
  begin
    Check(LFirst[I] = LSecond[I], 'All parts and FX replay exactly across PCM pull partitions');
    LEnergy := LEnergy + Abs(LFirst[I]);
  end;
  Check(LEnergy > 1, 'A sustained instrumental result actually sounds');
  LFirst := Render(511);
  Check(Length(LFirst) > 0, 'Driven musical context also streams through real instruments');
end;
procedure LongPlanAndCancel;
var
  LStarter: TInstrumentalStarter;
  LGraph: TBusGraph;
  LStream: TInstrumentalMusicStream;
  LOptions: TInstrumentalStreamOptions;
  LObserver: TObserver;
  LSamples: TAudioSamples;
  LOutputs: TBusSampleBlocks;
  LRejected: Boolean;
begin
  LStarter := MakeStarter;
  LGraph := MakeGraph;
  LOptions := DefaultInstrumentalStreamOptions(Int64(8000) * 86400);
  LObserver := TObserver.Create;
  LStream := nil;
  try
    LStream := TInstrumentalMusicStream.Create(LStarter.Config, LStarter.CopyRoles,
      LStarter.CopyPercussion(8000), LGraph, LOptions, LStarter.ContextModel);
    Check((LStream.TotalCells = 345600) and (LStream.PlannedCells = 0),
      'A24-hour musical plan has exact clocks and does not prebuild its graph history');
    LRejected := False;
    try LStream.ReadSamples(0, LSamples);
    except on EAudio do LRejected := True end;
    Check(LRejected and (LStream.State = issReady) and (LStream.PlannedCells = 0),
      'Invalid pulls cannot consume a musical frontier');
    LRejected := False;
    try LStream.ReadOutputs(1, [7], LSamples, LOutputs);
    except on EAudio do LRejected := True; end;
    Check(LRejected and (LStream.State = issReady) and (LStream.PlannedCells = 0),
      'Invalid output tap cannot plan or consume a musical frontier');
    LStream.Pause;
    Check(not LStream.ReadSamples(2048, LSamples) and (LStream.Position = 0),
      'Paused planning consumes no provider frontier');
    LStream.Resume;
    Check(LStream.ReadSamples(2048, LSamples) and (LStream.PlannedCells = 16),
      'First long-plan pull prepares only its sixteen-cell lookahead');
    LRejected := False;
    try LStream.IntersectFutureTokens(0, 0, []);
    except on Exception do LRejected := True end;
    Check(LRejected and (LStream.State = issReady), 'Past/planned musical choices are immutable');
    LStream.Stop;
    Check((LStream.State = issStopped) and not LStream.ReadSamples(2048, LSamples),
      'Stop ends future solving and instrumental output');
    FreeAndNil(LStream);
    LStream := TInstrumentalMusicStream.Create(LStarter.Config, LStarter.CopyRoles,
      LStarter.CopyPercussion(8000), LGraph, LOptions, LStarter.ContextModel);
    LObserver.Abort := True;
    LRejected := False;
    try LStream.ReadSamples(2048, LSamples, LObserver.Observe);
    except on EAudio do LRejected := True end;
    Check(LRejected and (LStream.State = issFailed) and (LSamples = nil) and
      (LStream.Position = 0), 'Planning cancellation exposes no partial audio or resumable cursor');
    FreeAndNil(LStream);
    FreeAndNil(LGraph);
    LGraph := MakeGraph(384000);
    LOptions := DefaultInstrumentalStreamOptions(Int64(384000) * 86400);
    LOptions.TicksPerQuarter := 1;
    LOptions.StepTicks := 1;
    LOptions.TempoMicroseconds := 16000000;
    LStream := TInstrumentalMusicStream.Create(LStarter.Config, LStarter.CopyRoles,
      LStarter.CopyPercussion(384000), LGraph, LOptions, LStarter.ContextModel);
    Check((LStream.TotalCells = 5400) and (LStream.FrameCount = Int64(33177600000)),
      'Requested24-hour clock does not overflow an unrelated artificial maximum map');
  finally
    LStream.Free;
    LObserver.Free;
    LGraph.Free;
    LStarter.Free;
  end;
end;
begin
  try
    Replay;
    LongPlanAndCancel;
    WriteLn('PASS ', GChecks, ' bounded WFC instrumental stream checks');
  except
    on E: Exception do
    begin
      WriteLn(E.ClassName, ': ', E.Message);
      ExitCode := 1;
    end;
  end;
end.
