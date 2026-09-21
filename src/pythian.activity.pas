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
unit pythian.activity;

{$mode delphi}
{$H+}

interface

uses
  pythian.analysis;

const
  AcousticActivityVersion = 1;

type
  TAcousticAction = (aaSilence, aaOnset, aaSustain);
  TAcousticActions = array of TAcousticAction;
  TOnsetStrengths = array of Double;
  TAcousticSegment = record
    StartFeature: Integer;
    FeatureCount: Integer;
    StartFrame: Integer;
    FrameCount: Integer;
    Action: TAcousticAction;
  end;
  TAcousticSegments = array of TAcousticSegment;
  TAcousticActivity = record
    Actions: TAcousticActions;
    Strengths: TOnsetStrengths;
    Segments: TAcousticSegments;
  end;
  TActivityOptions = record
    MinimumFlux: Double;
    AdaptiveMultiplier: Double;
    HistoryFeatures: Integer;
    PeakRadius: Integer;
    MinimumSeparationFeatures: Integer;
    MaximumSegmentFeatures: Integer;
  end;

function DefaultActivityOptions: TActivityOptions;
procedure ValidateActivityOptions(const AOptions: TActivityOptions);
{ Offline feature-grid onset candidates, not exact transient samples or beats.
  Source coverage is partitioned at candidate onsets, silence changes, and an
  explicit maximum segment length. Original overlapping windows are retained. }
function AnalyzeAcousticActivity(const AFeatures: TAudioFeatures;
  const AAnalysis: TAnalysisOptions; const ASourceFrames: Integer;
  const AOptions: TActivityOptions): TAcousticActivity;

implementation

uses
  Math,
  pythian.audio;

function DefaultActivityOptions: TActivityOptions;
begin
  Result.MinimumFlux := 0.18;
  Result.AdaptiveMultiplier := 1.5;
  Result.HistoryFeatures := 16;
  Result.PeakRadius := 2;
  Result.MinimumSeparationFeatures := 3;
  Result.MaximumSegmentFeatures := 128;
end;

procedure ValidateActivityOptions(const AOptions: TActivityOptions);
begin
  RequireFinite(AOptions.MinimumFlux, 'Minimum onset flux');
  RequireFinite(AOptions.AdaptiveMultiplier, 'Adaptive flux multiplier');
  if (AOptions.MinimumFlux < 0) or (AOptions.MinimumFlux > 1) or
    (AOptions.AdaptiveMultiplier < 0) or (AOptions.AdaptiveMultiplier > 8) or
    (AOptions.HistoryFeatures < 1) or (AOptions.HistoryFeatures > 128) or
    (AOptions.PeakRadius < 1) or (AOptions.PeakRadius > 8) or
    (AOptions.MinimumSeparationFeatures < 1) or
    (AOptions.MinimumSeparationFeatures > 64) or
    (AOptions.MaximumSegmentFeatures < 1) or (AOptions.MaximumSegmentFeatures > 1024) then
  begin
    raise EAudio.Create('Activity options exceed their bounded contract');
  end;
end;

function AnalyzeAcousticActivity(const AFeatures: TAudioFeatures;
  const AAnalysis: TAnalysisOptions; const ASourceFrames: Integer;
  const AOptions: TActivityOptions): TAcousticActivity;
var
  LExpected: Integer;
  LWork: Int64;
  LIndex: Integer;
  LOther: Integer;
  LFirst: Integer;
  LLastOnset: Integer;
  LSegment: Integer;
  LCount: Integer;
  LMean: Double;
  LThreshold: Double;
  LPeak: Boolean;
  LSplit: Boolean;
begin
  Result := Default(TAcousticActivity);
  ValidateActivityOptions(AOptions);
  PlanAudioAnalysis(ASourceFrames, 1, AAnalysis, LExpected, LWork);
  if Length(AFeatures) <> LExpected then
  begin
    raise EAudio.Create('Activity features must cover the complete source grid');
  end;
  for LIndex := 0 to High(AFeatures) do
  begin
    RequireFinite(AFeatures[LIndex].Flux, 'Activity flux');
    RequireFinite(AFeatures[LIndex].Rms, 'Activity RMS');
    if (AFeatures[LIndex].StartFrame <> Int64(LIndex) * AAnalysis.HopFrames) or
      (AFeatures[LIndex].ValidFrames <> Min(AAnalysis.WindowFrames,
        ASourceFrames - AFeatures[LIndex].StartFrame)) or
      (AFeatures[LIndex].Rms < 0) or (AFeatures[LIndex].Flux < 0) or
      (AFeatures[LIndex].Flux > 1.000001) or
      (AFeatures[LIndex].Silent and (AFeatures[LIndex].Flux <> 0)) or
      (AFeatures[LIndex].Silent <> (AFeatures[LIndex].Rms <= AAnalysis.SilenceRms)) then
    begin
      raise EAudio.Create('Activity feature grid, level or flux is invalid');
    end;
  end;
  SetLength(Result.Actions, Length(AFeatures));
  SetLength(Result.Strengths, Length(AFeatures));
  SetLength(Result.Segments, Length(AFeatures));
  LLastOnset := -AOptions.MinimumSeparationFeatures;
  LCount := 0;
  LSegment := -1;
  for LIndex := 0 to High(AFeatures) do
  begin
    Result.Actions[LIndex] := aaSilence;
    if not AFeatures[LIndex].Silent then
    begin
      Result.Actions[LIndex] := aaSustain;
      if (LIndex = 0) or AFeatures[LIndex - 1].Silent then
      begin
        Result.Actions[LIndex] := aaOnset;
        Result.Strengths[LIndex] := Min(1, AFeatures[LIndex].Flux);
      end
      else if LIndex - LLastOnset >= AOptions.MinimumSeparationFeatures then
      begin
        LFirst := Max(0, LIndex - AOptions.HistoryFeatures);
        LMean := 0;
        for LOther := LFirst to LIndex - 1 do
        begin
          LMean := LMean + AFeatures[LOther].Flux;
        end;
        LMean := LMean / (LIndex - LFirst);
        LThreshold := Max(AOptions.MinimumFlux, LMean * AOptions.AdaptiveMultiplier);
        LPeak := (AFeatures[LIndex].Flux > 0) and
          (AFeatures[LIndex].Flux >= LThreshold);
        for LOther := Max(0, LIndex - AOptions.PeakRadius) to
          Min(High(AFeatures), LIndex + AOptions.PeakRadius) do
        begin
          { First point of a flat maximum wins. Silence cannot supply a peak. }
          if (LOther <> LIndex) and not AFeatures[LOther].Silent and
            ((AFeatures[LOther].Flux > AFeatures[LIndex].Flux) or
            ((LOther < LIndex) and (AFeatures[LOther].Flux = AFeatures[LIndex].Flux))) then
          begin
            LPeak := False;
          end;
        end;
        if LPeak then
        begin
          Result.Actions[LIndex] := aaOnset;
          Result.Strengths[LIndex] := Min(1, AFeatures[LIndex].Flux);
        end;
      end;
    end;
    if Result.Actions[LIndex] = aaOnset then
    begin
      LLastOnset := LIndex;
    end;
    LSplit := LIndex = 0;
    if LIndex > 0 then
    begin
      LSplit := (Result.Actions[LIndex] = aaOnset) or
        ((Result.Actions[LIndex] = aaSilence) <> (Result.Actions[LIndex - 1] = aaSilence)) or
        (LIndex - Result.Segments[LSegment].StartFeature >= AOptions.MaximumSegmentFeatures);
    end;
    if LSplit then
    begin
      if LSegment >= 0 then
      begin
        Result.Segments[LSegment].FeatureCount := LIndex -
          Result.Segments[LSegment].StartFeature;
        Result.Segments[LSegment].FrameCount := AFeatures[LIndex].StartFrame -
          Result.Segments[LSegment].StartFrame;
      end;
      LSegment := LCount;
      Inc(LCount);
      Result.Segments[LSegment].StartFeature := LIndex;
      Result.Segments[LSegment].StartFrame := AFeatures[LIndex].StartFrame;
      Result.Segments[LSegment].Action := Result.Actions[LIndex];
    end;
  end;
  if LSegment >= 0 then
  begin
    Result.Segments[LSegment].FeatureCount := Length(AFeatures) -
      Result.Segments[LSegment].StartFeature;
    Result.Segments[LSegment].FrameCount := ASourceFrames -
      Result.Segments[LSegment].StartFrame;
  end;
  SetLength(Result.Segments, LCount);
end;

end.
