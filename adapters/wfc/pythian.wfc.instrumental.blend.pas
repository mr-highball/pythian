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
unit pythian.wfc.instrumental.blend;

{$mode delphi}{$H+}

interface

uses pythian.music.blend, pythian.progress, pythian.wfc.semantic.style;

{ Big Boss: transport-free binding of the shared musical choice contract to the
  primary semantic factory. No new learner, codec or vocabulary alignment path.
  Repeated source evidence keeps the primary maximum policy, not double counts. }
function BlendInstrumentalStyles(const ALeft, ARight: TSemanticStyle;
  const APlan: TMusicBlendPlan; const ALabel: String;
  const AProgress: TWorkProgressCallback = nil): TSemanticStyle;

implementation

uses pythian.audio, pythian.wfc.instrumental.stream;

function BlendInstrumentalStyles(const ALeft, ARight: TSemanticStyle;
  const APlan: TMusicBlendPlan; const ALabel: String;
  const AProgress: TWorkProgressCallback): TSemanticStyle;
var
  LRecipe: TSemanticBlendRecipe;
  I: Integer;
begin
  if (ALeft = nil) or (ARight = nil) then
  begin
    raise EAudio.Create('Choose two saved instrumental styles to blend');
  end;
  { The primary constructor checks the actual inventory/role layout. Validate
    choices here without cloning every model/evidence row a second time. }
  ValidateMusicBlendPlan(APlan, Length(APlan.Providers), Length(APlan.Parts));
  LRecipe := Default(TSemanticBlendRecipe);
  SetLength(LRecipe.Providers, Length(APlan.Providers));
  for I := 0 to High(APlan.Providers) do
  begin
    LRecipe.Providers[I] := APlan.Providers[I];
  end;
  LRecipe.Instrumental.Enabled := True;
  LRecipe.Instrumental.LabelText := ALabel;
  LRecipe.Instrumental.BaseParent := APlan.BaseParent;
  LRecipe.Instrumental.MasterParent := APlan.MasterParent;
  LRecipe.Instrumental.FormParent := APlan.FormParent;
  LRecipe.Instrumental.UnionPitchRanges := APlan.UnionPitchRanges;
  LRecipe.Instrumental.OverrideContextBinding := APlan.Context <> mbcKeepBase;
  if APlan.Context = mbcAllRoles then
  begin
    LRecipe.Instrumental.ContextBinding := icbAllRoles;
  end
  else
  begin
    LRecipe.Instrumental.ContextBinding := icbDrivenRole;
  end;
  SetLength(LRecipe.Instrumental.Parts, Length(APlan.Parts));
  for I := 0 to High(APlan.Parts) do
  begin
    LRecipe.Instrumental.Parts[I] := APlan.Parts[I];
  end;
  Result := TSemanticStyle.CreateBlend(ALeft, ARight, LRecipe, nil, nil, AProgress);
end;

end.
