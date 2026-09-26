(*
MIT License

Copyright (c) 2021 mr-highball
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
program pythian_chord_demo;

{$mode delphi}
{$H+}

uses
  Classes,
  SysUtils,
  pythian.audio,
  pythian.time,
  pythian.chord.stream,
  pythian.wave.stream;

procedure Run;
const
  CRate = 44100;
  CRoots: array[0..3] of Integer = (60, 65, 67, 60);
var
  LRenderer: TChordStreamRenderer;
  LClock: TIncrementalTempoClock;
  LFile: TFileStream;
  LSink: TStreamAudioSink;
  LWriter: TWavePcm16Writer;
  LOptions: TChordStreamOptions;
  LCapacities: TChordCapacities;
  LFrame: TChordFrame;
  LSamples: TAudioSamples;
  LIndex: Integer;
  LRoot: Integer;
  LInterval: Int64;
begin
  if ParamCount <> 1 then
  begin
    raise EAudio.Create('Usage: pythian.chord.demo OUTPUT.wav');
  end;
  LRenderer := nil;
  LClock := nil;
  LFile := nil;
  LSink := nil;
  LWriter := nil;
  try
    LOptions := DefaultChordStreamOptions(CRate);
    SetLength(LCapacities, 2);
    LCapacities[0] := 3;
    LCapacities[1] := 1;
    LRenderer := TChordStreamRenderer.Create(LOptions, LCapacities);
    LClock := TIncrementalTempoClock.Create(480, CRate);
    LFile := TFileStream.Create(ParamStr(1), fmCreate);
    LSink := TStreamAudioSink.Create(LFile);
    LWriter := TWavePcm16Writer.Create(LSink, CRate, 1, Int64(CRate) * 8);
    SetLength(LFrame, 2);
    SetLength(LFrame[0].Tones, 3);
    SetLength(LFrame[1].Tones, 1);
    for LIndex := 0 to 31 do
    begin
      LRoot := CRoots[LIndex div 8];
      LFrame[0].Action := caHold;
      if LIndex mod 8 = 0 then
      begin
        LFrame[0].Action := caAttack;
        LFrame[0].Tones[0].Pitch := LRoot;
        LFrame[0].Tones[0].Velocity := 90;
        LFrame[0].Tones[1].Pitch := LRoot + 4;
        LFrame[0].Tones[1].Velocity := 75;
        LFrame[0].Tones[2].Pitch := LRoot + 7;
        LFrame[0].Tones[2].Velocity := 80;
      end;
      LFrame[1].Action := caHold;
      if LIndex mod 4 = 0 then
      begin
        LFrame[1].Action := caAttack;
        LFrame[1].Tones[0].Pitch := LRoot - 24;
        if LIndex mod 8 = 4 then
        begin
          Inc(LFrame[1].Tones[0].Pitch, 7);
        end;
        LFrame[1].Tones[0].Velocity := 105;
      end;
      LInterval := LClock.Advance(240, 500000);
      LRenderer.AdmitFrame(LFrame, LInterval);
      while LRenderer.ReadSamples(1021, LSamples) do
      begin
        LWriter.AppendSamples(LSamples);
      end;
    end;
    LRenderer.EndInput;
    while LRenderer.ReadSamples(1021, LSamples) do
    begin
      LWriter.AppendSamples(LSamples);
    end;
    LWriter.Finish;
    if not LRenderer.Finished then
    begin
      raise EAudio.Create('Chord output did not finish');
    end;
    WriteLn('Streamed ', LRenderer.EmittedFrames, ' mono frames at ', CRate,
      ' Hz; delayed release ', LRenderer.LatencyFrames, ' frames; no appended tail');
  finally
    LWriter.Free;
    LSink.Free;
    LFile.Free;
    LClock.Free;
    LRenderer.Free;
  end;
end;

begin
  try
    Run;
  except
    on LException: Exception do
    begin
      WriteLn(StdErr, LException.ClassName, ': ', LException.Message);
      Halt(1);
    end;
  end;
end.

