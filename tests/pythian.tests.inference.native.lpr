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
program pythian_tests_inference_native;

{$mode delphi}
{$H+}

uses
  SysUtils,
  Math,
  pythian.audio,
  pythian.inference.native,
  pythian.inference.observation;

const
  CWindowFrames = 1024;
  CProbeWindows = 3000;
  CProbeWindowRate = 100;
  CProbeDeadlineMs = 30000;

type
  TWindowSet = array of TAudioSamples;

procedure Check(const ACondition: Boolean; const AMessage: String);
begin
  if not ACondition then
  begin
    raise EAudio.Create(AMessage);
  end;
end;

function MakeWindow(const AFrequency1, AAmplitude1, AFrequency2,
  AAmplitude2, AOffset: Double): TAudioSamples;
var
  LIndex: Integer;
  LPhase: Double;
begin
  Result := nil;
  SetLength(Result, CWindowFrames);
  for LIndex := 0 to CWindowFrames - 1 do
  begin
    LPhase := 2 * Pi * LIndex / InferenceRate;
    Result[LIndex] := AOffset + AAmplitude1 * Sin(AFrequency1 * LPhase);
    if AAmplitude2 <> 0 then
    begin
      Result[LIndex] := Result[LIndex] + AAmplitude2 * Sin(AFrequency2 * LPhase);
    end;
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
    Check(not IsNan(LValue) and not IsInfinite(LValue),
      'Native support must remain finite');
    Check((LValue >= 0) and (LValue <= 1),
      'Native support must remain in 0..1');
  end;
end;

procedure ExpectRejected(const ABackend: TNativeInferenceBackend;
  const AWindow: TAudioSamples; const AMessage: String);
var
  LRejected: Boolean;
begin
  LRejected := False;
  try
    ABackend.Activate(AWindow);
  except
    on EAudio do
    begin
      LRejected := True;
    end;
  end;
  Check(LRejected, AMessage);
end;

procedure Run;
var
  LBackend: TNativeInferenceBackend;
  LWindows: TWindowSet;
  LSalience: TPitchSalience;
  LReplay: TPitchSalience;
  LSilence: TAudioSamples;
  LInvalid: TAudioSamples;
  LMaximum: Single;
  LChecksum: Double;
  LStart: QWord;
  LElapsed: QWord;
  LProjectedHourMs: QWord;
  LIndex: Integer;
  LRejected: Boolean;
begin
  LBackend := TNativeInferenceBackend.Create;
  try
    Check(LBackend.EstimatorIdentity = NativeInferenceEstimator,
      'Native estimator identity is stable and explicit');
    Check(Abs(NativeInferenceBinFrequencyHz(0) - 32.7031956626) < 1e-8,
      'First bin maps to MIDI 24');
    Check(Abs(NativeInferenceBinFrequencyHz(359) - 2068.964315059) < 1e-8,
      'Last bin maps to MIDI 95.8');
    Check(NativeInferenceBinFrequencyHz(100) <
      NativeInferenceBinFrequencyHz(101), 'Bin frequency map is monotonic');

    SetLength(LWindows, 8);
    LWindows[0] := MakeWindow(440, 0.4, 0, 0, 0);
    LWindows[1] := MakeWindow(220, 0.25, 330, 0.25, 0.1);
    LWindows[2] := MakeWindow(220, 0.4, 0, 0, 0);
    LWindows[3] := MakeWindow(55, 0.4, 0, 0, 0);
    LWindows[4] := MakeWindow(880, 0.4, 0, 0, 0);
    LWindows[5] := MakeWindow(110, 0.2, 0, 0, 0.03);
    LWindows[6] := MakeWindow(440, 0.1, 0, 0, 0);
    LWindows[7] := MakeWindow(660, 0.4, 0, 0, 0);

    LSalience := LBackend.Activate(LWindows[0]);
    CheckSupport(LSalience);
    Check(LSalience[BinForFrequency(440)] > 0.95,
      '440-Hz controlled tone has strong periodic support at its mapped bin');
    LReplay := LBackend.Activate(LWindows[0]);
    for LIndex := Low(LSalience) to High(LSalience) do
    begin
      Check(LSalience[LIndex] = LReplay[LIndex],
        'Same input replays every support value exactly');
    end;

    LSalience := LBackend.Activate(LWindows[1]);
    Check(LSalience[BinForFrequency(110)] > 0.85,
      'Missing-fundamental control retains 110-Hz waveform periodicity');
    LSalience := LBackend.Activate(LWindows[2]);
    WriteLn('CONTROL octave_220=',
      FormatFloat('0.000000000', LSalience[BinForFrequency(220)]),
      ' octave_440=',
      FormatFloat('0.000000000', LSalience[BinForFrequency(440)]));
    Check((LSalience[BinForFrequency(220)] > 0.95) and
      (LSalience[BinForFrequency(440)] > 0.85),
      'Octave ambiguity remains present in the raw support vector');

    LSalience := LBackend.Activate(LWindows[6]);
    LReplay := LBackend.Activate(LWindows[0]);
    LMaximum := 0;
    for LIndex := Low(LSalience) to High(LSalience) do
    begin
      LMaximum := Max(LMaximum, Abs(LSalience[LIndex] - LReplay[LIndex]));
    end;
    Check(LMaximum < 1e-12,
      'Normalized periodic support is amplitude-invariant for a fixed tone');

    SetLength(LSilence, CWindowFrames);
    LSalience := LBackend.Activate(LSilence);
    for LIndex := Low(LSalience) to High(LSalience) do
    begin
      Check(LSalience[LIndex] = 0, 'Silence produces an all-zero unknown vector');
    end;
    LSilence := MakeWindow(0, 0, 0, 0, 0.25);
    LSalience := LBackend.Activate(LSilence);
    for LIndex := Low(LSalience) to High(LSalience) do
    begin
      Check(LSalience[LIndex] = 0, 'DC-only input produces no periodic support');
    end;

    SetLength(LInvalid, CWindowFrames - 1);
    ExpectRejected(LBackend, LInvalid, 'Short window rejects');
    SetLength(LInvalid, CWindowFrames + 1);
    ExpectRejected(LBackend, LInvalid, 'Long window rejects');
    LInvalid := Copy(LWindows[0]);
    LInvalid[17] := NaN;
    ExpectRejected(LBackend, LInvalid, 'Nonfinite input sample rejects');
    LRejected := False;
    try
      NativeInferenceBinFrequencyHz(-1);
    except
      on EAudio do
      begin
        LRejected := True;
      end;
    end;
    Check(LRejected, 'Out-of-range bin rejects');

    LChecksum := 0;
    LStart := GetTickCount64;
    for LIndex := 0 to CProbeWindows - 1 do
    begin
      LSalience := LBackend.Activate(LWindows[LIndex mod Length(LWindows)]);
      LChecksum := LChecksum + LSalience[(LIndex * 17) mod Length(LSalience)];
    end;
    LElapsed := GetTickCount64 - LStart;
    LProjectedHourMs := LElapsed *
      (Int64(3600) * CProbeWindowRate div CProbeWindows);
    WriteLn('PASS estimator=', LBackend.EstimatorIdentity);
    WriteLn('PASS bins=360 frequency_hz_first=',
      FormatFloat('0.000000', NativeInferenceBinFrequencyHz(0)),
      ' frequency_hz_last=',
      FormatFloat('0.000000', NativeInferenceBinFrequencyHz(359)));
    WriteLn('PASS controls=tone440,silence,dc,missing110,octave_ambiguity,replay,scale,invalid');
    WriteLn('COST lag_samples_per_window=',
      (CWindowFrames - NativeInferenceMinimumLag) *
        (NativeInferenceMaximumLag - NativeInferenceMinimumLag + 1) -
        ((NativeInferenceMaximumLag - NativeInferenceMinimumLag) *
          (NativeInferenceMaximumLag - NativeInferenceMinimumLag + 1) div 2),
      ' windows=', CProbeWindows, ' windows_per_second=', CProbeWindowRate,
      ' elapsed_ms=', LElapsed,
      ' throughput_windows_per_second=',
      FormatFloat('0.00', CProbeWindows * 1000.0 / LElapsed),
      ' projected_backend_hour_ms=', LProjectedHourMs,
      ' checksum=', FormatFloat('0.000000000000', LChecksum));
    Check(CProbeWindows div CProbeWindowRate = 30,
      'Throughput probe represents exactly 30 seconds at 100 windows/second');
    Check(LElapsed <= CProbeDeadlineMs,
      'Thirty-second-equivalent throughput probe exceeded real time');
    WriteLn('PASS throughput_probe_realtime deadline_ms=', CProbeDeadlineMs);
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
