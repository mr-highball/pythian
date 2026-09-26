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
program pythian_tests_delay_modulated;

{$mode delphi}
{$H+}

uses
  SysUtils,
  Math,
  pythian.audio,
  pythian.automation,
  pythian.delay,
  pythian.delay.modulated,
  pythian.effects;

procedure Check(const AValue: Boolean; const AMessage: String);
begin
  if not AValue then
  begin
    raise Exception.Create(AMessage);
  end;
end;

procedure CheckLine;
var
  LLine: TFractionalDelayLine;
  LDelay: TDelay;
  LDistance: Double;
  LExpected: Double;
  LFraction: Double;
  LInput: Double;
  LHistory: array[0..63] of Double;
  LWhole: Integer;
  LRejected: Boolean;
  I: Integer;
  J: Integer;
begin
  LLine := TFractionalDelayLine.Create(4);
  try
    for I := 0 to 31 do
    begin
      for J := 0 to 2 do
      begin
        case J of
          0: LDistance := 1;
          1: LDistance := 2.25;
          2: LDistance := 4;
        end;
        LWhole := Trunc(LDistance);
        LFraction := LDistance - LWhole;
        LExpected := (1 - LFraction) * Max(0, I - LWhole + 1) +
          LFraction * Max(0, I - LWhole);
        Check(LLine.Read(LDistance) = LExpected, 'Read-before-push ramp, fractional tap and ring wrap');
        Check(LLine.Read(LDistance) = LExpected, 'Repeated reads do not advance history');
      end;
      LLine.Push(I + 1);
    end;
    LRejected := False;
    try
      LLine.Push(Infinity);
    except
      on EAudio do
      begin
        LRejected := True;
      end;
    end;
    Check(LRejected and (LLine.Read(1) = 32), 'Rejected push preserves history');
    LRejected := False;
    try
      LLine.Read(0.5);
    except
      on EAudio do
      begin
        LRejected := True;
      end;
    end;
    Check(LRejected and (LLine.Read(4) = 29), 'Invalid delay preserves history');
    LLine.Reset;
    Check(LLine.Read(2.5) = 0, 'Fractional line reset clears all history');
  finally
    LLine.Free;
  end;
  LDelay := TDelay.Create(3, -0.25, 0.5);
  try
    FillChar(LHistory, SizeOf(LHistory), 0);
    for I := 0 to High(LHistory) do
    begin
      LInput := Sin(I * 0.2) * 0.1;
      LExpected := 0;
      if I >= 3 then
      begin
        LExpected := LHistory[I - 3];
      end;
      LHistory[I] := LInput - 0.25 * LExpected;
      LExpected := LInput + 0.5 * LExpected;
      Check(LDelay.Process(LInput) = LExpected,
        'Legacy delay matches independent full-history recurrence exactly');
    end;
  finally
    LDelay.Free;
  end;
end;

function Settings: TModulatedDelaySettings;
begin
  Result.MaximumDelayFrames := 4;
  Result.Feedback := 0.35;
  Result.DryGain := 0.6;
  Result.WetGain := 0.4;
end;

function Past(const AHistory: array of Double; const AIndex: Integer): Double;
begin
  if AIndex < 0 then
  begin
    Exit(0);
  end;
  Result := AHistory[AIndex];
end;

function Delayed(const AHistory: array of Double; const AFrame: Integer;
  const ADistance: Double): Double;
var
  LWhole: Integer;
  LFraction: Double;
begin
  LWhole := Trunc(ADistance);
  LFraction := ADistance - LWhole;
  Result := (1 - LFraction) * Past(AHistory, AFrame - LWhole) +
    LFraction * Past(AHistory, AFrame - LWhole - 1);
end;

procedure CheckEffect;
var
  LBase: TAutomationCurve;
  LLeft: TAutomationCurve;
  LRight: TAutomationCurve;
  LEffect: TModulatedDelayEffect;
  LSettings: TModulatedDelaySettings;
  LHistoryLeft: array[0..255] of Double;
  LHistoryRight: array[0..255] of Double;
  LInputLeft: Double;
  LInputRight: Double;
  LDelayedLeft: Double;
  LDelayedRight: Double;
  LActualLeft: Double;
  LActualRight: Double;
  LError: Double;
  LSin: Double;
  LRejected: Boolean;
  I: Integer;
begin
  LBase := nil;
  LLeft := nil;
  LRight := nil;
  LEffect := nil;
  try
    LBase := TAutomationCurve.CreateLfo(32, alsSine);
    LLeft := TAutomationCurve.CreateAffine(LBase, 1.25, 2.5);
    LRight := TAutomationCurve.CreateAffine(LBase, -1.25, 2.5);
    LSettings := Settings;
    LEffect := TModulatedDelayEffect.Create(8000, LSettings, LLeft, LRight);
    FreeAndNil(LBase);
    FreeAndNil(LLeft);
    FreeAndNil(LRight);
    FillChar(LHistoryLeft, SizeOf(LHistoryLeft), 0);
    FillChar(LHistoryRight, SizeOf(LHistoryRight), 0);
    LError := 0;
    for I := 0 to High(LHistoryLeft) do
    begin
      LInputLeft := 0.2 * Sin(I * 0.31);
      LInputRight := 0.15 * Cos(I * 0.17);
      LSin := Sin(2 * Pi * (I mod 32) / 32);
      LDelayedLeft := Delayed(LHistoryLeft, I, 2.5 + 1.25 * LSin);
      LDelayedRight := Delayed(LHistoryRight, I, 2.5 - 1.25 * LSin);
      LHistoryLeft[I] := LInputLeft + 0.35 * LDelayedLeft;
      LHistoryRight[I] := LInputRight + 0.35 * LDelayedRight;
      LActualLeft := LInputLeft;
      LActualRight := LInputRight;
      LEffect.Process(LActualLeft, LActualRight, LActualLeft, LActualRight);
      LError := Max(LError, Abs(LActualLeft - (0.6 * LInputLeft + 0.4 * LDelayedLeft)));
      LError := Max(LError, Abs(LActualRight - (0.6 * LInputRight + 0.4 * LDelayedRight)));
    end;
    Check((LError < 1E-14) and (LEffect.ProcessedFrames = 256),
      'Moving stereo feedback delay matches independent absolute-history oracle');
    WriteLn('Maximum moving-delay reference difference: ', LError);
    FreeAndNil(LEffect);
    LBase := TAutomationCurve.CreateLfo(32, alsSine);
    LLeft := TAutomationCurve.CreateAffine(LBase, 0, 1.5);
    LSettings.DryGain := 16;
    LSettings.WetGain := 1;
    LEffect := TModulatedDelayEffect.Create(8000, LSettings, LLeft, LLeft);
    LActualLeft := 23;
    LActualRight := -29;
    LRejected := False;
    try
      LEffect.Process(0.5, 1E100, LActualLeft, LActualRight);
    except
      on EAudio do
      begin
        LRejected := True;
      end;
    end;
    Check(LRejected and (LActualLeft = 23) and (LActualRight = -29) and
      (LEffect.ProcessedFrames = 0), 'Late right output rejection preserves outputs and phase');
    LEffect.Process(0, 0, LActualLeft, LActualRight);
    Check((LActualLeft = 0) and (LActualRight = 0), 'Late rejection preserves both delay lines');
    FreeAndNil(LEffect);
    LRight := TAutomationCurve.CreateAffine(LBase, 2, 3);
    LRejected := False;
    try
      LEffect := TModulatedDelayEffect.Create(8000, LSettings, LLeft, LRight);
    except
      on EAudio do
      begin
        LRejected := True;
      end;
    end;
    Check(LRejected and (LEffect = nil), 'Future curve excursion rejects before allocation');
  finally
    LEffect.Free;
    LRight.Free;
    LLeft.Free;
    LBase.Free;
  end;
end;

procedure CheckClipContinuity;
var
  LBase: TAutomationCurve;
  LCurve: TAutomationCurve;
  LChain: TEffectChain;
  LInput: TAudioClip;
  LFirst: TAudioClip;
  LSecond: TAudioClip;
  LWhole: TAudioClip;
  LPartOne: TAudioClip;
  LPartTwo: TAudioClip;
  LReplay: TAudioClip;
  LSamples: TAudioSamples;
  I: Integer;
  J: Integer;
begin
  LBase := nil;
  LCurve := nil;
  LChain := nil;
  LInput := nil;
  LFirst := nil;
  LSecond := nil;
  LWhole := nil;
  LPartOne := nil;
  LPartTwo := nil;
  LReplay := nil;
  try
    SetLength(LSamples, 274);
    for I := 0 to High(LSamples) do
    begin
      LSamples[I] := 0.2 * Sin(I * 0.2);
    end;
    LInput := TAudioClip.Create(8000, 2, LSamples);
    LFirst := TAudioClip.Create(8000, 2, Copy(LSamples, 0, 82));
    LSecond := TAudioClip.Create(8000, 2, Copy(LSamples, 82, 192));
    LBase := TAutomationCurve.CreateLfo(32, alsTriangle);
    LCurve := TAutomationCurve.CreateAffine(LBase, 1.25, 2.5);
    LChain := TEffectChain.Create(8000);
    LChain.Add(TModulatedDelayEffect.Create(8000, Settings, LCurve, LCurve));
    FreeAndNil(LCurve);
    FreeAndNil(LBase);
    LWhole := RenderEffectClip(LInput, LChain, 32);
    LChain.Reset;
    LPartOne := RenderEffectClip(LFirst, LChain);
    LPartTwo := RenderEffectClip(LSecond, LChain, 32);
    for I := 0 to LWhole.FrameCount - 1 do
    begin
      for J := 0 to 1 do
      begin
        if I < LPartOne.FrameCount then
        begin
          Check(LWhole.SampleAt(I, J) = LPartOne.SampleAt(I, J), 'First clip preserves control clock');
        end
        else
        begin
          Check(LWhole.SampleAt(I, J) = LPartTwo.SampleAt(I - LPartOne.FrameCount, J),
            'Split clips and explicit tail retain exact effect history');
        end;
      end;
    end;
    LChain.Reset;
    LReplay := RenderEffectClip(LInput, LChain, 32);
    for I := 0 to LWhole.FrameCount - 1 do
    begin
      for J := 0 to 1 do
      begin
        Check(LWhole.SampleAt(I, J) = LReplay.SampleAt(I, J), 'Reset restores history and modulation phase');
      end;
    end;
  finally
    LReplay.Free;
    LPartTwo.Free;
    LPartOne.Free;
    LWhole.Free;
    LSecond.Free;
    LFirst.Free;
    LInput.Free;
    LChain.Free;
    LCurve.Free;
    LBase.Free;
  end;
end;

begin
  try
    CheckLine;
    CheckEffect;
    CheckClipContinuity;
    WriteLn('Fractional delay, legacy recurrence, stereo transaction, curve ownership and clip continuity passed');
  except
    on LException: Exception do
    begin
      WriteLn(StdErr, LException.ClassName, ': ', LException.Message);
      Halt(1);
    end;
  end;
end.
