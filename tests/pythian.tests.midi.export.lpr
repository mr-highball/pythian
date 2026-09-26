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
program pythian_tests_midi_export;

{$mode delphi}
{$H+}

uses
  SysUtils,
  pythian.time,
  pythian.music,
  pythian.midi.smf,
  pythian.midi.notes,
  pythian.midi.export;

procedure Check(const AValue: Boolean; const AMessage: String);
begin
  if not AValue then
  begin
    raise Exception.Create(AMessage);
  end;
end;

procedure SameBytes(const ALeft, ARight: TMidiBytes);
var
  LIndex: Integer;
begin
  Check(Length(ALeft) = Length(ARight), 'byte length');
  for LIndex := 0 to High(ALeft) do
  begin
    Check(ALeft[LIndex] = ARight[LIndex], 'byte mismatch ' + IntToStr(LIndex));
  end;
end;

function Gate(const AStart, AEnd, APitch, AVoice, AChannel: Integer): TNoteGate;
begin
  Result := Default(TNoteGate);
  Result.StartTick := AStart;
  Result.EndTick := AEnd;
  Result.Pitch := APitch;
  Result.Velocity := 100;
  Result.Voice := AVoice;
  Result.Channel := AChannel;
end;

procedure CheckProjection;
var
  LTempos: TTempoChanges;
  LGates: TNoteGates;
  LSource: TNoteSequence;
  LDecoded: TNoteSequence;
  LPlan: TNoteMidiExport;
  LFile: TMidiFile;
  LExpected: TMidiBytes;
  LBytes: TMidiBytes;
  LReport: TMidiNoteReport;
  LEvent: TMidiEvent;
  LTick: Int64;
begin
  SetLength(LTempos, 2);
  LTempos[0] := MakeTempoChange(0, 500001);
  LTempos[1] := MakeTempoChange(480, 600001);
  SetLength(LGates, 3);
  LGates[0] := Gate(480, 960, 60, 0, 2);
  LGates[1] := Gate(0, 480, 60, 0, 2);
  LGates[2] := Gate(0, 960, 64, 1, 3);
  LSource := TNoteSequence.Create(480, 1200, LTempos, LGates);
  LPlan := nil;
  LDecoded := nil;
  try
    LPlan := TNoteMidiExport.Create(LSource, []);
    LBytes := EncodeMidiNotes(LSource, [2, 3]);
    SameBytes(LBytes, LPlan.Encode);
    FreeAndNil(LSource);
    LPlan.EventAt(0, LTick, LEvent);
    LEvent.Data[0] := 255;
    SameBytes(LBytes, LPlan.Encode);
    LFile := Default(TMidiFile);
    LFile.TicksPerQuarter := 480;
    SetLength(LFile.Tracks, 1);
    SetLength(LFile.Tracks[0].Events, 8);
    LFile.Tracks[0].Events[0] := MakeMidiTempoEvent(0, 500001);
    LFile.Tracks[0].Events[1] := MakeMidiChannelEvent(0, $92, [60, 100]);
    LFile.Tracks[0].Events[2] := MakeMidiChannelEvent(0, $93, [64, 100]);
    LFile.Tracks[0].Events[3] := MakeMidiTempoEvent(480, 600001);
    LFile.Tracks[0].Events[4] := MakeMidiChannelEvent(0, $82, [60, 0]);
    LFile.Tracks[0].Events[5] := MakeMidiChannelEvent(0, $92, [60, 100]);
    LFile.Tracks[0].Events[6] := MakeMidiChannelEvent(480, $82, [60, 0]);
    LFile.Tracks[0].Events[7] := MakeMidiChannelEvent(0, $83, [64, 0]);
    LFile.Tracks[0].EndDeltaTicks := 240;
    LExpected := EncodeMidiFile(LFile);
    SameBytes(LExpected, LBytes);
    LDecoded := DecodeMidiNotes(LBytes, DefaultMidiNoteOptions, LReport);
    Check((LDecoded.NoteCount = 3) and (LDecoded.LengthTicks = 1200) and
      (LDecoded.GateAt(0).EndTick = 480) and (LDecoded.GateAt(2).StartTick = 480) and
      (LDecoded.GateAt(1).Channel = 3), 'strict note/channel/timing round trip');
    Check(LDecoded.FrameAtTick(1200, 44100) = 61740, 'tempo map preserved');
  finally
    LDecoded.Free;
    LPlan.Free;
    LSource.Free;
  end;
end;

procedure CheckAdmission;
var
  LTempos: TTempoChanges;
  LGates: TNoteGates;
  LSource: TNoteSequence;
  LPlan: TNoteMidiExport;
  LPrevious: TNoteMidiExport;
  LRejected: Boolean;
  LBytes: TMidiBytes;
begin
  SetLength(LTempos, 1);
  LTempos[0] := MakeTempoChange(0, 500000);
  SetLength(LGates, 2);
  LGates[0] := Gate(0, 480, 60, 0, -1);
  LGates[1] := Gate(240, 960, 60, 1, -1);
  LSource := TNoteSequence.Create(480, 960, LTempos, LGates);
  LPlan := nil;
  try
    LPlan := TNoteMidiExport.Create(LSource, [0, 1]);
    LPrevious := LPlan;
    LRejected := False;
    try
      LPlan := TNoteMidiExport.Create(LSource, [0, 0]);
    except
      on EMidiNoteExport do LRejected := True;
    end;
    Check(LRejected and (LPlan = LPrevious), 'overlap rejects and preserves old plan');
    LRejected := False;
    try
      LBytes := EncodeMidiNotes(LSource, []);
    except
      on EMidiNoteExport do LRejected := True;
    end;
    Check(LRejected, 'unspecified channels require explicit bindings');
    LRejected := False;
    try
      LBytes := EncodeMidiNotes(LSource, [0]);
    except
      on EMidiNoteExport do LRejected := True;
    end;
    Check(LRejected, 'missing voice binding rejects');
    LRejected := False;
    try
      LBytes := EncodeMidiNotes(LSource, [0, 16]);
    except
      on EMidiNoteExport do LRejected := True;
    end;
    Check(LRejected, 'out of range channel rejects');
    LBytes := LPlan.Encode;
    Check(Length(LBytes) > 22, 'prior valid plan still usable');
  finally
    LPlan.Free;
    LSource.Free;
  end;
end;

procedure CheckLongSilence;
var
  LTempos: TTempoChanges;
  LGates: TNoteGates;
  LSource: TNoteSequence;
  LDecoded: TNoteSequence;
  LReport: TMidiNoteReport;
  LBytes: TMidiBytes;
  LFile: TMidiFile;
begin
  SetLength(LTempos, 1);
  LTempos[0] := MakeTempoChange(0, 500000);
  SetLength(LGates, 1);
  LGates[0] := Gate(Integer(MaximumMidiVariableLength) + 1,
    Integer(MaximumMidiVariableLength) + 10, 60, 0, 0);
  LSource := TNoteSequence.Create(480, Integer(MaximumMidiVariableLength) + 20,
    LTempos, LGates);
  LDecoded := nil;
  try
    LBytes := EncodeMidiNotes(LSource, []);
    LFile := DecodeMidiFile(LBytes);
    Check((LFile.Tracks[0].Events[1].MetaType = $01) and
      (LFile.Tracks[0].Events[1].DeltaTicks = MaximumMidiVariableLength),
      'long silence bridged by native stream');
    LDecoded := DecodeMidiNotes(LBytes, DefaultMidiNoteOptions, LReport);
    Check((LDecoded.GateAt(0).StartTick = LGates[0].StartTick) and
      (LDecoded.LengthTicks = LSource.LengthTicks), 'bridged note positions retained');
  finally
    LDecoded.Free;
    LSource.Free;
  end;
end;

begin
  try
    CheckProjection;
    CheckAdmission;
    CheckLongSilence;
    WriteLn('MIDI note export: canonical ordering, round trip, channels, ownership and bridges passed');
  except
    on E: Exception do
    begin
      WriteLn(StdErr, E.ClassName, ': ', E.Message);
      Halt(1);
    end;
  end;
end.
