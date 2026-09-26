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
unit pythian.tonal;

{$mode delphi}
{$H+}

interface

uses
  pythian.music,
  pythian.analysis;

const
  TonalProfileVersion = 1;
  DiatonicFitVersion = 1;
  MaximumPitchClassWeight = 1E100;

type
  TPitchClassWeights = array[0..11] of Double;
  TDiatonicMode = (dmMajor, dmNaturalMinor);
  TDiatonicFit = record
    Root: Integer;
    Mode: TDiatonicMode;
    RawScore: Double;
    Score: Double;
    Coverage: Double;
  end;
  TDiatonicFits = array[0..23] of TDiatonicFit;
  TTonalReport = record
    TotalWeight: Double;
    CandidateCount: Integer;
    Fits: TDiatonicFits;
    { Difference between the best two normalized heuristic scores, not a
      confidence probability. Exact ties retain root then mode order. }
    ScoreGap: Double;
  end;

{ Musical tick-duration histogram. Zero cap means uncapped; nonzero caps each
  note separately. Velocity weighting is optional; tempo does not affect ticks.
  Phanes compatibility uses 4 * sequence.TicksPerQuarter and False. }
function NotePitchClassWeights(const ASequence: TNoteSequence;
  const AMaximumNoteTicks: Int64 = 0; const AVelocityWeighted: Boolean = False): TPitchClassWeights;

{ Each measured chroma window contributes only min(hop, remaining source frames)
  of duration weight, avoiding double-counting overlapping window lengths.
  Optional RMS-squared weighting emphasizes loud windows. Uses stored features,
  with no FFT or pitch transcription; validates geometry/chroma/RMS first. }
function FeaturePitchClassWeights(const AFeatures: TAudioFeatures;
  const AOptions: TAnalysisOptions; const ASourceFrames: Integer;
  const AEnergyWeighted: Boolean = False): TPitchClassWeights;

{ Extracted Phanes heuristic: scale-membership weight plus 0.15 tonic and 0.05
  fifth bonuses, ranked across 12 major and 12 natural-minor candidates.
  Score divides RawScore by total weight and may exceed one. Coverage is scale
  membership / total. No evidence yields CandidateCount=0, roots=-1, gap=0.
  This is an inspectable fit ranking, not a verified key or probability. }
function RankDiatonicFits(const AWeights: TPitchClassWeights): TTonalReport;

implementation

uses
  Math,
  pythian.audio;

function NotePitchClassWeights(const ASequence: TNoteSequence;
  const AMaximumNoteTicks: Int64; const AVelocityWeighted: Boolean): TPitchClassWeights;
var
  LGate: TNoteGate;
  LIndex: Integer;
  LDuration: Int64;
  LWeight: Double;
begin
  if (ASequence = nil) or (AMaximumNoteTicks < 0) then
  begin
    raise EAudio.Create('Tonal note profile requires a sequence and nonnegative duration cap');
  end;
  Result := Default(TPitchClassWeights);
  for LIndex := 0 to ASequence.NoteCount - 1 do
  begin
    LGate := ASequence.GateAt(LIndex);
    LDuration := LGate.EndTick - LGate.StartTick;
    if AMaximumNoteTicks > 0 then
    begin
      LDuration := Min(LDuration, AMaximumNoteTicks);
    end;
    LWeight := LDuration;
    if AVelocityWeighted then
    begin
      LWeight := LWeight * LGate.Velocity / 127;
    end;
    Result[LGate.Pitch mod 12] := Result[LGate.Pitch mod 12] + LWeight;
  end;
end;

function FeaturePitchClassWeights(const AFeatures: TAudioFeatures;
  const AOptions: TAnalysisOptions; const ASourceFrames: Integer;
  const AEnergyWeighted: Boolean): TPitchClassWeights;
var
  LCandidate: TPitchClassWeights;
  LFeature: TAudioFeature;
  LExpected: Integer;
  LWork: Int64;
  LIndex: Integer;
  LPitch: Integer;
  LSum: Double;
  LWeight: Double;
begin
  PlanAudioAnalysis(ASourceFrames, 1, AOptions, LExpected, LWork);
  if Length(AFeatures) <> LExpected then
  begin
    raise EAudio.Create('Tonal feature count disagrees with source geometry');
  end;
  LCandidate := Default(TPitchClassWeights);
  for LIndex := 0 to High(AFeatures) do
  begin
    LFeature := AFeatures[LIndex];
    RequireFinite(LFeature.Rms, 'Tonal feature RMS');
    if (LFeature.StartFrame <> Int64(LIndex) * AOptions.HopFrames) or
      (LFeature.ValidFrames <> Min(AOptions.WindowFrames, ASourceFrames - LFeature.StartFrame)) or
      (LFeature.Rms < 0) or (LFeature.Rms > MaxSingle * (1 + 1E-9)) or
      (LFeature.Silent <> (LFeature.Rms <= AOptions.SilenceRms)) then
    begin
      raise EAudio.Create('Tonal feature geometry or RMS is invalid');
    end;
    LSum := 0;
    for LPitch := 0 to 11 do
    begin
      RequireFinite(LFeature.Chroma[LPitch], 'Tonal feature chroma');
      if (LFeature.Chroma[LPitch] < 0) or (LFeature.Chroma[LPitch] > 1) then
      begin
        raise EAudio.Create('Tonal feature chroma is outside normalized bounds');
      end;
      LSum := LSum + LFeature.Chroma[LPitch];
    end;
    if ((LSum <> 0) and (Abs(LSum - 1) > 1E-9)) or
      (LFeature.Silent and (LSum <> 0)) then
    begin
      raise EAudio.Create('Tonal chroma must be normalized or empty, with silent windows empty');
    end;
    LWeight := Min(AOptions.HopFrames, ASourceFrames - LFeature.StartFrame);
    if AEnergyWeighted then
    begin
      LWeight := LWeight * Sqr(LFeature.Rms);
    end;
    for LPitch := 0 to 11 do
    begin
      LCandidate[LPitch] := LCandidate[LPitch] + LFeature.Chroma[LPitch] * LWeight;
    end;
  end;
  Result := LCandidate;
end;

function RankDiatonicFits(const AWeights: TPitchClassWeights): TTonalReport;
const
  CScales: array[TDiatonicMode, 0..6] of Integer =
    ((0, 2, 4, 5, 7, 9, 11), (0, 2, 3, 5, 7, 8, 10));
var
  LReport: TTonalReport;
  LFit: TDiatonicFit;
  LRoot: Integer;
  LMode: TDiatonicMode;
  LDegree: Integer;
  LIndex: Integer;
  LPosition: Integer;
  LCoverage: Double;
begin
  LReport := Default(TTonalReport);
  for LIndex := 0 to 23 do
  begin
    LReport.Fits[LIndex].Root := -1;
  end;
  for LIndex := 0 to 11 do
  begin
    RequireFinite(AWeights[LIndex], 'Pitch-class weight');
    if (AWeights[LIndex] < 0) or (AWeights[LIndex] > MaximumPitchClassWeight) then
    begin
      raise EAudio.Create('Pitch-class weight exceeds nonnegative numeric bounds');
    end;
    LReport.TotalWeight := LReport.TotalWeight + AWeights[LIndex];
  end;
  if LReport.TotalWeight = 0 then
  begin
    Exit(LReport);
  end;
  for LRoot := 0 to 11 do
  begin
    for LMode := Low(TDiatonicMode) to High(TDiatonicMode) do
    begin
      LFit.Root := LRoot;
      LFit.Mode := LMode;
      { Preserve the precursor operation and tie order before normalization. }
      LFit.RawScore := AWeights[LRoot] * 0.15 + AWeights[(LRoot + 7) mod 12] * 0.05;
      LCoverage := 0;
      for LDegree := 0 to 6 do
      begin
        LFit.RawScore := LFit.RawScore + AWeights[(LRoot + CScales[LMode, LDegree]) mod 12];
        LCoverage := LCoverage + AWeights[(LRoot + CScales[LMode, LDegree]) mod 12];
      end;
      LFit.Score := LFit.RawScore / LReport.TotalWeight;
      LFit.Coverage := LCoverage / LReport.TotalWeight;
      LPosition := LReport.CandidateCount;
      while (LPosition > 0) and (LReport.Fits[LPosition - 1].RawScore < LFit.RawScore) do
      begin
        LReport.Fits[LPosition] := LReport.Fits[LPosition - 1];
        Dec(LPosition);
      end;
      LReport.Fits[LPosition] := LFit;
      Inc(LReport.CandidateCount);
    end;
  end;
  LReport.ScoreGap := LReport.Fits[0].Score - LReport.Fits[1].Score;
  Result := LReport;
end;

end.

