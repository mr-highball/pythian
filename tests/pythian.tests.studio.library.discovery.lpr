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
program StudioLibraryDiscoveryConformance;

{$mode delphi}
{$H+}

uses
  Classes,
  SysUtils,
  fpjson,
  pythian.audio,
  pythian.hash,
  pythian.wave,
  pythian.wave.read,
  pythian.tools.annotations.catalog,
  pythian.tools.annotations.media,
  pythian.tools.studio.&library,
  pythian.tools.studio.&library.discovery;

type
  TPayloadGuard = class(TStream)
  private
    FSource: TStream;
  public
    ReadBytes: Int64;
    constructor Create(const ASource: TStream);
    function Read(var ABuffer; ACount: Longint): Longint; override;
    function Write(const ABuffer; ACount: Longint): Longint; override;
    function Seek(const AOffset: Int64; AOrigin: TSeekOrigin): Int64; override;
  end;
  TProbe = class
  public
    StopStage: String;
    MutatePath: String;
    MutationDone: Boolean;
    HashPasses: Integer;
    procedure Progress(const AStage: String; const ADone, ATotal: Int64);
  end;

var
  GChecks: Integer;
  GRoot: String;
  GStage: Integer;

procedure Check(const ACondition: Boolean; const AMessage: String);
begin
  Inc(GChecks);
  if not ACondition then
    raise Exception.Create(AMessage);
end;

constructor TPayloadGuard.Create(const ASource: TStream);
begin
  inherited Create;
  FSource := ASource;
end;

function TPayloadGuard.Read(var ABuffer; ACount: Longint): Longint;
begin
  Check(FSource.Position + ACount <= 44, 'Header reader must not touch PCM payload');
  Result := FSource.Read(ABuffer, ACount);
  Inc(ReadBytes, Result);
end;

function TPayloadGuard.Write(const ABuffer; ACount: Longint): Longint;
begin
  Result := 0;
  raise Exception.Create('Read-only conformance stream');
end;

function TPayloadGuard.Seek(const AOffset: Int64; AOrigin: TSeekOrigin): Int64;
begin
  Result := FSource.Seek(AOffset, AOrigin);
end;

procedure FlipByte(const APath: String; const AOffset: Int64);
var
  LStream: TFileStream;
  LValue: Byte;
  LDate: Longint;
begin
  LStream := TFileStream.Create(APath, fmOpenReadWrite);
  try
    LDate := FileGetDate(LStream.Handle);
    LStream.Position := AOffset;
    LStream.ReadBuffer(LValue, 1);
    LValue := LValue xor 1;
    LStream.Position := AOffset;
    LStream.WriteBuffer(LValue, 1);
  finally
    LStream.Free;
  end;
  Check(FileSetDate(APath, LDate) = 0,
    'Restore stat to test same-metadata content change');
  LStream := TFileStream.Create(APath, fmOpenRead);
  try
    Check(FileGetDate(LStream.Handle) = LDate,
      'Verify original timestamp after same-metadata content change');
  finally
    LStream.Free;
  end;
end;

procedure TProbe.Progress(const AStage: String; const ADone, ATotal: Int64);
begin
  if ((AStage = 'hashing_source_bytes') or (AStage = 'verifying_catalog_bytes') or
    (AStage = 'verifying_original_bytes')) and (ADone = ATotal) then
    Inc(HashPasses);
  if (AStage = StopStage) and (MutatePath <> '') and not MutationDone then
  begin
    FlipByte(MutatePath, 24);
    MutationDone := True;
  end
  else if AStage = StopStage then
    raise EAudio.Create('Authored cancellation control');
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

procedure MakeWave(const APath: String; const AAmplitude: Single);
var
  LSamples: TAudioSamples;
  LClip: TAudioClip;
  LIndex: Integer;
begin
  SetLength(LSamples, 16000);
  for LIndex := 0 to High(LSamples) do
    LSamples[LIndex] := AAmplitude;
  LClip := TAudioClip.Create(8000, 1, LSamples);
  try
    SaveWavePcm16(APath, LClip);
  finally
    LClip.Free;
  end;
end;

procedure LargeWave(const APath: String);
var
  LStream: TFileStream;
  LTemplate: TFileStream;
  LHeader: array[0..43] of Byte;
  LSize: Cardinal;
  LZero: Byte;
begin
  LTemplate := TFileStream.Create(GRoot + 'library' + PathDelim + 'collections' +
    PathDelim + 'one' + PathDelim + 'a.wav', fmOpenRead);
  try
    LTemplate.ReadBuffer(LHeader[0], 44);
  finally
    LTemplate.Free;
  end;
  LSize := 16777216;
  Move(LSize, LHeader[40], 4);
  Inc(LSize, 36);
  Move(LSize, LHeader[4], 4);
  LStream := TFileStream.Create(APath, fmCreate);
  try
    LStream.WriteBuffer(LHeader[0], 44);
    LStream.Position := 16777216 + 43;
    LZero := 0;
    LStream.WriteBuffer(LZero, 1);
  finally
    LStream.Free;
  end;
end;

function RowNamed(const AIndex: TJSONObject; const AName: String): TJSONObject;
var
  LIndex: Integer;
begin
  for LIndex := 0 to AIndex.Arrays['entries'].Count - 1 do
    if AIndex.Arrays['entries'].Objects[LIndex].Strings['original_name'] = AName then
      Exit(AIndex.Arrays['entries'].Objects[LIndex]);
  raise Exception.Create('Conformance entry missing');
end;

function Selection(const ARow: TJSONObject): TJSONArray;
var
  LRow: TJSONObject;
begin
  Result := TJSONArray.Create;
  LRow := TJSONObject.Create;
  LRow.Add('entry_id', ARow.Strings['entry_id']);
  LRow.Add('entry_snapshot_sha256', ARow.Strings['entry_snapshot_sha256']);
  Result.Add(LRow);
end;

function Stage: String;
begin
  Inc(GStage);
  Result := GRoot + 'stage-' + IntToStr(GStage);
end;

procedure Run(const ARoot: String);
var
  LCatalog: String;
  LLibrary: String;
  LAudio: String;
  LIndex: TJSONObject;
  LCurrent: TJSONObject;
  LRow: TJSONObject;
  LReport: TJSONObject;
  LMetadata: TJSONObject;
  LSelection: TJSONArray;
  LStream: TStream;
  LFile: TFileStream;
  LGuard: TPayloadGuard;
  LWave: TWaveFrameReader;
  LProbe: TProbe;
  LHash: String;
  LPriorDigest: String;
  LFailed: Boolean;
  LRevision: Integer;
begin
  Check(not DirectoryExists(ARoot), 'Fixture root must be fresh');
  GRoot := IncludeTrailingPathDelimiter(ARoot);
  LCatalog := GRoot + 'catalog';
  LLibrary := GRoot + 'library';
  Check(ForceDirectories(LCatalog), 'Catalog root');
  Check(ForceDirectories(LLibrary + '/collections/one'), 'First collection');
  Check(ForceDirectories(LLibrary + '/collections/two'), 'Second collection');
  LAudio := LLibrary + '/collections/one/a.wav';
  MakeWave(LAudio, 0.125);
  MakeWave(LLibrary + '/collections/two/b.wav', -0.25);
  LargeWave(LLibrary + '/collections/two/large.wav');
  LFile := TFileStream.Create(LLibrary + '/collections/two/large.wav', fmOpenRead);
  try
    LGuard := TPayloadGuard.Create(LFile);
    try
      LReport := InspectStudioLibraryHeader(LGuard);
      try
        Check(LReport.Int64s['frame_count'] = 8388608, 'Large valid logical WAV geometry');
        Check((LGuard.ReadBytes <= 44) and (LReport.Int64s['header_read_bytes'] = LGuard.ReadBytes),
          'Large-file header proof independent of payload length');
      finally
        LReport.Free;
      end;
    finally
      LGuard.Free;
    end;
  finally
    LFile.Free;
  end;
  LIndex := DiscoverStudioLibrary(LCatalog, LLibrary);
  try
    Check((LIndex.Integers['available_count'] = 3) and
      (LIndex.Integers['collection_count'] = 2), 'Metadata discoveries');
    Check((LIndex.Int64s['header_read_bytes'] <= 132) and
      (LIndex.Int64s['content_read_bytes'] = 0) and (LIndex.Integers['imported_count'] = 0),
      'Discovery has no content-hash/copy/import work');
    Check(not DirectoryExists(LCatalog + '/sources'), 'Discovery does not create catalog media');
    Check(RenameFile(LLibrary, LLibrary + '-offline'), 'Temporarily remove library');
    LCurrent := ListStudioLibraryDiscovery(LCatalog);
    try
      Check(LCurrent.AsJSON = LIndex.AsJSON, 'Offline listing reads published metadata only');
    finally
      LCurrent.Free;
    end;
    Check(RenameFile(LLibrary + '-offline', LLibrary), 'Restore library');
    LRow := RowNamed(LIndex, 'a.wav');
    Check((LRow.Strings['content_validation'] = 'not_verified') and
      (LRow.Find('source_sha256') = nil), 'Entry metadata digest is not audio identity');
    LReport := ReadStudioLibraryWaveform(LCatalog, LLibrary, 1,
      RowNamed(LIndex, 'large.wav').Strings['entry_id'],
      RowNamed(LIndex, 'large.wav').Strings['entry_snapshot_sha256'], 0, 8388608, 256);
    try
      Check((LReport.Int64s['sampled_frame_count'] = 16384) and
        (LReport.Int64s['payload_read_bytes'] = 32768),
        'Whole long-file overview reads fixed sparse windows, not full payload');
    finally
      LReport.Free;
    end;
    LFailed := False;
    try
      LStream := OpenStudioLibraryEntryAudio(LCatalog, LLibrary, 1,
        RowNamed(LIndex, 'large.wav').Strings['entry_id'],
        RowNamed(LIndex, 'large.wav').Strings['entry_snapshot_sha256'],
        0, 240001, LMetadata);
      LMetadata.Free;
      LStream.Free;
    except
      on EAudio do LFailed := True;
    end;
    Check(LFailed, 'Preview beyond30seconds rejects before payload allocation');
    FlipByte(LAudio, 24);
    LFailed := False;
    try
      LStream := OpenStudioLibraryEntryAudio(LCatalog, LLibrary, 1, LRow.Strings['entry_id'],
        LRow.Strings['entry_snapshot_sha256'], 0, 64, LMetadata);
      LMetadata.Free;
      LStream.Free;
    except
      on EAudio do LFailed := True;
    end;
    Check(LFailed, 'Stale header blocks provisional audition without usable bytes');
    FlipByte(LAudio, 24);
    LReport := ReadStudioLibraryWaveform(LCatalog, LLibrary, 1, LRow.Strings['entry_id'],
      LRow.Strings['entry_snapshot_sha256'], 0, 16000, 128);
    try
      Check((LReport.Int64s['sampled_frame_count'] = 8192) and
        (LReport.Int64s['payload_read_bytes'] = 16384), 'Waveform bounded uniform sample count');
      Check((LReport.Arrays['bins'].Objects[0].Floats['peak'] > 0.12) and
        (LReport.Strings['content_validation'] = 'metadata_only_unverified'),
        'Waveform measured provisional amplitude');
    finally
      LReport.Free;
    end;
    LStream := OpenStudioLibraryEntryAudio(LCatalog, LLibrary, 1, LRow.Strings['entry_id'],
      LRow.Strings['entry_snapshot_sha256'], 8000, 12000, LMetadata);
    try
      Check(LMetadata.Int64s['source_start_frame'] = 8000, 'Preview retains original offset');
      Check((LMetadata.Int64s['payload_read_bytes'] = 8000) and
        (LMetadata.Int64s['preview_frame_count'] = 4000), 'Preview reads selected frames only');
      Check(Sha256Stream(LStream, LStream.Size) = LMetadata.Strings['preview_sha256'],
        'Actual preview bytes bound by preview hash');
      LStream.Position := 0;
      LWave := TWaveFrameReader.Create(LStream);
      try
        Check((LWave.FrameCount = 4000) and (LWave.SampleRate = 8000), 'Exact preview clock');
      finally
        LWave.Free;
      end;
    finally
      LMetadata.Free;
      LStream.Free;
    end;
    LSelection := Selection(LRow);
    try
      LReport := PrepareStudioLibraryEntries(LCatalog, LLibrary, Stage, 1, LSelection);
      try
        LHash := HashFile(LAudio);
        Check((LReport.Arrays['mappings'].Count = 1) and
          (LReport.Arrays['mappings'].Objects[0].Strings['source_sha256'] = LHash),
          'Only selected original gets real source hash');
        Check(LReport.Arrays['mappings'].Objects[0].Strings['status'] = 'imported',
          'New selected source admission');
      finally
        LReport.Free;
      end;
      LReport := ListLabelCatalog(LCatalog);
      try
        Check(LReport.Arrays['tracks'].Count = 1, 'Unrelated originals not imported');
      finally
        LReport.Free;
      end;
      LProbe := TProbe.Create;
      try
        LReport := PrepareStudioLibraryEntries(LCatalog, LLibrary, Stage, 1, LSelection,
          LProbe.Progress);
        try
          Check(LReport.Arrays['mappings'].Objects[0].Strings['status'] = 'existing',
            'Verified reuse of selected source');
          Check(LProbe.HashPasses = 3, 'Reuse retains three complete integrity passes');
        finally
          LReport.Free;
        end;
        Check(not DirectoryExists(GRoot + 'stage-' + IntToStr(GStage)),
          'Existing original has no full staging copy');
        LCurrent := ListStudioLibrary(LCatalog);
        try
          LPriorDigest := LCurrent.Strings['index_sha256'];
        finally
          LCurrent.Free;
        end;
        FlipByte(LCatalog + '/sources/' + LHash + '.wav', 44);
        LFailed := False;
        try
          LReport := PrepareStudioLibraryEntries(LCatalog, LLibrary, Stage, 1, LSelection);
          LReport.Free;
        except
          on EAudio do LFailed := True;
        end;
        Check(LFailed, 'Same-size catalog corruption rejects verified reuse');
        FlipByte(LCatalog + '/sources/' + LHash + '.wav', 44);
        LCurrent := ListStudioLibrary(LCatalog);
        try
          Check(LCurrent.Strings['index_sha256'] = LPriorDigest, 'Failure keeps prior published index');
        finally
          LCurrent.Free;
        end;
        LProbe.StopStage := 'publishing_index';
        LFailed := False;
        try
          LReport := PrepareStudioLibraryEntries(LCatalog, LLibrary, Stage, 1, LSelection,
            LProbe.Progress);
          LReport.Free;
        except
          on EAudio do LFailed := True;
        end;
        Check(LFailed, 'Cancellation before verified-index publication');
        LProbe.StopStage := 'rechecking_selected_metadata';
        LProbe.MutatePath := LAudio;
        LFailed := False;
        try
          LReport := PrepareStudioLibraryEntries(LCatalog, LLibrary, Stage, 1, LSelection,
            LProbe.Progress);
          LReport.Free;
        except
          on EAudio do LFailed := True;
        end;
        Check(LFailed and LProbe.MutationDone, 'Changed header after verification emits no usable receipt');
        FlipByte(LAudio, 24);
      finally
        LProbe.Free;
      end;
      FlipByte(LAudio, 44);
      LReport := PrepareStudioLibraryEntries(LCatalog, LLibrary, Stage, 1, LSelection);
      try
        Check(LReport.Arrays['mappings'].Objects[0].Strings['source_sha256'] <> LHash,
          'Same stat/header but changed payload gets new actual content identity');
        Check(FileExists(LCatalog + '/sources/' + LHash + '.wav'),
          'Previous immutable source preserved');
      finally
        LReport.Free;
      end;
      FlipByte(LAudio, 44);
      LSelection.Objects[0].Strings['entry_snapshot_sha256'] := StringOfChar('0', 64);
      LFailed := False;
      try
        LReport := ValidateStudioLibraryEntries(LCatalog, 1, LSelection);
        LReport.Free;
      except
        on EAudio do LFailed := True;
      end;
      Check(LFailed, 'False entry snapshot rejected before source I/O');
    finally
      LSelection.Free;
    end;
    LSelection := Selection(RowNamed(LIndex, 'b.wav'));
    try
      LReport := PrepareStudioLibraryEntries(LCatalog, LLibrary, Stage, 1, LSelection);
      LReport.Free;
    finally
      LSelection.Free;
    end;
    LSelection := Selection(LRow);
    try
      LReport := PrepareStudioLibraryEntries(LCatalog, LLibrary, Stage, 1, LSelection);
      LReport.Free;
    finally
      LSelection.Free;
    end;
    LReport := ListStudioLibrary(LCatalog);
    try
      Check(LReport.Integers['recording_count'] = 2,
        'Preparing one entry preserves unrelated previously prepared membership');
    finally
      LReport.Free;
    end;
    LSelection := Selection(RowNamed(LIndex, 'large.wav'));
    try
      LReport := PrepareStudioLibraryEntries(LCatalog, LLibrary, Stage, 1, LSelection);
      try
        LHash := LReport.Arrays['mappings'].Objects[0].Strings['source_sha256'];
      finally
        LReport.Free;
      end;
    finally
      LSelection.Free;
    end;
    LReport := CatalogWaveformRegion(LCatalog, LHash, 0, 8388608, 256, True);
    try
      Check((LReport.Strings['sampling'] = 'uniform_windows') and
        (LReport.Int64s['sampled_frame_count'] = 16384) and
        (LReport.Int64s['payload_read_bytes'] = 32768),
        'Prepared whole-track overview shares bounded sampling, not full PCM scan');
      Check(LReport.Arrays['bins'].Objects[255].Int64s['end_frame'] = 8388608,
        'Overview bins retain full original extent');
    finally
      LReport.Free;
    end;
    LReport := CatalogWaveformRegion(LCatalog, LHash, 8388607, 8388608, 1, True);
    try
      Check((LReport.Int64s['sampled_frame_count'] = 1) and
        (LReport.Int64s['payload_read_bytes'] = 2) and
        (LReport.Arrays['bins'].Objects[0].Int64s['sampled_start_frame'] = 8388607),
        'Single final frame samples exact late source clock');
    finally
      LReport.Free;
    end;
    LFailed := False;
    try
      LReport := CatalogWaveformRegion(LCatalog, LHash, 0, 8388608, 257, True);
      LReport.Free;
    except
      on EAudio do LFailed := True;
    end;
    Check(LFailed, 'Sampled catalog overview enforces finite window count');
    LFailed := False;
    try
      LReport := CatalogWaveformRegion(LCatalog, LHash, 8388607, 8388609, 1, True);
      LReport.Free;
    except
      on EAudio do LFailed := True;
    end;
    Check(LFailed, 'Overview cannot sample beyond original extent');
    LProbe := TProbe.Create;
    try
      LProbe.StopStage := 'publishing_discovery';
      LFailed := False;
      try
        LReport := DiscoverStudioLibrary(LCatalog, LLibrary, LProbe.Progress);
        LReport.Free;
      except
        on EAudio do LFailed := True;
      end;
      Check(LFailed, 'Cancel metadata discovery before atomic publication');
      LReport := ListStudioLibraryDiscovery(LCatalog);
      try
        Check(LReport.Strings['index_sha256'] = LIndex.Strings['index_sha256'],
          'Cancelled discovery keeps previous complete snapshot');
      finally
        LReport.Free;
      end;
    finally
      LProbe.Free;
    end;
    Check(DeleteFile(LLibrary + '/collections/two/b.wav'), 'Remove unprepared original');
    LCurrent := DiscoverStudioLibrary(LCatalog, LLibrary);
    try
      Check((LCurrent.Integers['missing_count'] = 1) and
        (RowNamed(LCurrent, 'b.wav').Strings['status'] = 'missing'), 'Missing entries retained honestly');
      LRevision := LCurrent.Integers['revision'];
      LPriorDigest := LCurrent.Strings['index_sha256'];
    finally
      LCurrent.Free;
    end;
    Check(ForceDirectories(LLibrary + '/collections/one/nested'), 'Create unsafe nested control');
    LFailed := False;
    try
      LCurrent := DiscoverStudioLibrary(LCatalog, LLibrary);
      LCurrent.Free;
    except
      on EAudio do LFailed := True;
    end;
    Check(LFailed, 'Nested discovery refuses arbitrary path traversal');
    LCurrent := ListStudioLibraryDiscovery(LCatalog);
    try
      Check((LCurrent.Integers['revision'] = LRevision) and
        (LCurrent.Strings['index_sha256'] = LPriorDigest), 'Discovery failure preserves prior snapshot');
    finally
      LCurrent.Free;
    end;
  finally
    LIndex.Free;
  end;
end;

begin
  try
    if ParamCount <> 1 then
      raise Exception.Create('Usage: discovery test FRESH_ROOT');
    Run(ExpandFileName(ParamStr(1)));
    WriteLn('PASS ', GChecks, ' metadata discovery and selected-use checks');
  except
    on E: Exception do
    begin
      WriteLn(StdErr, E.ClassName, ': ', E.Message);
      ExitCode := 1;
    end;
  end;
end.
