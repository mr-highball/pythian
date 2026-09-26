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
program pythian_example_core;

{$mode delphi}
{$H+}

uses
  SysUtils,
  pythian.audio,
  pythian.wave,
  pythian.synth,
  pythian.hash;

var
  LTones: TFrameTones;
  LClip: TAudioClip;
  LDecoded: TAudioClip;
  LBytes: TAudioBytes;
  LIndex: Integer;
begin
  try
    if ParamCount <> 1 then
    begin
      raise EAudio.Create('Usage: pythian.example.core OUTPUT.wav');
    end;
    SetLength(LTones, 3);
    for LIndex := 0 to High(LTones) do
    begin
      LTones[LIndex].StartFrame := LIndex * 22050;
      LTones[LIndex].GateFrames := 17640;
      LTones[LIndex].FrequencyHz := 220 * (1 + LIndex * 0.25);
      LTones[LIndex].Velocity := 0.6;
      LTones[LIndex].Seed := LIndex + 1;
      LTones[LIndex].Voice := DefaultSynthVoice;
      LTones[LIndex].Voice.Pan := -0.5 + LIndex * 0.5;
    end;
    LClip := RenderFrameTones(LTones, 44100, 66150);
    try
      LBytes := EncodeWavePcm16(LClip);
      LDecoded := DecodeWave(LBytes);
      try
        if (LDecoded.FrameCount <> LClip.FrameCount) or (LDecoded.Channels <> 2) then
        begin
          raise EAudio.Create('WAV round trip changed format');
        end;
      finally
        LDecoded.Free;
      end;
      SaveWavePcm16(ParamStr(1), LClip);
      WriteLn('Core consumer rendered ', LClip.FrameCount, ' stereo frames; SHA256 ', Sha256Bytes(LBytes));
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

