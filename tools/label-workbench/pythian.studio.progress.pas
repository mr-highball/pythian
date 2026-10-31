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
unit pythian.studio.progress;

{$mode delphi}
{$H+}

interface

uses JS, Web, SysUtils, Math, pythian.studio.sources;

function StudioStageText(const AStage: String): String;
function StudioByteSize(const ABytes: Double): String;
procedure DrawStudioProgress(const AParent: TJSElement; const AJob: TJSObject;
  const ACompact: Boolean = False);

implementation

function StudioByteSize(const ABytes: Double): String;
begin
  if ABytes >= 1073741824 then Result := FormatFloat('0.00', ABytes / 1073741824) + ' GiB'
  else if ABytes >= 1048576 then Result := FormatFloat('0.0', ABytes / 1048576) + ' MiB'
  else if ABytes >= 1024 then Result := FormatFloat('0.0', ABytes / 1024) + ' KiB'
  else Result := IntToStr(Trunc(ABytes)) + ' bytes';
end;

function StudioStageText(const AStage: String): String;
begin
  if (Copy(AStage, 1, 9) = 'playlist_') then
  begin
    if Pos('learn_music', AStage) > 0 then Result := 'Learn musical ideas'
    else if Pos('verify', AStage) > 0 then Result := 'Check your recording'
    else if Pos('prepare', AStage) > 0 then Result := 'Open your selected music'
    else if Pos('cache', AStage) > 0 then Result := 'Reuse saved analysis'
    else Result := 'Analyze your selected music';
    Exit;
  end;
  if (Copy(AStage, 1, 15) = 'musical_corpus_') or
    (Copy(AStage, 1, 17) = 'musical_proposal_') or (Copy(AStage, 1, 13) = 'wfc_weighted_') then
  begin
    Result := 'Learn musical ideas';
    Exit;
  end;
  if (Copy(AStage, 1, 4) = 'wfc_') then
  begin
    if Pos('search', AStage) > 0 then Result := 'Find the next musical pattern'
    else if (Pos('proof', AStage) > 0) or (Pos('commit', AStage) > 0) or
      (Pos('capture', AStage) > 0) then Result := 'Check the musical pattern'
    else Result := 'Prepare musical patterns';
    Exit;
  end;
  if Copy(AStage, 1, 9) = 'sequence_' then
  begin
    Result := 'Arrange the next musical passage';
    Exit;
  end;
  case AStage of
    'checking_selected_metadata', 'rechecking_selected_metadata': Result := 'Open selected music';
    'instrumental_prepare': Result := '1 · Prepare musical material';
    'instrumental_reference': Result := 'Prepare original reference';
    'context_prepare_masks': Result := '2 · Connect musical context and selected part';
    'context_validate_witness': Result := '2 · Check the shared musical pattern';
    'musical_control_tokens', 'musical_control_cells', 'musical_controls_ready':
      Result := '2 · Apply musical limits and preferences';
    'musical_expression': Result := '2 · Shape note strength and length';
    'instrumental_render': Result := '3 · Synthesize mix and parts';
    'instrumental_publish': Result := '4 · Save music for review';
    'instrumental_ready', 'instrumental_plan', 'percussion_ready', 'percussion_instruments':
      Result := '2 · Plan instruments and drums';
    'audio_pull', 'audio_pull_ready': Result := 'Render the next audio block';
    'journal_render_window': Result := 'Prepare the audio window';
    'journal_render_preflight': Result := 'Check source passages';
    'journal_render_source': Result := 'Read a source passage';
    'journal_render_mix': Result := 'Mix a source passage';
    'journal_render_flush': Result := 'Prepare output frames';
    'journal_render_output': Result := 'Output generated audio';
    'journal_render_grains': Result := 'Render source passages';
    'journal_render_complete': Result := 'Finish rendering audio';
    'journal_open': Result := 'Open saved sound observations';
    'journal_scan': Result := 'Check saved sound observations';
    'journal_validate': Result := 'Check sound measurements';
    'journal_encode', 'journal_append_ready': Result := 'Prepare sound observations to save';
    'journal_decode', 'journal_read': Result := 'Read sound observations';
    'journal_commit': Result := 'Save sound observations';
    'journal_recover': Result := 'Recover saved sound observations';
    'read_bytes': Result := 'Read saved data';
    'write_bytes': Result := 'Write saved data';
    'queued': Result := 'Waiting to start';
    'preflight', 'verify_sources': Result := 'Check recordings';
    'find_saved_model': Result := 'Check saved learning';
    'analyze_selected_ranges': Result := 'Analyze selected audio';
    'learn_raw_palette': Result := 'Learn sounds';
    'learn_wfc_model': Result := 'Learn patterns';
    'select_sound_examples': Result := 'Choose sound examples';
    'training_segments', 'training_overlap_pairs', 'training_reader_ready',
    'training_partition_entries', 'training_partition_pairs', 'training_partition_ready':
      Result := 'Check training selections';
    'candidate_observations', 'candidate_restore_slots', 'candidate_pool_ready':
      Result := 'Choose sound examples';
    'successor_sources', 'successor_observations', 'successor_index_ready':
      Result := 'Connect neighboring sounds';
    'context_sources', 'context_anchor_slots', 'context_sort_comparisons',
    'context_observations', 'context_windows', 'context_restore_visits', 'context_pool_ready':
      Result := 'Prepare source passages';
    'journal_wfc_visits', 'journal_wfc_observations', 'journal_wfc_model_ready':
      Result := 'Learn patterns';
    'journal_select_prepare', 'journal_successor_compatibility':
      Result := 'Prepare source choices';
    'journal_select_visits': Result := 'Choose the next source passage';
    'check_learned_model': Result := 'Check learned patterns';
    'verify_model_sources': Result := 'Recheck recordings before saving learning';
    'save_learned_model': Result := 'Save learning';
    'reload_verified_model': Result := 'Use saved learning';
    'find_feature_journals': Result := 'Find saved sound observations';
    'prepare_source_continuity': Result := 'Prepare source continuity';
    'prepare_audio': Result := 'Prepare selected audio';
    'prepare_hash_bytes': Result := 'Check prepared audio';
    'prepare_verify_bytes': Result := 'Verify prepared audio';
    'generate_auditions': Result := 'Generate music';
    'streaming': Result := 'Generate & play';
    'verify_output_sources': Result := 'Recheck recordings before saving results';
    'publish_listening': Result := 'Save results for review';
    'completed': Result := 'Complete';
    'failed': Result := 'Could not finish';
    'runtime_budget', 'preparation_timeout': Result := 'Time limit reached';
    'client_disconnected': Result := 'Playback connection lost';
    'interrupted': Result := 'Interrupted';
    'cancelled': Result := 'Cancelled';
    'cancelled_before_start': Result := 'Cancelled before starting';
    'verify_audio_bytes': Result := 'Check data integrity';
    'read_audio': Result := 'Read selected audio';
    'analyze_audio', 'inspect_temporary_audio': Result := 'Analyze audio';
    'inspect_levels': Result := 'Measure volume';
    'resample_audio': Result := 'Prepare audio for pitch detection';
    'estimate_pitch', 'preview_pitch': Result := 'Find pitches';
    'musical_pitch_channel': Result := 'Check channel pitches';
    'locate_onsets': Result := 'Find sound starts';
    'estimate_beats': Result := 'Find beat candidates';
    'prepare_learning': Result := 'Prepare sound examples';
    'encode_sounds': Result := 'Match sounds';
    'choose_examples': Result := 'Choose sound examples';
    'learn_sounds': Result := 'Learn sounds';
    'render_effects': Result := 'Apply effects';
    'render_note_preview': Result := 'Create note preview';
    'import_audio': Result := 'Add audio to catalog';
    'import_hash_bytes': Result := 'Check audio to add';
    'import_copy_bytes': Result := 'Copy audio to catalog';
    'import_verify_bytes': Result := 'Verify catalog audio';
    'import_items': Result := 'Add recordings to catalog';
    'copy_audio': Result := 'Copy audio';
    'save_capture', 'save_derived_clip': Result := 'Save to collection';
  else Result := 'Preparing music';
  end;
end;

function StepNumber(const AStage: String): Integer;
begin
  case AStage of
    'preflight', 'verify_sources': Result := 1;
    'find_saved_model', 'analyze_selected_ranges', 'prepare_audio',
      'prepare_hash_bytes', 'prepare_verify_bytes': Result := 2;
    'learn_raw_palette': Result := 3;
    'learn_wfc_model', 'select_sound_examples', 'check_learned_model',
      'verify_model_sources', 'save_learned_model': Result := 4;
    'generate_auditions', 'streaming': Result := 5;
    'verify_output_sources', 'publish_listening': Result := 6;
  else Result := 0;
  end;
end;

function Add(const AParent: TJSElement; const ATag, AText: String): TJSElement;
begin
  Result := document.createElement(ATag);
  Result.textContent := AText;
  AParent.appendChild(Result);
end;

procedure DrawStudioProgress(const AParent: TJSElement; const AJob: TJSObject;
  const ACompact: Boolean);
var
  LRoot, LBar, LLabel: TJSElement;
  LStage, LStatus, LText, LUnit, LDetail: String;
  LDone, LTotal: Double;
  LStep, LPass: Integer;
begin
  LStage := StudioText(AJob, 'stage');
  LStatus := StudioText(AJob, 'status');
  if LStatus = '' then LStatus := StudioText(AJob, 'job_status');
  if ACompact and ((LStatus = 'completed') or (LStatus = 'cancelled') or
    (LStatus = 'failed')) then Exit;
  LRoot := Add(AParent, 'div', '');
  LRoot.className := 'learning-progress';
  LStep := StepNumber(LStage);
  LText := StudioStageText(LStage);
  if ACompact then
  begin
    LStep := 0;
    if Pos(' · ', LText) = 2 then Delete(LText, 1, 4);
  end;
  if LStatus = 'failed' then
  begin
    LStep := 0;
    if (LStage <> 'runtime_budget') and (LStage <> 'preparation_timeout') and
      (LStage <> 'client_disconnected') then LText := 'Could not finish';
  end;
  if LStatus = 'cancelled' then
  begin
    LStep := 0;
    LText := 'Cancelled';
  end;
  if LStep > 0 then LText := 'Step ' + IntToStr(LStep) + ' of 6 · ' + LText;
  LLabel := Add(LRoot, 'p', LText);
  LLabel.className := 'progress-heading';
  if (LStatus = 'failed') or (LStatus = 'cancelled') then Exit;
  if LStatus = 'completed' then
  begin
    if (StudioText(AJob, 'kind') = 'train_generate') or
      (StudioText(AJob, 'kind') = 'stream_generate') then
      Add(LRoot, 'p', 'Ready to review.');
    Exit;
  end;
  if (LStage = 'reload_verified_model') then
  begin
    Add(LRoot, 'p', 'Saved learning is ready. Skipping analysis and learning.');
    Exit;
  end;
  LPass := Trunc(StudioNumber(AJob, 'progress_pass'));
  LDone := StudioNumber(AJob, 'done');
  LTotal := StudioNumber(AJob, 'total');
  LUnit := StudioText(AJob, 'progress_unit');
  LBar := Add(LRoot, 'progress', '');
  LBar.setAttribute('aria-label', StudioStageText(LStage) + ' progress');
  if (LTotal > 0) and (LUnit <> '') then
  begin
    LBar.setAttribute('max', FloatToStr(LTotal));
    LBar.setAttribute('value', FloatToStr(Min(LTotal, Max(0, LDone))));
    LText := IntToStr(Trunc(100 * LDone / LTotal)) + '%';
    if LPass > 0 then LText := 'Pass ' + IntToStr(LPass) + ' · ' + LText;
    if LUnit = 'bytes' then
    begin
      LDetail := StudioByteSize(LDone) + ' / ' + StudioByteSize(LTotal);
      if (LStage = 'verify_sources') or (LStage = 'verify_model_sources') or
        (LStage = 'verify_output_sources') then
        LDetail := LDetail + ' of original file'
      else LDetail := LDetail + ' of data';
    end
    else if LUnit = 'observations' then
      LDetail := IntToStr(Trunc(LDone)) + ' / ' + IntToStr(Trunc(LTotal)) + ' audio windows'
    else if LUnit = 'frames' then
      if (LStage = 'generate_auditions') or (LStage = 'streaming') then
        LDetail := 'of requested audio generated'
      else LDetail := IntToStr(Trunc(LDone)) + ' / ' + IntToStr(Trunc(LTotal)) + ' audio frames'
    else LDetail := IntToStr(Trunc(LDone)) + ' / ' + IntToStr(Trunc(LTotal));
    LBar.setAttribute('aria-valuetext', LText + ' · ' + LDetail);
    if ACompact then
    begin
      Add(LRoot, 'p', LText + ' of this step');
      Exit;
    end;
    Add(LRoot, 'p', LText + ' · ' + LDetail);
    if (LUnit = 'bytes') and ((LStage = 'verify_sources') or
      (LStage = 'verify_model_sources') or (LStage = 'verify_output_sources')) then
      Add(LRoot, 'small', 'Checking the full file identity. Only your selected audio is learned.');
    if LPass > 0 then
      Add(LRoot, 'small', 'This bar shows the current operation and pass.');
    if LDone = LTotal then Add(LRoot, 'small', 'Finishing this step…');
  end
  else
  begin
    if LStatus = 'queued' then LText := 'Starts when the worker is free.'
    else if not ACompact and (LUnit <> '') and (LDone > 0) then
    begin
      if LUnit = 'bytes' then LText := StudioByteSize(LDone) + ' checked'
      else if LUnit = 'frames' then LText := IntToStr(Trunc(LDone)) + ' audio frames processed'
      else if LUnit = 'observations' then LText := IntToStr(Trunc(LDone)) + ' audio windows checked'
      else LText := IntToStr(Trunc(LDone)) + ' work steps checked';
      if LPass > 0 then LText := 'Pass ' + IntToStr(LPass) + ' · ' + LText;
      LBar.setAttribute('aria-valuetext', LText + '. Total not yet known.');
    end
    else LText := 'Working…';
    Add(LRoot, 'p', LText);
  end;
end;

end.
