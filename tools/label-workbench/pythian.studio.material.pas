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

unit pythian.studio.material;
{$mode delphi}
{$H+}
interface
uses JS, Web, SysUtils, Math, pythian.studio.sources, pythian.workspace.guide;

type
  { Big Boss: a detached editing draft. Analysis, quantization and model creation
    stay in the primary Pascal library/native jobs. Apply never submits a job. }
  TStudioMaterial = class
  private
    FFetch: TStudioFetch;
    FChanged: TStudioChange;
    FValue, FDraft: TJSObject;
    FPanel, FSummary, FNotice, FGrid, FSource, FOrigin: TJSElement;
    FScrollX, FScrollY, FCell, FPage, FEpoch: Integer;
    FEnabled, FBusy, FEditedPattern: Boolean;
    function Add(AParent: TJSElement; const ATag, AText, AId: String): TJSElement;
    function Button(AParent: TJSElement; const AText, AAction: String): TJSElement;
    function Field(AParent: TJSElement; const ALabel, AId, AType: String): TJSElement;
    function Select(AParent: TJSElement; const ALabel, AId: String;
      const ALabels, AValues: array of String): TJSElement;
    function El(const AId: String): TJSElement;
    function Number(const AId: String; AMin, AMax: Integer): Integer;
    procedure Open;
    procedure Finish;
    procedure Draw;
    procedure DrawCells;
    procedure DrawCell;
    procedure DrawSummary;
    procedure DrawSoundState;
    procedure SetTab(const ATab: String);
    procedure MarkPitch;
    procedure Load(const AJob: String; const ARebuild: Boolean;
      const ASoundOnly: Boolean = False); async;
    function Click(AEvent: TJSMouseEvent): Boolean;
    function Edit(AEvent: TEventListenerEvent): Boolean;
    function Cancel(AEvent: TEventListenerEvent): Boolean;
    function DialogClosed(AEvent: TEventListenerEvent): Boolean;
  public
    constructor Create(const AFetch: TStudioFetch; const AChanged: TStudioChange);
    procedure Restore(AValue: TJSObject);
    procedure SetEnabled(const AEnabled: Boolean);
    function Value: TJSObject;
  end;

implementation
uses pythian.studio.requests, pythian.music.pattern, pythian.pitch.track;

function CopyObject(AValue: TJSObject): TJSObject;
begin
  Result := nil;
  if AValue <> nil then
    Result := TJSObject(TJSJSON.parse(TJSJSON.stringify(AValue)));
end;

function TStudioMaterial.Add(AParent: TJSElement;
  const ATag, AText, AId: String): TJSElement;
begin
  Result := document.createElement(ATag);
  Result.textContent := AText;
  if AId <> '' then Result.id := AId;
  AParent.appendChild(Result);
end;

function TStudioMaterial.El(const AId: String): TJSElement;
begin
  Result := document.getElementById('material-' + AId);
end;

function TStudioMaterial.Button(AParent: TJSElement;
  const AText, AAction: String): TJSElement;
begin
  Result := Add(AParent, 'button', AText, '');
  Result.setAttribute('type', 'button');
  Result.setAttribute('data-material-action', AAction);
end;

function TStudioMaterial.Field(AParent: TJSElement;
  const ALabel, AId, AType: String): TJSElement;
var LLabel: TJSElement;
begin
  LLabel := Add(AParent, 'label', ALabel, '');
  Result := Add(LLabel, 'input', '', 'material-' + AId);
  Result.setAttribute('type', AType);
  if AType = 'number' then
  begin
    Result.setAttribute('step', '1');
    Result.setAttribute('inputmode', 'numeric');
  end;
end;

function TStudioMaterial.Select(AParent: TJSElement;
  const ALabel, AId: String; const ALabels, AValues: array of String): TJSElement;
var LLabel, LOption: TJSElement; I: Integer;
begin
  LLabel := Add(AParent, 'label', ALabel, '');
  Result := Add(LLabel, 'select', '', 'material-' + AId);
  for I := 0 to High(ALabels) do
  begin
    LOption := Add(Result, 'option', ALabels[I], '');
    LOption.setAttribute('value', AValues[I]);
  end;
end;

constructor TStudioMaterial.Create(const AFetch: TStudioFetch;
  const AChanged: TStudioChange);
var LRoot, LRow, LBox, LHeader: TJSElement;
begin
  inherited Create;
  FFetch := AFetch;
  FChanged := AChanged;
  LRoot := document.getElementById('musical-material');
  Add(LRoot, 'h3', 'Musical starting points', '');
  FSummary := Add(LRoot, 'p', '', 'material-summary');
  Button(LRoot, 'Edit musical choices', 'edit');
  Add(LRoot, 'p', 'Analyze a passage or imported sound, then choose “Use or edit these suggestions”. Or write a motif yourself.', '').className := 'hint';
  FPanel := Add(document.body, 'dialog', '', 'material-dialog');
  FPanel.className := 'material-dialog';
  FPanel.setAttribute('aria-labelledby', 'material-title');
  LHeader := Add(FPanel, 'div', '', '');
  LHeader.className := 'material-heading';
  LRow := Add(LHeader, 'div', '', '');
  LRow.className := 'guide-dialog-header';
  Add(LRow, 'h2', 'Choose the musical starting point', 'material-title');
  Button(LRow, 'Cancel', 'cancel');
  Add(FPanel, 'p', 'Experimental · Editable pitch and sound with authored accompaniment. A mix is not separated into instruments.', '').className := 'hint';
  LRow := Add(LHeader, 'div', '', '');
  LRow.className := 'material-tabs';
  LRow.setAttribute('role', 'tablist');
  Button(LRow, '1 Tempo & key', 'tab-context');
  Button(LRow, '2 Pitch & part', 'tab-pitch');
  Button(LRow, '3 Sound', 'tab-sound');
  Button(LRow, '4 Source', 'tab-source');
  LBox := Add(FPanel, 'section', '', 'material-context');
  Add(LBox, 'p', 'These choices set the next experiment’s clock and accompaniment. You can still override them in Generate.', '');
  LRow := Add(LBox, 'div', '', '');
  LRow.className := 'range-fields';
  Field(LRow, 'Tempo (BPM, 40–240)', 'tempo', 'number');
  Select(LRow, 'Root', 'tonic',
    ['C', 'C♯', 'D', 'D♯', 'E', 'F', 'F♯', 'G', 'G♯', 'A', 'A♯', 'B'],
    ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9', '10', '11']);
  Select(LRow, 'Accompaniment', 'mode', ['Major', 'Natural minor'], ['major', 'natural_minor']);
  Add(LBox, 'p', '', 'material-decisions').className := 'hint';
  Button(LBox, 'Skip tempo suggestion · use 120 BPM', 'skip-tempo');
  Button(LBox, 'Skip key suggestion · use C major', 'skip-key');
  Button(LBox, 'Next: Pitch & part →', 'tab-pitch');
  LBox := Add(FPanel, 'section', '', 'material-pitch');
  Select(LBox, 'Use this pitch line for', 'part',
    ['Skip pitch · use authored parts', 'Bass', 'Harmony', 'Lead'], ['-1', '0', '1', '2']);
  LRow := Add(LBox, 'div', '', 'material-audio-controls');
  LRow.className := 'range-fields';
  Field(LRow, 'Audio channel (1 = first)', 'channel', 'number');
  Button(LRow, 'Rebuild cells from audio', 'rebuild');
  Add(LBox, 'p', 'Each cell is an eighth note at your chosen tempo. Unknown cells split the motif; rests are silence. Known runs become repeatable motifs. Timing and attacks are proposals.', '').className := 'hint';
  LRow := Add(LBox, 'div', '', '');
  LRow.className := 'source-toolbar';
  Button(LRow, '← Previous cells', 'previous');
  Add(LRow, 'output', '', 'material-page');
  Button(LRow, 'Next cells →', 'next');
  FGrid := Add(LBox, 'div', '', 'material-grid');
  LRow := Add(LBox, 'div', '', '');
  LRow.className := 'range-fields';
  Select(LRow, 'Selected cell', 'kind', ['New note', 'Hold previous note', 'Rest', 'Unknown'],
    ['note', 'hold', 'silence', 'unknown']);
  Field(LRow, 'MIDI note (60 = middle C)', 'note', 'number');
  Field(LRow, 'Velocity (1–127)', 'velocity', 'number');
  LRow := Add(LBox, 'div', '', '');
  LRow.className := 'source-toolbar';
  Button(LRow, '+ 8 empty cells', 'append');
  Button(LRow, 'Remove last cell', 'remove');
  Button(LBox, 'Next: Sound →', 'tab-sound');
  LBox := Add(FPanel, 'section', '', 'material-sound');
  Add(LBox, 'p', 'Shape the sound of one synthesized part.', '').className := 'hint';
  Select(LBox, 'Apply sound controls to', 'sound-part',
    ['Skip sound · keep current instruments', 'Bass', 'Harmony', 'Lead'], ['-1', '0', '1', '2']);
  LRow := Add(LBox, 'div', '', '');
  LRow.className := 'range-fields';
  Field(LRow, 'Low-pass cutoff (Hz, 100–10000)', 'cutoff', 'number');
  Field(LRow, 'Envelope sustain (%, 0–100)', 'sustain', 'number');
  Add(LBox, 'p', 'Cutoff changes brightness. Sustain sets the level while a note is held.', '').className := 'hint';
  Add(LBox, 'p', '', 'material-sound-decision').setAttribute('role', 'status');
  LRow := Add(LBox, 'div', '', '');
  LRow.className := 'source-toolbar';
  Button(LRow, 'Use sound suggestion', 'accept-sound');
  Button(LRow, 'Skip sound', 'skip-sound');
  LRow := Add(LBox, 'details', '', '');
  Add(LRow, 'summary', 'How is this suggested?', '');
  Add(LRow, 'p', 'Twice the measured spectral centroid → cutoff; quiet/peak window loudness → sustain. Edit either value to try something else. This does not identify an instrument or copy its envelope.', '').className := 'hint';
  Button(LBox, 'Next: Source & notes →', 'tab-source');
  LBox := Add(FPanel, 'section', '', 'material-source');
  FSource := Add(LBox, 'p', '', 'material-source-details');
  Add(LBox, 'p', 'The analysis and original source stay unchanged. Generation keeps the analyzed excerpt for Original/Synthesized comparison. Pitch coverage may be shorter than that excerpt.', '').className := 'hint';
  Button(LBox, 'Start fresh without this analysis', 'manual');
  LRow := Add(LBox, 'label', 'Notes (optional)', '');
  Add(LRow, 'textarea', '', 'material-notes').setAttribute('maxlength', '2048');
  FNotice := Add(FPanel, 'p', '', 'material-notice');
  FNotice.setAttribute('role', 'status');
  LRow := Add(FPanel, 'div', '', '');
  LRow.className := 'material-footer';
  Button(LRow, 'Cancel', 'cancel');
  Button(LRow, 'Apply to draft', 'apply').className := 'primary';
  Add(FPanel, 'p', 'Apply edits your draft. Save draft keeps it. Generate makes new audio. Neither Apply nor Save trains or generates.', '').className := 'hint';
  document.addEventListener('click', @Click);
  FPanel.addEventListener('change', @Edit);
  FPanel.addEventListener('cancel', @Cancel);
  FPanel.addEventListener('close', @DialogClosed);
  DrawSummary;
end;

procedure TStudioMaterial.SetEnabled(const AEnabled: Boolean);
begin
  FEnabled := AEnabled;
  TJSHTMLButtonElement(document.querySelector('[data-material-action="edit"]')).disabled := not AEnabled;
end;

procedure TStudioMaterial.Restore(AValue: TJSObject);
begin
  Inc(FEpoch);
  FValue := CopyObject(AValue);
  if TGuideDialog(FPanel).open then Finish;
  DrawSummary;
end;

function TStudioMaterial.Value: TJSObject;
begin
  Result := CopyObject(FValue);
end;

procedure TStudioMaterial.DrawSummary;
const CParts: array[0..2] of String = ('bass', 'harmony', 'lead');
var LPart: Integer; LText: String; LSound: TJSObject;
begin
  LText := 'Authored starter · no recording-derived choices.';
  if FValue <> nil then
  begin
    LText := IntToStr(Trunc(StudioNumber(FValue, 'tempo_bpm'))) + ' BPM · ' +
      StringReplace(StudioText(FValue, 'mode'), '_', ' ', [rfReplaceAll]);
    LPart := Trunc(StudioNumber(FValue, 'part'));
    if LPart >= 0 then LText := LText + ' · pitch cells → ' + CParts[LPart]
    else LText := LText + ' · authored pitched parts';
    if isObject(FValue['sound']) then
    begin
      LSound := TJSObject(FValue['sound']);
      LPart := Trunc(StudioNumber(LSound, 'part'));
      if (LPart >= 0) and (LPart < 3) then
        LText := LText + ' · sound controls → ' + CParts[LPart];
    end;
    if StudioText(FValue, 'analysis_job_id') <> '' then
      LText := LText + ' · linked to audio analysis'
    else LText := LText + ' · manual input';
  end;
  FSummary.textContent := LText;
end;

procedure TStudioMaterial.Open;
begin
  FBusy := False;
  FOrigin := document.activeElement;
  FScrollX := window.scrollX;
  FScrollY := window.scrollY;
  FNotice.textContent := '';
  FCell := 0;
  FPage := 0;
  if not TGuideDialog(FPanel).open then TGuideDialog(FPanel).showModal;
  SetTab('context');
end;

procedure TStudioMaterial.Finish;
begin
  Inc(FEpoch);
  TGuideDialog(FPanel).close;
end;

function TStudioMaterial.DialogClosed(AEvent: TEventListenerEvent): Boolean;
var LPlayers: TJSNodeList; I: Integer;
begin
  Result := False;
  Inc(FEpoch);
  LPlayers := FPanel.querySelectorAll('audio');
  for I := 0 to LPlayers.length - 1 do TJSHTMLAudioElement(LPlayers[I]).pause;
  if (FOrigin <> nil) and document.body.contains(FOrigin) then
    TJSHTMLElement(FOrigin).focus;
  window.scrollTo(FScrollX, FScrollY);
end;

function TStudioMaterial.Cancel(AEvent: TEventListenerEvent): Boolean;
begin
  Result := False;
  AEvent.preventDefault;
  Finish;
end;

procedure TStudioMaterial.SetTab(const ATab: String);
const CNames: array[0..3] of String = ('context', 'pitch', 'sound', 'source');
var LName: String; LButton: TJSElement;
begin
  for LName in CNames do
  begin
    if LName = ATab then El(LName).removeAttribute('hidden')
    else El(LName).setAttribute('hidden', '');
    LButton := FPanel.querySelector('.material-tabs [data-material-action="tab-' + LName + '"]');
    LButton.setAttribute('role', 'tab');
    LButton.setAttribute('aria-selected', BoolToStr(LName = ATab, 'true', 'false'));
    LButton.setAttribute('aria-controls', 'material-' + LName);
    El(LName).setAttribute('role', 'tabpanel');
  end;
end;

function TStudioMaterial.Number(const AId: String; AMin, AMax: Integer): Integer;
begin
  if not TryStrToInt(TJSHTMLInputElement(El(AId)).value, Result) or
    (Result < AMin) or (Result > AMax) then
    raise Exception.Create('Use ' + IntToStr(AMin) + '–' + IntToStr(AMax) + ' for ' + AId + '.');
end;

procedure TStudioMaterial.Draw;
var LSource, LSound: TJSObject; LRate: Double;
begin
  if FDraft = nil then Exit;
  TJSHTMLInputElement(El('tempo')).value := FloatToStr(StudioNumber(FDraft, 'tempo_bpm'));
  TJSHTMLSelectElement(El('tonic')).value := FloatToStr(StudioNumber(FDraft, 'tonic'));
  TJSHTMLSelectElement(El('mode')).value := StudioText(FDraft, 'mode');
  TJSHTMLSelectElement(El('part')).value := FloatToStr(StudioNumber(FDraft, 'part'));
  TJSHTMLInputElement(El('channel')).value := FloatToStr(StudioNumber(FDraft, 'channel') + 1);
  TJSHTMLInputElement(El('channel')).disabled := StudioText(FDraft, 'analysis_job_id') = '';
  if StudioText(FDraft, 'analysis_job_id') = '' then
    El('audio-controls').setAttribute('hidden', '')
  else El('audio-controls').removeAttribute('hidden');
  TJSHTMLTextAreaElement(El('notes')).value := StudioText(FDraft, 'notes');
  if not isObject(FDraft['sound']) then
  begin
    LSound := TJSObject.new;
    LSound['part'] := -1; LSound['cutoff_hz'] := 1800;
    LSound['sustain_percent'] := 70; LSound['decision'] := 'bypassed';
    LSound['available'] := False;
    FDraft['sound'] := LSound;
  end;
  LSound := TJSObject(FDraft['sound']);
  TJSHTMLSelectElement(El('sound-part')).value := FloatToStr(StudioNumber(LSound, 'part'));
  TJSHTMLInputElement(El('cutoff')).value := FloatToStr(StudioNumber(LSound, 'cutoff_hz'));
  TJSHTMLInputElement(El('sustain')).value := FloatToStr(StudioNumber(LSound, 'sustain_percent'));
  DrawSoundState;
  El('decisions').textContent := 'Tempo: ' + StudioText(FDraft, 'tempo_decision') +
    ' · Key: ' + StudioText(FDraft, 'key_decision');
  LSource := TJSObject(FDraft['source']);
  if StudioText(LSource, 'kind') = 'manual' then
    FSource.textContent := 'Manual input · no recording or inferred accuracy claim.'
  else
  begin
    LRate := StudioNumber(LSource, 'sample_rate');
    FSource.textContent := StudioText(LSource, 'title') + ' · ' +
      StudioTime(StudioNumber(LSource, 'start_frame') / LRate) + '–' +
      StudioTime(StudioNumber(LSource, 'end_frame') / LRate) +
      ' · ' + StudioText(LSource, 'license') + ' · ' + StudioText(LSource, 'provenance');
  end;
  DrawCells;
end;

procedure TStudioMaterial.DrawSoundState;
var LSound: TJSObject; LText: String;
begin
  LSound := TJSObject(FDraft['sound']);
  case StudioText(LSound, 'decision') of
    'accepted': LText := 'Using the analyzed sound suggestion.';
    'corrected': LText := 'Using your edited sound controls.';
    'manual': LText := 'Using your own sound controls.';
  else LText := 'Sound controls are skipped.';
  end;
  if not Boolean(LSound['available']) and (StudioNumber(LSound, 'part') < 0) then
    LText := LText + ' Choose a part to enter your own controls.';
  El('sound-decision').textContent := LText;
  TJSHTMLButtonElement(FPanel.querySelector('[data-material-action="accept-sound"]')).disabled :=
    not Boolean(LSound['available']);
end;

procedure TStudioMaterial.DrawCells;
var LCells: TJSArray; LRow: TJSObject; LButton: TJSElement; I: Integer; LText: String;
const CNotes: array[0..11] of String =
  ('C', 'C♯', 'D', 'D♯', 'E', 'F', 'F♯', 'G', 'G♯', 'A', 'A♯', 'B');
begin
  LCells := TJSArray(FDraft['pattern']);
  FCell := Max(0, Min(FCell, LCells.length - 1));
  FPage := Max(0, Min(FPage, (Max(1, LCells.length) - 1) div 16));
  FGrid.innerHTML := '';
  El('page').textContent := IntToStr(LCells.length) + ' cells · ' +
    IntToStr(FPage * 16 + 1) + '–' + IntToStr(Min(LCells.length, (FPage + 1) * 16));
  for I := FPage * 16 to Min(LCells.length, (FPage + 1) * 16) - 1 do
  begin
    LRow := TJSObject(LCells[I]);
    LText := StudioText(LRow, 'kind');
    if LText = 'pitch' then
    begin
      LText := CNotes[Trunc(StudioNumber(LRow, 'note')) mod 12] +
        IntToStr(Trunc(StudioNumber(LRow, 'note')) div 12 - 1);
      if not Boolean(LRow['attack']) then LText := '↔ ' + LText;
    end
    else if LText = 'silence' then LText := 'Rest'
    else LText := '?';
    LButton := Button(FGrid, IntToStr(I + 1) + ' · ' + LText, 'cell');
    LButton.setAttribute('data-cell', IntToStr(I));
    LButton.setAttribute('aria-pressed', BoolToStr(I = FCell, 'true', 'false'));
  end;
  if LCells.length = 0 then
    Add(FGrid, 'p', 'No pitch cells. Add eight to write a motif, or skip pitch above.', '');
  DrawCell;
end;

procedure TStudioMaterial.DrawCell;
var LCells: TJSArray; LRow: TJSObject; LKind: String;
begin
  LCells := TJSArray(FDraft['pattern']);
  if LCells.length = 0 then Exit;
  LRow := TJSObject(LCells[FCell]);
  LKind := StudioText(LRow, 'kind');
  if LKind = 'pitch' then
  begin
    LKind := 'note';
    if not Boolean(LRow['attack']) then LKind := 'hold';
  end;
  TJSHTMLSelectElement(El('kind')).value := LKind;
  if StudioText(LRow, 'kind') = 'pitch' then
  begin
    TJSHTMLInputElement(El('note')).value := FloatToStr(StudioNumber(LRow, 'note'));
    TJSHTMLInputElement(El('velocity')).value := FloatToStr(StudioNumber(LRow, 'velocity'));
  end
  else
  begin
    TJSHTMLInputElement(El('note')).value := '60';
    TJSHTMLInputElement(El('velocity')).value := '80';
  end;
end;

procedure TStudioMaterial.MarkPitch;
begin
  FEditedPattern := True;
  if StudioText(FDraft, 'analysis_job_id') = '' then FDraft['pitch_decision'] := 'manual'
  else FDraft['pitch_decision'] := 'corrected';
end;

procedure TStudioMaterial.Load(const AJob: String; const ARebuild, ASoundOnly: Boolean); async;
var LResponse: TJSResponse; LNew, LSound: TJSObject; LPath: String; LEpoch, LPart: Integer;
begin
  Inc(FEpoch);
  LEpoch := FEpoch;
  FBusy := True;
  FNotice.textContent := 'Preparing musical choices…';
  try
    LPath := '/api/studio/musical-material';
    if AJob <> '' then
    begin
      LPath := LPath + '?id=' + encodeURIComponent(AJob);
      if ARebuild and not ASoundOnly then
        LPath := LPath + '&tempo=' + IntToStr(Number('tempo', 40, 240)) +
          '&channel=' + IntToStr(Number('channel', 1, 32) - 1)
      else LPath := LPath + '&tempo=0&channel=0';
    end;
    LResponse := TJSResponse(await(JSValue, AwaitStudioPromise(FFetch(LPath, 'GET', ''), 30)));
    if LResponse.status <> 200 then
      raise Exception.Create(await(String, LResponse.text()));
    LNew := await(TJSObject, LResponse.json());
    if LEpoch <> FEpoch then Exit;
    if LResponse.status <> 200 then
      raise Exception.Create(StudioText(LNew, 'message'));
    if ASoundOnly then
    begin
      LPart := Trunc(StudioNumber(TJSObject(FDraft['sound']), 'part'));
      if LPart < 0 then LPart := Trunc(StudioNumber(FDraft, 'part'));
      if LPart < 0 then LPart := 2;
      LSound := CopyObject(TJSObject(LNew['sound']));
      if not Boolean(LSound['available']) then
        raise Exception.Create('This analysis has no sound suggestion. Enter your own controls instead.');
      LSound['part'] := LPart;
      LSound['decision'] := 'accepted';
      FDraft['sound'] := LSound;
    end
    else if ARebuild then
    begin
      FDraft['pattern'] := LNew['pattern'];
      FDraft['channel'] := LNew['channel'];
      FDraft['tempo_bpm'] := LNew['tempo_bpm'];
      FDraft['tempo_decision'] := LNew['tempo_decision'];
      MarkPitch;
    end
    else
    begin
      FDraft := LNew;
      FEditedPattern := False;
    end;
    if not ASoundOnly then
    begin
      FCell := 0;
      FPage := 0;
    end;
    Draw;
    FNotice.textContent := 'Choose a part to use pitch cells, or skip them. Apply keeps changes in your draft.';
    if ASoundOnly then
      FNotice.textContent := 'Sound suggestion selected. Pitch, tempo and key are unchanged. Apply keeps it in your draft.';
  except
    on E: Exception do
      if LEpoch = FEpoch then FNotice.textContent := E.Message;
  else
    if LEpoch = FEpoch then
      FNotice.textContent := 'Musical choices could not be loaded. Close and retry; your saved project is unchanged.';
  end;
  if LEpoch = FEpoch then FBusy := False;
end;

function TStudioMaterial.Edit(AEvent: TEventListenerEvent): Boolean;
var LId, LKind, LDecision: String; LCells: TJSArray; LRow, LPrev, LSound: TJSObject;
begin
  Result := False;
  if FBusy or (FDraft = nil) then Exit;
  LId := TJSElement(AEvent.target).id;
  try
    LDecision := 'manual';
    if StudioText(FDraft, 'analysis_job_id') <> '' then LDecision := 'corrected';
    if LId = 'material-tempo' then
    begin
      FDraft['tempo_bpm'] := Number('tempo', 40, 240);
      FDraft['tempo_decision'] := LDecision;
      if TJSArray(FDraft['pattern']).length > 0 then MarkPitch;
      FNotice.textContent := 'Tempo changed. Rebuild pitch cells to sample the audio on this clock, or keep the edited motif.';
    end
    else if (LId = 'material-tonic') or (LId = 'material-mode') then
    begin
      FDraft['tonic'] := Number('tonic', 0, 11);
      FDraft['mode'] := TJSHTMLSelectElement(El('mode')).value;
      FDraft['key_decision'] := LDecision;
    end
    else if LId = 'material-part' then
    begin
      FDraft['part'] := Number('part', -1, 2);
      if StudioNumber(FDraft, 'part') >= 0 then
      begin
        if FEditedPattern or (StudioText(FDraft, 'analysis_job_id') = '') then MarkPitch
        else FDraft['pitch_decision'] := 'accepted';
      end;
    end
    else if (LId = 'material-sound-part') or (LId = 'material-cutoff') or
      (LId = 'material-sustain') then
    begin
      LSound := TJSObject(FDraft['sound']);
      LSound['part'] := Number('sound-part', -1, 2);
      LSound['cutoff_hz'] := Number('cutoff', 100, 10000);
      LSound['sustain_percent'] := Number('sustain', 0, 100);
      LSound['decision'] := LDecision;
      if not Boolean(LSound['available']) then LSound['decision'] := 'manual';
      if StudioNumber(LSound, 'part') < 0 then LSound['decision'] := 'bypassed';
      DrawSoundState;
    end
    else if LId = 'material-notes' then
      FDraft['notes'] := TJSHTMLTextAreaElement(El('notes')).value
    else if (LId = 'material-kind') or (LId = 'material-note') or
      (LId = 'material-velocity') then
    begin
      LCells := TJSArray(FDraft['pattern']);
      if LCells.length = 0 then Exit;
      LKind := TJSHTMLSelectElement(El('kind')).value;
      LRow := TJSObject.new;
      LRow['kind'] := LKind;
      LRow['note'] := -1;
      LRow['velocity'] := 0;
      LRow['attack'] := False;
      if (LKind = 'note') or (LKind = 'hold') then
      begin
        LRow['kind'] := 'pitch';
        LRow['note'] := Number('note', 0, 127);
        LRow['velocity'] := Number('velocity', 1, 127);
        LRow['attack'] := LKind = 'note';
        if (LKind = 'hold') and (FCell > 0) then
        begin
          LPrev := TJSObject(LCells[FCell - 1]);
          if StudioText(LPrev, 'kind') <> 'pitch' then
            raise Exception.Create('A hold needs a preceding pitched note.');
          LRow['note'] := LPrev['note'];
          LRow['velocity'] := LPrev['velocity'];
        end;
      end;
      LCells[FCell] := LRow;
      MarkPitch;
      DrawCells;
    end;
  except
    on E: Exception do FNotice.textContent := E.Message;
  end;
end;

function TStudioMaterial.Click(AEvent: TJSMouseEvent): Boolean;
var
  LButton: TJSElement;
  LAction, LJob: String;
  LCells: TJSArray;
  LRow, LSound: TJSObject;
  LPattern: TPitchPattern;
  I, LCount: Integer;
begin
  Result := False;
  LButton := TJSElement(AEvent.target).closest('[data-material-action],[data-musical-job]');
  if (LButton = nil) or not FEnabled then Exit;
  LJob := LButton.getAttribute('data-musical-job');
  LAction := LButton.getAttribute('data-material-action');
  try
    if LButton.hasAttribute('data-musical-job') then
    begin
      if TGuideDialog(FPanel).open then Exit;
      Open;
      Load(LJob, False);
    end
    else if LAction = 'edit' then
    begin
      Open;
      FDraft := CopyObject(FValue);
      { A saved bypass can retain edited cells. Only a fresh analysis proposal
        may be promoted to accepted without re-checking its pitch observation. }
      FEditedPattern := StudioText(FDraft, 'pitch_decision') <> 'accepted';
      if FDraft = nil then Load('', False)
      else Draw;
    end
    else if LAction = 'cancel' then Finish
    else if FBusy or (FDraft = nil) then Exit
    else if Copy(LAction, 1, 4) = 'tab-' then SetTab(Copy(LAction, 5, MaxInt))
    else if LAction = 'manual' then Load('', False)
    else if LAction = 'accept-sound' then
    begin
      LSound := TJSObject(FDraft['sound']);
      if not Boolean(LSound['available']) then
        raise Exception.Create('Analyze a nonsilent recording first, or enter your own sound controls.');
      { Reload the actual proposal; edited numbers cannot be labeled accepted. }
      Load(StudioText(FDraft, 'analysis_job_id'), True, True);
    end
    else if LAction = 'skip-sound' then
    begin
      LSound := TJSObject(FDraft['sound']);
      LSound['part'] := -1; LSound['decision'] := 'bypassed';
      Draw;
    end
    else if LAction = 'rebuild' then
    begin
      if StudioText(FDraft, 'analysis_job_id') = '' then
        raise Exception.Create('Analyze a recording first, or add cells to write a motif.');
      Load(StudioText(FDraft, 'analysis_job_id'), True);
    end
    else if LAction = 'skip-tempo' then
    begin
      FDraft['tempo_bpm'] := 120;
      FDraft['tempo_decision'] := 'bypassed';
      if TJSArray(FDraft['pattern']).length > 0 then MarkPitch;
      Draw;
    end
    else if LAction = 'skip-key' then
    begin
      FDraft['tonic'] := 0;
      FDraft['mode'] := 'major';
      FDraft['key_decision'] := 'bypassed';
      Draw;
    end
    else if LAction = 'apply' then
    begin
      FDraft['tempo_bpm'] := Number('tempo', 40, 240);
      LSound := TJSObject(FDraft['sound']);
      LSound['part'] := Number('sound-part', -1, 2);
      LSound['cutoff_hz'] := Number('cutoff', 100, 10000);
      LSound['sustain_percent'] := Number('sustain', 0, 100);
      FDraft['notes'] := TJSHTMLTextAreaElement(El('notes')).value;
      LCells := TJSArray(FDraft['pattern']);
      SetLength(LPattern, LCells.length);
      for I := 0 to LCells.length - 1 do
      begin
        LRow := TJSObject(LCells[I]);
        LPattern[I] := Default(TPitchPatternCell);
        LPattern[I].Kind := pskUnknown;
        case StudioText(LRow, 'kind') of
          'pitch': LPattern[I].Kind := pskPitch;
          'silence': LPattern[I].Kind := pskSilence;
        end;
        LPattern[I].Note := Trunc(StudioNumber(LRow, 'note'));
        LPattern[I].Velocity := Trunc(StudioNumber(LRow, 'velocity'));
        LPattern[I].Attack := Boolean(LRow['attack']);
      end;
      if Length(LPattern) > 0 then ValidatePitchPattern(LPattern);
      if (StudioNumber(FDraft, 'part') >= 0) and (LCells.length = 0) then
        raise Exception.Create('Add pitch cells or choose Skip pitch.');
      if StudioNumber(FDraft, 'part') < 0 then FDraft['pitch_decision'] := 'bypassed';
      FValue := CopyObject(FDraft);
      DrawSummary;
      Finish;
      FChanged;
    end
    else
    begin
      LCells := TJSArray(FDraft['pattern']);
      if LAction = 'cell' then
      begin
        FCell := StrToInt(LButton.getAttribute('data-cell'));
        DrawCells;
      end
      else if LAction = 'previous' then
      begin
        Dec(FPage);
        DrawCells;
      end
      else if LAction = 'next' then
      begin
        Inc(FPage);
        DrawCells;
      end
      else if LAction = 'append' then
      begin
        LCount := Min(8, MaximumPitchPatternCells - LCells.length);
        if LCount = 0 then raise Exception.Create('The motif supports at most 256 cells.');
        FCell := LCells.length;
        FPage := FCell div 16;
        for I := 1 to LCount do
        begin
          LRow := TJSObject.new;
          LRow['kind'] := 'unknown';
          LRow['note'] := -1;
          LRow['velocity'] := 0;
          LRow['attack'] := False;
          LCells.push(LRow);
        end;
        MarkPitch;
        DrawCells;
      end
      else if LAction = 'remove' then
      begin
        LCells.pop;
        MarkPitch;
        DrawCells;
      end;
    end;
  except
    on E: Exception do FNotice.textContent := E.Message;
  end;
end;

end.
