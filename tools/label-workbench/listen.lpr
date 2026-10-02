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
program PythianFullOutputListener;

{$mode delphi}
{$H+}
{$modeswitch externalclass}

uses JS, Web, SysUtils, pythian.workspace.navigation;

type
  TListenerWindow = class external name 'Window' (TJSWindow)
    function fetch(const AUrl: String; const AOptions: TJSObject): TJSPromise;
      reintroduce;
  end;

  TListenerTimeRanges = class external name 'TimeRanges' (TJSObject)
    length: NativeInt;
    function finish(const AIndex: NativeInt): Double; external name 'end';
    function start(const AIndex: NativeInt): Double;
  end;

  TListenerAudioElement = class external name 'HTMLAudioElement' (TJSHTMLAudioElement)
  private
    FBufferedRanges: TListenerTimeRanges; external name 'buffered';
  public
    property BufferedRanges: TListenerTimeRanges read FBufferedRanges;
  end;

  TListener = class
  private
    FNavigation: TWorkspaceNavigation;
    FToken: String;
    FPending: TJSArray;
    FCompleted: TJSArray;
    FRequest: TJSObject;
    FComments: TJSArray;
    FAudioPlayers: TJSArray;
    FAudioFailures: TJSArray;
    FAudioReady: TJSArray;
    FSelectedId: String;
    FSelectedPending: Boolean;
    FSelectedIndex: Integer;
    FSaving: Boolean;
    FLoading: Boolean;
    FQueueLoads: Integer;
    FLoadingStage: String;
    FLoadingSince: NativeInt;
    FLoadingTimer: NativeInt;
    FLoadEpoch: Integer;
    function El(const AId: String): TJSElement;
    function FetchApi(const APath, AMethod, ABody: String): TJSPromise;
    function FetchNavigation(const APath, AMethod, ABody: String;
      const ASignal: TJSObject): TJSPromise;
    procedure Status(const AText: String; const AError: Boolean = False);
    procedure UpdateLoading;
    procedure Feedback(const AText: String; const AError: Boolean = False);
    procedure Clear(const AId: String);
    procedure PauseAudioPlayers;
    function CurrentAudioIndex(const AAudio: TJSHTMLAudioElement): Integer;
    function AnyAudioFailure: Boolean;
    function AllAudioReady: Boolean;
    procedure UpdateReviewGate;
    function AddText(const AParent: TJSElement; const ATag,
      AText, AClass: String): TJSElement;
    procedure AddOption(const ASelect: TJSHTMLSelectElement;
      const AText, AValue: String);
    procedure DrawQueue;
    procedure DrawPacket;
    procedure DrawComments;
    procedure ApplyQueue(const AData: TJSObject;
      const APreferred: String; const AAdvance: Boolean);
    procedure SelectRow(const AId: String);
    function FindRow(const AItems: TJSArray; const AId: String): TJSObject;
    function BuildTransaction: TJSObject;
    function SameSaved(const ARow, ATransaction: TJSObject): Boolean;
    function FrameAllowed(const AAssetId: String; const AFrame: Int64): Boolean;
    procedure Connect; async;
    procedure LoadQueue(const APreferred: String = ''; const AAdvance: Boolean = False); async;
    procedure Save; async;
    function HandlePageShow(AEvent: TEventListenerEvent): Boolean;
    function HandleRetry(AEvent: TJSMouseEvent): Boolean;
    function HandleReload(AEvent: TJSMouseEvent): Boolean;
    function HandleSelect(AEvent: TJSMouseEvent): Boolean;
    function HandleRange(AEvent: TJSMouseEvent): Boolean;
    function HandleAddComment(AEvent: TJSMouseEvent): Boolean;
    function HandleRemoveComment(AEvent: TJSMouseEvent): Boolean;
    function HandleSave(AEvent: TJSMouseEvent): Boolean;
    function HandleReset(AEvent: TJSMouseEvent): Boolean;
    function HandleAudioMetadata(AEvent: TEventListenerEvent): Boolean;
    function HandleAudioLoadStart(AEvent: TJSLoadEvent): Boolean;
    function HandleAudioWaiting(AEvent: TEventListenerEvent): Boolean;
    function HandleAudioProgress(AEvent: TEventListenerEvent): Boolean;
    function HandleAudioPlaying(AEvent: TEventListenerEvent): Boolean;
    function HandleAudioError(AEvent: TJSErrorEvent): Boolean;
    function HandleAudioPlay(AEvent: TJSPointerEvent): Boolean;
  public
    procedure Run;
  end;

function Obj(const AValue: JSValue): TJSObject;
begin
  Result := TJSObject(AValue);
end;

function Arr(const AObject: TJSObject; const AName: String): TJSArray;
begin
  Result := nil;
  if AObject <> nil then
    if isArray(AObject[AName]) then
      Result := TJSArray(AObject[AName]);
end;

function Str(const AObject: TJSObject; const AName: String): String;
begin
  Result := '';
  if (AObject <> nil) and isString(AObject[AName]) then
    Result := String(AObject[AName]);
end;

function Num(const AObject: TJSObject; const AName: String): Double;
begin
  Result := 0;
  if (AObject <> nil) and isNumber(AObject[AName]) then
    Result := Double(AObject[AName]);
end;

function Cloned(const AValue: JSValue): JSValue;
begin
  Result := TJSJSON.parse(TJSJSON.stringify(AValue));
end;

function Detail(const AText, AToken: String): String;
var
  I: Integer;
begin
  Result := Trim(Copy(StringReplace(AText, AToken, '[redacted]',
    [rfReplaceAll]), 1, 160));
  for I := 1 to Length(Result) do
    if Ord(Result[I]) < 32 then Result[I] := ' ';
end;

function AnswerCaption(const AValue: String): String;
begin
  case AValue of
    'style_fit': Result := 'Style match';
    'does_not_fit': Result := 'Does not fit';
    'unknown': Result := 'I can’t tell';
  else
    Result := StringReplace(AValue, '_', ' ', [rfReplaceAll]);
    if Result <> '' then Result[1] := UpCase(Result[1]);
  end;
end;

function PacketTitle(const ARow: TJSObject): String;
var
  LQuestion: String;
begin
  Result := Str(ARow, 'title');
  if Result <> '' then
    Exit;
  LQuestion := LowerCase(Str(ARow, 'question'));
  if Str(ARow, 'kind') = 'pair' then
  begin
    if Pos('playback', LQuestion) > 0 then
      Result := 'Check playback of two recordings'
    else
      Result := 'Compare two recordings';
  end
  else if Pos('full', LQuestion) > 0 then
    Result := 'Review a complete recording'
  else
    Result := 'Review one recording';
end;

function AssetName(const AAsset: TJSObject): String;
begin
  if Str(AAsset, 'role') = 'source' then
    Result := 'Original recording'
  else if Str(AAsset, 'id') = 'pythian_beat_cue' then
    Result := 'Pythian beat cue'
  else if Str(AAsset, 'role') = 'generated' then
    Result := 'Pythian generated recording'
  else if Str(AAsset, 'role') = 'edited' then
    Result := 'Edited recording'
  else
    Result := StringReplace(Str(AAsset, 'id'), '_', ' ', [rfReplaceAll]);
end;

function TListener.El(const AId: String): TJSElement;
begin
  Result := document.getElementById(AId);
  if Result = nil then raise Exception.Create('Missing control ' + AId);
end;

function TListener.FetchApi(const APath, AMethod, ABody: String): TJSPromise;
begin
  Result := FetchNavigation(APath, AMethod, ABody, nil);
end;

function TListener.FetchNavigation(const APath, AMethod, ABody: String;
  const ASignal: TJSObject): TJSPromise;
var
  LOptions, LHeaders: TJSObject;
begin
  LOptions := TJSObject.new;
  LHeaders := TJSObject.new;
  LOptions['method'] := AMethod;
  LOptions['mode'] := 'same-origin';
  { Only session setup needs cookies; other API routes use the token header. }
  if APath = '/api/session' then
  begin
    LOptions['credentials'] := 'same-origin';
  end
  else
  begin
    LOptions['credentials'] := 'omit';
  end;
  LOptions['redirect'] := 'error';
  LOptions['cache'] := 'no-store';
  LOptions['referrerPolicy'] := 'no-referrer';
  if ASignal <> nil then LOptions['signal'] := ASignal;
  if FToken <> '' then LHeaders['X-Pythian-Token'] := FToken;
  if ABody <> '' then
  begin
    LHeaders['Content-Type'] := 'application/json';
    LOptions['body'] := ABody;
  end;
  LOptions['headers'] := LHeaders;
  Result := TListenerWindow(window).fetch(window.location.origin + APath,
    LOptions);
  if (AMethod = 'POST') and (APath = '/api/listen-review') then
  begin
    Result := Result._then(@WorkspaceResponseSaved);
  end;
end;

procedure TListener.Status(const AText: String; const AError: Boolean);
begin
  El('status').textContent := AText;
  if AText = '' then
    El('status').setAttribute('hidden', '')
  else
    El('status').removeAttribute('hidden');
  if AError then El('status').setAttribute('class', 'status error')
  else El('status').setAttribute('class', 'status');
end;

procedure TListener.UpdateLoading;
var
  LStage, LText: String;
begin
  LStage := '';
  if FLoading then LStage := 'connection'
  else if FQueueLoads > 0 then LStage := 'queue';
  if LStage <> FLoadingStage then
  begin
    FLoadingStage := LStage;
    FLoadingSince := TJSDate.now;
  end;
  if LStage = '' then
  begin
    if FLoadingTimer <> 0 then window.clearTimeout(FLoadingTimer);
    FLoadingTimer := 0;
    El('loading-progress').setAttribute('hidden', '');
    Exit;
  end;
  if LStage = 'connection' then
    LText := 'Connecting to local service'
  else
    LText := 'Loading listening queue';
  LText := LText + ' · ' +
    IntToStr((TJSDate.now - FLoadingSince) div 1000) + ' s';
  El('loading-progress-text').textContent := LText;
  El('loading-progress').setAttribute('aria-label', LText);
  El('loading-progress').setAttribute('aria-valuetext', LText);
  El('loading-progress').removeAttribute('hidden');
  if FLoadingTimer = 0 then
    FLoadingTimer := window.setTimeout(
      procedure()
      begin
        FLoadingTimer := 0;
        UpdateLoading;
      end, 1000);
end;

procedure TListener.Feedback(const AText: String; const AError: Boolean);
begin
  El('feedback').textContent := AText;
  if AError then El('feedback').setAttribute('class', 'error')
  else El('feedback').removeAttribute('class');
end;

procedure TListener.Clear(const AId: String);
begin
  El(AId).textContent := '';
end;

procedure TListener.PauseAudioPlayers;
var
  I: Integer;
begin
  if FAudioPlayers = nil then Exit;
  for I := 0 to FAudioPlayers.length - 1 do
    TJSHTMLAudioElement(FAudioPlayers[I]).pause;
end;

function TListener.CurrentAudioIndex(
  const AAudio: TJSHTMLAudioElement): Integer;
var
  I: Integer;
begin
  Result := -1;
  for I := 0 to FAudioPlayers.length - 1 do
    if TJSHTMLAudioElement(FAudioPlayers[I]) = AAudio then
      Exit(I);
end;

function TListener.AnyAudioFailure: Boolean;
var
  I: Integer;
begin
  Result := False;
  if FAudioFailures = nil then Exit;
  for I := 0 to FAudioFailures.length - 1 do
    if FAudioFailures[I] = True then Exit(True);
end;

function TListener.AllAudioReady: Boolean;
var
  I: Integer;
begin
  Result := (FAudioReady <> nil) and (FAudioReady.length > 0);
  if not Result then Exit;
  for I := 0 to FAudioReady.length - 1 do
    if FAudioReady[I] <> True then Exit(False);
end;

procedure TListener.UpdateReviewGate;
var
  I, LReady: Integer;
begin
  LReady := 0;
  for I := 0 to FAudioReady.length - 1 do
    if FAudioReady[I] = True then Inc(LReady);
  if AnyAudioFailure then
    El('media-gate').textContent :=
      'A recording could not play. Try Play again before saving your response.'
  else if not AllAudioReady then
    El('media-gate').textContent := IntToStr(LReady) + ' of ' +
      IntToStr(FAudioReady.length) +
      ' recordings ready. Press Play on each recording before answering.'
  else
    El('media-gate').textContent :=
      'Audio is ready. Listen, then share your response below.';
  if AllAudioReady and not AnyAudioFailure then
    El('answer').removeAttribute('hidden')
  else
    El('answer').setAttribute('hidden', '');
  TJSHTMLButtonElement(El('save')).disabled :=
    FSaving or AnyAudioFailure or not AllAudioReady;
end;

function TListener.AddText(const AParent: TJSElement; const ATag,
  AText, AClass: String): TJSElement;
begin
  Result := document.createElement(ATag);
  Result.textContent := AText;
  if AClass <> '' then Result.setAttribute('class', AClass);
  AParent.appendChild(Result);
end;

procedure TListener.AddOption(const ASelect: TJSHTMLSelectElement;
  const AText, AValue: String);
var
  LOption: TJSHTMLOptionElement;
begin
  LOption := TJSHTMLOptionElement(TJSHTMLOptionElement.New(AText, AValue));
  ASelect.add(LOption);
end;

function TListener.FindRow(const AItems: TJSArray; const AId: String): TJSObject;
var
  I: Integer;
begin
  Result := nil;
  if AItems = nil then Exit;
  for I := 0 to AItems.length - 1 do
    if Str(Obj(AItems[I]), 'id') = AId then Exit(Obj(AItems[I]));
end;

procedure TListener.DrawQueue;
var
  I: Integer;
  LRow: TJSObject;
  LButton: TJSHTMLButtonElement;
  LParent: TJSElement;
  LQuestion: String;
begin
  Clear('pending');
  Clear('completed');
  El('progress').textContent := IntToStr(FPending.length) + ' waiting · ' +
    IntToStr(FCompleted.length) + ' completed';
  if (FPending.length = 0) and (FCompleted.length = 0) then
    El('queue-title').textContent := 'No listening reviews assigned'
  else if FPending.length = 0 then
    El('queue-title').textContent := 'All listening reviews complete'
  else if FPending.length = 1 then
    El('queue-title').textContent := '1 listening review needs attention'
  else
    El('queue-title').textContent := IntToStr(FPending.length) +
      ' listening reviews need attention';
  for I := 0 to FPending.length + FCompleted.length - 1 do
  begin
    if I < FPending.length then
    begin
      LRow := Obj(FPending[I]);
      LParent := El('pending');
    end
    else
    begin
      LRow := Obj(FCompleted[I - FPending.length]);
      LParent := El('completed');
    end;
    LButton := TJSHTMLButtonElement(document.createElement('button'));
    LButton.setAttribute('type', 'button');
    LButton.setAttribute('data-id', Str(LRow, 'id'));
    AddText(LButton, 'strong', PacketTitle(LRow), '');
    LQuestion := Str(LRow, 'question');
    if Length(LQuestion) > 140 then
      LQuestion := Copy(LQuestion, 1, 137) + '…';
    AddText(LButton, 'small', LQuestion, '');
    if Str(LRow, 'id') = FSelectedId then
      LButton.setAttribute('class', 'selected');
    LButton.onclick := @HandleSelect;
    LParent.appendChild(LButton);
  end;
  if FPending.length = 0 then
    AddText(El('pending'), 'p', 'No listening reviews are waiting.',
      'muted');
  if FCompleted.length = 0 then
    AddText(El('completed'), 'p', 'No saved responses yet.', 'muted');
end;

procedure TListener.DrawComments;
var
  I: Integer;
  LRow: TJSObject;
  LWrap: TJSElement;
  LButton: TJSHTMLButtonElement;
begin
  Clear('comments');
  for I := 0 to FComments.length - 1 do
  begin
    LRow := Obj(FComments[I]);
    LWrap := AddText(El('comments'), 'div',
      Str(LRow, 'asset_id') + ' @ frame ' +
      IntToStr(Trunc(Num(LRow, 'frame'))) + ': ' + Str(LRow, 'text'),
      'comment');
    LButton := TJSHTMLButtonElement(document.createElement('button'));
    LButton.setAttribute('type', 'button');
    LButton.setAttribute('data-index', IntToStr(I));
    LButton.textContent := 'Remove';
    LButton.onclick := @HandleRemoveComment;
    LWrap.appendChild(LButton);
  end;
end;

procedure TListener.DrawPacket;
var
  LAssets, LRanges, LChoices, LScores, LSaved, LSourceHashes: TJSArray;
  LAsset, LRange, LDimension, LAnswer, LProvenance: TJSObject;
  LCard, LSelect, LLabel, LDetails: TJSElement;
  LOption: TJSHTMLSelectElement;
  LAudio: TJSHTMLAudioElement;
  LButton: TJSHTMLButtonElement;
  LId: String;
  LAssetName: String;
  LRate: Integer;
  LStartSeconds, LEndSeconds: Integer;
  I, J, K: Integer;
begin
  PauseAudioPlayers;
  FAudioPlayers := TJSArray.new;
  FAudioFailures := TJSArray.new;
  FAudioReady := TJSArray.new;
  if FRequest = nil then
  begin
    El('packet').setAttribute('hidden', '');
    El('empty').removeAttribute('hidden');
    Exit;
  end;
  El('empty').setAttribute('hidden', '');
  El('packet').removeAttribute('hidden');
  if FSelectedPending then
    El('task').textContent := 'LISTENING REVIEW ' +
      IntToStr(FSelectedIndex + 1) + ' OF ' + IntToStr(FPending.length)
  else
    El('task').textContent := 'COMPLETED LISTENING REVIEW';
  El('packet-title').textContent := PacketTitle(FRequest);
  El('question').textContent := Str(FRequest, 'question');
  El('identity').textContent := 'Task ' + Str(FRequest, 'task_id') +
    ' · packet ' + Str(FRequest, 'id') +
    ' · revision ' + IntToStr(Trunc(Num(FRequest, 'revision'))) +
    ' · exact request ' + Copy(Str(FRequest, 'request_sha256'), 1, 12);
  Clear('assets'); Clear('ranges'); Clear('choices'); Clear('scores');
  TJSHTMLSelectElement(El('comment-asset')).innerHTML := '';
  LAssets := Arr(FRequest, 'assets');
  for I := 0 to LAssets.length - 1 do
  begin
    LAsset := Obj(LAssets[I]);
    LId := Str(LAsset, 'id');
    LAssetName := AssetName(LAsset);
    LCard := AddText(El('assets'), 'div', '', 'asset');
    AddText(LCard, 'strong', LAssetName, '');
    if Num(LAsset, 'sample_rate') > 0 then
      AddText(LCard, 'small',
        IntToStr(Round(Num(LAsset, 'frames') /
          Num(LAsset, 'sample_rate'))) + ' seconds', 'muted');
    LDetails := AddText(LCard, 'details', '', 'asset-technical');
    AddText(LDetails, 'summary', 'Audio details', '');
    AddText(LDetails, 'p', LId + ' · ' + Str(LAsset, 'storage') + ' · ' +
      IntToStr(Trunc(Num(LAsset, 'frames'))) + ' frames · ' +
      IntToStr(Trunc(Num(LAsset, 'sample_rate'))) + ' Hz', 'muted');
    if ((Str(LAsset, 'role') = 'generated') or
      (Str(LAsset, 'role') = 'edited')) and
      isObject(LAsset['provenance']) then
    begin
      LProvenance := Obj(LAsset['provenance']);
      LSourceHashes := Arr(LProvenance, 'source_sha256s');
      if (LSourceHashes <> nil) and (LSourceHashes.length > 1) then
        AddText(LDetails, 'small', IntToStr(LSourceHashes.length) +
          ' source recordings', 'muted');
    end;
    LAudio := TJSHTMLAudioElement(document.createElement('audio'));
    LAudio.id := 'audio-' + IntToStr(I);
    LAudio.controls := True;
    LAudio.preload := 'none';
    LAudio.src := window.location.origin + '/api/listen-audio?request=' +
      Str(FRequest, 'id') + '&asset=' + LId + '&packet=' +
      Str(FRequest, 'request_sha256');
    LAudio.onloadedmetadata := @HandleAudioMetadata;
    LAudio.onloadstart := @HandleAudioLoadStart;
    LAudio.onwaiting := @HandleAudioWaiting;
    LAudio.addEventListener('progress', @HandleAudioProgress);
    LAudio.oncanplay := @HandleAudioPlaying;
    LAudio.onerror := @HandleAudioError;
    LAudio.onplay := @HandleAudioPlay;
    LCard.appendChild(LAudio);
    FAudioPlayers.push(LAudio);
    FAudioFailures.push(False);
    FAudioReady.push(False);
    LSelect := AddText(LCard, 'span', 'Tap Play to load this WAV.',
      'media-state');
    LSelect.id := 'media-state-' + IntToStr(I);
    LSelect.setAttribute('role', 'status');
    LSelect.setAttribute('aria-live', 'polite');
    AddOption(TJSHTMLSelectElement(El('comment-asset')), LAssetName, LId);
  end;
  LRanges := Arr(FRequest, 'ranges');
  for I := 0 to LRanges.length - 1 do
  begin
    LRange := Obj(LRanges[I]);
    LButton := TJSHTMLButtonElement(document.createElement('button'));
    LButton.setAttribute('type', 'button');
    LButton.setAttribute('data-asset', Str(LRange, 'asset_id'));
    LButton.setAttribute('data-frame',
      IntToStr(Trunc(Num(LRange, 'start_frame'))));
    LAssetName := Str(LRange, 'asset_id');
    LRate := 0;
    for K := 0 to LAssets.length - 1 do
      if Str(Obj(LAssets[K]), 'id') = Str(LRange, 'asset_id') then
      begin
        LAssetName := AssetName(Obj(LAssets[K]));
        LRate := Trunc(Num(Obj(LAssets[K]), 'sample_rate'));
        Break;
      end;
    if LRate > 0 then
    begin
      LStartSeconds := Trunc(Num(LRange, 'start_frame') / LRate);
      LEndSeconds := Round(Num(LRange, 'end_frame') / LRate);
      LButton.textContent := 'Seek ' + LAssetName + ': ' +
        IntToStr(LStartSeconds) + '–' + IntToStr(LEndSeconds) + ' s';
    end
    else
      LButton.textContent := 'Seek ' + LAssetName;
    LButton.onclick := @HandleRange;
    El('ranges').appendChild(LButton);
  end;
  if FComments = nil then FComments := TJSArray.new;
  DrawComments;
  LChoices := Arr(Obj(FRequest['answer_spec']), 'choices');
  LScores := Arr(Obj(FRequest['answer_spec']), 'scores');
  for I := 0 to LChoices.length - 1 do
  begin
    LDimension := Obj(LChoices[I]);
    LLabel := AddText(El('choices'), 'label',
      AnswerCaption(Str(LDimension, 'id')), 'dimension');
    LOption := TJSHTMLSelectElement(document.createElement('select'));
    LOption.id := 'choice-' + IntToStr(I);
    AddOption(LOption, 'Choose an answer', '');
    LSaved := Arr(FRequest, 'current_choices');
    for J := 0 to Arr(LDimension, 'values').length - 1 do
      AddOption(LOption, AnswerCaption(String(Arr(LDimension, 'values')[J])),
        String(Arr(LDimension, 'values')[J]));
    if LSaved <> nil then
      for J := 0 to LSaved.length - 1 do
      begin
        LAnswer := Obj(LSaved[J]);
        if Str(LAnswer, 'id') = Str(LDimension, 'id') then
          LOption.value := Str(LAnswer, 'value');
      end;
    LLabel.appendChild(LOption);
  end;
  for I := 0 to LScores.length - 1 do
  begin
    LDimension := Obj(LScores[I]);
    LLabel := AddText(El('scores'), 'label',
      AnswerCaption(Str(LDimension, 'id')) + ' (0–3)',
      'dimension');
    LOption := TJSHTMLSelectElement(document.createElement('select'));
    LOption.id := 'score-' + IntToStr(I);
    AddOption(LOption, 'Choose a score', '');
    for J := 0 to 3 do AddOption(LOption, IntToStr(J), IntToStr(J));
    AddOption(LOption, 'I can’t tell', 'unknown');
    LSaved := Arr(FRequest, 'current_scores');
    if LSaved <> nil then
      for J := 0 to LSaved.length - 1 do
      begin
        LAnswer := Obj(LSaved[J]);
        if Str(LAnswer, 'id') = Str(LDimension, 'id') then
        begin
          if isString(LAnswer['value']) then
            LOption.value := String(LAnswer['value'])
          else LOption.value := IntToStr(Trunc(Double(LAnswer['value'])));
        end;
      end;
    LLabel.appendChild(LOption);
  end;
  if FSelectedPending then Feedback('Answer each question, then press Save response.')
  else Feedback('Saved response loaded. You may submit an explicit correction.');
  UpdateReviewGate;
end;

procedure TListener.SelectRow(const AId: String);
var
  I: Integer;
begin
  FRequest := FindRow(FPending, AId);
  FSelectedPending := FRequest <> nil;
  FSelectedIndex := -1;
  if FSelectedPending then
    for I := 0 to FPending.length - 1 do
      if Str(Obj(FPending[I]), 'id') = AId then FSelectedIndex := I;
  if FRequest = nil then FRequest := FindRow(FCompleted, AId);
  FSelectedId := '';
  FComments := TJSArray.new;
  if FRequest <> nil then
  begin
    FSelectedId := AId;
    if Arr(FRequest, 'current_comments') <> nil then
      FComments := TJSArray(Cloned(Arr(FRequest, 'current_comments')));
  end;
  DrawQueue;
  DrawPacket;
end;

procedure TListener.ApplyQueue(const AData: TJSObject;
  const APreferred: String; const AAdvance: Boolean);
var
  LNext: String;
begin
  FPending := Arr(AData, 'items');
  FCompleted := Arr(AData, 'completed');
  if (FPending = nil) or (FCompleted = nil) then
    raise Exception.Create('Listening queue shape is invalid');
  LNext := APreferred;
  if AAdvance and (FPending.length = 0) then LNext := '';
  if AAdvance and (FPending.length > 0) then
  begin
    if FSelectedIndex < 0 then FSelectedIndex := 0;
    if FSelectedIndex >= FPending.length then
      FSelectedIndex := FPending.length - 1;
    LNext := Str(Obj(FPending[FSelectedIndex]), 'id');
  end;
  if (FindRow(FPending, LNext) = nil) and
    (FindRow(FCompleted, LNext) = nil) then
  begin
    if (APreferred <> '') and not AAdvance then
    begin
      SelectRow('');
      El('empty').textContent := 'This listening review is unavailable. Choose another review below.';
      Exit;
    end;
    LNext := '';
    if FPending.length > 0 then LNext := Str(Obj(FPending[0]), 'id');
  end;
  SelectRow(LNext);
  if AAdvance then
  begin
    if FRequest <> nil then
      TJSHTMLElement(El('packet-title')).focus
    else
      TJSHTMLElement(El('queue-title')).focus;
  end;
  if (FPending.length = 0) and (LNext = '') then
    El('empty').textContent :=
      'All listening reviews are complete. Open a completed response below to review it.';
end;

function TListener.FrameAllowed(const AAssetId: String;
  const AFrame: Int64): Boolean;
var
  LRanges: TJSArray;
  I: Integer;
  LRow: TJSObject;
begin
  Result := False;
  LRanges := Arr(FRequest, 'ranges');
  for I := 0 to LRanges.length - 1 do
  begin
    LRow := Obj(LRanges[I]);
    if (Str(LRow, 'asset_id') = AAssetId) and
      (AFrame >= Trunc(Num(LRow, 'start_frame'))) and
      (AFrame < Trunc(Num(LRow, 'end_frame'))) then Exit(True);
  end;
end;

function TListener.BuildTransaction: TJSObject;
var
  LSpec, LDimension, LAnswer: TJSObject;
  LChoices, LScores, LDeclared: TJSArray;
  LValue: String;
  I: Integer;
begin
  Result := TJSObject.new;
  Result['version'] := 1;
  Result['request_id'] := FSelectedId;
  Result['request_sha256'] := Str(FRequest, 'request_sha256');
  Result['expected_revision'] := Trunc(Num(FRequest, 'revision'));
  Result['reviewer'] := 'operator';
  Result['status'] := 'submitted';
  LChoices := TJSArray.new;
  LScores := TJSArray.new;
  LSpec := Obj(FRequest['answer_spec']);
  LDeclared := Arr(LSpec, 'choices');
  for I := 0 to LDeclared.length - 1 do
  begin
    LDimension := Obj(LDeclared[I]);
    LValue := TJSHTMLSelectElement(El('choice-' + IntToStr(I))).value;
    if LValue = '' then
      raise Exception.Create('Choose ' + Str(LDimension, 'id') + '.');
    LAnswer := TJSObject.new;
    LAnswer['id'] := Str(LDimension, 'id');
    LAnswer['value'] := LValue;
    LChoices.push(LAnswer);
  end;
  LDeclared := Arr(LSpec, 'scores');
  for I := 0 to LDeclared.length - 1 do
  begin
    LDimension := Obj(LDeclared[I]);
    LValue := TJSHTMLSelectElement(El('score-' + IntToStr(I))).value;
    if LValue = '' then
      raise Exception.Create('Choose score ' + Str(LDimension, 'id') + '.');
    LAnswer := TJSObject.new;
    LAnswer['id'] := Str(LDimension, 'id');
    if LValue = 'unknown' then LAnswer['value'] := 'unknown'
    else LAnswer['value'] := StrToInt(LValue);
    LScores.push(LAnswer);
  end;
  Result['choices'] := LChoices;
  Result['scores'] := LScores;
  Result['comments'] := Cloned(FComments);
end;

function TListener.SameSaved(const ARow, ATransaction: TJSObject): Boolean;
begin
  Result := (Str(ARow, 'current_status') = 'submitted') and
    (TJSJSON.stringify(Arr(ARow, 'current_choices')) =
      TJSJSON.stringify(Arr(ATransaction, 'choices'))) and
    (TJSJSON.stringify(Arr(ARow, 'current_scores')) =
      TJSJSON.stringify(Arr(ATransaction, 'scores'))) and
    (TJSJSON.stringify(Arr(ARow, 'current_comments')) =
      TJSJSON.stringify(Arr(ATransaction, 'comments')));
end;

procedure TListener.Connect; async;
var
  LResponse: TJSResponse;
  LData: TJSObject;
  LEpoch: Integer;
  LTimer: NativeInt;
begin
  if FLoading then Exit;
  FLoading := True;
  Inc(FLoadEpoch);
  LEpoch := FLoadEpoch;
  FToken := '';
  UpdateLoading;
  Status('Connecting to local service…');
  El('retry').setAttribute('hidden', '');
  LTimer := window.setTimeout(
    procedure()
    begin
      if (LEpoch = FLoadEpoch) and (FToken = '') then
      begin
        Inc(FLoadEpoch);
        FLoading := False;
        UpdateLoading;
        Status('Connection is taking too long. Check this device’s network and retry.', True);
        FNavigation.ConnectionFailed;
        El('retry').removeAttribute('hidden');
      end;
    end, 10000);
  try
    LResponse := await(TJSResponse, FetchApi('/api/session', 'GET', ''));
    if LEpoch <> FLoadEpoch then Exit;
    if LResponse.status <> 200 then
      raise Exception.Create('Session HTTP ' + IntToStr(LResponse.status));
    LData := await(TJSObject, LResponse.json());
    if LEpoch <> FLoadEpoch then Exit;
    FToken := Str(LData, 'token');
    if FToken = '' then raise Exception.Create('Session token missing');
    FNavigation.Start;
    El('workspace').removeAttribute('hidden');
    Status('Connected. Loading listening packets…');
    LoadQueue(FSelectedId);
  except
    on E: Exception do
    begin
      if LEpoch = FLoadEpoch then
      begin
        Status('Connection failed: ' + E.Message, True);
        FNavigation.ConnectionFailed;
        El('retry').removeAttribute('hidden');
      end;
    end;
  else
    begin
      if LEpoch = FLoadEpoch then
      begin
        Status('Connection failed in this browser.', True);
        FNavigation.ConnectionFailed;
        El('retry').removeAttribute('hidden');
      end;
    end;
  end;
  window.clearTimeout(LTimer);
  if LEpoch = FLoadEpoch then
  begin
    FLoading := False;
    UpdateLoading;
  end;
end;

procedure TListener.LoadQueue(const APreferred: String;
  const AAdvance: Boolean); async;
var
  LResponse: TJSResponse;
  LData: TJSObject;
begin
  if FToken = '' then begin Connect; Exit; end;
  Inc(FQueueLoads);
  UpdateLoading;
  Status('Loading listening packets…');
  try
    try
      LResponse := await(TJSResponse, FetchApi('/api/listen-queue', 'GET', ''));
      if LResponse.status <> 200 then
        raise Exception.Create('Queue HTTP ' + IntToStr(LResponse.status));
      LData := await(TJSObject, LResponse.json());
      ApplyQueue(LData, APreferred, AAdvance);
      Status('');
    except
      on E: Exception do Status('Queue load failed: ' + E.Message +
        '. Use Reload queue.', True);
    else Status('Queue load failed in this browser. Use Reload queue.', True);
    end;
  finally
    Dec(FQueueLoads);
    UpdateLoading;
  end;
end;

function TListener.HandlePageShow(AEvent: TEventListenerEvent): Boolean;
begin
  Result := False;
  if (FToken <> '') and isBoolean(TJSObject(AEvent)['persisted']) and
    Boolean(TJSObject(AEvent)['persisted']) then
    LoadQueue(FSelectedId);
end;

procedure TListener.Save; async;
var
  LTransaction, LQueueData, LCurrent, LData: TJSObject;
  LResponse: TJSResponse;
  LReason: String;
  LAdvance: Boolean;
begin
  if FSaving or (FRequest = nil) then Exit;
  if AnyAudioFailure or not AllAudioReady then
  begin
    Feedback('Every declared WAV must load in this browser before saving. Retry playback or reload the queue.', True);
    Exit;
  end;
  try
    LTransaction := BuildTransaction;
  except
    on E: Exception do begin Feedback(E.Message, True); Exit; end;
  end;
  FSaving := True;
  TJSHTMLButtonElement(El('save')).disabled := True;
  LAdvance := FSelectedPending;
  Feedback('Checking the current request before saving…');
  try
    try
    LResponse := await(TJSResponse, FetchApi('/api/listen-queue', 'GET', ''));
    if LResponse.status <> 200 then
    begin
      LReason := Detail(await(String, LResponse.text()), FToken);
      raise Exception.Create('Request check HTTP ' +
        IntToStr(LResponse.status) + ': ' + LReason);
    end;
    LQueueData := await(TJSObject, LResponse.json());
    LCurrent := FindRow(Arr(LQueueData, 'items'), FSelectedId);
    if LCurrent = nil then
      LCurrent := FindRow(Arr(LQueueData, 'completed'), FSelectedId);
    if (LCurrent = nil) or
      (Str(LCurrent, 'request_sha256') <>
        Str(LTransaction, 'request_sha256')) then
      raise Exception.Create('Request changed or disappeared. Reload the queue before saving.');
    if SameSaved(LCurrent, LTransaction) then
    begin
      ApplyQueue(LQueueData, FSelectedId, LAdvance);
      Feedback('This exact response was already saved. No new event was written.');
      Exit;
    end;
    if Trunc(Num(LCurrent, 'revision')) <>
      Trunc(Num(LTransaction, 'expected_revision')) then
      raise Exception.Create('Request revision changed. Reload the queue before correcting it.');
    Feedback('Saving response…');
    LResponse := await(TJSResponse, FetchApi('/api/listen-review', 'POST',
      TJSJSON.stringify(LTransaction)));
    if LResponse.status <> 200 then
    begin
      LReason := Detail(await(String, LResponse.text()), FToken);
      raise Exception.Create('Save HTTP ' + IntToStr(LResponse.status) +
        ': ' + LReason);
    end;
    LData := await(TJSObject, LResponse.json());
    FRequest['revision'] := LData['revision'];
    Feedback('Response saved. Loading the next packet…');
    LResponse := await(TJSResponse, FetchApi('/api/listen-queue', 'GET', ''));
    if LResponse.status <> 200 then
      raise Exception.Create('Saved, but queue refresh HTTP ' +
        IntToStr(LResponse.status) + '. Use Reload queue.');
    LQueueData := await(TJSObject, LResponse.json());
    ApplyQueue(LQueueData, FSelectedId, LAdvance);
    Feedback('Response saved.');
    Status('Response saved. Queue refreshed.');
    except
      on E: Exception do Feedback(E.Message +
        ' Your selections remain. Retry Save to reconcile before any new write.', True);
    else Feedback('Save or request check failed in this browser. Your selections remain; retry Save to reconcile.', True);
    end;
  finally
    FSaving := False;
    UpdateReviewGate;
  end;
end;

function TListener.HandleRetry(AEvent: TJSMouseEvent): Boolean;
begin Connect; Result := False; end;

function TListener.HandleReload(AEvent: TJSMouseEvent): Boolean;
begin if not FSaving then LoadQueue(FSelectedId); Result := False; end;

function TListener.HandleSelect(AEvent: TJSMouseEvent): Boolean;
begin
  if not FSaving then
  begin
    SelectRow(TJSElement(AEvent.currentTarget).getAttribute('data-id'));
    TJSHTMLElement(El('packet-title')).focus;
  end;
  Result := False;
end;

function TListener.HandleRange(AEvent: TJSMouseEvent): Boolean;
var
  LAssetId: String;
  LAssets: TJSArray;
  I: Integer;
  LAudio: TJSHTMLAudioElement;
begin
  LAssetId := TJSElement(AEvent.currentTarget).getAttribute('data-asset');
  LAssets := Arr(FRequest, 'assets');
  for I := 0 to LAssets.length - 1 do
    if Str(Obj(LAssets[I]), 'id') = LAssetId then
    begin
      LAudio := TJSHTMLAudioElement(El('audio-' + IntToStr(I)));
      LAudio.currentTime := StrToInt64Def(
        TJSElement(AEvent.currentTarget).getAttribute('data-frame'), 0) /
        Num(Obj(LAssets[I]), 'sample_rate');
      TJSHTMLSelectElement(El('comment-asset')).value := LAssetId;
      Break;
    end;
  Result := False;
end;

function TListener.HandleAddComment(AEvent: TJSMouseEvent): Boolean;
var
  LAssets: TJSArray;
  LId, LText: String;
  LFrame: Int64;
  LRow: TJSObject;
  I: Integer;
begin
  LId := TJSHTMLSelectElement(El('comment-asset')).value;
  LText := Trim(TJSHTMLInputElement(El('comment-text')).value);
  if LText = '' then begin Feedback('Enter a comment first.', True); Exit(False); end;
  LAssets := Arr(FRequest, 'assets');
  for I := 0 to LAssets.length - 1 do
    if Str(Obj(LAssets[I]), 'id') = LId then
    begin
      LFrame := Trunc(TJSHTMLAudioElement(El('audio-' + IntToStr(I))).currentTime *
        Num(Obj(LAssets[I]), 'sample_rate'));
      if not FrameAllowed(LId, LFrame) then
      begin
        Feedback('Choose a moment inside the requested clip before adding your comment.', True);
        Exit(False);
      end;
      LRow := TJSObject.new;
      LRow['asset_id'] := LId;
      LRow['frame'] := LFrame;
      LRow['text'] := LText;
      FComments.push(LRow);
      TJSHTMLInputElement(El('comment-text')).value := '';
      DrawComments;
      Feedback('Timestamped comment staged. Save response to keep it.');
      Exit(False);
    end;
  Feedback('Choose a recording for your comment.', True);
  Result := False;
end;

function TListener.HandleRemoveComment(AEvent: TJSMouseEvent): Boolean;
var
  LIndex: Integer;
begin
  LIndex := StrToIntDef(TJSElement(AEvent.currentTarget).
    getAttribute('data-index'), -1);
  if (LIndex >= 0) and (LIndex < FComments.length) then
  begin
    FComments.splice(LIndex, 1);
    DrawComments;
    Feedback('Comment removed from the unsaved response.');
  end;
  Result := False;
end;

function TListener.HandleSave(AEvent: TJSMouseEvent): Boolean;
begin Save; Result := False; end;

function TListener.HandleReset(AEvent: TJSMouseEvent): Boolean;
begin if not FSaving then LoadQueue(FSelectedId); Result := False; end;

function TListener.HandleAudioMetadata(AEvent: TEventListenerEvent): Boolean;
var
  LAudio: TJSHTMLAudioElement;
  LIndex: Integer;
begin
  LAudio := TJSHTMLAudioElement(AEvent.currentTarget);
  LIndex := CurrentAudioIndex(LAudio);
  if LIndex < 0 then Exit(False);
  if (LIndex >= 0) and (LIndex < FAudioFailures.length) then
  begin
    FAudioFailures[LIndex] := False;
    FAudioReady[LIndex] := False;
  end;
  UpdateReviewGate;
  El('media-state-' + Copy(LAudio.id, 7, MaxInt)).textContent :=
    'WAV metadata loaded · ' + FormatFloat('0.0', LAudio.duration) +
    ' seconds. Waiting for playable audio.';
  El('media-state-' + Copy(LAudio.id, 7, MaxInt)).setAttribute(
    'class', 'media-state');
  Result := False;
end;

function TListener.HandleAudioLoadStart(AEvent: TJSLoadEvent): Boolean;
var
  LAudio: TJSHTMLAudioElement;
begin
  LAudio := TJSHTMLAudioElement(AEvent.currentTarget);
  if CurrentAudioIndex(LAudio) < 0 then Exit(False);
  El('media-state-' + Copy(LAudio.id, 7, MaxInt)).textContent :=
    'Loading WAV audio…';
  El('media-state-' + Copy(LAudio.id, 7, MaxInt)).setAttribute(
    'class', 'media-state busy');
  Result := False;
end;

function TListener.HandleAudioWaiting(AEvent: TEventListenerEvent): Boolean;
var
  LAudio: TJSHTMLAudioElement;
begin
  LAudio := TJSHTMLAudioElement(AEvent.currentTarget);
  if CurrentAudioIndex(LAudio) < 0 then Exit(False);
  El('media-state-' + Copy(LAudio.id, 7, MaxInt)).textContent :=
    'Loading WAV audio…';
  El('media-state-' + Copy(LAudio.id, 7, MaxInt)).setAttribute(
    'class', 'media-state busy');
  Result := False;
end;

function TListener.HandleAudioProgress(AEvent: TEventListenerEvent): Boolean;
var
  LAudio: TJSHTMLAudioElement;
  LRanges: TListenerTimeRanges;
  LBuffered: Double;
  LPercent, I: Integer;
begin
  LAudio := TJSHTMLAudioElement(AEvent.currentTarget);
  if CurrentAudioIndex(LAudio) < 0 then Exit(False);
  LRanges := TListenerAudioElement(LAudio).BufferedRanges;
  if (LRanges = nil) or (LRanges.length = 0) or
    (LAudio.duration <= 0) or (LAudio.duration > 1000000000) then
    Exit(False);
  LBuffered := 0;
  for I := 0 to LRanges.length - 1 do
    LBuffered := LBuffered + LRanges.finish(I) - LRanges.start(I);
  LPercent := Trunc(LBuffered * 100 / LAudio.duration);
  if LPercent > 100 then LPercent := 100;
  if LPercent < 0 then LPercent := 0;
  if LPercent < 100 then
  begin
    El('media-state-' + Copy(LAudio.id, 7, MaxInt)).textContent :=
      'WAV buffered: ' + IntToStr(LPercent) + '% of its duration. Playback can start before 100%.';
    El('media-state-' + Copy(LAudio.id, 7, MaxInt)).setAttribute(
      'class', 'media-state busy');
  end;
  Result := False;
end;

function TListener.HandleAudioPlaying(AEvent: TEventListenerEvent): Boolean;
var
  LAudio: TJSHTMLAudioElement;
  LIndex: Integer;
begin
  LAudio := TJSHTMLAudioElement(AEvent.currentTarget);
  LIndex := CurrentAudioIndex(LAudio);
  if LIndex < 0 then Exit(False);
  if (LIndex >= 0) and (LIndex < FAudioFailures.length) then
  begin
    FAudioFailures[LIndex] := False;
    FAudioReady[LIndex] := True;
  end;
  UpdateReviewGate;
  El('media-state-' + Copy(LAudio.id, 7, MaxInt)).textContent :=
    'WAV ready to play · ' + FormatFloat('0.0', LAudio.duration) +
    ' seconds total.';
  El('media-state-' + Copy(LAudio.id, 7, MaxInt)).setAttribute(
    'class', 'media-state');
  Result := False;
end;

function TListener.HandleAudioError(AEvent: TJSErrorEvent): Boolean;
var
  LAudio: TJSHTMLAudioElement;
  LCode: Integer;
  LIndex: Integer;
begin
  LAudio := TJSHTMLAudioElement(AEvent.currentTarget);
  LIndex := CurrentAudioIndex(LAudio);
  if LIndex < 0 then Exit(False);
  if (LIndex >= 0) and (LIndex < FAudioFailures.length) then
  begin
    FAudioFailures[LIndex] := True;
    FAudioReady[LIndex] := False;
  end;
  UpdateReviewGate;
  LCode := 0;
  if LAudio.error <> nil then LCode := LAudio.error.code;
  El('media-state-' + Copy(LAudio.id, 7, MaxInt)).textContent :=
    'WAV playback failed in this browser (media error ' +
    IntToStr(LCode) + '). Reload the queue or report this packet ID.';
  El('media-state-' + Copy(LAudio.id, 7, MaxInt)).setAttribute(
    'class', 'media-state error');
  Status('WAV playback failed for ' + FSelectedId + '.', True);
  Result := False;
end;

function TListener.HandleAudioPlay(AEvent: TJSPointerEvent): Boolean;
var
  I: Integer;
begin
  if CurrentAudioIndex(TJSHTMLAudioElement(AEvent.currentTarget)) < 0 then
    Exit(False);
  for I := 0 to FAudioPlayers.length - 1 do
    if TJSHTMLAudioElement(FAudioPlayers[I]).id <>
      TJSHTMLAudioElement(AEvent.currentTarget).id then
      TJSHTMLAudioElement(FAudioPlayers[I]).pause;
  Result := False;
end;

procedure TListener.Run;
var
  LRequested: JSValue;
begin
  FNavigation := TWorkspaceNavigation.Create(@FetchNavigation, 'listening');
  FPending := TJSArray.new;
  FCompleted := TJSArray.new;
  FComments := TJSArray.new;
  FAudioPlayers := TJSArray.new;
  FAudioFailures := TJSArray.new;
  FAudioReady := TJSArray.new;
  FSelectedIndex := -1;
  LRequested := TJSURLSearchParams.new(window.location.search).get('request');
  if isString(LRequested) then FSelectedId := String(LRequested);
  TJSHTMLButtonElement(El('retry')).onclick := @HandleRetry;
  TJSHTMLButtonElement(El('reload')).onclick := @HandleReload;
  TJSHTMLButtonElement(El('save')).onclick := @HandleSave;
  TJSHTMLButtonElement(El('reset')).onclick := @HandleReset;
  TJSHTMLButtonElement(El('add-comment')).onclick := @HandleAddComment;
  window.addEventListener('pageshow', @HandlePageShow);
  Connect;
end;

var Listener: TListener;
begin
  Listener := TListener.Create;
  Listener.Run;
end.
