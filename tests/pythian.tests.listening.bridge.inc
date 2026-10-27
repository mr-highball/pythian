(* MIT License
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
SOFTWARE. *)

{ Big Boss: compile the actual listener with this include; no duplicate UI model. }
var
  BridgeQueue: TJSObject;
  BridgeWrites, BridgeChecks: Integer;

procedure BridgeCheck(const AValue: Boolean; const AMessage: String);
begin
  Inc(BridgeChecks);
  if not AValue then raise Exception.Create(AMessage);
end;

function BridgeReply(const AValue: TJSObject): TJSObject;
begin
  Result := TJSObject.new;
  Result['status'] := 200;
  Result['json'] := function: TJSPromise
    begin Result := TJSPromise.resolve(Cloned(AValue)); end;
end;

function BridgeFetch(const AUrl: String; const AOptions: TJSObject): TJSPromise;
var
  LTransaction, LRow: TJSObject;
begin
  if Pos('/api/listen-queue', AUrl) > 0 then
    Exit(TJSPromise.resolve(BridgeReply(BridgeQueue)));
  if Pos('/api/listen-references', AUrl) > 0 then
    Exit(TJSPromise.resolve(BridgeReply(Obj(TJSJSON.parse(
      '{"format":"pythian.listening.references.v1","sources":[],' +
      '"message":"Original selections are unavailable for this older clip."}')))));
  BridgeCheck((Pos('/api/listen-review', AUrl) > 0) and
    (Str(AOptions, 'method') = 'POST'), 'Only the explicit feedback write is allowed');
  Inc(BridgeWrites);
  LTransaction := Obj(TJSJSON.parse(Str(AOptions, 'body')));
  LRow := Obj(Arr(BridgeQueue, 'items')[0]);
  LRow['revision'] := 1;
  LRow['current_status'] := 'submitted';
  LRow['current_choices'] := LTransaction['choices'];
  LRow['current_scores'] := LTransaction['scores'];
  LRow['current_comments'] := LTransaction['comments'];
  Arr(BridgeQueue, 'completed').push(LRow);
  Arr(BridgeQueue, 'items').splice(0, 1);
  Result := TJSPromise.reject('Synthetic lost response after durable commit');
end;

function BridgeTurn: TJSPromise;
begin
  Result := TJSPromise.new(procedure(Resolve, Reject: TJSPromiseResolver)
    begin window.setTimeout(procedure() begin Resolve(Undefined); end, 10); end);
end;

procedure RunListeningBridgeChecks(const AListener: TListener); async;
var
  LRow, LTransaction: TJSObject;
  LAsset: TJSObject;
  LAssets: TJSArray;
  LButtons: TJSNodeList;
  LPlayer: TJSHTMLAudioElement;
  I: Integer;
  LRejected: Boolean;
begin
  try
    BridgeQueue := Obj(TJSJSON.parse('{"items":[],"completed":[]}'));
    LRow := Obj(TJSJSON.parse('{"id":"qa-experiment","task_id":"NS-5_continuity_01",' +
      '"kind":"pair","question":"Which has fewer broken notes?","request_sha256":"qa-bound-request",' +
      '"revision":0,"assets":[],"ranges":[' +
      '{"asset_id":"before","start_frame":0,"end_frame":160000},' +
      '{"asset_id":"after","start_frame":0,"end_frame":160000}],' +
      '"answer_spec":{"choices":[{"id":"continuity_preference",' +
      '"values":["before","after","same","neither","unknown"]}],"scores":[]},' +
      '"experiment":{"title":"Smoother notes","change":"Keep matching neighbors together.",' +
      '"decision":"Decide whether to keep this core change.","reference":{' +
      '"request_id":"original","asset_id":"reference","request_sha256":"qa-original"}}}'));
    LAssets := Arr(LRow, 'assets');
    for I := 0 to 1 do
    begin
      LAsset := Obj(TJSJSON.parse('{"storage":"listening","role":"generated",' +
        '"sample_rate":8000,"channels":1,"frames":160000}'));
      if I = 0 then LAsset['id'] := 'before' else LAsset['id'] := 'after';
      LAssets.push(LAsset);
    end;
    Arr(BridgeQueue, 'items').push(LRow);
    TJSObject(window)['fetch'] := @BridgeFetch;
    AListener.FToken := 'qa-session';
    AListener.FComments := TJSArray.new;
    AListener.FAudioPlayers := TJSArray.new;
    AListener.FAudioFailures := TJSArray.new;
    AListener.FAudioReady := TJSArray.new;
    AListener.ApplyQueue(Obj(Cloned(BridgeQueue)), '', False);
    BridgeCheck(AListener.El('packet-title').textContent = 'Smoother notes', 'Prepared title');
    BridgeCheck(document.querySelectorAll('.sample-switch button').length = 3,
      'Original, Before and After tabs');
    BridgeCheck(document.querySelectorAll('#assets .asset:not([hidden])').length = 1,
      'Only one recording card is visible');
    BridgeCheck(document.querySelector('input[type=radio]:checked') = nil,
      'No musical judgment is preselected');
    BridgeCheck(AListener.El('answer').hasAttribute('hidden'), 'Media readiness gate starts closed');
    LRejected := False;
    try LTransaction := AListener.BuildTransaction;
    except on E: Exception do LRejected := True; end;
    BridgeCheck(LRejected, 'No answer is fabricated');
    LButtons := document.querySelectorAll('.sample-switch button');
    LPlayer := TJSHTMLAudioElement(AListener.El('audio-0'));
    TJSHTMLElement(LButtons[2]).click;
    BridgeCheck(not AListener.El('sample-card-1').hasAttribute('hidden') and
      AListener.El('sample-card-0').hasAttribute('hidden'), 'After tab switches in place');
    BridgeCheck(Num(TJSObject(LPlayer), 'testPauseCount') > 0, 'Switching pauses the prior player');
    for I := 0 to 1 do
      AListener.El('audio-' + IntToStr(I)).dispatchEvent(TJSEvent.new('canplay'));
    BridgeCheck(not AListener.El('answer').hasAttribute('hidden'),
      'Two generated clips suffice; optional original is not a voting prerequisite');
    TJSHTMLInputElement(document.querySelector('input[value=after]')).checked := True;
    LTransaction := AListener.BuildTransaction;
    BridgeCheck((Arr(LTransaction, 'choices').length = 1) and
      (Str(Obj(Arr(LTransaction, 'choices')[0]), 'value') = 'after'), 'One clear answer');
    BridgeCheck(Arr(LTransaction, 'comments').length = 0, 'Notes are optional');
    LPlayer.currentTime := 20;
    TJSHTMLInputElement(AListener.El('comment-text')).value := 'Synthetic end-of-clip note';
    AListener.HandleAddComment(nil);
    BridgeCheck(Num(Obj(AListener.FComments[0]), 'frame') = 159999,
      'A note at the finished playhead binds the last valid frame');
    AListener.Save;
    await(BridgeTurn);
    BridgeCheck((BridgeWrites = 1) and not AListener.FSaving and
      (AListener.FRequest <> nil), 'Lost write response preserves the visible answer');
    AListener.Save;
    await(BridgeTurn);
    BridgeCheck((BridgeWrites = 1) and (AListener.FPending.length = 0) and
      (AListener.FRequest = nil), 'Retry reconciles and Save/Next reaches the empty queue');
    AListener.ApplyQueue(Obj(Cloned(BridgeQueue)), 'qa-experiment', False);
    BridgeCheck(TJSHTMLInputElement(document.querySelector('input[value=after]')).checked,
      'Reload restores the saved choice');
    AListener.HandlePageHide(nil);
    BridgeCheck(document.querySelector('audio[src]') = nil,
      'Leaving releases every audio source, including Original');
    BridgeQueue := Obj(TJSJSON.parse('{"items":[],"completed":[]}'));
    LRow := Obj(TJSJSON.parse('{"id":"qa-single","task_id":"NS-5_continuity_01",' +
      '"kind":"single","question":"Does this clip get stuck in a short loop?",' +
      '"request_sha256":"qa-single-bound","revision":0,' +
      '"assets":[{"id":"generated","storage":"listening","role":"generated",' +
      '"sample_rate":8000,"channels":1,"frames":160000}],' +
      '"ranges":[{"asset_id":"generated","start_frame":0,"end_frame":160000}],' +
      '"answer_spec":{"choices":[{"id":"listening_answer",' +
      '"values":["yes","no","unknown"]}],"scores":[]},' +
      '"experiment":{"title":"Long playback","change":"Retained experimental clip.",' +
      '"decision":"Judge repeated patterns, without retraining.","reference":{' +
      '"request_id":"original","asset_id":"reference","request_sha256":"qa-original"}}}'));
    Arr(BridgeQueue, 'items').push(LRow);
    AListener.ApplyQueue(Obj(Cloned(BridgeQueue)), '', False);
    LButtons := document.querySelectorAll('.sample-switch button');
    BridgeCheck((LButtons.length = 2) and
      (LButtons[1].textContent = 'Generated'), 'Single Original and Generated tabs');
    TJSHTMLElement(LButtons[0]).click;
    BridgeCheck(not AListener.El('original-context').hasAttribute('hidden') and
      AListener.El('sample-card-0').hasAttribute('hidden'), 'Open original in place');
    TJSHTMLElement(LButtons[1]).click;
    BridgeCheck(AListener.El('original-context').hasAttribute('hidden') and
      not AListener.El('sample-card-0').hasAttribute('hidden'), 'Return to generated single');
    Obj(LRow['experiment'])['reference'] := Undefined;
    AListener.ApplyQueue(Obj(Cloned(BridgeQueue)), '', False);
    BridgeCheck(document.querySelector('.sample-switch') = nil,
      'Single without Original needs no empty comparison toolbar');
    BridgeCheck(document.querySelectorAll('input[type=radio]').length = 3,
      'Single has yes, no and uncertainty choices');
    BridgeCheck(document.querySelector('input[type=radio]:checked') = nil,
      'Single has no automatic answer');
    TJSHTMLAudioElement(AListener.El('audio-0')).dispatchEvent(TJSEvent.new('canplay'));
    TJSHTMLInputElement(document.querySelector('input[value=unknown]')).checked := True;
    LTransaction := AListener.BuildTransaction;
    BridgeCheck((Str(Obj(Arr(LTransaction, 'choices')[0]), 'value') = 'unknown') and
      (Arr(LTransaction, 'scores').length = 0) and
      (Arr(LTransaction, 'comments').length = 0), 'Single uncertainty with optional notes');
    TJSHTMLElement(document.querySelector('.original-reference')).setAttribute('open', '');
    document.querySelector('.original-reference').dispatchEvent(TJSEvent.new('toggle'));
    await(BridgeTurn);
    BridgeCheck(Pos('unavailable', document.querySelector(
      '.original-reference [role=status]').textContent) > 0,
      'Missing source context is explicit and is not unrelated Original audio');
    BridgeWrites := 0;
    AListener.Save;
    await(BridgeTurn);
    AListener.Save;
    await(BridgeTurn);
    BridgeCheck((BridgeWrites = 1) and (AListener.FPending.length = 0),
      'Single Save/Next reconciles a lost response without a duplicate write');
    AListener.ApplyQueue(Obj(Cloned(BridgeQueue)), 'qa-single', False);
    BridgeCheck(TJSHTMLInputElement(document.querySelector('input[value=unknown]')).checked,
      'Single reload retains uncertainty');
    AListener.HandlePageHide(nil);
    BridgeCheck(document.querySelector('audio[src]') = nil,
      'Leaving single releases generated and optional source audio');
    document.body.setAttribute('data-test-result', 'PASS ' + IntToStr(BridgeChecks) + ' listening bridge checks');
  except
    on E: Exception do document.body.setAttribute('data-test-result', 'FAIL ' + E.Message);
  else document.body.setAttribute('data-test-result', 'FAIL unhandled listener exception');
  end;
end;
