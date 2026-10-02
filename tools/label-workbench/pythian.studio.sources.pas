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
unit pythian.studio.sources;

{$mode delphi}
{$H+}

interface

uses JS, Web, SysUtils, Math, StrUtils, Types,
  pythian.studio.&library.refresh;

type
  TStudioFetch = function(const APath, AMethod, ABody: String): TJSPromise of object;
  TStudioChange = procedure of object;

  TStudioSourceEditor = class
  private
    FFetch: TStudioFetch;
    FChanged: TStudioChange;
    FPreparation: TStudioLibraryRefresh;
    FPrepareSelection: TJSObject;
    FPrepareEntry: String;
    FPrepareEditing: Integer;
    FPrepareAnalyze: Boolean;
    FPrepareDraft: TJSArray;
    FPreparePrior: TJSObject;
    FPrepareWindowStart: Double;
    FPrepareWindowEnd: Double;
    FPreviewStart: Double;
    FPosition: Double;
    FChunkEnd: Double;
    FMediaEpoch: Integer;
    FPlaying: Boolean;
    FSeeking: Boolean;
    FResumeAfterSeek: Boolean;
    FTracks: TJSArray;
    FSelections: TJSArray;
    FTrack: TJSObject;
    FDisabled: Boolean;
    FEditing: Integer;
    FBins: TJSArray;
    FWindowStart: Double;
    FWindowEnd: Double;
    FViewSeconds: Double;
    FEpoch: Integer;
    FDragging: Boolean;
    FDragStart: Double;
    FDragOldStart: String;
    FDragOldEnd: String;
    FPlayEnd: Double;
    FAnalysis: TJSObject;
    FAnalysisBusy: Boolean;
    FPlayer: TJSHTMLAudioElement;
    FCanvas: TJSHTMLCanvasElement;
    function El(const AId: String): TJSElement;
    function Input(const AId: String): TJSHTMLInputElement;
    function Add(AParent: TJSElement; const ATag, AText, AClass: String): TJSElement;
    function Button(AParent: TJSElement; const AText, AAction, AValue: String): TJSElement;
    procedure Notice(const AText: String; const AError: Boolean = False);
    procedure OpenTrack(const AHash: String; const ASelection: Integer);
    procedure WindowAt(const ASeconds: Double); async;
    procedure ResizeView(const ASeconds: Double);
    procedure Analyze; async;
    procedure DrawWaveform;
    procedure DrawTracks;
    function ReadRange(out AStart, AEnd: Double): Boolean;
    procedure SetRange(const AStart, AEnd: Double);
    procedure SaveSelection(const AWhole: Boolean);
    procedure ApplySelection(ARow: TJSObject; const AEditing: Integer);
    procedure PrepareRecording(ASelection: TJSObject; const AAnalyze: Boolean);
    procedure PreparationDone;
    procedure PreparationState;
    procedure ApplyPrepared; async;
    procedure PlayRange(const AStart, AEnd: Double);
    procedure PlayChunk; async;
    procedure ReplacePlayer;
    procedure SeekTo(const ASeconds: Double; const AResume: Boolean);
    procedure UpdateTransport;
    function CompletedForTrack: Boolean;
    function PointerFrame(AEvent: TJSPointerEvent): Double;
    function Click(AEvent: TJSMouseEvent): Boolean;
    function Edit(AEvent: TEventListenerEvent): Boolean;
    function Playback(AEvent: TEventListenerEvent): Boolean;
    function LeavePage(AEvent: TEventListenerEvent): Boolean;
    function Down(AEvent: TJSPointerEvent): Boolean;
    function Move(AEvent: TJSPointerEvent): Boolean;
    function Up(AEvent: TJSPointerEvent): Boolean;
    function CancelPointer(AEvent: TJSPointerEvent): Boolean;
  public
    constructor Create(const AFetch: TStudioFetch; const AChanged: TStudioChange;
      const AJobFetch: TLibraryFetch);
    procedure Bind(ATracks, ASelections: TJSArray; const ADisabled: Boolean);
    procedure SetDisabled(const ADisabled: Boolean);
    procedure Reset;
    procedure Search;
    function CurrentRange: TJSObject;
  end;

function StudioText(AObject: TJSObject; const AName: String): String;
function StudioNumber(AObject: TJSObject; const AName: String): Double;
function StudioTime(const ASeconds: Double): String;

implementation

function StudioText(AObject: TJSObject; const AName: String): String;
begin
  Result := '';
  if (AObject <> nil) and isString(AObject[AName]) then
  begin
    Result := String(AObject[AName]);
  end;
end;

function StudioNumber(AObject: TJSObject; const AName: String): Double;
begin
  Result := 0;
  if (AObject <> nil) and isNumber(AObject[AName]) then
  begin
    Result := Double(AObject[AName]);
  end;
end;

function StudioTime(const ASeconds: Double): String;
var
  LSeconds: Double;
begin
  LSeconds := Round(Max(0, ASeconds) * 1000) / 1000;
  Result := IntToStr(Floor(LSeconds / 60)) + ':' +
    FormatFloat('00.000', LSeconds - Floor(LSeconds / 60) * 60);
end;

function ParseSourceTime(const AText: String; out ASeconds: Double): Boolean;
var
  LParts: TStringDynArray;
  LMinutes: Double;
  LSeconds: Double;
begin
  LParts := SplitString(Trim(AText), ':');
  Result := False;
  ASeconds := 0;
  if Length(LParts) <> 2 then
  begin
    Exit;
  end;
  if not TryStrToFloat(LParts[0], LMinutes) or
    not TryStrToFloat(LParts[1], LSeconds) then
  begin
    Exit;
  end;
  Result := (LMinutes >= 0) and (Frac(LMinutes) = 0) and
    (LSeconds >= 0) and (LSeconds < 60);
  if Result then
  begin
    ASeconds := LMinutes * 60 + LSeconds;
  end;
end;

function TStudioSourceEditor.El(const AId: String): TJSElement;
begin
  Result := document.getElementById(AId);
end;

function TStudioSourceEditor.Input(const AId: String): TJSHTMLInputElement;
begin
  Result := TJSHTMLInputElement(El(AId));
end;

function TStudioSourceEditor.Add(AParent: TJSElement;
  const ATag, AText, AClass: String): TJSElement;
begin
  Result := document.createElement(ATag);
  Result.textContent := AText;
  Result.className := AClass;
  AParent.appendChild(Result);
end;

function TStudioSourceEditor.Button(AParent: TJSElement;
  const AText, AAction, AValue: String): TJSElement;
begin
  Result := Add(AParent, 'button', AText, '');
  Result.setAttribute('type', 'button');
  Result.setAttribute('data-action', AAction);
  Result.setAttribute('data-value', AValue);
  TJSHTMLButtonElement(Result).disabled := FDisabled;
  Result.addEventListener('click', @Click);
end;

constructor TStudioSourceEditor.Create(const AFetch: TStudioFetch;
  const AChanged: TStudioChange; const AJobFetch: TLibraryFetch);
var
  LNames: array of String;
  LIndex: Integer;
begin
  FFetch := AFetch;
  FChanged := AChanged;
  FPreparation := TStudioLibraryRefresh.Create(AJobFetch, @PreparationDone,
    'library_prepare', 'studio-source-prepare', 'source-prepare');
  FPreparation.OnStateChanged := @PreparationState;
  FEditing := -1;
  FPlayEnd := -1;
  FTracks := TJSArray.new;
  FSelections := TJSArray.new;
  FPlayer := TJSHTMLAudioElement(El('source-audio'));
  FCanvas := TJSHTMLCanvasElement(El('source-waveform'));
  ReplacePlayer;
  window.addEventListener('pagehide', @LeavePage);
  FCanvas.addEventListener('pointerdown', @Down);
  FCanvas.addEventListener('pointermove', @Move);
  FCanvas.addEventListener('pointerup', @Up);
  FCanvas.addEventListener('pointercancel', @CancelPointer);
  LNames := ['source-mark-in', 'source-mark-out', 'source-prev', 'source-next',
    'source-use-range', 'source-use-whole', 'source-close', 'source-play-range',
    'source-prepare', 'source-play', 'source-waveform-retry',
    'source-analyze', 'source-go', 'source-zoom-in', 'source-zoom-out',
    'source-view-whole', 'source-view-apply'];
  for LIndex := 0 to High(LNames) do
  begin
    El(LNames[LIndex]).addEventListener('click', @Click);
  end;
  El('source-start').addEventListener('input', @Edit);
  El('source-end').addEventListener('input', @Edit);
  El('source-classifications').addEventListener('input', @Edit);
  El('source-seek').addEventListener('input', @Edit);
  El('source-seek').addEventListener('change', @Edit);
  El('collection-filter').addEventListener('change', @Edit);
  El('source-beat-layer').addEventListener('change', @Edit);
end;

procedure TStudioSourceEditor.ReplacePlayer;
var
  LPlayer: TJSHTMLAudioElement;
begin
  { Big Boss: each request owns its media element. Late events and a failed
    decoder/network state from the previous request cannot affect its retry. }
  FPlayer.pause;
  FPlayer.removeAttribute('src');
  FPlayer.load;
  LPlayer := TJSHTMLAudioElement(document.createElement('audio'));
  LPlayer.id := 'source-audio';
  LPlayer.preload := 'none';
  LPlayer.setAttribute('hidden', '');
  FPlayer.parentNode.replaceChild(LPlayer, FPlayer);
  FPlayer := LPlayer;
  FPlayer.addEventListener('timeupdate', @Playback);
  FPlayer.addEventListener('loadedmetadata', @Playback);
  FPlayer.addEventListener('error', @Playback);
  FPlayer.addEventListener('ended', @Playback);
  FPlayer.addEventListener('waiting', @Playback);
  FPlayer.addEventListener('playing', @Playback);
  FPlayer.addEventListener('pause', @Playback);
end;

procedure TStudioSourceEditor.Notice(const AText: String; const AError: Boolean);
begin
  El('source-notice').textContent := AText;
  if AError then
  begin
    El('source-notice').className := 'field-error';
  end
  else
  begin
    El('source-notice').className := 'hint';
  end;
end;

procedure TStudioSourceEditor.Reset;
begin
  Inc(FEpoch);
  Inc(FMediaEpoch);
  FPlaying := False;
  FSeeking := False;
  FDragging := False;
  FPosition := 0;
  FPlayer.pause;
  FPlayer.removeAttribute('src');
  FPlayer.load;
  FTrack := nil;
  FAnalysis := nil;
  FPlayEnd := -1;
  FBins := nil;
  FEditing := -1;
  El('source-reconnect').setAttribute('hidden', '');
  El('source-inspector').setAttribute('hidden', '');
end;

procedure TStudioSourceEditor.Bind(ATracks, ASelections: TJSArray; const ADisabled: Boolean);
begin
  if (FSelections <> ASelections) and (FTrack <> nil) then
  begin
    Reset;
  end;
  FTracks := ATracks;
  FSelections := ASelections;
  SetDisabled(ADisabled);
  FPreparation.SetConnected(not ADisabled);
  if not ADisabled then
  begin
    FPreparation.Refresh;
  end;
  DrawTracks;
end;

procedure TStudioSourceEditor.SetDisabled(const ADisabled: Boolean);
var
  LControls: TJSNodeList;
  LIndex: Integer;
begin
  FDisabled := ADisabled;
  LControls := El('source-inspector').querySelectorAll('button, input');
  for LIndex := 0 to LControls.length - 1 do
  begin
    if FDisabled then
    begin
      TJSElement(LControls[LIndex]).setAttribute('disabled', '');
    end
    else
    begin
      TJSElement(LControls[LIndex]).removeAttribute('disabled');
    end;
  end;
end;

procedure TStudioSourceEditor.Search;
begin
  DrawTracks;
end;

procedure TStudioSourceEditor.DrawTracks;
var
  LRoot: TJSElement;
  LShortcuts: TJSElement;
  LShortcut: TJSElement;
  LCard: TJSElement;
  LRow: TJSElement;
  LTrack: TJSObject;
  LSelection: TJSObject;
  LCollections: TJSArray;
  LClasses: TJSArray;
  LNames: TJSArray;
  LFilter: TJSHTMLSelectElement;
  LOption: TJSElement;
  LIndex: Integer;
  LOther: Integer;
  LPart: Integer;
  LShown: Integer;
  LHash: String;
  LTitle: String;
  LCollectionText: String;
  LDurationText: String;
  LFilterValue: String;
  LQuery: String;
  LCaption: String;
  LMatchesCollection: Boolean;
begin
  LRoot := El('tracks');
  LRoot.innerHTML := '';
  LFilter := TJSHTMLSelectElement(El('collection-filter'));
  LFilterValue := LFilter.value;
  LNames := TJSArray.new;
  for LIndex := 0 to FTracks.length - 1 do
  begin
    LTrack := TJSObject(FTracks[LIndex]);
    LCollections := TJSArray(LTrack['collections']);
    if isArray(LCollections) then
    begin
      for LOther := 0 to LCollections.length - 1 do
      begin
        LTitle := StudioText(TJSObject(LCollections[LOther]), 'name');
        if LNames.indexOf(LTitle) < 0 then
        begin
          LNames.push(LTitle);
        end;
      end;
    end;
  end;
  LNames.sort;
  LFilter.innerHTML := '';
  LOption := Add(LFilter, 'option', 'All collections', '');
  LOption.setAttribute('value', '');
  for LIndex := 0 to LNames.length - 1 do
  begin
    LOption := Add(LFilter, 'option', String(LNames[LIndex]), '');
    LOption.setAttribute('value', String(LNames[LIndex]));
  end;
  LFilter.value := LFilterValue;
  if LFilter.selectedIndex < 0 then
  begin
    LFilter.selectedIndex := 0;
    LFilterValue := '';
  end;
  LShortcuts := El('collection-shortcuts');
  LShortcuts.innerHTML := '';
  if LNames.length > 0 then
  begin
    LShortcut := Button(LShortcuts, 'All recordings', 'collection', '');
    LShortcut.id := 'collection-choice-all';
    LShortcut.setAttribute('aria-pressed', LowerCase(BoolToStr(LFilterValue = '', True)));
    for LIndex := 0 to Min(LNames.length, 8) - 1 do
    begin
      LTitle := String(LNames[LIndex]);
      LShortcut := Button(LShortcuts, LTitle, 'collection', LTitle);
      LShortcut.id := 'collection-choice-' + IntToStr(LIndex);
      LShortcut.setAttribute('aria-pressed', LowerCase(BoolToStr(LFilterValue = LTitle, True)));
    end;
    if LNames.length > 8 then
    begin
      Add(LShortcuts, 'p', 'More collections are available in the selector above.', 'hint');
    end;
  end;
  LQuery := LowerCase(Trim(Input('track-search').value));
  LShown := 0;
  for LIndex := 0 to FTracks.length - 1 do
  begin
    LTrack := TJSObject(FTracks[LIndex]);
    LHash := StudioText(LTrack, 'entry_id');
    if LHash = '' then
    begin
      LHash := StudioText(LTrack, 'source_sha256');
    end;
    LTitle := StudioText(LTrack, 'title');
    LCollectionText := '';
    LMatchesCollection := LFilterValue = '';
    LCollections := TJSArray(LTrack['collections']);
    if isArray(LCollections) then
    begin
      for LOther := 0 to LCollections.length - 1 do
      begin
        if LCollectionText <> '' then
        begin
          LCollectionText := LCollectionText + ' · ';
        end;
        LCollectionText := LCollectionText + StudioText(TJSObject(LCollections[LOther]), 'name');
        LMatchesCollection := LMatchesCollection or
          (StudioText(TJSObject(LCollections[LOther]), 'name') = LFilterValue);
      end;
    end;
    if ((LQuery <> '') and (Pos(LQuery, LowerCase(LTitle + ' ' + LCollectionText)) = 0)) or
      not LMatchesCollection then
    begin
      Continue;
    end;
    Inc(LShown);
    LCard := Add(LRoot, 'article', '', 'track');
    Add(LCard, 'h3', LTitle, 'track-name');
    LDurationText := 'Header unavailable';
    if StudioNumber(LTrack, 'sample_rate') > 0 then
    begin
      LDurationText := StudioTime(StudioNumber(LTrack, 'frame_count') /
        StudioNumber(LTrack, 'sample_rate'));
    end;
    Add(LCard, 'p', LDurationText + ' · ' + LCollectionText, 'track-meta');
    if StudioText(LTrack, 'partition') = 'evaluation' then
    begin
      Add(LCard, 'p', 'Reserved evaluation recording', 'hint');
      Continue;
    end;
    if (StudioText(LTrack, 'status') = 'missing') or
      (StudioText(LTrack, 'status') = 'unsupported') then
    begin
      Add(LCard, 'p', 'Original unavailable. Refresh after replacing the file.', 'hint');
      if StudioText(LTrack, 'source_sha256') = '' then
      begin
        Continue;
      end;
      LHash := StudioText(LTrack, 'source_sha256');
    end;
    Button(LCard, 'Listen & select', 'open', LHash);
    for LOther := 0 to FSelections.length - 1 do
    begin
      LSelection := TJSObject(FSelections[LOther]);
      if StudioText(LSelection, 'source_sha256') <>
        StudioText(LTrack, 'source_sha256') then
      begin
        Continue;
      end;
      LCard.className := 'track selected';
      LRow := Add(LCard, 'div', '', 'selected-passage');
      if StudioText(LSelection, 'selection') = 'full' then
      begin
        LCaption := 'Whole recording';
      end
      else
      begin
        LCaption := StudioTime(StudioNumber(LSelection, 'start_frame') /
          StudioNumber(LTrack, 'sample_rate')) + '–' +
          StudioTime(StudioNumber(LSelection, 'end_frame') / StudioNumber(LTrack, 'sample_rate'));
      end;
      LClasses := TJSArray(LSelection['classifications']);
      if isArray(LClasses) then
      begin
        for LPart := 0 to LClasses.length - 1 do
        begin
          LCaption := LCaption + ' · ' + String(LClasses[LPart]);
        end;
      end;
      Add(LRow, 'p', LCaption, 'hint');
      Button(LRow, 'Edit passage', 'edit', IntToStr(LOther));
      Button(LRow, 'Remove', 'remove', IntToStr(LOther));
    end;
  end;
  if LShown = 0 then
  begin
    El('tracks-empty').textContent := 'No matching recordings. Add WAV files to your private collection folder, then refresh the library.';
    El('tracks-empty').removeAttribute('hidden');
  end
  else
  begin
    El('tracks-empty').setAttribute('hidden', '');
  end;
end;

procedure TStudioSourceEditor.OpenTrack(const AHash: String; const ASelection: Integer);
var
  LIndex: Integer;
  LSelection: TJSObject;
  LClasses: TJSArray;
begin
  Reset;
  for LIndex := 0 to FTracks.length - 1 do
  begin
    if (StudioText(TJSObject(FTracks[LIndex]), 'source_sha256') = AHash) or
      (StudioText(TJSObject(FTracks[LIndex]), 'entry_id') = AHash) then
    begin
      FTrack := TJSObject(FTracks[LIndex]);
      Break;
    end;
  end;
  if FTrack = nil then
  begin
    Exit;
  end;
  if (ASelection >= 0) or
    ((AHash = StudioText(FTrack, 'source_sha256')) and
    ((StudioText(FTrack, 'status') = 'missing') or
    (StudioText(FTrack, 'status') = 'unsupported'))) then
  begin
    { A saved selection refers to immutable catalog bytes, independently of
      the current original. Do not change the shared discovery card. }
    FTrack := TJSObject(TJSJSON.parse(TJSJSON.stringify(FTrack)));
    FTrack['entry_id'] := '';
    FTrack['entry_snapshot_sha256'] := '';
    FTrack['discovery_revision'] := 0;
    FTrack['prepared_snapshot'] := '';
  end;
  FEditing := ASelection;
  FViewSeconds := 30;
  El('source-inspector').removeAttribute('hidden');
  El('source-title').textContent := StudioText(FTrack, 'title');
  Input('source-seek').max := FloatToStr(StudioNumber(FTrack, 'frame_count') /
    StudioNumber(FTrack, 'sample_rate'));
  Input('source-classifications').value := '';
  SetRange(0, Min(30, StudioNumber(FTrack, 'frame_count') / StudioNumber(FTrack, 'sample_rate')));
  if ASelection >= 0 then
  begin
    LSelection := TJSObject(FSelections[ASelection]);
    SetRange(StudioNumber(LSelection, 'start_frame') / StudioNumber(FTrack, 'sample_rate'),
      StudioNumber(LSelection, 'end_frame') / StudioNumber(FTrack, 'sample_rate'));
    LClasses := TJSArray(LSelection['classifications']);
    if isArray(LClasses) then
    begin
      Input('source-classifications').value := LClasses.join(', ');
    end;
  end;
  { Opening shows only the bounded waveform; Play requests bounded PCM. }
  FPosition := 0;
  if ASelection >= 0 then
    FPosition := StudioNumber(LSelection, 'start_frame') / StudioNumber(FTrack, 'sample_rate');
  FPreviewStart := FPosition;
  FPlayEnd := StudioNumber(FTrack, 'frame_count') / StudioNumber(FTrack, 'sample_rate');
  UpdateTransport;
  El('source-playback-status').textContent := 'Choose a position, then press Play.';
  El('source-prepare').setAttribute('hidden', '');
  El('source-preparation-purpose').textContent := 'Ready for project use, analysis and effects.';
  if (StudioText(FTrack, 'entry_id') <> '') and
    (StudioText(FTrack, 'prepared_snapshot') <>
      StudioText(FTrack, 'entry_snapshot_sha256')) then
  begin
    El('source-prepare').removeAttribute('hidden');
    El('source-preparation-purpose').textContent := 'Browsing needs no preparation. Add music to your project, or prepare it for analysis and effects.';
  end;
  if FEditing < 0 then
  begin
    El('source-use-range').textContent := 'Add passage to project';
  end
  else
  begin
    El('source-use-range').textContent := 'Update selection';
  end;
  WindowAt(FPosition);
  TJSHTMLElement(El('source-title')).focus;
  Notice('');
  PreparationState;
end;

procedure TStudioSourceEditor.SetRange(const AStart, AEnd: Double);
begin
  Input('source-start').value := StudioTime(AStart);
  Input('source-end').value := StudioTime(AEnd);
  DrawWaveform;
end;

function TStudioSourceEditor.ReadRange(out AStart, AEnd: Double): Boolean;
begin
  Result := ParseSourceTime(Input('source-start').value, AStart);
  Result := ParseSourceTime(Input('source-end').value, AEnd) and Result;
  Result := Result and (FTrack <> nil);
  if Result then
  begin
    Result := (AStart < AEnd) and
      (AEnd <= StudioNumber(FTrack, 'frame_count') / StudioNumber(FTrack, 'sample_rate') + 0.0005);
  end;
end;

function TStudioSourceEditor.CurrentRange: TJSObject;
var
  LStart: Double;
  LEnd: Double;
begin
  Result := nil;
  if (FTrack = nil) or FDisabled or
    (StudioText(FTrack, 'source_sha256') = '') or
    ((StudioText(FTrack, 'entry_id') <> '') and
    (StudioText(FTrack, 'prepared_snapshot') <>
      StudioText(FTrack, 'entry_snapshot_sha256'))) or not ReadRange(LStart, LEnd) then
  begin
    Exit;
  end;
  Result := TJSObject.new;
  Result['source_sha256'] := StudioText(FTrack, 'source_sha256');
  Result['title'] := StudioText(FTrack, 'title');
  Result['sample_rate'] := StudioNumber(FTrack, 'sample_rate');
  Result['start_frame'] := Round(LStart * StudioNumber(FTrack, 'sample_rate'));
  Result['end_frame'] := Min(StudioNumber(FTrack, 'frame_count'),
    Round(LEnd * StudioNumber(FTrack, 'sample_rate')));
end;

procedure TStudioSourceEditor.WindowAt(const ASeconds: Double); async;
var
  LResponse: TJSResponse;
  LData: TJSObject;
  LEpoch: Integer;
  LRate: Double;
  LHash: String;
  LPath: String;
  LEntry: String;
begin
  if FTrack = nil then
  begin
    Exit;
  end;
  Inc(FEpoch);
  LEpoch := FEpoch;
  LRate := StudioNumber(FTrack, 'sample_rate');
  LHash := StudioText(FTrack, 'source_sha256');
  FWindowStart := Floor(Max(0, Min(ASeconds * LRate,
    StudioNumber(FTrack, 'frame_count') - Min(StudioNumber(FTrack, 'frame_count'), Round(FViewSeconds * LRate)))));
  FWindowEnd := Min(StudioNumber(FTrack, 'frame_count'),
    FWindowStart + Max(1, Round(LRate * FViewSeconds)));
  FAnalysis := nil;
  El('source-analysis-status').textContent := 'Analyze up to 30 seconds from the playhead for levels and suggested beats.';
  El('source-beat-layer').innerHTML := '<option value="-1">No beat overlay</option>';
  FBins := nil;
  El('source-waveform-state').textContent := 'Loading waveform…';
  El('source-waveform-state').className := 'hint';
  El('source-waveform-retry').setAttribute('hidden', '');
  FCanvas.setAttribute('aria-busy', 'true');
  DrawWaveform;
  El('source-window').textContent := StudioTime(FWindowStart / LRate) + '–' +
    StudioTime(FWindowEnd / LRate);
  Input('source-view-length').value := StudioTime((FWindowEnd - FWindowStart) / LRate);
  El('source-view-whole').setAttribute('aria-pressed', BoolToStr(
    (FWindowStart = 0) and (FWindowEnd = StudioNumber(FTrack, 'frame_count')), 'true', 'false'));
  TJSHTMLButtonElement(El('source-prev')).disabled := FDisabled or (FWindowStart = 0);
  TJSHTMLButtonElement(El('source-next')).disabled := FDisabled or (FWindowEnd = StudioNumber(FTrack, 'frame_count'));
  try
    LEntry := StudioText(FTrack, 'entry_id');
    LPath := '/api/waveform?hash=' + LHash +
      '&start=' + FloatToStr(FWindowStart) + '&end=' + FloatToStr(FWindowEnd) +
      '&bins=' + FloatToStr(Min(128, FWindowEnd - FWindowStart)) + '&sampled=1';
    if (LEntry <> '') and (StudioText(FTrack, 'status') = 'available') then
    begin
      LPath := '/api/studio/library-waveform?entry=' + encodeURIComponent(LEntry) +
        '&revision=' + FloatToStr(StudioNumber(FTrack, 'discovery_revision')) +
        '&snapshot=' + StudioText(FTrack, 'entry_snapshot_sha256') +
        '&start=' + FloatToStr(FWindowStart) + '&end=' + FloatToStr(FWindowEnd) +
        '&bins=' + FloatToStr(Min(128, FWindowEnd - FWindowStart));
    end;
    LResponse := await(TJSResponse, FFetch(LPath, 'GET', ''));
    if LResponse.status <> 200 then
    begin
      raise Exception.Create('Waveform unavailable. Check the recording or reconnect, then retry.');
    end;
    LData := await(TJSObject, LResponse.json());
    if LEpoch <> FEpoch then
    begin
      Exit;
    end;
    if Pos('/api/studio/library-waveform?', LPath) = 1 then
    begin
      if (StudioText(LData, 'format') <> 'pythian.studio.library.waveform.v1') or
        (StudioText(LData, 'content_validation') <> 'metadata_only_unverified') or
        (StudioText(LData, 'sampling') <> 'uniform_windows') or
        (StudioText(LData, 'entry_id') <> LEntry) or
        (StudioText(LData, 'entry_snapshot_sha256') <>
          StudioText(FTrack, 'entry_snapshot_sha256')) or
        (StudioNumber(LData, 'discovery_revision') <>
          StudioNumber(FTrack, 'discovery_revision')) or
        (StudioNumber(LData, 'source_start_frame') <> FWindowStart) or
        (StudioNumber(LData, 'source_end_frame') <> FWindowEnd) then
      begin
        raise Exception.Create('Original changed. Refresh and reopen this recording.');
      end;
    end
    else if (StudioText(LData, 'source_sha256') <> LHash) or
      (StudioNumber(LData, 'start_frame') <> FWindowStart) or
      (StudioNumber(LData, 'end_frame') <> FWindowEnd) then
    begin
      raise Exception.Create('Waveform identity changed. Reload this recording.');
    end;
    FBins := TJSArray(LData['bins']);
    if not isArray(LData['bins']) or (FBins.length = 0) then
      raise Exception.Create('Waveform unavailable. You can still try Play.');
    El('source-waveform-state').textContent := 'Tap to seek. Drag to select a passage.';
    FCanvas.setAttribute('aria-busy', 'false');
    DrawWaveform;
  except
    on LError: Exception do
    begin
      if LEpoch = FEpoch then
      begin
        El('source-waveform-state').textContent := LError.Message;
        El('source-waveform-state').className := 'field-error';
        El('source-waveform-retry').removeAttribute('hidden');
        FCanvas.setAttribute('aria-busy', 'false');
      end;
    end;
  else
    if LEpoch = FEpoch then
    begin
      El('source-waveform-state').textContent := 'Waveform could not load. Try again.';
      El('source-waveform-state').className := 'field-error';
      El('source-waveform-retry').removeAttribute('hidden');
      FCanvas.setAttribute('aria-busy', 'false');
    end;
  end;
end;

procedure TStudioSourceEditor.ResizeView(const ASeconds: Double);
begin
  if FTrack = nil then
  begin
    Exit;
  end;
  FViewSeconds := Min(StudioNumber(FTrack, 'frame_count') /
    StudioNumber(FTrack, 'sample_rate'), Max(0.1, ASeconds));
  WindowAt(FPosition - FViewSeconds / 2);
end;

procedure TStudioSourceEditor.Analyze; async;
var
  LRequest: TJSObject;
  LJob: TJSObject;
  LProposal: TJSObject;
  LCandidates: TJSArray;
  LResponse: TJSResponse;
  LJobId: String;
  LStatus: String;
  LEpoch: Integer;
  LAttempt: Integer;
  LIndex: Integer;
  LOption: TJSElement;
  LStart: Double;
  LEnd: Double;
begin
  if (FTrack = nil) or FAnalysisBusy then
  begin
    Exit;
  end;
  if (StudioText(FTrack, 'source_sha256') = '') or
    ((StudioText(FTrack, 'entry_id') <> '') and
    (StudioText(FTrack, 'prepared_snapshot') <>
      StudioText(FTrack, 'entry_snapshot_sha256'))) then
  begin
    PrepareRecording(nil, True);
    Exit;
  end;
  FAnalysisBusy := True;
  LEpoch := FEpoch;
  LJobId := 'inspect-' + FloatToStr(TJSDate.now) + '-' + IntToStr(Random(100000000));
  TJSHTMLButtonElement(El('source-analyze')).disabled := True;
  LStart := Floor(FPosition * StudioNumber(FTrack, 'sample_rate'));
  LEnd := Min(StudioNumber(FTrack, 'frame_count'), LStart +
    Min(2000000, 30 * StudioNumber(FTrack, 'sample_rate')));
  El('source-analysis-status').textContent := 'Analyzing ' + StudioTime(LStart /
    StudioNumber(FTrack, 'sample_rate')) + '–' + StudioTime(LEnd /
    StudioNumber(FTrack, 'sample_rate')) + '…';
  try
    LRequest := TJSObject.new;
    LRequest['format'] := 'pythian.studio.job.write.v1';
    LRequest['job_id'] := LJobId;
    LRequest['kind'] := 'inspect_source';
    LRequest['source_sha256'] := StudioText(FTrack, 'source_sha256');
    LRequest['start_frame'] := LStart;
    LRequest['end_frame'] := LEnd;
    LResponse := await(TJSResponse, FFetch('/api/studio/job', 'POST', TJSJSON.stringify(LRequest)));
    if LResponse.status <> 200 then
    begin
      raise Exception.Create(await(String, LResponse.text()));
    end;
    LJob := await(TJSObject, LResponse.json());
    LStatus := StudioText(LJob, 'status');
    LAttempt := 0;
    while (LStatus = 'queued') or (LStatus = 'running') do
    begin
      Inc(LAttempt);
      if LAttempt > 660 then
      begin
        raise Exception.Create('Analysis is still pending. Check the job list.');
      end;
      await(JSValue, TJSPromise.new(
        procedure(AResolve, AReject: TJSPromiseResolver)
        begin
          window.setTimeout(procedure() begin AResolve(True); end, 1000);
        end));
      LResponse := await(TJSResponse, FFetch('/api/studio/job?id=' + LJobId, 'GET', ''));
      if LResponse.status <> 200 then
      begin
        raise Exception.Create('Could not check analysis. Your source selection is preserved.');
      end;
      LJob := await(TJSObject, LResponse.json());
      LStatus := StudioText(LJob, 'status');
      if LEpoch = FEpoch then
      begin
        El('source-analysis-status').textContent := 'Analysis: ' + StudioText(LJob, 'stage');
      end;
    end;
    if LStatus <> 'completed' then
    begin
      raise Exception.Create(StudioText(LJob, 'error_message'));
    end;
    if LEpoch = FEpoch then
    begin
      FAnalysis := TJSObject(LJob['results']);
      if StudioText(FAnalysis, 'source_sha256') <> StudioText(FTrack, 'source_sha256') then
      begin
        FAnalysis := nil;
        raise Exception.Create('Analysis source differs. Run inspection again.');
      end;
      El('source-analysis-status').textContent := 'Measured signal · RMS ' +
        FormatFloat('0.0000', StudioNumber(FAnalysis, 'rms')) + ' · Peak ' +
        FormatFloat('0.0000', StudioNumber(FAnalysis, 'peak')) +
        ' · ' + StudioTime(StudioNumber(FAnalysis, 'start_frame') /
          StudioNumber(FAnalysis, 'sample_rate')) + '–' +
        StudioTime(StudioNumber(FAnalysis, 'end_frame') /
          StudioNumber(FAnalysis, 'sample_rate'));
      LProposal := TJSObject(FAnalysis['beat_proposal']);
      El('source-beat-layer').innerHTML := '';
      LOption := Add(El('source-beat-layer'), 'option', 'No beat overlay', '');
      LOption.setAttribute('value', '-1');
      LCandidates := TJSArray(LProposal['candidates']);
      if isArray(LCandidates) then
      begin
        for LIndex := 0 to LCandidates.length - 1 do
        begin
          LOption := Add(El('source-beat-layer'), 'option',
            FormatFloat('0.0', StudioNumber(TJSObject(LCandidates[LIndex]), 'bpm')) +
            ' BPM candidate ' + IntToStr(LIndex + 1), '');
          LOption.setAttribute('value', IntToStr(LIndex));
        end;
      end;
      DrawWaveform;
    end;
  except
    on LError: Exception do
    begin
      if LEpoch = FEpoch then
      begin
        El('source-analysis-status').textContent := 'Analysis unavailable: ' + LError.Message;
      end;
    end;
  else
    if LEpoch = FEpoch then
    begin
      El('source-analysis-status').textContent := 'Analysis connection failed. Retry when ready.';
    end;
  end;
  FAnalysisBusy := False;
  TJSHTMLButtonElement(El('source-analyze')).disabled := FDisabled;
end;

procedure TStudioSourceEditor.DrawWaveform;
var
  LContext: TJSCanvasRenderingContext2D;
  LIndex: Integer;
  LBin: TJSObject;
  LStart: Double;
  LEnd: Double;
  LRate: Double;
  LX: Double;
  LScale: Double;
  LCandidate: Integer;
  LProposal: TJSObject;
  LCandidates: TJSArray;
  LFrames: TJSArray;
begin
  LContext := FCanvas.getContextAs2DContext('2d');
  LContext.fillStyleAsColor := '#0b1e26';
  LContext.fillRect(0, 0, FCanvas.width, FCanvas.height);
  if (FTrack = nil) or (FWindowEnd <= FWindowStart) then
  begin
    Exit;
  end;
  LRate := StudioNumber(FTrack, 'sample_rate');
  LScale := FCanvas.width / (FWindowEnd - FWindowStart);
  if ReadRange(LStart, LEnd) then
  begin
    LContext.fillStyleAsColor := '#214d50';
    LContext.fillRect((LStart * LRate - FWindowStart) * LScale, 0,
      (LEnd - LStart) * LRate * LScale, FCanvas.height);
  end;
  LContext.fillStyleAsColor := '#a0ddcb';
  if (FBins <> nil) and (FBins.length > 0) then
  begin
    for LIndex := 0 to FBins.length - 1 do
    begin
      LBin := TJSObject(FBins[LIndex]);
      if isNumber(LBin['peak']) then
      begin
        LContext.fillRect(LIndex * FCanvas.width / FBins.length,
          90 - StudioNumber(LBin, 'peak') * 75, FCanvas.width / FBins.length + 1,
          Max(1, StudioNumber(LBin, 'peak') * 150));
      end
      else
      begin
        LContext.fillRect(LIndex * FCanvas.width / FBins.length,
          90 - StudioNumber(LBin, 'max') * 75, FCanvas.width / FBins.length + 1,
          Max(1, (StudioNumber(LBin, 'max') - StudioNumber(LBin, 'min')) * 75));
      end;
    end;
  end;
  LX := (FPosition * LRate - FWindowStart) * LScale;
  LContext.fillStyleAsColor := '#fff4ce';
  LContext.fillRect(LX, 0, 2, FCanvas.height);
  LCandidate := StrToIntDef(TJSHTMLSelectElement(El('source-beat-layer')).value, -1);
  if (FAnalysis <> nil) and (LCandidate >= 0) then
  begin
    LProposal := TJSObject(FAnalysis['beat_proposal']);
    LCandidates := TJSArray(LProposal['candidates']);
    if isArray(LCandidates) and (LCandidate < LCandidates.length) then
    begin
      LFrames := TJSArray(TJSObject(LCandidates[LCandidate])['frames']);
      LContext.fillStyleAsColor := '#ebbf76';
      for LIndex := 0 to LFrames.length - 1 do
      begin
        LX := (Double(LFrames[LIndex]) - FWindowStart) * LScale;
        LContext.fillRect(LX, 130, 2, 45);
      end;
    end;
  end;
end;

procedure TStudioSourceEditor.SaveSelection(const AWhole: Boolean);
var
  LStart: Double;
  LEnd: Double;
  LRate: Double;
  LRow: TJSObject;
  LPrior: TJSObject;
  LClasses: TJSArray;
  LParts: TStringDynArray;
  LIndex: Integer;
  LText: String;
begin
  if FTrack = nil then
  begin
    Exit;
  end;
  LRate := StudioNumber(FTrack, 'sample_rate');
  if AWhole then
  begin
    LStart := 0;
    LEnd := StudioNumber(FTrack, 'frame_count');
  end
  else
  begin
    if not ReadRange(LStart, LEnd) then
    begin
      Notice('Use valid start and end times within this recording, such as 0:15 to 0:30.', True);
      Exit;
    end;
    LStart := Floor(LStart * LRate);
    LEnd := Min(StudioNumber(FTrack, 'frame_count'), Ceil(LEnd * LRate));
  end;
  for LIndex := 0 to FSelections.length - 1 do
  begin
    LPrior := TJSObject(FSelections[LIndex]);
    if (LIndex <> FEditing) and
      (StudioText(LPrior, 'source_sha256') = StudioText(FTrack, 'source_sha256')) and
      (LStart < StudioNumber(LPrior, 'end_frame')) and
      (LEnd > StudioNumber(LPrior, 'start_frame')) then
    begin
      Notice('This overlaps an existing corpus selection. Edit or remove that selection first.', True);
      Exit;
    end;
  end;
  LClasses := TJSArray.new;
  LParts := SplitString(Input('source-classifications').value, ',');
  for LIndex := 0 to High(LParts) do
  begin
    LText := Trim(LParts[LIndex]);
    if LText = '' then
    begin
      Continue;
    end;
    if (Length(LText) > 64) or (LClasses.length >= 8) then
    begin
      Notice('Use up to eight classifications, each up to 64 characters.', True);
      Exit;
    end;
    if LClasses.indexOf(LText) < 0 then
    begin
      LClasses.push(LText);
    end;
  end;
  LRow := TJSObject.new;
  LRow['source_sha256'] := StudioText(FTrack, 'source_sha256');
  LRow['selection'] := 'range';
  if AWhole then
  begin
    LRow['selection'] := 'full';
  end;
  LRow['start_frame'] := LStart;
  LRow['end_frame'] := LEnd;
  LRow['range_invalid'] := False;
  LRow['classifications'] := LClasses;
  if (StudioText(FTrack, 'entry_id') <> '') and
    (StudioText(FTrack, 'prepared_snapshot') <>
      StudioText(FTrack, 'entry_snapshot_sha256')) then
  begin
    PrepareRecording(LRow, False);
    Exit;
  end;
  ApplySelection(LRow, FEditing);
end;

procedure TStudioSourceEditor.ApplySelection(ARow: TJSObject; const AEditing: Integer);
var
  LIndex: Integer;
  LPrior: TJSObject;
begin
  for LIndex := 0 to FSelections.length - 1 do
  begin
    LPrior := TJSObject(FSelections[LIndex]);
    if (LIndex <> AEditing) and
      (StudioText(LPrior, 'source_sha256') = StudioText(ARow, 'source_sha256')) and
      (StudioNumber(ARow, 'start_frame') < StudioNumber(LPrior, 'end_frame')) and
      (StudioNumber(ARow, 'end_frame') > StudioNumber(LPrior, 'start_frame')) then
    begin
      Notice('This overlaps an existing corpus selection. Edit it instead.', True);
      Exit;
    end;
  end;
  if AEditing >= 0 then
  begin
    if AEditing >= FSelections.length then
    begin
      Notice('The selection changed. Add the passage again.', True);
      Exit;
    end;
    FSelections[AEditing] := ARow;
  end
  else
  begin
    if FSelections.length >= 64 then
    begin
      Notice('This corpus already has 64 selections.', True);
      Exit;
    end;
    FSelections.push(ARow);
  end;
  FEditing := -1;
  El('source-use-range').textContent := 'Add another passage';
  FChanged;
  DrawTracks;
  Notice('Added to this corpus. Save the project to preserve your selection and classifications.');
end;

procedure TStudioSourceEditor.PrepareRecording(ASelection: TJSObject;
  const AAnalyze: Boolean);
var
  LWrite: TJSObject;
  LEntry: TJSObject;
  LEntries: TJSArray;
begin
  if (FTrack = nil) or (StudioText(FTrack, 'entry_id') = '') then
  begin
    Exit;
  end;
  if (FPrepareEntry <> '') and
    ((StudioText(FPreparation.CurrentJob, 'status') <> 'completed') and
    (StudioText(FPreparation.CurrentJob, 'status') <> 'failed') and
    (StudioText(FPreparation.CurrentJob, 'status') <> 'cancelled')) then
  begin
    Notice('Preparation is pending. Check its progress or cancel before trying again.');
    Exit;
  end;
  FPrepareSelection := ASelection;
  FPrepareEntry := StudioText(FTrack, 'entry_id');
  FPrepareEditing := FEditing;
  FPrepareAnalyze := AAnalyze;
  FPrepareDraft := FSelections;
  FPreparePrior := nil;
  if FEditing >= 0 then
  begin
    FPreparePrior := TJSObject(FSelections[FEditing]);
  end;
  FPrepareWindowStart := FWindowStart;
  FPrepareWindowEnd := FWindowEnd;
  if CompletedForTrack then
  begin
    ApplyPrepared;
    Exit;
  end;
  LWrite := TJSObject.new;
  LWrite['discovery_revision'] := StudioNumber(FTrack, 'discovery_revision');
  LEntries := TJSArray.new;
  LEntry := TJSObject.new;
  LEntry['entry_id'] := FPrepareEntry;
  LEntry['entry_snapshot_sha256'] := StudioText(FTrack, 'entry_snapshot_sha256');
  LEntries.push(LEntry);
  LWrite['entries'] := LEntries;
  if not FPreparation.Prepare(LWrite) then
  begin
    FPrepareEntry := '';
    FPrepareSelection := nil;
    Notice('Checking preparation status. Try this action again when it is ready.');
    Exit;
  end;
  if ASelection <> nil then
  begin
    El('source-preparation-purpose').textContent := 'Preparing this recording to add your selection to the project.';
  end
  else if AAnalyze then
  begin
    El('source-preparation-purpose').textContent := 'Preparing this recording, then analyzing at the playhead.';
  end
  else
  begin
    El('source-preparation-purpose').textContent := 'Preparing this recording for analysis and effects.';
  end;
  Notice('Your passage and project are preserved.');
  TJSHTMLElement(El('source-preparation-purpose')).scrollIntoView;
end;

procedure TStudioSourceEditor.PreparationDone;
begin
  ApplyPrepared;
end;

procedure TStudioSourceEditor.PreparationState;
var
  LJob: TJSObject;
  LStatus: String;
begin
  LJob := FPreparation.CurrentJob;
  LStatus := StudioText(LJob, 'status');
  if FTrack = nil then
  begin
    Exit;
  end;
  if CompletedForTrack and (StudioText(FTrack, 'prepared_snapshot') <>
    StudioText(FTrack, 'entry_snapshot_sha256')) then
  begin
    El('source-prepare').textContent := 'Use prepared recording';
    El('source-preparation-purpose').textContent := 'Already prepared. Load it for analysis and effects.';
  end
  else
  begin
    El('source-prepare').textContent := 'Prepare for analysis & effects';
  end;
  if ((LStatus = 'failed') or (LStatus = 'cancelled')) and
    (FPrepareEntry = StudioText(FTrack, 'entry_id')) then
  begin
    Notice('Preparation ' + LStatus + '. Your passage and project are preserved.',
      LStatus = 'failed');
  end;
end;

procedure TStudioSourceEditor.ApplyPrepared; async;
var
  LJob: TJSObject;
  LResult: TJSObject;
  LMappings: TJSArray;
  LMapping: TJSObject;
  LResponse: TJSResponse;
  LData: TJSObject;
  LRows: TJSArray;
  LSource: TJSObject;
  LTrack: TJSObject;
  LIndex: Integer;
  LKey: String;
  LSelection: TJSObject;
  LAnalyze: Boolean;
  LPrevious: TJSObject;
  LCollections: TJSArray;
  LTargetCollections: TJSArray;
  LCollection: TJSObject;
  LCollectionIndex: Integer;
  LTargetIndex: Integer;
  LFoundCollection: Boolean;
  LNames: TStringDynArray;
  LName: String;
begin
  LJob := FPreparation.CurrentJob;
  if LJob = nil then
  begin
    Exit;
  end;
  try
    LResult := TJSObject(LJob['results']);
    if (LResult = nil) or not isArray(LResult['mappings']) then
    begin
      raise Exception.Create('Preparation returned no verified source. Retry its status.');
    end;
    LMappings := TJSArray(LResult['mappings']);
    if LMappings.length <> 1 then
    begin
      raise Exception.Create('Preparation differs from the selected recording.');
    end;
    LMapping := TJSObject(LMappings[0]);
    LKey := StudioText(LMapping, 'entry_id');
    if (FPrepareEntry <> '') and (LKey <> FPrepareEntry) then
    begin
      raise Exception.Create('Preparation has a different entry identity.');
    end;
    if (Length(StudioText(LMapping, 'source_sha256')) <> 64) or
      ((StudioText(LMapping, 'status') <> 'existing') and
      (StudioText(LMapping, 'status') <> 'imported')) then
    begin
      raise Exception.Create('Preparation has no accepted content identity.');
    end;
    LResponse := await(TJSResponse, FFetch('/api/studio/sources', 'GET', ''));
    if LResponse.status <> 200 then
    begin
      raise Exception.Create('Recording prepared; reopen or retry to load its catalog details.');
    end;
    LData := await(TJSObject, LResponse.json());
    if StudioText(FPreparation.CurrentJob, 'job_id') <> StudioText(LJob, 'job_id') then
    begin
      Exit;
    end;
    if (StudioText(LData, 'format') <> 'pythian.studio.sources.v1') or
      not isArray(LData['sources']) then
    begin
      raise Exception.Create('Prepared catalog details are unavailable.');
    end;
    LRows := TJSArray(LData['sources']);
    LSource := nil;
    for LIndex := 0 to LRows.length - 1 do
    begin
      if StudioText(TJSObject(LRows[LIndex]), 'source_sha256') =
        StudioText(LMapping, 'source_sha256') then
      begin
        LSource := TJSObject(LRows[LIndex]);
        Break;
      end;
    end;
    if LSource = nil then
    begin
      raise Exception.Create('Prepared recording is absent from the catalog.');
    end;
    if StudioText(LSource, 'partition') = 'evaluation' then
    begin
      raise Exception.Create('Evaluation recordings cannot be added to a training corpus.');
    end;
    LTrack := nil;
    for LIndex := 0 to FTracks.length - 1 do
    begin
      if (StudioText(TJSObject(FTracks[LIndex]), 'entry_id') = LKey) and
        (StudioText(TJSObject(FTracks[LIndex]), 'entry_snapshot_sha256') =
          StudioText(LMapping, 'entry_snapshot_sha256')) then
      begin
        LTrack := TJSObject(FTracks[LIndex]);
        Break;
      end;
    end;
    if LTrack = nil then
    begin
      raise Exception.Create('The collection snapshot changed. Refresh and prepare again.');
    end;
    if (StudioText(LTrack, 'source_sha256') <> '') and
      (StudioText(LTrack, 'source_sha256') <> StudioText(LSource, 'source_sha256')) then
    begin
      { Preserve the old immutable catalog row for saved corpus selections. }
      LPrevious := TJSObject(TJSJSON.parse(TJSJSON.stringify(LTrack)));
      LPrevious['entry_id'] := '';
      LPrevious['entry_snapshot_sha256'] := '';
      LPrevious['title'] := StudioText(LPrevious, 'title') + ' (saved recording)';
      FTracks.push(LPrevious);
    end;
    LNames := ['source_sha256', 'partition', 'sample_rate', 'frame_count',
      'channels', 'source_bytes', 'metadata_sha256', 'license', 'provenance',
      'source_group', 'clock_id', 'bits_per_sample'];
    for LIndex := 0 to High(LNames) do
    begin
      LName := LNames[LIndex];
      if LSource.hasOwnProperty(LName) then
      begin
        LTrack[LName] := LSource[LName];
      end;
    end;
    LIndex := FTracks.length - 1;
    while LIndex >= 0 do
    begin
      LPrevious := TJSObject(FTracks[LIndex]);
      if (LPrevious <> LTrack) and
        (StudioText(LPrevious, 'source_sha256') = StudioText(LSource, 'source_sha256')) then
      begin
        LCollections := TJSArray(LPrevious['collections']);
        if isArray(LCollections) then
        begin
          LTargetCollections := TJSArray(LTrack['collections']);
          if not isArray(LTargetCollections) then
          begin
            LTargetCollections := TJSArray.new;
            LTrack['collections'] := LTargetCollections;
          end;
          for LCollectionIndex := 0 to LCollections.length - 1 do
          begin
            LCollection := TJSObject(LCollections[LCollectionIndex]);
            LFoundCollection := False;
            for LTargetIndex := 0 to LTargetCollections.length - 1 do
            begin
              if (StudioText(TJSObject(LTargetCollections[LTargetIndex]), 'collection_id') =
                StudioText(LCollection, 'collection_id')) and
                (StudioText(TJSObject(LTargetCollections[LTargetIndex]), 'name') =
                StudioText(LCollection, 'name')) then
              begin
                LFoundCollection := True;
                Break;
              end;
            end;
            if not LFoundCollection then
            begin
              LTargetCollections.push(TJSObject(TJSJSON.parse(TJSJSON.stringify(LCollection))));
            end;
          end;
        end;
        FTracks.splice(LIndex, 1);
      end;
      Dec(LIndex);
    end;
    LTrack['prepared_snapshot'] := StudioText(LMapping, 'entry_snapshot_sha256');
    LSelection := FPrepareSelection;
    LAnalyze := FPrepareAnalyze;
    FPrepareSelection := nil;
    FPrepareEntry := '';
    FPrepareAnalyze := False;
    if (FTrack <> nil) and (StudioText(FTrack, 'entry_id') = LKey) then
    begin
      El('source-prepare').setAttribute('hidden', '');
      El('source-preparation-purpose').textContent := 'Ready for project use, analysis and effects.';
      if LSelection <> nil then
      begin
        if (FSelections <> FPrepareDraft) or
          ((FPrepareEditing >= 0) and
          ((FPrepareEditing >= FSelections.length) or
          (TJSObject(FSelections[FPrepareEditing]) <> FPreparePrior))) then
        begin
          Notice('Recording prepared. Your project changed; add the passage again.');
        end
        else
        begin
          LSelection['source_sha256'] := StudioText(LSource, 'source_sha256');
          ApplySelection(LSelection, FPrepareEditing);
        end;
      end
      else
      begin
        Notice('');
      end;
      if LAnalyze and (FSelections = FPrepareDraft) and
        (FWindowStart = FPrepareWindowStart) and (FWindowEnd = FPrepareWindowEnd) then
      begin
        Analyze;
      end;
    end
    else
    begin
      Notice('Recording prepared. Open it to add your passage.');
    end;
    DrawTracks;
  except
    on LException: Exception do
    begin
      Notice(LException.Message + ' Your project is preserved.', True);
    end;
  end;
end;

function TStudioSourceEditor.CompletedForTrack: Boolean;
var
  LJob: TJSObject;
  LResult: TJSObject;
  LMappings: TJSArray;
begin
  Result := False;
  LJob := FPreparation.CurrentJob;
  if (FTrack = nil) or (StudioText(LJob, 'status') <> 'completed') then
  begin
    Exit;
  end;
  LResult := TJSObject(LJob['results']);
  if (LResult = nil) or not isArray(LResult['mappings']) then
  begin
    Exit;
  end;
  LMappings := TJSArray(LResult['mappings']);
  if LMappings.length = 1 then
  begin
    Result := (StudioText(TJSObject(LMappings[0]), 'entry_id') =
      StudioText(FTrack, 'entry_id')) and
      (StudioText(TJSObject(LMappings[0]), 'entry_snapshot_sha256') =
      StudioText(FTrack, 'entry_snapshot_sha256'));
  end;
end;

procedure TStudioSourceEditor.PlayRange(const AStart, AEnd: Double);
begin
  SeekTo(AStart, False);
  FPlayEnd := AEnd;
  FPlaying := True;
  PlayChunk;
end;

procedure TStudioSourceEditor.UpdateTransport;
begin
  if FTrack = nil then Exit;
  El('source-time').textContent := StudioTime(FPosition) + ' / ' +
    StudioTime(StudioNumber(FTrack, 'frame_count') / StudioNumber(FTrack, 'sample_rate'));
  if not FSeeking then Input('source-seek').value := FloatToStr(FPosition);
  Input('source-seek').setAttribute('aria-valuetext', StudioTime(FPosition));
  if document.activeElement <> Input('source-position') then
  begin
    Input('source-position').value := StudioTime(FPosition);
  end;
  El('source-play').setAttribute('data-playing', BoolToStr(FPlaying, 'true', 'false'));
  if FPlaying then
  begin
    El('source-play-label').textContent := 'Pause';
  end
  else
  begin
    El('source-play-label').textContent := 'Play';
  end;
  DrawWaveform;
end;

procedure TStudioSourceEditor.SeekTo(const ASeconds: Double; const AResume: Boolean);
var
  LRate: Double;
begin
  if FTrack = nil then Exit;
  Inc(FMediaEpoch);
  FPlaying := False;
  FSeeking := False;
  FPlayer.pause;
  FPlayer.removeAttribute('src');
  FPlayer.load;
  LRate := StudioNumber(FTrack, 'sample_rate');
  FPosition := Max(0, Min(ASeconds,
    (StudioNumber(FTrack, 'frame_count') - 1) / LRate));
  FPreviewStart := FPosition;
  FPlayEnd := StudioNumber(FTrack, 'frame_count') / LRate;
  El('source-playback-status').textContent := 'Ready at ' + StudioTime(FPosition) + '.';
  UpdateTransport;
  if (FPosition * LRate < FWindowStart) or (FPosition * LRate >= FWindowEnd) then
  begin
    WindowAt(FPosition);
  end;
  if AResume then
  begin
    FPlaying := True;
    PlayChunk;
  end;
end;

procedure TStudioSourceEditor.PlayChunk; async;
var
  LRate: Double;
  LStart: Double;
  LEnd: Double;
  LEntry: String;
  LPath: String;
  LEpoch: Integer;
begin
  if (FTrack = nil) or not FPlaying then Exit;
  Inc(FMediaEpoch);
  LEpoch := FMediaEpoch;
  LRate := StudioNumber(FTrack, 'sample_rate');
  LStart := Floor(FPosition * LRate + 0.000001);
  LEnd := Min(StudioNumber(FTrack, 'frame_count'),
    Min(Ceil(FPlayEnd * LRate), LStart + Min(Floor(30 * LRate), 2000000)));
  if LEnd <= LStart then
  begin
    FPlaying := False;
    UpdateTransport;
    Exit;
  end;
  LPath := '/api/audio?hash=' + StudioText(FTrack, 'source_sha256');
  LEntry := StudioText(FTrack, 'entry_id');
  if (LEntry <> '') and (StudioText(FTrack, 'status') = 'available') then
  begin
    LPath := '/api/studio/library-audio?entry=' + encodeURIComponent(LEntry) +
      '&revision=' + FloatToStr(StudioNumber(FTrack, 'discovery_revision')) +
      '&snapshot=' + StudioText(FTrack, 'entry_snapshot_sha256');
  end;
  ReplacePlayer;
  FPreviewStart := LStart / LRate;
  FPosition := FPreviewStart;
  FChunkEnd := LEnd / LRate;
  FPlayer.src := LPath + '&start=' + FloatToStr(LStart) + '&end=' + FloatToStr(LEnd);
  FPlayer.load;
  El('source-playback-status').textContent := 'Loading audio at ' + StudioTime(FPosition) + '…';
  UpdateTransport;
  try
    await(FPlayer.play());
  except
    { Big Boss: a replaced seek/pause rejects the old play promise normally.
      Only the current request may report failure or change transport state. }
    if (LEpoch = FMediaEpoch) and (FTrack <> nil) then
    begin
      FPlaying := False;
      El('source-playback-status').textContent := 'Audio could not play. Retry Play, or reconnect if the server restarted.';
      El('source-reconnect').removeAttribute('hidden');
      UpdateTransport;
    end;
  end;
end;

function TStudioSourceEditor.Click(AEvent: TJSMouseEvent): Boolean;
var
  LButton: TJSElement;
  LAction: String;
  LValue: String;
  LIndex: Integer;
  LStart: Double;
  LEnd: Double;
begin
  Result := False;
  if FDisabled then
  begin
    Exit;
  end;
  LButton := TJSElement(AEvent.currentTarget);
  LAction := LButton.getAttribute('data-action');
  LValue := LButton.getAttribute('data-value');
  case LAction of
    'collection':
      begin
        TJSHTMLSelectElement(El('collection-filter')).value := LValue;
        DrawTracks;
        if document.getElementById(LButton.id) <> nil then
        begin
          TJSHTMLElement(El(LButton.id)).focus;
        end;
        Exit;
      end;
    'open': OpenTrack(LValue, -1);
    'edit':
      begin
        LIndex := StrToInt(LValue);
        OpenTrack(StudioText(TJSObject(FSelections[LIndex]), 'source_sha256'), LIndex);
      end;
    'remove':
      begin
        FSelections.splice(StrToInt(LValue), 1);
        FEditing := -1;
        FChanged;
        DrawTracks;
      end;
  end;
  if FTrack = nil then
  begin
    Exit;
  end;
  case LButton.id of
    'source-close': Reset;
    'source-analyze': Analyze;
    'source-prepare':
      begin
        if CompletedForTrack then
        begin
          ApplyPrepared;
        end
        else
        begin
          PrepareRecording(nil, False);
        end;
      end;
    'source-mark-in': Input('source-start').value := StudioTime(FPosition);
    'source-mark-out': Input('source-end').value := StudioTime(FPosition);
    'source-prev':
      begin
        LStart := Max(0, FWindowStart / StudioNumber(FTrack, 'sample_rate') - FViewSeconds);
        WindowAt(LStart);
        SeekTo(LStart, FPlaying);
      end;
    'source-next':
      begin
        LStart := FWindowEnd / StudioNumber(FTrack, 'sample_rate');
        WindowAt(LStart);
        SeekTo(LStart, FPlaying);
      end;
    'source-zoom-in': ResizeView(FViewSeconds / 2);
    'source-zoom-out': ResizeView(FViewSeconds * 2);
    'source-view-whole': ResizeView(StudioNumber(FTrack, 'frame_count') / StudioNumber(FTrack, 'sample_rate'));
    'source-view-apply':
    begin
      if ParseSourceTime(Input('source-view-length').value, LStart) and (LStart > 0) then
      begin
        ResizeView(LStart);
      end
      else
      begin
        Notice('Enter a positive view length as minutes:seconds, for example 2:00.', True);
      end;
    end;
    'source-go':
    begin
      if ParseSourceTime(Input('source-position').value, LStart) and
        (LStart < StudioNumber(FTrack, 'frame_count') / StudioNumber(FTrack, 'sample_rate')) then
      begin
        SeekTo(LStart, FPlaying);
      end
      else
      begin
        Notice('Enter a position inside the recording as minutes:seconds.', True);
      end;
    end;
    'source-waveform-retry': WindowAt(FWindowStart / StudioNumber(FTrack, 'sample_rate'));
    'source-play':
      begin
        if FPlaying then
        begin
          if (FPlayer.readyState >= 1) and (FPlayer.currentSrc = FPlayer.src) then
            FPosition := Min(FChunkEnd, FPreviewStart + FPlayer.currentTime);
          Inc(FMediaEpoch);
          FPlaying := False;
          FPlayer.pause;
          El('source-playback-status').textContent := 'Paused at ' + StudioTime(FPosition) + '.';
          UpdateTransport;
        end
        else
        begin
          if FPosition >= FPlayEnd then
            FPlayEnd := StudioNumber(FTrack, 'frame_count') / StudioNumber(FTrack, 'sample_rate');
          if FPosition >= FPlayEnd then SeekTo(0, False);
          FPlaying := True;
          PlayChunk;
        end;
      end;
    'source-use-range': SaveSelection(False);
    'source-use-whole': SaveSelection(True);
    'source-play-range':
      begin
        if ReadRange(LStart, LEnd) then
        begin
          PlayRange(LStart, LEnd);
        end
        else
        begin
          Notice('Choose a valid passage before playing it.', True);
        end;
      end;
  end;
  DrawWaveform;
end;

function TStudioSourceEditor.Edit(AEvent: TEventListenerEvent): Boolean;
var
  LId: String;
begin
  Result := False;
  LId := TJSElement(AEvent.target).id;
  if LId = 'collection-filter' then
  begin
    DrawTracks;
    Exit;
  end;
  if LId = 'source-beat-layer' then
  begin
    DrawWaveform;
    Exit;
  end;
  if FDisabled or (FTrack = nil) then
  begin
    Exit;
  end;
  if LId = 'source-seek' then
  begin
    if AEvent._type = 'input' then
    begin
      if not FSeeking then
      begin
        FResumeAfterSeek := FPlaying;
        FSeeking := True;
        Inc(FMediaEpoch);
        FPlaying := False;
        FPlayer.pause;
      end;
      FPosition := StrToFloat(Input('source-seek').value);
      El('source-playback-status').textContent := 'Seek to ' + StudioTime(FPosition) + '.';
      UpdateTransport;
    end
    else
      SeekTo(StrToFloat(Input('source-seek').value), FSeeking and FResumeAfterSeek);
  end
  else
  begin
    Notice('Selection changed. Add it below to keep these changes.');
  end;
  DrawWaveform;
end;

function TStudioSourceEditor.LeavePage(AEvent: TEventListenerEvent): Boolean;
begin
  Reset;
  Result := False;
end;

function TStudioSourceEditor.Playback(AEvent: TEventListenerEvent): Boolean;
begin
  Result := False;
  if (AEvent.target <> FPlayer) or (FTrack = nil) or FSeeking or not FPlaying then
  begin
    Exit;
  end;
  if AEvent._type = 'error' then
  begin
    if FPlayer.error = nil then Exit;
    FPlaying := False;
    El('source-playback-status').textContent := 'Audio could not load. Retry Play, or reconnect if the server restarted.';
    El('source-reconnect').removeAttribute('hidden');
    UpdateTransport;
    Exit;
  end;
  if (FPlayer.readyState < 1) or (FPlayer.currentSrc <> FPlayer.src) then Exit;
  FPosition := Min(FChunkEnd, FPreviewStart + FPlayer.currentTime);
  if (AEvent._type = 'pause') and FPlayer.paused and not FPlayer.ended then
  begin
    Inc(FMediaEpoch);
    FPlaying := False;
    El('source-playback-status').textContent := 'Paused at ' + StudioTime(FPosition) + '.';
  end
  else if AEvent._type = 'playing' then
  begin
    El('source-playback-status').textContent := 'Playing';
    El('source-reconnect').setAttribute('hidden', '');
  end
  else if AEvent._type = 'waiting' then
    El('source-playback-status').textContent := 'Buffering audio…';
  if (AEvent._type = 'ended') and FPlayer.ended then
  begin
    FPosition := FChunkEnd;
    if FChunkEnd < FPlayEnd - 0.5 / StudioNumber(FTrack, 'sample_rate') then
    begin
      if FPosition * StudioNumber(FTrack, 'sample_rate') >= FWindowEnd then
      begin
        WindowAt(FPosition);
      end;
      PlayChunk;
    end
    else
    begin
      FPlaying := False;
      El('source-playback-status').textContent := 'Playback finished.';
    end;
  end;
  UpdateTransport;
end;

function TStudioSourceEditor.PointerFrame(AEvent: TJSPointerEvent): Double;
var
  LRect: TJSDOMRect;
begin
  LRect := FCanvas.getBoundingClientRect;
  Result := FWindowStart + Max(0, Min(1, (AEvent.clientX - LRect.left) / LRect.width)) *
    (FWindowEnd - FWindowStart);
end;

function TStudioSourceEditor.Down(AEvent: TJSPointerEvent): Boolean;
begin
  Result := False;
  if FDisabled or (FTrack = nil) then
  begin
    Exit;
  end;
  FDragging := True;
  FDragStart := PointerFrame(AEvent);
  FDragOldStart := Input('source-start').value;
  FDragOldEnd := Input('source-end').value;
  FCanvas.setPointerCapture(AEvent.pointerId);
end;

function TStudioSourceEditor.Move(AEvent: TJSPointerEvent): Boolean;
var
  LFrame: Double;
  LRate: Double;
begin
  Result := False;
  if FDragging and (FTrack <> nil) then
  begin
    LFrame := PointerFrame(AEvent);
    LRate := StudioNumber(FTrack, 'sample_rate');
    if Abs(LFrame - FDragStart) >= (FWindowEnd - FWindowStart) / 150 then
    begin
      SetRange(Min(FDragStart, LFrame) / LRate, Max(FDragStart, LFrame) / LRate);
    end;
  end;
end;

function TStudioSourceEditor.Up(AEvent: TJSPointerEvent): Boolean;
var
  LFrame: Double;
  LRate: Double;
begin
  Result := False;
  if FDragging and (FTrack <> nil) then
  begin
    FDragging := False;
    LFrame := PointerFrame(AEvent);
    LRate := StudioNumber(FTrack, 'sample_rate');
    if Abs(LFrame - FDragStart) < (FWindowEnd - FWindowStart) / 150 then
    begin
      SeekTo(LFrame / LRate, FPlaying);
      Input('source-start').value := FDragOldStart;
      Input('source-end').value := FDragOldEnd;
    end
    else
    begin
      SetRange(Min(FDragStart, LFrame) / LRate, Max(FDragStart, LFrame) / LRate);
    end;
    FCanvas.releasePointerCapture(AEvent.pointerId);
    DrawWaveform;
  end;
end;

function TStudioSourceEditor.CancelPointer(AEvent: TJSPointerEvent): Boolean;
begin
  Result := False;
  FDragging := False;
  Input('source-start').value := FDragOldStart;
  Input('source-end').value := FDragOldEnd;
  DrawWaveform;
end;

end.
