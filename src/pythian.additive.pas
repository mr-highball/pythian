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
unit pythian.additive;

{$mode delphi}
{$H+}

interface

const
  AdditiveVersion = 1;
  MaximumAdditivePartials = 128;

type
  TAdditivePartial = record
    Ratio: Double;
    Gain: Double;
    PhaseCycles: Double;
  end;
  TAdditivePartials = array of TAdditivePartial;

  { Owns copied partials and phase state. Partials at/above Nyquist are omitted
    from output, but all phases advance. No normalization or hard clipping. }
  TAdditiveOscillator = class
  strict private
    FSampleRate: Integer;
    FPartials: TAdditivePartials;
    FPhases: array of Double;
    FOmittedPartials: Integer;
  public
    constructor Create(const ASampleRate: Integer; const APartials: TAdditivePartials);
    procedure Reset;
    function Next(const AFundamentalHz: Double): Double; overload;
    { Optional per-partial amplitude modulation. Empty means unity; otherwise
      the array must match the partial count. Validated before any phase advances. }
    function Next(const AFundamentalHz: Double;
      const AGainMultipliers: array of Double): Double; overload;
    property OmittedPartials: Integer read FOmittedPartials;
  end;

implementation

uses
  Math,
  pythian.audio;

constructor TAdditiveOscillator.Create(const ASampleRate: Integer;
  const APartials: TAdditivePartials);
var
  LIndex: Integer;
begin
  inherited Create;
  ValidateAudioFormat(ASampleRate, 1);
  if (Length(APartials) < 1) or (Length(APartials) > MaximumAdditivePartials) then
  begin
    raise EAudio.Create('Additive synthesis requires 1..128 partials');
  end;
  for LIndex := 0 to High(APartials) do
  begin
    RequireFinite(APartials[LIndex].Ratio, 'Partial ratio');
    RequireFinite(APartials[LIndex].Gain, 'Partial gain');
    RequireFinite(APartials[LIndex].PhaseCycles, 'Partial phase');
    if (APartials[LIndex].Ratio < 0) or (APartials[LIndex].Ratio > 256) or
      (Abs(APartials[LIndex].Gain) > 16) or (APartials[LIndex].PhaseCycles < 0) or
      (APartials[LIndex].PhaseCycles >= 1) then
    begin
      raise EAudio.Create('Additive partial outside ratio/gain/phase bounds');
    end;
  end;
  FSampleRate := ASampleRate;
  FPartials := Copy(APartials);
  SetLength(FPhases, Length(FPartials));
  Reset;
end;

procedure TAdditiveOscillator.Reset;
var
  LIndex: Integer;
begin
  for LIndex := 0 to High(FPhases) do
  begin
    FPhases[LIndex] := FPartials[LIndex].PhaseCycles;
  end;
  FOmittedPartials := 0;
end;

function TAdditiveOscillator.Next(const AFundamentalHz: Double): Double;
begin
  Result := Next(AFundamentalHz, []);
end;

function TAdditiveOscillator.Next(const AFundamentalHz: Double;
  const AGainMultipliers: array of Double): Double;
var
  LIndex: Integer;
  LFrequency: Double;
  LGain: Double;
begin
  RequireFinite(AFundamentalHz, 'Additive fundamental');
  if (AFundamentalHz < 0) or (AFundamentalHz >= FSampleRate * 0.5) then
  begin
    raise EAudio.Create('Additive fundamental must be nonnegative and below Nyquist');
  end;
  if (Length(AGainMultipliers) <> 0) and
    (Length(AGainMultipliers) <> Length(FPartials)) then
  begin
    raise EAudio.Create('Additive modulation must match the partial count');
  end;
  for LIndex := 0 to High(AGainMultipliers) do
  begin
    RequireFinite(AGainMultipliers[LIndex], 'Partial amplitude modulation');
    if Abs(AGainMultipliers[LIndex]) > 16 then
    begin
      raise EAudio.Create('Partial amplitude multiplier magnitude must be at most 16');
    end;
  end;
  Result := 0;
  FOmittedPartials := 0;
  for LIndex := 0 to High(FPartials) do
  begin
    LFrequency := AFundamentalHz * FPartials[LIndex].Ratio;
    if LFrequency < FSampleRate * 0.5 then
    begin
      LGain := FPartials[LIndex].Gain;
      if Length(AGainMultipliers) <> 0 then
      begin
        LGain := LGain * AGainMultipliers[LIndex];
      end;
      Result := Result + LGain * Sin(2 * Pi * FPhases[LIndex]);
    end
    else
    begin
      Inc(FOmittedPartials);
    end;
    FPhases[LIndex] := Frac(FPhases[LIndex] + LFrequency / FSampleRate);
  end;
end;

end.
