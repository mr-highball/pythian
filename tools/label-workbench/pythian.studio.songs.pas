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
unit pythian.studio.songs;
{$mode delphi}
{$H+}
interface
uses JS, Web, SysUtils, pythian.studio.sources;
type
  TStudioOpenSong = procedure(const AJobId: String) of object;
  TStudioSongs = class
  private
    FFetch: TStudioFetch;
    FOpen: TStudioOpenSong;
    FRows: TJSArray;
    FJobId: String;
    FSaving, FLoading: Boolean;
    function El(const AId: String): TJSElement;
    function Add(AParent: TJSElement; const ATag, AText: String): TJSElement;
    procedure Draw;
    procedure Refresh; async;
    procedure Save; async;
    function Click(AEvent: TJSMouseEvent): Boolean;
    function Filter(AEvent: TEventListenerEvent): Boolean;
  public
    constructor Create(const AFetch: TStudioFetch; const AOpen: TStudioOpenSong);
    procedure Open;
    procedure SaveJob(const AJobId: String);
  end;
implementation
uses pythian.studio.requests;
function TStudioSongs.El(const AId: String): TJSElement;
begin Result := document.getElementById(AId) end;
function TStudioSongs.Add(AParent: TJSElement; const ATag, AText: String): TJSElement;
begin Result := document.createElement(ATag); Result.textContent := AText; AParent.appendChild(Result) end;
constructor TStudioSongs.Create(const AFetch: TStudioFetch; const AOpen: TStudioOpenSong);
begin
  FFetch := AFetch; FOpen := AOpen; FRows := TJSArray.new;
  El('refresh-songs').addEventListener('click', @Click);
  El('confirm-save-song').addEventListener('click', @Click);
  El('song-filter').addEventListener('change', @Filter);
end;
procedure TStudioSongs.Open;
begin TStudioDialog(El('songs-dialog')).showModal; Refresh end;
procedure TStudioSongs.SaveJob(const AJobId: String);
var I: Integer; LRow: TJSObject;
begin
  if FSaving then Exit;
  FJobId := AJobId;
  TJSHTMLInputElement(El('song-name')).value := 'My generated song';
  TJSHTMLInputElement(El('song-playlist')).value := 'My songs';
  for I := 0 to FRows.length - 1 do
  begin
    LRow := TJSObject(FRows[I]);
    if StudioText(LRow, 'job_id') <> AJobId then Continue;
    if LRow['saved'] = True then
    begin
      TJSHTMLInputElement(El('song-name')).value := StudioText(LRow, 'title');
      TJSHTMLInputElement(El('song-playlist')).value := StudioText(LRow, 'playlist');
    end;
  end;
  El('save-song-status').textContent := '';
  El('save-song-close').textContent := 'Cancel';
  TStudioDialog(El('save-song-dialog')).showModal;
  TJSHTMLElement(El('song-name')).focus;
end;
procedure TStudioSongs.Refresh; async;
var LData: TJSObject;
begin
  if FLoading then Exit;
  FLoading := True;
  El('songs-status').textContent := 'Loading song list…';
  try
    LData := await(TJSObject, ReadStudioJSONResponse(FFetch('/api/studio/songs', 'GET', '')));
    if not isArray(LData['songs']) then raise Exception.Create('Song list is unavailable. Retry refresh.');
    FRows := TJSArray(LData['songs']);
    Draw;
    El('songs-status').textContent := IntToStr(FRows.length) + ' finished track(s).';
  except
    on E: Exception do El('songs-status').textContent := E.Message + ' Saved songs are kept.';
  end;
  FLoading := False;
end;
procedure TStudioSongs.Draw;
var LFilter: TJSHTMLSelectElement; LChoice, LName, LId, LUrl, LTitle: String;
  LNames: TJSArray; LRow: TJSObject; LCard, LControl, LBar: TJSElement; I: Integer;
begin
  LFilter := TJSHTMLSelectElement(El('song-filter'));
  LChoice := LFilter.value;
  LNames := TJSArray.new;
  for I := 0 to FRows.length - 1 do
  begin
    LName := StudioText(TJSObject(FRows[I]), 'playlist');
    if (LName <> '') and (LNames.indexOf(LName) < 0) then LNames.push(LName);
  end;
  LNames.sort;
  LFilter.innerHTML := '';
  Add(LFilter, 'option', 'All songs').setAttribute('value', '');
  El('song-playlist-names').innerHTML := '';
  for I := 0 to LNames.length - 1 do
  begin
    Add(LFilter, 'option', String(LNames[I])).setAttribute('value', String(LNames[I]));
    Add(El('song-playlist-names'), 'option', String(LNames[I])).setAttribute('value', String(LNames[I]));
  end;
  LFilter.value := LChoice;
  if LFilter.selectedIndex < 0 then LFilter.value := '';
  El('songs-list').innerHTML := '';
  for I := FRows.length - 1 downto 0 do
  begin
    LRow := TJSObject(FRows[I]);
    if (LFilter.value <> '') and (LFilter.value <> StudioText(LRow, 'playlist')) then Continue;
    LId := StudioText(LRow, 'job_id');
    LTitle := 'Generated song ' + IntToStr(FRows.length - I);
    if LRow['saved'] = True then LTitle := StudioText(LRow, 'title');
    LUrl := '/api/studio/instrumental-audio?job=' + encodeURIComponent(LId) + '&part=6';
    LCard := Add(El('songs-list'), 'article', ''); LCard.className := 'track';
    Add(LCard, 'h3', LTitle);
    LName := 'Recent generation · not added to a playlist';
    if LRow['saved'] = True then LName := 'Saved · ' + StudioText(LRow, 'playlist');
    Add(LCard, 'p', LName + ' · ' + StudioTime(StudioNumber(LRow, 'frame_count') / StudioNumber(LRow, 'sample_rate')));
    LControl := Add(LCard, 'audio', ''); LControl.setAttribute('controls', '');
    LControl.setAttribute('preload', 'none'); LControl.setAttribute('src', LUrl);
    LControl.setAttribute('aria-label', 'Play ' + LTitle);
    LBar := Add(LCard, 'div', ''); LBar.className := 'row-actions';
    LControl := Add(LBar, 'button', 'Open result');
    LControl.setAttribute('data-open-song', LId); LControl.addEventListener('click', @Click);
    LName := 'Save to playlist'; if LRow['saved'] = True then LName := 'Rename / move';
    LControl := Add(LBar, 'button', LName);
    LControl.setAttribute('data-save-song', LId); LControl.addEventListener('click', @Click);
    LControl := Add(LBar, 'a', '↓ Download WAV');
    LControl.setAttribute('href', LUrl); LControl.setAttribute('download', 'pythian-track.wav');
    LControl.className := 'button-link';
  end;
end;
procedure TStudioSongs.Save; async;
var LWrite, LSaved: TJSObject;
begin
  if FSaving or (FJobId = '') then Exit;
  if (Trim(TJSHTMLInputElement(El('song-name')).value) = '') or
    (Trim(TJSHTMLInputElement(El('song-playlist')).value) = '') then
  begin El('save-song-status').textContent := 'Enter a song name and playlist.'; Exit end;
  FSaving := True;
  TJSHTMLButtonElement(El('confirm-save-song')).disabled := True;
  LWrite := TJSObject.new;
  LWrite['format'] := 'pythian.studio.song.write.v1'; LWrite['job_id'] := FJobId;
  LWrite['title'] := Trim(TJSHTMLInputElement(El('song-name')).value);
  LWrite['playlist'] := Trim(TJSHTMLInputElement(El('song-playlist')).value);
  El('save-song-status').textContent := 'Saving…';
  try
    LSaved := await(TJSObject, ReadStudioJSONResponse(FFetch('/api/studio/song', 'POST', TJSJSON.stringify(LWrite))));
    if (StudioText(LSaved, 'job_id') <> FJobId) or
      (StudioText(LSaved, 'title') <> String(LWrite['title'])) or
      (StudioText(LSaved, 'playlist') <> String(LWrite['playlist'])) then
      raise Exception.Create('Song save returned different choices. Retry.');
    El('save-song-status').textContent := 'Saved. Find it in Songs → ' + StudioText(LSaved, 'playlist') + '.';
    El('save-song-close').textContent := 'Done';
    Refresh;
  except
    on E: Exception do El('save-song-status').textContent := E.Message + ' Retry Save song; this keeps the same generation.';
  end;
  FSaving := False;
  TJSHTMLButtonElement(El('confirm-save-song')).disabled := False;
end;
function TStudioSongs.Filter(AEvent: TEventListenerEvent): Boolean;
begin Result := False; Draw end;
function TStudioSongs.Click(AEvent: TJSMouseEvent): Boolean;
var LControl: TJSElement;
begin
  Result := False; LControl := TJSElement(AEvent.currentTarget);
  if LControl.id = 'refresh-songs' then Refresh
  else if LControl.id = 'confirm-save-song' then Save
  else if LControl.hasAttribute('data-open-song') then FOpen(LControl.getAttribute('data-open-song'))
  else if LControl.hasAttribute('data-save-song') then SaveJob(LControl.getAttribute('data-save-song'));
end;
end.
