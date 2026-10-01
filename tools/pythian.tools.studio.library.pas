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
unit pythian.tools.studio.&library;

{$mode delphi}
{$H+}

interface

uses
  fpjson;

const
  StudioLibraryFormat = 'pythian.studio.library.v1';
  MaximumLibraryCollections = 64;
  MaximumLibraryFiles = 256;
  MaximumLibraryIndexBytes = 1048576;
  MaximumLibraryRevisions = 10000;
  MaximumLibrarySourceBytes: Int64 = 17179869184;
  MaximumLibraryAggregateBytes: Int64 = 34359738368;

type
  TStudioLibraryProgress = procedure(const AStage: String;
    const ADone, ATotal: Int64) of object;
  TStudioLibraryFile = record
    Path: String;
    Name: String;
    CollectionName: String;
    Hash: String;
    Bytes: Int64;
  end;
  TStudioLibraryFiles = array of TStudioLibraryFile;

{ Worker-only bounded discovery/import. AStageRoot must be a fresh directory,
  separate from library and catalog; failed stages remain for diagnosis.
  Progress callbacks may raise to cancel. No audio learning or admission occurs.
  Input copying, source integrity checks and the maintained importer make
  multiple full reads; byte caps describe input size, not total storage I/O.
  Existing sources require initial/final original hashes and one catalog hash,
  without staging media. Byte progress is per current file/pass, emitted after
  at most five seconds or eight MiB of read progress and at phase completion.
  Cancellation can raise from these callbacks during hashing/staging copies;
  new-source importer calls remain opaque between their native boundaries.
  For discovered original bytes A and distinct reused catalog bytes D, reuse
  makes 2A+D full verification reads (at most 3A), with zero full media writes.
  Mixed/new-source paths make at most 8A full hash/copy reads and 2A media
  writes: 256/64 GiB respectively at the 32 GiB aggregate input cap. WAV chunk
  header reads and bounded catalog JSON work are additional; these pass counts
  are logical I/O bounds, not measurements of physical disk traffic.
  Results are owned, path-free JSON. Partial imports may survive failed refresh;
  the previously published index remains unchanged. }
function RefreshStudioLibrary(const ACatalogRoot, ALibraryRoot, AStageRoot: String;
  const AProgress: TStudioLibraryProgress = nil): TJSONObject;
{ Worker-only explicit selection. The private file paths must resolve exactly
  under the configured collections directory; no other sources are discovered
  or hashed. Updates only selected memberships, preserving unrelated entries.
  Result adds prepared_sources to the published index projection. }
function PrepareStudioLibraryFiles(const ACatalogRoot, ALibraryRoot, AStageRoot: String;
  const AFiles: TStudioLibraryFiles;
  const AProgress: TStudioLibraryProgress = nil): TJSONObject;
{ Reads bounded published metadata only; never discovers or hashes audio. }
function ListStudioLibrary(const ACatalogRoot: String): TJSONObject;
function StudioCollectionsForSource(const ACatalogRoot, AHash: String): TJSONArray;

implementation

uses
  Classes,
  SysUtils,
  jsonparser,
  pythian.audio,
  pythian.hash,
  pythian.wave.read,
  pythian.tools.annotations.catalog
  {$IFDEF MSWINDOWS}, Windows{$ENDIF};

const
  CMaximumEntries = 4096;
  CProgressBytes = 8388608;
  CProgressMilliseconds = 5000;

type
  TLibraryFile = TStudioLibraryFile;
  TLibraryFiles = TStudioLibraryFiles;

  TLibraryReadStream = class(TFileStream)
  private
    FProgress: TStudioLibraryProgress;
    FStage: String;
    FDone: Int64;
    FTotal: Int64;
    FLastDone: Int64;
    FLastTick: QWord;
  public
    constructor Create(const APath, AStage: String; const ABytes: Int64;
      const AProgress: TStudioLibraryProgress);
    function Read(var ABuffer; ACount: Longint): Longint; override;
  end;

var
  GLibraryLock: TRTLCriticalSection;

procedure Need(const ACondition: Boolean; const AMessage: String);
begin
  if not ACondition then
  begin
    raise EAudio.Create(AMessage);
  end;
end;

constructor TLibraryReadStream.Create(const APath, AStage: String;
  const ABytes: Int64; const AProgress: TStudioLibraryProgress);
begin
  inherited Create(APath, fmOpenRead or fmShareDenyWrite);
  Need(Size = ABytes, 'Library source size changed before verification');
  FProgress := AProgress;
  FStage := AStage;
  FTotal := ABytes;
  FDone := 0;
  FLastDone := 0;
  FLastTick := GetTickCount64;
  if Assigned(FProgress) then
  begin
    FProgress(FStage, 0, FTotal);
  end;
end;

function TLibraryReadStream.Read(var ABuffer; ACount: Longint): Longint;
begin
  Result := inherited Read(ABuffer, ACount);
  Need((Result >= 0) and (Result <= FTotal - FDone),
    'Library read progress exceeds the declared source bytes');
  Inc(FDone, Result);
  if Assigned(FProgress) and ((FDone = FTotal) or
    (FDone - FLastDone >= CProgressBytes) or
    (GetTickCount64 - FLastTick >= CProgressMilliseconds)) then
  begin
    FLastDone := FDone;
    FLastTick := GetTickCount64;
    FProgress(FStage, FDone, FTotal);
  end;
end;

function HashText(const AText: String): String;
var
  LStream: TStringStream;
begin
  LStream := TStringStream.Create(AText);
  try
    Result := Sha256Stream(LStream, LStream.Size);
  finally
    LStream.Free;
  end;
end;

function ValidHash(const AText: String): Boolean;
var
  LIndex: Integer;
begin
  Result := Length(AText) = 64;
  for LIndex := 1 to Length(AText) do
  begin
    if not (AText[LIndex] in ['0'..'9', 'a'..'f']) then
    begin
      Exit(False);
    end;
  end;
end;

function SafeComponent(const AText: String): Boolean;
var
  LIndex: Integer;
begin
  Result := (AText <> '') and (AText <> '.') and (AText <> '..') and
    (Length(AText) <= 256);
  for LIndex := 1 to Length(AText) do
  begin
    if (Ord(AText[LIndex]) < 32) or (AText[LIndex] in ['/', '\', ':']) then
    begin
      Exit(False);
    end;
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
      {$IFDEF MSWINDOWS}
      LWindowsAttributes := GetFileAttributes(PChar(LPath));
      Need((LWindowsAttributes <> INVALID_FILE_ATTRIBUTES) and
        ((LWindowsAttributes and FILE_ATTRIBUTE_REPARSE_POINT) = 0),
        'Library path contains a linked or reparse component');
      {$ELSE}
      Need((LAttributes and faSymLink) = 0, 'Library path contains a symbolic link');
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

function RootPath(const APath: String): String;
begin
  Need(Trim(APath) <> '', 'Library root is required');
  Result := IncludeTrailingPathDelimiter(ExpandFileName(APath));
  CheckPath(Result);
end;

procedure SeparateRoots(const ALeft, ARight: String);
begin
  Need(not SameText(ALeft, ARight) and
    (Pos(LowerCase(ALeft), LowerCase(ARight)) <> 1) and
    (Pos(LowerCase(ARight), LowerCase(ALeft)) <> 1),
    'Library, catalog and stage roots must be separate');
end;

function IndexRoot(const ACatalogRoot: String): String;
begin
  Result := RootPath(ACatalogRoot) + 'studio' + PathDelim + 'library';
  CheckPath(Result);
end;

procedure WriteNew(const APath, AText: String);
var
  LStream: TFileStream;
begin
  CheckPath(APath);
  Need(not FileExists(APath) and not DirectoryExists(APath),
    'Library publication or stage already exists');
  LStream := TFileStream.Create(APath, fmCreate or fmShareExclusive);
  try
    if AText <> '' then
    begin
      LStream.WriteBuffer(AText[1], Length(AText));
    end;
  finally
    LStream.Free;
  end;
end;

function ReadIndex(const APath: String): TJSONObject;
var
  LStream: TFileStream;
  LText: String;
  LData: TJSONData;
  LDepth: Integer;
  LIndex: Integer;
  LQuoted: Boolean;
  LEscaped: Boolean;
begin
  CheckPath(APath);
  LStream := TFileStream.Create(APath, fmOpenRead or fmShareDenyWrite);
  try
    Need((LStream.Size > 0) and (LStream.Size <= MaximumLibraryIndexBytes),
      'Library index exceeds its byte bound');
    SetLength(LText, Integer(LStream.Size));
    LStream.ReadBuffer(LText[1], Length(LText));
  finally
    LStream.Free;
  end;
  LDepth := 0;
  LQuoted := False;
  LEscaped := False;
  for LIndex := 1 to Length(LText) do
  begin
    if LQuoted then
    begin
      if LEscaped then
      begin
        LEscaped := False;
      end
      else if LText[LIndex] = '\' then
      begin
        LEscaped := True;
      end
      else if LText[LIndex] = '"' then
      begin
        LQuoted := False;
      end;
    end
    else if LText[LIndex] = '"' then
    begin
      LQuoted := True;
    end
    else if LText[LIndex] in ['{', '['] then
    begin
      Inc(LDepth);
      Need(LDepth <= 16, 'Library index nesting exceeds its bound');
    end
    else if LText[LIndex] in ['}', ']'] then
    begin
      Dec(LDepth);
      Need(LDepth >= 0, 'Library index nesting is invalid');
    end;
  end;
  Need((LDepth = 0) and not LQuoted, 'Library index is incomplete');
  LData := GetJSON(LText);
  Need(LData <> nil, 'Library index is missing');
  if LData.JSONType <> jtObject then
  begin
    LData.Free;
    raise EAudio.Create('Library index must be an object');
  end;
  Result := TJSONObject(LData);
end;

function EmptyIndex: TJSONObject;
begin
  Result := TJSONObject.Create;
  Result.Add('format', StudioLibraryFormat);
  Result.Add('revision', 0);
  Result.Add('collections', TJSONArray.Create);
  Result.Add('source_collection_memberships', TJSONArray.Create);
  Result.Add('collection_count', 0);
  Result.Add('file_count', 0);
  Result.Add('recording_count', 0);
  Result.Add('missing_count', 0);
  Result.Add('changed_count', 0);
  Result.Add('unsupported_count', 0);
  Result.Add('imported_count', 0);
  Result.Add('existing_count', 0);
  Result.Add('duplicate_file_count', 0);
  Result.Add('failed_count', 0);
end;

procedure Summarize(const AIndex: TJSONObject); forward;

procedure Fields(const AObject: TJSONObject; const ANames: String);
var
  LNames: TStringList;
  LIndex: Integer;
begin
  LNames := TStringList.Create;
  try
    LNames.StrictDelimiter := True;
    LNames.Delimiter := ',';
    LNames.DelimitedText := ANames;
    Need(AObject.Count = LNames.Count, 'Library index field count is invalid');
    for LIndex := 0 to AObject.Count - 1 do
    begin
      Need(LNames.IndexOf(AObject.Names[LIndex]) >= 0,
        'Library index has an unsupported field');
      Need(AObject.IndexOfName(AObject.Names[LIndex]) = LIndex,
        'Library index has a repeated field');
    end;
  finally
    LNames.Free;
  end;
end;

procedure ValidateIndex(const AIndex: TJSONObject; const ARevision: Integer);
var
  LCopy: TJSONObject;
  LCollections: TJSONArray;
  LMembers: TJSONArray;
  LCollection: TJSONObject;
  LMember: TJSONObject;
  LIds: TStringList;
  LRows: TStringList;
  LHash: String;
  LCount: Integer;
  LIndex: Integer;
  LOther: Integer;
begin
  Fields(AIndex, 'format,revision,collections,source_collection_memberships,' +
    'collection_count,file_count,recording_count,missing_count,unsupported_count,' +
    'imported_count,existing_count,duplicate_file_count,failed_count,index_sha256,changed_count');
  Need((AIndex.Strings['format'] = StudioLibraryFormat) and
    (AIndex.Integers['revision'] = ARevision), 'Library index identity is invalid');
  LHash := AIndex.Strings['index_sha256'];
  Need(ValidHash(LHash), 'Library index digest is invalid');
  LCopy := TJSONObject(AIndex.Clone);
  try
    LCopy.Delete('index_sha256');
    Need(HashText(LCopy.AsJSON) = LHash, 'Library index differs from its digest');
  finally
    LCopy.Free;
  end;
  LCollections := AIndex.Arrays['collections'];
  Need(LCollections.Count <= MaximumLibraryCollections, 'Library collection bound exceeded');
  LIds := TStringList.Create;
  LRows := TStringList.Create;
  try
    LCount := 0;
    for LIndex := 0 to LCollections.Count - 1 do
    begin
      LCollection := LCollections.Objects[LIndex];
      Fields(LCollection, 'collection_id,name,status,source_sha256s,memberships');
      Need(SafeComponent(LCollection.Strings['name']) and
        (LCollection.Strings['collection_id'] = HashText(LCollection.Strings['name'])),
        'Library collection identity is invalid');
      Need(LIds.IndexOf(LCollection.Strings['collection_id']) < 0,
        'Library collection identity is repeated');
      LIds.Add(LCollection.Strings['collection_id']);
      Need((LCollection.Strings['status'] = 'available') or
        (LCollection.Strings['status'] = 'missing'), 'Library collection status is invalid');
      LMembers := LCollection.Arrays['memberships'];
      LRows.Clear;
      for LOther := 0 to LMembers.Count - 1 do
      begin
        Inc(LCount);
        Need(LCount <= MaximumLibraryFiles, 'Retained library membership bound exceeded');
        LMember := LMembers.Objects[LOther];
        Fields(LMember, 'source_sha256,original_name,source_bytes,status');
        Need(ValidHash(LMember.Strings['source_sha256']) and
          SafeComponent(LMember.Strings['original_name']) and
          (LMember.Int64s['source_bytes'] >= 44) and
          (LMember.Int64s['source_bytes'] <= MaximumLibrarySourceBytes),
          'Library membership identity is invalid');
        Need((LMember.Strings['status'] = 'available') or
          (LMember.Strings['status'] = 'missing'), 'Library membership status is invalid');
        LHash := LMember.Strings['source_sha256'] + ':' + LMember.Strings['original_name'];
        Need(LRows.IndexOf(LHash) < 0, 'Library membership is repeated');
        LRows.Add(LHash);
      end;
    end;
  finally
    LRows.Free;
    LIds.Free;
  end;
  LCopy := TJSONObject(AIndex.Clone);
  try
    Summarize(LCopy);
    Need(LCopy.AsJSON = AIndex.AsJSON,
      'Library index summary or source memberships are inconsistent');
  finally
    LCopy.Free;
  end;
end;

function ListStudioLibrary(const ACatalogRoot: String): TJSONObject;
var
  LRoot: String;
  LFound: TSearchRec;
  LStatus: Integer;
  LRevision: Integer;
  LNumber: Integer;
  LCount: Integer;
  LName: String;
begin
  LRoot := IndexRoot(ACatalogRoot);
  if not DirectoryExists(LRoot) then
  begin
    Result := EmptyIndex;
    Result.Add('index_sha256', HashText(Result.AsJSON));
    Exit;
  end;
  LRevision := 0;
  LCount := 0;
  LStatus := FindFirst(IncludeTrailingPathDelimiter(LRoot) + 'revision-*.json',
    faAnyFile, LFound);
  if LStatus = 0 then
  begin
    try
      while LStatus = 0 do
      begin
        Inc(LCount);
        Need(LCount <= MaximumLibraryRevisions, 'Library revision inventory exceeds its bound');
        LName := LFound.Name;
        Need((Length(LName) = 20) and
          TryStrToInt(Copy(LName, 10, 6), LNumber) and
          (LName = 'revision-' + Format('%.6d', [LNumber]) + '.json') and
          (LNumber > 0) and (LNumber <= MaximumLibraryRevisions),
          'Library revision filename is invalid');
        CheckPath(IncludeTrailingPathDelimiter(LRoot) + LName);
        Need((LFound.Attr and faDirectory) = 0, 'Library revision is not a regular file');
        if LNumber > LRevision then
        begin
          LRevision := LNumber;
        end;
        LStatus := FindNext(LFound);
      end;
    finally
      SysUtils.FindClose(LFound);
    end;
  end;
  if LRevision = 0 then
  begin
    Result := EmptyIndex;
    Result.Add('index_sha256', HashText(Result.AsJSON));
    Exit;
  end;
  Result := ReadIndex(IncludeTrailingPathDelimiter(LRoot) +
    'revision-' + Format('%.6d', [LRevision]) + '.json');
  try
    ValidateIndex(Result, LRevision);
  except
    Result.Free;
    raise;
  end;
end;

function StudioCollectionsForSource(const ACatalogRoot, AHash: String): TJSONArray;
var
  LIndex: TJSONObject;
  LCollections: TJSONArray;
  LMembers: TJSONArray;
  LCollection: TJSONObject;
  LRow: TJSONObject;
  LFound: Boolean;
  LAvailable: Boolean;
  LFirst: Integer;
  LSecond: Integer;
begin
  Need(ValidHash(AHash), 'Library source SHA256 is invalid');
  LIndex := ListStudioLibrary(ACatalogRoot);
  try
    Result := TJSONArray.Create;
    try
      LCollections := LIndex.Arrays['collections'];
      for LFirst := 0 to LCollections.Count - 1 do
      begin
        LCollection := LCollections.Objects[LFirst];
        LMembers := LCollection.Arrays['memberships'];
        LFound := False;
        LAvailable := False;
        for LSecond := 0 to LMembers.Count - 1 do
        begin
          if LMembers.Objects[LSecond].Strings['source_sha256'] = AHash then
          begin
            LFound := True;
            if LMembers.Objects[LSecond].Strings['status'] = 'available' then
            begin
              LAvailable := True;
            end;
          end;
        end;
        if LFound then
        begin
          LRow := TJSONObject.Create;
          LRow.Add('collection_id', LCollection.Strings['collection_id']);
          LRow.Add('name', LCollection.Strings['name']);
          if LAvailable and (LCollection.Strings['status'] = 'available') then
          begin
            LRow.Add('status', 'available');
          end
          else
          begin
            LRow.Add('status', 'missing');
          end;
          Result.Add(LRow);
        end;
      end;
    except
      Result.Free;
      raise;
    end;
  finally
    LIndex.Free;
  end;
end;

procedure Progress(const ACallback: TStudioLibraryProgress;
  const AStage: String; const ADone, ATotal: Int64);
begin
  if Assigned(ACallback) then
  begin
    ACallback(AStage, ADone, ATotal);
  end;
end;

procedure Discover(const ARoot: String; const ACollections: TStringList;
  out AFiles: TLibraryFiles; out AUnsupported: Integer);
var
  LRoot: String;
  LPath: String;
  LFound: TSearchRec;
  LStatus: Integer;
  LNames: TStringList;
  LFiles: TStringList;
  LIndex: Integer;
  LOther: Integer;
  LScanned: Integer;
  LBytes: Int64;
  LStream: TFileStream;
begin
  AFiles := nil;
  AUnsupported := 0;
  LRoot := ARoot + 'collections' + PathDelim;
  CheckPath(LRoot);
  Need(DirectoryExists(LRoot), 'Configured library collections directory is unavailable');
  LNames := TStringList.Create;
  LFiles := TStringList.Create;
  try
    LScanned := 0;
    LBytes := 0;
    LStatus := FindFirst(LRoot + '*', faAnyFile, LFound);
    if LStatus = 0 then
    begin
      try
        while LStatus = 0 do
        begin
          if (LFound.Name <> '.') and (LFound.Name <> '..') then
          begin
            Inc(LScanned);
            Need(LScanned <= CMaximumEntries, 'Library discovery entry bound exceeded');
            CheckPath(LRoot + LFound.Name);
            Need(SafeComponent(LFound.Name), 'Library collection name is unsafe');
            if (LFound.Attr and faDirectory) <> 0 then
            begin
              Need(LNames.Count < MaximumLibraryCollections, 'Library collection bound exceeded');
              LNames.Add(LFound.Name);
            end
            else
            begin
              Inc(AUnsupported);
            end;
          end;
          LStatus := FindNext(LFound);
        end;
      finally
        SysUtils.FindClose(LFound);
      end;
    end;
    LNames.Sort;
    ACollections.Assign(LNames);
    for LIndex := 0 to LNames.Count - 1 do
    begin
      LPath := LRoot + LNames[LIndex] + PathDelim;
      LFiles.Clear;
      LStatus := FindFirst(LPath + '*', faAnyFile, LFound);
      if LStatus = 0 then
      begin
        try
          while LStatus = 0 do
          begin
            if (LFound.Name <> '.') and (LFound.Name <> '..') then
            begin
              Inc(LScanned);
              Need(LScanned <= CMaximumEntries, 'Library discovery entry bound exceeded');
              CheckPath(LPath + LFound.Name);
              Need(SafeComponent(LFound.Name), 'Library source name is unsafe');
              Need((LFound.Attr and faDirectory) = 0, 'Nested library discovery is unsupported');
              if SameText(ExtractFileExt(LFound.Name), '.wav') then
              begin
                Need(Length(AFiles) + LFiles.Count < MaximumLibraryFiles,
                  'Library file count exceeds its bound');
                LFiles.Add(LFound.Name);
              end
              else
              begin
                Inc(AUnsupported);
              end;
            end;
            LStatus := FindNext(LFound);
          end;
        finally
          SysUtils.FindClose(LFound);
        end;
      end;
      LFiles.Sort;
      for LOther := 0 to LFiles.Count - 1 do
      begin
        SetLength(AFiles, Length(AFiles) + 1);
        AFiles[High(AFiles)].Path := LPath + LFiles[LOther];
        AFiles[High(AFiles)].Name := LFiles[LOther];
        AFiles[High(AFiles)].CollectionName := LNames[LIndex];
        LStream := TFileStream.Create(LPath + LFiles[LOther], fmOpenRead or fmShareDenyWrite);
        try
          Need((LStream.Size >= 44) and (LStream.Size <= MaximumLibrarySourceBytes),
            'Library source exceeds its byte bound');
          Need(LBytes <= MaximumLibraryAggregateBytes - LStream.Size,
            'Library aggregate input exceeds its byte bound');
          Inc(LBytes, LStream.Size);
          AFiles[High(AFiles)].Bytes := LStream.Size;
        finally
          LStream.Free;
        end;
      end;
    end;
  finally
    LFiles.Free;
    LNames.Free;
  end;
end;

function FileHash(const APath: String; const ABytes: Int64;
  const AProgress: TStudioLibraryProgress = nil;
  const AStage: String = 'verifying_source_bytes'): String;
var
  LStream: TLibraryReadStream;
begin
  CheckPath(APath);
  LStream := TLibraryReadStream.Create(APath, AStage, ABytes, AProgress);
  try
    Need(LStream.Size = ABytes, 'Library source size changed during refresh');
    Result := Sha256Stream(LStream, LStream.Size);
  finally
    LStream.Free;
  end;
end;

procedure CopySource(const AFile: TLibraryFile; const ATarget: String;
  const AProgress: TStudioLibraryProgress);
var
  LInput: TLibraryReadStream;
  LOutput: TFileStream;
begin
  CheckPath(AFile.Path);
  CheckPath(ATarget);
  Need(not FileExists(ATarget), 'Library staging name conflicts');
  LInput := TLibraryReadStream.Create(AFile.Path, 'copying_source_bytes',
    AFile.Bytes, AProgress);
  try
    Need(LInput.Size = AFile.Bytes, 'Library source changed before copy');
    LOutput := TFileStream.Create(ATarget, fmCreate or fmShareExclusive);
    try
      LOutput.CopyFrom(LInput, AFile.Bytes);
    finally
      LOutput.Free;
    end;
  finally
    LInput.Free;
  end;
  Need(FileHash(ATarget, AFile.Bytes, AProgress, 'verifying_stage_bytes') = AFile.Hash,
    'Library source changed during staging');
end;

function Collection(const AIndex: TJSONObject; const AName: String): TJSONObject;
var
  LRows: TJSONArray;
  LIndex: Integer;
begin
  LRows := AIndex.Arrays['collections'];
  for LIndex := 0 to LRows.Count - 1 do
  begin
    if LRows.Objects[LIndex].Strings['collection_id'] = HashText(AName) then
    begin
      Exit(LRows.Objects[LIndex]);
    end;
  end;
  Need(LRows.Count < MaximumLibraryCollections, 'Retained collection bound exceeded');
  Result := TJSONObject.Create;
  Result.Add('collection_id', HashText(AName));
  Result.Add('name', AName);
  Result.Add('status', 'available');
  Result.Add('source_sha256s', TJSONArray.Create);
  Result.Add('memberships', TJSONArray.Create);
  LRows.Add(Result);
end;

procedure MarkMissing(const AIndex: TJSONObject);
var
  LRows: TJSONArray;
  LMembers: TJSONArray;
  LIndex: Integer;
  LOther: Integer;
begin
  LRows := AIndex.Arrays['collections'];
  for LIndex := 0 to LRows.Count - 1 do
  begin
    LRows.Objects[LIndex].Strings['status'] := 'missing';
    LMembers := LRows.Objects[LIndex].Arrays['memberships'];
    for LOther := 0 to LMembers.Count - 1 do
    begin
      LMembers.Objects[LOther].Strings['status'] := 'missing';
    end;
  end;
end;

procedure AddMembership(const AIndex: TJSONObject; const AFile: TLibraryFile);
var
  LCollection: TJSONObject;
  LMembers: TJSONArray;
  LMember: TJSONObject;
  LIndex: Integer;
begin
  LCollection := Collection(AIndex, AFile.CollectionName);
  LCollection.Strings['status'] := 'available';
  LMembers := LCollection.Arrays['memberships'];
  for LIndex := 0 to LMembers.Count - 1 do
  begin
    LMember := LMembers.Objects[LIndex];
    if (LMember.Strings['source_sha256'] = AFile.Hash) and
      (LMember.Strings['original_name'] = AFile.Name) then
    begin
      Need(LMember.Int64s['source_bytes'] = AFile.Bytes, 'Library source length conflicts');
      LMember.Strings['status'] := 'available';
      Exit;
    end;
  end;
  LMember := TJSONObject.Create;
  LMember.Add('source_sha256', AFile.Hash);
  LMember.Add('original_name', AFile.Name);
  LMember.Add('source_bytes', AFile.Bytes);
  LMember.Add('status', 'available');
  LMembers.Add(LMember);
end;

function SourceChanged(const APrevious: TJSONObject; const AFile: TLibraryFile): Boolean;
var
  LCollections: TJSONArray;
  LMembers: TJSONArray;
  LFirst: Integer;
  LSecond: Integer;
begin
  Result := False;
  LCollections := APrevious.Arrays['collections'];
  for LFirst := 0 to LCollections.Count - 1 do
  begin
    if LCollections.Objects[LFirst].Strings['name'] = AFile.CollectionName then
    begin
      LMembers := LCollections.Objects[LFirst].Arrays['memberships'];
      for LSecond := 0 to LMembers.Count - 1 do
      begin
        if (LMembers.Objects[LSecond].Strings['original_name'] = AFile.Name) and
          (LMembers.Objects[LSecond].Strings['status'] = 'available') and
          (LMembers.Objects[LSecond].Strings['source_sha256'] <> AFile.Hash) then
        begin
          Exit(True);
        end;
      end;
    end;
  end;
end;

procedure CatalogInventory(const ACatalog: String; const AHashes: TStringList);
var
  LKind: Integer;
  LDirectory: String;
  LPattern: String;
  LFound: TSearchRec;
  LStatus: Integer;
  LCount: Integer;
  LHash: String;
begin
  for LKind := 0 to 1 do
  begin
    if LKind = 0 then
    begin
      LDirectory := ACatalog + 'tracks' + PathDelim;
      LPattern := '*.json';
    end
    else
    begin
      LDirectory := ACatalog + 'sources' + PathDelim;
      LPattern := '*.wav';
    end;
    CheckPath(LDirectory);
    LCount := 0;
    LStatus := FindFirst(LDirectory + LPattern, faAnyFile, LFound);
    if LStatus = 0 then
    begin
      try
        while LStatus = 0 do
        begin
          Inc(LCount);
          Need(LCount <= 4096, 'Library catalog inventory exceeds its bound');
          CheckPath(LDirectory + LFound.Name);
          Need((LFound.Attr and faDirectory) = 0, 'Catalog asset is not a regular file');
          LHash := ChangeFileExt(LFound.Name, '');
          Need(ValidHash(LHash), 'Catalog asset filename is invalid');
          if LKind = 0 then
          begin
            AHashes.Add(LHash);
          end;
          LStatus := FindNext(LFound);
        end;
      finally
        SysUtils.FindClose(LFound);
      end;
    end;
  end;
end;

procedure Summarize(const AIndex: TJSONObject);
var
  LCollections: TJSONArray;
  LMembers: TJSONArray;
  LHashes: TJSONArray;
  LMapping: TJSONArray;
  LLabels: TJSONArray;
  LRow: TJSONObject;
  LLabel: TJSONObject;
  LUnique: TStringList;
  LAvailable: TStringList;
  LFirst: Integer;
  LSecond: Integer;
  LThird: Integer;
  LFiles: Integer;
  LMissing: Integer;
  LFound: Boolean;
  LMembershipAvailable: Boolean;
begin
  LCollections := AIndex.Arrays['collections'];
  LUnique := TStringList.Create;
  LAvailable := TStringList.Create;
  try
    LFiles := 0;
    LMissing := 0;
    for LFirst := 0 to LCollections.Count - 1 do
    begin
      LHashes := LCollections.Objects[LFirst].Arrays['source_sha256s'];
      LHashes.Clear;
      LMembers := LCollections.Objects[LFirst].Arrays['memberships'];
      for LSecond := 0 to LMembers.Count - 1 do
      begin
        Inc(LFiles);
        Need(LFiles <= MaximumLibraryFiles, 'Retained membership bound exceeded');
        if LUnique.IndexOf(LMembers.Objects[LSecond].Strings['source_sha256']) < 0 then
        begin
          LUnique.Add(LMembers.Objects[LSecond].Strings['source_sha256']);
        end;
        if LMembers.Objects[LSecond].Strings['status'] = 'missing' then
        begin
          Inc(LMissing);
        end
        else
        begin
          if LAvailable.IndexOf(LMembers.Objects[LSecond].Strings['source_sha256']) < 0 then
          begin
            LAvailable.Add(LMembers.Objects[LSecond].Strings['source_sha256']);
          end;
          LFound := False;
          for LThird := 0 to LHashes.Count - 1 do
          begin
            if LHashes.Strings[LThird] = LMembers.Objects[LSecond].Strings['source_sha256'] then
            begin
              LFound := True;
            end;
          end;
          if not LFound then
          begin
            LHashes.Add(LMembers.Objects[LSecond].Strings['source_sha256']);
          end;
        end;
      end;
    end;
    LMapping := AIndex.Arrays['source_collection_memberships'];
    LMapping.Clear;
    for LFirst := 0 to LUnique.Count - 1 do
    begin
      LRow := TJSONObject.Create;
      LRow.Add('source_sha256', LUnique[LFirst]);
      LLabels := TJSONArray.Create;
      LRow.Add('collections', LLabels);
      LMapping.Add(LRow);
      for LSecond := 0 to LCollections.Count - 1 do
      begin
        LMembers := LCollections.Objects[LSecond].Arrays['memberships'];
        LFound := False;
        LMembershipAvailable := False;
        for LThird := 0 to LMembers.Count - 1 do
        begin
          if LMembers.Objects[LThird].Strings['source_sha256'] = LUnique[LFirst] then
          begin
            LFound := True;
            if LMembers.Objects[LThird].Strings['status'] = 'available' then
            begin
              LMembershipAvailable := True;
            end;
          end;
        end;
        if LFound then
        begin
          LLabel := TJSONObject.Create;
          LLabel.Add('collection_id', LCollections.Objects[LSecond].Strings['collection_id']);
          LLabel.Add('name', LCollections.Objects[LSecond].Strings['name']);
          if LMembershipAvailable and
            (LCollections.Objects[LSecond].Strings['status'] = 'available') then
          begin
            LLabel.Add('status', 'available');
          end
          else
          begin
            LLabel.Add('status', 'missing');
          end;
          LLabels.Add(LLabel);
        end;
      end;
    end;
    AIndex.Integers['collection_count'] := LCollections.Count;
    AIndex.Integers['file_count'] := LFiles - LMissing;
    AIndex.Integers['recording_count'] := LAvailable.Count;
    AIndex.Integers['missing_count'] := LMissing;
  finally
    LAvailable.Free;
    LUnique.Free;
  end;
end;

function ManifestEntry(const ACatalog: String; const AFile: TLibraryFile): TJSONObject;
var
  LTrack: TJSONObject;
  LFields: array[0..5] of String;
  LIndex: Integer;
  LTitle: String;
begin
  Result := TJSONObject.Create;
  try
    Result.Add('sha256', AFile.Hash);
    if FileExists(ACatalog + 'tracks' + PathDelim + AFile.Hash + '.json') then
    begin
      CheckPath(ACatalog + 'tracks' + PathDelim + AFile.Hash + '.json');
      CheckPath(ACatalog + 'sources' + PathDelim + AFile.Hash + '.wav');
      LTrack := ReadCatalogTrack(ACatalog, AFile.Hash);
      try
        Result.Add('file', LTrack.Strings['original_name']);
        LFields[0] := 'title';
        LFields[1] := 'source_group';
        LFields[2] := 'clock_id';
        LFields[3] := 'partition';
        LFields[4] := 'provenance';
        LFields[5] := 'license';
        for LIndex := 0 to 5 do
        begin
          Result.Add(LFields[LIndex], LTrack.Strings[LFields[LIndex]]);
        end;
      finally
        LTrack.Free;
      end;
    end
    else
    begin
      LTitle := ChangeFileExt(AFile.Name, '');
      Result.Add('file', AFile.Hash + '.wav');
      Result.Add('title', LTitle);
      Result.Add('source_group', 'library_' + AFile.Hash);
      Result.Add('clock_id', '');
      Result.Add('partition', 'unassigned');
      Result.Add('provenance', 'Private operator folder input; recording origin unverified');
      Result.Add('license', 'unknown/private; recording rights unverified');
    end;
  except
    Result.Free;
    raise;
  end;
end;

function ExistingText(const ATrack: TJSONObject; const AName: String;
  const AMaximum: Integer; const AEmptyAllowed: Boolean = False): String;
var
  LValue: TJSONData;
begin
  LValue := ATrack.Find(AName);
  Need((LValue <> nil) and (LValue.JSONType = jtString),
    'Existing catalog text is unavailable: ' + AName);
  Result := LValue.AsString;
  Need((Length(Result) <= AMaximum) and (AEmptyAllowed or (Result <> '')),
    'Existing catalog text exceeds its bounds: ' + AName);
end;

function VerifyExisting(const ACatalog: String; const AFile: TLibraryFile;
  const ACatalogHashes: TStrings; const AProgress: TStudioLibraryProgress): String;
var
  LTrack: TJSONObject;
  LCurrent: TJSONObject;
  LStream: TFileStream;
  LReader: TWaveFrameReader;
  LPath: String;
  LName: String;
  LGroup: String;
  LClock: String;
  LPartition: String;
  LIndex: Integer;
begin
  LPath := ACatalog + 'sources' + PathDelim + AFile.Hash + '.wav';
  CheckPath(LPath);
  LTrack := ReadCatalogTrack(ACatalog, AFile.Hash);
  try
    Result := HashText(LTrack.AsJSON);
    LName := ExistingText(LTrack, 'original_name', 128);
    LGroup := ExistingText(LTrack, 'source_group', 128);
    LClock := ExistingText(LTrack, 'clock_id', 128, True);
    LPartition := ExistingText(LTrack, 'partition', 16);
    Need(SafeComponent(LName) and (LowerCase(ExtractFileExt(LName)) = '.wav') and
      SafeComponent(LGroup) and ((LClock = '') or SafeComponent(LClock)),
      'Existing catalog source naming differs from the import contract');
    Need((LPartition = 'training') or (LPartition = 'development') or
      (LPartition = 'evaluation') or (LPartition = 'unassigned'),
      'Existing catalog partition is invalid');
    ExistingText(LTrack, 'title', 256);
    ExistingText(LTrack, 'provenance', 512);
    ExistingText(LTrack, 'license', 256);
    for LIndex := 0 to ACatalogHashes.Count - 1 do
    begin
      if ACatalogHashes[LIndex] <> AFile.Hash then
      begin
        LCurrent := ReadCatalogTrack(ACatalog, ACatalogHashes[LIndex]);
        try
          if LCurrent.Strings['source_group'] = LGroup then
          begin
            Need(LCurrent.Strings['partition'] = LPartition,
              'Existing source group crosses catalog partitions');
          end;
          if (LClock <> '') and (LCurrent.Strings['clock_id'] = LClock) then
          begin
            Need((LCurrent.Strings['source_group'] = LGroup) and
              (LCurrent.Integers['sample_rate'] = LTrack.Integers['sample_rate']),
              'Existing shared source clock is incompatible');
          end;
        finally
          LCurrent.Free;
        end;
      end;
    end;
    LStream := TFileStream.Create(LPath, fmOpenRead or fmShareDenyWrite);
    try
      Need((LStream.Size = AFile.Bytes) and
        (LTrack.Int64s['source_bytes'] = AFile.Bytes),
        'Existing catalog source byte count conflicts');
      LReader := TWaveFrameReader.Create(LStream);
      try
        Need((LReader.FrameCount > 0) and
          (LReader.SampleRate = LTrack.Integers['sample_rate']) and
          (LReader.Channels = LTrack.Integers['channels']) and
          (LReader.BitsPerSample = LTrack.Integers['bits_per_sample']) and
          (LReader.FrameCount = LTrack.Int64s['frame_count']),
          'Existing catalog source geometry conflicts');
      finally
        LReader.Free;
      end;
    finally
      LStream.Free;
    end;
    Need(FileHash(LPath, AFile.Bytes, AProgress, 'verifying_catalog_bytes') = AFile.Hash,
      'Existing catalog audio differs from its content identity');
    LCurrent := ReadCatalogTrack(ACatalog, AFile.Hash);
    try
      Need(HashText(LCurrent.AsJSON) = Result,
        'Existing catalog metadata changed during verification');
    finally
      LCurrent.Free;
    end;
  finally
    LTrack.Free;
  end;
end;

procedure WriteInbox(const AEntry: TJSONObject; const ADirectory: String);
var
  LManifest: TJSONObject;
  LRows: TJSONArray;
begin
  LManifest := TJSONObject.Create;
  try
    LManifest.Add('version', 1);
    LRows := TJSONArray.Create;
    LRows.Add(AEntry.Clone);
    LManifest.Add('tracks', LRows);
    WriteNew(ADirectory + 'manifest.json', LManifest.AsJSON + #10);
  finally
    LManifest.Free;
  end;
end;

function RefreshLocked(const ACatalogRoot, ALibraryRoot, AStageRoot: String;
  const AProgress: TStudioLibraryProgress; const ASelected: TStudioLibraryFiles;
  const ASelective: Boolean): TJSONObject;
var
  LCatalog: String;
  LLibrary: String;
  LStage: String;
  LRoot: String;
  LLock: String;
  LFinal: String;
  LPartial: String;
  LFiles: TLibraryFiles;
  LNames: TStringList;
  LHashes: TStringList;
  LCatalogHashes: TStringList;
  LExistingRecords: TStringList;
  LManifest: TJSONObject;
  LPrevious: TJSONObject;
  LEntries: TJSONArray;
  LEntry: TJSONObject;
  LReport: TJSONObject;
  LTrack: TJSONObject;
  LIndex: Integer;
  LUnsupported: Integer;
  LRevision: Integer;
  LUnique: Integer;
  LNewSources: Integer;
  LFileName: String;
  LInbox: String;
  LMembers: TJSONArray;
  LPrepared: TJSONArray;
  LRow: TJSONObject;
  LOther: Integer;
  LStream: TFileStream;
  LSelectedBytes: Int64;
begin
  LCatalog := RootPath(ACatalogRoot);
  LLibrary := RootPath(ALibraryRoot);
  LStage := RootPath(AStageRoot);
  SeparateRoots(LCatalog, LLibrary);
  SeparateRoots(LCatalog, LStage);
  SeparateRoots(LLibrary, LStage);
  Need(DirectoryExists(LCatalog), 'Library catalog root is unavailable');
  Need(not DirectoryExists(LStage) and not FileExists(ExcludeTrailingPathDelimiter(LStage)),
    'Library refresh stage must be fresh');
  LRoot := IndexRoot(LCatalog);
  Need(ForceDirectories(LRoot), 'Library index directory could not be created');
  LLock := IncludeTrailingPathDelimiter(LRoot) + '.write-lock';
  CheckPath(LLock);
  Need(CreateDir(LLock), 'Library refresh is busy or has an interrupted lock');
  Result := nil;
  LNames := TStringList.Create;
  LHashes := TStringList.Create;
  LCatalogHashes := TStringList.Create;
  LExistingRecords := TStringList.Create;
  LManifest := nil;
  LPrevious := nil;
  try
    try
      Result := ListStudioLibrary(LCatalog);
      LPrevious := TJSONObject(Result.Clone);
      CatalogInventory(LCatalog, LCatalogHashes);
      LRevision := Result.Integers['revision'] + 1;
      Need(LRevision <= MaximumLibraryRevisions, 'Library revision bound exceeded');
      LUnsupported := 0;
      if ASelective then
      begin
        Need((Length(ASelected) >= 1) and (Length(ASelected) <= 32),
          'Library preparation requires 1..32 selected entries');
        LFiles := Copy(ASelected, 0, Length(ASelected));
        LSelectedBytes := 0;
        for LIndex := 0 to High(LFiles) do
        begin
          Need(SafeComponent(LFiles[LIndex].CollectionName) and
            SafeComponent(LFiles[LIndex].Name), 'Selected library naming is unsafe');
          Need(SameText(ExpandFileName(LFiles[LIndex].Path), LLibrary + 'collections' +
            PathDelim + LFiles[LIndex].CollectionName + PathDelim + LFiles[LIndex].Name),
            'Selected library path differs from its configured entry');
          CheckPath(LFiles[LIndex].Path);
          Need((LowerCase(ExtractFileExt(LFiles[LIndex].Name)) = '.wav') and
            FileExists(LFiles[LIndex].Path), 'Selected library original is unavailable');
          LStream := TFileStream.Create(LFiles[LIndex].Path, fmOpenRead or fmShareDenyWrite);
          try
            Need((LStream.Size = LFiles[LIndex].Bytes) and (LStream.Size >= 44) and
              (LStream.Size <= MaximumLibrarySourceBytes),
              'Selected library original byte count changed');
          finally
            LStream.Free;
          end;
          Need(LSelectedBytes <= MaximumLibraryAggregateBytes - LFiles[LIndex].Bytes,
            'Selected library aggregate byte bound exceeded');
          Inc(LSelectedBytes, LFiles[LIndex].Bytes);
          for LOther := 0 to LIndex - 1 do
          begin
            Need(not SameText(LFiles[LOther].Path, LFiles[LIndex].Path),
              'Selected library entry is repeated');
          end;
          if LNames.IndexOf(LFiles[LIndex].CollectionName) < 0 then
          begin
            LNames.Add(LFiles[LIndex].CollectionName);
          end;
          LFiles[LIndex].Hash := '';
        end;
      end
      else
      begin
        Progress(AProgress, 'discovering', 0, 0);
        Discover(LLibrary, LNames, LFiles, LUnsupported);
        MarkMissing(Result);
      end;
      Result.Integers['changed_count'] := 0;
      for LIndex := 0 to LNames.Count - 1 do
      begin
        Collection(Result, LNames[LIndex]).Strings['status'] := 'available';
      end;
      for LIndex := 0 to High(LFiles) do
      begin
        Progress(AProgress, 'hashing_sources', LIndex, Length(LFiles));
        LFiles[LIndex].Hash := FileHash(LFiles[LIndex].Path, LFiles[LIndex].Bytes,
          AProgress, 'hashing_source_bytes');
        if SourceChanged(LPrevious, LFiles[LIndex]) then
        begin
          Result.Integers['changed_count'] := Result.Integers['changed_count'] + 1;
        end;
        if ASelective then
        begin
          LMembers := Collection(Result, LFiles[LIndex].CollectionName).Arrays['memberships'];
          for LOther := 0 to LMembers.Count - 1 do
          begin
            if LMembers.Objects[LOther].Strings['original_name'] = LFiles[LIndex].Name then
            begin
              LMembers.Objects[LOther].Strings['status'] := 'missing';
            end;
          end;
        end;
        AddMembership(Result, LFiles[LIndex]);
      end;
      Summarize(Result);
      LNewSources := 0;
      for LIndex := 0 to High(LFiles) do
      begin
        if (LCatalogHashes.IndexOf(LFiles[LIndex].Hash) < 0) and
          (LHashes.IndexOf(LFiles[LIndex].Hash) < 0) then
        begin
          LHashes.Add(LFiles[LIndex].Hash);
          Inc(LNewSources);
        end;
      end;
      Need(LCatalogHashes.Count + LNewSources <= 4096,
        'New library sources exceed the catalog capacity');
      LHashes.Clear;
      LManifest := TJSONObject.Create;
      LManifest.Add('version', 1);
      LEntries := TJSONArray.Create;
      LManifest.Add('tracks', LEntries);
      Result.Integers['imported_count'] := 0;
      Result.Integers['existing_count'] := 0;
      for LIndex := 0 to High(LFiles) do
      begin
        if LHashes.IndexOf(LFiles[LIndex].Hash) < 0 then
        begin
          LEntry := ManifestEntry(LCatalog, LFiles[LIndex]);
          try
            if LCatalogHashes.IndexOf(LFiles[LIndex].Hash) >= 0 then
            begin
              Progress(AProgress, 'verifying_existing_sources', LIndex, Length(LFiles));
              LExistingRecords.Add(LFiles[LIndex].Hash + '=' +
                VerifyExisting(LCatalog, LFiles[LIndex], LCatalogHashes, AProgress));
              Result.Integers['existing_count'] := Result.Integers['existing_count'] + 1;
            end
            else
            begin
              LFileName := LEntry.Strings['file'];
              Need(SafeComponent(LFileName) and (Length(LFileName) <= 128),
                'Catalog filename is unsupported for library staging');
              LInbox := LStage + LFiles[LIndex].Hash + PathDelim;
              Need(ForceDirectories(LInbox), 'Library source stage could not be created');
              Progress(AProgress, 'staging_sources', LIndex, Length(LFiles));
              CopySource(LFiles[LIndex], LInbox + LFileName, AProgress);
              WriteInbox(LEntry, LInbox);
              LEntries.Add(LEntry);
              LEntry := nil;
            end;
          finally
            LEntry.Free;
          end;
          LHashes.Add(LFiles[LIndex].Hash);
        end;
      end;
      LUnique := LHashes.Count;
      Result.Integers['duplicate_file_count'] := Length(LFiles) - LUnique;
      Result.Integers['unsupported_count'] := LUnsupported;
      Result.Integers['failed_count'] := 0;
      for LIndex := 0 to LEntries.Count - 1 do
      begin
        LInbox := LStage + LEntries.Objects[LIndex].Strings['sha256'] + PathDelim;
        Progress(AProgress, 'importing_sources', LIndex, LUnique);
        LReport := ImportLabelInbox(LInbox, LCatalog);
        try
          WriteNew(LInbox + 'import-report.json', LReport.AsJSON + #10);
          Need(LReport.Integers['failed'] = 0,
            'Library import failed; prior index preserved and stage report retained');
          Result.Integers['imported_count'] := Result.Integers['imported_count'] +
            LReport.Integers['imported'];
          Result.Integers['existing_count'] := Result.Integers['existing_count'] +
            LReport.Integers['duplicate'];
        finally
          LReport.Free;
        end;
      end;
      for LIndex := 0 to High(LFiles) do
      begin
        Progress(AProgress, 'verifying_sources', LIndex, Length(LFiles));
        Need(FileHash(LFiles[LIndex].Path, LFiles[LIndex].Bytes,
          AProgress, 'verifying_original_bytes') = LFiles[LIndex].Hash,
          'Original library source changed during refresh');
      end;
      Result.Integers['revision'] := LRevision;
      Result.Delete('index_sha256');
      Result.Add('index_sha256', HashText(Result.AsJSON));
      ValidateIndex(Result, LRevision);
      Need(Length(Result.AsJSON) + 1 <= MaximumLibraryIndexBytes,
        'Library index exceeds its byte bound');
      LFinal := IncludeTrailingPathDelimiter(LRoot) +
        'revision-' + Format('%.6d', [LRevision]) + '.json';
      LPartial := LFinal + '.partial';
      Progress(AProgress, 'publishing_index', LUnique, LUnique);
      for LIndex := 0 to LExistingRecords.Count - 1 do
      begin
        LTrack := ReadCatalogTrack(LCatalog, LExistingRecords.Names[LIndex]);
        try
          Need(HashText(LTrack.AsJSON) = LExistingRecords.ValueFromIndex[LIndex],
            'Existing catalog metadata changed before index publication');
        finally
          LTrack.Free;
        end;
      end;
      WriteNew(LPartial, Result.AsJSON + #10);
      Need(not FileExists(LFinal) and RenameFile(LPartial, LFinal),
        'Library index could not be published');
      if ASelective then
      begin
        LPrepared := TJSONArray.Create;
        Result.Add('prepared_sources', LPrepared);
        for LIndex := 0 to High(LFiles) do
        begin
          LRow := TJSONObject.Create;
          LRow.Add('collection_name', LFiles[LIndex].CollectionName);
          LRow.Add('original_name', LFiles[LIndex].Name);
          LRow.Add('source_sha256', LFiles[LIndex].Hash);
          if LCatalogHashes.IndexOf(LFiles[LIndex].Hash) >= 0 then
            LRow.Add('status', 'existing')
          else
            LRow.Add('status', 'imported');
          LPrepared.Add(LRow);
        end;
      end;
    except
      Result.Free;
      Result := nil;
      raise;
    end;
  finally
    LManifest.Free;
    LPrevious.Free;
    LCatalogHashes.Free;
    LExistingRecords.Free;
    LHashes.Free;
    LNames.Free;
    RemoveDir(LLock);
  end;
end;

function RefreshStudioLibrary(const ACatalogRoot, ALibraryRoot, AStageRoot: String;
  const AProgress: TStudioLibraryProgress): TJSONObject;
begin
  EnterCriticalSection(GLibraryLock);
  try
    Result := RefreshLocked(ACatalogRoot, ALibraryRoot, AStageRoot, AProgress, nil, False);
  finally
    LeaveCriticalSection(GLibraryLock);
  end;
end;

function PrepareStudioLibraryFiles(const ACatalogRoot, ALibraryRoot, AStageRoot: String;
  const AFiles: TStudioLibraryFiles; const AProgress: TStudioLibraryProgress): TJSONObject;
begin
  EnterCriticalSection(GLibraryLock);
  try
    Result := RefreshLocked(ACatalogRoot, ALibraryRoot, AStageRoot, AProgress, AFiles, True);
  finally
    LeaveCriticalSection(GLibraryLock);
  end;
end;

initialization
  InitCriticalSection(GLibraryLock);
finalization
  DoneCriticalSection(GLibraryLock);
end.
