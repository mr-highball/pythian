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
unit pythian.tools.annotations.review;

{$mode delphi}
{$H+}

interface

uses
  fpjson;

{ Each revision is a new immutable file. A transaction must explicitly name
  the source and expected revision. These are human review events, never
  automatically generated proposals or training examples. }
function CommitCatalogReview(const ACatalogRoot: String;
  const ATransaction: TJSONObject): TJSONObject;
function ReadCatalogReviewHistory(const ACatalogRoot, AHash: String;
  const AFirstRevision, AMaximumCount: Integer): TJSONObject;
function ReadCatalogCurrentLabels(const ACatalogRoot, AHash: String;
  const AStartFrame, AEndFrame: Int64; const AMaximumCount: Integer): TJSONObject;
function CatalogProposalsUnlocked(const ACatalogRoot: String;
  const ATrack: TJSONObject): Boolean;

implementation

uses
  Classes,
  SysUtils,
  jsonparser,
  pythian.audio,
  pythian.hash,
  pythian.tools.annotations.catalog,
  pythian.tools.annotations.proposal;

const
  CMaximumTransactionBytes = 16384;
  CMaximumEventBytes = 32768;
  CMaximumRevision = 100000;
  CMaximumHistoryPage = 256;

procedure Need(const ACondition: Boolean; const AMessage: String);
begin
  if not ACondition then
  begin
    raise EAudio.Create(AMessage);
  end;
end;

function RequiredText(const AObject: TJSONObject; const AName: String;
  const AMaximum: Integer): String;
var
  LData: TJSONData;
begin
  LData := AObject.Find(AName);
  Need((LData <> nil) and (LData.JSONType = jtString),
    'Missing or invalid ' + AName);
  Result := LData.AsString;
  Need((Length(Result) > 0) and (Length(Result) <= AMaximum),
    'Invalid length for ' + AName);
end;

function OptionalText(const AObject: TJSONObject; const AName: String;
  const AMaximum: Integer): String;
var
  LData: TJSONData;
begin
  LData := AObject.Find(AName);
  if LData = nil then
  begin
    Exit('');
  end;
  Need(LData.JSONType = jtString, 'Invalid ' + AName);
  Result := LData.AsString;
  Need(Length(Result) <= AMaximum, 'Invalid length for ' + AName);
end;

function RequiredInt64(const AObject: TJSONObject; const AName: String): Int64;
var
  LData: TJSONData;
begin
  LData := AObject.Find(AName);
  Need((LData <> nil) and (LData.JSONType = jtNumber) and
    TryStrToInt64(LData.AsJSON, Result),
    'Missing or invalid integer ' + AName);
end;

function SafeIdentifier(const AValue: String): Boolean;
var
  LIndex: Integer;
begin
  Result := (Length(AValue) > 0) and (Length(AValue) <= 128);
  for LIndex := 1 to Length(AValue) do
  begin
    if not (AValue[LIndex] in ['a'..'z', 'A'..'Z', '0'..'9', '-', '_', '.']) then
    begin
      Exit(False);
    end;
  end;
end;

function ValidHash(const AValue: String): Boolean;
var
  LIndex: Integer;
begin
  Result := Length(AValue) = 64;
  for LIndex := 1 to Length(AValue) do
  begin
    if not (AValue[LIndex] in ['0'..'9', 'a'..'f']) then
    begin
      Exit(False);
    end;
  end;
end;

function ReviewDirectory(const ACatalogRoot, AHash: String): String;
begin
  Need(ValidHash(AHash), 'Invalid source SHA256');
  Result := IncludeTrailingPathDelimiter(ExpandFileName(ACatalogRoot)) +
    'reviews' + PathDelim + AHash;
end;

function RevisionName(const ARevision: Integer): String;
begin
  Result := Format('%.8d.json', [ARevision]);
end;

function LatestRevision(const ADirectory: String): Integer;
var
  LFound: TSearchRec;
  LStatus: Integer;
  LRevision: Integer;
  LCount: Integer;
begin
  Result := 0;
  LCount := 0;
  if not DirectoryExists(ADirectory) then
  begin
    Exit;
  end;
  LStatus := FindFirst(IncludeTrailingPathDelimiter(ADirectory) + '*.json',
    faAnyFile, LFound);
  if LStatus <> 0 then
  begin
    Exit;
  end;
  try
    while LStatus = 0 do
    begin
      if LFound.Attr and faDirectory = 0 then
      begin
        Need((Length(LFound.Name) = 13) and
          (Copy(LFound.Name, 9, 5) = '.json') and
          TryStrToInt(Copy(LFound.Name, 1, 8), LRevision) and
          (LRevision > 0) and (LRevision <= CMaximumRevision),
          'Invalid review revision filename');
        Inc(LCount);
        if LRevision > Result then
        begin
          Result := LRevision;
        end;
      end;
      LStatus := FindNext(LFound);
    end;
  finally
    FindClose(LFound);
  end;
  Need(LCount = Result, 'Review revision sequence has a gap');
end;

function ReadEvent(const ADirectory: String; const ARevision: Integer): TJSONObject;
var
  LStream: TFileStream;
  LText: String;
  LData: TJSONData;
begin
  LStream := TFileStream.Create(IncludeTrailingPathDelimiter(ADirectory) +
    RevisionName(ARevision), fmOpenRead or fmShareDenyWrite);
  try
    Need((LStream.Size > 0) and (LStream.Size <= CMaximumEventBytes),
      'Review event exceeds size bound');
    SetLength(LText, Integer(LStream.Size));
    LStream.ReadBuffer(LText[1], Length(LText));
  finally
    LStream.Free;
  end;
  LData := GetJSON(LText);
  if LData.JSONType <> jtObject then
  begin
    LData.Free;
    raise EAudio.Create('Review event must be an object');
  end;
  Result := TJSONObject(LData);
  try
    Need((Result.Integers['version'] = 1) and
      (Result.Integers['revision'] = ARevision),
      'Review event revision differs from filename');
  except
    Result.Free;
    raise;
  end;
end;

function CatalogProposalsUnlocked(const ACatalogRoot: String;
  const ATrack: TJSONObject): Boolean;
var
  LHash: String;
  LDirectory: String;
  LFirst: TJSONObject;
  LChange: TJSONObject;
begin
  if ATrack.Strings['partition'] <> 'evaluation' then
  begin
    Exit(True);
  end;
  LHash := ATrack.Strings['source_sha256'];
  LDirectory := ReviewDirectory(ACatalogRoot, LHash);
  if LatestRevision(LDirectory) = 0 then
  begin
    Exit(False);
  end;
  LFirst := ReadEvent(LDirectory, 1);
  try
    Need((LFirst.Find('change') <> nil) and
      (LFirst.Find('change').JSONType = jtObject),
      'Evaluation first review has no change');
    LChange := LFirst.Objects['change'];
    Result := (LFirst.Strings['source_sha256'] = LHash) and
      (LFirst.Strings['source_group'] =
        ATrack.Strings['source_group']) and
      (LFirst.Strings['partition'] = 'evaluation') and
      (LFirst.Strings['reviewer'] <> '') and
      (LChange.Strings['proposal_id'] = '') and
      ((LChange.Strings['status'] = 'approved') or
      (LChange.Strings['status'] = 'uncertain'));
  finally
    LFirst.Free;
  end;
end;

function NormalizeChange(const AInput, ATrack: TJSONObject): TJSONObject;
var
  LId: String;
  LType: String;
  LValue: String;
  LStatus: String;
  LProposalId: String;
  LPart: String;
  LExtensionVersion: Int64;
  LStart: Int64;
  LEnd: Int64;
  LPitch: Int64;
begin
  LId := RequiredText(AInput, 'label_id', 128);
  Need(SafeIdentifier(LId), 'Invalid label identity');
  LType := RequiredText(AInput, 'type', 128);
  Need((LType = 'beat') or (LType = 'downbeat') or (LType = 'note') or
    (LType = 'presence') or (LType = 'part_role') or
    (LType = 'source_role') or (LType = 'phrase') or
    (LType = 'section') or (LType = 'style_preference') or
    ((Copy(LType, 1, 4) = 'ext.') and (Length(LType) > 4) and
      SafeIdentifier(LType)),
    'Unsupported label type');
  LValue := RequiredText(AInput, 'value', 256);
  LStatus := RequiredText(AInput, 'status', 16);
  Need((LStatus = 'approved') or (LStatus = 'rejected') or
    (LStatus = 'uncertain') or (LStatus = 'withdrawn'),
    'Unsupported review status');
  if LType = 'presence' then
  begin
    Need((LValue = 'audible') or (LValue = 'rest') or
      (LValue = 'unknown'), 'Invalid presence value');
  end;
  LStart := RequiredInt64(AInput, 'start_frame');
  LEnd := RequiredInt64(AInput, 'end_frame');
  Need((LStart >= 0) and (LEnd > LStart) and
    (LEnd <= ATrack.Int64s['frame_count']),
    'Label lies outside source frames');
  LPart := OptionalText(AInput, 'part', 128);
  LProposalId := OptionalText(AInput, 'proposal_id', 128);
  Need((LProposalId = '') or SafeIdentifier(LProposalId),
    'Invalid proposal identity');
  if LStatus = 'rejected' then
  begin
    Need(LProposalId <> '', 'Rejection requires a proposal identity');
  end;
  Result := TJSONObject.Create;
  try
    Result.Add('label_id', LId);
    Result.Add('type', LType);
    Result.Add('value', LValue);
    Result.Add('status', LStatus);
    Result.Add('start_frame', LStart);
    Result.Add('end_frame', LEnd);
    Result.Add('part', LPart);
    Result.Add('proposal_id', LProposalId);
    if LType = 'note' then
    begin
      LPitch := RequiredInt64(AInput, 'pitch_midi');
      Need((LPitch >= 0) and (LPitch <= 127), 'Invalid MIDI pitch');
      Result.Add('pitch_midi', LPitch);
    end;
    if Copy(LType, 1, 4) = 'ext.' then
    begin
      LExtensionVersion := RequiredInt64(AInput, 'extension_version');
      Need((LExtensionVersion > 0) and (LExtensionVersion <= 65535),
        'Invalid label extension version');
      Result.Add('extension_version', LExtensionVersion);
    end;
  except
    Result.Free;
    raise;
  end;
end;

procedure VerifySourceAsset(const ACatalogRoot, AHash: String;
  const ATrack: TJSONObject);
var
  LPath: String;
  LStream: TFileStream;
begin
  LPath := IncludeTrailingPathDelimiter(ExpandFileName(ACatalogRoot)) +
    'sources' + PathDelim + AHash + '.wav';
  LStream := TFileStream.Create(LPath, fmOpenRead or fmShareDenyWrite);
  try
    Need(LStream.Size = ATrack.Int64s['source_bytes'],
      'Catalog source byte count changed');
    Need(Sha256Stream(LStream, LStream.Size) = AHash,
      'Catalog source SHA256 changed');
  finally
    LStream.Free;
  end;
end;

procedure WriteNewEvent(const ADirectory: String; const ARevision: Integer;
  const AEvent: TJSONObject);
var
  LGuid: TGUID;
  LStage: String;
  LFinal: String;
  LText: String;
  LStream: TFileStream;
begin
  Need(CreateGUID(LGuid) = 0, 'Could not create review stage identity');
  LText := AEvent.AsJSON + LineEnding;
  Need(Length(LText) <= CMaximumEventBytes,
    'Review event exceeds size bound');
  LStage := IncludeTrailingPathDelimiter(ADirectory) +
    GUIDToString(LGuid) + '.partial';
  LFinal := IncludeTrailingPathDelimiter(ADirectory) + RevisionName(ARevision);
  try
    LStream := TFileStream.Create(LStage, fmCreate or fmShareExclusive);
    try
      LStream.WriteBuffer(LText[1], Length(LText));
    finally
      LStream.Free;
    end;
    Need(not FileExists(LFinal), 'Review revision already exists');
    Need(RenameFile(LStage, LFinal), 'Could not publish review event');
  finally
    if FileExists(LStage) then
    begin
      DeleteFile(LStage);
    end;
  end;
end;

function CommitCatalogReview(const ACatalogRoot: String;
  const ATransaction: TJSONObject): TJSONObject;
var
  LHash: String;
  LTrack: TJSONObject;
  LChange: TJSONObject;
  LDirectory: String;
  LReviews: String;
  LLock: TFileStream;
  LExpected: Int64;
  LRevision: Integer;
  LReviewer: String;
begin
  Need(ATransaction <> nil, 'Review transaction is required');
  Need(Length(ATransaction.AsJSON) <= CMaximumTransactionBytes,
    'Review transaction exceeds size bound');
  Need(RequiredInt64(ATransaction, 'version') = 1,
    'Unsupported review transaction version');
  LHash := RequiredText(ATransaction, 'source_sha256', 64);
  Need(ValidHash(LHash), 'Invalid review source SHA256');
  LExpected := RequiredInt64(ATransaction, 'expected_revision');
  Need((LExpected >= 0) and (LExpected < CMaximumRevision),
    'Review expected revision exceeds bound');
  LReviewer := RequiredText(ATransaction, 'reviewer', 128);
  Need((ATransaction.Find('change') <> nil) and
    (ATransaction.Find('change').JSONType = jtObject),
    'Review requires one change object');
  LTrack := ReadCatalogTrack(ACatalogRoot, LHash);
  try
    LChange := NormalizeChange(ATransaction.Objects['change'], LTrack);
    try
      LReviews := IncludeTrailingPathDelimiter(ExpandFileName(ACatalogRoot)) +
        'reviews';
      LDirectory := ReviewDirectory(ACatalogRoot, LHash);
      Need(ForceDirectories(LDirectory), 'Could not create review directory');
      LLock := TFileStream.Create(LReviews + PathDelim + LHash + '.lock',
        fmCreate or fmShareExclusive);
      try
        LRevision := LatestRevision(LDirectory);
        Need(LExpected = LRevision, 'Review revision conflict');
        Need((LTrack.Strings['partition'] <> 'evaluation') or
          (LRevision > 0) or
          ((LChange.Strings['proposal_id'] = '') and
          ((LChange.Strings['status'] = 'approved') or
          (LChange.Strings['status'] = 'uncertain'))),
          'Evaluation review must begin with an independent label');
        if LChange.Strings['proposal_id'] <> '' then
        begin
          Need(CatalogProposalExists(ACatalogRoot, LHash,
            LChange.Strings['proposal_id']),
            'Review refers to an unknown proposal');
        end;
        VerifySourceAsset(ACatalogRoot, LHash, LTrack);
        Result := TJSONObject.Create;
        try
          Result.Add('version', 1);
          Result.Add('revision', LRevision + 1);
          Result.Add('source_sha256', LHash);
          Result.Add('sample_rate', LTrack.Integers['sample_rate']);
          Result.Add('source_group', LTrack.Strings['source_group']);
          Result.Add('partition', LTrack.Strings['partition']);
          Result.Add('provenance', LTrack.Strings['provenance']);
          Result.Add('license', LTrack.Strings['license']);
          Result.Add('reviewer', LReviewer);
          Result.Add('change', LChange);
          LChange := nil;
          WriteNewEvent(LDirectory, LRevision + 1, Result);
        except
          Result.Free;
          raise;
        end;
      finally
        LLock.Free;
      end;
    finally
      LChange.Free;
    end;
  finally
    LTrack.Free;
  end;
end;

function ReadCatalogReviewHistory(const ACatalogRoot, AHash: String;
  const AFirstRevision, AMaximumCount: Integer): TJSONObject;
var
  LTrack: TJSONObject;
  LDirectory: String;
  LRevision: Integer;
  LIndex: Integer;
  LRows: TJSONArray;
  LEvent: TJSONObject;
begin
  Need((AFirstRevision > 0) and (AMaximumCount > 0) and
    (AMaximumCount <= CMaximumHistoryPage),
    'Review history page exceeds bound');
  LTrack := ReadCatalogTrack(ACatalogRoot, AHash);
  try
    LDirectory := ReviewDirectory(ACatalogRoot, AHash);
    LRevision := LatestRevision(LDirectory);
    Need(AFirstRevision <= LRevision + 1,
      'Review history starts beyond current revision');
    Result := TJSONObject.Create;
    try
      Result.Add('version', 1);
      Result.Add('source_sha256', AHash);
      Result.Add('revision', LRevision);
      Result.Add('source', LTrack);
      LTrack := nil;
      LRows := TJSONArray.Create;
      Result.Add('events', LRows);
      for LIndex := AFirstRevision to LRevision do
      begin
        if LRows.Count >= AMaximumCount then
        begin
          Break;
        end;
        LEvent := ReadEvent(LDirectory, LIndex);
        try
          Need(LEvent.Strings['source_sha256'] = AHash,
            'Review event source differs from history');
          LRows.Add(LEvent);
          LEvent := nil;
        finally
          LEvent.Free;
        end;
      end;
    except
      Result.Free;
      raise;
    end;
  finally
    LTrack.Free;
  end;
end;

function ReadCatalogCurrentLabels(const ACatalogRoot, AHash: String;
  const AStartFrame, AEndFrame: Int64; const AMaximumCount: Integer): TJSONObject;
var
  LTrack: TJSONObject;
  LDirectory: String;
  LRevision: Integer;
  LIndex: Integer;
  LPosition: Integer;
  LStates: TStringList;
  LEvent: TJSONObject;
  LChange: TJSONObject;
  LRow: TJSONObject;
  LRows: TJSONArray;
  LId: String;
begin
  Need((AMaximumCount > 0) and (AMaximumCount <= 2048),
    'Current-label page exceeds count bound');
  LTrack := ReadCatalogTrack(ACatalogRoot, AHash);
  try
    Need((AStartFrame >= 0) and (AEndFrame > AStartFrame) and
      (AEndFrame <= LTrack.Int64s['frame_count']),
      'Current-label page lies outside source frames');
    LDirectory := ReviewDirectory(ACatalogRoot, AHash);
    LRevision := LatestRevision(LDirectory);
    LStates := TStringList.Create;
    try
      LStates.Sorted := True;
      LStates.CaseSensitive := True;
      for LIndex := 1 to LRevision do
      begin
        LEvent := ReadEvent(LDirectory, LIndex);
        try
          Need(LEvent.Strings['source_sha256'] = AHash,
            'Review event source differs from current labels');
          LChange := LEvent.Objects['change'];
          LId := RequiredText(LChange, 'label_id', 128);
          LRow := TJSONObject(GetJSON(LChange.AsJSON));
          try
            LRow.Add('reviewer', LEvent.Strings['reviewer']);
            LRow.Add('revision', LIndex);
            LPosition := LStates.IndexOf(LId);
            if LPosition >= 0 then
            begin
              LStates.Objects[LPosition].Free;
              LStates.Objects[LPosition] := LRow;
            end
            else
            begin
              LStates.AddObject(LId, LRow);
            end;
            LRow := nil;
          finally
            LRow.Free;
          end;
        finally
          LEvent.Free;
        end;
      end;
      Result := TJSONObject.Create;
      try
        Result.Add('version', 1);
        Result.Add('source_sha256', AHash);
        Result.Add('review_revision', LRevision);
        Result.Add('start_frame', AStartFrame);
        Result.Add('end_frame', AEndFrame);
        LRows := TJSONArray.Create;
        Result.Add('labels', LRows);
        for LIndex := 0 to LStates.Count - 1 do
        begin
          LRow := TJSONObject(LStates.Objects[LIndex]);
          if (LRow.Int64s['end_frame'] > AStartFrame) and
            (LRow.Int64s['start_frame'] < AEndFrame) then
          begin
            Need(LRows.Count < AMaximumCount,
              'Current-label page has too many labels; narrow region');
            LRows.Add(LRow);
            LStates.Objects[LIndex] := nil;
          end;
        end;
        Result.Add('count', LRows.Count);
      except
        Result.Free;
        raise;
      end;
    finally
      for LIndex := 0 to LStates.Count - 1 do
      begin
        LStates.Objects[LIndex].Free;
      end;
      LStates.Free;
    end;
  finally
    LTrack.Free;
  end;
end;

end.
