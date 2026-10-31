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
  fpjson, pythian.tools.json,
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
function ParseStudioJobWrite(const AText: RawByteString): TJSONObject;
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
  const AProgressUnit: String = ''; const AProgressPass: Integer = 0;
  const AWorkflow: TJSONObject = nil);
function StudioJobCancelled(const ACatalogRoot, AJobId: String): Boolean;
procedure ReleaseStudioWorker(const ACatalogRoot: String; const AStream: Boolean = False);
function StudioWorkerLockDirectory(const ACatalogRoot: String;
  const AStream: Boolean = False): String;
procedure RecoverStudioJobs(const ACatalogRoot: String; const AWorkerStopped: Boolean);
function StudioJobDirectory(const ACatalogRoot, AJobId: String): String;
{ Creates only the private parent. The fresh leaf remains absent for importer
  and library staging; it must be outside both durable catalog and library.
  PYTHIAN_STUDIO_STAGE_ROOT optionally selects a short host staging root instead
  of cwd/build/studio-stages. It is host configuration, never a browser path. }
function ReserveStudioJobStage(const ACatalogRoot, ALibraryRoot, AJobId,
  APurpose: String): String;
{ Original bytes, including fpjson UTF8String, without host code-page conversion. }
function StudioTextHash(const AText: RawByteString): String;
function ReadStudioJSON(const APath: String): TJSONObject;
function OpenStudioReadStream(const APath: String): TFileStream;
function OpenStudioInstrumentalAudio(const ACatalogRoot, AJobId: String;
  const APart: Integer; out AHash: String): TFileStream;
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
  pythian.tools.studio.preparation,
  pythian.tools.studio.instrumental.config,
  pythian.tools.annotations.catalog,
  pythian.tools.annotations.sourceguard,
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
  LMaximum: Integer;
begin
  LValue := ARequest.Find('worker_seconds');
  if LValue = nil then
    Exit(MaximumStudioJobSeconds);
  LMaximum := StudioJobRuntimeSeconds(ARequest.Strings['kind']);
  if (ARequest.Strings['kind'] = 'instrumental_generate') and
    (ARequest.Find('project_snapshot') <> nil) and
    (ARequest.Objects['project_snapshot'].Find('playlist') <> nil) then
    LMaximum := MaximumStudioTrainingSeconds;
  Need((LValue.JSONType = jtNumber) and (LValue.AsFloat = LValue.AsInt64) and
    (LValue.AsInt64 >= 1) and
    (LValue.AsInt64 <= LMaximum),
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
  LBase := SysUtils.GetEnvironmentVariable('PYTHIAN_STUDIO_STAGE_ROOT');
  if LBase = '' then
    LBase := 'build' + PathDelim + 'studio-stages';
  LBase := IncludeTrailingPathDelimiter(ExpandFileName(
    IncludeTrailingPathDelimiter(LBase) +
    Copy(StudioTextHash('studio-stage-catalog-v1|' + LCatalog), 1, 16)));
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

function StudioTextHash(const AText: RawByteString): String;
begin
  Result := HashNativeText(AText);
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

function ParseStudioJobWrite(const AText: RawByteString): TJSONObject;
var
  LValue: TJSONData;
begin
  Need((Length(AText) > 0) and (Length(AText) <= 1048576), 'Job JSON exceeds byte bound');
  try
    LValue := ParseNativeJSON(AText, 1048576, 16);
  except
    on LException: EJSON do
    begin
      raise EAudio.Create('Malformed job JSON');
    end;
    on LException: EParserError do
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
  LText: RawByteString;
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

procedure WriteStudioData(const APath: String; const AText: RawByteString;
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
  WriteStudioData(APath, WriteNativeJSON(AObject, 1048576), False);
end;

procedure ReplaceStudioJSON(const APath: String; const AObject: TJSONObject);
begin
  WriteStudioData(APath, WriteNativeJSON(AObject, 1048576), True);
end;

procedure ReplaceStudioBinary(const APath: String; const ABytes: TAudioBytes);
var
  LText: RawByteString;
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

procedure LockJobs(const ACatalogRoot: String;
  const AWaitMilliseconds: QWord = CJobWriterWaitMilliseconds);
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
      Need(GetTickCount64 - LStarted < AWaitMilliseconds,
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

procedure ValidateWeightVector(const AWrite: TJSONObject; const AName: String);
var
  LWeights: TJSONArray;
  LRow: TJSONObject;
  LHash: String;
  LIndex: Integer;
  LPrevious: Integer;
begin
  Need((AWrite.Find(AName) <> nil) and (AWrite.Find(AName).JSONType = jtArray),
    AName + ' must be an array');
  LWeights := AWrite.Arrays[AName];
  Need((LWeights.Count >= 1) and (LWeights.Count <= 32), AName + ' exceeds bounds');
  for LIndex := 0 to LWeights.Count - 1 do
  begin
    Need(LWeights[LIndex].JSONType = jtObject, 'Invalid ' + AName + ' entry');
    LRow := TJSONObject(LWeights[LIndex]);
    Keys(LRow, '|source_sha256|weight|');
    Need((Number(LRow, 'weight') >= 1) and (Number(LRow, 'weight') <= 16),
      AName + ' weight must be 1..16');
    LHash := Text(LRow, 'source_sha256');
    Need(ValidHash(LHash), 'Invalid ' + AName + ' source identity');
    for LPrevious := 0 to LIndex - 1 do
    begin
      Need(LWeights.Objects[LPrevious].Strings['source_sha256'] <> LHash,
        'Duplicate source in ' + AName);
    end;
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
  LPreparation: TJSONObject;
begin
  Need(AWrite <> nil, 'Job write is required');
  Keys(AWrite, '|format|job_id|kind|project_id|project_revision|project_snapshot_sha256|' +
    'duration_ms|seeds|maximum_tokens|model_order|source_weights|generation_weights|resolve_unassigned|' +
    'parent_job_id|retry_of|source_sha256|start_frame|end_frame|effects|tail_seconds|' +
    'preview_job_id|collection_name|title|capture_id|mode|channel|tempo_bpm|' +
    'discovery_revision|entries|reconstruction|preparation|instrumental|');
  Need(Text(AWrite, 'format') = StudioJobWriteFormat, 'Unsupported Studio job format');
  LJobId := Text(AWrite, 'job_id');
  Need(SafeId(LJobId), 'Invalid job identifier');
  LKind := Text(AWrite, 'kind');
  Need((LKind = 'train_generate') or (LKind = 'stream_generate') or (LKind = 'library_refresh') or
    (LKind = 'library_discover') or (LKind = 'library_prepare') or
    (LKind = 'inspect_source') or (LKind = 'effect_preview') or
    (LKind = 'effect_save') or (LKind = 'capture_inspect') or
    (LKind = 'capture_save') or (LKind = 'capture_pitch') or
    (LKind = 'instrumental_generate'), 'Unsupported Studio job kind');
  LRequest := TJSONObject(AWrite.Clone);
  try
    if LKind = 'instrumental_generate' then
    begin
      Keys(AWrite, '|format|job_id|kind|project_id|project_revision|project_snapshot_sha256|' +
        'seeds|instrumental|duration_ms|parent_job_id|retry_of|');
      Need((AWrite.Find('instrumental') <> nil) and
        (AWrite.Find('instrumental').JSONType = jtObject), 'Instrumental settings are required');
      ValidateStudioInstrumentalConfig(AWrite.Objects['instrumental']);
      Need((AWrite.Find('seeds') <> nil) and (AWrite.Find('seeds').JSONType = jtArray) and
        (AWrite.Arrays['seeds'].Count = 1), 'Instrumental experiments require one seed');
      Need((AWrite.Arrays['seeds'][0].JSONType = jtNumber) and
        (AWrite.Arrays['seeds'][0].AsFloat = AWrite.Arrays['seeds'][0].AsInt64) and
        (AWrite.Arrays['seeds'][0].AsInt64 >= 0) and
        (AWrite.Arrays['seeds'][0].AsInt64 <= 2147483000), 'Invalid instrumental seed');
      LProject := ReadStudioProjectRevision(ACatalogRoot, Text(AWrite, 'project_id'),
        Number(AWrite, 'project_revision'));
      try
        Need(LProject.Strings['snapshot_sha256'] = Text(AWrite, 'project_snapshot_sha256'),
          'Project snapshot differs; reopen the saved project');
        Need(LProject.Strings['learning_mode'] = 'instrumental',
          'Save the project with Instrumental experiment selected');
        if LProject.Find('playlist') <> nil then
        begin
          Need(LProject.Objects['playlist'].Arrays['items'].Count > 0,
            'Add music to your playlist before generating');
          Need((Number(AWrite, 'duration_ms') >= 2000) and
            (Number(AWrite, 'duration_ms') <= 30000), 'Experimental music previews require2..30seconds');
        end
        else Need(AWrite.Find('duration_ms') = nil,
          'Duration in seconds belongs to playlist learning; authored experiments use cells');
        LRequest.Add('project_snapshot', LProject.Clone);
      finally
        LProject.Free;
      end;
    end
    else if (LKind = 'train_generate') or (LKind = 'stream_generate') then
    begin
      Keys(AWrite, '|format|job_id|kind|project_id|project_revision|project_snapshot_sha256|' +
        'duration_ms|seeds|maximum_tokens|model_order|source_weights|generation_weights|resolve_unassigned|' +
        'parent_job_id|retry_of|reconstruction|preparation|');
      if AWrite.Find('preparation') <> nil then
      begin
        Need(AWrite.Find('preparation').JSONType = jtObject,
          'Preparation must be a configuration object');
        LPreparation := CanonicalStudioPreparationConfig(AWrite.Objects['preparation']);
        LRequest.Delete('preparation');
        LRequest.Add('preparation', LPreparation);
      end;
      if AWrite.Find('reconstruction') <> nil then
      begin
        Need((Text(AWrite, 'reconstruction') = 'sparse') or
          (Text(AWrite, 'reconstruction') = 'source_successor'), 'Unsupported reconstruction policy');
      end;
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
        ValidateWeightVector(AWrite, 'source_weights');
        if AWrite.Find('generation_weights') <> nil then
        begin
          ValidateWeightVector(AWrite, 'generation_weights');
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
    if (LKind = 'instrumental_generate') and
      (LRequest.Objects['project_snapshot'].Find('playlist') <> nil) then
      LRequest.Integers['worker_seconds'] := MaximumStudioTrainingSeconds;
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
  LPreparation: TJSONObject;
  LRecipe: TJSONObject;
  LGeometry: TJSONObject;
  LGeometries: TJSONArray;
  LFrames: Int64;
  LPreparedFrames: Int64;
  LPreparedBytes: Int64;
  LVisits: Int64;
  LPlan: TStudioPreparationPlan;
  LSelectedSeconds: Double;
  LPreparing: Boolean;
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
      if LRequest.Strings['kind'] = 'instrumental_generate' then
      begin
        Result.Strings['source_validation'] := 'authored_material_no_source_audio';
        Result.Add('learning_mode', 'instrumental');
        Result.Add('material_origin', StudioInstrumentalOrigin);
        Result.Add('output_count', 1);
        Result.Add('cells', LRequest.Objects['instrumental'].Integers['cells']);
        Result.Add('source_count', 0);
        Result.Add('unique_source_bytes_to_verify', 0);
        Result.Add('experimental', True);
        if LRequest.Objects['project_snapshot'].Find('playlist') <> nil then
        begin
          Result.Strings['source_validation'] := 'selected_recordings_pending_content_verification';
          Result.Strings['material_origin'] := StudioPlaylistOrigin;
          Result.Integers['source_count'] :=
            LRequest.Objects['project_snapshot'].Objects['playlist'].Arrays['items'].Count;
          Result.Delete('unique_source_bytes_to_verify');
          Result.Add('requested_duration_ms', LRequest.Int64s['duration_ms']);
          Result.Add('analysis_coverage', 'All included time; bounded representative musical cells enter providers');
        end;
        if LRequest.Objects['project_snapshot'].Find('musical_material') <> nil then
        begin
          LRecipe := LRequest.Objects['project_snapshot'].Objects['musical_material'];
          Result.Strings['material_origin'] := 'Saved operator musical choices with authored accompaniment';
          Result.Strings['source_validation'] := 'saved_symbolic_choices_and_bounded_original_reference';
          Result.Add('musical_material', LRecipe.Clone);
          if LRecipe.Objects['source'].Strings['kind'] <> 'manual' then
          begin
            Result.Integers['source_count'] := 1;
            Result.Add('reference_frames_to_read', LRecipe.Objects['source'].Int64s['end_frame'] -
              LRecipe.Objects['source'].Int64s['start_frame']);
          end;
        end;
      end
      else if (LRequest.Strings['kind'] = 'train_generate') or
        (LRequest.Strings['kind'] = 'stream_generate') then
      begin
        LRows := LRequest.Objects['project_snapshot'].Arrays['sources'];
        LNames := TStringList.Create;
        try
          LSelectedFrames := 0;
          LEstimatedFeatures := 0;
          LBytes := 0;
          LPreparing := LRequest.Find('preparation') <> nil;
          LPreparedFrames := 0;
          LPreparedBytes := 0;
          LVisits := 0;
          LSelectedSeconds := 0;
          LGeometries := nil;
          if LPreparing then
          begin
            LPreparation := LRequest.Objects['preparation'];
            LRate := LPreparation.Integers['sample_rate'];
            LChannels := LPreparation.Integers['channels'];
            LGeometries := TJSONArray.Create;
            Result.Add('prepared_ranges', LGeometries);
            Result.Add('preparation', LPreparation.Clone);
          end
          else
          begin
            LRate := LRows.Objects[0].Integers['sample_rate'];
            LChannels := LRows.Objects[0].Integers['channels'];
          end;
          Need(LChannels <= 2, 'Raw Studio supports mono or stereo recordings');
          for LIndex := 0 to LRows.Count - 1 do
          begin
            LRow := LRows.Objects[LIndex];
            Need((LRow.Integers['sample_rate'] > 0) and
              (LRow.Integers['channels'] in [1, 2]) and
              (LRow.Int64s['start_frame'] >= 0) and
              (LRow.Int64s['end_frame'] > LRow.Int64s['start_frame']) and
              (LRow.Int64s['end_frame'] <= LRow.Int64s['frame_count']),
              'Selected source geometry is unsupported');
            if not LPreparing then
            begin
              Need((LRow.Integers['sample_rate'] = LRate) and
                (LRow.Integers['channels'] = LChannels),
                'Selected recordings require matching rate/channels; prepare conversion separately');
            end;
            LFrames := LRow.Int64s['end_frame'] - LRow.Int64s['start_frame'];
            Inc(LSelectedFrames, LFrames);
            LSelectedSeconds := LSelectedSeconds + LFrames / LRow.Integers['sample_rate'];
            if LPreparing then
            begin
              LPlan := PlanStudioPreparation(LFrames, LRow.Integers['sample_rate'],
                LRow.Integers['channels'], LPreparation);
              LFrames := LPlan.OutputFrames;
              Need(LPreparedBytes <= MaximumStudioPreparedBytes - LPlan.OutputBytesUpperBound,
                'Prepared ranges exceed storage budget');
              Inc(LPreparedBytes, LPlan.OutputBytesUpperBound);
              Need(LVisits <= MaximumStudioPreparationVisits - LPlan.VisitsUpperBound,
                'Preparation exceeds work budget');
              Inc(LVisits, LPlan.VisitsUpperBound);
              LRecipe := BuildStudioPreparationRecipe(LRow, LPreparation);
              try
                LGeometry := TJSONObject.Create;
                LGeometries.Add(LGeometry);
                LGeometry.Add('source_sha256', LRow.Strings['source_sha256']);
                LGeometry.Add('original_start_frame', LRow.Int64s['start_frame']);
                LGeometry.Add('original_end_frame', LRow.Int64s['end_frame']);
                LGeometry.Add('original_sample_rate', LRow.Integers['sample_rate']);
                LGeometry.Add('original_channels', LRow.Integers['channels']);
                LGeometry.Add('prepared_frames', LFrames);
                LGeometry.Add('prepared_sample_rate', LRate);
                LGeometry.Add('prepared_channels', LChannels);
                LGeometry.Add('mapping', 'range-relative rational; output count ceiling');
                LGeometry.Add('recipe_sha256', StudioTextHash(LRecipe.AsJSON));
              finally
                LRecipe.Free;
              end;
            end;
            Inc(LPreparedFrames, LFrames);
            Inc(LEstimatedFeatures, (LFrames + 1023) div 1024);
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
          if LRequest.Find('generation_weights') <> nil then
          begin
            Need(LRequest.Arrays['generation_weights'].Count = LNames.Count,
              'Provide one generation preference for each selected recording');
            for LIndex := 0 to LRequest.Arrays['generation_weights'].Count - 1 do
            begin
              Need(LNames.IndexOf(LRequest.Arrays['generation_weights'].Objects[LIndex].
                Strings['source_sha256']) >= 0,
                'Generation preference does not match the selected recordings');
            end;
            Result.Add('generation_weights', LRequest.Arrays['generation_weights'].Clone);
            Result.Add('generation_preference_policy', 'explicit');
          end
          else
          begin
            Result.Add('generation_weights', LRequest.Arrays['source_weights'].Clone);
            Result.Add('generation_preference_policy', 'inherited_training_weights');
          end;
          Result.Add('training_weights', LRequest.Arrays['source_weights'].Clone);
          Result.Add('generation_preference_note',
            'Preferences affect eligible candidate choices, not learning or guaranteed recording shares.');
          Result.Add('source_count', LNames.Count);
          Result.Add('range_count', LRows.Count);
          Result.Add('sample_rate', LRate);
          Result.Add('selected_frames', LSelectedFrames);
          Result.Add('estimated_analyzed_frames', LPreparedFrames);
          Result.Add('estimated_analyzed_features', LEstimatedFeatures);
          if LPreparing then
            Result.Add('selected_seconds', LSelectedSeconds)
          else
            Result.Add('selected_seconds', LSelectedFrames / LRate);
          if LPreparing then
          begin
            Result.Add('prepared_frames', LPreparedFrames);
            Result.Add('prepared_seconds', LPreparedFrames / LRate);
            Result.Add('prepared_channels', LChannels);
            Result.Add('prepared_bytes_upper_bound', LPreparedBytes);
            Result.Add('preparation_visits_upper_bound', LVisits);
            LLimits.Add('prepared_bytes', MaximumStudioPreparedBytes);
            LLimits.Add('preparation_visits', MaximumStudioPreparationVisits);
          end;
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
          Result.Add('reconstruction', LRequest.Get('reconstruction', 'sparse'));
          if LRequest.Get('reconstruction', 'sparse') = 'source_successor' then
          begin
            LLimits.Add('successor_index_bytes', LEstimatedFeatures * 16);
            LLimits.Add('successor_index_budget_bytes', MaximumStudioJobMemoryBytes div 4);
            LLimits.Add('successor_observations_upper_bound', LEstimatedFeatures);
            Result.Add('reconstruction_note', 'Experimental source continuity uses complete verified feature journals. A reused model requires its retained journals; a cold job prepares its own. No note or style learning is implied.');
          end;
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

function OpenStudioInstrumentalAudio(const ACatalogRoot, AJobId: String;
  const APart: Integer; out AHash: String): TFileStream;
var LJob, LAsset: TJSONObject; LPath: String;
begin
  Need((APart >= 0) and (APart <= 7), 'Choose a part, mix or original reference');
  LJob := ReadStudioJob(ACatalogRoot, AJobId);
  try
    Need((LJob.Strings['kind'] = 'instrumental_generate') and
      (LJob.Strings['status'] = 'completed'), 'Select a completed instrumental job');
    if APart = 7 then
    begin
      Need(LJob.Objects['results'].Find('original_reference') <> nil,
        'This instrumental job has no original reference');
      LAsset := LJob.Objects['results'].Objects['original_reference'];
    end
    else if APart = 6 then LAsset := LJob.Objects['results'].Arrays['outputs'].Objects[0]
    else LAsset := LJob.Objects['results'].Arrays['parts'].Objects[APart];
    LPath := StudioJobDirectory(ACatalogRoot, AJobId) + PathDelim +
      'part-' + IntToStr(APart) + '.wav';
    AHash := LAsset.Strings['wav_sha256'];
    VerifyGuardedSource(LPath, AHash, LAsset.Int64s['wav_bytes']);
    Result := OpenStudioReadStream(LPath);
  finally
    LJob.Free;
  end;
end;

function EnqueueStudioJob(const ACatalogRoot: String;
  const AWrite: TJSONObject): TJSONObject;
var
  LRequest: TJSONObject;
  LExisting: TJSONObject;
  LPrepared: TJSONObject;
  LCanonicalWrite: TJSONObject;
  LCanonicalPreparation: TJSONObject;
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
      LCanonicalWrite := TJSONObject(AWrite.Clone);
      try
        if LCanonicalWrite.Find('preparation') <> nil then
        begin
          Need(LCanonicalWrite.Find('preparation').JSONType = jtObject,
            'Preparation must be a configuration object');
          LCanonicalPreparation := CanonicalStudioPreparationConfig(LCanonicalWrite.Objects['preparation']);
          LCanonicalWrite.Delete('preparation');
          LCanonicalWrite.Add('preparation', LCanonicalPreparation);
        end;
        if LExisting.AsJSON <> LCanonicalWrite.AsJSON then
        begin
          raise EStudioConflict.Create('Job identifier already binds different settings');
        end;
      finally
        LCanonicalWrite.Free;
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
  const AProgressUnit: String; const AProgressPass: Integer;
  const AWorkflow: TJSONObject);
var
  LJob: TJSONObject;
begin
  Need((AStatus = 'running') or Terminal(AStatus), 'Invalid worker job status');
  { Big Boss: total zero retains the primary progress contract's unknown total;
    positive activity is real work, never an implied completion percentage. }
  Need((ADone >= 0) and (ATotal >= 0) and
    ((ATotal = 0) or (ADone <= ATotal)) and (Length(AStage) <= 64),
    'Invalid job progress');
  Need((AProgressPass >= 0) and
    ((AProgressUnit = '') or (AProgressUnit = 'bytes') or
     (AProgressUnit = 'observations') or (AProgressUnit = 'frames') or
     (AProgressUnit = 'items') or (AProgressUnit = 'milliseconds')),
    'Invalid job progress units');
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
      if AWorkflow <> nil then
      begin
        LJob.Delete('workflow');
        LJob.Add('workflow', AWorkflow.Clone);
      end;
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
  { Big Boss: a finite native progress commit can outlive the ordinary two-second
    writer wait. Cancel gets ten seconds, still inside the app's fifteen-second
    request bound. Do not remove another writer's lock or bypass its journal. }
  LockJobs(ACatalogRoot, 10000);
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
