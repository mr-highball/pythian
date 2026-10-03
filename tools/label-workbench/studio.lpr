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

uses
  JS,
  Web,
  SysUtils,
  Math,
  pythian.studio.sources,
  pythian.studio.batches,
  pythian.studio.effects,
  pythian.studio.capture,
  pythian.studio.reviews,
  pythian.workspace.navigation,
  pythian.workspace.tabs,
  pythian.studio.&library.refresh;

type
  TStudioWindow = class external name 'Window' (TJSWindow)
    function fetch(const AUrl: String; const AOptions: TJSObject): TJSPromise; reintroduce;
  end;

  TStudio = class
  private
    FNavigation: TWorkspaceNavigation;
    FTabs: TWorkspaceTabs;
    FLibraryRefresh: TStudioLibraryRefresh;
    FSourceEditor: TStudioSourceEditor;
    FBatches: TStudioBatches;
    FEffects: TStudioEffects;
    FCapture: TStudioCapture;
    FReviews: TStudioReviews;
    FSavedProject: TJSObject;
    FToken: String;
    FProjectId: String;
    FRevision: Integer;
    FTracks: TJSArray;
    FProjects: TJSArray;
    FSelections: TJSArray;
    FDirty: Boolean;
    FBusy: Boolean;
    FConnected: Boolean;
    FEpoch: Integer;
    FPendingWrite: TJSObject;
    FConflict: Boolean;
    FCatalogRefreshPending: Boolean;
    function El(const AId: String): TJSElement;
    function Input(const AId: String): TJSHTMLInputElement;
    function AddText(AParent: TJSElement; const ATag, AText, AClass: String): TJSElement;
    function FetchApi(const APath, AMethod, ABody: String): TJSPromise;
    function FetchNavigation(const APath, AMethod, ABody: String;
      const ASignal: TJSObject): TJSPromise;
    procedure Connect; async;
    procedure LoadProject(const AId: String); async;
    procedure Save; async;
    procedure CatalogSaved;
    function UseNextBatch(APacket: TJSObject): TJSPromise;
    function ApplyNextBatch(APacket: TJSObject): Boolean; async;
    procedure ApplyProject(AProject: TJSObject);
    procedure NewDraft;
    procedure DrawProjects;
    procedure DrawTracks;
    procedure MergeDiscovery(ATracks: TJSArray; ADiscovery, APrepared: TJSObject);
    procedure UpdateSummary;
    procedure UpdateState;
    procedure Status(const AText: String; AError: Boolean = False);
    procedure Feedback(const AText: String; AError: Boolean = False);
    procedure Changed;
    procedure ClearErrors;
    procedure ErrorAt(const AId, AText: String);
    function BuildWrite: TJSObject;
    function FindSelection(const AHash: String): TJSObject;
    function FindTrack(const AHash: String): TJSObject;
    function MatchesWrite(AProject, AWrite: TJSObject): Boolean;
    function HandleEdit(AEvent: TEventListenerEvent): Boolean;
    function HandleNew(AEvent: TJSMouseEvent): Boolean;
    function HandleSave(AEvent: TJSMouseEvent): Boolean;
    function HandleReload(AEvent: TJSMouseEvent): Boolean;
    function HandleRetry(AEvent: TJSMouseEvent): Boolean;
    function HandleProject(AEvent: TEventListenerEvent): Boolean;
    function HandleSearch(AEvent: TEventListenerEvent): Boolean;
    function HandleBeforeUnload(AEvent: TEventListenerEvent): Boolean;
    function HandleSubmit(AEvent: TEventListenerEvent): Boolean;
    function HandleAnyPlay(AEvent: TEventListenerEvent): Boolean;
    function HandleStart(AEvent: TJSMouseEvent): Boolean;
  public
    procedure Run;
  end;

function Obj(AValue: JSValue): TJSObject;
begin
  Result := TJSObject(AValue);
end;

function Str(AObject: TJSObject; const AName: String): String;
begin
  Result := '';
  if (AObject <> nil) and isString(AObject[AName]) then
  begin
    Result := String(AObject[AName]);
  end;
end;

function Num(AObject: TJSObject; const AName: String): Double;
begin
  Result := 0;
  if (AObject <> nil) and isNumber(AObject[AName]) then
  begin
    Result := Double(AObject[AName]);
  end;
end;

function Arr(AObject: TJSObject; const AName: String): TJSArray;
begin
  Result := nil;
  if (AObject <> nil) and isArray(AObject[AName]) then
  begin
    Result := TJSArray(AObject[AName]);
  end;
end;

function CloneObject(AObject: TJSObject): TJSObject;
begin
  Result := Obj(TJSJSON.parse(TJSJSON.stringify(AObject)));
end;

function TimeText(AMilliseconds: Double): String;
var
  LMilliseconds: NativeInt;
  LMinutes: NativeInt;
  LSeconds: NativeInt;
  LFraction: NativeInt;
begin
  LMilliseconds := Trunc(Max(0, AMilliseconds));
  LMinutes := LMilliseconds div 60000;
  LSeconds := (LMilliseconds div 1000) mod 60;
  LFraction := LMilliseconds mod 1000;
  Result := IntToStr(LMinutes) + ':' + Format('%.2d', [LSeconds]);
  if LFraction <> 0 then
  begin
    Result := Result + '.' + Format('%.3d', [LFraction]);
  end;
end;

function ParseTime(const AText: String; out AMilliseconds: Double): Boolean;
var
  LText: String;
  LColon: Integer;
  LDot: Integer;
  LIndex: Integer;
  LMinutes: Double;
  LSeconds: Integer;
  LFraction: String;
  LNumber: String;
begin
  Result := False;
  AMilliseconds := 0;
  LText := Trim(AText);
  LColon := Pos(':', LText);
  if (LColon < 2) or (Length(LText) > 24) then
  begin
    Exit;
  end;
  LMinutes := 0;
  for LIndex := 1 to LColon - 1 do
  begin
    if not (LText[LIndex] in ['0'..'9']) then
    begin
      Exit;
    end;
    LMinutes := LMinutes * 10 + Ord(LText[LIndex]) - Ord('0');
  end;
  LNumber := Copy(LText, LColon + 1, MaxInt);
  LDot := Pos('.', LNumber);
  LFraction := '';
  if LDot > 0 then
  begin
    LFraction := Copy(LNumber, LDot + 1, MaxInt);
    LNumber := Copy(LNumber, 1, LDot - 1);
    if (Length(LFraction) < 1) or (Length(LFraction) > 3) then
    begin
      Exit;
    end;
  end;
  if Length(LNumber) <> 2 then
  begin
    Exit;
  end;
  for LIndex := 1 to Length(LNumber) do
  begin
    if not (LNumber[LIndex] in ['0'..'9']) then
    begin
      Exit;
    end;
  end;
  for LIndex := 1 to Length(LFraction) do
  begin
    if not (LFraction[LIndex] in ['0'..'9']) then
    begin
      Exit;
    end;
  end;
  LSeconds := StrToInt(LNumber);
  if LSeconds > 59 then
  begin
    Exit;
  end;
  while Length(LFraction) < 3 do
  begin
    LFraction := LFraction + '0';
  end;
  AMilliseconds := LMinutes * 60000 + LSeconds * 1000 + StrToInt(LFraction);
  Result := not IsNan(AMilliseconds) and not IsInfinite(AMilliseconds) and
    (AMilliseconds <= 9007199254740991);
end;

function TrackTitle(ATrack: TJSObject): String;
begin
  Result := Str(ATrack, 'title');
  if Result = '' then
  begin
    Result := Str(ATrack, 'original_name');
  end;
  if Result = '' then
  begin
    Result := 'Imported recording';
  end;
end;

function TStudio.El(const AId: String): TJSElement;
begin
  Result := document.getElementById(AId);
  if Result = nil then
  begin
    raise Exception.Create('Missing Studio control: ' + AId);
  end;
end;

function TStudio.Input(const AId: String): TJSHTMLInputElement;
begin
  Result := TJSHTMLInputElement(El(AId));
end;

function TStudio.AddText(AParent: TJSElement; const ATag, AText, AClass: String): TJSElement;
begin
  Result := document.createElement(ATag);
  Result.textContent := AText;
  if AClass <> '' then
  begin
    Result.className := AClass;
  end;
  AParent.appendChild(Result);
end;

function NetworkFailure(AReason: JSValue): JSValue;
begin
  raise Exception.Create('Connection interrupted. Reconnect and retry.');
end;

function TStudio.FetchApi(const APath, AMethod, ABody: String): TJSPromise;
begin
  Result := FetchNavigation(APath, AMethod, ABody, nil);
end;

function TStudio.FetchNavigation(const APath, AMethod, ABody: String;
  const ASignal: TJSObject): TJSPromise;
var
  LOptions: TJSObject;
  LHeaders: TJSObject;
begin
  LOptions := TJSObject.new;
  LHeaders := TJSObject.new;
  LOptions['method'] := AMethod;
  LOptions['mode'] := 'same-origin';
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
  if (APath = '/api/studio/cancel') and (AMethod = 'POST') then
    LOptions['keepalive'] := True;
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
  Result := TStudioWindow(window).fetch(window.location.origin + APath, LOptions).catch(@NetworkFailure);
  if (AMethod = 'POST') and ((APath = '/api/studio/review') or
    (APath = '/api/studio/review/response')) then
  begin
    Result := Result._then(@WorkspaceResponseSaved);
  end;
end;

procedure TStudio.Status(const AText: String; AError: Boolean);
begin
  El('connection').textContent := AText;
  if AError then
  begin
    El('connection').className := 'notice error';
  end
  else
  begin
    El('connection').className := 'notice';
  end;
end;

procedure TStudio.Feedback(const AText: String; AError: Boolean);
begin
  El('save-feedback').textContent := AText;
  if AError then
  begin
    El('save-feedback').className := 'field-error';
  end
  else
  begin
    El('save-feedback').className := 'hint';
  end;
end;

procedure TStudio.ClearErrors;
begin
  El('name-error').setAttribute('hidden', '');
  El('qualities-error').setAttribute('hidden', '');
  El('tracks-error').setAttribute('hidden', '');
  El('style-name').removeAttribute('aria-invalid');
  El('style-qualities').removeAttribute('aria-invalid');
end;

procedure TStudio.ErrorAt(const AId, AText: String);
begin
  El(AId).textContent := AText;
  El(AId).removeAttribute('hidden');
end;

procedure TStudio.Changed;
begin
  FDirty := True;
  FBatches.SetProject(FSavedProject, True);
  FPendingWrite := nil;
  FConflict := False;
  UpdateSummary;
  UpdateState;
end;

procedure TStudio.UpdateState;
var
  LControls: array of String;
  LIndex: Integer;
begin
  FSourceEditor.SetDisabled(FBusy or not FConnected);
  LControls := ['style-name', 'style-qualities', 'learning-mode', 'new-draft',
    'draft-list', 'track-search'];
  for LIndex := 0 to High(LControls) do
  begin
    if FBusy or not FConnected then
    begin
      El(LControls[LIndex]).setAttribute('disabled', '');
    end
    else
    begin
      El(LControls[LIndex]).removeAttribute('disabled');
    end;
  end;
  TJSHTMLButtonElement(El('save-draft')).disabled := FBusy or not FConnected or
    ((not FDirty) and (FRevision > 0));
  TJSHTMLButtonElement(El('reload-draft')).disabled := FBusy or not FConnected or (FRevision = 0);
  if FBusy then
  begin
    if FPendingWrite <> nil then
    begin
      El('draft-state').textContent := 'Saving…';
    end
    else
    begin
      El('draft-state').textContent := 'Loading…';
    end;
    El('draft-state').className := 'state';
  end
  else if FConflict then
  begin
    El('draft-state').textContent := 'Save conflict';
    El('draft-state').className := 'state dirty';
  end
  else if FDirty then
  begin
    El('draft-state').textContent := 'Unsaved changes';
    El('draft-state').className := 'state dirty';
  end
  else if FRevision > 0 then
  begin
    El('draft-state').textContent := 'Saved';
    El('draft-state').className := 'state saved';
  end
  else
  begin
    El('draft-state').textContent := 'Not saved';
    El('draft-state').className := 'state';
  end;
  if FCatalogRefreshPending and not FBusy then
  begin
    FCatalogRefreshPending := False;
    Connect;
  end;
end;

function TStudio.FindSelection(const AHash: String): TJSObject;
var
  LIndex: Integer;
begin
  Result := nil;
  for LIndex := 0 to FSelections.length - 1 do
  begin
    if Str(Obj(FSelections[LIndex]), 'source_sha256') = AHash then
    begin
      Result := Obj(FSelections[LIndex]);
      Exit;
    end;
  end;
end;

function TStudio.FindTrack(const AHash: String): TJSObject;
var
  LIndex: Integer;
begin
  Result := nil;
  for LIndex := 0 to FTracks.length - 1 do
  begin
    if Str(Obj(FTracks[LIndex]), 'source_sha256') = AHash then
    begin
      Result := Obj(FTracks[LIndex]);
      Exit;
    end;
  end;
end;

procedure TStudio.NewDraft;
begin
  Inc(FEpoch);
  FSavedProject := nil;
  FBatches.SetProject(nil, False);
  FProjectId := 'style-' + IntToStr(TJSDate.now) + '-' + IntToStr(Random(1000000000));
  FRevision := 0;
  FDirty := False;
  FPendingWrite := nil;
  FConflict := False;
  FSelections := TJSArray.new;
  Input('style-name').value := '';
  TJSHTMLTextAreaElement(El('style-qualities')).value := '';
  Input('learning-mode').value := 'raw_acoustic';
  TJSHTMLSelectElement(El('draft-list')).value := '';
  ClearErrors;
  Feedback('Nothing has been saved yet.');
  El('draft-details').textContent := 'New draft · not trained. Source details will be verified before training.';
  DrawTracks;
  UpdateSummary;
  UpdateState;
end;

procedure TStudio.DrawProjects;
var
  LSelect: TJSHTMLSelectElement;
  LOption: TJSHTMLOptionElement;
  LIndex: Integer;
  LProject: TJSObject;
begin
  LSelect := TJSHTMLSelectElement(El('draft-list'));
  LSelect.innerHTML := '';
  LOption := TJSHTMLOptionElement(document.createElement('option'));
  LOption.value := '';
  LOption.textContent := 'New project';
  LSelect.appendChild(LOption);
  for LIndex := 0 to FProjects.length - 1 do
  begin
    LProject := Obj(FProjects[LIndex]);
    LOption := TJSHTMLOptionElement(document.createElement('option'));
    LOption.value := Str(LProject, 'project_id');
    LOption.textContent := Str(LProject, 'name');
    LSelect.appendChild(LOption);
  end;
  LSelect.value := FProjectId;
end;

procedure TStudio.UpdateSummary;
var
  LIndex: Integer;
  LSelected: TJSObject;
  LTrack: TJSObject;
  LSeconds: Double;
  LCount: Integer;
  LSelectedCount: Integer;
  LEvaluation: Integer;
  LName: String;
  LRoute: String;
  LHashes: TJSArray;
begin
  LHashes := TJSArray.new;
  case Input('learning-mode').value of
    'raw_acoustic': LRoute := 'Acoustic recombination';
    'reference_events': LRoute := 'Reference-assisted notes';
    'inferred_events': LRoute := 'Inferred notes (acceptance pending)';
  else
    LRoute := 'Unrecognized preference';
  end;
  El('support-detail').textContent := 'Saved route preference: ' + LRoute +
    '. This does not start training. Source details are catalog snapshots; recordings must be verified before training.';
  LSeconds := 0;
  LCount := 0;
  LSelectedCount := 0;
  LEvaluation := 0;
  for LIndex := 0 to FSelections.length - 1 do
  begin
    LSelected := Obj(FSelections[LIndex]);
    if not StudioIncluded(LSelected) then Continue;
    Inc(LSelectedCount);
    LTrack := FindTrack(Str(LSelected, 'source_sha256'));
    if (LTrack <> nil) and (Num(LTrack, 'sample_rate') > 0) then
    begin
      if Str(LSelected, 'selection') = 'full' then
      begin
        LSeconds := LSeconds + Num(LTrack, 'frame_count') / Num(LTrack, 'sample_rate');
      end
      else if not Boolean(LSelected['range_invalid']) then
      begin
        LSeconds := LSeconds + (Num(LSelected, 'end_frame') - Num(LSelected, 'start_frame')) /
          Num(LTrack, 'sample_rate');
      end;
      if LHashes.indexOf(Str(LSelected, 'source_sha256')) < 0 then
      begin
        LHashes.push(Str(LSelected, 'source_sha256'));
        Inc(LCount);
      end;
      if Str(LTrack, 'partition') = 'evaluation' then
      begin
        Inc(LEvaluation);
      end;
    end;
  end;
  if (LSeconds > 0) and (LSeconds < 60) then
  begin
    El('selected-duration').textContent := FormatFloat('0.###', LSeconds) + ' seconds';
  end
  else
  begin
    El('selected-duration').textContent := FormatFloat('0.0', LSeconds / 60) + ' minutes';
  end;
  El('selected-count').textContent := IntToStr(LCount);
  if LCount = 0 then
  begin
    El('selection-summary').textContent := 'Nothing checked for training. Choose music in Collection.';
  end
  else
  begin
    El('selection-summary').textContent := IntToStr(LSelectedCount) + ' checked for training · ' + TimeText(LSeconds * 1000);
    if LEvaluation > 0 then
    begin
      El('selection-summary').textContent := El('selection-summary').textContent + ' ' +
        IntToStr(LEvaluation) + ' evaluation-only recording(s) are reserved from training.';
    end;
  end;
  El('collection-training-summary').textContent := El('selection-summary').textContent;
  El('generation-training-summary').textContent := El('selection-summary').textContent;
  LName := Trim(Input('style-name').value);
  if LName = '' then
  begin
    El('draft-caption').textContent := 'Give your style a name, then select its recordings.';
  end
  else
  begin
    El('draft-caption').textContent := LName + ' · ' + IntToStr(LCount) +
      ' recording(s), ' + IntToStr(LSelectedCount) + ' checked for training.';
  end;
end;

procedure TStudio.DrawTracks;
begin
  FSourceEditor.Bind(FTracks, FSelections, FBusy or not FConnected);
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

procedure TStudio.ApplyProject(AProject: TJSObject);
var
  LSources: TJSArray;
  LSource: TJSObject;
  LSelection: TJSObject;
  LIndex: Integer;
  LIncludedCount: Integer;
begin
  if (Str(AProject, 'format') <> 'pythian.studio.project.v1') or
    (Str(AProject, 'status') <> 'draft') or
    (Str(AProject, 'training_status') <> 'not_started') or
    Boolean(AProject['model_available']) then
  begin
    raise Exception.Create('This page supports untrained style drafts only.');
  end;
  LSources := Arr(AProject, 'sources');
  LIncludedCount := 0;
  if LSources <> nil then
  begin
    LIncludedCount := LSources.length;
    LSources := LSources.slice;
    if Arr(AProject, 'parked_sources') <> nil then
      LSources := LSources.concat(Arr(AProject, 'parked_sources'));
  end;
  if (LSources = nil) or (LSources.length < 1) or (LSources.length > 64) then
  begin
    raise Exception.Create('The saved draft has an unsupported source selection.');
  end;
  { Validate the response before replacing an unsaved draft. }
  if (Str(AProject, 'project_id') = '') or (Num(AProject, 'revision') < 1) then
  begin
    raise Exception.Create('The saved draft identity is unsupported.');
  end;
  for LIndex := 0 to LSources.length - 1 do
  begin
    LSource := Obj(LSources[LIndex]);
    if (Length(Str(LSource, 'source_sha256')) <> 64) or
      (Num(LSource, 'sample_rate') <= 0) or
      ((Str(LSource, 'selection') <> 'full') and (Str(LSource, 'selection') <> 'range')) or
      (Num(LSource, 'start_frame') < 0) or
      (Num(LSource, 'end_frame') <= Num(LSource, 'start_frame')) or
      (Num(LSource, 'end_frame') > Num(LSource, 'frame_count')) or
      (Str(LSource, 'partition') = 'evaluation') then
    begin
      raise Exception.Create('The saved source selection is unsupported.');
    end;
  end;
  FSelections := TJSArray.new;
  for LIndex := 0 to LSources.length - 1 do
  begin
    LSource := Obj(LSources[LIndex]);
    if FindTrack(Str(LSource, 'source_sha256')) = nil then
    begin
      FTracks.push(CloneObject(LSource));
    end;
    LSelection := TJSObject.new;
    LSelection['source_sha256'] := Str(LSource, 'source_sha256');
    LSelection['selection'] := Str(LSource, 'selection');
    LSelection['start_frame'] := Num(LSource, 'start_frame');
    LSelection['end_frame'] := Num(LSource, 'end_frame');
    LSelection['start_text'] := TimeText(Num(LSource, 'start_frame') * 1000 / Num(LSource, 'sample_rate'));
    LSelection['end_text'] := TimeText(Num(LSource, 'end_frame') * 1000 / Num(LSource, 'sample_rate'));
    LSelection['range_invalid'] := False;
    LSelection['included'] := LIndex < LIncludedCount;
    if Arr(LSource, 'classifications') <> nil then
    begin
      LSelection['classifications'] := Arr(LSource, 'classifications').slice;
    end
    else
    begin
      LSelection['classifications'] := TJSArray.new;
    end;
    FSelections.push(LSelection);
  end;
  FProjectId := Str(AProject, 'project_id');
  FRevision := Trunc(Num(AProject, 'revision'));
  Input('style-name').value := Str(AProject, 'name');
  TJSHTMLTextAreaElement(El('style-qualities')).value := Str(AProject, 'style_intent');
  Input('learning-mode').value := Str(AProject, 'learning_mode');
  FSavedProject := CloneObject(AProject);
  FBatches.SetProject(FSavedProject, False);
  FDirty := False;
  FPendingWrite := nil;
  FConflict := False;
  ClearErrors;
  El('draft-details').textContent := 'Draft ' + FProjectId + ' · saved version ' +
    IntToStr(FRevision) + ' · not trained. Source verification is pending before training.';
  DrawProjects;
  DrawTracks;
  UpdateSummary;
  UpdateState;
end;

function TStudio.BuildWrite: TJSObject;
var
  LSources: TJSArray;
  LParked: TJSArray;
  LSource: TJSObject;
  LSelection: TJSObject;
  LIndex: Integer;
  LValid: Boolean;
  LName: String;
  LIntent: String;
begin
  Result := nil;
  ClearErrors;
  LName := Trim(Input('style-name').value);
  LIntent := TJSHTMLTextAreaElement(El('style-qualities')).value;
  LValid := True;
  if (Length(LName) < 1) or (Length(LName) > 128) then
  begin
    ErrorAt('name-error', 'Give your project a name, up to 128 characters.');
    Input('style-name').setAttribute('aria-invalid', 'true');
    RevealWorkspaceControl(El('style-name'));
    Input('style-name').focus;
    LValid := False;
  end;
  if Length(LIntent) > 2048 then
  begin
    ErrorAt('qualities-error', 'Keep your description within 2,048 characters.');
    El('style-qualities').setAttribute('aria-invalid', 'true');
    LValid := False;
  end;
  if (FSelections.length < 1) or (FSelections.length > 64) then
  begin
    ErrorAt('tracks-error', 'Select 1 to 64 passages from at most 32 recordings.');
    LValid := False;
  end;
  for LIndex := 0 to FSelections.length - 1 do
  begin
    if Boolean(Obj(FSelections[LIndex])['range_invalid']) then
    begin
      ErrorAt('tracks-error', 'Check the highlighted time ranges before saving.');
      LValid := False;
    end;
  end;
  if not LValid then
  begin
    if not El('name-error').hasAttribute('hidden') then
    begin
      RevealWorkspaceControl(El('style-name'));
      Input('style-name').focus;
    end
    else if not El('qualities-error').hasAttribute('hidden') then
    begin
      RevealWorkspaceControl(El('style-qualities'));
      TJSHTMLElement(El('style-qualities')).focus;
    end
    else
    begin
      RevealWorkspaceControl(El('tracks-error'));
      El('tracks-error').setAttribute('tabindex', '-1');
      TJSHTMLElement(El('tracks-error')).focus;
    end;
    Exit;
  end;
  Result := TJSObject.new;
  Result['format'] := 'pythian.studio.project.write.v1';
  Result['project_id'] := FProjectId;
  Result['expected_revision'] := FRevision;
  Result['name'] := LName;
  Result['style_intent'] := LIntent;
  Result['learning_mode'] := Input('learning-mode').value;
  LSources := TJSArray.new;
  LParked := TJSArray.new;
  for LIndex := 0 to FSelections.length - 1 do
  begin
    LSelection := Obj(FSelections[LIndex]);
    LSource := TJSObject.new;
    LSource['source_sha256'] := Str(LSelection, 'source_sha256');
    LSource['selection'] := Str(LSelection, 'selection');
    LSource['classifications'] := Arr(LSelection, 'classifications');
    if Str(LSelection, 'selection') = 'range' then
    begin
      LSource['start_frame'] := Num(LSelection, 'start_frame');
      LSource['end_frame'] := Num(LSelection, 'end_frame');
    end;
    if StudioIncluded(LSelection) then
      LSources.push(LSource)
    else
      LParked.push(LSource);
  end;
  Result['sources'] := LSources;
  Result['parked_sources'] := LParked;
end;

function TStudio.MatchesWrite(AProject, AWrite: TJSObject): Boolean;
var
  LSavedSources: TJSArray;
  LWriteSources: TJSArray;
  LIndex: Integer;
  LSaved: TJSObject;
  LWrite: TJSObject;
begin
  Result := False;
  if (Str(AProject, 'project_id') <> Str(AWrite, 'project_id')) or
    (Str(AProject, 'name') <> Str(AWrite, 'name')) or
    (Str(AProject, 'style_intent') <> Str(AWrite, 'style_intent')) or
    (Str(AProject, 'learning_mode') <> Str(AWrite, 'learning_mode')) then
  begin
    Exit;
  end;
  LSavedSources := Arr(AProject, 'sources');
  LWriteSources := Arr(AWrite, 'sources');
  if (LSavedSources = nil) or (LWriteSources = nil) or
    (LSavedSources.length <> LWriteSources.length) then Exit;
  LSavedSources := LSavedSources.slice;
  LWriteSources := LWriteSources.slice;
  if Arr(AProject, 'parked_sources') <> nil then
    LSavedSources := LSavedSources.concat(Arr(AProject, 'parked_sources'));
  if Arr(AWrite, 'parked_sources') <> nil then
    LWriteSources := LWriteSources.concat(Arr(AWrite, 'parked_sources'));
  if (LSavedSources = nil) or (LWriteSources = nil) or
    (LSavedSources.length <> LWriteSources.length) then
  begin
    Exit;
  end;
  for LIndex := 0 to LWriteSources.length - 1 do
  begin
    LSaved := Obj(LSavedSources[LIndex]);
    LWrite := Obj(LWriteSources[LIndex]);
    if (Str(LSaved, 'source_sha256') <> Str(LWrite, 'source_sha256')) or
      (Str(LSaved, 'selection') <> Str(LWrite, 'selection')) then
    begin
      Exit;
    end;
    if TJSJSON.stringify(LSaved['classifications']) <>
      TJSJSON.stringify(LWrite['classifications']) then
    begin
      Exit;
    end;
    if (Str(LWrite, 'selection') = 'range') and
      ((Num(LSaved, 'start_frame') <> Num(LWrite, 'start_frame')) or
      (Num(LSaved, 'end_frame') <> Num(LWrite, 'end_frame'))) then
    begin
      Exit;
    end;
  end;
  Result := True;
end;

procedure TStudio.Connect; async;
var
  LResponse: TJSResponse;
  LData: TJSObject;
  LPrepared: TJSObject;
  LTracks: TJSArray;
  LProjects: TJSArray;
  LEpoch: Integer;
  LTimer: NativeInt;
  LIndex: Integer;
  LOldTrack: TJSObject;
  LOther: Integer;
  LExists: Boolean;
begin
  if FBusy then
  begin
    Exit;
  end;
  Inc(FEpoch);
  LEpoch := FEpoch;
  FBusy := True;
  FConnected := False;
  FLibraryRefresh.SetConnected(False);
  FToken := '';
  UpdateState;
  Status('Connecting to your catalog…');
  El('retry').setAttribute('hidden', '');
  LTimer := window.setTimeout(
    procedure()
    begin
      if LEpoch = FEpoch then
      begin
        Inc(FEpoch);
        FBusy := False;
        FConnected := False;
        FNavigation.ConnectionFailed;
        UpdateState;
        Status('Connection is taking too long. Your edits are still here; retry when ready.', True);
        El('retry').removeAttribute('hidden');
      end;
    end, 15000);
  try
    LResponse := await(TJSResponse, FetchApi('/api/session', 'GET', ''));
    if LEpoch <> FEpoch then
    begin
      Exit;
    end;
    if LResponse.status <> 200 then
    begin
      raise Exception.Create('Connection could not be established.');
    end;
    LData := await(TJSObject, LResponse.json());
    if LEpoch <> FEpoch then
    begin
      Exit;
    end;
    FToken := Str(LData, 'token');
    if FToken = '' then
    begin
      raise Exception.Create('Connection could not be established.');
    end;
    FNavigation.Start;
    LResponse := await(TJSResponse, FetchApi('/api/studio/sources', 'GET', ''));
    if LEpoch <> FEpoch then
    begin
      Exit;
    end;
    if LResponse.status <> 200 then
    begin
      raise Exception.Create('Recordings could not be loaded.');
    end;
    LData := await(TJSObject, LResponse.json());
    if LEpoch <> FEpoch then
    begin
      Exit;
    end;
    LTracks := Arr(LData, 'sources');
    if (Str(LData, 'format') <> 'pythian.studio.sources.v1') or (LTracks = nil) then
    begin
      raise Exception.Create('The recording list is not supported by this Studio.');
    end;
    LResponse := await(TJSResponse, FetchApi('/api/studio/library', 'GET', ''));
    if LEpoch <> FEpoch then Exit;
    if LResponse.status <> 200 then
      raise Exception.Create('Prepared recording details could not be loaded.');
    LPrepared := await(TJSObject, LResponse.json());
    if LEpoch <> FEpoch then Exit;
    LResponse := await(TJSResponse, FetchApi('/api/studio/library-discovery', 'GET', ''));
    if LEpoch <> FEpoch then
    begin
      Exit;
    end;
    if LResponse.status <> 200 then
    begin
      raise Exception.Create('Library refresh details could not be loaded.');
    end;
    LData := await(TJSObject, LResponse.json());
    if LEpoch <> FEpoch then
    begin
      Exit;
    end;
    MergeDiscovery(LTracks, LData, LPrepared);
    El('library-summary').textContent :=
      IntToStr(Trunc(Num(LData, 'available_count'))) + ' original files in ' +
      IntToStr(Trunc(Num(LData, 'collection_count'))) + ' collections · ' +
      IntToStr(Trunc(Num(LData, 'missing_count'))) + ' missing · ' +
      IntToStr(Trunc(Num(LData, 'unsupported_count'))) + ' unsupported. ' +
      'Metadata only. Recordings are prepared when you add them.';
    if Num(LData, 'revision') = 0 then
    begin
      El('collection-empty-state').textContent := 'Your collection folders have not been scanned yet. Refresh the library to discover them.';
      El('collection-empty-state').removeAttribute('hidden');
    end
    else if Num(LData, 'collection_count') = 0 then
    begin
      El('collection-empty-state').textContent := 'No collection folders were found. Add a folder with WAV recordings, then refresh.';
      El('collection-empty-state').removeAttribute('hidden');
    end
    else if Num(LData, 'available_count') = 0 then
    begin
      El('collection-empty-state').textContent := 'Collection folders were found, but no WAV recordings are available. Add recordings, then refresh.';
      El('collection-empty-state').removeAttribute('hidden');
    end
    else
    begin
      El('collection-empty-state').setAttribute('hidden', '');
    end;
    LResponse := await(TJSResponse, FetchApi('/api/studio/projects', 'GET', ''));
    if LEpoch <> FEpoch then
    begin
      Exit;
    end;
    if LResponse.status <> 200 then
    begin
      raise Exception.Create('Saved projects could not be loaded.');
    end;
    LData := await(TJSObject, LResponse.json());
    if LEpoch <> FEpoch then
    begin
      Exit;
    end;
    LProjects := Arr(LData, 'projects');
    if (Str(LData, 'format') <> 'pythian.studio.projects.v1') or (LProjects = nil) then
    begin
      raise Exception.Create('The saved project list is not supported by this Studio.');
    end;
    for LIndex := 0 to FSelections.length - 1 do
    begin
      LOldTrack := FindTrack(Str(Obj(FSelections[LIndex]), 'source_sha256'));
      if LOldTrack <> nil then
      begin
        LExists := False;
        for LOther := 0 to LTracks.length - 1 do
        begin
          if Str(Obj(LTracks[LOther]), 'source_sha256') = Str(LOldTrack, 'source_sha256') then
          begin
            LExists := True;
          end;
        end;
        if not LExists then
        begin
          LTracks.push(CloneObject(LOldTrack));
        end;
      end;
    end;
    FTracks := LTracks;
    FProjects := LProjects;
    El('start-library-summary').textContent := IntToStr(FTracks.length) + ' recordings available';
    FConnected := True;
    FLibraryRefresh.SetConnected(True);
    FLibraryRefresh.Refresh;
    FBatches.Refresh;
    FReviews.Refresh;
    FCapture.Refresh;
    Status('Connected to your library.');
    DrawProjects;
  except
    on LError: Exception do
    begin
      if LEpoch = FEpoch then
      begin
        Status(LError.Message + ' Your edits are still here.', True);
        FNavigation.ConnectionFailed;
        El('retry').removeAttribute('hidden');
      end;
    end;
  else
    begin
      if LEpoch = FEpoch then
      begin
        Status('Connection failed. Your edits are still here; retry when ready.', True);
        FNavigation.ConnectionFailed;
        El('retry').removeAttribute('hidden');
      end;
    end;
  end;
  window.clearTimeout(LTimer);
  if LEpoch = FEpoch then
  begin
    FBusy := False;
    DrawTracks;
    UpdateSummary;
    UpdateState;
  end;
end;

procedure TStudio.CatalogSaved;
begin
  FCatalogRefreshPending := True;
  if not FBusy then
  begin
    FCatalogRefreshPending := False;
    Connect;
  end;
end;

function TStudio.UseNextBatch(APacket: TJSObject): TJSPromise;
begin
  Result := ApplyNextBatch(APacket);
end;

function TStudio.ApplyNextBatch(APacket: TJSObject): Boolean; async;
var
  LRequest: TJSObject;
  LResponse: TJSResponse;
  LProject: TJSObject;
begin
  Result := False;
  if FBusy or not FConnected then
  begin
    raise Exception.Create('Wait for the current project operation to finish.');
  end;
  if FDirty then
  begin
    raise Exception.Create('Save your project edits before preparing a different batch.');
  end;
  LRequest := TJSObject(APacket['request']);
  FBusy := True;
  UpdateState;
  try
    LResponse := await(TJSResponse, FetchApi('/api/studio/project-revision?id=' +
      encodeURIComponent(Str(LRequest, 'project_id')) + '&revision=' +
      IntToStr(Trunc(Num(LRequest, 'project_revision'))), 'GET', ''));
    if LResponse.status <> 200 then
    begin
      raise Exception.Create('The original project version could not be loaded. Your current setup remains.');
    end;
    LProject := await(TJSObject, LResponse.json());
    if Str(LProject, 'snapshot_sha256') <> Str(LRequest, 'project_snapshot_sha256') then
    begin
      raise Exception.Create('The project version differs from the chosen audition.');
    end;
    ApplyProject(LProject);
    FBatches.ApplyNextBatch(LRequest);
    Status('Next-batch settings are ready. Change what you want, then generate.');
    RevealWorkspaceControl(El('batch-duration'));
    SelectWorkspacePane('prepare', True);
    Result := True;
  finally
    FBusy := False;
    UpdateState;
  end;
end;

procedure TStudio.LoadProject(const AId: String); async;
var
  LResponse: TJSResponse;
  LData: TJSObject;
  LEpoch: Integer;
  LTimer: NativeInt;
begin
  if FBusy or not FConnected then
  begin
    Exit;
  end;
  if FDirty and not window.confirm('Discard unsaved changes and load the saved project?') then
  begin
    TJSHTMLSelectElement(El('draft-list')).value := FProjectId;
    Exit;
  end;
  FBusy := True;
  Inc(FEpoch);
  LEpoch := FEpoch;
  LTimer := window.setTimeout(
    procedure()
    begin
      if LEpoch = FEpoch then
      begin
        Inc(FEpoch);
        FBusy := False;
        DrawTracks;
        UpdateState;
        Feedback('Load is taking too long. Your current edits are still here. Retry when ready.', True);
        El('retry').removeAttribute('hidden');
      end;
    end, 15000);
  UpdateState;
  DrawTracks;
  Feedback('Loading saved draft…');
  try
    LResponse := await(TJSResponse, FetchApi('/api/studio/project?id=' +
      encodeURIComponent(AId), 'GET', ''));
    if LEpoch <> FEpoch then
    begin
      Exit;
    end;
    if LResponse.status <> 200 then
    begin
      raise Exception.Create('Saved draft could not be loaded.');
    end;
    LData := await(TJSObject, LResponse.json());
    if LEpoch <> FEpoch then
    begin
      Exit;
    end;
    ApplyProject(LData);
    Feedback('Saved draft loaded.');
  except
    on LError: Exception do
    begin
      if LEpoch = FEpoch then
      begin
        Feedback(LError.Message + ' Your current selections are still here.', True);
      end;
    end;
  else
    begin
      if LEpoch = FEpoch then
      begin
        Feedback('Draft could not be loaded. Your current selections are still here.', True);
      end;
    end;
  end;
  window.clearTimeout(LTimer);
  if LEpoch = FEpoch then
  begin
    FBusy := False;
    DrawTracks;
    UpdateState;
  end;
end;

procedure TStudio.Save; async;
var
  LWrite: TJSObject;
  LResponse: TJSResponse;
  LData: TJSObject;
  LEpoch: Integer;
  LTimer: NativeInt;
  LIndex: Integer;
  LFound: Boolean;
  LMessage: String;
  LSaved: Boolean;
begin
  if FBusy or not FConnected then
  begin
    Exit;
  end;
  if FPendingWrite <> nil then
  begin
    LWrite := FPendingWrite;
  end
  else
  begin
    LWrite := BuildWrite;
  end;
  if LWrite = nil then
  begin
    Feedback('Check the highlighted fields before saving.', True);
    Exit;
  end;
  FPendingWrite := CloneObject(LWrite);
  FBusy := True;
  Inc(FEpoch);
  LEpoch := FEpoch;
  LTimer := window.setTimeout(
    procedure()
    begin
      if LEpoch = FEpoch then
      begin
        Inc(FEpoch);
        FBusy := False;
        DrawTracks;
        UpdateState;
        Feedback('Save is taking too long. Your edits are still here. Retry Save draft to confirm or save the same draft.', True);
        El('retry').removeAttribute('hidden');
      end;
    end, 15000);
  UpdateState;
  DrawTracks;
  Feedback('Saving draft…');
  LSaved := False;
  LMessage := 'Save could not be confirmed. Your edits are still here. Retry Save draft.';
  try
    LResponse := await(TJSResponse, FetchApi('/api/studio/project', 'POST', TJSJSON.stringify(LWrite)));
    if LEpoch <> FEpoch then
    begin
      Exit;
    end;
    if LResponse.status <> 200 then
    begin
      if LResponse.status = 409 then
      begin
        FConflict := True;
        LMessage := 'Save conflict: the store is busy or the saved draft changed. Your edits are still here. Retry when idle; reload if the conflict remains.';
      end
      else if (LResponse.status = 400) or (LResponse.status = 422) then
      begin
        LMessage := 'Draft rejected. Check its name and time ranges, and choose training recordings. Your edits are still here.';
      end;
      raise Exception.Create(LMessage);
    end;
    LData := await(TJSObject, LResponse.json());
    if LEpoch <> FEpoch then
    begin
      Exit;
    end;
    LSaved := MatchesWrite(LData, LWrite);
  except
    on LError: Exception do
    begin
      LSaved := False;
    end;
  else
    begin
      LSaved := False;
    end;
  end;
  if LEpoch <> FEpoch then
  begin
    Exit;
  end;
  if not LSaved then
  begin
    { A dropped successful POST may already be durable. Probe the same ID;
      compare exact requested selections before claiming saved or retrying. }
    try
      LResponse := await(TJSResponse, FetchApi('/api/studio/project?id=' +
        encodeURIComponent(Str(LWrite, 'project_id')), 'GET', ''));
      if LEpoch <> FEpoch then
      begin
        Exit;
      end;
      if LResponse.status = 200 then
      begin
        LData := await(TJSObject, LResponse.json());
        if LEpoch <> FEpoch then
        begin
          Exit;
        end;
        LSaved := MatchesWrite(LData, LWrite);
      end;
    except
      on LError: Exception do
      begin
        LSaved := False;
      end;
    else
      begin
        LSaved := False;
      end;
    end;
  end;
  if LSaved then
  begin
    try
      LFound := False;
      for LIndex := 0 to FProjects.length - 1 do
      begin
        if Str(Obj(FProjects[LIndex]), 'project_id') = Str(LData, 'project_id') then
        begin
          FProjects[LIndex] := CloneObject(LData);
          LFound := True;
        end;
      end;
      if not LFound then
      begin
        FProjects.push(CloneObject(LData));
      end;
      ApplyProject(LData);
      Feedback('Draft saved.');
    except
      on LError: Exception do
      begin
        Feedback('Save response is unsupported. Your edits remain; reload when connected.', True);
      end;
    end;
  end
  else
  begin
    FDirty := True;
    Feedback(LMessage, True);
  end;
  window.clearTimeout(LTimer);
  if LEpoch = FEpoch then
  begin
    FBusy := False;
    DrawTracks;
    UpdateState;
  end;
end;

function TStudio.HandleEdit(AEvent: TEventListenerEvent): Boolean;
begin
  Result := False;
  if not FBusy then
  begin
    Changed;
  end;
end;

function TStudio.HandleNew(AEvent: TJSMouseEvent): Boolean;
begin
  Result := False;
  if FBusy then
  begin
    Exit;
  end;
  if FDirty and not window.confirm('Discard unsaved changes and start a new project?') then
  begin
    Exit;
  end;
  NewDraft;
  RevealWorkspaceControl(El('style-name'));
  Input('style-name').focus;
end;

function TStudio.HandleSave(AEvent: TJSMouseEvent): Boolean;
begin
  Result := False;
  Save;
end;

function TStudio.HandleReload(AEvent: TJSMouseEvent): Boolean;
begin
  Result := False;
  LoadProject(FProjectId);
end;

function TStudio.HandleRetry(AEvent: TJSMouseEvent): Boolean;
begin
  Result := False;
  Connect;
end;

function TStudio.HandleProject(AEvent: TEventListenerEvent): Boolean;
var
  LId: String;
begin
  Result := False;
  LId := TJSHTMLSelectElement(El('draft-list')).value;
  if LId = '' then
  begin
    if FDirty and not window.confirm('Discard unsaved changes and start a new project?') then
    begin
      TJSHTMLSelectElement(El('draft-list')).value := FProjectId;
      Exit;
    end;
    NewDraft;
  end
  else
  begin
    LoadProject(LId);
  end;
end;

function TStudio.HandleSearch(AEvent: TEventListenerEvent): Boolean;
begin
  Result := False;
  DrawTracks;
end;

function TStudio.HandleSubmit(AEvent: TEventListenerEvent): Boolean;
begin
  Result := False;
  AEvent.preventDefault;
  Save;
end;

function TStudio.HandleBeforeUnload(AEvent: TEventListenerEvent): Boolean;
begin
  Result := False;
  if FDirty then
  begin
    AEvent.preventDefault;
    TJSObject(AEvent)['returnValue'] := '';
  end;
end;

function TStudio.HandleAnyPlay(AEvent: TEventListenerEvent): Boolean;
var
  LPlayers: TJSNodeList;
  LIndex: Integer;
begin
  LPlayers := document.querySelectorAll('audio');
  for LIndex := 0 to LPlayers.length - 1 do
  begin
    if LPlayers[LIndex] <> AEvent.target then
    begin
      TJSHTMLAudioElement(LPlayers[LIndex]).pause;
    end;
  end;
  Result := True;
end;

function TStudio.HandleStart(AEvent: TJSMouseEvent): Boolean;
var
  LAction: String;
begin
  Result := False;
  LAction := TJSElement(AEvent.currentTarget).id;
  if LAction = 'start-browse' then
  begin
    RevealWorkspaceControl(El('collection-library'));
    TJSHTMLElement(El('collection-library')).scrollIntoView;
    TJSHTMLElement(El('collection-library')).focus;
  end
  else if LAction = 'capture-back' then
  begin
    RevealWorkspaceControl(El('start-record'));
    TJSHTMLElement(El('start-record')).scrollIntoView;
    TJSHTMLElement(El('start-record')).focus;
  end
  else
  begin
    RevealWorkspaceControl(El('studio-capture'));
    if LAction = 'start-record' then
    begin
      FCapture.OpenRecorder;
    end
    else
    begin
      FCapture.OpenImporter;
    end;
  end;
end;

procedure TStudio.Run;
begin
  FNavigation := TWorkspaceNavigation.Create(@FetchNavigation, 'studio');
  FTracks := TJSArray.new;
  FProjects := TJSArray.new;
  FSelections := TJSArray.new;
  FSourceEditor := TStudioSourceEditor.Create(@FetchApi, @Changed, @FetchNavigation);
  FBatches := TStudioBatches.Create(@FetchApi);
  FEffects := TStudioEffects.Create(@FetchApi, @FSourceEditor.CurrentRange, @CatalogSaved);
  FReviews := TStudioReviews.Create(@FetchApi, @UseNextBatch);
  FCapture := TStudioCapture.Create(@FetchApi, @CatalogSaved);
  FLibraryRefresh := TStudioLibraryRefresh.Create(@FetchNavigation, @CatalogSaved);
  El('start-record').addEventListener('click', @HandleStart);
  El('start-import').addEventListener('click', @HandleStart);
  El('start-browse').addEventListener('click', @HandleStart);
  El('capture-back').addEventListener('click', @HandleStart);
  FTabs := TWorkspaceTabs.Create;
  NewDraft;
  El('style-form').addEventListener('submit', @HandleSubmit);
  El('style-name').addEventListener('input', @HandleEdit);
  El('style-qualities').addEventListener('input', @HandleEdit);
  El('save-draft').addEventListener('click', @HandleSave);
  El('reload-draft').addEventListener('click', @HandleReload);
  El('new-draft').addEventListener('click', @HandleNew);
  El('retry').addEventListener('click', @HandleRetry);
  El('source-reconnect').addEventListener('click', @HandleRetry);
  El('draft-list').addEventListener('change', @HandleProject);
  El('track-search').addEventListener('input', @HandleSearch);
  window.addEventListener('beforeunload', @HandleBeforeUnload);
  document.addEventListener('play', @HandleAnyPlay, True);
  Connect;
end;

var
  GStudio: TStudio;

begin
  GStudio := TStudio.Create;
  GStudio.Run;
end.
