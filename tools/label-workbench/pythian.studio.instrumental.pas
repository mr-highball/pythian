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

unit pythian.studio.instrumental;
{$mode delphi}
{$H+}
interface
uses JS, Web, WebAudio, SysUtils, Math, pythian.studio.sources;

type
  { Big Boss: presentation and device playback only. All musical decisions,
    sound generation, levels and WAVs come from the native Pascal runtime. }
  TStudioInstrumental = class
  private
    FFetch: TStudioFetch;
    FSettings, FMixer, FStatus, FSeek, FClock: TJSElement;
    FContext: TJSAudioContext;
    FBuffers: array[0..5] of TJSAudioBuffer;
    FNodes: array[0..5] of TJSAudioBufferSourceNode;
    FGains: array[0..5] of TJSGainNode;
    FMuted, FSolo: array[0..5] of Boolean;
    FJob: String;
    FPlaying, FLoading, FDisposed: Boolean;
    FEpoch, FTimer: Integer;
    FPosition, FDuration, FStarted: Double;
    function Add(AParent: TJSElement; const ATag, AText: String): TJSElement;
    function Input(AParent: TJSElement; const AId, ALabel, AValue: String;
      AMinimum, AMaximum: Integer): TJSElement;
    function Number(const AId: String; AMinimum, AMaximum: Integer): Integer;
    procedure StopNodes;
    procedure CloseAudio;
    procedure UpdateGains;
    procedure Tick;
    procedure Play; async;
    function Click(AEvent: TJSMouseEvent): Boolean;
    function Seek(AEvent: TEventListenerEvent): Boolean;
    function Leaving(AEvent: TEventListenerEvent): Boolean;
    function OtherAudio(AEvent: TEventListenerEvent): Boolean;
  public
    constructor Create(const AFetch: TStudioFetch; AParent: TJSElement);
    destructor Destroy; override;
    function ReadConfig: TJSObject;
    procedure RestoreConfig(AConfig: TJSObject);
    procedure ApplyMusicalContext(AMaterial: TJSObject);
    procedure SetEnabled(const AEnabled: Boolean);
    procedure Show(const AVisible: Boolean);
    procedure AttachMixer(AParent: TJSElement; const AJob: String; const ADuration: Double);
    procedure ClearMixer;
  end;
implementation
uses pythian.studio.requests;

const
  CNames: array[0..5] of String = ('Bass', 'Harmony', 'Lead', 'Kick', 'Snare', 'Hat');
  CActions: array[0..4] of String = ('Play', 'Pause', 'Stop', 'Mute', 'Solo');

function TStudioInstrumental.Add(AParent: TJSElement; const ATag, AText: String): TJSElement;
begin
  Result := document.createElement(ATag); Result.textContent := AText;
  AParent.appendChild(Result);
end;

function TStudioInstrumental.Input(AParent: TJSElement;
  const AId, ALabel, AValue: String; AMinimum, AMaximum: Integer): TJSElement;
var LLabel: TJSElement;
begin
  LLabel := Add(AParent, 'label', ALabel);
  Result := Add(LLabel, 'input', '');
  Result.id := AId; Result.setAttribute('type', 'number');
  Result.setAttribute('min', IntToStr(AMinimum)); Result.setAttribute('max', IntToStr(AMaximum));
  Result.setAttribute('step', '1'); Result.setAttribute('value', AValue);
end;

constructor TStudioInstrumental.Create(const AFetch: TStudioFetch; AParent: TJSElement);
var LRow, LSelect, LOption, LLabel, LDetails: TJSElement; I, J: Integer;
const CShapes: array[0..3] of String = ('saw', 'triangle', 'square', 'sine');
begin
  inherited Create; FFetch := AFetch;
  FSettings := Add(AParent, 'section', ''); FSettings.id := 'instrumental-settings';
  Add(FSettings, 'h3', 'Make an instrumental experiment');
  Add(FSettings, 'p', 'Experimental · WFC arranges synthesized bass, harmony, lead and drums. Saved musical choices can supply an editable motif; other parts use authored accompaniment.').className := 'hint';
  LRow := Add(FSettings, 'div', ''); LRow.className := 'range-fields';
  Input(LRow, 'instrumental-tempo', 'Tempo (BPM)', '120', 40, 240);
  Input(LRow, 'instrumental-bars', 'Length (bars, 4 beats each)', '8', 1, 32);
  LLabel := Add(LRow, 'label', 'Key root');
  LSelect := Add(LLabel, 'select', ''); LSelect.id := 'instrumental-tonic';
  for I := 0 to 11 do
  begin
    LOption := Add(LSelect, 'option', Copy('C C#D D#E F F#G G#A A#B ', I * 2 + 1, 2));
    LOption.setAttribute('value', IntToStr(I));
  end;
  LSelect := Add(Add(LRow, 'label', 'Accompaniment'), 'select', '');
  LSelect.id := 'instrumental-mode';
  LOption := Add(LSelect, 'option', 'Major');
  LOption.setAttribute('value', 'major');
  LOption := Add(LSelect, 'option', 'Natural minor');
  LOption.setAttribute('value', 'natural_minor');
  Add(FSettings, 'p', 'The starter uses major/minor chord changes relative to this root. Length is finite; long instrumental sessions are a separate upcoming capability.').className := 'hint';
  LDetails := Add(FSettings, 'details', '');
  Add(LDetails, 'summary', 'Sounds and mix');
  Add(LDetails, 'p', 'Choose the three pitched sounds and six mix levels. Zero silences a part in the new render.').className := 'hint';
  LRow := Add(LDetails, 'div', ''); LRow.className := 'instrumental-parts';
  for I := 0 to 5 do
  begin
    LLabel := Add(LRow, 'div', ''); LLabel.className := 'track';
    Add(LLabel, 'strong', CNames[I]);
    if I < 3 then
    begin
      LSelect := Add(Add(LLabel, 'label', 'Instrument sound'), 'select', '');
      LSelect.id := 'instrumental-sound-' + IntToStr(I);
      for J := 0 to 3 do
      begin
        LOption := Add(LSelect, 'option', CShapes[J]);
        LOption.setAttribute('value', CShapes[J]);
      end;
      TJSHTMLSelectElement(LSelect).value := CShapes[I];
    end
    else Add(LLabel, 'p', 'Synthesized ' + CNames[I]).className := 'hint';
    Input(LLabel, 'instrumental-level-' + IntToStr(I), 'Mix level (0–100)', '100', 0, 100);
  end;
  window.addEventListener('pagehide', @Leaving);
  document.addEventListener('play', @OtherAudio, True);
end;

destructor TStudioInstrumental.Destroy;
begin
  FDisposed := True; ClearMixer;
  window.removeEventListener('pagehide', @Leaving);
  TStudioDocument(document).removeEventListener('play', @OtherAudio, True);
  inherited Destroy;
end;

function TStudioInstrumental.Number(const AId: String; AMinimum, AMaximum: Integer): Integer;
var LText: String;
begin
  LText := TJSHTMLInputElement(document.getElementById(AId)).value;
  if not TryStrToInt(LText, Result) or (Result < AMinimum) or (Result > AMaximum) then
    raise Exception.Create('Enter ' + IntToStr(AMinimum) + ' to ' + IntToStr(AMaximum) + ' for ' + AId);
end;

function TStudioInstrumental.ReadConfig: TJSObject;
var LShapes, LLevels: TJSArray; I: Integer;
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
end;

procedure TStudioInstrumental.RestoreConfig(AConfig: TJSObject);
var I: Integer;
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
  ReadConfig;
end;

procedure TStudioInstrumental.ApplyMusicalContext(AMaterial: TJSObject);
var LTempo, LTonic: Integer; LMode: String;
begin
  LTempo := 120;
  LTonic := 0;
  LMode := 'major';
  if AMaterial <> nil then
  begin
    LTempo := Trunc(StudioNumber(AMaterial, 'tempo_bpm'));
    LTonic := Trunc(StudioNumber(AMaterial, 'tonic'));
    LMode := StudioText(AMaterial, 'mode');
  end;
  TJSHTMLInputElement(document.getElementById('instrumental-tempo')).value := IntToStr(LTempo);
  TJSHTMLSelectElement(document.getElementById('instrumental-tonic')).value := IntToStr(LTonic);
  TJSHTMLSelectElement(document.getElementById('instrumental-mode')).value := LMode;
end;

procedure TStudioInstrumental.SetEnabled(const AEnabled: Boolean);
var LControls: TJSNodeList; I: Integer;
begin
  LControls := FSettings.querySelectorAll('input,select');
  for I := 0 to LControls.length - 1 do
    TJSHTMLInputElement(LControls[I]).disabled := not AEnabled;
end;

procedure TStudioInstrumental.Show(const AVisible: Boolean);
begin
  if AVisible then FSettings.removeAttribute('hidden')
  else FSettings.setAttribute('hidden', '');
end;

procedure TStudioInstrumental.StopNodes;
var I: Integer;
begin
  if FPlaying and (FContext <> nil) then
    FPosition := Min(FDuration, Max(0, FContext.currentTime - FStarted));
  FPlaying := False;
  for I := 0 to 5 do
  begin
    if FNodes[I] <> nil then
    begin FNodes[I].stop; FNodes[I].disconnect; FNodes[I] := nil end;
    if FGains[I] <> nil then begin FGains[I].disconnect; FGains[I] := nil end;
  end;
end;

procedure TStudioInstrumental.CloseAudio;
var I: Integer;
begin
  StopNodes;
  if FContext <> nil then begin FContext.close; FContext := nil end;
  for I := 0 to 5 do FBuffers[I] := nil;
end;

procedure TStudioInstrumental.ClearMixer;
begin
  Inc(FEpoch); FLoading := False; window.clearInterval(FTimer);
  CloseAudio; FPosition := 0; FJob := ''; FMixer := nil;
end;

procedure TStudioInstrumental.UpdateGains;
var I: Integer; LAnySolo: Boolean;
begin
  LAnySolo := False;
  for I := 0 to 5 do LAnySolo := LAnySolo or FSolo[I];
  for I := 0 to 5 do
    if FGains[I] <> nil then
      if FMuted[I] or (LAnySolo and not FSolo[I]) then FGains[I].gain.value := 0
      else FGains[I].gain.value := 1;
end;

procedure TStudioInstrumental.Tick;
var LPosition: Double;
begin
  if FMixer = nil then Exit;
  LPosition := FPosition;
  if FPlaying then LPosition := Max(0, FContext.currentTime - FStarted);
  if LPosition >= FDuration then
  begin StopNodes; FPosition := 0; LPosition := 0; FStatus.textContent := 'Finished. Play again or change a part.' end;
  TJSHTMLInputElement(FSeek).value := FloatToStr(LPosition);
  FClock.textContent := FormatFloat('0.0', LPosition) + ' / ' + FormatFloat('0.0', FDuration) + ' s';
end;

procedure TStudioInstrumental.AttachMixer(AParent: TJSElement; const AJob: String; const ADuration: Double);
var LRow, LButton: TJSElement; I, J: Integer; LAction: String;
begin
  ClearMixer; FJob := AJob; FDuration := ADuration;
  FMixer := Add(AParent, 'section', ''); FMixer.className := 'instrumental-mixer';
  Add(FMixer, 'h4', 'Explore the parts');
  Add(FMixer, 'p', 'Mute or solo while listening. Notes stay the same; saved feedback does not retrain.').className := 'hint';
  LRow := Add(FMixer, 'div', ''); LRow.className := 'source-toolbar';
  for J := 0 to 2 do
  begin
    LAction := CActions[J];
    LButton := Add(LRow, 'button', LAction); LButton.setAttribute('type', 'button');
    LButton.setAttribute('data-action', LAction); LButton.addEventListener('click', @Click);
  end;
  FSeek := Input(FMixer, 'instrumental-seek', 'Position in generated music', '0', 0, Ceil(FDuration));
  FSeek.setAttribute('type', 'range'); FSeek.setAttribute('step', '0.1');
  FSeek.addEventListener('change', @Seek);
  FClock := Add(FMixer, 'p', '');
  FStatus := Add(FMixer, 'p', 'Play loads only this result’s six synthesized parts.');
  FStatus.setAttribute('role', 'status');
  for I := 0 to 5 do
  begin
    FMuted[I] := False; FSolo[I] := False;
    LRow := Add(FMixer, 'div', ''); LRow.className := 'source-toolbar';
    Add(LRow, 'strong', CNames[I]);
    for J := 3 to 4 do
    begin
      LAction := CActions[J];
      LButton := Add(LRow, 'button', LAction); LButton.setAttribute('type', 'button');
      LButton.setAttribute('data-action', LAction); LButton.setAttribute('data-part', IntToStr(I));
      LButton.setAttribute('aria-label', LAction + ' ' + CNames[I]);
      LButton.setAttribute('aria-pressed', 'false'); LButton.addEventListener('click', @Click);
    end;
  end;
  FTimer := window.setInterval(@Tick, 250); Tick;
end;

procedure TStudioInstrumental.Play; async;
var I, LEpoch: Integer; LResponse: TJSResponse; LBytes: TJSArrayBuffer; LAudios: TJSNodeList;
begin
  if FPlaying or FLoading or (FMixer = nil) then Exit;
  FLoading := True; LEpoch := FEpoch;
  try
    try
    if FContext = nil then FContext := TJSAudioContext.new;
    await(JSValue, FContext.resume);
    LAudios := document.querySelectorAll('audio');
    for I := 0 to LAudios.length - 1 do TJSHTMLAudioElement(LAudios[I]).pause;
    for I := 0 to 5 do
      if FBuffers[I] = nil then
      begin
        FStatus.textContent := 'Loading ' + CNames[I] + ' (' + IntToStr(I + 1) + '/6)…';
        LResponse := TJSResponse(await(JSValue, AwaitStudioPromise(FFetch(
          '/api/studio/instrumental-audio?job=' + encodeURIComponent(FJob) +
          '&part=' + IntToStr(I), 'GET', ''), 15)));
        if LEpoch <> FEpoch then Exit;
        if LResponse.status <> 200 then raise Exception.Create('Part audio is unavailable. Refresh this job.');
        LBytes := TJSArrayBuffer(await(JSValue, AwaitStudioPromise(LResponse.arrayBuffer(), 15)));
        if LEpoch <> FEpoch then Exit;
        FBuffers[I] := TJSAudioBuffer(await(JSValue, AwaitStudioPromise(FContext.decodeAudioData(LBytes), 15)));
        if LEpoch <> FEpoch then Exit;
      end;
    if FPosition >= FDuration then FPosition := 0;
    FStarted := FContext.currentTime + 0.05 - FPosition;
    for I := 0 to 5 do
    begin
      FNodes[I] := FContext.createBufferSource; FNodes[I].buffer := FBuffers[I];
      FGains[I] := FContext.createGain;
      FNodes[I].connect(FGains[I]); FGains[I].connect(FContext.destination);
    end;
    UpdateGains;
    for I := 0 to 5 do FNodes[I].start(FStarted + FPosition, FPosition);
    FPlaying := True; FStatus.textContent := 'Playing synthesized parts.';
  except
    on E: Exception do
      if LEpoch = FEpoch then begin StopNodes; FStatus.textContent := E.Message end;
    end;
  finally
    if LEpoch = FEpoch then FLoading := False;
  end;
end;

function TStudioInstrumental.Click(AEvent: TJSMouseEvent): Boolean;
var LButton: TJSElement; LAction: String; I: Integer; LPressed: Boolean;
begin
  Result := False; LButton := TJSElement(AEvent.currentTarget);
  LAction := LButton.getAttribute('data-action');
  if LAction = 'Play' then Play
  else if (LAction = 'Pause') or (LAction = 'Stop') then
  begin
    if FLoading then begin Inc(FEpoch); FLoading := False; CloseAudio end
    else StopNodes;
    if LAction = 'Stop' then FPosition := 0;
    if LAction = 'Stop' then FStatus.textContent := 'Stopped.'
    else FStatus.textContent := 'Paused.';
    Tick;
  end
  else
  begin
    I := StrToInt(LButton.getAttribute('data-part'));
    if LAction = 'Mute' then begin FMuted[I] := not FMuted[I]; LPressed := FMuted[I] end
    else begin FSolo[I] := not FSolo[I]; LPressed := FSolo[I] end;
    LButton.setAttribute('aria-pressed', LowerCase(BoolToStr(LPressed, True))); UpdateGains;
  end;
end;

function TStudioInstrumental.Seek(AEvent: TEventListenerEvent): Boolean;
var LResume: Boolean;
begin
  Result := False; LResume := FPlaying; StopNodes;
  FPosition := StrToFloat(TJSHTMLInputElement(FSeek).value); Tick;
  if LResume then Play;
end;

function TStudioInstrumental.Leaving(AEvent: TEventListenerEvent): Boolean;
begin Result := False; Inc(FEpoch); FLoading := False; CloseAudio end;

function TStudioInstrumental.OtherAudio(AEvent: TEventListenerEvent): Boolean;
begin
  Result := False;
  if FLoading then
  begin Inc(FEpoch); FLoading := False; CloseAudio end
  else StopNodes;
end;

end.
