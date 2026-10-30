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

program pythian_tests_studio_material_generation;
{$mode delphi}{$H+}
uses {$IFDEF UNIX}cthreads,{$ENDIF} Classes, SysUtils, fpjson,
  pythian.audio, pythian.wave.read, pythian.tools.studio.material,
  pythian.tools.studio.capture, pythian.tools.studio.projects,
  pythian.tools.studio.jobs, pythian.tools.studio.worker,
  pythian.tools.listen.catalog, pythian.tests.studio.material.support;
var
  Checks: Integer;
procedure Check(const ACondition: Boolean; const AMessage: String);
begin
  Inc(Checks);
  if not ACondition then raise EAudio.Create(AMessage);
end;
function Generation(const AProject: TJSONObject; const AId: String): TJSONObject;
var LConfig: TJSONObject;
begin
  Result := TJSONObject.Create;
  Result.Add('format', StudioJobWriteFormat);
  Result.Add('job_id', AId);
  Result.Add('kind', 'instrumental_generate');
  Result.Add('project_id', AProject.Strings['project_id']);
  Result.Add('project_revision', AProject.Integers['revision']);
  Result.Add('project_snapshot_sha256', AProject.Strings['snapshot_sha256']);
  Result.Add('seeds', TJSONArray.Create([731]));
  LConfig := TJSONObject.Create;
  Result.Add('instrumental', LConfig);
  LConfig.Add('tempo_bpm', 120);
  LConfig.Add('tonic', 0);
  LConfig.Add('cells', 16);
  LConfig.Add('instruments', TJSONArray.Create(['saw','triangle','square']));
  LConfig.Add('levels', TJSONArray.Create([100,100,100,100,100,100]));
end;
procedure Run(const ARoot: String);
var
  LWrite, LReply, LMaterial, LProject, LRequest, LJob, LResult, LQueue, LRow: TJSONObject;
  LStream: TFileStream;
  LWave: TWaveFrameReader;
  LSourceHash, LHash, LFirstAudio, LFirstModel: String;
  I, J: Integer;
begin
  Check(not DirectoryExists(ARoot), 'Use a fresh isolated root');
  Check(ForceDirectories(ARoot), 'Create synthetic catalog');
  AnalyzeAuthoredStudioCapture(ARoot);
  LWrite := TJSONObject.Create;
  LMaterial := nil; LProject := nil; LRequest := nil;
  try
    LWrite.Add('capture_id', 'musical-input');
    LWrite.Add('collection_name', 'Authored control');
    LWrite.Add('title', 'Authored stereo control');
    LReply := SaveStudioCapture(ARoot, 'save-input', ARoot + '-library', LWrite);
    try LSourceHash := LReply.Strings['source_sha256']; finally LReply.Free end;
    LWrite.Clear;
    LWrite.Add('format', StudioJobWriteFormat);
    LWrite.Add('job_id', 'selected-analysis');
    LWrite.Add('kind', 'inspect_source');
    LWrite.Add('source_sha256', LSourceHash);
    LWrite.Add('start_frame', 8000);
    LWrite.Add('end_frame', 24000);
    LReply := EnqueueStudioJob(ARoot, LWrite); LReply.Free;
    Check(RunStudioWorker(ARoot, 'selected-analysis', ARoot + '-library'), 'Actual ordinary range analysis completes');
    LMaterial := ProposeStudioMaterial(ARoot, 'selected-analysis', 120, 0);
    LMaterial.Integers['part'] := 2;
    LMaterial.Strings['pitch_decision'] := 'accepted';
    LWrite.Clear;
    LWrite.Add('format', StudioProjectWriteFormat);
    LWrite.Add('project_id', 'musical-input');
    LWrite.Add('expected_revision', 0);
    LWrite.Add('name', 'Musical input control');
    LWrite.Add('style_intent', '');
    LWrite.Add('learning_mode', 'instrumental');
    LWrite.Add('sources', TJSONArray.Create);
    LWrite.Add('musical_material', LMaterial.Clone);
    for I := 1 to 2 do
    begin
      if I = 2 then
      begin
        LWrite.Integers['expected_revision'] := 1;
        LWrite.Objects['musical_material'].Strings['pitch_decision'] := 'corrected';
        for J := 0 to LWrite.Objects['musical_material'].Arrays['pattern'].Count - 1 do
        begin
          LRow := LWrite.Objects['musical_material'].Arrays['pattern'].Objects[J];
          if LRow.Strings['kind'] = 'pitch' then LRow.Integers['note'] := LRow.Integers['note'] + 1;
        end;
      end;
      FreeAndNil(LProject);
      LProject := SaveStudioProject(ARoot, LWrite);
      FreeAndNil(LRequest);
      LRequest := Generation(LProject, 'musical-generation-' + IntToStr(I));
      LReply := PrepareStudioJob(ARoot, LRequest);
      try
        Check(LReply.Integers['source_count'] = 1, 'Preflight reports the bounded reference source');
        Check(LReply.Int64s['unique_source_bytes_to_verify'] = 0, 'No gigabyte source rehash claimed');
        Check(LReply.Int64s['reference_frames_to_read'] = 16000, 'Exact selected original range to read');
      finally LReply.Free end;
      LReply := EnqueueStudioJob(ARoot, LRequest); LReply.Free;
      Check(RunStudioWorker(ARoot, LRequest.Strings['job_id'], ARoot + '-library'), 'Actual recipe job completes');
      LJob := ReadStudioJob(ARoot, LRequest.Strings['job_id']);
      try
        Check(LJob.Strings['status'] = 'completed', 'Native terminal success');
        LResult := LJob.Objects['results'];
        Check(LResult.Arrays['parts'].Count = 6, 'Actual six-part synthesis');
        Check(LResult.Arrays['graph'].Objects[0].Strings['name'] = 'musical-context', 'Paired context is actually used');
        Check(LResult.Arrays['graph'].Objects[LResult.Arrays['graph'].Count-1].Integers['graph_group'] = 2,
          'Real three conditional groups');
        Check(LResult.Objects['musical_material'].AsJSON = LProject.Objects['musical_material'].AsJSON,
          'Actual applied choices retain the immutable project recipe');
        Check((LResult.Objects['original_reference'].Int64s['start_frame'] = 8000) and
          (LResult.Objects['original_reference'].Int64s['end_frame'] = 24000), 'Nonzero original source clock retained');
        Check(LResult.Objects['original_reference'].Strings['source_sha256'] = LSourceHash, 'Original full-source receipt retained');
        LHash := LResult.Arrays['outputs'].Objects[0].Strings['wav_sha256'];
        if I = 1 then
        begin
          LFirstAudio := LHash;
          LFirstModel := LResult.Strings['model_sha256'];
        end
        else
        begin
          Check(LHash <> LFirstAudio, 'Corrected notes change the actual synthesized audio');
          Check(LResult.Strings['model_sha256'] <> LFirstModel, 'Corrected notes change real provider models');
        end;
        LStream := OpenStudioInstrumentalAudio(ARoot, LRequest.Strings['job_id'], 7, LHash);
        try
          LWave := TWaveFrameReader.Create(LStream);
          try
            Check((LWave.FrameCount = 16000) and (LWave.SampleRate = 8000) and (LWave.Channels = 2),
              'Original reference is the exact bounded source selection');
            Check(LHash <> LSourceHash, 'Excerpt identity is distinct from the full source identity');
          finally LWave.Free end;
        finally LStream.Free end;
      finally LJob.Free end;
    end;
    LQueue := ReadListeningQueue(ARoot);
    try
      Check(LQueue.Arrays['items'].Count = 2, 'Both explicit generations publish feedback');
      for I := 0 to 1 do
      begin
        LRow := LQueue.Arrays['items'].Objects[I];
        Check((LRow.Strings['kind'] = 'pair') and (LRow.Arrays['assets'].Count = 2),
          'Generated and Original reference enter one ordinary listening request');
      end;
    finally LQueue.Free end;
  finally
    LRequest.Free; LProject.Free; LMaterial.Free; LWrite.Free;
  end;
end;
begin
  try
    Check(ParamCount = 1, 'Usage: material generation FRESH_ROOT');
    Run(ExpandFileName(ParamStr(1)));
    WriteLn('PASS Studio musical generation: ', Checks, ' checks');
  except
    on E: Exception do
    begin
      WriteLn(StdErr, E.ClassName, ': ', E.Message);
      DumpExceptionBackTrace(StdErr);
      ExitCode := 1;
    end;
  end;
end.
