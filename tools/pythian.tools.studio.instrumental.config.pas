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

unit pythian.tools.studio.instrumental.config;

{$mode delphi}
{$H+}

interface

uses fpjson, pythian.music.controls, pythian.instrument, pythian.music.sound,
  pythian.oscillator, pythian.percussion, pythian.instrument.recipe;

const
  StudioInstrumentalOrigin =
    'Authored symbolic starter v1; operator tempo/key/sounds; WFC pitched and drum decisions; no WAV learning';
  StudioInstrumentalRate = 24000;
  StudioPlaylistOrigin =
    'Experimental recording-derived musical providers; primary synthesized instruments; no original-audio reconstruction';

function StudioInstrumentShape(const AName: String): TWaveShape;
function StudioPlaylistInstrumentZones: TInstrumentZones;
function CreateStudioRecipeInstrument(const ATemplate: TInstrumentZones;
  const AName: String; const ASound: TMusicalSound; const AApplySound: Boolean;
  const ASampleRate: Integer; const ASettings: TJSONObject = nil;
  const APart: Integer = -1): TRecipeInstrument;
function DecodeStudioPercussionSettings(const ARow: TJSONObject;
  const ASampleRate: Integer): TPercussionSettings;

implementation

uses SysUtils, pythian.audio, pythian.synth, pythian.tools.studio.sounds;

procedure Need(const ACondition: Boolean; const AMessage: String);
begin
  if not ACondition then raise EAudio.Create(AMessage);
end;

function Number(const AConfig: TJSONObject; const AName: String;
  const AMinimum, AMaximum: Integer): Integer;
var LValue: TJSONData;
begin
  LValue := AConfig.Find(AName);
  Need((LValue <> nil) and (LValue.JSONType = jtNumber),
    'Instrumental setting requires a whole number: ' + AName);
  Need((LValue.AsFloat = LValue.AsInt64) and (LValue.AsInt64 >= AMinimum) and
    (LValue.AsInt64 <= AMaximum), 'Instrumental setting is out of range: ' + AName);
  Result := LValue.AsInteger;
end;

function StudioInstrumentShape(const AName: String): TWaveShape;
begin
  if AName = 'sine' then Exit(wsSine);
  if AName = 'triangle' then Exit(wsTriangle);
  if AName = 'saw' then Exit(wsSaw);
  if AName = 'square' then Exit(wsSquare);
  raise EAudio.Create('Choose an available instrument sound');
end;

function StudioPlaylistInstrumentZones: TInstrumentZones;
var LZones: TInstrumentZones;
begin
  SetLength(LZones, 1);
  LZones[0].MinimumKey := 0;
  LZones[0].MaximumKey := 127;
  LZones[0].MinimumVelocity := 1;
  LZones[0].MaximumVelocity := 127;
  LZones[0].Voice := DefaultSynthVoice;
  LZones[0].Voice.Gain := 0.14;
  Result := LZones;
end;

function CreateStudioRecipeInstrument(const ATemplate: TInstrumentZones;
  const AName: String; const ASound: TMusicalSound; const AApplySound: Boolean;
  const ASampleRate: Integer; const ASettings: TJSONObject;
  const APart: Integer): TRecipeInstrument;
var
  LRecipe: TInstrumentRecipe;
  I: Integer;
begin
  if (ASettings <> nil) and (ASettings.Find('sound_design') <> nil) then
  begin
    Need((APart >= 0) and (APart < 3), 'Choose a pitched part for its sound recipe');
    LRecipe := DecodeStudioInstrumentRecipe(ASettings.Objects['sound_design'].Arrays['instruments'][APart]);
  end
  else
  begin
    LRecipe := Default(TInstrumentRecipe);
    LRecipe.Id := 'studio-oscillator-' + AName;
    LRecipe.Caption := AName;
    LRecipe.Origin := 'Studio oscillator; explicit voice controls';
    SetLength(LRecipe.Zones, Length(ATemplate));
    for I := 0 to High(ATemplate) do
    begin
      LRecipe.Zones[I] := DefaultInstrumentZoneRecipe;
      LRecipe.Zones[I].MinimumKey := ATemplate[I].MinimumKey;
      LRecipe.Zones[I].MaximumKey := ATemplate[I].MaximumKey;
      LRecipe.Zones[I].MinimumVelocity := ATemplate[I].MinimumVelocity;
      LRecipe.Zones[I].MaximumVelocity := ATemplate[I].MaximumVelocity;
      LRecipe.Zones[I].Voice := ATemplate[I].Voice;
      LRecipe.Zones[I].Voice.Shape := StudioInstrumentShape(AName);
      if AApplySound then
      begin
        LRecipe.Zones[I].Voice := ApplyMusicalSound(LRecipe.Zones[I].Voice, ASound, ASampleRate);
        LRecipe.Origin := 'Studio oscillator; Experimental recording-derived cutoff/sustain';
      end;
    end;
  end;
  Result := TRecipeInstrument.Create(LRecipe, ASampleRate);
end;

function DecodeStudioPercussionSettings(const ARow: TJSONObject;
  const ASampleRate: Integer): TPercussionSettings;
const
  CFields: array[0..5] of String =
    ('gain', 'pan', 'gate_seconds', 'release_seconds', 'tone_hz', 'cutoff_hz');
var LName: String;
begin
  Result := DefaultPercussionSettings(TPercussionKind(Number(ARow, 'kind', 0, 2)), ASampleRate);
  for LName in CFields do
    Need((ARow.Find(LName) <> nil) and (ARow.Find(LName).JSONType = jtNumber),
      'Saved drum recipe has a missing numeric setting');
  Result.Gain := ARow.Floats['gain'];
  Result.Pan := ARow.Floats['pan'];
  Result.GateSeconds := ARow.Floats['gate_seconds'];
  Result.ReleaseSeconds := ARow.Floats['release_seconds'];
  Result.ToneHz := ARow.Floats['tone_hz'];
  Result.CutoffHz := ARow.Floats['cutoff_hz'];
end;

end.
