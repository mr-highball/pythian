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
unit pythian.tools.studio.effects;

{$mode delphi}
{$H+}

interface

uses Classes, fpjson;

type
  TStudioEffectCheck = procedure of object;

{ Borrowed request; owned result. Source/preview hashes are verified in worker
  execution. Explicit bounded tail frames, reset DSP state, stereo PCM16 output; no hidden
  normalization or limiter. Over-range samples are counted before PCM clipping. }
procedure ValidateStudioEffectRequest(const ARequest: TJSONObject);
procedure ValidateStudioCollectionName(const AName: String);
function RenderStudioEffectPreview(const ACatalogRoot, AJobId: String;
  const ARequest: TJSONObject; const ACheck: TStudioEffectCheck = nil): TJSONObject;
function SaveStudioEffectPreview(const ACatalogRoot, AJobId, ALibraryRoot: String;
  const ARequest: TJSONObject; const ACheck: TStudioEffectCheck = nil): TJSONObject;
function OpenStudioEffectPreview(const ACatalogRoot, AJobId: String;
  out AHash: String): TFileStream;

implementation

uses
  SysUtils, Math,
  pythian.audio, pythian.hash, pythian.effects,
  pythian.effects.catalog, pythian.effects.rack,
  pythian.wave.read, pythian.wave.stream,
  pythian.tools.annotations.catalog, pythian.tools.annotations.sourceguard,
  pythian.tools.studio.projects, pythian.tools.studio.jobs,
  pythian.tools.studio.&library
  {$IFDEF MSWINDOWS}, Windows{$ENDIF};

procedure Need(const ACondition: Boolean; const AMessage: String);
begin
  if not ACondition then
  begin
    raise EAudio.Create(AMessage);
  end;
end;

function Number(const AObject: TJSONObject; const AKey: String;
  const AMinimum, AMaximum: Double): Double;
var
  LData: TJSONData;
begin
  LData := AObject.Find(AKey);
  Need((LData <> nil) and (LData.JSONType = jtNumber), 'Effect setting requires a number: ' + AKey);
  Result := LData.AsFloat;
  RequireFinite(Result, AKey);
  Need((Result >= AMinimum) and (Result <= AMaximum), 'Effect setting is outside its bound: ' + AKey);
end;

procedure CheckKeys(const AObject: TJSONObject; const AKeys: String);
var
  LIndex: Integer;
begin
  for LIndex := 0 to AObject.Count - 1 do
  begin
    Need(Pos('|' + AObject.Names[LIndex] + '|', AKeys) > 0, 'Unsupported effect setting');
  end;
end;

function SafeName(const AName: String): Boolean;
var
  LCharacter: Char;
  LBase: String;
begin
  Result := (Length(Trim(AName)) >= 1) and (Length(AName) <= 96) and
    (AName = Trim(AName)) and (AName <> '.') and (AName <> '..');
  for LCharacter in AName do
  begin
    Result := Result and not (LCharacter in [#0..#31, '/', '\', ':', '*', '?', '"', '<', '>', '|']);
  end;
  if AName <> '' then
  begin
    Result := Result and (AName[Length(AName)] <> '.');
  end;
  LBase := UpperCase(ChangeFileExt(AName, ''));
  Result := Result and (LBase <> 'CON') and (LBase <> 'PRN') and (LBase <> 'AUX') and
    (LBase <> 'NUL') and not ((Length(LBase) = 4) and
    ((Copy(LBase, 1, 3) = 'COM') or (Copy(LBase, 1, 3) = 'LPT')) and (LBase[4] in ['1'..'9']));
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
      Need((LAttributes and FILE_ATTRIBUTE_REPARSE_POINT) = 0, 'Linked effects paths are unsupported');
      {$ELSE}
      Need((LAttributes and faSymLink) = 0, 'Linked effects paths are unsupported');
      {$ENDIF}
    end;
    LPath := ExcludeTrailingPathDelimiter(ExtractFileDir(LPath));
  end;
end;

procedure ValidateStudioCollectionName(const AName: String);
begin
  Need(SafeName(AName), 'Choose a plain collection name without path separators');
end;


procedure ValidateStudioEffectRequest(const ARequest: TJSONObject);
var
  LEffects: TJSONArray;
  LRow: TJSONObject;
  LIndex: Integer;
  LKind: String;
  LDefinition: TEffectDefinition;
  LSetting: TEffectParameter;
  LParameter: Integer;
  LKeys: String;
  LStart: Double;
  LEnd: Double;
begin
  Need(ARequest <> nil, 'Effect request is required');
  if ARequest.Get('kind', '') = 'effect_save' then
  begin
    Need((Length(ARequest.Get('preview_job_id', '')) >= 1) and
      SafeName(ARequest.Get('collection_name', '')),
      'Choose a completed preview and a collection name');
    Need((Length(ARequest.Get('title', '')) >= 1) and
      (Length(ARequest.Get('title', '')) <= 128), 'Clip title must contain one to 128 bytes');
    Exit;
  end;
  Need(ARequest.Get('kind', '') = 'effect_preview', 'Unsupported effect operation');
  Need(Length(ARequest.Get('source_sha256', '')) = 64, 'Effect source identity is invalid');
  LStart := Number(ARequest, 'start_frame', 0, 9007199254740991);
  LEnd := Number(ARequest, 'end_frame', 1, 9007199254740991);
  Need((Frac(LStart) = 0) and (Frac(LEnd) = 0) and (LEnd > LStart),
    'Effect preview requires an exact original source range');
  if ARequest.Find('tail_seconds') <> nil then
  begin
    Number(ARequest, 'tail_seconds', 0, 10);
  end;
  Need((ARequest.Find('effects') <> nil) and (ARequest.Find('effects').JSONType = jtArray),
    'Effect stack must be an array');
  LEffects := ARequest.Arrays['effects'];
  Need(LEffects.Count <= 8, 'Use at most eight effect stages');
  for LIndex := 0 to LEffects.Count - 1 do
  begin
    Need(LEffects[LIndex].JSONType = jtObject, 'Effect stage must be an object');
    LRow := LEffects.Objects[LIndex];
    LKind := LRow.Get('kind', '');
    Need((LRow.Find('bypass') <> nil) and (LRow.Find('bypass').JSONType = jtBoolean),
      'Each effect stage must declare bypass');
    Need(FindEffectDefinition(LKind, LDefinition), 'Unsupported effect kind');
    LKeys := '|kind|bypass|';
    for LParameter := 0 to High(LDefinition.Parameters) do
    begin
      LSetting := LDefinition.Parameters[LParameter];
      LKeys := LKeys + LSetting.Key + '|';
      Number(LRow, LSetting.Key, LSetting.Minimum, LSetting.Maximum);
    end;
    CheckKeys(LRow, LKeys);
  end;
end;

function CreateChain(const AEffects: TJSONArray; const ARate: Integer): TEffectChain;
var
  LIndex: Integer;
  LRow: TJSONObject;
  LEffect: TAudioEffect;
  LDefinition: TEffectDefinition;
  LSettings: TCatalogEffectSettings;
  LSetting: TEffectParameter;
  LParameter: Integer;
begin
  Result := TEffectChain.Create(ARate);
  try
    for LIndex := 0 to AEffects.Count - 1 do
    begin
      LRow := AEffects.Objects[LIndex];
      Need(FindEffectDefinition(LRow.Strings['kind'], LDefinition), 'Unsupported effect kind');
      LSettings := DefaultCatalogEffect(LDefinition.Kind);
      for LParameter := 0 to High(LDefinition.Parameters) do
      begin
        { Big Boss: a bypassed recipe must remain valid when enabled. }
        LSetting := LDefinition.Parameters[LParameter];
        LSettings.Values[LParameter] := Number(LRow, LSetting.Key, LSetting.Minimum,
          EffectParameterMaximum(LSetting, ARate));
      end;
      ValidateCatalogEffect(LSettings, ARate);
      if LRow.Booleans['bypass'] then
      begin
        Continue;
      end;
      LEffect := CreateCatalogEffect(ARate, LSettings);
      try
        Result.Add(LEffect);
        LEffect := nil;
      finally
        LEffect.Free;
      end;
    end;
  except
    Result.Free;
    raise;
  end;
end;

function RenderStudioEffectPreview(const ACatalogRoot, AJobId: String;
  const ARequest: TJSONObject; const ACheck: TStudioEffectCheck): TJSONObject;
var
  LInput: TFileStream;
  LOutput: TFileStream;
  LReader: TWaveFrameReader;
  LSink: TStreamAudioSink;
  LWriter: TWavePcm16Writer;
  LChain: TEffectChain;
  LTrack: TJSONObject;
  LRecipe: TJSONObject;
  LSamples: TAudioSamples;
  LRendered: TAudioSamples;
  LStart: Int64;
  LFrames: Int64;
  LTailFrames: Int64;
  LInputRemaining: Int64;
  LRemaining: Int64;
  LClipped: Int64;
  LCount: Integer;
  LIndex: Integer;
  LLeft: Double;
  LRight: Double;
  LProcessedLeft: Double;
  LProcessedRight: Double;
  LPeak: Double;
  LPath: String;
  LHash: String;
  LBytes: Int64;
begin
  ValidateStudioEffectRequest(ARequest);
  LInput := nil;
  LOutput := nil;
  LReader := nil;
  LSink := nil;
  LWriter := nil;
  LChain := nil;
  LTrack := nil;
  LRecipe := nil;
  Result := nil;
  LPath := StudioJobDirectory(ACatalogRoot, AJobId) + PathDelim + 'effect.wav';
  Need(not FileExists(LPath), 'Effect preview already exists; reconcile its job instead of replacing it');
  try
    if Assigned(ACheck) then ACheck;
    LInput := OpenStudioSourceAudio(ACatalogRoot, ARequest.Strings['source_sha256']);
    Need(Sha256Stream(LInput, LInput.Size) = ARequest.Strings['source_sha256'],
      'Effect source hash changed');
    if Assigned(ACheck) then ACheck;
    LInput.Position := 0;
    LReader := TWaveFrameReader.Create(LInput);
    Need((LReader.SampleRate >= 8000) and (LReader.SampleRate <= 192000) and
      (LReader.Channels in [1, 2]), 'Effects support mono/stereo WAV at 8–192 kHz');
    LStart := ARequest.Int64s['start_frame'];
    LFrames := ARequest.Int64s['end_frame'] - LStart;
    LTailFrames := Round(ARequest.Get('tail_seconds', 0.0) * LReader.SampleRate);
    Need((LStart >= 0) and (LFrames > 0) and
      (ARequest.Int64s['end_frame'] <= LReader.FrameCount) and
      (LFrames <= Int64(LReader.SampleRate) * 30), 'Effects preview is limited to a 30-second source passage');
    LChain := CreateChain(ARequest.Arrays['effects'], LReader.SampleRate);
    Need((LFrames + LTailFrames) * LChain.FrameCost <= MaximumEffectVisits,
      'Effect stack and tail exceed render work bound; shorten the passage or tail');
    LTrack := ReadCatalogTrack(ACatalogRoot, ARequest.Strings['source_sha256']);
    LRecipe := TJSONObject.Create;
    LRecipe.Add('format', 'pythian.studio.effect.recipe.v1');
    LRecipe.Add('source_sha256', ARequest.Strings['source_sha256']);
    LRecipe.Add('source_group', LTrack.Strings['source_group']);
    LRecipe.Add('partition', LTrack.Strings['partition']);
    LRecipe.Add('start_frame', LStart);
    LRecipe.Add('end_frame', LStart + LFrames);
    LRecipe.Add('effects', ARequest.Arrays['effects'].Clone);
    LRecipe.Add('sample_rate', LReader.SampleRate);
    LRecipe.Add('channels', 2);
    LRecipe.Add('tail_frames', LTailFrames);
    LRecipe.Add('tail_policy', 'explicit_zero_input_then_cut');
    LRecipe.Add('initial_state', 'reset');
    LRecipe.Add('encoding', 'pcm16');
    LRecipe.Add('compressor_knee_db', 6);
    LRecipe.Add('policy', 'studio_effects_v1;explicit_order_and_bypass;no_hidden_limiter');
    LOutput := TFileStream.Create(LPath + '.partial', fmCreate or fmShareExclusive);
    LSink := TStreamAudioSink.Create(LOutput);
    LWriter := TWavePcm16Writer.Create(LSink, LReader.SampleRate, 2, LFrames + LTailFrames);
    LReader.SeekFrame(LStart);
    LRemaining := LFrames + LTailFrames;
    LInputRemaining := LFrames;
    LClipped := 0;
    LPeak := 0;
    while LRemaining > 0 do
    begin
      if Assigned(ACheck) then ACheck;
      LCount := 2048;
      if LRemaining < LCount then LCount := LRemaining;
      if LInputRemaining > 0 then
      begin
        LCount := Min(LCount, LInputRemaining);
        LSamples := LReader.ReadFrames(LCount);
        Need(Length(LSamples) = LCount * LReader.Channels, 'Short effects source read');
      end
      else
      begin
        LSamples := nil;
      end;
      SetLength(LRendered, LCount * 2);
      for LIndex := 0 to LCount - 1 do
      begin
        LLeft := 0;
        LRight := 0;
        if LInputRemaining > 0 then
        begin
          LLeft := LSamples[LIndex * LReader.Channels];
          LRight := LLeft;
          if LReader.Channels = 2 then
          begin
            LRight := LSamples[LIndex * 2 + 1];
          end;
        end;
        LChain.Process(LLeft, LRight, LProcessedLeft, LProcessedRight);
        LLeft := LProcessedLeft;
        LRight := LProcessedRight;
        LPeak := Math.Max(LPeak, Math.Max(Abs(LLeft), Abs(LRight)));
        if Abs(LLeft) > 1 then Inc(LClipped);
        if Abs(LRight) > 1 then Inc(LClipped);
        LRendered[LIndex * 2] := Math.Max(-1.0, Math.Min(1.0, LLeft));
        LRendered[LIndex * 2 + 1] := Math.Max(-1.0, Math.Min(1.0, LRight));
      end;
      LWriter.AppendSamples(LRendered);
      Dec(LRemaining, LCount);
      LInputRemaining := Max(Int64(0), LInputRemaining - LCount);
    end;
    LWriter.Finish;
    Need(FileFlush(LOutput.Handle), 'Could not flush effect preview');
    FreeAndNil(LWriter);
    FreeAndNil(LSink);
    FreeAndNil(LOutput);
    if Assigned(ACheck) then ACheck;
    LOutput := TFileStream.Create(LPath + '.partial', fmOpenRead or fmShareDenyWrite);
    LBytes := LOutput.Size;
    LHash := Sha256Stream(LOutput, LBytes);
    FreeAndNil(LOutput);
    Need(RenameFile(LPath + '.partial', LPath), 'Could not publish effect preview');
    Result := TJSONObject.Create;
    Result.Add('source_sha256', ARequest.Strings['source_sha256']);
    Result.Add('output_sha256', LHash);
    Result.Add('output_bytes', LBytes);
    Result.Add('artifact', 'effect.wav');
    Result.Add('sample_rate', LReader.SampleRate);
    Result.Add('channels', 2);
    Result.Add('frame_count', LFrames + LTailFrames);
    Result.Add('peak_before_encoding', LPeak);
    Result.Add('clipped_samples', LClipped);
    Result.Add('recipe_sha256', StudioTextHash(LRecipe.AsJSON));
    Result.Add('recipe', LRecipe.Clone);
  finally
    LWriter.Free;
    LSink.Free;
    LOutput.Free;
    LChain.Free;
    LReader.Free;
    LInput.Free;
    LTrack.Free;
    LRecipe.Free;
  end;
end;

function OpenStudioEffectPreview(const ACatalogRoot, AJobId: String;
  out AHash: String): TFileStream;
var
  LJob: TJSONObject;
  LResult: TJSONObject;
  LPath: String;
begin
  LJob := ReadStudioJob(ACatalogRoot, AJobId);
  try
    Need((LJob.Strings['status'] = 'completed') and
      (LJob.Strings['kind'] = 'effect_preview'), 'Select a completed effects preview');
    LResult := LJob.Objects['results'];
    Need(LResult.Strings['artifact'] = 'effect.wav', 'Effect preview artifact differs');
    LPath := StudioJobDirectory(ACatalogRoot, AJobId) + PathDelim + 'effect.wav';
    CheckPath(LPath);
    AHash := LResult.Strings['output_sha256'];
    VerifyGuardedSource(LPath, AHash, LResult.Int64s['output_bytes']);
    Result := TFileStream.Create(LPath, fmOpenRead or fmShareDenyWrite);
  finally
    LJob.Free;
  end;
end;

function SaveStudioEffectPreview(const ACatalogRoot, AJobId, ALibraryRoot: String;
  const ARequest: TJSONObject; const ACheck: TStudioEffectCheck): TJSONObject;
var
  LPreview: TJSONObject;
  LPreviewResult: TJSONObject;
  LRecipe: TJSONObject;
  LTrack: TJSONObject;
  LExisting: TJSONObject;
  LManifest: TJSONObject;
  LEntry: TJSONObject;
  LReport: TJSONObject;
  LRows: TJSONArray;
  LInput: TFileStream;
  LOutput: TFileStream;
  LHash: String;
  LName: String;
  LStage: String;
  LCollection: String;
  LFinal: String;
  LRecipePath: String;
  LBytes: Int64;
  LBuffer: array[0..65535] of Byte;
  LRead: Integer;
begin
  ValidateStudioEffectRequest(ARequest);
  Result := nil;
  LPreview := nil;
  LTrack := nil;
  LExisting := nil;
  LManifest := nil;
  LInput := nil;
  LOutput := nil;
  LReport := nil;
  { Stages are disposable generated artifacts; durable audio is in the library.
    The maintained service is launched from its workspace root. }
  LStage := ReserveStudioJobStage(ACatalogRoot, ALibraryRoot, AJobId, 'effects');
  CheckPath(LStage);
  Need(not DirectoryExists(LStage), 'Effects save stage exists; use an explicit retry job');
  try
    if Assigned(ACheck) then
    begin
      ACheck;
    end;
    LInput := OpenStudioEffectPreview(ACatalogRoot, ARequest.Strings['preview_job_id'], LHash);
    LBytes := LInput.Size;
    LPreview := ReadStudioJob(ACatalogRoot, ARequest.Strings['preview_job_id']);
    LPreviewResult := LPreview.Objects['results'];
    LRecipe := LPreviewResult.Objects['recipe'];
    Need(StudioTextHash(LRecipe.AsJSON) = LPreviewResult.Strings['recipe_sha256'],
      'Effects recipe identity differs');
    LTrack := ReadCatalogTrack(ACatalogRoot, LRecipe.Strings['source_sha256']);
    Need((LTrack.Strings['source_group'] = LRecipe.Strings['source_group']) and
      (LTrack.Strings['partition'] = LRecipe.Strings['partition']) and
      (LTrack.Strings['partition'] <> 'evaluation'), 'Source family or use restrictions changed');
    LName := LHash + '.wav';
    if FileExists(IncludeTrailingPathDelimiter(ACatalogRoot) + 'tracks' + PathDelim + LHash + '.json') then
    begin
      LExisting := ReadCatalogTrack(ACatalogRoot, LHash);
      Need((LExisting.Strings['source_group'] = LTrack.Strings['source_group']) and
        (LExisting.Strings['partition'] = LTrack.Strings['partition']),
        'Identical audio already belongs to another source family; no new independent clip was created');
      LName := LExisting.Strings['original_name'];
      Need(SafeName(LName), 'Existing catalog filename cannot be staged safely');
    end;
    Need(ForceDirectories(LStage), 'Could not create effects save stage');
    LOutput := TFileStream.Create(IncludeTrailingPathDelimiter(LStage) + LName, fmCreate or fmShareExclusive);
    repeat
      if Assigned(ACheck) then
      begin
        ACheck;
      end;
      LRead := LInput.Read(LBuffer, SizeOf(LBuffer));
      if LRead > 0 then
      begin
        LOutput.WriteBuffer(LBuffer, LRead);
      end;
    until LRead = 0;
    Need(LOutput.Size = LBytes, 'Short effect preview copy');
    FreeAndNil(LOutput);
    FreeAndNil(LInput);
    LManifest := TJSONObject.Create;
    LManifest.Add('version', 1);
    LRows := TJSONArray.Create;
    LManifest.Add('tracks', LRows);
    LEntry := TJSONObject.Create;
    LRows.Add(LEntry);
    LEntry.Add('file', LName);
    LEntry.Add('sha256', LHash);
    if LExisting <> nil then
    begin
      LEntry.Add('source_group', LExisting.Strings['source_group']);
      LEntry.Add('clock_id', LExisting.Strings['clock_id']);
      LEntry.Add('partition', LExisting.Strings['partition']);
      LEntry.Add('title', LExisting.Strings['title']);
      LEntry.Add('provenance', LExisting.Strings['provenance']);
      LEntry.Add('license', LExisting.Strings['license']);
    end
    else
    begin
      LEntry.Add('source_group', LTrack.Strings['source_group']);
      LEntry.Add('clock_id', '');
      LEntry.Add('partition', LTrack.Strings['partition']);
      LEntry.Add('title', ARequest.Strings['title']);
      LEntry.Add('provenance', 'Pythian effect-derived clip; parent ' + LRecipe.Strings['source_sha256'] +
        '; recipe ' + LPreviewResult.Strings['recipe_sha256'] + '; not an independent recording');
      LEntry.Add('license', LTrack.Strings['license']);
    end;
    WriteStudioJSONNew(IncludeTrailingPathDelimiter(LStage) + 'manifest.json', LManifest);
    LRecipePath := IncludeTrailingPathDelimiter(ACatalogRoot) + 'studio' + PathDelim +
      'effect-recipes' + PathDelim + LPreviewResult.Strings['recipe_sha256'] + '.json';
    CheckPath(LRecipePath);
    Need(ForceDirectories(ExtractFileDir(LRecipePath)), 'Could not create recipe history');
    if FileExists(LRecipePath) then
    begin
      LReport := ReadStudioJSON(LRecipePath);
      Need(LReport.AsJSON = LRecipe.AsJSON, 'Stored effects recipe differs');
      FreeAndNil(LReport);
    end
    else
    begin
      WriteStudioJSONNew(LRecipePath, LRecipe);
    end;
    if Assigned(ACheck) then
    begin
      ACheck;
    end;
    LReport := ImportLabelInbox(LStage, ACatalogRoot);
    Need(LReport.Integers['failed'] = 0, 'Effect source import failed; verified preview remains available');
    FreeAndNil(LReport);
    LCollection := IncludeTrailingPathDelimiter(ExpandFileName(ALibraryRoot)) +
      'collections' + PathDelim + ARequest.Strings['collection_name'];
    CheckPath(LCollection);
    Need(ForceDirectories(LCollection), 'Could not create chosen collection');
    LFinal := IncludeTrailingPathDelimiter(LCollection) + LHash + '.wav';
    CheckPath(LFinal);
    if FileExists(LFinal) then
    begin
      VerifyGuardedSource(LFinal, LHash, LBytes);
    end
    else
    begin
      LInput := OpenStudioEffectPreview(ACatalogRoot, ARequest.Strings['preview_job_id'], LHash);
      LOutput := TFileStream.Create(LFinal + '.partial', fmCreate or fmShareExclusive);
      repeat
        if Assigned(ACheck) then
        begin
          ACheck;
        end;
        LRead := LInput.Read(LBuffer, SizeOf(LBuffer));
        if LRead > 0 then
        begin
          LOutput.WriteBuffer(LBuffer, LRead);
        end;
      until LRead = 0;
      Need(LOutput.Size = LBytes, 'Short derived collection copy');
      Need(FileFlush(LOutput.Handle), 'Could not flush derived collection clip');
      FreeAndNil(LOutput);
      FreeAndNil(LInput);
      LInput := TFileStream.Create(LFinal + '.partial', fmOpenRead or fmShareDenyWrite);
      Need((LInput.Size = LBytes) and (Sha256Stream(LInput, LInput.Size) = LHash),
        'Derived collection copy differs from its verified preview');
      FreeAndNil(LInput);
      Need(RenameFile(LFinal + '.partial', LFinal), 'Could not publish derived collection clip');
    end;
    if Assigned(ACheck) then
    begin
      ACheck;
    end;
    LReport := RefreshStudioLibrary(ACatalogRoot, ALibraryRoot,
      ReserveStudioJobStage(ACatalogRoot, ALibraryRoot, AJobId, 'effects-refresh'));
    Result := TJSONObject.Create;
    Result.Add('source_sha256', LHash);
    Result.Add('parent_source_sha256', LRecipe.Strings['source_sha256']);
    Result.Add('source_group', LTrack.Strings['source_group']);
    Result.Add('partition', LTrack.Strings['partition']);
    Result.Add('collection_name', ARequest.Strings['collection_name']);
    Result.Add('title', ARequest.Strings['title']);
    Result.Add('preview_job_id', ARequest.Strings['preview_job_id']);
    Result.Add('recipe_sha256', LPreviewResult.Strings['recipe_sha256']);
    Result.Add('already_catalogued', LExisting <> nil);
    Result.Add('independent_recording', False);
    Result.Add('library_revision', LReport.Integers['revision']);
  finally
    LReport.Free;
    LOutput.Free;
    LInput.Free;
    LManifest.Free;
    LExisting.Free;
    LTrack.Free;
    LPreview.Free;
  end;
end;

end.
