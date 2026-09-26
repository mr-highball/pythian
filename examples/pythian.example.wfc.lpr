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
program pythian_example_wfc;

{$mode delphi}
{$H+}

uses
  SysUtils,
  pythian.audio,
  pythian.wave,
  pythian.analysis,
  pythian.learning,
  pythian.granular,
  pythian.reconstruction,
  pythian.wfc.learning,
  pythian.wfc.generation,
  wfc,
  wfc_sequence;

var
  LSource: TAudioClip;
  LOutput: TAudioClip;
  LPalette: TAcousticPalette;
  LModel: TWfcSequenceModel;
  LFeatures: TAudioFeatures;
  LCorpus: TAcousticCorpus;
  LIndices: TAcousticIndices;
  LSources: TAudioSources;
  LGrains: TAudioGrains;
  LAnalysis: TAnalysisOptions;
  LOptions: TAcousticGenerationOptions;
  LReport: TGraphSolveReport;
begin
  LSource := nil;
  LOutput := nil;
  LPalette := nil;
  LModel := nil;
  try
    try
      if ParamCount <> 2 then
      begin
        raise EAudio.Create('Usage: pythian.example.wfc INPUT.wav OUTPUT.wav');
      end;
      if SameFileName(ExpandFileName(ParamStr(1)), ExpandFileName(ParamStr(2))) then
      begin
        raise EAudio.Create('Input and output paths must differ');
      end;
      LSource := LoadWave(ParamStr(1));
      LAnalysis := DefaultAnalysisOptions;
      LFeatures := AnalyzeAudio(LSource, LAnalysis);
      LPalette := TAcousticPalette.Create(LFeatures, 8);
      SetLength(LCorpus, 1);
      LCorpus[0] := LPalette.Encode(LFeatures);
      LModel := LearnAcousticModel(LCorpus, LPalette);
      LOptions := DefaultAcousticGenerationOptions;
      LOptions.FrameCount := 64;
      if not TryGenerateAcousticSequence(LModel, LOptions, nil, LIndices, LReport) then
      begin
        raise EAudio.Create('Bounded WFC generation did not solve');
      end;
      LGrains := PlanAcousticGrains(LSource, LFeatures, LPalette, LIndices, LAnalysis.HopFrames);
      SetLength(LSources, 1);
      LSources[0] := LSource;
      LOutput := RenderGrains(LSources, LGrains,
        DefaultGrainRenderOptions(LSource.SampleRate, LSource.Channels));
      SaveWavePcm16(ParamStr(2), LOutput);
      WriteLn('WFC consumer learned ', Length(LFeatures), ' WAV observations and rendered ',
        Length(LIndices), ' generated grains');
    finally
      LModel.Free;
      LPalette.Free;
      LOutput.Free;
      LSource.Free;
    end;
  except
    on LException: Exception do
    begin
      WriteLn(StdErr, LException.ClassName, ': ', LException.Message);
      Halt(1);
    end;
  end;
end.

