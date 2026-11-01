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
unit pythian.studio.sounds;

{$mode delphi}{$H+}

interface

uses JS, Web, SysUtils, pythian.studio.sources, pythian.studio.effect.controls;

type
  TStudioSoundApply = procedure(ADesign: TJSObject) of object;
  { Big Boss: optional presentation over native recipe/job contracts. No audio
    renderer, inference, polling loop or second result player lives here. }
  TStudioSounds = class
  private
    FFetch: TStudioFetch;
    FApplyEvent: TStudioSoundApply;
    FDialog: TJSElement;
    FBody: TJSElement;
    FStatus: TJSElement;
    FApply: TJSElement;
    FName: TJSElement;
    FSetups: TJSElement;
    FRoleChoice: TJSElement;
    FRack: TStudioEffectRackControls;
    FCatalog: TJSObject;
    FDesign: TJSObject;
    FPatches: TJSArray;
    FOriginal: String;
    FPage: String;
    FRole: Integer;
    FZone: Integer;
    FEpoch: Integer;
    FLoading: Boolean;
    FAvailable: Boolean;
    FDirty: Boolean;
    function Json(const APath, AMethod, ABody: String): TJSObject; async;
    function Recipe: TJSObject;
    function Zone: TJSObject;
    procedure Notice(const AText: String);
    procedure Changed;
    procedure CommitRack;
    procedure Draw;
    procedure DrawInstrument;
    procedure DrawEnvelope;
    procedure DrawMotion;
    procedure DrawEffects;
    procedure DrawSetups;
    procedure Number(AParent: TJSElement; AObject: TJSObject;
      const AKey, ACaption: String; const AMinimum, AMaximum: Double;
      const AInteger: Boolean = False);
    procedure Choice(AParent: TJSElement; AObject: TJSObject;
      const AKey, ACaption: String; const ACaptions: array of String;
      const ARedraw: Boolean = False);
    procedure Check(AParent: TJSElement; AObject: TJSObject;
      const AKey, ACaption: String);
    procedure Curve(AParent: TJSElement; AOwner: TJSObject;
      const AKey, ACaption: String);
    procedure RemoveRow(AParent: TJSElement; ARows: TJSArray;
      const AIndex, AMinimum: Integer);
    function Click(AEvent: TEventListenerEvent): Boolean;
    function RoleChanged(AEvent: TEventListenerEvent): Boolean;
    procedure SaveSetup; async;
    procedure LoadSetup; async;
  public
    constructor Create(AParent: TJSElement; const AFetch: TStudioFetch;
      const AApply: TStudioSoundApply);
    destructor Destroy; override;
    procedure Open(const AJobId: String); async;
    procedure SetAvailable(const AAvailable: Boolean);
  end;

implementation

uses Math, pythian.effects.catalog;

const
  CParts: array[0..6] of String = ('Bass', 'Harmony', 'Lead', 'Kick', 'Snare', 'Hat', 'Full mix');
  CTargets: array[0..4] of String = ('Frequency · Hz', 'Pitch · cents',
    'Volume · multiplier', 'Pan · −1 left to 1 right', 'Filter cutoff · Hz');

function CopyObject(AValue: TJSObject): TJSObject;
begin
  Result := TJSObject(TJSJSON.parse(TJSJSON.stringify(AValue)));
end;

procedure Listen(AElement: TJSElement; const AEvent: String;
  const AHandler: TJSEventHandler);
begin
  AElement.addEventListener(AEvent, AHandler);
end;

function Add(AParent: TJSElement; const ATag, AText: String;
  const AClass: String = ''): TJSElement;
begin
  Result := document.createElement(ATag);
  Result.textContent := AText;
  Result.className := AClass;
  AParent.appendChild(Result);
end;

function Button(AParent: TJSElement; const ACaption: String;
  const AClick: TJSEventHandler): TJSElement;
begin
  Result := Add(AParent, 'button', ACaption);
  Result.setAttribute('type', 'button');
  Result.addEventListener('click', AClick);
end;

function PointsCurve(const AValue: Double): TJSObject;
var
  LRows: TJSArray;
begin
  Result := TJSObject.new;
  Result['kind'] := 0;
  LRows := TJSArray.new;
  LRows.push(TJSArray.new(0, AValue, 1));
  LRows.push(TJSArray.new(1, AValue, 0));
  Result['points'] := LRows;
end;

constructor TStudioSounds.Create(AParent: TJSElement; const AFetch: TStudioFetch;
  const AApply: TStudioSoundApply);
var
  LHeader: TJSElement;
  LRow: TJSElement;
  LButton: TJSElement;
  LOption: TJSElement;
  LDetails: TJSElement;
  I: Integer;
begin
  inherited Create;
  FFetch := AFetch;
  FApplyEvent := AApply;
  FAvailable := True;
  FDialog := Add(AParent, 'dialog', '', 'sound-editor');
  FDialog.id := 'sound-dialog';
  FDialog.setAttribute('aria-labelledby', 'sound-dialog-title');
  LHeader := Add(FDialog, 'header', '', 'dialog-heading');
  Add(LHeader, 'h2', 'Sounds & effects').id := 'sound-dialog-title';
  LButton := Button(LHeader, 'Done', @Click);
  LButton.setAttribute('data-sound-action', 'close');
  Add(FDialog, 'p', 'Keep the notes. Shape a part, then create a new version to hear it.', 'hint');
  LDetails := Add(FDialog, 'details', '', 'sound-setup-tools');
  Add(LDetails, 'summary', 'Saved sound setups');
  LRow := Add(LDetails, 'div', '', 'sound-setup-toolbar');
  FSetups := Add(Add(LRow, 'label', 'Saved setups'), 'select', '');
  FSetups.id := 'sound-saved-setups';
  Listen(FSetups, 'change',
    function(AEvent: TEventListenerEvent): Boolean
    begin
      Result := False;
      LoadSetup;
    end);
  FName := Add(Add(LRow, 'label', 'Setup name'), 'input', '');
  FName.id := 'sound-setup-name';
  FName.setAttribute('maxlength', '128');
  TJSHTMLInputElement(FName).value := 'My sounds';
  LButton := Button(LRow, 'Save setup', @Click);
  LButton.id := 'sound-save-setup';
  LButton.setAttribute('data-sound-action', 'save');
  FRoleChoice := Add(Add(FDialog, 'label', 'Part'), 'select', '');
  FRoleChoice.id := 'sound-part';
  for I := 0 to High(CParts) do
  begin
    LOption := Add(FRoleChoice, 'option', CParts[I]);
    LOption.setAttribute('value', IntToStr(I));
  end;
  FRoleChoice.addEventListener('change', @RoleChanged);
  LRow := Add(FDialog, 'nav', '', 'sound-tabs');
  LRow.setAttribute('aria-label', 'Sound settings');
  for I := 0 to 3 do
  begin
    case I of
      0: LButton := Button(LRow, 'Instrument', @Click);
      1: LButton := Button(LRow, 'Envelope', @Click);
      2: LButton := Button(LRow, 'Motion', @Click);
      3: LButton := Button(LRow, 'Effects', @Click);
    end;
    LButton.setAttribute('data-sound-action', 'page-' + IntToStr(I));
  end;
  FBody := Add(FDialog, 'div', '', 'sound-editor-body');
  FBody.id := 'sound-editor-body';
  FStatus := Add(FDialog, 'p', '', 'hint');
  FStatus.id := 'sound-editor-status';
  FStatus.setAttribute('role', 'status');
  FApply := Button(FDialog, 'Create new version', @Click);
  FApply.id := 'apply-sounds';
  FApply.className := 'primary';
  FApply.setAttribute('data-sound-action', 'apply');
end;

destructor TStudioSounds.Destroy;
begin
  Inc(FEpoch);
  FRack.Free;
  if FDialog.parentNode <> nil then FDialog.parentNode.removeChild(FDialog);
  inherited Destroy;
end;

procedure TStudioSounds.Notice(const AText: String);
begin
  FStatus.textContent := AText;
end;

procedure TStudioSounds.SetAvailable(const AAvailable: Boolean);
var
  LButtons: TJSNodeList;
  I: Integer;
begin
  FAvailable := AAvailable;
  TJSHTMLButtonElement(FApply).disabled := FLoading or not FAvailable or not FDirty or
    (FBody.querySelector('[aria-invalid="true"]') <> nil);
  TJSHTMLSelectElement(FSetups).disabled := FLoading;
  TJSHTMLInputElement(FName).disabled := FLoading;
  TJSHTMLSelectElement(FRoleChoice).disabled := FLoading;
  TJSHTMLButtonElement(document.getElementById('sound-save-setup')).disabled :=
    FLoading or (FDesign = nil) or not FAvailable;
  if FLoading then FBody.setAttribute('inert', '')
  else FBody.removeAttribute('inert');
  LButtons := FDialog.querySelectorAll('.sound-tabs button');
  for I := 0 to LButtons.length - 1 do
    TJSHTMLButtonElement(LButtons[I]).disabled := FLoading or ((FRole > 2) and (I < 3));
end;

procedure TStudioSounds.Changed;
var
  LOrigin: String;
begin
  if (FDesign <> nil) and (FRole < 3) and (FPage <> '3') then
  begin
    LOrigin := StudioControlText(Recipe, 'origin');
    if Pos('Operator edit; basis: ', LOrigin) <> 1 then
      Recipe['origin'] := 'Operator edit; basis: ' + LOrigin;
  end;
  FDirty := True;
  SetAvailable(FAvailable);
  Notice('Settings changed. Create a new version to compare the mix or an individual part.');
end;

function TStudioSounds.Json(const APath, AMethod, ABody: String): TJSObject; async;
var
  LResponse: TJSResponse;
begin
  LResponse := await(TJSResponse, FFetch(APath, AMethod, ABody));
  if LResponse.status <> 200 then
    raise Exception.Create(Copy(Trim(await(String, LResponse.text())), 1, 256));
  Result := await(TJSObject, LResponse.json());
end;

procedure TStudioSounds.Open(const AJobId: String); async;
var
  LEpoch: Integer;
  LPatches: TJSObject;
  LCatalog: TJSObject;
  LDesign: TJSObject;
begin
  Inc(FEpoch);
  LEpoch := FEpoch;
  FLoading := True;
  FDirty := False;
  FDesign := nil;
  FreeAndNil(FRack);
  FBody.innerHTML := '';
  SetAvailable(FAvailable);
  TStudioDialog(FDialog).showModal;
  Notice('Opening saved sounds…');
  try
    LCatalog := await(TJSObject, Json('/api/studio/sound-catalog', 'GET', ''));
    LDesign := await(TJSObject, Json('/api/studio/sound-design?job=' + encodeURIComponent(AJobId), 'GET', ''));
    LPatches := await(TJSObject, Json('/api/studio/sound-patches', 'GET', ''));
    if LEpoch <> FEpoch then Exit;
    FCatalog := LCatalog;
    FDesign := LDesign;
    FPatches := TJSArray(LPatches['patches']);
    FOriginal := TJSJSON.stringify(FDesign);
    FRole := 0;
    FZone := 0;
    FPage := '0';
    TJSHTMLSelectElement(FRoleChoice).value := '0';
    DrawSetups;
    Draw;
    Notice('Experimental. Saving a setup never starts learning or generation.');
  except
    on E: Exception do if LEpoch = FEpoch then Notice(E.Message);
  end;
  if LEpoch = FEpoch then
  begin
    FLoading := False;
    SetAvailable(FAvailable);
  end;
end;

function TStudioSounds.Recipe: TJSObject;
begin
  Result := TJSObject(TJSArray(FDesign['instruments'])[FRole]);
end;

function TStudioSounds.Zone: TJSObject;
begin
  Result := TJSObject(TJSArray(Recipe['zones'])[FZone]);
end;

procedure TStudioSounds.Number(AParent: TJSElement; AObject: TJSObject;
  const AKey, ACaption: String; const AMinimum, AMaximum: Double;
  const AInteger: Boolean);
var
  LInput: TJSElement;
begin
  LInput := Add(Add(AParent, 'label', ACaption), 'input', '');
  LInput.setAttribute('type', 'text');
  LInput.setAttribute('inputmode', 'decimal');
  LInput.setAttribute('maxlength', '24');
  TJSHTMLInputElement(LInput).value := StudioControlText(AObject, AKey);
  Listen(LInput, 'input',
    function(AEvent: TEventListenerEvent): Boolean
    var
      LValue: Double;
    begin
      Result := False;
      try
        LValue := ReadStudioDecimal(TJSHTMLInputElement(LInput).value,
          ACaption, AMinimum, AMaximum, LInput);
        if AInteger and (Frac(LValue) <> 0) then
        begin
          LInput.setAttribute('aria-invalid', 'true');
          raise Exception.Create(ACaption + ': use a whole number.');
        end;
        AObject[AKey] := LValue;
        Changed;
      except
        on E: Exception do Notice(E.Message);
      end;
      TJSHTMLButtonElement(FApply).disabled := FLoading or not FAvailable or
        (FBody.querySelector('[aria-invalid="true"]') <> nil);
    end);
end;

procedure TStudioSounds.Choice(AParent: TJSElement; AObject: TJSObject;
  const AKey, ACaption: String; const ACaptions: array of String;
  const ARedraw: Boolean);
var
  LSelect: TJSElement;
  LOption: TJSElement;
  I: Integer;
begin
  LSelect := Add(Add(AParent, 'label', ACaption), 'select', '');
  for I := 0 to High(ACaptions) do
  begin
    LOption := Add(LSelect, 'option', ACaptions[I]);
    LOption.setAttribute('value', IntToStr(I));
  end;
  TJSHTMLSelectElement(LSelect).value := StudioControlText(AObject, AKey);
  Listen(LSelect, 'change',
    function(AEvent: TEventListenerEvent): Boolean
    begin
      Result := False;
      AObject[AKey] := StrToInt(TJSHTMLSelectElement(AEvent.currentTarget).value);
      Changed;
      if ARedraw then Draw;
    end);
end;

procedure TStudioSounds.RemoveRow(AParent: TJSElement; ARows: TJSArray;
  const AIndex, AMinimum: Integer);
var
  LButton: TJSElement;
begin
  LButton := Button(AParent, 'Remove',
    function(AEvent: TEventListenerEvent): Boolean
    begin
      Result := False;
      if ARows.length <= AMinimum then Exit;
      ARows.splice(AIndex, 1);
      Changed;
      Draw;
    end);
  TJSHTMLButtonElement(LButton).disabled := ARows.length <= AMinimum;
end;

procedure TStudioSounds.Check(AParent: TJSElement; AObject: TJSObject;
  const AKey, ACaption: String);
var
  LLabel: TJSElement;
  LInput: TJSElement;
begin
  LLabel := Add(AParent, 'label', '', 'sound-check');
  LInput := Add(LLabel, 'input', '');
  LInput.setAttribute('type', 'checkbox');
  TJSHTMLInputElement(LInput).checked := Boolean(AObject[AKey]);
  Add(LLabel, 'span', ACaption);
  Listen(LInput, 'change',
    function(AEvent: TEventListenerEvent): Boolean
    begin
      Result := False;
      AObject[AKey] := TJSHTMLInputElement(LInput).checked;
      Changed;
    end);
end;

procedure TStudioSounds.Curve(AParent: TJSElement; AOwner: TJSObject;
  const AKey, ACaption: String);
var
  LCurve: TJSObject;
  LRows: TJSArray;
  LRow: TJSElement;
  LSelect: TJSElement;
  LOption: TJSElement;
  I: Integer;
begin
  LCurve := TJSObject(AOwner[AKey]);
  if LCurve = nil then Exit;
  Add(AParent, 'h3', ACaption);
  LSelect := Add(Add(AParent, 'label', 'Movement'), 'select', '');
  LOption := Add(LSelect, 'option', 'Points over time'); LOption.setAttribute('value', '0');
  LOption := Add(LSelect, 'option', 'Repeating LFO'); LOption.setAttribute('value', '1');
  TJSHTMLSelectElement(LSelect).value := StudioControlText(LCurve, 'kind');
  Listen(LSelect, 'change',
    function(AEvent: TEventListenerEvent): Boolean
    var
      LNew: TJSObject;
      LMinimum: Double;
      LMaximum: Double;
      LPoints: TJSArray;
      J: Integer;
    begin
      Result := False;
      if TJSHTMLSelectElement(LSelect).value = '0' then LNew := PointsCurve(1)
      else
      begin
        LNew := TJSObject.new;
        LNew['kind'] := 1; LNew['hz'] := 1; LNew['phase'] := 0;
        LMinimum := 1;
        LMaximum := 1;
        if isArray(LCurve['points']) then
        begin
          LPoints := TJSArray(LCurve['points']);
          LMinimum := Double(TJSArray(LPoints[0])[1]);
          LMaximum := LMinimum;
          for J := 1 to LPoints.length - 1 do
          begin
            LMinimum := Min(LMinimum, Double(TJSArray(LPoints[J])[1]));
            LMaximum := Max(LMaximum, Double(TJSArray(LPoints[J])[1]));
          end;
        end;
        if LMinimum = LMaximum then
        begin
          LMinimum := LMinimum - 0.1 * Max(1, Abs(LMinimum));
          LMaximum := LMaximum + 0.1 * Max(1, Abs(LMaximum));
        end;
        if (Pos('Volume', ACaption) = 1) or (Pos('volume multiplier', ACaption) > 0) then
        begin LMinimum := Max(0, LMinimum); LMaximum := Min(1, LMaximum) end;
        if Pos('Pan', ACaption) = 1 then
        begin LMinimum := Max(-1, LMinimum); LMaximum := Min(1, LMaximum) end;
        if isArray(AOwner['tables']) then
        begin LMinimum := Max(0, LMinimum); LMaximum := Min(TJSArray(AOwner['tables']).length - 1, LMaximum) end;
        LNew['shape'] := 0;
        LNew['scale'] := (LMaximum - LMinimum) / 2;
        LNew['offset'] := (LMaximum + LMinimum) / 2;
      end;
      AOwner[AKey] := LNew;
      Changed;
      Draw;
    end);
  if StudioNumber(LCurve, 'kind') = 1 then
  begin
    LRow := Add(AParent, 'div', '', 'range-fields');
    Number(LRow, LCurve, 'hz', 'Speed · Hz', 0.0001, 24000);
    Number(LRow, LCurve, 'phase', 'Starting phase · cycles', 0, 1);
    Number(LRow, LCurve, 'scale', 'Depth · target units', -1E12, 1E12);
    Number(LRow, LCurve, 'offset', 'Center · target units', -1E12, 1E12);
    Choice(LRow, LCurve, 'shape', 'Shape', ['Sine', 'Triangle']);
  end
  else
  begin
    LRows := TJSArray(LCurve['points']);
    for I := 0 to LRows.length - 1 do
    begin
      LRow := Add(AParent, 'div', '', 'sound-point-row');
      Number(LRow, TJSObject(LRows[I]), '0', 'Time · seconds', 0, 86400);
      Number(LRow, TJSObject(LRows[I]), '1', 'Value · target units', -1E12, 1E12);
      Choice(LRow, TJSObject(LRows[I]), '2', 'To next point', ['Hold', 'Linear', 'Exponential']);
      RemoveRow(LRow, LRows, I, 1);
    end;
    Button(AParent, 'Add point',
      function(AEvent: TEventListenerEvent): Boolean
      var
        LLast: TJSArray;
      begin
        Result := False;
        if LRows.length >= StudioNumber(FCatalog, 'maximum_curve_points') then Exit;
        LLast := TJSArray(LRows[LRows.length - 1]);
        LRows.push(TJSArray.new(Double(LLast[0]) + 0.25, LLast[1], 1));
        Changed;
        Draw;
      end);
  end;
end;

procedure TStudioSounds.CommitRack;
var
  LMix: TJSObject;
begin
  if FBody.querySelector('[aria-invalid="true"]') <> nil then
    raise Exception.Create('Correct the highlighted setting first.');
  if FRack = nil then Exit;
  LMix := TJSObject(FDesign['mix']);
  if FRole = 6 then LMix['master'] := FRack.Request(24000)
  else TJSObject(TJSArray(LMix['parts'])[FRole])['effects'] := FRack.Request(24000);
end;

function TStudioSounds.RoleChanged(AEvent: TEventListenerEvent): Boolean;
begin
  Result := False;
  try
    CommitRack;
    FRole := StrToInt(TJSHTMLSelectElement(FRoleChoice).value);
    FZone := 0;
    if FRole > 2 then FPage := '3';
    Draw;
  except
    on E: Exception do
    begin
      TJSHTMLSelectElement(FRoleChoice).value := IntToStr(FRole);
      Notice(E.Message);
    end;
  end;
end;

procedure TStudioSounds.Draw;
var
  LButtons: TJSNodeList;
  LButton: TJSElement;
  I: Integer;
  LZones: TJSArray;
  LSelect: TJSElement;
  LOption: TJSElement;
begin
  FreeAndNil(FRack);
  FBody.innerHTML := '';
  if FDesign = nil then Exit;
  LButtons := FDialog.querySelectorAll('.sound-tabs button');
  for I := 0 to LButtons.length - 1 do
  begin
    LButton := TJSElement(LButtons[I]);
    if LButton.getAttribute('data-sound-action') = 'page-' + FPage then
      LButton.setAttribute('aria-pressed', 'true')
    else LButton.setAttribute('aria-pressed', 'false');
    TJSHTMLButtonElement(LButton).disabled := (FRole > 2) and (I < 3);
  end;
  if (FRole < 3) and (FPage <> '3') then
  begin
    LZones := TJSArray(Recipe['zones']);
    LSelect := Add(Add(FBody, 'label', 'Instrument layer'), 'select', '');
    LSelect.id := 'sound-layer';
    for I := 0 to LZones.length - 1 do
    begin
      LOption := Add(LSelect, 'option', 'Layer ' + IntToStr(I + 1));
      LOption.setAttribute('value', IntToStr(I));
    end;
    TJSHTMLSelectElement(LSelect).value := IntToStr(FZone);
    Listen(LSelect, 'change',
      function(AEvent: TEventListenerEvent): Boolean
      begin
        Result := False;
        if FBody.querySelector('[aria-invalid="true"]') <> nil then
        begin
          TJSHTMLSelectElement(LSelect).value := IntToStr(FZone);
          Notice('Correct the highlighted setting first.');
          Exit;
        end;
        FZone := StrToInt(TJSHTMLSelectElement(AEvent.currentTarget).value);
        Draw;
      end);
  end;
  case FPage of
    '0': DrawInstrument;
    '1': DrawEnvelope;
    '2': DrawMotion;
    '3': DrawEffects;
  end;
end;

procedure TStudioSounds.DrawSetups;
var
  LOption: TJSElement;
  I: Integer;
begin
  FSetups.innerHTML := '';
  LOption := Add(FSetups, 'option', 'Choose a saved setup');
  LOption.setAttribute('value', '');
  for I := 0 to FPatches.length - 1 do
  begin
    LOption := Add(FSetups, 'option', StudioControlText(TJSObject(FPatches[I]), 'name'));
    LOption.setAttribute('value', StudioControlText(TJSObject(FPatches[I]), 'id'));
  end;
end;

procedure TStudioSounds.SaveSetup; async;
var
  LWrite: TJSObject;
  LSaved: TJSObject;
  LList: TJSObject;
  LEpoch: Integer;
begin
  if FLoading or (FDesign = nil) then Exit;
  LEpoch := FEpoch;
  try
    CommitRack;
    LWrite := TJSObject.new;
    LWrite['format'] := 'pythian.studio.sound-patch.write.v1';
    LWrite['name'] := TJSHTMLInputElement(FName).value;
    LWrite['design'] := CopyObject(FDesign);
    FLoading := True;
    SetAvailable(FAvailable);
    Notice('Saving setup…');
    LSaved := await(TJSObject, Json('/api/studio/sound-patch', 'POST', TJSJSON.stringify(LWrite)));
    LList := await(TJSObject, Json('/api/studio/sound-patches', 'GET', ''));
    if LEpoch <> FEpoch then Exit;
    FPatches := TJSArray(LList['patches']);
    DrawSetups;
    TJSHTMLSelectElement(FSetups).value := StudioControlText(LSaved, 'id');
    Notice('Setup saved. Your music and learning model are unchanged.');
  except
    on E: Exception do if LEpoch = FEpoch then Notice(E.Message);
  end;
  if LEpoch <> FEpoch then Exit;
  FLoading := False;
  SetAvailable(FAvailable);
end;

procedure TStudioSounds.LoadSetup; async;
var
  LId: String;
  LSaved: TJSObject;
  LEpoch: Integer;
begin
  if FLoading then Exit;
  LEpoch := FEpoch;
  LId := TJSHTMLSelectElement(FSetups).value;
  if LId = '' then Exit;
  FLoading := True;
  SetAvailable(FAvailable);
  try
    LSaved := await(TJSObject, Json('/api/studio/sound-patch?id=' + encodeURIComponent(LId), 'GET', ''));
    if LEpoch <> FEpoch then Exit;
    FDesign := CopyObject(TJSObject(LSaved['design']));
    TJSHTMLInputElement(FName).value := StudioControlText(LSaved, 'name');
    FZone := 0;
    Draw;
    FDirty := TJSJSON.stringify(FDesign) <> FOriginal;
    SetAvailable(FAvailable);
    Notice('Setup loaded. Create a new version to hear it on the saved notes.');
  except
    on E: Exception do if LEpoch = FEpoch then Notice(E.Message);
  end;
  if LEpoch <> FEpoch then Exit;
  FLoading := False;
  SetAvailable(FAvailable);
end;

function TStudioSounds.Click(AEvent: TEventListenerEvent): Boolean;
var
  LAction: String;
begin
  Result := False;
  LAction := TJSElement(AEvent.currentTarget).getAttribute('data-sound-action');
  if LAction = 'close' then
  begin
    Inc(FEpoch);
    TStudioDialog(FDialog).close;
    Exit;
  end;
  if LAction = 'save' then begin SaveSetup; Exit end;
  if FLoading or (FDesign = nil) then Exit;
  try
    CommitRack;
    if Pos('page-', LAction) = 1 then
    begin
      FPage := Copy(LAction, 6, 1);
      Draw;
    end
    else if (LAction = 'apply') and FAvailable then
    begin
      if TJSJSON.stringify(FDesign) = FOriginal then
        raise Exception.Create('Change a sound or effect first.');
      FApplyEvent(CopyObject(FDesign));
    end;
  except
    on E: Exception do Notice(E.Message);
  end;
end;

procedure TStudioSounds.DrawInstrument;
var
  LPresets: TJSArray;
  LZones: TJSArray;
  LSelect: TJSElement;
  LOption: TJSElement;
  LFields: TJSElement;
  LToolbar: TJSElement;
  LVoice: TJSObject;
  LSource: TJSObject;
  LRows: TJSArray;
  LTable: TJSObject;
  I: Integer;

  procedure Harmonics(ATable: TJSObject; const AKey, ACaption: String);
  var
    LValues: TJSArray;
    LRow: TJSElement;
    J: Integer;
  begin
    Add(FBody, 'h4', ACaption);
    LValues := TJSArray(ATable[AKey]);
    LRow := Add(FBody, 'div', '', 'range-fields');
    for J := 0 to LValues.length - 1 do
      Number(LRow, TJSObject(LValues), IntToStr(J),
        'Harmonic ' + IntToStr(J + 1), -16, 16);
    Button(FBody, 'Add harmonic',
      function(AEvent: TEventListenerEvent): Boolean
      begin
        Result := False;
        if LValues.length >= StudioNumber(FCatalog, 'maximum_table_harmonics') then Exit;
        LValues.push(0);
        Changed;
        Draw;
      end);
  end;

begin
  Add(FBody, 'h3', CParts[FRole] + ' · ' + StudioControlText(Recipe, 'caption'));
  LPresets := TJSArray(FCatalog['instruments']);
  LSelect := Add(Add(FBody, 'label', 'Replace this instrument with a preset'), 'select', '');
  LSelect.id := 'sound-preset';
  LOption := Add(LSelect, 'option', 'Choose a preset…'); LOption.setAttribute('value', '-1');
  for I := 0 to LPresets.length - 1 do
  begin
    LOption := Add(LSelect, 'option', StudioControlText(TJSObject(LPresets[I]), 'caption'));
    LOption.setAttribute('value', IntToStr(I));
  end;
  Listen(LSelect, 'change',
    function(AEvent: TEventListenerEvent): Boolean
    var
      LIndex: Integer;
    begin
      Result := False;
      LIndex := StrToInt(TJSHTMLSelectElement(AEvent.currentTarget).value);
      if LIndex < 0 then Exit;
      TJSArray(FDesign['instruments'])[FRole] := CopyObject(TJSObject(LPresets[LIndex]));
      FZone := 0;
      Changed;
      Draw;
    end);
  Add(FBody, 'p', StudioControlText(Recipe, 'origin'), 'hint');
  LZones := TJSArray(Recipe['zones']);
  LToolbar := Add(FBody, 'div', '', 'source-toolbar');
  Button(LToolbar, 'Duplicate layer',
    function(AEvent: TEventListenerEvent): Boolean
    begin
      Result := False;
      if LZones.length >= StudioNumber(FCatalog, 'maximum_zones') then
      begin Notice('This Studio instrument has reached its layer limit.'); Exit end;
      LZones.push(CopyObject(Zone));
      FZone := LZones.length - 1;
      Changed;
      Draw;
    end);
  Button(LToolbar, 'Remove layer',
    function(AEvent: TEventListenerEvent): Boolean
    begin
      Result := False;
      if LZones.length <= 1 then Exit;
      LZones.splice(FZone, 1);
      FZone := 0;
      Changed;
      Draw;
    end);
  LFields := Add(FBody, 'div', '', 'range-fields');
  Number(LFields, TJSObject(Zone['keys']), '0', 'Lowest MIDI key', 0, 127, True);
  Number(LFields, TJSObject(Zone['keys']), '1', 'Highest MIDI key', 0, 127, True);
  Number(LFields, TJSObject(Zone['velocity']), '0', 'Lowest velocity', 1, 127, True);
  Number(LFields, TJSObject(Zone['velocity']), '1', 'Highest velocity', 1, 127, True);
  LSource := TJSObject(Zone['source']);
  LVoice := TJSObject(Zone['voice']);
  LSelect := Add(Add(FBody, 'label', 'Synthesis source'), 'select', '');
  LSelect.id := 'sound-source';
  for I := 0 to 4 do
  begin
    case I of
      0: LOption := Add(LSelect, 'option', 'Oscillator / noise');
      1: LOption := Add(LSelect, 'option', 'Additive harmonics');
      2: LOption := Add(LSelect, 'option', 'Moving wavetable');
      3: LOption := Add(LSelect, 'option', 'Frequency modulation · FM');
      4: LOption := Add(LSelect, 'option', 'Phase modulation · PM');
    end;
    LOption.setAttribute('value', IntToStr(I));
  end;
  TJSHTMLSelectElement(LSelect).value := StudioControlText(LSource, 'kind');
  Listen(LSelect, 'change',
    function(AEvent: TEventListenerEvent): Boolean
    var
      LKind: Integer;
      LCandidate: TJSObject;
      J: Integer;
    begin
      Result := False;
      LKind := StrToInt(TJSHTMLSelectElement(AEvent.currentTarget).value);
      for J := 0 to LPresets.length - 1 do
      begin
        LCandidate := TJSObject(TJSObject(TJSArray(TJSObject(LPresets[J])['zones'])[0])['source']);
        if StudioNumber(LCandidate, 'kind') <> LKind then Continue;
        Zone['source'] := CopyObject(LCandidate);
        Changed;
        Draw;
        Break;
      end;
    end);
  Add(FBody, 'p', 'Sampler: library capability; Studio audio binding is not connected yet.', 'hint');
  LFields := Add(FBody, 'div', '', 'range-fields');
  Number(LFields, LVoice, 'gain', 'Layer gain', 0, 1);
  Number(LFields, LVoice, 'pan', 'Layer pan · −1 left / 1 right', -1, 1);
  case Round(StudioNumber(LSource, 'kind')) of
    0:
    begin
      Choice(LFields, LVoice, 'shape', 'Waveform', ['Sine', 'Triangle', 'Saw', 'Square', 'Noise']);
      Choice(LFields, LVoice, 'quality', 'Oscillator', ['Simple', 'Band-limited edges']);
    end;
    1:
    begin
      LRows := TJSArray(LSource['partials']);
      Add(FBody, 'h3', 'Harmonic partials');
      for I := 0 to LRows.length - 1 do
      begin
        LFields := Add(FBody, 'div', '', 'sound-point-row');
        Number(LFields, TJSObject(LRows[I]), '0', 'Frequency ratio', 0.0001, 128);
        Number(LFields, TJSObject(LRows[I]), '1', 'Amplitude', -16, 16);
        Number(LFields, TJSObject(LRows[I]), '2', 'Phase · cycles', 0, 1);
        RemoveRow(LFields, LRows, I, 1);
      end;
      Button(FBody, 'Add partial',
        function(AEvent: TEventListenerEvent): Boolean
        begin
          Result := False;
          if LRows.length >= StudioNumber(FCatalog, 'maximum_partials') then Exit;
          LRows.push(TJSArray.new(LRows.length + 1, 0, 0));
          Changed;
          Draw;
        end);
    end;
    2:
    begin
      Number(FBody, LSource, 'table_size', 'Wavetable size · power of two', 2, 65536, True);
      LRows := TJSArray(LSource['tables']);
      for I := 0 to LRows.length - 1 do
      begin
        LTable := TJSObject(LRows[I]);
        Add(FBody, 'h3', 'Wavetable ' + IntToStr(I + 1));
        Number(FBody, LTable, 'mean', 'DC offset', -1, 1);
        Harmonics(LTable, 'sine', 'Sine amplitudes');
        Harmonics(LTable, 'cosine', 'Cosine amplitudes');
        RemoveRow(FBody, LRows, I, 1);
      end;
      Button(FBody, 'Add wavetable',
        function(AEvent: TEventListenerEvent): Boolean
        begin
          Result := False;
          if LRows.length >= StudioNumber(FCatalog, 'maximum_tables') then Exit;
          LRows.push(CopyObject(TJSObject(LRows[LRows.length - 1])));
          if LRows.length = 2 then
          begin
            LSource['motion'] := PointsCurve(0);
            TJSArray(TJSArray(TJSObject(LSource['motion'])['points'])[1])[1] := 1;
          end;
          Changed;
          Draw;
        end);
      if LRows.length > 1 then Curve(FBody, LSource, 'motion', 'Wavetable position · first = 0')
      else LSource['motion'] := nil;
    end;
    3, 4:
    begin
      Number(LFields, LSource, 'ratio', 'Modulator frequency ratio', 0.0001, 128);
      if StudioNumber(LSource, 'kind') = 3 then
        Number(LFields, LSource, 'depth', 'FM depth · Hz', 0, 24000)
      else Number(LFields, LSource, 'depth', 'PM depth · radians', 0, 24000);
    end;
  end;
  LFields := Add(FBody, 'div', '', 'range-fields');
  Choice(LFields, LVoice, 'filter_model', 'Layer filter', ['One-pole', 'Biquad'], True);
  Number(LFields, LVoice, 'cutoff_hz', 'Cutoff · Hz (0 = off)', 0, 11999);
  if StudioNumber(LVoice, 'filter_model') = 0 then
    Choice(LFields, LVoice, 'filter_kind', 'Filter shape', ['Low-pass', 'High-pass'])
  else
  begin
    Choice(LFields, LVoice, 'biquad_kind', 'Filter shape',
      ['Low-pass', 'High-pass', 'Band-pass', 'Notch', 'All-pass', 'Peak', 'Low shelf', 'High shelf'], True);
    if StudioNumber(LVoice, 'biquad_kind') < 6 then
      Number(LFields, LVoice, 'q', 'Q / resonance', 0.01, 100);
    if StudioNumber(LVoice, 'biquad_kind') >= 5 then
      Number(LFields, LVoice, 'gain_db', 'Shelf / peak gain · dB', -24, 24);
  end;
end;

procedure TStudioSounds.DrawEnvelope;
var
  LVoice: TJSObject;
  LGate: TJSObject;
  LFields: TJSElement;
begin
  Add(FBody, 'h3', 'Layer ' + IntToStr(FZone + 1) + ' · loudness over a note');
  LVoice := TJSObject(Zone['voice']);
  LGate := TJSObject(Zone['gate']);
  if Boolean(LGate['enabled']) then
  begin
    Add(FBody, 'p', 'This layer uses a custom held/release envelope.', 'hint');
    Curve(FBody, LGate, 'held', 'While the note is held · volume multiplier');
    Number(FBody, LGate, 'release_seconds', 'Release duration · seconds', 0, 30);
    Curve(FBody, LGate, 'release', 'After note-off · volume multiplier');
    Button(FBody, 'Use ADSR instead',
      function(AEvent: TEventListenerEvent): Boolean
      var
        LNew: TJSObject;
      begin
        Result := False;
        LNew := TJSObject.new; LNew['enabled'] := False;
        Zone['gate'] := LNew;
        Changed;
        Draw;
      end);
  end
  else
  begin
    LFields := Add(FBody, 'div', '', 'range-fields');
    Number(LFields, TJSObject(LVoice['envelope']), '0', 'Attack · seconds', 0, 30);
    Number(LFields, TJSObject(LVoice['envelope']), '1', 'Decay · seconds', 0, 30);
    Number(LFields, TJSObject(LVoice['envelope']), '2', 'Sustain · level', 0, 1);
    Number(LFields, TJSObject(LVoice['envelope']), '3', 'Release · seconds', 0, 30);
    Add(FBody, 'p', 'Attack fades in, decay reaches sustain, and release rings after note-off.', 'hint');
    Button(FBody, 'Use a custom envelope',
      function(AEvent: TEventListenerEvent): Boolean
      var
        LNew: TJSObject;
      begin
        Result := False;
        LNew := TJSObject.new;
        LNew['enabled'] := True;
        LNew['held'] := PointsCurve(1);
        LNew['release_seconds'] := 1;
        LNew['release'] := PointsCurve(1);
        TJSArray(TJSArray(TJSObject(LNew['release'])['points'])[1])[1] := 0;
        Zone['gate'] := LNew;
        Changed;
        Draw;
      end);
  end;
end;

procedure TStudioSounds.DrawMotion;
var
  LControls: TJSArray;
  LControl: TJSObject;
  LSelect: TJSElement;
  LOption: TJSElement;
  LCard: TJSElement;
  I: Integer;
begin
  Add(FBody, 'h3', 'Movement within each note');
  Add(FBody, 'p', 'Each curve changes its named target. Times start at note-on; saved musical notes stay the same.', 'hint');
  LControls := TJSArray(Zone['controls']);
  LSelect := Add(Add(FBody, 'label', 'Add movement to'), 'select', '');
  for I := 0 to High(CTargets) do
  begin
    LOption := Add(LSelect, 'option', CTargets[I]);
    LOption.setAttribute('value', IntToStr(I));
  end;
  Button(FBody, 'Add movement',
    function(AEvent: TEventListenerEvent): Boolean
    var
      LTarget: Integer;
      LNew: TJSObject;
      LValue: Double;
      J: Integer;
    begin
      Result := False;
      LTarget := StrToInt(TJSHTMLSelectElement(LSelect).value);
      for J := 0 to LControls.length - 1 do
        if StudioNumber(TJSObject(LControls[J]), 'target') = LTarget then
        begin Notice('This target already has a movement curve.'); Exit end;
      LValue := 0;
      case LTarget of 0: LValue := 440; 2: LValue := 1; 4: LValue := 1000 end;
      LNew := TJSObject.new;
      LNew['target'] := LTarget;
      LNew['curve'] := PointsCurve(LValue);
      LControls.push(LNew);
      Changed;
      Draw;
    end);
  for I := 0 to LControls.length - 1 do
  begin
    LControl := TJSObject(LControls[I]);
    LCard := Add(FBody, 'section', '', 'track');
    Curve(LCard, LControl, 'curve', CTargets[Round(StudioNumber(LControl, 'target'))]);
    RemoveRow(LCard, LControls, I, 0);
  end;
end;

procedure TStudioSounds.DrawEffects;
var
  LMix: TJSObject;
  LPart: TJSObject;
  LRows: TJSArray;
  LSelect: TJSElement;
  LOption: TJSElement;
  LFields: TJSElement;
  LRoot: TJSElement;
  LKind: TCatalogEffect;
  LDefinition: TEffectDefinition;
  LMaximum: Integer;
begin
  LMix := TJSObject(FDesign['mix']);
  Add(FBody, 'h3', CParts[FRole] + ' · mix & effects');
  if (FRole >= 3) and (FRole < 6) then
    Add(FBody, 'p', 'Synthesized ' + LowerCase(CParts[FRole]) + '. Shape this part with its own rack.', 'hint');
  LMaximum := 31;
  if FRole < 6 then
  begin
    LPart := TJSObject(TJSArray(LMix['parts'])[FRole]);
    LFields := Add(FBody, 'div', '', 'range-fields');
    Number(LFields, LPart, 'gain', 'Part gain', 0, 1);
    Number(LFields, LPart, 'pan', 'Stereo balance · −1 left / 1 right', -1, 1);
    Check(FBody, LPart, 'bypass', 'Bypass this part’s effect stack');
    LRows := TJSArray(LPart['effects']);
  end
  else LRows := TJSArray(LMix['master']);
  Check(FBody, LMix, 'bypass', 'Bypass all effect stacks · dry comparison');
  Number(FBody, LMix, 'tail_seconds', 'Effect tail · seconds for the whole mix', 0, 30);
  Add(FBody, 'p', 'Dry keeps your instruments, gain/pan and output protection. Longer note releases are retained automatically.', 'hint');
  LSelect := Add(Add(FBody, 'label', 'Add an effect'), 'select', '');
  for LKind := Low(TCatalogEffect) to High(TCatalogEffect) do
  begin
    LDefinition := EffectDefinition(LKind);
    LOption := Add(LSelect, 'option', LDefinition.Caption);
    LOption.setAttribute('value', LDefinition.Key);
  end;
  Button(FBody, 'Add effect',
    function(AEvent: TEventListenerEvent): Boolean
    begin
      Result := False;
      try FRack.AddEffect(TJSHTMLSelectElement(LSelect).value)
      except on E: Exception do Notice(E.Message) end;
    end);
  LRoot := Add(FBody, 'div', '', 'sound-rack');
  FRack := TStudioEffectRackControls.Create(LRoot, @Changed, LMaximum);
  FRack.Restore(LRows);
end;

end.
