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
unit pythian.music.compose.longform;

{$mode delphi}
{$H+}

interface

uses
  pythian.music,
  pythian.music.compose;

const
  LongFormCompositionPolicyId = 'first-party-long-form-144-v1';
  LongFormCompositionBars = 144;
  LongFormCompositionSections = 9;
  LongFormCompositionTicks = 276480;

type
  TLongFormChordPath = array of TCompositionChord;

  TLongFormCompositionReport = record
    PolicyId: String;
    EventCount: Integer;
    BassEvents: Integer;
    MelodyEvents: Integer;
    DegreeSubstitutions: Integer;
    MaximumMelodyLeap: Integer;
    SectionBassEvents: array[0..8] of Integer;
    SectionMelodyEvents: array[0..8] of Integer;
  end;

{ Project a caller-owned 144-bar chord path into one continuous, owned
  two-part note sequence. The macroform, note timing and motif templates are
  first-party authored; this portable unit does not learn or call WFC. Every
  note has a chord-tone pitch and an explicit track/voice. Invalid input raises
  EAudio without publishing a partial sequence. }
function GenerateLongFormComposition(const AChords: TLongFormChordPath;
  out AReport: TLongFormCompositionReport): TNoteSequence;

implementation

uses
  SysUtils,
  pythian.audio,
  pythian.time;

const
  CMaximumEvents = 1000;
  CMinimumEvents = 400;
  CHalfBeatTicks = SourceFreeCompositionPPQ div 2;
  CBarTicks = SourceFreeCompositionPPQ * 4;
  CChordRootPc: array[TCompositionChord] of Integer = (0, 9, 5, 7, 4);
  CChordThirdPc: array[TCompositionChord] of Integer = (4, 0, 9, 11, 7);
  CChordFifthPc: array[TCompositionChord] of Integer = (7, 4, 0, 2, 11);
  CBassRoot: array[TCompositionChord] of Integer = (36, 33, 29, 31, 40);
  CBassFifth: array[TCompositionChord] of Integer = (43, 40, 36, 38, 47);
  CSectionNames: array[0..8] of String =
    ('intro', 'A', 'A-prime', 'B', 'A-return', 'C-bridge',
      'B-prime', 'A-final', 'outro');
  CBassVelocity: array[0..8] of Integer = (54, 70, 73, 76, 73, 59, 78, 82, 55);
  CMelodyVelocity: array[0..8] of Integer = (60, 77, 80, 83, 78, 66, 86, 88, 58);

procedure Require(const ACondition: Boolean; const AMessage: String);
begin
  if not ACondition then raise EAudio.Create(AMessage);
end;

function ChordPc(const AChord: TCompositionChord; const ADegree: Integer): Integer;
begin
  case ADegree of
    0: Result := CChordRootPc[AChord];
    1: Result := CChordThirdPc[AChord];
    2: Result := CChordFifthPc[AChord];
  else
    raise EAudio.Create('Long-form degree outside root/third/fifth');
  end;
end;

function PickMelodyPitch(const AChord: TCompositionChord;
  const ADegree, APrevious: Integer; out ASubstituted: Boolean): Integer;
var
  LPitch, LDegree, LScore, LBestScore, LLeap: Integer;
begin
  Result := -1;
  LBestScore := MaxInt;
  ASubstituted := False;
  for LPitch := 60 to 79 do
    for LDegree := 0 to 2 do
    begin
      if (LPitch mod 12) <> ChordPc(AChord, LDegree) then Continue;
      LLeap := Abs(LPitch - APrevious);
      if LLeap > 7 then Continue;
      LScore := LLeap * 10;
      if LDegree <> ADegree then Inc(LScore, 45);
      if (LScore < LBestScore) or
        ((LScore = LBestScore) and ((Result < 0) or (LPitch < Result))) then
      begin
        Result := LPitch;
        LBestScore := LScore;
        ASubstituted := LDegree <> ADegree;
      end;
    end;
  Require(Result >= 0, 'No bounded chord tone for melody voice leading');
end;

procedure AddGate(var AGates: TNoteGates; var ACount: Integer;
  const ABar, AHalfBeat, ADuration, APitch, AVelocity, APart: Integer);
var
  LGate: TNoteGate;
begin
  Require((ABar >= 0) and (ABar < LongFormCompositionBars) and
    (AHalfBeat >= 0) and (AHalfBeat < 8) and (ADuration > 0) and
    (AHalfBeat + ADuration <= 8), 'Long-form note lies outside its bar');
  Require(ACount < Length(AGates), 'Long-form note budget exhausted');
  LGate.StartTick := ABar * CBarTicks + AHalfBeat * CHalfBeatTicks;
  LGate.EndTick := LGate.StartTick + ADuration * CHalfBeatTicks;
  LGate.Pitch := APitch;
  LGate.Velocity := AVelocity;
  LGate.Track := APart;
  LGate.Voice := APart;
  LGate.Channel := 0;
  AGates[ACount] := LGate;
  Inc(ACount);
end;

procedure AddBass(const AChord: TCompositionChord; const ABar: Integer;
  var AGates: TNoteGates; var ACount: Integer;
  var AReport: TLongFormCompositionReport);
var
  LSection, LBarInSection, LVelocity: Integer;
begin
  LSection := ABar div 16;
  LBarInSection := ABar mod 16;
  LVelocity := CBassVelocity[LSection];
  if LSection = 5 then
    AddGate(AGates, ACount, ABar, 0, 6, CBassRoot[AChord], LVelocity, 0)
  else if (LSection = 0) or (LSection = 8) then
  begin
    AddGate(AGates, ACount, ABar, 0, 5, CBassRoot[AChord], LVelocity, 0);
    if (LBarInSection mod 4) = 3 then
      AddGate(AGates, ACount, ABar, 5, 2, CBassFifth[AChord],
        LVelocity - 7, 0);
  end
  else if (LSection = 3) or (LSection = 6) then
  begin
    AddGate(AGates, ACount, ABar, 0, 3, CBassRoot[AChord], LVelocity, 0);
    AddGate(AGates, ACount, ABar, 3, 2, CBassFifth[AChord],
      LVelocity - 6, 0);
    if (LBarInSection mod 2) = 0 then
      AddGate(AGates, ACount, ABar, 6, 2, CBassRoot[AChord],
        LVelocity - 9, 0);
  end
  else
  begin
    AddGate(AGates, ACount, ABar, 0, 4, CBassRoot[AChord], LVelocity, 0);
    if (LBarInSection mod 2) = 0 then
      AddGate(AGates, ACount, ABar, 4, 3, CBassFifth[AChord],
        LVelocity - 8, 0);
  end;
  Inc(AReport.BassEvents, ACount - AReport.EventCount);
  Inc(AReport.SectionBassEvents[LSection], ACount - AReport.EventCount);
  AReport.EventCount := ACount;
end;

procedure AddMelodyNote(const AChord: TCompositionChord;
  const ABar, AHalfBeat, ADuration, ADegree: Integer;
  var APreviousPitch: Integer; var AGates: TNoteGates; var ACount: Integer;
  var AReport: TLongFormCompositionReport);
var
  LSection, LDegree, LPitch, LLeap: Integer;
  LSubstituted: Boolean;
begin
  LSection := ABar div 16;
  LDegree := ADegree;
  if (LSection = 2) or (LSection = 7) then
    LDegree := (LDegree + 1) mod 3;
  if (LSection = 6) then
    LDegree := (LDegree + 2) mod 3;
  if (ABar = LongFormCompositionBars - 1) then LDegree := 0;
  LPitch := PickMelodyPitch(AChord, LDegree, APreviousPitch, LSubstituted);
  LLeap := Abs(LPitch - APreviousPitch);
  if LLeap > AReport.MaximumMelodyLeap then
    AReport.MaximumMelodyLeap := LLeap;
  if LSubstituted then Inc(AReport.DegreeSubstitutions);
  AddGate(AGates, ACount, ABar, AHalfBeat, ADuration, LPitch,
    CMelodyVelocity[LSection], 1);
  APreviousPitch := LPitch;
  Inc(AReport.MelodyEvents);
  Inc(AReport.SectionMelodyEvents[LSection]);
  AReport.EventCount := ACount;
end;

procedure AddMelody(const AChord: TCompositionChord; const ABar: Integer;
  var APreviousPitch: Integer; var AGates: TNoteGates; var ACount: Integer;
  var AReport: TLongFormCompositionReport);
var
  LSection, LBarInPhrase: Integer;
begin
  LSection := ABar div 16;
  LBarInPhrase := ABar mod 4;
  if LSection = 0 then
  begin
    if (ABar mod 2) = 0 then
      AddMelodyNote(AChord, ABar, 0, 4, LBarInPhrase mod 3,
        APreviousPitch, AGates, ACount, AReport);
    if LBarInPhrase = 3 then
      AddMelodyNote(AChord, ABar, 4, 3, 2,
        APreviousPitch, AGates, ACount, AReport);
  end
  else if LSection = 5 then
  begin
    if (LBarInPhrase mod 2) = 0 then
    begin
      AddMelodyNote(AChord, ABar, 0, 4, 1,
        APreviousPitch, AGates, ACount, AReport);
      AddMelodyNote(AChord, ABar, 5, 2, 0,
        APreviousPitch, AGates, ACount, AReport);
    end
    else
      AddMelodyNote(AChord, ABar, 2, 4, 2,
        APreviousPitch, AGates, ACount, AReport);
  end
  else if LSection = 8 then
  begin
    AddMelodyNote(AChord, ABar, 0, 4, (3 - LBarInPhrase) mod 3,
      APreviousPitch, AGates, ACount, AReport);
    if (ABar >= LongFormCompositionBars - 4) and (LBarInPhrase = 3) then
      AddMelodyNote(AChord, ABar, 4, 4, 0,
        APreviousPitch, AGates, ACount, AReport);
  end
  else if (LSection = 3) or (LSection = 6) then
  begin
    case LBarInPhrase of
      0: begin
        AddMelodyNote(AChord, ABar, 1, 2, 2,
          APreviousPitch, AGates, ACount, AReport);
        AddMelodyNote(AChord, ABar, 4, 2, 1,
          APreviousPitch, AGates, ACount, AReport);
      end;
      1: begin
        AddMelodyNote(AChord, ABar, 0, 2, 0,
          APreviousPitch, AGates, ACount, AReport);
        AddMelodyNote(AChord, ABar, 3, 2, 2,
          APreviousPitch, AGates, ACount, AReport);
        AddMelodyNote(AChord, ABar, 6, 1, 1,
          APreviousPitch, AGates, ACount, AReport);
      end;
      2: begin
        AddMelodyNote(AChord, ABar, 1, 2, 1,
          APreviousPitch, AGates, ACount, AReport);
        AddMelodyNote(AChord, ABar, 4, 3, 0,
          APreviousPitch, AGates, ACount, AReport);
      end;
      3: begin
        AddMelodyNote(AChord, ABar, 0, 2, 2,
          APreviousPitch, AGates, ACount, AReport);
        AddMelodyNote(AChord, ABar, 2, 2, 1,
          APreviousPitch, AGates, ACount, AReport);
        AddMelodyNote(AChord, ABar, 5, 3, 0,
          APreviousPitch, AGates, ACount, AReport);
      end;
    end;
  end
  else
  begin
    case LBarInPhrase of
      0: begin
        AddMelodyNote(AChord, ABar, 0, 2, 0,
          APreviousPitch, AGates, ACount, AReport);
        AddMelodyNote(AChord, ABar, 3, 1, 1,
          APreviousPitch, AGates, ACount, AReport);
        AddMelodyNote(AChord, ABar, 5, 2, 2,
          APreviousPitch, AGates, ACount, AReport);
      end;
      1: begin
        AddMelodyNote(AChord, ABar, 0, 2, 1,
          APreviousPitch, AGates, ACount, AReport);
        AddMelodyNote(AChord, ABar, 2, 2, 2,
          APreviousPitch, AGates, ACount, AReport);
        AddMelodyNote(AChord, ABar, 5, 2, 1,
          APreviousPitch, AGates, ACount, AReport);
      end;
      2: begin
        AddMelodyNote(AChord, ABar, 0, 4, 0,
          APreviousPitch, AGates, ACount, AReport);
        AddMelodyNote(AChord, ABar, 4, 2, 2,
          APreviousPitch, AGates, ACount, AReport);
      end;
      3: begin
        AddMelodyNote(AChord, ABar, 0, 2, 2,
          APreviousPitch, AGates, ACount, AReport);
        AddMelodyNote(AChord, ABar, 3, 1, 1,
          APreviousPitch, AGates, ACount, AReport);
        AddMelodyNote(AChord, ABar, 5, 3, 0,
          APreviousPitch, AGates, ACount, AReport);
      end;
    end;
  end;
end;

function GenerateLongFormComposition(const AChords: TLongFormChordPath;
  out AReport: TLongFormCompositionReport): TNoteSequence;
var
  LGates: TNoteGates;
  LTempo: TTempoChanges;
  LCount, LBar, LSection, LPreviousPitch: Integer;
begin
  Result := nil;
  AReport := Default(TLongFormCompositionReport);
  AReport.PolicyId := LongFormCompositionPolicyId;
  Require(Length(AChords) = LongFormCompositionBars,
    'Long-form chord path must contain exactly 144 bars');
  for LBar := 0 to High(AChords) do
    Require((Ord(AChords[LBar]) >= Ord(Low(TCompositionChord))) and
      (Ord(AChords[LBar]) <= Ord(High(TCompositionChord))),
      'Long-form path contains an unsupported chord');
  Require((AChords[0] = ccC) and (AChords[143] = ccC),
    'Long-form path must open and close on C');
  SetLength(LGates, CMaximumEvents);
  LCount := 0;
  LPreviousPitch := 67;
  for LBar := 0 to LongFormCompositionBars - 1 do
  begin
    AddBass(AChords[LBar], LBar, LGates, LCount, AReport);
    AddMelody(AChords[LBar], LBar, LPreviousPitch, LGates, LCount, AReport);
  end;
  Require((LCount >= CMinimumEvents) and (LCount <= CMaximumEvents),
    'Long-form event count outside declared bounds');
  Require((AReport.BassEvents + AReport.MelodyEvents = LCount) and
    (AReport.MaximumMelodyLeap <= 7),
    'Long-form note ownership or melodic movement failed');
  for LSection := 0 to LongFormCompositionSections - 1 do
    Require((AReport.SectionBassEvents[LSection] > 0) and
      (AReport.SectionMelodyEvents[LSection] > 0) and
      (CSectionNames[LSection] <> ''),
      'A long-form section lacks a part or form identity');
  SetLength(LGates, LCount);
  SetLength(LTempo, 1);
  LTempo[0] := MakeTempoChange(0, SourceFreeCompositionTempoUsPerQuarter);
  Result := TNoteSequence.Create(SourceFreeCompositionPPQ,
    LongFormCompositionTicks, LTempo, LGates);
  AReport.EventCount := LCount;
end;

end.
