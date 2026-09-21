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
program pythian_separate;

{$mode delphi}
{$H+}

uses
  SysUtils,
  Math,
  fpjson,
  pythian.audio,
  pythian.wave,
  pythian.separation,
  pythian.tools.files;

procedure Run;
var
  LSource: TAudioClip;
  LSeparated: THarmonicPercussive;
  LOptions: THarmonicPercussiveOptions;
  LSourceHash: String;
  LPrefix: String;
  LHarmonicBytes: TAudioBytes;
  LPercussiveBytes: TAudioBytes;
  LReport: TJSONObject;
  LText: String;
  LFrame: Integer;
  LChannel: Integer;
  LError: Double;
  LMaximumError: Double;
  LHEnergy: Double;
  LPEnergy: Double;
  LH: Double;
  LP: Double;
begin
  if not (ParamCount in [2, 6]) then
  begin
    raise EAudio.Create('Usage: pythian.separate INPUT.wav OUTPUT_PREFIX [WINDOW_FRAMES HOP_FRAMES HARMONIC_MEDIAN_FRAMES PERCUSSIVE_MEDIAN_BINS]');
  end;
  LPrefix := ParamStr(2);
  if SameFileName(ExpandFileName(ParamStr(1)), ExpandFileName(LPrefix + '-harmonic.wav')) or
    SameFileName(ExpandFileName(ParamStr(1)), ExpandFileName(LPrefix + '-percussive.wav')) or
    SameFileName(ExpandFileName(ParamStr(1)), ExpandFileName(LPrefix + '.json')) then
  begin
    raise EAudio.Create('Separation outputs must not replace the source WAV');
  end;
  LOptions := DefaultHarmonicPercussiveOptions;
  if ParamCount = 6 then
  begin
    LOptions.WindowFrames := StrToInt(ParamStr(3));
    LOptions.HopFrames := StrToInt(ParamStr(4));
    LOptions.HarmonicMedianFrames := StrToInt(ParamStr(5));
    LOptions.PercussiveMedianBins := StrToInt(ParamStr(6));
  end;
  LSource := nil;
  LSeparated := nil;
  LReport := nil;
  try
    LSource := LoadWaveSource(ParamStr(1), LSourceHash);
    LSeparated := THarmonicPercussive.Create(LSource, LOptions);
    LMaximumError := 0;
    LHEnergy := 0;
    LPEnergy := 0;
    for LFrame := 0 to LSource.FrameCount - 1 do
    begin
      for LChannel := 0 to LSource.Channels - 1 do
      begin
        LH := LSeparated.Harmonic.SampleAt(LFrame, LChannel);
        LP := LSeparated.Percussive.SampleAt(LFrame, LChannel);
        if (Abs(LH) > 1) or (Abs(LP) > 1) then
        begin
          raise EAudio.Create('Separated components exceed PCM16 headroom; reduce source gain before exporting');
        end;
        LError := Abs(LH + LP - LSource.SampleAt(LFrame, LChannel));
        LMaximumError := Max(LMaximumError, LError);
        LHEnergy := LHEnergy + Sqr(LH);
        LPEnergy := LPEnergy + Sqr(LP);
      end;
    end;
    LHarmonicBytes := EncodeWavePcm16(LSeparated.Harmonic);
    LPercussiveBytes := EncodeWavePcm16(LSeparated.Percussive);
    LReport := TJSONObject.Create;
    LReport.Add('source', ExtractFileName(ParamStr(1)));
    LReport.Add('source_sha256', LSourceHash);
    LReport.Add('harmonic_sha256', HashAudioBytes(LHarmonicBytes));
    LReport.Add('percussive_sha256', HashAudioBytes(LPercussiveBytes));
    LReport.Add('method', 'median-filter harmonic/percussive separation; squared soft masks');
    LReport.Add('reference', 'FitzGerald, DAFx 2010, Harmonic/Percussive Separation using Median Filtering');
    LReport.Add('window', 'centered periodic Hann; source edges zero padded');
    LReport.Add('median_edges', 'nearest available frame/bin');
    LReport.Add('stereo_policy', 'shared RMS-magnitude mask; retain per-channel phase');
    LReport.Add('reconstruction', 'harmonic inverse STFT with squared-window normalization; percussive is source residual');
    LReport.Add('source_roles_inferred', False);
    LReport.Add('harmonic_is_declared_monophonic', False);
    LReport.Add('sample_rate', LSource.SampleRate);
    LReport.Add('channels', LSource.Channels);
    LReport.Add('frames', LSource.FrameCount);
    LReport.Add('window_frames', LOptions.WindowFrames);
    LReport.Add('hop_frames', LOptions.HopFrames);
    LReport.Add('harmonic_median_frames', LOptions.HarmonicMedianFrames);
    LReport.Add('percussive_median_bins', LOptions.PercussiveMedianBins);
    LReport.Add('analysis_frames', LSeparated.Plan.AnalysisFrames);
    LReport.Add('spectral_cells', LSeparated.Plan.SpectralCells);
    LReport.Add('estimated_work', LSeparated.Plan.Work);
    LReport.Add('native_max_reconstruction_error', LMaximumError);
    LReport.Add('harmonic_rms', Sqrt(LHEnergy / (LSource.FrameCount * LSource.Channels)));
    LReport.Add('percussive_rms', Sqrt(LPEnergy / (LSource.FrameCount * LSource.Channels)));
    LReport.Add('output_encoding', 'PCM16, independently quantized components');
    LText := LReport.FormatJSON;
    WriteFileBytes(LPrefix + '-harmonic.wav', LHarmonicBytes);
    WriteFileBytes(LPrefix + '-percussive.wav', LPercussiveBytes);
    WriteTextFile(LPrefix + '.json', LText);
    WriteLn('Separated ', LSource.FrameCount, ' frames / ', LSource.Channels,
      ' channels; native maximum reconstruction error ', LMaximumError);
  finally
    LReport.Free;
    LSeparated.Free;
    LSource.Free;
  end;
end;

begin
  try
    Run;
  except
    on LException: Exception do
    begin
      WriteLn(StdErr, LException.ClassName, ': ', LException.Message);
      Halt(1);
    end;
  end;
end.

