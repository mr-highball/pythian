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
program PythianStudio;
{$mode delphi}
{$H+}
{$modeswitch externalclass}
uses JS, Web, SysUtils, Math,
  pythian.studio.sources, pythian.studio.capture, pythian.studio.effects,
  pythian.studio.requests, pythian.studio.&library.refresh;

type
  TStudioWindow = class external name 'Window' (TJSWindow)
    function fetch(const AUrl: String; const AOptions: TJSObject): TJSPromise; reintroduce;
  end;
  TStudio = class
  private
    FTracks, FSelections, FProjects: TJSArray;
    FSourceEditor: TStudioSourceEditor;
    FCapture: TStudioCapture;
    FEffects: TStudioEffects;
    FLibraryRefresh: TStudioLibraryRefresh;
    FToken, FProjectId, FName: String;
    FRevision, FChanges, FPendingVersion: Integer;
    FConnected, FLoading, FSaving, FDirty: Boolean;
    FSaveTimer: NativeInt;
    FPendingWrite: TJSObject;
    function El(const AId: String): TJSElement;
    function FetchApi(const APath, AMethod, ABody: String): TJSPromise;
    function FetchNavigation(const APath, AMethod, ABody: String;
      const ASignal: TJSObject): TJSPromise;
    function Json(const APath, AMethod, ABody: String): TJSObject; async;
    procedure Connect; async;
    procedure CatalogSaved;
    procedure MergeDiscovery(ATracks: TJSArray; ADiscovery, APrepared: TJSObject);
    procedure Draw;
    procedure DrawProjects;
    procedure BindSelectedTracks;
    procedure ShowStep(const AStep: String);
    procedure Changed;
    procedure QueueSave;
    procedure Remember;
    procedure Save; async;
    function BuildWrite: TJSObject;
    function Playlist: TJSObject;
    procedure ApplyPlaylist(APlaylist: TJSObject);
    procedure OpenProject(const AId: String); async;
    procedure LoadProject(AProject: TJSObject);
    procedure AddSelection(ASelection: TJSObject);
    procedure NewPlaylist;
    procedure SaveCopy;
    procedure Notice(const AText: String; const AError: Boolean = False);
    function Click(AEvent: TJSMouseEvent): Boolean;
    function Edit(AEvent: TEventListenerEvent): Boolean;
    function Playing(AEvent: TEventListenerEvent): Boolean;
    function Leaving(AEvent: TEventListenerEvent): Boolean;
    function CaptureClosed(AEvent: TEventListenerEvent): Boolean;
    function TabKey(AEvent: TJSKeyboardEvent): Boolean;
  public
    procedure Run;
  end;
function Obj(AValue: JSValue): TJSObject;
begin
  Result := nil;
  if isObject(AValue) and not isArray(AValue) then Result := TJSObject(AValue);
end;
function Str(AObject: TJSObject; const AName: String): String;
begin Result := StudioText(AObject, AName) end;
function Num(AObject: TJSObject; const AName: String): Double;
begin Result := StudioNumber(AObject, AName) end;
function Arr(AObject: TJSObject; const AName: String): TJSArray;
begin
  Result := nil;
  if (AObject <> nil) and isArray(AObject[AName]) then Result := TJSArray(AObject[AName]);
end;
function CloneObject(AObject: TJSObject): TJSObject;
begin Result := Obj(TJSJSON.parse(TJSJSON.stringify(AObject))) end;
function TStudio.El(const AId: String): TJSElement;
begin Result := document.getElementById(AId) end;
function Add(AParent: TJSElement; const ATag, AText: String): TJSElement;
begin
  Result := document.createElement(ATag);
  Result.textContent := AText;
  AParent.appendChild(Result);
end;
function TStudio.FetchApi(const APath, AMethod, ABody: String): TJSPromise;
begin Result := FetchNavigation(APath, AMethod, ABody, nil) end;
function TStudio.FetchNavigation(const APath, AMethod, ABody: String;
  const ASignal: TJSObject): TJSPromise;
var LOptions, LHeaders: TJSObject;
begin
  LOptions := TJSObject.new;
  LHeaders := TJSObject.new;
  LOptions['method'] := AMethod;
  LOptions['mode'] := 'same-origin';
  LOptions['credentials'] := 'omit';
  if APath = '/api/session' then LOptions['credentials'] := 'same-origin';
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
  Result := TStudioWindow(window).fetch(window.location.origin + APath, LOptions);
end;
function TStudio.Json(const APath, AMethod, ABody: String): TJSObject; async;
var LResponse: TJSResponse; LValue: TJSObject;
begin
  LResponse := TJSResponse(await(JSValue, AwaitStudioPromise(FetchApi(APath, AMethod, ABody), 20)));
  LValue := await(TJSObject, LResponse.json());
  if LResponse.status <> 200 then
  begin
    if LResponse.status = 409 then
      raise Exception.Create('Playlist changed or storage is busy. Retry shortly, or save a new copy. Your edits are kept.');
    raise Exception.Create('Could not complete this request. ' + Str(LValue, 'error'));
  end;
  Result := LValue;
end;
procedure TStudio.Notice(const AText: String; const AError: Boolean);
begin
  El('connection-state').textContent := AText;
  El('connection-state').className := 'hint';
  if AError then El('connection-state').className := 'field-error';
end;
procedure TStudio.ShowStep(const AStep: String);
var LName: String; LNames: array of String;
begin
  LNames := ['library', 'selection', 'generate'];
  for LName in LNames do
  begin
    if LName = AStep then
    begin
      El('step-' + LName).removeAttribute('hidden');
      El('tab-' + LName).setAttribute('aria-selected', 'true');
      El('tab-' + LName).setAttribute('tabindex', '0');
    end
    else
    begin
      El('step-' + LName).setAttribute('hidden', '');
      El('tab-' + LName).setAttribute('aria-selected', 'false');
      El('tab-' + LName).setAttribute('tabindex', '-1');
    end;
  end;
end;
procedure TStudio.NewPlaylist;
begin
  FProjectId := 'playlist-' + IntToStr(Round(TJSDate.now)) + '-' + IntToStr(Random(1000000));
  FRevision := 0;
  FSelections := TJSArray.new;
  FName := 'My playlist';
  FDirty := False;
  FPendingWrite := nil;
  TJSHTMLInputElement(El('playlist-name')).value := FName;
  FSourceEditor.Reset;
  QueueSave;
end;
procedure TStudio.Remember;
var LState: TJSObject;
begin
  LState := TJSObject.new;
  LState['project_id'] := FProjectId;
  LState['revision'] := FRevision;
  LState['name'] := FName;
  LState['selections'] := FSelections;
  LState['dirty'] := FDirty;
  LState['changes'] := FChanges;
  LState['pending_version'] := FPendingVersion;
  LState['pending_write'] := FPendingWrite;
  try
    window.localStorage.setItem('pythian.studio.playlist', TJSJSON.stringify(LState));
  except
    on E: Exception do Notice('Browser storage is unavailable. Keep this page open until Saved appears.', True);
  end;
end;
procedure TStudio.Changed;
begin
  QueueSave;
  Draw;
end;
procedure TStudio.QueueSave;
begin
  Inc(FChanges);
  FDirty := True;
  FName := Trim(TJSHTMLInputElement(El('playlist-name')).value);
  if FName = '' then FName := 'My playlist';
  Remember;
  El('save-state').textContent := 'Saving…';
  window.clearTimeout(FSaveTimer);
  FSaveTimer := window.setTimeout(procedure begin Save end, 500);
end;
function TStudio.Playlist: TJSObject;
var
  LItems, LClips, LClasses: TJSArray;
  LRow, LItem, LClip, LOther: TJSObject;
  I, J: Integer;
begin
  Result := TJSObject.new;
  Result['format'] := 'pythian.studio.playlist.v1';
  LItems := TJSArray.new;
  Result['items'] := LItems;
  for I := 0 to FSelections.length - 1 do
  begin
    LRow := Obj(FSelections[I]);
    if Str(LRow, 'selection') <> 'full' then Continue;
    LItem := TJSObject.new;
    LItem['kind'] := 'catalog';
    LItem['id'] := Str(LRow, 'source_sha256');
    LItem['snapshot_sha256'] := Str(LRow, 'metadata_sha256');
    LItem['discovery_revision'] := 0;
    if Str(LRow, 'entry_id') <> '' then
    begin
      LItem['kind'] := 'library';
      LItem['id'] := Str(LRow, 'entry_id');
      LItem['snapshot_sha256'] := Str(LRow, 'entry_snapshot_sha256');
      LItem['discovery_revision'] := Num(LRow, 'discovery_revision');
    end;
    LItem['title'] := Str(LRow, 'title');
    LItem['sample_rate'] := Num(LRow, 'sample_rate');
    LItem['frame_count'] := Num(LRow, 'frame_count');
    LItem['influence'] := Max(1, Num(LRow, 'influence'));
    LItem['extent'] := 'clips';
    if StudioIncluded(LRow) then LItem['extent'] := 'whole';
    LClips := TJSArray.new;
    LItem['clips'] := LClips;
    for J := 0 to FSelections.length - 1 do
    begin
      LOther := Obj(FSelections[J]);
      if (StudioSourceKey(LOther) <> StudioSourceKey(LRow)) or
        (Str(LOther, 'selection') = 'full') then Continue;
      LClip := TJSObject.new;
      LClip['start_frame'] := Num(LOther, 'start_frame');
      LClip['end_frame'] := Num(LOther, 'end_frame');
      LClip['included'] := StudioIncluded(LOther);
      LClasses := Arr(LOther, 'classifications');
      if LClasses = nil then LClasses := TJSArray.new;
      LClip['classifications'] := LClasses;
      LClips.push(LClip);
    end;
    LItems.push(LItem);
  end;
end;
function TStudio.BuildWrite: TJSObject;
begin
  Result := TJSObject.new;
  Result['format'] := 'pythian.studio.project.write.v1';
  Result['project_id'] := FProjectId;
  Result['expected_revision'] := FRevision;
  Result['name'] := FName;
  Result['style_intent'] := '';
  Result['learning_mode'] := 'instrumental';
  Result['sources'] := TJSArray.new;
  Result['playlist'] := Playlist;
end;
procedure TStudio.Save; async;
var LSaved: TJSObject; LVersion, I: Integer; LFound: Boolean;
begin
  if FSaving or FLoading or not FConnected or (not FDirty and (FPendingWrite = nil)) then Exit;
  FSaving := True;
  if FPendingWrite = nil then
  begin
    FPendingWrite := BuildWrite;
    FPendingVersion := FChanges;
  end;
  LVersion := FPendingVersion;
  Remember;
  try
    LSaved := await(TJSObject, Json('/api/studio/project', 'POST', TJSJSON.stringify(FPendingWrite)));
    if (Str(LSaved, 'project_id') <> FProjectId) or
      not SameStudioJSON(LSaved['playlist'], FPendingWrite['playlist']) or
      (Num(LSaved, 'revision') <> Num(FPendingWrite, 'expected_revision') + 1) then
      raise Exception.Create('Save returned a different playlist. Your edits are kept.');
    FRevision := Trunc(Num(LSaved, 'revision'));
    LFound := False;
    for I := 0 to FProjects.length - 1 do
      if Str(Obj(FProjects[I]), 'project_id') = FProjectId then
      begin FProjects[I] := LSaved; LFound := True; Break end;
    if not LFound then FProjects.push(LSaved);
    DrawProjects;
    FPendingWrite := nil;
    FDirty := FChanges <> LVersion;
    El('save-state').textContent := 'Saved';
    El('retry-save').setAttribute('hidden', '');
    Remember;
  except
    on E: Exception do
    begin
      El('save-state').textContent := 'Not saved — edits kept on this device';
      El('retry-save').removeAttribute('hidden');
      Notice(E.Message, True);
      if Pos('Playlist changed or storage is busy.', E.Message) = 1 then
        El('save-copy').removeAttribute('hidden');
    end;
  end;
  FSaving := False;
  TJSHTMLButtonElement(El('new-playlist')).disabled := FDirty or (FPendingWrite <> nil);
  if (FPendingWrite = nil) and FDirty then Save;
end;
procedure TStudio.SaveCopy;
begin
  if FSaving or FLoading then Exit;
  FProjectId := 'playlist-' + IntToStr(Round(TJSDate.now)) + '-' + IntToStr(Random(1000000));
  FRevision := 0;
  FPendingWrite := nil;
  El('save-copy').setAttribute('hidden', '');
  QueueSave;
  Save;
end;
procedure TStudio.BindSelectedTracks;
var LRow, LTrack: TJSObject; I, J, LFound: Integer;
begin
  for I := 0 to FSelections.length - 1 do
  begin
    LRow := Obj(FSelections[I]);
    if Str(LRow, 'selection') <> 'full' then Continue;
    LFound := -1;
    for J := 0 to FTracks.length - 1 do
      if (StudioSourceKey(Obj(FTracks[J])) = StudioSourceKey(LRow)) or
        ((Str(LRow, 'source_sha256') <> '') and
        (Str(Obj(FTracks[J]), 'source_sha256') = Str(LRow, 'source_sha256'))) then
      begin LFound := J; Break end;
    if LFound >= 0 then LTrack := CloneObject(Obj(FTracks[LFound]))
    else LTrack := CloneObject(LRow);
    { Saved source identity wins over a later discovery scan. Generation must
      verify that exact choice rather than quietly learning changed bytes. }
    LTrack['entry_id'] := Str(LRow, 'entry_id');
    LTrack['entry_snapshot_sha256'] := Str(LRow, 'entry_snapshot_sha256');
    LTrack['discovery_revision'] := Num(LRow, 'discovery_revision');
    LTrack['source_sha256'] := Str(LRow, 'source_sha256');
    LTrack['metadata_sha256'] := Str(LRow, 'metadata_sha256');
    LTrack['title'] := Str(LRow, 'title');
    LTrack['sample_rate'] := Num(LRow, 'sample_rate');
    LTrack['frame_count'] := Num(LRow, 'frame_count');
    if LFound >= 0 then FTracks[LFound] := LTrack else FTracks.push(LTrack);
  end;
end;
procedure TStudio.DrawProjects;
var I: Integer; LButton: TJSElement;
begin
  El('playlist-list').innerHTML := '';
  for I := 0 to FProjects.length - 1 do
  begin
    LButton := Add(El('playlist-list'), 'button', Str(Obj(FProjects[I]), 'name'));
    LButton.setAttribute('type', 'button');
    LButton.setAttribute('data-project', Str(Obj(FProjects[I]), 'project_id'));
    LButton.addEventListener('click', @Click);
  end;
end;
procedure TStudio.Draw;
var
  LItem, LOther: TJSObject;
  LRow, LLabel, LControl: TJSElement;
  I, J, LCount: Integer;
  LSeconds: Double;
  LWhole: Boolean;
begin
  BindSelectedTracks;
  FSourceEditor.Bind(FTracks, FSelections, not FConnected or FLoading);
  LCount := 0;
  LSeconds := 0;
  El('track-influences').innerHTML := '';
  for I := 0 to FSelections.length - 1 do
  begin
    LItem := Obj(FSelections[I]);
    if Str(LItem, 'selection') <> 'full' then Continue;
    Inc(LCount);
    LWhole := StudioIncluded(LItem);
    if LWhole then LSeconds := LSeconds + Num(LItem, 'frame_count') / Num(LItem, 'sample_rate')
    else
      for J := 0 to FSelections.length - 1 do
      begin
        LOther := Obj(FSelections[J]);
        if (StudioSourceKey(LOther) = StudioSourceKey(LItem)) and
          (Str(LOther, 'selection') <> 'full') and StudioIncluded(LOther) then
          LSeconds := LSeconds + (Num(LOther, 'end_frame') - Num(LOther, 'start_frame')) / Num(LItem, 'sample_rate');
      end;
    LRow := Add(El('track-influences'), 'label', '');
    LRow.className := 'influence-row';
    LLabel := Add(LRow, 'span', Str(LItem, 'title'));
    LControl := Add(LRow, 'input', '');
    LControl.setAttribute('type', 'range');
    LControl.setAttribute('min', '1');
    LControl.setAttribute('max', '16');
    LControl.setAttribute('step', '1');
    LControl.setAttribute('data-influence', IntToStr(I));
    TJSHTMLInputElement(LControl).value := FloatToStr(Max(1, Num(LItem, 'influence')));
    LControl.addEventListener('change', @Edit);
    Add(LRow, 'output', FloatToStr(Max(1, Num(LItem, 'influence'))) + '×');
  end;
  El('selection-count').textContent := IntToStr(LCount);
  El('selection-summary').textContent := IntToStr(LCount) + ' tracks · ' + StudioTime(LSeconds) + ' selected for learning';
  El('generate-summary').textContent := El('selection-summary').textContent;
  TJSHTMLInputElement(El('track-search')).disabled := not FConnected;
  TJSHTMLButtonElement(El('new-playlist')).disabled := FLoading or FSaving or FDirty or (FPendingWrite <> nil);
  TJSHTMLInputElement(El('playlist-name')).disabled := FLoading;
end;
procedure TStudio.AddSelection(ASelection: TJSObject);
var LTrack, LRow: TJSObject; I: Integer;
begin
  LRow := CloneObject(ASelection);
  for I := 0 to FTracks.length - 1 do
  begin
    LTrack := Obj(FTracks[I]);
    if Str(LTrack, 'source_sha256') <> Str(LRow, 'source_sha256') then Continue;
    LRow['title'] := Str(LTrack, 'title');
    LRow['sample_rate'] := Num(LTrack, 'sample_rate');
    LRow['frame_count'] := Num(LTrack, 'frame_count');
    LRow['metadata_sha256'] := Str(LTrack, 'metadata_sha256');
    LRow['entry_id'] := '';
    LRow['influence'] := 1;
    Break;
  end;
  FSelections.push(LRow);
end;
procedure TStudio.ApplyPlaylist(APlaylist: TJSObject);
var
  LItems, LClips: TJSArray;
  LItem, LTrack, LRow, LClip: TJSObject;
  I, J: Integer;
begin
  FSelections := TJSArray.new;
  LItems := Arr(APlaylist, 'items');
  if (Str(APlaylist, 'format') <> 'pythian.studio.playlist.v1') or (LItems = nil) then
    raise Exception.Create('This playlist format is unavailable.');
  for I := 0 to LItems.length - 1 do
  begin
    LItem := Obj(LItems[I]);
    LTrack := TJSObject.new;
    LTrack['source_sha256'] := '';
    LTrack['entry_id'] := '';
    if Str(LItem, 'kind') = 'catalog' then
    begin
      LTrack['source_sha256'] := Str(LItem, 'id');
      LTrack['metadata_sha256'] := Str(LItem, 'snapshot_sha256');
    end
    else
    begin
      LTrack['entry_id'] := Str(LItem, 'id');
      LTrack['entry_snapshot_sha256'] := Str(LItem, 'snapshot_sha256');
      LTrack['discovery_revision'] := Num(LItem, 'discovery_revision');
    end;
    LTrack['title'] := Str(LItem, 'title');
    LTrack['sample_rate'] := Num(LItem, 'sample_rate');
    LTrack['frame_count'] := Num(LItem, 'frame_count');
    LTrack['status'] := 'available';
    LTrack['collections'] := TJSArray.new;
    LRow := CloneObject(LTrack);
    LRow['selection'] := 'full';
    LRow['included'] := Str(LItem, 'extent') = 'whole';
    LRow['start_frame'] := 0;
    LRow['end_frame'] := Num(LItem, 'frame_count');
    LRow['influence'] := Num(LItem, 'influence');
    LRow['classifications'] := TJSArray.new;
    FSelections.push(LRow);
    LClips := Arr(LItem, 'clips');
    for J := 0 to LClips.length - 1 do
    begin
      LClip := CloneObject(LTrack);
      LClip['selection'] := 'range';
      LClip['start_frame'] := Num(Obj(LClips[J]), 'start_frame');
      LClip['end_frame'] := Num(Obj(LClips[J]), 'end_frame');
      LClip['included'] := Obj(LClips[J])['included'];
      LClip['classifications'] := Obj(LClips[J])['classifications'];
      FSelections.push(LClip);
    end;
  end;
end;
procedure TStudio.LoadProject(AProject: TJSObject);
var LRows: TJSArray; LRow, LWhole: TJSObject; I, J: Integer; LName: String;
  LNames: array of String;
begin
  FSelections := TJSArray.new;
  if Obj(AProject['playlist']) <> nil then ApplyPlaylist(Obj(AProject['playlist']))
  else
  begin
    LNames := ['sources', 'parked_sources'];
    for LName in LNames do
    begin
      LRows := Arr(AProject, LName);
      if LRows = nil then Continue;
      for I := 0 to LRows.length - 1 do
      begin
        LRow := CloneObject(Obj(LRows[I]));
        LRow['included'] := LName = 'sources';
        AddSelection(LRow);
      end;
    end;
    { A full row owns playlist membership and weight even when only clips teach. }
    I := 0;
    while I < FSelections.length do
    begin
      LRow := Obj(FSelections[I]);
      for J := 0 to FSelections.length - 1 do
        if (StudioSourceKey(Obj(FSelections[J])) = StudioSourceKey(LRow)) and
          (Str(Obj(FSelections[J]), 'selection') = 'full') then Break;
      if J >= FSelections.length then
      begin
        LWhole := CloneObject(LRow);
        LWhole['selection'] := 'full';
        LWhole['included'] := False;
        LWhole['start_frame'] := 0;
        LWhole['end_frame'] := Num(LRow, 'frame_count');
        FSelections.push(LWhole);
      end;
      Inc(I);
    end;
  end;
  { Legacy projects are opened as a NEW playlist, preserving their material,
    history and all immutable revisions. No silent overwrite of old work. }
  if Obj(AProject['playlist']) <> nil then
  begin
    FProjectId := Str(AProject, 'project_id');
    FRevision := Trunc(Num(AProject, 'revision'));
  end
  else
  begin
    FProjectId := 'playlist-' + IntToStr(Round(TJSDate.now));
    FRevision := 0;
  end;
  FName := Str(AProject, 'name');
  TJSHTMLInputElement(El('playlist-name')).value := FName;
  FDirty := False;
  FPendingWrite := nil;
  FSourceEditor.Reset;
  Remember;
  El('save-state').textContent := 'Saved';
  if Obj(AProject['playlist']) = nil then QueueSave;
end;
procedure TStudio.OpenProject(const AId: String); async;
var LProject: TJSObject;
begin
  if FLoading or FDirty or FSaving or (FPendingWrite <> nil) then
  begin
    Notice('Wait for Saved before opening another playlist. Your current edits are kept.', True);
    Exit;
  end;
  FLoading := True;
  Draw;
  try
    LProject := await(TJSObject, Json('/api/studio/project?id=' + encodeURIComponent(AId), 'GET', ''));
    LoadProject(LProject);
    TStudioDialog(El('playlists-dialog')).close;
    Draw;
    ShowStep('selection');
  except
    on E: Exception do Notice(E.Message, True);
  end;
  FLoading := False;
  Draw;
end;
procedure TStudio.CatalogSaved;
begin Connect end;
procedure TStudio.Connect; async;
var LSession, LData, LPrepared, LDiscovery, LState: TJSObject;
  LTracks: TJSArray; LOption: TJSElement; I: Integer; LLocal: String;
begin
  if FLoading then Exit;
  FLoading := True;
  try
    Notice('Opening your music…');
    LSession := await(TJSObject, Json('/api/session', 'GET', ''));
    FToken := Str(LSession, 'token');
    if FToken = '' then raise Exception.Create('Studio could not open a local session.');
    LData := await(TJSObject, Json('/api/studio/sources', 'GET', ''));
    LTracks := Arr(LData, 'sources');
    if LTracks = nil then raise Exception.Create('Music catalog is unavailable.');
    LPrepared := await(TJSObject, Json('/api/studio/library', 'GET', ''));
    LDiscovery := await(TJSObject, Json('/api/studio/library-discovery', 'GET', ''));
    MergeDiscovery(LTracks, LDiscovery, LPrepared);
    FTracks := LTracks;
    LData := await(TJSObject, Json('/api/studio/projects', 'GET', ''));
    FProjects := Arr(LData, 'projects');
    DrawProjects;
    if (FProjectId = '') then
    begin
      LLocal := window.localStorage.getItem('pythian.studio.playlist');
      if isString(LLocal) and (LLocal <> '') then
      begin
        LState := Obj(TJSJSON.parse(LLocal));
        if LState = nil then raise Exception.Create('Saved browser playlist is unreadable. Open a saved playlist to recover.');
        FProjectId := Str(LState, 'project_id');
        FRevision := Trunc(Num(LState, 'revision'));
        FName := Str(LState, 'name');
        FSelections := Arr(LState, 'selections');
        FDirty := isBoolean(LState['dirty']) and Boolean(LState['dirty']);
        FPendingWrite := Obj(LState['pending_write']);
        FPendingVersion := Trunc(Num(LState, 'pending_version'));
        FChanges := Trunc(Num(LState, 'changes'));
        if FSelections = nil then FSelections := TJSArray.new;
        TJSHTMLInputElement(El('playlist-name')).value := FName;
      end;
      if FProjectId = '' then NewPlaylist;
      if (FRevision > 0) and not FDirty and (FPendingWrite = nil) then
      begin
        LState := await(TJSObject, Json('/api/studio/project?id=' + encodeURIComponent(FProjectId), 'GET', ''));
        LoadProject(LState);
      end;
    end;
    FConnected := True;
    FLibraryRefresh.SetConnected(True);
    FLibraryRefresh.Refresh;
    FCapture.Refresh;
    Notice('');
    El('retry-connection').setAttribute('hidden', '');
  except
    on E: Exception do
    begin
      Notice(E.Message + ' Your playlist is kept.', True);
      El('retry-connection').removeAttribute('hidden');
    end;
  end;
  FLoading := False;
  Draw;
  if not FDirty and (FRevision > 0) then El('save-state').textContent := 'Saved';
  if FDirty or (FPendingWrite <> nil) then Save;
end;
function TStudio.Click(AEvent: TJSMouseEvent): Boolean;
var LButton: TJSElement; LStep, LDialog, LId: String;
begin
  Result := False;
  LButton := TJSElement(AEvent.currentTarget);
  if LButton.hasAttribute('data-step') then ShowStep(LButton.getAttribute('data-step'));
  if LButton.hasAttribute('data-dialog') then
    TStudioDialog(El(LButton.getAttribute('data-dialog'))).showModal;
  if LButton.hasAttribute('data-close') then
    TStudioDialog(El(LButton.getAttribute('data-close'))).close;
  if LButton.hasAttribute('data-project') then OpenProject(LButton.getAttribute('data-project'));
  case LButton.id of
    'new-playlist':
      begin
        if FDirty or FSaving or (FPendingWrite <> nil) then Exit;
        NewPlaylist;
        Draw;
        TStudioDialog(El('playlists-dialog')).close;
        ShowStep('library');
      end;
    'record-audio': begin TStudioDialog(El('capture-panel')).showModal; FCapture.OpenRecorder end;
    'import-audio': begin TStudioDialog(El('capture-panel')).showModal; FCapture.OpenImporter end;
    'retry-save': Save;
    'save-copy': SaveCopy;
    'retry-connection', 'source-reconnect': Connect;
  end;
end;
function TStudio.Edit(AEvent: TEventListenerEvent): Boolean;
var LControl: TJSElement; LIndex: Integer;
begin
  Result := False;
  if FLoading then Exit;
  LControl := TJSElement(AEvent.target);
  if LControl.id = 'track-search' then begin FSourceEditor.Search; Exit end;
  if LControl.hasAttribute('data-influence') then
  begin
    LIndex := StrToInt(LControl.getAttribute('data-influence'));
    Obj(FSelections[LIndex])['influence'] := StrToInt(TJSHTMLInputElement(LControl).value);
    LControl.parentElement.querySelector('output').textContent := TJSHTMLInputElement(LControl).value + '×';
    QueueSave;
    Exit;
  end;
  Changed;
end;
function TStudio.Playing(AEvent: TEventListenerEvent): Boolean;
var LPlayers: TJSNodeList; I: Integer;
begin
  Result := False;
  LPlayers := document.querySelectorAll('audio');
  for I := 0 to LPlayers.length - 1 do
    if LPlayers[I] <> AEvent.target then TJSHTMLAudioElement(LPlayers[I]).pause;
end;
function TStudio.Leaving(AEvent: TEventListenerEvent): Boolean;
begin
  Result := False;
  Remember;
end;
function TStudio.CaptureClosed(AEvent: TEventListenerEvent): Boolean;
begin
  Result := False;
  FCapture.CloseEntry;
end;
function TStudio.TabKey(AEvent: TJSKeyboardEvent): Boolean;
var LName: String;
begin
  Result := False;
  LName := TJSElement(AEvent.currentTarget).getAttribute('data-step');
  if AEvent.key = 'ArrowRight' then
  begin
    if LName = 'library' then LName := 'selection'
    else if LName = 'selection' then LName := 'generate' else LName := 'library';
  end
  else if AEvent.key = 'ArrowLeft' then
  begin
    if LName = 'library' then LName := 'generate'
    else if LName = 'generate' then LName := 'selection' else LName := 'library';
  end
  else if AEvent.key = 'Home' then LName := 'library'
  else if AEvent.key = 'End' then LName := 'generate'
  else Exit;
  AEvent.preventDefault;
  ShowStep(LName);
  TJSHTMLElement(El('tab-' + LName)).focus;
end;
procedure TStudio.Run;
var LNodes: TJSNodeList; I: Integer;
begin
  FTracks := TJSArray.new;
  FSelections := TJSArray.new;
  FProjects := TJSArray.new;
  FSourceEditor := TStudioSourceEditor.Create(@FetchApi, @Changed, @FetchNavigation);
  FCapture := TStudioCapture.Create(@FetchApi, @CatalogSaved);
  FEffects := TStudioEffects.Create(@FetchApi, @FSourceEditor.CurrentRange, @CatalogSaved);
  FLibraryRefresh := TStudioLibraryRefresh.Create(@FetchNavigation, @CatalogSaved);
  LNodes := document.querySelectorAll('button[data-step],button[data-dialog],button[data-close],button[data-studio-action]');
  for I := 0 to LNodes.length - 1 do TJSElement(LNodes[I]).addEventListener('click', @Click);
  El('track-search').addEventListener('input', @Edit);
  El('playlist-name').addEventListener('change', @Edit);
  El('source-reconnect').addEventListener('click', @Click);
  El('capture-panel').addEventListener('close', @CaptureClosed);
  El('tab-library').addEventListener('keydown', @TabKey);
  El('tab-selection').addEventListener('keydown', @TabKey);
  El('tab-generate').addEventListener('keydown', @TabKey);
  document.addEventListener('play', @Playing, True);
  window.addEventListener('pagehide', @Leaving);
  ShowStep('library');
  if (window.location.hash = '#listen') or (window.location.hash = '#prepare') then
    ShowStep('generate');
  Connect;
end;

procedure TStudio.MergeDiscovery(ATracks: TJSArray; ADiscovery, APrepared: TJSObject);
var
  LEntries: TJSArray;
  LEntry: TJSObject;
  LTrack: TJSObject;
  LCollection: TJSObject;
  LCollections: TJSArray;
  LPrevious: String;
  LIndex: Integer;
  LOther: Integer;
  LGroupIndex: Integer;
  LMemberIndex: Integer;
  LGroups: TJSArray;
  LMembers: TJSArray;
begin
  if (Str(ADiscovery, 'format') <> 'pythian.studio.library.discovery.v1') or
    not isArray(ADiscovery['entries']) then
  begin
    raise Exception.Create('The collection list is unavailable. Retry discovery.');
  end;
  LEntries := TJSArray(ADiscovery['entries']);
  if (Str(APrepared, 'format') <> 'pythian.studio.library.v1') or
    not isArray(APrepared['collections']) then
    raise Exception.Create('Prepared recording details are unavailable. Retry connection.');
  LGroups := TJSArray(APrepared['collections']);
  if LEntries.length > 256 then
  begin
    raise Exception.Create('The collection list exceeds its supported size.');
  end;
  for LIndex := 0 to LEntries.length - 1 do
  begin
    LEntry := Obj(LEntries[LIndex]);
    if (Str(LEntry, 'entry_id') = '') or
      (Length(Str(LEntry, 'entry_snapshot_sha256')) <> 64) then
    begin
      raise Exception.Create('A collection entry has no metadata identity.');
    end;
    LTrack := nil;
    LPrevious := Str(LEntry, 'previous_source_sha256');
    { Big Boss: preparation may be newer than the last discovery scan.
      Join its recorded membership for display only; selected use still
      verifies the current original in the native preparation job. }
    for LGroupIndex := 0 to LGroups.length - 1 do
      if Str(Obj(LGroups[LGroupIndex]), 'collection_id') = Str(LEntry, 'collection_id') then
      begin
        LMembers := Arr(Obj(LGroups[LGroupIndex]), 'memberships');
        if LMembers <> nil then
          for LMemberIndex := 0 to LMembers.length - 1 do
            if Str(Obj(LMembers[LMemberIndex]), 'original_name') = Str(LEntry, 'original_name') then
              LPrevious := Str(Obj(LMembers[LMemberIndex]), 'source_sha256');
      end;
    if LPrevious <> '' then
    begin
      for LOther := 0 to ATracks.length - 1 do
      begin
        if (Str(Obj(ATracks[LOther]), 'source_sha256') = LPrevious) and
          (((Num(Obj(ATracks[LOther]), 'sample_rate') = Num(LEntry, 'sample_rate')) and
          (Num(Obj(ATracks[LOther]), 'frame_count') = Num(LEntry, 'frame_count'))) or
          (Str(LEntry, 'status') <> 'available')) then
        begin
          LTrack := Obj(ATracks[LOther]);
          Break;
        end;
      end;
    end;
    if LTrack = nil then
    begin
      LTrack := CloneObject(LEntry);
      LTrack['title'] := Str(LEntry, 'original_name');
      LTrack['source_sha256'] := '';
      LTrack['partition'] := 'unassigned';
      ATracks.push(LTrack);
    end;
    if (Str(LTrack, 'entry_id') = '') or
      ((Str(LTrack, 'status') <> 'available') and (Str(LEntry, 'status') = 'available')) or
      (Str(LTrack, 'entry_id') = Str(LEntry, 'entry_id')) then
    begin
      LTrack['entry_id'] := Str(LEntry, 'entry_id');
      LTrack['entry_snapshot_sha256'] := Str(LEntry, 'entry_snapshot_sha256');
      LTrack['discovery_revision'] := Num(ADiscovery, 'revision');
      LTrack['status'] := Str(LEntry, 'status');
    end;
    LTrack['content_validation'] := 'not_verified';
    LCollections := TJSArray(LTrack['collections']);
    if not isArray(LCollections) then
    begin
      LCollections := TJSArray.new;
      LTrack['collections'] := LCollections;
    end;
    LPrevious := Str(LEntry, 'collection_id');
    LCollection := nil;
    for LOther := 0 to LCollections.length - 1 do
    begin
      if Str(Obj(LCollections[LOther]), 'collection_id') = LPrevious then
      begin
        LCollection := Obj(LCollections[LOther]);
      end;
    end;
    if LCollection = nil then
    begin
      LCollection := TJSObject.new;
      LCollection['collection_id'] := LPrevious;
      LCollection['name'] := Str(LEntry, 'collection_name');
      LCollections.push(LCollection);
    end;
  end;
end;


var GStudio: TStudio;
begin
  GStudio := TStudio.Create;
  GStudio.Run;
end.
