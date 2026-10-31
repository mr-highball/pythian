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
  pythian.oscillator, pythian.percussion;

const
  StudioInstrumentalOrigin =
    'Authored symbolic starter v1; operator tempo/key/sounds; WFC pitched and drum decisions; no WAV learning';
  StudioInstrumentalRate = 24000;
  StudioInstrumentalMaximumCells = 256;
  StudioPlaylistOrigin =
    'Experimental recording-derived musical providers; primary synthesized instruments; no original-audio reconstruction';

procedure ValidateStudioInstrumentalConfig(const AConfig: TJSONObject);
procedure ValidateStudioInstrumentNames(const ANames: TJSONArray);
function StudioInstrumentShape(const AName: String): TWaveShape;
function StudioPlaylistInstrumentZones: TInstrumentZones;
function CreateStudioInstrument(const ATemplate: TInstrumentZones;
  const AName: String; const ASound: TMusicalSound; const AApplySound: Boolean;
  const ASampleRate: Integer): TInstrument;
function DecodeStudioPercussionSettings(const ARow: TJSONObject;
  const ASampleRate: Integer): TPercussionSettings;
function DecodeStudioMusicalControls(const AControls: TJSONObject): TMusicalPartControls;

implementation

uses SysUtils, pythian.audio, pythian.synth;

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

procedure ValidateStudioInstrumentNames(const ANames: TJSONArray);
var I: Integer;
begin
  Need((ANames <> nil) and (ANames.Count = 3), 'Choose three pitched instruments');
  for I := 0 to 2 do
  begin
    Need(ANames[I].JSONType = jtString, 'Instrument name must be text');
    StudioInstrumentShape(ANames.Strings[I]);
  end;
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

function CreateStudioInstrument(const ATemplate: TInstrumentZones;
  const AName: String; const ASound: TMusicalSound; const AApplySound: Boolean;
  const ASampleRate: Integer): TInstrument;
var LZones: TInstrumentZones; I: Integer;
begin
  LZones := Copy(ATemplate);
  for I := 0 to High(LZones) do
  begin
    LZones[I].Voice.Shape := StudioInstrumentShape(AName);
    if AApplySound then
      LZones[I].Voice := ApplyMusicalSound(LZones[I].Voice, ASound, ASampleRate);
  end;
  Result := TInstrument.Create(LZones);
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

procedure ValidateStudioInstrumentalConfig(const AConfig: TJSONObject);
var LIndex: Integer; LValue: TJSONData;
begin
  Need((AConfig <> nil) and (AConfig.Count = 5 + Ord(AConfig.Find('mode') <> nil) +
    Ord(AConfig.Find('controls') <> nil)),
    'Instrumental settings require tempo_bpm, tonic, cells, instruments and levels');
  for LIndex := 0 to AConfig.Count - 1 do
    Need(Pos('|' + AConfig.Names[LIndex] + '|',
      '|tempo_bpm|tonic|cells|instruments|levels|mode|controls|') > 0, 'Unsupported instrumental setting');
  if AConfig.Find('controls') <> nil then
  begin
    Need(AConfig.Find('controls').JSONType = jtObject, 'Musical controls must be an object');
    DecodeStudioMusicalControls(AConfig.Objects['controls']);
  end;
  if AConfig.Find('mode') <> nil then
  begin
    Need(AConfig.Find('mode').JSONType = jtString, 'Accompaniment mode must be text');
    Need((AConfig.Strings['mode'] = 'major') or (AConfig.Strings['mode'] = 'natural_minor'),
      'Choose major or natural minor accompaniment');
  end;
  Number(AConfig, 'tempo_bpm', 40, 240);
  Number(AConfig, 'tonic', 0, 11);
  Number(AConfig, 'cells', 1, StudioInstrumentalMaximumCells);
  LValue := AConfig.Find('instruments');
  Need((LValue <> nil) and (LValue.JSONType = jtArray) and
    (TJSONArray(LValue).Count = 3), 'Choose three pitched instruments');
  ValidateStudioInstrumentNames(TJSONArray(LValue));
  LValue := AConfig.Find('levels');
  Need((LValue <> nil) and (LValue.JSONType = jtArray) and
    (TJSONArray(LValue).Count = 6), 'Choose six part levels');
  for LIndex := 0 to 5 do
  begin
    Need(TJSONArray(LValue)[LIndex].JSONType = jtNumber, 'Part level must be numeric');
    Need((TJSONArray(LValue)[LIndex].AsFloat = TJSONArray(LValue)[LIndex].AsInt64) and
      (TJSONArray(LValue).Integers[LIndex] >= 0) and
      (TJSONArray(LValue).Integers[LIndex] <= 100), 'Part level must be 0..100');
  end;
end;

function DecodeStudioMusicalControls(const AControls: TJSONObject): TMusicalPartControls;
var
  LParts: TJSONData;
  LPart: TJSONObject;
  LIndex: Integer;
  LField: Integer;
begin
  Result := nil;
  SetLength(Result, 3);
  for LIndex := 0 to 2 do Result[LIndex] := DefaultMusicalPartControl;
  if AControls = nil then Exit;
  Need((AControls.Count = 3) and (AControls.Find('guide') <> nil) and
    (AControls.Find('tonic_bias') <> nil), 'Musical controls need guide, tonic_bias and parts');
  Need(AControls.Find('guide').JSONType = jtBoolean, 'Authored guide choice must be Boolean');
  Number(AControls, 'tonic_bias', -100, 100);
  LParts := AControls.Find('parts');
  Need((LParts <> nil) and (LParts.JSONType = jtArray) and
    (TJSONArray(LParts).Count = 3), 'Musical controls require three pitched parts');
  for LIndex := 0 to 2 do
  begin
    Need(TJSONArray(LParts)[LIndex].JSONType = jtObject, 'Part controls must be an object');
    LPart := TJSONArray(LParts).Objects[LIndex];
    Need(LPart.Count = 5, 'Part controls require pitch bounds, activity, velocity and gate');
    for LField := 0 to LPart.Count - 1 do
      Need(Pos('|' + LPart.Names[LField] + '|',
        '|minimum_pitch|maximum_pitch|activity_bias|velocity_percent|gate_percent|') > 0,
        'Unsupported part control');
    Result[LIndex].MinimumPitch := Number(LPart, 'minimum_pitch', 0, 127);
    Result[LIndex].MaximumPitch := Number(LPart, 'maximum_pitch', 0, 127);
    Result[LIndex].ActivityBias := Number(LPart, 'activity_bias', -100, 100);
    Result[LIndex].Expression.VelocityPercent := Number(LPart, 'velocity_percent', 1, 200);
    Result[LIndex].Expression.GatePercent := Number(LPart, 'gate_percent', 1, 100);
    ValidateMusicalPartControl(Result[LIndex]);
  end;
end;

end.
