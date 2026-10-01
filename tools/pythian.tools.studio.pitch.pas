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
unit pythian.tools.studio.pitch;

{$mode delphi}
{$H+}

interface

uses Classes, fpjson, pythian.tools.studio.effects;

function PreviewStudioPitch(const ACatalogRoot, AJobId: String;
  const ARequest: TJSONObject; const ACheck: TStudioEffectCheck = nil): TJSONObject;
function OpenStudioPitchArtifact(const ACatalogRoot, AJobId, AKind: String;
  out AHash: String): TFileStream;
function SaveStudioExplorationFeedback(const ACatalogRoot: String;
  const AWrite: TJSONObject): TJSONObject;

implementation

uses SysUtils, Math,
  pythian.audio, pythian.hash, pythian.wave.read, pythian.wave.stream,
  pythian.resample, pythian.pitch, pythian.pitch.track,
  pythian.music, pythian.music.render, pythian.time, pythian.synth, pythian.oscillator,
  pythian.midi.smf, pythian.midi.export,
  pythian.tools.studio.capture, pythian.tools.studio.jobs;

procedure Need(const ACondition: Boolean; const AMessage: String);
begin
  if not ACondition then
  begin
    raise EAudio.Create(AMessage);
  end;
end;

function FileHash(const APath: String): String;
var
  LStream: TFileStream;
begin
  LStream := TFileStream.Create(APath, fmOpenRead or fmShareDenyWrite);
  try
    Result := Sha256Stream(LStream, LStream.Size);
  finally
    LStream.Free;
  end;
end;

function PreviewStudioPitch(const ACatalogRoot, AJobId: String;
  const ARequest: TJSONObject; const ACheck: TStudioEffectCheck): TJSONObject;
var
  LStream: TFileStream;
  LOutput: TFileStream;
  LWave: TWaveFrameReader;
  LOriginal: TAudioClip;
  LAnalysis: TAudioClip;
  LPreview: TAudioClip;
  LTrack: TPitchTrack;
  LClock: TTempoMap;
  LSequence: TNoteSequence;
  LOptions: TPitchTrackOptions;
  LSpans: TPitchSpans;
  LTimed: TTimedPitchSpans;
  LSamples: TAudioSamples;
  LMono: TAudioSamples;
  LGates: TNoteGates;
  LBytes: TMidiBytes;
  LRenderReport: TNoteRenderReport;
  LVoice: TSynthVoice;
  LHash: String;
  LSourcePath: String;
  LPath: String;
  LFrames: Integer;
  LPosition: Integer;
  LCount: Integer;
  LIndex: Integer;
  LChannel: Integer;
  LTempo: Integer;
  LLengthTicks: Integer;
  LRows: TJSONArray;
  LRow: TJSONObject;
begin
  Need(ARequest.Get('mode', '') = 'single_pitch', 'Choose the single-pitch preview');
  LChannel := ARequest.Get('channel', -1);
  LTempo := ARequest.Get('tempo_bpm', 0);
  Need((LChannel in [0, 1]) and (LTempo >= 40) and (LTempo <= 240), 'Preview controls exceed bounds');
  LStream := nil;
  LOutput := nil;
  LWave := nil;
  LOriginal := nil;
  LAnalysis := nil;
  LPreview := nil;
  LTrack := nil;
  LClock := nil;
  LSequence := nil;
  Result := nil;
  LPath := StudioJobDirectory(ACatalogRoot, AJobId);
  try
    if Assigned(ACheck) then
    begin
      ACheck;
    end;
    LStream := OpenStudioCapture(ACatalogRoot, ARequest.Strings['capture_id'], LHash, LSourcePath);
    Need(Sha256Stream(LStream, LStream.Size) = LHash, 'Pitch source content changed');
    LStream.Position := 0;
    LWave := TWaveFrameReader.Create(LStream);
    Need(LChannel < LWave.Channels, 'This recording does not have that channel');
    LFrames := Integer(Min(LWave.FrameCount, Int64(LWave.SampleRate) * 8));
    SetLength(LMono, LFrames);
    LPosition := 0;
    while LPosition < LFrames do
    begin
      if Assigned(ACheck) then
      begin
        ACheck;
      end;
      LCount := Min(4096, LFrames - LPosition);
      LSamples := LWave.ReadFrames(LCount);
      Need(Length(LSamples) = LCount * LWave.Channels, 'Incomplete pitch source');
      for LIndex := 0 to LCount - 1 do
      begin
        LMono[LPosition + LIndex] := LSamples[LIndex * LWave.Channels + LChannel];
      end;
      Inc(LPosition, LCount);
    end;
    LOriginal := TAudioClip.Create(LWave.SampleRate, 1, LMono);
    LAnalysis := ResampleClip(LOriginal, 8000);
    if Assigned(ACheck) then
    begin
      ACheck;
    end;
    LOptions := DefaultPitchTrackOptions(8000);
    LTrack := TPitchTrack.Create(LAnalysis, 0, LOptions);
    LTempo := Round(60000000 / LTempo);
    LLengthTicks := Ceil(LAnalysis.FrameCount * 1000000.0 * 480 / (8000.0 * LTempo)) + 1;
    LClock := TTempoMap.Create(480, LLengthTicks, [MakeTempoChange(0, LTempo)]);
    LSpans := LTrack.CopySpans;
    SetLength(LTimed, Length(LSpans));
    for LIndex := 0 to High(LSpans) do
    begin
      LTimed[LIndex].Kind := LSpans[LIndex].Kind;
      LTimed[LIndex].Note := LSpans[LIndex].Note;
      LTimed[LIndex].StartTick := LClock.NextGridTick(LSpans[LIndex].StartFrame, 8000, 1);
      LTimed[LIndex].EndTick := LClock.NextGridTick(LSpans[LIndex].EndFrame, 8000, 1);
    end;
    LGates := nil;
    for LIndex := 0 to High(LTimed) do
    begin
      if (LTimed[LIndex].Kind = pskPitch) and
        (LTimed[LIndex].EndTick > LTimed[LIndex].StartTick) then
      begin
        LCount := Length(LGates);
        SetLength(LGates, LCount + 1);
        LGates[LCount] := Default(TNoteGate);
        LGates[LCount].StartTick := LTimed[LIndex].StartTick;
        LGates[LCount].EndTick := LTimed[LIndex].EndTick;
        LGates[LCount].Pitch := LTimed[LIndex].Note;
        LGates[LCount].Velocity := 80;
        LGates[LCount].Channel := 0;
      end;
    end;
    Result := TJSONObject.Create;
    try
      Result.Add('capture_id', ARequest.Strings['capture_id']);
      Result.Add('source_sha256', LHash);
      Result.Add('source_sample_rate', LWave.SampleRate);
      Result.Add('source_start_frame', 0);
      Result.Add('source_end_frame', LFrames);
      Result.Add('source_channel', LChannel);
      Result.Add('analysis_sample_rate', 8000);
      Result.Add('resampler_version', ResampleVersion);
      Result.Add('estimator_version', PitchEstimatorVersion);
      Result.Add('window_frames', LTrack.WindowFrames);
      Result.Add('hop_frames', LOptions.HopFrames);
      Result.Add('minimum_hz', LOptions.Pitch.MinimumHz);
      Result.Add('maximum_hz', LOptions.Pitch.MaximumHz);
      Result.Add('difference_threshold', LOptions.Pitch.DifferenceThreshold);
      Result.Add('silence_rms', LOptions.Pitch.SilenceRms);
      Result.Add('maximum_cents', LOptions.MaximumCents);
      Result.Add('minimum_run_windows', LOptions.MinimumRunWindows);
      Result.Add('tempo_us', LTempo);
      Result.Add('ticks_per_quarter', 480);
      Result.Add('tempo_origin', 'caller_selected_export_clock_not_inferred');
      Result.Add('midi_rounding', 'first_tick_whose_floor_frame_reaches_each_endpoint');
      Result.Add('note_count', Length(LGates));
      Result.Add('experimental', True);
      Result.Add('training_admitted', False);
      Result.Add('policy', 'existing_single_pitch_track;native_sinc_8k;first_8s;unknown_spans_excluded;fixed_velocity_80;no_attack_inference');
      LRows := TJSONArray.Create;
      Result.Add('spans', LRows);
      LSpans := LTrack.CopySpans;
      for LIndex := 0 to High(LSpans) do
      begin
        LRow := TJSONObject.Create;
        LRows.Add(LRow);
        case LSpans[LIndex].Kind of
          pskPitch: LRow.Add('kind', 'note');
          pskSilence: LRow.Add('kind', 'silence');
          pskUnknown: LRow.Add('kind', 'unknown');
        end;
        LRow.Add('pitch', LSpans[LIndex].Note);
        LRow.Add('start_frame', (Int64(LSpans[LIndex].StartFrame) * LWave.SampleRate + 4000) div 8000);
        LRow.Add('end_frame', Min(Int64(LFrames),
          (Int64(LSpans[LIndex].EndFrame) * LWave.SampleRate + 4000) div 8000));
      end;
      Result.Add('midi_available', Length(LGates) > 0);
      Result.Add('audio_available', Length(LGates) > 0);
      if Length(LGates) > 0 then
      begin
        LSequence := TNoteSequence.Create(480, LLengthTicks, [MakeTempoChange(0, LTempo)], LGates);
        LBytes := EncodeMidiNotes(LSequence, []);
        LOutput := TFileStream.Create(LPath + PathDelim + 'notes.mid', fmCreate or fmShareExclusive);
        LOutput.WriteBuffer(LBytes[0], Length(LBytes));
        FreeAndNil(LOutput);
        if Assigned(ACheck) then
        begin
          ACheck;
        end;
        LVoice := DefaultSynthVoice;
        LVoice.Shape := wsSine;
        LVoice.Gain := 0.2;
        LVoice.Envelope.AttackSeconds := 0.005;
        LVoice.Envelope.ReleaseSeconds := 0.015;
        LPreview := RenderNoteSequence(LSequence, 22050, LVoice, LRenderReport);
        LOutput := TFileStream.Create(LPath + PathDelim + 'notes.wav', fmCreate or fmShareExclusive);
        WriteWavePcm16(LOutput, LPreview);
        FreeAndNil(LOutput);
        Result.Add('midi_sha256', FileHash(LPath + PathDelim + 'notes.mid'));
        Result.Add('audio_sha256', FileHash(LPath + PathDelim + 'notes.wav'));
        Result.Add('rendered_notes', LRenderReport.RenderedNotes);
      end;
    except
      Result.Free;
      Result := nil;
      raise;
    end;
  finally
    LOutput.Free;
    LSequence.Free;
    LClock.Free;
    LTrack.Free;
    LPreview.Free;
    LAnalysis.Free;
    LOriginal.Free;
    LWave.Free;
    LStream.Free;
  end;
end;

function OpenStudioPitchArtifact(const ACatalogRoot, AJobId, AKind: String;
  out AHash: String): TFileStream;
var
  LJob: TJSONObject;
  LName: String;
begin
  Need((AKind = 'midi') or (AKind = 'audio'), 'Choose MIDI or audio preview');
  LJob := ReadStudioJob(ACatalogRoot, AJobId);
  try
    Need((LJob.Strings['status'] = 'completed') and (LJob.Strings['kind'] = 'capture_pitch') and
      LJob.Objects['results'].Get(AKind + '_available', False), 'No pitch artifact is available');
    LName := 'notes.wav';
    if AKind = 'midi' then
    begin
      LName := 'notes.mid';
    end;
    AHash := LJob.Objects['results'].Strings[AKind + '_sha256'];
    Result := TFileStream.Create(StudioJobDirectory(ACatalogRoot, AJobId) + PathDelim + LName,
      fmOpenRead or fmShareDenyWrite);
    try
      Need((Result.Size <= 2097152) and (Sha256Stream(Result, Result.Size) = AHash),
        'Pitch preview artifact changed');
      Result.Position := 0;
    except
      Result.Free;
      raise;
    end;
  finally
    LJob.Free;
  end;
end;

function SaveStudioExplorationFeedback(const ACatalogRoot: String;
  const AWrite: TJSONObject): TJSONObject;
var
  LJob: TJSONObject;
  LOld: TJSONObject;
  LPath: String;
  LId: String;
  LChar: Char;
begin
  Need((AWrite.Count = 4) and (AWrite.Find('feedback_id') <> nil) and
    (AWrite.Find('job_id') <> nil) and (AWrite.Find('rating') <> nil) and
    (AWrite.Find('comment') <> nil), 'Feedback requires one job, rating and comment');
  LId := AWrite.Get('feedback_id', '');
  Need((Length(LId) >= 1) and (Length(LId) <= 48), 'Invalid feedback identity');
  for LChar in LId do
  begin
    Need(LChar in ['a'..'z', 'A'..'Z', '0'..'9', '-', '_'], 'Invalid feedback identity');
  end;
  ValidateStudioCollectionName(LId);
  Need((AWrite.Get('rating', '') = 'works') or (AWrite.Get('rating', '') = 'partial') or
    (AWrite.Get('rating', '') = 'fails'), 'Choose works, partial or fails');
  Need(Length(AWrite.Get('comment', '')) <= 2048, 'Feedback exceeds 2048 bytes');
  LJob := ReadStudioJob(ACatalogRoot, AWrite.Strings['job_id']);
  try
    Need((LJob.Strings['status'] = 'completed') and
      ((LJob.Strings['kind'] = 'capture_pitch') or (LJob.Strings['kind'] = 'capture_inspect')),
      'Choose a completed analysis or pitch preview');
    LPath := IncludeTrailingPathDelimiter(ACatalogRoot) + 'studio' + PathDelim +
      'exploration-feedback' + PathDelim + LId + '.json';
    Need(ForceDirectories(ExtractFileDir(LPath)), 'Could not create feedback history');
    Result := TJSONObject(AWrite.Clone);
    try
      Result.Add('source_sha256', LJob.Objects['results'].Strings['source_sha256']);
      Result.Add('request', LJob.Objects['request'].Clone);
      Result.Add('result_sha256', StudioTextHash(LJob.Objects['results'].AsJSON));
      if FileExists(LPath) then
      begin
        LOld := ReadStudioJSON(LPath);
        try
          Need(LOld.AsJSON = Result.AsJSON, 'Feedback retry differs from the saved answer');
        finally
          LOld.Free;
        end;
      end
      else
      begin
        WriteStudioJSONNew(LPath, Result);
      end;
    except
      Result.Free;
      raise;
    end;
  finally
    LJob.Free;
  end;
end;

end.
