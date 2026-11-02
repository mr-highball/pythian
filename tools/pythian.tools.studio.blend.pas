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
unit pythian.tools.studio.blend;

{$mode delphi}{$H+}

interface

uses fpjson, pythian.music.blend;

const
  StudioBlendFormat = 'pythian.studio.blend.v1';
  StudioBlendSourceFormat = 'pythian.studio.blend-source.v1';
  StudioBlendProviders = 9;
  StudioBlendParts = 6;

{ Metadata-only native boundary. Actual graph/clock/constraint compatibility is
  checked by the primary semantic factory in the cancellable native job. }
function DecodeStudioBlend(const AValue: TJSONData): TMusicBlendPlan;
function StudioBlendSource(const ALeft, ARight, ABlend: TJSONObject): TJSONObject;

implementation

uses SysUtils, pythian.audio;

procedure Need(const ACondition: Boolean; const AMessage: String);
begin
  if not ACondition then
  begin
    raise EAudio.Create(AMessage);
  end;
end;

function Whole(const AObject: TJSONObject; const AKey: String;
  const AMaximum: Integer): Integer;
var
  LValue: TJSONData;
begin
  LValue := AObject.Find(AKey);
  Need((LValue <> nil) and (LValue.JSONType = jtNumber),
    'A blend needs a whole-number choice for ' + AKey);
  Need((LValue.AsFloat = LValue.AsInt64) and (LValue.AsInt64 >= 0) and
    (LValue.AsInt64 <= AMaximum), 'Blend choice is out of range: ' + AKey);
  Result := LValue.AsInteger;
end;

function Rows(const AObject: TJSONObject; const AKey: String;
  const ACount: Integer): TJSONArray;
var
  LValue: TJSONData;
begin
  LValue := AObject.Find(AKey);
  Need((LValue <> nil) and (LValue.JSONType = jtArray) and
    (TJSONArray(LValue).Count = ACount), 'Choose every blend ' + AKey);
  Result := TJSONArray(LValue);
end;

function DecodeStudioBlend(const AValue: TJSONData): TMusicBlendPlan;
var
  LObject: TJSONObject;
  LRows: TJSONArray;
  LRow: TJSONObject;
  I: Integer;
begin
  Result := Default(TMusicBlendPlan);
  Need((AValue <> nil) and (AValue.JSONType = jtObject), 'Blend settings must be an object');
  LObject := TJSONObject(AValue);
  Need((LObject.Count = 9) and (LObject.Get('format', '') = StudioBlendFormat),
    'Unsupported blend settings');
  Need((LObject.Find('right_style_id') <> nil) and
    (LObject.Find('right_style_id').JSONType = jtString), 'Choose style B');
  Need((LObject.Find('union_pitch_ranges') <> nil) and
    (LObject.Find('union_pitch_ranges').JSONType = jtBoolean), 'Choose whether to combine pitch ranges');
  Result.BaseParent := Whole(LObject, 'base_parent', 1);
  Result.MasterParent := Whole(LObject, 'master_parent', 1);
  Result.FormParent := Whole(LObject, 'form_parent', 1);
  Result.Context := TMusicBlendContext(Whole(LObject, 'context', Ord(High(TMusicBlendContext))));
  Result.UnionPitchRanges := LObject.Booleans['union_pitch_ranges'];
  LRows := Rows(LObject, 'providers', StudioBlendProviders);
  SetLength(Result.Providers, StudioBlendProviders);
  for I := 0 to StudioBlendProviders - 1 do
  begin
    Need((LRows[I].JSONType = jtObject) and (TJSONObject(LRows[I]).Count = 3),
      'Every musical provider needs A/B weights and a rule parent');
    LRow := LRows.Objects[I];
    Result.Providers[I].LeftWeight := Whole(LRow, 'left_weight', MaximumMusicBlendWeight);
    Result.Providers[I].RightWeight := Whole(LRow, 'right_weight', MaximumMusicBlendWeight);
    Result.Providers[I].ControlParent := Whole(LRow, 'control_parent', 1);
  end;
  LRows := Rows(LObject, 'parts', StudioBlendParts);
  SetLength(Result.Parts, StudioBlendParts);
  for I := 0 to StudioBlendParts - 1 do
  begin
    Need((LRows[I].JSONType = jtObject) and (TJSONObject(LRows[I]).Count = 3),
      'Every part needs an instrument, effects and expression parent');
    LRow := LRows.Objects[I];
    Result.Parts[I].InstrumentParent := Whole(LRow, 'instrument_parent', 1);
    Result.Parts[I].EffectsParent := Whole(LRow, 'effects_parent', 1);
    Result.Parts[I].ExpressionParent := Whole(LRow, 'expression_parent', 1);
  end;
  ValidateMusicBlendPlan(Result, StudioBlendProviders, StudioBlendParts);
end;

function StudioBlendSource(const ALeft, ARight, ABlend: TJSONObject): TJSONObject;
var
  LPlan: TMusicBlendPlan;
  LParents: array[0..1] of TJSONObject;
begin
  LPlan := DecodeStudioBlend(ABlend);
  LParents[0] := ALeft;
  LParents[1] := ARight;
  Result := TJSONObject(LParents[LPlan.BaseParent].Clone);
  try
    Result.Strings['format'] := StudioBlendSourceFormat;
    Result.Strings['id'] := '';
    Result.Strings['kind'] := 'blend';
    Result.Strings['name'] := ALeft.Strings['name'] + ' + ' + ARight.Strings['name'];
    Result.Strings['left_style_id'] := ALeft.Strings['id'];
    Result.Booleans['has_form'] := LParents[LPlan.FormParent].Booleans['has_form'];
    Result.Add('blend', ABlend.Clone);
    Result.Add('parents', TJSONArray.Create([ALeft.Clone, ARight.Clone]));
  except
    Result.Free;
    raise;
  end;
end;

end.
