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

unit pythian.tools.studio.material.reference;
{$mode delphi}
{$H+}

interface

uses fpjson, pythian.progress;

{ A bounded reference preview, never an instrument source or training pass.
  The original analysis receipt stays separate from the staged excerpt hash. }
function StageStudioMaterialReference(const ACatalogRoot, AJobId: String;
  const AMaterial: TJSONObject; const AProgress: TWorkProgressCallback): TJSONObject;

implementation

uses Classes, SysUtils, Math, pythian.audio, pythian.wave.read,
  pythian.wave.stream, pythian.tools.studio.projects,
  pythian.tools.studio.capture, pythian.tools.listen.assets;

function StageStudioMaterialReference(const ACatalogRoot, AJobId: String;
  const AMaterial: TJSONObject; const AProgress: TWorkProgressCallback): TJSONObject;
var
  LSource: TJSONObject;
  LInput: TFileStream;
  LOutput: TListeningAssetWriter;
  LReader: TWaveFrameReader;
  LWriter: TWavePcm16Writer;
  LStaged: TJSONObject;
  LPath: String;
  LHash: String;
  LFrames: Int64;
  LDone: Int64;
  LCount: Integer;
  LSamples: TAudioSamples;
begin
  Result := nil;
  if AMaterial = nil then Exit;
  LSource := AMaterial.Objects['source'];
  if LSource.Strings['kind'] = 'manual' then Exit;
  LInput := nil;
  LReader := nil;
  LOutput := nil;
  LWriter := nil;
  LStaged := nil;
  try
    if LSource.Strings['kind'] = 'catalog' then
      LInput := OpenStudioSourceAudio(ACatalogRoot, LSource.Strings['source_sha256'])
    else
    begin
      LInput := OpenStudioCapture(ACatalogRoot, LSource.Strings['id'], LHash, LPath);
      if LHash <> LSource.Strings['source_sha256'] then
        raise EAudio.Create('Retained reference differs from the saved analysis source');
    end;
    LReader := TWaveFrameReader.Create(LInput);
    LFrames := LSource.Int64s['end_frame'] - LSource.Int64s['start_frame'];
    if (LReader.SampleRate <> LSource.Integers['sample_rate']) or
      (LSource.Int64s['start_frame'] < 0) or
      (LSource.Int64s['end_frame'] > LReader.FrameCount) or
      (LFrames < 1) or (LFrames > Int64(LReader.SampleRate) * 30) then
      raise EAudio.Create('Original reference range differs from its saved source clock');
    LReader.SeekFrame(LSource.Int64s['start_frame']);
    LOutput := TListeningAssetWriter.Create(ACatalogRoot, AJobId + '-reference');
    LWriter := TWavePcm16Writer.Create(LOutput, LReader.SampleRate, LReader.Channels, LFrames);
    LDone := 0;
    while LDone < LFrames do
    begin
      ReportWork(AProgress, 'instrumental_reference', wuFrames, LDone, LFrames);
      LCount := Min(Int64(4096), LFrames - LDone);
      LSamples := LReader.ReadFrames(LCount);
      if Length(LSamples) <> LCount * LReader.Channels then
        raise EAudio.Create('Original reference read ended early');
      LWriter.AppendSamples(LSamples);
      Inc(LDone, LCount);
    end;
    LWriter.Finish;
    LStaged := LOutput.Finish;
    FreeAndNil(LWriter);
    FreeAndNil(LOutput);
    Result := TJSONObject(LSource.Clone);
    try
      Result.Add('storage', 'listening');
      Result.Add('wav_sha256', LStaged.Strings['sha256']);
      Result.Add('wav_bytes', LStaged.Int64s['bytes']);
      Result.Add('channels', LStaged.Integers['channels']);
      Result.Add('frame_count', LStaged.Int64s['frames']);
      Result.Add('encoding', 'decoded PCM16 reference excerpt');
      Result.Add('source_binding', 'Immutable catalog/capture reference; original analysis digest is retained separately');
      ReportWork(AProgress, 'instrumental_reference', wuFrames, LFrames, LFrames);
    except
      FreeAndNil(Result);
      raise;
    end;
  finally
    LStaged.Free;
    LWriter.Free;
    LOutput.Free;
    LReader.Free;
    LInput.Free;
  end;
end;

end.
