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
unit pythian.studio.batches;

{$mode delphi}
{$H+}

interface

uses
  JS,
  Web,
  SysUtils,
  pythian.studio.sources,
  pythian.workspace.tabs,
  pythian.studio.live,
  pythian.studio.progress;

type
  TStudioBatches = class
  private
    FFetch: TStudioFetch;
    FLive: TStudioLive;
    FProject: TJSObject;
    FUnsaved: Boolean;
    FBusy: Boolean;
    FRefreshing: Boolean;
    FConfigVersion: Integer;
    FEpoch: Integer;
    FTimer: NativeInt;
    FPollTimer: NativeInt;
    FRefreshTimer: NativeInt;
    FRefreshEpoch: Integer;
    FLoadEpoch: Integer;
    FRequest: TJSObject;
    FRetryRequest: TJSObject;
    FExplicitSeeds: TJSArray;
    FParentJobId: String;
    FPreparation: TJSObject;
    FPending: TJSObject;
    FPendingHash: String;
    FJobs: TJSArray;
    FJob: TJSObject;
    FSelectedId: String;
    FLastHistory: String;
    function El(const AId: String): TJSElement;
    function Add(AParent: TJSElement; const ATag, AText, AClass: String): TJSElement;
    function Button(AParent: TJSElement; const AId, AText: String): TJSElement;
    procedure SelectOption(ASelect: TJSElement; const AValue, AText: String);
    procedure Layout;
    procedure Notice(const AText: String; const AError: Boolean = False);
    procedure Invalidate;
    procedure UpdateControls;
    procedure DrawWeights;
    procedure DrawHistory;
    procedure DrawJob;
    function ReadInteger(const AId: String; const AMinimum, AMaximum: Integer): Integer;
    function NewId: String;
    function BuildRequest: TJSObject;
    function Json(const APath, AMethod, ABody: String): TJSObject; async;
    function MatchingJob(AJob: TJSObject): Boolean;
    procedure Prepare; async;
    procedure Submit; async;
    procedure ConfirmPending; async;
    procedure CancelJob; async;
    procedure LoadJob(const AId: String); async;
    procedure RetryJob;
    function BeginAction(const AMessage: String): Integer;
    procedure EndAction(const AEpoch: Integer);
    function Edit(AEvent: TEventListenerEvent): Boolean;
    function Click(AEvent: TJSMouseEvent): Boolean;
  public
    constructor Create(const AFetch: TStudioFetch);
    destructor Destroy; override;
    procedure SetProject(AProject: TJSObject; AUnsaved: Boolean);
    procedure ApplyNextBatch(ARequest: TJSObject);
    procedure Refresh; async;
  end;

implementation

type
  EStudioBatchHttp = class(Exception)
  public
    Status: Integer;
  end;

function Obj(AValue: JSValue): TJSObject;
begin
  Result := TJSObject(AValue);
end;

function ArrayAt(AObject: TJSObject; const AName: String): TJSArray;
begin
  Result := nil;
  if (AObject <> nil) and isArray(AObject[AName]) then
  begin
    Result := TJSArray(AObject[AName]);
  end;
end;

function Clone(AObject: TJSObject): TJSObject;
begin
  Result := Obj(TJSJSON.parse(TJSJSON.stringify(AObject)));
end;

function Terminal(const AStatus: String): Boolean;
begin
  Result := (AStatus = 'completed') or (AStatus = 'failed') or (AStatus = 'cancelled');
end;

function TStudioBatches.El(const AId: String): TJSElement;
begin
  Result := document.getElementById(AId);
  if Result = nil then
  begin
    raise Exception.Create('Missing batch control: ' + AId);
  end;
end;

function TStudioBatches.Add(AParent: TJSElement;
  const ATag, AText, AClass: String): TJSElement;
begin
  Result := document.createElement(ATag);
  Result.textContent := AText;
  Result.className := AClass;
  AParent.appendChild(Result);
end;

function TStudioBatches.Button(AParent: TJSElement;
  const AId, AText: String): TJSElement;
begin
  Result := Add(AParent, 'button', AText, '');
  Result.id := AId;
  Result.setAttribute('type', 'button');
  Result.addEventListener('click', @Click);
end;

procedure TStudioBatches.SelectOption(ASelect: TJSElement; const AValue, AText: String);
var
  LOption: TJSElement;
begin
  LOption := Add(ASelect, 'option', AText, '');
  LOption.setAttribute('value', AValue);
end;

procedure TStudioBatches.Layout;
var
  LRoot: TJSElement;
  LRow: TJSElement;
  LLabel: TJSElement;
  LControl: TJSElement;
  LDetails: TJSElement;
  LShort: TJSElement;
  LLength: TJSElement;
  LNav: TJSElement;
  LLive: TJSElement;
  LHistory: TJSElement;
  LSettings: TJSElement;
begin
  LRoot := El('studio-batches');
  LControl := Add(LRoot, 'p', '', 'hint');
  LControl.id := 'batch-project';
  LControl := Add(LRoot, 'p', 'Save a project to prepare its first batch.', 'notice');
  LControl.id := 'batch-notice';
  LControl.setAttribute('role', 'status');
  LControl.setAttribute('aria-live', 'polite');
  LRow := Add(LRoot, 'div', '', 'range-fields');
  LLength := LRow;
  LLabel := Add(LRow, 'label', 'Audition length', '');
  LControl := Add(LLabel, 'select', '', '');
  LControl.id := 'batch-duration';
  SelectOption(LControl, '20000', '20 seconds');
  SelectOption(LControl, '30000', '30 seconds');
  SelectOption(LControl, '40000', '40 seconds');
  LControl.addEventListener('change', @Edit);
  LLabel := Add(LRow, 'label', 'Auditions in this batch', '');
  LControl := Add(LLabel, 'select', '', '');
  LControl.id := 'batch-count';
  SelectOption(LControl, '1', '1 audition');
  SelectOption(LControl, '2', '2 auditions');
  SelectOption(LControl, '3', '3 auditions');
  LControl.addEventListener('change', @Edit);
  LRow := Add(LRoot, 'div', '', '');
  LRow.id := 'batch-partition';
  LRow.setAttribute('hidden', '');
  LLabel := Add(LRow, 'label', 'Use unassigned recordings for', '');
  LControl := Add(LLabel, 'select', '', '');
  LControl.id := 'batch-use';
  SelectOption(LControl, '', 'Choose their intended use');
  SelectOption(LControl, 'development', 'Development and exploration');
  SelectOption(LControl, 'training', 'Training material');
  LControl.addEventListener('change', @Edit);
  Add(LRow, 'p', 'This choice applies to this job; evaluation sources stay excluded.', 'hint');
  LSettings := Add(LRoot, 'section', '', '');
  LSettings.id := 'settings-step';
  LSettings.appendChild(El('generation-source-summary'));
  LDetails := LSettings;
  Add(LDetails, 'h3', 'Generation settings and source weights', '');
  LRow := Add(LDetails, 'div', '', 'range-fields');
  LLabel := Add(LRow, 'label', 'Seed (repeat the same result)', '');
  LControl := Add(LLabel, 'input', '', '');
  LControl.id := 'batch-seed';
  LControl.setAttribute('type', 'text');
  LControl.setAttribute('inputmode', 'numeric');
  LControl.setAttribute('value', '731');
  LControl.setAttribute('maxlength', '10');
  LControl.addEventListener('input', @Edit);
  LLabel := Add(LRow, 'label', 'Sound examples to keep (2–16)', '');
  LControl := Add(LLabel, 'input', '', '');
  LControl.id := 'batch-palette';
  LControl.setAttribute('type', 'text');
  LControl.setAttribute('inputmode', 'numeric');
  LControl.setAttribute('value', '8');
  LControl.setAttribute('maxlength', '2');
  LControl.addEventListener('input', @Edit);
  LLabel := Add(LDetails, 'label', 'How many neighboring sound pieces to consider', '');
  LControl := Add(LLabel, 'select', '', '');
  LControl.id := 'batch-order';
  SelectOption(LControl, '1', '1 sound piece');
  SelectOption(LControl, '2', '2 sound pieces');
  SelectOption(LControl, '3', '3 sound pieces');
  TJSHTMLSelectElement(LControl).value := '2';
  LControl.addEventListener('change', @Edit);
  LControl := Add(LDetails, 'p', 'Additional seeds use first seed +1,000 and +2,000. ' +
    'Example count is a cap, not a measure of learned musical variety.', 'hint');
  LControl.id := 'batch-seed-rule';
  LControl := Add(LDetails, 'p', '', 'hint batch-identity');
  LControl.id := 'batch-ancestry';
  LControl.setAttribute('hidden', '');
  LControl := Add(LDetails, 'div', '', '');
  LControl.id := 'batch-weights';
  LNav := Add(LRoot, 'nav', '', 'substeps');
  LNav.setAttribute('data-tab-group', '');
  LNav.setAttribute('aria-label', 'Generation mode');
  LControl := Add(LNav, 'button', 'Auditions', '');
  LControl.id := 'tab-auditions';
  LControl.setAttribute('type', 'button');
  LControl.setAttribute('aria-controls', 'audition-step');
  LControl := Add(LNav, 'button', 'Long playback', '');
  LControl.id := 'tab-live';
  LControl.setAttribute('type', 'button');
  LControl.setAttribute('aria-controls', 'live-step');
  LControl := Add(LNav, 'button', 'Jobs', '');
  LControl.id := 'tab-jobs';
  LControl.setAttribute('type', 'button');
  LControl.setAttribute('aria-controls', 'jobs-step');
  LControl := Add(LNav, 'button', 'Settings', '');
  LControl.id := 'tab-settings';
  LControl.setAttribute('type', 'button');
  LControl.setAttribute('aria-controls', 'settings-step');
  LRoot.appendChild(LSettings);
  LLive := Add(LRoot, 'section', '', '');
  LLive.id := 'live-step';
  LLive.appendChild(El('long-generation-help'));
  Add(LLive, 'div', '', '').id := 'studio-live';
  LShort := Add(LRoot, 'section', '', '');
  LShort.id := 'audition-step';
  LShort.appendChild(El('generation-help'));
  LShort.appendChild(El('batch-partition'));
  Add(LShort, 'p', 'Generate complete WAV files for listening and feedback.', 'hint');
  LShort.appendChild(LLength);
  LRow := Add(LShort, 'div', '', 'source-toolbar');
  Button(LRow, 'batch-check', 'Check setup');
  LControl := Button(LRow, 'batch-submit', 'Generate auditions');
  LControl.className := 'primary';
  LControl := Button(LRow, 'batch-confirm', 'Confirm previous submission');
  LControl.setAttribute('hidden', '');
  LControl := Button(LRow, 'batch-current', 'Use current project settings');
  LControl.setAttribute('hidden', '');
  LControl := Add(LShort, 'p', '', 'hint');
  LControl.id := 'batch-preflight';
  LDetails := Add(LShort, 'details', '', 'advanced');
  Add(LDetails, 'summary', 'Work limits', '');
  Add(LDetails, 'p', 'Worker: 10 minutes; logical memory: 128 MiB; original sources: 32 GiB; ' +
    '500,000 feature observations; 32 recordings, 64 selected ranges and 3 outputs. ' +
    'Full source verification happens in the worker. Cancellation waits for worker checkpoints.',
    'hint');
  LHistory := Add(LRoot, 'section', '', '');
  LHistory.id := 'jobs-step';
  LRow := Add(LHistory, 'div', '', 'source-heading');
  Add(LRow, 'h3', 'Job progress', '');
  Button(LRow, 'batch-refresh', 'Refresh jobs');
  LControl := Add(LHistory, 'div', '', '');
  LControl.id := 'batch-detail';
  LDetails := Add(LHistory, 'details', '', 'support');
  Add(LDetails, 'summary', 'Choose a job from history', '');
  LControl := Add(LDetails, 'div', '', 'tracks');
  LControl.id := 'batch-history';
end;

procedure TStudioBatches.Notice(const AText: String; const AError: Boolean);
begin
  El('batch-notice').textContent := AText;
  if AError then
  begin
    El('batch-notice').className := 'notice error';
  end
  else
  begin
    El('batch-notice').className := 'notice';
  end;
end;

procedure TStudioBatches.Invalidate;
begin
  Inc(FConfigVersion);
  FRequest := nil;
  FRetryRequest := nil;
  FPreparation := nil;
  El('batch-preflight').textContent := '';
  UpdateControls;
end;

procedure TStudioBatches.UpdateControls;
var
  LReady: Boolean;
  LControls: array of String;
  LIndex: Integer;
  LWeights: TJSNodeList;
begin
  LReady := (FRetryRequest <> nil) or ((FProject <> nil) and not FUnsaved and
    (StudioNumber(FProject, 'revision') >= 1) and
    (TJSArray(FProject['sources']).length > 0) and
    (StudioText(FProject, 'learning_mode') = 'raw_acoustic'));
  if FLive <> nil then FLive.SetProject(FProject, LReady and not FUnsaved);
  LControls := ['batch-duration', 'batch-count', 'batch-use', 'batch-seed',
    'batch-palette', 'batch-order'];
  for LIndex := 0 to High(LControls) do
  begin
    TJSHTMLInputElement(El(LControls[LIndex])).disabled := FBusy or not LReady or
      (FRetryRequest <> nil);
  end;
  LWeights := El('batch-weights').querySelectorAll('input');
  for LIndex := 0 to LWeights.length - 1 do
  begin
    TJSHTMLInputElement(LWeights[LIndex]).disabled := FBusy or not LReady or
      (FRetryRequest <> nil);
  end;
  TJSHTMLButtonElement(El('batch-check')).disabled := FBusy or not LReady or (FPending <> nil);
  TJSHTMLButtonElement(El('batch-submit')).disabled := FBusy or not LReady or
    (FRequest = nil) or (FPreparation = nil) or (FPending <> nil);
  TJSHTMLButtonElement(El('batch-confirm')).disabled := FBusy;
  TJSHTMLButtonElement(El('batch-current')).disabled := FBusy;
  if FRetryRequest = nil then
  begin
    El('batch-current').setAttribute('hidden', '');
    El('batch-check').textContent := 'Check setup';
  end
  else
  begin
    El('batch-current').removeAttribute('hidden');
    El('batch-check').textContent := 'Check original retry setup';
  end;
  if FPending = nil then
  begin
    El('batch-confirm').setAttribute('hidden', '');
  end
  else
  begin
    El('batch-confirm').removeAttribute('hidden');
  end;
  if document.getElementById('batch-cancel') <> nil then
  begin
    TJSHTMLButtonElement(El('batch-cancel')).disabled := FBusy or
      (FSelectedId <> StudioText(FJob, 'job_id'));
  end;
  if document.getElementById('batch-retry') <> nil then
  begin
    TJSHTMLButtonElement(El('batch-retry')).disabled := FBusy or (FPending <> nil) or
      (FSelectedId <> StudioText(FJob, 'job_id'));
  end;
end;

procedure TStudioBatches.DrawWeights;
var
  LRoot: TJSElement;
  LRows: TJSArray;
  LSeen: TJSObject;
  LRow: TJSObject;
  LLabel: TJSElement;
  LInput: TJSElement;
  LHash: String;
  LTitle: String;
  LIndex: Integer;
begin
  LRoot := El('batch-weights');
  LRoot.innerHTML := '';
  LRows := ArrayAt(FProject, 'sources');
  if LRows = nil then
  begin
    Exit;
  end;
  Add(LRoot, 'h3', 'Recording weights', '');
  Add(LRoot, 'p', '1–16 per recording; all its selected ranges share the weight.', 'hint');
  LSeen := TJSObject.new;
  for LIndex := 0 to LRows.length - 1 do
  begin
    LRow := Obj(LRows[LIndex]);
    LHash := StudioText(LRow, 'source_sha256');
    if LSeen.hasOwnProperty(LHash) then
    begin
      Continue;
    end;
    LSeen[LHash] := True;
    LTitle := StudioText(LRow, 'title');
    if LTitle = '' then
    begin
      LTitle := StudioText(LRow, 'original_name');
    end;
    LLabel := Add(LRoot, 'label', LTitle, '');
    LInput := Add(LLabel, 'input', '', '');
    LInput.id := 'batch-weight-' + LHash;
    LInput.setAttribute('type', 'text');
    LInput.setAttribute('inputmode', 'numeric');
    LInput.setAttribute('maxlength', '2');
    LInput.setAttribute('value', '1');
    LInput.setAttribute('data-source', LHash);
    LInput.addEventListener('input', @Edit);
  end;
end;

procedure TStudioBatches.SetProject(AProject: TJSObject; AUnsaved: Boolean);
var
  LOldKey: String;
  LNewKey: String;
  LKeepParent: Boolean;
  LRows: TJSArray;
  LHasUnassigned: Boolean;
  LIndex: Integer;
begin
  LOldKey := StudioText(FProject, 'snapshot_sha256');
  LNewKey := StudioText(AProject, 'snapshot_sha256');
  LKeepParent := (FParentJobId <> '') and (FProject <> nil) and (AProject <> nil) and
    (StudioText(FProject, 'project_id') = StudioText(AProject, 'project_id'));
  if (LOldKey <> LNewKey) or (FUnsaved <> AUnsaved) then
  begin
    Invalidate;
  end;
  if AProject = nil then
  begin
    FProject := nil;
  end
  else
  begin
    FProject := Clone(AProject);
  end;
  FUnsaved := AUnsaved;
  if LOldKey <> LNewKey then
  begin
    if not LKeepParent then
    begin
      FExplicitSeeds := nil;
      FParentJobId := '';
      El('batch-ancestry').setAttribute('hidden', '');
      El('batch-seed-rule').textContent :=
        'Additional seeds use first seed +1,000 and +2,000. Example count is a cap, ' +
        'not a measure of learned musical variety.';
    end;
    DrawWeights;
    LRows := ArrayAt(FProject, 'sources');
    LHasUnassigned := False;
    if LRows <> nil then
    begin
      for LIndex := 0 to LRows.length - 1 do
      begin
        LHasUnassigned := LHasUnassigned or
          (StudioText(Obj(LRows[LIndex]), 'partition') = 'unassigned');
      end;
    end;
    if LHasUnassigned then
    begin
      El('batch-partition').removeAttribute('hidden');
      TJSHTMLSelectElement(El('batch-use')).value := '';
    end
    else
    begin
      El('batch-partition').setAttribute('hidden', '');
      TJSHTMLSelectElement(El('batch-use')).value := 'development';
    end;
  end;
  if (FProject = nil) or (StudioNumber(FProject, 'revision') < 1) then
  begin
    El('batch-project').textContent := 'No saved project selected.';
    Notice('Save your source collection before preparing a batch.');
  end
  else
  begin
    El('batch-project').textContent := StudioText(FProject, 'name') +
      ' · saved version ' + IntToStr(Trunc(StudioNumber(FProject, 'revision')));
    if FUnsaved then
    begin
      Notice('Save your changes before checking or submitting a new batch.');
    end
    else if StudioText(FProject, 'learning_mode') <> 'raw_acoustic' then
    begin
      Notice('This project requests a note-learning route that is unavailable here. ' +
        'No acoustic fallback will run.', True);
    end
    else if TJSArray(FProject['sources']).length = 0 then
    begin
      Notice('Nothing checked for training. Choose music in Collection, then Save draft.');
    end
    else if FPending = nil then
    begin
      Notice('Ready. Choose how long to play, or save short auditions.');
    end;
  end;
  UpdateControls;
end;

function TStudioBatches.ReadInteger(const AId: String;
  const AMinimum, AMaximum: Integer): Integer;
var
  LText: String;
  LIndex: Integer;
  LValue: Double;
begin
  LText := TJSHTMLInputElement(El(AId)).value;
  if (LText = '') or (Length(LText) > 10) then
  begin
    El(AId).setAttribute('aria-invalid', 'true');
    TJSHTMLInputElement(El(AId)).focus;
    raise Exception.Create('Enter a whole number within the declared range.');
  end;
  LValue := 0;
  for LIndex := 1 to Length(LText) do
  begin
    if not (LText[LIndex] in ['0'..'9']) then
    begin
      El(AId).setAttribute('aria-invalid', 'true');
      TJSHTMLInputElement(El(AId)).focus;
      raise Exception.Create('Use decimal digits only for generation settings and weights.');
    end;
    LValue := LValue * 10 + Ord(LText[LIndex]) - Ord('0');
  end;
  if (LValue < AMinimum) or (LValue > AMaximum) then
  begin
    El(AId).setAttribute('aria-invalid', 'true');
    TJSHTMLInputElement(El(AId)).focus;
    raise Exception.Create('Enter a value from ' + IntToStr(AMinimum) +
      ' to ' + IntToStr(AMaximum) + '.');
  end;
  El(AId).removeAttribute('aria-invalid');
  Result := Trunc(LValue);
end;

function TStudioBatches.NewId: String;
begin
  Result := 'batch-' + IntToStr(TJSDate.now) + '-' + IntToStr(Random(1000000000));
end;

procedure TStudioBatches.ApplyNextBatch(ARequest: TJSObject);
var
  LSeeds: TJSArray;
  LWeights: TJSArray;
  LSeen: TJSObject;
  LRow: TJSObject;
  LInputs: TJSNodeList;
  LIndex: Integer;
  LOther: Integer;
  LDuration: Integer;
  LPalette: Integer;
  LOrder: Integer;
  LSeed: Integer;
  LWeight: Integer;
  LHash: String;
  LParent: String;
  LSeedText: String;

  function IntegerValue(AValue: JSValue; AMinimum, AMaximum: Integer): Integer;
  var
    LNumber: Double;
  begin
    if not isNumber(AValue) then
    begin
      raise Exception.Create('The next batch contains an invalid numeric setting.');
    end;
    LNumber := Double(AValue);
    if not ((LNumber >= AMinimum) and (LNumber <= AMaximum)) then
    begin
      raise Exception.Create('The next batch contains an out-of-range setting.');
    end;
    Result := Trunc(LNumber);
    if LNumber <> Result then
    begin
      raise Exception.Create('The next batch requires whole-number settings.');
    end;
  end;

begin
  if FBusy or (FPending <> nil) then
  begin
    raise Exception.Create('Finish or confirm the current submission ' +
      'before preparing another batch.');
  end;
  if (ARequest = nil) or (FProject = nil) or FUnsaved or
    (StudioText(ARequest, 'format') <> 'pythian.studio.job.write.v1') or
    (StudioText(ARequest, 'kind') <> 'train_generate') or
    (StudioText(FProject, 'learning_mode') <> 'raw_acoustic') or
    (StudioText(ARequest, 'project_id') <> StudioText(FProject, 'project_id')) or
    (StudioNumber(ARequest, 'project_revision') <> StudioNumber(FProject, 'revision')) or
    (StudioText(ARequest, 'project_snapshot_sha256') <>
      StudioText(FProject, 'snapshot_sha256')) then
  begin
    raise Exception.Create('Load the saved project version for this reviewed batch first.');
  end;
  LDuration := IntegerValue(ARequest['duration_ms'], 20000, 40000);
  LPalette := IntegerValue(ARequest['maximum_tokens'], 2, 16);
  LOrder := IntegerValue(ARequest['model_order'], 1, 3);
  LSeeds := ArrayAt(ARequest, 'seeds');
  LWeights := ArrayAt(ARequest, 'source_weights');
  if (LSeeds = nil) or (LWeights = nil) then
  begin
    raise Exception.Create('The next batch needs explicit seeds and recording weights.');
  end;
  if (LSeeds.length < 1) or (LSeeds.length > 3) then
  begin
    raise Exception.Create('The next batch needs one to three distinct seeds.');
  end;
  LSeedText := '';
  for LIndex := 0 to LSeeds.length - 1 do
  begin
    LSeed := IntegerValue(LSeeds[LIndex], 0, 2147483000);
    for LOther := 0 to LIndex - 1 do
    begin
      if LSeed = IntegerValue(LSeeds[LOther], 0, 2147483000) then
      begin
        raise Exception.Create('The next batch seeds must be distinct.');
      end;
    end;
    if LSeedText <> '' then
    begin
      LSeedText := LSeedText + ', ';
    end;
    LSeedText := LSeedText + IntToStr(LSeed);
  end;
  LParent := StudioText(ARequest, 'parent_job_id');
  if (Length(LParent) < 1) or (Length(LParent) > 64) then
  begin
    raise Exception.Create('The next batch needs its original parent batch identity.');
  end;
  for LIndex := 1 to Length(LParent) do
  begin
    if not (LParent[LIndex] in ['A'..'Z', 'a'..'z', '0'..'9', '_', '-']) then
    begin
      raise Exception.Create('The parent batch identity is invalid.');
    end;
  end;
  if (StudioText(ARequest, 'resolve_unassigned') <> 'development') and
    (StudioText(ARequest, 'resolve_unassigned') <> 'training') then
  begin
    raise Exception.Create('The next batch needs an explicit recording-use choice.');
  end;
  LInputs := El('batch-weights').querySelectorAll('input');
  if LWeights.length <> LInputs.length then
  begin
    raise Exception.Create('The next batch weights do not match this saved project.');
  end;
  LSeen := TJSObject.new;
  for LIndex := 0 to LWeights.length - 1 do
  begin
    LRow := Obj(LWeights[LIndex]);
    LHash := StudioText(LRow, 'source_sha256');
    LWeight := IntegerValue(LRow['weight'], 1, 16);
    if LSeen.hasOwnProperty(LHash) then
    begin
      raise Exception.Create('The next batch repeats a recording weight.');
    end;
    LSeen[LHash] := LWeight;
  end;
  for LIndex := 0 to LInputs.length - 1 do
  begin
    LHash := TJSElement(LInputs[LIndex]).getAttribute('data-source');
    if not isNumber(LSeen[LHash]) then
    begin
      raise Exception.Create('The next batch weights do not match this saved project.');
    end;
  end;
  Invalidate;
  TJSHTMLSelectElement(El('batch-duration')).value := IntToStr(LDuration);
  if TJSHTMLSelectElement(El('batch-duration')).value = '' then
  begin
    SelectOption(El('batch-duration'), IntToStr(LDuration),
      StudioTime(LDuration / 1000) + ' (reviewed setting)');
    TJSHTMLSelectElement(El('batch-duration')).value := IntToStr(LDuration);
  end;
  TJSHTMLSelectElement(El('batch-count')).value := IntToStr(LSeeds.length);
  TJSHTMLInputElement(El('batch-seed')).value := IntToStr(IntegerValue(LSeeds[0], 0, 2147483000));
  TJSHTMLInputElement(El('batch-palette')).value := IntToStr(LPalette);
  TJSHTMLSelectElement(El('batch-order')).value := IntToStr(LOrder);
  TJSHTMLSelectElement(El('batch-use')).value := StudioText(ARequest, 'resolve_unassigned');
  for LIndex := 0 to LInputs.length - 1 do
  begin
    LHash := TJSElement(LInputs[LIndex]).getAttribute('data-source');
    TJSHTMLInputElement(LInputs[LIndex]).value := IntToStr(IntegerValue(LSeen[LHash], 1, 16));
  end;
  FExplicitSeeds := TJSArray(TJSJSON.parse(TJSJSON.stringify(LSeeds)));
  FParentJobId := LParent;
  El('batch-seed-rule').textContent := 'Reviewed seeds: ' + LSeedText +
    '. Editing the first seed or audition count restores the +1,000 seed rule.';
  El('batch-ancestry').textContent := 'Prepared from parent batch: ' + LParent;
  El('batch-ancestry').removeAttribute('hidden');
  Notice('Reviewed settings restored. Check setup before generating a new batch.');
  UpdateControls;
end;

function TStudioBatches.BuildRequest: TJSObject;
var
  LSeeds: TJSArray;
  LWeights: TJSArray;
  LRow: TJSObject;
  LInputs: TJSNodeList;
  LCount: Integer;
  LSeed: Integer;
  LIndex: Integer;
  LUse: String;
begin
  if (FProject = nil) or FUnsaved or
    (StudioText(FProject, 'learning_mode') <> 'raw_acoustic') then
  begin
    raise Exception.Create('A saved project using supported acoustic recombination is required.');
  end;
  LUse := TJSHTMLSelectElement(El('batch-use')).value;
  if (LUse <> 'development') and (LUse <> 'training') then
  begin
    TJSHTMLSelectElement(El('batch-use')).focus;
    raise Exception.Create('Choose the intended use of your unassigned recordings first.');
  end;
  LCount := ReadInteger('batch-count', 1, 3);
  if FExplicitSeeds = nil then
  begin
    LSeed := ReadInteger('batch-seed', 0, 2147483000 - (LCount - 1) * 1000);
  end
  else
  begin
    LSeed := ReadInteger('batch-seed', 0, 2147483000);
  end;
  Result := TJSObject.new;
  Result['format'] := 'pythian.studio.job.write.v1';
  Result['kind'] := 'train_generate';
  Result['job_id'] := NewId;
  Result['project_id'] := StudioText(FProject, 'project_id');
  Result['project_revision'] := StudioNumber(FProject, 'revision');
  Result['project_snapshot_sha256'] := StudioText(FProject, 'snapshot_sha256');
  Result['duration_ms'] := ReadInteger('batch-duration', 20000, 40000);
  Result['maximum_tokens'] := ReadInteger('batch-palette', 2, 16);
  Result['model_order'] := ReadInteger('batch-order', 1, 3);
  Result['resolve_unassigned'] := LUse;
  LSeeds := TJSArray.new;
  if FExplicitSeeds <> nil then
  begin
    for LIndex := 0 to FExplicitSeeds.length - 1 do
    begin
      LSeeds.push(FExplicitSeeds[LIndex]);
    end;
  end
  else
  begin
    for LIndex := 0 to LCount - 1 do
    begin
      LSeeds.push(LSeed + LIndex * 1000);
    end;
  end;
  Result['seeds'] := LSeeds;
  if FParentJobId <> '' then
  begin
    Result['parent_job_id'] := FParentJobId;
  end;
  LWeights := TJSArray.new;
  LInputs := El('batch-weights').querySelectorAll('input');
  for LIndex := 0 to LInputs.length - 1 do
  begin
    LRow := TJSObject.new;
    LRow['source_sha256'] := TJSElement(LInputs[LIndex]).getAttribute('data-source');
    LRow['weight'] := ReadInteger(TJSElement(LInputs[LIndex]).id, 1, 16);
    LWeights.push(LRow);
  end;
  Result['source_weights'] := LWeights;
end;

function TStudioBatches.Json(const APath, AMethod, ABody: String): TJSObject; async;
var
  LResponse: TJSResponse;
  LMessage: String;
  LError: EStudioBatchHttp;
begin
  LResponse := await(TJSResponse, FFetch(APath, AMethod, ABody));
  if (LResponse.status <> 200) and (LResponse.status <> 202) then
  begin
    LMessage := await(String, LResponse.text());
    LMessage := Copy(Trim(LMessage), 1, 256);
    if LMessage = '' then
    begin
      LMessage := 'The request was not accepted (' + IntToStr(LResponse.status) + ').';
    end;
    LError := EStudioBatchHttp.Create(LMessage);
    LError.Status := LResponse.status;
    raise LError;
  end;
  Result := await(TJSObject, LResponse.json());
end;

function TStudioBatches.BeginAction(const AMessage: String): Integer;
var
  LEpoch: Integer;
begin
  Inc(FEpoch);
  LEpoch := FEpoch;
  Result := LEpoch;
  FBusy := True;
  Notice(AMessage);
  UpdateControls;
  FTimer := window.setTimeout(
    procedure()
    begin
      if LEpoch = FEpoch then
      begin
        Inc(FEpoch);
        FBusy := False;
        if FPending <> nil then
        begin
          Notice('Submission is unconfirmed. Your batch identity is retained; ' +
            'confirm it before creating another attempt.', True);
        end
        else
        begin
          Notice('The request is taking too long. Your settings remain; retry when ready.', True);
        end;
        UpdateControls;
      end;
    end, 15000);
end;

procedure TStudioBatches.EndAction(const AEpoch: Integer);
begin
  if AEpoch = FEpoch then
  begin
    window.clearTimeout(FTimer);
    FBusy := False;
    UpdateControls;
  end;
end;

procedure TStudioBatches.Prepare; async;
var
  LEpoch: Integer;
  LVersion: Integer;
  LRequest: TJSObject;
  LData: TJSObject;
begin
  if FBusy or (FPending <> nil) then
  begin
    Exit;
  end;
  try
    if FRetryRequest <> nil then
    begin
      LRequest := Clone(FRetryRequest);
    end
    else
    begin
      LRequest := BuildRequest;
    end;
  except
    on LException: Exception do
    begin
      Notice(LException.Message, True);
      Exit;
    end;
  end;
  LEpoch := BeginAction('Checking selection and bounded work…');
  FRequest := nil;
  FPreparation := nil;
  El('batch-preflight').textContent := '';
  UpdateControls;
  LVersion := FConfigVersion;
  try
    LData := await(TJSObject, Json('/api/studio/preflight', 'POST', TJSJSON.stringify(LRequest)));
    if LEpoch <> FEpoch then
    begin
      Exit;
    end;
    if LVersion <> FConfigVersion then
    begin
      Notice('Your project or settings changed. Check the current selection again.');
    end
    else if (StudioText(LData, 'format') <> 'pythian.studio.job.preparation.v1') or
      (StudioText(LData, 'learning_mode') <> 'raw_acoustic') or
      (StudioText(LData, 'job_id') <> StudioText(LRequest, 'job_id')) or
      (Length(StudioText(LData, 'request_sha256')) <> 64) then
    begin
      Notice('The preparation response is unsupported. No job was submitted.', True);
    end
    else
    begin
      FRequest := Clone(LRequest);
      FPreparation := Clone(LData);
      El('batch-preflight').textContent := StudioTime(StudioNumber(LData, 'selected_seconds')) +
        ' selected across ' + IntToStr(Trunc(StudioNumber(LData, 'source_count'))) +
        ' recordings / ' + IntToStr(Trunc(StudioNumber(LData, 'range_count'))) +
      ' ranges. Estimated analysis: ' +
        IntToStr(Trunc(StudioNumber(LData, 'estimated_analyzed_features'))) +
        ' observations. ' + IntToStr(Trunc(StudioNumber(LRequest, 'duration_ms') / 1000)) +
        '-second auditions, seeds ' + TJSJSON.stringify(LRequest['seeds']) +
        '. No sources used yet; content verification is pending.';
      Notice('Setup is ready. Press Generate auditions to start.');
    end;
  except
    on LException: Exception do
    begin
      if LEpoch = FEpoch then
      begin
        Notice(LException.Message + ' No job was submitted.', True);
      end;
    end;
  else
    begin
      if LEpoch = FEpoch then
      begin
        Notice('Setup could not be checked. Your settings remain.', True);
      end;
    end;
  end;
  EndAction(LEpoch);
end;

function TStudioBatches.MatchingJob(AJob: TJSObject): Boolean;
begin
  Result := (FPending <> nil) and
    (StudioText(AJob, 'format') = 'pythian.studio.job.v1') and
    (StudioText(AJob, 'job_id') = StudioText(FPending, 'job_id')) and
    (StudioText(AJob, 'request_sha256') = FPendingHash);
end;

procedure TStudioBatches.Submit; async;
var
  LEpoch: Integer;
  LData: TJSObject;
begin
  if FBusy or (FUnsaved and (FRetryRequest = nil)) or (FRequest = nil) or
    (FPreparation = nil) or (FPending <> nil) then
  begin
    Exit;
  end;
  FPending := Clone(FRequest);
  FPendingHash := StudioText(FPreparation, 'request_sha256');
  LEpoch := BeginAction('Submitting this immutable batch…');
  try
    LData := await(TJSObject, Json('/api/studio/job', 'POST', TJSJSON.stringify(FPending)));
    if LEpoch <> FEpoch then
    begin
      Exit;
    end;
    if not MatchingJob(LData) then
    begin
      raise Exception.Create('The response does not match the submitted batch.');
    end;
    FSelectedId := StudioText(FPending, 'job_id');
    FJob := Clone(LData);
    FPending := nil;
    Invalidate;
    DrawJob;
    SelectWorkspacePane('jobs-step', True);
    Notice('Batch accepted. Source edits remain available while the worker runs.');
  except
    on LException: Exception do
    begin
      if LEpoch = FEpoch then
      begin
        if (LException is EStudioBatchHttp) and
          ((EStudioBatchHttp(LException).Status = 400) or
          (EStudioBatchHttp(LException).Status = 422)) then
        begin
          FPending := nil;
          Invalidate;
          Notice('Batch rejected: ' + LException.Message +
            ' Correct the setup and check it again.', True);
        end
        else
        begin
          Notice('Submission is unconfirmed: ' + LException.Message +
            ' Confirm the retained batch before making another attempt.', True);
        end;
      end;
    end;
  else
    begin
      if LEpoch = FEpoch then
      begin
        Notice('Submission is unconfirmed. Confirm the retained batch before retrying.', True);
      end;
    end;
  end;
  EndAction(LEpoch);
  Refresh;
end;

procedure TStudioBatches.ConfirmPending; async;
var
  LEpoch: Integer;
  LData: TJSObject;
  LNotFound: Boolean;
begin
  if FBusy or (FPending = nil) then
  begin
    Exit;
  end;
  LEpoch := BeginAction('Checking the original submission…');
  LNotFound := False;
  try
    try
      LData := await(TJSObject, Json('/api/studio/job?id=' +
        encodeURIComponent(StudioText(FPending, 'job_id')), 'GET', ''));
    except
      on LException: Exception do
      begin
        if LEpoch <> FEpoch then
        begin
          Exit;
        end;
        LNotFound := (LException is EStudioBatchHttp) and
          (EStudioBatchHttp(LException).Status = 404);
        { Reconcile with the SAME id/body, never a fresh speculative attempt. }
        LData := await(TJSObject, Json('/api/studio/job', 'POST', TJSJSON.stringify(FPending)));
      end;
    end;
    if LEpoch <> FEpoch then
    begin
      Exit;
    end;
    if not MatchingJob(LData) then
    begin
      raise Exception.Create('The retained submission identity could not be confirmed.');
    end;
    FSelectedId := StudioText(FPending, 'job_id');
    FJob := Clone(LData);
    FPending := nil;
    Invalidate;
    DrawJob;
    Notice('The original batch is confirmed. Its recorded status is shown below.');
  except
    on LException: Exception do
    begin
      if LEpoch = FEpoch then
      begin
        if LNotFound and (LException is EStudioBatchHttp) and
          ((EStudioBatchHttp(LException).Status = 400) or
          (EStudioBatchHttp(LException).Status = 422)) then
        begin
          FPending := nil;
          Invalidate;
          Notice('The absent original request was rejected: ' + LException.Message +
            ' Check the current setup before creating a new batch.', True);
        end
        else
        begin
          Notice(LException.Message + ' The original request remains retained.', True);
        end;
      end;
    end;
  else
    begin
      if LEpoch = FEpoch then
      begin
        Notice('Recovery remains unconfirmed. The original request is retained.', True);
      end;
    end;
  end;
  EndAction(LEpoch);
  Refresh;
end;

procedure TStudioBatches.DrawHistory;
var
  LRoot: TJSElement;
  LRow: TJSElement;
  LButton: TJSElement;
  LJob: TJSObject;
  LIndex: Integer;
  LFocusId: String;
  LShown: Integer;
begin
  if TJSJSON.stringify(FJobs) = FLastHistory then
  begin
    Exit;
  end;
  FLastHistory := TJSJSON.stringify(FJobs);
  LFocusId := '';
  if document.activeElement <> nil then
  begin
    LFocusId := document.activeElement.id;
  end;
  LRoot := El('batch-history');
  LRoot.innerHTML := '';
  LShown := 0;
  for LIndex := FJobs.length - 1 downto 0 do
  begin
    LJob := Obj(FJobs[LIndex]);
    if (StudioText(LJob, 'kind') <> 'train_generate') and
      (StudioText(LJob, 'kind') <> 'stream_generate') then
    begin
      Continue;
    end;
    Inc(LShown);
    LRow := Add(LRoot, 'div', '', 'track');
    if StudioText(LJob, 'kind') = 'stream_generate' then
      LButton := Button(LRow, 'batch-open-' + StudioText(LJob, 'job_id'),
        'Live session ' + IntToStr(LIndex + 1) + ' · ' + StudioText(LJob, 'status'))
    else LButton := Button(LRow, 'batch-open-' + StudioText(LJob, 'job_id'),
      'Auditions ' + IntToStr(LIndex + 1) + ' · ' + StudioText(LJob, 'status'));
    LButton.setAttribute('data-job', StudioText(LJob, 'job_id'));
    Add(LRow, 'span', StudioStageText(StudioText(LJob, 'stage')), 'track-meta');
  end;
  if LShown = 0 then
  begin
    Add(LRoot, 'p', 'No audition batches yet. Check a saved project to prepare its first batch.',
      'empty-state');
  end;
  if (LFocusId <> '') and (document.getElementById(LFocusId) <> nil) then
  begin
    TJSHTMLButtonElement(document.getElementById(LFocusId)).focus;
  end;
end;

procedure TStudioBatches.DrawJob;
var
  LRoot: TJSElement;
  LResults: TJSObject;
  LRequest: TJSObject;
  LOutput: TJSObject;
  LOutputs: TJSArray;
  LSources: TJSArray;
  LRow: TJSElement;
  LDetails: TJSElement;
  LLink: TJSElement;
  LStatus: String;
  LText: String;
  LSeconds: Double;
  LIndex: Integer;
  LFocusId: String;
  LExpanded: Boolean;
  LExisting: TJSElement;
begin
  LRoot := El('batch-detail');
  LFocusId := '';
  if document.activeElement <> nil then
  begin
    LFocusId := document.activeElement.id;
  end;
  LExisting := document.getElementById('batch-identities');
  LExpanded := (LExisting <> nil) and LExisting.hasAttribute('open');
  LRoot.innerHTML := '';
  if FJob = nil then
  begin
    Exit;
  end;
  LStatus := StudioText(FJob, 'status');
  if StudioText(FJob, 'kind') = 'stream_generate' then
    Add(LRoot, 'h3', 'Selected live session · ' + LStatus, '')
  else Add(LRoot, 'h3', 'Selected batch · ' + LStatus, '');
  DrawStudioProgress(LRoot, FJob);
  if (LStatus = 'queued') or (LStatus = 'running') then
  begin
    if Boolean(FJob['cancel_requested']) then
    begin
      Add(LRoot, 'p', 'Cancellation requested; waiting for a worker checkpoint.', 'hint');
    end
    else
    begin
      Button(LRoot, 'batch-cancel', 'Cancel this batch');
    end;
  end;
  if (LStatus = 'failed') or (LStatus = 'cancelled') then
  begin
    Add(LRoot, 'p', StudioText(FJob, 'error_message'), 'field-error');
    if StudioText(FJob, 'kind') = 'stream_generate' then
      Add(LRoot, 'p', 'This session has ended. Generate & play starts a new session from the beginning.', 'hint')
    else if isObject(FJob['request']) then
    begin
      Button(LRoot, 'batch-retry', 'Try this batch again');
    end
    else
    begin
      Add(LRoot, 'p', 'Original settings are not reported; retry is unavailable here.', 'hint');
    end;
  end;
  LResults := Obj(FJob['results']);
  if (StudioText(FJob, 'kind') = 'stream_generate') and
    (StudioNumber(LResults, 'sample_rate') > 0) then
    Add(LRoot, 'p', 'Generated: ' + StudioTime(StudioNumber(LResults, 'generated_frames') /
      StudioNumber(LResults, 'sample_rate')) + '. Playback may have stopped earlier.', 'hint');
  LSources := ArrayAt(LResults, 'sources');
  if LSources <> nil then
  begin
    LSeconds := 0;
    for LIndex := 0 to LSources.length - 1 do
    begin
      if StudioNumber(Obj(LSources[LIndex]), 'sample_rate') > 0 then
      begin
        LSeconds := LSeconds + StudioNumber(Obj(LSources[LIndex]), 'analyzed_frames') /
          StudioNumber(Obj(LSources[LIndex]), 'sample_rate');
      end;
    end;
    Add(LRoot, 'p', 'Source audio analyzed: ' + StudioTime(LSeconds) + ' · ' +
      IntToStr(Trunc(StudioNumber(LResults, 'total_analyzed_observations'))) +
      ' feature observations.', 'hint');
  end;
  if (LResults <> nil) and isNumber(LResults['retained_token_count']) and
    isNumber(LResults['retained_candidate_count']) then
  begin
    Add(LRoot, 'p', 'Sound examples kept: ' +
      IntToStr(Trunc(StudioNumber(LResults, 'retained_token_count'))) +
      ' types / ' + IntToStr(Trunc(StudioNumber(LResults, 'retained_candidate_count'))) +
      ' recorded pieces. More examples do not necessarily mean more musical variety.', 'hint');
  end
  else if LStatus = 'completed' then
  begin
    Add(LRoot, 'p', 'Retained palette and candidate counts are not reported.', 'hint');
  end;
  LOutputs := ArrayAt(LResults, 'outputs');
  if LOutputs <> nil then
  begin
    for LIndex := 0 to LOutputs.length - 1 do
    begin
      LOutput := Obj(LOutputs[LIndex]);
      if StudioText(LOutput, 'listening_request_id') = '' then
      begin
        Continue;
      end;
      LRow := Add(LRoot, 'div', '', 'track');
      Add(LRow, 'p', 'Audition ' + IntToStr(LIndex + 1) + ' · seed ' +
        IntToStr(Trunc(StudioNumber(LOutput, 'seed'))), '');
      LLink := Add(LRow, 'a', 'Listen and give feedback', '');
      LLink.setAttribute('href', 'listen.html?request=' +
        encodeURIComponent(StudioText(LOutput, 'listening_request_id')));
      Add(LRow, 'p', 'Listening request: ' + StudioText(LOutput, 'listening_request_id'),
        'track-meta batch-identity');
    end;
  end;
  LDetails := Add(LRoot, 'details', '', 'advanced batch-identities');
  LDetails.id := 'batch-identities';
  if LExpanded then
  begin
    LDetails.setAttribute('open', '');
  end;
  Add(LDetails, 'summary', 'Batch and model details', '');
  Add(LDetails, 'p', 'Batch ' + StudioText(FJob, 'job_id') +
    ' · request ' + StudioText(FJob, 'request_sha256'), 'track-meta');
  LRequest := Obj(FJob['request']);
  if LRequest <> nil then
  begin
    if StudioText(FJob, 'kind') = 'stream_generate' then
      Add(LDetails, 'p', 'Requested length: ' + StudioTime(StudioNumber(LRequest, 'duration_ms') / 1000) +
        '. Only saved review excerpts are retained as WAV files.', 'hint');
    Add(LDetails, 'p', 'Project ' + StudioText(LRequest, 'project_id') +
      ' · revision ' + IntToStr(Trunc(StudioNumber(LRequest, 'project_revision'))) +
      ' · snapshot ' + StudioText(LRequest, 'project_snapshot_sha256'), 'track-meta');
    if StudioText(LRequest, 'retry_of') <> '' then
    begin
      Add(LDetails, 'p', 'Retry of ' + StudioText(LRequest, 'retry_of'), 'track-meta');
    end;
    if StudioText(LRequest, 'parent_job_id') <> '' then
    begin
      Add(LDetails, 'p', 'Parent batch ' + StudioText(LRequest, 'parent_job_id'), 'track-meta');
    end;
  end;
  if StudioText(LResults, 'model_sha256') <> '' then
  begin
    Add(LDetails, 'p', 'Model ' + StudioText(LResults, 'model_sha256') +
      ' · training identity ' + StudioText(LResults, 'training_identity_sha256'), 'track-meta');
    if Boolean(LResults['model_reused']) then
    begin
      Add(LDetails, 'p', 'Verified existing model reused.', 'hint');
    end;
    if isNumber(LResults['retained_model_state_count']) then
    begin
      Add(LDetails, 'p', 'Model states: ' +
        IntToStr(Trunc(StudioNumber(LResults, 'retained_model_state_count'))), 'hint');
    end;
    if StudioText(LResults, 'policy') <> '' then
    begin
      Add(LDetails, 'p', 'Renderer policy: ' + StudioText(LResults, 'policy'), 'track-meta');
    end;
  end;
  if (LFocusId <> '') and (document.getElementById(LFocusId) <> nil) then
  begin
    TJSHTMLButtonElement(document.getElementById(LFocusId)).focus;
  end
  else if (LFocusId = 'batch-cancel') or (LFocusId = 'batch-retry') then
  begin
    TJSHTMLButtonElement(El('batch-refresh')).focus;
  end;
  UpdateControls;
end;

procedure TStudioBatches.LoadJob(const AId: String); async;
var
  LData: TJSObject;
  LEpoch: Integer;
  LTimer: NativeInt;
  LChanged: Boolean;
begin
  LChanged := FSelectedId <> AId;
  FSelectedId := AId;
  UpdateControls;
  Inc(FLoadEpoch);
  LEpoch := FLoadEpoch;
  if LChanged then
  begin
    Notice('Loading selected batch status…');
  end;
  LTimer := window.setTimeout(
    procedure()
    begin
      if LEpoch = FLoadEpoch then
      begin
        Inc(FLoadEpoch);
        if not FBusy then
        begin
          Notice('Status is taking too long. Previous results remain; refresh to retry.',
            True);
        end;
      end;
    end, 15000);
  try
    LData := await(TJSObject, Json('/api/studio/job?id=' + encodeURIComponent(AId), 'GET', ''));
    if (FSelectedId <> AId) or (LEpoch <> FLoadEpoch) then
    begin
      Exit;
    end;
    if (StudioText(LData, 'format') <> 'pythian.studio.job.v1') or
      (StudioText(LData, 'job_id') <> AId) then
    begin
      raise Exception.Create('Selected batch identity is unsupported.');
    end;
    if (FJob <> nil) and (StudioText(FJob, 'job_id') = AId) and
      (StudioNumber(LData, 'event_revision') < StudioNumber(FJob, 'event_revision')) then
    begin
      Exit;
    end;
    if (FJob = nil) or (TJSJSON.stringify(FJob) <> TJSJSON.stringify(LData)) then
    begin
      FJob := Clone(LData);
      DrawJob;
    end;
    if LChanged and not FBusy then
    begin
      Notice('Selected batch status loaded.');
    end;
  except
    on LException: Exception do
    begin
      if LEpoch = FLoadEpoch then
      begin
        Notice('Batch status could not be refreshed: ' + LException.Message, True);
      end;
    end;
  else
    begin
      if LEpoch = FLoadEpoch then
      begin
        Notice('Batch status could not be refreshed. Retained results remain.', True);
      end;
    end;
  end;
  window.clearTimeout(LTimer);
end;

procedure TStudioBatches.Refresh; async;
var
  LData: TJSObject;
  LJobs: TJSArray;
  LEpoch: Integer;
  LIndex: Integer;
  LActive: Boolean;
begin
  if FRefreshing then
  begin
    Exit;
  end;
  FRefreshing := True;
  window.clearTimeout(FPollTimer);
  Inc(FRefreshEpoch);
  LEpoch := FRefreshEpoch;
  LActive := False;
  FRefreshTimer := window.setTimeout(
    procedure()
    begin
      if LEpoch = FRefreshEpoch then
      begin
        Inc(FRefreshEpoch);
        Inc(FLoadEpoch);
        FRefreshing := False;
        if not FBusy then
        begin
          Notice('Status refresh is taking too long. Existing results remain; refresh to retry.',
            True);
        end;
      end;
    end, 15000);
  try
    LData := await(TJSObject, Json('/api/studio/jobs', 'GET', ''));
    if LEpoch <> FRefreshEpoch then
    begin
      Exit;
    end;
    LJobs := ArrayAt(LData, 'jobs');
    if (StudioText(LData, 'format') <> 'pythian.studio.jobs.v1') or (LJobs = nil) then
    begin
      raise Exception.Create('Batch history response is unsupported.');
    end;
    FJobs := LJobs;
    for LIndex := 0 to FJobs.length - 1 do
    begin
      LActive := LActive or ((StudioText(Obj(FJobs[LIndex]), 'kind') = 'train_generate') and
        not Terminal(StudioText(Obj(FJobs[LIndex]), 'status')));
    end;
    DrawHistory;
    if FSelectedId <> '' then
    begin
      await(LoadJob(FSelectedId));
    end;
    LActive := LActive or ((FJob <> nil) and not Terminal(StudioText(FJob, 'status')));
  except
    on LException: Exception do
    begin
      if (LEpoch = FRefreshEpoch) and not FBusy then
      begin
        Notice('History is unavailable: ' + LException.Message + ' Refresh to retry.', True);
      end;
    end;
  else
    begin
      if (LEpoch = FRefreshEpoch) and not FBusy then
      begin
        Notice('History is unavailable. Refresh to retry; existing settings remain.', True);
      end;
    end;
  end;
  if LEpoch = FRefreshEpoch then
  begin
    window.clearTimeout(FRefreshTimer);
    FRefreshing := False;
    if LActive then
    begin
      FPollTimer := window.setTimeout(
        procedure()
        begin
          Refresh;
        end, 3000);
    end;
  end;
end;

procedure TStudioBatches.CancelJob; async;
var
  LWrite: TJSObject;
  LData: TJSObject;
  LEpoch: Integer;
  LId: String;
begin
  if FBusy or (FJob = nil) or Terminal(StudioText(FJob, 'status')) then
  begin
    Exit;
  end;
  LId := StudioText(FJob, 'job_id');
  LWrite := TJSObject.new;
  LWrite['job_id'] := LId;
  LEpoch := BeginAction('Requesting cancellation at the next worker checkpoint…');
  try
    LData := await(TJSObject, Json('/api/studio/cancel', 'POST', TJSJSON.stringify(LWrite)));
    if (LEpoch = FEpoch) and (FSelectedId = LId) then
    begin
      if (StudioText(LData, 'format') <> 'pythian.studio.job.v1') or
        (StudioText(LData, 'job_id') <> LId) then
      begin
        raise Exception.Create('Cancellation response has a different batch identity.');
      end;
      FJob := Clone(LData);
      DrawJob;
      Notice('Cancellation response received; the recorded job status remains authoritative.');
    end;
  except
    on LException: Exception do
    begin
      if LEpoch = FEpoch then
      begin
        Notice('Cancellation is unconfirmed: ' + LException.Message + ' Refresh its status.', True);
      end;
    end;
  else
    begin
      if LEpoch = FEpoch then
      begin
        Notice('Cancellation is unconfirmed. Refresh its recorded status.', True);
      end;
    end;
  end;
  EndAction(LEpoch);
  Refresh;
end;

procedure TStudioBatches.RetryJob;
var
  LRequest: TJSObject;
begin
  if FBusy or (FPending <> nil) or (FJob = nil) or
    ((StudioText(FJob, 'status') <> 'failed') and (StudioText(FJob, 'status') <> 'cancelled')) then
  begin
    Exit;
  end;
  LRequest := Obj(FJob['request']);
  if LRequest = nil then
  begin
    Notice('Original settings are unavailable. No retry was created.', True);
    Exit;
  end;
  { A linked retry keeps the original source revision and settings. It is not
    inferred from the currently edited project or a changed set of seeds. }
  Invalidate;
  FRetryRequest := Clone(LRequest);
  FRetryRequest['job_id'] := NewId;
  FRetryRequest['retry_of'] := StudioText(FJob, 'job_id');
  UpdateControls;
  Notice('Linked retry uses the original saved revision and generation settings. ' +
    'Current project edits are excluded. Check original retry setup before enqueue.');
end;

function TStudioBatches.Edit(AEvent: TEventListenerEvent): Boolean;
begin
  Result := False;
  if not FBusy then
  begin
    if (TJSElement(AEvent.currentTarget).id = 'batch-seed') or
      (TJSElement(AEvent.currentTarget).id = 'batch-count') then
    begin
      FExplicitSeeds := nil;
      El('batch-seed-rule').textContent :=
        'Additional seeds use first seed +1,000 and +2,000. Example count is a cap, ' +
        'not a measure of learned musical variety.';
    end;
    Invalidate;
    Notice('Settings changed. Check setup again before generating.');
  end;
end;

function TStudioBatches.Click(AEvent: TJSMouseEvent): Boolean;
var
  LTarget: TJSElement;
  LId: String;
begin
  Result := False;
  LTarget := TJSElement(AEvent.currentTarget);
  LId := LTarget.id;
  if LId = 'batch-check' then
  begin
    Prepare;
  end
  else if LId = 'batch-submit' then
  begin
    Submit;
  end
  else if LId = 'batch-confirm' then
  begin
    ConfirmPending;
  end
  else if LId = 'batch-refresh' then
  begin
    Refresh;
  end
  else if LId = 'batch-current' then
  begin
    if not FBusy then
    begin
      Invalidate;
      SetProject(FProject, FUnsaved);
    end;
  end
  else if LId = 'batch-cancel' then
  begin
    CancelJob;
  end
  else if LId = 'batch-retry' then
  begin
    RetryJob;
  end
  else if LTarget.getAttribute('data-job') <> '' then
  begin
    LoadJob(LTarget.getAttribute('data-job'));
  end;
end;

constructor TStudioBatches.Create(const AFetch: TStudioFetch);
begin
  inherited Create;
  FFetch := AFetch;
  FJobs := TJSArray.new;
  Layout;
  FLive := TStudioLive.Create(FFetch, @BuildRequest);
  DrawHistory;
  UpdateControls;
end;

destructor TStudioBatches.Destroy;
begin
  FLive.Free;
  Inc(FEpoch);
  Inc(FRefreshEpoch);
  Inc(FLoadEpoch);
  window.clearTimeout(FTimer);
  window.clearTimeout(FPollTimer);
  window.clearTimeout(FRefreshTimer);
  inherited Destroy;
end;

end.
