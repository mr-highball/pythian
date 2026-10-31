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
program StudioPlaylistConformance;
{$mode delphi}
{$H+}
uses Classes, SysUtils, Math, fpjson, pythian.audio, pythian.wave,
  pythian.tools.studio.projects, pythian.tools.studio.&library.discovery,
  pythian.tools.studio.jobs;
var GChecks: Integer;
procedure Check(const AValue: Boolean; const AMessage: String);
begin
  Inc(GChecks);
  if not AValue then raise Exception.Create(AMessage);
end;
procedure Audio(const APath: String; const AFrequency: Integer);
var LSamples: TAudioSamples; LClip: TAudioClip; I: Integer;
begin
  Check(ForceDirectories(ExtractFileDir(APath)), 'Create private fixture collection');
  SetLength(LSamples, 8000 * 75);
  for I := 0 to High(LSamples) do LSamples[I] := 0.03 * Sin(I * 2 * Pi * AFrequency / 8000);
  LClip := TAudioClip.Create(8000, 1, LSamples);
  try SaveWavePcm16(APath, LClip) finally LClip.Free end;
end;
procedure Run(const ARoot: String);
var
  LCatalog, LLibrary, LFile: String;
  LDiscovery, LWrite, LPlaylist, LItem, LResult, LRead: TJSONObject;
  LJob, LConfig: TJSONObject;
  LEntries, LItems: TJSONArray;
  LGuard: TFileStream;
  I: Integer;
  LText: String;
  LRejected: Boolean;
begin
  Check(not DirectoryExists(ARoot), 'Use fresh fixture root');
  LCatalog := IncludeTrailingPathDelimiter(ARoot) + 'catalog';
  LLibrary := IncludeTrailingPathDelimiter(ARoot) + 'library';
  Check(ForceDirectories(LCatalog), 'Create isolated catalog');
  Check(ForceDirectories(IncludeTrailingPathDelimiter(ARoot) + 'inbox'), 'Create QA inbox');
  Audio(LLibrary + '/collections/Chillsynth/Evening.wav', 220);
  Audio(LLibrary + '/collections/lofi/Soft steps.wav', 330);
  LDiscovery := DiscoverStudioLibrary(LCatalog, LLibrary);
  LWrite := TJSONObject.Create;
  try
    LEntries := LDiscovery.Arrays['entries'];
    Check(LEntries.Count = 2, 'Discover two music collections');
    LWrite.Add('format', StudioProjectWriteFormat);
    LWrite.Add('project_id', 'simple-playlist');
    LWrite.Add('expected_revision', 0);
    LWrite.Add('name', 'Evening playlist');
    LWrite.Add('style_intent', '');
    LWrite.Add('learning_mode', 'instrumental');
    LWrite.Add('sources', TJSONArray.Create);
    LPlaylist := TJSONObject.Create;
    LWrite.Add('playlist', LPlaylist);
    LPlaylist.Add('format', StudioPlaylistFormat);
    LItems := TJSONArray.Create;
    LPlaylist.Add('items', LItems);
    for I := 0 to LEntries.Count - 1 do
    begin
      LItem := TJSONObject.Create;
      LItems.Add(LItem);
      LItem.Add('kind', 'library');
      LItem.Add('id', LEntries.Objects[I].Strings['entry_id']);
      LItem.Add('snapshot_sha256', LEntries.Objects[I].Strings['entry_snapshot_sha256']);
      LItem.Add('discovery_revision', LDiscovery.Integers['revision']);
      LItem.Add('title', LEntries.Objects[I].Strings['original_name']);
      LItem.Add('sample_rate', LEntries.Objects[I].Int64s['sample_rate']);
      LItem.Add('frame_count', LEntries.Objects[I].Int64s['frame_count']);
      LItem.Add('influence', I + 1);
      LItem.Add('extent', 'whole');
      LItem.Add('clips', TJSONArray.Create);
    end;
    LFile := LLibrary + '/collections/Chillsynth/Evening.wav';
    LGuard := TFileStream.Create(LFile, fmOpenReadWrite or fmShareExclusive);
    try
      LText := LWrite.AsJSON;
      LResult := SaveStudioProject(LCatalog, LWrite);
      try
        Check(LWrite.AsJSON = LText, 'Saving leaves borrowed playlist unchanged');
        Check(LResult.Objects['playlist'].Arrays['items'].Count = 2, 'Save both unprepared tracks');
        Check(not LResult.Booleans['model_available'] and
          (LResult.Strings['training_status'] = 'not_started'), 'Save never claims learning');
        Check(not DirectoryExists(LCatalog + '/sources'), 'Adding a playlist does not copy audio');
      finally LResult.Free end;
    finally LGuard.Free end;
    Check(RenameFile(LFile, LFile + '.moved'), 'Temporarily remove original');
    try
      LRead := ReadStudioProject(LCatalog, 'simple-playlist');
      try
        Check(LRead.Objects['playlist'].Arrays['items'].Count = 2,
          'Missing original does not destroy saved playlist');
      finally LRead.Free end;
      LWrite.Integers['expected_revision'] := 1;
      LItems.Objects[0].Integers['influence'] := 6;
      LResult := SaveStudioProject(LCatalog, LWrite);
      try
        Check(LResult.Integers['revision'] = 2,
          'Metadata-only edit works without audio; Generate must verify content separately');
      finally LResult.Free end;
    finally
      Check(RenameFile(LFile + '.moved', LFile), 'Restore original fixture');
    end;
    LRead := ReadStudioProjectRevision(LCatalog, 'simple-playlist', 1);
    try
      Check(LRead.Objects['playlist'].Arrays['items'].Objects[0].Integers['influence'] = 1,
        'Earlier weight and source identity remain immutable');
      LJob := TJSONObject.Create(['format', StudioJobWriteFormat,
        'job_id', 'no-authored-substitution', 'kind', 'instrumental_generate',
        'project_id', 'simple-playlist', 'project_revision', 1,
        'project_snapshot_sha256', LRead.Strings['snapshot_sha256']]);
      try
        LJob.Add('seeds', TJSONArray.Create([731]));
        LConfig := TJSONObject.Create(['tempo_bpm', 120, 'tonic', 0, 'cells', 16]);
        LConfig.Add('instruments', TJSONArray.Create(['sine', 'triangle', 'saw']));
        LConfig.Add('levels', TJSONArray.Create([70, 65, 60, 80, 60, 50]));
        LJob.Add('instrumental', LConfig);
        LRejected := False;
        try
          LResult := PrepareStudioJob(LCatalog, LJob);
          LResult.Free;
        except
          on E: EAudio do LRejected := Pos('Playlist learning is not connected yet', E.Message) = 1;
        end;
        Check(LRejected, 'A playlist cannot silently fall back to authored-only generation');
      finally
        LJob.Free;
      end;
    finally LRead.Free end;
  finally
    LWrite.Free;
    LDiscovery.Free;
  end;
  WriteLn('PASS ', GChecks, ' lazy playlist checks');
end;
begin
  try
    Check(ParamCount = 1, 'Usage: playlist FRESH_ROOT');
    Run(ParamStr(1));
  except
    on E: Exception do begin WriteLn(StdErr, E.ClassName, ': ', E.Message); ExitCode := 1 end;
  end;
end.
