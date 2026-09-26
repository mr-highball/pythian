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
program pythian_inspect;

{$mode delphi}
{$H+}

uses
  SysUtils,
  fpjson,
  pythian.audio,
  pythian.meter,
  pythian.tools.files;

procedure InspectFile(const AFileName: String);
var
  LClip: TAudioClip;
  LHash: String;
  LLevels: TAudioLevels;
  LDocument: TJSONObject;
  LChannels: TJSONArray;
  LChannel: TJSONObject;
  LIndex: Integer;
begin
  LClip := LoadWaveSource(AFileName, LHash);
  try
    LLevels := MeasureAudio(LClip);
    LDocument := TJSONObject.Create;
    try
      LDocument.Add('file', ExtractFileName(AFileName));
      LDocument.Add('sha256', LHash);
      LDocument.Add('sample_rate', LClip.SampleRate);
      LDocument.Add('frames', LClip.FrameCount);
      LDocument.Add('duration_seconds', LClip.FrameCount / LClip.SampleRate);
      LChannels := TJSONArray.Create;
      LDocument.Add('channels', LChannels);
      for LIndex := 0 to LClip.Channels - 1 do
      begin
        LChannel := TJSONObject.Create;
        LChannels.Add(LChannel);
        LChannel.Add('peak', LLevels[LIndex].Peak);
        LChannel.Add('rms', LLevels[LIndex].Rms);
        LChannel.Add('mean', LLevels[LIndex].Mean);
      end;
      WriteLn(LDocument.FormatJSON);
    finally
      LDocument.Free;
    end;
  finally
    LClip.Free;
  end;
end;

begin
  try
    if ParamCount <> 1 then
    begin
      WriteLn('Usage: pythian.inspect INPUT.wav');
      Halt(2);
    end;
    InspectFile(ParamStr(1));
  except
    on LException: Exception do
    begin
      WriteLn(StdErr, LException.ClassName, ': ', LException.Message);
      Halt(1);
    end;
  end;
end.
