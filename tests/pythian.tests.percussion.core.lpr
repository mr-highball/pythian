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
program pythian_tests_percussion_core;

{$mode delphi}
{$H+}

uses
  SysUtils,
  Math,
  pythian.audio,
  pythian.synth,
  pythian.percussion;

var
  Checks: Integer;

procedure Check(const AValue: Boolean; const AMessage: String);
begin
  Inc(Checks);
  if not AValue then
  begin
    raise EAudio.Create(AMessage);
  end;
end;

procedure RunKind(const AKind: TPercussionKind);
const
  CRate = 8000;
  CFrames = 3200;
var
  LSettings: TPercussionSettings;
  LFull: TPercussionInstrument;
  LHalf: TPercussionInstrument;
  LOne: TFrameTones;
  LTwo: TFrameTones;
  LJoined: TFrameTones;
  LFirst: TAudioClip;
  LSecond: TAudioClip;
  LMix: TAudioClip;
  LQuiet: TAudioClip;
  LIndex: Integer;
  LChannel: Integer;
  LCount: Integer;
  LEnergy: Double;
begin
  LSettings := DefaultPercussionSettings(AKind, CRate);
  LFull := TPercussionInstrument.Create(CRate, LSettings);
  LHalf := nil;
  LFirst := nil;
  LSecond := nil;
  LMix := nil;
  LQuiet := nil;
  try
    LOne := LFull.PlanHit(0, 100, 42);
    Check((Length(LOne) = 1 + Ord(AKind = pkSnare)), 'Actual layered drum recipe');
    for LIndex := 0 to High(LOne) do
    begin
      Check(LOne[LIndex].Voice.SourceFactory = nil, 'Source-free core drum');
      Check(LOne[LIndex].GateFrames > 0, 'Explicit drum gate');
    end;
    LFirst := RenderFrameTones(LOne, CRate, CFrames);
    LSettings.Gain := LSettings.Gain * 0.5;
    LHalf := TPercussionInstrument.Create(CRate, LSettings);
    LQuiet := RenderFrameTones(LHalf.PlanHit(0, 100, 42), CRate, CFrames);
    LTwo := LFull.PlanHit(600, 87, 43);
    LSecond := RenderFrameTones(LTwo, CRate, CFrames);
    LJoined := Copy(LOne);
    LCount := Length(LJoined);
    SetLength(LJoined, LCount + Length(LTwo));
    for LIndex := 0 to High(LTwo) do
    begin
      LJoined[LCount + LIndex] := LTwo[LIndex];
    end;
    LMix := RenderFrameTones(LJoined, CRate, CFrames);
    LEnergy := 0;
    for LIndex := 0 to CFrames - 1 do
    begin
      for LChannel := 0 to 1 do
      begin
        LEnergy := LEnergy + Sqr(LFirst.SampleAt(LIndex, LChannel));
        Check(Abs(LQuiet.SampleAt(LIndex, LChannel) -
          LFirst.SampleAt(LIndex, LChannel) * 0.5) < 3E-8, 'Audible gain control');
        Check(Abs(LMix.SampleAt(LIndex, LChannel) -
          LFirst.SampleAt(LIndex, LChannel) - LSecond.SampleAt(LIndex, LChannel)) < 1E-7,
          'Primary layered overlap is additive');
      end;
    end;
    Check(LEnergy > 0.01, 'Audible isolated percussion');
    Check((LFirst.SampleAt(CFrames - 1, 0) = 0) and
      (LFirst.SampleAt(CFrames - 1, 1) = 0), 'Release finishes cleanly');
  finally
    LFirst.Free;
    LSecond.Free;
    LMix.Free;
    LQuiet.Free;
    LFull.Free;
    LHalf.Free;
  end;
end;

procedure Reject;
var
  LSettings: TPercussionSettings;
  LKit: TPercussionInstrument;
  LRejected: Boolean;
begin
  LSettings := DefaultPercussionSettings(pkKick, 8000);
  LSettings.ToneHz := 9000;
  LKit := nil;
  LRejected := False;
  try
    try
      LKit := TPercussionInstrument.Create(8000, LSettings);
    except
      on EAudio do
      begin
        LRejected := True;
      end;
    end;
    Check(LRejected, 'Unsupported physical frequency rejects explicitly');
    LRejected := False;
    try
      LSettings := DefaultPercussionSettings(pkKick, 1000);
    except
      on EAudio do
      begin
        LRejected := True;
      end;
    end;
    Check(LRejected, 'Unsupported recipe sample rate rejects explicitly');
  finally
    LKit.Free;
  end;
end;

begin
  RunKind(pkKick);
  RunKind(pkSnare);
  RunKind(pkClosedHat);
  Reject;
  WriteLn('Core percussion: ', Checks, ' checks; source-free kick/snare/hat, gain, overlap and releases');
end.
