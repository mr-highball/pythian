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
program pythian_phrase_wav;

{$mode delphi}
{$H+}

uses
  Classes, SysUtils, Math, fpjson,
  pythian.audio, pythian.time, pythian.pitch, pythian.pitch.track,
  pythian.pitch.evaluate, pythian.resample, pythian.synth, pythian.synth.stream,
  pythian.oscillator, pythian.wave.stream, pythian.hash, pythian.tools.files,
  pythian.pitch.regions, pythian.analysis, pythian.activity, pythian.onset,
  pythian.onset.events;

const
  CRate = 8000;

function ReadReferences(const APath: String; out AHash: String): TPitchReferenceNotes;
var
  LBytes: TAudioBytes;
  LText: String;
  LLines: TStringList;
  LFields: TStringList;
  LFormat: TFormatSettings;
  LStart: Double;
  LDuration: Double;
  LFrequency: Double;
  LCount: Integer;
  LIndex: Integer;
begin
  LBytes := ReadFileBytes(APath, 2 * 1024 * 1024);
  AHash := HashAudioBytes(LBytes);
  SetLength(LText, Length(LBytes));
  if Length(LBytes) > 0 then
  begin
    Move(LBytes[0], LText[1], Length(LBytes));
  end;
  LLines := TStringList.Create;
  LFields := TStringList.Create;
  try
    LLines.Text := LText;
    LFormat := DefaultFormatSettings;
    LFormat.DecimalSeparator := '.';
    LCount := 0;
    Result := nil;
    SetLength(Result, Min(LLines.Count, MaximumPitchReferenceNotes));
    for LIndex := 0 to LLines.Count - 1 do
    begin
      LText := Trim(LLines[LIndex]);
      if LText = '' then
      begin
        Continue;
      end;
      if LCount = MaximumPitchReferenceNotes then
      begin
        raise EAudio.Create('Reference notes exceed count budget');
      end;
      LFields.Clear;
      ExtractStrings([' ', #9], [], PChar(LText), LFields);
      if (LFields.Count <> 3) or not TryStrToFloat(LFields[0], LStart, LFormat) or
        not TryStrToFloat(LFields[1], LFrequency, LFormat) or
        not TryStrToFloat(LFields[2], LDuration, LFormat) then
      begin
        raise EAudio.Create('Reference rows require onset seconds, pitch Hz and duration seconds');
      end;
      RequireFinite(LStart, 'Reference onset');
      RequireFinite(LFrequency, 'Reference frequency');
      RequireFinite(LDuration, 'Reference duration');
      if (LStart < 0) or (LDuration <= 0) or (LFrequency <= 0) then
      begin
        raise EAudio.Create('Reference values require nonnegative onset and positive pitch/duration');
      end;
      Result[LCount].StartFrame := SampleFramesFromSeconds(LStart, CRate, frFloor);
      Result[LCount].EndFrame := SampleFramesFromSeconds(LStart + LDuration, CRate, frCeiling);
      Result[LCount].Note := Floor(69 + 12 * Log2(LFrequency / 440) + 0.5);
      Inc(LCount);
    end;
    SetLength(Result, LCount);
    if LCount = 0 then
    begin
      raise EAudio.Create('Reference file contains no notes');
    end;
  finally
    LFields.Free;
    LLines.Free;
  end;
end;

function WriteClip(const APath: String; const AClip: TAudioClip): String;
var
  LStream: TFileStream;
begin
  LStream := TFileStream.Create(APath, fmCreate);
  try
    WriteWavePcm16(LStream, AClip);
    LStream.Position := 0;
    Result := Sha256Stream(LStream, LStream.Size);
  finally
    LStream.Free;
  end;
end;

function WriteNotes(const APath: String; const ANotes: TPitchReferenceNotes;
  const ASourceStart: Int64; const AFrameCount: Integer): String;
var
  LTones: TFrameTones;
  LReader: TFrameToneStream;
  LStream: TFileStream;
  LSink: TStreamAudioSink;
  LWriter: TWavePcm16Writer;
  LSamples: TAudioSamples;
  LIndex: Integer;
begin
  SetLength(LTones, Length(ANotes));
  for LIndex := 0 to High(LTones) do
  begin
    LTones[LIndex].StartFrame := ANotes[LIndex].StartFrame - ASourceStart;
    LTones[LIndex].GateFrames := ANotes[LIndex].EndFrame - ANotes[LIndex].StartFrame;
    LTones[LIndex].FrequencyHz := MidiFrequency(ANotes[LIndex].Note);
    LTones[LIndex].Velocity := 1;
    LTones[LIndex].Voice := DefaultSynthVoice;
    LTones[LIndex].Voice.Shape := wsSine;
    LTones[LIndex].Voice.Gain := 0.2;
    LTones[LIndex].Voice.Envelope.AttackSeconds := 0.003;
    LTones[LIndex].Voice.Envelope.ReleaseSeconds := 0;
  end;
  LReader := TFrameToneStream.Create(LTones, CRate, AFrameCount);
  LStream := nil;
  LSink := nil;
  LWriter := nil;
  try
    LStream := TFileStream.Create(APath, fmCreate);
    LSink := TStreamAudioSink.Create(LStream);
    LWriter := TWavePcm16Writer.Create(LSink, CRate, 2, LReader.FrameCount);
    while LReader.ReadSamples(2048, LSamples) do
    begin
      LWriter.AppendSamples(LSamples);
    end;
    LWriter.Finish;
    LStream.Position := 0;
    Result := Sha256Stream(LStream, LStream.Size);
  finally
    LWriter.Free;
    LSink.Free;
    LStream.Free;
    LReader.Free;
  end;
end;

function WriteRuns(const APath: String; const ATrack: TPitchTrack): String;
var
  LNotes: TPitchReferenceNotes;
  LRun: TPitchRun;
  I: Integer;
begin
  SetLength(LNotes, ATrack.RunCount);
  for I := 0 to High(LNotes) do
  begin
    LRun := ATrack.RunAt(I);
    LNotes[I].StartFrame := LRun.StartFrame;
    LNotes[I].EndFrame := LRun.EndFrame;
    LNotes[I].Note := LRun.Note;
  end;
  Result := WriteNotes(APath, LNotes, 0, ATrack.FrameCount);
end;

procedure AddRegionStudy(const AClip: TAudioClip; const ATrack: TPitchTrack;
  const AReferences: TPitchReferenceNotes; const ASourceStart: Int64;
  const ADocument: TJSONObject; out AOnsetNotes, AGatedNotes: TPitchReferenceNotes);
var
  LStudies: TJSONArray;
  LRegions: TPitchRegions;
  LAnalysis: TAnalysisOptions;
  LActivity: TActivityOptions;
  LLocationOptions: TOnsetLocationOptions;
  LEventOptions: TOnsetEventOptions;
  LBoundaryPolicy: TJSONObject;
  LFeatures: TAudioFeatures;
  LLocations: TOnsetLocations;
  LPlan: TOnsetEventPlan;
  LCount: Integer;
  LSkipped: Integer;
  I: Integer;

  procedure Summarize(const AName: String; const AUsesReferenceBounds,
    AEndGated: Boolean);
  var
    LSummary: TPitchRegionSummaries;
    LActual: TPitchReferenceNotes;
    LScore: TPitchNoteEvaluation;
    LFrames: TPitchIntervalFrameEvaluation;
    LFrameReport: TJSONObject;
    LStudy: TJSONObject;
    LRows: TJSONArray;
    LVotes: TJSONArray;
    LRow: TJSONObject;
    LVote: TJSONObject;
    LGate: TPitchRegion;
    LActualCount: Integer;
    LIndex: Integer;
    LVoteIndex: Integer;
  begin
    LSummary := SummarizePitchRegions(ATrack, LRegions, DefaultPitchRegionOptions);
    SetLength(LActual, Length(LSummary));
    LActualCount := 0;
    LStudy := TJSONObject.Create;
    LStudies.Add(LStudy);
    LStudy.Add('condition', AName);
    LStudy.Add('annotation_boundaries_used', AUsesReferenceBounds);
    LStudy.Add('end_at_last_support_bin', AEndGated);
    LStudy.Add('end_padding_frames', 0);
    LStudy.Add('quality_admitted', False);
    LStudy.Add('region_count', Length(LSummary));
    LRows := TJSONArray.Create;
    LStudy.Add('regions', LRows);
    for LIndex := 0 to High(LSummary) do
    begin
      LRow := TJSONObject.Create;
      LRows.Add(LRow);
      LRow.Add('start_frame', LSummary[LIndex].Region.StartFrame);
      LRow.Add('end_frame', LSummary[LIndex].Region.EndFrame);
      LRow.Add('candidate_note', LSummary[LIndex].CandidateNote);
      LRow.Add('note', LSummary[LIndex].Note);
      LRow.Add('decision', Ord(LSummary[LIndex].Decision));
      LRow.Add('periodic_coverage', LSummary[LIndex].PeriodicCoverage);
      LRow.Add('raw_admitted_windows', LSummary[LIndex].RawAdmittedWindows);
      LVotes := TJSONArray.Create;
      LRow.Add('votes', LVotes);
      for LVoteIndex := 0 to High(LSummary[LIndex].Votes) do
      begin
        LVote := TJSONObject.Create;
        LVotes.Add(LVote);
        LVote.Add('note', LSummary[LIndex].Votes[LVoteIndex].Note);
        LVote.Add('windows', LSummary[LIndex].Votes[LVoteIndex].WindowCount);
        LVote.Add('support_start_frame', LSummary[LIndex].Votes[LVoteIndex].SupportStartFrame);
        LVote.Add('support_end_frame', LSummary[LIndex].Votes[LVoteIndex].SupportEndFrame);
        LVote.Add('energy_share', LSummary[LIndex].Votes[LVoteIndex].EnergyShare);
        LVote.Add('mean_cents', LSummary[LIndex].Votes[LVoteIndex].MeanCents);
        LVote.Add('cents_deviation', LSummary[LIndex].Votes[LVoteIndex].CentsDeviation);
      end;
      if LSummary[LIndex].Note >= 0 then
      begin
        LGate := LSummary[LIndex].Region;
        if AEndGated then
        begin
          LGate := GatePitchRegion(LSummary[LIndex]);
        end;
        LRow.Add('note_start_frame', LGate.StartFrame);
        LRow.Add('note_end_frame', LGate.EndFrame);
        LActual[LActualCount].StartFrame := ASourceStart + LGate.StartFrame;
        LActual[LActualCount].EndFrame := ASourceStart + LGate.EndFrame;
        LActual[LActualCount].Note := LSummary[LIndex].Note;
        Inc(LActualCount);
      end;
    end;
    SetLength(LActual, LActualCount);
    if not AUsesReferenceBounds then
    begin
      if AEndGated then
      begin
        AGatedNotes := LActual;
      end
      else
      begin
        AOnsetNotes := LActual;
      end;
    end;
    LScore := EvaluatePitchNoteIntervals(LActual, AReferences, ASourceStart,
      ASourceStart + AClip.FrameCount, DefaultPitchEvaluationOptions(AClip.SampleRate));
    LFrames := EvaluatePitchIntervalFrames(ATrack, LActual, AReferences, ASourceStart);
    LFrameReport := TJSONObject.Create;
    LStudy.Add('frame_evaluation', LFrameReport);
    LFrameReport.Add('policy', 'Inferred intervals at unchanged raw window centers; gaps are unknown, reference overlaps excluded, no edge exclusion');
    LFrameReport.Add('window_count', LFrames.WindowCount);
    LFrameReport.Add('reference_active', LFrames.ReferenceActive);
    LFrameReport.Add('reference_rest', LFrames.ReferenceRest);
    LFrameReport.Add('reference_ambiguous', LFrames.ReferenceAmbiguous);
    LFrameReport.Add('reference_outside_range', LFrames.ReferenceOutsideRange);
    LFrameReport.Add('correct_pitch', LFrames.CorrectPitch);
    LFrameReport.Add('wrong_pitch', LFrames.WrongPitch);
    LFrameReport.Add('wrong_octave', LFrames.WrongOctave);
    LFrameReport.Add('unknown_active', LFrames.UnknownActive);
    LFrameReport.Add('false_pitch_in_rest', LFrames.FalsePitchInRest);
    LFrameReport.Add('unknown_rest', LFrames.UnknownRest);
    LFrameReport.Add('ambiguous_admitted', LFrames.AmbiguousAdmitted);
    LFrameReport.Add('pitch_coverage', LFrames.PitchCoverage);
    LFrameReport.Add('pitch_precision', LFrames.PitchPrecision);
    LStudy.Add('reference_notes', LScore.ReferenceNotes);
    LStudy.Add('estimated_notes', LScore.EstimatedNotes);
    LStudy.Add('matched_onsets', LScore.MatchedOnsets);
    LStudy.Add('matched_notes', LScore.MatchedNotes);
    LStudy.Add('matched_onset_error_frames', LScore.MatchedOnsetErrorFrames);
    LStudy.Add('matched_offset_error_frames', LScore.MatchedOffsetErrorFrames);
    LStudy.Add('onset_f1', NoteF1(LScore.MatchedOnsets, LScore.ReferenceNotes,
      LScore.EstimatedNotes));
    LStudy.Add('note_f1', NoteF1(LScore.MatchedNotes, LScore.ReferenceNotes,
      LScore.EstimatedNotes));
    WriteLn(AName, ': notes=', LScore.EstimatedNotes,
      ' matched=', LScore.MatchedNotes, '/', LScore.ReferenceNotes,
      ' onset F1=', NoteF1(LScore.MatchedOnsets, LScore.ReferenceNotes,
        LScore.EstimatedNotes):0:4,
      ' note F1=', NoteF1(LScore.MatchedNotes, LScore.ReferenceNotes,
        LScore.EstimatedNotes):0:4,
      ' coverage=', LFrames.PitchCoverage:0:4,
      ' precision=', LFrames.PitchPrecision:0:4,
      ' false-rest=', LFrames.FalsePitchInRest);
  end;

begin
  AOnsetNotes := nil;
  AGatedNotes := nil;
  LStudies := TJSONArray.Create;
  ADocument.Add('region_study', LStudies);
  ADocument.Add('region_policy', 'Separate hypotheses from raw periodic evidence; minimum 3 periodic windows, 50 percent window coverage, 75 percent RMS-squared energy share, mean tuning within 25 cents; no raw evidence changes');
  ADocument.Add('region_study_limit', 'Reference-boundary condition isolates within-note inference and is not end-to-end accuracy; detected conditions use existing detector bounds with optional last-support-bin endings, neither establishes physical offsets. No study condition is admitted for style learning.');
  SetLength(LRegions, Length(AReferences));
  LCount := 0;
  LSkipped := 0;
  for I := 0 to High(AReferences) do
  begin
    if (AReferences[I].StartFrame < ASourceStart) or
      (AReferences[I].EndFrame > ASourceStart + AClip.FrameCount) then
    begin
      Continue;
    end;
    if (LCount > 0) and
      (AReferences[I].StartFrame - ASourceStart < LRegions[LCount - 1].EndFrame) then
    begin
      Inc(LSkipped);
      Continue;
    end;
    LRegions[LCount].StartFrame := AReferences[I].StartFrame - ASourceStart;
    LRegions[LCount].EndFrame := AReferences[I].EndFrame - ASourceStart;
    Inc(LCount);
  end;
  SetLength(LRegions, LCount);
  ADocument.Add('region_reference_overlaps_skipped', LSkipped);
  Summarize('reference-boundary diagnostic', True, False);
  LAnalysis := DefaultOnsetAnalysisOptions(AClip.SampleRate);
  LActivity := DefaultActivityOptions;
  LLocationOptions := DefaultOnsetLocationOptions(AClip.SampleRate);
  LEventOptions := DefaultOnsetEventOptions(AClip.SampleRate);
  LBoundaryPolicy := TJSONObject.Create;
  ADocument.Add('region_boundary_policy', LBoundaryPolicy);
  LBoundaryPolicy.Add('analysis_window_frames', LAnalysis.WindowFrames);
  LBoundaryPolicy.Add('analysis_hop_frames', LAnalysis.HopFrames);
  LBoundaryPolicy.Add('analysis_silence_rms', LAnalysis.SilenceRms);
  LBoundaryPolicy.Add('minimum_flux', LActivity.MinimumFlux);
  LBoundaryPolicy.Add('adaptive_multiplier', LActivity.AdaptiveMultiplier);
  LBoundaryPolicy.Add('history_features', LActivity.HistoryFeatures);
  LBoundaryPolicy.Add('peak_radius', LActivity.PeakRadius);
  LBoundaryPolicy.Add('minimum_separation_features', LActivity.MinimumSeparationFeatures);
  LBoundaryPolicy.Add('maximum_segment_features', LActivity.MaximumSegmentFeatures);
  LBoundaryPolicy.Add('energy_window_frames', LLocationOptions.EnergyWindowFrames);
  LBoundaryPolicy.Add('minimum_energy_rise', LLocationOptions.MinimumEnergyRise);
  LBoundaryPolicy.Add('minimum_contrast', LLocationOptions.MinimumContrast);
  LBoundaryPolicy.Add('minimum_region_frames', LEventOptions.MinimumFrames);
  LBoundaryPolicy.Add('allow_clipped_context', LEventOptions.AllowClippedContext);
  LBoundaryPolicy.Add('allow_search_boundary', LEventOptions.AllowSearchBoundary);
  LFeatures := AnalyzeAudio(AClip, LAnalysis);
  LLocations := LocalizeAcousticOnsets(AClip, LFeatures, LAnalysis,
    LActivity, LLocationOptions);
  LPlan := PlanOnsetEvents(LLocations, AClip.FrameCount, LEventOptions);
  SetLength(LRegions, Length(LPlan.Bounds) - 1);
  for I := 0 to High(LRegions) do
  begin
    LRegions[I].StartFrame := LPlan.Bounds[I];
    LRegions[I].EndFrame := LPlan.Bounds[I + 1];
  end;
  Summarize('detected-onset regions', False, False);
  Summarize('detected-onset gated regions', False, True);
end;

procedure Run;
var
  LOriginal: TAudioClip;
  LExcerpt: TAudioClip;
  LClip: TAudioClip;
  LSamples: TAudioSamples;
  LTrack: TPitchTrack;
  LReferences: TPitchReferenceNotes;
  LOnsetNotes: TPitchReferenceNotes;
  LGatedNotes: TPitchReferenceNotes;
  LEvaluation: TPitchEvaluation;
  LEvalOptions: TPitchEvaluationOptions;
  LPitchOptions: TPitchTrackOptions;
  LDocument: TJSONObject;
  LRows: TJSONArray;
  LRow: TJSONObject;
  LSpans: TPitchSpans;
  LSourceHash: String;
  LReferenceHash: String;
  LOutputs: array[0..4] of String;
  LStartSeconds: Double;
  LSeconds: Double;
  LStartFrame: Int64;
  LCountFrames: Int64;
  LOutputStart: Int64;
  LFormat: TFormatSettings;
  LWindow: Integer;
  LPass: Boolean;
  LRegionStudy: Boolean;
  I: Integer;
  J: Integer;

  function Ratio(const ANumerator, ADenominator: Integer): Double;
  begin
    Result := 0;
    if ADenominator > 0 then
    begin
      Result := ANumerator / ADenominator;
    end;
  end;

begin
  LOriginal := nil;
  LExcerpt := nil;
  LClip := nil;
  LTrack := nil;
  LDocument := nil;
  try
    LRegionStudy := (ParamCount >= 6) and (ParamStr(ParamCount) = '--region-study');
    LOutputs[0] := ParamStr(3) + '.json';
    LOutputs[1] := ParamStr(3) + '.source.wav';
    LOutputs[2] := ParamStr(3) + '.estimated.wav';
    LOutputs[3] := ParamStr(3) + '.regions.wav';
    LOutputs[4] := ParamStr(3) + '.gated.wav';
    for I := 0 to 2 + 2 * Ord(LRegionStudy) do
    begin
      for J := 1 to 2 do
      begin
        if SameFileName(ExpandFileName(LOutputs[I]), ExpandFileName(ParamStr(J))) then
        begin
          raise EAudio.Create('Phrase outputs must differ from both inputs');
        end;
      end;
    end;
    LFormat := DefaultFormatSettings;
    LFormat.DecimalSeparator := '.';
    LStartSeconds := StrToFloat(ParamStr(4), LFormat);
    LSeconds := StrToFloat(ParamStr(5), LFormat);
    LWindow := 0;
    if (ParamCount >= 6) and (ParamStr(6) <> '--region-study') then
    begin
      LWindow := StrToInt(ParamStr(6));
    end;
    if (ParamCount = 7) and (not LRegionStudy or (ParamStr(6) = '--region-study')) then
    begin
      raise EAudio.Create('Expected --region-study after the optional window size');
    end;
    LOriginal := LoadWaveSource(ParamStr(1), LSourceHash);
    if LOriginal.Channels <> 1 then
    begin
      raise EAudio.Create('Phrase reference evaluation requires an isolated mono part');
    end;
    LStartFrame := SampleFramesFromSeconds(LStartSeconds, LOriginal.SampleRate, frFloor);
    LCountFrames := SampleFramesFromSeconds(LSeconds, LOriginal.SampleRate, frFloor);
    if (LCountFrames < 1) or (LStartFrame > LOriginal.FrameCount) or
      (LCountFrames > LOriginal.FrameCount - LStartFrame) then
    begin
      raise EAudio.Create('Phrase excerpt lies outside the complete source recording');
    end;
    SetLength(LSamples, LCountFrames);
    for I := 0 to High(LSamples) do
    begin
      LSamples[I] := LOriginal.SampleAt(LStartFrame + I, 0);
    end;
    LExcerpt := TAudioClip.Create(LOriginal.SampleRate, 1, LSamples);
    LSamples := nil;
    LOutputStart := LStartFrame * CRate div LOriginal.SampleRate;
    LClip := ResampleClip(LExcerpt, CRate);
    LReferences := ReadReferences(ParamStr(2), LReferenceHash);
    LPitchOptions := DefaultPitchTrackOptions(CRate);
    LTrack := TPitchTrack.Create(LClip, 0, LPitchOptions, LWindow);
    LEvalOptions := DefaultPitchEvaluationOptions(CRate);
    LEvaluation := EvaluatePitchTrack(LTrack, LReferences, LOutputStart, LEvalOptions);
    LDocument := TJSONObject.Create;
    LDocument.Add('contract', 'pythian.phrase.evaluation');
    LDocument.Add('source_sha256', LSourceHash);
    LDocument.Add('reference_sha256', LReferenceHash);
    LDocument.Add('source_rate', LOriginal.SampleRate);
    LDocument.Add('source_start_frame', LStartFrame);
    LDocument.Add('source_frame_count', LCountFrames);
    LDocument.Add('analysis_rate', CRate);
    LDocument.Add('analysis_start_frame', LOutputStart);
    LDocument.Add('analysis_frame_count', LClip.FrameCount);
    LDocument.Add('reference_policy', 'URMP onset seconds / pitch Hz / duration seconds; floor onset, ceil offset; nearest equal-tempered MIDI');
    LDocument.Add('frame_policy', 'Stable span labels at window centers; ambiguous reference overlap excluded; references never enter estimator');
    LDocument.Add('note_policy', 'Maximum ordered one-to-one semitone matches; onset 50 ms; offset max(50 ms, 20 percent duration); common 110 ms edge exclusion');
    LDocument.Add('window_frames', LTrack.WindowFrames);
    LDocument.Add('hop_frames', LPitchOptions.HopFrames);
    LDocument.Add('minimum_run_windows', LPitchOptions.MinimumRunWindows);
    LDocument.Add('maximum_cents', LPitchOptions.MaximumCents);
    LDocument.Add('minimum_hz', LPitchOptions.Pitch.MinimumHz);
    LDocument.Add('maximum_hz', LPitchOptions.Pitch.MaximumHz);
    LDocument.Add('difference_threshold', LPitchOptions.Pitch.DifferenceThreshold);
    LDocument.Add('silence_rms', LPitchOptions.Pitch.SilenceRms);
    LDocument.Add('window_count', LEvaluation.WindowCount);
    LDocument.Add('reference_active', LEvaluation.ReferenceActive);
    LDocument.Add('reference_rest', LEvaluation.ReferenceRest);
    LDocument.Add('reference_ambiguous', LEvaluation.ReferenceAmbiguous);
    LDocument.Add('reference_outside_range', LEvaluation.ReferenceOutsideRange);
    LDocument.Add('correct_pitch', LEvaluation.CorrectPitch);
    LDocument.Add('wrong_pitch', LEvaluation.WrongPitch);
    LDocument.Add('wrong_octave', LEvaluation.WrongOctave);
    LDocument.Add('unknown_active', LEvaluation.UnknownActive);
    LDocument.Add('unknown_no_period', LEvaluation.UnknownNoPeriod);
    LDocument.Add('unknown_outside_range', LEvaluation.UnknownOutsideRange);
    LDocument.Add('unknown_tuning', LEvaluation.UnknownTuning);
    LDocument.Add('unknown_short_run', LEvaluation.UnknownShortRun);
    LDocument.Add('silence_active', LEvaluation.SilenceActive);
    LDocument.Add('false_pitch_in_rest', LEvaluation.FalsePitchInRest);
    LDocument.Add('unknown_rest', LEvaluation.UnknownRest);
    LDocument.Add('silence_rest', LEvaluation.SilenceRest);
    LDocument.Add('ambiguous_admitted', LEvaluation.AmbiguousAdmitted);
    LDocument.Add('pitch_coverage', PitchCoverage(LEvaluation));
    LDocument.Add('pitch_precision', PitchPrecision(LEvaluation));
    LDocument.Add('reference_notes', LEvaluation.ReferenceNotes);
    LDocument.Add('estimated_notes', LEvaluation.EstimatedNotes);
    LDocument.Add('consecutive_repeated_references', LEvaluation.ConsecutiveRepeatedReferences);
    LDocument.Add('matched_onsets', LEvaluation.MatchedOnsets);
    LDocument.Add('matched_notes', LEvaluation.MatchedNotes);
    LDocument.Add('onset_precision', Ratio(LEvaluation.MatchedOnsets, LEvaluation.EstimatedNotes));
    LDocument.Add('onset_recall', Ratio(LEvaluation.MatchedOnsets, LEvaluation.ReferenceNotes));
    LDocument.Add('onset_f1', NoteF1(LEvaluation.MatchedOnsets,
      LEvaluation.ReferenceNotes, LEvaluation.EstimatedNotes));
    LDocument.Add('note_precision', Ratio(LEvaluation.MatchedNotes, LEvaluation.EstimatedNotes));
    LDocument.Add('note_recall', Ratio(LEvaluation.MatchedNotes, LEvaluation.ReferenceNotes));
    LDocument.Add('note_f1', NoteF1(LEvaluation.MatchedNotes,
      LEvaluation.ReferenceNotes, LEvaluation.EstimatedNotes));
    LDocument.Add('matched_onset_error_frames', LEvaluation.MatchedOnsetErrorFrames);
    LDocument.Add('matched_offset_error_frames', LEvaluation.MatchedOffsetErrorFrames);
    LPass := (PitchCoverage(LEvaluation) >= 0.8) and
      (PitchPrecision(LEvaluation) >= 0.98) and
      (NoteF1(LEvaluation.MatchedOnsets, LEvaluation.ReferenceNotes,
        LEvaluation.EstimatedNotes) >= 0.8) and
      (NoteF1(LEvaluation.MatchedNotes, LEvaluation.ReferenceNotes,
        LEvaluation.EstimatedNotes) >= 0.7);
    LDocument.Add('meets_declared_targets', LPass);
    if LRegionStudy then
    begin
      AddRegionStudy(LClip, LTrack, LReferences, LOutputStart, LDocument,
        LOnsetNotes, LGatedNotes);
    end;
    LRows := TJSONArray.Create;
    LDocument.Add('spans', LRows);
    LSpans := LTrack.CopySpans;
    for I := 0 to High(LSpans) do
    begin
      LRow := TJSONObject.Create;
      LRows.Add(LRow);
      LRow.Add('kind', Ord(LSpans[I].Kind));
      LRow.Add('note', LSpans[I].Note);
      LRow.Add('start_frame', LSpans[I].StartFrame);
      LRow.Add('end_frame', LSpans[I].EndFrame);
    end;
    LDocument.Add('excerpt_sha256', WriteClip(LOutputs[1], LClip));
    LDocument.Add('estimated_audio_sha256', WriteRuns(LOutputs[2], LTrack));
    if LRegionStudy then
    begin
      LDocument.Add('region_audio_policy', 'Diagnostic sine notes from detected-onset regions only; inferred notes occupy whole candidate intervals, so physical offsets/rests remain unproven; no annotation boundaries used in this audio');
      LDocument.Add('region_audio_sha256', WriteNotes(LOutputs[3], LOnsetNotes,
        LOutputStart, LClip.FrameCount));
      LDocument.Add('gated_audio_policy', 'Diagnostic sine notes retain detected attacks and end at the last supporting center-aligned hop bin, clipped to the candidate interval, with zero padding; unknown gaps are not proven silence; no annotation boundaries used');
      LDocument.Add('gated_audio_sha256', WriteNotes(LOutputs[4], LGatedNotes,
        LOutputStart, LClip.FrameCount));
    end;
    WriteTextFile(LOutputs[0], LDocument.FormatJSON);
    WriteLn('Phrase: coverage=', PitchCoverage(LEvaluation):0:4,
      ' precision=', PitchPrecision(LEvaluation):0:4,
      ' onset F1=', NoteF1(LEvaluation.MatchedOnsets, LEvaluation.ReferenceNotes,
        LEvaluation.EstimatedNotes):0:4,
      ' note F1=', NoteF1(LEvaluation.MatchedNotes, LEvaluation.ReferenceNotes,
        LEvaluation.EstimatedNotes):0:4, ' accepted=', LPass);
  finally
    LDocument.Free;
    LTrack.Free;
    LClip.Free;
    LExcerpt.Free;
    LOriginal.Free;
  end;
end;

begin
  try
    if not (ParamCount in [5, 6, 7]) then
    begin
      raise EAudio.Create('Usage: pythian.phrase.wav SOURCE.wav NOTES.txt OUTPUT_PREFIX START_SECONDS LENGTH_SECONDS [WINDOW_FRAMES] [--region-study]');
    end;
    Run;
  except
    on LException: Exception do
    begin
      WriteLn(StdErr, LException.ClassName, ': ', LException.Message);
      Halt(1);
    end;
  end;
end.
