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
program pythian_tests_instrument_recipe;

{$mode delphi}{$H+}

uses SysUtils, Math, pythian.audio, pythian.synth, pythian.instrument.recipe,
  pythian.instrument.catalog, pythian.automation, pythian.source.sample,
  pythian.sound.recipe.codec, pythian.hash
  {$ifndef pas2js}, pythian.wave{$endif};

const CRate = 24000;
var GChecks: Integer;

procedure Check(const ACondition: Boolean; const AMessage: String);
begin
  Inc(GChecks);
  if not ACondition then raise Exception.Create(AMessage);
end;

function Energy(const AClip: TAudioClip): Double;
var I, J: Integer; LValue: Double;
begin
  Result := 0;
  for I := 0 to AClip.FrameCount - 1 do
    for J := 0 to AClip.Channels - 1 do
    begin
      LValue := AClip.SampleAt(I, J);
      if IsNan(LValue) or IsInfinite(LValue) or (Abs(LValue) > 1) then
        raise Exception.Create('Recipe output must remain finite and controlled');
      Result := Result + LValue * LValue;
    end;
end;

procedure Compare(const A, B: TAudioClip; const AScale: Double);
var I, J: Integer;
begin
  Check((A.FrameCount = B.FrameCount) and (A.SampleRate = B.SampleRate) and
    (A.Channels = B.Channels), 'Recipe render clock changed');
  for I := 0 to A.FrameCount - 1 do
    for J := 0 to A.Channels - 1 do
      if Abs(A.SampleAt(I, J) * AScale - B.SampleAt(I, J)) > 0.000001 then
        raise Exception.Create('Recipe replay or gain control changed');
  Check(True, 'All replay/control samples matched');
end;

function Audition(const AInstrument: TRecipeInstrument): TAudioClip;
begin
  Result := RenderFrameTones(AInstrument.Instrument.PlanNote(69, 110,
    CRate, 0, 4800, 731), CRate);
end;

procedure RejectRecipe(const ARecipe: TInstrumentRecipe);
var LBank: TRecipeInstrument; LRejected: Boolean;
begin
  LBank := nil;
  LRejected := False;
  try
    try LBank := TRecipeInstrument.Create(ARecipe, CRate)
    except on EAudio do LRejected := True end;
    Check(LRejected, 'Invalid or borrowed recipe admitted');
  finally LBank.Free end;
end;

procedure CheckCatalog;
var LCatalog: TInstrumentRecipes; LRecipe, LCopy, LVerify: TInstrumentRecipe;
  LBank, LChanged: TRecipeInstrument; LA, LB: TAudioClip;
  LSignals: array of TAudioSamples; I, J, K: Integer;
  LRejected, LDifferent: Boolean;
begin
  LCatalog := BuiltInInstrumentRecipes;
  Check(Length(LCatalog) = 8, 'Authored catalog entries differ');
  SetLength(LSignals, Length(LCatalog));
  for I := 0 to High(LCatalog) do
  begin
    LRecipe := FindInstrumentRecipe(LCatalog, LCatalog[I].Id);
    LCopy := DecodeInstrumentRecipe(EncodeInstrumentRecipe(LRecipe));
    Check(Sha256Bytes(EncodeInstrumentRecipe(LCopy)) =
      Sha256Bytes(EncodeInstrumentRecipe(LRecipe)), 'Primary saved recipe is canonical');
    LChanged := TRecipeInstrument.Create(LCopy, CRate);
    LBank := nil;
    try
      LBank := TRecipeInstrument.Create(LRecipe, CRate);
      LA := Audition(LBank);
      LB := nil;
      try
        LB := Audition(LChanged);
        Compare(LA, LB, 1);
      finally
        LB.Free;
        LA.Free;
      end;
    finally
      LBank.Free;
      LChanged.Free;
    end;
    LBank := TRecipeInstrument.Create(LRecipe, CRate);
    try
      LA := Audition(LBank);
      try
        Check(Energy(LA) > 0.0001, 'Catalog recipe is silent');
        LSignals[I] := LA.CopySamples;
        Check(LA.FrameCount > 4800, 'Release history was truncated');
        LRecipe.Zones[0].Voice.Gain := 0;
        if Length(LRecipe.Zones[0].Source.Partials) > 0 then
          LRecipe.Zones[0].Source.Partials[0].Gain := 99;
        if Length(LRecipe.Zones[0].Source.Tables) > 0 then
          LRecipe.Zones[0].Source.Tables[0].Sine[0] := 99;
        LCopy := LBank.CopyRecipe;
        Check(LCopy.Zones[0].Voice.Gain > 0, 'Voice definition aliases caller');
        if Length(LCopy.Zones[0].Source.Partials) > 0 then
        begin
          Check(LCopy.Zones[0].Source.Partials[0].Gain < 1, 'Saved partials alias input');
          LCopy.Zones[0].Source.Partials[0].Gain := 88;
          LVerify := LBank.CopyRecipe;
          Check(LVerify.Zones[0].Source.Partials[0].Gain < 1, 'Saved partials alias exported copy');
        end;
        if Length(LCopy.Zones[0].Source.Tables) > 0 then
        begin
          Check(LCopy.Zones[0].Source.Tables[0].Sine[0] < 1, 'Saved tables alias input');
          LCopy.Zones[0].Source.Tables[0].Sine[0] := 88;
          LVerify := LBank.CopyRecipe;
          Check(LVerify.Zones[0].Source.Tables[0].Sine[0] < 1, 'Saved tables alias exported copy');
        end;
        LCopy.Zones[0].Voice.Gain := 0;
        LB := Audition(LBank);
        try Compare(LA, LB, 1) finally LB.Free end;
        LCopy := LBank.CopyRecipe;
        for J := 0 to High(LCopy.Zones) do
          LCopy.Zones[J].Voice.Gain := LCopy.Zones[J].Voice.Gain * 0.5;
        LChanged := TRecipeInstrument.Create(LCopy, CRate);
        try
          LB := Audition(LChanged);
          try Compare(LA, LB, 0.5) finally LB.Free end;
        finally LChanged.Free end;
        {$ifndef pas2js}
        if ParamCount = 1 then
          SaveWavePcm16(IncludeTrailingPathDelimiter(ParamStr(1)) + LCatalog[I].Id + '.wav', LA);
        {$endif}
      finally LA.Free end;
    finally LBank.Free end;
  end;
  for I := 0 to High(LSignals) do
    for J := I + 1 to High(LSignals) do
    begin
      LDifferent := False;
      for K := 0 to Min(Length(LSignals[I]), Length(LSignals[J])) - 1 do
        if Abs(LSignals[I][K] - LSignals[J][K]) > 0.000001 then
        begin
          LDifferent := True;
          Break;
        end;
      Check(LDifferent, 'Catalog choices did not change the sounding samples');
    end;
  LRecipe := FindInstrumentRecipe(LCatalog, 'layered-pad');
  LBank := TRecipeInstrument.Create(LRecipe, CRate);
  try
    Check(Length(LBank.Instrument.SelectZones(48, 95)) = 1, 'Quiet lower zone changed');
    Check(Length(LBank.Instrument.SelectZones(48, 96)) = 2, 'Velocity layer missing');
    Check(Length(LBank.Instrument.SelectZones(72, 110)) = 2, 'Upper key layer missing');
    Check(Length(LBank.Instrument.SelectZones(36, 110)) = 1, 'Layer extends below its key range');
  finally LBank.Free end;
  SetLength(LCatalog, Length(LCatalog) + 1);
  LCatalog[High(LCatalog)] := CopyInstrumentRecipe(LCatalog[0]);
  LCatalog[High(LCatalog)].Id := 'caller-patch';
  LRecipe := FindInstrumentRecipe(LCatalog, 'caller-patch');
  Check(LRecipe.Id = 'caller-patch', 'Caller recipe extension disappeared');
  LRejected := False;
  try LRecipe := FindInstrumentRecipe(LCatalog, 'absent')
  except on EAudio do LRejected := True end;
  Check(LRejected, 'Unknown recipe silently selected another sound');
  LCatalog[High(LCatalog)].Id := LCatalog[0].Id;
  LRejected := False;
  try LRecipe := FindInstrumentRecipe(LCatalog, LCatalog[0].Id)
  except on EAudio do LRejected := True end;
  Check(LRejected, 'Ambiguous catalog identity selected an arbitrary patch');
end;

procedure CheckGateAndSample;
var LRecipe: TInstrumentRecipe; LBank: TRecipeInstrument;
  LSamples: TInstrumentSampleBindings; LData: TAudioSamples;
  LClip, LOutput: TAudioClip;
begin
  LRecipe := FindInstrumentRecipe(BuiltInInstrumentRecipes, 'sub-bass');
  with LRecipe.Zones[0].Gate do
  begin
    Enabled := True;
    SetLength(Held.Points, 2);
    Held.Points[0].Value := 0;
    Held.Points[0].Transition := atLinear;
    Held.Points[1].Seconds := 0.01;
    Held.Points[1].Value := 1;
    ReleaseSeconds := 0.04;
    SetLength(Release.Points, 2);
    Release.Points[0].Value := 1;
    Release.Points[0].Transition := atLinear;
    Release.Points[1].Seconds := ReleaseSeconds;
    Release.Points[1].Value := 0;
  end;
  LBank := TRecipeInstrument.Create(LRecipe, CRate);
  try
    LRecipe.Zones[0].Gate.Held.Points[1].Value := 0;
    Check(LBank.CopyRecipe.Zones[0].Gate.Held.Points[1].Value = 1,
      'Saved envelope aliases input');
    LOutput := Audition(LBank);
    try
      Check((LOutput.FrameCount = 5760) and (Energy(LOutput) > 0),
        'Detached custom envelope/release did not sound');
    finally LOutput.Free end;
  finally LBank.Free end;
  LRecipe.Zones[0].Gate.Held.Points[1].Value := 1;
  LRecipe.Zones[0].Gate.ReleaseSeconds := 0;
  LRecipe.Zones[0].Gate.Release.Points := nil;
  LBank := TRecipeInstrument.Create(LRecipe, CRate);
  try
    LOutput := Audition(LBank);
    try Check((LOutput.FrameCount = 4800) and (Energy(LOutput) > 0),
      'Explicit immediate gate release was rejected or extended')
    finally LOutput.Free end;
  finally LBank.Free end;
  LRecipe.Zones[0].Gate.Held.Points[1].Seconds := 0.000001;
  RejectRecipe(LRecipe);
  LRecipe := FindInstrumentRecipe(BuiltInInstrumentRecipes, 'sub-bass');
  LRecipe.Id := 'explicit-test-sampler';
  LRecipe.Origin := 'Authored four-frame sample';
  LRecipe.Zones[0].Source.Kind := iskSample;
  LRecipe.Zones[0].Source.SampleId := 'four-frame';
  LRecipe.Zones[0].Source.SamplePlayback := spSustainLoop;
  LRecipe.Zones[0].Source.SampleQuality := sqLinear;
  RejectRecipe(LRecipe);
  SetLength(LData, 4);
  LData[0] := 0.5; LData[1] := 0.25; LData[2] := -0.5; LData[3] := -0.25;
  LClip := TAudioClip.Create(CRate, 1, LData);
  try
    SetLength(LSamples, 1);
    LSamples[0].Id := 'four-frame'; LSamples[0].Clip := LClip;
    LBank := TRecipeInstrument.Create(LRecipe, CRate, LSamples);
  finally LClip.Free end;
  try
    LOutput := Audition(LBank);
    try Check(Energy(LOutput) > 0.001, 'Sampler borrowed freed caller audio')
    finally LOutput.Free end;
  finally LBank.Free end;
end;

procedure CheckPlayedKeyAdmission;
var
  LRecipe: TInstrumentRecipe;
  LBank: TRecipeInstrument;
  LClip: TAudioClip;
  LRejected: Boolean;
begin
  LRecipe := FindInstrumentRecipe(BuiltInInstrumentRecipes, 'sub-bass');
  LRecipe.Zones[0].MinimumKey := 0;
  LRecipe.Zones[0].MaximumKey := 127;
  LBank := TRecipeInstrument.Create(LRecipe, CRate);
  try
    LClip := Audition(LBank);
    try
      Check(Energy(LClip) > 0, 'Broad key range rejected a supported played key');
    finally
      LClip.Free;
    end;
    LRejected := False;
    try
      LBank.Instrument.PlanNote(127, 110, CRate, 0, 4800, 731);
    except
      on EAudio do LRejected := True;
    end;
    Check(LRejected, 'Actual unsupported high key was silently clipped or retuned');
  finally
    LBank.Free;
  end;
end;

procedure CheckFailures;
var LRecipe: TInstrumentRecipe; LCurve: TAutomationCurve;
  LPoints: TAutomationPoints; LRejected: Boolean;
begin
  LRecipe := FindInstrumentRecipe(BuiltInInstrumentRecipes, 'soft-lead');
  SetLength(LRecipe.Zones[0].Controls, 2);
  LRecipe.Zones[0].Controls[1] := LRecipe.Zones[0].Controls[0];
  RejectRecipe(LRecipe);
  LRecipe := FindInstrumentRecipe(BuiltInInstrumentRecipes, 'moving-pad');
  LRecipe.Zones[0].Source.Tables := nil;
  RejectRecipe(LRecipe);
  LRecipe := FindInstrumentRecipe(BuiltInInstrumentRecipes, 'fm-bell');
  LRecipe.Zones[0].Source.ModulatorRatio := -1;
  RejectRecipe(LRecipe);
  LRecipe := FindInstrumentRecipe(BuiltInInstrumentRecipes, 'sub-bass');
  SetLength(LPoints, 1);
  LPoints[0].Value := 1;
  LCurve := TAutomationCurve.Create(LPoints);
  try
    LRecipe.Zones[0].Voice.Automation.GainMultiplier := LCurve;
    RejectRecipe(LRecipe);
    LRejected := False;
    try LRecipe := CopyInstrumentRecipe(LRecipe)
    except on EAudio do LRejected := True end;
    Check(LRejected, 'Copy exported a borrowed runtime pointer');
  finally LCurve.Free end;
end;

begin
  CheckCatalog;
  CheckGateAndSample;
  CheckPlayedKeyAdmission;
  CheckFailures;
  WriteLn('Instrument recipe/catalog checks=', GChecks);
end.
