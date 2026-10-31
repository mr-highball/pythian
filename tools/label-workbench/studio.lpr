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
  pythian.studio.requests, pythian.studio.&library.refresh, pythian.studio.progress,
  pythian.wave.stream, pythian.music.selection;

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
    FSnapshotHash: String;
    FStorageScope: String;
    FJobId: String;
    FJob: TJSObject;
    FJobWrite: TJSObject;
    FJobTimer: NativeInt;
    FJobEpoch: Integer;
    FJobPolling: Boolean;
    FSubmitting: Boolean;
    FCancelling: Boolean;
    FGenerateAfterSave: Boolean;
    FGenerationMessage: String;
    FResumeOnConnect: Boolean;
    FIncludedSeconds: Double;
    FLearningLabel: String;
    function ClassifiedSelections: TClassifiedMusicSelections;
    procedure OpenLearningLabel;
    procedure PreviewLearningLabel;
    procedure ApplyLearningLabel;
    function OutputSeconds(out ASeconds: Double): Boolean;
    procedure Generate; async;
    procedure RestoreGeneration; async;
    procedure PollGeneration; async;
    procedure CancelGeneration; async;
    procedure RememberGeneration;
    procedure DrawGeneration;
    procedure ClearGeneration;
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
    function UserInteraction(AEvent: TEventListenerEvent): Boolean;
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
  try
    LResponse := TJSResponse(await(JSValue, AwaitStudioPromise(FetchApi(APath, AMethod, ABody), 20)));
  except
    raise Exception.Create('Connection interrupted. Reconnect to continue. Your choices are kept.');
  end;
  if LResponse.status <> 200 then
  begin
    if LResponse.status = 409 then
      raise Exception.Create('Playlist changed or storage is busy. Retry shortly, or save a new copy. Your edits are kept.');
    raise Exception.Create('Request failed (HTTP ' + IntToStr(LResponse.status) + '). Reconnect or open a saved playlist.');
  end;
  try
    LValue := await(TJSObject, LResponse.json());
  except
    raise Exception.Create('Studio received an unreadable response. Reconnect to continue.');
  end;
  Result := LValue;
end;
procedure TStudio.Notice(const AText: String; const AError: Boolean);
begin
  El('connection-state').textContent := AText;
  El('playlist-dialog-status').textContent := AText;
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
  FLearningLabel := '';
  FProjectId := 'playlist-' + IntToStr(Round(TJSDate.now)) + '-' + IntToStr(Random(1000000));
  FRevision := 0;
  FSnapshotHash := '';
  ClearGeneration;
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
  if FStorageScope = '' then Exit;
  LState := TJSObject.new;
  LState['project_id'] := FProjectId;
  LState['revision'] := FRevision;
  LState['snapshot_sha256'] := FSnapshotHash;
  LState['name'] := FName;
  LState['selections'] := FSelections;
  LState['learning_label'] := FLearningLabel;
  LState['dirty'] := FDirty;
  LState['changes'] := FChanges;
  LState['pending_version'] := FPendingVersion;
  LState['pending_write'] := FPendingWrite;
  try
    window.localStorage.setItem('pythian.studio.playlist.' + FStorageScope, TJSJSON.stringify(LState));
  except
    on E: Exception do Notice('Browser storage is unavailable. Keep this page open until Saved appears.', True);
  end;
end;
procedure TStudio.Changed;
begin
  FLearningLabel := '';
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
  if FLearningLabel <> '' then Result['learning_label'] := FLearningLabel;
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
    LClasses := Arr(LRow, 'classifications');
    if (LClasses <> nil) and (LClasses.length > 0) then
      LItem['classifications'] := LClasses;
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
  El('save-state').textContent := 'Saving…';
  El('retry-save').setAttribute('hidden', '');
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
    FSnapshotHash := Str(LSaved, 'snapshot_sha256');
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
    Notice('');
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
  if FGenerateAfterSave and not FDirty and (FPendingWrite = nil) then Generate;
end;
procedure TStudio.ClearGeneration;
begin
  Inc(FJobEpoch);
  window.clearTimeout(FJobTimer);
  FJobId := '';
  FJob := nil;
  FJobWrite := nil;
  FJobPolling := False;
  FSubmitting := False;
  FCancelling := False;
  FGenerateAfterSave := False;
  FGenerationMessage := '';
  TJSHTMLAudioElement(El('generated-audio')).pause;
  TJSHTMLAudioElement(El('generated-original-audio')).pause;
  El('generated-audio').removeAttribute('src');
  El('generated-audio').removeAttribute('data-job');
  TJSHTMLAudioElement(El('generated-audio')).load;
  El('generated-original-audio').removeAttribute('src');
  TJSHTMLAudioElement(El('generated-original-audio')).load;
  El('generation-result').setAttribute('hidden', '');
end;

procedure TStudio.RememberGeneration;
var LState: TJSObject;
begin
  LState := TJSObject.new;
  LState['job_id'] := FJobId;
  LState['request'] := FJobWrite;
  LState['duration'] := TJSHTMLInputElement(El('output-duration')).value;
  LState['duration_unit'] := TJSHTMLSelectElement(El('output-duration-unit')).value;
  try
    window.localStorage.setItem('pythian.studio.generation.' + FStorageScope + '.' + FProjectId, TJSJSON.stringify(LState));
  except
    on E: Exception do FGenerationMessage := 'This run is saved on the computer. Reopen this playlist to reconnect.';
  end;
end;

function TStudio.OutputSeconds(out ASeconds: Double): Boolean;
var
  LUnit: String;
begin
  ASeconds := 0;
  Result := TryStrToFloat(TJSHTMLInputElement(El('output-duration')).value, ASeconds);
  if not Result or IsNan(ASeconds) or IsInfinite(ASeconds) then Exit(False);
  LUnit := TJSHTMLSelectElement(El('output-duration-unit')).value;
  if LUnit = 'minutes' then ASeconds := ASeconds * 60
  else if LUnit = 'hours' then ASeconds := ASeconds * 3600
  else if LUnit <> 'seconds' then Exit(False);
  Result := (ASeconds >= 2) and (ASeconds <= 86400);
end;

procedure TStudio.DrawGeneration;
var
  LState: String;
  LActive: Boolean;
  LResult, LReference, LLearning, LRow, LClassChoice: TJSObject;
  LRows: TJSArray;
  LUrl: String;
  LSeconds: Double;
  LBytes: Int64;
  I: Integer;
begin
  if OutputSeconds(LSeconds) then
  begin
    LBytes := WavePcm16ByteCount(24000, 2, Round(LSeconds * 1000) * 24 + 24000);
    El('output-estimate').textContent := 'About ' + StudioByteSize(LBytes * 7) +
      ' on this computer for your mix and six parts. Stereo WAV · 24 kHz.';
  end
  else El('output-estimate').textContent := 'Choose 2 seconds to 24 hours.';
  LState := Str(FJob, 'status');
  LActive := (LState = 'queued') or (LState = 'running') or FSubmitting or FGenerateAfterSave;
  TJSHTMLInputElement(El('output-duration')).disabled := LActive;
  TJSHTMLSelectElement(El('output-duration-unit')).disabled := LActive;
  TJSHTMLButtonElement(El('generate-music')).disabled := not FConnected or FLoading or
    (FIncludedSeconds <= 0) or LActive or FGenerateAfterSave;
  El('generation-progress').innerHTML := '';
  if (FJob <> nil) and not FSubmitting and not FGenerateAfterSave then
    DrawStudioProgress(El('generation-progress'), FJob, True);
  El('cancel-generation').setAttribute('hidden', '');
  if LActive and not FSubmitting and not FGenerateAfterSave then
    El('cancel-generation').removeAttribute('hidden');
  TJSHTMLButtonElement(El('cancel-generation')).disabled := FCancelling;
  El('reconnect-generation').setAttribute('hidden', '');
  if FGenerationMessage <> '' then
    El('generation-status').textContent := FGenerationMessage
  else if LActive then
    El('generation-status').textContent := 'Working on this computer. You can leave and come back.'
  else if LState = 'completed' then El('generation-status').textContent := 'Ready. Press Play.'
  else if LState = 'cancelled' then El('generation-status').textContent := 'Stopped. Your music choices are kept.'
  else if LState = 'failed' then El('generation-status').textContent := Str(FJob, 'error_message')
  else El('generation-status').textContent := 'Your selections save automatically. Generate learns from the selected music.';
  if not FSubmitting and not FCancelling and (FJobId <> '') and
    (FGenerationMessage <> '') and ((FJobWrite <> nil) or not LActive) then
    El('reconnect-generation').removeAttribute('hidden');
  if FSubmitting or FGenerateAfterSave then
  begin
    El('generation-result').setAttribute('hidden', '');
    Exit;
  end;
  if (LState <> 'completed') or (Obj(FJob['results']) = nil) then Exit;
  LResult := Obj(FJob['results']);
  El('generation-revision-note').textContent := '';
  if FDirty or (Num(LResult, 'project_revision') <> FRevision) then
    El('generation-revision-note').textContent :=
      'Your playlist has changed since this run. Generate again to use your current selection.';
  LUrl := '/api/studio/instrumental-audio?job=' + encodeURIComponent(FJobId) + '&part=6';
  if El('generated-audio').getAttribute('data-job') <> FJobId then
  begin
    TJSHTMLAudioElement(El('generated-audio')).src := LUrl;
    El('generated-audio').setAttribute('data-job', FJobId);
    El('download-generated').setAttribute('href', LUrl);
    LReference := Obj(LResult['original_reference']);
    El('generation-original').setAttribute('hidden', '');
    if LReference <> nil then
    begin
      El('generation-original').removeAttribute('hidden');
      El('generation-original-title').textContent := Str(LReference, 'title');
      TJSHTMLAudioElement(El('generated-original-audio')).src :=
        '/api/studio/instrumental-audio?job=' + encodeURIComponent(FJobId) + '&part=7';
    end;
    El('generation-learning').innerHTML := '';
    LLearning := Obj(LResult['playlist_learning']);
    LClassChoice := nil;
    if LLearning <> nil then LClassChoice := Obj(LLearning['classification_selection']);
    if LClassChoice <> nil then
      Add(El('generation-learning'), 'p', 'Label: ' + Str(LClassChoice, 'label'));
    LRows := Arr(LLearning, 'sources');
    if LRows <> nil then
      for I := 0 to LRows.length - 1 do
      begin
        LRow := Obj(LRows[I]);
        Add(El('generation-learning'), 'p', Str(Obj(LRow['playlist_item']), 'title') + ': ' +
          'selected ' + StudioTime(Num(LRow, 'included_frames') / Num(LRow, 'sample_rate')) +
          ' · analyzed ' + StudioTime(Num(LRow, 'analyzed_frames') / Num(LRow, 'sample_rate')) +
          ' · used in model ' + StudioTime(Num(LRow, 'model_used_frames') / Num(LRow, 'sample_rate')));
        Add(El('generation-learning'), 'p',
          StudioTime(Num(LRow, 'excluded_frames') / Num(LRow, 'sample_rate')) +
          ' not selected · ' + FloatToStr(Num(LRow, 'influence')) + '× influence');
        if (Arr(LRow, 'providers_taught') <> nil) and
          (Arr(LRow, 'providers_taught').length > 0) then
          Add(El('generation-learning'), 'p', 'Proposes bass, harmony, lead and drums.');
      end;
    LRows := Arr(LLearning, 'excluded_sources');
    if LRows <> nil then
      for I := 0 to LRows.length - 1 do
      begin
        LRow := Obj(LRows[I]);
        Add(El('generation-learning'), 'p', 'Not used: ' + Str(LRow, 'title') + ' · ' +
          StudioTime(Num(LRow, 'frame_count') / Num(LRow, 'sample_rate')) + ' not selected');
      end;
  end;
  El('generation-result').removeAttribute('hidden');
end;

procedure TStudio.Generate; async;
var
  LWrite, LSettings, LJob, LProject: TJSObject;
  LSeconds: Double;
  LId: String;
  LEpoch: Integer;
begin
  if FSubmitting or FLoading or not FConnected then Exit;
  if (Str(FJob, 'status') = 'running') or (Str(FJob, 'status') = 'queued') then Exit;
  if FSaving or FDirty or (FPendingWrite <> nil) then
  begin
    FGenerateAfterSave := True;
    FGenerationMessage := 'Saving your selection…';
    DrawGeneration;
    Save;
    Exit;
  end;
  FGenerateAfterSave := False;
  if (FJobWrite = nil) and
    not OutputSeconds(LSeconds) then
  begin
    FGenerationMessage := 'Choose a track length from 2 seconds to 24 hours.';
    DrawGeneration;
    Exit;
  end;
  FSubmitting := True;
  TJSHTMLAudioElement(El('generated-audio')).pause;
  TJSHTMLAudioElement(El('generated-original-audio')).pause;
  FGenerationMessage := 'Starting your track…';
  DrawGeneration;
  LEpoch := FJobEpoch;
  try
    if FJobWrite = nil then
    begin
      LProject := await(TJSObject, Json('/api/studio/project?id=' + encodeURIComponent(FProjectId), 'GET', ''));
      if LEpoch <> FJobEpoch then Exit;
      if (Num(LProject, 'revision') <> FRevision) or
        not SameStudioJSON(LProject['playlist'], Playlist) then
        raise Exception.Create('Your saved selection changed. Reopen this playlist before generating.');
      FSnapshotHash := Str(LProject, 'snapshot_sha256');
      LId := 'music-' + IntToStr(Round(TJSDate.now)) + '-' + IntToStr(Random(1000000));
      LWrite := TJSObject.new;
      LWrite['format'] := 'pythian.studio.job.write.v1';
      LWrite['job_id'] := LId;
      LWrite['kind'] := 'instrumental_generate';
      LWrite['project_id'] := FProjectId;
      LWrite['project_revision'] := FRevision;
      LWrite['project_snapshot_sha256'] := FSnapshotHash;
      LWrite['duration_ms'] := Round(LSeconds * 1000);
      LWrite['seeds'] := TJSArray.new;
      TJSArray(LWrite['seeds']).push(Random(2147483000));
      LSettings := TJSObject.new;
      LSettings['tempo_bpm'] := 120;
      LSettings['tonic'] := 0;
      LSettings['cells'] := 16;
      LSettings['instruments'] := TJSArray.new('saw', 'triangle', 'square');
      LSettings['levels'] := TJSArray.new(75, 65, 60, 80, 65, 50);
      LWrite['instrumental'] := LSettings;
      FJobWrite := LWrite;
      FJobId := LId;
      FJob := nil;
      TJSHTMLAudioElement(El('generated-audio')).pause;
      TJSHTMLAudioElement(El('generated-original-audio')).pause;
      El('generation-result').setAttribute('hidden', '');
      RememberGeneration;
    end;
    LJob := await(TJSObject, Json('/api/studio/job', 'POST', TJSJSON.stringify(FJobWrite)));
    if LEpoch <> FJobEpoch then Exit;
    if (Str(LJob, 'job_id') <> FJobId) or (Str(LJob, 'project_id') <> FProjectId) then
      raise Exception.Create('Generation returned a different playlist. Reconnect to this run.');
    FJob := LJob;
    FJobWrite := nil;
    if not FCancelling then FGenerationMessage := '';
    RememberGeneration;
  except
    on E: Exception do FGenerationMessage := E.Message + ' Your request is kept for reconnecting.';
  end;
  if LEpoch = FJobEpoch then
  begin
    FSubmitting := False;
    DrawGeneration;
    if FJob <> nil then PollGeneration;
  end;
end;

procedure TStudio.PollGeneration; async;
var LJob: TJSObject; LEpoch: Integer;
begin
  if FJobPolling or FSubmitting or (FJobId = '') or not FConnected then Exit;
  FJobPolling := True;
  LEpoch := FJobEpoch;
  window.clearTimeout(FJobTimer);
  try
    LJob := await(TJSObject, Json('/api/studio/job?id=' + encodeURIComponent(FJobId), 'GET', ''));
    if LEpoch <> FJobEpoch then Exit;
    if (Str(LJob, 'job_id') <> FJobId) or (Str(LJob, 'project_id') <> FProjectId) then
      raise Exception.Create('This run belongs to a different playlist.');
    FJob := LJob;
    FJobWrite := nil;
    if not FCancelling then FGenerationMessage := '';
    RememberGeneration;
  except
    on E: Exception do
      if LEpoch = FJobEpoch then FGenerationMessage := 'Reconnecting… Your saved request is kept.';
  end;
  if LEpoch = FJobEpoch then
  begin
    FJobPolling := False;
    DrawGeneration;
    if (FJob = nil) or (Str(FJob, 'status') = 'queued') or (Str(FJob, 'status') = 'running') then
      FJobTimer := window.setTimeout(procedure begin PollGeneration end, 1500);
  end;
end;

procedure TStudio.RestoreGeneration; async;
var LText: String; LState, LJobs: TJSObject; LRows: TJSArray; I, LEpoch: Integer;
  LLegacySeconds: Double;
begin
  if (FProjectId = '') or not FConnected then Exit;
  if FJobId <> '' then begin PollGeneration; Exit end;
  LEpoch := FJobEpoch;
  try
    LText := window.localStorage.getItem('pythian.studio.generation.' + FStorageScope + '.' + FProjectId);
    if isString(LText) and (LText <> '') then
    begin
      LState := Obj(TJSJSON.parse(LText));
      FJobId := Str(LState, 'job_id');
      FJobWrite := Obj(LState['request']);
      if Str(LState, 'duration') <> '' then
      begin
        if Str(LState, 'duration_unit') <> '' then
        begin
          TJSHTMLInputElement(El('output-duration')).value := Str(LState, 'duration');
          TJSHTMLSelectElement(El('output-duration-unit')).value := Str(LState, 'duration_unit');
        end
        else if ParseSourceTime(Str(LState, 'duration'), LLegacySeconds) then
        begin
          TJSHTMLInputElement(El('output-duration')).value := FloatToStr(LLegacySeconds);
          TJSHTMLSelectElement(El('output-duration-unit')).value := 'seconds';
        end;
      end;
    end;
    if FJobId = '' then
    begin
      LJobs := await(TJSObject, Json('/api/studio/jobs', 'GET', ''));
      if LEpoch <> FJobEpoch then Exit;
      LRows := Arr(LJobs, 'jobs');
      if LRows <> nil then
        for I := LRows.length - 1 downto 0 do
          if (Str(Obj(LRows[I]), 'project_id') = FProjectId) and
            (Str(Obj(LRows[I]), 'kind') = 'instrumental_generate') then
          begin FJobId := Str(Obj(LRows[I]), 'job_id'); Break end;
    end;
    if FJobId <> '' then
    begin
      if FResumeOnConnect then ShowStep('generate');
      PollGeneration;
    end;
  except
    on E: Exception do FGenerationMessage := 'Open Generate to reconnect to saved runs.';
  end;
  FResumeOnConnect := False;
end;

procedure TStudio.CancelGeneration; async;
var LWrite, LJob: TJSObject; LEpoch: Integer;
begin
  if (FJobId = '') or FCancelling then Exit;
  LEpoch := FJobEpoch;
  FCancelling := True;
  FGenerationMessage := 'Stopping at the next checkpoint…';
  DrawGeneration;
  LWrite := TJSObject.new;
  LWrite['job_id'] := FJobId;
  try
    LJob := await(TJSObject, Json('/api/studio/cancel', 'POST', TJSJSON.stringify(LWrite)));
    if LEpoch <> FJobEpoch then Exit;
    FJob := LJob;
    FGenerationMessage := 'Stopping at the next checkpoint…';
  except
    on E: Exception do FGenerationMessage := E.Message;
  end;
  if LEpoch = FJobEpoch then
  begin FCancelling := False; DrawGeneration; PollGeneration end;
end;

procedure TStudio.SaveCopy;
begin
  if FSaving or FLoading then Exit;
  FProjectId := 'playlist-' + IntToStr(Round(TJSDate.now)) + '-' + IntToStr(Random(1000000));
  FRevision := 0;
  FSnapshotHash := '';
  ClearGeneration;
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

function TStudio.ClassifiedSelections: TClassifiedMusicSelections;
var
  LRow: TJSObject;
  LTrack: TJSObject;
  LClasses: TJSArray;
  LCollections: TJSArray;
  LLabel: String;
  I: Integer;
  J: Integer;
  procedure AddLabel(const AValue: String);
  var
    LAt: Integer;
  begin
    if FindMusicClassification(Result[I].Classifications, AValue) >= 0 then Exit;
    LAt := Length(Result[I].Classifications);
    SetLength(Result[I].Classifications, LAt + 1);
    Result[I].Classifications[LAt] := AValue;
  end;
begin
  Result := nil;
  SetLength(Result, FSelections.length);
  for I := 0 to FSelections.length - 1 do
  begin
    LRow := Obj(FSelections[I]);
    Result[I].SourceId := StudioSourceKey(LRow);
    Result[I].WholeRecording := Str(LRow, 'selection') = 'full';
    Result[I].StartFrame := Trunc(Num(LRow, 'start_frame'));
    Result[I].EndFrame := Trunc(Num(LRow, 'end_frame'));
    LClasses := Arr(LRow, 'classifications');
    if LClasses <> nil then
      for J := 0 to LClasses.length - 1 do AddLabel(String(LClasses[J]));
    if not Result[I].WholeRecording then Continue;
    LCollections := nil;
    { Collection names become explicit caller labels only when the operator
      applies this selection. Browsing/reopening never changes a saved draft. }
    for J := 0 to FTracks.length - 1 do
    begin
      LTrack := Obj(FTracks[J]);
      if StudioSourceKey(LTrack) <> StudioSourceKey(LRow) then Continue;
      LCollections := Arr(LTrack, 'collections');
      Break;
    end;
    if LCollections <> nil then
      for J := 0 to LCollections.length - 1 do
      begin
        LLabel := Str(Obj(LCollections[J]), 'name');
        if LLabel <> '' then AddLabel(LLabel);
      end;
    LCollections := nil;
  end;
end;

procedure TStudio.OpenLearningLabel;
var
  LLabels: TMusicClassifications;
  LOption: TJSElement;
  I: Integer;
begin
  try
    LLabels := AvailableMusicClassifications(ClassifiedSelections);
    El('learning-label-choice').innerHTML := '';
    for I := 0 to High(LLabels) do
    begin
      LOption := Add(El('learning-label-choice'), 'option', LLabels[I]);
      LOption.setAttribute('value', LLabels[I]);
    end;
    if FindMusicClassification(LLabels, FLearningLabel) >= 0 then
      TJSHTMLSelectElement(El('learning-label-choice')).value := FLearningLabel;
    PreviewLearningLabel;
    TStudioDialog(El('learning-label-dialog')).showModal;
  except
    on E: Exception do Notice(E.Message, True);
  end;
end;

procedure TStudio.PreviewLearningLabel;
var
  LRows: TClassifiedMusicSelections;
  LFlags: TMusicSelectionFlags;
  LWhole: Integer;
  LClips: Integer;
  LSeconds: Double;
  LWholeText: String;
  LClipText: String;
  LDescription: String;
  I: Integer;
begin
  TJSHTMLButtonElement(El('apply-learning-label')).disabled := True;
  El('learning-label-preview').className := 'hint';
  El('learning-label-matches').innerHTML := '';
  try
    LRows := ClassifiedSelections;
    LFlags := ClassifyMusicSelection(LRows,
      TJSHTMLSelectElement(El('learning-label-choice')).value);
    LWhole := 0;
    LClips := 0;
    LSeconds := 0;
    for I := 0 to High(LFlags) do
    begin
      if not LFlags[I] then Continue;
      if LRows[I].WholeRecording then Inc(LWhole) else Inc(LClips);
      LDescription := Str(Obj(FSelections[I]), 'title') + ' · whole track';
      if not LRows[I].WholeRecording then
        LDescription := Str(Obj(FSelections[I]), 'title') + ' · ' +
          StudioTime(LRows[I].StartFrame / Num(Obj(FSelections[I]), 'sample_rate')) + '–' +
          StudioTime(LRows[I].EndFrame / Num(Obj(FSelections[I]), 'sample_rate'));
      Add(El('learning-label-matches'), 'p', LDescription);
      LSeconds := LSeconds + (LRows[I].EndFrame - LRows[I].StartFrame) /
        Num(Obj(FSelections[I]), 'sample_rate');
    end;
    LWholeText := IntToStr(LWhole) + ' whole track';
    if LWhole <> 1 then LWholeText := LWholeText + 's';
    LClipText := IntToStr(LClips) + ' clip';
    if LClips <> 1 then LClipText := LClipText + 's';
    El('learning-label-preview').textContent := LWholeText + ', ' + LClipText +
      ' · ' + StudioTime(LSeconds) + ' will teach Pythian.';
    TJSHTMLButtonElement(El('apply-learning-label')).disabled := False;
  except
    on E: Exception do
    begin
      El('learning-label-preview').textContent := E.Message;
      El('learning-label-preview').className := 'field-error';
    end;
  end;
end;

procedure TStudio.ApplyLearningLabel;
var
  LRows: TClassifiedMusicSelections;
  LFlags: TMusicSelectionFlags;
  LClasses: TJSArray;
  LLabel: String;
  I: Integer;
  J: Integer;
begin
  try
    LLabel := TJSHTMLSelectElement(El('learning-label-choice')).value;
    LRows := ClassifiedSelections;
    LFlags := ClassifyMusicSelection(LRows, LLabel);
    for I := 0 to High(LFlags) do
    begin
      Obj(FSelections[I])['included'] := LFlags[I];
      if LRows[I].WholeRecording then
      begin
        LClasses := TJSArray.new;
        for J := 0 to High(LRows[I].Classifications) do
          LClasses.push(LRows[I].Classifications[J]);
        Obj(FSelections[I])['classifications'] := LClasses;
      end;
    end;
    FLearningLabel := LLabel;
    QueueSave;
    Draw;
    TStudioDialog(El('learning-label-dialog')).close;
  except
    on E: Exception do
    begin
      El('learning-label-preview').textContent := E.Message;
      El('learning-label-preview').className := 'field-error';
    end;
  end;
end;

procedure TStudio.Draw;
var
  LItem, LOther: TJSObject;
  LRow, LLabel, LControl: TJSElement;
  I, J, LCount, LSavedCount: Integer;
  LSeconds, LItemSeconds: Double;
  LWhole: Boolean;
begin
  BindSelectedTracks;
  FSourceEditor.Bind(FTracks, FSelections, not FConnected or FLoading);
  LCount := 0;
  LSavedCount := 0;
  LSeconds := 0;
  El('track-influences').innerHTML := '';
  for I := 0 to FSelections.length - 1 do
  begin
    LItem := Obj(FSelections[I]);
    if Str(LItem, 'selection') <> 'full' then Continue;
    Inc(LSavedCount);
    LItemSeconds := 0;
    LWhole := StudioIncluded(LItem);
    if LWhole then LItemSeconds := Num(LItem, 'frame_count') / Num(LItem, 'sample_rate')
    else
      for J := 0 to FSelections.length - 1 do
      begin
        LOther := Obj(FSelections[J]);
        if (StudioSourceKey(LOther) = StudioSourceKey(LItem)) and
          (Str(LOther, 'selection') <> 'full') and StudioIncluded(LOther) then
          LItemSeconds := LItemSeconds + (Num(LOther, 'end_frame') - Num(LOther, 'start_frame')) / Num(LItem, 'sample_rate');
      end;
    if LItemSeconds = 0 then Continue;
    Inc(LCount);
    LSeconds := LSeconds + LItemSeconds;
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
  FIncludedSeconds := LSeconds;
  El('selection-summary').textContent := IntToStr(LCount) + ' of ' + IntToStr(LSavedCount) +
    ' tracks · ' + StudioTime(LSeconds) + ' selected for learning';
  El('learning-label-state').textContent := '';
  if FLearningLabel <> '' then
    El('learning-label-state').textContent := 'Label: ' + FLearningLabel + ' · change a checkbox to choose manually';
  TJSHTMLButtonElement(El('choose-by-label')).disabled :=
    not FConnected or FLoading or (LSavedCount = 0);
  El('generate-summary').textContent := El('selection-summary').textContent;
  TJSHTMLInputElement(El('track-search')).disabled := not FConnected;
  TJSHTMLButtonElement(El('new-playlist')).disabled := FLoading or FSaving or FDirty or (FPendingWrite <> nil);
  TJSHTMLInputElement(El('playlist-name')).disabled := FLoading;
  DrawGeneration;
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
  FLearningLabel := Str(APlaylist, 'learning_label');
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
    LRow['classifications'] := Arr(LItem, 'classifications');
    if LRow['classifications'] = nil then LRow['classifications'] := TJSArray.new;
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
  FLearningLabel := '';
  ClearGeneration;
  FSnapshotHash := Str(AProject, 'snapshot_sha256');
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
    Notice('');
    TStudioDialog(El('playlists-dialog')).close;
    Draw;
    ShowStep('selection');
  except
    on E: Exception do Notice(E.Message, True);
  end;
  FLoading := False;
  Draw;
  if FConnected then RestoreGeneration;
end;
procedure TStudio.CatalogSaved;
begin Connect end;
procedure TStudio.Connect; async;
var LSession, LData, LPrepared, LDiscovery, LState: TJSObject;
  LTracks, LCollections: TJSArray; I: Integer; LLocal: String;
begin
  if FLoading then Exit;
  FLoading := True;
  try
    Notice('Opening your music…');
    LSession := await(TJSObject, Json('/api/session', 'GET', ''));
    FToken := Str(LSession, 'token');
    FStorageScope := Str(LSession, 'catalog_id');
    if FToken = '' then raise Exception.Create('Studio could not open a local session.');
    if FStorageScope = '' then raise Exception.Create('Studio and server versions differ. Reload after updating both.');
    LData := await(TJSObject, Json('/api/studio/sources', 'GET', ''));
    LTracks := Arr(LData, 'sources');
    if LTracks = nil then raise Exception.Create('Music catalog is unavailable.');
    LPrepared := await(TJSObject, Json('/api/studio/library', 'GET', ''));
    LDiscovery := await(TJSObject, Json('/api/studio/library-discovery', 'GET', ''));
    MergeDiscovery(LTracks, LDiscovery, LPrepared);
    FTracks := TJSArray.new;
    for I := 0 to LTracks.length - 1 do
    begin
      LCollections := Arr(Obj(LTracks[I]), 'collections');
      if (LCollections <> nil) and (LCollections.length > 0) then
        FTracks.push(LTracks[I]);
    end;
    LData := await(TJSObject, Json('/api/studio/projects', 'GET', ''));
    FProjects := Arr(LData, 'projects');
    DrawProjects;
    if (FProjectId = '') then
    begin
      LLocal := window.localStorage.getItem('pythian.studio.playlist.' + FStorageScope);
      if isString(LLocal) and (LLocal <> '') then
      begin
        LState := Obj(TJSJSON.parse(LLocal));
        if LState = nil then raise Exception.Create('Saved browser playlist is unreadable. Open a saved playlist to recover.');
        FProjectId := Str(LState, 'project_id');
        FRevision := Trunc(Num(LState, 'revision'));
        FName := Str(LState, 'name');
        FSelections := Arr(LState, 'selections');
        FLearningLabel := Str(LState, 'learning_label');
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
  if FConnected then RestoreGeneration;
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
    'generate-music': Generate;
    'cancel-generation': CancelGeneration;
    'reconnect-generation':
      if FJobWrite <> nil then Generate else PollGeneration;
    'new-playlist':
      begin
        if FDirty or FSaving or (FPendingWrite <> nil) then Exit;
        NewPlaylist;
        Draw;
        TStudioDialog(El('playlists-dialog')).close;
        ShowStep('library');
      end;
    'choose-by-label': OpenLearningLabel;
    'apply-learning-label': ApplyLearningLabel;
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
  if LControl.id = 'learning-label-choice' then
  begin
    PreviewLearningLabel;
    Exit;
  end;
  if LControl.id = 'playlist-name' then
  begin
    QueueSave;
    Exit;
  end;
  if LControl.id = 'track-search' then begin FSourceEditor.Search; Exit end;
  if (LControl.id = 'output-duration') or (LControl.id = 'output-duration-unit') then
  begin
    RememberGeneration;
    DrawGeneration;
    Exit;
  end;
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
function TStudio.UserInteraction(AEvent: TEventListenerEvent): Boolean;
begin
  { Big Boss: a late saved-run response may restore data, but must not take
    navigation away after the operator has started using the page. }
  FResumeOnConnect := False;
  Result := False;
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
  FResumeOnConnect := True;
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
  El('output-duration').addEventListener('change', @Edit);
  El('output-duration').addEventListener('input', @Edit);
  El('output-duration-unit').addEventListener('change', @Edit);
  El('learning-label-choice').addEventListener('change', @Edit);
  El('source-reconnect').addEventListener('click', @Click);
  El('capture-panel').addEventListener('close', @CaptureClosed);
  El('tab-library').addEventListener('keydown', @TabKey);
  El('tab-selection').addEventListener('keydown', @TabKey);
  El('tab-generate').addEventListener('keydown', @TabKey);
  document.addEventListener('play', @Playing, True);
  document.addEventListener('pointerdown', @UserInteraction, True);
  document.addEventListener('keydown', @UserInteraction, True);
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
