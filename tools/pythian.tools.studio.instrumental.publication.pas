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

unit pythian.tools.studio.instrumental.publication;
{$mode delphi}
{$H+}
interface
uses fpjson, pythian.progress;
type
  TInstrumentalWorkCheck = procedure of object;
procedure PublishStudioInstrumental(const ACatalogRoot, AJobId: String;
  const ARequest, AResult, AReference: TJSONObject; const AIsPlaylist: Boolean;
  const ACheck: TInstrumentalWorkCheck; const AProgress: TWorkProgressCallback);
implementation
uses SysUtils, pythian.tools.studio.jobs, pythian.tools.studio.projects,
  pythian.tools.studio.playlist.learning, pythian.tools.listen.catalog,
  pythian.tools.studio.instrumental.config;
procedure PublishStudioInstrumental(const ACatalogRoot, AJobId: String;
  const ARequest, AResult, AReference: TJSONObject; const AIsPlaylist: Boolean;
  const ACheck: TInstrumentalWorkCheck; const AProgress: TWorkProgressCallback);
var
  LId, LDirectory, LMaterialHash, LModelHash, LOrigin: String;
  LQueue, LItem, LOutput, LAsset, LProvenance, LRange, LSpec, LChoice, LPublished: TJSONObject;
  LAssets: TJSONArray;
  LSeed: Cardinal;
  LRate: Integer;
  LFrameCount: Int64;
begin
  LDirectory := StudioJobDirectory(ACatalogRoot, AJobId);
  LMaterialHash := AResult.Strings['material_sha256'];
  LModelHash := AResult.Strings['model_sha256'];
  LOrigin := AResult.Strings['material_origin'];
  LOutput := AResult.Arrays['outputs'].Objects[0];
  LRate := LOutput.Integers['sample_rate'];
  LFrameCount := LOutput.Int64s['frame_count'];
  LSeed := ARequest.Arrays['seeds'].Int64s[0];
  LQueue := nil;
  try
    LId := 'studio_' + AJobId + '_0';
    LOutput.Add('listening_request_id', LId);
    LQueue := TJSONObject.Create;
    LQueue.Add('version', 1);
    LItem := TJSONObject.Create;
    LQueue.Add('items', TJSONArray.Create([LItem]));
    LItem.Add('id', LId);
    LItem.Add('task_id', 'NS-6_instrumental-studio_01');
    if AIsPlaylist then LItem.Strings['task_id'] := 'NS-3_style-vocabulary_01';
    LItem.Add('kind', 'single');
    LItem.Add('question', 'Do these instruments work together as music you want to develop?');
    if AReference <> nil then
    begin
      LItem.Strings['kind'] := 'pair';
      LItem.Strings['question'] := 'Do the synthesized parts carry musical qualities you want from this original?';
    end;
    if AIsPlaylist and (ARequest.Int64s['duration_ms'] > 30000) then
    begin
      LItem.Strings['task_id'] := 'NS-6_instrumental-streams_01';
      LItem.Strings['question'] := 'Can you hear distracting restarts or gaps in this longer track?';
    end;
    LAssets := TJSONArray.Create;
    LItem.Add('assets', LAssets);
    LAsset := TJSONObject.Create;
    LAssets.Add(LAsset);
    LAsset.Add('id', 'audition'); LAsset.Add('storage', 'listening');
    LAsset.Add('role', 'generated');
    LAsset.Add('sha256', LOutput.Strings['wav_sha256']);
    LAsset.Add('sample_rate', LRate); LAsset.Add('channels', 2);
    LAsset.Add('frames', LFrameCount); LAsset.Add('bytes', LOutput.Int64s['wav_bytes']);
    LProvenance := TJSONObject.Create;
    LAsset.Add('provenance', LProvenance);
    LProvenance.Add('material_sha256', LMaterialHash);
    LProvenance.Add('material_origin', LOrigin);
    LProvenance.Add('model_sha256', LModelHash);
    if AIsPlaylist then
      LProvenance.Add('policy_sha256', StudioTextHash(StudioPlaylistLearningPolicy + '|' +
        StudioPlaylistAnalysisPolicy + '|' + StudioPlaylistOrigin))
    else LProvenance.Add('policy_sha256', StudioTextHash('pythian instrumental starter studio v1'));
    LProvenance.Add('parameter_sha256', ARequest.Strings['request_sha256']);
    LProvenance.Add('split', 'development'); LProvenance.Add('seed', Int64(LSeed));
    LRange := TJSONObject.Create;
    LItem.Add('ranges', TJSONArray.Create([LRange]));
    LRange.Add('asset_id', 'audition'); LRange.Add('start_frame', 0);
    LRange.Add('end_frame', LFrameCount);
    if AReference <> nil then
    begin
      LAsset := TJSONObject.Create;
      LAssets.Add(LAsset);
      LAsset.Add('id', 'original_reference');
      LAsset.Add('storage', 'listening');
      LAsset.Add('role', 'reference');
      LAsset.Add('sha256', AReference.Strings['wav_sha256']);
      LAsset.Add('sample_rate', AReference.Integers['sample_rate']);
      LAsset.Add('channels', AReference.Integers['channels']);
      LAsset.Add('frames', AReference.Int64s['frame_count']);
      LAsset.Add('bytes', AReference.Int64s['wav_bytes']);
      LProvenance := TJSONObject.Create;
      LAsset.Add('provenance', LProvenance);
      LProvenance.Add('source_sha256', AReference.Strings['wav_sha256']);
      LProvenance.Add('source_group', AReference.Strings['source_group']);
      LProvenance.Add('clock_id', AReference.Strings['clock_id']);
      LProvenance.Add('partition', AReference.Strings['partition']);
      LRange := TJSONObject.Create;
      LItem.Arrays['ranges'].Add(LRange);
      LRange.Add('asset_id', 'original_reference');
      LRange.Add('start_frame', 0);
      LRange.Add('end_frame', AReference.Int64s['frame_count']);
    end;
    LSpec := TJSONObject.Create; LItem.Add('answer_spec', LSpec);
    LChoice := TJSONObject.Create; LSpec.Add('choices', TJSONArray.Create([LChoice]));
    LSpec.Add('scores', TJSONArray.Create);
    LChoice.Add('id', 'instrumental_fit');
    if AIsPlaylist and (ARequest.Int64s['duration_ms'] > 30000) then
      LChoice.Strings['id'] := 'continuity_breaks';
    LChoice.Add('values', TJSONArray.Create(['yes', 'no', 'unknown']));
    ReportWork(AProgress, 'instrumental_save', wuItems, 0, 1);
    WriteStudioJSONNew(LDirectory + PathDelim + 'listening-publication.json', LQueue);
    if Assigned(ACheck) then ACheck;
    LPublished := AppendListeningQueue(ACatalogRoot, LDirectory + PathDelim + 'listening-publication.json');
    LPublished.Free;
    AResult.Add('publication_status', 'published');
    WriteStudioJSONNew(LDirectory + PathDelim + 'result.json', AResult);
  finally
    LQueue.Free;
  end;
end;
end.
