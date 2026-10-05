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
unit pythian.listening.references;

{$mode delphi}
{$H+}
{$modeswitch externalclass}

interface

uses JS, Web, SysUtils, Math, pythian.studio.sources;

type
  TListeningReference = class
  private
    FFetch: TStudioFetch;
    FUrl: String;
    FRoot, FStatus, FControls, FClock: TJSElement;
    FSelect: TJSHTMLSelectElement;
    FSeek: TJSHTMLInputElement;
    FPlayer: TJSHTMLAudioElement;
    FPrevious, FNext, FRetry: TJSHTMLButtonElement;
    FRows: TJSArray;
    FStart, FEnd, FRate, FWindow: Double;
    FBusy, FDisposed: Boolean;
    function Add(AParent: TJSElement; const ATag, AText: String): TJSElement;
    procedure Load; async;
    procedure SelectSource;
    procedure SetWindow(const AFrame: Double);
    function Toggle(AEvent: TEventListenerEvent): Boolean;
    function Changed(AEvent: TEventListenerEvent): Boolean;
    function Click(AEvent: TJSMouseEvent): Boolean;
    function Playing(AEvent: TEventListenerEvent): Boolean;
    function TimeChanged(AEvent: TEventListenerEvent): Boolean;
    function Failed(AEvent: TJSErrorEvent): Boolean;
    function Hide(AEvent: TEventListenerEvent): Boolean;
  public
    constructor Create(AParent: TJSElement; const AFetch: TStudioFetch; const AUrl: String);
    destructor Destroy; override;
    procedure Stop;
  end;

implementation

uses pythian.studio.requests;

type
  TReferenceDocument = class external name 'Document' (TJSDocument)
    procedure removeEventListener(const AType: String; const AListener: JSValue;
      const ACapture: Boolean); reintroduce;
  end;

function TListeningReference.Add(AParent: TJSElement; const ATag, AText: String): TJSElement;
begin
  Result := document.createElement(ATag);
  Result.textContent := AText;
  AParent.appendChild(Result);
end;

constructor TListeningReference.Create(AParent: TJSElement;
  const AFetch: TStudioFetch; const AUrl: String);
var
  LLabel, LBar: TJSElement;
begin
  inherited Create;
  FFetch := AFetch;
  FUrl := AUrl;
  FRoot := Add(AParent, 'details', '');
  FRoot.className := 'original-reference';
  Add(FRoot, 'summary', 'Compare with original');
  FStatus := Add(FRoot, 'p', 'Hear the selections used to make this audition.');
  FStatus.setAttribute('role', 'status');
  FControls := Add(FRoot, 'div', '');
  FControls.setAttribute('hidden', '');
  LLabel := Add(FControls, 'label', 'Original selection');
  FSelect := TJSHTMLSelectElement(Add(LLabel, 'select', ''));
  FSelect.addEventListener('change', @Changed);
  FClock := Add(FControls, 'p', '');
  FClock.className := 'original-clock';
  FPlayer := TJSHTMLAudioElement(Add(FControls, 'audio', ''));
  FPlayer.controls := True;
  FPlayer.preload := 'none';
  FPlayer.setAttribute('aria-label', 'Original selection audio');
  FPlayer.addEventListener('timeupdate', @TimeChanged);
  FPlayer.onerror := @Failed;
  LLabel := Add(FControls, 'label', 'Position in the original selection');
  FSeek := TJSHTMLInputElement(Add(LLabel, 'input', ''));
  FSeek.setAttribute('type', 'range');
  FSeek.setAttribute('step', '1');
  FSeek.addEventListener('change', @Changed);
  LBar := Add(FControls, 'div', '');
  LBar.className := 'original-transport';
  FPrevious := TJSHTMLButtonElement(Add(LBar, 'button', '← 30 s'));
  FPrevious.setAttribute('aria-label', 'Previous 30 seconds of original');
  FNext := TJSHTMLButtonElement(Add(LBar, 'button', '30 s →'));
  FNext.setAttribute('aria-label', 'Next 30 seconds of original');
  FPrevious.setAttribute('type', 'button');
  FNext.setAttribute('type', 'button');
  FPrevious.onclick := @Click;
  FNext.onclick := @Click;
  FRetry := TJSHTMLButtonElement(Add(FRoot, 'button', 'Retry original'));
  FRetry.setAttribute('type', 'button');
  FRetry.setAttribute('hidden', '');
  FRetry.onclick := @Click;
  FRoot.addEventListener('toggle', @Toggle);
  document.addEventListener('play', @Playing, True);
  window.addEventListener('pagehide', @Hide);
end;

destructor TListeningReference.Destroy;
begin
  FDisposed := True;
  Stop;
  FRoot.removeEventListener('toggle', @Toggle);
  TReferenceDocument(document).removeEventListener('play', @Playing, True);
  window.removeEventListener('pagehide', @Hide);
  inherited Destroy;
end;

procedure TListeningReference.Stop;
begin
  FPlayer.pause;
  FPlayer.removeAttribute('src');
  FPlayer.load;
end;

procedure TListeningReference.Load; async;
var
  LResponse: TJSResponse;
  LData, LRow: TJSObject;
  LOption: TJSElement;
  I: Integer;
begin
  if FBusy or FDisposed then Exit;
  FBusy := True;
  FStatus.textContent := 'Loading original selections…';
  FRetry.setAttribute('hidden', '');
  try
    LResponse := TJSResponse(await(JSValue, AwaitStudioPromise(FFetch(FUrl, 'GET', ''), 15)));
    if FDisposed then Exit;
    if LResponse.status <> 200 then
      raise Exception.Create('Originals could not load. Reconnect and retry.');
    LData := TJSObject(await(JSValue, AwaitStudioPromise(LResponse.json(), 15)));
    if FDisposed then Exit;
    if (StudioText(LData, 'format') <> 'pythian.listening.references.v1') or
      not isArray(LData['sources']) then raise Exception.Create('Original selection details are unavailable.');
    FRows := TJSArray(LData['sources']);
    FStatus.textContent := StudioText(LData, 'message');
    FSelect.textContent := '';
    for I := 0 to FRows.length - 1 do
    begin
      LRow := TJSObject(FRows[I]);
      LOption := Add(FSelect, 'option', StudioText(LRow, 'title') + ' · ' +
        StudioTime(StudioNumber(LRow, 'start_frame') / StudioNumber(LRow, 'sample_rate')) + '–' +
        StudioTime(StudioNumber(LRow, 'end_frame') / StudioNumber(LRow, 'sample_rate')));
      LOption.setAttribute('value', IntToStr(I));
    end;
    if FRows.length > 0 then
    begin
      FSelect.value := '0';
      FControls.removeAttribute('hidden');
      SelectSource;
    end;
  except
    on E: Exception do
      if not FDisposed then
      begin
        FStatus.textContent := E.Message;
        FRetry.removeAttribute('hidden');
      end;
  end;
  FBusy := False;
end;

procedure TListeningReference.SelectSource;
var
  LRow: TJSObject;
begin
  Stop;
  LRow := TJSObject(FRows[StrToInt(FSelect.value)]);
  FStart := StudioNumber(LRow, 'start_frame');
  FEnd := StudioNumber(LRow, 'end_frame');
  FRate := StudioNumber(LRow, 'sample_rate');
  FSeek.min := FloatToStr(FStart / FRate);
  FSeek.max := FloatToStr(Max(FStart, FEnd - 1) / FRate);
  SetWindow(FStart);
end;

procedure TListeningReference.SetWindow(const AFrame: Double);
var
  LRow: TJSObject;
  LAvailable: Boolean;
begin
  Stop;
  LRow := TJSObject(FRows[StrToInt(FSelect.value)]);
  FWindow := Floor(Max(FStart, Min(AFrame, FEnd - 1)));
  LAvailable := Boolean(LRow['available']);
  FPlayer.hidden := not LAvailable;
  FSeek.disabled := not LAvailable;
  FPrevious.disabled := not LAvailable or (FWindow <= FStart);
  FNext.disabled := not LAvailable or (FWindow + 30 * FRate >= FEnd);
  FSeek.value := FloatToStr(FWindow / FRate);
  if LAvailable then
  begin
    FPlayer.src := '/api/audio?hash=' + encodeURIComponent(StudioText(LRow, 'source_sha256')) +
      '&start=' + FloatToStr(FWindow) + '&end=' + FloatToStr(Min(FEnd, FWindow + 30 * FRate));
    FClock.textContent := 'Original ' + StudioTime(FWindow / FRate) + '–' +
      StudioTime(Min(FEnd, FWindow + 30 * FRate) / FRate);
  end
  else FClock.textContent := 'This original is missing from the collection.';
  FSeek.setAttribute('aria-valuetext', StudioTime(FWindow / FRate) + ' in original');
end;

function TListeningReference.Toggle(AEvent: TEventListenerEvent): Boolean;
begin
  Result := True;
  if not FRoot.hasAttribute('open') then Stop
  else if FRows = nil then Load
  else if FRows.length > 0 then SetWindow(FWindow);
end;

function TListeningReference.Changed(AEvent: TEventListenerEvent): Boolean;
begin
  Result := True;
  if AEvent.currentTarget = FSelect then SelectSource
  else SetWindow(StrToFloat(FSeek.value) * FRate);
end;

function TListeningReference.Click(AEvent: TJSMouseEvent): Boolean;
begin
  Result := True;
  if AEvent.currentTarget = FRetry then
  begin
    if FRows = nil then Load
    else if FRows.length > 0 then
    begin
      SetWindow(FWindow);
      FRetry.setAttribute('hidden', '');
    end;
  end
  else if AEvent.currentTarget = FPrevious then SetWindow(FWindow - 30 * FRate)
  else SetWindow(FWindow + 30 * FRate);
end;

function TListeningReference.Playing(AEvent: TEventListenerEvent): Boolean;
var
  LPlayers: TJSNodeList;
  I: Integer;
begin
  Result := True;
  if AEvent.target <> FPlayer then FPlayer.pause
  else
  begin
    LPlayers := document.querySelectorAll('audio');
    for I := 0 to LPlayers.length - 1 do
      if LPlayers[I] <> FPlayer then TJSHTMLAudioElement(LPlayers[I]).pause;
  end;
end;

function TListeningReference.TimeChanged(AEvent: TEventListenerEvent): Boolean;
begin
  Result := True;
  if (FRows <> nil) and (FRows.length > 0) and (FRate > 0) and
    FPlayer.hasAttribute('src') then
    FClock.textContent := 'Original ' + StudioTime(FWindow / FRate + FPlayer.currentTime) +
      ' · preview ends ' + StudioTime(Min(FEnd, FWindow + 30 * FRate) / FRate);
end;

function TListeningReference.Failed(AEvent: TJSErrorEvent): Boolean;
begin
  Result := True;
  FClock.textContent := 'Original audio could not load. Reconnect or restore the recording, then retry.';
  FRetry.removeAttribute('hidden');
end;

function TListeningReference.Hide(AEvent: TEventListenerEvent): Boolean;
begin
  Result := True;
  Stop;
end;

end.
