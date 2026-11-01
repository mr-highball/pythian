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
program pythian_tests_mix_recipe;

{$mode delphi}{$H+}

uses SysUtils, Math, pythian.audio, pythian.bus, pythian.mix.recipe,
  pythian.effects.catalog;

var
  GChecks: Integer;

procedure Check(const ACondition: Boolean; const AMessage: String);
begin
  Inc(GChecks);
  if not ACondition then
  begin
    raise Exception.Create(AMessage);
  end;
end;

procedure CheckEffects;
var
  LBase: TStemMixRecipe;
  LRecipe: TStemMixRecipe;
  LExport: TStemMixRecipe;
  LDry: TBusGraph;
  LWet: TBusGraph;
  LBypass: TBusGraph;
  LInputs: TBusFrames;
  LLeft: Double;
  LRight: Double;
  LUnused: Double;
  LDifference: Double;
  LDryFrame: TStereoFrame;
  LWetFrame: TStereoFrame;
  LBypassFrame: TStereoFrame;
  LKind: TCatalogEffect;
  LDefinition: TEffectDefinition;
  I: Integer;
  J: Integer;
begin
  LBase := DefaultStemMixRecipe(2);
  SetLength(LInputs, 5);
  for LKind := Low(TCatalogEffect) to High(TCatalogEffect) do
  begin
    LRecipe := CopyStemMixRecipe(LBase);
    SetLength(LRecipe.Parts[0].Effects, 1);
    LRecipe.Parts[0].Effects[0].Settings := DefaultCatalogEffect(LKind);
    LDefinition := EffectDefinition(LKind);
    for J := 0 to High(LDefinition.Parameters) do
    begin
      if LDefinition.Parameters[J].Key = 'gain_db' then
      begin
        LRecipe.Parts[0].Effects[0].Settings.Values[J] := -6;
      end
      else if LDefinition.Parameters[J].Key = 'ceiling_db' then
      begin
        LRecipe.Parts[0].Effects[0].Settings.Values[J] := -12;
      end
      else if LDefinition.Parameters[J].Key = 'pan' then
      begin
        LRecipe.Parts[0].Effects[0].Settings.Values[J] := -0.5;
      end;
    end;
    LWet := CreateStemMixGraph(LRecipe, 8000);
    LDry := nil;
    LBypass := nil;
    try
      { Per-stage bypass uses the same retained definition as source racks. }
      LRecipe.Parts[0].Effects[0].Bypass := True;
      LBypass := CreateStemMixGraph(LRecipe, 8000);
      LExport := CopyStemMixRecipe(LRecipe);
      LExport.Parts[0].Effects[0].Settings.Values[0] := 123456;
      Check(LRecipe.Parts[0].Effects[0].Settings.Values[0] <> 123456, 'Mix recipe export aliases its input');
      LRecipe.Parts[0].Effects[0].Settings.Values[0] := 123456;
      LDry := CreateStemMixGraph(LBase, 8000);
      LDifference := 0;
      for I := 0 to 4095 do
      begin
        LInputs[0].Left := 0;
        LInputs[0].Right := 0;
        if I < 1024 then
        begin
          LInputs[0].Left := 0.8 * Sin(I * 0.3);
          LInputs[0].Right := LInputs[0].Left;
        end;
        LInputs[1].Left := 0.03 * Cos(I * 0.7);
        LInputs[1].Right := LInputs[1].Left;
        LWet.Process(LInputs, LLeft, LRight);
        Check(not IsNan(LLeft) and not IsInfinite(LLeft) and (Abs(LLeft) <= 1), 'Mix output is unsafe');
        LDry.Process(LInputs, LUnused, LRight);
        LBypass.Process(LInputs, LUnused, LRight);
        LDryFrame := LDry.LastOutput(3);
        LWetFrame := LWet.LastOutput(3);
        if (LDryFrame.Left <> LWetFrame.Left) or (LDryFrame.Right <> LWetFrame.Right) then
        begin
          raise Exception.Create('One part effect changed another stem');
        end;
        LDryFrame := LDry.LastOutput(2);
        LWetFrame := LWet.LastOutput(2);
        LBypassFrame := LBypass.LastOutput(2);
        if (LDryFrame.Left <> LBypassFrame.Left) or (LDryFrame.Right <> LBypassFrame.Right) then
        begin
          raise Exception.Create('Dry bypass changed the protected dry path');
        end;
        LDifference := LDifference + Abs(LDryFrame.Left - LWetFrame.Left) +
          Abs(LDryFrame.Right - LWetFrame.Right);
      end;
      Check(LDifference > 0.000001, 'Selected effect had no actual output effect: ' + LDefinition.Key);
      Check(not LWet.Failed and not LDry.Failed and not LBypass.Failed, 'Mix graph failed');
    finally
      LWet.Free;
      LDry.Free;
      LBypass.Free;
    end;
  end;
end;

procedure CheckPartPan;
var
  LRecipe: TStemMixRecipe;
  LDry: TBusGraph;
  LPanned: TBusGraph;
  LInputs: TBusFrames;
  LLeft: Double;
  LRight: Double;
  LStem: TStereoFrame;
  LOther: TStereoFrame;
  I: Integer;
begin
  LRecipe := DefaultStemMixRecipe(2);
  LDry := CreateStemMixGraph(LRecipe, 8000);
  LPanned := nil;
  try
    LRecipe.Parts[0].Pan := -1;
    LPanned := CreateStemMixGraph(LRecipe, 8000);
    SetLength(LInputs, 5);
    LInputs[0].Left := 0.2;
    LInputs[0].Right := 0.2;
    LInputs[1].Left := 0.05;
    LInputs[1].Right := 0.05;
    for I := 0 to 127 do
    begin
      LDry.Process(LInputs, LLeft, LRight);
      LPanned.Process(LInputs, LLeft, LRight);
      LStem := LPanned.LastOutput(2);
      Check((LStem.Left > 0) and (LStem.Right = 0), 'Part pan has no actual channel effect');
      LStem := LPanned.LastOutput(3);
      LOther := LDry.LastOutput(3);
      Check((LStem.Left = LOther.Left) and (LStem.Right = LOther.Right),
        'Part pan changed an unrelated stem');
    end;
  finally
    LPanned.Free;
    LDry.Free;
  end;
end;

procedure CheckFailure;
var
  LRecipe: TStemMixRecipe;
  LGraph: TBusGraph;
  LRejected: Boolean;
begin
  LRecipe := DefaultStemMixRecipe(6);
  LRecipe.Parts[5].Gain := 2;
  LGraph := nil;
  LRejected := False;
  try
    try
      LGraph := CreateStemMixGraph(LRecipe, 24000);
    except
      on EAudio do LRejected := True;
    end;
    Check(LRejected, 'Invalid later part was admitted');
  finally
    LGraph.Free;
  end;
end;

begin
  CheckEffects;
  CheckPartPan;
  CheckFailure;
  WriteLn('Mix recipe checks=', GChecks, '; all catalog effects, isolated stems, balance and dry bypass');
end.
