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

function ReadSeed(const AText: String): Cardinal;
var
  LValue: QWord;
  LIndex: Integer;
begin
  if (Length(AText) < 1) or (Length(AText) > 10) then
    raise EAudio.Create('Seed must be unsigned decimal');
  for LIndex := 1 to Length(AText) do
    if not (AText[LIndex] in ['0'..'9']) then
      raise EAudio.Create('Seed must be unsigned decimal');
  if not TryStrToQWord(AText, LValue) or (LValue > QWord(High(Cardinal)) - 2) then
    raise EAudio.Create('Seed exceeds three-voice bounds');
  Result := Cardinal(LValue);
end;

var
  LTones: TFrameTones;
  LClip: TAudioClip;
  LDecoded: TAudioClip;
  LBytes: TAudioBytes;
  LIndex: Integer;
  LGain: Double;
  LSeed: Cardinal;
  LPath: String;
  LFormat: TFormatSettings;
begin
  try
    if (ParamCount < 1) or (ParamCount > 3) then
    begin
      raise EAudio.Create('Usage: pythian.example.core FRESH_OUTPUT.wav [GAIN_0_TO_1 [SEED]]');
    end;
    LGain := 1; LSeed := 731;
    LFormat := DefaultFormatSettings; LFormat.DecimalSeparator := '.';
    LFormat.ThousandSeparator := #0;
    if (ParamCount >= 2) and not TryStrToFloat(ParamStr(2), LGain, LFormat) then
      raise EAudio.Create('Gain must be a finite decimal number');
    RequireFinite(LGain, 'Example gain');
    if (LGain < 0) or (LGain > 1) then raise EAudio.Create('Gain must be in [0,1]');
    if ParamCount = 3 then LSeed := ReadSeed(ParamStr(3));
    if (Trim(ParamStr(1)) = '') or not SameText(ExtractFileExt(ParamStr(1)), '.wav') then
      raise EAudio.Create('Example publication requires a nonempty .wav path');
    LPath := ExpandFileName(ParamStr(1));
    if FileExists(LPath) or DirectoryExists(LPath) or
      not DirectoryExists(ExtractFilePath(LPath)) then
      raise EAudio.Create('Example publication requires an existing parent and fresh WAV path');
    SetLength(LTones, 3);
    for LIndex := 0 to High(LTones) do
    begin
      LTones[LIndex].StartFrame := LIndex * 22050;
      LTones[LIndex].GateFrames := 17640;
      LTones[LIndex].FrequencyHz := 220 * (1 + LIndex * 0.25);
      LTones[LIndex].Velocity := 0.6;
      LTones[LIndex].Seed := Cardinal(LSeed) + Cardinal(LIndex);
      LTones[LIndex].Voice := DefaultSynthVoice;
      LTones[LIndex].Voice.Gain := LTones[LIndex].Voice.Gain * LGain;
      LTones[LIndex].Voice.Pan := -0.5 + LIndex * 0.5;
    end;
    LClip := RenderFrameTones(LTones, 44100, 66150);
    try
      LBytes := EncodeWavePcm16(LClip);
      SaveWavePcm16(LPath, LClip);
      LDecoded := LoadWave(LPath);
      try
        if (LDecoded.FrameCount <> LClip.FrameCount) or (LDecoded.Channels <> 2) or
          (LDecoded.SampleRate <> 44100) or
          (Sha256Bytes(EncodeWavePcm16(LDecoded)) <> Sha256Bytes(LBytes)) then
        begin
          raise EAudio.Create('Saved WAV reload changed declared geometry or PCM bytes');
        end;
      finally
        LDecoded.Free;
      end;
      WriteLn('Core consumer rendered and reloaded ', LClip.FrameCount,
        ' stereo frames at 44100 Hz; gain ', LGain, '; seed ', LSeed,
        '; SHA256 ', Sha256Bytes(LBytes));
    finally
      LClip.Free;
    end;
  except
    on LException: Exception do
    begin
      WriteLn(StdErr, LException.ClassName, ': ', LException.Message);
      ExitCode := 1;
    end;
  end;
end.
