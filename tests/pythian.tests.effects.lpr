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
program pythian_tests_effects;

{$mode delphi}
{$H+}

uses
  SysUtils,
  Math,
  pythian.audio,
  pythian.biquad,
  pythian.dynamics,
  pythian.effects,
  pythian.oscillator,
  pythian.synth;

type
  TRejectEffect = class(TAudioEffect)
  public
    Reject: Boolean;
    procedure Reset; override;
    procedure Process(const ALeft, ARight: Double; out AOutputLeft, AOutputRight: Double); override;
    function FrameCost: Integer; override;
  end;

procedure TRejectEffect.Reset;
begin
  Reject := False;
end;

procedure TRejectEffect.Process(const ALeft, ARight: Double;
  out AOutputLeft, AOutputRight: Double);
begin
  if Reject then
  begin
    raise EAudio.Create('Deliberate downstream failure');
  end;
  AOutputLeft := ALeft;
  AOutputRight := ARight;
end;

function TRejectEffect.FrameCost: Integer;
begin
  Result := 1;
end;

procedure Check(const ACondition: Boolean; const AMessage: String);
begin
  if not ACondition then
  begin
    raise Exception.Create(AMessage);
  end;
end;

procedure CheckBiquadResponses;
var
  LSettings: TBiquadSettings;
  LKind: TBiquadKind;
  LFilter: TBiquadFilter;
  LFrame: Integer;
  LValue: Double;
  LEnergy: Double;
  LExpected: Double;
  LMeasured: Double;
begin
  LSettings := DefaultBiquadSettings;
  LSettings.FrequencyHz := 1000;
  LSettings.GainDb := 12;
  for LKind := Low(TBiquadKind) to High(TBiquadKind) do
  begin
    LSettings.Kind := LKind;
    LFilter := TBiquadFilter.Create(8000, LSettings);
    try
      LValue := 0;
      for LFrame := 0 to 4095 do
      begin
        LValue := LFilter.Process(1);
      end;
      LExpected := 1;
      if LKind in [bkHighPass, bkBandPass] then
      begin
        LExpected := 0;
      end;
      if LKind = bkLowShelf then
      begin
        LExpected := Power(10, 12 / 20);
      end;
      Check(Abs(LValue - LExpected) < 1E-9, 'Biquad independent DC gain');
      LFilter.Reset;
      for LFrame := 0 to 4095 do
      begin
        LValue := LFilter.Process(1 - 2 * (LFrame mod 2));
      end;
      LExpected := 1;
      if LKind in [bkLowPass, bkBandPass] then
      begin
        LExpected := 0;
      end;
      if LKind = bkHighShelf then
      begin
        LExpected := Power(10, 12 / 20);
      end;
      Check(Abs(Abs(LValue) - LExpected) < 1E-9, 'Biquad independent Nyquist gain');
      LFilter.Reset;
      LEnergy := 0;
      for LFrame := 0 to 4607 do
      begin
        LValue := LFilter.Process(Sin(2 * Pi * LFrame / 8));
        if LFrame >= 512 then
        begin
          LEnergy := LEnergy + Sqr(LValue);
        end;
      end;
      LMeasured := Sqrt(2 * LEnergy / 4096);
      LExpected := 1;
      case LKind of
        bkLowPass, bkHighPass:
        begin
          LExpected := LSettings.Q;
        end;
        bkNotch:
        begin
          LExpected := 0;
        end;
        bkPeak:
        begin
          LExpected := Power(10, 12 / 20);
        end;
        bkLowShelf, bkHighShelf:
        begin
          LExpected := Power(10, 12 / 40);
        end;
        bkBandPass, bkAllPass:
        begin
          LExpected := 1;
        end;
      end;
      WriteLn('biquad kind=', Ord(LKind), ' center_gain=', LMeasured:0:10,
        ' expected=', LExpected:0:10);
      Check(Abs(LMeasured - LExpected) < 1E-9, 'Biquad center response');
    finally
      LFilter.Free;
    end;
  end;
end;

procedure CheckBiquadState;
var
  LSettings: TBiquadSettings;
  LFilter: TBiquadFilter;
  LReference: TBiquadFilter;
  LBoost: TBiquadFilter;
  LCut: TBiquadFilter;
  LLeft: Double;
  LRight: Double;
  LRefLeft: Double;
  LRefRight: Double;
  LExpected: Double;
  LFrame: Integer;
  LRejected: Boolean;
begin
  LSettings := DefaultBiquadSettings;
  LSettings.FrequencyHz := 2000;
  LFilter := TBiquadFilter.Create(8000, LSettings);
  try
    LExpected := 1 / (2 + Sqrt(2));
    Check(Abs(LFilter.Process(1) - LExpected) < 1E-12, 'Quarter-rate impulse first coefficient');
    Check(Abs(LFilter.Process(0) - 2 * LExpected) < 1E-12, 'Quarter-rate impulse second sample');
    Check(Abs(LFilter.Process(0) - (2 * Sqrt(2) - 2) * LExpected) < 1E-12,
      'Quarter-rate impulse recurrence');
  finally
    LFilter.Free;
  end;
  LFilter := TBiquadFilter.Create(8000, LSettings, 2);
  LReference := TBiquadFilter.Create(8000, LSettings, 2);
  try
    LFilter.ProcessStereo(1, -0.25, LLeft, LRight);
    LReference.ProcessStereo(1, -0.25, LRefLeft, LRefRight);
    LRejected := False;
    try
      LFilter.ProcessStereo(0.5, 1E101, LLeft, LRight);
    except
      on EAudio do
      begin
        LRejected := True;
      end;
    end;
    Check(LRejected, 'Invalid right channel rejects');
    LSettings.Q := 0;
    try
      LFilter.SetSettings(LSettings);
      raise Exception.Create('Invalid Q accepted');
    except
      on EAudio do
      begin
      end;
    end;
    for LFrame := 0 to 63 do
    begin
      LFilter.ProcessStereo(0, 0, LLeft, LRight);
      LReference.ProcessStereo(0, 0, LRefLeft, LRefRight);
      Check((LLeft = LRefLeft) and (LRight = LRefRight), 'Biquad failure preserves both histories/design');
      Check(Abs(LRight + LLeft / 4) < 1E-14, 'Biquad stereo channels remain independent');
    end;
  finally
    LReference.Free;
    LFilter.Free;
  end;
  LSettings := DefaultBiquadSettings;
  LSettings.Kind := bkPeak;
  LSettings.GainDb := 18;
  LBoost := TBiquadFilter.Create(48000, LSettings);
  try
    LSettings.GainDb := -18;
    LCut := TBiquadFilter.Create(48000, LSettings);
    try
      for LFrame := 0 to 1023 do
      begin
        LExpected := 0;
        if LFrame = 0 then
        begin
          LExpected := 1;
        end;
        Check(Abs(LCut.Process(LBoost.Process(LExpected)) - LExpected) < 1E-12,
          'Reciprocal peak boost/cut impulse identity');
      end;
    finally
      LCut.Free;
    end;
  finally
    LBoost.Free;
  end;
end;

procedure CheckDynamics;
var
  LSettings: TCompressorSettings;
  LCompressor: TStereoCompressor;
  LLimiter: TStereoPeakLimiter;
  LSmoother: TGainSmoother;
  LLeft: Double;
  LRight: Double;
  LExpected: Double;
  LBefore: Double;
  LFrame: Integer;
  LRejected: Boolean;
begin
  LSettings := DefaultCompressorSettings;
  LSettings.ThresholdDb := -12;
  LSettings.KneeDb := 0;
  LSettings.AttackSeconds := 0;
  LSettings.ReleaseSeconds := 0;
  Check(CompressorReductionDb(0, LSettings) = 9, '4:1 compressor hard-knee slope');
  LSettings.KneeDb := 6;
  Check(CompressorReductionDb(-12, LSettings) = 0.5625, 'Independent soft-knee midpoint');
  Check(CompressorReductionDb(-15, LSettings) = 0, 'Soft-knee lower endpoint');
  Check(CompressorReductionDb(-9, LSettings) = 2.25, 'Soft-knee upper endpoint');
  LSettings.KneeDb := 0;
  LCompressor := TStereoCompressor.Create(1000, LSettings);
  try
    LCompressor.Process(1, -0.25, LLeft, LRight);
    Check(Abs(LLeft - Power(10, -9 / 20)) < 1E-12, 'Static compression amplitude');
    Check(LRight = -LLeft / 4, 'Linked stereo compression preserves image');
    LCompressor.ProcessSidechain(0.1, -0.025, 1, LLeft, LRight);
    Check(Abs(LLeft - 0.1 * Power(10, -9 / 20)) < 1E-12, 'External sidechain ducking');
    LSettings.AttackSeconds := 0.01;
    LSettings.ReleaseSeconds := 0.02;
    LCompressor.SetSettings(LSettings);
    LCompressor.Reset;
    for LFrame := 1 to 10 do
    begin
      LCompressor.Process(1, 0, LLeft, LRight);
    end;
    LExpected := 9 * (1 - Exp(-1));
    Check(Abs(LCompressor.ReductionDb - LExpected) < 1E-10, 'Attack one-time-constant response');
    for LFrame := 1 to 20 do
    begin
      LCompressor.Process(0, 0, LLeft, LRight);
    end;
    Check(Abs(LCompressor.ReductionDb - LExpected * Exp(-1)) < 1E-10,
      'Release one-time-constant response');
    LBefore := LCompressor.ReductionDb;
    LRejected := False;
    try
      LCompressor.Process(1, NaN, LLeft, LRight);
    except
      on EAudio do
      begin
        LRejected := True;
      end;
    end;
    Check(LRejected and (LBefore = LCompressor.ReductionDb), 'Invalid stereo compressor input is atomic');
  finally
    LCompressor.Free;
  end;
  LLimiter := TStereoPeakLimiter.Create(1000, -6, 0.05);
  try
    LExpected := Power(10, -6 / 20);
    LLimiter.Process(2, -1, LLeft, LRight);
    Check((Abs(LLeft - LExpected) < 1E-12) and (LRight = -LLeft / 2), 'Linked sample limiter');
    LBefore := LLimiter.Gain;
    for LFrame := 1 to 50 do
    begin
      LLimiter.Process(0, 0, LLeft, LRight);
    end;
    Check(Abs(LLimiter.Gain - (1 - (1 - LBefore) * Exp(-1))) < 1E-12,
      'Limiter exponential recovery');
    for LFrame := 0 to 2047 do
    begin
      LLimiter.Process(4 * Sin(LFrame), 2 * Cos(LFrame), LLeft, LRight);
      Check((Abs(LLeft) <= LExpected) and (Abs(LRight) <= LExpected), 'Sample ceiling on transients');
    end;
    LLimiter.Reset;
    LLeft := 2;
    LRight := -1;
    LLimiter.Process(LLeft, LRight, LRight, LLeft);
    Check((Abs(LRight - LExpected) < 1E-12) and (LLeft = -LRight / 2),
      'Limiter accepts crossed in-place channel outputs');
  finally
    LLimiter.Free;
  end;
  LSmoother := TGainSmoother.Create(1000, 0, 0.035);
  try
    LSmoother.SetTarget(1);
    for LFrame := 1 to 35 do
    begin
      LSmoother.Next;
    end;
    Check(Abs(LSmoother.Current - (1 - Exp(-1))) < 1E-12, 'Extracted bus-gain time constant');
    LSmoother.SetTarget(0);
    for LFrame := 1 to 35 do
    begin
      LSmoother.Next;
    end;
    Check(Abs(LSmoother.Current - (1 - Exp(-1)) * Exp(-1)) < 1E-12, 'Retarget retains current gain');
  finally
    LSmoother.Free;
  end;
end;

function MakeChain: TEffectChain;
var
  LSettings: TBiquadSettings;
begin
  Result := TEffectChain.Create(8000);
  try
    LSettings := DefaultBiquadSettings;
    LSettings.Kind := bkHighPass;
    LSettings.FrequencyHz := 200;
    Result.Add(TBiquadEffect.Create(8000, LSettings));
    Result.Add(TCompressorEffect.Create(8000, DefaultCompressorSettings));
    Result.Add(TLimiterEffect.Create(8000, -1, 0.05));
  except
    Result.Free;
    raise;
  end;
end;

procedure CheckChain;
var
  LChain: TEffectChain;
  LOther: TEffectChain;
  LGain: TGainEffect;
  LReject: TRejectEffect;
  LInput: TAudioClip;
  LFirst: TAudioClip;
  LSecond: TAudioClip;
  LWhole: TAudioClip;
  LPart: TAudioClip;
  LSamples: TAudioSamples;
  LFrame: Integer;
  LLeft: Double;
  LRight: Double;
  LRejected: Boolean;
begin
  LChain := TEffectChain.Create(1000);
  LOther := TEffectChain.Create(1000);
  try
    LGain := TGainEffect.Create(1000, 0, 0.035);
    LGain.SetTarget(1);
    LChain.Add(LGain);
    LRejected := False;
    try
      LOther.Add(LGain);
    except
      on EAudio do
      begin
        LRejected := True;
      end;
    end;
    Check(LRejected, 'Effect ownership cannot transfer twice');
    LReject := TRejectEffect.Create(1000);
    LChain.Add(LReject);
    LReject.Reject := True;
    LLeft := 7;
    LRight := 8;
    LRejected := False;
    try
      LChain.Process(1, 1, LLeft, LRight);
    except
      on EAudio do
      begin
        LRejected := True;
      end;
    end;
    Check(LRejected and LChain.Failed and (LLeft = 7) and (LRight = 8),
      'Downstream failure poisons chain and preserves output');
    LReject.Reject := False;
    LRejected := False;
    try
      LChain.Process(1, 1, LLeft, LRight);
    except
      on EAudio do
      begin
        LRejected := True;
      end;
    end;
    Check(LRejected, 'Failed chain refuses reuse even after the cause is removed');
    LChain.Reset;
    LGain.SetTarget(1);
    LChain.Process(1, -1, LLeft, LRight);
    Check(not LChain.Failed and (Abs(LLeft - (1 - Exp(-1 / 35))) < 1E-12) and
      (LRight = -LLeft), 'Reset restores all stage histories');
  finally
    LOther.Free;
    LChain.Free;
  end;
  SetLength(LSamples, 1024);
  for LFrame := 0 to 511 do
  begin
    LSamples[2 * LFrame] := Sin(2 * Pi * LFrame / 13);
    LSamples[2 * LFrame + 1] := 0.3 * Cos(2 * Pi * LFrame / 11);
  end;
  LInput := TAudioClip.Create(8000, 2, LSamples);
  LFirst := TAudioClip.Create(8000, 2, Copy(LSamples, 0, 200));
  LSecond := TAudioClip.Create(8000, 2, Copy(LSamples, 200, 824));
  LChain := MakeChain;
  LOther := MakeChain;
  try
    LWhole := RenderEffectClip(LInput, LChain, 64);
    try
      LPart := RenderEffectClip(LFirst, LOther);
      try
        for LFrame := 0 to 99 do
        begin
          Check(LPart.SampleAt(LFrame, 0) = LWhole.SampleAt(LFrame, 0), 'First processing partition');
        end;
      finally
        LPart.Free;
      end;
      LPart := RenderEffectClip(LSecond, LOther, 64);
      try
        Check(LPart.FrameCount = 476, 'Explicit tail extent');
        for LFrame := 0 to LPart.FrameCount - 1 do
        begin
          Check((LPart.SampleAt(LFrame, 0) = LWhole.SampleAt(100 + LFrame, 0)) and
            (LPart.SampleAt(LFrame, 1) = LWhole.SampleAt(100 + LFrame, 1)),
            'Effect history continues identically across clip boundaries');
        end;
      finally
        LPart.Free;
      end;
    finally
      LWhole.Free;
    end;
  finally
    LOther.Free;
    LChain.Free;
    LSecond.Free;
    LFirst.Free;
    LInput.Free;
  end;
end;

procedure CheckVoiceFilter;
var
  LTones: TFrameTones;
  LClip: TAudioClip;
  LFrame: Integer;
  LEnergy: Double;
begin
  SetLength(LTones, 1);
  LTones[0].Voice := DefaultSynthVoice;
  LTones[0].Voice.Shape := wsSine;
  LTones[0].Voice.FilterModel := vfmBiquad;
  LTones[0].Voice.CutoffHz := 1000;
  LTones[0].Voice.Pan := -1;
  LTones[0].Voice.Gain := 0.5;
  LTones[0].Voice.Envelope.AttackSeconds := 0;
  LTones[0].Voice.Envelope.DecaySeconds := 0;
  LTones[0].Voice.Envelope.SustainLevel := 1;
  LTones[0].Voice.Envelope.ReleaseSeconds := 0;
  LTones[0].FrequencyHz := 1000;
  LTones[0].Velocity := 1;
  LTones[0].GateFrames := 512;
  LClip := RenderFrameTones(LTones, 8000);
  try
    LEnergy := 0;
    for LFrame := 256 to 511 do
    begin
      LEnergy := LEnergy + Sqr(LClip.SampleAt(LFrame, 0));
      Check(LClip.SampleAt(LFrame, 1) = 0, 'Biquad voice retains hard-left pan');
    end;
    Check(Abs(Sqrt(LEnergy / 256) - 0.25) < 1E-7, 'Tone renderer uses biquad center gain');
  finally
    LClip.Free;
  end;
end;

procedure CheckClipOverflow;
var
  LSamples: TAudioSamples;
  LSource: TAudioClip;
  LOutput: TAudioClip;
  LChain: TEffectChain;
  LRejected: Boolean;
begin
  SetLength(LSamples, 1);
  LSamples[0] := MaxSingle;
  LSource := TAudioClip.Create(8000, 1, LSamples);
  LOutput := LSource;
  LChain := TEffectChain.Create(8000);
  try
    LChain.Add(TGainEffect.Create(8000, 16, 0));
    LRejected := False;
    try
      LOutput := RenderEffectClip(LSource, LChain);
    except
      on EAudio do
      begin
        LRejected := True;
      end;
    end;
    Check(LRejected and LChain.Failed and (LOutput = LSource),
      'Clip overflow preserves caller output and requires chain reset');
  finally
    LChain.Free;
    if LOutput <> LSource then
    begin
      LOutput.Free;
    end;
    LSource.Free;
  end;
end;

begin
  try
    CheckBiquadResponses;
    CheckBiquadState;
    CheckDynamics;
    CheckChain;
    CheckVoiceFilter;
    CheckClipOverflow;
    WriteLn('Biquad, dynamics, effect-chain and tone-filter checks passed');
  except
    on LException: Exception do
    begin
      WriteLn(StdErr, LException.ClassName, ': ', LException.Message);
      Halt(1);
    end;
  end;
end.
