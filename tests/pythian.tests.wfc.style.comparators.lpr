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
program pythian_tests_wfc_style_comparators;

{$mode delphi}
{$H+}

uses
  SysUtils,
  Classes,
  Math,
  fpjson,
  jsonparser,
  pythian.audio,
  pythian.hash,
  pythian.pitch.track,
  pythian.synth,
  pythian.wave,
  pythian.wave.read,
  pythian.wfc.admitted.pitch,
  pythian.wfc.pitch,
  pythian.wfc.style.comparators,
  pythian.tools.style.comparators,
  wfc_model,
  wfc_sequence,
  wfc_sequence_text;

var
  GChecks: Integer;
  GOutputRoot: String;

procedure Check(ACondition: Boolean; const AMessage: String);
begin
  if not ACondition then
  begin
    raise EAudio.Create(AMessage);
  end;
  Inc(GChecks);
end;

function TextBytes(const AText: UTF8String): TAudioBytes;
begin
  SetLength(Result, Length(AText));
  if Length(AText) > 0 then
  begin
    Move(AText[1], Result[0], Length(AText));
  end;
end;

procedure WriteFreshBytes(const AName: String; const ABytes: TAudioBytes);
var
  LPath: String;
  LStream: TFileStream;
begin
  LPath := IncludeTrailingPathDelimiter(GOutputRoot) + AName;
  if FileExists(LPath) or DirectoryExists(LPath) then
  begin
    raise EAudio.Create('Fixture output already exists: ' + LPath);
  end;
  LStream := TFileStream.Create(LPath, fmCreate or fmShareExclusive);
  try
    if Length(ABytes) > 0 then
    begin
      LStream.WriteBuffer(ABytes[0], Length(ABytes));
    end;
  finally
    LStream.Free;
  end;
end;

function Span(AKind: TPitchSpanKind; ANote: Integer; AStart: Int64;
  AEnd: Int64): TAdmittedNoteSpan;
begin
  Result.Kind := AKind;
  Result.Note := ANote;
  Result.StartFrame := AStart;
  Result.EndFrame := AEnd;
end;

function MakeAuthoredFixture(out ASpans: TAdmittedNoteSpans): TAudioClip;
const
  CNotes: array[0..3] of Integer = (60, 62, 65, 67);
  CDurationsMs: array[0..3] of Integer = (250, 375, 500, 625);
  CRate = 8000;
var
  LTones: TFrameTones;
  LVoice: TSynthVoice;
  LNoteIndex: Integer;
  LSpanIndex: Integer;
  LStart: Int64;
  LEnd: Int64;
begin
  { Fixed prospective three-repeat source schedule, never measured/inferred
    labels. The same integer frames drive synthesis and caller annotation. }
  LVoice := DefaultSynthVoice;
  LVoice.Gain := 0.2;
  LVoice.Envelope.ReleaseSeconds := 0;
  SetLength(LTones, 12);
  SetLength(ASpans, 25);
  LStart := 250 * (CRate div 1000);
  ASpans[0] := Span(pskSilence, -1, 0, LStart);
  LSpanIndex := 1;
  for LNoteIndex := 0 to High(LTones) do
  begin
    LEnd := LStart + CDurationsMs[LNoteIndex mod 4] * (CRate div 1000);
    LTones[LNoteIndex].StartFrame := LStart;
    LTones[LNoteIndex].GateFrames := LEnd - LStart;
    LTones[LNoteIndex].FrequencyHz := 440 * Power(2, (CNotes[LNoteIndex mod 4] - 69) / 12);
    LTones[LNoteIndex].Velocity := 0.8;
    LTones[LNoteIndex].Voice := LVoice;
    LTones[LNoteIndex].Seed := 731;
    ASpans[LSpanIndex] := Span(pskPitch, CNotes[LNoteIndex mod 4], LStart, LEnd);
    Inc(LSpanIndex);
    LStart := LEnd + 250 * (CRate div 1000);
    ASpans[LSpanIndex] := Span(pskSilence, -1, LEnd, LStart);
    Inc(LSpanIndex);
  end;
  Result := RenderFrameTones(LTones, CRate, LStart);
end;

procedure PrepareOutputRoot;
var
  LBuildRoot: String;
begin
  if ParamCount <> 1 then
  begin
    raise EAudio.Create('An explicit fresh ignored build output directory is required');
  end;
  LBuildRoot := IncludeTrailingPathDelimiter(ExpandFileName('build'));
  GOutputRoot := ExpandFileName(ParamStr(1));
  if Copy(GOutputRoot, 1, Length(LBuildRoot)) <> LBuildRoot then
  begin
    raise EAudio.Create('Conformance artifacts must be inside ignored build/');
  end;
  if FileExists(GOutputRoot) or DirectoryExists(GOutputRoot) then
  begin
    raise EAudio.Create('Conformance output directory must be fresh');
  end;
  if not ForceDirectories(GOutputRoot) then
  begin
    raise EAudio.Create('Could not create conformance artifact directory');
  end;
end;

function Cell(AKind: TPitchSpanKind; ANote, ADuration: Integer): TPitchDurationCell;
begin
  Result.Kind := AKind;
  Result.Note := ANote;
  Result.Duration := ADuration;
end;

function DeclaredInput(const ASpans: TAdmittedNoteSpans; ARate: Integer;
  AFrames: Int64): TStyleComparatorInput;
var
  LIndex: Integer;
begin
  Result := Default(TStyleComparatorInput);
  Result.SourceChannels := 2;
  Result.Source.GroupId := 'synthetic-control';
  Result.Source.RecordingId := 'golden';
  Result.Source.SourceSha256 := StringOfChar('1', 64);
  Result.Source.SourceAnnotationId := 'authored-schedule';
  Result.Source.SourceAnnotationSha256 := StringOfChar('3', 64);
  Result.Source.SourceAnnotationPublisher := 'Pythian conformance';
  Result.Source.SourceAnnotationMethod := 'Caller-authored exact frame schedule';
  Result.Source.SampleRate := ARate;
  Result.Source.SourceFrameCount := AFrames;
  Result.Source.Spans := Copy(ASpans);
  SetLength(Result.SpanIds, Length(ASpans));
  for LIndex := 0 to High(ASpans) do
  begin
    Result.SpanIds[LIndex] := 'span-' + IntToStr(LIndex);
  end;
  Result.PolicySha256 := StringOfChar('2', 64);
  Result.AuthoredVocabularySha256 := StringOfChar('4', 64);
  Result.AuthoredProvenance := 'Independent authored equal-choice control, not source-derived';
  Result.SourceProvenance := 'Synthetic conformance declarations, not acoustic inference';
  Result.Exposure := 'caller-control';
  SetLength(Result.AuthoredVocabulary, 3);
  Result.AuthoredVocabulary[0] := Cell(pskPitch, 55, 250);
  Result.AuthoredVocabulary[1] := Cell(pskPitch, 59, 500);
  Result.AuthoredVocabulary[2] := Cell(pskSilence, -1, 250);
end;

procedure ExpectRejected(const AInput: TStyleComparatorInput; const ALabel: String);
var
  LRejected: Boolean;
begin
  LRejected := False;
  try
    ValidateStyleComparatorInput(AInput);
  except
    on LError: Exception do
    begin
      LRejected := True;
    end;
  end;
  Check(LRejected, 'Expected rejection: ' + ALabel);
end;

procedure TestGolden;
const
  CDigests: array[0..2] of String = (
    '2c215bb8bd3142ab17835fa910f660ea39cf232fa109ef60c2edeea8338981c8',
    'dc7c4a89a12108ce204bc0d21e239de741aff253f2f6bf23f443c4c6301be4c2',
    'd85ebf20342a1ca82fcb3c7f7b0a5fcc6c707c2cd6efc4a25b2f8e2a7e970515');
  COrdinals: array[0..2] of Integer = (0, 2, 1);
  CDerivedStart: array[0..2] of Integer = (0, 750, 250);
  CDerivedEnd: array[0..2] of Integer = (250, 1125, 750);
var
  LSpans: TAdmittedNoteSpans;
  LInput: TStyleComparatorInput;
  LModels: TStyleComparatorModels;
  LIndex: Integer;
begin
  SetLength(LSpans, 3);
  LSpans[0] := Span(pskPitch, 60, 0, 250);
  LSpans[1] := Span(pskPitch, 64, 250, 625);
  LSpans[2] := Span(pskPitch, 67, 625, 1125);
  LInput := DeclaredInput(LSpans, 1000, 1125);
  LModels := BuildStyleComparatorModels(LInput, 731);
  Check(Length(LModels.Permutations) = 1, 'Golden single training run');
  Check(LModels.Permutations[0].Id = 'golden:run:0', 'Frozen scope identity');
  Check(not LModels.Permutations[0].IdentityRotated, 'Golden needs no rotation');
  Check(LModels.Source.SourceSha256 = LInput.Source.SourceSha256, 'Original source hash retained');
  Check(LModels.Source.SourceAnnotationSha256 = LInput.Source.SourceAnnotationSha256,
    'Original annotation hash retained');
  Check(LModels.Source.RecordingId = 'golden', 'Original recording provenance retained');
  for LIndex := 0 to 2 do
  begin
    Check(LModels.Permutations[0].SeedDigests[LIndex] = CDigests[LIndex],
      'Independent literal byte-record digest');
    Check(LModels.Permutations[0].OutputOrdinals[LIndex] = COrdinals[LIndex],
      'Frozen output-to-original permutation');
    Check(LModels.Source.Spans[LIndex].StartFrame = LSpans[LIndex].StartFrame,
      'Original frames retained');
    Check(LInput.Source.Spans[LIndex].Note = LSpans[LIndex].Note,
      'Caller input unchanged');
    Check(LModels.Source.Spans[LIndex].EndFrame = LSpans[LIndex].EndFrame,
      'Original end frame retained');
    Check(LModels.OriginalSpanIds[LIndex] = LInput.SpanIds[LIndex], 'Original span ID retained');
    Check(LModels.DerivedSpans[LIndex].OriginalSpanIndex = LIndex, 'Derived original index retained');
    Check(LModels.DerivedSpans[LIndex].Span.StartFrame = CDerivedStart[LIndex],
      'Independent exact moved start clock');
    Check(LModels.DerivedSpans[LIndex].Span.EndFrame = CDerivedEnd[LIndex],
      'Independent exact moved end clock');
  end;
  Check(LModels.MarginalDistance = 0, 'Shuffle preserves exact marginals');
  Check(LModels.RelationshipDistance > 0, 'Shuffle changes order-sensitive relation');
  LModels.Source.Spans[0].Note := 1;
  Check(LInput.Source.Spans[0].Note = 60, 'Result source storage detached');
  LModels.OriginalSpanIds[0] := 'modified';
  Check(LInput.SpanIds[0] = 'span-0', 'Result identities detached');
  LInput.SpanIds[1] := LInput.SpanIds[0];
  ExpectRejected(LInput, 'repeated span IDs');
  LInput := DeclaredInput(LSpans, 1000, 1125);
  LInput.Source.Spans[1].StartFrame := 249;
  ExpectRejected(LInput, 'overlapping source intervals');
  LInput := DeclaredInput(LSpans, 1000, 1125);
  LInput.Source.SourceSha256 := 'not-a-hash';
  ExpectRejected(LInput, 'malformed source hash');
  LInput := DeclaredInput(LSpans, 1000, 1125);
  LInput.Source.SourceFrameCount := 1124;
  ExpectRejected(LInput, 'span beyond declared geometry');
  LInput := DeclaredInput(LSpans, 1000, 1125);
  LInput.AuthoredVocabulary[0].Kind := pskUnknown;
  ExpectRejected(LInput, 'unknown authored baseline');
  LInput := DeclaredInput(LSpans, 1000, 1125);
  LInput.Source.Spans[0].EndFrame := 0;
  ExpectRejected(LInput, 'empty source interval');
  LInput := DeclaredInput(LSpans, 1000, 1125);
  LInput.SpanIds[0] := '../unsafe';
  ExpectRejected(LInput, 'noncanonical span identity');
  LInput := DeclaredInput(LSpans, 1000, 1125);
  LInput.Exposure := 'evaluation';
  ExpectRejected(LInput, 'held-out evaluation exposure');
  LInput := DeclaredInput(LSpans, 1000, 1125);
  LInput.AuthoredVocabulary[1] := LInput.AuthoredVocabulary[0];
  ExpectRejected(LInput, 'duplicate authored choice');
end;

procedure TestRelationships;
var
  LLeft: TStyleComparatorTokenRuns;
  LRight: TStyleComparatorTokenRuns;
  LIndex: Integer;
  LRejected: Boolean;
begin
  SetLength(LLeft, 1);
  SetLength(LRight, 1);
  SetLength(LLeft[0], 6);
  SetLength(LRight[0], 6);
  for LIndex := 0 to 2 do
  begin
    LLeft[0][LIndex * 2] := PitchDurationToken(Cell(pskPitch, 60 + LIndex * 4, 250));
    LLeft[0][LIndex * 2 + 1] := PitchDurationToken(Cell(pskSilence, -1, 250));
  end;
  LRight[0] := Copy(LLeft[0]);
  LRight[0][2] := LLeft[0][4];
  LRight[0][4] := LLeft[0][2];
  Check(StyleComparatorTokenMarginalDistance(LLeft, LRight) = 0, 'Same token marginals');
  Check(StyleComparatorTokenPairDistance(LLeft, LRight) = 0, 'Common rests erase pair effect');
  Check(Abs(StyleComparatorTokenRelationshipDistance(LLeft, LRight) - 0.5) < 1E-12,
    'Independent four-trigram control has TV one half');
  SetLength(LRight[0], 2);
  LRejected := False;
  try
    StyleComparatorTokenRelationshipDistance(LLeft, LRight);
  except
    on LError: Exception do
    begin
      LRejected := True;
    end;
  end;
  Check(LRejected, 'Missing n-gram evidence is rejected rather than false distance');
end;

function ModelMarginals(const AText: String): String;
var
  LModel: TWfcSequenceModel;
  LCounts: TStringList;
  LIndex: Integer;
  LToken: String;
begin
  LModel := DecodeWfcSequenceText(AText);
  LCounts := TStringList.Create;
  try
    for LIndex := 0 to LModel.StateCount - 1 do
    begin
      LToken := String(LModel.ProjectStateToken(LIndex));
      LCounts.Values[LToken] := IntToStr(StrToIntDef(LCounts.Values[LToken], 0) +
        LModel.StateObservationCountAt(LIndex));
    end;
    LCounts.Sort;
    Result := LCounts.Text;
  finally
    LCounts.Free;
    LModel.Free;
  end;
end;

function ModelRelationships(const AText: String): String;
var
  LModel: TWfcSequenceModel;
  LRows: TStringList;
  LIndex: Integer;
  LHistoryIndex: Integer;
  LHistory: TWfcSequenceHistoryItem;
  LRow: String;
  LComplete: Boolean;
begin
  LModel := DecodeWfcSequenceText(AText);
  LRows := TStringList.Create;
  try
    LRows.Sorted := True;
    LRows.Duplicates := dupIgnore;
    for LIndex := 0 to LModel.StateCount - 1 do
    begin
      LRow := '';
      LComplete := True;
      for LHistoryIndex := 0 to LModel.HistorySize - 1 do
      begin
        LHistory := LModel.HistoryItemAt(LIndex, LHistoryIndex);
        if LHistory.Kind = wshBos then
        begin
          LComplete := False;
        end
        else
        begin
          LRow := LRow + String(LModel.PublicTokenAt(LHistory.TokenIndex)) + '|';
        end;
      end;
      if LComplete then
      begin
        LRows.Add(LRow + String(LModel.ProjectStateToken(LIndex)));
      end;
    end;
    Result := LRows.Text;
  finally
    LRows.Free;
    LModel.Free;
  end;
end;

procedure TestBoundaries;
var
  LSpans: TAdmittedNoteSpans;
  LInput: TStyleComparatorInput;
  LModels: TStyleComparatorModels;
  LRuns: TStyleComparatorTokenRuns;
  LIndex: Integer;
begin
  SetLength(LSpans, 9);
  LSpans[0] := Span(pskSilence, -1, 0, 250);
  LSpans[1] := Span(pskPitch, 60, 250, 500);
  LSpans[2] := Span(pskSilence, -1, 500, 750);
  LSpans[3] := Span(pskPitch, 64, 750, 1250);
  LSpans[4] := Span(pskSilence, -1, 1250, 1500);
  LSpans[5] := Span(pskPitch, 67, 1500, 1875);
  LSpans[6] := Span(pskUnknown, -1, 1875, 2125);
  LSpans[7] := Span(pskPitch, 72, 2125, 2375);
  LSpans[8] := Span(pskPitch, 76, 2500, 3000);
  LInput := DeclaredInput(LSpans, 1000, 3000);
  LRuns := StyleComparatorInputTokenRuns(LInput.Source);
  Check(Length(LRuns) = 3, 'Unknown and uncovered interval create separate runs');
  Check(Length(LRuns[1]) = 1, 'Unknown is never implicit silence');
  Check(Length(LRuns[2]) = 1, 'Uncovered gap is never implicit silence');
  LModels := BuildStyleComparatorModels(LInput, 731);
  Check(Length(LModels.DerivedSpans) = 9, 'All original spans retained');
  Check(LModels.Permutations[0].LeadingSilenceEndFrame = 250, 'Leading silence fixed');
  Check(Length(LModels.Permutations[0].Units[0].OriginalSpanIndices) = 2,
    'Pitch and explicit following rest form atomic unit');
  Check(not LModels.Permutations[1].Supported, 'Singleton unsupported without redraw');
  Check(not LModels.Permutations[2].Supported, 'Gap-separated singleton unsupported');
  for LIndex := 0 to High(LModels.DerivedSpans) do
  begin
    if LModels.DerivedSpans[LIndex].OriginalSpanIndex = 6 then
    begin
      Check(LModels.DerivedSpans[LIndex].Span.StartFrame = 1875, 'Unknown frame unchanged');
      Check(LModels.DerivedSpans[LIndex].Span.Kind = pskUnknown, 'Unknown meaning unchanged');
    end;
  end;
  SetLength(LSpans, 3);
  LSpans[0] := Span(pskPitch, 60, 0, 11026);
  LSpans[1] := Span(pskPitch, 64, 11026, 27564);
  LSpans[2] := Span(pskPitch, 67, 27564, 49613);
  LInput := DeclaredInput(LSpans, 44100, 49613);
  LModels := BuildStyleComparatorModels(LInput, 731);
  Check(LModels.MarginalDistance = 0, 'Fractional-ms endpoints retain original token marginals');
  Check(ModelMarginals(LModels.ModelTexts[sccSingleRecording]) =
    ModelMarginals(LModels.ModelTexts[sccShuffled]),
    'Actual fractional-frame learned token observation counts unchanged');
  LSpans[0] := Span(pskPitch, 60, 0, 250);
  LSpans[1] := Span(pskPitch, 60, 250, 500);
  LSpans[2] := Span(pskPitch, 60, 500, 750);
  LInput := DeclaredInput(LSpans, 1000, 750);
  LModels := BuildStyleComparatorModels(LInput, 731);
  Check(not LModels.CaseSupported[sccShuffled], 'Identical units have no effective comparator');
  Check(LModels.RelationshipDistance = 0, 'No-effect comparator retains zero measured effect');
  Check(LModels.Permutations[0].Reason = 'unchanged_targeted_token_relationships_no_redraw',
    'No-effect reason explicit without redraw');
  SetLength(LSpans, 1);
  LSpans[0] := Span(pskPitch, 60, 0, 250);
  LInput := DeclaredInput(LSpans, 1000, 250);
  LModels := BuildStyleComparatorModels(LInput, 731);
  Check(not LModels.RelationshipComparable, 'Absent trigram evidence is incomparable');
  Check(IsNan(LModels.RelationshipDistance), 'Missing relationship is not fabricated zero');
end;

procedure WriteJson(const AName: String; AObject: TJSONObject; out AHash: String);
var
  LBytes: TAudioBytes;
begin
  try
    LBytes := TextBytes(UTF8String(AObject.AsJSON));
    AHash := Sha256Bytes(LBytes);
    WriteFreshBytes(AName, LBytes);
  finally
    AObject.Free;
  end;
end;

function WritePacketFixture(out AInput: TStyleComparatorInput): String;
var
  LClip: TAudioClip;
  LSpans: TAdmittedNoteSpans;
  LBytes: TAudioBytes;
  LAnnotation: TJSONObject;
  LArray: TJSONArray;
  LRow: TJSONObject;
  LManifest: TJSONObject;
  LAuthored: TJSONObject;
  LSourceHash: String;
  LAnnotationHash: String;
  LPolicyHash: String;
  LAuthoredHash: String;
  LUnusedHash: String;
  LIndex: Integer;
  LKind: String;
begin
  LClip := MakeAuthoredFixture(LSpans);
  try
    Check(LClip.FrameCount = 68000, 'Authored actual source schedule geometry');
    LBytes := EncodeWavePcm16(LClip);
  finally
    LClip.Free;
  end;
  LSourceHash := Sha256Bytes(LBytes);
  WriteFreshBytes('source.wav', LBytes);
  AInput := DeclaredInput(LSpans, 8000, 68000);
  AInput.Source.RecordingId := 'synthetic-three-repeat';
  AInput.Source.SourceSha256 := LSourceHash;
  LAnnotation := TJSONObject.Create;
  LAnnotation.Add('format', 'pythian.style.comparators.annotations.v1');
  LArray := TJSONArray.Create;
  LAnnotation.Add('spans', LArray);
  for LIndex := 0 to High(LSpans) do
  begin
    LRow := TJSONObject.Create;
    LRow.Add('id', AInput.SpanIds[LIndex]);
    if LSpans[LIndex].Kind = pskPitch then
    begin
      LKind := 'pitch';
    end
    else
    begin
      LKind := 'silence';
    end;
    LRow.Add('kind', LKind);
    LRow.Add('note', LSpans[LIndex].Note);
    LRow.Add('start_frame', LSpans[LIndex].StartFrame);
    LRow.Add('end_frame', LSpans[LIndex].EndFrame);
    LArray.Add(LRow);
  end;
  WriteJson('annotations.json', LAnnotation, LAnnotationHash);
  LBytes := TextBytes('Synthetic authored exact-frame oracle; not independent recording or calibrated quality threshold.');
  LPolicyHash := Sha256Bytes(LBytes);
  WriteFreshBytes('policy.txt', LBytes);
  LAuthored := TJSONObject.Create;
  LAuthored.Add('format', 'pythian.style.comparators.authored.v1');
  LAuthored.Add('provenance', AInput.AuthoredProvenance);
  LArray := TJSONArray.Create;
  LAuthored.Add('choices', LArray);
  for LIndex := 0 to High(AInput.AuthoredVocabulary) do
  begin
    LRow := TJSONObject.Create;
    if AInput.AuthoredVocabulary[LIndex].Kind = pskPitch then
    begin
      LKind := 'pitch';
    end
    else
    begin
      LKind := 'silence';
    end;
    LRow.Add('kind', LKind);
    LRow.Add('note', AInput.AuthoredVocabulary[LIndex].Note);
    LRow.Add('duration_ms', AInput.AuthoredVocabulary[LIndex].Duration);
    LArray.Add(LRow);
  end;
  WriteJson('authored.json', LAuthored, LAuthoredHash);
  AInput.Source.SourceAnnotationSha256 := LAnnotationHash;
  AInput.PolicySha256 := LPolicyHash;
  AInput.AuthoredVocabularySha256 := LAuthoredHash;
  LManifest := TJSONObject.Create;
  LManifest.Add('format', 'pythian.style.comparators.input.v1');
  LRow := TJSONObject.Create;
  LManifest.Add('source', LRow);
  LRow.Add('file', 'source.wav');
  LRow.Add('sha256', LSourceHash);
  LRow.Add('sample_rate', 8000);
  LRow.Add('channels', 2);
  LRow.Add('frames', Int64(68000));
  LRow.Add('recording_id', AInput.Source.RecordingId);
  LRow.Add('group_id', AInput.Source.GroupId);
  LRow.Add('provenance', AInput.SourceProvenance);
  LRow.Add('exposure', AInput.Exposure);
  LRow := TJSONObject.Create;
  LManifest.Add('annotations', LRow);
  LRow.Add('file', 'annotations.json');
  LRow.Add('sha256', LAnnotationHash);
  LRow.Add('id', AInput.Source.SourceAnnotationId);
  LRow.Add('publisher', AInput.Source.SourceAnnotationPublisher);
  LRow.Add('method', AInput.Source.SourceAnnotationMethod);
  LRow := TJSONObject.Create;
  LManifest.Add('policy', LRow);
  LRow.Add('file', 'policy.txt');
  LRow.Add('sha256', LPolicyHash);
  LRow := TJSONObject.Create;
  LManifest.Add('authored_baseline', LRow);
  LRow.Add('file', 'authored.json');
  LRow.Add('sha256', LAuthoredHash);
  WriteJson('manifest.json', LManifest, LUnusedHash);
  Result := IncludeTrailingPathDelimiter(GOutputRoot) + 'manifest.json';
end;

procedure TestModelsAndRender(const AInput: TStyleComparatorInput);
var
  LModels: TStyleComparatorModels;
  LModel: TWfcSequenceModel;
  LOptions: TStyleComparatorRenderOptions;
  LLedger: TStyleComparatorRenderLedger;
  LReplayLedger: TStyleComparatorRenderLedger;
  LClip: TAudioClip;
  LReplay: TAudioClip;
  LReloaded: TAudioClip;
  LCase: TStyleComparatorCase;
  LIndex: Integer;
  LRejected: Boolean;
begin
  LModels := BuildStyleComparatorModels(AInput, 731);
  Check(LModels.CaseSupported[sccShuffled], 'Authored fixture has effective shuffle');
  Check(LModels.RelationshipDistance > 0, 'Effective shuffle changes learned relationship');
  Check(LModels.MarginalDistance = 0, 'Authored fixture preserves marginals');
  Check(ModelRelationships(LModels.ModelTexts[sccSingleRecording]) <>
    ModelRelationships(LModels.ModelTexts[sccShuffled]),
    'Actual learned complete trigram relations change, beyond model vocabulary order');
  for LCase := Low(TStyleComparatorCase) to High(TStyleComparatorCase) do
  begin
    LModel := DecodeWfcSequenceText(LModels.ModelTexts[LCase]);
    try
      Check(EncodeWfcSequenceText(LModel) = LModels.ModelTexts[LCase], 'Canonical model reload');
      if LCase = sccUnlearned then
      begin
        Check(LModel.Order = 1, 'Authored baseline has no learned ordering');
        Check(LModel.PublicTokenCount = 3, 'Independent authored vocabulary retained');
        for LIndex := 0 to LModel.StateCount - 1 do
        begin
          Check(LModel.StateObservationCountAt(LIndex) = 1, 'Authored choices have equal declared weights');
        end;
      end
      else
      begin
        Check(LModel.Order = 3, 'Learned order retains pitch-rest-next-pitch');
      end;
    finally
      LModel.Free;
    end;
    LOptions := DefaultStyleComparatorRenderOptions(731);
    LOptions.OutputMilliseconds := 1001;
    LOptions.SampleRate := 8000;
    LClip := GenerateStyleComparator(LModels.ModelTexts[LCase], LOptions, LLedger);
    LReplay := nil;
    try
      LReplay := GenerateStyleComparator(LModels.ModelTexts[LCase], LOptions, LReplayLedger);
      Check(LClip.FrameCount = 8008, 'Exact non-token-aligned output frame count');
      Check(LClip.Channels = 2, 'Native stereo output');
      Check(LLedger.FinalSpanClipped, 'Final known token clipped at exact clock');
      Check(LLedger.OutputFrames = LClip.FrameCount, 'Ledger agrees actual output');
      Check(Sha256Bytes(EncodeWavePcm16(LClip)) = Sha256Bytes(EncodeWavePcm16(LReplay)),
        'Fixed-seed actual PCM replay');
      WriteFreshBytes('short-' + IntToStr(Ord(LCase)) + '.wav', EncodeWavePcm16(LClip));
      WriteFreshBytes('model-' + IntToStr(Ord(LCase)) + '.txt', TextBytes(UTF8String(LModels.ModelTexts[LCase])));
      LReloaded := LoadWave(IncludeTrailingPathDelimiter(GOutputRoot) +
        'short-' + IntToStr(Ord(LCase)) + '.wav');
      try
        Check(LReloaded.FrameCount = 8008, 'Actual saved WAV geometry');
        for LIndex := 0 to LClip.FrameCount - 1 do
        begin
          if Abs(LReloaded.SampleAt(LIndex, 0) - LClip.SampleAt(LIndex, 0)) > 1 / 32768 then
          begin
            raise EAudio.Create('Saved PCM differs beyond quantization tolerance');
          end;
        end;
        Check(True, 'Actual saved WAV decoded samples match rendered PCM');
      finally
        LReloaded.Free;
      end;
    finally
      LReplay.Free;
      LClip.Free;
    end;
  end;
  LOptions := DefaultStyleComparatorRenderOptions(731);
  LOptions.OutputMilliseconds := 1001;
  LOptions.MaximumTokens := 1;
  LRejected := False;
  try
    LClip := GenerateStyleComparator(LModels.ModelTexts[sccSingleRecording], LOptions, LLedger);
    LClip.Free;
  except
    on LError: Exception do
    begin
      LRejected := True;
    end;
  end;
  Check(LRejected, 'Token budget rejects before rendering');
  LOptions := DefaultStyleComparatorRenderOptions(731);
  LOptions.OutputMilliseconds := 1001;
  LOptions.Level := NaN;
  LRejected := False;
  try
    LClip := GenerateStyleComparator(LModels.ModelTexts[sccSingleRecording], LOptions, LLedger);
    LClip.Free;
  except
    on LError: Exception do
    begin
      LRejected := True;
    end;
  end;
  Check(LRejected, 'Nonfinite synthesis level rejected');
end;

function ReadText(const APath: String): String;
var
  LStream: TFileStream;
begin
  LStream := TFileStream.Create(APath, fmOpenRead or fmShareDenyWrite);
  try
    Check((LStream.Size > 0) and (LStream.Size <= 16 * 1024 * 1024), 'Bounded text input');
    SetLength(Result, LStream.Size);
    if Length(Result) > 0 then
    begin
      LStream.ReadBuffer(Result[1], Length(Result));
    end;
  finally
    LStream.Free;
  end;
end;

procedure RejectManifest(const AName, AText: String);
var
  LRejected: Boolean;
  LInput: TStyleComparatorInput;
begin
  WriteFreshBytes(AName, TextBytes(UTF8String(AText)));
  LRejected := False;
  try
    LInput := ReadStyleComparatorInputFile(IncludeTrailingPathDelimiter(GOutputRoot) + AName);
  except
    on LError: Exception do
    begin
      LRejected := True;
    end;
  end;
  Check(LRejected, 'Authenticated reader rejection: ' + AName);
end;

procedure TestReader(const AManifestPath: String; const AExpected: TStyleComparatorInput);
var
  LInput: TStyleComparatorInput;
  LOriginal: String;
  LDocument: TJSONObject;
  LSource: TJSONObject;
  LText: String;
begin
  LInput := ReadStyleComparatorInputFile(AManifestPath);
  Check(LInput.Source.SourceSha256 = AExpected.Source.SourceSha256, 'Actual source hash authenticated');
  Check(LInput.Source.SourceAnnotationSha256 = AExpected.Source.SourceAnnotationSha256,
    'Actual annotation bytes authenticated');
  Check(LInput.PolicySha256 = AExpected.PolicySha256, 'Opaque policy bytes authenticated');
  Check(LInput.Source.Spans[1].Note = 60, 'Authored schedule reader preserves actual note');
  Check(LInput.Source.Spans[1].StartFrame = 2000, 'Authored exact-frame reader preserves leading silence');
  Check(LInput.Source.SourceFrameCount = 68000, 'Actual WAV geometry authenticated');
  LOriginal := ReadText(AManifestPath);
  LDocument := TJSONObject(GetJSON(LOriginal));
  try
    LSource := TJSONObject(LDocument.Find('source'));
    LSource.Strings['sha256'] := StringOfChar('1', 64);
    RejectManifest('false-source-hash.json', LDocument.AsJSON);
    LSource.Strings['sha256'] := AExpected.Source.SourceSha256;
    LSource.Integers['sample_rate'] := 8001;
    RejectManifest('false-clock.json', LDocument.AsJSON);
    LSource.Integers['sample_rate'] := 8000;
    LSource.Integers['channels'] := 1;
    RejectManifest('false-channels.json', LDocument.AsJSON);
    LSource.Integers['channels'] := 2;
    LSource.Int64s['frames'] := 67999;
    RejectManifest('false-frames.json', LDocument.AsJSON);
    LSource.Int64s['frames'] := 68000;
    LSource.Strings['file'] := '../source.wav';
    RejectManifest('path-traversal.json', LDocument.AsJSON);
    LSource.Strings['file'] := 'source.wav';
    TJSONObject(LDocument.Find('policy')).Strings['sha256'] := StringOfChar('2', 64);
    RejectManifest('false-policy-hash.json', LDocument.AsJSON);
    TJSONObject(LDocument.Find('policy')).Strings['sha256'] := AExpected.PolicySha256;
    TJSONObject(LDocument.Find('annotations')).Strings['sha256'] := StringOfChar('3', 64);
    RejectManifest('false-annotation-hash.json', LDocument.AsJSON);
  finally
    LDocument.Free;
  end;
  RejectManifest('truncated.json', Copy(LOriginal, 1, Length(LOriginal) div 2));
  LText := '{"format":"pythian.style.comparators.input.v1",' + Copy(LOriginal, 2, MaxInt);
  RejectManifest('duplicate-field.json', LText);
  RejectManifest('unknown-field.json', '{"unrecognized":true,' + Copy(LOriginal, 2, MaxInt));
  Check(ReadText(AManifestPath) = LOriginal, 'Malformed admission preserves original manifest');
  LInput := ReadStyleComparatorInputFile(AManifestPath);
  Check(LInput.Source.SourceSha256 = AExpected.Source.SourceSha256, 'Valid admission recovers after failures');
end;

procedure TestPrepublication(const AManifestPath: String);
var
  LRejected: Boolean;
  LOutput: String;
  LOriginal: String;
begin
  LOutput := IncludeTrailingPathDelimiter(GOutputRoot) + 'invalid-packet';
  LRejected := False;
  try
    RunStyleComparatorPacket(IncludeTrailingPathDelimiter(GOutputRoot) +
      'false-source-hash.json', LOutput);
  except
    on LError: Exception do
    begin
      LRejected := True;
    end;
  end;
  Check(LRejected, 'Malformed asset rejects packet before staging');
  Check(not DirectoryExists(LOutput), 'Malformed packet creates no output');
  Check(not DirectoryExists(LOutput + '.attempt'), 'Malformed packet creates no attempt');
  LOriginal := ReadText(AManifestPath);
  LRejected := False;
  try
    RunStyleComparatorPacket(AManifestPath, GOutputRoot);
  except
    on LError: Exception do
    begin
      LRejected := True;
    end;
  end;
  Check(LRejected, 'Occupied output rejects before solving');
  Check(not DirectoryExists(GOutputRoot + '.attempt'), 'Occupied output creates no attempt');
  Check(ReadText(AManifestPath) = LOriginal, 'Occupied output preserves existing fixture');
end;

procedure ExactFields(AObject: TJSONObject; const ANames: String);
var
  LNames: TStringList;
  LIndex: Integer;
  LOther: Integer;
  LName: String;
  LType: TJSONType;
  LInteger: Int64;
begin
  LNames := TStringList.Create;
  try
    LNames.Delimiter := ',';
    LNames.StrictDelimiter := True;
    LNames.DelimitedText := ANames;
    Check(AObject.Count = LNames.Count, 'Exact packet object field count');
    for LIndex := 0 to AObject.Count - 1 do
    begin
      Check(LNames.IndexOf(AObject.Names[LIndex]) >= 0, 'Known packet field');
      LName := AObject.Names[LIndex];
      if Pos(',' + LName + ',', ',original_spans,derivations,executions,runs,derived_frame_spans_by_original_index,canonical_units,output_to_original_ordinals,canonical_unit_sha256_keys,original_span_indices,full_solved_tokens,actually_rendered_tokens,unused_solved_suffix,') > 0 then
      begin
        LType := jtArray;
      end
      else if Pos(',' + LName + ',', ',input_evidence,render,solver,') > 0 then
      begin
        LType := jtObject;
      end
      else if Pos(',' + LName + ',', ',grounded_acceptance,training_token_trigram_comparable,supported,identity_rotated,final_span_clipped,attempted,trace_captured,') > 0 then
      begin
        LType := jtBoolean;
      end
      else if Pos(',' + LName + ',', ',format,status,extent,recording_id,group_id,source_sha256,source_provenance,exposure,annotation_id,annotation_sha256,annotation_publisher,annotation_method,policy_sha256,policy_semantics,authored_vocabulary_sha256,authored_provenance,dimension,duration_policy,derived_frame_policy,kind,id,scope_id,reason,case,model_file,model_sha256,wave_file,wave_sha256,') > 0 then
      begin
        LType := jtString;
      end
      else
      begin
        LType := jtNumber;
      end;
      Check(AObject.Items[LIndex].JSONType = LType, 'Strict packet field value type');
      if (LType = jtNumber) and
        (Pos(',' + LName + ',', ',level,original_model_token_marginal_distance,training_token_trigram_distance,rendered_token_marginal_distance,rendered_token_trigram_distance,') = 0) then
      begin
        Check(TryStrToInt64(AObject.Items[LIndex].AsJSON, LInteger), 'Strict integer packet field');
      end;
      for LOther := 0 to LIndex - 1 do
      begin
        Check(AObject.Names[LIndex] <> AObject.Names[LOther], 'Unique packet field');
      end;
    end;
  finally
    LNames.Free;
  end;
end;

function PacketPath(const ARoot, AName: String): String;
var
  LIndex: Integer;
begin
  Check((Length(AName) > 0) and (Length(AName) <= 128) and
    (AName <> '.') and (AName <> '..'), 'Packet file basename bounds');
  for LIndex := 1 to Length(AName) do
  begin
    Check(AName[LIndex] in ['a'..'z', 'A'..'Z', '0'..'9', '.', '_', '-'],
      'Packet file basename character');
  end;
  Result := IncludeTrailingPathDelimiter(ARoot) + AName;
end;

procedure StrictArray(AArray: TJSONArray; AType: TJSONType);
var
  LIndex: Integer;
  LInteger: Int64;
begin
  for LIndex := 0 to AArray.Count - 1 do
  begin
    Check(AArray.Items[LIndex].JSONType = AType, 'Strict packet array item type');
    if AType = jtNumber then
    begin
      Check(TryStrToInt64(AArray.Items[LIndex].AsJSON, LInteger), 'Strict integer packet array item');
    end;
  end;
end;

function VerifyFileHash(const APath, AHash: String; AMaximum: Int64): String;
var
  LStream: TFileStream;
begin
  LStream := TFileStream.Create(APath, fmOpenRead or fmShareDenyWrite);
  try
    Check((LStream.Size > 0) and (LStream.Size <= AMaximum), 'Bounded actual packet file');
    Result := Sha256Stream(LStream, LStream.Size);
    Check(Result = AHash, 'Actual saved file SHA matches packet');
  finally
    LStream.Free;
  end;
end;

procedure VerifyPacket(const ARoot: String);
const
  CSeeds: array[0..2] of Integer = (731, 1731, 2731);
  CCases: array[0..2] of String = ('single_recording_baseline',
    'source_local_shuffled', 'independently_authored_equal_choice');
var
  LRoot: TJSONObject;
  LData: TJSONData;
  LEvidence: TJSONObject;
  LDerivation: TJSONObject;
  LRun: TJSONObject;
  LUnit: TJSONObject;
  LOriginalSpan: TJSONObject;
  LDerivedSpan: TJSONObject;
  LExecution: TJSONObject;
  LRender: TJSONObject;
  LSolver: TJSONObject;
  LDerivations: TJSONArray;
  LExecutions: TJSONArray;
  LOriginal: TJSONArray;
  LDerived: TJSONArray;
  LRuns: TJSONArray;
  LUnits: TJSONArray;
  LOrdinals: TJSONArray;
  LParts: TJSONArray;
  LFull: TJSONArray;
  LUsed: TJSONArray;
  LSuffix: TJSONArray;
  LSeen: array of Boolean;
  LOwned: array of Boolean;
  LModels: array[0..2] of String;
  LStream: TFileStream;
  LReader: TWaveFrameReader;
  LModel: TWfcSequenceModel;
  LFullCell: TPitchDurationCell;
  LUsedCell: TPitchDurationCell;
  LSeedIndex: Integer;
  LCaseIndex: Integer;
  LRunIndex: Integer;
  LIndex: Integer;
  LPart: Integer;
  LOrdinal: Integer;
  LSpanIndex: Integer;
  LUsedCount: Integer;
  LTotal: Int64;
  LFullTotal: Int64;
  LPosition: Int64;
  LEnd: Int64;
  LModelPath: String;
  LWavePath: String;
  LPacketText: String;
  LHash: String;
begin
  LPacketText := ReadText(IncludeTrailingPathDelimiter(ARoot) + 'packet.json');
  Check(Length(LPacketText) <= 4 * 1024 * 1024, 'Packet JSON bounded');
  LData := GetJSON(LPacketText);
  if LData.JSONType <> jtObject then
  begin
    LData.Free;
    raise EAudio.Create('Packet root must be an object');
  end;
  LRoot := TJSONObject(LData);
  try
    ExactFields(LRoot, 'format,status,grounded_acceptance,expected_render_count,completed_render_count,output_ms,sample_rate,channels,level,release_ms,extent,maximum_tokens,input_evidence,derivations,executions');
    Check(LRoot.Strings['format'] = StyleComparatorPacketFormat, 'Current packet format');
    Check(LRoot.Strings['status'] = 'completed_mechanical_execution', 'Completed packet status');
    Check(not LRoot.Booleans['grounded_acceptance'], 'Packet explicitly ungrounded');
    Check((LRoot.Integers['expected_render_count'] = 9) and
      (LRoot.Integers['completed_render_count'] = 9), 'Nine actual expected/completed outputs');
    Check((LRoot.Integers['output_ms'] = 120000) and
      (LRoot.Integers['sample_rate'] = 16000) and (LRoot.Integers['channels'] = 2),
      'Fixed full output clock');
    Check((LRoot.Integers['release_ms'] = 0) and (LRoot.Strings['extent'] = 'prefix') and
      (LRoot.Integers['maximum_tokens'] = 1024) and (Abs(LRoot.Floats['level'] - 0.1) < 1E-12),
      'Fixed full render policy');
    LEvidence := TJSONObject(LRoot.Find('input_evidence'));
    ExactFields(LEvidence, 'recording_id,group_id,source_sha256,source_provenance,exposure,source_sample_rate,source_channels,source_frame_count,annotation_id,annotation_sha256,annotation_publisher,annotation_method,policy_sha256,policy_semantics,authored_vocabulary_sha256,authored_provenance,original_spans');
    Check((Length(LEvidence.Strings['recording_id']) > 0) and
      (Length(LEvidence.Strings['group_id']) > 0), 'Retained source/group identities');
    Check(LEvidence.Strings['policy_semantics'] = 'opaque_caller_declaration_no_calibration',
      'Retained scientific scope');
    LOriginal := TJSONArray(LEvidence.Find('original_spans'));
    StrictArray(LOriginal, jtObject);
    Check((LOriginal.Count > 0) and (LOriginal.Count <= 1024), 'Retained original spans');
    LDerivations := TJSONArray(LRoot.Find('derivations'));
    LExecutions := TJSONArray(LRoot.Find('executions'));
    StrictArray(LDerivations, jtObject);
    StrictArray(LExecutions, jtObject);
    Check((LDerivations.Count = 3) and (LExecutions.Count = 9), 'Exact seed/case counts');
    for LSeedIndex := 0 to 2 do
    begin
      LDerivation := TJSONObject(LDerivations.Items[LSeedIndex]);
      ExactFields(LDerivation, 'seed,dimension,learned_shuffled_order,unlearned_order,original_model_token_marginal_distance,training_token_trigram_comparable,training_token_trigram_distance,duration_policy,derived_frame_policy,runs,derived_frame_spans_by_original_index');
      Check(LDerivation.Integers['seed'] = CSeeds[LSeedIndex], 'Prospective seed retained');
      Check(LDerivation.Strings['dimension'] = StyleComparatorDimension, 'Target dimension retained');
      Check(LDerivation.Booleans['training_token_trigram_comparable'] and
        (LDerivation.Floats['training_token_trigram_distance'] > 0), 'Effective new-context derivation');
      Check(LDerivation.Floats['original_model_token_marginal_distance'] = 0, 'Zero original-token marginal change');
      Check((LDerivation.Integers['learned_shuffled_order'] = 3) and
        (LDerivation.Integers['unlearned_order'] = 1), 'Declared model orders');
      LDerived := TJSONArray(LDerivation.Find('derived_frame_spans_by_original_index'));
      StrictArray(LDerived, jtObject);
      Check(LDerived.Count = LOriginal.Count, 'Every original span retained in derivation');
      SetLength(LOwned, 0);
      SetLength(LOwned, LOriginal.Count);
      for LIndex := 0 to LOriginal.Count - 1 do
      begin
        LOriginalSpan := TJSONObject(LOriginal.Items[LIndex]);
        LDerivedSpan := TJSONObject(LDerived.Items[LIndex]);
        ExactFields(LOriginalSpan, 'kind,note,start_frame,end_frame,id');
        ExactFields(LDerivedSpan, 'kind,note,start_frame,end_frame,original_span_index');
        Check(Length(LOriginalSpan.Strings['id']) > 0, 'Retained original ID');
        Check((LDerivedSpan.Integers['original_span_index'] = LIndex) and
          (LDerivedSpan.Strings['kind'] = LOriginalSpan.Strings['kind']) and
          (LDerivedSpan.Integers['note'] = LOriginalSpan.Integers['note']), 'Derived index/meaning retained');
        Check(LDerivedSpan.Int64s['end_frame'] - LDerivedSpan.Int64s['start_frame'] =
          LOriginalSpan.Int64s['end_frame'] - LOriginalSpan.Int64s['start_frame'], 'Exact original frame duration retained');
      end;
      LRuns := TJSONArray(LDerivation.Find('runs'));
      StrictArray(LRuns, jtObject);
      Check(LRuns.Count > 0, 'Retained run boundaries');
      for LRunIndex := 0 to LRuns.Count - 1 do
      begin
        LRun := TJSONObject(LRuns.Items[LRunIndex]);
        ExactFields(LRun, 'scope_id,first_frame,end_frame,leading_silence_end_frame,supported,reason,identity_rotated,canonical_units,output_to_original_ordinals,canonical_unit_sha256_keys');
        Check(LRun.Strings['scope_id'] = LEvidence.Strings['recording_id'] + ':run:' + IntToStr(LRunIndex),
          'Source-local scope ID');
        LUnits := TJSONArray(LRun.Find('canonical_units'));
        LOrdinals := TJSONArray(LRun.Find('output_to_original_ordinals'));
        StrictArray(LUnits, jtObject);
        StrictArray(LOrdinals, jtNumber);
        StrictArray(TJSONArray(LRun.Find('canonical_unit_sha256_keys')), jtString);
        Check(LUnits.Count = LOrdinals.Count, 'Complete permutation length');
        Check(TJSONArray(LRun.Find('canonical_unit_sha256_keys')).Count = LUnits.Count, 'Complete permutation digest ledger');
        SetLength(LSeen, 0);
        SetLength(LSeen, LUnits.Count);
        LPosition := LRun.Int64s['leading_silence_end_frame'];
        for LIndex := 0 to LOrdinals.Count - 1 do
        begin
          LOrdinal := LOrdinals.Integers[LIndex];
          Check((LOrdinal >= 0) and (LOrdinal < LUnits.Count), 'Permutation index bounds');
          Check(not LSeen[LOrdinal], 'Permutation is bijective');
          LSeen[LOrdinal] := True;
          LUnit := TJSONObject(LUnits.Items[LOrdinal]);
          ExactFields(LUnit, 'id,original_first_frame,original_end_frame,original_span_indices');
          LParts := TJSONArray(LUnit.Find('original_span_indices'));
          StrictArray(LParts, jtNumber);
          Check(LParts.Count > 0, 'Atomic unit owns source spans');
          for LPart := 0 to LParts.Count - 1 do
          begin
            LSpanIndex := LParts.Integers[LPart];
            Check((LSpanIndex >= 0) and (LSpanIndex < LOriginal.Count), 'Atomic span index bounds');
            LOriginalSpan := TJSONObject(LOriginal.Items[LSpanIndex]);
            LDerivedSpan := TJSONObject(LDerived.Items[LSpanIndex]);
            Check(not LOwned[LSpanIndex], 'Original span has one atomic owner');
            LOwned[LSpanIndex] := True;
            if LPart = 0 then
            begin
              Check(LUnit.Strings['id'] = LOriginalSpan.Strings['id'], 'Atomic unit retains original pitch ID');
              Check(LOriginalSpan.Strings['kind'] = 'pitch', 'Atomic unit begins with known pitch');
              Check(LUnit.Int64s['original_first_frame'] = LOriginalSpan.Int64s['start_frame'],
                'Atomic original start retained');
            end
            else
            begin
              Check(LOriginalSpan.Strings['kind'] = 'silence', 'Only explicit known silence accompanies pitch');
            end;
            Check(LDerivedSpan.Int64s['start_frame'] = LPosition, 'Permutation maps exact atomic moved position');
            Inc(LPosition, LOriginalSpan.Int64s['end_frame'] - LOriginalSpan.Int64s['start_frame']);
            Check(LDerivedSpan.Int64s['end_frame'] = LPosition, 'Atomic known-rest extent preserved');
            if LPart = LParts.Count - 1 then
            begin
              Check(LUnit.Int64s['original_end_frame'] = LOriginalSpan.Int64s['end_frame'],
                'Atomic original end retained');
            end;
          end;
        end;
        Check(LPosition = LRun.Int64s['end_frame'], 'Permutation preserves complete run clock');
      end;
      for LIndex := 0 to LOriginal.Count - 1 do
      begin
        if not LOwned[LIndex] then
        begin
          LOriginalSpan := TJSONObject(LOriginal.Items[LIndex]);
          LDerivedSpan := TJSONObject(LDerived.Items[LIndex]);
          Check((LDerivedSpan.Int64s['start_frame'] = LOriginalSpan.Int64s['start_frame']) and
            (LDerivedSpan.Int64s['end_frame'] = LOriginalSpan.Int64s['end_frame']),
            'Unowned leading silence/unknown boundaries stay fixed');
        end;
      end;
      for LCaseIndex := 0 to 2 do
      begin
        LExecution := TJSONObject(LExecutions.Items[LSeedIndex * 3 + LCaseIndex]);
        ExactFields(LExecution, 'seed,case,status,model_file,model_sha256,wave_file,wave_sha256,render,rendered_token_marginal_distance,rendered_token_trigram_distance');
        Check((LExecution.Integers['seed'] = CSeeds[LSeedIndex]) and
          (LExecution.Strings['case'] = CCases[LCaseIndex]) and
          (LExecution.Strings['status'] = 'completed_mechanical_execution'), 'Exact completed seed/case');
        LModelPath := PacketPath(ARoot, LExecution.Strings['model_file']);
        LHash := VerifyFileHash(LModelPath, LExecution.Strings['model_sha256'], 16 * 1024 * 1024);
        LModels[LCaseIndex] := ReadText(LModelPath);
        LModel := DecodeWfcSequenceText(LModels[LCaseIndex]);
        try
          Check(EncodeWfcSequenceText(LModel) = LModels[LCaseIndex], 'Actual saved model canonical');
          if LCaseIndex = 2 then
          begin
            Check(LModel.Order = 1, 'Actual saved authored model order');
          end
          else
          begin
            Check(LModel.Order = 3, 'Actual saved learned model order');
          end;
        finally
          LModel.Free;
        end;
        LWavePath := PacketPath(ARoot, LExecution.Strings['wave_file']);
        VerifyFileHash(LWavePath, LExecution.Strings['wave_sha256'], 8 * 1024 * 1024);
        LStream := TFileStream.Create(LWavePath, fmOpenRead or fmShareDenyWrite);
        try
          LReader := TWaveFrameReader.Create(LStream);
          try
            Check((LReader.SampleRate = 16000) and (LReader.Channels = 2) and
              (LReader.BitsPerSample = 16) and (LReader.FrameCount = 1920000),
              'Actual saved WAV is full120s stereo16k PCM16');
          finally
            LReader.Free;
          end;
        finally
          LStream.Free;
        end;
        LRender := TJSONObject(LExecution.Find('render'));
        ExactFields(LRender, 'solver,requested_token_count,used_token_count,full_solved_duration_ms,final_rendered_span_ms,final_span_clipped,output_frames,model_sha256,full_solved_tokens,actually_rendered_tokens,unused_solved_suffix');
        Check(LRender.Strings['model_sha256'] = LHash, 'Rendered saved-model binding');
        Check(LRender.Int64s['output_frames'] = 1920000, 'Full output frame ledger');
        LSolver := TJSONObject(LRender.Find('solver'));
        ExactFields(LSolver, 'attempted,seed,frame_count_means_tokens,extent,max_backtracks,state_cell_budget,status_ordinal,random_algorithm_version,solver_algorithm_version,graph_model_version,pipeline_algorithm_version,failed_pass_index,contradiction_kind_ordinal,trace_captured');
        Check(LSolver.Booleans['attempted'] and (LSolver.Integers['status_ordinal'] = 0), 'Actual solved pipeline');
        Check(LSolver.Integers['seed'] = CSeeds[LSeedIndex], 'Solver seed binding');
        LFull := TJSONArray(LRender.Find('full_solved_tokens'));
        LUsed := TJSONArray(LRender.Find('actually_rendered_tokens'));
        LSuffix := TJSONArray(LRender.Find('unused_solved_suffix'));
        StrictArray(LFull, jtString);
        StrictArray(LUsed, jtString);
        StrictArray(LSuffix, jtString);
        LUsedCount := LRender.Integers['used_token_count'];
        Check((LFull.Count = LRender.Integers['requested_token_count']) and
          (LFull.Count <= 1024) and (LUsed.Count = LUsedCount) and (LUsedCount > 0) and
          (LUsedCount <= LFull.Count), 'Full/used token counts bounded');
        Check(LSolver.Integers['frame_count_means_tokens'] = LFull.Count, 'Solver extent means tokens');
        Check(LSuffix.Count = LFull.Count - LUsedCount, 'Exact unused suffix count');
        LTotal := 0;
        LFullTotal := 0;
        for LIndex := 0 to LFull.Count - 1 do
        begin
          LFullCell := DecodePitchDurationToken(UTF8String(LFull.Strings[LIndex]));
          Check(LFullCell.Kind <> pskUnknown, 'No generated implicit unknown/rest');
          Inc(LFullTotal, LFullCell.Duration);
          if LIndex < LUsedCount then
          begin
            LUsedCell := DecodePitchDurationToken(UTF8String(LUsed.Strings[LIndex]));
            Check((LUsedCell.Kind = LFullCell.Kind) and (LUsedCell.Note = LFullCell.Note),
              'Rendered token retains solved meaning');
            if LIndex < LUsedCount - 1 then
            begin
              Check(LUsed.Strings[LIndex] = LFull.Strings[LIndex], 'Rendered prefix exact before final span');
            end
            else
            begin
              LEnd := 120000 - LTotal;
              Check((LUsedCell.Duration = LEnd) and (LUsedCell.Duration <= LFullCell.Duration),
                'Final rendered duration exact clock clipping');
              Check(LRender.Integers['final_rendered_span_ms'] = LUsedCell.Duration, 'Final span ledger agrees');
              Check(LRender.Booleans['final_span_clipped'] = (LUsedCell.Duration < LFullCell.Duration),
                'Clipping flag truthful');
            end;
            Inc(LTotal, LUsedCell.Duration);
          end
          else
          begin
            Check(LSuffix.Strings[LIndex - LUsedCount] = LFull.Strings[LIndex], 'Unused solved suffix exact');
          end;
        end;
        Check((LTotal = 120000) and (LFullTotal = LRender.Int64s['full_solved_duration_ms']),
          'Independent duration sum agrees full/rendered ledgers');
      end;
      Check(ModelMarginals(LModels[0]) = ModelMarginals(LModels[1]), 'Actual saved learned model marginals identical');
      Check(ModelRelationships(LModels[0]) <> ModelRelationships(LModels[1]), 'Actual saved learned relationships changed');
      Check((LModels[0] <> LModels[2]) and (LModels[1] <> LModels[2]), 'Actual authored model distinct');
    end;
    WriteLn('PASS ', GChecks, ' independent packet assertions; no generation or calibrated musical claim');
  finally
    LRoot.Free;
  end;
end;

var
  LInput: TStyleComparatorInput;
  LManifestPath: String;
begin
  try
    if (ParamCount = 2) and (ParamStr(1) = 'verify-packet') then
    begin
      VerifyPacket(ExpandFileName(ParamStr(2)));
    end
    else
    begin
      PrepareOutputRoot;
      LManifestPath := WritePacketFixture(LInput);
      TestReader(LManifestPath, LInput);
      TestPrepublication(LManifestPath);
      TestGolden;
      TestRelationships;
      TestBoundaries;
      TestModelsAndRender(LInput);
      WriteLn('PASS ', GChecks, ' synthetic mechanical assertions');
      WriteLn('CLI fixture: ', LManifestPath);
      WriteLn('No independent recorded-reference calibration or musical acceptance claimed.');
    end;
  except
    on LError: Exception do
    begin
      WriteLn(StdErr, LError.ClassName, ': ', LError.Message);
      ExitCode := 1;
    end;
  end;
end.
