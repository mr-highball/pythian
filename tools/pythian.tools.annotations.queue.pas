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
  pythian.tools.annotations.review;

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
    (AType = 'part_role') or (AType = 'source_role') or
    (AType = 'phrase') or (AType = 'section') or
    (AType = 'style_preference');
end;

procedure ValidateFields(const AObject: TJSONObject;
  const ARoot: Boolean);
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
        (LName = 'label_type'),
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
  AQueuePath: String): TJSONObject;
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
  LConflict: String;
  LCurrent: TJSONObject;
  LStart: Int64;
  LEnd: Int64;
  LRate: Integer;
  LCompleted: Boolean;
  I: Integer;
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
      ValidateFields(LInput, True);
      RequireQueue(QueueInteger(LInput, 'version') = 1,
        'unsupported version');
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
          ValidateFields(LInputItem, False);
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
            RequireQueue(ValidLabelType(LLabelType),
              'unsupported label_type at item ' + IntToStr(I));
          end;
          LSourceTitle := '';
          try
            LSource := ReadCatalogTrack(ACatalogRoot, LHash);
            try
              LRate := LSource.Integers['sample_rate'];
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
          LOutputItem := TJSONObject.Create;
          LOutputItems.Add(LOutputItem);
          LOutputItem.Add('id', LId);
          LOutputItem.Add('source_sha256', LHash);
          LOutputItem.Add('start_frame', LStart);
          LOutputItem.Add('end_frame', LEnd);
          LOutputItem.Add('question', LQuestion);
          if LLabelType <> '' then
            LOutputItem.Add('label_type', LLabelType);
          LCompleted := False;
          LConflict := '';
          LCurrent := nil;
          try
            LCurrent := FindCatalogCurrentLabel(ACatalogRoot, LHash, LId);
          except
            on Exception do
              LConflict := 'Could not verify existing label ID for this source.';
          end;
          if (LConflict = '') and (LCurrent <> nil) then
          try
            if (LCurrent.Int64s['start_frame'] <> LStart) or
              (LCurrent.Int64s['end_frame'] <> LEnd) or
              ((LLabelType <> '') and
              (LCurrent.Strings['type'] <> LLabelType)) then
            begin
              LConflict := 'This request ID already names a different saved label.';
            end
            else
            begin
              LOutputItem.Add('current_type', LCurrent.Strings['type']);
              LOutputItem.Add('current_value', LCurrent.Strings['value']);
              LOutputItem.Add('current_status', LCurrent.Strings['status']);
              LCompleted :=
                (LCurrent.Strings['status'] = 'approved') or
                (LCurrent.Strings['status'] = 'rejected');
            end;
          finally
            LCurrent.Free;
          end;
          if LConflict <> '' then
            LOutputItem.Add('answer_conflict', LConflict);
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
    Result := ReadReviewQueueFile(ACatalogRoot, LStage);
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
