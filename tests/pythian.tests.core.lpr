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
program pythian_tests_core;

{$mode delphi}
{$H+}

uses
  SysUtils,
  Math,
  pythian.audio,
  pythian.time,
  pythian.meter,
  pythian.wave,
  pythian.oscillator,
  pythian.envelope,
  pythian.filter,
  pythian.delay,
  pythian.analysis,
  pythian.learning,
  pythian.synth;

procedure Check(const ACondition: Boolean; const AMessage: String);
begin
  if not ACondition then
  begin
    raise Exception.Create(AMessage);
  end;
end;

procedure CheckWave;
const
  CGolden = '524946462E00000057415645666D74201000000001000100' +
    '44AC00008858010002001000646174610A0000000080FFFF00000100FF7F';
var
  LSamples: TAudioSamples;
  LClip: TAudioClip;
  LDecoded: TAudioClip;
  LBytes: TAudioBytes;
  LIndex: Integer;
  LHex: String;
  LRejected: Boolean;
  LLevels: TAudioLevels;
begin
  SetLength(LSamples, 5);
  LSamples[0] := -1;
  LSamples[1] := -1 / 32768;
  LSamples[2] := 0;
  LSamples[3] := 1 / 32768;
  LSamples[4] := 32767 / 32768;
  LClip := TAudioClip.Create(44100, 1, LSamples);
  try
    LLevels := MeasureAudio(LClip);
    Check((LLevels[0].Peak = 1) and
      (Abs(LLevels[0].Rms - Sqrt((1 + Sqr(32767 / 32768) + 2 / Sqr(32768)) / 5)) < 1E-12),
      'Independent PCM boundary RMS/peak');
    Check(Abs(LLevels[0].Mean + 1 / (5 * 32768)) < 1E-12, 'Signed sample mean');
    Check(LLevels[1].Peak = 0, 'Unused meter channel is zero');
    LSamples[0] := 0;
    Check(LClip.SampleAt(0, 0) = -1, 'Clip must own input samples');
    LSamples := LClip.CopySamples;
    LSamples[0] := 0;
    Check(LClip.SampleAt(0, 0) = -1, 'CopySamples must detach output');
    LBytes := EncodeWavePcm16(LClip);
    LHex := '';
    for LIndex := 0 to High(LBytes) do
    begin
      LHex := LHex + IntToHex(LBytes[LIndex], 2);
    end;
    Check(LHex = CGolden, 'WFC v1 boundary WAVE golden bytes');
    LDecoded := DecodeWave(LBytes);
    try
      for LIndex := 0 to 4 do
      begin
        Check(LDecoded.SampleAt(LIndex, 0) = LClip.SampleAt(LIndex, 0),
          'PCM16 sample identity');
      end;
    finally
      LDecoded.Free;
    end;
    { Every truncation must reject, including header and sample boundaries. }
    for LIndex := 0 to Length(LBytes) - 1 do
    begin
      LRejected := False;
      try
        LDecoded := DecodeWave(Copy(LBytes, 0, LIndex));
        LDecoded.Free;
      except
        on EAudio do
        begin
          LRejected := True;
        end;
      end;
      Check(LRejected, 'Truncated WAVE accepted');
    end;
    { Replace PCM tag with unsupported compression. }
    LBytes[20] := 2;
    LRejected := False;
    try
      LDecoded := DecodeWave(LBytes);
      LDecoded.Free;
    except
      on EAudio do
      begin
        LRejected := True;
      end;
    end;
    Check(LRejected, 'Compressed WAVE accepted');
  finally
    LClip.Free;
  end;
  WriteLn('PASS owned clips, WFC WAVE golden, round-trip, malformed input');
end;

function BytesFromHex(const AHex: String): TAudioBytes;
var
  LIndex: Integer;
begin
  Result := nil;
  SetLength(Result, Length(AHex) div 2);
  for LIndex := 0 to High(Result) do
  begin
    Result[LIndex] := StrToInt('$' + Copy(AHex, LIndex * 2 + 1, 2));
  end;
end;

procedure CheckWaveEncodings;
const
  { Hand-encoded containers, independent of the library writer. PCM8 includes
    an odd-sized unknown chunk and puts data before fmt. }
  CPcm8 = '5249464630000000574156454A554E4B010000004200' +
    '646174610200000000FF' +
    '666D74201000000001000100401F0000401F000001000800';
  CPcm24 = '524946462A00000057415645666D74201000000001000100' +
    '401F0000C05D0000030018006461746106000000000080FFFF7F';
  CPcm32 = '524946462C00000057415645666D74201000000001000100' +
    '401F0000007D000004002000646174610800000000000080FFFFFF7F';
  CFloat32 = '524946462C00000057415645666D74201000000003000100' +
    '401F0000007D0000040020006461746108000000000000BF0000C03F';
var
  LClip: TAudioClip;
  LBytes: TAudioBytes;
  LRejected: Boolean;
begin
  LClip := DecodeWave(BytesFromHex(CPcm8));
  try
    Check((LClip.SampleAt(0, 0) = -1) and (LClip.SampleAt(1, 0) = 127 / 128),
      'PCM8 unsigned samples, unknown chunk padding, reordered chunks');
  finally
    LClip.Free;
  end;
  LClip := DecodeWave(BytesFromHex(CPcm24));
  try
    Check((LClip.SampleAt(0, 0) = -1) and
      (LClip.SampleAt(1, 0) = 8388607 / 8388608), 'PCM24 sign extension');
  finally
    LClip.Free;
  end;
  LClip := DecodeWave(BytesFromHex(CPcm32));
  try
    Check((LClip.SampleAt(0, 0) = -1) and
      (LClip.SampleAt(1, 0) = 1), 'PCM32 conversion into float precision');
  finally
    LClip.Free;
  end;
  LBytes := BytesFromHex(CFloat32);
  LClip := DecodeWave(LBytes);
  try
    Check((LClip.SampleAt(0, 0) = -0.5) and
      (LClip.SampleAt(1, 0) = 1.5), 'Float32 decoding retains headroom');
  finally
    LClip.Free;
  end;
  LBytes[50] := $C0;
  LBytes[51] := $7F;
  LRejected := False;
  try
    LClip := DecodeWave(LBytes);
    LClip.Free;
  except
    on EAudio do
    begin
      LRejected := True;
    end;
  end;
  Check(LRejected, 'NaN input must be rejected before float arithmetic');
  WriteLn('PASS PCM8/24/32, float32, RIFF ordering/padding, nonfinite rejection');
end;

procedure CheckDsp;
var
  LEnvelope: TAdsr;
  LDelay: TDelay;
  LFilter: TOnePoleFilter;
  LOscillator: TOscillator;
  LFirst: Double;
  LIndex: Integer;
begin
  Check(FixedTriangleSample(0) = 0, 'Triangle origin');
  Check(FixedTriangleSample(PhaseQuarter) = 32767, 'Triangle crest');
  Check(FixedTriangleSample(3 * PhaseQuarter) = -32767, 'Triangle trough');
  Check(FixedPhaseIncrement(69, 44100) = 167392, 'Pinned WFC A4 phase increment');
  Check(FixedEnvelopeGain(0, 100, 10, 10) = 0, 'Attack boundary');
  Check(FixedEnvelopeGain(99, 100, 10, 10) = 0, 'Release boundary');
  LEnvelope := DefaultAdsr;
  LEnvelope.AttackSeconds := 1;
  LEnvelope.ReleaseSeconds := 1;
  Check(Abs(EnvelopeAt(LEnvelope, 0.75, 0.5) - 0.375) < 1E-12,
    'Early note-off releases from actual level');
  LDelay := TDelay.Create(3, 0.5, 1);
  try
    Check(LDelay.Process(1) = 1, 'Delay dry impulse');
    Check(LDelay.Process(0) = 0, 'Delay frame one');
    Check(LDelay.Process(0) = 0, 'Delay frame two');
    Check(LDelay.Process(0) = 1, 'Delay first echo');
    LDelay.Process(0);
    LDelay.Process(0);
    Check(LDelay.Process(0) = 0.5, 'Delay feedback echo');
    LDelay.Reset;
    Check(LDelay.Process(0) = 0, 'Delay reset');
  finally
    LDelay.Free;
  end;
  LFilter := TOnePoleFilter.Create(44100, 1000);
  try
    for LIndex := 0 to 999 do
    begin
      LFirst := LFilter.Process(1);
    end;
    Check(Abs(LFirst - 1) < 1E-10, 'Low-pass DC unity');
  finally
    LFilter.Free;
  end;
  LOscillator := TOscillator.Create(44100, 731);
  try
    LFirst := LOscillator.Next(wsNoise, 0);
    LOscillator.Reset(731);
    Check(LOscillator.Next(wsNoise, 0) = LFirst, 'Seeded noise replay');
    LOscillator.Reset;
    Check(Abs(LOscillator.Next(wsSine, 440)) < 1E-12, 'Sine starts at zero');
  finally
    LOscillator.Free;
  end;
  WriteLn('PASS fixed oscillator, ADSR early release, delay impulse, filter, noise replay');
end;

procedure CheckSynthesis;
var
  LTones: TTones;
  LClip: TAudioClip;
  LReplay: TAudioClip;
  LIndex: Integer;
  LEnergy: Double;
begin
  SetLength(LTones, 1);
  LTones[0].Voice := DefaultSynthVoice;
  LTones[0].Voice.Shape := wsSine;
  LTones[0].Voice.Pan := -1;
  LTones[0].FrequencyHz := 440;
  LTones[0].StartSeconds := 0.05;
  LTones[0].GateSeconds := 0.1;
  LTones[0].Velocity := 1;
  LTones[0].Seed := 731;
  LClip := RenderTones(LTones, 44100);
  try
    LReplay := RenderTones(LTones, 44100);
    try
      Check(LClip.Channels = 2, 'Stereo render');
      Check(LClip.FrameCount >= 11906, 'Release tail retained');
      LEnergy := 0;
      for LIndex := 0 to LClip.FrameCount - 1 do
      begin
        Check(LClip.SampleAt(LIndex, 1) = 0, 'Hard-left pan');
        Check(LClip.SampleAt(LIndex, 0) = LReplay.SampleAt(LIndex, 0), 'Render replay');
        if LIndex < 2205 then
        begin
          Check(LClip.SampleAt(LIndex, 0) = 0, 'Scheduled silence');
        end;
        LEnergy := LEnergy + Sqr(LClip.SampleAt(LIndex, 0));
      end;
      Check(LEnergy > 1, 'Render contains signal');
    finally
      LReplay.Free;
    end;
  finally
    LClip.Free;
  end;
  WriteLn('PASS native synthesis, scheduling, stereo pan, release tail, replay');
end;

procedure CheckSampleTime;
var
  LTone: TFrameTone;
  LPlaying: TPlayingTone;
  LClip: TAudioClip;
  LRejected: Boolean;
  LCount: Int64;
begin
  Check(SampleFramesFromSeconds(0.08, 44100) = 3528, '80 ms has a binary64 3528-frame product');
  Check(SampleFramesFromSeconds(0.080001, 44100) = 3529, 'A fractional frame still rounds upward');
  Check(SampleFramesFromSeconds(0.080001, 44100, frFloor) = 3528, 'Explicit floor retains lower frame');
  Check(SampleFramesFromSeconds(0, 44100) = 0, 'Zero sample time');
  LCount := 123;
  LRejected := False;
  try
    LCount := SampleFramesFromSeconds(MaxDouble, 44100);
  except
    on EAudio do
    begin
      LRejected := True;
    end;
  end;
  Check(LRejected and (LCount = 123), 'Excess seconds reject before multiplication and preserve assignment');
  LTone := Default(TFrameTone);
  LTone.Voice := DefaultSynthVoice;
  LTone.Voice.Envelope.ReleaseSeconds := 0.08;
  LTone.FrequencyHz := 440;
  LTone.Velocity := 0.5;
  LTone.GateFrames := 10;
  LPlaying := TPlayingTone.Create(44100, LTone);
  LClip := nil;
  try
    LClip := RenderFrameTones([LTone], 44100);
    Check((LPlaying.FrameCount = 3538) and (LClip.FrameCount = 3538),
      'Offline and scheduled voice admission share exact release rounding');
    LPlaying.Release;
    Check(LPlaying.FrameCount = 3528, 'Early scheduled release shares the same frame conversion');
  finally
    LClip.Free;
    LPlaying.Free;
  end;
  WriteLn('PASS binary64 sample-time rounding and shared offline/scheduled release');
end;

procedure CompareWaveOutput(const ALeftName, ARightName: String);
var
  LLeft: TAudioClip;
  LRight: TAudioClip;
  LFrame: Integer;
  LChannel: Integer;
  LChanged: Integer;
  LMaximumError: Double;
  LError: Double;
begin
  LLeft := LoadWave(ALeftName);
  LRight := nil;
  try
    LRight := LoadWave(ARightName);
    Check((LLeft.FrameCount = LRight.FrameCount) and (LLeft.SampleRate = LRight.SampleRate) and
      (LLeft.Channels = LRight.Channels), 'Cross-target WAV geometry must match exactly');
    LMaximumError := 0;
    LChanged := 0;
    for LFrame := 0 to LLeft.FrameCount - 1 do
    begin
      for LChannel := 0 to LLeft.Channels - 1 do
      begin
        LError := Abs(LLeft.SampleAt(LFrame, LChannel) - LRight.SampleAt(LFrame, LChannel));
        if LError > 0 then
        begin
          Inc(LChanged);
          LMaximumError := Max(LMaximumError, LError);
        end;
      end;
    end;
    WriteLn('Cross-target PCM: ', LLeft.FrameCount, ' frames; ', LChanged,
      ' changed samples; maximum error ', LMaximumError * 32768:0:3, ' PCM16 steps');
    Check(LMaximumError <= 1 / 32768, 'Cross-target synthesis differs by more than one PCM16 step');
  finally
    LRight.Free;
    LLeft.Free;
  end;
end;

begin
  try
    CheckSampleTime;
    CheckWave;
    CheckWaveEncodings;
    CheckDsp;
    CheckSynthesis;
    if ParamCount = 2 then
    begin
      CompareWaveOutput(ParamStr(1), ParamStr(2));
    end;
  except
    on LException: Exception do
    begin
      WriteLn(StdErr, LException.ClassName, ': ', LException.Message);
      Halt(1);
    end;
  end;
end.
