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
unit pythian.studio.blend;

{$mode delphi}{$H+}{$modeswitch externalclass}

interface

uses JS, Web, SysUtils, pythian.music.blend, pythian.studio.sources;

type
  TStudioChooseBlend = procedure(const AStyle: TJSObject) of object;
  TStudioBlendChoices = class
  private
    FChoose: TStudioChooseBlend;
    FRows: TJSArray;
    FPlan: TMusicBlendPlan;
    FProvider: Integer;
    FPart: Integer;
    FAvailable: Boolean;
    function El(const AId: String): TJSElement;
    function Add(const AParent: TJSElement; const ATag, AText: String): TJSElement;
    function Select(const AParent: TJSElement; const AId, ACaption: String;
      const AChoices: array of String): TJSElement;
    function Number(const AId: String; const AMaximum: Integer): Integer;
    procedure StoreProvider;
    procedure DrawProvider;
    procedure StorePart;
    procedure DrawPart;
    procedure UpdateParentAudio;
    procedure ShowTab(const AIndex: Integer);
    procedure RestorePlan(const AValue: TJSObject);
    procedure Apply;
    function Click(AEvent: TJSMouseEvent): Boolean;
    function Changed(AEvent: TEventListenerEvent): Boolean;
    function TabKey(AEvent: TJSKeyboardEvent): Boolean;
    function PreviewToggled(AEvent: TEventListenerEvent): Boolean;
  public
    constructor Create(const AChoose: TStudioChooseBlend);
    procedure SetAvailable(const AAvailable: Boolean);
    procedure Open(const ARows: TJSArray; const ASelection: TJSObject = nil);
  end;

implementation

const
  CProviders: array[0..8] of String = ('Chord progression', 'Groove', 'Bass notes',
    'Chord notes', 'Lead notes', 'Shared musical context', 'Kick pattern', 'Snare pattern', 'Hat pattern');
  CParts: array[0..5] of String = ('Bass', 'Chords', 'Lead', 'Kick', 'Snare', 'Hat');

function TStudioBlendChoices.El(const AId: String): TJSElement;
begin
  Result := document.getElementById(AId);
end;

function TStudioBlendChoices.Add(const AParent: TJSElement; const ATag, AText: String): TJSElement;
begin
  Result := document.createElement(ATag);
  Result.textContent := AText;
  AParent.appendChild(Result);
end;

function TStudioBlendChoices.Select(const AParent: TJSElement; const AId, ACaption: String;
  const AChoices: array of String): TJSElement;
var
  LLabel: TJSElement;
  I: Integer;
begin
  LLabel := Add(AParent, 'label', ACaption);
  LLabel.setAttribute('for', AId);
  Result := Add(LLabel, 'select', '');
  Result.id := AId;
  for I := 0 to High(AChoices) do
  begin
    Add(Result, 'option', AChoices[I]).setAttribute('value', IntToStr(I));
  end;
end;

constructor TStudioBlendChoices.Create(const AChoose: TStudioChooseBlend);
var
  LPanel: TJSElement;
  LRow: TJSElement;
  LInput: TJSElement;
  LLabel: TJSElement;
  LButton: TJSElement;
  I: Integer;
begin
  inherited Create;
  FChoose := AChoose;
  FRows := TJSArray.new;
  FPlan := DefaultMusicBlendPlan(Length(CProviders), Length(CParts));
  LPanel := El('blend-panel-0');
  LInput := Select(LPanel, 'blend-provider', 'Musical idea to adjust', CProviders);
  LInput.addEventListener('change', @Changed);
  LRow := Add(LPanel, 'div', '');
  LRow.className := 'blend-weights';
  for I := 0 to 1 do
  begin
    if I = 0 then LLabel := Add(LRow, 'label', 'A weight')
    else LLabel := Add(LRow, 'label', 'B weight');
    LInput := Add(LLabel, 'input', '');
    LInput.id := 'blend-weight-' + IntToStr(I);
    LLabel.setAttribute('for', LInput.id);
    LInput.setAttribute('type', 'number');
    LInput.setAttribute('min', '0');
    LInput.setAttribute('max', IntToStr(MaximumMusicBlendWeight));
    LInput.setAttribute('step', '1');
    LInput.setAttribute('inputmode', 'numeric');
    LInput.addEventListener('input', @Changed);
  end;
  Select(LPanel, 'blend-rule-parent', 'Keep note limits and preferences from', ['A', 'B']);
  Add(LPanel, 'p', '1 + 1 mixes both equally. 0 leaves that style’s examples out. Rules stay separate from weights.').className := 'hint';
  LPanel := El('blend-panel-1');
  LInput := Select(LPanel, 'blend-part', 'Part to adjust', CParts);
  LInput.addEventListener('change', @Changed);
  LRow := Add(LPanel, 'div', '');
  LRow.className := 'blend-part-choices';
  Select(LRow, 'blend-instrument-parent', 'Instrument from', ['A', 'B']);
  Select(LRow, 'blend-effects-parent', 'Effects from', ['A', 'B']);
  Select(LRow, 'blend-expression-parent', 'Expression from', ['A', 'B']);
  Add(LPanel, 'p', 'Pythian plays every part. Effects include mix level; expression is note strength and length.').className := 'hint';
  LPanel := El('blend-panel-2');
  Select(LPanel, 'blend-base-parent', 'Tempo and timing from', ['A', 'B']);
  Select(LPanel, 'blend-master-parent', 'Master effects from', ['A', 'B']);
  Select(LPanel, 'blend-form-parent', 'Song sections from', ['A', 'B']);
  Select(LPanel, 'blend-context', 'Connect bass, chords and lead',
    ['Keep timing style’s connection', 'Keep the shared lead connection', 'All follow the shared context']);
  LLabel := Add(LPanel, 'label', '');
  LLabel.className := 'blend-check';
  LInput := Add(LLabel, 'input', '');
  LInput.id := 'blend-pitch-ranges';
  LInput.setAttribute('type', 'checkbox');
  Add(LLabel, 'span', 'Combine pitch ranges from both musical parents');
  Add(LPanel, 'p', 'Sections must fit the chosen timing. Keep both from the same style if they conflict. Note limits remain active.').className := 'hint';
  for I := 0 to 2 do
  begin
    LButton := El('blend-tab-' + IntToStr(I));
    LButton.addEventListener('click', @Click);
    LButton.addEventListener('keydown', @TabKey);
  end;
  El('confirm-blend-style').addEventListener('click', @Click);
  El('blend-style-0').addEventListener('change', @Changed);
  El('blend-style-1').addEventListener('change', @Changed);
  El('blend-previews').addEventListener('toggle', @PreviewToggled);
end;

procedure TStudioBlendChoices.SetAvailable(const AAvailable: Boolean);
begin
  FAvailable := AAvailable;
  TJSHTMLButtonElement(El('confirm-blend-style')).disabled := not FAvailable;
end;

function TStudioBlendChoices.Number(const AId: String; const AMaximum: Integer): Integer;
var
  LText: String;
begin
  if El(AId).tagName = 'SELECT' then LText := TJSHTMLSelectElement(El(AId)).value
  else LText := TJSHTMLInputElement(El(AId)).value;
  if not TryStrToInt(LText, Result) or (Result < 0) or (Result > AMaximum) then
  begin
    raise Exception.Create('Choose a whole number from 0 to ' + IntToStr(AMaximum) + '.');
  end;
end;

procedure TStudioBlendChoices.StoreProvider;
var
  LPlan: TMusicBlendPlan;
begin
  LPlan := CopyMusicBlendPlan(FPlan);
  LPlan.Providers[FProvider].LeftWeight := Number('blend-weight-0', MaximumMusicBlendWeight);
  LPlan.Providers[FProvider].RightWeight := Number('blend-weight-1', MaximumMusicBlendWeight);
  LPlan.Providers[FProvider].ControlParent := Number('blend-rule-parent', 1);
  try
    ValidateMusicBlendPlan(LPlan, Length(CProviders), Length(CParts));
  except
    on E: Exception do
    begin
      if (LPlan.Providers[FProvider].LeftWeight = 0) and
        (LPlan.Providers[FProvider].RightWeight = 0) then
        raise Exception.Create('Give A or B a weight above 0 for ' + CProviders[FProvider] + '.');
      raise;
    end;
  end;
  FPlan := LPlan;
end;

procedure TStudioBlendChoices.DrawProvider;
begin
  TJSHTMLSelectElement(El('blend-provider')).value := IntToStr(FProvider);
  TJSHTMLInputElement(El('blend-weight-0')).value := IntToStr(FPlan.Providers[FProvider].LeftWeight);
  TJSHTMLInputElement(El('blend-weight-1')).value := IntToStr(FPlan.Providers[FProvider].RightWeight);
  TJSHTMLSelectElement(El('blend-rule-parent')).value := IntToStr(FPlan.Providers[FProvider].ControlParent);
end;

procedure TStudioBlendChoices.StorePart;
begin
  FPlan.Parts[FPart].InstrumentParent := Number('blend-instrument-parent', 1);
  FPlan.Parts[FPart].EffectsParent := Number('blend-effects-parent', 1);
  FPlan.Parts[FPart].ExpressionParent := Number('blend-expression-parent', 1);
end;

procedure TStudioBlendChoices.DrawPart;
begin
  TJSHTMLSelectElement(El('blend-part')).value := IntToStr(FPart);
  TJSHTMLSelectElement(El('blend-instrument-parent')).value := IntToStr(FPlan.Parts[FPart].InstrumentParent);
  TJSHTMLSelectElement(El('blend-effects-parent')).value := IntToStr(FPlan.Parts[FPart].EffectsParent);
  TJSHTMLSelectElement(El('blend-expression-parent')).value := IntToStr(FPlan.Parts[FPart].ExpressionParent);
end;

procedure TStudioBlendChoices.UpdateParentAudio;
var
  I: Integer;
  LRow: TJSObject;
  LAudio: TJSHTMLAudioElement;
  LJob: String;
begin
  for I := 0 to 1 do
  begin
    LRow := TJSObject(FRows[Number('blend-style-' + IntToStr(I), FRows.length - 1)]);
    LJob := StudioText(LRow, 'source_job_id');
    LAudio := TJSHTMLAudioElement(El('blend-parent-audio-' + IntToStr(I)));
    if LAudio.getAttribute('data-job') <> LJob then
    begin
      LAudio.pause;
      LAudio.setAttribute('data-job', LJob);
      if LJob = '' then LAudio.removeAttribute('src')
      else LAudio.src := '/api/studio/instrumental-audio?job=' + encodeURIComponent(LJob) + '&part=6';
    end;
  end;
end;

procedure TStudioBlendChoices.ShowTab(const AIndex: Integer);
var
  I: Integer;
  LActive: Boolean;
begin
  for I := 0 to 2 do
  begin
    LActive := I = AIndex;
    if LActive then
    begin
      El('blend-tab-' + IntToStr(I)).setAttribute('aria-selected', 'true');
      El('blend-tab-' + IntToStr(I)).setAttribute('tabindex', '0');
      El('blend-panel-' + IntToStr(I)).removeAttribute('hidden');
    end
    else
    begin
      El('blend-tab-' + IntToStr(I)).setAttribute('aria-selected', 'false');
      El('blend-tab-' + IntToStr(I)).setAttribute('tabindex', '-1');
      El('blend-panel-' + IntToStr(I)).setAttribute('hidden', '');
    end;
  end;
end;

procedure TStudioBlendChoices.RestorePlan(const AValue: TJSObject);
var
  LRows: TJSArray;
  LRow: TJSObject;
  I: Integer;
  function Value(const AObject: TJSObject; const AKey: String; const AMaximum: Integer): Integer;
  var
    LNumber: Double;
  begin
    if (AObject = nil) or not isNumber(AObject[AKey]) then
      raise Exception.Create('This blend choice is unavailable. Choose the styles again.');
    LNumber := Double(AObject[AKey]);
    if (LNumber < 0) or (LNumber > AMaximum) or (LNumber <> Trunc(LNumber)) then
      raise Exception.Create('This blend choice is out of range. Choose the styles again.');
    Result := Trunc(LNumber);
  end;
begin
  if (AValue = nil) or not isArray(AValue['providers']) or not isArray(AValue['parts']) then
    raise Exception.Create('This blend is incomplete. Choose the styles again.');
  LRows := TJSArray(AValue['providers']);
  if LRows.length <> Length(CProviders) then raise Exception.Create('This blend has a different musical layout.');
  for I := 0 to High(FPlan.Providers) do
  begin
    LRow := TJSObject(LRows[I]);
    FPlan.Providers[I].LeftWeight := Value(LRow, 'left_weight', MaximumMusicBlendWeight);
    FPlan.Providers[I].RightWeight := Value(LRow, 'right_weight', MaximumMusicBlendWeight);
    FPlan.Providers[I].ControlParent := Value(LRow, 'control_parent', 1);
  end;
  LRows := TJSArray(AValue['parts']);
  if LRows.length <> Length(CParts) then raise Exception.Create('This blend has different instrument parts.');
  for I := 0 to High(FPlan.Parts) do
  begin
    LRow := TJSObject(LRows[I]);
    FPlan.Parts[I].InstrumentParent := Value(LRow, 'instrument_parent', 1);
    FPlan.Parts[I].EffectsParent := Value(LRow, 'effects_parent', 1);
    FPlan.Parts[I].ExpressionParent := Value(LRow, 'expression_parent', 1);
  end;
  FPlan.BaseParent := Value(AValue, 'base_parent', 1);
  FPlan.MasterParent := Value(AValue, 'master_parent', 1);
  FPlan.FormParent := Value(AValue, 'form_parent', 1);
  FPlan.Context := TMusicBlendContext(Value(AValue, 'context', 2));
  if not isBoolean(AValue['union_pitch_ranges']) then
    raise Exception.Create('Choose whether to combine pitch ranges.');
  FPlan.UnionPitchRanges := Boolean(AValue['union_pitch_ranges']);
  ValidateMusicBlendPlan(FPlan, Length(CProviders), Length(CParts));
end;

procedure TStudioBlendChoices.Open(const ARows: TJSArray; const ASelection: TJSObject);
var
  I: Integer;
  LSide: Integer;
  LSelect: TJSElement;
  LSelected: array[0..1] of Integer;
  LIds: array[0..1] of String;
begin
  if not FAvailable or (ARows = nil) or (ARows.length < 2) then Exit;
  FRows := ARows;
  FPlan := DefaultMusicBlendPlan(Length(CProviders), Length(CParts));
  LSelected[0] := 0;
  LSelected[1] := 1;
  if ASelection <> nil then
  begin
    RestorePlan(TJSObject(ASelection['blend']));
    LIds[0] := StudioText(ASelection, 'left_style_id');
    LIds[1] := StudioText(TJSObject(ASelection['blend']), 'right_style_id');
    for LSide := 0 to 1 do
    begin
      LSelected[LSide] := -1;
      for I := 0 to FRows.length - 1 do
        if StudioText(TJSObject(FRows[I]), 'id') = LIds[LSide] then LSelected[LSide] := I;
      if LSelected[LSide] < 0 then raise Exception.Create('A parent style is unavailable. Choose another style.');
    end;
  end;
  FProvider := 0;
  FPart := 0;
  for LSide := 0 to 1 do
  begin
    LSelect := El('blend-style-' + IntToStr(LSide));
    LSelect.innerHTML := '';
    for I := 0 to FRows.length - 1 do
    begin
      Add(LSelect, 'option', StudioText(TJSObject(FRows[I]), 'name')).setAttribute('value', IntToStr(I));
    end;
    TJSHTMLSelectElement(LSelect).value := IntToStr(LSelected[LSide]);
  end;
  TJSHTMLSelectElement(El('blend-base-parent')).value := IntToStr(FPlan.BaseParent);
  TJSHTMLSelectElement(El('blend-master-parent')).value := IntToStr(FPlan.MasterParent);
  TJSHTMLSelectElement(El('blend-form-parent')).value := IntToStr(FPlan.FormParent);
  TJSHTMLSelectElement(El('blend-context')).value := IntToStr(Ord(FPlan.Context));
  TJSHTMLInputElement(El('blend-pitch-ranges')).checked := FPlan.UnionPitchRanges;
  El('blend-status').textContent := '';
  DrawProvider;
  DrawPart;
  UpdateParentAudio;
  ShowTab(0);
  TStudioDialog(El('blend-style-dialog')).showModal;
  TJSHTMLElement(El('blend-style-0')).focus;
end;

procedure TStudioBlendChoices.Apply;
var
  LBlend: TJSObject;
  LSource: TJSObject;
  LRow: TJSObject;
  LParents: array[0..1] of TJSObject;
  LRows: TJSArray;
  I: Integer;
begin
  if not FAvailable then Exit;
  try
    StoreProvider;
    StorePart;
    FPlan.BaseParent := Number('blend-base-parent', 1);
    FPlan.MasterParent := Number('blend-master-parent', 1);
    FPlan.FormParent := Number('blend-form-parent', 1);
    FPlan.Context := TMusicBlendContext(Number('blend-context', 2));
    FPlan.UnionPitchRanges := TJSHTMLInputElement(El('blend-pitch-ranges')).checked;
    ValidateMusicBlendPlan(FPlan, Length(CProviders), Length(CParts));
    for I := 0 to 1 do
    begin
      LParents[I] := TJSObject(FRows[Number('blend-style-' + IntToStr(I), FRows.length - 1)]);
    end;
    LBlend := TJSObject.new;
    LBlend['format'] := 'pythian.studio.blend.v1';
    LBlend['right_style_id'] := StudioText(LParents[1], 'id');
    LBlend['base_parent'] := FPlan.BaseParent;
    LBlend['master_parent'] := FPlan.MasterParent;
    LBlend['form_parent'] := FPlan.FormParent;
    LBlend['context'] := Ord(FPlan.Context);
    LBlend['union_pitch_ranges'] := FPlan.UnionPitchRanges;
    LRows := TJSArray.new;
    LBlend['providers'] := LRows;
    for I := 0 to High(FPlan.Providers) do
    begin
      LRow := TJSObject.new;
      LRow['left_weight'] := FPlan.Providers[I].LeftWeight;
      LRow['right_weight'] := FPlan.Providers[I].RightWeight;
      LRow['control_parent'] := FPlan.Providers[I].ControlParent;
      LRows.push(LRow);
    end;
    LRows := TJSArray.new;
    LBlend['parts'] := LRows;
    for I := 0 to High(FPlan.Parts) do
    begin
      LRow := TJSObject.new;
      LRow['instrument_parent'] := FPlan.Parts[I].InstrumentParent;
      LRow['effects_parent'] := FPlan.Parts[I].EffectsParent;
      LRow['expression_parent'] := FPlan.Parts[I].ExpressionParent;
      LRows.push(LRow);
    end;
    LSource := TJSObject(TJSJSON.parse(TJSJSON.stringify(LParents[FPlan.BaseParent])));
    LSource['format'] := 'pythian.studio.blend-source.v1';
    LSource['id'] := '';
    LSource['kind'] := 'blend';
    LSource['name'] := StudioText(LParents[0], 'name') + ' + ' + StudioText(LParents[1], 'name');
    LSource['left_style_id'] := StudioText(LParents[0], 'id');
    LSource['has_form'] := LParents[FPlan.FormParent]['has_form'];
    if (StudioNumber(LParents[0], 'sample_rate') <> 24000) or
      (StudioNumber(LParents[1], 'sample_rate') <> 24000) then
      raise Exception.Create('Refresh saved styles to load their sound clocks.');
    LSource['sample_rate'] := 24000;
    LSource['tail_frames'] := MusicBlendSoundTailFrames(FPlan.BaseParent,
      FPlan.MasterParent, FPlan.Parts, Trunc(StudioNumber(LParents[0], 'tail_frames')),
      Trunc(StudioNumber(LParents[1], 'tail_frames')));
    LSource['blend'] := LBlend;
    TStudioDialog(El('blend-style-dialog')).close;
    FChoose(LSource);
  except
    on E: Exception do El('blend-status').textContent := E.Message;
  end;
end;

function TStudioBlendChoices.Changed(AEvent: TEventListenerEvent): Boolean;
var
  LId: String;
begin
  Result := False;
  LId := TJSElement(AEvent.currentTarget).id;
  try
    if LId = 'blend-provider' then
    begin
      StoreProvider;
      FProvider := Number('blend-provider', High(CProviders));
      DrawProvider;
    end
    else if LId = 'blend-part' then
    begin
      StorePart;
      FPart := Number('blend-part', High(CParts));
      DrawPart;
    end
    else if (LId = 'blend-style-0') or (LId = 'blend-style-1') then UpdateParentAudio;
    El('blend-status').textContent := '';
  except
    on E: Exception do
    begin
      TJSHTMLSelectElement(El('blend-provider')).value := IntToStr(FProvider);
      TJSHTMLSelectElement(El('blend-part')).value := IntToStr(FPart);
      El('blend-status').textContent := E.Message;
    end;
  end;
end;

function TStudioBlendChoices.Click(AEvent: TJSMouseEvent): Boolean;
var
  LId: String;
begin
  Result := False;
  LId := TJSElement(AEvent.currentTarget).id;
  if LId = 'confirm-blend-style' then Apply
  else ShowTab(StrToInt(Copy(LId, 11, 1)));
end;

function TStudioBlendChoices.TabKey(AEvent: TJSKeyboardEvent): Boolean;
var
  LIndex: Integer;
begin
  Result := False;
  LIndex := StrToInt(Copy(TJSElement(AEvent.currentTarget).id, 11, 1));
  if AEvent.key = 'ArrowRight' then LIndex := (LIndex + 1) mod 3
  else if AEvent.key = 'ArrowLeft' then LIndex := (LIndex + 2) mod 3
  else if AEvent.key = 'Home' then LIndex := 0
  else if AEvent.key = 'End' then LIndex := 2
  else Exit;
  AEvent.preventDefault;
  ShowTab(LIndex);
  TJSHTMLElement(El('blend-tab-' + IntToStr(LIndex))).focus;
end;

function TStudioBlendChoices.PreviewToggled(AEvent: TEventListenerEvent): Boolean;
var
  I: Integer;
begin
  Result := False;
  if El('blend-previews').hasAttribute('open') then Exit;
  for I := 0 to 1 do
    TJSHTMLAudioElement(El('blend-parent-audio-' + IntToStr(I))).pause;
end;

end.
