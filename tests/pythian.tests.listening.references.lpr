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
program ListeningReferences;

{$mode delphi}
{$H+}

uses JS, Web, SysUtils, pythian.listening.references, pythian.studio.reviews;

type
  TChecks = class
    Reads: Integer;
    Mode: String;
    Pending: TJSPromiseResolver;
    function Fetch(const APath, AMethod, ABody: String): TJSPromise;
    procedure Run; async;
  end;
var
  GChecks: Integer;

procedure Check(ACondition: Boolean; const AMessage: String);
begin
  Inc(GChecks);
  if not ACondition then raise Exception.Create(AMessage);
end;

function Reply: TJSObject;
begin
  Result := TJSObject.new;
  Result['status'] := 200;
  Result['json'] := function: TJSPromise
    begin
      Result := TJSPromise.resolve(TJSJSON.parse('{"format":"pythian.listening.references.v1","status":"ready","message":"Original selections; timelines do not align.","sources":[{"title":"First recording","source_sha256":"first","start_frame":5760000,"end_frame":9120000,"sample_rate":48000,"available":true},{"title":"Missing recording","source_sha256":"second","start_frame":14400000,"end_frame":14640000,"sample_rate":48000,"available":false}]}'));
    end;
end;

function TChecks.Fetch(const APath, AMethod, ABody: String): TJSPromise;
begin
  Inc(Reads);
  Check((AMethod = 'GET') and (ABody = '') and
    (APath = '/api/listen-references?request=qa&asset=audition'),
    'Reference metadata is an explicit read without job writes');
  if Mode = 'offline' then Exit(TJSPromise.reject('Disconnected'));
  if Mode = 'pending' then
    Exit(TJSPromise.new(procedure(Resolve, Reject: TJSPromiseResolver)
      begin
        Pending := Resolve;
      end));
  Result := TJSPromise.resolve(Reply);
end;

function WaitTurn: TJSPromise;
begin
  Result := TJSPromise.new(procedure(Resolve, Reject: TJSPromiseResolver)
    begin
      window.setTimeout(procedure() begin Resolve(Undefined); end, 10);
    end);
end;

procedure TChecks.Run; async;
var
  LRoot, LDetails, LClock: TJSElement;
  LReference: TListeningReference;
  LPlayer, LGenerated: TJSHTMLAudioElement;
  LSeek: TJSHTMLInputElement;
  LSelect: TJSHTMLSelectElement;
  LButtons: TJSNodeList;
  LBefore: Integer;
  LReview: TStudioReviews;
begin
  try
    LRoot := document.createElement('div');
    document.body.appendChild(LRoot);
    LGenerated := TJSHTMLAudioElement(document.createElement('audio'));
    LRoot.appendChild(LGenerated);
    LReference := TListeningReference.Create(LRoot, @Fetch,
      '/api/listen-references?request=qa&asset=audition');
    try
      LDetails := LRoot.querySelector('details');
      LPlayer := TJSHTMLAudioElement(LDetails.querySelector('audio'));
      Check((Reads = 0) and not LPlayer.hasAttribute('src'), 'Mount fetches no metadata or original PCM');
      LDetails.setAttribute('open', '');
      LDetails.dispatchEvent(TJSEvent.new('toggle'));
      await(WaitTurn);
      Check((Reads = 1) and (LPlayer.preload = 'none'), 'Opening loads only source metadata');
      Check(Pos('hash=first&start=5760000&end=7200000', LPlayer.src) > 0,
        'First preview starts at actual selection and spans only thirty seconds');
      Check(Pos(window.location.origin + '/api/audio?', LPlayer.src) = 1,
        'Original media preserves current origin');
      LSelect := TJSHTMLSelectElement(LDetails.querySelector('select'));
      Check((LSelect.options.length = 2) and (Pos('2:00', LSelect.textContent) > 0),
        'Source choices expose names and original selected times');
      LClock := LDetails.querySelector('.original-clock');
      LPlayer.currentTime := 7;
      LPlayer.dispatchEvent(TJSEvent.new('timeupdate'));
      Check(Pos('2:07', LClock.textContent) > 0, 'Original clock includes selection offset');
      LButtons := LDetails.querySelectorAll('.original-transport button');
      TJSHTMLElement(LButtons[1]).click;
      Check(Pos('start=7200000&end=8640000', LPlayer.src) > 0, 'Next advances by thirty source seconds');
      TJSHTMLElement(LButtons[1]).click;
      Check((Pos('start=8640000&end=9120000', LPlayer.src) > 0) and
        TJSHTMLButtonElement(LButtons[1]).disabled, 'Final preview clips to training selection');
      LSeek := TJSHTMLInputElement(LDetails.querySelector('input'));
      LSeek.value := '135';
      LSeek.dispatchEvent(TJSEvent.new('change'));
      Check(Pos('start=6480000&end=7920000', LPlayer.src) > 0, 'Seeking stays on the original clock');
      LGenerated.dispatchEvent(TJSEvent.new('play'));
      Check(Double(TJSObject(LPlayer)['testPauseCount']) > 0, 'Generated playback pauses original');
      LBefore := Trunc(Double(TJSObject(LGenerated)['testPauseCount']));
      LPlayer.dispatchEvent(TJSEvent.new('play'));
      Check(Double(TJSObject(LGenerated)['testPauseCount']) > LBefore, 'Original playback pauses generated audio');
      LDetails.removeAttribute('open');
      LDetails.dispatchEvent(TJSEvent.new('toggle'));
      Check(not LPlayer.hasAttribute('src'), 'Closing releases original media');
      LDetails.setAttribute('open', '');
      LDetails.dispatchEvent(TJSEvent.new('toggle'));
      Check(Reads = 1, 'Reopening reuses metadata without changing request');
      LSelect.value := '1';
      LSelect.dispatchEvent(TJSEvent.new('change'));
      Check(not LPlayer.hasAttribute('src') and LSeek.disabled and
        (Pos('missing', LClock.textContent) > 0), 'Missing original has no substitute audio');
      LSelect.value := '0';
      LSelect.dispatchEvent(TJSEvent.new('change'));
      window.dispatchEvent(TJSEvent.new('pagehide'));
      Check(not LPlayer.hasAttribute('src'), 'Leaving page releases original playback');
    finally
      LReference.Free;
    end;
    LRoot.textContent := '';
    Mode := 'offline';
    LReference := TListeningReference.Create(LRoot, @Fetch,
      '/api/listen-references?request=qa&asset=audition');
    LDetails := LRoot.querySelector('details');
    LDetails.setAttribute('open', '');
    LDetails.dispatchEvent(TJSEvent.new('toggle'));
    await(WaitTurn);
    Check(not LDetails.querySelector(':scope > button').hasAttribute('hidden'), 'Failed metadata offers retry');
    Mode := 'ok';
    TJSHTMLElement(LDetails.querySelector(':scope > button')).click;
    await(WaitTurn);
    Check(LDetails.querySelector('audio').hasAttribute('src'), 'Retry restores original reference');
    LReference.Free;
    LRoot.textContent := '';
    Mode := 'pending';
    LReference := TListeningReference.Create(LRoot, @Fetch,
      '/api/listen-references?request=qa&asset=audition');
    LDetails := LRoot.querySelector('details');
    LDetails.setAttribute('open', '');
    LDetails.dispatchEvent(TJSEvent.new('toggle'));
    LReference.Free;
    Pending(Reply);
    await(WaitTurn);
    Check(not LDetails.querySelector('audio').hasAttribute('src'), 'Late response cannot revive a closed review');
    LReview := TStudioReviews.Create(@Fetch, nil);
    try
      Check(not TJSHTMLInputElement(document.getElementById('review-blind')).checked,
        'Ordinary comparison allows originals before feedback; blind mode is explicit');
    finally
      LReview.Free;
    end;
    document.body.setAttribute('data-test-result', 'PASS ' + IntToStr(GChecks) + ' original-reference checks');
  except
    on E: Exception do document.body.setAttribute('data-test-result', 'FAIL ' + E.Message);
  end;
end;

var Checks: TChecks;
begin
  Checks := TChecks.Create;
  Checks.Run;
end.
