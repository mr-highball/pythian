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
program pythian_example_corpus_intake;

{$mode delphi}
{$H+}

uses
  SysUtils, Math, pythian.audio, pythian.wave, pythian.corpus.intake,
  pythian.tools.files, pythian.tools.corpus.intake;

const
  ExampleLicense = 'MIT License'#10#10 +
    'Copyright (c) 2026 mr-highball'#10#10 +
    'Permission is hereby granted, free of charge, to any person obtaining a copy ' +
    'of this software and associated documentation files (the "Software"), to deal ' +
    'in the Software without restriction, including without limitation the rights ' +
    'to use, copy, modify, merge, publish, distribute, sublicense, and/or sell ' +
    'copies of the Software, and to permit persons to whom the Software is ' +
    'furnished to do so, subject to the following conditions:'#10#10 +
    'The above copyright notice and this permission notice shall be included in all ' +
    'copies or substantial portions of the Software.'#10#10 +
    'THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR ' +
    'IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, ' +
    'FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE ' +
    'AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER ' +
    'LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, ' +
    'OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE ' +
    'SOFTWARE.';

var
  D: TCorpusIntakeDefinition;
  P: TCorpusIntakePlan;
  LSamples: TAudioSamples;
  LBytes: TAudioBytes;
  LClip: TAudioClip;
  LDirectory, LLabel: String;
  I, J, K: Integer;
begin
  try
    if ParamCount <> 1 then raise Exception.Create('Supply an ignored output directory');
    LDirectory := IncludeTrailingPathDelimiter(ExpandFileName(ParamStr(1)));
    if not ForceDirectories(LDirectory) then raise Exception.Create('Cannot create example directory');
    D := Default(TCorpusIntakeDefinition);
    SetLength(D.Families, 2); SetLength(D.Sources, 2); SetLength(D.Ranges, 4);
    for I := 0 to 1 do
    begin
      D.Families[I].Id := 'first-party-family-' + IntToStr(I);
      D.Families[I].WorkId := 'first-party-work-' + IntToStr(I);
      D.Families[I].IdentityEvidence := 'Independent waveforms authored by this MIT-licensed Pascal example; no external media';
      D.Families[I].Verified := True;
      if I = 0 then D.Families[I].Partition := cpTraining
      else D.Families[I].Partition := cpDevelopment;
      SetLength(LSamples, 16000);
      for J := 0 to High(LSamples) do
        if (I = 0) and (J >= 6000) and (J < 10000) then LSamples[J] := 0
        else if (I = 0) and (J >= 10000) then
          LSamples[J] := 0.2 * Sin(2 * Pi * 880 * J / 8000)
        else LSamples[J] := 0.2 * Sin(2 * Pi * (220 + I * 330) * J / 8000);
      LClip := TAudioClip.Create(8000, 1, LSamples);
      try
        LBytes := EncodeWavePcm16(LClip);
      finally
        LClip.Free;
      end;
      with D.Sources[I] do
      begin
        Id := 'source-' + IntToStr(I); Path := 'source-' + IntToStr(I) + '.wav';
        RecordingId := 'first-party-recording-' + IntToStr(I); Family := I;
        Sha256 := HashAudioBytes(LBytes); SampleRate := 8000; Channels := 1; FrameCount := 16000;
        Acquisition := 'Generated locally by pythian.example.corpus.intake; no download or private media';
        LicenseNotice := ExampleLicense;
        PreparationPolicy := 'Unchanged generated PCM16, mono 8000 Hz, amplitude 0.2';
        PreparationSha256 := HashText(PreparationPolicy); PreparationAccepted := True;
        PeakCeiling := 0.3; Parent := -1; ParentEndFrame := FrameCount; ParentGain := 1;
      end;
      WriteFileBytes(LDirectory + D.Sources[I].Path, LBytes);
    end;
    D.Ranges[0].Source := 0; D.Ranges[0].EndFrame := 6000;
    D.Ranges[0].SongId := 'example-song-left';
    D.Ranges[0].BoundaryEvidence := 'Authored region [0,6000) from the example generator';
    D.Ranges[1].Source := 0; D.Ranges[1].FirstFrame := 6000; D.Ranges[1].EndFrame := 10000;
    { This is an explicitly unknown span; silence is not invented song truth. }
    D.Ranges[2].Source := 0; D.Ranges[2].FirstFrame := 10000; D.Ranges[2].EndFrame := 16000;
    D.Ranges[2].SongId := 'example-song-right';
    D.Ranges[2].BoundaryEvidence := 'Authored region [10000,16000) from the example generator';
    D.Ranges[3].Source := 1; D.Ranges[3].EndFrame := 16000;
    D.Ranges[3].SongId := 'example-development-song';
    D.Ranges[3].BoundaryEvidence := 'The generator authored the entire independent development source';
    for I := 0 to High(D.Ranges) do D.Ranges[I].Multiplicity := 1;
    for K := 0 to 2 do
    begin
      case K of
        0: LLabel := 'caller-label-A';
        1: LLabel := 'unrelated-label-B';
        else LLabel := '';
      end;
      D.StyleId := LLabel;
      P := TCorpusIntakePlan.Create(D);
      try
        WriteTextFile(LDirectory + 'example-' + IntToStr(K) + '.json', EncodeCorpusIntake(P));
      finally
        P.Free;
      end;
    end;
    WriteLn('Generated three caller profiles over two first-party WAVs, retaining one unknown span');
  except
    on E: Exception do
    begin
      WriteLn(StdErr, E.Message); Halt(1);
    end;
  end;
end.
