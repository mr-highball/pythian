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
unit pythian.evaluation.style;

{$mode delphi}
{$H+}

interface

uses
  pythian.progress, pythian.text;

const
  MaximumStyleGroups = 256;
  MaximumStyleBins = 4096;
  MaximumStyleCount: Int64 = 9007199254740991;

type
  TStyleCounts = array of Int64;
  TStyleBinNames = array of TScalarText;
  TStyleGroupHistogram = record
    GroupId: TScalarText;
    Counts: TStyleCounts;
    Unknown: Int64;
    Ambiguous: Int64;
    Unsupported: Int64;
  end;
  TStyleGroupHistograms = array of TStyleGroupHistogram;
  TStyleDistribution = record
    { Caller-verified policy bytes bind trait, bin edges/labels, units, sampling,
      rest/uncertainty conventions and the independent reference packet.
      This helper neither reads assets nor establishes musical ground truth. }
    PolicySha256: String;
    Bins: TStyleBinNames;
    Groups: TStyleGroupHistograms;
  end;
  TStyleDistributionCoverage = record
    Groups: Integer;
    GroupsWithValues: Integer;
    Known: Int64;
    Unknown: Int64;
    Ambiguous: Int64;
    Unsupported: Int64;
    Total: Int64;
    PooledCoverage: Double;
    MeanGroupCoverage: Double;
    MinimumGroupCoverage: Double;
  end;
  TStyleDistributionComparison = record
    Reference: TStyleDistributionCoverage;
    Candidate: TStyleDistributionCoverage;
    { False if ANY declared group has no known values. In that case Distance
      remains zero but is undefined, not a successful match. }
    Comparable: Boolean;
    Distance: Double;
  end;

{ Compare generated and reference trait distributions without aligning their
  source clocks or copying a song. Each declared recording group contributes
  equal mass after normalization of its known observations. Distance is total
  variation, in [0,1]. Unknown/ambiguous/unsupported remain in coverage; rest
  must be an explicit bin when meaningful. No threshold or style verdict is
  implied. Caller must check coverage AND distance AND evidence eligibility.
  Bin names and group IDs are canonical scalar text with 1..256 UTF-8 bytes,
  strictly sorted in scalar/canonical byte order and unique. No normalization.
  References/candidates require identical policy hash and bins. Group identities
  need not match: generated runs are different from reference recordings.
  All counts per distribution sum to at most MaximumStyleCount. Arrays are
  borrowed read-only; failure leaves a caller's previous assignment intact.
  The synchronous observer is borrowed only during this call. Counts and
  normalization are separate actual visits, with pass1 reference/pass2 candidate;
  its final publication callback precedes the returned result. }
function CompareStyleDistributions(const AReference,
  ACandidate: TStyleDistribution;
  const AProgress: TWorkProgressCallback = nil): TStyleDistributionComparison;

implementation

uses
  SysUtils, pythian.audio;

type
  TProbabilities = array of Double;

procedure Require(const ACondition: Boolean; const AMessage: String);
begin
  if not ACondition then
  begin
    raise EAudio.Create(AMessage);
  end;
end;

procedure AddCount(var ATotal: Int64; const AValue: Int64);
begin
  Require((AValue >= 0) and (AValue <= MaximumStyleCount),
    'Style observation count is outside the exact integer budget');
  Require(ATotal <= MaximumStyleCount - AValue,
    'Style distribution exceeds the total observation budget');
  ATotal := ATotal + AValue;
end;

procedure CheckIdentity(const AText: TScalarText);
begin
  ValidateScalarText(AText, 256, False, False);
end;

procedure CheckPolicy(const AHash: String);
var
  I: Integer;
begin
  Require(Length(AHash) = 64, 'Style policy requires a SHA256 identity');
  for I := 1 to Length(AHash) do
  begin
    Require(AHash[I] in ['0'..'9', 'a'..'f'], 'Style policy requires lowercase SHA256');
  end;
end;

procedure Summarize(const ADistribution: TStyleDistribution;
  out ACoverage: TStyleDistributionCoverage; out AProbabilities: TProbabilities;
  const AProgress: TWorkProgressCallback; const APass: Integer);
var
  I: Integer;
  J: Integer;
  LKnown: Int64;
  LTotal: Int64;
  LCoverage: Double;
  LCountDone: Int64;
  LCountTotal: Int64;
  LNormalized: Int64;
begin
  ACoverage := Default(TStyleDistributionCoverage);
  CheckPolicy(ADistribution.PolicySha256);
  Require((Length(ADistribution.Bins) > 0) and
    (Length(ADistribution.Bins) <= MaximumStyleBins), 'Style bin budget exceeded');
  Require((Length(ADistribution.Groups) > 0) and
    (Length(ADistribution.Groups) <= MaximumStyleGroups), 'Style group budget exceeded');
  ReportWork(AProgress, 'style_distribution_bins', wuItems, 0,
    Length(ADistribution.Bins), APass);
  for I := 0 to High(ADistribution.Bins) do
  begin
    CheckIdentity(ADistribution.Bins[I]);
    if I > 0 then
    begin
      Require(CompareScalarText(ADistribution.Bins[I - 1], ADistribution.Bins[I], 256) < 0,
        'Style bins must be strictly sorted and unique');
    end;
    if ((I + 1) mod 256 = 0) or (I = High(ADistribution.Bins)) then
    begin
      ReportWork(AProgress, 'style_distribution_bins', wuItems, I + 1,
        Length(ADistribution.Bins), APass);
    end;
  end;
  AProbabilities := nil;
  SetLength(AProbabilities, Length(ADistribution.Bins));
  ACoverage.Groups := Length(ADistribution.Groups);
  ACoverage.MinimumGroupCoverage := 1;
  LCountDone := 0;
  LCountTotal := Int64(Length(ADistribution.Groups)) * Length(ADistribution.Bins);
  LNormalized := 0;
  ReportWork(AProgress, 'style_distribution_counts', wuItems, 0, LCountTotal, APass);
  { All-unknown groups skip normalization. Its total is actual work, known only
    after the walk, rather than the maximum group/bin capacity. }
  ReportWork(AProgress, 'style_distribution_normalize', wuItems, 0, 0, APass);
  for I := 0 to High(ADistribution.Groups) do
  begin
    CheckIdentity(ADistribution.Groups[I].GroupId);
    if I > 0 then
    begin
      Require(CompareScalarText(ADistribution.Groups[I - 1].GroupId,
        ADistribution.Groups[I].GroupId, 256) < 0,
        'Style groups must be strictly sorted and unique');
    end;
    Require(Length(ADistribution.Groups[I].Counts) = Length(ADistribution.Bins),
      'Style group counts do not match the declared vocabulary');
    LKnown := 0;
    for J := 0 to High(ADistribution.Bins) do
    begin
      AddCount(LKnown, ADistribution.Groups[I].Counts[J]);
      Inc(LCountDone);
      if LCountDone mod 4096 = 0 then
      begin
        ReportWork(AProgress, 'style_distribution_counts', wuItems,
          LCountDone, LCountTotal, APass);
      end;
    end;
    LTotal := LKnown;
    AddCount(LTotal, ADistribution.Groups[I].Unknown);
    AddCount(LTotal, ADistribution.Groups[I].Ambiguous);
    AddCount(LTotal, ADistribution.Groups[I].Unsupported);
    Require(LTotal > 0, 'Style groups require declared observation opportunities');
    AddCount(ACoverage.Total, LTotal);
    AddCount(ACoverage.Known, LKnown);
    AddCount(ACoverage.Unknown, ADistribution.Groups[I].Unknown);
    AddCount(ACoverage.Ambiguous, ADistribution.Groups[I].Ambiguous);
    AddCount(ACoverage.Unsupported, ADistribution.Groups[I].Unsupported);
    LCoverage := LKnown / LTotal;
    ACoverage.MeanGroupCoverage := ACoverage.MeanGroupCoverage +
      LCoverage / ACoverage.Groups;
    if LCoverage < ACoverage.MinimumGroupCoverage then
    begin
      ACoverage.MinimumGroupCoverage := LCoverage;
    end;
    if LKnown > 0 then
    begin
      Inc(ACoverage.GroupsWithValues);
      for J := 0 to High(ADistribution.Bins) do
      begin
        AProbabilities[J] := AProbabilities[J] +
          (ADistribution.Groups[I].Counts[J] / LKnown) / ACoverage.Groups;
        Inc(LNormalized);
        if LNormalized mod 4096 = 0 then
        begin
          ReportWork(AProgress, 'style_distribution_normalize', wuItems,
            LNormalized, 0, APass);
        end;
      end;
    end;
  end;
  ACoverage.PooledCoverage := ACoverage.Known / ACoverage.Total;
  ReportWork(AProgress, 'style_distribution_counts', wuItems,
    LCountDone, LCountTotal, APass);
  ReportWork(AProgress, 'style_distribution_normalize', wuItems,
    LNormalized, LNormalized, APass);
end;

function CompareStyleDistributions(const AReference,
  ACandidate: TStyleDistribution;
  const AProgress: TWorkProgressCallback): TStyleDistributionComparison;
var
  LReference: TProbabilities;
  LCandidate: TProbabilities;
  LResult: TStyleDistributionComparison;
  I: Integer;
begin
  LResult := Default(TStyleDistributionComparison);
  Require(AReference.PolicySha256 = ACandidate.PolicySha256,
    'Style comparison requires the same bound trait policy');
  Require(Length(AReference.Bins) = Length(ACandidate.Bins),
    'Style comparison requires the same vocabulary');
  { Validate budgets before walking the caller's arrays. }
  Summarize(AReference, LResult.Reference, LReference, AProgress, 1);
  Summarize(ACandidate, LResult.Candidate, LCandidate, AProgress, 2);
  ReportWork(AProgress, 'style_distribution_compare_bins', wuItems, 0,
    Length(AReference.Bins), 1);
  for I := 0 to High(AReference.Bins) do
  begin
    Require(CompareScalarText(AReference.Bins[I], ACandidate.Bins[I], 256) = 0,
      'Style comparison requires identical bin meanings and order');
    if ((I + 1) mod 256 = 0) or (I = High(AReference.Bins)) then
    begin
      ReportWork(AProgress, 'style_distribution_compare_bins', wuItems,
        I + 1, Length(AReference.Bins), 1);
    end;
  end;
  LResult.Comparable := (LResult.Reference.GroupsWithValues = LResult.Reference.Groups) and
    (LResult.Candidate.GroupsWithValues = LResult.Candidate.Groups);
  if not LResult.Comparable then
  begin
    ReportWork(AProgress, 'style_distribution_ready', wuItems, 1, 1);
    Result := LResult;
    Exit;
  end;
  ReportWork(AProgress, 'style_distribution_compare_bins', wuItems, 0,
    Length(LReference), 2);
  for I := 0 to High(LReference) do
  begin
    LResult.Distance := LResult.Distance + Abs(LReference[I] - LCandidate[I]) * 0.5;
    if ((I + 1) mod 256 = 0) or (I = High(LReference)) then
    begin
      ReportWork(AProgress, 'style_distribution_compare_bins', wuItems,
        I + 1, Length(LReference), 2);
    end;
  end;
  { Bound the accumulation's last rounding bit, not the inputs. }
  if LResult.Distance > 1 then
  begin
    LResult.Distance := 1;
  end;
  ReportWork(AProgress, 'style_distribution_ready', wuItems, 1, 1);
  Result := LResult;
end;

end.
