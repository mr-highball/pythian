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
unit pythian.music.blend;

{$mode delphi}{$H+}

interface

const
  MaximumMusicBlendWeight = 64;

type
  { Big Boss: musical contributions and selected rules/sounds are separate.
    Parents are explicit indices 0 and 1; zero weight excludes observations,
    never implicitly replaces a rule or instrument. This contract owns no model. }
  TMusicBlendProvider = record
    LeftWeight: Integer;
    RightWeight: Integer;
    ControlParent: Integer;
  end;
  TMusicBlendPart = record
    InstrumentParent: Integer;
    EffectsParent: Integer;
    ExpressionParent: Integer;
  end;
  TMusicBlendContext = (mbcKeepBase, mbcDrivenRole, mbcAllRoles);
  TMusicBlendPlan = record
    Providers: array of TMusicBlendProvider;
    Parts: array of TMusicBlendPart;
    BaseParent: Integer;
    MasterParent: Integer;
    FormParent: Integer;
    UnionPitchRanges: Boolean;
    Context: TMusicBlendContext;
  end;

function DefaultMusicBlendPlan(const AProviders, AParts: Integer): TMusicBlendPlan;
procedure ValidateMusicBlendPlan(const APlan: TMusicBlendPlan;
  const AProviders, AParts: Integer);
function CopyMusicBlendPlan(const APlan: TMusicBlendPlan): TMusicBlendPlan;
{ Both tails use the same sample clock. Timing/base, master, instruments and
  part effects retain their selected parent's tail. Music weights, expression
  and form do not select sound tails. No model or instrument needs opening. }
function MusicBlendSoundTailFrames(const ABaseParent, AMasterParent: Integer;
  const AParts: array of TMusicBlendPart;
  const ALeftFrames, ARightFrames: Int64): Int64;

implementation

uses SysUtils, pythian.audio, pythian.time;

procedure Need(const ACondition: Boolean; const AMessage: String);
begin
  if not ACondition then
  begin
    raise EAudio.Create(AMessage);
  end;
end;

procedure Parent(const AValue: Integer; const AName: String);
begin
  Need((AValue = 0) or (AValue = 1), 'Choose style A or B for ' + AName);
end;

procedure ValidateMusicBlendPlan(const APlan: TMusicBlendPlan;
  const AProviders, AParts: Integer);
var
  I: Integer;
begin
  Need((AProviders > 0) and (AParts > 0) and
    (Length(APlan.Providers) = AProviders) and (Length(APlan.Parts) = AParts),
    'Blend choices must match every musical provider and part');
  Parent(APlan.BaseParent, 'tempo and timing');
  Parent(APlan.MasterParent, 'master effects');
  Parent(APlan.FormParent, 'song sections');
  Need(APlan.Context in [mbcKeepBase, mbcDrivenRole, mbcAllRoles],
    'Choose how the shared musical context connects to parts');
  for I := 0 to High(APlan.Providers) do
  begin
    Need((APlan.Providers[I].LeftWeight >= 0) and
      (APlan.Providers[I].LeftWeight <= MaximumMusicBlendWeight) and
      (APlan.Providers[I].RightWeight >= 0) and
      (APlan.Providers[I].RightWeight <= MaximumMusicBlendWeight),
      'Musical weights must be whole numbers from 0 to 64');
    Need((APlan.Providers[I].LeftWeight > 0) or (APlan.Providers[I].RightWeight > 0),
      'Give style A or B a positive weight for musical provider ' + IntToStr(I + 1));
    Parent(APlan.Providers[I].ControlParent, 'musical rules');
  end;
  for I := 0 to High(APlan.Parts) do
  begin
    Parent(APlan.Parts[I].InstrumentParent, 'instrument');
    Parent(APlan.Parts[I].EffectsParent, 'part effects');
    Parent(APlan.Parts[I].ExpressionParent, 'expression');
  end;
end;

function DefaultMusicBlendPlan(const AProviders, AParts: Integer): TMusicBlendPlan;
var
  I: Integer;
begin
  Need((AProviders > 0) and (AProviders <= 256) and
    (AParts > 0) and (AParts <= 256), 'A blend needs bounded provider and part counts');
  Result := Default(TMusicBlendPlan);
  SetLength(Result.Providers, AProviders);
  SetLength(Result.Parts, AParts);
  for I := 0 to AProviders - 1 do
  begin
    Result.Providers[I].LeftWeight := 1;
    Result.Providers[I].RightWeight := 1;
  end;
end;

function CopyMusicBlendPlan(const APlan: TMusicBlendPlan): TMusicBlendPlan;
var
  I: Integer;
begin
  ValidateMusicBlendPlan(APlan, Length(APlan.Providers), Length(APlan.Parts));
  Result := APlan;
  Result.Providers := nil;
  Result.Parts := nil;
  SetLength(Result.Providers, Length(APlan.Providers));
  SetLength(Result.Parts, Length(APlan.Parts));
  for I := 0 to High(APlan.Providers) do
  begin
    Result.Providers[I] := APlan.Providers[I];
  end;
  for I := 0 to High(APlan.Parts) do
  begin
    Result.Parts[I] := APlan.Parts[I];
  end;
end;

function MusicBlendSoundTailFrames(const ABaseParent, AMasterParent: Integer;
  const AParts: array of TMusicBlendPart;
  const ALeftFrames, ARightFrames: Int64): Int64;
var
  LTails: array[0..1] of Int64;
  I: Integer;
  procedure Include(const AParent: Integer);
  begin
    Parent(AParent, 'sound tail');
    if LTails[AParent] > Result then
    begin
      Result := LTails[AParent];
    end;
  end;
begin
  RequireExactTimingCounter(ALeftFrames, 'Style A sound tail');
  RequireExactTimingCounter(ARightFrames, 'Style B sound tail');
  Need((ALeftFrames >= 0) and (ARightFrames >= 0), 'Sound tails cannot be negative');
  Need((Length(AParts) > 0) and (Length(AParts) <= 256), 'Choose bounded blend parts');
  LTails[0] := ALeftFrames;
  LTails[1] := ARightFrames;
  Result := 0;
  Include(ABaseParent);
  Include(AMasterParent);
  for I := 0 to High(AParts) do
  begin
    Include(AParts[I].InstrumentParent);
    Include(AParts[I].EffectsParent);
  end;
end;

end.
