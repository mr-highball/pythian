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
program ListeningAssetConformance;
{$mode delphi}
{$H+}

uses Classes, SysUtils, fpjson, pythian.audio, pythian.hash, pythian.wave.stream,
  pythian.tools.listen.assets, pythian.tools.annotations.sourceguard;

var
  GChecks: Integer;

procedure Check(const ACondition: Boolean; const AMessage: String);
begin
  if not ACondition then raise Exception.Create(AMessage);
  Inc(GChecks);
end;

function FileHash(const APath: String): String;
var
  LFile: TFileStream;
begin
  LFile := TFileStream.Create(APath, fmOpenRead or fmShareDenyWrite);
  try
    Result := Sha256Stream(LFile, LFile.Size);
  finally
    LFile.Free;
  end;
end;

procedure CopyOwnedFile(const AFrom, ATo: String);
var
  LFrom, LTo: TFileStream;
begin
  LFrom := TFileStream.Create(AFrom, fmOpenRead or fmShareDenyWrite);
  try
    LTo := TFileStream.Create(ATo, fmCreate);
    try LTo.CopyFrom(LFrom, LFrom.Size); finally LTo.Free; end;
  finally LFrom.Free; end;
end;

function WriteAudio(const ACatalog: String; const AValue: Single): TJSONObject;
var
  LOutput: TListeningAssetWriter;
  LWave: TWavePcm16Writer;
  LBlock: TAudioSamples;
  I: Integer;
begin
  LWave := nil;
  LOutput := TListeningAssetWriter.Create(ACatalog);
  try
    LWave := TWavePcm16Writer.Create(LOutput, 24000, 2, 3000);
    SetLength(LBlock, 2000);
    for I := 0 to High(LBlock) do LBlock[I] := AValue;
    for I := 0 to 2 do LWave.AppendSamples(LBlock);
    LWave.Finish;
    Result := LOutput.Finish;
  finally
    LWave.Free;
    LOutput.Free;
  end;
end;

procedure Run(const ARoot: String);
var
  LCatalog, LOtherCatalog, LPath, LLegacy, LSource, LStage: String;
  LHash, LIdentity: String;
  LAsset, LAgain: TJSONObject;
  LInfo: TListeningAssetInfo;
  LWriter: TListeningAssetWriter;
  LWave: TWavePcm16Writer;
  LFile: TFileStream;
  LBytes: TAudioBytes;
  LRejected: Boolean;
  I: Integer;
begin
  Check(not DirectoryExists(ARoot), 'Fixture root must be fresh');
  LCatalog := ARoot + PathDelim + 'catalog';
  LOtherCatalog := ARoot + PathDelim + 'other-catalog';
  Check(ForceDirectories(LCatalog) and ForceDirectories(LOtherCatalog), 'Create catalogs');
  LAsset := WriteAudio(LCatalog, 0.125);
  try
    LHash := LAsset.Strings['sha256'];
    LPath := ListeningAssetPath(LCatalog, LHash);
    Check(FileExists(LPath) and (FileHash(LPath) = LHash), 'Written bytes match output digest');
    Check((LAsset.Count = 6) and (Pos(ARoot, LAsset.AsJSON) = 0), 'Public descriptor excludes host receipt/path');
    LInfo := InspectListeningWave(LPath, LHash, True);
    Check((LInfo.Frames = 3000) and (LInfo.Channels = 2) and (LInfo.Bytes = 12044), 'Primary geometry');
    for I := 0 to 3 do VerifyListeningAsset(LPath, LHash, LInfo.Bytes);
    Check(True, 'Repeated guarded opens');
    LAgain := WriteAudio(LCatalog, 0.125);
    try Check(LAgain.AsJSON = LAsset.AsJSON, 'Duplicate output reuses canonical descriptor');
    finally LAgain.Free; end;
    LSource := ARoot + PathDelim + 'original.wav';
    CopyOwnedFile(LPath, LSource);
    LAgain := ImportListeningAsset(LCatalog, LSource);
    try Check(LAgain.AsJSON = LAsset.AsJSON, 'Existing input imports through shared writer');
    finally LAgain.Free; end;
    Check(FileExists(LSource) and (FileHash(LSource) = LHash), 'Import preserves original');
    if SysUtils.GetEnvironmentVariable('PYTHIAN_STUDIO_ARTIFACT_ROOT') <> '' then
    begin
      Check(Pos(IncludeTrailingPathDelimiter(ExpandFileName(
        SysUtils.GetEnvironmentVariable('PYTHIAN_STUDIO_ARTIFACT_ROOT'))), LPath) = 1,
        'Configured store owns new output');
      Check(ListeningAssetDirectory(LCatalog) <> ListeningAssetDirectory(LOtherCatalog),
        'Configured catalogs are isolated');
    end;
    { An actual pre-existing catalog asset remains readable after root selection. }
    LLegacy := IncludeTrailingPathDelimiter(LOtherCatalog) + 'listening' + PathDelim + 'assets';
    Check(ForceDirectories(LLegacy), 'Legacy directory');
    LLegacy := IncludeTrailingPathDelimiter(LLegacy) + LHash + '.wav';
    CopyOwnedFile(LSource, LLegacy);
    Check(ListeningAssetPath(LOtherCatalog, LHash) = LLegacy, 'Legacy read fallback');
    LInfo := InspectListeningWave(LLegacy, LHash, True);
    Check(LInfo.Frames = 3000, 'Legacy content verified');
    { The receipt is a native publisher assertion, not a browser-controlled hash.
      A direct guard call with a deliberately different declaration proves the
      matching identity path performs no payload reread. Production receipts
      above are independently checked against the actual hash. }
    LIdentity := SourceFileIdentity(LSource, 12044);
    if LIdentity <> '' then
    begin
      VerifyGuardedSource(LSource, StringOfChar('0', 64), 12044, LIdentity);
      Check(True, 'Trusted native identity primes guard without payload hashing');
    end;
  finally
    LAsset.Free;
  end;
  { Alter a newly published file before its first guarded read. Same length,
    different content and explicit changed timestamp must reject its receipt. }
  LAsset := WriteAudio(LCatalog, -0.125);
  try
    LPath := ListeningAssetPath(LCatalog, LAsset.Strings['sha256']);
    LFile := TFileStream.Create(LPath, fmOpenReadWrite or fmShareExclusive);
    try
      LFile.Position := 44;
      SetLength(LBytes, 1);
      LBytes[0] := 19;
      LFile.WriteBuffer(LBytes[0], 1);
    finally LFile.Free; end;
    Check(FileSetDate(LPath, FileAge(LPath) - 32) = 0, 'Force changed file timestamp');
    LRejected := False;
    try VerifyListeningAsset(LPath, LAsset.Strings['sha256'], LAsset.Int64s['bytes']);
    except on E: EAudio do LRejected := True; end;
    Check(LRejected, 'Changed output identity/content rejected');
  finally LAsset.Free; end;
  LWriter := TListeningAssetWriter.Create(LCatalog, 'cancelled-test-job');
  try
    LStage := LWriter.StagePath;
    Check(Pos('cancelled-test-job', LStage) > 0, 'Failure stage identifies its owner');
    LBytes := WavePcm16Header(24000, 2, 1000);
    LWriter.WriteBytes(LBytes);
    LRejected := False;
    try LAgain := LWriter.Finish; LAgain.Free;
    except on E: EAudio do LRejected := True; end;
    Check(LRejected and FileExists(LStage), 'Truncated output retained as unpublished evidence');
    LRejected := False;
    try LAgain := LWriter.Finish; LAgain.Free;
    except on E: EAudio do LRejected := True; end;
    Check(LRejected, 'Failed publication cannot be retried as success');
  finally LWriter.Free; end;
  LWriter := TListeningAssetWriter.Create(LCatalog);
  LWave := nil;
  try
    LStage := LWriter.StagePath;
    LWave := TWavePcm16Writer.Create(LWriter, 24000, 2, 1000);
    { Cancellation destroys owners without publishing, even if a header exists. }
  finally LWave.Free; LWriter.Free; end;
  Check(FileExists(LStage), 'Cancelled stage retains identifiable evidence');
end;

begin
  try
    Check(ParamCount = 1, 'Usage: listen assets FRESH_ROOT');
    Run(ExpandFileName(ParamStr(1)));
    WriteLn('PASS listening asset ownership, identity, deduplication and legacy access: ', GChecks, ' checks');
  except
    on E: Exception do
    begin
      WriteLn(StdErr, E.ClassName, ': ', E.Message);
      DumpExceptionBackTrace(StdErr);
      ExitCode := 1;
    end;
  end;
end.
