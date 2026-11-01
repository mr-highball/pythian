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
unit pythian.tools.studio.sound.patches;

{$mode delphi}{$H+}

interface

uses fpjson;

{ Immutable local definitions only. Save never starts learning, inference,
  synthesis or playback. Listing returns summaries; load a definition explicitly. }
function ListStudioSoundPatches(const ACatalogRoot: String): TJSONObject;
function ReadStudioSoundPatch(const ACatalogRoot, AId: String): TJSONObject;
function SaveStudioSoundPatch(const ACatalogRoot: String; const AWrite: TJSONObject): TJSONObject;

implementation

uses SysUtils, pythian.audio, pythian.text, pythian.tools.json,
  pythian.tools.studio.jobs, pythian.tools.studio.sounds,
  pythian.tools.studio.instrumental.config;

const
  CFormat = 'pythian.studio.sound-patch.v1';
  CMaximumPatches = 128;

procedure Need(const ACondition: Boolean; const AMessage: String);
begin
  if not ACondition then
  begin
    raise EAudio.Create(AMessage);
  end;
end;

function PatchRoot(const ACatalogRoot: String): String;
begin
  Need(DirectoryExists(ACatalogRoot), 'Sound patch catalog does not exist');
  Result := IncludeTrailingPathDelimiter(ExpandFileName(ACatalogRoot)) +
    'studio' + PathDelim + 'sound-patches' + PathDelim;
end;

procedure ValidateId(const AId: String);
var
  I: Integer;
begin
  Need((Length(AId) = 70) and (Copy(AId, 1, 6) = 'patch-'), 'Invalid sound patch identity');
  for I := 7 to Length(AId) do
  begin
    Need(AId[I] in ['0'..'9', 'a'..'f'], 'Invalid sound patch identity');
  end;
end;

function PatchDigest(const AName: TScalarText; const ADesign: TJSONObject): String;
var
  LIdentity: TJSONObject;
begin
  LIdentity := TJSONObject.Create(['format', CFormat]);
  try
    LIdentity.Add('name', NativeJSONText(AName));
    LIdentity.Add('design', ADesign.Clone);
    Result := HashNativeText(WriteNativeJSON(LIdentity, 262144));
  finally
    LIdentity.Free;
  end;
end;

function ReadStudioSoundPatch(const ACatalogRoot, AId: String): TJSONObject;
var
  LCanonical: TJSONObject;
  LName: TScalarText;
  LHash: String;
begin
  ValidateId(AId);
  Result := ReadStudioJSON(PatchRoot(ACatalogRoot) + AId + '.json');
  try
    Need((Result.Count = 5) and (Result.Strings['format'] = CFormat) and
      (Result.Strings['id'] = AId), 'Saved sound patch identity differs');
    Need((Result.Find('name') <> nil) and (Result.Find('name').JSONType = jtString),
      'Saved sound patch name is missing');
    LName := Result.Strings['name'];
    ValidateScalarText(LName, 128, False);
    LCanonical := CanonicalStudioSoundDesign(Result.Find('design'), StudioInstrumentalRate);
    try
      LHash := PatchDigest(LName, LCanonical);
      Need((Result.Strings['sha256'] = LHash) and (AId = 'patch-' + LHash),
        'Saved sound patch content differs');
    finally
      LCanonical.Free;
    end;
  except
    Result.Free;
    raise;
  end;
end;

function ListStudioSoundPatches(const ACatalogRoot: String): TJSONObject;
var
  LSearch: TSearchRec;
  LRecord: TJSONObject;
  LRows: TJSONArray;
  LErrors: TJSONArray;
  LId: String;
  LCount: Integer;
begin
  Result := TJSONObject.Create(['format', 'pythian.studio.sound-patches.v1']);
  LRows := TJSONArray.Create;
  LErrors := TJSONArray.Create;
  Result.Add('patches', LRows);
  Result.Add('errors', LErrors);
  LCount := 0;
  try
    if FindFirst(PatchRoot(ACatalogRoot) + '*.json', faAnyFile, LSearch) = 0 then
    begin
      try
        repeat
          Need((LSearch.Attr and faDirectory) = 0, 'Unexpected directory in sound patches');
          Inc(LCount);
          Need(LCount <= CMaximumPatches, 'Sound patch catalog exceeds128 entries');
          LId := ChangeFileExt(LSearch.Name, '');
          try
            LRecord := ReadStudioSoundPatch(ACatalogRoot, LId);
            try
              LRows.Add(TJSONObject.Create(['id', LId, 'name', LRecord.Find('name').Clone,
                'sha256', LRecord.Strings['sha256']]));
            finally
              LRecord.Free;
            end;
          except
            on LException: Exception do
            begin
              LErrors.Add(TJSONObject.Create(['id', LId, 'error', LException.Message]));
            end;
          end;
        until FindNext(LSearch) <> 0;
      finally
        FindClose(LSearch);
      end;
    end;
  except
    Result.Free;
    raise;
  end;
end;

function SaveStudioSoundPatch(const ACatalogRoot: String; const AWrite: TJSONObject): TJSONObject;
var
  LDesign: TJSONObject;
  LRecord: TJSONObject;
  LExisting: TJSONObject;
  LName: TScalarText;
  LId: String;
  LHash: String;
  LPath: String;
begin
  Need((AWrite <> nil) and (AWrite.Count = 3) and
    (AWrite.Strings['format'] = 'pythian.studio.sound-patch.write.v1') and
    (AWrite.Find('name') <> nil) and (AWrite.Find('name').JSONType = jtString),
    'Save a sound setup with a name and design');
  LName := AWrite.Strings['name'];
  ValidateScalarText(LName, 128, False);
  LDesign := CanonicalStudioSoundDesign(AWrite.Find('design'), StudioInstrumentalRate);
  LRecord := nil;
  try
    LHash := PatchDigest(LName, LDesign);
    LId := 'patch-' + LHash;
    LPath := PatchRoot(ACatalogRoot) + LId + '.json';
    if FileExists(LPath) then
    begin
      Exit(ReadStudioSoundPatch(ACatalogRoot, LId));
    end;
    LExisting := ListStudioSoundPatches(ACatalogRoot);
    try
      Need(LExisting.Arrays['patches'].Count + LExisting.Arrays['errors'].Count < CMaximumPatches,
        'Sound patch catalog is full');
    finally
      LExisting.Free;
    end;
    LRecord := TJSONObject.Create(['format', CFormat, 'id', LId, 'sha256', LHash]);
    LRecord.Add('name', NativeJSONText(LName));
    LRecord.Add('design', LDesign);
    LDesign := nil;
    { Verify the actual bound before any write; the shared atomic record writer
      retains stage/commit failure semantics. Retry reads only matching content. }
    WriteNativeJSON(LRecord, 262144);
    try
      WriteStudioJSONNew(LPath, LRecord);
    except
      if not FileExists(LPath) then
      begin
        raise;
      end;
    end;
    Result := ReadStudioSoundPatch(ACatalogRoot, LId);
  finally
    LDesign.Free;
    LRecord.Free;
  end;
end;

end.
