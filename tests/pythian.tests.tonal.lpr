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
program pythian.tests.tonal;

{$mode delphi}
{$H+}

uses
  SysUtils,
  Math,
  pythian.audio,
  pythian.time,
  pythian.music,
  pythian.analysis,
  pythian.tonal;

procedure Check(const ACondition: Boolean; const AMessage: String);
begin
  if not ACondition then
  begin
    raise EAudio.Create(AMessage);
  end;
end;

procedure CheckProfiles;
var
  LWeights: TPitchClassWeights;
  LReport: TTonalReport;
  LFeatures: TAudioFeatures;
  LOptions: TAnalysisOptions;
  LNotes: TNoteGates;
  LTempos: TTempoChanges;
  LSequence: TNoteSequence;
  LSamples: TAudioSamples;
  LClip: TAudioClip;
  LIndex: Integer;
  LRejected: Boolean;
begin
  LWeights := Default(TPitchClassWeights);
  LReport := RankDiatonicFits(LWeights);
  Check((LReport.CandidateCount = 0) and (LReport.Fits[0].Root = -1) and
    (LReport.ScoreGap = 0), 'Empty evidence does not invent C major');
  for LIndex := 0 to 11 do
  begin
    LWeights[LIndex] := 1;
  end;
  LReport := RankDiatonicFits(LWeights);
  Check((LReport.CandidateCount = 24) and (LReport.ScoreGap = 0), 'Uniform chroma is tied');
  for LIndex := 0 to 23 do
  begin
    Check((LReport.Fits[LIndex].Root = LIndex div 2) and
      (Ord(LReport.Fits[LIndex].Mode) = LIndex mod 2), 'Stable root then mode tie order');
  end;
  LWeights := Default(TPitchClassWeights);
  LWeights[0] := 8;
  LWeights[4] := 4;
  LWeights[7] := 4;
  LReport := RankDiatonicFits(LWeights);
  Check((LReport.Fits[0].Root = 0) and (LReport.Fits[0].Mode = dmMajor) and
    (Abs(LReport.Fits[0].Score - 1.0875) < 1E-12) and
    (LReport.Fits[0].Coverage = 1), 'Independent C-major triad membership and bonuses');
  SetLength(LTempos, 1);
  LTempos[0] := MakeTempoChange(0, 500000);
  SetLength(LNotes, 2);
  for LIndex := 0 to 1 do
  begin
    LNotes[LIndex] := Default(TNoteGate);
    LNotes[LIndex].Velocity := 127;
  end;
  LNotes[0].Pitch := 60;
  LNotes[0].EndTick := 4800;
  LNotes[0].Velocity := 64;
  LNotes[1].Pitch := 64;
  LNotes[1].EndTick := 480;
  LSequence := TNoteSequence.Create(480, 4800, LTempos, LNotes);
  try
    LWeights := NotePitchClassWeights(LSequence, 1920);
    Check((LWeights[0] = 1920) and (LWeights[4] = 480), 'Explicit per-note duration cap');
    LWeights := NotePitchClassWeights(LSequence);
    Check(LWeights[0] = 4800, 'Uncapped duration is available');
    LWeights := NotePitchClassWeights(LSequence, 1920, True);
    Check(Abs(LWeights[0] - 1920 * 64 / 127) < 1E-9, 'Optional velocity weighting');
  finally
    LSequence.Free;
  end;
  LOptions := DefaultAnalysisOptions;
  LOptions.WindowFrames := 64;
  LOptions.HopFrames := 32;
  SetLength(LFeatures, 2);
  LFeatures[0] := Default(TAudioFeature);
  LFeatures[0].ValidFrames := 40;
  LFeatures[0].Rms := 0.5;
  LFeatures[0].Chroma[0] := 1;
  LFeatures[1] := Default(TAudioFeature);
  LFeatures[1].StartFrame := 32;
  LFeatures[1].ValidFrames := 8;
  LFeatures[1].Rms := 1;
  LFeatures[1].Chroma[7] := 1;
  LWeights := FeaturePitchClassWeights(LFeatures, LOptions, 40);
  Check((LWeights[0] = 32) and (LWeights[7] = 8), 'Each hop contributes only its source coverage');
  LWeights := FeaturePitchClassWeights(LFeatures, LOptions, 40, True);
  Check((LWeights[0] = 8) and (LWeights[7] = 8), 'Independent RMS-squared duration weights');
  LFeatures[1].Chroma[0] := 1;
  LRejected := False;
  try
    LWeights := FeaturePitchClassWeights(LFeatures, LOptions, 40);
  except
    on EAudio do
    begin
      LRejected := True;
    end;
  end;
  Check(LRejected and (LWeights[0] = 8), 'Invalid chroma preserves previous profile');
  SetLength(LSamples, 8192);
  for LIndex := 0 to High(LSamples) do
  begin
    LSamples[LIndex] := 0.5 * Sin(2 * Pi * 440 * LIndex / 40960);
  end;
  LClip := TAudioClip.Create(40960, 1, LSamples);
  try
    LOptions := DefaultAnalysisOptions;
    LOptions.HopFrames := LOptions.WindowFrames;
    LFeatures := AnalyzeAudio(LClip, LOptions);
    LWeights := FeaturePitchClassWeights(LFeatures, LOptions, LClip.FrameCount);
    LReport := RankDiatonicFits(LWeights);
    Check(LWeights[9] > 0.999 * LReport.TotalWeight,
      'Known A440 signal dominates pitch class A after actual FFT analysis');
  finally
    LClip.Free;
  end;
end;

procedure CheckReferenceSelections;
const
  { Captured from the actual precursor before reference removal. See TONAL.md
    for the pinned source, fixture construction and comparison evidence. }
  CRoots: array[0..31] of Integer = (
    11, 0, 8, 4, 0, 11, 7, 8, 9, 5, 1, 0, 8, 4, 5, 6,
    2, 1, 6, 5, 1, 2, 3, 11, 7, 3, 2, 10, 11, 0, 8, 4);
  CModes: array[0..31] of Integer = (
    0, 1, 1, 1, 1, 0, 0, 0, 1, 1, 1, 0, 0, 0, 0, 1,
    1, 0, 1, 0, 0, 0, 1, 1, 1, 1, 0, 0, 0, 1, 1, 1);
var
  LNotes: TNoteGates;
  LTempos: TTempoChanges;
  LSequence: TNoteSequence;
  LReport: TTonalReport;
  LCase: Integer;
  LIndex: Integer;
  LDuration: Integer;
begin
  SetLength(LNotes, 24);
  SetLength(LTempos, 1);
  LTempos[0] := MakeTempoChange(0, 500000);
  for LCase := 0 to 31 do
  begin
    for LIndex := 0 to 23 do
    begin
      LDuration := (1 + (LIndex + LCase) mod 7) * 480;
      LNotes[LIndex] := Default(TNoteGate);
      LNotes[LIndex].StartTick := LIndex * 480;
      LNotes[LIndex].EndTick := LIndex * 480 + LDuration;
      LNotes[LIndex].Pitch := 48 + (LIndex * 7 + LCase * 3) mod 36;
      LNotes[LIndex].Velocity := 1 + (LIndex * 11) mod 127;
    end;
    LSequence := TNoteSequence.Create(480, 31 * 480, LTempos, LNotes);
    try
      LReport := RankDiatonicFits(NotePitchClassWeights(LSequence, 4 * 480));
      Check((LReport.Fits[0].Root = CRoots[LCase]) and
        (Ord(LReport.Fits[0].Mode) = CModes[LCase]),
        'Captured precursor tonal selection ' + IntToStr(LCase));
    finally
      LSequence.Free;
    end;
  end;
  WriteLn('Captured reference selections match across 32 transposed/mixed-duration fixtures');
end;

begin
  try
    CheckProfiles;
    CheckReferenceSelections;
    WriteLn('Tonal weights, scale fits, ambiguity and preservation checks passed');
  except
    on LException: Exception do
    begin
      WriteLn(StdErr, LException.Message);
      Halt(1);
    end;
  end;
end.
