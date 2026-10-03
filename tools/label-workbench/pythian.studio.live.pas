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
unit pythian.studio.live;

{$mode delphi}
{$H+}

interface

uses
  JS, Web, WebAudio, SysUtils, Math, pythian.time,
  pythian.studio.sources, pythian.studio.requests, pythian.studio.progress;

type
  TStudioLiveRequest = function: TJSObject of object;
  TLiveQueuedAudio = record
    Node: TJSAudioBufferSourceNode;
    StartsAt, EndsAt, FirstFrame, Frames: Double;
  end;
  TStudioLive = class
  private
    FFetch: TStudioFetch;
    FBuildRequest: TStudioLiveRequest;
    FProject: TJSObject;
    FAllowed, FActive, FPaused, FComplete, FExcerptRequested: Boolean;
    FBusyEpoch: Integer;
    FEpoch, FSequence, FRate: Integer;
    FJobId: String;
    FContext: TJSAudioContext;
    FQueue: array of TLiveQueuedAudio;
    FNextAt, FReceived, FPlayed, FTotal, FLastStatus: Double;
    FTimer: NativeInt;
    FState: TJSObject;
    function El(const AId: String): TJSElement;
    function Add(AParent: TJSElement; const ATag, AText, AId: String): TJSElement;
    procedure Button(AParent: TJSElement; const AText, AId: String);
    procedure Layout;
    procedure Controls;
    procedure Notice(const AText: String; const AError: Boolean = False);
    procedure Progress;
    procedure CloseAudio;
    function Json(const APath, AMethod, ABody: String): TJSObject; async;
    procedure Start; async;
    procedure Poll; async;
    procedure TogglePause; async;
    procedure Stop; async;
    procedure Excerpt; async;
    function Click(AEvent: TJSMouseEvent): Boolean;
    function Leaving(AEvent: TEventListenerEvent): Boolean;
  public
    constructor Create(const AFetch: TStudioFetch; const ABuildRequest: TStudioLiveRequest);
    destructor Destroy; override;
    procedure SetProject(AProject: TJSObject; const AEnabled: Boolean);
  end;

implementation

function TStudioLive.El(const AId: String): TJSElement;
begin
  Result := document.getElementById(AId);
end;

function TStudioLive.Add(AParent: TJSElement; const ATag, AText, AId: String): TJSElement;
begin
  Result := document.createElement(ATag);
  Result.textContent := AText;
  if AId <> '' then Result.id := AId;
  AParent.appendChild(Result);
end;

procedure TStudioLive.Button(AParent: TJSElement; const AText, AId: String);
var LButton: TJSElement;
begin
  LButton := Add(AParent, 'button', AText, AId);
  LButton.setAttribute('type', 'button');
  LButton.addEventListener('click', @Click);
end;

procedure TStudioLive.Layout;
var LRoot, LRow, LLabel, LInput, LOption: TJSElement;
begin
  LRoot := El('studio-live');
  Add(LRoot, 'h3', 'Generate and play', '');
  Add(LRoot, 'p', 'Experimental · choose a length, then listen as Pythian generates.', '');
  LRow := Add(LRoot, 'div', '', '');
  LRow.className := 'range-fields';
  LLabel := Add(LRow, 'label', 'Length', '');
  LInput := Add(LLabel, 'input', '', 'live-duration');
  LInput.setAttribute('type', 'text');
  LInput.setAttribute('inputmode', 'decimal');
  LInput.setAttribute('value', '2');
  LInput.setAttribute('maxlength', '10');
  LLabel := Add(LRow, 'label', 'Time unit', '');
  LInput := Add(LLabel, 'select', '', 'live-unit');
  LOption := Add(LInput, 'option', 'Seconds', ''); LOption.setAttribute('value', '1');
  LOption := Add(LInput, 'option', 'Minutes', ''); LOption.setAttribute('value', '60');
  LOption := Add(LInput, 'option', 'Hours', ''); LOption.setAttribute('value', '3600');
  TJSHTMLSelectElement(LInput).value := '60';
  LRow := Add(LRoot, 'div', '', '');
  LRow.className := 'source-toolbar';
  LRow.setAttribute('role', 'group');
  LRow.setAttribute('aria-label', 'Live playback');
  Button(LRow, '▶ Generate & play', 'live-start');
  El('live-start').className := 'primary';
  Button(LRow, 'Ⅱ Pause', 'live-pause');
  Button(LRow, '■ Stop', 'live-stop');
  LInput := Add(LRoot, 'p', 'Save a project, then choose how long to play.', 'live-status');
  LInput.className := 'notice';
  LInput.setAttribute('role', 'status');
  LInput.setAttribute('aria-live', 'polite');
  Add(LRoot, 'div', '', 'live-learning-progress');
  Add(LRoot, 'p', '', 'live-clock');
  Add(LRoot, 'p', '', 'live-source');
  LRow := Add(LRoot, 'div', '', '');
  LRow.className := 'source-toolbar';
  Button(LRow, 'Save next 20 seconds for review', 'live-excerpt');
  LInput := Add(LRow, 'a', 'Listen, download WAV & give feedback', 'live-review');
  LInput.setAttribute('hidden', '');
  LInput := Add(LRoot, 'p', 'Up to 24 hours. Keep this page open to listen. ' +
    'Only saved excerpts are kept as WAV files.', '');
  LInput.className := 'hint';
end;

procedure TStudioLive.Notice(const AText: String; const AError: Boolean);
begin
  El('live-status').textContent := AText;
  if AError then El('live-status').className := 'notice error'
  else El('live-status').className := 'notice';
end;

procedure TStudioLive.Controls;
begin
  TJSHTMLButtonElement(El('live-start')).disabled := FActive or not FAllowed;
  TJSHTMLInputElement(El('live-duration')).disabled := FActive;
  TJSHTMLSelectElement(El('live-unit')).disabled := FActive;
  TJSHTMLButtonElement(El('live-pause')).disabled := not FActive or (FContext = nil);
  TJSHTMLButtonElement(El('live-stop')).disabled := not FActive;
  TJSHTMLButtonElement(El('live-excerpt')).disabled := not FActive or FComplete or FExcerptRequested or
    (StudioNumber(FState, 'total_frames') = 0) or
    (StudioText(FState, 'excerpt_status') <> 'available');
  if FPaused then El('live-pause').textContent := '▶ Resume'
  else El('live-pause').textContent := 'Ⅱ Pause';
end;

procedure TStudioLive.SetProject(AProject: TJSObject; const AEnabled: Boolean);
begin
  FProject := AProject;
  FAllowed := AEnabled and (FProject <> nil);
  if not FActive and (FReceived = 0) and (FEpoch = 0) and FAllowed then
    Notice('Choose a length, then Generate & play.');
  Controls;
end;

procedure TStudioLive.CloseAudio;
var LItem: TLiveQueuedAudio;
begin
  for LItem in FQueue do
  begin
    LItem.Node.stop;
    LItem.Node.disconnect;
  end;
  FQueue := nil;
  if FContext <> nil then
  begin
    FContext.close;
    FContext := nil;
  end;
end;

function TStudioLive.Json(const APath, AMethod, ABody: String): TJSObject; async;
var LResponse: TJSResponse; LText: String;
begin
  LResponse := TJSResponse(await(JSValue, AwaitStudioPromise(FFetch(APath, AMethod, ABody), 15)));
  if (LResponse.status <> 200) and (LResponse.status <> 202) then
  begin
    LText := String(await(JSValue, AwaitStudioPromise(LResponse.text(), 15)));
    raise Exception.Create(Copy(Trim(LText), 1, 256));
  end;
  Result := TJSObject(await(JSValue, AwaitStudioPromise(LResponse.json(), 15)));
end;

procedure TStudioLive.Start; async;
var LRequest, LPlan, LReply: TJSObject; LOptions: TJSAudioContextOptions;
  LSeconds, LValue: Double; LEpoch: Integer; LSeeds: TJSArray;
begin
  if FActive or not FAllowed then Exit;
  Inc(FEpoch); LEpoch := FEpoch;
  try
    if not TryStrToFloat(TJSHTMLInputElement(El('live-duration')).value, LValue) then
      raise Exception.Create('Enter a length such as 2 or 2.5.');
    LSeconds := LValue * StrToInt(TJSHTMLSelectElement(El('live-unit')).value);
    if not ((LSeconds >= 1) and (LSeconds <= 86400)) then
      raise Exception.Create('Choose a length from 1 second to 24 hours.');
    LRequest := FBuildRequest();
    LRequest['kind'] := 'stream_generate';
    LRequest['duration_ms'] := SampleFramesFromSeconds(LSeconds, 1000, frFloor);
    LSeeds := TJSArray.new;
    LSeeds.push(TJSArray(LRequest['seeds'])[0]);
    LRequest['seeds'] := LSeeds;
    FActive := True; FPaused := False; FComplete := False;
    FExcerptRequested := False;
    FJobId := ''; FSequence := 0; FReceived := 0; FPlayed := 0; FNextAt := 0;
    FState := nil; FLastStatus := 0;
    El('live-clock').textContent := '';
    El('live-source').textContent := '';
    El('live-review').setAttribute('hidden', '');
    El('live-excerpt').textContent := 'Save next 20 seconds for review';
    Controls;
    Notice('Checking your saved selections…');
    LPlan := await(TJSObject, Json('/api/studio/preflight', 'POST', TJSJSON.stringify(LRequest)));
    if LEpoch <> FEpoch then Exit;
    FRate := Trunc(StudioNumber(LPlan, 'sample_rate'));
    FTotal := 0; { The native session publishes its exact integer frame extent. }
    LOptions := TJSAudioContextOptions.new;
    LOptions.sampleRate := FRate;
    FContext := TJSAudioContext.new(LOptions);
    await(JSValue, AwaitStudioPromise(FContext.resume(), 15));
    if LEpoch <> FEpoch then Exit;
    if FContext.sampleRate <> FRate then
      raise Exception.Create('This browser cannot play the recording sample rate. Prepare a supported rate first.');
    FJobId := StudioText(LRequest, 'job_id');
    El('live-source').textContent := StudioText(FProject, 'name') + ' · ' +
      StudioTime(StudioNumber(LPlan, 'selected_seconds')) + ' of source music · seed ' +
      IntToStr(Trunc(Double(LSeeds[0])));
    Notice('Preparing your selected recordings…');
    LReply := await(TJSObject, Json('/api/studio/job', 'POST', TJSJSON.stringify(LRequest)));
    if LEpoch <> FEpoch then Exit;
    Controls;
    Poll;
  except
    on E: Exception do
    begin
      if LEpoch = FEpoch then
      begin
        Stop;
        Notice(E.Message, True);
      end;
    end;
  else
    begin
      if LEpoch = FEpoch then
      begin
        Stop;
        Notice('Could not start audio. Reconnect, then try Generate & play.', True);
      end;
    end;
  end;
end;

procedure TStudioLive.Progress;
var LNow, LQueued: Double; LIndex: Integer;
begin
  if FContext = nil then Exit;
  LNow := FContext.currentTime;
  while (Length(FQueue) > 0) and (LNow >= FQueue[0].EndsAt) do
  begin
    FPlayed := FQueue[0].FirstFrame + FQueue[0].Frames;
    FQueue[0].Node.disconnect;
    for LIndex := 1 to High(FQueue) do FQueue[LIndex - 1] := FQueue[LIndex];
    SetLength(FQueue, Length(FQueue) - 1);
  end;
  if (Length(FQueue) > 0) and (LNow >= FQueue[0].StartsAt) then
    FPlayed := Min(FQueue[0].FirstFrame + FQueue[0].Frames,
      FQueue[0].FirstFrame + (LNow - FQueue[0].StartsAt) * FRate);
  LQueued := Max(0, FNextAt - LNow);
  El('live-clock').textContent := StudioTime(FPlayed / FRate) + ' / ' +
    StudioTime(FTotal / FRate) + ' · ' + FormatFloat('0.0', LQueued) + ' s buffered';
  if FComplete and (Length(FQueue) = 0) then
  begin
    FActive := False;
    CloseAudio;
    Notice('Finished. Generate again to replay from the beginning.');
    Controls;
  end
  else if FPaused then Notice('Paused. Your place is kept.')
  else if FReceived > 0 then
  begin
    if LQueued < 0.05 then Notice('Buffering…') else Notice('Playing.');
  end;
end;

procedure TStudioLive.Poll; async;
var LEpoch, LIndex: Integer; LReply, LCommand: TJSObject;
  LResponse: TJSResponse; LBytes: TJSArrayBuffer; LBuffer: TJSAudioBuffer;
  LStart, LEnd, LFrames: Double; LId: String;
begin
  if (FBusyEpoch = FEpoch) or not FActive or (FJobId = '') then Exit;
  LEpoch := FEpoch; FBusyEpoch := LEpoch;
  try
    try
      Progress;
      if not FActive then Exit;
      if not FPaused and not FComplete and (FNextAt - FContext.currentTime < 3) then
      begin
        LReply := await(TJSObject, Json('/api/studio/live?id=' + encodeURIComponent(FJobId), 'GET', ''));
        if LEpoch <> FEpoch then Exit;
        FState := LReply;
        if (StudioText(LReply, 'job_status') = 'failed') or
          (StudioText(LReply, 'job_status') = 'cancelled') then
          raise Exception.Create(StudioText(LReply, 'error_message') + ' Start a new session.');
        if StudioNumber(LReply, 'total_frames') = 0 then
        begin
          Notice(StudioStageText(StudioText(LReply, 'stage')));
          El('live-learning-progress').innerHTML := '';
          DrawStudioProgress(El('live-learning-progress'), LReply);
        end
        else
        begin
          El('live-learning-progress').innerHTML := '';
          FTotal := StudioNumber(LReply, 'total_frames');
          LCommand := TJSObject.new;
          LCommand['job_id'] := FJobId; LCommand['action'] := 'pull';
          LCommand['sequence'] := FSequence;
          LReply := await(TJSObject, Json('/api/studio/live', 'POST', TJSJSON.stringify(LCommand)));
          if LEpoch <> FEpoch then Exit;
          FState := LReply;
          if StudioNumber(LReply, 'sequence') = FSequence then
          begin
            LStart := StudioNumber(LReply, 'start_frame');
            LEnd := StudioNumber(LReply, 'position'); LFrames := LEnd - LStart;
            if (LStart <> FReceived) or (LFrames < 1) or (LFrames > 65536) then
              raise Exception.Create('Audio continuity changed. Start a new session.');
            LResponse := TJSResponse(await(JSValue, AwaitStudioPromise(FFetch(
              '/api/studio/live-audio?id=' + encodeURIComponent(FJobId) +
              '&sequence=' + IntToStr(FSequence), 'GET', ''), 15)));
            if LResponse.status <> 200 then raise Exception.Create('Audio chunk unavailable. Reconnect and restart.');
            LBytes := TJSArrayBuffer(await(JSValue, AwaitStudioPromise(LResponse.arrayBuffer(), 15)));
            if LEpoch <> FEpoch then Exit;
            LBuffer := TJSAudioBuffer(await(JSValue, AwaitStudioPromise(FContext.decodeAudioData(LBytes), 15)));
            if LEpoch <> FEpoch then Exit;
            if (LBuffer.length_ <> LFrames) or (LBuffer.sampleRate <> FRate) then
              raise Exception.Create('Decoded audio clock differs. Choose a supported recording rate.');
            LIndex := Length(FQueue);
            if LIndex >= 32 then raise Exception.Create('Playback queue is full. Stop and retry.');
            SetLength(FQueue, LIndex + 1);
            FQueue[LIndex].Node := FContext.createBufferSource;
            FQueue[LIndex].Node.buffer := LBuffer;
            FQueue[LIndex].Node.connect(FContext.destination);
            FNextAt := Max(FNextAt, FContext.currentTime + 0.1);
            FQueue[LIndex].StartsAt := FNextAt;
            FNextAt := FNextAt + LBuffer.duration;
            FQueue[LIndex].EndsAt := FNextAt;
            FQueue[LIndex].FirstFrame := LStart; FQueue[LIndex].Frames := LFrames;
            FQueue[LIndex].Node.start(FQueue[LIndex].StartsAt);
            FReceived := LEnd; Inc(FSequence);
            FComplete := FReceived = FTotal;
          end;
        end;
        FLastStatus := TJSDate.now;
      end
      else if TJSDate.now - FLastStatus > 10000 then
      begin
        LReply := await(TJSObject, Json('/api/studio/live?id=' + encodeURIComponent(FJobId), 'GET', ''));
        if LEpoch <> FEpoch then Exit;
        FState := LReply; FLastStatus := TJSDate.now;
        if (StudioText(LReply, 'job_status') = 'failed') or
          (StudioText(LReply, 'job_status') = 'cancelled') then
          raise Exception.Create(StudioText(LReply, 'error_message') + ' Start a new session.');
      end;
      LId := StudioText(FState, 'listening_request_id');
      if LId <> '' then
      begin
        El('live-review').setAttribute('href', 'listen.html?request=' + encodeURIComponent(LId));
        El('live-review').removeAttribute('hidden');
        El('live-excerpt').textContent := 'Review excerpt saved';
      end
      else if StudioText(FState, 'excerpt_status') = 'recording' then
        El('live-excerpt').textContent := 'Saving review excerpt…';
      Progress;
      Controls;
    except
      on E: Exception do
      begin
        if LEpoch = FEpoch then begin Stop; Notice(E.Message, True) end;
      end;
    else
      if LEpoch = FEpoch then begin Stop; Notice('Playback disconnected. Reconnect and start again.', True) end;
    end;
  finally
    if FBusyEpoch = LEpoch then FBusyEpoch := -1;
    if (LEpoch = FEpoch) and FActive then
      if StudioNumber(FState, 'total_frames') = 0 then
        FTimer := window.setTimeout(procedure() begin Poll end, 500)
      else FTimer := window.setTimeout(procedure() begin Poll end, 100);
  end;
end;

procedure TStudioLive.TogglePause; async;
var LEpoch: Integer;
begin
  if not FActive or (FContext = nil) then Exit;
  LEpoch := FEpoch;
  FPaused := not FPaused;
  try
    if FPaused then await(JSValue, AwaitStudioPromise(FContext.suspend(), 15))
    else await(JSValue, AwaitStudioPromise(FContext.resume(), 15));
    if LEpoch = FEpoch then begin Progress; Controls end;
  except
    if LEpoch = FEpoch then begin Stop; Notice('Audio could not resume. Start again.', True) end;
  end;
end;

procedure TStudioLive.Stop; async;
var LCommand, LReply: TJSObject; LId: String; LEpoch: Integer;
begin
  LId := FJobId;
  Inc(FEpoch); LEpoch := FEpoch; FActive := False; FPaused := False;
  FJobId := '';
  window.clearTimeout(FTimer);
  CloseAudio; Controls;
  El('live-learning-progress').innerHTML := '';
  if (FRate > 0) and (FTotal > 0) then
    El('live-clock').textContent := StudioTime(FPlayed / FRate) + ' / ' +
      StudioTime(FTotal / FRate) + ' · 0.0 s buffered';
  Notice('Stopped. Generate again to start from the beginning.');
  if LId = '' then Exit;
  LCommand := TJSObject.new; LCommand['job_id'] := LId;
  try
    LReply := await(TJSObject, Json('/api/studio/cancel', 'POST', TJSJSON.stringify(LCommand)));
  except
    if LEpoch = FEpoch then
      Notice('Stopped here. If disconnected, the server stops within 90 seconds.');
  end;
end;

procedure TStudioLive.Excerpt; async;
var LCommand, LReply: TJSObject; LEpoch: Integer;
begin
  if not FActive or FComplete or FExcerptRequested then Exit;
  LEpoch := FEpoch; FExcerptRequested := True; Controls;
  LCommand := TJSObject.new; LCommand['job_id'] := FJobId; LCommand['action'] := 'excerpt';
  try
    LReply := await(TJSObject, Json('/api/studio/live', 'POST', TJSJSON.stringify(LCommand)));
    if LEpoch <> FEpoch then Exit;
    El('live-excerpt').textContent := 'Saving review excerpt…';
    TJSHTMLButtonElement(El('live-excerpt')).disabled := True;
  except
    on E: Exception do
      if LEpoch = FEpoch then begin FExcerptRequested := False; Controls; Notice(E.Message, True) end;
  end;
end;

function TStudioLive.Click(AEvent: TJSMouseEvent): Boolean;
begin
  Result := False;
  case TJSElement(AEvent.currentTarget).id of
    'live-start': Start;
    'live-pause': TogglePause;
    'live-stop': Stop;
    'live-excerpt': Excerpt;
  end;
end;

function TStudioLive.Leaving(AEvent: TEventListenerEvent): Boolean;
begin
  Result := False;
  if FActive then Stop;
end;

constructor TStudioLive.Create(const AFetch: TStudioFetch; const ABuildRequest: TStudioLiveRequest);
begin
  inherited Create;
  FFetch := AFetch; FBuildRequest := ABuildRequest;
  FBusyEpoch := -1;
  Layout; Controls;
  window.addEventListener('pagehide', @Leaving);
end;

destructor TStudioLive.Destroy;
begin
  window.removeEventListener('pagehide', @Leaving);
  window.clearTimeout(FTimer);
  Inc(FEpoch);
  CloseAudio;
  inherited Destroy;
end;

end.
