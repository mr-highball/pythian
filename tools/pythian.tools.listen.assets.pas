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
unit pythian.tools.listen.assets;

{$mode delphi}
{$H+}

interface

uses Classes, fpjson, pythian.wave.stream;

const
  MaximumListeningAssetBytes: Int64 = 17179869184;

type
  TListeningAssetInfo = record
    Bytes: Int64;
    SampleRate: Integer;
    Channels: Integer;
    Frames: Int64;
  end;

  { Owns a fresh stage in the canonical store. Destruction retains incomplete
    stages as failure evidence; only Finish publishes a WAV. Borrows no source.
    The PCM writer must finish before calling this sink's Finish. Public JSON
    contains only content/geometry, never a host path or verification receipt. }
  TListeningAssetWriter = class(TAudioByteSink)
  private
    FRoot: String;
    FStagePath: String;
    FFile: TFileStream;
    FSink: TStreamAudioSink;
    FHashSink: THashedAudioByteSink;
    FFailed: Boolean;
    FResult: TJSONObject;
    procedure CloseOutput;
  public
    constructor Create(const ACatalogRoot: String; const AOwnerId: String = '');
    destructor Destroy; override;
    procedure WriteBytes(const ABytes: array of Byte); override;
    function Finish: TJSONObject;
    property StagePath: String read FStagePath;
  end;

{ PYTHIAN_STUDIO_ARTIFACT_ROOT selects a host root, namespaced by catalog path.
  Unconfigured hosts use catalog/listening/assets. Old catalog assets remain
  readable; all new writes use the selected root. No background migration. }
function ListeningAssetDirectory(const ACatalogRoot: String): String;
function ListeningAssetPath(const ACatalogRoot, AHash: String): String;
procedure EnsureListeningAssetStorage(const ACatalogRoot: String);
function InspectListeningWave(const APath, AHash: String;
  const AVerifyHash: Boolean): TListeningAssetInfo;
procedure VerifyListeningAsset(const APath, AHash: String; const ABytes: Int64);
function ImportListeningAsset(const ACatalogRoot, AInputPath: String): TJSONObject;

implementation

uses SysUtils, jsonparser, pythian.audio, pythian.hash, pythian.wave.read,
  pythian.tools.annotations.sourceguard
  {$IFDEF MSWINDOWS}, Windows{$ENDIF};

procedure Need(const ACondition: Boolean; const AMessage: String);
begin
  if not ACondition then raise EAudio.Create('Listening audio: ' + AMessage);
end;

procedure CheckNotLink(const APath: String);
{$IFDEF MSWINDOWS}
var
  LAttributes: DWORD;
{$ENDIF}
begin
  {$IFDEF MSWINDOWS}
  if FileExists(APath) or DirectoryExists(APath) then
  begin
    LAttributes := GetFileAttributes(PChar(APath));
    Need((LAttributes <> INVALID_FILE_ATTRIBUTES) and
      ((LAttributes and FILE_ATTRIBUTE_REPARSE_POINT) = 0),
      'asset storage contains a reparse point');
  end;
  {$ENDIF}
end;

procedure RequireHash(const AHash: String);
var
  I: Integer;
begin
  Need(Length(AHash) = 64, 'invalid asset SHA256');
  for I := 1 to Length(AHash) do
    Need(AHash[I] in ['0'..'9', 'a'..'f'], 'invalid asset SHA256');
end;

function LegacyDirectory(const ACatalogRoot: String): String;
begin
  Result := IncludeTrailingPathDelimiter(ExpandFileName(ACatalogRoot)) +
    'listening' + PathDelim + 'assets' + PathDelim;
end;

function ListeningAssetDirectory(const ACatalogRoot: String): String;
var
  LNamespace: String;
  LStream: TStringStream;
begin
  Result := SysUtils.GetEnvironmentVariable('PYTHIAN_STUDIO_ARTIFACT_ROOT');
  if Result = '' then Exit(LegacyDirectory(ACatalogRoot));
  LNamespace := ExcludeTrailingPathDelimiter(ExpandFileName(ACatalogRoot));
  {$IFDEF MSWINDOWS}
  LNamespace := UpperCase(LNamespace);
  {$ENDIF}
  LStream := TStringStream.Create(LNamespace);
  try
    LNamespace := Sha256Stream(LStream, LStream.Size);
  finally
    LStream.Free;
  end;
  Result := IncludeTrailingPathDelimiter(ExpandFileName(Result)) + LNamespace + PathDelim;
end;

procedure EnsureListeningAssetStorage(const ACatalogRoot: String);
var
  LRoot, LParent: String;
begin
  Need(DirectoryExists(ACatalogRoot), 'catalog root does not exist');
  CheckNotLink(ACatalogRoot);
  LRoot := ListeningAssetDirectory(ACatalogRoot);
  LParent := ExtractFileDir(ExcludeTrailingPathDelimiter(LRoot));
  CheckNotLink(LParent);
  CheckNotLink(LRoot);
  Need(ForceDirectories(LRoot), 'cannot create audio store');
  CheckNotLink(LParent);
  CheckNotLink(LRoot);
end;

function ListeningAssetPath(const ACatalogRoot, AHash: String): String;
var
  LLegacy: String;
begin
  RequireHash(AHash);
  Result := ListeningAssetDirectory(ACatalogRoot) + AHash + '.wav';
  if not FileExists(Result) then
  begin
    LLegacy := LegacyDirectory(ACatalogRoot) + AHash + '.wav';
    if FileExists(LLegacy) then Result := LLegacy;
  end;
  CheckNotLink(ExtractFileDir(Result));
  CheckNotLink(Result);
end;

function NewStagePath(const ARoot: String; const AOwnerId: String = ''): String;
var
  LGuid: TGUID;
  I: Integer;
begin
  for I := 1 to Length(AOwnerId) do
    Need(AOwnerId[I] in ['a'..'z', 'A'..'Z', '0'..'9', '.', '-', '_'], 'invalid output owner');
  Need(CreateGUID(LGuid) = 0, 'cannot create output identity');
  Result := ARoot + 'output-' + Copy(AOwnerId, 1, 48) + '-' + GUIDToString(LGuid) + '.partial';
end;

function ReadIdentity(const APath, AHash: String; const ABytes: Int64): String;
var
  LFile: TFileStream;
  LText: TStringStream;
  LData: TJSONData;
begin
  Result := '';
  if not FileExists(APath + '.verified.json') then Exit;
  CheckNotLink(APath + '.verified.json');
  LFile := TFileStream.Create(APath + '.verified.json', fmOpenRead or fmShareDenyWrite);
  LText := TStringStream.Create('');
  LData := nil;
  try
    Need((LFile.Size > 0) and (LFile.Size <= 4096), 'invalid native output receipt size');
    LText.CopyFrom(LFile, LFile.Size);
    LData := GetJSON(LText.DataString);
    Need(LData is TJSONObject, 'invalid native output receipt');
    with TJSONObject(LData) do
    begin
      Need((Get('version', 0) = 1) and (Get('sha256', '') = AHash) and
        (Get('bytes', Int64(-1)) = ABytes), 'native output receipt differs from audio');
      Result := Get('identity', '');
    end;
  finally
    LData.Free;
    LText.Free;
    LFile.Free;
  end;
end;

procedure VerifyListeningAsset(const APath, AHash: String; const ABytes: Int64);
begin
  RequireHash(AHash);
  CheckNotLink(APath);
  VerifyGuardedSource(APath, AHash, ABytes, ReadIdentity(APath, AHash, ABytes));
end;

function InspectListeningWave(const APath, AHash: String;
  const AVerifyHash: Boolean): TListeningAssetInfo;
var
  LFile: TFileStream;
  LReader: TWaveFrameReader;
begin
  Result := Default(TListeningAssetInfo);
  CheckNotLink(APath);
  LFile := TFileStream.Create(APath, fmOpenRead or fmShareDenyWrite);
  try
    Need((LFile.Size >= 44) and (LFile.Size <= MaximumListeningAssetBytes),
      'asset exceeds WAV size bound');
    Result.Bytes := LFile.Size;
    if AVerifyHash then VerifyListeningAsset(APath, AHash, Result.Bytes);
    LReader := TWaveFrameReader.Create(LFile);
    try
      Result.SampleRate := LReader.SampleRate;
      Result.Channels := LReader.Channels;
      Result.Frames := LReader.FrameCount;
      Need(Result.SampleRate >= 8000, 'WAV sample rate below 8000 Hz is unsupported for playback');
      Need(Result.Frames > 0, 'WAV has no frames');
    finally
      LReader.Free;
    end;
  finally
    LFile.Free;
  end;
end;

procedure WriteReceipt(const APath, AHash: String; const ABytes: Int64);
var
  LIdentity, LStage, LText: String;
  LData: TJSONObject;
  LFile: TFileStream;
begin
  LIdentity := SourceFileIdentity(APath, ABytes);
  if LIdentity = '' then Exit;
  LStage := NewStagePath(ExtractFilePath(APath));
  LData := TJSONObject.Create;
  try
    LData.Add('version', 1);
    LData.Add('sha256', AHash);
    LData.Add('bytes', ABytes);
    LData.Add('identity', LIdentity);
    LText := LData.AsJSON;
    LFile := TFileStream.Create(LStage, fmCreate or fmShareExclusive);
    try
      LFile.WriteBuffer(LText[1], Length(LText));
    finally
      LFile.Free;
    end;
    {$IFDEF MSWINDOWS}
    Need(MoveFileEx(PChar(LStage), PChar(APath + '.verified.json'), MOVEFILE_REPLACE_EXISTING),
      'cannot publish native output receipt');
    {$ELSE}
    Need(RenameFile(LStage, APath + '.verified.json'), 'cannot publish native output receipt');
    {$ENDIF}
  finally
    LData.Free;
  end;
end;

constructor TListeningAssetWriter.Create(const ACatalogRoot: String; const AOwnerId: String);
begin
  inherited Create;
  EnsureListeningAssetStorage(ACatalogRoot);
  FRoot := ListeningAssetDirectory(ACatalogRoot);
  FStagePath := NewStagePath(FRoot, AOwnerId);
  FFile := TFileStream.Create(FStagePath, fmCreate or fmShareExclusive);
  FSink := TStreamAudioSink.Create(FFile);
  FHashSink := THashedAudioByteSink.Create(FSink);
end;

procedure TListeningAssetWriter.CloseOutput;
begin
  FreeAndNil(FHashSink);
  FreeAndNil(FSink);
  FreeAndNil(FFile);
end;

destructor TListeningAssetWriter.Destroy;
begin
  CloseOutput;
  FResult.Free;
  inherited Destroy;
end;

procedure TListeningAssetWriter.WriteBytes(const ABytes: array of Byte);
begin
  Need(not FFailed and (FResult = nil) and (FHashSink <> nil), 'output is closed or failed');
  Need(Length(ABytes) <= MaximumListeningAssetBytes - FHashSink.ByteCount, 'output exceeds size bound');
  try
    FHashSink.WriteBytes(ABytes);
  except
    FFailed := True;
    raise;
  end;
end;

function TListeningAssetWriter.Finish: TJSONObject;
var
  LHash, LPath: String;
  LBytes: Int64;
  LInfo: TListeningAssetInfo;
begin
  Need(not FFailed, 'output failed before publication');
  if FResult <> nil then Exit(TJSONObject(FResult.Clone));
  try
    LHash := FHashSink.Finish;
    LBytes := FHashSink.ByteCount;
    CloseOutput;
    LInfo := InspectListeningWave(FStagePath, '', False);
    Need(LInfo.Bytes = LBytes, 'staged bytes differ from confirmed output');
    LPath := FRoot + LHash + '.wav';
    CheckNotLink(LPath);
    if not RenameFile(FStagePath, LPath) then
    begin
      Need(FileExists(LPath), 'cannot publish generated audio');
      LInfo := InspectListeningWave(LPath, LHash, True);
      Need(LInfo.Bytes = LBytes, 'existing asset differs from generated output');
      Need(SysUtils.DeleteFile(FStagePath), 'cannot discard identical owned stage');
    end
    else
      WriteReceipt(LPath, LHash, LBytes);
    FResult := TJSONObject.Create;
    FResult.Add('version', 1);
    FResult.Add('sha256', LHash);
    FResult.Add('bytes', LInfo.Bytes);
    FResult.Add('sample_rate', LInfo.SampleRate);
    FResult.Add('channels', LInfo.Channels);
    FResult.Add('frames', LInfo.Frames);
    Result := TJSONObject(FResult.Clone);
  except
    FFailed := True;
    raise;
  end;
end;

function ImportListeningAsset(const ACatalogRoot, AInputPath: String): TJSONObject;
var
  LInput: TFileStream;
  LWriter: TListeningAssetWriter;
  LBuffer: array[0..65535] of Byte;
  LRead: Integer;
  LRemaining: Int64;
begin
  LWriter := nil;
  LInput := TFileStream.Create(ExpandFileName(AInputPath), fmOpenRead or fmShareDenyWrite);
  try
    Need((LInput.Size >= 44) and (LInput.Size <= MaximumListeningAssetBytes), 'import exceeds WAV size bound');
    LWriter := TListeningAssetWriter.Create(ACatalogRoot, 'import');
    LRemaining := LInput.Size;
    while LRemaining > 0 do
    begin
      LRead := SizeOf(LBuffer);
      if LRemaining < LRead then LRead := Integer(LRemaining);
      Need(LInput.Read(LBuffer, LRead) = LRead, 'import source ended early');
      LWriter.WriteBytes(Slice(LBuffer, LRead));
      Dec(LRemaining, LRead);
    end;
    Result := LWriter.Finish;
  finally
    LWriter.Free;
    LInput.Free;
  end;
end;

end.
