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
unit pythian.tools.studio.schema;

{$mode delphi}
{$H+}

interface

const
  StudioJobWriteFormat = 'pythian.studio.job.write.v1';

{ Big Boss: admission and retry projection share the write schema. A public
  retained request also contains resolved worker inputs; these are not writes. }
function StudioInstrumentalWriteFields(const AKind: String): String;

implementation

function StudioInstrumentalWriteFields(const AKind: String): String;
const
  CIdentity = '|format|job_id|kind|project_id|project_revision|project_snapshot_sha256|';
begin
  Result := '';
  if AKind = 'instrumental_generate' then
  begin
    Result := CIdentity + 'seeds|instrumental|duration_ms|parent_job_id|retry_of|';
  end
  else if AKind = 'instrumental_style' then
  begin
    Result := CIdentity + 'style_id|style_blend|duration_ms|seeds|retry_of|';
  end
  else if (AKind = 'instrumental_reperform') or (AKind = 'instrumental_regenerate') then
  begin
    Result := CIdentity + 'parent_job_id|parent_plan_sha256|instruments|note_edit|' +
      'retry_of|sound_design|';
  end;
end;

end.
