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
program pythian_tests_passage_ownership;
{$mode delphi}{$H+}

uses SysUtils, pythian.audio, pythian.passage, pythian.granular;

var
  GChecks: Integer;

procedure Check(const AValue: Boolean; const AMessage: String);
begin
  Inc(GChecks);
  if not AValue then raise Exception.Create(AMessage);
end;

{ Big Boss: a core-only external consumer with binary-exact source samples and
  an independently declared fade oracle. No WFC or analysis fixture is needed. }
procedure Exercise;
const
  CGains: array[0..10] of Double = (0, 1, 1, 1, 1, 0.5, 0, 0, 0.5, 0.5, 0);
var
  LSources: TAudioSources;
  LSamples: TAudioSamples;
  LPassages: TRecordedPassages;
  LBefore: TRecordedPassages;
  LClip: TAudioClip;
  LReplay: TAudioClip;
  LRejectedClip: TAudioClip;
  LSource: Integer;
  LFrame: Integer;
  LIndex: Integer;
  LExpected: Single;
  LRejected: Boolean;
begin
  SetLength(LSources, 2);
  LClip := nil;
  LReplay := nil;
  try
    for LSource := 0 to 1 do
    begin
      SetLength(LSamples, 16);
      for LFrame := 0 to 15 do
        LSamples[LFrame] := (LFrame + 1) * (1 - 2 * LSource) / 32;
      LSources[LSource] := TAudioClip.Create(8000, 1, LSamples);
    end;
    SetLength(LPassages, 3);
    LPassages[0].StartFrame := 1;
    LPassages[0].FrameCount := 3;
    LPassages[1].StartFrame := 4;
    LPassages[1].FrameCount := 4;
    LPassages[2].SourceIndex := 1;
    LPassages[2].StartFrame := 8;
    LPassages[2].FrameCount := 4;
    LBefore := Copy(LPassages);
    LClip := RenderPassages(LSources, LPassages, 2);
    LReplay := RenderPassages(LSources, LPassages, 2);
    Check((LClip.FrameCount = 11) and (LReplay.FrameCount = 11), 'Exact output extent');
    for LIndex := 0 to 2 do
      Check((LPassages[LIndex].SourceIndex = LBefore[LIndex].SourceIndex) and
        (LPassages[LIndex].StartFrame = LBefore[LIndex].StartFrame) and
        (LPassages[LIndex].FrameCount = LBefore[LIndex].FrameCount), 'Caller record changed');
    for LFrame := 0 to 10 do
    begin
      LSource := 0;
      if LFrame >= 7 then LSource := 1;
      LExpected := (LFrame + 2) * (1 - 2 * LSource) / 32 * CGains[LFrame];
      Check(LClip.SampleAt(LFrame, 0) = LExpected, 'Wrong selected source, join or fade');
      Check(LReplay.SampleAt(LFrame, 0) = LExpected, 'Repeat render changed selected PCM');
    end;
    LPassages[2].FrameCount := 1000;
    LRejected := False;
    try
      LRejectedClip := RenderPassages(LSources, LPassages, 2);
      LRejectedClip.Free;
    except
      on E: EAudio do LRejected := True;
    end;
    Check(LRejected and (LPassages[2].FrameCount = 1000), 'Late invalid input changed');
    for LSource := 0 to 1 do
      for LFrame := 0 to 15 do
        Check(LSources[LSource].SampleAt(LFrame, 0) =
          (LFrame + 1) * (1 - 2 * LSource) / 32, 'Borrowed source audio changed');
  finally
    LReplay.Free;
    LClip.Free;
    for LSource := 0 to High(LSources) do LSources[LSource].Free;
  end;
end;

begin
  Exercise;
  WriteLn('Primary passage ownership: ', GChecks, ' exact source/PCM/replay checks');
end.
