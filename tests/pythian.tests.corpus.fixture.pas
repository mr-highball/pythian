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
unit pythian.tests.corpus.fixture;

{$mode delphi}
{$H+}

interface

uses
  pythian.corpus,
  pythian.granular;

function CreateCorpusFixture(out ASources: TAudioSources): TAcousticCorpusData;
procedure ReleaseFixtureSources(var ASources: TAudioSources);

implementation

uses
  Math,
  pythian.audio,
  pythian.analysis,
  pythian.wave,
  pythian.hash;

procedure ReleaseFixtureSources(var ASources: TAudioSources);
var
  LIndex: Integer;
begin
  for LIndex := 0 to High(ASources) do
  begin
    ASources[LIndex].Free;
  end;
  ASources := nil;
end;

function CreateCorpusFixture(out ASources: TAudioSources): TAcousticCorpusData;
var
  LInfo: TAcousticSourceInfos;
  LSamples: TAudioSamples;
  LOptions: TAnalysisOptions;
  LIndex: Integer;
  LFrame: Integer;
begin
  ASources := nil;
  SetLength(ASources, 2);
  SetLength(LInfo, 2);
  LOptions := DefaultAnalysisOptions;
  LOptions.WindowFrames := 64;
  LOptions.HopFrames := 32;
  try
    for LIndex := 0 to 1 do
    begin
      SetLength(LSamples, 256);
      for LFrame := 0 to High(LSamples) do
      begin
        LSamples[LFrame] := 0.5 * Sin(2 * Pi * (LIndex + 1) * LFrame / 8);
      end;
      ASources[LIndex] := TAudioClip.Create(8192, 1, LSamples);
      LInfo[LIndex].Name := 'tone.wav';
      LInfo[LIndex].Provenance := 'Analytic sine fixture, authored for this test';
      LInfo[LIndex].SampleRate := 8192;
      LInfo[LIndex].Channels := 1;
      LInfo[LIndex].FrameCount := 256;
      LInfo[LIndex].Sha256 := Sha256Bytes(EncodeWavePcm16(ASources[LIndex]));
    end;
    Result := TrainAcousticCorpus(ASources, LInfo, LOptions, 4);
  except
    ReleaseFixtureSources(ASources);
    raise;
  end;
end;

end.
