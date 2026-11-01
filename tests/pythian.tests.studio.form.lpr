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
program StudioFormConsumer;
{$mode delphi}
{$H+}
uses {$ifdef unix}cthreads,{$endif} Classes, SysUtils, fpjson,
  pythian.audio, pythian.music.form, pythian.music.decisions,
  pythian.tools.studio.form, pythian.tools.studio.instrumental.settings,
  pythian.tools.studio.projects, pythian.tools.studio.jobs,
  pythian.tools.studio.worker, pythian.tools.studio.decisions,
  pythian.tools.listen.assets, pythian.wave.read;

var GChecks: Integer;
procedure Check(const AValue: Boolean; const AMessage: String);
begin
  Inc(GChecks);
  if not AValue then raise EAudio.Create(AMessage);
end;

function Section(const AName: String; const ACells: Integer): TJSONObject;
begin
  Result := TJSONObject.Create(['section', AName, 'name', AName, 'cells', ACells,
    'repeat_from', -1, 'keep', TJSONArray.Create, 'energy', 50]);
end;

function CanonicalFormJSON(const AValue: TJSONData): String;
var LRows: TJSONArray;
begin
  LRows := EncodeStudioForm(DecodeStudioForm(AValue));
  try Result := LRows.AsJSON finally LRows.Free end;
end;

procedure InspectRepeat(const ARoot, AJobId: String);
var
  LJob: TJSONObject;
  LInput: TStream;
  LReader: TMusicDecisionReader;
  LChunk: TMusicDecisionChunk;
  LSource: array[0..3] of TMusicDecisionChunk;
  LChunks: Integer;
  LIndex: Integer;
  I: Integer;
  J: Integer;
begin
  LJob := ReadStudioJob(ARoot, AJobId);
  LInput := nil;
  LReader := nil;
  try
    Check(LJob.Strings['status'] = 'completed', 'The actual Studio arrangement completed');
    Check(LJob.Objects['results'].Arrays['sections'].Count = 3,
      'Actual Studio output exposes all three musical sections');
    Check((LJob.Objects['results'].Arrays['sections'].Objects[2].Int64s['start_frame'] = 768000) and
      (LJob.Objects['results'].Arrays['sections'].Objects[2].Int64s['end_frame'] = 1152000),
      'Return playback uses the actual 32 to 48 second musical interval');
    LInput := OpenStudioDecisionJournal(ARoot, LJob.Objects['results'].Objects['decisions']);
    LReader := TMusicDecisionReader.Create(LInput);
    LChunks := 0;
    while LReader.TryNext(LChunk) do
    begin
      Check(Length(LChunk.Cells) = 16, 'The actual renderer retains bounded musical chunks');
      if LChunk.FirstCell < 64 then
        LSource[LChunk.FirstCell div 16] := CopyMusicDecisionChunk(LChunk)
      else if LChunk.FirstCell >= 128 then
      begin
        LIndex := (LChunk.FirstCell - 128) div 16;
        Check((Length(LChunk.Providers) = 8) and
          (Length(LSource[LIndex].Providers) = 8), 'All actual musical providers are retained');
        for I := 0 to High(LChunk.Providers) do
        begin
          Check(LChunk.Providers[I].Key = LSource[LIndex].Providers[I].Key,
            'A return binds the real named musical provider');
          for J := 0 to 15 do
            Check(LChunk.Providers[I].Tokens[J] = LSource[LIndex].Providers[I].Tokens[J],
              'Actual WFC return tokens retain the source motif without copying PCM');
        end;
      end;
      Inc(LChunks);
    end;
    Check((LChunks = 12) and (LReader.CellCount = 192) and
      (LReader.FrameCount = 1152000), 'Actual arrangement journal covers the full 48 seconds');
  finally
    LReader.Free;
    LInput.Free;
    LJob.Free;
  end;
end;

procedure InspectExpression(const ARoot: String);
var
  LParent, LChild: TJSONObject;
  LBeforeFile, LAfterFile: TStream;
  LBeforeReader, LAfterReader: TMusicDecisionReader;
  LBefore, LAfter: TMusicDecisionChunk;
  I, J: Integer;
begin
  LParent := ReadStudioJob(ARoot, 'structure-run');
  LChild := nil;
  LBeforeFile := nil;
  LAfterFile := nil;
  LBeforeReader := nil;
  LAfterReader := nil;
  try
    LChild := ReadStudioJob(ARoot, 'structure-notes');
    for J := 0 to 5 do
      if J <> 2 then
        Check(LParent.Objects['results'].Arrays['parts'].Objects[J].Strings['wav_sha256'] =
          LChild.Objects['results'].Arrays['parts'].Objects[J].Strings['wav_sha256'],
          'Each unselected actual instrument retains exact PCM with section expression');
    Check(LParent.Objects['results'].Objects['decisions'].Integers['record_version'] = 2,
      'Publication identifies explicit performance records within the framed journal');
    LBeforeFile := OpenStudioDecisionJournal(ARoot, LParent.Objects['results'].Objects['decisions']);
    LAfterFile := OpenStudioDecisionJournal(ARoot, LChild.Objects['results'].Objects['decisions']);
    LBeforeReader := TMusicDecisionReader.Create(LBeforeFile);
    LAfterReader := TMusicDecisionReader.Create(LAfterFile);
    while LBeforeReader.TryNext(LBefore) do
    begin
      Check(LAfterReader.TryNext(LAfter) and (LAfter.Version = 2),
        'The actual note edit retains every performed-expression chunk');
      for I := 0 to High(LBefore.Cells) do
        for J := 0 to High(LBefore.Cells[I].Expression) do
          Check(LBefore.Cells[I].Expression[J].VelocityPercent =
            LAfter.Cells[I].Expression[J].VelocityPercent,
            'Changing actual notes preserves every original section and role expression');
    end;
    Check(LAfterReader.AtEnd, 'Retained expression keeps the exact original musical extent');
  finally
    LAfterReader.Free;
    LBeforeReader.Free;
    LAfterFile.Free;
    LBeforeFile.Free;
    LChild.Free;
    LParent.Free;
  end;
end;

procedure Followups(const ARoot: String);
var
  LParent, LWrite, LJob, LEdit, LControls: TJSONObject;
  LParts, LRows: TJSONArray;
  I: Integer;
begin
  LParent := ReadStudioJob(ARoot, 'structure-run');
  LWrite := nil;
  try
    LWrite := TJSONObject.Create(['format', StudioJobWriteFormat,
      'job_id', 'structure-sounds', 'kind', 'instrumental_reperform',
      'project_id', 'structure', 'project_revision', LParent.Objects['results'].Int64s['project_revision'],
      'project_snapshot_sha256', LParent.Objects['results'].Strings['project_snapshot_sha256'],
      'parent_job_id', 'structure-run',
      'parent_plan_sha256', LParent.Objects['results'].Strings['plan_sha256'],
      'instruments', TJSONArray.Create(['sine', 'triangle', 'square'])]);
    LJob := EnqueueStudioJob(ARoot, LWrite);
    LJob.Free;
    Check(RunStudioWorker(ARoot, 'structure-sounds', ARoot + '-absent-library'),
      'Authored form sound changes replay its saved score without recordings or solving');
    LJob := ReadStudioJob(ARoot, 'structure-sounds');
    try
      Check(LJob.Objects['results'].Objects['decisions'].AsJSON =
        LParent.Objects['results'].Objects['decisions'].AsJSON, 'Sound changes preserve the exact musical journal');
      Check(LJob.Objects['results'].Arrays['outputs'].Objects[0].Strings['wav_sha256'] <>
        LParent.Objects['results'].Arrays['outputs'].Objects[0].Strings['wav_sha256'],
        'Changed sound produces different actual audio');
    finally LJob.Free end;
    FreeAndNil(LWrite);
    LParts := TJSONArray.Create([False, False, True, False, False, False]);
    LRows := TJSONArray.Create;
    for I := 0 to 2 do LRows.Add(TJSONObject.Create(['minimum_pitch', 0, 'maximum_pitch', 127,
      'activity_bias', 0, 'velocity_percent', 100, 'gate_percent', 100]));
    LControls := TJSONObject.Create(['guide', False, 'tonic_bias', 0, 'parts', LRows]);
    LEdit := TJSONObject.Create(['start_frame', 48000, 'end_frame', 144000,
      'parts', LParts, 'harmony', False, 'rhythm', False, 'tonic', 0,
      'controls', LControls, 'seed', 17]);
    LWrite := TJSONObject.Create(['format', StudioJobWriteFormat,
      'job_id', 'structure-notes', 'kind', 'instrumental_regenerate',
      'project_id', 'structure', 'project_revision', LParent.Objects['results'].Int64s['project_revision'],
      'project_snapshot_sha256', LParent.Objects['results'].Strings['project_snapshot_sha256'],
      'parent_job_id', 'structure-run',
      'parent_plan_sha256', LParent.Objects['results'].Strings['plan_sha256'], 'note_edit', LEdit]);
    LJob := EnqueueStudioJob(ARoot, LWrite);
    LJob.Free;
    Check(RunStudioWorker(ARoot, 'structure-notes', ARoot + '-absent-library'),
      'Existing passage editor consumes the actual no-context musical models');
    LJob := ReadStudioJob(ARoot, 'structure-notes');
    try
      Check(LJob.Objects['results'].Objects['edit_report'].Int64s['changed_cells'] > 0,
        'Targeted regeneration changes actual musical cells');
      Check(LJob.Objects['results'].Objects['edit_report'].Int64s['actual_start_frame'] = 48000,
        'Targeted section change begins at the native section boundary');
      Check(LJob.Objects['results'].Objects['edit_report'].Int64s['actual_end_frame'] = 144000,
        'Targeted section change ends at the native section boundary');
    finally LJob.Free end;
  finally
    LWrite.Free;
    LParent.Free;
  end;
end;

procedure RepairEdit(const ARoot, AParentId, AFailedId, ANewId: String);
var
  LParent: TJSONObject;
  LFailed: TJSONObject;
  LRequest: TJSONObject;
  LWrite: TJSONObject;
  LJob: TJSONObject;
  LParentInput: TStream;
  LChildInput: TStream;
  LParentReader: TMusicDecisionReader;
  LChildReader: TMusicDecisionReader;
  LBefore: TMusicDecisionChunk;
  LAfter: TMusicDecisionChunk;
  LFrame: Int64;
  LStart: Int64;
  LEnd: Int64;
  LChanges: Integer;
  I: Integer;
  J: Integer;
  LInside: Boolean;
begin
  LParent := ReadStudioJob(ARoot, AParentId);
  LFailed := ReadStudioJob(ARoot, AFailedId);
  LRequest := ReadStudioJobRequest(ARoot, AFailedId);
  LWrite := nil;
  LJob := nil;
  LParentInput := nil;
  LChildInput := nil;
  LParentReader := nil;
  LChildReader := nil;
  try
    Check(LFailed.Strings['status'] = 'failed', 'Keep the actual failed edit as evidence');
    LWrite := TJSONObject.Create(['format', StudioJobWriteFormat,
      'job_id', ANewId, 'kind', 'instrumental_regenerate',
      'project_id', LParent.Objects['results'].Strings['project_id'],
      'project_revision', LParent.Objects['results'].Int64s['project_revision'],
      'project_snapshot_sha256', LParent.Objects['results'].Strings['project_snapshot_sha256'],
      'parent_job_id', AParentId,
      'parent_plan_sha256', LParent.Objects['results'].Strings['plan_sha256'],
      'note_edit', LRequest.Objects['note_edit'].Clone]);
    LJob := EnqueueStudioJob(ARoot, LWrite);
    FreeAndNil(LJob);
    Check(RunStudioWorker(ARoot, ANewId, ARoot + '-no-recordings'),
      'The exact failed section, controls and seed complete through the shared bounded editor');
    LJob := ReadStudioJob(ARoot, ANewId);
    Check(LJob.Strings['status'] = 'completed', 'The actual repaired native job completes');
    Check(LJob.Objects['results'].Objects['note_edit'].AsJSON = LRequest.Objects['note_edit'].AsJSON,
      'Repair does not sweep seeds, change the range or relax the requested parts');
    Check(LJob.Objects['results'].Arrays['sections'].AsJSON =
      LParent.Objects['results'].Arrays['sections'].AsJSON, 'Repaired version retains the actual arrangement');
    LStart := LRequest.Objects['note_edit'].Int64s['start_frame'];
    LEnd := LRequest.Objects['note_edit'].Int64s['end_frame'];
    LParentInput := OpenStudioDecisionJournal(ARoot, LParent.Objects['results'].Objects['decisions']);
    LChildInput := OpenStudioDecisionJournal(ARoot, LJob.Objects['results'].Objects['decisions']);
    LParentReader := TMusicDecisionReader.Create(LParentInput);
    LChildReader := TMusicDecisionReader.Create(LChildInput);
    LChanges := 0;
    while LParentReader.TryNext(LBefore) do
    begin
      Check(LChildReader.TryNext(LAfter), 'Repaired journal retains every original chunk');
      Check((LBefore.FirstCell = LAfter.FirstCell) and (LBefore.StartFrame = LAfter.StartFrame) and
        (Length(LBefore.Cells) = Length(LAfter.Cells)), 'Prefix publication preserves original journal clocks');
      LFrame := LBefore.StartFrame;
      for I := 0 to High(LBefore.Cells) do
      begin
        LInside := (LFrame < LEnd) and (LFrame + LBefore.Cells[I].FrameCount > LStart);
        if not SameMusicDecisionFrame(LBefore.Cells[I].Parts, LAfter.Cells[I].Parts) then
        begin
          Inc(LChanges);
          Check(LInside, 'No actual musical decision changes outside the requested section');
        end;
        for J := 0 to High(LBefore.Providers) do
          if not LInside or (LBefore.Providers[J].Key <> 'lead') then
            Check((LBefore.Providers[J].Tokens[I] = LAfter.Providers[J].Tokens[I]) and
              (LBefore.Providers[J].States[I] = LAfter.Providers[J].States[I]),
              'Other providers and outside-range latent states remain exact');
        Inc(LFrame, LBefore.Cells[I].FrameCount);
      end;
    end;
    Check(not LChildReader.TryNext(LAfter), 'Repaired result adds no hidden musical cells');
    Check((LChanges > 0) and
      (LChanges = LJob.Objects['results'].Objects['edit_report'].Int64s['changed_cells']),
      'Change report counts only actual published-prefix changes, not provisional future notes');
    for I := 0 to 5 do
      if I <> 2 then
        Check(LJob.Objects['results'].Arrays['parts'].Objects[I].Strings['wav_sha256'] =
          LParent.Objects['results'].Arrays['parts'].Objects[I].Strings['wav_sha256'],
          'All five unselected actual PCM stems stay identical');
    Check(LJob.Objects['results'].Arrays['parts'].Objects[2].Strings['wav_sha256'] <>
      LParent.Objects['results'].Arrays['parts'].Objects[2].Strings['wav_sha256'],
      'The requested Lead changes in the actual synthesized output');
    FreeAndNil(LJob);
    LJob := ReadStudioJob(ARoot, AFailedId);
    Check(LJob.AsJSON = LFailed.AsJSON, 'The original failed request and evidence stay unchanged');
  finally
    LChildReader.Free;
    LParentReader.Free;
    LChildInput.Free;
    LParentInput.Free;
    LJob.Free;
    LWrite.Free;
    LRequest.Free;
    LFailed.Free;
    LParent.Free;
  end;
end;

procedure Run(const ARoot: String);
var
  LSettings, LWrite, LProject, LRead, LRequest, LJob, LMeta: TJSONObject;
  LRows, LEncoded: TJSONArray;
  LForm: TMusicForm;
  LFile: TStream;
  LReader: TMusicDecisionReader;
  LChunk: TMusicDecisionChunk;
  LCells, LChunks: Integer;
  LRaised: Boolean;
begin
  Check(not DirectoryExists(ARoot), 'Use a fresh isolated form catalog');
  ForceDirectories(ARoot);
  LRows := TJSONArray.Create([Section('Opening', 8), Section('Contrast', 16)]);
  LRows.Objects[0].Integers['energy'] := 0;
  LRows.Objects[1].Integers['energy'] := 100;
  LRows.Objects[0].Add('density', 0);
  LRows.Objects[1].Add('density', 100);
  LSettings := TJSONObject.Create(['tempo_bpm', 120, 'tonic', 0, 'cells', 24,
    'instruments', TJSONArray.Create(['saw', 'triangle', 'square']),
    'levels', TJSONArray.Create([100, 100, 100, 100, 100, 100]), 'form', LRows]);
  LWrite := TJSONObject.Create(['format', StudioProjectWriteFormat,
    'project_id', 'structure', 'expected_revision', 0, 'name', 'Unequal musical sections',
    'style_intent', '', 'learning_mode', 'instrumental', 'sources', TJSONArray.Create,
    'instrumental', LSettings]);
  LProject := nil;
  LRequest := nil;
  LJob := nil;
  LMeta := nil;
  LFile := nil;
  LReader := nil;
  try
    LForm := DecodeStudioForm(LRows);
    Check((StudioFormCells(LForm) = 24) and (StudioFormFrames(LForm, 120, 8000) = 48000),
      'Form transport reuses the primary cell and rational frame clocks');
    Check((LForm[0].DensityOffset = -50) and (LForm[1].DensityOffset = 50),
      'Native form transport retains the actual sparse/busy section controls');
    LRows.Objects[0].Integers['density'] := 101;
    LRaised := False;
    try LForm := DecodeStudioForm(LRows);
    except on E: EAudio do LRaised := True end;
    Check(LRaised, 'Out-of-range section density rejects at the native boundary');
    LRows.Objects[0].Floats['density'] := 0.5;
    LRaised := False;
    try LForm := DecodeStudioForm(LRows);
    except on E: EAudio do LRaised := True end;
    Check(LRaised, 'Fractional section density rejects at the native boundary');
    LRows.Objects[0].Integers['density'] := 50;
    LEncoded := EncodeStudioForm(DecodeStudioForm(LRows));
    try
      Check(LEncoded.Objects[0].Find('density') = nil,
        'Neutral density preserves the canonical signed form identity');
    finally LEncoded.Free end;
    LRows.Objects[0].Integers['density'] := 0;
    LRows.Objects[0].Delete('energy');
    LForm := DecodeStudioForm(LRows);
    Check(LForm[0].EnergyOffset = 0, 'Historical five-field forms remain explicitly neutral');
    LRows.Objects[0].Add('energy', 101);
    LRaised := False;
    try LForm := DecodeStudioForm(LRows);
    except on E: EAudio do LRaised := True end;
    Check(LRaised, 'The native boundary refuses an out-of-range section energy');
    LRows.Objects[0].Integers['energy'] := 0;
    LRows.Objects[0].Integers['repeat_from'] := 1;
    LRaised := False;
    try LForm := DecodeStudioForm(LRows);
    except on E: EAudio do LRaised := True end;
    Check(LRaised, 'A future motif cannot authorize a section repeat');
    LRows.Objects[0].Integers['repeat_from'] := -1;
    LProject := SaveStudioProject(ARoot, LWrite);
    LRead := ReadStudioProject(ARoot, 'structure');
    try
      LForm := DecodeStudioForm(LRead.Objects['instrumental'].Arrays['form']);
      Check((LForm[0].DensityOffset = -50) and (LForm[1].DensityOffset = 50) and
        (LForm[0].EnergyOffset = -50) and (LForm[1].EnergyOffset = 50),
        'Signed save/reopen preserves the independent density and energy values');
      { Invalid-input probes reorder keys and can change JSON number subtypes.
        Compare the public canonical representation, not the mutable probe bytes. }
      Check(LRead.Objects['instrumental'].Arrays['form'].AsJSON = CanonicalFormJSON(LRows),
        'Native save/reopen retains the actual arrangement');
    finally LRead.Free end;
    LRequest := TJSONObject.Create(['format', StudioJobWriteFormat,
      'job_id', 'structure-run', 'kind', 'instrumental_generate',
      'project_id', 'structure', 'project_revision', 1,
      'project_snapshot_sha256', LProject.Strings['snapshot_sha256'],
      'seeds', TJSONArray.Create([731]), 'instrumental', LSettings.Clone]);
    LJob := EnqueueStudioJob(ARoot, LRequest);
    FreeAndNil(LJob);
    Check(RunStudioWorker(ARoot, 'structure-run', ARoot + '-absent-library'),
      'Ordinary native worker performs the authored form without recordings');
    LJob := ReadStudioJob(ARoot, 'structure-run');
    Check(LJob.Strings['status'] = 'completed', 'Structured native job completes');
    Check(LJob.Objects['results'].Strings['runtime'] = 'bounded_instrumental_stream',
      'Structured job reuses the primary bounded performer and publication');
    Check(LJob.Objects['results'].Arrays['parts'].Count = 6, 'Actual output exposes all six parts');
    Check(CanonicalFormJSON(LJob.Objects['results'].Objects['settings'].Arrays['form']) =
      CanonicalFormJSON(LRows),
      'Completed result binds the saved arrangement');
    Check((LJob.Objects['results'].Arrays['sections'].Objects[1].Int64s['start_frame'] = 48000) and
      (LJob.Objects['results'].Arrays['sections'].Objects[1].Int64s['end_frame'] = 144000),
      'Playback and targeted changes share exact native section clocks');
    LMeta := ReadStudioJSON(StudioJobDirectory(ARoot, 'structure-run') + '/instrumental-stream-completed.json');
    Check((LMeta.Arrays['models'].Count = 8) and (LMeta.Strings['context_binding'] = 'none'),
      'Replay metadata records actual providers without inventing a learned context');
    LFile := OpenStudioDecisionJournal(ARoot, LJob.Objects['results'].Objects['decisions']);
    LReader := TMusicDecisionReader.Create(LFile);
    LCells := 0;
    LChunks := 0;
    while LReader.TryNext(LChunk) do
    begin
      Inc(LCells, Length(LChunk.Cells));
      Inc(LChunks);
      Check(Length(LChunk.Cells) = 8, 'Saved musical chunks respect both real section boundaries');
      Check((LChunk.Version = MusicDecisionExpressionVersion) and
        (LChunk.Cells[0].Expression[0].VelocityPercent =
          50 + 100 * Ord(LChunk.FirstCell >= 8)),
        'The actual native worker records each section performance strength');
    end;
    Check((LCells = 24) and (LChunks = 3) and (LReader.FrameCount = 144000),
      'Saved actual decisions cover the exact six-second musical clock');
  finally
    LReader.Free;
    LFile.Free;
    LMeta.Free;
    LJob.Free;
    LRequest.Free;
    LProject.Free;
    LWrite.Free;
  end;
end;

begin
  try
    if (ParamCount = 5) and (ParamStr(1) = '--repair-edit') then
      RepairEdit(ExpandFileName(ParamStr(2)), ParamStr(3), ParamStr(4), ParamStr(5))
    else if (ParamCount = 3) and (ParamStr(1) = '--inspect-repeat') then
      InspectRepeat(ExpandFileName(ParamStr(2)), ParamStr(3))
    else if (ParamCount = 2) and (ParamStr(1) = '--inspect-expression') then
      InspectExpression(ExpandFileName(ParamStr(2)))
    else if (ParamCount = 2) and (ParamStr(1) = '--followup') then
      Followups(ExpandFileName(ParamStr(2)))
    else
    begin
      if ParamCount <> 1 then raise EAudio.Create('Usage: Studio form checks FRESH_ROOT');
      Run(ExpandFileName(ParamStr(1)));
      Followups(ExpandFileName(ParamStr(1)));
      InspectExpression(ExpandFileName(ParamStr(1)));
    end;
    WriteLn('PASS ', GChecks, ' Studio form checks');
  except on E: Exception do
  begin
    WriteLn('FAIL: ', E.ClassName, ': ', E.Message);
    ExitCode := 1;
  end end;
end.
