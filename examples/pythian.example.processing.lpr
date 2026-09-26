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

program pythian_example_processing;

{$mode delphi}
{$H+}

uses
  Classes,
  SysUtils,
  Math,
  pythian.audio,
  pythian.analysis,
  pythian.analysis.wave,
  pythian.effects,
  pythian.hash,
  pythian.reverb,
  pythian.wave,
  pythian.wave.read,
  pythian.wave.stream;

procedure Run(const AInputName, AOutputName: String);
const
  CBlockFrames = 257;
var
  LInput: TFileStream;
  LOutput: TFileStream;
  LReader: TWaveFrameReader;
  LSink: TStreamAudioSink;
  LWriter: TWavePcm16Writer;
  LChain: TEffectChain;
  LEffect: TReverbEffect;
  LSettings: TReverbSettings;
  LOptions: TAnalysisOptions;
  LFeatures: TAudioFeatures;
  LSamples: TAudioSamples;
  LProcessed: TAudioSamples;
  LFrame: Integer;
  LBlock: Integer;
  LSourceFrames: Integer;
  LOutputFrames: Integer;
  LRate: Integer;
  LFeatureCount: Integer;
  LWork: Int64;
  LRemaining: Integer;
  LLeft: Double;
  LRight: Double;
  LPeak: Double;
  LSourceHash: String;
begin
  if SameFileName(ExpandFileName(AInputName), ExpandFileName(AOutputName)) then
  begin
    raise EAudio.Create('Processing output must differ from input');
  end;
  LInput := nil;
  LOutput := nil;
  LReader := nil;
  LSink := nil;
  LWriter := nil;
  LChain := nil;
  LEffect := nil;
  try
    LInput := TFileStream.Create(AInputName, fmOpenRead or fmShareDenyWrite);
    if LInput.Size > MaximumWaveBytes then
    begin
      raise EAudio.Create('Example input exceeds encoded-byte budget');
    end;
    LReader := TWaveFrameReader.Create(LInput);
    LRate := LReader.SampleRate;
    if LReader.FrameCount > MaximumClipSamples div 2 - LRate then
    begin
      raise EAudio.Create('Example output exceeds sample budget');
    end;
    LSourceFrames := Integer(LReader.FrameCount);
    LOutputFrames := LSourceFrames + LRate;
    LOptions := DefaultAnalysisOptions;
    PlanAudioAnalysis(LOutputFrames, 2, LOptions, LFeatureCount, LWork);
    LInput.Position := 0;
    LSourceHash := Sha256Stream(LInput, LInput.Size);
    LReader.SeekFrame(0);
    LSettings := DefaultReverbSettings(LRate);
    LSettings.DryGain := 0.65;
    LSettings.WetGain := 0.25;
    LEffect := TReverbEffect.Create(LRate, LSettings);
    LChain := TEffectChain.Create(LRate);
    LChain.Add(LEffect);
    LEffect := nil;
    LOutput := TFileStream.Create(AOutputName, fmCreate);
    LSink := TStreamAudioSink.Create(LOutput);
    LWriter := TWavePcm16Writer.Create(LSink, LRate, 2, LOutputFrames);
    LRemaining := LOutputFrames;
    LPeak := 0;
    while LRemaining > 0 do
    begin
      LBlock := Min(CBlockFrames, LRemaining);
      LSourceFrames := 0;
      if LReader.FramePosition < LReader.FrameCount then
      begin
        LSamples := LReader.ReadFrames(LBlock);
        LSourceFrames := Length(LSamples) div LReader.Channels;
      end;
      SetLength(LProcessed, LBlock * 2);
      for LFrame := 0 to LBlock - 1 do
      begin
        LLeft := 0;
        LRight := 0;
        if LFrame < LSourceFrames then
        begin
          LLeft := LSamples[LFrame * LReader.Channels];
          LRight := LLeft;
          if LReader.Channels = 2 then
          begin
            LRight := LSamples[LFrame * 2 + 1];
          end;
        end;
        LChain.Process(LLeft, LRight, LLeft, LRight);
        if (Abs(LLeft) > 1) or (Abs(LRight) > 1) then
        begin
          raise EAudio.Create('Example requires more input headroom');
        end;
        LPeak := Max(LPeak, Max(Abs(LLeft), Abs(LRight)));
        LProcessed[LFrame * 2] := LLeft;
        LProcessed[LFrame * 2 + 1] := LRight;
      end;
      LWriter.AppendSamples(LProcessed);
      Dec(LRemaining, LBlock);
    end;
    LWriter.Finish;
    FreeAndNil(LWriter);
    FreeAndNil(LSink);
    FreeAndNil(LOutput);
    FreeAndNil(LReader);
    FreeAndNil(LInput);

    { Read back through the same bounded spectral engine, with no full clip. }
    LInput := TFileStream.Create(AOutputName, fmOpenRead or fmShareDenyWrite);
    LReader := TWaveFrameReader.Create(LInput);
    if (LReader.FrameCount <> LOutputFrames) or (LReader.Channels <> 2) then
    begin
      raise EAudio.Create('Processed WAV geometry mismatch');
    end;
    LFeatures := AnalyzeWave(LReader, LOptions);
    if Length(LFeatures) <> LFeatureCount then
    begin
      raise EAudio.Create('Processed WAV feature count mismatch');
    end;
    LInput.Position := 0;
    WriteLn('Source SHA256: ', LSourceHash);
    WriteLn('Output SHA256: ', Sha256Stream(LInput, LInput.Size));
    WriteLn(LOutputFrames, ' stereo frames; ', Length(LFeatures),
      ' observations; peak ', LPeak:0:10, '; one-second tail');
  finally
    LEffect.Free;
    LChain.Free;
    LWriter.Free;
    LSink.Free;
    LOutput.Free;
    LReader.Free;
    LInput.Free;
  end;
end;

begin
  try
    if ParamCount <> 2 then
    begin
      raise EAudio.Create('Usage: pythian.example.processing INPUT.wav OUTPUT.wav');
    end;
    Run(ParamStr(1), ParamStr(2));
  except
    on LException: Exception do
    begin
      WriteLn(StdErr, LException.ClassName, ': ', LException.Message);
      Halt(1);
    end;
  end;
end.
