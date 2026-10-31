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
unit pythian.studio.structure;
{$mode delphi}
{$H+}

interface
uses JS, Web, SysUtils, pythian.music.form;

type
  TStudioSectionRow = record
    Key: Integer;
    Pane: TJSElement;
    Tab: TJSElement;
    Name: TJSElement;
    GroupName: TJSElement;
    Bars: TJSElement;
    RepeatChoice: TJSElement;
    KeepGroup: TJSElement;
    Keep: array[0..7] of TJSHTMLInputElement;
  end;
  { Big Boss: presentation and transport. The portable form cursor validates
    actual motif references/providers; existing jobs own inference and playback. }
  TStudioStructure = class
  private
    FRoot: TJSElement;
    FBody: TJSElement;
    FList: TJSElement;
    FPanels: TJSElement;
    FStatus: TJSElement;
    FToggle: TJSElement;
    FRows: array of TStudioSectionRow;
    FSerial: Integer;
    FEditing: Boolean;
    function Add(AParent: TJSElement; const ATag, AText: String): TJSElement;
    function Input(AParent: TJSElement; const AId, ALabel, AValue: String): TJSElement;
    procedure Button(AParent: TJSElement; const AAction, AText: String);
    function IndexOf(const AKey: Integer): Integer;
    function SelectedIndex: Integer;
    function GetEnabled: Boolean;
    procedure Clear;
    procedure AddSection(const AName, ABars: String; const ARepeatKey: Integer = 0);
    procedure Select(const AKey: Integer);
    procedure Update;
    procedure Changed;
    function Click(AEvent: TJSMouseEvent): Boolean;
    function Edit(AEvent: TEventListenerEvent): Boolean;
    function Key(AEvent: TJSKeyboardEvent): Boolean;
  public
    constructor Create(AParent: TJSElement);
    destructor Destroy; override;
    function ReadConfig(out ACells: Integer): TJSArray;
    procedure RestoreConfig(AValue: JSValue);
    function ReadDraft: TJSObject;
    procedure RestoreDraft(ADraft: TJSObject);
    procedure SetEnabled(const AEnabled: Boolean);
    property Enabled: Boolean read GetEnabled;
  end;

implementation
uses pythian.music.decisions, pythian.workspace.tabs;

const
  CNames: array[0..7] of String =
    ('Chords', 'Rhythm', 'Bass', 'Harmony', 'Lead', 'Kick', 'Snare', 'Hat');
  CKeys: array[0..7] of String =
    ('harmony', 'rhythm', 'bass', 'harmony-voice', 'lead', 'kick', 'snare', 'hat');

function TStudioStructure.Add(AParent: TJSElement; const ATag, AText: String): TJSElement;
begin
  Result := document.createElement(ATag);
  Result.textContent := AText;
  AParent.appendChild(Result);
end;

function TStudioStructure.Input(AParent: TJSElement;
  const AId, ALabel, AValue: String): TJSElement;
begin
  Result := Add(Add(AParent, 'label', ALabel), 'input', '');
  Result.id := AId;
  Result.setAttribute('value', AValue);
  Result.setAttribute('data-structure', 'true');
end;

procedure TStudioStructure.Button(AParent: TJSElement; const AAction, AText: String);
var LButton: TJSElement;
begin
  LButton := Add(AParent, 'button', AText);
  LButton.setAttribute('type', 'button');
  LButton.setAttribute('data-structure-action', AAction);
end;

constructor TStudioStructure.Create(AParent: TJSElement);
var LRow, LLabel: TJSElement;
begin
  inherited Create;
  FEditing := True;
  FRoot := Add(AParent, 'div', '');
  FRoot.id := 'structure-editor';
  FRoot.addEventListener('click', @Click);
  FRoot.addEventListener('input', @Edit);
  FRoot.addEventListener('change', @Edit);
  LLabel := Add(FRoot, 'label', 'Arrange sections');
  LLabel.className := 'check-label';
  FToggle := Add(LLabel, 'input', '');
  FToggle.id := 'structure-enabled';
  FToggle.setAttribute('type', 'checkbox');
  FToggle.setAttribute('data-structure', 'true');
  FStatus := Add(FRoot, 'p', '');
  FStatus.className := 'hint';
  FStatus.setAttribute('role', 'status');
  FBody := Add(FRoot, 'div', '');
  LRow := Add(FBody, 'div', '');
  LRow.className := 'structure-toolbar';
  Button(LRow, 'add', '+ Section');
  Button(LRow, 'preset', 'Use A / B / A');
  FList := Add(FBody, 'div', '');
  FList.className := 'structure-tabs';
  FList.setAttribute('role', 'tablist');
  FList.setAttribute('aria-label', 'Song sections');
  FList.addEventListener('keydown', @Key);
  Add(FBody, 'p', 'Make new music, or repeat an earlier section and keep chosen parts.').className := 'hint';
  Add(FBody, 'p', 'Experimental · neutral note preferences and expression. Pitch ranges, sounds and mix remain editable.').className := 'hint';
  FPanels := Add(FBody, 'div', '');
  AddSection('A', '4');
  Update;
end;

destructor TStudioStructure.Destroy;
begin
  FRoot.removeEventListener('click', @Click);
  FRoot.removeEventListener('input', @Edit);
  FRoot.removeEventListener('change', @Edit);
  FList.removeEventListener('keydown', @Key);
  inherited Destroy;
end;

function TStudioStructure.GetEnabled: Boolean;
begin
  Result := TJSHTMLInputElement(FToggle).checked;
end;

function TStudioStructure.IndexOf(const AKey: Integer): Integer;
begin
  Result := 0;
  while (Result < Length(FRows)) and (FRows[Result].Key <> AKey) do Inc(Result);
  if Result = Length(FRows) then Result := -1;
end;

function TStudioStructure.SelectedIndex: Integer;
begin
  Result := 0;
  while (Result < High(FRows)) and
    (FRows[Result].Tab.getAttribute('aria-selected') <> 'true') do Inc(Result);
end;

procedure TStudioStructure.Select(const AKey: Integer);
var I: Integer;
begin
  I := IndexOf(AKey);
  if I >= 0 then SelectWorkspacePane(FRows[I].Pane.id);
end;

procedure TStudioStructure.Clear;
var I: Integer;
begin
  for I := 0 to High(FRows) do
  begin
    FRows[I].Pane.parentNode.removeChild(FRows[I].Pane);
    FRows[I].Tab.parentNode.removeChild(FRows[I].Tab);
  end;
  FRows := nil;
end;

procedure TStudioStructure.AddSection(const AName, ABars: String; const ARepeatKey: Integer);
var I, J: Integer; LKey: String; LRow, LKeep, LDetails: TJSElement;
begin
  if Length(FRows) >= MaximumMusicFormPhrases then
    raise Exception.Create('This arrangement has reached its section limit.');
  I := Length(FRows);
  SetLength(FRows, I + 1);
  Inc(FSerial);
  FRows[I].Key := FSerial;
  LKey := IntToStr(FSerial);
  FRows[I].Tab := Add(FList, 'button', AName);
  FRows[I].Tab.id := 'structure-tab-' + LKey;
  FRows[I].Tab.setAttribute('role', 'tab');
  FRows[I].Tab.setAttribute('type', 'button');
  FRows[I].Tab.setAttribute('aria-controls', 'structure-section-' + LKey);
  FRows[I].Tab.setAttribute('data-structure-action', 'select');
  FRows[I].Tab.setAttribute('data-section', LKey);
  FRows[I].Pane := Add(FPanels, 'section', '');
  FRows[I].Pane.id := 'structure-section-' + LKey;
  FRows[I].Pane.setAttribute('role', 'tabpanel');
  FRows[I].Pane.setAttribute('aria-labelledby', FRows[I].Tab.id);
  LRow := Add(FRows[I].Pane, 'div', '');
  LRow.className := 'structure-toolbar';
  LRow.setAttribute('role', 'toolbar');
  LRow.setAttribute('aria-label', 'Move or remove this section');
  Button(LRow, 'up', '↑ Earlier');
  Button(LRow, 'down', '↓ Later');
  Button(LRow, 'remove', 'Remove section');
  FRows[I].Name := Input(FRows[I].Pane, 'structure-name-' + LKey, 'Section name', AName);
  FRows[I].Name.setAttribute('maxlength', '128');
  LDetails := Add(FRows[I].Pane, 'details', '');
  Add(LDetails, 'summary', 'Section grouping');
  FRows[I].GroupName := Input(LDetails, 'structure-group-' + LKey,
    'Group name · optional', '');
  FRows[I].GroupName.setAttribute('maxlength', '128');
  FRows[I].Bars := Input(FRows[I].Pane, 'structure-bars-' + LKey, 'Length · bars', ABars);
  FRows[I].Bars.setAttribute('type', 'number');
  FRows[I].Bars.setAttribute('min', '0.125');
  FRows[I].Bars.setAttribute('max', '32');
  FRows[I].Bars.setAttribute('step', '0.125');
  FRows[I].Bars.setAttribute('inputmode', 'decimal');
  FRows[I].RepeatChoice := Add(Add(FRows[I].Pane, 'label', 'Make this section'), 'select', '');
  FRows[I].RepeatChoice.id := 'structure-repeat-' + LKey;
  FRows[I].RepeatChoice.setAttribute('data-structure', 'true');
  FRows[I].RepeatChoice.setAttribute('data-repeat-key', IntToStr(ARepeatKey));
  FRows[I].KeepGroup := Add(FRows[I].Pane, 'fieldset', '');
  Add(FRows[I].KeepGroup, 'legend', 'Keep from the earlier section');
  LKeep := Add(FRows[I].KeepGroup, 'div', '');
  LKeep.className := 'structure-keep';
  for J := 0 to 7 do
  begin
    FRows[I].Keep[J] := TJSHTMLInputElement(Input(LKeep, 'structure-keep-' +
      LKey + '-' + IntToStr(J), CNames[J], ''));
    FRows[I].Keep[J].setAttribute('type', 'checkbox');
    FRows[I].Keep[J].checked := True;
  end;
  Update;
  Select(FSerial);
end;

procedure TStudioStructure.Update;
var
  I, J, LReference, LCells: Integer;
  LChoice, LName: String;
  LOption: TJSElement;
  LConfig: TJSArray;
  LNodes: TJSNodeList;
begin
  TJSHTMLInputElement(FToggle).disabled := not FEditing;
  LNodes := FRoot.querySelectorAll('[data-structure-action="add"],[data-structure-action="preset"]');
  for I := 0 to LNodes.length - 1 do TJSHTMLButtonElement(LNodes[I]).disabled := not FEditing;
  if Enabled then FBody.removeAttribute('hidden') else FBody.setAttribute('hidden', '');
  for I := 0 to High(FRows) do
  begin
    LChoice := FRows[I].RepeatChoice.getAttribute('data-repeat-key');
    FRows[I].RepeatChoice.innerHTML := '';
    Add(FRows[I].RepeatChoice, 'option', 'New music').setAttribute('value', '0');
    for J := 0 to High(FRows) do
      if (J < I) or (IntToStr(FRows[J].Key) = LChoice) then
      begin
        LName := TJSHTMLInputElement(FRows[J].Name).value;
        if J >= I then LName := LName + ' (must be earlier)';
        LOption := Add(FRows[I].RepeatChoice, 'option', 'Repeat ' + LName);
        LOption.setAttribute('value', IntToStr(FRows[J].Key));
      end;
    TJSHTMLSelectElement(FRows[I].RepeatChoice).value := LChoice;
    LReference := IndexOf(StrToIntDef(LChoice, 0));
    if (LReference >= 0) and (LReference < I) then
      TJSHTMLInputElement(FRows[I].Bars).value := TJSHTMLInputElement(FRows[LReference].Bars).value;
    TJSHTMLInputElement(FRows[I].Name).disabled := not FEditing;
    TJSHTMLInputElement(FRows[I].GroupName).disabled := not FEditing;
    TJSHTMLInputElement(FRows[I].Bars).disabled := not FEditing or (LReference >= 0);
    TJSHTMLSelectElement(FRows[I].RepeatChoice).disabled := not FEditing;
    if LReference >= 0 then FRows[I].KeepGroup.removeAttribute('hidden')
    else FRows[I].KeepGroup.setAttribute('hidden', '');
    for J := 0 to 7 do FRows[I].Keep[J].disabled := not FEditing;
    LName := TJSHTMLInputElement(FRows[I].Name).value;
    if LName = '' then LName := 'Unnamed section';
    FRows[I].Tab.textContent := IntToStr(I + 1) + ' · ' + LName;
    { Big Boss: do not detach the focused editor on every keystroke. Only move
      existing nodes when the operator changes their actual section order. }
    if FList.children.item(I) <> FRows[I].Tab then
      FList.insertBefore(FRows[I].Tab, FList.children.item(I));
    if FPanels.children.item(I) <> FRows[I].Pane then
      FPanels.insertBefore(FRows[I].Pane, FPanels.children.item(I));
    LNodes := FRows[I].Pane.querySelectorAll('button[data-structure-action]');
    for J := 0 to LNodes.length - 1 do
      TJSHTMLButtonElement(LNodes[J]).disabled := not FEditing or
        ((TJSElement(LNodes[J]).getAttribute('data-structure-action') = 'up') and (I = 0)) or
        ((TJSElement(LNodes[J]).getAttribute('data-structure-action') = 'down') and (I = High(FRows))) or
        ((TJSElement(LNodes[J]).getAttribute('data-structure-action') = 'remove') and (Length(FRows) = 1));
  end;
  try
    LConfig := ReadConfig(LCells);
    if LConfig = nil then FStatus.textContent := 'Turn on to arrange sections. Otherwise Music sets the length.'
    else FStatus.textContent := IntToStr(Length(FRows)) + ' sections · ' + FloatToStr(LCells / 8) + ' bars.';
  except on E: Exception do FStatus.textContent := E.Message end;
end;

procedure TStudioStructure.Changed;
var LOptions: TJSEventInit;
begin
  Update;
  LOptions := Default(TJSEventInit);
  LOptions.bubbles := True;
  FRoot.dispatchEvent(TJSEvent.new('change', LOptions));
end;

function TStudioStructure.Edit(AEvent: TEventListenerEvent): Boolean;
var I: Integer;
begin
  Result := False;
  for I := 0 to High(FRows) do
    if AEvent.target = FRows[I].RepeatChoice then
      FRows[I].RepeatChoice.setAttribute('data-repeat-key', TJSHTMLSelectElement(FRows[I].RepeatChoice).value);
  Update;
end;

function TStudioStructure.Key(AEvent: TJSKeyboardEvent): Boolean;
begin
  Result := HandleWorkspaceTabKey(AEvent);
end;

function TStudioStructure.Click(AEvent: TJSMouseEvent): Boolean;
var LButton: TJSElement; LAction, LName: String; I, J, LReference: Integer; LRow: TStudioSectionRow;
begin
  Result := False;
  LButton := TJSElement(AEvent.target).closest('button[data-structure-action]');
  if LButton = nil then Exit;
  LAction := LButton.getAttribute('data-structure-action');
  if LAction = 'select' then
  begin
    Select(StrToInt(LButton.getAttribute('data-section')));
    Exit;
  end;
  if not FEditing then Exit;
  try
    if LAction = 'add' then AddSection('Section ' + IntToStr(Length(FRows) + 1), '8')
    else if LAction = 'preset' then
    begin
      Clear;
      AddSection('A', '8');
      LReference := FRows[0].Key;
      AddSection('B', '8');
      AddSection('A return', '8', LReference);
      Select(LReference);
    end
    else
    begin
      I := SelectedIndex;
      LRow := FRows[I];
      if LAction = 'remove' then
      begin
        for J := 0 to High(FRows) do
          if FRows[J].RepeatChoice.getAttribute('data-repeat-key') = IntToStr(LRow.Key) then
            raise Exception.Create('Another section repeats this one. Change that repeat before removing its source.');
        LRow.Pane.parentNode.removeChild(LRow.Pane);
        LRow.Tab.parentNode.removeChild(LRow.Tab);
        for J := I to High(FRows) - 1 do FRows[J] := FRows[J + 1];
        SetLength(FRows, Length(FRows) - 1);
        if I >= Length(FRows) then I := High(FRows);
        Select(FRows[I].Key);
      end
      else
      begin
        J := I - 1;
        if LAction = 'down' then J := I + 1;
        if (J < 0) or (J > High(FRows)) then Exit;
        FRows[I] := FRows[J];
        FRows[J] := LRow;
        Select(LRow.Key);
      end;
    end;
    Changed;
    if (LAction = 'up') or (LAction = 'down') then
    begin
      LButton := FRows[SelectedIndex].Pane.querySelector(
        'button[data-structure-action="' + LAction + '"]');
      if (LButton <> nil) and not TJSHTMLButtonElement(LButton).disabled then
        TJSHTMLElement(LButton).focus
      else TJSHTMLElement(FRows[SelectedIndex].Tab).focus;
    end;
  except on E: Exception do FStatus.textContent := E.Message end;
end;

function TStudioStructure.ReadConfig(out ACells: Integer): TJSArray;
var
  LForm: TMusicForm;
  LCursor: TMusicFormCursor;
  LRow: TJSObject;
  LKeep: TJSArray;
  I, J, LCount: Integer;
  LValue: Double;
begin
  Result := nil;
  ACells := 0;
  if not Enabled then Exit;
  SetLength(LForm, Length(FRows));
  for I := 0 to High(FRows) do
  begin
    LForm[I].Name := TJSHTMLInputElement(FRows[I].Name).value;
    LForm[I].Section := TJSHTMLInputElement(FRows[I].GroupName).value;
    if LForm[I].Section = '' then LForm[I].Section := LForm[I].Name;
    if not TryStrToFloat(TJSHTMLInputElement(FRows[I].Bars).value, LValue) then
      raise Exception.Create('Give each section a length in bars.');
    LValue := LValue * 8;
    if (LValue <> Trunc(LValue)) or (LValue < 1) or (LValue > MaximumMusicDecisionCells) then
      raise Exception.Create('Use 0.125–32 bars, in eighth-note steps.');
    LForm[I].Cells := Trunc(LValue);
    LForm[I].RepeatFrom := IndexOf(StrToIntDef(FRows[I].RepeatChoice.getAttribute('data-repeat-key'), 0));
    if (FRows[I].RepeatChoice.getAttribute('data-repeat-key') <> '0') and
      (LForm[I].RepeatFrom < 0) then
      raise Exception.Create('Choose an existing earlier section for this repeat.');
    if LForm[I].RepeatFrom >= 0 then
    begin
      if LForm[I].RepeatFrom >= I then
        raise Exception.Create('Move a repeated section after its source.');
      LCount := 0;
      for J := 0 to 7 do if FRows[I].Keep[J].checked then Inc(LCount);
      SetLength(LForm[I].Keep, LCount);
      LCount := 0;
      for J := 0 to 7 do if FRows[I].Keep[J].checked then
      begin
        LForm[I].Keep[LCount] := CKeys[J];
        Inc(LCount);
      end;
    end;
  end;
  LCursor := TMusicFormCursor.Create(LForm,
    ['harmony', 'rhythm', 'bass', 'harmony-voice', 'lead', 'kick', 'snare', 'hat']);
  try ACells := LCursor.TotalCells finally LCursor.Free end;
  Result := TJSArray.new;
  for I := 0 to High(LForm) do
  begin
    LRow := TJSObject.new;
    LRow['section'] := LForm[I].Section;
    LRow['name'] := LForm[I].Name;
    LRow['cells'] := LForm[I].Cells;
    LRow['repeat_from'] := LForm[I].RepeatFrom;
    LKeep := TJSArray.new;
    for J := 0 to High(LForm[I].Keep) do LKeep.push(LForm[I].Keep[J]);
    LRow['keep'] := LKeep;
    Result.push(LRow);
  end;
end;

procedure TStudioStructure.RestoreConfig(AValue: JSValue);
var LRows, LKeep: TJSArray; LRow: TJSObject; I, J, K, LReference: Integer;
begin
  Clear;
  TJSHTMLInputElement(FToggle).checked := isArray(AValue);
  if not Enabled then AddSection('A', '4')
  else
  begin
    LRows := TJSArray(AValue);
    for I := 0 to LRows.length - 1 do
    begin
      LRow := TJSObject(LRows[I]);
      AddSection(String(LRow['name']), FloatToStr(Double(LRow['cells']) / 8));
      if String(LRow['section']) <> String(LRow['name']) then
        TJSHTMLInputElement(FRows[I].GroupName).value := String(LRow['section']);
      LReference := Trunc(Double(LRow['repeat_from']));
      if (LReference >= 0) and (LReference < I) then
        FRows[I].RepeatChoice.setAttribute('data-repeat-key', IntToStr(FRows[LReference].Key));
      LKeep := TJSArray(LRow['keep']);
      for J := 0 to 7 do
      begin
        FRows[I].Keep[J].checked := False;
        for K := 0 to LKeep.length - 1 do
          if String(LKeep[K]) = CKeys[J] then FRows[I].Keep[J].checked := True;
      end;
    end;
  end;
  Update;
  if Length(FRows) > 0 then Select(FRows[0].Key);
end;

function TStudioStructure.ReadDraft: TJSObject;
var LRows, LKeep: TJSArray; LRow: TJSObject; I, J: Integer;
begin
  Result := TJSObject.new;
  Result['enabled'] := Enabled;
  LRows := TJSArray.new;
  Result['rows'] := LRows;
  for I := 0 to High(FRows) do
  begin
    LRow := TJSObject.new;
    LRow['key'] := FRows[I].Key;
    LRow['name'] := TJSHTMLInputElement(FRows[I].Name).value;
    LRow['group'] := TJSHTMLInputElement(FRows[I].GroupName).value;
    LRow['bars'] := TJSHTMLInputElement(FRows[I].Bars).value;
    LRow['repeat_key'] := FRows[I].RepeatChoice.getAttribute('data-repeat-key');
    LKeep := TJSArray.new;
    for J := 0 to 7 do LKeep.push(FRows[I].Keep[J].checked);
    LRow['keep'] := LKeep;
    LRows.push(LRow);
  end;
end;

procedure TStudioStructure.RestoreDraft(ADraft: TJSObject);
var LRows: TJSArray; LRow: TJSObject; I, J, K, LReference: Integer;
begin
  if (ADraft = nil) or not isArray(ADraft['rows']) then Exit;
  LRows := TJSArray(ADraft['rows']);
  if (LRows.length < 1) or (LRows.length > MaximumMusicFormPhrases) then Exit;
  Clear;
  TJSHTMLInputElement(FToggle).checked := Boolean(ADraft['enabled']);
  for I := 0 to LRows.length - 1 do
  begin
    LRow := TJSObject(LRows[I]);
    AddSection(String(LRow['name']), String(LRow['bars']));
    if isString(LRow['group']) then TJSHTMLInputElement(FRows[I].GroupName).value := String(LRow['group']);
    for J := 0 to 7 do FRows[I].Keep[J].checked := Boolean(TJSArray(LRow['keep'])[J]);
  end;
  for I := 0 to LRows.length - 1 do
  begin
    LReference := StrToIntDef(String(TJSObject(LRows[I])['repeat_key']), 0);
    for K := 0 to LRows.length - 1 do
      if Trunc(Double(TJSObject(LRows[K])['key'])) = LReference then
        FRows[I].RepeatChoice.setAttribute('data-repeat-key', IntToStr(FRows[K].Key));
  end;
  Update;
  Select(FRows[0].Key);
end;

procedure TStudioStructure.SetEnabled(const AEnabled: Boolean);
begin
  FEditing := AEnabled;
  Update;
end;

end.
