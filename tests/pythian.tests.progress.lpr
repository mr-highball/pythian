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
program pythian_tests_progress;
{$mode delphi}
{$H+}
uses Classes, SysUtils, Math, pythian.audio, pythian.progress, pythian.hash,
  pythian.analysis, pythian.analysis.wave, pythian.wave.read, pythian.wave.stream,
  pythian.resample, pythian.pitch, pythian.pitch.track, pythian.learning,
  pythian.beat, pythian.beat.wave;

type
  EProbeAbort = class(Exception);
  TProbe = class
    Last: TWorkProgress;
    Calls, Intermediate, Passes: Integer;
    Abort: Boolean;
    procedure Reset(const AAbort: Boolean = False);
    procedure Report(const AProgress: TWorkProgress);
  end;
var Checks: Integer;
procedure Check(const AValue: Boolean; const AMessage: String);
begin
  Inc(Checks);
  if not AValue then raise Exception.Create(AMessage);
end;
procedure TProbe.Reset(const AAbort: Boolean);
begin
  Last := Default(TWorkProgress); Calls := 0; Intermediate := 0; Passes := 0;
  Abort := AAbort;
end;
procedure TProbe.Report(const AProgress: TWorkProgress);
begin
  Check((AProgress.Done >= 0) and ((AProgress.Total = 0) or
    (AProgress.Done <= AProgress.Total)), 'Callback counts are bounded');
  if (Calls > 0) and (AProgress.Stage = Last.Stage) and (AProgress.Pass = Last.Pass) then
    Check(AProgress.Done >= Last.Done, 'Completed work never decreases inside a stage/pass');
  if (AProgress.Done > 0) and ((AProgress.Total = 0) or
    (AProgress.Done < AProgress.Total)) then Inc(Intermediate);
  Passes := Max(Passes, AProgress.Pass);
  Last := AProgress; Inc(Calls);
  if Abort and (Intermediate > 0) then raise EProbeAbort.Create('Stop at a measured checkpoint');
end;

procedure Run;
var
  P: TProbe;
  Bytes: TAudioBytes;
  Samples: TAudioSamples;
  Input, Baseline, Observed: TAudioClip;
  M: TMemoryStream;
  Wave: TWaveFrameReader;
  FA, FB: TAudioFeatures;
  A, B: TPitchTrack;
  PA, PB: TAcousticPalette;
  CentersA, CentersB: TAcousticVectors;
  BA, BB: TWaveBeatEvidence;
  Options: TAnalysisOptions;
  H: String;
  I,J: Integer;
  Failed, Equal: Boolean;
begin
  P := TProbe.Create; M := TMemoryStream.Create;
  Input := nil; Baseline := nil; Observed := nil; A := nil; B := nil;
  PA := nil; PB := nil; Wave := nil;
  try
    SetLength(Bytes, 65536);
    for I := 0 to High(Bytes) do Bytes[I] := I mod 251;
    H := Sha256Bytes(Bytes);
    P.Reset;
    Check(Sha256Bytes(Bytes, P.Report) = H, 'Byte hash callback preserves digest');
    Check((P.Intermediate > 0) and (P.Last.Done = Length(Bytes)), 'Byte hash intermediate and completion');
    M.WriteBuffer(Bytes[0], Length(Bytes)); M.Position := 0;
    P.Reset;
    Check(Sha256Stream(M, M.Size, P.Report) = H, 'Stream hash callback preserves digest');
    Check((P.Intermediate > 0) and (P.Last.Done = M.Size), 'Stream hash measured bytes');
    M.Position := 0; P.Reset(True); Failed := False;
    try H := Sha256Stream(M, M.Size, P.Report) except on EProbeAbort do Failed := True end;
    Check(Failed and (M.Position < M.Size), 'Hash abort stops before remaining source reads');

    SetLength(Samples, 64000);
    for I := 0 to High(Samples) do
      Samples[I] := 0.2 * Sin(2*Pi*(220 + (I div 8000 mod 4)*55)*I/16000);
    Input := TAudioClip.Create(16000, 1, Samples);
    Baseline := ResampleClip(Input, 8000); P.Reset;
    Observed := ResampleClip(Input, 8000, P.Report);
    Equal := Observed.FrameCount = Baseline.FrameCount;
    for I := 0 to Baseline.FrameCount - 1 do
      Equal := Equal and (Observed.SampleAt(I,0) = Baseline.SampleAt(I,0));
    Check(Equal and (P.Intermediate > 0), 'Resampler callback preserves every output sample');
    FreeAndNil(Observed); P.Reset(True); Failed := False;
    try Observed := ResampleClip(Input, 8000, P.Report) except on EProbeAbort do Failed := True end;
    Check(Failed and (Observed = nil), 'Resampling abort publishes no partial clip');
    Options := DefaultAnalysisOptions; Options.WindowFrames := 512; Options.HopFrames := 256;
    FA := AnalyzeAudio(Input, Options); P.Reset;
    FB := AnalyzeAudio(Input, Options, P.Report);
    Equal := Length(FA) = Length(FB);
    for I := 0 to High(FA) do Equal := Equal and (FA[I].Rms = FB[I].Rms) and
      (FA[I].Flux = FB[I].Flux) and (FA[I].CentroidHz = FB[I].CentroidHz);
    Check(Equal and (P.Intermediate > 0), 'Analysis callback preserves shared FFT results');
    P.Reset(True); Failed := False;
    try FB := AnalyzeAudio(Input, Options, P.Report) except on EProbeAbort do Failed := True end;
    Check(Failed and (Length(FB) = Length(FA)), 'Analysis abort preserves previously assigned result');
    M.Clear; WriteWavePcm16(M, Input); M.Position := 0; Wave := TWaveFrameReader.Create(M);
    P.Reset; FB := AnalyzeWave(Wave, Options, P.Report);
    Check((P.Intermediate > 0) and (P.Last.Done = Length(FB)), 'WAV wrapper forwards primary analysis callbacks');
    FreeAndNil(Wave);

    A := TPitchTrack.Create(Baseline,0,DefaultPitchTrackOptions(8000)); P.Reset;
    B := TPitchTrack.Create(Baseline,0,DefaultPitchTrackOptions(8000),0,P.Report);
    Equal := A.WindowCount = B.WindowCount;
    for I := 0 to A.WindowCount - 1 do Equal := Equal and
      (A.EstimateAt(I).FrequencyHz = B.EstimateAt(I).FrequencyHz) and (A.NoteAt(I) = B.NoteAt(I));
    Check(Equal and (P.Intermediate > 0), 'Pitch callback preserves estimates and admissions');
    FreeAndNil(B); P.Reset(True); Failed := False;
    try B := TPitchTrack.Create(Baseline,0,DefaultPitchTrackOptions(8000),0,P.Report)
    except on EProbeAbort do Failed := True end;
    Check(Failed and (B = nil), 'Pitch callback abort publishes no partial track');

    PA := TAcousticPalette.Create(FA,4); P.Reset;
    PB := TAcousticPalette.Create(FA,4,P.Report);
    CentersA := PA.CopyCenters; CentersB := PB.CopyCenters;
    Equal := Length(CentersA) = Length(CentersB);
    for I := 0 to High(CentersA) do for J := 0 to High(TAcousticVector) do
      Equal := Equal and (CentersA[I][J] = CentersB[I][J]);
    Check(Equal and (P.Passes > 8) and (P.Intermediate > 0), 'Bulk palette callbacks preserve all learned centers');
    FreeAndNil(PB); P.Reset(True); Failed := False;
    try PB := TAcousticPalette.Create(FA,4,P.Report) except on EProbeAbort do Failed := True end;
    Check(Failed and (PB = nil), 'Palette callback abort leaves no partial model');

    BA := MeasureWaveBeats(Input, DefaultBeatGridOptions); P.Reset;
    BB := MeasureWaveBeats(Input, DefaultBeatGridOptions, P.Report);
    Equal := (Length(BA.Observations) = Length(BB.Observations)) and
      (Length(BA.Grid.Candidates) = Length(BB.Grid.Candidates));
    Check(Equal and (P.Calls > 2), 'Beat pipeline reuses primary observable analysis');
    P.Reset(True); Failed := False;
    try BB := MeasureWaveBeats(Input,DefaultBeatGridOptions,P.Report)
    except on EProbeAbort do Failed := True end;
    Check(Failed, 'Beat pipeline propagates callback abort');
    WriteLn('PASS ', Checks, ' progress bounds, output parity and abort checks');
  finally
    PB.Free; PA.Free; B.Free; A.Free; Wave.Free; Observed.Free; Baseline.Free;
    Input.Free; M.Free; P.Free;
  end;
end;
begin
  try Run except on E: Exception do begin WriteLn(E.ClassName, ': ', E.Message); Halt(1) end end;
end.
