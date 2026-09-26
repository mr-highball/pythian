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
program pythian_beat_candidates;

{$mode delphi}
{$H+}

uses
  SysUtils, Classes, Math, fpjson, jsonparser,
  pythian.audio, pythian.beat, pythian.beat.track,
  pythian.analysis, pythian.activity, pythian.onset,
  pythian.onset.events, pythian.evaluation,
  pythian.tools.files;

type
  TBooleans = array of Boolean;
  TMatchScore = TEventEvaluation;

procedure Require(const ACondition: Boolean; const AMessage: String);
begin
  if not ACondition then
  begin
    raise EAudio.Create(AMessage);
  end;
end;

function ObjectField(const AObject: TJSONObject; const AName: String): TJSONObject;
var
  LValue: TJSONData;
begin
  LValue := AObject.Find(AName);
  Require((LValue <> nil) and (LValue.JSONType = jtObject),
    'Missing candidate report object: ' + AName);
  Result := TJSONObject(LValue);
end;

function ArrayField(const AObject: TJSONObject; const AName: String): TJSONArray;
var
  LValue: TJSONData;
begin
  LValue := AObject.Find(AName);
  Require((LValue <> nil) and (LValue.JSONType = jtArray),
    'Missing candidate report array: ' + AName);
  Result := TJSONArray(LValue);
end;

function NumberField(const AObject: TJSONObject; const AName: String): Double;
var
  LValue: TJSONData;
begin
  LValue := AObject.Find(AName);
  Require((LValue <> nil) and (LValue.JSONType = jtNumber),
    'Missing candidate report number: ' + AName);
  Result := LValue.AsFloat;
  Require(not IsNan(Result) and not IsInfinite(Result),
    'Nonfinite candidate report number: ' + AName);
end;

function IntegerField(const AObject: TJSONObject; const AName: String): Integer;
var
  LValue: TJSONData;
begin
  LValue := AObject.Find(AName);
  Require((LValue <> nil) and (LValue.JSONType = jtNumber) and
    TryStrToInt(LValue.AsJSON, Result),
    'Missing or inexact candidate report integer: ' + AName);
end;

function StringField(const AObject: TJSONObject; const AName: String): String;
var
  LValue: TJSONData;
begin
  LValue := AObject.Find(AName);
  Require((LValue <> nil) and (LValue.JSONType = jtString),
    'Missing candidate report text: ' + AName);
  Result := LValue.AsString;
end;

function BooleanField(const AObject: TJSONObject; const AName: String): Boolean;
var
  LValue: TJSONData;
begin
  LValue := AObject.Find(AName);
  Require((LValue <> nil) and (LValue.JSONType = jtBoolean),
    'Missing candidate report Boolean: ' + AName);
  Result := LValue.AsBoolean;
end;

function Near(const ALeft, ARight: Double): Boolean;
begin
  Result := Abs(ALeft - ARight) < 1E-9;
end;

function BytesText(const ABytes: TAudioBytes): String;
begin
  SetLength(Result, Length(ABytes));
  if Length(ABytes) > 0 then
  begin
    Move(ABytes[0], Result[1], Length(ABytes));
  end;
end;

function LoadReport(const APath: String): TJSONObject;
var
  LData: TJSONData;
begin
  LData := GetJSON(BytesText(ReadFileBytes(APath, 8 * 1024 * 1024)));
  if LData.JSONType <> jtObject then
  begin
    LData.Free;
    raise EAudio.Create('Candidate report root must be an object');
  end;
  Result := TJSONObject(LData);
end;

function LoadReference(const APath: String; const ASampleRate,
  ASourceFrames: Integer): TBeatFrames;
var
  LLines: TStringList;
  LFormat: TFormatSettings;
  LSeconds: Double;
  LIndex: Integer;
begin
  Result := nil;
  LLines := TStringList.Create;
  try
    LLines.Text := BytesText(ReadFileBytes(APath, 65536));
    Require((LLines.Count >= 2) and (LLines.Count <= 1024),
      'Candidate reference count exceeds bounds');
    SetLength(Result, LLines.Count);
    LFormat := DefaultFormatSettings;
    LFormat.DecimalSeparator := '.';
    for LIndex := 0 to LLines.Count - 1 do
    begin
      LSeconds := StrToFloat(Trim(LLines[LIndex]), LFormat);
      Require(not IsNan(LSeconds) and not IsInfinite(LSeconds) and
        (LSeconds >= 0) and (LSeconds * ASampleRate < ASourceFrames),
        'Invalid candidate reference time');
      Result[LIndex] := Floor(LSeconds * ASampleRate + 0.5);
      if LIndex > 0 then
      begin
        Require(Result[LIndex] > Result[LIndex - 1],
          'Candidate reference times must increase');
      end;
    end;
  finally
    LLines.Free;
  end;
end;

function EvaluationFrames(const AFrames: TBeatFrames): TEvaluationFrames;
var
  LIndex: Integer;
begin
  Result := nil;
  SetLength(Result, Length(AFrames));
  for LIndex := 0 to High(AFrames) do
  begin
    Result[LIndex] := AFrames[LIndex];
  end;
end;

function MatchScore(const AReference, APrediction: TBeatFrames;
  const AFirstFrame, AEndFrame, AToleranceFrames: Integer): TMatchScore;
begin
  Result := EvaluateEvents(EvaluationFrames(AReference),
    EvaluationFrames(APrediction), AFirstFrame, AEndFrame,
    AToleranceFrames);
end;

function ScoreJson(const AScore: TMatchScore): TJSONObject;
begin
  Result := TJSONObject.Create;
  Result.Add('reference_count', AScore.ReferenceCount);
  Result.Add('prediction_count', AScore.PredictionCount);
  Result.Add('matches', AScore.Matches);
  Result.Add('extras', AScore.PredictionCount - AScore.Matches);
  Result.Add('misses', AScore.ReferenceCount - AScore.Matches);
  Result.Add('precision', AScore.Precision);
  Result.Add('recall', AScore.Recall);
  Result.Add('f1', AScore.F1);
end;

function Better(const ALeft, ARight: TMatchScore): Boolean;
begin
  Result := (ALeft.F1 > ARight.F1 + 1E-12) or
    ((Abs(ALeft.F1 - ARight.F1) <= 1E-12) and
      ((ALeft.Recall > ARight.Recall + 1E-12) or
       ((Abs(ALeft.Recall - ARight.Recall) <= 1E-12) and
         (ALeft.Precision > ARight.Precision + 1E-12))));
end;

function BetterRecall(const ALeft, ARight: TMatchScore): Boolean;
begin
  Result := (ALeft.Recall > ARight.Recall + 1E-12) or
    ((Abs(ALeft.Recall - ARight.Recall) <= 1E-12) and
      (ALeft.Precision > ARight.Precision + 1E-12));
end;

function OwnedReference(const AAll: TBeatFrames;
  const AStartFrame, AEndFrame: Integer): TBeatFrames;
var
  LIndex: Integer;
  LCount: Integer;
begin
  Result := nil;
  SetLength(Result, Length(AAll));
  LCount := 0;
  for LIndex := 0 to High(AAll) do
  begin
    if (AAll[LIndex] >= AStartFrame) and (AAll[LIndex] < AEndFrame) then
    begin
      Result[LCount] := AAll[LIndex];
      Inc(LCount);
    end;
  end;
  SetLength(Result, LCount);
end;

function GridFramesInWindow(const AWindow: TBeatTrackWindow;
  const ACandidate: TBeatGridCandidate;
  const AToleranceFrames: Integer): TBeatFrames;
var
  LStart: Integer;
  LEnd: Integer;
begin
  LStart := Max(AWindow.OwnerStartFrame,
    AWindow.Analysis.FirstObservationFrame - AToleranceFrames);
  LEnd := Min(AWindow.OwnerEndFrame,
    AWindow.Analysis.LastObservationFrame + AToleranceFrames + 1);
  Result := nil;
  if LStart < LEnd then
  begin
    Result := BeatGridFrames(ACandidate, LStart, LEnd);
  end;
end;

function CandidateFrames(const AWindow: TBeatTrackWindow;
  const AIndex, AToleranceFrames: Integer): TBeatFrames;
begin
  Result := nil;
  if AIndex >= 0 then
  begin
    Result := GridFramesInWindow(AWindow,
      AWindow.Analysis.Candidates[AIndex], AToleranceFrames);
  end;
end;

function InspectSavedWindow(const AWindow: TBeatTrackWindow;
  const AObservations: TBeatObservations; const ASampleRate,
  ASourceFrames: Integer; const AGridOptions: TBeatGridOptions;
  const ATrackOptions: TBeatTrackOptions;
  out ATrace: TBeatCandidateTrace): TBeatGridAnalysis;
var
  LSubset: TBeatObservations;
  LPeak: Double;
  LTaper: Double;
  LCenter: Integer;
  LIndex: Integer;
  LCount: Integer;
begin
  LSubset := nil;
  SetLength(LSubset, Length(AObservations));
  LCount := 0;
  for LIndex := 0 to High(AObservations) do
  begin
    if (AObservations[LIndex].Frame >= AWindow.StartFrame) and
      (AObservations[LIndex].Frame < AWindow.EndFrame) then
    begin
      LSubset[LCount] := AObservations[LIndex];
      Inc(LCount);
    end;
  end;
  SetLength(LSubset, LCount);
  if ATrackOptions.TaperWindows then
  begin
    LCenter := AWindow.OwnerStartFrame +
      (AWindow.OwnerEndFrame - AWindow.OwnerStartFrame) div 2;
    LPeak := 0;
    for LIndex := 0 to High(LSubset) do
    begin
      LPeak := Max(LPeak, LSubset[LIndex].Weight);
    end;
    LCount := 0;
    for LIndex := 0 to High(LSubset) do
    begin
      LTaper := (1 + Cos(2 * Pi * (LSubset[LIndex].Frame - LCenter) /
        ATrackOptions.WindowFrames)) / 2;
      if LTaper > 0 then
      begin
        LSubset[LCount] := LSubset[LIndex];
        LSubset[LCount].Weight := (LSubset[LCount].Weight / LPeak) * LTaper;
        if LSubset[LCount].Weight > 0 then
        begin
          Inc(LCount);
        end;
      end;
    end;
    SetLength(LSubset, LCount);
  end;
  Result := InspectBeatGridCandidates(LSubset, ASampleRate, ASourceFrames,
    AGridOptions, ATrace);
  Require((Result.ObservationCount = AWindow.Analysis.ObservationCount) and
    (Result.FirstObservationFrame = AWindow.Analysis.FirstObservationFrame) and
    (Result.LastObservationFrame = AWindow.Analysis.LastObservationFrame) and
    (Length(Result.Candidates) = Length(AWindow.Analysis.Candidates)),
    'Traced candidate window differs from saved report');
  for LIndex := 0 to High(Result.Candidates) do
  begin
    Require(Near(Result.Candidates[LIndex].Bpm,
        AWindow.Analysis.Candidates[LIndex].Bpm) and
      Near(Result.Candidates[LIndex].PhaseFrame,
        AWindow.Analysis.Candidates[LIndex].PhaseFrame) and
      Near(Result.Candidates[LIndex].Score,
        AWindow.Analysis.Candidates[LIndex].Score),
      'Traced candidate differs from saved pool');
  end;
end;

function NearbyObservationCount(const AReference: TBeatFrames;
  const AObservations: TBeatObservations;
  const AStartFrame, AEndFrame, AToleranceFrames: Integer): Integer;
var
  LReference: Integer;
  LObservation: Integer;
begin
  Result := 0;
  LObservation := 0;
  for LReference := 0 to High(AReference) do
  begin
    while (LObservation < Length(AObservations)) and
      ((AObservations[LObservation].Frame < AStartFrame) or
       (AObservations[LObservation].Frame <
        AReference[LReference] - AToleranceFrames)) do
    begin
      Inc(LObservation);
    end;
    if (LObservation < Length(AObservations)) and
      (AObservations[LObservation].Frame < AEndFrame) and
      (Abs(AObservations[LObservation].Frame -
       AReference[LReference]) <= AToleranceFrames) then
    begin
      Inc(Result);
    end;
  end;
end;

function NearReference(const AReference: TBeatFrames; const AFrame,
  AToleranceFrames: Integer): Boolean;
var
  LIndex: Integer;
begin
  Result := False;
  for LIndex := 0 to High(AReference) do
  begin
    if AReference[LIndex] > AFrame + AToleranceFrames then
    begin
      Exit;
    end;
    if Abs(AReference[LIndex] - AFrame) <= AToleranceFrames then
    begin
      Exit(True);
    end;
  end;
end;

function NonreferenceOnsets(const AWindow: TBeatTrackWindow;
  const AReference: TBeatFrames; const AObservations: TBeatObservations;
  const AToleranceFrames: Integer): Integer;
var
  LIndex: Integer;
begin
  Result := 0;
  for LIndex := 0 to High(AObservations) do
  begin
    if (AObservations[LIndex].Frame >= AWindow.OwnerStartFrame) and
      (AObservations[LIndex].Frame < AWindow.OwnerEndFrame) and
      not NearReference(AReference, AObservations[LIndex].Frame,
        AToleranceFrames) then
    begin
      Inc(Result);
    end;
  end;
end;

function NonreferenceGridOnsetSupport(const AWindow: TBeatTrackWindow;
  const AReference, AGridFrames: TBeatFrames;
  const AObservations: TBeatObservations;
  const AToleranceFrames: Integer): Integer;
var
  LFrame: Integer;
  LObservation: Integer;
begin
  Result := 0;
  for LFrame := 0 to High(AGridFrames) do
  begin
    if NearReference(AReference, AGridFrames[LFrame], AToleranceFrames) then
    begin
      Continue;
    end;
    for LObservation := 0 to High(AObservations) do
    begin
      if (AObservations[LObservation].Frame >= AWindow.OwnerStartFrame) and
        (AObservations[LObservation].Frame < AWindow.OwnerEndFrame) and
        (Abs(AObservations[LObservation].Frame - AGridFrames[LFrame]) <=
         AToleranceFrames) then
      begin
        Inc(Result);
        Break;
      end;
    end;
  end;
end;

function TraceJson(const AWindow: TBeatTrackWindow;
  const ATrace: TBeatCandidateTrace; const AOwned: TBeatFrames;
  const AObservations: TBeatObservations; const AToleranceFrames: Integer;
  var AMatchWork: Int64): TJSONObject;
var
  LTrial: Integer;
  LStage: Integer;
  LBestStage: Integer;
  LBestTrial: Integer;
  LCompatible: array[0..3] of Integer;
  LScore: TMatchScore;
  LBestScore: TMatchScore;
  LFrames: TBeatFrames;
  LPositive: Integer;
  LPeak: Integer;
  LSuppressed: Integer;
  LCapacity: Integer;
  LNames: array[0..4] of String =
    ('no_compatible_fit', 'peak_filtered', 'suppressed', 'capacity', 'retained');
begin
  Result := nil;
  LPositive := 0;
  LPeak := 0;
  LSuppressed := 0;
  LCapacity := 0;
  LBestStage := 0;
  LBestTrial := -1;
  LBestScore := Default(TMatchScore);
  FillChar(LCompatible, SizeOf(LCompatible), 0);
  for LTrial := 0 to High(ATrace.Trials) do
  begin
    if ATrace.Trials[LTrial].Score <= 0 then
    begin
      Continue;
    end;
    Inc(LPositive);
    if ATrace.PeakEligible[LTrial] then
    begin
      Inc(LPeak);
    end;
    if ATrace.SelectedRank[LTrial] >= 0 then
    begin
      LStage := 4;
    end
    else if ATrace.SuppressedBy[LTrial] >= 0 then
    begin
      LStage := 2;
      Inc(LSuppressed);
    end
    else if ATrace.PeakEligible[LTrial] then
    begin
      LStage := 3;
      Inc(LCapacity);
    end
    else
    begin
      LStage := 1;
    end;
    LFrames := GridFramesInWindow(AWindow, ATrace.Trials[LTrial],
      AToleranceFrames);
    AMatchWork := AMatchWork + Length(AOwned) + Length(LFrames);
    Require(AMatchWork <= MaximumBeatTrackWork,
      'Candidate trace matching exceeds bounded work');
    LScore := MatchScore(AOwned, LFrames, AWindow.OwnerStartFrame,
      AWindow.OwnerEndFrame, AToleranceFrames);
    if (LScore.Precision >= 0.75) and (LScore.Recall >= 0.75) then
    begin
      Inc(LCompatible[LStage - 1]);
      if (LStage > LBestStage) or
        ((LStage = LBestStage) and
         ((LBestTrial < 0) or Better(LScore, LBestScore))) then
      begin
        LBestStage := LStage;
        LBestTrial := LTrial;
        LBestScore := LScore;
      end;
    end;
  end;
  Result := TJSONObject.Create;
  Result.Add('positive_fit_count', LPositive);
  Result.Add('peak_eligible_count', LPeak);
  Result.Add('suppressed_count', LSuppressed);
  Result.Add('capacity_count', LCapacity);
  Result.Add('reference_onset_near_count', NearbyObservationCount(AOwned,
    AObservations, AWindow.OwnerStartFrame, AWindow.OwnerEndFrame,
    AToleranceFrames));
  Result.Add('owner_nonreference_onset_count', NonreferenceOnsets(AWindow,
    AOwned, AObservations, AToleranceFrames));
  Result.Add('compatible_peak_filtered', LCompatible[0]);
  Result.Add('compatible_suppressed', LCompatible[1]);
  Result.Add('compatible_capacity', LCompatible[2]);
  Result.Add('compatible_retained', LCompatible[3]);
  Result.Add('latest_compatible_stage', LNames[LBestStage]);
  Result.Add('latest_compatible_trial', LBestTrial);
  if LBestTrial >= 0 then
  begin
    Result.Add('latest_compatible_bpm', ATrace.Trials[LBestTrial].Bpm);
    Result.Add('latest_compatible_phase_frame',
      ATrace.Trials[LBestTrial].PhaseFrame);
    Result.Add('latest_compatible_score', ScoreJson(LBestScore));
    if LBestStage = 2 then
    begin
      Result.Add('suppressed_by_trial', ATrace.SuppressedBy[LBestTrial]);
    end;
  end;
end;

procedure Evaluate(const AReportPath, AReferencePath, ASourcePath,
  AExpectedSourceHash, AExpectedReferenceHash: String;
  const ATraceEnabled: Boolean);
var
  LReport: TJSONObject;
  LOutput: TJSONObject;
  LRows: TJSONArray;
  LRates: TJSONArray;
  LRow: TJSONObject;
  LTrack: TJSONObject;
  LGridOptions: TJSONObject;
  LAnalysisPolicy: TJSONObject;
  LWindowJson: TJSONObject;
  LCandidateJson: TJSONObject;
  LWindowsJson: TJSONArray;
  LCandidatesJson: TJSONArray;
  LPointsJson: TJSONArray;
  LObservationsJson: TJSONArray;
  LObservationJson: TJSONObject;
  LClip: TAudioClip;
  LWindows: TBeatTrackWindows;
  LReplayed: TBeatTrackWindows;
  LSavedStarts: TBooleans;
  LReference: TBeatFrames;
  LOwned: TBeatFrames;
  LFrames: TBeatFrames;
  LFullRaw: TBeatFrames;
  LFullAligned: TBeatFrames;
  LObservations: TBeatObservations;
  LTrace: TBeatCandidateTrace;
  LTraced: TBeatGridAnalysis;
  LSourceHash: String;
  LReferenceHash: String;
  LScore: TMatchScore;
  LBest: TMatchScore;
  LBestRecall: TMatchScore;
  LBestCompatible: TMatchScore;
  LSelected: TMatchScore;
  LOptions: TBeatTrackOptions;
  LDefaultGrid: TBeatGridOptions;
  LTraceGrid: TBeatGridOptions;
  LDefaultAnalysis: TAnalysisOptions;
  LDefaultActivity: TActivityOptions;
  LDefaultLocation: TOnsetLocationOptions;
  LDefaultEvents: TOnsetEventOptions;
  LIndex: Integer;
  LChoice: Integer;
  LBestIndex: Integer;
  LRecallIndex: Integer;
  LCompatibleIndex: Integer;
  LSelectedIndex: Integer;
  LEligible: Integer;
  LAvailable: Integer;
  LRecallAvailable: Integer;
  LReferenceTotal: Integer;
  LBestPoolMatches: Integer;
  LToleranceFrames: Integer;
  LCenter: Integer;
  LTraceFitWork: Int64;
  LTraceMatchWork: Int64;
begin
  LReport := nil;
  LOutput := nil;
  LClip := nil;
  try
    LReport := LoadReport(AReportPath);
    LClip := LoadWaveSource(ASourcePath, LSourceHash);
    LReferenceHash := HashAudioBytes(ReadFileBytes(AReferencePath, 65536));
    Require((LSourceHash = AExpectedSourceHash) and
      (LSourceHash = StringField(LReport, 'source_sha256')),
      'Candidate source identity mismatch');
    Require(LReferenceHash = AExpectedReferenceHash,
      'Candidate reference identity mismatch');
    Require((LClip.SampleRate = IntegerField(LReport, 'sample_rate')) and
      (LClip.FrameCount = IntegerField(LReport, 'source_frames')),
      'Candidate source geometry mismatch');
    Require(IntegerField(LReport, 'version') = BeatGridVersion,
      'Candidate grid report version mismatch');
    Require(StringField(LReport, 'measurement_policy') =
      BeatGridMeasurementPolicy, 'Candidate measurement policy mismatch');
    LDefaultAnalysis := DefaultOnsetAnalysisOptions(LClip.SampleRate);
    LDefaultActivity := DefaultActivityOptions;
    LDefaultLocation := DefaultOnsetLocationOptions(LClip.SampleRate);
    LDefaultEvents := DefaultOnsetEventOptions(LClip.SampleRate);
    LAnalysisPolicy := ObjectField(LReport, 'analysis_policy');
    Require((IntegerField(LAnalysisPolicy, 'window_frames') =
        LDefaultAnalysis.WindowFrames) and
      (IntegerField(LAnalysisPolicy, 'hop_frames') =
        LDefaultAnalysis.HopFrames) and
      Near(NumberField(LAnalysisPolicy, 'silence_rms'),
        LDefaultAnalysis.SilenceRms) and
      Near(NumberField(LAnalysisPolicy, 'minimum_flux'),
        LDefaultActivity.MinimumFlux) and
      Near(NumberField(LAnalysisPolicy, 'adaptive_multiplier'),
        LDefaultActivity.AdaptiveMultiplier) and
      (IntegerField(LAnalysisPolicy, 'history_features') =
        LDefaultActivity.HistoryFeatures) and
      (IntegerField(LAnalysisPolicy, 'peak_radius') =
        LDefaultActivity.PeakRadius) and
      (IntegerField(LAnalysisPolicy, 'minimum_separation_features') =
        LDefaultActivity.MinimumSeparationFeatures) and
      (IntegerField(LAnalysisPolicy, 'maximum_segment_features') =
        LDefaultActivity.MaximumSegmentFeatures) and
      (IntegerField(LAnalysisPolicy, 'energy_window_frames') =
        LDefaultLocation.EnergyWindowFrames) and
      Near(NumberField(LAnalysisPolicy, 'minimum_energy_rise'),
        LDefaultLocation.MinimumEnergyRise) and
      Near(NumberField(LAnalysisPolicy, 'minimum_contrast'),
        LDefaultLocation.MinimumContrast) and
      (IntegerField(LAnalysisPolicy, 'minimum_event_frames') =
        LDefaultEvents.MinimumFrames) and
      (BooleanField(LAnalysisPolicy, 'allow_clipped_context') =
        LDefaultEvents.AllowClippedContext) and
      (BooleanField(LAnalysisPolicy, 'allow_search_boundary') =
        LDefaultEvents.AllowSearchBoundary),
      'Candidate onset policy differs from frozen defaults');
    LDefaultGrid := DefaultBeatGridOptions;
    LGridOptions := ObjectField(LReport, 'grid_policy');
    Require(Near(NumberField(LGridOptions, 'minimum_bpm'),
        LDefaultGrid.MinimumBpm) and
      Near(NumberField(LGridOptions, 'maximum_bpm'),
        LDefaultGrid.MaximumBpm) and
      Near(NumberField(LGridOptions, 'step_bpm'),
        LDefaultGrid.StepBpm) and
      Near(NumberField(LGridOptions, 'minimum_separation_bpm'),
        LDefaultGrid.MinimumSeparationBpm) and
      Near(NumberField(LGridOptions, 'tolerance_seconds'),
        LDefaultGrid.ToleranceSeconds) and
      Near(NumberField(LGridOptions, 'minimum_matched_weight'),
        LDefaultGrid.MinimumMatchedWeight) and
      (IntegerField(LGridOptions, 'minimum_cycles') =
        LDefaultGrid.MinimumCycles) and
      (IntegerField(LGridOptions, 'maximum_candidates') >= 1) and
      (IntegerField(LGridOptions, 'maximum_candidates') <= 16),
      'Candidate grid policy is outside frozen bounds');
    LReference := LoadReference(AReferencePath, LClip.SampleRate,
      LClip.FrameCount);
    LTrack := ObjectField(LReport, 'local_track');
    Require(IntegerField(LTrack, 'version') = BeatTrackVersion,
      'Candidate track report version mismatch');
    LOptions := DefaultBeatTrackOptions(LClip.SampleRate);
    Require((IntegerField(LTrack, 'window_frames') = LOptions.WindowFrames) and
      (IntegerField(LTrack, 'hop_frames') = LOptions.HopFrames) and
      Near(NumberField(LTrack, 'maximum_tempo_ratio'),
        LOptions.MaximumTempoRatio) and
      Near(NumberField(LTrack, 'tempo_penalty'), LOptions.TempoPenalty) and
      Near(NumberField(LTrack, 'phase_penalty'), LOptions.PhasePenalty) and
      Near(NumberField(LTrack, 'snap_tolerance_seconds'),
        LOptions.SnapToleranceSeconds) and
      (BooleanField(LTrack, 'taper_windows') = LOptions.TaperWindows),
      'Candidate track policy is outside frozen bounds');
    Require(IntegerField(LTrack, 'fit_work') <= MaximumBeatTrackWork,
      'Candidate fit work exceeds bound');
    LWindowsJson := ArrayField(LTrack, 'windows');
    Require((LWindowsJson.Count >= 1) and
      (LWindowsJson.Count <= MaximumBeatTrackWindows),
      'Candidate window count exceeds bound');
    if ATraceEnabled then
    begin
      LObservationsJson := ArrayField(LReport, 'observations');
      Require((LObservationsJson.Count =
        IntegerField(LReport, 'observation_count')) and
        (LObservationsJson.Count <= MaximumBeatObservations),
        'Candidate trace observation count differs from saved report');
      SetLength(LObservations, LObservationsJson.Count);
      for LIndex := 0 to LObservationsJson.Count - 1 do
      begin
        LObservationJson := TJSONObject(LObservationsJson.Items[LIndex]);
        LObservations[LIndex].Frame := IntegerField(LObservationJson, 'frame');
        LObservations[LIndex].Weight := NumberField(LObservationJson, 'weight');
        Require((LObservations[LIndex].Frame >= 0) and
          (LObservations[LIndex].Frame < LClip.FrameCount) and
          (LObservations[LIndex].Weight > 0) and
          (LObservations[LIndex].Weight <= 1),
          'Candidate trace observation is invalid');
        if LIndex > 0 then
        begin
          Require(LObservations[LIndex].Frame >
            LObservations[LIndex - 1].Frame,
            'Candidate trace observations are unordered');
        end;
      end;
      LTraceGrid := LDefaultGrid;
      LTraceGrid.MaximumCandidates := IntegerField(LGridOptions,
        'maximum_candidates');
    end;
    SetLength(LWindows, LWindowsJson.Count);
    SetLength(LSavedStarts, LWindowsJson.Count);
    for LIndex := 0 to LWindowsJson.Count - 1 do
    begin
      LWindowJson := TJSONObject(LWindowsJson.Items[LIndex]);
      LWindows[LIndex].StartFrame := IntegerField(LWindowJson, 'start_frame');
      LWindows[LIndex].EndFrame := IntegerField(LWindowJson, 'end_frame');
      LWindows[LIndex].OwnerStartFrame := IntegerField(LWindowJson,
        'owner_start_frame');
      LWindows[LIndex].OwnerEndFrame := IntegerField(LWindowJson,
        'owner_end_frame');
      LWindows[LIndex].Analysis.FirstObservationFrame := IntegerField(
        LWindowJson, 'first_observation_frame');
      LWindows[LIndex].Analysis.LastObservationFrame := IntegerField(
        LWindowJson, 'last_observation_frame');
      LWindows[LIndex].Analysis.ObservationCount := IntegerField(
        LWindowJson, 'observation_count');
      LWindows[LIndex].SelectedCandidate := IntegerField(LWindowJson,
        'selected_candidate');
      LSavedStarts[LIndex] := BooleanField(LWindowJson, 'starts_new_path');
      LWindows[LIndex].StartsNewPath := False;
      Require((LWindows[LIndex].OwnerStartFrame = LIndex *
        LOptions.HopFrames) and
        (LWindows[LIndex].OwnerEndFrame = Min(LClip.FrameCount,
          (LIndex + 1) * LOptions.HopFrames)),
        'Candidate owner geometry differs from frozen hop');
      LCenter := LWindows[LIndex].OwnerStartFrame +
        (LWindows[LIndex].OwnerEndFrame -
         LWindows[LIndex].OwnerStartFrame) div 2;
      Require((LWindows[LIndex].StartFrame >= 0) and
        (LWindows[LIndex].EndFrame <= LClip.FrameCount) and
        (LWindows[LIndex].StartFrame = Max(0,
          LCenter - LOptions.WindowFrames div 2)) and
        (LWindows[LIndex].EndFrame = Min(LClip.FrameCount,
          LCenter + LOptions.WindowFrames -
          LOptions.WindowFrames div 2)),
        'Candidate source window geometry is invalid');
      LCandidatesJson := ArrayField(LWindowJson, 'candidates');
      Require(LCandidatesJson.Count <=
        IntegerField(LGridOptions, 'maximum_candidates'),
        'Candidate pool exceeds declared grid limit');
      SetLength(LWindows[LIndex].Analysis.Candidates, LCandidatesJson.Count);
      for LChoice := 0 to LCandidatesJson.Count - 1 do
      begin
        LCandidateJson := TJSONObject(LCandidatesJson.Items[LChoice]);
        LWindows[LIndex].Analysis.Candidates[LChoice].Bpm := NumberField(
          LCandidateJson, 'bpm');
        LWindows[LIndex].Analysis.Candidates[LChoice].PeriodFrames := NumberField(
          LCandidateJson, 'period_frames');
        LWindows[LIndex].Analysis.Candidates[LChoice].PhaseFrame := NumberField(
          LCandidateJson, 'phase_frame');
        LWindows[LIndex].Analysis.Candidates[LChoice].Score := NumberField(
          LCandidateJson, 'score');
        LWindows[LIndex].Analysis.Candidates[LChoice].PhaseConcentration :=
          NumberField(LCandidateJson, 'phase_concentration');
        LWindows[LIndex].Analysis.Candidates[LChoice].MatchedWeightFraction :=
          NumberField(LCandidateJson, 'matched_weight_fraction');
        LWindows[LIndex].Analysis.Candidates[LChoice].Coverage := NumberField(
          LCandidateJson, 'coverage');
        LWindows[LIndex].Analysis.Candidates[LChoice].MeanErrorFrames :=
          NumberField(LCandidateJson, 'mean_error_frames');
        LWindows[LIndex].Analysis.Candidates[LChoice].SupportedOnsets :=
          IntegerField(LCandidateJson, 'supported_onsets');
        LWindows[LIndex].Analysis.Candidates[LChoice].SupportedBeats :=
          IntegerField(LCandidateJson, 'supported_beats');
        LWindows[LIndex].Analysis.Candidates[LChoice].GridBeats :=
          IntegerField(LCandidateJson, 'grid_beats');
        Require(Near(LWindows[LIndex].Analysis.Candidates[LChoice].PeriodFrames *
          LWindows[LIndex].Analysis.Candidates[LChoice].Bpm,
          LClip.SampleRate * 60.0),
          'Candidate period and BPM disagree');
      end;
    end;
    LReplayed := SelectBeatTrackPath(LWindows, LOptions);
    for LIndex := 0 to High(LWindows) do
    begin
      Require(LReplayed[LIndex].SelectedCandidate =
        LWindows[LIndex].SelectedCandidate,
        'Candidate selected path does not replay');
      Require(LReplayed[LIndex].StartsNewPath = LSavedStarts[LIndex],
        'Candidate path break does not replay');
    end;
    LToleranceFrames := EvaluationToleranceFrames(LClip.SampleRate, 30);
    LOutput := TJSONObject.Create;
    LOutput.Add('source_sha256', LSourceHash);
    LOutput.Add('reference_sha256', LReferenceHash);
    LOutput.Add('report_sha256', HashAudioBytes(ReadFileBytes(AReportPath,
      8 * 1024 * 1024)));
    LOutput.Add('measurement_policy', BeatGridMeasurementPolicy);
    LOutput.Add('candidate_policy', StringField(LReport, 'candidate_policy'));
    LOutput.Add('tolerance_ms', 30);
    LOutput.Add('fit_work', IntegerField(LTrack, 'fit_work'));
    LRows := TJSONArray.Create;
    LOutput.Add('windows', LRows);
    LEligible := 0;
    LAvailable := 0;
    LRecallAvailable := 0;
    LReferenceTotal := 0;
    LBestPoolMatches := 0;
    LTraceFitWork := 0;
    LTraceMatchWork := 0;
    for LIndex := 0 to High(LWindows) do
    begin
      LOwned := OwnedReference(LReference, LWindows[LIndex].OwnerStartFrame,
        LWindows[LIndex].OwnerEndFrame);
      LBest := Default(TMatchScore);
      LBestRecall := Default(TMatchScore);
      LBestCompatible := Default(TMatchScore);
      LBestIndex := -1;
      LRecallIndex := -1;
      LCompatibleIndex := -1;
      for LChoice := 0 to High(LWindows[LIndex].Analysis.Candidates) do
      begin
        LFrames := CandidateFrames(LWindows[LIndex], LChoice,
          LToleranceFrames);
        LScore := MatchScore(LOwned, LFrames,
          LWindows[LIndex].OwnerStartFrame,
          LWindows[LIndex].OwnerEndFrame, LToleranceFrames);
        if (LBestIndex < 0) or Better(LScore, LBest) then
        begin
          LBest := LScore;
          LBestIndex := LChoice;
        end;
        if (LRecallIndex < 0) or BetterRecall(LScore, LBestRecall) then
        begin
          LBestRecall := LScore;
          LRecallIndex := LChoice;
        end;
        if (LScore.Precision >= 0.75) and (LScore.Recall >= 0.75) and
          ((LCompatibleIndex < 0) or Better(LScore, LBestCompatible)) then
        begin
          LBestCompatible := LScore;
          LCompatibleIndex := LChoice;
        end;
      end;
      LSelectedIndex := LWindows[LIndex].SelectedCandidate;
      LFrames := CandidateFrames(LWindows[LIndex], LSelectedIndex,
        LToleranceFrames);
      LSelected := MatchScore(LOwned, LFrames,
        LWindows[LIndex].OwnerStartFrame,
        LWindows[LIndex].OwnerEndFrame, LToleranceFrames);
      LRow := TJSONObject.Create;
      LRows.Add(LRow);
      LRow.Add('window_index', LIndex);
      LRow.Add('owner_start_frame', LWindows[LIndex].OwnerStartFrame);
      LRow.Add('owner_end_frame', LWindows[LIndex].OwnerEndFrame);
      LRow.Add('observation_count', LWindows[LIndex].Analysis.ObservationCount);
      LRow.Add('candidate_count',
        Length(LWindows[LIndex].Analysis.Candidates));
      LRates := TJSONArray.Create;
      LRow.Add('retained_bpm', LRates);
      for LChoice := 0 to High(LWindows[LIndex].Analysis.Candidates) do
      begin
        LRates.Add(LWindows[LIndex].Analysis.Candidates[LChoice].Bpm);
      end;
      LRow.Add('eligible', Length(LOwned) >= 2);
      LRow.Add('reference_compatible', LCompatibleIndex >= 0);
      LRow.Add('witness_index', LBestIndex);
      LRow.Add('witness', ScoreJson(LBest));
      LRow.Add('best_recall_index', LRecallIndex);
      LRow.Add('best_recall', ScoreJson(LBestRecall));
      LRow.Add('recall_compatible', (LRecallIndex >= 0) and
        (LBestRecall.Recall >= 0.75));
      LRow.Add('compatible_index', LCompatibleIndex);
      if LCompatibleIndex >= 0 then
      begin
        LRow.Add('compatible', ScoreJson(LBestCompatible));
      end;
      LRow.Add('selected_index', LSelectedIndex);
      LRow.Add('selected_raw', ScoreJson(LSelected));
      Inc(LReferenceTotal, Length(LOwned));
      Inc(LBestPoolMatches, LBestRecall.Matches);
      if ATraceEnabled then
      begin
        LTraced := InspectSavedWindow(LWindows[LIndex], LObservations,
          LClip.SampleRate, LClip.FrameCount, LTraceGrid, LOptions, LTrace);
        LTraceFitWork := LTraceFitWork + BeatGridFitWork(
          LTraced.ObservationCount, LTraced.TrialCount);
        Require(LTraceFitWork <= MaximumBeatTrackWork,
          'Candidate trace fit work exceeds aggregate budget');
        if (Length(LOwned) >= 2) and (LCompatibleIndex < 0) then
        begin
          LRow.Add('trace', TraceJson(LWindows[LIndex], LTrace, LOwned,
            LObservations, LToleranceFrames, LTraceMatchWork));
          LFrames := CandidateFrames(LWindows[LIndex], LBestIndex,
            LToleranceFrames);
          LRow.Add('witness_nonreference_onset_grids',
            NonreferenceGridOnsetSupport(LWindows[LIndex], LOwned, LFrames,
              LObservations, LToleranceFrames));
        end;
      end;
      if (Length(LOwned) >= 2) and (LCompatibleIndex < 0) then
      begin
        WriteLn(StdErr, ExtractFileName(ASourcePath), ' window ',
          LIndex, ': missing compatible candidate; witness ',
          LBestIndex, ' matches ', LBest.Matches, '/',
          LBest.ReferenceCount, ', extras ',
          LBest.PredictionCount - LBest.Matches);
      end;
      if Length(LOwned) >= 2 then
      begin
        Inc(LEligible);
        if (LRecallIndex >= 0) and (LBestRecall.Recall >= 0.75) then
        begin
          Inc(LRecallAvailable);
        end;
        if LCompatibleIndex >= 0 then
        begin
          Inc(LAvailable);
        end;
      end;
    end;
    LOutput.Add('eligible_windows', LEligible);
    LOutput.Add('available_windows', LAvailable);
    LOutput.Add('recall_available_windows', LRecallAvailable);
    LOutput.Add('reference_total', LReferenceTotal);
    LOutput.Add('best_pool_matches', LBestPoolMatches);
    if LReferenceTotal > 0 then
    begin
      LOutput.Add('best_pool_recall', LBestPoolMatches / LReferenceTotal);
    end;
    if LEligible > 0 then
    begin
      LOutput.Add('candidate_coverage', LAvailable / LEligible);
      LOutput.Add('recall_coverage', LRecallAvailable / LEligible);
    end;
    if ATraceEnabled then
    begin
      Require(LTraceFitWork = IntegerField(LTrack, 'fit_work'),
        'Candidate trace work differs from saved inference');
      LOutput.Add('trace_fit_work', LTraceFitWork);
      LOutput.Add('trace_match_work', LTraceMatchWork);
    end;
    LPointsJson := ArrayField(LTrack, 'points');
    SetLength(LFullRaw, LPointsJson.Count);
    SetLength(LFullAligned, LPointsJson.Count);
    for LIndex := 0 to LPointsJson.Count - 1 do
    begin
      LWindowJson := TJSONObject(LPointsJson.Items[LIndex]);
      LFullRaw[LIndex] := IntegerField(LWindowJson, 'grid_frame');
      LFullAligned[LIndex] := IntegerField(LWindowJson, 'frame');
      Require((LFullRaw[LIndex] >= 0) and
        (LFullRaw[LIndex] < LClip.FrameCount) and
        (LFullAligned[LIndex] >= 0) and
        (LFullAligned[LIndex] < LClip.FrameCount),
        'Candidate selected point outside source');
      if LIndex > 0 then
      begin
        Require((LFullRaw[LIndex] > LFullRaw[LIndex - 1]) and
          (LFullAligned[LIndex] > LFullAligned[LIndex - 1]),
          'Candidate selected points are unordered');
      end;
    end;
    LOutput.Add('selected_full_raw', ScoreJson(MatchScore(LReference,
      LFullRaw, 0, LClip.FrameCount, LToleranceFrames)));
    LOutput.Add('selected_full_aligned', ScoreJson(MatchScore(LReference,
      LFullAligned, 0, LClip.FrameCount, LToleranceFrames)));
    WriteLn(StdErr, ExtractFileName(ASourcePath), ': ',
      LAvailable, '/', LEligible, ' eligible windows retain a compatible ',
      'candidate; selected raw F1 ',
      MatchScore(LReference, LFullRaw, 0, LClip.FrameCount,
        LToleranceFrames).F1:0:4);
    WriteLn(LOutput.FormatJSON);
  finally
    LOutput.Free;
    LReport.Free;
    LClip.Free;
  end;
end;

begin
  try
    if (ParamCount <> 5) and (ParamCount <> 6) then
    begin
      raise EAudio.Create('Usage: pythian.beat.candidates REPORT.json ' +
        'REFERENCE.csv SOURCE.wav SOURCE_SHA256 REFERENCE_SHA256 [--trace]');
    end;
    if (ParamCount = 6) and (ParamStr(6) <> '--trace') then
    begin
      raise EAudio.Create('Unknown candidate evaluation option');
    end;
    Evaluate(ParamStr(1), ParamStr(2), ParamStr(3), ParamStr(4),
      ParamStr(5), ParamCount = 6);
  except
    on LError: Exception do
    begin
      WriteLn(StdErr, LError.Message);
      ExitCode := 1;
    end;
  end;
end.
