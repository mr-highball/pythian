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
program pythian_tests_evaluation_style_card;

{$mode delphi}
{$H+}

uses
  Classes, SysUtils, Math, fpjson, jsonparser,
  pythian.audio, pythian.wave, pythian.hash, pythian.tools.files,
  pythian.evaluation, pythian.evaluation.style, pythian.evaluation.style.card,
  pythian.tools.style.card;

type
  TFixtureNote = record
    Pitch: Integer;
    DurationFrames: Integer;
  end;
  TFixtureNotes = array of TFixtureNote;

var
  GFixtureRoot: String;
  GChecks: Integer;

procedure Check(const ACondition: Boolean; const AMessage: String);
begin
  Inc(GChecks);
  if not ACondition then
  begin
    raise Exception.Create(AMessage);
  end;
end;

function Path(const AName: String): String;
begin
  Result := IncludeTrailingPathDelimiter(GFixtureRoot) + AName;
end;

procedure Save(const AName: String; const AText: UTF8String);
begin
  WriteTextFile(Path(AName), AText);
end;

function FixtureCard: TStyleCard;
var
  LClip: TAudioClip;
  LSamples: TAudioSamples;
  LBytes: TAudioBytes;
  LPolicy: String;
  I: Integer;
  LBinding: TEvaluationBinding;
begin
  SetLength(LSamples, 80);
  LClip := TAudioClip.Create(8000, 1, LSamples);
  try
    LBytes := EncodeWavePcm16(LClip);
  finally
    LClip.Free;
  end;
  WriteFileBytes(Path('source.wav'), LBytes);
  Save('preparation.txt', 'identity preparation; fixture only');
  Save('reference.txt', 'synthetic supplied notes; not acoustic truth');
  Save('annotation.txt', 'synthetic fixture; supplied events only; unspecified confidence');
  LPolicy := 'pitch-duration joint bins: low<66/high>=66; short<15/long>=15 frames; supplied-event denominator; fixture arithmetic only';
  Save('policy.txt', LPolicy);
  Save('estimator.txt', 'no inference; test fixture authoring provenance');
  LBinding := Default(TEvaluationBinding);
  LBinding.SourceSha256 := Sha256Bytes(LBytes);
  LBinding.PreparationSha256 := HashText('identity preparation; fixture only');
  LBinding.ReferenceSha256 := HashText('synthetic supplied notes; not acoustic truth');
  LBinding.AnnotationPolicySha256 := HashText('synthetic fixture; supplied events only; unspecified confidence');
  LBinding.ScoringPolicySha256 := HashText(LPolicy);
  LBinding.EstimatorSha256 := HashText('no inference; test fixture authoring provenance');
  LBinding.GroupId := 'development-fixture';
  LBinding.SampleRate := 8000;
  LBinding.SourceFrames := 80;
  LBinding.EndFrame := 80;
  LBinding.Partition := epDevelopment;
  LBinding.PreviouslyUsedForTuning := True;
  LBinding.ReferenceComplete := False;
  LBinding.EstimatorTrainingOverlap := etoNotApplicable;
  Result := Default(TStyleCard);
  Result.Id := 'caller quiet glass';
  SetLength(Result.Traits, 1);
  Result.Traits[0].Id := 'supplied-note.pitch-duration';
  Result.Traits[0].Units := 'pitch/duration category pairs';
  Result.Traits[0].Denominator := 'supplied events including unknown/ambiguous/unsupported; not elapsed time';
  Result.Traits[0].MinimumCoverage := 0.75;
  Result.Traits[0].MaximumDistance := 0.1;
  Result.Traits[0].Distribution.PolicySha256 := LBinding.ScoringPolicySha256;
  SetLength(Result.Traits[0].Distribution.Bins, 4);
  Result.Traits[0].Distribution.Bins[0] := 'high.long';
  Result.Traits[0].Distribution.Bins[1] := 'high.short';
  Result.Traits[0].Distribution.Bins[2] := 'low.long';
  Result.Traits[0].Distribution.Bins[3] := 'low.short';
  SetLength(Result.Traits[0].Distribution.Groups, 1);
  Result.Traits[0].Distribution.Groups[0].GroupId := 'recording-a';
  SetLength(Result.Traits[0].Distribution.Groups[0].Counts, 4);
  Result.Traits[0].Distribution.Groups[0].Counts[0] := 2;
  Result.Traits[0].Distribution.Groups[0].Counts[3] := 2;
  Result.Traits[0].Distribution.Groups[0].Unknown := 1;
  SetLength(Result.Traits[0].Groups, 1);
  Result.Traits[0].Groups[0].Id := 'recording-a';
  Result.Traits[0].Groups[0].Binding := LBinding;
  Result.Traits[0].Groups[0].Method := 'independently authored synthetic annotation-domain fixture, no learner';
  Result.Traits[0].Groups[0].Uncertainty := 'unspecified confidence; no audio/time/rest truth or calibrated style gate';
  for I := 0 to 5 do
    case I of
      0: Result.Traits[0].Groups[0].Assets[I] := 'source.wav';
      1: Result.Traits[0].Groups[0].Assets[I] := 'preparation.txt';
      2: Result.Traits[0].Groups[0].Assets[I] := 'reference.txt';
      3: Result.Traits[0].Groups[0].Assets[I] := 'annotation.txt';
      4: Result.Traits[0].Groups[0].Assets[I] := 'policy.txt';
      5: Result.Traits[0].Groups[0].Assets[I] := 'estimator.txt';
    end;
end;

procedure CountNotes(var ACard: TStyleCard; const ANotes: TFixtureNotes);
var
  I: Integer;
  LBin: Integer;
begin
  for I := 0 to 3 do
  begin
    ACard.Traits[0].Distribution.Groups[0].Counts[I] := 0;
  end;
  for I := 0 to High(ANotes) do
  begin
    LBin := 0;
    if ANotes[I].Pitch < 66 then
    begin
      Inc(LBin, 2);
    end;
    if ANotes[I].DurationFrames < 15 then
    begin
      Inc(LBin);
    end;
    Inc(ACard.Traits[0].Distribution.Groups[0].Counts[LBin]);
  end;
end;

procedure ExpectFileFailure(const AText, AReason: UTF8String);
var
  LCard: TStyleCard;
  LFailed: Boolean;
begin
  LCard := FixtureCard;
  LCard.Id := 'preserved prior result';
  Save('bad.json', AText);
  LFailed := False;
  try
    LCard := ReadStyleCardFile(Path('bad.json'));
  except
    on LException: Exception do
    begin
      LFailed := True;
      if AReason <> '' then
      begin
        Check(Pos(AReason, LException.Message) > 0, 'Wrong rejection: ' + LException.Message);
      end;
    end;
  end;
  Check(LFailed, 'Malformed file admitted');
  Check(LCard.Id = 'preserved prior result', 'Failed reader changed prior assignment');
end;

procedure ExpectCoreFailure(const AReference, ACandidate: TStyleCard);
var
  LResult: TStyleCardResult;
  LFailed: Boolean;
begin
  LResult := Default(TStyleCardResult);
  LResult.ReferenceId := 'preserved prior comparison';
  LFailed := False;
  try
    LResult := CompareStyleCards(AReference, ACandidate);
  except
    on LException: Exception do
    begin
      LFailed := True;
    end;
  end;
  Check(LFailed, 'Invalid core comparison admitted');
  Check(LResult.ReferenceId = 'preserved prior comparison', 'Failed scorer changed prior assignment');
end;

procedure RoundTripAndControls;
var
  LRef: TStyleCard;
  LPreserved: TStyleCard;
  LBroken: TStyleCard;
  LLoaded: TStyleCard;
  LClone: TStyleCard;
  LNotes: TFixtureNotes;
  LResult: TStyleCardResult;
  LJSON: UTF8String;
  LReport: UTF8String;
  I: Integer;
begin
  LRef := FixtureCard;
  Save('reference.json', WriteStyleCardJSON(LRef));
  LLoaded := ReadStyleCardFile(Path('reference.json'));
  Check(WriteStyleCardJSON(LLoaded) = WriteStyleCardJSON(LRef), 'Reference round-trip changed contract');
  LPreserved := CloneStyleCard(LRef);
  LPreserved.Id := 'caller thunder garden';
  SetLength(LNotes, 4);
  for I := 0 to 3 do
  begin
    if I mod 2 = 0 then
    begin
      LNotes[I].Pitch := 72;
      LNotes[I].DurationFrames := 20;
    end
    else
    begin
      LNotes[I].Pitch := 60;
      LNotes[I].DurationFrames := 10;
    end;
  end;
  { Reordered supplied notes preserve the joint observation histogram. }
  CountNotes(LPreserved, LNotes);
  Save('preserved.json', WriteStyleCardJSON(LPreserved));
  LLoaded := ReadStyleCardFile(Path('preserved.json'));
  Check(LLoaded.Id = LPreserved.Id, 'Opaque second caller label changed');
  LResult := CompareStyleCards(LRef, LLoaded);
  Check(LResult.PassedRequiredDeclaredLimits, 'Preserving supplied-event control failed');
  Check(not LResult.GroundedAcceptance, 'Fixture certified grounded style acceptance');
  Check(Abs(LResult.Traits[0].Comparison.Distance) < 1e-12, 'Preserving distance differs');
  Check(LResult.Traits[0].Comparison.Candidate.Total = 5, 'Unknown observation disappeared');
  Check(Abs(LResult.Traits[0].Comparison.Candidate.MinimumGroupCoverage - 0.8) < 1e-12, 'Wrong supplied-event denominator');
  LBroken := CloneStyleCard(LPreserved);
  for I := 0 to 3 do
  begin
    if LNotes[I].Pitch >= 66 then
    begin
      LNotes[I].DurationFrames := 10;
    end
    else
    begin
      LNotes[I].DurationFrames := 20;
    end;
  end;
  CountNotes(LBroken, LNotes);
  LBroken.Id := 'same marginals broken relationship';
  Save('broken.json', WriteStyleCardJSON(LBroken));
  LResult := CompareStyleCards(LRef, ReadStyleCardFile(Path('broken.json')));
  Check(not LResult.PassedRequiredDeclaredLimits, 'Broken joint relationship passed');
  Check(Abs(LResult.Traits[0].Comparison.Distance - 1) < 1e-12, 'Broken joint relationship distance differs');
  LReport := CompareStyleCardFiles(Path('reference.json'), Path('broken.json'));
  Check(LReport = CompareStyleCardFiles(Path('reference.json'), Path('broken.json')), 'Comparison replay changed');
  Save('broken-report.json', LReport);
  LJSON := WriteStyleCardJSON(LRef);
  LClone := CloneStyleCard(LRef);
  LClone.Traits[0].Distribution.Bins[0] := 'changed bin';
  LClone.Traits[0].Distribution.Groups[0].Counts[0] := 99;
  LClone.Traits[0].Groups[0].Assets[0] := 'changed file';
  Check(WriteStyleCardJSON(LRef) = LJSON, 'Clone aliases original mutable arrays');
  LClone := CloneStyleCard(LRef);
  SetLength(LClone.Traits[0].Groups, 2);
  SetLength(LClone.Traits[0].Distribution.Groups, 2);
  LClone.Traits[0].Groups[1] := LClone.Traits[0].Groups[0];
  LClone.Traits[0].Groups[1].Id := 'recording-b';
  LClone.Traits[0].Distribution.Groups[1] := LClone.Traits[0].Distribution.Groups[0];
  LClone.Traits[0].Distribution.Groups[1].GroupId := 'recording-b';
  Save('same-family.json', WriteStyleCardJSON(LClone));
  LLoaded := ReadStyleCardFile(Path('same-family.json'));
  Check(LLoaded.Traits[0].Groups[0].Binding.GroupId =
    LLoaded.Traits[0].Groups[1].Binding.GroupId, 'Same family changed during reload');
  Check(CompareStyleCards(LRef, LLoaded).Traits[0].Comparison.Reference.Groups = 1,
    'Reference balancing group changed');
  Check(CompareStyleCards(LRef, LLoaded).Traits[0].Comparison.Candidate.Groups = 2,
    'Separate recordings merged into exposure family');
  Check(not IsIndependentEvaluation(LLoaded.Traits[0].Groups[1].Binding),
    'Second recording promoted development family to independent evaluation');
end;

procedure MissingAndUnknown;
var
  LRef: TStyleCard;
  LCand: TStyleCard;
  LResult: TStyleCardResult;
  I: Integer;
begin
  LRef := FixtureCard;
  LCand := CloneStyleCard(LRef);
  for I := 0 to 3 do
  begin
    LCand.Traits[0].Distribution.Groups[0].Counts[I] := 0;
  end;
  LCand.Traits[0].Distribution.Groups[0].Unknown := 5;
  LResult := CompareStyleCards(LRef, LCand);
  Check(not LResult.Traits[0].Comparison.Comparable, 'Zero-known group comparable');
  Check(not LResult.PassedRequiredDeclaredLimits, 'Undefined distance passed');
  Check(Pos('"distance" : null', WriteStyleCardResultJSON(LResult)) > 0, 'Undefined report distance is not null');
  LCand := CloneStyleCard(LRef);
  LCand.Traits[0].Distribution.Groups[0].Unknown := 4;
  LCand.Traits[0].Distribution.Groups[0].Ambiguous := 1;
  LCand.Traits[0].Distribution.Groups[0].Unsupported := 1;
  LResult := CompareStyleCards(LRef, LCand);
  Check(LResult.Traits[0].Comparison.Candidate.Total = 10, 'Missing states removed from denominator');
  Check(not LResult.PassedRequiredDeclaredLimits, 'Low known coverage passed');
  LCand := CloneStyleCard(LRef);
  LCand.Traits[0].MinimumCoverage := 0;
  LCand.Traits[0].MaximumDistance := 1;
  LCand.Traits[0].Distribution.Groups[0].Unknown := 20;
  Check(not CompareStyleCards(LRef, LCand).PassedRequiredDeclaredLimits, 'Candidate overrides reference limits');
  LCand := CloneStyleCard(LRef);
  LCand.Traits[0].Support := stsUnsupported;
  LCand.Traits[0].Distribution := Default(TStyleDistribution);
  LCand.Traits[0].Groups := nil;
  LResult := CompareStyleCards(LRef, LCand);
  Check(not LResult.Traits[0].Supported and not LResult.PassedRequiredDeclaredLimits, 'Unsupported required trait passed');
  SetLength(LCand.Traits, 2);
  LCand.Traits[1] := LCand.Traits[0];
  LCand.Traits[1].Id := 'zz.optional';
  LCand.Traits[1].Requirement := strOptional;
  ExpectCoreFailure(LRef, LCand);
  LRef := FixtureCard;
  SetLength(LRef.Traits, 2);
  LRef.Traits[1] := LCand.Traits[1];
  LCand := FixtureCard;
  LResult := CompareStyleCards(LRef, LCand);
  Check(not LResult.Traits[1].Present and LResult.PassedRequiredDeclaredLimits, 'Missing optional trait hidden or blocks required pass');
  LRef.Traits[1].Requirement := strRequired;
  Check(not CompareStyleCards(LRef, LCand).PassedRequiredDeclaredLimits, 'Missing required trait passes');
  LCand := FixtureCard;
  LCand.Traits[0].Distribution.PolicySha256 := StringOfChar('a', 64);
  ExpectCoreFailure(FixtureCard, LCand);
  LCand := FixtureCard;
  LCand.Traits[0].Groups := nil;
  ExpectCoreFailure(FixtureCard, LCand);
  LCand := FixtureCard;
  LCand.Traits[0].Groups[0].Binding.EndFrame := 81;
  ExpectCoreFailure(FixtureCard, LCand);
  LCand := FixtureCard;
  LCand.Traits[0].MinimumCoverage := NaN;
  ExpectCoreFailure(FixtureCard, LCand);
  LCand := FixtureCard;
  LCand.Traits[0].MaximumDistance := Infinity;
  ExpectCoreFailure(FixtureCard, LCand);
  LCand := FixtureCard;
  LCand.Traits[0].Distribution.Groups[0].Counts[0] := -1;
  ExpectCoreFailure(FixtureCard, LCand);
  LCand := FixtureCard;
  LCand.Traits[0].Distribution.Bins[1] := LCand.Traits[0].Distribution.Bins[0];
  ExpectCoreFailure(FixtureCard, LCand);
  LCand := FixtureCard;
  LCand.Traits[0].Distribution.Groups[0].Counts[0] := MaximumStyleCount;
  ExpectCoreFailure(FixtureCard, LCand);
end;

procedure MalformedFiles;
var
  LCard: TStyleCard;
  LJSON: UTF8String;
  LRoot: TJSONObject;
  LTrait: TJSONObject;
  LGroup: TJSONObject;
  LBinding: TJSONObject;
  LBytes: TAudioBytes;
  I: Integer;
begin
  LCard := FixtureCard;
  LJSON := WriteStyleCardJSON(LCard);
  ExpectFileFailure('{"version":1,"id":"a","id":"b","traits":[]}', '');
  ExpectFileFailure('{"version":1,"id":"a","traits":[],"extra":0}', '');
  ExpectFileFailure('{"version":1,"id":1,"traits":[]}', '');
  ExpectFileFailure('{"version":1,"id":"a","traits":[],}', '');
  ExpectFileFailure(LJSON + '{}', '');
  ExpectFileFailure(StringOfChar('[', 17) + '0' + StringOfChar(']', 17), 'nesting');
  SetLength(LBytes, MaximumStyleCardDocumentBytes + 1);
  WriteFileBytes(Path('oversized.json'), LBytes);
  try
    ReadStyleCardFile(Path('oversized.json'));
    Check(False, 'Oversized document admitted');
  except
    on LException: EAudio do
    begin
      Check(True, 'Oversized document rejected');
    end;
  end;
  for I := 0 to 5 do
  begin
    LCard := FixtureCard;
    case I of
      0: LCard.Traits[0].Groups[0].Binding.SourceSha256 := StringOfChar('a', 64);
      1: LCard.Traits[0].Groups[0].Binding.PreparationSha256 := StringOfChar('a', 64);
      2: LCard.Traits[0].Groups[0].Binding.ReferenceSha256 := StringOfChar('a', 64);
      3: LCard.Traits[0].Groups[0].Binding.AnnotationPolicySha256 := StringOfChar('a', 64);
      4:
      begin
        LCard.Traits[0].Groups[0].Binding.ScoringPolicySha256 := StringOfChar('a', 64);
        LCard.Traits[0].Distribution.PolicySha256 := StringOfChar('a', 64);
      end;
      5: LCard.Traits[0].Groups[0].Binding.EstimatorSha256 := StringOfChar('a', 64);
    end;
    ExpectFileFailure(WriteStyleCardJSON(LCard), 'digest mismatch');
  end;
  LCard := FixtureCard;
  LCard.Traits[0].Groups[0].Binding.SourceFrames := 81;
  ExpectFileFailure(WriteStyleCardJSON(LCard), 'clock');
  LCard := FixtureCard;
  LCard.Traits[0].Groups[0].Binding.SampleRate := 16000;
  ExpectFileFailure(WriteStyleCardJSON(LCard), 'clock');
  LCard := FixtureCard;
  LCard.Traits[0].Groups[0].Assets[2] := 'missing-reference.txt';
  ExpectFileFailure(WriteStyleCardJSON(LCard), '');
  LRoot := TJSONObject(GetJSON(LJSON));
  try
    LTrait := TJSONObject(TJSONArray(LRoot.Find('traits')).Items[0]);
    LTrait.Find('minimum_coverage').AsFloat := -0.1;
    ExpectFileFailure(LRoot.AsJSON, 'coverage');
    LTrait.Find('minimum_coverage').AsFloat := 0.75;
    LTrait.Find('maximum_distance').AsFloat := 1.1;
    ExpectFileFailure(LRoot.AsJSON, 'distance');
    LTrait.Find('maximum_distance').AsFloat := 0.1;
    LGroup := TJSONObject(TJSONArray(LTrait.Find('groups')).Items[0]);
    TJSONArray(LGroup.Find('counts')).Items[0] := TJSONFloatNumber.Create(1.5);
    ExpectFileFailure(LRoot.AsJSON, 'integer');
    TJSONArray(LGroup.Find('counts')).Items[0] := TJSONInt64Number.Create(2);
    LBinding := TJSONObject(LGroup.Find('binding'));
    LBinding.Find('partition').AsString := 'evaluation';
    ExpectFileFailure(LRoot.AsJSON, 'untouched');
  finally
    LRoot.Free;
  end;
end;

begin
  try
    if ParamCount <> 1 then
    begin
      raise Exception.Create('Expected ignored fixture output directory');
    end;
    GFixtureRoot := ExpandFileName(ParamStr(1));
    ForceDirectories(GFixtureRoot);
    RoundTripAndControls;
    MissingAndUnknown;
    MalformedFiles;
    WriteLn('Style card contract checks passed: ', GChecks);
    WriteLn('Synthetic supplied-event controls only; no grounded musical acceptance.');
  except
    on LException: Exception do
    begin
      WriteLn(StdErr, LException.Message);
      Halt(1);
    end;
  end;
end.
