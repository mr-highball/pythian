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
program pythian_tests_wfc_admitted_pitch_balance;

{$mode delphi}
{$H+}

uses
  SysUtils,
  pythian.audio,
  pythian.pitch.track,
  pythian.wfc.admitted.pitch,
  pythian.wfc.admitted.pitch.balance,
  pythian.wfc.admitted.pitch.journal,
  pythian.wfc.generation,
  pythian.wfc.pitch,
  wfc,
  wfc_model,
  wfc_sequence,
  wfc_sequence_graph;

procedure Check(const ACondition: Boolean; const AMessage: String);
begin
  if not ACondition then
  begin
    raise EAudio.Create(AMessage);
  end;
end;

function Span(const AKind: TPitchSpanKind; const ANote: Integer;
  const AStart, AEnd: Int64): TAdmittedNoteSpan;
begin
  Result.Kind := AKind;
  Result.Note := ANote;
  Result.StartFrame := AStart;
  Result.EndFrame := AEnd;
end;

function Source(const AGroup, ARecording: String; const ASourceChar,
  AAnnotationChar: Char; const ASpans: TAdmittedNoteSpans): TAdmittedNoteSource;
begin
  Result := Default(TAdmittedNoteSource);
  Result.GroupId := AGroup;
  Result.RecordingId := ARecording;
  Result.SourceSha256 := StringOfChar(ASourceChar, 64);
  Result.SourceAnnotationId := ARecording + '-notes';
  Result.SourceAnnotationSha256 := StringOfChar(AAnnotationChar, 64);
  Result.SourceAnnotationPublisher := 'fixture-publisher';
  Result.SourceAnnotationMethod := 'fixture-method';
  Result.SampleRate := 1000;
  Result.SourceFrameCount := 10000;
  Result.Spans := ASpans;
end;

procedure CheckBalanceAndReplay;
var
  LJournal: TAdmittedPitchJournal;
  LReloaded: TAdmittedPitchJournal;
  LPlan: TAdmittedPitchBalancePlan;
  LReplayPlan: TAdmittedPitchBalancePlan;
  LBaseline: TAdmittedPitchDurationModel;
  LBalanced: TAdmittedPitchDurationModel;
  LReplay: TAdmittedPitchDurationModel;
  LOptions: TAcousticGenerationOptions;
  LReport: TGraphSolveReport;
  LTokens: TWfcModelTokens;
  LIndex: Integer;
  LRejected: Boolean;
  LBefore: String;
  LSources: TAdmittedNoteSources;
begin
  LJournal := TAdmittedPitchJournal.Create(1);
  LReloaded := TAdmittedPitchJournal.Create(1);
  LPlan := nil;
  LReplayPlan := nil;
  LBaseline := nil;
  LBalanced := nil;
  LReplay := nil;
  try
    LJournal.AppendSource(Source('group-a', 'recording-a', 'a', 'b', [
      Span(pskPitch, 60, 0, 100),
      Span(pskPitch, 62, 100, 200),
      Span(pskUnknown, -1, 200, 250),
      Span(pskPitch, 64, 250, 350),
      Span(pskPitch, 65, 350, 450)]), AdmittedPitchPolicyIdentity);
    LJournal.AppendSource(Source('group-b', 'recording-b', 'c', 'd', [
      Span(pskPitch, 67, 0, 100),
      Span(pskPitch, 69, 100, 200)]), AdmittedPitchPolicyIdentity);
    LPlan := PlanAdmittedPitchGroupBalance(LJournal);
    Check(Pos('group'#9'group-a'#9'4'#9'2'#9'1'#9'4'#9'2', LPlan.ReportText) > 0,
      'Four-token group kept weight one and unknown split');
    Check(Pos('group'#9'group-b'#9'2'#9'1'#9'2'#9'4'#9'2', LPlan.ReportText) > 0,
      'Two-token group doubled to equal WFC token mass');
    Check(Pos('total'#9'6'#9'3'#9'8'#9'4'#9'65536'#9'4096',
      LPlan.ReportText) > 0, 'Weighted work and both capacity limits are explicit');
    Check(Pos('repeated_section_identity=unknown', LPlan.ReportText) > 0,
      'Repeated musical material remains unknown');
    LBaseline := LJournal.Rebuild;
    LBalanced := LPlan.Rebuild(LJournal);
    Check(LBaseline.ModelSha256 <> LBalanced.ModelSha256,
      'Balanced WFC model must change actual contribution counts');
    Check(Pos('weight_policy=' + AdmittedPitchBalancePolicyIdentity,
      LBalanced.EvidenceText) > 0, 'Weighted model retains its policy identity');
    Check(Pos('source_weight'#9'group-b'#9'recording-b'#9'2',
      LBalanced.EvidenceText) > 0, 'Weighted model retains source contribution');
    Check(Pos('weight_policy=', LBaseline.EvidenceText) = 0,
      'Accepted all-ones evidence remains unchanged');
    LOptions := DefaultAcousticGenerationOptions;
    LOptions.FrameCount := 2;
    LOptions.Extent := wseWhole;
    LOptions.Seed := 731;
    LTokens := nil;
    Check(LBalanced.TryGenerate(LOptions, nil, LTokens, LReport),
      'Balanced saved model solves a bounded two-token sequence');
    Check(Length(LTokens) = 2, 'Balanced WFC solve has exact extent');
    for LIndex := 0 to High(LTokens) do
    begin
      Check(DecodePitchDurationToken(LTokens[LIndex]).Kind <> pskUnknown,
        'Unknown entered balanced WFC output');
    end;
    LReloaded.ReplaceFromText(LJournal.EncodeText);
    Check(LReloaded.JournalSha256 = LPlan.JournalSha256,
      'Canonical journal reload keeps balance input identity');
    LReplayPlan := PlanAdmittedPitchGroupBalance(LReloaded);
    Check(LReplayPlan.ReportText = LPlan.ReportText,
      'Balanced contribution report replays after canonical journal reload');
    LReplay := LReplayPlan.Rebuild(LReloaded);
    Check((LReplay.ModelText = LBalanced.ModelText) and
      (LReplay.EvidenceText = LBalanced.EvidenceText),
      'Balanced WFC model and evidence replay after journal reload');
    LBefore := LBalanced.ModelSha256 + LBalanced.EvidenceSha256;
    LJournal.AppendSource(Source('group-c', 'recording-c', 'e', 'f', [
      Span(pskPitch, 72, 0, 100)]), AdmittedPitchPolicyIdentity);
    LRejected := False;
    try
      LPlan.Rebuild(LJournal).Free;
    except
      on E: EAudio do
      begin
        LRejected := True;
      end;
    end;
    Check(LRejected and (LBefore = LBalanced.ModelSha256 + LBalanced.EvidenceSha256),
      'Foreign journal rejects without changing published balanced model');
    LSources := LReloaded.CopySources;
    LRejected := False;
    try
      LearnWeightedAdmittedPitchDurationModel(LSources, [1, 2], 1, '').Free;
    except
      on E: EAudio do
      begin
        LRejected := True;
      end;
    end;
    Check(LRejected, 'Non-default weights require a distinct policy identity');
    WriteLn('Balanced source-free model=', LBalanced.ModelSha256,
      ' evidence=', LBalanced.EvidenceSha256);
  finally
    LReplay.Free;
    LBalanced.Free;
    LBaseline.Free;
    LPlan.Free;
    LReplayPlan.Free;
    LReloaded.Free;
    LJournal.Free;
  end;
end;

procedure CheckImpossibleBalance;
var
  LJournal: TAdmittedPitchJournal;
  LMany: TAdmittedNoteSpans;
  LIndex: Integer;
  LRejected: Boolean;
begin
  LJournal := TAdmittedPitchJournal.Create(1);
  try
    SetLength(LMany, 100);
    for LIndex := 0 to High(LMany) do
    begin
      LMany[LIndex] := Span(pskPitch, 60, LIndex * 10, (LIndex + 1) * 10);
    end;
    LJournal.AppendSource(Source('group-a', 'recording-a', 'a', 'b', LMany),
      AdmittedPitchPolicyIdentity);
    LJournal.AppendSource(Source('group-b', 'recording-b', 'c', 'd', [
      Span(pskPitch, 67, 0, 100)]), AdmittedPitchPolicyIdentity);
    LRejected := False;
    try
      PlanAdmittedPitchGroupBalance(LJournal).Free;
    except
      on E: EAudio do
      begin
        LRejected := True;
      end;
    end;
    Check(LRejected, 'Impossible bounded ratio must reject before WFC learning');
  finally
    LJournal.Free;
  end;
end;

procedure CheckWeightedCapacity;
var
  LJournal: TAdmittedPitchJournal;
  LMany: TAdmittedNoteSpans;
  LFirst: TAdmittedNoteSource;
  LSecond: TAdmittedNoteSource;
  LIndex: Integer;
  LRejected: Boolean;
begin
  LJournal := TAdmittedPitchJournal.Create(1);
  try
    SetLength(LMany, 40000);
    for LIndex := 0 to High(LMany) do
    begin
      LMany[LIndex] := Span(pskPitch, 60, LIndex * 10, (LIndex + 1) * 10);
    end;
    LFirst := Source('group-a', 'recording-a', 'a', 'b', LMany);
    LFirst.SourceFrameCount := 500000;
    LJournal.AppendSource(LFirst, AdmittedPitchPolicyIdentity);
    SetLength(LMany, 10000);
    for LIndex := 0 to High(LMany) do
    begin
      LMany[LIndex] := Span(pskPitch, 67, LIndex * 10, (LIndex + 1) * 10);
    end;
    LSecond := Source('group-b', 'recording-b', 'c', 'd', LMany);
    LSecond.SourceFrameCount := 500000;
    LJournal.AppendSource(LSecond, AdmittedPitchPolicyIdentity);
    LRejected := False;
    try
      PlanAdmittedPitchGroupBalance(LJournal).Free;
    except
      on E: EAudio do
      begin
        LRejected := True;
      end;
    end;
    Check(LRejected, 'Equal group mass exceeding 65536 weighted tokens rejects');
    Check((LJournal.SpanCount = 50000) and (LJournal.SourceCount = 2),
      'Rejected plan retains bounded source journal');
  finally
    LJournal.Free;
  end;
end;

begin
  CheckBalanceAndReplay;
  CheckImpossibleBalance;
  CheckWeightedCapacity;
  WriteLn('Admitted pitch group balance checks passed');
end.
