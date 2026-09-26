(*
MIT License

Copyright (c) 2021 mr-highball
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
program pythian_tests_wfc_music;

{$mode delphi}
{$H+}

uses
  SysUtils,
  pythian.audio,
  pythian.music,
  pythian.time,
  pythian.music.render,
  pythian.synth,
  pythian.midi.smf,
  pythian.midi.export,
  pythian.chord.stream,
  pythian.wfc.music,
  wfc_sequence,
  wfc_sequence_learn,
  wfc_music,
  wfc_music_midi,
  wfc_music_audio,
  wfc_music_ensemble,
  wfc_music_sequence,
  wfc_midi_smf;

procedure Check(const ACondition: Boolean; const AMessage: String);
begin
  if not ACondition then
  begin
    raise Exception.Create(AMessage);
  end;
end;

procedure CheckTimedFrame;
var
  LClock: TTempoMap;
  LFrame: TWfcMusicEnsembleFrame;
  LParts: TTimedWfcEnsembleFrames;
  LTones: TWfcMusicTones;
begin
  LClock := TTempoMap.Create(480, 300, [MakeTempoChange(0, 500000),
    MakeTempoChange(100, 750000), MakeTempoChange(220, 250000)]);
  try
    SetLength(LTones, 1);
    LTones[0] := MakeWfcMusicTone(60, 100);
    SetLength(LFrame.Voices, 2);
    LFrame.Voices[0] := MakeWfcMusicVoiceCell(wmcaAttack, LTones);
    LFrame.Voices[1] := MakeWfcMusicRestVoiceCell;
    LParts := TimeWfcEnsembleFrame(LFrame, LClock, 0, 300);
    Check((Length(LParts) = 3) and (LParts[0].Timing.LengthTicks = 100) and
      (LParts[1].Timing.LengthTicks = 120) and (LParts[2].Timing.LengthTicks = 80) and
      (LParts[0].Frame.Voices[0].Action = wmcaAttack) and
      (LParts[1].Frame.Voices[0].Action = wmcaHold) and
      (LParts[2].Frame.Voices[0].Action = wmcaHold) and
      (LParts[1].Frame.Voices[1].Action = wmcaRest),
      'Tempo changes subdivide playback without repeated attacks or sounding rests');
    LParts[1].Frame.Voices[0].Tones[0].Pitch := 72;
    Check((LFrame.Voices[0].Tones[0].Pitch = 60) and
      (LParts[0].Frame.Voices[0].Tones[0].Pitch = 60) and
      (LParts[2].Frame.Voices[0].Tones[0].Pitch = 60), 'Timed parts own detached voice/tone arrays');
    WriteLn('Timed ensemble playback preserves attacks, holds, rests and source ownership');
  finally
    LClock.Free;
  end;
end;

procedure CheckNoteExportParity(const AScore: TWfcMusicScore;
  const ASequence: TNoteSequence);
var
  LFile: TWfcMidiFile;
  LBytes: TWfcMidiBytes;
  LNative: TMidiBytes;
  LIndex: Integer;
  LCount: Integer;
  LDelta: Cardinal;
begin
  LFile := BuildWfcMusicMidiFile(AScore);
  { Native note sequences retain notes and tempo. Remove only meter events
    from the actual companion export while carrying their delta forward. }
  LCount := 0;
  LDelta := 0;
  for LIndex := 0 to High(LFile.Tracks[0].Events) do
  begin
    Inc(LDelta, LFile.Tracks[0].Events[LIndex].DeltaTicks);
    if (LFile.Tracks[0].Events[LIndex].Status = $FF) and
      (LFile.Tracks[0].Events[LIndex].MetaType = $58) then
    begin
      Continue;
    end;
    LFile.Tracks[0].Events[LCount] := LFile.Tracks[0].Events[LIndex];
    LFile.Tracks[0].Events[LCount].DeltaTicks := LDelta;
    LDelta := 0;
    Inc(LCount);
  end;
  SetLength(LFile.Tracks[0].Events, LCount);
  Inc(LFile.Tracks[0].EndDeltaTicks, LDelta);
  LBytes := EncodeWfcMidiFile(LFile);
  LNative := EncodeMidiNotes(ASequence, [0]);
  Check(Length(LNative) = Length(LBytes), 'Actual WFC note export byte extent');
  for LIndex := 0 to High(LNative) do
  begin
    Check(LNative[LIndex] = LBytes[LIndex], 'Actual WFC note/tempo export bytes');
  end;
end;

procedure CheckScore(const AFractional: Boolean);
var
  LTracks: TWfcMusicTracks;
  LVoices: TWfcMusicVoices;
  LMeters: TWfcMusicMeterChanges;
  LTempos: TWfcMusicTempoChanges;
  LSpans: TWfcMusicSpanEvents;
  LTones: TWfcMusicTones;
  LScore: TWfcMusicScore;
  LSequence: TNoteSequence;
  LPreview: TWfcMusicPcm16Clip;
  LClip: TAudioClip;
  LVoice: TSynthVoice;
  LReport: TNoteRenderReport;
  LOptions: TWfcMusicAudioOptions;
  LRetimed: TNoteSequence;
  LRejected: Boolean;
begin
  SetLength(LTracks, 1);
  LTracks[0] := MakeWfcMusicTrack('fixture', 'Fixture');
  SetLength(LVoices, 1);
  LVoices[0] := MakeWfcMusicVoice(0, 'voice');
  SetLength(LMeters, 1);
  LMeters[0] := MakeWfcMusicMeterChange(0, 4, 4);
  SetLength(LTempos, 2);
  if AFractional then
  begin
    LTempos[0] := MakeWfcMusicTempoChange(0, 6);
    LTempos[1] := MakeWfcMusicTempoChange(1, 8);
    SetLength(LTones, 1);
    LTones[0] := MakeWfcMusicTone(60, 100);
    SetLength(LSpans, 1);
    LSpans[0] := MakeWfcMusicSound(0, 0, 12, LTones);
    LScore := TWfcMusicScore.Create(3, 12, 12,
      LTracks, LVoices, LMeters, LTempos, LSpans);
  end
  else
  begin
    LTempos[0] := MakeWfcMusicTempoChange(0, 500001);
    LTempos[1] := MakeWfcMusicTempoChange(960, 250000);
    SetLength(LSpans, 3);
    LSpans[0] := MakeWfcMusicRest(0, 0, 480);
    SetLength(LTones, 2);
    LTones[0] := MakeWfcMusicTone(60, 100);
    LTones[1] := MakeWfcMusicTone(64, 80);
    LSpans[1] := MakeWfcMusicSound(0, 480, 480, LTones);
    SetLength(LTones, 1);
    LTones[0] := MakeWfcMusicTone(69, 127);
    LSpans[2] := MakeWfcMusicSound(0, 960, 960, LTones);
    LScore := TWfcMusicScore.Create(480, 12, 1920,
      LTracks, LVoices, LMeters, LTempos, LSpans);
  end;
  try
    LSequence := ProjectWfcNotes(LScore);
    try
      CheckNoteExportParity(LScore, LSequence);
      if not AFractional then
      begin
        LRetimed := ProjectRetimedWfcNotes(LScore, 480, [120, 360, 240, 721]);
        try
          Check((LRetimed.LengthTicks = 1441) and (LRetimed.NoteCount = 3) and
            (LRetimed.GateAt(0).StartTick = 120) and (LRetimed.GateAt(0).EndTick = 480) and
            (LRetimed.GateAt(2).StartTick = 480) and (LRetimed.GateAt(2).EndTick = 1441) and
            (LRetimed.GateAt(2).Pitch = 69) and (LRetimed.GateAt(2).Velocity = 127),
            'Non-measure retiming preserves chords, held notes and exact endpoints');
          Check((LRetimed.FrameAtTick(480, 32000) = 16000) and
            (LRetimed.FrameAtTick(1441, 32000) = 32016),
            'Tempo change moves to the independent cumulative cell boundary');
        finally
          LRetimed.Free;
        end;
        LRejected := False;
        try
          LRetimed := ProjectRetimedWfcNotes(LScore, 480, [120, 360]);
          LRetimed.Free;
        except
          on EAudio do
          begin
            LRejected := True;
          end;
        end;
        Check(LRejected, 'Retiming cannot silently discard sounding source content');
        LRejected := False;
        try
          LRetimed := ProjectRetimedWfcNotes(LScore, 640, [120, 360, 721]);
          LRetimed.Free;
        except
          on EAudio do
          begin
            LRejected := True;
          end;
        end;
        Check(LRejected, 'Retiming rejects hidden endpoint quantization');
        Check((LSequence.NoteCount = 3) and (LSequence.GateAt(0).StartTick = 480)
          and (LSequence.GateAt(1).Pitch = 64) and (LSequence.GateAt(2).Pitch = 69)
          and (LSequence.GateAt(2).Velocity = 127), 'Rest/chord/note projection');
        Check((LSequence.GateAt(0).Voice = 0) and (LSequence.GateAt(0).Track = 0)
          and (LSequence.GateAt(0).Channel = -1), 'Source coordinates retained');
      end;
      LOptions := DefaultWfcMusicAudioOptions;
      LOptions.SampleRate := 32000;
      LPreview := RenderWfcMusicAudio(LScore, LOptions);
      try
        Check(LSequence.FrameAtTick(LSequence.LengthTicks, 32000) = LPreview.FrameCount,
          'Native PPQ time agrees with actual WFC renderer');
        LVoice := DefaultSynthVoice;
        LVoice.Envelope.ReleaseSeconds := 0;
        LClip := RenderNoteSequence(LSequence, 32000, LVoice, LReport);
        try
          Check(LClip.FrameCount = LPreview.FrameCount, 'Projected render keeps exact score extent');
        finally
          LClip.Free;
        end;
      finally
        LPreview.Free;
      end;
      LScore.Free;
      LScore := nil;
      Check(LSequence.GateAt(0).Pitch = 60, 'Projection survives source-score destruction');
    finally
      LSequence.Free;
    end;
  finally
    LScore.Free;
  end;
end;

procedure CheckCodec;
var
  LFile: TMidiFile;
  LBytes: TMidiBytes;
  LWfcBytes: TWfcMidiBytes;
  LIndex: Integer;
begin
  LFile := Default(TMidiFile);
  LFile.Format := 1;
  LFile.TicksPerQuarter := 480;
  SetLength(LFile.Tracks, 2);
  SetLength(LFile.Tracks[0].Events, 3);
  LFile.Tracks[0].Events[0] := MakeMidiTempoEvent(0, 500001);
  LFile.Tracks[0].Events[1] := MakeMidiMetaEvent(0, $7F, [1, 2, 255]);
  LFile.Tracks[0].Events[2] := MakeMidiSystemExclusiveEvent(128, $F0, [$7D, 1, $F7]);
  LFile.Tracks[0].EndDeltaTicks := 1;
  SetLength(LFile.Tracks[1].Events, 2);
  LFile.Tracks[1].Events[0] := MakeMidiChannelEvent(0, $90, [60, 100]);
  LFile.Tracks[1].Events[1] := MakeMidiChannelEvent(480, $80, [60, 0]);
  LFile.Tracks[1].EndDeltaTicks := 240;
  LBytes := EncodeMidiFile(LFile);
  SetLength(LWfcBytes, Length(LBytes));
  for LIndex := 0 to High(LBytes) do
  begin
    LWfcBytes[LIndex] := LBytes[LIndex];
  end;
  LWfcBytes := EncodeWfcMidiFile(DecodeWfcMidiFile(LWfcBytes));
  Check(Length(LBytes) = Length(LWfcBytes), 'WFC canonical MIDI length');
  for LIndex := 0 to High(LBytes) do
  begin
    Check(LBytes[LIndex] = LWfcBytes[LIndex], 'Complete actual WFC codec byte parity');
  end;
end;

procedure CheckEnsemble;
var
  LSpans: TWfcMusicSpanEvents;
  LTracks: TWfcMusicTracks;
  LVoices: TWfcMusicVoices;
  LMeters: TWfcMusicMeterChanges;
  LTempos: TWfcMusicTempoChanges;
  LFrames: TWfcMusicEnsembleFrames;
  LChord: TWfcMusicTones;
  LBass: TWfcMusicTones;
  LTemplate: TWfcMusicScore;
  LSequence: TNoteSequence;
  LBindings: TNoteVoices;
  LPlan: TFrameTones;
  LReport: TNoteRenderReport;
  LIndex: Integer;
  LRejected: Boolean;
begin
  SetLength(LTracks, 2);
  LTracks[0] := MakeWfcMusicTrack('bass', 'Bass');
  LTracks[1] := MakeWfcMusicTrack('chord', 'Chord');
  SetLength(LVoices, 2);
  LVoices[0] := MakeWfcMusicVoice(1, 'chord');
  LVoices[1] := MakeWfcMusicVoice(0, 'bass');
  SetLength(LMeters, 1);
  LMeters[0] := MakeWfcMusicMeterChange(0, 2, 4);
  SetLength(LTempos, 2);
  LTempos[0] := MakeWfcMusicTempoChange(0, 500000);
  LTempos[1] := MakeWfcMusicTempoChange(480, 250000);
  SetLength(LSpans, 2);
  LSpans[0] := MakeWfcMusicRest(0, 0, 960);
  LSpans[1] := MakeWfcMusicRest(1, 0, 960);
  LTemplate := TWfcMusicScore.Create(480, 12, 960, LTracks, LVoices,
    LMeters, LTempos, LSpans);
  LSequence := nil;
  try
    SetLength(LChord, 2);
    LChord[0] := MakeWfcMusicTone(60, 90);
    LChord[1] := MakeWfcMusicTone(64, 80);
    SetLength(LBass, 1);
    LBass[0] := MakeWfcMusicTone(48, 100);
    SetLength(LFrames, 4);
    for LIndex := 0 to 3 do
    begin
      SetLength(LFrames[LIndex].Voices, 2);
      LFrames[LIndex].Voices[0] := MakeWfcMusicVoiceCell(wmcaHold, LChord);
      LFrames[LIndex].Voices[1] := MakeWfcMusicRestVoiceCell;
    end;
    LFrames[0].Voices[0] := MakeWfcMusicVoiceCell(wmcaAttack, LChord);
    LFrames[1].Voices[1] := MakeWfcMusicVoiceCell(wmcaAttack, LBass);
    LFrames[2].Voices[1] := MakeWfcMusicVoiceCell(wmcaHold, LBass);
    LFrames[3].Voices[0] := MakeWfcMusicRestVoiceCell;
    LSequence := ProjectWfcEnsembleNotes(LFrames, 240, LTemplate);
    Check(LSequence.NoteCount = 3, 'Held chord and bass reconstruct one gate per attack');
    Check((LSequence.GateAt(0).StartTick = 0) and (LSequence.GateAt(0).EndTick = 720) and
      (LSequence.GateAt(0).Voice = 0) and (LSequence.GateAt(0).Track = 1) and
      (LSequence.GateAt(1).Pitch = 64) and (LSequence.GateAt(1).Velocity = 80),
      'Chord sustain and source identity');
    Check((LSequence.GateAt(2).StartTick = 240) and (LSequence.GateAt(2).EndTick = 720) and
      (LSequence.GateAt(2).Voice = 1) and (LSequence.GateAt(2).Track = 0),
      'Independent bass attack/hold');
    SetLength(LBindings, 2);
    LBindings[0] := DefaultSynthVoice;
    LBindings[0].Pan := -0.5;
    LBindings[1] := DefaultSynthVoice;
    LBindings[1].Pan := 0.5;
    LPlan := PlanNoteTones(LSequence, 8000, LBindings, LReport);
    Check((LPlan[0].GateFrames = 5000) and (LPlan[2].StartFrame = 2000) and
      (LPlan[2].GateFrames = 3000) and (LPlan[2].Voice.Pan = 0.5),
      'Ensemble hold crosses tempo change without retriggering');
    LFrames[2].Voices[1].Tones[0].Velocity := 99;
    LRejected := False;
    try
      ProjectWfcEnsembleNotes(LFrames, 240, LTemplate).Free;
    except
      on Exception do
      begin
        LRejected := True;
      end;
    end;
    Check(LRejected and (LSequence.GateAt(2).Velocity = 100),
      'Changed-velocity hold rejected; previous projection stays detached');
    LTemplate.Free;
    LTemplate := nil;
    Check(LSequence.FrameAtTick(960, 8000) = 6000, 'Template-free exact clock');
  finally
    LSequence.Free;
    LTemplate.Free;
  end;
end;

procedure CheckIndependentCapacities;
var
  LModels: array[0..1] of TWfcSequenceModel;
  LInvalid: TWfcSequenceModel;
  LFrames: TWfcMusicEnsembleFrames;
  LCapacities: TChordCapacities;
  LVoice: Integer;
  LTone: Integer;
  LRejected: Boolean;
begin
  LModels[0] := nil;
  LModels[1] := nil;
  LInvalid := nil;
  try
    for LVoice := 0 to 1 do
    begin
      LFrames := nil;
      SetLength(LFrames, 2);
      SetLength(LFrames[0].Voices, 1);
      LFrames[0].Voices[0] := MakeWfcMusicRestVoiceCell;
      SetLength(LFrames[1].Voices, 1);
      LFrames[1].Voices[0].Action := wmcaAttack;
      SetLength(LFrames[1].Voices[0].Tones, 1 + 2 * LVoice);
      for LTone := 0 to High(LFrames[1].Voices[0].Tones) do
      begin
        LFrames[1].Voices[0].Tones[LTone] := MakeWfcMusicTone(48 + 12 * LVoice + LTone * 4, 90);
      end;
      LModels[LVoice] := LearnSequenceModel(EncodeWfcMusicEnsembleFrames(LFrames), 1);
    end;
    LCapacities := WfcIndependentVoiceCapacities(LModels);
    Check((Length(LCapacities) = 2) and (LCapacities[0] = 1) and (LCapacities[1] = 3),
      'Independent capacities scan the complete singleton vocabularies, including chords after rests');
    SetLength(LFrames[0].Voices, 2);
    LFrames[0].Voices[1] := MakeWfcMusicRestVoiceCell;
    LInvalid := LearnSequenceModel([EncodeWfcMusicEnsembleFrame(LFrames[0])], 1);
    LCapacities[0] := 77;
    LRejected := False;
    try
      LCapacities := WfcIndependentVoiceCapacities([LModels[0], LInvalid]);
    except
      on EAudio do
      begin
        LRejected := True;
      end;
    end;
    Check(LRejected and (LCapacities[0] = 77),
      'A multi-voice vocabulary rejects without replacing the native capacities');
    LRejected := False;
    try
      WfcIndependentVoiceCapacities([LModels[0], nil]);
    except
      on EAudio do
      begin
        LRejected := True;
      end;
    end;
    Check(LRejected, 'Missing independent model rejected before renderer construction');
  finally
    LInvalid.Free;
    LModels[1].Free;
    LModels[0].Free;
  end;
end;

begin
  try
    CheckTimedFrame;
    CheckIndependentCapacities;
    CheckScore(False);
    CheckScore(True);
    CheckCodec;
    CheckEnsemble;
    WriteLn('WFC music projection, clock and SMF parity checks passed');
  except
    on LException: Exception do
    begin
      WriteLn(StdErr, LException.Message);
      Halt(1);
    end;
  end;
end.
