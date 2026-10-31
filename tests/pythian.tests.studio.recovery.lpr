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
program StudioRecovery;

{$mode delphi}
{$H+}
{$modeswitch externalclass}

uses JS, Web, SysUtils, pythian.studio.laboratory, pythian.studio.sources,
  pythian.studio.requests, pythian.studio.progress;

type
  TFixtureEvent = class external name 'Event' (TJSEvent)
    constructor new(const AType: String; const AOptions: TJSObject);
  end;
  TChecks = class
    Writes, Generated, Opened, Saved: Integer;
    Mode: String;
    LastWrite, Project: TJSObject;
    PendingResolve: TJSPromiseResolver;
    function Fetch(const APath, AMethod, ABody: String): TJSPromise;
    procedure OnGenerate(AProject: TJSObject);
    procedure OnSaved(AProject: TJSObject);
    procedure OnOpened(AProject: TJSObject);
    procedure Run; async;
  end;

var GChecks: Integer;

procedure Check(AValue: Boolean; const AMessage: String);
begin
  Inc(GChecks);
  if not AValue then raise Exception.Create(AMessage);
end;

function Response(AData: TJSObject): TJSObject;
begin
  Result := TJSObject.new;
  Result['status'] := 200;
  Result['json'] := function: TJSPromise
    begin Result := TJSPromise.resolve(AData) end;
end;

function TChecks.Fetch(const APath, AMethod, ABody: String): TJSPromise;
begin
  { Big Boss: fake HTTP boundary only. Native fixtures exercise real signed
    snapshots/admission/output. No musical behavior lives in this host. }
  Check(APath = '/api/studio/project', 'The form only saves settings, never queues a job');
  Check(AMethod = 'POST', 'This fixture exercises explicit project writes');
  Inc(Writes);
  LastWrite := TJSObject(TJSJSON.parse(ABody));
  Project := TJSObject.new;
  Project['project_id'] := LastWrite['project_id'];
  Project['revision'] := Double(LastWrite['expected_revision']) + 1;
  Project['name'] := LastWrite['name'];
  Project['instrumental'] := LastWrite['instrumental'];
  Project['snapshot_sha256'] := StringOfChar('a', 64);
  if Mode = 'offline' then Exit(TJSPromise.reject(Exception.Create('Offline fixture')));
  if Mode = 'hang' then
    Exit(TJSPromise.new(procedure(Resolve, Reject: TJSPromiseResolver)
      begin PendingResolve := Resolve end));
  Result := TJSPromise.resolve(Response(Project));
end;

procedure TChecks.OnGenerate(AProject: TJSObject);
begin
  Inc(Generated);
  Check(AProject <> nil, 'Generate receives saved settings');
  Check(String(AProject['snapshot_sha256']) = StringOfChar('a', 64), 'Generate uses saved lineage');
end;

procedure TChecks.OnSaved(AProject: TJSObject);
begin Inc(Saved) end;
procedure TChecks.OnOpened(AProject: TJSObject);
begin Inc(Opened) end;

procedure SetValue(const AId, AValue: String);
var LInput: TJSHTMLInputElement; LOptions: TJSObject;
begin
  LInput := TJSHTMLInputElement(document.getElementById(AId));
  LInput.value := AValue;
  LOptions := TJSObject.new; LOptions['bubbles'] := True;
  LInput.dispatchEvent(TFixtureEvent.new('change', LOptions));
end;

function Value(const AId: String): String;
begin Result := TJSHTMLInputElement(document.getElementById(AId)).value end;
procedure Click(const AId: String);
begin TJSHTMLElement(document.getElementById(AId)).click end;

function WaitTurn: TJSPromise;
begin
  Result := TJSPromise.new(procedure(Resolve, Reject: TJSPromiseResolver)
    begin window.setTimeout(procedure begin Resolve(Undefined) end, 1) end);
end;

procedure TChecks.Run; async;
var LLab: TStudioLaboratory; LBefore, LGenerated: Integer;
  LRetry, LId: String; LPending: JSValue; LResolve: TJSPromiseResolver; LReply, LProgress: TJSObject;
begin
  LLab := nil;
  try
    LLab := TStudioLaboratory.Create(document.body, @Fetch, @OnSaved, @OnGenerate, @OnOpened);
    LLab.SetScope('isolated-optional-lab');
    LLab.Open(TJSArray.new);
    Check(Generated = 0, 'Opening a laboratory never generates');
    Check(await(Boolean, LLab.Save), 'Default authored settings save');
    Check(not LastWrite.hasOwnProperty('playlist'), 'Authored settings never claim a recording playlist');
    Check(TJSArray(LastWrite['sources']).length = 0, 'Authored experiment is source-free');
    LId := LLab.ProjectId;
    Check(String(TJSObject(LastWrite['instrumental'])['tempo_bpm']) = '120', 'Default real tempo saved');
    SetValue('instrumental-tempo', '90');
    Check(await(Boolean, LLab.Save), 'Changed tempo saves');
    Check(String(TJSObject(LastWrite['instrumental'])['tempo_bpm']) = '90', 'Saved settings follow form');
    Click('lab-tab-2');
    Check(document.getElementById('lab-panel-0').hasAttribute('hidden'), 'Only the selected tab is shown');
    SetValue('instrumental-energy', '80');
    SetValue('instrumental-density', '70');
    SetValue('instrumental-tension', '30');
    Click('instrumental-apply-affect');
    Check(Value('instrumental-velocity-0') = '130', 'Primary energy mapping reaches real controls');
    Check(Value('instrumental-activity-2') = '40', 'Primary density mapping reaches Lead activity');
    Check(Value('instrumental-tonic-bias') = '40', 'Primary tension mapping reaches root preference');
    Check(Generated = 0, 'Applying feel never generates');
    SetValue('instrumental-guide', 'free');
    Check(await(Boolean, LLab.Save), 'Mapped controls save');
    Check(not Boolean(TJSObject(TJSObject(LastWrite['instrumental'])['controls'])['guide']),
      'Explicit WFC guide choice reaches the saved recipe');
    Click('lab-tab-1');
    SetValue('lab-part', '2');
    Check(not document.getElementById('lab-role-2').hasAttribute('hidden'), 'Part selector shows Lead');
    Check(document.getElementById('lab-role-0').hasAttribute('hidden'), 'Part selector hides Bass');
    LBefore := Writes;
    SetValue('instrumental-minimum-2', '100');
    SetValue('instrumental-maximum-2', '10');
    Check(not await(Boolean, LLab.Save), 'Contradictory range refuses saving');
    Check(Writes = LBefore, 'Invalid settings do not cross the HTTP boundary');
    Check(TJSHTMLButtonElement(document.getElementById('lab-generate')).disabled, 'Invalid settings disable Generate');
    SetValue('instrumental-minimum-2', '0');
    SetValue('instrumental-maximum-2', '127');
    Mode := 'offline';
    SetValue('instrumental-tempo', '100');
    Check(not await(Boolean, LLab.Save), 'Disconnected save retains the pending write');
    LRetry := TJSJSON.stringify(LastWrite);
    SetValue('instrumental-tempo', '110');
    Mode := '';
    Check(not await(Boolean, LLab.Save), 'Reconcile the old write before new settings');
    Check(TJSJSON.stringify(LastWrite) = LRetry, 'Retry sends exactly the same immutable write');
    Check(await(Boolean, LLab.Save), 'The newer settings then save');
    Check(Value('instrumental-tempo') = '110', 'Retry does not roll back newer form edits');
    Check(Generated = 0, 'Reconnection never generates');
    LLab.Free;
    LLab := TStudioLaboratory.Create(document.body, @Fetch, @OnSaved, @OnGenerate, @OnOpened);
    LLab.SetScope('isolated-optional-lab');
    LLab.Open(TJSArray.new);
    Check(LLab.ProjectId = LId, 'Browser reopening retains the real experiment');
    Check(Value('instrumental-tempo') = '110', 'Browser reopening retains changed tempo');
    Check(Value('instrumental-energy') = '80', 'Browser reopening retains helper inputs');
    Check(Value('instrumental-velocity-0') = '130', 'Browser reopening retains mapped controls');
    Click('lab-help');
    Check(document.getElementById('laboratory-help').hasAttribute('open'), 'Contextual help opens a modal');
    Click('lab-help-close');
    Check(document.getElementById('laboratory-dialog').hasAttribute('open'), 'Closing help keeps the current experiment open');
    Click('lab-generate');
    await(JSValue, WaitTurn);
    Check(Generated = 1, 'Only explicit Generate invokes the normal job controller');
    LGenerated := Generated;
    Mode := 'hang';
    SetValue('instrumental-tempo', '91');
    LPending := LLab.Save;
    await(JSValue, WaitTurn);
    LResolve := PendingResolve; LReply := Project;
    SetValue('instrumental-tempo', '92');
    LResolve(Response(LReply));
    Check(not await(Boolean, LPending), 'Late save cannot accept newer unsaved settings');
    Mode := '';
    Check(await(Boolean, LLab.Save), 'The newer settings save after the older response');
    Check(String(TJSObject(LastWrite['instrumental'])['tempo_bpm']) = '92', 'Late response preserves current controls');
    LLab.SetGenerationAvailable(False);
    Check(TJSHTMLButtonElement(document.getElementById('lab-generate')).disabled, 'Active native work disables another Generate');
    Click('lab-generate'); await(JSValue, WaitTurn);
    Check(Generated = LGenerated, 'Disabled Generate cannot queue work');
    LLab.SetGenerationAvailable(True);
    Mode := 'hang'; SetValue('instrumental-tempo', '93');
    LPending := LLab.Save;
    await(JSValue, WaitTurn);
    LResolve := PendingResolve; LReply := Project; LBefore := Saved;
    LLab.Free; LLab := nil;
    LResolve(Response(LReply));
    await(Boolean, LPending);
    Check(Saved = LBefore, 'Disposed forms ignore late transport responses');
    Check(document.getElementById('laboratory-dialog') = nil, 'Disposed form leaves no obsolete UI owner');
    Check(Generated = LGenerated, 'No hidden generation during save/disposal');
    LProgress := TJSObject(TJSJSON.parse('{"kind":"instrumental_generate","status":"running","stage":"instrumental_prepare","request":{"instrumental":{}},"workflow":{"phase":1,"done":0,"total":0,"unit":""}}'));
    DrawStudioProgress(document.body, LProgress, True);
    Check(Pos('Prepare the music', document.body.textContent) > 0, 'Authored work has an honest preparation label');
    Check(Pos('Learn your music', document.body.textContent) = 0, 'Authored progress does not claim recording learning');
    document.body.textContent := '';
    TJSObject(LProgress['request'])['duration_ms'] := 2000;
    DrawStudioProgress(document.body, LProgress, True);
    Check(Pos('Learn your music', document.body.textContent) > 0, 'Recording learning keeps its distinct workflow');
    document.body.setAttribute('data-test-result', 'PASS ' + IntToStr(GChecks) + ' active laboratory recovery checks');
  except
    on E: Exception do document.body.setAttribute('data-test-result', 'FAIL ' + E.Message);
  end;
  LLab.Free;
end;

begin
  TChecks.Create.Run;
end.
