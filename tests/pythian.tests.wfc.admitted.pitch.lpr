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
program pythian_tests_wfc_admitted_pitch;

{$mode delphi}
{$H+}

uses
  SysUtils,
  pythian.audio,
  pythian.pitch.track,
  pythian.wfc.admitted.pitch,
  pythian.wfc.generation,
  pythian.wfc.pitch,
  wfc,
  wfc_model,
  wfc_sequence,
  wfc_sequence_text;

procedure Check(const ACondition: Boolean; const AMessage: String);
begin
  if not ACondition then
  begin
    raise EAudio.Create(AMessage);
  end;
end;

function FakeSha(const AHex: Char): String;
begin
  Result := StringOfChar(AHex, 64);
end;

function MakeSource(const AGroupId, ARecordingId, ASha, AAnnotationId,
  AAnnotationSha: String; const ASpans: TAdmittedNoteSpans): TAdmittedNoteSource;
begin
  Result.GroupId := AGroupId;
  Result.RecordingId := ARecordingId;
  Result.SourceSha256 := ASha;
  Result.SourceAnnotationId := AAnnotationId;
  Result.SourceAnnotationSha256 := AAnnotationSha;
  Result.SourceAnnotationPublisher := 'controlled-test-publisher';
  Result.SourceAnnotationMethod := 'controlled-test-fixture';
  Result.SampleRate := 1000;
  Result.SourceFrameCount := 10000;
  Result.Spans := ASpans;
end;

function SourceSpan(const AKind: TPitchSpanKind; const ANote: Integer;
  const AStart, AEnd: Int64): TAdmittedNoteSpan;
begin
  Result.Kind := AKind;
  Result.Note := ANote;
  Result.StartFrame := AStart;
  Result.EndFrame := AEnd;
end;

function DurationCell(const AKind: TPitchSpanKind; const ANote, ADuration: Integer): TPitchDurationCell;
begin
  Result.Kind := AKind;
  Result.Note := ANote;
  Result.Duration := ADuration;
end;

function SameTokens(const ALeft, ARight: TWfcModelTokens): Boolean;
var
  LIndex: Integer;
begin
  Result := Length(ALeft) = Length(ARight);
  if not Result then
  begin
    Exit;
  end;
  for LIndex := 0 to High(ALeft) do
  begin
    if ALeft[LIndex] <> ARight[LIndex] then
    begin
      Exit(False);
    end;
  end;
end;

procedure CheckUnknownAbsent(const AModel: TWfcSequenceModel);
var
  LTokens: TWfcModelTokens;
  LIndex: Integer;
begin
  LTokens := AModel.CopyPublicTokens;
  for LIndex := 0 to High(LTokens) do
  begin
    Check(DecodePitchDurationToken(LTokens[LIndex]).Kind <> pskUnknown,
      'Unknown appears in saved model vocabulary');
  end;
end;

procedure CheckSourceFreeControls;
var
  LSources: TAdmittedNoteSources;
  LModel: TAdmittedPitchDurationModel;
  LReloaded: TWfcSequenceModel;
  LTokensA: TWfcModelTokens;
  LTokensB: TWfcModelTokens;
  LOptions: TAcousticGenerationOptions;
  LReport: TGraphSolveReport;
  LSampleLengths: TWfcSequenceSampleLengths;
  LIndex: Integer;
  LRejected: Boolean;
  LOverflow: TAdmittedNoteSpans;
begin
  SetLength(LSources, 2);
  LSources[0] := MakeSource('control-group-a', 'control-a', FakeSha('1'),
    'annotation-a', FakeSha('2'), [
      SourceSpan(pskPitch, 60, 0, 1000),
      SourceSpan(pskSilence, -1, 1000, 1200),
      SourceSpan(pskPitch, 62, 1200, 2000),
      SourceSpan(pskUnknown, -1, 2000, 2100),
      SourceSpan(pskPitch, 67, 2100, 3000)]);
  LSources[1] := MakeSource('control-group-b', 'control-b', FakeSha('3'),
    'annotation-b', FakeSha('4'), [
      SourceSpan(pskPitch, 72, 0, 100),
      SourceSpan(pskPitch, 74, 200, 300)]);
  LModel := LearnAdmittedPitchDurationModel(LSources, 2);
  try
    Check((LModel.GroupCount = 2) and (LModel.TrainingRunCount = 4) and
      (LModel.TrainingSpanCount = 6),
      'Unknown, uncovered-gap and source boundaries did not split expected runs');
    Check(Pos('excluded_gap' + #9 + 'control-group-b', LModel.EvidenceText) > 0,
      'Implicit uncovered source gap is absent from sidecar');
    Check(Pos('training_run' + #9 + '0' + #9 + 'control-group-a' + #9 + 'control-a',
      LModel.EvidenceText) > 0, 'Run ownership is absent from source ledger');
    LReloaded := LModel.Load;
    try
      Check(EncodeWfcSequenceText(LReloaded) = LModel.ModelText,
        'Model text changed on save/reload');
      CheckUnknownAbsent(LReloaded);
      LSampleLengths := LReloaded.CopySampleLengths;
      Check((Length(LSampleLengths) = 4) and (LSampleLengths[0] = 3) and
        (LSampleLengths[1] = 1) and (LSampleLengths[2] = 1) and
        (LSampleLengths[3] = 1),
        'Training samples crossed unknown, uncovered-gap or recording boundaries');
      Check(LReloaded.FindPublicToken(PitchDurationToken(
        DurationCell(pskUnknown, -1, 1000))) < 0,
        'Explicit unknown leaked into model vocabulary');
      Check(LReloaded.FindPublicToken(PitchDurationToken(
        DurationCell(pskSilence, -1, 200))) >= 0,
        'Explicit silence was not retained in the learned vocabulary');
    finally
      LReloaded.Free;
    end;
    LOptions := DefaultAcousticGenerationOptions;
    LOptions.FrameCount := 3;
    LOptions.Extent := wseWhole;
    LOptions.Seed := 731;
    LTokensA := nil;
    LTokensB := nil;
    Check(LModel.TryGenerate(LOptions, nil, LTokensA, LReport),
      'Saved two-group model did not solve a bounded three-span sequence');
    Check(LModel.TryGenerate(LOptions, nil, LTokensB, LReport),
      'Deterministic replay did not solve');
    Check(SameTokens(LTokensA, LTokensB), 'Same-seed source-free solve did not replay exactly');
    Check(Length(LTokensA) = 3, 'Generated sequence extent was not exact');
    for LIndex := 0 to High(LTokensA) do
    begin
      Check(DecodePitchDurationToken(LTokensA[LIndex]).Kind <> pskUnknown,
        'Unknown appeared in generated output');
    end;
    LTokensA := [PitchDurationToken(DurationCell(pskPitch, 60, 50))];
    LOptions.FrameCount := MaximumGeneratedAcousticFrames + 1;
    LRejected := False;
    try
      LModel.TryGenerate(LOptions, nil, LTokensA, LReport);
    except
      on E: EAudio do
      begin
        LRejected := True;
      end;
    end;
    Check(LRejected and (Length(LTokensA) = 1) and
      (LTokensA[0] = PitchDurationToken(DurationCell(pskPitch, 60, 50))),
      'Invalid solve request changed prior caller output');
  finally
    LModel.Free;
  end;

  SetLength(LSources, 2);
  SetLength(LOverflow, 17);
  for LIndex := 0 to High(LOverflow) do
  begin
    LOverflow[LIndex] := SourceSpan(pskPitch, 48 + (LIndex mod 12), LIndex * 2, LIndex * 2 + 1);
  end;
  LSources[0] := MakeSource('control-group-a', 'overflow-a', FakeSha('5'),
    'overflow-ann-a', FakeSha('6'), LOverflow);
  SetLength(LOverflow, 16);
  for LIndex := 0 to High(LOverflow) do
  begin
    LOverflow[LIndex] := SourceSpan(pskPitch, 60 + (LIndex mod 12), LIndex * 2, LIndex * 2 + 1);
  end;
  LSources[1] := MakeSource('control-group-b', 'overflow-b', FakeSha('7'),
    'overflow-ann-b', FakeSha('8'), LOverflow);
  LRejected := False;
  try
    LModel := LearnAdmittedPitchDurationModel(LSources, 2);
    LModel.Free;
  except
    on E: EAudio do
    begin
      LRejected := Pos('32 independent training runs', E.Message) > 0;
    end;
  end;
  Check(LRejected, '33 training runs were not rejected explicitly');

  LSources[0].Spans := [SourceSpan(pskPitch, 60, 100, 300), SourceSpan(pskPitch, 62, 200, 400)];
  LRejected := False;
  try
    LModel := LearnAdmittedPitchDurationModel(LSources, 2);
    LModel.Free;
  except
    on E: EAudio do
    begin
      LRejected := Pos('ordered', E.Message) > 0;
    end;
  end;
  Check(LRejected, 'Overlapping spans were not rejected');

  LSources[0].Spans := [SourceSpan(pskPitch, 60, 0, 1)];
  LSources[0].SampleRate := 16000;
  LSources[0].SourceFrameCount := 10000;
  LRejected := False;
  try
    LModel := LearnAdmittedPitchDurationModel(LSources, 2);
    LModel.Free;
  except
    on E: EAudio do
    begin
      LRejected := Pos('collapses', E.Message) > 0;
    end;
  end;
  Check(LRejected, 'Submillisecond pitch collapse was not rejected');

  LSources[0].Spans := [SourceSpan(pskPitch, 60, 0, 100)];
  LSources[0].SampleRate := 1000;
  LSources[0].SourceSha256 := 'not-a-sha256';
  LRejected := False;
  try
    LModel := LearnAdmittedPitchDurationModel(LSources, 2);
    LModel.Free;
  except
    on E: EAudio do
    begin
      LRejected := Pos('identity is invalid', E.Message) > 0;
    end;
  end;
  Check(LRejected, 'Malformed source digest was not rejected');
end;

procedure CheckEqualDurationAcrossSampleRates;
var
  LSources: TAdmittedNoteSources;
  LModel: TAdmittedPitchDurationModel;
  LReloaded: TWfcSequenceModel;
  LToken16k: String;
  LToken44100: String;
  LToken100Ms: String;
  LToken99Ms: String;
  LToken101Ms: String;
  LDuration16k: Integer;
  LDuration44100: Integer;
begin
  SetLength(LSources, 2);
  LSources[0] := MakeSource('rate-group-16k', 'rate-source-16k', FakeSha('a'),
    'rate-annotation-16k', FakeSha('b'), [SourceSpan(pskPitch, 60, 0, 1600)]);
  LSources[0].SampleRate := 16000;
  LSources[0].SourceFrameCount := 16000;
  LSources[1] := MakeSource('rate-group-44100', 'rate-source-44100', FakeSha('c'),
    'rate-annotation-44100', FakeSha('d'), [SourceSpan(pskPitch, 60, 0, 4410)]);
  LSources[1].SampleRate := 44100;
  LSources[1].SourceFrameCount := 44100;

  LDuration16k := RoundAdmittedFrameToMilliseconds(1600, 16000) -
    RoundAdmittedFrameToMilliseconds(0, 16000);
  LDuration44100 := RoundAdmittedFrameToMilliseconds(4410, 44100) -
    RoundAdmittedFrameToMilliseconds(0, 44100);
  Check((LDuration16k = 100) and (LDuration44100 = 100),
    'Equal 100 ms intervals did not project equally across 16 kHz and 44.1 kHz');
  LToken16k := PitchDurationToken(DurationCell(pskPitch, 60, LDuration16k));
  LToken44100 := PitchDurationToken(DurationCell(pskPitch, 60, LDuration44100));
  LToken100Ms := PitchDurationToken(DurationCell(pskPitch, 60, 100));
  LToken99Ms := PitchDurationToken(DurationCell(pskPitch, 60, 99));
  LToken101Ms := PitchDurationToken(DurationCell(pskPitch, 60, 101));
  Check(LToken16k = LToken44100,
    'Equal elapsed durations at 16 kHz and 44.1 kHz encoded differently');
  Check(LToken16k = LToken100Ms,
    'Equal source durations did not produce the exact 100 ms public token');
  LModel := LearnAdmittedPitchDurationModel(LSources, 1);
  try
    LReloaded := LModel.Load;
    try
      Check(LReloaded.FindPublicToken(LToken100Ms) >= 0,
        'Exact 100 ms public token is absent from the model');
      Check((LReloaded.FindPublicToken(LToken99Ms) < 0) and
        (LReloaded.FindPublicToken(LToken101Ms) < 0),
        'Adjacent 99 ms or 101 ms alternative unexpectedly entered the model');
    finally
      LReloaded.Free;
    end;
  finally
    LModel.Free;
  end;
end;

procedure CheckExplicitOuterGaps;
var
  LSources: TAdmittedNoteSources;
  LModel: TAdmittedPitchDurationModel;
begin
  SetLength(LSources, 2);
  LSources[0] := MakeSource('outer-group-a', 'outer-recording-a', FakeSha('e'),
    'outer-annotation-a', FakeSha('f'), [SourceSpan(pskPitch, 60, 1600, 3200)]);
  LSources[0].SampleRate := 16000;
  LSources[0].SourceFrameCount := 16000;
  LSources[1] := MakeSource('outer-group-b', 'outer-recording-b', FakeSha('0'),
    'outer-annotation-b', FakeSha('9'), [SourceSpan(pskPitch, 62, 0, 1000)]);
  LSources[1].SampleRate := 1000;
  LSources[1].SourceFrameCount := 1000;
  LModel := LearnAdmittedPitchDurationModel(LSources, 1);
  try
    Check(Pos('excluded_gap' + #9 + 'outer-group-a' + #9 +
      'outer-recording-a' + #9 + '0' + #9 + '1600' + #10,
      LModel.EvidenceText) > 0,
      'Source-leading uncovered frames were omitted from the evidence ledger');
    Check(Pos('excluded_gap' + #9 + 'outer-group-a' + #9 +
      'outer-recording-a' + #9 + '3200' + #9 + '16000' + #10,
      LModel.EvidenceText) > 0,
      'Source-trailing uncovered frames were omitted from the evidence ledger');
  finally
    LModel.Free;
  end;
end;

procedure Run;
begin
  Check(RoundAdmittedFrameToMilliseconds(8, 16000) = 1,
    'Frame-to-ms tie/half-up projection failed');
  Check(RoundAdmittedFrameToMilliseconds(7, 16000) = 0,
    'Frame-to-ms below-half projection failed');
  CheckEqualDurationAcrossSampleRates;
  CheckExplicitOuterGaps;
  CheckSourceFreeControls;
end;

begin
  try
    Run;
    Writeln('PASS: source ownership, unknown/uncovered-gap boundaries, silence token, 32-run rejection, model reload, deterministic solve, and output preservation');
  except
    on E: Exception do
    begin
      Writeln('FAIL: ', E.ClassName, ': ', E.Message);
      ExitCode := 1;
    end;
  end;
end.
