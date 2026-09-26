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
unit pythian.music.render;

{$mode delphi}
{$H+}

interface

uses
  pythian.audio,
  pythian.music,
  pythian.instrument,
  pythian.synth;

const
  MaximumNoteVoices = 4096;

type
  TNoteVoices = array of TSynthVoice;
  TNoteInstruments = array of TInstrument;

  TNoteRenderReport = record
    SourceNotes: Integer;
    RenderedNotes: Integer;
    SubFrameNotes: Integer;
    RenderedTones: Integer;
  end;

{ Caller selects one voice for every note; this is not a General MIDI device.
  Both gate endpoints floor independently using the exact PPQ clock. Gates
  shorter than one output frame are omitted and counted. No pitch is clamped.
  Planning bounds the finite event count, not total PCM storage; offline render
  calls still enforce their clip sample/work budgets. Stream the plan for longer
  output. Planning builds a detached candidate; rejection preserves the prior assigned
  plan and leaves the report reset.
  Optional automation, gated envelopes and source factories remain borrowed in planned tones;
  keep them alive until all rendering of the returned plan has finished. }
function PlanNoteTones(const ASequence: TNoteSequence; const ASampleRate: Integer;
  const AVoice: TSynthVoice; out AReport: TNoteRenderReport): TFrameTones; overload;
function RenderNoteSequence(const ASequence: TNoteSequence; const ASampleRate: Integer;
  const AVoice: TSynthVoice; out AReport: TNoteRenderReport): TAudioClip; overload;

{ Explicit dense table indexed by TNoteGate.Voice, independent of track/channel.
  Every note, including a sub-frame gate, must have a binding. There is no implicit
  fallback or MIDI program selection. Voice records are copied into planned tones;
  automation/envelopes/source factories follow the same borrowed lifetime as above. }
function PlanNoteTones(const ASequence: TNoteSequence; const ASampleRate: Integer;
  const AVoices: TNoteVoices; out AReport: TNoteRenderReport): TFrameTones; overload;
function RenderNoteSequence(const ASequence: TNoteSequence; const ASampleRate: Integer;
  const AVoices: TNoteVoices; out AReport: TNoteRenderReport): TAudioClip; overload;

{ Instruments are borrowed during planning. All matching zones expand in input
  note order, then zone order. RenderedNotes counts sounding source gates;
  RenderedTones counts all layers. The tone budget applies after expansion.
  Missing instruments or zones reject even sub-frame notes; rate-dependent voice
  validation applies only to sounding gates. Factories/automation/envelopes remain borrowed
  after planning, but the instruments and binding table may be released. }
function PlanNoteTones(const ASequence: TNoteSequence; const ASampleRate: Integer;
  const AInstrument: TInstrument; out AReport: TNoteRenderReport): TFrameTones; overload;
function PlanNoteTones(const ASequence: TNoteSequence; const ASampleRate: Integer;
  const AInstruments: TNoteInstruments; out AReport: TNoteRenderReport): TFrameTones; overload;
function RenderNoteSequence(const ASequence: TNoteSequence; const ASampleRate: Integer;
  const AInstrument: TInstrument; out AReport: TNoteRenderReport): TAudioClip; overload;
function RenderNoteSequence(const ASequence: TNoteSequence; const ASampleRate: Integer;
  const AInstruments: TNoteInstruments; out AReport: TNoteRenderReport): TAudioClip; overload;

implementation

uses
  Math;

function PlanBindings(const ASequence: TNoteSequence; const ASampleRate: Integer;
  const AVoices: TNoteVoices; const AInstruments: TNoteInstruments;
  const ASelectByVoice, AUseInstruments: Boolean;
  out AReport: TNoteRenderReport): TFrameTones;
var
  LGate: TNoteGate;
  LIndex: Integer;
  LCount: Integer;
  LVoiceIndex: Integer;
  LBindingCount: Integer;
  LLayer: Integer;
  LNote: TFrameTones;
  LStart: Int64;
  LEnd: Int64;
  LReport: TNoteRenderReport;
begin
  AReport := Default(TNoteRenderReport);
  ValidateAudioFormat(ASampleRate, 2);
  if ASequence = nil then
  begin
    raise EAudio.Create('Note sequence is required');
  end;
  LBindingCount := Length(AVoices);
  if AUseInstruments then
  begin
    LBindingCount := Length(AInstruments);
  end;
  if (LBindingCount < 1) or (LBindingCount > MaximumNoteVoices) then
  begin
    raise EAudio.Create('Note rendering requires 1..4096 explicit bindings');
  end;
  LReport := Default(TNoteRenderReport);
  LReport.SourceNotes := ASequence.NoteCount;
  Result := nil;
  SetLength(Result, Min(ASequence.NoteCount, MaximumToneEvents));
  LCount := 0;
  for LIndex := 0 to ASequence.NoteCount - 1 do
  begin
    LGate := ASequence.GateAt(LIndex);
    LVoiceIndex := 0;
    if ASelectByVoice then
    begin
      LVoiceIndex := LGate.Voice;
    end;
    if LVoiceIndex >= LBindingCount then
    begin
      raise EAudio.Create('Note has no synthesis voice binding');
    end;
    if AUseInstruments and (AInstruments[LVoiceIndex] = nil) then
    begin
      raise EAudio.Create('Note has no instrument binding');
    end;
    LStart := ASequence.FrameAtTick(LGate.StartTick, ASampleRate);
    LEnd := ASequence.FrameAtTick(LGate.EndTick, ASampleRate);
    if LEnd = LStart then
    begin
      if AUseInstruments then
      begin
        AInstruments[LVoiceIndex].SelectZones(LGate.Pitch, LGate.Velocity);
      end;
      Inc(LReport.SubFrameNotes);
      Continue;
    end;
    if AUseInstruments then
    begin
      LNote := AInstruments[LVoiceIndex].PlanNote(LGate.Pitch, LGate.Velocity,
        ASampleRate, LStart, LEnd - LStart, LIndex + 1);
    end
    else
    begin
      SetLength(LNote, 1);
      LNote[0].StartFrame := LStart;
      LNote[0].GateFrames := LEnd - LStart;
      LNote[0].FrequencyHz := 440 * Power(2, (LGate.Pitch - 69) / 12);
      LNote[0].Velocity := LGate.Velocity / 127;
      LNote[0].Voice := AVoices[LVoiceIndex];
      LNote[0].Seed := LIndex + 1;
    end;
    if Length(LNote) > MaximumToneEvents - LCount then
    begin
      raise EAudio.Create('Sequence exceeds offline rendering tone budget');
    end;
    if LCount + Length(LNote) > Length(Result) then
    begin
      SetLength(Result, Min(MaximumToneEvents,
        Max(Length(Result) * 2, LCount + Length(LNote))));
    end;
    for LLayer := 0 to High(LNote) do
    begin
      Result[LCount] := LNote[LLayer];
      Inc(LCount);
    end;
    Inc(LReport.RenderedNotes);
  end;
  SetLength(Result, LCount);
  LReport.RenderedTones := LCount;
  AReport := LReport;
end;

function PlanNoteTones(const ASequence: TNoteSequence; const ASampleRate: Integer;
  const AVoice: TSynthVoice; out AReport: TNoteRenderReport): TFrameTones;
var
  LVoices: TNoteVoices;
  LCandidate: TFrameTones;
begin
  SetLength(LVoices, 1);
  LVoices[0] := AVoice;
  LCandidate := PlanBindings(ASequence, ASampleRate, LVoices, nil, False, False, AReport);
  Result := LCandidate;
end;

function PlanNoteTones(const ASequence: TNoteSequence; const ASampleRate: Integer;
  const AVoices: TNoteVoices; out AReport: TNoteRenderReport): TFrameTones;
var
  LCandidate: TFrameTones;
begin
  LCandidate := PlanBindings(ASequence, ASampleRate, AVoices, nil, True, False, AReport);
  Result := LCandidate;
end;

function PlanNoteTones(const ASequence: TNoteSequence; const ASampleRate: Integer;
  const AInstrument: TInstrument; out AReport: TNoteRenderReport): TFrameTones;
var
  LInstruments: TNoteInstruments;
  LCandidate: TFrameTones;
begin
  SetLength(LInstruments, 1);
  LInstruments[0] := AInstrument;
  LCandidate := PlanBindings(ASequence, ASampleRate, nil, LInstruments,
    False, True, AReport);
  Result := LCandidate;
end;

function PlanNoteTones(const ASequence: TNoteSequence; const ASampleRate: Integer;
  const AInstruments: TNoteInstruments; out AReport: TNoteRenderReport): TFrameTones;
var
  LCandidate: TFrameTones;
begin
  LCandidate := PlanBindings(ASequence, ASampleRate, nil, AInstruments,
    True, True, AReport);
  Result := LCandidate;
end;

function RenderNoteSequence(const ASequence: TNoteSequence; const ASampleRate: Integer;
  const AVoice: TSynthVoice; out AReport: TNoteRenderReport): TAudioClip;
var
  LTones: TFrameTones;
  LReport: TNoteRenderReport;
begin
  AReport := Default(TNoteRenderReport);
  LTones := PlanNoteTones(ASequence, ASampleRate, AVoice, LReport);
  Result := RenderFrameTones(LTones, ASampleRate,
    ASequence.FrameAtTick(ASequence.LengthTicks, ASampleRate));
  AReport := LReport;
end;

function RenderNoteSequence(const ASequence: TNoteSequence; const ASampleRate: Integer;
  const AVoices: TNoteVoices; out AReport: TNoteRenderReport): TAudioClip;
var
  LTones: TFrameTones;
  LReport: TNoteRenderReport;
begin
  AReport := Default(TNoteRenderReport);
  LTones := PlanNoteTones(ASequence, ASampleRate, AVoices, LReport);
  Result := RenderFrameTones(LTones, ASampleRate,
    ASequence.FrameAtTick(ASequence.LengthTicks, ASampleRate));
  AReport := LReport;
end;

function RenderNoteSequence(const ASequence: TNoteSequence; const ASampleRate: Integer;
  const AInstrument: TInstrument; out AReport: TNoteRenderReport): TAudioClip;
var
  LTones: TFrameTones;
  LReport: TNoteRenderReport;
begin
  AReport := Default(TNoteRenderReport);
  LTones := PlanNoteTones(ASequence, ASampleRate, AInstrument, LReport);
  Result := RenderFrameTones(LTones, ASampleRate,
    ASequence.FrameAtTick(ASequence.LengthTicks, ASampleRate));
  AReport := LReport;
end;

function RenderNoteSequence(const ASequence: TNoteSequence; const ASampleRate: Integer;
  const AInstruments: TNoteInstruments; out AReport: TNoteRenderReport): TAudioClip;
var
  LTones: TFrameTones;
  LReport: TNoteRenderReport;
begin
  AReport := Default(TNoteRenderReport);
  LTones := PlanNoteTones(ASequence, ASampleRate, AInstruments, LReport);
  Result := RenderFrameTones(LTones, ASampleRate,
    ASequence.FrameAtTick(ASequence.LengthTicks, ASampleRate));
  AReport := LReport;
end;

end.
