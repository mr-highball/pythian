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
  LegacyAccessKeyStorage = 'pythian.catalog.access-key.v1';
  ReviewHistoryPrefix = 'pythian.catalog.review-history.v1.';
  MaximumLocalUndoEntries = 128;
  MaximumAlignedPeerLanes = 8;

type
  TLabelDragMode = (dmNone, dmCreate, dmMove, dmStart, dmEnd, dmDraft);

  TWorkbenchWindow = class external name 'Window' (TJSWindow)
    function fetch(const AUrl: String;
      const AOptions: TJSObject): TJSPromise; reintroduce;
  end;

  TWorkbenchStreamReader = class external name 'ReadableStreamDefaultReader' (TJSObject)
    function read: TJSPromise;
    function cancel: TJSPromise;
  end;

  TWorkbenchStream = class external name 'ReadableStream' (TJSObject)
    function getReader: TWorkbenchStreamReader;
  end;

  TWorkbenchAbortController = class external name 'AbortController' (TJSObject)
  private
    FSignal: TJSObject; external name 'signal';
  public
    constructor new;
    procedure abort;
    property signal: TJSObject read FSignal;
  end;

  TWorkbenchResponse = class external name 'Response' (TJSResponse)
  private
    FBodyStream: TWorkbenchStream; external name 'body';
  public
    function blobRequest: TJSPromise; external name 'blob';
    property BodyStream: TWorkbenchStream read FBodyStream;
  end;

  TWorkbenchAudioElement = class external name 'HTMLAudioElement' (TJSHTMLAudioElement)
    function playRequest: TJSPromise; external name 'play';
  end;

  TWorkbench = class
  private
    FToken: String;
    FStartEpoch: Integer;
    FConnectionLoading: Boolean;
    FCatalogLoads: Integer;
    FQueueLoads: Integer;
    FSourceQueueKnown: Boolean;
    FSourceWaiting: Integer;
    FSourceCompleted: Integer;
    FListeningQueueKnown: Boolean;
    FListeningQueueLoading: Boolean;
    FListeningWaiting: Integer;
    FListeningCompleted: Integer;
    FAudioLoading: Boolean;
    FAudioAbort: TWorkbenchAbortController;
    FLoadingStage: String;
    FLoadingSince: NativeInt;
    FLoadingTimer: NativeInt;
    FAudioReceived: Int64;
    FAudioTotal: Int64;
    FSourceHash: String;
    FSourceGroup: String;
    FClockId: String;
    FPartition: String;
    FAudioUrl: String;
    FAudioCueLoaded: Boolean;
    FTracks: TJSArray;
    FReviewQueue: TJSArray;
    FQueueInitialSelectionDone: Boolean;
    FQueueRefreshPending: Boolean;
    FQueueAdvancePending: Boolean;
    FQueuePostCommitPending: Boolean;
    FQueueAdvanceIndex: Integer;
    FReviewId: String;
    FReviewQuestion: String;
    FReviewType: String;
    FReviewGeometry: String;
    FReviewRequestHash: String;
    FReviewSpec: TJSObject;
    FReviewConflict: String;
    FReviewCurrentValue: String;
    FReviewCurrentStatus: String;
    FReviewStart: Int64;
    FReviewEnd: Int64;
    FRequestDraft: Boolean;
    FPresenceValue: String;
    FPresenceFeedback: String;
    FPresenceChecking: Boolean;
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
    function FetchApi(const APath, AMethod, ABody: String;
      const ASignal: TJSObject = nil): TJSPromise;
    procedure Status(const AText: String; const AError: Boolean = False);
    procedure UpdateLoading;
    procedure CancelAudioRequest;
    procedure AudioFeedback(const AText: String; const AError: Boolean = False);
    procedure PlayLoadedAudio; async;
    procedure ShowWorkspace;
    procedure ClearItems(const AId: String);
    procedure AddItem(const AContainerId, ATitle, ADetail,
      AClassName: String; const AIndex: Integer;
      const AClick: THTMLClickEventHandler = nil);
    procedure RenderInbox(const AData: TJSObject);
    procedure RenderCatalog(const AData: TJSObject);
    procedure RenderAssignments(const AData: TJSObject);
    procedure UpdateReviewOverview;
    procedure SelectAssignment(const AIndex: Integer;
      const AScroll: Boolean);
    procedure ReviewPrompt(const AFallback: String);
    procedure ClearRequest;
    procedure ReleaseRequestDraft;
    function SelectedExactRequest: Boolean;
    function CurrentPresenceAnswer: String;
    function GuidedValueAllowed(const AType, AValue: String): Boolean;
    function StructuredGuided: Boolean;
    procedure ShowStructuredLinks;
    procedure FillStructuredSelect(const AId: String;
      const AValues: TJSArray);
    procedure UpdateValueHint;
    procedure UpdateRecordAnswerAction;
    procedure ChoosePresence(const AValue: String);
    procedure SavePresence; async;
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
    procedure UpdateTrackIdentity;
    procedure UpdateTrackProposalIdentity;
    function SharesSourceClock(const ATrack: TJSObject): Boolean;
    procedure RenderAlignedPeerScaffold;
    procedure LoadAlignedPeerWaveforms(const AEpoch: Integer); async;
    procedure DrawAlignedPeerWaveform(const ACanvas: TJSHTMLCanvasElement;
      const ABins: TJSArray; const AAvailableRatio: Double);
    procedure DrawAlignedPeerOverlays(const ACanvas: TJSHTMLCanvasElement;
      const ALabels: TJSArray; const AProposals: TJSObject;
      const AStart, AEnd, AVisibleEnd, ASourceFrames: Int64);
    procedure Start; async;
    procedure RefreshLists; async;
    procedure RefreshAssignments; async;
    procedure RefreshListeningOverview; async;
    function HandlePageShow(AEvent: TEventListenerEvent): Boolean;
    procedure ImportAll; async;
    procedure SelectTrack(const AIndex: Integer;
      const AStartFrame: Int64 = -1; const AEndFrame: Int64 = -1;
      const AReviewId: String = ''; const AQuestion: String = '';
      const AReviewType: String = '';
      const AConflict: String = '';
      const AGeometry: String = 'exact';
      const ARequestHash: String = '';
      const ASpec: TJSObject = nil); async;
    procedure RefreshWindow; async;
    procedure LoadAudio(const ACue: Boolean); async;
    procedure SuggestBeats; async;
    procedure SaveReview(const AGuidedChange: TJSObject = nil); async;
    procedure RecordAnswer; async;
    procedure DownloadExport; async;
    procedure UploadReviewed; async;
    function HandleImport(AEvent: TJSMouseEvent): Boolean;
    function HandleConnectRetry(AEvent: TJSMouseEvent): Boolean;
    function HandleTrack(AEvent: TJSMouseEvent): Boolean;
    function HandleAssignment(AEvent: TJSMouseEvent): Boolean;
    function HandleAlignedPeer(AEvent: TJSMouseEvent): Boolean;
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
    function HandleAudioMetadata(AEvent: TEventListenerEvent): Boolean;
    function HandleAudioEnded(AEvent: TEventListenerEvent): Boolean;
    function HandleAudioError(AEvent: TJSErrorEvent): Boolean;
    function HandleSuggest(AEvent: TJSMouseEvent): Boolean;
    function HandleSave(AEvent: TJSMouseEvent): Boolean;
    function HandleRecordAnswer(AEvent: TJSMouseEvent): Boolean;
    function HandlePresenceChoice(AEvent: TJSMouseEvent): Boolean;
    function HandlePresenceSave(AEvent: TJSMouseEvent): Boolean;
    function HandleLabelTypeChange(AEvent: TEventListenerEvent): Boolean;
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
  ABody: String; const ASignal: TJSObject): TJSPromise;
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
  if ASignal <> nil then LOptions['signal'] := ASignal;
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
  if AText = '' then
    LStatus.setAttribute('hidden', '')
  else
    LStatus.removeAttribute('hidden');
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
  Element('workspace').removeAttribute('hidden');
end;

procedure TWorkbench.CancelAudioRequest;
begin
  if FAudioAbort <> nil then
  begin
    FAudioAbort.abort;
    FAudioAbort := nil;
  end;
end;

function BoundedRequestDetail(const AText, AToken: String): String;
var
  LIndex: Integer;
begin
  Result := AText;
  if AToken <> '' then
    Result := StringReplace(Result, AToken, '[redacted]', [rfReplaceAll]);
  Result := Trim(Copy(Result, 1, 160));
  for LIndex := 1 to Length(Result) do
    if Ord(Result[LIndex]) < 32 then
      Result[LIndex] := ' ';
end;

function ReviewGeometry(const ARow: TJSObject): String;
begin
  Result := TextField(ARow, 'answer_geometry');
  if Result = '' then
    Result := 'exact';
end;

function ReviewSpec(const ARow: TJSObject): TJSObject;
begin
  Result := nil;
  if (ARow <> nil) and isObject(ARow['answer_spec']) then
    Result := TJSObject(ARow['answer_spec']);
end;

function StructuredRow(const ARow: TJSObject): Boolean;
begin
  Result := (ARow <> nil) and
    ((TextField(ARow, 'request_sha256') <> '') or
      isObject(ARow['request']));
end;

function RequestGeometryAllows(const AGeometry: String;
  const ARequestStart, ARequestEnd, ALabelStart,
  ALabelEnd: Int64): Boolean;
begin
  if AGeometry = 'exact' then
    Result := (ALabelStart = ARequestStart) and
      (ALabelEnd = ARequestEnd)
  else if AGeometry = 'point' then
    Result := (ALabelStart >= ARequestStart) and
      (ALabelEnd = ALabelStart + 1) and
      (ALabelEnd <= ARequestEnd)
  else if AGeometry = 'contained' then
    Result := (ALabelStart >= ARequestStart) and
      (ALabelEnd > ALabelStart) and
      (ALabelEnd <= ARequestEnd)
  else
    Result := False;
end;

procedure TWorkbench.UpdateLoading;
var
  LText: String;
  LStage: String;
  LPercent: Integer;
  LProgress: TJSElement;
begin
  LStage := '';
  if FAudioLoading then
    LStage := 'audio'
  else if FConnectionLoading then
    LStage := 'connection'
  else if FQueueLoads > 0 then
    LStage := 'queue'
  else if FCatalogLoads > 0 then
    LStage := 'catalog';
  if LStage <> FLoadingStage then
  begin
    FLoadingStage := LStage;
    FLoadingSince := TJSDate.now;
  end;
  LProgress := Element('loading-progress');
  if LStage = '' then
  begin
    if FLoadingTimer <> 0 then window.clearTimeout(FLoadingTimer);
    FLoadingTimer := 0;
    LProgress.setAttribute('hidden', '')
  end
  else
  begin
    if LStage = 'audio' then
    begin
      if FAudioTotal > 0 then
      begin
        LPercent := Integer((FAudioReceived * 100) div FAudioTotal);
        if LPercent > 100 then LPercent := 100;
        LText := 'Receiving WAV: ' + IntToStr(LPercent) + '%';
        Element('loading-progress-fill').setAttribute('style',
          'width: ' + IntToStr(LPercent) + '%');
        Element('loading-progress-fill').setAttribute('class', 'determinate');
        LProgress.setAttribute('aria-valuenow', IntToStr(LPercent));
      end
      else
        LText := 'Waiting for WAV response';
    end
    else if LStage = 'connection' then
      LText := 'Connecting to local service'
    else if LStage = 'queue' then
      LText := 'Loading prepared requests'
    else
      LText := 'Loading audio catalog';
    if (LStage <> 'audio') or (FAudioTotal <= 0) then
    begin
      LProgress.removeAttribute('aria-valuenow');
      Element('loading-progress-fill').removeAttribute('style');
      Element('loading-progress-fill').removeAttribute('class');
    end;
    LText := LText + ' · ' +
      IntToStr((TJSDate.now - FLoadingSince) div 1000) + ' s';
    Element('loading-progress-text').textContent := LText;
    LProgress.setAttribute('aria-label', LText);
    LProgress.setAttribute('aria-valuetext', LText);
    LProgress.removeAttribute('hidden');
    if FLoadingTimer = 0 then
      FLoadingTimer := window.setTimeout(
        procedure()
        begin
          FLoadingTimer := 0;
          UpdateLoading;
        end, 1000);
  end;
end;

procedure TWorkbench.AudioFeedback(const AText: String; const AError: Boolean);
var
  LFeedback: TJSElement;
begin
  LFeedback := Element('audio-feedback');
  LFeedback.textContent := AText;
  if AError then
    LFeedback.setAttribute('class', 'audio-feedback error')
  else
    LFeedback.setAttribute('class', 'audio-feedback');
end;

procedure TWorkbench.PlayLoadedAudio; async;
begin
  if FAudioUrl = '' then
    Exit;
  try
    await(TJSObject, TWorkbenchAudioElement(FAudio).playRequest());
    if FAudioCueLoaded then
      AudioFeedback('Playing the Pythian cue over the original WAV.')
    else
      AudioFeedback('Playing the original WAV.');
  except
    on LError: Exception do
    begin
      if FAudioUrl = '' then
        Exit;
      if FAudio.Error <> nil then
        AudioFeedback('This browser could not play the WAV (media error ' +
          IntToStr(FAudio.Error.code) + ').', True)
      else
        AudioFeedback('Audio is ready. Tap Play in the player to start it on this browser. ' +
          LError.Message);
    end
    else
    begin
      if FAudioUrl <> '' then
        AudioFeedback('The browser did not start playback. Tap Play in the player; ' +
          'if it remains at 0:00, report this message.', True);
    end;
  end;
end;

function TWorkbench.HandleAudioMetadata(AEvent: TEventListenerEvent): Boolean;
var
  LMode: String;
  LSeconds: String;
begin
  if (FAudioUrl <> '') and (FAudio.readyState >= 1) and
    (FAudio.duration > 0) then
  begin
    LMode := 'Original WAV';
    if FAudioCueLoaded then LMode := 'Pythian cue';
    LSeconds := FormatFloat('0.00', FAudio.duration) + ' s';
    Element('audio-mode').textContent := LMode + ' · ' + LSeconds;
    AudioFeedback('Decoded ' + LSeconds +
      ' WAV region ready; starting playback. For a half-second clip, the player clock may round to 0:00 / 0:00.');
  end;
  Result := False;
end;

function TWorkbench.HandleAudioEnded(AEvent: TEventListenerEvent): Boolean;
begin
  if FAudioUrl <> '' then
    AudioFeedback('Playback finished. Press Play in the player to hear this region again.');
  Result := False;
end;

function TWorkbench.HandleAudioError(AEvent: TJSErrorEvent): Boolean;
var
  LCode: Integer;
begin
  if FAudioUrl <> '' then
  begin
    LCode := 0;
    if FAudio.Error <> nil then
      LCode := FAudio.Error.code;
    AudioFeedback('This browser could not play the WAV (media error ' +
      IntToStr(LCode) + '). Try Play original again.', True);
    Status('Audio player failed after loading the region.', True);
    TJSURL.revokeObjectURL(FAudioUrl);
    FAudioUrl := '';
    FAudio.removeAttribute('src');
    FAudioCueLoaded := False;
    Element('audio-mode').textContent := 'Audio unavailable';
    TJSHTMLButtonElement(Element('load-audio-button')).disabled := False;
  end;
  Result := False;
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
      IntToStr(Trunc(NumberField(LRow, 'frame_count') /
      NumberField(LRow, 'sample_rate') / 60)) + ' min · ' +
      TextField(LRow, 'partition'),
      '', LIndex, @HandleTrack);
  end;
end;

procedure TWorkbench.UpdateReviewOverview;
var
  LKnownWaiting: Integer;
  LTitle: String;
begin
  LKnownWaiting := 0;
  if FSourceQueueKnown then
  begin
    Inc(LKnownWaiting, FSourceWaiting);
    Element('source-overview-state').textContent :=
      IntToStr(FSourceWaiting) + ' waiting · ' +
      IntToStr(FSourceCompleted) + ' completed';
  end
  else if (FQueueLoads > 0) or (FCatalogLoads > 0) then
    Element('source-overview-state').textContent := 'Checking…'
  else
    Element('source-overview-state').textContent := 'Status unavailable';
  if FListeningQueueKnown then
  begin
    Inc(LKnownWaiting, FListeningWaiting);
    Element('listening-overview-state').textContent :=
      IntToStr(FListeningWaiting) + ' waiting · ' +
      IntToStr(FListeningCompleted) + ' completed';
  end
  else if FListeningQueueLoading then
    Element('listening-overview-state').textContent := 'Checking…'
  else
    Element('listening-overview-state').textContent := 'Status unavailable';

  if FSourceQueueKnown and FListeningQueueKnown then
  begin
    if LKnownWaiting = 0 then
    begin
      if (FSourceCompleted = 0) and (FListeningCompleted = 0) then
      begin
        LTitle := 'No reviews assigned yet';
        Element('review-overview-detail').textContent :=
          'New listening reviews and source labels will appear here.';
      end
      else
      begin
        LTitle := 'All assigned reviews complete';
        Element('review-overview-detail').textContent :=
          'There are no listening reviews or source labels waiting.';
      end;
    end
    else
    begin
      if LKnownWaiting = 1 then
        LTitle := '1 review needs your attention'
      else
        LTitle := IntToStr(LKnownWaiting) +
          ' reviews need your attention';
      Element('review-overview-detail').textContent :=
        'Choose a queue below. Your saved decisions are removed from its waiting list.';
    end;
  end
  else
  begin
    if LKnownWaiting = 1 then
      LTitle := 'At least 1 review needs your attention'
    else if LKnownWaiting > 1 then
      LTitle := 'At least ' + IntToStr(LKnownWaiting) +
        ' reviews need your attention'
    else
      LTitle := 'Checking assigned reviews…';
    if (FQueueLoads > 0) or (FCatalogLoads > 0) or
      FListeningQueueLoading then
      Element('review-overview-detail').textContent :=
        'Checking listening reviews and source labels.'
    else
      Element('review-overview-detail').textContent :=
        'One queue could not be checked. Open its page or retry the connection.';
  end;
  Element('review-overview-title').textContent := LTitle;
  if FSourceQueueKnown and FListeningQueueKnown then
    Element('review-overview-announcement').textContent := LTitle +
      '. ' + IntToStr(FListeningWaiting) + ' listening reviews waiting; ' +
      IntToStr(FSourceWaiting) + ' source labels waiting.';
  if FListeningQueueKnown and (FListeningWaiting > 0) then
    Element('listening-route').setAttribute('class', 'review-route needs-review')
  else
    Element('listening-route').setAttribute('class', 'review-route');
  if FSourceQueueKnown and (FSourceWaiting > 0) then
    Element('source-route').setAttribute('class', 'review-route needs-review')
  else
    Element('source-route').setAttribute('class', 'review-route');
end;

procedure TWorkbench.RenderAssignments(const AData: TJSObject);
var
  LRow: TJSObject;
  LCompleted: TJSArray;
  LIndex: Integer;
  LTrackIndex: Integer;
  LRate: Integer;
  LCompletedCount: Integer;
  LSelectIndex: Integer;
  LTitle: String;
  LDetail: String;
  LSelectedFound: Boolean;
begin
  ClearItems('assignment-list');
  FReviewQueue := TJSArray(AData['items']);
  if FReviewQueue = nil then
    FReviewQueue := TJSArray.new;
  LCompleted := TJSArray(AData['completed']);
  LCompletedCount := 0;
  if LCompleted <> nil then
    LCompletedCount := LCompleted.length;
  FSourceQueueKnown := True;
  FSourceWaiting := FReviewQueue.length;
  FSourceCompleted := LCompletedCount;
  UpdateReviewOverview;
  Element('queue-progress').textContent :=
    IntToStr(FReviewQueue.length) + ' source labels waiting · ' +
    IntToStr(LCompletedCount) + ' completed';
  LSelectedFound := False;
  if FReviewId <> '' then
  begin
    for LIndex := 0 to FReviewQueue.length - 1 do
    begin
      LRow := TJSObject(FReviewQueue[LIndex]);
      if (TextField(LRow, 'id') = FReviewId) and
        (TextField(LRow, 'source_sha256') = FSourceHash) and
        (Trunc(NumberField(LRow, 'start_frame')) = FReviewStart) and
        (Trunc(NumberField(LRow, 'end_frame')) = FReviewEnd) then
      begin
        LSelectedFound := True;
        if (TextField(LRow, 'label_type') <> FReviewType) or
          (TextField(LRow, 'question') <> FReviewQuestion) or
          (ReviewGeometry(LRow) <> FReviewGeometry) or
          (TextField(LRow, 'request_sha256') <> FReviewRequestHash) then
        begin
          ClearRequest;
          Break;
        end;
        FReviewConflict := TextField(LRow, 'answer_conflict');
        FReviewSpec := ReviewSpec(LRow);
        FReviewCurrentValue := TextField(LRow, 'current_value');
        FReviewCurrentStatus := TextField(LRow, 'current_status');
        Break;
      end;
    end;
    if not LSelectedFound then
      ClearRequest;
  end;
  if FReviewQueue.length = 0 then
  begin
    FQueueAdvancePending := False;
    FQueueInitialSelectionDone := True;
    ClearRequest;
    if (LCompleted <> nil) and (LCompleted.length > 0) then
    begin
      Element('assignment-state').textContent :=
        'No source labels waiting. Listening reviews may still need attention above.';
      ReviewPrompt('All source-label requests are complete.');
    end
    else
    begin
      Element('assignment-state').textContent :=
        'No source labels are assigned. Use the review queue above for your next action.';
      ReviewPrompt('No source-label requests are waiting.');
    end;
    Exit;
  end;
  Element('catalog-browser').removeAttribute('open');
  Element('assignment-state').textContent :=
    'Listen to the selected region, choose an answer, then click Save answer.';
  for LIndex := 0 to FReviewQueue.length - 1 do
  begin
    LRow := TJSObject(FReviewQueue[LIndex]);
    LTitle := TextField(LRow, 'title');
    if LTitle = '' then
      LTitle := 'Request ' + IntToStr(LIndex + 1);
    LDetail := TextField(LRow, 'source_title');
    LRate := 0;
    if FTracks <> nil then
      for LTrackIndex := 0 to FTracks.length - 1 do
        if TextField(TJSObject(FTracks[LTrackIndex]), 'source_sha256') =
          TextField(LRow, 'source_sha256') then
        begin
          LRate := Trunc(NumberField(TJSObject(FTracks[LTrackIndex]),
            'sample_rate'));
          Break;
        end;
    if LRate > 0 then
      LDetail := FormatFloat('0.0', NumberField(LRow, 'start_frame') /
        LRate) + '–' + FormatFloat('0.0',
        NumberField(LRow, 'end_frame') / LRate) + ' s · ' + LDetail
    else
      LDetail := IntToStr(Trunc(NumberField(LRow, 'start_frame'))) +
        '–' + IntToStr(Trunc(NumberField(LRow, 'end_frame'))) +
        ' frames · ' + LDetail;
    AddItem('assignment-list', LTitle, LDetail,
      'review-request', LIndex, @HandleAssignment);
  end;
  LSelectIndex := -1;
  if FQueueAdvancePending then
  begin
    LSelectIndex := FQueueAdvanceIndex;
    if LSelectIndex >= FReviewQueue.length then
      LSelectIndex := 0;
    FQueueAdvancePending := False;
  end
  else if not FQueueInitialSelectionDone and not LSelectedFound then
    LSelectIndex := 0;
  if LSelectIndex >= 0 then
  begin
    FQueueInitialSelectionDone := True;
    SelectAssignment(LSelectIndex, True);
  end;
  UpdateRecordAnswerAction;
end;

procedure TWorkbench.ReviewPrompt(const AFallback: String);
begin
  if SelectedExactRequest then
    Element('review-next-step').textContent := FReviewQuestion
  else
    Element('review-next-step').textContent := AFallback;
  UpdateRecordAnswerAction;
end;

function TWorkbench.SelectedExactRequest: Boolean;
begin
  Result := (FReviewId <> '') and (FReviewQuestion <> '') and
    (FSourceHash <> '') and (FWindowStart = FReviewStart) and
    (FWindowStart + FWindowSpan = FReviewEnd);
end;

function TWorkbench.CurrentPresenceAnswer: String;
begin
  Result := '';
  if (FReviewCurrentStatus = 'approved') and
    GuidedValueAllowed(FReviewType, FReviewCurrentValue) then
    Result := FReviewCurrentValue;
end;

function TWorkbench.GuidedValueAllowed(const AType, AValue: String): Boolean;
var
  LValues: TJSArray;
  LIndex: Integer;
begin
  if FReviewSpec <> nil then
  begin
    Result := False;
    if not isArray(FReviewSpec['vocabulary']) then Exit;
    LValues := TJSArray(FReviewSpec['vocabulary']);
    for LIndex := 0 to LValues.length - 1 do
      if String(LValues[LIndex]) = AValue then Exit(True);
    Exit;
  end;
  Result := ((AType = 'presence') and
    ((AValue = 'audible') or (AValue = 'rest') or
     (AValue = 'unknown'))) or
    ((AType = 'activity') and
    ((AValue = 'attack') or (AValue = 'continuation') or
     (AValue = 'release_tail') or (AValue = 'rest') or
     (AValue = 'unknown') or (AValue = 'noise_only')));
end;

function TWorkbench.StructuredGuided: Boolean;
begin
  Result := (FReviewSpec <> nil) and (FReviewGeometry = 'exact') and
    (FReviewType <> 'note') and
    not isArray(FReviewSpec['part_vocabulary']);
end;

procedure TWorkbench.ShowStructuredLinks;
var
  LLinks: TJSArray;
  LLink: TJSObject;
  LIndex: Integer;
  LText: String;
begin
  if FReviewSpec = nil then
  begin
    Element('structured-request-links').setAttribute('hidden', '');
    Exit;
  end;
  LText := 'Facet: ' + TextField(FReviewSpec, 'facet') + '.';
  if isArray(FReviewSpec['links']) then
  begin
    LLinks := TJSArray(FReviewSpec['links']);
    for LIndex := 0 to LLinks.length - 1 do
    begin
      LLink := TJSObject(LLinks[LIndex]);
      LText := LText + ' ' + TextField(LLink, 'role') + ': ' +
        TextField(LLink, 'kind') + ' ' +
        TextField(LLink, 'target_id');
      if TextField(LLink, 'kind') = 'label' then
        LText := LText + ' (' + TextField(LLink, 'target_type') +
          ', revision ' + IntToStr(Trunc(NumberField(LLink,
            'target_revision'))) + ')';
      LText := LText + '.';
    end;
  end;
  if TextField(FReviewSpec, 'proposal_id') <> '' then
    LText := LText + ' Bound proposal: ' +
      TextField(FReviewSpec, 'proposal_id') + '.';
  Element('structured-request-links').textContent := LText;
  Element('structured-request-links').removeAttribute('hidden');
end;

procedure TWorkbench.FillStructuredSelect(const AId: String;
  const AValues: TJSArray);
var
  LSelect: TJSHTMLSelectElement;
  LOption: TJSHTMLOptionElement;
  LIndex: Integer;
  LValue: String;
begin
  LSelect := TJSHTMLSelectElement(Element(AId));
  LSelect.innerHTML := '';
  LOption := TJSHTMLOptionElement(TJSHTMLOptionElement.New(
    'Choose one', ''));
  LSelect.add(LOption);
  if AValues <> nil then
    for LIndex := 0 to AValues.length - 1 do
    begin
      LValue := String(AValues[LIndex]);
      LOption := TJSHTMLOptionElement(TJSHTMLOptionElement.New(
        LValue, LValue));
      LSelect.add(LOption);
    end;
  LSelect.value := '';
end;

procedure TWorkbench.UpdateValueHint;
var
  LType, LHint: String;
begin
  LType := Input('label-type').value;
  if LType = 'key' then
    LHint := 'Key: C:major or F#:minor; unknown or ambiguous if needed.'
  else if LType = 'tempo' then
    LHint := 'Tempo in BPM: 120 or 87.5; unknown or ambiguous if needed.'
  else if LType = 'meter' then
    LHint := 'Meter: 4/4 or 7/8; unknown or ambiguous if needed.'
  else if LType = 'harmony' then
    LHint := 'Harmony: C:major, A:minor, or a task-declared root:quality such as G:dominant7; unknown or ambiguous if needed.'
  else if LType = 'activity' then
    LHint := 'Use attack, continuation, release_tail, rest, unknown, or noise_only.'
  else if LType = 'presence' then
    LHint := 'Use audible, rest, or unknown.'
  else
    LHint := 'Enter the exact reviewed value for the selected type.';
  Element('label-value-hint').textContent := LHint;
end;

procedure TWorkbench.ReleaseRequestDraft;
begin
  if not FRequestDraft then
    Exit;
  FRequestDraft := False;
  Element('request-geometry-help').setAttribute('hidden', '');
  FCanvas.setAttribute('aria-label',
    'Original WAV waveform with review and proposal lanes; tap waveform to seek loaded audio');
  Input('label-id').removeAttribute('readonly');
  Input('label-value').removeAttribute('readonly');
  Input('label-value').removeAttribute('hidden');
  Element('structured-value').setAttribute('hidden', '');
  Input('label-part').removeAttribute('readonly');
  Input('label-part').removeAttribute('hidden');
  Element('structured-part').setAttribute('hidden', '');
  Input('label-pitch').removeAttribute('hidden');
  Element('structured-pitch').setAttribute('hidden', '');
  Input('label-proposal').removeAttribute('readonly');
  Input('label-start').removeAttribute('readonly');
  Input('label-end').removeAttribute('readonly');
  Element('label-type').removeAttribute('disabled');
end;

procedure TWorkbench.ClearRequest;
begin
  FPresenceValue := '';
  FPresenceFeedback := '';
  FPresenceChecking := False;
  if FRequestDraft then
  begin
    Input('label-id').value := '';
    Input('label-type').value := '';
    UpdateValueHint;
    Input('label-value').value := '';
    Input('label-start').value := '';
    Input('label-end').value := '';
    Input('label-proposal').value := '';
    Input('label-part').value := '';
    Input('label-pitch').value := '';
    Element('review-editor').removeAttribute('open');
  end;
  ReleaseRequestDraft;
  FReviewId := '';
  FReviewQuestion := '';
  FReviewType := '';
  FReviewGeometry := '';
  FReviewRequestHash := '';
  FReviewSpec := nil;
  FReviewConflict := '';
  FReviewCurrentValue := '';
  FReviewCurrentStatus := '';
  FReviewStart := 0;
  FReviewEnd := 0;
  UpdateRecordAnswerAction;
end;

procedure TWorkbench.UpdateRecordAnswerAction;
var
  LBlocked: Boolean;
  LGuided: Boolean;
  LSaved: String;
  LValues: TJSArray;
  LButton: TJSHTMLButtonElement;
  LIndex: Integer;
  LValue: String;
begin
  if not SelectedExactRequest then
  begin
    FPresenceChecking := False;
    FPresenceValue := '';
    FPresenceFeedback := '';
    Element('record-answer-area').setAttribute('hidden', '');
    Element('presence-answer-area').setAttribute('hidden', '');
    Element('record-answer-state').textContent := '';
    Element('presence-answer-state').textContent := '';
    Element('presence-saved-answer').setAttribute('hidden', '');
    Element('structured-request-links').setAttribute('hidden', '');
    Exit;
  end;
  ShowStructuredLinks;
  LGuided := StructuredGuided or
    ((FReviewSpec = nil) and
      ((FReviewType = 'presence') or (FReviewType = 'activity')));
  Element('structured-choices').setAttribute('hidden', '');
  Element('structured-status-area').setAttribute('hidden', '');
  if StructuredGuided then
  begin
    Element('guided-answer-heading').textContent :=
      'Choose one declared answer for this exact region';
    Element('guided-answer-help').textContent :=
      'The choices below are the request’s complete answer vocabulary. Nothing is saved until you click Save answer.';
    Element('presence-choices').setAttribute('hidden', '');
    Element('activity-choices').setAttribute('hidden', '');
    Element('structured-choices').removeAttribute('hidden');
    if TextField(FReviewSpec, 'proposal_id') <> '' then
      Element('structured-status-area').removeAttribute('hidden');
    ClearItems('structured-choices');
    LValues := TJSArray(FReviewSpec['vocabulary']);
    for LIndex := 0 to LValues.length - 1 do
    begin
      LValue := String(LValues[LIndex]);
      LButton := TJSHTMLButtonElement(document.createElement('button'));
      LButton.setAttribute('type', 'button');
      LButton.setAttribute('data-value', LValue);
      LButton.setAttribute('aria-pressed',
        LowerCase(BoolToStr(FPresenceValue = LValue, True)));
      LButton.textContent := LValue;
      LButton.disabled := (FReviewConflict <> '') or FHistoryLoading or
        FHistoryLoadFailed or FSaveInProgress or FPresenceChecking;
      LButton.onclick := @HandlePresenceChoice;
      Element('structured-choices').appendChild(LButton);
    end;
  end
  else if FReviewType = 'activity' then
  begin
    Element('guided-answer-heading').textContent := 'What kind of activity do you hear in this exact region?';
    Element('guided-answer-help').textContent :=
      'Choose the best description for the entire requested region. Use unknown if the sound remains unclear.';
    Element('presence-choices').setAttribute('hidden', '');
    Element('activity-choices').removeAttribute('hidden');
  end
  else
  begin
    Element('guided-answer-heading').textContent := 'What do you hear in this exact region?';
    Element('guided-answer-help').textContent :=
      'A half-second clip may show 0:00 / 0:00 in the player. Use Loop region if useful; choose “I can’t tell” if the sound remains unclear.';
    Element('activity-choices').setAttribute('hidden', '');
    Element('presence-choices').removeAttribute('hidden');
  end;
  LSaved := CurrentPresenceAnswer;
  if LSaved <> '' then
  begin
    Element('presence-saved-answer').textContent := 'Saved answer: ' +
      LSaved + '. Select a different answer only to correct it.';
    Element('presence-saved-answer').removeAttribute('hidden');
  end
  else
    Element('presence-saved-answer').setAttribute('hidden', '');
  if LGuided then
  begin
    Element('record-answer-area').setAttribute('hidden', '');
    Element('presence-answer-area').removeAttribute('hidden');
  end
  else
  begin
    Element('presence-answer-area').setAttribute('hidden', '');
    Element('record-answer-area').removeAttribute('hidden');
  end;
  LBlocked := FQueuePostCommitPending or
    (FReviewConflict <> '') or FHistoryLoading or
    FHistoryLoadFailed or FSaveInProgress or FPresenceChecking or
    ((FPendingChanges <> nil) and (FPendingChanges.length > 0));
  TJSHTMLButtonElement(Element('presence-audible')).disabled := LBlocked;
  TJSHTMLButtonElement(Element('presence-rest')).disabled := LBlocked;
  TJSHTMLButtonElement(Element('presence-unknown')).disabled := LBlocked;
  TJSHTMLButtonElement(Element('activity-attack')).disabled := LBlocked;
  TJSHTMLButtonElement(Element('activity-continuation')).disabled := LBlocked;
  TJSHTMLButtonElement(Element('activity-release_tail')).disabled := LBlocked;
  TJSHTMLButtonElement(Element('activity-rest')).disabled := LBlocked;
  TJSHTMLButtonElement(Element('activity-unknown')).disabled := LBlocked;
  TJSHTMLButtonElement(Element('activity-noise_only')).disabled := LBlocked;
  Element('presence-audible').setAttribute('aria-pressed',
    LowerCase(BoolToStr(FPresenceValue = 'audible', True)));
  Element('presence-rest').setAttribute('aria-pressed',
    LowerCase(BoolToStr(FPresenceValue = 'rest', True)));
  Element('presence-unknown').setAttribute('aria-pressed',
    LowerCase(BoolToStr(FPresenceValue = 'unknown', True)));
  Element('activity-attack').setAttribute('aria-pressed',
    LowerCase(BoolToStr(FPresenceValue = 'attack', True)));
  Element('activity-continuation').setAttribute('aria-pressed',
    LowerCase(BoolToStr(FPresenceValue = 'continuation', True)));
  Element('activity-release_tail').setAttribute('aria-pressed',
    LowerCase(BoolToStr(FPresenceValue = 'release_tail', True)));
  Element('activity-rest').setAttribute('aria-pressed',
    LowerCase(BoolToStr(FPresenceValue = 'rest', True)));
  Element('activity-unknown').setAttribute('aria-pressed',
    LowerCase(BoolToStr(FPresenceValue = 'unknown', True)));
  Element('activity-noise_only').setAttribute('aria-pressed',
    LowerCase(BoolToStr(FPresenceValue = 'noise_only', True)));
  TJSHTMLButtonElement(Element('presence-save')).disabled :=
    LBlocked or (FPresenceValue = '') or (FPresenceValue = LSaved);
  TJSHTMLSelectElement(Element('structured-status')).disabled := LBlocked;
  if LSaved <> '' then
    Element('presence-save').textContent := 'Save correction'
  else
    Element('presence-save').textContent := 'Save answer';
  if FReviewConflict <> '' then
    Element('presence-answer-state').textContent := FReviewConflict
  else if FHistoryLoading then
    Element('presence-answer-state').textContent := 'Loading saved decisions…'
  else if FHistoryLoadFailed then
    Element('presence-answer-state').textContent := 'Saved decisions could not load.'
  else if FPresenceChecking then
    Element('presence-answer-state').textContent := 'Checking the exact request…'
  else if FSaveInProgress then
    Element('presence-answer-state').textContent := 'Saving answer…'
  else if FPresenceFeedback <> '' then
    Element('presence-answer-state').textContent := FPresenceFeedback
  else if (LSaved <> '') and (FPresenceValue = LSaved) then
    Element('presence-answer-state').textContent := 'This answer is already saved. Choose a different value to correct it.'
  else if (LSaved <> '') and (FPresenceValue = '') then
    Element('presence-answer-state').textContent := 'The saved answer is shown above. Nothing new will be recorded.'
  else if FPresenceValue = '' then
    Element('presence-answer-state').textContent := 'Choose one answer. Nothing is saved yet.'
  else
    Element('presence-answer-state').textContent := 'Click Save answer to record this decision.';
  TJSHTMLButtonElement(Element('record-answer-button')).disabled := LBlocked;
  if FReviewConflict <> '' then
    Element('record-answer-state').textContent := FReviewConflict
  else if FHistoryLoading then
    Element('record-answer-state').textContent := 'Loading saved decisions…'
  else if FHistoryLoadFailed then
    Element('record-answer-state').textContent := 'Saved decisions could not load.'
  else if LBlocked then
    Element('record-answer-state').textContent := 'Finish the current review first.'
  else if FReviewGeometry = 'point' then
    Element('record-answer-state').textContent :=
      'Place a one-frame point inside the listening region. Status starts Uncertain; choose Approved to accept it.'
  else if FReviewGeometry = 'contained' then
    Element('record-answer-state').textContent :=
      'Place the answer span inside the listening region. Status starts Uncertain; choose Approved to accept it.'
  else
    Element('record-answer-state').textContent :=
      'Opens a draft for this exact region. Status starts Uncertain; choose Approved to accept the answer, then save.';
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
    if StructuredRow(LRow) or not RowMatchesSource(LRow) or
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
    (FSourceHash = '') or FPendingConflict or FSaveInProgress or
    FHistoryLoading or FHistoryLoadFailed;
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
  TJSHTMLButtonElement(Element('save-label-button')).disabled :=
    FHistoryLoading or FHistoryLoadFailed;
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
  UpdatePendingUi;
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
  LIndex: Integer;
begin
  if (AEntry = nil) or FHistoryStale or FSaveInProgress or
    ((FPendingChanges <> nil) and (FPendingChanges.length > 0)) then
    Exit;
  LAfter := TJSObject(AEntry['after']);
  if (TextField(AEntry, 'request_sha256') <> '') or
    StructuredRow(LAfter) or
    (isObject(AEntry['before']) and
      StructuredRow(TJSObject(AEntry['before']))) then
  begin
    Status('A structured answer is bound to its request. Undo or redo cannot turn it into a freeform review; use a new prepared request.', True);
    Exit;
  end;
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
  if FCurrentLabels <> nil then
    for LIndex := 0 to FCurrentLabels.length - 1 do
      if (TextField(TJSObject(FCurrentLabels[LIndex]), 'label_id') =
        TextField(LTarget, 'label_id')) and
        StructuredRow(TJSObject(FCurrentLabels[LIndex])) then
      begin
        Status('A structured answer cannot be restored as a freeform event. Use a new prepared request.', True);
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
var
  LValue: String;
begin
  Result := TJSObject.new;
  Result['label_id'] := ALabelId;
  Result['type'] := Input('label-type').value;
  if FRequestDraft and (FReviewSpec <> nil) then
    LValue := TJSHTMLSelectElement(Element('structured-value')).value
  else
    LValue := Input('label-value').value;
  Result['value'] := LValue;
  Result['status'] := Input('label-status').value;
  Result['start_frame'] := AStartFrame;
  Result['end_frame'] := AEndFrame;
  if FRequestDraft and (FReviewSpec <> nil) then
  begin
    if isArray(FReviewSpec['part_vocabulary']) then
      Result['part'] := TJSHTMLSelectElement(
        Element('structured-part')).value
    else
      Result['part'] := '';
    Result['proposal_id'] := TextField(FReviewSpec, 'proposal_id');
    if Copy(Input('label-type').value, 1, 4) = 'ext.' then
      Result['extension_version'] := 2;
  end
  else
  begin
    Result['part'] := Input('label-part').value;
    Result['proposal_id'] := Input('label-proposal').value;
  end;
  if Input('label-type').value = 'note' then
  begin
    if not ((FRequestDraft and (FReviewSpec <> nil)) and
      ((LValue = 'unknown') or (LValue = 'ambiguous'))) then
    begin
      if FRequestDraft and (FReviewSpec <> nil) and
        isArray(FReviewSpec['pitch_midi_values']) then
        Result['pitch_midi'] := StrToIntDef(
          TJSHTMLSelectElement(Element('structured-pitch')).value, -1)
      else
        Result['pitch_midi'] := StrToIntDef(Input('label-pitch').value, -1);
    end;
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
  if (TextField(ARow, 'type') = 'note') and
    (not StructuredRow(ARow) or
      ((TextField(ARow, 'value') <> 'unknown') and
       (TextField(ARow, 'value') <> 'ambiguous'))) then
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
  LAnalyzerVersion: String;
begin
  ClearItems('proposal-list');
  UpdateTrackProposalIdentity;
  if FSelectedProposal < 0 then
  begin
    Element('load-cue-button').textContent := 'Play selected Pythian cue';
  end;
  TJSHTMLButtonElement(Element('load-cue-button')).disabled :=
    (FProposals = nil) or (FSelectedProposal < 0);
  if (FPartition = 'evaluation') and (FReviewRevision = 0) then
  begin
    ReviewPrompt('Blind review: suggestions are hidden until an independent decision is saved.');
    Element('proposal-note').textContent :=
      'Blind evaluation: Pythian suggestions are hidden. Commit your own label first.';
    Exit;
  end;
  if FProposals = nil then
  begin
    ReviewPrompt('No review request is assigned to this region. You can listen without annotating it.');
    Element('proposal-note').textContent :=
      'No saved proposals for this window. Suggestions remain unreviewed.';
    Exit;
  end;
  ReviewPrompt('Pythian suggestions are available, but this region has no assigned review request.');
  LAnalyzerVersion := IntToStr(Trunc(NumberField(FProposals,
    'analyzer_version')));
  Element('proposal-note').textContent :=
    'Pythian beat-grid hypotheses · ' +
    TextField(FProposals, 'analyzer') + ' v' + LAnalyzerVersion +
    ' · unreviewed';
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

procedure TWorkbench.UpdateTrackIdentity;
var
  LShortHash: String;
begin
  if FSourceHash = '' then
  begin
    Element('source-hash-short').textContent := '—';
    Element('source-hash-full').textContent := '';
    Element('source-hash-details').setAttribute('hidden', '');
    Element('catalog-import-state').textContent := 'Catalog: —';
    Element('track-review-state').textContent := 'Review: —';
    Exit;
  end;
  LShortHash := Copy(FSourceHash, 1, 12);
  if Length(FSourceHash) > 12 then
    LShortHash := LShortHash + '…';
  Element('source-hash-short').textContent := LShortHash;
  Element('source-hash-short').setAttribute('title', FSourceHash);
  Element('source-hash-full').textContent := FSourceHash;
  Element('source-hash-details').removeAttribute('hidden');
  Element('catalog-import-state').textContent := 'Catalog: imported';
  Element('track-review-state').textContent := 'Review: loading state…';
end;

procedure TWorkbench.UpdateTrackProposalIdentity;
var
  LCandidates: TJSArray;
  LAnalyzerVersion: String;
begin
  Element('track-proposal-state').setAttribute('hidden', '');
  Element('track-proposal-state').textContent := '';
  if FProposals = nil then
    Exit;
  LCandidates := TJSArray(FProposals['candidates']);
  if (LCandidates = nil) or (LCandidates.length = 0) or
    ((FPartition = 'evaluation') and (FReviewRevision = 0)) then
    Exit;
  LAnalyzerVersion := IntToStr(Trunc(NumberField(FProposals,
    'analyzer_version')));
  Element('track-proposal-state').textContent :=
    'Proposal analyzer: ' + TextField(FProposals, 'analyzer') +
    ' v' + LAnalyzerVersion;
  Element('track-proposal-state').removeAttribute('hidden');
end;

function TWorkbench.SharesSourceClock(const ATrack: TJSObject): Boolean;
begin
  Result := (FClockId <> '') and (FSourceGroup <> '') and
    (TextField(ATrack, 'clock_id') = FClockId) and
    (TextField(ATrack, 'source_group') = FSourceGroup) and
    (Trunc(NumberField(ATrack, 'sample_rate')) = FSampleRate) and
    (TextField(ATrack, 'source_sha256') <> FSourceHash);
end;

procedure TWorkbench.RenderAlignedPeerScaffold;
var
  LTrack: TJSObject;
  LWrapper: TJSHTMLElement;
  LButton: TJSHTMLButtonElement;
    LCanvas: TJSHTMLCanvasElement;
    LNote: TJSElement;
    LOverlayStatus: TJSElement;
  LIndex: Integer;
  LCount: Integer;
  LShown: Integer;
begin
  ClearItems('aligned-peer-lanes');
  Element('aligned-peer-panel').setAttribute('hidden', '');
  if (FTracks = nil) or (FClockId = '') then
  begin
    Element('aligned-peer-note').textContent :=
      'No shared source clock is declared for this recording.';
    Exit;
  end;
  LCount := 0;
  for LIndex := 0 to FTracks.length - 1 do
  begin
    LTrack := TJSObject(FTracks[LIndex]);
    if SharesSourceClock(LTrack) then
      Inc(LCount);
  end;
  if LCount = 0 then
  begin
    Element('aligned-peer-note').textContent :=
      'No other catalog track shares this nonempty source clock.';
    Exit;
  end;
  LShown := 0;
  for LIndex := 0 to FTracks.length - 1 do
  begin
    if LShown >= MaximumAlignedPeerLanes then
      Break;
    LTrack := TJSObject(FTracks[LIndex]);
    if not SharesSourceClock(LTrack) then
      Continue;
    LWrapper := TJSHTMLElement(document.createElement('div'));
    LWrapper.className := 'aligned-peer-lane';
    LButton := TJSHTMLButtonElement(document.createElement('button'));
    LButton.setAttribute('type', 'button');
    LButton.setAttribute('data-index', IntToStr(LIndex));
    LButton.textContent := 'Open aligned stem: ' +
      TextField(LTrack, 'title');
    LButton.onclick := @HandleAlignedPeer;
    LWrapper.appendChild(LButton);
    LCanvas := TJSHTMLCanvasElement(document.createElement('canvas'));
    LCanvas.id := 'peer-canvas-' + TextField(LTrack, 'source_sha256');
    LCanvas.width := FCanvas.width;
    LCanvas.height := 150;
    LCanvas.setAttribute('aria-label', 'Aligned waveform for ' +
      TextField(LTrack, 'title') + ' on the shared source-frame timeline');
    LWrapper.appendChild(LCanvas);
    LNote := document.createElement('small');
    LNote.id := 'peer-gap-' + TextField(LTrack, 'source_sha256');
    LNote.className := 'peer-source-gap';
    LNote.textContent := 'Loading exact source-frame window…';
    LWrapper.appendChild(LNote);
    LOverlayStatus := document.createElement('small');
    LOverlayStatus.id := 'peer-overlay-' + TextField(LTrack, 'source_sha256');
    LOverlayStatus.className := 'peer-overlay-status';
    LOverlayStatus.textContent := 'Loading review and proposal overlays…';
    LWrapper.appendChild(LOverlayStatus);
    Element('aligned-peer-lanes').appendChild(LWrapper);
    Inc(LShown);
  end;
  if LCount > MaximumAlignedPeerLanes then
    Element('aligned-peer-note').textContent :=
      'Same group, clock and sample rate; source-frame x positions align. ' +
      'Showing first ' + IntToStr(MaximumAlignedPeerLanes) + ' of ' +
      IntToStr(LCount) + ' matching stems.'
  else
    Element('aligned-peer-note').textContent :=
      'Same group, clock and sample rate; source-frame x positions align.';
  Element('aligned-peer-panel').removeAttribute('hidden');
end;

procedure TWorkbench.DrawAlignedPeerWaveform(
  const ACanvas: TJSHTMLCanvasElement; const ABins: TJSArray;
  const AAvailableRatio: Double);
var
  LContext: TJSCanvasRenderingContext2D;
  LRow: TJSObject;
  LPeak: Double;
  LMinimum: Double;
  LMaximum: Double;
  LWidth: Double;
  LAvailableWidth: Double;
  LIndex: Integer;
begin
  LContext := ACanvas.getContextAs2DContext('2d');
  LContext.fillStyleAsColor := '#11212d';
  LContext.fillRect(0, 0, ACanvas.width, ACanvas.height);
  LContext.fillStyleAsColor := '#344852';
  LContext.fillRect(0, 34, ACanvas.width, 1);
  LAvailableWidth := ACanvas.width * AAvailableRatio;
  if LAvailableWidth < ACanvas.width then
  begin
    LContext.fillStyleAsColor := '#26363a';
    LContext.fillRect(LAvailableWidth, 0,
      ACanvas.width - LAvailableWidth, ACanvas.height);
  end;
  if (ABins = nil) or (ABins.length = 0) then
    Exit;
  LPeak := 0.00001;
  for LIndex := 0 to ABins.length - 1 do
  begin
    LRow := TJSObject(ABins[LIndex]);
    LMinimum := Abs(NumberField(LRow, 'min'));
    LMaximum := Abs(NumberField(LRow, 'max'));
    if LMinimum > LPeak then
      LPeak := LMinimum;
    if LMaximum > LPeak then
      LPeak := LMaximum;
  end;
  LContext.fillStyleAsColor := '#7dd8cf';
  LWidth := LAvailableWidth / ABins.length;
  for LIndex := 0 to ABins.length - 1 do
  begin
    LRow := TJSObject(ABins[LIndex]);
    LMinimum := NumberField(LRow, 'min');
    LMaximum := NumberField(LRow, 'max');
    LContext.fillRect(LIndex * LWidth,
      34 - LMaximum / LPeak * 27, LWidth + 1,
      (LMaximum - LMinimum) / LPeak * 27 + 1);
  end;
end;

procedure TWorkbench.DrawAlignedPeerOverlays(
  const ACanvas: TJSHTMLCanvasElement; const ALabels: TJSArray;
  const AProposals: TJSObject;
  const AStart, AEnd, AVisibleEnd, ASourceFrames: Int64);
var
  LContext: TJSCanvasRenderingContext2D;
  LLabel: TJSObject;
  LCandidates: TJSArray;
  LCandidate: TJSObject;
  LFrames: TJSArray;
  LFrame: Double;
  LStart: Int64;
  LEnd: Int64;
  LDrawEnd: Int64;
  LX1: Double;
  LX2: Double;
  LIndex: Integer;
  LPoint: Integer;
  LRow: Integer;
  LWidth: Double;
begin
  LContext := ACanvas.getContextAs2DContext('2d');
  LDrawEnd := Smaller(AEnd, ASourceFrames);
  LContext.fillStyleAsColor := '#17252d';
  LContext.fillRect(0, 74, ACanvas.width, 34);
  LContext.fillStyleAsColor := '#1d2430';
  LContext.fillRect(0, 112, ACanvas.width, 38);
  LContext.strokeStyleAsColor := '#52636d';
  LContext.beginPath;
  LContext.moveTo(0, 72);
  LContext.lineTo(ACanvas.width, 72);
  LContext.moveTo(0, 110);
  LContext.lineTo(ACanvas.width, 110);
  LContext.stroke;
  if LDrawEnd < AVisibleEnd then
  begin
    LX1 := (LDrawEnd - AStart) / (AVisibleEnd - AStart) * ACanvas.width;
    LContext.fillStyleAsColor := '#26363a';
    LContext.fillRect(LX1, 74, ACanvas.width - LX1, 76);
  end;
  if ALabels <> nil then
  begin
    for LIndex := 0 to ALabels.length - 1 do
    begin
      LLabel := TJSObject(ALabels[LIndex]);
      LStart := Trunc(NumberField(LLabel, 'start_frame'));
      LEnd := Trunc(NumberField(LLabel, 'end_frame'));
      if (LStart >= LDrawEnd) or (LEnd <= AStart) or (LEnd <= LStart) then
        Continue;
      if LStart < AStart then
        LStart := AStart;
      if LEnd > LDrawEnd then
        LEnd := LDrawEnd;
      LX1 := (LStart - AStart) / (AVisibleEnd - AStart) * ACanvas.width;
      LX2 := (LEnd - AStart) / (AVisibleEnd - AStart) * ACanvas.width;
      LRow := LIndex mod 3;
      if TextField(LLabel, 'status') = 'approved' then
        LContext.fillStyleAsColor := '#9ce3aa'
      else if TextField(LLabel, 'status') = 'uncertain' then
        LContext.fillStyleAsColor := '#f3c98d'
      else if TextField(LLabel, 'status') = 'rejected' then
        LContext.fillStyleAsColor := '#f39b91'
      else
        LContext.fillStyleAsColor := '#91a4ad';
      LWidth := LX2 - LX1;
      if LWidth < 1 then
        LWidth := 1;
      LContext.fillRect(LX1, 88 + LRow * 6, LWidth, 4);
    end;
  end;
  if AProposals = nil then
    Exit;
  LCandidates := TJSArray(AProposals['candidates']);
  if LCandidates = nil then
    Exit;
  for LIndex := 0 to Smaller(LCandidates.length, 4) - 1 do
  begin
    LCandidate := TJSObject(LCandidates[LIndex]);
    LFrames := TJSArray(LCandidate['frames']);
    if LFrames = nil then
      Continue;
    case LIndex of
      0: LContext.fillStyleAsColor := '#f5c27c';
      1: LContext.fillStyleAsColor := '#c8a6ff';
      2: LContext.fillStyleAsColor := '#79c8ff';
      else LContext.fillStyleAsColor := '#ff9ec4';
    end;
    for LPoint := 0 to LFrames.length - 1 do
    begin
      LFrame := Double(LFrames[LPoint]);
      if (LFrame < AStart) or (LFrame >= LDrawEnd) then
        Continue;
      LX1 := (LFrame - AStart) / (AVisibleEnd - AStart) * ACanvas.width;
      LContext.fillRect(LX1, 126 + LIndex * 5, 2, 4);
    end;
  end;
end;

procedure TWorkbench.LoadAlignedPeerWaveforms(const AEpoch: Integer); async;
var
  LTrack: TJSObject;
  LCanvas: TJSHTMLCanvasElement;
  LOverlayStatus: TJSElement;
  LResponse: TJSResponse;
  LData: TJSObject;
  LCurrentData: TJSObject;
  LPeerLabels: TJSArray;
  LPeerProposals: TJSObject;
  LBins: TJSArray;
  LIndex: Integer;
  LShown: Integer;
  LPeerFrames: Int64;
  LPeerEnd: Int64;
  LVisibleEnd: Int64;
  LBinCount: Integer;
  LAvailableRatio: Double;
  LHash: String;
  LPath: String;
  LOverlayMessage: String;
  LPartition: String;
  LCurrentError: String;
  LProposalError: String;
  LNote: TJSElement;
begin
  if (FTracks = nil) or (FClockId = '') then
    Exit;
  LVisibleEnd := FWindowStart + FWindowSpan;
  LShown := 0;
  for LIndex := 0 to FTracks.length - 1 do
  begin
    if LShown >= MaximumAlignedPeerLanes then
      Break;
    LTrack := TJSObject(FTracks[LIndex]);
    if not SharesSourceClock(LTrack) then
      Continue;
    Inc(LShown);
    if AEpoch <> FWindowEpoch then
      Exit;
    LHash := TextField(LTrack, 'source_sha256');
    LCurrentData := nil;
    LPeerLabels := nil;
    LPeerProposals := nil;
    LCanvas := TJSHTMLCanvasElement(
      document.getElementById('peer-canvas-' + LHash));
    LNote := document.getElementById('peer-gap-' + LHash);
    LOverlayStatus := document.getElementById('peer-overlay-' + LHash);
    if (LCanvas = nil) or (LNote = nil) or (LOverlayStatus = nil) then
      Continue;
    LCanvas.setAttribute('data-viewport-start-frame',
      IntToStr(FWindowStart));
    LCanvas.setAttribute('data-viewport-end-frame',
      IntToStr(LVisibleEnd));
    LPeerFrames := Trunc(NumberField(LTrack, 'frame_count'));
    LPartition := TextField(LTrack, 'partition');
    if LPeerFrames <= FWindowStart then
    begin
      LCanvas.setAttribute('data-source-start-frame', '');
      LCanvas.setAttribute('data-source-end-frame', '');
      DrawAlignedPeerWaveform(LCanvas, nil, 0);
      DrawAlignedPeerOverlays(LCanvas, nil, nil, FWindowStart,
        LVisibleEnd, LVisibleEnd, LPeerFrames);
      LNote.textContent := 'This source ends before the selected frame window.';
      LOverlayStatus.textContent := 'No source frames for overlays.';
      Continue;
    end;
    LPeerEnd := Smaller(LVisibleEnd, LPeerFrames);
    if LPeerEnd <= FWindowStart then
    begin
      LCanvas.setAttribute('data-source-start-frame', '');
      LCanvas.setAttribute('data-source-end-frame', '');
      DrawAlignedPeerWaveform(LCanvas, nil, 0);
      DrawAlignedPeerOverlays(LCanvas, nil, nil, FWindowStart,
        LVisibleEnd, LVisibleEnd, LPeerFrames);
      LNote.textContent := 'No source frames overlap this selected window.';
      LOverlayStatus.textContent := 'No source frames for overlays.';
      Continue;
    end;
    LCanvas.setAttribute('data-source-start-frame',
      IntToStr(FWindowStart));
    LCanvas.setAttribute('data-source-end-frame', IntToStr(LPeerEnd));
    LBinCount := 256;
    if (LPeerEnd - FWindowStart) < LBinCount then
      LBinCount := LPeerEnd - FWindowStart;
    LPath := '/api/waveform?hash=' + LHash +
      '&start=' + IntToStr(FWindowStart) +
      '&end=' + IntToStr(LPeerEnd) + '&bins=' + IntToStr(LBinCount);
    try
      LResponse := await(TJSResponse, FetchApi(LPath, 'GET', ''));
      if AEpoch <> FWindowEpoch then
        Exit;
      if LResponse.status <> 200 then
        raise Exception.Create('Waveform HTTP ' +
          IntToStr(LResponse.status));
      LData := await(TJSObject, LResponse.json());
      if AEpoch <> FWindowEpoch then
        Exit;
      LBins := TJSArray(LData['bins']);
      LAvailableRatio := (LPeerEnd - FWindowStart) / FWindowSpan;
      DrawAlignedPeerWaveform(LCanvas, LBins, LAvailableRatio);
      if LPeerEnd < LVisibleEnd then
        LNote.textContent := 'Shaded area is beyond this stem’s ' +
          IntToStr(LPeerFrames) + '-frame source.'
      else
        LNote.textContent := 'Source frames ' + IntToStr(FWindowStart) +
          '–' + IntToStr(LPeerEnd) + ' on the shared clock.';
      LPeerLabels := nil;
      LPeerProposals := nil;
      LCurrentError := '';
      LProposalError := '';
      LPath := '/api/current?hash=' + LHash +
        '&start=' + IntToStr(FWindowStart) +
        '&end=' + IntToStr(LPeerEnd) + '&count=2048';
      try
        LResponse := await(TJSResponse, FetchApi(LPath, 'GET', ''));
        if AEpoch <> FWindowEpoch then
          Exit;
        if LResponse.status = 200 then
        begin
          LCurrentData := await(TJSObject, LResponse.json());
          if AEpoch <> FWindowEpoch then
            Exit;
          LPeerLabels := TJSArray(LCurrentData['labels']);
        end
        else
          LCurrentError := 'review HTTP ' + IntToStr(LResponse.status);
      except
        on LError: Exception do
        begin
          if AEpoch <> FWindowEpoch then
            Exit;
          LCurrentError := LError.Message;
        end;
      end;
      if (LPartition <> 'evaluation') or
        ((LCurrentData <> nil) and
        (NumberField(LCurrentData, 'review_revision') > 0)) then
      begin
        LPath := '/api/proposals?hash=' + LHash +
          '&start=' + IntToStr(FWindowStart) +
          '&end=' + IntToStr(LPeerEnd);
        try
          LResponse := await(TJSResponse, FetchApi(LPath, 'GET', ''));
          if AEpoch <> FWindowEpoch then
            Exit;
          if LResponse.status = 200 then
          begin
            LPeerProposals := await(TJSObject, LResponse.json());
            if AEpoch <> FWindowEpoch then
              Exit;
          end
          else if LResponse.status <> 404 then
            LProposalError := 'proposal HTTP ' + IntToStr(LResponse.status);
        except
          on LError: Exception do
          begin
            if AEpoch <> FWindowEpoch then
              Exit;
            LProposalError := LError.Message;
          end;
        end;
      end;
      DrawAlignedPeerOverlays(LCanvas, LPeerLabels, LPeerProposals,
        FWindowStart, LPeerEnd, LVisibleEnd, LPeerFrames);
      if LCurrentError <> '' then
        LOverlayMessage := 'Reviewed labels unavailable: ' + LCurrentError
      else if (LPartition = 'evaluation') and
        ((LCurrentData = nil) or
        (NumberField(LCurrentData, 'review_revision') = 0)) then
        LOverlayMessage := 'Blind evaluation: proposals hidden; ' +
          'no saved reviewed labels in this window.'
      else if (LPeerLabels = nil) or (LPeerLabels.length = 0) then
        LOverlayMessage := 'No reviewed labels in this window.'
      else
        LOverlayMessage := IntToStr(LPeerLabels.length) +
          ' reviewed label(s) shown.';
      if LProposalError <> '' then
        LOverlayMessage := LOverlayMessage + ' Proposals unavailable: ' +
          LProposalError + '.'
      else if (LPartition = 'evaluation') and
        (LCurrentData <> nil) and
        (NumberField(LCurrentData, 'review_revision') = 0) then
        LOverlayMessage := LOverlayMessage + ' Blind gate active.'
      else if LPeerProposals = nil then
        LOverlayMessage := LOverlayMessage + ' No saved Pythian proposals.'
      else
        LOverlayMessage := LOverlayMessage + ' Pythian beat ticks shown.';
      LOverlayStatus.textContent := LOverlayMessage;
    except
      on LError: Exception do
      begin
        if AEpoch <> FWindowEpoch then
          Exit;
        DrawAlignedPeerWaveform(LCanvas, nil, 0);
        LNote.textContent := 'Aligned waveform unavailable: ' +
          LError.Message;
        LOverlayStatus.textContent :=
          'Review/proposal overlays unavailable: ' + LError.Message;
      end;
    end;
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
  LRow := TJSObject(FCurrentLabels[AIndex]);
  if StructuredRow(LRow) then
  begin
    Status('This answer is bound to a structured request. Its value and links cannot be edited as a freeform label; use a new prepared request.', True);
    Exit;
  end;
  ReleaseRequestDraft;
  FSelectedLabel := AIndex;
  FDragMode := dmNone;
  Input('label-id').value := TextField(LRow, 'label_id');
  Input('label-type').value := TextField(LRow, 'type');
  UpdateValueHint;
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
  Element('review-editor').setAttribute('open', '');
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
  FCanvas.setAttribute('data-window-start-frame',
    IntToStr(FWindowStart));
  FCanvas.setAttribute('data-window-end-frame', IntToStr(LEnd));
end;

procedure TWorkbench.Start; async;
var
  LResponse: TJSResponse;
  LData: TJSObject;
  LEpoch: Integer;
  LTimer: NativeInt;
begin
  Inc(FStartEpoch);
  LEpoch := FStartEpoch;
  FToken := '';
  FConnectionLoading := True;
  UpdateLoading;
  Element('connect-retry').setAttribute('hidden', '');
  Status('Connecting to local service…');
  LTimer := window.setTimeout(
    procedure()
    begin
      if (LEpoch = FStartEpoch) and (FToken = '') then
      begin
        Inc(FStartEpoch);
        FConnectionLoading := False;
        UpdateLoading;
        Status('Connection is taking too long. Check that this device can reach the catalog, then retry.', True);
        Element('connect-retry').removeAttribute('hidden');
      end;
    end, 10000);
  try
    LResponse := await(TJSResponse, FetchApi('/api/session', 'GET', ''));
    if LEpoch <> FStartEpoch then
    begin
      window.clearTimeout(LTimer);
      Exit;
    end;
    if LResponse.status <> 200 then
      raise Exception.Create('HTTP ' + IntToStr(LResponse.status));
    LData := await(TJSObject, LResponse.json());
    if LEpoch <> FStartEpoch then
    begin
      window.clearTimeout(LTimer);
      Exit;
    end;
    window.clearTimeout(LTimer);
    FToken := TextField(LData, 'token');
    if FToken = '' then
    begin
      raise Exception.Create('Session token missing');
    end;
    try
      window.localStorage.removeItem(LegacyAccessKeyStorage);
    except
      // Disabled browser storage must not block the workbench.
    end;
    Element('connect-retry').setAttribute('hidden', '');
    FConnectionLoading := False;
    UpdateLoading;
    ShowWorkspace;
    Status('Connected to catalog.');
    FSourceQueueKnown := False;
    FListeningQueueKnown := False;
    FListeningQueueLoading := True;
    RefreshLists;
    RefreshListeningOverview;
  except
    on LError: Exception do
    begin
      if LEpoch = FStartEpoch then
      begin
        window.clearTimeout(LTimer);
        FConnectionLoading := False;
        UpdateLoading;
        Status('Could not reach the catalog service: ' +
          LError.Message + '. Retry the connection.', True);
        Element('connect-retry').removeAttribute('hidden');
      end;
    end;
  else
    if LEpoch = FStartEpoch then
    begin
      window.clearTimeout(LTimer);
      FConnectionLoading := False;
      UpdateLoading;
      Status('Could not reach the catalog service. Check this device’s connection and retry.', True);
      Element('connect-retry').removeAttribute('hidden');
    end;
  end;
end;

procedure TWorkbench.RefreshLists; async;
var
  LResponse: TJSResponse;
  LData: TJSObject;
begin
  Inc(FCatalogLoads);
  UpdateLoading;
  try
    try
      LResponse := await(TJSResponse, FetchApi('/api/catalog', 'GET', ''));
    if LResponse.status <> 200 then
    begin
      raise Exception.Create('Catalog HTTP ' + IntToStr(LResponse.status));
    end;
    LData := await(TJSObject, LResponse.json());
    RenderCatalog(LData);
    RefreshAssignments;
    LResponse := await(TJSResponse, FetchApi('/api/inbox', 'GET', ''));
    if LResponse.status <> 200 then
    begin
      raise Exception.Create('Inbox HTTP ' + IntToStr(LResponse.status));
    end;
    LData := await(TJSObject, LResponse.json());
    RenderInbox(LData);
    Status('');
    except
      on LError: Exception do
      begin
        Status('Catalog list failed: ' + LError.Message + '. Retry connection to reload.', True);
        Element('connect-retry').removeAttribute('hidden');
      end;
    else
    begin
      Status('Catalog request failed in this browser. Retry connection to reload.', True);
      Element('connect-retry').removeAttribute('hidden');
    end;
    end;
  finally
    Dec(FCatalogLoads);
    UpdateLoading;
    UpdateReviewOverview;
  end;
end;

procedure TWorkbench.RefreshAssignments; async;
var
  LResponse: TJSResponse;
  LData: TJSObject;
begin
  FSourceQueueKnown := False;
  Inc(FQueueLoads);
  UpdateLoading;
  UpdateReviewOverview;
  try
    try
      LResponse := await(TJSResponse,
      FetchApi('/api/review-queue', 'GET', ''));
    if LResponse.status = 404 then
    begin
      FSourceQueueKnown := False;
      UpdateReviewOverview;
      if not FQueuePostCommitPending then
      begin
        FQueueAdvancePending := False;
        ClearRequest;
      end;
      Element('queue-progress').textContent := 'Queue unavailable';
      Element('assignment-state').textContent :=
        'Review requests are unavailable in this service version. Saved decisions remain in the catalog.';
      Element('connect-retry').removeAttribute('hidden');
      Exit;
    end;
    if LResponse.status <> 200 then
      raise Exception.Create('Review queue HTTP ' +
        IntToStr(LResponse.status));
    LData := await(TJSObject, LResponse.json());
    RenderAssignments(LData);
    FQueuePostCommitPending := False;
    UpdateRecordAnswerAction;
    except
      on LError: Exception do
      begin
        FSourceQueueKnown := False;
        UpdateReviewOverview;
        if not FQueuePostCommitPending then
        begin
          FQueueAdvancePending := False;
          ClearRequest;
        end;
        Element('queue-progress').textContent := 'Queue unavailable';
        if FQueuePostCommitPending then
          Element('assignment-state').textContent :=
            'Review was saved. Queue refresh failed: ' + LError.Message +
            '. Retry connection to continue.'
        else
          Element('assignment-state').textContent :=
            'Review requests could not load: ' + LError.Message;
        Element('connect-retry').removeAttribute('hidden');
      end;
    else
      begin
        FSourceQueueKnown := False;
        UpdateReviewOverview;
        if not FQueuePostCommitPending then
        begin
          FQueueAdvancePending := False;
          ClearRequest;
        end;
        Element('queue-progress').textContent := 'Queue unavailable';
        if FQueuePostCommitPending then
          Element('assignment-state').textContent :=
            'Review was saved. Queue refresh failed. Retry connection to continue.'
        else
          Element('assignment-state').textContent :=
            'Review requests could not load. Retry connection to reload.';
        Element('connect-retry').removeAttribute('hidden');
      end;
    end;
  finally
    Dec(FQueueLoads);
    UpdateLoading;
    UpdateReviewOverview;
  end;
end;

procedure TWorkbench.RefreshListeningOverview; async;
var
  LResponse: TJSResponse;
  LData: TJSObject;
  LWaiting: TJSArray;
  LCompleted: TJSArray;
begin
  FListeningQueueKnown := False;
  FListeningQueueLoading := True;
  UpdateReviewOverview;
  try
    try
      LResponse := await(TJSResponse,
        FetchApi('/api/listen-queue', 'GET', ''));
      if LResponse.status <> 200 then
        raise Exception.Create('Listening queue HTTP ' +
          IntToStr(LResponse.status));
      LData := await(TJSObject, LResponse.json());
      LWaiting := TJSArray(LData['items']);
      LCompleted := TJSArray(LData['completed']);
      if (LWaiting = nil) or (LCompleted = nil) then
        raise Exception.Create('Listening queue shape is invalid');
      FListeningWaiting := LWaiting.length;
      FListeningCompleted := LCompleted.length;
      FListeningQueueKnown := True;
    except
      FListeningQueueKnown := False;
    end;
  finally
    FListeningQueueLoading := False;
    UpdateReviewOverview;
  end;
end;

function TWorkbench.HandlePageShow(AEvent: TEventListenerEvent): Boolean;
begin
  Result := False;
  if (FToken <> '') and isBoolean(TJSObject(AEvent)['persisted']) and
    Boolean(TJSObject(AEvent)['persisted']) then
  begin
    RefreshAssignments;
    RefreshListeningOverview;
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

procedure TWorkbench.SelectTrack(const AIndex: Integer;
  const AStartFrame, AEndFrame: Int64;
  const AReviewId, AQuestion, AReviewType, AConflict,
  AGeometry, ARequestHash: String; const ASpec: TJSObject); async;
var
  LTrack: TJSObject;
  LKeepTimeline: Boolean;
  LPreviousStart: Int64;
  LPreviousSpan: Int64;
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
  ClearRequest;
  LTrack := TJSObject(FTracks[AIndex]);
  LKeepTimeline := (FSourceHash <> '') and (FClockId <> '') and
    (FSourceGroup <> '') and
    (TextField(LTrack, 'clock_id') = FClockId) and
    (TextField(LTrack, 'source_group') = FSourceGroup) and
    (Trunc(NumberField(LTrack, 'sample_rate')) = FSampleRate);
  LPreviousStart := FWindowStart;
  LPreviousSpan := FWindowSpan;
  FSourceHash := TextField(LTrack, 'source_sha256');
  FSourceGroup := TextField(LTrack, 'source_group');
  FClockId := TextField(LTrack, 'clock_id');
  FPartition := TextField(LTrack, 'partition');
  FSampleRate := Trunc(NumberField(LTrack, 'sample_rate'));
  FFrameCount := Trunc(NumberField(LTrack, 'frame_count'));
  if (FSampleRate <= 0) or (FFrameCount <= 0) then
  begin
    Status('The catalog track has invalid audio geometry.', True);
    FSourceHash := '';
    Exit;
  end;
  if AReviewId <> '' then
  begin
    if (AQuestion = '') or (AStartFrame < 0) or
      (AEndFrame <= AStartFrame) or (AEndFrame > FFrameCount) or
      (AEndFrame - AStartFrame > Int64(FSampleRate) * 30) then
    begin
      Status('The selected review request has an invalid source region.', True);
      Exit;
    end;
    FReviewId := AReviewId;
    FReviewQuestion := AQuestion;
    FReviewType := AReviewType;
    FReviewGeometry := AGeometry;
    FReviewRequestHash := ARequestHash;
    FReviewSpec := ASpec;
    FReviewConflict := AConflict;
    FReviewStart := AStartFrame;
    FReviewEnd := AEndFrame;
  end;
  Element('work-column').removeAttribute('hidden');
  Element('workspace').removeAttribute('class');
  Inc(FWindowEpoch);
  FAudio.pause;
  FAudio.removeAttribute('src');
  FAudioCueLoaded := False;
  Element('audio-mode').textContent := 'No region loaded';
  AudioFeedback('Press Play original to hear the selected region.');
  TJSHTMLButtonElement(Element('load-audio-button')).disabled := False;
  if FAudioUrl <> '' then
  begin
    TJSURL.revokeObjectURL(FAudioUrl);
    FAudioUrl := '';
  end;
  if AReviewId <> '' then
  begin
    FWindowStart := AStartFrame;
    FWindowSpan := AEndFrame - AStartFrame;
  end
  else if LKeepTimeline then
  begin
    FWindowSpan := Smaller(LPreviousSpan, FFrameCount);
    if FWindowSpan <= 0 then
      FWindowSpan := Smaller(FFrameCount,
        Smaller(Int64(FSampleRate) * 10, 8388608));
    FWindowStart := Smaller(LPreviousStart,
      FFrameCount - FWindowSpan);
  end
  else
  begin
    FWindowStart := 0;
    FWindowSpan := Smaller(FFrameCount,
      Smaller(Int64(FSampleRate) * 10, 8388608));
  end;
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
  UpdatePendingUi;
  FDragMode := dmNone;
  Input('jump-seconds').value := IntToStr(FWindowStart div FSampleRate);
  Input('jump-seconds').setAttribute('max',
    IntToStr((FFrameCount - 1) div FSampleRate));
  Element('track-title').textContent := TextField(LTrack, 'title');
  if AReviewId <> '' then
    ReviewPrompt('Review request selected.');
  Element('track-partition').textContent := UpperCase(FPartition);
  Element('track-meta').textContent :=
    TextField(LTrack, 'source_group') + ' · ' +
    TextField(LTrack, 'provenance') + ' · ' +
    TextField(LTrack, 'license') + ' · ' +
    IntToStr(FFrameCount div FSampleRate) + ' s · ' +
    IntToStr(FSampleRate) + ' Hz';
  UpdateTrackIdentity;
  UpdateTrackProposalIdentity;
  RenderAlignedPeerScaffold;
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
  LMainBinCount: Integer;
  LResponse: TJSResponse;
  LData: TJSObject;
begin
  if FSourceHash = '' then
  begin
    Exit;
  end;
  FHistoryLoading := True;
  FHistoryLoadFailed := False;
  UpdatePendingUi;
  UpdateRecordAnswerAction;
  Status('Loading source frames and saved labels…');
  try
    Inc(FWindowEpoch);
    CancelAudioRequest;
    Inc(FAudioEpoch);
    FAudioLoading := False;
    UpdateLoading;
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
    FAudioCueLoaded := False;
    Element('audio-mode').textContent := 'No region loaded';
    AudioFeedback('Press Play original to hear this region.');
    TJSHTMLButtonElement(Element('load-audio-button')).disabled := False;
    if FAudioUrl <> '' then
    begin
      TJSURL.revokeObjectURL(FAudioUrl);
      FAudioUrl := '';
    end;
    UpdateWindowLabel;
    Input('jump-seconds').value := IntToStr(FWindowStart div FSampleRate);
    LMainBinCount := 512;
    if (LEnd - LStart) < LMainBinCount then
      LMainBinCount := LEnd - LStart;
    if LMainBinCount < 1 then
      raise Exception.Create('The selected source window is empty');
    LPath := '/api/waveform?hash=' + LHash +
      '&start=' + IntToStr(LStart) +
      '&end=' + IntToStr(LEnd) + '&bins=' + IntToStr(LMainBinCount);
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
    if FReviewRevision > 0 then
      Element('track-review-state').textContent :=
        'Review: revision ' + IntToStr(FReviewRevision)
    else
      Element('track-review-state').textContent := 'Review: no saved events';
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
    UpdateRecordAnswerAction;
    DrawWaveform;
    Status('Loaded source frames ' + IntToStr(LStart) +
      '–' + IntToStr(LEnd) + '.');
    LoadAlignedPeerWaveforms(LEpoch);
    if FSaveInProgress then
    begin
      FSaveInProgress := False;
      UpdatePendingUi;
      UpdateRecordAnswerAction;
      if FQueueRefreshPending then
      begin
        FQueueRefreshPending := False;
        RefreshAssignments;
      end;
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
        Element('track-review-state').textContent :=
          'Review: load failed';
        UpdatePendingUi;
      end;
      FProposals := nil;
      UpdateTrackProposalIdentity;
      UpdateRecordAnswerAction;
      Status('Timeline failed: ' + LError.Message, True);
      if FQueueRefreshPending then
      begin
        FQueueRefreshPending := False;
        RefreshAssignments;
      end;
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
  LTimer: NativeInt;
  LReason: String;
  LIndex: Integer;
  LReader: TWorkbenchStreamReader;
  LRead: TJSObject;
  LParts: TJSArray;
  LChunk: TJSUint8Array;
begin
  if FSaveInProgress then
  begin
    Exit;
  end;
  if FSourceHash = '' then
  begin
    AudioFeedback('Choose a recording before pressing Play original.', True);
    Exit;
  end;
  if (FAudioUrl <> '') and (FAudioCueLoaded = ACue) then
  begin
    PlayLoadedAudio;
    Exit;
  end;
  if ACue and ((FProposals = nil) or (FSelectedProposal < 0)) then
  begin
    Status('Select a saved beat proposal before loading its cue.', True);
    Exit;
  end;
  LTimer := 0;
  try
    LEpoch := FWindowEpoch;
    CancelAudioRequest;
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
      AudioFeedback('Fetching the Pythian cue…');
    end
    else
    begin
      LPath := '/api/audio?hash=' + LHash +
        '&start=' + IntToStr(LStart) + '&end=' + IntToStr(LEnd);
      Status('Loading original WAV region…');
      AudioFeedback('Fetching the original WAV region…');
    end;
    TJSHTMLButtonElement(Element('load-audio-button')).disabled := True;
    FAudioLoading := True;
    FAudioAbort := TWorkbenchAbortController.new;
    FAudioReceived := 0;
    FAudioTotal := 0;
    UpdateLoading;
    LTimer := window.setTimeout(
      procedure()
      begin
        if (LEpoch = FWindowEpoch) and (LAudioEpoch = FAudioEpoch) then
        begin
          CancelAudioRequest;
          Inc(FAudioEpoch);
          FAudioLoading := False;
          UpdateLoading;
          TJSHTMLButtonElement(Element('load-audio-button')).disabled := False;
          Status('Audio request timed out. Check the connection and press Play original to retry.', True);
          AudioFeedback('The WAV request took too long. Press Play original to retry.', True);
        end;
      end, 120000);
    LResponse := await(TJSResponse, FetchApi(LPath, 'GET', '',
      FAudioAbort.signal));
    if (LEpoch <> FWindowEpoch) or (LAudioEpoch <> FAudioEpoch) then
    begin
      window.clearTimeout(LTimer);
      Exit;
    end;
    if LResponse.status <> 200 then
    begin
      LReason := '';
      try
        LReason := await(String, LResponse.text());
      except
        // Keep the HTTP status available even if the error body cannot be read.
      end;
      if (LEpoch <> FWindowEpoch) or (LAudioEpoch <> FAudioEpoch) then
      begin
        window.clearTimeout(LTimer);
        Exit;
      end;
      LReason := Trim(Copy(LReason, 1, 160));
      for LIndex := 1 to Length(LReason) do
        if Ord(LReason[LIndex]) < 32 then
          LReason[LIndex] := ' ';
      if FToken <> '' then
        LReason := StringReplace(LReason, FToken, '[redacted]',
          [rfReplaceAll]);
      if LReason <> '' then
        raise Exception.Create('Audio HTTP ' +
          IntToStr(LResponse.status) + ': ' + LReason);
      raise Exception.Create('Audio HTTP ' + IntToStr(LResponse.status));
    end;
    if LResponse.headers.has('Content-Length') and
      (TWorkbenchResponse(LResponse).BodyStream <> nil) then
      FAudioTotal := StrToInt64Def(LResponse.headers.get('Content-Length'), 0);
    if FAudioTotal > 0 then
    begin
      UpdateLoading;
      LParts := TJSArray.new;
      LReader := TWorkbenchResponse(LResponse).BodyStream.getReader();
      repeat
        LRead := await(TJSObject, LReader.read());
        if (LEpoch <> FWindowEpoch) or (LAudioEpoch <> FAudioEpoch) then
        begin
          window.clearTimeout(LTimer);
          LReader.cancel();
          Exit;
        end;
        if Boolean(LRead['done']) then Break;
        LChunk := TJSUint8Array(LRead['value']);
        LParts.push(LChunk);
        Inc(FAudioReceived, LChunk.byteLength);
        UpdateLoading;
      until False;
      LBlob := TJSBlob.new(LParts);
      if LBlob.size <> FAudioTotal then
        raise Exception.Create('WAV transfer ended before all bytes arrived');
    end
    else
      LBlob := await(TJSBlob, TWorkbenchResponse(LResponse).blobRequest());
    if (LEpoch <> FWindowEpoch) or (LAudioEpoch <> FAudioEpoch) then
    begin
      window.clearTimeout(LTimer);
      Exit;
    end;
    window.clearTimeout(LTimer);
    FAudioAbort := nil;
    FAudioLoading := False;
    UpdateLoading;
    if FAudioUrl <> '' then
    begin
      TJSURL.revokeObjectURL(FAudioUrl);
    end;
    FAudioUrl := TJSURL.createObjectURL(LBlob);
    FAudio.src := FAudioUrl;
    FAudioCueLoaded := ACue;
    FAudio.loop := Input('loop-region').checked;
    FAudio.load;
    TJSHTMLButtonElement(Element('load-audio-button')).disabled := False;
    AudioFeedback('WAV received; starting playback…');
    if ACue then
    begin
      Element('audio-mode').textContent :=
        'Pythian cue · grid ' + IntToStr(LCandidate + 1);
      Status('Pythian cue received by the browser.');
    end
    else
    begin
      Element('audio-mode').textContent := 'Original WAV';
      Status('Original WAV received by the browser.');
    end;
    PlayLoadedAudio;
  except
    on LError: Exception do
    begin
      if LTimer <> 0 then window.clearTimeout(LTimer);
      if (LEpoch = FWindowEpoch) and (LAudioEpoch = FAudioEpoch) then
      begin
        CancelAudioRequest;
        FAudioLoading := False;
        UpdateLoading;
        Status('Audio failed: ' + LError.Message, True);
        AudioFeedback('Could not load audio: ' + LError.Message +
          '. Press Play original to retry.', True);
        TJSHTMLButtonElement(Element('load-audio-button')).disabled := False;
      end;
    end
    else
    begin
      if LTimer <> 0 then window.clearTimeout(LTimer);
      if (LEpoch = FWindowEpoch) and (LAudioEpoch = FAudioEpoch) then
      begin
        CancelAudioRequest;
        FAudioLoading := False;
        UpdateLoading;
        Status('The browser could not fetch or prepare this audio region.', True);
        AudioFeedback('Audio request failed in this browser. The player has no region; ' +
          'press Play original to retry.', True);
        TJSHTMLButtonElement(Element('load-audio-button')).disabled := False;
      end;
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

procedure TWorkbench.ChoosePresence(const AValue: String);
begin
  if not (StructuredGuided or
    ((FReviewSpec = nil) and
     ((FReviewType = 'presence') or (FReviewType = 'activity')))) or
    not SelectedExactRequest or
    (FReviewConflict <> '') or FHistoryLoading or FHistoryLoadFailed or
    FSaveInProgress or FPresenceChecking or
    ((FPendingChanges <> nil) and (FPendingChanges.length > 0)) then
    Exit;
  if not GuidedValueAllowed(FReviewType, AValue) then
    Exit;
  FPresenceValue := AValue;
  FPresenceFeedback := '';
  UpdateRecordAnswerAction;
end;

procedure TWorkbench.SavePresence; async;
var
  LResponse: TJSResponse;
  LData: TJSObject;
  LRows: TJSArray;
  LCompleted: TJSArray;
  LRow: TJSObject;
  LChange: TJSObject;
  LId, LHash, LQuestion, LType, LGeometry, LValue: String;
  LRequestHash, LDesiredStatus: String;
  LStart, LEnd: Int64;
  LEpoch, LIndex: Integer;
  LFailure, LReason, LDetail: String;
begin
  if not (StructuredGuided or
    ((FReviewSpec = nil) and
     ((FReviewType = 'presence') or (FReviewType = 'activity')))) or
    not SelectedExactRequest or
    (FReviewConflict <> '') or FHistoryLoading or FHistoryLoadFailed or
    FSaveInProgress or FPresenceChecking or
    (FPresenceValue = CurrentPresenceAnswer) or
    ((FPendingChanges <> nil) and (FPendingChanges.length > 0)) or
    not GuidedValueAllowed(FReviewType, FPresenceValue) then
    Exit;
  LId := FReviewId;
  LHash := FSourceHash;
  LQuestion := FReviewQuestion;
  LType := FReviewType;
  LGeometry := FReviewGeometry;
  LStart := FReviewStart;
  LEnd := FReviewEnd;
  LValue := FPresenceValue;
  LRequestHash := FReviewRequestHash;
  LDesiredStatus := 'approved';
  if (FReviewSpec <> nil) and
    (TextField(FReviewSpec, 'proposal_id') <> '') then
    LDesiredStatus := TJSHTMLSelectElement(
      Element('structured-status')).value;
  LEpoch := FWindowEpoch;
  FPresenceChecking := True;
  FPresenceFeedback := '';
  UpdateRecordAnswerAction;
  LFailure := 'Network request failed before HTTP response';
  try
    LResponse := await(TJSResponse, FetchApi('/api/review-queue', 'GET', ''));
    if (LEpoch <> FWindowEpoch) or (LId <> FReviewId) or
      (LHash <> FSourceHash) or (LQuestion <> FReviewQuestion) or
      (LType <> FReviewType) or
      (LGeometry <> FReviewGeometry) or
      (LRequestHash <> FReviewRequestHash) or
      (LStart <> FReviewStart) or (LEnd <> FReviewEnd) or
      (LValue <> FPresenceValue) or not SelectedExactRequest then
      Exit;
    if LResponse.status <> 200 then
    begin
      LFailure := 'HTTP ' + IntToStr(LResponse.status);
      LReason := '';
      try
        LReason := await(String, LResponse.text());
      except
        // The status remains available if the response body cannot be read.
      end;
      LReason := BoundedRequestDetail(LReason, FToken);
      if LReason <> '' then
        LFailure := LFailure + ': ' + LReason;
      raise Exception.Create(LFailure);
    end;
    LFailure := '';
    LData := await(TJSObject, LResponse.json());
    if (LEpoch <> FWindowEpoch) or (LId <> FReviewId) or
      (LHash <> FSourceHash) or (LQuestion <> FReviewQuestion) or
      (LType <> FReviewType) or
      (LGeometry <> FReviewGeometry) or
      (LRequestHash <> FReviewRequestHash) or
      (LStart <> FReviewStart) or (LEnd <> FReviewEnd) or
      (LValue <> FPresenceValue) or not SelectedExactRequest then
      Exit;
    LRows := TJSArray(LData['items']);
    LRow := nil;
    for LIndex := 0 to LRows.length - 1 do
      if TextField(TJSObject(LRows[LIndex]), 'id') = LId then
      begin
        LRow := TJSObject(LRows[LIndex]);
        Break;
      end;
    if LRow = nil then
    begin
      LCompleted := TJSArray(LData['completed']);
      if LCompleted <> nil then
        for LIndex := 0 to LCompleted.length - 1 do
          if (TextField(TJSObject(LCompleted[LIndex]), 'id') = LId) and
            (TextField(TJSObject(LCompleted[LIndex]),
              'request_sha256') = LRequestHash) and
            (TextField(TJSObject(LCompleted[LIndex]),
              'current_value') = LValue) and
            (TextField(TJSObject(LCompleted[LIndex]),
              'current_status') = LDesiredStatus) then
          begin
            FPresenceChecking := False;
            FReviewCurrentValue := LValue;
            FReviewCurrentStatus := LDesiredStatus;
            FPresenceFeedback := 'This answer is already saved. No duplicate review was recorded.';
            FQueueAdvancePending := True;
            FQueueAdvanceIndex := 0;
            FQueuePostCommitPending := True;
            UpdateRecordAnswerAction;
            RefreshAssignments;
            Exit;
          end;
      FPresenceChecking := False;
      FPresenceFeedback := 'This request is no longer pending. Your choice remains selected; reload the queue before any new save.';
      UpdateRecordAnswerAction;
      Exit;
    end;
    if (TextField(LRow, 'source_sha256') <> LHash) or
      (Trunc(NumberField(LRow, 'start_frame')) <> LStart) or
      (Trunc(NumberField(LRow, 'end_frame')) <> LEnd) or
      (TextField(LRow, 'label_type') <> LType) or
      (TextField(LRow, 'question') <> LQuestion) or
      (ReviewGeometry(LRow) <> LGeometry) or
      (TextField(LRow, 'request_sha256') <> LRequestHash) or
      (TextField(LRow, 'answer_conflict') <> '') then
    begin
      FPresenceChecking := False;
      FPresenceFeedback := 'The exact request changed or conflicts with a saved label. Your choice remains selected; reload the queue.';
      UpdateRecordAnswerAction;
      Exit;
    end;
    FReviewCurrentValue := TextField(LRow, 'current_value');
    FReviewCurrentStatus := TextField(LRow, 'current_status');
    if LValue = CurrentPresenceAnswer then
    begin
      FPresenceChecking := False;
      FPresenceFeedback := 'This answer was already saved. No new review was recorded.';
      UpdateRecordAnswerAction;
      Exit;
    end;
    FPresenceChecking := False;
    LChange := TJSObject.new;
    LChange['label_id'] := LId;
    LChange['type'] := LType;
    LChange['value'] := LValue;
    LChange['status'] := LDesiredStatus;
    LChange['start_frame'] := LStart;
    LChange['end_frame'] := LEnd;
    LChange['part'] := '';
    if FReviewSpec <> nil then
      LChange['proposal_id'] := TextField(FReviewSpec, 'proposal_id')
    else
      LChange['proposal_id'] := '';
    if Copy(LType, 1, 4) = 'ext.' then
      LChange['extension_version'] := 2;
    SaveReview(LChange);
  except
    on LError: Exception do
    begin
      if (LEpoch = FWindowEpoch) and (LId = FReviewId) then
      begin
        FPresenceChecking := False;
        LDetail := LFailure;
        LReason := BoundedRequestDetail(LError.Message, FToken);
        if LDetail = 'Network request failed before HTTP response' then
        begin
          if (LReason <> '') and (LReason <> LDetail) then
            LDetail := LDetail + ': ' + LReason;
        end
        else if LDetail = '' then
          LDetail := LReason;
        if LDetail = '' then
          LDetail := 'unknown request error';
        if CurrentPresenceAnswer <> '' then
          FPresenceFeedback := 'Request check failed; no correction recorded. The saved answer remains ' +
            CurrentPresenceAnswer + '. (' + LDetail + ')'
        else
          FPresenceFeedback := 'Request check failed; no new answer recorded (' +
            LDetail + '). Your choice is still selected; try again.';
        UpdateRecordAnswerAction;
      end;
    end;
  else
    if (LEpoch = FWindowEpoch) and (LId = FReviewId) then
    begin
      FPresenceChecking := False;
      LDetail := BoundedRequestDetail(LFailure, FToken);
      if LDetail = '' then
        LDetail := 'invalid response or browser request error';
      FPresenceFeedback := 'Request check failed; no new answer or correction was recorded (' +
        LDetail + '). Your choice is still selected.';
      UpdateRecordAnswerAction;
    end;
  end;
end;

procedure TWorkbench.SaveReview(const AGuidedChange: TJSObject); async;
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
  LGuided: Boolean;
  LRequestDraft: Boolean;
  LQueueResponse: TJSResponse;
  LQueueData: TJSObject;
  LQueueItems: TJSArray;
  LQueueCompleted: TJSArray;
  LQueueRow: TJSObject;
  LCompletion: TJSObject;
  LQueueIndex: Integer;
begin
  LGuided := AGuidedChange <> nil;
  if FSaveInProgress then
    Exit;
  if FQueuePostCommitPending then
  begin
    Status('The review was saved. Retry the queue connection before starting another answer.', True);
    Exit;
  end;
  if FSourceHash = '' then
  begin
    Exit;
  end;
  if FHistoryLoading or FHistoryLoadFailed then
  begin
    Status('Wait for the selected source labels to load before saving.', True);
    Exit;
  end;
  LQueued := (FPendingChanges <> nil) and
    (FPendingChanges.length > 0);
  if LGuided and LQueued then
    Exit;
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
  else if LGuided then
  begin
    LChange := AGuidedChange;
    LStart := Trunc(NumberField(LChange, 'start_frame'));
    LEnd := Trunc(NumberField(LChange, 'end_frame'));
    if not SelectedExactRequest or
      not (StructuredGuided or
        ((FReviewSpec = nil) and
        ((FReviewType = 'presence') or (FReviewType = 'activity')))) or
      (FReviewConflict <> '') or (TextField(LChange, 'label_id') <> FReviewId) or
      (TextField(LChange, 'type') <> FReviewType) or
      ((TextField(LChange, 'status') <> 'approved') and
       ((FReviewSpec = nil) or
        (TextField(LChange, 'status') <> 'rejected') or
        (TextField(FReviewSpec, 'proposal_id') = ''))) or
      (TextField(LChange, 'value') <> FPresenceValue) or
      (LStart <> FReviewStart) or (LEnd <> FReviewEnd) then
      Exit;
  end
  else
  begin
    LStart := StrToInt64Def(Input('label-start').value, -1);
    LEnd := StrToInt64Def(Input('label-end').value, -1);
    if FRequestDraft and
      (not SelectedExactRequest or
       (Input('label-id').value <> FReviewId) or
       (Input('label-proposal').value <>
         TextField(FReviewSpec, 'proposal_id')) or
       ((FReviewType <> '') and
        (Input('label-type').value <> FReviewType))) then
    begin
      Status('The request draft no longer matches its exact region. Select the request again.', True);
      Exit;
    end;
    if FRequestDraft and not RequestGeometryAllows(FReviewGeometry,
      FReviewStart, FReviewEnd, LStart, LEnd) then
    begin
      if FReviewGeometry = 'point' then
        Status('Place a one-frame point inside the selected request region before saving.', True)
      else if FReviewGeometry = 'contained' then
        Status('Keep the label span entirely inside the selected request region.', True)
      else
        Status('The request draft must use its exact selected region.', True);
      Exit;
    end;
    if (Trim(Input('label-id').value) = '') then
    begin
      Status('Enter a label ID before saving.', True);
      Exit;
    end;
    if Input('label-type').value = '' then
    begin
      Status('Choose a label type before saving.', True);
      Exit;
    end;
    if FRequestDraft and (FReviewSpec <> nil) and
      (TJSHTMLSelectElement(Element('structured-value')).value = '') then
    begin
      Status('Choose one declared answer before saving.', True);
      Exit;
    end;
    if FRequestDraft and (Trim(Input('label-value').value) = '') and
      (FReviewSpec = nil) then
    begin
      Status('Enter your answer before saving.', True);
      Exit;
    end;
    LChange := EditorChange(LStart, LEnd, Input('label-id').value);
  end;
  if (LStart < 0) or (LEnd <= LStart) or (LEnd > FFrameCount) then
  begin
    Status('Enter a valid nonzero half-open source-frame interval.', True);
    Exit;
  end;
  LRequestDraft := FRequestDraft and not LQueued and not LGuided;
  if FCurrentLabels <> nil then
    for LIndex := 0 to FCurrentLabels.length - 1 do
      if (TextField(TJSObject(FCurrentLabels[LIndex]), 'label_id') =
        TextField(LChange, 'label_id')) and
        StructuredRow(TJSObject(FCurrentLabels[LIndex])) and
        not ((LGuided or LRequestDraft) and (FReviewSpec <> nil) and
          (TextField(TJSObject(FCurrentLabels[LIndex]),
            'request_sha256') = FReviewRequestHash)) then
      begin
        Status('This structured label cannot be saved through freeform authoring. Use its prepared request.', True);
        Exit;
      end;
  FSaveInProgress := True;
  UpdatePendingUi;
  UpdateRecordAnswerAction;
  try
    if LRequestDraft then
    begin
      LQueueResponse := await(TJSResponse,
        FetchApi('/api/review-queue', 'GET', ''));
      if LQueueResponse.status <> 200 then
        raise Exception.Create('Request check HTTP ' +
          IntToStr(LQueueResponse.status));
      LQueueData := await(TJSObject, LQueueResponse.json());
      LQueueItems := TJSArray(LQueueData['items']);
      LQueueRow := nil;
      if LQueueItems <> nil then
        for LQueueIndex := 0 to LQueueItems.length - 1 do
          if TextField(TJSObject(LQueueItems[LQueueIndex]), 'id') =
            FReviewId then
          begin
            LQueueRow := TJSObject(LQueueItems[LQueueIndex]);
            Break;
          end;
      if LQueueRow = nil then
      begin
        LQueueCompleted := TJSArray(LQueueData['completed']);
        LCompletion := nil;
        if LQueueCompleted <> nil then
          for LQueueIndex := 0 to LQueueCompleted.length - 1 do
            if TextField(TJSObject(LQueueCompleted[LQueueIndex]), 'id') =
              FReviewId then
            begin
              LCompletion := TJSObject(LQueueCompleted[LQueueIndex]);
              Break;
            end;
        if (LCompletion <> nil) and
          (TextField(LCompletion, 'source_sha256') = FSourceHash) and
          (TextField(LCompletion, 'request_sha256') =
            FReviewRequestHash) and
          (TextField(LCompletion, 'current_type') =
            TextField(LChange, 'type')) and
          (TextField(LCompletion, 'current_value') =
            TextField(LChange, 'value')) and
          (TextField(LCompletion, 'current_status') =
            TextField(LChange, 'status')) and
          (Trunc(NumberField(LCompletion, 'current_start_frame')) =
            LStart) and
          (Trunc(NumberField(LCompletion, 'current_end_frame')) =
            LEnd) then
        begin
          FQueueRefreshPending := True;
          FQueueAdvancePending := True;
          FQueueAdvanceIndex := 0;
          FQueuePostCommitPending := True;
          UpdatePendingUi;
          UpdateRecordAnswerAction;
          Status('This exact answer is already saved. No duplicate review event was recorded.');
          RefreshWindow;
          Exit;
        end;
      end;
      if (LQueueRow = nil) or not SelectedExactRequest or
        (TextField(LQueueRow, 'source_sha256') <> FSourceHash) or
        (Trunc(NumberField(LQueueRow, 'start_frame')) <> FReviewStart) or
        (Trunc(NumberField(LQueueRow, 'end_frame')) <> FReviewEnd) or
        (TextField(LQueueRow, 'question') <> FReviewQuestion) or
        (TextField(LQueueRow, 'label_type') <> FReviewType) or
        (ReviewGeometry(LQueueRow) <> FReviewGeometry) or
        (TextField(LQueueRow, 'request_sha256') <>
          FReviewRequestHash) or
        (TextField(LQueueRow, 'answer_conflict') <> '') then
        raise Exception.Create('Prepared request changed; select it again.');
      if (TextField(LQueueRow, 'current_type') =
          TextField(LChange, 'type')) and
        (TextField(LQueueRow, 'current_value') =
          TextField(LChange, 'value')) and
        (TextField(LQueueRow, 'current_status') =
          TextField(LChange, 'status')) and
        (Trunc(NumberField(LQueueRow, 'current_start_frame')) =
          LStart) and
        (Trunc(NumberField(LQueueRow, 'current_end_frame')) =
          LEnd) then
      begin
        FQueueRefreshPending := True;
        FQueueAdvancePending := False;
        FQueuePostCommitPending := True;
        Status('This exact answer is already saved. No duplicate review event was recorded.');
        RefreshWindow;
        Exit;
      end;
    end;
    LTransaction := TJSObject.new;
    if (FReviewSpec <> nil) and (LGuided or LRequestDraft) then
    begin
      LTransaction['version'] := 2;
      LTransaction['request_id'] := FReviewId;
      LTransaction['request_sha256'] := FReviewRequestHash;
    end
    else
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
      if (FReviewSpec <> nil) and (LGuided or LRequestDraft) then
        LEntry['request_sha256'] := FReviewRequestHash;
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
        if LGuided then
          FPresenceFeedback := 'Answer not saved: another review changed this source. Reload and try again.';
      end;
      UpdateRecordAnswerAction;
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
      if LGuided or LRequestDraft then
      begin
        FQueueRefreshPending := True;
        FQueuePostCommitPending := True;
        FQueueAdvancePending := LGuided or
          (TextField(LChange, 'status') = 'approved') or
          (TextField(LChange, 'status') = 'rejected');
        if FQueueAdvancePending then
        begin
          FQueueAdvanceIndex := 0;
          if FReviewQueue <> nil then
            for LIndex := 0 to FReviewQueue.length - 1 do
              if TextField(TJSObject(FReviewQueue[LIndex]), 'id') =
                TextField(LChange, 'label_id') then
              begin
                FQueueAdvanceIndex := LIndex;
                Break;
              end;
        end;
      end;
      if LGuided then
      begin
        FReviewCurrentValue := TextField(LChange, 'value');
        FReviewCurrentStatus := 'approved';
        FPresenceValue := '';
        FPresenceFeedback := 'Answer saved for this exact region.';
      end;
    end;
    UpdateRecordAnswerAction;
    RefreshWindow;
  except
    on LError: Exception do
    begin
      FSaveInProgress := False;
      UpdatePendingUi;
      UpdateRecordAnswerAction;
      Status('Review failed: ' + LError.Message, True);
      if LGuided then
      begin
        FPresenceFeedback := 'Answer not saved: ' + LError.Message;
        UpdateRecordAnswerAction;
      end;
    end;
  else
    FSaveInProgress := False;
    UpdatePendingUi;
    if LGuided then
      FPresenceFeedback := 'Review request failed; no new answer or correction was confirmed. Your choice is still selected.';
    UpdateRecordAnswerAction;
    Status('Review request failed. Reload current labels before trying again.', True);
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

function TWorkbench.HandleImport(AEvent: TJSMouseEvent): Boolean;
begin
  ImportAll;
  Result := False;
end;

function TWorkbench.HandleConnectRetry(AEvent: TJSMouseEvent): Boolean;
begin
  Start;
  Result := False;
end;

function TWorkbench.HandleTrack(AEvent: TJSMouseEvent): Boolean;
begin
  FQueueInitialSelectionDone := True;
  SelectTrack(StrToIntDef(
    TJSElement(AEvent.currentTarget).getAttribute('data-index'), -1));
  TJSHTMLElement(Element('track-title')).scrollIntoView;
  Result := False;
end;

procedure TWorkbench.RecordAnswer; async;
var
  LResponse: TJSResponse;
  LData: TJSObject;
  LRows: TJSArray;
  LRow: TJSObject;
  LHash: String;
  LId: String;
  LQuestion, LType, LGeometry: String;
  LRequestHash: String;
  LStart, LEnd: Int64;
  LEpoch: Integer;
  LIndex: Integer;
begin
  if StructuredGuided or
    ((FReviewSpec = nil) and
     ((FReviewType = 'presence') or (FReviewType = 'activity'))) then
    Exit;
  if not SelectedExactRequest or (FReviewConflict <> '') or
    FHistoryLoading or FHistoryLoadFailed or FSaveInProgress or
    ((FPendingChanges <> nil) and (FPendingChanges.length > 0)) then
  begin
    UpdateRecordAnswerAction;
    Exit;
  end;
  LHash := FSourceHash;
  LId := FReviewId;
  LQuestion := FReviewQuestion;
  LType := FReviewType;
  LGeometry := FReviewGeometry;
  LRequestHash := FReviewRequestHash;
  LStart := FReviewStart;
  LEnd := FReviewEnd;
  LEpoch := FWindowEpoch;
  try
    LResponse := await(TJSResponse, FetchApi('/api/review-queue', 'GET', ''));
    if (LEpoch <> FWindowEpoch) or not SelectedExactRequest or
      (LHash <> FSourceHash) or (LId <> FReviewId) or
      (LQuestion <> FReviewQuestion) or (LType <> FReviewType) or
      (LGeometry <> FReviewGeometry) or
      (LRequestHash <> FReviewRequestHash) or
      (LStart <> FReviewStart) or (LEnd <> FReviewEnd) then
      Exit;
    if LResponse.status <> 200 then
      raise Exception.Create('Could not verify the request (HTTP ' +
        IntToStr(LResponse.status) + ')');
    LData := await(TJSObject, LResponse.json());
    if (LEpoch <> FWindowEpoch) or not SelectedExactRequest or
      (LHash <> FSourceHash) or (LId <> FReviewId) or
      (LQuestion <> FReviewQuestion) or (LType <> FReviewType) or
      (LGeometry <> FReviewGeometry) or
      (LRequestHash <> FReviewRequestHash) or
      (LStart <> FReviewStart) or (LEnd <> FReviewEnd) then
      Exit;
    LRows := TJSArray(LData['items']);
    LRow := nil;
    for LIndex := 0 to LRows.length - 1 do
    begin
      if TextField(TJSObject(LRows[LIndex]), 'id') = LId then
      begin
        LRow := TJSObject(LRows[LIndex]);
        Break;
      end;
    end;
    if (LRow = nil) or (TextField(LRow, 'source_sha256') <> LHash) or
      (Trunc(NumberField(LRow, 'start_frame')) <> LStart) or
      (Trunc(NumberField(LRow, 'end_frame')) <> LEnd) or
      (TextField(LRow, 'label_type') <> LType) or
      (TextField(LRow, 'question') <> LQuestion) or
      (ReviewGeometry(LRow) <> LGeometry) or
      (TextField(LRow, 'request_sha256') <> LRequestHash) then
    begin
      ClearRequest;
      Status('This request changed. Select it again from the queue.', True);
      Exit;
    end;
    FReviewConflict := TextField(LRow, 'answer_conflict');
    if FReviewConflict <> '' then
    begin
      UpdateRecordAnswerAction;
      Exit;
    end;
    ReleaseRequestDraft;
    FRequestDraft := True;
    FSelectedLabel := -1;
    FDragMode := dmNone;
    Input('label-id').value := FReviewId;
    Input('label-type').value := FReviewType;
    UpdateValueHint;
    Input('label-value').value := '';
    Input('label-status').value := 'uncertain';
    Input('label-part').value := '';
    Input('label-start').value := IntToStr(FReviewStart);
    if FReviewGeometry = 'point' then
      Input('label-end').value := IntToStr(FReviewStart + 1)
    else
      Input('label-end').value := IntToStr(FReviewEnd);
    Input('label-pitch').value := '';
    Input('label-proposal').value := TextField(FReviewSpec,
      'proposal_id');
    if FReviewSpec <> nil then
    begin
      FillStructuredSelect('structured-value',
        TJSArray(FReviewSpec['vocabulary']));
      Input('label-value').setAttribute('hidden', '');
      Element('structured-value').removeAttribute('hidden');
      Input('label-part').value := '';
      Input('label-part').setAttribute('readonly', '');
      if isArray(FReviewSpec['part_vocabulary']) then
      begin
        FillStructuredSelect('structured-part',
          TJSArray(FReviewSpec['part_vocabulary']));
        Input('label-part').setAttribute('hidden', '');
        Element('structured-part').removeAttribute('hidden');
      end;
      if isArray(FReviewSpec['pitch_midi_values']) then
      begin
        FillStructuredSelect('structured-pitch',
          TJSArray(FReviewSpec['pitch_midi_values']));
        Input('label-pitch').setAttribute('hidden', '');
        Element('structured-pitch').removeAttribute('hidden');
      end;
      Input('label-proposal').setAttribute('readonly', '');
      Element('label-value-hint').textContent :=
        'Choose only from this request’s declared answer values.';
    end;
    Input('label-id').setAttribute('readonly', '');
    if FReviewGeometry = 'exact' then
    begin
      Input('label-start').setAttribute('readonly', '');
      Input('label-end').setAttribute('readonly', '');
      Element('request-geometry-help').setAttribute('hidden', '');
    end
    else
    begin
      Input('label-start').removeAttribute('readonly');
      Input('label-end').removeAttribute('readonly');
      if FReviewGeometry = 'point' then
      begin
        Element('request-geometry-help').textContent :=
          'Place one frame-wide point inside request frames ' +
          IntToStr(FReviewStart) + '–' + IntToStr(FReviewEnd) +
          '. Tap the reviewed waveform lane or edit Start frame; End frame must equal Start + 1.';
        FCanvas.setAttribute('aria-label',
          'Original WAV waveform; tap the reviewed lane to place a one-frame point')
      end
      else
        Element('request-geometry-help').textContent :=
          'Place this label entirely inside request frames ' +
          IntToStr(FReviewStart) + '–' + IntToStr(FReviewEnd) +
          '. Edit Start and End frames before saving.';
      Element('request-geometry-help').removeAttribute('hidden');
    end;
    if FReviewType <> '' then
      Element('label-type').setAttribute('disabled', '');
    Element('review-editor').setAttribute('open', '');
    TJSHTMLElement(Element('review-editor')).scrollIntoView;
    if FReviewGeometry = 'point' then
      Status('Tap the reviewed waveform lane to place the one-frame point, enter its value, choose Approved, then Save review event. Nothing is saved yet.')
    else if FReviewType = '' then
      Status('Choose a label type and enter your answer. Status is Uncertain until you choose Approved; then click Save review event.')
    else
      Status('Enter your answer. Status is Uncertain until you choose Approved; then click Save review event. Nothing has been saved yet.');
  except
    on LError: Exception do
      Status('Could not open this request draft: ' + LError.Message, True);
  end;
end;

procedure TWorkbench.SelectAssignment(const AIndex: Integer;
  const AScroll: Boolean);
var
  LIndex: Integer;
  LTrackIndex: Integer;
  LRow: TJSObject;
  LTrack: TJSObject;
begin
  if (FReviewQueue = nil) or (AIndex < 0) or
    (AIndex >= FReviewQueue.length) then
    Exit;
  LRow := TJSObject(FReviewQueue[AIndex]);
  LTrackIndex := -1;
  if FTracks <> nil then
    for LIndex := 0 to FTracks.length - 1 do
    begin
      LTrack := TJSObject(FTracks[LIndex]);
      if TextField(LTrack, 'source_sha256') =
        TextField(LRow, 'source_sha256') then
      begin
        LTrackIndex := LIndex;
        Break;
      end;
    end;
  if LTrackIndex < 0 then
  begin
    Status('The requested audio is not in this catalog.', True);
    Exit;
  end;
  SelectTrack(LTrackIndex,
    Trunc(NumberField(LRow, 'start_frame')),
    Trunc(NumberField(LRow, 'end_frame')),
    TextField(LRow, 'id'), TextField(LRow, 'question'),
    TextField(LRow, 'label_type'),
    TextField(LRow, 'answer_conflict'), ReviewGeometry(LRow),
    TextField(LRow, 'request_sha256'), ReviewSpec(LRow));
  if (FReviewId = TextField(LRow, 'id')) and
    (FSourceHash = TextField(LRow, 'source_sha256')) then
  begin
    FReviewCurrentValue := TextField(LRow, 'current_value');
    FReviewCurrentStatus := TextField(LRow, 'current_status');
    UpdateRecordAnswerAction;
  end;
  if AScroll then
    TJSHTMLElement(Element('track-title')).scrollIntoView;
end;

function TWorkbench.HandleAssignment(AEvent: TJSMouseEvent): Boolean;
begin
  FQueueInitialSelectionDone := True;
  SelectAssignment(StrToIntDef(
    TJSElement(AEvent.currentTarget).getAttribute('data-index'), -1),
    True);
  Result := False;
end;

function TWorkbench.HandleAlignedPeer(AEvent: TJSMouseEvent): Boolean;
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
  LPointFrame: Int64;
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
  if FRequestDraft and (FReviewGeometry = 'point') and
    SelectedExactRequest then
  begin
    LPointFrame := FrameAtX(LX);
    if LPointFrame >= FReviewEnd then
      LPointFrame := FReviewEnd - 1;
    if LPointFrame < FReviewStart then
      LPointFrame := FReviewStart;
    Input('label-start').value := IntToStr(LPointFrame);
    Input('label-end').value := IntToStr(LPointFrame + 1);
    FSelectedLabel := -1;
    FDragMode := dmNone;
    Status('Point placed at frame ' + IntToStr(LPointFrame) +
      '. Enter its value, choose Approved, then click Save review event.');
    DrawWaveform;
    AEvent.preventDefault;
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
    if StructuredRow(TJSObject(FCurrentLabels[LHit])) then
    begin
      Status('This structured answer is bound to its request and cannot be moved as a freeform label.', True);
      AEvent.preventDefault;
      Exit;
    end;
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
    if LEndX - LStartX <= 20 then
    begin
      // A frame-wide marker has overlapping edge handles; drag its position.
      FDragMode := dmMove;
    end
    else if Abs(LX - LStartX) <= 10 then
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
    ReleaseRequestDraft;
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
    UpdateValueHint;
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
    Element('review-editor').setAttribute('open', '');
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
  ReleaseRequestDraft;
  LFrames := TJSArray(LRow['frames']);
  FSelectedProposal := LIndex;
  TJSHTMLButtonElement(Element('load-cue-button')).disabled :=
    LFrames.length = 0;
  Element('load-cue-button').textContent :=
    'Play cue for grid ' + IntToStr(LIndex + 1);
  DrawWaveform;
  LFrame := FWindowStart;
  if LFrames.length > 0 then
  begin
    LFrame := Trunc(Double(LFrames[0]));
  end;
  Input('label-id').value := 'review-' + IntToStr(FReviewRevision + 1);
  Input('label-type').value := 'beat';
  UpdateValueHint;
  Input('label-value').value := 'candidate-grid-point';
  Input('label-status').value := 'uncertain';
  Input('label-start').value := IntToStr(LFrame);
  Input('label-end').value := IntToStr(LFrame + 1);
  Input('label-proposal').value := TextField(LRow, 'proposal_id');
  Element('review-editor').setAttribute('open', '');
  Element('review-next-step').textContent :=
    'Compare this Pythian suggestion with the original, then save a review decision if assigned.';
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
    ClearRequest;
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
    ClearRequest;
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
  ClearRequest;
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
    ClearRequest;
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
    ClearRequest;
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

function TWorkbench.HandleRecordAnswer(AEvent: TJSMouseEvent): Boolean;
begin
  RecordAnswer;
  Result := False;
end;

function TWorkbench.HandlePresenceChoice(AEvent: TJSMouseEvent): Boolean;
begin
  ChoosePresence(TJSElement(AEvent.currentTarget).getAttribute('data-value'));
  Result := False;
end;

function TWorkbench.HandlePresenceSave(AEvent: TJSMouseEvent): Boolean;
begin
  SavePresence;
  Result := False;
end;

function TWorkbench.HandleLabelTypeChange(AEvent: TEventListenerEvent): Boolean;
begin
  UpdateValueHint;
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
  if StructuredRow(LTarget) or not RowMatchesSource(LTarget) or
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
  FAudio.onloadedmetadata := @HandleAudioMetadata;
  FAudio.onended := @HandleAudioEnded;
  FAudio.onerror := @HandleAudioError;
  TJSHTMLButtonElement(Element('connect-retry')).onclick :=
    @HandleConnectRetry;
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
  TJSHTMLButtonElement(Element('record-answer-button')).onclick :=
    @HandleRecordAnswer;
  Element('presence-audible').setAttribute('data-value', 'audible');
  Element('presence-rest').setAttribute('data-value', 'rest');
  Element('presence-unknown').setAttribute('data-value', 'unknown');
  TJSHTMLButtonElement(Element('presence-audible')).onclick :=
    @HandlePresenceChoice;
  TJSHTMLButtonElement(Element('presence-rest')).onclick :=
    @HandlePresenceChoice;
  TJSHTMLButtonElement(Element('presence-unknown')).onclick :=
    @HandlePresenceChoice;
  Element('activity-attack').setAttribute('data-value', 'attack');
  Element('activity-continuation').setAttribute('data-value', 'continuation');
  Element('activity-release_tail').setAttribute('data-value', 'release_tail');
  Element('activity-rest').setAttribute('data-value', 'rest');
  Element('activity-unknown').setAttribute('data-value', 'unknown');
  Element('activity-noise_only').setAttribute('data-value', 'noise_only');
  TJSHTMLButtonElement(Element('activity-attack')).onclick := @HandlePresenceChoice;
  TJSHTMLButtonElement(Element('activity-continuation')).onclick := @HandlePresenceChoice;
  TJSHTMLButtonElement(Element('activity-release_tail')).onclick := @HandlePresenceChoice;
  TJSHTMLButtonElement(Element('activity-rest')).onclick := @HandlePresenceChoice;
  TJSHTMLButtonElement(Element('activity-unknown')).onclick := @HandlePresenceChoice;
  TJSHTMLButtonElement(Element('activity-noise_only')).onclick := @HandlePresenceChoice;
  TJSHTMLButtonElement(Element('presence-save')).onclick :=
    @HandlePresenceSave;
  TJSHTMLInputElement(Element('label-type')).onchange := @HandleLabelTypeChange;
  UpdateValueHint;
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
  window.addEventListener('pageshow', @HandlePageShow);
  DrawWaveform;
  Start;
end;

var
  Workbench: TWorkbench;
begin
  Workbench := TWorkbench.Create;
  Workbench.Run;
end.
