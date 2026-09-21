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
program pythian_render;

{$mode delphi}
{$H+}

uses
  SysUtils,
  pythian.audio,
  pythian.wave,
  pythian.oscillator,
  pythian.synth;

const
  CPitches: array[0..7] of Integer = (60, 64, 67, 71, 69, 67, 64, 62);

var
  LTones: TTones;
  LClip: TAudioClip;
  LIndex: Integer;
begin
  try
    if ParamCount <> 1 then
    begin
      WriteLn('Usage: pythian.render OUTPUT.wav');
      Halt(2);
    end;
    SetLength(LTones, 32);
    for LIndex := 0 to High(LTones) do
    begin
      LTones[LIndex].Voice := DefaultSynthVoice;
      LTones[LIndex].Voice.Shape := TWaveShape((LIndex div 8) mod 4);
      LTones[LIndex].Voice.Pan := (LIndex mod 3 - 1) * 0.6;
      LTones[LIndex].Voice.Gain := 0.28;
      LTones[LIndex].StartSeconds := LIndex * 0.25;
      LTones[LIndex].GateSeconds := 0.2;
      LTones[LIndex].FrequencyHz := MidiFrequency(CPitches[LIndex mod 8]);
      LTones[LIndex].Velocity := 0.8;
      LTones[LIndex].Seed := 731 + LIndex;
    end;
    LClip := RenderTones(LTones, 44100);
    try
      SaveWavePcm16(ParamStr(1), LClip);
      WriteLn('Rendered ', LClip.FrameCount, ' stereo frames at ', LClip.SampleRate, ' Hz');
    finally
      LClip.Free;
    end;
  except
    on LException: Exception do
    begin
      WriteLn(StdErr, LException.ClassName, ': ', LException.Message);
      Halt(1);
    end;
  end;
end.
