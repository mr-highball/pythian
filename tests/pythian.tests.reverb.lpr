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

program pythian_tests_reverb;

{$mode delphi}
{$H+}

uses
  SysUtils,
  Math,
  pythian.audio,
  pythian.effects,
  pythian.reverb;

type
  TReferenceSignal = array[0..2047] of Double;

procedure Check(const AValue: Boolean; const AMessage: String);
begin
  if not AValue then
  begin
    raise Exception.Create(AMessage);
  end;
end;

function Past(const AValues: TReferenceSignal; const AFrame: Integer): Double;
begin
  if AFrame < 0 then
  begin
    Result := 0;
  end
  else
  begin
    Result := AValues[AFrame];
  end;
end;

procedure ReferenceCheck;
var
  LSettings: TReverbSettings;
  LEffect: TReverbEffect;
  LInput: array[0..1] of TReferenceSignal;
  LComb: array[0..1, 0..3] of TReferenceSignal;
  LStages: array[0..1, 0..2] of TReferenceSignal;
  LFeedback: Double;
  LExpected: Double;
  LOutput: array[0..1] of Double;
  LError: Double;
  LChannel: Integer;
  LIndex: Integer;
  LFrame: Integer;
  LDelay: Integer;
begin
  FillChar(LInput, SizeOf(LInput), 0);
  FillChar(LComb, SizeOf(LComb), 0);
  FillChar(LStages, SizeOf(LStages), 0);
  LSettings := DefaultReverbSettings(1000);
  LSettings.DecaySeconds := 0.25;
  LSettings.Damping := 0.43;
  LSettings.Diffusion := -0.61;
  LSettings.Width := 0.37;
  LSettings.DryGain := 0.4;
  LSettings.WetGain := 0.7;
  for LFrame := 0 to 250 do
  begin
    LInput[0, LFrame] := 0.3 * Sin(LFrame * 0.13);
    LInput[1, LFrame] := 0.2 * Cos(LFrame * 0.37);
  end;
  LEffect := TReverbEffect.Create(1000, LSettings);
  try
    LError := 0;
    for LFrame := 0 to 2047 do
    begin
      for LChannel := 0 to 1 do
      begin
        for LIndex := 0 to 3 do
        begin
          LDelay := LSettings.CombFrames[LChannel, LIndex];
          LFeedback := Exp(-3 * Ln(10) * LDelay / (1000 * LSettings.DecaySeconds));
          { Independent transfer-function recurrence: no circular delay or
            separately stored damping state from the implementation. }
          LComb[LChannel, LIndex, LFrame] :=
            LSettings.Damping * Past(LComb[LChannel, LIndex], LFrame - 1) +
            Past(LInput[LChannel], LFrame - LDelay) -
            LSettings.Damping * Past(LInput[LChannel], LFrame - LDelay - 1) +
            LFeedback * (1 - LSettings.Damping) *
              Past(LComb[LChannel, LIndex], LFrame - LDelay);
          LStages[LChannel, 0, LFrame] := LStages[LChannel, 0, LFrame] +
            LComb[LChannel, LIndex, LFrame] / 4;
        end;
        for LIndex := 0 to 1 do
        begin
          LDelay := LSettings.DiffuserFrames[LChannel, LIndex];
          LStages[LChannel, LIndex + 1, LFrame] :=
            -LSettings.Diffusion * LStages[LChannel, LIndex, LFrame] +
            Past(LStages[LChannel, LIndex], LFrame - LDelay) +
            LSettings.Diffusion * Past(LStages[LChannel, LIndex + 1], LFrame - LDelay);
        end;
      end;
      LEffect.Process(LInput[0, LFrame], LInput[1, LFrame], LOutput[0], LOutput[1]);
      for LChannel := 0 to 1 do
      begin
        LExpected := LSettings.DryGain * LInput[LChannel, LFrame] +
          LSettings.WetGain * ((1 + LSettings.Width) / 2 * LStages[LChannel, 2, LFrame] +
          (1 - LSettings.Width) / 2 * LStages[1 - LChannel, 2, LFrame]);
        LError := Max(LError, Abs(LExpected - LOutput[LChannel]));
      end;
    end;
    Check(LError < 1e-12, 'Independent transfer-function recurrence');
    WriteLn('Full stereo recurrence maximum error: ', LError);
  finally
    LEffect.Free;
  end;
end;

procedure ImpulseCheck;
var
  LSettings: TReverbSettings;
  LEffect: TReverbEffect;
  LFrame: Integer;
  LChannel: Integer;
  LIndex: Integer;
  LLeft: Double;
  LRight: Double;
  LExpected: Double;
begin
  LSettings := DefaultReverbSettings(1000);
  for LChannel := 0 to 1 do
  begin
    for LIndex := 0 to 3 do
    begin
      LSettings.CombFrames[LChannel, LIndex] := 10;
    end;
    LSettings.DiffuserFrames[LChannel, 0] := 3;
    LSettings.DiffuserFrames[LChannel, 1] := 2;
  end;
  LSettings.DecaySeconds := 0.1;
  LSettings.Damping := 0;
  LSettings.Diffusion := 0;
  LSettings.DryGain := 0;
  LSettings.WetGain := 1;
  LEffect := TReverbEffect.Create(1000, LSettings);
  try
    for LFrame := 0 to 125 do
    begin
      LLeft := 0;
      if LFrame = 0 then
      begin
        LLeft := 1;
      end;
      LEffect.Process(LLeft, 0, LLeft, LRight);
      LExpected := 0;
      if (LFrame >= 15) and ((LFrame - 15) mod 10 = 0) then
      begin
        LExpected := Power(10, -3 * ((LFrame - 15) / 100));
      end;
      Check(Abs(LLeft - LExpected) < 1e-13, 'Analytic echo timing and decay');
      Check(LRight = 0, 'Full-width channels have independent excitation');
      if LFrame = 115 then
      begin
        Check(Abs(LLeft - 0.001) < 1e-13, 'Comb decays 60 dB in declared 100 ms');
      end;
    end;
    LEffect.Reset;
    for LFrame := 0 to 125 do
    begin
      LEffect.Process(0, 0, LLeft, LRight);
      Check((LLeft = 0) and (LRight = 0), 'Reset clears every delayed tail');
    end;
  finally
    LEffect.Free;
  end;
end;

procedure FailureCheck;
var
  LSettings: TReverbSettings;
  LEffect: TReverbEffect;
  LReference: TReverbEffect;
  LLeft: Double;
  LRight: Double;
  LRefLeft: Double;
  LRefRight: Double;
  LRejected: Boolean;
  LIndex: Integer;
begin
  LSettings := DefaultReverbSettings(1000);
  LSettings.DryGain := 16;
  LEffect := TReverbEffect.Create(1000, LSettings);
  LReference := TReverbEffect.Create(1000, LSettings);
  try
    LSettings.CombFrames[0, 0] := 0;
    LSettings.WetGain := 0;
    LLeft := 12;
    LRight := 34;
    LRejected := False;
    try
      LEffect.Process(0.1, 1e100, LLeft, LRight);
    except
      on EAudio do
      begin
        LRejected := True;
      end;
    end;
    Check(LRejected and (LLeft = 12) and (LRight = 34), 'Late right failure preserves outputs');
    for LIndex := 0 to 500 do
    begin
      LEffect.Process(0.1 * Sin(LIndex), -0.2 * Cos(LIndex), LLeft, LRight);
      LReference.Process(0.1 * Sin(LIndex), -0.2 * Cos(LIndex), LRefLeft, LRefRight);
      Check((LLeft = LRefLeft) and (LRight = LRefRight),
        'Failure preserves both histories; settings are copied');
    end;
  finally
    LReference.Free;
    LEffect.Free;
  end;
  LRejected := False;
  try
    LEffect := TReverbEffect.Create(1000, LSettings);
    LEffect.Free;
  except
    on EAudio do
    begin
      LRejected := True;
    end;
  end;
  Check(LRejected, 'Invalid delay rejects before use');
end;

function NewChain(const ASettings: TReverbSettings): TEffectChain;
var
  LEffect: TReverbEffect;
begin
  Result := TEffectChain.Create(1000);
  try
    LEffect := TReverbEffect.Create(1000, ASettings);
    try
      Result.Add(LEffect);
    except
      LEffect.Free;
      raise;
    end;
  except
    Result.Free;
    raise;
  end;
end;

procedure PartitionCheck;
var
  LSettings: TReverbSettings;
  LSamples: TAudioSamples;
  LWhole: TAudioClip;
  LFirst: TAudioClip;
  LSecond: TAudioClip;
  LExpected: TAudioClip;
  LPartA: TAudioClip;
  LPartB: TAudioClip;
  LChainA: TEffectChain;
  LChainB: TEffectChain;
  LIndex: Integer;
  LChannel: Integer;
begin
  LWhole := nil;
  LFirst := nil;
  LSecond := nil;
  LExpected := nil;
  LPartA := nil;
  LPartB := nil;
  LChainA := nil;
  LChainB := nil;
  try
    SetLength(LSamples, 201 * 2);
    for LIndex := 0 to High(LSamples) do
    begin
      LSamples[LIndex] := 0.1 * Sin(LIndex * 0.7);
    end;
    LWhole := TAudioClip.Create(1000, 2, LSamples);
    LFirst := TAudioClip.Create(1000, 2, Copy(LSamples, 0, 74));
    LSecond := TAudioClip.Create(1000, 2, Copy(LSamples, 74, Length(LSamples) - 74));
    LSettings := DefaultReverbSettings(1000);
    LSettings.Width := 0;
    LSettings.DryGain := 0;
    LChainA := NewChain(LSettings);
    LChainB := NewChain(LSettings);
    LExpected := RenderEffectClip(LWhole, LChainA, 150);
    LPartA := RenderEffectClip(LFirst, LChainB);
    LPartB := RenderEffectClip(LSecond, LChainB, 150);
    for LIndex := 0 to LExpected.FrameCount - 1 do
    begin
      Check(LExpected.SampleAt(LIndex, 0) = LExpected.SampleAt(LIndex, 1),
        'Zero width produces equal wet channels');
      for LChannel := 0 to 1 do
      begin
        if LIndex < 37 then
        begin
          Check(LExpected.SampleAt(LIndex, LChannel) = LPartA.SampleAt(LIndex, LChannel),
            'First partition parity');
        end
        else
        begin
          Check(LExpected.SampleAt(LIndex, LChannel) = LPartB.SampleAt(LIndex - 37, LChannel),
            'Second partition and tail parity');
        end;
      end;
    end;
  finally
    LChainB.Free;
    LChainA.Free;
    LPartB.Free;
    LPartA.Free;
    LExpected.Free;
    LSecond.Free;
    LFirst.Free;
    LWhole.Free;
  end;
end;

begin
  try
    ReferenceCheck;
    ImpulseCheck;
    FailureCheck;
    PartitionCheck;
    WriteLn('Reverb analytic decay, stereo, failure, reset and partition checks pass');
  except
    on LException: Exception do
    begin
      WriteLn(StdErr, LException.ClassName, ': ', LException.Message);
      Halt(1);
    end;
  end;
end.
