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
program pythian_tests_corpus_intake;

{$mode delphi}
{$H+}

uses SysUtils, Math, pythian.audio, pythian.corpus.intake;

var LChecks: Integer;

procedure Check(const ACondition: Boolean; const AMessage: String);
begin
  if not ACondition then raise Exception.Create(AMessage);
  Inc(LChecks);
end;

function Fixture: TCorpusIntakeDefinition;
begin
  Result := Default(TCorpusIntakeDefinition);
  SetLength(Result.Families, 1); SetLength(Result.Sources, 1);
  with Result.Families[0] do
  begin
    Id := 'family'; WorkId := 'work'; IdentityEvidence := 'independent caller declaration';
    Partition := cpTraining; Verified := True;
  end;
  with Result.Sources[0] do
  begin
    Id := 'original'; Path := 'public-example.wav'; Sha256 := StringOfChar('a', 64);
    RecordingId := 'recording'; SampleRate := 8000; Channels := 1; FrameCount := 16000;
    Acquisition := 'caller'; LicenseNotice := 'MIT'; PreparationPolicy := 'unchanged';
    PreparationSha256 := StringOfChar('b', 64); PreparationAccepted := True;
    PeakCeiling := 0.9; Parent := -1; ParentEndFrame := FrameCount; ParentGain := 1;
    SingleSongId := 'song'; SongEvidence := 'caller reviewed boundary';
  end;
end;

procedure Reject(const D: TCorpusIntakeDefinition; const ATraining: Boolean = False);
var P: TCorpusIntakePlan; LRejected: Boolean;
begin
  P := nil; LRejected := False;
  try
    try
      P := TCorpusIntakePlan.Create(D);
      if ATraining then P.TrainingRanges;
    except on E: EAudio do LRejected := True; end;
  finally P.Free; end;
  Check(LRejected, 'Invalid intake accepted');
end;

procedure SectionChecks;
var
  LDefinition: TCorpusIntakeDefinition;
  LCopy: TCorpusIntakeDefinition;
  LPlan: TCorpusIntakePlan;
  LRows: TCorpusRecordingContributions;
  LGroups: TCorpusSectionContributions;
  LOriginal: Integer;
  LFirst: Int64;
  LEnd: Int64;
  LIndex: Integer;
begin
  LDefinition := Fixture;
  LPlan := TCorpusIntakePlan.Create(LDefinition);
  try
    LRows := LPlan.Contributions;
    LGroups := LPlan.SectionContributions;
    Check((Length(LGroups) = 0) and (LRows[0].SectionTaggedFrames = 0) and
      (LRows[0].UnknownSectionFrames = LRows[0].UniqueFrames),
      'Omitted section declarations preserve unknown selected coverage');
  finally
    LPlan.Free;
  end;
  LDefinition.Sources[0].SingleSongId := '';
  LDefinition.Sources[0].SongEvidence := '';
  SetLength(LDefinition.Families, 2);
  LDefinition.Families[1] := LDefinition.Families[0];
  LDefinition.Families[1].Id := 'other-family';
  LDefinition.Families[1].WorkId := 'other-work';
  LDefinition.Families[1].Partition := cpDevelopment;
  SetLength(LDefinition.Sources, 3);
  LDefinition.Sources[1] := LDefinition.Sources[0];
  LDefinition.Sources[1].Id := 'derivative';
  LDefinition.Sources[1].Sha256 := StringOfChar('c', 64);
  LDefinition.Sources[1].Parent := 0;
  LDefinition.Sources[1].ParentFirstFrame := 4000;
  LDefinition.Sources[1].ParentEndFrame := 12000;
  LDefinition.Sources[1].FrameCount := 8000;
  LDefinition.Sources[2] := LDefinition.Sources[0];
  LDefinition.Sources[2].Id := 'other';
  LDefinition.Sources[2].RecordingId := 'other-recording';
  LDefinition.Sources[2].Family := 1;
  LDefinition.Sources[2].Sha256 := StringOfChar('d', 64);
  SetLength(LDefinition.Ranges, 3);
  LDefinition.Ranges[0].EndFrame := 8000;
  LDefinition.Ranges[0].Multiplicity := 1;
  LDefinition.Ranges[1].Source := 1;
  LDefinition.Ranges[1].EndFrame := 8000;
  LDefinition.Ranges[1].Multiplicity := 2;
  LDefinition.Ranges[2].Source := 2;
  LDefinition.Ranges[2].EndFrame := 8000;
  LDefinition.Ranges[2].Multiplicity := 1;
  SetLength(LDefinition.SectionOccurrences, 5);
  for LIndex := 0 to 4 do
  begin
    LDefinition.SectionOccurrences[LIndex].SectionId := 'A';
    LDefinition.SectionOccurrences[LIndex].Evidence := 'caller assertion';
  end;
  LDefinition.SectionOccurrences[0].FirstFrame := 4000;
  LDefinition.SectionOccurrences[0].EndFrame := 6000;
  LDefinition.SectionOccurrences[1].Source := 1;
  LDefinition.SectionOccurrences[1].EndFrame := 2000;
  LDefinition.SectionOccurrences[1].Evidence := 'another assertion';
  LDefinition.SectionOccurrences[2].FirstFrame := 5500;
  LDefinition.SectionOccurrences[2].EndFrame := 7500;
  LDefinition.SectionOccurrences[3].FirstFrame := 7000;
  LDefinition.SectionOccurrences[3].EndFrame := 9000;
  LDefinition.SectionOccurrences[3].SectionId := 'B';
  LDefinition.SectionOccurrences[4].Source := 2;
  LDefinition.SectionOccurrences[4].FirstFrame := 1000;
  LDefinition.SectionOccurrences[4].EndFrame := 2000;
  LPlan := TCorpusIntakePlan.Create(LDefinition);
  try
    LPlan.OriginalOccurrence(1, LOriginal, LFirst, LEnd);
    Check((LOriginal = 0) and (LFirst = 4000) and (LEnd = 6000), 'Occurrence original mapping');
    LRows := LPlan.Contributions;
    Check((Length(LRows) = 2) and (LRows[0].RecordingId = 'other-recording') and
      (LRows[0].SectionTaggedFrames = 1000) and (LRows[0].UnknownSectionFrames = 7000) and
      (LRows[0].Partition = cpDevelopment), 'Other recording section coverage');
    Check((LRows[1].UniqueFrames = 12000) and (LRows[1].UnknownBoundaryFrames = 12000) and
      (LRows[1].SectionTaggedFrames = 5000) and (LRows[1].UnknownSectionFrames = 7000) and
      (LRows[1].DeclaredWeightedFrames = 24000), 'Cross-group physical union and unknown coverage');
    LGroups := LPlan.SectionContributions;
    Check((Length(LGroups) = 3) and (LGroups[1].SectionId = 'A') and
      (LGroups[1].DeclaredRows = 3) and (LGroups[1].DistinctOccurrences = 2) and
      (LGroups[1].UniqueFrames = 3500) and (LGroups[2].SectionId = 'B') and
      (LGroups[2].UniqueFrames = 2000), 'Alias, overlap and section group accounting');
    LDefinition.SectionOccurrences[0].Evidence := 'mutated';
    LCopy := LPlan.CopyDefinition;
    Check(LCopy.SectionOccurrences[0].Evidence = 'caller assertion', 'Input evidence detached');
    LCopy.SectionOccurrences[0].Evidence := 'output mutation';
    LCopy := LPlan.CopyDefinition;
    LGroups[1].SectionId := 'mutated';
    LGroups := LPlan.SectionContributions;
    Check((LCopy.SectionOccurrences[0].Evidence = 'caller assertion') and
      (LGroups[1].SectionId = 'A'), 'Returned evidence and rows detached');
  finally
    LPlan.Free;
  end;
  LCopy := LDefinition;
  LCopy.SectionOccurrences := Copy(LDefinition.SectionOccurrences);
  LCopy.SectionOccurrences[0] := LDefinition.SectionOccurrences[4];
  LCopy.SectionOccurrences[4] := LDefinition.SectionOccurrences[0];
  LPlan := TCorpusIntakePlan.Create(LCopy);
  try
    LGroups := LPlan.SectionContributions;
    LRows := LPlan.Contributions;
    Check((LGroups[1].DistinctOccurrences = 2) and (LGroups[1].UniqueFrames = 3500) and
      (LRows[1].SectionTaggedFrames = 5000), 'Section declaration order does not change accounting');
  finally
    LPlan.Free;
  end;
  LDefinition.SectionOccurrences[0].Evidence := '';
  Reject(LDefinition);
  LDefinition.SectionOccurrences[0].Evidence := 'caller assertion';
  LDefinition.SectionOccurrences[0].SectionId := '';
  Reject(LDefinition);
  LDefinition.SectionOccurrences[0].SectionId := 'A';
  LDefinition.SectionOccurrences[0].Evidence := StringOfChar('e', 4097);
  Reject(LDefinition);
  LDefinition.SectionOccurrences[0].Evidence := 'caller assertion';
  LDefinition.SectionOccurrences[0].EndFrame := MaximumIntakeFrame;
  Reject(LDefinition);
  LDefinition.SectionOccurrences[0].EndFrame := 6000;
  LDefinition.Ranges[0].EndFrame := 5000;
  LDefinition.Ranges[1].FirstFrame := 2000;
  Reject(LDefinition);
  SetLength(LDefinition.SectionOccurrences, MaximumIntakeSectionOccurrences + 1);
  Reject(LDefinition);
  LDefinition := Fixture;
  LDefinition.Sources[0].FrameCount := MaximumIntakeFrame;
  LDefinition.Sources[0].ParentEndFrame := MaximumIntakeFrame;
  SetLength(LDefinition.SectionOccurrences, 1);
  LDefinition.SectionOccurrences[0].FirstFrame := MaximumIntakeFrame - 100;
  LDefinition.SectionOccurrences[0].EndFrame := MaximumIntakeFrame;
  LDefinition.SectionOccurrences[0].SectionId := 'boundary';
  LDefinition.SectionOccurrences[0].Evidence := 'caller assertion';
  LPlan := TCorpusIntakePlan.Create(LDefinition);
  try
    LRows := LPlan.Contributions;
    Check((LRows[0].SectionTaggedFrames = 100) and
      (LRows[0].UnknownSectionFrames = MaximumIntakeFrame - 100),
      'Exact integer section boundary remains valid');
  finally
    LPlan.Free;
  end;
end;

var
  D, E: TCorpusIntakeDefinition;
  P, Q: TCorpusIntakePlan;
  C: TCorpusIntakeCoverage;
  R: TCorpusIntakeRanges;
  Contributions: TCorpusRecordingContributions;
  Again: TCorpusRecordingContributions;
  LRejected: Boolean;
  I: Integer;
begin
  try
    SectionChecks;
    D := Fixture;
    P := TCorpusIntakePlan.Create(D);
    try
      D.Sources[0].Path := 'mutated.wav';
      E := P.CopyDefinition; Check(E.Sources[0].Path = 'public-example.wav', 'Input arrays were not detached');
      E.Sources[0].Path := 'mutated-again.wav';
      E := P.CopyDefinition; Check(E.Sources[0].Path = 'public-example.wav', 'Output arrays were not detached');
      C := P.Coverage; Check(Abs(C.UniqueSeconds[cpTraining] - 2) < 1e-12, 'Unique duration');
      Check(C.DeclaredVerifiedGroups[cpTraining] = 1, 'Group count');
      R := P.TrainingRanges; Check((Length(R) = 1) and (R[0].SongId = 'song'), 'Optional known whole song');
    finally P.Free; end;
    D := Fixture; D.Sources[0].SingleSongId := ''; D.Sources[0].SongEvidence := '';
    P := TCorpusIntakePlan.Create(D);
    try
      C := P.Coverage; Check(Abs(C.UnknownBoundarySeconds[cpTraining] - 2) < 1e-12, 'Absent songs must stay unknown');
    finally P.Free; end;
    Reject(D, True);
    D := Fixture; D.Families[0].Verified := False; Reject(D);
    D.Families[0].Partition := cpDevelopment;
    P := TCorpusIntakePlan.Create(D); P.Free; Check(True, 'Unknown development identity');
    D := Fixture; D.Families[0].Partition := cpEvaluation; D.Families[0].PriorExposure := [cpTraining]; Reject(D);
    D := Fixture; D.Sources[0].LicenseNotice := ''; Reject(D);
    D := Fixture; D.Sources[0].PeakCeiling := 1; Reject(D);
    D := Fixture; D.Sources[0].Parent := 0; Reject(D);
    D := Fixture; SetLength(D.Sources, 2); D.Sources[1] := D.Sources[0];
    D.Sources[1].Id := 'alias'; D.Sources[1].RecordingId := 'fake independent recording'; Reject(D);
    D := Fixture; SetLength(D.Ranges, 3);
    D.Sources[0].SingleSongId := ''; D.Sources[0].SongEvidence := '';
    for I := 0 to 2 do begin D.Ranges[I].Multiplicity := 1; end;
    D.Ranges[0].EndFrame := 6000; D.Ranges[0].SongId := 'left'; D.Ranges[0].BoundaryEvidence := 'declared';
    D.Ranges[1].FirstFrame := 6000; D.Ranges[1].EndFrame := 10000;
    D.Ranges[2].FirstFrame := 10000; D.Ranges[2].EndFrame := 16000;
    D.Ranges[2].SongId := 'right'; D.Ranges[2].BoundaryEvidence := 'declared';
    P := TCorpusIntakePlan.Create(D);
    try
      C := P.Coverage; R := P.TrainingRanges;
      Check((Length(R) = 2) and (R[0].EndFrame = 6000) and (R[1].FirstFrame = 10000), 'Unknown span exclusion');
      Check(Abs(C.UnknownBoundarySeconds[cpTraining] - 0.5) < 1e-12, 'Unknown union');
      Contributions := P.Contributions;
      Check((Contributions[0].UniqueFrames = 16000) and
        (Contributions[0].UnknownBoundaryFrames = 4000) and
        (Contributions[0].DeclaredRows = 3) and
        (Contributions[0].DeclaredWeightedFrames = 16000), 'Unknown contribution');
    finally P.Free; end;
    D.Ranges[1].FirstFrame := 5000; Reject(D, True);
    D := Fixture; SetLength(D.Ranges, 2);
    D.Ranges[0].EndFrame := 12000; D.Ranges[0].SongId := 'song'; D.Ranges[0].BoundaryEvidence := 'declared';
    D.Ranges[0].Multiplicity := 4; D.Ranges[1] := D.Ranges[0];
    D.Ranges[1].BoundaryEvidence := 'another supporting source';
    P := TCorpusIntakePlan.Create(D);
    try
      R := P.TrainingRanges; C := P.Coverage;
      Check((Length(R) = 1) and (R[0].Multiplicity = 4), 'Exact duplicate must not amplify weight');
      Check(Abs(C.UniqueSeconds[cpTraining] - 1.5) < 1e-12, 'Duplicate duration union');
      Contributions := P.Contributions;
      Check((Length(Contributions) = 1) and
        (Contributions[0].RecordingId = 'recording') and
        (Contributions[0].UniqueFrames = 12000) and
        (Contributions[0].DeclaredRows = 2) and
        (Contributions[0].DistinctDeclarations = 1) and
        (Contributions[0].DeclaredWeightedFrames = 48000), 'Duplicate weighted declaration');
      Contributions[0].RecordingId := 'mutated';
      Again := P.Contributions;
      Check(Again[0].RecordingId = 'recording', 'Contribution result must be detached');
    finally P.Free; end;
    D.Ranges[1].FirstFrame := 1000; Reject(D, True);
    D := Fixture;
    D.Sources[0].SingleSongId := ''; D.Sources[0].SongEvidence := '';
    SetLength(D.Sources, 2); D.Sources[1] := D.Sources[0];
    D.Sources[1].Id := 'derivative'; D.Sources[1].Sha256 := StringOfChar('c', 64);
    D.Sources[1].Parent := 0; D.Sources[1].ParentFirstFrame := 4000;
    D.Sources[1].ParentEndFrame := 12000; D.Sources[1].FrameCount := 8000;
    SetLength(D.Ranges, 2);
    D.Ranges[0].EndFrame := 8000; D.Ranges[0].Multiplicity := 1;
    D.Ranges[1].Source := 1; D.Ranges[1].EndFrame := 8000; D.Ranges[1].Multiplicity := 2;
    P := TCorpusIntakePlan.Create(D);
    try
      Contributions := P.Contributions;
      Check((Contributions[0].UniqueFrames = 12000) and
        (Contributions[0].UnknownBoundaryFrames = 12000) and
        (Contributions[0].DeclaredWeightedFrames = 24000), 'Mapped derivative union');
    finally
      P.Free;
    end;
    E := D; E.Ranges := Copy(D.Ranges); E.Ranges[0] := D.Ranges[1]; E.Ranges[1] := D.Ranges[0];
    P := TCorpusIntakePlan.Create(E);
    try
      Again := P.Contributions;
      Check((Again[0].UniqueFrames = Contributions[0].UniqueFrames) and
        (Again[0].DeclaredWeightedFrames = Contributions[0].DeclaredWeightedFrames), 'Order replay');
    finally
      P.Free;
    end;
    D := Fixture; SetLength(D.Families, 2); SetLength(D.Sources, 2);
    D.Families[1] := D.Families[0]; D.Families[1].Id := 'family-2';
    D.Families[1].WorkId := 'work-2'; D.Families[1].Partition := cpDevelopment;
    D.Sources[1] := D.Sources[0]; D.Sources[1].Id := 'second';
    D.Sources[1].RecordingId := 'another'; D.Sources[1].Family := 1;
    D.Sources[1].Sha256 := StringOfChar('c', 64); D.Sources[1].SingleSongId := 'song-2';
    SetLength(D.Ranges, 2); D.Ranges[0].EndFrame := 8000;
    D.Ranges[0].SongId := 'song'; D.Ranges[0].BoundaryEvidence := 'declared';
    D.Ranges[0].Multiplicity := 1; D.Ranges[1] := D.Ranges[0];
    D.Ranges[1].Source := 1; D.Ranges[1].SongId := 'song-2';
    P := TCorpusIntakePlan.Create(D);
    try
      Contributions := P.Contributions;
      Check((Length(Contributions) = 2) and (Contributions[0].RecordingId = 'another') and
        (Contributions[0].Partition = cpDevelopment) and
        (Contributions[1].RecordingId = 'recording') and
        (Contributions[1].Partition = cpTraining), 'Recording and partition order');
    finally
      P.Free;
    end;
    D := Fixture; D.Sources[0].FrameCount := MaximumIntakeFrame;
    D.Sources[0].ParentEndFrame := MaximumIntakeFrame;
    SetLength(D.Ranges, 1); D.Ranges[0].EndFrame := MaximumIntakeFrame;
    D.Ranges[0].SongId := 'song'; D.Ranges[0].BoundaryEvidence := 'declared';
    D.Ranges[0].Multiplicity := 2;
    P := TCorpusIntakePlan.Create(D);
    try
      C := P.Coverage;
      LRejected := False;
      try
        Contributions := P.Contributions;
      except
        on E: EAudio do
        begin
          LRejected := True;
        end;
      end;
      Check(LRejected and (C.UniqueSeconds[cpTraining] > 0), 'Weight overflow and coverage preservation');
    finally
      P.Free;
    end;
    D := Fixture; P := TCorpusIntakePlan.Create(D);
    D.Families[0].PreviouslyUsed := True; D.Families[0].PriorExposure := [cpDevelopment];
    Q := TCorpusIntakePlan.Create(D);
    try
      RequireIntakeHistory(P, Q); Check(True, 'New exposure retained');
      LRejected := False;
      try RequireIntakeHistory(Q, P); except on E: EAudio do LRejected := True; end;
      Check(LRejected, 'History may not erase exposure');
    finally Q.Free; P.Free; end;
    WriteLn('Corpus intake core: ', LChecks, ' checks passed');
  except
    on E: Exception do
    begin
      WriteLn(E.Message);
      {$ifdef pas2js}
      raise;
      {$else}
      Halt(1);
      {$endif}
    end;
  end;
end.
