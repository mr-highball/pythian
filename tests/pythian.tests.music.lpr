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
program pythian_tests_music;

{$mode delphi}
{$H+}

uses
  Classes,
  SysUtils,
  Math,
  pythian.audio,
  pythian.time,
  pythian.music,
  pythian.music.render,
  pythian.midi.smf,
  pythian.midi.notes,
  pythian.synth,
  pythian.envelope,
  pythian.oscillator;

procedure Check(const ACondition: Boolean; const AMessage: String);
begin
  if not ACondition then
  begin
    raise Exception.Create(AMessage);
  end;
end;

function FromHex(const AText: String): TMidiBytes;
var
  LIndex: Integer;
begin
  Result := nil;
  SetLength(Result, Length(AText) div 2);
  for LIndex := 0 to High(Result) do
  begin
    Result[LIndex] := StrToInt('$' + Copy(AText, LIndex * 2 + 1, 2));
  end;
end;

procedure CheckTime;
var
  LTempos: TTempoChanges;
  LMap: TTempoMap;
  LNext: TTempoMap;
  LTime: TMusicTime;
  LRejected: Boolean;
  LTick: Integer;
begin
  SetLength(LTempos, 2);
  LTempos[0] := MakeTempoChange(0, 500001);
  LTempos[1] := MakeTempoChange(2, 250000);
  LMap := TTempoMap.Create(3, 6, LTempos);
  try
    LTempos[0].MicrosecondsPerQuarter := 1;
    LTime := LMap.TimeAtTick(3);
    Check((LTime.WholeMicroseconds = 416667) and (LTime.FractionNumerator = 1)
      and (LTime.Denominator = 3), 'Tempo segments retain exact PPQ remainder');
    Check(LMap.FrameAtTick(3, 44100) = 18375, 'Independent floor frame');
    Check(LMap.FrameAtTick(3, 44100, frCeiling) = 18376, 'Independent ceiling frame');
    Check(LMap.NextGridTick(14700, 44100, 2) = 2, 'Grid includes exact boundary');
    Check(LMap.NextGridTick(14701, 44100, 2) = 4, 'Grid advances beyond frozen boundary');
    LNext := LMap.WithTempoFrom(2, 1000000, 44100, 14700);
    try
      for LTick := 0 to 2 do
      begin
        Check(LNext.FrameAtTick(LTick, 44100) = LMap.FrameAtTick(LTick, 44100),
          'Tempo candidate preserves committed prefix and pivot');
      end;
      Check(LNext.FrameAtTick(6, 44100) = 73500, 'New tempo pivots without a time jump');
      Check(LMap.FrameAtTick(6, 44100) = 29400, 'Original tempo map remains unchanged');
    finally
      LNext.Free;
    end;
    LRejected := False;
    try
      LNext := LMap.WithTempoFrom(2, 1000000, 44100, 14701);
      LNext.Free;
    except
      on EAudio do
      begin
        LRejected := True;
      end;
    end;
    Check(LRejected, 'Cannot replace tempo inside committed frame prefix');
  finally
    LMap.Free;
  end;
  LTempos[0] := MakeTempoChange(0, 6);
  LTempos[1] := MakeTempoChange(1, 8);
  LMap := TTempoMap.Create(3, 12, LTempos);
  try
    Check(LMap.FrameAtTick(12, 32000) = 1, 'Sub-microsecond carry affects output frame');
  finally
    LMap.Free;
  end;
  SetLength(LTempos, 1);
  LTempos[0] := MakeTempoChange(0, MaximumTempoMicroseconds);
  LMap := TTempoMap.Create(1, High(Integer), LTempos);
  try
    Check(LMap.TimeAtTick(High(Integer)).WholeMicroseconds = Int64(36028794854703105),
      'Large tick/tempo product fits exact clock');
    Check(LMap.FrameAtTick(High(Integer), 384000) = Int64(13835057224205992),
      'Frame conversion avoids overflowing the unsplit product');
  finally
    LMap.Free;
  end;
end;

const
  CGolden = '4D546864000000060000000100034D54726B0000001A' +
    '00FF510307A12101903C6401FF510303D09001803C0003FF2F00';

procedure ExpectImportFailure(const AFile: TMidiFile; const AOptions: TMidiNoteOptions;
  const AMessage: String);
var
  LSequence: TNoteSequence;
  LReport: TMidiNoteReport;
  LRejected: Boolean;
begin
  LRejected := False;
  LReport.NoteCount := 99;
  try
    LSequence := DecodeMidiNotes(EncodeMidiFile(AFile), AOptions, LReport);
    LSequence.Free;
  except
    on EAudio do
    begin
      LRejected := True;
    end;
  end;
  Check(LRejected and (LReport.NoteCount = 0), AMessage);
end;

procedure CheckMidi;
var
  LBytes: TMidiBytes;
  LEncoded: TMidiBytes;
  LFile: TMidiFile;
  LOptions: TMidiNoteOptions;
  LReport: TMidiNoteReport;
  LSequence: TNoteSequence;
  LIndex: Integer;
  LRejected: Boolean;
  LGates: TNoteGates;
  LStream: TFileStream;
begin
  LBytes := FromHex(CGolden);
  LFile := DecodeMidiFile(LBytes);
  LEncoded := EncodeMidiFile(LFile);
  Check(Length(LEncoded) = Length(LBytes), 'Canonical MIDI byte length');
  Check(CompareByte(LEncoded[0], LBytes[0], Length(LBytes)) = 0,
    'Independent complete SMF golden bytes');
  for LIndex := 0 to High(LBytes) do
  begin
    LRejected := False;
    try
      DecodeMidiFile(Copy(LBytes, 0, LIndex));
    except
      on EMidiSmf do
      begin
        LRejected := True;
      end;
    end;
    Check(LRejected, 'Every truncated SMF fails');
  end;
  LRejected := False;
  try
    DecodeMidiVariableLength(FromHex('8000'));
  except
    on EMidiSmf do
    begin
      LRejected := True;
    end;
  end;
  Check(LRejected, 'Noncanonical VLQ fails');
  LOptions := DefaultMidiNoteOptions;
  LSequence := DecodeMidiNotes(LBytes, LOptions, LReport);
  try
    Check((LSequence.NoteCount = 1) and (LSequence.LengthTicks = 6) and
      (LSequence.GateAt(0).StartTick = 1) and (LSequence.GateAt(0).EndTick = 3),
      'Note endpoints and end-of-track silence preserved');
    Check(not LReport.UsedDefaultTempo, 'Explicit initial tempo reported');
    LGates := LSequence.CopyGates;
    LGates[0].Pitch := 1;
    Check(LSequence.GateAt(0).Pitch = 60, 'Sequence output is detached');
  finally
    LSequence.Free;
  end;
  if ParamCount > 0 then
  begin
    LStream := TFileStream.Create(ParamStr(1), fmCreate);
    try
      LStream.WriteBuffer(LBytes[0], Length(LBytes));
    finally
      LStream.Free;
    end;
  end;
  LBytes := FromHex('4D546864000000060000000100034D54726B00000011' +
    '00903C64013E50023C00013E0000FF2F00');
  LSequence := DecodeMidiNotes(LBytes, LOptions, LReport);
  try
    Check((LSequence.NoteCount = 2) and (LSequence.GateAt(0).EndTick = 3) and
      (LSequence.GateAt(1).StartTick = 1) and (LSequence.GateAt(1).EndTick = 4),
      'Running status and note-on-zero releases');
    Check(LReport.UsedDefaultTempo, 'Implicit initial tempo reported');
  finally
    LSequence.Free;
  end;

  LFile := Default(TMidiFile);
  LFile.Format := 0;
  LFile.TicksPerQuarter := 480;
  SetLength(LFile.Tracks, 1);
  SetLength(LFile.Tracks[0].Events, 4);
  LFile.Tracks[0].Events[0] := MakeMidiChannelEvent(0, $90, [60, 100]);
  LFile.Tracks[0].Events[1] := MakeMidiChannelEvent(1, $90, [60, 80]);
  LFile.Tracks[0].Events[2] := MakeMidiChannelEvent(1, $80, [60, 50]);
  LFile.Tracks[0].Events[3] := MakeMidiChannelEvent(1, $80, [60, 0]);
  ExpectImportFailure(LFile, LOptions, 'Overlapping same key rejects by default');
  LOptions.AllowOverlapsFIFO := True;
  LSequence := DecodeMidiNotes(EncodeMidiFile(LFile), LOptions, LReport);
  try
    Check((LSequence.GateAt(0).EndTick = 2) and (LSequence.GateAt(1).EndTick = 3)
      and (LReport.OverlappingNotesPairedFIFO = 1)
      and (LReport.DiscardedReleaseVelocities = 1), 'Explicit FIFO and release report');
  finally
    LSequence.Free;
  end;
  SetLength(LFile.Tracks[0].Events, 1);
  LFile.Tracks[0].EndDeltaTicks := 480;
  ExpectImportFailure(LFile, LOptions, 'Dangling note rejects by default');
  LOptions.CloseDanglingNotes := True;
  LSequence := DecodeMidiNotes(EncodeMidiFile(LFile), LOptions, LReport);
  try
    Check((LSequence.GateAt(0).EndTick = 480) and
      (LReport.ClosedDanglingNotes = 1), 'Explicit closure at global sequence end');
  finally
    LSequence.Free;
  end;

  LFile.Format := 1;
  SetLength(LFile.Tracks, 2);
  SetLength(LFile.Tracks[1].Events, 2);
  LFile.Tracks[1].Events[0] := MakeMidiChannelEvent(240, $80, [60, 0]);
  LFile.Tracks[1].Events[1] := MakeMidiChannelEvent(0, $B0, [64, 127]);
  ExpectImportFailure(LFile, LOptions, 'Pedal controller requires explicit lossy policy');
  LOptions.IgnoreUnsupportedEvents := True;
  LSequence := DecodeMidiNotes(EncodeMidiFile(LFile), LOptions, LReport);
  try
    Check((LSequence.GateAt(0).Track = 0) and (LSequence.GateAt(0).EndTick = 240)
      and (LReport.ClosedDanglingNotes = 0) and (LReport.IgnoredPerformanceEvents = 1),
      'Pair globally across tracks; retain note-on owner and report discarded controller');
  finally
    LSequence.Free;
  end;
  LFile.Tracks[0].Events[0] := MakeMidiTempoEvent(0, 500000);
  LFile.Tracks[1].Events[0] := MakeMidiTempoEvent(0, 500001);
  ExpectImportFailure(LFile, LOptions, 'Conflicting simultaneous tempos never guessed');
  LFile.Tracks[1].Events[0] := MakeMidiTempoEvent(0, 500000);
  LFile.Tracks[1].Events[1] := MakeMidiMetaEvent(0, $21, [1]);
  ExpectImportFailure(LFile, LOptions, 'Unsafe port routing rejects even under ignore policy');
  LFile.Tracks[1].Events[1] := MakeMidiSystemExclusiveEvent(0, $F0, [$7D, 1, $F7]);
  LBytes := EncodeMidiFile(LFile);
  LFile := DecodeMidiFile(LBytes);
  LBytes[High(LBytes) - 4] := 0;
  Check(LFile.Tracks[1].Events[1].Data[2] = $F7, 'Raw decoder owns opaque event data');
  LSequence := DecodeMidiNotes(EncodeMidiFile(LFile), LOptions, LReport);
  try
    Check((LReport.IgnoredSystemEvents = 1) and (LReport.RedundantTempoEvents = 1),
      'Opaque data loss and identical duplicate tempos reported');
  finally
    LSequence.Free;
  end;
end;

procedure CheckFrameRendering;
var
  LTones: TFrameTones;
  LClip: TAudioClip;
  LReplay: TAudioClip;
  LIndex: Integer;
  LRejected: Boolean;
  LSequence: TNoteSequence;
  LImport: TMidiNoteReport;
  LRender: TNoteRenderReport;
  LFile: TMidiFile;
begin
  SetLength(LTones, 1);
  LTones[0].StartFrame := 15;
  LTones[0].GateFrames := 7;
  LTones[0].FrequencyHz := 440;
  LTones[0].Velocity := 1;
  LTones[0].Seed := 1;
  LTones[0].Voice := DefaultSynthVoice;
  LTones[0].Voice.Shape := wsSquare;
  LTones[0].Voice.Envelope := Default(TAdsr);
  LTones[0].Voice.Envelope.SustainLevel := 1;
  LTones[0].Voice.Pan := -1;
  LClip := RenderFrameTones(LTones, 44100);
  try
    Check(LClip.FrameCount = 22, 'Exact integer gate extent');
    for LIndex := 0 to 14 do
    begin
      Check(LClip.SampleAt(LIndex, 0) = 0, 'Exact leading silence');
    end;
    Check((Abs(LClip.SampleAt(15, 0)) > 0) and
      (Abs(LClip.SampleAt(21, 0)) > 0), 'First and last gate frames included');
    LReplay := RenderFrameTones(LTones, 44100);
    try
      for LIndex := 0 to 21 do
      begin
        Check(LClip.SampleAt(LIndex, 0) = LReplay.SampleAt(LIndex, 0), 'Frame-render replay');
      end;
    finally
      LReplay.Free;
    end;
  finally
    LClip.Free;
  end;
  LTones[0].StartFrame := High(Int64);
  LRejected := False;
  try
    LClip := RenderFrameTones(LTones, 44100);
    LClip.Free;
  except
    on EAudio do
    begin
      LRejected := True;
    end;
  end;
  Check(LRejected, 'Huge frame input rejects before arithmetic/allocation');

  LSequence := DecodeMidiNotes(FromHex(CGolden), DefaultMidiNoteOptions, LImport);
  try
    LTones := PlanNoteTones(LSequence, 44100, DefaultSynthVoice, LRender);
    Check((LTones[0].StartFrame = 7350) and (LTones[0].GateFrames = 11025),
      'Tempo-crossing note uses independently floored endpoints');
    LClip := RenderNoteSequence(LSequence, 44100, DefaultSynthVoice, LRender);
    try
      Check(LClip.FrameCount = 29400, 'End-of-track silence retained after release');
    finally
      LClip.Free;
    end;
  finally
    LSequence.Free;
  end;
  LFile := DecodeMidiFile(FromHex(CGolden));
  LFile.Tracks[0].Events[0] := MakeMidiTempoEvent(0, 1);
  LFile.Tracks[0].Events[2] := MakeMidiTempoEvent(1, 1);
  LSequence := DecodeMidiNotes(EncodeMidiFile(LFile), DefaultMidiNoteOptions, LImport);
  try
    LClip := RenderNoteSequence(LSequence, 44100, DefaultSynthVoice, LRender);
    try
      Check((LClip.FrameCount = 0) and (LRender.SourceNotes = 1) and
        (LRender.RenderedNotes = 0) and (LRender.SubFrameNotes = 1),
        'Sub-frame gates are explicitly counted and do not produce release-only audio');
    finally
      LClip.Free;
    end;
  finally
    LSequence.Free;
  end;
end;

procedure CheckVoiceBindings;
var
  LNotes: TNoteGates;
  LTempos: TTempoChanges;
  LVoices: TNoteVoices;
  LSequence: TNoteSequence;
  LPlan: TFrameTones;
  LReference: TFrameTones;
  LClip: TAudioClip;
  LExpected: TAudioClip;
  LReport: TNoteRenderReport;
  LIndex: Integer;
  LChannel: Integer;
  LRejected: Boolean;
begin
  SetLength(LNotes, 2);
  LNotes[0].StartTick := 240;
  LNotes[0].EndTick := 960;
  LNotes[0].Pitch := 57;
  LNotes[0].Velocity := 100;
  LNotes[0].Voice := 1;
  LNotes[0].Track := 17;
  LNotes[1].StartTick := 0;
  LNotes[1].EndTick := 720;
  LNotes[1].Pitch := 69;
  LNotes[1].Velocity := 90;
  LNotes[1].Voice := 0;
  LNotes[1].Track := 23;
  SetLength(LTempos, 2);
  LTempos[0] := MakeTempoChange(0, 500000);
  LTempos[1] := MakeTempoChange(480, 250000);
  SetLength(LVoices, 2);
  for LIndex := 0 to 1 do
  begin
    LVoices[LIndex] := DefaultSynthVoice;
    LVoices[LIndex].Pan := LIndex * 2 - 1;
    LVoices[LIndex].Envelope.ReleaseSeconds := 0;
  end;
  LVoices[0].Shape := wsSine;
  LVoices[1].Shape := wsSquare;
  LSequence := TNoteSequence.Create(480, 960, LTempos, LNotes);
  try
    LPlan := PlanNoteTones(LSequence, 8000, LVoices, LReport);
    Check((LPlan[0].Voice.Shape = wsSquare) and (LPlan[0].Voice.Pan = 1) and
      (LPlan[1].Voice.Shape = wsSine) and (LPlan[1].Voice.Pan = -1),
      'Binding follows source voice, independently of note order and track');
    SetLength(LReference, 2);
    LReference[0].StartFrame := 2000;
    LReference[0].GateFrames := 4000;
    LReference[0].FrequencyHz := 220;
    LReference[0].Velocity := 100 / 127;
    LReference[0].Seed := 1;
    LReference[0].Voice := LVoices[1];
    LReference[1].StartFrame := 0;
    LReference[1].GateFrames := 5000;
    LReference[1].FrequencyHz := 440;
    LReference[1].Velocity := 90 / 127;
    LReference[1].Seed := 2;
    LReference[1].Voice := LVoices[0];
    LExpected := RenderFrameTones(LReference, 8000, 6000);
    try
      LClip := RenderNoteSequence(LSequence, 8000, LVoices, LReport);
      try
        Check((LClip.FrameCount = 6000) and (LReport.RenderedNotes = 2), 'Mapped extent');
        for LIndex := 0 to LClip.FrameCount - 1 do
        begin
          for LChannel := 0 to 1 do
          begin
            Check(LClip.SampleAt(LIndex, LChannel) = LExpected.SampleAt(LIndex, LChannel),
              'Mapped stereo PCM agrees with independently timed voices');
          end;
        end;
      finally
        LClip.Free;
      end;
    finally
      LExpected.Free;
    end;
    LVoices[1].Pan := 0;
    Check(LPlan[0].Voice.Pan = 1, 'Planned voice records are detached');
    SetLength(LVoices, 1);
    LRejected := False;
    try
      LPlan := PlanNoteTones(LSequence, 8000, LVoices, LReport);
    except
      on EAudio do
      begin
        LRejected := True;
      end;
    end;
    Check(LRejected and (LPlan[0].Voice.Pan = 1), 'Missing binding preserves prior plan');
  finally
    LSequence.Free;
  end;
end;

begin
  try
    CheckTime;
    CheckMidi;
    CheckFrameRendering;
    CheckVoiceBindings;
    WriteLn('Timing, MIDI and frame rendering checks passed');
  except
    on LException: Exception do
    begin
      WriteLn(StdErr, LException.Message);
      Halt(1);
    end;
  end;
end.
