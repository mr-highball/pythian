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

uses fpjson, pythian.music.controls;

const
  StudioInstrumentalOrigin =
    'Authored symbolic starter v1; operator tempo/key/sounds; WFC pitched and drum decisions; no WAV learning';
  StudioInstrumentalRate = 24000;
  StudioInstrumentalMaximumCells = 256;

procedure ValidateStudioInstrumentalConfig(const AConfig: TJSONObject);
function DecodeStudioMusicalControls(const AControls: TJSONObject): TMusicalPartControls;

implementation

uses SysUtils, pythian.audio;

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

procedure ValidateStudioInstrumentalConfig(const AConfig: TJSONObject);
var LIndex: Integer; LValue: TJSONData; LText: String;
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
  Need(Number(AConfig, 'cells', 8, StudioInstrumentalMaximumCells) mod 8 = 0,
    'Instrumental length requires complete eight-cell bars');
  LValue := AConfig.Find('instruments');
  Need((LValue <> nil) and (LValue.JSONType = jtArray) and
    (TJSONArray(LValue).Count = 3), 'Choose three pitched instruments');
  for LIndex := 0 to 2 do
  begin
    Need(TJSONArray(LValue)[LIndex].JSONType = jtString, 'Instrument name must be text');
    LText := TJSONArray(LValue).Strings[LIndex];
    Need((LText = 'sine') or (LText = 'triangle') or (LText = 'saw') or
      (LText = 'square'), 'Unsupported instrumental oscillator');
  end;
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
