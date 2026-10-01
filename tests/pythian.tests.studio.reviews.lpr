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
program StudioReviewConformance;

{$mode delphi}
{$H+}

uses
  {$IFDEF UNIX}cthreads,{$ENDIF}
  Classes,
  SysUtils,
  Math,
  fpjson,
  pythian.audio,
  pythian.hash,
  pythian.wave.read,
  pythian.wave.stream,
  pythian.tools.annotations.catalog,
  pythian.tools.studio.projects,
  pythian.tools.studio.jobs,
  pythian.tools.studio.worker,
  pythian.tools.studio.reviews,
  pythian.tools.listen.catalog;

const
  CResponseArrays: array[0..1] of String = ('choices', 'scores');

var
  GChecks: Integer;

procedure Check(const ACondition: Boolean; const AMessage: String);
begin
  Inc(GChecks);
  if not ACondition then
  begin
    raise Exception.Create(AMessage);
  end;
end;

function SourceFixture(const ARoot: String): String;
var
  LSamples: TAudioSamples;
  LClip: TAudioClip;
  LStream: TFileStream;
  LManifest: TJSONObject;
  LRow: TJSONObject;
  LReport: TJSONObject;
  LIndex: Integer;
  LPath: String;
begin
  Check(ForceDirectories(ARoot + PathDelim + 'inbox'), 'Create authored fixture inbox');
  SetLength(LSamples, 64000);
  for LIndex := 0 to High(LSamples) do
  begin
    LSamples[LIndex] := 0.15 * Sin(2 * Pi * (220 + ((LIndex div 4000) mod 4) * 55) *
      LIndex / 8000);
  end;
  LPath := ARoot + PathDelim + 'inbox' + PathDelim + 'source.wav';
  LClip := TAudioClip.Create(8000, 1, LSamples);
  try
    LStream := TFileStream.Create(LPath, fmCreate);
    try
      WriteWavePcm16(LStream, LClip);
    finally
      LStream.Free;
    end;
  finally
    LClip.Free;
  end;
  LStream := TFileStream.Create(LPath, fmOpenRead);
  try
    Result := Sha256Stream(LStream, LStream.Size);
  finally
    LStream.Free;
  end;
  LManifest := TJSONObject.Create;
  try
    LManifest.Add('version', 1);
    LManifest.Add('tracks', TJSONArray.Create);
    LRow := TJSONObject.Create;
    LManifest.Arrays['tracks'].Add(LRow);
    LRow.Add('file', 'source.wav');
    LRow.Add('sha256', Result);
    LRow.Add('source_group', 'authored_review_control');
    LRow.Add('clock_id', '');
    LRow.Add('partition', 'development');
    LRow.Add('title', 'Pascal-authored review control');
    LRow.Add('provenance', 'Synthetic oscillator. Mechanical controls only; no musical verdict');
    LRow.Add('license', 'MIT');
    WriteStudioJSONNew(ARoot + PathDelim + 'inbox' + PathDelim + 'manifest.json', LManifest);
  finally
    LManifest.Free;
  end;
  LReport := ImportLabelInbox(ARoot + PathDelim + 'inbox', ARoot + PathDelim + 'catalog');
  try
    Check(LReport.Integers['imported'] = 1, 'Original authored source imported');
  finally
    LReport.Free;
  end;
end;

procedure Generate(const ACatalog, AHash: String);
var
  LWrite: TJSONObject;
  LRow: TJSONObject;
  LProject: TJSONObject;
  LResult: TJSONObject;
begin
  LWrite := TJSONObject.Create;
  try
    LWrite.Add('format', StudioProjectWriteFormat);
    LWrite.Add('project_id', 'control');
    LWrite.Add('expected_revision', 0);
    LWrite.Add('name', 'Authored audition controls');
    LWrite.Add('style_intent', '');
    LWrite.Add('learning_mode', 'raw_acoustic');
    LWrite.Add('sources', TJSONArray.Create);
    LRow := TJSONObject.Create;
    LWrite.Arrays['sources'].Add(LRow);
    LRow.Add('source_sha256', AHash);
    LRow.Add('selection', 'full');
    LRow.Add('classifications', TJSONArray.Create);
    LProject := SaveStudioProject(ACatalog, LWrite);
  finally
    LWrite.Free;
  end;
  try
    LWrite := TJSONObject.Create;
    try
      LWrite.Add('format', StudioJobWriteFormat);
      LWrite.Add('job_id', 'authored-batch');
      LWrite.Add('kind', 'train_generate');
      LWrite.Add('project_id', 'control');
      LWrite.Add('project_revision', LProject.Int64s['revision']);
      LWrite.Add('project_snapshot_sha256', LProject.Strings['snapshot_sha256']);
      LWrite.Add('duration_ms', 20000);
      LWrite.Add('seeds', TJSONArray.Create);
      LWrite.Arrays['seeds'].Add(731);
      LWrite.Arrays['seeds'].Add(1731);
      LWrite.Add('maximum_tokens', 4);
      LWrite.Add('model_order', 2);
      LWrite.Add('resolve_unassigned', 'development');
      LWrite.Add('source_weights', TJSONArray.Create);
      LRow := TJSONObject.Create;
      LWrite.Arrays['source_weights'].Add(LRow);
      LRow.Add('source_sha256', AHash);
      LRow.Add('weight', 1);
      LResult := EnqueueStudioJob(ACatalog, LWrite);
      LResult.Free;
      Check(RunStudioWorker(ACatalog, 'authored-batch', ExtractFileDir(ACatalog) +
        PathDelim + 'library'), 'Actual two-seed saved-model/WAV/listening batch');
    finally
      LWrite.Free;
    end;
  finally
    LProject.Free;
  end;
end;

function NewReview: TJSONObject;
var
  LRow: TJSONObject;
  LIndex: Integer;
begin
  Result := TJSONObject.Create;
  Result.Add('format', StudioReviewWriteFormat);
  Result.Add('review_id', 'comparison');
  Result.Add('question', 'Which direction fits the intent?');
  Result.Add('context', 'Synthetic development controls, not a musical calibration verdict');
  Result.Add('mode', 'frozen_evaluation');
  Result.Add('blind', True);
  Result.Add('style_choices', TJSONArray.Create);
  Result.Arrays['style_choices'].Add('My intended direction');
  Result.Arrays['style_choices'].Add('Different direction');
  Result.Add('outputs', TJSONArray.Create);
  for LIndex := 0 to 1 do
  begin
    LRow := TJSONObject.Create;
    Result.Arrays['outputs'].Add(LRow);
    LRow.Add('job_id', 'authored-batch');
    LRow.Add('ordinal', LIndex);
  end;
end;

function Response(const ARead: TJSONObject; const AStatus: String): TJSONObject;
var
  LName: String;
  LIndex: Integer;
  LRow: TJSONObject;
begin
  Result := TJSONObject.Create;
  Result.Add('format', StudioReviewResponseFormat);
  Result.Add('review_id', ARead.Strings['review_id']);
  Result.Add('expected_revision', ARead.Int64s['revision']);
  Result.Add('reviewer', 'mechanical_control');
  Result.Add('status', AStatus);
  for LName in CResponseArrays do
  begin
    Result.Add(LName, TJSONArray.Create);
    for LIndex := 0 to ARead.Objects['answer_spec'].Arrays[LName].Count - 1 do
    begin
      LRow := TJSONObject.Create;
      Result.Arrays[LName].Add(LRow);
      LRow.Add('id', ARead.Objects['answer_spec'].Arrays[LName].Objects[LIndex].Strings['id']);
      LRow.Add('value', 'unknown');
    end;
  end;
  Result.Add('comments', TJSONArray.Create);
  LRow := TJSONObject.Create;
  Result.Arrays['comments'].Add(LRow);
  LRow.Add('asset_id', 'sample_a');
  LRow.Add('frame', 8000);
  LRow.Add('text', 'Mechanical timestamp comment, no audible judgment');
end;

procedure CheckListeningExport(const ARoot, ACatalog: String);
var
  LPacket: TJSONObject;
  LReport: TJSONObject;
  LRows: TJSONArray;
  LAssets: TJSONArray;
  LSeen: TStringList;
  LInput: TFileStream;
  LOutput: TFileStream;
  LReplay: String;
  LHash: String;
  LExpected: String;
  LIndex: Integer;
  LAssetIndex: Integer;
begin
  LReport := ExportListeningPacket(ACatalog, ARoot + PathDelim + 'feedback.json');
  try
    LExpected := LReport.Strings['sha256'];
    Check(LReport.Integers['requests'] = 3, 'Export includes ordinary auditions and comparison');
  finally
    LReport.Free;
  end;
  LReport := InspectListeningPacket(ARoot + PathDelim + 'feedback.json');
  try
    Check(LReport.Integers['events'] = 5, 'Export retains corrections and withdrawals');
  finally
    LReport.Free;
  end;
  LReplay := ARoot + PathDelim + 'replay-catalog';
  Check(ForceDirectories(LReplay + PathDelim + 'listening' + PathDelim + 'assets'),
    'Fresh replay has independently copied immutable audition assets');
  LPacket := ReadStudioJSON(ARoot + PathDelim + 'feedback.json');
  LSeen := TStringList.Create;
  try
    LRows := LPacket.Objects['queue'].Arrays['items'];
    for LIndex := 0 to LRows.Count - 1 do
    begin
      LAssets := LRows.Objects[LIndex].Arrays['assets'];
      for LAssetIndex := 0 to LAssets.Count - 1 do
      begin
        LHash := LAssets.Objects[LAssetIndex].Strings['sha256'];
        if LSeen.IndexOf(LHash) >= 0 then
        begin
          Continue;
        end;
        LSeen.Add(LHash);
        LInput := TFileStream.Create(ACatalog + PathDelim + 'listening' + PathDelim +
          'assets' + PathDelim + LHash + '.wav', fmOpenRead or fmShareDenyWrite);
        try
          LOutput := TFileStream.Create(LReplay + PathDelim + 'listening' + PathDelim +
            'assets' + PathDelim + LHash + '.wav', fmCreate or fmShareExclusive);
          try
            LOutput.CopyFrom(LInput, LInput.Size);
          finally
            LOutput.Free;
          end;
        finally
          LInput.Free;
        end;
      end;
    end;
  finally
    LSeen.Free;
    LPacket.Free;
  end;
  LReport := ReplayListeningPacket(LReplay, ARoot + PathDelim + 'feedback.json');
  LReport.Free;
  LReport := ExportListeningPacket(LReplay, ARoot + PathDelim + 'feedback-replayed.json');
  try
    Check(LReport.Strings['sha256'] = LExpected,
      'Fresh verified-asset replay and reexport preserve every response identity');
  finally
    LReport.Free;
  end;
end;

procedure Run(const ARoot: String);
var
  LCatalog: String;
  LHash: String;
  LWrite: TJSONObject;
  LRead: TJSONObject;
  LOther: TJSONObject;
  LReply: TJSONObject;
  LQueue: TJSONObject;
  LAsset: TJSONObject;
  LNext: TJSONObject;
  LItem: String;
  LIds: TStringList;
  LBindings: TJSONObject;
  LFailed: Boolean;
  LRequestHash: String;
begin
  Check(not DirectoryExists(ARoot), 'Review fixture is fresh');
  Check(ForceDirectories(ARoot), 'Create review fixture');
  LHash := SourceFixture(ARoot);
  LCatalog := ARoot + PathDelim + 'catalog';
  Generate(LCatalog, LHash);
  LWrite := NewReview;
  try
    LRead := CreateStudioReview(LCatalog, LWrite);
    try
      Check(LRead.Arrays['samples'].Count = 2, 'Actual paired comparison');
      Check(not LRead.Booleans['revealed'], 'Blind assignment starts unrevealed');
      Check(LRead.Integers['revision'] = 0, 'No fabricated answer');
      Check((Pos('authored-batch', LRead.AsJSON) = 0) and (Pos(LHash, LRead.AsJSON) = 0) and
        (Pos('sha256', LRead.AsJSON) = 0) and (Pos('seed', LRead.AsJSON) = 0),
        'Public blind payload withholds job/seed/hash/model mapping');
      Check(LRead.Arrays['scores'].Count = 0, 'No preselected rubric');
      Check(LRead.Objects['score_anchors'].Arrays['fit'].Count = 4, 'Four plain-language anchors');
      LOther := CreateStudioReview(LCatalog, LWrite);
      try
        Check(LOther.AsJSON = LRead.AsJSON, 'Identical retry preserves randomized assignment');
      finally
        LOther.Free;
      end;
      LBindings := ReadStudioJSON(LCatalog + PathDelim + 'studio' + PathDelim +
        'reviews' + PathDelim + 'comparison' + PathDelim + 'session.json');
      try
        LItem := LBindings.Objects['listening_request'].Strings['id'];
        LRequestHash := LBindings.Strings['session_sha256'];
      finally
        LBindings.Free;
      end;
      Check(IsStudioReviewListeningItemHidden(LCatalog, LItem), 'Generic queue must hide blind mapping');
      Check(not IsStudioReviewListeningItemHidden(LCatalog, 'studio_authored-batch_0'),
        'Ordinary job audition remains separate from blind aliases');
      LAsset := ResolveStudioReviewAsset(LCatalog, 'comparison', 'sample_a');
      try
        Check((LAsset.Int64s['frames'] = 160000) and (LAsset.Integers['sample_rate'] = 8000),
          'Server-only actual asset clock');
      finally
        LAsset.Free;
      end;
      LFailed := False;
      try
        LNext := PrepareStudioNextBatch(LCatalog, 'comparison', 'sample_a');
        LNext.Free;
      except
        on E: EAudio do
        begin
          LFailed := True;
        end;
      end;
      Check(LFailed, 'Unreviewed comparison cannot silently prepare next model');
      LReply := Response(LRead, 'withdrawn');
    finally
      LRead.Free;
    end;
    try
      LRead := CommitStudioReview(LCatalog, LReply);
      try
        Check((LRead.Integers['revision'] = 1) and not LRead.Booleans['revealed'],
          'Withdrawn response durable without revealing identity');
        Check(LRead.Arrays['comments'].Objects[0].Int64s['frame'] = 8000, 'Exact timestamp persisted');
      finally
        LRead.Free;
      end;
      LRead := CommitStudioReview(LCatalog, LReply);
      try
        Check(LRead.Integers['revision'] = 1, 'Lost withdrawn response produces no duplicate event');
      finally
        LRead.Free;
      end;
      LReply.Int64s['expected_revision'] := 1;
      LReply.Strings['status'] := 'submitted';
      LRead := CommitStudioReview(LCatalog, LReply);
      try
        Check((LRead.Integers['revision'] = 2) and LRead.Booleans['revealed'],
          'Complete uncertainty response triggers declared reveal');
        Check(LRead.Arrays['samples'].Objects[0].Objects['assignment'].Strings['job_id'] =
          'authored-batch', 'Auditable assignment exposed only at reveal');
        Check(not LRead.Booleans['grounded_acceptance'], 'Mechanical review does not grant musical acceptance');
      finally
        LRead.Free;
      end;
      LRead := CommitStudioReview(LCatalog, LReply);
      try
        Check(LRead.Integers['revision'] = 2, 'Lost submitted response produces no duplicate event');
      finally
        LRead.Free;
      end;
      LReply.Arrays['scores'].Objects[0].Integers['value'] := 3;
      LFailed := False;
      try
        LRead := CommitStudioReview(LCatalog, LReply);
        LRead.Free;
      except
        on E: EAudio do
        begin
          LFailed := True;
        end;
      end;
      Check(LFailed, 'Stale changed feedback rejects');
      LReply.Int64s['expected_revision'] := 2;
      LRead := CommitStudioReview(LCatalog, LReply);
      try
        Check(LRead.Integers['revision'] = 3, 'Explicit feedback correction retains earlier history');
      finally
        LRead.Free;
      end;
      LReply.Int64s['expected_revision'] := 3;
      LReply.Strings['status'] := 'withdrawn';
      LRead := CommitStudioReview(LCatalog, LReply);
      try
        Check((LRead.Integers['revision'] = 4) and LRead.Booleans['revealed'],
          'Withdrawal cannot restore an already exposed blind assignment');
      finally
        LRead.Free;
      end;
      LReply.Int64s['expected_revision'] := 4;
      LReply.Strings['status'] := 'submitted';
      LRead := CommitStudioReview(LCatalog, LReply);
      LRead.Free;
    finally
      LReply.Free;
    end;
    Check(not IsStudioReviewListeningItemHidden(LCatalog, LItem), 'Declared reveal releases generic queue mapping');
    LRead := PinStudioReview(LCatalog, 'comparison', 0, True);
    try
      Check(LRead.Objects['pin'].Booleans['pinned'] and
        (LRead.Objects['pin'].Integers['revision'] = 1), 'Useful result pin persisted');
    finally
      LRead.Free;
    end;
    LRead := PinStudioReview(LCatalog, 'comparison', 0, True);
    try
      Check(LRead.Objects['pin'].Integers['revision'] = 1, 'Lost pin response reconciles');
    finally
      LRead.Free;
    end;
    LRead := PinStudioReview(LCatalog, 'comparison', 1, False);
    LRead.Free;
    LRead := PinStudioReview(LCatalog, 'comparison', 2, True);
    LRead.Free;
    LFailed := False;
    try
      LRead := PinStudioReview(LCatalog, 'comparison', 0, False);
      LRead.Free;
    except
      on E: EStudioConflict do
      begin
        LFailed := True;
      end;
    end;
    Check(LFailed, 'Stale conflicting pin does not replace newer pin');
    LNext := PrepareStudioNextBatch(LCatalog, 'comparison', 'sample_a');
    try
      Check(LNext.Strings['enqueue_status'] = 'not_enqueued', 'Preference never silently enqueues');
      Check(LNext.Objects['request'].Find('job_id') = nil, 'Next batch needs a fresh deliberate identity');
      Check(LNext.Objects['request'].Strings['parent_job_id'] = 'authored-batch', 'Immutable parent lineage');
      Check(LNext.Objects['request'].Int64s['project_revision'] = 1, 'Retained original corpus revision');
    finally
      LNext.Free;
    end;
    LRead := ListStudioReviews(LCatalog);
    try
      Check((LRead.Integers['count'] = 1) and
        (LRead.Arrays['reviews'].Objects[0].Find('samples') = nil), 'History uses compact summaries');
    finally
      LRead.Free;
    end;
    LQueue := ReadListeningQueue(LCatalog);
    try
      Check((LQueue.Integers['waiting_count'] = 2) and (LQueue.Integers['completed_count'] = 1),
        'Existing audition requests retained beside comparison');
    finally
      LQueue.Free;
    end;
    LWrite.Strings['question'] := 'Different question';
    LFailed := False;
    try
      LRead := CreateStudioReview(LCatalog, LWrite);
      LRead.Free;
    except
      on E: EStudioConflict do
      begin
        LFailed := True;
      end;
    end;
    Check(LFailed, 'Conflicting review retry cannot redraw assignment');
    CheckListeningExport(ARoot, LCatalog);
    LIds := TStringList.Create;
    try
      LIds.LoadFromFile(LCatalog + PathDelim + 'studio' + PathDelim + 'reviews' +
        PathDelim + 'comparison' + PathDelim + 'session.json');
      Check(Pos(LRequestHash, LIds.Text) > 0, 'Immutable session identity retained after feedback');
    finally
      LIds.Free;
    end;
  finally
    LWrite.Free;
  end;
end;

begin
  try
    if ParamCount <> 1 then
    begin
      raise Exception.Create('Usage: Studio reviews test FRESH_ROOT');
    end;
    Run(ExpandFileName(ParamStr(1)));
    WriteLn('PASS ', GChecks, ' Studio review and iteration checks');
  except
    on E: Exception do
    begin
      WriteLn(StdErr, E.ClassName, ': ', E.Message);
      DumpExceptionBackTrace(StdErr);
      ExitCode := 1;
    end;
  end;
end.
