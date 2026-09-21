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
program pythian_remix;

{$mode delphi}
{$H+}

uses
  SysUtils,
  fpjson,
  pythian.audio,
  pythian.wave,
  pythian.analysis,
  pythian.learning,
  pythian.granular,
  pythian.reconstruction,
  pythian.wfc.learning,
  pythian.wfc.generation,
  pythian.tools.files,
  wfc,
  wfc_sequence,
  wfc_sequence_text;

procedure RemixFile(const AInput, AOutput: String; const ASeed: TGraphSeed;
  const AFrameCount: Integer);
var
  LSource: TAudioClip;
  LOutput: TAudioClip;
  LSha256: String;
  LAnalysis: TAnalysisOptions;
  LFeatures: TAudioFeatures;
  LPalette: TAcousticPalette;
  LCorpus: TAcousticCorpus;
  LModel: TWfcSequenceModel;
  LGeneration: TAcousticGenerationOptions;
  LReport: TGraphSolveReport;
  LIndices: TAcousticIndices;
  LGrains: TAudioGrains;
  LSources: TAudioSources;
  LRender: TGrainRenderOptions;
  LDocument: TJSONObject;
  LEvents: TJSONArray;
  LEvent: TJSONObject;
  LIndex: Integer;
  LModelText: String;
  LWaveBytes: TAudioBytes;
begin
  if (CompareText(ExpandFileName(AInput), ExpandFileName(AOutput)) = 0) or
    (CompareText(ExpandFileName(AInput), ExpandFileName(AOutput + '.json')) = 0) or
    (CompareText(ExpandFileName(AInput), ExpandFileName(AOutput + '.wfcs')) = 0) then
  begin
    raise EAudio.Create('Remix output must not replace its input recording');
  end;
  LSource := LoadWaveSource(AInput, LSha256);
  try
    LAnalysis := DefaultAnalysisOptions;
    LFeatures := AnalyzeAudio(LSource, LAnalysis);
    LPalette := TAcousticPalette.Create(LFeatures);
    try
      SetLength(LCorpus, 1);
      LCorpus[0] := LPalette.Encode(LFeatures);
      LModel := LearnAcousticModel(LCorpus, LPalette);
      try
        LGeneration := DefaultAcousticGenerationOptions;
        LGeneration.Seed := ASeed;
        LGeneration.FrameCount := AFrameCount;
        if not TryGenerateAcousticSequence(LModel, LGeneration, nil, LIndices, LReport) then
        begin
          if LReport.Status = gssBacktrackLimit then
          begin
            raise EAudio.Create('WFC backtrack budget exhausted; no remix was published');
          end;
          raise EAudio.Create('WFC acoustic request is contradictory; no remix was published');
        end;
        LGrains := PlanAcousticGrains(LSource, LFeatures, LPalette, LIndices,
          LAnalysis.HopFrames);
        SetLength(LSources, 1);
        LSources[0] := LSource;
        LRender := DefaultGrainRenderOptions(LSource.SampleRate, LSource.Channels);
        LOutput := RenderGrains(LSources, LGrains, LRender);
        try
          LModelText := EncodeWfcSequenceText(LModel);
          LWaveBytes := EncodeWavePcm16(LOutput);
          LDocument := TJSONObject.Create;
          try
            LDocument.Add('contract', 'pythian.remix.v1');
            LDocument.Add('method', 'WFC acoustic sequence with recorded-grain reconstruction');
            LDocument.Add('source', ExtractFileName(AInput));
            LDocument.Add('source_sha256', LSha256);
            LDocument.Add('model_sha256', HashText(LModelText));
            LDocument.Add('output_sha256', HashAudioBytes(LWaveBytes));
            LDocument.Add('sample_rate', LSource.SampleRate);
            LDocument.Add('channels', LSource.Channels);
            LDocument.Add('source_frames', LSource.FrameCount);
            LDocument.Add('output_frames', LOutput.FrameCount);
            LDocument.Add('seed', Int64(ASeed));
            LDocument.Add('extent', 'fragment');
            LDocument.Add('max_backtracks', LGeneration.MaxBacktracks);
            LDocument.Add('analysis_version', AnalysisVersion);
            LDocument.Add('learning_version', AcousticLearningVersion);
            LDocument.Add('generation_version', AcousticGenerationVersion);
            LDocument.Add('reconstruction_version', AcousticReconstructionVersion);
            LDocument.Add('granular_version', GranularVersion);
            LDocument.Add('wfc_solver_version', LReport.SolverAlgorithmVersion);
            LDocument.Add('wfc_random_version', LReport.RandomAlgorithmVersion);
            LDocument.Add('window_frames', LAnalysis.WindowFrames);
            LDocument.Add('hop_frames', LAnalysis.HopFrames);
            LDocument.Add('silence_rms', LAnalysis.SilenceRms);
            LDocument.Add('palette_tokens', LPalette.Count);
            LDocument.Add('model_states', LModel.StateCount);
            LEvents := TJSONArray.Create;
            LDocument.Add('grains', LEvents);
            for LIndex := 0 to High(LGrains) do
            begin
              LEvent := TJSONObject.Create;
              LEvents.Add(LEvent);
              LEvent.Add('token', LIndices[LIndex]);
              LEvent.Add('source_start_frame', LGrains[LIndex].SourceStartFrame);
              LEvent.Add('output_start_frame', LGrains[LIndex].OutputStartFrame);
              LEvent.Add('frame_count', LGrains[LIndex].FrameCount);
              LEvent.Add('playback_rate', LGrains[LIndex].PlaybackRate);
              LEvent.Add('gain', LGrains[LIndex].Gain);
              LEvent.Add('window', 'hann');
            end;
            SaveWavePcm16(AOutput, LOutput);
            WriteTextFile(AOutput + '.wfcs', LModelText);
            WriteTextFile(AOutput + '.json', LDocument.FormatJSON);
          finally
            LDocument.Free;
          end;
          WriteLn('Reconstructed ', Length(LGrains), ' WFC-selected recorded grains into ',
            LOutput.FrameCount, ' frames; source mapping: ', AOutput, '.json');
        finally
          LOutput.Free;
        end;
      finally
        LModel.Free;
      end;
    finally
      LPalette.Free;
    end;
  finally
    LSource.Free;
  end;
end;

var
  LSeed: QWord;
  LFrameCount: Integer;
begin
  try
    if (ParamCount < 2) or (ParamCount > 4) then
    begin
      WriteLn('Usage: pythian.remix INPUT.wav OUTPUT.wav [SEED] [ACOUSTIC_FRAMES]');
      Halt(2);
    end;
    LSeed := 731;
    LFrameCount := 256;
    if ParamCount >= 3 then
    begin
      if not TryStrToQWord(ParamStr(3), LSeed) or (LSeed > High(TGraphSeed)) then
      begin
        raise EAudio.Create('Seed must fit the WFC seed type');
      end;
    end;
    if ParamCount = 4 then
    begin
      LFrameCount := StrToInt(ParamStr(4));
    end;
    if (LFrameCount < 1) or (LFrameCount > MaximumGeneratedAcousticFrames) then
    begin
      raise EAudio.Create('Acoustic frames must be 1..1024');
    end;
    RemixFile(ParamStr(1), ParamStr(2), LSeed, LFrameCount);
  except
    on LException: Exception do
    begin
      WriteLn(StdErr, LException.ClassName, ': ', LException.Message);
      Halt(1);
    end;
  end;
end.
