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
unit pythian.wfc.note.events;

{$mode delphi}
{$H+}

interface

uses
  pythian.music,
  pythian.time,
  wfc_model;

const
  JointNoteEventCodecVersion = 1;
  MaximumJointNoteEventGates = 4096;
  MaximumJointNoteEventBundles = 1024;
  MaximumJointNoteEventWidth = 16;
  MaximumJointNoteEventTokenBytes = 512;

type
  TJointNoteEventTokens = TWfcModelTokens;

  TJointNoteEventPath = record
    TicksPerQuarter: Integer;
    LengthTicks: Integer;
    PartA: Integer;
    PartB: Integer;
    QuantumTicks: Integer;
    Tempos: TTempoChanges;
    Tokens: TJointNoteEventTokens;
  end;

{ Exact one-source-tick codec. Tokens group equal-onset notes; the first delta
  is measured from tick zero and later deltas from the preceding bundle. An
  empty token path is an explicit all-silence phrase with its extent in metadata. }
function EncodeJointNoteEvents(const ASequence: TNoteSequence;
  const APartA, APartB, AQuantumTicks: Integer): TJointNoteEventPath;

{ Returns a detached candidate only after the entire packet validates. }
function DecodeJointNoteEvents(const APath: TJointNoteEventPath): TNoteSequence;

implementation

uses
  Classes,
  SysUtils,
  pythian.audio;

type
  TOrderedGate = record
    Gate: TNoteGate;
    Ordinal: Integer;
  end;
  TOrderedGates = array of TOrderedGate;
  TStringVector = array of String;

function GateBefore(const ALeft, ARight: TOrderedGate): Boolean;
begin
  if ALeft.Gate.StartTick <> ARight.Gate.StartTick then
    Exit(ALeft.Gate.StartTick < ARight.Gate.StartTick);
  if ALeft.Gate.Voice <> ARight.Gate.Voice then
    Exit(ALeft.Gate.Voice < ARight.Gate.Voice);
  if ALeft.Gate.Pitch <> ARight.Gate.Pitch then
    Exit(ALeft.Gate.Pitch < ARight.Gate.Pitch);
  if ALeft.Gate.EndTick <> ARight.Gate.EndTick then
    Exit(ALeft.Gate.EndTick < ARight.Gate.EndTick);
  Result := ALeft.Ordinal < ARight.Ordinal;
end;

procedure SortGates(var AGates: TOrderedGates);
var
  LIndex: Integer;
  LPosition: Integer;
  LValue: TOrderedGate;
begin
  for LIndex := 1 to High(AGates) do
  begin
    LValue := AGates[LIndex];
    LPosition := LIndex;
    while (LPosition > 0) and GateBefore(LValue, AGates[LPosition - 1]) do
    begin
      AGates[LPosition] := AGates[LPosition - 1];
      Dec(LPosition);
    end;
    AGates[LPosition] := LValue;
  end;
end;

function SameGateIdentity(const ALeft, ARight: TNoteGate): Boolean;
begin
  Result := (ALeft.StartTick = ARight.StartTick) and
    (ALeft.EndTick = ARight.EndTick) and (ALeft.Voice = ARight.Voice) and
    (ALeft.Track = ARight.Track) and (ALeft.Channel = ARight.Channel) and
    (ALeft.Pitch = ARight.Pitch) and (ALeft.Velocity = ARight.Velocity);
end;

function GateIdentity(const AGate: TNoteGate): String;
begin
  Result := IntToStr(AGate.StartTick) + ',' + IntToStr(AGate.EndTick) + ',' +
    IntToStr(AGate.Voice) + ',' + IntToStr(AGate.Track) + ',' +
    IntToStr(AGate.Channel) + ',' + IntToStr(AGate.Pitch) + ',' +
    IntToStr(AGate.Velocity);
end;

procedure RequireParts(const APartA, APartB: Integer);
begin
  if (APartA < 0) or (APartA >= 4096) or (APartB < 0) or
    (APartB >= 4096) or (APartA = APartB) then
    raise EAudio.Create('Joint note events require two distinct bounded part IDs');
end;

procedure SplitStrict(const AText: String; const ASeparator: Char;
  const AFields: TStrings);
var
  LStart: Integer;
  LIndex: Integer;
begin
  AFields.Clear;
  if AText = '' then
    raise EAudio.Create('Empty field in joint note-event token');
  LStart := 1;
  for LIndex := 1 to Length(AText) do
  begin
    if AText[LIndex] = ASeparator then
    begin
      if LIndex = LStart then
        raise EAudio.Create('Empty field in joint note-event token');
      AFields.Add(Copy(AText, LStart, LIndex - LStart));
      LStart := LIndex + 1;
    end;
  end;
  if LStart > Length(AText) then
    raise EAudio.Create('Trailing separator in joint note-event token');
  AFields.Add(Copy(AText, LStart, Length(AText) - LStart + 1));
end;

function ParseCanonicalInt(const AText: String; const AMinimum,
  AMaximum: Integer): Integer;
begin
  if not TryStrToInt(AText, Result) or (IntToStr(Result) <> AText) or
    (Result < AMinimum) or (Result > AMaximum) then
    raise EAudio.CreateFmt('Invalid canonical joint note-event integer: %s', [AText]);
end;

function GateTokenFields(const AGate: TNoteGate): String;
begin
  Result := IntToStr(AGate.Voice) + ',' + IntToStr(AGate.Track) + ',' +
    IntToStr(AGate.Channel) + ',' + IntToStr(AGate.Pitch) + ',' +
    IntToStr(AGate.Velocity) + ',' + IntToStr(AGate.EndTick - AGate.StartTick);
end;

function EncodeJointNoteEvents(const ASequence: TNoteSequence;
  const APartA, APartB, AQuantumTicks: Integer): TJointNoteEventPath;
var
  LGates: TOrderedGates;
  LSeenTokens: TStringList;
  LSeenIdentities: TStringList;
  LGate: TNoteGate;
  LToken: String;
  LBundle: Integer;
  LEnd: Integer;
  LCount: Integer;
  LIndex: Integer;
  LPreviousStart: Integer;
  LDelta: Int64;
  LClock: TTempoMap;
begin
  if ASequence = nil then
    raise EAudio.Create('Joint note-event encoding requires a note sequence');
  RequireParts(APartA, APartB);
  if (AQuantumTicks <> 1) then
    raise EAudio.Create('This codec version requires an exact one-tick quantum');
  if ASequence.NoteCount > MaximumJointNoteEventGates then
    raise EAudio.Create('Joint note-event gate count exceeds 4,096');
  if (ASequence.LengthTicks < 1) or (ASequence.TicksPerQuarter < 1) then
    raise EAudio.Create('Joint note-event sequence extent and PPQ must be positive');

  Result := Default(TJointNoteEventPath);
  Result.TicksPerQuarter := ASequence.TicksPerQuarter;
  Result.LengthTicks := ASequence.LengthTicks;
  Result.PartA := APartA;
  Result.PartB := APartB;
  Result.QuantumTicks := AQuantumTicks;
  LClock := ASequence.CopyClock;
  try
    Result.Tempos := LClock.CopyChanges;
  finally
    LClock.Free;
  end;

  SetLength(LGates, ASequence.NoteCount);
  LSeenIdentities := TStringList.Create;
  LSeenTokens := TStringList.Create;
  try
    LSeenIdentities.Sorted := True;
    LSeenIdentities.Duplicates := dupIgnore;
    LSeenTokens.Sorted := True;
    LSeenTokens.Duplicates := dupIgnore;
    for LIndex := 0 to ASequence.NoteCount - 1 do
    begin
      LGate := ASequence.GateAt(LIndex);
      if (LGate.Voice <> APartA) and (LGate.Voice <> APartB) then
        raise EAudio.CreateFmt('Gate %d has a voice outside the two declared parts',
          [LIndex]);
      if (LGate.StartTick < 0) or (LGate.EndTick <= LGate.StartTick) or
        (LGate.EndTick > ASequence.LengthTicks) or (LGate.Track < 0) or
        (LGate.Channel < -1) or (LGate.Channel > 15) or
        (LGate.Pitch < 0) or (LGate.Pitch > 127) or
        (LGate.Velocity < 1) or (LGate.Velocity > 127) then
        raise EAudio.CreateFmt('Gate %d exceeds the joint note-event bounds', [LIndex]);
      if LGate.StartTick mod AQuantumTicks <> 0 then
        raise EAudio.CreateFmt('Gate %d onset is not representable at this quantum', [LIndex]);
      if LSeenIdentities.IndexOf(GateIdentity(LGate)) >= 0 then
        raise EAudio.CreateFmt('Gate %d duplicates an existing source identity', [LIndex]);
      LSeenIdentities.Add(GateIdentity(LGate));
      LGates[LIndex].Gate := LGate;
      LGates[LIndex].Ordinal := LIndex;
    end;
    SortGates(LGates);
    LPreviousStart := 0;
    LBundle := 0;
    LIndex := 0;
    while LIndex < Length(LGates) do
    begin
      if LBundle >= MaximumJointNoteEventBundles then
        raise EAudio.Create('Joint note-event bundle count exceeds 1,024');
      LEnd := LIndex + 1;
      while (LEnd < Length(LGates)) and
        (LGates[LEnd].Gate.StartTick = LGates[LIndex].Gate.StartTick) do
        Inc(LEnd);
      LCount := LEnd - LIndex;
      if LCount > MaximumJointNoteEventWidth then
        raise EAudio.Create('Joint note-event bundle exceeds 16 simultaneous starts');
      LDelta := Int64(LGates[LIndex].Gate.StartTick) - LPreviousStart;
      if (LBundle = 0) then
      begin
        if LDelta < 0 then
          raise EAudio.Create('First joint note-event delta is negative');
      end
      else if LDelta <= 0 then
        raise EAudio.Create('Joint note-event onset deltas must be positive');
      LToken := IntToStr(LDelta);
      for LCount := LIndex to LEnd - 1 do
      begin
        LGate := LGates[LCount].Gate;
        LToken := LToken + '|' + GateTokenFields(LGate);
      end;
      if Length(LToken) > MaximumJointNoteEventTokenBytes then
        raise EAudio.Create('Joint note-event token exceeds 512 bytes');
      LSeenTokens.Add(LToken);
      SetLength(Result.Tokens, LBundle + 1);
      Result.Tokens[LBundle] := UTF8String(LToken);
      LPreviousStart := LGates[LIndex].Gate.StartTick;
      LIndex := LEnd;
      Inc(LBundle);
    end;
    if LSeenTokens.Count > MaximumJointNoteEventBundles then
      raise EAudio.Create('Joint note-event vocabulary exceeds 1,024 unique tokens');
  finally
    LSeenTokens.Free;
    LSeenIdentities.Free;
  end;
end;

function DecodeJointNoteEvents(const APath: TJointNoteEventPath): TNoteSequence;
var
  LFields: TStringList;
  LNoteFields: TStringList;
  LSeenTokens: TStringList;
  LSeenIdentities: TStringList;
  LGates: TNoteGates;
  LGate: TNoteGate;
  LToken: String;
  LDelta: Integer;
  LStart: Int64;
  LDuration: Integer;
  LIndex: Integer;
  LNoteIndex: Integer;
  LGateCount: Integer;
  LPreviousGate: TNoteGate;
  LHasPrevious: Boolean;
begin
  RequireParts(APath.PartA, APath.PartB);
  if (APath.QuantumTicks <> 1) or (APath.TicksPerQuarter < 1) or
    (APath.LengthTicks < 1) or (Length(APath.Tokens) > MaximumJointNoteEventBundles) then
    raise EAudio.Create('Joint note-event packet metadata exceeds bounds');
  LFields := TStringList.Create;
  LNoteFields := TStringList.Create;
  LSeenTokens := TStringList.Create;
  LSeenIdentities := TStringList.Create;
  try
    LSeenTokens.Sorted := True;
    LSeenTokens.Duplicates := dupIgnore;
    LSeenIdentities.Sorted := True;
    LSeenIdentities.Duplicates := dupIgnore;
    SetLength(LGates, MaximumJointNoteEventGates);
    LGateCount := 0;
    LStart := 0;
    for LIndex := 0 to High(APath.Tokens) do
    begin
      LToken := String(APath.Tokens[LIndex]);
      if Length(LToken) > MaximumJointNoteEventTokenBytes then
        raise EAudio.CreateFmt('Joint note-event token %d exceeds 512 bytes', [LIndex]);
      SplitStrict(LToken, '|', LFields);
      if LFields.Count < 2 then
        raise EAudio.Create('Joint note-event bundle has no notes');
      LDelta := ParseCanonicalInt(LFields[0], 0, High(Integer));
      if (LIndex > 0) and (LDelta = 0) then
        raise EAudio.Create('Noninitial joint note-event delta must be positive');
      LStart := LStart + LDelta;
      if (LStart < 0) or (LStart >= APath.LengthTicks) then
        raise EAudio.Create('Joint note-event onset lies outside declared extent');
      if LFields.Count - 1 > MaximumJointNoteEventWidth then
        raise EAudio.Create('Joint note-event bundle exceeds 16 simultaneous starts');
      LSeenTokens.Add(LToken);
      LHasPrevious := False;
      LPreviousGate := Default(TNoteGate);
      for LNoteIndex := 1 to LFields.Count - 1 do
      begin
        if LGateCount >= MaximumJointNoteEventGates then
          raise EAudio.Create('Joint note-event packet exceeds 4,096 gates');
        SplitStrict(LFields[LNoteIndex], ',', LNoteFields);
        if LNoteFields.Count <> 6 then
          raise EAudio.Create('Joint note-event note must have six fields');
        LGate := Default(TNoteGate);
        LGate.Voice := ParseCanonicalInt(LNoteFields[0], 0, 4095);
        if (LGate.Voice <> APath.PartA) and (LGate.Voice <> APath.PartB) then
          raise EAudio.Create('Joint note-event note has an undeclared voice');
        LGate.Track := ParseCanonicalInt(LNoteFields[1], 0, High(Integer));
        LGate.Channel := ParseCanonicalInt(LNoteFields[2], -1, 15);
        LGate.Pitch := ParseCanonicalInt(LNoteFields[3], 0, 127);
        LGate.Velocity := ParseCanonicalInt(LNoteFields[4], 1, 127);
        LDuration := ParseCanonicalInt(LNoteFields[5], 1, High(Integer));
        if LStart + LDuration > APath.LengthTicks then
          raise EAudio.Create('Joint note-event gate ends beyond declared extent');
        LGate.StartTick := Integer(LStart);
        LGate.EndTick := Integer(LStart + LDuration);
        if LHasPrevious and
          ((LGate.Voice < LPreviousGate.Voice) or
          ((LGate.Voice = LPreviousGate.Voice) and
          (LGate.Pitch < LPreviousGate.Pitch)) or
          ((LGate.Voice = LPreviousGate.Voice) and
          (LGate.Pitch = LPreviousGate.Pitch) and
          (LGate.EndTick < LPreviousGate.EndTick))) then
          raise EAudio.Create('Joint note-event notes are not canonically ordered');
        LGates[LGateCount] := LGate;
        if LSeenIdentities.IndexOf(GateIdentity(LGate)) >= 0 then
          raise EAudio.Create('Joint note-event packet duplicates a note identity');
        LSeenIdentities.Add(GateIdentity(LGate));
        LPreviousGate := LGate;
        LHasPrevious := True;
        Inc(LGateCount);
      end;
    end;
    if LSeenTokens.Count > MaximumJointNoteEventBundles then
      raise EAudio.Create('Joint note-event vocabulary exceeds 1,024 unique tokens');
    SetLength(LGates, LGateCount);
    Result := TNoteSequence.Create(APath.TicksPerQuarter, APath.LengthTicks,
      APath.Tempos, LGates);
  finally
    LSeenIdentities.Free;
    LSeenTokens.Free;
    LNoteFields.Free;
    LFields.Free;
  end;
end;

end.
