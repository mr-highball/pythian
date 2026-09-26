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
program pythian_wave_transcode;

{$mode delphi}
{$H+}

uses
  Classes,
  SysUtils,
  pythian.audio,
  pythian.wave.read,
  pythian.wave.stream;

procedure Transcode(const AInputName, AOutputName: String; const ABlockFrames: Integer);
var
  LInput: TFileStream;
  LOutput: TFileStream;
  LReader: TWaveFrameReader;
  LSink: TStreamAudioSink;
  LWriter: TWavePcm16Writer;
  LSamples: TAudioSamples;
begin
  if SameFileName(ExpandFileName(AInputName), ExpandFileName(AOutputName)) then
  begin
    raise EAudio.Create('Output must differ from the source file');
  end;
  if (ABlockFrames < 1) or (ABlockFrames > MaximumWaveReadFrames) then
  begin
    raise EAudio.Create('Block size must be 1..65536 frames');
  end;
  LInput := nil;
  LOutput := nil;
  LReader := nil;
  LSink := nil;
  LWriter := nil;
  try
    LInput := TFileStream.Create(AInputName, fmOpenRead or fmShareDenyWrite);
    LReader := TWaveFrameReader.Create(LInput);
    LOutput := TFileStream.Create(AOutputName, fmCreate);
    LSink := TStreamAudioSink.Create(LOutput);
    LWriter := TWavePcm16Writer.Create(LSink, LReader.SampleRate, LReader.Channels,
      LReader.FrameCount);
    while LReader.FramePosition < LReader.FrameCount do
    begin
      LSamples := LReader.ReadFrames(ABlockFrames);
      LWriter.AppendSamples(LSamples);
    end;
    LWriter.Finish;
    WriteLn('PCM16: ', LWriter.FrameCount, ' frames; ', LWriter.SampleRate,
      ' Hz; ', LWriter.Channels, ' channels; RF64=', BoolToStr(LWriter.IsRF64, True));
    WriteLn('Bounded input blocks: ', ABlockFrames, ' frames; audio metadata is not copied.');
  finally
    LWriter.Free;
    LSink.Free;
    LReader.Free;
    LOutput.Free;
    LInput.Free;
  end;
end;

var
  LBlockFrames: Integer;

begin
  try
    if (ParamCount < 2) or (ParamCount > 3) then
    begin
      WriteLn('Usage: pythian.wave.transcode INPUT.wav OUTPUT.wav [BLOCK_FRAMES]');
      Halt(2);
    end;
    LBlockFrames := 4096;
    if (ParamCount = 3) and not TryStrToInt(ParamStr(3), LBlockFrames) then
    begin
      raise EAudio.Create('Block size must be an integer');
    end;
    Transcode(ParamStr(1), ParamStr(2), LBlockFrames);
  except
    on LException: Exception do
    begin
      WriteLn(StdErr, LException.ClassName, ': ', LException.Message);
      Halt(1);
    end;
  end;
end.

