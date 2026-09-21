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
unit pythian.oscillator;

{$mode delphi}
{$H+}

interface

const
  FixedOscillatorVersion = 1;
  PhaseModulus = 1 shl 24;
  PhaseMask = PhaseModulus - 1;
  PhaseQuarter = PhaseModulus div 4;
  EnvelopeScale = 32767;

type
  TWaveShape = (wsSine, wsTriangle, wsSaw, wsSquare, wsNoise);
  { Polynomial correction reduces aliasing; it is not an ideal band limit. }
  TOscillatorQuality = (oqNaive, oqPolynomial);

  TOscillator = class
  strict private
    FSampleRate: Integer;
    FPhase: Double;
    FRandom: Cardinal;
    FQuality: TOscillatorQuality;
  public
    constructor Create(const ASampleRate: Integer; const ASeed: Cardinal = 731;
      const AQuality: TOscillatorQuality = oqNaive);
    procedure Reset(const ASeed: Cardinal = 731);
    function Next(const AShape: TWaveShape; const AFrequency: Double): Double;
  end;

function MidiFrequency(const APitch: Integer): Double;
function FixedPhaseIncrement(const APitch, ASampleRate: Integer): Integer;
function FixedTriangleSample(const APhase: Integer): Integer;
function FixedEnvelopeGain(const AOffset, AFrameCount,
  AAttackFrames, AReleaseFrames: Integer): Integer;

implementation

uses
  Math,
  pythian.audio;

const
  { Extracted from WFC audio v1: MIDI 0..11, Hz * 4096. }
  BaseFrequencyQ12: array[0..11] of Integer = (
    33488, 35479, 37589, 39824, 42192, 44701,
    47359, 50175, 53159, 56320, 59669, 63217
  );

function MidiFrequency(const APitch: Integer): Double;
begin
  if (APitch < 0) or (APitch > 127) then
  begin
    raise EAudio.Create('MIDI pitch must be 0..127');
  end;
  Result := 440 * Power(2, (APitch - 69) / 12);
end;

function FixedPhaseIncrement(const APitch, ASampleRate: Integer): Integer;
var
  LDenominator: Int64;
  LNumerator: Int64;
begin
  if (APitch < 0) or (APitch > 127) then
  begin
    raise EAudio.Create('MIDI pitch must be 0..127');
  end;
  ValidateAudioFormat(ASampleRate, 1);
  LDenominator := Int64(ASampleRate) * 4096;
  LNumerator := Int64(BaseFrequencyQ12[APitch mod 12]) *
    (1 shl (APitch div 12)) * PhaseModulus;
  { Reduction also permits low-rate callers without integer overflow. }
  Result := ((LNumerator + LDenominator div 2) div LDenominator) mod PhaseModulus;
end;

function FixedTriangleSample(const APhase: Integer): Integer;
var
  LPhase: Integer;
  LOffset: Integer;
  LValue: Integer;
begin
  LPhase := APhase and PhaseMask;
  LOffset := LPhase and (PhaseQuarter - 1);
  LValue := (Int64(LOffset) * EnvelopeScale) div PhaseQuarter;
  case LPhase div PhaseQuarter of
    0:
    begin
      Result := LValue;
    end;
    1:
    begin
      Result := EnvelopeScale - LValue;
    end;
    2:
    begin
      Result := -LValue;
    end;
  else
    Result := -EnvelopeScale + LValue;
  end;
end;

function FixedEnvelopeGain(const AOffset, AFrameCount,
  AAttackFrames, AReleaseFrames: Integer): Integer;
var
  LValue: Int64;
begin
  if (AOffset < 0) or (AOffset >= AFrameCount) or
    (AAttackFrames < 0) or (AReleaseFrames < 0) then
  begin
    raise EAudio.Create('Invalid fixed envelope coordinate');
  end;
  Result := EnvelopeScale;
  if AAttackFrames > 0 then
  begin
    LValue := Int64(AOffset) * EnvelopeScale div AAttackFrames;
    if LValue < Result then
    begin
      Result := LValue;
    end;
  end;
  if AReleaseFrames > 0 then
  begin
    LValue := Int64(AFrameCount - 1 - AOffset) * EnvelopeScale div AReleaseFrames;
    if LValue < Result then
    begin
      Result := LValue;
    end;
  end;
end;

constructor TOscillator.Create(const ASampleRate: Integer; const ASeed: Cardinal;
  const AQuality: TOscillatorQuality);
begin
  inherited Create;
  ValidateAudioFormat(ASampleRate, 1);
  FSampleRate := ASampleRate;
  FQuality := AQuality;
  Reset(ASeed);
end;

procedure TOscillator.Reset(const ASeed: Cardinal);
begin
  FPhase := 0;
  FRandom := ASeed;
end;

{ Two-sample polynomial step residual. Phase is in [0, 1), step in (0, 0.5). }
function StepResidual(const APhase, AStep: Double): Double;
var
  LX: Double;
begin
  Result := 0;
  if APhase < AStep then
  begin
    LX := APhase / AStep;
    Result := 2 * LX - LX * LX - 1;
  end
  else if APhase > 1 - AStep then
  begin
    LX := (APhase - 1) / AStep;
    Result := LX * LX + 2 * LX + 1;
  end;
end;

{ Integral of the step residual, expressed in cycles. Each triangle corner
  has half-slope jump +/-4. See the derivation and limits in docs/DSP.md. }
function RampResidual(const APhase, AStep: Double): Double;
var
  LX: Double;
begin
  Result := 0;
  if APhase < AStep then
  begin
    LX := 1 - APhase / AStep;
    Result := AStep * LX * LX * LX / 3;
  end
  else if APhase > 1 - AStep then
  begin
    LX := 1 + (APhase - 1) / AStep;
    Result := AStep * LX * LX * LX / 3;
  end;
end;

function TOscillator.Next(const AShape: TWaveShape; const AFrequency: Double): Double;
var
  LStep: Double;
  LHalfPhase: Double;
begin
  RequireFinite(AFrequency, 'Frequency');
  if (AFrequency < 0) or (AFrequency >= FSampleRate * 0.5) then
  begin
    raise EAudio.Create('Frequency must be nonnegative and below Nyquist');
  end;
  LStep := AFrequency / FSampleRate;
  case AShape of
    wsSine:
    begin
      Result := Sin(2 * Pi * FPhase);
    end;
    wsTriangle:
    begin
      Result := 1 - 4 * Abs(FPhase - 0.5);
    end;
    wsSaw:
    begin
      Result := 2 * FPhase - 1;
    end;
    wsSquare:
    begin
      if FPhase < 0.5 then
      begin
        Result := 1;
      end
      else
      begin
        Result := -1;
      end;
    end;
    wsNoise:
    begin
      { Phanes's explicit seed and LCG; wide arithmetic preserves checked builds. }
      FRandom := (QWord(FRandom) * 1664525 + 1013904223) and $7FFFFFFF;
      Result := FRandom / $40000000 - 1;
    end;
  end;
  if (FQuality = oqPolynomial) and (LStep > 0) then
  begin
    LHalfPhase := Frac(FPhase + 0.5);
    case AShape of
      wsSine, wsNoise:
      begin
        { No discontinuity correction for these shapes. }
      end;
      wsSaw:
      begin
        Result := Result - StepResidual(FPhase, LStep);
      end;
      wsSquare:
      begin
        Result := Result + StepResidual(FPhase, LStep) -
          StepResidual(LHalfPhase, LStep);
      end;
      wsTriangle:
      begin
        Result := Result + 4 * (RampResidual(FPhase, LStep) -
          RampResidual(LHalfPhase, LStep));
      end;
    end;
  end;
  FPhase := Frac(FPhase + LStep);
end;

end.
