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
program pythian.timed.remix;

{$mode delphi}
{$H+}

uses
  SysUtils,
  fpjson,
  pythian.audio,
  pythian.wave,
  pythian.time,
  pythian.music,
  pythian.midi.smf,
  pythian.midi.notes,
  pythian.alignment,
  pythian.articulation,
  pythian.activity,
  pythian.corpus,
  pythian.corpus.archive,
  pythian.continuity,
  pythian.granular,
  pythian.wfc.generation,
  pythian.wfc.joint,
  pythian.wfc.joint.archive,
  pythian.wfc.timing,
  pythian.tools.files,
  pythian.tools.sources,
  wfc,
  wfc_sequence,
  wfc_sequence_text;

procedure ProtectInput(const AInput, AOutput: String);
begin
  if SameFileName(ExpandFileName(AInput), ExpandFileName(AOutput)) or
    SameFileName(ExpandFileName(AInput), ExpandFileName(AOutput + '.json')) or
    SameFileName(ExpandFileName(AInput + '.json'), ExpandFileName(AOutput)) then
  begin
    raise EAudio.Create('Timed remix output must differ from every input and its sidecar');
  end;
end;

function ReadArticulation(const ASampleRate: Integer;
  const ADocument: TJSONObject): TArticulationPlan;
var
  LTempos: TTempoChanges;
  LClock: TTempoMap;
  LSequence: TNoteSequence;
  LBytes: TAudioBytes;
  LMidi: TMidiBytes;
  LImport: TMidiNoteReport;
  LTempo: Integer;
  LGrid: Integer;
  LPattern: String;
  LLength: Int64;
  LOmitted: Integer;
  LAttack: Integer;
  LRelease: Integer;
  LPlan: TArticulationPlan;
begin
  LPlan := nil;
  try
    LAttack := (ASampleRate + 199) div 200;
    LRelease := (ASampleRate + 99) div 100;
    ADocument.Add('attack_frames', LAttack);
    ADocument.Add('release_frames', LRelease);
    ADocument.Add('articulation_version', ArticulationVersion);
    if ParamStr(4) = 'grid' then
    begin
      LTempo := StrToInt(ParamStr(5));
      LGrid := StrToInt(ParamStr(6));
      LPattern := ParamStr(7);
      if (LGrid < 1) or (Length(LPattern) < 1) or
        (Length(LPattern) > MaximumArticulationGates) then
      begin
        raise EAudio.Create('Timed grid or pattern exceeds its bounds');
      end;
      LLength := Int64(LGrid) * Length(LPattern);
      if LLength > High(Integer) then
      begin
        raise EAudio.Create('Timed grid exceeds PPQ tick range');
      end;
      SetLength(LTempos, 1);
      LTempos[0] := MakeTempoChange(0, LTempo);
      LClock := TTempoMap.Create(480, LLength, LTempos);
      try
        LPlan := PlanGridArticulation(LClock, 0, LGrid, LPattern,
          ASampleRate, LAttack, LRelease);
      finally
        LClock.Free;
      end;
      ADocument.Add('ticks_per_quarter', 480);
      ADocument.Add('microseconds_per_quarter', LTempo);
      ADocument.Add('grid_ticks', LGrid);
      ADocument.Add('pattern', LPattern);
    end
    else
    begin
      LBytes := ReadFileBytes(ParamStr(5), DefaultMidiReadLimits.MaxFileBytes);
      ADocument.Add('midi_sha256', HashAudioBytes(LBytes));
      LMidi := nil;
      SetLength(LMidi, Length(LBytes));
      if Length(LMidi) > 0 then
      begin
        Move(LBytes[0], LMidi[0], Length(LMidi));
      end;
      LSequence := DecodeMidiNotes(LMidi, DefaultMidiNoteOptions, LImport);
      try
        LPlan := PlanNoteArticulation(LSequence, ASampleRate, LAttack, LRelease, LOmitted);
        ADocument.Add('ticks_per_quarter', LSequence.TicksPerQuarter);
        ADocument.Add('source_notes', LSequence.NoteCount);
        ADocument.Add('sub_frame_notes', LOmitted);
        ADocument.Add('ignored_metadata_events', LImport.IgnoredMetadataEvents);
        ADocument.Add('discarded_release_velocities', LImport.DiscardedReleaseVelocities);
        ADocument.Add('zero_length_notes', LImport.ZeroLengthNotes);
        ADocument.Add('used_default_tempo', LImport.UsedDefaultTempo);
      finally
        LSequence.Free;
      end;
    end;
    Result := LPlan;
    LPlan := nil;
  finally
    LPlan.Free;
  end;
end;

procedure Run;
var
  LBytes: TAudioBytes;
  LPaths: array of String;
  LSources: TAudioSources;
  LCorpus: TAcousticCorpusData;
  LModel: TWfcSequenceModel;
  LActivity: TActivityOptions;
  LArticulation: TArticulationPlan;
  LAttackPlan: TJointAttackPlan;
  LGeneration: TAcousticGenerationOptions;
  LSequence: TJointSequence;
  LSolve: TGraphSolveReport;
  LPlanner: TCorpusGrainPlanner;
  LPlanOptions: TContinuityOptions;
  LContinuity: TContinuityReport;
  LGrains: TAudioGrains;
  LRenderOptions: TGrainRenderOptions;
  LRendered: TAudioClip;
  LOutput: TAudioClip;
  LDocument: TJSONObject;
  LTiming: TJSONObject;
  LPolicy: TJSONObject;
  LItems: TJSONArray;
  LItem: TJSONObject;
  LInfo: TAcousticSourceInfo;
  LGate: TArticulationGate;
  LIndex: Integer;
  LFirstSource: Integer;
  LMaximumError: Integer;
  LSeed: QWord;
  LJson: String;
begin
  if (ParamCount < 7) or not ((ParamStr(4) = 'grid') or (ParamStr(4) = 'midi')) then
  begin
    raise EAudio.Create('Usage: pythian.timed.remix INPUT.pyac OUTPUT.wav SEED ' +
      'grid MICROSECONDS_PER_QUARTER GRID_TICKS PATTERN MAX_ERROR_FRAMES SOURCE.wav... ' +
      'or INPUT.pyac OUTPUT.wav SEED midi INPUT.mid MAX_ERROR_FRAMES SOURCE.wav...');
  end;
  LFirstSource := 7;
  if ParamStr(4) = 'grid' then
  begin
    LFirstSource := 9;
  end
  else
  begin
    ProtectInput(ParamStr(5), ParamStr(2));
  end;
  if ParamCount < LFirstSource then
  begin
    raise EAudio.Create('Timed remix requires timing arguments and source WAV files');
  end;
  ProtectInput(ParamStr(1), ParamStr(2));
  LMaximumError := StrToInt(ParamStr(LFirstSource - 1));
  if not TryStrToQWord(ParamStr(3), LSeed) or (LSeed > High(TGraphSeed)) then
  begin
    raise EAudio.Create('Timed remix seed must fit the WFC seed type');
  end;
  SetLength(LPaths, ParamCount - LFirstSource + 1);
  for LIndex := 0 to High(LPaths) do
  begin
    LPaths[LIndex] := ParamStr(LFirstSource + LIndex);
    ProtectInput(LPaths[LIndex], ParamStr(2));
  end;
  LCorpus := nil;
  LModel := nil;
  LArticulation := nil;
  LRendered := nil;
  LOutput := nil;
  LSources := nil;
  LDocument := TJSONObject.Create;
  try
    LBytes := ReadFileBytes(ParamStr(1), MaximumCorpusArchiveBytes);
    LDocument.Add('archive_sha256', HashAudioBytes(LBytes));
    LCorpus := DecodeWfcJointCorpus(LBytes, LModel, LActivity);
    LDocument.Add('model_sha256', HashText(EncodeWfcSequenceText(LModel)));
    LDocument.Add('loaded_without_learning', True);
    LDocument.Add('seed', Int64(LSeed));
    LInfo := LCorpus.SourceInfoAt(0);
    LDocument.Add('sample_rate', LInfo.SampleRate);
    LDocument.Add('channels', LInfo.Channels);
    LTiming := TJSONObject.Create;
    LDocument.Add('timing', LTiming);
    LTiming.Add('version', JointTimingVersion);
    LTiming.Add('alignment_version', FeatureAlignmentVersion);
    LTiming.Add('mode', ParamStr(4));
    LTiming.Add('hop_frames', LCorpus.Options.HopFrames);
    LTiming.Add('window_frames', LCorpus.Options.WindowFrames);
    LTiming.Add('maximum_error_frames', LMaximumError);
    LTiming.Add('rounding', 'nearest_ties_earlier');
    LTiming.Add('source_lock', 'onset_candidates_at_gate_starts');
    LTiming.Add('source_transient_sample_accuracy', False);
    LArticulation := ReadArticulation(LInfo.SampleRate, LTiming);
    LAttackPlan := PlanJointAttacks(LArticulation, LCorpus.Options.HopFrames, LMaximumError);
    LGeneration := DefaultAcousticGenerationOptions;
    LGeneration.Seed := LSeed;
    LGeneration.FrameCount := LAttackPlan.CellCount;
    LTiming.Add('analysis_cells', LAttackPlan.CellCount);
    LTiming.Add('distinct_attack_constraints', Length(LAttackPlan.Constraints));
    LItems := TJSONArray.Create;
    LTiming.Add('anchors', LItems);
    for LIndex := 0 to High(LAttackPlan.Anchors) do
    begin
      LItem := TJSONObject.Create;
      LItems.Add(LItem);
      LItem.Add('requested_frame', LAttackPlan.Anchors[LIndex].RequestedFrame);
      LItem.Add('cell', LAttackPlan.Anchors[LIndex].Cell);
      LItem.Add('aligned_frame', LAttackPlan.Anchors[LIndex].AlignedFrame);
      LItem.Add('error_frames', LAttackPlan.Anchors[LIndex].ErrorFrames);
    end;
    LItems := TJSONArray.Create;
    LTiming.Add('gates', LItems);
    for LIndex := 0 to LArticulation.GateCount - 1 do
    begin
      LGate := LArticulation.GateAt(LIndex);
      LItem := TJSONObject.Create;
      LItems.Add(LItem);
      LItem.Add('start_frame', LGate.StartFrame);
      LItem.Add('end_frame', LGate.EndFrame);
      LItem.Add('gain', LGate.Gain);
    end;
    LSources := LoadBoundCorpusSources(LCorpus, LPaths);
    if not TryGenerateJointSequence(LModel, LGeneration, LAttackPlan.Constraints,
      LSequence, LSolve) then
    begin
      if LSolve.Status = gssBacktrackLimit then
      begin
        raise EAudio.Create('Timed WFC backtrack budget exhausted; no output published');
      end;
      raise EAudio.Create('Timed WFC constraints are contradictory; no output published');
    end;
    LPlanOptions := DefaultContinuityOptions;
    LPlanOptions.Activity := LActivity;
    LPlanner := TCorpusGrainPlanner.Create(LCorpus, LSources, LPlanOptions);
    try
      LGrains := LPlanner.PlanActions(LSequence.Tokens, LSequence.Actions, LContinuity);
    finally
      LPlanner.Free;
    end;
    LDocument.Add('contiguous_links', LContinuity.ContiguousLinks);
    LPolicy := TJSONObject.Create;
    LDocument.Add('continuity', LPolicy);
    LPolicy.Add('version', AcousticContinuityVersion);
    LPolicy.Add('beam_width', LPlanOptions.BeamWidth);
    LPolicy.Add('candidates_per_token', LPlanOptions.CandidatesPerToken);
    LPolicy.Add('join_probe_frames', LPlanOptions.JoinProbeFrames);
    LPolicy.Add('center_weight', LPlanOptions.CenterWeight);
    LPolicy.Add('seam_weight', LPlanOptions.SeamWeight);
    LPolicy.Add('jump_weight', LPlanOptions.JumpWeight);
    LPolicy.Add('sustain_jump_weight', LPlanOptions.SustainJumpWeight);
    LPolicy := TJSONObject.Create;
    LDocument.Add('activity', LPolicy);
    LPolicy.Add('version', AcousticActivityVersion);
    LPolicy.Add('minimum_flux', LActivity.MinimumFlux);
    LPolicy.Add('adaptive_multiplier', LActivity.AdaptiveMultiplier);
    LPolicy.Add('history_features', LActivity.HistoryFeatures);
    LPolicy.Add('peak_radius', LActivity.PeakRadius);
    LPolicy.Add('minimum_separation_features', LActivity.MinimumSeparationFeatures);
    LPolicy.Add('maximum_segment_features', LActivity.MaximumSegmentFeatures);
    LItems := TJSONArray.Create;
    LDocument.Add('sources', LItems);
    for LIndex := 0 to LCorpus.SourceCount - 1 do
    begin
      LInfo := LCorpus.SourceInfoAt(LIndex);
      LItem := TJSONObject.Create;
      LItems.Add(LItem);
      LItem.Add('index', LIndex);
      LItem.Add('name', String(LInfo.Name));
      LItem.Add('sha256', LInfo.Sha256);
      LItem.Add('provenance', String(LInfo.Provenance));
    end;
    LItems := TJSONArray.Create;
    LDocument.Add('grains', LItems);
    for LIndex := 0 to High(LGrains) do
    begin
      LItem := TJSONObject.Create;
      LItems.Add(LItem);
      LItem.Add('token', LSequence.Tokens[LIndex]);
      LItem.Add('activity', Ord(LSequence.Actions[LIndex]));
      LItem.Add('source_index', LGrains[LIndex].SourceIndex);
      LItem.Add('source_start_frame', LGrains[LIndex].SourceStartFrame);
      LItem.Add('output_start_frame', LGrains[LIndex].OutputStartFrame);
      LItem.Add('frame_count', LGrains[LIndex].FrameCount);
      LItem.Add('playback_rate', LGrains[LIndex].PlaybackRate);
      LItem.Add('gain', LGrains[LIndex].Gain);
      LItem.Add('window', 'hann');
    end;
    LRenderOptions := DefaultGrainRenderOptions(LArticulation.SampleRate, LSources[0].Channels);
    LRenderOptions.MinimumFrames := LArticulation.FrameCount;
    LDocument.Add('normalize_overlap', LRenderOptions.NormalizeOverlap);
    LDocument.Add('interpolation', 'linear');
    LTiming.Add('gate_overlap', 'maximum');
    LRendered := RenderGrains(LSources, LGrains, LRenderOptions);
    LOutput := RenderArticulatedClip(LRendered, LArticulation);
    LBytes := EncodeWavePcm16(LOutput);
    LDocument.Add('output_sha256', HashAudioBytes(LBytes));
    LDocument.Add('output_frames', LOutput.FrameCount);
    LDocument.Add('max_backtracks', LGeneration.MaxBacktracks);
    LDocument.Add('extent', 'fragment');
    LDocument.Add('generation_version', AcousticGenerationVersion);
    LDocument.Add('granular_version', GranularVersion);
    LDocument.Add('wfc_solver_version', LSolve.SolverAlgorithmVersion);
    LDocument.Add('wfc_random_version', LSolve.RandomAlgorithmVersion);
    LJson := LDocument.FormatJSON;
    WriteFileBytes(ParamStr(2), LBytes);
    WriteTextFile(ParamStr(2) + '.json', LJson);
    WriteLn('Rendered ', LOutput.FrameCount, ' frames, ', Length(LGrains),
      ' learned grains and ', Length(LAttackPlan.Constraints), ' timed attack constraints');
    WriteLn('Exact output gates; source-window timing errors recorded in metadata.');
  finally
    LOutput.Free;
    LRendered.Free;
    LArticulation.Free;
    FreeAudioSources(LSources);
    LModel.Free;
    LCorpus.Free;
    LDocument.Free;
  end;
end;

begin
  try
    Run;
  except
    on LException: Exception do
    begin
      WriteLn(StdErr, LException.ClassName, ': ', LException.Message);
      Halt(1);
    end;
  end;
end.
