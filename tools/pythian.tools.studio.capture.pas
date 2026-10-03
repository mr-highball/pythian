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
unit pythian.tools.studio.capture;

{$mode delphi}
{$H+}

interface

uses pythian.progress, Classes, fpjson, pythian.tools.studio.effects;

const
  MaximumStudioUploadBytes = 134217728;
  MaximumStudioUploadChunk = 16384;

function StartStudioCapture(const ACatalogRoot: String; const AWrite: TJSONObject): TJSONObject;
function AppendStudioCapture(const ACatalogRoot: String; const AWrite: TJSONObject): TJSONObject;
function ReadStudioCapture(const ACatalogRoot, ACaptureId: String): TJSONObject;
function ListStudioCaptures(const ACatalogRoot: String): TJSONObject;
function DiscardStudioCapture(const ACatalogRoot, ACaptureId: String): TJSONObject;
function InspectStudioCapture(const ACatalogRoot, ACaptureId: String;
  const ACheck: TStudioEffectCheck = nil;
  const AProgress: TWorkProgressCallback = nil): TJSONObject;
function SaveStudioCapture(const ACatalogRoot, AJobId, ALibraryRoot: String;
  const AWrite: TJSONObject; const ACheck: TStudioEffectCheck = nil;
  const AProgress: TWorkProgressCallback = nil): TJSONObject;
function OpenStudioCapture(const ACatalogRoot, ACaptureId: String;
  out AHash, APath: String): TFileStream;

implementation

uses SysUtils, Math, Base64,
  pythian.audio, pythian.hash, pythian.wave.read,
  pythian.tools.annotations.catalog, pythian.tools.annotations.media,
  pythian.tools.annotations.proposal, pythian.tools.studio.jobs,
  pythian.tools.studio.&library
  {$IFDEF MSWINDOWS}, Windows{$ENDIF};

procedure Need(const ACondition: Boolean; const AMessage: String);
begin
  if not ACondition then
  begin
    raise EAudio.Create(AMessage);
  end;
end;

procedure CheckPath(const APath: String);
var
  LPath: String;
  LAttributes: LongInt;
begin
  LPath := ExpandFileName(APath);
  while Length(LPath) > Length(ExtractFileDrive(LPath)) + 1 do
  begin
    LAttributes := FileGetAttr(LPath);
    if LAttributes <> -1 then
    begin
      {$IFDEF MSWINDOWS}
      Need((LAttributes and FILE_ATTRIBUTE_REPARSE_POINT) = 0, 'Linked capture paths are unsupported');
      {$ELSE}
      Need((LAttributes and faSymLink) = 0, 'Linked capture paths are unsupported');
      {$ENDIF}
    end;
    LPath := ExcludeTrailingPathDelimiter(ExtractFileDir(LPath));
  end;
end;

function CaptureRoot(const ACatalogRoot, ACaptureId: String): String;
var
  LCharacter: Char;
begin
  Need((Length(ACaptureId) > 0) and (Length(ACaptureId) <= 48), 'Invalid temporary audio identity');
  ValidateStudioCollectionName(ACaptureId);
  for LCharacter in ACaptureId do
  begin
    Need(LCharacter in ['a'..'z', 'A'..'Z', '0'..'9', '-', '_'], 'Invalid temporary audio identity');
  end;
  Result := ExpandFileName('build' + PathDelim + 'studio-capture' + PathDelim +
    Copy(StudioTextHash(ExpandFileName(ACatalogRoot)), 1, 16) + PathDelim + ACaptureId);
  CheckPath(Result);
end;

procedure Keys(const AWrite: TJSONObject; const AAllowed: String);
var
  LIndex: Integer;
begin
  Need(AWrite <> nil, 'Capture request is required');
  for LIndex := 0 to AWrite.Count - 1 do
  begin
    Need(Pos('|' + AWrite.Names[LIndex] + '|', AAllowed) > 0, 'Unsupported capture field');
  end;
end;

function ReadStudioCapture(const ACatalogRoot, ACaptureId: String): TJSONObject;
var
  LRoot: String;
  LStream: TFileStream;
begin
  LRoot := CaptureRoot(ACatalogRoot, ACaptureId);
  Result := ReadStudioJSON(LRoot + PathDelim + 'request.json');
  try
    CheckPath(LRoot + PathDelim + 'incoming' + PathDelim + 'input.wav');
    LStream := TFileStream.Create(LRoot + PathDelim + 'incoming' + PathDelim + 'input.wav',
      fmOpenRead or fmShareDenyWrite);
    try
      Result.Add('received_bytes', LStream.Size);
      Result.Add('complete', LStream.Size = Result.Int64s['bytes']);
      Result.Add('inspected', FileExists(LRoot + PathDelim + 'analysis.json'));
    finally
      LStream.Free;
    end;
  except
    Result.Free;
    raise;
  end;
end;

function StartStudioCapture(const ACatalogRoot: String; const AWrite: TJSONObject): TJSONObject;
var
  LRoot: String;
  LExisting: TJSONObject;
  LSearch: TSearchRec;
  LCount: Integer;
  LStream: TFileStream;
begin
  Keys(AWrite, '|capture_id|name|bytes|origin|');
  Need((AWrite.Find('bytes') <> nil) and (AWrite.Find('bytes').JSONType = jtNumber) and
    (AWrite.Floats['bytes'] = AWrite.Int64s['bytes']) and
    (AWrite.Int64s['bytes'] >= 44) and (AWrite.Int64s['bytes'] <= MaximumStudioUploadBytes),
    'Import a WAV between 44 bytes and 128 MiB');
  Need((Length(AWrite.Get('name', '')) > 0) and (Length(AWrite.Get('name', '')) <= 128),
    'Audio name must contain one to 128 bytes');
  Need((AWrite.Get('origin', '') = 'wav_import') or (AWrite.Get('origin', '') = 'microphone'),
    'Choose WAV import or microphone capture');
  LRoot := CaptureRoot(ACatalogRoot, AWrite.Get('capture_id', ''));
  if FileExists(LRoot + PathDelim + 'request.json') then
  begin
    LExisting := ReadStudioJSON(LRoot + PathDelim + 'request.json');
    try
      Need(LExisting.AsJSON = AWrite.AsJSON, 'This upload identity has different settings');
    finally
      LExisting.Free;
    end;
    Exit(ReadStudioCapture(ACatalogRoot, AWrite.Strings['capture_id']));
  end;
  Need(not DirectoryExists(LRoot), 'Interrupted upload exists; discard it before importing again');
  LCount := 0;
  if FindFirst(ExtractFileDir(LRoot) + PathDelim + '*', faDirectory, LSearch) = 0 then
  begin
    try
      repeat
        if ((LSearch.Attr and faDirectory) <> 0) and
          (LSearch.Name <> '.') and (LSearch.Name <> '..') then
        begin
          Inc(LCount);
        end;
      until FindNext(LSearch) <> 0;
    finally
      SysUtils.FindClose(LSearch);
    end;
  end;
  Need(LCount < 8, 'Eight temporary inputs are retained; discard an earlier input first');
  Need(ForceDirectories(LRoot + PathDelim + 'incoming'), 'Could not create temporary audio folder');
  LStream := TFileStream.Create(LRoot + PathDelim + 'incoming' + PathDelim + 'input.wav',
    fmCreate or fmShareExclusive);
  LStream.Free;
  WriteStudioJSONNew(LRoot + PathDelim + 'request.json', AWrite);
  Result := ReadStudioCapture(ACatalogRoot, AWrite.Strings['capture_id']);
end;

function AppendStudioCapture(const ACatalogRoot: String; const AWrite: TJSONObject): TJSONObject;
var
  LRoot: String;
  LState: TJSONObject;
  LBytes: String;
  LOld: String;
  LStream: TFileStream;
  LOffset: Int64;
  LOverlap: Integer;
begin
  Keys(AWrite, '|capture_id|offset|data|');
  Need((AWrite.Find('offset') <> nil) and (AWrite.Find('offset').JSONType = jtNumber) and
    (AWrite.Floats['offset'] = AWrite.Int64s['offset']) and (AWrite.Int64s['offset'] >= 0),
    'Upload offset must be a nonnegative byte count');
  Need((Length(AWrite.Get('data', '')) > 0) and (Length(AWrite.Get('data', '')) <= 21848),
    'Upload chunk exceeds 16 KiB');
  LBytes := DecodeStringBase64(AWrite.Strings['data'], True);
  Need((Length(LBytes) > 0) and (Length(LBytes) <= MaximumStudioUploadChunk), 'Invalid upload chunk');
  LRoot := CaptureRoot(ACatalogRoot, AWrite.Get('capture_id', ''));
  LState := ReadStudioCapture(ACatalogRoot, AWrite.Strings['capture_id']);
  try
    Need(not LState.Booleans['inspected'], 'Inspected audio is immutable; use a new import');
    LOffset := AWrite.Int64s['offset'];
    Need((LOffset <= LState.Int64s['received_bytes']) and
      (LOffset + Length(LBytes) <= LState.Int64s['bytes']), 'Upload chunk leaves declared audio');
    LStream := TFileStream.Create(LRoot + PathDelim + 'incoming' + PathDelim + 'input.wav',
      fmOpenReadWrite or fmShareExclusive);
    try
      LOverlap := Min(Int64(Length(LBytes)), LStream.Size - LOffset);
      SetLength(LOld, LOverlap);
      LStream.Position := LOffset;
      if LOverlap > 0 then
      begin
        LStream.ReadBuffer(LOld[1], LOverlap);
        Need(LOld = Copy(LBytes, 1, LOverlap), 'Retried upload bytes differ');
      end;
      if LOverlap < Length(LBytes) then
      begin
        LStream.WriteBuffer(LBytes[LOverlap + 1], Length(LBytes) - LOverlap);
      end;
    finally
      LStream.Free;
    end;
  finally
    LState.Free;
  end;
  Result := ReadStudioCapture(ACatalogRoot, AWrite.Strings['capture_id']);
end;

function Manifest(const AHash, AName, AOrigin: String; const AExisting: TJSONObject): TJSONObject;
var
  LRows: TJSONArray;
  LRow: TJSONObject;
begin
  Result := TJSONObject.Create;
  Result.Add('version', 1);
  LRows := TJSONArray.Create;
  Result.Add('tracks', LRows);
  LRow := TJSONObject.Create;
  LRows.Add(LRow);
  LRow.Add('file', 'input.wav');
  LRow.Add('sha256', AHash);
  if AExisting <> nil then
  begin
    LRow.Add('source_group', AExisting.Strings['source_group']);
    LRow.Add('clock_id', AExisting.Strings['clock_id']);
    LRow.Add('partition', AExisting.Strings['partition']);
    LRow.Add('title', AExisting.Strings['title']);
    LRow.Add('license', AExisting.Strings['license']);
    LRow.Add('provenance', AExisting.Strings['provenance']);
    LRow.Strings['file'] := AExisting.Strings['original_name'];
  end
  else
  begin
    LRow.Add('source_group', 'recording-' + AHash);
    LRow.Add('clock_id', '');
    LRow.Add('partition', 'unassigned');
    LRow.Add('title', AName);
    LRow.Add('license', 'unknown; caller-supplied private audio');
    LRow.Add('provenance', 'Operator ' + AOrigin + '; independent recording status unverified');
  end;
end;

function InspectStudioCapture(const ACatalogRoot, ACaptureId: String;
  const ACheck: TStudioEffectCheck;
  const AProgress: TWorkProgressCallback): TJSONObject;
var
  LRoot: String;
  LTemporary: String;
  LState: TJSONObject;
  LManifest: TJSONObject;
  LReport: TJSONObject;
  LStream: TFileStream;
  LWave: TWaveFrameReader;
  LHash: String;
  LSamples: TAudioSamples;
  LSample: Single;
  LSum: Double;
  LPeak: Double;
  LEnd: Int64;
  LCount: Int64;
begin
  LRoot := CaptureRoot(ACatalogRoot, ACaptureId);
  if FileExists(LRoot + PathDelim + 'analysis.json') then
  begin
    Exit(ReadStudioJSON(LRoot + PathDelim + 'analysis.json'));
  end;
  LState := ReadStudioCapture(ACatalogRoot, ACaptureId);
  LManifest := nil;
  LReport := nil;
  LStream := nil;
  LWave := nil;
  Result := nil;
  try
    Need(LState.Booleans['complete'], 'Finish uploading before analysis');
    if Assigned(ACheck) then
    begin
      ACheck;
    end;
    LStream := TFileStream.Create(LRoot + PathDelim + 'incoming' + PathDelim + 'input.wav',
      fmOpenRead or fmShareDenyWrite);
    LHash := Sha256Stream(LStream, LStream.Size, AProgress);
    LStream.Position := 0;
    LWave := TWaveFrameReader.Create(LStream);
    Need((LWave.FrameCount > 0) and (LWave.SampleRate >= 8000) and
      (LWave.SampleRate <= 192000) and (LWave.Channels in [1, 2]),
      'Explore mono or stereo WAV at 8–192 kHz');
    LEnd := Min(LWave.FrameCount, Min(Int64(LWave.SampleRate) * 30, Int64(2000000)));
    LSum := 0;
    LPeak := 0;
    LCount := 0;
    while LWave.FramePosition < LEnd do
    begin
      if Assigned(ACheck) then
      begin
        ACheck;
      end;
      ReportWork(AProgress, 'inspect_levels', wuFrames, LWave.FramePosition, LEnd);
      LSamples := LWave.ReadFrames(Integer(Min(Int64(4096), LEnd - LWave.FramePosition)));
      for LSample in LSamples do
      begin
        LSum := LSum + Sqr(LSample);
        LPeak := Math.Max(LPeak, Abs(LSample));
        Inc(LCount);
      end;
    end;
    LTemporary := LRoot + PathDelim + 'catalog';
    LManifest := Manifest(LHash, LState.Strings['name'], LState.Strings['origin'], nil);
    if not FileExists(LRoot + PathDelim + 'incoming' + PathDelim + 'manifest.json') then
    begin
      WriteStudioJSONNew(LRoot + PathDelim + 'incoming' + PathDelim + 'manifest.json', LManifest);
    end;
    ReportWork(AProgress, 'import_audio', wuItems, 0, 0);
    LReport := ImportLabelInbox(LRoot + PathDelim + 'incoming', LTemporary);
    Need(LReport.Integers['failed'] = 0, 'Temporary WAV validation failed');
    FreeAndNil(LReport);
    Result := TJSONObject.Create;
    try
      Result.Add('capture_id', ACaptureId);
      Result.Add('source_sha256', LHash);
      Result.Add('source_bytes', LStream.Size);
      Result.Add('sample_rate', LWave.SampleRate);
      Result.Add('channels', LWave.Channels);
      Result.Add('frame_count', LWave.FrameCount);
      Result.Add('start_frame', 0);
      Result.Add('end_frame', LEnd);
      Result.Add('rms', Sqrt(LSum / LCount));
      Result.Add('peak', LPeak);
      Result.Add('waveform', CatalogWaveformRegion(LTemporary, LHash, 0, LEnd, 512));
      if Assigned(ACheck) then
      begin
        ACheck;
      end;
      Result.Add('beat_proposal', PublishCatalogBeatProposals(LTemporary, LHash, 0, LEnd, AProgress));
      Result.Add('uncertainty', 'Unreviewed pulse hypotheses; no beat or note truth is admitted');
      Result.Add('midi_available', False);
      Result.Add('pitch_preview_available', True);
      Result.Add('midi_scope', 'Experimental single-pitch preview is available as a separate action');
      WriteStudioJSONNew(LRoot + PathDelim + 'analysis.json', Result);
    except
      Result.Free;
      Result := nil;
      raise;
    end;
  finally
    LWave.Free;
    LStream.Free;
    LReport.Free;
    LManifest.Free;
    LState.Free;
  end;
end;

function OpenStudioCapture(const ACatalogRoot, ACaptureId: String;
  out AHash, APath: String): TFileStream;
var
  LRoot: String;
  LAnalysis: TJSONObject;
begin
  LRoot := CaptureRoot(ACatalogRoot, ACaptureId);
  LAnalysis := ReadStudioJSON(LRoot + PathDelim + 'analysis.json');
  try
    AHash := LAnalysis.Strings['source_sha256'];
    APath := LRoot + PathDelim + 'incoming' + PathDelim + 'input.wav';
    CheckPath(APath);
    Result := TFileStream.Create(APath, fmOpenRead or fmShareDenyWrite);
    try
      Need(Result.Size = LAnalysis.Int64s['source_bytes'], 'Temporary audio size changed');
    except
      Result.Free;
      raise;
    end;
  finally
    LAnalysis.Free;
  end;
end;

function SaveStudioCapture(const ACatalogRoot, AJobId, ALibraryRoot: String;
  const AWrite: TJSONObject; const ACheck: TStudioEffectCheck;
  const AProgress: TWorkProgressCallback): TJSONObject;
var
  LInput: TFileStream;
  LOutput: TFileStream;
  LManifest: TJSONObject;
  LReport: TJSONObject;
  LHash: String;
  LPath: String;
  LStage: String;
  LCollection: String;
  LFinal: String;
  LBuffer: array[0..65535] of Byte;
  LCount: Integer;
  LExists: Boolean;
begin
  ValidateStudioCollectionName(AWrite.Get('collection_name', ''));
  Need((Length(Trim(AWrite.Get('title', ''))) > 0) and
    (Length(AWrite.Get('title', '')) <= 128), 'Clip title must contain one to 128 bytes');
  LInput := nil;
  LOutput := nil;
  LManifest := nil;
  LReport := nil;
  Result := nil;
  try
    if Assigned(ACheck) then
    begin
      ACheck;
    end;
    LInput := OpenStudioCapture(ACatalogRoot, AWrite.Strings['capture_id'], LHash, LPath);
    Need(Sha256Stream(LInput, LInput.Size, AProgress) = LHash, 'Temporary audio content changed');
    LExists := FileExists(IncludeTrailingPathDelimiter(ACatalogRoot) + 'tracks' + PathDelim + LHash + '.json');
    if not LExists then
    begin
      LStage := ReserveStudioJobStage(ACatalogRoot, ALibraryRoot, AJobId, 'capture-save');
      Need(ForceDirectories(LStage), 'Could not prepare audio save');
      LOutput := TFileStream.Create(LStage + PathDelim + 'input.wav', fmCreate or fmShareExclusive);
      LInput.Position := 0;
      repeat
        if Assigned(ACheck) then
        begin
          ACheck;
        end;
        LCount := LInput.Read(LBuffer, SizeOf(LBuffer));
        if LCount > 0 then
        begin
          LOutput.WriteBuffer(LBuffer, LCount);
          ReportWork(AProgress, 'copy_audio', wuBytes, LOutput.Size, LInput.Size);
        end;
      until LCount = 0;
      Need(LOutput.Size = LInput.Size, 'Short capture save');
      FreeAndNil(LOutput);
      LReport := ReadStudioCapture(ACatalogRoot, AWrite.Strings['capture_id']);
      LManifest := Manifest(LHash, AWrite.Strings['title'], LReport.Strings['origin'], nil);
      FreeAndNil(LReport);
      WriteStudioJSONNew(LStage + PathDelim + 'manifest.json', LManifest);
      ReportWork(AProgress, 'import_audio', wuItems, 0, 0);
      LReport := ImportLabelInbox(LStage, ACatalogRoot);
      Need(LReport.Integers['failed'] = 0, 'Verified capture could not join catalog');
      FreeAndNil(LReport);
    end;
    LCollection := IncludeTrailingPathDelimiter(ExpandFileName(ALibraryRoot)) +
      'collections' + PathDelim + AWrite.Strings['collection_name'];
    CheckPath(LCollection);
    Need(ForceDirectories(LCollection), 'Could not create chosen collection');
    LFinal := LCollection + PathDelim + LHash + '.wav';
    CheckPath(LFinal);
    if not FileExists(LFinal) then
    begin
      LOutput := TFileStream.Create(LFinal + '.partial', fmCreate or fmShareExclusive);
      LInput.Position := 0;
      repeat
        if Assigned(ACheck) then
        begin
          ACheck;
        end;
        LCount := LInput.Read(LBuffer, SizeOf(LBuffer));
        if LCount > 0 then
        begin
          LOutput.WriteBuffer(LBuffer, LCount);
          ReportWork(AProgress, 'copy_audio', wuBytes, LOutput.Size, LInput.Size);
        end;
      until LCount = 0;
      Need((LOutput.Size = LInput.Size) and FileFlush(LOutput.Handle), 'Could not finish collection audio');
      FreeAndNil(LOutput);
      LOutput := TFileStream.Create(LFinal + '.partial', fmOpenRead or fmShareDenyWrite);
      Need(Sha256Stream(LOutput, LOutput.Size, AProgress) = LHash, 'Collection copy hash differs');
      FreeAndNil(LOutput);
      Need(RenameFile(LFinal + '.partial', LFinal), 'Could not publish collection audio');
    end
    else
    begin
      LOutput := TFileStream.Create(LFinal, fmOpenRead or fmShareDenyWrite);
      Need(Sha256Stream(LOutput, LOutput.Size, AProgress) = LHash, 'Existing collection audio differs');
      FreeAndNil(LOutput);
    end;
    FreeAndNil(LInput);
    LReport := RefreshStudioLibrary(ACatalogRoot, ALibraryRoot,
      ReserveStudioJobStage(ACatalogRoot, ALibraryRoot, AJobId, 'capture-refresh'));
    Result := TJSONObject.Create;
    Result.Add('source_sha256', LHash);
    Result.Add('capture_id', AWrite.Strings['capture_id']);
    Result.Add('collection_name', AWrite.Strings['collection_name']);
    Result.Add('title', AWrite.Strings['title']);
    Result.Add('already_catalogued', LExists);
    Result.Add('library_revision', LReport.Integers['revision']);
  finally
    LReport.Free;
    LManifest.Free;
    LOutput.Free;
    LInput.Free;
  end;
end;

procedure RemoveTemporaryTree(const APath: String; const ADepth: Integer);
var
  LSearch: TSearchRec;
  LChild: String;
begin
  Need(ADepth <= 12, 'Unexpected temporary audio directory depth');
  CheckPath(APath);
  if FindFirst(APath + PathDelim + '*', faAnyFile, LSearch) = 0 then
  begin
    try
      repeat
        if (LSearch.Name = '.') or (LSearch.Name = '..') then
        begin
          Continue;
        end;
        LChild := APath + PathDelim + LSearch.Name;
        CheckPath(LChild);
        if (LSearch.Attr and faDirectory) <> 0 then
        begin
          RemoveTemporaryTree(LChild, ADepth + 1);
        end
        else
        begin
          Need(SysUtils.DeleteFile(LChild), 'Temporary audio is still in use; stop playback and retry discard');
        end;
      until FindNext(LSearch) <> 0;
    finally
      SysUtils.FindClose(LSearch);
    end;
  end;
  Need(RemoveDir(APath), 'Could not remove temporary audio folder');
end;

function DiscardStudioCapture(const ACatalogRoot, ACaptureId: String): TJSONObject;
var
  LRoot: String;
  LJobs: TJSONObject;
  LRequest: TJSONObject;
  LJob: TJSONObject;
  LIndex: Integer;
begin
  LRoot := CaptureRoot(ACatalogRoot, ACaptureId);
  LJobs := ListStudioJobs(ACatalogRoot);
  try
    for LIndex := 0 to LJobs.Arrays['jobs'].Count - 1 do
    begin
      LJob := LJobs.Arrays['jobs'].Objects[LIndex];
      if (LJob.Strings['status'] = 'queued') or (LJob.Strings['status'] = 'running') then
      begin
        LRequest := ReadStudioJobRequest(ACatalogRoot, LJob.Strings['job_id']);
        try
          Need(LRequest.Get('capture_id', '') <> ACaptureId, 'Cancel the active audio job before discard');
        finally
          LRequest.Free;
        end;
      end;
    end;
  finally
    LJobs.Free;
  end;
  if DirectoryExists(LRoot) then
  begin
    RemoveTemporaryTree(LRoot, 0);
  end;
  Result := TJSONObject.Create;
  Result.Add('capture_id', ACaptureId);
  Result.Add('discarded', True);
end;

function ListStudioCaptures(const ACatalogRoot: String): TJSONObject;
var
  LRoot: String;
  LSearch: TSearchRec;
  LRows: TJSONArray;
  LRow: TJSONObject;
begin
  LRoot := ExtractFileDir(CaptureRoot(ACatalogRoot, 'list'));
  Result := TJSONObject.Create;
  LRows := TJSONArray.Create;
  Result.Add('captures', LRows);
  try
    if FindFirst(LRoot + PathDelim + '*', faDirectory, LSearch) = 0 then
    begin
      try
        repeat
          if ((LSearch.Attr and faDirectory) <> 0) and
            (LSearch.Name <> '.') and (LSearch.Name <> '..') then
          begin
            Need(LRows.Count < 8, 'Temporary input count exceeds bound');
            CaptureRoot(ACatalogRoot, LSearch.Name);
            try
              LRow := ReadStudioCapture(ACatalogRoot, LSearch.Name);
            except
              LRow := TJSONObject.Create;
              LRow.Add('capture_id', LSearch.Name);
              LRow.Add('name', 'Interrupted import — discard and try again');
              LRow.Add('bytes', 0);
              LRow.Add('received_bytes', 0);
              LRow.Add('complete', False);
              LRow.Add('inspected', False);
              LRow.Add('interrupted', True);
            end;
            LRows.Add(LRow);
          end;
        until FindNext(LSearch) <> 0;
      finally
        SysUtils.FindClose(LSearch);
      end;
    end;
  except
    Result.Free;
    raise;
  end;
end;

end.
