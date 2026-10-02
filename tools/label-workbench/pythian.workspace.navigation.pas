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
unit pythian.workspace.navigation;

{$mode delphi}
{$H+}
{$modeswitch externalclass}

interface

uses
  JS,
  Web,
  SysUtils;

type
  TWorkspaceFetch = function(const APath, AMethod, ABody: String;
    const ASignal: TJSObject): TJSPromise of object;

  TWorkspaceAbortController = class external name 'AbortController' (TJSObject)
  private
    FSignal: TJSObject; external name 'signal';
  public
    constructor new;
    procedure abort;
    property Signal: TJSObject read FSignal;
  end;

  TWorkspaceCount = record
    State: String;
    Count: Integer;
    Attention: Integer;
    InFlight: Boolean;
    Again: Boolean;
    Timeout: NativeInt;
    Epoch: NativeInt;
    Controller: TWorkspaceAbortController;
  end;

  { The page supplies its existing authenticated transport and calls Start once
    its session is ready. The transport must pass ASignal to the native Fetch.
    Each route owns at most one current request; cancellation aborts that Fetch
    before releasing the route, and obsolete callbacks cannot change its state. }
  TWorkspaceNavigation = class
  private
    FFetch: TWorkspaceFetch;
    FCurrentPage: String;
    FStarted: Boolean;
    FConnected: Boolean;
    FPaused: Boolean;
    FTimer: NativeInt;
    FCounts: array[0..2] of TWorkspaceCount;
    FLinks: array[0..2] of TJSElement;
    FBadges: array[0..2] of TJSElement;
    FDetails: array[0..2] of TJSElement;
    FNextText: TJSElement;
    FNextLink: TJSElement;
    FRefreshButton: TJSElement;
    function Visible: Boolean;
    function Add(AParent: TJSElement; const ATag, AText, AClass: String): TJSElement;
    procedure Layout;
    procedure Draw;
    procedure Schedule;
    procedure CancelRoute(const ARoute: Integer; const AUnavailable: Boolean);
    procedure ReadCount(const ARoute: Integer; AData: TJSObject);
    procedure Load(const ARoute: Integer); async;
    function Changed(AEvent: TEventListenerEvent): Boolean;
    function Leaving(AEvent: TEventListenerEvent): Boolean;
    function Returning(AEvent: TEventListenerEvent): Boolean;
    function Click(AEvent: TJSMouseEvent): Boolean;
  public
    constructor Create(const AFetch: TWorkspaceFetch; const ACurrentPage: String);
    destructor Destroy; override;
    procedure Start;
    procedure Refresh;
    procedure ConnectionFailed;
  end;

{ A response-chain observer: successful writes notify mounted navigation without
  changing the response, consuming its body, or triggering writes themselves. }
function WorkspaceResponseSaved(AValue: JSValue): JSValue;
function SourceQuestionIsAppCheck(const AQuestion: String): Boolean;

implementation

const
  CPages: array[0..2] of String = ('studio', 'source', 'listening');
  CTitles: array[0..2] of String = ('Studio', 'Source reviews', 'Listening reviews');
  CPaths: array[0..2] of String = ('/studio.html', '/', '/listen.html');
  CApis: array[0..2] of String =
    ('/api/studio/reviews', '/api/review-queue', '/api/listen-queue');
  CIcons: array[0..2] of String = (
    'M3 3h7v7H3z M14 3h7v7h-7z M3 14h7v7H3z M14 14h7v7h-7z',
    'M3 12h2l2-6 3 12 3-15 3 18 2-9h3',
    'M4 14v-3a8 8 0 0 1 16 0v3 M4 13H2v7h4v-7z M20 13h2v7h-4v-7z');

function SourceQuestionIsAppCheck(const AQuestion: String): Boolean;
begin
  { These are the explicit declarations used by the existing operator-check
    publisher. Do not infer purpose from IDs, partitions or arbitrary words.
    This is presentation only; requests and saved evidence remain intact. }
  Result := (Pos('QA fixture only:', AQuestion) = 1) or
    (Pos('Operator mechanics only:', AQuestion) = 1);
end;

function WorkspaceResponseSaved(AValue: JSValue): JSValue;
var
  LEvent: TJSEvent;
begin
  Result := AValue;
  if isObject(AValue) and (AValue <> nil) and
    isBoolean(TJSObject(AValue)['ok']) and Boolean(TJSObject(AValue)['ok']) then
  begin
    LEvent := TJSEvent.new('pythian-workspace-changed');
    window.dispatchEvent(LEvent);
  end;
end;

constructor TWorkspaceNavigation.Create(const AFetch: TWorkspaceFetch;
  const ACurrentPage: String);
var
  LIndex: Integer;
begin
  inherited Create;
  if not Assigned(AFetch) then
  begin
    raise Exception.Create('Workspace navigation requires the page transport');
  end;
  if (ACurrentPage <> 'studio') and (ACurrentPage <> 'source') and
    (ACurrentPage <> 'listening') then
  begin
    raise Exception.Create('Unknown workspace page');
  end;
  FFetch := AFetch;
  FCurrentPage := ACurrentPage;
  for LIndex := 0 to 2 do
  begin
    FCounts[LIndex].State := 'loading';
    FCounts[LIndex].Count := 0;
    FCounts[LIndex].Attention := 0;
    FCounts[LIndex].InFlight := False;
    FCounts[LIndex].Again := False;
    FCounts[LIndex].Timeout := 0;
    FCounts[LIndex].Epoch := 0;
    FCounts[LIndex].Controller := nil;
  end;
  Layout;
  Draw;
end;

destructor TWorkspaceNavigation.Destroy;
var
  LIndex: Integer;
begin
  FStarted := False;
  FConnected := False;
  window.clearTimeout(FTimer);
  for LIndex := 0 to 2 do
  begin
    CancelRoute(LIndex, False);
  end;
  document.removeEventListener('visibilitychange', @Changed);
  window.removeEventListener('focus', @Changed);
  window.removeEventListener('pythian-workspace-changed', @Changed);
  window.removeEventListener('pagehide', @Leaving);
  window.removeEventListener('pageshow', @Returning);
  if FRefreshButton <> nil then
  begin
    FRefreshButton.removeEventListener('click', @Click);
  end;
  inherited Destroy;
end;

function TWorkspaceNavigation.Visible: Boolean;
begin
  Result := FStarted and FConnected and not FPaused and
    (String(TJSObject(document)['visibilityState']) <> 'hidden');
end;

function TWorkspaceNavigation.Add(AParent: TJSElement;
  const ATag, AText, AClass: String): TJSElement;
begin
  Result := document.createElement(ATag);
  Result.textContent := AText;
  Result.className := AClass;
  AParent.appendChild(Result);
end;

procedure TWorkspaceNavigation.Layout;
var
  LRoot: TJSElement;
  LNav: TJSElement;
  LIcon: TJSElement;
  LPath: TJSElement;
  LLabel: TJSElement;
  LIndex: Integer;
begin
  LRoot := document.getElementById('workspace-navigation');
  if LRoot <> nil then
  begin
    LRoot.textContent := '';
    LNav := Add(LRoot, 'nav', '', 'workspace-tabs');
    LNav.setAttribute('aria-label', 'Workspace');
    for LIndex := 0 to 2 do
    begin
      FLinks[LIndex] := Add(LNav, 'a', '', 'workspace-tab');
      FLinks[LIndex].setAttribute('href', CPaths[LIndex]);
      if FCurrentPage = CPages[LIndex] then
      begin
        FLinks[LIndex].setAttribute('aria-current', 'page');
      end;
      LIcon := document.createElementNS('http://www.w3.org/2000/svg', 'svg');
      LIcon.setAttribute('viewBox', '0 0 24 24');
      LIcon.setAttribute('aria-hidden', 'true');
      LIcon.setAttribute('focusable', 'false');
      LPath := document.createElementNS('http://www.w3.org/2000/svg', 'path');
      LPath.setAttribute('d', CIcons[LIndex]);
      LIcon.appendChild(LPath);
      FLinks[LIndex].appendChild(LIcon);
      LLabel := Add(FLinks[LIndex], 'span', CTitles[LIndex], 'workspace-label');
      FBadges[LIndex] := Add(LLabel, 'span', '', 'workspace-badge');
      FBadges[LIndex].setAttribute('aria-hidden', 'true');
      FDetails[LIndex] := Add(FLinks[LIndex], 'span', '', 'workspace-detail');
    end;
  end;
  LRoot := document.getElementById('workspace-next-action');
  if LRoot <> nil then
  begin
    LRoot.textContent := '';
    LRoot.classList.add('workspace-next');
    LRoot.setAttribute('aria-live', 'polite');
    LRoot.setAttribute('aria-atomic', 'true');
    FNextText := Add(LRoot, 'span', '', 'workspace-next-text');
    FNextLink := Add(LRoot, 'a', '', 'workspace-next-link');
    FRefreshButton := Add(LRoot, 'button', 'Refresh counts', 'workspace-refresh');
    FRefreshButton.setAttribute('type', 'button');
    FRefreshButton.addEventListener('click', @Click);
  end;
end;

procedure TWorkspaceNavigation.Draw;
var
  LIndex: Integer;
  LCount: Integer;
  LBadge: String;
  LDetail: String;
  LText: String;
  LLabel: String;
  LPath: String;
  LAllReady: Boolean;
  LLoading: Boolean;
begin
  LAllReady := True;
  LLoading := False;
  for LIndex := 0 to 2 do
  begin
    LCount := FCounts[LIndex].Count;
    if FCounts[LIndex].State = 'ready' then
    begin
      LBadge := IntToStr(LCount);
      if LIndex = 0 then
      begin
        LDetail := IntToStr(LCount) + ' awaiting feedback';
        if FCounts[LIndex].Attention > 0 then
        begin
          LDetail := LDetail + ' · ' + IntToStr(FCounts[LIndex].Attention) +
            ' awaiting publication';
        end;
      end
      else
      begin
        LDetail := IntToStr(LCount) + ' pending';
        if FCounts[LIndex].Attention > 0 then
        begin
          LDetail := LDetail + ' · ' + IntToStr(FCounts[LIndex].Attention) +
            ' need attention';
        end;
      end;
    end
    else
    begin
      LAllReady := False;
      if FCounts[LIndex].State = 'loading' then
      begin
        LBadge := '…';
        LDetail := 'Checking counts';
        LLoading := True;
      end
      else
      begin
        LBadge := '?';
        LDetail := 'Count unavailable';
      end;
    end;
    if FLinks[LIndex] <> nil then
    begin
      FBadges[LIndex].textContent := LBadge;
      FDetails[LIndex].textContent := LDetail;
      FLinks[LIndex].setAttribute('aria-label', CTitles[LIndex] + ': ' + LDetail);
      FLinks[LIndex].setAttribute('data-count-state', FCounts[LIndex].State);
      if (FCounts[LIndex].State = 'ready') and (FCounts[LIndex].Attention > 0) then
      begin
        FLinks[LIndex].setAttribute('data-needs-attention', 'true');
      end
      else
      begin
        FLinks[LIndex].setAttribute('data-needs-attention', 'false');
      end;
    end;
  end;
  LText := '';
  LLabel := 'Open Studio';
  LPath := '/studio.html';
  if (FCounts[1].State = 'ready') and (FCounts[1].Attention > 0) then
  begin
    if FCounts[1].Attention = 1 then
    begin
      LText := '1 source review needs attention.';
    end
    else
    begin
      LText := IntToStr(FCounts[1].Attention) + ' source reviews need attention.';
    end;
    LLabel := 'Open source reviews';
    LPath := '/';
  end
  else if (FCounts[0].State = 'ready') and (FCounts[0].Count > 0) then
  begin
    if FCounts[0].Count = 1 then
    begin
      LText := '1 comparison is waiting for your feedback.';
    end
    else
    begin
      LText := IntToStr(FCounts[0].Count) + ' comparisons are waiting for your feedback.';
    end;
    LLabel := 'Listen and compare';
    LPath := '/studio.html#listen';
  end
  else if (FCounts[2].State = 'ready') and (FCounts[2].Count > 0) then
  begin
    if FCounts[2].Count = 1 then
    begin
      LText := '1 listening review is waiting.';
    end
    else
    begin
      LText := IntToStr(FCounts[2].Count) + ' listening reviews are waiting.';
    end;
    LLabel := 'Open listening reviews';
    LPath := '/listen.html';
  end
  else if (FCounts[1].State = 'ready') and (FCounts[1].Count > 0) then
  begin
    if FCounts[1].Count = 1 then
    begin
      LText := '1 source review is waiting.';
    end
    else
    begin
      LText := IntToStr(FCounts[1].Count) + ' source reviews are waiting.';
    end;
    LLabel := 'Open source reviews';
    LPath := '/';
  end
  else if (FCounts[0].State = 'ready') and (FCounts[0].Attention > 0) then
  begin
    LText := 'A comparison is waiting to be published.';
    LLabel := 'Open comparisons';
    LPath := '/studio.html#listen';
  end
  else if LAllReady then
  begin
    LText := 'Reviews are up to date. Record audio or choose music in Studio.';
  end
  else if not FConnected then
  begin
    if LLoading then
    begin
      LText := 'Connect to check your workspace counts. Navigation is available.';
    end
    else
    begin
      LText := 'Counts are unavailable while disconnected. Navigation is available.';
    end;
  end
  else if LLoading then
  begin
    LText := 'Checking your workspace…';
  end
  else
  begin
    LText := 'Some counts are unavailable. Open a section or refresh to check again.';
  end;
  if FNextText <> nil then
  begin
    if FNextText.textContent <> LText then
    begin
      FNextText.textContent := LText;
    end;
    FNextLink.textContent := LLabel;
    FNextLink.setAttribute('href', LPath);
    if ((FCurrentPage = 'source') and (LPath = '/')) or
      ((FCurrentPage = 'listening') and (LPath = '/listen.html')) then
      FNextLink.setAttribute('hidden', '')
    else
      FNextLink.removeAttribute('hidden');
    TJSObject(FRefreshButton)['disabled'] := not FConnected;
  end;
end;

procedure TWorkspaceNavigation.ReadCount(const ARoute: Integer; AData: TJSObject);
var
  LRows: TJSArray;
  LRow: TJSObject;
  LIndex: Integer;
  LCount: Integer;
  LAttention: Integer;
  LStatus: String;
  LKey: String;
begin
  if (AData = nil) or not isObject(AData) or isArray(AData) then
  begin
    raise Exception.Create('Workspace count response is not an object');
  end;
  LKey := 'items';
  if ARoute = 0 then
  begin
    LKey := 'reviews';
  end;
  if not isArray(AData[LKey]) then
  begin
    raise Exception.Create('Workspace count rows are unavailable');
  end;
  LRows := TJSArray(AData[LKey]);
  if LRows.length > 4096 then
  begin
    raise Exception.Create('Workspace count rows exceed the supported bound');
  end;
  LCount := 0;
  LAttention := 0;
  for LIndex := 0 to LRows.length - 1 do
  begin
    if (LRows[LIndex] = nil) or not isObject(LRows[LIndex]) or isArray(LRows[LIndex]) then
    begin
      raise Exception.Create('Workspace count row is invalid');
    end;
    LRow := TJSObject(LRows[LIndex]);
    if (ARoute = 1) and isString(LRow['question']) and
      SourceQuestionIsAppCheck(String(LRow['question'])) then Continue;
    if ARoute = 0 then
    begin
      if not isString(LRow['status']) then
      begin
        raise Exception.Create('Comparison status is unavailable');
      end;
      LStatus := String(LRow['status']);
      if (LStatus = 'waiting') or (LStatus = 'withdrawn') then
      begin
        Inc(LCount);
      end
      else if LStatus = 'pending_publication' then
      begin
        Inc(LAttention);
      end
      else if LStatus <> 'submitted' then
      begin
        raise Exception.Create('Comparison status is unsupported');
      end;
    end
    else
    begin
      Inc(LCount);
      if (ARoute = 1) and isString(LRow['answer_conflict']) and
        (String(LRow['answer_conflict']) <> '') then
      begin
        Inc(LAttention);
      end;
    end;
  end;
  FCounts[ARoute].Count := LCount;
  FCounts[ARoute].Attention := LAttention;
  FCounts[ARoute].State := 'ready';
end;

procedure TWorkspaceNavigation.Load(const ARoute: Integer); async;
var
  LResponse: TJSResponse;
  LData: TJSObject;
  LEpoch: NativeInt;
begin
  if not Visible or FCounts[ARoute].InFlight then
  begin
    Exit;
  end;
  Inc(FCounts[ARoute].Epoch);
  LEpoch := FCounts[ARoute].Epoch;
  FCounts[ARoute].InFlight := True;
  FCounts[ARoute].Again := False;
  if FCounts[ARoute].State <> 'ready' then
  begin
    FCounts[ARoute].State := 'loading';
  end;
  try
    FCounts[ARoute].Controller := TWorkspaceAbortController.new;
    FCounts[ARoute].Timeout := window.setTimeout(
      procedure()
      begin
        if FStarted and FConnected and FCounts[ARoute].InFlight and
          (FCounts[ARoute].Epoch = LEpoch) then
        begin
          CancelRoute(ARoute, True);
          Draw;
        end;
      end, 10000);
    LResponse := await(TJSResponse, FFetch(CApis[ARoute], 'GET', '',
      FCounts[ARoute].Controller.Signal));
    if (LResponse = nil) or not LResponse.ok then
    begin
      raise Exception.Create('Workspace count request failed');
    end;
    LData := await(TJSObject, LResponse.json());
    if FStarted and FConnected and (FCounts[ARoute].Epoch = LEpoch) then
    begin
      ReadCount(ARoute, LData);
    end;
  except
    if FStarted and FConnected and (FCounts[ARoute].Epoch = LEpoch) then
    begin
      FCounts[ARoute].State := 'unavailable';
    end;
  end;
  if FCounts[ARoute].Epoch <> LEpoch then
  begin
    Exit;
  end;
  window.clearTimeout(FCounts[ARoute].Timeout);
  FCounts[ARoute].Timeout := 0;
  FCounts[ARoute].InFlight := False;
  FCounts[ARoute].Controller := nil;
  if FStarted then
  begin
    Draw;
    if FCounts[ARoute].Again and Visible then
    begin
      Load(ARoute);
    end;
  end;
end;

procedure TWorkspaceNavigation.CancelRoute(const ARoute: Integer;
  const AUnavailable: Boolean);
var
  LController: TWorkspaceAbortController;
begin
  Inc(FCounts[ARoute].Epoch);
  window.clearTimeout(FCounts[ARoute].Timeout);
  FCounts[ARoute].Timeout := 0;
  LController := FCounts[ARoute].Controller;
  FCounts[ARoute].Controller := nil;
  if LController <> nil then
  begin
    LController.abort;
  end;
  FCounts[ARoute].InFlight := False;
  FCounts[ARoute].Again := False;
  if AUnavailable then
  begin
    FCounts[ARoute].State := 'unavailable';
  end;
end;

procedure TWorkspaceNavigation.Schedule;
begin
  window.clearTimeout(FTimer);
  FTimer := 0;
  if Visible then
  begin
    FTimer := window.setTimeout(
      procedure()
      begin
        FTimer := 0;
        Refresh;
      end, 25000);
  end;
end;

procedure TWorkspaceNavigation.Refresh;
var
  LIndex: Integer;
begin
  if not Visible then
  begin
    Exit;
  end;
  for LIndex := 0 to 2 do
  begin
    if FCounts[LIndex].InFlight then
    begin
      FCounts[LIndex].Again := True;
    end
    else
    begin
      Load(LIndex);
    end;
  end;
  Draw;
  Schedule;
end;

function TWorkspaceNavigation.Changed(AEvent: TEventListenerEvent): Boolean;
var
  LIndex: Integer;
begin
  Result := True;
  if Visible then
  begin
    Refresh;
  end
  else
  begin
    window.clearTimeout(FTimer);
    FTimer := 0;
    for LIndex := 0 to 2 do
    begin
      if FCounts[LIndex].InFlight then
      begin
        CancelRoute(LIndex, True);
      end;
    end;
  end;
end;

function TWorkspaceNavigation.Leaving(AEvent: TEventListenerEvent): Boolean;
var
  LIndex: Integer;
begin
  Result := True;
  FPaused := True;
  window.clearTimeout(FTimer);
  FTimer := 0;
  for LIndex := 0 to 2 do
  begin
    if FCounts[LIndex].InFlight then
    begin
      CancelRoute(LIndex, True);
    end;
  end;
end;

function TWorkspaceNavigation.Returning(AEvent: TEventListenerEvent): Boolean;
begin
  Result := True;
  FPaused := False;
  Refresh;
end;

function TWorkspaceNavigation.Click(AEvent: TJSMouseEvent): Boolean;
begin
  Result := True;
  Refresh;
end;

procedure TWorkspaceNavigation.Start;
begin
  FConnected := True;
  FPaused := False;
  if FStarted then
  begin
    Refresh;
    Exit;
  end;
  FStarted := True;
  Draw;
  document.addEventListener('visibilitychange', @Changed);
  window.addEventListener('focus', @Changed);
  window.addEventListener('pythian-workspace-changed', @Changed);
  window.addEventListener('pagehide', @Leaving);
  window.addEventListener('pageshow', @Returning);
  Refresh;
end;

procedure TWorkspaceNavigation.ConnectionFailed;
var
  LIndex: Integer;
begin
  FConnected := False;
  window.clearTimeout(FTimer);
  FTimer := 0;
  for LIndex := 0 to 2 do
  begin
    CancelRoute(LIndex, True);
  end;
  Draw;
end;

end.
