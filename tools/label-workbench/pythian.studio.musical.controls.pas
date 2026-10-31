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

unit pythian.studio.musical.controls;

{$mode delphi}
{$H+}

interface

uses JS, Web, SysUtils;

type
  { Big Boss: form presentation only. Reuses the primary control/affect mappings;
    owns no audio device, inference, transport or job lifecycle. }
  TStudioMusicalControls = class
  private
    FSettings, FControlStatus: TJSElement;
    FPanels: array[0..2] of TJSElement;
    FTabs: array[0..2] of TJSElement;
    function Add(AParent: TJSElement; const ATag, AText: String): TJSElement;
    function Input(AParent: TJSElement; const AId, ALabel, AValue: String;
      AMinimum, AMaximum: Integer): TJSElement;
    function Number(const AId: String; AMinimum, AMaximum: Integer): Integer;
    function Affect(AEvent: TJSMouseEvent): Boolean;
    function TabClick(AEvent: TJSMouseEvent): Boolean;
    function TabKey(AEvent: TJSKeyboardEvent): Boolean;
    function PartChanged(AEvent: TEventListenerEvent): Boolean;
    procedure SelectTab(const AIndex: Integer);
  public
    constructor Create(AParent: TJSElement);
    function ReadConfig: TJSObject;
    procedure RestoreConfig(AConfig: TJSObject);
    function ReadDraft: TJSObject;
    procedure RestoreDraft(ADraft: TJSObject);
    procedure SetEnabled(const AEnabled: Boolean);
    property Root: TJSElement read FSettings;
  end;

implementation

uses pythian.studio.sources, pythian.studio.requests, pythian.music.controls;

const
  CNames: array[0..5] of String = ('Bass', 'Harmony', 'Lead', 'Kick', 'Snare', 'Hat');
function TStudioMusicalControls.Add(AParent: TJSElement; const ATag, AText: String): TJSElement;
begin
  Result := document.createElement(ATag); Result.textContent := AText;
  AParent.appendChild(Result);
end;

function TStudioMusicalControls.Input(AParent: TJSElement;
  const AId, ALabel, AValue: String; AMinimum, AMaximum: Integer): TJSElement;
var LLabel: TJSElement;
begin
  LLabel := Add(AParent, 'label', ALabel);
  Result := Add(LLabel, 'input', '');
  Result.id := AId; Result.setAttribute('type', 'number');
  Result.setAttribute('data-label', ALabel);
  Result.setAttribute('min', IntToStr(AMinimum)); Result.setAttribute('max', IntToStr(AMaximum));
  Result.setAttribute('step', '1'); Result.setAttribute('value', AValue);
  Result.setAttribute('inputmode', 'numeric');
end;


constructor TStudioMusicalControls.Create(AParent: TJSElement);
const
  CTabs: array[0..2] of String = ('Music', 'Parts', 'Feel');
  CShapes: array[0..3] of String = ('saw', 'triangle', 'square', 'sine');
  CSoundNames: array[0..3] of String = ('Bright · saw', 'Soft · triangle', 'Hollow · square', 'Smooth · sine');
  CKeys: array[0..11] of String = ('C', 'C♯', 'D', 'E♭', 'E', 'F', 'F♯', 'G', 'A♭', 'A', 'B♭', 'B');
var
  LNav, LRow, LSelect, LOption, LPart, LButton: TJSElement;
  I, J: Integer;
begin
  inherited Create;
  FSettings := Add(AParent, 'div', '');
  FSettings.id := 'lab-controls';
  LNav := Add(FSettings, 'div', '');
  LNav.className := 'lab-tabs';
  LNav.setAttribute('role', 'tablist');
  LNav.setAttribute('aria-label', 'Experiment controls');
  for I := 0 to 2 do
  begin
    FTabs[I] := Add(LNav, 'button', CTabs[I]);
    FTabs[I].id := 'lab-tab-' + IntToStr(I);
    FTabs[I].setAttribute('type', 'button');
    FTabs[I].setAttribute('role', 'tab');
    FTabs[I].setAttribute('data-panel', IntToStr(I));
    FTabs[I].setAttribute('aria-controls', 'lab-panel-' + IntToStr(I));
    FTabs[I].addEventListener('click', @TabClick);
    FTabs[I].addEventListener('keydown', @TabKey);
  end;
  for I := 0 to 2 do
  begin
    FPanels[I] := Add(FSettings, 'section', '');
    FPanels[I].id := 'lab-panel-' + IntToStr(I);
    FPanels[I].setAttribute('role', 'tabpanel');
    FPanels[I].setAttribute('aria-labelledby', FTabs[I].id);
  end;
  LRow := Add(FPanels[0], 'div', ''); LRow.className := 'lab-grid';
  Input(LRow, 'instrumental-tempo', 'Tempo · BPM', '120', 40, 240);
  Input(LRow, 'instrumental-bars', 'Length · bars', '4', 1, 32);
  LSelect := Add(Add(LRow, 'label', 'Key root'), 'select', '');
  LSelect.id := 'instrumental-tonic';
  for I := 0 to 11 do
    Add(LSelect, 'option', CKeys[I]).setAttribute('value', IntToStr(I));
  LSelect := Add(Add(LRow, 'label', 'Scale'), 'select', '');
  LSelect.id := 'instrumental-mode';
  Add(LSelect, 'option', 'Major').setAttribute('value', 'major');
  Add(LSelect, 'option', 'Natural minor').setAttribute('value', 'natural_minor');
  Add(FPanels[0], 'p', 'Four beats per bar. Up to 32 bars here; the main Generate step supports long tracks learned from recordings.').className := 'hint';
  Add(FPanels[0], 'p', 'Authored starter · WFC chooses musical events, then Pythian synthesizes all six parts. No recordings are learned in this experiment.').className := 'hint';
  LSelect := Add(Add(FPanels[1], 'label', 'Part to adjust'), 'select', '');
  LSelect.id := 'lab-part';
  for I := 0 to 5 do
    Add(LSelect, 'option', CNames[I]).setAttribute('value', IntToStr(I));
  LSelect.addEventListener('change', @PartChanged);
  for I := 0 to 5 do
  begin
    LPart := Add(FPanels[1], 'div', '');
    LPart.id := 'lab-role-' + IntToStr(I);
    LPart.className := 'lab-grid';
    if I < 3 then
    begin
      LSelect := Add(Add(LPart, 'label', 'Sound'), 'select', '');
      LSelect.id := 'instrumental-sound-' + IntToStr(I);
      for J := 0 to 3 do
        Add(LSelect, 'option', CSoundNames[J]).setAttribute('value', CShapes[J]);
      TJSHTMLSelectElement(LSelect).value := CShapes[I];
      Input(LPart, 'instrumental-minimum-' + IntToStr(I), 'Lowest note · MIDI', '0', 0, 127);
      Input(LPart, 'instrumental-maximum-' + IntToStr(I), 'Highest note · MIDI', '127', 0, 127);
      Input(LPart, 'instrumental-activity-' + IntToStr(I), 'Note activity · −100 to 100', '0', -100, 100);
      Input(LPart, 'instrumental-velocity-' + IntToStr(I), 'Note strength · %', '100', 1, 200);
      Input(LPart, 'instrumental-gate-' + IntToStr(I), 'Note length · %', '100', 1, 100);
    end
    else Add(LPart, 'p', 'Synthesized ' + CNames[I] + '. The starter provides its rhythm and sound recipe.').className := 'hint';
    Input(LPart, 'instrumental-level-' + IntToStr(I), 'Mix level · %', '100', 0, 100);
    if I <> 0 then LPart.setAttribute('hidden', '');
  end;
  Add(FPanels[1], 'p', 'MIDI 60 is middle C. Pitch bounds select existing notes; they do not transpose. Impossible choices fail visibly.').className := 'hint';
  LSelect := Add(Add(FPanels[2], 'label', 'Rhythm and chords'), 'select', '');
  LSelect.id := 'instrumental-guide';
  Add(LSelect, 'option', 'Follow the starter').setAttribute('value', 'guide');
  Add(LSelect, 'option', 'Let WFC vary').setAttribute('value', 'free');
  LRow := Add(FPanels[2], 'div', ''); LRow.className := 'lab-grid';
  Input(LRow, 'instrumental-energy', 'Energy · 0–100', '50', 0, 100);
  Input(LRow, 'instrumental-density', 'Density · 0–100', '50', 0, 100);
  Input(LRow, 'instrumental-tension', 'Tension · 0–100', '50', 0, 100);
  LButton := Add(FPanels[2], 'button', 'Apply feel to parts');
  LButton.setAttribute('type', 'button'); LButton.id := 'instrumental-apply-affect';
  LButton.addEventListener('click', @Affect);
  Add(FPanels[2], 'p', 'Experimental mapping: energy → note strength, density → activity, tension → chord-root preference. Choose Let WFC vary to hear rhythm/chord preferences. Apply changes settings only.').className := 'hint';
  Input(FPanels[2], 'instrumental-tonic-bias', 'Chord-root preference · −100 to 100', '0', -100, 100);
  FControlStatus := Add(FPanels[2], 'p', ''); FControlStatus.setAttribute('role', 'status');
  SelectTab(0);
end;
function TStudioMusicalControls.Number(const AId: String; AMinimum, AMaximum: Integer): Integer;
var LText, LLabel: String;
begin
  LText := TJSHTMLInputElement(document.getElementById(AId)).value;
  if not TryStrToInt(LText, Result) or (Result < AMinimum) or (Result > AMaximum) then
  begin
    LLabel := document.getElementById(AId).getAttribute('data-label');
    if LLabel = '' then LLabel := 'this choice';
    raise Exception.Create('Use ' + IntToStr(AMinimum) + ' to ' + IntToStr(AMaximum) + ' for ' + LLabel + '.');
  end;
end;

function TStudioMusicalControls.ReadConfig: TJSObject;
var LShapes, LLevels, LParts: TJSArray; LControls, LPart: TJSObject; I: Integer;
  LNativeControl: TMusicalPartControl;
begin
  Result := TJSObject.new;
  Result['tempo_bpm'] := Number('instrumental-tempo', 40, 240);
  Result['tonic'] := Number('instrumental-tonic', 0, 11);
  Result['mode'] := TJSHTMLSelectElement(document.getElementById('instrumental-mode')).value;
  Result['cells'] := Number('instrumental-bars', 1, 32) * 8;
  LShapes := TJSArray.new; LLevels := TJSArray.new;
  for I := 0 to 5 do
  begin
    if I < 3 then LShapes.push(TJSHTMLSelectElement(document.getElementById(
      'instrumental-sound-' + IntToStr(I))).value);
    LLevels.push(Number('instrumental-level-' + IntToStr(I), 0, 100));
  end;
  Result['instruments'] := LShapes; Result['levels'] := LLevels;
  LControls := TJSObject.new;
  LControls['guide'] := TJSHTMLSelectElement(document.getElementById('instrumental-guide')).value = 'guide';
  LControls['tonic_bias'] := Number('instrumental-tonic-bias', -100, 100);
  LParts := TJSArray.new;
  LControls['parts'] := LParts;
  for I := 0 to 2 do
  begin
    LNativeControl := DefaultMusicalPartControl;
    LNativeControl.MinimumPitch := Number('instrumental-minimum-' + IntToStr(I), 0, 127);
    LNativeControl.MaximumPitch := Number('instrumental-maximum-' + IntToStr(I), 0, 127);
    LNativeControl.ActivityBias := Number('instrumental-activity-' + IntToStr(I), -100, 100);
    LNativeControl.Expression.VelocityPercent := Number('instrumental-velocity-' + IntToStr(I), 1, 200);
    LNativeControl.Expression.GatePercent := Number('instrumental-gate-' + IntToStr(I), 1, 100);
    try
      ValidateMusicalPartControl(LNativeControl);
    except
      on E: Exception do raise Exception.Create(CNames[I] + ': ' + E.Message);
    end;
    LPart := TJSObject.new;
    LPart['minimum_pitch'] := LNativeControl.MinimumPitch;
    LPart['maximum_pitch'] := LNativeControl.MaximumPitch;
    LPart['activity_bias'] := LNativeControl.ActivityBias;
    LPart['velocity_percent'] := LNativeControl.Expression.VelocityPercent;
    LPart['gate_percent'] := LNativeControl.Expression.GatePercent;
    LParts.push(LPart);
  end;
  Result['controls'] := LControls;
end;

procedure TStudioMusicalControls.RestoreConfig(AConfig: TJSObject);
var I: Integer; LControls, LPart: TJSObject;
begin
  if (AConfig = nil) or not isArray(AConfig['instruments']) or
    not isArray(AConfig['levels']) or (TJSArray(AConfig['instruments']).length <> 3) or
    (TJSArray(AConfig['levels']).length <> 6) then
    raise Exception.Create('The saved instrumental settings are incomplete.');
  TJSHTMLInputElement(document.getElementById('instrumental-tempo')).value :=
    FloatToStr(StudioNumber(AConfig, 'tempo_bpm'));
  TJSHTMLInputElement(document.getElementById('instrumental-bars')).value :=
    FloatToStr(StudioNumber(AConfig, 'cells') / 8);
  TJSHTMLSelectElement(document.getElementById('instrumental-tonic')).value :=
    FloatToStr(StudioNumber(AConfig, 'tonic'));
  TJSHTMLSelectElement(document.getElementById('instrumental-mode')).value := 'major';
  if StudioText(AConfig, 'mode') <> '' then
    TJSHTMLSelectElement(document.getElementById('instrumental-mode')).value := StudioText(AConfig, 'mode');
  for I := 0 to 5 do
  begin
    if I < 3 then TJSHTMLSelectElement(document.getElementById('instrumental-sound-' +
      IntToStr(I))).value := String(TJSArray(AConfig['instruments'])[I]);
    TJSHTMLInputElement(document.getElementById('instrumental-level-' + IntToStr(I))).value :=
      String(TJSArray(AConfig['levels'])[I]);
  end;
  TJSHTMLSelectElement(document.getElementById('instrumental-guide')).value := 'guide';
  TJSHTMLInputElement(document.getElementById('instrumental-tonic-bias')).value := '0';
  LControls := nil;
  if isObject(AConfig['controls']) then LControls := TJSObject(AConfig['controls']);
  if LControls <> nil then
  begin
    if not Boolean(LControls['guide']) then
      TJSHTMLSelectElement(document.getElementById('instrumental-guide')).value := 'free';
    TJSHTMLInputElement(document.getElementById('instrumental-tonic-bias')).value :=
      FloatToStr(StudioNumber(LControls, 'tonic_bias'));
  end;
  for I := 0 to 2 do
  begin
    TJSHTMLInputElement(document.getElementById('instrumental-minimum-' + IntToStr(I))).value := '0';
    TJSHTMLInputElement(document.getElementById('instrumental-maximum-' + IntToStr(I))).value := '127';
    TJSHTMLInputElement(document.getElementById('instrumental-activity-' + IntToStr(I))).value := '0';
    TJSHTMLInputElement(document.getElementById('instrumental-velocity-' + IntToStr(I))).value := '100';
    TJSHTMLInputElement(document.getElementById('instrumental-gate-' + IntToStr(I))).value := '100';
    if (LControls <> nil) and isArray(LControls['parts']) and
      (TJSArray(LControls['parts']).length = 3) then
    begin
      LPart := TJSObject(TJSArray(LControls['parts'])[I]);
      TJSHTMLInputElement(document.getElementById('instrumental-minimum-' + IntToStr(I))).value := FloatToStr(StudioNumber(LPart, 'minimum_pitch'));
      TJSHTMLInputElement(document.getElementById('instrumental-maximum-' + IntToStr(I))).value := FloatToStr(StudioNumber(LPart, 'maximum_pitch'));
      TJSHTMLInputElement(document.getElementById('instrumental-activity-' + IntToStr(I))).value := FloatToStr(StudioNumber(LPart, 'activity_bias'));
      TJSHTMLInputElement(document.getElementById('instrumental-velocity-' + IntToStr(I))).value := FloatToStr(StudioNumber(LPart, 'velocity_percent'));
      TJSHTMLInputElement(document.getElementById('instrumental-gate-' + IntToStr(I))).value := FloatToStr(StudioNumber(LPart, 'gate_percent'));
    end;
  end;
  FControlStatus.textContent := '';
  ReadConfig;
end;

function TStudioMusicalControls.Affect(AEvent: TJSMouseEvent): Boolean;
var
  LMapping: TMusicalAffectMapping;
  LPart: Integer;
begin
  Result := False;
  try
    LMapping := MapMusicalAffect(Number('instrumental-energy', 0, 100),
      Number('instrumental-density', 0, 100), Number('instrumental-tension', 0, 100));
    for LPart := 0 to 2 do
    begin
      TJSHTMLInputElement(document.getElementById('instrumental-velocity-' + IntToStr(LPart))).value :=
        IntToStr(LMapping.VelocityPercent);
      TJSHTMLInputElement(document.getElementById('instrumental-activity-' + IntToStr(LPart))).value :=
        IntToStr(LMapping.ActivityBias);
    end;
    TJSHTMLInputElement(document.getElementById('instrumental-tonic-bias')).value := IntToStr(LMapping.TonicBias);
    FSettings.dispatchEvent(TJSEvent.new('change'));
    FControlStatus.textContent := 'Applied: note strength ' + IntToStr(LMapping.VelocityPercent) +
      '%, activity ' + IntToStr(LMapping.ActivityBias) +
      ', chord-root preference ' + IntToStr(LMapping.TonicBias) + '. Edit in Parts or Feel before generating.';
  except
    on E: Exception do FControlStatus.textContent := E.Message;
  end;
end;

procedure TStudioMusicalControls.SetEnabled(const AEnabled: Boolean);
var LControls: TJSNodeList; I: Integer;
begin
  LControls := FSettings.querySelectorAll('input,select');
  for I := 0 to LControls.length - 1 do
    TJSHTMLInputElement(LControls[I]).disabled := not AEnabled;
  TJSHTMLButtonElement(document.getElementById('instrumental-apply-affect')).disabled := not AEnabled;
end;


procedure TStudioMusicalControls.SelectTab(const AIndex: Integer);
var I: Integer;
begin
  for I := 0 to 2 do
  begin
    FTabs[I].setAttribute('aria-selected', BoolToStr(I = AIndex, 'true', 'false'));
    FTabs[I].setAttribute('tabindex', IntToStr(-Ord(I <> AIndex)));
    if I = AIndex then FPanels[I].removeAttribute('hidden')
    else FPanels[I].setAttribute('hidden', '');
  end;
end;

function TStudioMusicalControls.TabClick(AEvent: TJSMouseEvent): Boolean;
begin
  Result := False;
  SelectTab(StrToInt(TJSElement(AEvent.currentTarget).getAttribute('data-panel')));
end;

function TStudioMusicalControls.TabKey(AEvent: TJSKeyboardEvent): Boolean;
var I: Integer;
begin
  Result := False;
  I := StrToInt(TJSElement(AEvent.currentTarget).getAttribute('data-panel'));
  if AEvent.key = 'ArrowRight' then I := (I + 1) mod 3
  else if AEvent.key = 'ArrowLeft' then I := (I + 2) mod 3
  else if AEvent.key = 'Home' then I := 0
  else if AEvent.key = 'End' then I := 2 else Exit;
  AEvent.preventDefault;
  SelectTab(I);
  TJSHTMLElement(FTabs[I]).focus;
end;

function TStudioMusicalControls.PartChanged(AEvent: TEventListenerEvent): Boolean;
var I, LPart: Integer;
begin
  Result := False;
  LPart := StrToInt(TJSHTMLSelectElement(document.getElementById('lab-part')).value);
  for I := 0 to 5 do
    if I = LPart then document.getElementById('lab-role-' + IntToStr(I)).removeAttribute('hidden')
    else document.getElementById('lab-role-' + IntToStr(I)).setAttribute('hidden', '');
end;

function TStudioMusicalControls.ReadDraft: TJSObject;
var LNodes: TJSNodeList; I: Integer; LInput: TJSHTMLInputElement;
begin
  Result := TJSObject.new;
  LNodes := FSettings.querySelectorAll('input,select');
  for I := 0 to LNodes.length - 1 do
  begin
    LInput := TJSHTMLInputElement(LNodes[I]);
    Result[LInput.id] := LInput.value;
  end;
end;

procedure TStudioMusicalControls.RestoreDraft(ADraft: TJSObject);
var LNodes: TJSNodeList; I: Integer; LInput: TJSHTMLInputElement;
begin
  if ADraft = nil then Exit;
  LNodes := FSettings.querySelectorAll('input,select');
  for I := 0 to LNodes.length - 1 do
  begin
    LInput := TJSHTMLInputElement(LNodes[I]);
    if isString(ADraft[LInput.id]) then LInput.value := String(ADraft[LInput.id]);
  end;
  PartChanged(nil);
end;
end.
