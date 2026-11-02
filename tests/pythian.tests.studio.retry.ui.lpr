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
program PythianStudioRetryUI;

{$mode delphi}
{$H+}

uses JS, SysUtils, pythian.studio.requests;

var
  GChecks: Integer;

procedure Check(const ACondition: Boolean; const AMessage: String);
begin
  if not ACondition then
  begin
    raise Exception.Create(AMessage);
  end;
  Inc(GChecks);
end;

procedure Rejected(const AJob: TJSObject; const AId: String);
var
  LRejected: Boolean;
begin
  LRejected := False;
  try
    StudioRetryWrite(AJob, AId);
  except
    on E: Exception do LRejected := True;
  end;
  Check(LRejected, 'Invalid retry must preserve the old run');
end;

procedure Run;
const
  CKinds: array[0..3] of String = ('instrumental_generate', 'instrumental_style',
    'instrumental_reperform', 'instrumental_regenerate');
var
  LJob: TJSObject;
  LRequest: TJSObject;
  LWrite: TJSObject;
  LBefore: String;
  LKind: String;
  I: Integer;
begin
  Rejected(nil, 'new');
  for I := 0 to High(CKinds) do
  begin
    LKind := CKinds[I];
    LJob := TJSObject(TJSJSON.parse('{"job_id":"old","project_id":"original",' +
      '"status":"failed","request":{"format":"pythian.studio.job.write.v1",' +
      '"job_id":"old","project_id":"original","project_revision":2,' +
      '"project_snapshot_sha256":"immutable","seeds":[79],"duration_ms":32000,' +
      '"instrumental":{"tempo_bpm":91},"style_id":"lofi",' +
      '"style_blend":{"right_style_id":"chillwave","groove_weight":0.75},' +
      '"parent_job_id":"before","parent_plan_sha256":"plan",' +
      '"sound_design":{"lead":{"cutoff":900}},"note_edit":{"parts":["bass"]},' +
      '"style_source":{"resolved":"native"},"comparison_before":{"resolved":"native"},' +
      '"project_snapshot":{"private":"native"},"preparation":{"resolved":"native"},' +
      '"replay_source_job_id":"resolved","request_sha256":"resolved","worker_seconds":600}}'));
    LRequest := TJSObject(LJob['request']);
    LJob['kind'] := LKind;
    LRequest['kind'] := LKind;
    LBefore := TJSJSON.stringify(LJob);
    LWrite := StudioRetryWrite(LJob, 'new');
    Check((LWrite['job_id'] = 'new') and (LWrite['retry_of'] = 'old'), 'Explicit retry lineage');
    Check((LWrite['project_id'] = 'original') and (LWrite['project_revision'] = 2) and
      (LWrite['project_snapshot_sha256'] = 'immutable'), 'Original project revision stays frozen');
    Check(isUndefined(LWrite['project_snapshot']) and isUndefined(LWrite['request_sha256']) and
      isUndefined(LWrite['style_source']) and isUndefined(LWrite['comparison_before']) and
      isUndefined(LWrite['worker_seconds']) and isUndefined(LWrite['replay_source_job_id']) and
      isUndefined(LWrite['preparation']), 'Resolved worker inputs cannot be resubmitted as controls');
    Check(TJSJSON.stringify(LJob) = LBefore, 'Projection never edits the retained failure');
    if LKind = 'instrumental_style' then
    begin
      Check((TJSArray(LWrite['seeds'])[0] = 79) and (LWrite['duration_ms'] = 32000) and
        (TJSObject(LWrite['style_blend'])['groove_weight'] = 0.75), 'Frozen blend, seed and length');
      TJSObject(LWrite['style_blend'])['groove_weight'] := 0;
      Check(TJSJSON.stringify(LJob) = LBefore, 'Nested retry edits cannot mutate the old blend');
    end
    else if LKind = 'instrumental_generate' then
    begin
      Check(TJSObject(LWrite['instrumental'])['tempo_bpm'] = 91, 'Frozen experiment');
      Check(isUndefined(LWrite['style_id']), 'Experiment cannot acquire a saved style');
    end
    else
    begin
      Check(isUndefined(LWrite['seeds']) and isUndefined(LWrite['duration_ms']) and
        isUndefined(LWrite['instrumental']), 'Followup keeps native parent-derived timing');
      Check((LWrite['parent_job_id'] = 'before') and (LWrite['parent_plan_sha256'] = 'plan'),
        'Followup binds its exact Before plan');
    end;
    LJob['status'] := 'running';
    Rejected(LJob, 'new');
    LJob['status'] := 'completed';
    Rejected(LJob, 'new');
    LJob['status'] := 'cancelled';
    Check(StudioRetryWrite(LJob, 'new')['retry_of'] = 'old', 'Stopped run can be explicitly retried');
    Rejected(LJob, 'old');
    LRequest['project_id'] := 'different';
    Rejected(LJob, 'new');
  end;
  WriteLn('Studio retry UI: ', GChecks, ' checks passed');
end;

begin
  Run;
end.
