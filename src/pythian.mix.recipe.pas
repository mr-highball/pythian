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
unit pythian.mix.recipe;

{$mode delphi}{$H+}

interface

uses pythian.bus, pythian.effects.catalog, pythian.effects.rack;

type
  TEffectRecipes = TCatalogEffectRecipes;
  TPartMixRecipe = record
    Gain: Double;
    Pan: Double;
    BypassEffects: Boolean;
    Effects: TEffectRecipes;
  end;
  TPartMixRecipes = array of TPartMixRecipe;
  TStemMixRecipe = record
    Parts: TPartMixRecipes;
    StemGain: Double;
    MasterGain: Double;
    MasterEffects: TEffectRecipes;
    BypassEffects: Boolean;
    LimitOutputs: Boolean;
    CeilingDb: Double;
    LimiterReleaseSeconds: Double;
    { Explicit saved zero-input tail; no claim of infinite effect decay. }
    TailSeconds: Double;
  end;

function DefaultStemMixRecipe(const AParts: Integer): TStemMixRecipe;
function CopyStemMixRecipe(const ARecipe: TStemMixRecipe): TStemMixRecipe;
procedure ValidateStemMixRecipe(const ARecipe: TStemMixRecipe;
  const ASampleRate: Integer);
{ Owned graph. Inputs0..N-1 each run their effects exactly once, then feed both
  stem busesN..2N-1 and master2N through post-fader sends. Stems and master have
  independent output limiters. Changing pull boundaries never resets history.
  No I/O, WFC, device or browser dependency; caller owns the returned graph. }
function CreateStemMixGraph(const ARecipe: TStemMixRecipe;
  const ASampleRate: Integer): TBusGraph;

implementation

uses pythian.audio, pythian.effects;

function OutputLimiterSettings(const ARecipe: TStemMixRecipe): TCatalogEffectSettings;
var
  LDefinition: TEffectDefinition;
  I: Integer;
begin
  Result := DefaultCatalogEffect(ceLimiter);
  LDefinition := EffectDefinition(ceLimiter);
  for I := 0 to High(LDefinition.Parameters) do
  begin
    if LDefinition.Parameters[I].Key = 'ceiling_db' then
    begin
      Result.Values[I] := ARecipe.CeilingDb;
    end
    else if LDefinition.Parameters[I].Key = 'release_ms' then
    begin
      Result.Values[I] := ARecipe.LimiterReleaseSeconds * 1000;
    end;
  end;
end;

function DefaultStemMixRecipe(const AParts: Integer): TStemMixRecipe;
var
  I: Integer;
begin
  if (AParts < 1) or (AParts > (MaximumBuses - 1) div 2) then
  begin
    raise EAudio.Create('Stem mix needs1..15 source parts');
  end;
  Result := Default(TStemMixRecipe);
  SetLength(Result.Parts, AParts);
  for I := 0 to High(Result.Parts) do
  begin
    Result.Parts[I].Gain := 1;
  end;
  Result.StemGain := 0.7;
  Result.MasterGain := 0.7;
  Result.LimitOutputs := True;
  Result.CeilingDb := -1;
  Result.LimiterReleaseSeconds := 0.08;
  Result.TailSeconds := 1;
end;

function CopyStemMixRecipe(const ARecipe: TStemMixRecipe): TStemMixRecipe;
var
  I: Integer;
begin
  Result := ARecipe;
  Result.Parts := Copy(ARecipe.Parts);
  for I := 0 to High(Result.Parts) do
  begin
    Result.Parts[I].Effects := CopyEffectRecipes(ARecipe.Parts[I].Effects);
  end;
  Result.MasterEffects := CopyEffectRecipes(ARecipe.MasterEffects);
end;

procedure ValidateStemMixRecipe(const ARecipe: TStemMixRecipe;
  const ASampleRate: Integer);
var
  I: Integer;
  J: Integer;
begin
  ValidateAudioFormat(ASampleRate, 2);
  if (Length(ARecipe.Parts) < 1) or
    (Length(ARecipe.Parts) > (MaximumBuses - 1) div 2) then
  begin
    raise EAudio.Create('Stem mix needs1..15 source parts');
  end;
  RequireFinite(ARecipe.StemGain, 'Stem gain');
  RequireFinite(ARecipe.MasterGain, 'Master gain');
  RequireFinite(ARecipe.TailSeconds, 'Effect tail');
  if (ARecipe.StemGain < 0) or (ARecipe.StemGain > 1) or
    (ARecipe.MasterGain < 0) or (ARecipe.MasterGain > 1) or
    (ARecipe.TailSeconds < 0) or (ARecipe.TailSeconds > 86400) then
  begin
    raise EAudio.Create('Mix output gains must be0..1; tail must be0..86400seconds');
  end;
  if (Length(ARecipe.MasterEffects) + Ord(ARecipe.LimitOutputs) > MaximumEffects) then
  begin
    raise EAudio.Create('Master effect chain exceeds the primary stage limit');
  end;
  if ARecipe.LimitOutputs then
  begin
    ValidateCatalogEffect(OutputLimiterSettings(ARecipe), ASampleRate);
  end;
  for I := 0 to High(ARecipe.MasterEffects) do
  begin
    ValidateCatalogEffect(ARecipe.MasterEffects[I].Settings, ASampleRate);
  end;
  for I := 0 to High(ARecipe.Parts) do
  begin
    RequireFinite(ARecipe.Parts[I].Gain, 'Part gain');
    RequireFinite(ARecipe.Parts[I].Pan, 'Part pan');
    if (ARecipe.Parts[I].Gain < 0) or (ARecipe.Parts[I].Gain > 1) or
      (ARecipe.Parts[I].Pan < -1) or (ARecipe.Parts[I].Pan > 1) or
      (Length(ARecipe.Parts[I].Effects) + Ord(ARecipe.Parts[I].Pan <> 0) > MaximumEffects) then
    begin
      raise EAudio.Create('Part gain must be0..1, pan must be-1..1, within the primary effect stage limit');
    end;
    for J := 0 to High(ARecipe.Parts[I].Effects) do
    begin
      ValidateCatalogEffect(ARecipe.Parts[I].Effects[J].Settings, ASampleRate);
    end;
  end;
end;

function CreateStemMixGraph(const ARecipe: TStemMixRecipe;
  const ASampleRate: Integer): TBusGraph;
var
  LSettings: array of TBusSettings;
  LGraph: TBusGraph;
  LCount: Integer;
  I: Integer;
  J: Integer;

  procedure AddOwned(const ABus: Integer; AEffect: TAudioEffect);
  begin
    try
      LGraph.AddEffect(ABus, AEffect);
    except
      AEffect.Free;
      raise;
    end;
  end;

begin
  ValidateStemMixRecipe(ARecipe, ASampleRate);
  LCount := Length(ARecipe.Parts);
  SetLength(LSettings, LCount * 2 + 1);
  for I := 0 to High(LSettings) do
  begin
    LSettings[I] := Default(TBusSettings);
    if I < LCount then
    begin
      LSettings[I].Gain := ARecipe.Parts[I].Gain;
    end
    else if I < LCount * 2 then
    begin
      LSettings[I].Gain := ARecipe.StemGain;
    end
    else
    begin
      LSettings[I].Gain := ARecipe.MasterGain;
    end;
  end;
  LGraph := TBusGraph.Create(ASampleRate, LSettings);
  try
    for I := 0 to LCount - 1 do
    begin
      if not ARecipe.BypassEffects and not ARecipe.Parts[I].BypassEffects then
      begin
        for J := 0 to High(ARecipe.Parts[I].Effects) do
        begin
          if not ARecipe.Parts[I].Effects[J].Bypass then
          begin
            AddOwned(I, CreateCatalogEffect(ASampleRate, ARecipe.Parts[I].Effects[J].Settings));
          end;
        end;
      end;
      if ARecipe.Parts[I].Pan <> 0 then
      begin
        AddOwned(I, TStereoBalanceEffect.Create(ASampleRate, ARecipe.Parts[I].Pan));
      end;
      LGraph.AddSend(I, I + LCount, stPostFader, 1, 0);
      LGraph.AddSend(I, LCount * 2, stPostFader, 1, 0);
      if ARecipe.LimitOutputs then
      begin
        AddOwned(I + LCount, CreateCatalogEffect(ASampleRate, OutputLimiterSettings(ARecipe)));
      end;
    end;
    if not ARecipe.BypassEffects then
    begin
      for I := 0 to High(ARecipe.MasterEffects) do
      begin
        if not ARecipe.MasterEffects[I].Bypass then
        begin
          AddOwned(LCount * 2, CreateCatalogEffect(ASampleRate, ARecipe.MasterEffects[I].Settings));
        end;
      end;
    end;
    if ARecipe.LimitOutputs then
    begin
      AddOwned(LCount * 2, CreateCatalogEffect(ASampleRate, OutputLimiterSettings(ARecipe)));
    end;
    Result := LGraph;
  except
    LGraph.Free;
    raise;
  end;
end;

end.
