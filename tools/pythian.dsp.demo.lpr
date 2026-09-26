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
program pythian_dsp_demo;

{$mode delphi}
{$H+}

uses
  SysUtils,
  Math,
  pythian.audio,
  pythian.wave,
  pythian.oscillator,
  pythian.granular;

const
  CRate = 48000;
  CSegmentFrames = 36000;

function Fade(const AFrame: Integer): Double;
begin
  Result := Max(0, Min(1, Min(AFrame / 480, (CSegmentFrames - 2400 - AFrame) / 480)));
end;

var
  LSamples: TAudioSamples;
  LSourceSamples: TAudioSamples;
  LSources: TAudioSources;
  LGrains: TAudioGrains;
  LOptions: TGrainRenderOptions;
  LClip: TAudioClip;
  LGrainClip: TAudioClip;
  LOscillator: TOscillator;
  LShape: TWaveShape;
  LQuality: TOscillatorQuality;
  LSegment: Integer;
  LFrame: Integer;
  LFrequency: Double;
  LValue: Double;
begin
  try
    if ParamCount <> 1 then
    begin
      WriteLn('Usage: pythian.dsp.demo OUTPUT.wav');
      Halt(2);
    end;
    SetLength(LSamples, CSegmentFrames * 8);
    for LSegment := 0 to 5 do
    begin
      LShape := TWaveShape(1 + LSegment div 2);
      LQuality := TOscillatorQuality(LSegment mod 2);
      LOscillator := TOscillator.Create(CRate, 731, LQuality);
      try
        for LFrame := 0 to CSegmentFrames - 1 do
        begin
          LFrequency := 400 * Power(25, LFrame / CSegmentFrames);
          LSamples[LSegment * CSegmentFrames + LFrame] :=
            0.35 * Fade(LFrame) * LOscillator.Next(LShape, LFrequency);
        end;
      finally
        LOscillator.Free;
      end;
    end;
    SetLength(LSourceSamples, CSegmentFrames * 3);
    for LFrame := 0 to High(LSourceSamples) do
    begin
      LSourceSamples[LFrame] := 0.25 * (Sin(2 * Pi * 1000 * LFrame / CRate) +
        Sin(2 * Pi * 18000 * LFrame / CRate));
    end;
    SetLength(LSources, 1);
    LSources[0] := TAudioClip.Create(CRate, 1, LSourceSamples);
    try
      SetLength(LGrains, 1);
      LGrains[0].FrameCount := CSegmentFrames;
      LGrains[0].PlaybackRate := 3;
      LGrains[0].Gain := 1;
      LOptions := DefaultGrainRenderOptions(CRate, 1);
      for LSegment := 6 to 7 do
      begin
        LOptions.Interpolation := TGrainInterpolation(LSegment - 6);
        LGrainClip := RenderGrains(LSources, LGrains, LOptions);
        try
          for LFrame := 0 to CSegmentFrames - 1 do
          begin
            LValue := LGrainClip.SampleAt(LFrame, 0);
            LSamples[LSegment * CSegmentFrames + LFrame] := Fade(LFrame) * LValue;
          end;
        finally
          LGrainClip.Free;
        end;
      end;
    finally
      LSources[0].Free;
    end;
    LClip := TAudioClip.Create(CRate, 1, LSamples);
    try
      SaveWavePcm16(ParamStr(1), LClip);
    finally
      LClip.Free;
    end;
    WriteLn('6 seconds, mono 48000 Hz; each segment is 0.75 seconds.');
    WriteLn('Triangle, saw, square: each pair is naive then polynomial, 400..10000 Hz sweep.');
    WriteLn('Final pair: 3x grain playback, linear then sinc; 18000 Hz source should be removed.');
  except
    on LException: Exception do
    begin
      WriteLn(StdErr, LException.ClassName, ': ', LException.Message);
      Halt(1);
    end;
  end;
end.

