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
unit pythian.wfc.music;

{$mode delphi}
{$H+}

interface

uses
  pythian.music,
  pythian.time,
  pythian.chord.stream,
  wfc_sequence,
  wfc_music,
  wfc_music_ensemble;

type
  TTimedWfcEnsembleFrame = record
    Timing: TTempoInterval;
    Frame: TWfcMusicEnsembleFrame;
  end;
  TTimedWfcEnsembleFrames = array of TTimedWfcEnsembleFrame;

{ Split playback at explicit tempo changes without creating new attacks.
  Each part owns detached voice/tone arrays. The original learned frame and
  its logical position remain unchanged. Rests remain rests. }
function TimeWfcEnsembleFrame(const AFrame: TWfcMusicEnsembleFrame;
  const AClock: TTempoMap; const AStartTick, ALengthTicks: Integer): TTimedWfcEnsembleFrames;

{ Audible note projection, not a replacement for the original WFC score.
  Retains PPQ, tempo, score extent, track/voice indices, pitch and velocity.
  Rest spans remain implicit gaps; meters, IDs and names remain in the source.
  WFC validates sounding velocities as 1..127. Returned sequence is owned. }
function ProjectWfcNotes(const AScore: TWfcMusicScore): TNoteSequence;

{ Explicit logical-cell retiming into native note timing, without imposing
  complete-measure output lengths. Source note and tempo endpoints must align to
  AQuantumTicks; positive lengths map the requested source prefix exactly.
  Only trailing source rests may lie outside that prefix. Meter/track names stay
  in the unchanged WFC score; notes retain track/voice indices and tempo values.
  Caller owns the detached result. No interpolation or inferred beat clock. }
function ProjectRetimedWfcNotes(const AScore: TWfcMusicScore;
  const AQuantumTicks: Integer; const ACellLengths: array of Integer): TNoteSequence;

{ Bounded complete ensemble timeline. Uses WFC's own reconstruction/hold checks,
  retains template tempo/voice identities, and returns detached native note gates.
  Frames must span the template exactly. This is not incremental frame admission. }
function ProjectWfcEnsembleNotes(const AFrames: TWfcMusicEnsembleFrames;
  const AQuantumTicks: Integer; const ATemplate: TWfcMusicScore): TNoteSequence;

{ Detached rest/attack/hold frame conversion shared by native audio and MIDI.
  Bounds voices/total tones and maps actions; each consumer applies its own
  pitch/velocity/channel/hold contract when admitting the result. }
function ProjectWfcChordFrame(const AFrame: TWfcMusicEnsembleFrame): TChordFrame;

{ Borrowed renderer and matching native clock. Converts one WFC ensemble frame,
  retaining holds across segment boundaries. Both must have the same admitted
  sample extent. Expected rejection preserves renderer and clock; unexpected
  renderer processing failure remains terminal. No WFC generator is duplicated. }
procedure AdmitWfcEnsembleFrame(const ARenderer: TChordStreamRenderer;
  const AClock: TIncrementalTempoClock; const AFrame: TWfcMusicEnsembleFrame;
  const ALengthTicks, ATempoMicrosecondsPerQuarter: Integer);

{ Detached per-voice maximum chord sizes over the complete model vocabulary.
  Checks native pitch/velocity and bounded inspection before rendering begins.
  The companion stream remains responsible for learned-path/music validation. }
function WfcEnsembleCapacities(const AModel: TWfcSequenceModel): TChordCapacities;

{ One singleton-frame model per output voice. Scans complete vocabularies with
  one shared inspection budget, preserves chords, and checks total tone capacity.
  Models are borrowed only during this call; no graph or stream is constructed. }
function WfcIndependentVoiceCapacities(
  const AModels: array of TWfcSequenceModel): TChordCapacities;

implementation

uses
  pythian.audio,
  wfc_music_sequence;

function TimeWfcEnsembleFrame(const AFrame: TWfcMusicEnsembleFrame;
  const AClock: TTempoMap; const AStartTick, ALengthTicks: Integer): TTimedWfcEnsembleFrames;
var
  LIntervals: TTempoIntervals;
  LIndex: Integer;
  LVoice: Integer;
begin
  if AClock = nil then
  begin
    raise EAudio.Create('Timed ensemble frame requires an explicit tempo map');
  end;
  ProjectWfcChordFrame(AFrame);
  LIntervals := AClock.Intervals(AStartTick, ALengthTicks);
  Result := nil;
  SetLength(Result, Length(LIntervals));
  for LIndex := 0 to High(Result) do
  begin
    Result[LIndex].Timing := LIntervals[LIndex];
    SetLength(Result[LIndex].Frame.Voices, Length(AFrame.Voices));
    for LVoice := 0 to High(AFrame.Voices) do
    begin
      Result[LIndex].Frame.Voices[LVoice] := AFrame.Voices[LVoice];
      Result[LIndex].Frame.Voices[LVoice].Tones := Copy(AFrame.Voices[LVoice].Tones);
      if (LIndex > 0) and (AFrame.Voices[LVoice].Action = wmcaAttack) then
      begin
        Result[LIndex].Frame.Voices[LVoice].Action := wmcaHold;
      end;
    end;
  end;
end;

function ProjectRetimedWfcNotes(const AScore: TWfcMusicScore;
  const AQuantumTicks: Integer; const ACellLengths: array of Integer): TNoteSequence;
var
  LBoundaries: array of Integer;
  LSource: TNoteSequence;
  LNotes: TNoteGates;
  LTempos: TTempoChanges;
  LTempo: TWfcMusicTempoChange;
  LIndex: Integer;
  LTempoCount: Integer;
  LPrefix: Int64;
  LTotal: Int64;

  function MapTick(const ATick: Integer): Integer;
  begin
    if (ATick < 0) or (ATick > LPrefix) or (ATick mod AQuantumTicks <> 0) then
    begin
      raise EAudio.Create('Retimed note/tempo events require exact source cell boundaries');
    end;
    Result := LBoundaries[ATick div AQuantumTicks];
  end;

begin
  if (AScore = nil) or (AQuantumTicks < 1) or
    (Length(ACellLengths) < 1) or (Length(ACellLengths) > MaximumNoteGates) then
  begin
    raise EAudio.Create('Retiming requires a score and bounded positive cell lengths');
  end;
  LPrefix := Int64(AQuantumTicks) * Length(ACellLengths);
  if LPrefix > AScore.LengthTicks then
  begin
    raise EAudio.Create('Retiming prefix exceeds the source score');
  end;
  SetLength(LBoundaries, Length(ACellLengths) + 1);
  LTotal := 0;
  for LIndex := 0 to High(ACellLengths) do
  begin
    if ACellLengths[LIndex] < 1 then
    begin
      raise EAudio.Create('Retimed cell lengths must be positive');
    end;
    Inc(LTotal, ACellLengths[LIndex]);
    if LTotal > High(Integer) then
    begin
      raise EAudio.Create('Retimed notes exceed the PPQ timeline extent');
    end;
    LBoundaries[LIndex + 1] := LTotal;
  end;
  LSource := ProjectWfcNotes(AScore);
  try
    SetLength(LNotes, LSource.NoteCount);
    for LIndex := 0 to High(LNotes) do
    begin
      LNotes[LIndex] := LSource.GateAt(LIndex);
      { Includes notes beyond the requested prefix: those must reject, not drop. }
      LNotes[LIndex].StartTick := MapTick(LNotes[LIndex].StartTick);
      LNotes[LIndex].EndTick := MapTick(LNotes[LIndex].EndTick);
    end;
    SetLength(LTempos, AScore.TempoCount);
    LTempoCount := 0;
    for LIndex := 0 to AScore.TempoCount - 1 do
    begin
      LTempo := AScore.TempoAt(LIndex);
      if LTempo.Tick >= LPrefix then
      begin
        Break;
      end;
      LTempos[LTempoCount] := MakeTempoChange(MapTick(LTempo.Tick),
        LTempo.MicrosecondsPerQuarter);
      Inc(LTempoCount);
    end;
    SetLength(LTempos, LTempoCount);
    Result := TNoteSequence.Create(AScore.TicksPerQuarter, LTotal, LTempos, LNotes);
  finally
    LSource.Free;
  end;
end;

function ScanEnsembleCapacities(const AModel: TWfcSequenceModel;
  const ASingleVoice: Boolean; var AWork: Int64): TChordCapacities;
var
  LCandidate: TChordCapacities;
  LFrame: TWfcMusicEnsembleFrame;
  LToken: Integer;
  LVoice: Integer;
  LTone: Integer;
  LTotal: Integer;
begin
  if (AModel = nil) or (AModel.PublicTokenCount < 1) or
    (AModel.PublicTokenCount > MaximumNoteGates) then
  begin
    raise EAudio.Create('Ensemble capacity scan requires a bounded model');
  end;
  LCandidate := nil;
  for LToken := 0 to AModel.PublicTokenCount - 1 do
  begin
    LFrame := DecodeWfcMusicEnsembleFrame(AModel.PublicTokenAt(LToken));
    if ASingleVoice and (Length(LFrame.Voices) <> 1) then
    begin
      raise EAudio.Create('Independent voice model must emit singleton ensemble frames');
    end;
    if (Length(LFrame.Voices) < 1) or (Length(LFrame.Voices) > MaximumChordStreamVoices) then
    begin
      raise EAudio.Create('Ensemble model exceeds native voice budget');
    end;
    if LToken = 0 then
    begin
      SetLength(LCandidate, Length(LFrame.Voices));
    end
    else if Length(LFrame.Voices) <> Length(LCandidate) then
    begin
      raise EAudio.Create('Ensemble model changes voice count');
    end;
    Inc(AWork, Length(LFrame.Voices));
    for LVoice := 0 to High(LFrame.Voices) do
    begin
      Inc(AWork, Length(LFrame.Voices[LVoice].Tones));
      if AWork > MaximumNoteGates then
      begin
        raise EAudio.Create('Ensemble capacity inspection exceeds work budget');
      end;
      if Length(LFrame.Voices[LVoice].Tones) > LCandidate[LVoice] then
      begin
        LCandidate[LVoice] := Length(LFrame.Voices[LVoice].Tones);
      end;
      for LTone := 0 to High(LFrame.Voices[LVoice].Tones) do
      begin
        if (LFrame.Voices[LVoice].Tones[LTone].Pitch < 0) or
          (LFrame.Voices[LVoice].Tones[LTone].Pitch > 127) or
          (LFrame.Voices[LVoice].Tones[LTone].Velocity < 1) or
          (LFrame.Voices[LVoice].Tones[LTone].Velocity > 127) then
        begin
          raise EAudio.Create('Ensemble model contains a tone outside native preview bounds');
        end;
      end;
    end;
  end;
  LTotal := 0;
  for LVoice := 0 to High(LCandidate) do
  begin
    if LCandidate[LVoice] > MaximumChordStreamTones - LTotal then
    begin
      raise EAudio.Create('Ensemble maximum voice capacities exceed native tone budget');
    end;
    Inc(LTotal, LCandidate[LVoice]);
  end;
  Result := LCandidate;
end;

function WfcEnsembleCapacities(const AModel: TWfcSequenceModel): TChordCapacities;
var
  LWork: Int64;
begin
  LWork := 0;
  Result := ScanEnsembleCapacities(AModel, False, LWork);
end;

function WfcIndependentVoiceCapacities(
  const AModels: array of TWfcSequenceModel): TChordCapacities;
var
  LCandidate: TChordCapacities;
  LSingle: TChordCapacities;
  LWork: Int64;
  LTotal: Integer;
  LVoice: Integer;
begin
  if (Length(AModels) < 1) or (Length(AModels) > MaximumChordStreamVoices) then
  begin
    raise EAudio.Create('Independent model count exceeds native voice budget');
  end;
  SetLength(LCandidate, Length(AModels));
  LWork := 0;
  LTotal := 0;
  for LVoice := 0 to High(AModels) do
  begin
    LSingle := ScanEnsembleCapacities(AModels[LVoice], True, LWork);
    LCandidate[LVoice] := LSingle[0];
    if LCandidate[LVoice] > MaximumChordStreamTones - LTotal then
    begin
      raise EAudio.Create('Independent voice capacities exceed native tone budget');
    end;
    Inc(LTotal, LCandidate[LVoice]);
  end;
  Result := LCandidate;
end;

function ProjectWfcChordFrame(const AFrame: TWfcMusicEnsembleFrame): TChordFrame;
var
  LFrame: TChordFrame;
  LVoice: Integer;
  LTone: Integer;
  LCount: Integer;
  LAction: Integer;
begin
  if Length(AFrame.Voices) > MaximumChordStreamVoices then
  begin
    raise EAudio.Create('Ensemble frame exceeds native chord voice budget');
  end;
  LCount := 0;
  SetLength(LFrame, Length(AFrame.Voices));
  for LVoice := 0 to High(LFrame) do
  begin
    LAction := Ord(AFrame.Voices[LVoice].Action);
    case LAction of
      Ord(wmcaRest):
      begin
        LFrame[LVoice].Action := caRest;
      end;
      Ord(wmcaAttack):
      begin
        LFrame[LVoice].Action := caAttack;
      end;
      Ord(wmcaHold):
      begin
        LFrame[LVoice].Action := caHold;
      end;
    else
      raise EAudio.Create('Unknown WFC ensemble voice action');
    end;
    if Length(AFrame.Voices[LVoice].Tones) > MaximumChordStreamTones - LCount then
    begin
      raise EAudio.Create('Ensemble frame exceeds native chord tone budget');
    end;
    Inc(LCount, Length(AFrame.Voices[LVoice].Tones));
    SetLength(LFrame[LVoice].Tones, Length(AFrame.Voices[LVoice].Tones));
    for LTone := 0 to High(LFrame[LVoice].Tones) do
    begin
      LFrame[LVoice].Tones[LTone].Pitch := AFrame.Voices[LVoice].Tones[LTone].Pitch;
      LFrame[LVoice].Tones[LTone].Velocity := AFrame.Voices[LVoice].Tones[LTone].Velocity;
    end;
  end;
  Result := LFrame;
end;

procedure AdmitWfcEnsembleFrame(const ARenderer: TChordStreamRenderer;
  const AClock: TIncrementalTempoClock; const AFrame: TWfcMusicEnsembleFrame;
  const ALengthTicks, ATempoMicrosecondsPerQuarter: Integer);
var
  LFrame: TChordFrame;
  LBefore: TTempoClockSnapshot;
  LFrames: Int64;
begin
  if (ARenderer = nil) or (AClock = nil) or (ALengthTicks < 1) then
  begin
    raise EAudio.Create('Ensemble admission requires a renderer, clock and positive tick interval');
  end;
  LBefore := AClock.Snapshot;
  if (LBefore.SampleRate <> ARenderer.SampleRate) or
    (LBefore.FrameCount <> ARenderer.FrameCount) then
  begin
    raise EAudio.Create('Ensemble clock does not match the renderer sample rate and extent');
  end;
  LFrame := ProjectWfcChordFrame(AFrame);
  LFrames := AClock.Advance(ALengthTicks, ATempoMicrosecondsPerQuarter);
  try
    ARenderer.AdmitFrame(LFrame, LFrames);
  except
    AClock.Restore(LBefore);
    raise;
  end;
end;

function ProjectWfcNotes(const AScore: TWfcMusicScore): TNoteSequence;
var
  LTempos: TTempoChanges;
  LGates: TNoteGates;
  LTempo: TWfcMusicTempoChange;
  LSpan: TWfcMusicSpanEvent;
  LVoice: TWfcMusicVoice;
  LIndex: Integer;
  LTone: Integer;
  LCount: Integer;
  LCapacity: Integer;
begin
  if AScore = nil then
  begin
    raise EAudio.Create('WFC score is required');
  end;
  if AScore.StepsPerOctave <> 12 then
  begin
    raise EAudio.Create('Note projection requires twelve-step MIDI pitch semantics');
  end;
  if (AScore.SpanCount > MaximumNoteGates) or
    (AScore.TempoCount > MaximumTempoChanges) then
  begin
    raise EAudio.Create('WFC score exceeds note projection budget');
  end;
  SetLength(LTempos, AScore.TempoCount);
  for LIndex := 0 to High(LTempos) do
  begin
    LTempo := AScore.TempoAt(LIndex);
    LTempos[LIndex] := MakeTempoChange(LTempo.Tick, LTempo.MicrosecondsPerQuarter);
  end;
  LCount := 0;
  LCapacity := 0;
  for LIndex := 0 to AScore.SpanCount - 1 do
  begin
    LSpan := AScore.SpanAt(LIndex);
    if Length(LSpan.Tones) > MaximumNoteGates - LCount then
    begin
      raise EAudio.Create('WFC chord tones exceed note projection budget');
    end;
    LVoice := AScore.VoiceAt(LSpan.VoiceIndex);
    for LTone := 0 to High(LSpan.Tones) do
    begin
      if LCount = LCapacity then
      begin
        if LCapacity = 0 then
        begin
          LCapacity := 64;
        end
        else
        begin
          LCapacity := LCapacity * 2;
        end;
        if LCapacity > MaximumNoteGates then
        begin
          LCapacity := MaximumNoteGates;
        end;
        SetLength(LGates, LCapacity);
      end;
      LGates[LCount].StartTick := LSpan.StartTick;
      LGates[LCount].EndTick := LSpan.StartTick + LSpan.DurationTicks;
      LGates[LCount].Pitch := LSpan.Tones[LTone].Pitch;
      LGates[LCount].Velocity := LSpan.Tones[LTone].Velocity;
      LGates[LCount].Track := LVoice.TrackIndex;
      LGates[LCount].Voice := LSpan.VoiceIndex;
      LGates[LCount].Channel := -1;
      Inc(LCount);
    end;
  end;
  SetLength(LGates, LCount);
  Result := TNoteSequence.Create(AScore.TicksPerQuarter, AScore.LengthTicks, LTempos, LGates);
end;

function ProjectWfcEnsembleNotes(const AFrames: TWfcMusicEnsembleFrames;
  const AQuantumTicks: Integer; const ATemplate: TWfcMusicScore): TNoteSequence;
var
  LScore: TWfcMusicScore;
  LFrame: Integer;
  LVoice: Integer;
  LWork: Int64;
begin
  if (ATemplate = nil) or (Length(AFrames) < 1) or
    (Length(AFrames) > MaximumNoteGates) then
  begin
    raise EAudio.Create('Ensemble note projection requires a bounded timeline and template');
  end;
  LWork := 0;
  for LFrame := 0 to High(AFrames) do
  begin
    Inc(LWork, Length(AFrames[LFrame].Voices));
    if LWork > MaximumNoteGates then
    begin
      raise EAudio.Create('Ensemble voice-cell work budget exceeded');
    end;
    for LVoice := 0 to High(AFrames[LFrame].Voices) do
    begin
      Inc(LWork, Length(AFrames[LFrame].Voices[LVoice].Tones));
      if LWork > MaximumNoteGates then
      begin
        raise EAudio.Create('Ensemble chord work budget exceeded');
      end;
    end;
  end;
  LScore := RebuildWfcMusicEnsembleScore(AFrames, AQuantumTicks, ATemplate);
  try
    Result := ProjectWfcNotes(LScore);
  finally
    LScore.Free;
  end;
end;

end.
