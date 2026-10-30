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

unit pythian.tests.studio.material.support;
{ Shared authored stereo input and the actual native capture-analysis path. }
{$mode delphi}
{$H+}
interface
procedure AnalyzeAuthoredStudioCapture(const ACatalogRoot: String);
implementation
uses Classes, SysUtils, Math, Base64, fpjson, pythian.audio, pythian.wave.stream,
  pythian.tools.studio.jobs, pythian.tools.studio.capture;
function AuthoredWave: String;
var
  LStream: TMemoryStream;
  LClip: TAudioClip;
  LSamples: TAudioSamples;
  LIndex: Integer;
begin
  SetLength(LSamples, 8000 * 4 * 2);
  for LIndex := 0 to 31999 do
  begin
    LSamples[LIndex * 2] := 0.2 * Sin(2 * Pi * 220 * LIndex / 8000);
    LSamples[LIndex * 2 + 1] := 0.2 * Sin(2 * Pi * 440 * LIndex / 8000);
  end;
  LClip := TAudioClip.Create(8000, 2, LSamples);
  LStream := TMemoryStream.Create;
  try
    WriteWavePcm16(LStream, LClip);
    SetLength(Result, LStream.Size);
    LStream.Position := 0;
    LStream.ReadBuffer(Result[1], Length(Result));
  finally
    LStream.Free;
    LClip.Free;
  end;
end;

procedure AnalyzeAuthoredStudioCapture(const ACatalogRoot: String);
var
  LBytes: String;
  LWrite, LResult, LAnalysis: TJSONObject;
  LOffset, LCount: Integer;
begin
  LBytes := AuthoredWave;
  LWrite := TJSONObject.Create;
  try
    LWrite.Add('capture_id', 'musical-input');
    LWrite.Add('name', 'Authored stereo pitch control');
    LWrite.Add('bytes', Length(LBytes));
    LWrite.Add('origin', 'wav_import');
    LResult := StartStudioCapture(ACatalogRoot, LWrite);
    LResult.Free;
  finally
    LWrite.Free;
  end;
  LOffset := 0;
  while LOffset < Length(LBytes) do
  begin
    LCount := Min(MaximumStudioUploadChunk, Length(LBytes) - LOffset);
    LWrite := TJSONObject.Create;
    try
      LWrite.Add('capture_id', 'musical-input');
      LWrite.Add('offset', LOffset);
      LWrite.Add('data', EncodeStringBase64(Copy(LBytes, LOffset + 1, LCount)));
      LResult := AppendStudioCapture(ACatalogRoot, LWrite);
      LResult.Free;
    finally
      LWrite.Free;
    end;
    Inc(LOffset, LCount);
  end;
  LAnalysis := InspectStudioCapture(ACatalogRoot, 'musical-input');
  try
    LWrite := TJSONObject.Create;
    try
      LWrite.Add('format', StudioJobWriteFormat);
      LWrite.Add('job_id', 'musical-analysis');
      LWrite.Add('kind', 'capture_inspect');
      LWrite.Add('capture_id', 'musical-input');
      LResult := EnqueueStudioJob(ACatalogRoot, LWrite);
      LResult.Free;
      LResult := ClaimStudioJob(ACatalogRoot, 'musical-analysis');
      LResult.Free;
      try
        AdvanceStudioJob(ACatalogRoot, 'musical-analysis', 'completed', 'completed', 1, 1, LAnalysis);
      finally
        ReleaseStudioWorker(ACatalogRoot);
      end;
    finally
      LWrite.Free;
    end;
  finally
    LAnalysis.Free;
  end;
end;

end.
