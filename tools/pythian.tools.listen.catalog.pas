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
unit pythian.tools.listen.catalog;

{$mode delphi}
{$H+}

interface

uses
  fpjson;

{ These packets are listening decisions, not source-label reviews. Asset paths
  are derived exclusively from hashes in the private catalog. }
function StageListeningAsset(const ACatalogRoot, AInputPath: String): TJSONObject;
function PublishListeningQueue(const ACatalogRoot,
  AInputPath: String): TJSONObject;
function ReadListeningQueue(const ACatalogRoot: String): TJSONObject;
function CommitListeningReview(const ACatalogRoot: String;
  const ATransaction: TJSONObject): TJSONObject;
function ExportListeningPacket(const ACatalogRoot, AOutputPath: String): TJSONObject;
function InspectListeningPacket(const APacketPath: String): TJSONObject;
function ReplayListeningPacket(const ACatalogRoot, APacketPath: String): TJSONObject;
function ResolveListeningAsset(const ACatalogRoot, ARequestId,
  AAssetId: String): TJSONObject;

implementation

uses
  Classes,
  SysUtils,
  jsonparser,
  {$IFDEF WINDOWS}
  Windows,
  {$ENDIF}
  pythian.audio,
  pythian.hash,
  pythian.wave.read,
  pythian.tools.annotations.catalog,
  pythian.tools.annotations.sourceguard;

const
  CMaximumAssetBytes: Int64 = 17179869184;
  CMaximumQueueBytes = 1048576;
  CMaximumPacketBytes = 4194304;
  CMaximumTransactionBytes = 32768;
  CMaximumItems = 256;
  CMaximumRanges = 32;
  CMaximumDimensions = 16;
  CMaximumValues = 32;
  CMaximumComments = 64;
  CMaximumRevision = 100000;
  CCopyBytes = 65536;

type
  TAssetInfo = record
    Bytes: Int64;
    SampleRate: Integer;
    Channels: Integer;
    Frames: Int64;
  end;

procedure Need(const ACondition: Boolean; const AReason: String);
begin
  if not ACondition then
  begin
    raise EAudio.Create('Invalid listening packet: ' + AReason);
  end;
end;

function SafeId(const AValue: String; const AMaximum: Integer): Boolean;
var
  I: Integer;
begin
  Result := (Length(AValue) > 0) and (Length(AValue) <= AMaximum);
  for I := 1 to Length(AValue) do
  begin
    if not (AValue[I] in ['a'..'z', 'A'..'Z', '0'..'9', '_', '-', '.']) then
    begin
      Exit(False);
    end;
  end;
end;

function ValidHash(const AValue: String): Boolean;
var
  I: Integer;
begin
  Result := Length(AValue) = 64;
  for I := 1 to Length(AValue) do
  begin
    if not (AValue[I] in ['0'..'9', 'a'..'f']) then
    begin
      Exit(False);
    end;
  end;
end;

function TextField(const AObject: TJSONObject; const AName: String;
  const AMaximum: Integer): String;
var
  LValue: TJSONData;
begin
  LValue := AObject.Find(AName);
  Need((LValue <> nil) and (LValue.JSONType = jtString),
    'missing or invalid ' + AName);
  Result := LValue.AsString;
  Need((Trim(Result) <> '') and (Length(Result) <= AMaximum),
    'invalid length for ' + AName);
end;

function StringField(const AObject: TJSONObject; const AName: String;
  const AMaximum: Integer): String;
var
  LValue: TJSONData;
begin
  LValue := AObject.Find(AName);
  Need((LValue <> nil) and (LValue.JSONType = jtString),
    'missing or invalid ' + AName);
  Result := LValue.AsString;
  Need(Length(Result) <= AMaximum,
    'invalid length for ' + AName);
end;

function IntegerField(const AObject: TJSONObject; const AName: String): Int64;
var
  LValue: TJSONData;
begin
  LValue := AObject.Find(AName);
  Need((LValue <> nil) and (LValue.JSONType = jtNumber) and
    TryStrToInt64(LValue.AsJSON, Result), 'missing or invalid ' + AName);
end;

function ObjectField(const AObject: TJSONObject; const AName: String): TJSONObject;
var
  LValue: TJSONData;
begin
  LValue := AObject.Find(AName);
  Need((LValue <> nil) and (LValue.JSONType = jtObject),
    'missing or invalid ' + AName);
  Result := TJSONObject(LValue);
end;

function ArrayField(const AObject: TJSONObject; const AName: String): TJSONArray;
var
  LValue: TJSONData;
begin
  LValue := AObject.Find(AName);
  Need((LValue <> nil) and (LValue.JSONType = jtArray),
    'missing or invalid ' + AName);
  Result := TJSONArray(LValue);
end;

procedure CheckFields(const AObject: TJSONObject; const AAllowed: String);
var
  I: Integer;
  J: Integer;
begin
  for I := 0 to AObject.Count - 1 do
  begin
    Need(Pos('|' + AObject.Names[I] + '|', AAllowed) > 0,
      'unsupported field ' + AObject.Names[I]);
    for J := 0 to I - 1 do
    begin
      Need(AObject.Names[J] <> AObject.Names[I],
        'duplicate field ' + AObject.Names[I]);
    end;
  end;
end;

function ReadObject(const APath: String; const AMaximum: Integer): TJSONObject;
var
  LStream: TFileStream;
  LText: String;
  LData: TJSONData;
begin
  LStream := TFileStream.Create(APath, fmOpenRead or fmShareDenyWrite);
  try
    Need((LStream.Size > 0) and (LStream.Size <= AMaximum),
      'JSON file exceeds size bound');
    SetLength(LText, Integer(LStream.Size));
    LStream.ReadBuffer(LText[1], Length(LText));
  finally
    LStream.Free;
  end;
  LData := GetJSON(LText);
  if LData.JSONType <> jtObject then
  begin
    LData.Free;
    Need(False, 'JSON root must be an object');
  end;
  Result := TJSONObject(LData);
end;

procedure CheckNotLink(const APath: String); forward;

function RootPath(const ACatalogRoot: String): String;
begin
  Result := IncludeTrailingPathDelimiter(ExpandFileName(ACatalogRoot));
end;

function ListenPath(const ACatalogRoot: String): String;
begin
  Result := RootPath(ACatalogRoot) + 'listening' + PathDelim;
end;

function QueuePath(const ACatalogRoot: String): String;
begin
  Result := ListenPath(ACatalogRoot) + 'queue.json';
end;

function AssetPath(const ACatalogRoot, AStorage, AHash: String): String;
begin
  Need(ValidHash(AHash), 'invalid asset SHA256');
  if AStorage = 'source' then
  begin
    Result := RootPath(ACatalogRoot) + 'sources' + PathDelim + AHash + '.wav';
  end
  else
  begin
    Need(AStorage = 'listening', 'invalid asset storage');
    Result := ListenPath(ACatalogRoot) + 'assets' + PathDelim + AHash + '.wav';
  end;
end;

function ReviewPath(const ACatalogRoot, AId: String): String;
begin
  Need(SafeId(AId, 128), 'invalid request ID');
  CheckNotLink(RootPath(ACatalogRoot));
  CheckNotLink(ListenPath(ACatalogRoot));
  CheckNotLink(ListenPath(ACatalogRoot) + 'reviews');
  Result := ListenPath(ACatalogRoot) + 'reviews' + PathDelim + AId + PathDelim;
  CheckNotLink(Result);
end;

function RevisionName(const ARevision: Integer): String;
begin
  Result := Format('%.8d.json', [ARevision]);
end;

procedure CheckNotLink(const APath: String);
{$IFDEF WINDOWS}
var
  LAttributes: DWORD;
{$ENDIF}
begin
  {$IFDEF WINDOWS}
  if FileExists(APath) or DirectoryExists(APath) then
  begin
    LAttributes := GetFileAttributes(PChar(APath));
    Need((LAttributes <> INVALID_FILE_ATTRIBUTES) and
      ((LAttributes and FILE_ATTRIBUTE_REPARSE_POINT) = 0),
      'asset storage contains a reparse point');
  end;
  {$ENDIF}
end;

procedure CheckStorage(const ACatalogRoot: String);
var
  LRoot: String;
begin
  LRoot := RootPath(ACatalogRoot);
  Need(DirectoryExists(LRoot), 'catalog root does not exist');
  CheckNotLink(LRoot);
  CheckNotLink(LRoot + 'listening');
  CheckNotLink(LRoot + 'listening' + PathDelim + 'assets');
  Need(ForceDirectories(LRoot + 'listening' + PathDelim + 'assets'),
    'cannot create listening asset directory');
  CheckNotLink(LRoot + 'listening');
  CheckNotLink(LRoot + 'listening' + PathDelim + 'assets');
end;

function InspectWave(const APath, AHash: String;
  const AVerifyHash: Boolean): TAssetInfo;
var
  LStream: TFileStream;
  LReader: TWaveFrameReader;
begin
  Result := Default(TAssetInfo);
  CheckNotLink(APath);
  LStream := TFileStream.Create(APath, fmOpenRead or fmShareDenyWrite);
  try
    Need((LStream.Size >= 44) and (LStream.Size <= CMaximumAssetBytes),
      'asset exceeds WAV size bound');
    Result.Bytes := LStream.Size;
    if AVerifyHash then
    begin
      Need(Sha256Stream(LStream, Result.Bytes) = AHash,
        'asset SHA256 differs from declaration');
    end;
    LStream.Position := 0;
    LReader := TWaveFrameReader.Create(LStream);
    try
      Result.SampleRate := LReader.SampleRate;
      Result.Channels := LReader.Channels;
      Result.Frames := LReader.FrameCount;
      { 1 kHz RIFF PCM is parseable here but Chromium's media demuxer rejects
        it. Keep 8 kHz as a conservative intake floor; browser QA currently
        verifies the positive path at 48 kHz, not every rate above this floor. }
      Need(Result.SampleRate >= 8000,
        'listening WAV sample rate below 8000 Hz is unsupported for browser playback');
      Need(Result.Frames > 0, 'asset WAV has no frames');
    finally
      LReader.Free;
    end;
  finally
    LStream.Free;
  end;
end;

function NewStagePath(const ATarget: String): String;
var
  LGuid: TGUID;
begin
  Need(CreateGUID(LGuid) = 0, 'cannot create stage identity');
  Result := ATarget + '.' + GUIDToString(LGuid) + '.partial';
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

procedure ReplaceFile(const AStage, ATarget: String);
begin
  {$IFDEF WINDOWS}
  Need(MoveFileEx(PChar(AStage), PChar(ATarget), MOVEFILE_REPLACE_EXISTING),
    'cannot publish listening file');
  {$ELSE}
  Need(RenameFile(AStage, ATarget), 'cannot publish listening file');
  {$ENDIF}
end;

function HashJson(const AObject: TJSONObject): String;
var
  LText: String;
  LStream: TStringStream;
begin
  LText := AObject.AsJSON;
  LStream := TStringStream.Create(LText);
  try
    Result := Sha256Stream(LStream, LStream.Size);
  finally
    LStream.Free;
  end;
end;

function StageListeningAsset(const ACatalogRoot, AInputPath: String): TJSONObject;
var
  LInput: TFileStream;
  LOutput: TFileStream;
  LHash: String;
  LPath: String;
  LStage: String;
  LInfo: TAssetInfo;
  LBuffer: array[0..CCopyBytes - 1] of Byte;
  LRead: Integer;
begin
  CheckStorage(ACatalogRoot);
  LInput := TFileStream.Create(ExpandFileName(AInputPath),
    fmOpenRead or fmShareDenyWrite);
  try
    Need((LInput.Size >= 44) and (LInput.Size <= CMaximumAssetBytes),
      'stage WAV exceeds size bound');
    LHash := Sha256Stream(LInput, LInput.Size);
    LPath := AssetPath(ACatalogRoot, 'listening', LHash);
    if not FileExists(LPath) then
    begin
      LStage := NewStagePath(LPath);
      try
        LInput.Position := 0;
        LOutput := TFileStream.Create(LStage, fmCreate or fmShareExclusive);
        try
          repeat
            LRead := LInput.Read(LBuffer, SizeOf(LBuffer));
            if LRead > 0 then
            begin
              LOutput.WriteBuffer(LBuffer, LRead);
            end;
          until LRead = 0;
        finally
          LOutput.Free;
        end;
        LInfo := InspectWave(LStage, LHash, True);
        CheckNotLink(LPath);
        if not FileExists(LPath) then
        begin
          Need(RenameFile(LStage, LPath), 'cannot publish staged asset');
        end;
      finally
        if FileExists(LStage) then
        begin
          SysUtils.DeleteFile(LStage);
        end;
      end;
    end;
    LInfo := InspectWave(LPath, LHash, True);
  finally
    LInput.Free;
  end;
  Result := TJSONObject.Create;
  Result.Add('version', 1);
  Result.Add('sha256', LHash);
  Result.Add('bytes', LInfo.Bytes);
  Result.Add('sample_rate', LInfo.SampleRate);
  Result.Add('channels', LInfo.Channels);
  Result.Add('frames', LInfo.Frames);
end;

function NormalizeProvenance(const AInput: TJSONObject;
  const AStorage, ARole, AHash: String; const ATrack: TJSONObject): TJSONObject;
var
  LHash: String;
begin
  CheckFields(AInput, '|source_sha256|model_sha256|policy_sha256|' +
    'parameter_sha256|split|seed|source_group|clock_id|partition|');
  Result := TJSONObject.Create;
  try
    if AStorage = 'source' then
    begin
      Need((ARole = 'source') or (ARole = 'reference'),
        'catalog source asset has invalid role');
      Need(TextField(AInput, 'source_sha256', 64) = AHash,
        'catalog source provenance hash differs');
      Need(TextField(AInput, 'source_group', 128) =
        ATrack.Strings['source_group'], 'source group differs from catalog');
      Need(StringField(AInput, 'clock_id', 128) =
        ATrack.Strings['clock_id'], 'source clock differs from catalog');
      Need(TextField(AInput, 'partition', 32) =
        ATrack.Strings['partition'], 'source partition differs from catalog');
      Need(AInput.Count = 4, 'source provenance contains unrelated fields');
      Result.Add('source_sha256', AHash);
      Result.Add('source_group', ATrack.Strings['source_group']);
      Result.Add('clock_id', ATrack.Strings['clock_id']);
      Result.Add('partition', ATrack.Strings['partition']);
    end
    else if (ARole = 'generated') or (ARole = 'edited') then
    begin
      Need(AInput.Count = 6, 'generated provenance requires six fields');
      LHash := TextField(AInput, 'source_sha256', 64);
      Need(ValidHash(LHash), 'invalid generated source hash');
      Result.Add('source_sha256', LHash);
      LHash := TextField(AInput, 'model_sha256', 64);
      Need(ValidHash(LHash), 'invalid model hash');
      Result.Add('model_sha256', LHash);
      LHash := TextField(AInput, 'policy_sha256', 64);
      Need(ValidHash(LHash), 'invalid policy hash');
      Result.Add('policy_sha256', LHash);
      LHash := TextField(AInput, 'parameter_sha256', 64);
      Need(ValidHash(LHash), 'invalid parameter hash');
      Result.Add('parameter_sha256', LHash);
      Result.Add('split', TextField(AInput, 'split', 32));
      Need((IntegerField(AInput, 'seed') >= 0) and
        (IntegerField(AInput, 'seed') <= High(Integer)),
        'invalid generated seed');
      Result.Add('seed', IntegerField(AInput, 'seed'));
    end
    else
    begin
      Need(((ARole = 'source') or (ARole = 'reference')) and
        (AInput.Count = 4), 'invalid staged-source provenance');
      LHash := TextField(AInput, 'source_sha256', 64);
      Need(ValidHash(LHash) and (LHash = AHash),
        'staged-source provenance hash differs from WAV');
      Result.Add('source_sha256', LHash);
      Result.Add('source_group', TextField(AInput, 'source_group', 128));
      Result.Add('clock_id', StringField(AInput, 'clock_id', 128));
      Result.Add('partition', TextField(AInput, 'partition', 32));
    end;
  except
    Result.Free;
    raise;
  end;
end;

function NormalizeAsset(const ACatalogRoot: String;
  const AInput: TJSONObject; const AVerifyHash: Boolean): TJSONObject;
var
  LStorage: String;
  LRole: String;
  LHash: String;
  LInfo: TAssetInfo;
  LTrack: TJSONObject;
  LProvenance: TJSONObject;
begin
  CheckFields(AInput, '|id|storage|sha256|role|bytes|sample_rate|' +
    'channels|frames|provenance|');
  Need(SafeId(TextField(AInput, 'id', 64), 64), 'invalid asset ID');
  LStorage := TextField(AInput, 'storage', 16);
  Need((LStorage = 'source') or (LStorage = 'listening'),
    'invalid asset storage');
  LRole := TextField(AInput, 'role', 16);
  Need((LRole = 'source') or (LRole = 'reference') or
    (LRole = 'generated') or (LRole = 'edited'),
    'invalid asset role');
  LHash := TextField(AInput, 'sha256', 64);
  Need(ValidHash(LHash), 'invalid asset hash');
  if LStorage = 'source' then
  begin
    Need((LRole = 'source') or (LRole = 'reference'),
      'catalog source cannot be generated output');
    CheckNotLink(RootPath(ACatalogRoot));
    CheckNotLink(RootPath(ACatalogRoot) + 'sources');
    LTrack := ReadCatalogTrack(ACatalogRoot, LHash);
  end
  else
  begin
    LTrack := nil;
  end;
  try
    if LStorage = 'listening' then
    begin
      CheckStorage(ACatalogRoot);
    end;
    LInfo := InspectWave(AssetPath(ACatalogRoot, LStorage, LHash),
      LHash, AVerifyHash);
    Need((IntegerField(AInput, 'bytes') = LInfo.Bytes) and
      (IntegerField(AInput, 'sample_rate') = LInfo.SampleRate) and
      (IntegerField(AInput, 'channels') = LInfo.Channels) and
      (IntegerField(AInput, 'frames') = LInfo.Frames),
      'asset geometry differs from declaration');
    if LTrack <> nil then
    begin
      Need((LTrack.Strings['source_sha256'] = LHash) and
        (LTrack.Int64s['source_bytes'] = LInfo.Bytes) and
        (LTrack.Integers['sample_rate'] = LInfo.SampleRate) and
        (LTrack.Integers['channels'] = LInfo.Channels) and
        (LTrack.Int64s['frame_count'] = LInfo.Frames),
        'catalog source geometry differs');
    end;
    LProvenance := NormalizeProvenance(
      ObjectField(AInput, 'provenance'), LStorage, LRole, LHash, LTrack);
    Result := TJSONObject.Create;
    try
      Result.Add('id', TextField(AInput, 'id', 64));
      Result.Add('storage', LStorage);
      Result.Add('sha256', LHash);
      Result.Add('role', LRole);
      Result.Add('bytes', LInfo.Bytes);
      Result.Add('sample_rate', LInfo.SampleRate);
      Result.Add('channels', LInfo.Channels);
      Result.Add('frames', LInfo.Frames);
      Result.Add('provenance', LProvenance);
      LProvenance := nil;
    except
      LProvenance.Free;
      Result.Free;
      raise;
    end;
  finally
    LTrack.Free;
  end;
end;

function FindAsset(const AAssets: TJSONArray; const AId: String): TJSONObject;
var
  I: Integer;
  LAsset: TJSONObject;
begin
  Result := nil;
  for I := 0 to AAssets.Count - 1 do
  begin
    LAsset := TJSONObject(AAssets.Items[I]);
    if LAsset.Strings['id'] = AId then
    begin
      Exit(LAsset);
    end;
  end;
end;

function NormalizeRanges(const AInput, AAssets: TJSONArray): TJSONArray;
var
  I: Integer;
  J: Integer;
  LInputRange: TJSONObject;
  LRange: TJSONObject;
  LAsset: TJSONObject;
  LId: String;
  LStart: Int64;
  LEnd: Int64;
begin
  Need((AInput.Count > 0) and (AInput.Count <= CMaximumRanges),
    'invalid listening range count');
  Result := TJSONArray.Create;
  try
    for I := 0 to AInput.Count - 1 do
    begin
      Need(AInput.Items[I].JSONType = jtObject,
        'listening range must be an object');
      LInputRange := TJSONObject(AInput.Items[I]);
      CheckFields(LInputRange, '|asset_id|start_frame|end_frame|');
      LId := TextField(LInputRange, 'asset_id', 64);
      LAsset := FindAsset(AAssets, LId);
      Need(LAsset <> nil, 'range asset is not declared');
      LStart := IntegerField(LInputRange, 'start_frame');
      LEnd := IntegerField(LInputRange, 'end_frame');
      Need((LStart >= 0) and (LEnd > LStart) and
        (LEnd <= LAsset.Int64s['frames']),
        'listening range is outside asset');
      LRange := TJSONObject.Create;
      LRange.Add('asset_id', LId);
      LRange.Add('start_frame', LStart);
      LRange.Add('end_frame', LEnd);
      Result.Add(LRange);
    end;
    for I := 0 to AAssets.Count - 1 do
    begin
      LId := TJSONObject(AAssets.Items[I]).Strings['id'];
      LAsset := nil;
      for J := 0 to Result.Count - 1 do
      begin
        if TJSONObject(Result.Items[J]).Strings['asset_id'] = LId then
        begin
          LAsset := TJSONObject(AAssets.Items[I]);
          Break;
        end;
      end;
      Need(LAsset <> nil, 'every asset needs a listening range');
    end;
  except
    Result.Free;
    raise;
  end;
end;

function NormalizeEvidenceReference(const AInput: TJSONObject): TJSONObject;
var
  LId: String;
  LHash: String;
begin
  CheckFields(AInput, '|evidence_id|evidence_sha256|');
  Need(AInput.Count = 2, 'correspondence evidence reference is incomplete');
  LId := TextField(AInput, 'evidence_id', 128);
  LHash := TextField(AInput, 'evidence_sha256', 64);
  Need(SafeId(LId, 128) and ValidHash(LHash),
    'invalid correspondence evidence identity or SHA256');
  Result := TJSONObject.Create;
  Result.Add('evidence_id', LId);
  Result.Add('evidence_sha256', LHash);
end;

function NormalizeCorrespondenceEvidence(const AInput: TJSONObject;
  const AAssets: TJSONArray): TJSONObject;
var
  LSubject: String;
  LRecording: TJSONObject;
  LEdition: TJSONObject;
  LCut: TJSONObject;
begin
  CheckFields(AInput, '|subject_asset_id|recording|edition|cut|');
  Need(AInput.Count = 4, 'correspondence evidence is incomplete');
  LSubject := TextField(AInput, 'subject_asset_id', 64);
  Need(SafeId(LSubject, 64) and (FindAsset(AAssets, LSubject) <> nil),
    'correspondence subject asset is not declared');
  Result := TJSONObject.Create;
  try
    Result.Add('subject_asset_id', LSubject);
    Result.Add('recording', NormalizeEvidenceReference(
      ObjectField(AInput, 'recording')));
    Result.Add('edition', NormalizeEvidenceReference(
      ObjectField(AInput, 'edition')));
    Result.Add('cut', NormalizeEvidenceReference(
      ObjectField(AInput, 'cut')));
    LRecording := Result.Objects['recording'];
    LEdition := Result.Objects['edition'];
    LCut := Result.Objects['cut'];
    Need((LRecording.Strings['evidence_id'] <>
      LEdition.Strings['evidence_id']) and
      (LRecording.Strings['evidence_id'] <> LCut.Strings['evidence_id']) and
      (LEdition.Strings['evidence_id'] <> LCut.Strings['evidence_id']) and
      (LRecording.Strings['evidence_sha256'] <>
      LEdition.Strings['evidence_sha256']) and
      (LRecording.Strings['evidence_sha256'] <>
      LCut.Strings['evidence_sha256']) and
      (LEdition.Strings['evidence_sha256'] <>
      LCut.Strings['evidence_sha256']),
      'recording, edition and cut need distinct evidence identities');
  except
    Result.Free;
    raise;
  end;
end;

function NormalizeDimension(const AInput: TJSONObject;
  const AChoice: Boolean): TJSONObject;
var
  LValues: TJSONArray;
  LOutputValues: TJSONArray;
  I: Integer;
  J: Integer;
  LValue: String;
  LHasUnknown: Boolean;
begin
  if AChoice then
  begin
    CheckFields(AInput, '|id|values|');
  end
  else
  begin
    CheckFields(AInput, '|id|');
  end;
  Need(SafeId(TextField(AInput, 'id', 64), 64),
    'invalid answer dimension ID');
  Result := TJSONObject.Create;
  try
    Result.Add('id', TextField(AInput, 'id', 64));
    if AChoice then
    begin
      LValues := ArrayField(AInput, 'values');
      Need((LValues.Count >= 2) and (LValues.Count <= CMaximumValues),
        'invalid finite-choice vocabulary size');
      LOutputValues := TJSONArray.Create;
      Result.Add('values', LOutputValues);
      LHasUnknown := False;
      for I := 0 to LValues.Count - 1 do
      begin
        Need(LValues.Items[I].JSONType = jtString,
          'choice value must be text');
        LValue := LValues.Strings[I];
        Need(SafeId(LValue, 64), 'invalid choice value');
        for J := 0 to I - 1 do
        begin
          Need(LValues.Strings[J] <> LValue,
            'duplicate choice value');
        end;
        if LValue = 'unknown' then
        begin
          LHasUnknown := True;
        end;
        LOutputValues.Add(LValue);
      end;
      Need(LHasUnknown, 'choice vocabulary must declare unknown');
    end;
  except
    Result.Free;
    raise;
  end;
end;

function NormalizeSpec(const AInput: TJSONObject): TJSONObject;
var
  LChoices: TJSONArray;
  LScores: TJSONArray;
  LOutput: TJSONArray;
  LDimension: TJSONObject;
  I: Integer;
  J: Integer;
begin
  CheckFields(AInput, '|choices|scores|');
  LChoices := ArrayField(AInput, 'choices');
  LScores := ArrayField(AInput, 'scores');
  Need((LChoices.Count <= CMaximumDimensions) and
    (LScores.Count <= CMaximumDimensions) and
    ((LChoices.Count + LScores.Count) > 0),
    'invalid answer dimension count');
  Result := TJSONObject.Create;
  try
    LOutput := TJSONArray.Create;
    Result.Add('choices', LOutput);
    for I := 0 to LChoices.Count - 1 do
    begin
      Need(LChoices.Items[I].JSONType = jtObject,
        'choice dimension must be an object');
      LDimension := NormalizeDimension(TJSONObject(LChoices.Items[I]), True);
      for J := 0 to LOutput.Count - 1 do
      begin
        Need(TJSONObject(LOutput.Items[J]).Strings['id'] <>
          LDimension.Strings['id'], 'duplicate answer dimension');
      end;
      LOutput.Add(LDimension);
    end;
    LOutput := TJSONArray.Create;
    Result.Add('scores', LOutput);
    for I := 0 to LScores.Count - 1 do
    begin
      Need(LScores.Items[I].JSONType = jtObject,
        'score dimension must be an object');
      LDimension := NormalizeDimension(TJSONObject(LScores.Items[I]), False);
      for J := 0 to LChoices.Count - 1 do
      begin
        Need(TJSONObject(LChoices.Items[J]).Strings['id'] <>
          LDimension.Strings['id'], 'choice and score IDs overlap');
      end;
      for J := 0 to LOutput.Count - 1 do
      begin
        Need(TJSONObject(LOutput.Items[J]).Strings['id'] <>
          LDimension.Strings['id'], 'duplicate answer dimension');
      end;
      LOutput.Add(LDimension);
    end;
  except
    Result.Free;
    raise;
  end;
end;

function NormalizeRequest(const ACatalogRoot: String;
  const AInput: TJSONObject; const AVerifyAssets: Boolean): TJSONObject;
var
  LAssets: TJSONArray;
  LOutputAssets: TJSONArray;
  LOutputRanges: TJSONArray;
  LSpec: TJSONObject;
  LAsset: TJSONObject;
  LKind: String;
  LCorrespondence: Boolean;
  I: Integer;
  J: Integer;
begin
  CheckFields(AInput, '|id|task_id|kind|question|assets|ranges|' +
    'answer_spec|purpose|correspondence_evidence|');
  Need(SafeId(TextField(AInput, 'id', 128), 128), 'invalid request ID');
  Need(SafeId(TextField(AInput, 'task_id', 64), 64),
    'invalid task ID');
  LKind := TextField(AInput, 'kind', 8);
  Need((LKind = 'single') or (LKind = 'pair'),
    'invalid listening request kind');
  LCorrespondence := AInput.Find('purpose') <> nil;
  Need(LCorrespondence = (AInput.Find('correspondence_evidence') <> nil),
    'correspondence purpose and evidence must appear together');
  if LCorrespondence then
  begin
    Need(TextField(AInput, 'purpose', 32) = 'source_correspondence',
      'unsupported listening request purpose');
    Need(LKind = 'pair', 'source correspondence requires a pair');
  end;
  LAssets := ArrayField(AInput, 'assets');
  if LKind = 'single' then
  begin
    Need(LAssets.Count = 1, 'single request needs one asset');
  end
  else
  begin
    Need(LAssets.Count = 2, 'paired request needs two assets');
  end;
  LAsset := nil;
  Result := TJSONObject.Create;
  try
    Result.Add('id', TextField(AInput, 'id', 128));
    Result.Add('task_id', TextField(AInput, 'task_id', 64));
    Result.Add('kind', LKind);
    Result.Add('question', TextField(AInput, 'question', 1024));
    if LCorrespondence then
      Result.Add('purpose', 'source_correspondence');
    LOutputAssets := TJSONArray.Create;
    Result.Add('assets', LOutputAssets);
    for I := 0 to LAssets.Count - 1 do
    begin
      Need(LAssets.Items[I].JSONType = jtObject,
        'asset must be an object');
      LAsset := NormalizeAsset(ACatalogRoot, TJSONObject(LAssets.Items[I]),
        AVerifyAssets);
      for J := 0 to LOutputAssets.Count - 1 do
      begin
        Need(TJSONObject(LOutputAssets.Items[J]).Strings['id'] <>
          LAsset.Strings['id'], 'duplicate asset ID');
      end;
      LOutputAssets.Add(LAsset);
      LAsset := nil;
    end;
    if LCorrespondence then
      Result.Add('correspondence_evidence',
        NormalizeCorrespondenceEvidence(
          ObjectField(AInput, 'correspondence_evidence'), LOutputAssets));
    LOutputRanges := NormalizeRanges(ArrayField(AInput, 'ranges'),
      LOutputAssets);
    Result.Add('ranges', LOutputRanges);
    LSpec := NormalizeSpec(ObjectField(AInput, 'answer_spec'));
    Result.Add('answer_spec', LSpec);
  except
    LAsset.Free;
    Result.Free;
    raise;
  end;
end;

function NormalizeQueue(const ACatalogRoot: String;
  const AInput: TJSONObject; const AVerifyAssets: Boolean): TJSONObject;
var
  LItems: TJSONArray;
  LOutput: TJSONArray;
  LRequest: TJSONObject;
  I: Integer;
  J: Integer;
begin
  CheckFields(AInput, '|version|items|');
  Need(IntegerField(AInput, 'version') = 1,
    'unsupported listening queue version');
  LItems := ArrayField(AInput, 'items');
  Need(LItems.Count <= CMaximumItems, 'too many listening requests');
  LRequest := nil;
  Result := TJSONObject.Create;
  try
    Result.Add('version', 1);
    LOutput := TJSONArray.Create;
    Result.Add('items', LOutput);
    for I := 0 to LItems.Count - 1 do
    begin
      Need(LItems.Items[I].JSONType = jtObject,
        'listening request must be an object');
      LRequest := NormalizeRequest(ACatalogRoot,
        TJSONObject(LItems.Items[I]), AVerifyAssets);
      for J := 0 to LOutput.Count - 1 do
      begin
        Need(TJSONObject(LOutput.Items[J]).Strings['id'] <>
          LRequest.Strings['id'], 'duplicate listening request ID');
      end;
      LOutput.Add(LRequest);
      LRequest := nil;
    end;
  except
    LRequest.Free;
    Result.Free;
    raise;
  end;
end;

function ReadQueueManifest(const ACatalogRoot: String): TJSONObject;
var
  LInput: TJSONObject;
begin
  Need(DirectoryExists(RootPath(ACatalogRoot)),
    'catalog root does not exist');
  CheckNotLink(RootPath(ACatalogRoot));
  CheckNotLink(ListenPath(ACatalogRoot));
  CheckNotLink(QueuePath(ACatalogRoot));
  if not FileExists(QueuePath(ACatalogRoot)) then
  begin
    Result := TJSONObject.Create;
    Result.Add('version', 1);
    Result.Add('items', TJSONArray.Create);
    Exit;
  end;
  LInput := ReadObject(QueuePath(ACatalogRoot), CMaximumQueueBytes);
  try
    Result := NormalizeQueue(ACatalogRoot, LInput, False);
  finally
    LInput.Free;
  end;
end;

function FindRequest(const AQueue: TJSONObject; const AId: String): TJSONObject;
var
  LItems: TJSONArray;
  I: Integer;
begin
  Result := nil;
  LItems := AQueue.Arrays['items'];
  for I := 0 to LItems.Count - 1 do
  begin
    if TJSONObject(LItems.Items[I]).Strings['id'] = AId then
    begin
      Exit(TJSONObject(LItems.Items[I]));
    end;
  end;
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
  LStatus := FindFirst(ADirectory + '*.json', faAnyFile, LFound);
  if LStatus <> 0 then
  begin
    Exit;
  end;
  try
    while LStatus = 0 do
    begin
      if (LFound.Attr and faDirectory) = 0 then
      begin
        Need((Length(LFound.Name) = 13) and
          (Copy(LFound.Name, 9, 5) = '.json') and
          TryStrToInt(Copy(LFound.Name, 1, 8), LRevision) and
          (LRevision > 0) and (LRevision <= CMaximumRevision),
          'invalid listening revision filename');
        Inc(LCount);
        if LRevision > Result then
        begin
          Result := LRevision;
        end;
      end;
      LStatus := FindNext(LFound);
    end;
  finally
    SysUtils.FindClose(LFound);
  end;
  Need(LCount = Result, 'listening revision sequence has a gap');
end;

function ReadEvent(const ADirectory: String; const ARevision: Integer): TJSONObject;
begin
  Result := ReadObject(ADirectory + RevisionName(ARevision),
    CMaximumTransactionBytes);
  try
    CheckFields(Result, '|version|request_id|request_sha256|revision|' +
      'reviewer|status|choices|scores|comments|request|');
    Need((IntegerField(Result, 'version') = 1) and
      (IntegerField(Result, 'revision') = ARevision),
      'listening event revision differs');
    Need(SafeId(TextField(Result, 'request_id', 128), 128) and
      ValidHash(TextField(Result, 'request_sha256', 64)),
      'invalid listening event identity');
  except
    Result.Free;
    raise;
  end;
end;

procedure ValidateStoredEvent(const AEvent, ARequest: TJSONObject); forward;

function ReadListeningQueue(const ACatalogRoot: String): TJSONObject;
var
  LQueue: TJSONObject;
  LItems: TJSONArray;
  LPending: TJSONArray;
  LCompleted: TJSONArray;
  LRequest: TJSONObject;
  LRow: TJSONObject;
  LEvent: TJSONObject;
  LHash: String;
  LRevision: Integer;
  I: Integer;
begin
  LQueue := ReadQueueManifest(ACatalogRoot);
  try
    Result := TJSONObject.Create;
    try
      Result.Add('version', 1);
      LPending := TJSONArray.Create;
      LCompleted := TJSONArray.Create;
      Result.Add('items', LPending);
      Result.Add('completed', LCompleted);
      LItems := LQueue.Arrays['items'];
      for I := 0 to LItems.Count - 1 do
      begin
        LRequest := TJSONObject(LItems.Items[I]);
        LHash := HashJson(LRequest);
        LRevision := LatestRevision(ReviewPath(ACatalogRoot,
          LRequest.Strings['id']));
        LRow := TJSONObject(LRequest.Clone);
        LRow.Add('request_sha256', LHash);
        LRow.Add('revision', LRevision);
        if LRevision > 0 then
        begin
          LEvent := ReadEvent(ReviewPath(ACatalogRoot,
            LRequest.Strings['id']), LRevision);
          try
            ValidateStoredEvent(LEvent, LRequest);
            Need((LEvent.Strings['request_id'] = LRequest.Strings['id']) and
              (LEvent.Strings['request_sha256'] = LHash),
              'review history differs from current listening request');
            LRow.Add('current_reviewer', LEvent.Strings['reviewer']);
            LRow.Add('current_status', LEvent.Strings['status']);
            LRow.Add('current_choices', LEvent.Arrays['choices'].Clone);
            LRow.Add('current_scores', LEvent.Arrays['scores'].Clone);
            LRow.Add('current_comments', LEvent.Arrays['comments'].Clone);
            if LEvent.Strings['status'] = 'submitted' then
            begin
              LCompleted.Add(LRow);
            end
            else
            begin
              LPending.Add(LRow);
            end;
          finally
            LEvent.Free;
          end;
        end
        else
        begin
          LPending.Add(LRow);
        end;
      end;
      Result.Add('waiting_count', LPending.Count);
      Result.Add('completed_count', LCompleted.Count);
    except
      Result.Free;
      raise;
    end;
  finally
    LQueue.Free;
  end;
end;

function PublishListeningQueueLocked(const ACatalogRoot,
  AInputPath: String): TJSONObject;
var
  LInput: TJSONObject;
  LQueue: TJSONObject;
  LOld: TJSONObject;
  LItems: TJSONArray;
  LOldRequest: TJSONObject;
  LNewRequest: TJSONObject;
  LTarget: String;
  LStage: String;
  I: Integer;
begin
  CheckStorage(ACatalogRoot);
  LInput := ReadObject(ExpandFileName(AInputPath), CMaximumQueueBytes);
  try
    LQueue := NormalizeQueue(ACatalogRoot, LInput, True);
  finally
    LInput.Free;
  end;
  try
    LOld := ReadQueueManifest(ACatalogRoot);
    try
      LItems := LOld.Arrays['items'];
      for I := 0 to LItems.Count - 1 do
      begin
        LOldRequest := TJSONObject(LItems.Items[I]);
        if LatestRevision(ReviewPath(ACatalogRoot,
          LOldRequest.Strings['id'])) > 0 then
        begin
          LNewRequest := FindRequest(LQueue, LOldRequest.Strings['id']);
          Need((LNewRequest <> nil) and
            (HashJson(LNewRequest) = HashJson(LOldRequest)),
            'cannot change or remove a reviewed listening request');
        end;
      end;
    finally
      LOld.Free;
    end;
    LTarget := QueuePath(ACatalogRoot);
    CheckNotLink(LTarget);
    LStage := NewStagePath(LTarget);
    try
      WriteNewText(LStage, LQueue.AsJSON + LineEnding);
      ReplaceFile(LStage, LTarget);
    finally
      if FileExists(LStage) then
      begin
        SysUtils.DeleteFile(LStage);
      end;
    end;
  finally
    LQueue.Free;
  end;
  Result := ReadListeningQueue(ACatalogRoot);
end;

function PublishListeningQueue(const ACatalogRoot,
  AInputPath: String): TJSONObject;
var
  LLock: TFileStream;
begin
  CheckStorage(ACatalogRoot);
  CheckNotLink(ListenPath(ACatalogRoot) + 'queue.lock');
  LLock := TFileStream.Create(ListenPath(ACatalogRoot) + 'queue.lock',
    fmCreate or fmShareExclusive);
  try
    Result := PublishListeningQueueLocked(ACatalogRoot, AInputPath);
  finally
    LLock.Free;
  end;
end;

function FindDimension(const AItems: TJSONArray; const AId: String): TJSONObject;
var
  I: Integer;
begin
  Result := nil;
  for I := 0 to AItems.Count - 1 do
  begin
    if TJSONObject(AItems.Items[I]).Strings['id'] = AId then
    begin
      Exit(TJSONObject(AItems.Items[I]));
    end;
  end;
end;

function FindResponse(const AItems: TJSONArray; const AId: String): TJSONObject;
var
  I: Integer;
begin
  Result := nil;
  for I := 0 to AItems.Count - 1 do
  begin
    Need(AItems.Items[I].JSONType = jtObject,
      'answer row must be an object');
    if TextField(TJSONObject(AItems.Items[I]), 'id', 64) = AId then
    begin
      Need(Result = nil, 'duplicate answer dimension');
      Result := TJSONObject(AItems.Items[I]);
    end;
  end;
end;

function NormalizeAnswers(const AInput, ADeclared: TJSONArray;
  const AChoice, ASubmitted: Boolean): TJSONArray;
var
  I: Integer;
  J: Integer;
  LRow: TJSONObject;
  LDeclared: TJSONObject;
  LOutput: TJSONObject;
  LValue: TJSONData;
  LAccepted: Boolean;
  LFound: Boolean;
begin
  Need(AInput.Count <= ADeclared.Count,
    'too many answer rows');
  for I := 0 to AInput.Count - 1 do
  begin
    Need(AInput.Items[I].JSONType = jtObject,
      'answer row must be an object');
    LRow := TJSONObject(AInput.Items[I]);
    CheckFields(LRow, '|id|value|');
    Need(FindDimension(ADeclared, TextField(LRow, 'id', 64)) <> nil,
      'answer dimension is not declared');
    for J := 0 to I - 1 do
    begin
      Need(TJSONObject(AInput.Items[J]).Strings['id'] <>
        LRow.Strings['id'], 'duplicate answer dimension');
    end;
  end;
  Result := TJSONArray.Create;
  try
    for I := 0 to ADeclared.Count - 1 do
    begin
      LDeclared := TJSONObject(ADeclared.Items[I]);
      LRow := FindResponse(AInput, LDeclared.Strings['id']);
      if LRow = nil then
      begin
        Need(not ASubmitted, 'submitted answer omits a dimension');
        Continue;
      end;
      LValue := LRow.Find('value');
      Need(LValue <> nil, 'answer value is missing');
      LOutput := TJSONObject.Create;
      try
        LOutput.Add('id', LDeclared.Strings['id']);
        if AChoice then
        begin
          Need(LValue.JSONType = jtString, 'choice value must be text');
          LAccepted := False;
          for J := 0 to LDeclared.Arrays['values'].Count - 1 do
          begin
            if LDeclared.Arrays['values'].Strings[J] = LValue.AsString then
            begin
              LAccepted := True;
            end;
          end;
          Need(LAccepted, 'choice value is outside declared vocabulary');
          LOutput.Add('value', LValue.AsString);
        end
        else if LValue.JSONType = jtString then
        begin
          Need(LValue.AsString = 'unknown',
            'rubric text must be unknown');
          LOutput.Add('value', 'unknown');
        end
        else
        begin
          LFound := TryStrToInt(LValue.AsJSON, J);
          Need((LValue.JSONType = jtNumber) and LFound and
            (J >= 0) and (J <= 3), 'rubric score must be 0..3 or unknown');
          LOutput.Add('value', J);
        end;
        Result.Add(LOutput);
      except
        LOutput.Free;
        raise;
      end;
    end;
  except
    Result.Free;
    raise;
  end;
end;

function FrameInRanges(const ARanges: TJSONArray; const AAssetId: String;
  const AFrame: Int64): Boolean;
var
  I: Integer;
  LRange: TJSONObject;
begin
  Result := False;
  for I := 0 to ARanges.Count - 1 do
  begin
    LRange := TJSONObject(ARanges.Items[I]);
    if (LRange.Strings['asset_id'] = AAssetId) and
      (AFrame >= LRange.Int64s['start_frame']) and
      (AFrame < LRange.Int64s['end_frame']) then
    begin
      Exit(True);
    end;
  end;
end;

function NormalizeComments(const AInput: TJSONArray;
  const ARequest: TJSONObject): TJSONArray;
var
  I: Integer;
  LInput: TJSONObject;
  LOutput: TJSONObject;
  LAssetId: String;
  LFrame: Int64;
begin
  Need(AInput.Count <= CMaximumComments, 'too many timestamped comments');
  Result := TJSONArray.Create;
  try
    for I := 0 to AInput.Count - 1 do
    begin
      Need(AInput.Items[I].JSONType = jtObject,
        'timestamped comment must be an object');
      LInput := TJSONObject(AInput.Items[I]);
      CheckFields(LInput, '|asset_id|frame|text|');
      LAssetId := TextField(LInput, 'asset_id', 64);
      LFrame := IntegerField(LInput, 'frame');
      Need(FrameInRanges(ARequest.Arrays['ranges'], LAssetId, LFrame),
        'comment frame is outside declared listening range');
      LOutput := TJSONObject.Create;
      LOutput.Add('asset_id', LAssetId);
      LOutput.Add('frame', LFrame);
      LOutput.Add('text', TextField(LInput, 'text', 512));
      Result.Add(LOutput);
    end;
  except
    Result.Free;
    raise;
  end;
end;

function NormalizeResponse(const ATransaction, ARequest: TJSONObject): TJSONObject;
var
  LStatus: String;
  LChoices: TJSONArray;
  LScores: TJSONArray;
  LComments: TJSONArray;
  LInputChoices: TJSONArray;
  LInputScores: TJSONArray;
  LInputComments: TJSONArray;
begin
  CheckFields(ATransaction, '|version|request_id|request_sha256|' +
    'expected_revision|reviewer|status|choices|scores|comments|');
  Need(IntegerField(ATransaction, 'version') = 1,
    'unsupported listening transaction version');
  Need(TextField(ATransaction, 'request_id', 128) = ARequest.Strings['id'],
    'transaction request ID differs');
  Need(TextField(ATransaction, 'request_sha256', 64) = HashJson(ARequest),
    'transaction request hash differs');
  Need((IntegerField(ATransaction, 'expected_revision') >= 0) and
    (IntegerField(ATransaction, 'expected_revision') < CMaximumRevision),
    'invalid expected revision');
  LStatus := TextField(ATransaction, 'status', 16);
  Need((LStatus = 'submitted') or (LStatus = 'withdrawn'),
    'invalid listening decision status');
  LInputChoices := TJSONArray.Create;
  LInputScores := TJSONArray.Create;
  LInputComments := TJSONArray.Create;
  try
    if ATransaction.Find('choices') <> nil then
    begin
      LInputChoices.Free;
      LInputChoices := TJSONArray(ArrayField(ATransaction, 'choices').Clone);
    end;
    if ATransaction.Find('scores') <> nil then
    begin
      LInputScores.Free;
      LInputScores := TJSONArray(ArrayField(ATransaction, 'scores').Clone);
    end;
    if ATransaction.Find('comments') <> nil then
    begin
      LInputComments.Free;
      LInputComments := TJSONArray(ArrayField(ATransaction, 'comments').Clone);
    end;
    LChoices := NormalizeAnswers(LInputChoices,
      ARequest.Objects['answer_spec'].Arrays['choices'], True,
      LStatus = 'submitted');
    try
      LScores := NormalizeAnswers(LInputScores,
        ARequest.Objects['answer_spec'].Arrays['scores'], False,
        LStatus = 'submitted');
      try
        LComments := NormalizeComments(LInputComments, ARequest);
        try
          Result := TJSONObject.Create;
          Result.Add('version', 1);
          Result.Add('request_id', ARequest.Strings['id']);
          Result.Add('request_sha256', HashJson(ARequest));
          Result.Add('reviewer', TextField(ATransaction, 'reviewer', 128));
          Result.Add('status', LStatus);
          Result.Add('choices', LChoices);
          Result.Add('scores', LScores);
          Result.Add('comments', LComments);
          Exit;
        except
          LComments.Free;
          raise;
        end;
      except
        LScores.Free;
        raise;
      end;
    except
      LChoices.Free;
      raise;
    end;
  finally
    LInputChoices.Free;
    LInputScores.Free;
    LInputComments.Free;
  end;
end;

function SameResponse(const AEvent, AResponse: TJSONObject): Boolean;
begin
  Result := (AEvent.Strings['request_id'] =
    AResponse.Strings['request_id']) and
    (AEvent.Strings['request_sha256'] =
    AResponse.Strings['request_sha256']) and
    (AEvent.Strings['reviewer'] = AResponse.Strings['reviewer']) and
    (AEvent.Strings['status'] = AResponse.Strings['status']) and
    (AEvent.Arrays['choices'].AsJSON = AResponse.Arrays['choices'].AsJSON) and
    (AEvent.Arrays['scores'].AsJSON = AResponse.Arrays['scores'].AsJSON) and
    (AEvent.Arrays['comments'].AsJSON = AResponse.Arrays['comments'].AsJSON);
end;

procedure ValidateStoredEvent(const AEvent, ARequest: TJSONObject);
var
  LTransaction: TJSONObject;
  LResponse: TJSONObject;
begin
  Need((AEvent.Strings['request_id'] = ARequest.Strings['id']) and
    (AEvent.Strings['request_sha256'] = HashJson(ARequest)) and
    (ObjectField(AEvent, 'request').AsJSON = ARequest.AsJSON),
    'stored listening event request differs');
  LTransaction := TJSONObject.Create;
  try
    LTransaction.Add('version', 1);
    LTransaction.Add('request_id', ARequest.Strings['id']);
    LTransaction.Add('request_sha256', HashJson(ARequest));
    LTransaction.Add('expected_revision',
      IntegerField(AEvent, 'revision') - 1);
    LTransaction.Add('reviewer', TextField(AEvent, 'reviewer', 128));
    LTransaction.Add('status', TextField(AEvent, 'status', 16));
    LTransaction.Add('choices', ArrayField(AEvent, 'choices').Clone);
    LTransaction.Add('scores', ArrayField(AEvent, 'scores').Clone);
    LTransaction.Add('comments', ArrayField(AEvent, 'comments').Clone);
    LResponse := NormalizeResponse(LTransaction, ARequest);
    try
      Need(SameResponse(AEvent, LResponse),
        'stored listening response is not canonical');
    finally
      LResponse.Free;
    end;
  finally
    LTransaction.Free;
  end;
end;

procedure VerifyRequestAssets(const ACatalogRoot: String;
  const ARequest: TJSONObject);
var
  LAssets: TJSONArray;
  LAsset: TJSONObject;
  LPath: String;
  I: Integer;
begin
  LAssets := ARequest.Arrays['assets'];
  for I := 0 to LAssets.Count - 1 do
  begin
    LAsset := TJSONObject(LAssets.Items[I]);
    LPath := AssetPath(ACatalogRoot, LAsset.Strings['storage'],
      LAsset.Strings['sha256']);
    CheckNotLink(LPath);
    VerifyGuardedSource(LPath, LAsset.Strings['sha256'],
      LAsset.Int64s['bytes']);
  end;
end;

function CommitListeningReviewLocked(const ACatalogRoot: String;
  const ATransaction: TJSONObject): TJSONObject;
var
  LQueue: TJSONObject;
  LRequest: TJSONObject;
  LResponse: TJSONObject;
  LEvent: TJSONObject;
  LDirectory: String;
  LLock: TFileStream;
  LRevision: Integer;
  LExpected: Int64;
  LStage: String;
  LFinal: String;
begin
  Need((ATransaction <> nil) and
    (Length(ATransaction.AsJSON) <= CMaximumTransactionBytes),
    'listening transaction exceeds size bound');
  LQueue := ReadQueueManifest(ACatalogRoot);
  try
    LRequest := FindRequest(LQueue, TextField(ATransaction, 'request_id', 128));
    Need(LRequest <> nil, 'listening request is not published');
    LResponse := NormalizeResponse(ATransaction, LRequest);
    try
      VerifyRequestAssets(ACatalogRoot, LRequest);
      LExpected := IntegerField(ATransaction, 'expected_revision');
      LDirectory := ReviewPath(ACatalogRoot, LRequest.Strings['id']);
      Need(ForceDirectories(LDirectory),
        'cannot create listening review directory');
      LLock := TFileStream.Create(LDirectory + '.lock',
        fmCreate or fmShareExclusive);
      try
        LRevision := LatestRevision(LDirectory);
        if LExpected <> LRevision then
        begin
          if (LRevision = LExpected + 1) and (LRevision > 0) then
          begin
            LEvent := ReadEvent(LDirectory, LRevision);
            try
              if SameResponse(LEvent, LResponse) then
              begin
                Result := TJSONObject(LEvent.Clone);
                Result.Add('already_saved', True);
                Exit;
              end;
            finally
              LEvent.Free;
            end;
          end;
          Need(False, 'listening review revision conflict');
        end;
        LEvent := TJSONObject(LResponse.Clone);
        try
          LEvent.Add('revision', LRevision + 1);
          LEvent.Add('request', LRequest.Clone);
          LFinal := LDirectory + RevisionName(LRevision + 1);
          Need(not FileExists(LFinal), 'listening event already exists');
          LStage := NewStagePath(LFinal);
          try
            WriteNewText(LStage, LEvent.AsJSON + LineEnding);
            Need(RenameFile(LStage, LFinal),
              'cannot publish listening review event');
          finally
            if FileExists(LStage) then
            begin
              SysUtils.DeleteFile(LStage);
            end;
          end;
          Result := TJSONObject(LEvent.Clone);
        finally
          LEvent.Free;
        end;
      finally
        LLock.Free;
      end;
    finally
      LResponse.Free;
    end;
  finally
    LQueue.Free;
  end;
end;

function CommitListeningReview(const ACatalogRoot: String;
  const ATransaction: TJSONObject): TJSONObject;
var
  LLock: TFileStream;
begin
  CheckStorage(ACatalogRoot);
  CheckNotLink(ListenPath(ACatalogRoot) + 'queue.lock');
  LLock := TFileStream.Create(ListenPath(ACatalogRoot) + 'queue.lock',
    fmCreate or fmShareExclusive);
  try
    Result := CommitListeningReviewLocked(ACatalogRoot, ATransaction);
  finally
    LLock.Free;
  end;
end;

function ResolveListeningAsset(const ACatalogRoot, ARequestId,
  AAssetId: String): TJSONObject;
var
  LQueue: TJSONObject;
  LRequest: TJSONObject;
  LAsset: TJSONObject;
begin
  Need(SafeId(ARequestId, 128) and SafeId(AAssetId, 64),
    'invalid listening request or asset ID');
  LQueue := ReadQueueManifest(ACatalogRoot);
  try
    LRequest := FindRequest(LQueue, ARequestId);
    Need(LRequest <> nil, 'listening request is not published');
    LAsset := FindAsset(LRequest.Arrays['assets'], AAssetId);
    Need(LAsset <> nil, 'asset is not declared by listening request');
    Result := TJSONObject.Create;
    try
      Result.Add('path', AssetPath(ACatalogRoot,
        LAsset.Strings['storage'], LAsset.Strings['sha256']));
      Result.Add('sha256', LAsset.Strings['sha256']);
      Result.Add('bytes', LAsset.Int64s['bytes']);
      Result.Add('sample_rate', LAsset.Integers['sample_rate']);
      Result.Add('channels', LAsset.Integers['channels']);
      Result.Add('frames', LAsset.Int64s['frames']);
      Result.Add('request_sha256', HashJson(LRequest));
    except
      Result.Free;
      raise;
    end;
  finally
    LQueue.Free;
  end;
end;

function BuildExport(const ACatalogRoot: String): TJSONObject;
var
  LQueue: TJSONObject;
  LHistory: TJSONArray;
  LGroup: TJSONObject;
  LEvents: TJSONArray;
  LEvent: TJSONObject;
  LRequest: TJSONObject;
  LDirectory: String;
  LRevision: Integer;
  I: Integer;
  J: Integer;
begin
  LQueue := ReadQueueManifest(ACatalogRoot);
  LGroup := nil;
  LEvent := nil;
  Result := TJSONObject.Create;
  try
    Result.Add('version', 1);
    Result.Add('queue', LQueue);
    LQueue := nil;
    LHistory := TJSONArray.Create;
    Result.Add('history', LHistory);
    for I := 0 to Result.Objects['queue'].Arrays['items'].Count - 1 do
    begin
      LRequest := TJSONObject(Result.Objects['queue'].Arrays['items'].Items[I]);
      LDirectory := ReviewPath(ACatalogRoot, LRequest.Strings['id']);
      LRevision := LatestRevision(LDirectory);
      LGroup := TJSONObject.Create;
      LGroup.Add('request_id', LRequest.Strings['id']);
      LEvents := TJSONArray.Create;
      LGroup.Add('events', LEvents);
      for J := 1 to LRevision do
      begin
        LEvent := ReadEvent(LDirectory, J);
        ValidateStoredEvent(LEvent, LRequest);
        LEvents.Add(LEvent);
        LEvent := nil;
      end;
      LHistory.Add(LGroup);
      LGroup := nil;
    end;
    Need(Length(Result.AsJSON) <= CMaximumPacketBytes,
      'listening export exceeds size bound');
  except
    LEvent.Free;
    LGroup.Free;
    LQueue.Free;
    Result.Free;
    raise;
  end;
end;

function ExportListeningPacket(const ACatalogRoot, AOutputPath: String): TJSONObject;
var
  LPacket: TJSONObject;
  LStage: String;
begin
  Need(not FileExists(AOutputPath), 'listening export output already exists');
  LPacket := BuildExport(ACatalogRoot);
  try
    LStage := NewStagePath(ExpandFileName(AOutputPath));
    try
      WriteNewText(LStage, LPacket.AsJSON + LineEnding);
      Need(not FileExists(AOutputPath),
        'listening export output already exists');
      Need(RenameFile(LStage, AOutputPath),
        'cannot publish listening export');
    finally
      if FileExists(LStage) then
      begin
        SysUtils.DeleteFile(LStage);
      end;
    end;
    Result := TJSONObject.Create;
    Result.Add('version', 1);
    Result.Add('requests', LPacket.Objects['queue'].Arrays['items'].Count);
    Result.Add('sha256', HashJson(LPacket));
  finally
    LPacket.Free;
  end;
end;

function ReadExportPacket(const APacketPath: String): TJSONObject;
var
  LQueue: TJSONObject;
  LGroups: TJSONArray;
  LItems: TJSONArray;
  LGroup: TJSONObject;
  LRequest: TJSONObject;
  LEvents: TJSONArray;
  LEvent: TJSONObject;
  LTransaction: TJSONObject;
  LResponse: TJSONObject;
  I: Integer;
  J: Integer;
begin
  Result := ReadObject(APacketPath, CMaximumPacketBytes);
  try
    CheckFields(Result, '|version|queue|history|');
    Need(IntegerField(Result, 'version') = 1,
      'unsupported listening export version');
    LQueue := ObjectField(Result, 'queue');
    CheckFields(LQueue, '|version|items|');
    Need(IntegerField(LQueue, 'version') = 1,
      'unsupported listening queue version');
    LItems := ArrayField(LQueue, 'items');
    LGroups := ArrayField(Result, 'history');
    Need((LItems.Count <= CMaximumItems) and
      (LGroups.Count = LItems.Count),
      'listening export history count differs');
    for I := 0 to LItems.Count - 1 do
    begin
      Need((LItems.Items[I].JSONType = jtObject) and
        (LGroups.Items[I].JSONType = jtObject),
        'invalid listening export row');
      LRequest := TJSONObject(LItems.Items[I]);
      LGroup := TJSONObject(LGroups.Items[I]);
      CheckFields(LGroup, '|request_id|events|');
      Need(TextField(LGroup, 'request_id', 128) =
        TextField(LRequest, 'id', 128),
        'listening export request order differs');
      LEvents := ArrayField(LGroup, 'events');
      Need(LEvents.Count <= CMaximumRevision,
        'listening export history exceeds revision bound');
      for J := 0 to LEvents.Count - 1 do
      begin
        Need(LEvents.Items[J].JSONType = jtObject,
          'invalid listening export event');
        LEvent := TJSONObject(LEvents.Items[J]);
        CheckFields(LEvent, '|version|request_id|request_sha256|' +
          'revision|reviewer|status|choices|scores|comments|request|');
        Need((IntegerField(LEvent, 'version') = 1) and
          (IntegerField(LEvent, 'revision') = J + 1) and
          (TextField(LEvent, 'request_id', 128) = LRequest.Strings['id']) and
          (TextField(LEvent, 'request_sha256', 64) = HashJson(LRequest)) and
          (ObjectField(LEvent, 'request').AsJSON = LRequest.AsJSON),
          'listening export event identity differs');
        LTransaction := TJSONObject.Create;
        try
          LTransaction.Add('version', 1);
          LTransaction.Add('request_id', LRequest.Strings['id']);
          LTransaction.Add('request_sha256', HashJson(LRequest));
          LTransaction.Add('expected_revision', J);
          LTransaction.Add('reviewer', TextField(LEvent, 'reviewer', 128));
          LTransaction.Add('status', TextField(LEvent, 'status', 16));
          LTransaction.Add('choices', ArrayField(LEvent, 'choices').Clone);
          LTransaction.Add('scores', ArrayField(LEvent, 'scores').Clone);
          LTransaction.Add('comments', ArrayField(LEvent, 'comments').Clone);
          LResponse := NormalizeResponse(LTransaction, LRequest);
          try
            Need(SameResponse(LEvent, LResponse),
              'listening export response is not canonical');
          finally
            LResponse.Free;
          end;
        finally
          LTransaction.Free;
        end;
      end;
    end;
  except
    Result.Free;
    raise;
  end;
end;

function InspectListeningPacket(const APacketPath: String): TJSONObject;
var
  LPacket: TJSONObject;
  LHistory: TJSONArray;
  LEvents: Integer;
  I: Integer;
begin
  LPacket := ReadExportPacket(APacketPath);
  try
    LHistory := LPacket.Arrays['history'];
    LEvents := 0;
    for I := 0 to LHistory.Count - 1 do
    begin
      Inc(LEvents, TJSONObject(LHistory.Items[I]).Arrays['events'].Count);
    end;
    Result := TJSONObject.Create;
    Result.Add('version', 1);
    Result.Add('requests', LHistory.Count);
    Result.Add('events', LEvents);
    Result.Add('sha256', HashJson(LPacket));
  finally
    LPacket.Free;
  end;
end;

function ReplayListeningPacket(const ACatalogRoot, APacketPath: String): TJSONObject;
var
  LPacket: TJSONObject;
  LNormalized: TJSONObject;
  LQueue: TJSONObject;
  LGroups: TJSONArray;
  LEvents: TJSONArray;
  LRequest: TJSONObject;
  LEvent: TJSONObject;
  LTransaction: TJSONObject;
  LResponse: TJSONObject;
  LDirectory: String;
  LStage: String;
  LStageReviews: String;
  LFinalReviews: String;
  LLock: TFileStream;
  LPromoted: Boolean;
  I: Integer;
  J: Integer;
  LCount: Integer;
begin
  Need(not FileExists(QueuePath(ACatalogRoot)),
    'target listening queue already exists');
  LPacket := ReadExportPacket(APacketPath);
  try
    LNormalized := NormalizeQueue(ACatalogRoot, LPacket.Objects['queue'],
      True);
    try
      Need(LNormalized.AsJSON = LPacket.Objects['queue'].AsJSON,
        'exported queue is not canonical or target assets differ');
      LGroups := LPacket.Arrays['history'];
      LQueue := LPacket.Objects['queue'];
      for I := 0 to LGroups.Count - 1 do
      begin
        LRequest := TJSONObject(LQueue.Arrays['items'].Items[I]);
        LDirectory := ReviewPath(ACatalogRoot, LRequest.Strings['id']);
        Need(LatestRevision(LDirectory) = 0,
          'target listening review already exists');
        LEvents := TJSONObject(LGroups.Items[I]).Arrays['events'];
        for J := 0 to LEvents.Count - 1 do
        begin
          LEvent := TJSONObject(LEvents.Items[J]);
          LTransaction := TJSONObject.Create;
          try
            LTransaction.Add('version', 1);
            LTransaction.Add('request_id', LRequest.Strings['id']);
            LTransaction.Add('request_sha256', HashJson(LRequest));
            LTransaction.Add('expected_revision', J);
            LTransaction.Add('reviewer', LEvent.Strings['reviewer']);
            LTransaction.Add('status', LEvent.Strings['status']);
            LTransaction.Add('choices', LEvent.Arrays['choices'].Clone);
            LTransaction.Add('scores', LEvent.Arrays['scores'].Clone);
            LTransaction.Add('comments', LEvent.Arrays['comments'].Clone);
            LResponse := NormalizeResponse(LTransaction, LRequest);
            try
              Need(SameResponse(LEvent, LResponse),
                'exported review response is not canonical');
            finally
              LResponse.Free;
            end;
          finally
            LTransaction.Free;
          end;
        end;
      end;
      CheckStorage(ACatalogRoot);
      CheckNotLink(ListenPath(ACatalogRoot) + 'queue.lock');
      LLock := TFileStream.Create(ListenPath(ACatalogRoot) + 'queue.lock',
        fmCreate or fmShareExclusive);
      try
        Need(not FileExists(QueuePath(ACatalogRoot)),
          'target listening queue already exists');
        LFinalReviews := ListenPath(ACatalogRoot) + 'reviews';
        Need(not DirectoryExists(LFinalReviews) and
          not FileExists(LFinalReviews),
          'target listening review storage already exists');
        LStage := NewStagePath(ListenPath(ACatalogRoot) + 'replay');
        LStageReviews := LStage + PathDelim + 'reviews';
        LPromoted := False;
        try
          Need(ForceDirectories(LStageReviews),
            'cannot stage listening replay');
          LCount := 0;
          for I := 0 to LGroups.Count - 1 do
          begin
            LRequest := TJSONObject(LQueue.Arrays['items'].Items[I]);
            LDirectory := LStageReviews + PathDelim +
              LRequest.Strings['id'] + PathDelim;
            Need(ForceDirectories(LDirectory),
              'cannot stage listening replay directory');
            LEvents := TJSONObject(LGroups.Items[I]).Arrays['events'];
            for J := 0 to LEvents.Count - 1 do
            begin
              LEvent := TJSONObject(LEvents.Items[J]);
              WriteNewText(LDirectory + RevisionName(J + 1),
                LEvent.AsJSON + LineEnding);
              Inc(LCount);
            end;
          end;
          WriteNewText(LStage + PathDelim + 'queue.json',
            LQueue.AsJSON + LineEnding);
          Need(RenameFile(LStageReviews, LFinalReviews),
            'cannot publish replayed listening reviews');
          LPromoted := True;
          Need(RenameFile(LStage + PathDelim + 'queue.json',
            QueuePath(ACatalogRoot)),
            'cannot publish replayed listening queue');
          LPromoted := False;
        finally
          if LPromoted then
          begin
            Need(RenameFile(LFinalReviews, LStageReviews),
              'cannot roll back replayed listening reviews');
          end;
          if FileExists(LStage + PathDelim + 'queue.json') then
          begin
            SysUtils.DeleteFile(LStage + PathDelim + 'queue.json');
          end;
          for I := 0 to LGroups.Count - 1 do
          begin
            LRequest := TJSONObject(LQueue.Arrays['items'].Items[I]);
            LDirectory := LStageReviews + PathDelim +
              LRequest.Strings['id'] + PathDelim;
            LEvents := TJSONObject(LGroups.Items[I]).Arrays['events'];
            for J := 0 to LEvents.Count - 1 do
            begin
              SysUtils.DeleteFile(LDirectory + RevisionName(J + 1));
            end;
            RemoveDir(LDirectory);
          end;
          RemoveDir(LStageReviews);
          RemoveDir(LStage);
        end;
      finally
        LLock.Free;
      end;
      Result := TJSONObject.Create;
      Result.Add('version', 1);
      Result.Add('requests', LQueue.Arrays['items'].Count);
      Result.Add('events', LCount);
      Result.Add('sha256', HashJson(LPacket));
    finally
      LNormalized.Free;
    end;
  finally
    LPacket.Free;
  end;
end;

end.
