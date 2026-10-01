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
unit pythian.tools.studio.&library.discovery;

{$mode delphi}
{$H+}

interface

uses
  Classes,
  fpjson,
  pythian.tools.studio.&library;

const
  StudioLibraryDiscoveryFormat = 'pythian.studio.library.discovery.v1';
  StudioLibraryPreparationFormat = 'pythian.studio.library.preparation.v1';
  StudioLibraryWaveformFormat = 'pythian.studio.library.waveform.v1';
  StudioLibraryPreviewFormat = 'pythian.studio.library.preview.v1';
  MaximumLibraryHeaderReadBytes = 65536;
  MaximumLibraryWaveformBins = 256;
  MaximumLibraryWaveformWindowFrames = 64;
  MaximumLibraryPreviewFrames = 2000000;
  MaximumLibraryPreparedEntries = 32;

{ Borrowed seekable stream; reads only chunk/header structure, never PCM.
  Header reads are counted and limited independently of file length. }
function InspectStudioLibraryHeader(const AStream: TStream): TJSONObject;
{ Discovery performs directory/stat and bounded header work only. Listing
  reads a published snapshot without touching source files. All JSON is owned
  and path-free. Entry and snapshot digests are metadata identities. }
function DiscoverStudioLibrary(const ACatalogRoot, ALibraryRoot: String;
  const AProgress: TStudioLibraryProgress = nil): TJSONObject;
function ReadStudioLibraryDiscovery(const ACatalogRoot: String;
  const ARevision: Integer = 0): TJSONObject;
function ListStudioLibraryDiscovery(const ACatalogRoot: String): TJSONObject;
function ValidateStudioLibraryEntries(const ACatalogRoot: String;
  const ARevision: Integer; const AEntries: TJSONArray): TJSONObject;
{ Full content verification/import applies only to these indexed selections.
  AStageRoot is fresh and separate. Previous corpus/hash snapshots survive. }
function PrepareStudioLibraryEntries(const ACatalogRoot, ALibraryRoot, AStageRoot: String;
  const ARevision: Integer; const AEntries: TJSONArray;
  const AProgress: TStudioLibraryProgress = nil): TJSONObject;
{ Uniform windows sample at most 256*64 PCM frames, not the entire extent.
  No metadata-only digest is accepted as a verified source hash. }
function ReadStudioLibraryWaveform(const ACatalogRoot, ALibraryRoot: String;
  const ARevision: Integer; const AEntryId, ASnapshotSha256: String;
  const AStartFrame, AEndFrame: Int64; const ABins: Integer): TJSONObject;
{ Owned memory stream, exact selected original clock, <=30s/2M frames. Native
  PCM16 re-encoding is a provisional audition. Its hash binds preview bytes,
  never original source content. AMetadata is owned on success, nil on failure. }
function OpenStudioLibraryEntryAudio(const ACatalogRoot, ALibraryRoot: String;
  const ARevision: Integer; const AEntryId, ASnapshotSha256: String;
  const AStartFrame, AEndFrame: Int64; out AMetadata: TJSONObject): TStream;

implementation

uses
  SysUtils,
  Math,
  jsonparser,
  pythian.audio,
  pythian.hash,
  pythian.wave,
  pythian.wave.read
  {$IFDEF MSWINDOWS}, Windows{$ENDIF};

type
  THeaderStream = class(TStream)
  private
    FSource: TStream;
    FTrace: TMemoryStream;
    FReadBytes: Int64;
    FPayloadLimit: Int64;
    FPayloadBytes: Int64;
    FPayload: Boolean;
  public
    constructor Create(const ASource: TStream);
    destructor Destroy; override;
    function Read(var ABuffer; ACount: Longint): Longint; override;
    function Write(const ABuffer; ACount: Longint): Longint; override;
    function Seek(const AOffset: Int64; AOrigin: TSeekOrigin): Int64; override;
    function Digest: String;
    procedure BeginPayload(const AMaximumBytes: Int64);
    property ReadBytes: Int64 read FReadBytes;
    property PayloadBytes: Int64 read FPayloadBytes;
  end;

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

function SafeName(const AText: String): Boolean;
var
  LIndex: Integer;
  LStem: String;
begin
  Result := (Length(AText) >= 1) and (Length(AText) <= 128) and
    (AText <> '.') and (AText <> '..') and (Trim(AText) = AText);
  if not Result then
  begin
    Exit;
  end;
  Result := not (AText[Length(AText)] in ['.', ' ']);
  for LIndex := 1 to Length(AText) do
  begin
    if (Ord(AText[LIndex]) < 32) or (AText[LIndex] in ['/', '\', ':', '*', '?', '"', '<', '>', '|']) then
    begin
      Exit(False);
    end;
  end;
  LStem := UpperCase(ChangeFileExt(AText, ''));
  if (LStem = 'CON') or (LStem = 'PRN') or (LStem = 'AUX') or (LStem = 'NUL') or
    ((Length(LStem) = 4) and (Copy(LStem, 1, 3) = 'COM') and (LStem[4] in ['1'..'9'])) or
    ((Length(LStem) = 4) and (Copy(LStem, 1, 3) = 'LPT') and (LStem[4] in ['1'..'9'])) then
  begin
    Result := False;
  end;
end;

procedure CheckPath(const APath: String);
var
  LPath: String;
  LParent: String;
  LAttributes: Longint;
begin
  LPath := ExcludeTrailingPathDelimiter(ExpandFileName(APath));
  repeat
    LAttributes := FileGetAttr(LPath);
    if LAttributes >= 0 then
    begin
      {$IFDEF MSWINDOWS}
      Need((GetFileAttributes(PChar(LPath)) and FILE_ATTRIBUTE_REPARSE_POINT) = 0,
        'Discovery path contains a linked component');
      {$ELSE}
      Need((LAttributes and faSymLink) = 0, 'Discovery path contains a linked component');
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
  Need(Trim(APath) <> '', 'Discovery root is required');
  Result := IncludeTrailingPathDelimiter(ExpandFileName(APath));
  CheckPath(Result);
end;

function DiscoveryRoot(const ACatalogRoot: String): String;
begin
  Result := RootPath(ACatalogRoot) + 'studio' + PathDelim + 'library-discovery' + PathDelim;
  CheckPath(Result);
end;

function LibraryId(const ALibraryRoot: String): String;
begin
  Result := HashText('pythian.library.configured-root.v1' + #10 + RootPath(ALibraryRoot));
end;

constructor THeaderStream.Create(const ASource: TStream);
begin
  inherited Create;
  Need(ASource <> nil, 'Header source stream is required');
  FSource := ASource;
  FTrace := TMemoryStream.Create;
end;

destructor THeaderStream.Destroy;
begin
  FTrace.Free;
  inherited Destroy;
end;

function THeaderStream.Read(var ABuffer; ACount: Longint): Longint;
var
  LPosition: Int64;
begin
  if FPayload then
  begin
    Need((ACount >= 0) and (ACount <= FPayloadLimit - FPayloadBytes),
      'Audition payload exceeds its bounded read budget');
    Result := FSource.Read(ABuffer, ACount);
    Inc(FPayloadBytes, Result);
    Exit;
  end;
  Need((ACount >= 0) and (ACount <= MaximumLibraryHeaderReadBytes - FReadBytes),
    'WAV header inspection exceeds its bounded read budget');
  LPosition := FSource.Position;
  Result := FSource.Read(ABuffer, ACount);
  Inc(FReadBytes, Result);
  FTrace.WriteBuffer(LPosition, SizeOf(LPosition));
  FTrace.WriteBuffer(Result, SizeOf(Result));
  if Result > 0 then
  begin
    FTrace.WriteBuffer(ABuffer, Result);
  end;
end;

function THeaderStream.Write(const ABuffer; ACount: Longint): Longint;
begin
  Result := 0;
  raise EAudio.Create('Header inspection is read-only');
end;

function THeaderStream.Seek(const AOffset: Int64; AOrigin: TSeekOrigin): Int64;
begin
  Result := FSource.Seek(AOffset, AOrigin);
end;

function THeaderStream.Digest: String;
begin
  FTrace.Position := 0;
  Result := Sha256Stream(FTrace, FTrace.Size);
end;

procedure THeaderStream.BeginPayload(const AMaximumBytes: Int64);
begin
  Need(AMaximumBytes >= 0, 'Invalid audition payload budget');
  FPayloadLimit := AMaximumBytes;
  FPayload := True;
end;

function Header(const AStream: TStream; out AReadBytes: Int64): TJSONObject;
var
  LBounded: THeaderStream;
  LWave: TWaveFrameReader;
begin
  Result := nil;
  AReadBytes := 0;
  LBounded := THeaderStream.Create(AStream);
  try
    LWave := TWaveFrameReader.Create(LBounded);
    try
      Result := TJSONObject.Create;
      Result.Add('sample_rate', LWave.SampleRate);
      Result.Add('channels', LWave.Channels);
      Result.Add('bits_per_sample', LWave.BitsPerSample);
      Result.Add('frame_count', LWave.FrameCount);
      Result.Add('duration_ms', LWave.FrameCount * 1000 div LWave.SampleRate);
      Result.Add('header_sha256', LBounded.Digest);
      Result.Add('header_read_bytes', LBounded.ReadBytes);
    finally
      LWave.Free;
    end;
  finally
    AReadBytes := LBounded.ReadBytes;
    LBounded.Free;
  end;
end;

function InspectStudioLibraryHeader(const AStream: TStream): TJSONObject;
var
  LReadBytes: Int64;
begin
  Result := Header(AStream, LReadBytes);
end;

procedure Fields(const AObject: TJSONObject; const ANames: String);
var
  LIndex: Integer;
begin
  Need(AObject <> nil, 'Discovery object is required');
  for LIndex := 0 to AObject.Count - 1 do
  begin
    Need(Pos(',' + AObject.Names[LIndex] + ',', ',' + ANames + ',') > 0,
      'Unknown discovery field');
  end;
end;

function SnapshotHash(const ARow: TJSONObject): String;
var
  LIdentity: TJSONObject;
begin
  LIdentity := TJSONObject.Create;
  try
    LIdentity.Add('domain', 'pythian.library.entry.metadata.v1');
    LIdentity.Add('entry_id', ARow.Strings['entry_id']);
    LIdentity.Add('source_bytes', ARow.Int64s['source_bytes']);
    LIdentity.Add('modified_stamp', ARow.Int64s['modified_stamp']);
    LIdentity.Add('header_sha256', ARow.Strings['header_sha256']);
    LIdentity.Add('sample_rate', ARow.Integers['sample_rate']);
    LIdentity.Add('channels', ARow.Integers['channels']);
    LIdentity.Add('bits_per_sample', ARow.Integers['bits_per_sample']);
    LIdentity.Add('frame_count', ARow.Int64s['frame_count']);
    LIdentity.Add('status', ARow.Strings['status']);
    Result := HashText(LIdentity.AsJSON);
  finally
    LIdentity.Free;
  end;
end;

function EmptyDiscovery: TJSONObject;
begin
  Result := TJSONObject.Create;
  Result.Add('format', StudioLibraryDiscoveryFormat);
  Result.Add('revision', 0);
  Result.Add('library_id', '');
  Result.Add('collections', TJSONArray.Create);
  Result.Add('entries', TJSONArray.Create);
  Result.Add('collection_count', 0);
  Result.Add('entry_count', 0);
  Result.Add('available_count', 0);
  Result.Add('missing_count', 0);
  Result.Add('unsupported_count', 0);
  Result.Add('header_read_bytes', Int64(0));
  Result.Add('content_read_bytes', Int64(0));
  Result.Add('imported_count', 0);
end;

procedure ValidateDiscovery(const AValue: TJSONObject; const ARevision: Integer);
var
  LCopy: TJSONObject;
  LRows: TJSONArray;
  LCollections: TJSONArray;
  LRow: TJSONObject;
  LIds: TStringList;
  LIndex: Integer;
  LAvailable: Integer;
  LMissing: Integer;
begin
  Fields(AValue, 'format,revision,library_id,collections,entries,collection_count,' +
    'entry_count,available_count,missing_count,unsupported_count,header_read_bytes,' +
    'content_read_bytes,imported_count,index_sha256');
  Need((AValue.Strings['format'] = StudioLibraryDiscoveryFormat) and
    (AValue.Integers['revision'] = ARevision), 'Discovery revision/format is invalid');
  Need(ValidHash(AValue.Strings['index_sha256']) and
    ((ARevision = 0) or ValidHash(AValue.Strings['library_id'])),
    'Discovery metadata identity is invalid');
  LCopy := TJSONObject(AValue.Clone);
  try
    LCopy.Delete('index_sha256');
    Need(HashText(LCopy.AsJSON) = AValue.Strings['index_sha256'],
      'Discovery differs from its metadata digest');
  finally
    LCopy.Free;
  end;
  LRows := AValue.Arrays['entries'];
  LCollections := AValue.Arrays['collections'];
  Need((LRows.Count <= MaximumLibraryFiles) and
    (LCollections.Count <= MaximumLibraryCollections) and
    (LRows.Count = AValue.Integers['entry_count']) and
    (LCollections.Count = AValue.Integers['collection_count']) and
    (AValue.Int64s['header_read_bytes'] >= 0) and
    (AValue.Int64s['header_read_bytes'] <= Int64(MaximumLibraryFiles) *
      MaximumLibraryHeaderReadBytes) and (AValue.Int64s['content_read_bytes'] = 0) and
    (AValue.Integers['imported_count'] = 0), 'Discovery bounds/status are invalid');
  LIds := TStringList.Create;
  try
    for LIndex := 0 to LCollections.Count - 1 do
    begin
      LRow := LCollections.Objects[LIndex];
      Fields(LRow, 'collection_id,name,status');
      Need(SafeName(LRow.Strings['name']) and
        (LRow.Strings['collection_id'] = HashText(LRow.Strings['name'])) and
        ((LRow.Strings['status'] = 'available') or (LRow.Strings['status'] = 'missing')) and
        (LIds.IndexOf(LRow.Strings['collection_id']) < 0), 'Invalid discovery collection');
      LIds.Add(LRow.Strings['collection_id']);
    end;
    LIds.Clear;
    LAvailable := 0;
    LMissing := 0;
    for LIndex := 0 to LRows.Count - 1 do
    begin
      LRow := LRows.Objects[LIndex];
      Fields(LRow, 'entry_id,entry_snapshot_sha256,collection_id,collection_name,original_name,' +
        'source_bytes,modified_stamp,header_sha256,header_read_bytes,sample_rate,channels,' +
        'bits_per_sample,frame_count,duration_ms,status,content_validation,' +
        'previous_source_sha256,preparation_status');
      Need(SafeName(LRow.Strings['collection_name']) and SafeName(LRow.Strings['original_name']) and
        ValidHash(LRow.Strings['entry_id']) and ValidHash(LRow.Strings['entry_snapshot_sha256']) and
        (LRow.Strings['collection_id'] = HashText(LRow.Strings['collection_name'])) and
        (LRow.Strings['entry_id'] = HashText('pythian.library.entry.v1' + #10 +
          AValue.Strings['library_id'] + #10 + LRow.Strings['collection_name'] + #10 +
          LRow.Strings['original_name'])) and (LIds.IndexOf(LRow.Strings['entry_id']) < 0),
        'Invalid or duplicate discovery entry');
      LIds.Add(LRow.Strings['entry_id']);
      Need((LRow.Strings['content_validation'] = 'not_verified') and
        ((LRow.Strings['previous_source_sha256'] = '') or
          ValidHash(LRow.Strings['previous_source_sha256'])) and
        ((LRow.Strings['preparation_status'] = 'not_prepared') or
          (LRow.Strings['preparation_status'] = 'previously_prepared_pending_verification')),
        'Discovery cannot claim content admission');
      Need((LRow.Int64s['header_read_bytes'] >= 0) and
        (LRow.Int64s['header_read_bytes'] <= MaximumLibraryHeaderReadBytes) and
        (SnapshotHash(LRow) = LRow.Strings['entry_snapshot_sha256']),
        'Discovery entry snapshot differs');
      if LRow.Strings['status'] = 'available' then
      begin
        Inc(LAvailable);
        Need((LRow.Int64s['source_bytes'] >= 44) and
          (LRow.Int64s['source_bytes'] <= MaximumLibrarySourceBytes) and
          ValidHash(LRow.Strings['header_sha256']) and (LRow.Int64s['frame_count'] > 0) and
          (LRow.Integers['sample_rate'] > 0) and (LRow.Integers['channels'] in [1, 2]),
          'Available discovery geometry is invalid');
      end
      else if LRow.Strings['status'] = 'missing' then
        Inc(LMissing)
      else
        Need(LRow.Strings['status'] = 'unsupported', 'Invalid discovery status');
    end;
    Need((LAvailable = AValue.Integers['available_count']) and
      (LMissing = AValue.Integers['missing_count']), 'Discovery summary differs');
  finally
    LIds.Free;
  end;
end;

function ReadObject(const APath: String): TJSONObject;
var
  LStream: TFileStream;
  LText: String;
  LData: TJSONData;
  LDepth: Integer;
  LIndex: Integer;
  LString: Boolean;
  LEscape: Boolean;
begin
  CheckPath(APath);
  Need(FileExists(APath), 'Discovery snapshot is unavailable; refresh the library');
  LStream := TFileStream.Create(APath, fmOpenRead or fmShareDenyWrite);
  try
    Need((LStream.Size > 0) and (LStream.Size <= MaximumLibraryIndexBytes),
      'Discovery snapshot size is invalid');
    SetLength(LText, LStream.Size);
    LStream.ReadBuffer(LText[1], Length(LText));
  finally
    LStream.Free;
  end;
  LDepth := 0;
  LString := False;
  LEscape := False;
  for LIndex := 1 to Length(LText) do
  begin
    if LString then
    begin
      if LEscape then
        LEscape := False
      else if LText[LIndex] = '\' then
        LEscape := True
      else if LText[LIndex] = '"' then
        LString := False;
    end
    else if LText[LIndex] = '"' then
      LString := True
    else if LText[LIndex] in ['{', '['] then
    begin
      Inc(LDepth);
      Need(LDepth <= 8, 'Discovery snapshot nesting exceeds bound');
    end
    else if LText[LIndex] in ['}', ']'] then
      Dec(LDepth);
  end;
  LData := GetJSON(LText);
  try
    Need(LData is TJSONObject, 'Discovery snapshot is not an object');
    Result := TJSONObject(LData);
  except
    LData.Free;
    raise;
  end;
end;

function ReadStudioLibraryDiscovery(const ACatalogRoot: String;
  const ARevision: Integer): TJSONObject;
var
  LRoot: String;
  LFound: TSearchRec;
  LCode: Integer;
  LRevision: Integer;
  LNumber: Integer;
  LCount: Integer;
begin
  Need((ARevision >= 0) and (ARevision <= MaximumLibraryRevisions),
    'Discovery revision is outside bounds');
  LRoot := DiscoveryRoot(ACatalogRoot);
  LRevision := ARevision;
  if LRevision = 0 then
  begin
    LCount := 0;
    LCode := FindFirst(LRoot + 'revision-*.json', faAnyFile, LFound);
    if LCode = 0 then
    begin
      try
        while LCode = 0 do
        begin
          Inc(LCount);
          Need((LCount <= MaximumLibraryRevisions) and
            TryStrToInt(Copy(LFound.Name, 10, 6), LNumber) and (LNumber > 0) and
            (LNumber <= MaximumLibraryRevisions) and
            (LFound.Name = 'revision-' + Format('%.6d', [LNumber]) + '.json'),
            'Discovery revision inventory is invalid');
          if LNumber > LRevision then
            LRevision := LNumber;
          LCode := FindNext(LFound);
        end;
      finally
        SysUtils.FindClose(LFound);
      end;
    end;
  end;
  if LRevision = 0 then
  begin
    Result := EmptyDiscovery;
    Result.Add('index_sha256', HashText(Result.AsJSON));
    Exit;
  end;
  Result := ReadObject(LRoot + 'revision-' + Format('%.6d', [LRevision]) + '.json');
  try
    ValidateDiscovery(Result, LRevision);
  except
    Result.Free;
    raise;
  end;
end;

function ListStudioLibraryDiscovery(const ACatalogRoot: String): TJSONObject;
begin
  Result := ReadStudioLibraryDiscovery(ACatalogRoot, 0);
end;

function FindEntry(const AIndex: TJSONObject; const AId: String): TJSONObject;
var
  LIndex: Integer;
begin
  Need(ValidHash(AId), 'Invalid discovered entry identifier');
  for LIndex := 0 to AIndex.Arrays['entries'].Count - 1 do
  begin
    if AIndex.Arrays['entries'].Objects[LIndex].Strings['entry_id'] = AId then
      Exit(AIndex.Arrays['entries'].Objects[LIndex]);
  end;
  raise EAudio.Create('Discovered entry is unavailable; refresh the library');
end;

procedure Notify(const AProgress: TStudioLibraryProgress; const AStage: String;
  const ADone, ATotal: Int64);
begin
  if Assigned(AProgress) then
    AProgress(AStage, ADone, ATotal);
end;

procedure WriteNew(const APath, AText: String);
var
  LStream: TFileStream;
begin
  CheckPath(APath);
  Need(not FileExists(APath), 'Discovery output already exists');
  LStream := TFileStream.Create(APath, fmCreate);
  try
    LStream.WriteBuffer(AText[1], Length(AText));
  finally
    LStream.Free;
  end;
end;

function PreviousSource(const AIndex: TJSONObject; const ACollection, AName: String): String;
var
  LIndex: Integer;
  LOther: Integer;
  LCollection: TJSONObject;
  LRow: TJSONObject;
begin
  Result := '';
  for LIndex := 0 to AIndex.Arrays['collections'].Count - 1 do
  begin
    LCollection := AIndex.Arrays['collections'].Objects[LIndex];
    if LCollection.Strings['name'] = ACollection then
    begin
      for LOther := 0 to LCollection.Arrays['memberships'].Count - 1 do
      begin
        LRow := LCollection.Arrays['memberships'].Objects[LOther];
        if (LRow.Strings['original_name'] = AName) and (LRow.Strings['status'] = 'available') then
          Exit(LRow.Strings['source_sha256']);
      end;
    end;
  end;
end;

function InspectEntry(const ALibraryRoot, ACollection, AName: String;
  out AReadBytes: Int64): TJSONObject;
var
  LPath: String;
  LStream: TFileStream;
  LHeader: TJSONObject;
  LIndex: Integer;
begin
  Need(SafeName(ACollection) and SafeName(AName), 'Discovery naming is unsafe');
  LPath := RootPath(ALibraryRoot) + 'collections' + PathDelim + ACollection + PathDelim + AName;
  CheckPath(LPath);
  Need(FileExists(LPath), 'Discovered original is unavailable; refresh the library');
  Result := TJSONObject.Create;
  LHeader := nil;
  try
    try
      Result.Add('entry_id', HashText('pythian.library.entry.v1' + #10 +
      LibraryId(ALibraryRoot) + #10 + ACollection + #10 + AName));
    Result.Add('collection_id', HashText(ACollection));
    Result.Add('collection_name', ACollection);
    Result.Add('original_name', AName);
    LStream := TFileStream.Create(LPath, fmOpenRead or fmShareDenyWrite);
    try
      Need((LStream.Size >= 44) and (LStream.Size <= MaximumLibrarySourceBytes),
        'Discovered original exceeds its size bound');
      Result.Add('source_bytes', LStream.Size);
      Result.Add('modified_stamp', Int64(FileGetDate(LStream.Handle)));
      LStream.Position := 0;
      AReadBytes := 0;
      try
        LHeader := Header(LStream, AReadBytes);
        Need(LHeader.Int64s['frame_count'] > 0, 'Empty recording is unsupported');
        Result.Add('status', 'available');
      except
        on EAudio do
        begin
          FreeAndNil(LHeader);
          LHeader := TJSONObject.Create;
          LHeader.Add('sample_rate', 0);
          LHeader.Add('channels', 0);
          LHeader.Add('bits_per_sample', 0);
          LHeader.Add('frame_count', Int64(0));
          LHeader.Add('duration_ms', Int64(0));
          LHeader.Add('header_sha256', '');
          LHeader.Add('header_read_bytes', AReadBytes);
          Result.Add('status', 'unsupported');
        end;
      end;
      for LIndex := 0 to LHeader.Count - 1 do
        Result.Add(LHeader.Names[LIndex], LHeader.Items[LIndex].Clone);
    finally
      LStream.Free;
    end;
    Result.Add('content_validation', 'not_verified');
    Result.Add('previous_source_sha256', '');
    Result.Add('preparation_status', 'not_prepared');
    Result.Add('entry_snapshot_sha256', SnapshotHash(Result));
    except
      Result.Free;
      raise;
    end;
  finally
    LHeader.Free;
  end;
end;

procedure ScanNames(const APath: String; const ADirectories: Boolean;
  const ANames: TStringList; var AScanned, AUnsupported: Integer);
var
  LFound: TSearchRec;
  LCode: Integer;
begin
  CheckPath(APath);
  LCode := FindFirst(APath + '*', faAnyFile, LFound);
  if LCode = 0 then
  begin
    try
      while LCode = 0 do
      begin
        if (LFound.Name <> '.') and (LFound.Name <> '..') then
        begin
          Inc(AScanned);
          Need(AScanned <= 4096, 'Discovery entry inventory exceeds bound');
          Need(SafeName(LFound.Name), 'Discovery file name is unsafe');
          CheckPath(APath + LFound.Name);
          if ADirectories then
          begin
            if (LFound.Attr and faDirectory) <> 0 then
              ANames.Add(LFound.Name)
            else
              Inc(AUnsupported);
          end
          else
          begin
            Need((LFound.Attr and faDirectory) = 0, 'Nested library discovery is unsupported');
            if LowerCase(ExtractFileExt(LFound.Name)) = '.wav' then
              ANames.Add(LFound.Name)
            else
              Inc(AUnsupported);
          end;
        end;
        LCode := FindNext(LFound);
      end;
    finally
      SysUtils.FindClose(LFound);
    end;
  end;
  ANames.Sort;
end;

function DiscoverStudioLibrary(const ACatalogRoot, ALibraryRoot: String;
  const AProgress: TStudioLibraryProgress): TJSONObject;
var
  LRoot: String;
  LLibrary: String;
  LLock: String;
  LFinal: String;
  LPrior: TJSONObject;
  LPrepared: TJSONObject;
  LNames: TStringList;
  LFiles: TStringList;
  LIds: TStringList;
  LRow: TJSONObject;
  LCollection: TJSONObject;
  LIndex: Integer;
  LOther: Integer;
  LScanned: Integer;
  LUnsupported: Integer;
  LAvailable: Integer;
  LMissing: Integer;
  LReadBytes: Int64;
  LBytes: Int64;
  LTotalHeader: Int64;
begin
  LRoot := DiscoveryRoot(ACatalogRoot);
  LLibrary := RootPath(ALibraryRoot);
  Need((Pos(LowerCase(RootPath(ACatalogRoot)), LowerCase(LLibrary)) <> 1) and
    (Pos(LowerCase(LLibrary), LowerCase(RootPath(ACatalogRoot))) <> 1),
    'Discovery catalog and library must be separate');
  Need(DirectoryExists(LLibrary + 'collections'), 'Library collections folder is unavailable');
  Need(ForceDirectories(LRoot), 'Discovery snapshot directory could not be created');
  LLock := LRoot + '.write-lock';
  CheckPath(LLock);
  Need(CreateDir(LLock), 'Discovery is busy or has an interrupted writer');
  LPrior := nil;
  LPrepared := nil;
  LNames := TStringList.Create;
  LFiles := TStringList.Create;
  LIds := TStringList.Create;
  Result := nil;
  try
    try
      LPrior := ListStudioLibraryDiscovery(ACatalogRoot);
      LPrepared := ListStudioLibrary(ACatalogRoot);
      Need((LPrior.Integers['revision'] = 0) or
        (LPrior.Strings['library_id'] = LibraryId(LLibrary)),
        'Configured library differs from the retained discovery');
      Result := EmptyDiscovery;
      Result.Integers['revision'] := LPrior.Integers['revision'] + 1;
      Need(Result.Integers['revision'] <= MaximumLibraryRevisions, 'Discovery revision bound reached');
      Result.Strings['library_id'] := LibraryId(LLibrary);
      LScanned := 0;
      LUnsupported := 0;
      LBytes := 0;
      LTotalHeader := 0;
      LAvailable := 0;
      LMissing := 0;
      Notify(AProgress, 'discovering_metadata', 0, 0);
      ScanNames(LLibrary + 'collections' + PathDelim, True, LNames, LScanned, LUnsupported);
      Need(LNames.Count <= MaximumLibraryCollections, 'Discovery collection bound exceeded');
      for LIndex := 0 to LNames.Count - 1 do
      begin
        LCollection := TJSONObject.Create;
        LCollection.Add('collection_id', HashText(LNames[LIndex]));
        LCollection.Add('name', LNames[LIndex]);
        LCollection.Add('status', 'available');
        Result.Arrays['collections'].Add(LCollection);
        LFiles.Clear;
        ScanNames(LLibrary + 'collections' + PathDelim + LNames[LIndex] + PathDelim,
          False, LFiles, LScanned, LUnsupported);
        Need(Result.Arrays['entries'].Count + LFiles.Count <= MaximumLibraryFiles,
          'Discovery recording bound exceeded');
        for LOther := 0 to LFiles.Count - 1 do
        begin
          Notify(AProgress, 'reading_headers', Result.Arrays['entries'].Count, MaximumLibraryFiles);
          LRow := InspectEntry(LLibrary, LNames[LIndex], LFiles[LOther], LReadBytes);
          Result.Arrays['entries'].Add(LRow);
          Need(LBytes <= MaximumLibraryAggregateBytes - LRow.Int64s['source_bytes'],
            'Discovery aggregate original bytes exceed bound');
          Inc(LBytes, LRow.Int64s['source_bytes']);
          Inc(LTotalHeader, LReadBytes);
          LRow.Strings['previous_source_sha256'] :=
            PreviousSource(LPrepared, LNames[LIndex], LFiles[LOther]);
          if LRow.Strings['previous_source_sha256'] <> '' then
            LRow.Strings['preparation_status'] := 'previously_prepared_pending_verification';
          LIds.Add(LRow.Strings['entry_id']);
          if LRow.Strings['status'] = 'available' then
            Inc(LAvailable)
          else
            Inc(LUnsupported);
        end;
      end;
      for LIndex := 0 to LPrior.Arrays['entries'].Count - 1 do
      begin
        LRow := LPrior.Arrays['entries'].Objects[LIndex];
        if LIds.IndexOf(LRow.Strings['entry_id']) < 0 then
        begin
          Need(Result.Arrays['entries'].Count < MaximumLibraryFiles,
            'Retained discovery entry bound exceeded');
          LRow := TJSONObject(LRow.Clone);
          LRow.Strings['status'] := 'missing';
          LRow.Strings['entry_snapshot_sha256'] := SnapshotHash(LRow);
          Result.Arrays['entries'].Add(LRow);
          Inc(LMissing);
        end;
      end;
      for LIndex := 0 to LPrior.Arrays['collections'].Count - 1 do
      begin
        LCollection := LPrior.Arrays['collections'].Objects[LIndex];
        if LNames.IndexOf(LCollection.Strings['name']) < 0 then
        begin
          Need(Result.Arrays['collections'].Count < MaximumLibraryCollections,
            'Retained discovery collection bound exceeded');
          LCollection := TJSONObject(LCollection.Clone);
          LCollection.Strings['status'] := 'missing';
          Result.Arrays['collections'].Add(LCollection);
        end;
      end;
      Result.Integers['collection_count'] := Result.Arrays['collections'].Count;
      Result.Integers['entry_count'] := Result.Arrays['entries'].Count;
      Result.Integers['available_count'] := LAvailable;
      Result.Integers['missing_count'] := LMissing;
      Result.Integers['unsupported_count'] := LUnsupported;
      Result.Int64s['header_read_bytes'] := LTotalHeader;
      Result.Add('index_sha256', HashText(Result.AsJSON));
      ValidateDiscovery(Result, Result.Integers['revision']);
      Need(Length(Result.AsJSON) + 1 <= MaximumLibraryIndexBytes, 'Discovery metadata exceeds bound');
      Notify(AProgress, 'publishing_discovery', LAvailable, LAvailable);
      LFinal := LRoot + 'revision-' + Format('%.6d', [Result.Integers['revision']]) + '.json';
      WriteNew(LFinal + '.partial', Result.AsJSON + #10);
      Need(not FileExists(LFinal) and RenameFile(LFinal + '.partial', LFinal),
        'Discovery snapshot could not be published');
    except
      Result.Free;
      raise;
    end;
  finally
    LIds.Free;
    LFiles.Free;
    LNames.Free;
    LPrepared.Free;
    LPrior.Free;
    RemoveDir(LLock);
  end;
end;

function ValidateStudioLibraryEntries(const ACatalogRoot: String;
  const ARevision: Integer; const AEntries: TJSONArray): TJSONObject;
var
  LIndex: TJSONObject;
  LRow: TJSONObject;
  LWrite: TJSONObject;
  LIds: TStringList;
  LOrdinal: Integer;
  LBytes: Int64;
begin
  Need((ARevision > 0) and (AEntries <> nil) and (AEntries.Count >= 1) and
    (AEntries.Count <= MaximumLibraryPreparedEntries), 'Preparation requires1..32entries');
  LIndex := ReadStudioLibraryDiscovery(ACatalogRoot, ARevision);
  LIds := TStringList.Create;
  Result := nil;
  try
    LBytes := 0;
    for LOrdinal := 0 to AEntries.Count - 1 do
    begin
      Need(AEntries[LOrdinal] is TJSONObject, 'Invalid preparation selection');
      LWrite := AEntries.Objects[LOrdinal];
      Fields(LWrite, 'entry_id,entry_snapshot_sha256');
      LRow := FindEntry(LIndex, LWrite.Strings['entry_id']);
      Need((LRow.Strings['status'] = 'available') and
        ValidHash(LWrite.Strings['entry_snapshot_sha256']) and
        (LWrite.Strings['entry_snapshot_sha256'] = LRow.Strings['entry_snapshot_sha256']) and
        (LIds.IndexOf(LWrite.Strings['entry_id']) < 0), 'Preparation snapshot unavailable or repeated');
      LIds.Add(LWrite.Strings['entry_id']);
      Need(LBytes <= MaximumLibraryAggregateBytes - LRow.Int64s['source_bytes'],
        'Selected preparation byte bound exceeded');
      Inc(LBytes, LRow.Int64s['source_bytes']);
    end;
    Result := TJSONObject.Create;
    Result.Add('discovery_revision', ARevision);
    Result.Add('discovery_index_sha256', LIndex.Strings['index_sha256']);
    Result.Add('selected_entry_count', AEntries.Count);
    Result.Add('selected_source_bytes', LBytes);
    Result.Add('content_validation', 'pending_selected_content_verification');
  finally
    LIds.Free;
    LIndex.Free;
  end;
end;

function EntryPath(const AIndex: TJSONObject; const ALibraryRoot: String;
  const ARow: TJSONObject): String;
begin
  Need(AIndex.Strings['library_id'] = LibraryId(ALibraryRoot),
    'Configured library differs from indexed entry');
  Result := RootPath(ALibraryRoot) + 'collections' + PathDelim +
    ARow.Strings['collection_name'] + PathDelim + ARow.Strings['original_name'];
  CheckPath(Result);
end;

procedure Recheck(const AIndex: TJSONObject; const ALibraryRoot: String;
  const ARow: TJSONObject);
var
  LCurrent: TJSONObject;
  LBytes: Int64;
begin
  EntryPath(AIndex, ALibraryRoot, ARow);
  Need(ARow.Strings['status'] = 'available', 'Discovered recording is unavailable');
  LCurrent := InspectEntry(ALibraryRoot, ARow.Strings['collection_name'],
    ARow.Strings['original_name'], LBytes);
  try
    Need(LCurrent.Strings['entry_snapshot_sha256'] = ARow.Strings['entry_snapshot_sha256'],
      'Original metadata changed; refresh and reopen the recording');
  finally
    LCurrent.Free;
  end;
end;

function PrepareStudioLibraryEntries(const ACatalogRoot, ALibraryRoot, AStageRoot: String;
  const ARevision: Integer; const AEntries: TJSONArray;
  const AProgress: TStudioLibraryProgress): TJSONObject;
var
  LValidation: TJSONObject;
  LIndex: TJSONObject;
  LReport: TJSONObject;
  LFiles: TStudioLibraryFiles;
  LRow: TJSONObject;
  LPrepared: TJSONObject;
  LMapping: TJSONObject;
  LOrdinal: Integer;
begin
  LValidation := ValidateStudioLibraryEntries(ACatalogRoot, ARevision, AEntries);
  LValidation.Free;
  LIndex := ReadStudioLibraryDiscovery(ACatalogRoot, ARevision);
  LReport := nil;
  Result := nil;
  try
    try
      SetLength(LFiles, AEntries.Count);
    for LOrdinal := 0 to AEntries.Count - 1 do
    begin
      LRow := FindEntry(LIndex, AEntries.Objects[LOrdinal].Strings['entry_id']);
      Notify(AProgress, 'checking_selected_metadata', LOrdinal, AEntries.Count);
      Recheck(LIndex, ALibraryRoot, LRow);
      LFiles[LOrdinal].Path := EntryPath(LIndex, ALibraryRoot, LRow);
      LFiles[LOrdinal].Name := LRow.Strings['original_name'];
      LFiles[LOrdinal].CollectionName := LRow.Strings['collection_name'];
      LFiles[LOrdinal].Bytes := LRow.Int64s['source_bytes'];
    end;
    LReport := PrepareStudioLibraryFiles(ACatalogRoot, ALibraryRoot, AStageRoot, LFiles, AProgress);
    for LOrdinal := 0 to AEntries.Count - 1 do
    begin
      LRow := FindEntry(LIndex, AEntries.Objects[LOrdinal].Strings['entry_id']);
      Notify(AProgress, 'rechecking_selected_metadata', LOrdinal, AEntries.Count);
      Recheck(LIndex, ALibraryRoot, LRow);
    end;
    Result := TJSONObject.Create;
    Result.Add('format', StudioLibraryPreparationFormat);
    Result.Add('discovery_revision', ARevision);
    Result.Add('discovery_index_sha256', LIndex.Strings['index_sha256']);
    Result.Add('library_revision', LReport.Integers['revision']);
    Result.Add('content_validation', 'selected_content_verified');
    Result.Add('mappings', TJSONArray.Create);
    for LOrdinal := 0 to AEntries.Count - 1 do
    begin
      LPrepared := LReport.Arrays['prepared_sources'].Objects[LOrdinal];
      LMapping := TJSONObject(AEntries.Objects[LOrdinal].Clone);
      LMapping.Add('source_sha256', LPrepared.Strings['source_sha256']);
      LMapping.Add('status', LPrepared.Strings['status']);
      Result.Arrays['mappings'].Add(LMapping);
    end;
    except
      Result.Free;
      raise;
    end;
  finally
    LReport.Free;
    LIndex.Free;
  end;
end;

function OpenEntry(const ACatalogRoot, ALibraryRoot: String; const ARevision: Integer;
  const AEntryId, ASnapshot: String; out AIndex, ARow: TJSONObject): TFileStream;
begin
  Result := nil;
  AIndex := ReadStudioLibraryDiscovery(ACatalogRoot, ARevision);
  try
    ARow := FindEntry(AIndex, AEntryId);
    Need((ARevision > 0) and ValidHash(ASnapshot) and
      (ASnapshot = ARow.Strings['entry_snapshot_sha256']), 'Invalid audition snapshot');
    Recheck(AIndex, ALibraryRoot, ARow);
    Result := TFileStream.Create(EntryPath(AIndex, ALibraryRoot, ARow),
      fmOpenRead or fmShareDenyWrite);
    Need((Result.Size = ARow.Int64s['source_bytes']) and
      (Int64(FileGetDate(Result.Handle)) = ARow.Int64s['modified_stamp']),
      'Original changed before audition');
  except
    Result.Free;
    AIndex.Free;
    raise;
  end;
end;

function AuditionMetadata(const AFormat: String; const ARevision: Integer;
  const ARow: TJSONObject; const AStart, AEnd: Int64): TJSONObject;
begin
  Result := TJSONObject.Create;
  Result.Add('format', AFormat);
  Result.Add('entry_id', ARow.Strings['entry_id']);
  Result.Add('entry_snapshot_sha256', ARow.Strings['entry_snapshot_sha256']);
  Result.Add('discovery_revision', ARevision);
  Result.Add('source_start_frame', AStart);
  Result.Add('source_end_frame', AEnd);
  Result.Add('source_sample_rate', ARow.Integers['sample_rate']);
  Result.Add('source_channels', ARow.Integers['channels']);
  Result.Add('source_bits_per_sample', ARow.Integers['bits_per_sample']);
  Result.Add('content_validation', 'metadata_only_unverified');
end;

function ReadStudioLibraryWaveform(const ACatalogRoot, ALibraryRoot: String;
  const ARevision: Integer; const AEntryId, ASnapshotSha256: String;
  const AStartFrame, AEndFrame: Int64; const ABins: Integer): TJSONObject;
var
  LIndex: TJSONObject;
  LRow: TJSONObject;
  LBin: TJSONObject;
  LStream: TFileStream;
  LWave: TWaveFrameReader;
  LSamples: TAudioSamples;
  LBounded: THeaderStream;
  LOrdinal: Integer;
  LSample: Integer;
  LCount: Integer;
  LStart: Int64;
  LEnd: Int64;
  LSampled: Int64;
  LSum: Double;
  LPeak: Double;
  LBins: Integer;
begin
  Need((ABins >= 1) and (ABins <= MaximumLibraryWaveformBins) and
    (AStartFrame >= 0) and (AEndFrame > AStartFrame), 'Waveform bounds are invalid');
  LStream := OpenEntry(ACatalogRoot, ALibraryRoot, ARevision, AEntryId,
    ASnapshotSha256, LIndex, LRow);
  Result := nil;
  try
    try
      Need(AEndFrame <= LRow.Int64s['frame_count'], 'Waveform exceeds original extent');
    LBounded := THeaderStream.Create(LStream);
    try
      LWave := TWaveFrameReader.Create(LBounded);
      try
      Need(LBounded.Digest = LRow.Strings['header_sha256'],
        'Original header changed before waveform');
      LBounded.BeginPayload(Int64(MaximumLibraryWaveformBins) *
        MaximumLibraryWaveformWindowFrames * LWave.Channels *
        (LWave.BitsPerSample div 8));
      Result := AuditionMetadata(StudioLibraryWaveformFormat, ARevision, LRow,
        AStartFrame, AEndFrame);
      Result.Add('sample_rate', LWave.SampleRate);
      Result.Add('channels', LWave.Channels);
      Result.Add('sampling', 'uniform_windows');
      Result.Add('bins', TJSONArray.Create);
      LSampled := 0;
      LBins := ABins;
      if AEndFrame - AStartFrame < LBins then
        LBins := AEndFrame - AStartFrame;
      for LOrdinal := 0 to LBins - 1 do
      begin
        LStart := AStartFrame + (AEndFrame - AStartFrame) * LOrdinal div LBins;
        LEnd := AStartFrame + (AEndFrame - AStartFrame) * (LOrdinal + 1) div LBins;
      LCount := MaximumLibraryWaveformWindowFrames;
      if LEnd - LStart < LCount then
        LCount := LEnd - LStart;
        LWave.SeekFrame(LStart);
        LSamples := LWave.ReadFrames(LCount);
        LSum := 0;
        LPeak := 0;
        for LSample := 0 to High(LSamples) do
        begin
          LSum := LSum + Sqr(LSamples[LSample]);
          if Abs(LSamples[LSample]) > LPeak then
            LPeak := Abs(LSamples[LSample]);
        end;
        LBin := TJSONObject.Create;
        LBin.Add('start_frame', LStart);
        LBin.Add('end_frame', LEnd);
        LBin.Add('sampled_start_frame', LStart);
        LBin.Add('sampled_end_frame', LStart + LCount);
        if Length(LSamples) = 0 then
          LBin.Add('rms', 0.0)
        else
          LBin.Add('rms', Sqrt(LSum / Length(LSamples)));
        LBin.Add('peak', LPeak);
        Result.Arrays['bins'].Add(LBin);
        Inc(LSampled, LCount);
      end;
      Result.Add('sampled_frame_count', LSampled);
      Result.Add('payload_read_bytes', LBounded.PayloadBytes);
      finally
        LWave.Free;
      end;
    finally
      LBounded.Free;
    end;
    except
      Result.Free;
      raise;
    end;
  finally
    LStream.Free;
    LIndex.Free;
  end;
end;

function OpenStudioLibraryEntryAudio(const ACatalogRoot, ALibraryRoot: String;
  const ARevision: Integer; const AEntryId, ASnapshotSha256: String;
  const AStartFrame, AEndFrame: Int64; out AMetadata: TJSONObject): TStream;
var
  LIndex: TJSONObject;
  LRow: TJSONObject;
  LStream: TFileStream;
  LWave: TWaveFrameReader;
  LClip: TAudioClip;
  LSamples: TAudioSamples;
  LPart: TAudioSamples;
  LBytes: TAudioBytes;
  LFrames: Integer;
  LDone: Integer;
  LCount: Integer;
  LMemory: TMemoryStream;
  LBounded: THeaderStream;
begin
  AMetadata := nil;
  Result := nil;
  Need((AStartFrame >= 0) and (AEndFrame > AStartFrame) and
    (AEndFrame - AStartFrame <= MaximumLibraryPreviewFrames), 'Preview frame bound exceeded');
  LStream := OpenEntry(ACatalogRoot, ALibraryRoot, ARevision, AEntryId,
    ASnapshotSha256, LIndex, LRow);
  try
    try
      Need((AEndFrame <= LRow.Int64s['frame_count']) and
      (AEndFrame - AStartFrame <= Int64(LRow.Integers['sample_rate']) * 30),
      'Preview exceeds30seconds/originalextent');
    LBounded := THeaderStream.Create(LStream);
    try
      LWave := TWaveFrameReader.Create(LBounded);
      try
      Need(LBounded.Digest = LRow.Strings['header_sha256'],
        'Original header changed before preview');
      LBounded.BeginPayload((AEndFrame - AStartFrame) * LWave.Channels *
        (LWave.BitsPerSample div 8));
      LWave.SeekFrame(AStartFrame);
      LFrames := AEndFrame - AStartFrame;
      SetLength(LSamples, LFrames * LWave.Channels);
      LDone := 0;
      while LDone < LFrames do
      begin
        LCount := Min(4096, LFrames - LDone);
        LPart := LWave.ReadFrames(LCount);
        Need(Length(LPart) = LCount * LWave.Channels, 'Truncated original preview');
        Move(LPart[0], LSamples[LDone * LWave.Channels], Length(LPart) * SizeOf(Single));
        Inc(LDone, LCount);
      end;
      LClip := TAudioClip.Create(LWave.SampleRate, LWave.Channels, LSamples);
      try
        LBytes := EncodeWavePcm16(LClip);
      finally
        LClip.Free;
      end;
      LMemory := TMemoryStream.Create;
      Result := LMemory;
      LMemory.WriteBuffer(LBytes[0], Length(LBytes));
      LMemory.Position := 0;
      AMetadata := AuditionMetadata(StudioLibraryPreviewFormat, ARevision, LRow,
        AStartFrame, AEndFrame);
      AMetadata.Add('preview_frame_count', LFrames);
      AMetadata.Add('preview_sample_rate', LWave.SampleRate);
      AMetadata.Add('preview_channels', LWave.Channels);
      AMetadata.Add('preview_bits_per_sample', 16);
      AMetadata.Add('preview_bytes', LMemory.Size);
      AMetadata.Add('preview_sha256', Sha256Stream(LMemory, LMemory.Size));
      AMetadata.Add('payload_read_bytes', LBounded.PayloadBytes);
      LMemory.Position := 0;
      finally
        LWave.Free;
      end;
    finally
      LBounded.Free;
    end;
    except
      Result.Free;
      AMetadata.Free;
      AMetadata := nil;
      raise;
    end;
  finally
    LStream.Free;
    LIndex.Free;
  end;
end;

end.
