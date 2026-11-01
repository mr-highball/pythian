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
unit pythian.tools.effects.json;

{$mode delphi}{$H+}

interface

uses fpjson, pythian.effects.rack;

{ Big Boss: one named-parameter JSON boundary for source and instrumental racks.
  Rate zero performs structural/catalog admission; an actual rate also checks
  Nyquist and processor constraints. Bypassed stages remain valid definitions. }
function DecodeEffectRecipes(const AValue: TJSONData; const AMaximum: Integer;
  const ASampleRate: Integer = 0): TCatalogEffectRecipes;
function EncodeEffectRecipes(const ARecipes: TCatalogEffectRecipes): TJSONArray;

implementation

uses pythian.audio, pythian.effects, pythian.effects.catalog;

procedure Need(const ACondition: Boolean; const AMessage: String);
begin
  if not ACondition then
  begin
    raise EAudio.Create(AMessage);
  end;
end;

function DecodeEffectRecipes(const AValue: TJSONData; const AMaximum: Integer;
  const ASampleRate: Integer): TCatalogEffectRecipes;
var
  LRows: TJSONArray;
  LRow: TJSONObject;
  LData: TJSONData;
  LDefinition: TEffectDefinition;
  LParameter: TEffectParameter;
  LMaximum: Double;
  LKeys: String;
  I: Integer;
  J: Integer;
  K: Integer;
begin
  Result := nil;
  Need((AValue <> nil) and (AValue.JSONType = jtArray), 'Effect stack must be an array');
  LRows := TJSONArray(AValue);
  Need((AMaximum >= 0) and (AMaximum <= MaximumEffects) and
    (LRows.Count <= AMaximum), 'Effect stack exceeds the stage limit');
  SetLength(Result, LRows.Count);
  for I := 0 to High(Result) do
  begin
    Need(LRows[I].JSONType = jtObject, 'Effect stage must be an object');
    LRow := LRows.Objects[I];
    LData := LRow.Find('kind');
    Need((LData <> nil) and (LData.JSONType = jtString), 'Effect kind must be text');
    Need(FindEffectDefinition(LData.AsString, LDefinition), 'Choose an available effect');
    LData := LRow.Find('bypass');
    Need((LData <> nil) and (LData.JSONType = jtBoolean), 'Each effect stage must declare bypass');
    Result[I] := DefaultEffectRecipe(LDefinition.Kind);
    Result[I].Bypass := LData.AsBoolean;
    LKeys := '|kind|bypass|';
    for J := 0 to High(LDefinition.Parameters) do
    begin
      LParameter := LDefinition.Parameters[J];
      LKeys := LKeys + LParameter.Key + '|';
      LData := LRow.Find(LParameter.Key);
      Need((LData <> nil) and (LData.JSONType = jtNumber),
        'Effect setting requires a number: ' + LParameter.Key);
      Result[I].Settings.Values[J] := LData.AsFloat;
      RequireFinite(Result[I].Settings.Values[J], LParameter.Key);
      LMaximum := LParameter.Maximum;
      if ASampleRate <> 0 then
      begin
        LMaximum := EffectParameterMaximum(LParameter, ASampleRate);
      end;
      Need((Result[I].Settings.Values[J] >= LParameter.Minimum) and
        (Result[I].Settings.Values[J] <= LMaximum),
        'Effect setting is outside its bound: ' + LParameter.Key);
    end;
    Need(LRow.Count = Length(LDefinition.Parameters) + 2, 'Effect stage has missing or repeated settings');
    for J := 0 to LRow.Count - 1 do
    begin
      Need(Pos('|' + LRow.Names[J] + '|', LKeys) > 0, 'Unsupported effect setting');
      for K := 0 to J - 1 do
      begin
        Need(LRow.Names[K] <> LRow.Names[J], 'Repeated effect setting');
      end;
    end;
  end;
  if ASampleRate <> 0 then
  begin
    ValidateEffectRecipes(Result, ASampleRate);
  end;
end;

function EncodeEffectRecipes(const ARecipes: TCatalogEffectRecipes): TJSONArray;
var
  LRow: TJSONObject;
  LDefinition: TEffectDefinition;
  I: Integer;
  J: Integer;
begin
  Result := TJSONArray.Create;
  try
    for I := 0 to High(ARecipes) do
    begin
      LDefinition := EffectDefinition(ARecipes[I].Settings.Kind);
      Need(Length(ARecipes[I].Settings.Values) = Length(LDefinition.Parameters),
        'Effect parameter count differs from its catalog definition');
      LRow := TJSONObject.Create(['kind', LDefinition.Key, 'bypass', ARecipes[I].Bypass]);
      Result.Add(LRow);
      for J := 0 to High(LDefinition.Parameters) do
      begin
        LRow.Add(LDefinition.Parameters[J].Key, ARecipes[I].Settings.Values[J]);
      end;
    end;
  except
    Result.Free;
    raise;
  end;
end;

end.
