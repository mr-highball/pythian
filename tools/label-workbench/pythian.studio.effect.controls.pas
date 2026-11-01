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
unit pythian.studio.effect.controls;

{$mode delphi}{$H+}

interface

uses JS, Web, SysUtils, pythian.studio.sources;

type
  { Big Boss: source previews and generated parts share this presentation and
    catalog admission. It starts no jobs and owns no audio, inference or DSP. }
  TStudioEffectRackControls = class
  private
    FRoot: TJSElement;
    FRows: TJSArray;
    FChanged: TStudioChange;
    FMaximum: Integer;
    FSerial: Integer;
    function GetCount: Integer;
    function Edit(AEvent: TEventListenerEvent): Boolean;
    function Click(AEvent: TJSMouseEvent): Boolean;
    procedure Draw;
  public
    constructor Create(ARoot: TJSElement; const AChanged: TStudioChange;
      const AMaximum: Integer);
    destructor Destroy; override;
    procedure AddEffect(const AKind: String);
    procedure Restore(ARows: TJSArray);
    function Request(const ASampleRate: Integer): TJSArray;
    property Count: Integer read GetCount;
  end;

function ReadStudioDecimal(const AText, ACaption: String;
  const AMinimum, AMaximum: Double; AInput: TJSElement = nil): Double;
function StudioControlText(AObject: TJSObject; const AKey: String): String;

implementation

uses pythian.effects.catalog;

function StudioControlText(AObject: TJSObject; const AKey: String): String;
var
  LSettings: TFormatSettings;
begin
  Result := '';
  if AObject = nil then Exit;
  if isString(AObject[AKey]) then Result := String(AObject[AKey])
  else if isNumber(AObject[AKey]) then
  begin
    LSettings := FormatSettings;
    LSettings.DecimalSeparator := '.';
    LSettings.ThousandSeparator := #0;
    Result := FloatToStr(Double(AObject[AKey]), LSettings);
  end;
end;

function Add(AParent: TJSElement; const ATag, AText, AClass: String): TJSElement;
begin
  Result := document.createElement(ATag);
  Result.textContent := AText;
  Result.className := AClass;
  AParent.appendChild(Result);
end;

function ReadStudioDecimal(const AText, ACaption: String;
  const AMinimum, AMaximum: Double; AInput: TJSElement): Double;
var
  LText: String;
  LSettings: TFormatSettings;
  LDots: Integer;
  LDigits: Integer;
  I: Integer;
  LValid: Boolean;
begin
  Result := 0;
  LText := Trim(AText);
  LDots := 0;
  LDigits := 0;
  LValid := True;
  for I := 1 to Length(LText) do
  begin
    if LText[I] in ['0'..'9'] then Inc(LDigits)
    else if LText[I] = '.' then Inc(LDots)
    else if not ((LText[I] in ['-', '+']) and (I = 1)) then LValid := False;
  end;
  LSettings := FormatSettings;
  LSettings.DecimalSeparator := '.';
  LSettings.ThousandSeparator := #0;
  LValid := LValid and (LDigits > 0) and (LDots <= 1) and
    TryStrToFloat(LText, Result, LSettings);
  LValid := LValid and (Result >= AMinimum) and (Result <= AMaximum);
  if not LValid then
  begin
    if AInput <> nil then
    begin
      AInput.setAttribute('aria-invalid', 'true');
      TJSHTMLElement(AInput).focus;
    end;
    raise Exception.Create(ACaption + ': use ' + FloatToStr(AMinimum) +
      ' to ' + FloatToStr(AMaximum) + '.');
  end;
  if AInput <> nil then AInput.removeAttribute('aria-invalid');
end;

constructor TStudioEffectRackControls.Create(ARoot: TJSElement;
  const AChanged: TStudioChange; const AMaximum: Integer);
begin
  inherited Create;
  FRoot := ARoot;
  FChanged := AChanged;
  FMaximum := AMaximum;
  FRows := TJSArray.new;
  Draw;
end;

destructor TStudioEffectRackControls.Destroy;
begin
  FRoot.innerHTML := '';
  inherited Destroy;
end;

function TStudioEffectRackControls.GetCount: Integer;
begin
  Result := FRows.length;
end;

procedure TStudioEffectRackControls.Restore(ARows: TJSArray);
var
  I: Integer;
begin
  if (ARows = nil) or (ARows.length > FMaximum) then
    raise Exception.Create('Effect stack exceeds its stage limit.');
  FRows := TJSArray(TJSJSON.parse(TJSJSON.stringify(ARows)));
  for I := 0 to FRows.length - 1 do
  begin
    Inc(FSerial);
    TJSObject(FRows[I])['ui_id'] := IntToStr(FSerial);
  end;
  Draw;
end;

procedure TStudioEffectRackControls.AddEffect(const AKind: String);
var
  LRow: TJSObject;
  LDefinition: TEffectDefinition;
  I: Integer;
begin
  if Count >= FMaximum then raise Exception.Create('This effect stack is full.');
  if not FindEffectDefinition(AKind, LDefinition) then
    raise Exception.Create('Choose an available effect.');
  Inc(FSerial);
  LRow := TJSObject.new;
  LRow['ui_id'] := IntToStr(FSerial);
  LRow['kind'] := AKind;
  LRow['bypass'] := False;
  for I := 0 to High(LDefinition.Parameters) do
    LRow[LDefinition.Parameters[I].Key] := LDefinition.Parameters[I].DefaultValue;
  FRows.push(LRow);
  Draw;
  if Assigned(FChanged) then FChanged;
end;

procedure TStudioEffectRackControls.Draw;
var
  LCard: TJSElement;
  LToolbar: TJSElement;
  LLabel: TJSElement;
  LInput: TJSElement;
  LFields: TJSElement;
  LRow: TJSObject;
  LDefinition: TEffectDefinition;
  LId: String;
  I: Integer;
  J: Integer;
  procedure Button(const ACaption, AAction: String; const ADisabled: Boolean);
  var
    LButton: TJSElement;
  begin
    LButton := Add(LToolbar, 'button', ACaption, '');
    LButton.setAttribute('type', 'button');
    LButton.setAttribute('data-rack-action', AAction);
    LButton.setAttribute('data-row', LId);
    TJSHTMLButtonElement(LButton).disabled := ADisabled;
    LButton.addEventListener('click', @Click);
  end;
begin
  FRoot.innerHTML := '';
  if Count = 0 then Add(FRoot, 'p', 'No effects. Add a stage to shape the sound.', 'hint');
  for I := 0 to Count - 1 do
  begin
    LRow := TJSObject(FRows[I]);
    if not FindEffectDefinition(StudioText(LRow, 'kind'), LDefinition) then
      raise Exception.Create('Unsupported saved effect.');
    LId := StudioText(LRow, 'ui_id');
    LCard := Add(FRoot, 'div', '', 'track');
    Add(LCard, 'h3', IntToStr(I + 1) + '. ' + LDefinition.Caption, '');
    Add(LCard, 'p', LDefinition.Purpose, 'hint');
    LToolbar := Add(LCard, 'div', '', 'source-toolbar');
    LLabel := Add(LToolbar, 'label', '', '');
    LInput := Add(LLabel, 'input', '', '');
    LInput.setAttribute('type', 'checkbox');
    LInput.setAttribute('data-row', LId);
    LInput.setAttribute('data-key', 'bypass');
    TJSHTMLInputElement(LInput).checked := Boolean(LRow['bypass']);
    LInput.addEventListener('change', @Edit);
    Add(LLabel, 'span', 'Bypass', '');
    Button('Move up', 'up', I = 0);
    Button('Move down', 'down', I = Count - 1);
    Button('Remove', 'remove', False);
    LFields := Add(LCard, 'div', '', 'range-fields');
    for J := 0 to High(LDefinition.Parameters) do
    begin
      LLabel := Add(LFields, 'label', LDefinition.Parameters[J].Caption, '');
      LInput := Add(LLabel, 'input', '', '');
      LInput.setAttribute('type', 'text');
      LInput.setAttribute('inputmode', 'decimal');
      LInput.setAttribute('maxlength', '24');
      LInput.setAttribute('data-row', LId);
      LInput.setAttribute('data-key', LDefinition.Parameters[J].Key);
      TJSHTMLInputElement(LInput).value := StudioControlText(LRow, LDefinition.Parameters[J].Key);
      LInput.addEventListener('input', @Edit);
    end;
  end;
end;

function TStudioEffectRackControls.Edit(AEvent: TEventListenerEvent): Boolean;
var
  LInput: TJSHTMLInputElement;
  LRow: TJSObject;
  LKey: String;
  I: Integer;
begin
  Result := False;
  LInput := TJSHTMLInputElement(AEvent.currentTarget);
  LInput.removeAttribute('aria-invalid');
  LKey := LInput.getAttribute('data-key');
  for I := 0 to Count - 1 do
  begin
    LRow := TJSObject(FRows[I]);
    if StudioText(LRow, 'ui_id') <> LInput.getAttribute('data-row') then Continue;
    if LKey = 'bypass' then LRow[LKey] := LInput.checked
    else LRow[LKey] := LInput.value;
    if Assigned(FChanged) then FChanged;
    Break;
  end;
end;

function TStudioEffectRackControls.Click(AEvent: TJSMouseEvent): Boolean;
var
  LButton: TJSElement;
  LAction: String;
  LSwap: JSValue;
  I: Integer;
begin
  Result := False;
  LButton := TJSElement(AEvent.currentTarget);
  LAction := LButton.getAttribute('data-rack-action');
  for I := 0 to Count - 1 do
  begin
    if StudioText(TJSObject(FRows[I]), 'ui_id') <> LButton.getAttribute('data-row') then Continue;
    if LAction = 'remove' then FRows.splice(I, 1)
    else if (LAction = 'up') and (I > 0) then
    begin
      LSwap := FRows[I - 1]; FRows[I - 1] := FRows[I]; FRows[I] := LSwap;
    end
    else if (LAction = 'down') and (I < Count - 1) then
    begin
      LSwap := FRows[I + 1]; FRows[I + 1] := FRows[I]; FRows[I] := LSwap;
    end;
    Break;
  end;
  Draw;
  if Assigned(FChanged) then FChanged;
end;

function TStudioEffectRackControls.Request(const ASampleRate: Integer): TJSArray;
var
  LStored: TJSObject;
  LRow: TJSObject;
  LDefinition: TEffectDefinition;
  LSettings: TCatalogEffectSettings;
  LParameter: TEffectParameter;
  LInput: TJSElement;
  I: Integer;
  J: Integer;
begin
  Result := TJSArray.new;
  for I := 0 to Count - 1 do
  begin
    LStored := TJSObject(FRows[I]);
    if not FindEffectDefinition(StudioText(LStored, 'kind'), LDefinition) then
      raise Exception.Create('Choose an available effect.');
    LSettings := DefaultCatalogEffect(LDefinition.Kind);
    LRow := TJSObject.new;
    LRow['kind'] := LDefinition.Key;
    LRow['bypass'] := Boolean(LStored['bypass']);
    for J := 0 to High(LDefinition.Parameters) do
    begin
      LParameter := LDefinition.Parameters[J];
      LInput := FRoot.querySelector('input[data-row="' + StudioText(LStored, 'ui_id') +
        '"][data-key="' + LParameter.Key + '"]');
      LSettings.Values[J] := ReadStudioDecimal(StudioControlText(LStored, LParameter.Key),
        LParameter.Caption, LParameter.Minimum,
        EffectParameterMaximum(LParameter, ASampleRate), LInput);
      LRow[LParameter.Key] := LSettings.Values[J];
    end;
    ValidateCatalogEffect(LSettings, ASampleRate);
    Result.push(LRow);
  end;
end;

end.
