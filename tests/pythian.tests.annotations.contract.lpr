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
program pythian_tests_annotations_contract;

{$mode delphi}
{$H+}

uses
  Classes,
  SysUtils,
  fpjson,
  pythian.audio,
  pythian.hash,
  pythian.wave.stream,
  pythian.tools.annotations.catalog,
  pythian.tools.annotations.contract,
  pythian.tools.annotations.queue,
  pythian.tools.annotations.review,
  pythian.tools.annotations.proposal,
  pythian.tools.annotations.export,
  pythian.tools.annotations.replay;

procedure Need(const ACondition: Boolean; const AMessage: String);
begin
  if not ACondition then
    raise Exception.Create(AMessage);
end;

procedure WriteJson(const APath: String; const AData: TJSONObject);
var
  LText: String;
  LOutput: TFileStream;
begin
  LText := AData.AsJSON + LineEnding;
  LOutput := TFileStream.Create(APath, fmCreate);
  try
    LOutput.WriteBuffer(LText[1], Length(LText));
  finally
    LOutput.Free;
  end;
end;

function SourceHash(const APath: String): String;
var
  LInput: TFileStream;
begin
  LInput := TFileStream.Create(APath, fmOpenRead);
  try
    Result := Sha256Stream(LInput, LInput.Size);
  finally
    LInput.Free;
  end;
end;

function PrepareSource(const ARoot: String;
  const APartition: String = 'development'): String;
var
  LSamples: TAudioSamples;
  LClip: TAudioClip;
  LOutput: TFileStream;
  LManifest: TJSONObject;
  LTracks: TJSONArray;
  LTrack: TJSONObject;
  LReport: TJSONObject;
  LIndex: Integer;
  LInbox: String;
  LPath: String;
begin
  LInbox := IncludeTrailingPathDelimiter(ARoot) + 'inbox';
  Need(ForceDirectories(LInbox), 'inbox directory');
  SetLength(LSamples, 8000);
  for LIndex := 0 to High(LSamples) do
    if LIndex mod 500 < 30 then
      LSamples[LIndex] := 0.8
    else
      LSamples[LIndex] := 0;
  LClip := TAudioClip.Create(1000, 1, LSamples);
  try
    LPath := IncludeTrailingPathDelimiter(LInbox) + 'source.wav';
    LOutput := TFileStream.Create(LPath, fmCreate);
    try
      WriteWavePcm16(LOutput, LClip);
    finally
      LOutput.Free;
    end;
  finally
    LClip.Free;
  end;
  Result := SourceHash(LPath);
  LManifest := TJSONObject.Create;
  try
    LManifest.Add('version', 1);
    LTracks := TJSONArray.Create;
    LManifest.Add('tracks', LTracks);
    LTrack := TJSONObject.Create;
    LTracks.Add(LTrack);
    LTrack.Add('file', 'source.wav');
    LTrack.Add('sha256', Result);
    LTrack.Add('source_group', 'contract_control');
    LTrack.Add('clock_id', '');
    LTrack.Add('partition', APartition);
    LTrack.Add('title', 'Source-free structured review control');
    LTrack.Add('provenance', 'Pascal-authored test pulse train');
    LTrack.Add('license', 'MIT');
    WriteJson(IncludeTrailingPathDelimiter(LInbox) + 'manifest.json',
      LManifest);
  finally
    LManifest.Free;
  end;
  LReport := ImportLabelInbox(LInbox,
    IncludeTrailingPathDelimiter(ARoot) + 'catalog');
  try
    Need((LReport.Integers['imported'] = 1) and
      (LReport.Integers['failed'] = 0), 'source import');
  finally
    LReport.Free;
  end;
end;

function Link(const AKind, ARole, AHash, ATarget,
  ATargetType: String; const ATargetRevision: Integer = 0): TJSONObject;
begin
  Result := TJSONObject.Create;
  Result.Add('role', ARole);
  Result.Add('kind', AKind);
  Result.Add('source_sha256', AHash);
  Result.Add('target_id', ATarget);
  if AKind = 'label' then
  begin
    Result.Add('target_type', ATargetType);
    Result.Add('target_revision', ATargetRevision);
  end;
end;

function Item(const AId, AHash, AType, AFacet, AGeometry,
  AProposal: String; const AStart, AEnd: Int64;
  const AValues: array of String; ALinks: TJSONArray): TJSONObject;
var
  LSpec: TJSONObject;
  LValues: TJSONArray;
  LIndex: Integer;
begin
  Result := TJSONObject.Create;
  Result.Add('id', AId);
  Result.Add('source_sha256', AHash);
  Result.Add('start_frame', AStart);
  Result.Add('end_frame', AEnd);
  Result.Add('question', 'Source-free question for ' + AFacet);
  Result.Add('label_type', AType);
  Result.Add('answer_geometry', AGeometry);
  LSpec := TJSONObject.Create;
  Result.Add('answer_spec', LSpec);
  LSpec.Add('facet', AFacet);
  LValues := TJSONArray.Create;
  LSpec.Add('vocabulary', LValues);
  for LIndex := Low(AValues) to High(AValues) do
    LValues.Add(AValues[LIndex]);
  LSpec.Add('links', ALinks);
  LSpec.Add('proposal_id', AProposal);
end;

function Change(const AId, AType, AValue, AStatus,
  AProposal: String; const AStart, AEnd: Int64;
  const AStructured: Boolean): TJSONObject;
begin
  Result := TJSONObject.Create;
  Result.Add('label_id', AId);
  Result.Add('type', AType);
  Result.Add('value', AValue);
  Result.Add('status', AStatus);
  Result.Add('start_frame', AStart);
  Result.Add('end_frame', AEnd);
  Result.Add('part', '');
  Result.Add('proposal_id', AProposal);
  if AStructured then
    Result.Add('extension_version', 2);
end;

procedure Commit(const ACatalog, AHash: String; const ARevision: Integer;
  AChange: TJSONObject; const ARequestHash: String);
var
  LTransaction: TJSONObject;
  LEvent: TJSONObject;
begin
  LTransaction := TJSONObject.Create;
  try
    if ARequestHash = '' then
      LTransaction.Add('version', 1)
    else
    begin
      LTransaction.Add('version', 2);
      LTransaction.Add('request_id', AChange.Strings['label_id']);
      LTransaction.Add('request_sha256', ARequestHash);
    end;
    LTransaction.Add('source_sha256', AHash);
    LTransaction.Add('expected_revision', ARevision);
    LTransaction.Add('reviewer', 'contract-fixture');
    LTransaction.Add('change', AChange);
    LEvent := CommitCatalogReview(ACatalog, LTransaction);
    try
      Need(LEvent.Integers['revision'] = ARevision + 1,
        'review revision did not advance');
    finally
      LEvent.Free;
    end;
  finally
    LTransaction.Free;
  end;
end;

function QueueHash(const AReport: TJSONObject; const AId: String): String;
var
  LRows: TJSONArray;
  LIndex: Integer;
begin
  LRows := AReport.Arrays['items'];
  for LIndex := 0 to LRows.Count - 1 do
    if LRows.Objects[LIndex].Strings['id'] = AId then
      Exit(LRows.Objects[LIndex].Strings['request_sha256']);
  raise Exception.Create('Queue request hash is missing: ' + AId);
end;

var
  LRoot: String;
  LCatalog: String;
  LCatalogReplay: String;
  LHash: String;
  LProposalPacket: TJSONObject;
  LProposalIds: TJSONArray;
  LQueue: TJSONObject;
  LItems: TJSONArray;
  LLinks: TJSONArray;
  LReport: TJSONObject;
  LPacket: TJSONObject;
  LRebuilt: TJSONObject;
  LReplay: TJSONObject;
  LBad: TJSONObject;
  LPath: String;
  LOldHash: String;
  LBlindRoot: String;
  LBlindCatalog: String;
  LBlindHash: String;
  LIndex: Integer;
  LNoKeyFound: Boolean;
begin
  Need(ParamCount = 1, 'Usage: contract-fixture BUILD_DIR');
  LRoot := ExpandFileName(ParamStr(1));
  Need(ForceDirectories(LRoot), 'fixture root');
  LCatalog := IncludeTrailingPathDelimiter(LRoot) + 'catalog';
  LCatalogReplay := IncludeTrailingPathDelimiter(LRoot) + 'replay';
  LHash := PrepareSource(LRoot);
  Commit(LCatalog, LHash, 0,
    Change('part_anchor', 'part_role', 'drums', 'approved', '',
      100, 500, False), '');
  Commit(LCatalog, LHash, 1,
    Change('phrase_anchor', 'phrase', 'A', 'approved', '',
      600, 1200, False), '');
  LPacket := BuildReviewedCatalogPacket(LCatalog);
  try
    Need((LPacket.Integers['version'] = 1) and
      (LPacket.Strings['policy'] = 'pythian.reviewed-catalog.v1'),
      'v1-only packet changed version');
    WriteJson(IncludeTrailingPathDelimiter(LRoot) + 'packet-v1.json',
      LPacket);
  finally
    LPacket.Free;
  end;
  LProposalPacket := PublishCatalogBeatProposals(LCatalog, LHash,
    0, 8000);
  try
    Need(LProposalPacket.Arrays['candidates'].Count >= 2,
      'source-free pulse needs two proposal alternatives');
    LProposalIds := TJSONArray.Create;
    LProposalIds.Add(LProposalPacket.Arrays['candidates'].Objects[0]
      .Strings['proposal_id']);
    LProposalIds.Add(LProposalPacket.Arrays['candidates'].Objects[1]
      .Strings['proposal_id']);
  finally
    LProposalPacket.Free;
  end;
  LQueue := TJSONObject.Create;
  try
    LQueue.Add('version', 2);
    LItems := TJSONArray.Create;
    LQueue.Add('items', LItems);
    LLinks := TJSONArray.Create;
    LLinks.Add(Link('label', 'role', LHash, 'part_anchor', 'part_role', 1));
    LItems.Add(Item('groove_answer', LHash, 'ext.groove_trait',
      'velocity_relation', 'contained', '', 100, 600,
      ['stronger', 'weaker', 'unknown'], LLinks));
    LLinks := TJSONArray.Create;
    LLinks.Add(Link('label', 'motif', LHash,
      'phrase_anchor', 'phrase', 2));
    LItems.Add(Item('motif_answer', LHash, 'ext.motif_relation',
      'variation', 'contained', '', 600, 1300,
      ['varied', 'repeated', 'unknown'], LLinks));
    LItems.Add(Item('omission_answer', LHash, 'ext.pulse_evidence',
      'omission', 'point', '', 1500, 1800,
      ['omitted', 'present', 'unknown'], TJSONArray.Create));
    LLinks := TJSONArray.Create;
    LLinks.Add(Link('proposal', 'alternative_a', LHash,
      LProposalIds.Strings[0], ''));
    LLinks.Add(Link('proposal', 'alternative_b', LHash,
      LProposalIds.Strings[1], ''));
    LItems.Add(Item('phase_answer', LHash, 'ext.pulse_evidence',
      'phase_rate', 'contained', '', 2000, 3000,
      ['phase_a', 'phase_b', 'unknown'], LLinks));
    LItems.Add(Item('reject_answer', LHash, 'ext.pulse_evidence',
      'clock_gap', 'contained', LProposalIds.Strings[0], 3000, 4000,
      ['gap', 'continuous', 'unknown'], TJSONArray.Create));
    LItems.Add(Item('key_answer', LHash, 'key', 'key', 'exact', '',
      4100, 4500, ['C:major', 'no_key', 'unknown'], TJSONArray.Create));
    LItems.Add(Item('note_answer', LHash, 'note', 'note', 'contained', '',
      4600, 5000, ['C4', 'unknown'], TJSONArray.Create));
    LItems.Objects[6].Objects['answer_spec'].Add('pitch_midi_values',
      TJSONArray.Create([60]));
    LItems.Objects[6].Objects['answer_spec'].Add('part_vocabulary',
      TJSONArray.Create(['piano']));
    LPath := IncludeTrailingPathDelimiter(LRoot) + 'queue-v2.json';
    WriteJson(LPath, LQueue);
    LReport := PublishReviewQueue(LCatalog, LPath);
    try
      Need((LReport.Integers['version'] = 2) and
        (LReport.Arrays['items'].Count = 7), 'v2 queue publication');
      LOldHash := QueueHash(LReport, 'groove_answer');
    finally
      LReport.Free;
    end;
    LBad := TJSONObject(LQueue.Clone);
    try
      LBad.Arrays['items'].Objects[0].Objects['answer_spec']
        .Arrays['links'].Objects[0].Strings['target_id'] := 'missing';
      WriteJson(IncludeTrailingPathDelimiter(LRoot) +
        'queue-invalid.json', LBad);
      try
        LReport := PublishReviewQueue(LCatalog,
          IncludeTrailingPathDelimiter(LRoot) + 'queue-invalid.json');
        LReport.Free;
        Need(False, 'invalid queue replacement was accepted');
      except
        on EReviewQueue do
          Writeln('EXPECTED invalid queue replacement');
      end;
    finally
      LBad.Free;
    end;
  finally
    LQueue.Free;
    LProposalIds.Free;
  end;
  LReport := ReadReviewQueue(LCatalog);
  try
    Need(QueueHash(LReport, 'groove_answer') = LOldHash,
      'invalid publication replaced queue');
    try
      Commit(LCatalog, LHash, 2,
        Change('groove_answer', 'ext.groove_trait', 'made_up',
          'approved', '', 150, 500, True), LOldHash);
      Need(False, 'undeclared value was accepted');
    except
      on EAnswerContract do
        Writeln('EXPECTED undeclared value');
    end;
    LBad := ReadCatalogReviewHistory(LCatalog, LHash, 1, 16);
    try
      Need(LBad.Integers['revision'] = 2,
        'invalid review advanced revision');
    finally
      LBad.Free;
    end;
    Commit(LCatalog, LHash, 2,
      Change('groove_answer', 'ext.groove_trait', 'stronger',
        'approved', '', 150, 500, True), LOldHash);
    Commit(LCatalog, LHash, 3,
      Change('motif_answer', 'ext.motif_relation', 'unknown',
        'approved', '', 700, 1200, True),
      QueueHash(LReport, 'motif_answer'));
    Commit(LCatalog, LHash, 4,
      Change('omission_answer', 'ext.pulse_evidence', 'omitted',
        'approved', '', 1600, 1601, True),
      QueueHash(LReport, 'omission_answer'));
    Commit(LCatalog, LHash, 5,
      Change('phase_answer', 'ext.pulse_evidence', 'phase_a',
        'approved', '', 2100, 2800, True),
      QueueHash(LReport, 'phase_answer'));
    Commit(LCatalog, LHash, 6,
      Change('reject_answer', 'ext.pulse_evidence', 'gap',
        'rejected', LReport.Arrays['items'].Objects[4]
          .Objects['answer_spec'].Strings['proposal_id'],
        3100, 3900, True), QueueHash(LReport, 'reject_answer'));
    Commit(LCatalog, LHash, 7,
      Change('key_answer', 'key', 'no_key', 'approved', '',
        4100, 4500, False), QueueHash(LReport, 'key_answer'));
    LBad := Change('note_answer', 'note', 'C4', 'approved', '',
      4700, 4800, False);
    LBad.Add('pitch_midi', 60);
    LBad.Strings['part'] := 'violin';
    try
      Commit(LCatalog, LHash, 8, LBad,
        QueueHash(LReport, 'note_answer'));
      Need(False, 'undeclared part was accepted');
    except
      on EAnswerContract do
        Writeln('EXPECTED undeclared part');
    end;
    LBad := Change('note_answer', 'note', 'C4', 'approved', '',
      4700, 4800, False);
    LBad.Add('pitch_midi', 60);
    LBad.Strings['part'] := 'piano';
    Commit(LCatalog, LHash, 8, LBad,
      QueueHash(LReport, 'note_answer'));
  finally
    LReport.Free;
  end;
  LReport := ReadReviewQueue(LCatalog);
  try
    Need((LReport.Arrays['items'].Count = 0) and
      (LReport.Arrays['completed'].Count = 7),
      'v2 completed queue differs');
  finally
    LReport.Free;
  end;
  try
    Commit(LCatalog, LHash, 9,
      Change('groove_answer', 'ext.groove_trait', 'weaker',
        'approved', '', 150, 500, True), '');
    Need(False, 'v1 transaction downgraded a structured answer');
  except
    on EAudio do
      Writeln('EXPECTED structured downgrade rejected');
  end;
  LBad := ReadCatalogReviewHistory(LCatalog, LHash, 1, 16);
  try
    Need(LBad.Integers['revision'] = 9,
      'structured downgrade advanced revision');
  finally
    LBad.Free;
  end;
  LPacket := BuildReviewedCatalogPacket(LCatalog);
  try
    Need((LPacket.Integers['version'] = 2) and
      (LPacket.Arrays['tracks'].Objects[0]
        .Arrays['selected_labels'].Count = 7) and
      (LPacket.Arrays['tracks'].Objects[0]
        .Arrays['unknown_labels'].Count = 1),
      'mixed packet selected/unknown split');
    LNoKeyFound := False;
    for LIndex := 0 to LPacket.Arrays['tracks'].Objects[0]
      .Arrays['selected_labels'].Count - 1 do
      if (LPacket.Arrays['tracks'].Objects[0]
        .Arrays['selected_labels'].Objects[LIndex].Strings['label_id'] =
        'key_answer') and
        (LPacket.Arrays['tracks'].Objects[0]
          .Arrays['selected_labels'].Objects[LIndex].Strings['value'] =
          'no_key') then
        LNoKeyFound := True;
    Need(LNoKeyFound,
      'reviewed no-key was not selected separately from unknown');
    WriteJson(IncludeTrailingPathDelimiter(LRoot) + 'packet-v2.json',
      LPacket);
    LReport := ImportLabelInbox(
      IncludeTrailingPathDelimiter(LRoot) + 'inbox', LCatalogReplay);
    LReport.Free;
    LReplay := ReplayReviewedCatalogText(LCatalogReplay,
      LPacket.AsJSON);
    try
      Need(LReplay.Strings['status'] = 'imported',
        'v2 clean replay did not import');
    finally
      LReplay.Free;
    end;
    LRebuilt := BuildReviewedCatalogPacket(LCatalogReplay);
    try
      Need(LRebuilt.AsJSON = LPacket.AsJSON,
        'v2 replay changed packet bytes');
    finally
      LRebuilt.Free;
    end;
  finally
    LPacket.Free;
  end;
  Commit(LCatalog, LHash, 9,
    Change('part_anchor', 'part_role', 'drums', 'withdrawn', '',
      100, 500, False), '');
  try
    LBad := BuildReviewedCatalogPacket(LCatalog);
    LBad.Free;
    Need(False, 'withdrawn link entered selected export');
  except
    on EAudio do
      Writeln('EXPECTED withdrawn link blocks selected export');
  end;
  LBlindRoot := IncludeTrailingPathDelimiter(LRoot) + 'blind';
  LBlindCatalog := IncludeTrailingPathDelimiter(LBlindRoot) + 'catalog';
  LBlindHash := PrepareSource(LBlindRoot, 'evaluation');
  LQueue := TJSONObject.Create;
  try
    LQueue.Add('version', 2);
    LItems := TJSONArray.Create;
    LQueue.Add('items', LItems);
    LItems.Add(Item('blind_leak', LBlindHash,
      'ext.pulse_evidence', 'clock_gap', 'exact', 'proposal_hidden',
      100, 500, ['gap', 'unknown'], TJSONArray.Create));
    LPath := IncludeTrailingPathDelimiter(LBlindRoot) +
      'blind-leak-queue.json';
    WriteJson(LPath, LQueue);
    try
      LReport := PublishReviewQueue(LBlindCatalog, LPath);
      LReport.Free;
      Need(False, 'blind evaluation proposal binding was published');
    except
      on EReviewQueue do
        Writeln('EXPECTED blind proposal request rejected');
    end;
    Need(not FileExists(IncludeTrailingPathDelimiter(LBlindCatalog) +
      'review-queue.json'), 'blind publication created a queue');
  finally
    LQueue.Free;
  end;
  Writeln('PASS source=', LHash,
    ' v1-only, v2 queue/review/export/replay, negative preservation');
end.
