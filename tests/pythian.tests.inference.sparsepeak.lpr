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
program pythian_tests_inference_sparsepeak;

{$mode delphi}
{$H+}

uses
  SysUtils,
  Math,
  pythian.audio,
  pythian.inference.observation,
  pythian.inference.sparsepeak;

const
  CFrames = SparsePeakWindowFrames;
  CProbeWindows = 3000;
  CProbeRate = 100;

type
  TWindowSet = array of TAudioSamples;

procedure Check(const ACondition: Boolean; const AMessage: String);
begin
  if not ACondition then
    raise EAudio.Create(AMessage);
end;

function MakeWindow(const AFrequency1, AAmplitude1, AFrequency2,
  AAmplitude2, AOffset: Double): TAudioSamples;
var
  LIndex: Integer;
  LPhase: Double;
begin
  Result := nil;
  SetLength(Result, CFrames);
  for LIndex := 0 to CFrames - 1 do
  begin
    LPhase := 2 * Pi * LIndex / InferenceRate;
    Result[LIndex] := AOffset + AAmplitude1 * Sin(AFrequency1 * LPhase);
    if AAmplitude2 <> 0 then
      Result[LIndex] := Result[LIndex] + AAmplitude2 * Sin(AFrequency2 * LPhase);
  end;
end;

function BinForFrequency(const AFrequency: Double): Integer;
begin
  Result := Round((69 + 12 * Log2(AFrequency / 440) - 24) * 5);
end;

procedure CheckSupport(const ASalience: TPitchSalience);
var
  LValue: Single;
begin
  for LValue in ASalience do
  begin
    Check(not IsNan(LValue) and not IsInfinite(LValue), 'Support finite');
    Check((LValue >= 0) and (LValue <= 1), 'Support in 0..1');
  end;
end;

procedure ExpectRejected(const ABackend: TSparsePeakInferenceBackend;
  const AWindow: TAudioSamples; const AMessage: String);
var
  LRejected: Boolean;
begin
  LRejected := False;
  try
    ABackend.Activate(AWindow);
  except
    on EAudio do
      LRejected := True;
  end;
  Check(LRejected, AMessage);
end;

procedure Run;
var
  LBackend: TSparsePeakInferenceBackend;
  LWindows: TWindowSet;
  LSalience, LReplay: TPitchSalience;
  LSilence, LInvalid: TAudioSamples;
  LIndex: Integer;
  LValue, LChecksum: Double;
  LStarted, LElapsed: QWord;
begin
  LBackend := TSparsePeakInferenceBackend.Create;
  try
    Check(LBackend.EstimatorIdentity = SparsePeakInferenceEstimator,
      'Estimator identity is fixed');
    Check(SparsePeakInferencePolicy <> '', 'Distinct support policy is named');
    Check(Abs(SparsePeakBinFrequencyHz(0) - 32.7031956626) < 1E-8,
      'First bin is MIDI 24');
    Check(Abs(SparsePeakBinFrequencyHz(359) - 2068.964315059) < 1E-8,
      'Last bin is MIDI 95.8');

    SetLength(LWindows, 8);
    LWindows[0] := MakeWindow(440, 0.4, 0, 0, 0);
    LWindows[1] := MakeWindow(55, 0.3, 0, 0, 0);
    LWindows[2] := MakeWindow(110, 0.3, 0, 0, 0);
    LWindows[3] := MakeWindow(55, 0.3, 110, 0.2, 0);
    LWindows[4] := MakeWindow(110, 0.3, 165, 0.3, 0);
    LWindows[5] := MakeWindow(220, 0.4, 0, 0, 0);
    LWindows[6] := MakeWindow(0, 0, 0, 0, 0.25);
    LWindows[7] := MakeWindow(880, 0.4, 0, 0, 0);

    LSalience := LBackend.Activate(LWindows[0]);
    CheckSupport(LSalience);
    LValue := LSalience[BinForFrequency(440)];
    WriteLn('CONTROL tone440=', FormatFloat('0.000000000', LValue));
    Check(LValue > 0.5, '440-Hz pure tone support exceeds 0.5');
    LReplay := LBackend.Activate(LWindows[0]);
    for LIndex := Low(LSalience) to High(LSalience) do
      Check(LSalience[LIndex] = LReplay[LIndex], 'Replay is exact');

    LSalience := LBackend.Activate(LWindows[1]);
    Check(LSalience[BinForFrequency(55)] > 0.3,
      '55-Hz pure tone support exceeds 0.3');
    LSalience := LBackend.Activate(LWindows[2]);
    Check(LSalience[BinForFrequency(110)] > 0.3,
      '110-Hz pure tone support exceeds 0.3');
    LSalience := LBackend.Activate(LWindows[3]);
    CheckSupport(LSalience);
    WriteLn('CONTROL mix55=', FormatFloat('0.000000000',
      LSalience[BinForFrequency(55)]), ' mix110=',
      FormatFloat('0.000000000', LSalience[BinForFrequency(110)]));
    Check((LSalience[BinForFrequency(55)] > 0.3) and
      (LSalience[BinForFrequency(110)] > 0.3),
      '55/110-Hz mixture has both supports above 0.3');

    LSalience := LBackend.Activate(LWindows[4]);
    Check(LSalience[BinForFrequency(55)] > 0.3,
      'Missing 55-Hz fundamental is supported by 110/165 harmonic pair');
    LSalience := LBackend.Activate(LWindows[5]);
    Check((LSalience[BinForFrequency(110)] > 0.3) and
      (LSalience[BinForFrequency(220)] > 0.3),
      '220-Hz tone retains lower-octave ambiguity');
    LSalience := LBackend.Activate(LWindows[7]);
    Check(LSalience[BinForFrequency(880)] > 0.5, '880-Hz tone support');

    SetLength(LSilence, CFrames);
    LSalience := LBackend.Activate(LSilence);
    for LValue in LSalience do
      Check(LValue = 0, 'Silence returns zero unknown vector');
    LSalience := LBackend.Activate(LWindows[6]);
    for LValue in LSalience do
      Check(LValue = 0, 'DC returns zero unknown vector');
    SetLength(LInvalid, CFrames - 1);
    ExpectRejected(LBackend, LInvalid, 'Short input rejected');
    LInvalid := Copy(LWindows[0]);
    LInvalid[9] := NaN;
    ExpectRejected(LBackend, LInvalid, 'Nonfinite input rejected');

    WriteLn('PASS synthetic controls estimator=', LBackend.EstimatorIdentity,
      ' policy=', SparsePeakInferencePolicy, ' window=2048 fft=8192 rate=16000');
{$ifndef SKIP_COST_SCREEN}
    LChecksum := 0;
    LStarted := GetTickCount64;
    for LIndex := 0 to CProbeWindows - 1 do
    begin
      LSalience := LBackend.Activate(LWindows[LIndex mod Length(LWindows)]);
      LChecksum := LChecksum + LSalience[(LIndex * 17) mod Length(LSalience)];
    end;
    LElapsed := GetTickCount64 - LStarted;
    WriteLn('COST windows=', CProbeWindows, ' rate=', CProbeRate,
      ' equivalent_seconds=30 elapsed_ms=', LElapsed,
      ' throughput_windows_per_second=',
      FormatFloat('0.00', CProbeWindows * 1000.0 / LElapsed),
      ' checksum=', FormatFloat('0.0000000000', LChecksum));
    Check(LElapsed <= 30000, '3000-window probe exceeds realtime budget');
{$endif}
  finally
    LBackend.Free;
  end;
end;

begin
  try
    Run;
  except
    on E: Exception do
    begin
      WriteLn(StdErr, 'FAIL ', E.ClassName, ': ', E.Message);
      ExitCode := 1;
    end;
  end;
end.
