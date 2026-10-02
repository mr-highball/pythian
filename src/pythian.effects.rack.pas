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
unit pythian.effects.rack;

{$mode delphi}
{$H+}

interface

uses
  pythian.effects,
  pythian.effects.catalog;

{ Returns an owned, reset effect. Settings are borrowed only during creation.
  Mix is linear dry=1-mix, wet=mix. Delay uses opposed stereo sine modulation;
  zero depth is a steady echo. No JSON, playback or WFC dependency. }
function CreateCatalogEffect(const ASampleRate: Integer;
  const ASettings: TCatalogEffectSettings): TAudioEffect;

implementation

uses
  Math,
  pythian.audio,
  pythian.automation,
  pythian.biquad,
  pythian.dynamics,
  pythian.delay.modulated,
  pythian.reverb;

function CreateCatalogEffect(const ASampleRate: Integer;
  const ASettings: TCatalogEffectSettings): TAudioEffect;
var
  LDefinition: TEffectDefinition;
  LFilter: TBiquadSettings;
  LCompressor: TCompressorSettings;
  LDelay: TModulatedDelaySettings;
  LReverb: TReverbSettings;
  LLfo: TAutomationCurve;
  LLeft: TAutomationCurve;
  LRight: TAutomationCurve;
  LPeriod: Int64;
  LBase: Double;
  LDepth: Double;

  function Value(const AKey: String): Double;
  begin
    Result := CatalogEffectValue(ASettings, AKey);
  end;

begin
  ValidateCatalogEffect(ASettings, ASampleRate);
  LDefinition := EffectDefinition(ASettings.Kind);
  if LDefinition.IsBiquad then
  begin
    LFilter := DefaultBiquadSettings;
    LFilter.Kind := LDefinition.BiquadKind;
    LFilter.FrequencyHz := Value('frequency_hz');
    if not (ASettings.Kind in [ceLowShelf, ceHighShelf]) then
    begin
      LFilter.Q := Value('q');
    end;
    if ASettings.Kind in [cePeak, ceLowShelf, ceHighShelf] then
    begin
      LFilter.GainDb := Value('gain_db');
    end;
    Exit(TBiquadEffect.Create(ASampleRate, LFilter));
  end;
  case ASettings.Kind of
    ceGain:
      Result := TGainEffect.Create(ASampleRate, Power(10, Value('gain_db') / 20), 0);
    ceCompressor:
      begin
        LCompressor := DefaultCompressorSettings;
        LCompressor.ThresholdDb := Value('threshold_db');
        LCompressor.Ratio := Value('ratio');
        LCompressor.AttackSeconds := Value('attack_ms') / 1000;
        LCompressor.ReleaseSeconds := Value('release_ms') / 1000;
        LCompressor.MakeupDb := Value('makeup_db');
        LCompressor.KneeDb := 6;
        Result := TCompressorEffect.Create(ASampleRate, LCompressor);
      end;
    ceLimiter:
      Result := TLimiterEffect.Create(ASampleRate, Value('ceiling_db'),
        Value('release_ms') / 1000);
    ceDelay:
      begin
        LBase := Value('delay_ms') * ASampleRate / 1000;
        LDepth := Value('depth_ms') * ASampleRate / 1000;
        LPeriod := Round(ASampleRate / Value('rate_hz'));
        LDelay.MaximumDelayFrames := Ceil(LBase + LDepth);
        LDelay.Feedback := Value('feedback');
        LDelay.WetGain := Value('mix');
        LDelay.DryGain := 1 - LDelay.WetGain;
        LLfo := nil;
        LLeft := nil;
        LRight := nil;
        try
          LLfo := TAutomationCurve.CreateLfo(LPeriod, alsSine);
          LLeft := TAutomationCurve.CreateAffine(LLfo, LDepth, LBase);
          LRight := TAutomationCurve.CreateAffine(LLfo, -LDepth, LBase);
          Result := TModulatedDelayEffect.Create(ASampleRate, LDelay, LLeft, LRight);
        finally
          LRight.Free;
          LLeft.Free;
          LLfo.Free;
        end;
      end;
    ceReverb:
      begin
        LReverb := DefaultReverbSettings(ASampleRate);
        LReverb.DecaySeconds := Value('decay_seconds');
        LReverb.Damping := Value('damping');
        LReverb.Diffusion := Value('diffusion');
        LReverb.Width := Value('width');
        LReverb.WetGain := Value('mix');
        LReverb.DryGain := 1 - LReverb.WetGain;
        Result := TReverbEffect.Create(ASampleRate, LReverb);
      end;
  else
    raise EAudio.Create('Unsupported catalog effect');
  end;
end;

end.
