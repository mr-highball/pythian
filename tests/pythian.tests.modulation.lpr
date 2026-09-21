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
program pythian_tests_modulation;

{$mode delphi}
{$H+}

uses
  SysUtils,
  Math,
  pythian.audio,
  pythian.automation,
  pythian.additive,
  pythian.modulation,
  pythian.resample,
  pythian.oscillator,
  pythian.filter,
  pythian.synth;

procedure Check(const ACondition: Boolean; const AMessage: String);
begin
  if not ACondition then
  begin
    raise Exception.Create(AMessage);
  end;
end;

function Curve(const AFirst, ALast: Double; const AEnd: Int64;
  const ATransition: TAutomationTransition): TAutomationCurve;
var
  LPoints: TAutomationPoints;
begin
  SetLength(LPoints, 2);
  LPoints[0].Value := AFirst;
  LPoints[0].Transition := ATransition;
  LPoints[1].Frame := AEnd;
  LPoints[1].Value := ALast;
  Result := TAutomationCurve.Create(LPoints);
end;

procedure CheckCurves;
var
  LPoints: TAutomationPoints;
  LCopy: TAutomationPoints;
  LCurve: TAutomationCurve;
  LRejected: Boolean;
begin
  SetLength(LPoints, 3);
  LPoints[0].Frame := 10;
  LPoints[0].Value := -1;
  LPoints[0].Transition := atHold;
  LPoints[1].Frame := 20;
  LPoints[1].Value := 2;
  LPoints[1].Transition := atLinear;
  LPoints[2].Frame := 30;
  LPoints[2].Value := 4;
  LCurve := TAutomationCurve.Create(LPoints);
  try
    LPoints[1].Value := 900;
    LCopy := LCurve.CopyPoints;
    LCopy[2].Value := -900;
    Check((LCurve.ValueAt(0) = -1) and (LCurve.ValueAt(19) = -1), 'Leading/segment hold');
    Check((LCurve.ValueAt(20) = 2) and (LCurve.ValueAt(25) = 3), 'Exact knot and linear midpoint');
    Check((LCurve.ValueAt(High(Int64)) = 4) and (LCurve.Maximum = 4), 'Detached tail and extrema');
  finally
    LCurve.Free;
  end;
  LCurve := Curve(125, 42, 7200, atExponential);
  try
    Check(Abs(LCurve.ValueAt(3600) - Sqrt(125 * 42)) < 1E-10,
      'Precursor kick frequency geometric midpoint');
    Check((LCurve.ValueAt(0) = 125) and (LCurve.ValueAt(7200) = 42), 'Exact exponential endpoints');
  finally
    LCurve.Free;
  end;
  SetLength(LPoints, 2);
  LPoints[0].Frame := High(Int64) - 20;
  LPoints[0].Value := 10;
  LPoints[0].Transition := atLinear;
  LPoints[1].Frame := High(Int64);
  LPoints[1].Value := 30;
  LCurve := TAutomationCurve.Create(LPoints);
  try
    Check(LCurve.ValueAt(High(Int64) - 10) = 20, 'High integer coordinates retain differences');
    LPoints[1].Frame := LPoints[0].Frame;
    LRejected := False;
    try
      LCurve := TAutomationCurve.Create(LPoints);
    except
      on EAudio do
      begin
        LRejected := True;
      end;
    end;
    Check(LRejected and (LCurve.ValueAt(High(Int64)) = 30), 'Failed candidate preserves curve');
  finally
    LCurve.Free;
  end;
  LRejected := False;
  try
    LCurve := Curve(0, 1, 100, atExponential);
    LCurve.Free;
  except
    on EAudio do
    begin
      LRejected := True;
    end;
  end;
  Check(LRejected, 'Zero exponential endpoint rejects');
  Check(Abs(FrequencyWithCents(440, 1200) - 880) < 1E-12, 'Pitch cents octave');
end;

procedure CheckAdditive;
var
  LPartials: TAdditivePartials;
  LOscillator: TAdditiveOscillator;
  LReference: TAdditiveOscillator;
  LFrame: Integer;
  LExpected: Double;
  LActual: Double;
  LRejected: Boolean;
begin
  SetLength(LPartials, 3);
  LPartials[0].Ratio := 1;
  LPartials[0].Gain := 0.7;
  LPartials[1].Ratio := 2;
  LPartials[1].Gain := -0.2;
  LPartials[2].Ratio := 3.5;
  LPartials[2].Gain := 0.1;
  LPartials[2].PhaseCycles := 0.25;
  LOscillator := TAdditiveOscillator.Create(32768, LPartials);
  try
    LPartials[0].Gain := 12;
    for LFrame := 0 to 1023 do
    begin
      LExpected := 0.7 * Sin(2 * Pi * 512 * LFrame / 32768) -
        0.2 * Sin(2 * Pi * 1024 * LFrame / 32768) +
        0.1 * Cos(2 * Pi * 1792 * LFrame / 32768);
      Check(Abs(LOscillator.Next(512) - LExpected) < 1E-12, 'Owned harmonic/inharmonic sum');
    end;
    Check(LOscillator.OmittedPartials = 0, 'Admitted partial count');
    LOscillator.Reset;
    Check(Abs(LOscillator.Next(0) - 0.1) < 1E-12, 'Zero frequency and reset phase');
    Check(LOscillator.Next(0, [1, 1, 0]) = 0, 'Independent partial amplitude modulation');
    LRejected := False;
    try
      LOscillator.Next(512, [1, 1, 17]);
    except
      on EAudio do
      begin
        LRejected := True;
      end;
    end;
    Check(LRejected and (Abs(LOscillator.Next(0) - 0.1) < 1E-12),
      'Invalid last multiplier preserves every partial phase');
  finally
    LOscillator.Free;
  end;
  SetLength(LPartials, 2);
  LPartials[0].Gain := 0.7;
  LPartials[1].Ratio := 40;
  LOscillator := TAdditiveOscillator.Create(32768, LPartials);
  LReference := TAdditiveOscillator.Create(32768, LPartials);
  try
    for LFrame := 0 to 16 do
    begin
      LExpected := 0.7 * Sin(2 * Pi * 1024 * LFrame / 32768);
      LActual := LOscillator.Next(1024);
      Check(Abs(LActual - LExpected) < 1E-12, 'Out-of-band partial omitted');
      Check(LActual = LReference.Next(1024), 'Additive replay');
    end;
    Check(LOscillator.OmittedPartials = 1, 'Omission report');
    LRejected := False;
    try
      LOscillator.Next(-1);
    except
      on EAudio do
      begin
        LRejected := True;
      end;
    end;
    Check(LRejected, 'Invalid additive frequency rejects');
    LExpected := 0.7 * Sin(2 * Pi * 17 / 32) -
      0.2 * Sin(2 * Pi * Frac(17 * 1.25));
    Check(Abs(LOscillator.Next(100) - LExpected) < 1E-12,
      'Omitted partial phase advances before re-entry');
    Check(Abs(LReference.Next(100) - LExpected) < 1E-12, 'Failure preserves additive state');
  finally
    LReference.Free;
    LOscillator.Free;
  end;
end;

{ Independent integer-order Bessel power series. }
function BesselSeries(const AOrder: Integer; const AArgument: Double = 1): Double;
var
  LTerm: Double;
  LIndex: Integer;
begin
  LTerm := 1;
  for LIndex := 1 to AOrder do
  begin
    LTerm := LTerm * AArgument * 0.5 / LIndex;
  end;
  Result := LTerm;
  for LIndex := 1 to 18 do
  begin
    LTerm := -LTerm * Sqr(AArgument) * 0.25 / (LIndex * (LIndex + AOrder));
    Result := Result + LTerm;
  end;
end;

procedure CheckModulation;
const
  CFrames = 8192;
var
  LFm: TFmOscillator;
  LReference: TPhaseOscillator;
  LSamples: array of Double;
  LFrame: Integer;
  LOrder: Integer;
  LSide: Integer;
  LBin: Integer;
  LSin: Double;
  LCos: Double;
  LAmplitude: Double;
  LExpected: Double;
  LRejected: Boolean;
begin
  LFm := TFmOscillator.Create(32768);
  LReference := TPhaseOscillator.Create(32768);
  try
    LFm.Reset(0, 0.25);
    for LFrame := 0 to 255 do
    begin
      Check(Abs(LFm.NextFm(100, 0, -200) - LReference.Next(-100)) < 1E-12,
        'True FM integrates constant negative instantaneous frequency');
    end;
    LFm.Reset;
    LReference.Reset;
    for LFrame := 0 to 255 do
    begin
      Check(LFm.NextPm(4000, 400, 0) = LReference.Next(4000), 'Zero-index PM carrier identity');
    end;
    LFm.Reset;
    SetLength(LSamples, CFrames);
    for LFrame := 0 to CFrames - 1 do
    begin
      LSamples[LFrame] := LFm.NextPm(4000, 400, 1);
    end;
    for LOrder := 0 to 3 do
    begin
      for LSide := -1 to 1 do
      begin
        if (LSide = 0) or ((LOrder = 0) and (LSide = -1)) then
        begin
          Continue;
        end;
        LBin := 1000 + LSide * LOrder * 100;
        LSin := 0;
        LCos := 0;
        for LFrame := 0 to CFrames - 1 do
        begin
          LSin := LSin + LSamples[LFrame] * Sin(2 * Pi * LBin * LFrame / CFrames);
          LCos := LCos + LSamples[LFrame] * Cos(2 * Pi * LBin * LFrame / CFrames);
        end;
        LAmplitude := 2 * Sqrt(Sqr(LSin) + Sqr(LCos)) / CFrames;
        LExpected := Abs(BesselSeries(LOrder));
        WriteLn('PM sideband order=', LSide * LOrder, ' measured=', LAmplitude:0:10,
          ' Bessel=', LExpected:0:10);
        Check(Abs(LAmplitude - LExpected) < 1E-9, 'PM analytic sideband amplitude');
      end;
    end;
    LFm.Reset;
    LRejected := False;
    try
      LFm.NextFm(10000, 500, 10000);
    except
      on EAudio do
      begin
        LRejected := True;
      end;
    end;
    Check(LRejected, 'Unsafe instantaneous FM frequency bound rejects');
    for LFrame := 0 to 255 do
    begin
      Check(LFm.NextPm(4000, 400, 1) = LSamples[LFrame], 'Rejected FM preserves both phases');
    end;
    LReference.Reset;
    Check(Abs(LReference.Next(0, Pi / 2) - 1) < 1E-12, 'External phase modulation');
    Check(LReference.Next(0) = 0, 'Phase offset does not mutate stored phase');
  finally
    LReference.Free;
    LFm.Free;
  end;
end;

procedure CheckFilterAndRenderer;
var
  LFilter: TOnePoleFilter;
  LState: Double;
  LExpected: Double;
  LCurve: TAutomationCurve;
  LFrequency: TAutomationCurve;
  LGain: TAutomationCurve;
  LPan: TAutomationCurve;
  LTones: TFrameTones;
  LClip: TAudioClip;
  LReplay: TAudioClip;
  LFrame: Integer;
  LRejected: Boolean;
begin
  LFilter := TOnePoleFilter.Create(8000, 1000);
  try
    LState := LFilter.Process(1);
    LFilter.SetCutoff(500);
    LExpected := LState * Exp(-2 * Pi * 500 / 8000);
    Check(Abs(LFilter.Process(0) - LExpected) < 1E-12, 'Cutoff change retains filter history');
    LRejected := False;
    try
      LFilter.SetCutoff(4000);
    except
      on EAudio do
      begin
        LRejected := True;
      end;
    end;
    Check(LRejected, 'Invalid cutoff rejects');
    Check(Abs(LFilter.Process(0) - LExpected * Exp(-2 * Pi * 500 / 8000)) < 1E-12,
      'Rejected cutoff preserves coefficient and history');
  finally
    LFilter.Free;
  end;
  LCurve := Curve(600, 160, 1000, atExponential);
  LFrequency := Curve(125, 42, 600, atExponential);
  LGain := Curve(0, 1, 100, atHold);
  LPan := Curve(-1, 1, 500, atHold);
  try
    SetLength(LTones, 1);
    LTones[0].StartFrame := 20;
    LTones[0].GateFrames := 1200;
    LTones[0].FrequencyHz := 125;
    LTones[0].Velocity := 1;
    LTones[0].Voice := DefaultSynthVoice;
    LTones[0].Voice.Shape := wsSine;
    LTones[0].Voice.Automation.FrequencyHz := LFrequency;
    LTones[0].Voice.Automation.CutoffHz := LCurve;
    LTones[0].Voice.Automation.GainMultiplier := LGain;
    LTones[0].Voice.Automation.Pan := LPan;
    LClip := RenderFrameTones(LTones, 8000);
    try
      for LFrame := 0 to 119 do
      begin
        Check((LClip.SampleAt(LFrame, 0) = 0) and (LClip.SampleAt(LFrame, 1) = 0),
          'Automation offset is relative to note-on');
      end;
      Check(Abs(LClip.SampleAt(150, 0)) > 0.001, 'Automated voice becomes audible');
      Check(Abs(LClip.SampleAt(150, 1)) < 1E-12, 'Initial hard-left automation');
      Check(Abs(LClip.SampleAt(750, 0)) < 1E-12, 'Later hard-right automation');
      LReplay := RenderFrameTones(LTones, 8000);
      try
        for LFrame := 0 to LClip.FrameCount - 1 do
        begin
          Check((LClip.SampleAt(LFrame, 0) = LReplay.SampleAt(LFrame, 0)) and
            (LClip.SampleAt(LFrame, 1) = LReplay.SampleAt(LFrame, 1)), 'Automated render replay');
        end;
      finally
        LReplay.Free;
      end;
      LTones[0].Voice.Automation.PitchCents := Curve(19200, 19200, 1, atHold);
      try
        LRejected := False;
        try
          LClip := RenderFrameTones(LTones, 8000);
        except
          on EAudio do
          begin
            LRejected := True;
          end;
        end;
        Check(LRejected and (LClip.FrameCount > 1200), 'Combined pitch preflight preserves output');
      finally
        LTones[0].Voice.Automation.PitchCents.Free;
      end;
    finally
      LClip.Free;
    end;
    Check(LFrequency.ValueAt(0) = 125, 'Renderer borrows curves');
  finally
    LPan.Free;
    LGain.Free;
    LFrequency.Free;
    LCurve.Free;
  end;
end;

function BinAmplitude(const AClip: TAudioClip; const AFrequency: Double): Double;
var
  LFrame: Integer;
  LSin: Double;
  LCos: Double;
begin
  LSin := 0;
  LCos := 0;
  for LFrame := 2048 to 10239 do
  begin
    LSin := LSin + AClip.SampleAt(LFrame, 0) *
      Sin(2 * Pi * AFrequency * LFrame / AClip.SampleRate);
    LCos := LCos + AClip.SampleAt(LFrame, 0) *
      Cos(2 * Pi * AFrequency * LFrame / AClip.SampleRate);
  end;
  Result := 2 * Sqrt(Sqr(LSin) + Sqr(LCos)) / 8192;
end;

procedure CheckOversampledPm;
var
  LSamples: TAudioSamples;
  LOscillator: TFmOscillator;
  LRaw: TAudioClip;
  LHighRate: TAudioClip;
  LFiltered: TAudioClip;
  LFrame: Integer;
  LAliasRaw: Double;
  LAliasFiltered: Double;
  LSideband: Double;
begin
  SetLength(LSamples, 12288);
  LOscillator := TFmOscillator.Create(32768);
  try
    for LFrame := 0 to High(LSamples) do
    begin
      LSamples[LFrame] := LOscillator.NextPm(4000, 6000, 3);
    end;
  finally
    LOscillator.Free;
  end;
  LRaw := TAudioClip.Create(32768, 1, LSamples);
  try
    SetLength(LSamples, 12288 * 4);
    LOscillator := TFmOscillator.Create(131072);
    try
      for LFrame := 0 to High(LSamples) do
      begin
        LSamples[LFrame] := LOscillator.NextPm(4000, 6000, 3);
      end;
    finally
      LOscillator.Free;
    end;
    LHighRate := TAudioClip.Create(131072, 1, LSamples);
    try
      LFiltered := ResampleClip(LHighRate, 32768);
      try
        LAliasRaw := BinAmplitude(LRaw, 10768);
        LAliasFiltered := BinAmplitude(LFiltered, 10768);
        LSideband := BinAmplitude(LFiltered, 10000);
        WriteLn('PM 22000->10768 Hz alias amplitude raw=', LAliasRaw:0:10,
          ' 4x_sinc=', LAliasFiltered:0:10,
          ' reduction_db=', (20 * Log10(LAliasRaw / LAliasFiltered)):0:3);
        Check(LAliasRaw > 0.3, 'Wide PM fixture excites the selected alias');
        Check(LAliasFiltered < 0.00001, 'Oversampled PM suppresses selected folded sideband');
        Check(Abs(LSideband - BesselSeries(1, 3)) < 0.00001,
          'Oversampled PM retains desired J1(3) sideband');
      finally
        LFiltered.Free;
      end;
    finally
      LHighRate.Free;
    end;
  finally
    LRaw.Free;
  end;
end;

begin
  try
    CheckCurves;
    CheckAdditive;
    CheckModulation;
    CheckFilterAndRenderer;
    CheckOversampledPm;
    WriteLn('Automation, additive and modulation checks passed');
  except
    on LException: Exception do
    begin
      WriteLn(StdErr, LException.ClassName, ': ', LException.Message);
      Halt(1);
    end;
  end;
end.
