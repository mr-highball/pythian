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
  Math;

type
  TStudioWindow = class external name 'Window' (TJSWindow)
    function fetch(const AUrl: String; const AOptions: TJSObject): TJSPromise; reintroduce;
  end;

  TStudio = class
  private
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
    function El(const AId: String): TJSElement;
    function Input(const AId: String): TJSHTMLInputElement;
    function AddText(AParent: TJSElement; const ATag, AText, AClass: String): TJSElement;
    function FetchApi(const APath, AMethod, ABody: String): TJSPromise;
    procedure Connect; async;
    procedure LoadProject(const AId: String); async;
    procedure Save; async;
    procedure RefreshSources; async;
    procedure ApplyProject(AProject: TJSObject);
    procedure NewDraft;
    procedure DrawProjects;
    procedure DrawTracks;
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
    function HandleRefresh(AEvent: TJSMouseEvent): Boolean;
    function HandleProject(AEvent: TEventListenerEvent): Boolean;
    function HandleSearch(AEvent: TEventListenerEvent): Boolean;
    function HandleTrack(AEvent: TEventListenerEvent): Boolean;
    function HandleRange(AEvent: TEventListenerEvent): Boolean;
    function HandleRangeMode(AEvent: TEventListenerEvent): Boolean;
    function HandleBeforeUnload(AEvent: TEventListenerEvent): Boolean;
    function HandleSubmit(AEvent: TEventListenerEvent): Boolean;
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

function TStudio.FetchApi(const APath, AMethod, ABody: String): TJSPromise;
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
  Result := TStudioWindow(window).fetch(window.location.origin + APath, LOptions);
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
  LControls := ['style-name', 'style-qualities', 'learning-mode', 'new-draft',
    'draft-list', 'refresh-tracks', 'track-search'];
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
  LEvaluation: Integer;
  LName: String;
  LRoute: String;
begin
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
  LEvaluation := 0;
  for LIndex := 0 to FSelections.length - 1 do
  begin
    LSelected := Obj(FSelections[LIndex]);
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
      Inc(LCount);
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
    El('selection-summary').textContent := 'Select recordings to build your source collection.';
  end
  else
  begin
    El('selection-summary').textContent := TimeText(LSeconds * 1000) + ' selected.';
    if LEvaluation > 0 then
    begin
      El('selection-summary').textContent := El('selection-summary').textContent + ' ' +
        IntToStr(LEvaluation) + ' evaluation-only recording(s) are reserved from training.';
    end;
  end;
  LName := Trim(Input('style-name').value);
  if LName = '' then
  begin
    El('draft-caption').textContent := 'Give your style a name, then select its recordings.';
  end
  else
  begin
    El('draft-caption').textContent := LName + ' · ' + IntToStr(LCount) + ' recording(s) selected.';
  end;
end;

procedure TStudio.DrawTracks;
var
  LRoot: TJSElement;
  LCard: TJSElement;
  LLabel: TJSElement;
  LText: TJSElement;
  LDetails: TJSElement;
  LFields: TJSElement;
  LHelp: TJSElement;
  LCheckbox: TJSHTMLInputElement;
  LRangeMode: TJSHTMLInputElement;
  LStart: TJSHTMLInputElement;
  LEnd: TJSHTMLInputElement;
  LTrack: TJSObject;
  LSelected: TJSObject;
  LIndex: Integer;
  LHash: String;
  LQuery: String;
  LMeta: String;
  LIsRange: Boolean;
  LShown: Integer;
begin
  LRoot := El('tracks');
  LRoot.innerHTML := '';
  LQuery := LowerCase(Trim(Input('track-search').value));
  LShown := 0;
  for LIndex := 0 to FTracks.length - 1 do
  begin
    LTrack := Obj(FTracks[LIndex]);
    LHash := Str(LTrack, 'source_sha256');
    LSelected := FindSelection(LHash);
    if (LQuery <> '') and (Pos(LQuery, LowerCase(TrackTitle(LTrack))) = 0) and
      (LSelected = nil) then
    begin
      Continue;
    end;
    Inc(LShown);
    LCard := AddText(LRoot, 'div', '', 'track');
    if LSelected <> nil then
    begin
      LCard.className := 'track selected';
    end;
    LLabel := AddText(LCard, 'label', '', 'track-toggle');
    LCheckbox := TJSHTMLInputElement(document.createElement('input'));
    LCheckbox.id := 'pick-' + LHash;
    LCheckbox.setAttribute('type', 'checkbox');
    LCheckbox.checked := LSelected <> nil;
    LCheckbox.disabled := FBusy or not FConnected or
      (Str(LTrack, 'partition') = 'evaluation');
    LCheckbox.setAttribute('data-source', LHash);
    LCheckbox.addEventListener('change', @HandleTrack);
    LLabel.appendChild(LCheckbox);
    LText := AddText(LLabel, 'span', '', '');
    AddText(LText, 'span', TrackTitle(LTrack), 'track-name');
    LMeta := TimeText(Num(LTrack, 'frame_count') * 1000 / Num(LTrack, 'sample_rate'));
    if Str(LTrack, 'partition') = 'evaluation' then
    begin
      LMeta := LMeta + ' · Evaluation only — reserved from training';
    end
    else if Str(LTrack, 'partition') = 'unassigned' then
    begin
      LMeta := LMeta + ' · Use not assigned — draft selection allowed';
    end
    else
    begin
      LMeta := LMeta + ' · Imported recording';
    end;
    AddText(LText, 'span', LMeta, 'track-meta');
    if LSelected <> nil then
    begin
      LDetails := AddText(LCard, 'details', '', '');
      AddText(LDetails, 'summary', 'Choose a time range', '');
      LLabel := AddText(LDetails, 'label', '', 'track-toggle');
      LRangeMode := TJSHTMLInputElement(document.createElement('input'));
      LRangeMode.setAttribute('type', 'checkbox');
      LRangeMode.checked := Str(LSelected, 'selection') = 'range';
      LRangeMode.disabled := FBusy;
      LRangeMode.setAttribute('data-source', LHash);
      LRangeMode.addEventListener('change', @HandleRangeMode);
      LLabel.appendChild(LRangeMode);
      AddText(LLabel, 'span', 'Use only part of this recording', '');
      LIsRange := LRangeMode.checked;
      LFields := AddText(LDetails, 'div', '', 'range-fields');
      LLabel := AddText(LFields, 'label', 'Start (minutes:seconds)', '');
      LStart := TJSHTMLInputElement(document.createElement('input'));
      LStart.setAttribute('type', 'text');
      LStart.id := 'start-' + LHash;
      LStart.value := Str(LSelected, 'start_text');
      LStart.placeholder := '0:00';
      LStart.disabled := FBusy or not LIsRange;
      LStart.setAttribute('data-source', LHash);
      LStart.setAttribute('aria-describedby', 'range-help-' + LHash + ' range-error-' + LHash);
      LStart.addEventListener('input', @HandleRange);
      LLabel.appendChild(LStart);
      LLabel := AddText(LFields, 'label', 'End (minutes:seconds)', '');
      LEnd := TJSHTMLInputElement(document.createElement('input'));
      LEnd.setAttribute('type', 'text');
      LEnd.id := 'end-' + LHash;
      LEnd.value := Str(LSelected, 'end_text');
      LEnd.placeholder := '1:30';
      LEnd.disabled := FBusy or not LIsRange;
      LEnd.setAttribute('data-source', LHash);
      LEnd.setAttribute('aria-describedby', 'range-help-' + LHash + ' range-error-' + LHash);
      LEnd.addEventListener('input', @HandleRange);
      LLabel.appendChild(LEnd);
      LHelp := AddText(LDetails, 'p', 'For example, 1:30 to 2:15. Optional milliseconds: 1:30.250. Times snap to source frames.', 'hint');
      LHelp.id := 'range-help-' + LHash;
      LHelp := AddText(LDetails, 'p', '', 'field-error');
      LHelp.id := 'range-error-' + LHash;
      LHelp.setAttribute('role', 'alert');
      if Boolean(LSelected['range_invalid']) then
      begin
        LHelp.textContent := 'Enter valid times with the end after the start, inside this recording.';
      end
      else
      begin
        LHelp.setAttribute('hidden', '');
      end;
      LDetails := AddText(LCard, 'details', '', '');
      AddText(LDetails, 'summary', 'Recording details', '');
      AddText(LDetails, 'p', 'License: ' + Str(LTrack, 'license') + '. Source verification is pending before training. Song boundaries are not verified.', 'hint');
    end;
  end;
  if LShown = 0 then
  begin
    El('tracks-empty').removeAttribute('hidden');
    if FTracks.length = 0 then
    begin
      El('tracks-empty').textContent := 'No imported recordings yet. Import recordings into your source catalog, then refresh this list.';
    end
    else
    begin
      El('tracks-empty').textContent := 'No recording names match your search.';
    end;
  end
  else
  begin
    El('tracks-empty').setAttribute('hidden', '');
  end;
end;

function TStudio.HandleTrack(AEvent: TEventListenerEvent): Boolean;
var
  LInput: TJSHTMLInputElement;
  LSelected: TJSObject;
  LTrack: TJSObject;
  LHash: String;
  LIndex: Integer;
begin
  Result := False;
  if FBusy then
  begin
    Exit;
  end;
  LInput := TJSHTMLInputElement(AEvent.target);
  LHash := LInput.getAttribute('data-source');
  LTrack := FindTrack(LHash);
  if LTrack = nil then
  begin
    Exit;
  end;
  if LInput.checked then
  begin
    if FindSelection(LHash) = nil then
    begin
      LSelected := TJSObject.new;
      LSelected['source_sha256'] := LHash;
      LSelected['selection'] := 'full';
      LSelected['start_frame'] := 0;
      LSelected['end_frame'] := Num(LTrack, 'frame_count');
      LSelected['start_text'] := '0:00';
      LSelected['end_text'] := TimeText(Num(LTrack, 'frame_count') * 1000 / Num(LTrack, 'sample_rate'));
      LSelected['range_invalid'] := False;
      FSelections.push(LSelected);
    end;
  end
  else
  begin
    for LIndex := FSelections.length - 1 downto 0 do
    begin
      if Str(Obj(FSelections[LIndex]), 'source_sha256') = LHash then
      begin
        FSelections.splice(LIndex, 1);
      end;
    end;
  end;
  Changed;
  DrawTracks;
  if document.getElementById('pick-' + LHash) <> nil then
  begin
    Input('pick-' + LHash).focus;
  end
  else
  begin
    Input('track-search').focus;
  end;
end;

function TStudio.HandleRangeMode(AEvent: TEventListenerEvent): Boolean;
var
  LInput: TJSHTMLInputElement;
  LSelected: TJSObject;
  LHash: String;
begin
  Result := False;
  if FBusy then
  begin
    Exit;
  end;
  LInput := TJSHTMLInputElement(AEvent.target);
  LHash := LInput.getAttribute('data-source');
  LSelected := FindSelection(LHash);
  if LSelected = nil then
  begin
    Exit;
  end;
  if LInput.checked then
  begin
    LSelected['selection'] := 'range';
  end
  else
  begin
    LSelected['selection'] := 'full';
    LSelected['range_invalid'] := False;
  end;
  Input('start-' + LHash).disabled := not LInput.checked;
  Input('end-' + LHash).disabled := not LInput.checked;
  El('range-error-' + LHash).setAttribute('hidden', '');
  if LInput.checked then
  begin
    { Re-entering a range validates the visible fields, including stale errors. }
    HandleRange(AEvent);
  end
  else
  begin
    Input('start-' + LHash).removeAttribute('aria-invalid');
    Input('end-' + LHash).removeAttribute('aria-invalid');
    Changed;
  end;
end;

function TStudio.HandleRange(AEvent: TEventListenerEvent): Boolean;
var
  LInput: TJSHTMLInputElement;
  LSelected: TJSObject;
  LTrack: TJSObject;
  LHash: String;
  LStartMs: Double;
  LEndMs: Double;
  LStartFrame: Double;
  LEndFrame: Double;
  LValid: Boolean;
begin
  Result := False;
  if FBusy then
  begin
    Exit;
  end;
  LInput := TJSHTMLInputElement(AEvent.target);
  LHash := LInput.getAttribute('data-source');
  LSelected := FindSelection(LHash);
  LTrack := FindTrack(LHash);
  if (LSelected = nil) or (LTrack = nil) then
  begin
    Exit;
  end;
  LSelected['start_text'] := Input('start-' + LHash).value;
  LSelected['end_text'] := Input('end-' + LHash).value;
  LValid := ParseTime(Str(LSelected, 'start_text'), LStartMs);
  LValid := ParseTime(Str(LSelected, 'end_text'), LEndMs) and LValid;
  LValid := LValid and (LStartMs < LEndMs) and
    (LEndMs <= Num(LTrack, 'frame_count') * 1000 / Num(LTrack, 'sample_rate'));
  if not LValid then
  begin
    LStartMs := 0;
    LEndMs := 0;
  end;
  LStartFrame := Floor(LStartMs * Num(LTrack, 'sample_rate') / 1000);
  LEndFrame := Ceil(LEndMs * Num(LTrack, 'sample_rate') / 1000);
  LValid := LValid and (LStartFrame >= 0) and (LEndFrame > LStartFrame) and
    (LEndFrame <= Num(LTrack, 'frame_count')) and (LEndFrame <= 9007199254740991);
  LSelected['range_invalid'] := not LValid;
  if LValid then
  begin
    LSelected['start_frame'] := LStartFrame;
    LSelected['end_frame'] := LEndFrame;
    El('range-error-' + LHash).setAttribute('hidden', '');
    Input('start-' + LHash).removeAttribute('aria-invalid');
    Input('end-' + LHash).removeAttribute('aria-invalid');
  end
  else
  begin
    El('range-error-' + LHash).textContent := 'Use minutes:seconds, with the end after the start and within this recording.';
    El('range-error-' + LHash).removeAttribute('hidden');
    Input('start-' + LHash).setAttribute('aria-invalid', 'true');
    Input('end-' + LHash).setAttribute('aria-invalid', 'true');
  end;
  Changed;
end;

procedure TStudio.ApplyProject(AProject: TJSObject);
var
  LSources: TJSArray;
  LSource: TJSObject;
  LSelection: TJSObject;
  LIndex: Integer;
begin
  if (Str(AProject, 'format') <> 'pythian.studio.project.v1') or
    (Str(AProject, 'status') <> 'draft') or
    (Str(AProject, 'training_status') <> 'not_started') or
    Boolean(AProject['model_available']) then
  begin
    raise Exception.Create('This page supports untrained style drafts only.');
  end;
  LSources := Arr(AProject, 'sources');
  if (LSources = nil) or (LSources.length < 1) or (LSources.length > 32) then
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
    FSelections.push(LSelection);
  end;
  FProjectId := Str(AProject, 'project_id');
  FRevision := Trunc(Num(AProject, 'revision'));
  Input('style-name').value := Str(AProject, 'name');
  TJSHTMLTextAreaElement(El('style-qualities')).value := Str(AProject, 'style_intent');
  Input('learning-mode').value := Str(AProject, 'learning_mode');
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
    Input('style-name').focus;
    LValid := False;
  end;
  if Length(LIntent) > 2048 then
  begin
    ErrorAt('qualities-error', 'Keep your description within 2,048 characters.');
    El('style-qualities').setAttribute('aria-invalid', 'true');
    LValid := False;
  end;
  if (FSelections.length < 1) or (FSelections.length > 32) then
  begin
    ErrorAt('tracks-error', 'Select between 1 and 32 recordings for this draft.');
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
  for LIndex := 0 to FSelections.length - 1 do
  begin
    LSelection := Obj(FSelections[LIndex]);
    LSource := TJSObject.new;
    LSource['source_sha256'] := Str(LSelection, 'source_sha256');
    LSource['selection'] := Str(LSelection, 'selection');
    if Str(LSelection, 'selection') = 'range' then
    begin
      LSource['start_frame'] := Num(LSelection, 'start_frame');
      LSource['end_frame'] := Num(LSelection, 'end_frame');
    end;
    LSources.push(LSource);
  end;
  Result['sources'] := LSources;
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
    FConnected := True;
    Status('Choose recordings and save your project draft.');
    DrawProjects;
  except
    on LError: Exception do
    begin
      if LEpoch = FEpoch then
      begin
        Status(LError.Message + ' Your edits are still here.', True);
        El('retry').removeAttribute('hidden');
      end;
    end;
  else
    begin
      if LEpoch = FEpoch then
      begin
        Status('Connection failed. Your edits are still here; retry when ready.', True);
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

procedure TStudio.RefreshSources; async;
begin
  Connect;
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

function TStudio.HandleRefresh(AEvent: TJSMouseEvent): Boolean;
begin
  Result := False;
  RefreshSources;
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

procedure TStudio.Run;
begin
  FTracks := TJSArray.new;
  FProjects := TJSArray.new;
  FSelections := TJSArray.new;
  NewDraft;
  El('style-form').addEventListener('submit', @HandleSubmit);
  El('style-name').addEventListener('input', @HandleEdit);
  El('style-qualities').addEventListener('input', @HandleEdit);
  El('save-draft').addEventListener('click', @HandleSave);
  El('reload-draft').addEventListener('click', @HandleReload);
  El('new-draft').addEventListener('click', @HandleNew);
  El('retry').addEventListener('click', @HandleRetry);
  El('refresh-tracks').addEventListener('click', @HandleRefresh);
  El('draft-list').addEventListener('change', @HandleProject);
  El('track-search').addEventListener('input', @HandleSearch);
  window.addEventListener('beforeunload', @HandleBeforeUnload);
  Connect;
end;

var
  GStudio: TStudio;

begin
  GStudio := TStudio.Create;
  GStudio.Run;
end.
