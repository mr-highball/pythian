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
program pythian_tests_separation;

{$mode delphi}
{$H+}

uses
  SysUtils,
  Math,
  pythian.audio,
  pythian.fourier,
  pythian.separation,
  pythian.wave;

procedure Check(const AValue: Boolean; const AMessage: String);
begin
  if not AValue then
  begin
    raise Exception.Create(AMessage);
  end;
end;

procedure FourierChecks;
var
  LReal: TFourierValues;
  LImaginary: TFourierValues;
  LOriginalReal: TFourierValues;
  LOriginalImaginary: TFourierValues;
  LExpectedReal: Double;
  LExpectedImaginary: Double;
  LAngle: Double;
  LBin: Integer;
  LIndex: Integer;
  LRejected: Boolean;
begin
  SetLength(LReal, 8);
  SetLength(LImaginary, 8);
  for LIndex := 0 to 7 do
  begin
    LReal[LIndex] := (LIndex - 3) / 7;
    LImaginary[LIndex] := (LIndex mod 3 - 1) / 5;
  end;
  LOriginalReal := LReal;
  LOriginalImaginary := LImaginary;
  Fourier(LReal, LImaginary);
  for LBin := 0 to 7 do
  begin
    LExpectedReal := 0;
    LExpectedImaginary := 0;
    for LIndex := 0 to 7 do
    begin
      LAngle := -2 * Pi * LBin * LIndex / 8;
      LExpectedReal := LExpectedReal + LOriginalReal[LIndex] * Cos(LAngle) -
        LOriginalImaginary[LIndex] * Sin(LAngle);
      LExpectedImaginary := LExpectedImaginary + LOriginalReal[LIndex] * Sin(LAngle) +
        LOriginalImaginary[LIndex] * Cos(LAngle);
    end;
    Check((Abs(LReal[LBin] - LExpectedReal) < 1E-12) and
      (Abs(LImaginary[LBin] - LExpectedImaginary) < 1E-12), 'FFT matches independent direct complex DFT');
  end;
  Check(Abs(LOriginalReal[0] + 3 / 7) < 1E-15, 'Transform detaches shared original arrays');
  Fourier(LReal, LImaginary, True);
  for LIndex := 0 to 7 do
  begin
    Check((Abs(LReal[LIndex] - LOriginalReal[LIndex]) < 1E-12) and
      (Abs(LImaginary[LIndex] - LOriginalImaginary[LIndex]) < 1E-12),
      'Inverse restores original complex signal with 1/N scaling');
  end;
  LImaginary := LReal;
  Fourier(LReal, LImaginary);
  Check(LReal[0] = LImaginary[0], 'Distinct variables may share input buffers');
  LRejected := False;
  try
    Fourier(LReal, LReal);
  except
    on EAudio do
    begin
      LRejected := True;
    end;
  end;
  Check(LRejected, 'Same output variable rejects');
  SetLength(LImaginary, 3);
  LOriginalReal := Copy(LReal);
  LRejected := False;
  try
    Fourier(LReal, LImaginary);
  except
    on EAudio do
    begin
      LRejected := True;
    end;
  end;
  Check(LRejected and (LReal[0] = LOriginalReal[0]) and (Length(LImaginary) = 3),
    'Invalid geometry preserves both arrays');
end;

procedure CheckWavePair(const ASourceName, AHarmonicName, APercussiveName: String);
var
  LSource: TAudioClip;
  LHarmonic: TAudioClip;
  LPercussive: TAudioClip;
  LFrame: Integer;
  LChannel: Integer;
  LSum: Double;
  LMaximumError: Double;
begin
  LSource := nil;
  LHarmonic := nil;
  LPercussive := nil;
  try
    LSource := LoadWave(ASourceName);
    LHarmonic := LoadWave(AHarmonicName);
    LPercussive := LoadWave(APercussiveName);
    Check((LSource.SampleRate = LHarmonic.SampleRate) and
      (LSource.SampleRate = LPercussive.SampleRate) and
      (LSource.Channels = LHarmonic.Channels) and (LSource.Channels = LPercussive.Channels) and
      (LSource.FrameCount = LHarmonic.FrameCount) and (LSource.FrameCount = LPercussive.FrameCount),
      'Both encoded separation components retain complete source geometry');
    LMaximumError := 0;
    for LFrame := 0 to LSource.FrameCount - 1 do
    begin
      for LChannel := 0 to LSource.Channels - 1 do
      begin
        LSum := LHarmonic.SampleAt(LFrame, LChannel);
        LSum := LSum + LPercussive.SampleAt(LFrame, LChannel);
        LMaximumError := Max(LMaximumError, Abs(LSum - LSource.SampleAt(LFrame, LChannel)));
      end;
    end;
    Check(LMaximumError <= 2 / 32768, 'Independently encoded components reconstruct within two PCM16 steps');
    WriteLn('Encoded component sum: ', LSource.FrameCount, ' frames / ', LSource.Channels,
      ' channels; maximum reconstruction error ', LMaximumError);
  finally
    LPercussive.Free;
    LHarmonic.Free;
    LSource.Free;
  end;
end;

procedure SeparationChecks(const APrefix: String);
var
  LSamples: TAudioSamples;
  LSource: TAudioClip;
  LResult: THarmonicPercussive;
  LPrior: THarmonicPercussive;
  LOptions: THarmonicPercussiveOptions;
  LPlan: TSeparationPlan;
  LFrame: Integer;
  LChannel: Integer;
  LTone: Double;
  LClick: Double;
  LValue: Double;
  LError: Double;
  LMaximumError: Double;
  LHEnergyError: Double;
  LPEnergyError: Double;
  LHEnergy: Double;
  LPEnergy: Double;
  LRejected: Boolean;
begin
  LOptions := DefaultHarmonicPercussiveOptions;
  LOptions.WindowFrames := 512;
  LOptions.HopFrames := 128;
  SetLength(LSamples, 32000 * 2);
  for LFrame := 0 to 31999 do
  begin
    LTone := 0.2 * Sin(2 * Pi * 440 * LFrame / 8000);
    LClick := 0;
    if LFrame mod 4000 = 512 then
    begin
      LClick := 0.8;
    end;
    LSamples[LFrame * 2] := LTone + LClick;
    LSamples[LFrame * 2 + 1] := -0.5 * LSamples[LFrame * 2];
  end;
  LSource := TAudioClip.Create(8000, 2, LSamples);
  LResult := nil;
  try
    LResult := THarmonicPercussive.Create(LSource, LOptions);
    LPlan := PlanHarmonicPercussive(LSource.FrameCount, LSource.Channels, LOptions);
    Check((LPlan.AnalysisFrames = 251) and (LPlan.FrequencyBins = 257) and
      (LPlan.SpectralCells = 64507) and (LPlan.Work = LResult.Plan.Work),
      'Preflight accounts for centered frames, one-sided bins and actual processing plan');
    Check((LResult.Harmonic.FrameCount = LSource.FrameCount) and
      (LResult.Percussive.FrameCount = LSource.FrameCount) and
      (LResult.Harmonic.Channels = 2) and (LResult.Percussive.SampleRate = 8000),
      'Separation retains exact source geometry');
    LMaximumError := 0;
    LHEnergyError := 0;
    LPEnergyError := 0;
    LHEnergy := 0;
    LPEnergy := 0;
    for LFrame := 0 to LSource.FrameCount - 1 do
    begin
      for LChannel := 0 to 1 do
      begin
        LValue := LResult.Harmonic.SampleAt(LFrame, LChannel);
        LValue := LValue + LResult.Percussive.SampleAt(LFrame, LChannel);
        LMaximumError := Max(LMaximumError, Abs(LValue - LSource.SampleAt(LFrame, LChannel)));
      end;
      Check(Abs(LResult.Harmonic.SampleAt(LFrame, 1) +
        0.5 * LResult.Harmonic.SampleAt(LFrame, 0)) < 1E-7, 'Shared stereo masks retain polarity and channel ratio');
      if (LFrame >= 1024) and (LFrame < 30976) then
      begin
        LTone := 0.2 * Sin(2 * Pi * 440 * LFrame / 8000);
        LClick := 0;
        if LFrame mod 4000 = 512 then
        begin
          LClick := 0.8;
        end;
        LError := LResult.Harmonic.SampleAt(LFrame, 0) - LTone;
        LHEnergyError := LHEnergyError + Sqr(LError);
        LError := LResult.Percussive.SampleAt(LFrame, 0) - LClick;
        LPEnergyError := LPEnergyError + Sqr(LError);
        LHEnergy := LHEnergy + Sqr(LTone);
        LPEnergy := LPEnergy + Sqr(LClick);
      end;
    end;
    Check(LMaximumError < 1E-7, 'Complementary components reconstruct every sample including edges');
    Check(LHEnergyError / LHEnergy < 0.01, 'Controlled harmonic component exceeds 20 dB signal/error');
    Check(LPEnergyError / LPEnergy < 0.1, 'Controlled percussive component exceeds 10 dB signal/error');
    WriteLn('Controlled harmonic signal/error dB: ', 10 * Log10(LHEnergy / LHEnergyError):0:5,
      '; percussive: ', 10 * Log10(LPEnergy / LPEnergyError):0:5,
      '; maximum reconstruction error: ', LMaximumError);
    if APrefix <> '' then
    begin
      SaveWavePcm16(APrefix + '-source.wav', LSource);
      SaveWavePcm16(APrefix + '-harmonic.wav', LResult.Harmonic);
      SaveWavePcm16(APrefix + '-percussive.wav', LResult.Percussive);
    end;
    LSource.Free;
    LSource := nil;
    Check(LResult.Harmonic.FrameCount = 32000, 'Separated clips outlive released source');
    LPrior := LResult;
    LRejected := False;
    try
      LResult := THarmonicPercussive.Create(nil, LOptions);
    except
      on EAudio do
      begin
        LRejected := True;
      end;
    end;
    Check(LRejected and (LResult = LPrior), 'Rejected separation preserves prior object');
    LOptions.HarmonicMedianFrames := 16;
    LRejected := False;
    try
      LPlan := PlanHarmonicPercussive(32000, 2, LOptions);
    except
      on EAudio do
      begin
        LRejected := True;
      end;
    end;
    Check(LRejected, 'Even median length rejects');
    LOptions := DefaultHarmonicPercussiveOptions;
    LRejected := False;
    try
      LPlan := PlanHarmonicPercussive(MaximumClipSamples div 2, 2, LOptions);
    except
      on EAudio do
      begin
        LRejected := True;
      end;
    end;
    Check(LRejected, 'Spectral memory preflight rejects large source');
  finally
    LResult.Free;
    LSource.Free;
  end;
  SetLength(LSamples, 1);
  LSamples[0] := 0.25;
  LSource := TAudioClip.Create(8000, 1, LSamples);
  try
    LResult := THarmonicPercussive.Create(LSource, DefaultHarmonicPercussiveOptions);
    try
      Check((LResult.Harmonic.SampleAt(0, 0) = 0.125) and
        (LResult.Percussive.SampleAt(0, 0) = 0.125),
        'One-frame broadband input splits equal evidence without losing the boundary sample');
    finally
      LResult.Free;
    end;
  finally
    LSource.Free;
  end;
  LSamples[0] := 0;
  LSource := TAudioClip.Create(8000, 1, LSamples);
  try
    LResult := THarmonicPercussive.Create(LSource, DefaultHarmonicPercussiveOptions);
    try
      Check((LResult.Harmonic.SampleAt(0, 0) = 0) and
        (LResult.Percussive.SampleAt(0, 0) = 0), 'Zero-evidence bins avoid division by zero');
    finally
      LResult.Free;
    end;
  finally
    LSource.Free;
  end;
  WriteLn('FFT, separation geometry, controlled components, stereo, ownership and rejection checks pass');
end;

begin
  try
    if (ParamCount = 4) and (ParamStr(1) = 'reconstruct') then
    begin
      CheckWavePair(ParamStr(2), ParamStr(3), ParamStr(4));
    end
    else
    begin
      FourierChecks;
      SeparationChecks(ParamStr(1));
    end;
  except
    on LException: Exception do
    begin
      WriteLn(StdErr, LException.ClassName, ': ', LException.Message);
      Halt(1);
    end;
  end;
end.
