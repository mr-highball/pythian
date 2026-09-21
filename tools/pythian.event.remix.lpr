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
program pythian_event_remix;

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
  pythian.wfc.generation,
  pythian.tools.files,
  pythian.tools.events,
  pythian.tools.pulses,
  wfc,
  wfc_model,
  wfc_sequence,
  wfc_sequence_text;

procedure Remix(const AArchive, ASourcePath, AOnsets, AOutput: String;
  const ASeed: TGraphSeed; const AEventCount, APaletteSize: Integer;
  const APulses: Boolean);
var
  LCorpus: TAcousticCorpusData;
  LSource: TAudioClip;
  LOutput: TAudioClip;
  LPalette: TAcousticPalette;
  LModel: TWfcSequenceModel;
  LOnsets: TJSONData;
  LDocument: TJSONObject;
  LBytes: TAudioBytes;
  LAttachment: TAudioBytes;
  LContract: UTF8String;
  LSourceHash: String;
  LArchiveHash: String;
  LOnsetHash: String;
  LOnsetText: String;
  LModelText: String;
  LDestination: String;
  LInfo: TAcousticSourceInfo;
  LLocations: TOnsetLocations;
  LPlan: TOnsetEventPlan;
  LEventOptions: TOnsetEventOptions;
  LFeatures: TAudioFeatures;
  LAdmittedFeatures: TAudioFeatures;
  LPulses: TPreparedPulseEvents;
  LRuns: TPassageIndices;
  LSymbols: TAcousticEventSymbols;
  LClasses: TAcousticIndices;
  LTraining: TAcousticEventCorpus;
  LSourceTokens: TWfcModelTokens;
  LGenerated: TWfcModelTokens;
  LIndices: TPassageIndices;
  LCandidates: TPassageIndices;
  LConstraints: TWfcSequenceTokenConstraints;
  LOptions: TAcousticGenerationOptions;
  LSolveReport: TGraphSolveReport;
  LRows: TJSONArray;
  LRow: TJSONObject;
  LCenters: TJSONArray;
  LCenter: TJSONArray;
  LDecisions: TJSONArray;
  LVector: TAcousticVector;
  LSourceIndex: Integer;
  LIndex: Integer;
  LOther: Integer;
  LPrevious: Integer;
  LSelected: Integer;
  LCount: Integer;
  LOffset: Integer;
  LQuantum: Integer;
  LFade: Integer;
begin
  if (AEventCount < 1) or (AEventCount > MaximumGeneratedAcousticFrames) or
    (APaletteSize < 1) or (APaletteSize > MaximumAcousticVocabulary) then
  begin
    raise EAudio.Create('Event remix requires 1..1024 events and 1..32 palette classes');
  end;
  for LIndex := 0 to 2 do
  begin
    LDestination := AOutput;
    if LIndex = 1 then
    begin
      LDestination := AOutput + '.json';
    end;
    if LIndex = 2 then
    begin
      LDestination := AOutput + '.wfcs';
    end;
    if SameFileName(ExpandFileName(LDestination), ExpandFileName(AArchive)) or
      SameFileName(ExpandFileName(LDestination), ExpandFileName(ASourcePath)) or
      SameFileName(ExpandFileName(LDestination), ExpandFileName(AOnsets)) then
    begin
      raise EAudio.Create('Event remix output must not replace an input');
    end;
  end;
  LCorpus := nil;
  LSource := nil;
  LOutput := nil;
  LPalette := nil;
  LModel := nil;
  LOnsets := nil;
  LDocument := nil;
  try
    LBytes := ReadFileBytes(AArchive, MaximumCorpusArchiveBytes);
    LArchiveHash := HashAudioBytes(LBytes);
    LCorpus := DecodeAcousticArchive(LBytes, LContract, LAttachment);
    LSource := LoadWaveSource(ASourcePath, LSourceHash);
    LSourceIndex := -1;
    for LIndex := 0 to LCorpus.SourceCount - 1 do
    begin
      if LCorpus.SourceInfoAt(LIndex).Sha256 = LSourceHash then
      begin
        LSourceIndex := LIndex;
      end;
    end;
    if LSourceIndex < 0 then
    begin
      raise EAudio.Create('Exact source WAV is absent from the measured corpus');
    end;
    LInfo := LCorpus.SourceInfoAt(LSourceIndex);
    if (LInfo.FrameCount <> LSource.FrameCount) or
      (LInfo.SampleRate <> LSource.SampleRate) or (LInfo.Channels <> LSource.Channels) then
    begin
      raise EAudio.Create('Decoded source format differs from the measured corpus');
    end;
    LBytes := ReadFileBytes(AOnsets, 16 * 1024 * 1024);
    LOnsetHash := HashAudioBytes(LBytes);
    LOnsetText := '';
    if Length(LBytes) > 0 then
    begin
      SetString(LOnsetText, PAnsiChar(@LBytes[0]), Length(LBytes));
    end;
    LOnsets := GetJSON(LOnsetText);
    if not (LOnsets is TJSONObject) then
    begin
      raise EAudio.Create('Onset report must be a JSON object');
    end;
    LLocations := ReadLocations(TJSONObject(LOnsets), LSource, LSourceHash);
    LEventOptions := DefaultOnsetEventOptions(LSource.SampleRate);
    LPlan := PlanOnsetEvents(LLocations, LSource.FrameCount, LEventOptions);
    if High(LPlan.Bounds) < 3 then
    begin
      raise EAudio.Create('Event learning requires at least two admitted interior onset boundaries');
    end;
    if APulses then
    begin
      LPulses := PreparePulseEvents(LLocations, LPlan, LSource.SampleRate, LSource.FrameCount);
      if LPulses.Plan.SelectedCount < 3 then
      begin
        raise EAudio.Create('Pulse learning requires at least three admitted source intervals');
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
      SetLength(LRuns, Length(LFeatures));
      LAdmittedFeatures := LFeatures;
    end;
    LPalette := TAcousticPalette.Create(LAdmittedFeatures, APaletteSize);
    LClasses := LPalette.Encode(LFeatures);
    LQuantum := Max(1, LSource.SampleRate div 50);
    SetLength(LSymbols, Length(LClasses));
    SetLength(LSourceTokens, Length(LClasses));
    for LIndex := 0 to High(LClasses) do
    begin
      if LRuns[LIndex] < 0 then
      begin
        Continue;
      end;
      LSymbols[LIndex] := AcousticEventSymbol(LClasses[LIndex],
        LPlan.Bounds[LIndex + 1] - LPlan.Bounds[LIndex], LQuantum,
        LPlan.LocationIndices[LIndex] >= 0);
      LSourceTokens[LIndex] := AcousticEventToken(LSymbols[LIndex]);
    end;
    LTraining := PartitionAcousticEvents(LSymbols, LRuns);
    LModel := LearnAcousticEventModel(LTraining, LPalette, 2);
    LOptions := DefaultAcousticGenerationOptions;
    LOptions.FrameCount := AEventCount;
    LOptions.Seed := ASeed;
    LOptions.Extent := wseFragment;
    LConstraints := nil;
    if not TryGenerateTokenSequence(LModel, LOptions, LConstraints, LGenerated, LSolveReport) then
    begin
      raise EAudio.CreateFmt('Event WFC generation failed with status %d; output preserved',
        [Ord(LSolveReport.Status)]);
    end;
    SetLength(LIndices, Length(LGenerated));
    SetLength(LCandidates, Length(LSourceTokens));
    LPrevious := -2;
    for LIndex := 0 to High(LGenerated) do
    begin
      ParseAcousticEventToken(LGenerated[LIndex]);
      LSelected := -1;
      if (LPrevious >= 0) and (LPrevious + 1 < Length(LSourceTokens)) and
        (LSourceTokens[LPrevious + 1] = LGenerated[LIndex]) then
      begin
        LSelected := LPrevious + 1;
      end;
      if LSelected < 0 then
      begin
        LCount := 0;
        for LOther := 0 to High(LSourceTokens) do
        begin
          if LSourceTokens[LOther] = LGenerated[LIndex] then
          begin
            LCandidates[LCount] := LOther;
            Inc(LCount);
          end;
        end;
        if LCount = 0 then
        begin
          raise EAudio.Create('Generated event has no matching recorded member');
        end;
        LSelected := LCandidates[(QWord(ASeed) + QWord(LIndex) * 2654435761) mod QWord(LCount)];
      end;
      LIndices[LIndex] := LSelected;
      LPrevious := LSelected;
    end;
    LFade := Max(1, LSource.SampleRate div 1000);
    LOutput := RenderPassages(LSource, LPlan.Bounds, LIndices, LFade);
    LBytes := EncodeWavePcm16(LOutput);
    LModelText := EncodeWfcSequenceText(LModel);
    LDocument := TJSONObject.Create;
    if APulses then
    begin
      LDocument.Add('contract', 'pythian.pulse.remix.v1');
      LDocument.Add('pulse_analysis', PulseEventsJson(LPulses, LSource.SampleRate));
    end
    else
    begin
      LDocument.Add('contract', 'pythian.event.remix.v1');
    end;
    LDocument.Add('method', 'Order-2 WFC on acoustic class, measured duration class and source-onset status');
    if APulses then
    begin
      LDocument.Add('timing', 'Exact source intervals between admitted pulse hypotheses; independent runs; no time stretching or meter inference');
    end
    else
    begin
      LDocument.Add('timing', 'Original source interval durations; no beat inference, time stretching or PPQ grid');
    end;
    LDocument.Add('source', String(LInfo.Name));
    LDocument.Add('provenance', String(LInfo.Provenance));
    LDocument.Add('source_sha256', LSourceHash);
    LDocument.Add('archive_sha256', LArchiveHash);
    LDocument.Add('onset_report_sha256', LOnsetHash);
    LDocument.Add('onset_report', LOnsets.Clone);
    LDocument.Add('archive_attachment_used', False);
    LDocument.Add('onset_report_reanalyzed', False);
    LDocument.Add('model_sha256', HashText(LModelText));
    LDocument.Add('output_sha256', HashAudioBytes(LBytes));
    LDocument.Add('source_frames', LSource.FrameCount);
    LDocument.Add('output_frames', LOutput.FrameCount);
    LDocument.Add('sample_rate', LSource.SampleRate);
    LDocument.Add('channels', LSource.Channels);
    LDocument.Add('duration_quantum_frames', LQuantum);
    LDocument.Add('minimum_event_frames', LEventOptions.MinimumFrames);
    LDocument.Add('allow_clipped_context', LEventOptions.AllowClippedContext);
    LDocument.Add('allow_search_boundary', LEventOptions.AllowSearchBoundary);
    LDocument.Add('fade_frames', LFade);
    LDocument.Add('seed', Int64(ASeed));
    LDocument.Add('extent', 'fragment');
    LDocument.Add('event_version', OnsetEventVersion);
    LDocument.Add('adapter_version', WfcEventAdapterVersion);
    LDocument.Add('palette_limit', APaletteSize);
    LDocument.Add('max_backtracks', LOptions.MaxBacktracks);
    LDocument.Add('wfc_solver_version', LSolveReport.SolverAlgorithmVersion);
    LDocument.Add('wfc_random_version', LSolveReport.RandomAlgorithmVersion);
    LCenters := TJSONArray.Create;
    LDocument.Add('palette_centers', LCenters);
    for LIndex := 0 to LPalette.Count - 1 do
    begin
      LCenter := TJSONArray.Create;
      LCenters.Add(LCenter);
      LVector := LPalette.CenterAt(LIndex);
      for LOther := 0 to High(LVector) do
      begin
        LCenter.Add(LVector[LOther]);
      end;
    end;
    LDecisions := TJSONArray.Create;
    LDocument.Add('location_decisions', LDecisions);
    for LIndex := 0 to High(LPlan.Decisions) do
    begin
      LDecisions.Add(OnsetEventDecisionName(LPlan.Decisions[LIndex]));
    end;
    LRows := TJSONArray.Create;
    LDocument.Add('source_events', LRows);
    for LIndex := 0 to High(LSourceTokens) do
    begin
      LRow := TJSONObject.Create;
      LRows.Add(LRow);
      LRow.Add('token', LSourceTokens[LIndex]);
      LRow.Add('source_start_frame', LPlan.Bounds[LIndex]);
      LRow.Add('frame_count', LPlan.Bounds[LIndex + 1] - LPlan.Bounds[LIndex]);
      LRow.Add('location_index', LPlan.LocationIndices[LIndex]);
      if APulses then
      begin
        LRow.Add('run_index', LRuns[LIndex]);
      end;
    end;
    LRows := TJSONArray.Create;
    LDocument.Add('events', LRows);
    LOffset := 0;
    for LIndex := 0 to High(LIndices) do
    begin
      LSelected := LIndices[LIndex];
      LCount := LPlan.Bounds[LSelected + 1] - LPlan.Bounds[LSelected];
      LRow := TJSONObject.Create;
      LRows.Add(LRow);
      LRow.Add('token', LGenerated[LIndex]);
      LRow.Add('source_event', LSelected);
      LRow.Add('source_start_frame', LPlan.Bounds[LSelected]);
      LRow.Add('output_start_frame', LOffset);
      LRow.Add('frame_count', LCount);
      Inc(LOffset, LCount);
    end;
    WriteFileBytes(AOutput, LBytes);
    WriteTextFile(AOutput + '.wfcs', LModelText);
    WriteTextFile(AOutput + '.json', LDocument.FormatJSON);
    WriteLn('Rendered ', Length(LIndices), ' learned events from ', Length(LSourceTokens),
      ' source intervals into ', LOutput.FrameCount, ' frames; ',
      LModel.PublicTokenCount, ' joint tokens, ', LModel.StateCount, ' WFC states');
  finally
    LDocument.Free;
    LOnsets.Free;
    LModel.Free;
    LPalette.Free;
    LOutput.Free;
    LSource.Free;
    LCorpus.Free;
  end;
end;

procedure Main;
var
  LSeed: QWord;
  LPalette: Integer;
  LArgumentCount: Integer;
  LPulses: Boolean;
begin
  LPulses := (ParamCount > 0) and (ParamStr(ParamCount) = '--pulses');
  LArgumentCount := ParamCount - Ord(LPulses);
  if (LArgumentCount < 6) or (LArgumentCount > 7) then
  begin
    raise EAudio.Create('Usage: pythian.event.remix INPUT.pyac SOURCE.wav ONSETS.json ' +
      'OUTPUT.wav SEED EVENTS [PALETTE_SIZE] [--pulses]');
  end;
  if not TryStrToQWord(ParamStr(5), LSeed) or (LSeed > High(TGraphSeed)) then
  begin
    raise EAudio.Create('Seed must fit the WFC seed type');
  end;
  LPalette := 8;
  if LArgumentCount = 7 then
  begin
    LPalette := StrToInt(ParamStr(7));
  end;
  Remix(ParamStr(1), ParamStr(2), ParamStr(3), ParamStr(4),
    LSeed, StrToInt(ParamStr(6)), LPalette, LPulses);
end;

begin
  try
    Main;
  except
    on LException: Exception do
    begin
      WriteLn(StdErr, LException.ClassName, ': ', LException.Message);
      Halt(1);
    end;
  end;
end.
