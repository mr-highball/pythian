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
program pythian_ensemble_demo;

{$mode delphi}
{$H+}

uses
  Classes,
  SysUtils,
  fpjson,
  pythian.audio,
  pythian.time,
  pythian.chord.stream,
  pythian.wave.stream,
  pythian.wfc.music,
  pythian.wfc.layers,
  pythian.tools.files,
  wfc,
  wfc_model,
  wfc_sequence,
  wfc_sequence_learn,
  wfc_sequence_graph,
  wfc_sequence_text,
  wfc_music,
  wfc_music_sequence,
  wfc_music_ensemble,
  wfc_music_ensemble_passes,
  wfc_music_ensemble_stream,
  wfc_music_ensemble_audio,
  wfc_music_audio,
  wfc_music_arrangement;

const
  CRate = 44100;
  CQuantum = 240;
  CPpq = 480;
  CTempo = 500001;
  CTrainingCells = 32;

procedure Require(const ACondition: Boolean; const AMessage: String);
begin
  if not ACondition then
  begin
    raise EAudio.Create(AMessage);
  end;
end;

function TrainingFrame(const ASample, ACell: Integer): TWfcMusicEnsembleFrame;
const
  CRoots: array[0..1, 0..3] of Integer = ((60, 65, 67, 60), (60, 57, 65, 67));
var
  LRoot: Integer;
  LBass: Integer;
  LThird: Integer;
begin
  Result := Default(TWfcMusicEnsembleFrame);
  LRoot := CRoots[ASample, ACell div 8];
  LThird := 4;
  if LRoot = 57 then
  begin
    LThird := 3;
  end;
  SetLength(Result.Voices, 2);
  Result.Voices[0].Action := wmcaHold;
  if ACell mod 8 = 0 then
  begin
    Result.Voices[0].Action := wmcaAttack;
  end;
  SetLength(Result.Voices[0].Tones, 3);
  Result.Voices[0].Tones[0] := MakeWfcMusicTone(LRoot, 90);
  Result.Voices[0].Tones[1] := MakeWfcMusicTone(LRoot + LThird, 75);
  Result.Voices[0].Tones[2] := MakeWfcMusicTone(LRoot + 7, 80);
  Result.Voices[1].Action := wmcaHold;
  if ACell mod 2 = 0 then
  begin
    Result.Voices[1].Action := wmcaAttack;
  end;
  LBass := LRoot - 24;
  if (ACell div 2) mod 2 = 1 then
  begin
    Inc(LBass, 7);
  end;
  SetLength(Result.Voices[1].Tones, 1);
  Result.Voices[1].Tones[0] := MakeWfcMusicTone(LBass, 105);
end;

function LearnModels: TWfcMusicEnsembleModels;
var
  LSamples: array[TWfcMusicEnsembleLayer] of TWfcSequenceSamples;
  LTokens: array[TWfcMusicEnsembleLayer] of TWfcModelTokens;
  LLayer: TWfcMusicEnsembleLayer;
  LSample: Integer;
  LCell: Integer;
  LFrame: TWfcMusicEnsembleFrame;
  LCandidate: TWfcMusicEnsembleModels;
begin
  LCandidate := Default(TWfcMusicEnsembleModels);
  for LLayer := Low(TWfcMusicEnsembleLayer) to High(TWfcMusicEnsembleLayer) do
  begin
    SetLength(LSamples[LLayer], 2);
    SetLength(LTokens[LLayer], CTrainingCells);
  end;
  for LSample := 0 to 1 do
  begin
    for LCell := 0 to CTrainingCells - 1 do
    begin
      LFrame := TrainingFrame(LSample, LCell);
      LTokens[wmelEnsemble][LCell] := EncodeWfcMusicEnsembleFrame(LFrame);
      LTokens[wmelRhythm][LCell] :=
        EncodeWfcMusicRhythmFrame(ProjectWfcMusicEnsembleFrameToRhythm(LFrame));
      LTokens[wmelHarmony][LCell] :=
        EncodeWfcMusicPitchClassSet(ProjectWfcMusicEnsembleFrameToPitchClassSet(LFrame, 12));
    end;
    for LLayer := Low(TWfcMusicEnsembleLayer) to High(TWfcMusicEnsembleLayer) do
    begin
      LSamples[LLayer][LSample] := MakeWfcSequenceSample(LTokens[LLayer]);
    end;
  end;
  try
    LCandidate.Harmony := LearnSequenceModelCorpus(LSamples[wmelHarmony], 2);
    LCandidate.Rhythm := LearnSequenceModelCorpus(LSamples[wmelRhythm], 2);
    LCandidate.Ensemble := LearnSequenceModelCorpus(LSamples[wmelEnsemble], 2);
  except
    LCandidate.Ensemble.Free;
    LCandidate.Rhythm.Free;
    LCandidate.Harmony.Free;
    raise;
  end;
  Result := LCandidate;
end;

procedure Drain(const ARenderer: TChordStreamRenderer;
  const AReference: TWfcMusicEnsembleAudioRenderer; const AWriter: TWavePcm16Writer);
var
  LSamples: TAudioSamples;
  LReference: TWfcMusicPcm16Samples;
  LNativeMore: Boolean;
  LReferenceMore: Boolean;
  LIndex: Integer;
begin
  repeat
    LNativeMore := ARenderer.ReadSamples(997, LSamples);
    if AReference <> nil then
    begin
      LReferenceMore := AReference.ReadSamples(997, LReference);
      Require((LNativeMore = LReferenceMore) and
        (Length(LSamples) = Length(LReference)), 'Reference output block differs');
      for LIndex := 0 to High(LSamples) do
      begin
        Require(LSamples[LIndex] = LReference[LIndex] / 32768,
          'Generated ensemble PCM differs from the actual WFC renderer');
      end;
    end;
    if LNativeMore then
    begin
      AWriter.AppendSamples(LSamples);
    end;
  until not LNativeMore;
end;

function ModelJson(const AModel: TWfcSequenceModel): TJSONObject;
var
  LText: String;
begin
  LText := EncodeWfcSequenceText(AModel);
  Result := TJSONObject.Create;
  Result.Add('text', LText);
  Result.Add('sha256', HashText(LText));
  Result.Add('states', AModel.StateCount);
  Result.Add('public_tokens', AModel.PublicTokenCount);
end;

function PlanPhrase(const AModels: TWfcMusicEnsembleModels; const ACells: Integer;
  const ASeed: TGraphSeed; const AEnding: String): TLayerSequences;
var
  LLayers: TLearnedLayers;
  LOptions: TLayerGenerationOptions;
  LReport: TGraphNegotiationReport;
  LAllowed: TWfcModelTokens;
  LRhythm: String;
  LToken: String;
  LFrame: TWfcMusicEnsembleFrame;
  LCell: Integer;
  LIndex: Integer;
  LCount: Integer;
begin
  Result := nil;
  SetLength(LLayers, 1);
  LLayers[0].Model := AModels.Ensemble;
  SetLength(LLayers[0].Constraints, ACells);
  for LCell := 0 to ACells - 1 do
  begin
    LRhythm := EncodeWfcMusicRhythmFrame(ProjectWfcMusicEnsembleFrameToRhythm(
      TrainingFrame(0, LCell mod CTrainingCells)));
    SetLength(LAllowed, AModels.Ensemble.PublicTokenCount);
    LCount := 0;
    for LIndex := 0 to AModels.Ensemble.PublicTokenCount - 1 do
    begin
      LToken := AModels.Ensemble.PublicTokenAt(LIndex);
      LFrame := DecodeWfcMusicEnsembleFrame(LToken);
      if EncodeWfcMusicRhythmFrame(ProjectWfcMusicEnsembleFrameToRhythm(LFrame)) <> LRhythm then
      begin
        Continue;
      end;
      if (LCell = ACells - 1) and
        (EncodeWfcMusicPitchClassSet(ProjectWfcMusicEnsembleFrameToPitchClassSet(LFrame, 12)) <>
          AEnding) then
      begin
        Continue;
      end;
      LAllowed[LCount] := LToken;
      Inc(LCount);
    end;
    SetLength(LAllowed, LCount);
    Require(LCount > 0, 'No observed ensemble frame meets the phrase guide');
    LLayers[0].Constraints[LCell] := MakeWfcSequenceTokenConstraint(LCell, LAllowed);
  end;
  LOptions := DefaultLayerGenerationOptions;
  LOptions.CellCount := ACells;
  LOptions.Seed := ASeed;
  LOptions.Extent := wseWhole;
  if not TryGenerateLayers(LLayers, nil, LOptions, Result, LReport) then
  begin
    raise EAudio.Create('Finite ensemble phrase plan failed (status ' +
      IntToStr(Ord(LReport.Status)) + ')');
  end;
end;

procedure Run(const AOutput: String; const ASeed: TGraphSeed;
  const ACells, ASegmentCells: Integer; const AVerify: Boolean);
var
  LModels: TWfcMusicEnsembleModels;
  LConfig: TWfcMusicEnsembleStreamConfig;
  LStream: TWfcMusicEnsembleStream;
  LSegment: TWfcMusicEnsembleSegment;
  LRenderer: TChordStreamRenderer;
  LClock: TIncrementalTempoClock;
  LExpectedClock: TIncrementalTempoClock;
  LReference: TWfcMusicEnsembleAudioRenderer;
  LReferenceOptions: TWfcMusicAudioOptions;
  LReferenceCaps: TWfcMusicEnsembleAudioVoiceCapacities;
  LCapacities: TChordCapacities;
  LFile: TFileStream;
  LSink: TStreamAudioSink;
  LWriter: TWavePcm16Writer;
  LFrames: TWfcMusicEnsembleFrames;
  LReport: TGraphNegotiationReport;
  LStep: TWfcMusicArrangementStep;
  LFrontier: TWfcMusicEnsembleStreamFrontier;
  LGenerated: TWfcGeneratedSequenceSegment;
  LDocument: TJSONObject;
  LModelsJson: TJSONObject;
  LSegments: TJSONArray;
  LRow: TJSONObject;
  LLayers: TJSONObject;
  LLayerJson: TJSONObject;
  LTokensJson: TJSONArray;
  LStatesJson: TJSONArray;
  LLayer: TWfcMusicEnsembleLayer;
  LModel: TWfcSequenceModel;
  LCell: Integer;
  LVoice: Integer;
  LExpected: Int64;
  LContinuedHolds: Integer;
  LEnding: TWfcModelTokens;
  LPlan: TLayerSequences;
begin
  Require((ACells >= 4) and (ACells <= 1024) and
    (ASegmentCells >= 1) and (ASegmentCells <= 64), 'Cells must be 4..1024; segment cells 1..64');
  LModels := Default(TWfcMusicEnsembleModels);
  LStream := nil;
  LSegment := nil;
  LRenderer := nil;
  LClock := nil;
  LExpectedClock := nil;
  LReference := nil;
  LFile := nil;
  LSink := nil;
  LWriter := nil;
  LDocument := nil;
  LContinuedHolds := 0;
  try
    LModels := LearnModels;
    LCapacities := WfcEnsembleCapacities(LModels.Ensemble);
    LConfig := DefaultWfcMusicEnsembleStreamConfig(LModels, Length(LCapacities),
      12, CQuantum, Int64(ACells) * CQuantum, ASeed);
    LConfig.SegmentCellCount := ASegmentCells;
    LConfig.RequireObservedEnd := True;
    LStream := TWfcMusicEnsembleStream.Create(LConfig);
    SetLength(LEnding, 1);
    LEnding[0] := EncodeWfcMusicPitchClassSet(
      ProjectWfcMusicEnsembleFrameToPitchClassSet(TrainingFrame(0, 31), 12));
    LPlan := PlanPhrase(LModels, ACells, ASeed, LEnding[0]);
    for LCell := 0 to ACells - 1 do
    begin
      LFrames := DecodeWfcMusicEnsembleFrames([LPlan[0].Tokens[LCell]]);
      LStream.IntersectAllowedTokens(wmelEnsemble, LCell, [LPlan[0].Tokens[LCell]]);
      LStream.IntersectAllowedTokens(wmelRhythm, LCell,
        [EncodeWfcMusicRhythmFrame(ProjectWfcMusicEnsembleFrameToRhythm(LFrames[0]))]);
      LStream.IntersectAllowedTokens(wmelHarmony, LCell,
        [EncodeWfcMusicPitchClassSet(ProjectWfcMusicEnsembleFrameToPitchClassSet(LFrames[0], 12))]);
    end;
    LClock := TIncrementalTempoClock.Create(CPpq, CRate);
    LExpectedClock := TIncrementalTempoClock.Create(CPpq, CRate);
    LExpected := LExpectedClock.Advance(ACells * CQuantum, CTempo);
    LRenderer := TChordStreamRenderer.Create(DefaultChordStreamOptions(CRate), LCapacities);
    if AVerify then
    begin
      SetLength(LReferenceCaps, Length(LCapacities));
      for LVoice := 0 to High(LCapacities) do
      begin
        LReferenceCaps[LVoice] := LCapacities[LVoice];
      end;
      LReferenceOptions := DefaultWfcMusicAudioOptions;
      LReference := TWfcMusicEnsembleAudioRenderer.Create(LReferenceOptions, CPpq, LReferenceCaps);
    end;
    LDocument := TJSONObject.Create;
    LDocument.Add('version', 1);
    LDocument.Add('source', 'Two authored 32-cell ensemble phrases; no external music');
    LDocument.Add('planning', 'Bounded learned whole phrase, regular rhythm guide, then streamed realization');
    LDocument.Add('plan_max_backtracks', 512);
    LDocument.Add('seed', Int64(ASeed));
    LDocument.Add('cells', ACells);
    LDocument.Add('segment_cells', ASegmentCells);
    LDocument.Add('sample_rate', CRate);
    LDocument.Add('ticks_per_quarter', CPpq);
    LDocument.Add('quantum_ticks', CQuantum);
    LDocument.Add('tempo_microseconds', CTempo);
    LDocument.Add('expected_frames', LExpected);
    LDocument.Add('ending_harmony_token', LEnding[0]);
    LModelsJson := TJSONObject.Create;
    LDocument.Add('models', LModelsJson);
    LModelsJson.Add('harmony', ModelJson(LModels.Harmony));
    LModelsJson.Add('rhythm', ModelJson(LModels.Rhythm));
    LModelsJson.Add('ensemble', ModelJson(LModels.Ensemble));
    LSegments := TJSONArray.Create;
    LDocument.Add('segments', LSegments);
    LFile := TFileStream.Create(AOutput, fmCreate);
    LSink := TStreamAudioSink.Create(LFile);
    LWriter := TWavePcm16Writer.Create(LSink, CRate, 1, LExpected);
    repeat
      LFrontier := LStream.CopyFrontier;
      LStep := LStream.Next(LSegment, LReport);
      if LStep = wmaspCompleted then
      begin
        Break;
      end;
      Require(LStep = wmaspProduced, 'Ensemble generation stopped: ' + LStream.Failure);
      try
        Require((LSegment.StartTick = LClock.Snapshot.TickCount) and
          (LSegment.Seed = WfcMusicArrangementSectionSeed(ASeed, LSegment.Index)),
          'Generated segment provenance differs from the audio cursor');
        LRow := TJSONObject.Create;
        LSegments.Add(LRow);
        LRow.Add('index', LSegment.Index);
        LRow.Add('start_tick', LSegment.StartTick);
        LRow.Add('cell_count', LSegment.CellCount);
        LRow.Add('seed', Int64(LSegment.Seed));
        LRow.Add('final', LSegment.FinalSegment);
        LLayers := TJSONObject.Create;
        LRow.Add('layers', LLayers);
        for LLayer := Low(TWfcMusicEnsembleLayer) to High(TWfcMusicEnsembleLayer) do
        begin
          LGenerated := LSegment.CopyGenerated(LLayer);
          Require((LGenerated.Boundary.HasPrevious = LFrontier.HasPrevious) and
            (LGenerated.Boundary.PreviousState = LFrontier.StateIndices[LLayer]),
            'Segment lost the preceding latent state');
          case LLayer of
            wmelHarmony: LModel := LModels.Harmony;
            wmelRhythm: LModel := LModels.Rhythm;
          else
            LModel := LModels.Ensemble;
          end;
          LLayerJson := TJSONObject.Create;
          LLayers.Add(WfcMusicEnsembleLayerName(LLayer), LLayerJson);
          LLayerJson.Add('previous_state', LGenerated.Boundary.PreviousState);
          LLayerJson.Add('observed_end', LGenerated.Boundary.RequireObservedEnd);
          LTokensJson := TJSONArray.Create;
          LLayerJson.Add('tokens', LTokensJson);
          LStatesJson := TJSONArray.Create;
          LLayerJson.Add('states', LStatesJson);
          for LCell := 0 to High(LGenerated.Tokens) do
          begin
            Require(LModel.PublicTokenAt(LModel.StateEmittedTokenIndexAt(
              LGenerated.StateIndices[LCell])) =
              LGenerated.Tokens[LCell], 'Latent state does not emit its recorded token');
            LTokensJson.Add(LGenerated.Tokens[LCell]);
            LStatesJson.Add(LGenerated.StateIndices[LCell]);
          end;
        end;
        LFrames := LSegment.CopyFrames;
        if LFrontier.HasPrevious then
        begin
          for LVoice := 0 to High(LFrames[0].Voices) do
          begin
            if LFrames[0].Voices[LVoice].Action = wmcaHold then
            begin
              Inc(LContinuedHolds);
            end;
          end;
        end;
        for LCell := 0 to High(LFrames) do
        begin
          Require(EncodeWfcMusicEnsembleFrame(LFrames[LCell]) =
            LPlan[0].Tokens[Integer(LSegment.StartTick div CQuantum) + LCell],
            'Stream realization differs from the finite learned plan');
          AdmitWfcEnsembleFrame(LRenderer, LClock, LFrames[LCell], CQuantum, CTempo);
          if LReference <> nil then
          begin
            LReference.AdmitFrame(LFrames[LCell], CQuantum, CTempo);
          end;
          Drain(LRenderer, LReference, LWriter);
        end;
      finally
        FreeAndNil(LSegment);
      end;
    until False;
    LRenderer.EndInput;
    if LReference <> nil then
    begin
      LReference.EndInput;
    end;
    Drain(LRenderer, LReference, LWriter);
    Require(LRenderer.Finished and (LRenderer.EmittedFrames = LExpected) and
      (LClock.Snapshot.TickCount = LStream.ActualTicks), 'Final ensemble/audio extent differs');
    LWriter.Finish;
    LDocument.Add('rendered_frames', LRenderer.EmittedFrames);
    LDocument.Add('continued_voice_holds', LContinuedHolds);
    LDocument.Add('verified_against_wfc', AVerify);
    WriteTextFile(AOutput + '.json', LDocument.FormatJSON);
    WriteLn('Learned 64 ensemble observations; generated ', ACells, ' cells in ',
      LSegments.Count, ' segments; ', LContinuedHolds, ' voice holds crossed segment boundaries');
    WriteLn('Streamed ', LRenderer.EmittedFrames, ' frames; actual WFC PCM verification: ', AVerify);
  finally
    LWriter.Free;
    LSink.Free;
    LFile.Free;
    LDocument.Free;
    LReference.Free;
    LRenderer.Free;
    LExpectedClock.Free;
    LClock.Free;
    LSegment.Free;
    LStream.Free;
    LModels.Ensemble.Free;
    LModels.Rhythm.Free;
    LModels.Harmony.Free;
  end;
end;

var
  LSeed: TGraphSeed;
  LSeedValue: Int64;
  LCells: Integer;
  LSegmentCells: Integer;
  LCount: Integer;
  LVerify: Boolean;
begin
  try
    LCount := ParamCount;
    LVerify := (LCount > 0) and (ParamStr(LCount) = '--verify');
    if LVerify then
    begin
      Dec(LCount);
    end;
    Require((LCount >= 1) and (LCount <= 4),
      'Usage: pythian.ensemble.demo OUTPUT.wav [SEED [CELLS [SEGMENT_CELLS]]] [--verify]');
    LSeed := 731;
    LCells := 64;
    LSegmentCells := 5;
    if LCount >= 2 then
    begin
      LSeedValue := StrToInt64(ParamStr(2));
      Require((LSeedValue >= 0) and (LSeedValue <= High(Cardinal)), 'Seed must fit Cardinal');
      LSeed := LSeedValue;
    end;
    if LCount >= 3 then
    begin
      LCells := StrToInt(ParamStr(3));
    end;
    if LCount >= 4 then
    begin
      LSegmentCells := StrToInt(ParamStr(4));
    end;
    Run(ParamStr(1), LSeed, LCells, LSegmentCells, LVerify);
  except
    on LException: Exception do
    begin
      WriteLn(StdErr, LException.ClassName, ': ', LException.Message);
      Halt(1);
    end;
  end;
end.
