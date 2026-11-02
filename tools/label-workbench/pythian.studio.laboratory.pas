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
unit pythian.studio.laboratory;

{$mode delphi}
{$H+}

interface

uses JS, Web, SysUtils, pythian.studio.sources, pythian.studio.musical.controls,
  pythian.studio.material;

type
  TStudioExperimentEvent = procedure(AProject: TJSObject) of object;
  { Big Boss: optional musical draft/form only. Generation is handed to the
    ordinary Studio job controller; no second worker, player or polling loop. }
  TStudioLaboratory = class
  private
    FFetch: TStudioFetch;
    FSavedEvent, FGenerateEvent, FOpenedEvent: TStudioExperimentEvent;
    FDialog, FHelp, FStatus, FName, FSavedChoice, FGenerate: TJSElement;
    FOrigin: TJSElement;
    FForm: TStudioMusicalControls;
    FMaterial: TStudioMaterial;
    FDefaults, FSaved, FPending: TJSObject;
    FProjects: TJSArray;
    FScope, FId, FMessage: String;
    FRevision, FChanges, FPendingChanges: Integer;
    FTimer: NativeInt;
    FDirty, FSaving, FLoading, FGenerationAvailable, FDisposed: Boolean;
    function Add(AParent: TJSElement; const ATag, AText: String): TJSElement;
    function Json(const APath, AMethod, ABody: String): TJSObject; async;
    function Edited(AEvent: TEventListenerEvent): Boolean;
    function Click(AEvent: TJSMouseEvent): Boolean;
    function SavedChoice(AEvent: TEventListenerEvent): Boolean;
    procedure Remember;
    procedure DrawSavedChoices;
    procedure Draw;
    procedure NewExperiment(const ACopy: Boolean);
    procedure MaterialChanged;
    procedure SelectSaved; async;
    procedure Generate; async;
  public
    constructor Create(AParent: TJSElement; const AFetch: TStudioFetch;
      const AOnSaved, AOnGenerate, AOnOpened: TStudioExperimentEvent);
    destructor Destroy; override;
    procedure SetScope(const AScope: String);
    procedure Open(AProjects: TJSArray);
    procedure OpenProject(AProject: TJSObject);
    procedure SetGenerationAvailable(const AAvailable: Boolean);
    function Save: Boolean; async;
    property ProjectId: String read FId;
    property Revision: Integer read FRevision;
  end;

implementation

uses pythian.studio.requests;

function ObjectValue(AValue: JSValue): TJSObject;
begin
  Result := nil;
  if isObject(AValue) and not isArray(AValue) then Result := TJSObject(AValue);
end;

function TStudioLaboratory.Add(AParent: TJSElement; const ATag, AText: String): TJSElement;
begin
  Result := document.createElement(ATag);
  Result.textContent := AText;
  AParent.appendChild(Result);
end;

constructor TStudioLaboratory.Create(AParent: TJSElement; const AFetch: TStudioFetch;
  const AOnSaved, AOnGenerate, AOnOpened: TStudioExperimentEvent);
var LHeader, LRow, LButton: TJSElement;
  procedure Button(AParent: TJSElement; const AId, AText: String);
  begin
    LButton := Add(AParent, 'button', AText);
    LButton.id := AId;
    LButton.setAttribute('type', 'button');
    LButton.addEventListener('click', @Click);
  end;
begin
  inherited Create;
  FFetch := AFetch;
  FSavedEvent := AOnSaved; FGenerateEvent := AOnGenerate; FOpenedEvent := AOnOpened;
  FGenerationAvailable := True;
  FDialog := Add(AParent, 'dialog', ''); FDialog.id := 'laboratory-dialog';
  FDialog.setAttribute('aria-labelledby', 'laboratory-title');
  LHeader := Add(FDialog, 'header', ''); LHeader.className := 'dialog-heading';
  Add(LHeader, 'h2', 'Musical experiments').id := 'laboratory-title';
  Button(LHeader, 'lab-help', '?');
  LButton.setAttribute('aria-label', 'How this works');
  Button(LHeader, 'lab-close', 'Done');
  FOrigin := Add(FDialog, 'p', '');
  FOrigin.className := 'hint';
  LRow := Add(FDialog, 'div', ''); LRow.className := 'lab-saved';
  FSavedChoice := Add(Add(LRow, 'label', 'Saved experiments'), 'select', '');
  FSavedChoice.id := 'lab-saved'; FSavedChoice.addEventListener('change', @SavedChoice);
  Button(LRow, 'lab-new', 'New');
  FName := Add(Add(FDialog, 'label', 'Experiment name'), 'input', '');
  FName.id := 'lab-name'; FName.setAttribute('maxlength', '128');
  FName.addEventListener('input', @Edited);
  FForm := TStudioMusicalControls.Create(FDialog);
  FDefaults := FForm.ReadConfig;
  FForm.Root.addEventListener('input', @Edited);
  FForm.Root.addEventListener('change', @Edited);
  FMaterial := TStudioMaterial.Create(FForm.ContextPanel, AFetch, @MaterialChanged);
  LRow := Add(FDialog, 'footer', ''); LRow.className := 'lab-footer';
  FStatus := Add(LRow, 'p', ''); FStatus.id := 'lab-status'; FStatus.className := 'hint';
  FStatus.setAttribute('role', 'status');
  Button(LRow, 'lab-generate', 'Generate experiment');
  FGenerate := LButton; FGenerate.className := 'primary';
  Button(LRow, 'lab-retry', 'Retry save');
  Button(LRow, 'lab-copy', 'Save a copy');
  FHelp := Add(AParent, 'dialog', ''); FHelp.id := 'laboratory-help';
  FHelp.setAttribute('aria-labelledby', 'laboratory-help-title');
  LHeader := Add(FHelp, 'header', ''); LHeader.className := 'dialog-heading';
  Add(LHeader, 'h2', 'Try one change').id := 'laboratory-help-title';
  Button(LHeader, 'lab-help-close', 'Close help');
  Add(FHelp, 'p', 'Music sets tempo, key and length. Parts changes note ranges, activity, note strength, note length and mix. Feel fills editable preferences. Structure arranges sections and repeats.');
  Add(FHelp, 'p', 'In Structure, choose an earlier section and the parts to keep. Other parts can vary. A repeat takes its source length; moving its source after it is invalid. Conflicting musical choices fail visibly.');
  Add(FHelp, 'p', 'Section energy makes new instrument attacks softer or stronger. 50 is neutral. Held notes keep ringing; a repeated part keeps its notes and rhythm while its new attacks use this section’s energy.');
  Add(FHelp, 'p', 'Without recording ideas, the starter supplies authored musical examples. With recording ideas, your selected notes drive one part with authored accompaniment. WFC chooses events and Pythian instruments synthesize all six parts.');
  Add(FHelp, 'p', 'Analyze a passage or imported recording, then choose Try these suggestions. Edit tempo, key, pitch cells and sound, or skip them. Use in experiment saves the choices; Generate experiment is the separate action that makes music. These proposals are Experimental and do not separate a mix into instruments.');
  Add(FHelp, 'p', 'Follow the starter fixes chords and rhythm. Let WFC vary releases those choices; preferences cannot override a hard pitch limit. A conflict means the requested choices do not fit.');
  Add(FHelp, 'p', 'Settings save automatically. Only Generate experiment starts music. Listen in the normal Generate step, then return here to change a setting. Saving feedback never changes the model.');
  NewExperiment(False);
end;

destructor TStudioLaboratory.Destroy;
begin
  window.clearTimeout(FTimer);
  Remember;
  FDisposed := True;
  FMaterial.Free;
  FForm.Free;
  if FDialog.parentNode <> nil then FDialog.parentNode.removeChild(FDialog);
  if FHelp.parentNode <> nil then FHelp.parentNode.removeChild(FHelp);
  inherited Destroy;
end;

function TStudioLaboratory.Json(const APath, AMethod, ABody: String): TJSObject; async;
begin
  Result := await(TJSObject, ReadStudioJSONResponse(FFetch(APath, AMethod, ABody)));
end;

procedure TStudioLaboratory.Remember;
var LState: TJSObject;
begin
  if (FScope = '') or FDisposed then Exit;
  LState := TJSObject.new;
  LState['id'] := FId; LState['revision'] := FRevision;
  LState['name'] := TJSHTMLInputElement(FName).value;
  LState['draft'] := FForm.ReadDraft; LState['saved'] := FSaved;
  LState['material'] := FMaterial.Value;
  LState['pending'] := FPending; LState['dirty'] := FDirty;
  LState['changes'] := FChanges; LState['pending_changes'] := FPendingChanges;
  try
    window.localStorage.setItem('pythian.studio.laboratory.' + FScope, TJSJSON.stringify(LState));
  except
    FMessage := 'Browser draft storage is unavailable. Keep this page open until Saved.';
    FStatus.textContent := FMessage;
  end;
end;

procedure TStudioLaboratory.SetScope(const AScope: String);
var LText: String; LState: TJSObject;
begin
  if FScope = AScope then Exit;
  FScope := AScope;
  try
    LText := window.localStorage.getItem('pythian.studio.laboratory.' + FScope);
    if not isString(LText) or (LText = '') then Exit;
    LState := ObjectValue(TJSJSON.parse(LText));
    if LState = nil then Exit;
    FId := StudioText(LState, 'id');
    FRevision := Trunc(StudioNumber(LState, 'revision'));
    TJSHTMLInputElement(FName).value := StudioText(LState, 'name');
    FForm.RestoreDraft(ObjectValue(LState['draft']));
    FMaterial.Restore(ObjectValue(LState['material']));
    FSaved := ObjectValue(LState['saved']); FPending := ObjectValue(LState['pending']);
    FDirty := isBoolean(LState['dirty']) and Boolean(LState['dirty']);
    FChanges := Trunc(StudioNumber(LState, 'changes'));
    FPendingChanges := Trunc(StudioNumber(LState, 'pending_changes'));
    Draw;
  except
    FMessage := 'This browser draft could not reopen. Choose a saved experiment or New.';
    FStatus.textContent := FMessage;
  end;
end;

procedure TStudioLaboratory.NewExperiment(const ACopy: Boolean);
begin
  if FSaving or FLoading then Exit;
  window.clearTimeout(FTimer);
  FId := 'experiment-' + IntToStr(Round(TJSDate.now)) + '-' + IntToStr(Random(1000000));
  FRevision := 0; FSaved := nil; FPending := nil;
  FMessage := '';
  Inc(FChanges); FDirty := True;
  if not ACopy then
  begin
    TJSHTMLInputElement(FName).value := 'My experiment';
    FForm.RestoreConfig(FDefaults);
    FMaterial.Restore(nil);
  end;
  Remember;
  Draw;
end;

procedure TStudioLaboratory.Open(AProjects: TJSArray);
begin
  FProjects := AProjects;
  DrawSavedChoices;
  Draw;
  TStudioDialog(FDialog).showModal;
  if FDirty and (FPending = nil) then
    FTimer := window.setTimeout(procedure begin Save end, 500);
end;

procedure TStudioLaboratory.DrawSavedChoices;
var I: Integer; LRow: TJSObject; LFound: Boolean;
  procedure AddChoice(AProject: TJSObject);
  begin
    Add(FSavedChoice, 'option', StudioText(AProject, 'name')).
      setAttribute('value', StudioText(AProject, 'project_id'));
    LFound := LFound or (StudioText(AProject, 'project_id') = FId);
  end;
begin
  LFound := False;
  FSavedChoice.innerHTML := '';
  Add(FSavedChoice, 'option', 'Choose an experiment').setAttribute('value', '');
  if FProjects <> nil then
    for I := 0 to FProjects.length - 1 do
    begin
      LRow := ObjectValue(FProjects[I]);
      if (LRow = nil) or not isBoolean(LRow['musical_experiment']) or
        not Boolean(LRow['musical_experiment']) then Continue;
      AddChoice(LRow);
    end;
  if not LFound and (FSaved <> nil) then AddChoice(FSaved);
  TJSHTMLSelectElement(FSavedChoice).value := '';
  if LFound then TJSHTMLSelectElement(FSavedChoice).value := FId;
end;

procedure TStudioLaboratory.OpenProject(AProject: TJSObject);
begin
  if FSaving then raise Exception.Create('Wait for the current experiment to save.');
  if ObjectValue(AProject['instrumental']) = nil then
    raise Exception.Create('This saved item is not a musical experiment.');
  window.clearTimeout(FTimer);
  FForm.RestoreConfig(ObjectValue(AProject['instrumental']));
  FMaterial.Restore(ObjectValue(AProject['musical_material']));
  FId := StudioText(AProject, 'project_id');
  FRevision := Trunc(StudioNumber(AProject, 'revision'));
  TJSHTMLInputElement(FName).value := StudioText(AProject, 'name');
  FSaved := AProject; FPending := nil; FDirty := False;
  FMessage := '';
  Inc(FChanges);
  Remember;
  DrawSavedChoices;
  Draw;
  if Assigned(FOpenedEvent) then FOpenedEvent(AProject);
end;

function TStudioLaboratory.Edited(AEvent: TEventListenerEvent): Boolean;
begin
  Result := False;
  try
    FMaterial.UpdateContext(FForm.ReadConfig);
  except
    { Big Boss: retain invalid partial form input; Draw explains it and Save
      validates before publication. Do not rewrite recording choices from it. }
  end;
  Inc(FChanges); FDirty := True;
  FMessage := '';
  Remember;
  Draw;
  window.clearTimeout(FTimer);
  FTimer := window.setTimeout(procedure begin Save end, 500);
end;

procedure TStudioLaboratory.MaterialChanged;
var
  LMaterial: TJSObject;
begin
  LMaterial := FMaterial.Value;
  if LMaterial <> nil then
    FForm.RestoreContext(LMaterial);
  Inc(FChanges);
  FDirty := True;
  FMessage := '';
  Remember;
  Draw;
  if not FDialog.hasAttribute('open') then TStudioDialog(FDialog).showModal;
  window.clearTimeout(FTimer);
  FTimer := window.setTimeout(procedure begin Save end, 500);
end;

procedure TStudioLaboratory.Draw;
var LValid: Boolean;
begin
  if FDisposed then Exit;
  FForm.SetEnabled(not FLoading);
  FMaterial.SetEnabled(not FLoading);
  FOrigin.textContent := 'Authored music · recordings are optional.';
  if FMaterial.Value <> nil then
    FOrigin.textContent := 'Experimental recording ideas or edited notes, with authored accompaniment. A mix is not separated into instruments.';
  TJSHTMLInputElement(FName).disabled := FLoading;
  TJSHTMLSelectElement(FSavedChoice).disabled := FLoading or FSaving;
  LValid := False;
  try
    FForm.ReadConfig;
    if Trim(TJSHTMLInputElement(FName).value) = '' then
      raise Exception.Create('Give the experiment a name.');
    LValid := True;
    if FSaving then FStatus.textContent := 'Saving settings…'
    else if FPending <> nil then FStatus.textContent := 'Save interrupted. Retry keeps the same version.'
    else if FDirty then FStatus.textContent := 'Settings changed. They save automatically; no music starts yet.'
    else FStatus.textContent := 'Saved. Generate when ready.';
  except
    on E: Exception do FStatus.textContent := E.Message + ' Your draft is kept.';
  end;
  TJSHTMLButtonElement(FGenerate).disabled := not LValid or FSaving or FLoading or
    not FGenerationAvailable or (FScope = '');
  if not FGenerationAvailable then
    FStatus.textContent := FStatus.textContent + ' Finish or stop the current track before generating.';
  if FMessage <> '' then FStatus.textContent := FMessage;
  TJSHTMLButtonElement(document.getElementById('lab-new')).disabled := FSaving or FLoading;
  TJSHTMLButtonElement(document.getElementById('lab-copy')).disabled := not LValid or FSaving or FLoading;
  TJSHTMLButtonElement(document.getElementById('lab-retry')).disabled := not LValid or FSaving or FLoading;
  if FPending = nil then document.getElementById('lab-retry').setAttribute('hidden', '')
  else document.getElementById('lab-retry').removeAttribute('hidden');
end;

procedure TStudioLaboratory.SetGenerationAvailable(const AAvailable: Boolean);
begin
  FGenerationAvailable := AAvailable;
  Draw;
end;

function TStudioLaboratory.Save: Boolean; async;
var LSaved, LWrite, LConfig, LMaterial: TJSObject; LVersion: Integer; LCompleted: Boolean; LFailure: String;
begin
  Result := False;
  if FDisposed or FSaving or FLoading or (FScope = '') then Exit;
  window.clearTimeout(FTimer);
  if not FDirty and (FPending = nil) then Exit(True);
  LCompleted := False; LFailure := '';
  FMessage := '';
  try
    LConfig := FForm.ReadConfig;
    if Trim(TJSHTMLInputElement(FName).value) = '' then raise Exception.Create('Give the experiment a name.');
    if FPending = nil then
    begin
      LWrite := TJSObject.new;
      LWrite['format'] := 'pythian.studio.project.write.v1';
      LWrite['project_id'] := FId; LWrite['expected_revision'] := FRevision;
      LWrite['name'] := Trim(TJSHTMLInputElement(FName).value);
      LWrite['style_intent'] := ''; LWrite['learning_mode'] := 'instrumental';
      LWrite['sources'] := TJSArray.new; LWrite['instrumental'] := LConfig;
      LMaterial := FMaterial.Value;
      if LMaterial <> nil then LWrite['musical_material'] := LMaterial;
      FPending := LWrite; FPendingChanges := FChanges;
    end;
    FSaving := True; Remember; Draw;
    LVersion := FPendingChanges;
    LSaved := await(TJSObject, Json('/api/studio/project', 'POST', TJSJSON.stringify(FPending)));
    if FDisposed then Exit;
    if (StudioText(LSaved, 'project_id') <> FId) or
      not SameStudioJSON(LSaved['instrumental'], FPending['instrumental']) or
      not SameStudioJSON(LSaved['musical_material'], FPending['musical_material']) then
      raise Exception.Create('Saved experiment differs. Your requested settings are kept.');
    FRevision := Trunc(StudioNumber(LSaved, 'revision'));
    FSaved := LSaved; FPending := nil;
    FDirty := FChanges <> LVersion;
    LCompleted := True;
    if Assigned(FSavedEvent) then FSavedEvent(LSaved);
    DrawSavedChoices;
    Result := not FDirty;
  except
    on E: Exception do
      if FSaving then LFailure := E.Message + ' Retry save or save a copy.'
      else LFailure := E.Message + ' Your draft is kept.';
  end;
  FSaving := False;
  Remember;
  Draw;
  if LFailure <> '' then
  begin
    FMessage := LFailure;
    FStatus.textContent := LFailure;
  end;
  if LCompleted and FDirty then
  begin
    window.clearTimeout(FTimer);
    FTimer := window.setTimeout(procedure begin Save end, 500);
  end;
end;

procedure TStudioLaboratory.Generate; async;
var LVersion: Integer;
begin
  if not FGenerationAvailable or FSaving or FLoading then Exit;
  LVersion := FChanges;
  if not await(Boolean, Save) then Exit;
  if (LVersion <> FChanges) or not FGenerationAvailable then
  begin
    FStatus.textContent := 'Settings changed while saving. Generate again when ready.';
    Exit;
  end;
  if Assigned(FGenerateEvent) then FGenerateEvent(FSaved);
  TStudioDialog(FDialog).close;
end;

function TStudioLaboratory.Click(AEvent: TJSMouseEvent): Boolean;
begin
  Result := False;
  case TJSElement(AEvent.currentTarget).id of
    'lab-close': TStudioDialog(FDialog).close;
    'lab-help': TStudioDialog(FHelp).showModal;
    'lab-help-close': TStudioDialog(FHelp).close;
    'lab-new': begin NewExperiment(False); Save end;
    'lab-copy': begin NewExperiment(True); Save end;
    'lab-retry': Save;
    'lab-generate': Generate;
  end;
end;

function TStudioLaboratory.SavedChoice(AEvent: TEventListenerEvent): Boolean;
begin
  Result := False;
  SelectSaved;
end;

procedure TStudioLaboratory.SelectSaved; async;
var LId: String; LProject: TJSObject;
begin
  LId := TJSHTMLSelectElement(FSavedChoice).value;
  if LId = '' then Exit;
  if FSaving or FDirty or (FPending <> nil) then
  begin
    FStatus.textContent := 'Wait for Saved, or save a copy before opening another experiment.';
    TJSHTMLSelectElement(FSavedChoice).value := '';
    Exit;
  end;
  FLoading := True; Draw;
  try
    LProject := await(TJSObject, Json('/api/studio/project?id=' + encodeURIComponent(LId), 'GET', ''));
    OpenProject(LProject);
  except
    on E: Exception do FMessage := E.Message;
  end;
  FLoading := False;
  Draw;
end;

end.
