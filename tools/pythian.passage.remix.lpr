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
program pythian_passage_remix;

{$mode delphi}
{$H+}

uses
  SysUtils,
  fpjson,
  pythian.audio,
  pythian.wave,
  pythian.passage,
  pythian.analysis,
  pythian.learning,
  pythian.corpus,
  pythian.corpus.archive,
  pythian.wfc.learning,
  pythian.wfc.generation,
  pythian.tools.files,
  wfc,
  wfc_sequence,
  wfc_sequence_text;

procedure Remix(const AArchive, ASourcePath, AOutput: String;
  const ASeed: TGraphSeed; const ABarCount, APaletteSize: Integer);
var
  LCorpus: TAcousticCorpusData;
  LSource: TAudioClip;
  LOutput: TAudioClip;
  LPalette: TAcousticPalette;
  LModel: TWfcSequenceModel;
  LDocument: TJSONObject;
  LBytes: TAudioBytes;
  LAttachment: TAudioBytes;
  LContract: UTF8String;
  LSourceHash: String;
  LArchiveHash: String;
  LInfo: TAcousticSourceInfo;
  LLoop: TWaveLoopInfo;
  LBounds: TPassageBounds;
  LPassages: TPassageIndices;
  LPins: TPassageIndices;
  LCandidates: TPassageIndices;
  LFeatures: TAudioFeatures;
  LTraining: TAcousticCorpus;
  LTokens: TAcousticIndices;
  LConstraints: TWfcSequenceTokenConstraints;
  LOptions: TAcousticGenerationOptions;
  LReport: TGraphSolveReport;
  LEvents: TJSONArray;
  LEvent: TJSONObject;
  LCenters: TJSONArray;
  LCenter: TJSONArray;
  LVector: TAcousticVector;
  LSourceTokens: TJSONArray;
  LModelText: String;
  LSourceIndex: Integer;
  LIndex: Integer;
  LOther: Integer;
  LCount: Integer;
  LSelected: Integer;
  LPrevious: Integer;
  LOffset: Integer;
  LFade: Integer;
  LDeclaredTempo: Double;
  LDestination: String;
begin
  if (ABarCount < 16) or (ABarCount > 64) or
    (APaletteSize < 1) or (APaletteSize > MaximumAcousticVocabulary) then
  begin
    raise EAudio.Create('Request requires 16..64 output bars and 1..32 palette tokens');
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
    if (CompareText(ExpandFileName(LDestination), ExpandFileName(AArchive)) = 0) or
      (CompareText(ExpandFileName(LDestination), ExpandFileName(ASourcePath)) = 0) then
    begin
      raise EAudio.Create('Passage output must not replace an input');
    end;
  end;
  LCorpus := nil;
  LSource := nil;
  LOutput := nil;
  LPalette := nil;
  LModel := nil;
  LDocument := nil;
  try
    LBytes := ReadFileBytes(AArchive, MaximumCorpusArchiveBytes);
    LArchiveHash := HashAudioBytes(LBytes);
    LCorpus := DecodeAcousticArchive(LBytes, LContract, LAttachment);
    LBytes := ReadFileBytes(ASourcePath, MaximumWaveBytes);
    LSourceHash := HashAudioBytes(LBytes);
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
    LLoop := ReadWaveLoopInfo(LBytes);
    LSource := DecodeWave(LBytes);
    if (LSource.FrameCount <> LInfo.FrameCount) or
      (LSource.SampleRate <> LInfo.SampleRate) or (LSource.Channels <> LInfo.Channels) then
    begin
      raise EAudio.Create('Decoded source format differs from corpus');
    end;
    LBounds := LoopBarBounds(LLoop, LSource.FrameCount, LSource.SampleRate);
    if High(LBounds) < 8 then
    begin
      raise EAudio.Create('Opening/reprise/ending policy requires at least eight source bars');
    end;
    LFeatures := MeasurePassages(LCorpus, LSourceIndex, LBounds);
    LPalette := TAcousticPalette.Create(LFeatures, APaletteSize);
    SetLength(LTraining, 1);
    LTraining[0] := LPalette.Encode(LFeatures);
    LModel := LearnAcousticModel(LTraining, LPalette, 2);

    { An authored form, distinct from the learned local transition model.
      Four opening bars return eight bars before the end; the last four
      bars use the recording's ending. All three regions also constrain WFC. }
    SetLength(LPins, ABarCount);
    for LIndex := 0 to High(LPins) do
    begin
      LPins[LIndex] := -1;
    end;
    for LIndex := 0 to 3 do
    begin
      LPins[LIndex] := LIndex;
      LPins[ABarCount - 8 + LIndex] := LIndex;
      LPins[ABarCount - 4 + LIndex] := High(LBounds) - 4 + LIndex;
    end;
    SetLength(LConstraints, 12);
    LCount := 0;
    for LIndex := 0 to High(LPins) do
    begin
      if LPins[LIndex] >= 0 then
      begin
        LConstraints[LCount].Position := LIndex;
        SetLength(LConstraints[LCount].AllowedTokens, 1);
        LConstraints[LCount].AllowedTokens[0] := AcousticToken(LTraining[0][LPins[LIndex]]);
        Inc(LCount);
      end;
    end;
    LOptions := DefaultAcousticGenerationOptions;
    LOptions.FrameCount := ABarCount;
    LOptions.Seed := ASeed;
    LOptions.Extent := wseWhole;
    LOptions.MaxBacktracks := 4096;
    if not TryGenerateAcousticSequence(LModel, LOptions, LConstraints, LTokens, LReport) then
    begin
      if LReport.Status = gssBacktrackLimit then
      begin
        raise EAudio.Create('Passage WFC backtrack budget exhausted; output preserved');
      end;
      raise EAudio.Create('Opening/reprise/ending contradict learned passage model; output preserved');
    end;

    SetLength(LPassages, ABarCount);
    LPrevious := -1;
    for LIndex := 0 to High(LPassages) do
    begin
      LSelected := LPins[LIndex];
      if LSelected < 0 then
      begin
        { Prefer a continuing source bar when it belongs to the generated class.
          Otherwise choose a class member deterministically from seed/position. }
        if (LPrevious + 1 < Length(LTraining[0])) and
          (LTraining[0][LPrevious + 1] = LTokens[LIndex]) then
        begin
          LSelected := LPrevious + 1;
        end
        else
        begin
          LCandidates := nil;
          for LOther := 0 to High(LTraining[0]) do
          begin
            if LTraining[0][LOther] = LTokens[LIndex] then
            begin
              SetLength(LCandidates, Length(LCandidates) + 1);
              LCandidates[High(LCandidates)] := LOther;
            end;
          end;
          if Length(LCandidates) = 0 then
          begin
            raise EAudio.Create('Generated passage token has no recorded member');
          end;
          LSelected := LCandidates[(QWord(ASeed) + QWord(LIndex) * 2654435761)
            mod QWord(Length(LCandidates))];
        end;
      end;
      if LTraining[0][LSelected] <> LTokens[LIndex] then
      begin
        raise EAudio.Create('Recorded passage violates generated token');
      end;
      LPassages[LIndex] := LSelected;
      LPrevious := LSelected;
    end;
    LFade := LSource.SampleRate div 200;
    LOutput := RenderPassages(LSource, LBounds, LPassages, LFade);
    LBytes := EncodeWavePcm16(LOutput);
    LModelText := EncodeWfcSequenceText(LModel);
    LDocument := TJSONObject.Create;
    LDocument.Add('contract', 'pythian.passage.remix.v1');
    LDocument.Add('method', 'Order-2 WFC on measured full-bar acoustic classes');
    LDocument.Add('form', 'Four opening bars, generated middle, four-bar reprise, four source ending bars');
    LDocument.Add('downbeat_assumption', 'Source frame zero; source metadata does not annotate attacks');
    LDocument.Add('source', String(LInfo.Name));
    LDocument.Add('provenance', String(LInfo.Provenance));
    LDocument.Add('source_sha256', LSourceHash);
    LDocument.Add('archive_sha256', LArchiveHash);
    LDocument.Add('archive_attachment_used', False);
    LDocument.Add('model_sha256', HashText(LModelText));
    LDocument.Add('output_sha256', HashAudioBytes(LBytes));
    LDocument.Add('source_frames', LSource.FrameCount);
    LDocument.Add('output_frames', LOutput.FrameCount);
    LDocument.Add('sample_rate', LSource.SampleRate);
    LDocument.Add('channels', LSource.Channels);
    LDeclaredTempo := LLoop.TempoBpm;
    LDocument.Add('declared_tempo_bpm', LDeclaredTempo);
    LDocument.Add('declared_beats', Int64(LLoop.BeatCount));
    LDocument.Add('meter_numerator', Integer(LLoop.MeterNumerator));
    LDocument.Add('meter_denominator', Integer(LLoop.MeterDenominator));
    LDocument.Add('fade_frames', LFade);
    LDocument.Add('seed', Int64(ASeed));
    LDocument.Add('extent', 'whole');
    LDocument.Add('passage_version', PassageVersion);
    LDocument.Add('palette_limit', APaletteSize);
    LDocument.Add('max_backtracks', LOptions.MaxBacktracks);
    LDocument.Add('wfc_solver_version', LReport.SolverAlgorithmVersion);
    LDocument.Add('wfc_random_version', LReport.RandomAlgorithmVersion);
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
    LSourceTokens := TJSONArray.Create;
    LDocument.Add('source_bar_tokens', LSourceTokens);
    for LIndex := 0 to High(LTraining[0]) do
    begin
      LSourceTokens.Add(LTraining[0][LIndex]);
    end;
    LEvents := TJSONArray.Create;
    LDocument.Add('passages', LEvents);
    LOffset := 0;
    for LIndex := 0 to High(LPassages) do
    begin
      LSelected := LPassages[LIndex];
      LCount := LBounds[LSelected + 1] - LBounds[LSelected];
      LEvent := TJSONObject.Create;
      LEvents.Add(LEvent);
      LEvent.Add('token', LTokens[LIndex]);
      LEvent.Add('source_bar', LSelected);
      LEvent.Add('pinned', LPins[LIndex] >= 0);
      LEvent.Add('source_start_frame', LBounds[LSelected]);
      LEvent.Add('output_start_frame', LOffset);
      LEvent.Add('frame_count', LCount);
      Inc(LOffset, LCount);
    end;
    { All validation/rendering precedes publication. Multiple output files are
      still separate writes; a filesystem failure can leave a partial set. }
    WriteFileBytes(AOutput, LBytes);
    WriteTextFile(AOutput + '.wfcs', LModelText);
    WriteTextFile(AOutput + '.json', LDocument.FormatJSON);
    WriteLn('Rendered ', ABarCount, ' bars at declared ', LLoop.TempoBpm:0:3,
      ' BPM into ', LOutput.FrameCount, ' frames; ', LPalette.Count,
      ' acoustic classes and ', LModel.StateCount, ' WFC states');
    Write('Source bars (zero based):');
    for LIndex := 0 to High(LPassages) do
    begin
      Write(' ', LPassages[LIndex]);
    end;
    WriteLn;
  finally
    LDocument.Free;
    LModel.Free;
    LPalette.Free;
    LOutput.Free;
    LSource.Free;
    LCorpus.Free;
  end;
end;

var
  LSeed: QWord;
  LPaletteSize: Integer;
begin
  try
    if (ParamCount < 5) or (ParamCount > 6) then
    begin
      WriteLn('Usage: pythian.passage.remix INPUT.pyac SOURCE.wav OUTPUT.wav SEED BARS [PALETTE_SIZE]');
      Halt(2);
    end;
    if not TryStrToQWord(ParamStr(4), LSeed) or (LSeed > High(TGraphSeed)) then
    begin
      raise EAudio.Create('Seed must fit the WFC seed type');
    end;
    LPaletteSize := 4;
    if ParamCount = 6 then
    begin
      LPaletteSize := StrToInt(ParamStr(6));
    end;
    Remix(ParamStr(1), ParamStr(2), ParamStr(3), LSeed, StrToInt(ParamStr(5)), LPaletteSize);
  except
    on LException: Exception do
    begin
      WriteLn(StdErr, LException.ClassName, ': ', LException.Message);
      Halt(1);
    end;
  end;
end.
