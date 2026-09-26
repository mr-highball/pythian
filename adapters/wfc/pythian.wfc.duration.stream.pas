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
unit pythian.wfc.duration.stream;

{$mode delphi}
{$H+}

interface

uses
  pythian.bus, pythian.schedule, pythian.synth, pythian.time,
  pythian.pitch.track, pythian.wfc.instrument,
  wfc, wfc_model, wfc_sequence, wfc_sequence_graph, wfc_music_voices_graph;

type
  TDurationProvider = (dpKey, dpTempo, dpDuration);
  TDurationProviders = set of TDurationProvider;
  TDurationModels = array[TDurationProvider] of TWfcSequenceModel;
  TDurationGrid = array of Integer; { Explicit finite cell boundaries, origin zero. }
  TDurationRoleNames = array of String;
  TDurationMasks = array[TDurationProvider] of TWfcSequenceTokenConstraints;
  TDurationMusicMasks = array of TWfcSequenceTokenConstraints;
  TDurationEdit = record
    Revision: Int64;
    FromSpan, SpanCount: Integer;
    Regenerate: TDurationProviders;
    RegenerateMusic, RequireObservedEnd: Boolean;
    Seed: TGraphSeed;
    { Complete transaction masks in absolute cell coordinates. Frozen prefix
      masks must agree. Empty masks deliberately leave the future unconstrained. }
    Masks: TDurationMasks;
    MusicMasks: TDurationMusicMasks; { Harmony, joint rhythm, declared roles. }
  end;
  TDurationStreamOptions = record
    TicksPerQuarter, LeadRole, OutputBus: Integer;
    MaxBacktracks, MaxPassBacktracks, VoiceLimit, WorkLimit: Integer;
    MaxPlanFrames: Int64;
  end;
  TDurationEditResult = (derAccepted, derConflict, derCoverage,
    derCommittedNote, derFrameLimit, derVoiceLimit, derWorkLimit);
  TDurationNote = record
    Role, Pitch, Velocity, AttackSpan: Integer;
    StartFrame, GateFrames: Int64;
  end;
  TDurationNotes = array of TDurationNote;
  TDurationSequences = array[TDurationProvider] of TWfcGeneratedSequenceSegment;

  { Owns immutable model clones and a private native scheduler. The
    instruments are borrowed immutable for the lifetime, including release tails.
    Bus processing belongs exclusively to this stream.
    No import of latent cursor, playback snapshot or saved-style checkpoint. }
  TDurationStream = class
  strict private
    type
      TPlan = class
        Sequences: TDurationSequences;
        Music: TWfcMusicVoicesGeneratedLayers;
        Spans: TTimedPitchSpans;
        Clock: TTempoMap;
        Notes: TDurationNotes;
        destructor Destroy; override;
      end;
  strict private
    FModels: TDurationModels;
    FConfig: TWfcMusicVoicesGraphConfig;
    FNames: TDurationRoleNames;
    FKeyGrid, FTempoGrid: TDurationGrid;
    FInstruments: TStyleInstruments;
    FOptions: TDurationStreamOptions;
    FSynth: TScheduledSynth;
    FRate: Integer;
    FPlan: TPlan;
    FRevision: Int64;
    function GetNextFrame: Int64;
    function GetFailed: Boolean;
    procedure BuildNotes(const APlan: TPlan);
    function SolveSequence(const AModel: TWfcSequenceModel;
      const APrevious: TWfcGeneratedSequenceSegment; const AFrom, ACount: Integer;
      const AEdit: TDurationEdit; const AMasks: TWfcSequenceTokenConstraints;
      out ASequence: TWfcGeneratedSequenceSegment): Boolean;
  public
    constructor Create(const AModels: TDurationModels;
      const AKeyGrid, ATempoGrid: TDurationGrid;
      const AConfig: TWfcMusicVoicesGraphConfig;
      const ARoles: TDurationRoleNames; const AInstruments: TStyleInstruments;
      const ABus: TBusGraph; const AOptions: TDurationStreamOptions);
    destructor Destroy; override;
    { All staging, proof and allocation precede native future admission.
      Result other than accepted, or an exception, preserves accepted plan.
      No retry across duration/context/ensemble stages is implicit. }
    function TryEdit(const AEdit: TDurationEdit): TDurationEditResult;
    function CopySpans: TTimedPitchSpans;
    function CopyNotes: TDurationNotes;
    function CopySequence(const AProvider: TDurationProvider): TWfcGeneratedSequenceSegment;
    function CopyMusic(const AModelIndex: Integer): TWfcGeneratedSequenceSegment;
    function ModelText(const AProvider: TDurationProvider): String;
    function MusicModelText(const AModelIndex: Integer): String;
    function RoleModelIndex(const AName: String): Integer;
    procedure Process(out ALeft, ARight: Double);
    property Revision: Int64 read FRevision;
    property NextFrame: Int64 read GetNextFrame;
    property Failed: Boolean read GetFailed;
  end;

function DefaultDurationStreamOptions: TDurationStreamOptions;

implementation

uses
  SysUtils, pythian.audio, pythian.music.context, pythian.tonal,
  pythian.wfc.context, pythian.wfc.pitch,
  wfc_sequence_text, wfc_music, wfc_music_sequence, wfc_music_ensemble;

function DefaultDurationStreamOptions: TDurationStreamOptions;
begin
  Result := Default(TDurationStreamOptions);
  Result.TicksPerQuarter := 480;
  Result.MaxBacktracks := 256;
  Result.MaxPassBacktracks := 32;
  Result.VoiceLimit := 128;
  Result.WorkLimit := 1000000;
  Result.MaxPlanFrames := 10000000;
end;

function CloneSequence(const AValue: TWfcGeneratedSequenceSegment): TWfcGeneratedSequenceSegment;
begin
  Result := AValue;
  Result.StateIndices := Copy(AValue.StateIndices);
  Result.Tokens := Copy(AValue.Tokens);
end;

function SegmentBoundary(const APrevious: TWfcGeneratedSequenceSegment;
  const AFrom: Integer; const AEnd: Boolean): TWfcSequenceSegmentBoundary;
begin
  if AFrom = 0 then Result := MakeWfcSequenceInitialSegmentBoundary(AEnd)
  else Result := MakeWfcSequenceContinuingSegmentBoundary(APrevious.StateIndices[AFrom - 1], AEnd);
end;

function JoinSequence(const APrevious, ASuffix: TWfcGeneratedSequenceSegment;
  const AFrom: Integer): TWfcGeneratedSequenceSegment;
var
  LIndex: Integer;
begin
  Result := Default(TWfcGeneratedSequenceSegment);
  Result.Boundary := MakeWfcSequenceInitialSegmentBoundary(ASuffix.Boundary.RequireObservedEnd);
  SetLength(Result.StateIndices, AFrom + Length(ASuffix.StateIndices));
  SetLength(Result.Tokens, Length(Result.StateIndices));
  for LIndex := 0 to High(Result.Tokens) do
    if LIndex < AFrom then
    begin
      Result.StateIndices[LIndex] := APrevious.StateIndices[LIndex];
      Result.Tokens[LIndex] := APrevious.Tokens[LIndex];
    end
    else
    begin
      Result.StateIndices[LIndex] := ASuffix.StateIndices[LIndex - AFrom];
      Result.Tokens[LIndex] := ASuffix.Tokens[LIndex - AFrom];
    end;
end;

function LocalMasks(const AModel: TWfcSequenceModel;
  const AMasks: TWfcSequenceTokenConstraints;
  const APrevious: TWfcGeneratedSequenceSegment; const AFrom, ACount: Integer): TWfcSequenceTokenConstraints;
var
  LIndex, LToken, LCount: Integer;
  LFound: Boolean;
begin
  ValidateSequenceTokenConstraints(AModel, ACount, AMasks);
  Result := nil;
  for LIndex := 0 to High(AMasks) do
  begin
    if AMasks[LIndex].Position < AFrom then
    begin
      LFound := False;
      for LToken := 0 to High(AMasks[LIndex].AllowedTokens) do
        if AMasks[LIndex].AllowedTokens[LToken] = APrevious.Tokens[AMasks[LIndex].Position] then
          LFound := True;
      if not LFound then raise EAudio.Create('Edit mask conflicts with frozen provider prefix');
    end
    else
    begin
      LCount := Length(Result);
      SetLength(Result, LCount + 1);
      Result[LCount] := MakeWfcSequenceTokenConstraint(AMasks[LIndex].Position - AFrom,
        AMasks[LIndex].AllowedTokens);
    end;
  end;
end;

procedure ValidateGrid(const AGrid: TDurationGrid);
var LIndex: Integer;
begin
  if (Length(AGrid) < 2) or (Length(AGrid) > 1025) or (AGrid[0] <> 0) then
    raise EAudio.Create('Duration context requires 1..1024 finite cells at tick zero');
  for LIndex := 1 to High(AGrid) do
    if AGrid[LIndex] <= AGrid[LIndex - 1] then
      raise EAudio.Create('Duration context boundaries must strictly increase');
end;

constructor TDurationStream.Create(const AModels: TDurationModels;
  const AKeyGrid, ATempoGrid: TDurationGrid;
  const AConfig: TWfcMusicVoicesGraphConfig;
  const ARoles: TDurationRoleNames; const AInstruments: TStyleInstruments;
  const ABus: TBusGraph; const AOptions: TDurationStreamOptions);
var LProvider: TDurationProvider; LIndex, LOther: Integer;
begin
  inherited Create;
  ValidateGrid(AKeyGrid);
  ValidateGrid(ATempoGrid);
  ValidateWfcMusicVoicesGraphConfig(AConfig);
  if (ABus = nil) or (Length(AConfig.Voices) > 6) or
    (Length(ARoles) <> Length(AConfig.Voices)) or
    (Length(AInstruments) <> Length(ARoles)) or (AConfig.StepsPerOctave <> 12) or
    (AOptions.LeadRole < 0) or (AOptions.LeadRole >= Length(ARoles)) or
    (AOptions.TicksPerQuarter < 1) or (AOptions.TicksPerQuarter > 32767) or
    (AOptions.MaxBacktracks < 0) or (AOptions.MaxBacktracks > 65536) or
    (AOptions.MaxPassBacktracks < 0) or (AOptions.MaxPassBacktracks > 65536) or
    (AOptions.MaxPlanFrames < 1) then
    raise EAudio.Create('Duration stream configuration exceeds its finite policy');
  if (AOptions.OutputBus < 0) or (AOptions.OutputBus >= ABus.BusCount) then
    raise EAudio.Create('Duration output bus is invalid');
  FRate := ABus.SampleRate;
  for LIndex := 0 to High(ARoles) do
  begin
    if (Trim(ARoles[LIndex]) = '') or (AInstruments[LIndex] = nil) or
      (AInstruments[LIndex].SampleRate <> FRate) then
      raise EAudio.Create('Duration roles and instrument clocks must be explicit');
    for LOther := 0 to LIndex - 1 do
      if ARoles[LIndex] = ARoles[LOther] then raise EAudio.Create('Duplicate duration role');
  end;
  for LProvider := Low(TDurationProvider) to High(TDurationProvider) do
  begin
    if AModels[LProvider] = nil then raise EAudio.Create('Missing duration provider');
    if AModels[LProvider].StateCount > 256 then raise EAudio.Create('Duration provider exceeds state bound');
    FModels[LProvider] := DecodeWfcSequenceText(EncodeWfcSequenceText(AModels[LProvider]));
  end;
  FConfig := CopyWfcMusicVoicesGraphConfig(AConfig);
  FConfig.HarmonyModel := nil;
  FConfig.RhythmModel := nil;
  for LIndex := 0 to High(FConfig.Voices) do FConfig.Voices[LIndex].Model := nil;
  FConfig.HarmonyModel := DecodeWfcSequenceText(EncodeWfcSequenceText(AConfig.HarmonyModel));
  FConfig.RhythmModel := DecodeWfcSequenceText(EncodeWfcSequenceText(AConfig.RhythmModel));
  for LIndex := 0 to High(FConfig.Voices) do
    FConfig.Voices[LIndex].Model := DecodeWfcSequenceText(EncodeWfcSequenceText(AConfig.Voices[LIndex].Model));
  for LIndex := 0 to WfcMusicVoicesModelCount(FConfig) - 1 do
    if WfcMusicVoicesModelAt(FConfig, LIndex).StateCount > 256 then
      raise EAudio.Create('Duration musical provider exceeds state bound');
  FNames := Copy(ARoles);
  FInstruments := Copy(AInstruments);
  FKeyGrid := Copy(AKeyGrid);
  FTempoGrid := Copy(ATempoGrid);
  FOptions := AOptions;
  FSynth := TScheduledSynth.Create(ABus, AOptions.VoiceLimit, AOptions.WorkLimit);
end;

destructor TDurationStream.TPlan.Destroy;
begin
  Clock.Free;
  inherited;
end;

destructor TDurationStream.Destroy;
var LProvider: TDurationProvider; LIndex: Integer;
begin
  FSynth.Free;
  FPlan.Free;
  for LProvider := Low(TDurationProvider) to High(TDurationProvider) do FModels[LProvider].Free;
  FConfig.HarmonyModel.Free;
  FConfig.RhythmModel.Free;
  for LIndex := 0 to High(FConfig.Voices) do FConfig.Voices[LIndex].Model.Free;
  inherited;
end;

function TDurationStream.SolveSequence(const AModel: TWfcSequenceModel;
  const APrevious: TWfcGeneratedSequenceSegment; const AFrom, ACount: Integer;
  const AEdit: TDurationEdit; const AMasks: TWfcSequenceTokenConstraints;
  out ASequence: TWfcGeneratedSequenceSegment): Boolean;
var
  LGraph: TGraph;
  LBoundary: TWfcSequenceSegmentBoundary;
  LLocal: TWfcSequenceTokenConstraints;
  LChunk: TWfcGeneratedSequenceSegment;
  LOptions: TGraphSolveOptions;
  LReport: TGraphSolveReport;
  LValidation: TWfcSequenceGraphValidationReport;
  LFalse: Integer;
begin
  LLocal := LocalMasks(AModel, AMasks, APrevious, AFrom, ACount);
  if AFrom = ACount then
  begin
    if AEdit.RequireObservedEnd and not ValidateSequenceStatePath(AModel,
      APrevious.StateIndices, wseWhole, LValidation) then Exit(False);
    ASequence := CloneSequence(APrevious);
    Exit(True);
  end;
  LBoundary := SegmentBoundary(APrevious, AFrom, AEdit.RequireObservedEnd);
  LGraph := TGraph.Create;
  try
    LGraph.Reshape(ACount - AFrom, 1, 1);
    LGraph.WrapNeighbors := False;
    LGraph.Seed := AEdit.Seed;
    ApplySequenceModelSegmentToGraph(AModel, LGraph, LBoundary);
    IntersectSequenceTokenConstraints(AModel, LGraph, LLocal);
    LOptions := DefaultGraphSolveOptions;
    LOptions.MaxBacktracks := FOptions.MaxBacktracks;
    Result := LGraph.TrySolve(LOptions, LReport);
    if not Result then Exit;
    if not CaptureSolvedSequenceSegment(AModel, LGraph, LBoundary, LChunk, LValidation) or
      not SequenceStatesSatisfyEntryConstraints(AModel, LGraph, LChunk.StateIndices, LFalse) then
      raise EAudio.Create('Duration sequence failed independent continuation proof');
    ASequence := JoinSequence(APrevious, LChunk, AFrom);
  finally
    LGraph.Free;
  end;
end;

function FirstEditable(const AGrid: TDurationGrid; const ATick: Integer): Integer;
begin
  Result := 0;
  while (Result < High(AGrid)) and (AGrid[Result] < ATick) do Inc(Result);
end;

function GridCell(const AGrid: TDurationGrid; const ATick: Integer): Integer;
begin
  if (ATick < 0) or (ATick >= AGrid[High(AGrid)]) then
    raise EAudio.Create('Duration provider does not cover requested tick');
  Result := 0;
  while AGrid[Result + 1] <= ATick do Inc(Result);
end;

function KeyAllows(const AKey: TKeyContext; const APitch: Integer): Boolean;
const CSteps: array[TDiatonicMode, 0..6] of Integer =
  ((0, 2, 4, 5, 7, 9, 11), (0, 2, 3, 5, 7, 8, 10));
var LIndex: Integer;
begin
  if AKey.Root < 0 then Exit(True); { Explicit unconstrained unknown-key policy. }
  for LIndex := 0 to 6 do
    if ((APitch - AKey.Root + 120) mod 12) = CSteps[AKey.Mode, LIndex] then Exit(True);
  Result := False;
end;

procedure TDurationStream.BuildNotes(const APlan: TPlan);
var
  LRole, LSpan, LTone, LIndex, LCount: Integer;
  LCell: TWfcMusicVoiceCell;
  LActive: array of Integer;
  LNote, LSwap: TDurationNote;
begin
  APlan.Notes := nil;
  for LRole := 0 to High(FNames) do
  begin
    LActive := nil;
    for LSpan := 0 to High(APlan.Spans) do
    begin
      LCell := DecodeWfcMusicEnsembleFrame(APlan.Music[LRole + 2].Tokens[LSpan]).Voices[0];
      if LCell.Action <> wmcaHold then LActive := nil;
      if LCell.Action = wmcaAttack then
      begin
        SetLength(LActive, Length(LCell.Tones));
        for LTone := 0 to High(LCell.Tones) do
        begin
          LNote.Role := LRole;
          LNote.Pitch := LCell.Tones[LTone].Pitch;
          LNote.Velocity := LCell.Tones[LTone].Velocity;
          LNote.AttackSpan := LSpan;
          LNote.StartFrame := APlan.Clock.FrameAtTick(APlan.Spans[LSpan].StartTick, FRate);
          LNote.GateFrames := 0;
          LCount := Length(APlan.Notes);
          if LCount >= MaximumScheduledVoices then raise EAudio.Create('Duration note ledger exceeds bound');
          SetLength(APlan.Notes, LCount + 1);
          APlan.Notes[LCount] := LNote;
          LActive[LTone] := LCount;
        end;
      end;
      for LTone := 0 to High(LActive) do
      begin
        LIndex := LActive[LTone];
        APlan.Notes[LIndex].GateFrames := APlan.Clock.FrameAtTick(APlan.Spans[LSpan].EndTick, FRate) -
          APlan.Notes[LIndex].StartFrame;
        if APlan.Notes[LIndex].GateFrames < 1 then
          raise EAudio.Create('Duration note has no sample-frame extent');
      end;
    end;
  end;
  { Stable admission order: absolute start, then declared role and chord pitch. }
  for LIndex := 1 to High(APlan.Notes) do
  begin
    LCount := LIndex;
    while (LCount > 0) and (APlan.Notes[LCount].StartFrame < APlan.Notes[LCount - 1].StartFrame) do
    begin
      LSwap := APlan.Notes[LCount];
      APlan.Notes[LCount] := APlan.Notes[LCount - 1];
      APlan.Notes[LCount - 1] := LSwap;
      Dec(LCount);
    end;
  end;
end;

function SameNote(const ALeft, ARight: TDurationNote): Boolean;
begin
  Result := (ALeft.Role = ARight.Role) and (ALeft.Pitch = ARight.Pitch) and
    (ALeft.Velocity = ARight.Velocity) and (ALeft.AttackSpan = ARight.AttackSpan) and
    (ALeft.StartFrame = ARight.StartFrame) and (ALeft.GateFrames = ARight.GateFrames);
end;

function TDurationStream.TryEdit(const AEdit: TDurationEdit): TDurationEditResult;
var
  LCandidate, LOld: TPlan;
  LProvider: TDurationProvider;
  LPrevious: TWfcGeneratedSequenceSegment;
  LFrom, LCount, LPivotTick, LIndex, LRole, LToken, LTone, LKeyCell, LOut: Integer;
  LPivotFrame, LTick, LId: Int64;
  LCell: TPitchDurationCell;
  LChanges: TTempoChanges;
  LGraph: TGraph;
  LBoundaries: TWfcMusicVoicesBoundaries;
  LGenerated: TWfcMusicVoicesGenerated;
  LProof: TWfcMusicVoicesValidationReport;
  LOptions: TGraphNegotiationOptions;
  LReport: TGraphNegotiationReport;
  LAllowed: TWfcModelTokens;
  LMask, LLocal: TWfcSequenceTokenConstraints;
  LFrame: TWfcMusicEnsembleFrame;
  LKey: TKeyContext;
  LAccept, LMusic: Boolean;
  LModel: TWfcSequenceModel;
  LTones, LPlanned: TFrameTones;
  LSchedule: TScheduleResult;
  LValidation: TWfcSequenceGraphValidationReport;
begin
  if Failed then raise EAudio.Create('Duration stream processing failed; create a fresh playback epoch');
  if (AEdit.Revision <> FRevision) or (FRevision = High(Int64)) or
    (AEdit.FromSpan < 0) or (AEdit.SpanCount < 1) or (AEdit.SpanCount > 1024) or
    (AEdit.FromSpan >= AEdit.SpanCount) or
    (Length(AEdit.MusicMasks) <> WfcMusicVoicesModelCount(FConfig)) then
    raise EAudio.Create('Duration edit revision, span range or complete musical mask vector is invalid');
  if FPlan = nil then
  begin
    if (AEdit.FromSpan <> 0) or (AEdit.Regenerate <> [dpKey, dpTempo, dpDuration]) or
      not AEdit.RegenerateMusic or (NextFrame <> 0) then
      raise EAudio.Create('Initial duration plan requires every provider before playback');
    LPivotTick := 0;
    LPivotFrame := 0;
  end
  else
  begin
    if AEdit.FromSpan > Length(FPlan.Spans) then raise EAudio.Create('Edit pivot exceeds accepted endpoint');
    if AEdit.FromSpan = Length(FPlan.Spans) then LPivotTick := FPlan.Spans[High(FPlan.Spans)].EndTick
    else LPivotTick := FPlan.Spans[AEdit.FromSpan].StartTick;
    LPivotFrame := FPlan.Clock.FrameAtTick(LPivotTick, FRate);
    if LPivotFrame < NextFrame then raise EAudio.Create('Edit pivot is already emitted');
    if (AEdit.SpanCount <> Length(FPlan.Spans)) and not (dpDuration in AEdit.Regenerate) then
      raise EAudio.Create('Changing span count requires duration regeneration');
  end;
  LCandidate := TPlan.Create;
  try
    for LProvider := Low(TDurationProvider) to High(TDurationProvider) do
    begin
      LPrevious := Default(TWfcGeneratedSequenceSegment);
      if FPlan <> nil then LPrevious := FPlan.Sequences[LProvider];
      case LProvider of
        dpKey: begin LCount := High(FKeyGrid); LFrom := FirstEditable(FKeyGrid, LPivotTick); end;
        dpTempo: begin LCount := High(FTempoGrid); LFrom := FirstEditable(FTempoGrid, LPivotTick); end;
        else begin LCount := AEdit.SpanCount; LFrom := AEdit.FromSpan; end;
      end;
      if not (LProvider in AEdit.Regenerate) then LFrom := LCount;
      if not SolveSequence(FModels[LProvider], LPrevious, LFrom, LCount, AEdit,
        AEdit.Masks[LProvider], LCandidate.Sequences[LProvider]) then Exit(derConflict);
    end;
    SetLength(LCandidate.Spans, AEdit.SpanCount);
    LTick := 0;
    for LIndex := 0 to AEdit.SpanCount - 1 do
    begin
      LCell := DecodePitchDurationToken(LCandidate.Sequences[dpDuration].Tokens[LIndex]);
      if LTick + LCell.Duration > High(Integer) then Exit(derCoverage);
      LCandidate.Spans[LIndex].StartTick := Integer(LTick);
      Inc(LTick, LCell.Duration);
      LCandidate.Spans[LIndex].EndTick := Integer(LTick);
      LCandidate.Spans[LIndex].Kind := LCell.Kind;
      LCandidate.Spans[LIndex].Note := LCell.Note;
    end;
    if (LTick > FKeyGrid[High(FKeyGrid)]) or (LTick > FTempoGrid[High(FTempoGrid)]) then Exit(derCoverage);
    LChanges := nil;
    for LIndex := 0 to High(FTempoGrid) - 1 do
    begin
      LCount := TempoContextFromToken(LCandidate.Sequences[dpTempo].Tokens[LIndex]);
      if FTempoGrid[LIndex] < LTick then
      begin
        LOut := Length(LChanges);
        SetLength(LChanges, LOut + 1);
        LChanges[LOut].Tick := FTempoGrid[LIndex];
        LChanges[LOut].MicrosecondsPerQuarter := LCount;
      end;
    end;
    for LIndex := 0 to High(LCandidate.Sequences[dpKey].Tokens) do
      KeyContextFromToken(LCandidate.Sequences[dpKey].Tokens[LIndex]);
    LCandidate.Clock := TTempoMap.Create(FOptions.TicksPerQuarter, Integer(LTick), LChanges);
    if LCandidate.Clock.FrameAtTick(Integer(LTick), FRate) > FOptions.MaxPlanFrames then Exit(derFrameLimit);
    if LCandidate.Clock.FrameAtTick(LPivotTick, FRate) <> LPivotFrame then Exit(derCommittedNote);
    LMusic := AEdit.RegenerateMusic or (dpKey in AEdit.Regenerate) or (dpDuration in AEdit.Regenerate);
    SetLength(LCandidate.Music, WfcMusicVoicesModelCount(FConfig));
    if LMusic then
    begin
      SetLength(LBoundaries, Length(LCandidate.Music));
      for LIndex := 0 to High(LBoundaries) do
      begin
        LPrevious := Default(TWfcGeneratedSequenceSegment);
        if FPlan <> nil then LPrevious := FPlan.Music[LIndex];
        LBoundaries[LIndex] := SegmentBoundary(LPrevious, AEdit.FromSpan, AEdit.RequireObservedEnd);
      end;
      LGraph := BuildWfcMusicVoicesSegmentGraph(FConfig, AEdit.SpanCount - AEdit.FromSpan,
        AEdit.Seed, LBoundaries);
      try
        for LIndex := 0 to High(LBoundaries) do
        begin
          LPrevious := Default(TWfcGeneratedSequenceSegment);
          if FPlan <> nil then LPrevious := FPlan.Music[LIndex];
          LModel := WfcMusicVoicesModelAt(FConfig, LIndex);
          LLocal := LocalMasks(LModel, AEdit.MusicMasks[LIndex], LPrevious, AEdit.FromSpan, AEdit.SpanCount);
          IntersectSequenceTokenConstraints(LModel, LGraph.PassGraph[LIndex], LLocal);
        end;
        for LRole := 0 to High(FNames) do
          for LIndex := AEdit.FromSpan to AEdit.SpanCount - 1 do
          begin
            LModel := FConfig.Voices[LRole].Model;
            LAllowed := nil;
            LKeyCell := GridCell(FKeyGrid, LCandidate.Spans[LIndex].StartTick);
            LKey := KeyContextFromToken(LCandidate.Sequences[dpKey].Tokens[LKeyCell]);
            for LToken := 0 to LModel.PublicTokenCount - 1 do
            begin
              LFrame := DecodeWfcMusicEnsembleFrame(LModel.PublicTokenAt(LToken));
              LAccept := True;
              if LCandidate.Spans[LIndex].Kind <> pskPitch then
                LAccept := LFrame.Voices[0].Action = wmcaRest
              else
              begin
                if LRole = FOptions.LeadRole then
                  LAccept := (Length(LFrame.Voices[0].Tones) = 1) and
                    (LFrame.Voices[0].Tones[0].Pitch = LCandidate.Spans[LIndex].Note);
                if LFrame.Voices[0].Action = wmcaAttack then
                  for LTone := 0 to High(LFrame.Voices[0].Tones) do
                    LAccept := LAccept and KeyAllows(LKey, LFrame.Voices[0].Tones[LTone].Pitch);
              end;
              if LAccept then
              begin
                LOut := Length(LAllowed);
                SetLength(LAllowed, LOut + 1);
                LAllowed[LOut] := LModel.PublicTokenAt(LToken);
              end;
            end;
            if Length(LAllowed) = 0 then Exit(derConflict);
            SetLength(LMask, 1);
            LMask[0] := MakeWfcSequenceTokenConstraint(LIndex - AEdit.FromSpan, LAllowed);
            IntersectSequenceTokenConstraints(LModel, LGraph.PassGraph[LRole + 2], LMask);
          end;
        LOptions := DefaultGraphNegotiationOptions;
        LOptions.SolveOptions.MaxBacktracks := FOptions.MaxBacktracks;
        LOptions.MaxPassBacktracks := FOptions.MaxPassBacktracks;
        if not LGraph.TrySolveNegotiated(LOptions, LReport) then Exit(derConflict);
        if not CaptureSolvedWfcMusicVoices(FConfig, LGraph, LBoundaries, LGenerated, LProof) then
          raise EAudio.Create('Duration ensemble failed independent semantic proof: ' + LProof.Issue.Detail);
        for LIndex := 0 to High(LBoundaries) do
        begin
          LPrevious := Default(TWfcGeneratedSequenceSegment);
          if FPlan <> nil then LPrevious := FPlan.Music[LIndex];
          LCandidate.Music[LIndex] := JoinSequence(LPrevious, LGenerated.Layers[LIndex], AEdit.FromSpan);
        end;
      finally
        LGraph.Free;
      end;
    end
    else
      for LIndex := 0 to High(LCandidate.Music) do
      begin
        LLocal := LocalMasks(WfcMusicVoicesModelAt(FConfig, LIndex), AEdit.MusicMasks[LIndex],
          FPlan.Music[LIndex], AEdit.SpanCount, AEdit.SpanCount);
        if AEdit.RequireObservedEnd and not ValidateSequenceStatePath(
          WfcMusicVoicesModelAt(FConfig, LIndex), FPlan.Music[LIndex].StateIndices,
          wseWhole, LValidation) then Exit(derConflict);
        LCandidate.Music[LIndex] := CloneSequence(FPlan.Music[LIndex]);
      end;
    BuildNotes(LCandidate);
    if FPlan <> nil then
    begin
      LIndex := 0;
      while (LIndex < Length(FPlan.Notes)) and (FPlan.Notes[LIndex].StartFrame < LPivotFrame) do
      begin
        if (LIndex >= Length(LCandidate.Notes)) or
          not SameNote(FPlan.Notes[LIndex], LCandidate.Notes[LIndex]) then Exit(derCommittedNote);
        Inc(LIndex);
      end;
      if (LIndex < Length(LCandidate.Notes)) and (LCandidate.Notes[LIndex].StartFrame < LPivotFrame) then
        Exit(derCommittedNote);
    end;
    LTones := nil;
    for LIndex := 0 to High(LCandidate.Notes) do
      if LCandidate.Notes[LIndex].StartFrame >= LPivotFrame then
      begin
        with LCandidate.Notes[LIndex] do
          LPlanned := FInstruments[Role].PlanNote(Pitch, Velocity, StartFrame, GateFrames,
            Cardinal(1 + AttackSpan * 8 + Role));
        LOut := Length(LTones);
        SetLength(LTones, LOut + Length(LPlanned));
        for LTone := 0 to High(LPlanned) do LTones[LOut + LTone] := LPlanned[LTone];
      end;
    LSchedule := FSynth.TryReplaceFuture(0, LPivotFrame, FOptions.OutputBus, LTones, LId);
    case LSchedule of
      srVoiceLimit: Exit(derVoiceLimit);
      srWorkLimit: Exit(derWorkLimit);
    end;
    LOld := FPlan;
    FPlan := LCandidate;
    LCandidate := nil;
    Inc(FRevision);
    LOld.Free;
    Result := derAccepted;
  finally
    LCandidate.Free;
  end;
end;

function TDurationStream.CopySpans: TTimedPitchSpans;
begin
  Result := nil;
  if FPlan <> nil then Result := Copy(FPlan.Spans);
end;

function TDurationStream.CopyNotes: TDurationNotes;
begin
  Result := nil;
  if FPlan <> nil then Result := Copy(FPlan.Notes);
end;

function TDurationStream.CopySequence(const AProvider: TDurationProvider): TWfcGeneratedSequenceSegment;
begin
  Result := Default(TWfcGeneratedSequenceSegment);
  if FPlan <> nil then Result := CloneSequence(FPlan.Sequences[AProvider]);
end;

function TDurationStream.CopyMusic(const AModelIndex: Integer): TWfcGeneratedSequenceSegment;
begin
  if (AModelIndex < 0) or (AModelIndex >= WfcMusicVoicesModelCount(FConfig)) then
    raise EAudio.Create('Duration musical provider index is invalid');
  Result := Default(TWfcGeneratedSequenceSegment);
  if FPlan <> nil then Result := CloneSequence(FPlan.Music[AModelIndex]);
end;

function TDurationStream.ModelText(const AProvider: TDurationProvider): String;
begin
  Result := EncodeWfcSequenceText(FModels[AProvider]);
end;

function TDurationStream.MusicModelText(const AModelIndex: Integer): String;
begin
  Result := EncodeWfcSequenceText(WfcMusicVoicesModelAt(FConfig, AModelIndex));
end;

function TDurationStream.RoleModelIndex(const AName: String): Integer;
var LIndex: Integer;
begin
  for LIndex := 0 to High(FNames) do
    if FNames[LIndex] = AName then Exit(LIndex + 2);
  raise EAudio.Create('Unknown duration role identity');
end;

function TDurationStream.GetNextFrame: Int64;
begin
  Result := FSynth.NextFrame;
end;

function TDurationStream.GetFailed: Boolean;
begin
  Result := FSynth.Failed;
end;

procedure TDurationStream.Process(out ALeft, ARight: Double);
begin
  FSynth.Process(ALeft, ARight);
end;

end.
