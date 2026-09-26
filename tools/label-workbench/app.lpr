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
  ReviewHistoryPrefix = 'pythian.catalog.review-history.v1.';
  MaximumLocalUndoEntries = 128;

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
    FSourceGroup: String;
    FPartition: String;
    FAudioUrl: String;
    FTracks: TJSArray;
    FWaveBins: TJSArray;
    FCurrentLabels: TJSArray;
    FPendingChanges: TJSArray;
    FPendingSourceHash: String;
    FPendingSourceGroup: String;
    FPendingPartition: String;
    FPendingOperation: String;
    FPendingCommitted: Integer;
    FPendingConflict: Boolean;
    FPendingHistoryMode: String;
    FPendingHistoryEntry: TJSObject;
    FSaveInProgress: Boolean;
    FUndoStack: TJSArray;
    FRedoStack: TJSArray;
    FHistoryStale: Boolean;
    FHistoryLoading: Boolean;
    FHistoryLoadFailed: Boolean;
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
    procedure RenderMergeTargets;
    procedure UpdatePendingUi;
    procedure UpdateHistoryUi;
    procedure LoadLocalHistory;
    procedure SaveLocalHistory(const ARevision: Integer);
    procedure StageHistoryAction(const ARedo: Boolean);
    procedure StageHistoryTarget(const AEntry: TJSObject;
      const ARedo: Boolean);
    procedure ClearPending;
    procedure AppendPending(const AChange: TJSObject);
    function RowMatchesSource(const ARow: TJSObject): Boolean;
    function EditorChange(const AStartFrame, AEndFrame: Int64;
      const ALabelId: String): TJSObject;
    function RowChange(const ARow: TJSObject;
      const AStatus: String = ''): TJSObject;
    function NextOperationLabelId(const APrefix: String): String;
    function SameLabelIdentity(const ALeft, ARight: TJSObject): Boolean;
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
    function HandleUndo(AEvent: TJSMouseEvent): Boolean;
    function HandleRedo(AEvent: TJSMouseEvent): Boolean;
    function HandleClearHistory(AEvent: TJSMouseEvent): Boolean;
    function HandleKeyboard(AEvent: TJSKeyboardEvent): Boolean;
    function HandleSplit(AEvent: TJSMouseEvent): Boolean;
    function HandleMerge(AEvent: TJSMouseEvent): Boolean;
    function HandleCancelPending(AEvent: TJSMouseEvent): Boolean;
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

function CloneObject(const AObject: TJSObject): TJSObject;
begin
  if AObject = nil then
    Exit(nil);
  Result := TJSObject(TJSJSON.parse(TJSJSON.stringify(AObject)));
end;

function CloneArray(const AArray: TJSArray): TJSArray;
begin
  if AArray = nil then
    Exit(TJSArray.new);
  Result := TJSArray(TJSJSON.parse(TJSJSON.stringify(AArray)));
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
    RenderMergeTargets;
    UpdatePendingUi;
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
  RenderMergeTargets;
  UpdatePendingUi;
end;

procedure TWorkbench.RenderMergeTargets;
var
  LSelect: TJSHTMLSelectElement;
  LOption: TJSHTMLOptionElement;
  LRow: TJSObject;
  LIndex: Integer;
begin
  LSelect := TJSHTMLSelectElement(Element('merge-label-target'));
  LSelect.innerHTML := '';
  LOption := TJSHTMLOptionElement(TJSHTMLOptionElement.New(
    'Choose an adjacent label', ''));
  LOption.disabled := True;
  LOption.selected := True;
  LSelect.add(LOption);
  if FCurrentLabels = nil then
  begin
    Exit;
  end;
  for LIndex := 0 to FCurrentLabels.length - 1 do
  begin
    if LIndex = FSelectedLabel then
    begin
      Continue;
    end;
    LRow := TJSObject(FCurrentLabels[LIndex]);
    if not RowMatchesSource(LRow) or
      (TextField(LRow, 'status') = 'withdrawn') then
    begin
      Continue;
    end;
    LOption := TJSHTMLOptionElement(TJSHTMLOptionElement.New(
      TextField(LRow, 'label_id') + ' · ' +
      IntToStr(Trunc(NumberField(LRow, 'start_frame'))) + '–' +
      IntToStr(Trunc(NumberField(LRow, 'end_frame'))),
      IntToStr(LIndex)));
    LSelect.add(LOption);
  end;
end;

procedure TWorkbench.UpdatePendingUi;
var
  LCount: Integer;
  LChange: TJSObject;
  LRows: String;
  LIndex: Integer;
begin
  LCount := 0;
  if FPendingChanges <> nil then
  begin
    LCount := FPendingChanges.length;
  end;
  TJSHTMLButtonElement(Element('split-label-button')).disabled :=
    (FSourceHash = '') or (LCount > 0) or FPendingConflict;
  TJSHTMLButtonElement(Element('merge-label-button')).disabled :=
    (FSourceHash = '') or (LCount > 0) or FPendingConflict;
  TJSHTMLButtonElement(Element('cancel-staged-button')).disabled :=
    (LCount = 0) or FSaveInProgress;
  TJSHTMLButtonElement(Element('save-label-button')).disabled :=
    (FSourceHash = '') or FPendingConflict or FSaveInProgress;
  if FSaveInProgress then
  begin
    if LCount > 0 then
    begin
      Element('pending-review-note').textContent :=
        IntToStr(FPendingCommitted) + ' event(s) saved; ' +
        IntToStr(LCount) +
        ' remain staged while the current source revision and labels reload. Further edits are locked.';
    end
    else
    begin
      Element('pending-review-note').textContent :=
        'The final staged event was saved. Waiting for the current source revision and labels to reload; further edits are locked.';
    end;
    UpdateHistoryUi;
    Exit;
  end;
  if LCount = 0 then
  begin
    Element('pending-review-note').textContent :=
      'Split and merge edits stay in this browser until you explicitly save a review event.';
    Element('pending-review-list').textContent := '';
    TJSHTMLButtonElement(Element('save-label-button')).textContent :=
      'Save review event';
    UpdateHistoryUi;
    Exit;
  end;
  TJSHTMLButtonElement(Element('save-label-button')).disabled := False;
  if FPendingConflict then
  begin
    TJSHTMLButtonElement(Element('save-label-button')).disabled := True;
    Element('pending-review-note').textContent :=
      'The source revision changed while this operation was staged. Cancel the remaining unsaved events, reload the current labels, and stage the operation again.';
    Element('pending-review-list').textContent :=
      IntToStr(FPendingCommitted) + ' staged event(s) already saved; ' +
      IntToStr(LCount) + ' remain unsaved.';
    UpdateHistoryUi;
    Exit;
  end;
  TJSHTMLButtonElement(Element('save-label-button')).textContent :=
    'Commit next staged event (' + IntToStr(FPendingCommitted + 1) +
    ' of ' + IntToStr(FPendingCommitted + LCount) + ')';
  Element('pending-review-note').textContent :=
    FPendingOperation + ' is staged for this source only. ' +
    IntToStr(FPendingCommitted) + ' event(s) saved; ' + IntToStr(LCount) +
    ' remain unsaved. Each click on “Commit next staged event” saves one event; navigation is locked until the queue is completed or cancelled.';
  LRows := '';
  for LIndex := 0 to LCount - 1 do
  begin
    LChange := TJSObject(FPendingChanges[LIndex]);
    if LRows <> '' then
    begin
      LRows := LRows + ' · ';
    end;
    LRows := LRows + TextField(LChange, 'label_id') + ' ' +
      IntToStr(Trunc(NumberField(LChange, 'start_frame'))) + '–' +
      IntToStr(Trunc(NumberField(LChange, 'end_frame'))) + ' ' +
      TextField(LChange, 'status');
  end;
  Element('pending-review-list').textContent := LRows;
  UpdateHistoryUi;
end;

procedure TWorkbench.UpdateHistoryUi;
var
  LUndoCount: Integer;
  LRedoCount: Integer;
  LLocked: Boolean;
begin
  LUndoCount := 0;
  LRedoCount := 0;
  if FUndoStack <> nil then
    LUndoCount := FUndoStack.length;
  if FRedoStack <> nil then
    LRedoCount := FRedoStack.length;
  LLocked := (FSourceHash = '') or FHistoryStale or FHistoryLoading or
    FHistoryLoadFailed or FSaveInProgress or
    ((FPendingChanges <> nil) and (FPendingChanges.length > 0));
  TJSHTMLButtonElement(Element('undo-review-button')).disabled :=
    LLocked or (LUndoCount = 0);
  TJSHTMLButtonElement(Element('redo-review-button')).disabled :=
    LLocked or (LRedoCount = 0);
  TJSHTMLButtonElement(Element('clear-history-button')).disabled :=
    (FSourceHash = '') or FHistoryLoading or FHistoryLoadFailed or FSaveInProgress or
    ((FPendingChanges <> nil) and (FPendingChanges.length > 0));
  if FHistoryLoading then
    Element('history-note').textContent :=
      'Loading this source’s saved review history…'
  else if FHistoryLoadFailed then
    Element('history-note').textContent :=
      'Source history did not finish loading. Reload this source window before using undo or redo.'
  else if FHistoryStale then
    Element('history-note').textContent :=
      'Review history changed outside this browser. Undo and redo are paused; clear local history to continue safely.'
  else if FSourceHash = '' then
    Element('history-note').textContent :=
      'Undo and redo apply to saved review events for the selected source.'
  else
    Element('history-note').textContent :=
      'Saved local history: ' + IntToStr(LUndoCount) + ' undo, ' +
      IntToStr(LRedoCount) + ' redo. Ctrl/Cmd+Z stages undo; Ctrl/Cmd+Shift+Z stages redo. Save explicitly to append the restoring event.';
end;

procedure TWorkbench.LoadLocalHistory;
var
  LText: String;
  LData: TJSObject;
  LRevision: Integer;
begin
  FUndoStack := TJSArray.new;
  FRedoStack := TJSArray.new;
  FHistoryStale := False;
  FHistoryLoading := False;
  FHistoryLoadFailed := False;
  if FSourceHash = '' then
  begin
    UpdateHistoryUi;
    Exit;
  end;
  try
    LText := window.localStorage.getItem(ReviewHistoryPrefix + FSourceHash);
    if LText <> '' then
    begin
      LData := TJSObject(TJSJSON.parse(LText));
      LRevision := Trunc(NumberField(LData, 'revision'));
      if TextField(LData, 'source_sha256') <> FSourceHash then
        FHistoryStale := True
      else if LRevision <> FReviewRevision then
        FHistoryStale := True
      else
      begin
        if isObject(LData['undo']) then
          FUndoStack := CloneArray(TJSArray(LData['undo']));
        if isObject(LData['redo']) then
          FRedoStack := CloneArray(TJSArray(LData['redo']));
      end;
    end;
  except
    on LError: Exception do
    begin
      FHistoryStale := True;
      Status('Local undo history could not be read: ' + LError.Message, True);
    end;
  end;
  UpdateHistoryUi;
end;

procedure TWorkbench.SaveLocalHistory(const ARevision: Integer);
var
  LData: TJSObject;
begin
  if FSourceHash = '' then
    Exit;
  LData := TJSObject.new;
  LData['version'] := 1;
  LData['source_sha256'] := FSourceHash;
  LData['revision'] := ARevision;
  LData['undo'] := FUndoStack;
  LData['redo'] := FRedoStack;
  try
    window.localStorage.setItem(ReviewHistoryPrefix + FSourceHash,
      TJSJSON.stringify(LData));
    FHistoryStale := False;
  except
    on LError: Exception do
    begin
      FHistoryStale := True;
      Status('Review event saved, but browser undo history could not be stored: ' +
        LError.Message, True);
    end;
  end;
  UpdateHistoryUi;
end;

procedure TWorkbench.StageHistoryTarget(const AEntry: TJSObject;
  const ARedo: Boolean);
var
  LTarget: TJSObject;
  LAfter: TJSObject;
begin
  if (AEntry = nil) or FHistoryStale or FSaveInProgress or
    ((FPendingChanges <> nil) and (FPendingChanges.length > 0)) then
    Exit;
  LAfter := TJSObject(AEntry['after']);
  if TextField(AEntry, 'source_sha256') <> FSourceHash then
  begin
    FHistoryStale := True;
    UpdateHistoryUi;
    Status('This undo entry belongs to another source. No review event was staged.',
      True);
    Exit;
  end;
  if ARedo then
    LTarget := CloneObject(LAfter)
  else if isObject(AEntry['before']) then
    LTarget := CloneObject(TJSObject(AEntry['before']))
  else
  begin
    LTarget := CloneObject(LAfter);
    LTarget['status'] := 'withdrawn';
  end;
  if LTarget = nil then
  begin
    Status('This history entry has no restorable label state.', True);
    Exit;
  end;
  FPendingHistoryMode := 'undo';
  if ARedo then
    FPendingHistoryMode := 'redo';
  FPendingHistoryEntry := CloneObject(AEntry);
  AppendPending(LTarget);
  FPendingOperation := 'Undo' ;
  if ARedo then
    FPendingOperation := 'Redo';
  UpdatePendingUi;
  UpdateHistoryUi;
  Status(FPendingOperation + ' is staged for source frames ' +
    IntToStr(Trunc(NumberField(LTarget, 'start_frame'))) + '–' +
    IntToStr(Trunc(NumberField(LTarget, 'end_frame'))) +
    '. Click Save review event to append it to the audit history.');
end;

procedure TWorkbench.StageHistoryAction(const ARedo: Boolean);
var
  LStack: TJSArray;
begin
  if FHistoryStale then
  begin
    Status('Local review history is stale. Clear it before staging undo or redo.',
      True);
    Exit;
  end;
  if ARedo then
    LStack := FRedoStack
  else
    LStack := FUndoStack;
  if (LStack = nil) or (LStack.length = 0) then
  begin
    Status('No saved review event is available for this action.', True);
    Exit;
  end;
  StageHistoryTarget(TJSObject(LStack[LStack.length - 1]), ARedo);
end;

procedure TWorkbench.ClearPending;
begin
  FPendingChanges := nil;
  FPendingSourceHash := '';
  FPendingSourceGroup := '';
  FPendingPartition := '';
  FPendingOperation := '';
  FPendingCommitted := 0;
  FPendingConflict := False;
  FPendingHistoryMode := '';
  FPendingHistoryEntry := nil;
  UpdatePendingUi;
  UpdateHistoryUi;
end;

procedure TWorkbench.AppendPending(const AChange: TJSObject);
var
  LIndex: Integer;
begin
  if FPendingChanges = nil then
  begin
    FPendingChanges := TJSArray.new;
    FPendingSourceHash := FSourceHash;
    FPendingSourceGroup := FSourceGroup;
    FPendingPartition := FPartition;
    FPendingCommitted := 0;
    FPendingConflict := False;
  end;
  LIndex := FPendingChanges.length;
  FPendingChanges[LIndex] := AChange;
end;

function TWorkbench.RowMatchesSource(const ARow: TJSObject): Boolean;
var
  LValue: String;
begin
  Result := False;
  if (ARow = nil) or (FSourceHash = '') then
  begin
    Exit;
  end;
  LValue := TextField(ARow, 'source_sha256');
  if (LValue <> '') and (LValue <> FSourceHash) then
  begin
    Exit;
  end;
  LValue := TextField(ARow, 'source_group');
  if (LValue <> '') and (LValue <> FSourceGroup) then
  begin
    Exit;
  end;
  LValue := TextField(ARow, 'partition');
  if (LValue <> '') and (LValue <> FPartition) then
  begin
    Exit;
  end;
  Result := True;
end;

function TWorkbench.EditorChange(const AStartFrame, AEndFrame: Int64;
  const ALabelId: String): TJSObject;
begin
  Result := TJSObject.new;
  Result['label_id'] := ALabelId;
  Result['type'] := Input('label-type').value;
  Result['value'] := Input('label-value').value;
  Result['status'] := Input('label-status').value;
  Result['start_frame'] := AStartFrame;
  Result['end_frame'] := AEndFrame;
  Result['part'] := Input('label-part').value;
  Result['proposal_id'] := Input('label-proposal').value;
  if Input('label-type').value = 'note' then
  begin
    Result['pitch_midi'] := StrToIntDef(Input('label-pitch').value, -1);
  end;
end;

function TWorkbench.RowChange(const ARow: TJSObject;
  const AStatus: String): TJSObject;
var
  LStatus: String;
begin
  Result := TJSObject.new;
  Result['label_id'] := TextField(ARow, 'label_id');
  Result['type'] := TextField(ARow, 'type');
  Result['value'] := TextField(ARow, 'value');
  LStatus := AStatus;
  if LStatus = '' then
  begin
    LStatus := TextField(ARow, 'status');
  end;
  Result['status'] := LStatus;
  Result['start_frame'] := Trunc(NumberField(ARow, 'start_frame'));
  Result['end_frame'] := Trunc(NumberField(ARow, 'end_frame'));
  Result['part'] := TextField(ARow, 'part');
  Result['proposal_id'] := TextField(ARow, 'proposal_id');
  if TextField(ARow, 'type') = 'note' then
  begin
    Result['pitch_midi'] := Trunc(NumberField(ARow, 'pitch_midi'));
  end;
end;

function TWorkbench.NextOperationLabelId(const APrefix: String): String;
var
  LCandidate: String;
  LIndex: Integer;
  LUsed: Boolean;
  LRow: TJSObject;
  LChange: TJSObject;
  LAttempt: Integer;
begin
  for LAttempt := 1 to 2048 do
  begin
    LCandidate := 'workbench-' + APrefix + '-r' +
      IntToStr(FReviewRevision + 1) + '-' + IntToStr(LAttempt);
    LUsed := False;
    if FCurrentLabels <> nil then
    begin
      for LIndex := 0 to FCurrentLabels.length - 1 do
      begin
        LRow := TJSObject(FCurrentLabels[LIndex]);
        if TextField(LRow, 'label_id') = LCandidate then
        begin
          LUsed := True;
          Break;
        end;
      end;
    end;
    if (not LUsed) and (FPendingChanges <> nil) then
    begin
      for LIndex := 0 to FPendingChanges.length - 1 do
      begin
        LChange := TJSObject(FPendingChanges[LIndex]);
        if TextField(LChange, 'label_id') = LCandidate then
        begin
          LUsed := True;
          Break;
        end;
      end;
    end;
    if not LUsed then
    begin
      Exit(LCandidate);
    end;
  end;
  raise Exception.Create('Could not create a unique staged label ID.');
end;

function TWorkbench.SameLabelIdentity(const ALeft,
  ARight: TJSObject): Boolean;
begin
  Result := (TextField(ALeft, 'type') = TextField(ARight, 'type')) and
    (TextField(ALeft, 'value') = TextField(ARight, 'value')) and
    (TextField(ALeft, 'status') = TextField(ARight, 'status')) and
    (TextField(ALeft, 'part') = TextField(ARight, 'part')) and
    (TextField(ALeft, 'proposal_id') = TextField(ARight, 'proposal_id'));
  if Result and (TextField(ALeft, 'type') = 'note') then
  begin
    Result := NumberField(ALeft, 'pitch_midi') =
      NumberField(ARight, 'pitch_midi');
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
  if (FPendingChanges <> nil) and
    (FPendingSourceHash = FSourceHash) then
  begin
    LContext.fillStyleAsColor := '#d3a8ff';
    for LIndex := 0 to FPendingChanges.length - 1 do
    begin
      LRow := TJSObject(FPendingChanges[LIndex]);
      if TextField(LRow, 'status') = 'withdrawn' then
      begin
        Continue;
      end;
      LStart := (NumberField(LRow, 'start_frame') - FWindowStart) /
        FWindowSpan * FCanvas.width;
      LEnd := (NumberField(LRow, 'end_frame') - FWindowStart) /
        FWindowSpan * FCanvas.width;
      LContext.fillRect(LStart, 232, LEnd - LStart + 2, 12);
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
  if FSaveInProgress or ((FPendingChanges <> nil) and
    (FPendingChanges.length > 0)) then
  begin
    Status('Finish or cancel the staged operation before selecting another label.',
      True);
    Exit;
  end;
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
  RenderMergeTargets;
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
  if FSaveInProgress or ((FPendingChanges <> nil) and
    (FPendingChanges.length > 0)) then
  begin
    Status('Finish or cancel the staged review operation before changing source.',
      True);
    Exit;
  end;
  if (FTracks = nil) or (AIndex < 0) or
    (AIndex >= FTracks.length) then
  begin
    Exit;
  end;
  LTrack := TJSObject(FTracks[AIndex]);
  FSourceHash := TextField(LTrack, 'source_sha256');
  FSourceGroup := TextField(LTrack, 'source_group');
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
  FUndoStack := TJSArray.new;
  FRedoStack := TJSArray.new;
  FHistoryLoading := True;
  FHistoryLoadFailed := False;
  FHistoryStale := False;
  UpdateHistoryUi;
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
    LoadLocalHistory;
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
    if FSaveInProgress then
    begin
      FSaveInProgress := False;
      UpdatePendingUi;
    end;
  except
    on LError: Exception do
    begin
      if FSaveInProgress then
      begin
        FSaveInProgress := False;
        if (FPendingChanges <> nil) and
          (FPendingChanges.length > 0) and (FPendingCommitted > 0) then
        begin
          FPendingConflict := True;
        end;
        UpdatePendingUi;
      end;
      if FHistoryLoading then
      begin
        FHistoryLoading := False;
        FHistoryLoadFailed := True;
        UpdateHistoryUi;
      end;
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
  if FSaveInProgress then
  begin
    Exit;
  end;
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
  LQueued: Boolean;
  LRemaining: TJSArray;
  LIndex: Integer;
  LData: TJSObject;
  LEntry: TJSObject;
  LBefore: TJSObject;
  LLabelId: String;
  LRevision: Integer;
begin
  if FSourceHash = '' then
  begin
    Exit;
  end;
  LQueued := (FPendingChanges <> nil) and
    (FPendingChanges.length > 0);
  if LQueued then
  begin
    if FPendingConflict or (FPendingSourceHash <> FSourceHash) or
      (FPendingSourceGroup <> FSourceGroup) or
      (FPendingPartition <> FPartition) then
    begin
      FPendingConflict := True;
      UpdatePendingUi;
      Status('The staged operation no longer matches this source. Cancel remaining events.',
        True);
      Exit;
    end;
    LChange := TJSObject(FPendingChanges[0]);
    LStart := Trunc(NumberField(LChange, 'start_frame'));
    LEnd := Trunc(NumberField(LChange, 'end_frame'));
  end
  else
  begin
    LStart := StrToInt64Def(Input('label-start').value, -1);
    LEnd := StrToInt64Def(Input('label-end').value, -1);
    if (Trim(Input('label-id').value) = '') then
    begin
      Status('Enter a label ID before saving.', True);
      Exit;
    end;
    LChange := EditorChange(LStart, LEnd, Input('label-id').value);
  end;
  if (LStart < 0) or (LEnd <= LStart) or (LEnd > FFrameCount) then
  begin
    Status('Enter a valid nonzero half-open source-frame interval.', True);
    Exit;
  end;
  FSaveInProgress := True;
  UpdatePendingUi;
  try
    LTransaction := TJSObject.new;
    LTransaction['version'] := 1;
    LTransaction['source_sha256'] := FSourceHash;
    LTransaction['expected_revision'] := FReviewRevision;
    LTransaction['reviewer'] := Input('reviewer').value;
    LTransaction['change'] := LChange;
    LEntry := FPendingHistoryEntry;
    if FPendingHistoryMode = '' then
    begin
      LLabelId := TextField(LChange, 'label_id');
      LBefore := nil;
      if FCurrentLabels <> nil then
      begin
        for LIndex := 0 to FCurrentLabels.length - 1 do
          if TextField(TJSObject(FCurrentLabels[LIndex]), 'label_id') = LLabelId then
          begin
            LBefore := RowChange(TJSObject(FCurrentLabels[LIndex]));
            Break;
          end;
      end;
      LEntry := TJSObject.new;
      LEntry['before'] := LBefore;
      LEntry['after'] := CloneObject(LChange);
      LEntry['source_sha256'] := FSourceHash;
    end;
    LResponse := await(TJSResponse, FetchApi('/api/review', 'POST',
      TJSJSON.stringify(LTransaction)));
    if LResponse.status = 409 then
    begin
      FDragMode := dmNone;
      if LQueued then
      begin
        FPendingConflict := True;
        FSaveInProgress := False;
        UpdatePendingUi;
        Status('Another review changed this source. The remaining staged events were not saved; cancel them after reviewing the reloaded labels.',
          True);
      end
      else
      begin
        FSaveInProgress := False;
        UpdatePendingUi;
        Status('Another review changed this source. Reloading current labels.');
      end;
      RefreshWindow;
      Exit;
    end;
    if LResponse.status <> 200 then
    begin
      raise Exception.Create('Review HTTP ' + IntToStr(LResponse.status));
    end;
    LData := await(TJSObject, LResponse.json());
    LRevision := Trunc(NumberField(LData, 'revision'));
    if LRevision <= FReviewRevision then
      raise Exception.Create('Review response did not advance its revision');
    if FPendingHistoryMode = 'undo' then
    begin
      if (FUndoStack <> nil) and (FUndoStack.length > 0) then
        FUndoStack.length := FUndoStack.length - 1;
      if FRedoStack = nil then
        FRedoStack := TJSArray.new;
      FRedoStack[FRedoStack.length] := FPendingHistoryEntry;
    end
    else if FPendingHistoryMode = 'redo' then
    begin
      if (FRedoStack <> nil) and (FRedoStack.length > 0) then
        FRedoStack.length := FRedoStack.length - 1;
      if FUndoStack = nil then
        FUndoStack := TJSArray.new;
      FUndoStack[FUndoStack.length] := FPendingHistoryEntry;
    end
    else
    begin
      if FUndoStack = nil then
        FUndoStack := TJSArray.new;
      FUndoStack[FUndoStack.length] := LEntry;
      if FUndoStack.length > MaximumLocalUndoEntries then
      begin
        for LIndex := 1 to FUndoStack.length - 1 do
          FUndoStack[LIndex - 1] := FUndoStack[LIndex];
        FUndoStack.length := MaximumLocalUndoEntries;
      end;
      FRedoStack := TJSArray.new;
    end;
    FReviewRevision := LRevision;
    SaveLocalHistory(LRevision);
    FDragMode := dmNone;
    if LQueued then
    begin
      LRemaining := TJSArray.new;
      for LIndex := 1 to FPendingChanges.length - 1 do
      begin
        LRemaining[LRemaining.length] := FPendingChanges[LIndex];
      end;
      FPendingChanges := LRemaining;
      Inc(FPendingCommitted);
      if FPendingChanges.length = 0 then
      begin
        ClearPending;
        Status('One staged review event saved. Operation complete; reloaded exact source labels.');
      end
      else
      begin
        UpdatePendingUi;
        Status('One staged review event saved. The next event remains unsaved until you click again.');
      end;
    end
    else
    begin
      Status('Review event saved. Reloading exact source labels.');
    end;
    RefreshWindow;
  except
    on LError: Exception do
    begin
      FSaveInProgress := False;
      UpdatePendingUi;
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
  if FSaveInProgress or ((FPendingChanges <> nil) and
    (FPendingChanges.length > 0)) then
  begin
    Status('Finish or cancel the staged review operation before editing another span.',
      True);
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
  if FSaveInProgress or ((FPendingChanges <> nil) and
    (FPendingChanges.length > 0)) then
  begin
    Status('Finish or cancel the staged operation before selecting a proposal.',
      True);
    Exit(False);
  end;
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
  if FSaveInProgress or ((FPendingChanges <> nil) and
    (FPendingChanges.length > 0)) then
  begin
    Status('Finish or cancel the staged operation before changing the source window.',
      True);
    Exit(False);
  end;
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
  if FSaveInProgress or ((FPendingChanges <> nil) and
    (FPendingChanges.length > 0)) then
  begin
    Status('Finish or cancel the staged operation before changing the source window.',
      True);
    Exit(False);
  end;
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
  if FSaveInProgress or ((FPendingChanges <> nil) and
    (FPendingChanges.length > 0)) then
  begin
    Status('Finish or cancel the staged operation before changing the source window.',
      True);
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
  if FSaveInProgress or ((FPendingChanges <> nil) and
    (FPendingChanges.length > 0)) then
  begin
    Status('Finish or cancel the staged operation before changing the source window.',
      True);
    Exit(False);
  end;
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
  if FSaveInProgress or ((FPendingChanges <> nil) and
    (FPendingChanges.length > 0)) then
  begin
    Status('Finish or cancel the staged operation before changing the source window.',
      True);
    Exit(False);
  end;
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

function TWorkbench.HandleUndo(AEvent: TJSMouseEvent): Boolean;
begin
  StageHistoryAction(False);
  Result := False;
end;

function TWorkbench.HandleRedo(AEvent: TJSMouseEvent): Boolean;
begin
  StageHistoryAction(True);
  Result := False;
end;

function TWorkbench.HandleClearHistory(AEvent: TJSMouseEvent): Boolean;
begin
  Result := False;
  FUndoStack := TJSArray.new;
  FRedoStack := TJSArray.new;
  FHistoryStale := False;
  SaveLocalHistory(FReviewRevision);
  Status('Local undo history cleared. The append-only server review history was not changed.');
end;

function TWorkbench.HandleKeyboard(AEvent: TJSKeyboardEvent): Boolean;
var
  LTarget: TJSObject;
  LTag: String;
  LKey: String;
begin
  Result := False;
  LTarget := TJSObject(AEvent.target);
  LTag := UpperCase(TextField(LTarget, 'tagName'));
  if (LTag = 'INPUT') or (LTag = 'TEXTAREA') or (LTag = 'SELECT') or
    (LTarget['isContentEditable'] = True) then
    Exit;
  LKey := LowerCase(AEvent.key);
  if (AEvent.ctrlKey or AEvent.metaKey) and (LKey = 'z') then
  begin
    AEvent.preventDefault;
    StageHistoryAction(AEvent.shiftKey);
    Exit;
  end;
  if (AEvent.ctrlKey or AEvent.metaKey) and (LKey = 'y') then
  begin
    AEvent.preventDefault;
    StageHistoryAction(True);
    Exit;
  end;
  if FSaveInProgress or ((FPendingChanges <> nil) and
    (FPendingChanges.length > 0)) then
    Exit;
  if LKey = 'arrowleft' then
  begin
    AEvent.preventDefault;
    if FSourceHash <> '' then
    begin
      if FWindowStart > FWindowSpan then
        Dec(FWindowStart, FWindowSpan)
      else
        FWindowStart := 0;
      RefreshWindow;
    end;
  end
  else if LKey = 'arrowright' then
  begin
    AEvent.preventDefault;
    if FSourceHash <> '' then
    begin
      FWindowStart := Smaller(FFrameCount - 1,
        FWindowStart + FWindowSpan);
      RefreshWindow;
    end;
  end
  else if (LKey = 'arrowup') or (LKey = 'arrowdown') then
  begin
    if (FCurrentLabels <> nil) and (FCurrentLabels.length > 0) then
    begin
      AEvent.preventDefault;
      if LKey = 'arrowup' then
        SelectLabel((FSelectedLabel + FCurrentLabels.length - 1) mod
          FCurrentLabels.length)
      else
        SelectLabel((FSelectedLabel + 1) mod FCurrentLabels.length);
    end;
  end;
end;

function TWorkbench.HandleSplit(AEvent: TJSMouseEvent): Boolean;
var
  LStart: Int64;
  LEnd: Int64;
  LSplit: Int64;
  LRow: TJSObject;
  LChange: TJSObject;
  LLeftId: String;
  LRightId: String;
begin
  Result := False;
  LStart := StrToInt64Def(Input('label-start').value, -1);
  LEnd := StrToInt64Def(Input('label-end').value, -1);
  LSplit := StrToInt64Def(Input('split-frame').value, -1);
  if (FSourceHash = '') or (FFrameCount <= 0) then
  begin
    Status('Select a valid source before splitting a label.', True);
    Exit;
  end;
  if FSaveInProgress or ((FPendingChanges <> nil) and
    (FPendingChanges.length > 0)) then
  begin
    Status('Complete or cancel the current staged operation first.', True);
    Exit;
  end;
  if (LStart < 0) or (LEnd <= LStart) or (LEnd > FFrameCount) then
  begin
    Status('The label must have a nonzero interval within this source.', True);
    Exit;
  end;
  if (LSplit <= LStart) or (LSplit >= LEnd) then
  begin
    Status('Choose a split frame strictly inside the selected half-open interval.',
      True);
    Exit;
  end;
  if Input('label-status').value = 'withdrawn' then
  begin
    Status('A withdrawn label cannot be split.', True);
    Exit;
  end;
  if FSelectedLabel >= 0 then
  begin
    if (FCurrentLabels = nil) or
      (FSelectedLabel >= FCurrentLabels.length) then
    begin
      Status('The selected saved label is no longer available.', True);
      Exit;
    end;
    LRow := TJSObject(FCurrentLabels[FSelectedLabel]);
    if not RowMatchesSource(LRow) or
      (TextField(LRow, 'status') = 'withdrawn') or
      (TextField(LRow, 'label_id') <> Input('label-id').value) or
      (Trunc(NumberField(LRow, 'start_frame')) <> LStart) or
      (Trunc(NumberField(LRow, 'end_frame')) <> LEnd) or
      not SameLabelIdentity(LRow, EditorChange(LStart, LEnd,
        Input('label-id').value)) then
    begin
      Status('The saved selection or its label identity changed. Reload/select it again before splitting.',
        True);
      Exit;
    end;
    AppendPending(RowChange(LRow, 'withdrawn'));
  end;
  LLeftId := NextOperationLabelId('split-left');
  LChange := EditorChange(LStart, LSplit, LLeftId);
  AppendPending(LChange);
  LRightId := NextOperationLabelId('split-right');
  LChange := EditorChange(LSplit, LEnd, LRightId);
  AppendPending(LChange);
  FPendingOperation := 'Split';
  FPendingConflict := False;
  FDragMode := dmNone;
  UpdatePendingUi;
  DrawWaveform;
  Status('Split staged at exact source frame ' + IntToStr(LSplit) +
    '. No review event has been saved.');
end;

function TWorkbench.HandleMerge(AEvent: TJSMouseEvent): Boolean;
var
  LStart: Int64;
  LEnd: Int64;
  LTargetIndex: Integer;
  LTarget: TJSObject;
  LSelected: TJSObject;
  LChange: TJSObject;
  LLabelId: String;
  LNewStart: Int64;
  LNewEnd: Int64;
begin
  Result := False;
  if (FSourceHash = '') or (FFrameCount <= 0) then
  begin
    Status('Select a valid source before merging labels.', True);
    Exit;
  end;
  if FSaveInProgress or ((FPendingChanges <> nil) and
    (FPendingChanges.length > 0)) then
  begin
    Status('Complete or cancel the current staged operation first.', True);
    Exit;
  end;
  if (FCurrentLabels = nil) then
  begin
    Status('Load saved labels before merging.', True);
    Exit;
  end;
  LTargetIndex := StrToIntDef(
    TJSHTMLSelectElement(Element('merge-label-target')).value, -1);
  if (LTargetIndex < 0) or (LTargetIndex >= FCurrentLabels.length) or
    (LTargetIndex = FSelectedLabel) then
  begin
    Status('Choose another current-source label as the merge target.', True);
    Exit;
  end;
  LTarget := TJSObject(FCurrentLabels[LTargetIndex]);
  if not RowMatchesSource(LTarget) or
    (TextField(LTarget, 'status') = 'withdrawn') then
  begin
    Status('The merge target is not an active label on this source.', True);
    Exit;
  end;
  LStart := StrToInt64Def(Input('label-start').value, -1);
  LEnd := StrToInt64Def(Input('label-end').value, -1);
  if (LStart < 0) or (LEnd <= LStart) or (LEnd > FFrameCount) or
    (Trunc(NumberField(LTarget, 'end_frame')) <=
      Trunc(NumberField(LTarget, 'start_frame'))) then
  begin
    Status('Both labels must have nonzero intervals within their source.', True);
    Exit;
  end;
  if FSelectedLabel >= 0 then
  begin
    if FSelectedLabel >= FCurrentLabels.length then
    begin
      Status('The selected saved label is no longer available.', True);
      Exit;
    end;
    LSelected := TJSObject(FCurrentLabels[FSelectedLabel]);
    if not RowMatchesSource(LSelected) or
      (TextField(LSelected, 'status') = 'withdrawn') or
      (TextField(LSelected, 'label_id') <> Input('label-id').value) or
      (Trunc(NumberField(LSelected, 'start_frame')) <> LStart) or
      (Trunc(NumberField(LSelected, 'end_frame')) <> LEnd) or
      not SameLabelIdentity(LSelected, EditorChange(LStart, LEnd,
        Input('label-id').value)) then
    begin
      Status('The selected saved label was edited or changed identity. Select it again before merging.',
        True);
      Exit;
    end;
  end
  else
  begin
    LSelected := EditorChange(LStart, LEnd, Input('label-id').value);
    if Trim(Input('label-value').value) = '' then
    begin
      Status('Enter a label value before merging a draft with a saved label.',
        True);
      Exit;
    end;
  end;
  if not SameLabelIdentity(LSelected, LTarget) then
  begin
    Status('Labels with different type, value, status, part, proposal, or pitch cannot be merged.',
      True);
    Exit;
  end;
  if (LStart > Trunc(NumberField(LTarget, 'end_frame'))) or
    (Trunc(NumberField(LTarget, 'start_frame')) > LEnd) then
  begin
    Status('Merge requires adjacent or overlapping intervals; gaps are not filled.',
      True);
    Exit;
  end;
  LNewStart := LStart;
  if Trunc(NumberField(LTarget, 'start_frame')) < LNewStart then
  begin
    LNewStart := Trunc(NumberField(LTarget, 'start_frame'));
  end;
  LNewEnd := LEnd;
  if Trunc(NumberField(LTarget, 'end_frame')) > LNewEnd then
  begin
    LNewEnd := Trunc(NumberField(LTarget, 'end_frame'));
  end;
  if FSelectedLabel >= 0 then
  begin
    LLabelId := TextField(LSelected, 'label_id');
  end
  else
  begin
    LLabelId := NextOperationLabelId('merge');
  end;
  AppendPending(EditorChange(LNewStart, LNewEnd, LLabelId));
  AppendPending(RowChange(LTarget, 'withdrawn'));
  FPendingOperation := 'Merge';
  FPendingConflict := False;
  FDragMode := dmNone;
  UpdatePendingUi;
  DrawWaveform;
  Status('Merge staged for frames ' + IntToStr(LNewStart) + '–' +
    IntToStr(LNewEnd) + '. No review event has been saved.');
end;

function TWorkbench.HandleCancelPending(AEvent: TJSMouseEvent): Boolean;
var
  LRemaining: Integer;
  LSaved: Integer;
begin
  Result := False;
  if FSaveInProgress then
  begin
    Status('Wait for the current review save and label reload before cancelling staged events.',
      True);
    Exit;
  end;
  LRemaining := 0;
  if FPendingChanges <> nil then
  begin
    LRemaining := FPendingChanges.length;
  end;
  LSaved := FPendingCommitted;
  ClearPending;
  DrawWaveform;
  if LSaved > 0 then
  begin
    Status(IntToStr(LSaved) + ' event(s) remain saved. Cancelled ' +
      IntToStr(LRemaining) + ' unsaved event(s); saved history was not rolled back.');
  end
  else
  begin
    Status('Cancelled ' + IntToStr(LRemaining) +
      ' staged event(s). Nothing was saved.');
  end;
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
  TJSHTMLButtonElement(Element('undo-review-button')).onclick := @HandleUndo;
  TJSHTMLButtonElement(Element('redo-review-button')).onclick := @HandleRedo;
  TJSHTMLButtonElement(Element('clear-history-button')).onclick :=
    @HandleClearHistory;
  TJSHTMLButtonElement(Element('split-label-button')).onclick := @HandleSplit;
  TJSHTMLButtonElement(Element('merge-label-button')).onclick := @HandleMerge;
  TJSHTMLButtonElement(Element('cancel-staged-button')).onclick :=
    @HandleCancelPending;
  TJSHTMLButtonElement(Element('export-button')).onclick := @HandleExport;
  TJSHTMLButtonElement(Element('import-reviewed-button')).onclick :=
    @HandleUploadReviewed;
  FCanvas.onpointerdown := @HandleCanvasDown;
  FCanvas.onpointermove := @HandleCanvasMove;
  FCanvas.onpointerup := @HandleCanvasUp;
  FCanvas.onpointercancel := @HandleCanvasCancel;
  document.onkeydown := @HandleKeyboard;
  DrawWaveform;
  Start;
end;

var
  Workbench: TWorkbench;
begin
  Workbench := TWorkbench.Create;
  Workbench.Run;
end.
