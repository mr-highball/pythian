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
unit pythian.wfc.instrumental.stream;

{$mode delphi}
{$H+}

interface

uses pythian.audio, pythian.time, pythian.progress, pythian.bus, pythian.chord,
  pythian.music.decisions,
  pythian.percussion, pythian.music.stream, pythian.wfc.instrumental,
  pythian.wfc.percussion, pythian.wfc.stream, wfc, wfc_model, wfc_sequence,
  wfc_sequence_graph, wfc_music_ensemble, wfc_music_voices_graph,
  wfc_music_voices_stream;

const
  InstrumentalStreamVersion = 2;

type
  TInstrumentalTokenStreams = array of TWfcModelTokens;
  TInstrumentalContextBinding = (icbDrivenRole, icbAllRoles);
  TInstrumentalStreamOptions = record
    MusicFrames: Int64;
    TailFrames: Int64;
    TicksPerQuarter: Integer;
    StepTicks: Integer;
    TempoMicroseconds: Integer;
    SegmentCells: Integer;
    Seed: TGraphSeed;
    MaxBacktracks: Integer;
    MaxPassBacktracks: Integer;
    VoiceLimit: Integer;
    WorkLimit: Integer;
    ContextBinding: TInstrumentalContextBinding;
  end;

  { Big Boss: one bounded musical lookahead, exact provider frontiers and one
    persistent primary instrument/scheduler/bus stream. Borrows immutable source
    models, pitched instruments and the exclusively processed matching bus graph.
    Owns percussion recipes. Context selects H/R and either its declared driven
    role or all roles explicitly. All-role binding keeps the joint provider's
    musical choices together across short/unaligned planning windows;
    named voices solve their existing joint graph, then independent drum streams
    are constrained by its actual rhythm. No source PCM is performed.

    Plan failures/cancellation are terminal: returned PCM remains identified by
    Position, but unpublished future provider cursors are not resumed. Solves
    check cancellation at bounded planning boundaries; sequence work/rendering
    also forward interior callbacks. Generic voice-stream Next is synchronous.
    Seed, model order, segmentation, tempo and sound recipes define replay.
    Planning windows do not claim learned musical form or infinite solvability. }
  TInstrumentalMusicStream = class
  private
    FOptions: TInstrumentalStreamOptions;
    FConfig: TWfcMusicVoicesGraphConfig;
    FVoices: TWfcMusicVoicesStream;
    FContext: TLearnedSequenceStream;
    FDrumStreams: array of TLearnedSequenceStream;
    FDrums: array of TPercussionInstrument;
    FDefinitions: TPercussionDefinitions;
    FMusic: TInstrumentMusicStream;
    FClock: TIncrementalTempoClock;
    FFrames: TWfcMusicEnsembleFrames;
    FDecisions: TMusicDecisionChunk;
    FPreviousDecision: TChordFrame;
    FRoleNames: TMusicDecisionTokens;
    FDecisionSink: TMusicDecisionSink;
    FCell: Integer;
    FCells: Int64;
    FTotalCells: Int64;
    FSegments: Int64;
    FPercussionHits: Int64;
    FBusy: Boolean;
    FFailed: Boolean;
    procedure RequireIdle;
    procedure PlanSegment(const AProgress: TWorkProgressCallback);
    procedure AdmitCell(const AProgress: TWorkProgressCallback);
    function DrumConstraints(const APart: Integer;
      const ARhythm: TWfcModelTokens): TWfcSequenceTokenConstraints;
    function GetPosition: Int64;
    function GetFrameCount: Int64;
    function GetState: TInstrumentStreamState;
    function GetPeakVoices: Integer;
    function GetPlannedCells: Int64;
  public
    constructor Create(const AConfig: TWfcMusicVoicesGraphConfig;
      const ARoles: TInstrumentalRoles; const APercussion: TPercussionDefinitions;
      const AGraph: TBusGraph; const AOptions: TInstrumentalStreamOptions;
      const AContext: TWfcSequenceModel = nil;
      const ADecisionSink: TMusicDecisionSink = nil);
    destructor Destroy; override;
    function ReadSamples(const AMaximumFrames: Integer; out ASamples: TAudioSamples;
      const AProgress: TWorkProgressCallback = nil): Boolean;
    function ReadOutputs(const AMaximumFrames: Integer; const AOutputBuses: array of Integer;
      out ASamples: TAudioSamples; out AOutputs: TBusSampleBlocks;
      const AProgress: TWorkProgressCallback = nil): Boolean;
    procedure Pause;
    procedure Resume;
    procedure Stop;
    { Sparse constraints apply only beyond the already planned lookahead.
      Indices: harmony0, rhythm1, then ordered pitched roles. }
    procedure IntersectFutureTokens(const AProvider: Integer; const ACell: Int64;
      const ATokens: TWfcModelTokens);
    function CopyLastFrames: TWfcMusicEnsembleFrames;
    function CopyLastDecisions: TMusicDecisionChunk;
    property Position: Int64 read GetPosition;
    property FrameCount: Int64 read GetFrameCount;
    property State: TInstrumentStreamState read GetState;
    property PlannedCells: Int64 read GetPlannedCells;
    property TotalCells: Int64 read FTotalCells;
    property PlannedSegments: Int64 read FSegments;
    property PeakVoices: Integer read GetPeakVoices;
    property PercussionHits: Int64 read FPercussionHits;
  end;

function DefaultInstrumentalStreamOptions(const AMusicFrames: Int64): TInstrumentalStreamOptions;

implementation

uses SysUtils, Math, pythian.synth, pythian.wfc.music,
  pythian.wfc.voices, pythian.wfc.layers, pythian.wfc.musical.context,
  wfc_music_arrangement;

function DefaultInstrumentalStreamOptions(const AMusicFrames: Int64): TInstrumentalStreamOptions;
begin
  Result := Default(TInstrumentalStreamOptions);
  Result.MusicFrames := AMusicFrames;
  Result.TicksPerQuarter := 480;
  Result.StepTicks := 240;
  Result.TempoMicroseconds := 500000;
  Result.SegmentCells := 16;
  Result.Seed := 731;
  Result.MaxBacktracks := 256;
  Result.MaxPassBacktracks := 16;
  Result.VoiceLimit := 128;
  Result.WorkLimit := 1000000;
  Result.ContextBinding := icbAllRoles;
end;

constructor TInstrumentalMusicStream.Create(const AConfig: TWfcMusicVoicesGraphConfig;
  const ARoles: TInstrumentalRoles; const APercussion: TPercussionDefinitions;
  const AGraph: TBusGraph; const AOptions: TInstrumentalStreamOptions;
  const AContext: TWfcSequenceModel; const ADecisionSink: TMusicDecisionSink);
var
  LBindings: TInstrumentStreamBindings;
  LOptions: TInstrumentStreamOptions;
  LStreamConfig: TWfcMusicVoicesStreamConfig;
  LMap: TTempoMap;
  LTicks, LMaximumTicks: Integer;
  LIndex, J: Integer;
  LStates: Int64;
begin
  inherited Create;
  if (AGraph = nil) or (Length(ARoles) < 1) or (Length(ARoles) > 6) or
    (Length(ARoles) <> Length(AConfig.Voices)) or (Length(APercussion) > 6) or
    (AOptions.SegmentCells < 1) or (AOptions.SegmentCells > 256) or
    (AOptions.StepTicks < 1) or (AOptions.MaxBacktracks < 0) or
    (AOptions.MaxBacktracks > 65536) or (AOptions.MaxPassBacktracks < 0) or
    (AOptions.MaxPassBacktracks > 1024) or
    not (AOptions.ContextBinding in [icbDrivenRole, icbAllRoles]) then
    raise EAudio.Create('Instrumental stream needs ordered roles, bounded lookahead and search');
  FOptions := AOptions;
  FDecisionSink := ADecisionSink;
  SetLength(FRoleNames, Length(ARoles));
  for LIndex := 0 to High(ARoles) do FRoleNames[LIndex] := ARoles[LIndex].Name;
  SetLength(FPreviousDecision, Length(ARoles) + Length(APercussion));
  for LIndex := 0 to High(FPreviousDecision) do
    FPreviousDecision[LIndex] := Default(TChordVoice);
  FConfig := CopyWfcMusicVoicesGraphConfig(AConfig);
  FClock := TIncrementalTempoClock.Create(AOptions.TicksPerQuarter, AGraph.SampleRate);
  if FClock.Advance(AOptions.StepTicks, AOptions.TempoMicroseconds) < 1 then
    raise EAudio.Create('Musical stream cells must span at least one sample frame');
  FClock.Reset;
  LMap := nil;
  try
    { Bracket only the requested clock span. A map extending to High(Integer)
      ticks can overflow exact frame arithmetic for otherwise valid short plans. }
    LMaximumTicks := (High(Integer) div AOptions.StepTicks) * AOptions.StepTicks;
    LTicks := AOptions.StepTicks;
    while True do
    begin
      FreeAndNil(LMap);
      LMap := TTempoMap.Create(AOptions.TicksPerQuarter, LTicks,
        [MakeTempoChange(0, AOptions.TempoMicroseconds)]);
      if LMap.FrameAtTick(LTicks, AGraph.SampleRate) >= AOptions.MusicFrames then Break;
      if LTicks = LMaximumTicks then
        raise EAudio.Create('Requested music exceeds the supported tick extent');
      LTicks := Min(Int64(LMaximumTicks), Int64(LTicks) * 2);
    end;
    LTicks := LMap.NextGridTick(AOptions.MusicFrames, AGraph.SampleRate, AOptions.StepTicks);
    FTotalCells := LTicks div AOptions.StepTicks;
  finally
    LMap.Free;
  end;
  LStates := 0;
  for LIndex := 0 to WfcMusicVoicesModelCount(FConfig) - 1 do
    Inc(LStates, WfcMusicVoicesModelAt(FConfig, LIndex).StateCount);
  if AContext <> nil then Inc(LStates, AContext.StateCount);
  for LIndex := 0 to High(APercussion) do
  begin
    if APercussion[LIndex].Model = nil then raise EAudio.Create('Drum stream needs a model');
    Inc(LStates, APercussion[LIndex].Model.StateCount);
  end;
  if LStates * AOptions.SegmentCells > MaximumLayerStateCells then
    raise EAudio.Create('Instrumental lookahead exceeds its explicit state-cell budget');
  LStreamConfig := DefaultWfcMusicVoicesStreamConfig(FConfig, AOptions.StepTicks,
    LTicks, AOptions.Seed);
  LStreamConfig.SegmentCellCount := AOptions.SegmentCells;
  LStreamConfig.Search.SolveOptions.MaxBacktracks := AOptions.MaxBacktracks;
  LStreamConfig.Search.MaxPassBacktracks := AOptions.MaxPassBacktracks;
  FVoices := TWfcMusicVoicesStream.Create(LStreamConfig);
  if AContext <> nil then FContext := TLearnedSequenceStream.Create(AContext);
  FDefinitions := Copy(APercussion);
  SetLength(FDrumStreams, Length(APercussion));
  SetLength(FDrums, Length(APercussion));
  LBindings := nil;
  SetLength(LBindings, Length(ARoles) + Length(APercussion));
  for LIndex := 0 to High(ARoles) do
  begin
    if ARoles[LIndex].IsPercussion then raise EAudio.Create('Pitched role cannot use drum binding');
    LBindings[LIndex].Instrument := ARoles[LIndex].Instrument;
    LBindings[LIndex].Bus := ARoles[LIndex].OutputBus;
    LBindings[LIndex].MaximumTones := 128;
  end;
  for LIndex := 0 to High(APercussion) do
  begin
    if (Trim(APercussion[LIndex].Origin) = '') or
      (APercussion[LIndex].HitWeight < 1) or
      (APercussion[LIndex].HitWeight > MaximumLayerPreferenceMultiplier) then
      raise EAudio.Create('Drum stream requires origin and hit weight1..1024');
    FDefinitions[LIndex].AllowedHitRhythms := Copy(APercussion[LIndex].AllowedHitRhythms);
    FDefinitions[LIndex].Constraints := Copy(APercussion[LIndex].Constraints);
    for J := 0 to High(FDefinitions[LIndex].Constraints) do
      FDefinitions[LIndex].Constraints[J].AllowedTokens :=
        Copy(APercussion[LIndex].Constraints[J].AllowedTokens);
    ValidateSequenceTokenConstraints(APercussion[LIndex].Model,
      FTotalCells, APercussion[LIndex].Constraints);
    FDrumStreams[LIndex] := TLearnedSequenceStream.Create(APercussion[LIndex].Model);
    FDrums[LIndex] := TPercussionInstrument.Create(AGraph.SampleRate, APercussion[LIndex].Settings);
    LBindings[Length(ARoles) + LIndex].Instrument := FDrums[LIndex].Instrument;
    LBindings[Length(ARoles) + LIndex].Bus := APercussion[LIndex].OutputBus;
    LBindings[Length(ARoles) + LIndex].MaximumTones := 1;
    LBindings[Length(ARoles) + LIndex].GateFrames :=
      SampleFramesFromSeconds(APercussion[LIndex].Settings.GateSeconds, AGraph.SampleRate);
  end;
  LOptions := DefaultInstrumentStreamOptions(AOptions.MusicFrames);
  LOptions.TailFrames := AOptions.TailFrames;
  LOptions.Seed := AOptions.Seed;
  LOptions.VoiceLimit := AOptions.VoiceLimit;
  LOptions.WorkLimit := AOptions.WorkLimit;
  FMusic := TInstrumentMusicStream.Create(LBindings, AGraph, LOptions);
end;

destructor TInstrumentalMusicStream.Destroy;
var
  I: Integer;
begin
  FMusic.Free;
  FVoices.Free;
  FContext.Free;
  for I := 0 to High(FDrumStreams) do FDrumStreams[I].Free;
  for I := 0 to High(FDrums) do FDrums[I].Free;
  FClock.Free;
  inherited Destroy;
end;

procedure TInstrumentalMusicStream.RequireIdle;
begin
  if FBusy then raise EAudio.Create('Instrumental stream calls cannot reenter');
end;

function TInstrumentalMusicStream.DrumConstraints(const APart: Integer;
  const ARhythm: TWfcModelTokens): TWfcSequenceTokenConstraints;
var
  LCell, LToken, LCount, LMask: Integer;
  LAllowedRhythms, LTokens: TWfcModelTokens;
  LTokenText, LR: String;
  LAllowed, LLock: Boolean;
begin
  Result := nil;
  SetLength(Result, Length(ARhythm));
  for LCell := 0 to High(ARhythm) do
  begin
    LTokens := nil;
    for LToken := 0 to FDefinitions[APart].Model.PublicTokenCount - 1 do
    begin
      LTokenText := FDefinitions[APart].Model.PublicTokenAt(LToken);
      LAllowed := FDefinitions[APart].Enabled or (PercussionVelocity(LTokenText) = 0);
      LAllowedRhythms := AllowedPercussionRhythms(FConfig.RhythmModel,
        FDefinitions[APart], LTokenText);
      LLock := False;
      for LR in LAllowedRhythms do LLock := LLock or (LR = ARhythm[LCell]);
      LAllowed := LAllowed and LLock;
      for LMask := 0 to High(FDefinitions[APart].Constraints) do
        if FDefinitions[APart].Constraints[LMask].Position = FCells + LCell then
        begin
          LLock := False;
          for LR in FDefinitions[APart].Constraints[LMask].AllowedTokens do
            LLock := LLock or (LR = LTokenText);
          LAllowed := LAllowed and LLock;
        end;
      if LAllowed then
      begin
        LCount := Length(LTokens);
        SetLength(LTokens, LCount + 1);
        LTokens[LCount] := LTokenText;
      end;
    end;
    Result[LCell] := MakeWfcSequenceTokenConstraint(LCell, LTokens);
  end;
end;

procedure TInstrumentalMusicStream.PlanSegment(const AProgress: TWorkProgressCallback);
var
  LChunk: TWfcGeneratedSequenceSegment;
  LOptions: TSequenceChunkOptions;
  LReport: TGraphSolveReport;
  LVoiceReport: TGraphNegotiationReport;
  LSegment: TWfcMusicVoicesSegment;
  LMasks: TVoiceMasks;
  LMask: TWfcSequenceTokenConstraint;
  LProvider, I, LToken, LWeight: Integer;
  LName: String;
  LExpected: String;
  LFrames: TWfcMusicEnsembleFrames;
  LRhythm, LContextTokens: TWfcModelTokens;
  LDrumTokens: TInstrumentalTokenStreams;
  LDecisions, LSinkCopy: TMusicDecisionChunk;
  LClock: TIncrementalTempoClock;
  LFrame: TChordFrame;
  LCell, LAt, LVelocity: Integer;
  LFrameCount, LFrameAt: Int64;
  procedure KeepProvider(const AKey: String; const AGenerated: TWfcGeneratedSequenceSegment);
  var LAt, LCell: Integer;
  begin
    LAt := Length(LDecisions.Providers);
    SetLength(LDecisions.Providers, LAt + 1);
    LDecisions.Providers[LAt].Key := AKey;
    SetLength(LDecisions.Providers[LAt].Tokens, Length(AGenerated.Tokens));
    SetLength(LDecisions.Providers[LAt].States, Length(AGenerated.StateIndices));
    for LCell := 0 to High(AGenerated.Tokens) do
      LDecisions.Providers[LAt].Tokens[LCell] := AGenerated.Tokens[LCell];
    for LCell := 0 to High(AGenerated.StateIndices) do
      LDecisions.Providers[LAt].States[LCell] := AGenerated.StateIndices[LCell];
  end;
begin
  LDecisions := Default(TMusicDecisionChunk);
  LDecisions.Version := MusicDecisionVersion;
  LDecisions.FirstCell := FCells;
  LDecisions.StartFrame := FMusic.AdmittedFrames;
  LDecisions.Previous := CopyChordFrame(FPreviousDecision);
  LOptions := DefaultSequenceChunkOptions;
  LOptions.CellCount := Min(Int64(FOptions.SegmentCells), FTotalCells - FCells);
  { Big Boss: a bounded segment must leave a viable structural exit for the
    requested remainder. Finite capacity is below the model's state count, so
    capping this threshold at High(Integer) preserves the long-clock decision. }
  LOptions.MinimumFollowingCells := Min(Int64(High(Integer)),
    FTotalCells - FCells - LOptions.CellCount);
  LOptions.MaxBacktracks := FOptions.MaxBacktracks;
  LOptions.Seed := WfcMusicArrangementSectionSeed(FOptions.Seed, FSegments);
  ReportWork(AProgress, 'instrumental_stream_plan', wuItems, FCells, FTotalCells);
  LContextTokens := nil;
  if FContext <> nil then
  begin
    if not FContext.TryNext(LOptions, [], LChunk, LReport, AProgress) then
      raise EAudio.Create('Learned context cannot plan step ' + IntToStr(FCells) +
        ' (solver status ' + IntToStr(Ord(LReport.Status)) + ', following cells ' +
        IntToStr(LOptions.MinimumFollowingCells) +
        '). Try a shorter track or a broader selection.');
    LContextTokens := LChunk.Tokens;
    KeepProvider(MusicalContextPassName, LChunk);
    LMasks := BindMusicalContextTokens(LContextTokens, Length(FConfig.Voices), nil,
      FOptions.ContextBinding = icbAllRoles);
    for LProvider := 0 to High(LMasks) do
      for LMask in LMasks[LProvider] do
        FVoices.IntersectAllowedTokens(LProvider, FCells + LMask.Position, LMask.AllowedTokens);
  end;
  LSegment := nil;
  LExpected := '';
  if (FContext <> nil) and (Length(LMasks[0]) > 0) then
    LExpected := '; next context harmony=' + LMasks[0][0].AllowedTokens[0];
  try
    if FVoices.Next(LSegment, LVoiceReport) <> wmaspProduced then
      raise EAudio.Create('Musical frontier cannot continue at cell ' + IntToStr(FCells) +
        ', negotiation ' + IntToStr(Ord(LVoiceReport.Status)) + ', pass ' +
        IntToStr(LVoiceReport.FinalReport.FailedPassIndex) + ': ' + FVoices.Failure +
        '; previous harmony=' + FVoices.CopyFrontier.Tokens[0] + LExpected);
    LFrames := LSegment.CopyFrames;
    LRhythm := LSegment.CopyGenerated(1).Tokens;
    KeepProvider('harmony', LSegment.CopyGenerated(0));
    KeepProvider('rhythm', LSegment.CopyGenerated(1));
    for I := 0 to High(FRoleNames) do
      KeepProvider(FRoleNames[I], LSegment.CopyGenerated(I + 2));
  finally
    LSegment.Free;
  end;
  ReportWork(AProgress, 'instrumental_stream_voices', wuItems, FCells, FTotalCells);
  LDrumTokens := nil;
  SetLength(LDrumTokens, Length(FDrumStreams));
  for I := 0 to High(FDrumStreams) do
  begin
    LOptions.Preferences := nil;
    SetLength(LOptions.Preferences, FDefinitions[I].Model.PublicTokenCount);
    for LToken := 0 to High(LOptions.Preferences) do
    begin
      LName := FDefinitions[I].Model.PublicTokenAt(LToken);
      LWeight := 1;
      if PercussionVelocity(LName) > 0 then LWeight := FDefinitions[I].HitWeight;
      LOptions.Preferences[LToken] := MakeLayerTokenPreference(LName, LWeight);
    end;
    LOptions.Seed := WfcMusicArrangementSectionSeed(FOptions.Seed xor Cardinal(I + 1741), FSegments);
    if not FDrumStreams[I].TryNext(LOptions, DrumConstraints(I, LRhythm), LChunk,
      LReport, AProgress) then
      raise EAudio.Create('Drum frontier cannot continue: ' + FDefinitions[I].Name);
    LDrumTokens[I] := LChunk.Tokens;
    KeepProvider(FDefinitions[I].Name, LChunk);
  end;
  { Retain the exact performed cell clock, including fractional tempo carry and
    the clipped last cell. This uses the same primary frame projection and clock;
    AdmitCell below consumes this candidate instead of projecting a second copy. }
  SetLength(LDecisions.Cells, Length(LFrames));
  LFrameAt := LDecisions.StartFrame;
  LClock := TIncrementalTempoClock.Create(FOptions.TicksPerQuarter, FMusic.SampleRate);
  try
    LClock.Restore(FClock.Snapshot);
    for LCell := 0 to High(LFrames) do
    begin
      LFrame := ProjectWfcChordFrame(LFrames[LCell]);
      LAt := Length(LFrame);
      SetLength(LFrame, LAt + Length(FDrums));
      for I := 0 to High(FDrums) do
      begin
        LFrame[LAt + I] := Default(TChordVoice);
        LVelocity := PercussionVelocity(LDrumTokens[I][LCell]);
        if LVelocity = 0 then Continue;
        LFrame[LAt + I].Action := caAttack;
        SetLength(LFrame[LAt + I].Tones, 1);
        LFrame[LAt + I].Tones[0].Pitch := PercussionKey(FDefinitions[I].Settings.Kind);
        LFrame[LAt + I].Tones[0].Velocity := LVelocity;
      end;
      LFrameCount := LClock.Advance(FOptions.StepTicks, FOptions.TempoMicroseconds);
      LFrameCount := Min(LFrameCount, FOptions.MusicFrames - LFrameAt);
      LDecisions.Cells[LCell].FrameCount := LFrameCount;
      LDecisions.Cells[LCell].Parts := LFrame;
      Inc(LFrameAt, LFrameCount);
    end;
  finally
    LClock.Free;
  end;
  ValidateMusicDecisionChunk(LDecisions, AProgress);
  ReportWork(AProgress, 'instrumental_stream_ready', wuItems,
    FCells + Length(LFrames), FTotalCells);
  if Assigned(FDecisionSink) then
  begin
    LSinkCopy := CopyMusicDecisionChunk(LDecisions);
    FDecisionSink(LSinkCopy);
  end;
  FFrames := LFrames;
  FDecisions := LDecisions;
  FCell := 0;
  Inc(FSegments);
end;

procedure TInstrumentalMusicStream.AdmitCell(const AProgress: TWorkProgressCallback);
var
  LFrame: TChordFrame;
  I, LHits: Integer;
  LFrames: Int64;
begin
  if FCell = Length(FFrames) then PlanSegment(AProgress);
  LFrame := FDecisions.Cells[FCell].Parts;
  LHits := 0;
  for I := 0 to High(FDrums) do
  begin
    if LFrame[Length(FRoleNames) + I].Action = caAttack then Inc(LHits);
  end;
  LFrames := FClock.Advance(FOptions.StepTicks, FOptions.TempoMicroseconds);
  LFrames := Min(LFrames, FOptions.MusicFrames - FMusic.AdmittedFrames);
  if LFrames <> FDecisions.Cells[FCell].FrameCount then
    raise EAudio.Create('Decision capture differs from the performed clock');
  FMusic.AdmitFrame(LFrame, LFrames, AProgress);
  FPreviousDecision := CopyChordFrame(LFrame);
  Inc(FPercussionHits, LHits);
  Inc(FCell);
  Inc(FCells);
end;

function TInstrumentalMusicStream.ReadSamples(const AMaximumFrames: Integer;
  out ASamples: TAudioSamples; const AProgress: TWorkProgressCallback): Boolean;
var
  LOutputs: TBusSampleBlocks;
begin
  Result := ReadOutputs(AMaximumFrames, [], ASamples, LOutputs, AProgress);
end;

function TInstrumentalMusicStream.ReadOutputs(const AMaximumFrames: Integer;
  const AOutputBuses: array of Integer; out ASamples: TAudioSamples;
  out AOutputs: TBusSampleBlocks; const AProgress: TWorkProgressCallback): Boolean;
begin
  RequireIdle;
  ASamples := nil;
  AOutputs := nil;
  FMusic.ValidatePull(AMaximumFrames, AOutputBuses);
  if FFailed then raise EAudio.Create('Instrumental stream failed; start a new replay');
  if State <> issReady then Exit(False);
  FBusy := True;
  try
    try
      if FMusic.NeedsInput then AdmitCell(AProgress);
      Result := FMusic.ReadOutputs(AMaximumFrames, AOutputBuses, ASamples, AOutputs, AProgress);
    except
      FFailed := True;
      ASamples := nil;
      AOutputs := nil;
      raise;
    end;
  finally
    FBusy := False;
  end;
end;

function TInstrumentalMusicStream.GetPosition: Int64;
begin
  Result := FMusic.Position;
end;

function TInstrumentalMusicStream.GetFrameCount: Int64;
begin
  Result := FMusic.FrameCount;
end;

function TInstrumentalMusicStream.GetState: TInstrumentStreamState;
begin
  if FFailed then Result := issFailed else Result := FMusic.State;
end;

function TInstrumentalMusicStream.GetPeakVoices: Integer;
begin
  Result := FMusic.PeakVoices;
end;

function TInstrumentalMusicStream.GetPlannedCells: Int64;
begin
  Result := FCells + Length(FFrames) - FCell;
end;

procedure TInstrumentalMusicStream.Pause;
begin
  RequireIdle;
  FMusic.Pause;
end;

procedure TInstrumentalMusicStream.Resume;
begin
  RequireIdle;
  FMusic.Resume;
end;

procedure TInstrumentalMusicStream.Stop;
begin
  RequireIdle;
  FVoices.Cancel;
  FMusic.Stop;
end;

procedure TInstrumentalMusicStream.IntersectFutureTokens(const AProvider: Integer;
  const ACell: Int64; const ATokens: TWfcModelTokens);
begin
  RequireIdle;
  if State <> issReady then raise EAudio.Create('Only ready musical streams accept future edits');
  FVoices.IntersectAllowedTokens(AProvider, ACell, ATokens);
end;

function TInstrumentalMusicStream.CopyLastFrames: TWfcMusicEnsembleFrames;
var
  I: Integer;
begin
  Result := Copy(FFrames);
  for I := 0 to High(Result) do
    Result[I] := DecodeWfcMusicEnsembleFrame(EncodeWfcMusicEnsembleFrame(FFrames[I]));
end;

function TInstrumentalMusicStream.CopyLastDecisions: TMusicDecisionChunk;
begin
  Result := CopyMusicDecisionChunk(FDecisions);
end;

end.
