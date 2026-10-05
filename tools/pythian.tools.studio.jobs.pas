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
unit pythian.tools.studio.jobs;

{$mode delphi}
{$H+}

interface

uses
  Classes,
  fpjson,
  pythian.audio;

const
  StudioJobWriteFormat = 'pythian.studio.job.write.v1';
  StudioJobFormat = 'pythian.studio.job.v1';
  StudioJobsFormat = 'pythian.studio.jobs.v1';
  StudioTimeoutMessage = 'Time limit reached. Try a shorter selection or smaller operation.';
  MaximumStudioJobs = 256;
  MaximumStudioQueuedJobs = 32;
  MaximumStudioJobSeconds = 600;
  MaximumStudioTrainingSeconds = 7200;
  MaximumStudioLibrarySeconds = 7200;
  MaximumStudioSessionSeconds = 172800;
  MaximumStudioJobMemoryBytes = 128 * 1024 * 1024;
  MaximumStudioJobSourceBytes: Int64 = 34359738368;
  MaximumStudioJobFeatures = 500000;

type
  EStudioJobCancelled = class(EAudio);
  EStudioJobTimeout = class(EAudio);

{ Owned detached results; no source PCM reads, WFC or worker launch here. }
function ParseStudioJobWrite(const AText: String): TJSONObject;
{ Collection verification and audition learning can read hours of source audio.
  Both worker and supervisor use the declared finite job policy. }
function StudioJobRuntimeSeconds(const AKind: String): Integer;
function StudioJobRequestRuntimeSeconds(const ARequest: TJSONObject): Integer;
function PrepareStudioJob(const ACatalogRoot: String;
  const AWrite: TJSONObject): TJSONObject;
function EnqueueStudioJob(const ACatalogRoot: String;
  const AWrite: TJSONObject): TJSONObject;
function ListStudioJobs(const ACatalogRoot: String): TJSONObject;
function ReadStudioJob(const ACatalogRoot, AJobId: String): TJSONObject;
function CancelStudioJob(const ACatalogRoot, AJobId: String): TJSONObject;

{ Worker/supervisor boundary. Recovery is permitted only after the supervisor
  has established that no worker for this catalog remains alive. }
function ReadStudioJobRequest(const ACatalogRoot, AJobId: String): TJSONObject;
function ClaimStudioJob(const ACatalogRoot, AJobId: String): TJSONObject;
procedure AdvanceStudioJob(const ACatalogRoot, AJobId, AStatus, AStage: String;
  const ADone, ATotal: Int64; const AResults: TJSONObject = nil;
  const AErrorCode: String = ''; const AErrorMessage: String = '';
  const AProgressUnit: String = ''; const AProgressPass: Integer = 0);
function StudioJobCancelled(const ACatalogRoot, AJobId: String): Boolean;
procedure ReleaseStudioWorker(const ACatalogRoot: String; const AStream: Boolean = False);
function StudioWorkerLockDirectory(const ACatalogRoot: String;
  const AStream: Boolean = False): String;
procedure RecoverStudioJobs(const ACatalogRoot: String; const AWorkerStopped: Boolean);
function StudioJobDirectory(const ACatalogRoot, AJobId: String): String;
{ Creates only the private parent. The fresh leaf remains absent for importer
  and library staging; it must be outside both durable catalog and library. }
function ReserveStudioJobStage(const ACatalogRoot, ALibraryRoot, AJobId,
  APurpose: String): String;
function StudioTextHash(const AText: String): String;
function ReadStudioJSON(const APath: String): TJSONObject;
function OpenStudioReadStream(const APath: String): TFileStream;
procedure WriteStudioJSONNew(const APath: String; const AObject: TJSONObject);
{ Mutable bounded checkpoints only; immutable job/identity records use New. }
procedure ReplaceStudioJSON(const APath: String; const AObject: TJSONObject);
procedure ReplaceStudioBinary(const APath: String; const ABytes: TAudioBytes);

implementation

uses
  SysUtils,
  Math,
  jsonparser,
  jsonscanner,
  pythian.hash,
  pythian.tools.annotations.catalog,
  pythian.tools.studio.projects,
  pythian.tools.studio.&library.discovery
  {$IFDEF MSWINDOWS}, Windows{$ENDIF};

const
  CJobWriterWaitMilliseconds = 2000;

var
  GJobsLock: TRTLCriticalSection;

function StudioJobRuntimeSeconds(const AKind: String): Integer;
begin
  if AKind = 'stream_generate' then
    Result := MaximumStudioSessionSeconds
  else if (AKind = 'library_refresh') or (AKind = 'library_prepare') then
    Result := MaximumStudioLibrarySeconds
  else if AKind = 'train_generate' then
    Result := MaximumStudioTrainingSeconds
  else
    Result := MaximumStudioJobSeconds;
end;

procedure Need(const ACondition: Boolean; const AMessage: String);
begin
  if not ACondition then
  begin
    raise EAudio.Create(AMessage);
  end;
end;

function StudioJobRequestRuntimeSeconds(const ARequest: TJSONObject): Integer;
var
  LValue: TJSONData;
begin
  LValue := ARequest.Find('worker_seconds');
  if LValue = nil then
    Exit(MaximumStudioJobSeconds);
  Need((LValue.JSONType = jtNumber) and (LValue.AsFloat = LValue.AsInt64) and
    (LValue.AsInt64 >= 1) and
    (LValue.AsInt64 <= StudioJobRuntimeSeconds(ARequest.Strings['kind'])),
    'Stored job runtime budget exceeds its supported policy');
  Result := LValue.AsInteger;
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
  Result := Result and (UpperCase(AText) <> 'CON') and (UpperCase(AText) <> 'PRN') and
    (UpperCase(AText) <> 'AUX') and (UpperCase(AText) <> 'NUL') and
    not ((Length(AText) = 4) and
    ((Copy(UpperCase(AText), 1, 3) = 'COM') or
     (Copy(UpperCase(AText), 1, 3) = 'LPT')) and (AText[4] in ['1'..'9']));
end;

procedure CheckPath(const APath: String); forward;

function ValidHash(const AText: String): Boolean;
var
  LCharacter: Char;
begin
  Result := Length(AText) = 64;
  for LCharacter in AText do
  begin
    Result := Result and (LCharacter in ['0'..'9', 'a'..'f']);
  end;
end;

function ReserveStudioJobStage(const ACatalogRoot, ALibraryRoot, AJobId,
  APurpose: String): String;
var
  LBase: String;
  LCatalog: String;
  LLibrary: String;
  LGuid: TGuid;
begin
  Need(SafeId(AJobId) and SafeId(APurpose), 'Invalid Studio staging identity');
  LCatalog := IncludeTrailingPathDelimiter(ExpandFileName(ACatalogRoot));
  LLibrary := IncludeTrailingPathDelimiter(ExpandFileName(ALibraryRoot));
  LBase := IncludeTrailingPathDelimiter(ExpandFileName('build' + PathDelim +
    'studio-stages' + PathDelim + Copy(StudioTextHash('studio-stage-catalog-v1|' + LCatalog), 1, 16)));
  Need((Pos(LowerCase(LCatalog), LowerCase(LBase)) <> 1) and
    (Pos(LowerCase(LBase), LowerCase(LCatalog)) <> 1) and
    (Pos(LowerCase(LLibrary), LowerCase(LBase)) <> 1) and
    (Pos(LowerCase(LBase), LowerCase(LLibrary)) <> 1),
    'Studio import staging must be separate from catalog and library');
  CheckPath(LBase);
  Need(ForceDirectories(LBase), 'Cannot create private Studio staging parent');
  CreateGUID(LGuid);
  { Keep the stage path short enough for native importer hash subdirectories.
    The GUID provides leaf uniqueness; job/purpose remain in durable receipts. }
  Result := LBase + Copy(GUIDToString(LGuid), 2, 36);
  CheckPath(Result);
  Need(not FileExists(Result) and not DirectoryExists(Result), 'Studio stage already exists');
end;

function Text(const AObject: TJSONObject; const AKey: String;
  const ARequired: Boolean = True): String;
var
  LValue: TJSONData;
begin
  LValue := AObject.Find(AKey);
  if (LValue = nil) and not ARequired then
  begin
    Exit('');
  end;
  Need((LValue <> nil) and (LValue.JSONType = jtString), 'Missing or invalid ' + AKey);
  Result := LValue.AsString;
  Need(Length(Result) <= 2048, 'Text exceeds job bound');
end;

function Number(const AObject: TJSONObject; const AKey: String): Int64;
var
  LValue: TJSONData;
begin
  LValue := AObject.Find(AKey);
  Need((LValue <> nil) and (LValue.JSONType = jtNumber) and
    (TJSONNumber(LValue).NumberType in [ntInteger, ntInt64]), 'Exact integer required for ' + AKey);
  Result := LValue.AsInt64;
end;

procedure Keys(const AObject: TJSONObject; const AAllowed: String);
var
  LIndex: Integer;
begin
  for LIndex := 0 to AObject.Count - 1 do
  begin
    Need(Pos('|' + AObject.Names[LIndex] + '|', AAllowed) > 0, 'Unsupported job field');
  end;
end;

function StudioTextHash(const AText: String): String;
var
  LBytes: TAudioBytes;
begin
  SetLength(LBytes, Length(AText));
  if Length(LBytes) > 0 then
  begin
    Move(AText[1], LBytes[0], Length(LBytes));
  end;
  Result := Sha256Bytes(LBytes);
end;

procedure CheckPath(const APath: String);
var
  LPath: String;
  LParent: String;
  LAttributes: LongInt;
begin
  LPath := ExcludeTrailingPathDelimiter(ExpandFileName(APath));
  repeat
    if FileExists(LPath) or DirectoryExists(LPath) then
    begin
      LAttributes := FileGetAttr(LPath);
      Need(LAttributes >= 0, 'Cannot inspect Studio storage');
      {$IFDEF MSWINDOWS}
      Need((LAttributes and FILE_ATTRIBUTE_REPARSE_POINT) = 0,
        'Studio storage must not traverse links');
      {$ELSE}
      Need((LAttributes and faSymLink) = 0, 'Studio storage must not traverse links');
      {$ENDIF}
    end;
    LParent := ExtractFileDir(LPath);
    if LParent = LPath then
    begin
      Break;
    end;
    LPath := LParent;
  until LPath = '';
end;

function JobsRoot(const ACatalogRoot: String): String;
begin
  CheckPath(ACatalogRoot);
  Need(DirectoryExists(ACatalogRoot), 'Catalog root does not exist');
  Result := IncludeTrailingPathDelimiter(ExpandFileName(ACatalogRoot)) + 'studio' +
    PathDelim + 'jobs';
  CheckPath(Result);
end;

function StudioJobDirectory(const ACatalogRoot, AJobId: String): String;
begin
  Need(SafeId(AJobId), 'Invalid job identifier');
  Result := JobsRoot(ACatalogRoot) + PathDelim + AJobId;
  CheckPath(Result);
end;

function ParseStudioJobWrite(const AText: String): TJSONObject;
var
  LParser: TJSONParser;
  LValue: TJSONData;
  LDepth: Integer;
  LString: Boolean;
  LEscape: Boolean;
  LCharacter: Char;
begin
  Need((Length(AText) > 0) and (Length(AText) <= 1048576), 'Job JSON exceeds byte bound');
  LDepth := 0;
  LString := False;
  LEscape := False;
  for LCharacter in AText do
  begin
    if LString then
    begin
      if LEscape then
      begin
        LEscape := False;
      end
      else if LCharacter = '\' then
      begin
        LEscape := True;
      end
      else if LCharacter = '"' then
      begin
        LString := False;
      end;
    end
    else if LCharacter = '"' then
    begin
      LString := True;
    end
    else if LCharacter in ['{', '['] then
    begin
      Inc(LDepth);
      Need(LDepth <= 16, 'Job JSON exceeds nesting bound');
    end
    else if LCharacter in ['}', ']'] then
    begin
      Dec(LDepth);
      Need(LDepth >= 0, 'Malformed job JSON');
    end;
  end;
  Need((LDepth = 0) and not LString, 'Malformed job JSON');
  LParser := TJSONParser.Create(AText, [joUTF8, joStrict]);
  try
    try
      LValue := LParser.Parse;
    except
      on E: EJSON do
      begin
        raise EAudio.Create('Malformed job JSON');
      end;
      on E: EParserError do
      begin
        raise EAudio.Create('Malformed job JSON');
      end;
    end;
    if LValue.JSONType <> jtObject then
    begin
      LValue.Free;
      raise EAudio.Create('Job JSON must be an object');
    end;
    Result := TJSONObject(LValue);
  finally
    LParser.Free;
  end;
end;

function OpenStudioReadStream(const APath: String): TFileStream;
var
  LStarted: QWord;
begin
  CheckPath(APath);
  LStarted := GetTickCount64;
  repeat
    try
      Exit(TFileStream.Create(APath, fmOpenRead or fmShareDenyWrite));
    except
      on E: EFOpenError do
      begin
        {$IFDEF MSWINDOWS}
        if not (GetLastError in [ERROR_SHARING_VIOLATION, ERROR_LOCK_VIOLATION]) or
          (GetTickCount64 - LStarted >= 2000) then raise;
        Sleep(5);
        {$ELSE}
        raise;
        {$ENDIF}
      end;
    end;
  until False;
end;

function ReadStudioJSON(const APath: String): TJSONObject;
var
  LStream: TFileStream;
  LText: String;
begin
  LStream := OpenStudioReadStream(APath);
  try
    Need((LStream.Size > 0) and (LStream.Size <= 1048576), 'Studio record exceeds byte bound');
    SetLength(LText, Integer(LStream.Size));
    LStream.ReadBuffer(LText[1], Length(LText));
  finally
    LStream.Free;
  end;
  Result := ParseStudioJobWrite(LText);
end;

procedure WriteStudioData(const APath, AText: String;
  const AReplace: Boolean);
var
  LStage: String;
  LStream: TFileStream;
  LGuid: TGuid;
  LReplaced: Boolean;
  LStarted: QWord;
begin
  CheckPath(APath);
  Need((AReplace or not FileExists(APath)) and not DirectoryExists(APath),
    'Studio record already exists');
  Need(ForceDirectories(ExtractFileDir(APath)), 'Cannot create Studio record directory');
  CreateGUID(LGuid);
  LStage := IncludeTrailingPathDelimiter(ExtractFileDir(APath)) +
    GUIDToString(LGuid) + '.stage';
  Need(not FileExists(LStage) and not DirectoryExists(LStage), 'Studio record stage must be fresh');
  Need((Length(AText) > 0) and (Length(AText) <= 1048576), 'Studio record exceeds byte bound');
  try
    LStream := TFileStream.Create(LStage, fmCreate or fmShareExclusive);
    try
      LStream.WriteBuffer(AText[1], Length(AText));
      Need(FileFlush(LStream.Handle), 'Cannot flush Studio record');
    finally
      LStream.Free;
    end;
    if AReplace then
    begin
      LStarted := GetTickCount64;
      repeat
        {$IFDEF MSWINDOWS}
        LReplaced := MoveFileExW(PWideChar(UnicodeString(LStage)),
          PWideChar(UnicodeString(APath)), MOVEFILE_REPLACE_EXISTING);
        {$ELSE}
        LReplaced := RenameFile(LStage, APath);
        {$ENDIF}
        if LReplaced then Break;
        Sleep(5);
      until GetTickCount64 - LStarted >= 2000;
      Need(LReplaced, 'Cannot replace Studio checkpoint');
    end
    else
      Need(not FileExists(APath) and RenameFile(LStage, APath), 'Cannot publish Studio record');
  finally
    if FileExists(LStage) then
    begin
      SysUtils.DeleteFile(LStage);
    end;
  end;
end;

procedure WriteStudioJSONNew(const APath: String; const AObject: TJSONObject);
begin
  WriteStudioData(APath, AObject.AsJSON, False);
end;

procedure ReplaceStudioJSON(const APath: String; const AObject: TJSONObject);
begin
  WriteStudioData(APath, AObject.AsJSON, True);
end;

procedure ReplaceStudioBinary(const APath: String; const ABytes: TAudioBytes);
var
  LText: String;
begin
  Need((Length(ABytes) > 0) and (Length(ABytes) <= 1048576), 'Studio binary checkpoint exceeds byte bound');
  SetLength(LText, Length(ABytes));
  Move(ABytes[0], LText[1], Length(ABytes));
  WriteStudioData(APath, LText, True);
end;

function Terminal(const AStatus: String): Boolean;
begin
  Result := (AStatus = 'completed') or (AStatus = 'failed') or (AStatus = 'cancelled');
end;

function JobNames(const ACatalogRoot: String): TStringList;
var
  LFound: TSearchRec;
  LStatus: Integer;
begin
  Result := TStringList.Create;
  try
    if DirectoryExists(JobsRoot(ACatalogRoot)) then
    begin
      LStatus := FindFirst(JobsRoot(ACatalogRoot) + PathDelim + '*', faAnyFile, LFound);
      if LStatus = 0 then
      begin
        try
          while LStatus = 0 do
          begin
            if (LFound.Attr and faDirectory <> 0) and SafeId(LFound.Name) then
            begin
              Result.Add(LFound.Name);
              Need(Result.Count <= MaximumStudioJobs, 'Studio job count exceeds bound');
            end;
            LStatus := FindNext(LFound);
          end;
        finally
          SysUtils.FindClose(LFound);
        end;
      end;
    end;
    Result.Sort;
  except
    Result.Free;
    raise;
  end;
end;

function ReadStudioJobRequest(const ACatalogRoot, AJobId: String): TJSONObject;
var
  LHash: String;
begin
  Result := ReadStudioJSON(StudioJobDirectory(ACatalogRoot, AJobId) + PathDelim + 'request.json');
  try
    Need(Result.Strings['job_id'] = AJobId, 'Stored job identifier differs');
    LHash := Result.Strings['request_sha256'];
    Result.Delete('request_sha256');
    Need(StudioTextHash(Result.AsJSON) = LHash, 'Stored job request digest differs');
    Result.Add('request_sha256', LHash);
    StudioJobRequestRuntimeSeconds(Result);
  except
    Result.Free;
    raise;
  end;
end;

function ReadStudioJob(const ACatalogRoot, AJobId: String): TJSONObject;
var
  LDirectory: String;
  LFound: TSearchRec;
  LStatus: Integer;
  LRevision: Integer;
  LMaximum: Integer;
  LRequest: TJSONObject;
begin
  LDirectory := StudioJobDirectory(ACatalogRoot, AJobId);
  LMaximum := 0;
  LStatus := FindFirst(LDirectory + PathDelim + '*.event.json', faAnyFile, LFound);
  if LStatus = 0 then
  begin
    try
      while LStatus = 0 do
      begin
        Need((Length(LFound.Name) = 19) and
          TryStrToInt(Copy(LFound.Name, 1, 8), LRevision) and
          (LRevision >= 1) and (LRevision <= 100000), 'Invalid Studio event name');
        if LRevision > LMaximum then
        begin
          LMaximum := LRevision;
        end;
        LStatus := FindNext(LFound);
      end;
    finally
      SysUtils.FindClose(LFound);
    end;
  end;
  Need(LMaximum >= 1, 'Studio job has no accepted state');
  Result := ReadStudioJSON(LDirectory + PathDelim + Format('%.8d.event.json', [LMaximum]));
  try
    Need((Result.Strings['format'] = StudioJobFormat) and
      (Result.Strings['job_id'] = AJobId) and (Result.Integers['event_revision'] = LMaximum),
      'Studio event identity differs');
    LRequest := ReadStudioJobRequest(ACatalogRoot, AJobId);
    try
      Need(Result.Strings['request_sha256'] = LRequest.Strings['request_sha256'],
        'Studio event request binding differs');
      Result.Integers['maximum_worker_seconds'] := StudioJobRequestRuntimeSeconds(LRequest);
      LRequest.Delete('project_snapshot');
      LRequest.Delete('request_sha256');
      LRequest.Delete('worker_seconds');
      Result.Add('request', LRequest.Clone);
    finally
      LRequest.Free;
    end;
    Result.Booleans['cancel_requested'] := StudioJobCancelled(ACatalogRoot, AJobId);
  except
    Result.Free;
    raise;
  end;
end;

procedure LockJobs(const ACatalogRoot: String);
var
  LLock: String;
  LStarted: QWord;
begin
  EnterCriticalSection(GJobsLock);
  try
    Need(ForceDirectories(JobsRoot(ACatalogRoot)), 'Cannot create Studio job storage');
    LLock := JobsRoot(ACatalogRoot) + PathDelim + '.write-lock';
    LStarted := GetTickCount64;
    { Big Boss: the service and worker publish through the same directory lock.
      A live progress write is ordinary contention, not an interrupted writer.
      Wait briefly for its owner; never remove or take over an occupied lock. }
    while not CreateDir(LLock) do
    begin
      Need(GetTickCount64 - LStarted < CJobWriterWaitMilliseconds,
        'Studio job writer remains busy; retry or inspect a stopped writer before recovery');
      Sleep(10);
    end;
  except
    LeaveCriticalSection(GJobsLock);
    raise;
  end;
end;

procedure UnlockJobs(const ACatalogRoot: String);
begin
  RemoveDir(JobsRoot(ACatalogRoot) + PathDelim + '.write-lock');
  LeaveCriticalSection(GJobsLock);
end;

procedure AddState(const ACatalogRoot, AJobId: String; const AState: TJSONObject);
var
  LStored: TJSONObject;
begin
  LStored := TJSONObject(AState.Clone);
  try
    LStored.Delete('request');
    LStored.Delete('maximum_worker_seconds');
    WriteStudioJSONNew(StudioJobDirectory(ACatalogRoot, AJobId) + PathDelim +
      Format('%.8d.event.json', [AState.Integers['event_revision']]), LStored);
  finally
    LStored.Free;
  end;
end;

function BuildJobRequest(const ACatalogRoot: String;
  const AWrite: TJSONObject): TJSONObject;
var
  LRequest: TJSONObject;
  LProject: TJSONObject;
  LExisting: TJSONObject;
  LJobId: String;
  LKind: String;
  LName: String;
  LQueued: Integer;
  LIndex: Integer;
  LSeeds: TJSONArray;
  LWeights: TJSONArray;
  LHash: String;
  LRow: TJSONObject;
begin
  Need(AWrite <> nil, 'Job write is required');
  Keys(AWrite, '|format|job_id|kind|project_id|project_revision|project_snapshot_sha256|' +
    'duration_ms|seeds|maximum_tokens|model_order|source_weights|resolve_unassigned|' +
    'parent_job_id|retry_of|source_sha256|start_frame|end_frame|effects|tail_seconds|' +
    'preview_job_id|collection_name|title|capture_id|mode|channel|tempo_bpm|' +
    'discovery_revision|entries|');
  Need(Text(AWrite, 'format') = StudioJobWriteFormat, 'Unsupported Studio job format');
  LJobId := Text(AWrite, 'job_id');
  Need(SafeId(LJobId), 'Invalid job identifier');
  LKind := Text(AWrite, 'kind');
  Need((LKind = 'train_generate') or (LKind = 'stream_generate') or (LKind = 'library_refresh') or
    (LKind = 'library_discover') or (LKind = 'library_prepare') or
    (LKind = 'inspect_source') or (LKind = 'effect_preview') or
    (LKind = 'effect_save') or (LKind = 'capture_inspect') or
    (LKind = 'capture_save') or (LKind = 'capture_pitch'), 'Unsupported Studio job kind');
  LRequest := TJSONObject(AWrite.Clone);
  try
    if (LKind = 'train_generate') or (LKind = 'stream_generate') then
    begin
      Keys(AWrite, '|format|job_id|kind|project_id|project_revision|project_snapshot_sha256|' +
        'duration_ms|seeds|maximum_tokens|model_order|source_weights|resolve_unassigned|' +
        'parent_job_id|retry_of|');
      if LKind = 'stream_generate' then
        Need((Number(AWrite, 'duration_ms') >= 1000) and
          (Number(AWrite, 'duration_ms') <= 86400000), 'Live duration must be 1 second to 24 hours')
      else
        Need((Number(AWrite, 'duration_ms') >= 20000) and
          (Number(AWrite, 'duration_ms') <= 40000), 'Review auditions must be 20..40 seconds');
      Need((Number(AWrite, 'maximum_tokens') >= 2) and
        (Number(AWrite, 'maximum_tokens') <= 16), 'Palette must contain 2..16 tokens');
      Need((Number(AWrite, 'model_order') >= 1) and
        (Number(AWrite, 'model_order') <= 3), 'Model order must be 1..3');
      Need((Text(AWrite, 'resolve_unassigned') = 'development') or
        (Text(AWrite, 'resolve_unassigned') = 'training'), 'Explicit training split is required');
      Need((AWrite.Find('seeds') <> nil) and (AWrite.Find('seeds').JSONType = jtArray),
        'Seeds must be an array');
      LSeeds := AWrite.Arrays['seeds'];
      Need((LSeeds.Count >= 1) and (LSeeds.Count <= 3), 'Batch requires 1..3 seeds');
      Need((LKind <> 'stream_generate') or (LSeeds.Count = 1), 'Live playback requires one seed');
      for LIndex := 0 to LSeeds.Count - 1 do
      begin
        Need((LSeeds[LIndex].JSONType = jtNumber) and
          (TJSONNumber(LSeeds[LIndex]).NumberType in [ntInteger, ntInt64]) and
          (LSeeds[LIndex].AsInt64 >= 0) and (LSeeds[LIndex].AsInt64 <= 2147483000),
          'Seed is outside the supported range');
        for LQueued := 0 to LIndex - 1 do
        begin
          Need(LSeeds[LQueued].AsInt64 <> LSeeds[LIndex].AsInt64, 'Duplicate seed');
        end;
      end;
      LProject := ReadStudioProjectRevision(ACatalogRoot, Text(AWrite, 'project_id'),
        Number(AWrite, 'project_revision'));
      try
        Need((LProject.Int64s['revision'] = Number(AWrite, 'project_revision')) and
          (LProject.Strings['snapshot_sha256'] = Text(AWrite, 'project_snapshot_sha256')),
          'Project revision or snapshot differs; reopen the saved project');
        Need(LProject.Strings['learning_mode'] = 'raw_acoustic',
          'Only raw acoustic recombination is currently runnable');
        Need((LProject.Arrays['sources'].Count >= 1) and
          (LProject.Arrays['sources'].Count <= 64), 'Project range count exceeds bound');
        Need((AWrite.Find('source_weights') <> nil) and
          (AWrite.Find('source_weights').JSONType = jtArray), 'Source weights are required');
        LWeights := AWrite.Arrays['source_weights'];
        Need((LWeights.Count >= 1) and (LWeights.Count <= 32), 'Source weights exceed bound');
        for LIndex := 0 to LWeights.Count - 1 do
        begin
          Need(LWeights[LIndex].JSONType = jtObject, 'Invalid source weight');
          LRow := TJSONObject(LWeights[LIndex]);
          Keys(LRow, '|source_sha256|weight|');
          Need((Number(LRow, 'weight') >= 1) and (Number(LRow, 'weight') <= 16),
            'Source weight must be 1..16');
          LHash := Text(LRow, 'source_sha256');
          Need(ValidHash(LHash), 'Invalid source weight identity');
          for LQueued := 0 to LIndex - 1 do
          begin
            Need(LWeights.Objects[LQueued].Strings['source_sha256'] <> LHash,
              'Duplicate source weight');
          end;
        end;
        LRequest.Add('project_snapshot', LProject.Clone);
      finally
        LProject.Free;
      end;
    end
    else if (LKind = 'inspect_source') or (LKind = 'effect_preview') then
    begin
      Keys(AWrite, '|format|job_id|kind|source_sha256|start_frame|end_frame|' +
        'parent_job_id|retry_of|effects|tail_seconds|');
      Need(ValidHash(Text(AWrite, 'source_sha256')) and
        (Number(AWrite, 'start_frame') >= 0) and
        (Number(AWrite, 'end_frame') > Number(AWrite, 'start_frame')) and
        (Number(AWrite, 'end_frame') - Number(AWrite, 'start_frame') <= 2000000),
        'Inspection requires one bounded original source range');
      if LKind = 'effect_preview' then
      begin
        if AWrite.Find('tail_seconds') <> nil then
        begin
          Need((AWrite.Find('tail_seconds').JSONType = jtNumber) and
            (AWrite.Floats['tail_seconds'] >= 0) and
            (AWrite.Floats['tail_seconds'] <= 10), 'Effect tail must be 0..10 seconds');
        end;
        Need((AWrite.Find('effects') <> nil) and
          (AWrite.Find('effects').JSONType = jtArray) and
          (AWrite.Arrays['effects'].Count <= 8), 'Effects require at most eight ordered stages');
        for LIndex := 0 to AWrite.Arrays['effects'].Count - 1 do
        begin
          Need(AWrite.Arrays['effects'][LIndex].JSONType = jtObject, 'Invalid effect stage');
        end;
      end
      else
      begin
        Need(AWrite.Find('effects') = nil, 'Inspection does not accept effects');
        Need(AWrite.Find('tail_seconds') = nil, 'Inspection does not accept an effect tail');
      end;
    end
    else if (LKind = 'effect_save') or (LKind = 'capture_save') then
    begin
      Keys(AWrite, '|format|job_id|kind|preview_job_id|capture_id|collection_name|title|' +
        'parent_job_id|retry_of|');
      Need((Length(Text(AWrite, 'collection_name')) >= 1) and
        (Length(Text(AWrite, 'collection_name')) <= 128), 'Collection name exceeds bound');
      Need((Length(Text(AWrite, 'title')) >= 1) and
        (Length(Text(AWrite, 'title')) <= 256), 'Clip title exceeds bound');
      if LKind = 'effect_save' then
      begin
        Need(AWrite.Find('capture_id') = nil, 'Effect save does not accept a capture identity');
        Need(SafeId(Text(AWrite, 'preview_job_id')), 'Invalid effect preview identity');
        LExisting := ReadStudioJob(ACatalogRoot, Text(AWrite, 'preview_job_id'));
        try
          Need((LExisting.Strings['kind'] = 'effect_preview') and
            (LExisting.Strings['status'] = 'completed'), 'Save requires a completed effect preview');
        finally
          LExisting.Free;
        end;
      end
      else
      begin
        Need(AWrite.Find('preview_job_id') = nil, 'Capture save does not accept an effect preview identity');
        Need(SafeId(Text(AWrite, 'capture_id')), 'Invalid capture identity');
      end;
    end
    else if LKind = 'capture_inspect' then
    begin
      Keys(AWrite, '|format|job_id|kind|capture_id|parent_job_id|retry_of|');
      Need(SafeId(Text(AWrite, 'capture_id')), 'Invalid capture identity');
    end
    else if LKind = 'capture_pitch' then
    begin
      Keys(AWrite, '|format|job_id|kind|capture_id|mode|channel|tempo_bpm|parent_job_id|retry_of|');
      Need(SafeId(Text(AWrite, 'capture_id')) and (Text(AWrite, 'mode') = 'single_pitch'),
        'Choose the supported single-pitch candidate preview');
      Need((Number(AWrite, 'channel') >= 0) and (Number(AWrite, 'channel') <= 1),
        'Pitch preview channel must be zero or one');
      Need((Number(AWrite, 'tempo_bpm') >= 40) and (Number(AWrite, 'tempo_bpm') <= 240),
        'MIDI clock tempo must be 40..240 BPM');
    end
    else if LKind = 'library_prepare' then
    begin
      Keys(AWrite, '|format|job_id|kind|discovery_revision|entries|parent_job_id|retry_of|');
      Need((Number(AWrite, 'discovery_revision') >= 1) and
        (Number(AWrite, 'discovery_revision') <= 10000) and
        (AWrite.Find('entries') <> nil) and (AWrite.Find('entries').JSONType = jtArray),
        'Preparation requires an immutable discovery selection');
      LExisting := ValidateStudioLibraryEntries(ACatalogRoot,
        Number(AWrite, 'discovery_revision'), AWrite.Arrays['entries']);
      LExisting.Free;
    end
    else
    begin
      Keys(AWrite, '|format|job_id|kind|parent_job_id|retry_of|');
    end;
    for LName in ['parent_job_id', 'retry_of'] do
    begin
      if AWrite.Find(LName) <> nil then
      begin
        Need(SafeId(Text(AWrite, LName)) and (Text(AWrite, LName) <> LJobId),
          'Invalid job ancestry');
        LExisting := ReadStudioJob(ACatalogRoot, Text(AWrite, LName));
        try
          if LName = 'retry_of' then
          begin
            Need((LExisting.Strings['status'] = 'failed') or
              (LExisting.Strings['status'] = 'cancelled'), 'Retry parent is not failed or cancelled');
          end;
        finally
          LExisting.Free;
        end;
      end;
    end;
    LRequest.Add('worker_seconds', StudioJobRuntimeSeconds(LKind));
    LRequest.Add('request_sha256', StudioTextHash(LRequest.AsJSON));
    Result := LRequest;
    LRequest := nil;
  finally
    LRequest.Free;
  end;
end;

function PrepareStudioJob(const ACatalogRoot: String;
  const AWrite: TJSONObject): TJSONObject;
var
  LRequest: TJSONObject;
  LRows: TJSONArray;
  LRow: TJSONObject;
  LTrack: TJSONObject;
  LIndex: Integer;
  LSelectedFrames: Int64;
  LEstimatedFeatures: Int64;
  LRate: Integer;
  LChannels: Integer;
  LNames: TStringList;
  LBytes: Int64;
  LOutputFrames: Int64;
  LOutputGrains: Int64;
  LLimits: TJSONObject;
begin
  LRequest := BuildJobRequest(ACatalogRoot, AWrite);
  try
    Result := TJSONObject.Create;
    try
      Result.Add('format', 'pythian.studio.job.preparation.v1');
      Result.Add('job_id', LRequest.Strings['job_id']);
      Result.Add('kind', LRequest.Strings['kind']);
      Result.Add('request_sha256', LRequest.Strings['request_sha256']);
      Result.Add('source_validation', 'metadata_only_pending_worker_content_verification');
      Result.Add('used_sources', TJSONArray.Create);
      Result.Add('exclusions', TJSONArray.Create);
      LLimits := TJSONObject.Create;
      Result.Add('limits', LLimits);
      LLimits.Add('worker_seconds', StudioJobRequestRuntimeSeconds(LRequest));
      LLimits.Add('logical_memory_bytes', MaximumStudioJobMemoryBytes);
      LLimits.Add('unique_source_bytes', MaximumStudioJobSourceBytes);
      LLimits.Add('analyzed_features', MaximumStudioJobFeatures);
      LLimits.Add('sources', 32);
      LLimits.Add('ranges', 64);
      LLimits.Add('output_count', 3);
      if (LRequest.Strings['kind'] = 'train_generate') or
        (LRequest.Strings['kind'] = 'stream_generate') then
      begin
        LRows := LRequest.Objects['project_snapshot'].Arrays['sources'];
        LNames := TStringList.Create;
        try
          LSelectedFrames := 0;
          LEstimatedFeatures := 0;
          LBytes := 0;
          LRate := LRows.Objects[0].Integers['sample_rate'];
          LChannels := LRows.Objects[0].Integers['channels'];
          Need(LChannels <= 2, 'Raw Studio supports mono or stereo recordings');
          for LIndex := 0 to LRows.Count - 1 do
          begin
            LRow := LRows.Objects[LIndex];
            Need((LRow.Integers['sample_rate'] = LRate) and
              (LRow.Integers['channels'] = LChannels),
              'Selected recordings require matching rate/channels; prepare conversion separately');
            Inc(LSelectedFrames, LRow.Int64s['end_frame'] - LRow.Int64s['start_frame']);
            Inc(LEstimatedFeatures, (LRow.Int64s['end_frame'] -
              LRow.Int64s['start_frame'] + 1023) div 1024);
            if LNames.IndexOf(LRow.Strings['source_sha256']) < 0 then
            begin
              LNames.Add(LRow.Strings['source_sha256']);
              Inc(LBytes, LRow.Int64s['source_bytes']);
            end;
          end;
          Need((LEstimatedFeatures <= MaximumStudioJobFeatures) and
            (LBytes <= MaximumStudioJobSourceBytes), 'Selection exceeds worker analysis/source budget');
          Need(LRequest.Arrays['source_weights'].Count = LNames.Count,
            'Provide one weight for each unique selected recording');
          for LIndex := 0 to LRequest.Arrays['source_weights'].Count - 1 do
          begin
            Need(LNames.IndexOf(LRequest.Arrays['source_weights'].Objects[LIndex].
              Strings['source_sha256']) >= 0, 'Source weight does not match the selected recordings');
          end;
          Result.Add('source_count', LNames.Count);
          Result.Add('range_count', LRows.Count);
          Result.Add('sample_rate', LRate);
          Result.Add('selected_frames', LSelectedFrames);
          Result.Add('estimated_analyzed_frames', LSelectedFrames);
          Result.Add('estimated_analyzed_features', LEstimatedFeatures);
          Result.Add('selected_seconds', LSelectedFrames / LRate);
          Result.Add('unique_source_bytes_to_verify', LBytes);
          Result.Add('expected_used_status', 'All selected ranges or explicit failure; no silent truncation');
          Result.Add('duration_ms', LRequest.Integers['duration_ms']);
          Result.Add('output_count', LRequest.Arrays['seeds'].Count);
          LOutputFrames := Int64(LRequest.Integers['duration_ms']) * LRate div 1000;
          LOutputGrains := (Max(Int64(0), LOutputFrames - 4096) + 1023) div 1024 + 1;
          if LRequest.Strings['kind'] = 'train_generate' then
          begin
            Need(LOutputGrains <= 6000, 'Output clock exceeds the bounded grain receipt; reduce duration or prepare a lower rate');
            LLimits.Add('grain_rows_per_output', 6000);
          end
          else
          begin
            LLimits.Add('buffered_pcm_frames', 131072);
            LLimits.Add('pull_frames', 65536);
            LLimits.Add('review_excerpt_seconds', 20);
            LLimits.Add('whole_output_retained', False);
          end;
          Result.Add('estimated_grains_per_output', LOutputGrains);
          Result.Add('learning_mode', 'raw_acoustic');
        finally
          LNames.Free;
        end;
      end
      else if (LRequest.Strings['kind'] = 'inspect_source') or
        (LRequest.Strings['kind'] = 'effect_preview') then
      begin
        LTrack := ReadCatalogTrack(ACatalogRoot, LRequest.Strings['source_sha256']);
        try
          Need(LTrack.Strings['partition'] <> 'evaluation',
            'Evaluation recordings are excluded from exploratory inspection');
          Need((LRequest.Int64s['end_frame'] <= LTrack.Int64s['frame_count']) and
            (LRequest.Int64s['end_frame'] - LRequest.Int64s['start_frame'] <=
             Int64(LTrack.Integers['sample_rate']) * 30), 'Inspection exceeds30seconds/sourceextent');
        finally
          LTrack.Free;
        end;
      end
      else if LRequest.Strings['kind'] = 'library_prepare' then
      begin
        LTrack := ValidateStudioLibraryEntries(ACatalogRoot,
          LRequest.Integers['discovery_revision'], LRequest.Arrays['entries']);
        try
          Result.Add('selected_entry_count', LTrack.Integers['selected_entry_count']);
          Result.Add('selected_source_bytes', LTrack.Int64s['selected_source_bytes']);
          Result.Add('discovery_revision', LTrack.Integers['discovery_revision']);
          Result.Add('discovery_index_sha256', LTrack.Strings['discovery_index_sha256']);
          Result.Add('content_validation', LTrack.Strings['content_validation']);
        finally
          LTrack.Free;
        end;
      end
      else if LRequest.Strings['kind'] = 'library_discover' then
      begin
        Result.Add('content_validation', 'metadata_discovery_only');
        LLimits.Add('header_read_bytes_per_file', MaximumLibraryHeaderReadBytes);
        LLimits.Add('entries', 256);
      end;
    except
      Result.Free;
      raise;
    end;
  finally
    LRequest.Free;
  end;
end;

function EnqueueStudioJob(const ACatalogRoot: String;
  const AWrite: TJSONObject): TJSONObject;
var
  LRequest: TJSONObject;
  LExisting: TJSONObject;
  LPrepared: TJSONObject;
  LJob: TJSONObject;
  LNames: TStringList;
  LJobId: String;
  LKind: String;
  LName: String;
  LQueued: Integer;
begin
  Need(AWrite <> nil, 'Job write is required');
  LJobId := Text(AWrite, 'job_id');
  if FileExists(StudioJobDirectory(ACatalogRoot, LJobId) + PathDelim + 'request.json') then
  begin
    LExisting := ReadStudioJobRequest(ACatalogRoot, LJobId);
    try
      LExisting.Delete('request_sha256');
      LExisting.Delete('project_snapshot');
      LExisting.Delete('worker_seconds');
      if LExisting.AsJSON <> AWrite.AsJSON then
      begin
        raise EStudioConflict.Create('Job identifier already binds different settings');
      end;
      Result := ReadStudioJob(ACatalogRoot, LJobId);
      Result.Add('already_queued', True);
      Exit;
    finally
      LExisting.Free;
    end;
  end;
  LPrepared := PrepareStudioJob(ACatalogRoot, AWrite);
  LPrepared.Free;
  LRequest := BuildJobRequest(ACatalogRoot, AWrite);
  LKind := LRequest.Strings['kind'];
  try
    LockJobs(ACatalogRoot);
    try
      if FileExists(StudioJobDirectory(ACatalogRoot, LJobId) + PathDelim + 'request.json') then
      begin
        LExisting := ReadStudioJobRequest(ACatalogRoot, LJobId);
        try
          if LExisting.AsJSON <> LRequest.AsJSON then
          begin
            raise EStudioConflict.Create('Job identifier already binds different settings');
          end;
        finally
          LExisting.Free;
        end;
        Result := ReadStudioJob(ACatalogRoot, LJobId);
        Result.Add('already_queued', True);
        Exit;
      end;
      LNames := JobNames(ACatalogRoot);
      try
        Need(LNames.Count < MaximumStudioJobs, 'Retained job limit reached');
        LQueued := 0;
        for LName in LNames do
        begin
          LExisting := ReadStudioJob(ACatalogRoot, LName);
          try
            if not Terminal(LExisting.Strings['status']) then
            begin
              Inc(LQueued);
            end;
          finally
            LExisting.Free;
          end;
        end;
        Need(LQueued < MaximumStudioQueuedJobs, 'Queued job limit reached');
      finally
        LNames.Free;
      end;
      Need(not DirectoryExists(StudioJobDirectory(ACatalogRoot, LJobId)),
        'Interrupted job creation exists; retain it and choose a new identifier');
      WriteStudioJSONNew(StudioJobDirectory(ACatalogRoot, LJobId) + PathDelim + 'request.json', LRequest);
      LJob := TJSONObject.Create;
      try
        LJob.Add('format', StudioJobFormat);
        LJob.Add('job_id', LJobId);
        LJob.Add('kind', LKind);
        LJob.Add('request_sha256', LRequest.Strings['request_sha256']);
        LJob.Add('event_revision', 1);
        LJob.Add('status', 'queued');
        LJob.Add('stage', 'queued');
        LJob.Add('done', 0);
        LJob.Add('total', 0);
        LJob.Add('cancel_requested', False);
        LJob.Add('results', TJSONObject.Create);
        LJob.Add('error_code', '');
        LJob.Add('error_message', '');
        LJob.Add('project_id', Text(AWrite, 'project_id', False));
        AddState(ACatalogRoot, LJobId, LJob);
      finally
        LJob.Free;
      end;
      Result := ReadStudioJob(ACatalogRoot, LJobId);
      Result.Add('already_queued', False);
    finally
      UnlockJobs(ACatalogRoot);
    end;
  finally
    LRequest.Free;
  end;
end;

function ListStudioJobs(const ACatalogRoot: String): TJSONObject;
var
  LNames: TStringList;
  LName: String;
  LRows: TJSONArray;
  LRow: TJSONObject;
  LCompleted: Integer;
begin
  Result := TJSONObject.Create;
  try
    Result.Add('format', StudioJobsFormat);
    LRows := TJSONArray.Create;
    Result.Add('jobs', LRows);
    LNames := JobNames(ACatalogRoot);
    try
      for LName in LNames do
      begin
        LRow := ReadStudioJob(ACatalogRoot, LName);
        LCompleted := 0;
        if LRow.Objects['results'].Find('completed_render_count') <> nil then
        begin
          LCompleted := LRow.Objects['results'].Integers['completed_render_count'];
        end;
        LRow.Delete('results');
        LRow.Delete('request');
        LRow.Add('completed_render_count', LCompleted);
        LRows.Add(LRow);
      end;
    finally
      LNames.Free;
    end;
    Result.Add('count', LRows.Count);
    Result.Add('maximum_retained', MaximumStudioJobs);
    Result.Add('maximum_queued', MaximumStudioQueuedJobs);
    Result.Add('maximum_worker_seconds', MaximumStudioLibrarySeconds);
    Result.Add('maximum_generation_seconds', MaximumStudioTrainingSeconds);
    Result.Add('maximum_library_refresh_seconds', MaximumStudioLibrarySeconds);
    Result.Add('logical_memory_budget_bytes', MaximumStudioJobMemoryBytes);
  except
    Result.Free;
    raise;
  end;
end;

function StudioJobCancelled(const ACatalogRoot, AJobId: String): Boolean;
begin
  Result := FileExists(StudioJobDirectory(ACatalogRoot, AJobId) + PathDelim + 'cancel.json');
end;

procedure AdvanceStudioJob(const ACatalogRoot, AJobId, AStatus, AStage: String;
  const ADone, ATotal: Int64; const AResults: TJSONObject;
  const AErrorCode: String; const AErrorMessage: String;
  const AProgressUnit: String; const AProgressPass: Integer);
var
  LJob: TJSONObject;
begin
  Need((AStatus = 'running') or Terminal(AStatus), 'Invalid worker job status');
  Need((ADone >= 0) and (ATotal >= ADone) and (Length(AStage) <= 64),
    'Invalid job progress');
  Need((AProgressPass >= 0) and
    ((AProgressUnit = '') or (AProgressUnit = 'bytes') or
     (AProgressUnit = 'observations') or (AProgressUnit = 'frames') or
     (AProgressUnit = 'items')), 'Invalid job progress units');
  LockJobs(ACatalogRoot);
  try
    LJob := ReadStudioJob(ACatalogRoot, AJobId);
    try
      Need(not Terminal(LJob.Strings['status']), 'Terminal job cannot be replaced');
      Need((AStatus <> 'completed') or not LJob.Booleans['cancel_requested'],
        'Cancelled job cannot complete');
      LJob.Integers['event_revision'] := LJob.Integers['event_revision'] + 1;
      Need(LJob.Integers['event_revision'] <= 100000, 'Job event limit reached');
      LJob.Strings['status'] := AStatus;
      LJob.Strings['stage'] := AStage;
      LJob.Int64s['done'] := ADone;
      LJob.Int64s['total'] := ATotal;
      LJob.Strings['progress_unit'] := AProgressUnit;
      LJob.Integers['progress_pass'] := AProgressPass;
      LJob.Strings['error_code'] := AErrorCode;
      LJob.Strings['error_message'] := Copy(AErrorMessage, 1, 256);
      if AResults <> nil then
      begin
        LJob.Delete('results');
        LJob.Add('results', AResults.Clone);
      end;
      AddState(ACatalogRoot, AJobId, LJob);
    finally
      LJob.Free;
    end;
  finally
    UnlockJobs(ACatalogRoot);
  end;
end;

function CancelStudioJob(const ACatalogRoot, AJobId: String): TJSONObject;
var
  LMarker: TJSONObject;
begin
  LockJobs(ACatalogRoot);
  try
    Result := ReadStudioJob(ACatalogRoot, AJobId);
    try
      if Terminal(Result.Strings['status']) then
      begin
        Exit;
      end;
      if not StudioJobCancelled(ACatalogRoot, AJobId) then
      begin
        LMarker := TJSONObject.Create;
        try
          LMarker.Add('job_id', AJobId);
          LMarker.Add('request_sha256', Result.Strings['request_sha256']);
          WriteStudioJSONNew(StudioJobDirectory(ACatalogRoot, AJobId) + PathDelim + 'cancel.json', LMarker);
        finally
          LMarker.Free;
        end;
      end;
      Result.Booleans['cancel_requested'] := True;
      if Result.Strings['status'] = 'queued' then
      begin
        Result.Integers['event_revision'] := Result.Integers['event_revision'] + 1;
        Result.Strings['status'] := 'cancelled';
        Result.Strings['stage'] := 'cancelled_before_start';
        AddState(ACatalogRoot, AJobId, Result);
      end;
    except
      Result.Free;
      raise;
    end;
  finally
    UnlockJobs(ACatalogRoot);
  end;
end;

function ClaimStudioJob(const ACatalogRoot, AJobId: String): TJSONObject;
var
  LState: TJSONObject;
  LOwner: TJSONObject;
  LStream: Boolean;
  LLock: String;
begin
  LockJobs(ACatalogRoot);
  try
    Result := ReadStudioJobRequest(ACatalogRoot, AJobId);
    try
      LStream := Result.Strings['kind'] = 'stream_generate';
      LLock := StudioWorkerLockDirectory(ACatalogRoot, LStream);
      LState := ReadStudioJob(ACatalogRoot, AJobId);
      try
        Need(LState.Strings['status'] = 'queued', 'Only a queued job can be claimed');
      finally
        LState.Free;
      end;
      Need(not StudioJobCancelled(ACatalogRoot, AJobId), 'Job was cancelled before claim');
      Need(CreateDir(LLock),
        'A Studio worker already owns this catalog');
      LOwner := TJSONObject.Create;
      try
        LOwner.Add('process_id', GetProcessID);
        LOwner.Add('job_id', AJobId);
        WriteStudioJSONNew(LLock + PathDelim + 'owner.json', LOwner);
      finally
        LOwner.Free;
      end;
    except
      Result.Free;
      raise;
    end;
  finally
    UnlockJobs(ACatalogRoot);
  end;
  try
    AdvanceStudioJob(ACatalogRoot, AJobId, 'running', 'preflight', 0, 0);
  except
    Result.Free;
    ReleaseStudioWorker(ACatalogRoot, LStream);
    raise;
  end;
end;

function StudioWorkerLockDirectory(const ACatalogRoot: String;
  const AStream: Boolean): String;
begin
  Result := JobsRoot(ACatalogRoot) + PathDelim;
  if AStream then Result := Result + '.stream-worker-lock'
  else Result := Result + '.worker-lock';
end;

procedure ReleaseStudioWorker(const ACatalogRoot: String; const AStream: Boolean);
var
  LLock: String;
begin
  LLock := StudioWorkerLockDirectory(ACatalogRoot, AStream);
  if FileExists(LLock + PathDelim + 'owner.json') then
  begin
    SysUtils.DeleteFile(LLock + PathDelim + 'owner.json');
  end;
  RemoveDir(LLock);
end;

procedure RecoverStudioJobs(const ACatalogRoot: String; const AWorkerStopped: Boolean);
var
  LNames: TStringList;
  LName: String;
  LJob: TJSONObject;
begin
  Need(AWorkerStopped, 'Cannot recover jobs while a worker may be alive');
  if DirectoryExists(JobsRoot(ACatalogRoot) + PathDelim + '.write-lock') then
  begin
    Need(RemoveDir(JobsRoot(ACatalogRoot) + PathDelim + '.write-lock'),
      'Interrupted writer lock is not empty; retain and inspect it');
  end;
  LNames := JobNames(ACatalogRoot);
  try
    for LName in LNames do
    begin
      LJob := ReadStudioJob(ACatalogRoot, LName);
      try
        if LJob.Strings['status'] = 'running' then
        begin
          AdvanceStudioJob(ACatalogRoot, LName, 'failed', 'interrupted', 0, 0,
            nil, 'interrupted', 'Worker stopped before a terminal receipt; retained files are not accepted');
        end;
      finally
        LJob.Free;
      end;
    end;
  finally
    LNames.Free;
  end;
  ReleaseStudioWorker(ACatalogRoot);
  ReleaseStudioWorker(ACatalogRoot, True);
end;

initialization
  InitCriticalSection(GJobsLock);

finalization
  DoneCriticalSection(GJobsLock);

end.
