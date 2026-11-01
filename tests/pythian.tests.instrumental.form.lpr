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
program InstrumentalFormConformance;
{$mode delphi}
{$H+}
uses Classes, SysUtils, Math, pythian.audio, pythian.bus, pythian.echo, pythian.chord,
  {$ifndef pas2js}pythian.wave,{$endif}
  pythian.music.form, pythian.music.decisions, pythian.music.pattern,
  pythian.music.stream, pythian.progress, pythian.pitch.track,
  pythian.wfc.instrumental.starter, pythian.wfc.instrumental.stream,
  pythian.wfc.generation, pythian.wfc.percussion, pythian.wfc.voices,
  wfc, wfc_model, wfc_sequence, wfc_sequence_graph;

type
  TChunks = array of TMusicDecisionChunk;
  TCapture = class
    Chunks: TChunks;
    StopAt: Integer;
    procedure Keep(const AChunk: TMusicDecisionChunk);
    procedure Observe(const AProgress: TWorkProgress);
  end;
  TResult = record
    Mix: TAudioSamples;
    Stems: TBusSampleBlocks;
    Chunks: TChunks;
  end;

var GChecks: Integer;
procedure Check(const AValue: Boolean; const AMessage: String);
begin
  Inc(GChecks);
  if not AValue then raise EAudio.Create(AMessage);
end;

procedure CheckPerformedParts(const ASource: TResult; const ARequireAll: Boolean;
  const AMinimumEnergy: Double);
var Part, Chunk, Cell, Sample: Integer; HasNotes: Boolean;
  Energy, DrumEnergy: Double;
begin
  { H/R guidance does not select drum notes. The authored percussion models
    deliberately include silence. Check actual score-to-audio performance,
    preserving the six-sounding-part positive control separately. }
  DrumEnergy := 0;
  for Part := 0 to 5 do
  begin
    HasNotes := False;
    for Chunk := 0 to High(ASource.Chunks) do
      for Cell := 0 to High(ASource.Chunks[Chunk].Cells) do
        HasNotes := HasNotes or (Length(ASource.Chunks[Chunk].Cells[Cell].Parts[Part].Tones) > 0);
    Energy := 0;
    for Sample := 0 to High(ASource.Stems[Part]) do
      Energy := Energy + Abs(ASource.Stems[Part][Sample]);
    if ARequireAll or (Part < 3) then
      Check(HasNotes, 'The positive form selects every required instrumental part');
    if HasNotes then Check(Energy > AMinimumEnergy, 'Actually selected notes are performed')
    else Check(Energy = 0, 'A rest-only musical part has no fabricated audio');
    if Part >= 3 then DrumEnergy := DrumEnergy + Energy;
  end;
  Check(DrumEnergy > AMinimumEnergy, 'The form includes actual synthesized percussion');
end;
procedure TCapture.Keep(const AChunk: TMusicDecisionChunk);
begin
  SetLength(Chunks, Length(Chunks) + 1);
  Chunks[High(Chunks)] := CopyMusicDecisionChunk(AChunk);
end;
procedure TCapture.Observe(const AProgress: TWorkProgress);
begin
  if (StopAt > 0) and (AProgress.Stage = 'instrumental_stream_plan') and
    (AProgress.Done >= StopAt) then raise EAudio.Create('Operator stopped the form');
end;

function MakeForm(const AAdjacent: Boolean): TMusicForm;
const CNames: array[0..4] of String = ('A', 'B', 'A return', 'Bridge', 'A variation');
var I, LLast: Integer;
begin
  Result := nil;
  SetLength(Result, 5 - Ord(AAdjacent));
  for I := 0 to High(Result) do
  begin
    Result[I].Name := CNames[I]; Result[I].Section := CNames[I];
    Result[I].Cells := 64; Result[I].RepeatFrom := -1;
  end;
  Result[2].RepeatFrom := 0;
  SetLength(Result[2].Keep, 8);
  Result[2].Keep[0] := 'harmony'; Result[2].Keep[1] := 'rhythm';
  Result[2].Keep[2] := 'bass'; Result[2].Keep[3] := 'harmony-voice';
  Result[2].Keep[4] := 'lead'; Result[2].Keep[5] := 'kick';
  Result[2].Keep[6] := 'snare'; Result[2].Keep[7] := 'hat';
  LLast := High(Result);
  Result[LLast].Name := 'A variation'; Result[LLast].Section := 'A variation';
  Result[LLast].RepeatFrom := 0;
  SetLength(Result[LLast].Keep, 2);
  Result[LLast].Keep[0] := 'lead'; Result[LLast].Keep[1] := 'hat';
end;

function Starter: TInstrumentalStarter;
var LPattern: TPitchPattern; I: Integer;
begin
  LPattern := nil;
  SetLength(LPattern, 8);
  for I := 0 to 7 do
  begin
    LPattern[I] := Default(TPitchPatternCell);
    LPattern[I].Kind := pskPitch;
    LPattern[I].Note := 72;
    LPattern[I].Velocity := 80;
    LPattern[I].Attack := I mod 2 = 0;
  end;
  Result := TInstrumentalStarter.Create(0, False, LPattern);
end;

function Graph: TBusGraph;
var LSettings: array[0..6] of TBusSettings; LEcho: TEchoSettings; I: Integer;
begin
  for I := 0 to 6 do
  begin
    LSettings[I] := DefaultBusSettings; LSettings[I].Gain := 0.15;
    LSettings[I].SmoothingSeconds := 0;
  end;
  LSettings[6].Gain := 1;
  Result := TBusGraph.Create(8000, LSettings);
  for I := 0 to 5 do Result.AddSend(I, 6, stPostFader, 1, 0);
  LEcho := DefaultEchoSettings(8000); LEcho.DelayFrames := 311;
  Result.AddEffect(6, TEchoEffect.Create(8000, LEcho));
end;

function Render(const APull: Integer; const AStopAt: Integer = 0;
  const ABinding: TInstrumentalContextBinding = icbAllRoles;
  const AAdjacent: Boolean = False; const AStrongReturn: Boolean = False): TResult;
var LStarter: TInstrumentalStarter; LGraph: TBusGraph;
  LStream: TInstrumentalMusicStream; LCapture: TCapture;
  LOptions: TInstrumentalStreamOptions;
  LBlock: TAudioSamples; LStems: TBusSampleBlocks;
  LAt, I, J: Integer;
  LStopped, LRejectedEdit: Boolean;
  LForm: TMusicForm;
begin
  Result := Default(TResult);
  LStarter := Starter; LGraph := Graph; LStream := nil; LCapture := TCapture.Create;
  try
    LCapture.StopAt := AStopAt;
    LForm := MakeForm(AAdjacent);
    if AStrongReturn then LForm[2].EnergyOffset := 50;
    LOptions := DefaultInstrumentalStreamOptions(8000 * 16 * Length(LForm));
    LOptions.TailFrames := 800;
    LOptions.ContextBinding := ABinding;
    LStream := TInstrumentalMusicStream.Create(LStarter.Config, LStarter.CopyRoles,
      LStarter.CopyPercussion(8000), LGraph, LOptions, LStarter.ContextModel,
      LCapture.Keep, LForm);
    SetLength(Result.Mix, LStream.FrameCount * 2);
    SetLength(Result.Stems, 6);
    for I := 0 to 5 do SetLength(Result.Stems[I], Length(Result.Mix));
    LAt := 0; LStopped := False;
    try
      while LStream.ReadOutputs(APull, [0, 1, 2, 3, 4, 5], LBlock, LStems, LCapture.Observe) do
      begin
        if LAt = 0 then
        begin
          Check((LStream.PlannedCells = 16) and (LStream.LastVoicePlanningCells = 64) and
            (LStream.ContextLookaheadCells = LStream.VoiceLookaheadCells) and
            (LStream.VoiceLookaheadCells <= 256),
            'Only the joint16cell prefix commits; context/drum lookahead is provisional');
          LRejectedEdit := False;
          try LStream.IntersectFutureTokens(0, 0, [])
          except on E: EAudio do LRejectedEdit := True end;
          Check(LRejectedEdit, 'Future edits cannot overwrite a committed musical prefix');
        end;
        for I := 0 to High(LBlock) do
        begin
          Result.Mix[LAt + I] := LBlock[I];
          for J := 0 to 5 do Result.Stems[J][LAt + I] := LStems[J][I];
        end;
        Inc(LAt, Length(LBlock));
      end;
    except
      on E: EAudio do
      begin
        if E.Message = 'Operator stopped the form' then LStopped := True
        else raise;
      end;
    end;
    Result.Chunks := LCapture.Chunks;
    if AStopAt > 0 then
    begin
      Check(LStopped and (LStream.State = issFailed), 'Cancellation makes the producer terminal');
      Check(LStream.PlannedCells = AStopAt, 'Cancelled next phrase publishes no future decisions');
      Exit;
    end;
    Check((LStream.State = issCompleted) and (LAt = Length(Result.Mix)) and
      (LStream.TotalCells = 64 * Length(LForm)), 'Musical form performs every declared phrase through one stream');
    Check((Length(Result.Chunks) = 4 * Length(LForm)) and
      (LStream.PlannedSegments = 4 * Length(LForm)), 'Every declared phrase publishes four joint prefixes');
    CheckPerformedParts(Result, not AAdjacent, 1);
  finally
    LStream.Free; LCapture.Free; LGraph.Free; LStarter.Free;
  end;
end;

function SourceFreeForm(const APull: Integer;
  const ABoundedGuide: Boolean = False): TResult;
var
  LStarter: TInstrumentalStarter;
  LGraph: TBusGraph;
  LStream: TInstrumentalMusicStream;
  LOptions: TInstrumentalStreamOptions;
  LForm: TMusicForm;
  LBlock: TAudioSamples;
  LStems: TBusSampleBlocks;
  LCapture: TCapture;
  LGuide: TVoiceMasks;
  LDomainProvider: TInstrumentalDomainProvider;
  I, J, LAt: Integer;
begin
  Result := Default(TResult);
  LStarter := TInstrumentalStarter.Create;
  LGraph := Graph;
  LStream := nil;
  LCapture := TCapture.Create;
  try
    SetLength(LForm, 2);
    for I := 0 to 1 do
    begin
      LForm[I].Section := 'Authored';
      LForm[I].Name := 'Phrase ' + IntToStr(I);
      LForm[I].Cells := 8 + I * 8;
      LForm[I].RepeatFrom := -1;
    end;
    LOptions := DefaultInstrumentalStreamOptions(8000 * 6);
    LDomainProvider := nil;
    if ABoundedGuide then LDomainProvider := LStarter.GuideMasksRange;
    LStream := TInstrumentalMusicStream.Create(LStarter.Config, LStarter.CopyRoles,
      LStarter.CopyPercussion(8000), LGraph, LOptions, nil, LCapture.Keep, LForm,
      LDomainProvider);
    { Big Boss: original retained positive reproduction: same guide/seed and
      unequal8/16cell phrases. No learned context, seed sweep or relaxed domain. }
    LGuide := LStarter.GuideMasks(24);
    if not ABoundedGuide then
      for I := 0 to High(LGuide) do
        for J := 0 to High(LGuide[I]) do
          LStream.IntersectFutureTokens(I, LGuide[I][J].Position, LGuide[I][J].AllowedTokens);
    SetLength(Result.Mix, LStream.FrameCount * 2);
    SetLength(Result.Stems, 6);
    for I := 0 to 5 do SetLength(Result.Stems[I], Length(Result.Mix));
    LAt := 0;
    while LStream.ReadOutputs(APull, [0, 1, 2, 3, 4, 5], LBlock, LStems) do
    begin
      if LAt = 0 then
      begin
        Check((LStream.PlannedCells = 8) and (LStream.LastVoicePlanningCells = 24) and
          (LStream.VoiceLookaheadCells <= 256), 'Only the8cell prefix commits from the24cell voice plan');
        for I := 0 to High(LGuide[0]) do
          if LGuide[0][I].Position = 16 then
            LStream.IntersectFutureTokens(0, 16, LGuide[0][I].AllowedTokens);
        Check(LStream.PlannedCells = 8, 'Provisional voice suffix permits future-domain edits');
      end;
      for I := 0 to High(LBlock) do
      begin
        Result.Mix[LAt + I] := LBlock[I];
        for J := 0 to 5 do Result.Stems[J][LAt + I] := LStems[J][I];
      end;
      Inc(LAt, Length(LBlock));
    end;
    Result.Chunks := LCapture.Chunks;
    Check((LStream.State = issCompleted) and (Length(Result.Chunks) = 3) and
      (LAt = Length(Result.Mix)), 'Guided form performs unequal phrases without a context provider');
    for I := 0 to High(Result.Chunks) do
      Check(Length(Result.Chunks[I].Cells) = 8, 'Actual phrase boundaries set the common solve quantum');
    CheckPerformedParts(Result, False, 0.1);
  finally
    LStream.Free;
    LCapture.Free;
    LGraph.Free;
    LStarter.Free;
  end;
end;

{$ifndef pas2js}
procedure SaveProof(const AResult: TResult; const ADirectory: String);
var LClip: TAudioClip; LSamples: TAudioSamples; LPath: String;
  LFile: TFileStream; LWriter: TMusicDecisionWriter; I: Integer;
begin
  ForceDirectories(ADirectory);
  for I := 0 to 6 do
  begin
    LPath := IncludeTrailingPathDelimiter(ADirectory) + 'part-' + IntToStr(I) + '.wav';
    if FileExists(LPath) then raise EAudio.Create('Use a fresh form proof directory');
    if I = 6 then LSamples := AResult.Mix else LSamples := AResult.Stems[I];
    LClip := TAudioClip.Create(8000, 2, LSamples);
    try SaveWavePcm16(LPath, LClip) finally LClip.Free end;
  end;
  LPath := IncludeTrailingPathDelimiter(ADirectory) + 'decisions.pmd';
  if FileExists(LPath) then raise EAudio.Create('Use a fresh decision proof path');
  LFile := TFileStream.Create(LPath, fmCreate); LWriter := nil;
  try
    LWriter := TMusicDecisionWriter.Create(LFile);
    for I := 0 to High(AResult.Chunks) do LWriter.Append(AResult.Chunks[I]);
    WriteLn('Decision proof SHA-256: ', LWriter.Seal);
  finally LWriter.Free; LFile.Free end;
end;
{$endif}

function SameAudio(const A, B: TAudioSamples): Boolean;
var I: Integer;
begin
  Result := Length(A) = Length(B);
  if not Result then Exit;
  for I := 0 to High(A) do if A[I] <> B[I] then Exit(False);
end;

procedure VerifyHatCycle(const ATokens: TWfcModelTokens; const AExpected: Boolean);
var LStarter: TInstrumentalStarter;
  LDrums: TPercussionDefinitions;
  LOptions: TAcousticGenerationOptions;
  LConstraints: TWfcSequenceTokenConstraints;
  LTokens: TWfcModelTokens;
  LReport: TGraphSolveReport;
  I: Integer;
begin
  LStarter := Starter;
  try
    LDrums := LStarter.CopyPercussion(8000);
    LOptions := DefaultAcousticGenerationOptions;
    LOptions.FrameCount := 64;
    LOptions.Extent := wseWrap;
    SetLength(LConstraints, 64);
    for I := 0 to 63 do
      LConstraints[I] := MakeWfcSequenceTokenConstraint(I, [ATokens[I]]);
    LTokens := nil;
    if AExpected then
      Check(TryGenerateTokenSequence(LDrums[2].Model, LOptions, LConstraints, LTokens, LReport)
        and (LReport.Status = gssSolved),
        'Independent cyclic graph proves the newly selected adjacent Hat motif can loop')
    else
      Check(not TryGenerateTokenSequence(LDrums[2].Model, LOptions, LConstraints, LTokens, LReport)
        and (LReport.Status = gssContradiction),
        'Independent cyclic graph preserves rejection of the original captured Hat motif');
  finally LStarter.Free end;
end;

procedure VerifyOldRejectedCycle;
const
  { Big Boss: first64 Hat tokens decoded through TMusicDecisionReader from the
    preserved form-frontier audio01 journal (original digest c4355af4...124a1130).
    Fresh joint planning may choose a feasible motif; that must not erase this
    actual historical impossible cycle or turn its contradiction into a limit. }
  Vocabulary: array[0..3] of String = ('hit:100', 'hit:64', 'hit:80', 'rest');
  Choices: array[0..63] of Byte = (
    0,1,2,1,2,1,0,1,2,1,2,1,2,1,0,1,
    0,1,2,1,2,1,2,1,2,1,2,1,2,1,3,0,
    1,2,1,2,1,2,1,0,1,2,1,2,1,0,1,2,
    1,2,1,2,1,2,1,2,1,2,1,2,1,0,1,0);
var Tokens: TWfcModelTokens; I: Integer;
begin
  SetLength(Tokens, 64);
  for I := 0 to 63 do Tokens[I] := Vocabulary[Choices[I]];
  VerifyHatCycle(Tokens, False);
end;

function DecisionDigest(const ASource: TResult): String;
var LStream: TMemoryStream; LWriter: TMusicDecisionWriter; I: Integer;
begin
  LStream := TMemoryStream.Create; LWriter := nil;
  try
    LWriter := TMusicDecisionWriter.Create(LStream);
    for I := 0 to High(ASource.Chunks) do LWriter.Append(ASource.Chunks[I]);
    Result := LWriter.Seal;
  finally LWriter.Free; LStream.Free end;
end;

procedure Run;
var LFirst, LSecond, LCancelled, LAdjacent, LShort, LShortReplay: TResult;
  I, J, K, LChangedParts: Integer; LDifferent, LHasAttack: Boolean;
  LDigest: String;
  LHat: TWfcModelTokens;
begin
  VerifyOldRejectedCycle;
  LAdjacent := Render(2048, 0, icbAllRoles, True);
  SetLength(LHat, 64);
  for I := 0 to 63 do LHat[I] := LAdjacent.Chunks[I div 16].Providers[8].Tokens[I mod 16];
  VerifyHatCycle(LHat, True);
  LFirst := Render(2048);
  LDigest := DecisionDigest(LFirst);
  WriteLn('Decision digest: ', LDigest);
  { Version5 selects shared context/drum negotiation and domain preparation.
    The former c4355af4...124a1130 journal remains historical evidence above. }
  Check(LDigest = '21131a9f6102818393c249c9a5bc273c7e0529b7943a361ed701a64a742bdd4f',
    'Fixed joint form/seed/models retain identical actual decisions on native and pas2js');
  LSecond := Render(173);
  Check(SameAudio(LFirst.Mix, LSecond.Mix), 'Continuous mix/effects replay exactly across PCM pulls');
  for I := 0 to 5 do
    Check(SameAudio(LFirst.Stems[I], LSecond.Stems[I]), 'Each part replays across PCM pulls');
  LDifferent := False;
  for I := 0 to 3 do
  begin
    for J := 1 to High(LFirst.Chunks[I].Providers) do
      for K := 0 to 15 do
        Check(LFirst.Chunks[I].Providers[J].Tokens[K] =
          LFirst.Chunks[I + 8].Providers[J].Tokens[K],
          'An explicit return retains all eight musical providers through a newly solved frontier');
    for J := 0 to 15 do
    begin
      Check(SameMusicDecisionFrame(LFirst.Chunks[I].Cells[J].Parts,
        LFirst.Chunks[I + 8].Cells[J].Parts), 'Returned six-part musical decisions are exact');
      Check(LFirst.Chunks[I].Providers[5].Tokens[J] =
        LFirst.Chunks[I + 16].Providers[5].Tokens[J], 'Lead motif is held in the selective variation');
      Check(LFirst.Chunks[I].Providers[8].Tokens[J] =
        LFirst.Chunks[I + 16].Providers[8].Tokens[J], 'Hat motif is held in the selective variation');
      LDifferent := LDifferent or not SameMusicDecisionFrame(LFirst.Chunks[I].Cells[J].Parts,
        LFirst.Chunks[I + 4].Cells[J].Parts);
    end;
  end;
  Check(LDifferent, 'The fresh contrasting section contains different actual music');
  for I := 1 to High(LFirst.Chunks) do
    Check(SameMusicDecisionFrame(LFirst.Chunks[I].Previous,
      LFirst.Chunks[I - 1].Cells[15].Parts), 'Real holds/predecessors continue across phrase boundaries');
  LCancelled := Render(2048, 64);
  Check(Length(LCancelled.Chunks) = 4, 'Stopped form retains only its earlier declared phrase');
  LSecond := Render(2048, 64, icbDrivenRole);
  Check(Length(LSecond.Chunks) = 4, 'Driven-role context consumer also uses the form path');
  LShort := SourceFreeForm(2048);
  LShortReplay := SourceFreeForm(173, True);
  Check(SameAudio(LShort.Mix, LShortReplay.Mix),
    'Bounded guide callback and original full guide perform identical mix across PCM pulls');
  Check(DecisionDigest(LShort) = DecisionDigest(LShortReplay),
    'Bounded guide callback retains exact original model choices and section boundaries');
  for I := 0 to 5 do
    Check(SameAudio(LShort.Stems[I], LShortReplay.Stems[I]), 'Unequal-phrase parts replay across PCM pulls');
  LSecond := Render(2048, 0, icbAllRoles, False, True);
  for I := 0 to High(LFirst.Chunks) do
    for J := 0 to High(LFirst.Chunks[I].Providers) do
      for K := 0 to High(LFirst.Chunks[I].Providers[J].States) do
        Check((LFirst.Chunks[I].Providers[J].States[K] = LSecond.Chunks[I].Providers[J].States[K]) and
          (LFirst.Chunks[I].Providers[J].Tokens[K] = LSecond.Chunks[I].Providers[J].Tokens[K]),
          'Section energy preserves every real WFC choice, including the repeated motif');
  LChangedParts := 0;
  for I := 0 to 5 do
  begin
    LDifferent := False;
    LHasAttack := False;
    for J := 8 to 11 do
      for K := 0 to High(LFirst.Chunks[J].Cells) do
        LHasAttack := LHasAttack or (LFirst.Chunks[J].Cells[K].Parts[I].Action = caAttack);
    for J := 0 to 32 * 8000 * 2 - 1 do
      Check(LFirst.Stems[I][J] = LSecond.Stems[I][J],
        'A future energy change never alters already performed music');
    for J := 32 * 8000 * 2 to 48 * 8000 * 2 - 1 do
      LDifferent := LDifferent or (LFirst.Stems[I][J] <> LSecond.Stems[I][J]);
    if LHasAttack then
    begin
      Check(LDifferent, 'The stronger retained motif changes each attacking instrument part');
      Inc(LChangedParts);
    end
    else Check(not LDifferent, 'Attack expression does not fabricate audio or restart a hold');
  end;
  Check(LChangedParts > 0, 'Section energy changes actual performed music');
  {$ifndef pas2js}
  if ParamCount = 1 then
  begin
    SaveProof(LFirst, ParamStr(1));
    SaveProof(LShort, IncludeTrailingPathDelimiter(ParamStr(1)) + 'unequal-phrases');
  end;
  {$endif}
  WriteLn('PASS ', GChecks, ' instrumental form checks');
end;

begin
  try Run except on E: Exception do
  begin WriteLn('FAIL: ', E.Message); ExitCode := 1 end end;
end.
