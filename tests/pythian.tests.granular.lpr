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
program pythian_tests_granular;

{$mode delphi}
{$H+}

uses
  SysUtils,
  Math,
  pythian.audio,
  pythian.granular,
  pythian.reconstruction;

procedure Check(const ACondition: Boolean; const AMessage: String);
begin
  if not ACondition then
  begin
    raise Exception.Create(AMessage);
  end;
end;

procedure CheckGrains;
var
  LSamples: TAudioSamples;
  LSources: TAudioSources;
  LGrains: TAudioGrains;
  LOptions: TGrainRenderOptions;
  LClip: TAudioClip;
  LIndex: Integer;
  LRejected: Boolean;
begin
  SetLength(LSamples, 256);
  for LIndex := 0 to 127 do
  begin
    LSamples[2 * LIndex] := LIndex / 128;
    LSamples[2 * LIndex + 1] := -LIndex / 128;
  end;
  SetLength(LSources, 1);
  LSources[0] := TAudioClip.Create(8000, 2, LSamples);
  try
    SetLength(LGrains, 1);
    LGrains[0].SourceIndex := 0;
    LGrains[0].SourceStartFrame := 2;
    LGrains[0].OutputStartFrame := 3;
    LGrains[0].FrameCount := 9;
    LGrains[0].PlaybackRate := 0.5;
    LGrains[0].Gain := 0.5;
    LGrains[0].Window := gwRectangular;
    LOptions := DefaultGrainRenderOptions(8000, 2);
    LClip := RenderGrains(LSources, LGrains, LOptions);
    try
      Check(LClip.FrameCount = 12, 'Exact grain output length');
      for LIndex := 0 to 2 do
      begin
        Check(LClip.SampleAt(LIndex, 0) = 0, 'Grain leading silence');
      end;
      for LIndex := 0 to 8 do
      begin
        Check(LClip.SampleAt(3 + LIndex, 0) = (2 + 0.5 * LIndex) / 256,
          'Independent ramp interpolation and gain');
        Check(LClip.SampleAt(3 + LIndex, 1) = -LClip.SampleAt(3 + LIndex, 0),
          'Stereo channel polarity preserved');
      end;
    finally
      LClip.Free;
    end;
    LGrains[0].SourceStartFrame := 127;
    LRejected := False;
    try
      LClip := RenderGrains(LSources, LGrains, LOptions);
      LClip.Free;
    except
      on EAudio do
      begin
        LRejected := True;
      end;
    end;
    Check(LRejected, 'Grain source overrun must reject');
    Check(LSources[0].SampleAt(127, 0) = 127 / 128, 'Source preserved after failed render');
  finally
    LSources[0].Free;
  end;

  for LIndex := 0 to High(LSamples) do
  begin
    LSamples[LIndex] := 0.5;
  end;
  LSources[0] := TAudioClip.Create(8000, 2, LSamples);
  try
    SetLength(LGrains, 2);
    LGrains[0] := Default(TAudioGrain);
    LGrains[0].FrameCount := 128;
    LGrains[0].PlaybackRate := 1;
    LGrains[0].Gain := 1;
    LGrains[0].Window := gwHann;
    LGrains[1] := LGrains[0];
    LGrains[1].OutputStartFrame := 64;
    LClip := RenderGrains(LSources, LGrains, LOptions);
    try
      Check(LClip.FrameCount = 192, 'Overlap extent');
      Check((LClip.SampleAt(0, 0) > 0) and (LClip.SampleAt(0, 0) < 0.001),
        'Window fade survives overlap normalization');
      for LIndex := 64 to 127 do
      begin
        Check(Abs(LClip.SampleAt(LIndex, 0) - 0.5) < 1E-7,
          'Half-hop Hann overlap has unity gain');
      end;
      Check(LClip.SampleAt(191, 0) < 0.001, 'Tail fade retained');
    finally
      LClip.Free;
    end;
    LGrains[1].OutputStartFrame := 0;
    LGrains[0].Window := gwRectangular;
    LGrains[1].Window := gwRectangular;
    LClip := RenderGrains(LSources, LGrains, LOptions);
    try
      Check(LClip.SampleAt(20, 0) = 0.5, 'Identical overlap normalized');
    finally
      LClip.Free;
    end;
    LOptions.NormalizeOverlap := False;
    LClip := RenderGrains(LSources, LGrains, LOptions);
    try
      Check(LClip.SampleAt(20, 0) = 1, 'Unnormalized overlap adds explicitly');
    finally
      LClip.Free;
    end;
  finally
    LSources[0].Free;
  end;
  WriteLn('PASS granular interpolation, stereo, bounds, overlap gain and window fades');
end;

begin
  try
    CheckGrains;
  except
    on LException: Exception do
    begin
      WriteLn(StdErr, LException.ClassName, ': ', LException.Message);
      Halt(1);
    end;
  end;
end.
