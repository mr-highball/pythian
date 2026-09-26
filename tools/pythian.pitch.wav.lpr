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

program pythian_pitch_wav;

{$mode delphi}
{$H+}

uses
  SysUtils,
  Math,
  fpjson,
  pythian.audio,
  pythian.articulation,
  pythian.pitch,
  pythian.pitch.cells,
  pythian.pitch.track,
  pythian.tonal,
  pythian.time,
  pythian.music,
  pythian.music.context,
  pythian.music.context.admission,
  pythian.music.render,
  pythian.synth,
  pythian.wave,
  pythian.wfc.pitch,
  pythian.wfc.layers,
  pythian.wfc.style,
  pythian.wfc.context,
  pythian.wfc.context.profile,
  pythian.tools.files,
  wfc,
  wfc_model,
  wfc_sequence,
  wfc_sequence_graph,
  wfc_sequence_text;

procedure ProtectOutput(const AOutput, AInput: String);
begin
  if SameFileName(ExpandFileName(AOutput), ExpandFileName(AInput)) then
  begin
    raise EAudio.Create('Pitch output must not replace its input');
  end;
end;

function RunPreviewSpanCount: Integer;
var
  LArgument: Integer;
begin
  Result := 8;
  if ParamCount = 4 then
  begin
    Exit;
  end;
  if (ParamCount = 5) and (ParamStr(5) <> '--spans') then
  begin
    Exit;
  end;
  LArgument := 5;
  if ParamStr(LArgument) <> '--spans' then
  begin
    Inc(LArgument);
  end;
  if (ParamStr(LArgument) <> '--spans') or
    (LArgument + 1 <> ParamCount) or
    not TryStrToInt(ParamStr(LArgument + 1), Result) or
    (Result < 1) or (Result > MaximumLayerCells) then
  begin
    raise EAudio.Create('Pitch duration span count is invalid');
  end;
end;

procedure Measure(const ALearn: Boolean);
var
  LClip: TAudioClip;
  LClock: TTempoMap;
  LScope: TWaveContextScope;
  LOptions: TPitchOptions;
  LEstimate: TPitchEstimate;
  LPitchEvidence: TPitchCellEvidence;
  LTracks: TPitchTracks;
  LModel: TWfcSequenceModel;
  LDocument: TJSONObject;
  LRows: TJSONArray;
  LRow: TJSONObject;
  LHash: String;
  LOutput: String;
  LModelText: String;
  LTempo: Integer;
  LChannel: Integer;
  LWindow: Integer;
  LCell: Integer;
  LStart: Integer;
  LEnd: Integer;
  LWindowStart: Integer;
  LKnown: Integer;
begin
  LOutput := ParamStr(3);
  if ALearn then
  begin
    LOutput := LOutput + '.json';
  end;
  ProtectOutput(LOutput, ParamStr(2));
  if ALearn then
  begin
    ProtectOutput(ParamStr(3) + '.model.txt', ParamStr(2));
  end;
  LClip := nil;
  LClock := nil;
  LModel := nil;
  LDocument := TJSONObject.Create;
  try
    LClip := LoadWaveSource(ParamStr(2), LHash);
    LTempo := StrToInt(ParamStr(4));
    LChannel := StrToInt(ParamStr(5));
    LOptions := DefaultPitchOptions;
    LPitchEvidence := MeasurePitchCells(LClip, LTempo, 480, 240, LChannel, LOptions, 25);
    LWindow := LPitchEvidence.WindowFrames;
    LScope := WaveContextScope(LClip.SampleRate, LClip.FrameCount, LTempo, 480, 240,
      MakeKeyContext(-1, dmMajor));
    LClock := TTempoMap.Create(480, Length(LScope.Grid.Tempos) * 240, [MakeTempoChange(0, LTempo)]);
    SetLength(LTracks, 1);
    LTracks[0] := AdmitPitchCells(LPitchEvidence, LClip.SampleRate, LClip.Channels,
      LClip.FrameCount, LTempo, 480, 240);
    LDocument.Add('contract', 'pythian.pitch.cells.v1');
    LDocument.Add('estimator_version', PitchEstimatorVersion);
    LDocument.Add('source_name', ExtractFileName(ParamStr(2)));
    LDocument.Add('source_sha256', LHash);
    LDocument.Add('source_sample_rate', LClip.SampleRate);
    LDocument.Add('source_channels', LClip.Channels);
    LDocument.Add('source_frames', LClip.FrameCount);
    LDocument.Add('selected_channel', LChannel);
    LDocument.Add('declared_tempo_us', LTempo);
    LDocument.Add('ticks_per_quarter', 480);
    LDocument.Add('step_ticks', 240);
    LDocument.Add('window_frames', LWindow);
    LDocument.Add('minimum_hz', LOptions.MinimumHz);
    LDocument.Add('maximum_hz', LOptions.MaximumHz);
    LDocument.Add('difference_threshold', LOptions.DifferenceThreshold);
    LDocument.Add('silence_ac_rms', LOptions.SilenceRms);
    LDocument.Add('admission_maximum_cents', 25);
    LDocument.Add('declared_monophonic', ALearn);
    LDocument.Add('policy', 'Cell-centered single-channel periodic estimate on declared clock; inspection is candidate evidence; learning explicitly assumes a monophonic source; unknown cells split training runs');
    LDocument.Add('beat_or_note_boundaries_inferred', False);
    LRows := TJSONArray.Create;
    LDocument.Add('cells', LRows);
    LKnown := 0;
    for LCell := 0 to High(LTracks[0]) do
    begin
      LStart := Integer(LClock.FrameAtTick(LCell * 240, LClip.SampleRate));
      LEnd := Integer(LClock.FrameAtTick((LCell + 1) * 240, LClip.SampleRate));
      LRow := TJSONObject.Create;
      LRows.Add(LRow);
      LRow.Add('cell', LCell);
      LRow.Add('start_frame', LStart);
      LRow.Add('end_frame', LEnd);
      if not LPitchEvidence.Cells[LCell].Measured then
      begin
        LRow.Add('status', 'insufficient_cell_window');
        LRow.Add('candidate_note', -1);
        Continue;
      end;
      LWindowStart := LStart + (LEnd - LStart - LWindow) div 2;
      LEstimate := LPitchEvidence.Cells[LCell].Estimate;
      LRow.Add('window_start_frame', LWindowStart);
      LRow.Add('status_ordinal', Ord(LEstimate.Status));
      LRow.Add('frequency_hz', LEstimate.FrequencyHz);
      LRow.Add('period_frames', LEstimate.PeriodFrames);
      LRow.Add('normalized_difference', LEstimate.NormalizedDifference);
      LRow.Add('ac_rms', LEstimate.AcRms);
      LRow.Add('nearest_midi', LEstimate.NearestMidi);
      LRow.Add('cents_error', LEstimate.CentsError);
      LRow.Add('candidate_note', LTracks[0][LCell]);
      if LTracks[0][LCell] >= 0 then
      begin
        Inc(LKnown);
      end;
    end;
    LDocument.Add('candidate_cells', LKnown);
    if ALearn then
    begin
      LModel := LearnPitchModel(LTracks, [1]);
      LModelText := EncodeWfcSequenceText(LModel);
      LDocument.Add('model_sha256', HashText(LModelText));
      LDocument.Add('model', LModelText);
      WriteTextFile(ParamStr(3) + '.model.txt', LModelText);
    end;
    WriteTextFile(LOutput, LDocument.FormatJSON);
    WriteLn('Pitch candidates ', LKnown, '/', Length(LTracks[0]),
      '; declared monophonic learning: ', ALearn);
  finally
    LDocument.Free;
    LModel.Free;
    LClock.Free;
    LClip.Free;
  end;
end;

procedure MeasureRuns(const ALearn: Boolean);
var
  LClip: TAudioClip;
  LTrack: TPitchTrack;
  LModel: TWfcSequenceModel;
  LTracks: TMeasuredPitchTracks;
  LSpans: TPitchSpans;
  LEstimate: TPitchEstimate;
  LOptions: TPitchTrackOptions;
  LDocument: TJSONObject;
  LRows: TJSONArray;
  LRow: TJSONObject;
  LHash: String;
  LModelText: String;
  LIndex: Integer;
  LOutput: String;
  LWindowFrames: Integer;
begin
  LWindowFrames := 0;
  if ParamCount = 7 then
  begin
    LWindowFrames := StrToInt(ParamStr(7));
    if LWindowFrames < 1 then
    begin
      raise EAudio.Create('Explicit pitch window requires positive frames');
    end;
  end;
  LOutput := ParamStr(3);
  if ALearn then
  begin
    LOutput := LOutput + '.json';
    ProtectOutput(ParamStr(3) + '.model.txt', ParamStr(2));
  end;
  ProtectOutput(LOutput, ParamStr(2));
  LClip := nil;
  LTrack := nil;
  LModel := nil;
  LDocument := TJSONObject.Create;
  try
    LClip := LoadWaveSource(ParamStr(2), LHash);
    LOptions := DefaultPitchTrackOptions(LClip.SampleRate);
    LTrack := TPitchTrack.Create(LClip, StrToInt(ParamStr(4)), LOptions, LWindowFrames);
    if ALearn and (LTrack.RunCount = 0) then
    begin
      raise EAudio.Create('No stable admitted pitch runs for monophonic duration learning');
    end;
    if ALearn then
    begin
      SetLength(LTracks, 1);
      LTracks[0] := LTrack;
      LModel := LearnPitchDurationModel(LTracks, [1]);
      LModelText := EncodeWfcSequenceText(LModel);
    end;
    LDocument.Add('contract', 'pythian.pitch.spans.v1');
    LDocument.Add('source_name', ExtractFileName(ParamStr(2)));
    LDocument.Add('source_sha256', LHash);
    LDocument.Add('source_sample_rate', LClip.SampleRate);
    LDocument.Add('source_channels', LClip.Channels);
    LDocument.Add('source_frames', LClip.FrameCount);
    LDocument.Add('selected_channel', LTrack.Channel);
    LDocument.Add('estimator_version', PitchEstimatorVersion);
    LDocument.Add('window_frames', LTrack.WindowFrames);
    LDocument.Add('hop_frames', LOptions.HopFrames);
    LDocument.Add('minimum_run_windows', LOptions.MinimumRunWindows);
    LDocument.Add('admission_maximum_cents', LOptions.MaximumCents);
    LDocument.Add('minimum_hz', LOptions.Pitch.MinimumHz);
    LDocument.Add('maximum_hz', LOptions.Pitch.MaximumHz);
    LDocument.Add('difference_threshold', LOptions.Pitch.DifferenceThreshold);
    LDocument.Add('silence_ac_rms', LOptions.Pitch.SilenceRms);
    LDocument.Add('declared_monophonic', True);
    LDocument.Add('duration_quantum_seconds', LOptions.HopFrames / LClip.SampleRate);
    LDocument.Add('pitch_run_count', LTrack.RunCount);
    LDocument.Add('policy', 'Overlapping complete windows; stable pitch runs occupy center-aligned hop bins; short pitch runs and unresolved windows remain explicit unknown spans; silence is a measured window classification; no beat clock or exact note-on/off inference');
    LDocument.Add('boundary_resolution_frames', LTrack.WindowFrames + LOptions.HopFrames);
    if ALearn then
    begin
      LDocument.Add('model_sha256', HashText(LModelText));
      LDocument.Add('model', LModelText);
    end;
    LRows := TJSONArray.Create;
    LDocument.Add('windows', LRows);
    for LIndex := 0 to LTrack.WindowCount - 1 do
    begin
      LEstimate := LTrack.EstimateAt(LIndex);
      LRow := TJSONObject.Create;
      LRows.Add(LRow);
      LRow.Add('start_frame', LIndex * LOptions.HopFrames);
      LRow.Add('status_ordinal', Ord(LEstimate.Status));
      LRow.Add('frequency_hz', LEstimate.FrequencyHz);
      LRow.Add('period_frames', LEstimate.PeriodFrames);
      LRow.Add('normalized_difference', LEstimate.NormalizedDifference);
      LRow.Add('ac_rms', LEstimate.AcRms);
      LRow.Add('nearest_midi', LEstimate.NearestMidi);
      LRow.Add('cents_error', LEstimate.CentsError);
      LRow.Add('candidate_note', LTrack.NoteAt(LIndex));
    end;
    LSpans := LTrack.CopySpans;
    LRows := TJSONArray.Create;
    LDocument.Add('spans', LRows);
    for LIndex := 0 to High(LSpans) do
    begin
      LRow := TJSONObject.Create;
      LRows.Add(LRow);
      LRow.Add('kind_ordinal', Ord(LSpans[LIndex].Kind));
      LRow.Add('note', LSpans[LIndex].Note);
      LRow.Add('first_window', LSpans[LIndex].FirstWindow);
      LRow.Add('window_count', LSpans[LIndex].WindowCount);
      LRow.Add('start_frame', LSpans[LIndex].StartFrame);
      LRow.Add('end_frame', LSpans[LIndex].EndFrame);
    end;
    if ALearn then
    begin
      WriteTextFile(ParamStr(3) + '.model.txt', LModelText);
    end;
    WriteTextFile(LOutput, LDocument.FormatJSON);
    WriteLn('Measured ', LTrack.RunCount, ' admitted pitch durations within ',
      Length(LSpans), ' explicit pitch/silence/unknown spans');
  finally
    LDocument.Free;
    LModel.Free;
    LTrack.Free;
    LClip.Free;
  end;
end;

procedure Generate(const ARunMode: Boolean; const AStyleMode: Boolean = False);
var
  LBytes: TAudioBytes;
  LText: String;
  LLayers: TLearnedLayers;
  LOptions: TLayerGenerationOptions;
  LGenerated: TLayerSequences;
  LReport: TGraphNegotiationReport;
  LSequence: TNoteSequence;
  LNotes: TNoteGates;
  LVoice: TSynthVoice;
  LRender: TNoteRenderReport;
  LClip: TAudioClip;
  LDocument: TJSONObject;
  LRows: TJSONArray;
  LStates: TJSONArray;
  LIndex: Integer;
  LTempo: Integer;
  LSeed: QWord;
  LSpan: TPitchDurationCell;
  LSpanRows: TJSONArray;
  LSpanRow: TJSONObject;
  LQuantum: Integer;
  LPpq: Integer;
  LTick: Integer;
  LNoteCount: Integer;
  LDuration: Integer;
  LGatePlan: TArticulationPlan;
  LGated: TAudioClip;
  LSubFrame: Integer;
  LStyle: TWaveStyleProfile;
  LStylePreferences: TStyleGenerationPreferences;
  LContext: TContextProfile;
  LModelLayer: Integer;
  LLayer: Integer;
  LTempos: TTempoChanges;
  LCumulativeTicks: Integer;
  LSession: TLearnedLayerSession;
  LBefore: TLayerSequences;
  LSelective: TGraphSelectiveNegotiationReport;
  LAllowed: TWfcModelTokens;
  LPinCell: Integer;
  LPinDuration: Integer;
  LSeparator: Integer;
  LTokenIndex: Integer;
  LProviderRows: TJSONArray;
  LProviderRow: TJSONObject;
  LProviderTokens: TJSONArray;
  LProviderStates: TJSONArray;
  LDurationClock: TTempoMap;
  LArgument: Integer;
  LDurationLock: String;
  LSpanCountSpecified: Boolean;
  LExtentName: String;
  LContextMode: String;
  LHoldContext: Boolean;
  LTempoPosition: Integer;
  LPreviewSpanCount: Integer;
begin
  ProtectOutput(ParamStr(3), ParamStr(2));
  ProtectOutput(ParamStr(3) + '.json', ParamStr(2));
  LPreviewSpanCount := 8;
  if ARunMode and not AStyleMode then
  begin
    LPreviewSpanCount := RunPreviewSpanCount;
  end;
  LStyle := nil;
  LContext := nil;
  LSession := nil;
  LAllowed := nil;
  LHoldContext := False;
  LModelLayer := 0;
  if AStyleMode then
  begin
    LModelLayer := 2;
  end;
  SetLength(LLayers, LModelLayer + 1);
  LClip := nil;
  LSequence := nil;
  LDocument := TJSONObject.Create;
  try
    if AStyleMode then
    begin
      LStyle := DecodeWaveStyle(ReadFileBytes(ParamStr(2), MaximumStyleBytes));
      LLayers[2].Model := LStyle.CopyDurationModel;
      LContext := LStyle.CopyContext;
      LLayers[0].Model := LContext.CopyModel(cdKey);
      LLayers[1].Model := LContext.CopyModel(cdTempo);
      LStylePreferences := LStyle.CopyGenerationPreferences;
      if (Length(LStylePreferences[sppRhythm]) > 0) or
        (Length(LStylePreferences[sppIntensity]) > 0) or
        (Length(LStylePreferences[sppPitch]) > 0) or
        (Length(LStylePreferences[sppPitchRhythm]) > 0) then
      begin
        raise EAudio.Create('Duration generation cannot consume grid-model preferences');
      end;
      LLayers[0].Preferences := LStylePreferences[sppKey];
      LLayers[1].Preferences := LStylePreferences[sppTempo];
      LLayers[2].Preferences := LStylePreferences[sppPerformance];
      LDocument.Add('wave_style_sha256', LStyle.Identity);
      LText := EncodeWfcSequenceText(LLayers[2].Model);
    end
    else
    begin
      LBytes := ReadFileBytes(ParamStr(2), 262144);
      SetLength(LText, Length(LBytes));
      if Length(LBytes) > 0 then
      begin
        Move(LBytes[0], LText[1], Length(LBytes));
      end;
      LLayers[0].Model := DecodeWfcSequenceText(LText);
    end;
    for LIndex := 0 to LLayers[LModelLayer].Model.PublicTokenCount - 1 do
    begin
      if ARunMode then
      begin
        DecodePitchDurationToken(LLayers[LModelLayer].Model.PublicTokenAt(LIndex));
      end
      else
      begin
        DecodePitchNoteToken(LLayers[LModelLayer].Model.PublicTokenAt(LIndex));
      end;
    end;
    LTempo := 1000000;
    if not AStyleMode then
    begin
      LTempo := StrToInt(ParamStr(4));
    end;
    LPpq := 480;
    LQuantum := 240;
    if ARunMode and not AStyleMode then
    begin
      LQuantum := LTempo;
      if (LQuantum < 1) or (LQuantum > 1000) then
      begin
        raise EAudio.Create('Pitch duration quantum must be 1..1000 milliseconds');
      end;
      LPpq := 1000;
      LTempo := 1000000;
    end;
    if AStyleMode then
    begin
      LPpq := LContext.TicksPerQuarter;
    end;
    LSeed := 731;
    if not AStyleMode and (ParamCount >= 5) and
      (not ARunMode or (ParamStr(5) <> '--spans')) then
    begin
      if not TryStrToQWord(ParamStr(5), LSeed) or (LSeed > High(TGraphSeed)) then
      begin
        raise EAudio.Create('Pitch seed exceeds companion range');
      end;
    end;
    LOptions := DefaultLayerGenerationOptions;
    LOptions.Seed := LSeed;
    if ARunMode then
    begin
      LOptions.CellCount := LPreviewSpanCount;
    end;
    if AStyleMode then
    begin
      LDurationLock := '';
      LExtentName := '';
      LContextMode := '';
      LSpanCountSpecified := False;
      LArgument := 4;
      while LArgument <= ParamCount do
      begin
        if ParamStr(LArgument) = '--spans' then
        begin
          if LSpanCountSpecified or
            not TryStrToInt(ParamStr(LArgument + 1), LOptions.CellCount) then
          begin
            raise EAudio.Create('Specify --spans once with an integer count');
          end;
          LSpanCountSpecified := True;
          if (LOptions.CellCount < 1) or (LOptions.CellCount > MaximumLayerCells) then
          begin
            raise EAudio.Create('Span count exceeds the supported layer extent');
          end;
        end
        else if ParamStr(LArgument) = '--context' then
        begin
          if LContextMode <> '' then
          begin
            raise EAudio.Create('Specify --context once');
          end;
          LContextMode := ParamStr(LArgument + 1);
          if (LContextMode <> 'hold') and (LContextMode <> 'sequence') then
          begin
            raise EAudio.Create('Context mode must be hold or sequence');
          end;
          LHoldContext := LContextMode = 'hold';
        end
        else if ParamStr(LArgument) = '--extent' then
        begin
          if LExtentName <> '' then
          begin
            raise EAudio.Create('Specify --extent once');
          end;
          LExtentName := ParamStr(LArgument + 1);
          if LExtentName = 'prefix' then
          begin
            LOptions.Extent := wsePrefix;
          end
          else if LExtentName <> 'fragment' then
          begin
            raise EAudio.Create('Extent must be prefix or fragment');
          end;
        end
        else if ParamStr(LArgument) = '--duration-lock' then
        begin
          if LDurationLock <> '' then
          begin
            raise EAudio.Create('Specify --duration-lock once');
          end;
          LDurationLock := ParamStr(LArgument + 1);
          if LDurationLock = '' then
          begin
            raise EAudio.Create('Duration lock requires CELL:UNITS');
          end;
        end
        else
        begin
          raise EAudio.Create('Expected --spans COUNT, --extent prefix|fragment, --context hold|sequence or --duration-lock CELL:UNITS');
        end;
        Inc(LArgument, 2);
      end;
      if LExtentName = '' then
      begin
        LExtentName := 'fragment';
      end;
      LDocument.Add('sequence_extent', LExtentName);
      if LContextMode = '' then
      begin
        LContextMode := 'sequence';
      end;
      LDocument.Add('context_mode', LContextMode);
      if LHoldContext then
      begin
        HeldContextToken(LLayers[0].Model, cdKey);
        HeldContextToken(LLayers[1].Model, cdTempo);
        SetLength(LOptions.Scopes, 3);
        LOptions.Scopes[0] := MakeLayerScope(1, wsePrefix);
        LOptions.Scopes[1] := MakeLayerScope(1, wsePrefix);
        LOptions.Scopes[2] := MakeLayerScope(LOptions.CellCount, LOptions.Extent);
      end;
      LSession := TLearnedLayerSession.Create(LLayers, nil, ['key', 'tempo', 'performance'], LOptions);
      if not LSession.TryGenerate(LGenerated, LReport) then
      begin
        raise EAudio.Create('Bounded saved duration generation failed');
      end;
      if LDurationLock <> '' then
      begin
        LSeparator := Pos(':', LDurationLock);
        if LSeparator < 2 then
        begin
          raise EAudio.Create('Duration lock requires CELL:UNITS');
        end;
        LPinCell := StrToInt(Copy(LDurationLock, 1, LSeparator - 1));
        LPinDuration := StrToInt(Copy(LDurationLock, LSeparator + 1, MaxInt));
        if (LPinCell < 0) or (LPinCell >= LOptions.CellCount) or (LPinDuration < 1) then
        begin
          raise EAudio.Create('Duration lock is outside the event span extent');
        end;
        for LTokenIndex := 0 to LLayers[2].Model.PublicTokenCount - 1 do
        begin
          LSpan := DecodePitchDurationToken(LLayers[2].Model.PublicTokenAt(LTokenIndex));
          if LSpan.Duration = LPinDuration then
          begin
            SetLength(LAllowed, Length(LAllowed) + 1);
            LAllowed[High(LAllowed)] := LLayers[2].Model.PublicTokenAt(LTokenIndex);
          end;
        end;
        if Length(LAllowed) = 0 then
        begin
          raise EAudio.Create('Requested duration has no observed alternative');
        end;
        LBefore := LSession.CopyAccepted;
        LSession.SetConstraints('performance', [MakeWfcSequenceTokenConstraint(LPinCell, LAllowed)]);
        if not LSession.TryRegenerate(['performance'], LSeed, LGenerated, LSelective) then
        begin
          raise EAudio.Create('Bounded duration edit could not satisfy the saved model');
        end;
        for LLayer := 0 to 1 do
        begin
          for LIndex := 0 to High(LGenerated[LLayer].StateIndices) do
          begin
            if LBefore[LLayer].StateIndices[LIndex] <> LGenerated[LLayer].StateIndices[LIndex] then
            begin
              raise EAudio.Create('Duration edit changed an accepted context provider');
            end;
          end;
        end;
        LDocument.Add('duration_lock', LDurationLock);
        LDocument.Add('context_states_preserved', True);
        LDocument.Add('regenerated_pass', LSelective.ActivePassIndices[0]);
      end;
      LProviderRows := TJSONArray.Create;
      LDocument.Add('provider_passes', LProviderRows);
      for LLayer := 0 to High(LLayers) do
      begin
        LProviderRow := TJSONObject.Create;
        LProviderRows.Add(LProviderRow);
        LProviderRow.Add('model_sha256', HashText(EncodeWfcSequenceText(LLayers[LLayer].Model)));
        if LHoldContext and (LLayer < 2) then
        begin
          LProviderRow.Add('sequence_extent', 'prefix');
        end
        else
        begin
          LProviderRow.Add('sequence_extent', LExtentName);
        end;
        LProviderTokens := TJSONArray.Create;
        LProviderStates := TJSONArray.Create;
        LProviderRow.Add('tokens', LProviderTokens);
        LProviderRow.Add('states', LProviderStates);
        for LIndex := 0 to High(LGenerated[LLayer].Tokens) do
        begin
          LProviderTokens.Add(String(LGenerated[LLayer].Tokens[LIndex]));
          LProviderStates.Add(LGenerated[LLayer].StateIndices[LIndex]);
        end;
      end;
      if LHoldContext then
      begin
        LDocument.Add('context_policy', 'Explicit output hold of each single-valued saved context model; one actual prefix state per key/tempo pass holds to the output endpoint; no added observations or inferred source scope; unknown key remains unknown');
      end
      else
      begin
        LDocument.Add('context_policy', 'Actual saved key and tempo passes; absolute measured pitches retain their register; tempo applies at generated span boundaries; no authored accompaniment');
      end;
    end
    else if not TryGenerateLayers(LLayers, nil, LOptions, LGenerated, LReport) then
    begin
      raise EAudio.Create('Bounded pitch generation failed');
    end;
    SetLength(LNotes, LOptions.CellCount);
    LRows := TJSONArray.Create;
    LStates := TJSONArray.Create;
    LDocument.Add('notes', LRows);
    LDocument.Add('states', LStates);
    LTick := 0;
    LCumulativeTicks := 0;
    SetLength(LTempos, LOptions.CellCount);
    LNoteCount := 0;
    LSpanRows := nil;
    if ARunMode then
    begin
      LSpanRows := TJSONArray.Create;
      LDocument.Add('spans', LSpanRows);
    end;
    for LIndex := 0 to LOptions.CellCount - 1 do
    begin
      LStates.Add(LGenerated[LModelLayer].StateIndices[LIndex]);
      LSpan.Kind := pskPitch;
      LSpan.Duration := 1;
      if ARunMode then
      begin
        LSpan := DecodePitchDurationToken(LGenerated[LModelLayer].Tokens[LIndex]);
      end
      else
      begin
        LSpan.Note := DecodePitchNoteToken(LGenerated[LModelLayer].Tokens[LIndex]);
      end;
      LDuration := LSpan.Duration * LQuantum;
      if AStyleMode then
      begin
        Inc(LCumulativeTicks, LSpan.Duration);
        LDuration := LCumulativeTicks - LTick;
        if LDuration < 1 then
        begin
          raise EAudio.Create('Duration span is shorter than one output PPQ tick');
        end;
        LTempoPosition := LIndex;
        if LHoldContext then
        begin
          LTempoPosition := 0;
        end;
        LTempo := TempoContextFromToken(String(LGenerated[1].Tokens[LTempoPosition]));
      end;
      LTempos[LIndex] := MakeTempoChange(LTick, LTempo);
      if ARunMode then
      begin
        LSpanRow := TJSONObject.Create;
        LSpanRows.Add(LSpanRow);
        LSpanRow.Add('token', String(LGenerated[LModelLayer].Tokens[LIndex]));
        LSpanRow.Add('start_tick', LTick);
        LSpanRow.Add('end_tick', LTick + LDuration);
        LSpanRow.Add('kind_ordinal', Ord(LSpan.Kind));
        LSpanRow.Add('note', LSpan.Note);
      end;
      if LSpan.Kind = pskPitch then
      begin
        LNotes[LNoteCount].StartTick := LTick;
        LNotes[LNoteCount].EndTick := LTick + LDuration;
        if not ARunMode then
        begin
          LNotes[LNoteCount].EndTick := LTick + 192;
        end;
        LNotes[LNoteCount].Pitch := LSpan.Note;
        LNotes[LNoteCount].Velocity := 96;
        LNotes[LNoteCount].Channel := -1;
        LRows.Add(LSpan.Note);
        Inc(LNoteCount);
      end;
      Inc(LTick, LDuration);
    end;
    SetLength(LNotes, LNoteCount);
    LSequence := TNoteSequence.Create(LPpq, LTick,
      LTempos, LNotes);
    if ARunMode then
    begin
      LDurationClock := LSequence.CopyClock;
      try
        if LDurationClock.FrameAtTick(LTick, 44100) > 120 * 44100 then
        begin
          raise EAudio.Create('Pitch duration render exceeds 120-second budget');
        end;
      finally
        LDurationClock.Free;
      end;
    end;
    LVoice := DefaultSynthVoice;
    LVoice.Gain := 0.24;
    if ARunMode then
    begin
      { These are monophonic measured spans. A previous note's release must not
        spill into the next pitched span; the gate plan supplies interior fades. }
      LVoice.Envelope.ReleaseSeconds := 0;
    end;
    LClip := RenderNoteSequence(LSequence, 44100, LVoice, LRender);
    if ARunMode then
    begin
      LGatePlan := PlanNoteArticulation(LSequence, 44100, 44, 44, LSubFrame);
      try
        LGated := RenderArticulatedClip(LClip, LGatePlan);
        LClip.Free;
        LClip := LGated;
      finally
        LGatePlan.Free;
      end;
      LDocument.Add('gate_policy', 'Monophonic synthesis ends each voice at its span boundary; native articulation adds 44-frame interior fades; previous pitches do not spill into following pitched, silent or unknown spans');
    end;
    LDocument.Add('contract', 'pythian.pitch.generated.v1');
    LDocument.Add('ticks_per_quarter', LPpq);
    if LHoldContext then
    begin
      LDocument.Add('context_hold_end_tick', LTick);
    end;
    if ARunMode and not AStyleMode then
    begin
      LDocument.Add('duration_quantum_ms', LQuantum);
      LDocument.Add('span_count', LOptions.CellCount);
    end;
    LDocument.Add('model_sha256', HashText(LText));
    LDocument.Add('seed', Int64(LSeed));
    LDocument.Add('tempo_us', LTempo);
    if AStyleMode then
    begin
      LDocument.Add('duration_ticks_per_quarter', LStyle.DurationTicksPerQuarter);
      LDocument.Add('policy', 'Saved style duration model; normalized PPQ tick durations accumulate to musical boundaries, then generated tempo controls output time; pitch spans sound fully, silence/unknown spans render silently; authored velocity and timbre');
    end
    else if ARunMode then
    begin
      LDocument.Add('policy', 'Actual saved pitch/silence/unknown duration model; caller supplies its hop duration in milliseconds; measured pitch spans sound for their full duration; silence and unknown spans render silently as an explicit output policy; velocity and timbre remain authored');
    end
    else
    begin
      LDocument.Add('policy', 'Actual saved pitch model; authored equal cell spacing, 80-percent gates, velocity and timbre; no source duration/style-profile inference');
    end;
    LDocument.Add('frames', LClip.FrameCount);
    LBytes := EncodeWavePcm16(LClip);
    LDocument.Add('output_sha256', HashAudioBytes(LBytes));
    WriteFileBytes(ParamStr(3), LBytes);
    WriteTextFile(ParamStr(3) + '.json', LDocument.FormatJSON);
    WriteLn('Rendered ', Length(LNotes), ' notes from saved WAV-derived pitch model');
  finally
    LDocument.Free;
    LClip.Free;
    LSequence.Free;
    LSession.Free;
    LContext.Free;
    LStyle.Free;
    for LLayer := 0 to High(LLayers) do
    begin
      LLayers[LLayer].Model.Free;
    end;
  end;
end;

begin
  try
    if (ParamStr(1) = 'inspect') and (ParamCount = 5) then
    begin
      Measure(False);
    end
    else if (ParamStr(1) = 'learn') and (ParamCount = 6) and (ParamStr(6) = '--monophonic') then
    begin
      Measure(True);
    end
    else if (ParamStr(1) = 'learn-runs') and
      ((ParamCount = 5) or ((ParamCount = 7) and (ParamStr(6) = '--window-frames'))) and
      (ParamStr(5) = '--monophonic') then
    begin
      MeasureRuns(True);
    end
    else if (ParamStr(1) = 'inspect-runs') and
      ((ParamCount = 5) or ((ParamCount = 7) and (ParamStr(6) = '--window-frames'))) and
      (ParamStr(5) = '--monophonic') then
    begin
      MeasureRuns(False);
    end
    else if (ParamStr(1) = 'generate-style-runs') and (ParamCount in [3, 5, 7, 9, 11]) then
    begin
      Generate(True, True);
    end
    else if (ParamStr(1) = 'generate-runs') and
      (ParamCount in [4, 5, 6, 7]) and
      ((ParamCount <= 5) or (ParamStr(ParamCount - 1) = '--spans')) then
    begin
      Generate(True);
    end
    else if (ParamStr(1) = 'generate') and (ParamCount in [4, 5]) then
    begin
      Generate(False);
    end
    else
    begin
      raise EAudio.Create('Usage: pythian.pitch.wav inspect INPUT.wav REPORT.json TEMPO_US CHANNEL; ' +
        'learn INPUT.wav PREFIX TEMPO_US CHANNEL --monophonic; generate MODEL.txt OUTPUT.wav TEMPO_US [SEED]; ' +
        'inspect-runs INPUT.wav REPORT.json CHANNEL --monophonic [--window-frames N]; ' +
        'learn-runs INPUT.wav PREFIX CHANNEL --monophonic [--window-frames N]; generate-runs MODEL.txt OUTPUT.wav QUANTUM_MS [SEED] [--spans COUNT]; ' +
        'generate-style-runs PROFILE.pys OUTPUT.wav [--spans COUNT] ' +
        '[--extent prefix|fragment] [--context hold|sequence] [--duration-lock CELL:TICKS]');
    end;
  except
    on LException: Exception do
    begin
      WriteLn(StdErr, LException.ClassName, ': ', LException.Message);
      ExitCode := 1;
    end;
  end;
end.
