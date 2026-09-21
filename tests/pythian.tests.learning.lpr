(*
MIT License

Copyright (c) 2021 mr-highball
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
program pythian_tests_learning;

{$mode delphi}
{$H+}

uses
  SysUtils,
  Math,
  pythian.audio,
  pythian.wave,
  pythian.analysis,
  pythian.learning,
  pythian.granular,
  pythian.reconstruction,
  pythian.wfc.audio,
  pythian.wfc.learning,
  pythian.wfc.generation,
  pythian.tools.files,
  wfc,
  wfc_model,
  wfc_music_audio,
  wfc_sequence,
  wfc_sequence_text,
  wfc_sequence_graph;

procedure Check(const ACondition: Boolean; const AMessage: String);
begin
  if not ACondition then
  begin
    raise Exception.Create(AMessage);
  end;
end;

procedure CheckPcmBridge;
var
  LSamples: TWfcMusicPcm16Samples;
  LWfc: TWfcMusicPcm16Clip;
  LBack: TWfcMusicPcm16Clip;
  LClip: TAudioClip;
  LExpected: TWfcMusicAudioBytes;
  LActual: TAudioBytes;
  LIndex: Integer;
begin
  SetLength(LSamples, 65536);
  for LIndex := 0 to High(LSamples) do
  begin
    LSamples[LIndex] := LIndex - 32768;
  end;
  LWfc := TWfcMusicPcm16Clip.Create(44100, LSamples);
  try
    LClip := FromWfcClip(LWfc);
    try
      LActual := EncodeWavePcm16(LClip);
      LExpected := EncodeWfcMusicWave(LWfc);
      Check(Length(LActual) = Length(LExpected), 'WFC WAVE byte count');
      Check(CompareByte(LActual[0], LExpected[0], Length(LActual)) = 0,
        'Every PCM16 value encodes identically to precursor');
      LBack := ToWfcClip(LClip);
      try
        for LIndex := 0 to High(LSamples) do
        begin
          Check(LBack.SampleAt(LIndex) = LSamples[LIndex], 'Lossless WFC round-trip');
        end;
      finally
        LBack.Free;
      end;
    finally
      LClip.Free;
    end;
  finally
    LWfc.Free;
  end;
  WriteLn('PASS WFC bridge: all 65536 PCM16 values and canonical bytes');
end;

procedure CheckAcousticLearning;
const
  CRate = 16384;
  CWindow = 4096;
var
  LSamples: TAudioSamples;
  LClip: TAudioClip;
  LDecoded: TAudioClip;
  LOptions: TAnalysisOptions;
  LFeatures: TAudioFeatures;
  LPalette: TAcousticPalette;
  LReplay: TAcousticPalette;
  LCorpus: TAcousticCorpus;
  LIndices: TAcousticIndices;
  LModel: TWfcSequenceModel;
  LRestored: TWfcSequenceModel;
  LGraph: TGraph;
  LSolveOptions: TGraphSolveOptions;
  LSolveReport: TGraphSolveReport;
  LGenerated: TWfcGeneratedSequence;
  LValidation: TWfcSequenceGraphValidationReport;
  LIndex: Integer;
  LValue: Double;
  LGeneration: TAcousticGenerationOptions;
  LGeneratedIndices: TAcousticIndices;
  LReplayIndices: TAcousticIndices;
  LConstraints: TWfcSequenceTokenConstraints;
  LGrains: TAudioGrains;
  LSources: TAudioSources;
  LReconstruction: TAudioClip;
  LReject: Boolean;
begin
  { Independent analytic stereo fixture: A4/E5 dyad, silence, C5. Right is
    inverted so a destructive mono average would lose the entire recording. }
  SetLength(LSamples, CWindow * 8);
  for LIndex := 0 to CWindow * 4 - 1 do
  begin
    LValue := 0;
    if LIndex < CWindow * 2 then
    begin
      LValue := 0.3 * Sin(2 * Pi * 440 * LIndex / CRate) +
        0.3 * Sin(2 * Pi * 660 * LIndex / CRate);
    end
    else if LIndex >= CWindow * 3 then
    begin
      LValue := 0.4 * Sin(2 * Pi * 524 * LIndex / CRate);
    end;
    LSamples[2 * LIndex] := LValue;
    LSamples[2 * LIndex + 1] := -LValue;
  end;
  LClip := TAudioClip.Create(CRate, 2, LSamples);
  try
    LDecoded := DecodeWave(EncodeWavePcm16(LClip));
    try
      LOptions := DefaultAnalysisOptions;
      LOptions.WindowFrames := CWindow;
      LOptions.HopFrames := CWindow;
      LFeatures := AnalyzeAudio(LDecoded, LOptions);
    finally
      LDecoded.Free;
    end;
  finally
    LClip.Free;
  end;
  Check(Length(LFeatures) = 4, 'Analysis frame count');
  Check(Abs(LFeatures[0].Rms - 0.3) < 0.0001, 'Independent analytic dyad RMS');
  Check(Abs(LFeatures[0].CentroidHz - 550) < 2, 'Independent dyad centroid');
  Check(LFeatures[0].Chroma[9] > 0.4, 'A pitch class retained');
  Check(LFeatures[0].Chroma[4] > 0.4, 'E pitch class retained');
  Check(LFeatures[2].Silent and (LFeatures[2].Rms = 0), 'Silence is explicit');
  Check(LFeatures[3].Chroma[0] > 0.9, 'C pitch class retained');
  LPalette := TAcousticPalette.Create(LFeatures, 3);
  try
    SetLength(LCorpus, 1);
    LCorpus[0] := LPalette.Encode(LFeatures);
    Check((LCorpus[0][0] <> LCorpus[0][2]) and (LCorpus[0][2] <> LCorpus[0][3]),
      'Harmonic, silent and changed-harmony frames have different tokens');
    LReplay := TAcousticPalette.Create(LFeatures, 3);
    try
      LIndices := LReplay.Encode(LFeatures);
      for LIndex := 0 to High(LIndices) do
      begin
        Check(LIndices[LIndex] = LCorpus[0][LIndex], 'Palette replay');
      end;
    finally
      LReplay.Free;
    end;
    LModel := LearnAcousticModel(LCorpus, LPalette, 2);
    try
      Check(LModel.ObservationCount = 4, 'WFC observes every audio frame');
      LRestored := DecodeWfcSequenceText(EncodeWfcSequenceText(LModel));
      try
        Check(EncodeWfcSequenceText(LRestored) = EncodeWfcSequenceText(LModel),
          'Actual WFC model serialization round-trip');
      finally
        LRestored.Free;
      end;
      LGraph := TGraph.Create;
      try
        LGraph.Reshape(4, 1, 1);
        LGraph.WrapNeighbors := False;
        ApplySequenceModelToGraph(LModel, LGraph);
        LSolveOptions := DefaultGraphSolveOptions;
        Check(LGraph.TrySolve(LSolveOptions, LSolveReport), 'WAV-trained WFC solve');
        Check(CaptureSolvedSequence(LModel, LGraph, LGenerated, LValidation),
          'Independent WFC generated-path validation');
        Check(Length(LGenerated.Tokens) = 4, 'Generated acoustic token count');
      finally
        LGraph.Free;
      end;
      LGeneration := DefaultAcousticGenerationOptions;
      Check(LGeneration.StateCellBudget = 262144, 'Default graph budget is retained');
      LGeneration.FrameCount := 4;
      LGeneration.Extent := wseWhole;
      LGeneration.StateCellBudget := 4 * LModel.StateCount;
      SetLength(LConstraints, 1);
      LConstraints[0] := MakeWfcSequenceTokenConstraint(2,
        [AcousticToken(LCorpus[0][2])]);
      Check(TryGenerateAcousticSequence(LModel, LGeneration, LConstraints,
        LGeneratedIndices, LSolveReport), 'Acoustic adapter solves with a caller lock');
      Check(LGeneratedIndices[2] = LCorpus[0][2], 'Caller silence lock preserved');
      Check(TryGenerateAcousticSequence(LModel, LGeneration, LConstraints,
        LReplayIndices, LSolveReport), 'Acoustic generation replay succeeds');
      for LIndex := 0 to High(LGeneratedIndices) do
      begin
        Check(LGeneratedIndices[LIndex] = LReplayIndices[LIndex], 'Seeded WFC replay');
      end;
      { The exact budget above admits the locked path. One fewer cell must fail
        without replacing the caller's previously generated path. }
      Dec(LGeneration.StateCellBudget);
      LReject := False;
      try
        TryGenerateAcousticSequence(LModel, LGeneration, LConstraints,
          LGeneratedIndices, LSolveReport);
      except
        on EAudio do
        begin
          LReject := True;
        end;
      end;
      Check(LReject, 'Selected state-cell budget is enforced');
      Check(Length(LGeneratedIndices) = Length(LReplayIndices), 'Budget preserves length');
      for LIndex := 0 to High(LReplayIndices) do
      begin
        Check(LGeneratedIndices[LIndex] = LReplayIndices[LIndex], 'Budget preserves tokens');
      end;
      for LIndex := 0 to 1 do
      begin
        LGeneration.StateCellBudget := LIndex * (MaximumAcousticStateCells + 1);
        LReject := False;
        try
          TryGenerateAcousticSequence(LModel, LGeneration, LConstraints,
            LGeneratedIndices, LSolveReport);
        except
          on EAudio do
          begin
            LReject := True;
          end;
        end;
        Check(LReject, 'Zero or over-cap state-cell budget rejects');
      end;
      LGeneration.StateCellBudget := MaximumAcousticStateCells;
      Check(TryGenerateAcousticSequence(LModel, LGeneration, LConstraints,
        LGeneratedIndices, LSolveReport), 'Explicit maximum admits caller lock');
      for LIndex := 0 to High(LReplayIndices) do
      begin
        Check(LGeneratedIndices[LIndex] = LReplayIndices[LIndex],
          'Budget enlargement preserves the same seeded constrained path');
      end;
      SetLength(LSources, 1);
      LSources[0] := TAudioClip.Create(CRate, 2, LSamples);
      try
        LGrains := PlanAcousticGrains(LSources[0], LFeatures, LPalette,
          LGeneratedIndices, CWindow);
        Check(LGrains[2].SourceStartFrame = 2 * CWindow, 'Locked grain traces to source silence');
        LReconstruction := RenderGrains(LSources, LGrains,
          DefaultGrainRenderOptions(CRate, 2));
        try
          Check(LReconstruction.FrameCount = 4 * CWindow, 'Reconstruction duration');
          Check(Abs(LReconstruction.SampleAt(1234, 0)) > 0.001, 'Reconstruction contains audio');
          Check(LReconstruction.SampleAt(2 * CWindow + 1000, 0) = 0,
            'Locked silent grain reconstructs silence');
          Check(LReconstruction.SampleAt(1234, 0) = -LReconstruction.SampleAt(1234, 1),
            'Reconstruction preserves stereo phase');
        finally
          LReconstruction.Free;
        end;
      finally
        LSources[0].Free;
      end;
      LConstraints[0] := MakeWfcSequenceTokenConstraint(0,
        [AcousticToken(LCorpus[0][3])]);
      Check(not TryGenerateAcousticSequence(LModel, LGeneration, LConstraints,
        LGeneratedIndices, LSolveReport), 'Contradictory acoustic lock rejected');
      Check(LSolveReport.Status = gssContradiction, 'Contradiction status preserved');
      for LIndex := 0 to High(LGeneratedIndices) do
      begin
        Check(LGeneratedIndices[LIndex] = LReplayIndices[LIndex],
          'Failed generation preserves previously published indices');
      end;
      LGeneration.FrameCount := MaximumGeneratedAcousticFrames + 1;
      LReject := False;
      try
        TryGenerateAcousticSequence(LModel, LGeneration, nil,
          LGeneratedIndices, LSolveReport);
      except
        on EAudio do
        begin
          LReject := True;
        end;
      end;
      Check(LReject, 'Oversized generation rejected before publication');
    finally
      LModel.Free;
    end;
  finally
    LPalette.Free;
  end;
  WriteLn('PASS WAV dyad/silence features, stereo phase, acoustic palette, actual WFC solve');
  WriteLn('PASS WFC generation locks, replay, failure preservation and recorded-grain reconstruction');
  WriteLn('PASS explicit state-cell boundary, cap rejection and budget-independent replay');
end;

procedure CheckSearchBudget;
var
  LFeatures: TAudioFeatures;
  LPalette: TAcousticPalette;
  LCorpus: TAcousticCorpus;
  LModel: TWfcSequenceModel;
  LOptions: TAcousticGenerationOptions;
  LReport: TGraphSolveReport;
  LIndices: TAcousticIndices;
begin
  SetLength(LFeatures, 2);
  LFeatures[0].Chroma[0] := 1;
  LFeatures[1].Chroma[1] := 1;
  LPalette := TAcousticPalette.Create(LFeatures, 2);
  try
    SetLength(LCorpus, 1);
    SetLength(LCorpus[0], 4);
    LCorpus[0][0] := 0;
    LCorpus[0][1] := 1;
    LCorpus[0][2] := 0;
    LCorpus[0][3] := 1;
    LModel := LearnAcousticModel(LCorpus, LPalette, 2);
    try
      LOptions := DefaultAcousticGenerationOptions;
      LOptions.FrameCount := 3;
      LOptions.Extent := wseWrap;
      LOptions.MaxBacktracks := 0;
      SetLength(LIndices, 1);
      LIndices[0] := 31;
      Check(not TryGenerateAcousticSequence(LModel, LOptions, nil, LIndices, LReport),
        'Odd alternating cycle cannot generate');
      Check(LReport.Status = gssBacktrackLimit, 'Exhausted search is reported as a budget limit');
      Check((Length(LIndices) = 1) and (LIndices[0] = 31), 'Budget failure preserves output');
      LOptions.MaxBacktracks := 32;
      Check(not TryGenerateAcousticSequence(LModel, LOptions, nil, LIndices, LReport),
        'Odd alternating cycle remains impossible with recovery');
      Check(LReport.Status = gssContradiction, 'Exhaustive contradiction remains distinct');
    finally
      LModel.Free;
    end;
  finally
    LPalette.Free;
  end;
  WriteLn('PASS WFC budget exhaustion distinguished from exhaustive contradiction');
end;

begin
  try
    CheckPcmBridge;
    CheckAcousticLearning;
    CheckSearchBudget;
    Check(HashText('abc') =
      'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad',
      'SHA256 provenance known-answer fixture');
  except
    on LException: Exception do
    begin
      WriteLn(StdErr, LException.ClassName, ': ', LException.Message);
      Halt(1);
    end;
  end;
end.
