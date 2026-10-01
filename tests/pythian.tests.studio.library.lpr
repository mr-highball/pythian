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
program PythianStudioLibraryConformance;

{$mode delphi}
{$H+}

uses
  Classes,
  SysUtils,
  fpjson,
  jsonparser,
  pythian.audio,
  pythian.hash,
  pythian.wave,
  pythian.wave.stream,
  pythian.tools.annotations.catalog,
  pythian.tools.studio.&library
  {$IFDEF MSWINDOWS}, Windows{$ENDIF};

type
  TProgressProbe = class
  public
    Stage: String;
    MutationPath: String;
    MutationText: String;
    Calls: Integer;
    InteriorOnly: Boolean;
    InteriorCalls: Integer;
    ByteCalls: Integer;
    LastByteStage: String;
    LastByteDone: Int64;
    procedure Observe(const AStage: String; const ADone, ATotal: Int64);
  end;

var
  GChecks: Integer;
  GStage: Integer;
  GRoot: String;

procedure Check(const ACondition: Boolean; const AMessage: String);
begin
  Inc(GChecks);
  if not ACondition then
  begin
    raise Exception.Create(AMessage);
  end;
end;

procedure WriteText(const APath, AText: String);
var
  LStream: TFileStream;
begin
  LStream := TFileStream.Create(APath, fmCreate);
  try
    if AText <> '' then
    begin
      LStream.WriteBuffer(AText[1], Length(AText));
    end;
  finally
    LStream.Free;
  end;
end;

function HashFile(const APath: String): String;
var
  LStream: TFileStream;
begin
  LStream := TFileStream.Create(APath, fmOpenRead or fmShareDenyWrite);
  try
    Result := Sha256Stream(LStream, LStream.Size);
  finally
    LStream.Free;
  end;
end;

procedure CopyFixture(const ASource, ATarget: String);
var
  LInput: TFileStream;
  LOutput: TFileStream;
begin
  LInput := TFileStream.Create(ASource, fmOpenRead);
  try
    LOutput := TFileStream.Create(ATarget, fmCreate);
    try
      LOutput.CopyFrom(LInput, LInput.Size);
    finally
      LOutput.Free;
    end;
  finally
    LInput.Free;
  end;
end;

function MakeWave(const APath: String; const APhase: Integer): String;
var
  LSamples: TAudioSamples;
  LClip: TAudioClip;
  LStream: TFileStream;
  LIndex: Integer;
begin
  SetLength(LSamples, 800);
  for LIndex := 0 to High(LSamples) do
  begin
    if (LIndex + APhase) mod 80 < 20 then
    begin
      LSamples[LIndex] := 0.125;
    end
    else
    begin
      LSamples[LIndex] := -0.125;
    end;
  end;
  LClip := TAudioClip.Create(8000, 1, LSamples);
  try
    LStream := TFileStream.Create(APath, fmCreate);
    try
      WriteWavePcm16(LStream, LClip);
    finally
      LStream.Free;
    end;
  finally
    LClip.Free;
  end;
  Result := HashFile(APath);
end;

procedure TProgressProbe.Observe(const AStage: String; const ADone, ATotal: Int64);
begin
  Inc(Calls);
  Check((ADone >= 0) and (ATotal >= ADone), 'Progress counters have truthful bounds');
  if Pos('_bytes', AStage) > 0 then
  begin
    Inc(ByteCalls);
    if (LastByteStage = AStage) and (ADone <> 0) then
    begin
      Check(ADone >= LastByteDone, 'Byte progress is monotonic within its file/pass');
    end;
    LastByteStage := AStage;
    LastByteDone := ADone;
    if (ADone > 0) and (ADone < ATotal) then
    begin
      Inc(InteriorCalls);
    end;
  end;
  if (AStage = Stage) and
    (not InteriorOnly or ((ADone > 0) and (ADone < ATotal))) then
  begin
    if MutationPath <> '' then
    begin
      if MutationText <> '' then
      begin
        WriteText(MutationPath, MutationText);
      end
      else
      begin
        MakeWave(MutationPath, 13);
      end;
      MutationPath := '';
    end
    else
    begin
      raise EAudio.Create('Caller cancelled this synthetic refresh');
    end;
  end;
end;

function MakeProgressWave(const APath: String): String;
var
  LStream: TFileStream;
  LSink: TStreamAudioSink;
  LWriter: TWavePcm16Writer;
  LSamples: TAudioSamples;
  LRemaining: Integer;
  LCount: Integer;
  LIndex: Integer;
begin
  LStream := TFileStream.Create(APath, fmCreate);
  try
    LSink := TStreamAudioSink.Create(LStream);
    try
      LWriter := TWavePcm16Writer.Create(LSink, 8000, 1, 4500000);
      try
        LRemaining := 4500000;
        while LRemaining > 0 do
        begin
          LCount := 4096;
          if LCount > LRemaining then
          begin
            LCount := LRemaining;
          end;
          SetLength(LSamples, LCount);
          for LIndex := 0 to LCount - 1 do
          begin
            LSamples[LIndex] := 0.125;
          end;
          LWriter.AppendSamples(LSamples);
          Dec(LRemaining, LCount);
        end;
        LWriter.Finish;
      finally
        LWriter.Free;
      end;
    finally
      LSink.Free;
    end;
  finally
    LStream.Free;
  end;
  Result := HashFile(APath);
end;

function FreshStage: String;
begin
  Inc(GStage);
  Result := GRoot + 'stages' + PathDelim + IntToStr(GStage);
end;

function Refresh(const ACatalog, ALibrary: String;
  const AProbe: TProgressProbe = nil): TJSONObject;
begin
  if AProbe = nil then
  begin
    Result := RefreshStudioLibrary(ACatalog, ALibrary, FreshStage);
  end
  else
  begin
    Result := RefreshStudioLibrary(ACatalog, ALibrary, FreshStage, AProbe.Observe);
  end;
end;

procedure ExpectFailure(const ACatalog, ALibrary, ABefore: String;
  const AProbe: TProgressProbe = nil);
var
  LResult: TJSONObject;
  LFailed: Boolean;
begin
  LFailed := False;
  try
    LResult := Refresh(ACatalog, ALibrary, AProbe);
    LResult.Free;
  except
    on LException: Exception do
    begin
      LFailed := True;
      WriteLn('EXPECTED: ', LException.ClassName, ': ', LException.Message);
    end;
  end;
  Check(LFailed, 'Invalid refresh rejected');
  LResult := ListStudioLibrary(ACatalog);
  try
    Check(LResult.AsJSON = ABefore, 'Failure preserves the complete published index');
  finally
    LResult.Free;
  end;
end;

procedure MakeSparse(const APath: String; const ASize: Int64);
var
  LStream: TFileStream;
  {$IFDEF MSWINDOWS}
  LReturned: DWORD;
  {$ENDIF}
begin
  LStream := TFileStream.Create(APath, fmCreate);
  try
    {$IFDEF MSWINDOWS}
    Check(DeviceIoControl(THandle(LStream.Handle), $000900C4, nil, 0,
      nil, 0, LReturned, nil), 'Create sparse size-bound fixture without media allocation');
    {$ENDIF}
    LStream.Size := ASize;
    Check(LStream.Size = ASize, 'Sparse fixture declares exact size');
  finally
    LStream.Free;
  end;
end;

procedure Run(const AOutput: String);
var
  LCatalog: String;
  LLibrary: String;
  LFirst: String;
  LSecond: String;
  LAlias: String;
  LHash: String;
  LOtherHash: String;
  LPriorHash: String;
  LBefore: String;
  LMetadata: String;
  LResult: TJSONObject;
  LTrack: TJSONObject;
  LLabels: TJSONArray;
  LProbe: TProgressProbe;
  LIndex: Integer;
  LBroken: String;
  LPath: String;
  LStream: TFileStream;
  LByte: Byte;
  LData: TJSONData;
  LRevisionPath: String;
  LFullCatalog: String;
  LAvailableLabels: Integer;
  LProgressPath: String;
  LProgressHash: String;
begin
  GRoot := IncludeTrailingPathDelimiter(ExpandFileName(AOutput));
  Check(not DirectoryExists(GRoot), 'Conformance output root must be fresh');
  Check(ForceDirectories(GRoot), 'Create isolated conformance root');
  LCatalog := GRoot + 'catalog';
  LLibrary := GRoot + 'library';
  Check(ForceDirectories(LCatalog), 'Create empty synthetic catalog');
  LLabels := StudioCollectionsForSource(LCatalog, StringOfChar('0', 64));
  try
    Check(LLabels.Count = 0, 'Collection lookup before first index returns an empty array');
  finally
    LLabels.Free;
  end;
  Check(ForceDirectories(LLibrary + '/collections/Evening piano'), 'Create caller collection');
  Check(ForceDirectories(LLibrary + '/collections/Bright'), 'Create second caller collection');
  LFirst := LLibrary + '/collections/Evening piano/first tune.wav';
  LSecond := LLibrary + '/collections/Bright/second.wav';
  LAlias := LLibrary + '/collections/Bright/alias.wav';
  LHash := MakeWave(LFirst, 0);
  LOtherHash := MakeWave(LSecond, 7);
  CopyFixture(LFirst, LAlias);
  WriteText(LLibrary + '/collections/Bright/readme.txt', 'Synthetic non-audio control');
  LResult := Refresh(LCatalog, LLibrary);
  try
    Check(LResult.Strings['format'] = StudioLibraryFormat, 'Public format identified');
    Check(LResult.Integers['revision'] = 1, 'First immutable index revision');
    Check(LResult.Integers['collection_count'] = 2, 'Two independent collection labels');
    Check(LResult.Integers['file_count'] = 3, 'Three actual file memberships');
    Check(LResult.Integers['recording_count'] = 2, 'Duplicate bytes are one recording');
    Check(LResult.Integers['imported_count'] = 2, 'Two unique sources imported');
    Check(LResult.Integers['duplicate_file_count'] = 1, 'Duplicate alias count retained');
    Check(LResult.Integers['unsupported_count'] = 1, 'Unsupported regular file reported');
    Check(LResult.Integers['failed_count'] = 0, 'Only coherent refresh publishes');
    Check(Pos(GRoot, LResult.AsJSON) = 0, 'No private absolute path in public index');
    Check(Pos('"path"', LResult.AsJSON) = 0, 'No source path field in public index');
    LBefore := LResult.AsJSON;
  finally
    LResult.Free;
  end;
  Check(HashFile(LFirst) = LHash, 'Original source untouched');
  Check(HashFile(LAlias) = LHash, 'Duplicate original untouched');
  Check(HashFile(LSecond) = LOtherHash, 'Second original untouched');
  LLabels := StudioCollectionsForSource(LCatalog, LHash);
  try
    Check(LLabels.Count = 2, 'Source belongs to both collection labels');
  finally
    LLabels.Free;
  end;
  LTrack := ReadCatalogTrack(LCatalog, LHash);
  try
    Check(LTrack.Strings['partition'] = 'unassigned', 'New source use remains unassigned');
    Check(LTrack.Strings['source_group'] = 'library_' + LHash,
      'Recording grouping derives from content, not collection genre');
    Check(LTrack.Strings['clock_id'] = '', 'No inferred shared clock');
    Check(Pos('unverified', LTrack.Strings['license']) > 0, 'Rights explicitly unverified');
    LTrack.Strings['partition'] := 'evaluation';
    LTrack.Strings['source_group'] := 'preserved_existing_group';
    LTrack.Strings['license'] := 'MIT; caller synthetic control';
    LTrack.Strings['provenance'] := 'Existing authored fixture declaration';
    LTrack.Strings['title'] := 'Preserved caller title';
    LTrack.Strings['original_name'] := 'preserved.wav';
    LMetadata := LTrack.AsJSON;
    WriteText(LCatalog + '/tracks/' + LHash + '.json', LMetadata + #10);
  finally
    LTrack.Free;
  end;
  LTrack := ReadCatalogTrack(LCatalog, LOtherHash);
  try
    LTrack.Strings['original_name'] := 'preserved.wav';
    WriteText(LCatalog + '/tracks/' + LOtherHash + '.json', LTrack.AsJSON + #10);
  finally
    LTrack.Free;
  end;
  LResult := Refresh(LCatalog, LLibrary);
  try
    Check(LResult.Integers['revision'] = 2, 'Refresh publishes a new immutable revision');
    Check(LResult.Integers['imported_count'] = 0, 'Identical catalog bytes not reclassified');
    Check(LResult.Integers['existing_count'] = 2, 'Existing recordings verified');
    Check(not DirectoryExists(GRoot + 'stages/' + IntToStr(GStage)),
      'Verified existing recordings create no full staging files or stage directory');
    LBefore := LResult.AsJSON;
  finally
    LResult.Free;
  end;
  LTrack := ReadCatalogTrack(LCatalog, LHash);
  try
    Check(LTrack.AsJSON = LMetadata, 'All existing group/license/exposure metadata preserved');
  finally
    LTrack.Free;
  end;
  LTrack := ReadCatalogTrack(LCatalog, LOtherHash);
  try
    Check(LTrack.Strings['original_name'] = 'preserved.wav',
      'Second hash retains the shared original basename after verification');
  finally
    LTrack.Free;
  end;
  Check(RenameFile(LLibrary, LLibrary + '-offline'), 'Temporarily remove source root');
  LResult := ListStudioLibrary(LCatalog);
  try
    Check(LResult.AsJSON = LBefore, 'Metadata listing needs no live library or media');
  finally
    LResult.Free;
  end;
  Check(RenameFile(LLibrary + '-offline', LLibrary), 'Restore source root');
  Check(SysUtils.DeleteFile(LAlias), 'Remove only owned alias fixture');
  LResult := Refresh(LCatalog, LLibrary);
  try
    Check(LResult.Integers['missing_count'] = 1, 'Missing alias retained explicitly');
    Check(LResult.Integers['file_count'] = 2, 'Active file count excludes missing alias');
    Check(LResult.Integers['recording_count'] = 2, 'Other source remains available');
    LBefore := LResult.AsJSON;
  finally
    LResult.Free;
  end;
  Check(RenameFile(LLibrary + '/collections/Evening piano',
    LLibrary + '/collections/Renamed collection'), 'Rename owned collection');
  LFirst := LLibrary + '/collections/Renamed collection/first tune.wav';
  LResult := Refresh(LCatalog, LLibrary);
  try
    Check(LResult.Integers['collection_count'] = 3, 'Renamed label does not overwrite history');
    Check(LResult.Integers['missing_count'] = 2, 'Old collection membership remains missing');
    LBefore := LResult.AsJSON;
  finally
    LResult.Free;
  end;
  LLabels := StudioCollectionsForSource(LCatalog, LHash);
  try
    Check(LLabels.Count = 3, 'Collection lineage remains observable');
    LAvailableLabels := 0;
    for LIndex := 0 to LLabels.Count - 1 do
    begin
      if LLabels.Objects[LIndex].Strings['status'] = 'available' then
      begin
        Inc(LAvailableLabels);
      end;
    end;
    Check(LAvailableLabels = 1, 'Missing file labels do not imply current membership');
  finally
    LLabels.Free;
  end;
  LPriorHash := LOtherHash;
  LOtherHash := MakeWave(LSecond, 9);
  LResult := Refresh(LCatalog, LLibrary);
  try
    Check(LResult.Integers['changed_count'] = 1, 'Changed bytes reported as a new recording');
    Check(LResult.Integers['missing_count'] = 3, 'Prior changed membership remains missing');
    Check(LResult.Integers['imported_count'] = 1,
      'Changed recording imported under fresh identity');
    Check(FileExists(LCatalog + '/sources/' + LPriorHash + '.wav'),
      'Changed bytes do not replace the prior catalog audio');
  finally
    LResult.Free;
  end;
  LResult := Refresh(LCatalog, LLibrary);
  try
    Check(LResult.Integers['changed_count'] = 0,
      'Unchanged repeat does not report perpetual change');
    LBefore := LResult.AsJSON;
  finally
    LResult.Free;
  end;
  LProbe := TProgressProbe.Create;
  try
    LProbe.Stage := 'hashing_sources';
    ExpectFailure(LCatalog, LLibrary, LBefore, LProbe);
    Check(LProbe.Calls > 0, 'Caller cancellation actually executed');
    LProbe.Stage := 'publishing_index';
    ExpectFailure(LCatalog, LLibrary, LBefore, LProbe);
    LProbe.Stage := 'verifying_sources';
    LProbe.MutationPath := LSecond;
    ExpectFailure(LCatalog, LLibrary, LBefore, LProbe);
    MakeWave(LSecond, 9);
  finally
    LProbe.Free;
  end;
  LTrack := ReadCatalogTrack(LCatalog, LOtherHash);
  try
    LMetadata := LTrack.AsJSON;
    LTrack.Int64s['frame_count'] := LTrack.Int64s['frame_count'] + 1;
    WriteText(LCatalog + '/tracks/' + LOtherHash + '.json', LTrack.AsJSON + #10);
    ExpectFailure(LCatalog, LLibrary, LBefore);
    WriteText(LCatalog + '/tracks/' + LOtherHash + '.json', LMetadata + #10);
  finally
    LTrack.Free;
  end;
  LPath := LCatalog + '/sources/' + LOtherHash + '.wav';
  LStream := TFileStream.Create(LPath, fmOpenReadWrite);
  try
    LStream.Position := 60;
    LStream.ReadBuffer(LByte, 1);
    LByte := LByte xor 1;
    LStream.Position := 60;
    LStream.WriteBuffer(LByte, 1);
  finally
    LStream.Free;
  end;
  ExpectFailure(LCatalog, LLibrary, LBefore);
  CopyFixture(LSecond, LPath);
  LStream := TFileStream.Create(LPath, fmOpenReadWrite);
  try
    LStream.Position := 24;
    LStream.ReadBuffer(LByte, 1);
    LByte := LByte xor 1;
    LStream.Position := 24;
    LStream.WriteBuffer(LByte, 1);
  finally
    LStream.Free;
  end;
  ExpectFailure(LCatalog, LLibrary, LBefore);
  CopyFixture(LSecond, LPath);
  LTrack := ReadCatalogTrack(LCatalog, LOtherHash);
  try
    LMetadata := LTrack.AsJSON;
    LTrack.Strings['source_group'] := 'preserved_existing_group';
    WriteText(LCatalog + '/tracks/' + LOtherHash + '.json', LTrack.AsJSON + #10);
    ExpectFailure(LCatalog, LLibrary, LBefore);
    WriteText(LCatalog + '/tracks/' + LOtherHash + '.json', LMetadata + #10);
  finally
    LTrack.Free;
  end;
  LProbe := TProgressProbe.Create;
  try
    LTrack := ReadCatalogTrack(LCatalog, LOtherHash);
    try
      LMetadata := LTrack.AsJSON;
      LTrack.Strings['title'] := 'Changed during publication checkpoint';
      LProbe.Stage := 'publishing_index';
      LProbe.MutationPath := LCatalog + '/tracks/' + LOtherHash + '.json';
      LProbe.MutationText := LTrack.AsJSON + #10;
    finally
      LTrack.Free;
    end;
    ExpectFailure(LCatalog, LLibrary, LBefore, LProbe);
    WriteText(LCatalog + '/tracks/' + LOtherHash + '.json', LMetadata + #10);
  finally
    LProbe.Free;
  end;
  Check(ForceDirectories(LLibrary + '/collections/Stream control'),
    'Create first-party read-progress fixture collection');
  LProgressPath := LLibrary + '/collections/Stream control/progress.wav';
  LProgressHash := MakeProgressWave(LProgressPath);
  LProbe := TProgressProbe.Create;
  try
    LProbe.Stage := 'hashing_source_bytes';
    LProbe.InteriorOnly := True;
    ExpectFailure(LCatalog, LLibrary, LBefore, LProbe);
    Check(LProbe.InteriorCalls > 0, 'Cancellation reached an actual partial hash read');
    LProbe.Stage := 'copying_source_bytes';
    LProbe.InteriorCalls := 0;
    ExpectFailure(LCatalog, LLibrary, LBefore, LProbe);
    Check(LProbe.InteriorCalls > 0, 'Cancellation reached an actual partial staging copy');
    Check(not FileExists(LCatalog + '/sources/' + LProgressHash + '.wav'),
      'Cancelled partial new-source copy is not published into catalog');
  finally
    LProbe.Free;
  end;
  LProbe := TProgressProbe.Create;
  try
    LResult := Refresh(LCatalog, LLibrary, LProbe);
    try
      Check(LResult.Integers['imported_count'] = 1,
        'Fresh retry imports the actual first-party progress source once');
      Check(LProbe.InteriorCalls > 0, 'Successful verification reports actual interior bytes');
      Check(LProbe.Calls < 100, 'Small progress fixture does not flood callback events');
      LBefore := LResult.AsJSON;
    finally
      LResult.Free;
    end;
    LProbe.Stage := 'verifying_catalog_bytes';
    LProbe.InteriorOnly := True;
    LProbe.InteriorCalls := 0;
    ExpectFailure(LCatalog, LLibrary, LBefore, LProbe);
    Check(LProbe.InteriorCalls > 0,
      'Verified reuse can cancel during the actual catalog content read');
    LProbe.Stage := '';
    LProbe.InteriorOnly := False;
    LProbe.Calls := 0;
    LProbe.InteriorCalls := 0;
    LResult := Refresh(LCatalog, LLibrary, LProbe);
    try
      Check((LResult.Integers['imported_count'] = 0) and
        (LResult.Integers['existing_count'] = 3),
        'Later read-progress refresh verifies all three existing sources');
      Check(not DirectoryExists(GRoot + 'stages/' + IntToStr(GStage)),
        'Existing progress source is reused with zero staging media');
      Check(LProbe.InteriorCalls >= 3,
        'Existing large control exposes all three actual hash read passes');
      Check(LProbe.Calls < 100, 'Verified reuse keeps progress callbacks bounded');
      LBefore := LResult.AsJSON;
    finally
      LResult.Free;
    end;
  finally
    LProbe.Free;
  end;
  Check(ForceDirectories(LLibrary + '/collections/Bright/nested'),
    'Create forbidden nested directory');
  ExpectFailure(LCatalog, LLibrary, LBefore);
  Check(RemoveDir(LLibrary + '/collections/Bright/nested'), 'Remove owned empty directory');
  LBroken := GRoot + 'too-many-collections';
  for LIndex := 0 to MaximumLibraryCollections do
  begin
    Check(ForceDirectories(LBroken + '/collections/c' + IntToStr(LIndex)),
      'Create bounded collection-count control');
  end;
  ExpectFailure(LCatalog, LBroken, LBefore);
  LBroken := GRoot + 'too-many-files';
  Check(ForceDirectories(LBroken + '/collections/one'), 'Create file-count control');
  for LIndex := 0 to MaximumLibraryFiles do
  begin
    WriteText(LBroken + '/collections/one/f' + IntToStr(LIndex) + '.wav',
      StringOfChar('x', 44));
  end;
  ExpectFailure(LCatalog, LBroken, LBefore);
  LBroken := GRoot + 'oversize';
  Check(ForceDirectories(LBroken + '/collections/one'), 'Create size control');
  MakeSparse(LBroken + '/collections/one/huge.wav', MaximumLibrarySourceBytes + 1);
  ExpectFailure(LCatalog, LBroken, LBefore);
  LBroken := GRoot + 'aggregate';
  Check(ForceDirectories(LBroken + '/collections/one'), 'Create aggregate size control');
  for LIndex := 0 to 2 do
  begin
    MakeSparse(LBroken + '/collections/one/huge' + IntToStr(LIndex) + '.wav',
      MaximumLibrarySourceBytes);
  end;
  ExpectFailure(LCatalog, LBroken, LBefore);
  LBroken := GRoot + 'invalid-wave';
  Check(ForceDirectories(LBroken + '/collections/one'), 'Create malformed WAV control');
  WriteText(LBroken + '/collections/one/not-wave.wav', StringOfChar('x', 44));
  ExpectFailure(LCatalog, LBroken, LBefore);
  LFullCatalog := GRoot + 'full-catalog';
  Check(ForceDirectories(LFullCatalog + '/tracks'), 'Create bounded catalog capacity control');
  for LIndex := 0 to 4095 do
  begin
    WriteText(LFullCatalog + '/tracks/' + StringOfChar('0', 56) +
      LowerCase(IntToHex(LIndex, 8)) + '.json', '{}');
  end;
  LResult := ListStudioLibrary(LFullCatalog);
  try
    ExpectFailure(LFullCatalog, LLibrary, LResult.AsJSON);
  finally
    LResult.Free;
  end;
  Check(ForceDirectories(LCatalog + '/studio/library/.write-lock'), 'Create interrupted lock');
  ExpectFailure(LCatalog, LLibrary, LBefore);
  Check(RemoveDir(LCatalog + '/studio/library/.write-lock'),
    'Explicitly remove owned lock control');
  LData := GetJSON(LBefore);
  try
    LRevisionPath := LCatalog + '/studio/library/revision-' +
      Format('%.6d', [TJSONObject(LData).Integers['revision']]) + '.json';
    TJSONObject(LData).Integers['recording_count'] := 999;
    WriteText(LRevisionPath, LData.AsJSON + #10);
    try
      LResult := ListStudioLibrary(LCatalog);
      LResult.Free;
      Check(False, 'Tampered index must reject');
    except
      on LException: EAudio do
      begin
        Check(True, 'Tampered digest rejected without fallback');
      end;
    end;
    WriteText(LRevisionPath, LBefore + #10);
  finally
    LData.Free;
  end;
  if ParamCount = 2 then
  begin
    ExpectFailure(LCatalog, ParamStr(2), LBefore);
    WriteLn('PASS actual linked-directory rejection');
  end;
  Check(not DirectoryExists(LCatalog + '/reviews'), 'No review event store created');
  Check(not DirectoryExists(LCatalog + '/proposals'), 'No musical inference/proposals run');
  LResult := ListStudioLibrary(LCatalog);
  try
    WriteText(GRoot + 'final-index.json', LResult.AsJSON + #10);
  finally
    LResult.Free;
  end;
  WriteLn('PASS ', GChecks, ' Studio library checks; synthetic input only');
end;

begin
  try
    Check((ParamCount = 1) or (ParamCount = 2),
      'Usage: pythian.tests.studio.library FRESH_ROOT [LINKED_LIBRARY_ROOT]');
    Run(ParamStr(1));
  except
    on LException: Exception do
    begin
      WriteLn(StdErr, LException.ClassName, ': ', LException.Message);
      ExitCode := 1;
    end;
  end;
end.
