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
program pythian_tests_wfc_corpus;

{$mode delphi}
{$H+}

uses
  SysUtils,
  pythian.audio,
  pythian.corpus,
  pythian.corpus.archive,
  pythian.learning,
  pythian.granular,
  pythian.wave,
  pythian.wfc.learning,
  pythian.wfc.corpus,
  pythian.wfc.generation,
  pythian.tests.corpus.fixture,
  wfc,
  wfc_sequence,
  wfc_sequence_text;

procedure Check(const AValue: Boolean; const AMessage: String);
begin
  if not AValue then
  begin
    raise Exception.Create(AMessage);
  end;
end;

procedure Run;
var
  LCorpus: TAcousticCorpusData;
  LLoaded: TAcousticCorpusData;
  LRejectedCorpus: TAcousticCorpusData;
  LSources: TAudioSources;
  LModel: TWfcSequenceModel;
  LReloaded: TWfcSequenceModel;
  LWrongModel: TWfcSequenceModel;
  LPalette: TAcousticPalette;
  LBytes: TAudioBytes;
  LWrongBytes: TAudioBytes;
  LWave: TAudioBytes;
  LReplayWave: TAudioBytes;
  LSequences: TAcousticCorpus;
  LGeneration: TAcousticGenerationOptions;
  LReport: TGraphSolveReport;
  LTokens: TAcousticIndices;
  LReplay: TAcousticIndices;
  LClip: TAudioClip;
  LText: String;
  LIndex: Integer;
  LOrder: Integer;
  LRejected: Boolean;
begin
  LCorpus := CreateCorpusFixture(LSources);
  try
    for LOrder := 1 to 4 do
    begin
      LBytes := EncodeWfcAcousticCorpus(LCorpus, LOrder);
      LLoaded := DecodeWfcAcousticCorpus(LBytes, LModel);
      try
        Check((LModel.SampleCount = 2) and (LModel.ObservationCount = 16) and
          (LModel.Order = LOrder), 'Actual WFC model preserves corpus boundaries and order');
        LGeneration := DefaultAcousticGenerationOptions;
        LGeneration.FrameCount := 8;
        Check(TryGenerateAcousticSequence(LModel, LGeneration, nil, LTokens, LReport),
          'Generate from saved WFC corpus');
        LClip := RenderGrains(LSources, LLoaded.PlanGrains(LTokens),
          DefaultGrainRenderOptions(8192, 1));
        try
          LWave := EncodeWavePcm16(LClip);
        finally
          LClip.Free;
        end;
        LRejectedCorpus := DecodeWfcAcousticCorpus(LBytes, LReloaded);
        try
          Check(TryGenerateAcousticSequence(LReloaded, LGeneration, nil, LReplay, LReport),
            'Generate again after a separate load');
          Check(Length(LReplay) = Length(LTokens), 'Reloaded token length');
          for LIndex := 0 to High(LTokens) do
          begin
            Check(LReplay[LIndex] = LTokens[LIndex], 'Exact saved-model token replay');
          end;
          LClip := RenderGrains(LSources, LRejectedCorpus.PlanGrains(LReplay),
            DefaultGrainRenderOptions(8192, 1));
          try
            LReplayWave := EncodeWavePcm16(LClip);
          finally
            LClip.Free;
          end;
          Check((Length(LWave) = Length(LReplayWave)) and
            (CompareByte(LWave[0], LReplayWave[0], Length(LWave)) = 0),
            'Exact audio replay after loading');
        finally
          LReloaded.Free;
          LRejectedCorpus.Free;
        end;
      finally
        LModel.Free;
        LLoaded.Free;
      end;
    end;
    SetLength(LSequences, 2);
    LSequences[0] := LCorpus.RecordingAt(0).Tokens;
    LSequences[1] := LCorpus.RecordingAt(1).Tokens;
    LSequences[0][0] := (LSequences[0][0] + 1) mod LCorpus.PaletteCount;
    LPalette := LCorpus.CopyPalette;
    try
      LWrongModel := LearnAcousticModel(LSequences, LPalette, 2);
      try
        LText := EncodeWfcSequenceText(LWrongModel);
        SetLength(LWrongBytes, Length(LText));
        Move(LText[1], LWrongBytes[0], Length(LText));
        LWrongBytes := EncodeAcousticArchive(LCorpus, WfcCorpusAttachmentContract, LWrongBytes);
      finally
        LWrongModel.Free;
      end;
    finally
      LPalette.Free;
    end;
    LRejected := False;
    LModel := nil;
    try
      LRejectedCorpus := DecodeWfcAcousticCorpus(LWrongBytes, LModel);
      LRejectedCorpus.Free;
      LModel.Free;
    except
      on EAudio do
      begin
        LRejected := True;
      end;
    end;
    Check(LRejected and (LModel = nil),
      'Valid digest and valid WFC model do not excuse mismatched corpus observations');
  finally
    LCorpus.Free;
    ReleaseFixtureSources(LSources);
  end;
end;

begin
  try
    Run;
    WriteLn('Persisted WFC corpus validation and audio replay checks passed');
  except
    on LException: Exception do
    begin
      WriteLn(StdErr, LException.Message);
      Halt(1);
    end;
  end;
end.
