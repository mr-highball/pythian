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
program pythian_tests_evaluation_style;

{$mode delphi}
{$H+}

uses
  SysUtils, Math, pythian.audio, pythian.evaluation.style;

procedure Check(const ACondition: Boolean; const AMessage: String);
begin
  if not ACondition then
  begin
    raise Exception.Create(AMessage);
  end;
end;

procedure Near(const AActual, AExpected: Double; const AMessage: String);
begin
  Check(Abs(AActual - AExpected) < 1e-12, AMessage);
end;

function Distribution(const ABins: array of String;
  const ACounts: array of Int64): TStyleDistribution;
var
  I: Integer;
begin
  Result := Default(TStyleDistribution);
  Result.PolicySha256 := StringOfChar('a', 64);
  SetLength(Result.Bins, Length(ABins));
  for I := 0 to High(ABins) do
  begin
    Result.Bins[I] := ABins[I];
  end;
  SetLength(Result.Groups, 1);
  Result.Groups[0].GroupId := 'recording-a';
  SetLength(Result.Groups[0].Counts, Length(ACounts));
  for I := 0 to High(ACounts) do
  begin
    Result.Groups[0].Counts[I] := ACounts[I];
  end;
end;

procedure CheckRelationships;
var
  LReference: TStyleDistribution;
  LPreserved: TStyleDistribution;
  LBroken: TStyleDistribution;
  LScore: TStyleDistributionComparison;
begin
  { Identical low/high marginals can conceal a destroyed bass/voice pairing.
    Joint labels are independently specified tuples, not inferred role truth. }
  LReference := Distribution(['high/high', 'high/low', 'low/high', 'low/low'],
    [4, 0, 0, 4]);
  LPreserved := Distribution(['high/high', 'high/low', 'low/high', 'low/low'],
    [40, 0, 0, 40]);
  LBroken := Distribution(['high/high', 'high/low', 'low/high', 'low/low'],
    [0, 4, 4, 0]);
  LScore := CompareStyleDistributions(LReference, LPreserved);
  Check(LScore.Comparable, 'Preserved joint distribution is comparable');
  Near(LScore.Distance, 0, 'Duration scaling must preserve a distribution');
  LScore := CompareStyleDistributions(LReference, LBroken);
  Near(LScore.Distance, 1, 'Broken pairing must be disjoint despite equal marginals');
  LReference := Distribution(['high', 'low'], [4, 4]);
  LBroken := Distribution(['high', 'low'], [4, 4]);
  LScore := CompareStyleDistributions(LReference, LBroken);
  Near(LScore.Distance, 0, 'Marginals alone cannot detect relationship loss');
end;

procedure CheckGroupBalance;
var
  LReference: TStyleDistribution;
  LCandidate: TStyleDistribution;
  LScore: TStyleDistributionComparison;
begin
  LReference := Distribution(['a', 'b'], [1, 0]);
  SetLength(LReference.Groups, 2);
  LReference.Groups[1].GroupId := 'recording-b';
  SetLength(LReference.Groups[1].Counts, 2);
  LReference.Groups[1].Counts[1] := 99;
  LCandidate := Distribution(['a', 'b'], [50, 50]);
  LScore := CompareStyleDistributions(LReference, LCandidate);
  Near(LScore.Distance, 0, 'A long recording must not drown out another group');
  LCandidate.Groups[0].Counts[0] := 1;
  LCandidate.Groups[0].Counts[1] := 99;
  LScore := CompareStyleDistributions(LReference, LCandidate);
  Near(LScore.Distance, 0.49, 'Pooled duration bias must remain visible');
  LReference.Groups[0].Unknown := 1;
  LReference.Groups[0].Ambiguous := 1;
  LReference.Groups[0].Unsupported := 1;
  LScore := CompareStyleDistributions(LReference, LCandidate);
  Near(LScore.Reference.PooledCoverage, 100 / 103, 'Pooled coverage');
  Near(LScore.Reference.MeanGroupCoverage, 0.625, 'Equal-group coverage');
  Near(LScore.Reference.MinimumGroupCoverage, 0.25, 'Weakest group coverage');
  Check((LScore.Reference.Unknown = 1) and (LScore.Reference.Ambiguous = 1) and
    (LScore.Reference.Unsupported = 1), 'Uncertainty categories remain separate');
  LReference.Groups[0].Counts[0] := 0;
  LScore := CompareStyleDistributions(LReference, LCandidate);
  Check(not LScore.Comparable, 'An all-unknown group cannot disappear from comparison');
  Check(LScore.Reference.GroupsWithValues = 1, 'Known group count');
end;

procedure CheckFailures;
var
  LReference: TStyleDistribution;
  LCandidate: TStyleDistribution;
  LScore: TStyleDistributionComparison;
  LRejected: Boolean;
  I: Integer;
begin
  LReference := Distribution(['a', 'b'], [1, 1]);
  for I := 0 to 10 do
  begin
    LCandidate := Distribution(['a', 'b'], [1, 1]);
    case I of
      0: LCandidate.PolicySha256 := StringOfChar('b', 64);
      1: LCandidate.Bins[1] := 'c';
      2: LCandidate.Bins[1] := 'a';
      3: LCandidate.Groups[0].Counts[0] := -1;
      4: LCandidate.Groups[0].Counts[0] := MaximumStyleCount;
      5: LCandidate.Groups[0].Unknown := -1;
      6: LCandidate.Groups[0].GroupId := '';
      7: SetLength(LCandidate.Groups[0].Counts, 1);
      8: SetLength(LCandidate.Groups, 0);
      9:
        begin
          LCandidate.Groups[0].Counts[0] := 0;
          LCandidate.Groups[0].Counts[1] := 0;
        end;
      10:
        begin
          SetLength(LCandidate.Groups, 2);
          LCandidate.Groups[1] := LCandidate.Groups[0];
        end;
    end;
    LScore := Default(TStyleDistributionComparison);
    LScore.Distance := 0.375;
    LRejected := False;
    try
      LScore := CompareStyleDistributions(LReference, LCandidate);
    except
      on EAudio do
      begin
        LRejected := True;
      end;
    end;
    Check(LRejected, 'Malformed distribution did not reject: ' + IntToStr(I));
    Near(LScore.Distance, 0.375, 'Rejected comparison preserves caller result');
    Check((LReference.Groups[0].Counts[0] = 1) and
      (LReference.Groups[0].Counts[1] = 1), 'Borrowed reference remains unchanged');
  end;
  LReference := Distribution(['rest', 'tone'], [0, MaximumStyleCount]);
  LCandidate := Distribution(['rest', 'tone'], [0, MaximumStyleCount]);
  LScore := CompareStyleDistributions(LReference, LCandidate);
  Near(LScore.Distance, 0, 'Exact maximum count boundary');
  Near(LScore.Candidate.MinimumGroupCoverage, 1, 'Maximum count coverage');
end;

begin
  CheckRelationships;
  CheckGroupBalance;
  CheckFailures;
  Writeln('Style distribution controls passed: joint relationships, group balance, ',
    'uncertainty, contracts, bounds and rejected-result preservation.');
end.
