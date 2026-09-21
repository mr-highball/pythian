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
program pythian_convert;

{$mode delphi}
{$H+}

uses
  Classes, SysUtils, Math, fpjson,
  pythian.audio, pythian.hash, pythian.wave.read, pythian.wave.stream,
  pythian.wave.resample, pythian.resample.stream;

procedure Convert(const AInputName, AOutputName: String; const AOutputRate,
  ABlockFrames: Integer; const AGain, APeakCeiling: Double);
var
  LInput: TFileStream;
  LWave: TWaveFrameReader;
  LStaged: String;
  LSourceHash: String;
  LOutputHash: String;
  LExpected: Int64;
  LSourceSize: Int64;
  LGain: Double;
  LPeak: Double;
  LInputPeak: Double;
  LOutputPeak: Double;
  LHistoryFrames: Integer;
  LKernelCacheWeights: Integer;
  LKernelCachePhases: Integer;
  LIsRF64: Boolean;
  LDocument: TJSONObject;
  LCopySource: TFileStream;
  LCopyTarget: TFileStream;

  function Process(const AWrite: Boolean): Double;
  var
    LPcm: TWavePcmReader;
    LResampler: TSincResampleStream;
    LOutput: TFileStream;
    LSink: TStreamAudioSink;
    LWriter: TWavePcm16Writer;
    LSamples: TAudioSamples;
    LLeft: Double;
    LRight: Double;
    LValue: Double;
    LCount: Integer;
    LChannel: Integer;
  begin
    Result := 0;
    LPcm := nil;
    LResampler := nil;
    LOutput := nil;
    LSink := nil;
    LWriter := nil;
    LWave.SeekFrame(0);
    try
      LPcm := TWavePcmReader.Create(LWave, ABlockFrames);
      LResampler := TSincResampleStream.Create(LPcm, AOutputRate);
      LHistoryFrames := LResampler.HistoryFrames;
      LKernelCacheWeights := LResampler.KernelCacheWeights;
      LKernelCachePhases := LResampler.KernelCachePhases;
      if AWrite then
      begin
        LOutput := TFileStream.Create(LStaged, fmCreate);
        LSink := TStreamAudioSink.Create(LOutput);
        LWriter := TWavePcm16Writer.Create(LSink, AOutputRate, LWave.Channels, LExpected);
        LIsRF64 := LWriter.IsRF64;
        SetLength(LSamples, ABlockFrames * LWave.Channels);
      end;
      LCount := 0;
      LLeft := 0;
      LRight := 0;
      while LResampler.ReadFrame(LLeft, LRight) do
      begin
        Result := Max(Result, Max(Abs(LLeft), Abs(LRight)));
        if AWrite then
        begin
          for LChannel := 0 to LWave.Channels - 1 do
          begin
            if LChannel = 0 then
            begin
              LValue := LLeft * LGain;
            end
            else
            begin
              LValue := LRight * LGain;
            end;
            RequireFinite(LValue, 'Converted sample');
            if Abs(LValue) > 1 then
            begin
              raise EAudio.Create('Converted samples exceed PCM16 headroom; choose --gain or --peak');
            end;
            LSamples[LCount] := LValue;
            LOutputPeak := Max(LOutputPeak, Abs(LSamples[LCount]));
            Inc(LCount);
          end;
          if LCount = Length(LSamples) then
          begin
            LWriter.AppendSamples(LSamples);
            LCount := 0;
          end;
        end;
      end;
      if (LResampler.InputFrameCount <> LWave.FrameCount) or
        (LResampler.OutputFrameCount <> LExpected) then
      begin
        raise EAudio.Create('Streaming conversion frame accounting differs');
      end;
      LInputPeak := LPcm.Peak;
      if AWrite then
      begin
        SetLength(LSamples, LCount);
        LWriter.AppendSamples(LSamples);
        LWriter.Finish;
        LOutput.Position := 0;
        LOutputHash := Sha256Stream(LOutput, LOutput.Size);
      end;
    finally
      LWriter.Free;
      LSink.Free;
      LOutput.Free;
      LResampler.Free;
      LPcm.Free;
    end;
  end;

begin
  if SameFileName(ExpandFileName(AInputName), ExpandFileName(AOutputName)) then
  begin
    raise EAudio.Create('Output must differ from the source file');
  end;
  LInput := nil;
  LWave := nil;
  LDocument := nil;
  LStaged := '';
  LOutputPeak := 0;
  LGain := AGain;
  try
    LInput := TFileStream.Create(AInputName, fmOpenRead or fmShareDenyWrite);
    LWave := TWaveFrameReader.Create(LInput);
    LExpected := StreamResampleFrameCount(LWave.FrameCount, LWave.SampleRate, AOutputRate);
    LSourceSize := LInput.Size;
    LInput.Position := 0;
    LSourceHash := Sha256Stream(LInput, LSourceSize);
    if APeakCeiling > 0 then
    begin
      LPeak := Process(False);
      if LPeak > APeakCeiling then
      begin
        { Reserve against a rounding overshoot when the requested ceiling is unity. }
        LGain := (APeakCeiling * (1 - 1E-12)) / LPeak;
      end;
    end;
    LStaged := GetTempFileName(ExtractFilePath(ExpandFileName(AOutputName)), 'pythian-');
    LPeak := Process(True);
    LInput.Position := 0;
    if (LInput.Size <> LSourceSize) or (Sha256Stream(LInput, LSourceSize) <> LSourceHash) then
    begin
      raise EAudio.Create('Source changed during conversion');
    end;
    LDocument := TJSONObject.Create;
    LDocument.Add('contract', 'pythian.wave.conversion');
    LDocument.Add('source', ExtractFileName(AInputName));
    LDocument.Add('source_sha256', LSourceHash);
    LDocument.Add('output_sha256', LOutputHash);
    LDocument.Add('input_rate', LWave.SampleRate);
    LDocument.Add('output_rate', AOutputRate);
    LDocument.Add('channels', LWave.Channels);
    LDocument.Add('input_frames', LWave.FrameCount);
    LDocument.Add('output_frames', LExpected);
    LDocument.Add('source_peak', LInputPeak);
    LDocument.Add('resampled_peak', LPeak);
    LDocument.Add('applied_gain', LGain);
    LDocument.Add('peak_ceiling', APeakCeiling);
    LDocument.Add('output_peak_before_pcm16', LOutputPeak);
    LDocument.Add('audio_passes', 1 + Ord(APeakCeiling > 0));
    LDocument.Add('block_frames', ABlockFrames);
    LDocument.Add('history_frames', LHistoryFrames);
    LDocument.Add('kernel_cache_weights', LKernelCacheWeights);
    LDocument.Add('kernel_cache_phases', LKernelCachePhases);
    LDocument.Add('rf64', LIsRF64);
    LDocument.Add('policy', 'Continuous centered sinc; exact ceiling duration; one gain across channels and time; --peak only attenuates; PCM16 clipping rejects; source metadata omitted');
    { Complete validation/encoding precedes replacement. Physical destination I/O
      failures during this bounded copy do not promise atomic rollback. }
    LCopySource := TFileStream.Create(LStaged, fmOpenRead or fmShareDenyWrite);
    try
      LCopyTarget := TFileStream.Create(AOutputName, fmCreate);
      try
        LCopyTarget.CopyFrom(LCopySource, LCopySource.Size);
      finally
        LCopyTarget.Free;
      end;
    finally
      LCopySource.Free;
    end;
    WriteLn(LDocument.FormatJSON);
  finally
    LDocument.Free;
    LWave.Free;
    LInput.Free;
    if LStaged <> '' then
    begin
      DeleteFile(LStaged);
    end;
  end;
end;

var
  LRate: Integer;
  LBlockFrames: Integer;
  LGain: Double;
  LPeakCeiling: Double;
  LOption: String;
  LFormat: TFormatSettings;
  LGainSelected: Boolean;
  LBlockSelected: Boolean;
  I: Integer;
begin
  try
    if (ParamCount < 3) or not Odd(ParamCount) then
    begin
      raise EAudio.Create('Usage: pythian.convert INPUT.wav OUTPUT.wav SAMPLE_RATE [--gain VALUE | --peak CEILING] [--block-frames N]');
    end;
    LRate := StrToInt(ParamStr(3));
    ValidateAudioFormat(LRate, 1);
    LGain := 1;
    LPeakCeiling := 0;
    LBlockFrames := 4096;
    LGainSelected := False;
    LBlockSelected := False;
    LFormat := DefaultFormatSettings;
    LFormat.DecimalSeparator := '.';
    I := 4;
    while I <= ParamCount do
    begin
      LOption := ParamStr(I);
      if ((LOption = '--gain') or (LOption = '--peak')) and not LGainSelected then
      begin
        LGainSelected := True;
        if LOption = '--gain' then
        begin
          LGain := StrToFloat(ParamStr(I + 1), LFormat);
        end
        else
        begin
          LPeakCeiling := StrToFloat(ParamStr(I + 1), LFormat);
          RequireFinite(LPeakCeiling, 'Peak ceiling');
          if (LPeakCeiling <= 0) or (LPeakCeiling > 1) then
          begin
            raise EAudio.Create('Peak ceiling must be greater than zero and at most one');
          end;
        end;
      end
      else if (LOption = '--block-frames') and not LBlockSelected then
      begin
        LBlockSelected := True;
        LBlockFrames := StrToInt(ParamStr(I + 1));
      end
      else
      begin
        raise EAudio.Create('Unknown or duplicate conversion option');
      end;
      Inc(I, 2);
    end;
    RequireFinite(LGain, 'Conversion gain');
    if (LGain < 0) or (LBlockFrames < 1) or (LBlockFrames > MaximumWaveReadFrames) then
    begin
      raise EAudio.Create('Gain must be nonnegative and block frames must be 1..65536');
    end;
    Convert(ParamStr(1), ParamStr(2), LRate, LBlockFrames, LGain, LPeakCeiling);
  except
    on LException: Exception do
    begin
      WriteLn(StdErr, LException.ClassName, ': ', LException.Message);
      Halt(1);
    end;
  end;
end.
