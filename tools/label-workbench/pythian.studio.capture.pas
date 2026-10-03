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
unit pythian.studio.capture;

{$mode delphi}
{$H+}

interface

uses pythian.studio.progress,
  JS, Web, WebAudio, SysUtils, Math, Types, pythian.audio, pythian.wave.stream,
  pythian.studio.sources, pythian.studio.requests;

type
  TStudioCapture = class
  private
    FFetch: TStudioFetch;
    FSaved: TStudioChange;
    FBusy: Boolean;
    FEpoch: Integer;
    FPoll: NativeInt;
    FStopTimer: NativeInt;
    FDurationTimer: NativeInt;
    FInputId: String;
    FComplete: Boolean;
    FInspected: Boolean;
    FWaiting: Boolean;
    FBlob: TJSBlob;
    FStart: TJSObject;
    FRequest: TJSObject;
    FPending: Boolean;
    FJob: TJSObject;
    FJobStarted: Double;
    FNotified: String;
    FFeedback: TJSObject;
    FStream: TJSMediaStream;
    FContext: TJSAudioContext;
    FSource: TJSMediaStreamAudioSourceNode;
    FNode: TJSAudioWorkletNode;
    FRecording: Boolean;
    FStopping: Boolean;
    FPCM: TJSUint8Array;
    FFrames: Integer;
    FRate: Integer;
    FOriginal: TJSHTMLAudioElement;
    FCandidate: TJSHTMLAudioElement;
    FLocalUrl: String;
    function El(const AId: String): TJSElement;
    function Add(AParent: TJSElement; const ATag, AText: String): TJSElement;
    function Input(AParent: TJSElement; const AId, ALabel, AValue: String): TJSElement;
    procedure Button(AParent: TJSElement; const AText, AAction: String);
    procedure Layout;
    procedure Notice(const AText: String; const AError: Boolean = False);
    procedure Controls;
    procedure OpenEntry(const ARecorder: Boolean);
    procedure ResetFeedback;
    procedure ResetInputDisplay;
    procedure ClearPlayers;
    procedure CloseMicrophone;
    function NewId(const APrefix: String): String;
    function Json(const APath, AMethod, ABody: String): TJSObject; async;
    procedure RecordInput; async;
    procedure StopRecording;
    function Samples(AEvent: TJSMessageEvent): Boolean;
    function ProcessorError(AEvent: TJSEvent): Boolean;
    procedure FinishRecording;
    procedure Upload; async;
    procedure Enqueue(const AKind: String);
    procedure SendJob(AConfirm: Boolean); async;
    procedure ReadJob; async;
    procedure AcceptJob(AJob: TJSObject);
    procedure ShowResult;
    procedure DrawWaveform(AWaveform: TJSObject);
    procedure CancelJob; async;
    procedure Discard; async;
    procedure Feedback; async;
    function Click(AEvent: TJSMouseEvent): Boolean;
    function FileChanged(AEvent: TEventListenerEvent): Boolean;
    function InputChanged(AEvent: TEventListenerEvent): Boolean;
    function Leaving(AEvent: TEventListenerEvent): Boolean;
    function Playing(AEvent: TEventListenerEvent): Boolean;
  public
    constructor Create(const AFetch: TStudioFetch; const ASaved: TStudioChange);
    destructor Destroy; override;
    procedure OpenRecorder;
    procedure OpenImporter;
    procedure Refresh; async;
  end;

implementation

type
  ECaptureHttp = class(Exception)
  public
    Status: Integer;
  end;

function Flag(AObject: TJSObject; const AName: String): Boolean;
begin
  Result := (AObject <> nil) and isBoolean(AObject[AName]) and Boolean(AObject[AName]);
end;

function TStudioCapture.El(const AId: String): TJSElement;
begin
  Result := document.getElementById(AId);
end;

function TStudioCapture.Add(AParent: TJSElement; const ATag, AText: String): TJSElement;
begin
  Result := document.createElement(ATag);
  Result.textContent := AText;
  AParent.appendChild(Result);
end;

function TStudioCapture.Input(AParent: TJSElement;
  const AId, ALabel, AValue: String): TJSElement;
var
  LLabel: TJSElement;
begin
  LLabel := Add(AParent, 'label', ALabel);
  Result := Add(LLabel, 'input', '');
  Result.id := AId;
  Result.setAttribute('type', 'text');
  Result.setAttribute('value', AValue);
end;

procedure TStudioCapture.Button(AParent: TJSElement; const AText, AAction: String);
var
  LButton: TJSElement;
begin
  LButton := Add(AParent, 'button', AText);
  LButton.setAttribute('type', 'button');
  LButton.setAttribute('data-capture-action', AAction);
  LButton.addEventListener('click', @Click);
end;

procedure TStudioCapture.Layout;
var
  LRoot: TJSElement;
  LRow: TJSElement;
  LControl: TJSElement;
  LDetails: TJSElement;
  LLabel: TJSElement;
  LOption: TJSElement;
  LCanvas: TJSHTMLCanvasElement;
begin
  LRoot := El('studio-capture');
  Add(LRoot, 'h2', 'Import or record audio');
  LRow := Add(LRoot, 'div', '');
  LRow.className := 'source-toolbar';
  LControl := Input(LRow, 'capture-file', 'WAV file', '');
  LControl.setAttribute('type', 'file');
  LControl.setAttribute('accept', '.wav,audio/wav');
  LControl.addEventListener('change', @FileChanged);
  Button(LRow, 'Upload WAV', 'upload');
  Button(LRow, 'Start microphone', 'record');
  Button(LRow, 'Stop recording', 'stop');
  Button(LRow, 'Cancel microphone request', 'cancel-microphone');
  LControl := Add(LRoot, 'p', '');
  LControl.id := 'capture-microphone';
  LControl.setAttribute('tabindex', '-1');
  if not Boolean(TJSObject(window)['isSecureContext']) then
  begin
    LControl.textContent := 'Microphone needs a secure page on this device. ' +
      'Localhost recording is only for the host computer.';
    if window.location.protocol = 'http:' then
    begin
      LControl := Add(LRoot, 'a', 'Set up phone recording');
      LControl.id := 'capture-phone-setup';
      LControl.setAttribute('href', '/phone-setup.html');
      LControl.setAttribute('target', '_blank');
      LControl.setAttribute('rel', 'noopener');
      LControl.setAttribute('style',
        'display:inline-flex;align-items:center;min-height:44px');
    end;
  end;
  LControl := Add(LRoot, 'p', '');
  LControl.id := 'capture-level';
  LControl.setAttribute('role', 'status');
  LControl := Add(LRoot, 'p', '');
  LControl.id := 'capture-notice';
  LControl.setAttribute('role', 'status');
  LControl.setAttribute('aria-live', 'polite');
  LControl.setAttribute('tabindex', '-1');
  LRow := Add(LRoot, 'div', '');
  LRow.className := 'source-toolbar';
  LLabel := Add(LRow, 'label', 'Your inputs');
  LControl := Add(LLabel, 'select', '');
  LControl.id := 'capture-input';
  LControl.addEventListener('change', @InputChanged);
  Button(LRow, 'Refresh inputs', 'refresh');
  Button(LRow, 'Analyze audio', 'inspect');
  Button(LRow, 'Discard input', 'discard');
  FOriginal := TJSHTMLAudioElement(Add(LRoot, 'audio', ''));
  FOriginal.controls := True;
  FOriginal.preload := 'none';
  FOriginal.setAttribute('aria-label', 'Original input audio');
  FOriginal.setAttribute('hidden', '');
  FOriginal.addEventListener('play', @Playing);
  LCanvas := TJSHTMLCanvasElement(Add(LRoot, 'canvas', ''));
  LCanvas.id := 'capture-waveform';
  LCanvas.width := 600;
  LCanvas.height := 120;
  LCanvas.setAttribute('aria-label', 'Inspected waveform, first 30 seconds');
  LCanvas.setAttribute('role', 'img');
  LCanvas.setAttribute('hidden', '');
  LCanvas.style.setProperty('max-width', '100%');
  LControl := Add(LRoot, 'p', '');
  LControl.id := 'capture-analysis';
  LDetails := Add(LRoot, 'details', '');
  LDetails.className := 'advanced';
  Add(LDetails, 'summary', 'Try a note preview');
  LControl := Add(LDetails, 'span', 'Experimental');
  LControl.className := 'badge';
  LRow := Add(LDetails, 'div', '');
  LRow.className := 'range-fields';
  LLabel := Add(LRow, 'label', 'Input channel');
  LControl := Add(LLabel, 'select', '');
  LControl.id := 'capture-channel';
  LOption := Add(LControl, 'option', 'First / mono');
  LOption.setAttribute('value', '0');
  LOption := Add(LControl, 'option', 'Second');
  LOption.setAttribute('value', '1');
  LControl := Input(LRow, 'capture-tempo', 'MIDI tempo (40–240 BPM)', '120');
  LControl.setAttribute('inputmode', 'numeric');
  LControl.setAttribute('maxlength', '3');
  Button(LDetails, 'Try notes from the first 8 seconds', 'pitch');
  FCandidate := TJSHTMLAudioElement(Add(LDetails, 'audio', ''));
  FCandidate.controls := True;
  FCandidate.preload := 'none';
  FCandidate.setAttribute('hidden', '');
  FCandidate.setAttribute('aria-label', 'Experimental note preview');
  FCandidate.addEventListener('play', @Playing);
  LControl := Add(LDetails, 'a', 'Download MIDI');
  LControl.id := 'capture-midi';
  LControl.setAttribute('hidden', '');
  LControl := Add(LDetails, 'p', '');
  LControl.id := 'capture-notes';
  LLabel := Add(LDetails, 'label', 'How did this preview work?');
  LControl := Add(LLabel, 'select', '');
  LControl.id := 'capture-rating';
  LOption := Add(LControl, 'option', 'Choose feedback');
  LOption.setAttribute('value', '');
  LOption := Add(LControl, 'option', 'Works for this input');
  LOption.setAttribute('value', 'works');
  LOption := Add(LControl, 'option', 'Partly works');
  LOption.setAttribute('value', 'partial');
  LOption := Add(LControl, 'option', 'Does not work');
  LOption.setAttribute('value', 'fails');
  LLabel := Add(LDetails, 'label', 'Optional comment');
  LControl := Add(LLabel, 'textarea', '');
  LControl.id := 'capture-comment';
  LControl.setAttribute('maxlength', '2048');
  Button(LDetails, 'Save feedback', 'feedback');
  LRow := Add(LRoot, 'div', '');
  LRow.className := 'source-toolbar';
  Button(LRow, 'Check job status', 'status');
  Button(LRow, 'Retry same submission', 'confirm');
  Button(LRow, 'Cancel job', 'cancel');
  LControl := Add(LRoot, 'div', '');
  LControl.id := 'capture-job';
  LRow := Add(LRoot, 'div', '');
  LRow.className := 'range-fields';
  LControl := Input(LRow, 'capture-collection', 'Collection', 'Imported audio');
  LControl.setAttribute('maxlength', '96');
  LControl := Input(LRow, 'capture-title', 'Clip title', '');
  LControl.setAttribute('maxlength', '128');
  Button(LRoot, 'Save to collection', 'save');
  LDetails := Add(LRoot, 'details', '');
  LDetails.className := 'advanced';
  Add(LDetails, 'summary', 'Input details');
  Add(LDetails, 'p', 'WAV: up to 128 MiB; eight temporary inputs. Microphone: up to 120 seconds, ' +
    'mono PCM16 at the actual audio-context rate. MIDI tempo is an export clock. ' +
    'Inspection and saving do not start training.');
  LControl := Add(LDetails, 'p', '');
  LControl.id := 'capture-identity';
  LControl.className := 'batch-identity';
end;

procedure TStudioCapture.Notice(const AText: String; const AError: Boolean);
begin
  El('capture-notice').textContent := AText;
  if AError then
  begin
    El('capture-notice').className := 'notice error';
  end
  else
  begin
    El('capture-notice').className := 'notice';
  end;
end;

procedure TStudioCapture.Controls;
var
  LButtons: TJSNodeList;
  LButton: TJSHTMLButtonElement;
  LAction: String;
  LActive: Boolean;
  LVisible: Boolean;
  LIndex: Integer;
begin
  LActive := (StudioText(FJob, 'status') = 'queued') or
    (StudioText(FJob, 'status') = 'running');
  LButtons := El('studio-capture').querySelectorAll('button[data-capture-action]');
  for LIndex := 0 to LButtons.length - 1 do
  begin
    LButton := TJSHTMLButtonElement(LButtons[LIndex]);
    LAction := LButton.getAttribute('data-capture-action');
    LVisible := True;
    LButton.disabled := FBusy or FRecording or FStopping or FPending or LActive;
    if LAction = 'stop' then
    begin
      LButton.disabled := not FRecording or FStopping;
      LVisible := FRecording or FStopping;
    end
    else if LAction = 'record' then
    begin
      LButton.disabled := LButton.disabled or not Boolean(TJSObject(window)['isSecureContext']) or
        (window.navigator.mediaDevices = nil) or not isFunction(TJSObject(window)['AudioContext']);
    end
    else if LAction = 'upload' then
    begin
      LButton.disabled := LButton.disabled or (FBlob = nil);
    end
    else if LAction = 'cancel-microphone' then
    begin
      LButton.disabled := not FWaiting;
      LVisible := FWaiting;
    end
    else if LAction = 'inspect' then
    begin
      LButton.disabled := LButton.disabled or not FComplete;
    end
    else if (LAction = 'pitch') or (LAction = 'save') then
    begin
      LButton.disabled := LButton.disabled or not FInspected;
    end
    else if LAction = 'discard' then
    begin
      LButton.disabled := LButton.disabled or (FInputId = '');
    end
    else if LAction = 'confirm' then
    begin
      LButton.disabled := FBusy or not FPending;
      LVisible := FPending;
    end
    else if LAction = 'status' then
    begin
      LButton.disabled := FBusy or FPending or (FJob = nil);
      LVisible := LActive and not FPending;
    end
    else if LAction = 'cancel' then
    begin
      LButton.disabled := FBusy or FPending or not LActive;
      LVisible := LActive and not FPending;
    end
    else if LAction = 'feedback' then
    begin
      LButton.disabled := FBusy or LActive or FPending or
        (StudioText(FJob, 'kind') <> 'capture_pitch') or
        (StudioText(FJob, 'status') <> 'completed');
    end;
    if LVisible then
    begin
      LButton.removeAttribute('hidden');
    end
    else
    begin
      LButton.setAttribute('hidden', '');
    end;
  end;
  TJSHTMLInputElement(El('capture-file')).disabled := FBusy or FRecording or FStopping or
    FPending or LActive;
  TJSHTMLSelectElement(El('capture-input')).disabled := FBusy or FRecording or FStopping or
    FPending or LActive;
  TJSHTMLSelectElement(El('capture-rating')).disabled := FFeedback <> nil;
  TJSHTMLTextAreaElement(El('capture-comment')).disabled := FFeedback <> nil;
end;

procedure TStudioCapture.OpenEntry(const ARecorder: Boolean);
var
  LAction: String;
  LControl: TJSElement;
begin
  El('studio-capture').removeAttribute('hidden');
  TJSHTMLElement(El('studio-capture')).scrollIntoView(True);
  Controls;
  LAction := '';
  if FPending then
  begin
    LAction := 'confirm';
    Notice('Your pending submission is retained. Retry the same submission first.');
  end
  else if FWaiting then
  begin
    LAction := 'cancel-microphone';
    Notice('The microphone request is still open. You can cancel it.');
  end
  else if FRecording or FStopping then
  begin
    LAction := 'stop';
    if FStopping then
    begin
      Notice('Your recording is finishing.');
    end
    else
    begin
      Notice('Your recording is active. Stop it when ready.');
    end;
  end
  else if (StudioText(FJob, 'status') = 'queued') or
    (StudioText(FJob, 'status') = 'running') then
  begin
    LAction := 'status';
    Notice('An audio job is active. Check its status before starting another input.');
  end
  else if FBusy then
  begin
    Notice('The current operation is still running. Your input is retained.');
  end
  else if ARecorder and not Boolean(TJSObject(window)['isSecureContext']) then
  begin
    TJSHTMLElement(El('capture-microphone')).focus;
    Exit;
  end
  else if ARecorder and ((window.navigator.mediaDevices = nil) or
    not isFunction(TJSObject(window)['AudioContext'])) then
  begin
    El('capture-microphone').textContent := 'This browser cannot record audio here.';
    TJSHTMLElement(El('capture-microphone')).focus;
    Exit;
  end
  else if ARecorder and (FBlob <> nil) and not FComplete then
  begin
    LAction := 'upload';
    Notice('Your current input is retained. Upload it before starting another recording.');
  end
  else if ARecorder then
  begin
    LAction := 'record';
    Notice('Press Start microphone to record.');
  end
  else
  begin
    TJSHTMLInputElement(El('capture-file')).focus;
    Exit;
  end;
  if LAction <> '' then
  begin
    LControl := El('studio-capture').querySelector(
      'button[data-capture-action="' + LAction + '"]');
    if (LControl <> nil) and not TJSHTMLButtonElement(LControl).disabled then
    begin
      TJSHTMLButtonElement(LControl).focus;
      Exit;
    end;
  end;
  TJSHTMLElement(El('capture-notice')).focus;
end;

procedure TStudioCapture.OpenRecorder;
begin
  OpenEntry(True);
end;

procedure TStudioCapture.OpenImporter;
begin
  OpenEntry(False);
end;

procedure TStudioCapture.ResetFeedback;
begin
  FFeedback := nil;
  TJSHTMLSelectElement(El('capture-rating')).value := '';
  TJSHTMLTextAreaElement(El('capture-comment')).value := '';
  El('capture-notes').textContent := '';
end;

procedure TStudioCapture.ResetInputDisplay;
begin
  ResetFeedback;
  El('capture-level').textContent := '';
  El('capture-job').textContent := '';
  El('capture-identity').textContent := '';
end;

function TStudioCapture.NewId(const APrefix: String): String;
begin
  Result := APrefix + '-' + IntToStr(TJSDate.now) + '-' + IntToStr(Random(1000000000));
end;

function TStudioCapture.Json(const APath, AMethod, ABody: String): TJSObject; async;
var
  LResponse: TJSResponse;
  LText: String;
  LError: ECaptureHttp;
begin
  LResponse := TJSResponse(await(JSValue, AwaitStudioPromise(FFetch(APath, AMethod, ABody), 15)));
  if (LResponse.status <> 200) and (LResponse.status <> 202) then
  begin
    LText := String(await(JSValue, AwaitStudioPromise(LResponse.text(), 15)));
    LError := ECaptureHttp.Create(Copy(Trim(LText), 1, 256));
    LError.Status := LResponse.status;
    raise LError;
  end;
  Result := TJSObject(await(JSValue, AwaitStudioPromise(LResponse.json(), 15)));
end;

procedure TStudioCapture.ClearPlayers;
begin
  FOriginal.pause;
  FCandidate.pause;
  FOriginal.removeAttribute('src');
  FCandidate.removeAttribute('src');
  FOriginal.load;
  FCandidate.load;
  FOriginal.setAttribute('hidden', '');
  FCandidate.setAttribute('hidden', '');
  El('capture-midi').setAttribute('hidden', '');
  El('capture-waveform').setAttribute('hidden', '');
  El('capture-analysis').textContent := '';
  El('capture-notes').textContent := '';
  if FLocalUrl <> '' then
  begin
    TJSURL.revokeObjectURL(FLocalUrl);
    FLocalUrl := '';
  end;
end;

procedure TStudioCapture.CloseMicrophone;
var
  LTracks: TJSMediaStreamTracks;
  LIndex: Integer;
begin
  window.clearTimeout(FStopTimer);
  window.clearTimeout(FDurationTimer);
  if FStream <> nil then
  begin
    LTracks := FStream.getTracks;
    for LIndex := 0 to LTracks.length - 1 do
    begin
      TJSMediaStreamTrack(LTracks[LIndex]).stop;
    end;
    FStream := nil;
  end;
  if FNode <> nil then
  begin
    FNode.port.removeEventListener('message', @Samples);
    FNode.onprocessorerror := nil;
    FNode.disconnect;
    FNode.port.close;
    FNode := nil;
  end;
  if FSource <> nil then
  begin
    FSource.disconnect;
    FSource := nil;
  end;
  if FContext <> nil then
  begin
    FContext.close();
    FContext := nil;
  end;
  FRecording := False;
  FStopping := False;
  FWaiting := False;
end;

procedure TStudioCapture.RecordInput; async;
var
  LConstraints: TJSObject;
  LAudioConstraints: TJSObject;
  LPermission: TJSPromise;
  LStream: TJSMediaStream;
  LOptions: TJSAudioWorkletNodeOptions;
  LEpoch: Integer;
begin
  if FBusy or FRecording or FPending then
  begin
    Exit;
  end;
  FBusy := True;
  Inc(FEpoch);
  LEpoch := FEpoch;
  Controls;
  Notice('Waiting for microphone permission…');
  FWaiting := True;
  Controls;
  try
    LConstraints := TJSObject.new;
    LAudioConstraints := TJSObject.new;
    LAudioConstraints['echoCancellation'] := False;
    LAudioConstraints['noiseSuppression'] := False;
    LAudioConstraints['autoGainControl'] := False;
    LConstraints['audio'] := LAudioConstraints;
    LConstraints['video'] := False;
    LPermission := window.navigator.mediaDevices.getUserMedia(LConstraints)._then(
      function(AValue: JSValue): JSValue
      var
        LTracks: TJSMediaStreamTracks;
        LIndex: Integer;
      begin
        Result := AValue;
        if LEpoch <> FEpoch then
        begin
          LTracks := TJSMediaStream(AValue).getTracks;
          for LIndex := 0 to LTracks.length - 1 do
          begin
            TJSMediaStreamTrack(LTracks[LIndex]).stop;
          end;
        end;
      end);
    LStream := TJSMediaStream(await(JSValue, AwaitStudioPromise(LPermission, 60)));
    if LEpoch <> FEpoch then
    begin
      Exit;
    end;
    FStream := LStream;
    FContext := TJSAudioContext.new;
    FRate := Round(FContext.sampleRate);
    if (FRate < 8000) or (FRate > 192000) or (RiffHeaderBytes + FRate * 240 > 134217728) or
      (FContext.audioWorklet = nil) then
    begin
      raise Exception.Create('This browser cannot provide the supported microphone worklet.');
    end;
    await(JSValue, AwaitStudioPromise(FContext.audioWorklet.addModule('capture-worklet.js'), 15));
    if LEpoch <> FEpoch then
    begin
      Exit;
    end;
    ClearPlayers;
    FPCM := TJSUint8Array.new(RiffHeaderBytes + FRate * 240);
    FFrames := 0;
    FBlob := nil;
    FStart := nil;
    FInputId := '';
    FComplete := False;
    FInspected := False;
    FJob := nil;
    ResetInputDisplay;
    LOptions := TJSAudioWorkletNodeOptions.new;
    LOptions.numberOfInputs := 1;
    LOptions.numberOfOutputs := 1;
    LOptions.outputChannelCount := [1];
    FNode := TJSAudioWorkletNode.new(FContext, 'pythian-capture', LOptions);
    FNode.port.addEventListener('message', @Samples);
    FNode.port.start;
    FNode.onprocessorerror := @ProcessorError;
    FSource := FContext.createMediaStreamSource(FStream);
    FSource.connect(FNode);
    FNode.connect(FContext.destination);
    await(JSValue, AwaitStudioPromise(FContext.resume(), 15));
    if LEpoch = FEpoch then
    begin
      FRecording := True;
      FWaiting := False;
      FDurationTimer := window.setTimeout(
        procedure()
        begin
          StopRecording;
        end, 120000);
      Notice('Recording without monitoring. Stop when ready (120 seconds maximum).');
    end;
  except
    on LException: Exception do
    begin
      if LEpoch = FEpoch then
      begin
        Inc(FEpoch);
        CloseMicrophone;
        FBusy := False;
        Notice(LException.Message, True);
        Controls;
      end;
    end;
  else
    if LEpoch = FEpoch then
    begin
      Inc(FEpoch);
      CloseMicrophone;
      FBusy := False;
      Notice('Microphone setup failed. Import a WAV or try recording again.', True);
      Controls;
    end;
  end;
  if LEpoch = FEpoch then
  begin
    FBusy := False;
    Controls;
  end;
end;

procedure TStudioCapture.StopRecording;
begin
  if not FRecording or FStopping then
  begin
    Exit;
  end;
  FStopping := True;
  Controls;
  Notice('Finishing the recording…');
  FNode.port.postMessage('stop');
  FStopTimer := window.setTimeout(
    procedure()
    begin
      if FStopping then
      begin
        CloseMicrophone;
        FPCM := nil;
        Notice('Recording did not finish cleanly. No incomplete WAV was uploaded.', True);
        Controls;
      end;
    end, 3000);
end;

function TStudioCapture.ProcessorError(AEvent: TJSEvent): Boolean;
begin
  Result := False;
  Inc(FEpoch);
  FBusy := False;
  CloseMicrophone;
  FPCM := nil;
  Notice('Microphone processing failed. Record again or import a WAV.', True);
  Controls;
end;

function TStudioCapture.Samples(AEvent: TJSMessageEvent): Boolean;
var
  LMessage: TJSObject;
  LSamples: TJSFloat32Array;
  LView: TJSDataView;
  LIndex: Integer;
  LValue: Double;
  LPeak: Double;
  LSample: Integer;
begin
  Result := False;
  if FPCM = nil then
  begin
    Exit;
  end;
  LMessage := TJSObject(AEvent.data);
  if StudioText(LMessage, 'kind') = 'ended' then
  begin
    if (StudioNumber(LMessage, 'frames') <> FFrames) or
      (StudioNumber(LMessage, 'sample_rate') <> FRate) then
    begin
      ProcessorError(nil);
      Exit;
    end;
    FinishRecording;
    Exit;
  end;
  if StudioText(LMessage, 'kind') <> 'samples' then
  begin
    Exit;
  end;
  LSamples := TJSFloat32Array(LMessage['samples']);
  if (StudioNumber(LMessage, 'start_frame') <> FFrames) or
    (LSamples.length > 4096) or (FFrames + LSamples.length > FRate * 120) then
  begin
    ProcessorError(nil);
    Exit;
  end;
  LView := TJSDataView.new(FPCM.buffer);
  LPeak := 0;
  for LIndex := 0 to LSamples.length - 1 do
  begin
    LValue := Double(LSamples[LIndex]);
    try
      LSample := QuantizePcm16(LValue);
    except
      on E: EAudio do begin ProcessorError(nil); Exit end;
    end;
    LPeak := Max(LPeak, Abs(LValue));
    LView.setInt16(RiffHeaderBytes + (FFrames + LIndex) * 2, LSample, True);
  end;
  Inc(FFrames, LSamples.length);
  El('capture-level').textContent := StudioTime(FFrames / FRate) +
    ' recorded · peak ' + IntToStr(Round(Min(1, LPeak) * 100)) + '%';
end;

procedure TStudioCapture.FinishRecording;
var
  LView: TJSDataView;
  LParts: TJSArray;
  LHeader: TAudioBytes;
  LIndex: Integer;
begin
  CloseMicrophone;
  if FFrames < 1 then
  begin
    FPCM := nil;
    Notice('No microphone samples were received. Try again or import a WAV.', True);
    Controls;
    Exit;
  end;
  LView := TJSDataView.new(FPCM.buffer);
  LHeader := WavePcm16Header(FRate, 1, FFrames);
  for LIndex := 0 to High(LHeader) do LView.setUint8(LIndex, LHeader[LIndex]);
  LParts := TJSArray.new;
  LParts.push(FPCM.subarray(0, Length(LHeader) + FFrames * 2));
  FBlob := TJSBlob.new(LParts);
  FPCM := nil;
  FStart := TJSObject.new;
  FStart['capture_id'] := NewId('mic');
  FStart['name'] := 'Microphone recording';
  FStart['bytes'] := FBlob.size;
  FStart['origin'] := 'microphone';
  TJSHTMLInputElement(El('capture-title')).value := 'Microphone recording';
  FLocalUrl := TJSURL.createObjectURL(FBlob);
  FOriginal.src := FLocalUrl;
  FOriginal.removeAttribute('hidden');
  Notice('Recording ready. Listen locally, then upload it for inspection or saving.');
  Controls;
end;

procedure TStudioCapture.Upload; async;
var
  LEpoch: Integer;
  LState: TJSObject;
  LWrite: TJSObject;
  LChunk: TJSUint8Array;
  LBuffer: TJSArrayBuffer;
  LOffset: Integer;
  LEnd: Integer;
  LIndex: Integer;
  LText: String;
begin
  if FBusy or FRecording or FStopping or FPending or (FBlob = nil) or (FStart = nil) then
  begin
    Exit;
  end;
  FBusy := True;
  LEpoch := FEpoch;
  Controls;
  try
    LState := await(TJSObject, Json('/api/studio/capture/start', 'POST',
      TJSJSON.stringify(FStart)));
    if LEpoch <> FEpoch then
    begin
      Exit;
    end;
    if (StudioText(LState, 'capture_id') <> StudioText(FStart, 'capture_id')) or
      (StudioNumber(LState, 'bytes') <> FBlob.size) then
    begin
      raise Exception.Create('Upload response does not match the retained input.');
    end;
    FInputId := StudioText(FStart, 'capture_id');
    LOffset := Trunc(StudioNumber(LState, 'received_bytes'));
    if (LOffset < 0) or (LOffset > FBlob.size) then
    begin
      raise Exception.Create('Upload returned an invalid byte offset.');
    end;
    while LOffset < FBlob.size do
    begin
      LEnd := Min(FBlob.size, LOffset + 16384);
      LBuffer := TJSArrayBuffer(await(JSValue, AwaitStudioPromise(FBlob.slice(LOffset, LEnd).arrayBuffer(), 15)));
      if LEpoch <> FEpoch then
      begin
        Exit;
      end;
      LChunk := TJSUint8Array.new(LBuffer);
      LText := '';
      for LIndex := 0 to LChunk.length - 1 do
      begin
        LText := LText + Chr(Byte(LChunk[LIndex]));
      end;
      LWrite := TJSObject.new;
      LWrite['capture_id'] := FInputId;
      LWrite['offset'] := LOffset;
      LWrite['data'] := window.btoa(LText);
      LState := await(TJSObject, Json('/api/studio/capture/chunk', 'POST',
        TJSJSON.stringify(LWrite)));
      if LEpoch <> FEpoch then
      begin
        Exit;
      end;
      if (StudioText(LState, 'capture_id') <> FInputId) or
        (StudioNumber(LState, 'received_bytes') <> LEnd) then
      begin
        raise Exception.Create('Upload acknowledgement does not match this chunk.');
      end;
      LOffset := LEnd;
      Notice('Uploading · ' + IntToStr(LOffset) + ' / ' + IntToStr(FBlob.size) + ' bytes');
    end;
    FComplete := True;
    Notice('Upload complete. Press Analyze audio to listen and explore it.');
  except
    on LException: Exception do
    begin
      if LEpoch = FEpoch then
      begin
        Notice('Upload paused. Press Upload WAV to resume. ' +
          LException.Message, True);
      end;
    end;
  end;
  if LEpoch = FEpoch then
  begin
    FBusy := False;
    Controls;
    Refresh;
  end;
end;

procedure TStudioCapture.Refresh; async;
var
  LList: TJSObject;
  LRows: TJSArray;
  LRow: TJSObject;
  LSelect: TJSHTMLSelectElement;
  LOption: TJSElement;
  LIndex: Integer;
  LEpoch: Integer;
begin
  if FBusy or FRecording or FStopping then
  begin
    Exit;
  end;
  FBusy := True;
  LEpoch := FEpoch;
  Controls;
  try
    LList := await(TJSObject, Json('/api/studio/captures', 'GET', ''));
    if LEpoch = FEpoch then
    begin
      if not isArray(LList['captures']) then
      begin
        raise Exception.Create('The retained input list is unavailable.');
      end;
      LRows := TJSArray(LList['captures']);
      LSelect := TJSHTMLSelectElement(El('capture-input'));
      LSelect.innerHTML := '';
      LOption := Add(LSelect, 'option', 'Choose a recording');
      LOption.setAttribute('value', '');
      for LIndex := 0 to LRows.length - 1 do
      begin
        LRow := TJSObject(LRows[LIndex]);
        LOption := Add(LSelect, 'option', StudioText(LRow, 'name'));
        if not Flag(LRow, 'complete') then
        begin
          LOption.textContent := LOption.textContent + ' (incomplete upload)';
        end;
        LOption.setAttribute('value', StudioText(LRow, 'capture_id'));
        LOption.setAttribute('data-complete', BoolToStr(Flag(LRow, 'complete'), True));
        LOption.setAttribute('data-inspected', BoolToStr(Flag(LRow, 'inspected'), True));
        if StudioText(LRow, 'capture_id') = FInputId then
        begin
          FComplete := Flag(LRow, 'complete');
          FInspected := Flag(LRow, 'inspected');
        end;
      end;
      LSelect.value := FInputId;
      if (FInputId <> '') and (LSelect.value = '') then
      begin
        FInputId := '';
        FComplete := False;
        FInspected := False;
        FJob := nil;
        ResetInputDisplay;
        ClearPlayers;
      end;
      El('capture-identity').textContent := 'Input: ' + FInputId;
    end;
  except
    on LException: Exception do
    begin
      if LEpoch = FEpoch then
      begin
        Notice(LException.Message, True);
      end;
    end;
  end;
  if LEpoch = FEpoch then
  begin
    FBusy := False;
    Controls;
  end;
end;

procedure TStudioCapture.Enqueue(const AKind: String);
var
  LRequest: TJSObject;
  LTempo: Integer;
  LText: String;
  LIndex: Integer;
begin
  if FBusy or FRecording or FStopping or FPending or not FComplete or
    (StudioText(FJob, 'status') = 'queued') or (StudioText(FJob, 'status') = 'running') then
  begin
    Exit;
  end;
  LRequest := TJSObject.new;
  LRequest['format'] := 'pythian.studio.job.write.v1';
  LRequest['job_id'] := NewId('capture');
  LRequest['kind'] := AKind;
  LRequest['capture_id'] := FInputId;
  if AKind = 'capture_pitch' then
  begin
    if not FInspected then
    begin
      Notice('Inspect this input before trying notes.', True);
      Exit;
    end;
    LText := TJSHTMLInputElement(El('capture-tempo')).value;
    for LIndex := 1 to Length(LText) do
    begin
      if not (LText[LIndex] in ['0'..'9']) then
      begin
        Notice('Use a whole-number MIDI tempo from 40 to 240 BPM.', True);
        Exit;
      end;
    end;
    if not TryStrToInt(LText, LTempo) or (LTempo < 40) or (LTempo > 240) then
    begin
      Notice('Use a MIDI tempo from 40 to 240 BPM.', True);
      Exit;
    end;
    LRequest['mode'] := 'single_pitch';
    LRequest['channel'] := StrToInt(TJSHTMLSelectElement(El('capture-channel')).value);
    LRequest['tempo_bpm'] := LTempo;
    FCandidate.pause;
    FCandidate.removeAttribute('src');
    FCandidate.load;
    FCandidate.setAttribute('hidden', '');
    El('capture-midi').setAttribute('hidden', '');
    ResetFeedback;
    El('capture-level').textContent := '';
    El('capture-job').textContent := '';
  end
  else if AKind = 'capture_save' then
  begin
    if not FInspected then
    begin
      Notice('Inspect this input before saving it.', True);
      Exit;
    end;
    LRequest['collection_name'] := Trim(TJSHTMLInputElement(El('capture-collection')).value);
    LRequest['title'] := Trim(TJSHTMLInputElement(El('capture-title')).value);
    if (StudioText(LRequest, 'collection_name') = '') or (StudioText(LRequest, 'title') = '') then
    begin
      Notice('Choose a collection and clip title first.', True);
      Exit;
    end;
  end;
  FRequest := LRequest;
  FPending := True;
  FJob := nil;
  FJobStarted := TJSDate.now;
  SendJob(False);
end;

procedure TStudioCapture.SendJob(AConfirm: Boolean); async;
var
  LJob: TJSObject;
  LEpoch: Integer;
  LNotFound: Boolean;
begin
  if FBusy or not FPending then
  begin
    Exit;
  end;
  FBusy := True;
  LEpoch := FEpoch;
  LNotFound := not AConfirm;
  Controls;
  try
    if AConfirm then
    begin
      try
        LJob := await(TJSObject, Json('/api/studio/job?id=' +
          encodeURIComponent(StudioText(FRequest, 'job_id')), 'GET', ''));
      except
        on LException: Exception do
        begin
          LNotFound := (LException is ECaptureHttp) and (ECaptureHttp(LException).Status = 404);
          if LEpoch <> FEpoch then
          begin
            Exit;
          end;
          LJob := await(TJSObject, Json('/api/studio/job', 'POST', TJSJSON.stringify(FRequest)));
        end;
      end;
    end
    else
    begin
      LJob := await(TJSObject, Json('/api/studio/job', 'POST', TJSJSON.stringify(FRequest)));
    end;
    if LEpoch = FEpoch then
    begin
      AcceptJob(LJob);
    end;
  except
    on LException: Exception do
    begin
      if LEpoch = FEpoch then
      begin
        if LNotFound and (LException is ECaptureHttp) and
          (ECaptureHttp(LException).Status in [400, 422]) then
        begin
          FPending := False;
          Notice('Job rejected: ' + LException.Message, True);
        end
        else
        begin
          Notice('Submission unconfirmed. Confirm this same job before trying another. ' +
            LException.Message, True);
        end;
      end;
    end;
  end;
  if LEpoch = FEpoch then
  begin
    FBusy := False;
    Controls;
  end;
end;

procedure TStudioCapture.AcceptJob(AJob: TJSObject);
var
  LOriginal: TJSObject;
  LKeys: TStringDynArray;
  LKey: String;
begin
  if (StudioText(AJob, 'job_id') <> StudioText(FRequest, 'job_id')) or
    (StudioText(AJob, 'kind') <> StudioText(FRequest, 'kind')) then
  begin
    raise Exception.Create('The returned job does not match this submission.');
  end;
  LOriginal := TJSObject(AJob['request']);
  if LOriginal = nil then
  begin
    raise Exception.Create('The returned job has no input binding.');
  end;
  LKeys := TJSObject.keys(FRequest);
  for LKey in LKeys do
  begin
    if TJSJSON.stringify(FRequest[LKey]) <> TJSJSON.stringify(LOriginal[LKey]) then
    begin
      raise Exception.Create('The returned job does not match the retained settings.');
    end;
  end;
  if (FJob <> nil) and (StudioNumber(AJob, 'event_revision') <
    StudioNumber(FJob, 'event_revision')) then
  begin
    Exit;
  end;
  FJob := AJob;
  FPending := False;
  El('capture-job').innerHTML := '';
  DrawStudioProgress(El('capture-job'), AJob);
  El('capture-identity').textContent := 'Input: ' + FInputId + ' · Job: ' +
    StudioText(AJob, 'job_id');
  window.clearTimeout(FPoll);
  if (StudioText(AJob, 'status') = 'queued') or (StudioText(AJob, 'status') = 'running') then
  begin
    if TJSDate.now - FJobStarted < 660000 then
    begin
      FPoll := window.setTimeout(
        procedure()
        begin
          ReadJob;
        end, 2000);
    end
    else
    begin
      Notice('Automatic checks stopped. Check job status to recover.', True);
    end;
  end
  else if StudioText(AJob, 'status') = 'completed' then
  begin
    ShowResult;
  end
  else
  begin
    Notice(StudioText(AJob, 'status') + '. ' + StudioText(AJob, 'error_message') +
      ' You can try again with a new job.', True);
  end;
end;

procedure TStudioCapture.ReadJob; async;
var
  LJob: TJSObject;
  LEpoch: Integer;
begin
  if FBusy or FPending or (FJob = nil) then
  begin
    Exit;
  end;
  FBusy := True;
  LEpoch := FEpoch;
  Controls;
  try
    LJob := await(TJSObject, Json('/api/studio/job?id=' +
      encodeURIComponent(StudioText(FJob, 'job_id')), 'GET', ''));
    if LEpoch = FEpoch then
    begin
      AcceptJob(LJob);
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
  if LEpoch = FEpoch then
  begin
    FBusy := False;
    Controls;
  end;
end;

procedure TStudioCapture.DrawWaveform(AWaveform: TJSObject);
var
  LCanvas: TJSHTMLCanvasElement;
  LContext: TJSCanvasRenderingContext2D;
  LBins: TJSArray;
  LBin: TJSObject;
  LIndex: Integer;
begin
  if (AWaveform = nil) or not isArray(AWaveform['bins']) then
  begin
    Exit;
  end;
  LCanvas := TJSHTMLCanvasElement(El('capture-waveform'));
  LContext := TJSCanvasRenderingContext2D(LCanvas.getContext('2d'));
  LContext.fillStyleAsColor := '#152b32';
  LContext.fillRect(0, 0, LCanvas.width, LCanvas.height);
  LContext.fillStyleAsColor := '#a0ddcb';
  LBins := TJSArray(AWaveform['bins']);
  for LIndex := 0 to LBins.length - 1 do
  begin
    LBin := TJSObject(LBins[LIndex]);
    LContext.fillRect(LIndex * LCanvas.width / LBins.length,
      60 - StudioNumber(LBin, 'max') * 50, LCanvas.width / LBins.length + 1,
      Max(1, (StudioNumber(LBin, 'max') - StudioNumber(LBin, 'min')) * 50));
  end;
  LCanvas.removeAttribute('hidden');
end;

procedure TStudioCapture.ShowResult;
var
  LResult: TJSObject;
  LSpans: TJSArray;
  LUnknown: Integer;
  LSilence: Integer;
  LIndex: Integer;
  LId: String;
  LKind: String;
  LProposals: TJSObject;
  LCandidates: TJSArray;
  LPulseText: String;
begin
  LResult := TJSObject(FJob['results']);
  LId := StudioText(FJob, 'job_id');
  LKind := StudioText(FJob, 'kind');
  if LKind = 'capture_inspect' then
  begin
    FInspected := True;
    FOriginal.src := '/api/studio/capture-audio?id=' + encodeURIComponent(FInputId);
    FOriginal.removeAttribute('hidden');
    DrawWaveform(TJSObject(LResult['waveform']));
    El('capture-analysis').textContent :=
      StudioTime(StudioNumber(LResult, 'frame_count') / StudioNumber(LResult, 'sample_rate')) +
      ' · ' + IntToStr(Trunc(StudioNumber(LResult, 'sample_rate'))) + ' Hz · ' +
      IntToStr(Trunc(StudioNumber(LResult, 'channels'))) + ' channel(s) · peak ' +
      FormatFloat('0.00', StudioNumber(LResult, 'peak'));
    LProposals := TJSObject(LResult['beat_proposal']);
    LPulseText := '';
    if (LProposals <> nil) and isArray(LProposals['candidates']) then
    begin
      LCandidates := TJSArray(LProposals['candidates']);
      for LIndex := 0 to Min(2, LCandidates.length - 1) do
      begin
        if LPulseText <> '' then
        begin
          LPulseText := LPulseText + ', ';
        end;
        LPulseText := LPulseText + FormatFloat('0.0',
          StudioNumber(TJSObject(LCandidates[LIndex]), 'bpm'));
      end;
    end;
    if LPulseText = '' then
    begin
      LPulseText := 'No tempo suggestion';
    end
    else
      LPulseText := 'Suggested tempo: ' + LPulseText + ' BPM';
    El('capture-analysis').textContent := El('capture-analysis').textContent +
      ' · ' + LPulseText;
    Notice('Analysis complete. Showing the first ' +
      StudioTime((StudioNumber(LResult, 'end_frame') - StudioNumber(LResult, 'start_frame')) /
      StudioNumber(LResult, 'sample_rate')) + '.');
  end
  else if LKind = 'capture_pitch' then
  begin
    LUnknown := 0;
    LSilence := 0;
    if isArray(LResult['spans']) then
    begin
      LSpans := TJSArray(LResult['spans']);
      for LIndex := 0 to LSpans.length - 1 do
      begin
        if StudioText(TJSObject(LSpans[LIndex]), 'kind') = 'unknown' then
        begin
          Inc(LUnknown);
        end
        else if StudioText(TJSObject(LSpans[LIndex]), 'kind') = 'silence' then
        begin
          Inc(LSilence);
        end;
      end;
    end;
    El('capture-notes').textContent := IntToStr(Trunc(StudioNumber(LResult, 'note_count'))) +
      ' suggested notes · ' + IntToStr(LSilence) + ' silent regions · ' +
      IntToStr(LUnknown) + ' uncertain regions';
    FOriginal.src := '/api/studio/capture-audio?id=' + encodeURIComponent(FInputId);
    FOriginal.removeAttribute('hidden');
    if Flag(LResult, 'audio_available') then
    begin
      FCandidate.src := '/api/studio/pitch-audio?job=' + encodeURIComponent(LId);
      FCandidate.removeAttribute('hidden');
    end;
    if Flag(LResult, 'midi_available') then
    begin
      El('capture-midi').setAttribute('href', '/api/studio/pitch-midi?job=' +
        encodeURIComponent(LId));
      El('capture-midi').removeAttribute('hidden');
    end;
    Notice('Note preview complete. Listen and leave brief feedback.');
  end
  else if LKind = 'capture_save' then
  begin
    Notice('Input saved to ' + StudioText(LResult, 'collection_name') + '.');
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

procedure TStudioCapture.CancelJob; async;
var
  LWrite: TJSObject;
  LJob: TJSObject;
  LEpoch: Integer;
begin
  if FBusy or FPending or (FJob = nil) then
  begin
    Exit;
  end;
  LWrite := TJSObject.new;
  LWrite['job_id'] := StudioText(FJob, 'job_id');
  FBusy := True;
  LEpoch := FEpoch;
  Controls;
  try
    LJob := await(TJSObject, Json('/api/studio/cancel', 'POST', TJSJSON.stringify(LWrite)));
    if LEpoch = FEpoch then
    begin
      AcceptJob(LJob);
      if Flag(LJob, 'cancel_requested') then
      begin
        Notice('Cancellation requested; waiting for the worker checkpoint.');
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
  if LEpoch = FEpoch then
  begin
    FBusy := False;
    Controls;
  end;
end;

procedure TStudioCapture.Discard; async;
var
  LWrite: TJSObject;
  LResult: TJSObject;
  LEpoch: Integer;
begin
  if FBusy or FPending or (FInputId = '') then
  begin
    Exit;
  end;
  FBusy := True;
  LEpoch := FEpoch;
  Controls;
  LWrite := TJSObject.new;
  LWrite['capture_id'] := FInputId;
  try
    LResult := await(TJSObject, Json('/api/studio/capture/discard', 'POST',
      TJSJSON.stringify(LWrite)));
    if (LEpoch = FEpoch) and Flag(LResult, 'discarded') then
    begin
      FInputId := '';
      FComplete := False;
      FInspected := False;
      FBlob := nil;
      FStart := nil;
      FJob := nil;
      ResetInputDisplay;
      ClearPlayers;
      Notice('Temporary input discarded. Saved collection clips are unchanged.');
    end;
  except
    on LException: Exception do
    begin
      if LEpoch = FEpoch then
      begin
        Notice('Discard unconfirmed. Refresh inputs to check. ' + LException.Message, True);
      end;
    end;
  end;
  if LEpoch = FEpoch then
  begin
    FBusy := False;
    Controls;
    Refresh;
  end;
end;

procedure TStudioCapture.Feedback; async;
var
  LResult: TJSObject;
  LRating: String;
  LEpoch: Integer;
begin
  if FBusy or (StudioText(FJob, 'kind') <> 'capture_pitch') or
    (StudioText(FJob, 'status') <> 'completed') then
  begin
    Exit;
  end;
  if FFeedback = nil then
  begin
    LRating := TJSHTMLSelectElement(El('capture-rating')).value;
    if (LRating <> 'works') and (LRating <> 'partial') and (LRating <> 'fails') then
    begin
      Notice('Choose brief feedback first.', True);
      Exit;
    end;
    FFeedback := TJSObject.new;
    FFeedback['feedback_id'] := NewId('feedback');
    FFeedback['job_id'] := StudioText(FJob, 'job_id');
    FFeedback['rating'] := LRating;
    FFeedback['comment'] := TJSHTMLTextAreaElement(El('capture-comment')).value;
  end;
  FBusy := True;
  LEpoch := FEpoch;
  Controls;
  try
    LResult := await(TJSObject, Json('/api/studio/exploration-feedback', 'POST',
      TJSJSON.stringify(FFeedback)));
    if (StudioText(LResult, 'feedback_id') <> StudioText(FFeedback, 'feedback_id')) or
      (StudioText(LResult, 'job_id') <> StudioText(FFeedback, 'job_id')) then
    begin
      raise Exception.Create('Feedback response does not match this preview.');
    end;
    if LEpoch = FEpoch then
    begin
      Notice('Feedback saved for this exact preview.');
      FFeedback := nil;
    end;
  except
    on LException: Exception do
    begin
      if LEpoch = FEpoch then
      begin
        Notice('Feedback unconfirmed; Save feedback retries the same response. ' +
          LException.Message, True);
      end;
    end;
  end;
  if LEpoch = FEpoch then
  begin
    FBusy := False;
    Controls;
  end;
end;

function TStudioCapture.Click(AEvent: TJSMouseEvent): Boolean;
var
  LAction: String;
begin
  Result := False;
  LAction := TJSElement(AEvent.currentTarget).getAttribute('data-capture-action');
  if LAction = 'upload' then
  begin
    Upload;
  end
  else if LAction = 'record' then
  begin
    RecordInput;
  end
  else if LAction = 'stop' then
  begin
    StopRecording;
  end
  else if LAction = 'cancel-microphone' then
  begin
    Inc(FEpoch);
    CloseMicrophone;
    FBusy := False;
    Notice('Microphone request cancelled.');
    Controls;
  end
  else if LAction = 'refresh' then
  begin
    Refresh;
  end
  else if LAction = 'inspect' then
  begin
    Enqueue('capture_inspect');
  end
  else if LAction = 'pitch' then
  begin
    Enqueue('capture_pitch');
  end
  else if LAction = 'save' then
  begin
    Enqueue('capture_save');
  end
  else if LAction = 'confirm' then
  begin
    SendJob(True);
  end
  else if LAction = 'status' then
  begin
    ReadJob;
  end
  else if LAction = 'cancel' then
  begin
    CancelJob;
  end
  else if LAction = 'discard' then
  begin
    Discard;
  end
  else if LAction = 'feedback' then
  begin
    Feedback;
  end;
end;

function TStudioCapture.FileChanged(AEvent: TEventListenerEvent): Boolean;
var
  LFiles: TJSHTMLFileList;
  LFile: TJSFile;
begin
  Result := False;
  if FBusy or FRecording or FStopping or FPending then
  begin
    Exit;
  end;
  LFiles := TJSHTMLInputElement(El('capture-file')).files;
  if LFiles.length = 0 then
  begin
    Exit;
  end;
  LFile := LFiles[0];
  if (LFile.size < 44) or (LFile.size > 134217728) then
  begin
    FBlob := nil;
    FStart := nil;
    Notice('Choose a WAV between 44 bytes and 128 MiB.', True);
    Controls;
    Exit;
  end;
  ClearPlayers;
  FBlob := LFile;
  FInputId := '';
  FComplete := False;
  FInspected := False;
  FJob := nil;
  ResetInputDisplay;
  FStart := TJSObject.new;
  FStart['capture_id'] := NewId('wav');
  FStart['name'] := Copy(LFile.name, 1, 128);
  FStart['bytes'] := LFile.size;
  FStart['origin'] := 'wav_import';
  TJSHTMLInputElement(El('capture-title')).value := Copy(LFile.name, 1, 128);
  Notice('WAV selected. Press Upload WAV to continue.');
  Controls;
end;

function TStudioCapture.InputChanged(AEvent: TEventListenerEvent): Boolean;
var
  LSelect: TJSHTMLSelectElement;
begin
  Result := False;
  if FBusy or FPending then
  begin
    Exit;
  end;
  LSelect := TJSHTMLSelectElement(El('capture-input'));
  FInputId := LSelect.value;
  FComplete := (LSelect.selectedIndex >= 0) and
    (TJSElement(LSelect.options[LSelect.selectedIndex]).getAttribute('data-complete') = 'True');
  FInspected := (LSelect.selectedIndex >= 0) and
    (TJSElement(LSelect.options[LSelect.selectedIndex]).getAttribute('data-inspected') = 'True');
  FJob := nil;
  ResetInputDisplay;
  ClearPlayers;
  if FInspected then
  begin
    FOriginal.src := '/api/studio/capture-audio?id=' + encodeURIComponent(FInputId);
    FOriginal.removeAttribute('hidden');
  end;
  El('capture-job').textContent := '';
  if FComplete and not FInspected then
  begin
    Notice('Inspect this uploaded input before listening, trying notes, or saving.');
  end;
  El('capture-identity').textContent := 'Input: ' + FInputId;
  Controls;
end;

function TStudioCapture.Playing(AEvent: TEventListenerEvent): Boolean;
begin
  Result := False;
  if AEvent.currentTarget = FOriginal then
  begin
    FCandidate.pause;
  end
  else
  begin
    FOriginal.pause;
  end;
end;

function TStudioCapture.Leaving(AEvent: TEventListenerEvent): Boolean;
begin
  Result := False;
  Inc(FEpoch);
  FBusy := False;
  CloseMicrophone;
  FPCM := nil;
  window.clearTimeout(FPoll);
  ClearPlayers;
end;

constructor TStudioCapture.Create(const AFetch: TStudioFetch; const ASaved: TStudioChange);
begin
  inherited Create;
  FFetch := AFetch;
  FSaved := ASaved;
  Layout;
  Controls;
  window.addEventListener('pagehide', @Leaving);
end;

destructor TStudioCapture.Destroy;
begin
  Inc(FEpoch);
  window.removeEventListener('pagehide', @Leaving);
  CloseMicrophone;
  window.clearTimeout(FPoll);
  ClearPlayers;
  inherited Destroy;
end;

end.
