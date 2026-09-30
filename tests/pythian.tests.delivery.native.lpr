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
program pythian_tests_delivery_native;

{$mode delphi}
{$H+}

uses Classes, SysUtils, Math, pythian.audio, pythian.wave, pythian.hash;

procedure Require(const ACondition: Boolean; const AMessage: String);
begin
  if not ACondition then raise EAudio.Create(AMessage);
end;

function FileHash(const APath: String): String;
var S: TFileStream;
begin
  S := TFileStream.Create(APath, fmOpenRead or fmShareDenyWrite);
  try
    Require(S.Size <= MaximumWaveBytes, 'Delivery WAV exceeds encoded byte bound');
    Result := Sha256Stream(S, S.Size);
  finally S.Free; end;
end;

var
  Base, Changed, Replay: TAudioClip;
  BaseSamples, ChangedSamples: TAudioSamples;
  LRate, LChannels, LFrames, I: Integer;
  LRatio, LTolerance, LError, LMaximumError, LBasePeak, LChangedPeak: Double;
  LFormat: TFormatSettings;
begin
  Base := nil; Changed := nil; Replay := nil;
  try
    try
      Require(ParamCount = 7, 'Usage: BASE.wav CHANGED.wav REPLAY.wav RATE CHANNELS FRAMES EXPECTED_GAIN_RATIO');
      Require(TryStrToInt(ParamStr(4), LRate) and TryStrToInt(ParamStr(5), LChannels) and
        TryStrToInt(ParamStr(6), LFrames), 'Delivery geometry requires integers');
      Require((LFrames > 0) and (LFrames <= 1000000), 'Delivery fixture frame bound');
      ValidateAudioFormat(LRate, LChannels);
      LFormat := DefaultFormatSettings; LFormat.DecimalSeparator := '.';
      Require(TryStrToFloat(ParamStr(7), LRatio, LFormat), 'Expected ratio requires decimal');
      RequireFinite(LRatio, 'Expected gain ratio');
      Require((LRatio > 0) and (LRatio <= 16) and (LRatio <> 1), 'Expected changed gain ratio bound');
      Require(FileHash(ParamStr(1)) = FileHash(ParamStr(3)), 'Fixed-input/seed saved-file replay differs');
      Require(FileHash(ParamStr(1)) <> FileHash(ParamStr(2)), 'Changed control did not change saved PCM bytes');
      Base := LoadWave(ParamStr(1)); Changed := LoadWave(ParamStr(2)); Replay := LoadWave(ParamStr(3));
      Require((Base.SampleRate = LRate) and (Base.Channels = LChannels) and (Base.FrameCount = LFrames),
        'Base saved-file geometry differs');
      Require((Changed.SampleRate = LRate) and (Changed.Channels = LChannels) and (Changed.FrameCount = LFrames),
        'Changed-control saved-file geometry differs');
      Require((Replay.SampleRate = LRate) and (Replay.Channels = LChannels) and (Replay.FrameCount = LFrames),
        'Replayed saved-file geometry differs');
      BaseSamples := Base.CopySamples; ChangedSamples := Changed.CopySamples;
      LTolerance := (1 + LRatio) / 32768;
      LMaximumError := 0; LBasePeak := 0; LChangedPeak := 0;
      for I := 0 to High(BaseSamples) do
      begin
        LError := Abs(ChangedSamples[I] - BaseSamples[I] * LRatio);
        LMaximumError := Max(LMaximumError, LError);
        LBasePeak := Max(LBasePeak, Abs(BaseSamples[I]));
        LChangedPeak := Max(LChangedPeak, Abs(ChangedSamples[I]));
        Require(LError <= LTolerance, 'Control did not produce declared amplitude change within PCM quantization');
      end;
      Require((LBasePeak > 0) and (LChangedPeak > 0) and (LBasePeak < 1) and (LChangedPeak < 1),
        'Delivery control requires nonzero unclipped evidence');
      WriteLn('Saved-file geometry, exact replay and declared gain effect passed; ',
        LFrames, ' frames, ', LRate, ' Hz, ', LChannels, ' channels; ratio ', LRatio,
        '; maximum PCM error ', LMaximumError);
    finally Replay.Free; Changed.Free; Base.Free; end;
  except on E: Exception do begin WriteLn(StdErr, E.Message); ExitCode := 1; end; end;
end.
