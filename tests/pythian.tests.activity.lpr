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
program pythian_tests_activity;

{$mode delphi}
{$H+}

uses
  SysUtils,
  Math,
  pythian.audio,
  pythian.wave,
  pythian.hash,
  pythian.analysis,
  pythian.activity,
  pythian.learning,
  pythian.corpus,
  pythian.granular,
  pythian.continuity;

procedure Check(const AValue: Boolean; const AMessage: String);
begin
  if not AValue then
  begin
    raise Exception.Create(AMessage);
  end;
end;

procedure CheckActivity;
var
  LFeatures: TAudioFeatures;
  LAnalysis: TAnalysisOptions;
  LOptions: TActivityOptions;
  LActivity: TAcousticActivity;
  LSamples: TAudioSamples;
  LClip: TAudioClip;
  LIndex: Integer;
  LEnd: Integer;
  LOnsets: Integer;
  LRejected: Boolean;
begin
  LAnalysis := DefaultAnalysisOptions;
  LAnalysis.WindowFrames := 64;
  LAnalysis.HopFrames := 32;
  LOptions := DefaultActivityOptions;
  LOptions.PeakRadius := 1;
  LOptions.MinimumSeparationFeatures := 2;
  LOptions.HistoryFeatures := 2;
  LOptions.AdaptiveMultiplier := 1;
  LOptions.MaximumSegmentFeatures := 2;
  SetLength(LFeatures, 12);
  for LIndex := 0 to High(LFeatures) do
  begin
    LFeatures[LIndex].StartFrame := LIndex * 32;
    LFeatures[LIndex].ValidFrames := Min(64, 384 - LIndex * 32);
    LFeatures[LIndex].Rms := 1;
    LFeatures[LIndex].Flux := 0.01;
  end;
  for LIndex := 0 to 1 do
  begin
    LFeatures[LIndex].Silent := True;
    LFeatures[LIndex].Rms := 0;
    LFeatures[LIndex].Flux := 0;
  end;
  LFeatures[2].Flux := 0.8;
  LFeatures[3].Flux := 0.05;
  LFeatures[4].Flux := 0.6;
  LFeatures[5].Flux := 0.6;
  LFeatures[7].Silent := True;
  LFeatures[7].Rms := 0;
  LFeatures[7].Flux := 0;
  LFeatures[10].Flux := 0.9;
  LActivity := AnalyzeAcousticActivity(LFeatures, LAnalysis, 384, LOptions);
  Check((LActivity.Actions[2] = aaOnset) and (LActivity.Actions[4] = aaOnset) and
    (LActivity.Actions[5] = aaSustain) and (LActivity.Actions[8] = aaOnset) and
    (LActivity.Actions[10] = aaOnset), 'Peak, plateau, refractory and silence-resume policy');
  Check((Length(LActivity.Segments) = 7) and
    (LActivity.Segments[3].Action = aaSustain), 'Maximum segment split is not a false onset');
  LEnd := 0;
  for LIndex := 0 to High(LActivity.Segments) do
  begin
    Check(LActivity.Segments[LIndex].StartFrame = LEnd, 'Segment coverage has no gaps');
    Inc(LEnd, LActivity.Segments[LIndex].FrameCount);
  end;
  Check(LEnd = 384, 'Segment partition covers the exact source extent');
  Inc(LFeatures[5].StartFrame);
  LRejected := False;
  try
    AnalyzeAcousticActivity(LFeatures, LAnalysis, 384, LOptions);
  except
    on EAudio do
    begin
      LRejected := True;
    end;
  end;
  Check(LRejected, 'Irregular activity grids reject');

  SetLength(LSamples, 1024);
  LSamples[256 * 2] := 1;
  LSamples[256 * 2 + 1] := -1;
  LClip := TAudioClip.Create(8192, 2, LSamples);
  try
    LFeatures := AnalyzeAudio(LClip, LAnalysis);
    LActivity := AnalyzeAcousticActivity(LFeatures, LAnalysis, LClip.FrameCount,
      DefaultActivityOptions);
    LOnsets := 0;
    for LIndex := 0 to High(LActivity.Actions) do
    begin
      if LActivity.Actions[LIndex] = aaOnset then
      begin
        Inc(LOnsets);
        Check((LFeatures[LIndex].StartFrame <= 256) and
          (LFeatures[LIndex].StartFrame + LFeatures[LIndex].ValidFrames > 256),
          'Anti-phase stereo impulse lies inside the reported onset window');
      end;
    end;
    Check(LOnsets = 1, 'Isolated impulse has one onset candidate');
  finally
    LClip.Free;
  end;
end;

procedure CheckContinuity;
var
  LSources: TAudioSources;
  LRecords: TAcousticRecordings;
  LSamples: TAudioSamples;
  LCenters: TAcousticVectors;
  LCorpus: TAcousticCorpusData;
  LAnalysis: TAnalysisOptions;
  LOptions: TContinuityOptions;
  LPlanner: TCorpusGrainPlanner;
  LTokens: TAcousticIndices;
  LGrains: TAudioGrains;
  LReplay: TAudioGrains;
  LReport: TContinuityReport;
  LBaseline: TContinuityReport;
  LSource: Integer;
  LIndex: Integer;
  LRejected: Boolean;
begin
  SetLength(LSources, 2);
  SetLength(LRecords, 2);
  SetLength(LSamples, 256);
  LAnalysis := DefaultAnalysisOptions;
  LAnalysis.WindowFrames := 64;
  LAnalysis.HopFrames := 32;
  try
    for LSource := 0 to 1 do
    begin
      for LIndex := 0 to High(LSamples) do
      begin
        LSamples[LIndex] := 0.5 - LSource;
      end;
      LSources[LSource] := TAudioClip.Create(8192, 1, LSamples);
      LRecords[LSource].Info.Name := 'constant.wav';
      LRecords[LSource].Info.Provenance := 'Analytic constant-signal measurement fixture';
      LRecords[LSource].Info.Sha256 := Sha256Bytes(EncodeWavePcm16(LSources[LSource]));
      LRecords[LSource].Info.SampleRate := 8192;
      LRecords[LSource].Info.Channels := 1;
      LRecords[LSource].Info.FrameCount := 256;
      SetLength(LRecords[LSource].Features, 8);
      SetLength(LRecords[LSource].Tokens, 8);
      for LIndex := 0 to 7 do
      begin
        LRecords[LSource].Features[LIndex].StartFrame := LIndex * 32;
        LRecords[LSource].Features[LIndex].ValidFrames := Min(64, 256 - LIndex * 32);
        LRecords[LSource].Features[LIndex].Rms := 0.5;
        LRecords[LSource].Features[LIndex].Peak := 0.5;
      end;
    end;
    SetLength(LCenters, 1);
    LCenters[0] := AcousticVector(LRecords[0].Features[0]);
    LCorpus := TAcousticCorpusData.Create(LAnalysis, LCenters, LRecords);
    try
      LOptions := DefaultContinuityOptions;
      LOptions.CandidatesPerToken := 1;
      LOptions.BeamWidth := 1;
      LPlanner := TCorpusGrainPlanner.Create(LCorpus, LSources, LOptions);
      try
        SetLength(LTokens, 6);
        LGrains := LCorpus.PlanGrains(LTokens);
        LBaseline := LPlanner.Evaluate(LTokens, LGrains);
        Check(LBaseline.SourceJumps = 5, 'Nearest exemplar repeats one source window');
        LGrains := LPlanner.Plan(LTokens, LReport);
        Check((LReport.SourceJumps = 0) and (LReport.ContiguousLinks = 5) and
          (LReport.TotalCost = 0) and (LReport.MeanSeamError = 0),
          'Dynamic successors extend beyond static candidate count with zero-cost continuity');
        for LIndex := 0 to High(LGrains) do
        begin
          Check((LGrains[LIndex].SourceIndex = 0) and
            (LGrains[LIndex].SourceStartFrame = LIndex * 32),
            'Tie order and exact forward source coordinates');
        end;
        LReplay := LPlanner.Plan(LTokens, LReport);
        for LIndex := 0 to High(LGrains) do
        begin
          Check(LReplay[LIndex].SourceStartFrame = LGrains[LIndex].SourceStartFrame,
            'Planner replay preserves coordinates');
        end;
        SetLength(LTokens, 2);
        LGrains := LCorpus.PlanGrains(LTokens);
        LGrains[1].SourceIndex := 1;
        LReport := LPlanner.Evaluate(LTokens, LGrains);
        Check((Abs(LReport.MeanSeamError - 2) < 1E-12) and
          (LReport.SourceSwitches = 1), 'Independent opposite-constant normalized seam error');
        LTokens[1] := 1;
        LRejected := False;
        try
          LReplay := LPlanner.Plan(LTokens, LReport);
        except
          on EAudio do
          begin
            LRejected := True;
          end;
        end;
        Check(LRejected and (LReport.GrainCount = 0), 'Unknown token is never substituted');
        Check(Length(LReplay) = 6, 'Failed plan assignment retains caller result');
        SetLength(LTokens, MaximumContinuityGrains + 1);
        LRejected := False;
        try
          LReplay := LPlanner.Plan(LTokens, LReport);
        except
          on EAudio do
          begin
            LRejected := True;
          end;
        end;
        Check(LRejected, 'Oversized planning request rejects before search');
      finally
        LPlanner.Free;
      end;
    finally
      LCorpus.Free;
    end;
  finally
    for LSource := 0 to High(LSources) do
    begin
      LSources[LSource].Free;
    end;
  end;
end;

begin
  try
    CheckActivity;
    CheckContinuity;
    WriteLn('Acoustic activity, segmentation and continuity checks passed');
  except
    on LException: Exception do
    begin
      WriteLn(StdErr, LException.Message);
      Halt(1);
    end;
  end;
end.
