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
program pythian_tests_events_output;

{$mode delphi}
{$H+}

uses
  SysUtils,
  Math,
  fpjson,
  jsonparser,
  pythian.audio,
  pythian.wave,
  pythian.analysis,
  pythian.onset,
  pythian.onset.events,
  pythian.passage,
  pythian.learning,
  pythian.corpus,
  pythian.corpus.archive,
  pythian.wfc.events,
  pythian.tools.files,
  pythian.tools.pulses,
  wfc_sequence,
  wfc_sequence_text;

procedure Check(const ACondition: Boolean; const AMessage: String);
begin
  if not ACondition then
  begin
    raise Exception.Create(AMessage);
  end;
end;

function ReadText(const APath: String): String;
var
  LBytes: TAudioBytes;
begin
  LBytes := ReadFileBytes(APath, 16 * 1024 * 1024);
  Result := '';
  if Length(LBytes) > 0 then
  begin
    SetString(Result, PAnsiChar(@LBytes[0]), Length(LBytes));
  end;
end;

procedure Verify;
var
  LCorpus: TAcousticCorpusData;
  LPalette: TAcousticPalette;
  LModel: TWfcSequenceModel;
  LSource: TAudioClip;
  LOutput: TAudioClip;
  LDocument: TJSONData;
  LOnsets: TJSONData;
  LEvents: TJSONArray;
  LSourceEvents: TJSONArray;
  LRows: TJSONArray;
  LRow: TJSONData;
  LBytes: TAudioBytes;
  LAttachment: TAudioBytes;
  LContract: UTF8String;
  LSourceHash: String;
  LFeatures: TAudioFeatures;
  LAdmittedFeatures: TAudioFeatures;
  LPulses: TPreparedPulseEvents;
  LRuns: TPassageIndices;
  LSymbols: TAcousticEventSymbols;
  LPulseJson: TJSONObject;
  LPulseMode: Boolean;
  LCount: Integer;
  LClasses: TAcousticIndices;
  LLocations: TOnsetLocations;
  LPlan: TOnsetEventPlan;
  LTraining: TAcousticEventCorpus;
  LIndices: TPassageIndices;
  LReachable: array of Boolean;
  LNext: array of Boolean;
  LSourceIndex: Integer;
  LIndex: Integer;
  LState: Integer;
  LPrevious: Integer;
  LFrame: Integer;
  LChannel: Integer;
  LLength: Integer;
  LOffset: Integer;
  LFade: Integer;
  LSelected: Integer;
  LExpected: Double;
  LGain: Double;
  LFound: Boolean;
  LFadeIn: Boolean;
  LFadeOut: Boolean;
  LContiguous: Integer;
begin
  LCorpus := nil;
  LPalette := nil;
  LModel := nil;
  LSource := nil;
  LOutput := nil;
  LDocument := nil;
  LOnsets := nil;
  try
    LDocument := GetJSON(ReadText(ParamStr(4) + '.json'));
    LPulseMode := LDocument.FindPath('contract').AsString = 'pythian.pulse.remix.v1';
    Check(LPulseMode or (LDocument.FindPath('contract').AsString = 'pythian.event.remix.v1'),
      'Output contract');
    Check(LDocument.FindPath('extent').AsString = 'fragment', 'Fragment extent');
    LBytes := ReadFileBytes(ParamStr(1), MaximumCorpusArchiveBytes);
    Check(HashAudioBytes(LBytes) = LDocument.FindPath('archive_sha256').AsString, 'Archive hash');
    LCorpus := DecodeAcousticArchive(LBytes, LContract, LAttachment);
    LSource := LoadWaveSource(ParamStr(2), LSourceHash);
    Check(LSourceHash = LDocument.FindPath('source_sha256').AsString, 'Source hash');
    LSourceIndex := -1;
    for LIndex := 0 to LCorpus.SourceCount - 1 do
    begin
      if LCorpus.SourceInfoAt(LIndex).Sha256 = LSourceHash then
      begin
        LSourceIndex := LIndex;
      end;
    end;
    Check(LSourceIndex >= 0, 'Source belongs to measured corpus');
    LBytes := ReadFileBytes(ParamStr(3), 16 * 1024 * 1024);
    Check(HashAudioBytes(LBytes) = LDocument.FindPath('onset_report_sha256').AsString, 'Onset report hash');
    LOnsets := GetJSON(ReadText(ParamStr(3)));
    Check(LOnsets.AsJSON = LDocument.FindPath('onset_report').AsJSON, 'Complete onset report retained');
    Check(LOnsets.FindPath('source_sha256').AsString = LSourceHash, 'Onsets identify exact source');
    LRows := LOnsets.FindPath('locations') as TJSONArray;
    SetLength(LLocations, LRows.Count);
    for LIndex := 0 to LRows.Count - 1 do
    begin
      LRow := LRows.Items[LIndex];
      LLocations[LIndex].WindowStartFrame := LRow.FindPath('window_start').AsInteger;
      LLocations[LIndex].WindowFrameCount := LRow.FindPath('window_frames').AsInteger;
      LLocations[LIndex].Frame := LRow.FindPath('frame').AsInteger;
      LLocations[LIndex].EnergyRise := LRow.FindPath('energy_rise').AsFloat;
      LLocations[LIndex].Resolved := LRow.FindPath('resolved').AsBoolean;
      LLocations[LIndex].ContextClipped := LRow.FindPath('context_clipped').AsBoolean;
      LLocations[LIndex].SearchBoundary := LRow.FindPath('search_boundary').AsBoolean;
    end;
    LPlan := PlanOnsetEvents(LLocations, LSource.FrameCount, DefaultOnsetEventOptions(LSource.SampleRate));
    Check(LDocument.FindPath('minimum_event_frames').AsInteger = Max(1, LSource.SampleRate div 100),
      'Minimum interval policy');
    Check(not LDocument.FindPath('allow_clipped_context').AsBoolean and
      not LDocument.FindPath('allow_search_boundary').AsBoolean, 'Uncertain edge exclusion policy');
    LRows := LDocument.FindPath('location_decisions') as TJSONArray;
    Check(LRows.Count = Length(LPlan.Decisions), 'Every candidate has a decision');
    for LIndex := 0 to High(LPlan.Decisions) do
    begin
      Check(LRows.Strings[LIndex] = OnsetEventDecisionName(LPlan.Decisions[LIndex]), 'Candidate decision');
    end;
    if LPulseMode then
    begin
      LPulses := PreparePulseEvents(LLocations, LPlan, LSource.SampleRate, LSource.FrameCount);
      LPulseJson := PulseEventsJson(LPulses, LSource.SampleRate);
      try
        Check(LPulseJson.AsJSON = LDocument.FindPath('pulse_analysis').AsJSON,
          'Complete pulse positions, source identities, policy and admission replay');
      finally
        LPulseJson.Free;
      end;
      LPlan.Bounds := Copy(LPulses.Plan.Bounds, 0, Length(LPulses.Plan.Bounds));
      LPlan.LocationIndices := Copy(LPulses.LocationIndices, 0, Length(LPulses.LocationIndices));
      LRuns := Copy(LPulses.Plan.RunIndices, 0, Length(LPulses.Plan.RunIndices));
      LFeatures := MeasurePassages(LCorpus, LSourceIndex, LPlan.Bounds);
      SetLength(LAdmittedFeatures, LPulses.Plan.SelectedCount);
      LCount := 0;
      for LIndex := 0 to High(LFeatures) do
      begin
        if LRuns[LIndex] >= 0 then
        begin
          LAdmittedFeatures[LCount] := LFeatures[LIndex];
          Inc(LCount);
        end;
      end;
    end
    else
    begin
      LFeatures := MeasurePassages(LCorpus, LSourceIndex, LPlan.Bounds);
      LAdmittedFeatures := LFeatures;
      SetLength(LRuns, Length(LFeatures));
    end;
    LPalette := TAcousticPalette.Create(LAdmittedFeatures, LDocument.FindPath('palette_limit').AsInteger);
    LClasses := LPalette.Encode(LFeatures);
    LSourceEvents := LDocument.FindPath('source_events') as TJSONArray;
    Check(LSourceEvents.Count = Length(LClasses), 'Source event count');
    Check(LDocument.FindPath('duration_quantum_frames').AsInteger = Max(1, LSource.SampleRate div 50),
      'Explicit duration class quantum');
    SetLength(LSymbols, Length(LClasses));
    for LIndex := 0 to High(LClasses) do
    begin
      LLength := LPlan.Bounds[LIndex + 1] - LPlan.Bounds[LIndex];
      LRow := LSourceEvents.Items[LIndex];
      if LPulseMode then
      begin
        Check(LRow.FindPath('run_index').AsInteger = LRuns[LIndex], 'Independent training run');
      end;
      Check((LRow.FindPath('source_start_frame').AsInteger = LPlan.Bounds[LIndex]) and
        (LRow.FindPath('frame_count').AsInteger = LLength) and
        (LRow.FindPath('location_index').AsInteger = LPlan.LocationIndices[LIndex]),
        'Source interval and original location identity');
      if LRuns[LIndex] < 0 then
      begin
        Check(LRow.FindPath('token').AsString = '', 'Excluded interval has no learned symbol');
      end
      else
      begin
        LSymbols[LIndex] := AcousticEventSymbol(LClasses[LIndex], LLength,
          Max(1, LSource.SampleRate div 50), LPlan.LocationIndices[LIndex] >= 0);
        Check(LRow.FindPath('token').AsString = AcousticEventToken(LSymbols[LIndex]),
          'Admitted joint symbol');
      end;
    end;
    LTraining := PartitionAcousticEvents(LSymbols, LRuns);
    LModel := LearnAcousticEventModel(LTraining, LPalette, 2);
    Check(EncodeWfcSequenceText(LModel) = ReadText(ParamStr(4) + '.wfcs'),
      'Published model is exactly the actual learned source-event model');
    Check(HashText(EncodeWfcSequenceText(LModel)) = LDocument.FindPath('model_sha256').AsString,
      'Model identity');
    LBytes := ReadFileBytes(ParamStr(4), MaximumWaveBytes);
    Check(HashAudioBytes(LBytes) = LDocument.FindPath('output_sha256').AsString, 'Output identity');
    LOutput := DecodeWave(LBytes);
    Check((LOutput.SampleRate = LSource.SampleRate) and (LOutput.Channels = LSource.Channels),
      'Output source format retained');
    LEvents := LDocument.FindPath('events') as TJSONArray;
    SetLength(LIndices, LEvents.Count);
    SetLength(LReachable, LModel.StateCount);
    LOffset := 0;
    LContiguous := 0;
    for LIndex := 0 to LEvents.Count - 1 do
    begin
      LRow := LEvents.Items[LIndex];
      LSelected := LRow.FindPath('source_event').AsInteger;
      Check((LSelected >= 0) and (LSelected < Length(LClasses)), 'Selected interval range');
      Check(LRuns[LSelected] >= 0, 'Generated event never selects an excluded interval');
      LIndices[LIndex] := LSelected;
      LLength := LPlan.Bounds[LSelected + 1] - LPlan.Bounds[LSelected];
      Check((LRow.FindPath('source_start_frame').AsInteger = LPlan.Bounds[LSelected]) and
        (LRow.FindPath('frame_count').AsInteger = LLength) and
        (LRow.FindPath('output_start_frame').AsInteger = LOffset) and
        (LRow.FindPath('token').AsString = AcousticEventToken(LSymbols[LSelected])),
        'Every generated event matches its source class, duration class and onset status');
      if (LIndex > 0) and (LIndices[LIndex - 1] + 1 = LSelected) then
      begin
        Inc(LContiguous);
      end;
      Inc(LOffset, LLength);
      { Independent reachability over actual WFC latent states, without solving. }
      LNext := nil;
      SetLength(LNext, LModel.StateCount);
      for LState := 0 to LModel.StateCount - 1 do
      begin
        if LModel.ProjectStateToken(LState) <> LRow.FindPath('token').AsString then
        begin
          Continue;
        end;
        if LIndex = 0 then
        begin
          LNext[LState] := LModel.StateLeadingBosCountAt(LState) = 0;
        end
        else
        begin
          for LPrevious := 0 to LModel.StateCount - 1 do
          begin
            if LReachable[LPrevious] and LModel.StatesCompatible(LPrevious, LState) then
            begin
              LNext[LState] := True;
              Break;
            end;
          end;
        end;
      end;
      LReachable := LNext;
    end;
    LFound := False;
    for LState := 0 to High(LReachable) do
    begin
      LFound := LFound or LReachable[LState];
    end;
    Check(LFound, 'Generated tokens have a compatible actual WFC fragment path');
    Check((LOffset = LOutput.FrameCount) and
      (LOffset = LDocument.FindPath('output_frames').AsInteger), 'Complete exact-duration output coverage');
    LFade := Max(1, LSource.SampleRate div 1000);
    Check(LDocument.FindPath('fade_frames').AsInteger = LFade, 'Fade policy');
    LOffset := 0;
    for LIndex := 0 to High(LIndices) do
    begin
      LSelected := LIndices[LIndex];
      LLength := LPlan.Bounds[LSelected + 1] - LPlan.Bounds[LSelected];
      LFadeIn := (LIndex = 0) or (LIndices[LIndex - 1] + 1 <> LSelected);
      LFadeOut := (LIndex = High(LIndices)) or (LSelected + 1 <> LIndices[LIndex + 1]);
      for LFrame := 0 to LLength - 1 do
      begin
        LGain := 1;
        if LFadeIn then
        begin
          LGain := Min(LGain, LFrame / Min(LFade, Max(1, LLength div 2)));
        end;
        if LFadeOut then
        begin
          LGain := Min(LGain, (LLength - 1 - LFrame) / Min(LFade, Max(1, LLength div 2)));
        end;
        for LChannel := 0 to LSource.Channels - 1 do
        begin
          LExpected := LSource.SampleAt(LPlan.Bounds[LSelected] + LFrame, LChannel) * LGain;
          LExpected := Max(-1, Min(32767 / 32768, LExpected));
          Check(Abs(LOutput.SampleAt(LOffset + LFrame, LChannel) - LExpected) <= 0.502 / 32768,
            'Every PCM sample matches its source and independent edge-gain calculation');
        end;
      end;
      Inc(LOffset, LLength);
    end;
    WriteLn('Published events: input identities, interval decisions, joint model, latent path and ',
      LOutput.FrameCount, ' stereo frames pass; ', LContiguous, '/', Max(0, LEvents.Count - 1),
      ' contiguous source links');
  finally
    LOnsets.Free;
    LDocument.Free;
    LOutput.Free;
    LSource.Free;
    LModel.Free;
    LPalette.Free;
    LCorpus.Free;
  end;
end;

begin
  try
    if ParamCount <> 4 then
    begin
      raise EAudio.Create('Usage: pythian.tests.events.output INPUT.pyac SOURCE.wav ONSETS.json OUTPUT.wav');
    end;
    Verify;
  except
    on LException: Exception do
    begin
      WriteLn(StdErr, LException.ClassName, ': ', LException.Message);
      Halt(1);
    end;
  end;
end.
