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
unit pythian.tools.studio.references;

{$mode delphi}
{$H+}

interface

uses fpjson;

{ Metadata only, from the exact published output and its immutable job.
  Big Boss: never infer a training range from a current project or a hash alone. }
function ReadListeningSourceReferences(const ACatalogRoot, ARequestId,
  AAssetId: String): TJSONObject;
{ Read-only instrumental view of the exact voting WAV's completed performance.
  Parts share its clock; selecting one never changes the immutable review. }
function ReadListeningPerformance(const ACatalogRoot, ARequestId,
  AAssetId: String): TJSONObject;

implementation

uses SysUtils, pythian.audio, pythian.tools.listen.catalog,
  pythian.tools.studio.jobs, pythian.tools.studio.reviews;

const
  CListeningLists: array[0..1] of String = ('items', 'completed');

function ReadListeningPerformance(const ACatalogRoot, ARequestId,
  AAssetId: String): TJSONObject;
var
  LQueue, LJobs, LJob, LRow, LAsset, LProvenance, LPerformance,
    LOutput, LPart, LView, LBound: TJSONObject;
  LList: String;
  I, J, K: Integer;
begin
  if IsStudioReviewListeningItemHidden(ACatalogRoot, ARequestId) then
    raise EAudio.Create('Performance details are hidden until this blind comparison is submitted');
  LBound := ResolveListeningAsset(ACatalogRoot, ARequestId, AAssetId);
  LBound.Free;
  Result := TJSONObject.Create;
  try
    Result.Add('format', 'pythian.listening.performance.v1');
    Result.Add('request_id', ARequestId);
    Result.Add('asset_id', AAssetId);
    Result.Add('status', 'unavailable');
    Result.Add('parts', TJSONArray.Create);
    LQueue := ReadListeningQueue(ACatalogRoot);
    try
      LAsset := nil;
      for LList in CListeningLists do
        for I := 0 to LQueue.Arrays[LList].Count - 1 do
        begin
          LRow := LQueue.Arrays[LList].Objects[I];
          if LRow.Strings['id'] <> ARequestId then Continue;
          Result.Add('request_sha256', LRow.Strings['request_sha256']);
          for J := 0 to LRow.Arrays['assets'].Count - 1 do
            if LRow.Arrays['assets'].Objects[J].Strings['id'] = AAssetId then
              LAsset := LRow.Arrays['assets'].Objects[J];
        end;
      if (LAsset = nil) or
        ((LAsset.Get('role', '') <> 'generated') and (LAsset.Get('role', '') <> 'edited')) or
        (LAsset.Find('provenance') = nil) then Exit;
      LProvenance := LAsset.Objects['provenance'];
      LJobs := ListStudioJobs(ACatalogRoot);
      try
        for I := 0 to LJobs.Arrays['jobs'].Count - 1 do
        begin
          LRow := LJobs.Arrays['jobs'].Objects[I];
          if not IsStudioInstrumentalJob(LRow.Get('kind', '')) or
            (LRow.Get('status', '') <> 'completed') or
            (LRow.Get('request_sha256', '') <> LProvenance.Get('parameter_sha256', '')) then Continue;
          LJob := ReadStudioJob(ACatalogRoot, LRow.Strings['job_id']);
          try
            LPerformance := LJob.Objects['results'];
            if (LPerformance.Get('model_sha256', '') <> LProvenance.Get('model_sha256', '')) or
              (LPerformance.Get('material_sha256', '') <> LProvenance.Get('material_sha256', '')) then
              raise EAudio.Create('Review performance/model binding differs');
            LOutput := LPerformance.Arrays['outputs'].Objects[0];
            if (LOutput.Strings['wav_sha256'] <> LAsset.Strings['sha256']) or
              (LOutput.Int64s['frame_count'] <> LAsset.Int64s['frames']) or
              (LOutput.Integers['sample_rate'] <> LAsset.Integers['sample_rate']) or
              (LOutput.Integers['channels'] <> LAsset.Integers['channels']) or
              (LOutput.Int64s['seed'] <> LProvenance.Int64s['seed']) then
              raise EAudio.Create('Review performance/audio binding differs');
            if LPerformance.Arrays['parts'].Count <> 6 then
              raise EAudio.Create('Review performance requires six retained parts');
            Result.Strings['status'] := 'ready';
            Result.Add('job_id', LJob.Strings['job_id']);
            Result.Add('source_request_sha256', LJob.Strings['request_sha256']);
            Result.Add('plan_sha256', LPerformance.Strings['plan_sha256']);
            Result.Add('model_sha256', LPerformance.Strings['model_sha256']);
            Result.Add('material_origin', LPerformance.Strings['material_origin']);
            Result.Add('seed', LOutput.Int64s['seed']);
            Result.Add('graph', LPerformance.Arrays['graph'].Clone);
            for J := 0 to 6 do
            begin
              LPart := LOutput;
              if J < 6 then LPart := LPerformance.Arrays['parts'].Objects[J];
              if (LPart.Int64s['frame_count'] <> LOutput.Int64s['frame_count']) or
                (LPart.Integers['sample_rate'] <> LOutput.Integers['sample_rate']) or
                (LPart.Integers['channels'] <> LOutput.Integers['channels']) then
                raise EAudio.Create('Retained part clock differs from the reviewed mix');
              if (J < 6) and (LPart.Integers['part_index'] <> J) then
                raise EAudio.Create('Retained part index differs');
              LView := TJSONObject.Create;
              Result.Arrays['parts'].Add(LView);
              LView.Add('part_index', J);
              LView.Add('name', 'Full mix');
              if J < 6 then LView.Strings['name'] := LPart.Strings['name'];
              LView.Add('audio_url', '/api/studio/instrumental-audio?job=' +
                LJob.Strings['job_id'] + '&part=' + IntToStr(J));
              for K := 0 to LPart.Count - 1 do
                if (LPart.Names[K] = 'wav_sha256') or (LPart.Names[K] = 'sample_rate') or
                  (LPart.Names[K] = 'channels') or (LPart.Names[K] = 'frame_count') then
                  LView.Add(LPart.Names[K], LPart.Items[K].Clone);
            end;
            Exit;
          finally
            LJob.Free;
          end;
        end;
      finally
        LJobs.Free;
      end;
    finally
      LQueue.Free;
    end;
  except
    Result.Free;
    raise;
  end;
end;

function ReadListeningSourceReferences(const ACatalogRoot, ARequestId,
  AAssetId: String): TJSONObject;
var
  LQueue, LJobs, LJob, LResult, LAsset, LProvenance, LRow, LSource,
    LReference, LSnapshot, LBound, LRequest, LStreamResult: TJSONObject;
  LList: String;
  I, J, K: Integer;
  LMatched: Boolean;
begin
  if IsStudioReviewListeningItemHidden(ACatalogRoot, ARequestId) then
    raise EAudio.Create('Originals are hidden until this blind comparison is submitted');
  LBound := ResolveListeningAsset(ACatalogRoot, ARequestId, AAssetId);
  LBound.Free;
  Result := TJSONObject.Create;
  try
    Result.Add('format', 'pythian.listening.references.v1');
    Result.Add('request_id', ARequestId);
    Result.Add('asset_id', AAssetId);
    Result.Add('status', 'unavailable');
    Result.Add('message', 'Original selections are not available for this recording.');
    Result.Add('sources', TJSONArray.Create);
    LQueue := ReadListeningQueue(ACatalogRoot);
    try
      LAsset := nil;
      for LList in CListeningLists do
        for I := 0 to LQueue.Arrays[LList].Count - 1 do
        begin
          LRow := LQueue.Arrays[LList].Objects[I];
          if LRow.Strings['id'] <> ARequestId then Continue;
          for J := 0 to LRow.Arrays['assets'].Count - 1 do
            if LRow.Arrays['assets'].Objects[J].Strings['id'] = AAssetId then
              LAsset := LRow.Arrays['assets'].Objects[J];
        end;
      if (LAsset = nil) or (LAsset.Get('role', '') <> 'generated') or
        (LAsset.Find('provenance') = nil) then Exit;
      LProvenance := LAsset.Objects['provenance'];
      LJobs := ListStudioJobs(ACatalogRoot);
      try
        for I := 0 to LJobs.Arrays['jobs'].Count - 1 do
        begin
          LRow := LJobs.Arrays['jobs'].Objects[I];
          if (LRow.Get('request_sha256', '') <> LProvenance.Get('parameter_sha256', '')) or
            ((LRow.Get('kind', '') <> 'train_generate') and
            (LRow.Get('kind', '') <> 'stream_generate')) then Continue;
          LJob := ReadStudioJob(ACatalogRoot, LRow.Strings['job_id']);
          LRequest := nil;
          LStreamResult := nil;
          try
            if LRow.Get('kind', '') = 'stream_generate' then
            begin
              { A saved excerpt is durable while its bounded session still runs.
                Read its committed binding, never the current project or an
                uncommitted worker status snapshot. }
              if not FileExists(StudioJobDirectory(ACatalogRoot, LRow.Strings['job_id']) +
                PathDelim + 'stream-excerpt.receipt.json') then Continue;
              LStreamResult := ReadStudioJSON(StudioJobDirectory(ACatalogRoot,
                LRow.Strings['job_id']) + PathDelim + 'stream-excerpt.receipt.json');
              LResult := LStreamResult;
              if LResult.Get('request_sha256', '') <>
                LProvenance.Get('parameter_sha256', '') then Continue;
            end
            else
            begin
              if LJob.Find('results') = nil then Continue;
              LResult := LJob.Objects['results'];
            end;
            if (LResult.Get('model_sha256', '') <> LProvenance.Get('model_sha256', '')) or
              (LResult.Find('sources') = nil) then Continue;
            LMatched := False;
            if LStreamResult <> nil then
              LMatched := LResult.Get('wav_sha256', '') = LAsset.Strings['sha256']
            else if LResult.Find('outputs') <> nil then
              for J := 0 to LResult.Arrays['outputs'].Count - 1 do
                if LResult.Arrays['outputs'].Objects[J].Get('wav_sha256', '') =
                  LAsset.Strings['sha256'] then LMatched := True;
            if not LMatched then Continue;
            LRequest := ReadStudioJobRequest(ACatalogRoot, LRow.Strings['job_id']);
            LSnapshot := LRequest.Objects['project_snapshot'];
            for J := 0 to LResult.Arrays['sources'].Count - 1 do
            begin
              LSource := LResult.Arrays['sources'].Objects[J];
              if (LSource.Int64s['start_frame'] < 0) or
                (LSource.Int64s['end_frame'] <= LSource.Int64s['start_frame']) or
                (LSource.Int64s['end_frame'] > LSource.Int64s['source_frames']) or
                (LSource.Integers['sample_rate'] <= 0) then
                raise EAudio.Create('Saved original selection is invalid');
              LReference := TJSONObject.Create;
              Result.Arrays['sources'].Add(LReference);
              LReference.Add('source_sha256', LSource.Strings['source_sha256']);
              LReference.Add('title', 'Original recording ' + IntToStr(J + 1));
              for K := 0 to LSnapshot.Arrays['sources'].Count - 1 do
                if LSnapshot.Arrays['sources'].Objects[K].Strings['source_sha256'] =
                  LSource.Strings['source_sha256'] then
                begin
                  LReference.Strings['title'] := LSnapshot.Arrays['sources'].Objects[K].Get(
                    'title', LReference.Strings['title']);
                  Break;
                end;
              LReference.Add('sample_rate', LSource.Integers['sample_rate']);
              LReference.Add('start_frame', LSource.Int64s['start_frame']);
              LReference.Add('end_frame', LSource.Int64s['end_frame']);
              if LSource.Find('prepared') <> nil then
                LReference.Add('prepared', LSource.Objects['prepared'].Clone);
              LReference.Add('available', FileExists(IncludeTrailingPathDelimiter(ACatalogRoot) +
                'sources' + PathDelim + LSource.Strings['source_sha256'] + '.wav'));
            end;
            if Result.Arrays['sources'].Count > 0 then
            begin
              Result.Strings['status'] := 'ready';
              Result.Strings['message'] := 'These are the original selections used for this audition. Generated music rearranges their sounds; the timelines do not align.';
            end;
            Exit;
          finally
            LStreamResult.Free;
            LRequest.Free;
            LJob.Free;
          end;
        end;
      finally
        LJobs.Free;
      end;
    finally
      LQueue.Free;
    end;
  except
    Result.Free;
    raise;
  end;
end;

end.
