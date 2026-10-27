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
program pythian_tests_studio_live_policy;
{$mode delphi}{$H+}
uses JS, Web, SysUtils, pythian.studio.live;
type
  TChecks = class
    PreflightPolicy: String;
    JobPolicy: String;
    InheritedPolicy: String;
    Preflights: Integer;
    Jobs: Integer;
    Cancels: Integer;
    Reads: Integer;
    function Build: TJSObject;
    function Fetch(const APath, AMethod, ABody: String): TJSPromise;
    procedure Run; async;
  end;
var GChecks: Integer;
procedure Check(const AValue: Boolean; const AMessage: String);
begin
  Inc(GChecks);
  if not AValue then
  begin
    raise Exception.Create(AMessage);
  end;
end;
function Response(const AData: TJSObject): TJSObject;
begin
  Result := TJSObject.new;
  Result['status'] := 200;
  Result['json'] := function: TJSPromise
    begin
      Result := TJSPromise.resolve(AData);
    end;
end;
function TChecks.Build: TJSObject;
begin
  Result := TJSObject(TJSJSON.parse('{"job_id":"live-qa","seeds":[731,1731]}'));
  Result['reconstruction'] := InheritedPolicy;
end;
function TChecks.Fetch(const APath, AMethod, ABody: String): TJSPromise;
var LData, LRequest: TJSObject;
begin
  LData := TJSObject.new;
  if APath = '/api/studio/preflight' then
  begin
    Inc(Preflights);
    LRequest := TJSObject(TJSJSON.parse(ABody));
    PreflightPolicy := String(LRequest['reconstruction']);
    Check((String(LRequest['kind'])='stream_generate') and
      (TJSArray(LRequest['seeds']).length=1), 'Live preflight request');
    LData['sample_rate'] := 8000;
    LData['selected_seconds'] := 20;
  end
  else if APath = '/api/studio/job' then
  begin
    Inc(Jobs);
    LRequest := TJSObject(TJSJSON.parse(ABody));
    JobPolicy := String(LRequest['reconstruction']);
    Check((String(LRequest['kind'])='stream_generate') and
      (TJSArray(LRequest['seeds']).length=1), 'Live job request');
  end
  else if APath = '/api/studio/cancel' then
  begin
    Inc(Cancels);
  end
  else
  begin
    Inc(Reads);
    LData['total_frames'] := 0;
    LData['stage'] := 'verify_sources';
  end;
  Result := TJSPromise.resolve(Response(LData));
end;
function WaitTurn: TJSPromise;
begin
  Result := TJSPromise.new(procedure(AResolve, AReject: TJSPromiseResolver)
    begin
      window.setTimeout(procedure() begin AResolve(Undefined); end, 2);
    end);
end;
procedure TChecks.Run; async;
var
  LLive: TStudioLive;
  LProject: TJSObject;
  LSelect: TJSHTMLSelectElement;
  LBefore: Integer;
  LIndex: Integer;
begin
  LLive := nil;
  try
    LProject := TJSObject(TJSJSON.parse('{"name":"QA","project_id":"qa"}'));
    LLive := TStudioLive.Create(@Fetch, @Build);
    LLive.SetProject(LProject, True);
    LSelect := TJSHTMLSelectElement(document.getElementById('live-reconstruction'));
    Check((LSelect.value='sparse') and (LSelect.options.length=2), 'Explicit standard default');
    Check(Pos('Sound joins', LSelect.parentElement.textContent)>0, 'Visible sound joins label');
    Check(document.getElementById('live-start').textContent='▶ Generate & play', 'Start glyph');
    Check(document.getElementById('live-pause').textContent='Ⅱ Pause', 'Pause glyph');
    Check(document.getElementById('live-stop').textContent='■ Stop', 'Stop glyph');
    Check(LSelect.options[1].textContent='Use neighboring fragments · Experimental',
      'Experimental option glyph');
    InheritedPolicy := 'source_successor';
    TJSHTMLElement(document.getElementById('live-start')).click;
    Check(document.getElementById('live-status').textContent='Checking your saved selections…',
      'Checking status ellipsis');
    for LIndex := 1 to 8 do await(WaitTurn);
    Check((PreflightPolicy='sparse') and (JobPolicy='sparse') and
      (Preflights=1) and (Jobs=1), 'Live choice overrides audition successor');
    Check(LSelect.disabled, 'Policy disabled during playback');
    Check(Pos(' · ', document.getElementById('live-source').textContent)>0,
      'Source context separator');
    TJSHTMLElement(document.getElementById('live-pause')).click;
    for LIndex := 1 to 4 do await(WaitTurn);
    Check(document.getElementById('live-pause').textContent='▶ Resume',
      'Pause retains session and offers resume');
    TJSHTMLElement(document.getElementById('live-pause')).click;
    for LIndex := 1 to 4 do await(WaitTurn);
    Check(document.getElementById('live-pause').textContent='Ⅱ Pause',
      'Resume restores pause control');
    TJSHTMLElement(document.getElementById('live-stop')).click;
    for LIndex := 1 to 4 do await(WaitTurn);
    Check((Cancels=1) and not LSelect.disabled, 'Stop cancels and restores policy control');
    InheritedPolicy := 'sparse';
    LSelect.value := 'source_successor';
    TJSHTMLElement(document.getElementById('live-start')).click;
    for LIndex := 1 to 8 do await(WaitTurn);
    Check((PreflightPolicy='source_successor') and (JobPolicy='source_successor') and
      (Preflights=2) and (Jobs=2), 'Successor reaches preflight and job');
    TJSHTMLElement(document.getElementById('live-stop')).click;
    for LIndex := 1 to 4 do await(WaitTurn);
    Check((Cancels=2) and not LSelect.disabled, 'Second stop restores control');
    LSelect.value := '';
    TJSHTMLElement(document.getElementById('live-start')).click;
    for LIndex := 1 to 4 do await(WaitTurn);
    Check((Preflights=2) and (Jobs=2), 'Invalid choice cannot silently downgrade');
    LLive.Free;
    LLive := nil;
    LBefore := Reads;
    for LIndex := 1 to 12 do await(WaitTurn);
    Check(Reads=LBefore, 'Destroyed component stops polling');
    document.body.setAttribute('data-test-result', 'PASS '+IntToStr(GChecks)+' live policy checks');
  except
    on E: Exception do document.body.setAttribute('data-test-result', 'FAIL '+E.Message);
  else
    document.body.setAttribute('data-test-result', 'FAIL unhandled test exception');
  end;
  LLive.Free;
end;
var Runner: TChecks;
begin
  Runner := TChecks.Create;
  Runner.Run;
end.
