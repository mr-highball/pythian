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
unit pythian.tools.annotations.catalog;

{$mode delphi}
{$H+}

interface

uses
  fpjson;

{ Native import boundary. Reviews and Pythian proposals have distinct future
  stores; importing a source never creates a reviewed label. }
function ImportLabelInbox(const AInboxRoot, ACatalogRoot: String): TJSONObject;
function ReadPreparedLabelInbox(const AInboxRoot: String): TJSONObject;
function ListLabelCatalog(const ACatalogRoot: String): TJSONObject;
function ReadCatalogTrack(const ACatalogRoot, AHash: String): TJSONObject;

implementation

uses
  Classes,
  SysUtils,
  jsonparser,
  pythian.audio,
  pythian.hash,
  pythian.wave.read;

const
  CManifestBytes = 1048576;
  CRecordBytes = 65536;
  CMaximumInboxTracks = 256;
  CMaximumCatalogTracks = 4096;
  CMaximumSourceBytes: Int64 = 17179869184;
  CCopyBytes = 65536;

type
  TSourceInfo = record
    Bytes: Int64;
    SampleRate: Integer;
    Channels: Integer;
    Frames: Int64;
    Bits: Integer;
  end;

procedure Need(const ACondition: Boolean; const AMessage: String);
begin
  if not ACondition then
  begin
    raise EAudio.Create(AMessage);
  end;
end;

function ReadBoundedText(const APath: String; const AMaximum: Integer): String;
var
  LStream: TFileStream;
begin
  LStream := TFileStream.Create(APath, fmOpenRead or fmShareDenyWrite);
  try
    Need((LStream.Size > 0) and (LStream.Size <= AMaximum),
      'JSON file exceeds size bound');
    SetLength(Result, Integer(LStream.Size));
    LStream.ReadBuffer(Result[1], Length(Result));
  finally
    LStream.Free;
  end;
end;

function ReadObject(const APath: String; const AMaximum: Integer): TJSONObject;
var
  LData: TJSONData;
begin
  LData := GetJSON(ReadBoundedText(APath, AMaximum));
  if LData.JSONType <> jtObject then
  begin
    LData.Free;
    raise EAudio.Create('Expected JSON object');
  end;
  Result := TJSONObject(LData);
end;

function RequiredText(const AObject: TJSONObject; const AName: String;
  const AMaximum: Integer): String;
var
  LValue: TJSONData;
begin
  LValue := AObject.Find(AName);
  Need((LValue <> nil) and (LValue.JSONType = jtString),
    'Missing or invalid ' + AName);
  Result := LValue.AsString;
  Need((Length(Result) > 0) and (Length(Result) <= AMaximum),
    'Invalid length for ' + AName);
end;

function OptionalText(const AObject: TJSONObject; const AName: String;
  const AMaximum: Integer): String;
var
  LValue: TJSONData;
begin
  LValue := AObject.Find(AName);
  if LValue = nil then
  begin
    Exit('');
  end;
  Need(LValue.JSONType = jtString, 'Invalid ' + AName);
  Result := LValue.AsString;
  Need(Length(Result) <= AMaximum, 'Invalid length for ' + AName);
end;

function SafeName(const AName: String): Boolean;
var
  LIndex: Integer;
begin
  Result := (AName <> '') and (AName <> '.') and (AName <> '..') and
    (Length(AName) <= 128);
  for LIndex := 1 to Length(AName) do
  begin
    if not (AName[LIndex] in ['a'..'z', 'A'..'Z', '0'..'9', '_', '-', '.']) then
    begin
      Exit(False);
    end;
  end;
end;

function ValidHash(const AHash: String): Boolean;
var
  LIndex: Integer;
begin
  Result := Length(AHash) = 64;
  for LIndex := 1 to Length(AHash) do
  begin
    if not (AHash[LIndex] in ['0'..'9', 'a'..'f']) then
    begin
      Exit(False);
    end;
  end;
end;

function NewStagePath(const ADirectory, AExtension: String): String;
var
  LGuid: TGUID;
begin
  Need(CreateGUID(LGuid) = 0, 'Could not create stage identity');
  Result := IncludeTrailingPathDelimiter(ADirectory) +
    GUIDToString(LGuid) + AExtension;
end;

procedure WriteNewText(const APath, AText: String);
var
  LStream: TFileStream;
begin
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

function InspectSource(const APath, AExpectedHash: String): TSourceInfo;
var
  LStream: TFileStream;
  LReader: TWaveFrameReader;
begin
  Result := Default(TSourceInfo);
  LStream := TFileStream.Create(APath, fmOpenRead or fmShareDenyWrite);
  try
    Need((LStream.Size >= 44) and (LStream.Size <= CMaximumSourceBytes),
      'Source WAV exceeds import size bound');
    Result.Bytes := LStream.Size;
    Need(Sha256Stream(LStream, Result.Bytes) = AExpectedHash,
      'Prepared WAV differs from manifest SHA256');
    LStream.Position := 0;
    LReader := TWaveFrameReader.Create(LStream);
    try
      Result.SampleRate := LReader.SampleRate;
      Result.Channels := LReader.Channels;
      Result.Frames := LReader.FrameCount;
      Result.Bits := LReader.BitsPerSample;
      Need(Result.Frames > 0, 'Empty prepared WAV');
    finally
      LReader.Free;
    end;
  finally
    LStream.Free;
  end;
end;

procedure CopyVerifiedSource(const AInputPath, AFinalPath,
  ASourceDirectory, AHash: String; const AExpectedBytes: Int64);
var
  LInput: TFileStream;
  LOutput: TFileStream;
  LStage: String;
  LBuffer: array[0..CCopyBytes - 1] of Byte;
  LRemaining: Int64;
  LCount: Integer;
begin
  if FileExists(AFinalPath) then
  begin
    LInput := TFileStream.Create(AFinalPath, fmOpenRead or fmShareDenyWrite);
    try
      Need((LInput.Size = AExpectedBytes) and
        (Sha256Stream(LInput, LInput.Size) = AHash),
        'Existing catalog WAV differs from source identity');
    finally
      LInput.Free;
    end;
    Exit;
  end;
  LStage := NewStagePath(ASourceDirectory, '.wav.partial');
  try
    LInput := TFileStream.Create(AInputPath, fmOpenRead or fmShareDenyWrite);
    try
      Need(LInput.Size = AExpectedBytes, 'Prepared WAV changed before copy');
      LOutput := TFileStream.Create(LStage, fmCreate or fmShareExclusive);
      try
        LRemaining := AExpectedBytes;
        while LRemaining > 0 do
        begin
          LCount := CCopyBytes;
          if LRemaining < LCount then
          begin
            LCount := Integer(LRemaining);
          end;
          LInput.ReadBuffer(LBuffer[0], LCount);
          LOutput.WriteBuffer(LBuffer[0], LCount);
          Dec(LRemaining, LCount);
        end;
      finally
        LOutput.Free;
      end;
      LInput.Position := 0;
      Need(Sha256Stream(LInput, AExpectedBytes) = AHash,
        'Prepared WAV changed during copy');
    finally
      LInput.Free;
    end;
    LOutput := TFileStream.Create(LStage, fmOpenRead or fmShareDenyWrite);
    try
      Need((LOutput.Size = AExpectedBytes) and
        (Sha256Stream(LOutput, LOutput.Size) = AHash),
        'Copied catalog WAV differs from source identity');
    finally
      LOutput.Free;
    end;
    Need(RenameFile(LStage, AFinalPath), 'Could not publish catalog WAV');
  finally
    if FileExists(LStage) then
    begin
      DeleteFile(LStage);
    end;
  end;
end;

procedure CheckGroupPartition(const ATrackDirectory, AHash, AGroup,
  APartition, AClock: String; const ASampleRate: Integer);
var
  LFound: TSearchRec;
  LMetadata: TJSONObject;
  LStatus: Integer;
begin
  LStatus := FindFirst(IncludeTrailingPathDelimiter(ATrackDirectory) + '*.json',
    faAnyFile, LFound);
  if LStatus <> 0 then
  begin
    Exit;
  end;
  try
    while LStatus = 0 do
    begin
      if (LFound.Attr and faDirectory = 0) and
        (LFound.Name <> AHash + '.json') then
      begin
        LMetadata := ReadObject(IncludeTrailingPathDelimiter(ATrackDirectory) +
          LFound.Name, CRecordBytes);
        try
          if LMetadata.Strings['source_group'] = AGroup then
          begin
            Need(LMetadata.Strings['partition'] = APartition,
              'Source group crosses catalog partitions');
          end;
          if (AClock <> '') and (LMetadata.Strings['clock_id'] = AClock) then
          begin
            Need((LMetadata.Strings['source_group'] = AGroup) and
              (LMetadata.Integers['sample_rate'] = ASampleRate),
              'Shared source clock has incompatible group or sample rate');
          end;
        finally
          LMetadata.Free;
        end;
      end;
      LStatus := FindNext(LFound);
    end;
  finally
    FindClose(LFound);
  end;
end;

function ImportOne(const AEntry: TJSONObject; const AInboxRoot,
  ATrackDirectory, ASourceDirectory: String): String;
var
  LName: String;
  LHash: String;
  LGroup: String;
  LClock: String;
  LPartition: String;
  LTitle: String;
  LProvenance: String;
  LLicense: String;
  LInputPath: String;
  LAssetPath: String;
  LRecordPath: String;
  LStage: String;
  LInfo: TSourceInfo;
  LExisting: TJSONObject;
  LRecord: TJSONObject;
begin
  LName := RequiredText(AEntry, 'file', 128);
  Need(SafeName(LName) and (LowerCase(ExtractFileExt(LName)) = '.wav'),
    'Unsafe prepared WAV name');
  LHash := RequiredText(AEntry, 'sha256', 64);
  Need(ValidHash(LHash), 'Invalid lowercase SHA256');
  LGroup := RequiredText(AEntry, 'source_group', 128);
  Need(SafeName(LGroup), 'Unsafe source group');
  LClock := OptionalText(AEntry, 'clock_id', 128);
  Need((LClock = '') or SafeName(LClock), 'Unsafe shared clock identity');
  LPartition := RequiredText(AEntry, 'partition', 16);
  Need((LPartition = 'training') or (LPartition = 'development') or
    (LPartition = 'evaluation') or (LPartition = 'unassigned'),
    'Invalid catalog partition');
  LTitle := RequiredText(AEntry, 'title', 256);
  LProvenance := RequiredText(AEntry, 'provenance', 512);
  LLicense := RequiredText(AEntry, 'license', 256);
  LInputPath := IncludeTrailingPathDelimiter(AInboxRoot) + LName;
  LInfo := InspectSource(LInputPath, LHash);
  LAssetPath := IncludeTrailingPathDelimiter(ASourceDirectory) + LHash + '.wav';
  LRecordPath := IncludeTrailingPathDelimiter(ATrackDirectory) + LHash + '.json';
  CheckGroupPartition(ATrackDirectory, LHash, LGroup, LPartition,
    LClock, LInfo.SampleRate);
  if FileExists(LRecordPath) then
  begin
    LExisting := ReadObject(LRecordPath, CRecordBytes);
    try
      Need((LExisting.Strings['source_sha256'] = LHash) and
        (LExisting.Int64s['source_bytes'] = LInfo.Bytes) and
        (LExisting.Integers['sample_rate'] = LInfo.SampleRate) and
        (LExisting.Integers['channels'] = LInfo.Channels) and
        (LExisting.Int64s['frame_count'] = LInfo.Frames) and
        (LExisting.Strings['original_name'] = LName) and
        (LExisting.Strings['title'] = LTitle) and
        (LExisting.Strings['source_group'] = LGroup) and
        (LExisting.Strings['clock_id'] = LClock) and
        (LExisting.Strings['partition'] = LPartition) and
        (LExisting.Strings['provenance'] = LProvenance) and
        (LExisting.Strings['license'] = LLicense),
        'Existing catalog record has conflicting source metadata');
    finally
      LExisting.Free;
    end;
    CopyVerifiedSource(LInputPath, LAssetPath, ASourceDirectory,
      LHash, LInfo.Bytes);
    Exit('duplicate');
  end;
  CopyVerifiedSource(LInputPath, LAssetPath, ASourceDirectory,
    LHash, LInfo.Bytes);
  LRecord := TJSONObject.Create;
  try
    LRecord.Add('version', 1);
    LRecord.Add('source_sha256', LHash);
    LRecord.Add('source_bytes', LInfo.Bytes);
    LRecord.Add('sample_rate', LInfo.SampleRate);
    LRecord.Add('channels', LInfo.Channels);
    LRecord.Add('bits_per_sample', LInfo.Bits);
    LRecord.Add('frame_count', LInfo.Frames);
    LRecord.Add('original_name', LName);
    LRecord.Add('title', LTitle);
    LRecord.Add('source_group', LGroup);
    LRecord.Add('clock_id', LClock);
    LRecord.Add('partition', LPartition);
    LRecord.Add('provenance', LProvenance);
    LRecord.Add('license', LLicense);
    LRecord.Add('asset', 'sources/' + LHash + '.wav');
    LStage := NewStagePath(ATrackDirectory, '.json.partial');
    try
      WriteNewText(LStage, LRecord.AsJSON + LineEnding);
      Need(RenameFile(LStage, LRecordPath),
        'Could not publish catalog record');
    finally
      if FileExists(LStage) then
      begin
        DeleteFile(LStage);
      end;
    end;
  finally
    LRecord.Free;
  end;
  Result := 'imported';
end;

function ImportLabelInbox(const AInboxRoot, ACatalogRoot: String): TJSONObject;
var
  LInbox: String;
  LCatalog: String;
  LManifest: TJSONObject;
  LEntries: TJSONArray;
  LRows: TJSONArray;
  LRow: TJSONObject;
  LIndex: Integer;
  LStatus: String;
  LTrackDirectory: String;
  LSourceDirectory: String;
  LImported: Integer;
  LDuplicates: Integer;
  LFailed: Integer;
begin
  LInbox := IncludeTrailingPathDelimiter(ExpandFileName(AInboxRoot));
  LCatalog := IncludeTrailingPathDelimiter(ExpandFileName(ACatalogRoot));
  Need(DirectoryExists(LInbox), 'Prepared inbox does not exist');
  Need(not SameText(LInbox, LCatalog) and
    (Pos(LInbox, LCatalog) <> 1) and (Pos(LCatalog, LInbox) <> 1),
    'Inbox and catalog roots must be separate');
  LManifest := ReadObject(LInbox + 'manifest.json', CManifestBytes);
  try
    Need(LManifest.Integers['version'] = 1, 'Unsupported inbox manifest version');
    Need((LManifest.Find('tracks') <> nil) and
      (LManifest.Find('tracks').JSONType = jtArray),
      'Manifest requires tracks array');
    LEntries := LManifest.Arrays['tracks'];
    Need((LEntries.Count > 0) and (LEntries.Count <= CMaximumInboxTracks),
      'Manifest track count exceeds bounds');
    LTrackDirectory := LCatalog + 'tracks';
    LSourceDirectory := LCatalog + 'sources';
    Need(ForceDirectories(LTrackDirectory) and
      ForceDirectories(LSourceDirectory), 'Could not create catalog directories');
    LRows := TJSONArray.Create;
    Result := TJSONObject.Create;
    Result.Add('version', 1);
    Result.Add('tracks', LRows);
    LImported := 0;
    LDuplicates := 0;
    LFailed := 0;
    try
      for LIndex := 0 to LEntries.Count - 1 do
      begin
        LRow := TJSONObject.Create;
        LRows.Add(LRow);
        LRow.Add('index', LIndex);
        try
          Need(LEntries[LIndex].JSONType = jtObject,
            'Manifest track must be an object');
          LStatus := ImportOne(TJSONObject(LEntries[LIndex]),
            LInbox, LTrackDirectory, LSourceDirectory);
          LRow.Add('status', LStatus);
          if LStatus = 'imported' then
          begin
            Inc(LImported);
          end
          else
          begin
            Inc(LDuplicates);
          end;
        except
          on LError: Exception do
          begin
            LRow.Add('status', 'failed');
            LRow.Add('error', LError.Message);
            Inc(LFailed);
          end;
        end;
      end;
      Result.Add('imported', LImported);
      Result.Add('duplicate', LDuplicates);
      Result.Add('failed', LFailed);
    except
      Result.Free;
      raise;
    end;
  finally
    LManifest.Free;
  end;
end;

function ReadPreparedLabelInbox(const AInboxRoot: String): TJSONObject;
var
  LInbox: String;
  LManifest: TJSONObject;
  LEntries: TJSONArray;
  LRows: TJSONArray;
  LRow: TJSONObject;
  LEntry: TJSONObject;
  LName: String;
  LHash: String;
  LGroup: String;
  LClock: String;
  LPartition: String;
  LIndex: Integer;
begin
  LInbox := IncludeTrailingPathDelimiter(ExpandFileName(AInboxRoot));
  LManifest := ReadObject(LInbox + 'manifest.json', CManifestBytes);
  try
    Need(LManifest.Integers['version'] = 1,
      'Unsupported inbox manifest version');
    Need((LManifest.Find('tracks') <> nil) and
      (LManifest.Find('tracks').JSONType = jtArray),
      'Manifest requires tracks array');
    LEntries := LManifest.Arrays['tracks'];
    Need((LEntries.Count > 0) and
      (LEntries.Count <= CMaximumInboxTracks),
      'Manifest track count exceeds bounds');
    Result := TJSONObject.Create;
    try
      Result.Add('version', 1);
      LRows := TJSONArray.Create;
      Result.Add('tracks', LRows);
      for LIndex := 0 to LEntries.Count - 1 do
      begin
        LRow := TJSONObject.Create;
        LRows.Add(LRow);
        LRow.Add('index', LIndex);
        try
          Need(LEntries[LIndex].JSONType = jtObject,
            'Manifest track must be an object');
          LEntry := LEntries.Objects[LIndex];
          LName := RequiredText(LEntry, 'file', 128);
          Need(SafeName(LName) and
            (LowerCase(ExtractFileExt(LName)) = '.wav'),
            'Unsafe prepared WAV name');
          LHash := RequiredText(LEntry, 'sha256', 64);
          Need(ValidHash(LHash), 'Invalid prepared WAV SHA256');
          LGroup := RequiredText(LEntry, 'source_group', 128);
          Need(SafeName(LGroup), 'Unsafe source group');
          LClock := OptionalText(LEntry, 'clock_id', 128);
          Need((LClock = '') or SafeName(LClock),
            'Unsafe shared clock identity');
          LPartition := RequiredText(LEntry, 'partition', 16);
          Need((LPartition = 'training') or
            (LPartition = 'development') or
            (LPartition = 'evaluation') or
            (LPartition = 'unassigned'),
            'Invalid catalog partition');
          LRow.Add('file', LName);
          LRow.Add('sha256', LHash);
          LRow.Add('title', RequiredText(LEntry, 'title', 256));
          LRow.Add('source_group', LGroup);
          LRow.Add('clock_id', LClock);
          LRow.Add('partition', LPartition);
          LRow.Add('provenance',
            RequiredText(LEntry, 'provenance', 512));
          LRow.Add('license', RequiredText(LEntry, 'license', 256));
          if FileExists(LInbox + LName) then
          begin
            LRow.Add('status', 'prepared_unverified');
          end
          else
          begin
            LRow.Add('status', 'missing');
          end;
        except
          on LError: Exception do
          begin
            LRow.Add('status', 'invalid');
            LRow.Add('error', LError.Message);
          end;
        end;
      end;
      Result.Add('count', LRows.Count);
    except
      Result.Free;
      raise;
    end;
  finally
    LManifest.Free;
  end;
end;

function ListLabelCatalog(const ACatalogRoot: String): TJSONObject;
var
  LTrackDirectory: String;
  LFound: TSearchRec;
  LStatus: Integer;
  LRows: TJSONArray;
  LRecord: TJSONObject;
  LNames: TStringList;
  LIndex: Integer;
begin
  LTrackDirectory := IncludeTrailingPathDelimiter(ExpandFileName(ACatalogRoot)) +
    'tracks';
  Need(DirectoryExists(LTrackDirectory), 'Catalog tracks directory does not exist');
  Result := TJSONObject.Create;
  LRows := TJSONArray.Create;
  Result.Add('version', 1);
  Result.Add('tracks', LRows);
  LNames := TStringList.Create;
  try
    try
      LStatus := FindFirst(IncludeTrailingPathDelimiter(LTrackDirectory) + '*.json',
        faAnyFile, LFound);
      if LStatus <> 0 then
      begin
        Result.Add('count', 0);
        Exit;
      end;
      try
        while LStatus = 0 do
        begin
          if LFound.Attr and faDirectory = 0 then
          begin
            Need(LNames.Count < CMaximumCatalogTracks,
              'Catalog track count exceeds bounds');
            LNames.Add(LFound.Name);
          end;
          LStatus := FindNext(LFound);
        end;
      finally
        FindClose(LFound);
      end;
      LNames.Sort;
      for LIndex := 0 to LNames.Count - 1 do
      begin
        LRecord := ReadObject(IncludeTrailingPathDelimiter(LTrackDirectory) +
          LNames[LIndex], CRecordBytes);
        try
          Need(ValidHash(LRecord.Strings['source_sha256']) and
            (LNames[LIndex] = LRecord.Strings['source_sha256'] + '.json'),
            'Catalog record identity differs from filename');
          LRows.Add(LRecord);
          LRecord := nil;
        finally
          LRecord.Free;
        end;
      end;
      Result.Add('count', LRows.Count);
    except
      Result.Free;
      raise;
    end;
  finally
    LNames.Free;
  end;
end;

function ReadCatalogTrack(const ACatalogRoot, AHash: String): TJSONObject;
var
  LRecordPath: String;
begin
  Need(ValidHash(AHash), 'Invalid catalog source SHA256');
  LRecordPath := IncludeTrailingPathDelimiter(ExpandFileName(ACatalogRoot)) +
    'tracks' + PathDelim + AHash + '.json';
  Result := ReadObject(LRecordPath, CRecordBytes);
  try
    Need((Result.Integers['version'] = 1) and
      (Result.Strings['source_sha256'] = AHash) and
      (Result.Strings['asset'] = 'sources/' + AHash + '.wav'),
      'Catalog record identity or version differs');
  except
    Result.Free;
    raise;
  end;
end;

end.
