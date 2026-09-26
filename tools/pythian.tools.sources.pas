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
unit pythian.tools.sources;

{$mode delphi}
{$H+}

interface

uses
  pythian.corpus,
  pythian.granular;

{ Load each persisted source exactly once by SHA256, allowing any path order.
  Returns an owning array in corpus order; failure releases every loaded clip.
  Stored names/provenance are never opened as paths. }
function LoadBoundCorpusSources(const ACorpus: TAcousticCorpusData;
  const APaths: array of String): TAudioSources;
procedure FreeAudioSources(var ASources: TAudioSources);

implementation

uses
  pythian.audio,
  pythian.tools.files;

procedure FreeAudioSources(var ASources: TAudioSources);
var
  LIndex: Integer;
begin
  for LIndex := 0 to High(ASources) do
  begin
    ASources[LIndex].Free;
  end;
  ASources := nil;
end;

function LoadBoundCorpusSources(const ACorpus: TAcousticCorpusData;
  const APaths: array of String): TAudioSources;
var
  LClip: TAudioClip;
  LHash: String;
  LInfo: TAcousticSourceInfo;
  LArgument: Integer;
  LIndex: Integer;
  LMatch: Integer;
begin
  if (ACorpus = nil) or (Length(APaths) <> ACorpus.SourceCount) then
  begin
    raise EAudio.Create('Provide exactly one WAV for each archive source (any order)');
  end;
  Result := nil;
  SetLength(Result, ACorpus.SourceCount);
  try
    for LArgument := 0 to High(APaths) do
    begin
      LClip := LoadWaveSource(APaths[LArgument], LHash);
      try
        LMatch := -1;
        for LIndex := 0 to ACorpus.SourceCount - 1 do
        begin
          if ACorpus.SourceInfoAt(LIndex).Sha256 = LHash then
          begin
            LMatch := LIndex;
            Break;
          end;
        end;
        if LMatch < 0 then
        begin
          raise EAudio.Create('WAV bytes do not match any persisted source SHA256');
        end;
        LInfo := ACorpus.SourceInfoAt(LMatch);
        if (Result[LMatch] <> nil) or (LClip.SampleRate <> LInfo.SampleRate) or
          (LClip.Channels <> LInfo.Channels) or (LClip.FrameCount <> LInfo.FrameCount) then
        begin
          raise EAudio.Create('Duplicate source or source format differs from archive');
        end;
        Result[LMatch] := LClip;
        LClip := nil;
      finally
        LClip.Free;
      end;
    end;
  except
    FreeAudioSources(Result);
    raise;
  end;
end;

end.

