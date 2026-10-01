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
unit pythian.studio.&library.refresh;

{$mode delphi}
{$H+}
{$modeswitch externalclass}

interface

uses
  JS,
  Web,
  SysUtils,
  Classes;

type
  TLibraryFetch = function(const APath, AMethod, ABody: String;
    const ASignal: TJSObject): TJSPromise of object;
  TLibraryChanged = procedure of object;

  TLibraryAbort = class external name 'AbortController' (TJSObject)
  private
    FSignal: TJSObject; external name 'signal';
  public
    constructor new;
    procedure abort;
    property Signal: TJSObject read FSignal;
  end;

  TStudioLibraryRefresh = class
  private
    FFetch: TLibraryFetch;
    FChanged: TLibraryChanged;
    FConnected: Boolean;
    FPaused: Boolean;
    FBusy: Boolean;
    FKnown: Boolean;
    FPending: Boolean;
    FAbsent: Boolean;
    FDestroyed: Boolean;
    FEpoch: Integer;
    FTimer: NativeInt;
    FRead: TLibraryAbort;
    FWrite: TJSObject;
    FJob: TJSObject;
    FObserved: TStringList;
    FNotified: TStringList;
    FStart: TJSHTMLButtonElement;
    FCancel: TJSHTMLButtonElement;
    FRetry: TJSHTMLButtonElement;
    FStatus: TJSElement;
    FDetails: TJSElement;
    FProgress: TJSElement;
    procedure StorePending;
    function Add(AParent: TJSElement; const ATag, AText: String): TJSElement;
    function Request(const APath, AMethod, ABody: String): TJSObject; async;
    procedure Draw;
    procedure Notice(const AText: String);
    procedure Schedule;
    procedure PauseReads;
    procedure Accept(AJob: TJSObject; const AId: String);
    procedure Submit; async;
    procedure Cancel; async;
    procedure Recover; async;
    function Click(AEvent: TJSMouseEvent): Boolean;
    function Visibility(AEvent: TEventListenerEvent): Boolean;
    function Leaving(AEvent: TEventListenerEvent): Boolean;
    function Returning(AEvent: TEventListenerEvent): Boolean;
  public
    constructor Create(AFetch: TLibraryFetch; AChanged: TLibraryChanged);
    destructor Destroy; override;
    procedure SetConnected(AConnected: Boolean);
    procedure Refresh; async;
  end;

implementation

type
  ERefreshHttp = class(Exception)
    Status: Integer;
  end;

function Text(AObject: TJSObject; const AKey: String): String;
begin
  Result := '';
  if (AObject <> nil) and isString(AObject[AKey]) then
  begin
    Result := String(AObject[AKey]);
  end;
end;

function Active(AJob: TJSObject): Boolean;
begin
  Result := (Text(AJob, 'status') = 'queued') or (Text(AJob, 'status') = 'running');
end;

function ValidStatus(AJob: TJSObject): Boolean;
begin
  Result := Active(AJob) or (Text(AJob, 'status') = 'completed') or
    (Text(AJob, 'status') = 'failed') or (Text(AJob, 'status') = 'cancelled');
end;

function Phase(const AStage: String): String;
begin
  case AStage of
    'queued': Result := 'Waiting to refresh';
    'discovering': Result := 'Finding recordings';
    'hashing_sources': Result := 'Checking recording identity';
    'staging_sources': Result := 'Preparing recordings';
    'importing_sources': Result := 'Adding recordings';
    'verifying_sources': Result := 'Verifying recordings';
    'verifying_existing_sources': Result := 'Checking existing recordings';
    'hashing_source_bytes': Result := 'Checking original audio';
    'verifying_catalog_bytes': Result := 'Checking saved audio';
    'verifying_original_bytes': Result := 'Rechecking original audio';
    'copying_source_bytes': Result := 'Copying new recordings';
    'verifying_stage_bytes': Result := 'Verifying new recordings';
    'publishing_index': Result := 'Saving collection list';
  else
    Result := 'Checking collection';
  end;
end;

function AudioBytes(const AValue: Double): String;
begin
  if AValue >= 1000000000 then
    Result := FormatFloat('0.00', AValue / 1000000000) + ' GB'
  else
    Result := FormatFloat('0.0', AValue / 1000000) + ' MB';
end;

function TStudioLibraryRefresh.Add(AParent: TJSElement;
  const ATag, AText: String): TJSElement;
begin
  Result := document.createElement(ATag);
  Result.textContent := AText;
  AParent.appendChild(Result);
end;

constructor TStudioLibraryRefresh.Create(AFetch: TLibraryFetch; AChanged: TLibraryChanged);
var
  LMount: TJSElement;
  LActions: TJSElement;
  LDetails: TJSElement;
  LStored: String;
begin
  inherited Create;
  FFetch := AFetch;
  FChanged := AChanged;
  FObserved := TStringList.Create;
  FNotified := TStringList.Create;
  LMount := document.getElementById('studio-library-refresh');
  if LMount = nil then
  begin
    raise Exception.Create('Library refresh mount is missing.');
  end;
  FStatus := Add(LMount, 'p', 'Connect to check collection refresh status.');
  FStatus.id := 'library-refresh-status';
  FStatus.setAttribute('role', 'status');
  FStatus.setAttribute('aria-live', 'polite');
  FProgress := Add(LMount, 'progress', '');
  FProgress.id := 'library-refresh-progress';
  FProgress.setAttribute('aria-label', 'Current refresh phase');
  LActions := Add(LMount, 'div', '');
  LActions.className := 'actions';
  FStart := TJSHTMLButtonElement(Add(LActions, 'button', 'Refresh library'));
  FStart.id := 'library-refresh-start';
  FCancel := TJSHTMLButtonElement(Add(LActions, 'button', 'Cancel refresh'));
  FCancel.id := 'library-refresh-cancel';
  FRetry := TJSHTMLButtonElement(Add(LActions, 'button', 'Retry status check'));
  FRetry.id := 'library-refresh-retry';
  FStart.setAttribute('type', 'button');
  FCancel.setAttribute('type', 'button');
  FRetry.setAttribute('type', 'button');
  FStart.addEventListener('click', @Click);
  FCancel.addEventListener('click', @Click);
  FRetry.addEventListener('click', @Click);
  LDetails := Add(LMount, 'details', '');
  Add(LDetails, 'summary', 'Refresh details');
  FDetails := Add(LDetails, 'p', '');
  document.addEventListener('visibilitychange', @Visibility);
  window.addEventListener('pagehide', @Leaving);
  window.addEventListener('pageshow', @Returning);
  try
    LStored := window.sessionStorage.getItem('pythian.library-refresh.pending.v1');
    if LStored <> '' then
    begin
      FWrite := TJSObject(TJSJSON.parse(LStored));
      if (Text(FWrite, 'format') = 'pythian.studio.job.write.v1') and
        (Text(FWrite, 'kind') = 'library_refresh') and
        (Pos('library-refresh-', Text(FWrite, 'job_id')) = 1) then
      begin
        FPending := True;
        FObserved.Add(Text(FWrite, 'job_id'));
      end;
    end;
  except
    FWrite := nil;
  end;
  Draw;
end;

procedure TStudioLibraryRefresh.StorePending;
begin
  try
    if FPending then
    begin
      window.sessionStorage.setItem('pythian.library-refresh.pending.v1',
        TJSJSON.stringify(FWrite));
    end
    else
    begin
      window.sessionStorage.removeItem('pythian.library-refresh.pending.v1');
    end;
  except
    { Storage can be disabled; the current page still retains its exact request. }
  end;
end;

procedure TStudioLibraryRefresh.Notice(const AText: String);
begin
  FStatus.textContent := AText;
end;

procedure TStudioLibraryRefresh.Draw;
var
  LDone: Double;
  LTotal: Double;
  LCap: JSValue;
begin
  FStart.disabled := not FConnected or FBusy or not FKnown or FPending or Active(FJob);
  TJSObject(FCancel)['hidden'] := not Active(FJob);
  FCancel.disabled := not FConnected or FBusy;
  TJSObject(FRetry)['hidden'] := FKnown and not FPending;
  FRetry.disabled := not FConnected or FBusy;
  FRetry.textContent := 'Retry status check';
  if FPending then
  begin
    FRetry.textContent := 'Check refresh';
    if FAbsent then
    begin
      FRetry.textContent := 'Retry refresh';
    end;
  end;
  TJSObject(FProgress)['hidden'] := not Active(FJob);
  FProgress.removeAttribute('value');
  if Active(FJob) and isNumber(FJob['done']) and isNumber(FJob['total']) then
  begin
    LDone := Double(FJob['done']);
    LTotal := Double(FJob['total']);
    if (LDone >= 0) and (LTotal > 0) and (LTotal <= 9007199254740991) and
      (LDone <= LTotal) then
    begin
      FProgress.setAttribute('max', FloatToStr(LTotal));
      FProgress.setAttribute('value', FloatToStr(LDone));
    end;
  end;
  FDetails.textContent := '';
  if FJob <> nil then
  begin
    FDetails.textContent := 'Job ' + Text(FJob, 'job_id');
    LCap := FJob['maximum_worker_seconds'];
    if isNumber(LCap) and (Double(LCap) > 0) then
    begin
      FDetails.textContent := FDetails.textContent + ' · Worker limit ' +
        FloatToStr(Double(LCap)) + ' seconds';
    end;
    if Text(FJob, 'status') = 'failed' then
    begin
      FDetails.textContent := FDetails.textContent + ' · ' +
        Copy(Text(FJob, 'error_message'), 1, 512);
    end;
  end;
end;

function TStudioLibraryRefresh.Request(const APath, AMethod, ABody: String): TJSObject; async;
var
  LController: TLibraryAbort;
  LTimer: NativeInt;
  LResponse: TJSResponse;
  LError: ERefreshHttp;
  LBody: String;
begin
  LController := TLibraryAbort.new;
  if AMethod = 'GET' then
  begin
    FRead := LController;
  end;
  LTimer := window.setTimeout(
    procedure
    begin
      LController.abort;
    end, 10000);
  try
    LResponse := await(TJSResponse, FFetch(APath, AMethod, ABody, LController.signal));
    if not LResponse.ok then
    begin
      LBody := await(String, LResponse.text());
      LError := ERefreshHttp.Create(Copy(LBody, 1, 240));
      LError.Status := LResponse.status;
      raise LError;
    end;
    Result := await(TJSObject, LResponse.json());
  finally
    window.clearTimeout(LTimer);
    if FRead = LController then
    begin
      FRead := nil;
    end;
  end;
end;

procedure TStudioLibraryRefresh.Accept(AJob: TJSObject; const AId: String);
var
  LStatus: String;
begin
  if (Text(AJob, 'format') <> 'pythian.studio.job.v1') or
    (Text(AJob, 'kind') <> 'library_refresh') or (Text(AJob, 'job_id') <> AId) then
  begin
    raise Exception.Create('Refresh response has a different identity.');
  end;
  LStatus := Text(AJob, 'status');
  if (LStatus <> 'queued') and (LStatus <> 'running') and
    (LStatus <> 'completed') and (LStatus <> 'failed') and (LStatus <> 'cancelled') then
  begin
    raise Exception.Create('Refresh status is unknown. Retry its status check.');
  end;
  FJob := AJob;
  FKnown := True;
  FPending := False;
  FAbsent := False;
  StorePending;
  if Active(FJob) then
  begin
    if FObserved.IndexOf(AId) < 0 then
    begin
      FObserved.Add(AId);
    end;
    Notice(Phase(Text(FJob, 'stage')));
    if isNumber(FJob['done']) and isNumber(FJob['total']) and
      (Double(FJob['done']) >= 0) and (Double(FJob['total']) > 0) and
      (Double(FJob['total']) <= 9007199254740991) and
      (Double(FJob['done']) <= Double(FJob['total'])) then
    begin
      if Pos('_bytes', Text(FJob, 'stage')) > 0 then
      begin
        FStatus.textContent := FStatus.textContent + ' · ' +
          AudioBytes(Double(FJob['done'])) + ' / ' + AudioBytes(Double(FJob['total']));
      end
      else
      begin
        FStatus.textContent := FStatus.textContent + ' · ' +
          FloatToStr(Double(FJob['done'])) + ' / ' + FloatToStr(Double(FJob['total']));
      end;
    end;
    if isBoolean(FJob['cancel_requested']) and Boolean(FJob['cancel_requested']) then
    begin
      Notice('Waiting for the refresh to stop…');
    end;
  end
  else
  begin
    case LStatus of
      'completed': Notice('Library refreshed.');
      'failed': Notice('Refresh failed. You can start a new refresh.');
      'cancelled': Notice('Refresh cancelled. You can start a new refresh.');
    end;
    if (LStatus = 'completed') and (FObserved.IndexOf(AId) >= 0) and
      (FNotified.IndexOf(AId) < 0) then
    begin
      FNotified.Add(AId);
      if Assigned(FChanged) then
      begin
        FChanged;
      end;
    end;
  end;
end;

procedure TStudioLibraryRefresh.Schedule;
begin
  window.clearTimeout(FTimer);
  FTimer := 0;
  if FConnected and not FPaused and
    (String(TJSObject(document)['visibilityState']) <> 'hidden') and Active(FJob) and FKnown then
  begin
    FTimer := window.setTimeout(
      procedure
      begin
        Refresh;
      end, 2000);
  end;
end;

procedure TStudioLibraryRefresh.Refresh; async;
var
  LEpoch: Integer;
  LData: TJSObject;
  LJobs: TJSArray;
  LRow: TJSObject;
  LId: String;
  LIndex: Integer;
begin
  if FDestroyed or not FConnected or FPaused or
    (String(TJSObject(document)['visibilityState']) = 'hidden') or FBusy then
  begin
    Exit;
  end;
  FBusy := True;
  LEpoch := FEpoch;
  Draw;
  try
    LId := '';
    if FPending then
    begin
      LId := Text(FWrite, 'job_id');
    end
    else if Active(FJob) then
    begin
      LId := Text(FJob, 'job_id');
    end
    else
    begin
      LData := await(TJSObject, Request('/api/studio/jobs', 'GET', ''));
      if LEpoch <> FEpoch then
      begin
        Exit;
      end;
      if (Text(LData, 'format') <> 'pythian.studio.jobs.v1') or
        not isArray(LData['jobs']) then
      begin
        raise Exception.Create('Refresh history is unavailable.');
      end;
      LJobs := TJSArray(LData['jobs']);
      if LJobs.length > 256 then
      begin
        raise Exception.Create('Refresh history exceeds its limit.');
      end;
      for LIndex := 0 to LJobs.length - 1 do
      begin
        if (LJobs[LIndex] = nil) or not isObject(LJobs[LIndex]) or isArray(LJobs[LIndex]) then
        begin
          raise Exception.Create('Refresh history contains an unreadable entry.');
        end;
        LRow := TJSObject(LJobs[LIndex]);
        if (Text(LRow, 'kind') = 'library_refresh') and
          ((Text(LRow, 'job_id') = '') or not ValidStatus(LRow)) then
        begin
          raise Exception.Create('Recorded refresh status is unknown.');
        end;
        if (LId = '') and (Text(LRow, 'kind') = 'library_refresh') and Active(LRow) then
        begin
          LId := Text(LRow, 'job_id');
        end;
      end;
      if LId = '' then
      begin
        if (FJob <> nil) and ValidStatus(FJob) and not Active(FJob) then
        begin
          Accept(FJob, Text(FJob, 'job_id'));
        end
        else
        begin
          FKnown := True;
          Notice('Ready to refresh your collections.');
        end;
      end;
    end;
    if LId <> '' then
    begin
      LData := await(TJSObject, Request('/api/studio/job?id=' + encodeURIComponent(LId),
        'GET', ''));
      if LEpoch = FEpoch then
      begin
        Accept(LData, LId);
      end;
    end;
  except
    on LException: Exception do
    begin
      if LEpoch = FEpoch then
      begin
        FKnown := False;
        if (LException is ERefreshHttp) and (ERefreshHttp(LException).Status = 404) and
          FPending then
        begin
          FAbsent := True;
          Notice('No refresh found yet. Retry when ready.');
        end
        else
        begin
          Notice('Status check failed or timed out. Retry to reconnect.');
        end;
      end;
    end;
  else
    begin
      if LEpoch = FEpoch then
      begin
        FKnown := False;
        Notice('Status check failed or timed out. Retry to reconnect.');
      end;
    end;
  end;
  if LEpoch = FEpoch then
  begin
    FBusy := False;
    Draw;
    Schedule;
  end;
end;

procedure TStudioLibraryRefresh.Submit; async;
var
  LEpoch: Integer;
  LData: TJSObject;
begin
  if not FConnected or FBusy or (FPending and not FAbsent) then
  begin
    Exit;
  end;
  if not FPending then
  begin
    if not FKnown or Active(FJob) then
    begin
      Exit;
    end;
    FWrite := TJSObject.new;
    FWrite['format'] := 'pythian.studio.job.write.v1';
    FWrite['kind'] := 'library_refresh';
    FWrite['job_id'] := 'library-refresh-' + FloatToStr(TJSDate.now) + '-' +
      IntToStr(Trunc(Random * 100000000));
  end;
  FPending := True;
  StorePending;
  FAbsent := False;
  FBusy := True;
  LEpoch := FEpoch;
  if FObserved.IndexOf(Text(FWrite, 'job_id')) < 0 then
  begin
    FObserved.Add(Text(FWrite, 'job_id'));
  end;
  Notice('Starting library refresh…');
  Draw;
  try
    LData := await(TJSObject, Request('/api/studio/job', 'POST', TJSJSON.stringify(FWrite)));
    if LEpoch = FEpoch then
    begin
      Accept(LData, Text(FWrite, 'job_id'));
    end;
  except
    if LEpoch = FEpoch then
    begin
      FKnown := False;
      Notice('Connection lost. Check whether the refresh started.');
    end;
  end;
  if LEpoch = FEpoch then
  begin
    FBusy := False;
    Draw;
    Schedule;
  end;
end;

procedure TStudioLibraryRefresh.Cancel; async;
var
  LEpoch: Integer;
  LWrite: TJSObject;
  LData: TJSObject;
  LId: String;
begin
  if not FConnected or FBusy or not Active(FJob) then
  begin
    Exit;
  end;
  FBusy := True;
  LEpoch := FEpoch;
  LId := Text(FJob, 'job_id');
  LWrite := TJSObject.new;
  LWrite['job_id'] := LId;
  Notice('Stopping refresh…');
  Draw;
  try
    LData := await(TJSObject, Request('/api/studio/cancel', 'POST', TJSJSON.stringify(LWrite)));
    if LEpoch = FEpoch then
    begin
      Accept(LData, LId);
    end;
  except
    if LEpoch = FEpoch then
    begin
      FKnown := False;
      Notice('Cancellation is unconfirmed. Retry its status check.');
    end;
  end;
  if LEpoch = FEpoch then
  begin
    FBusy := False;
    Draw;
    Schedule;
  end;
end;

procedure TStudioLibraryRefresh.Recover; async;
begin
  if FPending and FAbsent then
  begin
    Submit;
  end
  else
  begin
    Refresh;
  end;
end;

function TStudioLibraryRefresh.Click(AEvent: TJSMouseEvent): Boolean;
begin
  Result := True;
  case TJSElement(AEvent.currentTarget).id of
    'library-refresh-start': Submit;
    'library-refresh-cancel': Cancel;
    'library-refresh-retry': Recover;
  end;
end;

procedure TStudioLibraryRefresh.PauseReads;
begin
  window.clearTimeout(FTimer);
  FTimer := 0;
  if FRead <> nil then
  begin
    Inc(FEpoch);
    FRead.abort;
    FRead := nil;
    FBusy := False;
  end;
end;

procedure TStudioLibraryRefresh.SetConnected(AConnected: Boolean);
begin
  FConnected := AConnected;
  if not AConnected then
  begin
    PauseReads;
    FKnown := False;
    Notice('Disconnected. Reconnect to check refresh status.');
  end;
  Draw;
end;

function TStudioLibraryRefresh.Visibility(AEvent: TEventListenerEvent): Boolean;
begin
  Result := True;
  FPaused := String(TJSObject(document)['visibilityState']) = 'hidden';
  if FPaused then
  begin
    PauseReads;
  end
  else
  begin
    Refresh;
  end;
end;

function TStudioLibraryRefresh.Leaving(AEvent: TEventListenerEvent): Boolean;
begin
  Result := True;
  FPaused := True;
  PauseReads;
end;

function TStudioLibraryRefresh.Returning(AEvent: TEventListenerEvent): Boolean;
begin
  Result := True;
  FPaused := False;
  Refresh;
end;

destructor TStudioLibraryRefresh.Destroy;
begin
  FDestroyed := True;
  Inc(FEpoch);
  PauseReads;
  FStart.removeEventListener('click', @Click);
  FCancel.removeEventListener('click', @Click);
  FRetry.removeEventListener('click', @Click);
  document.removeEventListener('visibilitychange', @Visibility);
  window.removeEventListener('pagehide', @Leaving);
  window.removeEventListener('pageshow', @Returning);
  FObserved.Free;
  FNotified.Free;
  inherited Destroy;
end;

end.
