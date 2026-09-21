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
program pythian_tests_context;

{$mode delphi}
{$H+}

uses
  SysUtils,
  pythian.audio,
  pythian.time,
  pythian.tonal,
  pythian.music.context;

procedure Check(const AValue: Boolean; const AMessage: String);
begin
  if not AValue then
  begin
    raise Exception.Create(AMessage);
  end;
end;

procedure CheckPitchMapping;
var
  LC: TKeyContext;
  LD: TKeyContext;
  LValue: Integer;
  LRejected: Boolean;
begin
  LC := MakeKeyContext(0, dmMajor);
  LD := MakeKeyContext(2, dmNaturalMinor);
  Check((MapDiatonicPitch(60, LC, LD) = 62) and
    (MapDiatonicPitch(64, LC, LD) = 65) and (MapDiatonicPitch(69, LC, LD) = 70) and
    (MapDiatonicPitch(65, LD, LC) = 64), 'Diatonic mapping retains degree/octave across major and minor');
  Check(MapDiatonicPitch(1, MakeKeyContext(11, dmMajor), MakeKeyContext(10, dmMajor)) = 0,
    'Source notes below the tonic use the preceding octave');
  LValue := 64;
  LRejected := False;
  try
    LValue := MapDiatonicPitch(61, LC, LD);
  except
    on EAudio do
    begin
      LRejected := True;
    end;
  end;
  Check(LRejected and (LValue = 64), 'Chromatic source pitches reject without changing accepted result');
  LRejected := False;
  try
    MapDiatonicPitch(60, LC, MakeKeyContext(-1, dmMajor));
  except
    on EAudio do
    begin
      LRejected := True;
    end;
  end;
  Check(LRejected, 'Unknown key is never an implicit C major');
  LRejected := False;
  try
    MapDiatonicPitch(127, LC, MakeKeyContext(11, dmMajor));
  except
    on EAudio do
    begin
      LRejected := True;
    end;
  end;
  Check(LRejected, 'Mapping rejects pitches outside MIDI range');
  WriteLn('Explicit diatonic mapping, octave boundaries and unknown/chromatic rejection pass');
end;

procedure Run;
var
  LClock: TTempoMap;
  LContext: TMusicContext;
  LKeys: TKeyChanges;
  LCopy: TKeyChanges;
  LGrid: TMusicContextGrid;
  LRejected: Boolean;
begin
  LClock := TTempoMap.Create(480, 1920, [MakeTempoChange(0, 500001),
    MakeTempoChange(720, 600001), MakeTempoChange(1440, 400001)]);
  LContext := nil;
  try
    SetLength(LKeys, 3);
    LKeys[0].Key := MakeKeyContext(-1, dmMajor);
    LKeys[1].Tick := 480;
    LKeys[1].Key := MakeKeyContext(0, dmMajor);
    LKeys[2].Tick := 1440;
    LKeys[2].Key := MakeKeyContext(2, dmNaturalMinor);
    LContext := TMusicContext.Create(LClock, LKeys);
    FreeAndNil(LClock);
    LKeys[1].Key.Root := 11;
    LCopy := LContext.CopyKeys;
    LCopy[2].Key.Root := 11;
    Check((LContext.KeyAtTick(479).Root = -1) and
      (LContext.KeyAtTick(480).Root = 0) and (LContext.KeyAtTick(1920).Root = 2),
      'Detached key changes, unknown context and exact endpoints');
    LGrid := LContext.Grid(480, 240, 4);
    Check((LGrid.StartTick = 480) and (LGrid.Keys[0].Root = 0) and
      (LGrid.Tempos[0] = 500001) and (LGrid.Tempos[1] = 600001) and
      (LGrid.Keys[3].Root = 0), 'Scoped broadcast retains offset and excludes right boundary');
    ValidateContextGrid(LGrid);
    LGrid.Keys[0].Root := 8;
    Check(LContext.KeyAtTick(480).Root = 0, 'Grid storage is detached');
    LClock := LContext.CopyClock;
    { 1.5 quarters at 500001 us + 1.5 at 600001 + 1 at 400001:
      floor(2050004 us * 44100 / 1000000) = 90405 frames. }
    Check(LClock.FrameAtTick(1920, 44100) = 90405, 'Exact fractional tempo clock survives ownership');
    LRejected := False;
    try
      LGrid := LContext.Grid(480, 480, 2);
    except
      on EAudio do
      begin
        LRejected := True;
      end;
    end;
    Check(LRejected and (LGrid.StepTicks = 240) and (LGrid.Keys[0].Root = 8),
      'Interior tempo change rejects without replacing previous grid');
    LRejected := False;
    try
      LGrid := LContext.Grid(0, 720, 2);
    except
      on EAudio do
      begin
        LRejected := True;
      end;
    end;
    Check(LRejected, 'Interior key change rejects');
    LRejected := False;
    try
      LGrid := LContext.Grid(1, High(Integer), 2);
    except
      on EAudio do
      begin
        LRejected := True;
      end;
    end;
    Check(LRejected, 'Overflowing extent rejects before arithmetic/allocation');
    WriteLn('Typed key context, scoped grids, ownership, exact clock and boundary rejection passed');
  finally
    LContext.Free;
    LClock.Free;
  end;
end;

begin
  try
    CheckPitchMapping;
    Run;
  except
    on LException: Exception do
    begin
      WriteLn(StdErr, LException.ClassName, ': ', LException.Message);
      Halt(1);
    end;
  end;
end.

