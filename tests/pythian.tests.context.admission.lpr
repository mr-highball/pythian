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

program pythian_tests_context_admission;

{$mode delphi}
{$H+}

uses
  SysUtils,
  Math,
  pythian.audio,
  pythian.analysis,
  pythian.onset,
  pythian.tempo,
  pythian.beat,
  pythian.music.context,
  pythian.music.context.admission,
  pythian.music.grid.frames,
  pythian.time,
  pythian.tonal,
  pythian.oscillator,
  pythian.synth,
  pythian.wave;

procedure MakeWaveFixture(const AFileName: String; const AOffsetFrames: Integer = 0);
const
  CPitches: array[0..7] of Integer = (60, 64, 67, 72, 60, 64, 67, 60);
var
  LTones: TFrameTones;
  LClip: TAudioClip;
  LFeatures: TAudioFeatures;
  LOptions: TAnalysisOptions;
  LAdmission: TTonalContextAdmission;
  LIndex: Integer;
begin
  SetLength(LTones, Length(CPitches));
  for LIndex := 0 to High(LTones) do
  begin
    LTones[LIndex].Voice := DefaultSynthVoice;
    LTones[LIndex].Voice.Shape := wsSine;
    LTones[LIndex].Voice.Gain := 0.25;
    LTones[LIndex].Voice.Envelope.AttackSeconds := 0.005;
    LTones[LIndex].Voice.Envelope.ReleaseSeconds := 0.02;
    LTones[LIndex].StartFrame := AOffsetFrames + LIndex * 4000;
    LTones[LIndex].GateFrames := 2800;
    LTones[LIndex].FrequencyHz := MidiFrequency(CPitches[LIndex]);
    LTones[LIndex].Velocity := 0.8;
    LTones[LIndex].Seed := LIndex + 1;
  end;
  LClip := RenderFrameTones(LTones, 8000, AOffsetFrames + 32000);
  try
    LOptions := DefaultAnalysisOptions;
    LFeatures := AnalyzeAudio(LClip, LOptions);
    LAdmission := AdmitTonalContext(FeaturePitchClassWeights(LFeatures, LOptions,
      LClip.FrameCount), MakeKeyContext(0, dmMajor));
    if LAdmission.SelectedRank <> 0 then
    begin
      raise Exception.Create('Controlled C-major phrase must support its declared selection');
    end;
    SaveWavePcm16(AFileName, LClip);
    WriteLn('Controlled C-major WAV written; measured ranking supports explicit selection');
  finally
    LClip.Free;
  end;
end;

procedure Check(const AValue: Boolean; const AMessage: String);
begin
  if not AValue then
  begin
    raise Exception.Create(AMessage);
  end;
end;

procedure LocalKeyChecks(const AFileName: String);
const
  CPitches: array[0..15] of Integer =
    (60, 64, 67, 72, 60, 64, 67, 60, 62, 65, 69, 74, 62, 65, 69, 62);
var
  LTones: TFrameTones;
  LClip: TAudioClip;
  LChanged: TAudioClip;
  LSamples: TAudioSamples;
  LClock: TTempoMap;
  LGrid: TMusicGridFrames;
  LRegions: TTonalKeyRegions;
  LMeasured: TTonalRegionAdmissions;
  LOther: TTonalRegionAdmissions;
  LOptions: TAnalysisOptions;
  LIndex: Integer;
  LRejected: Boolean;
begin
  SetLength(LTones, Length(CPitches));
  for LIndex := 0 to High(LTones) do
  begin
    LTones[LIndex].Voice := DefaultSynthVoice;
    LTones[LIndex].Voice.Shape := wsSine;
    LTones[LIndex].Voice.Gain := 0.25;
    LTones[LIndex].Voice.Envelope.AttackSeconds := 0.005;
    LTones[LIndex].Voice.Envelope.ReleaseSeconds := 0.02;
    LTones[LIndex].StartFrame := LIndex * 4000;
    LTones[LIndex].GateFrames := 2800;
    LTones[LIndex].FrequencyHz := MidiFrequency(CPitches[LIndex]);
    LTones[LIndex].Velocity := 0.8;
    LTones[LIndex].Seed := LIndex + 1;
  end;
  LClip := RenderFrameTones(LTones, 8000, 64000);
  LChanged := nil;
  LClock := nil;
  LGrid := nil;
  try
    LClock := TTempoMap.Create(480, 7680, [MakeTempoChange(0, 500000)]);
    LGrid := TMusicGridFrames.Create(LClock, 8000, LClip.FrameCount, 0, 0, 240, 32);
    SetLength(LRegions, 2);
    LRegions[0].FirstCell := 0;
    LRegions[0].CellCount := 16;
    LRegions[0].Key := MakeKeyContext(0, dmMajor);
    LRegions[1].FirstCell := 16;
    LRegions[1].CellCount := 16;
    LRegions[1].Key := MakeKeyContext(2, dmNaturalMinor);
    LOptions := DefaultAnalysisOptions;
    LMeasured := AdmitWaveKeyRegions(LClip, LGrid, LRegions, LOptions);
    Check((LMeasured[0].Tonal.SelectedRank = 0) and
      (LMeasured[1].Tonal.SelectedRank = 0), 'Separate controlled phrases support their selected local keys');
    Check((LMeasured[0].StartFrame = 0) and (LMeasured[0].EndFrame = 32000) and
      (LMeasured[1].StartFrame = 32000) and (LMeasured[1].EndFrame = 64000),
      'Local tonal evidence retains exact nonoverlapping source ranges');
    LSamples := LClip.CopySamples;
    for LIndex := 32000 * LClip.Channels to High(LSamples) do
    begin
      LSamples[LIndex] := 0;
    end;
    LChanged := TAudioClip.Create(8000, LClip.Channels, LSamples);
    LRegions[1].Key := MakeKeyContext(-1, dmMajor);
    LOther := AdmitWaveKeyRegions(LChanged, LGrid, LRegions, LOptions);
    Check((LOther[1].Tonal.Report.CandidateCount = 0) and
      (LOther[1].Tonal.SelectedRank = -1), 'Silent local region remains explicitly unknown');
    for LIndex := 0 to 11 do
    begin
      Check(LOther[0].Weights[LIndex] = LMeasured[0].Weights[LIndex],
        'Neighboring-region replacement cannot alter earlier tonal weights');
    end;
    Check(LMeasured[1].Region.Key.Root = 2, 'Returned region evidence owns its selected keys');
    LRegions[1].Key := MakeKeyContext(2, dmNaturalMinor);
    LRejected := False;
    try
      LOther := AdmitWaveKeyRegions(LChanged, LGrid, LRegions, LOptions);
    except
      on EAudio do
      begin
        LRejected := True;
      end;
    end;
    Check(LRejected and (LOther[1].Tonal.SelectedRank = -1),
      'Known key without local evidence rejects and preserves prior result');
    LRegions[1].FirstCell := 17;
    LRejected := False;
    try
      LOther := AdmitWaveKeyRegions(LClip, LGrid, LRegions, LOptions);
    except
      on EAudio do
      begin
        LRejected := True;
      end;
    end;
    Check(LRejected, 'A gap in selected regions cannot silently acquire a key');
    LRegions[1].FirstCell := 16;
    LOptions.HopFrames := 2;
    LRejected := False;
    try
      LOther := AdmitWaveKeyRegions(LClip, LGrid, LRegions, LOptions);
    except
      on LException: EAudio do
      begin
        LRejected := Pos('aggregate', LException.Message) > 0;
      end;
    end;
    Check(LRejected, 'Individually valid region work cannot exceed the aggregate budget');
    LOptions := DefaultAnalysisOptions;
    LGrid.Free;
    LGrid := nil;
    LClock.Free;
    LClock := nil;
    LClock := TTempoMap.Create(96, 768,
      [MakeTempoChange(0, 500000), MakeTempoChange(384, 750000)]);
    LGrid := TMusicGridFrames.Create(LClock, 8000, LClip.FrameCount, 1000, 96, 96, 7);
    LRegions[0].CellCount := 3;
    LRegions[0].Key := MakeKeyContext(-1, dmMajor);
    LRegions[1].FirstCell := 3;
    LRegions[1].CellCount := 4;
    LRegions[1].Key := MakeKeyContext(-1, dmMajor);
    LOther := AdmitWaveKeyRegions(LClip, LGrid, LRegions, LOptions);
    Check((LOther[0].StartFrame = 5000) and (LOther[0].EndFrame = 17000) and
      (LOther[1].StartFrame = 17000) and (LOther[1].EndFrame = 41000),
      'Local key regions honor source offsets, nonzero start, native PPQ and changing tempo');
    if AFileName <> '' then
    begin
      SaveWavePcm16(AFileName, LClip);
    end;
    WriteLn('Local tonal regions: independent measured keys, source ranges, unknowns and recovery pass');
  finally
    LGrid.Free;
    LClock.Free;
    LChanged.Free;
    LClip.Free;
  end;
end;

procedure Run;
var
  LWeights: TPitchClassWeights;
  LAdmission: TTonalContextAdmission;
  LScope: TWaveContextScope;
  LCopy: TWaveContextScope;
  LKey: TKeyContext;
  LRejected: Boolean;
begin
  LWeights := Default(TPitchClassWeights);
  LWeights[0] := 10;
  LWeights[2] := 2;
  LWeights[4] := 4;
  LWeights[5] := 1;
  LWeights[7] := 5;
  LWeights[9] := 1;
  LWeights[11] := 1;
  LKey := MakeKeyContext(0, dmMajor);
  LAdmission := AdmitTonalContext(LWeights, LKey);
  Check((LAdmission.SelectedRank = 0) and (LAdmission.Report.CandidateCount = 24) and
    SameKeyContext(LAdmission.Key, LKey), 'Explicit selected key retains full ranking');
  LAdmission := AdmitTonalContext(LWeights, MakeKeyContext(2, dmNaturalMinor));
  Check((LAdmission.SelectedRank > 0) and (LAdmission.Key.Root = 2),
    'Caller selection is not silently replaced by highest-ranked candidate');
  LAdmission := AdmitTonalContext(LWeights, MakeKeyContext(-1, dmMajor));
  Check((LAdmission.Key.Root = -1) and (LAdmission.SelectedRank = -1) and
    (LAdmission.Report.CandidateCount = 24), 'Unknown survives despite measured evidence');
  LWeights := Default(TPitchClassWeights);
  LAdmission := AdmitTonalContext(LWeights, MakeKeyContext(-1, dmMajor));
  Check(LAdmission.Report.CandidateCount = 0, 'Silence can retain unknown key');
  LRejected := False;
  try
    LAdmission := AdmitTonalContext(LWeights, LKey);
  except
    on EAudio do
    begin
      LRejected := True;
    end;
  end;
  Check(LRejected and (LAdmission.Key.Root = -1), 'Empty evidence cannot publish a measured key');

  { Four quarter-half cells end at exactly 1000.002 frames. Flooring the end
    would incorrectly include the fourth cell in a 1000-frame source. }
  LScope := WaveContextScope(1000, 1000, 500001, 480, 240, LKey);
  Check((Length(LScope.Grid.Keys) = 3) and (LScope.EndFrameFloor = 750) and
    (LScope.EndFrameCeiling = 751) and (LScope.UnassignedWholeFrames = 249),
    'Exact fractional clock excludes partial final cell');
  LScope := WaveContextScope(1000, 1001, 500001, 480, 240, LKey);
  Check((Length(LScope.Grid.Keys) = 4) and (LScope.EndFrameFloor = 1000) and
    (LScope.EndFrameCeiling = 1001) and (LScope.UnassignedWholeFrames = 0),
    'Ceiling boundary admits exactly fitting fractional end');
  Check((LScope.Grid.StartTick = 0) and (LScope.Grid.Tempos[3] = 500001) and
    SameKeyContext(LScope.Grid.Keys[3], LKey), 'Explicit clock and key fill admitted scope');
  LCopy := LScope;
  LRejected := False;
  try
    LScope := WaveContextScope(1000, 1001, 500001, 480, 0, LKey);
  except
    on EAudio do
    begin
      LRejected := True;
    end;
  end;
  Check(LRejected and (Length(LScope.Grid.Keys) = Length(LCopy.Grid.Keys)) and
    (LScope.EndFrameCeiling = LCopy.EndFrameCeiling), 'Invalid scope preserves prior assignment');
  LRejected := False;
  try
    LScope := WaveContextScope(1000, 1, 500001, 480, 240, LKey);
  except
    on EAudio do
    begin
      LRejected := True;
    end;
  end;
  Check(LRejected, 'No complete cell rejects');
  LRejected := False;
  try
    LScope := WaveContextScope(1000, 1000, 1, 480, 1, LKey);
  except
    on EAudio do
    begin
      LRejected := True;
    end;
  end;
  Check(LRejected, 'Cell budget rejects instead of truncating');
  LRejected := False;
  try
    LScope := WaveContextScope(1, MaximumClipSamples, 1, High(Integer), 1, LKey);
  except
    on EAudio do
    begin
      LRejected := True;
    end;
  end;
  Check(LRejected, 'Large declared clock rejects without arithmetic overflow');
  WriteLn('Explicit tonal admission, unknown preservation and exact WAV scope checks pass');
end;

procedure PhaseChecks;
var
  LCandidate: TBeatGridCandidate;
  LAdmission: TBeatContextAdmission;
  LKey: TKeyContext;
  LRejected: Boolean;
  LIndex: Integer;
begin
  LKey := MakeKeyContext(-1, dmMajor);
  LCandidate := Default(TBeatGridCandidate);
  LCandidate.PeriodFrames := 500;
  LCandidate.PhaseFrame := 125.25;
  LAdmission := AdmitBeatContext(LCandidate, 1000, 2125, 480, 240, LKey);
  Check((LAdmission.Scope.Grid.StartTick = 120) and
    (LAdmission.Scope.StartFrameFloor = 125) and
    (LAdmission.Scope.StartFrameCeiling = 125) and
    (LAdmission.Scope.EndFrameCeiling = 2125) and
    (Length(LAdmission.Scope.Grid.Keys) = 8) and
    (LAdmission.PhaseErrorFrames = -0.25) and (LAdmission.PeriodErrorFrames = 0),
    'Selected pulse phase retains exact PPQ scope and explicit quantization error');
  for LIndex := 0 to 3 do
  begin
    LCandidate.PeriodFrames := 500;
    LCandidate.PhaseFrame := 125;
    case LIndex of
      0: LCandidate.PhaseFrame := -1;
      1: LCandidate.PhaseFrame := 500;
      2: LCandidate.PeriodFrames := MaxDouble;
      3: LCandidate.PeriodFrames := 0;
    end;
    LRejected := False;
    try
      LAdmission := AdmitBeatContext(LCandidate, 1000, 2125, 480, 240, LKey);
    except
      on EAudio do
      begin
        LRejected := True;
      end;
    end;
    Check(LRejected and (LAdmission.Scope.Grid.StartTick = 120),
      'Invalid beat admission rejects without overflow or replacing accepted context');
  end;
end;

procedure TempoChecks;
var
  LFeatures: TAudioFeatures;
  LAnalysis: TAnalysisOptions;
  LOptions: TTempoOptions;
  LReport: TTempoReport;
  LIndex: Integer;
  LFound120: Boolean;
  LFound60: Boolean;
  LRejected: Boolean;
begin
  LAnalysis := DefaultAnalysisOptions;
  LAnalysis.WindowFrames := 64;
  LAnalysis.HopFrames := 10;
  LOptions := DefaultTempoOptions;
  SetLength(LFeatures, 1600);
  for LIndex := 0 to High(LFeatures) do
  begin
    LFeatures[LIndex].StartFrame := LIndex * 10;
    LFeatures[LIndex].ValidFrames := Min(64, 16000 - LIndex * 10);
    if (LIndex > 0) and (LIndex mod 50 = 0) then
    begin
      LFeatures[LIndex].Flux := 1;
    end;
  end;
  LReport := RankTempoCandidates(LFeatures, LAnalysis, 1000, 16000, LOptions);
  LFound120 := False;
  LFound60 := False;
  for LIndex := 0 to High(LReport.Candidates) do
  begin
    if Abs(LReport.Candidates[LIndex].Bpm - 120) < 0.1 then
    begin
      LFound120 := True;
      Check(Abs(LReport.Candidates[LIndex].MicrosecondsPerQuarter - 500000) < 400,
        'Known 500-frame pulse gives an independently known half-second clock');
    end;
    LFound60 := LFound60 or (Abs(LReport.Candidates[LIndex].Bpm - 60) < 0.1);
  end;
  Check((LReport.Status = tsCandidates) and LFound120 and LFound60,
    'Exact pulse and slower metrical alternative retained without automatic folding');
  LFeatures[2].Flux := NaN;
  LRejected := False;
  try
    LReport := RankTempoCandidates(LFeatures, LAnalysis, 1000, 16000, LOptions);
  except
    on EAudio do
    begin
      LRejected := True;
    end;
  end;
  Check(LRejected and (LReport.Status = tsCandidates), 'Nonfinite flux preserves accepted result');
  for LIndex := 0 to High(LFeatures) do
  begin
    LFeatures[LIndex].Flux := 0;
    LFeatures[LIndex].Silent := True;
  end;
  LReport := RankTempoCandidates(LFeatures, LAnalysis, 1000, 16000, LOptions);
  Check((LReport.Status = tsInsufficientActivity) and (Length(LReport.Candidates) = 0),
    'Silence produces no tempo candidate');
  LFeatures[100].Flux := 1;
  LFeatures[100].Silent := False;
  LReport := RankTempoCandidates(LFeatures, LAnalysis, 1000, 16000, LOptions);
  Check(Length(LReport.Candidates) = 0, 'One onset is not periodic tempo evidence');
  LFeatures[0].StartFrame := 1;
  LRejected := False;
  try
    LReport := RankTempoCandidates(LFeatures, LAnalysis, 1000, 16000, LOptions);
  except
    on EAudio do
    begin
      LRejected := True;
    end;
  end;
  Check(LRejected, 'Shifted source geometry rejects');
  LFeatures[0].StartFrame := 0;
  for LIndex := 0 to High(LFeatures) do
  begin
    LFeatures[LIndex].Flux := 0.2;
    LFeatures[LIndex].Silent := False;
  end;
  LReport := RankTempoCandidates(LFeatures, LAnalysis, 1000, 16000, LOptions);
  Check(Length(LReport.Candidates) = 0,
    'Constant onset strength supplies no repeating pulse after background removal');
  SetLength(LFeatures, 20);
  for LIndex := 0 to High(LFeatures) do
  begin
    LFeatures[LIndex].ValidFrames := Min(64, 200 - LIndex * 10);
  end;
  LReport := RankTempoCandidates(LFeatures, LAnalysis, 1000, 200, LOptions);
  Check(LReport.Status = tsInsufficientDuration, 'Short excerpts cannot support enough pulse cycles');
  SetLength(LFeatures, 64000);
  LAnalysis.HopFrames := 1;
  for LIndex := 0 to High(LFeatures) do
  begin
    LFeatures[LIndex].StartFrame := LIndex;
    LFeatures[LIndex].ValidFrames := Min(64, 64000 - LIndex);
  end;
  LRejected := False;
  try
    LReport := RankTempoCandidates(LFeatures, LAnalysis, 8000, 64000, LOptions);
  except
    on EAudio do
    begin
      LRejected := True;
    end;
  end;
  Check(LRejected and (LReport.Status = tsInsufficientDuration),
    'Excess correlation work rejects before allocation and preserves prior report');
  WriteLn('Known pulse, metrical alternatives, absent evidence and tempo input checks pass');
end;

procedure CheckTempoWave(const AFileName: String; const AExpectedBpm: Double);
var
  LClip: TAudioClip;
  LAnalysis: TAnalysisOptions;
  LFeatures: TAudioFeatures;
  LReport: TTempoReport;
  LIndex: Integer;
  LBestError: Double;
begin
  LClip := LoadWave(AFileName);
  try
    LAnalysis := DefaultOnsetAnalysisOptions(LClip.SampleRate);
    LFeatures := AnalyzeAudio(LClip, LAnalysis);
    LReport := RankTempoCandidates(LFeatures, LAnalysis, LClip.SampleRate,
      LClip.FrameCount, DefaultTempoOptions);
    LBestError := MaxDouble;
    for LIndex := 0 to High(LReport.Candidates) do
    begin
      WriteLn('Tempo rank ', LIndex, ': ', LReport.Candidates[LIndex].Bpm:0:4,
        ' BPM; correlation ', LReport.Candidates[LIndex].Correlation:0:4);
      LBestError := Min(LBestError, Abs(LReport.Candidates[LIndex].Bpm - AExpectedBpm));
    end;
    Check(LBestError / AExpectedBpm <= 0.02,
      'Measured candidate must match the independent source tempo within two percent');
    WriteLn('Independent source tempo appears among measured candidates; musical pulse level remains explicit');
  finally
    LClip.Free;
  end;
end;

begin
  try
    Run;
    PhaseChecks;
    TempoChecks;
    if (ParamCount = 2) and (ParamStr(1) = 'local-keys') then
    begin
      LocalKeyChecks(ParamStr(2));
    end
    else
    begin
      LocalKeyChecks('');
    end;
    if ParamCount = 1 then
    begin
      MakeWaveFixture(ParamStr(1));
    end;
    if (ParamCount = 3) and (ParamStr(1) = 'shifted') then
    begin
      MakeWaveFixture(ParamStr(2), StrToInt(ParamStr(3)));
    end;
    if (ParamCount = 3) and (ParamStr(1) = 'tempo') then
    begin
      CheckTempoWave(ParamStr(2), StrToFloat(ParamStr(3)));
    end;
  except
    on LException: Exception do
    begin
      WriteLn(StdErr, LException.ClassName, ': ', LException.Message);
      Halt(1);
    end;
  end;
end.
