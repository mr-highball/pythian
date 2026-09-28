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
unit pythian.tools.annotations.queue;

{$mode delphi}
{$H+}

interface

uses
  SysUtils,
  fpjson;

type
  EReviewQueue = class(Exception);

{ Prepared prompts plus committed outcomes; the review journal owns labels. }
function ReadReviewQueue(const ACatalogRoot: String): TJSONObject;
function PublishReviewQueue(const ACatalogRoot,
  AInputPath: String): TJSONObject;

implementation

uses
  Classes,
  jsonparser,
  {$IFDEF WINDOWS}
  Windows,
  {$ENDIF}
  pythian.tools.annotations.catalog,
  pythian.tools.annotations.review,
  pythian.tools.annotations.proposal,
  pythian.tools.annotations.contract;

const
  CMaximumQueueBytes = 1048576;
  CMaximumQueueItems = 256;
  CMaximumIdBytes = 128;
  CMaximumQuestionBytes = 1024;
  CMaximumTitleBytes = 256;

procedure RequireQueue(const ACondition: Boolean; const AMessage: String);
begin
  if not ACondition then
  begin
    raise EReviewQueue.Create('Invalid review queue: ' + AMessage);
  end;
end;

function QueueText(const AObject: TJSONObject; const AName: String;
  const AMaximum: Integer): String;
var
  LValue: TJSONData;
begin
  LValue := AObject.Find(AName);
  RequireQueue((LValue <> nil) and (LValue.JSONType = jtString),
    'missing or invalid ' + AName);
  Result := LValue.AsString;
  RequireQueue((Trim(Result) <> '') and (Length(Result) <= AMaximum),
    'invalid length for ' + AName);
end;

function QueueInteger(const AObject: TJSONObject; const AName: String): Int64;
var
  LValue: TJSONData;
begin
  LValue := AObject.Find(AName);
  RequireQueue((LValue <> nil) and (LValue.JSONType = jtNumber) and
    TryStrToInt64(LValue.AsJSON, Result), 'missing or invalid ' + AName);
end;

function ValidId(const AId: String): Boolean;
var
  I: Integer;
begin
  Result := (AId <> '') and (Length(AId) <= CMaximumIdBytes);
  for I := 1 to Length(AId) do
  begin
    if not (AId[I] in ['a'..'z', 'A'..'Z', '0'..'9', '_', '-', '.']) then
    begin
      Exit(False);
    end;
  end;
end;

function ValidHash(const AHash: String): Boolean;
var
  I: Integer;
begin
  Result := Length(AHash) = 64;
  for I := 1 to Length(AHash) do
  begin
    if not (AHash[I] in ['0'..'9', 'a'..'f']) then
    begin
      Exit(False);
    end;
  end;
end;

function ValidLabelType(const AType: String): Boolean;
begin
  Result := (AType = 'note') or (AType = 'beat') or
    (AType = 'downbeat') or (AType = 'presence') or
    (AType = 'activity') or (AType = 'key') or
    (AType = 'tempo') or (AType = 'meter') or
    (AType = 'harmony') or
    (AType = 'part_role') or (AType = 'source_role') or
    (AType = 'phrase') or (AType = 'section') or
    (AType = 'style_preference');
end;

procedure ValidateFields(const AObject: TJSONObject;
  const ARoot: Boolean; const AVersion: Integer);
var
  I: Integer;
  J: Integer;
  LName: String;
begin
  for I := 0 to AObject.Count - 1 do
  begin
    LName := AObject.Names[I];
    for J := 0 to I - 1 do
    begin
      RequireQueue(AObject.Names[J] <> LName, 'duplicate field');
    end;
    if ARoot then
    begin
      RequireQueue((LName = 'version') or (LName = 'items'),
        'unsupported root field');
    end
    else
    begin
      RequireQueue((LName = 'id') or (LName = 'source_sha256') or
        (LName = 'start_frame') or (LName = 'end_frame') or
        (LName = 'question') or (LName = 'title') or
        (LName = 'label_type') or (LName = 'answer_geometry') or
        ((AVersion = 2) and (LName = 'answer_spec')),
        'unsupported item field');
    end;
  end;
end;

function ReadQueueText(const APath: String): String;
var
  LStream: TFileStream;
begin
  LStream := TFileStream.Create(APath, fmOpenRead or fmShareDenyWrite);
  try
    RequireQueue((LStream.Size > 0) and
      (LStream.Size <= CMaximumQueueBytes), 'file size exceeds bound');
    SetLength(Result, Integer(LStream.Size));
    LStream.ReadBuffer(Result[1], Length(Result));
  finally
    LStream.Free;
  end;
end;

function ReadReviewQueueFile(const ACatalogRoot,
  AQueuePath: String; const AForPublish: Boolean = False): TJSONObject;
var
  LPath: String;
  LData: TJSONData;
  LSource: TJSONObject;
  LInput: TJSONObject;
  LInputItems: TJSONArray;
  LInputItem: TJSONObject;
  LOutputItems: TJSONArray;
  LCompletedItems: TJSONArray;
  LOutputItem: TJSONObject;
  LIds: TStringList;
  LId: String;
  LHash: String;
  LQuestion: String;
  LTitle: String;
  LSourceTitle: String;
  LLabelType: String;
  LAnswerGeometry: String;
  LConflict: String;
  LCurrent: TJSONObject;
  LStructured: TJSONObject;
  LSpec: TJSONObject;
  LLinks: TJSONArray;
  LLink: TJSONObject;
  LTarget: TJSONObject;
  LRequestHash: String;
  LStart: Int64;
  LEnd: Int64;
  LRate: Integer;
  LVersion: Integer;
  LCompleted: Boolean;
  LBlindLocked: Boolean;
  I: Integer;
  J: Integer;
begin
  Result := TJSONObject.Create;
  try
    Result.Add('version', 1);
    LOutputItems := TJSONArray.Create;
    Result.Add('items', LOutputItems);
    LCompletedItems := TJSONArray.Create;
    Result.Add('completed', LCompletedItems);
    LPath := ExpandFileName(AQueuePath);
    if not FileExists(LPath) then
    begin
      Exit;
    end;
    try
      LData := GetJSON(ReadQueueText(LPath));
    except
      on EReviewQueue do
      begin
        raise;
      end;
      on Exception do
      begin
        raise EReviewQueue.Create('Invalid review queue: unreadable JSON');
      end;
    end;
    try
      RequireQueue(LData.JSONType = jtObject, 'root must be an object');
      LInput := TJSONObject(LData);
      LVersion := QueueInteger(LInput, 'version');
      ValidateFields(LInput, True, LVersion);
      RequireQueue((LVersion = 1) or (LVersion = 2),
        'unsupported version');
      Result.Integers['version'] := LVersion;
      RequireQueue((LInput.Find('items') <> nil) and
        (LInput.Find('items').JSONType = jtArray),
        'items must be an array');
      LInputItems := LInput.Arrays['items'];
      RequireQueue(LInputItems.Count <= CMaximumQueueItems,
        'item count exceeds bound');
      LIds := TStringList.Create;
      try
        LIds.CaseSensitive := True;
        for I := 0 to LInputItems.Count - 1 do
        begin
          RequireQueue(LInputItems[I].JSONType = jtObject,
            'item ' + IntToStr(I) + ' must be an object');
          LInputItem := LInputItems.Objects[I];
          ValidateFields(LInputItem, False, LVersion);
          LId := QueueText(LInputItem, 'id', CMaximumIdBytes);
          RequireQueue(ValidId(LId), 'invalid id at item ' + IntToStr(I));
          RequireQueue(LIds.IndexOf(LId) < 0, 'duplicate id ' + LId);
          LIds.Add(LId);
          LHash := QueueText(LInputItem, 'source_sha256', 64);
          RequireQueue(ValidHash(LHash),
            'invalid source_sha256 at item ' + IntToStr(I));
          LStart := QueueInteger(LInputItem, 'start_frame');
          LEnd := QueueInteger(LInputItem, 'end_frame');
          LQuestion := QueueText(LInputItem, 'question',
            CMaximumQuestionBytes);
          LLabelType := '';
          if LInputItem.Find('label_type') <> nil then
          begin
            LLabelType := QueueText(LInputItem, 'label_type', 128);
            RequireQueue(ValidLabelType(LLabelType) or
              ((LVersion = 2) and
               (LInputItem.Find('answer_spec') <> nil) and
               ((LLabelType = 'ext.groove_trait') or
                (LLabelType = 'ext.motif_relation') or
                (LLabelType = 'ext.pulse_evidence'))),
              'unsupported label_type at item ' + IntToStr(I));
          end;
          LAnswerGeometry := 'exact';
          if LInputItem.Find('answer_geometry') <> nil then
          begin
            LAnswerGeometry := QueueText(LInputItem, 'answer_geometry', 16);
            RequireQueue((LAnswerGeometry = 'exact') or
              (LAnswerGeometry = 'point') or
              (LAnswerGeometry = 'contained'),
              'unsupported answer_geometry at item ' + IntToStr(I));
          end;
          if LAnswerGeometry = 'point' then
          begin
            RequireQueue((LLabelType = 'beat') or
              (LLabelType = 'downbeat') or
              ((LVersion = 2) and
               (LInputItem.Find('answer_spec') <> nil) and
               ((LLabelType = 'ext.pulse_evidence') or
                (LLabelType = 'ext.motif_relation'))),
              'point answers require beat or downbeat at item ' + IntToStr(I));
          end;
          if LAnswerGeometry = 'contained' then
          begin
            RequireQueue((LLabelType <> '') and
              (LLabelType <> 'presence') and
              (LLabelType <> 'activity') and
              (LLabelType <> 'beat') and
              (LLabelType <> 'downbeat'),
              'contained answers require a span label type at item ' +
              IntToStr(I));
          end;
          LStructured := nil;
          LRequestHash := '';
          if (LVersion = 2) and
            (LInputItem.Find('answer_spec') <> nil) then
          begin
            try
              LStructured := NormalizeStructuredRequest(LInputItem);
              LRequestHash := StructuredRequestHash(LStructured);
            except
              on LError: EAnswerContract do
                raise EReviewQueue.Create('Invalid review queue: item ' +
                  IntToStr(I) + ': ' + LError.Message);
            end;
          end;
          try
          LSourceTitle := '';
          try
            LSource := ReadCatalogTrack(ACatalogRoot, LHash);
            try
              LRate := LSource.Integers['sample_rate'];
              LBlindLocked := not CatalogProposalsUnlocked(
                ACatalogRoot, LSource);
              RequireQueue((LStart >= 0) and (LEnd > LStart) and
                (LEnd <= LSource.Int64s['frame_count']),
                'frames outside catalog source at item ' + IntToStr(I));
              RequireQueue((LRate > 0) and
                (LEnd - LStart <= Int64(LRate) * 30),
                'interval exceeds 30 seconds at item ' + IntToStr(I));
              if (LSource.Find('title') <> nil) and
                (LSource.Find('title').JSONType = jtString) then
              begin
                LSourceTitle := LSource.Strings['title'];
              end;
            finally
              LSource.Free;
            end;
          except
            on EReviewQueue do
            begin
              raise;
            end;
            on Exception do
            begin
              raise EReviewQueue.Create('Invalid review queue: source_sha256 ' +
                'is not a valid catalog track at item ' + IntToStr(I));
            end;
          end;
          if LBlindLocked and (LStructured <> nil) then
          begin
            LSpec := LStructured.Objects['answer_spec'];
            RequireQueue(LSpec.Strings['proposal_id'] = '',
              'blind evaluation request cannot expose a proposal at item ' +
              IntToStr(I));
            LLinks := LSpec.Arrays['links'];
            for J := 0 to LLinks.Count - 1 do
              RequireQueue(LLinks.Objects[J].Strings['kind'] <> 'proposal',
                'blind evaluation request cannot expose a proposal link at item ' +
                IntToStr(I));
          end;
          LOutputItem := TJSONObject.Create;
          LOutputItems.Add(LOutputItem);
          LOutputItem.Add('id', LId);
          LOutputItem.Add('source_sha256', LHash);
          LOutputItem.Add('start_frame', LStart);
          LOutputItem.Add('end_frame', LEnd);
          LOutputItem.Add('question', LQuestion);
          if LStructured <> nil then
          begin
            LSpec := LStructured.Objects['answer_spec'];
            LOutputItem.Add('answer_spec', LSpec.Clone);
            LOutputItem.Add('request_sha256', LRequestHash);
          end;
          if LLabelType <> '' then
            LOutputItem.Add('label_type', LLabelType);
          if LInputItem.Find('answer_geometry') <> nil then
            LOutputItem.Add('answer_geometry', LAnswerGeometry);
          LCompleted := False;
          LConflict := '';
          if LStructured <> nil then
          begin
            LSpec := LStructured.Objects['answer_spec'];
            LLinks := LSpec.Arrays['links'];
            for J := 0 to LLinks.Count - 1 do
            begin
              LLink := LLinks.Objects[J];
              if LLink.Strings['kind'] = 'proposal' then
              begin
                if not CatalogProposalExists(ACatalogRoot, LHash,
                  LLink.Strings['target_id']) then
                  LConflict := 'A declared proposal link is unavailable.';
              end
              else
              begin
                LTarget := FindCatalogCurrentLabel(ACatalogRoot, LHash,
                  LLink.Strings['target_id']);
                try
                  if (LTarget = nil) or
                    (LTarget.Strings['status'] <> 'approved') or
                    (LTarget.Strings['type'] <>
                      LLink.Strings['target_type']) or
                    (LTarget.Integers['revision'] <>
                      LLink.Integers['target_revision']) or
                    (LTarget.Strings['value'] = 'unknown') or
                    (LTarget.Strings['value'] = 'ambiguous') then
                    LConflict := 'A declared reviewed-label link is unavailable.';
                finally
                  LTarget.Free;
                end;
              end;
            end;
            if (LSpec.Strings['proposal_id'] <> '') and
              not CatalogProposalExists(ACatalogRoot, LHash,
                LSpec.Strings['proposal_id']) then
              LConflict := 'The declared proposal binding is unavailable.';
          end;
          LCurrent := nil;
          try
            LCurrent := FindCatalogCurrentLabel(ACatalogRoot, LHash, LId);
          except
            on Exception do
              LConflict := 'Could not verify existing label ID for this source.';
          end;
          if (LConflict = '') and (LCurrent <> nil) then
          try
            if ((LAnswerGeometry = 'exact') and
              ((LCurrent.Int64s['start_frame'] <> LStart) or
               (LCurrent.Int64s['end_frame'] <> LEnd))) or
              ((LAnswerGeometry = 'point') and
              ((LCurrent.Int64s['start_frame'] < LStart) or
               (LCurrent.Int64s['end_frame'] > LEnd) or
               (LCurrent.Int64s['end_frame'] <>
                 LCurrent.Int64s['start_frame'] + 1))) or
              ((LAnswerGeometry = 'contained') and
              ((LCurrent.Int64s['start_frame'] < LStart) or
               (LCurrent.Int64s['end_frame'] > LEnd))) or
              ((LLabelType <> '') and
              (LCurrent.Strings['type'] <> LLabelType)) or
              ((LStructured <> nil) and
              ((LCurrent.Find('request_sha256') = nil) or
               (LCurrent.Strings['request_sha256'] <> LRequestHash))) then
            begin
              LConflict := 'This request ID already names a different saved label.';
            end
            else
            begin
              LOutputItem.Add('current_type', LCurrent.Strings['type']);
              LOutputItem.Add('current_value', LCurrent.Strings['value']);
              LOutputItem.Add('current_status', LCurrent.Strings['status']);
              LOutputItem.Add('current_start_frame',
                LCurrent.Int64s['start_frame']);
              LOutputItem.Add('current_end_frame',
                LCurrent.Int64s['end_frame']);
              LCompleted :=
                (LCurrent.Strings['status'] = 'approved') or
                (LCurrent.Strings['status'] = 'rejected');
            end;
          finally
            LCurrent.Free;
            LCurrent := nil;
          end;
          LCurrent.Free;
          if LConflict <> '' then
          begin
            if AForPublish and (LStructured <> nil) then
              RequireQueue(False, 'item ' + IntToStr(I) + ': ' + LConflict);
            LOutputItem.Add('answer_conflict', LConflict);
          end;
          if LSourceTitle <> '' then
          begin
            LOutputItem.Add('source_title', LSourceTitle);
          end;
          if LInputItem.Find('title') <> nil then
          begin
            LTitle := QueueText(LInputItem, 'title', CMaximumTitleBytes);
            LOutputItem.Add('title', LTitle);
          end;
          if LCompleted then
          begin
            LCompletedItems.Add(
              LOutputItems.Extract(LOutputItems.Count - 1));
          end;
          finally
            LStructured.Free;
          end;
        end;
      finally
        LIds.Free;
      end;
    finally
      LData.Free;
    end;
  except
    Result.Free;
    raise;
  end;
end;

function ReviewQueuePath(const ACatalogRoot: String): String;
begin
  Result := IncludeTrailingPathDelimiter(ExpandFileName(ACatalogRoot)) +
    'review-queue.json';
end;

function ReadReviewQueue(const ACatalogRoot: String): TJSONObject;
begin
  Result := ReadReviewQueueFile(ACatalogRoot,
    ReviewQueuePath(ACatalogRoot));
end;

function PublishReviewQueue(const ACatalogRoot,
  AInputPath: String): TJSONObject;
var
  LTarget: String;
  LStage: String;
  LText: String;
  LGuid: TGUID;
  LOutput: TFileStream;
begin
  LTarget := ReviewQueuePath(ACatalogRoot);
  RequireQueue(DirectoryExists(ExtractFileDir(LTarget)),
    'catalog root does not exist');
  LText := ReadQueueText(ExpandFileName(AInputPath));
  RequireQueue(CreateGUID(LGuid) = 0,
    'could not create stage identity');
  LStage := LTarget + '.' + GUIDToString(LGuid) + '.partial';
  try
    LOutput := TFileStream.Create(LStage, fmCreate or fmShareExclusive);
    try
      LOutput.WriteBuffer(LText[1], Length(LText));
    finally
      LOutput.Free;
    end;
    Result := ReadReviewQueueFile(ACatalogRoot, LStage, True);
    try
      {$IFDEF WINDOWS}
      RequireQueue(MoveFileEx(PChar(LStage), PChar(LTarget),
        MOVEFILE_REPLACE_EXISTING),
        'could not publish request manifest');
      {$ELSE}
      RequireQueue(RenameFile(LStage, LTarget),
        'could not publish request manifest');
      {$ENDIF}
    except
      Result.Free;
      raise;
    end;
  finally
    if FileExists(LStage) then
    begin
      SysUtils.DeleteFile(LStage);
    end;
  end;
end;

end.
