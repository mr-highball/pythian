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

var
  D, E: TCorpusIntakeDefinition;
  P, Q: TCorpusIntakePlan;
  C: TCorpusIntakeCoverage;
  R: TCorpusIntakeRanges;
  LRejected: Boolean;
  I: Integer;
begin
  try
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
    finally P.Free; end;
    D.Ranges[1].FirstFrame := 5000; Reject(D, True);
    D := Fixture; SetLength(D.Ranges, 2);
    D.Ranges[0].EndFrame := 12000; D.Ranges[0].SongId := 'song'; D.Ranges[0].BoundaryEvidence := 'declared';
    D.Ranges[0].Multiplicity := 4; D.Ranges[1] := D.Ranges[0];
    P := TCorpusIntakePlan.Create(D);
    try
      R := P.TrainingRanges; C := P.Coverage;
      Check((Length(R) = 1) and (R[0].Multiplicity = 4), 'Exact duplicate must not amplify weight');
      Check(Abs(C.UniqueSeconds[cpTraining] - 1.5) < 1e-12, 'Duplicate duration union');
    finally P.Free; end;
    D.Ranges[1].FirstFrame := 1000; Reject(D, True);
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
  except on E: Exception do begin WriteLn(StdErr, E.Message); Halt(1); end; end;
end.
