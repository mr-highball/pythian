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

{ Big Boss: real persisted Unicode publication, feedback and replay. Fixture
  strings enter through the primary parser, independent of host source encoding. }
procedure CheckUnicodeListening(const ARoot, AInbox, ASourceHash,
  AGeneratedPath: String; const AGenerated: TJSONObject);
var
  LCatalog, LReplay, LInput, LExport, LAgain, LRequestHash, LQueueHash: String;
  LQueue, LDefinition, LPrepared, LReport, LTransaction, LEvent, LText: TJSONObject;
  LRaw: RawByteString;
  LFile: TFileStream;
  LRejected: Boolean;
begin
  LCatalog := ARoot + PathDelim + 'unicode-listening';
  LReplay := ARoot + PathDelim + 'unicode-replay';
  LInput := ARoot + PathDelim + 'unicode-input.json';
  LExport := ARoot + PathDelim + 'unicode-export.json';
  LAgain := ARoot + PathDelim + 'unicode-replayed.json';
  LQueue := nil; LDefinition := nil; LPrepared := nil; LReport := nil;
  LTransaction := nil; LEvent := nil; LText := nil;
  try
    ImportSource(AInbox, LCatalog, ASourceHash);
    LReport := StageListeningAsset(LCatalog, AGeneratedPath);
    FreeAndNil(LReport);
    LQueue := TJSONObject.Create(['version', 1, 'items', TJSONArray.Create]);
    LQueue.Arrays['items'].Add(Request('unicode-base', 'single', AGenerated, AGenerated));
    LQueue.Arrays['items'].Objects[0].Arrays['ranges'].Objects[0].Strings['asset_id'] := 'generated';
    WriteJson(LInput, LQueue);
    LReport := PublishListeningQueue(LCatalog, LInput);
    FreeAndNil(LReport);
    LDefinition := TJSONObject(ParseNativeJSON(
      '{"id":"unicode-review","task_id":"NS-6_listening-utf8_01",' +
      '"comparison_id":"unicode-base","title":"Return \u00b7 \ud83c\udfb5",' +
      '"question":"Does the melody return \u2014 caf\u00e9?",' +
      '"change":"Lead returns \u2192 ending.","decision":"Keep \u97f3 or revise."}'));
    LPrepared := PrepareListeningExperiment(LCatalog, LDefinition);
    WriteJson(LInput, LPrepared);
    LReport := AppendListeningQueue(LCatalog, LInput);
    FreeAndNil(LReport);
    LReport := ReadListeningQueue(LCatalog);
    Need((LReport.Arrays['items'].Objects[1].Strings['question'] = LDefinition.Strings['question']) and
      (LReport.Arrays['items'].Objects[1].Objects['experiment'].Strings['title'] = LDefinition.Strings['title']) and
      (LReport.Arrays['items'].Objects[1].Objects['experiment'].Strings['decision'] = LDefinition.Strings['decision']),
      'Unicode prepared content must survive append and reload exactly');
    LRequestHash := LReport.Arrays['items'].Objects[1].Strings['request_sha256'];
    FreeAndNil(LReport);
    LTransaction := Transaction('unicode-review', LRequestHash, 'submitted', 'yes', 0);
    LTransaction.Arrays['choices'].Objects[0].Strings['id'] := 'listening_answer';
    LTransaction.Arrays['scores'].Clear;
    LTransaction.Arrays['comments'].Objects[0].Strings['asset_id'] := 'generated';
    LText := TJSONObject(ParseNativeJSON('{"text":"M\u00e9lodie \ud83c\udfb5 \u97f3"}'));
    LTransaction.Arrays['comments'].Objects[0].Strings['text'] := LText.Strings['text'];
    LTransaction.Strings['reviewer'] := LText.Strings['text'];
    LEvent := CommitListeningReview(LCatalog, LTransaction);
    FreeAndNil(LReport);
    LReport := ReadListeningQueue(LCatalog);
    Need((LReport.Arrays['completed'].Count = 1) and
      (LReport.Arrays['completed'].Objects[0].Strings['request_sha256'] = LRequestHash) and
      (LReport.Arrays['completed'].Objects[0].Arrays['current_comments'].Objects[0].Strings['text'] = LText.Strings['text']),
      'Unicode response must reopen against the exact accepted request');
    FreeAndNil(LReport);
    LReport := CommitListeningReview(LCatalog, LTransaction);
    Need(LReport.Booleans['already_saved'], 'Unicode response retry must be idempotent');
    FreeAndNil(LReport);
    LReport := ExportListeningPacket(LCatalog, LExport);
    FreeAndNil(LReport);
    ImportSource(AInbox, LReplay, ASourceHash);
    LReport := StageListeningAsset(LReplay, AGeneratedPath);
    FreeAndNil(LReport);
    LReport := ReplayListeningPacket(LReplay, LExport);
    FreeAndNil(LReport);
    LReport := ExportListeningPacket(LReplay, LAgain);
    FreeAndNil(LReport);
    Need(FileHash(LExport) = FileHash(LAgain), 'Unicode queue/response export replay must preserve exact bytes');
    LQueueHash := FileHash(LCatalog + PathDelim + 'listening' + PathDelim + 'queue.json');
    { Real malformed input bytes, not a code-page-tagged string that the host
      can legitimately convert into a valid scalar before the test begins. }
    LRaw := '{"version":1,"items":[{"title":"?"}]}';
    LRaw[Pos('?', LRaw)] := AnsiChar($FF);
    LFile := TFileStream.Create(LInput, fmCreate);
    try LFile.WriteBuffer(LRaw[1], Length(LRaw)) finally LFile.Free end;
    LRejected := False;
    try
      LReport := AppendListeningQueue(LCatalog, LInput);
      FreeAndNil(LReport);
    except on E: EAudio do LRejected := True end;
    Need(LRejected and (FileHash(LCatalog + PathDelim + 'listening' + PathDelim + 'queue.json') = LQueueHash),
      'Malformed scalar rejection must preserve accepted queue bytes');
    WriteLn('PASS Unicode listening publication, response, exact replay and malformed-text preservation');
  finally
    LText.Free; LEvent.Free; LTransaction.Free; LReport.Free;
    LPrepared.Free; LDefinition.Free; LQueue.Free;
  end;
end;
