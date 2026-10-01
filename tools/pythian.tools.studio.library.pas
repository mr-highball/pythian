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

{ Worker-only bounded discovery/import. AStageRoot must be a fresh directory,
  separate from library and catalog; failed stages remain for diagnosis.
  Progress callbacks may raise to cancel. No audio learning or admission occurs.
  Input copying, source integrity checks and the maintained importer make
  multiple full reads; byte caps describe input size, not total storage I/O.
  Results are owned, path-free JSON. Partial imports may survive failed refresh;
  the previously published index remains unchanged. }
function RefreshStudioLibrary(const ACatalogRoot, ALibraryRoot, AStageRoot: String;
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
  pythian.tools.annotations.catalog
  {$IFDEF MSWINDOWS}, Windows{$ENDIF};

const
  CMaximumEntries = 4096;

type
  TLibraryFile = record
    Path: String;
    Name: String;
    CollectionName: String;
    Hash: String;
    Bytes: Int64;
  end;
  TLibraryFiles = array of TLibraryFile;

var
  GLibraryLock: TRTLCriticalSection;

procedure Need(const ACondition: Boolean; const AMessage: String);
begin
  if not ACondition then
  begin
    raise EAudio.Create(AMessage);
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

function FileHash(const APath: String; const ABytes: Int64): String;
var
  LStream: TFileStream;
begin
  CheckPath(APath);
  LStream := TFileStream.Create(APath, fmOpenRead or fmShareDenyWrite);
  try
    Need(LStream.Size = ABytes, 'Library source size changed during refresh');
    Result := Sha256Stream(LStream, LStream.Size);
  finally
    LStream.Free;
  end;
end;

procedure CopySource(const AFile: TLibraryFile; const ATarget: String);
var
  LInput: TFileStream;
  LOutput: TFileStream;
begin
  CheckPath(AFile.Path);
  CheckPath(ATarget);
  Need(not FileExists(ATarget), 'Library staging name conflicts');
  LInput := TFileStream.Create(AFile.Path, fmOpenRead or fmShareDenyWrite);
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
  Need(FileHash(ATarget, AFile.Bytes) = AFile.Hash,
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
  const AProgress: TStudioLibraryProgress): TJSONObject;
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
  LManifest: TJSONObject;
  LPrevious: TJSONObject;
  LEntries: TJSONArray;
  LEntry: TJSONObject;
  LReport: TJSONObject;
  LIndex: Integer;
  LUnsupported: Integer;
  LRevision: Integer;
  LUnique: Integer;
  LNewSources: Integer;
  LFileName: String;
  LInbox: String;
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
  LManifest := nil;
  LPrevious := nil;
  try
    try
      Result := ListStudioLibrary(LCatalog);
      LPrevious := TJSONObject(Result.Clone);
      CatalogInventory(LCatalog, LCatalogHashes);
      LRevision := Result.Integers['revision'] + 1;
      Need(LRevision <= MaximumLibraryRevisions, 'Library revision bound exceeded');
      Progress(AProgress, 'discovering', 0, 0);
      Discover(LLibrary, LNames, LFiles, LUnsupported);
      MarkMissing(Result);
      Result.Integers['changed_count'] := 0;
      for LIndex := 0 to LNames.Count - 1 do
      begin
        Collection(Result, LNames[LIndex]).Strings['status'] := 'available';
      end;
      for LIndex := 0 to High(LFiles) do
      begin
        Progress(AProgress, 'hashing_sources', LIndex, Length(LFiles));
        LFiles[LIndex].Hash := FileHash(LFiles[LIndex].Path, LFiles[LIndex].Bytes);
        if SourceChanged(LPrevious, LFiles[LIndex]) then
        begin
          Result.Integers['changed_count'] := Result.Integers['changed_count'] + 1;
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
      Need(ForceDirectories(LStage), 'Library stage could not be created');
      LManifest := TJSONObject.Create;
      LManifest.Add('version', 1);
      LEntries := TJSONArray.Create;
      LManifest.Add('tracks', LEntries);
      for LIndex := 0 to High(LFiles) do
      begin
        if LHashes.IndexOf(LFiles[LIndex].Hash) < 0 then
        begin
          LEntry := ManifestEntry(LCatalog, LFiles[LIndex]);
          LEntries.Add(LEntry);
          LFileName := LEntry.Strings['file'];
          Need(SafeComponent(LFileName) and (Length(LFileName) <= 128),
            'Existing catalog filename is unsupported for library staging');
          LInbox := LStage + LFiles[LIndex].Hash + PathDelim;
          Need(ForceDirectories(LInbox), 'Library source stage could not be created');
          Progress(AProgress, 'staging_sources', LIndex, Length(LFiles));
          CopySource(LFiles[LIndex], LInbox + LFileName);
          WriteInbox(LEntry, LInbox);
          LHashes.Add(LFiles[LIndex].Hash);
        end;
      end;
      LUnique := LEntries.Count;
      Result.Integers['imported_count'] := 0;
      Result.Integers['existing_count'] := 0;
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
        Need(FileHash(LFiles[LIndex].Path, LFiles[LIndex].Bytes) = LFiles[LIndex].Hash,
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
      WriteNew(LPartial, Result.AsJSON + #10);
      Need(not FileExists(LFinal) and RenameFile(LPartial, LFinal),
        'Library index could not be published');
    except
      Result.Free;
      Result := nil;
      raise;
    end;
  finally
    LManifest.Free;
    LPrevious.Free;
    LCatalogHashes.Free;
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
    Result := RefreshLocked(ACatalogRoot, ALibraryRoot, AStageRoot, AProgress);
  finally
    LeaveCriticalSection(GLibraryLock);
  end;
end;

initialization
  InitCriticalSection(GLibraryLock);
finalization
  DoneCriticalSection(GLibraryLock);
end.
