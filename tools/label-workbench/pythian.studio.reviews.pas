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
unit pythian.studio.reviews;

{$mode delphi}
{$H+}

interface

uses
  JS,
  Web,
  Classes,
  SysUtils,
  Math,
  pythian.studio.sources;

type
  TStudioNextBatch = function(APacket: TJSObject): TJSPromise of object;

  TStudioReviews = class
  private
    FFetch: TStudioFetch;
    FNext: TStudioNextBatch;
    FReview: TJSObject;
    FComments: TJSArray;
    FCreateBody: String;
    FSaveBody: String;
    FBusy: Boolean;
    FEpoch: Integer;
    FTimer: NativeInt;
    function El(const AId: String): TJSElement;
    function Add(AParent: TJSElement; const ATag, AText, AClass: String): TJSElement;
    function Button(AParent: TJSElement; const AText, AAction, AValue: String): TJSElement;
    function Field(AParent: TJSElement; const AId, ALabel, ATag: String): TJSElement;
    procedure Option(AParent: TJSElement; const AValue, ALabel: String);
    procedure Notice(const AText: String; const AError: Boolean = False);
    function BeginAction(const AText: String): Integer;
    procedure EndAction(const AEpoch: Integer);
    procedure Controls;
    procedure StopAudio;
    procedure Layout;
    procedure Draw;
    procedure DrawComments;
    procedure DrawHistory(AData: TJSObject);
    function Json(const APath, AMethod, ABody: String): TJSObject; async;
    procedure CreateComparison; async;
    procedure LoadReview(const AId: String); async;
    procedure Save; async;
    procedure Pin; async;
    procedure NextBatch(const ASample: String); async;
    procedure AddComment(const ASample: String);
    function Answer(const AName, AId: String): String;
    function Reply: TJSObject;
    function Click(AEvent: TJSMouseEvent): Boolean;
    function Play(AEvent: TEventListenerEvent): Boolean;
    function Hide(AEvent: TEventListenerEvent): Boolean;
  public
    constructor Create(const AFetch: TStudioFetch; const ANext: TStudioNextBatch);
    destructor Destroy; override;
    procedure Refresh; async;
  end;

implementation

type
  EReviewHttp = class(Exception)
  public
    Status: Integer;
  end;

function Arr(AObject: TJSObject; const AName: String): TJSArray;
begin
  Result := nil;
  if (AObject <> nil) and isArray(AObject[AName]) then
  begin
    Result := TJSArray(AObject[AName]);
  end;
end;

function TStudioReviews.El(const AId: String): TJSElement;
begin
  Result := document.getElementById(AId);
end;

function TStudioReviews.Add(AParent: TJSElement;
  const ATag, AText, AClass: String): TJSElement;
begin
  Result := document.createElement(ATag);
  Result.textContent := AText;
  Result.className := AClass;
  AParent.appendChild(Result);
end;

function TStudioReviews.Button(AParent: TJSElement;
  const AText, AAction, AValue: String): TJSElement;
begin
  Result := Add(AParent, 'button', AText, '');
  Result.setAttribute('type', 'button');
  Result.setAttribute('data-action', AAction);
  Result.setAttribute('data-value', AValue);
  Result.addEventListener('click', @Click);
end;

function TStudioReviews.Field(AParent: TJSElement;
  const AId, ALabel, ATag: String): TJSElement;
var
  LLabel: TJSElement;
begin
  LLabel := Add(AParent, 'label', ALabel, 'field');
  LLabel.setAttribute('for', AId);
  Result := Add(LLabel, ATag, '', '');
  Result.id := AId;
end;

procedure TStudioReviews.Option(AParent: TJSElement; const AValue, ALabel: String);
var
  LOption: TJSElement;
begin
  LOption := Add(AParent, 'option', ALabel, '');
  LOption.setAttribute('value', AValue);
end;

procedure TStudioReviews.Notice(const AText: String; const AError: Boolean);
begin
  El('review-notice').textContent := AText;
  if AError then
  begin
    El('review-notice').setAttribute('role', 'alert');
  end
  else
  begin
    El('review-notice').setAttribute('role', 'status');
  end;
end;

procedure TStudioReviews.Controls;
var
  LNodes: TJSNodeList;
  LIndex: Integer;
  LNode: TJSElement;
  LDisabled: Boolean;
begin
  LNodes := El('studio-reviews').querySelectorAll('button,input,select,textarea');
  for LIndex := 0 to LNodes.length - 1 do
  begin
    LNode := TJSElement(LNodes[LIndex]);
    LDisabled := FBusy;
    if (FSaveBody <> '') and (LNode.getAttribute('data-action') <> 'save') and
      (LNode.getAttribute('data-action') <> 'reload') then
    begin
      LDisabled := True;
    end;
    if (FCreateBody <> '') and (LNode.getAttribute('data-action') <> 'create') then
    begin
      LDisabled := True;
    end;
    if LDisabled then
    begin
      LNode.setAttribute('disabled', '');
    end
    else
    begin
      LNode.removeAttribute('disabled');
    end;
  end;
  if El('review-save') <> nil then
  begin
    if FSaveBody = '' then
    begin
      El('review-save').textContent := 'Save feedback';
    end
    else
    begin
      El('review-save').textContent := 'Retry same Save';
    end;
  end;
  if FCreateBody <> '' then
  begin
    El('review-create').textContent := 'Retry same comparison';
  end
  else
  begin
    El('review-create').textContent := 'Start listening';
  end;
end;

function TStudioReviews.BeginAction(const AText: String): Integer;
var
  LEpoch: Integer;
begin
  Inc(FEpoch);
  LEpoch := FEpoch;
  Result := LEpoch;
  FBusy := True;
  Notice(AText);
  Controls;
  FTimer := window.setTimeout(
    procedure()
    begin
      if LEpoch = FEpoch then
      begin
        Inc(FEpoch);
        FBusy := False;
        Notice('Response unconfirmed. Your settings and Save identity remain; retry or reload saved feedback.', True);
        Controls;
      end;
    end, 15000);
end;

procedure TStudioReviews.EndAction(const AEpoch: Integer);
begin
  if AEpoch = FEpoch then
  begin
    window.clearTimeout(FTimer);
    FBusy := False;
    Controls;
  end;
end;

procedure TStudioReviews.StopAudio;
var
  LNodes: TJSNodeList;
  LIndex: Integer;
  LPlayer: TJSHTMLAudioElement;
begin
  LNodes := El('studio-reviews').querySelectorAll('audio');
  for LIndex := 0 to LNodes.length - 1 do
  begin
    LPlayer := TJSHTMLAudioElement(LNodes[LIndex]);
    LPlayer.pause;
    LPlayer.removeAttribute('src');
    LPlayer.load;
  end;
end;

constructor TStudioReviews.Create(const AFetch: TStudioFetch; const ANext: TStudioNextBatch);
begin
  inherited Create;
  FFetch := AFetch;
  FNext := ANext;
  FComments := TJSArray.new;
  Layout;
  window.addEventListener('pagehide', @Hide);
end;

destructor TStudioReviews.Destroy;
begin
  Inc(FEpoch);
  window.clearTimeout(FTimer);
  window.removeEventListener('pagehide', @Hide);
  StopAudio;
  inherited Destroy;
end;

procedure TStudioReviews.Layout;
var
  LMount: TJSElement;
  LDetails: TJSElement;
  LField: TJSElement;
  LQualification: TJSElement;
begin
  LMount := El('studio-reviews');
  LMount.textContent := '';
  Add(LMount, 'p', 'Choose finished auditions. Describe what fits, what repeats, and what to try next.', '');
  Button(LMount, 'Refresh auditions and history', 'refresh', '');
  LField := Add(LMount, 'p', 'Generate an audition to begin.', '');
  LField.id := 'review-notice';
  LField.setAttribute('aria-live', 'polite');
  LDetails := Add(LMount, 'details', '', '');
  Add(LDetails, 'summary', 'New comparison', '');
  LField := Field(LDetails, 'review-output-a', 'First passage', 'select');
  Option(LField, '', 'Choose a finished audition');
  LField := Field(LDetails, 'review-output-b', 'Second passage (optional)', 'select');
  Option(LField, '', 'Single passage');
  LField := Field(LDetails, 'review-question', 'What are you listening for?', 'input');
  TJSHTMLInputElement(LField).value := 'Does this sound like the music you wanted to make?';
  LField.setAttribute('maxlength', '1024');
  LField := Field(LDetails, 'review-context', 'Context (optional)', 'input');
  LField.setAttribute('maxlength', '2048');
  LField := Field(LDetails, 'review-styles', 'Labels for these results (one per line)', 'textarea');
  TJSHTMLTextAreaElement(LField).value := 'Matches my intent' + #10 + 'Different direction';
  LField.setAttribute('maxlength', '512');
  LField := Field(LDetails, 'review-blind', 'Hide sample identities until feedback is saved', 'input');
  LField.setAttribute('type', 'checkbox');
  TJSHTMLInputElement(LField).checked := True;
  LField := Field(LDetails, 'review-mode', 'Review purpose', 'select');
  Option(LField, 'development', 'Explore and improve');
  Option(LField, 'frozen_evaluation', 'Keep comparison fixed');
  LQualification := Add(LDetails, 'details', '', '');
  Add(LQualification, 'summary', 'About review purpose', '');
  Add(LQualification, 'p', 'A frozen comparison keeps this setup fixed. It does not turn previously used sources into an untouched test.', '');
  LField := Button(LDetails, 'Start listening', 'create', '');
  LField.id := 'review-create';
  LField := Add(LMount, 'div', '', '');
  LField.id := 'review-current';
  Add(LMount, 'h3', 'Comparison history', '');
  LField := Add(LMount, 'div', 'No comparisons yet.', '');
  LField.id := 'review-history';
end;

function TStudioReviews.Json(const APath, AMethod, ABody: String): TJSObject; async;
var
  LResponse: TJSResponse;
  LError: EReviewHttp;
  LMessage: String;
begin
  try
    LResponse := await(TJSResponse, FFetch(APath, AMethod, ABody));
    if (LResponse.status <> 200) and (LResponse.status <> 202) then
    begin
      LMessage := await(String, LResponse.text());
      LError := EReviewHttp.Create(Copy(Trim(LMessage), 1, 256));
      LError.Status := LResponse.status;
      raise LError;
    end;
    Result := await(TJSObject, LResponse.json());
  except
    on E: Exception do
    begin
      raise;
    end;
    else
    begin
      raise Exception.Create('The connection was interrupted. Retry the same action.');
    end;
  end;
end;

procedure TStudioReviews.Refresh; async;
var
  LEpoch: Integer;
  LJobs: TJSObject;
  LHistory: TJSObject;
  LRows: TJSArray;
  LJob: TJSObject;
  LIndex: Integer;
  LOrdinal: Integer;
  LCount: Integer;
  LValue: String;
  LCaption: String;
  LBatchNumber: Integer;
  LOldA: String;
  LOldB: String;
begin
  if FBusy then
  begin
    Exit;
  end;
  LEpoch := BeginAction('Loading finished auditions and history…');
  try
    LJobs := await(TJSObject, Json('/api/studio/jobs', 'GET', ''));
    LHistory := await(TJSObject, Json('/api/studio/reviews', 'GET', ''));
    if LEpoch <> FEpoch then
    begin
      Exit;
    end;
    LOldA := TJSHTMLSelectElement(El('review-output-a')).value;
    LOldB := TJSHTMLSelectElement(El('review-output-b')).value;
    El('review-output-a').textContent := '';
    El('review-output-b').textContent := '';
    Option(El('review-output-a'), '', 'Choose a finished audition');
    Option(El('review-output-b'), '', 'Single passage');
    LRows := Arr(LJobs, 'jobs');
    LBatchNumber := 0;
    if LRows <> nil then
    begin
      for LIndex := 0 to LRows.length - 1 do
      begin
        LJob := TJSObject(LRows[LIndex]);
        if (StudioText(LJob, 'kind') <> 'train_generate') or
          (StudioText(LJob, 'status') <> 'completed') then
        begin
          Continue;
        end;
        LCount := Trunc(StudioNumber(LJob, 'completed_render_count'));
        Inc(LBatchNumber);
        LCaption := StudioText(LJob, 'project_name');
        if LCaption = '' then
        begin
          LCaption := 'Batch ' + IntToStr(LBatchNumber);
        end;
        for LOrdinal := 0 to Min(3, LCount) - 1 do
        begin
          LValue := StudioText(LJob, 'job_id') + '|' + IntToStr(LOrdinal);
          Option(El('review-output-a'), LValue, LCaption + ' · audition ' + IntToStr(LOrdinal + 1));
          Option(El('review-output-b'), LValue, LCaption + ' · audition ' + IntToStr(LOrdinal + 1));
        end;
      end;
    end;
    TJSHTMLSelectElement(El('review-output-a')).value := LOldA;
    TJSHTMLSelectElement(El('review-output-b')).value := LOldB;
    DrawHistory(LHistory);
    Notice('Choose a finished passage or reopen saved feedback.');
  except
    on E: Exception do
    begin
      if LEpoch = FEpoch then
      begin
        Notice(E.Message, True);
      end;
    end;
  end;
  EndAction(LEpoch);
end;

procedure TStudioReviews.DrawHistory(AData: TJSObject);
var
  LRows: TJSArray;
  LRow: TJSObject;
  LIndex: Integer;
  LCaption: String;
begin
  El('review-history').textContent := '';
  LRows := Arr(AData, 'reviews');
  if (LRows = nil) or (LRows.length = 0) then
  begin
    El('review-history').textContent := 'No comparisons yet.';
    Exit;
  end;
  for LIndex := LRows.length - 1 downto 0 do
  begin
    LRow := TJSObject(LRows[LIndex]);
    LCaption := StudioText(LRow, 'question') + ' · ' + StudioText(LRow, 'status');
    if Boolean(TJSObject(LRow['pin'])['pinned']) then
    begin
      LCaption := 'Pinned · ' + LCaption;
    end;
    Button(El('review-history'), LCaption, 'open', StudioText(LRow, 'review_id'));
  end;
end;

procedure TStudioReviews.CreateComparison; async;
var
  LWrite: TJSObject;
  LOutputs: TJSArray;
  LStyles: TJSArray;
  LLines: TStringList;
  LValue: String;
  LId: String;
  LRow: TJSObject;
  LSeparator: Integer;
  LIndex: Integer;
  LEpoch: Integer;
  LData: TJSObject;
begin
  if FBusy or (FSaveBody <> '') then
  begin
    Exit;
  end;
  try
    if FCreateBody = '' then
    begin
      LWrite := TJSObject.new;
      LWrite['format'] := 'pythian.studio.review.write.v1';
      LId := 'r_' + IntToStr(Trunc(TJSDate.now)) + '_' +
        IntToStr(Random(1000000000));
      LWrite['review_id'] := LId;
      LWrite['question'] := TJSHTMLInputElement(El('review-question')).value;
      LWrite['context'] := TJSHTMLInputElement(El('review-context')).value;
      LWrite['mode'] := TJSHTMLSelectElement(El('review-mode')).value;
      LWrite['blind'] := TJSHTMLInputElement(El('review-blind')).checked;
      LOutputs := TJSArray.new;
      LWrite['outputs'] := LOutputs;
      for LIndex := 0 to 1 do
      begin
        LValue := TJSHTMLSelectElement(El('review-output-' + Chr(Ord('a') + LIndex))).value;
        if LValue = '' then
        begin
          if LIndex = 0 then
          begin
            raise Exception.Create('Choose a finished audition first.');
          end;
          Continue;
        end;
        LSeparator := Pos('|', LValue);
        if LSeparator <= 1 then
        begin
          raise Exception.Create('Reload the finished audition list.');
        end;
        LRow := TJSObject.new;
        LRow['job_id'] := Copy(LValue, 1, LSeparator - 1);
        LRow['ordinal'] := StrToInt(Copy(LValue, LSeparator + 1, Length(LValue)));
        LOutputs.push(LRow);
      end;
      LStyles := TJSArray.new;
      LWrite['style_choices'] := LStyles;
      LLines := TStringList.Create;
      try
        LLines.Text := TJSHTMLTextAreaElement(El('review-styles')).value;
        for LIndex := 0 to LLines.Count - 1 do
        begin
          LValue := Trim(LLines[LIndex]);
          if LValue <> '' then
          begin
            LStyles.push(LValue);
          end;
        end;
      finally
        LLines.Free;
      end;
      FCreateBody := TJSJSON.stringify(LWrite);
    end;
  except
    on E: Exception do
    begin
      Notice(E.Message, True);
      Exit;
    end;
  end;
  LEpoch := BeginAction('Preparing this comparison…');
  try
    LData := await(TJSObject, Json('/api/studio/review', 'POST', FCreateBody));
    if LEpoch <> FEpoch then
    begin
      Exit;
    end;
    FCreateBody := '';
    FSaveBody := '';
    FReview := LData;
    FComments := Arr(FReview, 'comments');
    Draw;
    Notice('Listen first. Nothing is answered for you.');
  except
    on E: Exception do
    begin
      if LEpoch = FEpoch then
      begin
        if (E is EReviewHttp) and (EReviewHttp(E).Status >= 400) and
          (EReviewHttp(E).Status < 500) then
        begin
          FCreateBody := '';
        end;
        Notice(E.Message + ' Your comparison settings remain.', True);
      end;
    end;
  end;
  EndAction(LEpoch);
end;

procedure TStudioReviews.LoadReview(const AId: String); async;
var
  LEpoch: Integer;
  LData: TJSObject;
begin
  if FBusy then
  begin
    Exit;
  end;
  LEpoch := BeginAction('Loading saved feedback…');
  try
    LData := await(TJSObject, Json('/api/studio/review?id=' + encodeURIComponent(AId), 'GET', ''));
    if LEpoch <> FEpoch then
    begin
      Exit;
    end;
    FReview := LData;
    FSaveBody := '';
    FComments := Arr(FReview, 'comments');
    Draw;
    Notice('Saved feedback loaded. You can correct it and Save a new version.');
  except
    on E: Exception do
    begin
      if LEpoch = FEpoch then
      begin
        Notice(E.Message, True);
      end;
    end;
  end;
  EndAction(LEpoch);
end;

function TStudioReviews.Answer(const AName, AId: String): String;
var
  LRows: TJSArray;
  LIndex: Integer;
  LRow: TJSObject;
begin
  Result := '';
  LRows := Arr(FReview, AName);
  if LRows = nil then
  begin
    Exit;
  end;
  for LIndex := 0 to LRows.length - 1 do
  begin
    LRow := TJSObject(LRows[LIndex]);
    if StudioText(LRow, 'id') = AId then
    begin
      if isString(LRow['value']) then
      begin
        Exit(String(LRow['value']));
      end;
      Exit(IntToStr(Trunc(Double(LRow['value']))));
    end;
  end;
end;

procedure TStudioReviews.Draw;
var
  LMount: TJSElement;
  LCard: TJSElement;
  LDetails: TJSElement;
  LField: TJSElement;
  LPlayer: TJSHTMLAudioElement;
  LSamples: TJSArray;
  LStyles: TJSArray;
  LNames: TStringList;
  LSample: TJSObject;
  LStyle: TJSObject;
  LAlias: String;
  LId: String;
  LName: String;
  LAnchors: TJSArray;
  LIndex: Integer;
  LChoiceIndex: Integer;
begin
  StopAudio;
  LMount := El('review-current');
  LMount.textContent := '';
  if FReview = nil then
  begin
    Exit;
  end;
  Add(LMount, 'h3', StudioText(FReview, 'question'), '');
  if StudioText(FReview, 'context') <> '' then
  begin
    Add(LMount, 'p', StudioText(FReview, 'context'), '');
  end;
  if Boolean(FReview['blind']) and not Boolean(FReview['revealed']) then
  begin
    Add(LMount, 'p', 'Sample identities are hidden until you Save completed feedback.', '');
  end;
  LSamples := Arr(FReview, 'samples');
  LStyles := Arr(FReview, 'style_options');
  LNames := TStringList.Create;
  try
    LNames.Add('fit');
    LNames.Add('continuity');
    LNames.Add('repetition');
    LNames.Add('technical');
    for LIndex := 0 to LSamples.length - 1 do
    begin
      LSample := TJSObject(LSamples[LIndex]);
      LAlias := StudioText(LSample, 'sample_id');
      LCard := Add(LMount, 'fieldset', '', '');
      Add(LCard, 'legend', StudioText(LSample, 'label'), '');
      LPlayer := TJSHTMLAudioElement(Add(LCard, 'audio', '', ''));
      LPlayer.id := 'review-audio-' + LAlias;
      LPlayer.controls := True;
      LPlayer.preload := 'metadata';
      LPlayer.src := StudioText(LSample, 'audio_url');
      LPlayer.addEventListener('play', @Play);
      LPlayer.setAttribute('aria-label', StudioText(LSample, 'label') + ' audio');
      LId := 'style_' + LAlias;
      LField := Field(LCard, 'review-answer-' + LId, 'Which label fits this result?', 'select');
      Option(LField, '', 'Choose after listening');
      for LChoiceIndex := 0 to LStyles.length - 1 do
      begin
        LStyle := TJSObject(LStyles[LChoiceIndex]);
        Option(LField, StudioText(LStyle, 'value'), StudioText(LStyle, 'label'));
      end;
      TJSHTMLSelectElement(LField).value := Answer('choices', LId);
      for LChoiceIndex := 0 to LNames.Count - 1 do
      begin
        LName := LNames[LChoiceIndex];
        LId := LName + '_' + LAlias;
        if LName = 'fit' then
        begin
          LField := Field(LCard, 'review-answer-' + LId, 'Style fit', 'select');
        end
        else if LName = 'technical' then
        begin
          LField := Field(LCard, 'review-answer-' + LId, 'Sound quality', 'select');
        end
        else if LName = 'continuity' then
        begin
          LField := Field(LCard, 'review-answer-' + LId, 'Flow between sounds', 'select');
        end
        else if LName = 'repetition' then
        begin
          LField := Field(LCard, 'review-answer-' + LId, 'How repetition feels', 'select');
        end
        else
        begin
          LField := Field(LCard, 'review-answer-' + LId, LName, 'select');
        end;
        Option(LField, '', 'Choose after listening');
        LAnchors := TJSArray(TJSObject(FReview['score_anchors'])[LName]);
        Option(LField, '0', '0 — ' + String(LAnchors[0]));
        Option(LField, '1', '1 — ' + String(LAnchors[1]));
        Option(LField, '2', '2 — ' + String(LAnchors[2]));
        Option(LField, '3', '3 — ' + String(LAnchors[3]));
        Option(LField, 'unknown', 'Cannot judge yet');
        TJSHTMLSelectElement(LField).value := Answer('scores', LId);
      end;
      LField := Field(LCard, 'review-comment-' + LAlias, 'Optional note at the playhead', 'input');
      LField.setAttribute('maxlength', '512');
      Button(LCard, 'Add note here', 'comment', LAlias);
      if Boolean(FReview['revealed']) then
      begin
        LDetails := Add(LCard, 'details', '', '');
        Add(LDetails, 'summary', 'Source and saved settings', '');
        Add(LDetails, 'pre', Copy(TJSJSON.stringify(LSample['assignment']), 1, 12000), 'batch-identity');
      end;
      if StudioText(FReview, 'status') = 'submitted' then
      begin
        Button(LCard, 'Use these settings for next batch', 'next', LAlias);
      end;
    end;
  finally
    LNames.Free;
  end;
  if LSamples.length = 2 then
  begin
    LField := Field(LMount, 'review-answer-preference', 'Which would you keep?', 'select');
    Option(LField, '', 'Choose after listening');
    Option(LField, 'sample_a', 'Sample A');
    Option(LField, 'sample_b', 'Sample B');
    Option(LField, 'neither', 'Neither');
    Option(LField, 'unknown', 'Unsure');
    TJSHTMLSelectElement(LField).value := Answer('choices', 'preference');
  end;
  LField := Add(LMount, 'div', '', '');
  LField.id := 'review-comments';
  DrawComments;
  LField := Button(LMount, 'Save feedback', 'save', '');
  LField.id := 'review-save';
  Button(LMount, 'Reload saved feedback', 'reload', '');
  if Boolean(TJSObject(FReview['pin'])['pinned']) then
  begin
    LField := Button(LMount, 'Unpin result', 'pin', '');
  end
  else
  begin
    LField := Button(LMount, 'Pin useful result', 'pin', '');
  end;
  LField.id := 'review-pin';
end;

procedure TStudioReviews.DrawComments;
var
  LIndex: Integer;
  LRow: TJSObject;
  LBox: TJSElement;
  LSamples: TJSArray;
  LSample: TJSObject;
  LSampleIndex: Integer;
  LWhen: String;
begin
  El('review-comments').textContent := '';
  if FComments = nil then
  begin
    FComments := TJSArray.new;
  end;
  for LIndex := 0 to FComments.length - 1 do
  begin
    LRow := TJSObject(FComments[LIndex]);
    LWhen := '';
    LSamples := Arr(FReview, 'samples');
    for LSampleIndex := 0 to LSamples.length - 1 do
    begin
      LSample := TJSObject(LSamples[LSampleIndex]);
      if StudioText(LSample, 'sample_id') = StudioText(LRow, 'asset_id') then
      begin
        LWhen := ' at ' + FloatToStrF(StudioNumber(LRow, 'frame') /
          StudioNumber(LSample, 'sample_rate'), ffFixed, 8, 1) + ' seconds';
      end;
    end;
    LBox := Add(El('review-comments'), 'p', StudioText(LRow, 'asset_id') + LWhen + ': ' +
      StudioText(LRow, 'text'), '');
    Button(LBox, 'Remove note', 'remove-comment', IntToStr(LIndex));
  end;
end;

procedure TStudioReviews.AddComment(const ASample: String);
var
  LPlayer: TJSHTMLAudioElement;
  LSamples: TJSArray;
  LSample: TJSObject;
  LIndex: Integer;
  LText: String;
  LFrame: Double;
  LRow: TJSObject;
begin
  if FBusy or (FReview = nil) or (FSaveBody <> '') then
  begin
    Exit;
  end;
  LText := Trim(TJSHTMLInputElement(El('review-comment-' + ASample)).value);
  if LText = '' then
  begin
    Notice('Write a short note first.', True);
    Exit;
  end;
  LSamples := Arr(FReview, 'samples');
  for LIndex := 0 to LSamples.length - 1 do
  begin
    LSample := TJSObject(LSamples[LIndex]);
    if StudioText(LSample, 'sample_id') = ASample then
    begin
      LPlayer := TJSHTMLAudioElement(El('review-audio-' + ASample));
      LFrame := Floor(LPlayer.currentTime * StudioNumber(LSample, 'sample_rate'));
      LFrame := Max(0, Min(StudioNumber(LSample, 'frames') - 1, LFrame));
      if FComments.length >= 64 then
      begin
        Notice('This review already has 64 notes. Remove one to add another.', True);
        Exit;
      end;
      LRow := TJSObject.new;
      LRow['asset_id'] := ASample;
      LRow['frame'] := LFrame;
      LRow['text'] := LText;
      FComments.push(LRow);
      TJSHTMLInputElement(El('review-comment-' + ASample)).value := '';
      DrawComments;
      Notice('Note added at ' + FloatToStrF(LPlayer.currentTime, ffFixed, 8, 1) + ' seconds. Save to keep it.');
      Exit;
    end;
  end;
end;

function TStudioReviews.Reply: TJSObject;
var
  LSpec: TJSObject;
  LRows: TJSArray;
  LAnswers: TJSArray;
  LRow: TJSObject;
  LIndex: Integer;
  LNameIndex: Integer;
  LName: String;
  LId: String;
  LValue: String;
begin
  Result := TJSObject.new;
  Result['format'] := 'pythian.studio.review.response.v1';
  Result['review_id'] := FReview['review_id'];
  Result['expected_revision'] := FReview['revision'];
  Result['reviewer'] := 'operator';
  Result['status'] := 'submitted';
  Result['comments'] := FComments;
  LSpec := TJSObject(FReview['answer_spec']);
  for LNameIndex := 0 to 1 do
  begin
    LName := 'choices';
    if LNameIndex = 1 then
    begin
      LName := 'scores';
    end;
    LRows := Arr(LSpec, LName);
    LAnswers := TJSArray.new;
    Result[LName] := LAnswers;
    for LIndex := 0 to LRows.length - 1 do
    begin
      LId := StudioText(TJSObject(LRows[LIndex]), 'id');
      LValue := TJSHTMLSelectElement(El('review-answer-' + LId)).value;
      if LValue = '' then
      begin
        TJSHTMLSelectElement(El('review-answer-' + LId)).focus;
        raise Exception.Create('Choose an answer or Cannot judge for each listening question.');
      end;
      LRow := TJSObject.new;
      LAnswers.push(LRow);
      LRow['id'] := LId;
      if (LName = 'scores') and (LValue <> 'unknown') then
      begin
        LRow['value'] := StrToInt(LValue);
      end
      else
      begin
        LRow['value'] := LValue;
      end;
    end;
  end;
end;

procedure TStudioReviews.Save; async;
var
  LEpoch: Integer;
  LData: TJSObject;
begin
  if FBusy or (FReview = nil) then
  begin
    Exit;
  end;
  if FSaveBody = '' then
  begin
    try
      FSaveBody := TJSJSON.stringify(Reply);
    except
      on E: Exception do
      begin
        Notice(E.Message, True);
        Exit;
      end;
    end;
  end;
  LEpoch := BeginAction('Saving feedback…');
  try
    LData := await(TJSObject, Json('/api/studio/review/response', 'POST', FSaveBody));
    if LEpoch <> FEpoch then
    begin
      Exit;
    end;
    FSaveBody := '';
    FReview := LData;
    FComments := Arr(FReview, 'comments');
    Draw;
    Notice('Feedback saved. Previous versions and original audio are retained.');
  except
    on E: Exception do
    begin
      if LEpoch = FEpoch then
      begin
        if (E is EReviewHttp) and (EReviewHttp(E).Status >= 400) and
          (EReviewHttp(E).Status < 500) then
        begin
          FSaveBody := '';
        end;
        Notice(E.Message + ' Your answers remain visible.', True);
      end;
    end;
  end;
  EndAction(LEpoch);
end;

procedure TStudioReviews.Pin; async;
var
  LEpoch: Integer;
  LWrite: TJSObject;
  LData: TJSObject;
begin
  if FBusy or (FReview = nil) then
  begin
    Exit;
  end;
  LWrite := TJSObject.new;
  LWrite['review_id'] := FReview['review_id'];
  LWrite['expected_revision'] := TJSObject(FReview['pin'])['revision'];
  LWrite['pinned'] := not Boolean(TJSObject(FReview['pin'])['pinned']);
  LEpoch := BeginAction('Saving result pin…');
  try
    LData := await(TJSObject, Json('/api/studio/review/pin', 'POST', TJSJSON.stringify(LWrite)));
    if LEpoch = FEpoch then
    begin
      FReview['pin'] := LData['pin'];
      if Boolean(TJSObject(FReview['pin'])['pinned']) then
      begin
        El('review-pin').textContent := 'Unpin result';
      end
      else
      begin
        El('review-pin').textContent := 'Pin useful result';
      end;
      Notice('Result pin saved.');
    end;
  except
    on E: Exception do
    begin
      if LEpoch = FEpoch then
      begin
        Notice(E.Message, True);
      end;
    end;
  end;
  EndAction(LEpoch);
end;

procedure TStudioReviews.NextBatch(const ASample: String); async;
var
  LEpoch: Integer;
  LWrite: TJSObject;
  LData: TJSObject;
  LAccepted: Boolean;
begin
  if FBusy or (FReview = nil) or not Assigned(FNext) then
  begin
    Exit;
  end;
  LWrite := TJSObject.new;
  LWrite['review_id'] := FReview['review_id'];
  LWrite['sample_id'] := ASample;
  LEpoch := BeginAction('Preparing retained settings…');
  try
    LData := await(TJSObject, Json('/api/studio/review/next-batch?id=' +
      encodeURIComponent(StudioText(FReview, 'review_id')) + '&sample=' +
      encodeURIComponent(ASample), 'GET', ''));
    if LEpoch = FEpoch then
    begin
      LAccepted := await(Boolean, FNext(LData));
      if not LAccepted then
      begin
        raise Exception.Create('Next-batch settings were not applied. Your existing selection remains.');
      end;
      Notice('Settings copied for the next batch. Deliberately change what you want, then Check setup and Generate.');
    end;
  except
    on E: Exception do
    begin
      if LEpoch = FEpoch then
      begin
        Notice(E.Message, True);
      end;
    end;
  end;
  EndAction(LEpoch);
end;

function TStudioReviews.Click(AEvent: TJSMouseEvent): Boolean;
var
  LTarget: TJSElement;
  LAction: String;
  LValue: String;
  LIndex: Integer;
begin
  Result := True;
  LTarget := TJSElement(AEvent.currentTarget);
  LAction := LTarget.getAttribute('data-action');
  LValue := LTarget.getAttribute('data-value');
  if FBusy then
  begin
    Exit;
  end;
  if LAction = 'refresh' then
  begin
    Refresh;
  end
  else if LAction = 'create' then
  begin
    CreateComparison;
  end
  else if LAction = 'open' then
  begin
    LoadReview(LValue);
  end
  else if LAction = 'reload' then
  begin
    LoadReview(StudioText(FReview, 'review_id'));
  end
  else if LAction = 'save' then
  begin
    Save;
  end
  else if LAction = 'pin' then
  begin
    Pin;
  end
  else if LAction = 'next' then
  begin
    NextBatch(LValue);
  end
  else if LAction = 'comment' then
  begin
    AddComment(LValue);
  end
  else if LAction = 'remove-comment' then
  begin
    if TryStrToInt(LValue, LIndex) and (LIndex >= 0) and (LIndex < FComments.length) then
    begin
      FComments.splice(LIndex, 1);
      DrawComments;
      TJSHTMLElement(El('review-save')).focus;
      Notice('Note removed. Save to keep the change.');
    end;
  end;
end;

function TStudioReviews.Play(AEvent: TEventListenerEvent): Boolean;
var
  LNodes: TJSNodeList;
  LIndex: Integer;
begin
  Result := True;
  LNodes := El('studio-reviews').querySelectorAll('audio');
  for LIndex := 0 to LNodes.length - 1 do
  begin
    if LNodes[LIndex] <> AEvent.currentTarget then
    begin
      TJSHTMLAudioElement(LNodes[LIndex]).pause;
    end;
  end;
end;

function TStudioReviews.Hide(AEvent: TEventListenerEvent): Boolean;
begin
  Result := True;
  StopAudio;
end;

end.
