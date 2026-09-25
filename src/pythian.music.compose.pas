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
unit pythian.music.compose;

{$mode delphi}
{$H+}

interface

uses
  pythian.audio,
  pythian.music;

const
  SourceFreeCompositionPolicyId = 'source-free-composition-scaffold-v1';
  SourceFreeCompositionPPQ = 480;
  SourceFreeCompositionTempoUsPerQuarter = 555556;
  SourceFreeCompositionBars = 16;
  SourceFreeCompositionTicks = 30720;

type
  TCompositionScaffoldReport = record
    PolicyId: String;
    Seed: Cardinal;
    Generator: String;
    SourceKind: String;
    LearnedWfc: Boolean;
    PPQ: Integer;
    TempoUsPerQuarter: Integer;
    BarCount: Integer;
    EventCount: Integer;
    BassSilentBeats: Integer;
    MelodySilentBeats: Integer;
    SimultaneousOverlapBeats: Integer;
    MelodyDegreeAdjustments: Integer;
    SeedGeneratedBaseASlots: Integer;
    FormDerivedAprimeSlots: Integer;
    FormDerivedBForcedSlots: Integer;
    FormComplementBOptionalSlots: Integer;
    ReturnRecallSlots: Integer;
    AuthoredCadenceSlots: Integer;
    AuthoredSourcePhraseUnionCount: Integer;
    GeneratedPhraseComparisonCount: Integer;
    CopiedPhraseRunCount: Integer;
    ModelHash: String;
    TokenHash: String;
    EventLedger: UTF8String;
    Text: UTF8String;
  end;

{ Build one bounded 16-bar source-free two-part composition. Choices are
  deterministic for ASeed. Structural failure raises EAudio and returns no
  sequence; no WFC model or recording is consulted. The returned sequence is
  caller-owned. Report includes explicit lineage, provenance and event rows. }
function GenerateSourceFreeComposition(const ASeed: Cardinal;
  out AReport: TCompositionScaffoldReport): TNoteSequence;

implementation

uses
  SysUtils,
  Math,
  pythian.time;

const
  CBeatsPerBar = 4;
  CBeatsPerPassage = 64;
  CPhraseBeats = 16;
  CSampleRate = 44100;
  CMaximumNotes = 128;

type
  TChord = (chC, chAm, chF, chG, chEm);

  TAction = record
    Present: Boolean;
    OffsetHalfBeats: Integer;
    DurationHalfBeats: Integer;
    Degree: Integer;
    Pitch: Integer;
  end;

  TPartActions = array[0..CBeatsPerPassage - 1] of TAction;
  TPassageActions = array[0..1] of TPartActions;

const
  CChordSchedule: array[0..15] of TChord = (
    chC, chAm, chF, chG,
    chC, chAm, chF, chG,
    chF, chG, chEm, chAm,
    chF, chG, chC, chC);

  CChordName: array[TChord] of String = ('C', 'Am', 'F', 'G', 'Em');
  CChordRootPc: array[TChord] of Integer = (0, 9, 5, 7, 4);
  CChordThirdPc: array[TChord] of Integer = (4, 0, 9, 11, 7);
  CChordFifthPc: array[TChord] of Integer = (7, 4, 0, 2, 11);
  CBassRoot: array[TChord] of Integer = (36, 33, 29, 31, 40);
  CBassFifth: array[TChord] of Integer = (43, 40, 36, 38, 47);

procedure Require(const ACondition: Boolean; const AMessage: String);
begin
  if not ACondition then
  begin
    raise EAudio.Create(AMessage);
  end;
end;

procedure AppendLine(var AText: UTF8String; const ALine: String);
begin
  AText := AText + UTF8String(ALine) + #10;
end;

function ChordAtBeat(const ABeat: Integer): TChord;
begin
  Result := CChordSchedule[(ABeat div CBeatsPerBar) mod Length(CChordSchedule)];
end;

function ChordPitchClass(const AChord: TChord; const ADegree: Integer): Integer;
begin
  case ADegree of
    0:
      Result := CChordRootPc[AChord];
    1:
      Result := CChordThirdPc[AChord];
    2:
      Result := CChordFifthPc[AChord];
  else
    raise EAudio.Create('Scale degree must be root, third or fifth');
  end;
end;

function PitchClass(const APitch: Integer): Integer;
begin
  Result := ((APitch mod 12) + 12) mod 12;
end;

function NextRandom(var AState: Cardinal): Cardinal;
begin
  if AState = 0 then
  begin
    AState := $6D2B79F5;
  end;
  AState := AState xor (AState shl 13);
  AState := AState xor (AState shr 17);
  AState := AState xor (AState shl 5);
  Result := AState;
end;

function Pick(const ABound: Integer; var AState: Cardinal): Integer;
begin
  Require(ABound > 0, 'Random choice bound must be positive');
  Result := Integer(NextRandom(AState) mod Cardinal(ABound));
end;

function EmptyAction: TAction;
begin
  Result.Present := False;
  Result.OffsetHalfBeats := 0;
  Result.DurationHalfBeats := 0;
  Result.Degree := 0;
  Result.Pitch := -1;
end;

function FlipRootFifth(const ADegree: Integer): Integer;
begin
  if ADegree = 0 then
  begin
    Exit(2);
  end;
  if ADegree = 2 then
  begin
    Exit(0);
  end;
  raise EAudio.Create('Root/fifth theme transform received a non-root/fifth degree');
end;

function NewAction(const APart, ABeat: Integer; const AForced: Boolean;
  var AState: Cardinal): TAction;
var
  LChoice: Integer;
begin
  Result := EmptyAction;
  if not AForced and (Pick(2, AState) <> 0) then
  begin
    Exit;
  end;
  Result.Present := True;
  if (ABeat mod CBeatsPerBar) = 0 then
  begin
    Result.OffsetHalfBeats := 0;
  end
  else
  begin
    Result.OffsetHalfBeats := Pick(2, AState);
  end;
  if Result.OffsetHalfBeats = 0 then
  begin
    Result.DurationHalfBeats := 1 + Pick(2, AState);
  end
  else
  begin
    Result.DurationHalfBeats := 1;
  end;
  if (APart = 0) and ((ABeat mod CBeatsPerBar) = 0) then
  begin
    Result.Degree := 0;
  end
  else if APart = 0 then
  begin
    Result.Degree := Pick(2, AState) * 2;
  end
  else if AForced then
  begin
    LChoice := Pick(2, AState);
    Result.Degree := LChoice * 2;
  end
  else
  begin
    Result.Degree := Pick(3, AState);
  end;
end;

procedure GenerateBaseA(const ASeed: Cardinal; out ABase: TPassageActions);
var
  LState: Cardinal;
  LBeat: Integer;
  LPart: Integer;
  LBeatInBar: Integer;
  LForced: Boolean;
begin
  LState := ASeed xor $A511E9B3;
  if LState = 0 then
  begin
    LState := 1;
  end;
  for LPart := 0 to 1 do
  begin
    for LBeat := 0 to CPhraseBeats - 1 do
    begin
      LBeatInBar := LBeat mod CBeatsPerBar;
      LForced := (LBeatInBar = 0) or (LBeatInBar = 2);
      ABase[LPart][LBeat] := NewAction(LPart, LBeat, LForced, LState);
    end;
  end;
end;

procedure GeneratePassageActions(const ASeed: Cardinal;
  out AActions: TPassageActions);
var
  LBase: TPassageActions;
  LBState: Cardinal;
  LPart: Integer;
  LBeat: Integer;
  LIndex: Integer;
  LAction: TAction;
  LBeatInBar: Integer;
begin
  GenerateBaseA(ASeed, LBase);
  for LPart := 0 to 1 do
  begin
    for LBeat := 0 to CPhraseBeats - 1 do
    begin
      AActions[LPart][LBeat] := LBase[LPart][LBeat];
    end;
  end;

  { A-prime keeps A's event grid and duration profile. }
  for LPart := 0 to 1 do
  begin
    for LBeat := 0 to CPhraseBeats - 1 do
    begin
      LAction := LBase[LPart][LBeat];
      if LAction.Present and (LBeat in [2, 10]) then
      begin
        LAction.Degree := FlipRootFifth(LAction.Degree);
      end;
      AActions[LPart][CPhraseBeats + LBeat] := LAction;
    end;
  end;

  { B complements A's optional beat-one/beat-three rhythm and reverses the
    root/fifth choices at each forced beat-two attack. }
  LBState := ASeed xor $C2B2AE35;
  if LBState = 0 then
  begin
    LBState := 1;
  end;
  for LPart := 0 to 1 do
  begin
    for LBeat := 0 to CPhraseBeats - 1 do
    begin
      LBeatInBar := LBeat mod CBeatsPerBar;
      LAction := LBase[LPart][LBeat];
      if LBeatInBar in [1, 3] then
      begin
        if LAction.Present then
        begin
          LAction := EmptyAction;
        end
        else
        begin
          LAction := NewAction(LPart, LBeat, True, LBState);
        end;
      end
      else if (LBeatInBar = 2) and LAction.Present then
      begin
        LAction.Degree := FlipRootFifth(LAction.Degree);
      end;
      AActions[LPart][2 * CPhraseBeats + LBeat] := LAction;
    end;
  end;

  { Return recalls A's first 14 beats and ends with a two-part rest. }
  for LPart := 0 to 1 do
  begin
    for LIndex := 0 to CPhraseBeats - 1 do
    begin
      if LIndex < CPhraseBeats - 1 then
      begin
        AActions[LPart][3 * CPhraseBeats + LIndex] := LBase[LPart][LIndex];
      end
      else
      begin
        AActions[LPart][3 * CPhraseBeats + LIndex] := EmptyAction;
      end;
    end;
  end;
  for LPart := 0 to 1 do
  begin
    AActions[LPart][3 * CPhraseBeats + 14] := EmptyAction;
    AActions[LPart][3 * CPhraseBeats + 14].Present := True;
    AActions[LPart][3 * CPhraseBeats + 14].OffsetHalfBeats := 0;
    AActions[LPart][3 * CPhraseBeats + 14].DurationHalfBeats := 2;
    AActions[LPart][3 * CPhraseBeats + 14].Degree := 0;
    AActions[LPart][3 * CPhraseBeats + 14].Pitch := -1;
  end;
end;

function TryMelodyPitch(const AChord: TChord; const ADegree,
  APreviousPitch: Integer; out APitch: Integer): Boolean;
var
  LPitch: Integer;
  LDistance: Integer;
  LBestDistance: Integer;
  LTarget: Integer;
begin
  LTarget := ChordPitchClass(AChord, ADegree);
  APitch := -1;
  LBestDistance := High(Integer);
  for LPitch := 60 to 79 do
  begin
    if PitchClass(LPitch) = LTarget then
    begin
      LDistance := Abs(LPitch - APreviousPitch);
      if LDistance < LBestDistance then
      begin
        APitch := LPitch;
        LBestDistance := LDistance;
      end;
    end;
  end;
  Result := (APitch >= 0) and (LBestDistance <= 7);
end;

procedure ProjectPitches(var AActions: TPassageActions;
  out AConstraintDegreeAdjustments: Integer);
var
  LBeat: Integer;
  LPreviousMelody: Integer;
  LChord: TChord;
  LAction: TAction;
  LOriginalDegree: Integer;
  LTry: Integer;
  LResolved: Boolean;
  LPitch: Integer;
begin
  AConstraintDegreeAdjustments := 0;
  LPreviousMelody := 67;
  for LBeat := 0 to CBeatsPerPassage - 1 do
  begin
    LChord := ChordAtBeat(LBeat);
    LAction := AActions[0][LBeat];
    if LAction.Present then
    begin
      if LAction.Degree = 0 then
      begin
        LAction.Pitch := CBassRoot[LChord];
      end
      else if LAction.Degree = 2 then
      begin
        LAction.Pitch := CBassFifth[LChord];
      end
      else
      begin
        raise EAudio.Create('Bass degree must be root or fifth');
      end;
      AActions[0][LBeat] := LAction;
    end;
    LAction := AActions[1][LBeat];
    if LAction.Present then
    begin
      LOriginalDegree := LAction.Degree;
      LResolved := False;
      for LTry := 0 to 2 do
      begin
        LAction.Degree := (LOriginalDegree + LTry) mod 3;
        if TryMelodyPitch(LChord, LAction.Degree, LPreviousMelody, LPitch) then
        begin
          LAction.Pitch := LPitch;
          LResolved := True;
          Break;
        end;
      end;
      Require(LResolved,
        'No chord tone satisfies the seven-semitone melody bound for this seed');
      if LAction.Degree <> LOriginalDegree then
      begin
        Inc(AConstraintDegreeAdjustments);
      end;
      LPreviousMelody := LAction.Pitch;
      AActions[1][LBeat] := LAction;
    end;
  end;
end;

function CountSilentBeats(const AActions: TPartActions): Integer;
var
  LBeat: Integer;
begin
  Result := 0;
  for LBeat := 0 to CBeatsPerPassage - 1 do
  begin
    if not AActions[LBeat].Present then
    begin
      Inc(Result);
    end;
  end;
end;

function CountOverlapBeats(const AActions: TPassageActions): Integer;
var
  LBeat: Integer;
  LBassStart: Integer;
  LBassEnd: Integer;
  LMelodyStart: Integer;
  LMelodyEnd: Integer;
begin
  Result := 0;
  for LBeat := 0 to CBeatsPerPassage - 1 do
  begin
    if AActions[0][LBeat].Present and AActions[1][LBeat].Present then
    begin
      LBassStart := AActions[0][LBeat].OffsetHalfBeats;
      LBassEnd := LBassStart + AActions[0][LBeat].DurationHalfBeats;
      LMelodyStart := AActions[1][LBeat].OffsetHalfBeats;
      LMelodyEnd := LMelodyStart + AActions[1][LBeat].DurationHalfBeats;
      if Max(LBassStart, LMelodyStart) < Min(LBassEnd, LMelodyEnd) then
      begin
        Inc(Result);
      end;
    end;
  end;
end;

function CountDegreeChanges(const ALeft, ARight: TPartActions;
  const AStart, ACount: Integer): Integer;
var
  LIndex: Integer;
  LBeat: Integer;
begin
  Result := 0;
  for LIndex := 0 to ACount - 1 do
  begin
    LBeat := AStart + LIndex;
    if ALeft[LBeat].Present and ARight[LBeat].Present and
      (ALeft[LBeat].Degree <> ARight[LBeat].Degree) then
    begin
      Inc(Result);
    end;
  end;
end;

function CountRhythmChanges(const ALeft, ARight: TPartActions;
  const AStart, ACount: Integer): Integer;
var
  LIndex: Integer;
  LBeat: Integer;
begin
  Result := 0;
  for LIndex := 0 to ACount - 1 do
  begin
    LBeat := AStart + LIndex;
    if (ALeft[LBeat].Present <> ARight[LBeat].Present) or
      (ALeft[LBeat].Present and ARight[LBeat].Present and
      (ALeft[LBeat].OffsetHalfBeats <> ARight[LBeat].OffsetHalfBeats)) then
    begin
      Inc(Result);
    end;
  end;
end;

procedure ValidateActions(const AActions: TPassageActions;
  var AReport: TCompositionScaffoldReport);
var
  LBeat: Integer;
  LPart: Integer;
  LAction: TAction;
  LChord: TChord;
  LPreviousEnd: array[0..1] of Integer;
  LPreviousMelody: Integer;
  LStart: Integer;
  LEnd: Integer;
  LOverlap: Integer;
  LBassRests: Integer;
  LMelodyRests: Integer;
  LA: TPartActions;
  LAprime: TPartActions;
  LB: TPartActions;
  LExpected: TAction;
  LActual: TAction;
  LChanges: Integer;
begin
  LPreviousEnd[0] := 0;
  LPreviousEnd[1] := 0;
  LPreviousMelody := 67;
  for LBeat := 0 to CBeatsPerPassage - 1 do
  begin
    LChord := ChordAtBeat(LBeat);
    for LPart := 0 to 1 do
    begin
      LAction := AActions[LPart][LBeat];
      if LBeat = 62 then
      begin
        Require(LAction.Present and (LAction.OffsetHalfBeats = 0) and
          (LAction.DurationHalfBeats = 2) and (LAction.Degree = 0),
          'Seed does not resolve both parts to C root on beat 62');
      end;
      if (LPart = 0) and ((LBeat mod CBeatsPerBar) = 0) then
      begin
        Require(LAction.Present and (LAction.OffsetHalfBeats = 0) and
          (LAction.Degree = 0) and (LAction.Pitch = CBassRoot[LChord]),
          'Seed does not place the exact bass root at a bar downbeat');
      end;
      if not LAction.Present then
      begin
        Continue;
      end;
      Require((LAction.OffsetHalfBeats >= 0) and
        (LAction.OffsetHalfBeats <= 1) and
        (LAction.DurationHalfBeats >= 1) and
        (LAction.DurationHalfBeats <= 2) and
        (LAction.OffsetHalfBeats + LAction.DurationHalfBeats <= 2),
        'Seed generated a gate outside its half-open beat cell');
      LStart := LBeat * SourceFreeCompositionPPQ +
        LAction.OffsetHalfBeats * (SourceFreeCompositionPPQ div 2);
      LEnd := LStart + LAction.DurationHalfBeats *
        (SourceFreeCompositionPPQ div 2);
      Require((LStart >= LPreviousEnd[LPart]) and
        (LEnd <= (LBeat + 1) * SourceFreeCompositionPPQ),
        'Seed generated a same-part overlap or chord-boundary crossing');
      LPreviousEnd[LPart] := LEnd;
      if LPart = 0 then
      begin
        Require((LAction.Pitch >= 29) and (LAction.Pitch <= 48) and
          (PitchClass(LAction.Pitch) = ChordPitchClass(LChord, LAction.Degree)),
          'Seed generated bass outside its register or chord');
      end
      else
      begin
        Require((LAction.Pitch >= 60) and (LAction.Pitch <= 79) and
          (PitchClass(LAction.Pitch) = ChordPitchClass(LChord, LAction.Degree)),
          'Seed generated melody outside its register or chord');
        Require(Abs(LAction.Pitch - LPreviousMelody) <= 7,
          'Seed generated a melody leap larger than seven semitones');
        LPreviousMelody := LAction.Pitch;
      end;
    end;
  end;
  LBassRests := CountSilentBeats(AActions[0]);
  LMelodyRests := CountSilentBeats(AActions[1]);
  LOverlap := CountOverlapBeats(AActions);
  Require((LBassRests >= 8) and (LMelodyRests >= 8),
    'Seed does not leave at least eight silent beat slots in each part');
  Require(LOverlap >= 16,
    'Seed does not produce at least sixteen overlap beat slots');
  Require(not AActions[0][63].Present and not AActions[1][63].Present,
    'Seed does not leave both parts silent on the final beat');

  for LPart := 0 to 1 do
  begin
    LA := Default(TPartActions);
    LAprime := Default(TPartActions);
    LB := Default(TPartActions);
    for LBeat := 0 to CPhraseBeats - 1 do
    begin
      LA[LBeat] := AActions[LPart][LBeat];
      LAprime[LBeat] := AActions[LPart][CPhraseBeats + LBeat];
      LB[LBeat] := AActions[LPart][2 * CPhraseBeats + LBeat];
    end;
    LChanges := CountDegreeChanges(LA, LAprime, 0, CPhraseBeats);
    Require(LChanges >= 2,
      'A-prime must vary at least two pitch-degree choices in each part');
    LChanges := CountRhythmChanges(LA, LB, 0, CPhraseBeats);
    Require(LChanges > 0,
      'B must vary onsets or rests in each part');
    LChanges := CountDegreeChanges(LA, LB, 0, CPhraseBeats);
    Require(LChanges > 0,
      'B must vary contour in each part');
    for LBeat := 0 to 13 do
    begin
      LExpected := LA[LBeat];
      LActual := AActions[LPart][3 * CPhraseBeats + LBeat];
      Require((LExpected.Present = LActual.Present) and
        (not LExpected.Present or
        ((LExpected.OffsetHalfBeats = LActual.OffsetHalfBeats) and
        (LExpected.DurationHalfBeats = LActual.DurationHalfBeats) and
        (LExpected.Degree = LActual.Degree))),
        'Return phrase does not recall its A opening');
    end;
  end;
  AReport.BassSilentBeats := LBassRests;
  AReport.MelodySilentBeats := LMelodyRests;
  AReport.SimultaneousOverlapBeats := LOverlap;
end;

function PartName(const APart: Integer): String;
begin
  if APart = 0 then
  begin
    Result := 'bass';
  end
  else
  begin
    Result := 'melody';
  end;
end;

function TwoDigits(const AValue: Integer): String;
begin
  Result := Chr(Ord('0') + (AValue div 10)) +
    Chr(Ord('0') + (AValue mod 10));
end;

function PartVelocity(const APart: Integer): Integer;
begin
  if APart = 0 then
  begin
    Result := 80;
  end
  else
  begin
    Result := 72;
  end;
end;

function BuildLedger(const AActions: TPassageActions; const ASeed: Cardinal): UTF8String;
var
  LBeat: Integer;
  LPart: Integer;
  LAction: TAction;
  LStart: Integer;
  LEnd: Integer;
begin
  Result := '';
  AppendLine(Result, '# contract=' + SourceFreeCompositionPolicyId);
  AppendLine(Result, '# seed=' + IntToStr(ASeed));
  AppendLine(Result, '# source=first-party-seeded; wfc=none; recordings=none');
  AppendLine(Result, '# ppq=480; tempo_us_per_quarter=555556; half_beat_ticks=240');
  AppendLine(Result, 'beat'#9'bar'#9'chord'#9'part'#9'presence'#9'onset_half'#9+
    'duration_half'#9'degree'#9'pitch'#9'velocity'#9'track'#9'voice'#9'channel'#9+
    'start_tick'#9'end_tick');
  for LBeat := 0 to CBeatsPerPassage - 1 do
  begin
    for LPart := 0 to 1 do
    begin
      LAction := AActions[LPart][LBeat];
      if LAction.Present then
      begin
        LStart := LBeat * SourceFreeCompositionPPQ +
          LAction.OffsetHalfBeats * (SourceFreeCompositionPPQ div 2);
        LEnd := LStart + LAction.DurationHalfBeats *
          (SourceFreeCompositionPPQ div 2);
        AppendLine(Result, TwoDigits(LBeat) + #9 +
          IntToStr((LBeat div CBeatsPerBar) + 1) + #9 +
          CChordName[ChordAtBeat(LBeat)] + #9 + PartName(LPart) + #9 +
          'attack'#9 + IntToStr(LAction.OffsetHalfBeats) + #9 +
          IntToStr(LAction.DurationHalfBeats) + #9 + IntToStr(LAction.Degree) + #9 +
          IntToStr(LAction.Pitch) + #9 + IntToStr(PartVelocity(LPart)) + #9 +
          IntToStr(LPart) + #9 + IntToStr(LPart) + #9 + '0'#9 +
          IntToStr(LStart) + #9 + IntToStr(LEnd));
      end
      else
      begin
        AppendLine(Result, TwoDigits(LBeat) + #9 +
          IntToStr((LBeat div CBeatsPerBar) + 1) + #9 +
          CChordName[ChordAtBeat(LBeat)] + #9 + PartName(LPart) + #9 +
          'rest'#9'-'#9'-'#9'-'#9'-'#9'-'#9'-'#9'-'#9'-'#9'-'#9'-');
      end;
    end;
  end;
end;

procedure BuildSequence(const AActions: TPassageActions; out ASequence: TNoteSequence);
var
  LGates: TNoteGates;
  LTempo: TTempoChanges;
  LBeat: Integer;
  LPart: Integer;
  LAction: TAction;
  LGate: TNoteGate;
  LCount: Integer;
  LStart: Integer;
begin
  ASequence := nil;
  SetLength(LGates, CMaximumNotes);
  LCount := 0;
  for LBeat := 0 to CBeatsPerPassage - 1 do
  begin
    for LPart := 0 to 1 do
    begin
      LAction := AActions[LPart][LBeat];
      if not LAction.Present then
      begin
        Continue;
      end;
      LStart := LBeat * SourceFreeCompositionPPQ +
        LAction.OffsetHalfBeats * (SourceFreeCompositionPPQ div 2);
      LGate.StartTick := LStart;
      LGate.EndTick := LStart + LAction.DurationHalfBeats *
        (SourceFreeCompositionPPQ div 2);
      LGate.Pitch := LAction.Pitch;
      LGate.Velocity := PartVelocity(LPart);
      LGate.Track := LPart;
      LGate.Voice := LPart;
      LGate.Channel := 0;
      LGates[LCount] := LGate;
      Inc(LCount);
    end;
  end;
  SetLength(LGates, LCount);
  SetLength(LTempo, 1);
  LTempo[0] := MakeTempoChange(0, SourceFreeCompositionTempoUsPerQuarter);
  ASequence := TNoteSequence.Create(SourceFreeCompositionPPQ,
    SourceFreeCompositionTicks, LTempo, LGates);
end;

procedure BuildReportText(var AReport: TCompositionScaffoldReport);
begin
  AReport.Text := '';
  AppendLine(AReport.Text, 'contract=' + AReport.PolicyId);
  AppendLine(AReport.Text, 'source_kind=' + AReport.SourceKind);
  AppendLine(AReport.Text, 'wfc_learned=' + LowerCase(BoolToStr(AReport.LearnedWfc, True)));
  AppendLine(AReport.Text, 'seed=' + IntToStr(AReport.Seed));
  AppendLine(AReport.Text, 'generator=' + AReport.Generator);
  AppendLine(AReport.Text, 'form=A,A-prime,B,return-cadence');
  AppendLine(AReport.Text, 'chords=C Am F G | C Am F G | F G Em Am | F G C C');
  AppendLine(AReport.Text, 'ppq=' + IntToStr(AReport.PPQ));
  AppendLine(AReport.Text, 'tempo_us_per_quarter=' + IntToStr(AReport.TempoUsPerQuarter));
  AppendLine(AReport.Text, 'bars=' + IntToStr(AReport.BarCount));
  AppendLine(AReport.Text, 'event_count=' + IntToStr(AReport.EventCount));
  AppendLine(AReport.Text, 'bass_silent_beat_slots=' + IntToStr(AReport.BassSilentBeats));
  AppendLine(AReport.Text, 'melody_silent_beat_slots=' + IntToStr(AReport.MelodySilentBeats));
  AppendLine(AReport.Text, 'overlap_beat_slots=' + IntToStr(AReport.SimultaneousOverlapBeats));
  AppendLine(AReport.Text, 'melody_degree_constraint_adjustments=' +
    IntToStr(AReport.MelodyDegreeAdjustments));
  AppendLine(AReport.Text, 'seed_generated_base_A_slots=' +
    IntToStr(AReport.SeedGeneratedBaseASlots) + '/128');
  AppendLine(AReport.Text, 'form_derived_Aprime_slots=' +
    IntToStr(AReport.FormDerivedAprimeSlots));
  AppendLine(AReport.Text, 'form_derived_B_forced_slots=' +
    IntToStr(AReport.FormDerivedBForcedSlots));
  AppendLine(AReport.Text, 'form_complement_B_optional_slots=' +
    IntToStr(AReport.FormComplementBOptionalSlots));
  AppendLine(AReport.Text, 'return_recall_slots=' +
    IntToStr(AReport.ReturnRecallSlots));
  AppendLine(AReport.Text, 'authored_cadence_slots=' +
    IntToStr(AReport.AuthoredCadenceSlots));
  AppendLine(AReport.Text, 'lineage_accounting=action-slot categories, not per-attribute shares');
  AppendLine(AReport.Text, 'authored_source_phrase_union_count=' +
    IntToStr(AReport.AuthoredSourcePhraseUnionCount));
  AppendLine(AReport.Text, 'generated_phrase_comparison_count=' +
    'not_applicable_empty_source_union');
  AppendLine(AReport.Text, 'copied_phrase_run_count=' +
    'not_applicable_empty_source_union');
  AppendLine(AReport.Text, 'model_hash=' + AReport.ModelHash);
  AppendLine(AReport.Text, 'token_hash=' + AReport.TokenHash);
  AppendLine(AReport.Text, 'structural_status=PASS');
end;

function GenerateSourceFreeComposition(const ASeed: Cardinal;
  out AReport: TCompositionScaffoldReport): TNoteSequence;
var
  LActions: TPassageActions;
  LCount: Integer;
  LPart: Integer;
  LBeat: Integer;
begin
  Result := nil;
  AReport := Default(TCompositionScaffoldReport);
  AReport.PolicyId := SourceFreeCompositionPolicyId;
  AReport.Seed := ASeed;
  AReport.Generator := 'xorshift32(base=A511E9B3,form=C2B2AE35);v1';
  AReport.SourceKind := 'first-party-seeded-source-free';
  AReport.LearnedWfc := False;
  AReport.PPQ := SourceFreeCompositionPPQ;
  AReport.TempoUsPerQuarter := SourceFreeCompositionTempoUsPerQuarter;
  AReport.BarCount := SourceFreeCompositionBars;
  AReport.SeedGeneratedBaseASlots := 32;
  AReport.FormDerivedAprimeSlots := 32;
  AReport.FormDerivedBForcedSlots := 16;
  AReport.FormComplementBOptionalSlots := 16;
  AReport.ReturnRecallSlots := 28;
  AReport.AuthoredCadenceSlots := 4;
  AReport.AuthoredSourcePhraseUnionCount := 0;
  AReport.GeneratedPhraseComparisonCount := 0;
  AReport.CopiedPhraseRunCount := 0;
  AReport.ModelHash := 'not_applicable_no_WFC_model';
  AReport.TokenHash := 'not_applicable_no_WFC_tokens';
  try
    GeneratePassageActions(ASeed, LActions);
    ProjectPitches(LActions, AReport.MelodyDegreeAdjustments);
    ValidateActions(LActions, AReport);
    LCount := 0;
    for LPart := 0 to 1 do
    begin
      for LBeat := 0 to CBeatsPerPassage - 1 do
      begin
        if LActions[LPart][LBeat].Present then
        begin
          Inc(LCount);
        end;
      end;
    end;
    Require((LCount > 0) and (LCount <= CMaximumNotes),
      'Seed event count exceeds the bounded note budget');
    AReport.EventCount := LCount;
    AReport.EventLedger := BuildLedger(LActions, ASeed);
    BuildReportText(AReport);
    BuildSequence(LActions, Result);
    Require(Result.NoteCount = LCount,
      'Constructed note sequence differs from the validated event count');
  except
    on E: Exception do
    begin
      Result.Free;
      Result := nil;
      AReport := Default(TCompositionScaffoldReport);
      raise EAudio.Create('Composition seed ' + IntToStr(ASeed) +
        ' stopped: ' + E.Message);
    end;
  end;
end;

end.
