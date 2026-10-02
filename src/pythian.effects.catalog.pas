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
unit pythian.effects.catalog;

{$mode delphi}
{$H+}

interface

uses
  pythian.biquad;

type
  TCatalogEffect = (ceGain, ceLowPass, ceHighPass, ceBandPass, ceNotch,
    ceAllPass, cePeak, ceLowShelf, ceHighShelf, ceCompressor, ceLimiter);
  TEffectParameter = record
    Key: String;
    Caption: String;
    Minimum: Double;
    Maximum: Double;
    DefaultValue: Double;
  end;
  TEffectParameters = array of TEffectParameter;
  TEffectDefinition = record
    Kind: TCatalogEffect;
    Key: String;
    Caption: String;
    Purpose: String;
    IsBiquad: Boolean;
    BiquadKind: TBiquadKind;
    Parameters: TEffectParameters;
  end;

{ Shared native/pas2js recipe controls for the built-in rack. The primitive DSP
  retains its wider direct API. Returned definitions own their parameter arrays;
  no JSON, DOM or service types cross this boundary. }
function EffectDefinition(const AKind: TCatalogEffect): TEffectDefinition;
function FindEffectDefinition(const AKey: String; out ADefinition: TEffectDefinition): Boolean;
function EffectParameterMaximum(const AParameter: TEffectParameter;
  const ASampleRate: Integer): Double;

implementation

uses
  Math,
  pythian.audio;

function EffectDefinition(const AKind: TCatalogEffect): TEffectDefinition;
const
  CKeys: array[TCatalogEffect] of String = ('gain', 'lowpass', 'highpass',
    'bandpass', 'notch', 'allpass', 'peak', 'lowshelf', 'highshelf',
    'compressor', 'limiter');
  CCaptions: array[TCatalogEffect] of String = ('Gain', 'Low-pass filter',
    'High-pass filter', 'Band-pass filter', 'Notch filter', 'All-pass filter',
    'Peaking EQ', 'Low shelf', 'High shelf', 'Compressor', 'Limiter');
  CPurposes: array[TCatalogEffect] of String = (
    'Make the passage louder or quieter.', 'Soften highs above the cutoff.',
    'Remove lows below the cutoff.', 'Keep a band around the chosen frequency.',
    'Cut a narrow band around the chosen frequency.',
    'Shift phase while keeping the frequency balance. Subtle on its own.',
    'Boost or cut a band around the chosen frequency.', 'Boost or cut the lows.',
    'Boost or cut the highs.', 'Reduce the difference between loud and quiet moments.',
    'Keep peaks below a chosen ceiling.');
  CFilters: array[ceLowPass..ceHighShelf] of TBiquadKind = (bkLowPass,
    bkHighPass, bkBandPass, bkNotch, bkAllPass, bkPeak, bkLowShelf, bkHighShelf);
var
  LDefinition: TEffectDefinition;
  LFrequency: Double;
  LCaption: String;

  procedure Parameter(const AKey, ACaption: String;
    const AMinimum, AMaximum, ADefault: Double);
  var
    LIndex: Integer;
  begin
    LIndex := Length(LDefinition.Parameters);
    SetLength(LDefinition.Parameters, LIndex + 1);
    LDefinition.Parameters[LIndex].Key := AKey;
    LDefinition.Parameters[LIndex].Caption := ACaption;
    LDefinition.Parameters[LIndex].Minimum := AMinimum;
    LDefinition.Parameters[LIndex].Maximum := AMaximum;
    LDefinition.Parameters[LIndex].DefaultValue := ADefault;
  end;

begin
  if not (AKind in [Low(TCatalogEffect)..High(TCatalogEffect)]) then
  begin
    raise EAudio.Create('Unsupported catalog effect');
  end;
  LDefinition.Kind := AKind;
  LDefinition.Key := CKeys[AKind];
  LDefinition.Caption := CCaptions[AKind];
  LDefinition.Purpose := CPurposes[AKind];
  LDefinition.IsBiquad := AKind in [ceLowPass..ceHighShelf];
  LDefinition.BiquadKind := bkLowPass;
  LDefinition.Parameters := nil;
  if LDefinition.IsBiquad then
  begin
    LDefinition.BiquadKind := CFilters[AKind];
    LFrequency := 1000;
    if AKind in [ceHighPass, ceLowShelf] then
    begin
      LFrequency := 80;
    end;
    LCaption := 'Frequency (Hz)';
    if AKind in [ceLowPass, ceHighPass] then
    begin
      LCaption := 'Cutoff (Hz)';
    end;
    Parameter('frequency_hz', LCaption, 20, 20000, LFrequency);
    if not (AKind in [ceLowShelf, ceHighShelf]) then
    begin
      Parameter('q', 'Resonance Q (0.1–10)', 0.1, 10, 0.707);
    end;
    if AKind in [cePeak, ceLowShelf, ceHighShelf] then
    begin
      Parameter('gain_db', 'Boost / cut (−24 to +24 dB)', -24, 24, 0);
    end;
  end
  else
  begin
    case AKind of
      ceGain:
        Parameter('gain_db', 'Gain (−48 to +12 dB)', -48, 12, 0);
      ceCompressor:
        begin
          Parameter('threshold_db', 'Threshold (−60 to 0 dB)', -60, 0, -18);
          Parameter('ratio', 'Ratio (1–20)', 1, 20, 3);
          Parameter('attack_ms', 'Attack (0–200 ms)', 0, 200, 10);
          Parameter('release_ms', 'Release (1–2,000 ms)', 1, 2000, 100);
          Parameter('makeup_db', 'Makeup gain (0–12 dB)', 0, 12, 0);
        end;
      ceLimiter:
        begin
          Parameter('ceiling_db', 'Ceiling (−24 to 0 dB)', -24, 0, -1);
          Parameter('release_ms', 'Release (1–2,000 ms)', 1, 2000, 100);
        end;
    end;
  end;
  Result := LDefinition;
end;

function FindEffectDefinition(const AKey: String; out ADefinition: TEffectDefinition): Boolean;
var
  LKind: TCatalogEffect;
begin
  for LKind := Low(TCatalogEffect) to High(TCatalogEffect) do
  begin
    ADefinition := EffectDefinition(LKind);
    if ADefinition.Key = AKey then
    begin
      Exit(True);
    end;
  end;
  Result := False;
end;

function EffectParameterMaximum(const AParameter: TEffectParameter;
  const ASampleRate: Integer): Double;
var
  LMinimumHz: Double;
  LMaximumHz: Double;
begin
  Result := AParameter.Maximum;
  if (AParameter.Key = 'frequency_hz') and (ASampleRate > 0) then
  begin
    BiquadFrequencyBounds(ASampleRate, LMinimumHz, LMaximumHz);
    Result := Min(Result, LMaximumHz);
  end;
end;

end.
