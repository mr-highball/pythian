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

program pythian_context_track;

{$mode delphi}
{$H+}

uses
  SysUtils,
  Math,
  fpjson,
  pythian.audio,
  pythian.beat,
  pythian.beat.clock,
  pythian.beat.track,
  pythian.beat.wave,
  pythian.music.context,
  pythian.music.context.admission,
  pythian.music,
  pythian.music.render,
  pythian.time,
  pythian.synth,
  pythian.wave,
  pythian.tonal,
  pythian.wfc.context.archive,
  pythian.wfc.context.profile,
  pythian.wfc.context,
  pythian.wfc.layers,
  pythian.tools.beat.report,
  pythian.tools.files,
  wfc,
  wfc_sequence,
  wfc_sequence_graph;

procedure Audition;
var
  LProfile: TContextProfile;
  LBundle: TContextLearningBundle;
  LEvidence: TContextEvidenceArray;
  LLayers: TLearnedLayers;
  LMaps: TLayerProjections;
  LGenerated: TLayerSequences;
  LOptions: TLayerGenerationOptions;
  LReport: TGraphNegotiationReport;
  LContext: TMusicContext;
  LClock: TTempoMap;
  LNotes: TNoteSequence;
  LGates: TNoteGates;
  LVoice: TSynthVoice;
  LRender: TNoteRenderReport;
  LClip: TAudioClip;
  LLayer: Integer;
  LCell: Integer;
  LToken: String;
begin
  if SameFileName(ExpandFileName(ParamStr(2)), ExpandFileName(ParamStr(3))) then
  begin
    raise EAudio.Create('Audition must not replace the saved profile');
  end;
  LProfile := nil;
  LBundle := nil;
  LContext := nil;
  LClock := nil;
  LNotes := nil;
  LClip := nil;
  SetLength(LLayers, 2);
  LMaps := nil;
  try
    LProfile := DecodeContextProfile(ReadFileBytes(ParamStr(2), MaximumContextProfileBytes));
    for LLayer := 0 to 1 do
    begin
      LBundle := LProfile.CopyBundle(TContextDimension(LLayer));
      LEvidence := LBundle.CopyEvidence;
      FreeAndNil(LBundle);
      if Length(LEvidence) <> 1 then
      begin
        raise EAudio.Create('Clock audition requires one selected evidence grid per provider');
      end;
      LLayers[LLayer].Model := LProfile.CopyModel(TContextDimension(LLayer));
      SetLength(LLayers[LLayer].Constraints, Length(LEvidence[0].Grid.Keys));
      for LCell := 0 to High(LEvidence[0].Grid.Keys) do
      begin
        if LLayer = 0 then
        begin
          LToken := KeyContextToken(LEvidence[0].Grid.Keys[LCell]);
        end
        else
        begin
          LToken := TempoContextToken(LEvidence[0].Grid.Tempos[LCell]);
        end;
        LLayers[LLayer].Constraints[LCell] := MakeWfcSequenceTokenConstraint(LCell, [LToken]);
      end;
    end;
    if Length(LLayers[0].Constraints) <> Length(LLayers[1].Constraints) then
    begin
      raise EAudio.Create('Clock audition requires matching selected provider extents');
    end;
    LOptions := DefaultLayerGenerationOptions;
    LOptions.CellCount := Length(LLayers[0].Constraints);
    LOptions.Extent := wseWhole;
    if not TryGenerateLayers(LLayers, LMaps, LOptions, LGenerated, LReport) then
    begin
      raise EAudio.Create('Saved context models cannot reproduce the selected clock');
    end;
    LContext := MusicContextFromTokens(LGenerated[0].Tokens, LGenerated[1].Tokens,
      LProfile.TicksPerQuarter, LProfile.StepTicks);
    LClock := LContext.CopyClock;
    if (LClock.LengthTicks < LClock.TicksPerQuarter) or
      (LClock.LengthTicks mod LClock.TicksPerQuarter <> 0) then
    begin
      raise EAudio.Create('Pulse audition requires complete quarter-note intervals');
    end;
    SetLength(LGates, LClock.LengthTicks div LClock.TicksPerQuarter);
    for LCell := 0 to High(LGates) do
    begin
      LGates[LCell] := Default(TNoteGate);
      LGates[LCell].StartTick := LCell * LClock.TicksPerQuarter;
      LGates[LCell].EndTick := LGates[LCell].StartTick + Max(1, LClock.TicksPerQuarter div 4);
      LGates[LCell].Pitch := 84;
      LGates[LCell].Velocity := 96;
    end;
    LNotes := TNoteSequence.Create(LClock.TicksPerQuarter, LClock.LengthTicks,
      LClock.CopyChanges, LGates);
    LVoice := DefaultSynthVoice;
    LVoice.Envelope.ReleaseSeconds := 0;
    LClip := RenderNoteSequence(LNotes, 44100, LVoice, LRender);
    SaveWavePcm16(ParamStr(3), LClip);
    WriteLn('Saved WFC key/tempo passes drive ', LRender.RenderedNotes,
      ' authored pulse tones in ', LClip.FrameCount, ' frames; no source audio or learned voice pitches');
  finally
    LClip.Free;
    LNotes.Free;
    LClock.Free;
    LContext.Free;
    LBundle.Free;
    LProfile.Free;
    for LLayer := 0 to High(LLayers) do
    begin
      LLayers[LLayer].Model.Free;
    end;
  end;
end;

procedure Run;
var
  LAdmit: Boolean;
  LClockEnabled: Boolean;
  LArgumentCount: Integer;
  LClockOptions: TBeatClockOptions;
  LReconstructed: TBeatClock;
  LClip: TAudioClip;
  LHash: String;
  LGridOptions: TBeatGridOptions;
  LTrackOptions: TBeatTrackOptions;
  LMeasured: TWaveBeatEvidence;
  LTrack: TBeatTrack;
  LAdmission: TBeatTrackAdmission;
  LKey: TKeyContext;
  LFirst: Integer;
  LLast: Integer;
  LIndex: Integer;
  LDocument: TJSONObject;
  LRow: TJSONObject;
  LRows: TJSONArray;
  LText: String;
  LReportName: String;
  LProfileName: String;
  LEvidence: TContextEvidenceArray;
  LBundle: TContextLearningBundle;
  LProfile: TContextProfile;
  LBytes: TAudioBytes;
begin
  LClockOptions := DefaultBeatClockOptions;
  LReconstructed := Default(TBeatClock);
  LClockEnabled := False;
  LArgumentCount := ParamCount;
  if (LArgumentCount > 0) and (ParamStr(LArgumentCount) = '--alignment-context') then
  begin
    LClockOptions.AlignmentMode := bcaNeighbourSupported;
    Dec(LArgumentCount);
  end;
  if (LArgumentCount >= 2) and (ParamStr(LArgumentCount - 1) = '--clock') then
  begin
    if ParamStr(LArgumentCount) = 'step' then
    begin
      LClockOptions.Shape := bcsStepWhenFeasible;
    end
    else if ParamStr(LArgumentCount) <> 'linear' then
    begin
      raise EAudio.Create('Clock shape must be linear or step');
    end;
    LClockEnabled := True;
    Dec(LArgumentCount, 2);
  end;
  if (LClockOptions.AlignmentMode = bcaNeighbourSupported) and not LClockEnabled then
  begin
    raise EAudio.Create('--alignment-context requires --clock linear|step');
  end;
  LAdmit := (LArgumentCount = 8) and (ParamStr(1) = 'admit');
  if not LAdmit and not ((LArgumentCount = 3) and (ParamStr(1) = 'inspect')) then
  begin
    raise EAudio.Create('Usage: pythian.context.track inspect INPUT.wav REPORT.json [--clock linear|step [--alignment-context]]; ' +
      'admit INPUT.wav EXPECTED_SHA256 FIRST_PULSE LAST_PULSE ROOT MODE OUTPUT_PREFIX [--clock linear|step [--alignment-context]]; ' +
      'audition PROFILE.pcp OUTPUT.wav');
  end;
  LProfileName := '';
  LFirst := -1;
  LLast := -1;
  LKey := MakeKeyContext(-1, dmMajor);
  if LAdmit then
  begin
    LFirst := StrToInt(ParamStr(4));
    LLast := StrToInt(ParamStr(5));
    if ParamStr(7) = 'major' then
    begin
      LKey := MakeKeyContext(StrToInt(ParamStr(6)), dmMajor);
    end
    else if ParamStr(7) = 'minor' then
    begin
      LKey := MakeKeyContext(StrToInt(ParamStr(6)), dmNaturalMinor);
    end
    else
    begin
      raise EAudio.Create('Mode must be major or minor; unknown uses root -1 and major');
    end;
    LReportName := ParamStr(8) + '.json';
    LProfileName := ParamStr(8) + '.pcp';
  end
  else
  begin
    LReportName := ParamStr(3);
  end;
  if SameFileName(ExpandFileName(ParamStr(2)), ExpandFileName(LReportName)) or
    (LAdmit and SameFileName(ExpandFileName(ParamStr(2)), ExpandFileName(LProfileName))) then
  begin
    raise EAudio.Create('Track outputs must not replace the source WAV');
  end;
  LClip := nil;
  LDocument := nil;
  LBundle := nil;
  LProfile := nil;
  try
    LClip := LoadWaveSource(ParamStr(2), LHash);
    if LAdmit and (LowerCase(ParamStr(3)) <> LHash) then
    begin
      raise EAudio.Create('WAV source differs from the reviewed SHA256');
    end;
    LGridOptions := DefaultBeatGridOptions;
    LTrackOptions := DefaultBeatTrackOptions(LClip.SampleRate);
    LMeasured := MeasureWaveBeats(LClip, LGridOptions);
    LTrack := TrackBeatGrids(LMeasured.Observations, LClip.SampleRate,
      LClip.FrameCount, LGridOptions, LTrackOptions);
    LDocument := TJSONObject.Create;
    LDocument.Add('contract', 'pythian.wave-context-admission.v1');
    LDocument.Add('tempo_decision', 'explicit_tracked_pulse_range');
    if LClockEnabled then
    begin
      LDocument.Strings['tempo_decision'] := 'explicit_reconstructed_pulse_range';
      LReconstructed := ReconstructBeatClock(SelectedBeatClockWindows(LTrack.Windows),
        LMeasured.Observations, LClip.SampleRate, LClip.FrameCount, LClockOptions);
      LDocument.Add('continuous_clock', BeatClockJson(LReconstructed, LClockOptions));
    end;
    LDocument.Add('source', ExtractFileName(ParamStr(2)));
    LDocument.Add('source_sha256', LHash);
    LDocument.Add('sample_rate', LClip.SampleRate);
    LDocument.Add('channels', LClip.Channels);
    LDocument.Add('source_frames', LClip.FrameCount);
    LDocument.Add('admitted', LAdmit);
    LDocument.Add('beat_measurement', BeatEvidenceJson(LMeasured, LGridOptions));
    LDocument.Add('local_track', TrackJson(LTrack, LTrackOptions));
    if LAdmit then
    begin
      if LClockEnabled then
      begin
        LAdmission := AdmitBeatClockRange(SelectedBeatClockWindows(LTrack.Windows),
          LMeasured.Observations, LClockOptions, LClip.SampleRate, LClip.FrameCount,
          LFirst, LLast, 480, 240, LKey);
      end
      else
      begin
        LAdmission := AdmitBeatTrackRange(LTrack, LClip.SampleRate, LClip.FrameCount,
          LFirst, LLast, 480, 240, LKey);
      end;
      LDocument.Add('first_pulse', LFirst);
      LDocument.Add('last_pulse', LLast);
      LDocument.Add('source_start_frame', LAdmission.SourceStartFrame);
      LDocument.Add('source_end_frame', LAdmission.SourceEndFrame);
      LDocument.Add('ticks_per_quarter', LAdmission.Grid.TicksPerQuarter);
      LDocument.Add('step_ticks', LAdmission.Grid.StepTicks);
      LDocument.Add('cells', Length(LAdmission.Grid.Keys));
      LDocument.Add('key_root', LKey.Root);
      LDocument.Add('key_mode_ordinal', Ord(LKey.Mode));
      LDocument.Add('key_decision', 'caller_declared; unknown remains unknown');
      LDocument.Add('origin_decision', 'tick zero is first selected pulse; source offset retained separately');
      LDocument.Add('pulse_decision', 'caller declares consecutive quarter notes; no meter or downbeat inference');
      LRows := TJSONArray.Create;
      LDocument.Add('tempo_changes', LRows);
      for LIndex := 0 to High(LAdmission.Changes) do
      begin
        LRow := TJSONObject.Create;
        LRows.Add(LRow);
        LRow.Add('tick', LAdmission.Changes[LIndex].Tick);
        LRow.Add('microseconds_per_quarter', LAdmission.Changes[LIndex].MicrosecondsPerQuarter);
      end;
      LRows := TJSONArray.Create;
      LDocument.Add('boundary_error_frames', LRows);
      for LIndex := 0 to High(LAdmission.BoundaryErrors) do
      begin
        LRows.Add(LAdmission.BoundaryErrors[LIndex]);
      end;
    end;
    LText := LDocument.FormatJSON;
    if LAdmit then
    begin
      SetLength(LEvidence, 1);
      LEvidence[0].Name := ExtractFileName(ParamStr(2));
      LEvidence[0].SourceSha256 := LHash;
      LEvidence[0].SourceFrameOffset := LAdmission.SourceStartFrame;
      LEvidence[0].AdmissionPolicy := 'pythian.wave-context-admission.v1; tracked quarter pulses; ' +
        'relative clock; source_start_frame=' + IntToStr(LAdmission.SourceStartFrame) +
        '; no gap joining; report_sha256=' + HashText(LText);
      if LClockEnabled then
      begin
        LEvidence[0].AdmissionPolicy := 'pythian.wave-context-admission.v1; reconstructed quarter pulses; ' +
          'relative clock; source_start_frame=' + IntToStr(LAdmission.SourceStartFrame) +
          '; no gaps/restarts/ambiguous phase; report_sha256=' + HashText(LText);
      end;
      if LClockOptions.AlignmentMode = bcaNeighbourSupported then
      begin
        LEvidence[0].AdmissionPolicy := LEvidence[0].AdmissionPolicy +
          '; optional neighbour alignment; raw fallback is caller-reviewed clock, not observed-beat admission';
      end;
      LEvidence[0].Grid := LAdmission.Grid;
      LBundle := TContextLearningBundle.Create(LEvidence);
      LProfile := TContextProfile.Create(LBundle);
      LBytes := EncodeContextProfile(LProfile);
      WriteFileBytes(LProfileName, LBytes);
      WriteLn('Saved changing-tempo profile ', LProfile.Identity, '; cells ',
        Length(LAdmission.Grid.Keys));
    end;
    WriteTextFile(LReportName, LText);
    WriteLn('Tracked ', Length(LTrack.Frames), ' pulse positions; source ', LHash);
  finally
    LProfile.Free;
    LBundle.Free;
    LDocument.Free;
    LClip.Free;
  end;
end;

begin
  try
    if (ParamCount = 3) and (ParamStr(1) = 'audition') then
    begin
      Audition;
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
