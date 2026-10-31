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
unit pythian.percussion;

{$mode delphi}
{$H+}

interface

uses
  pythian.synth,
  pythian.instrument,
  pythian.automation;

type
  TPercussionKind = (pkKick, pkSnare, pkClosedHat);
  TPercussionSettings = record
    Kind: TPercussionKind;
    Gain: Double;
    Pan: Double;
    GateSeconds: Double;
    ReleaseSeconds: Double;
    ToneHz: Double;
    CutoffHz: Double;
  end;

  { Big Boss: primary source-free percussion recipes. Noise/oscillators, curves,
    envelopes, filtering and layered note planning use existing core classes.
    Owns its curves/instrument. Keep this definition alive through planning and
    player construction; playing tones clone the curves and envelopes. }
  TPercussionInstrument = class
  private
    FRate: Integer;
    FSettings: TPercussionSettings;
    FInstrument: TInstrument;
    FCurves: array of TAutomationCurve;
  public
    constructor Create(const ASampleRate: Integer; const ASettings: TPercussionSettings);
    destructor Destroy; override;
    function PlanHit(const AStartFrame: Int64; const AVelocity: Integer;
      const ASeed: Cardinal): TFrameTones;
    function CopySettings: TPercussionSettings;
    property SampleRate: Integer read FRate;
    { Borrowed primary recipe, including its owned automation curves. Keep this
      percussion instrument alive through every stream using the recipe. }
    property Instrument: TInstrument read FInstrument;
  end;

function DefaultPercussionSettings(const AKind: TPercussionKind;
  const ASampleRate: Integer): TPercussionSettings;
{ Explicit GM channel-10 note keys for export/zone selection, never harmonic
  pitch-class membership. Physical oscillator frequency is independent. }
function PercussionKey(const AKind: TPercussionKind): Integer;

implementation

uses
  Math,
  pythian.audio,
  pythian.time,
  pythian.oscillator,
  pythian.filter,
  pythian.biquad;

function PercussionKey(const AKind: TPercussionKind): Integer;
begin
  case AKind of
    pkKick: Result := 36;
    pkSnare: Result := 38;
    pkClosedHat: Result := 42;
  else
    raise EAudio.Create('Unsupported percussion kind');
  end;
end;

function DefaultPercussionSettings(const AKind: TPercussionKind;
  const ASampleRate: Integer): TPercussionSettings;
begin
  ValidateAudioFormat(ASampleRate, 2);
  PercussionKey(AKind);
  if ASampleRate < 8000 then
  begin
    raise EAudio.Create('Percussion recipes require at least 8000 Hz');
  end;
  Result := Default(TPercussionSettings);
  Result.Kind := AKind;
  Result.Gain := 0.45;
  Result.GateSeconds := 0.14;
  Result.ReleaseSeconds := 0.04;
  Result.ToneHz := 48;
  Result.CutoffHz := Min(1800, ASampleRate * 0.4);
  case AKind of
    pkSnare:
    begin
      Result.Gain := 0.34;
      Result.GateSeconds := 0.10;
      Result.ToneHz := 180;
      Result.Pan := 0.08;
    end;
    pkClosedHat:
    begin
      Result.Gain := 0.18;
      Result.GateSeconds := 0.045;
      Result.ReleaseSeconds := 0.02;
      Result.ToneHz := 120;
      Result.CutoffHz := Min(7000, ASampleRate * 0.4);
      Result.Pan := -0.15;
    end;
  end;
end;

constructor TPercussionInstrument.Create(const ASampleRate: Integer;
  const ASettings: TPercussionSettings);
var
  LZones: TInstrumentZones;
  LPoints: TAutomationPoints;
  LIndex: Integer;
  LKey: Integer;
  LVoice: TSynthVoice;
begin
  inherited Create;
  ValidateAudioFormat(ASampleRate, 2);
  LKey := PercussionKey(ASettings.Kind);
  if ASampleRate < 8000 then
  begin
    raise EAudio.Create('Percussion recipes require at least 8000 Hz');
  end;
  RequireFinite(ASettings.Gain, 'Percussion gain');
  RequireFinite(ASettings.Pan, 'Percussion pan');
  RequireFinite(ASettings.GateSeconds, 'Percussion gate');
  RequireFinite(ASettings.ReleaseSeconds, 'Percussion release');
  RequireFinite(ASettings.ToneHz, 'Percussion physical frequency');
  RequireFinite(ASettings.CutoffHz, 'Percussion cutoff');
  if (ASettings.Gain < 0) or (ASettings.Gain > 4) or
    (ASettings.Pan < -1) or (ASettings.Pan > 1) or
    (ASettings.GateSeconds <= 0) or (ASettings.GateSeconds > 4) or
    (ASettings.ReleaseSeconds < 0) or (ASettings.ReleaseSeconds > 4) or
    (ASettings.ToneHz <= 0) or (ASettings.ToneHz > ASampleRate * 0.1) or
    (ASettings.CutoffHz <= 0) or (ASettings.CutoffHz >= ASampleRate * 0.5) then
  begin
    raise EAudio.Create('Percussion gain/pan/gate/release/frequency/cutoff is outside recipe bounds');
  end;
  FRate := ASampleRate;
  FSettings := ASettings;
  SetLength(LZones, 1);
  if ASettings.Kind = pkSnare then
  begin
    SetLength(LZones, 2);
  end;
  SetLength(FCurves, Length(LZones));
  for LIndex := 0 to High(LZones) do
  begin
    LVoice := DefaultSynthVoice;
    LVoice.Shape := wsNoise;
    LVoice.Gain := ASettings.Gain;
    LVoice.Pan := ASettings.Pan;
    LVoice.CutoffHz := ASettings.CutoffHz;
    LVoice.Envelope.AttackSeconds := 0.001;
    LVoice.Envelope.DecaySeconds := ASettings.GateSeconds * 0.8;
    LVoice.Envelope.SustainLevel := 0.01;
    LVoice.Envelope.ReleaseSeconds := ASettings.ReleaseSeconds;
    if (ASettings.Kind = pkKick) or (LIndex = 1) then
    begin
      LVoice.Shape := wsSine;
      SetLength(LPoints, 1);
      LPoints[0] := Default(TAutomationPoint);
      LPoints[0].Value := ASettings.ToneHz;
      if ASettings.Kind = pkKick then
      begin
        SetLength(LPoints, 3);
        LPoints[0].Value := ASettings.ToneHz * 3;
        LPoints[0].Transition := atExponential;
        LPoints[1].Frame := Max(1, Round(ASampleRate * 0.012));
        LPoints[1].Value := ASettings.ToneHz * 1.35;
        LPoints[1].Transition := atExponential;
        LPoints[2].Frame := Max(LPoints[1].Frame + 1, Round(ASampleRate * 0.075));
        LPoints[2].Value := ASettings.ToneHz;
      end
      else
      begin
        LVoice.Gain := ASettings.Gain * 0.3;
      end;
      FCurves[LIndex] := TAutomationCurve.Create(LPoints);
      LVoice.Automation.FrequencyHz := FCurves[LIndex];
    end
    else if ASettings.Kind = pkClosedHat then
    begin
      LVoice.FilterKind := fkHighPass;
      LVoice.FilterModel := vfmBiquad;
      LVoice.BiquadKind := bkHighPass;
    end
    else
    begin
      LVoice.FilterModel := vfmBiquad;
      LVoice.BiquadKind := bkBandPass;
      LVoice.BiquadQ := 0.7;
    end;
    LZones[LIndex] := Default(TInstrumentZone);
    LZones[LIndex].MinimumKey := LKey;
    LZones[LIndex].MaximumKey := LKey;
    LZones[LIndex].MinimumVelocity := 1;
    LZones[LIndex].MaximumVelocity := 127;
    LZones[LIndex].Voice := LVoice;
  end;
  FInstrument := TInstrument.Create(LZones);
end;

destructor TPercussionInstrument.Destroy;
var
  LCurve: TAutomationCurve;
begin
  FInstrument.Free;
  for LCurve in FCurves do
  begin
    LCurve.Free;
  end;
  inherited Destroy;
end;

function TPercussionInstrument.PlanHit(const AStartFrame: Int64;
  const AVelocity: Integer; const ASeed: Cardinal): TFrameTones;
begin
  Result := FInstrument.PlanNote(PercussionKey(FSettings.Kind), AVelocity,
    FRate, AStartFrame, SampleFramesFromSeconds(FSettings.GateSeconds, FRate), ASeed);
end;

function TPercussionInstrument.CopySettings: TPercussionSettings;
begin
  Result := FSettings;
end;

end.
