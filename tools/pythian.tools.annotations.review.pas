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
{ Returns the latest event for one source-local label ID, or nil when unused.
  Memory use is independent of source duration and total label count. }
function FindCatalogCurrentLabel(const ACatalogRoot, AHash,
  ALabelId: String): TJSONObject;
function CatalogProposalsUnlocked(const ACatalogRoot: String;
  const ATrack: TJSONObject): Boolean;

implementation

uses
  Classes,
  SysUtils,
  jsonparser,
  pythian.audio,
  pythian.tools.annotations.catalog,
  pythian.tools.annotations.proposal,
  pythian.tools.annotations.contract,
  pythian.tools.annotations.sourceguard;

const
  CMaximumTransactionBytes = 16384;
  CMaximumEventBytes = 32768;
  CMaximumRevision = 100000;
  CMaximumHistoryPage = 256;

function ValidTonalRoot(const ARoot: String): Boolean;
begin
  Result := (Length(ARoot) >= 1) and (Length(ARoot) <= 2);
  if not Result then
  begin
    Exit;
  end;
  Result := ARoot[1] in ['A'..'G'];
  if Result and (Length(ARoot) = 2) then
  begin
    Result := ARoot[2] in ['#', 'b'];
  end;
end;

function ValidTonalValue(const AValue: String): Boolean;
var
  LSeparator: Integer;
  LName: String;
  LIndex: Integer;
begin
  if (AValue = 'unknown') or (AValue = 'ambiguous') then
  begin
    Exit(True);
  end;
  LSeparator := Pos(':', AValue);
  if LSeparator = 0 then
  begin
    Exit(False);
  end;
  LName := Copy(AValue, LSeparator + 1, MaxInt);
  Result := ValidTonalRoot(Copy(AValue, 1, LSeparator - 1)) and
    (Length(LName) >= 1) and (Length(LName) <= 48);
  if not Result then
  begin
    Exit;
  end;
  for LIndex := 1 to Length(LName) do
  begin
    if not (LName[LIndex] in ['a'..'z', '0'..'9', '_']) then
    begin
      Exit(False);
    end;
  end;
end;

function ValidTempoValue(const AValue: String): Boolean;
var
  LIndex: Integer;
  LDecimal: Integer;
  LCode: Integer;
  LBpm: Double;
begin
  if (AValue = 'unknown') or (AValue = 'ambiguous') then
  begin
    Exit(True);
  end;
  Result := (Length(AValue) >= 1) and (Length(AValue) <= 10);
  if not Result then
  begin
    Exit;
  end;
  LDecimal := 0;
  for LIndex := 1 to Length(AValue) do
  begin
    if AValue[LIndex] = '.' then
    begin
      if (LDecimal <> 0) or (LIndex = 1) or
        (LIndex = Length(AValue)) then
      begin
        Exit(False);
      end;
      LDecimal := LIndex;
    end
    else if not (AValue[LIndex] in ['0'..'9']) then
    begin
      Exit(False);
    end;
  end;
  if (LDecimal > 0) and (Length(AValue) - LDecimal > 6) then
  begin
    Exit(False);
  end;
  Val(AValue, LBpm, LCode);
  Result := (LCode = 0) and (LBpm >= 0.1) and (LBpm <= 1000);
end;

function ValidMeterValue(const AValue: String): Boolean;
var
  LSeparator: Integer;
  LIndex: Integer;
  LNumerator: Integer;
  LDenominator: Integer;
begin
  if (AValue = 'unknown') or (AValue = 'ambiguous') then
  begin
    Exit(True);
  end;
  LSeparator := Pos('/', AValue);
  Result := (LSeparator >= 2) and
    (LSeparator < Length(AValue)) and (Length(AValue) <= 5);
  if not Result then
  begin
    Exit;
  end;
  for LIndex := 1 to Length(AValue) do
  begin
    if (LIndex <> LSeparator) and
      not (AValue[LIndex] in ['0'..'9']) then
    begin
      Exit(False);
    end;
  end;
  Result := TryStrToInt(Copy(AValue, 1, LSeparator - 1), LNumerator) and
    TryStrToInt(Copy(AValue, LSeparator + 1, MaxInt), LDenominator);
  if Result then
  begin
    Result := (LNumerator >= 1) and (LNumerator <= 64) and
      (LDenominator in [1, 2, 4, 8, 16, 32, 64]);
  end;
end;

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
    Need((Result.Integers['version'] in [1, 2]) and
      (Result.Integers['revision'] = ARevision),
      'Review event revision differs from filename');
    if Result.Integers['version'] = 2 then
    begin
      Need((Result.Find('change') <> nil) and
        (Result.Find('change').JSONType = jtObject),
        'Structured review event requires change');
      ValidateStructuredChange(Result.Objects['change'],
        Result.Strings['source_sha256']);
    end;
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

function NormalizeChange(const AInput, ATrack: TJSONObject;
  const AStructured: Boolean): TJSONObject;
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
    (LType = 'presence') or (LType = 'activity') or
    (LType = 'key') or (LType = 'tempo') or
    (LType = 'meter') or (LType = 'harmony') or
    (LType = 'part_role') or
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
  if LType = 'activity' then
  begin
    Need((LValue = 'attack') or (LValue = 'continuation') or
      (LValue = 'release_tail') or (LValue = 'rest') or
      (LValue = 'unknown') or (LValue = 'noise_only'),
      'Invalid activity value');
  end;
  if (LType = 'key') or (LType = 'harmony') then
  begin
    Need(((LType = 'key') and (LValue = 'no_key')) or
      ValidTonalValue(LValue), 'Invalid tonal value');
  end;
  if LType = 'tempo' then
  begin
    Need(ValidTempoValue(LValue), 'Invalid tempo BPM');
  end;
  if LType = 'meter' then
  begin
    Need(ValidMeterValue(LValue), 'Invalid meter');
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
    if (LType = 'note') and
      (not AStructured or
       ((LValue <> 'unknown') and (LValue <> 'ambiguous'))) then
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

procedure ValidateFixedLinks(const ACatalogRoot, AHash: String;
  const ARequest: TJSONObject);
var
  LSpec: TJSONObject;
  LLinks: TJSONArray;
  LLink: TJSONObject;
  LTarget: TJSONObject;
  LIndex: Integer;
begin
  LSpec := ARequest.Objects['answer_spec'];
  LLinks := LSpec.Arrays['links'];
  for LIndex := 0 to LLinks.Count - 1 do
  begin
    LLink := LLinks.Objects[LIndex];
    if LLink.Strings['kind'] = 'proposal' then
    begin
      Need(CatalogProposalExists(ACatalogRoot, AHash,
        LLink.Strings['target_id']),
        'Structured answer proposal link is unavailable');
    end
    else
    begin
      LTarget := FindCatalogCurrentLabel(ACatalogRoot, AHash,
        LLink.Strings['target_id']);
      try
        Need((LTarget <> nil) and
          (LTarget.Strings['status'] = 'approved') and
          (LTarget.Strings['type'] = LLink.Strings['target_type']) and
          (LTarget.Integers['revision'] =
            LLink.Integers['target_revision']) and
          (LTarget.Strings['value'] <> 'unknown') and
          (LTarget.Strings['value'] <> 'ambiguous'),
          'Structured answer reviewed-label link is unavailable');
      finally
        LTarget.Free;
      end;
    end;
  end;
end;

procedure VerifySourceAsset(const ACatalogRoot, AHash: String;
  const ATrack: TJSONObject);
var
  LPath: String;
begin
  LPath := IncludeTrailingPathDelimiter(ExpandFileName(ACatalogRoot)) +
    'sources' + PathDelim + AHash + '.wav';
  VerifyGuardedSource(LPath, AHash, ATrack.Int64s['source_bytes']);
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
  LTransactionVersion: Int64;
  LRequestId: String;
  LRequestHash: String;
  LRequest: TJSONObject;
  LCurrent: TJSONObject;
begin
  Need(ATransaction <> nil, 'Review transaction is required');
  Need(Length(ATransaction.AsJSON) <= CMaximumTransactionBytes,
    'Review transaction exceeds size bound');
  LTransactionVersion := RequiredInt64(ATransaction, 'version');
  Need(LTransactionVersion in [1, 2],
    'Unsupported review transaction version');
  LHash := RequiredText(ATransaction, 'source_sha256', 64);
  Need(ValidHash(LHash), 'Invalid review source SHA256');
  LExpected := RequiredInt64(ATransaction, 'expected_revision');
  Need((LExpected >= 0) and (LExpected < CMaximumRevision),
    'Review expected revision exceeds bound');
  LReviewer := RequiredText(ATransaction, 'reviewer', 128);
  LRequestId := '';
  LRequestHash := '';
  if LTransactionVersion = 2 then
  begin
    LRequestId := RequiredText(ATransaction, 'request_id', 128);
    LRequestHash := RequiredText(ATransaction,
      'request_sha256', 64);
    Need(ValidHash(LRequestHash), 'Invalid request SHA256');
  end;
  Need((ATransaction.Find('change') <> nil) and
    (ATransaction.Find('change').JSONType = jtObject),
    'Review requires one change object');
  LTrack := ReadCatalogTrack(ACatalogRoot, LHash);
  try
    LChange := NormalizeChange(ATransaction.Objects['change'], LTrack,
      LTransactionVersion = 2);
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
        LCurrent := FindCatalogCurrentLabel(ACatalogRoot, LHash,
          LChange.Strings['label_id']);
        try
          if (LCurrent <> nil) and
            (LCurrent.Find('request_sha256') <> nil) then
            Need((LTransactionVersion = 2) and
              (LCurrent.Strings['request_sha256'] = LRequestHash),
              'Structured label corrections require their exact published request');
        finally
          LCurrent.Free;
        end;
        if LTransactionVersion = 2 then
        begin
          LRequest := FindPublishedStructuredRequest(ACatalogRoot,
            LRequestId, LRequestHash);
          try
            Need((LRequest.Int64s['end_frame'] <=
              LTrack.Int64s['frame_count']) and
              (LRequest.Int64s['end_frame'] -
               LRequest.Int64s['start_frame'] <=
                Int64(LTrack.Integers['sample_rate']) * 30),
              'Structured request lies outside bounded source region');
            if Copy(LChange.Strings['type'], 1, 4) = 'ext.' then
              Need(LChange.Int64s['extension_version'] = 2,
                'Structured review extension version must be 2');
            LChange.Add('request_sha256', LRequestHash);
            LChange.Add('request', LRequest);
            LRequest := nil;
            ValidateStructuredChange(LChange, LHash);
            ValidateFixedLinks(ACatalogRoot, LHash,
              LChange.Objects['request']);
          finally
            LRequest.Free;
          end;
        end;
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
          Result.Add('version', LTransactionVersion);
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

function FindCatalogCurrentLabel(const ACatalogRoot, AHash,
  ALabelId: String): TJSONObject;
var
  LTrack: TJSONObject;
  LDirectory: String;
  LRevision: Integer;
  LEvent: TJSONObject;
  LChange: TJSONObject;
begin
  Need(SafeIdentifier(ALabelId), 'Invalid label ID');
  LTrack := ReadCatalogTrack(ACatalogRoot, AHash);
  try
    LDirectory := ReviewDirectory(ACatalogRoot, AHash);
    LRevision := LatestRevision(LDirectory);
    Result := nil;
    while LRevision > 0 do
    begin
      LEvent := ReadEvent(LDirectory, LRevision);
      try
        Need(LEvent.Strings['source_sha256'] = AHash,
          'Review event source differs from current label');
        LChange := LEvent.Objects['change'];
        if RequiredText(LChange, 'label_id', 128) = ALabelId then
        begin
          Result := TJSONObject(GetJSON(LChange.AsJSON));
          Result.Add('revision', LRevision);
          Exit;
        end;
      finally
        LEvent.Free;
      end;
      Dec(LRevision);
    end;
  finally
    LTrack.Free;
  end;
end;

end.
