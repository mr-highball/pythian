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
unit pythian.studio.styles;
{$mode delphi}{$H+}{$modeswitch externalclass}
interface
uses JS, Web, SysUtils, pythian.studio.sources, pythian.studio.blend;
type
  TStudioChooseStyle = procedure(const AStyle: TJSObject) of object;
  TStudioStyles = class
  private
    FFetch: TStudioFetch;
    FChoose: TStudioChooseStyle;
    FBlend: TStudioBlendChoices;
    FPresetBlend: TJSObject;
    FRows: TJSArray;
    FJobId: String;
    FLoading, FSaving, FAvailable: Boolean;
    function El(const AId: String): TJSElement;
    procedure Refresh; async;
    procedure Save; async;
    procedure Draw;
    procedure Blended(const AStyle: TJSObject);
    function Click(AEvent: TJSMouseEvent): Boolean;
  public
    constructor Create(const AFetch: TStudioFetch; const AChoose: TStudioChooseStyle);
    procedure SetAvailable(const AAvailable: Boolean);
    procedure Open;
    procedure EditBlend(const AStyle: TJSObject);
    procedure SaveJob(const AJobId: String);
  end;
implementation
uses pythian.studio.requests;
function TStudioStyles.El(const AId: String): TJSElement;
begin Result := document.getElementById(AId) end;
constructor TStudioStyles.Create(const AFetch: TStudioFetch; const AChoose: TStudioChooseStyle);
begin
  FFetch := AFetch; FChoose := AChoose; FRows := TJSArray.new;
  FBlend := TStudioBlendChoices.Create(@Blended);
  El('refresh-styles').addEventListener('click', @Click);
  El('open-style-blend').addEventListener('click', @Click);
  El('confirm-save-style').addEventListener('click', @Click);
end;
procedure TStudioStyles.SetAvailable(const AAvailable: Boolean);
begin
  FAvailable := AAvailable;
  FBlend.SetAvailable(AAvailable);
  if El('styles-dialog').hasAttribute('open') then Draw;
end;
procedure TStudioStyles.Blended(const AStyle: TJSObject);
begin
  TStudioDialog(El('styles-dialog')).close;
  FChoose(AStyle);
end;
procedure TStudioStyles.Open;
begin TStudioDialog(El('styles-dialog')).showModal; Refresh end;
procedure TStudioStyles.EditBlend(const AStyle: TJSObject);
begin
  if not FAvailable then Exit;
  FPresetBlend := TJSObject(TJSJSON.parse(TJSJSON.stringify(AStyle)));
  Open;
end;
procedure TStudioStyles.SaveJob(const AJobId: String);
begin
  if FSaving or not FAvailable then Exit;
  FJobId := AJobId;
  TJSHTMLInputElement(El('style-name')).value := 'My style';
  El('save-style-status').textContent := '';
  El('save-style-close').textContent := 'Cancel';
  TStudioDialog(El('save-style-dialog')).showModal;
  TJSHTMLElement(El('style-name')).focus;
end;
procedure TStudioStyles.Refresh; async;
var LData: TJSObject;
begin
  if FLoading then Exit;
  FLoading := True;
  El('styles-status').textContent := 'Opening saved styles…';
  try
    LData := await(TJSObject, ReadStudioJSONResponse(FFetch('/api/studio/styles', 'GET', '')));
    if not isArray(LData['styles']) then raise Exception.Create('Style list is unavailable. Retry refresh.');
    FRows := TJSArray(LData['styles']);
    El('styles-status').textContent := IntToStr(FRows.length) + ' saved style(s).';
    if isArray(LData['errors']) and (TJSArray(LData['errors']).length > 0) then
      El('styles-status').textContent := El('styles-status').textContent + ' Some styles need repair.';
    Draw;
    if FPresetBlend <> nil then
    begin
      FBlend.Open(FRows, FPresetBlend);
      FPresetBlend := nil;
    end;
  except on E: Exception do El('styles-status').textContent := E.Message end;
  FLoading := False;
end;
procedure TStudioStyles.Draw;
var I: Integer; LCard, LTitle, LNote, LButton: TJSElement; LRow: TJSObject;
begin
  El('styles-list').innerHTML := '';
  TJSHTMLButtonElement(El('open-style-blend')).disabled := not FAvailable or (FRows.length < 2);
  for I := 0 to FRows.length - 1 do
  begin
    LRow := TJSObject(FRows[I]);
    LCard := document.createElement('article'); LCard.className := 'track';
    El('styles-list').appendChild(LCard);
    LTitle := document.createElement('h3'); LTitle.textContent := StudioText(LRow, 'name'); LCard.appendChild(LTitle);
    LNote := document.createElement('p'); LNote.className := 'hint';
    LNote.textContent := 'Saved musical ideas, controls and sounds. No new recording analysis.';
    if LRow['has_form'] = True then LNote.textContent := LNote.textContent +
      ' Keeps its ' + StudioTime(StudioNumber(LRow, 'preferred_duration_ms') / 1000) + ' song form.';
    LCard.appendChild(LNote);
    LButton := document.createElement('button'); LButton.textContent := 'Use this style';
    LButton.setAttribute('data-style-index', IntToStr(I)); LButton.addEventListener('click', @Click);
    TJSHTMLButtonElement(LButton).disabled := not FAvailable; LCard.appendChild(LButton);
  end;
  if FRows.length = 0 then
  begin
    LNote := document.createElement('p');
    LNote.textContent := 'Generate a track, then choose Save style below the result.';
    El('styles-list').appendChild(LNote);
  end;
end;
procedure TStudioStyles.Save; async;
var LWrite, LSaved: TJSObject; LName: String;
begin
  if FSaving or not FAvailable or (FJobId = '') then Exit;
  LName := Trim(TJSHTMLInputElement(El('style-name')).value);
  if LName = '' then begin El('save-style-status').textContent := 'Give your style a name.'; Exit end;
  FSaving := True; TJSHTMLButtonElement(El('confirm-save-style')).disabled := True;
  LWrite := TJSObject.new; LWrite['format'] := 'pythian.studio.style.write.v1';
  LWrite['name'] := LName; LWrite['job_id'] := FJobId;
  El('save-style-status').textContent := 'Saving style…';
  try
    LSaved := await(TJSObject, ReadStudioJSONResponse(FFetch('/api/studio/style', 'POST', TJSJSON.stringify(LWrite))));
    if StudioText(LSaved, 'name') <> LName then raise Exception.Create('The saved name differs. Retry Save style.');
    El('save-style-status').textContent := 'Saved. Choose Use a saved style to make another track.';
    El('save-style-close').textContent := 'Done';
  except on E: Exception do El('save-style-status').textContent := E.Message end;
  FSaving := False; TJSHTMLButtonElement(El('confirm-save-style')).disabled := False;
end;
function TStudioStyles.Click(AEvent: TJSMouseEvent): Boolean;
var LButton: TJSElement; I: Integer;
begin
  Result := False;
  LButton := TJSElement(AEvent.currentTarget);
  if LButton.id = 'refresh-styles' then Refresh
  else if LButton.id = 'open-style-blend' then FBlend.Open(FRows)
  else if LButton.id = 'confirm-save-style' then Save
  else if FAvailable and LButton.hasAttribute('data-style-index') then
  begin
    I := StrToInt(LButton.getAttribute('data-style-index'));
    if (I < 0) or (I >= FRows.length) then Exit;
    TStudioDialog(El('styles-dialog')).close;
    FChoose(TJSObject(FRows[I]));
  end;
end;
end.
