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
program PythianLabelWorkbench;

{$mode delphi}
{$H+}
{$modeswitch externalclass}

uses
  JS,
  Web,
  SysUtils;

const
  RememberedAccessKey = 'pythian.catalog.access-key.v1';

type
  TLabelDragMode = (dmNone, dmCreate, dmMove, dmStart, dmEnd, dmDraft);

  TWorkbenchWindow = class external name 'Window' (TJSWindow)
    function fetch(const AUrl: String;
      const AOptions: TJSObject): TJSPromise; reintroduce;
  end;

  TWorkbenchResponse = class external name 'Response' (TJSResponse)
    function blobRequest: TJSPromise; external name 'blob';
  end;

  TWorkbench = class
  private
    FToken: String;
    FSourceHash: String;
    FPartition: String;
    FAudioUrl: String;
    FTracks: TJSArray;
    FWaveBins: TJSArray;
    FCurrentLabels: TJSArray;
    FProposals: TJSObject;
    FSampleRate: Integer;
    FReviewRevision: Integer;
    FFrameCount: Int64;
    FWindowStart: Int64;
    FWindowSpan: Int64;
    FWindowEpoch: Integer;
    FAudioEpoch: Integer;
    FCanvas: TJSHTMLCanvasElement;
    FAudio: TJSHTMLAudioElement;
    FSelectedLabel: Integer;
    FSelectedProposal: Integer;
    FDragMode: TLabelDragMode;
    FDragPointer: NativeInt;
    FDragAnchor: Int64;
    FDragOriginalStart: Int64;
    FDragOriginalEnd: Int64;
    FDragStart: Int64;
    FDragEnd: Int64;
    function Element(const AId: String): TJSElement;
    function Input(const AId: String): TJSHTMLInputElement;
    function FetchApi(const APath, AMethod, ABody: String): TJSPromise;
    procedure Status(const AText: String; const AError: Boolean = False);
    procedure ShowWorkspace;
    procedure ClearItems(const AId: String);
    procedure AddItem(const AContainerId, ATitle, ADetail,
      AClassName: String; const AIndex: Integer;
      const AClick: THTMLClickEventHandler = nil);
    procedure RenderInbox(const AData: TJSObject);
    procedure RenderCatalog(const AData: TJSObject);
    procedure RenderLabels;
    procedure RenderProposals;
    procedure DrawWaveform;
    procedure SelectLabel(const AIndex: Integer);
    function CanvasX(const AEvent: TJSPointerEvent): Double;
    function CanvasY(const AEvent: TJSPointerEvent): Double;
    function FrameAtX(const AX: Double): Int64;
    procedure UpdateDrag(const AFrame: Int64);
    procedure UpdateWindowLabel;
    procedure Start; async;
    procedure Connect; async;
    procedure ConnectWithKey(const AKey: String; const ARemember: Boolean); async;
    procedure ForgetDevice;
    procedure RefreshLists; async;
    procedure ImportAll; async;
    procedure SelectTrack(const AIndex: Integer); async;
    procedure RefreshWindow; async;
    procedure LoadAudio(const ACue: Boolean); async;
    procedure SuggestBeats; async;
    procedure SaveReview; async;
    procedure DownloadExport; async;
    procedure UploadReviewed; async;
    function HandleConnect(AEvent: TJSMouseEvent): Boolean;
    function HandleForgetDevice(AEvent: TJSMouseEvent): Boolean;
    function HandleImport(AEvent: TJSMouseEvent): Boolean;
    function HandleTrack(AEvent: TJSMouseEvent): Boolean;
    function HandleLabel(AEvent: TJSMouseEvent): Boolean;
    function HandleProposal(AEvent: TJSMouseEvent): Boolean;
    function HandlePrevious(AEvent: TJSMouseEvent): Boolean;
    function HandleNext(AEvent: TJSMouseEvent): Boolean;
    function HandleJump(AEvent: TJSMouseEvent): Boolean;
    function HandleLoop(AEvent: TJSMouseEvent): Boolean;
    function HandleZoomIn(AEvent: TJSMouseEvent): Boolean;
    function HandleZoomOut(AEvent: TJSMouseEvent): Boolean;
    function HandleLoadAudio(AEvent: TJSMouseEvent): Boolean;
    function HandleLoadCue(AEvent: TJSMouseEvent): Boolean;
    function HandleSuggest(AEvent: TJSMouseEvent): Boolean;
    function HandleSave(AEvent: TJSMouseEvent): Boolean;
    function HandleExport(AEvent: TJSMouseEvent): Boolean;
    function HandleUploadReviewed(AEvent: TJSMouseEvent): Boolean;
    function HandleCanvasDown(AEvent: TJSPointerEvent): Boolean;
    function HandleCanvasMove(AEvent: TJSPointerEvent): Boolean;
    function HandleCanvasUp(AEvent: TJSPointerEvent): Boolean;
    function HandleCanvasCancel(AEvent: TJSPointerEvent): Boolean;
  public
    procedure Run;
  end;

function TextField(const AObject: TJSObject; const AName: String): String;
begin
  Result := '';
  if (AObject <> nil) and isString(AObject[AName]) then
  begin
    Result := String(AObject[AName]);
  end;
end;

function NumberField(const AObject: TJSObject; const AName: String): Double;
begin
  Result := 0;
  if (AObject <> nil) and isNumber(AObject[AName]) then
  begin
    Result := Double(AObject[AName]);
  end;
end;

function Smaller(const ALeft, ARight: Int64): Int64;
begin
  if ALeft < ARight then
  begin
    Result := ALeft;
  end
  else
  begin
    Result := ARight;
  end;
end;

function TWorkbench.Element(const AId: String): TJSElement;
begin
  Result := document.getElementById(AId);
  if Result = nil then
  begin
    raise Exception.Create('Missing browser control ' + AId);
  end;
end;

function TWorkbench.Input(const AId: String): TJSHTMLInputElement;
begin
  Result := TJSHTMLInputElement(Element(AId));
end;

function TWorkbench.FetchApi(const APath, AMethod,
  ABody: String): TJSPromise;
var
  LOptions: TJSObject;
  LHeaders: TJSObject;
begin
  LOptions := TJSObject.new;
  LHeaders := TJSObject.new;
  LOptions['method'] := AMethod;
  LOptions['mode'] := 'same-origin';
  LOptions['credentials'] := 'same-origin';
  LOptions['redirect'] := 'error';
  LOptions['cache'] := 'no-store';
  LOptions['referrerPolicy'] := 'no-referrer';
  if FToken <> '' then
  begin
    LHeaders['X-Pythian-Token'] := FToken;
  end;
  if ABody <> '' then
  begin
    LHeaders['Content-Type'] := 'application/json';
    LOptions['body'] := ABody;
  end;
  LOptions['headers'] := LHeaders;
  Result := TWorkbenchWindow(window).fetch(
    window.location.origin + APath, LOptions);
end;

procedure TWorkbench.Status(const AText: String; const AError: Boolean);
var
  LStatus: TJSElement;
begin
  LStatus := Element('status');
  LStatus.textContent := AText;
  if AError then
  begin
    LStatus.setAttribute('class', 'status error');
  end
  else
  begin
    LStatus.setAttribute('class', 'status');
  end;
end;

procedure TWorkbench.ShowWorkspace;
begin
  Element('login-panel').setAttribute('hidden', '');
  Element('workspace').removeAttribute('hidden');
end;

procedure TWorkbench.ClearItems(const AId: String);
begin
  Element(AId).innerHTML := '';
end;

procedure TWorkbench.AddItem(const AContainerId, ATitle, ADetail,
  AClassName: String; const AIndex: Integer;
  const AClick: THTMLClickEventHandler);
var
  LButton: TJSHTMLButtonElement;
  LTitle: TJSElement;
  LDetail: TJSElement;
begin
  LButton := TJSHTMLButtonElement(document.createElement('button'));
  LButton.setAttribute('type', 'button');
  LButton.className := 'item ' + AClassName;
  LButton.setAttribute('data-index', IntToStr(AIndex));
  LTitle := document.createElement('strong');
  LTitle.textContent := ATitle;
  LButton.appendChild(LTitle);
  LDetail := document.createElement('small');
  LDetail.textContent := ADetail;
  LButton.appendChild(LDetail);
  if AClick <> nil then
  begin
    LButton.onclick := AClick;
  end
  else
  begin
    LButton.disabled := True;
  end;
  Element(AContainerId).appendChild(LButton);
end;

procedure TWorkbench.RenderInbox(const AData: TJSObject);
var
  LRows: TJSArray;
  LRow: TJSObject;
  LCatalogRow: TJSObject;
  LIndex: Integer;
  LCatalogIndex: Integer;
  LState: String;
  LRemaining: Integer;
begin
  ClearItems('inbox-list');
  LRows := TJSArray(AData['tracks']);
  LRemaining := 0;
  for LIndex := 0 to LRows.length - 1 do
  begin
    LRow := TJSObject(LRows[LIndex]);
    LState := TextField(LRow, 'status');
    if (LState = 'prepared_unverified') and (FTracks <> nil) then
    begin
      for LCatalogIndex := 0 to FTracks.length - 1 do
      begin
        LCatalogRow := TJSObject(FTracks[LCatalogIndex]);
        if TextField(LCatalogRow, 'source_sha256') =
          TextField(LRow, 'sha256') then
        begin
          if (TextField(LCatalogRow, 'source_group') =
            TextField(LRow, 'source_group')) and
            (TextField(LCatalogRow, 'partition') =
            TextField(LRow, 'partition')) then
          begin
            LState := 'in catalog';
          end
          else
          begin
            LState := 'catalog conflict';
          end;
          Break;
        end;
      end;
    end;
    if LState <> 'in catalog' then
    begin
      Inc(LRemaining);
    end;
    AddItem('inbox-list', TextField(LRow, 'title'),
      TextField(LRow, 'file') + ' · ' + LState + ' · ' +
      TextField(LRow, 'partition'), LState, LIndex);
  end;
  TJSHTMLButtonElement(Element('import-button')).disabled := LRemaining = 0;
  if LRows.length = 0 then
  begin
    Element('import-button').textContent := 'No prepared files';
  end
  else if LRemaining = 0 then
  begin
    Element('import-button').textContent := 'All imported';
  end
  else
  begin
    Element('import-button').textContent := 'Import all';
  end;
end;

procedure TWorkbench.RenderCatalog(const AData: TJSObject);
var
  LRow: TJSObject;
  LIndex: Integer;
begin
  ClearItems('catalog-list');
  FTracks := TJSArray(AData['tracks']);
  for LIndex := 0 to FTracks.length - 1 do
  begin
    LRow := TJSObject(FTracks[LIndex]);
    AddItem('catalog-list', TextField(LRow, 'title'),
      TextField(LRow, 'source_group') + ' · ' +
      TextField(LRow, 'partition') + ' · ' +
      IntToStr(Trunc(NumberField(LRow, 'frame_count'))) + ' frames',
      '', LIndex, @HandleTrack);
  end;
end;

procedure TWorkbench.RenderLabels;
var
  LRow: TJSObject;
  LIndex: Integer;
begin
  ClearItems('review-list');
  if FCurrentLabels = nil then
  begin
    Exit;
  end;
  for LIndex := 0 to FCurrentLabels.length - 1 do
  begin
    LRow := TJSObject(FCurrentLabels[LIndex]);
    AddItem('review-list', TextField(LRow, 'type') + ': ' +
      TextField(LRow, 'value'),
      TextField(LRow, 'label_id') + ' · ' +
      IntToStr(Trunc(NumberField(LRow, 'start_frame'))) + '–' +
      IntToStr(Trunc(NumberField(LRow, 'end_frame'))) + ' · ' +
      TextField(LRow, 'status'),
      'reviewed', LIndex, @HandleLabel);
  end;
end;

procedure TWorkbench.RenderProposals;
var
  LRows: TJSArray;
  LRow: TJSObject;
  LIndex: Integer;
begin
  ClearItems('proposal-list');
  if FSelectedProposal < 0 then
  begin
    Element('load-cue-button').textContent := 'Load selected Pythian cue';
  end;
  TJSHTMLButtonElement(Element('load-cue-button')).disabled :=
    (FProposals = nil) or (FSelectedProposal < 0);
  if (FPartition = 'evaluation') and (FReviewRevision = 0) then
  begin
    Element('proposal-note').textContent :=
      'Blind evaluation: Pythian suggestions are hidden. Commit your own label first.';
    Exit;
  end;
  if FProposals = nil then
  begin
    Element('proposal-note').textContent :=
      'No saved proposals for this window. Suggestions remain unreviewed.';
    Exit;
  end;
  Element('proposal-note').textContent :=
    'Pythian beat-grid hypotheses · ' +
    TextField(FProposals, 'analyzer') + ' · unreviewed';
  LRows := TJSArray(FProposals['candidates']);
  for LIndex := 0 to LRows.length - 1 do
  begin
    LRow := TJSObject(LRows[LIndex]);
    AddItem('proposal-list', 'Beat grid ' + IntToStr(LIndex + 1),
      'BPM ' + TJSJSON.stringify(LRow['bpm']) + ' · score ' +
      TJSJSON.stringify(LRow['score']) + ' · tap to review',
      'proposal', LIndex, @HandleProposal);
  end;
end;

procedure TWorkbench.DrawWaveform;
var
  LContext: TJSCanvasRenderingContext2D;
  LPeak: Double;
  LMinimum: Double;
  LMaximum: Double;
  LX: Double;
  LWidth: Double;
  LRow: TJSObject;
  LIndex: Integer;
  LStart: Double;
  LEnd: Double;
  LFrames: TJSArray;
  LCandidates: TJSArray;
  LSelected: TJSObject;
begin
  LContext := FCanvas.getContextAs2DContext('2d');
  LContext.fillStyleAsColor := '#11212d';
  LContext.fillRect(0, 0, FCanvas.width, FCanvas.height);
  LContext.fillStyleAsColor := '#2d4550';
  LContext.fillRect(0, 124, FCanvas.width, 1);
  LContext.fillRect(0, 204, FCanvas.width, 1);
  if (FWaveBins = nil) or (FWaveBins.length = 0) then
  begin
    Exit;
  end;
  LPeak := 0.00001;
  for LIndex := 0 to FWaveBins.length - 1 do
  begin
    LRow := TJSObject(FWaveBins[LIndex]);
    LMinimum := Abs(NumberField(LRow, 'min'));
    LMaximum := Abs(NumberField(LRow, 'max'));
    if LMinimum > LPeak then
    begin
      LPeak := LMinimum;
    end;
    if LMaximum > LPeak then
    begin
      LPeak := LMaximum;
    end;
  end;
  LContext.fillStyleAsColor := '#7dd8cf';
  LWidth := FCanvas.width / FWaveBins.length;
  for LIndex := 0 to FWaveBins.length - 1 do
  begin
    LRow := TJSObject(FWaveBins[LIndex]);
    LMinimum := NumberField(LRow, 'min');
    LMaximum := NumberField(LRow, 'max');
    LX := LIndex * LWidth;
    LContext.fillRect(LX, 124 - LMaximum / LPeak * 92,
      LWidth + 1, (LMaximum - LMinimum) / LPeak * 92 + 1);
  end;
  if FCurrentLabels <> nil then
  begin
    for LIndex := 0 to FCurrentLabels.length - 1 do
    begin
      LRow := TJSObject(FCurrentLabels[LIndex]);
      LStart := (NumberField(LRow, 'start_frame') - FWindowStart) /
        FWindowSpan * FCanvas.width;
      LEnd := (NumberField(LRow, 'end_frame') - FWindowStart) /
        FWindowSpan * FCanvas.width;
      if TextField(LRow, 'status') = 'approved' then
        LContext.fillStyleAsColor := '#9ce3aa'
      else
        LContext.fillStyleAsColor := '#78909a';
      LContext.fillRect(LStart, 211, LEnd - LStart + 2, 18);
    end;
  end;
  if (FDragMode <> dmNone) or
    ((FCurrentLabels <> nil) and (FSelectedLabel >= 0) and
    (FSelectedLabel < FCurrentLabels.length)) then
  begin
    if FDragMode <> dmNone then
    begin
      LStart := (FDragStart - FWindowStart) /
        FWindowSpan * FCanvas.width;
      LEnd := (FDragEnd - FWindowStart) /
        FWindowSpan * FCanvas.width;
    end
    else
    begin
      LSelected := TJSObject(FCurrentLabels[FSelectedLabel]);
      LStart := (NumberField(LSelected, 'start_frame') - FWindowStart) /
        FWindowSpan * FCanvas.width;
      LEnd := (NumberField(LSelected, 'end_frame') - FWindowStart) /
        FWindowSpan * FCanvas.width;
    end;
    LContext.fillStyleAsColor := '#b7e6ff';
    LContext.fillRect(LStart, 209, LEnd - LStart + 2, 2);
    LContext.fillRect(LStart - 3, 207, 6, 25);
    LContext.fillRect(LEnd - 3, 207, 6, 25);
  end;
  if FProposals <> nil then
  begin
    LCandidates := TJSArray(FProposals['candidates']);
    if LCandidates.length > 0 then
    begin
      if (FSelectedProposal >= 0) and
        (FSelectedProposal < LCandidates.length) then
      begin
        LFrames := TJSArray(
          TJSObject(LCandidates[FSelectedProposal])['frames']);
      end
      else
      begin
        LFrames := TJSArray(TJSObject(LCandidates[0])['frames']);
      end;
      LContext.fillStyleAsColor := '#f5c27c';
      for LIndex := 0 to LFrames.length - 1 do
      begin
        LX := (Double(LFrames[LIndex]) - FWindowStart) /
          FWindowSpan * FCanvas.width;
        LContext.fillRect(LX, 164, 2, 35);
      end;
    end;
  end;
end;

procedure TWorkbench.SelectLabel(const AIndex: Integer);
var
  LRow: TJSObject;
begin
  if (FCurrentLabels = nil) or (AIndex < 0) or
    (AIndex >= FCurrentLabels.length) then
  begin
    Exit;
  end;
  FSelectedLabel := AIndex;
  FDragMode := dmNone;
  LRow := TJSObject(FCurrentLabels[AIndex]);
  Input('label-id').value := TextField(LRow, 'label_id');
  Input('label-type').value := TextField(LRow, 'type');
  Input('label-value').value := TextField(LRow, 'value');
  Input('label-status').value := TextField(LRow, 'status');
  Input('label-part').value := TextField(LRow, 'part');
  Input('label-start').value :=
    IntToStr(Trunc(NumberField(LRow, 'start_frame')));
  Input('label-end').value :=
    IntToStr(Trunc(NumberField(LRow, 'end_frame')));
  Input('label-proposal').value := TextField(LRow, 'proposal_id');
  if TextField(LRow, 'type') = 'note' then
  begin
    Input('label-pitch').value :=
      IntToStr(Trunc(NumberField(LRow, 'pitch_midi')));
  end;
  DrawWaveform;
end;

function TWorkbench.CanvasX(const AEvent: TJSPointerEvent): Double;
var
  LRect: TJSDOMRect;
begin
  LRect := FCanvas.getBoundingClientRect;
  Result := (AEvent.clientX - LRect.left) / LRect.width * FCanvas.width;
end;

function TWorkbench.CanvasY(const AEvent: TJSPointerEvent): Double;
var
  LRect: TJSDOMRect;
begin
  LRect := FCanvas.getBoundingClientRect;
  Result := (AEvent.clientY - LRect.top) / LRect.height * FCanvas.height;
end;

function TWorkbench.FrameAtX(const AX: Double): Int64;
var
  LEnd: Int64;
begin
  LEnd := Smaller(FFrameCount, FWindowStart + FWindowSpan);
  Result := FWindowStart + Trunc(AX / FCanvas.width * FWindowSpan + 0.5);
  if Result < FWindowStart then
  begin
    Result := FWindowStart;
  end;
  if Result > LEnd then
  begin
    Result := LEnd;
  end;
end;

procedure TWorkbench.UpdateDrag(const AFrame: Int64);
var
  LDelta: Int64;
  LDuration: Int64;
begin
  case FDragMode of
    dmCreate:
      begin
        if AFrame < FDragAnchor then
        begin
          FDragStart := AFrame;
          FDragEnd := FDragAnchor;
        end
        else
        begin
          FDragStart := FDragAnchor;
          FDragEnd := AFrame;
        end;
        if FDragEnd = FDragStart then
        begin
          FDragEnd := Smaller(FFrameCount, FDragStart + 1);
        end;
      end;
    dmMove:
      begin
        LDelta := AFrame - FDragAnchor;
        LDuration := FDragOriginalEnd - FDragOriginalStart;
        FDragStart := FDragOriginalStart + LDelta;
        if FDragStart < 0 then
        begin
          FDragStart := 0;
        end;
        if FDragStart > FFrameCount - LDuration then
        begin
          FDragStart := FFrameCount - LDuration;
        end;
        FDragEnd := FDragStart + LDuration;
      end;
    dmStart:
      begin
        FDragStart := AFrame;
        if FDragStart >= FDragOriginalEnd then
        begin
          FDragStart := FDragOriginalEnd - 1;
        end;
      end;
    dmEnd:
      begin
        FDragEnd := AFrame;
        if FDragEnd <= FDragOriginalStart then
        begin
          FDragEnd := FDragOriginalStart + 1;
        end;
      end;
  end;
end;

procedure TWorkbench.UpdateWindowLabel;
var
  LEnd: Int64;
begin
  if FSampleRate <= 0 then
  begin
    Exit;
  end;
  LEnd := Smaller(FFrameCount, FWindowStart + FWindowSpan);
  Element('window-label').textContent :=
    IntToStr(FWindowStart) + '–' + IntToStr(LEnd) +
    ' frames · ' + IntToStr(FWindowStart div FSampleRate) +
    '–' + IntToStr(LEnd div FSampleRate) + ' s';
end;

procedure TWorkbench.Start; async;
var
  LResponse: TJSResponse;
  LData: TJSObject;
  LKey: String;
begin
  try
    LResponse := await(TJSResponse, FetchApi('/api/session', 'GET', ''));
    if LResponse.status = 200 then
    begin
      LData := await(TJSObject, LResponse.json());
      FToken := TextField(LData, 'token');
      ShowWorkspace;
      Status('Connected to loopback catalog.');
      RefreshLists;
    end
    else
    begin
      LKey := '';
      try
        LKey := window.localStorage.getItem(RememberedAccessKey);
      except
        // Browser storage can be disabled; manual connection still works.
      end;
      if isString(LKey) and (LKey <> '') then
      begin
        Status('Reconnecting to the LAN catalog…');
        ConnectWithKey(LKey, False);
      end
      else
      begin
        Status('Enter the local LAN access key to connect.');
      end;
    end;
  except
    on LError: Exception do
    begin
      Status('Could not reach the Pascal catalog service: ' +
        LError.Message, True);
    end;
  end;
end;

procedure TWorkbench.Connect; async;
var
  LKey: String;
begin
  LKey := Input('access-key').value;
  Input('access-key').value := '';
  ConnectWithKey(LKey, True);
end;

procedure TWorkbench.ConnectWithKey(const AKey: String;
  const ARemember: Boolean); async;
var
  LBody: TJSObject;
  LResponse: TJSResponse;
  LData: TJSObject;
  LStored: Boolean;
begin
  try
    LBody := TJSObject.new;
    LBody['access_key'] := AKey;
    LResponse := await(TJSResponse, FetchApi('/api/session', 'POST',
      TJSJSON.stringify(LBody)));
    if LResponse.status <> 200 then
    begin
      if LResponse.status = 403 then
      begin
        try
          window.localStorage.removeItem(RememberedAccessKey);
        except
          // A failed storage removal must not prevent manual connection.
        end;
        if ARemember then
        begin
          Status('Access key was not accepted. Enter the current key.', True);
        end
        else
        begin
          Status('Saved access key was not accepted. Enter the current key.', True);
        end;
      end
      else
      begin
        Status('Connection failed (HTTP ' +
          IntToStr(LResponse.status) + ').', True);
      end;
      Exit;
    end;
    LData := await(TJSObject, LResponse.json());
    FToken := TextField(LData, 'token');
    if FToken = '' then
    begin
      raise Exception.Create('Session token missing');
    end;
    LStored := not ARemember;
    if ARemember then
    begin
      try
        window.localStorage.setItem(RememberedAccessKey, AKey);
        LStored := True;
      except
        LStored := False;
      end;
    end;
    ShowWorkspace;
    Element('connection-actions').removeAttribute('hidden');
    if LStored then
    begin
      Status('Connected to catalog. This browser will reconnect automatically.');
    end
    else
    begin
      Status('Connected to catalog. Browser storage is unavailable; ' +
        'enter the key again next visit.');
    end;
    RefreshLists;
  except
    on LError: Exception do
    begin
      Status('Connection failed: ' + LError.Message, True);
    end;
  end;
end;

procedure TWorkbench.ForgetDevice;
begin
  try
    window.localStorage.removeItem(RememberedAccessKey);
  except
    on LError: Exception do
    begin
      Status('Could not remove the saved key: ' + LError.Message, True);
      Exit;
    end;
  end;
  Inc(FWindowEpoch);
  Inc(FAudioEpoch);
  FToken := '';
  FAudio.pause;
  FAudio.removeAttribute('src');
  Element('audio-mode').textContent := 'No region loaded';
  if FAudioUrl <> '' then
  begin
    TJSURL.revokeObjectURL(FAudioUrl);
    FAudioUrl := '';
  end;
  Element('workspace').setAttribute('hidden', '');
  Element('connection-actions').setAttribute('hidden', '');
  Element('login-panel').removeAttribute('hidden');
  Status('Saved key removed from this browser. Enter a key to reconnect.');
end;

procedure TWorkbench.RefreshLists; async;
var
  LResponse: TJSResponse;
  LData: TJSObject;
begin
  try
    LResponse := await(TJSResponse, FetchApi('/api/catalog', 'GET', ''));
    if LResponse.status <> 200 then
    begin
      raise Exception.Create('Catalog HTTP ' + IntToStr(LResponse.status));
    end;
    LData := await(TJSObject, LResponse.json());
    RenderCatalog(LData);
    LResponse := await(TJSResponse, FetchApi('/api/inbox', 'GET', ''));
    if LResponse.status <> 200 then
    begin
      raise Exception.Create('Inbox HTTP ' + IntToStr(LResponse.status));
    end;
    LData := await(TJSObject, LResponse.json());
    RenderInbox(LData);
    Status('Inbox and catalog loaded. Choose a track to review.');
  except
    on LError: Exception do
    begin
      Status('Catalog list failed: ' + LError.Message, True);
    end;
  end;
end;

procedure TWorkbench.ImportAll; async;
var
  LResponse: TJSResponse;
  LData: TJSObject;
begin
  try
    Status('Verifying and importing the prepared inbox…');
    LResponse := await(TJSResponse, FetchApi('/api/import', 'POST', '{}'));
    if LResponse.status <> 200 then
    begin
      raise Exception.Create('Import HTTP ' + IntToStr(LResponse.status));
    end;
    LData := await(TJSObject, LResponse.json());
    Status('Import: ' + IntToStr(Trunc(NumberField(LData, 'imported'))) +
      ' added, ' + IntToStr(Trunc(NumberField(LData, 'duplicate'))) +
      ' already present, ' +
      IntToStr(Trunc(NumberField(LData, 'failed'))) + ' failed.');
    RefreshLists;
  except
    on LError: Exception do
    begin
      Status('Import failed: ' + LError.Message, True);
    end;
  end;
end;

procedure TWorkbench.SelectTrack(const AIndex: Integer); async;
var
  LTrack: TJSObject;
begin
  if (FTracks = nil) or (AIndex < 0) or
    (AIndex >= FTracks.length) then
  begin
    Exit;
  end;
  LTrack := TJSObject(FTracks[AIndex]);
  FSourceHash := TextField(LTrack, 'source_sha256');
  FPartition := TextField(LTrack, 'partition');
  FSampleRate := Trunc(NumberField(LTrack, 'sample_rate'));
  FFrameCount := Trunc(NumberField(LTrack, 'frame_count'));
  if (FSampleRate <= 0) or (FFrameCount <= 0) then
  begin
    Status('The catalog track has invalid audio geometry.', True);
    FSourceHash := '';
    Exit;
  end;
  Inc(FWindowEpoch);
  FAudio.pause;
  FAudio.removeAttribute('src');
  Element('audio-mode').textContent := 'No region loaded';
  if FAudioUrl <> '' then
  begin
    TJSURL.revokeObjectURL(FAudioUrl);
    FAudioUrl := '';
  end;
  FWindowStart := 0;
  FWindowSpan := Smaller(FFrameCount,
    Smaller(Int64(FSampleRate) * 10, 8388608));
  FWaveBins := nil;
  FCurrentLabels := nil;
  FProposals := nil;
  FSelectedProposal := -1;
  FSelectedLabel := -1;
  FDragMode := dmNone;
  Input('jump-seconds').value := '0';
  Input('jump-seconds').setAttribute('max',
    IntToStr((FFrameCount - 1) div FSampleRate));
  Element('track-title').textContent := TextField(LTrack, 'title');
  Element('track-partition').textContent := UpperCase(FPartition);
  Element('track-meta').textContent :=
    TextField(LTrack, 'source_group') + ' · ' +
    TextField(LTrack, 'provenance') + ' · ' +
    TextField(LTrack, 'license') + ' · ' +
    IntToStr(FFrameCount div FSampleRate) + ' s · ' +
    IntToStr(FSampleRate) + ' Hz';
  TJSHTMLButtonElement(Element('suggest-button')).disabled :=
    FPartition = 'evaluation';
  Element('proposal-note').textContent := 'Loading suggestions…';
  RefreshWindow;
end;

procedure TWorkbench.RefreshWindow; async;
var
  LEnd: Int64;
  LStart: Int64;
  LEpoch: Integer;
  LHash: String;
  LPartition: String;
  LPath: String;
  LResponse: TJSResponse;
  LData: TJSObject;
begin
  if FSourceHash = '' then
  begin
    Exit;
  end;
  try
    Inc(FWindowEpoch);
    Inc(FAudioEpoch);
    FSelectedProposal := -1;
    FProposals := nil;
    TJSHTMLButtonElement(Element('load-cue-button')).disabled := True;
    LEpoch := FWindowEpoch;
    LHash := FSourceHash;
    LPartition := FPartition;
    LStart := FWindowStart;
    LEnd := Smaller(FFrameCount, LStart + FWindowSpan);
    FSelectedLabel := -1;
    FDragMode := dmNone;
    FAudio.pause;
    FAudio.removeAttribute('src');
    Element('audio-mode').textContent := 'No region loaded';
    if FAudioUrl <> '' then
    begin
      TJSURL.revokeObjectURL(FAudioUrl);
      FAudioUrl := '';
    end;
    UpdateWindowLabel;
    Input('jump-seconds').value := IntToStr(FWindowStart div FSampleRate);
    LPath := '/api/waveform?hash=' + LHash +
      '&start=' + IntToStr(LStart) +
      '&end=' + IntToStr(LEnd) + '&bins=512';
    LResponse := await(TJSResponse, FetchApi(LPath, 'GET', ''));
    if LEpoch <> FWindowEpoch then
    begin
      Exit;
    end;
    if LResponse.status <> 200 then
    begin
      raise Exception.Create('Waveform HTTP ' + IntToStr(LResponse.status));
    end;
    LData := await(TJSObject, LResponse.json());
    if LEpoch <> FWindowEpoch then
    begin
      Exit;
    end;
    FWaveBins := TJSArray(LData['bins']);
    LPath := '/api/current?hash=' + LHash +
      '&start=' + IntToStr(LStart) +
      '&end=' + IntToStr(LEnd) + '&count=2048';
    LResponse := await(TJSResponse, FetchApi(LPath, 'GET', ''));
    if LEpoch <> FWindowEpoch then
    begin
      Exit;
    end;
    if LResponse.status <> 200 then
    begin
      raise Exception.Create('Labels HTTP ' + IntToStr(LResponse.status));
    end;
    LData := await(TJSObject, LResponse.json());
    if LEpoch <> FWindowEpoch then
    begin
      Exit;
    end;
    FCurrentLabels := TJSArray(LData['labels']);
    FReviewRevision := Trunc(NumberField(LData, 'review_revision'));
    Element('revision-label').textContent :=
      'Revision ' + IntToStr(FReviewRevision);
    TJSHTMLButtonElement(Element('suggest-button')).disabled :=
      (LPartition = 'evaluation') and (FReviewRevision = 0);
    FProposals := nil;
    FSelectedProposal := -1;
    if (LPartition <> 'evaluation') or (FReviewRevision > 0) then
    begin
      LPath := '/api/proposals?hash=' + LHash +
        '&start=' + IntToStr(LStart) +
        '&end=' + IntToStr(LEnd);
      LResponse := await(TJSResponse, FetchApi(LPath, 'GET', ''));
      if LEpoch <> FWindowEpoch then
      begin
        Exit;
      end;
      if LResponse.status = 200 then
      begin
        FProposals := await(TJSObject, LResponse.json());
        if LEpoch <> FWindowEpoch then
        begin
          Exit;
        end;
      end
      else if LResponse.status <> 404 then
      begin
        raise Exception.Create('Proposals HTTP ' +
          IntToStr(LResponse.status));
      end;
    end;
    RenderLabels;
    RenderProposals;
    DrawWaveform;
    Status('Loaded source frames ' + IntToStr(LStart) +
      '–' + IntToStr(LEnd) + '.');
  except
    on LError: Exception do
    begin
      Status('Timeline failed: ' + LError.Message, True);
    end;
  end;
end;

procedure TWorkbench.LoadAudio(const ACue: Boolean); async;
var
  LEnd: Int64;
  LEpoch: Integer;
  LAudioEpoch: Integer;
  LCandidate: Integer;
  LStart: Int64;
  LHash: String;
  LPath: String;
  LResponse: TJSResponse;
  LBlob: TJSBlob;
begin
  if FSourceHash = '' then
  begin
    Exit;
  end;
  if ACue and ((FProposals = nil) or (FSelectedProposal < 0)) then
  begin
    Status('Select a saved beat proposal before loading its cue.', True);
    Exit;
  end;
  try
    LEpoch := FWindowEpoch;
    Inc(FAudioEpoch);
    LAudioEpoch := FAudioEpoch;
    LCandidate := FSelectedProposal;
    LStart := FWindowStart;
    LHash := FSourceHash;
    LEnd := Smaller(FFrameCount, Smaller(LStart + FWindowSpan,
      LStart + Int64(FSampleRate) * 30));
    if ACue then
    begin
      LPath := '/api/cue?hash=' + LHash +
        '&start=' + IntToStr(LStart) + '&end=' + IntToStr(LEnd) +
        '&candidate=' + IntToStr(LCandidate);
      Status('Loading Pythian beat cue over the original WAV…');
    end
    else
    begin
      LPath := '/api/audio?hash=' + LHash +
        '&start=' + IntToStr(LStart) + '&end=' + IntToStr(LEnd);
      Status('Loading original WAV region…');
    end;
    LResponse := await(TJSResponse, FetchApi(LPath, 'GET', ''));
    if (LEpoch <> FWindowEpoch) or (LAudioEpoch <> FAudioEpoch) then
    begin
      Exit;
    end;
    if LResponse.status <> 200 then
    begin
      raise Exception.Create('Audio HTTP ' + IntToStr(LResponse.status));
    end;
    LBlob := await(TJSBlob, TWorkbenchResponse(LResponse).blobRequest());
    if (LEpoch <> FWindowEpoch) or (LAudioEpoch <> FAudioEpoch) then
    begin
      Exit;
    end;
    if FAudioUrl <> '' then
    begin
      TJSURL.revokeObjectURL(FAudioUrl);
    end;
    FAudioUrl := TJSURL.createObjectURL(LBlob);
    FAudio.src := FAudioUrl;
    FAudio.loop := Input('loop-region').checked;
    FAudio.load;
    if ACue then
    begin
      Element('audio-mode').textContent :=
        'Pythian cue · grid ' + IntToStr(LCandidate + 1);
      Status('Pythian cue loaded over original audio. Press play.');
    end
    else
    begin
      Element('audio-mode').textContent := 'Original WAV';
      Status('Audio region loaded. Press play in the player.');
    end;
  except
    on LError: Exception do
    begin
      Status('Audio failed: ' + LError.Message, True);
    end;
  end;
end;

procedure TWorkbench.SuggestBeats; async;
var
  LEnd: Int64;
  LEpoch: Integer;
  LBody: TJSObject;
  LResponse: TJSResponse;
begin
  if (FSourceHash = '') or
    ((FPartition = 'evaluation') and (FReviewRevision = 0)) then
  begin
    Exit;
  end;
  LEpoch := FWindowEpoch;
  LEnd := Smaller(FFrameCount, FWindowStart + FWindowSpan);
  if (LEnd - FWindowStart > 2000000) or
    (LEnd - FWindowStart > Int64(FSampleRate) * 30) then
  begin
    Status('Zoom in to 30 seconds or less before requesting beat suggestions.',
      True);
    Exit;
  end;
  try
    LBody := TJSObject.new;
    LBody['source_sha256'] := FSourceHash;
    LBody['start_frame'] := FWindowStart;
    LBody['end_frame'] := LEnd;
    Status('Running native Pascal beat analysis…');
    LResponse := await(TJSResponse, FetchApi('/api/propose-beats', 'POST',
      TJSJSON.stringify(LBody)));
    if LEpoch <> FWindowEpoch then
    begin
      Exit;
    end;
    if LResponse.status <> 200 then
    begin
      raise Exception.Create('Proposal HTTP ' + IntToStr(LResponse.status));
    end;
    FProposals := await(TJSObject, LResponse.json());
    if LEpoch <> FWindowEpoch then
    begin
      Exit;
    end;
    FSelectedProposal := -1;
    RenderProposals;
    DrawWaveform;
    Status('Suggestions loaded as unreviewed hypotheses.');
  except
    on LError: Exception do
    begin
      Status('Suggestions failed: ' + LError.Message, True);
    end;
  end;
end;

procedure TWorkbench.SaveReview; async;
var
  LTransaction: TJSObject;
  LChange: TJSObject;
  LStart: Int64;
  LEnd: Int64;
  LResponse: TJSResponse;
begin
  if FSourceHash = '' then
  begin
    Exit;
  end;
  LStart := StrToInt64Def(Input('label-start').value, -1);
  LEnd := StrToInt64Def(Input('label-end').value, -1);
  if (LStart < 0) or (LEnd <= LStart) or (LEnd > FFrameCount) then
  begin
    Status('Enter a valid half-open source-frame interval.', True);
    Exit;
  end;
  try
    LChange := TJSObject.new;
    LChange['label_id'] := Input('label-id').value;
    LChange['type'] := Input('label-type').value;
    LChange['value'] := Input('label-value').value;
    LChange['status'] := Input('label-status').value;
    LChange['start_frame'] := LStart;
    LChange['end_frame'] := LEnd;
    LChange['part'] := Input('label-part').value;
    LChange['proposal_id'] := Input('label-proposal').value;
    if Input('label-type').value = 'note' then
    begin
      LChange['pitch_midi'] :=
        StrToIntDef(Input('label-pitch').value, -1);
    end;
    LTransaction := TJSObject.new;
    LTransaction['version'] := 1;
    LTransaction['source_sha256'] := FSourceHash;
    LTransaction['expected_revision'] := FReviewRevision;
    LTransaction['reviewer'] := Input('reviewer').value;
    LTransaction['change'] := LChange;
    LResponse := await(TJSResponse, FetchApi('/api/review', 'POST',
      TJSJSON.stringify(LTransaction)));
    if LResponse.status = 409 then
    begin
      FDragMode := dmNone;
      Status('Another review changed this source. Reloading current labels.',
        True);
      RefreshWindow;
      Exit;
    end;
    if LResponse.status <> 200 then
    begin
      raise Exception.Create('Review HTTP ' + IntToStr(LResponse.status));
    end;
    FDragMode := dmNone;
    Status('Review event saved. Reloading exact source labels.');
    RefreshWindow;
  except
    on LError: Exception do
    begin
      Status('Review failed: ' + LError.Message, True);
    end;
  end;
end;

procedure TWorkbench.DownloadExport; async;
var
  LResponse: TJSResponse;
  LBlob: TJSBlob;
  LLink: TJSHTMLAnchorElement;
  LDownloadUrl: String;
begin
  try
    Element('export-state').textContent :=
      'Verifying source hashes and building reviewed packet…';
    LResponse := await(TJSResponse, FetchApi('/api/export', 'GET', ''));
    if LResponse.status <> 200 then
    begin
      raise Exception.Create('Export HTTP ' + IntToStr(LResponse.status));
    end;
    LBlob := await(TJSBlob, TWorkbenchResponse(LResponse).blobRequest());
    LDownloadUrl := TJSURL.createObjectURL(LBlob);
    LLink := TJSHTMLAnchorElement(document.createElement('a'));
    LLink.href := LDownloadUrl;
    LLink.download := 'pythian-reviewed-catalog-v1.json';
    document.body.appendChild(LLink);
    LLink.click;
    LLink.remove;
    window.setTimeout(
      procedure()
      begin
        TJSURL.revokeObjectURL(LDownloadUrl);
      end, 30000);
    Element('export-state').textContent :=
      'Download requested: ' + IntToStr(LBlob.size) +
      ' bytes of reviewed catalog JSON.';
  except
    on LError: Exception do
    begin
      Element('export-state').textContent :=
        'Export failed: ' + LError.Message;
      Status('Reviewed export failed: ' + LError.Message, True);
    end;
  end;
end;

procedure TWorkbench.UploadReviewed; async;
var
  LFiles: TJSHTMLFileList;
  LFile: TJSHTMLFile;
  LText: String;
  LResponse: TJSResponse;
  LReport: TJSObject;
begin
  try
    LFiles := Input('reviewed-packet').files;
    if (LFiles = nil) or (LFiles.length <> 1) then
    begin
      raise Exception.Create('Choose one reviewed JSON packet.');
    end;
    LFile := LFiles[0];
    if (LFile.size < 1) or (LFile.size > 67108864) then
    begin
      raise Exception.Create('Packet must be between 1 byte and 64 MiB.');
    end;
    Element('import-reviewed-state').textContent :=
      'Reading and validating reviewed packet…';
    LText := await(String, LFile.text());
    LResponse := await(TJSResponse,
      FetchApi('/api/import-reviewed', 'POST', LText));
    if LResponse.status <> 200 then
    begin
      raise Exception.Create('Replay HTTP ' + IntToStr(LResponse.status));
    end;
    LReport := await(TJSObject, LResponse.json());
    Element('import-reviewed-state').textContent :=
      'Packet ' + TextField(LReport, 'status') + ': ' +
      IntToStr(Trunc(NumberField(LReport, 'track_count'))) + ' tracks.';
    RefreshLists;
  except
    on LError: Exception do
    begin
      Element('import-reviewed-state').textContent :=
        'Replay failed: ' + LError.Message;
      Status('Reviewed packet replay failed: ' + LError.Message, True);
    end;
  end;
end;

function TWorkbench.HandleConnect(AEvent: TJSMouseEvent): Boolean;
begin
  Connect;
  Result := False;
end;

function TWorkbench.HandleForgetDevice(AEvent: TJSMouseEvent): Boolean;
begin
  ForgetDevice;
  Result := False;
end;

function TWorkbench.HandleImport(AEvent: TJSMouseEvent): Boolean;
begin
  ImportAll;
  Result := False;
end;

function TWorkbench.HandleTrack(AEvent: TJSMouseEvent): Boolean;
begin
  SelectTrack(StrToIntDef(
    TJSElement(AEvent.currentTarget).getAttribute('data-index'), -1));
  Result := False;
end;

function TWorkbench.HandleLabel(AEvent: TJSMouseEvent): Boolean;
var
  LIndex: Integer;
begin
  LIndex := StrToIntDef(
    TJSElement(AEvent.currentTarget).getAttribute('data-index'), -1);
  SelectLabel(LIndex);
  Result := False;
end;

function TWorkbench.HandleCanvasDown(AEvent: TJSPointerEvent): Boolean;
var
  LX: Double;
  LY: Double;
  LSeek: Double;
  LStartX: Double;
  LEndX: Double;
  LRow: TJSObject;
  LIndex: Integer;
  LPass: Integer;
  LHit: Integer;
begin
  Result := False;
  if (FSourceHash = '') or (FWaveBins = nil) or
    (AEvent.button <> 0) or
    (FDragMode in [dmCreate, dmMove, dmStart, dmEnd]) then
  begin
    Exit;
  end;
  LX := CanvasX(AEvent);
  LY := CanvasY(AEvent);
  if (LY >= 0) and (LY < 207) then
  begin
    if (FAudioUrl = '') or (FAudio.readyState = 0) then
    begin
      Status('Load this region before seeking within its waveform.');
    end
    else
    begin
      LSeek := (FrameAtX(LX) - FWindowStart) / FSampleRate;
      if LSeek >= FAudio.Duration then
      begin
        Status('That point is beyond the loaded audio. Zoom in or load a later region.');
      end
      else
      begin
        FAudio.currentTime := LSeek;
        Status('Playback moved to source frame ' +
          IntToStr(FrameAtX(LX)) + '.');
      end;
    end;
    AEvent.preventDefault;
    Exit;
  end;
  if (LY < 207) or (LY > 235) then
  begin
    Exit;
  end;
  FDragMode := dmNone;
  LHit := -1;
  if FCurrentLabels <> nil then
  begin
    for LPass := 0 to FCurrentLabels.length do
    begin
      if LPass = 0 then
      begin
        LIndex := FSelectedLabel;
      end
      else
      begin
        LIndex := FCurrentLabels.length - LPass;
      end;
      if (LIndex < 0) or (LIndex >= FCurrentLabels.length) then
      begin
        Continue;
      end;
      LRow := TJSObject(FCurrentLabels[LIndex]);
      LStartX := (NumberField(LRow, 'start_frame') - FWindowStart) /
        FWindowSpan * FCanvas.width;
      LEndX := (NumberField(LRow, 'end_frame') - FWindowStart) /
        FWindowSpan * FCanvas.width;
      if (LX >= LStartX - 10) and (LX <= LEndX + 10) then
      begin
        LHit := LIndex;
        Break;
      end;
    end;
  end;
  if LHit >= 0 then
  begin
    SelectLabel(LHit);
    LRow := TJSObject(FCurrentLabels[LHit]);
    FDragOriginalStart := Trunc(NumberField(LRow, 'start_frame'));
    FDragOriginalEnd := Trunc(NumberField(LRow, 'end_frame'));
    FDragStart := FDragOriginalStart;
    FDragEnd := FDragOriginalEnd;
    LStartX := (FDragStart - FWindowStart) /
      FWindowSpan * FCanvas.width;
    LEndX := (FDragEnd - FWindowStart) /
      FWindowSpan * FCanvas.width;
    if Abs(LX - LStartX) <= 10 then
    begin
      FDragMode := dmStart;
    end
    else if Abs(LX - LEndX) <= 10 then
    begin
      FDragMode := dmEnd;
    end
    else
    begin
      FDragMode := dmMove;
    end;
  end
  else
  begin
    FSelectedLabel := -1;
    FDragMode := dmCreate;
    FDragStart := FrameAtX(LX);
    if FDragStart >= FFrameCount then
    begin
      FDragStart := FFrameCount - 1;
    end;
    FDragEnd := FDragStart + 1;
    Input('label-id').value := '';
    Input('label-type').value := 'presence';
    Input('label-value').value := '';
    Input('label-status').value := 'uncertain';
    Input('label-part').value := '';
    Input('label-proposal').value := '';
  end;
  FDragPointer := AEvent.pointerId;
  FDragAnchor := FrameAtX(LX);
  FCanvas.setPointerCapture(FDragPointer);
  AEvent.preventDefault;
  DrawWaveform;
end;

function TWorkbench.HandleCanvasMove(AEvent: TJSPointerEvent): Boolean;
begin
  Result := False;
  if (FDragMode in [dmCreate, dmMove, dmStart, dmEnd]) and
    (AEvent.pointerId = FDragPointer) then
  begin
    UpdateDrag(FrameAtX(CanvasX(AEvent)));
    DrawWaveform;
    AEvent.preventDefault;
  end;
end;

function TWorkbench.HandleCanvasUp(AEvent: TJSPointerEvent): Boolean;
begin
  Result := False;
  if (FDragMode in [dmCreate, dmMove, dmStart, dmEnd]) and
    (AEvent.pointerId = FDragPointer) then
  begin
    UpdateDrag(FrameAtX(CanvasX(AEvent)));
    FCanvas.releasePointerCapture(FDragPointer);
    FDragMode := dmDraft;
    Input('label-start').value := IntToStr(FDragStart);
    Input('label-end').value := IntToStr(FDragEnd);
    DrawWaveform;
    Status('Span drafted at frames ' + IntToStr(FDragStart) +
      '–' + IntToStr(FDragEnd) +
      '. Check the label and save the review event.');
    AEvent.preventDefault;
  end;
end;

function TWorkbench.HandleCanvasCancel(AEvent: TJSPointerEvent): Boolean;
begin
  Result := False;
  if (FDragMode in [dmCreate, dmMove, dmStart, dmEnd]) and
    (AEvent.pointerId = FDragPointer) then
  begin
    FDragMode := dmNone;
    DrawWaveform;
  end;
end;

function TWorkbench.HandleProposal(AEvent: TJSMouseEvent): Boolean;
var
  LIndex: Integer;
  LRows: TJSArray;
  LFrames: TJSArray;
  LRow: TJSObject;
  LFrame: Int64;
begin
  LIndex := StrToIntDef(
    TJSElement(AEvent.currentTarget).getAttribute('data-index'), -1);
  if FProposals = nil then
  begin
    Exit(False);
  end;
  LRows := TJSArray(FProposals['candidates']);
  if (LIndex < 0) or (LIndex >= LRows.length) then
  begin
    Exit(False);
  end;
  LRow := TJSObject(LRows[LIndex]);
  LFrames := TJSArray(LRow['frames']);
  FSelectedProposal := LIndex;
  TJSHTMLButtonElement(Element('load-cue-button')).disabled :=
    LFrames.length = 0;
  Element('load-cue-button').textContent :=
    'Load cue for grid ' + IntToStr(LIndex + 1);
  DrawWaveform;
  LFrame := FWindowStart;
  if LFrames.length > 0 then
  begin
    LFrame := Trunc(Double(LFrames[0]));
  end;
  Input('label-id').value := 'review-' + IntToStr(FReviewRevision + 1);
  Input('label-type').value := 'beat';
  Input('label-value').value := 'candidate-grid-point';
  Input('label-status').value := 'uncertain';
  Input('label-start').value := IntToStr(LFrame);
  Input('label-end').value := IntToStr(LFrame + 1);
  Input('label-proposal').value := TextField(LRow, 'proposal_id');
  if LFrames.length = 0 then
  begin
    Status('This proposal has no cue points. Choose your own review verdict.');
  end
  else
  begin
    Status('Proposal copied to editor. Choose your own verdict before saving.');
  end;
  Result := False;
end;

function TWorkbench.HandlePrevious(AEvent: TJSMouseEvent): Boolean;
begin
  if FSourceHash <> '' then
  begin
    if FWindowStart > FWindowSpan then
      Dec(FWindowStart, FWindowSpan)
    else
      FWindowStart := 0;
    RefreshWindow;
  end;
  Result := False;
end;

function TWorkbench.HandleNext(AEvent: TJSMouseEvent): Boolean;
begin
  if FSourceHash <> '' then
  begin
    FWindowStart := Smaller(FFrameCount - 1,
      FWindowStart + FWindowSpan);
    RefreshWindow;
  end;
  Result := False;
end;

function TWorkbench.HandleJump(AEvent: TJSMouseEvent): Boolean;
var
  LSeconds: Int64;
  LFrame: Int64;
begin
  Result := False;
  if FSourceHash = '' then
  begin
    Status('Choose a catalog track before jumping to a time.', True);
    Exit;
  end;
  if not TryStrToInt64(Trim(Input('jump-seconds').value), LSeconds) or
    (LSeconds < 0) or
    (LSeconds > (FFrameCount - 1) div FSampleRate) then
  begin
    Status('Enter a whole source second between 0 and ' +
      IntToStr((FFrameCount - 1) div FSampleRate) + '.', True);
    Exit;
  end;
  LFrame := LSeconds * FSampleRate;
  if LFrame > FFrameCount - FWindowSpan then
  begin
    FWindowStart := FFrameCount - FWindowSpan;
  end
  else
  begin
    FWindowStart := LFrame;
  end;
  RefreshWindow;
  Input('jump-seconds').value := IntToStr(LSeconds);
end;

function TWorkbench.HandleLoop(AEvent: TJSMouseEvent): Boolean;
begin
  FAudio.loop := Input('loop-region').checked;
  Result := True;
end;

function TWorkbench.HandleZoomIn(AEvent: TJSMouseEvent): Boolean;
begin
  if FSourceHash <> '' then
  begin
    FWindowSpan := Smaller(FFrameCount,
      FWindowSpan div 2);
    if FWindowSpan < 1 then
    begin
      FWindowSpan := 1;
    end;
    RefreshWindow;
  end;
  Result := False;
end;

function TWorkbench.HandleZoomOut(AEvent: TJSMouseEvent): Boolean;
begin
  if FSourceHash <> '' then
  begin
    FWindowSpan := Smaller(FFrameCount,
      Smaller(8388608, FWindowSpan * 2));
    RefreshWindow;
  end;
  Result := False;
end;

function TWorkbench.HandleLoadAudio(AEvent: TJSMouseEvent): Boolean;
begin
  LoadAudio(False);
  Result := False;
end;

function TWorkbench.HandleLoadCue(AEvent: TJSMouseEvent): Boolean;
begin
  LoadAudio(True);
  Result := False;
end;

function TWorkbench.HandleSuggest(AEvent: TJSMouseEvent): Boolean;
begin
  SuggestBeats;
  Result := False;
end;

function TWorkbench.HandleSave(AEvent: TJSMouseEvent): Boolean;
begin
  SaveReview;
  Result := False;
end;

function TWorkbench.HandleExport(AEvent: TJSMouseEvent): Boolean;
begin
  DownloadExport;
  Result := False;
end;

function TWorkbench.HandleUploadReviewed(AEvent: TJSMouseEvent): Boolean;
begin
  UploadReviewed;
  Result := False;
end;

procedure TWorkbench.Run;
begin
  FSelectedLabel := -1;
  FCanvas := TJSHTMLCanvasElement(Element('waveform'));
  FAudio := TJSHTMLAudioElement(Element('preview'));
  TJSHTMLButtonElement(Element('connect-button')).onclick := @HandleConnect;
  TJSHTMLButtonElement(Element('forget-device-button')).onclick :=
    @HandleForgetDevice;
  TJSHTMLButtonElement(Element('import-button')).onclick := @HandleImport;
  TJSHTMLButtonElement(Element('previous-button')).onclick := @HandlePrevious;
  TJSHTMLButtonElement(Element('next-button')).onclick := @HandleNext;
  TJSHTMLButtonElement(Element('jump-button')).onclick := @HandleJump;
  Input('loop-region').onclick := @HandleLoop;
  TJSHTMLButtonElement(Element('zoom-in-button')).onclick := @HandleZoomIn;
  TJSHTMLButtonElement(Element('zoom-out-button')).onclick := @HandleZoomOut;
  TJSHTMLButtonElement(Element('load-audio-button')).onclick := @HandleLoadAudio;
  TJSHTMLButtonElement(Element('load-cue-button')).onclick := @HandleLoadCue;
  TJSHTMLButtonElement(Element('suggest-button')).onclick := @HandleSuggest;
  TJSHTMLButtonElement(Element('save-label-button')).onclick := @HandleSave;
  TJSHTMLButtonElement(Element('export-button')).onclick := @HandleExport;
  TJSHTMLButtonElement(Element('import-reviewed-button')).onclick :=
    @HandleUploadReviewed;
  FCanvas.onpointerdown := @HandleCanvasDown;
  FCanvas.onpointermove := @HandleCanvasMove;
  FCanvas.onpointerup := @HandleCanvasUp;
  FCanvas.onpointercancel := @HandleCanvasCancel;
  DrawWaveform;
  Start;
end;

var
  Workbench: TWorkbench;
begin
  Workbench := TWorkbench.Create;
  Workbench.Run;
end.
