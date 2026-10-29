{ MIT License
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
  SOFTWARE. }

{ Big Boss: real catalog histories, stale preparation and replay boundaries;
  authored fixture judgments never count as an operator's musical verdict. }
procedure CheckReviewedFeedback(const ARoot, AInbox, ASourceHash,
  AGeneratedPath: String; const ASource, AGenerated: TJSONObject);
var
  LCatalog: String;
  LPath: String;
  LQueuePath: String;
  LExport: String;
  LReplayExport: String;
  LReplay: String;
  LQueueHash: String;
  LParentHash: String;
  LResponseHash: String;
  LQueue: TJSONObject;
  LDefinition: TJSONObject;
  LPrepared: TJSONObject;
  LBad: TJSONObject;
  LReport: TJSONObject;
  LTransaction: TJSONObject;
  LEvent: TJSONObject;
  LBinding: TJSONObject;
  LStream: TStringStream;
  LRejected: Boolean;
  I: Integer;

  procedure AnswerParent(const ARevision: Integer; const AValue: String;
    const AStatus: String = 'submitted');
  begin
    LTransaction := Transaction('reviewed-guided', LParentHash, AStatus, AValue, ARevision);
    try
      if AStatus = 'submitted' then
      begin
        LTransaction.Arrays['choices'].Objects[0].Strings['id'] := 'listening_answer';
        LTransaction.Arrays['scores'].Clear;
        LTransaction.Arrays['comments'].Objects[0].Strings['asset_id'] := 'generated';
      end;
      LEvent := CommitListeningReview(LCatalog, LTransaction);
      try
        LStream := TStringStream.Create(LEvent.AsJSON);
        try
          LResponseHash := Sha256Stream(LStream, LStream.Size);
        finally
          LStream.Free;
        end;
      finally
        LEvent.Free;
      end;
    finally
      LTransaction.Free;
    end;
  end;

  procedure RejectAppend(const AInput: TJSONObject; const AError: String);
  begin
    LQueueHash := FileHash(LQueuePath);
    WriteJson(LPath, AInput);
    LRejected := False;
    try
      LReport := AppendListeningQueue(LCatalog, LPath);
      LReport.Free;
    except
      on E: EAudio do LRejected := Pos(AError, E.Message) > 0;
    end;
    Need(LRejected and (FileHash(LQueuePath) = LQueueHash),
      'Feedback rejection must preserve queue: ' + AError);
  end;

begin
  LCatalog := ARoot + PathDelim + 'reviewed-feedback';
  LPath := ARoot + PathDelim + 'reviewed-feedback-input.json';
  LQueuePath := LCatalog + PathDelim + 'listening' + PathDelim + 'queue.json';
  ImportSource(AInbox, LCatalog, ASourceHash);
  LReport := StageListeningAsset(LCatalog, AGeneratedPath);
  LReport.Free;
  LQueue := TJSONObject.Create;
  LDefinition := TJSONObject.Create;
  try
    LQueue.Add('version', 1);
    LQueue.Add('items', TJSONArray.Create);
    for I := 0 to 1 do
    begin
      if I = 0 then LParentHash := 'origin' else LParentHash := 'candidate';
      LReport := Request(LParentHash, 'single', AGenerated, AGenerated);
      LReport.Arrays['ranges'].Objects[0].Strings['asset_id'] := 'generated';
      LQueue.Arrays['items'].Add(LReport);
    end;
    LQueue.Arrays['items'].Add(Request('original-reference', 'single', ASource, AGenerated));
    WriteJson(LPath, LQueue);
    LReport := AppendListeningQueue(LCatalog, LPath);
    LReport.Free;
    LDefinition.Add('id', 'reviewed-guided');
    LDefinition.Add('task_id', 'NS-6_studio_03');
    LDefinition.Add('comparison_id', 'origin');
    LDefinition.Add('reference_id', 'original-reference');
    LDefinition.Add('title', 'Authored parent');
    LDefinition.Add('question', 'Does this sound smoother?');
    LDefinition.Add('change', 'A fixed authored control.');
    LDefinition.Add('decision', 'Prepare one explicit longer follow-up.');
    LPrepared := PrepareListeningExperiment(LCatalog, LDefinition);
    try
      WriteJson(LPath, LPrepared);
      LReport := AppendListeningQueue(LCatalog, LPath);
      LReport.Free;
    finally
      LPrepared.Free;
    end;
    LReport := ReadListeningQueue(LCatalog);
    try
      LParentHash := LReport.Arrays['items'].Objects[3].Strings['request_sha256'];
    finally
      LReport.Free;
    end;
    LDefinition.Strings['id'] := 'followup';
    LDefinition.Strings['comparison_id'] := 'candidate';
    LDefinition.Add('reviewed_request_id', 'reviewed-guided');
    LDefinition.Add('reviewed_asset_id', 'generated');
    LRejected := False;
    try
      LPrepared := PrepareListeningExperiment(LCatalog, LDefinition);
      LPrepared.Free;
    except
      on E: EAudio do LRejected := Pos('no saved response', E.Message) > 0;
    end;
    Need(LRejected, 'An unanswered parent cannot produce feedback lineage');
    AnswerParent(0, 'yes');
    LPrepared := PrepareListeningExperiment(LCatalog, LDefinition);
    try
      LBinding := LPrepared.Arrays['items'].Objects[0].Objects['experiment'].Objects['reviewed_from'];
      Need((LBinding.Strings['request_id'] = 'reviewed-guided') and
        (LBinding.Strings['request_sha256'] = LParentHash) and
        (LBinding.Integers['revision'] = 1) and
        (LBinding.Strings['response_sha256'] = LResponseHash),
        'Factory binds the exact prepared parent and actual submitted answer');
      for I := 0 to 5 do
      begin
        LBad := TJSONObject(LPrepared.Clone);
        try
          LBinding := LBad.Arrays['items'].Objects[0].Objects['experiment'].Objects['reviewed_from'];
          case I of
            0: LBinding.Integers['revision'] := 0;
            1: LBinding.Strings['response_sha256'] := StringOfChar('f', 64);
            2: LBinding.Strings['request_sha256'] := StringOfChar('a', 64);
            3: LBinding.Strings['asset_id'] := 'missing';
            4: LBinding.Strings['request_id'] := 'followup';
            5: LBinding.Add('undeclared', 'field');
          end;
          case I of
            0: RejectAppend(LBad, 'revision or hash');
            1: RejectAppend(LBad, 'historical response');
            2: RejectAppend(LBad, 'reference changed');
            3: RejectAppend(LBad, 'asset is not declared');
            4: RejectAppend(LBad, 'ordinary request except');
            5: RejectAppend(LBad, 'unsupported field');
          end;
        finally
          LBad.Free;
        end;
      end;
      WriteJson(LPath, LPrepared);
      LReport := AppendListeningQueue(LCatalog, LPath);
      LReport.Free;
      AnswerParent(1, 'no');
      LQueueHash := FileHash(LQueuePath);
      LReport := AppendListeningQueue(LCatalog, LPath);
      LReport.Free;
      Need(FileHash(LQueuePath) = LQueueHash,
        'Identical historical follow-up survives later parent correction');
      LBad := TJSONObject(LPrepared.Clone);
      try
        LBad.Arrays['items'].Objects[0].Strings['id'] := 'stale-followup';
        RejectAppend(LBad, 'changed before publication');
        LReport := ReadJson(LQueuePath);
        try
          LReport.Arrays['items'].Add(LBad.Arrays['items'].Objects[0].Clone);
          ExpectBadPublish(LCatalog, LPath, LReport, 'stale feedback full publish',
            'changed before publication');
        finally
          LReport.Free;
        end;
      finally
        LBad.Free;
      end;
      AnswerParent(2, '', 'withdrawn');
      LRejected := False;
      try
        LReport := PrepareListeningExperiment(LCatalog, LDefinition);
        LReport.Free;
      except
        on E: EAudio do LRejected := Pos('must be submitted', E.Message) > 0;
      end;
      Need(LRejected, 'A withdrawn answer is not submitted feedback');
      LExport := ARoot + PathDelim + 'reviewed-feedback-export.json';
      LReport := ExportListeningPacket(LCatalog, LExport);
      LReport.Free;
      LReport := InspectListeningPacket(LExport);
      LReport.Free;
      LReplay := ARoot + PathDelim + 'reviewed-feedback-replay';
      ImportSource(AInbox, LReplay, ASourceHash);
      LReport := StageListeningAsset(LReplay, AGeneratedPath);
      LReport.Free;
      LReport := ReplayListeningPacket(LReplay, LExport);
      LReport.Free;
      LReplayExport := ARoot + PathDelim + 'reviewed-feedback-reexport.json';
      LReport := ExportListeningPacket(LReplay, LReplayExport);
      LReport.Free;
      Need(FileHash(LExport) = FileHash(LReplayExport),
        'Review-bound export/replay preserves complete historical bytes');
      for I := 0 to 1 do
      begin
        LBad := ReadJson(LExport);
        try
          if I = 0 then
            LBad.Arrays['history'].Objects[3].Arrays['events'].Objects[0].Arrays['choices'].Objects[0].Strings['value'] := 'no'
          else
            LBad.Arrays['history'].Objects[3].Arrays['events'].Clear;
          WriteJson(LPath, LBad);
          LRejected := False;
          try
            LReport := InspectListeningPacket(LPath);
            LReport.Free;
          except
            on E: EAudio do LRejected := Pos('feedback', E.Message) > 0;
          end;
          Need(LRejected, 'Forged or missing bound history cannot pass export inspection');
        finally
          LBad.Free;
        end;
      end;
      WriteLn('PASS reviewed-feedback preparation, stale publication and historical replay');
    finally
      LPrepared.Free;
    end;
  finally
    LDefinition.Free;
    LQueue.Free;
  end;
end;
