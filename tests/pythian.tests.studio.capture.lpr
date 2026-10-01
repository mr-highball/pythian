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
program StudioCaptureConformance;

{$mode delphi}
{$H+}

uses Classes, SysUtils, Math, Base64, fpjson,
  pythian.audio, pythian.hash, pythian.wave.stream,
  pythian.tools.annotations.catalog, pythian.tools.studio.projects,
  pythian.tools.studio.jobs, pythian.tools.studio.capture, pythian.tools.studio.pitch,
  pythian.music, pythian.midi.smf, pythian.midi.notes;

var
  GChecks: Integer;
  GRoot: String;
  GCatalog: String;

procedure Check(const ACondition: Boolean; const AMessage: String);
begin
  Inc(GChecks);
  if not ACondition then
  begin
    raise Exception.Create(AMessage);
  end;
end;

function WaveBytes(const ARate: Integer = 8000; const AChannels: Integer = 1;
  const ASilentLeft: Boolean = False): String;
var
  LStream: TMemoryStream;
  LClip: TAudioClip;
  LSamples: TAudioSamples;
  LIndex: Integer;
begin
  SetLength(LSamples, ARate * 4 * AChannels);
  for LIndex := 0 to ARate * 4 - 1 do
  begin
    if not ASilentLeft then
    begin
      LSamples[LIndex * AChannels] := 0.2 * Sin(2 * Pi * 220 * LIndex / ARate);
    end;
    if AChannels = 2 then
    begin
      LSamples[LIndex * 2 + 1] := 0.2 * Sin(2 * Pi * 440 * LIndex / ARate);
    end;
  end;
  LClip := TAudioClip.Create(ARate, AChannels, LSamples);
  LStream := TMemoryStream.Create;
  try
    WriteWavePcm16(LStream, LClip);
    SetLength(Result, LStream.Size);
    LStream.Position := 0;
    LStream.ReadBuffer(Result[1], Length(Result));
  finally
    LStream.Free;
    LClip.Free;
  end;
end;

function StartWrite(const AId: String; const ABytes: Integer): TJSONObject;
begin
  Result := TJSONObject.Create;
  Result.Add('capture_id', AId);
  Result.Add('name', 'Authored upload control');
  Result.Add('bytes', ABytes);
  Result.Add('origin', 'wav_import');
end;

function Chunk(const AId, ABytes: String; const AOffset: Integer): TJSONObject;
begin
  Result := TJSONObject.Create;
  Result.Add('capture_id', AId);
  Result.Add('offset', AOffset);
  Result.Add('data', EncodeStringBase64(ABytes));
end;

procedure CheckPitchBoundary(const AId: String; const ARate, AChannels,
  AChannel, AExpectedPitch: Integer);
var
  LBytes: String;
  LWrite: TJSONObject;
  LResult: TJSONObject;
  LOffset: Integer;
  LCount: Integer;
  LStream: TFileStream;
  LHash: String;
  LMidi: TMidiBytes;
  LNotes: TNoteSequence;
  LReport: TMidiNoteReport;
begin
  LBytes := WaveBytes(ARate, AChannels, True);
  LWrite := StartWrite(AId, Length(LBytes));
  try
    LResult := StartStudioCapture(GCatalog, LWrite);
    LResult.Free;
  finally
    LWrite.Free;
  end;
  LOffset := 0;
  while LOffset < Length(LBytes) do
  begin
    LCount := Min(MaximumStudioUploadChunk, Length(LBytes) - LOffset);
    LWrite := Chunk(AId, Copy(LBytes, LOffset + 1, LCount), LOffset);
    try
      LResult := AppendStudioCapture(GCatalog, LWrite);
      LResult.Free;
    finally
      LWrite.Free;
    end;
    Inc(LOffset, LCount);
  end;
  LResult := InspectStudioCapture(GCatalog, AId);
  LResult.Free;
  LWrite := TJSONObject.Create;
  try
    LWrite.Add('format', StudioJobWriteFormat);
    LWrite.Add('job_id', AId);
    LWrite.Add('kind', 'capture_pitch');
    LWrite.Add('capture_id', AId);
    LWrite.Add('mode', 'single_pitch');
    LWrite.Add('channel', AChannel);
    LWrite.Add('tempo_bpm', 90);
    LResult := EnqueueStudioJob(GCatalog, LWrite);
    LResult.Free;
    LResult := ClaimStudioJob(GCatalog, AId);
    LResult.Free;
    try
      LResult := PreviewStudioPitch(GCatalog, AId, LWrite);
      try
        Check((LResult.Integers['source_sample_rate'] = ARate) and
          (LResult.Int64s['source_end_frame'] = ARate * 4) and
          (LResult.Integers['source_channel'] = AChannel), 'Exact original clock/channel survives conversion');
        if AExpectedPitch < 0 then
        begin
          Check((LResult.Integers['note_count'] = 0) and
            not LResult.Booleans['midi_available'] and not LResult.Booleans['audio_available'],
            'Silence produces no fabricated note or playback');
          Check(not FileExists(StudioJobDirectory(GCatalog, AId) + '/notes.mid'),
            'Silence does not publish a MIDI artifact');
        end
        else
        begin
          Check(LResult.Integers['note_count'] = 1, 'Selected stereo channel yields one note');
        end;
        AdvanceStudioJob(GCatalog, AId, 'completed', 'completed', 1, 1, LResult);
      finally
        LResult.Free;
      end;
    finally
      ReleaseStudioWorker(GCatalog);
    end;
    if AExpectedPitch >= 0 then
    begin
      LStream := OpenStudioPitchArtifact(GCatalog, AId, 'midi', LHash);
      try
        SetLength(LMidi, LStream.Size);
        LStream.ReadBuffer(LMidi[0], Length(LMidi));
      finally
        LStream.Free;
      end;
      LNotes := DecodeMidiNotes(LMidi, DefaultMidiNoteOptions, LReport);
      try
        Check((LNotes.NoteCount = 1) and (LNotes.GateAt(0).Pitch = AExpectedPitch),
          'Resampling uses the requested channel, not the silent channel');
        Check((LNotes.GateAt(0).EndTick > 2700) and (LNotes.GateAt(0).EndTick <= 2882),
          'Export clock preserves the four-second source extent at 90 BPM');
      finally
        LNotes.Free;
      end;
    end;
  finally
    LWrite.Free;
  end;
  LResult := DiscardStudioCapture(GCatalog, AId);
  LResult.Free;
end;

procedure Run;
var
  LBytes: String;
  LHash: String;
  LPath: String;
  LWrite: TJSONObject;
  LChunk: TJSONObject;
  LResult: TJSONObject;
  LTrack: TJSONObject;
  LStream: TFileStream;
  LOffset: Integer;
  LCount: Integer;
  LFailed: Boolean;
  LSave: TJSONObject;
  LPitchWrite: TJSONObject;
  LFeedback: TJSONObject;
  LNotes: TNoteSequence;
  LMidi: TMidiBytes;
  LMidiReport: TMidiNoteReport;
  LMidiHash: String;
  LPitchHash: String;
begin
  Check(not DirectoryExists(GRoot), 'Use fresh isolated root');
  Check(ForceDirectories(GCatalog), 'Create isolated catalog');
  LBytes := WaveBytes;
  LWrite := StartWrite('uploaded', Length(LBytes));
  try
    LResult := StartStudioCapture(GCatalog, LWrite);
    try
      Check(LResult.Int64s['received_bytes'] = 0, 'New upload starts empty');
    finally
      LResult.Free;
    end;
    LResult := StartStudioCapture(GCatalog, LWrite);
    LResult.Free;
    LFailed := False;
    try
      LResult := InspectStudioCapture(GCatalog, 'uploaded');
      LResult.Free;
    except
      on E: EAudio do
      begin
        LFailed := True;
      end;
    end;
    Check(LFailed, 'Incomplete input cannot be inspected');
    LOffset := 0;
    while LOffset < Length(LBytes) do
    begin
      LCount := Min(MaximumStudioUploadChunk, Length(LBytes) - LOffset);
      LChunk := Chunk('uploaded', Copy(LBytes, LOffset + 1, LCount), LOffset);
      try
        LResult := AppendStudioCapture(GCatalog, LChunk);
        try
          Check(LResult.Int64s['received_bytes'] = LOffset + LCount, 'Exact chunk receipt');
        finally
          LResult.Free;
        end;
        LResult := AppendStudioCapture(GCatalog, LChunk);
        try
          Check(LResult.Int64s['received_bytes'] = LOffset + LCount, 'Chunk retry is idempotent');
        finally
          LResult.Free;
        end;
      finally
        LChunk.Free;
      end;
      Inc(LOffset, LCount);
    end;
    LChunk := Chunk('uploaded', 'wrong', 0);
    try
      LFailed := False;
      try
        LResult := AppendStudioCapture(GCatalog, LChunk);
        LResult.Free;
      except
        on E: EAudio do
        begin
          LFailed := True;
        end;
      end;
      Check(LFailed, 'Conflicting retry cannot overwrite original bytes');
    finally
      LChunk.Free;
    end;
    LResult := InspectStudioCapture(GCatalog, 'uploaded');
    try
      LHash := LResult.Strings['source_sha256'];
      Check((LResult.Int64s['frame_count'] = 32000) and
        (LResult.Integers['sample_rate'] = 8000), 'Native WAV geometry');
      Check(Abs(LResult.Floats['rms'] - 0.1414) < 0.001, 'Native actual RMS');
      Check(not LResult.Booleans['midi_available'] and LResult.Booleans['pitch_preview_available'],
        'Signal analysis offers explicit pitch preview without claiming it has run');
      Check(LResult.Find('waveform') <> nil, 'Native waveform is present');
      Check(LResult.Find('beat_proposal') <> nil, 'Native candidate packet is present');
    finally
      LResult.Free;
    end;
    Check(not FileExists(GCatalog + '/tracks/' + LHash + '.json'), 'Inspection does not admit training source');
    LStream := OpenStudioCapture(GCatalog, 'uploaded', LHash, LPath);
    try
      Check(Sha256Stream(LStream, LStream.Size) = LHash, 'Original preview is exact uploaded content');
    finally
      LStream.Free;
    end;
    LSave := TJSONObject.Create;
    try
      LSave.Add('capture_id', 'uploaded');
      LSave.Add('collection_name', 'recordings');
      LSave.Add('title', 'Saved oscillator control');
      LResult := SaveStudioCapture(GCatalog, 'save-upload', GRoot + '/library', LSave);
      try
        Check(LResult.Strings['source_sha256'] = LHash, 'Explicit save preserves audio identity');
        Check(not LResult.Booleans['already_catalogued'], 'First save adds one source');
      finally
        LResult.Free;
      end;
      LTrack := ReadCatalogTrack(GCatalog, LHash);
      try
        Check(LTrack.Strings['partition'] = 'unassigned', 'Save does not choose training admission');
        Check(Pos('wav_import', LTrack.Strings['provenance']) > 0, 'Import provenance retained');
      finally
        LTrack.Free;
      end;
      LResult := SaveStudioCapture(GCatalog, 'save-retry', GRoot + '/library', LSave);
      try
        Check(LResult.Booleans['already_catalogued'], 'Save retry deduplicates audio');
      finally
        LResult.Free;
      end;
      Check(FileExists(GRoot + '/library/collections/recordings/' + LHash + '.wav'),
        'Explicitly saved audio appears in private collection');
    finally
      LSave.Free;
    end;
    LPitchWrite := TJSONObject.Create;
    LFeedback := TJSONObject.Create;
    try
      LPitchWrite.Add('format', StudioJobWriteFormat);
      LPitchWrite.Add('job_id', 'pitch-one');
      LPitchWrite.Add('kind', 'capture_pitch');
      LPitchWrite.Add('capture_id', 'uploaded');
      LPitchWrite.Add('mode', 'single_pitch');
      LPitchWrite.Add('channel', 0);
      LPitchWrite.Add('tempo_bpm', 120);
      LResult := EnqueueStudioJob(GCatalog, LPitchWrite);
      LResult.Free;
      LResult := ClaimStudioJob(GCatalog, 'pitch-one');
      LResult.Free;
      try
        LResult := PreviewStudioPitch(GCatalog, 'pitch-one', LPitchWrite);
        try
          Check(LResult.Booleans['midi_available'], 'Current estimator produces MIDI preview');
          Check((LResult.Integers['note_count'] = 1) and LResult.Booleans['experimental'],
            'One stable pitch candidate is marked experimental');
          Check(not LResult.Booleans['training_admitted'], 'Preview never silently trains');
          LMidiHash := LResult.Strings['midi_sha256'];
          LPitchHash := LResult.Strings['audio_sha256'];
          AdvanceStudioJob(GCatalog, 'pitch-one', 'completed', 'completed', 1, 1, LResult);
        finally
          LResult.Free;
        end;
      finally
        ReleaseStudioWorker(GCatalog);
      end;
      LStream := OpenStudioPitchArtifact(GCatalog, 'pitch-one', 'midi', LHash);
      try
        Check(LHash = LMidiHash, 'Download binds exact MIDI bytes');
        SetLength(LMidi, LStream.Size);
        LStream.ReadBuffer(LMidi[0], Length(LMidi));
      finally
        LStream.Free;
      end;
      LNotes := DecodeMidiNotes(LMidi, DefaultMidiNoteOptions, LMidiReport);
      try
        Check((LNotes.NoteCount = 1) and (LNotes.GateAt(0).Pitch = 57),
          'Real MIDI decode preserves measured 220 Hz candidate A3');
        Check(LNotes.GateAt(0).EndTick > LNotes.GateAt(0).StartTick, 'Candidate MIDI has duration');
      finally
        LNotes.Free;
      end;
      LStream := OpenStudioPitchArtifact(GCatalog, 'pitch-one', 'audio', LHash);
      try
        Check((LHash = LPitchHash) and (LStream.Size > 1000), 'Native synthesized note playback');
      finally
        LStream.Free;
      end;
      LPitchWrite.Strings['job_id'] := 'pitch-replay';
      LResult := EnqueueStudioJob(GCatalog, LPitchWrite);
      LResult.Free;
      LResult := ClaimStudioJob(GCatalog, 'pitch-replay');
      LResult.Free;
      try
        LResult := PreviewStudioPitch(GCatalog, 'pitch-replay', LPitchWrite);
        try
          Check((LResult.Strings['midi_sha256'] = LMidiHash) and
            (LResult.Strings['audio_sha256'] = LPitchHash), 'Exact MIDI/audio preview replay');
          AdvanceStudioJob(GCatalog, 'pitch-replay', 'completed', 'completed', 1, 1, LResult);
        finally
          LResult.Free;
        end;
      finally
        ReleaseStudioWorker(GCatalog);
      end;
      LFeedback.Add('feedback_id', 'feedback-one');
      LFeedback.Add('job_id', 'pitch-one');
      LFeedback.Add('rating', 'partial');
      LFeedback.Add('comment', 'Authored test feedback, not a human listening judgment');
      LResult := SaveStudioExplorationFeedback(GCatalog, LFeedback);
      try
        Check(LResult.Objects['request'].Strings['capture_id'] = 'uploaded',
          'Listening feedback retains exact source request');
      finally
        LResult.Free;
      end;
      LResult := SaveStudioExplorationFeedback(GCatalog, LFeedback);
      LResult.Free;
      LFeedback.Strings['rating'] := 'fails';
      LFailed := False;
      try
        LResult := SaveStudioExplorationFeedback(GCatalog, LFeedback);
        LResult.Free;
      except
        on E: EAudio do
        begin
          LFailed := True;
        end;
      end;
      Check(LFailed, 'Changed feedback cannot silently replace saved response');
    finally
      LFeedback.Free;
      LPitchWrite.Free;
    end;
    LResult := DiscardStudioCapture(GCatalog, 'uploaded');
    LResult.Free;
    LResult := DiscardStudioCapture(GCatalog, 'uploaded');
    LResult.Free;
    LResult := ListStudioSources(GCatalog);
    try
      Check(LResult.Arrays['sources'].Count = 1, 'Discard preserves explicitly saved source');
    finally
      LResult.Free;
    end;
    LResult := ListStudioCaptures(GCatalog);
    try
      Check(LResult.Arrays['captures'].Count = 0, 'Discard removes temporary intake');
    finally
      LResult.Free;
    end;
    LWrite.Strings['capture_id'] := 'oversize';
    LWrite.Int64s['bytes'] := Int64(MaximumStudioUploadBytes) + 1;
    LFailed := False;
    try
      LResult := StartStudioCapture(GCatalog, LWrite);
      LResult.Free;
    except
      on E: EAudio do
      begin
        LFailed := True;
      end;
    end;
    Check(LFailed, 'Oversize input rejected before allocation');
    LWrite.Int64s['bytes'] := 44;
    LWrite.Strings['capture_id'] := '../escape';
    LFailed := False;
    try
      LResult := StartStudioCapture(GCatalog, LWrite);
      LResult.Free;
    except
      on E: EAudio do
      begin
        LFailed := True;
      end;
    end;
    Check(LFailed, 'Upload path traversal rejected');
    LWrite.Strings['capture_id'] := 'corrupt';
    LResult := StartStudioCapture(GCatalog, LWrite);
    LResult.Free;
    LChunk := Chunk('corrupt', StringOfChar('x', 44), 0);
    try
      LResult := AppendStudioCapture(GCatalog, LChunk);
      LResult.Free;
    finally
      LChunk.Free;
    end;
    LFailed := False;
    try
      LResult := InspectStudioCapture(GCatalog, 'corrupt');
      LResult.Free;
    except
      on E: EAudio do
      begin
        LFailed := True;
      end;
    end;
    Check(LFailed, 'Corrupt WAV cannot reach preview or collection');
    LResult := DiscardStudioCapture(GCatalog, 'corrupt');
    LResult.Free;
    LWrite.Strings['capture_id'] := 'CON';
    LFailed := False;
    try
      LResult := StartStudioCapture(GCatalog, LWrite);
      LResult.Free;
    except
      on E: EAudio do
      begin
        LFailed := True;
      end;
    end;
    Check(LFailed, 'Platform-reserved temporary identity rejected');
    LPath := 'build/studio-capture/' + Copy(StudioTextHash(ExpandFileName(GCatalog)), 1, 16) + '/interrupted';
    Check(ForceDirectories(LPath + '/incoming'), 'Create interrupted upload control');
    LResult := ListStudioCaptures(GCatalog);
    try
      Check((LResult.Arrays['captures'].Count = 1) and
        LResult.Arrays['captures'].Objects[0].Booleans['interrupted'], 'Interrupted import remains discoverable for discard');
    finally
      LResult.Free;
    end;
    LResult := DiscardStudioCapture(GCatalog, 'interrupted');
    LResult.Free;
    Check(not DirectoryExists(LPath), 'Discard recovers interrupted upload quota');
  finally
    LWrite.Free;
  end;
  CheckPitchBoundary('silence', 8000, 1, 0, -1);
  CheckPitchBoundary('right-channel', 16000, 2, 1, 69);
end;

begin
  try
    Check(ParamCount = 1, 'Usage: studio capture test FRESH_ROOT');
    GRoot := ExpandFileName(ParamStr(1));
    GCatalog := GRoot + '/catalog';
    Run;
    WriteLn('PASS ', GChecks, ' Studio capture checks');
  except
    on E: Exception do
    begin
      WriteLn(StdErr, E.ClassName, ': ', E.Message);
      ExitCode := 1;
    end;
  end;
end.
