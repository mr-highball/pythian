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

unit pythian.tools.studio.instrumental.settings;

{$mode delphi}
{$H+}

interface

uses fpjson, pythian.music.controls;

const
  StudioInstrumentalMaximumCells = 256;

type
  TStudioPassageEdit = record
    StartFrame: Int64;
    EndFrame: Int64;
    Parts: array of Boolean;
    Harmony: Boolean;
    Rhythm: Boolean;
    Tonic: Integer;
    TonicBias: Integer;
    Controls: TMusicalPartControls;
    Seed: Integer;
  end;

{ Big Boss: one native JSON boundary for saved experiment settings and jobs.
  No WFC/model construction, source access or inference occurs here. }
procedure ValidateStudioInstrumentalConfig(const AConfig: TJSONObject);
procedure ValidateStudioInstrumentNames(const ANames: TJSONArray);
function DecodeStudioMusicalControls(const AControls: TJSONObject): TMusicalPartControls;
function DecodeStudioPassageEdit(const AEdit: TJSONObject;
  const AMusicFrames: Int64): TStudioPassageEdit;
function CanonicalStudioInstrumentalConfig(const AConfig: TJSONObject): TJSONObject;

implementation

uses SysUtils, pythian.audio, pythian.music.form, pythian.music.decisions,
  pythian.tools.studio.form;
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

function DecodeStudioPassageEdit(const AEdit: TJSONObject;
  const AMusicFrames: Int64): TStudioPassageEdit;
var
  I: Integer;
  LAny: Boolean;
begin
  Result := Default(TStudioPassageEdit);
  Need((AMusicFrames > 0) and (AMusicFrames <= High(Integer)) and
    (AEdit <> nil) and (AEdit.Count = 8), 'Note changes need a saved track and explicit choices');
  for I := 0 to AEdit.Count - 1 do
    Need(Pos('|' + AEdit.Names[I] + '|',
      '|start_frame|end_frame|parts|harmony|rhythm|tonic|controls|seed|') > 0,
      'Unsupported note change');
  Result.StartFrame := Number(AEdit, 'start_frame', 0, AMusicFrames - 1);
  Result.EndFrame := Number(AEdit, 'end_frame', 1, AMusicFrames);
  Need(Result.EndFrame > Result.StartFrame, 'End must follow Start');
  Need((AEdit.Find('parts') <> nil) and (AEdit.Find('parts').JSONType = jtArray) and
    (AEdit.Arrays['parts'].Count = 6), 'Choose the parts to change');
  Need((AEdit.Find('harmony') <> nil) and (AEdit.Find('harmony').JSONType = jtBoolean) and
    (AEdit.Find('rhythm') <> nil) and (AEdit.Find('rhythm').JSONType = jtBoolean),
    'Chord and rhythm choices must be explicit');
  Result.Harmony := AEdit.Booleans['harmony'];
  Result.Rhythm := AEdit.Booleans['rhythm'];
  Result.Tonic := Number(AEdit, 'tonic', 0, 11);
  Result.Seed := Number(AEdit, 'seed', 0, High(Integer));
  Need((AEdit.Find('controls') <> nil) and (AEdit.Find('controls').JSONType = jtObject),
    'Note controls are required');
  Result.Controls := DecodeStudioMusicalControls(AEdit.Objects['controls']);
  Need(not AEdit.Objects['controls'].Booleans['guide'],
    'Retained note changes use the saved models, without an authored guide');
  Result.TonicBias := AEdit.Objects['controls'].Integers['tonic_bias'];
  Need(Result.Harmony or (Result.TonicBias = 0), 'Allow chord changes before choosing a chord preference');
  SetLength(Result.Parts, 6);
  LAny := Result.Harmony or Result.Rhythm;
  for I := 0 to 5 do
  begin
    Need(AEdit.Arrays['parts'][I].JSONType = jtBoolean, 'Part selections must be Boolean');
    Result.Parts[I] := AEdit.Arrays['parts'].Booleans[I];
    LAny := LAny or Result.Parts[I];
    if I >= 3 then Continue;
    Need(Result.Parts[I] or ((Result.Controls[I].MinimumPitch = 0) and
      (Result.Controls[I].MaximumPitch = 127)), 'Select a part before setting its pitch range');
    Need(Result.Rhythm or (Result.Controls[I].ActivityBias = 0),
      'Allow rhythm changes before setting activity');
    Need((Result.Controls[I].Expression.VelocityPercent = 100) and
      (Result.Controls[I].Expression.GatePercent = 100), 'Note changes keep the performed expression');
  end;
  Need(LAny, 'Choose at least one part to change');
end;

procedure ValidateStudioInstrumentNames(const ANames: TJSONArray);
var I: Integer;
begin
  Need((ANames <> nil) and (ANames.Count = 3), 'Choose three pitched instruments');
  for I := 0 to 2 do
  begin
    Need(ANames[I].JSONType = jtString, 'Instrument name must be text');
    Need((ANames.Strings[I] = 'sine') or (ANames.Strings[I] = 'triangle') or
      (ANames.Strings[I] = 'square') or (ANames.Strings[I] = 'saw'),
      'Choose a supported instrument sound');
  end;
end;

procedure ValidateStudioInstrumentalConfig(const AConfig: TJSONObject);
var LIndex, LMaximumCells: Integer; LValue: TJSONData; LForm: TMusicForm;
  LControls: TMusicalPartControls;
begin
  Need((AConfig <> nil) and (AConfig.Count = 5 + Ord(AConfig.Find('mode') <> nil) +
    Ord(AConfig.Find('controls') <> nil) + Ord(AConfig.Find('form') <> nil)),
    'Instrumental settings require tempo_bpm, tonic, cells, instruments and levels');
  for LIndex := 0 to AConfig.Count - 1 do
    Need(Pos('|' + AConfig.Names[LIndex] + '|',
      '|tempo_bpm|tonic|cells|instruments|levels|mode|controls|form|') > 0, 'Unsupported instrumental setting');
  LMaximumCells := StudioInstrumentalMaximumCells;
  if AConfig.Find('form') <> nil then
  begin
    LForm := DecodeStudioForm(AConfig.Find('form'));
    LMaximumCells := MaximumMusicFormPhrases * MaximumMusicDecisionCells;
    Need(Number(AConfig, 'cells', 1, LMaximumCells) = StudioFormCells(LForm),
      'Track length must equal the sections in its structure');
  end;
  if AConfig.Find('controls') <> nil then
  begin
    Need(AConfig.Find('controls').JSONType = jtObject, 'Musical controls must be an object');
    LControls := DecodeStudioMusicalControls(AConfig.Objects['controls']);
    if AConfig.Find('form') <> nil then
    begin
      Need(AConfig.Objects['controls'].Integers['tonic_bias'] = 0,
        'Experimental structure currently requires a neutral chord preference');
      for LIndex := 0 to High(LControls) do
        Need((LControls[LIndex].ActivityBias = 0) and
          (LControls[LIndex].Expression.VelocityPercent = 100) and
          (LControls[LIndex].Expression.GatePercent = 100),
          'Experimental structure currently requires neutral activity and 100% note strength/length');
    end;
  end;
  if AConfig.Find('mode') <> nil then
  begin
    Need(AConfig.Find('mode').JSONType = jtString, 'Accompaniment mode must be text');
    Need((AConfig.Strings['mode'] = 'major') or (AConfig.Strings['mode'] = 'natural_minor'),
      'Choose major or natural minor accompaniment');
  end;
  Number(AConfig, 'tempo_bpm', 40, 240);
  Number(AConfig, 'tonic', 0, 11);
  Number(AConfig, 'cells', 1, LMaximumCells);
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

function CanonicalStudioInstrumentalConfig(const AConfig: TJSONObject): TJSONObject;
var
  LParts: TMusicalPartControls;
  LControls: TJSONObject;
  LRows: TJSONArray;
  LLevels: TJSONArray;
  I: Integer;
begin
  ValidateStudioInstrumentalConfig(AConfig);
  Result := TJSONObject.Create;
  try
    Result.Add('tempo_bpm', AConfig.Integers['tempo_bpm']);
    Result.Add('tonic', AConfig.Integers['tonic']);
    Result.Add('cells', AConfig.Integers['cells']);
    if AConfig.Find('mode') <> nil then Result.Add('mode', AConfig.Strings['mode']);
    if AConfig.Find('form') <> nil then
      Result.Add('form', EncodeStudioForm(DecodeStudioForm(AConfig.Find('form'))));
    Result.Add('instruments', AConfig.Arrays['instruments'].Clone);
    LLevels := TJSONArray.Create;
    Result.Add('levels', LLevels);
    for I := 0 to 5 do LLevels.Add(AConfig.Arrays['levels'].Integers[I]);
    if AConfig.Find('controls') <> nil then
    begin
      LControls := AConfig.Objects['controls'];
      LParts := DecodeStudioMusicalControls(LControls);
      LRows := TJSONArray.Create;
      Result.Add('controls', TJSONObject.Create(['guide', LControls.Booleans['guide'],
        'tonic_bias', LControls.Integers['tonic_bias'], 'parts', LRows]));
      for I := 0 to High(LParts) do
        LRows.Add(TJSONObject.Create(['minimum_pitch', LParts[I].MinimumPitch,
          'maximum_pitch', LParts[I].MaximumPitch, 'activity_bias', LParts[I].ActivityBias,
          'velocity_percent', LParts[I].Expression.VelocityPercent,
          'gate_percent', LParts[I].Expression.GatePercent]));
    end;
  except
    Result.Free;
    raise;
  end;
end;

end.
