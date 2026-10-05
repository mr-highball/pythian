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

implementation

uses SysUtils, pythian.audio, pythian.tools.listen.catalog,
  pythian.tools.studio.jobs, pythian.tools.studio.reviews;

const
  CListeningLists: array[0..1] of String = ('items', 'completed');

function ReadListeningSourceReferences(const ACatalogRoot, ARequestId,
  AAssetId: String): TJSONObject;
var
  LQueue, LJobs, LJob, LResult, LAsset, LProvenance, LRow, LSource,
    LReference, LSnapshot, LBound, LRequest: TJSONObject;
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
            (LRow.Get('kind', '') <> 'train_generate') then Continue;
          LJob := ReadStudioJob(ACatalogRoot, LRow.Strings['job_id']);
          LRequest := nil;
          try
            if LJob.Find('results') = nil then Continue;
            LResult := LJob.Objects['results'];
            if (LResult.Get('model_sha256', '') <> LProvenance.Get('model_sha256', '')) or
              (LResult.Find('outputs') = nil) or (LResult.Find('sources') = nil) then Continue;
            LMatched := False;
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
