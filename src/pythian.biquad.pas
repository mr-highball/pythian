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
unit pythian.biquad;

{$mode delphi}
{$H+}

interface

const
  BiquadVersion = 1;
  MaximumBiquadMagnitude = 1E100;
  MinimumBiquadFrequencyRatio = 1E-5;

type
  TBiquadKind = (bkLowPass, bkHighPass, bkBandPass, bkNotch, bkAllPass,
    bkPeak, bkLowShelf, bkHighShelf);
  TBiquadSettings = record
    Kind: TBiquadKind;
    FrequencyHz: Double;
    Q: Double;
    GainDb: Double;
  end;
  TBiquadCoefficients = record
    B0: Double;
    B1: Double;
    B2: Double;
    A1: Double;
    A2: Double;
  end;
  TBiquadState = record
    X1: Double;
    X2: Double;
    Y1: Double;
    Y2: Double;
  end;

  TBiquadFilter = class
  strict private
    FSampleRate: Integer;
    FChannels: Integer;
    FSettings: TBiquadSettings;
    FCoefficients: TBiquadCoefficients;
    FLeft: TBiquadState;
    FRight: TBiquadState;
  public
    constructor Create(const ASampleRate: Integer; const ASettings: TBiquadSettings;
      const AChannels: Integer = 1);
    procedure Reset;
    { Changes coefficients while retaining delay history. Failed changes preserve both. }
    procedure SetSettings(const ASettings: TBiquadSettings);
    procedure SetFrequency(const AFrequencyHz: Double);
    function Process(const AInput: Double): Double;
    { Both channels validate and compute before either history is committed. }
    procedure ProcessStereo(const ALeft, ARight: Double; out AOutputLeft, AOutputRight: Double);
    property Coefficients: TBiquadCoefficients read FCoefficients;
  end;

function DefaultBiquadSettings: TBiquadSettings;
function DesignBiquad(const ASampleRate: Integer;
  const ASettings: TBiquadSettings): TBiquadCoefficients;

implementation

uses
  Math,
  pythian.audio;

function DefaultBiquadSettings: TBiquadSettings;
begin
  Result.Kind := bkLowPass;
  Result.FrequencyHz := 1800;
  Result.Q := Sqrt(0.5);
  Result.GainDb := 0;
end;

function DesignBiquad(const ASampleRate: Integer;
  const ASettings: TBiquadSettings): TBiquadCoefficients;
var
  LW: Double;
  LCos: Double;
  LSin: Double;
  LAlpha: Double;
  LA: Double;
  LBeta: Double;
  LA0: Double;
begin
  ValidateAudioFormat(ASampleRate, 1);
  RequireFinite(ASettings.FrequencyHz, 'Biquad frequency');
  RequireFinite(ASettings.Q, 'Biquad Q');
  RequireFinite(ASettings.GainDb, 'Biquad gain');
  if not (ASettings.Kind in [bkLowPass, bkHighPass, bkBandPass, bkNotch, bkAllPass,
    bkPeak, bkLowShelf, bkHighShelf]) or
    (ASettings.FrequencyHz < ASampleRate * MinimumBiquadFrequencyRatio) or
    (ASettings.FrequencyHz > ASampleRate * (0.5 - MinimumBiquadFrequencyRatio)) or
    (ASettings.Q < 0.05) or (ASettings.Q > 100) or (Abs(ASettings.GainDb) > 48) then
  begin
    raise EAudio.Create('Biquad settings outside frequency/Q/gain bounds');
  end;
  LW := 2 * Pi * ASettings.FrequencyHz / ASampleRate;
  LCos := Cos(LW);
  LSin := Sin(LW);
  LAlpha := LSin / (2 * ASettings.Q);
  LA := Power(10, ASettings.GainDb / 40);
  LA0 := 1 + LAlpha;
  Result.A1 := -2 * LCos;
  Result.A2 := 1 - LAlpha;
  case ASettings.Kind of
    bkLowPass:
    begin
      Result.B0 := (1 - LCos) / 2;
      Result.B1 := 1 - LCos;
      Result.B2 := Result.B0;
    end;
    bkHighPass:
    begin
      Result.B0 := (1 + LCos) / 2;
      Result.B1 := -(1 + LCos);
      Result.B2 := Result.B0;
    end;
    bkBandPass:
    begin
      { Constant unity gain at center. }
      Result.B0 := LAlpha;
      Result.B1 := 0;
      Result.B2 := -LAlpha;
    end;
    bkNotch:
    begin
      Result.B0 := 1;
      Result.B1 := -2 * LCos;
      Result.B2 := 1;
    end;
    bkAllPass:
    begin
      Result.B0 := 1 - LAlpha;
      Result.B1 := -2 * LCos;
      Result.B2 := 1 + LAlpha;
    end;
    bkPeak:
    begin
      Result.B0 := 1 + LAlpha * LA;
      Result.B1 := -2 * LCos;
      Result.B2 := 1 - LAlpha * LA;
      LA0 := 1 + LAlpha / LA;
      Result.A2 := 1 - LAlpha / LA;
    end;
    bkLowShelf, bkHighShelf:
    begin
      { Shelf slope S=1. Q is admitted but does not control shelf slope. }
      LAlpha := LSin / Sqrt(2);
      LBeta := 2 * Sqrt(LA) * LAlpha;
      if ASettings.Kind = bkLowShelf then
      begin
        Result.B0 := LA * ((LA + 1) - (LA - 1) * LCos + LBeta);
        Result.B1 := 2 * LA * ((LA - 1) - (LA + 1) * LCos);
        Result.B2 := LA * ((LA + 1) - (LA - 1) * LCos - LBeta);
        LA0 := (LA + 1) + (LA - 1) * LCos + LBeta;
        Result.A1 := -2 * ((LA - 1) + (LA + 1) * LCos);
        Result.A2 := (LA + 1) + (LA - 1) * LCos - LBeta;
      end
      else
      begin
        Result.B0 := LA * ((LA + 1) + (LA - 1) * LCos + LBeta);
        Result.B1 := -2 * LA * ((LA - 1) + (LA + 1) * LCos);
        Result.B2 := LA * ((LA + 1) + (LA - 1) * LCos - LBeta);
        LA0 := (LA + 1) - (LA - 1) * LCos + LBeta;
        Result.A1 := 2 * ((LA - 1) - (LA + 1) * LCos);
        Result.A2 := (LA + 1) - (LA - 1) * LCos - LBeta;
      end;
    end;
  end;
  Result.B0 := Result.B0 / LA0;
  Result.B1 := Result.B1 / LA0;
  Result.B2 := Result.B2 / LA0;
  Result.A1 := Result.A1 / LA0;
  Result.A2 := Result.A2 / LA0;
  { Jury/Schur conditions for a real second-order denominator. }
  if (1 + Result.A1 + Result.A2 <= 0) or (1 - Result.A1 + Result.A2 <= 0) or
    (1 - Result.A2 <= 0) then
  begin
    raise EAudio.Create('Biquad coefficients lack stable finite-precision poles');
  end;
end;

procedure CheckMagnitude(const AValue: Double);
begin
  RequireFinite(AValue, 'Biquad sample/state');
  if Abs(AValue) > MaximumBiquadMagnitude then
  begin
    raise EAudio.Create('Biquad sample/state exceeds magnitude bound');
  end;
end;

function Evaluate(const AInput: Double; const AState: TBiquadState;
  const ACoefficients: TBiquadCoefficients; out ANext: TBiquadState): Double;
begin
  CheckMagnitude(AInput);
  Result := ACoefficients.B0 * AInput + ACoefficients.B1 * AState.X1 +
    ACoefficients.B2 * AState.X2 - ACoefficients.A1 * AState.Y1 -
    ACoefficients.A2 * AState.Y2;
  CheckMagnitude(Result);
  ANext.X1 := AInput;
  ANext.X2 := AState.X1;
  ANext.Y1 := Result;
  ANext.Y2 := AState.Y1;
end;

constructor TBiquadFilter.Create(const ASampleRate: Integer;
  const ASettings: TBiquadSettings; const AChannels: Integer);
begin
  inherited Create;
  ValidateAudioFormat(ASampleRate, AChannels);
  FSampleRate := ASampleRate;
  FChannels := AChannels;
  SetSettings(ASettings);
  Reset;
end;

procedure TBiquadFilter.Reset;
begin
  FLeft := Default(TBiquadState);
  FRight := Default(TBiquadState);
end;

procedure TBiquadFilter.SetSettings(const ASettings: TBiquadSettings);
var
  LCandidate: TBiquadCoefficients;
begin
  LCandidate := DesignBiquad(FSampleRate, ASettings);
  FCoefficients := LCandidate;
  FSettings := ASettings;
end;

procedure TBiquadFilter.SetFrequency(const AFrequencyHz: Double);
var
  LCandidate: TBiquadSettings;
begin
  LCandidate := FSettings;
  LCandidate.FrequencyHz := AFrequencyHz;
  SetSettings(LCandidate);
end;

function TBiquadFilter.Process(const AInput: Double): Double;
var
  LNext: TBiquadState;
begin
  if FChannels <> 1 then
  begin
    raise EAudio.Create('Use stereo processing for a stereo biquad');
  end;
  Result := Evaluate(AInput, FLeft, FCoefficients, LNext);
  FLeft := LNext;
end;

procedure TBiquadFilter.ProcessStereo(const ALeft, ARight: Double;
  out AOutputLeft, AOutputRight: Double);
var
  LNextLeft: TBiquadState;
  LNextRight: TBiquadState;
  LLeft: Double;
  LRight: Double;
begin
  if FChannels <> 2 then
  begin
    raise EAudio.Create('Use mono processing for a mono biquad');
  end;
  LLeft := Evaluate(ALeft, FLeft, FCoefficients, LNextLeft);
  LRight := Evaluate(ARight, FRight, FCoefficients, LNextRight);
  FLeft := LNextLeft;
  FRight := LNextRight;
  AOutputLeft := LLeft;
  AOutputRight := LRight;
end;

end.

