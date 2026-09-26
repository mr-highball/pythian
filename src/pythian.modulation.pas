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
unit pythian.modulation;

{$mode delphi}
{$H+}

interface

const
  ModulationVersion = 1;
  MaximumPhaseOffsetRadians = 1000000;
  MaximumPmIndex = 64;

type
  { Sine phase accumulator, also usable as a bipolar LFO. Signed Hz permits
    reverse/through-zero motion. Offset affects output, not stored phase. }
  TPhaseOscillator = class
  strict private
    FSampleRate: Integer;
    FPhase: Double;
  public
    constructor Create(const ASampleRate: Integer);
    procedure Reset(const APhaseCycles: Double = 0);
    function Next(const AFrequencyHz: Double; const APhaseOffsetRadians: Double = 0): Double;
  end;

  { Two sine operators. Each method samples current phase then advances it.
    Frequency inputs are signed Hz; FM depth is Hz, PM depth is radians.
    Carrier/modulator state is shared when switching methods. }
  TFmOscillator = class
  strict private
    FSampleRate: Integer;
    FCarrierPhase: Double;
    FModulatorPhase: Double;
  public
    constructor Create(const ASampleRate: Integer);
    procedure Reset(const ACarrierPhaseCycles: Double = 0;
      const AModulatorPhaseCycles: Double = 0);
    function NextFm(const ACarrierHz, AModulatorHz, ADeviationHz: Double): Double;
    function NextPm(const ACarrierHz, AModulatorHz, AIndexRadians: Double): Double;
  end;

implementation

uses
  Math,
  pythian.audio;

procedure ValidatePhase(const APhase: Double);
begin
  RequireFinite(APhase, 'Phase');
  if (APhase < 0) or (APhase >= 1) then
  begin
    raise EAudio.Create('Initial phase must be in [0, 1) cycles');
  end;
end;

procedure ValidateFrequency(const AFrequency: Double; const ASampleRate: Integer);
begin
  RequireFinite(AFrequency, 'Modulation frequency');
  if Abs(AFrequency) >= ASampleRate * 0.5 then
  begin
    raise EAudio.Create('Signed frequency magnitude must be below Nyquist');
  end;
end;

function AdvancePhase(const APhase, AStep: Double): Double;
begin
  Result := Frac(APhase + AStep);
  if Result < 0 then
  begin
    Result := Result + 1;
  end;
end;

constructor TPhaseOscillator.Create(const ASampleRate: Integer);
begin
  inherited Create;
  ValidateAudioFormat(ASampleRate, 1);
  FSampleRate := ASampleRate;
  Reset;
end;

procedure TPhaseOscillator.Reset(const APhaseCycles: Double);
begin
  ValidatePhase(APhaseCycles);
  FPhase := APhaseCycles;
end;

function TPhaseOscillator.Next(const AFrequencyHz: Double;
  const APhaseOffsetRadians: Double): Double;
begin
  ValidateFrequency(AFrequencyHz, FSampleRate);
  RequireFinite(APhaseOffsetRadians, 'Phase offset');
  if Abs(APhaseOffsetRadians) > MaximumPhaseOffsetRadians then
  begin
    raise EAudio.Create('Phase offset exceeds one million radians');
  end;
  Result := Sin(2 * Pi * FPhase + APhaseOffsetRadians);
  FPhase := AdvancePhase(FPhase, AFrequencyHz / FSampleRate);
end;

constructor TFmOscillator.Create(const ASampleRate: Integer);
begin
  inherited Create;
  ValidateAudioFormat(ASampleRate, 1);
  FSampleRate := ASampleRate;
  Reset;
end;

procedure TFmOscillator.Reset(const ACarrierPhaseCycles, AModulatorPhaseCycles: Double);
begin
  ValidatePhase(ACarrierPhaseCycles);
  ValidatePhase(AModulatorPhaseCycles);
  FCarrierPhase := ACarrierPhaseCycles;
  FModulatorPhase := AModulatorPhaseCycles;
end;

function TFmOscillator.NextFm(const ACarrierHz, AModulatorHz,
  ADeviationHz: Double): Double;
var
  LInstantaneousHz: Double;
begin
  ValidateFrequency(ACarrierHz, FSampleRate);
  ValidateFrequency(AModulatorHz, FSampleRate);
  RequireFinite(ADeviationHz, 'FM deviation');
  if Abs(ADeviationHz) >= FSampleRate * 0.5 - Abs(ACarrierHz) then
  begin
    raise EAudio.Create('FM carrier plus deviation magnitude must remain below Nyquist');
  end;
  LInstantaneousHz := ACarrierHz + ADeviationHz * Sin(2 * Pi * FModulatorPhase);
  Result := Sin(2 * Pi * FCarrierPhase);
  FCarrierPhase := AdvancePhase(FCarrierPhase, LInstantaneousHz / FSampleRate);
  FModulatorPhase := AdvancePhase(FModulatorPhase, AModulatorHz / FSampleRate);
end;

function TFmOscillator.NextPm(const ACarrierHz, AModulatorHz,
  AIndexRadians: Double): Double;
begin
  ValidateFrequency(ACarrierHz, FSampleRate);
  ValidateFrequency(AModulatorHz, FSampleRate);
  RequireFinite(AIndexRadians, 'PM index');
  if Abs(AIndexRadians) > MaximumPmIndex then
  begin
    raise EAudio.Create('PM index magnitude must be at most 64 radians');
  end;
  Result := Sin(2 * Pi * FCarrierPhase +
    AIndexRadians * Sin(2 * Pi * FModulatorPhase));
  FCarrierPhase := AdvancePhase(FCarrierPhase, ACarrierHz / FSampleRate);
  FModulatorPhase := AdvancePhase(FModulatorPhase, AModulatorHz / FSampleRate);
end;

end.

