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

unit pythian.music.sound;
{$mode delphi}
{$H+}

interface

uses pythian.synth;

type
  TMusicalSound = record
    CutoffHz: Integer;
    SustainPercent: Integer;
  end;

{ Experimental control mapping, not source/instrument identification. Brightness
  proposes twice the spectral centroid, bounded to 100..10000 Hz. Quiet/peak
  window RMS proposes ADSR sustain. Silence yields no proposal. No audio, voice
  or caller state is changed. Applying it is an explicit separate operation. }
function ProposeMusicalSound(const ACentroidHz, AMinimumRms, AMaximumRms: Double;
  out ASound: TMusicalSound): Boolean;
procedure ValidateMusicalSound(const ASound: TMusicalSound);
{ Detached voice record; existing borrowed resources retain their lifetime.
  Reject conflicting cutoff automation/gated envelopes rather than ignoring
  either control. Cutoff must fit this actual synthesis sample rate. }
function ApplyMusicalSound(const AVoice: TSynthVoice; const ASound: TMusicalSound;
  const ASampleRate: Integer): TSynthVoice;

implementation

uses pythian.audio, pythian.filter;

procedure ValidateMusicalSound(const ASound: TMusicalSound);
begin
  if (ASound.CutoffHz < 100) or (ASound.CutoffHz > 10000) or
    (ASound.SustainPercent < 0) or (ASound.SustainPercent > 100) or
    (ASound.CutoffHz <> Trunc(ASound.CutoffHz)) or
    (ASound.SustainPercent <> Trunc(ASound.SustainPercent)) then
    raise EAudio.Create('Sound controls require cutoff 100..10000 Hz and sustain 0..100 percent');
end;

function ProposeMusicalSound(const ACentroidHz, AMinimumRms, AMaximumRms: Double;
  out ASound: TMusicalSound): Boolean;
begin
  RequireFinite(ACentroidHz, 'Sound centroid');
  RequireFinite(AMinimumRms, 'Sound minimum RMS');
  RequireFinite(AMaximumRms, 'Sound maximum RMS');
  if (ACentroidHz < 0) or (AMinimumRms < 0) or (AMaximumRms < AMinimumRms) then
    raise EAudio.Create('Sound observations require nonnegative brightness and ordered RMS bounds');
  ASound := Default(TMusicalSound);
  Result := AMaximumRms > 1E-5;
  if not Result then Exit;
  if ACentroidHz <= 50 then ASound.CutoffHz := 100
  else if ACentroidHz >= 5000 then ASound.CutoffHz := 10000
  else ASound.CutoffHz := Round(2 * ACentroidHz);
  ASound.SustainPercent := Round(100 * (AMinimumRms / AMaximumRms));
  ValidateMusicalSound(ASound);
end;

function ApplyMusicalSound(const AVoice: TSynthVoice; const ASound: TMusicalSound;
  const ASampleRate: Integer): TSynthVoice;
begin
  ValidateMusicalSound(ASound);
  ValidateAudioFormat(ASampleRate, 2);
  if ASound.CutoffHz >= ASampleRate / 2 then
    raise EAudio.Create('Sound cutoff must be below this synthesis sample rate Nyquist limit');
  if (AVoice.GateEnvelope <> nil) or (AVoice.Automation.CutoffHz <> nil) then
    raise EAudio.Create('Choose either sound starting points or existing envelope/cutoff automation');
  Result := AVoice;
  Result.FilterModel := vfmOnePole;
  Result.FilterKind := fkLowPass;
  Result.CutoffHz := ASound.CutoffHz;
  Result.Envelope.SustainLevel := ASound.SustainPercent / 100;
end;

end.
