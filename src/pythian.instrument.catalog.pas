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
unit pythian.instrument.catalog;

{$mode delphi}{$H+}

interface

uses pythian.instrument.recipe;

{ Detached authored starting points, not learned instrument identifications.
  Callers may edit, append or replace recipes; no global registry owns them.
  Realization validates the requested rate and complete declared key range. }
function BuiltInInstrumentRecipes: TInstrumentRecipes;
function FindInstrumentRecipe(const ARecipes: TInstrumentRecipes;
  const AId: String): TInstrumentRecipe;

implementation

uses pythian.audio, pythian.oscillator;

function NewRecipe(const AId, ACaption: String): TInstrumentRecipe;
begin
  Result := Default(TInstrumentRecipe);
  Result.Id := AId;
  Result.Caption := ACaption;
  Result.Origin := 'Pythian authored';
  SetLength(Result.Zones, 1);
  Result.Zones[0] := DefaultInstrumentZoneRecipe;
  Result.Zones[0].Voice.Gain := 0.18;
end;

function BuiltInInstrumentRecipes: TInstrumentRecipes;
var I: Integer;
begin
  Result := nil;
  SetLength(Result, 8);
  Result[0] := NewRecipe('sub-bass', 'Sub bass');
  with Result[0].Zones[0] do
  begin
    Voice.Shape := wsSine;
    Voice.CutoffHz := 600;
    Voice.Envelope.AttackSeconds := 0.008;
    Voice.Envelope.ReleaseSeconds := 0.08;
  end;
  Result[1] := NewRecipe('soft-lead', 'Soft triangle lead');
  with Result[1].Zones[0] do
  begin
    Voice.Shape := wsTriangle;
    Voice.Envelope.AttackSeconds := 0.015;
    Voice.Envelope.ReleaseSeconds := 0.12;
    SetLength(Controls, 1);
    Controls[0].Target := ictPitchCents;
    Controls[0].Curve := DefaultInstrumentCurve;
    Controls[0].Curve.Kind := ickLfo;
    Controls[0].Curve.LfoHz := 4.8;
    Controls[0].Curve.Scale := 9;
  end;
  Result[2] := NewRecipe('noise-hat', 'Noise hi-hat');
  with Result[2].Zones[0] do
  begin
    Voice.Shape := wsNoise;
    Voice.CutoffHz := 3000;
    Voice.Envelope.AttackSeconds := 0.001;
    Voice.Envelope.DecaySeconds := 0.055;
    Voice.Envelope.SustainLevel := 0;
    Voice.Envelope.ReleaseSeconds := 0.01;
  end;
  Result[3] := NewRecipe('additive-keys', 'Additive keys');
  with Result[3].Zones[0] do
  begin
    Source.Kind := iskAdditive;
    SetLength(Source.Partials, 4);
    for I := 0 to 3 do
    begin
      Source.Partials[I].Ratio := I + 1;
      Source.Partials[I].Gain := 0.65 / (I + 1);
    end;
    Voice.Envelope.DecaySeconds := 0.25;
    Voice.Envelope.SustainLevel := 0.25;
    Voice.Envelope.ReleaseSeconds := 0.25;
  end;
  Result[4] := NewRecipe('moving-pad', 'Moving wavetable pad');
  with Result[4].Zones[0] do
  begin
    Source.Kind := iskWavetable;
    SetLength(Source.Tables, 2);
    SetLength(Source.Tables[0].Sine, 1);
    Source.Tables[0].Sine[0] := 0.8;
    SetLength(Source.Tables[1].Sine, 3);
    Source.Tables[1].Sine[0] := 0.5;
    Source.Tables[1].Sine[1] := 0.2;
    Source.Tables[1].Sine[2] := 0.1;
    Source.TableMotion.Kind := ickLfo;
    Source.TableMotion.LfoHz := 0.4;
    Source.TableMotion.Scale := 0.5;
    Source.TableMotion.Offset := 0.5;
    Voice.Envelope.AttackSeconds := 0.12;
    Voice.Envelope.ReleaseSeconds := 0.4;
  end;
  Result[5] := NewRecipe('fm-bell', 'FM bell');
  with Result[5].Zones[0] do
  begin
    Source.Kind := iskFm;
    Source.ModulatorRatio := 2;
    Source.ModulationDepth := 120;
    Voice.Envelope.AttackSeconds := 0.002;
    Voice.Envelope.DecaySeconds := 0.4;
    Voice.Envelope.SustainLevel := 0.12;
    Voice.Envelope.ReleaseSeconds := 0.3;
  end;
  Result[6] := NewRecipe('pm-tine', 'PM tine');
  with Result[6].Zones[0] do
  begin
    Source.Kind := iskPm;
    Source.ModulatorRatio := 2;
    Source.ModulationDepth := 1.4;
    Voice.Envelope.AttackSeconds := 0.002;
    Voice.Envelope.DecaySeconds := 0.3;
    Voice.Envelope.SustainLevel := 0.2;
    Voice.Envelope.ReleaseSeconds := 0.2;
  end;
  Result[7] := NewRecipe('layered-pad', 'Layered key and velocity pad');
  with Result[7] do
  begin
    SetLength(Zones, 3);
    for I := 0 to 2 do
    begin
      Zones[I] := DefaultInstrumentZoneRecipe;
      Zones[I].Voice.Gain := 0.09;
      Zones[I].Voice.Envelope.AttackSeconds := 0.08;
      Zones[I].Voice.Envelope.ReleaseSeconds := 0.3;
    end;
    Zones[0].MaximumKey := 59;
    Zones[0].Voice.Shape := wsTriangle;
    Zones[0].Voice.Pan := -0.2;
    Zones[1].MinimumKey := 60;
    Zones[1].Voice.Shape := wsSaw;
    Zones[1].Voice.Pan := -0.2;
    Zones[2].MinimumKey := 48;
    Zones[2].MinimumVelocity := 96;
    Zones[2].Voice.Shape := wsSine;
    Zones[2].Voice.Pan := 0.2;
  end;
end;

function FindInstrumentRecipe(const ARecipes: TInstrumentRecipes;
  const AId: String): TInstrumentRecipe;
var I, LFound: Integer;
begin
  LFound := -1;
  for I := 0 to High(ARecipes) do
    if ARecipes[I].Id = AId then
    begin
      if LFound >= 0 then raise EAudio.Create('Instrument recipe identity is ambiguous');
      LFound := I;
    end;
  if LFound < 0 then raise EAudio.Create('Instrument recipe is not in this catalog');
  Result := CopyInstrumentRecipe(ARecipes[LFound]);
end;

end.
