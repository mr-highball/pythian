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
program pythian_event_merge;

{$mode delphi}
{$H+}

uses
  SysUtils, Math, fpjson, jsonparser,
  pythian.audio, pythian.wave, pythian.granular, pythian.passage,
  pythian.corpus, pythian.corpus.archive, pythian.onset, pythian.onset.events,
  pythian.wfc.event.corpus, pythian.wfc.event.archive, pythian.wfc.generation,
  pythian.tools.files, pythian.tools.events, pythian.tools.pulses,
  wfc, wfc_model, wfc_sequence, wfc_sequence_text;

procedure Generate(const ALearning: TRecordedEventLearning;
  const ASources: TAudioSources; const ASourceMap: TPassageIndices;
  const AOptions: TAcousticGenerationOptions; const AOutputPath: String;
  const ADocument: TJSONObject; const AArchiveBytes: TAudioBytes);
var
  LMember: TRecordedEventMember;
  LPassages: TRecordedPassages;
  LSelection: TPassageIndices;
  LGenerated: TWfcModelTokens;
  LConstraints: TWfcSequenceTokenConstraints;
  LSolveReport: TGraphSolveReport;
  LRows: TJSONArray;
  LRow: TJSONObject;
  LVector: TJSONArray;
  LClip: TAudioClip;
  LBytes: TAudioBytes;
  LModelText: String;
  LOffset: Integer;
  LFade: Integer;
  I: Integer;
  K: Integer;
begin
  LClip := nil;
  try
    LConstraints := nil;
    if not TryGenerateTokenSequence(ALearning.Model, AOptions, LConstraints,
      LGenerated, LSolveReport) then
    begin
      raise EAudio.CreateFmt('Event merge solve failed with status %d', [Ord(LSolveReport.Status)]);
    end;
    LSelection := ALearning.SelectMembers(LGenerated, AOptions.Seed);
    SetLength(LPassages, Length(LSelection));
    LRows := TJSONArray.Create;
    ADocument.Add('events', LRows);
    LOffset := 0;
    for I := 0 to High(LSelection) do
    begin
      LMember := ALearning.MemberAt(LSelection[I]);
      LPassages[I] := LMember.Passage;
      LPassages[I].SourceIndex := ASourceMap[LMember.Passage.SourceIndex];
      LRow := TJSONObject.Create;
      LRows.Add(LRow);
      LRow.Add('member_index', LSelection[I]);
      LRow.Add('token', LMember.Token);
      LRow.Add('source_index', LMember.Passage.SourceIndex);
      LRow.Add('source_start_frame', LMember.Passage.StartFrame);
      LRow.Add('frame_count', LMember.Passage.FrameCount);
      LRow.Add('run_index', LMember.RunIndex);
      LRow.Add('output_start_frame', LOffset);
      Inc(LOffset, LMember.Passage.FrameCount);
    end;
    LFade := Max(1, ASources[0].SampleRate div 1000);
    LClip := RenderPassages(ASources, LPassages, LFade);
    LBytes := EncodeWavePcm16(LClip);
    LModelText := EncodeWfcSequenceText(ALearning.Model);
    ADocument.Add('duration_quantum_frames', ALearning.QuantumFrames);
    ADocument.Add('member_count', ALearning.MemberCount);
    ADocument.Add('training_runs', ALearning.RunCount);
    ADocument.Add('public_tokens', ALearning.Model.PublicTokenCount);
    ADocument.Add('states', ALearning.Model.StateCount);
    ADocument.Add('max_backtracks', AOptions.MaxBacktracks);
    ADocument.Add('wfc_solver_version', LSolveReport.SolverAlgorithmVersion);
    ADocument.Add('wfc_random_version', LSolveReport.RandomAlgorithmVersion);
    ADocument.Add('sample_rate', LClip.SampleRate);
    ADocument.Add('channels', LClip.Channels);
    ADocument.Add('output_frames', LClip.FrameCount);
    ADocument.Add('fade_frames', LFade);
    ADocument.Add('model_sha256', HashText(LModelText));
    ADocument.Add('output_sha256', HashAudioBytes(LBytes));
    LRows := TJSONArray.Create;
    ADocument.Add('palette_centers', LRows);
    for I := 0 to ALearning.Palette.Count - 1 do
    begin
      LVector := TJSONArray.Create;
      LRows.Add(LVector);
      for K := 0 to 14 do
      begin
        LVector.Add(ALearning.Palette.CenterAt(I)[K]);
      end;
    end;
    ADocument.Add('saved_learning_sha256', HashAudioBytes(AArchiveBytes));
    WriteFileBytes(AOutputPath, LBytes);
    WriteTextFile(AOutputPath + '.wfcs', LModelText);
    WriteTextFile(AOutputPath + '.json', ADocument.FormatJSON);
    WriteFileBytes(AOutputPath + '.pyac', AArchiveBytes);
    WriteLn('Merged ', Length(ASources), ' recordings: ', ALearning.MemberCount, ' events in ',
      ALearning.RunCount, ' independent runs; ', ALearning.Model.PublicTokenCount,
      ' tokens / ', ALearning.Model.StateCount, ' states; rendered ',
      Length(LSelection), ' events / ', LClip.FrameCount, ' frames');
  finally
    LClip.Free;
  end;
end;

procedure Run;
var
  LCorpus: TAcousticCorpusData;
  LLearning: TRecordedEventLearning;
  LSources: TAudioSources;
  LInputs: TRecordedEventInputs;
  LSourceMap: TPassageIndices;
  LLocations: TOnsetLocations;
  LPlan: TOnsetEventPlan;
  LPulse: TPreparedPulseEvents;
  LInfo: TAcousticSourceInfo;
  LOptions: TAcousticGenerationOptions;
  LBytes: TAudioBytes;
  LAttachment: TAudioBytes;
  LArchiveBytes: TAudioBytes;
  LPolicy: UTF8String;
  LContract: UTF8String;
  LArchiveHash: String;
  LHash: String;
  LText: String;
  LOutputPath: String;
  LDestination: String;
  LDocument: TJSONObject;
  LOnsetDocument: TJSONData;
  LSourceRows: TJSONArray;
  LInputRows: TJSONArray;
  LRow: TJSONObject;
  LSeed: QWord;
  LCount: Integer;
  LArgCount: Integer;
  LSourceIndex: Integer;
  LPulses: Boolean;
  I: Integer;
  J: Integer;
begin
  LPulses := (ParamCount > 0) and (ParamStr(ParamCount) = '--pulses');
  LArgCount := ParamCount - Ord(LPulses);
  if (LArgCount < 6) or ((LArgCount - 4) mod 2 <> 0) or
    ((LArgCount - 4) div 2 > MaximumCorpusSources) then
  begin
    raise EAudio.Create('Usage: pythian.event.merge INPUT.pyac OUTPUT.wav SEED EVENTS ' +
      'SOURCE.wav ONSETS.json [SOURCE.wav ONSETS.json ...] [--pulses]');
  end;
  if not TryStrToQWord(ParamStr(3), LSeed) or (LSeed > High(TGraphSeed)) then
  begin
    raise EAudio.Create('Seed must fit the WFC seed type');
  end;
  LOptions := DefaultAcousticGenerationOptions;
  LOptions.FrameCount := StrToInt(ParamStr(4));
  if (LOptions.FrameCount < 1) or (LOptions.FrameCount > 1024) then
  begin
    raise EAudio.Create('Event output requires 1..1024 selections');
  end;
  LOptions.Seed := LSeed;
  LOptions.Extent := wseFragment;
  LOutputPath := ParamStr(2);
  for I := 0 to 3 do
  begin
    LDestination := LOutputPath;
    if I = 1 then
    begin
      LDestination := LOutputPath + '.json';
    end;
    if I = 2 then
    begin
      LDestination := LOutputPath + '.wfcs';
    end;
    if I = 3 then
    begin
      LDestination := LOutputPath + '.pyac';
    end;
    for J := 1 to LArgCount do
    begin
      if (J = 1) or (J >= 5) then
      begin
        if SameFileName(ExpandFileName(LDestination), ExpandFileName(ParamStr(J))) then
        begin
          raise EAudio.Create('Event merge output must not replace an input');
        end;
      end;
    end;
  end;
  LCorpus := nil;
  LLearning := nil;
  LDocument := nil;
  LOnsetDocument := nil;
  try
    LBytes := ReadFileBytes(ParamStr(1), MaximumCorpusArchiveBytes);
    LArchiveHash := HashAudioBytes(LBytes);
    LCorpus := DecodeAcousticArchive(LBytes, LContract, LAttachment);
    LCount := (LArgCount - 4) div 2;
    SetLength(LInputs, LCount);
    SetLength(LSources, LCount);
    SetLength(LSourceMap, LCorpus.SourceCount);
    for I := 0 to High(LSourceMap) do
    begin
      LSourceMap[I] := -1;
    end;
    LDocument := TJSONObject.Create;
    LDocument.Add('contract', 'pythian.event.merge.v1');
    LDocument.Add('event_learning_version', RecordedEventLearningVersion);
    LDocument.Add('onset_event_version', OnsetEventVersion);
    LDocument.Add('weighting', 'One observation per admitted event; separate source/run samples');
    LDocument.Add('archive_sha256', LArchiveHash);
    LDocument.Add('archive_attachment_used', False);
    LDocument.Add('pulse_mode', LPulses);
    LDocument.Add('seed', Int64(LSeed));
    LDocument.Add('order', 2);
    LDocument.Add('palette_limit', 8);
    LDocument.Add('extent', 'fragment');
    LDocument.Add('timing', 'Original source intervals; no time stretching, beat or voice separation claim');
    LSourceRows := TJSONArray.Create;
    LDocument.Add('sources', LSourceRows);
    for I := 0 to LCount - 1 do
    begin
      LSources[I] := LoadWaveSource(ParamStr(5 + I * 2), LHash);
      LSourceIndex := -1;
      for J := 0 to LCorpus.SourceCount - 1 do
      begin
        if LCorpus.SourceInfoAt(J).Sha256 = LHash then
        begin
          LSourceIndex := J;
        end;
      end;
      if LSourceIndex < 0 then
      begin
        raise EAudio.Create('Exact event source is absent from measured corpus');
      end;
      if LSourceMap[LSourceIndex] >= 0 then
      begin
        raise EAudio.Create('Repeated source has no explicit weighting policy');
      end;
      LSourceMap[LSourceIndex] := I;
      LInfo := LCorpus.SourceInfoAt(LSourceIndex);
      if (LInfo.SampleRate <> LSources[I].SampleRate) or
        (LInfo.Channels <> LSources[I].Channels) or
        (LInfo.FrameCount <> LSources[I].FrameCount) then
      begin
        raise EAudio.Create('Decoded source format differs from measured corpus');
      end;
      LBytes := ReadFileBytes(ParamStr(6 + I * 2), 16 * 1024 * 1024);
      LText := '';
      if Length(LBytes) > 0 then
      begin
        SetString(LText, PAnsiChar(@LBytes[0]), Length(LBytes));
      end;
      LOnsetDocument := GetJSON(LText);
      if not (LOnsetDocument is TJSONObject) then
      begin
        raise EAudio.Create('Onset report must be an object');
      end;
      LLocations := ReadLocations(TJSONObject(LOnsetDocument), LSources[I], LHash);
      LPlan := PlanOnsetEvents(LLocations, LSources[I].FrameCount,
        DefaultOnsetEventOptions(LSources[I].SampleRate));
      LInputs[I].SourceIndex := LSourceIndex;
      LRow := TJSONObject.Create;
      LSourceRows.Add(LRow);
      LRow.Add('source_index', LSourceIndex);
      LRow.Add('name', String(LInfo.Name));
      LRow.Add('provenance', String(LInfo.Provenance));
      LRow.Add('sha256', LHash);
      LRow.Add('frame_count', LInfo.FrameCount);
      LRow.Add('onset_report_sha256', HashAudioBytes(LBytes));
      if LPulses then
      begin
        LPulse := PreparePulseEvents(LLocations, LPlan, LInfo.SampleRate, LInfo.FrameCount);
        LPlan.Bounds := Copy(LPulse.Plan.Bounds);
        LPlan.LocationIndices := Copy(LPulse.LocationIndices);
        LInputs[I].RunIndices := Copy(LPulse.Plan.RunIndices);
        LRow.Add('pulse_analysis', PulseEventsJson(LPulse, LInfo.SampleRate));
      end
      else
      begin
        SetLength(LInputs[I].RunIndices, High(LPlan.Bounds));
      end;
      LInputs[I].Bounds := Copy(LPlan.Bounds);
      SetLength(LInputs[I].StartsAtOnset, High(LPlan.Bounds));
      LInputRows := TJSONArray.Create;
      LRow.Add('intervals', LInputRows);
      for J := 0 to High(LInputs[I].StartsAtOnset) do
      begin
        LInputs[I].StartsAtOnset[J] := LPlan.LocationIndices[J] >= 0;
        LRow := TJSONObject.Create;
        LInputRows.Add(LRow);
        LRow.Add('start_frame', LPlan.Bounds[J]);
        LRow.Add('frame_count', LPlan.Bounds[J + 1] - LPlan.Bounds[J]);
        LRow.Add('run_index', LInputs[I].RunIndices[J]);
        LRow.Add('starts_at_onset', LInputs[I].StartsAtOnset[J]);
      end;
      FreeAndNil(LOnsetDocument);
    end;
    LLearning := TRecordedEventLearning.Create(LCorpus, LInputs,
      Max(1, LSources[0].SampleRate div 50));
    LPolicy := 'Onset-event defaults v1; accepted source intervals and onset flags';
    if LPulses then
    begin
      LPolicy := 'Pulse-event defaults v1; accepted source intervals, independent runs and onset flags';
    end;
    LArchiveBytes := EncodeRecordedEventCorpus(LCorpus, LLearning, LPolicy);
    LDocument.Add('saved_learning', False);
    LDocument.Add('admission_policy', String(LPolicy));
    Generate(LLearning, LSources, LSourceMap, LOptions, LOutputPath, LDocument, LArchiveBytes);
  finally
    LOnsetDocument.Free;
    LDocument.Free;
    LLearning.Free;
    for I := 0 to High(LSources) do
    begin
      LSources[I].Free;
    end;
    LCorpus.Free;
  end;
end;

procedure RunSaved;
var
  LCorpus: TAcousticCorpusData;
  LLearning: TRecordedEventLearning;
  LInputs: TRecordedEventInputs;
  LSources: TAudioSources;
  LSourceMap: TPassageIndices;
  LBytes: TAudioBytes;
  LPolicy: UTF8String;
  LHash: String;
  LDestination: String;
  LInfo: TAcousticSourceInfo;
  LOptions: TAcousticGenerationOptions;
  LDocument: TJSONObject;
  LRows: TJSONArray;
  LRow: TJSONObject;
  LSeed: QWord;
  LSourceIndex: Integer;
  I: Integer;
  J: Integer;
begin
  if (ParamCount < 6) or (ParamCount > MaximumCorpusSources + 5) then
  begin
    raise EAudio.Create('Usage: pythian.event.merge --load INPUT.pyac OUTPUT.wav ' +
      'SEED EVENTS SOURCE.wav [SOURCE.wav ...]');
  end;
  if not TryStrToQWord(ParamStr(4), LSeed) or (LSeed > High(TGraphSeed)) then
  begin
    raise EAudio.Create('Seed must fit the WFC seed type');
  end;
  LOptions := DefaultAcousticGenerationOptions;
  LOptions.FrameCount := StrToInt(ParamStr(5));
  LOptions.Seed := LSeed;
  LOptions.Extent := wseFragment;
  if (LOptions.FrameCount < 1) or (LOptions.FrameCount > 1024) then
  begin
    raise EAudio.Create('Saved event output requires 1..1024 selections');
  end;
  for I := 0 to 3 do
  begin
    LDestination := ParamStr(3);
    case I of
      1: LDestination := LDestination + '.json';
      2: LDestination := LDestination + '.wfcs';
      3: LDestination := LDestination + '.pyac';
    end;
    for J := 2 to ParamCount do
    begin
      if (J = 2) or (J >= 6) then
      begin
        if SameFileName(ExpandFileName(LDestination), ExpandFileName(ParamStr(J))) then
        begin
          raise EAudio.Create('Saved event output must not replace an input');
        end;
      end;
    end;
  end;
  LCorpus := nil;
  LLearning := nil;
  LDocument := nil;
  try
    LBytes := ReadFileBytes(ParamStr(2), MaximumCorpusArchiveBytes);
    LCorpus := DecodeRecordedEventCorpus(LBytes, LLearning, LPolicy);
    LInputs := LLearning.CopyInputs;
    if Length(LInputs) <> ParamCount - 5 then
    begin
      raise EAudio.Create('Saved event generation requires every admitted source exactly once');
    end;
    SetLength(LSources, Length(LInputs));
    SetLength(LSourceMap, LLearning.SourceCount);
    for I := 0 to High(LSourceMap) do
    begin
      LSourceMap[I] := -1;
    end;
    LDocument := TJSONObject.Create;
    LDocument.Add('contract', 'pythian.event.merge.v1');
    LDocument.Add('event_learning_version', RecordedEventLearningVersion);
    LDocument.Add('archive_sha256', HashAudioBytes(LBytes));
    LDocument.Add('archive_attachment_used', True);
    LDocument.Add('saved_learning', True);
    LDocument.Add('admission_policy', String(LPolicy));
    LDocument.Add('onset_reports_used', False);
    LDocument.Add('seed', Int64(LSeed));
    LDocument.Add('order', LLearning.Model.Order);
    LDocument.Add('extent', 'fragment');
    LRows := TJSONArray.Create;
    LDocument.Add('sources', LRows);
    for I := 0 to High(LSources) do
    begin
      LSources[I] := LoadWaveSource(ParamStr(I + 6), LHash);
      LSourceIndex := -1;
      for J := 0 to High(LInputs) do
      begin
        LInfo := LLearning.SourceInfoAt(LInputs[J].SourceIndex);
        if LInfo.Sha256 = LHash then
        begin
          LSourceIndex := LInputs[J].SourceIndex;
        end;
      end;
      if LSourceIndex < 0 then
      begin
        raise EAudio.Create('Source WAV is absent from saved admitted recordings');
      end;
      if LSourceMap[LSourceIndex] >= 0 then
      begin
        raise EAudio.Create('Duplicate source WAV for saved event generation');
      end;
      LSourceMap[LSourceIndex] := I;
      LInfo := LLearning.SourceInfoAt(LSourceIndex);
      if (LInfo.SampleRate <> LSources[I].SampleRate) or
        (LInfo.Channels <> LSources[I].Channels) or
        (LInfo.FrameCount <> LSources[I].FrameCount) then
      begin
        raise EAudio.Create('Saved source format disagrees with decoded WAV');
      end;
      LRow := TJSONObject.Create;
      LRows.Add(LRow);
      LRow.Add('source_index', LSourceIndex);
      LRow.Add('name', String(LInfo.Name));
      LRow.Add('provenance', String(LInfo.Provenance));
      LRow.Add('sha256', LHash);
      LRow.Add('frame_count', LInfo.FrameCount);
    end;
    Generate(LLearning, LSources, LSourceMap, LOptions, ParamStr(3), LDocument, LBytes);
  finally
    LDocument.Free;
    LLearning.Free;
    LCorpus.Free;
    for I := 0 to High(LSources) do
    begin
      LSources[I].Free;
    end;
  end;
end;

begin
  try
    if (ParamCount > 0) and (ParamStr(1) = '--load') then
    begin
      RunSaved;
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
