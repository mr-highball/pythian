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

program StudioInstrumentalConformance;
{$mode delphi}
{$H+}
uses {$IFDEF UNIX}cthreads,{$ENDIF} Classes, SysUtils, fpjson,
  pythian.audio, pythian.wave.read, pythian.tools.studio.projects,
  pythian.tools.studio.jobs, pythian.tools.studio.worker, pythian.tools.listen.catalog;
type
  TInstrumentalCancelWorker = class(TThread)
  public
    Catalog: String;
    Succeeded: Boolean;
    Failure: String;
    procedure Execute; override;
  end;

procedure TInstrumentalCancelWorker.Execute;
begin
  try
    Succeeded := RunStudioWorker(Catalog, 'live-cancelled', Catalog + '-absent-library');
  except
    on E: Exception do Failure := E.ClassName + ': ' + E.Message;
  end;
end;

var GChecks: Integer;
procedure Check(ACondition: Boolean; const AMessage: String);
begin Inc(GChecks); if not ACondition then raise Exception.Create(AMessage) end;
function Config: TJSONObject;
begin
  Result := TJSONObject.Create;
  Result.Add('tempo_bpm', 120); Result.Add('tonic', 0); Result.Add('cells', 16);
  Result.Add('instruments', TJSONArray.Create(['saw','triangle','square']));
  Result.Add('levels', TJSONArray.Create([100,100,100,100,100,100]));
end;
procedure Run(const ARoot: String; const ASmoke: Boolean);
var
  LWrite, LProject, LRequest, LJob, LPrepared, LQueue, LAsset: TJSONObject;
  LHash, LFirstHash, LFirstModel: String; LStream: TFileStream; LWave: TWaveFrameReader;
  I, LRenderCount: Integer; LRejected: Boolean;
  LCancelWorker: TInstrumentalCancelWorker;
  LStarted: QWord;
  LReady: Boolean;
begin
  Check(ForceDirectories(ARoot), 'Create isolated root');
  LWrite := TJSONObject.Create;
  LProject := nil; LRequest := nil;
  try
    LWrite.Add('format', StudioProjectWriteFormat);
    LWrite.Add('project_id', 'instruments');
    LWrite.Add('expected_revision', 0);
    LWrite.Add('name', 'Instrumental fixture');
    LWrite.Add('style_intent', '');
    LWrite.Add('learning_mode', 'instrumental');
    LWrite.Add('sources', TJSONArray.Create);
    LProject := SaveStudioProject(ARoot, LWrite);
    Check(LProject.Arrays['sources'].Count = 0, 'Empty authored project saves');
    LRequest := TJSONObject.Create;
    LRequest.Add('format', StudioJobWriteFormat);
    LRequest.Add('kind', 'instrumental_generate');
    LRequest.Add('job_id', 'instrumental-1');
    LRequest.Add('project_id', LProject.Strings['project_id']);
    LRequest.Add('project_revision', LProject.Integers['revision']);
    LRequest.Add('project_snapshot_sha256', LProject.Strings['snapshot_sha256']);
    LRequest.Add('seeds', TJSONArray.Create([731]));
    LRequest.Add('instrumental', Config);
    LPrepared := PrepareStudioJob(ARoot, LRequest);
    try
      Check(LPrepared.Strings['learning_mode'] = 'instrumental', 'Preflight describes instrumental path');
      Check(LPrepared.Int64s['unique_source_bytes_to_verify'] = 0, 'No source verification is claimed');
    finally LPrepared.Free end;
    LRenderCount := 5;
    if ASmoke then LRenderCount := 1;
    for I := 1 to LRenderCount do
    begin
      LRequest.Strings['job_id'] := 'instrumental-' + IntToStr(I);
      if I = 3 then LRequest.Objects['instrumental'].Integers['tonic'] := 5;
      if I = 4 then
      begin
        LRequest.Objects['instrumental'].Integers['tonic'] := 0;
        LRequest.Objects['instrumental'].Arrays['instruments'].Strings[2] := 'sine';
      end;
      if I = 5 then
      begin
        LRequest.Objects['instrumental'].Arrays['instruments'].Strings[2] := 'square';
        LRequest.Objects['instrumental'].Add('controls', TJSONObject.Create([
          'guide', True, 'tonic_bias', 0, 'parts', TJSONArray.Create([
            TJSONObject.Create(['minimum_pitch', 0, 'maximum_pitch', 127,
              'activity_bias', 0, 'velocity_percent', 100, 'gate_percent', 100]),
            TJSONObject.Create(['minimum_pitch', 0, 'maximum_pitch', 127,
              'activity_bias', 0, 'velocity_percent', 100, 'gate_percent', 100]),
            TJSONObject.Create(['minimum_pitch', 72, 'maximum_pitch', 84,
              'activity_bias', 0, 'velocity_percent', 50, 'gate_percent', 100])
          ])]));
      end;
      LJob := EnqueueStudioJob(ARoot, LRequest); LJob.Free;
      Check(RunStudioWorker(ARoot, LRequest.Strings['job_id'], ARoot + '-absent-library'),
        'Ordinary durable worker completes without recordings');
      LJob := ReadStudioJob(ARoot, LRequest.Strings['job_id']);
      try
        Check(LJob.Strings['status'] = 'completed', 'Worker terminal success');
        Check(LJob.Integers['event_revision'] < 200, 'Detailed WFC callbacks use bounded durable publication');
        Check(LJob.Objects['results'].Arrays['parts'].Count = 6, 'Six playable stems');
        Check(LJob.Objects['results'].Arrays['graph'].Count = 16, 'Actual sixteen passes');
        Check(LJob.Objects['results'].Arrays['sources'].Count = 0, 'No used source audio invented');
        LHash := LJob.Objects['results'].Arrays['outputs'].Objects[0].Strings['wav_sha256'];
        if I = 1 then
        begin
          LFirstHash := LHash;
          LFirstModel := LJob.Objects['results'].Strings['model_sha256'];
        end
        else if I = 2 then Check(LHash = LFirstHash, 'Unchanged settings replay exact audio')
        else Check(LHash <> LFirstHash, 'Key/instrument control changes actual synthesized WAV');
        if I = 4 then Check(LJob.Objects['results'].Strings['model_sha256'] = LFirstModel,
          'Instrument change performs the same authored musical models');
        if I = 5 then
        begin
          Check(LJob.Objects['results'].Strings['model_sha256'] = LFirstModel,
            'Musical generation controls do not change the model vocabulary');
          Check(LJob.Objects['results'].Objects['settings'].Objects['controls'].
            Arrays['parts'].Objects[2].Integers['velocity_percent'] = 50,
            'Completed result retains actual performed controls');
          Check(LJob.Objects['results'].Objects['settings'].Objects['controls'].
            Arrays['parts'].Objects[2].Integers['minimum_pitch'] = 72,
            'Hard pitch control is retained in replay settings');
        end;
        LStream := OpenStudioInstrumentalAudio(ARoot, LRequest.Strings['job_id'], 6, LHash);
        try
          LWave := TWaveFrameReader.Create(LStream);
          try
            Check((LWave.FrameCount > 96000) and (LWave.Channels = 2), 'Bounded playable mix');
          finally LWave.Free end;
        finally LStream.Free end;
      finally LJob.Free end;
    end;
    LQueue := ReadListeningQueue(ARoot);
    try
      Check(LQueue.Arrays['items'].Count = LRenderCount, 'All successful jobs enter existing listening queue');
      LAsset := LQueue.Arrays['items'].Objects[0].Arrays['assets'].Objects[0];
      Check(LAsset.Objects['provenance'].Find('source_sha256') = nil, 'Authored feedback has no fictitious WAV');
      Check(Length(LAsset.Objects['provenance'].Strings['material_sha256']) = 64,
        'Feedback preserves authored material identity');
    finally LQueue.Free end;
    LRequest.Strings['job_id'] := 'invalid';
    LRequest.Objects['instrumental'].Integers['cells'] := 257;
    LRejected := False;
    try
      LPrepared := PrepareStudioJob(ARoot, LRequest); LPrepared.Free;
    except on E: EAudio do LRejected := True end;
    Check(LRejected, 'Unsupported finite length rejects, no truncation');
    LRequest.Objects['instrumental'].Integers['cells'] := 16;
    LRequest.Strings['job_id'] := 'cancelled';
    LJob := EnqueueStudioJob(ARoot, LRequest); LJob.Free;
    LJob := CancelStudioJob(ARoot, 'cancelled');
    try Check(LJob.Strings['status'] = 'cancelled', 'Queued instrumental cancellation persists')
    finally LJob.Free end;
    LRequest.Strings['job_id'] := 'live-cancelled';
    LJob := EnqueueStudioJob(ARoot, LRequest); LJob.Free;
    LCancelWorker := TInstrumentalCancelWorker.Create(True);
    try
      LCancelWorker.Catalog := ARoot;
      LCancelWorker.Start;
      LStarted := GetTickCount64;
      LReady := False;
      repeat
        LJob := ReadStudioJob(ARoot, 'live-cancelled');
        try
          LReady := (LJob.Strings['status'] = 'running') and
            (LJob.Strings['stage'] <> 'preflight');
        finally LJob.Free end;
        if not LReady then Sleep(10);
      until LReady or LCancelWorker.Finished or (GetTickCount64 - LStarted > 60000);
      LJob := CancelStudioJob(ARoot, 'live-cancelled');
      try Check(LJob.Booleans['cancel_requested'], 'Live cancellation request persists')
      finally LJob.Free end;
      LCancelWorker.WaitFor;
      Check(LReady, 'Cancellation exercises actual instrumental progress');
      Check(not LCancelWorker.Succeeded and (LCancelWorker.Failure = ''),
        'Worker handles cancellation despite suppressed progress publications');
      LJob := ReadStudioJob(ARoot, 'live-cancelled');
      try Check(LJob.Strings['status'] = 'cancelled', 'Live instrumental terminal cancellation')
      finally LJob.Free end;
    finally
      LCancelWorker.Free;
    end;
    if ASmoke then WriteLn('Studio instrumental smoke: ', GChecks,
      ' checks; one durable source-free job, six stems, lineage and actual cancellation')
    else WriteLn('Studio instrumental: ', GChecks,
      ' checks; durable source-free jobs, replay, key change, six stems and authored review lineage');
  finally LRequest.Free; LProject.Free; LWrite.Free end;
end;
begin
  try
    if (ParamCount = 2) and (ParamStr(1) = '--smoke') then Run(ParamStr(2), True)
    else if ParamCount = 1 then Run(ParamStr(1), False)
    else raise Exception.Create('Usage: fixture [--smoke] FRESH_ROOT');
  except on E: Exception do begin WriteLn(StdErr, E.ClassName, ': ', E.Message); ExitCode:=1 end end;
end.
