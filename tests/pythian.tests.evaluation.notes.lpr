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
program pythian_tests_evaluation_notes;

{$mode delphi}
{$H+}

uses
  SysUtils, pythian.audio, pythian.evaluation, pythian.evaluation.notes;

procedure Check(const ACondition: Boolean; const AMessage: String);
begin
  if not ACondition then
  begin
    raise Exception.Create(AMessage);
  end;
end;

function Note(const AId: UTF8String; const AStart, AEnd: Int64;
  const APitch: Integer): TEvaluationNote;
begin
  Result := Default(TEvaluationNote);
  Result.Id := AId;
  Result.StartFrame := AStart;
  Result.EndFrame := AEnd;
  Result.Pitch := APitch;
end;

function Regions: TEvaluationNoteRegions;
begin
  Result := nil;
  SetLength(Result, 1);
  Result[0].FirstFrame := 0;
  Result[0].EndFrame := 1000;
  Result[0].State := esValue;
end;

function Options: TOverlappingNoteOptions;
begin
  Result := Default(TOverlappingNoteOptions);
  Result.OnsetToleranceFrames := 10;
  Result.OffsetFractionDenominator := 1;
end;

function PairText(const AValue: TNoteAssignment): String;
var
  I: Integer;
begin
  Result := '';
  for I := 0 to High(AValue.Pairs) do
  begin
    Result := Result + AValue.Pairs[I].ReferenceId + ':' +
      AValue.Pairs[I].PredictionId + ';';
  end;
end;

procedure Counterexamples;
var
  LReference: TEvaluationNotes;
  LPrediction: TEvaluationNotes;
  LScore: TOverlappingNoteEvaluation;
  LPolicy: TOverlappingNoteOptions;
  LRegions: TEvaluationNoteRegions;
  LText: String;
  LSwap: TEvaluationNote;
begin
  SetLength(LReference, 2);
  SetLength(LPrediction, 2);
  LRegions := Regions;
  LPolicy := Options;
  LReference[0] := Note('r1', 100, 200, 60);
  LReference[1] := Note('r2', 100, 200, 64);
  LPrediction[0] := Note('p1', 100, 200, 64);
  LPrediction[1] := Note('p2', 100, 200, 60);
  LScore := EvaluateOverlappingNotes(LReference, LPrediction, LRegions, 0, 1000, LPolicy);
  Check((Length(LScore.FullNotes.Pairs) = 2) and
    (LScore.FullNotes.OnsetErrorFrames = 0), 'Chord order must not lose a match');
  LReference[1].StartFrame := 110;
  LPrediction[1].StartFrame := 110;
  LScore := EvaluateOverlappingNotes(LReference, LPrediction, LRegions, 0, 1000, LPolicy);
  Check((Length(LScore.FullNotes.Pairs) = 2) and
    (LScore.FullNotes.OnsetErrorFrames = 20), 'Strictly ordered starts can need crossed assignment');
  LReference[0] := Note('r1', 100, 400, 69);
  LReference[1] := Note('r2', 110, 200, 69);
  LPrediction[0] := Note('p1', 100, 200, 69);
  LPrediction[1] := Note('p2', 110, 400, 69);
  LScore := EvaluateOverlappingNotes(LReference, LPrediction, LRegions, 0, 1000, LPolicy);
  Check((Length(LScore.Onsets.Pairs) = 2) and (LScore.Onsets.OnsetErrorFrames = 0) and
    (LScore.Onsets.OffsetErrorFrames = 400) and (Length(LScore.FullNotes.Pairs) = 2) and
    (LScore.FullNotes.OnsetErrorFrames = 20) and (LScore.FullNotes.OffsetErrorFrames = 0),
    'Onset and full-note assignments have independent pairs and errors');
  Check((PairText(LScore.Onsets) = 'r1:p1;r2:p2;') and
    (PairText(LScore.FullNotes) = 'r1:p2;r2:p1;'), 'Returned matching identities differ');
  LText := PairText(LScore.FullNotes);
  LSwap := LReference[0];
  LReference[0] := LReference[1];
  LReference[1] := LSwap;
  LSwap := LPrediction[0];
  LPrediction[0] := LPrediction[1];
  LPrediction[1] := LSwap;
  LScore := EvaluateOverlappingNotes(LReference, LPrediction, LRegions, 0, 1000, LPolicy);
  Check(PairText(LScore.FullNotes) = LText, 'Input permutation changes canonical assignment');
  LReference[0] := Note('r2', 100, 200, 60);
  LReference[1] := Note('r1', 100, 200, 60);
  LPrediction[0] := Note('p2', 100, 200, 60);
  LPrediction[1] := Note('p1', 100, 200, 60);
  LScore := EvaluateOverlappingNotes(LReference, LPrediction, LRegions, 0, 1000, LPolicy);
  LText := PairText(LScore.FullNotes);
  LSwap := LPrediction[0];
  LPrediction[0] := LPrediction[1];
  LPrediction[1] := LSwap;
  LScore := EvaluateOverlappingNotes(LReference, LPrediction, LRegions, 0, 1000, LPolicy);
  Check((Length(LScore.FullNotes.Pairs) = 2) and (PairText(LScore.FullNotes) = LText),
    'Equal-cost duplicate-note multiplicity or tie replay differs');
  SetLength(LPrediction, 1);
  LScore := EvaluateOverlappingNotes(LReference, LPrediction, LRegions, 0, 1000, LPolicy);
  Check((Length(LScore.FullNotes.Pairs) = 1) and (Length(LScore.FullNotes.MissedIds) = 1),
    'One prediction cannot satisfy two equal-pitch reference events');
end;

procedure CheckOracle(const AReference, APrediction: TEvaluationNotes;
  const AFull: Boolean; const AScore: TNoteAssignment);
var
  LBestCount: Integer;
  LBestOnset: Int64;
  LBestOffset: Int64;
  LSeenR: String;
  LSeenP: String;
  LOnsetSum: Int64;
  LOffsetSum: Int64;
  R: Integer;
  P: Integer;
  I: Integer;
  J: Integer;

  procedure Enumerate(const ARow, AUsed, ACount: Integer; const AOnset, AOffset: Int64);
  var
    LOnset: Int64;
    LOffset: Int64;
    K: Integer;
  begin
    if ARow = Length(AReference) then
    begin
      if (ACount > LBestCount) or ((ACount = LBestCount) and
        ((AOnset < LBestOnset) or ((AOnset = LBestOnset) and (AOffset < LBestOffset)))) then
      begin
        LBestCount := ACount;
        LBestOnset := AOnset;
        LBestOffset := AOffset;
      end;
      Exit;
    end;
    Enumerate(ARow + 1, AUsed, ACount, AOnset, AOffset);
    for K := 0 to High(APrediction) do
    begin
      LOnset := Abs(AReference[ARow].StartFrame - APrediction[K].StartFrame);
      LOffset := Abs(AReference[ARow].EndFrame - APrediction[K].EndFrame);
      if ((AUsed and (1 shl K)) = 0) and (AReference[ARow].Pitch = APrediction[K].Pitch) and
        (LOnset <= 10) and (not AFull or (LOffset = 0)) then
      begin
        Enumerate(ARow + 1, AUsed or (1 shl K), ACount + 1,
          AOnset + LOnset, AOffset + LOffset);
      end;
    end;
  end;

begin
  LBestCount := -1;
  LBestOnset := 0;
  LBestOffset := 0;
  Enumerate(0, 0, 0, 0, 0);
  Check((Length(AScore.Pairs) = LBestCount) and (AScore.OnsetErrorFrames = LBestOnset) and
    (AScore.OffsetErrorFrames = LBestOffset), 'Independent exhaustive assignment objective differs');
  Check((Length(AScore.MissedIds) = Length(AReference) - LBestCount) and
    (Length(AScore.ExtraIds) = Length(APrediction) - LBestCount), 'Oracle unmatched count differs');
  LSeenR := ';';
  LSeenP := ';';
  LOnsetSum := 0;
  LOffsetSum := 0;
  for I := 0 to High(AScore.Pairs) do
  begin
    R := -1;
    P := -1;
    for J := 0 to High(AReference) do
    begin
      if AReference[J].Id = AScore.Pairs[I].ReferenceId then
      begin
        R := J;
      end;
    end;
    for J := 0 to High(APrediction) do
    begin
      if APrediction[J].Id = AScore.Pairs[I].PredictionId then
      begin
        P := J;
      end;
    end;
    Check((R >= 0) and (P >= 0), 'Assignment names missing event');
    Check((Pos(';' + AReference[R].Id + ';', LSeenR) = 0) and
      (Pos(';' + APrediction[P].Id + ';', LSeenP) = 0), 'Assignment double uses event');
    LSeenR := LSeenR + AReference[R].Id + ';';
    LSeenP := LSeenP + APrediction[P].Id + ';';
    Check((AReference[R].Pitch = APrediction[P].Pitch) and
      (Abs(AReference[R].StartFrame - APrediction[P].StartFrame) <= 10) and
      (not AFull or (AReference[R].EndFrame = APrediction[P].EndFrame)),
      'Assignment includes ineligible pair');
    Inc(LOnsetSum, Abs(AReference[R].StartFrame - APrediction[P].StartFrame));
    Inc(LOffsetSum, Abs(AReference[R].EndFrame - APrediction[P].EndFrame));
  end;
  Check((LOnsetSum = AScore.OnsetErrorFrames) and (LOffsetSum = AScore.OffsetErrorFrames),
    'Returned pairs do not support aggregate error');
end;

procedure TinyOracle;
var
  LReference: TEvaluationNotes;
  LPrediction: TEvaluationNotes;
  LScore: TOverlappingNoteEvaluation;
  LRegions: TEvaluationNoteRegions;
  LPolicy: TOverlappingNoteOptions;
  LSeed: UInt64;
  LStart: Int64;
  LEnd: Int64;
  LPitch: Integer;
  I: Integer;
  J: Integer;

  function NextValue(const ACount: Integer): Integer;
  begin
    LSeed := (LSeed * 1664525 + 1013904223) and $FFFFFFFF;
    Result := (LSeed shr 16) mod ACount;
  end;

begin
  LRegions := Regions;
  LPolicy := Options;
  LSeed := 1731;
  for I := 0 to 63 do
  begin
    SetLength(LReference, NextValue(5));
    SetLength(LPrediction, NextValue(5));
    for J := 0 to High(LReference) do
    begin
      LStart := 100 + NextValue(4) * 10;
      LEnd := 200 + NextValue(3) * 20;
      LPitch := 60 + NextValue(2);
      LReference[J] := Note('r' + IntToStr(J), LStart, LEnd, LPitch);
    end;
    for J := 0 to High(LPrediction) do
    begin
      LStart := 100 + NextValue(4) * 10;
      LEnd := 200 + NextValue(3) * 20;
      LPitch := 60 + NextValue(2);
      LPrediction[J] := Note('p' + IntToStr(J), LStart, LEnd, LPitch);
    end;
    LScore := EvaluateOverlappingNotes(LReference, LPrediction, LRegions, 0, 1000, LPolicy);
    CheckOracle(LReference, LPrediction, False, LScore.Onsets);
    CheckOracle(LReference, LPrediction, True, LScore.FullNotes);
  end;
end;

procedure Boundaries;
var
  LReference: TEvaluationNotes;
  LPrediction: TEvaluationNotes;
  LRegions: TEvaluationNoteRegions;
  LPolicy: TOverlappingNoteOptions;
  LScore: TOverlappingNoteEvaluation;
  LPrevious: String;
  LRejected: Boolean;
  I: Integer;
begin
  SetLength(LReference, 1);
  SetLength(LPrediction, 1);
  LReference[0] := Note('r', 100, 201, 60);
  LPrediction[0] := Note('p', 110, 221, 60);
  LRegions := Regions;
  LPolicy := Options;
  LPolicy.OffsetFractionNumerator := 1;
  LPolicy.OffsetFractionDenominator := 5;
  LScore := EvaluateOverlappingNotes(LReference, LPrediction, LRegions, 0, 1000, LPolicy);
  Check(Length(LScore.FullNotes.Pairs) = 1, 'Exact rational offset interior boundary');
  LPrediction[0].EndFrame := 222;
  LScore := EvaluateOverlappingNotes(LReference, LPrediction, LRegions, 0, 1000, LPolicy);
  Check((Length(LScore.Onsets.Pairs) = 1) and (Length(LScore.FullNotes.Pairs) = 0),
    'Fractional offset boundary rounded outward');
  LPrediction[0].StartFrame := 111;
  LScore := EvaluateOverlappingNotes(LReference, LPrediction, LRegions, 0, 1000, LPolicy);
  Check(Length(LScore.Onsets.Pairs) = 0, 'Inclusive onset tolerance exceeded');
  LPolicy := Options;
  LPolicy.EdgeFrames := 50;
  SetLength(LRegions, 3);
  LRegions[0].FirstFrame := 0;
  LRegions[0].EndFrame := 300;
  LRegions[0].State := esValue;
  LRegions[1].FirstFrame := 300;
  LRegions[1].EndFrame := 500;
  LRegions[1].State := esAmbiguous;
  LRegions[2].FirstFrame := 500;
  LRegions[2].EndFrame := 1000;
  LRegions[2].State := esRest;
  SetLength(LReference, 3);
  SetLength(LPrediction, 4);
  LReference[0] := Note('r-known', 100, 200, 60);
  LReference[1] := Note('r-uncertain', 250, 400, 64);
  LReference[2] := Note('r-edge', 0, 100, 60);
  LPrediction[0] := Note('p-known', 100, 200, 60);
  LPrediction[1] := Note('p-uncertain', 310, 400, 64);
  LPrediction[2] := Note('p-edge', 0, 100, 60);
  LPrediction[3] := Note('p-rest', 600, 700, 69);
  LScore := EvaluateOverlappingNotes(LReference, LPrediction, LRegions, 0, 1000, LPolicy);
  Check((LScore.ReferenceNotes = 1) and (LScore.PredictionNotes = 2) and
    (Length(LScore.ReferenceUncertain) = 1) and (Length(LScore.PredictionUnscorable) = 1) and
    (Length(LScore.ReferenceCensored) = 1) and (Length(LScore.PredictionCensored) = 1) and
    (LScore.RegionFrames[esAmbiguous] = 200) and (Abs(LScore.ReferenceCoverage - 0.8) < 1e-12) and
    (LScore.FullNotes.Precision = 0.5) and (LScore.FullNotes.ExtraIds[0] = 'p-rest'),
    'Uncertainty/censoring/rest denominators differ');
  LPrevious := PairText(LScore.FullNotes);
  LReference[0].StartFrame := 550;
  LReference[0].EndFrame := 650;
  LRejected := False;
  try
    LScore := EvaluateOverlappingNotes(LReference, LPrediction, LRegions, 0, 1000, LPolicy);
  except
    on LException: EAudio do
    begin
      LRejected := True;
    end;
  end;
  Check(LRejected and (PairText(LScore.FullNotes) = LPrevious),
    'Contradictory rest accepted or previous managed result replaced');
  LReference[0] := Note('r-known', 100, 200, 60);
  LRegions[1].FirstFrame := 301;
  LRejected := False;
  try
    LScore := EvaluateOverlappingNotes(LReference, LPrediction, LRegions, 0, 1000, LPolicy);
  except
    on LException: EAudio do
    begin
      LRejected := True;
    end;
  end;
  Check(LRejected, 'Missing annotation region silently treated as known');
  LRegions[1].FirstFrame := 300;
  LReference[1].Id := LReference[0].Id;
  LRejected := False;
  try
    LScore := EvaluateOverlappingNotes(LReference, LPrediction, LRegions, 0, 1000, LPolicy);
  except
    on LException: EAudio do
    begin
      LRejected := True;
    end;
  end;
  Check(LRejected, 'Duplicate event identity accepted');
  LRegions := Regions;
  LPolicy := Options;
  SetLength(LReference, MaximumNotesPerPitch + 1);
  for I := 0 to High(LReference) do
  begin
    LReference[I] := Note('r' + IntToStr(I), 100, 200, 60);
  end;
  LRejected := False;
  try
    LScore := EvaluateOverlappingNotes(LReference, nil, LRegions, 0, 1000, LPolicy);
  except
    on LException: EAudio do
    begin
      LRejected := True;
    end;
  end;
  Check(LRejected, 'Per-pitch work geometry accepted beyond limit');
  Check((LReference[0].StartFrame = 100) and (LPrediction[3].Id = 'p-rest'),
    'Borrowed inputs mutated');
end;

begin
  try
    Counterexamples;
    TinyOracle;
    Boundaries;
    WriteLn('PASS overlapping-note assignments, exhaustive tiny oracle, uncertainty and boundaries');
  except
    on LException: Exception do
    begin
      WriteLn(StdErr, LException.ClassName, ': ', LException.Message);
      ExitCode := 1;
    end;
  end;
end.
