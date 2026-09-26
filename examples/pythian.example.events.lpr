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
program pythian_example_events;

{$mode delphi}
{$H+}

uses
  Classes, SysUtils, pythian.audio, pythian.wave, pythian.hash, pythian.analysis,
  pythian.granular, pythian.corpus, pythian.corpus.archive, pythian.passage,
  pythian.wfc.event.corpus, pythian.wfc.event.archive, pythian.wfc.generation,
  wfc, wfc_model, wfc_sequence;

function ReadBytes(const APath: String; const AMaximum: Integer): TAudioBytes;
var
  LStream: TFileStream;
begin
  LStream := TFileStream.Create(APath, fmOpenRead or fmShareDenyWrite);
  try
    if LStream.Size > AMaximum then
    begin
      raise EAudio.Create('Example input exceeds byte budget');
    end;
    Result := nil;
    SetLength(Result, LStream.Size);
    if Length(Result) > 0 then
    begin
      LStream.ReadBuffer(Result[0], Length(Result));
    end;
  finally
    LStream.Free;
  end;
end;

procedure WriteBytes(const APath: String; const ABytes: TAudioBytes);
var
  LStream: TFileStream;
begin
  LStream := TFileStream.Create(APath, fmCreate);
  try
    if Length(ABytes) > 0 then
    begin
      LStream.WriteBuffer(ABytes[0], Length(ABytes));
    end;
  finally
    LStream.Free;
  end;
end;

procedure Run;
var
  LSources: TAudioSources;
  LInfo: TAcousticSourceInfos;
  LCorpus: TAcousticCorpusData;
  LLoadedCorpus: TAcousticCorpusData;
  LLearning: TRecordedEventLearning;
  LLoaded: TRecordedEventLearning;
  LInputs: TRecordedEventInputs;
  LMember: TRecordedEventMember;
  LSelections: TPassageIndices;
  LPassages: TRecordedPassages;
  LTokens: TWfcModelTokens;
  LOptions: TAcousticGenerationOptions;
  LReport: TGraphSolveReport;
  LBytes: TAudioBytes;
  LArchive: TAudioBytes;
  LReplay: TAudioBytes;
  LPolicy: UTF8String;
  LOutput: TAudioClip;
  LDestination: String;
  I: Integer;
  J: Integer;
begin
  if ParamCount <> 3 then
  begin
    raise EAudio.Create('Usage: pythian.example.events INPUT_A.wav INPUT_B.wav OUTPUT_PREFIX');
  end;
  for I := 0 to 1 do
  begin
    LDestination := ParamStr(3) + '.wav';
    if I = 1 then
    begin
      LDestination := ParamStr(3) + '.pyac';
    end;
    for J := 1 to 2 do
    begin
      if SameFileName(ExpandFileName(LDestination), ExpandFileName(ParamStr(J))) then
      begin
        raise EAudio.Create('Example output must not replace an input');
      end;
    end;
  end;
  LCorpus := nil;
  LLoadedCorpus := nil;
  LLearning := nil;
  LLoaded := nil;
  LOutput := nil;
  SetLength(LSources, 2);
  SetLength(LInfo, 2);
  SetLength(LInputs, 2);
  try
    for I := 0 to 1 do
    begin
      LBytes := ReadBytes(ParamStr(I + 1), MaximumWaveBytes);
      LSources[I] := DecodeWave(LBytes);
      LInfo[I].Name := UTF8String(ExtractFileName(ParamStr(I + 1)));
      LInfo[I].Sha256 := Sha256Bytes(LBytes);
      LInfo[I].Provenance := 'Caller-supplied WAV; eight explicit equal-length source intervals';
      LInfo[I].SampleRate := LSources[I].SampleRate;
      LInfo[I].Channels := LSources[I].Channels;
      LInfo[I].FrameCount := LSources[I].FrameCount;
      if LInfo[I].FrameCount < 8 then
      begin
        raise EAudio.Create('Example requires at least eight source frames');
      end;
      LInputs[I].SourceIndex := I;
      SetLength(LInputs[I].Bounds, 9);
      SetLength(LInputs[I].RunIndices, 8);
      SetLength(LInputs[I].StartsAtOnset, 8);
      for J := 0 to 8 do
      begin
        LInputs[I].Bounds[J] := Int64(LInfo[I].FrameCount) * J div 8;
      end;
    end;
    LCorpus := TrainAcousticCorpus(LSources, LInfo, DefaultAnalysisOptions, 8);
    LLearning := TRecordedEventLearning.Create(LCorpus, LInputs,
      LSources[0].SampleRate div 50, 8, 2);
    LArchive := EncodeRecordedEventCorpus(LCorpus, LLearning,
      'Example v1: eight explicit equal intervals per recording; no inferred onsets or beats');
    WriteBytes(ParamStr(3) + '.pyac', LArchive);
    FreeAndNil(LLearning);
    FreeAndNil(LCorpus);

    LBytes := ReadBytes(ParamStr(3) + '.pyac', MaximumCorpusArchiveBytes);
    LLoadedCorpus := DecodeRecordedEventCorpus(LBytes, LLoaded, LPolicy);
    LReplay := EncodeRecordedEventCorpus(LLoadedCorpus, LLoaded, LPolicy);
    if (Length(LArchive) <> Length(LReplay)) or
      not CompareMem(@LArchive[0], @LReplay[0], Length(LArchive)) then
    begin
      raise EAudio.Create('Saved event learning changed during disk round trip');
    end;
    LOptions := DefaultAcousticGenerationOptions;
    LOptions.Extent := wseWhole;
    LOptions.FrameCount := 8;
    if not TryGenerateTokenSequence(LLoaded.Model, LOptions, nil, LTokens, LReport) then
    begin
      raise EAudio.Create('Bounded saved-event generation did not solve');
    end;
    LSelections := LLoaded.SelectMembers(LTokens, LOptions.Seed);
    SetLength(LPassages, Length(LSelections));
    for I := 0 to High(LSelections) do
    begin
      LMember := LLoaded.MemberAt(LSelections[I]);
      LPassages[I] := LMember.Passage;
    end;
    LOutput := RenderPassages(LSources, LPassages, LSources[0].SampleRate div 1000);
    SaveWavePcm16(ParamStr(3) + '.wav', LOutput);
    WriteLn('Saved event consumer: ', LLoaded.MemberCount, ' members / ',
      LLoaded.RunCount, ' independent runs; generated ', Length(LTokens),
      ' events / ', LOutput.FrameCount, ' frames; archive SHA256 ', Sha256Bytes(LArchive));
  finally
    LOutput.Free;
    LLoaded.Free;
    LLoadedCorpus.Free;
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
    Run;
  except
    on LException: Exception do
    begin
      WriteLn(StdErr, LException.Message);
      Halt(1);
    end;
  end;
end.
