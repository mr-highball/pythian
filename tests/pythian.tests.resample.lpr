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
program pythian_tests_resample;

{$mode delphi}
{$H+}

uses
  SysUtils,
  Math,
  pythian.audio,
  pythian.oscillator,
  pythian.synth,
  pythian.resample,
  pythian.granular;

procedure Check(const ACondition: Boolean; const AMessage: String);
begin
  if not ACondition then
  begin
    raise Exception.Create(AMessage);
  end;
end;

function AliasRatio(const AShape: TWaveShape; const AQuality: TOscillatorQuality;
  const ABin: Integer): Double;
const
  CFrames = 8192;
var
  LOscillator: TOscillator;
  LSamples: array of Double;
  LFrame: Integer;
  LHarmonic: Integer;
  LCos: Double;
  LSin: Double;
  LTotal: Double;
  LAllowed: Double;
  LFundamental: Double;
  LPower: Double;
begin
  SetLength(LSamples, CFrames);
  LOscillator := TOscillator.Create(32768, 731, AQuality);
  try
    LTotal := 0;
    for LFrame := 0 to CFrames - 1 do
    begin
      LSamples[LFrame] := LOscillator.Next(AShape, ABin * 4);
      LTotal := LTotal + Sqr(LSamples[LFrame]);
    end;
    LOscillator.Reset;
    for LFrame := 0 to CFrames - 1 do
    begin
      Check(LSamples[LFrame] = LOscillator.Next(AShape, ABin * 4), 'Oscillator replay');
    end;
  finally
    LOscillator.Free;
  end;
  LAllowed := 0;
  LFundamental := 0;
  for LHarmonic := 1 to (CFrames div 2 - 1) div ABin do
  begin
    if (AShape <> wsSaw) and (LHarmonic mod 2 = 0) then
    begin
      Continue;
    end;
    LCos := 0;
    LSin := 0;
    for LFrame := 0 to CFrames - 1 do
    begin
      LCos := LCos + LSamples[LFrame] * Cos(2 * Pi * LHarmonic * ABin * LFrame / CFrames);
      LSin := LSin + LSamples[LFrame] * Sin(2 * Pi * LHarmonic * ABin * LFrame / CFrames);
    end;
    LPower := 2 * (Sqr(LCos / CFrames) + Sqr(LSin / CFrames));
    LAllowed := LAllowed + LPower;
    if LHarmonic = 1 then
    begin
      LFundamental := LPower;
    end;
  end;
  Check(LFundamental > 0.05, 'Alias reduction must retain fundamental energy');
  Result := Max(0, LTotal / CFrames - LAllowed) / LFundamental;
end;

procedure CheckOscillators;
const
  CBins: array[0..1] of Integer = (997, 3079);
var
  LShape: TWaveShape;
  LBin: Integer;
  LNaive: Double;
  LPolynomial: Double;
  LOscillator: TOscillator;
  LReference: TOscillator;
  LRejected: Boolean;
  LIndex: Integer;
begin
  for LShape := wsTriangle to wsSquare do
  begin
    for LBin in CBins do
    begin
      LNaive := AliasRatio(LShape, oqNaive, LBin);
      LPolynomial := AliasRatio(LShape, oqPolynomial, LBin);
      WriteLn('shape=', Ord(LShape), ' bin=', LBin, ' alias/fundamental naive=',
        LNaive:0:9, ' polynomial=', LPolynomial:0:9,
        ' reduction_db=', (10 * Log10(LNaive / LPolynomial)):0:3);
      Check(LPolynomial < LNaive * 0.3, 'Polynomial alias energy reduction');
    end;
  end;
  LOscillator := TOscillator.Create(48000, 731, oqPolynomial);
  LReference := TOscillator.Create(48000);
  try
    for LShape := wsSine to wsNoise do
    begin
      LOscillator.Reset;
      LReference.Reset;
      Check(LOscillator.Next(LShape, 0) = LReference.Next(LShape, 0),
        'Zero-frequency definition');
    end;
    for LIndex := 0 to 99 do
    begin
      Check(LOscillator.Next(wsNoise, 1000) = LReference.Next(wsNoise, 1000),
        'Noise recurrence unchanged');
    end;
    LOscillator.Reset;
    LRejected := False;
    try
      LOscillator.Next(wsSaw, 24000);
    except
      on EAudio do
      begin
        LRejected := True;
      end;
    end;
    Check(LRejected, 'Nyquist must reject');
    Check(LOscillator.Next(wsSaw, 6000) = 0, 'Failure preserves oscillator phase');
  finally
    LReference.Free;
    LOscillator.Free;
  end;
end;

function ToneClip(const ARate, AFrames: Integer; const AFrequency: Double): TAudioClip;
var
  LSamples: TAudioSamples;
  LFrame: Integer;
begin
  SetLength(LSamples, AFrames * 2);
  for LFrame := 0 to AFrames - 1 do
  begin
    LSamples[2 * LFrame] := 0.5 * Sin(2 * Pi * AFrequency * LFrame / ARate);
    LSamples[2 * LFrame + 1] := -LSamples[2 * LFrame];
  end;
  Result := TAudioClip.Create(ARate, 2, LSamples);
end;

procedure CheckSpectra;
const
  CFrequencies: array[0..3] of Integer = (1000, 7000, 9000, 18000);
var
  LSource: TAudioClip;
  LOutput: TAudioClip;
  LIndex: Integer;
  LFrame: Integer;
  LError: Double;
  LRms: Double;
  LExpected: Double;
begin
  for LIndex := 0 to High(CFrequencies) do
  begin
    LSource := ToneClip(48000, 12000, CFrequencies[LIndex]);
    try
      LOutput := ResampleClip(LSource, 16000);
      try
        Check(LOutput.FrameCount = 4000, 'Exact integer downsampling duration');
        LError := 0;
        LRms := 0;
        for LFrame := 128 to LOutput.FrameCount - 129 do
        begin
          LExpected := 0.5 * Sin(2 * Pi * CFrequencies[LIndex] * LFrame / 16000);
          LError := LError + Sqr(LOutput.SampleAt(LFrame, 0) - LExpected);
          LRms := LRms + Sqr(LOutput.SampleAt(LFrame, 0));
          Check(LOutput.SampleAt(LFrame, 1) = -LOutput.SampleAt(LFrame, 0),
            'Anti-phase stereo must survive conversion');
        end;
        LRms := Sqrt(LRms / (LOutput.FrameCount - 256));
        LError := Sqrt(LError / (LOutput.FrameCount - 256));
        WriteLn('48000->16000 frequency=', CFrequencies[LIndex],
          ' interior_rms=', LRms:0:9, ' reference_error=', LError:0:9);
        if LIndex < 2 then
        begin
          Check(LError < 0.001, 'Passband phase and gain');
        end
        else
        begin
          Check(LRms < 0.00001, 'Stopband alias suppression');
        end;
      finally
        LOutput.Free;
      end;
    finally
      LSource.Free;
    end;
  end;
  LSource := ToneClip(12000, 3000, 1000);
  try
    LOutput := ResampleClip(LSource, 48000);
    try
      LError := 0;
      for LFrame := 256 to LOutput.FrameCount - 257 do
      begin
        LExpected := 0.5 * Sin(2 * Pi * 1000 * LFrame / 48000);
        LError := Max(LError, Abs(LOutput.SampleAt(LFrame, 0) - LExpected));
      end;
      WriteLn('12000->48000 maximum_interior_error=', LError:0:9);
      Check(LError < 0.0001, 'Upsampling interpolation and image suppression');
    finally
      LOutput.Free;
    end;
  finally
    LSource.Free;
  end;
end;

procedure CheckCoordinates;
var
  LSamples: TAudioSamples;
  LSource: TAudioClip;
  LOutput: TAudioClip;
  LReplay: TAudioClip;
  LFrame: Integer;
  LFrames: Integer;
  LVisits: Int64;
  LRejected: Boolean;
begin
  SetLength(LSamples, 5000);
  LSamples[2205] := 1;
  LSource := TAudioClip.Create(44100, 1, LSamples);
  try
    LOutput := ResampleClip(LSource, 48000);
    try
      Check(LOutput.FrameCount = 5443, 'Rational ceiling duration');
      Check(LOutput.SampleAt(2400, 0) > 0.9, 'Impulse exact rational anchor');
      for LFrame := 1 to 64 do
      begin
        Check(Abs(LOutput.SampleAt(2400 - LFrame, 0) -
          LOutput.SampleAt(2400 + LFrame, 0)) < 1E-7, 'Centered impulse symmetry');
      end;
      LReplay := ResampleClip(LSource, 48000);
      try
        for LFrame := 0 to LOutput.FrameCount - 1 do
        begin
          Check(LOutput.SampleAt(LFrame, 0) = LReplay.SampleAt(LFrame, 0), 'SRC replay');
        end;
      finally
        LReplay.Free;
      end;
    finally
      LOutput.Free;
    end;
    LOutput := ResampleClip(LSource, 44100);
    try
      Check(LOutput <> LSource, 'Unity rate detached ownership');
      for LFrame := 0 to 4999 do
      begin
        Check(LOutput.SampleAt(LFrame, 0) = LSamples[LFrame], 'Unity rate exact identity');
      end;
    finally
      LOutput.Free;
    end;
  finally
    LSource.Free;
  end;
  SetLength(LSamples, 1);
  LSamples[0] := 0.25;
  LSource := TAudioClip.Create(8000, 1, LSamples);
  try
    LOutput := ResampleClip(LSource, 44100);
    try
      Check(LOutput.FrameCount = 6, 'Single frame duration');
      for LFrame := 0 to 5 do
      begin
        Check(LOutput.SampleAt(LFrame, 0) = 0.25, 'Constant edge extension and DC gain');
      end;
    finally
      LOutput.Free;
    end;
  finally
    LSource.Free;
  end;
  LRejected := False;
  try
    PlanResample(64000000, 1, 48000, 16000, LFrames, LVisits);
  except
    on EAudio do
    begin
      LRejected := True;
    end;
  end;
  Check(LRejected and (LFrames = 0) and (LVisits = 0), 'Work preflight clears failed plan');
  LRejected := False;
  try
    PlanResample(1, 1, 384000, 1000, LFrames, LVisits);
  except
    on EAudio do
    begin
      LRejected := True;
    end;
  end;
  Check(LRejected, 'Unsupported ratio rejects before allocation');
  PlanResample(640, 2, 384000, 6000, LFrames, LVisits);
  Check((LFrames = 10) and (LVisits = 174340), 'Maximum ratio and conservative taps');
  LRejected := False;
  try
    PlanResample(64000000, 1, 8000, 48000, LFrames, LVisits);
  except
    on EAudio do
    begin
      LRejected := True;
    end;
  end;
  Check(LRejected and (LFrames = 0), 'Output size rejects before allocation');
  SetLength(LSamples, 0);
  LSource := TAudioClip.Create(48000, 2, LSamples);
  try
    LOutput := ResampleClip(LSource, 44100);
    try
      Check((LOutput.FrameCount = 0) and (LOutput.Channels = 2), 'Empty stereo conversion');
    finally
      LOutput.Free;
    end;
  finally
    LSource.Free;
  end;
end;

procedure CheckSincGrains;
var
  LSources: TAudioSources;
  LGrains: TAudioGrains;
  LOptions: TGrainRenderOptions;
  LOutput: TAudioClip;
  LFrame: Integer;
  LEnergy: Double;
begin
  SetLength(LSources, 1);
  LSources[0] := ToneClip(48000, 12000, 18000);
  try
    SetLength(LGrains, 1);
    LGrains[0].FrameCount := 4000;
    LGrains[0].PlaybackRate := 3;
    LGrains[0].Gain := 1;
    LOptions := DefaultGrainRenderOptions(48000, 2);
    LOptions.Interpolation := giSinc;
    LOutput := RenderGrains(LSources, LGrains, LOptions);
    try
      LEnergy := 0;
      for LFrame := 128 to 3871 do
      begin
        LEnergy := LEnergy + Sqr(LOutput.SampleAt(LFrame, 0));
      end;
      Check(Sqrt(LEnergy / 3744) < 0.00001, 'Granular downsampling uses anti-alias filter');
    finally
      LOutput.Free;
    end;
    LGrains[0].PlaybackRate := 1;
    LOutput := RenderGrains(LSources, LGrains, LOptions);
    try
      for LFrame := 0 to 3999 do
      begin
        Check(LOutput.SampleAt(LFrame, 0) = LSources[0].SampleAt(LFrame, 0),
          'Unity grain identity with sinc option');
      end;
    finally
      LOutput.Free;
    end;
  finally
    LSources[0].Free;
  end;
end;

procedure CheckSynthQuality;
var
  LTones: TFrameTones;
  LNaive: TAudioClip;
  LPolynomial: TAudioClip;
begin
  SetLength(LTones, 1);
  LTones[0].Voice := DefaultSynthVoice;
  LTones[0].Voice.Shape := wsSaw;
  LTones[0].Voice.CutoffHz := 2000;
  LTones[0].Voice.Envelope.AttackSeconds := 0;
  LTones[0].Voice.Envelope.DecaySeconds := 0;
  LTones[0].Voice.Envelope.SustainLevel := 1;
  LTones[0].Voice.Envelope.ReleaseSeconds := 0;
  LTones[0].FrequencyHz := 1000;
  LTones[0].GateFrames := 16;
  LTones[0].Velocity := 1;
  LNaive := RenderFrameTones(LTones, 8000);
  try
    LTones[0].Voice.OscillatorQuality := oqPolynomial;
    LPolynomial := RenderFrameTones(LTones, 8000);
    try
      Check(LNaive.SampleAt(0, 0) < 0, 'Legacy saw starts below zero');
      Check(LPolynomial.SampleAt(0, 0) = 0, 'Renderer applies corrected wrap midpoint');
      Check(LPolynomial.FrameCount = LNaive.FrameCount, 'Quality retains gate extent');
      Check(LPolynomial.SampleAt(1, 0) <> 0, 'Corrected voice remains audible');
    finally
      LPolynomial.Free;
    end;
  finally
    LNaive.Free;
  end;
end;

begin
  try
    CheckOscillators;
    CheckSpectra;
    CheckCoordinates;
    CheckSincGrains;
    CheckSynthQuality;
    WriteLn('Oscillator and resampling checks passed');
  except
    on LException: Exception do
    begin
      WriteLn(StdErr, LException.ClassName, ': ', LException.Message);
      Halt(1);
    end;
  end;
end.
