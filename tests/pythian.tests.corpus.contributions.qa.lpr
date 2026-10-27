(* MIT License
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
SOFTWARE. *)
program pythian_tests_corpus_contributions_qa;
{$mode delphi}{$H+}
uses SysUtils, Classes, fpjson, jsonparser, pythian.audio, pythian.corpus.intake,
  pythian.tools.corpus.intake;

var GChecks: Integer;

procedure Check(const ACondition: Boolean; const AMessageText: String);
begin
  if not ACondition then
  begin
    raise Exception.Create(AMessageText);
  end;
  Inc(GChecks);
end;

function Fixture: TCorpusIntakeDefinition;
begin
  Result := Default(TCorpusIntakeDefinition);
  SetLength(Result.Families, 1);
  SetLength(Result.Sources, 1);
  with Result.Families[0] do
  begin
    Id := 'family';
    WorkId := 'work';
    IdentityEvidence := 'caller';
    Partition := cpTraining;
    Verified := True;
  end;
  with Result.Sources[0] do
  begin
    Id := 'source';
    Path := 'source.wav';
    Sha256 := StringOfChar('a', 64);
    RecordingId := 'recording';
    SampleRate := 8000;
    Channels := 1;
    FrameCount := MaximumIntakeFrame;
    Acquisition := 'caller';
    LicenseNotice := 'MIT';
    PreparationPolicy := 'unchanged';
    PreparationSha256 := StringOfChar('b', 64);
    PreparationAccepted := True;
    PeakCeiling := 0.9;
    Parent := -1;
    ParentEndFrame := FrameCount;
    ParentGain := 1;
  end;
end;

procedure OverflowCheck(const ADefinition: TCorpusIntakeDefinition; const ALabelText: String);
var
  LPlan: TCorpusIntakePlan;
  LContributions: TCorpusIntakeCoverage;
  LRejected: Boolean;
begin
  LPlan := TCorpusIntakePlan.Create(ADefinition);
  try
    LContributions := LPlan.Coverage;
    Check(LContributions.UniqueSeconds[cpTraining] > 0, ALabelText + ' coverage remains available');
    LRejected := False;
    try
      LPlan.Contributions;
    except
      on LException: EAudio do
      begin
        LRejected := True;
      end;
    end;
    Check(LRejected, ALabelText + ' rejects weighted overflow');
  finally
    LPlan.Free;
  end;
end;

procedure ConsumerCheck;
var
  LPlan: TCorpusIntakePlan;
  LReplay: TCorpusIntakePlan;
  LStrings: TStringList;
  LJson: TJSONObject;
  LTextA: String;
  LTextB: String;
  LRanges: TCorpusIntakeRanges;
begin
  LPlan := ReadCorpusIntake(ParamStr(1) + '/example-0.json');
  try
    LTextA := EncodeCorpusIntake(LPlan);
    LRanges := LPlan.TrainingRanges;
    Check((Length(LRanges) = 2) and (LRanges[0].EndFrame = 6000) and
      (LRanges[1].FirstFrame = 10000), 'consumer excludes unknown and development ranges');
    LJson := TJSONObject(GetJSON(CorpusIntakeAuditJSON(LPlan)));
    try
      Check((LJson.Objects['training'].Integers['declared_range_rows'] = 3) and
        (LJson.Objects['development'].Integers['declared_range_rows'] = 1), 'consumer partition rows');
      Check((LJson.Objects['declared_contributions'].Strings['training_admission'] = 'not_assessed') and
        (LJson.Objects['declared_contributions'].Strings['repeated_section_identity'] = 'unknown'),
        'consumer declares accounting scope');
      Check((LJson.Objects['declared_contributions'].Arrays['recordings'].Objects[0].Int64s['unknown_song_frames'] = 4000) and
        (LJson.Objects['declared_contributions'].Arrays['recordings'].Objects[0].Int64s['unique_original_frames'] = 16000),
        'consumer original clock and unknown union');
    finally
      LJson.Free;
    end;
    LStrings := TStringList.Create;
    try
      LStrings.Text := LTextA;
      LStrings.SaveToFile(ParamStr(1) + '/canonical.json');
    finally
      LStrings.Free;
    end;
    LReplay := ReadCorpusIntake(ParamStr(1) + '/canonical.json');
    try
      Check(EncodeCorpusIntake(LReplay) = LTextA, 'canonical replay');
    finally
      LReplay.Free;
    end;
  finally
    LPlan.Free;
  end;
  LearnCorpusIntake(ParamStr(1) + '/example-0.json', ParamStr(1) + '/run-a', '', 4, 2);
  LearnCorpusIntake(ParamStr(1) + '/canonical.json', ParamStr(1) + '/run-b', '', 4, 2);
  LStrings := TStringList.Create;
  try
    LStrings.LoadFromFile(ParamStr(1) + '/run-a.wfcs');
    LTextA := LStrings.Text;
    LStrings.LoadFromFile(ParamStr(1) + '/run-b.wfcs');
    LTextB := LStrings.Text;
    Check(LTextA = LTextB, 'consumer learned model replay');
    LStrings.LoadFromFile(ParamStr(1) + '/run-a.audit.json');
    LJson := TJSONObject(GetJSON(LStrings.Text));
    try
      Check((LJson.Integers['training_segments'] = 2) and (LJson.Integers['training_observations'] = 3),
        'actual learned observations remain separate from declarations');
    finally
      LJson.Free;
    end;
  finally
    LStrings.Free;
  end;
end;

var
  LDefinition: TCorpusIntakeDefinition;
  LPlan: TCorpusIntakePlan;
  LContributions: TCorpusRecordingContributions;
  LRanges: TCorpusIntakeRanges;
begin
  LDefinition := Fixture;
  SetLength(LDefinition.Ranges, 2);
  LDefinition.Ranges[0].EndFrame := 100;
  LDefinition.Ranges[0].SongId := 'song';
  LDefinition.Ranges[0].BoundaryEvidence := 'first';
  LDefinition.Ranges[0].Multiplicity := 3;
  LDefinition.Ranges[1] := LDefinition.Ranges[0];
  LDefinition.Ranges[1].BoundaryEvidence := 'second';
  LPlan := TCorpusIntakePlan.Create(LDefinition);
  try
    LContributions := LPlan.Contributions;
    LRanges := LPlan.TrainingRanges;
    Check((LContributions[0].DeclaredRows = 2) and (LContributions[0].DistinctDeclarations = 1) and
      (LContributions[0].DeclaredWeightedFrames = 300) and (LContributions[0].UniqueFrames = 100), 'duplicate accounting');
    Check((Length(LRanges) = 1) and (LRanges[0].Multiplicity = 3), 'training duplicate weight');
  finally
    LPlan.Free;
  end;
  LDefinition.Ranges[0].EndFrame := MaximumIntakeFrame;
  LDefinition.Ranges[0].Multiplicity := 2;
  SetLength(LDefinition.Ranges, 1);
  OverflowCheck(LDefinition, 'product');
  LDefinition.Ranges[0].Multiplicity := 1;
  SetLength(LDefinition.Ranges, 2);
  LDefinition.Ranges[1] := LDefinition.Ranges[0];
  LDefinition.Ranges[1].FirstFrame := 1;
  OverflowCheck(LDefinition, 'sum');
  LDefinition.Ranges[0].EndFrame := MaximumIntakeFrame - 1;
  LDefinition.Ranges[1].FirstFrame := MaximumIntakeFrame - 1;
  LPlan := TCorpusIntakePlan.Create(LDefinition);
  try
    LContributions := LPlan.Contributions;
    Check(LContributions[0].DeclaredWeightedFrames = MaximumIntakeFrame, 'exact sum limit');
  finally
    LPlan.Free;
  end;
  if ParamCount > 0 then
  begin
    ConsumerCheck;
  end;
  WriteLn('PASS ', GChecks, ' independent contribution boundary checks');
end.
