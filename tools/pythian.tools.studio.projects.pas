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
unit pythian.tools.studio.projects;

{$mode delphi}
{$H+}

interface

uses
  fpjson,
  pythian.audio;

const
  StudioSourcesFormat = 'pythian.studio.sources.v1';
  StudioProjectsFormat = 'pythian.studio.projects.v1';
  StudioProjectFormat = 'pythian.studio.project.v1';
  StudioProjectWriteFormat = 'pythian.studio.project.write.v1';
  StudioSourceValidation = 'catalog_snapshot_pending_training_verification';
  MaximumStudioProjects = 256;
  MaximumStudioSources = 32;
  MaximumStudioRevision = 100000;
  MaximumStudioDocumentBytes = 1048576;

type
  EStudioConflict = class(EAudio);

{ Owned JSON results. Draft admission checks catalog metadata and WAV headers,
  never hashes/decodes source payloads or certifies musical source truth.
  Input objects are borrowed and remain unchanged. All exact times are original
  half-open source frames. No reference/model training occurs here. }
function ListStudioSources(const ACatalogRoot: String): TJSONObject;
function ListStudioProjects(const ACatalogRoot: String): TJSONObject;
function ReadStudioProject(const ACatalogRoot, AProjectId: String): TJSONObject;
{ Bounds byte length/nesting before the strict parser runs. }
function ParseStudioProjectWrite(const AText: String): TJSONObject;
{ expected_revision=0 creates a project. An identical retry against the directly
  preceding revision reconciles without another write. Other stale writes fail.
  Immutable accepted revisions are never replaced. The returned already_saved
  transport flag is outside the stored snapshot and its digest. A crash-leftover
  studio/projects/.write-lock refuses further writes; an operator must retain
  that evidence and verify no writer remains before explicitly recovering it. }
function SaveStudioProject(const ACatalogRoot: String;
  const AWrite: TJSONObject): TJSONObject;

implementation

uses
  Classes,
  SysUtils,
  jsonparser,
  jsonscanner,
  pythian.corpus,
  pythian.corpus.intake,
  pythian.hash,
  pythian.wave.read,
  pythian.tools.annotations.catalog
  {$IFDEF MSWINDOWS}, Windows{$ENDIF};

const
  CSourceFields = 'source_sha256,title,original_name,source_group,partition,' +
    'clock_id,license,provenance,sample_rate,channels,frame_count,source_bytes,' +
    'metadata_sha256,selection_status,source_validation,song_boundaries,exposure';
  CSelectedFields = CSourceFields + ',selection,start_frame,end_frame,usage_status';
  CSnapshotFields = 'format,project_id,revision,name,style_intent,learning_mode,' +
    'status,training_status,model_available,used_sources,sources,snapshot_sha256';
  CMaximumSourceBytes: Int64 = 17179869184;

var
  GStudioLock: TRTLCriticalSection;

procedure Need(const ACondition: Boolean; const AMessage: String);
begin
  if not ACondition then
  begin
    raise EAudio.Create(AMessage);
  end;
end;

procedure BoundJson(const AData: TJSONData; const ADepth: Integer;
  var ACount: Integer);
var
  LIndex: Integer;
begin
  Need((AData <> nil) and (ADepth <= 8), 'Studio JSON nesting exceeds its bound');
  Inc(ACount);
  Need(ACount <= 4096, 'Studio JSON value count exceeds its bound');
  if AData.JSONType = jtObject then
  begin
    for LIndex := 0 to TJSONObject(AData).Count - 1 do
    begin
      BoundJson(TJSONObject(AData).Items[LIndex], ADepth + 1, ACount);
    end;
  end
  else if AData.JSONType = jtArray then
  begin
    for LIndex := 0 to TJSONArray(AData).Count - 1 do
    begin
      BoundJson(TJSONArray(AData).Items[LIndex], ADepth + 1, ACount);
    end;
  end;
end;

procedure BoundText(const AText: String);
var
  LIndex: Integer;
  LDepth: Integer;
  LCount: Integer;
  LQuoted: Boolean;
  LEscaped: Boolean;
begin
  Need((Length(AText) > 0) and (Length(AText) <= MaximumStudioDocumentBytes),
    'Studio JSON exceeds its byte bound');
  LDepth := 0;
  LCount := 0;
  LQuoted := False;
  LEscaped := False;
  for LIndex := 1 to Length(AText) do
  begin
    if LQuoted then
    begin
      if LEscaped then
      begin
        LEscaped := False;
      end
      else if AText[LIndex] = '\' then
      begin
        LEscaped := True;
      end
      else if AText[LIndex] = '"' then
      begin
        LQuoted := False;
      end;
    end
    else if AText[LIndex] = '"' then
    begin
      LQuoted := True;
    end
    else if AText[LIndex] in ['{', '['] then
    begin
      Inc(LDepth);
      Inc(LCount);
      Need((LDepth <= 8) and (LCount <= 4096), 'Studio JSON structure exceeds its bound');
    end
    else if AText[LIndex] in ['}', ']'] then
    begin
      Dec(LDepth);
      Need(LDepth >= 0, 'Studio JSON structure is invalid');
    end;
  end;
  Need((LDepth = 0) and not LQuoted, 'Studio JSON structure is incomplete');
end;

function ParseStudioProjectWrite(const AText: String): TJSONObject;
var
  LParser: TJSONParser;
  LData: TJSONData;
  LCount: Integer;
begin
  Result := nil;
  BoundText(AText);
  LParser := TJSONParser.Create(AText, [joUTF8, joStrict]);
  try
    try
      LData := LParser.Parse;
    except
      on LException: EParserError do
      begin
        raise EAudio.Create('Studio JSON syntax is invalid');
      end;
      on LException: EJSON do
      begin
        raise EAudio.Create('Studio JSON syntax is invalid or contains duplicate fields');
      end;
    end;
    try
      Need((LData <> nil) and (LData.JSONType = jtObject),
        'Studio JSON must be an object');
      LCount := 0;
      BoundJson(LData, 1, LCount);
      Result := TJSONObject(LData);
      LData := nil;
    finally
      LData.Free;
    end;
  finally
    LParser.Free;
  end;
end;

function ValidId(const AValue: String): Boolean;
var
  LIndex: Integer;
  LUpper: String;
begin
  Result := (Length(AValue) >= 1) and (Length(AValue) <= 64);
  for LIndex := 1 to Length(AValue) do
  begin
    if not (AValue[LIndex] in ['a'..'z', 'A'..'Z', '0'..'9', '_', '-']) then
    begin
      Result := False;
    end;
  end;
  LUpper := UpperCase(AValue);
  if (LUpper = 'CON') or (LUpper = 'PRN') or (LUpper = 'AUX') or
    (LUpper = 'NUL') or ((Length(LUpper) = 4) and
    ((Copy(LUpper, 1, 3) = 'COM') or (Copy(LUpper, 1, 3) = 'LPT')) and
    (LUpper[4] in ['1'..'9'])) then
  begin
    Result := False;
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
      Result := False;
    end;
  end;
end;

procedure Fields(const AObject: TJSONObject; const AAllowed: String);
var
  LNames: TStringList;
  LIndex: Integer;
  LPrior: Integer;
begin
  Need(AObject <> nil, 'Studio object is missing');
  LNames := TStringList.Create;
  try
    LNames.StrictDelimiter := True;
    LNames.Delimiter := ',';
    LNames.DelimitedText := AAllowed;
    Need(AObject.Count = LNames.Count, 'Studio object has missing or unsupported fields');
    for LIndex := 0 to AObject.Count - 1 do
    begin
      Need(LNames.IndexOf(AObject.Names[LIndex]) >= 0, 'Studio field is unsupported');
      for LPrior := 0 to LIndex - 1 do
      begin
        Need(AObject.Names[LPrior] <> AObject.Names[LIndex], 'Studio field is duplicated');
      end;
    end;
  finally
    LNames.Free;
  end;
end;

function TextField(const AObject: TJSONObject; const AName: String;
  const AMinimum, AMaximum: Integer): String;
var
  LValue: TJSONData;
begin
  LValue := AObject.Find(AName);
  Need((LValue <> nil) and (LValue.JSONType = jtString), 'Studio text field is missing');
  Result := LValue.AsString;
  Need((Length(Result) >= AMinimum) and (Length(Result) <= AMaximum),
    'Studio text field exceeds its bounds');
  ValidateCorpusText(UTF8String(Result));
end;

function IntField(const AObject: TJSONObject; const AName: String): Int64;
var
  LValue: TJSONData;
  LText: String;
  LIndex: Integer;
begin
  LValue := AObject.Find(AName);
  Need((LValue <> nil) and (LValue.JSONType = jtNumber), 'Studio integer field is missing');
  LText := LValue.AsJSON;
  Need(Length(LText) > 0, 'Studio integer is empty');
  for LIndex := 1 to Length(LText) do
  begin
    Need((LText[LIndex] in ['0'..'9']) or ((LIndex = 1) and (LText[LIndex] = '-')),
      'Studio integer must use exact decimal notation');
  end;
  Need(TryStrToInt64(LText, Result), 'Studio integer exceeds its bounds');
  Need((Result >= -MaximumIntakeFrame) and (Result <= MaximumIntakeFrame),
    'Studio integer exceeds the exact source clock');
end;

function ObjectAt(const AArray: TJSONArray; const AIndex: Integer): TJSONObject;
begin
  Need(AArray.Items[AIndex].JSONType = jtObject, 'Studio source must be an object');
  Result := TJSONObject(AArray.Items[AIndex]);
end;

function ArrayField(const AObject: TJSONObject; const AName: String): TJSONArray;
var
  LValue: TJSONData;
begin
  LValue := AObject.Find(AName);
  Need((LValue <> nil) and (LValue.JSONType = jtArray), 'Studio array field is missing');
  Result := TJSONArray(LValue);
end;

function JsonHash(const AObject: TJSONObject): String;
var
  LStream: TStringStream;
begin
  LStream := TStringStream.Create(AObject.AsJSON);
  try
    Result := Sha256Stream(LStream, LStream.Size);
  finally
    LStream.Free;
  end;
end;

procedure CheckPath(const APath: String);
var
  LPath: String;
  LParent: String;
  LAttributes: Longint;
  {$IFDEF MSWINDOWS}
  LWindowsAttributes: DWORD;
  {$ENDIF}
begin
  LPath := ExcludeTrailingPathDelimiter(ExpandFileName(APath));
  repeat
    LAttributes := FileGetAttr(LPath);
    if LAttributes >= 0 then
    begin
      {$IFNDEF MSWINDOWS}
      Need((LAttributes and faSymLink) = 0, 'Studio path contains a symbolic link');
      {$ENDIF}
      {$IFDEF MSWINDOWS}
      LWindowsAttributes := GetFileAttributes(PChar(LPath));
      Need((LWindowsAttributes <> INVALID_FILE_ATTRIBUTES) and
        ((LWindowsAttributes and FILE_ATTRIBUTE_REPARSE_POINT) = 0),
        'Studio path contains a reparse point');
      {$ENDIF}
    end;
    LParent := ExcludeTrailingPathDelimiter(ExtractFileDir(LPath));
    if (LParent = '') or (LParent = LPath) then
    begin
      Break;
    end;
    LPath := LParent;
  until False;
end;

function CatalogPath(const ACatalogRoot: String): String;
begin
  Result := IncludeTrailingPathDelimiter(ExpandFileName(ACatalogRoot));
  CheckPath(Result);
  Need(DirectoryExists(Result), 'Studio catalog is unavailable');
  CheckPath(Result + 'tracks');
  CheckPath(Result + 'sources');
end;

function ProjectsPath(const ACatalogRoot: String): String;
begin
  Result := CatalogPath(ACatalogRoot) + 'studio' + PathDelim + 'projects';
  CheckPath(Result);
end;

function ProjectPath(const ACatalogRoot, AId: String): String;
begin
  Need(ValidId(AId), 'Studio project ID is invalid');
  Result := ProjectsPath(ACatalogRoot) + PathDelim + AId;
  CheckPath(Result);
end;

function ReadObject(const APath: String): TJSONObject;
var
  LStream: TFileStream;
  LText: String;
begin
  Result := nil;
  CheckPath(APath);
  try
    LStream := TFileStream.Create(APath, fmOpenRead or fmShareDenyWrite);
  except
    raise EAudio.Create('Studio document is unavailable');
  end;
  try
    Need((LStream.Size > 0) and (LStream.Size <= MaximumStudioDocumentBytes),
      'Studio document exceeds its byte bound');
    SetLength(LText, Integer(LStream.Size));
    LStream.ReadBuffer(LText[1], Length(LText));
    Result := ParseStudioProjectWrite(LText);
  finally
    LStream.Free;
  end;
end;

function ReadSource(const ACatalogRoot, AHash: String): TJSONObject;
var
  LRoot: String;
  LTrack: TJSONObject;
  LStream: TFileStream;
  LWave: TWaveFrameReader;
  LPartition: String;
begin
  Result := nil;
  Need(ValidHash(AHash), 'Studio source hash is invalid');
  LRoot := CatalogPath(ACatalogRoot);
  CheckPath(LRoot + 'tracks' + PathDelim + AHash + '.json');
  LTrack := ReadObject(LRoot + 'tracks' + PathDelim + AHash + '.json');
  try
    Fields(LTrack, 'version,source_sha256,source_bytes,sample_rate,channels,' +
      'bits_per_sample,frame_count,original_name,title,source_group,clock_id,' +
      'partition,provenance,license,asset');
    Need((IntField(LTrack, 'version') = 1) and
      (TextField(LTrack, 'source_sha256', 64, 64) = AHash) and
      (TextField(LTrack, 'asset', 1, 128) = 'sources/' + AHash + '.wav'),
      'Studio catalog source identity differs');
    Need((IntField(LTrack, 'source_bytes') >= 44) and
      (IntField(LTrack, 'source_bytes') <= CMaximumSourceBytes) and
      (IntField(LTrack, 'sample_rate') > 0) and (IntField(LTrack, 'channels') > 0) and
      (IntField(LTrack, 'frame_count') > 0), 'Studio source geometry is invalid');
    LPartition := TextField(LTrack, 'partition', 1, 16);
    Need((LPartition = 'training') or (LPartition = 'development') or
      (LPartition = 'evaluation') or (LPartition = 'unassigned'),
      'Studio source partition is invalid');
    Need(TextField(LTrack, 'source_group', 1, 128) <> '', 'Studio source group is missing');
    CheckPath(LRoot + 'sources' + PathDelim + AHash + '.wav');
    try
      LStream := TFileStream.Create(LRoot + 'sources' + PathDelim + AHash + '.wav',
        fmOpenRead or fmShareDenyWrite);
    except
      raise EAudio.Create('Studio source audio is unavailable');
    end;
    try
      Need(LStream.Size = IntField(LTrack, 'source_bytes'),
        'Studio source byte length differs from its catalog');
      LWave := TWaveFrameReader.Create(LStream);
      try
        Need((LWave.SampleRate = IntField(LTrack, 'sample_rate')) and
          (LWave.Channels = IntField(LTrack, 'channels')) and
          (LWave.FrameCount = IntField(LTrack, 'frame_count')) and
          (LWave.BitsPerSample = IntField(LTrack, 'bits_per_sample')),
          'Studio source header geometry differs from its catalog');
      finally
        LWave.Free;
      end;
    finally
      LStream.Free;
    end;
    Result := TJSONObject.Create;
    try
      Result.Add('source_sha256', AHash);
      Result.Add('title', TextField(LTrack, 'title', 1, 256));
      Result.Add('original_name', TextField(LTrack, 'original_name', 1, 256));
      Result.Add('source_group', TextField(LTrack, 'source_group', 1, 128));
      Result.Add('partition', LPartition);
      Result.Add('clock_id', TextField(LTrack, 'clock_id', 0, 128));
      Result.Add('license', TextField(LTrack, 'license', 1, 256));
      Result.Add('provenance', TextField(LTrack, 'provenance', 1, 1024));
      Result.Add('sample_rate', IntField(LTrack, 'sample_rate'));
      Result.Add('channels', IntField(LTrack, 'channels'));
      Result.Add('frame_count', IntField(LTrack, 'frame_count'));
      Result.Add('source_bytes', IntField(LTrack, 'source_bytes'));
      Result.Add('metadata_sha256', JsonHash(LTrack));
      if LPartition = 'evaluation' then
      begin
        Result.Add('selection_status', 'evaluation_only');
      end
      else if LPartition = 'unassigned' then
      begin
        Result.Add('selection_status', 'pending_partition');
      end
      else
      begin
        Result.Add('selection_status', 'available_metadata');
      end;
      Result.Add('source_validation', StudioSourceValidation);
      Result.Add('song_boundaries', 'unknown');
      Result.Add('exposure', 'catalog_partition_only');
    except
      Result.Free;
      Result := nil;
      raise;
    end;
  finally
    LTrack.Free;
  end;
end;

function ListStudioSources(const ACatalogRoot: String): TJSONObject;
var
  LDirectory: String;
  LFound: TSearchRec;
  LCode: Integer;
  LNames: TStringList;
  LRows: TJSONArray;
  LIndex: Integer;
  LHash: String;
begin
  LDirectory := CatalogPath(ACatalogRoot) + 'tracks';
  Need(DirectoryExists(LDirectory), 'Studio catalog tracks are unavailable');
  LNames := TStringList.Create;
  try
    LCode := FindFirst(IncludeTrailingPathDelimiter(LDirectory) + '*.json',
      faAnyFile, LFound);
    if LCode = 0 then
    begin
      try
        while LCode = 0 do
        begin
          LHash := Copy(LFound.Name, 1, 64);
          Need((LFound.Attr and faDirectory = 0) and ValidHash(LHash) and
            (LFound.Name = LHash + '.json'), 'Studio source namespace is invalid');
          Need(LNames.Count < 4096, 'Studio source listing exceeds the catalog limit');
          LNames.Add(LHash);
          LCode := FindNext(LFound);
        end;
      finally
        SysUtils.FindClose(LFound);
      end;
    end;
    LNames.Sort;
    Result := TJSONObject.Create;
    try
      Result.Add('format', StudioSourcesFormat);
      LRows := TJSONArray.Create;
      Result.Add('sources', LRows);
      for LIndex := 0 to LNames.Count - 1 do
      begin
        LRows.Add(ReadSource(ACatalogRoot, LNames[LIndex]));
      end;
      Result.Add('count', LRows.Count);
      Result.Add('maximum_sources', 4096);
      Result.Add('maximum_selected_sources', MaximumStudioSources);
    except
      Result.Free;
      raise;
    end;
  finally
    LNames.Free;
  end;
end;

function RevisionName(const ARevision: Integer): String;
begin
  Result := Format('%.8d.json', [ARevision]);
end;

function LatestRevision(const ADirectory: String): Integer;
var
  LFound: TSearchRec;
  LCode: Integer;
  LRevision: Integer;
  LCount: Integer;
begin
  Result := 0;
  LCount := 0;
  if not DirectoryExists(ADirectory) then
  begin
    Exit;
  end;
  LCode := FindFirst(IncludeTrailingPathDelimiter(ADirectory) + '*.json',
    faAnyFile, LFound);
  if LCode <> 0 then
  begin
    Exit;
  end;
  try
    while LCode = 0 do
    begin
      Need((LFound.Attr and faDirectory = 0) and (Length(LFound.Name) = 13) and
        TryStrToInt(Copy(LFound.Name, 1, 8), LRevision) and (LRevision >= 1) and
        (LRevision <= MaximumStudioRevision) and
        (LFound.Name = RevisionName(LRevision)), 'Studio revision namespace is invalid');
      Inc(LCount);
      Need(LCount <= MaximumStudioRevision, 'Studio revision count exceeds its bound');
      if LRevision > Result then
      begin
        Result := LRevision;
      end;
      LCode := FindNext(LFound);
    end;
  finally
    SysUtils.FindClose(LFound);
  end;
  Need(LCount = Result, 'Studio revision history has a gap');
end;

procedure ValidateSnapshot(const AProject: TJSONObject; const AId: String;
  const ARevision: Integer);
var
  LCopy: TJSONObject;
  LHash: String;
  LSources: TJSONArray;
  LSource: TJSONObject;
  LIndex: Integer;
  LPrior: Integer;
  LUsage: String;
  LValue: TJSONData;
begin
  Fields(AProject, CSnapshotFields);
  Need((TextField(AProject, 'format', 1, 64) = StudioProjectFormat) and
    (TextField(AProject, 'project_id', 1, 64) = AId) and
    (IntField(AProject, 'revision') = ARevision), 'Studio snapshot identity differs');
  TextField(AProject, 'name', 1, 128);
  TextField(AProject, 'style_intent', 0, 2048);
  LUsage := TextField(AProject, 'learning_mode', 1, 32);
  Need((LUsage = 'raw_acoustic') or (LUsage = 'reference_events') or
    (LUsage = 'inferred_events'), 'Studio learning mode is unsupported');
  Need((TextField(AProject, 'status', 1, 32) = 'draft') and
    (TextField(AProject, 'training_status', 1, 32) = 'not_started') and
    (ArrayField(AProject, 'used_sources').Count = 0), 'Studio draft implies used training');
  LValue := AProject.Find('model_available');
  Need((LValue <> nil) and (LValue.JSONType = jtBoolean) and not LValue.AsBoolean,
    'Studio draft implies an available model');
  LSources := ArrayField(AProject, 'sources');
  Need((LSources.Count >= 1) and (LSources.Count <= MaximumStudioSources),
    'Studio selected source count exceeds its bounds');
  for LIndex := 0 to LSources.Count - 1 do
  begin
    LSource := ObjectAt(LSources, LIndex);
    Fields(LSource, CSelectedFields);
    Need(ValidHash(TextField(LSource, 'source_sha256', 64, 64)) and
      ValidHash(TextField(LSource, 'metadata_sha256', 64, 64)),
      'Studio snapshot source identity is invalid');
    Need((IntField(LSource, 'start_frame') >= 0) and
      (IntField(LSource, 'end_frame') > IntField(LSource, 'start_frame')) and
      (IntField(LSource, 'end_frame') <= IntField(LSource, 'frame_count')),
      'Studio snapshot source range is invalid');
    LUsage := TextField(LSource, 'selection', 1, 16);
    Need((LUsage = 'full') or (LUsage = 'range'), 'Studio snapshot selection is invalid');
    if LUsage = 'full' then
    begin
      Need((IntField(LSource, 'start_frame') = 0) and
        (IntField(LSource, 'end_frame') = IntField(LSource, 'frame_count')),
        'Studio full selection differs from its original clock');
    end;
    Need((TextField(LSource, 'source_validation', 1, 128) = StudioSourceValidation) and
      (TextField(LSource, 'song_boundaries', 1, 32) = 'unknown') and
      (TextField(LSource, 'exposure', 1, 32) = 'catalog_partition_only'),
      'Studio draft overstates source qualification');
    if TextField(LSource, 'partition', 1, 16) = 'evaluation' then
    begin
      LUsage := 'evaluation_only';
    end
    else
    begin
      LUsage := 'selected_not_used';
    end;
    Need(TextField(LSource, 'usage_status', 1, 32) = LUsage,
      'Studio draft source use differs from its partition');
    for LPrior := 0 to LIndex - 1 do
    begin
      Need(ObjectAt(LSources, LPrior).Strings['source_sha256'] <>
        LSource.Strings['source_sha256'], 'Studio snapshot contains duplicate sources');
    end;
  end;
  LHash := TextField(AProject, 'snapshot_sha256', 64, 64);
  Need(ValidHash(LHash), 'Studio snapshot digest is invalid');
  LCopy := TJSONObject(AProject.Clone);
  try
    LCopy.Delete('snapshot_sha256');
    Need(JsonHash(LCopy) = LHash, 'Studio snapshot digest differs');
  finally
    LCopy.Free;
  end;
end;

function ReadProjectLocked(const ACatalogRoot, AId: String): TJSONObject;
var
  LDirectory: String;
  LRevision: Integer;
begin
  LDirectory := ProjectPath(ACatalogRoot, AId);
  LRevision := LatestRevision(LDirectory);
  Need(LRevision > 0, 'Studio project does not exist');
  Result := ReadObject(IncludeTrailingPathDelimiter(LDirectory) + RevisionName(LRevision));
  try
    ValidateSnapshot(Result, AId, LRevision);
  except
    Result.Free;
    raise;
  end;
end;

function ReadStudioProject(const ACatalogRoot, AProjectId: String): TJSONObject;
begin
  EnterCriticalSection(GStudioLock);
  try
    Result := ReadProjectLocked(ACatalogRoot, AProjectId);
  finally
    LeaveCriticalSection(GStudioLock);
  end;
end;

function ListStudioProjects(const ACatalogRoot: String): TJSONObject;
var
  LDirectory: String;
  LFound: TSearchRec;
  LCode: Integer;
  LNames: TStringList;
  LRows: TJSONArray;
  LIndex: Integer;
  LProject: TJSONObject;
  LSummary: TJSONObject;
begin
  EnterCriticalSection(GStudioLock);
  try
    LDirectory := ProjectsPath(ACatalogRoot);
    LNames := TStringList.Create;
    try
      if DirectoryExists(LDirectory) then
      begin
        LCode := FindFirst(IncludeTrailingPathDelimiter(LDirectory) + '*', faDirectory,
          LFound);
        if LCode = 0 then
        begin
          try
            while LCode = 0 do
            begin
              if (LFound.Attr and faDirectory <> 0) and (LFound.Name <> '.') and
                (LFound.Name <> '..') and (LFound.Name <> '.write-lock') then
              begin
                Need(ValidId(LFound.Name), 'Studio project namespace is invalid');
                Need(LNames.Count < MaximumStudioProjects,
                  'Studio project count exceeds its bound');
                LNames.Add(LFound.Name);
              end;
              LCode := FindNext(LFound);
            end;
          finally
            SysUtils.FindClose(LFound);
          end;
        end;
      end;
      LNames.Sort;
      Result := TJSONObject.Create;
      try
        Result.Add('format', StudioProjectsFormat);
        LRows := TJSONArray.Create;
        Result.Add('projects', LRows);
        for LIndex := 0 to LNames.Count - 1 do
        begin
          if LatestRevision(ProjectPath(ACatalogRoot, LNames[LIndex])) > 0 then
          begin
            LProject := ReadProjectLocked(ACatalogRoot, LNames[LIndex]);
            try
              LSummary := TJSONObject.Create;
              LRows.Add(LSummary);
              LSummary.Add('project_id', LProject.Strings['project_id']);
              LSummary.Add('name', LProject.Strings['name']);
              LSummary.Add('revision', LProject.Integers['revision']);
              LSummary.Add('snapshot_sha256', LProject.Strings['snapshot_sha256']);
              LSummary.Add('learning_mode', LProject.Strings['learning_mode']);
              LSummary.Add('status', LProject.Strings['status']);
              LSummary.Add('training_status', LProject.Strings['training_status']);
              LSummary.Add('source_count', ArrayField(LProject, 'sources').Count);
            finally
              LProject.Free;
            end;
          end;
        end;
      Result.Add('count', LRows.Count);
      Result.Add('maximum_projects', MaximumStudioProjects);
      except
        Result.Free;
        raise;
      end;
    finally
      LNames.Free;
    end;
  finally
    LeaveCriticalSection(GStudioLock);
  end;
end;

function CandidateProject(const ACatalogRoot: String;
  const AWrite: TJSONObject; const ARevision: Integer): TJSONObject;
var
  LSelections: TJSONArray;
  LRows: TJSONArray;
  LSelection: TJSONObject;
  LSource: TJSONObject;
  LIndex: Integer;
  LPrior: Integer;
  LMode: String;
  LKind: String;
  LHash: String;
  LStart: Int64;
  LEnd: Int64;
begin
  LMode := TextField(AWrite, 'learning_mode', 1, 32);
  Need((LMode = 'raw_acoustic') or (LMode = 'reference_events') or
    (LMode = 'inferred_events'), 'Studio requested learning mode is unsupported');
  LSelections := ArrayField(AWrite, 'sources');
  Need((LSelections.Count >= 1) and (LSelections.Count <= MaximumStudioSources),
    'Select between one and 32 original sources');
  Result := TJSONObject.Create;
  try
    Result.Add('format', StudioProjectFormat);
    Result.Add('project_id', TextField(AWrite, 'project_id', 1, 64));
    Result.Add('revision', ARevision);
    Result.Add('name', TextField(AWrite, 'name', 1, 128));
    Result.Add('style_intent', TextField(AWrite, 'style_intent', 0, 2048));
    Result.Add('learning_mode', LMode);
    Result.Add('status', 'draft');
    Result.Add('training_status', 'not_started');
    Result.Add('model_available', False);
    Result.Add('used_sources', TJSONArray.Create);
    LRows := TJSONArray.Create;
    Result.Add('sources', LRows);
    for LIndex := 0 to LSelections.Count - 1 do
    begin
      LSelection := ObjectAt(LSelections, LIndex);
      LKind := TextField(LSelection, 'selection', 1, 16);
      Need((LKind = 'full') or (LKind = 'range'), 'Studio source selection is unsupported');
      if LKind = 'full' then
      begin
        Fields(LSelection, 'source_sha256,selection');
      end
      else
      begin
        Fields(LSelection, 'source_sha256,selection,start_frame,end_frame');
      end;
      LHash := TextField(LSelection, 'source_sha256', 64, 64);
      for LPrior := 0 to LIndex - 1 do
      begin
        Need(TextField(ObjectAt(LSelections, LPrior), 'source_sha256', 64, 64) <> LHash,
          'Studio selection repeats an original source');
      end;
      LSource := ReadSource(ACatalogRoot, LHash);
      try
        Need(LSource.Strings['partition'] <> 'evaluation',
          'Evaluation sources are reserved for comparison, not training selection');
        if LKind = 'full' then
        begin
          LStart := 0;
          LEnd := IntField(LSource, 'frame_count');
        end
        else
        begin
          LStart := IntField(LSelection, 'start_frame');
          LEnd := IntField(LSelection, 'end_frame');
        end;
        Need((LStart >= 0) and (LEnd > LStart) and
          (LEnd <= IntField(LSource, 'frame_count')), 'Studio selected time is out of range');
        for LPrior := 0 to LRows.Count - 1 do
        begin
          if ObjectAt(LRows, LPrior).Strings['source_group'] = LSource.Strings['source_group'] then
          begin
            Need(ObjectAt(LRows, LPrior).Strings['partition'] = LSource.Strings['partition'],
              'Studio source group crosses catalog partitions');
          end;
        end;
        LSource.Add('selection', LKind);
        LSource.Add('start_frame', LStart);
        LSource.Add('end_frame', LEnd);
        if LSource.Strings['partition'] = 'evaluation' then
        begin
          LSource.Add('usage_status', 'evaluation_only');
        end
        else
        begin
          LSource.Add('usage_status', 'selected_not_used');
        end;
        LRows.Add(LSource);
        LSource := nil;
      finally
        LSource.Free;
      end;
    end;
    Result.Add('snapshot_sha256', JsonHash(Result));
    ValidateSnapshot(Result, Result.Strings['project_id'], ARevision);
  except
    Result.Free;
    raise;
  end;
end;

function SameContent(const ALeft, ARight: TJSONObject): Boolean;
var
  LLeft: TJSONObject;
  LRight: TJSONObject;
begin
  LLeft := TJSONObject(ALeft.Clone);
  try
    LRight := TJSONObject(ARight.Clone);
    try
      LLeft.Delete('revision');
      LLeft.Delete('snapshot_sha256');
      LRight.Delete('revision');
      LRight.Delete('snapshot_sha256');
      Result := LLeft.AsJSON = LRight.AsJSON;
    finally
      LRight.Free;
    end;
  finally
    LLeft.Free;
  end;
end;

function SaveStudioProjectLocked(const ACatalogRoot: String;
  const AWrite: TJSONObject): TJSONObject;
var
  LId: String;
  LDirectory: String;
  LProjects: String;
  LLockPath: String;
  LStage: String;
  LFinal: String;
  LExpected: Int64;
  LRevision: Integer;
  LPrevious: TJSONObject;
  LCandidate: TJSONObject;
  LStream: TFileStream;
  LText: String;
  LCount: TJSONObject;
  LValueCount: Integer;
begin
  LValueCount := 0;
  BoundJson(AWrite, 1, LValueCount);
  Fields(AWrite, 'format,project_id,expected_revision,name,style_intent,learning_mode,sources');
  Need(Length(AWrite.AsJSON) <= MaximumStudioDocumentBytes, 'Studio write exceeds its byte bound');
  Need(TextField(AWrite, 'format', 1, 64) = StudioProjectWriteFormat,
    'Studio write format is unsupported');
  LId := TextField(AWrite, 'project_id', 1, 64);
  Need(ValidId(LId), 'Studio project ID is invalid');
  LExpected := IntField(AWrite, 'expected_revision');
  Need((LExpected >= 0) and (LExpected < MaximumStudioRevision),
    'Studio expected revision exceeds its bound');
  LProjects := ProjectsPath(ACatalogRoot);
  LDirectory := ProjectPath(ACatalogRoot, LId);
  LPrevious := nil;
  LCandidate := CandidateProject(ACatalogRoot, AWrite, Integer(LExpected) + 1);
  try
    Need(ForceDirectories(LProjects), 'Studio project storage could not be created');
    CheckPath(LProjects);
    LLockPath := IncludeTrailingPathDelimiter(LProjects) + '.write-lock';
    CheckPath(LLockPath);
    if not CreateDir(LLockPath) then
    begin
      raise EStudioConflict.Create('Studio store is busy; retry after the current save completes');
    end;
    try
      LRevision := LatestRevision(LDirectory);
      if LRevision > 0 then
      begin
        LPrevious := ReadProjectLocked(ACatalogRoot, LId);
      end;
      if LExpected <> LRevision then
      begin
        if (LPrevious <> nil) and (LRevision = LExpected + 1) and
          SameContent(LPrevious, LCandidate) then
        begin
          Result := TJSONObject(LPrevious.Clone);
          Result.Add('already_saved', True);
          Exit;
        end;
        raise EStudioConflict.Create('Studio project changed; reopen it before saving a correction');
      end;
      if LRevision = 0 then
      begin
        LCount := ListStudioProjects(ACatalogRoot);
        try
          Need(IntField(LCount, 'count') < MaximumStudioProjects,
            'Studio project count exceeds its bound');
        finally
          LCount.Free;
        end;
      end;
      Need(ForceDirectories(LDirectory), 'Studio project directory could not be created');
      CheckPath(LDirectory);
      LFinal := IncludeTrailingPathDelimiter(LDirectory) + RevisionName(LRevision + 1);
      LStage := LFinal + '.stage';
      CheckPath(LFinal);
      CheckPath(LStage);
      Need(not FileExists(LFinal) and not DirectoryExists(LFinal),
        'Studio accepted revision already exists');
      Need(not FileExists(LStage) and not DirectoryExists(LStage),
        'Studio interrupted stage requires recovery before saving');
      LText := LCandidate.AsJSON + #10;
      LStream := TFileStream.Create(LStage, fmCreate or fmShareExclusive);
      try
        LStream.WriteBuffer(LText[1], Length(LText));
      finally
        LStream.Free;
      end;
      try
        Need(RenameFile(LStage, LFinal), 'Studio project revision could not be published');
      finally
        if FileExists(LStage) then
        begin
          SysUtils.DeleteFile(LStage);
        end;
      end;
      Result := TJSONObject(LCandidate.Clone);
      Result.Add('already_saved', False);
    finally
      RemoveDir(LLockPath);
    end;
  finally
    LPrevious.Free;
    LCandidate.Free;
  end;
end;

function SaveStudioProject(const ACatalogRoot: String;
  const AWrite: TJSONObject): TJSONObject;
begin
  EnterCriticalSection(GStudioLock);
  try
    Result := SaveStudioProjectLocked(ACatalogRoot, AWrite);
  finally
    LeaveCriticalSection(GStudioLock);
  end;
end;

initialization
  InitCriticalSection(GStudioLock);

finalization
  DoneCriticalSection(GStudioLock);

end.
