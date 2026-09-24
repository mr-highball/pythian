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
program pythian_tests_note_events;

{$mode delphi}
{$H+}
{$apptype console}

uses
  SysUtils,
  pythian.music,
  pythian.time,
  pythian.wfc.note.events;

procedure Check(const ACondition: Boolean; const AMessage: String);
begin
  if not ACondition then
    raise Exception.Create(AMessage);
end;

function MakeGate(const AStart, AEnd, AVoice, ATrack, AChannel, APitch,
  AVelocity: Integer): TNoteGate;
begin
  Result := Default(TNoteGate);
  Result.StartTick := AStart;
  Result.EndTick := AEnd;
  Result.Voice := AVoice;
  Result.Track := ATrack;
  Result.Channel := AChannel;
  Result.Pitch := APitch;
  Result.Velocity := AVelocity;
end;

function SameGate(const ALeft, ARight: TNoteGate): Boolean;
begin
  Result := (ALeft.StartTick = ARight.StartTick) and
    (ALeft.EndTick = ARight.EndTick) and (ALeft.Pitch = ARight.Pitch) and
    (ALeft.Velocity = ARight.Velocity) and (ALeft.Track = ARight.Track) and
    (ALeft.Voice = ARight.Voice) and (ALeft.Channel = ARight.Channel);
end;

function ContainsGate(const AGates: TNoteGates; const AGate: TNoteGate): Boolean;
var
  LIndex: Integer;
begin
  Result := False;
  for LIndex := 0 to High(AGates) do
    if SameGate(AGates[LIndex], AGate) then
      Exit(True);
end;

var
  LGates: TNoteGates;
  LTempos: TTempoChanges;
  LSequence: TNoteSequence;
  LDecoded: TNoteSequence;
  LDecodedAgain: TNoteSequence;
  LClock: TTempoMap;
  LPath: TJointNoteEventPath;
  LReplay: TJointNoteEventPath;
  LCorrupt: TJointNoteEventPath;
  LEmptyPath: TJointNoteEventPath;
  LEmptySequence: TNoteSequence;
  LEmptyDecoded: TNoteSequence;
  LDuplicateSequence: TNoteSequence;
  LDuplicateGates: TNoteGates;
  LWideSequence: TNoteSequence;
  LWideGates: TNoteGates;
  LBadQuantumRejected: Boolean;
  LIndex: Integer;
  LOriginalDecoded: TNoteSequence;
  LRejected: Boolean;
begin
  LSequence := nil;
  LDecoded := nil;
  LDecodedAgain := nil;
  LEmptySequence := nil;
  LEmptyDecoded := nil;
  LDuplicateSequence := nil;
  LWideSequence := nil;
  try
    SetLength(LGates, 5);
    { Deliberately unordered: shared onset, unequal ends, other-voice overlap,
      same-pitch retrigger, then a joint rest and trailing silence. }
    LGates[0] := MakeGate(400, 460, 10, 7, 0, 60, 91);
    LGates[1] := MakeGate(110, 310, 20, 8, 1, 72, 84);
    LGates[2] := MakeGate(0, 120, 10, 7, 0, 60, 100);
    LGates[3] := MakeGate(0, 60, 20, 8, 1, 67, 77);
    LGates[4] := MakeGate(200, 260, 10, 7, 0, 60, 96);
    SetLength(LTempos, 2);
    LTempos[0] := MakeTempoChange(0, 500000);
    LTempos[1] := MakeTempoChange(300, 420000);
    LSequence := TNoteSequence.Create(480, 600, LTempos, LGates);
    LPath := EncodeJointNoteEvents(LSequence, 10, 20, 1);
    Check(Length(LPath.Tokens) = 4, 'Four exact-onset bundles expected');
    Check(LPath.Tokens[0] = '0|10,7,0,60,100,120|20,8,1,67,77,60',
      'First simultaneous bundle is not canonical');
    Check(LPath.Tokens[1] = '110|20,8,1,72,84,200',
      'Other-part overlap/delta did not survive');
    Check(LPath.Tokens[2] = '90|10,7,0,60,96,60',
      'Same-pitch retrigger was merged or lost');
    Check(LPath.Tokens[3] = '200|10,7,0,60,91,60',
      'Rest delta or final retrigger is incorrect');
    LDecoded := DecodeJointNoteEvents(LPath);
    Check((LDecoded.TicksPerQuarter = LSequence.TicksPerQuarter) and
      (LDecoded.LengthTicks = LSequence.LengthTicks), 'PPQ or extent changed');
    Check(LDecoded.NoteCount = LSequence.NoteCount, 'Gate count changed');
    for LIndex := 0 to High(LGates) do
      Check(ContainsGate(LDecoded.CopyGates, LGates[LIndex]),
        'Exact source gate fields did not round-trip');
    LClock := LDecoded.CopyClock;
    try
      Check((LClock.ChangeCount = 2) and
        (LClock.ChangeAt(0).Tick = 0) and
        (LClock.ChangeAt(0).MicrosecondsPerQuarter = 500000) and
        (LClock.ChangeAt(1).Tick = 300) and
        (LClock.ChangeAt(1).MicrosecondsPerQuarter = 420000),
        'Tempo map did not round-trip exactly');
    finally
      LClock.Free;
    end;
    LDecodedAgain := DecodeJointNoteEvents(EncodeJointNoteEvents(LDecoded, 10, 20, 1));
    LReplay := EncodeJointNoteEvents(LDecodedAgain, 10, 20, 1);
    Check(Length(LReplay.Tokens) = Length(LPath.Tokens), 'Replay token count differs');
    for LIndex := 0 to High(LPath.Tokens) do
      Check(LReplay.Tokens[LIndex] = LPath.Tokens[LIndex],
        'Encode/decode replay is not deterministic');

    LBadQuantumRejected := False;
    try
      LReplay := EncodeJointNoteEvents(LSequence, 10, 20, 2);
    except
      on E: Exception do
        LBadQuantumRejected := True;
    end;
    Check(LBadQuantumRejected, 'Non-one-tick quantum was accepted');
    Check((Length(LReplay.Tokens) = Length(LPath.Tokens)) and
      (LReplay.Tokens[0] = LPath.Tokens[0]),
      'Rejected quantum encode replaced the prior path');

    LGates := nil;
    LEmptySequence := TNoteSequence.Create(480, 600, LTempos, LGates);
    LEmptyPath := EncodeJointNoteEvents(LEmptySequence, 10, 20, 1);
    Check(Length(LEmptyPath.Tokens) = 0,
      'Empty phrase invented a note-event token');
    LEmptyDecoded := DecodeJointNoteEvents(LEmptyPath);
    Check((LEmptyDecoded.NoteCount = 0) and (LEmptyDecoded.LengthTicks = 600),
      'All-silence phrase did not preserve its explicit extent');

    SetLength(LDuplicateGates, 2);
    LDuplicateGates[0] := MakeGate(0, 60, 10, 7, 0, 60, 96);
    LDuplicateGates[1] := LDuplicateGates[0];
    LDuplicateSequence := TNoteSequence.Create(480, 600, LTempos, LDuplicateGates);
    LBadQuantumRejected := False;
    try
      EncodeJointNoteEvents(LDuplicateSequence, 10, 20, 1);
    except
      on E: Exception do
        LBadQuantumRejected := True;
    end;
    Check(LBadQuantumRejected, 'Duplicate source gate identity was accepted');

    SetLength(LWideGates, MaximumJointNoteEventWidth + 1);
    for LIndex := 0 to High(LWideGates) do
      LWideGates[LIndex] := MakeGate(0, 20 + LIndex, 10 + (LIndex mod 2),
        LIndex, -1, 40 + LIndex, 80);
    LWideSequence := TNoteSequence.Create(480, 600, LTempos, LWideGates);
    LBadQuantumRejected := False;
    try
      EncodeJointNoteEvents(LWideSequence, 10, 11, 1);
    except
      on E: Exception do
        LBadQuantumRejected := True;
    end;
    Check(LBadQuantumRejected, 'Seventeen-way simultaneous bundle was accepted');

    LCorrupt := LPath;
    LCorrupt.Tokens[1] := '110|20,08,1,72,84,200';
    LOriginalDecoded := LDecoded;
    LRejected := False;
    try
      LDecoded := DecodeJointNoteEvents(LCorrupt);
    except
      on E: Exception do
        LRejected := True;
    end;
    Check(LRejected, 'Noncanonical token was accepted');
    Check(LDecoded = LOriginalDecoded,
      'Rejected decode replaced caller output with a partial sequence');
    WriteLn('PASS note-event codec: exact 2-part round-trip, retriggers, overlap, rest, empty phrase, replay, bounds and rejection preservation');
  finally
    LDecodedAgain.Free;
    LDecoded.Free;
    LEmptyDecoded.Free;
    LEmptySequence.Free;
    LDuplicateSequence.Free;
    LWideSequence.Free;
    LSequence.Free;
  end;
end.
