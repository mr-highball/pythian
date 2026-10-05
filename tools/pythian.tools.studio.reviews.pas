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
unit pythian.tools.studio.reviews;

{$mode delphi}
{$H+}

interface

uses
  fpjson;

const
  StudioReviewWriteFormat = 'pythian.studio.review.write.v1';
  StudioReviewFormat = 'pythian.studio.review.v1';
  StudioReviewResponseFormat = 'pythian.studio.review.response.v1';

{ Borrowed inputs, detached owned results. Answers use existing listening
  journals. A review's private assignment never enters a blind public payload. }
function CreateStudioReview(const ACatalogRoot: String;
  const AWrite: TJSONObject): TJSONObject;
function ReadStudioReview(const ACatalogRoot, AReviewId: String): TJSONObject;
function ListStudioReviews(const ACatalogRoot: String): TJSONObject;
function CommitStudioReview(const ACatalogRoot: String;
  const AWrite: TJSONObject): TJSONObject;
function PinStudioReview(const ACatalogRoot, AReviewId: String;
  const AExpectedRevision: Int64; const APinned: Boolean): TJSONObject;
function PrepareStudioNextBatch(const ACatalogRoot, AReviewId,
  ASampleId: String): TJSONObject;
function IsStudioReviewListeningItemHidden(const ACatalogRoot,
  AItemId: String): Boolean;
{ Studio feedback has one owning UI even after reveal or withdrawal. }
function IsStudioReviewListeningItem(const ACatalogRoot,
  AItemId: String): Boolean;
{ Server-only stream binding. Do not serialize this object to the operator or
  copy its source hash into a pre-reveal media ETag/content-disposition. }
function ResolveStudioReviewAsset(const ACatalogRoot, AReviewId,
  ASampleId: String): TJSONObject;

implementation

uses
  Classes,
  SysUtils,
  pythian.audio,
  pythian.tools.studio.jobs,
  pythian.tools.studio.projects,
  pythian.tools.listen.catalog;

const
  CQueueArrays: array[0..1] of String = ('items', 'completed');
  CAnswerArrays: array[0..2] of String = ('choices', 'scores', 'comments');
  CScoreNames: array[0..3] of String = ('fit', 'continuity', 'repetition', 'technical');

var
  GReviewLock: TRTLCriticalSection;

procedure Need(const ACondition: Boolean; const AMessage: String);
begin
  if not ACondition then
  begin
    raise EAudio.Create(AMessage);
  end;
end;

function SafeId(const AText: String): Boolean;
var
  LCharacter: Char;
begin
  Result := (Length(AText) >= 1) and (Length(AText) <= 64);
  for LCharacter in AText do
  begin
    Result := Result and (LCharacter in ['a'..'z', 'A'..'Z', '0'..'9', '_', '-']);
  end;
  Result := Result and (Pos('.', AText) = 0) and
    (UpperCase(AText) <> 'CON') and (UpperCase(AText) <> 'PRN') and
    (UpperCase(AText) <> 'AUX') and (UpperCase(AText) <> 'NUL') and
    not ((Length(AText) = 4) and
      ((Copy(UpperCase(AText), 1, 3) = 'COM') or
       (Copy(UpperCase(AText), 1, 3) = 'LPT')) and (AText[4] in ['1'..'9']));
end;

procedure Keys(const AObject: TJSONObject; const AAllowed: String);
var
  LIndex: Integer;
begin
  Need(AObject <> nil, 'Review object is required');
  for LIndex := 0 to AObject.Count - 1 do
  begin
    Need(Pos('|' + AObject.Names[LIndex] + '|', AAllowed) > 0,
      'Unsupported review field: ' + AObject.Names[LIndex]);
  end;
end;

function Text(const AObject: TJSONObject; const AKey: String;
  const AMaximum: Integer): String;
var
  LValue: TJSONData;
begin
  LValue := AObject.Find(AKey);
  Need((LValue <> nil) and (LValue.JSONType = jtString), 'Review text required: ' + AKey);
  Result := LValue.AsString;
  Need(Length(Result) <= AMaximum, 'Review text exceeds bound: ' + AKey);
end;

function IntegerValue(const AObject: TJSONObject; const AKey: String): Int64;
var
  LValue: TJSONData;
begin
  LValue := AObject.Find(AKey);
  Need((LValue <> nil) and (LValue.JSONType = jtNumber) and
    (TJSONNumber(LValue).NumberType in [ntInteger, ntInt64]), 'Exact review integer required: ' + AKey);
  Result := LValue.AsInt64;
end;

function Root(const ACatalogRoot: String): String;
begin
  Need(DirectoryExists(ACatalogRoot), 'Review catalog is unavailable');
  Result := IncludeTrailingPathDelimiter(ExpandFileName(ACatalogRoot)) + 'studio' +
    PathDelim + 'reviews';
end;

function Directory(const ACatalogRoot, AId: String): String;
begin
  Need(SafeId(AId), 'Invalid review identity');
  Result := Root(ACatalogRoot) + PathDelim + AId;
end;

function ReviewIds(const ACatalogRoot: String): TStringList;
var
  LFound: TSearchRec;
  LStatus: Integer;
begin
  Result := TStringList.Create;
  try
    LStatus := FindFirst(Root(ACatalogRoot) + PathDelim + '*', faAnyFile, LFound);
    if LStatus = 0 then
    begin
      try
        while LStatus = 0 do
        begin
          if (LFound.Attr and faDirectory <> 0) and SafeId(LFound.Name) then
          begin
            Result.Add(LFound.Name);
            Need(Result.Count <= 256, 'Review session count exceeds256');
          end;
          LStatus := FindNext(LFound);
        end;
      finally
        SysUtils.FindClose(LFound);
      end;
    end;
    Result.Sort;
  except
    Result.Free;
    raise;
  end;
end;

procedure Lock(const ACatalogRoot: String);
begin
  EnterCriticalSection(GReviewLock);
  try
    Need(ForceDirectories(Root(ACatalogRoot)), 'Cannot create review root');
    Need(CreateDir(Root(ACatalogRoot) + PathDelim + '.write-lock'),
      'Review store is busy or has an interrupted lock');
  except
    LeaveCriticalSection(GReviewLock);
    raise;
  end;
end;

procedure Unlock(const ACatalogRoot: String);
begin
  RemoveDir(Root(ACatalogRoot) + PathDelim + '.write-lock');
  LeaveCriticalSection(GReviewLock);
end;

function ReadSession(const ACatalogRoot, AId: String): TJSONObject;
var
  LHash: String;
begin
  Result := ReadStudioJSON(Directory(ACatalogRoot, AId) + PathDelim + 'session.json');
  try
    Need((Result.Strings['format'] = 'pythian.studio.review.session.v1') and
      (Result.Strings['review_id'] = AId), 'Review session identity differs');
    LHash := Result.Strings['session_sha256'];
    Result.Delete('session_sha256');
    Need(StudioTextHash(Result.AsJSON) = LHash, 'Review session digest differs');
    Result.Add('session_sha256', LHash);
  except
    Result.Free;
    raise;
  end;
end;

function ListeningRow(const ACatalogRoot, AItemId: String): TJSONObject;
var
  LQueue: TJSONObject;
  LName: String;
  LIndex: Integer;
begin
  Result := nil;
  LQueue := ReadListeningQueue(ACatalogRoot);
  try
    for LName in CQueueArrays do
    begin
      for LIndex := 0 to LQueue.Arrays[LName].Count - 1 do
      begin
        if LQueue.Arrays[LName].Objects[LIndex].Strings['id'] = AItemId then
        begin
          Exit(TJSONObject(LQueue.Arrays[LName].Objects[LIndex].Clone));
        end;
      end;
    end;
  finally
    LQueue.Free;
  end;
end;

function Revealed(const ACatalogRoot: String; const ASession, ARow: TJSONObject): Boolean;
var
  LMarker: TJSONObject;
  LPath: String;
begin
  Result := not ASession.Booleans['blind'] or
    ((ARow <> nil) and (ARow.Get('current_status', '') = 'submitted'));
  LPath := Directory(ACatalogRoot, ASession.Strings['review_id']) + PathDelim + 'reveal.json';
  if not Result and FileExists(LPath) then
  begin
    LMarker := ReadStudioJSON(LPath);
    try
      Need((LMarker.Strings['session_sha256'] = ASession.Strings['session_sha256']) and
        (LMarker.Strings['review_id'] = ASession.Strings['review_id']) and
        (LMarker.Int64s['first_submitted_revision'] >= 1), 'Review reveal identity differs');
      Result := True;
    finally
      LMarker.Free;
    end;
  end;
end;

procedure RetainReveal(const ACatalogRoot: String; const ASession, ARow: TJSONObject);
var
  LPath: String;
  LMarker: TJSONObject;
begin
  if (ARow = nil) or (ARow.Get('current_status', '') <> 'submitted') then
  begin
    Exit;
  end;
  LPath := Directory(ACatalogRoot, ASession.Strings['review_id']) + PathDelim + 'reveal.json';
  if FileExists(LPath) then
  begin
    Exit;
  end;
  LMarker := TJSONObject.Create;
  try
    LMarker.Add('review_id', ASession.Strings['review_id']);
    LMarker.Add('session_sha256', ASession.Strings['session_sha256']);
    LMarker.Add('first_submitted_revision', ARow.Int64s['revision']);
    WriteStudioJSONNew(LPath, LMarker);
  finally
    LMarker.Free;
  end;
end;

function PinState(const ACatalogRoot, AId: String): TJSONObject;
var
  LFound: TSearchRec;
  LStatus: Integer;
  LRevision: Integer;
  LLatest: Integer;
begin
  LLatest := 0;
  LStatus := FindFirst(Directory(ACatalogRoot, AId) + PathDelim + '*.pin.json', faAnyFile, LFound);
  if LStatus = 0 then
  begin
    try
      while LStatus = 0 do
      begin
        Need((Length(LFound.Name) = 17) and TryStrToInt(Copy(LFound.Name, 1, 8), LRevision) and
          (LRevision >= 1) and (LRevision <= 10000), 'Invalid review pin revision');
        if LRevision > LLatest then
        begin
          LLatest := LRevision;
        end;
        LStatus := FindNext(LFound);
      end;
    finally
      SysUtils.FindClose(LFound);
    end;
  end;
  if LLatest = 0 then
  begin
    Result := TJSONObject.Create;
    Result.Add('revision', 0);
    Result.Add('pinned', False);
  end
  else
  begin
    Result := ReadStudioJSON(Directory(ACatalogRoot, AId) + PathDelim +
      Format('%.8d.pin.json', [LLatest]));
    try
      Need((Result.Strings['review_id'] = AId) and (Result.Integers['revision'] = LLatest),
        'Review pin identity differs');
    except
      Result.Free;
      raise;
    end;
  end;
end;

procedure AddChoice(const AChoices: TJSONArray; const AId: String;
  const AValues: TJSONArray);
var
  LRow: TJSONObject;
begin
  LRow := TJSONObject.Create;
  AChoices.Add(LRow);
  LRow.Add('id', AId);
  LRow.Add('values', AValues.Clone);
end;

function BuildSession(const ACatalogRoot: String; const AWrite: TJSONObject): TJSONObject;
var
  LOutputs: TJSONArray;
  LLabels: TJSONArray;
  LBindings: TJSONArray;
  LAssets: TJSONArray;
  LRanges: TJSONArray;
  LChoices: TJSONArray;
  LScores: TJSONArray;
  LValues: TJSONArray;
  LRequest: TJSONObject;
  LSpec: TJSONObject;
  LRow: TJSONObject;
  LJob: TJSONObject;
  LOutput: TJSONObject;
  LOriginal: TJSONObject;
  LAsset: TJSONObject;
  LRange: TJSONObject;
  LBinding: TJSONObject;
  LSummary: TJSONObject;
  LSelected: TJSONObject;
  LGuid: TGuid;
  LId: String;
  LAlias: String;
  LMode: String;
  LHash: String;
  LScore: String;
  LIndex: Integer;
  LSourceIndex: Integer;
  LOrdinal: Integer;
  LChoiceIndex: Integer;
  LReverse: Boolean;
begin
  Keys(AWrite, '|format|review_id|question|context|mode|blind|outputs|style_choices|');
  Need(Text(AWrite, 'format', 64) = StudioReviewWriteFormat, 'Unsupported review write format');
  LId := Text(AWrite, 'review_id', 64);
  Need(SafeId(LId), 'Invalid review identifier');
  Need(Trim(Text(AWrite, 'question', 1024)) <> '', 'Explain the listening purpose');
  Text(AWrite, 'context', 2048);
  LMode := Text(AWrite, 'mode', 32);
  Need((LMode = 'development') or (LMode = 'frozen_evaluation'), 'Unsupported review mode');
  Need((AWrite.Find('blind') <> nil) and (AWrite.Find('blind').JSONType = jtBoolean),
    'Explicit blind presentation choice required');
  Need((AWrite.Find('outputs') <> nil) and (AWrite.Find('outputs').JSONType = jtArray),
    'Review outputs are required');
  Need((AWrite.Find('style_choices') <> nil) and (AWrite.Find('style_choices').JSONType = jtArray),
    'Caller style choices are required');
  LOutputs := AWrite.Arrays['outputs'];
  LLabels := AWrite.Arrays['style_choices'];
  Need((LOutputs.Count >= 1) and (LOutputs.Count <= 2), 'Review one or two verified passages');
  Need((LLabels.Count >= 1) and (LLabels.Count <= 8), 'Declare one to eight style choices');
  for LIndex := 0 to LLabels.Count - 1 do
  begin
    Need((LLabels[LIndex].JSONType = jtString) and (Trim(LLabels.Strings[LIndex]) <> '') and
      (Length(LLabels.Strings[LIndex]) <= 64), 'Invalid caller style choice');
    for LChoiceIndex := 0 to LIndex - 1 do
    begin
      Need(LLabels.Strings[LChoiceIndex] <> LLabels.Strings[LIndex], 'Duplicate style choice');
    end;
  end;
  CreateGUID(LGuid);
  LHash := StudioTextHash(GUIDToString(LGuid));
  LReverse := AWrite.Booleans['blind'] and (LOutputs.Count = 2) and
    ((StrToInt('$' + Copy(LHash, 1, 2)) and 1) <> 0);
  Result := TJSONObject.Create;
  try
    Result.Add('format', 'pythian.studio.review.session.v1');
    Result.Add('review_id', LId);
    Result.Add('write_sha256', StudioTextHash(AWrite.AsJSON));
    Result.Add('write', AWrite.Clone);
    Result.Add('blind', AWrite.Booleans['blind']);
    Result.Add('mode', LMode);
    Result.Add('question', AWrite.Strings['question']);
    Result.Add('context', AWrite.Strings['context']);
    Result.Add('style_choices', LLabels.Clone);
    Result.Add('assignment_policy', 'server-guid-randomized-v1; reveal only after submitted response');
    LBindings := TJSONArray.Create;
    Result.Add('bindings', LBindings);
    LRequest := TJSONObject.Create;
    Result.Add('listening_request', LRequest);
    LRequest.Add('id', 'sr_' + Copy(StudioTextHash('studio-review-v1|' + LId), 1, 32));
    LRequest.Add('task_id', 'NS-6_studio_03');
    if LOutputs.Count = 1 then
    begin
      LRequest.Add('kind', 'single');
    end
    else
    begin
      LRequest.Add('kind', 'pair');
    end;
    LRequest.Add('question', AWrite.Strings['question']);
    LAssets := TJSONArray.Create;
    LRequest.Add('assets', LAssets);
    LRanges := TJSONArray.Create;
    LRequest.Add('ranges', LRanges);
    LSpec := TJSONObject.Create;
    LRequest.Add('answer_spec', LSpec);
    LChoices := TJSONArray.Create;
    LSpec.Add('choices', LChoices);
    LScores := TJSONArray.Create;
    LSpec.Add('scores', LScores);
    LValues := TJSONArray.Create;
    try
      for LChoiceIndex := 0 to LLabels.Count - 1 do
      begin
        LValues.Add('choice_' + IntToStr(LChoiceIndex));
      end;
      LValues.Add('unknown');
      for LIndex := 0 to LOutputs.Count - 1 do
      begin
        LSourceIndex := LIndex;
        if LReverse then
        begin
          LSourceIndex := 1 - LIndex;
        end;
        Need(LOutputs[LSourceIndex].JSONType = jtObject, 'Invalid review output selection');
        LRow := LOutputs.Objects[LSourceIndex];
        Keys(LRow, '|job_id|ordinal|');
        Need(SafeId(Text(LRow, 'job_id', 64)), 'Invalid output job identity');
        LOrdinal := IntegerValue(LRow, 'ordinal');
        LJob := ReadStudioJob(ACatalogRoot, LRow.Strings['job_id']);
        try
          Need((LJob.Strings['kind'] = 'train_generate') and
            (LJob.Strings['status'] = 'completed'), 'Review requires a completed acoustic audition job');
          Need((LOrdinal >= 0) and (LOrdinal < LJob.Objects['results'].Arrays['outputs'].Count),
            'Output ordinal is outside the completed batch');
          LOutput := LJob.Objects['results'].Arrays['outputs'].Objects[LOrdinal];
          Need(LOutput.Strings['status'] = 'verified', 'Output was not verified by the worker');
          for LChoiceIndex := 0 to LIndex - 1 do
          begin
            Need((LBindings.Objects[LChoiceIndex].Strings['job_id'] <> LRow.Strings['job_id']) or
              (LBindings.Objects[LChoiceIndex].Integers['ordinal'] <> LOrdinal),
              'Duplicate passage selection');
          end;
          LOriginal := ListeningRow(ACatalogRoot, LOutput.Strings['listening_request_id']);
          Need(LOriginal <> nil, 'Verified output lacks its bound listening publication');
          try
            Need(LOriginal.Arrays['assets'].Count = 1, 'Original audition asset count differs');
            Need(LOriginal.Arrays['assets'].Objects[0].Strings['sha256'] = LOutput.Strings['wav_sha256'],
              'Job/listening output identity differs');
            LAlias := 'sample_a';
            if LIndex = 1 then
            begin
              LAlias := 'sample_b';
            end;
            LBinding := TJSONObject.Create;
            LBindings.Add(LBinding);
            LBinding.Add('sample_id', LAlias);
            LBinding.Add('job_id', LRow.Strings['job_id']);
            LBinding.Add('ordinal', LOrdinal);
            LBinding.Add('request', LJob.Objects['request'].Clone);
            LSummary := TJSONObject(LJob.Objects['results'].Clone);
            LSummary.Delete('outputs');
            LSelected := TJSONObject(LOutput.Clone);
            LSelected.Delete('grain_map');
            LSummary.Add('selected_output', LSelected);
            LBinding.Add('result', LSummary);
            LAsset := TJSONObject(LOriginal.Arrays['assets'].Objects[0].Clone);
            LAsset.Strings['id'] := LAlias;
            LAssets.Add(LAsset);
            LRange := TJSONObject.Create;
            LRanges.Add(LRange);
            LRange.Add('asset_id', LAlias);
            LRange.Add('start_frame', 0);
            LRange.Add('end_frame', LAsset.Int64s['frames']);
            AddChoice(LChoices, 'style_' + LAlias, LValues);
            for LScore in CScoreNames do
            begin
              LRange := TJSONObject.Create;
              LScores.Add(LRange);
              LRange.Add('id', LScore + '_' + LAlias);
            end;
          finally
            LOriginal.Free;
          end;
        finally
          LJob.Free;
        end;
      end;
    finally
      LValues.Free;
    end;
    if LOutputs.Count = 2 then
    begin
      LValues := TJSONArray.Create;
      try
        LValues.Add('sample_a');
        LValues.Add('sample_b');
        LValues.Add('neither');
        LValues.Add('unknown');
        AddChoice(LChoices, 'preference', LValues);
      finally
        LValues.Free;
      end;
    end;
    Result.Add('session_sha256', StudioTextHash(Result.AsJSON));
    Need(Length(Result.AsJSON) <= 1048576, 'Review session exceeds byte bound');
  except
    Result.Free;
    raise;
  end;
end;

function CreateStudioReview(const ACatalogRoot: String;
  const AWrite: TJSONObject): TJSONObject;
var
  LId: String;
  LSession: TJSONObject;
  LQueue: TJSONObject;
  LReport: TJSONObject;
  LIds: TStringList;
  LPath: String;
begin
  Need(AWrite <> nil, 'Review write required');
  LId := Text(AWrite, 'review_id', 64);
  Lock(ACatalogRoot);
  try
    LPath := Directory(ACatalogRoot, LId);
    if FileExists(LPath + PathDelim + 'session.json') then
    begin
      LSession := ReadSession(ACatalogRoot, LId);
      if LSession.Strings['write_sha256'] <> StudioTextHash(AWrite.AsJSON) then
      begin
        LSession.Free;
        raise EStudioConflict.Create('Review identity already has different settings');
      end;
    end
    else
    begin
      LIds := ReviewIds(ACatalogRoot);
      try
        Need(LIds.Count < 256, 'Review session limit reached');
      finally
        LIds.Free;
      end;
      LSession := BuildSession(ACatalogRoot, AWrite);
      try
        WriteStudioJSONNew(LPath + PathDelim + 'session.json', LSession);
      except
        LSession.Free;
        raise;
      end;
    end;
    try
      { Persist the auditable assignment first, so generic queue projection can
        hide this request before publication. Retry completes an interrupted append. }
      if not FileExists(LPath + PathDelim + 'publication.json') then
      begin
        LQueue := TJSONObject.Create;
        try
          LQueue.Add('version', 1);
          LQueue.Add('items', TJSONArray.Create);
          LQueue.Arrays['items'].Add(LSession.Objects['listening_request'].Clone);
          WriteStudioJSONNew(LPath + PathDelim + 'publication.json', LQueue);
        finally
          LQueue.Free;
        end;
      end;
      LReport := AppendListeningQueue(ACatalogRoot, LPath + PathDelim + 'publication.json');
      LReport.Free;
    finally
      LSession.Free;
    end;
    Result := ReadStudioReview(ACatalogRoot, LId);
  finally
    Unlock(ACatalogRoot);
  end;
end;

procedure AddAnchors(const AResult: TJSONObject);
var
  LAnchors: TJSONObject;
  LValues: TJSONArray;
  LName: String;
begin
  LAnchors := TJSONObject.Create;
  AResult.Add('score_anchors', LAnchors);
  for LName in CScoreNames do
  begin
    LValues := TJSONArray.Create;
    LAnchors.Add(LName, LValues);
    if LName = 'fit' then
    begin
      LValues.Add('Misses my intent');
      LValues.Add('Some resemblance');
      LValues.Add('Mostly fits');
      LValues.Add('Strong match');
    end
    else if LName = 'continuity' then
    begin
      LValues.Add('Frequent disruptive joins');
      LValues.Add('Several disruptive joins');
      LValues.Add('Mostly smooth');
      LValues.Add('Smooth throughout');
    end
    else if LName = 'repetition' then
    begin
      LValues.Add('Excessively repetitive');
      LValues.Add('Often repeats');
      LValues.Add('Some useful variation');
      LValues.Add('Varied while keeping its direction');
    end
    else
    begin
      LValues.Add('Hard to listen to');
      LValues.Add('Frequent audible defects');
      LValues.Add('Minor audible issues');
      LValues.Add('Sounds clean to me');
    end;
  end;
  AResult.Add('unknown_label', 'Cannot judge yet');
end;

function ReadStudioReview(const ACatalogRoot, AReviewId: String): TJSONObject;
var
  LSession: TJSONObject;
  LRow: TJSONObject;
  LPin: TJSONObject;
  LSamples: TJSONArray;
  LOptions: TJSONArray;
  LSample: TJSONObject;
  LOption: TJSONObject;
  LAsset: TJSONObject;
  LIndex: Integer;
  LName: String;
  LRevealed: Boolean;
begin
  LSession := ReadSession(ACatalogRoot, AReviewId);
  try
    LRow := ListeningRow(ACatalogRoot, LSession.Objects['listening_request'].Strings['id']);
    try
      LRevealed := Revealed(ACatalogRoot, LSession, LRow);
      Result := TJSONObject.Create;
      try
        Result.Add('format', StudioReviewFormat);
        Result.Add('review_id', AReviewId);
        Result.Add('mode', LSession.Strings['mode']);
        Result.Add('question', LSession.Strings['question']);
        Result.Add('context', LSession.Strings['context']);
        Result.Add('blind', LSession.Booleans['blind']);
        Result.Add('revealed', LRevealed);
        Result.Add('reveal_policy', 'after_submitted_response');
        Result.Add('grounded_acceptance', False);
        Result.Add('exposure', 'Original job families/exposure retained; frozen presentation does not create an untouched holdout');
        Result.Add('status', 'pending_publication');
        Result.Add('revision', 0);
        Result.Add('choices', TJSONArray.Create);
        Result.Add('scores', TJSONArray.Create);
        Result.Add('comments', TJSONArray.Create);
        if LRow <> nil then
        begin
          Result.Strings['status'] := LRow.Get('current_status', 'waiting');
          Result.Int64s['revision'] := LRow.Int64s['revision'];
          for LName in CAnswerArrays do
          begin
            if LRow.Find('current_' + LName) <> nil then
            begin
              Result.Delete(LName);
              Result.Add(LName, LRow.Arrays['current_' + LName].Clone);
            end;
          end;
        end;
        LPin := PinState(ACatalogRoot, AReviewId);
        Result.Add('pin', LPin);
        LOptions := TJSONArray.Create;
        Result.Add('style_options', LOptions);
        for LIndex := 0 to LSession.Arrays['style_choices'].Count - 1 do
        begin
          LOption := TJSONObject.Create;
          LOptions.Add(LOption);
          LOption.Add('value', 'choice_' + IntToStr(LIndex));
          LOption.Add('label', LSession.Arrays['style_choices'].Strings[LIndex]);
        end;
        LOption := TJSONObject.Create;
        LOptions.Add(LOption);
        LOption.Add('value', 'unknown');
        LOption.Add('label', 'Cannot judge yet');
        AddAnchors(Result);
        Result.Add('answer_spec', LSession.Objects['listening_request'].Objects['answer_spec'].Clone);
        LSamples := TJSONArray.Create;
        Result.Add('samples', LSamples);
        for LIndex := 0 to LSession.Arrays['bindings'].Count - 1 do
        begin
          LAsset := LSession.Objects['listening_request'].Arrays['assets'].Objects[LIndex];
          LSample := TJSONObject.Create;
          LSamples.Add(LSample);
          LSample.Add('sample_id', LAsset.Strings['id']);
          LSample.Add('label', 'Sample ' + Chr(Ord('A') + LIndex));
          LSample.Add('sample_rate', LAsset.Integers['sample_rate']);
          LSample.Add('channels', LAsset.Integers['channels']);
          LSample.Add('frames', LAsset.Int64s['frames']);
          LSample.Add('audio_url', '/api/studio/review-audio?id=' + AReviewId + '&sample=' + LAsset.Strings['id']);
          if LRevealed then
          begin
            LSample.Add('assignment', LSession.Arrays['bindings'].Objects[LIndex].Clone);
            LSample.Add('reference_url', '/api/listen-references?request=' +
              LSession.Objects['listening_request'].Strings['id'] + '&asset=' + LAsset.Strings['id']);
          end;
        end;
      except
        Result.Free;
        raise;
      end;
    finally
      LRow.Free;
    end;
  finally
    LSession.Free;
  end;
end;

function ListStudioReviews(const ACatalogRoot: String): TJSONObject;
var
  LIds: TStringList;
  LId: String;
  LFull: TJSONObject;
  LSummary: TJSONObject;
begin
  Result := TJSONObject.Create;
  try
    Result.Add('format', 'pythian.studio.reviews.v1');
    Result.Add('reviews', TJSONArray.Create);
    LIds := ReviewIds(ACatalogRoot);
    try
      for LId in LIds do
      begin
        LFull := ReadStudioReview(ACatalogRoot, LId);
        try
          LSummary := TJSONObject.Create;
          Result.Arrays['reviews'].Add(LSummary);
          LSummary.Add('review_id', LId);
          LSummary.Add('question', LFull.Strings['question']);
          LSummary.Add('mode', LFull.Strings['mode']);
          LSummary.Add('status', LFull.Strings['status']);
          LSummary.Add('revision', LFull.Int64s['revision']);
          LSummary.Add('blind', LFull.Booleans['blind']);
          LSummary.Add('revealed', LFull.Booleans['revealed']);
          LSummary.Add('sample_count', LFull.Arrays['samples'].Count);
          LSummary.Add('pin', LFull.Objects['pin'].Clone);
        finally
          LFull.Free;
        end;
      end;
    finally
      LIds.Free;
    end;
    Result.Add('count', Result.Arrays['reviews'].Count);
  except
    Result.Free;
    raise;
  end;
end;

function CommitStudioReview(const ACatalogRoot: String;
  const AWrite: TJSONObject): TJSONObject;
var
  LSession: TJSONObject;
  LRow: TJSONObject;
  LTransaction: TJSONObject;
  LReceipt: TJSONObject;
  LName: String;
  LId: String;
  LCurrent: TJSONObject;
begin
  Keys(AWrite, '|format|review_id|expected_revision|reviewer|status|choices|scores|comments|');
  Need(Text(AWrite, 'format', 64) = StudioReviewResponseFormat, 'Unsupported review response format');
  LId := Text(AWrite, 'review_id', 64);
  Lock(ACatalogRoot);
  try
    LSession := ReadSession(ACatalogRoot, LId);
    try
      LRow := ListeningRow(ACatalogRoot, LSession.Objects['listening_request'].Strings['id']);
      Need(LRow <> nil, 'Listening publication is incomplete; retry preparing this review');
      try
        RetainReveal(ACatalogRoot, LSession, LRow);
        LTransaction := TJSONObject.Create;
        try
          LTransaction.Add('version', 1);
          LTransaction.Add('request_id', LRow.Strings['id']);
          LTransaction.Add('request_sha256', LRow.Strings['request_sha256']);
          LTransaction.Add('expected_revision', IntegerValue(AWrite, 'expected_revision'));
          LTransaction.Add('reviewer', Text(AWrite, 'reviewer', 128));
          LTransaction.Add('status', Text(AWrite, 'status', 16));
          for LName in CAnswerArrays do
          begin
            if AWrite.Find(LName) <> nil then
            begin
              Need(AWrite.Find(LName).JSONType = jtArray, 'Review answers must be arrays');
              LTransaction.Add(LName, AWrite.Arrays[LName].Clone);
            end;
          end;
          try
            LReceipt := CommitListeningReview(ACatalogRoot, LTransaction);
          except
            on E: EAudio do
            begin
              if Pos('revision conflict', E.Message) > 0 then
              begin
                raise EStudioConflict.Create('Review revision differs; reload without losing your answer');
              end;
              raise;
            end;
          end;
          LReceipt.Free;
        finally
          LTransaction.Free;
        end;
      finally
        LRow.Free;
      end;
      LCurrent := ListeningRow(ACatalogRoot, LSession.Objects['listening_request'].Strings['id']);
      try
        RetainReveal(ACatalogRoot, LSession, LCurrent);
      finally
        LCurrent.Free;
      end;
      Result := ReadStudioReview(ACatalogRoot, LId);
    finally
      LSession.Free;
    end;
  finally
    Unlock(ACatalogRoot);
  end;
end;

function PinStudioReview(const ACatalogRoot, AReviewId: String;
  const AExpectedRevision: Int64; const APinned: Boolean): TJSONObject;
var
  LSession: TJSONObject;
  LPin: TJSONObject;
begin
  Lock(ACatalogRoot);
  try
    LSession := ReadSession(ACatalogRoot, AReviewId);
    LSession.Free;
    LPin := PinState(ACatalogRoot, AReviewId);
    try
      if AExpectedRevision <> LPin.Int64s['revision'] then
      begin
        if (AExpectedRevision = LPin.Int64s['revision'] - 1) and
          (APinned = LPin.Booleans['pinned']) then
        begin
          Exit(ReadStudioReview(ACatalogRoot, AReviewId));
        end;
        raise EStudioConflict.Create('Review pin revision differs; reload its current state');
      end;
      Need(LPin.Int64s['revision'] < 10000, 'Review pin revision budget exceeded');
      LPin.Int64s['revision'] := LPin.Int64s['revision'] + 1;
      LPin.Booleans['pinned'] := APinned;
      LPin.Strings['review_id'] := AReviewId;
      WriteStudioJSONNew(Directory(ACatalogRoot, AReviewId) + PathDelim +
        Format('%.8d.pin.json', [LPin.Integers['revision']]), LPin);
    finally
      LPin.Free;
    end;
    Result := ReadStudioReview(ACatalogRoot, AReviewId);
  finally
    Unlock(ACatalogRoot);
  end;
end;

function SampleBinding(const ASession: TJSONObject; const ASampleId: String): TJSONObject;
var
  LIndex: Integer;
begin
  Result := nil;
  for LIndex := 0 to ASession.Arrays['bindings'].Count - 1 do
  begin
    if ASession.Arrays['bindings'].Objects[LIndex].Strings['sample_id'] = ASampleId then
    begin
      Exit(ASession.Arrays['bindings'].Objects[LIndex]);
    end;
  end;
  raise EAudio.Create('Review sample is not declared');
end;

function PrepareStudioNextBatch(const ACatalogRoot, AReviewId,
  ASampleId: String): TJSONObject;
var
  LSession: TJSONObject;
  LRow: TJSONObject;
  LBinding: TJSONObject;
  LWrite: TJSONObject;
begin
  LSession := ReadSession(ACatalogRoot, AReviewId);
  try
    LRow := ListeningRow(ACatalogRoot, LSession.Objects['listening_request'].Strings['id']);
    try
      Need((LRow <> nil) and (LRow.Get('current_status', '') = 'submitted'),
        'Save a complete review before preparing its next batch');
      LBinding := SampleBinding(LSession, ASampleId);
      LWrite := TJSONObject(LBinding.Objects['request'].Clone);
      try
        LWrite.Delete('job_id');
        LWrite.Delete('retry_of');
        LWrite.Delete('parent_job_id');
        LWrite.Add('parent_job_id', LBinding.Strings['job_id']);
        Result := TJSONObject.Create;
        Result.Add('format', 'pythian.studio.next-batch.v1');
        Result.Add('review_id', AReviewId);
        Result.Add('sample_id', ASampleId);
        Result.Add('review_revision', LRow.Int64s['revision']);
        Result.Add('request', LWrite);
        LWrite := nil;
        Result.Add('change_summary', 'Retains this saved corpus revision and supported controls. Choose a new batch ID and deliberately change controls or seeds before checking/enqueueing.');
        Result.Add('enqueue_status', 'not_enqueued');
        Result.Add('generated_audio_training_status', 'not_admitted_as_source');
      finally
        LWrite.Free;
      end;
    finally
      LRow.Free;
    end;
  finally
    LSession.Free;
  end;
end;

function StudioSessionForListeningItem(const ACatalogRoot, AItemId: String): TJSONObject;
var
  LIds: TStringList;
  LId: String;
  LSession: TJSONObject;
begin
  Result := nil;
  if Pos('sr_', AItemId) <> 1 then
  begin
    Exit;
  end;
  LIds := ReviewIds(ACatalogRoot);
  try
    for LId in LIds do
    begin
      LSession := ReadSession(ACatalogRoot, LId);
      try
        if LSession.Objects['listening_request'].Strings['id'] = AItemId then
        begin
          Result := LSession;
          LSession := nil;
          Exit;
        end;
      finally
        LSession.Free;
      end;
    end;
  finally
    LIds.Free;
  end;
end;

function IsStudioReviewListeningItem(const ACatalogRoot, AItemId: String): Boolean;
var
  LSession: TJSONObject;
begin
  LSession := StudioSessionForListeningItem(ACatalogRoot, AItemId);
  try
    Result := LSession <> nil;
  finally
    LSession.Free;
  end;
end;

function IsStudioReviewListeningItemHidden(const ACatalogRoot, AItemId: String): Boolean;
var
  LSession: TJSONObject;
  LRow: TJSONObject;
begin
  Result := False;
  LSession := StudioSessionForListeningItem(ACatalogRoot, AItemId);
  try
    if LSession = nil then
    begin
      Exit;
    end;
    LRow := ListeningRow(ACatalogRoot, AItemId);
    try
      Result := not Revealed(ACatalogRoot, LSession, LRow);
    finally
      LRow.Free;
    end;
  finally
    LSession.Free;
  end;
end;

function ResolveStudioReviewAsset(const ACatalogRoot, AReviewId,
  ASampleId: String): TJSONObject;
var
  LSession: TJSONObject;
begin
  LSession := ReadSession(ACatalogRoot, AReviewId);
  try
    SampleBinding(LSession, ASampleId);
    Result := ResolveListeningAsset(ACatalogRoot,
      LSession.Objects['listening_request'].Strings['id'], ASampleId);
  finally
    LSession.Free;
  end;
end;

initialization
  InitCriticalSection(GReviewLock);

finalization
  DoneCriticalSection(GReviewLock);

end.
