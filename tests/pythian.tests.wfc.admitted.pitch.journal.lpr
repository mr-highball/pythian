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
program pythian_tests_wfc_admitted_pitch_journal;

{$mode delphi}
{$H+}

uses
  SysUtils,
  pythian.audio,
  pythian.pitch.track,
  pythian.wfc.admitted.pitch,
  pythian.wfc.admitted.pitch.journal,
  pythian.wfc.pitch,
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

function Sha(const AChar: Char): String;
begin
  Result := StringOfChar(AChar, 64);
end;

function IndexedSha(const AIndex: Integer): String;
begin
  Result := LowerCase(IntToHex(AIndex, 2)) + StringOfChar('0', 62);
end;

function Span(const AKind: TPitchSpanKind; const ANote: Integer;
  const AStart, AEnd: Int64): TAdmittedNoteSpan;
begin
  Result.Kind := AKind;
  Result.Note := ANote;
  Result.StartFrame := AStart;
  Result.EndFrame := AEnd;
end;

function Source(const AGroup, ARecording: String; const ASha, AAnnotation,
  AAnnotationSha: String; const ASpans: TAdmittedNoteSpans): TAdmittedNoteSource;
begin
  Result.GroupId := AGroup;
  Result.RecordingId := ARecording;
  Result.SourceSha256 := ASha;
  Result.SourceAnnotationId := AAnnotation;
  Result.SourceAnnotationSha256 := AAnnotationSha;
  Result.SourceAnnotationPublisher := 'fixture-publisher';
  Result.SourceAnnotationMethod := 'fixture-method';
  Result.SampleRate := 1000;
  Result.SourceFrameCount := 10000;
  Result.Spans := ASpans;
end;

function SameModel(const ALeft, ARight: TAdmittedPitchDurationModel): Boolean;
begin
  Result := (ALeft.ModelSha256 = ARight.ModelSha256) and
    (ALeft.EvidenceSha256 = ARight.EvidenceSha256) and
    (ALeft.ModelText = ARight.ModelText) and
    (ALeft.EvidenceText = ARight.EvidenceText);
end;

procedure ExpectAppendReject(const AJournal: TAdmittedPitchJournal;
  const ASource: TAdmittedNoteSource; const APolicy, ALabel: String);
var
  LRejected: Boolean;
begin
  LRejected := False;
  try
    AJournal.AppendSource(ASource, APolicy);
  except
    on E: EAudio do
    begin
      LRejected := True;
    end;
  end;
  Check(LRejected, ALabel + ' was not rejected');
end;

procedure ExpectReplaceReject(const AJournal: TAdmittedPitchJournal;
  const AText: UTF8String; const ALabel: String);
var
  LRejected: Boolean;
begin
  LRejected := False;
  try
    AJournal.ReplaceFromText(AText);
  except
    on E: EAudio do
    begin
      LRejected := True;
    end;
  end;
  Check(LRejected, ALabel + ' was not rejected');
end;

procedure CheckRestartParity;
var
  LFirst: TAdmittedNoteSource;
  LSecond: TAdmittedNoteSource;
  LBatch: TAdmittedNoteSources;
  LBatchModel: TAdmittedPitchDurationModel;
  LJournalModel: TAdmittedPitchDurationModel;
  LJournal: TAdmittedPitchJournal;
  LReloaded: TAdmittedPitchJournal;
  LText: UTF8String;
  LStableText: UTF8String;
  LSources: TAdmittedNoteSources;
  LReloadedModel: TWfcSequenceModel;
  LModelTokens: TWfcModelTokens;
  LTokenIndex: Integer;
begin
  LFirst := Source('development-a', 'recording-a', Sha('1'), 'notes-a', Sha('2'), [
    Span(pskPitch, 60, 0, 1000),
    Span(pskSilence, -1, 1000, 1200),
    Span(pskPitch, 62, 1200, 2000),
    Span(pskUnknown, -1, 2000, 2100),
    Span(pskPitch, 67, 2100, 3000)]);
  LSecond := Source('development-b', 'recording-b', Sha('3'), 'notes-b', Sha('4'), [
    Span(pskPitch, 72, 0, 100),
    Span(pskPitch, 74, 200, 300)]);

  SetLength(LBatch, 2);
  LBatch[0] := LFirst;
  LBatch[1] := LSecond;
  LBatchModel := LearnAdmittedPitchDurationModel(LBatch, 2);
  try
    LJournal := TAdmittedPitchJournal.Create(2);
    try
      LJournal.AppendSource(LSecond, AdmittedPitchPolicyIdentity);
      LText := LJournal.EncodeText;
      LReloaded := TAdmittedPitchJournal.Create(2);
      try
        LReloaded.ReplaceFromText(LText);
        LReloaded.AppendSource(LFirst, AdmittedPitchPolicyIdentity);
        LStableText := LReloaded.EncodeText;
        LReloaded.AppendSource(LSecond, AdmittedPitchPolicyIdentity);
        Check(LReloaded.EncodeText = LStableText,
          'Exact duplicate append changed canonical journal bytes');
        Check((LReloaded.SourceCount = 2) and (LReloaded.SpanCount = 7) and
          (LReloaded.TrainingRunCount = 4),
          'Journal counts lost source, unknown, gap or run boundaries');
        LSources := LReloaded.CopySources;
        Check((LSources[0].GroupId = 'development-a') and
          (LSources[1].GroupId = 'development-b'),
          'Journal did not sort contributions canonically');
        LSources[0].Spans[0].Note := 1;
        Check(LReloaded.CopySources[0].Spans[0].Note = 60,
          'Copied source array aliases journal contribution memory');
        LJournalModel := LReloaded.Rebuild;
        try
          Check(SameModel(LBatchModel, LJournalModel),
            'Clean batch and restart/reload/append rebuild differ');
          Writeln('model_sha256=', LJournalModel.ModelSha256);
          Writeln('evidence_sha256=', LJournalModel.EvidenceSha256);
          Writeln('journal_sha256=', LReloaded.JournalSha256);
          Check(Pos('excluded_gap', LJournalModel.EvidenceText) > 0,
            'Uncovered intervals were not kept as excluded boundaries');
          LReloadedModel := LJournalModel.Load;
          try
            LModelTokens := LReloadedModel.CopyPublicTokens;
            for LTokenIndex := 0 to High(LModelTokens) do
            begin
              Check(DecodePitchDurationToken(LModelTokens[LTokenIndex]).Kind <> pskUnknown,
                'Unknown span entered rebuilt model vocabulary');
            end;
          finally
            LReloadedModel.Free;
          end;
        finally
          LJournalModel.Free;
        end;
      finally
        LReloaded.Free;
      end;
    finally
      LJournal.Free;
    end;
  finally
    LBatchModel.Free;
  end;
end;

procedure CheckFailurePreservation;
var
  LJournal: TAdmittedPitchJournal;
  LOriginal: TAdmittedNoteSource;
  LConflict: TAdmittedNoteSource;
  LBefore: UTF8String;
  LCorrupt: UTF8String;
begin
  LOriginal := Source('preserve-a', 'preserve-recording', Sha('5'), 'preserve-notes', Sha('6'), [
    Span(pskPitch, 60, 0, 1000)]);
  LConflict := LOriginal;
  SetLength(LConflict.Spans, Length(LOriginal.Spans));
  LConflict.Spans[0] := LOriginal.Spans[0];
  LConflict.Spans[0].Note := 61;
  LJournal := TAdmittedPitchJournal.Create(2);
  try
    LJournal.AppendSource(LOriginal, AdmittedPitchPolicyIdentity);
    LBefore := LJournal.EncodeText;
    ExpectAppendReject(LJournal, LConflict, AdmittedPitchPolicyIdentity,
      'Conflicting recording identity');
    Check(LJournal.EncodeText = LBefore,
      'Conflicting append changed journal state');
    ExpectAppendReject(LJournal, LConflict, 'different.policy.v1',
      'Conflicting policy identity');
    Check(LJournal.EncodeText = LBefore,
      'Policy rejection changed journal state');
    LCorrupt := Copy(LBefore, 1, Length(LBefore) - 3) + 'x'#10;
    ExpectReplaceReject(LJournal, LCorrupt, 'Corrupt journal replacement');
    Check(LJournal.EncodeText = LBefore,
      'Malformed replacement changed prior journal');
    LCorrupt := StringReplace(LBefore, 'source_count'#9 + '1',
      'source_count'#9 + '2', []);
    ExpectReplaceReject(LJournal, LCorrupt, 'Truncated journal replacement');
    Check(LJournal.EncodeText = LBefore,
      'Truncated replacement changed prior journal');
    LCorrupt := LBefore + StringOfChar('x',
      MaximumAdmittedPitchJournalBytes - Length(LBefore) + 1);
    ExpectReplaceReject(LJournal, LCorrupt, 'Oversized journal replacement');
    Check(LJournal.EncodeText = LBefore,
      'Oversized replacement changed prior journal');
  finally
    LJournal.Free;
  end;
end;

procedure CheckSourceCapacity;
var
  LJournal: TAdmittedPitchJournal;
  LSource: TAdmittedNoteSource;
  LIndex: Integer;
  LBefore: UTF8String;
begin
  LJournal := TAdmittedPitchJournal.Create(2);
  try
    for LIndex := 0 to MaximumAdmittedSources - 1 do
    begin
      LSource := Source('capacity-group-' + IntToStr(LIndex),
        'capacity-recording-' + IntToStr(LIndex), IndexedSha(LIndex),
        'capacity-annotation-' + IntToStr(LIndex), IndexedSha(LIndex + 32), [
          Span(pskPitch, 60 + LIndex mod 12, 0, 1000)]);
      LJournal.AppendSource(LSource, AdmittedPitchPolicyIdentity);
    end;
    LBefore := LJournal.EncodeText;
    LSource := Source('capacity-group-overflow', 'capacity-recording-overflow',
      Sha('f'), 'capacity-annotation-overflow', Sha('e'), [Span(pskPitch, 60, 0, 1000)]);
    ExpectAppendReject(LJournal, LSource, AdmittedPitchPolicyIdentity,
      '33rd source');
    Check(LJournal.EncodeText = LBefore,
      'Source capacity rejection changed journal bytes');
  finally
    LJournal.Free;
  end;
end;

procedure CheckStagedRebuildPreservation;
var
  LJournal: TAdmittedPitchJournal;
  LSource: TAdmittedNoteSource;
  LBefore: UTF8String;
  LModel: TAdmittedPitchDurationModel;
  LRejected: Boolean;
begin
  LJournal := TAdmittedPitchJournal.Create(2);
  try
    LSource := Source('staged-group-a', 'staged-recording-a', Sha('a'),
      'staged-annotation-a', Sha('b'), [Span(pskPitch, 60, 0, 1000)]);
    LJournal.AppendSource(LSource, AdmittedPitchPolicyIdentity);
    LBefore := LJournal.EncodeText;
    LRejected := False;
    LModel := nil;
    try
      LModel := LJournal.Rebuild;
    except
      on E: EAudio do
      begin
        LRejected := True;
      end;
    end;
    LModel.Free;
    Check(LRejected, 'One-group staged journal unexpectedly rebuilt');
    Check(LJournal.EncodeText = LBefore,
      'Failed staged rebuild changed journal contributions');

    LSource := Source('staged-group-b', 'staged-recording-b', Sha('c'),
      'staged-annotation-b', Sha('d'), [Span(pskPitch, 64, 0, 1000)]);
    LJournal.AppendSource(LSource, AdmittedPitchPolicyIdentity);
    LModel := LJournal.Rebuild;
    try
      Check(LModel.GroupCount = 2,
        'Adding the second source group did not enable deterministic rebuild');
    finally
      LModel.Free;
    end;
  finally
    LJournal.Free;
  end;
end;

procedure CheckUnsortedDecodeRejection;
var
  LSourceJournal: TAdmittedPitchJournal;
  LTargetJournal: TAdmittedPitchJournal;
  LSource: TAdmittedNoteSource;
  LCanonical: UTF8String;
  LUnsorted: UTF8String;
  LBefore: UTF8String;
  LStartA: Integer;
  LStartB: Integer;
  LHeader: UTF8String;
  LBlockA: UTF8String;
  LBlockB: UTF8String;
begin
  LSourceJournal := TAdmittedPitchJournal.Create(2);
  LTargetJournal := TAdmittedPitchJournal.Create(2);
  try
    LSource := Source('order-a', 'order-recording-a', Sha('1'), 'order-notes-a', Sha('2'), [
      Span(pskPitch, 60, 0, 1000)]);
    LSourceJournal.AppendSource(LSource, AdmittedPitchPolicyIdentity);
    LSource := Source('order-b', 'order-recording-b', Sha('3'), 'order-notes-b', Sha('4'), [
      Span(pskPitch, 62, 0, 1000)]);
    LSourceJournal.AppendSource(LSource, AdmittedPitchPolicyIdentity);
    LCanonical := LSourceJournal.EncodeText;
    LStartA := Pos('source'#9 + 'order-a'#9, String(LCanonical));
    LStartB := Pos('source'#9 + 'order-b'#9, String(LCanonical));
    Check((LStartA > 0) and (LStartB > LStartA),
      'Could not identify canonical source row blocks');
    LHeader := Copy(LCanonical, 1, LStartA - 1);
    LBlockA := Copy(LCanonical, LStartA, LStartB - LStartA);
    LBlockB := Copy(LCanonical, LStartB, Length(LCanonical) - LStartB + 1);
    LUnsorted := LHeader + LBlockB + LBlockA;

    LSource := Source('preserve-order', 'preserve-order-recording', Sha('5'),
      'preserve-order-notes', Sha('6'), [Span(pskPitch, 67, 0, 1000)]);
    LTargetJournal.AppendSource(LSource, AdmittedPitchPolicyIdentity);
    LBefore := LTargetJournal.EncodeText;
    ExpectReplaceReject(LTargetJournal, LUnsorted,
      'Unsorted source contribution rows');
    Check(LTargetJournal.EncodeText = LBefore,
      'Unsorted journal replacement changed prior contribution state');
  finally
    LTargetJournal.Free;
    LSourceJournal.Free;
  end;
end;

procedure CheckRunCapacity;
var
  LJournal: TAdmittedPitchJournal;
  LSource: TAdmittedNoteSource;
  LSpans: TAdmittedNoteSpans;
  LIndex: Integer;
  LBefore: UTF8String;
begin
  SetLength(LSpans, 63);
  for LIndex := 0 to 31 do
  begin
    LSpans[LIndex * 2] := Span(pskPitch, 60 + LIndex mod 12,
      LIndex * 20, LIndex * 20 + 10);
    if LIndex < 31 then
    begin
      LSpans[LIndex * 2 + 1] := Span(pskUnknown, -1,
        LIndex * 20 + 10, LIndex * 20 + 20);
    end;
  end;
  LSource := Source('run-cap-group-a', 'run-cap-recording-a', Sha('7'),
    'run-cap-annotation-a', Sha('8'), LSpans);
  LJournal := TAdmittedPitchJournal.Create(2);
  try
    LJournal.AppendSource(LSource, AdmittedPitchPolicyIdentity);
    Check(LJournal.TrainingRunCount = 32,
      '32 independent runs were not accepted');
    LBefore := LJournal.EncodeText;
    LSource := Source('run-cap-group-b', 'run-cap-recording-b', Sha('9'),
      'run-cap-annotation-b', Sha('0'), [Span(pskPitch, 65, 0, 10)]);
    ExpectAppendReject(LJournal, LSource, AdmittedPitchPolicyIdentity,
      '33rd training run');
    Check(LJournal.EncodeText = LBefore,
      'Training-run capacity rejection changed journal bytes');
  finally
    LJournal.Free;
  end;
end;

procedure CheckSpanCapacity;
var
  LJournal: TAdmittedPitchJournal;
  LSource: TAdmittedNoteSource;
  LSpans: TAdmittedNoteSpans;
  LIndex: Integer;
  LBefore: UTF8String;
begin
  SetLength(LSpans, MaximumAdmittedInputSpans);
  for LIndex := 0 to High(LSpans) do
  begin
    LSpans[LIndex] := Span(pskSilence, -1, LIndex, LIndex + 1);
  end;
  LSource := Source('span-cap-group-a', 'span-cap-recording-a', Sha('c'),
    'span-cap-annotation-a', Sha('d'), LSpans);
  LSource.SourceFrameCount := MaximumAdmittedInputSpans + 1;
  LJournal := TAdmittedPitchJournal.Create(2);
  try
    LJournal.AppendSource(LSource, AdmittedPitchPolicyIdentity);
    Check(LJournal.SpanCount = MaximumAdmittedInputSpans,
      '65,536 spans were not accepted at the bound');
    LBefore := LJournal.JournalSha256;
    LSource := Source('span-cap-group-b', 'span-cap-recording-b', Sha('e'),
      'span-cap-annotation-b', Sha('f'), [Span(pskSilence, -1, 0, 1)]);
    ExpectAppendReject(LJournal, LSource, AdmittedPitchPolicyIdentity,
      '65,537th span');
    Check(LJournal.JournalSha256 = LBefore,
      'Span capacity rejection changed journal hash');
  finally
    LJournal.Free;
  end;
end;

begin
  try
    CheckRestartParity;
    CheckFailurePreservation;
    CheckStagedRebuildPreservation;
    CheckUnsortedDecodeRejection;
    CheckSourceCapacity;
    CheckRunCapacity;
    CheckSpanCapacity;
    Writeln('PASS: canonical contribution restart parity, duplicate idempotence, policy/conflict/corruption preservation, unknown/gap boundaries, and 32/65536/32 capacity bounds');
  except
    on E: Exception do
    begin
      Writeln('FAIL: ', E.ClassName, ': ', E.Message);
      ExitCode := 1;
    end;
  end;
end.
