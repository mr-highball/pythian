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
unit pythian.studio.effects;

{$mode delphi}
{$H+}

interface

uses
  JS,
  Web,
  SysUtils,
  Types,
  pythian.studio.sources;

type
  TStudioEffectSelection = function: TJSObject of object;

  TStudioEffects = class
  private
    FFetch: TStudioFetch;
    FSelection: TStudioEffectSelection;
    FSaved: TStudioChange;
    FRack: TJSArray;
    FSerial: Integer;
    FSelectionKey: String;
    FVersion: Integer;
    FPreviewVersion: Integer;
    FPreviewId: String;
    FTransport: TJSObject;
    FPending: Boolean;
    FJob: TJSObject;
    FBusy: Boolean;
    FEpoch: Integer;
    FTimer: NativeInt;
    FPollTimer: NativeInt;
    FWatchTimer: NativeInt;
    FStarted: Double;
    FNotified: String;
    FPlayer: TJSHTMLAudioElement;
    function El(const AId: String): TJSElement;
    function Add(AParent: TJSElement; const ATag, AText, AClass: String): TJSElement;
    procedure Button(AParent: TJSElement; const AText, AAction: String);
    procedure Layout;
    procedure DrawRack;
    procedure Parameter(AParent: TJSElement; ARow: TJSObject;
      const AKey, ALabel: String);
    procedure Notice(const AText: String; const AError: Boolean = False);
    procedure Invalidate;
    procedure StopAudio;
    procedure WatchSelection;
    procedure UpdateControls;
    procedure DrawJob;
    function Number(ARow: TJSObject; const AKey: String;
      AMinimum, AMaximum: Double): Double;
    function RackRequest(ARate: Double): TJSArray;
    function NewId: String;
    function Json(const APath, AMethod, ABody: String): TJSObject; async;
    function BeginAction: Integer;
    procedure EndAction(AEpoch: Integer);
    function Matches(AJob: TJSObject): Boolean;
    procedure Accept(AJob: TJSObject);
    procedure Submit(ARequest: TJSObject); async;
    procedure Confirm; async;
    procedure Poll; async;
    procedure Cancel; async;
    procedure Preview;
    procedure SaveClip;
    function Edit(AEvent: TEventListenerEvent): Boolean;
    function Click(AEvent: TJSMouseEvent): Boolean;
    function Playing(AEvent: TEventListenerEvent): Boolean;
    function Leaving(AEvent: TEventListenerEvent): Boolean;
    function Returning(AEvent: TEventListenerEvent): Boolean;
  public
    constructor Create(const AFetch: TStudioFetch;
      const ASelection: TStudioEffectSelection; const ASaved: TStudioChange);
    destructor Destroy; override;
  end;

implementation

type
  EStudioEffectHttp = class(Exception)
  public
    Status: Integer;
  end;

function CopyObject(AObject: TJSObject): TJSObject;
begin
  Result := TJSObject(TJSJSON.parse(TJSJSON.stringify(AObject)));
end;

function EffectName(const AKind: String): String;
begin
  Result := AKind;
  if AKind = 'gain' then
  begin
    Result := 'Gain';
  end
  else if AKind = 'lowpass' then
  begin
    Result := 'Low-pass filter';
  end
  else if AKind = 'highpass' then
  begin
    Result := 'High-pass filter';
  end
  else if AKind = 'compressor' then
  begin
    Result := 'Compressor';
  end
  else if AKind = 'limiter' then
  begin
    Result := 'Limiter';
  end;
end;

function TStudioEffects.El(const AId: String): TJSElement;
begin
  Result := document.getElementById(AId);
end;

function TStudioEffects.Add(AParent: TJSElement;
  const ATag, AText, AClass: String): TJSElement;
begin
  Result := document.createElement(ATag);
  Result.textContent := AText;
  Result.className := AClass;
  AParent.appendChild(Result);
end;

procedure TStudioEffects.Button(AParent: TJSElement; const AText, AAction: String);
var
  LButton: TJSElement;
begin
  LButton := Add(AParent, 'button', AText, '');
  LButton.setAttribute('type', 'button');
  LButton.setAttribute('data-effect-action', AAction);
  LButton.addEventListener('click', @Click);
end;

procedure TStudioEffects.Layout;
var
  LRoot: TJSElement;
  LRow: TJSElement;
  LLabel: TJSElement;
  LControl: TJSElement;
  LOption: TJSElement;
  LKind: String;
  LKinds: array of String;
  LDetails: TJSElement;
begin
  LRoot := El('studio-effects');
  Add(LRoot, 'h2', 'Effects and new clips', '');
  LControl := Add(LRoot, 'p', 'Select a source passage to preview.', 'hint');
  LControl.id := 'effects-selection';
  LRow := Add(LRoot, 'div', '', 'source-toolbar');
  LLabel := Add(LRow, 'label', 'Add an effect', '');
  LControl := Add(LLabel, 'select', '', '');
  LControl.id := 'effects-kind';
  LKinds := ['gain', 'lowpass', 'highpass', 'compressor', 'limiter'];
  for LKind in LKinds do
  begin
    LOption := Add(LControl, 'option', EffectName(LKind), '');
    LOption.setAttribute('value', LKind);
  end;
  Button(LRow, 'Add effect', 'add');
  LControl := Add(LRoot, 'div', '', 'tracks');
  LControl.id := 'effects-rack';
  Add(LRoot, 'p', 'Effects run from top to bottom. Originals stay unchanged.', 'hint');
  LRow := Add(LRoot, 'div', '', 'source-toolbar');
  Button(LRow, 'Preview passage', 'preview');
  Button(LRow, 'Check job status', 'refresh');
  Button(LRow, 'Confirm submission', 'confirm');
  Button(LRow, 'Cancel job', 'cancel');
  LControl := Add(LRoot, 'p', '', 'notice');
  LControl.id := 'effects-notice';
  LControl.setAttribute('role', 'status');
  LControl.setAttribute('aria-live', 'polite');
  LControl := Add(LRoot, 'p', '', 'hint');
  LControl.id := 'effects-status';
  FPlayer := TJSHTMLAudioElement(Add(LRoot, 'audio', '', ''));
  FPlayer.controls := True;
  FPlayer.preload := 'none';
  FPlayer.setAttribute('aria-label', 'Current effects preview');
  FPlayer.setAttribute('hidden', '');
  FPlayer.addEventListener('play', @Playing);
  LRow := Add(LRoot, 'div', '', 'range-fields');
  LLabel := Add(LRow, 'label', 'Collection for the new clip', '');
  LControl := Add(LLabel, 'input', '', '');
  LControl.id := 'effects-collection';
  LControl.setAttribute('value', 'Edited clips');
  LControl.setAttribute('maxlength', '96');
  LControl.setAttribute('type', 'text');
  LLabel := Add(LRow, 'label', 'New clip title', '');
  LControl := Add(LLabel, 'input', '', '');
  LControl.id := 'effects-title';
  LControl.setAttribute('maxlength', '128');
  LControl.setAttribute('type', 'text');
  Button(LRoot, 'Save as new clip', 'save');
  LDetails := Add(LRoot, 'details', '', 'advanced');
  Add(LDetails, 'summary', 'Preview details', '');
  Add(LDetails, 'p', 'Up to 30 seconds and 2,000,000 frames; eight effects. ' +
    'The preview starts with reset effect state and ends at the selected range. ' +
    'Saving preserves its recipe and source lineage; it does not start training.', 'hint');
  LControl := Add(LDetails, 'p', '', 'hint batch-identity');
  LControl.id := 'effects-identity';
end;

procedure TStudioEffects.Parameter(AParent: TJSElement; ARow: TJSObject;
  const AKey, ALabel: String);
var
  LLabel: TJSElement;
  LInput: TJSElement;
begin
  LLabel := Add(AParent, 'label', ALabel, '');
  LInput := Add(LLabel, 'input', '', '');
  LInput.setAttribute('type', 'text');
  LInput.setAttribute('inputmode', 'decimal');
  LInput.setAttribute('maxlength', '16');
  LInput.setAttribute('data-row', StudioText(ARow, 'ui_id'));
  LInput.setAttribute('data-key', AKey);
  LInput.setAttribute('value', StudioText(ARow, AKey));
  LInput.addEventListener('input', @Edit);
end;

procedure TStudioEffects.DrawRack;
var
  LRoot: TJSElement;
  LCard: TJSElement;
  LRow: TJSElement;
  LLabel: TJSElement;
  LCheck: TJSElement;
  LDetails: TJSElement;
  LParams: TJSElement;
  LEffect: TJSObject;
  LKind: String;
  LId: String;
  LIndex: Integer;
begin
  LRoot := El('effects-rack');
  LRoot.innerHTML := '';
  if FRack.length = 0 then
  begin
    Add(LRoot, 'p', 'No effects yet. Preview without effects or add a stage.', 'hint');
  end;
  for LIndex := 0 to FRack.length - 1 do
  begin
    LEffect := TJSObject(FRack[LIndex]);
    LKind := StudioText(LEffect, 'kind');
    LId := StudioText(LEffect, 'ui_id');
    LCard := Add(LRoot, 'div', '', 'track');
    Add(LCard, 'h3', IntToStr(LIndex + 1) + '. ' + EffectName(LKind), '');
    LRow := Add(LCard, 'div', '', 'source-toolbar');
    LLabel := Add(LRow, 'label', '', '');
    LCheck := Add(LLabel, 'input', '', '');
    LCheck.setAttribute('type', 'checkbox');
    LCheck.setAttribute('data-row', LId);
    LCheck.setAttribute('data-key', 'bypass');
    TJSHTMLInputElement(LCheck).checked := Boolean(LEffect['bypass']);
    LCheck.addEventListener('change', @Edit);
    Add(LLabel, 'span', 'Bypass', '');
    Button(LRow, 'Move up', 'up:' + LId);
    TJSHTMLButtonElement(LRow.lastElementChild).disabled := LIndex = 0;
    Button(LRow, 'Move down', 'down:' + LId);
    TJSHTMLButtonElement(LRow.lastElementChild).disabled := LIndex = FRack.length - 1;
    Button(LRow, 'Remove', 'remove:' + LId);
    LDetails := Add(LCard, 'details', '', 'advanced');
    Add(LDetails, 'summary', 'Parameters', '');
    LParams := Add(LDetails, 'div', '', 'range-fields');
    if LKind = 'gain' then
    begin
      Parameter(LParams, LEffect, 'gain_db', 'Gain (−48 to +12 dB)');
    end
    else if (LKind = 'lowpass') or (LKind = 'highpass') then
    begin
      Parameter(LParams, LEffect, 'frequency_hz', 'Cutoff (Hz, below half the source rate)');
      Parameter(LParams, LEffect, 'q', 'Resonance Q (0.1–10)');
    end
    else if LKind = 'compressor' then
    begin
      Parameter(LParams, LEffect, 'threshold_db', 'Threshold (−60 to 0 dB)');
      Parameter(LParams, LEffect, 'ratio', 'Ratio (1–20)');
      Parameter(LParams, LEffect, 'attack_ms', 'Attack (0–200 ms)');
      Parameter(LParams, LEffect, 'release_ms', 'Release (1–2,000 ms)');
      Parameter(LParams, LEffect, 'makeup_db', 'Makeup gain (0–12 dB)');
    end
    else if LKind = 'limiter' then
    begin
      Parameter(LParams, LEffect, 'ceiling_db', 'Ceiling (−24 to 0 dB)');
      Parameter(LParams, LEffect, 'release_ms', 'Release (1–2,000 ms)');
    end;
  end;
end;

procedure TStudioEffects.Notice(const AText: String; const AError: Boolean);
begin
  El('effects-notice').textContent := AText;
  if AError then
  begin
    El('effects-notice').className := 'notice error';
  end
  else
  begin
    El('effects-notice').className := 'notice';
  end;
end;

procedure TStudioEffects.StopAudio;
begin
  FPlayer.pause;
  FPlayer.removeAttribute('src');
  FPlayer.removeAttribute('data-job');
  FPlayer.load;
  FPlayer.setAttribute('hidden', '');
end;

procedure TStudioEffects.Invalidate;
begin
  Inc(FVersion);
  FPreviewId := '';
  StopAudio;
  UpdateControls;
end;

procedure TStudioEffects.WatchSelection;
var
  LSelection: TJSObject;
  LKey: String;
begin
  LSelection := FSelection();
  LKey := TJSJSON.stringify(LSelection);
  if LKey <> FSelectionKey then
  begin
    FSelectionKey := LKey;
    Invalidate;
    if LSelection = nil then
    begin
      El('effects-selection').textContent := 'Select a source passage to preview.';
    end
    else
    begin
      El('effects-selection').textContent := StudioText(LSelection, 'title') + ' · ' +
        StudioTime((StudioNumber(LSelection, 'end_frame') -
        StudioNumber(LSelection, 'start_frame')) / StudioNumber(LSelection, 'sample_rate'));
    end;
  end;
end;

procedure TStudioEffects.UpdateControls;
var
  LButtons: TJSNodeList;
  LButton: TJSHTMLButtonElement;
  LAction: String;
  LIndex: Integer;
  LActive: Boolean;
begin
  LActive := (StudioText(FJob, 'status') = 'queued') or
    (StudioText(FJob, 'status') = 'running');
  LButtons := El('studio-effects').querySelectorAll('button[data-effect-action]');
  for LIndex := 0 to LButtons.length - 1 do
  begin
    LButton := TJSHTMLButtonElement(LButtons[LIndex]);
    LAction := LButton.getAttribute('data-effect-action');
    if LAction = 'preview' then
    begin
      LButton.disabled := FBusy or FPending or LActive or (FSelection() = nil);
    end
    else if LAction = 'save' then
    begin
      LButton.disabled := FBusy or FPending or LActive or (FPreviewId = '') or
        (FPreviewVersion <> FVersion);
    end
    else if LAction = 'add' then
    begin
      LButton.disabled := FRack.length >= 8;
    end
    else if LAction = 'confirm' then
    begin
      LButton.disabled := FBusy;
      if FPending then
      begin
        LButton.removeAttribute('hidden');
      end
      else
      begin
        LButton.setAttribute('hidden', '');
      end;
    end
    else if LAction = 'cancel' then
    begin
      LButton.disabled := FBusy or FPending or not LActive;
      if LActive then
      begin
        LButton.removeAttribute('hidden');
      end
      else
      begin
        LButton.setAttribute('hidden', '');
      end;
    end
    else if LAction = 'refresh' then
    begin
      LButton.disabled := FBusy or FPending or (FJob = nil);
    end;
  end;
end;

function TStudioEffects.Number(ARow: TJSObject; const AKey: String;
  AMinimum, AMaximum: Double): Double;
var
  LText: String;
  LIndex: Integer;
  LDots: Integer;
  LDigits: Integer;
  LSettings: TFormatSettings;

  procedure Reject(const AMessage: String);
  var
    LInput: TJSElement;
  begin
    LInput := El('effects-rack').querySelector('input[data-row="' +
      StudioText(ARow, 'ui_id') + '"][data-key="' + AKey + '"]');
    if LInput <> nil then
    begin
      LInput.setAttribute('aria-invalid', 'true');
      LInput.parentElement.parentElement.parentElement.setAttribute('open', '');
      TJSHTMLInputElement(LInput).focus;
    end;
    raise Exception.Create(AMessage + StringReplace(AKey, '_', ' ', [rfReplaceAll]) + '.');
  end;

begin
  LText := Trim(StudioText(ARow, AKey));
  LDots := 0;
  LDigits := 0;
  for LIndex := 1 to Length(LText) do
  begin
    if LText[LIndex] in ['0'..'9'] then
    begin
      Inc(LDigits);
    end
    else if LText[LIndex] = '.' then
    begin
      Inc(LDots);
    end
    else if not ((LText[LIndex] = '-') and (LIndex = 1)) then
    begin
      Reject('Use a decimal number for ');
    end;
  end;
  LSettings := FormatSettings;
  LSettings.DecimalSeparator := '.';
  LSettings.ThousandSeparator := #0;
  if (LDigits = 0) or (LDots > 1) or
    not TryStrToFloat(LText, Result, LSettings) or
    not ((Result >= AMinimum) and (Result <= AMaximum)) then
  begin
    Reject('Check the allowed range for ');
  end;
end;

function TStudioEffects.RackRequest(ARate: Double): TJSArray;
var
  LStored: TJSObject;
  LRow: TJSObject;
  LKind: String;
  LFrequency: Double;
  LIndex: Integer;
begin
  Result := TJSArray.new;
  for LIndex := 0 to FRack.length - 1 do
  begin
    LStored := TJSObject(FRack[LIndex]);
    LKind := StudioText(LStored, 'kind');
    LRow := TJSObject.new;
    LRow['kind'] := LKind;
    LRow['bypass'] := Boolean(LStored['bypass']);
    if LKind = 'gain' then
    begin
      LRow['gain_db'] := Number(LStored, 'gain_db', -48, 12);
    end
    else if (LKind = 'lowpass') or (LKind = 'highpass') then
    begin
      LFrequency := Number(LStored, 'frequency_hz', 20, 20000);
      if LFrequency >= ARate / 2 then
      begin
        raise Exception.Create('Filter cutoff must be below half the source sample rate.');
      end;
      LRow['frequency_hz'] := LFrequency;
      LRow['q'] := Number(LStored, 'q', 0.1, 10);
    end
    else if LKind = 'compressor' then
    begin
      LRow['threshold_db'] := Number(LStored, 'threshold_db', -60, 0);
      LRow['ratio'] := Number(LStored, 'ratio', 1, 20);
      LRow['attack_ms'] := Number(LStored, 'attack_ms', 0, 200);
      LRow['release_ms'] := Number(LStored, 'release_ms', 1, 2000);
      LRow['makeup_db'] := Number(LStored, 'makeup_db', 0, 12);
    end
    else if LKind = 'limiter' then
    begin
      LRow['ceiling_db'] := Number(LStored, 'ceiling_db', -24, 0);
      LRow['release_ms'] := Number(LStored, 'release_ms', 1, 2000);
    end;
    Result.push(LRow);
  end;
end;

function TStudioEffects.NewId: String;
begin
  Result := 'effect-' + IntToStr(TJSDate.now) + '-' + IntToStr(Random(1000000000));
end;

function TStudioEffects.Json(const APath, AMethod, ABody: String): TJSObject; async;
var
  LResponse: TJSResponse;
  LMessage: String;
  LError: EStudioEffectHttp;
begin
  LResponse := await(TJSResponse, FFetch(APath, AMethod, ABody));
  if (LResponse.status <> 200) and (LResponse.status <> 202) then
  begin
    LMessage := Copy(Trim(await(String, LResponse.text())), 1, 256);
    if LMessage = '' then
    begin
      LMessage := 'The effects request was not accepted.';
    end;
    LError := EStudioEffectHttp.Create(LMessage);
    LError.Status := LResponse.status;
    raise LError;
  end;
  Result := await(TJSObject, LResponse.json());
end;

function TStudioEffects.BeginAction: Integer;
var
  LEpoch: Integer;
begin
  Inc(FEpoch);
  LEpoch := FEpoch;
  Result := LEpoch;
  FBusy := True;
  UpdateControls;
  FTimer := window.setTimeout(
    procedure()
    begin
      if LEpoch = FEpoch then
      begin
        Inc(FEpoch);
        FBusy := False;
        Notice('Response delayed. Check status or confirm the retained submission.', True);
        UpdateControls;
      end;
    end, 15000);
end;

procedure TStudioEffects.EndAction(AEpoch: Integer);
begin
  if AEpoch = FEpoch then
  begin
    window.clearTimeout(FTimer);
    FBusy := False;
    UpdateControls;
  end;
end;

function TStudioEffects.Matches(AJob: TJSObject): Boolean;
var
  LRequest: TJSObject;
  LKeys: TStringDynArray;
  LKey: String;
begin
  Result := (StudioText(AJob, 'format') = 'pythian.studio.job.v1') and
    (StudioText(AJob, 'job_id') = StudioText(FTransport, 'job_id')) and
    (StudioText(AJob, 'kind') = StudioText(FTransport, 'kind'));
  if not Result then
  begin
    Exit;
  end;
  LRequest := TJSObject(AJob['request']);
  if LRequest = nil then
  begin
    Result := False;
    Exit;
  end;
  LKeys := TJSObject.keys(FTransport);
  for LKey in LKeys do
  begin
    if TJSJSON.stringify(FTransport[LKey]) <> TJSJSON.stringify(LRequest[LKey]) then
    begin
      Result := False;
      Exit;
    end;
  end;
end;

procedure TStudioEffects.Accept(AJob: TJSObject);
begin
  if not Matches(AJob) then
  begin
    raise Exception.Create('The job response does not match the retained submission.');
  end;
  if (FJob <> nil) and
    (StudioText(FJob, 'job_id') = StudioText(AJob, 'job_id')) and
    (StudioNumber(AJob, 'event_revision') < StudioNumber(FJob, 'event_revision')) then
  begin
    Exit;
  end;
  FJob := AJob;
  FPending := False;
  WatchSelection;
  DrawJob;
  UpdateControls;
  window.clearTimeout(FPollTimer);
  if (StudioText(FJob, 'status') = 'queued') or (StudioText(FJob, 'status') = 'running') then
  begin
    if TJSDate.now - FStarted < 660000 then
    begin
      FPollTimer := window.setTimeout(
        procedure()
        begin
          Poll;
        end, 2000);
    end
    else
    begin
      Notice('Automatic status checks stopped. Use Check job status to recover.', True);
    end;
  end;
end;

procedure TStudioEffects.DrawJob;
var
  LStatus: String;
  LText: String;
  LResult: TJSObject;
  LId: String;
begin
  LStatus := StudioText(FJob, 'status');
  LId := StudioText(FJob, 'job_id');
  LText := LStatus + ' · ' + StudioText(FJob, 'stage');
  if StudioNumber(FJob, 'total') > 0 then
  begin
    LText := LText + ' · ' + FloatToStr(StudioNumber(FJob, 'done')) + ' / ' +
      FloatToStr(StudioNumber(FJob, 'total'));
  end;
  if Boolean(FJob['cancel_requested']) then
  begin
    LText := LText + ' · cancellation requested';
  end;
  El('effects-status').textContent := LText;
  El('effects-identity').textContent := 'Job: ' + LId;
  if (LStatus = 'failed') or (LStatus = 'cancelled') then
  begin
    Notice(LStatus + '. ' + StudioText(FJob, 'error_message') +
      ' Adjust settings or preview again with a new job.', LStatus = 'failed');
  end
  else if LStatus = 'completed' then
  begin
    LResult := TJSObject(FJob['results']);
    if StudioText(FJob, 'kind') = 'effect_preview' then
    begin
      if FPreviewVersion = FVersion then
      begin
        FPreviewId := LId;
        if FPlayer.getAttribute('data-job') <> LId then
        begin
          FPlayer.src := '/api/studio/effect-audio?job=' + encodeURIComponent(LId);
          FPlayer.setAttribute('data-job', LId);
        end;
        FPlayer.removeAttribute('hidden');
        Notice('Preview ready. Listen, adjust effects, or save as a new clip.');
        if StudioNumber(LResult, 'clipped_samples') > 0 then
        begin
          Notice('Preview ready; samples clipped. Lower gain or adjust the limiter.', True);
        end;
        El('effects-identity').textContent := 'Job: ' + LId + ' · WAV: ' +
          StudioText(LResult, 'output_sha256');
      end
      else
      begin
        Notice('Earlier preview finished. Preview the changed passage or rack before saving.');
      end;
    end
    else if StudioText(FJob, 'kind') = 'effect_save' then
    begin
      Notice('New clip saved to ' + StudioText(LResult, 'collection_name') +
        '. The original remains unchanged.');
      if FNotified <> LId then
      begin
        FNotified := LId;
        if Assigned(FSaved) then
        begin
          FSaved;
        end;
      end;
    end;
  end;
end;

procedure TStudioEffects.Submit(ARequest: TJSObject); async;
var
  LEpoch: Integer;
  LJob: TJSObject;
begin
  FTransport := CopyObject(ARequest);
  FPending := True;
  FStarted := TJSDate.now;
  LEpoch := BeginAction;
  if StudioText(ARequest, 'kind') = 'effect_preview' then
  begin
    Notice('Submitting preview…');
  end
  else
  begin
    Notice('Saving a new clip…');
  end;
  try
    LJob := await(TJSObject, Json('/api/studio/job', 'POST', TJSJSON.stringify(FTransport)));
    if LEpoch = FEpoch then
    begin
      Accept(LJob);
    end;
  except
    on LException: Exception do
    begin
      if LEpoch = FEpoch then
      begin
        if (LException is EStudioEffectHttp) and
          (EStudioEffectHttp(LException).Status in [400, 422]) then
        begin
          FPending := False;
          Notice('Request rejected: ' + LException.Message, True);
        end
        else
        begin
          Notice('Submission unconfirmed. Confirm this same job before trying another. ' +
            LException.Message, True);
        end;
      end;
    end;
  end;
  EndAction(LEpoch);
end;

procedure TStudioEffects.Confirm; async;
var
  LEpoch: Integer;
  LJob: TJSObject;
  LNotFound: Boolean;
begin
  if FBusy or not FPending then
  begin
    Exit;
  end;
  LEpoch := BeginAction;
  LNotFound := False;
  try
    try
      LJob := await(TJSObject, Json('/api/studio/job?id=' +
        encodeURIComponent(StudioText(FTransport, 'job_id')), 'GET', ''));
    except
      on LException: Exception do
      begin
        if LEpoch <> FEpoch then
        begin
          Exit;
        end;
        LNotFound := (LException is EStudioEffectHttp) and
          (EStudioEffectHttp(LException).Status = 404);
        LJob := await(TJSObject, Json('/api/studio/job', 'POST', TJSJSON.stringify(FTransport)));
      end;
    end;
    if LEpoch = FEpoch then
    begin
      Accept(LJob);
    end;
  except
    on LException: Exception do
    begin
      if LEpoch = FEpoch then
      begin
        if LNotFound and (LException is EStudioEffectHttp) and
          (EStudioEffectHttp(LException).Status in [400, 422]) then
        begin
          FPending := False;
          Notice('Job was not accepted: ' + LException.Message, True);
        end
        else
        begin
          Notice('Still unconfirmed. The original submission is retained. ' +
            LException.Message, True);
        end;
      end;
    end;
  end;
  EndAction(LEpoch);
end;

procedure TStudioEffects.Poll; async;
var
  LEpoch: Integer;
  LJob: TJSObject;
begin
  if FBusy or FPending or (FJob = nil) then
  begin
    Exit;
  end;
  LEpoch := BeginAction;
  try
    LJob := await(TJSObject, Json('/api/studio/job?id=' +
      encodeURIComponent(StudioText(FJob, 'job_id')), 'GET', ''));
    if LEpoch = FEpoch then
    begin
      Accept(LJob);
    end;
  except
    on LException: Exception do
    begin
      if LEpoch = FEpoch then
      begin
        Notice('Status unavailable. Check job status to retry. ' + LException.Message, True);
      end;
    end;
  end;
  EndAction(LEpoch);
end;

procedure TStudioEffects.Cancel; async;
var
  LEpoch: Integer;
  LBody: TJSObject;
  LJob: TJSObject;
begin
  if FBusy or FPending or (FJob = nil) then
  begin
    Exit;
  end;
  LBody := TJSObject.new;
  LBody['job_id'] := StudioText(FJob, 'job_id');
  LEpoch := BeginAction;
  try
    LJob := await(TJSObject, Json('/api/studio/cancel', 'POST', TJSJSON.stringify(LBody)));
    if LEpoch = FEpoch then
    begin
      Accept(LJob);
      if (StudioText(LJob, 'status') = 'queued') or
        (StudioText(LJob, 'status') = 'running') then
      begin
        Notice('Cancellation requested; the worker stops at a checkpoint.');
      end;
    end;
  except
    on LException: Exception do
    begin
      if LEpoch = FEpoch then
      begin
        Notice('Cancellation unconfirmed. Check job status. ' + LException.Message, True);
      end;
    end;
  end;
  EndAction(LEpoch);
end;

procedure TStudioEffects.Preview;
var
  LSelection: TJSObject;
  LRequest: TJSObject;
  LStart: Double;
  LEnd: Double;
  LRate: Double;
begin
  WatchSelection;
  if FBusy or FPending or (StudioText(FJob, 'status') = 'queued') or
    (StudioText(FJob, 'status') = 'running') then
  begin
    Exit;
  end;
  try
    LSelection := FSelection();
    if LSelection = nil then
    begin
      raise Exception.Create('Select an original source passage first.');
    end;
    LStart := StudioNumber(LSelection, 'start_frame');
    LEnd := StudioNumber(LSelection, 'end_frame');
    LRate := StudioNumber(LSelection, 'sample_rate');
    if (LRate <= 0) or (LStart < 0) or (Frac(LStart) <> 0) or (Frac(LEnd) <> 0) or
      (LEnd <= LStart) or (LEnd - LStart > 2000000) or (LEnd - LStart > LRate * 30) then
    begin
      raise Exception.Create('Choose a passage of at most 30 seconds and 2,000,000 frames.');
    end;
    LRequest := TJSObject.new;
    LRequest['format'] := 'pythian.studio.job.write.v1';
    LRequest['job_id'] := NewId;
    LRequest['kind'] := 'effect_preview';
    LRequest['source_sha256'] := StudioText(LSelection, 'source_sha256');
    LRequest['start_frame'] := LStart;
    LRequest['end_frame'] := LEnd;
    LRequest['effects'] := RackRequest(LRate);
    Invalidate;
    FPreviewVersion := FVersion;
    FJob := nil;
    Submit(LRequest);
  except
    on LException: Exception do
    begin
      Notice(LException.Message, True);
    end;
  end;
end;

procedure TStudioEffects.SaveClip;
var
  LRequest: TJSObject;
  LCollection: String;
  LTitle: String;
begin
  WatchSelection;
  if FBusy or FPending or (FPreviewId = '') or (FPreviewVersion <> FVersion) or
    (StudioText(FJob, 'status') = 'queued') or (StudioText(FJob, 'status') = 'running') then
  begin
    Exit;
  end;
  LCollection := Trim(TJSHTMLInputElement(El('effects-collection')).value);
  LTitle := Trim(TJSHTMLInputElement(El('effects-title')).value);
  if (LCollection = '') or (LTitle = '') then
  begin
    Notice('Choose a collection and title for the new clip.', True);
    if LCollection = '' then
    begin
      TJSHTMLInputElement(El('effects-collection')).focus;
    end
    else
    begin
      TJSHTMLInputElement(El('effects-title')).focus;
    end;
    Exit;
  end;
  LRequest := TJSObject.new;
  LRequest['format'] := 'pythian.studio.job.write.v1';
  LRequest['job_id'] := NewId;
  LRequest['kind'] := 'effect_save';
  LRequest['preview_job_id'] := FPreviewId;
  LRequest['collection_name'] := LCollection;
  LRequest['title'] := LTitle;
  FJob := nil;
  Submit(LRequest);
end;

function TStudioEffects.Edit(AEvent: TEventListenerEvent): Boolean;
var
  LInput: TJSHTMLInputElement;
  LRow: TJSObject;
  LIndex: Integer;
  LKey: String;
begin
  Result := False;
  LInput := TJSHTMLInputElement(AEvent.currentTarget);
  LInput.removeAttribute('aria-invalid');
  LKey := LInput.getAttribute('data-key');
  for LIndex := 0 to FRack.length - 1 do
  begin
    LRow := TJSObject(FRack[LIndex]);
    if StudioText(LRow, 'ui_id') = LInput.getAttribute('data-row') then
    begin
      if LKey = 'bypass' then
      begin
        LRow[LKey] := LInput.checked;
      end
      else
      begin
        LRow[LKey] := LInput.value;
      end;
      Invalidate;
      Notice('Rack changed. Preview again before saving.');
      Break;
    end;
  end;
end;

function TStudioEffects.Click(AEvent: TJSMouseEvent): Boolean;
var
  LAction: String;
  LId: String;
  LKind: String;
  LRow: TJSObject;
  LSwap: JSValue;
  LIndex: Integer;
  LSelection: TJSObject;
  LCutoff: Integer;
begin
  Result := False;
  LAction := TJSElement(AEvent.currentTarget).getAttribute('data-effect-action');
  if LAction = 'preview' then
  begin
    Preview;
    Exit;
  end
  else if LAction = 'save' then
  begin
    SaveClip;
    Exit;
  end
  else if LAction = 'refresh' then
  begin
    Poll;
    Exit;
  end
  else if LAction = 'confirm' then
  begin
    Confirm;
    Exit;
  end
  else if LAction = 'cancel' then
  begin
    Cancel;
    Exit;
  end;
  if LAction = 'add' then
  begin
    if FRack.length >= 8 then
    begin
      Exit;
    end;
    Inc(FSerial);
    LKind := TJSHTMLSelectElement(El('effects-kind')).value;
    LRow := TJSObject.new;
    LRow['ui_id'] := IntToStr(FSerial);
    LRow['kind'] := LKind;
    LRow['bypass'] := False;
    if LKind = 'gain' then
    begin
      LRow['gain_db'] := '0';
    end
    else if (LKind = 'lowpass') or (LKind = 'highpass') then
    begin
      if LKind = 'lowpass' then
      begin
        LSelection := FSelection();
        LCutoff := 1000;
        if (LSelection <> nil) and (StudioNumber(LSelection, 'sample_rate') < 4000) then
        begin
          LCutoff := Trunc(StudioNumber(LSelection, 'sample_rate') / 4);
          if LCutoff < 20 then
          begin
            LCutoff := 20;
          end;
        end;
        LRow['frequency_hz'] := IntToStr(LCutoff);
      end
      else
      begin
        LRow['frequency_hz'] := '80';
      end;
      LRow['q'] := '0.707';
    end
    else if LKind = 'compressor' then
    begin
      LRow['threshold_db'] := '-18';
      LRow['ratio'] := '3';
      LRow['attack_ms'] := '10';
      LRow['release_ms'] := '100';
      LRow['makeup_db'] := '0';
    end
    else if LKind = 'limiter' then
    begin
      LRow['ceiling_db'] := '-1';
      LRow['release_ms'] := '100';
    end;
    FRack.push(LRow);
  end
  else
  begin
    LId := Copy(LAction, Pos(':', LAction) + 1, Length(LAction));
    for LIndex := 0 to FRack.length - 1 do
    begin
      if StudioText(TJSObject(FRack[LIndex]), 'ui_id') = LId then
      begin
        if Pos('remove:', LAction) = 1 then
        begin
          FRack.splice(LIndex, 1);
        end
        else if (Pos('up:', LAction) = 1) and (LIndex > 0) then
        begin
          LSwap := FRack[LIndex - 1];
          FRack[LIndex - 1] := FRack[LIndex];
          FRack[LIndex] := LSwap;
        end
        else if (Pos('down:', LAction) = 1) and (LIndex < FRack.length - 1) then
        begin
          LSwap := FRack[LIndex + 1];
          FRack[LIndex + 1] := FRack[LIndex];
          FRack[LIndex] := LSwap;
        end;
        Break;
      end;
    end;
  end;
  Invalidate;
  DrawRack;
  UpdateControls;
  TJSHTMLSelectElement(El('effects-kind')).focus;
  Notice('Rack changed. Preview again before saving.');
end;

function TStudioEffects.Playing(AEvent: TEventListenerEvent): Boolean;
begin
  Result := False;
  WatchSelection;
  if (FPreviewId = '') or (FPreviewVersion <> FVersion) then
  begin
    StopAudio;
    Notice('Preview the current passage and rack before listening.', True);
  end;
end;

function TStudioEffects.Leaving(AEvent: TEventListenerEvent): Boolean;
begin
  Result := False;
  Inc(FEpoch);
  FBusy := False;
  StopAudio;
  window.clearTimeout(FTimer);
  window.clearTimeout(FPollTimer);
  window.clearInterval(FWatchTimer);
  FWatchTimer := 0;
end;

function TStudioEffects.Returning(AEvent: TEventListenerEvent): Boolean;
begin
  Result := False;
  if FWatchTimer = 0 then
  begin
    WatchSelection;
    UpdateControls;
    FWatchTimer := window.setInterval(
      procedure()
      begin
        WatchSelection;
      end, 500);
    if FPending then
    begin
      Notice('Confirm the retained submission before starting another job.');
    end
    else
    begin
      Poll;
    end;
  end;
end;

constructor TStudioEffects.Create(const AFetch: TStudioFetch;
  const ASelection: TStudioEffectSelection; const ASaved: TStudioChange);
begin
  inherited Create;
  FFetch := AFetch;
  FSelection := ASelection;
  FSaved := ASaved;
  FRack := TJSArray.new;
  Layout;
  DrawRack;
  WatchSelection;
  UpdateControls;
  FWatchTimer := window.setInterval(
    procedure()
    begin
      WatchSelection;
    end, 500);
  window.addEventListener('pagehide', @Leaving);
  window.addEventListener('pageshow', @Returning);
end;

destructor TStudioEffects.Destroy;
begin
  Inc(FEpoch);
  window.clearTimeout(FTimer);
  window.clearTimeout(FPollTimer);
  window.clearInterval(FWatchTimer);
  window.removeEventListener('pagehide', @Leaving);
  window.removeEventListener('pageshow', @Returning);
  StopAudio;
  inherited Destroy;
end;

end.
