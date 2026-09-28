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
program pythian_tests_listen_catalog;

{$mode delphi}
{$H+}

uses
  Classes,
  SysUtils,
  fpjson,
  jsonparser,
  pythian.audio,
  pythian.hash,
  pythian.wave.stream,
  pythian.tools.annotations.catalog,
  pythian.tools.listen.catalog;

const
  CLegacyExportSha256 =
    '79f465907dbb16b97b5944d133adad360feff9b7088410781206c0259b617142';

procedure Need(const ACondition: Boolean; const AMessage: String);
begin
  if not ACondition then
  begin
    raise Exception.Create(AMessage);
  end;
end;

procedure WriteJson(const APath: String; const AData: TJSONObject);
var
  LStream: TFileStream;
  LText: String;
begin
  LText := AData.AsJSON + LineEnding;
  LStream := TFileStream.Create(APath, fmCreate);
  try
    LStream.WriteBuffer(LText[1], Length(LText));
  finally
    LStream.Free;
  end;
end;

function FileHash(const APath: String): String; forward;

procedure ExpectBadPublish(const ACatalog, APath: String;
  const AQueue: TJSONObject; const AReason: String;
  const AExpectedError: String = '');
var
  LBefore: String;
  LFailed: Boolean;
  LReport: TJSONObject;
begin
  LBefore := FileHash(IncludeTrailingPathDelimiter(ACatalog) +
    'listening' + PathDelim + 'queue.json');
  WriteJson(APath, AQueue);
  LFailed := False;
  try
    LReport := PublishListeningQueue(ACatalog, APath);
    LReport.Free;
  except
    on E: Exception do
      LFailed := (AExpectedError = '') or
        (Pos(AExpectedError, E.Message) > 0);
  end;
  Need(LFailed, 'invalid publish accepted: ' + AReason);
  Need(FileHash(IncludeTrailingPathDelimiter(ACatalog) +
    'listening' + PathDelim + 'queue.json') = LBefore,
    'invalid publish changed prior queue: ' + AReason);
end;

function FileHash(const APath: String): String;
var
  LStream: TFileStream;
begin
  LStream := TFileStream.Create(APath, fmOpenRead);
  try
    Result := Sha256Stream(LStream, LStream.Size);
  finally
    LStream.Free;
  end;
end;

function FileBytes(const APath: String): Int64;
var
  LStream: TFileStream;
begin
  LStream := TFileStream.Create(APath, fmOpenRead);
  try
    Result := LStream.Size;
  finally
    LStream.Free;
  end;
end;

function ReadJson(const APath: String): TJSONObject;
var
  LStream: TFileStream;
  LText: String;
  LData: TJSONData;
begin
  LStream := TFileStream.Create(APath, fmOpenRead);
  try
    SetLength(LText, Integer(LStream.Size));
    LStream.ReadBuffer(LText[1], Length(LText));
  finally
    LStream.Free;
  end;
  LData := GetJSON(LText);
  Need(LData.JSONType = jtObject, 'test JSON must be object');
  Result := TJSONObject(LData);
end;

procedure WriteWave(const APath: String; const AFrames,
  ASampleRate: Integer);
var
  LSamples: TAudioSamples;
  LClip: TAudioClip;
  LStream: TFileStream;
  I: Integer;
begin
  SetLength(LSamples, AFrames);
  for I := 0 to High(LSamples) do
  begin
    if I mod 100 < 20 then
    begin
      LSamples[I] := 0.5;
    end
    else
    begin
      LSamples[I] := 0;
    end;
  end;
  LClip := TAudioClip.Create(ASampleRate, 1, LSamples);
  try
    LStream := TFileStream.Create(APath, fmCreate);
    try
      WriteWavePcm16(LStream, LClip);
    finally
      LStream.Free;
    end;
  finally
    LClip.Free;
  end;
end;

procedure ImportSource(const AInbox, ACatalog: String;
  const AHash: String);
var
  LManifest: TJSONObject;
  LTracks: TJSONArray;
  LTrack: TJSONObject;
  LReport: TJSONObject;
begin
  LManifest := TJSONObject.Create;
  try
    LManifest.Add('version', 1);
    LTracks := TJSONArray.Create;
    LManifest.Add('tracks', LTracks);
    LTrack := TJSONObject.Create;
    LTracks.Add(LTrack);
    LTrack.Add('file', 'source.wav');
    LTrack.Add('sha256', AHash);
    LTrack.Add('source_group', 'listen_control');
    LTrack.Add('clock_id', 'source_clock');
    LTrack.Add('partition', 'development');
    LTrack.Add('title', 'Pascal source control');
    LTrack.Add('provenance', 'Pascal authored source-free fixture');
    LTrack.Add('license', 'MIT');
    WriteJson(IncludeTrailingPathDelimiter(AInbox) + 'manifest.json',
      LManifest);
  finally
    LManifest.Free;
  end;
  LReport := ImportLabelInbox(AInbox, ACatalog);
  try
    Need((LReport.Integers['imported'] = 1) and
      (LReport.Integers['failed'] = 0), 'source import failed');
  finally
    LReport.Free;
  end;
end;

function Asset(const AId, AStorage, AHash, ARole: String;
  const ABytes, AFrames: Int64; const ASourceHash: String): TJSONObject;
var
  LProvenance: TJSONObject;
begin
  Result := TJSONObject.Create;
  Result.Add('id', AId);
  Result.Add('storage', AStorage);
  Result.Add('sha256', AHash);
  Result.Add('role', ARole);
  Result.Add('bytes', ABytes);
  Result.Add('sample_rate', 48000);
  Result.Add('channels', 1);
  Result.Add('frames', AFrames);
  LProvenance := TJSONObject.Create;
  Result.Add('provenance', LProvenance);
  LProvenance.Add('source_sha256', ASourceHash);
  if AStorage = 'source' then
  begin
    LProvenance.Add('source_group', 'listen_control');
    LProvenance.Add('clock_id', 'source_clock');
    LProvenance.Add('partition', 'development');
  end
  else
  begin
    LProvenance.Add('model_sha256', StringOfChar('a', 64));
    LProvenance.Add('policy_sha256', StringOfChar('b', 64));
    LProvenance.Add('parameter_sha256', StringOfChar('c', 64));
    LProvenance.Add('split', 'development');
    LProvenance.Add('seed', 731);
  end;
end;

function Range(const AAssetId: String; const AStart, AEnd: Int64): TJSONObject;
begin
  Result := TJSONObject.Create;
  Result.Add('asset_id', AAssetId);
  Result.Add('start_frame', AStart);
  Result.Add('end_frame', AEnd);
end;

function Spec: TJSONObject;
var
  LChoices: TJSONArray;
  LScores: TJSONArray;
  LChoice: TJSONObject;
  LValues: TJSONArray;
  LScore: TJSONObject;
begin
  Result := TJSONObject.Create;
  LChoices := TJSONArray.Create;
  Result.Add('choices', LChoices);
  LChoice := TJSONObject.Create;
  LChoices.Add(LChoice);
  LChoice.Add('id', 'fit');
  LValues := TJSONArray.Create;
  LChoice.Add('values', LValues);
  LValues.Add('yes');
  LValues.Add('no');
  LValues.Add('unknown');
  LScores := TJSONArray.Create;
  Result.Add('scores', LScores);
  LScore := TJSONObject.Create;
  LScore.Add('id', 'usefulness');
  LScores.Add(LScore);
end;

function Request(const AId, AKind: String; const ASource,
  AGenerated: TJSONObject): TJSONObject;
var
  LAssets: TJSONArray;
  LRanges: TJSONArray;
begin
  Result := TJSONObject.Create;
  Result.Add('id', AId);
  Result.Add('task_id', 'NS-5_evaluation_03');
  Result.Add('kind', AKind);
  Result.Add('question', 'Does this fixed authored fixture meet its prompt?');
  LAssets := TJSONArray.Create;
  Result.Add('assets', LAssets);
  LAssets.Add(ASource.Clone);
  LRanges := TJSONArray.Create;
  Result.Add('ranges', LRanges);
  LRanges.Add(Range('source', 0, ASource.Int64s['frames']));
  if AKind = 'pair' then
  begin
    LAssets.Add(AGenerated.Clone);
    LRanges.Add(Range('generated', 0, AGenerated.Int64s['frames']));
  end;
  Result.Add('answer_spec', Spec);
end;

function EvidenceReference(const AId, AHash: String): TJSONObject;
begin
  Result := TJSONObject.Create;
  Result.Add('evidence_id', AId);
  Result.Add('evidence_sha256', AHash);
end;

function CorrespondenceRequest(const ASource,
  AGenerated: TJSONObject): TJSONObject;
var
  LEvidence: TJSONObject;
begin
  Result := Request('correspondence_control', 'pair', ASource, AGenerated);
  Result.Add('purpose', 'source_correspondence');
  LEvidence := TJSONObject.Create;
  Result.Add('correspondence_evidence', LEvidence);
  LEvidence.Add('subject_asset_id', 'source');
  LEvidence.Add('recording', EvidenceReference('recording_audit',
    StringOfChar('a', 64)));
  LEvidence.Add('edition', EvidenceReference('edition_audit',
    StringOfChar('b', 64)));
  LEvidence.Add('cut', EvidenceReference('cut_audit',
    StringOfChar('c', 64)));
end;

function QueueAssetProvenance(const AQueue: TJSONObject;
  const AItem, AAsset: Integer): TJSONObject;
begin
  Result := TJSONObject(TJSONObject(AQueue.Arrays['items'].Items[AItem]).
    Arrays['assets'].Items[AAsset]).Objects['provenance'];
end;

function MultiHashes(const AFirst: String): TJSONArray;
begin
  Result := TJSONArray.Create;
  Result.Add(AFirst);
  Result.Add(StringOfChar('d', 64));
  Result.Add(StringOfChar('e', 64));
end;

function Answer(const AId, AValue: String): TJSONObject;
begin
  Result := TJSONObject.Create;
  Result.Add('id', AId);
  Result.Add('value', AValue);
end;

function Transaction(const AId, AHash, AStatus, AChoice: String;
  const ARevision: Integer): TJSONObject;
var
  LChoices: TJSONArray;
  LScores: TJSONArray;
  LComments: TJSONArray;
  LComment: TJSONObject;
  LScore: TJSONObject;
begin
  Result := TJSONObject.Create;
  Result.Add('version', 1);
  Result.Add('request_id', AId);
  Result.Add('request_sha256', AHash);
  Result.Add('expected_revision', ARevision);
  Result.Add('reviewer', 'fixture_operator');
  Result.Add('status', AStatus);
  LChoices := TJSONArray.Create;
  Result.Add('choices', LChoices);
  LScores := TJSONArray.Create;
  Result.Add('scores', LScores);
  LComments := TJSONArray.Create;
  Result.Add('comments', LComments);
  if AStatus = 'submitted' then
  begin
    LChoices.Add(Answer('fit', AChoice));
    LScore := TJSONObject.Create;
    LScore.Add('id', 'usefulness');
    LScore.Add('value', 2);
    LScores.Add(LScore);
    LComment := TJSONObject.Create;
    LComment.Add('asset_id', 'source');
    LComment.Add('frame', 500);
    LComment.Add('text', 'Authored test timestamp');
    LComments.Add(LComment);
  end;
end;

var
  LRoot: String;
  LInbox: String;
  LCatalog: String;
  LReplayCatalog: String;
  LBadReplayCatalog: String;
  LCorrespondenceReplayCatalog: String;
  LSourcePath: String;
  LGeneratedPath: String;
  LLowPath: String;
  LLowHash: String;
  LInput: TFileStream;
  LOutput: TFileStream;
  LSourceHash: String;
  LGeneratedHash: String;
  LSource: TJSONObject;
  LGenerated: TJSONObject;
  LQueue: TJSONObject;
  LItems: TJSONArray;
  LReport: TJSONObject;
  LTransaction: TJSONObject;
  LEvent: TJSONObject;
  LExportPath: String;
  LExportReplayPath: String;
  LBadExportPath: String;
  LFailed: Boolean;
  LBadQueue: TJSONObject;
  LBadTransaction: TJSONObject;
  LBadPacket: TJSONObject;
  LCorrespondenceQueue: TJSONObject;
  LCorrespondenceRequest: TJSONObject;
  LCorrespondenceExportPath: String;
  LCorrespondenceReplayPath: String;
  LMultiQueue: TJSONObject;
  LMultiGenerated, LMultiEdited: TJSONObject;
  LMultiReplayCatalog, LMultiExportPath, LMultiReplayPath: String;
  LProvenance: TJSONObject;
  LHashes: TJSONArray;
  I, J: Integer;
  LSearch: TSearchRec;
begin
  Need(ParamCount = 1, 'expected isolated output directory');
  LRoot := ExpandFileName(ParamStr(1));
  Need(not DirectoryExists(LRoot), 'fixture directory already exists');
  Need(ForceDirectories(LRoot), 'cannot create fixture directory');
  LInbox := LRoot + PathDelim + 'inbox';
  LCatalog := LRoot + PathDelim + 'catalog';
  LReplayCatalog := LRoot + PathDelim + 'replay';
  LBadReplayCatalog := LRoot + PathDelim + 'bad-replay';
  LCorrespondenceReplayCatalog := LRoot + PathDelim +
    'correspondence-replay';
  Need(ForceDirectories(LInbox), 'cannot create inbox');
  LSourcePath := LInbox + PathDelim + 'source.wav';
  LGeneratedPath := LRoot + PathDelim + 'generated.wav';
  LLowPath := LRoot + PathDelim + 'unsupported-1000hz.wav';
  WriteWave(LSourcePath, 48000, 48000);
  WriteWave(LGeneratedPath, 5760000, 48000);
  WriteWave(LLowPath, 1000, 1000);
  LSourceHash := FileHash(LSourcePath);
  LGeneratedHash := FileHash(LGeneratedPath);
  LLowHash := FileHash(LLowPath);
  ImportSource(LInbox, LCatalog, LSourceHash);
  ImportSource(LInbox, LReplayCatalog, LSourceHash);
  ImportSource(LInbox, LBadReplayCatalog, LSourceHash);
  LFailed := False;
  try
    LReport := StageListeningAsset(LCatalog, LLowPath);
    LReport.Free;
  except
    on E: Exception do
      LFailed := Pos('below 8000 Hz', E.Message) > 0;
  end;
  Need(LFailed and not FileExists(LCatalog + PathDelim + 'listening' +
    PathDelim + 'assets' + PathDelim + LLowHash + '.wav'),
    '1 kHz WAV was staged despite browser intake guard');
  LReport := StageListeningAsset(LCatalog, LGeneratedPath);
  LReport.Free;
  LReport := StageListeningAsset(LReplayCatalog, LGeneratedPath);
  LReport.Free;
  LReport := StageListeningAsset(LBadReplayCatalog, LGeneratedPath);
  LReport.Free;
  LSource := Asset('source', 'source', LSourceHash, 'source',
    FileBytes(LSourcePath), 48000, LSourceHash);
  LGenerated := Asset('generated', 'listening', LGeneratedHash,
    'generated', FileBytes(LGeneratedPath), 5760000, LSourceHash);
  LQueue := TJSONObject.Create;
  try
    LQueue.Add('version', 1);
    LItems := TJSONArray.Create;
    LQueue.Add('items', LItems);
    LItems.Add(Request('single_control', 'single', LSource, LGenerated));
    LItems.Add(Request('pair_control', 'pair', LSource, LGenerated));
    WriteJson(LRoot + PathDelim + 'queue.json', LQueue);
    LReport := PublishListeningQueue(LCatalog,
      LRoot + PathDelim + 'queue.json');
    try
      Need((LReport.Integers['waiting_count'] = 2) and
        (LReport.Integers['completed_count'] = 0),
        'initial queue counts');
      LBadQueue := TJSONObject(LQueue.Clone);
      try
        TJSONObject(TJSONObject(LBadQueue.Arrays['items'].Items[0]).
          Arrays['assets'].Items[0]).Strings['sha256'] := StringOfChar('0', 64);
        ExpectBadPublish(LCatalog, LRoot + PathDelim + 'bad-queue.json',
          LBadQueue, 'wrong source hash');
      finally
        LBadQueue.Free;
      end;
      LBadQueue := TJSONObject(LQueue.Clone);
      try
        TJSONObject(TJSONObject(LBadQueue.Arrays['items'].Items[0]).
          Arrays['assets'].Items[0]).Add('path', '..' + PathDelim +
          'escaped.wav');
        ExpectBadPublish(LCatalog, LRoot + PathDelim + 'bad-queue.json',
          LBadQueue, 'arbitrary asset path');
      finally
        LBadQueue.Free;
      end;
      LBadQueue := TJSONObject(LQueue.Clone);
      try
        TJSONObject(TJSONObject(LBadQueue.Arrays['items'].Items[0]).
          Arrays['ranges'].Items[0]).Int64s['end_frame'] := 48001;
        ExpectBadPublish(LCatalog, LRoot + PathDelim + 'bad-queue.json',
          LBadQueue, 'out-of-asset range');
      finally
        LBadQueue.Free;
      end;
      LBadQueue := TJSONObject(LQueue.Clone);
      try
        TJSONObject(TJSONObject(LBadQueue.Arrays['items'].Items[0]).
          Arrays['assets'].Items[0]).Objects['provenance'].
          Strings['source_group'] := 'wrong_group';
        ExpectBadPublish(LCatalog, LRoot + PathDelim + 'bad-queue.json',
          LBadQueue, 'wrong imported source group');
      finally
        LBadQueue.Free;
      end;
      LBadQueue := TJSONObject(LQueue.Clone);
      try
        TJSONObject(TJSONObject(LBadQueue.Arrays['items'].Items[0]).
          Objects['answer_spec'].Arrays['choices'].Items[0]).
          Arrays['values'].Strings[2] := 'maybe';
        ExpectBadPublish(LCatalog, LRoot + PathDelim + 'bad-queue.json',
          LBadQueue, 'choice vocabulary without unknown');
      finally
        LBadQueue.Free;
      end;
      { Bypass the public stage operation only in this negative fixture to
        prove publish also rejects a parseable 1 kHz WAV by rate. }
      LInput := TFileStream.Create(LLowPath, fmOpenRead);
      try
        LOutput := TFileStream.Create(LCatalog + PathDelim + 'listening' +
          PathDelim + 'assets' + PathDelim + LLowHash + '.wav', fmCreate);
        try
          LOutput.CopyFrom(LInput, LInput.Size);
        finally
          LOutput.Free;
        end;
      finally
        LInput.Free;
      end;
      LBadQueue := TJSONObject(LQueue.Clone);
      try
        with TJSONObject(TJSONObject(LBadQueue.Arrays['items'].Items[1]).
          Arrays['assets'].Items[1]) do
        begin
          Strings['sha256'] := LLowHash;
          Int64s['bytes'] := FileBytes(LLowPath);
          Integers['sample_rate'] := 1000;
          Int64s['frames'] := 1000;
        end;
        TJSONObject(TJSONObject(LBadQueue.Arrays['items'].Items[1]).
          Arrays['ranges'].Items[1]).Int64s['end_frame'] := 1000;
        ExpectBadPublish(LCatalog, LRoot + PathDelim + 'bad-queue.json',
          LBadQueue, '1 kHz published asset', 'below 8000 Hz');
      finally
        LBadQueue.Free;
      end;
      LTransaction := Transaction('single_control',
        TJSONObject(LReport.Arrays['items'].Items[0]).Strings['request_sha256'],
        'submitted', 'yes', 0);
    finally
      LReport.Free;
    end;
    try
      LBadTransaction := TJSONObject(LTransaction.Clone);
      try
        LBadTransaction.Strings['request_sha256'] := StringOfChar('0', 64);
        LFailed := False;
        try
          LEvent := CommitListeningReview(LCatalog, LBadTransaction);
          LEvent.Free;
        except
          LFailed := True;
        end;
        Need(LFailed, 'wrong request hash accepted');
      finally
        LBadTransaction.Free;
      end;
      LBadTransaction := TJSONObject(LTransaction.Clone);
      try
        LBadTransaction.Strings['reviewer'] := '';
        LFailed := False;
        try
          LEvent := CommitListeningReview(LCatalog, LBadTransaction);
          LEvent.Free;
        except
          LFailed := True;
        end;
        Need(LFailed, 'empty reviewer accepted');
      finally
        LBadTransaction.Free;
      end;
      LBadTransaction := TJSONObject(LTransaction.Clone);
      try
        TJSONObject(LBadTransaction.Arrays['comments'].Items[0]).
          Int64s['frame'] := 48000;
        LFailed := False;
        try
          LEvent := CommitListeningReview(LCatalog, LBadTransaction);
          LEvent.Free;
        except
          LFailed := True;
        end;
        Need(LFailed, 'out-of-range comment accepted');
      finally
        LBadTransaction.Free;
      end;
      LBadTransaction := TJSONObject(LTransaction.Clone);
      try
        LBadTransaction.Arrays['scores'].Delete(0);
        LFailed := False;
        try
          LEvent := CommitListeningReview(LCatalog, LBadTransaction);
          LEvent.Free;
        except
          LFailed := True;
        end;
        Need(LFailed, 'incomplete submitted rubric accepted');
      finally
        LBadTransaction.Free;
      end;
      LEvent := CommitListeningReview(LCatalog, LTransaction);
      Need(LEvent.Integers['revision'] = 1, 'first event revision');
      LEvent.Free;
      LEvent := CommitListeningReview(LCatalog, LTransaction);
      Need(LEvent.Booleans['already_saved'],
        'lost-response retry must deduplicate');
      LEvent.Free;
      TJSONObject(LTransaction.Arrays['choices'].Items[0]).Strings['value'] := 'no';
      LFailed := False;
      try
        LEvent := CommitListeningReview(LCatalog, LTransaction);
        LEvent.Free;
      except
        LFailed := True;
      end;
      Need(LFailed, 'stale correction must reject');
      TJSONObject(LTransaction.Arrays['choices'].Items[0]).Strings['value'] :=
        'outside_vocabulary';
      LTransaction.Integers['expected_revision'] := 1;
      LFailed := False;
      try
        LEvent := CommitListeningReview(LCatalog, LTransaction);
        LEvent.Free;
      except
        LFailed := True;
      end;
      Need(LFailed, 'invalid value must reject');
    finally
      LTransaction.Free;
    end;
    LReport := ReadListeningQueue(LCatalog);
    try
      Need((LReport.Integers['waiting_count'] = 1) and
        (LReport.Integers['completed_count'] = 1),
        'saved queue counts');
      LTransaction := Transaction('pair_control',
        TJSONObject(LReport.Arrays['items'].Items[0]).Strings['request_sha256'],
        'withdrawn', '', 0);
    finally
      LReport.Free;
    end;
    try
      LEvent := CommitListeningReview(LCatalog, LTransaction);
      LEvent.Free;
      LTransaction.Free;
    except
      LTransaction.Free;
      raise;
    end;
    LReport := ReadListeningQueue(LCatalog);
    try
      Need((LReport.Integers['waiting_count'] = 1) and
        (LReport.Integers['completed_count'] = 1),
        'withdrawn answer remains pending');
      LTransaction := Transaction('pair_control',
        TJSONObject(LReport.Arrays['items'].Items[0]).Strings['request_sha256'],
        'submitted', 'unknown', 1);
      TJSONObject(LTransaction.Arrays['scores'].Items[0]).
        Strings['value'] := 'unknown';
    finally
      LReport.Free;
    end;
    try
      LEvent := CommitListeningReview(LCatalog, LTransaction);
      Need(LEvent.Integers['revision'] = 2,
        'submitted pair revision');
      LEvent.Free;
    finally
      LTransaction.Free;
    end;
    LReport := ReadListeningQueue(LCatalog);
    Need((LReport.Integers['waiting_count'] = 0) and
      (LReport.Integers['completed_count'] = 2),
      'all submitted queue counts');
    Need(TJSONObject(TJSONObject(LReport.Arrays['completed'].Items[1]).
      Arrays['current_scores'].Items[0]).Strings['value'] = 'unknown',
      'unknown rubric must remain distinct from zero');
    LReport.Free;
    LExportPath := LRoot + PathDelim + 'export.json';
    LExportReplayPath := LRoot + PathDelim + 'export-replay.json';
    LReport := ExportListeningPacket(LCatalog, LExportPath);
    LReport.Free;
    Need(FileHash(LExportPath) = CLegacyExportSha256,
      'legacy non-correspondence export bytes changed');
    LReport := InspectListeningPacket(LExportPath);
    Need((LReport.Integers['requests'] = 2) and
      (LReport.Integers['events'] = 3),
      'export history inventory');
    LReport.Free;
    LBadExportPath := LRoot + PathDelim + 'bad-export.json';
    LBadPacket := ReadJson(LExportPath);
    try
      TJSONObject(TJSONObject(TJSONObject(LBadPacket.Arrays['history'].
        Items[0]).Arrays['events'].Items[0]).Arrays['scores'].Items[0]).
        Int64s['value'] := 5;
      WriteJson(LBadExportPath, LBadPacket);
    finally
      LBadPacket.Free;
    end;
    LFailed := False;
    try
      LReport := InspectListeningPacket(LBadExportPath);
      LReport.Free;
    except
      LFailed := True;
    end;
    Need(LFailed, 'invalid exported score accepted');
    LFailed := False;
    try
      LReport := ReplayListeningPacket(LBadReplayCatalog,
        LBadExportPath);
      LReport.Free;
    except
      LFailed := True;
    end;
    Need(LFailed and not FileExists(LBadReplayCatalog + PathDelim +
      'listening' + PathDelim + 'queue.json'),
      'invalid replay changed target queue');
    Need(CreateDir(LBadReplayCatalog + PathDelim + 'listening' +
      PathDelim + 'queue.json'), 'cannot create replay failure fixture');
    LFailed := False;
    try
      LReport := ReplayListeningPacket(LBadReplayCatalog, LExportPath);
      LReport.Free;
    except
      LFailed := True;
    end;
    Need(LFailed, 'queue publish failure fixture did not reject');
    Need(not DirectoryExists(LBadReplayCatalog + PathDelim + 'listening' +
      PathDelim + 'reviews'),
      'failed replay left promoted review events');
    Need(FindFirst(LBadReplayCatalog + PathDelim + 'listening' + PathDelim +
      'replay.*.partial', faAnyFile, LSearch) <> 0,
      'failed replay left staged review events');
    Need(RemoveDir(LBadReplayCatalog + PathDelim + 'listening' +
      PathDelim + 'queue.json'), 'cannot clear replay failure fixture');
    LReport := ReplayListeningPacket(LBadReplayCatalog, LExportPath);
    LReport.Free;
    LReport := ReplayListeningPacket(LReplayCatalog, LExportPath);
    LReport.Free;
    LReport := ExportListeningPacket(LReplayCatalog, LExportReplayPath);
    LReport.Free;
    Need(FileHash(LExportPath) = FileHash(LExportReplayPath),
      'export/replay bytes differ');
    LReport := ResolveListeningAsset(LCatalog, 'pair_control', 'generated');
    Need((LReport.Strings['sha256'] = LGeneratedHash) and
      (LReport.Int64s['frames'] = 5760000), 'asset resolver');
    LReport.Free;
    LCorrespondenceQueue := TJSONObject(LQueue.Clone);
    try
      LCorrespondenceQueue.Arrays['items'].Add(
        CorrespondenceRequest(LSource, LGenerated));
      WriteJson(LRoot + PathDelim + 'correspondence-queue.json',
        LCorrespondenceQueue);
      LReport := PublishListeningQueue(LCatalog,
        LRoot + PathDelim + 'correspondence-queue.json');
      Need((LReport.Integers['waiting_count'] = 1) and
        (LReport.Integers['completed_count'] = 2),
        'correspondence queue retains legacy reviews');
      LCorrespondenceRequest :=
        TJSONObject(LReport.Arrays['items'].Items[0]);
      Need((LCorrespondenceRequest.Strings['purpose'] =
        'source_correspondence') and
        (LCorrespondenceRequest.Objects['correspondence_evidence'].
        Objects['cut'].Strings['evidence_id'] = 'cut_audit'),
        'correspondence evidence readback');
      LTransaction := Transaction('correspondence_control',
        LCorrespondenceRequest.Strings['request_sha256'],
        'submitted', 'unknown', 0);
      LReport.Free;
      LBadQueue := TJSONObject(LCorrespondenceQueue.Clone);
      try
        TJSONObject(LBadQueue.Arrays['items'].Items[2]).
          Delete('correspondence_evidence');
        ExpectBadPublish(LCatalog, LRoot + PathDelim + 'bad-queue.json',
          LBadQueue, 'correspondence purpose without evidence',
          'purpose and evidence');
      finally LBadQueue.Free end;
      LBadQueue := TJSONObject(LCorrespondenceQueue.Clone);
      try
        TJSONObject(LBadQueue.Arrays['items'].Items[2]).Delete('purpose');
        ExpectBadPublish(LCatalog, LRoot + PathDelim + 'bad-queue.json',
          LBadQueue, 'correspondence evidence without purpose',
          'purpose and evidence');
      finally LBadQueue.Free end;
      LBadQueue := TJSONObject(LCorrespondenceQueue.Clone);
      try
        TJSONObject(LBadQueue.Arrays['items'].Items[2]).
          Strings['purpose'] := 'preference';
        ExpectBadPublish(LCatalog, LRoot + PathDelim + 'bad-queue.json',
          LBadQueue, 'unknown correspondence purpose',
          'unsupported listening request purpose');
      finally LBadQueue.Free end;
      LBadQueue := TJSONObject(LCorrespondenceQueue.Clone);
      try
        LCorrespondenceRequest := TJSONObject(LBadQueue.Arrays['items'].Items[2]);
        LCorrespondenceRequest.Strings['kind'] := 'single';
        LCorrespondenceRequest.Arrays['assets'].Delete(1);
        LCorrespondenceRequest.Arrays['ranges'].Delete(1);
        ExpectBadPublish(LCatalog, LRoot + PathDelim + 'bad-queue.json',
          LBadQueue, 'single-asset correspondence',
          'source correspondence requires a pair');
      finally LBadQueue.Free end;
      LBadQueue := TJSONObject(LCorrespondenceQueue.Clone);
      try
        TJSONObject(LBadQueue.Arrays['items'].Items[2]).
          Objects['correspondence_evidence'].Delete('cut');
        ExpectBadPublish(LCatalog, LRoot + PathDelim + 'bad-queue.json',
          LBadQueue, 'missing cut evidence',
          'correspondence evidence is incomplete');
      finally LBadQueue.Free end;
      LBadQueue := TJSONObject(LCorrespondenceQueue.Clone);
      try
        TJSONObject(LBadQueue.Arrays['items'].Items[2]).
          Objects['correspondence_evidence'].Strings['subject_asset_id'] :=
          'undeclared';
        ExpectBadPublish(LCatalog, LRoot + PathDelim + 'bad-queue.json',
          LBadQueue, 'unknown correspondence subject',
          'subject asset is not declared');
      finally LBadQueue.Free end;
      LBadQueue := TJSONObject(LCorrespondenceQueue.Clone);
      try
        TJSONObject(LBadQueue.Arrays['items'].Items[2]).
          Objects['correspondence_evidence'].Objects['recording'].
          Strings['evidence_sha256'] := 'bad';
        ExpectBadPublish(LCatalog, LRoot + PathDelim + 'bad-queue.json',
          LBadQueue, 'malformed recording evidence hash',
          'invalid correspondence evidence identity or SHA256');
      finally LBadQueue.Free end;
      LBadQueue := TJSONObject(LCorrespondenceQueue.Clone);
      try
        TJSONObject(LBadQueue.Arrays['items'].Items[2]).
          Objects['correspondence_evidence'].Objects['cut'].
          Strings['evidence_sha256'] := StringOfChar('a', 64);
        ExpectBadPublish(LCatalog, LRoot + PathDelim + 'bad-queue.json',
          LBadQueue, 'reused recording/cut evidence hash',
          'distinct evidence identities');
      finally LBadQueue.Free end;
      LEvent := CommitListeningReview(LCatalog, LTransaction);
      LEvent.Free;
      LTransaction.Free;
      LCorrespondenceExportPath := LRoot + PathDelim +
        'correspondence-export.json';
      LCorrespondenceReplayPath := LRoot + PathDelim +
        'correspondence-replay.json';
      LReport := ExportListeningPacket(LCatalog,
        LCorrespondenceExportPath);
      LReport.Free;
      ImportSource(LInbox, LCorrespondenceReplayCatalog, LSourceHash);
      LReport := StageListeningAsset(LCorrespondenceReplayCatalog,
        LGeneratedPath);
      LReport.Free;
      LReport := ReplayListeningPacket(LCorrespondenceReplayCatalog,
        LCorrespondenceExportPath);
      LReport.Free;
      LReport := ExportListeningPacket(LCorrespondenceReplayCatalog,
        LCorrespondenceReplayPath);
      LReport.Free;
      Need(FileHash(LCorrespondenceExportPath) =
        FileHash(LCorrespondenceReplayPath),
        'correspondence response replay differs');
      LReport := InspectListeningPacket(LCorrespondenceExportPath);
      Need((LReport.Integers['requests'] = 3) and
        (LReport.Integers['events'] = 4),
        'correspondence evidence/event not retained in export');
      LReport.Free;
      LMultiGenerated := TJSONObject(LGenerated.Clone);
      LMultiEdited := TJSONObject(LGenerated.Clone);
      try
        LMultiGenerated.Objects['provenance'].Add('source_sha256s',
          MultiHashes(LSourceHash));
        LMultiEdited.Strings['role'] := 'edited';
        LMultiEdited.Objects['provenance'].Add('source_sha256s',
          MultiHashes(LSourceHash));
        LMultiQueue := TJSONObject(LCorrespondenceQueue.Clone);
        try
          LMultiQueue.Arrays['items'].Add(Request('multi_generated',
            'pair', LSource, LMultiGenerated));
          LMultiQueue.Arrays['items'].Add(Request('multi_edited',
            'pair', LSource, LMultiEdited));
          WriteJson(LRoot + PathDelim + 'multi-queue.json', LMultiQueue);
          LReport := PublishListeningQueue(LCatalog,
            LRoot + PathDelim + 'multi-queue.json');
          Need((LReport.Integers['waiting_count'] = 2) and
            (LReport.Integers['completed_count'] = 3),
            'multi-source queue counts');
          LReport.Free;
          LReport := ReadListeningQueue(LCatalog);
          try
            for I := 0 to 1 do
            begin
              LProvenance := TJSONObject(TJSONObject(LReport.Arrays['items'].
                Items[I]).Arrays['assets'].Items[1]).Objects['provenance'];
              LHashes := LProvenance.Arrays['source_sha256s'];
              Need((LHashes.Count = 3) and
                (LHashes.Strings[0] = LSourceHash) and
                (LHashes.Strings[1] = StringOfChar('d', 64)) and
                (LHashes.Strings[2] = StringOfChar('e', 64)),
                'multi-source order changed on queue readback');
            end;
            LTransaction := Transaction('multi_generated',
              TJSONObject(LReport.Arrays['items'].Items[0]).
              Strings['request_sha256'], 'submitted', 'yes', 0);
          finally LReport.Free end;
          LEvent := CommitListeningReview(LCatalog, LTransaction);
          LEvent.Free;
          LTransaction.Free;
          LReport := ReadListeningQueue(LCatalog);
          try
            LTransaction := Transaction('multi_edited',
              TJSONObject(LReport.Arrays['items'].Items[0]).
              Strings['request_sha256'], 'submitted', 'unknown', 0);
          finally LReport.Free end;
          LEvent := CommitListeningReview(LCatalog, LTransaction);
          LEvent.Free;
          LTransaction.Free;
          LMultiExportPath := LRoot + PathDelim + 'multi-export.json';
          LMultiReplayPath := LRoot + PathDelim + 'multi-replay.json';
          LReport := ExportListeningPacket(LCatalog, LMultiExportPath);
          LReport.Free;
          LMultiReplayCatalog := LRoot + PathDelim + 'multi-replay';
          ImportSource(LInbox, LMultiReplayCatalog, LSourceHash);
          LReport := StageListeningAsset(LMultiReplayCatalog,
            LGeneratedPath);
          LReport.Free;
          LReport := ReplayListeningPacket(LMultiReplayCatalog,
            LMultiExportPath);
          LReport.Free;
          LReport := ExportListeningPacket(LMultiReplayCatalog,
            LMultiReplayPath);
          LReport.Free;
          Need(FileHash(LMultiExportPath) = FileHash(LMultiReplayPath),
            'ordered multi-source export/replay bytes differ');

          for I := 0 to 7 do
          begin
            LBadQueue := TJSONObject(LMultiQueue.Clone);
            try
              LProvenance := QueueAssetProvenance(LBadQueue, 3, 1);
              LHashes := LProvenance.Arrays['source_sha256s'];
              case I of
                0: LHashes.Strings[1] := LSourceHash;
                1: LHashes.Strings[1] := StringOfChar('A', 64);
                2: LHashes.Strings[0] := StringOfChar('f', 64);
                3: begin
                     LHashes.Delete(2);
                     LHashes.Delete(1);
                   end;
                4: for J := 1 to 30 do
                     LHashes.Add(LowerCase(IntToHex(J, 64)));
                5: LProvenance.Delete('source_sha256');
                6: LProvenance.Add('undeclared', 'x');
                7: begin
                     QueueAssetProvenance(LBadQueue, 3, 0).
                       Add('source_sha256s', MultiHashes(LSourceHash));
                   end;
              end;
              ExpectBadPublish(LCatalog,
                LRoot + PathDelim + 'bad-queue.json', LBadQueue,
                'invalid ordered multi-source case ' + IntToStr(I));
            finally LBadQueue.Free end;
          end;
        finally LMultiQueue.Free end;
      finally
        LMultiGenerated.Free;
        LMultiEdited.Free;
      end;
    finally
      LCorrespondenceQueue.Free;
    end;
  finally
    LSource.Free;
    LGenerated.Free;
    LQueue.Free;
  end;
  WriteLn('PASS listening packet staged, reviewed, deduplicated, replayed');
end.
