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
  pythian.evaluation, pythian.evaluation.style, pythian.progress, pythian.text;

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
    Id: TScalarText;
    Binding: TEvaluationBinding;
    Method: TScalarText;
    Uncertainty: TScalarText;
    { Native consumers resolve these six paths relative to the card. The core
      never opens files. Array order: source, preparation, reference,
      annotation policy, scoring policy, estimator/provenance artifact. }
    Assets: array[0..5] of TScalarText;
  end;
  TStyleCardGroups = array of TStyleCardGroup;
  TStyleCardTrait = record
    Id: TScalarText;
    Requirement: TStyleTraitRequirement;
    Support: TStyleTraitSupport;
    Units: TScalarText;
    Denominator: TScalarText;
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
    Id: TScalarText;
    Traits: TStyleCardTraits;
  end;
  TStyleCardTraitResult = record
    Id: TScalarText;
    Requirement: TStyleTraitRequirement;
    Present: Boolean;
    Supported: Boolean;
    Comparison: TStyleDistributionComparison;
    PassedDeclaredLimits: Boolean;
  end;
  TStyleCardTraitResults = array of TStyleCardTraitResult;
  TStyleCardResult = record
    ReferenceId: TScalarText;
    CandidateId: TScalarText;
    Traits: TStyleCardTraitResults;
    PassedRequiredDeclaredLimits: Boolean;
    { Always false. These helpers cannot verify annotation truth, calibrated
      gates, independent exposure or the final listening/style claim. }
    GroundedAcceptance: Boolean;
  end;

{ Strict scalar-sorted unique IDs, canonical UTF-8 byte limits, bounded arrays,
  valid exposure/clock declarations,
  binding-to-histogram correspondence, policies and finite [0,1] limits.
  Unsupported traits have no observations; required unsupported traits remain
  valid declarations but prevent a passing whole-card result. Optional synchronous
  callbacks are borrowed per operation and forwarded to the primary comparison
  and text work. They never establish grounded musical acceptance. }
procedure ValidateStyleCard(const ACard: TStyleCard;
  const AProgress: TWorkProgressCallback = nil);
{ Independently owns every mutable array; records and strings follow RTL value
  semantics. Inputs are borrowed read-only. No global state or retained files. }
function CloneStyleCard(const ACard: TStyleCard;
  const AProgress: TWorkProgressCallback = nil): TStyleCard;
{ Different recording/run clocks are intentional: generated distributions are
  NOT aligned transcription scores. Same trait ID/policy/units/denominator/bin
  vocabulary are required. Reference limits alone govern the result. Missing
  candidate traits are visible failures for required traits. Extra candidate
  traits reject rather than disappear. Failure leaves prior assignments intact. }
function CompareStyleCards(const AReference, ACandidate: TStyleCard;
  const AProgress: TWorkProgressCallback = nil): TStyleCardResult;

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

procedure Text(const AValue: TScalarText; const AMaximum: Integer;
  const AProgress: TWorkProgressCallback);
begin
  ValidateScalarText(AValue, AMaximum, False, False, AProgress);
end;

procedure ValidateStyleCard(const ACard: TStyleCard;
  const AProgress: TWorkProgressCallback);
var
  I: Integer;
  J: Integer;
  K: Integer;
  LTrait: TStyleCardTrait;
  LComparison: TStyleDistributionComparison;
begin
  Text(ACard.Id, 256, AProgress);
  Require((Length(ACard.Traits) > 0) and
    (Length(ACard.Traits) <= MaximumStyleCardTraits), 'Style card trait budget exceeded');
  ReportWork(AProgress, 'style_card_validate_traits', wuItems, 0, Length(ACard.Traits));
  for I := 0 to High(ACard.Traits) do
  begin
    LTrait := ACard.Traits[I];
    Text(LTrait.Id, 256, AProgress);
    if I > 0 then
    begin
      Require(CompareScalarText(ACard.Traits[I - 1].Id, LTrait.Id, 256) < 0,
        'Style traits must be sorted and unique');
    end;
    Require(LTrait.Requirement in [strRequired, strOptional], 'Invalid style requirement');
    Require(LTrait.Support in [stsSupported, stsUnsupported], 'Invalid style support');
    Text(LTrait.Units, MaximumStyleCardTextBytes, AProgress);
    Text(LTrait.Denominator, MaximumStyleCardTextBytes, AProgress);
    Require(not IsNan(LTrait.MinimumCoverage) and not IsInfinite(LTrait.MinimumCoverage) and
      (LTrait.MinimumCoverage >= 0) and (LTrait.MinimumCoverage <= 1), 'Invalid style coverage limit');
    Require(not IsNan(LTrait.MaximumDistance) and not IsInfinite(LTrait.MaximumDistance) and
      (LTrait.MaximumDistance >= 0) and (LTrait.MaximumDistance <= 1), 'Invalid style distance limit');
    if LTrait.Support = stsUnsupported then
    begin
      Require((Length(LTrait.Groups) = 0) and (Length(LTrait.Distribution.Groups) = 0) and
        (Length(LTrait.Distribution.Bins) = 0) and (LTrait.Distribution.PolicySha256 = ''),
        'Unsupported style trait cannot carry observations');
      ReportWork(AProgress, 'style_card_validate_traits', wuItems, I + 1, Length(ACard.Traits));
      Continue;
    end;
    LComparison := CompareStyleDistributions(LTrait.Distribution, LTrait.Distribution, AProgress);
    Require(Length(LTrait.Groups) = LComparison.Reference.Groups,
      'Style observations require corresponding source/reference bindings');
    ReportWork(AProgress, 'style_card_bindings', wuItems, 0, Length(LTrait.Groups), I + 1);
    for J := 0 to High(LTrait.Groups) do
    begin
      ValidateEvaluationBinding(LTrait.Groups[J].Binding);
      Require(CompareScalarText(LTrait.Groups[J].Id,
        LTrait.Distribution.Groups[J].GroupId, 256) = 0,
        'Style recording/run identity differs from histogram identity');
      Require(LTrait.Groups[J].Binding.ScoringPolicySha256 = LTrait.Distribution.PolicySha256,
        'Style group scoring policy differs from trait policy');
      Text(LTrait.Groups[J].Method, MaximumStyleCardTextBytes, AProgress);
      Text(LTrait.Groups[J].Uncertainty, MaximumStyleCardTextBytes, AProgress);
      for K := 0 to 5 do
      begin
        Text(LTrait.Groups[J].Assets[K], MaximumStyleCardTextBytes, AProgress);
      end;
      ReportWork(AProgress, 'style_card_bindings', wuItems, J + 1, Length(LTrait.Groups), I + 1);
    end;
    ReportWork(AProgress, 'style_card_validate_traits', wuItems, I + 1, Length(ACard.Traits));
  end;
end;

function CloneStyleCard(const ACard: TStyleCard;
  const AProgress: TWorkProgressCallback): TStyleCard;
var
  I: Integer;
  J: Integer;
  LCard: TStyleCard;
begin
  ValidateStyleCard(ACard, AProgress);
  LCard := ACard;
  LCard.Traits := Copy(ACard.Traits);
  for I := 0 to High(LCard.Traits) do
  begin
    LCard.Traits[I].Groups := Copy(ACard.Traits[I].Groups);
    LCard.Traits[I].Distribution.Bins := Copy(ACard.Traits[I].Distribution.Bins);
    LCard.Traits[I].Distribution.Groups := Copy(ACard.Traits[I].Distribution.Groups);
    ReportWork(AProgress, 'style_card_clone_groups', wuItems, 0,
      Length(LCard.Traits[I].Distribution.Groups), I + 1);
    for J := 0 to High(LCard.Traits[I].Distribution.Groups) do
    begin
      LCard.Traits[I].Distribution.Groups[J].Counts :=
        Copy(ACard.Traits[I].Distribution.Groups[J].Counts);
      ReportWork(AProgress, 'style_card_clone_groups', wuItems, J + 1,
        Length(LCard.Traits[I].Distribution.Groups), I + 1);
    end;
  end;
  ReportWork(AProgress, 'style_card_clone_ready', wuItems, 1, 1);
  Result := LCard;
end;

function CompareStyleCards(const AReference, ACandidate: TStyleCard;
  const AProgress: TWorkProgressCallback): TStyleCardResult;
var
  I: Integer;
  J: Integer;
  LResult: TStyleCardResult;
  LRef: TStyleCardTrait;
  LCand: TStyleCardTrait;
begin
  ValidateStyleCard(AReference, AProgress);
  ValidateStyleCard(ACandidate, AProgress);
  LResult := Default(TStyleCardResult);
  LResult.ReferenceId := AReference.Id;
  LResult.CandidateId := ACandidate.Id;
  LResult.PassedRequiredDeclaredLimits := True;
  SetLength(LResult.Traits, Length(AReference.Traits));
  J := 0;
  ReportWork(AProgress, 'style_card_compare_traits', wuItems, 0, Length(AReference.Traits));
  for I := 0 to High(AReference.Traits) do
  begin
    LRef := AReference.Traits[I];
    LResult.Traits[I].Id := LRef.Id;
    LResult.Traits[I].Requirement := LRef.Requirement;
    if LRef.Support = stsSupported then
    begin
      LResult.Traits[I].Comparison.Reference :=
        CompareStyleDistributions(LRef.Distribution, LRef.Distribution, AProgress).Reference;
    end;
    if J <= High(ACandidate.Traits) then
    begin
      Require(CompareScalarText(ACandidate.Traits[J].Id, LRef.Id, 256) >= 0,
        'Candidate has undeclared style trait');
    end;
    if (J <= High(ACandidate.Traits)) and
      (CompareScalarText(ACandidate.Traits[J].Id, LRef.Id, 256) = 0) then
    begin
      LCand := ACandidate.Traits[J];
      Inc(J);
      LResult.Traits[I].Present := True;
      Require((CompareScalarText(LRef.Units, LCand.Units,
        MaximumStyleCardTextBytes, False, AProgress) = 0) and
        (CompareScalarText(LRef.Denominator, LCand.Denominator,
        MaximumStyleCardTextBytes, False, AProgress) = 0),
        'Style trait units or denominator differ');
      LResult.Traits[I].Supported := (LRef.Support = stsSupported) and
        (LCand.Support = stsSupported);
      if LResult.Traits[I].Supported then
      begin
        LResult.Traits[I].Comparison := CompareStyleDistributions(LRef.Distribution,
          LCand.Distribution, AProgress);
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
    ReportWork(AProgress, 'style_card_compare_traits', wuItems, I + 1,
      Length(AReference.Traits));
  end;
  Require(J = Length(ACandidate.Traits), 'Candidate has undeclared style trait');
  ReportWork(AProgress, 'style_card_compare_ready', wuItems, 1, 1);
  Result := LResult;
end;

end.
