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

program pythian_tests_context_profile;

{$mode delphi}
{$H+}

uses
  Classes,
  SysUtils,
  Math,
  fpjson,
  jsonparser,
  pythian.audio,
  pythian.analysis,
  pythian.analysis.wave,
  pythian.onset,
  pythian.tempo,
  pythian.beat,
  pythian.beat.track,
  pythian.beat.clock,
  pythian.beat.wave,
  pythian.hash,
  pythian.time,
  pythian.music.context,
  pythian.music.context.admission,
  pythian.music.grid.frames,
  pythian.tonal,
  pythian.wfc.context,
  pythian.wfc.context.archive,
  pythian.wfc.context.profile,
  pythian.wfc.layers,
  pythian.wave.read,
  pythian.wave,
  pythian.tools.beat.report,
  pythian.tools.files,
  wfc,
  wfc_sequence,
  wfc_sequence_graph,
  wfc_sequence_text;

procedure Check(const AValue: Boolean; const AMessage: String);
begin
  if not AValue then
  begin
    raise Exception.Create(AMessage);
  end;
end;

function SourceProfile(const ASource, AStep: Integer): TContextProfile;
var
  LEvidence: TContextEvidenceArray;
  LBundle: TContextLearningBundle;
  LIndex: Integer;
begin
  SetLength(LEvidence, 1);
  LEvidence[0].Name := 'Source ' + IntToStr(ASource);
  LEvidence[0].SourceSha256 := Sha256Bytes([Byte(ASource)]);
  LEvidence[0].AdmissionPolicy := 'Explicit authored fixture; independent context dimensions';
  LEvidence[0].Grid.TicksPerQuarter := 480;
  LEvidence[0].Grid.StartTick := ASource * 1920;
  LEvidence[0].Grid.StepTicks := AStep;
  SetLength(LEvidence[0].Grid.Keys, 8);
  SetLength(LEvidence[0].Grid.Tempos, 8);
  for LIndex := 0 to 7 do
  begin
    LEvidence[0].Grid.Keys[LIndex] := MakeKeyContext(ASource * 2, dmMajor);
    LEvidence[0].Grid.Tempos[LIndex] := 500001 + ASource * 100000;
  end;
  LBundle := TContextLearningBundle.Create(LEvidence, 1 + ASource, 3 - ASource);
  try
    Result := TContextProfile.Create(LBundle);
  finally
    LBundle.Free;
  end;
end;

function ModelText(const AProfile: TContextProfile; const ADimension: TContextDimension): String;
var
  LModel: TWfcSequenceModel;
begin
  LModel := AProfile.CopyModel(ADimension);
  try
    Result := EncodeWfcSequenceText(LModel);
  finally
    LModel.Free;
  end;
end;

procedure PutNumber(var ABytes: TAudioBytes; const AOffset, AValue: Integer);
var
  LIndex: Integer;
begin
  for LIndex := 0 to 3 do
  begin
    ABytes[AOffset + LIndex] := (Cardinal(AValue) shr (8 * LIndex)) and $FF;
  end;
end;

procedure Redigest(var ABytes: TAudioBytes);
var
  LHash: String;
begin
  LHash := Sha256Bytes(Copy(ABytes, 0, Length(ABytes) - 64));
  Move(LHash[1], ABytes[Length(ABytes) - 64], 64);
end;

procedure Reject(const ABytes: TAudioBytes; var APrior: TContextProfile);
var
  LPrevious: TContextProfile;
  LRejected: Boolean;
begin
  LPrevious := APrior;
  LRejected := False;
  try
    APrior := DecodeContextProfile(ABytes);
  except
    on EAudio do
    begin
      LRejected := True;
    end;
  end;
  Check(LRejected and (APrior = LPrevious), 'Malformed profile preserves prior assignment');
end;

procedure Run;
var
  LA: TContextProfile;
  LB: TContextProfile;
  LC: TContextProfile;
  LFirst: TContextProfile;
  LSecond: TContextProfile;
  LLoaded: TContextProfile;
  LParent: TContextProfile;
  LNext: TContextProfile;
  LBundle: TContextLearningBundle;
  LEvidence: TContextEvidenceArray;
  LBytes: TAudioBytes;
  LBad: TAudioBytes;
  LKeyText: String;
  LTempoText: String;
  LFirstId: String;
  LCId: String;
  LAProvider: String;
  LCProvider: String;
  LRejected: Boolean;
  LDepth: Integer;
begin
  LA := nil;
  LB := nil;
  LC := nil;
  LFirst := nil;
  LSecond := nil;
  LLoaded := nil;
  LParent := nil;
  LBundle := nil;
  try
    LA := SourceProfile(0, 240);
    LB := SourceProfile(1, 240);
    LC := SourceProfile(2, 240);
    LKeyText := ModelText(LA, cdKey);
    LTempoText := ModelText(LC, cdTempo);
    LAProvider := LA.ProviderIdentity(cdKey);
    LCProvider := LC.ProviderIdentity(cdTempo);
    LCId := LC.Identity;
    LFirst := SelectContextProfile(LA, LB);
    Check((ModelText(LFirst, cdKey) = LKeyText) and
      (ModelText(LFirst, cdTempo) = ModelText(LB, cdTempo)), 'Independent first selection');
    LFirstId := LFirst.Identity;
    LSecond := SelectContextProfile(LFirst, LC);
    Check((LSecond.Depth = 3) and (LSecond.NodeCount = 5) and
      (LSecond.EvidenceCells = 24), 'Complete two-stage ancestry counts');
    LBytes := EncodeContextProfile(LSecond);
    FreeAndNil(LA);
    FreeAndNil(LB);
    FreeAndNil(LC);
    FreeAndNil(LFirst);
    FreeAndNil(LSecond);
    LLoaded := DecodeContextProfile(LBytes);
    Check(LLoaded.Identity = Sha256Bytes(LBytes), 'Archive identity covers exact bytes');
    Check(Sha256Bytes(EncodeContextProfile(LLoaded)) = Sha256Bytes(LBytes), 'Exact round trip');
    LBad := EncodeContextProfile(LLoaded);
    LBad[0] := LBad[0] xor 1;
    LBytes[0] := LBytes[0] xor 1;
    Check(Sha256Bytes(EncodeContextProfile(LLoaded)) = LLoaded.Identity,
      'Decoded and encoded byte arrays are detached from immutable profile');
    LBytes[0] := LBytes[0] xor 1;
    Check((LLoaded.ParentIdentity(cdKey) = LFirstId) and
      (LLoaded.ParentIdentity(cdTempo) = LCId), 'Immediate parent identities survive');
    Check((LLoaded.ProviderIdentity(cdKey) = LAProvider) and
      (LLoaded.ProviderIdentity(cdTempo) = LCProvider), 'Selected original bundle identities survive');
    Check((ModelText(LLoaded, cdKey) = LKeyText) and
      (ModelText(LLoaded, cdTempo) = LTempoText), 'Selected actual models survive source lifetimes');
    LParent := LLoaded.CopyParent(cdKey);
    Check(LParent.Identity = LFirstId, 'Complete intermediate profile can be recovered');
    LBundle := LLoaded.CopyBundle(cdTempo);
    LEvidence := LBundle.CopyEvidence;
    Check((LBundle.TempoOrder = 1) and (Length(LEvidence) = 1) and
      (LEvidence[0].Grid.StartTick = 3840), 'Order and original source scope survive selection');
    FreeAndNil(LBundle);
    LBad := Copy(LBytes);
    PutNumber(LBad, 4, 99);
    Redigest(LBad);
    Reject(LBad, LLoaded);
    LBad := Copy(LBytes);
    PutNumber(LBad, 8, 2);
    Redigest(LBad);
    Reject(LBad, LLoaded);
    LBad := Copy(LBytes);
    PutNumber(LBad, 12, High(Integer));
    Redigest(LBad);
    Reject(LBad, LLoaded);
    LBad := Copy(LBytes);
    LBad[16] := LBad[16] xor 1;
    Redigest(LBad);
    Reject(LBad, LLoaded);
    Reject(Copy(LBytes, 0, Length(LBytes) - 1), LLoaded);
    LBad := Copy(LBytes);
    SetLength(LBad, Length(LBad) + 1);
    Redigest(LBad);
    Reject(LBad, LLoaded);
    LA := SourceProfile(0, 120);
    LRejected := False;
    try
      LNext := SelectContextProfile(LLoaded, LA);
      LNext.Free;
    except
      on EAudio do
      begin
        LRejected := True;
      end;
    end;
    Check(LRejected, 'Incompatible step rejects without quantization');
    FreeAndNil(LA);
    LA := SourceProfile(0, 240);
    FreeAndNil(LParent);
    LParent := DecodeContextProfile(EncodeContextProfile(LA));
    for LDepth := 2 to MaximumContextProfileDepth do
    begin
      LNext := SelectContextProfile(LParent, LA);
      FreeAndNil(LParent);
      LParent := LNext;
      Check(LParent.Depth = LDepth, 'Repeated selections remain reusable through allowed depth');
    end;
    LRejected := False;
    try
      LNext := SelectContextProfile(LParent, LA);
      LNext.Free;
    except
      on EAudio do
      begin
        LRejected := True;
      end;
    end;
    Check(LRejected, 'Depth budget rejects further derivation');
    WriteLn('Context source/derived selection, persistence, lineage and failure checks pass');
  finally
    LBundle.Free;
    LParent.Free;
    LLoaded.Free;
    LSecond.Free;
    LFirst.Free;
    LC.Free;
    LB.Free;
    LA.Free;
  end;
end;

function ReadBytes(const APath: String): TAudioBytes;
var
  LStream: TFileStream;
begin
  LStream := TFileStream.Create(APath, fmOpenRead or fmShareDenyWrite);
  try
    if LStream.Size > MaximumContextProfileBytes then
    begin
      raise EAudio.Create('Admission checker metadata exceeds byte budget');
    end;
    Result := nil;
    SetLength(Result, Integer(LStream.Size));
    if Length(Result) > 0 then
    begin
      LStream.ReadBuffer(Result[0], Length(Result));
    end;
  finally
    LStream.Free;
  end;
end;

procedure CheckLocalKeyOutput(const APrefix, ASource: String);
var
  LBytes: TAudioBytes;
  LText: String;
  LHash: String;
  LDocument: TJSONObject;
  LRows: TJSONArray;
  LRow: TJSONObject;
  LTonal: TJSONObject;
  LProfile: TContextProfile;
  LBundle: TContextLearningBundle;
  LEvidence: TContextEvidenceArray;
  LClip: TAudioClip;
  LClock: TTempoMap;
  LGrid: TMusicGridFrames;
  LRegions: TTonalKeyRegions;
  LMeasured: TTonalRegionAdmissions;
  LOptions: TAnalysisOptions;
  LIndex: Integer;
  LCell: Integer;
  LFit: Integer;
  LMaximumError: Double;
  LError: Double;
begin
  LDocument := nil;
  LProfile := nil;
  LBundle := nil;
  LClip := nil;
  LClock := nil;
  LGrid := nil;
  try
    LBytes := ReadBytes(APrefix + '.json');
    SetLength(LText, Length(LBytes));
    if Length(LBytes) > 0 then
    begin
      Move(LBytes[0], LText[1], Length(LBytes));
    end;
    LDocument := GetJSON(LText) as TJSONObject;
    LProfile := DecodeContextProfile(ReadBytes(APrefix + '.pcp'));
    LBundle := LProfile.CopyBundle(cdKey);
    LEvidence := LBundle.CopyEvidence;
    Check((Length(LEvidence) = 1) and
      (LProfile.ProviderIdentity(cdKey) = LProfile.ProviderIdentity(cdTempo)),
      'Local key profile retains a shared source for independent base providers');
    Check(Pos('report_sha256=' + Sha256Bytes(LBytes), LEvidence[0].AdmissionPolicy) > 0,
      'Local key profile binds exact measured report bytes');
    LClip := LoadWaveSource(ASource, LHash);
    Check((LHash = LEvidence[0].SourceSha256) and
      (LHash = LDocument.Get('source_sha256', '')), 'Local key profile/report bind actual WAV bytes');
    LClock := TTempoMap.Create(LProfile.TicksPerQuarter,
      LProfile.StepTicks * Length(LEvidence[0].Grid.Keys),
      [MakeTempoChange(0, LDocument.Get('tempo_microseconds_per_quarter', 0))]);
    LGrid := TMusicGridFrames.Create(LClock, LClip.SampleRate, LClip.FrameCount,
      0, 0, LProfile.StepTicks, Length(LEvidence[0].Grid.Keys));
    LRows := LDocument.Arrays['key_regions'];
    SetLength(LRegions, LRows.Count);
    for LIndex := 0 to High(LRegions) do
    begin
      LRow := LRows.Objects[LIndex];
      LRegions[LIndex].FirstCell := LRow.Get('first_cell', -1);
      LRegions[LIndex].CellCount := LRow.Get('cell_count', -1);
      LRegions[LIndex].Key := MakeKeyContext(LRow.Get('key_root', -2),
        TDiatonicMode(LRow.Get('key_mode_ordinal', -1)));
    end;
    LOptions := DefaultAnalysisOptions;
    LOptions.WindowFrames := LDocument.Get('window_frames', 0);
    LOptions.HopFrames := LDocument.Get('hop_frames', 0);
    LOptions.SilenceRms := LDocument.Get('silence_rms', -1.0);
    LMeasured := AdmitWaveKeyRegions(LClip, LGrid, LRegions, LOptions);
    LMaximumError := 0;
    for LIndex := 0 to High(LMeasured) do
    begin
      LRow := LRows.Objects[LIndex];
      Check((LMeasured[LIndex].StartFrame = LRow.Get('start_frame', -1)) and
        (LMeasured[LIndex].EndFrame = LRow.Get('end_frame', -1)) and
        (LMeasured[LIndex].Tonal.SelectedRank = LRow.Get('selected_rank', -2)),
        'Local key measurement replays exact geometry and explicit selected rank');
      LTonal := LRow.Objects['tonal'];
      Check(LMeasured[LIndex].Tonal.Report.CandidateCount = LTonal.Arrays['ranked_fits'].Count,
        'Local key candidate count replays');
      for LFit := 0 to LMeasured[LIndex].Tonal.Report.CandidateCount - 1 do
      begin
        Check((LMeasured[LIndex].Tonal.Report.Fits[LFit].Root =
          LTonal.Arrays['ranked_fits'].Objects[LFit].Get('root', -1)) and
          (Ord(LMeasured[LIndex].Tonal.Report.Fits[LFit].Mode) =
          LTonal.Arrays['ranked_fits'].Objects[LFit].Get('mode_ordinal', -1)),
          'Every regional tonal candidate retains rank and musical identity');
      end;
      for LCell := 0 to 11 do
      begin
        LError := Abs(LMeasured[LIndex].Weights[LCell] -
          LTonal.Arrays['pitch_class_weights'].Floats[LCell]) /
          Max(1.0, Abs(LMeasured[LIndex].Weights[LCell]));
        LMaximumError := Max(LMaximumError, LError);
        Check(LError < 1E-12, 'Regional tonal weights replay within cross-target floating precision');
      end;
      for LCell := LRegions[LIndex].FirstCell to
        LRegions[LIndex].FirstCell + LRegions[LIndex].CellCount - 1 do
      begin
        Check(SameKeyContext(LEvidence[0].Grid.Keys[LCell], LRegions[LIndex].Key) and
          (LEvidence[0].Grid.Tempos[LCell] = LDocument.Get('tempo_microseconds_per_quarter', 0)),
          'Saved base grid retains every selected key and independent tempo cell');
      end;
    end;
    WriteLn('Saved local key regions: exact source/report binding, grid and rankings; maximum relative weight error ',
      LMaximumError);
  finally
    LGrid.Free;
    LClock.Free;
    LClip.Free;
    LBundle.Free;
    LProfile.Free;
    LDocument.Free;
  end;
end;

procedure CheckTrackOutput(const APrefix, ASource: String);
var
  LBytes: TAudioBytes;
  LText: String;
  LHash: String;
  LJson: TJSONData;
  LDocument: TJSONObject;
  LProfile: TContextProfile;
  LBundle: TContextLearningBundle;
  LEvidence: TContextEvidenceArray;
  LSource: TAudioClip;
  LAudio: TAudioClip;
  LMeasured: TWaveBeatEvidence;
  LTrack: TBeatTrack;
  LTrackOptions: TBeatTrackOptions;
  LGridOptions: TBeatGridOptions;
  LAdmission: TBeatTrackAdmission;
  LClockOptions: TBeatClockOptions;
  LReconstructed: TBeatClock;
  LClockReport: TJSONObject;
  LClock: TTempoMap;
  LKey: TKeyContext;
  LReplay: TJSONObject;
  LIndex: Integer;
  LFrame: Integer;
  LChannel: Integer;
  LStart: Integer;
  LGateEnd: Integer;
  LEnd: Integer;
  LEnergy: Double;
begin
  LJson := nil;
  LProfile := nil;
  LBundle := nil;
  LSource := nil;
  LAudio := nil;
  LClock := nil;
  try
    LBytes := ReadBytes(APrefix + '.json');
    SetLength(LText, Length(LBytes));
    if Length(LBytes) > 0 then
    begin
      Move(LBytes[0], LText[1], Length(LBytes));
    end;
    LJson := GetJSON(LText);
    Check(LJson is TJSONObject, 'Track admission report object');
    LDocument := TJSONObject(LJson);
    LProfile := DecodeContextProfile(ReadBytes(APrefix + '.pcp'));
    LBundle := LProfile.CopyBundle(cdTempo);
    LEvidence := LBundle.CopyEvidence;
    Check((Length(LEvidence) = 1) and
      (LProfile.ProviderIdentity(cdKey) = LProfile.ProviderIdentity(cdTempo)),
      'One recorded context source supplies both saved models');
    Check(Pos('report_sha256=' + Sha256Bytes(LBytes), LEvidence[0].AdmissionPolicy) > 0,
      'Changing-clock profile binds exact admission report bytes');
    LSource := LoadWaveSource(ASource, LHash);
    Check((LHash = LEvidence[0].SourceSha256) and
      (LHash = LDocument.Get('source_sha256', '')), 'Track profile/report bind actual WAV bytes');
    LGridOptions := DefaultBeatGridOptions;
    LTrackOptions := DefaultBeatTrackOptions(LSource.SampleRate);
    LMeasured := MeasureWaveBeats(LSource, LGridOptions);
    LTrack := TrackBeatGrids(LMeasured.Observations, LSource.SampleRate,
      LSource.FrameCount, LGridOptions, LTrackOptions);
    LReplay := BeatEvidenceJson(LMeasured, LGridOptions);
    try
      Check(LReplay.AsJSON = LDocument.Objects['beat_measurement'].AsJSON,
        'All shared source measurements and policies replay');
    finally
      LReplay.Free;
    end;
    LReplay := TrackJson(LTrack, LTrackOptions);
    try
      Check(LReplay.AsJSON = LDocument.Objects['local_track'].AsJSON,
        'All track alternatives, adjustments, joins and policies replay');
    finally
      LReplay.Free;
    end;
    LKey := MakeKeyContext(LDocument.Get('key_root', -2),
      TDiatonicMode(LDocument.Get('key_mode_ordinal', -1)));
    if LDocument.Find('continuous_clock') <> nil then
    begin
      LClockReport := LDocument.Objects['continuous_clock'];
      LClockOptions := DefaultBeatClockOptions;
      if LClockReport.Get('shape', '') = 'step' then
      begin
        LClockOptions.Shape := bcsStepWhenFeasible;
      end
      else
      begin
        Check(LClockReport.Get('shape', '') = 'linear', 'Known clock reconstruction shape');
      end;
      LClockOptions.SupportToleranceSeconds := LClockReport.Floats['support_tolerance_seconds'];
      LClockOptions.SnapToleranceSeconds := LClockReport.Floats['snap_tolerance_seconds'];
      if LClockReport.Find('alignment_policy') <> nil then
      begin
        Check(LClockReport.Strings['alignment_policy'] = 'two-neighbour-offset-envelope',
          'Known optional alignment policy');
        LClockOptions.AlignmentMode := bcaNeighbourSupported;
      end;
      LReconstructed := ReconstructBeatClock(SelectedBeatClockWindows(LTrack.Windows),
        LMeasured.Observations, LSource.SampleRate, LSource.FrameCount, LClockOptions);
      LReplay := BeatClockJson(LReconstructed, LClockOptions);
      try
        Check(LReplay.AsJSON = LClockReport.AsJSON, 'Complete clock reconstruction replays');
      finally
        LReplay.Free;
      end;
      LAdmission := AdmitBeatClockRange(SelectedBeatClockWindows(LTrack.Windows),
        LMeasured.Observations, LClockOptions, LSource.SampleRate, LSource.FrameCount,
        LDocument.Get('first_pulse', -1), LDocument.Get('last_pulse', -1),
        LProfile.TicksPerQuarter, LProfile.StepTicks, LKey);
    end
    else
    begin
      LAdmission := AdmitBeatTrackRange(LTrack, LSource.SampleRate, LSource.FrameCount,
        LDocument.Get('first_pulse', -1), LDocument.Get('last_pulse', -1),
        LProfile.TicksPerQuarter, LProfile.StepTicks, LKey);
    end;
    Check((LAdmission.SourceStartFrame = LDocument.Get('source_start_frame', -1)) and
      (LAdmission.SourceStartFrame = LEvidence[0].SourceFrameOffset) and
      (LAdmission.SourceEndFrame = LDocument.Get('source_end_frame', -1)) and
      (Length(LAdmission.Grid.Keys) = Length(LEvidence[0].Grid.Keys)),
      'Selected range and source offset replay');
    Check(LDocument.Arrays['boundary_error_frames'].Count = Length(LAdmission.BoundaryErrors),
      'All boundary errors retained');
    for LIndex := 0 to High(LAdmission.BoundaryErrors) do
    begin
      Check(LDocument.Arrays['boundary_error_frames'].Integers[LIndex] =
        LAdmission.BoundaryErrors[LIndex], 'Boundary quantization replays');
    end;
    for LIndex := 0 to High(LAdmission.Grid.Keys) do
    begin
      Check(SameKeyContext(LAdmission.Grid.Keys[LIndex], LEvidence[0].Grid.Keys[LIndex]) and
        (LAdmission.Grid.Tempos[LIndex] = LEvidence[0].Grid.Tempos[LIndex]),
        'Measured changing-clock cells equal actual saved learning evidence');
    end;
    LAudio := LoadWaveSource(APrefix + '.wav', LHash);
    LClock := TTempoMap.Create(LProfile.TicksPerQuarter,
      Length(LAdmission.Grid.Keys) * LProfile.StepTicks, LAdmission.Changes);
    Check((LAudio.SampleRate = 44100) and (LAudio.Channels = 2) and
      (LAudio.FrameCount = LClock.FrameAtTick(LClock.LengthTicks, 44100)),
      'Saved WFC context audition has the exact admitted changing-clock extent');
    for LIndex := 0 to High(LAdmission.Changes) do
    begin
      LStart := LClock.FrameAtTick(LIndex * LClock.TicksPerQuarter, 44100);
      LGateEnd := LClock.FrameAtTick(LIndex * LClock.TicksPerQuarter +
        LClock.TicksPerQuarter div 4, 44100);
      LEnd := LClock.FrameAtTick((LIndex + 1) * LClock.TicksPerQuarter, 44100);
      LEnergy := 0;
      for LFrame := LStart to LEnd - 1 do
      begin
        for LChannel := 0 to LAudio.Channels - 1 do
        begin
          if LFrame < LGateEnd then
          begin
            LEnergy := LEnergy + Sqr(LAudio.SampleAt(LFrame, LChannel));
          end
          else
          begin
            Check(LAudio.SampleAt(LFrame, LChannel) = 0, 'Silence between admitted pulse cues');
          end;
        end;
      end;
      Check(LEnergy > 0.01, 'Every admitted interval produces an audible pulse cue');
    end;
    WriteLn('Changing-clock source/report/profile replay and ', Length(LAdmission.Changes),
      ' native pulse gates pass; ', LAudio.FrameCount, ' output frames');
  finally
    LClock.Free;
    LAudio.Free;
    LSource.Free;
    LBundle.Free;
    LProfile.Free;
    LJson.Free;
  end;
end;

procedure CheckWaveOutput(const APrefix, ASource: String);
var
  LBeatClip: TAudioClip;
  LBeatEvidence: TWaveBeatEvidence;
  LBeatAdmission: TBeatContextAdmission;
  LBeatJson: TJSONObject;
  LBeatRank: Integer;
  LProfile: TContextProfile;
  LBundle: TContextLearningBundle;
  LEvidence: TContextEvidenceArray;
  LBytes: TAudioBytes;
  LText: String;
  LDocument: TJSONObject;
  LJson: TJSONData;
  LSource: TFileStream;
  LReader: TWaveFrameReader;
  LScope: TWaveContextScope;
  LKey: TKeyContext;
  LMode: Integer;
  LLayers: TLearnedLayers;
  LGenerated: TLayerSequences;
  LOptions: TLayerGenerationOptions;
  LReport: TGraphNegotiationReport;
  LIndex: Integer;
  LTempoJson: TJSONObject;
  LTempoAnalysis: TAnalysisOptions;
  LTempoOptions: TTempoOptions;
  LTempoReport: TTempoReport;
  LFeatures: TAudioFeatures;
  LTempoRank: Integer;
begin
  LProfile := nil;
  LBundle := nil;
  LJson := nil;
  LSource := nil;
  LReader := nil;
  SetLength(LLayers, 2);
  try
    LBytes := ReadBytes(APrefix + '.json');
    SetLength(LText, Length(LBytes));
    if Length(LBytes) > 0 then
    begin
      Move(LBytes[0], LText[1], Length(LBytes));
    end;
    LJson := GetJSON(LText);
    Check(LJson is TJSONObject, 'Admission report object');
    LDocument := TJSONObject(LJson);
    Check(LDocument.Get('contract', '') = 'pythian.wave-context-admission.v1',
      'Admission report contract');
    LProfile := DecodeContextProfile(ReadBytes(APrefix + '.pcp'));
    Check(LProfile.ProviderIdentity(cdKey) = LProfile.ProviderIdentity(cdTempo),
      'One admitted source supplies both dimensions');
    LBundle := LProfile.CopyBundle(cdKey);
    LEvidence := LBundle.CopyEvidence;
    Check(Length(LEvidence) = 1, 'One admitted recording');
    Check(Pos('report_sha256=' + Sha256Bytes(LBytes), LEvidence[0].AdmissionPolicy) > 0,
      'Saved policy binds exact measured report bytes');
    LSource := TFileStream.Create(ASource, fmOpenRead or fmShareDenyWrite);
    Check(Sha256Stream(LSource, LSource.Size) = LEvidence[0].SourceSha256,
      'Saved evidence binds actual source bytes');
    Check(LDocument.Get('source_sha256', '') = LEvidence[0].SourceSha256,
      'Report and profile share source identity');
    LSource.Position := 0;
    LReader := TWaveFrameReader.Create(LSource);
    Check((LReader.SampleRate = LDocument.Get('sample_rate', 0)) and
      (LReader.Channels = LDocument.Get('channels', 0)) and
      (LReader.FrameCount = LDocument.Get('source_frames', 0)), 'Actual WAV geometry');
    if LDocument.Get('tempo_decision', '') = 'explicit_measured_candidate_selection' then
    begin
      LTempoJson := LDocument.Objects['tempo_measurement'];
      Check(LTempoJson.Get('measurement_version', -1) = TempoMeasurementVersion,
        'Current tempo measurement policy');
      LTempoAnalysis := DefaultOnsetAnalysisOptions(LReader.SampleRate);
      Check((LTempoJson.Get('analysis_window', -1) = LTempoAnalysis.WindowFrames) and
        (LTempoJson.Get('analysis_hop', -1) = LTempoAnalysis.HopFrames) and
        (LTempoJson.Get('silence_rms', -1.0) = LTempoAnalysis.SilenceRms),
        'Reported tempo feature settings match the measured operator path');
      LTempoOptions := DefaultTempoOptions;
      Check((LTempoJson.Get('minimum_bpm', -1.0) = LTempoOptions.MinimumBpm) and
        (LTempoJson.Get('maximum_bpm', -1.0) = LTempoOptions.MaximumBpm) and
        (LTempoJson.Get('minimum_flux', -1.0) = LTempoOptions.MinimumFlux) and
        (LTempoJson.Get('minimum_correlation', -1.0) = LTempoOptions.MinimumCorrelation) and
        (LTempoJson.Get('minimum_cycles', -1) = LTempoOptions.MinimumCycles) and
        (LTempoJson.Get('maximum_candidates', -1) = LTempoOptions.MaximumCandidates),
        'All reported tempo policy settings retained');
      LFeatures := AnalyzeWave(LReader, LTempoAnalysis);
      LTempoReport := RankTempoCandidates(LFeatures, LTempoAnalysis, LReader.SampleRate,
        Integer(LReader.FrameCount), LTempoOptions);
      Check(LTempoJson.Arrays['candidates'].Count = Length(LTempoReport.Candidates),
        'All measured tempo alternatives replay from the actual source');
      for LIndex := 0 to High(LTempoReport.Candidates) do
      begin
        Check((LTempoJson.Arrays['candidates'].Objects[LIndex].Get('microseconds_per_quarter', 0) =
          LTempoReport.Candidates[LIndex].MicrosecondsPerQuarter) and
          (Abs(LTempoJson.Arrays['candidates'].Objects[LIndex].Get('correlation', -1.0) -
          LTempoReport.Candidates[LIndex].Correlation) < 0.000000001),
          'Measured tempo candidate and strength replay');
      end;
      LTempoRank := LDocument.Get('tempo_selected_rank', -1);
      Check((LTempoRank >= 0) and (LTempoRank < Length(LTempoReport.Candidates)),
        'Selected tempo refers to an available measured candidate');
      Check(LTempoReport.Candidates[LTempoRank].MicrosecondsPerQuarter =
        LDocument.Get('tempo_microseconds_per_quarter', 0),
        'Saved clock equals the explicitly selected measured candidate');
    end;
    LMode := LDocument.Get('key_mode_ordinal', -1);
    Check(LMode in [0, 1], 'Supported selected mode');
    LKey := MakeKeyContext(LDocument.Get('key_root', -2), TDiatonicMode(LMode));
    if LDocument.Find('beat_measurement') <> nil then
    begin
      LBeatClip := LoadWave(ASource);
      LBeatJson := nil;
      try
        LBeatEvidence := MeasureWaveBeats(LBeatClip, DefaultBeatGridOptions);
        LBeatJson := BeatEvidenceJson(LBeatEvidence, DefaultBeatGridOptions);
        Check(LBeatJson.AsJSON = LDocument.Objects['beat_measurement'].AsJSON,
          'All beat policies, source observations and candidate metrics replay');
        LBeatRank := LDocument.Get('beat_selected_rank', -1);
        Check((LBeatRank >= 0) and (LBeatRank < Length(LBeatEvidence.Grid.Candidates)),
          'Selected beat candidate exists');
        LBeatAdmission := AdmitBeatContext(LBeatEvidence.Grid.Candidates[LBeatRank],
          LBeatClip.SampleRate, LBeatClip.FrameCount, LDocument.Get('ticks_per_quarter', 0),
          LDocument.Get('step_ticks', 0), LKey);
        Check((LBeatAdmission.TempoMicroseconds = LDocument.Get('tempo_microseconds_per_quarter', 0)) and
          (LBeatAdmission.Scope.Grid.StartTick = LDocument.Get('start_tick', -1)) and
          (Abs(LBeatAdmission.PhaseErrorFrames - LDocument.Get('phase_error_frames', 1E9)) < 1E-8) and
          (Abs(LBeatAdmission.PeriodErrorFrames - LDocument.Get('period_error_frames', 1E9)) < 1E-8),
          'Selected beat clock, source origin and quantization error bind to the profile');
      finally
        LBeatJson.Free;
        LBeatClip.Free;
      end;
    end;
    LScope := WaveContextScope(LReader.SampleRate, Integer(LReader.FrameCount),
      LDocument.Get('tempo_microseconds_per_quarter', 0),
      LDocument.Get('ticks_per_quarter', 0), LDocument.Get('step_ticks', 0), LKey,
      LDocument.Get('start_tick', 0));
    Check((LScope.Grid.StartTick = LEvidence[0].Grid.StartTick) and
      (Length(LScope.Grid.Keys) = Length(LEvidence[0].Grid.Keys)) and
      (LScope.EndFrameFloor = LDocument.Get('end_frame_floor', -1)) and
      (LScope.EndFrameCeiling = LDocument.Get('end_frame_ceiling', -1)),
      'Stored scope and exact source boundary');
    for LIndex := 0 to High(LScope.Grid.Keys) do
    begin
      Check(SameKeyContext(LScope.Grid.Keys[LIndex], LEvidence[0].Grid.Keys[LIndex]) and
        (LScope.Grid.Tempos[LIndex] = LEvidence[0].Grid.Tempos[LIndex]),
        'Every saved admitted context cell');
    end;
    LLayers[0].Model := LProfile.CopyModel(cdKey);
    LLayers[1].Model := LProfile.CopyModel(cdTempo);
    FreeAndNil(LProfile);
    FreeAndNil(LBundle);
    LOptions := DefaultLayerGenerationOptions;
    LOptions.CellCount := 8;
    LOptions.Extent := wseWhole;
    Check(TryGenerateLayers(LLayers, nil, LOptions, LGenerated, LReport),
      'Reloaded measured context models solve through actual WFC passes');
    for LIndex := 0 to 7 do
    begin
      Check((LGenerated[0].Tokens[LIndex] = KeyContextToken(LKey)) and
        (LGenerated[1].Tokens[LIndex] = TempoContextToken(LScope.Grid.Tempos[0])),
        'Generated key/tempo retain admitted decisions');
    end;
    WriteLn('WAV/report/profile bindings and actual WFC provider generation pass; cells ',
      Length(LScope.Grid.Keys), '; key root ', LKey.Root);
  finally
    for LIndex := 0 to High(LLayers) do
    begin
      LLayers[LIndex].Model.Free;
    end;
    LReader.Free;
    LSource.Free;
    LJson.Free;
    LBundle.Free;
    LProfile.Free;
  end;
end;


begin
  try
    if (ParamCount = 3) and (ParamStr(1) = 'local-keys') then
    begin
      CheckLocalKeyOutput(ParamStr(2), ParamStr(3));
    end
    else if (ParamCount = 3) and (ParamStr(1) = 'track') then
    begin
      CheckTrackOutput(ParamStr(2), ParamStr(3));
    end
    else if ParamCount = 2 then
    begin
      CheckWaveOutput(ParamStr(1), ParamStr(2));
    end
    else
    begin
      Run;
    end;
  except
    on LException: Exception do
    begin
      WriteLn(StdErr, LException.ClassName, ': ', LException.Message);
      Halt(1);
    end;
  end;
end.
