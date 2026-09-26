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
program pythian_tests_passage_output;

{$mode delphi}
{$H+}

uses
  SysUtils,
  Math,
  fpjson,
  jsonparser,
  pythian.audio,
  pythian.wave,
  pythian.passage,
  pythian.analysis,
  pythian.learning,
  pythian.corpus,
  pythian.corpus.archive,
  pythian.wfc.learning,
  pythian.tools.files,
  wfc_sequence,
  wfc_sequence_text;

procedure Check(const AValue: Boolean; const AMessage: String);
begin
  if not AValue then
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
  LEvents: TJSONArray;
  LEvent: TJSONData;
  LBytes: TAudioBytes;
  LAttachment: TAudioBytes;
  LContract: UTF8String;
  LModelText: String;
  LSourceHash: String;
  LFeatures: TAudioFeatures;
  LTraining: TAcousticCorpus;
  LBounds: TPassageBounds;
  LBars: TPassageIndices;
  LTokens: TAcousticIndices;
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
  LBar: Integer;
  LExpectedPin: Integer;
  LExpected: Double;
  LGain: Double;
  LFound: Boolean;
  LFadeIn: Boolean;
  LFadeOut: Boolean;
begin
  LCorpus := nil;
  LPalette := nil;
  LModel := nil;
  LSource := nil;
  LOutput := nil;
  LDocument := nil;
  try
    LDocument := GetJSON(ReadText(ParamStr(3) + '.json'));
    Check(LDocument.FindPath('contract').AsString = 'pythian.passage.remix.v1', 'Contract');
    LBytes := ReadFileBytes(ParamStr(1), MaximumCorpusArchiveBytes);
    Check(HashAudioBytes(LBytes) = LDocument.FindPath('archive_sha256').AsString,
      'Archive hash');
    LCorpus := DecodeAcousticArchive(LBytes, LContract, LAttachment);
    LBytes := ReadFileBytes(ParamStr(2), MaximumWaveBytes);
    LSourceHash := HashAudioBytes(LBytes);
    Check(LSourceHash = LDocument.FindPath('source_sha256').AsString, 'Source hash');
    LSource := DecodeWave(LBytes);
    LBounds := LoopBarBounds(ReadWaveLoopInfo(LBytes), LSource.FrameCount, LSource.SampleRate);
    LSourceIndex := -1;
    for LIndex := 0 to LCorpus.SourceCount - 1 do
    begin
      if LCorpus.SourceInfoAt(LIndex).Sha256 = LSourceHash then
      begin
        LSourceIndex := LIndex;
      end;
    end;
    Check(LSourceIndex >= 0, 'Corpus source membership');
    LFeatures := MeasurePassages(LCorpus, LSourceIndex, LBounds);
    LPalette := TAcousticPalette.Create(LFeatures, LDocument.FindPath('palette_limit').AsInteger);
    SetLength(LTraining, 1);
    LTraining[0] := LPalette.Encode(LFeatures);
    LModel := LearnAcousticModel(LTraining, LPalette, 2);
    LModelText := ReadText(ParamStr(3) + '.wfcs');
    Check(EncodeWfcSequenceText(LModel) = LModelText, 'Model matches source bar observations');
    Check(HashText(LModelText) = LDocument.FindPath('model_sha256').AsString, 'Model hash');
    LBytes := ReadFileBytes(ParamStr(3), MaximumWaveBytes);
    Check(HashAudioBytes(LBytes) = LDocument.FindPath('output_sha256').AsString, 'Output hash');
    LOutput := DecodeWave(LBytes);
    Check((LOutput.SampleRate = LSource.SampleRate) and
      (LOutput.Channels = LSource.Channels), 'Output format');
    LEvents := LDocument.FindPath('passages') as TJSONArray;
    Check((LEvents.Count >= 16) and (LEvents.Count <= 64), 'Output bar count');
    SetLength(LBars, LEvents.Count);
    SetLength(LTokens, LEvents.Count);
    LOffset := 0;
    for LIndex := 0 to High(LBars) do
    begin
      LEvent := LEvents.Items[LIndex];
      LBar := LEvent.FindPath('source_bar').AsInteger;
      Check((LBar >= 0) and (LBar < High(LBounds)), 'Source bar range');
      LBars[LIndex] := LBar;
      LTokens[LIndex] := LEvent.FindPath('token').AsInteger;
      Check(LTraining[0][LBar] = LTokens[LIndex], 'Selected source bar belongs to class');
      LExpectedPin := -1;
      if LIndex < 4 then
      begin
        LExpectedPin := LIndex;
      end;
      if (LIndex >= Length(LBars) - 8) and (LIndex < Length(LBars) - 4) then
      begin
        LExpectedPin := LIndex - (Length(LBars) - 8);
      end;
      if LIndex >= Length(LBars) - 4 then
      begin
        LExpectedPin := High(LBounds) - (Length(LBars) - LIndex);
      end;
      Check(LEvent.FindPath('pinned').AsBoolean = (LExpectedPin >= 0), 'Pin annotation');
      Check((LExpectedPin < 0) or (LBar = LExpectedPin), 'Concrete form pin');
      LLength := LBounds[LBar + 1] - LBounds[LBar];
      Check((LEvent.FindPath('source_start_frame').AsInteger = LBounds[LBar]) and
        (LEvent.FindPath('frame_count').AsInteger = LLength) and
        (LEvent.FindPath('output_start_frame').AsInteger = LOffset), 'Exact source/output mapping');
      Inc(LOffset, LLength);
    end;
    Check(LOffset = LOutput.FrameCount, 'Complete output coverage');

    { Independent reachability over actual latent states, without invoking the solver. }
    SetLength(LReachable, LModel.StateCount);
    for LIndex := 0 to High(LTokens) do
    begin
      LNext := nil;
      SetLength(LNext, LModel.StateCount);
      for LState := 0 to LModel.StateCount - 1 do
      begin
        if LModel.ProjectStateToken(LState) <> AcousticToken(LTokens[LIndex]) then
        begin
          Continue;
        end;
        if LIndex = 0 then
        begin
          LNext[LState] := LModel.StartCountAt(LState) > 0;
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
    for LState := 0 to LModel.StateCount - 1 do
    begin
      LFound := LFound or (LReachable[LState] and (LModel.EndCountAt(LState) > 0));
    end;
    Check(LFound, 'Whole learned path has observed start/end and compatible latent history');

    LFade := LSource.SampleRate div 200;
    Check(LDocument.FindPath('fade_frames').AsInteger = LFade, 'Published fade');
    LOffset := 0;
    for LIndex := 0 to High(LBars) do
    begin
      LBar := LBars[LIndex];
      LLength := LBounds[LBar + 1] - LBounds[LBar];
      LFadeIn := (LIndex = 0) or (LBars[LIndex - 1] + 1 <> LBar);
      LFadeOut := (LIndex = High(LBars)) or (LBar + 1 <> LBars[LIndex + 1]);
      for LFrame := 0 to LLength - 1 do
      begin
        LGain := 1;
        if LFadeIn then
        begin
          LGain := Min(LGain, LFrame / Min(LFade, Max(1, LLength div 2)));
        end;
        if LFadeOut then
        begin
          LGain := Min(LGain, (LLength - 1 - LFrame) /
            Min(LFade, Max(1, LLength div 2)));
        end;
        for LChannel := 0 to LSource.Channels - 1 do
        begin
          LExpected := LSource.SampleAt(LBounds[LBar] + LFrame, LChannel) * LGain;
          LExpected := Max(-1, Min(32767 / 32768, LExpected));
          Check(Abs(LOutput.SampleAt(LOffset + LFrame, LChannel) - LExpected) <=
            0.5001 / 32768, 'Published PCM differs from source/fade within quantization');
        end;
      end;
      Inc(LOffset, LLength);
    end;
    WriteLn('Published passages: source/model binding, form, latent path, every stereo PCM sample pass');
  finally
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
    if ParamCount <> 3 then
    begin
      WriteLn('Usage: pythian.tests.passage.output INPUT.pyac SOURCE.wav OUTPUT.wav');
      Halt(2);
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

