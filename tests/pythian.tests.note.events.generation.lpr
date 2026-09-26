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
program pythian_tests_note_events_generation;

{$mode delphi}
{$H+}
{$apptype console}

uses
  Math,
  SysUtils,
  pythian.audio,
  pythian.music,
  pythian.time,
  pythian.hash,
  pythian.wfc.generation,
  pythian.wfc.note.events,
  pythian.wfc.note.events.generation,
  wfc_model,
  wfc_sequence;

const
  CSeed = 731;
  COrder = 2;
  COutputBundles = 6;
  COutputExtent = 90;
  CStateBudget = 1048576;

type
  TPartEvent = record
    Onset: Integer;
    Pitch: Integer;
    Duration: Integer;
  end;
  TPartEvents = array of TPartEvent;

function SamePartEvent(const ALeft, ARight: TPartEvent): Boolean;
begin
  Result := (ALeft.Onset = ARight.Onset) and
    (ALeft.Pitch = ARight.Pitch) and
    (ALeft.Duration = ARight.Duration);
end;

function PartEvents(const ASequence: TNoteSequence;
  const AVoice: Integer): TPartEvents;
var
  LCount: Integer;
  LIndex: Integer;
  LGate: TNoteGate;
  LInsert: Integer;
  LValue: TPartEvent;
begin
  Result := nil;
  LCount := 0;
  for LIndex := 0 to ASequence.NoteCount - 1 do
    if ASequence.GateAt(LIndex).Voice = AVoice then
      Inc(LCount);
  SetLength(Result, LCount);
  LCount := 0;
  for LIndex := 0 to ASequence.NoteCount - 1 do
  begin
    LGate := ASequence.GateAt(LIndex);
    if LGate.Voice = AVoice then
    begin
      Result[LCount].Onset := LGate.StartTick;
      Result[LCount].Pitch := LGate.Pitch;
      Result[LCount].Duration := LGate.EndTick - LGate.StartTick;
      Inc(LCount);
    end;
  end;
  for LIndex := 1 to High(Result) do
  begin
    LValue := Result[LIndex];
    LInsert := LIndex;
    while (LInsert > 0) and
      ((Result[LInsert - 1].Onset > LValue.Onset) or
       ((Result[LInsert - 1].Onset = LValue.Onset) and
        (Result[LInsert - 1].Pitch > LValue.Pitch)) or
       ((Result[LInsert - 1].Onset = LValue.Onset) and
        (Result[LInsert - 1].Pitch = LValue.Pitch) and
        (Result[LInsert - 1].Duration > LValue.Duration))) do
    begin
      Result[LInsert] := Result[LInsert - 1];
      Dec(LInsert);
    end;
    Result[LInsert] := LValue;
  end;
end;

function OrderedEventEditDistance(const AGenerated,
  ASource: TPartEvents): Integer;
var
  LDistance: array of array of Integer;
  LRow: Integer;
  LColumn: Integer;
  LSubstitution: Integer;
begin
  SetLength(LDistance, Length(AGenerated) + 1);
  for LRow := 0 to High(LDistance) do
    SetLength(LDistance[LRow], Length(ASource) + 1);
  for LRow := 0 to Length(AGenerated) do
    LDistance[LRow][0] := LRow;
  for LColumn := 0 to Length(ASource) do
    LDistance[0][LColumn] := LColumn;
  for LRow := 1 to Length(AGenerated) do
    for LColumn := 1 to Length(ASource) do
    begin
      LSubstitution := 0;
      if not SamePartEvent(AGenerated[LRow - 1], ASource[LColumn - 1]) then
        LSubstitution := 1;
      LDistance[LRow][LColumn] := Min(
        LDistance[LRow - 1][LColumn] + 1,
        Min(LDistance[LRow][LColumn - 1] + 1,
          LDistance[LRow - 1][LColumn - 1] + LSubstitution));
    end;
  Result := LDistance[Length(AGenerated)][Length(ASource)];
end;

function CanonicalPartBytes(const AEvents: TPartEvents): TAudioBytes;
var
  LText: String;
  LIndex: Integer;
begin
  Result := nil;
  LText := '';
  for LIndex := 0 to High(AEvents) do
    LText := LText + IntToStr(AEvents[LIndex].Onset) + ',' +
      IntToStr(AEvents[LIndex].Pitch) + ',' +
      IntToStr(AEvents[LIndex].Duration) + #10;
  SetLength(Result, Length(LText));
  for LIndex := 1 to Length(LText) do
    Result[LIndex - 1] := Byte(Ord(LText[LIndex]));
end;

procedure ReportPartComparison(const AGenerated, ASource: TNoteSequence;
  const ASourceIndex, AVoice: Integer; out AChangeCount: Integer);
var
  LGeneratedEvents: TPartEvents;
  LSourceEvents: TPartEvents;
begin
  LGeneratedEvents := PartEvents(AGenerated, AVoice);
  LSourceEvents := PartEvents(ASource, AVoice);
  AChangeCount := OrderedEventEditDistance(LGeneratedEvents, LSourceEvents);
  WriteLn(Format(
    'source_%d_part_%d generated_count=%d source_count=%d ordered_tuple_edit_distance=%d generated_sha256=%s source_sha256=%s',
    [ASourceIndex, AVoice, Length(LGeneratedEvents), Length(LSourceEvents),
     AChangeCount, Sha256Bytes(CanonicalPartBytes(LGeneratedEvents)),
     Sha256Bytes(CanonicalPartBytes(LSourceEvents))]));
end;

procedure Check(const ACondition: Boolean; const AMessage: String);
begin
  if not ACondition then
    raise Exception.Create(AMessage);
end;

function MakeGate(const AStart, AEnd, AVoice, APitch, AVelocity: Integer): TNoteGate;
begin
  Result := Default(TNoteGate);
  Result.StartTick := AStart;
  Result.EndTick := AEnd;
  Result.Voice := AVoice;
  Result.Track := AVoice;
  Result.Channel := AVoice;
  Result.Pitch := APitch;
  Result.Velocity := AVelocity;
end;

function MakeSource(const ASecondBranch, ALength: Integer): TNoteSequence;
var
  LGates: TNoteGates;
  LTempos: TTempoChanges;
begin
  SetLength(LGates, 7);
  LGates[0] := MakeGate(0, 20, 0, 60, 96);
  LGates[1] := MakeGate(0, 10, 1, 67, 88);
  LGates[2] := MakeGate(10, 18, 0, 60, 96);
  if ASecondBranch = 0 then
    LGates[3] := MakeGate(22, 42, 0, 62, 96)
  else
    LGates[3] := MakeGate(22, 30, 0, 64, 96);
  LGates[4] := MakeGate(32, 40, 1, 69, 88);
  LGates[5] := MakeGate(42, 50, 1, 67, 88);
  if ASecondBranch = 0 then
    LGates[6] := MakeGate(57, 67, 0, 65, 96)
  else
    LGates[6] := MakeGate(57, 77, 1, 71, 88);
  SetLength(LTempos, 2);
  LTempos[0] := MakeTempoChange(0, 500000);
  LTempos[1] := MakeTempoChange(40, 600000);
  Result := TNoteSequence.Create(1000, ALength, LTempos, LGates);
end;

function SameTempoMap(const ALeft, ARight: TTempoChanges): Boolean;
var
  LIndex: Integer;
begin
  if Length(ALeft) <> Length(ARight) then
    Exit(False);
  for LIndex := 0 to High(ALeft) do
    if (ALeft[LIndex].Tick <> ARight[LIndex].Tick) or
      (ALeft[LIndex].MicrosecondsPerQuarter <>
        ARight[LIndex].MicrosecondsPerQuarter) then
      Exit(False);
  Result := True;
end;

function SequenceTempos(const ASequence: TNoteSequence): TTempoChanges;
var
  LClock: TTempoMap;
begin
  LClock := ASequence.CopyClock;
  try
    Result := LClock.CopyChanges;
  finally
    LClock.Free;
  end;
end;

function SameTokens(const ALeft, ARight: TJointNoteEventTokens): Boolean;
var
  LIndex: Integer;
begin
  if Length(ALeft) <> Length(ARight) then
    Exit(False);
  for LIndex := 0 to High(ALeft) do
    if ALeft[LIndex] <> ARight[LIndex] then
      Exit(False);
  Result := True;
end;

function BundleDelta(const AToken: UTF8String): Integer;
var
  LText: String;
  LSeparator: Integer;
begin
  LText := String(AToken);
  LSeparator := Pos('|', LText);
  Check(LSeparator > 1, 'Malformed generated event token');
  Result := StrToInt(Copy(LText, 1, LSeparator - 1));
end;

function SameGate(const ALeft, ARight: TNoteGate): Boolean;
begin
  Result := (ALeft.StartTick = ARight.StartTick) and
    (ALeft.EndTick = ARight.EndTick) and (ALeft.Voice = ARight.Voice) and
    (ALeft.Track = ARight.Track) and (ALeft.Channel = ARight.Channel) and
    (ALeft.Pitch = ARight.Pitch) and (ALeft.Velocity = ARight.Velocity);
end;

function SameSequence(const ALeft, ARight: TNoteSequence): Boolean;
var
  LIndex: Integer;
begin
  Result := False;
  if (ALeft = nil) or (ARight = nil) or
    (ALeft.NoteCount <> ARight.NoteCount) or
    (ALeft.TicksPerQuarter <> ARight.TicksPerQuarter) or
    (ALeft.LengthTicks <> ARight.LengthTicks) then
    Exit;
  if not SameTempoMap(SequenceTempos(ALeft), SequenceTempos(ARight)) then
    Exit;
  for LIndex := 0 to ALeft.NoteCount - 1 do
    if not SameGate(ALeft.GateAt(LIndex), ARight.GateAt(LIndex)) then
      Exit;
  Result := True;
end;

function SameAsInput(const AGenerated: TJointNoteEventTokens;
  const ASamples: TJointNoteEventSequences): Boolean;
var
  LSample: Integer;
  LPath: TJointNoteEventPath;
begin
  for LSample := 0 to High(ASamples) do
  begin
    LPath := EncodeJointNoteEvents(ASamples[LSample], 0, 1, 1);
    if SameTokens(AGenerated, LPath.Tokens) then
      Exit(True);
  end;
  Result := False;
end;

function CountSimultaneousCrossPartOnsets(const ASequence: TNoteSequence): Integer;
var
  LLeft: Integer;
  LRight: Integer;
begin
  Result := 0;
  for LLeft := 0 to ASequence.NoteCount - 1 do
    for LRight := LLeft + 1 to ASequence.NoteCount - 1 do
      if (ASequence.GateAt(LLeft).Voice <> ASequence.GateAt(LRight).Voice) and
        (ASequence.GateAt(LLeft).StartTick = ASequence.GateAt(LRight).StartTick) then
        Inc(Result);
end;

function HasRepeatedSamePitchRetrigger(const ASequence: TNoteSequence): Boolean;
var
  LLeft: Integer;
  LRight: Integer;
  LGateA: TNoteGate;
  LGateB: TNoteGate;
begin
  for LLeft := 0 to ASequence.NoteCount - 1 do
    for LRight := LLeft + 1 to ASequence.NoteCount - 1 do
    begin
      LGateA := ASequence.GateAt(LLeft);
      LGateB := ASequence.GateAt(LRight);
      if (LGateA.Voice = LGateB.Voice) and (LGateA.Pitch = LGateB.Pitch) and
        (LGateA.StartTick <> LGateB.StartTick) then
        Exit(True);
    end;
  Result := False;
end;

function HasSameVoiceRestGap(const ASequence: TNoteSequence): Boolean;
var
  LLeft: Integer;
  LRight: Integer;
  LGateA: TNoteGate;
  LGateB: TNoteGate;
begin
  for LLeft := 0 to ASequence.NoteCount - 1 do
    for LRight := 0 to ASequence.NoteCount - 1 do
    begin
      LGateA := ASequence.GateAt(LLeft);
      LGateB := ASequence.GateAt(LRight);
      if (LGateA.Voice = LGateB.Voice) and
        (LGateB.StartTick > LGateA.EndTick) then
        Exit(True);
    end;
  Result := False;
end;

function HasUnequalDurations(const ASequence: TNoteSequence): Boolean;
var
  LIndex: Integer;
  LDuration: Integer;
begin
  if ASequence.NoteCount < 2 then
    Exit(False);
  LDuration := ASequence.GateAt(0).EndTick - ASequence.GateAt(0).StartTick;
  for LIndex := 1 to ASequence.NoteCount - 1 do
    if ASequence.GateAt(LIndex).EndTick - ASequence.GateAt(LIndex).StartTick <>
      LDuration then
      Exit(True);
  Result := False;
end;

procedure VerifyOpenBoundaryBranching(const ASamples: TJointNoteEventSequences);
var
  LFirst: TJointNoteEventPath;
  LSecond: TJointNoteEventPath;
begin
  LFirst := EncodeJointNoteEvents(ASamples[0], 0, 1, 1);
  LSecond := EncodeJointNoteEvents(ASamples[1], 0, 1, 1);
  Check((Length(LFirst.Tokens) = 6) and (Length(LSecond.Tokens) = 6),
    'Fixture sequences must each have six onset bundles');
  Check((LFirst.Tokens[0] = LSecond.Tokens[0]) and
    (LFirst.Tokens[1] = LSecond.Tokens[1]) and
    (LFirst.Tokens[2] <> LSecond.Tokens[2]) and
    (LFirst.Tokens[3] = LSecond.Tokens[3]) and
    (LFirst.Tokens[4] = LSecond.Tokens[4]) and
    (LFirst.Tokens[5] <> LSecond.Tokens[5]),
    'Frozen fixture lacks its intended shared-prefix/branch contexts');
end;

procedure VerifyIncompatibleTempoRejected(const ASamples: TJointNoteEventSequences);
var
  LChangedSamples: TJointNoteEventSequences;
  LGates: TNoteGates;
  LClock: TTempoMap;
  LTempos: TTempoChanges;
  LBadSample: TNoteSequence;
  LUnexpectedModel: TJointNoteEventWfcModel;
  LRejected: Boolean;
  LExceptionText: String;
begin
  LGates := ASamples[1].CopyGates;
  LClock := ASamples[1].CopyClock;
  try
    LTempos := LClock.CopyChanges;
  finally
    LClock.Free;
  end;
  Inc(LTempos[1].MicrosecondsPerQuarter);
  LBadSample := TNoteSequence.Create(ASamples[1].TicksPerQuarter,
    ASamples[1].LengthTicks, LTempos, LGates);
  try
    SetLength(LChangedSamples, 2);
    LChangedSamples[0] := ASamples[0];
    LChangedSamples[1] := LBadSample;
    LUnexpectedModel := nil;
    LRejected := False;
    LExceptionText := '';
    try
      LUnexpectedModel := LearnJointNoteEventWfcModel(LChangedSamples,
        0, 1, 1, COrder);
    except
      on LException: Exception do
      begin
        LRejected := Pos('incompatible tempo map',
          LowerCase(LException.Message)) > 0;
        LExceptionText := LException.Message;
      end;
    end;
    LUnexpectedModel.Free;
    Check(LRejected, 'Mixed source tempo maps were not rejected before learning: ' +
      LExceptionText);
  finally
    LBadSample.Free;
  end;
end;

var
  LSamples: TJointNoteEventSequences;
  LModel: TJointNoteEventWfcModel;
  LOptions: TAcousticGenerationOptions;
  LFirst: TNoteSequence;
  LReplay: TNoteSequence;
  LOldOutput: TNoteSequence;
  LReport: TJointNoteEventGenerationReport;
  LReplayReport: TJointNoteEventGenerationReport;
  LFailureReport: TJointNoteEventGenerationReport;
  LPath: TJointNoteEventPath;
  LReplayPath: TJointNoteEventPath;
  LFailed: Boolean;
  LExtentRejected: Boolean;
  LIsNew: Boolean;
  LIndex: Integer;
  LPreviousReplay: TNoteSequence;
  LPreviousFailure: TNoteSequence;
  LFailureMessage: String;
  LPartAChanges: Integer;
  LPartBChanges: Integer;
  LChangedSourceCount: Integer;
begin
  LModel := nil;
  LFirst := nil;
  LReplay := nil;
  LOldOutput := nil;
  LPreviousReplay := nil;
  LPreviousFailure := nil;
  try
    SetLength(LSamples, 2);
    LSamples[0] := MakeSource(0, 70);
    LSamples[1] := MakeSource(1, 80);
    try
      VerifyOpenBoundaryBranching(LSamples);
      VerifyIncompatibleTempoRejected(LSamples);
      LModel := LearnJointNoteEventWfcModel(LSamples, 0, 1, 1, COrder);
      Check(LModel.SampleCount = 2, 'Open corpus model merged source sample boundaries');
      Check(LModel.Boundary = wmbOpen, 'Learned model did not retain open sample boundaries');
      Check(LModel.TicksPerQuarter = 1000, 'Learned PPQ was not retained');
      Check((LModel.PartA = 0) and (LModel.PartB = 1) and
        (LModel.QuantumTicks = 1), 'Learned part/quantum metadata mismatch');
      Check((Length(LModel.SourceLengthTicks) = 2) and
        (LModel.SourceLengthTicks[0] = 70) and
        (LModel.SourceLengthTicks[1] = 80), 'Distinct source extents were not retained');
      Check((LModel.StateCount > 0) and (LModel.VocabularyCount = 8),
        'Unexpected learned joint event vocabulary/state count');
      Check(SameTempoMap(LModel.Tempos, SequenceTempos(LSamples[0])),
        'Exact learned tempo map was not retained');

      LOptions := DefaultAcousticGenerationOptions;
      LOptions.FrameCount := COutputBundles;
      LOptions.Seed := CSeed;
      LOptions.Extent := wseWhole;
      LOptions.MaxBacktracks := 256;
      LOptions.StateCellBudget := CStateBudget;
      Check(TryGenerateJointNoteEventSequence(LModel, LOptions,
        COutputExtent, LFirst, LReport), 'Frozen whole-passage generation failed');
      Check(LReport.Status = jngSolved, 'Successful solve status was not reported');
      Check((Length(LReport.GeneratedTokens) = COutputBundles) and
        (LFirst.NoteCount >= 7) and (LFirst.NoteCount <= 9),
        'Generated event activity lies outside fixture bounds');
      Check((Length(PartEvents(LFirst, 0)) > 0) and
        (Length(PartEvents(LFirst, 1)) > 0),
        'Generated sequence lacks activity in one of the two parts');
      Check(BundleDelta(LReport.GeneratedTokens[0]) = 0,
        'Whole-passage source-free fixture should begin with the zero-delta token');
      for LIndex := 1 to High(LReport.GeneratedTokens) do
        Check(BundleDelta(LReport.GeneratedTokens[LIndex]) > 0,
          'Noninitial generated bundle retained a zero-onset delta');
      Check((LFirst.TicksPerQuarter = LModel.TicksPerQuarter) and
        (LFirst.LengthTicks = COutputExtent) and
        SameTempoMap(SequenceTempos(LFirst), LModel.Tempos),
        'Generated output clock/extent does not match declared model clock');
      Check(CountSimultaneousCrossPartOnsets(LFirst) >= 1,
        'Simultaneous two-part event bundle was lost');
      Check(HasRepeatedSamePitchRetrigger(LFirst),
        'Distinct repeated-pitch attacks were lost');
      Check(HasSameVoiceRestGap(LFirst), 'Source-free rest gap was lost');
      Check(HasUnequalDurations(LFirst), 'Unequal note durations were lost');
      LPath := EncodeJointNoteEvents(LFirst, 0, 1, 1);
      Check(SameTokens(LPath.Tokens, LReport.GeneratedTokens),
        'Generated output did not canonically replay its exact WFC tokens');
      Check((LPath.PartA = 0) and (LPath.PartB = 1) and
        (LPath.TicksPerQuarter = LModel.TicksPerQuarter) and
        (LPath.LengthTicks = COutputExtent) and
        SameTempoMap(LPath.Tempos, LModel.Tempos),
        'Canonical replay changed explicit clock or part metadata');
      LReplay := DecodeJointNoteEvents(LPath);
      Check(SameSequence(LFirst, LReplay), 'Canonical decoded replay differs from generated events');
      LChangedSourceCount := 0;
      for LIndex := 0 to High(LSamples) do
      begin
        ReportPartComparison(LFirst, LSamples[LIndex], LIndex, 0,
          LPartAChanges);
        ReportPartComparison(LFirst, LSamples[LIndex], LIndex, 1,
          LPartBChanges);
        if (LPartAChanges > 0) or (LPartBChanges > 0) then
          Inc(LChangedSourceCount);
      end;
      LIsNew := LChangedSourceCount = Length(LSamples);
      Check(LIsNew,
        'Generated ordered part streams replay at least one complete source sample');
      WriteLn('generated_path=new joint-event branch combination; changed_sources=',
        LChangedSourceCount,
        '; compared_parts=onset,pitch,duration; change_metric=ordered Levenshtein distance; activity=both_parts; overlap=',
        CountSimultaneousCrossPartOnsets(LFirst));

      LPreviousReplay := LReplay;
      Check(TryGenerateJointNoteEventSequence(LModel, LOptions,
        COutputExtent, LReplay, LReplayReport), 'Deterministic replay solve failed');
      Check(LReplay <> LPreviousReplay,
        'Successful generation did not replace the caller-owned prior output');
      LReplayPath := EncodeJointNoteEvents(LReplay, 0, 1, 1);
      Check(SameTokens(LPath.Tokens, LReplayPath.Tokens),
        'Same-seed same-model generation was not byte-identical');
      Check(SameSequence(LFirst, LReplay), 'Same-seed replay changed generated events');

      LOldOutput := DecodeJointNoteEvents(LPath);
      LPreviousFailure := LOldOutput;
      LExtentRejected := False;
      LFailureMessage := '';
      try
        LFailed := TryGenerateJointNoteEventSequence(LModel, LOptions,
          50, LOldOutput, LFailureReport);
        if LFailed then
          LFailureMessage := 'Unexpected output for a 50-tick extent';
      except
        on LException: Exception do
        begin
          LFailureMessage := LowerCase(LException.Message);
          LExtentRejected :=
            (Pos('beyond declared extent', LFailureMessage) > 0) or
            (Pos('outside declared extent', LFailureMessage) > 0);
          LFailureMessage := LException.Message;
        end;
      end;
      Check(LExtentRejected, 'Fixed solve did not reject the undersized output extent: ' +
        LFailureMessage);
      Check(LOldOutput = LPreviousFailure,
        'Out-of-extent decode changed the caller previous output pointer');
      Check(SameSequence(LOldOutput, LFirst),
        'Out-of-extent decode changed the caller previous output data');
      WriteLn('out_of_extent_status=REJECTED; prior_output_preserved=YES');
      WriteLn('samples=2; source bundles=6 each; WFC order=2; seed=731; output bundles=6');
      WriteLn('sample extents=70,80; output extent=90; generated gates=', LFirst.NoteCount);
      WriteLn('incompatible_tempo_map=REJECTED before model publication');
    finally
      LSamples[1].Free;
      LSamples[0].Free;
    end;
  finally
    LReplay.Free;
    if (LOldOutput <> nil) and (LOldOutput <> LFirst) and
      (LOldOutput <> LReplay) then
      LOldOutput.Free;
    LFirst.Free;
    LModel.Free;
  end;
end.
