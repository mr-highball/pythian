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
program pythian_learn;

{$mode delphi}
{$H+}

uses
  SysUtils,
  fpjson,
  pythian.audio,
  pythian.analysis,
  pythian.learning,
  pythian.wfc.learning,
  pythian.tools.files,
  pythian.tools.features,
  pythian.tools.journal.learning,
  wfc_sequence,
  wfc_sequence_text;

procedure LearnFile(const AInput, AOutputPrefix: String);
var
  LInfo: TWaveAnalysisInfo;
  LOptions: TAnalysisOptions;
  LFeatures: TAudioFeatures;
  LPalette: TAcousticPalette;
  LCorpus: TAcousticCorpus;
  LModel: TWfcSequenceModel;
  LDocument: TJSONObject;
  LCenters: TJSONArray;
  LCenter: TJSONArray;
  LTokens: TJSONArray;
  LVector: TAcousticVector;
  LIndex: Integer;
  LComponent: Integer;
  LModelText: String;
begin
  if (CompareText(ExpandFileName(AInput), ExpandFileName(AOutputPrefix + '.json')) = 0) or
    (CompareText(ExpandFileName(AInput), ExpandFileName(AOutputPrefix + '.wfcs')) = 0) then
  begin
    raise EAudio.Create('Learning output must not replace its input recording');
  end;
  LOptions := DefaultAnalysisOptions;
  LFeatures := AnalyzeWaveSource(AInput, LOptions, LInfo);
  LPalette := TAcousticPalette.Create(LFeatures);
  try
    SetLength(LCorpus, 1);
    LCorpus[0] := LPalette.Encode(LFeatures);
    LModel := LearnAcousticModel(LCorpus, LPalette);
    try
      LModelText := EncodeWfcSequenceText(LModel);
      LDocument := TJSONObject.Create;
      try
        LDocument.Add('contract', 'pythian.acoustic.v1');
        LDocument.Add('analysis_version', AnalysisVersion);
        LDocument.Add('learning_version', AcousticLearningVersion);
        LDocument.Add('source', ExtractFileName(AInput));
        LDocument.Add('source_sha256', LInfo.Sha256);
        LDocument.Add('model_sha256', HashText(LModelText));
        LDocument.Add('sample_rate', LInfo.SampleRate);
        LDocument.Add('channels', LInfo.Channels);
        LDocument.Add('source_frames', LInfo.FrameCount);
        LDocument.Add('window_frames', LOptions.WindowFrames);
        LDocument.Add('hop_frames', LOptions.HopFrames);
        LDocument.Add('silence_rms', LOptions.SilenceRms);
        LDocument.Add('observations', LModel.ObservationCount);
        LDocument.Add('states', LModel.StateCount);
        LCenters := TJSONArray.Create;
        LDocument.Add('palette', LCenters);
        for LIndex := 0 to LPalette.Count - 1 do
        begin
          LVector := LPalette.CenterAt(LIndex);
          LCenter := TJSONArray.Create;
          LCenters.Add(LCenter);
          for LComponent := 0 to High(LVector) do
          begin
            LCenter.Add(LVector[LComponent]);
          end;
        end;
        LTokens := TJSONArray.Create;
        LDocument.Add('frame_tokens', LTokens);
        for LIndex := 0 to High(LCorpus[0]) do
        begin
          LTokens.Add(LCorpus[0][LIndex]);
        end;
        { Build both artifacts before writing either; CLI output paths are explicit. }
        WriteTextFile(AOutputPrefix + '.json', LDocument.FormatJSON);
        WriteTextFile(AOutputPrefix + '.wfcs', LModelText);
      finally
        LDocument.Free;
      end;
      WriteLn('Learned ', LModel.ObservationCount, ' WAV frames into ',
        LPalette.Count, ' acoustic tokens and ', LModel.StateCount, ' WFC states');
    finally
      LModel.Free;
    end;
  finally
    LPalette.Free;
  end;
end;

var
  LBatchFeatures: Integer;
  LMaximumBatches: Integer;
  LIndex: Integer;
  LSeenBatch: Boolean;
  LSeenMaximum: Boolean;
begin
  try
    if ParamStr(1) = 'fit' then
    begin
      FitJournalFiles;
      Exit;
    end;
    if ParamStr(1) = 'contexts' then
    begin
      AttachJournalContexts;
      Exit;
    end;
    if ParamStr(1) = 'blend' then
    begin
      BlendJournalFiles;
      Exit;
    end;
    if ParamStr(1) = 'replay' then
    begin
      ReplayJournalFiles;
      Exit;
    end;
    if ParamStr(1) = 'journals' then
    begin
      LearnJournalFiles;
      Exit;
    end;
    if ParamStr(1) = 'cache' then
    begin
      if (ParamCount < 3) or not Odd(ParamCount) then
      begin
        raise EAudio.Create('Usage: pythian.learn cache INPUT.wav OUTPUT.pyaf [--batch-features N] [--max-batches N]');
      end;
      LBatchFeatures := 1024;
      LMaximumBatches := 0;
      LSeenBatch := False;
      LSeenMaximum := False;
      LIndex := 4;
      while LIndex <= ParamCount do
      begin
        if (ParamStr(LIndex) = '--batch-features') and not LSeenBatch then
        begin
          LBatchFeatures := StrToInt(ParamStr(LIndex + 1));
          LSeenBatch := True;
        end
        else if (ParamStr(LIndex) = '--max-batches') and not LSeenMaximum then
        begin
          LMaximumBatches := StrToInt(ParamStr(LIndex + 1));
          LSeenMaximum := True;
        end
        else
        begin
          raise EAudio.Create('Unknown or duplicate feature cache option');
        end;
        Inc(LIndex, 2);
      end;
      CacheWaveFeatures(ParamStr(2), ParamStr(3), LBatchFeatures, LMaximumBatches);
      Exit;
    end;
    if ParamCount <> 2 then
    begin
      WriteLn('Usage: pythian.learn INPUT.wav OUTPUT_PREFIX');
      Halt(2);
    end;
    LearnFile(ParamStr(1), ParamStr(2));
  except
    on LException: Exception do
    begin
      WriteLn(StdErr, LException.ClassName, ': ', LException.Message);
      Halt(1);
    end;
  end;
end.
