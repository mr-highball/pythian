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
program pythian_wfc_longform_cli;

{$mode delphi}
{$H+}

uses
  SysUtils, Classes, pythian.audio, pythian.hash, pythian.music,
  pythian.music.compose, pythian.music.compose.longform,
  Math, pythian.music.render, pythian.synth, pythian.synth.stream,
  pythian.articulation, pythian.wave, pythian.wave.stream,
  pythian.wfc.generation, wfc, wfc_model, wfc_sequence,
  wfc_sequence_learn, wfc_sequence_text;

const
  CSourceHash = 'ddb0bb188d350e7dd0e15ef00d07296e66e921f72d864a1ce5e39a213e5ab139';
  CFrames = 144;
  CMaximumReachabilityWork = 1000000;

type
  TBoolCells = array of Boolean;

procedure Require(const ACondition: Boolean; const AMessage: String);
begin
  if not ACondition then raise EAudio.Create(AMessage);
end;

function HashText(const AText: UTF8String): String;
var
  LBytes: TAudioBytes;
  I: Integer;
begin
  SetLength(LBytes, Length(AText));
  for I := 1 to Length(AText) do LBytes[I - 1] := Byte(AText[I]);
  Result := Sha256Bytes(LBytes);
end;

function FileHash(const APath: String; const AMaximumBytes: Int64): String;
var
  LStream: TFileStream;
begin
  LStream := TFileStream.Create(APath, fmOpenRead or fmShareDenyWrite);
  try
    Require((LStream.Size > 0) and (LStream.Size <= AMaximumBytes),
      'File exceeds its declared byte bound');
    Result := Sha256Stream(LStream, LStream.Size);
  finally
    LStream.Free;
  end;
end;

function ReadSources(const APath: String): TWfcSequenceSamples;
var
  LLines, LWords: TStringList;
  LLine: String;
  LTokens: TWfcModelTokens;
  I, J, LSource: Integer;
begin
  Result := nil;
  Require(FileHash(APath, 16384) = CSourceHash,
    'Source hash differs from freeze');
  LLines := TStringList.Create;
  LWords := TStringList.Create;
  try
    LLines.LoadFromFile(APath);
    Require(LLines.Count <= 64, 'Chord source file has too many lines');
    for I := 0 to LLines.Count - 1 do
    begin
      LLine := Trim(LLines[I]);
      if LLine = '' then Continue;
      if LLine[1] = '#' then Continue;
      LWords.Clear;
      ExtractStrings([' ', #9], [], PChar(LLine), LWords);
      Require(LWords.Count = 16, 'Source row has other than 16 chords');
      SetLength(LTokens, 16);
      for J := 0 to 15 do
      begin
        Require((LWords[J] = 'C') or (LWords[J] = 'Am') or
          (LWords[J] = 'F') or (LWords[J] = 'G') or (LWords[J] = 'Em'),
          'Source row contains an unknown chord');
        LTokens[J] := UTF8String(LWords[J]);
      end;
      LSource := Length(Result);
      Require(LSource < 8, 'Too many source rows');
      SetLength(Result, LSource + 1);
      Result[LSource] := MakeWfcSequenceSample(LTokens);
    end;
    Require(Length(Result) = 8, 'Expected eight source rows');
  finally
    LWords.Free;
    LLines.Free;
  end;
end;

function AllowedAt(const APosition: Integer; const AToken: TWfcModelToken): Boolean;
begin
  case APosition of
    0, 142, 143: Result := AToken = 'C';
    140: Result := AToken = 'F';
    141: Result := AToken = 'G';
  else
    Result := True;
  end;
end;

function Reachable(const AModel: TWfcSequenceModel; out AWork: Int64): Boolean;
var
  LCells: TBoolCells;
  LStateCount, LPosition, LState, LNext: Integer;
begin
  Result := False;
  LStateCount := AModel.StateCount;
  SetLength(LCells, CFrames * LStateCount);
  AWork := 0;
  for LState := 0 to LStateCount - 1 do
    if (AModel.StartCountAt(LState) > 0) and
      AllowedAt(0, AModel.ProjectStateToken(LState)) then
      LCells[LState] := True;
  for LPosition := 1 to CFrames - 1 do
    for LState := 0 to LStateCount - 1 do
    begin
      if not LCells[(LPosition - 1) * LStateCount + LState] then Continue;
      for LNext := 0 to LStateCount - 1 do
      begin
        Inc(AWork);
        Require(AWork <= CMaximumReachabilityWork,
          'Reachability exceeded work bound');
        if AModel.StatesCompatible(LState, LNext) and
          AllowedAt(LPosition, AModel.ProjectStateToken(LNext)) then
          LCells[LPosition * LStateCount + LNext] := True;
      end;
    end;
  for LState := 0 to LStateCount - 1 do
    if LCells[(CFrames - 1) * LStateCount + LState] and
      (AModel.EndCountAt(LState) > 0) then Exit(True);
end;

function Constraints: TWfcSequenceTokenConstraints;
const
  CPositions: array[0..4] of Integer = (0, 140, 141, 142, 143);
  CNames: array[0..4] of UTF8String = ('C', 'F', 'G', 'C', 'C');
var
  I: Integer;
  LAllowed: TWfcModelTokens;
begin
  Result := nil;
  SetLength(Result, 5);
  SetLength(LAllowed, 1);
  for I := 0 to 4 do
  begin
    LAllowed[0] := CNames[I];
    Result[I] := MakeWfcSequenceTokenConstraint(CPositions[I], LAllowed);
  end;
end;

function EqualWindow(const A, B: TWfcModelTokens;
  const AStart, BStart, ALength: Integer): Boolean;
var I: Integer;
begin
  for I := 0 to ALength - 1 do
    if A[AStart + I] <> B[BStart + I] then Exit(False);
  Result := True;
end;

procedure InspectNovelty(const ATokens: TWfcModelTokens;
  const ASources: TWfcSequenceSamples);
var
  LBlock, LPhrase, LSource, LSourcePhrase, LOther, LMask: Integer;
  LNovel, LUnique, LChordMask: Integer;
  LOld: Boolean;
  LText: UTF8String;
begin
  LUnique := 0;
  LChordMask := 0;
  LText := '';
  for LBlock := 0 to 8 do
  begin
    LOld := False;
    for LSource := 0 to High(ASources) do
      if EqualWindow(ATokens, ASources[LSource].Tokens,
        LBlock * 16, 0, 16) then LOld := True;
    Require(not LOld, 'A complete 16-bar block copies a source');
    LOld := False;
    for LOther := 0 to LBlock - 1 do
      if EqualWindow(ATokens, ATokens, LBlock * 16, LOther * 16, 16) then
        LOld := True;
    if not LOld then Inc(LUnique);
    LNovel := 0;
    for LPhrase := 0 to 3 do
    begin
      LMask := 0;
      for LSource := 0 to High(ASources) do
        for LSourcePhrase := 0 to 3 do
          if EqualWindow(ATokens, ASources[LSource].Tokens,
            LBlock * 16 + LPhrase * 4, LSourcePhrase * 4, 4) then
            LMask := LMask or (1 shl LSource);
      if LMask = 0 then Inc(LNovel);
      WriteLn('block=', LBlock + 1, ' phrase=', LPhrase + 1,
        ' source_mask=', LMask);
    end;
    Require(LNovel >= 1, 'A block has no source-novel four-bar phrase');
    WriteLn('block=', LBlock + 1, ' novel_phrases=', LNovel);
  end;
  Require(LUnique = 9, 'Complete 16-bar blocks repeat');
  for LBlock := 0 to High(ATokens) do
  begin
    if ATokens[LBlock] = 'C' then LChordMask := LChordMask or 1
    else if ATokens[LBlock] = 'Am' then LChordMask := LChordMask or 2
    else if ATokens[LBlock] = 'F' then LChordMask := LChordMask or 4
    else if ATokens[LBlock] = 'G' then LChordMask := LChordMask or 8
    else if ATokens[LBlock] = 'Em' then LChordMask := LChordMask or 16
    else raise EAudio.Create('Generated token outside chord vocabulary');
    if LBlock > 0 then LText := LText + ' ';
    LText := LText + ATokens[LBlock];
  end;
  LNovel := 0;
  for LBlock := 0 to 4 do
    if (LChordMask and (1 shl LBlock)) <> 0 then Inc(LNovel);
  Require(LNovel >= 4, 'Fewer than four chord labels appear');
  WriteLn('unique_blocks=', LUnique, ' distinct_chords=', LNovel);
  WriteLn('tokens=', String(LText));
  WriteLn('token_sha256=', HashText(LText + #10));
end;

function TokenChord(const AToken: TWfcModelToken): TCompositionChord;
begin
  if AToken = 'C' then Exit(ccC);
  if AToken = 'Am' then Exit(ccAm);
  if AToken = 'F' then Exit(ccF);
  if AToken = 'G' then Exit(ccG);
  if AToken = 'Em' then Exit(ccEm);
  raise EAudio.Create('Generated chord outside vocabulary');
end;

function SectionGates(const ASequence: TNoteSequence;
  const ASection: Integer): TNoteGates;
var
  I, LCount, LStart, LEnd: Integer;
  LGate: TNoteGate;
begin
  Result := nil;
  LCount := 0;
  LStart := ASection * SourceFreeCompositionTicks;
  LEnd := LStart + SourceFreeCompositionTicks;
  SetLength(Result, ASequence.NoteCount);
  for I := 0 to ASequence.NoteCount - 1 do
  begin
    LGate := ASequence.GateAt(I);
    if (LGate.StartTick < LStart) or (LGate.StartTick >= LEnd) then Continue;
    LGate.StartTick := LGate.StartTick - LStart;
    LGate.EndTick := LGate.EndTick - LStart;
    Result[LCount] := LGate;
    Inc(LCount);
  end;
  SetLength(Result, LCount);
end;

function SameEvent(const A, B: TNoteGate): Boolean;
begin
  Result := (A.Track = B.Track) and (A.StartTick = B.StartTick) and
    (A.EndTick = B.EndTick) and (A.Pitch = B.Pitch);
end;

function SameSection(const A, B: TNoteGates): Boolean;
var I: Integer;
begin
  if Length(A) <> Length(B) then Exit(False);
  for I := 0 to High(A) do
    if not SameEvent(A[I], B[I]) then Exit(False);
  Result := True;
end;

procedure InspectEvents(const ASequence: TNoteSequence;
  const ASources: TWfcSequenceSamples);
var
  LBlocks: array[0..8] of TNoteGates;
  LSourceGates: TNoteGates;
  LSourceSchedule: TCompositionChordSchedule;
  LSourceSequence: TNoteSequence;
  LSourceReport: TCompositionScaffoldReport;
  LLastStart: array[0..1] of Integer;
  LBestOnset, LBestDuration, LBestPitch, LBestFull: array[0..8] of Integer;
  LOnset, LDuration, LPitch, LFull: Integer;
  LSection, LSource, I, J, LPart: Integer;
  LGate: TNoteGate;
begin
  FillChar(LBestOnset, SizeOf(LBestOnset), 0);
  FillChar(LBestDuration, SizeOf(LBestDuration), 0);
  FillChar(LBestPitch, SizeOf(LBestPitch), 0);
  FillChar(LBestFull, SizeOf(LBestFull), 0);
  for LSection := 0 to 8 do
  begin
    LBlocks[LSection] := SectionGates(ASequence, LSection);
    for I := 0 to LSection - 1 do
      Require(not SameSection(LBlocks[LSection], LBlocks[I]),
        'Two note-event sections repeat exactly');
  end;
  LLastStart[0] := -1;
  LLastStart[1] := -1;
  for I := 0 to ASequence.NoteCount - 1 do
  begin
    LGate := ASequence.GateAt(I);
    Require((LGate.Track >= 0) and (LGate.Track <= 1) and
      (LGate.Voice = LGate.Track), 'Long-form part ownership failed');
    LPart := LGate.Track;
    if LLastStart[LPart] >= 0 then
      Require(LGate.StartTick - LLastStart[LPart] <=
        4 * SourceFreeCompositionPPQ * 4,
        'Part has more than four bars between note starts');
    LLastStart[LPart] := LGate.StartTick;
  end;
  for LSource := 0 to High(ASources) do
  begin
    for I := 0 to 15 do
      LSourceSchedule[I] := TokenChord(ASources[LSource].Tokens[I]);
    LSourceSequence := GenerateCompositionWithChordSchedule(
      LSourceSchedule, 1731, LSourceReport);
    try
      LSourceGates := LSourceSequence.CopyGates;
      for LSection := 0 to 8 do
      begin
        LOnset := 0;
        LDuration := 0;
        LPitch := 0;
        LFull := 0;
        for I := 0 to High(LBlocks[LSection]) do
          for J := 0 to High(LSourceGates) do
          begin
            if (LBlocks[LSection][I].Track <> LSourceGates[J].Track) or
              (LBlocks[LSection][I].StartTick <>
                LSourceGates[J].StartTick) then Continue;
            Inc(LOnset);
            if LBlocks[LSection][I].EndTick = LSourceGates[J].EndTick then
              Inc(LDuration);
            if LBlocks[LSection][I].Pitch = LSourceGates[J].Pitch then
              Inc(LPitch);
            if SameEvent(LBlocks[LSection][I], LSourceGates[J]) then
              Inc(LFull);
          end;
        if LOnset > LBestOnset[LSection] then LBestOnset[LSection] := LOnset;
        if LDuration > LBestDuration[LSection] then
          LBestDuration[LSection] := LDuration;
        if LPitch > LBestPitch[LSection] then LBestPitch[LSection] := LPitch;
        if LFull > LBestFull[LSection] then LBestFull[LSection] := LFull;
      end;
    finally
      LSourceSequence.Free;
    end;
  end;
  for LSection := 0 to 8 do
    WriteLn('section=', LSection + 1, ' events=', Length(LBlocks[LSection]),
      ' best_source_onset=', LBestOnset[LSection],
      ' best_source_onset_duration=', LBestDuration[LSection],
      ' best_source_onset_pitch=', LBestPitch[LSection],
      ' best_source_exact=', LBestFull[LSection]);
end;

procedure RenderCandidateStream(const ASequence: TNoteSequence;
  const AOutputPath: String);
const
  CSampleRate = 44100;
  CEndJumpLimit = 0.005;
var
  LVoices: TNoteVoices;
  LTones: TFrameTones;
  LReport: TNoteRenderReport;
  LPlan: TArticulationPlan;
  LStream: TFrameToneStream;
  LFile: TFileStream;
  LSink: TStreamAudioSink;
  LWriter: TWavePcm16Writer;
  LBlock: TAudioSamples;
  LGains: array of Double;
  LMarked: array of Boolean;
  LTemporary: String;
  LWavHash: String;
  LBlockStart, LFrame, LFirst, LLast, LOffset: Integer;
  LFrameCount, LIndex, LChannel, LGateIndex, LOmitted: Integer;
  LGate: TArticulationGate;
  LWeight, LSample, LPeak, LJump, LMaxEndJump: Double;
  LPrevious: array[0..1] of Double;
begin
  Require(not FileExists(AOutputPath) and not DirectoryExists(AOutputPath),
    'Long-form output path already exists');
  LTemporary := AOutputPath + '.tmp';
  Require(not FileExists(LTemporary), 'Temporary output path already exists');
  SetLength(LVoices, 2);
  LVoices[0] := DefaultSynthVoice;
  LVoices[0].Gain := 0.12;
  LVoices[0].Pan := -0.25;
  LVoices[0].Envelope.ReleaseSeconds := 0.005;
  LVoices[1] := DefaultSynthVoice;
  LVoices[1].Gain := 0.12;
  LVoices[1].Pan := 0.25;
  LVoices[1].Envelope.ReleaseSeconds := 0.005;
  LTones := PlanNoteTones(ASequence, CSampleRate, LVoices, LReport);
  Require((LReport.SourceNotes = ASequence.NoteCount) and
    (LReport.RenderedNotes = ASequence.NoteCount) and
    (LReport.SubFrameNotes = 0), 'Streaming plan omitted a long-form note');
  LPlan := nil;
  LStream := nil;
  LFile := nil;
  LSink := nil;
  LWriter := nil;
  LPeak := 0.0;
  LMaxEndJump := 0.0;
  LPrevious[0] := 0.0;
  LPrevious[1] := 0.0;
  try
    try
      LPlan := PlanNoteArticulation(ASequence, CSampleRate, 44, 44,
        LOmitted);
      Require(LOmitted = 0, 'Streaming articulation omitted a note');
      Require(LPlan.FrameCount = ASequence.FrameAtTick(
        LongFormCompositionTicks, CSampleRate),
        'Streaming plan length differs from exact clock');
      LStream := TFrameToneStream.Create(LTones, CSampleRate,
        LPlan.FrameCount);
      LFile := TFileStream.Create(LTemporary, fmCreate);
      LSink := TStreamAudioSink.Create(LFile);
      LWriter := TWavePcm16Writer.Create(LSink, CSampleRate, 2,
        LPlan.FrameCount);
      while LWriter.FrameCount < LPlan.FrameCount do
      begin
        LBlockStart := Integer(LWriter.FrameCount);
        Require(LStream.ReadSamples(Min(2048,
          LPlan.FrameCount - LWriter.FrameCount), LBlock),
          'Streaming renderer ended before the exact clock');
        Require((Length(LBlock) > 0) and ((Length(LBlock) mod 2) = 0),
          'Streaming renderer returned a partial stereo frame');
        LFrameCount := Length(LBlock) div 2;
        SetLength(LGains, LFrameCount);
        SetLength(LMarked, LFrameCount);
        for LIndex := 0 to LFrameCount - 1 do
        begin
          LGains[LIndex] := 0.0;
          LMarked[LIndex] := False;
        end;
        for LGateIndex := 0 to LPlan.GateCount - 1 do
        begin
          LGate := LPlan.GateAt(LGateIndex);
          LFirst := Max(LGate.StartFrame, LBlockStart);
          LLast := Min(LGate.EndFrame, LBlockStart + LFrameCount);
          for LFrame := LFirst to LLast - 1 do
          begin
            LWeight := 1.0;
            if LPlan.AttackFrames > 0 then
              LWeight := Min(LWeight,
                (LFrame - LGate.StartFrame) / LPlan.AttackFrames);
            if LPlan.ReleaseFrames > 0 then
              LWeight := Min(LWeight,
                (LGate.EndFrame - 1 - LFrame) / LPlan.ReleaseFrames);
            LOffset := LFrame - LBlockStart;
            LGains[LOffset] := Max(LGains[LOffset], LWeight * LGate.Gain);
          end;
          LFirst := Max(LGate.EndFrame - 3, LBlockStart);
          LLast := Min(LGate.EndFrame + 4,
            LBlockStart + LFrameCount);
          for LFrame := LFirst to LLast - 1 do
            LMarked[LFrame - LBlockStart] := True;
        end;
        for LIndex := 0 to LFrameCount - 1 do
          for LChannel := 0 to 1 do
          begin
            LSample := LBlock[LIndex * 2 + LChannel] * LGains[LIndex];
            RequireFinite(LSample, 'Streaming composed sample');
            if Abs(LSample) > LPeak then LPeak := Abs(LSample);
            if LMarked[LIndex] and (LBlockStart + LIndex > 0) then
            begin
              LJump := Abs(LSample - LPrevious[LChannel]);
              if LJump > LMaxEndJump then LMaxEndJump := LJump;
            end;
            LPrevious[LChannel] := LSample;
            LBlock[LIndex * 2 + LChannel] := LSample;
          end;
        LWriter.AppendSamples(LBlock);
      end;
      Require(LPeak < 1.0, 'Streaming long-form render clips full scale');
      Require(LMaxEndJump <= CEndJumpLimit,
        'Streaming long-form note-end jump exceeds frozen limit');
      LWriter.Finish;
      Require(LWriter.Finished and
        (LWriter.FrameCount = LPlan.FrameCount),
        'Streaming WAV writer did not finish exactly');
      WriteLn('frames=', LWriter.FrameCount,
        ' seconds=', (LWriter.FrameCount / CSampleRate):0:6,
        ' peak=', LPeak:0:9,
        ' maximum_note_end_jump=', LMaxEndJump:0:9);
    finally
      LWriter.Free;
      LSink.Free;
      LFile.Free;
      LStream.Free;
      LPlan.Free;
    end;
    LWavHash := FileHash(LTemporary, 64000000);
    Require(RenameFile(LTemporary, AOutputPath),
      'Could not publish streaming long-form WAV');
    WriteLn('wav=', AOutputPath);
    WriteLn('wav_sha256=', LWavHash);
  except
    DeleteFile(LTemporary);
    raise;
  end;
end;

procedure Run;
var
  LSources: TWfcSequenceSamples;
  LModel: TWfcSequenceModel;
  LOptions: TAcousticGenerationOptions;
  LTokens: TWfcModelTokens;
  LReport: TGraphSolveReport;
  LWork: Int64;
  LIndex: Integer;
  LChords: TLongFormChordPath;
  LSequence: TNoteSequence;
  LNoteReport: TLongFormCompositionReport;
begin
  LModel := nil;
  try
    Require((ParamCount = 1) or (ParamCount = 2),
      'Usage: pythian.wfc.longform SOURCES.txt [OUTPUT.wav]');
    LSources := ReadSources(ParamStr(1));
    LModel := LearnSequenceModelCorpus(LSources, 2, wmbOpen);
    Require((LModel.SampleCount = 8) and (LModel.StateCount <= 256) and
      (LModel.PublicTokenCount = 5), 'Model bound or vocabulary failed');
    WriteLn('model_sha256=', HashText(UTF8String(EncodeWfcSequenceText(LModel))));
    WriteLn('state_count=', LModel.StateCount);
    Require(Reachable(LModel, LWork), 'No complete constrained 144-bar path');
    WriteLn('reachability_work=', LWork);
    LOptions := DefaultAcousticGenerationOptions;
    LOptions.FrameCount := CFrames;
    LOptions.Seed := 1731;
    LOptions.Extent := wseWhole;
    LOptions.MaxBacktracks := 256;
    LOptions.StateCellBudget := 262144;
    LTokens := nil;
    Require(TryGenerateTokenSequence(LModel, LOptions, Constraints,
      LTokens, LReport), 'WFC solve did not complete');
    Require(Length(LTokens) = CFrames, 'Wrong generated token count');
    for LIndex := 0 to CFrames - 1 do
      Require(AllowedAt(LIndex, LTokens[LIndex]), 'Constraint mismatch');
    InspectNovelty(LTokens, LSources);
    SetLength(LChords, CFrames);
    for LIndex := 0 to CFrames - 1 do
      LChords[LIndex] := TokenChord(LTokens[LIndex]);
    LSequence := GenerateLongFormComposition(LChords, LNoteReport);
    try
      WriteLn('note_policy=', LNoteReport.PolicyId,
        ' events=', LNoteReport.EventCount,
        ' bass=', LNoteReport.BassEvents,
        ' melody=', LNoteReport.MelodyEvents,
        ' degree_substitutions=', LNoteReport.DegreeSubstitutions,
        ' max_melody_leap=', LNoteReport.MaximumMelodyLeap);
      Require(LSequence.LengthTicks = LongFormCompositionTicks,
        'Long-form clock mismatch');
      for LIndex := 0 to 8 do
        WriteLn('section=', LIndex + 1,
          ' bass_events=', LNoteReport.SectionBassEvents[LIndex],
          ' melody_events=', LNoteReport.SectionMelodyEvents[LIndex]);
      InspectEvents(LSequence, LSources);
      if ParamCount = 2 then
        RenderCandidateStream(LSequence, ParamStr(2));
    finally
      LSequence.Free;
    end;
    WriteLn('status=PASS');
  finally
    LModel.Free;
  end;
end;

begin
  try
    Run;
  except
    on E: Exception do
    begin
      WriteLn(StdErr, 'status=STOP reason=', E.Message);
      ExitCode := 1;
    end;
  end;
end.
