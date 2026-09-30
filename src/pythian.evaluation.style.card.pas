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
unit pythian.evaluation.style.card;

{$mode delphi}
{$H+}

interface

uses
  pythian.evaluation, pythian.evaluation.style;

const
  StyleCardVersion = 1;
  MaximumStyleCardTraits = 64;
  MaximumStyleCardTextBytes = 4096;

type
  TStyleTraitRequirement = (strRequired, strOptional);
  TStyleTraitSupport = (stsSupported, stsUnsupported);
  TStyleCardGroup = record
    { Histogram recording/run identity is separate from Binding.GroupId's
      conservative family/exposure identity. Two recordings can share a family. }
    Id: UTF8String;
    Binding: TEvaluationBinding;
    Method: UTF8String;
    Uncertainty: UTF8String;
    { Native consumers resolve these six paths relative to the card. The core
      never opens files. Array order: source, preparation, reference,
      annotation policy, scoring policy, estimator/provenance artifact. }
    Assets: array[0..5] of UTF8String;
  end;
  TStyleCardGroups = array of TStyleCardGroup;
  TStyleCardTrait = record
    Id: UTF8String;
    Requirement: TStyleTraitRequirement;
    Support: TStyleTraitSupport;
    Units: UTF8String;
    Denominator: UTF8String;
    { These are caller-declared arithmetic limits, NOT independently calibrated
      musical gates. Coverage is the minimum known/total group fraction on
      BOTH sides; unknown, ambiguous and unsupported stay in the denominator. }
    MinimumCoverage: Double;
    MaximumDistance: Double;
    Distribution: TStyleDistribution;
    Groups: TStyleCardGroups;
  end;
  TStyleCardTraits = array of TStyleCardTrait;
  TStyleCard = record
    Id: UTF8String;
    Traits: TStyleCardTraits;
  end;
  TStyleCardTraitResult = record
    Id: UTF8String;
    Requirement: TStyleTraitRequirement;
    Present: Boolean;
    Supported: Boolean;
    Comparison: TStyleDistributionComparison;
    PassedDeclaredLimits: Boolean;
  end;
  TStyleCardTraitResults = array of TStyleCardTraitResult;
  TStyleCardResult = record
    ReferenceId: UTF8String;
    CandidateId: UTF8String;
    Traits: TStyleCardTraitResults;
    PassedRequiredDeclaredLimits: Boolean;
    { Always false. These helpers cannot verify annotation truth, calibrated
      gates, independent exposure or the final listening/style claim. }
    GroundedAcceptance: Boolean;
  end;

{ Strict sorted unique IDs, bounded arrays, valid exposure/clock declarations,
  binding-to-histogram correspondence, policies and finite [0,1] limits.
  Unsupported traits have no observations; required unsupported traits remain
  valid declarations but prevent a passing whole-card result. }
procedure ValidateStyleCard(const ACard: TStyleCard);
{ Independently owns every mutable array; records and strings follow RTL value
  semantics. Inputs are borrowed read-only. No global state or retained files. }
function CloneStyleCard(const ACard: TStyleCard): TStyleCard;
{ Different recording/run clocks are intentional: generated distributions are
  NOT aligned transcription scores. Same trait ID/policy/units/denominator/bin
  vocabulary are required. Reference limits alone govern the result. Missing
  candidate traits are visible failures for required traits. Extra candidate
  traits reject rather than disappear. Failure leaves prior assignments intact. }
function CompareStyleCards(const AReference, ACandidate: TStyleCard): TStyleCardResult;

implementation

uses
  SysUtils, Math, pythian.audio;

procedure Require(const ACondition: Boolean; const AMessage: String);
begin
  if not ACondition then
  begin
    raise EAudio.Create(AMessage);
  end;
end;

procedure Text(const AValue: UTF8String; const AMaximum: Integer);
begin
  Require((Length(AValue) > 0) and (Length(AValue) <= AMaximum) and
    (Pos(#0, AValue) = 0), 'Style card text is empty, oversized or contains NUL');
end;

procedure ValidateStyleCard(const ACard: TStyleCard);
var
  I: Integer;
  J: Integer;
  K: Integer;
  LTrait: TStyleCardTrait;
  LComparison: TStyleDistributionComparison;
begin
  Text(ACard.Id, 256);
  Require((Length(ACard.Traits) > 0) and
    (Length(ACard.Traits) <= MaximumStyleCardTraits), 'Style card trait budget exceeded');
  for I := 0 to High(ACard.Traits) do
  begin
    LTrait := ACard.Traits[I];
    Text(LTrait.Id, 256);
    if I > 0 then
    begin
      Require(ACard.Traits[I - 1].Id < LTrait.Id, 'Style traits must be sorted and unique');
    end;
    Require(LTrait.Requirement in [strRequired, strOptional], 'Invalid style requirement');
    Require(LTrait.Support in [stsSupported, stsUnsupported], 'Invalid style support');
    Text(LTrait.Units, MaximumStyleCardTextBytes);
    Text(LTrait.Denominator, MaximumStyleCardTextBytes);
    Require(not IsNan(LTrait.MinimumCoverage) and not IsInfinite(LTrait.MinimumCoverage) and
      (LTrait.MinimumCoverage >= 0) and (LTrait.MinimumCoverage <= 1), 'Invalid style coverage limit');
    Require(not IsNan(LTrait.MaximumDistance) and not IsInfinite(LTrait.MaximumDistance) and
      (LTrait.MaximumDistance >= 0) and (LTrait.MaximumDistance <= 1), 'Invalid style distance limit');
    if LTrait.Support = stsUnsupported then
    begin
      Require((Length(LTrait.Groups) = 0) and (Length(LTrait.Distribution.Groups) = 0) and
        (Length(LTrait.Distribution.Bins) = 0) and (LTrait.Distribution.PolicySha256 = ''),
        'Unsupported style trait cannot carry observations');
      Continue;
    end;
    LComparison := CompareStyleDistributions(LTrait.Distribution, LTrait.Distribution);
    Require(Length(LTrait.Groups) = LComparison.Reference.Groups,
      'Style observations require corresponding source/reference bindings');
    for J := 0 to High(LTrait.Groups) do
    begin
      ValidateEvaluationBinding(LTrait.Groups[J].Binding);
      Require(LTrait.Groups[J].Id = LTrait.Distribution.Groups[J].GroupId,
        'Style recording/run identity differs from histogram identity');
      Require(LTrait.Groups[J].Binding.ScoringPolicySha256 = LTrait.Distribution.PolicySha256,
        'Style group scoring policy differs from trait policy');
      Text(LTrait.Groups[J].Method, MaximumStyleCardTextBytes);
      Text(LTrait.Groups[J].Uncertainty, MaximumStyleCardTextBytes);
      for K := 0 to 5 do
      begin
        Text(LTrait.Groups[J].Assets[K], MaximumStyleCardTextBytes);
      end;
    end;
  end;
end;

function CloneStyleCard(const ACard: TStyleCard): TStyleCard;
var
  I: Integer;
  J: Integer;
  LCard: TStyleCard;
begin
  ValidateStyleCard(ACard);
  LCard := ACard;
  LCard.Traits := Copy(ACard.Traits);
  for I := 0 to High(LCard.Traits) do
  begin
    LCard.Traits[I].Groups := Copy(ACard.Traits[I].Groups);
    LCard.Traits[I].Distribution.Bins := Copy(ACard.Traits[I].Distribution.Bins);
    LCard.Traits[I].Distribution.Groups := Copy(ACard.Traits[I].Distribution.Groups);
    for J := 0 to High(LCard.Traits[I].Distribution.Groups) do
    begin
      LCard.Traits[I].Distribution.Groups[J].Counts :=
        Copy(ACard.Traits[I].Distribution.Groups[J].Counts);
    end;
  end;
  Result := LCard;
end;

function CompareStyleCards(const AReference, ACandidate: TStyleCard): TStyleCardResult;
var
  I: Integer;
  J: Integer;
  LResult: TStyleCardResult;
  LRef: TStyleCardTrait;
  LCand: TStyleCardTrait;
begin
  ValidateStyleCard(AReference);
  ValidateStyleCard(ACandidate);
  LResult := Default(TStyleCardResult);
  LResult.ReferenceId := AReference.Id;
  LResult.CandidateId := ACandidate.Id;
  LResult.PassedRequiredDeclaredLimits := True;
  SetLength(LResult.Traits, Length(AReference.Traits));
  J := 0;
  for I := 0 to High(AReference.Traits) do
  begin
    LRef := AReference.Traits[I];
    LResult.Traits[I].Id := LRef.Id;
    LResult.Traits[I].Requirement := LRef.Requirement;
    if LRef.Support = stsSupported then
    begin
      LResult.Traits[I].Comparison.Reference :=
        CompareStyleDistributions(LRef.Distribution, LRef.Distribution).Reference;
    end;
    if J <= High(ACandidate.Traits) then
    begin
      Require(ACandidate.Traits[J].Id >= LRef.Id, 'Candidate has undeclared style trait');
    end;
    if (J <= High(ACandidate.Traits)) and (ACandidate.Traits[J].Id = LRef.Id) then
    begin
      LCand := ACandidate.Traits[J];
      Inc(J);
      LResult.Traits[I].Present := True;
      Require((LRef.Units = LCand.Units) and (LRef.Denominator = LCand.Denominator),
        'Style trait units or denominator differ');
      LResult.Traits[I].Supported := (LRef.Support = stsSupported) and
        (LCand.Support = stsSupported);
      if LResult.Traits[I].Supported then
      begin
        LResult.Traits[I].Comparison := CompareStyleDistributions(LRef.Distribution,
          LCand.Distribution);
        LResult.Traits[I].PassedDeclaredLimits := LResult.Traits[I].Comparison.Comparable and
          (LResult.Traits[I].Comparison.Reference.MinimumGroupCoverage >= LRef.MinimumCoverage) and
          (LResult.Traits[I].Comparison.Candidate.MinimumGroupCoverage >= LRef.MinimumCoverage) and
          (LResult.Traits[I].Comparison.Distance <= LRef.MaximumDistance);
      end;
    end;
    if LRef.Requirement = strRequired then
    begin
      LResult.PassedRequiredDeclaredLimits := LResult.PassedRequiredDeclaredLimits and
        LResult.Traits[I].PassedDeclaredLimits;
    end;
  end;
  Require(J = Length(ACandidate.Traits), 'Candidate has undeclared style trait');
  Result := LResult;
end;

end.
