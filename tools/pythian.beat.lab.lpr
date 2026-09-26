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
program pythian_beat_lab;

{$mode delphi}
{$H+}

uses
  SysUtils,
  Math,
  fpjson,
  pythian.audio,
  pythian.evaluation,
  pythian.wave,
  pythian.oscillator,
  pythian.analysis,
  pythian.activity,
  pythian.onset,
  pythian.onset.events,
  pythian.beat,
  pythian.beat.track,
  pythian.tools.files;

const
  CRate = 44100;
  CFrames = 617400;
  CTolerance = 1323;
  CNames: array[0..2] of String = ('regular', 'polyphonic', 'tempo-change');

procedure Check(const ACondition: Boolean; const AMessage: String);
begin
  if not ACondition then
  begin
    raise EAudio.Create(AMessage);
  end;
end;

function MakeCase(const ACase: Integer; out ATruth: TBeatFrames): TAudioClip;
var
  LSamples: TAudioSamples;
  LNoise: TOscillator;
  LChord: array[0..2] of TOscillator;
  LIndex: Integer;
  LFrame: Integer;
  LBeat: Integer;
  LAge: Integer;
  LStart: Integer;
  LCount: Integer;
  LValue: Double;
  LBed: Double;
  LFrequency: Double;
  LEnvelope: Double;
begin
  LNoise := nil;
  for LIndex := 0 to High(LChord) do
  begin
    LChord[LIndex] := nil;
  end;
  try
    LCount := 24;
    if ACase = 1 then
    begin
      LCount := 20;
    end;
    SetLength(ATruth, LCount);
    for LBeat := 0 to High(ATruth) do
    begin
      case ACase of
        0: ATruth[LBeat] := 5093 + LBeat * 22050;
        1: ATruth[LBeat] := 7131 + (Int64(LBeat) * 55125) div 2;
        2:
        begin
          if LBeat < 12 then
          begin
            ATruth[LBeat] := 5093 + LBeat * 22050;
          end
          else
          begin
            ATruth[LBeat] := 5093 + 12 * 22050 + (LBeat - 12) * 26460;
          end;
        end;
      end;
    end;
    SetLength(LSamples, CFrames * 2);
    LNoise := TOscillator.Create(CRate, 731);
    for LIndex := 0 to High(LChord) do
    begin
      LChord[LIndex] := TOscillator.Create(CRate, 731 + LIndex);
    end;
    if ACase = 1 then
    begin
      for LFrame := 0 to CFrames - 1 do
      begin
        LBed := 0;
        LEnvelope := Min(1, LFrame / 4410) * Min(1, (CFrames - LFrame) / 4410);
        for LIndex := 0 to High(LChord) do
        begin
          case LIndex of
            0: LFrequency := 130.81278265;
            1: LFrequency := 164.81377846;
            2: LFrequency := 195.99771799;
          end;
          if (LFrame div 110250) mod 2 = 1 then
          begin
            LFrequency := LFrequency * 4 / 3;
          end;
          LBed := LBed + 0.035 * LChord[LIndex].Next(wsSine, LFrequency);
        end;
        LSamples[LFrame * 2] := LBed * LEnvelope;
        LSamples[LFrame * 2 + 1] := LBed * LEnvelope * 0.8;
      end;
    end;
    for LBeat := 0 to High(ATruth) do
    begin
      LStart := ATruth[LBeat];
      LNoise.Reset(731 + LBeat);
      for LAge := 0 to 2204 do
      begin
        LFrame := LStart + LAge;
        LValue := 0.65 * (1 - LAge / 2205) * LNoise.Next(wsNoise, 0);
        LSamples[LFrame * 2] := LSamples[LFrame * 2] + LValue;
        LSamples[LFrame * 2 + 1] := LSamples[LFrame * 2 + 1] - LValue;
      end;
      if (ACase = 1) and (LBeat < High(ATruth)) then
      begin
        LStart := (ATruth[LBeat] + ATruth[LBeat + 1]) div 2;
        for LAge := 0 to 881 do
        begin
          LFrame := LStart + LAge;
          LValue := 0.08 * (1 - LAge / 882) * LNoise.Next(wsNoise, 0);
          LSamples[LFrame * 2] := LSamples[LFrame * 2] + LValue;
          LSamples[LFrame * 2 + 1] := LSamples[LFrame * 2 + 1] - LValue;
        end;
      end;
    end;
    Result := TAudioClip.Create(CRate, 2, LSamples);
  finally
    LNoise.Free;
    for LIndex := 0 to High(LChord) do
    begin
      LChord[LIndex].Free;
    end;
  end;
end;

function FrameJson(const AFrames: TBeatFrames): TJSONArray;
var
  LIndex: Integer;
begin
  Result := TJSONArray.Create;
  for LIndex := 0 to High(AFrames) do
  begin
    Result.Add(AFrames[LIndex]);
  end;
end;

function TimingMetrics(const ATruth, APredicted: TBeatFrames): TJSONObject;
var
  LReference: TEvaluationFrames;
  LPrediction: TEvaluationFrames;
  LMetrics: TEventEvaluation;
  LIndex: Integer;
begin
  LReference := nil;
  LPrediction := nil;
  SetLength(LReference, Length(ATruth));
  SetLength(LPrediction, Length(APredicted));
  for LIndex := 0 to High(ATruth) do
  begin
    LReference[LIndex] := ATruth[LIndex];
  end;
  for LIndex := 0 to High(APredicted) do
  begin
    LPrediction[LIndex] := APredicted[LIndex];
  end;
  LMetrics := EvaluateEvents(LReference, LPrediction, 0, CFrames, CTolerance);
  Result := TJSONObject.Create;
  Result.Add('tolerance_frames', CTolerance);
  Result.Add('matches', LMetrics.Matches);
  Result.Add('false_positives', LMetrics.Extras);
  Result.Add('misses', LMetrics.Misses);
  if LMetrics.Matches > 0 then
  begin
    Result.Add('mean_error_frames', LMetrics.AbsoluteErrorFrames / LMetrics.Matches);
  end;
end;

function EvaluationFrames(const AFrames, ATruth: TBeatFrames): TBeatFrames;
var
  LIndex: Integer;
  LCount: Integer;
begin
  Result := nil;
  SetLength(Result, Length(AFrames));
  LCount := 0;
  for LIndex := 0 to High(AFrames) do
  begin
    if (AFrames[LIndex] >= Max(0, ATruth[0] - CTolerance)) and
      (AFrames[LIndex] < ATruth[High(ATruth)] + CTolerance + 1) then
    begin
      Result[LCount] := AFrames[LIndex];
      Inc(LCount);
    end;
  end;
  SetLength(Result, LCount);
end;

procedure RunCase(const APrefix: String; const ACase: Integer);
var
  LOriginal: TAudioClip;
  LDecoded: TAudioClip;
  LTruth: TBeatFrames;
  LFrames: TBeatFrames;
  LBytes: TAudioBytes;
  LFeatures: TAudioFeatures;
  LLocations: TOnsetLocations;
  LEvents: TOnsetEventPlan;
  LObservations: TBeatObservations;
  LAnalysisOptions: TAnalysisOptions;
  LAnalysis: TBeatGridAnalysis;
  LTrack: TBeatTrack;
  LTrackOptions: TBeatTrackOptions;
  LTrackJson: TJSONObject;
  LDocument: TJSONObject;
  LRows: TJSONArray;
  LRow: TJSONObject;
  LMetrics: TJSONObject;
  LPath: String;
  LPeak: Double;
  LIndex: Integer;
  LPoint: Integer;
  LReferenceAvailable: Boolean;
begin
  LOriginal := nil;
  LDecoded := nil;
  LDocument := nil;
  try
    LOriginal := MakeCase(ACase, LTruth);
    LBytes := EncodeWavePcm16(LOriginal);
    LDecoded := DecodeWave(LBytes);
    LPath := APrefix + '-' + CNames[ACase];
    WriteFileBytes(LPath + '.wav', LBytes);
    LAnalysisOptions := DefaultOnsetAnalysisOptions(CRate);
    LFeatures := AnalyzeAudio(LDecoded, LAnalysisOptions);
    LLocations := LocalizeAcousticOnsets(LDecoded, LFeatures, LAnalysisOptions,
      DefaultActivityOptions, DefaultOnsetLocationOptions(CRate));
    LEvents := PlanOnsetEvents(LLocations, CFrames, DefaultOnsetEventOptions(CRate));
    SetLength(LObservations, Length(LEvents.Bounds) - 2);
    LPeak := 0;
    for LIndex := 0 to High(LObservations) do
    begin
      LPoint := LEvents.LocationIndices[LIndex + 1];
      LObservations[LIndex].Frame := LLocations[LPoint].Frame;
      LObservations[LIndex].Weight := Sqrt(LLocations[LPoint].EnergyRise);
      LPeak := Max(LPeak, LObservations[LIndex].Weight);
    end;
    if LPeak > 0 then
    begin
      for LIndex := 0 to High(LObservations) do
      begin
        LObservations[LIndex].Weight := LObservations[LIndex].Weight / LPeak;
      end;
    end;
    LAnalysis := EstimateBeatGrids(LObservations, CRate, CFrames, DefaultBeatGridOptions);
    LDocument := TJSONObject.Create;
    LDocument.Add('version', BeatGridVersion);
    LDocument.Add('measurement_policy', BeatGridMeasurementPolicy);
    LDocument.Add('case', CNames[ACase]);
    LDocument.Add('source_sha256', HashAudioBytes(LBytes));
    LDocument.Add('sample_rate', CRate);
    LDocument.Add('channels', 2);
    LDocument.Add('source_frames', CFrames);
    LDocument.Add('truth', 'Authored quarter-note clock; timing is independent of detector output');
    LDocument.Add('truth_frames', FrameJson(LTruth));
    LDocument.Add('admitted_onsets', Length(LObservations));
    LRows := TJSONArray.Create;
    LDocument.Add('candidates', LRows);
    LReferenceAvailable := False;
    for LIndex := 0 to High(LAnalysis.Candidates) do
    begin
      LRow := TJSONObject.Create;
      LRows.Add(LRow);
      LRow.Add('bpm', LAnalysis.Candidates[LIndex].Bpm);
      LRow.Add('score', LAnalysis.Candidates[LIndex].Score);
      LRow.Add('phase_frame', LAnalysis.Candidates[LIndex].PhaseFrame);
      { The truth evaluation interval is authored, independent of detected span. }
      LFrames := BeatGridFrames(LAnalysis.Candidates[LIndex],
        Max(0, LTruth[0] - CTolerance), LTruth[High(LTruth)] + CTolerance + 1);
      LRow.Add('predicted_frames', FrameJson(LFrames));
      LMetrics := TimingMetrics(LTruth, LFrames);
      LRow.Add('metrics', LMetrics);
      LReferenceAvailable := LReferenceAvailable or
        ((LMetrics.Integers['matches'] = Length(LTruth)) and
         (LMetrics.Integers['false_positives'] = 0));
      if LIndex = 0 then
      begin
        WriteLn(CNames[ACase], ': ', Length(LObservations), ' onsets; ',
          LAnalysis.Candidates[LIndex].Bpm:0:2, ' BPM; ',
          LMetrics.Integers['matches'], '/', Length(LTruth), ' matched beats; ',
          LMetrics.Integers['false_positives'], ' extra grid points');
        if ACase = 0 then
        begin
          Check((Abs(LAnalysis.Candidates[LIndex].Bpm - 120) < 0.01) and
            (LMetrics.Integers['matches'] = Length(LTruth)) and
            (LMetrics.Integers['false_positives'] = 0), 'Regular native WAV clock regressed');
        end;
      end;
    end;
    Check((ACase <> 0) or (Length(LAnalysis.Candidates) > 0),
      'Regular native WAV must yield a supported grid');
    LDocument.Add('reference_grid_available', LReferenceAvailable);
    Check((ACase = 2) or LReferenceAvailable,
      'Regular/polyphonic reference grid must remain available despite metrical ranking');
    LTrackOptions := DefaultBeatTrackOptions(CRate);
    LTrack := TrackBeatGrids(LObservations, CRate, CFrames,
      DefaultBeatGridOptions, LTrackOptions);
    LTrackJson := TJSONObject.Create;
    LDocument.Add('local_track', LTrackJson);
    LTrackJson.Add('version', BeatTrackVersion);
    LTrackJson.Add('window_frames', LTrackOptions.WindowFrames);
    LTrackJson.Add('hop_frames', LTrackOptions.HopFrames);
    LTrackJson.Add('maximum_tempo_ratio', LTrackOptions.MaximumTempoRatio);
    LTrackJson.Add('tempo_penalty', LTrackOptions.TempoPenalty);
    LTrackJson.Add('phase_penalty', LTrackOptions.PhasePenalty);
    LTrackJson.Add('taper_windows', LTrackOptions.TaperWindows);
    LTrackJson.Add('snap_tolerance_seconds', LTrackOptions.SnapToleranceSeconds);
    LTrackJson.Add('frames', FrameJson(LTrack.Frames));
    LTrackJson.Add('grid_frames', FrameJson(LTrack.GridFrames));
    LTrackJson.Add('observation_indices', FrameJson(LTrack.ObservationIndices));
    LTrackJson.Add('seam_issues', LTrack.SeamIssues);
    LFrames := EvaluationFrames(LTrack.GridFrames, LTruth);
    LTrackJson.Add('grid_metrics', TimingMetrics(LTruth, LFrames));
    LFrames := EvaluationFrames(LTrack.Frames, LTruth);
    LTrackJson.Add('evaluation_start_frame', Max(0, LTruth[0] - CTolerance));
    LTrackJson.Add('evaluation_end_frame', LTruth[High(LTruth)] + CTolerance + 1);
    LMetrics := TimingMetrics(LTruth, LFrames);
    LTrackJson.Add('metrics', LMetrics);
    LRows := TJSONArray.Create;
    LTrackJson.Add('windows', LRows);
    for LIndex := 0 to High(LTrack.Windows) do
    begin
      LRow := TJSONObject.Create;
      LRows.Add(LRow);
      LRow.Add('owner_start_frame', LTrack.Windows[LIndex].OwnerStartFrame);
      LRow.Add('owner_end_frame', LTrack.Windows[LIndex].OwnerEndFrame);
      LRow.Add('selected_candidate', LTrack.Windows[LIndex].SelectedCandidate);
      LRow.Add('starts_new_path', LTrack.Windows[LIndex].StartsNewPath);
      LRow.Add('join_gap_ratio', LTrack.Windows[LIndex].JoinGapRatio);
      LRow.Add('join_uncertain', LTrack.Windows[LIndex].JoinUncertain);
      if LTrack.Windows[LIndex].SelectedCandidate >= 0 then
      begin
        LRow.Add('bpm', LTrack.Windows[LIndex].Analysis.Candidates[
          LTrack.Windows[LIndex].SelectedCandidate].Bpm);
      end;
    end;
    WriteLn(CNames[ACase], ' tracked: ', LMetrics.Integers['matches'], '/',
      Length(LTruth), ' beats; ', LMetrics.Integers['false_positives'],
      ' extra points; ', LTrack.SeamIssues, ' uncertain joins');
    Check((LMetrics.Integers['matches'] = Length(LTruth)) and
      (LMetrics.Integers['false_positives'] = 0), 'Tracked authored WAV clock regressed');
    WriteTextFile(LPath + '.json', LDocument.FormatJSON);
  finally
    LDocument.Free;
    LDecoded.Free;
    LOriginal.Free;
  end;
end;

var
  LCase: Integer;
begin
  try
    if ParamCount <> 1 then
    begin
      raise EAudio.Create('Usage: pythian.beat.lab OUTPUT_PREFIX');
    end;
    for LCase := 0 to High(CNames) do
    begin
      RunCase(ParamStr(1), LCase);
    end;
  except
    on LError: Exception do
    begin
      WriteLn(StdErr, LError.Message);
      Halt(1);
    end;
  end;
end.
