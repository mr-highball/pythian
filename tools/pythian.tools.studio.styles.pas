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
unit pythian.tools.studio.styles;

{$mode delphi}{$H+}

interface

uses fpjson, pythian.audio, pythian.progress;

const
  { Native storage envelope, independent of the semantic decoder's own tighter
    versioned limits. Catalog listing/admission must remain WFC-free. }
  MaximumStudioStyleBytes = 64 * 1024 * 1024;

{ Private immutable model artifacts and named references. Listing reads only
  bounded metadata. Saving a name never learns, generates or copies source PCM. }
procedure RetainStudioStyleBytes(const ACatalogRoot, ASha256: String;
  const ABytes: TAudioBytes; const AProgress: TWorkProgressCallback = nil);
function ReadStudioStyleBytes(const ACatalogRoot, ASha256: String;
  const AProgress: TWorkProgressCallback = nil): TAudioBytes;
function ReadStudioNamedStyle(const ACatalogRoot, AId: String): TJSONObject;
function ListStudioStyles(const ACatalogRoot: String): TJSONObject;
function SaveStudioStyle(const ACatalogRoot: String; const AWrite: TJSONObject): TJSONObject;

implementation

uses Classes, SysUtils, pythian.text, pythian.hash,
  pythian.tools.json, pythian.tools.path,
  pythian.tools.studio.jobs, pythian.tools.listen.assets,
  pythian.tools.studio.instrumental.config;

const
  CFormat = 'pythian.studio.style.v1';
  CMaximumStyles = 128;

procedure Need(const ACondition: Boolean; const AMessage: String);
begin
  if not ACondition then raise EAudio.Create(AMessage);
end;

function IsDigest(const AValue: String): Boolean;
var I: Integer;
begin
  Result := Length(AValue) = 64;
  if not Result then Exit;
  for I := 1 to Length(AValue) do
    if not (AValue[I] in ['0'..'9', 'a'..'f']) then Exit(False);
end;

function ArtifactPath(const ACatalogRoot, ASha256: String): String;
begin
  Need(IsDigest(ASha256), 'Invalid saved style identity');
  Result := ListeningAssetDirectory(ACatalogRoot) + PathDelim + 'styles' +
    PathDelim + ASha256 + '.pysg';
end;

function StyleRoot(const ACatalogRoot: String): String;
begin
  Result := IncludeTrailingPathDelimiter(ExpandFileName(ACatalogRoot)) +
    'studio' + PathDelim + 'styles' + PathDelim;
end;

function NameIdentity(const AName: TScalarText; const ASha256: String): String;
var LBinding: TJSONObject;
begin
  LBinding := TJSONObject.Create(['format', CFormat, 'name', NativeJSONText(AName),
    'sha256', ASha256]);
  try Result := 'style-' + HashNativeText(WriteNativeJSON(LBinding, 1024));
  finally LBinding.Free end;
end;

function ReadStudioStyleBytes(const ACatalogRoot, ASha256: String;
  const AProgress: TWorkProgressCallback): TAudioBytes;
var
  LFile: TFileStream;
  LAt, LTake: Integer;
begin
  Result := nil;
  LFile := OpenStudioReadStream(ArtifactPath(ACatalogRoot, ASha256));
  try
    Need((LFile.Size > 0) and (LFile.Size <= MaximumStudioStyleBytes),
      'Saved style exceeds its supported byte limit');
    SetLength(Result, LFile.Size);
    LAt := 0;
    repeat
      ReportWork(AProgress, 'studio_style_read', wuBytes, LAt, LFile.Size);
      LTake := Length(Result) - LAt;
      if LTake > 65536 then LTake := 65536;
      LFile.ReadBuffer(Result[LAt], LTake);
      Inc(LAt, LTake);
    until LAt = Length(Result);
    Need(Sha256Bytes(Result, AProgress) = ASha256,
      'Existing style content differs from its immutable identity');
    ReportWork(AProgress, 'studio_style_read', wuBytes, LAt, LFile.Size);
  finally
    LFile.Free;
  end;
end;

procedure RetainStudioStyleBytes(const ACatalogRoot, ASha256: String;
  const ABytes: TAudioBytes; const AProgress: TWorkProgressCallback);
var LPath: String; LExisting: TAudioBytes;
begin
  LPath := ArtifactPath(ACatalogRoot, ASha256);
  Need((Length(ABytes) > 0) and (Length(ABytes) <= MaximumStudioStyleBytes) and
    (Sha256Bytes(ABytes, AProgress) = ASha256), 'Style bytes differ from their identity');
  if not FileExists(NativeFilePath(LPath)) then
  begin
    try
      WriteStudioBinaryNew(LPath, ABytes, MaximumStudioStyleBytes);
    except
      if not FileExists(NativeFilePath(LPath)) then raise;
      { A concurrent writer may have published the same immutable artifact. }
    end;
  end;
  LExisting := ReadStudioStyleBytes(ACatalogRoot, ASha256, AProgress);
  Need(Length(LExisting) = Length(ABytes), 'Existing style length differs');
end;

procedure ValidateStyleClock(const ARecord: TJSONObject);
var
  LRate: TJSONData;
  LTail: TJSONData;
begin
  LRate := ARecord.Find('sample_rate');
  LTail := ARecord.Find('tail_frames');
  Need((LRate <> nil) and (LTail <> nil) and
    (LRate.JSONType = jtNumber) and (LTail.JSONType = jtNumber),
    'Saved style needs its performed sample clock and sound tail');
  Need((LRate.AsFloat = StudioInstrumentalRate) and
    (LTail.AsFloat = LTail.AsInt64) and (LTail.AsInt64 >= 0) and
    (LTail.AsInt64 <= Int64(86400) * StudioInstrumentalRate),
    'Saved style sound clock is out of range');
end;

procedure AddPerformedClock(const ARecord, AJob: TJSONObject);
var
  LResult: TJSONObject;
  LResources: TJSONObject;
begin
  Need(AJob.Strings['status'] = 'completed', 'Saved style needs its finished source song');
  LResult := AJob.Objects['results'];
  Need((LResult.Find('style_candidate') <> nil) and
    (LResult.Find('style_candidate').JSONType = jtObject),
    'Saved style source song has no retained model receipt');
  Need((LResult.Objects['style_candidate'].Strings['sha256'] = ARecord.Strings['sha256']) and
    (LResult.Objects['style_candidate'].Strings['status'] = 'ready'),
    'Saved style clock belongs to a different model');
  Need((LResult.Find('output_resources') <> nil) and
    (LResult.Find('output_resources').JSONType = jtObject),
    'Saved style source song has no performed output clock');
  LResources := LResult.Objects['output_resources'];
  Need((LResources.Find('sample_rate') <> nil) and
    (LResources.Find('tail_frames') <> nil), 'Saved style output clock is incomplete');
  ARecord.Add('sample_rate', LResources.Find('sample_rate').Clone);
  ARecord.Add('tail_frames', LResources.Find('tail_frames').Clone);
  ValidateStyleClock(ARecord);
  Need((LResources.Int64s['frame_count'] = LResources.Int64s['music_frames'] +
      ARecord.Int64s['tail_frames']) and
    (LResources.Int64s['frame_count'] = LResult.Arrays['outputs'].Objects[0].Int64s['frame_count']) and
    (ARecord.Integers['sample_rate'] = LResult.Arrays['outputs'].Objects[0].Integers['sample_rate']),
    'Saved style clock differs from its completed output');
end;

function ReadStudioNamedStyle(const ACatalogRoot, AId: String): TJSONObject;
var
  LName: TScalarText;
  LJob: TJSONObject;
begin
  Need((Copy(AId, 1, 6) = 'style-') and IsDigest(Copy(AId, 7, 64)) and
    (Length(AId) = 70), 'Invalid named style identifier');
  Result := ReadStudioJSON(StyleRoot(ACatalogRoot) + AId + '.json');
  try
    Need((Result.Strings['format'] = CFormat) and (Result.Strings['id'] = AId) and
      IsDigest(Result.Strings['sha256']), 'Saved style reference is invalid');
    LName := Result.Strings['name'];
    ValidateScalarText(LName, 128, False);
    Need(NameIdentity(LName, Result.Strings['sha256']) = AId, 'Saved style name/identity differs');
    Need((Result.Int64s['bytes'] > 0) and
      (Result.Int64s['bytes'] <= MaximumStudioStyleBytes), 'Saved style byte count is invalid');
    if (Result.Find('sample_rate') = nil) and (Result.Find('tail_frames') = nil) then
    begin
      { Big Boss: older private references keep their bytes. Recover only proven
        clock metadata from their actual completed song, never from a model/PCM scan. }
      LJob := ReadStudioJob(ACatalogRoot, Result.Strings['source_job_id']);
      try
        AddPerformedClock(Result, LJob);
      finally
        LJob.Free;
      end;
    end;
    ValidateStyleClock(Result);
  except
    Result.Free;
    raise;
  end;
end;

function ListStudioStyles(const ACatalogRoot: String): TJSONObject;
var
  LSearch: TSearchRec;
  LRows, LErrors: TJSONArray;
  LRecord: TJSONObject;
  LId: String;
  LCount: Integer;
begin
  Result := TJSONObject.Create(['format', 'pythian.studio.styles.v1']);
  LRows := TJSONArray.Create;
  LErrors := TJSONArray.Create;
  Result.Add('styles', LRows);
  Result.Add('errors', LErrors);
  LCount := 0;
  try
    if FindFirst(NativeFilePath(StyleRoot(ACatalogRoot) + '*.json'), faAnyFile, LSearch) = 0 then
    begin
      try
        repeat
          Inc(LCount);
          Need(LCount <= CMaximumStyles, 'Saved style catalog exceeds128 entries');
          LId := ChangeFileExt(LSearch.Name, '');
          try
            Need((LSearch.Attr and faDirectory) = 0, 'Unexpected directory in saved styles');
            LRecord := ReadStudioNamedStyle(ACatalogRoot, LId);
            try
              LRows.Add(TJSONObject.Create(['id', LId, 'name', LRecord.Find('name').Clone,
                'sha256', LRecord.Strings['sha256'], 'bytes', LRecord.Int64s['bytes'],
                'provider_count', LRecord.Integers['provider_count'],
                'source_count', LRecord.Integers['source_count'],
                'source_job_id', LRecord.Strings['source_job_id'],
                'sample_rate', LRecord.Integers['sample_rate'],
                'tail_frames', LRecord.Int64s['tail_frames'],
                'preferred_duration_ms', LRecord.Int64s['preferred_duration_ms'],
                'has_form', LRecord.Booleans['has_form']]));
            finally LRecord.Free end;
          except
            on E: Exception do LErrors.Add(TJSONObject.Create(['id', LId, 'error', E.Message]));
          end;
        until FindNext(LSearch) <> 0;
      finally FindClose(LSearch) end;
    end;
  except
    Result.Free;
    raise;
  end;
end;

function SaveStudioStyle(const ACatalogRoot: String; const AWrite: TJSONObject): TJSONObject;
var
  LJob, LCandidate, LRecord, LList: TJSONObject;
  LName: TScalarText;
  LId, LPath, LHash: String;
  LBytes: TAudioBytes;
begin
  Need((AWrite <> nil) and (AWrite.Count = 3) and
    (AWrite.Strings['format'] = 'pythian.studio.style.write.v1') and
    (AWrite.Find('name') <> nil) and (AWrite.Find('name').JSONType = jtString),
    'Choose a finished track and a style name');
  LName := AWrite.Strings['name'];
  ValidateScalarText(LName, 128, False);
  LJob := ReadStudioJob(ACatalogRoot, AWrite.Strings['job_id']);
  LRecord := nil;
  try
    Need((LJob.Strings['status'] = 'completed') and
      (LJob.Objects['results'].Find('style_candidate') <> nil),
      'This track has no saved model. Generate a new track to save its style.');
    LCandidate := LJob.Objects['results'].Objects['style_candidate'];
    Need(LCandidate.Strings['status'] = 'ready', LCandidate.Get('reason', 'This style is unavailable'));
    LHash := LCandidate.Strings['sha256'];
    LBytes := ReadStudioStyleBytes(ACatalogRoot, LHash);
    Need(Length(LBytes) = LCandidate.Int64s['bytes'], 'Saved style length differs from its job');
    LId := NameIdentity(LName, LHash);
    LPath := StyleRoot(ACatalogRoot) + LId + '.json';
    if FileExists(NativeFilePath(LPath)) then Exit(ReadStudioNamedStyle(ACatalogRoot, LId));
    LList := ListStudioStyles(ACatalogRoot);
    try
      Need(LList.Arrays['styles'].Count + LList.Arrays['errors'].Count < CMaximumStyles,
        'Saved style catalog is full');
    finally LList.Free end;
    LRecord := TJSONObject.Create(['format', CFormat, 'id', LId,
      'name', NativeJSONText(LName), 'sha256', LHash, 'bytes', Length(LBytes),
      'source_job_id', LJob.Strings['job_id'],
      'provider_count', LCandidate.Integers['provider_count'],
      'source_count', LCandidate.Integers['source_count'],
      'contribution_count', LCandidate.Integers['contribution_count'],
      'corpus_revision', LCandidate.Strings['corpus_revision'],
      'preferred_duration_ms', LJob.Objects['results'].Objects['decisions'].Int64s['music_frames'] *
        1000 div LJob.Objects['results'].Arrays['outputs'].Objects[0].Integers['sample_rate'],
      'has_form', LJob.Objects['results'].Find('sections') <> nil]);
    AddPerformedClock(LRecord, LJob);
    LRecord.Add('settings', LJob.Objects['results'].Objects['settings'].Clone);
    if LJob.Objects['results'].Find('original_reference') <> nil then
      LRecord.Add('original_reference', LJob.Objects['results'].Objects['original_reference'].Clone);
    try WriteStudioJSONNew(LPath, LRecord);
    except if not FileExists(NativeFilePath(LPath)) then raise end;
    Result := ReadStudioNamedStyle(ACatalogRoot, LId);
  finally
    LRecord.Free;
    LJob.Free;
  end;
end;

end.
