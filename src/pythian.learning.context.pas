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

unit pythian.learning.context;

{$mode delphi}
{$H+}

interface

uses
  pythian.audio, pythian.analysis.journal, pythian.learning,
  pythian.learning.journal, pythian.learning.selection;

const
  MaximumJournalContexts = 2048;
  MaximumJournalContextGrains = 32;
  MaximumJournalContextWindows = 65536;

type
  TJournalContextWindow = record
    Token: Integer;
    Candidate: TJournalRepresentative;
  end;
  TJournalContextWindows = array of TJournalContextWindow;
  TJournalContextSets = array of TJournalContextWindows;
  TJournalContextLocks = array of Boolean;
  TJournalContextSource = record
    Binding: TFeatureJournalBinding;
    FirstFeature: Int64;
    FeatureCount: Int64;
  end;
  TJournalContextSources = array of TJournalContextSource;
  TJournalContextOptions = record
    { Caps one selected context chunk. Adjacent chunks or repairs may form a
      longer source-contiguous run in the final path. }
    MaximumRunGrains: Integer;
    { Zero leaves usage unrestricted; otherwise cap starts at each context.
      Overlapping contexts and fallback/repair can reuse the same source window;
      this is not a final per-window or repeated-pattern ceiling. }
    MaximumContextUses: Integer;
    Seed: Integer;
  end;
  TJournalContextReport = record
    ContextRuns: Integer;
    ContextGrains: Integer;
    FallbackGrains: Integer;
    ContiguousLinks: Integer;
    RepeatedWindows: Integer;
    RepairEdits: Integer;
    Reverted: Boolean;
    WorkBound: Int64;
  end;

  { Owns detached source bindings, fallback coordinates and forward source context
    around each populated fallback candidate. Borrows reader/palette/pool only
    during construction. One sequential journal pass; storage is bounded.
    Context never crosses a declared segment or invents observations at EOF.
    This is acoustic source context, not inferred musical phrase boundaries. }
  TJournalContextPool = class
  private
    FContexts: TJournalContextSets;
    FSources: TJournalContextSources;
    FFallback: TJournalCandidatePool;
    FVocabulary: String;
    FTokenCount: Integer;
    FWindowCount: Integer;
    FHop: Integer;
    function GetCount: Integer;
    function GetSourceCount: Integer;
  public
    constructor Create(const AReader: TJournalTrainingReader;
      const APalette: TAcousticPalette; const AFallback: TJournalCandidatePool;
      const AMaximumGrains: Integer = 8);
    { Restores detached, structurally checked contexts without journal reads.
      Source extent, grid, palette/timebase and fallback bindings are validated;
      serialized measurements still require host provenance verification. }
    constructor CreateFromContexts(const APalette: TAcousticPalette;
      const AFallback: TJournalCandidatePool; const ASources: TJournalContextSources;
      const AContexts: TJournalContextSets);
    destructor Destroy; override;
    function SourceAt(const AIndex: Integer): TJournalContextSource;
    function ContextLength(const AIndex: Integer): Integer;
    function WindowAt(const AContext, AOffset: Integer): TJournalContextWindow;
    { Starts with feasible fallback slots. Preserves every token, exact
      per-token/source counts and locked coordinates. Greedy variable-length
      contexts use remaining source quotas; unsupported positions use fallback.
      Seed breaks equal-length/equal-usage ties. No whole-recording allocation.
      Bounded same-token/source substitutions and equal-token position swaps
      repair boundary repeats when both edited neighborhoods remain repeat-free.
      If repeats still exceed the
      initial ceiling, returns the
      complete original selection and reports Reverted, never partial changes.
      No optimality, perceptual quality or quota-feasible longest-path claim. }
    function Plan(const AInitial: TAcousticIndices; const ALocked: TJournalContextLocks;
      const AOptions: TJournalContextOptions;
      out AReport: TJournalContextReport): TJournalContextWindows;
    property Count: Integer read GetCount;
    property SourceCount: Integer read GetSourceCount;
    property WindowCount: Integer read FWindowCount;
    property VocabularySha256: String read FVocabulary;
    property Fallback: TJournalCandidatePool read FFallback;
  end;

function DefaultJournalContextOptions: TJournalContextOptions;
{ Reads each distinct source coordinate at most once. Preserves actual EOF padding
  and the standard Hann overlap-add clock. Returned clip is caller-owned. }
function RenderJournalContexts(const ASelection: TJournalContextWindows;
  const AReadWindow: TJournalWindowRead; const ASampleRate, AChannels,
  AWindowFrames, AHopFrames: Integer): TAudioClip;

implementation

uses
  Math, pythian.learning.binding, pythian.granular;

function SameWindow(const ALeft, ARight: TJournalRepresentative): Boolean;
begin
  Result := (ALeft.SegmentIndex = ARight.SegmentIndex) and
    (ALeft.FeatureIndex = ARight.FeatureIndex) and
    (ALeft.SourceFrame = ARight.SourceFrame);
end;

function DefaultJournalContextOptions: TJournalContextOptions;
begin
  Result.MaximumRunGrains := 8;
  Result.MaximumContextUses := 0;
  Result.Seed := 731;
end;

constructor TJournalContextPool.Create(const AReader: TJournalTrainingReader;
  const APalette: TAcousticPalette; const AFallback: TJournalCandidatePool;
  const AMaximumGrains: Integer);
var
  LSlots: TJournalRepresentatives;
  LSegment: TJournalTrainingSegment;
  LCandidate: TJournalRepresentative;
  LObservation: TJournalTrainingObservation;
  LContext: TJournalContextWindows;
  LSlot: Integer;
  LIndex: Integer;
  LOther: Integer;
  LFirst: Integer;
  LNext: Integer;
  LOffset: Integer;
  LSeen: Integer;
  LToken: Integer;
  LDistance: Double;
begin
  inherited Create;
  if (AReader = nil) or (APalette = nil) or (AFallback = nil) or
    (AMaximumGrains < 1) or (AMaximumGrains > MaximumJournalContextGrains) then
  begin
    raise EAudio.Create('Context pool requires reader, palette, fallback and 1..32 grains');
  end;
  if AFallback.SegmentCount <> AReader.SegmentCount then
  begin
    raise EAudio.Create('Context and fallback source counts differ');
  end;
  FTokenCount := APalette.Count;
  SetLength(FSources, AReader.SegmentCount);
  for LIndex := 0 to High(FSources) do
  begin
    LSegment := AReader.SegmentAt(LIndex);
    FSources[LIndex].Binding := LSegment.Journal.Binding;
    FSources[LIndex].FirstFeature := LSegment.FirstFeature;
    FSources[LIndex].FeatureCount := LSegment.FeatureCount;
  end;
  FHop := FSources[0].Binding.Options.HopFrames;
  FVocabulary := AcousticVocabularySha256(APalette, FSources[0].Binding.Options,
    FSources[0].Binding.SampleRate, FSources[0].Binding.Channels);
  SetLength(LSlots, AFallback.SlotCount);
  for LSlot := 0 to AFallback.SlotCount - 1 do
  begin
    LCandidate := AFallback.CandidateAt(LSlot);
    LSlots[LSlot] := LCandidate;
    if not LCandidate.Found then
    begin
      Continue;
    end;
    LSegment := AReader.SegmentAt(LCandidate.SegmentIndex);
    if (LCandidate.FeatureIndex < LSegment.FirstFeature) or
      (LCandidate.FeatureIndex >= LSegment.FirstFeature + LSegment.FeatureCount) then
    begin
      raise EAudio.Create('Context anchor is outside its source range');
    end;
    if Length(FContexts) = MaximumJournalContexts then
    begin
      raise EAudio.Create('Context anchor budget exceeded');
    end;
    LIndex := Length(FContexts);
    SetLength(FContexts, LIndex + 1);
    SetLength(FContexts[LIndex], Min(Int64(AMaximumGrains),
      LSegment.FirstFeature + LSegment.FeatureCount - LCandidate.FeatureIndex));
    FContexts[LIndex][0].Candidate := LCandidate;
    FContexts[LIndex][0].Token := AFallback.TokenAt(LSlot);
    Inc(FWindowCount, Length(FContexts[LIndex]));
  end;
  FFallback := TJournalCandidatePool.CreateFromCandidates(APalette.Count,
    AReader.SegmentCount, AFallback.BinsPerSegment, LSlots);
  { At most 2048 anchors: bounded insertion sort, independent of recording length. }
  for LIndex := 1 to High(FContexts) do
  begin
    LContext := FContexts[LIndex];
    LOther := LIndex - 1;
    while LOther >= 0 do
    begin
      LCandidate := FContexts[LOther][0].Candidate;
      if (LCandidate.SegmentIndex < LContext[0].Candidate.SegmentIndex) or
        ((LCandidate.SegmentIndex = LContext[0].Candidate.SegmentIndex) and
        (LCandidate.FeatureIndex <= LContext[0].Candidate.FeatureIndex)) then
      begin
        Break;
      end;
      FContexts[LOther + 1] := FContexts[LOther];
      Dec(LOther);
    end;
    FContexts[LOther + 1] := LContext;
  end;
  for LIndex := 1 to High(FContexts) do
  begin
    if SameWindow(FContexts[LIndex - 1][0].Candidate, FContexts[LIndex][0].Candidate) then
    begin
      raise EAudio.Create('Context anchors must be distinct source observations');
    end;
  end;
  AReader.Rewind;
  LFirst := 0;
  LNext := 0;
  LSeen := 0;
  while AReader.ReadObservation(LObservation) do
  begin
    while LNext < Length(FContexts) do
    begin
      LCandidate := FContexts[LNext][0].Candidate;
      if (LCandidate.SegmentIndex > LObservation.SegmentIndex) or
        ((LCandidate.SegmentIndex = LObservation.SegmentIndex) and
        (LCandidate.FeatureIndex > LObservation.FeatureIndex)) then
      begin
        Break;
      end;
      Inc(LNext);
    end;
    while LFirst < LNext do
    begin
      LCandidate := FContexts[LFirst][0].Candidate;
      if (LCandidate.SegmentIndex = LObservation.SegmentIndex) and
        (LCandidate.FeatureIndex + Length(FContexts[LFirst]) > LObservation.FeatureIndex) then
      begin
        Break;
      end;
      Inc(LFirst);
    end;
    if LFirst = LNext then
    begin
      Continue;
    end;
    LToken := APalette.EncodeFeature(LObservation.Feature);
    LDistance := APalette.FeatureDistance(LObservation.Feature, LToken);
    for LIndex := LFirst to LNext - 1 do
    begin
      LOffset := LObservation.FeatureIndex - FContexts[LIndex][0].Candidate.FeatureIndex;
      if (LOffset < 0) or (LOffset >= Length(FContexts[LIndex])) then
      begin
        raise EAudio.Create('Context observation order differs from declared interval');
      end;
      if LOffset = 0 then
      begin
        LCandidate := FContexts[LIndex][0].Candidate;
        if (FContexts[LIndex][0].Token <> LToken) or
          (LCandidate.SourceFrame <> LObservation.SourceFrame) or
          (LCandidate.ValidFrames <> LObservation.Feature.ValidFrames) then
        begin
          raise EAudio.Create('Fallback anchor differs from its measured journal observation');
        end;
      end;
      LCandidate := Default(TJournalRepresentative);
      LCandidate.Found := True;
      LCandidate.SegmentIndex := LObservation.SegmentIndex;
      LCandidate.FeatureIndex := LObservation.FeatureIndex;
      LCandidate.SourceFrame := LObservation.SourceFrame;
      LCandidate.ValidFrames := LObservation.Feature.ValidFrames;
      LCandidate.Distance := LDistance;
      FContexts[LIndex][LOffset].Token := LToken;
      FContexts[LIndex][LOffset].Candidate := LCandidate;
      Inc(LSeen);
    end;
  end;
  if LSeen <> FWindowCount then
  begin
    raise EAudio.Create('Context journal ended without all declared windows');
  end;
end;

constructor TJournalContextPool.CreateFromContexts(const APalette: TAcousticPalette;
  const AFallback: TJournalCandidatePool; const ASources: TJournalContextSources;
  const AContexts: TJournalContextSets);
var
  LSlots: TJournalRepresentatives;
  LSource: TJournalContextSource;
  LContext: TJournalContextWindows;
  LIndex: Integer;
  LOther: Integer;
  LOffset: Integer;
  LTotal: Int64;

  procedure ValidateWindow(const AWindow: TJournalContextWindow);
  var
    LBinding: TJournalContextSource;
    LCandidate: TJournalRepresentative;
  begin
    LCandidate := AWindow.Candidate;
    if not LCandidate.Found or (AWindow.Token < 0) or (AWindow.Token >= FTokenCount) or
      (LCandidate.SegmentIndex < 0) or (LCandidate.SegmentIndex >= SourceCount) then
    begin
      raise EAudio.Create('Restored context token or source is invalid');
    end;
    LBinding := FSources[LCandidate.SegmentIndex];
    RequireFinite(LCandidate.Distance, 'Restored context center distance');
    if (LCandidate.Distance < 0) or (LCandidate.Distance > Length(TAcousticVector)) or
      (LCandidate.SourceFrame < 0) or (LCandidate.SourceFrame >= LBinding.Binding.FrameCount) or
      (LCandidate.SourceFrame mod FHop <> 0) or
      (LCandidate.FeatureIndex <> LCandidate.SourceFrame div FHop) or
      (LCandidate.FeatureIndex < LBinding.FirstFeature) or
      (LCandidate.FeatureIndex - LBinding.FirstFeature >= LBinding.FeatureCount) or
      (LCandidate.ValidFrames <> Min(Int64(LBinding.Binding.Options.WindowFrames),
        LBinding.Binding.FrameCount - LCandidate.SourceFrame)) then
    begin
      raise EAudio.Create('Restored context coordinate, extent or distance is inconsistent');
    end;
  end;

begin
  inherited Create;
  if (APalette = nil) or (AFallback = nil) or (Length(ASources) < 1) or
    (Length(ASources) <> AFallback.SegmentCount) or
    (Length(AContexts) < 1) or (Length(AContexts) > MaximumJournalContexts) then
  begin
    raise EAudio.Create('Restored context geometry is invalid');
  end;
  FTokenCount := APalette.Count;
  FSources := Copy(ASources);
  FHop := FSources[0].Binding.Options.HopFrames;
  FVocabulary := AcousticVocabularySha256(APalette, FSources[0].Binding.Options,
    FSources[0].Binding.SampleRate, FSources[0].Binding.Channels);
  for LIndex := 0 to High(FSources) do
  begin
    LSource := FSources[LIndex];
    if (AcousticVocabularySha256(APalette, LSource.Binding.Options,
      LSource.Binding.SampleRate, LSource.Binding.Channels) <> FVocabulary) or
      (Length(LSource.Binding.SourceSha256) <> 64) or (LSource.Binding.FrameCount < 1) then
    begin
      raise EAudio.Create('Restored context source/timebase binding differs');
    end;
    for LOffset := 1 to Length(LSource.Binding.SourceSha256) do
    begin
      if not (LSource.Binding.SourceSha256[LOffset] in ['0'..'9', 'a'..'f']) then
      begin
        raise EAudio.Create('Restored context source digest is invalid');
      end;
    end;
    LTotal := (LSource.Binding.FrameCount - 1) div FHop + 1;
    if (LSource.FirstFeature < 0) or (LSource.FirstFeature >= LTotal) or
      (LSource.FeatureCount < 1) or (LSource.FeatureCount > LTotal - LSource.FirstFeature) then
    begin
      raise EAudio.Create('Restored context source range is invalid');
    end;
    for LOther := 0 to LIndex - 1 do
    begin
      if (LSource.Binding.SourceSha256 = FSources[LOther].Binding.SourceSha256) and
        ((LSource.Binding.FrameCount <> FSources[LOther].Binding.FrameCount) or
        ((LSource.FirstFeature < FSources[LOther].FirstFeature + FSources[LOther].FeatureCount) and
        (FSources[LOther].FirstFeature < LSource.FirstFeature + LSource.FeatureCount))) then
      begin
        raise EAudio.Create('Restored context source ranges conflict or overlap');
      end;
    end;
  end;
  SetLength(LSlots, AFallback.SlotCount);
  for LIndex := 0 to High(LSlots) do
  begin
    LSlots[LIndex] := AFallback.CandidateAt(LIndex);
    if LSlots[LIndex].Found then
    begin
      SetLength(LContext, 1);
      LContext[0].Token := AFallback.TokenAt(LIndex);
      LContext[0].Candidate := LSlots[LIndex];
      ValidateWindow(LContext[0]);
    end;
  end;
  FFallback := TJournalCandidatePool.CreateFromCandidates(FTokenCount, SourceCount,
    AFallback.BinsPerSegment, LSlots);
  SetLength(FContexts, Length(AContexts));
  for LIndex := 0 to High(FContexts) do
  begin
    if (Length(AContexts[LIndex]) < 1) or
      (Length(AContexts[LIndex]) > MaximumJournalContextGrains) or
      (Length(AContexts[LIndex]) > MaximumJournalContextWindows - FWindowCount) then
    begin
      raise EAudio.Create('Restored context exceeds window budget');
    end;
    FContexts[LIndex] := Copy(AContexts[LIndex]);
    Inc(FWindowCount, Length(FContexts[LIndex]));
    for LOffset := 0 to High(FContexts[LIndex]) do
    begin
      ValidateWindow(FContexts[LIndex][LOffset]);
      if LOffset > 0 then
      begin
        if (FContexts[LIndex][LOffset].Candidate.SegmentIndex <>
          FContexts[LIndex][0].Candidate.SegmentIndex) or
          (FContexts[LIndex][LOffset].Candidate.FeatureIndex -
          FContexts[LIndex][LOffset - 1].Candidate.FeatureIndex <> 1) then
        begin
          raise EAudio.Create('Restored context crosses a source boundary or skips observations');
        end;
      end;
    end;
  end;
  { Canonical source/anchor order makes serialization and merging repeatable. }
  for LIndex := 1 to High(FContexts) do
  begin
    LContext := FContexts[LIndex];
    LOther := LIndex - 1;
    while LOther >= 0 do
    begin
      if (FContexts[LOther][0].Candidate.SegmentIndex < LContext[0].Candidate.SegmentIndex) or
        ((FContexts[LOther][0].Candidate.SegmentIndex = LContext[0].Candidate.SegmentIndex) and
        (FContexts[LOther][0].Candidate.FeatureIndex <= LContext[0].Candidate.FeatureIndex)) then
      begin
        Break;
      end;
      FContexts[LOther + 1] := FContexts[LOther];
      Dec(LOther);
    end;
    FContexts[LOther + 1] := LContext;
  end;
  for LIndex := 1 to High(FContexts) do
  begin
    if SameWindow(FContexts[LIndex - 1][0].Candidate, FContexts[LIndex][0].Candidate) then
    begin
      raise EAudio.Create('Restored context contains duplicate anchors');
    end;
  end;
end;

destructor TJournalContextPool.Destroy;
begin
  FFallback.Free;
  inherited Destroy;
end;

function TJournalContextPool.GetCount: Integer;
begin
  Result := Length(FContexts);
end;

function TJournalContextPool.GetSourceCount: Integer;
begin
  Result := Length(FSources);
end;

function TJournalContextPool.SourceAt(const AIndex: Integer): TJournalContextSource;
begin
  if (AIndex < 0) or (AIndex >= SourceCount) then
  begin
    raise EAudio.Create('Context source index out of bounds');
  end;
  Result := FSources[AIndex];
end;

function TJournalContextPool.ContextLength(const AIndex: Integer): Integer;
begin
  if (AIndex < 0) or (AIndex >= Count) then
  begin
    raise EAudio.Create('Context index out of bounds');
  end;
  Result := Length(FContexts[AIndex]);
end;

function TJournalContextPool.WindowAt(const AContext, AOffset: Integer): TJournalContextWindow;
begin
  if (AOffset < 0) or (AOffset >= ContextLength(AContext)) then
  begin
    raise EAudio.Create('Context window offset out of bounds');
  end;
  Result := FContexts[AContext][AOffset];
end;

function TJournalContextPool.Plan(const AInitial: TAcousticIndices;
  const ALocked: TJournalContextLocks; const AOptions: TJournalContextOptions;
  out AReport: TJournalContextReport): TJournalContextWindows;
var
  LOriginal: TJournalContextWindows;
  LRemaining: array of Integer;
  LUses: array of Integer;
  LFromContext: array of Boolean;
  LInitialRepeats: Integer;
  LIndex: Integer;
  LOffset: Integer;
  LOther: Integer;
  LContext: Integer;
  LRotation: Integer;
  LMatch: Integer;
  LBest: Integer;
  LBestLength: Integer;
  LBestScore: Integer;
  LScore: Integer;
  LNeeded: Integer;
  LQuota: Integer;
  LSlot: Integer;
  LChosen: Integer;
  LWork: Int64;
  LWindow: TJournalContextWindow;
  LCandidate: TJournalRepresentative;

  function Locked(const APosition: Integer): Boolean;
  begin
    Result := (Length(ALocked) <> 0) and ALocked[APosition];
  end;

  function QuotaIndex(const AWindow: TJournalContextWindow): Integer;
  begin
    Result := AWindow.Token * SourceCount + AWindow.Candidate.SegmentIndex;
  end;

  function RepeatsPrevious(const APath: TJournalContextWindows; const APosition: Integer;
    const ACandidate: TJournalRepresentative): Boolean;
  begin
    Result := (APosition > 0) and SameWindow(APath[APosition - 1].Candidate, ACandidate);
  end;

  procedure Measure(const APath: TJournalContextWindows);
  var
    LPosition: Integer;
  begin
    AReport.RepeatedWindows := 0;
    AReport.ContiguousLinks := 0;
    for LPosition := 1 to High(APath) do
    begin
      if SameWindow(APath[LPosition - 1].Candidate, APath[LPosition].Candidate) then
      begin
        Inc(AReport.RepeatedWindows);
      end;
      if (APath[LPosition - 1].Candidate.SegmentIndex = APath[LPosition].Candidate.SegmentIndex) and
        (APath[LPosition].Candidate.SourceFrame - APath[LPosition - 1].Candidate.SourceFrame = FHop) then
      begin
        Inc(AReport.ContiguousLinks);
      end;
    end;
  end;

  function RepairAt(var APath: TJournalContextWindows; const APosition: Integer): Boolean;
  var
    LRepairSlot: Integer;
    LRepairContext: Integer;
    LRepairOffset: Integer;
    LReplacement: TJournalContextWindow;

    function Fits(const AWindow: TJournalContextWindow): Boolean;
    begin
      Result := AWindow.Candidate.Found and
        (AWindow.Token = APath[APosition].Token) and
        (AWindow.Candidate.SegmentIndex = APath[APosition].Candidate.SegmentIndex) and
        not SameWindow(AWindow.Candidate, APath[APosition].Candidate) and
        ((APosition = 0) or not SameWindow(AWindow.Candidate, APath[APosition - 1].Candidate)) and
        ((APosition = High(APath)) or not SameWindow(AWindow.Candidate, APath[APosition + 1].Candidate));
    end;

    procedure Accept(const AWindow: TJournalContextWindow);
    begin
      APath[APosition] := AWindow;
      Inc(AReport.RepairEdits);
      if LFromContext[APosition] then
      begin
        LFromContext[APosition] := False;
        Dec(AReport.ContextGrains);
        Inc(AReport.FallbackGrains);
      end;
    end;

  begin
    Result := False;
    if Locked(APosition) then
    begin
      Exit;
    end;
    for LRepairSlot := 0 to FFallback.SlotCount - 1 do
    begin
      LReplacement.Token := FFallback.TokenAt(LRepairSlot);
      LReplacement.Candidate := FFallback.CandidateAt(LRepairSlot);
      if Fits(LReplacement) then
      begin
        Accept(LReplacement);
        Exit(True);
      end;
    end;
    for LRepairContext := 0 to Count - 1 do
    begin
      for LRepairOffset := 0 to High(FContexts[LRepairContext]) do
      begin
        LReplacement := FContexts[LRepairContext][LRepairOffset];
        if Fits(LReplacement) then
        begin
          Accept(LReplacement);
          Exit(True);
        end;
      end;
    end;
  end;

  function RepairBySwap(var APath: TJournalContextWindows;
    const APosition: Integer): Boolean;
  var
    LPartner: Integer;
    LSaved: TJournalContextWindow;

    function ClearNeighbors(const AIndex: Integer): Boolean;
    begin
      Result := ((AIndex = 0) or
        not SameWindow(APath[AIndex - 1].Candidate, APath[AIndex].Candidate)) and
        ((AIndex = High(APath)) or
        not SameWindow(APath[AIndex].Candidate, APath[AIndex + 1].Candidate));
    end;

    procedure MarkFallback(const AIndex: Integer);
    begin
      if LFromContext[AIndex] then
      begin
        LFromContext[AIndex] := False;
        Dec(AReport.ContextGrains);
        Inc(AReport.FallbackGrains);
      end;
    end;

  begin
    Result := False;
    if Locked(APosition) then
    begin
      Exit;
    end;
    for LPartner := 0 to High(APath) do
    begin
      if (LPartner = APosition) or Locked(LPartner) or
        (APath[LPartner].Token <> APath[APosition].Token) or
        (APath[LPartner].Candidate.SegmentIndex = APath[APosition].Candidate.SegmentIndex) then
      begin
        Continue;
      end;
      LSaved := APath[APosition];
      APath[APosition] := APath[LPartner];
      APath[LPartner] := LSaved;
      if ClearNeighbors(APosition) and ClearNeighbors(LPartner) then
      begin
        MarkFallback(APosition);
        MarkFallback(LPartner);
        Inc(AReport.RepairEdits);
        Exit(True);
      end;
      APath[LPartner] := APath[APosition];
      APath[APosition] := LSaved;
    end;
  end;

begin
  AReport := Default(TJournalContextReport);
  if (Length(AInitial) < 1) or (Length(AInitial) > MaximumJournalSelectionGrains) or
    ((Length(ALocked) <> 0) and (Length(ALocked) <> Length(AInitial))) or
    (AOptions.MaximumRunGrains < 1) or (AOptions.MaximumRunGrains > MaximumJournalContextGrains) or
    (AOptions.MaximumContextUses < 0) or (AOptions.MaximumContextUses > MaximumJournalSelectionGrains) or
    (AOptions.Seed < 0) then
  begin
    raise EAudio.Create('Context selection geometry or policy invalid');
  end;
  LWork := Int64(Length(AInitial)) *
    (FWindowCount * Int64(AOptions.MaximumRunGrains + 2) + FFallback.SlotCount * 3) +
    Int64(Length(AInitial)) * Length(AInitial) * 8;
  if AOptions.MaximumRunGrains = 1 then
  begin
    LWork := Length(AInitial);
  end;
  if LWork > MaximumJournalSelectionVisits then
  begin
    raise EAudio.Create('Context selection exceeds matching-work budget');
  end;
  AReport.WorkBound := LWork;
  LOriginal := nil;
  SetLength(LOriginal, Length(AInitial));
  SetLength(LRemaining, FTokenCount * SourceCount);
  SetLength(LUses, Count);
  SetLength(LFromContext, Length(AInitial));
  for LIndex := 0 to High(AInitial) do
  begin
    LOriginal[LIndex].Token := FFallback.TokenAt(AInitial[LIndex]);
    LOriginal[LIndex].Candidate := FFallback.CandidateAt(AInitial[LIndex]);
    if not LOriginal[LIndex].Candidate.Found then
    begin
      raise EAudio.Create('Context initial selection contains an empty slot');
    end;
    if not Locked(LIndex) then
    begin
      Inc(LRemaining[QuotaIndex(LOriginal[LIndex])]);
    end;
  end;
  Measure(LOriginal);
  LInitialRepeats := AReport.RepeatedWindows;
  Result := Copy(LOriginal);
  if AOptions.MaximumRunGrains = 1 then
  begin
    AReport.FallbackGrains := Length(AInitial);
    Exit;
  end;
  LIndex := 0;
  while LIndex < Length(Result) do
  begin
    if Locked(LIndex) then
    begin
      Inc(AReport.FallbackGrains);
      Inc(LIndex);
      Continue;
    end;
    LBest := -1;
    LBestLength := 0;
    LBestScore := 0;
    for LRotation := 0 to Count - 1 do
    begin
      LContext := (Int64(AOptions.Seed) + LRotation) mod Count;
      if (AOptions.MaximumContextUses > 0) and
        (LUses[LContext] >= AOptions.MaximumContextUses) then
      begin
        Continue;
      end;
      LMatch := 0;
      while (LMatch < Length(FContexts[LContext])) and
        (LMatch < AOptions.MaximumRunGrains) and (LIndex + LMatch < Length(Result)) do
      begin
        if Locked(LIndex + LMatch) then
        begin
          Break;
        end;
        LWindow := FContexts[LContext][LMatch];
        if LWindow.Token <> LOriginal[LIndex + LMatch].Token then
        begin
          Break;
        end;
        LNeeded := 1;
        for LOther := 0 to LMatch - 1 do
        begin
          if FContexts[LContext][LOther].Token = LWindow.Token then
          begin
            Inc(LNeeded);
          end;
        end;
        if LRemaining[QuotaIndex(LWindow)] < LNeeded then
        begin
          Break;
        end;
        Inc(LMatch);
      end;
      if (LMatch = 0) or RepeatsPrevious(Result, LIndex, FContexts[LContext][0].Candidate) then
      begin
        Continue;
      end;
      LScore := LMatch - 1;
      if (LIndex > 0) and
        (Result[LIndex - 1].Candidate.SegmentIndex = FContexts[LContext][0].Candidate.SegmentIndex) and
        (FContexts[LContext][0].Candidate.SourceFrame - Result[LIndex - 1].Candidate.SourceFrame = FHop) then
      begin
        Inc(LScore);
      end;
      if (LScore > LBestScore) or ((LScore = LBestScore) and (LScore > 0) and
        (LBest >= 0) and (LUses[LContext] < LUses[LBest])) then
      begin
        LBest := LContext;
        LBestLength := LMatch;
        LBestScore := LScore;
      end;
    end;
    if LBest >= 0 then
    begin
      for LOffset := 0 to LBestLength - 1 do
      begin
        Result[LIndex + LOffset] := FContexts[LBest][LOffset];
        LFromContext[LIndex + LOffset] := True;
        Dec(LRemaining[QuotaIndex(Result[LIndex + LOffset])]);
      end;
      Inc(LUses[LBest]);
      Inc(AReport.ContextRuns);
      Inc(AReport.ContextGrains, LBestLength);
      Inc(LIndex, LBestLength);
    end
    else
    begin
      LChosen := -1;
      LWindow := LOriginal[LIndex];
      if (LRemaining[QuotaIndex(LWindow)] > 0) and
        not RepeatsPrevious(Result, LIndex, LWindow.Candidate) then
      begin
        LChosen := AInitial[LIndex];
      end;
      if LChosen < 0 then
      begin
        for LOffset := 0 to FFallback.SlotCount - 1 do
        begin
          LSlot := (Int64(AOptions.Seed) + LIndex + LOffset) mod FFallback.SlotCount;
          LCandidate := FFallback.CandidateAt(LSlot);
          if not LCandidate.Found or (FFallback.TokenAt(LSlot) <> LOriginal[LIndex].Token) then
          begin
            Continue;
          end;
          LQuota := LOriginal[LIndex].Token * SourceCount + LCandidate.SegmentIndex;
          if LRemaining[LQuota] > 0 then
          begin
            LChosen := LSlot;
            if not RepeatsPrevious(Result, LIndex, LCandidate) then
            begin
              Break;
            end;
          end;
        end;
      end;
      if LChosen < 0 then
      begin
        raise EAudio.Create('Context remaining source quota has no fallback window');
      end;
      Result[LIndex].Candidate := FFallback.CandidateAt(LChosen);
      Dec(LRemaining[QuotaIndex(Result[LIndex])]);
      Inc(AReport.FallbackGrains);
      Inc(LIndex);
    end;
  end;
  for LQuota in LRemaining do
  begin
    if LQuota <> 0 then
    begin
      raise EAudio.Create('Context selection failed exact source accounting');
    end;
  end;
  Measure(Result);
  if AReport.RepeatedWindows > LInitialRepeats then
  begin
    for LIndex := 1 to High(Result) do
    begin
      if SameWindow(Result[LIndex - 1].Candidate, Result[LIndex].Candidate) then
      begin
        if not RepairAt(Result, LIndex) then
        begin
          if not RepairAt(Result, LIndex - 1) then
          begin
            if not RepairBySwap(Result, LIndex) then
            begin
              RepairBySwap(Result, LIndex - 1);
            end;
          end;
        end;
      end;
    end;
    Measure(Result);
  end;
  if AReport.RepeatedWindows > LInitialRepeats then
  begin
    Result := LOriginal;
    AReport.ContextRuns := 0;
    AReport.ContextGrains := 0;
    AReport.RepairEdits := 0;
    AReport.FallbackGrains := Length(Result);
    AReport.Reverted := True;
    Measure(Result);
  end;
end;

function RenderJournalContexts(const ASelection: TJournalContextWindows;
  const AReadWindow: TJournalWindowRead; const ASampleRate, AChannels,
  AWindowFrames, AHopFrames: Integer): TAudioClip;
var
  LClips: TAudioSources;
  LGrains: TAudioGrains;
  LRepresentatives: TJournalRepresentatives;
  LSamples: TAudioSamples;
  LIndex: Integer;
  LOther: Integer;
  LUnique: Integer;
  LSource: Integer;
  LFrames: Int64;
  LCandidate: TJournalRepresentative;
begin
  ValidateAudioFormat(ASampleRate, AChannels);
  if not Assigned(AReadWindow) or (Length(ASelection) < 1) or
    (Length(ASelection) > MaximumJournalSelectionGrains) or
    (AWindowFrames < 1) or (AWindowFrames > 65536) or
    (AHopFrames < 1) or (AHopFrames > AWindowFrames) then
  begin
    raise EAudio.Create('Context rendering geometry or callback invalid');
  end;
  LFrames := Int64(Length(ASelection) - 1) * AHopFrames + AWindowFrames;
  if (LFrames * AChannels > MaximumGrainSamples) or
    (Int64(Length(ASelection)) * AWindowFrames * AChannels > MaximumGrainVisits) then
  begin
    raise EAudio.Create('Context rendering exceeds sample/work budget');
  end;
  for LIndex := 0 to High(ASelection) do
  begin
    LCandidate := ASelection[LIndex].Candidate;
    if not LCandidate.Found or (LCandidate.ValidFrames < 1) or
      (LCandidate.ValidFrames > AWindowFrames) or (LCandidate.SegmentIndex < 0) or
      (LCandidate.SourceFrame < 0) or (LCandidate.FeatureIndex < 0) then
    begin
      raise EAudio.Create('Context rendering requires valid source coordinates');
    end;
  end;
  SetLength(LClips, Length(ASelection));
  SetLength(LRepresentatives, Length(ASelection));
  SetLength(LGrains, Length(ASelection));
  LUnique := 0;
  try
    for LIndex := 0 to High(ASelection) do
    begin
      LCandidate := ASelection[LIndex].Candidate;
      LSource := -1;
      for LOther := 0 to LUnique - 1 do
      begin
        if SameWindow(LCandidate, LRepresentatives[LOther]) then
        begin
          if LCandidate.ValidFrames <> LRepresentatives[LOther].ValidFrames then
          begin
            raise EAudio.Create('Repeated context coordinate has conflicting extent');
          end;
          LSource := LOther;
          Break;
        end;
      end;
      if LSource < 0 then
      begin
        LSource := LUnique;
        LSamples := AReadWindow(LCandidate);
        if Length(LSamples) <> LCandidate.ValidFrames * AChannels then
        begin
          raise EAudio.Create('Context callback returned mismatched source samples');
        end;
        SetLength(LSamples, AWindowFrames * AChannels);
        LClips[LSource] := TAudioClip.Create(ASampleRate, AChannels, LSamples);
        LRepresentatives[LSource] := LCandidate;
        Inc(LUnique);
      end;
      LGrains[LIndex].SourceIndex := LSource;
      LGrains[LIndex].SourceStartFrame := 0;
      LGrains[LIndex].OutputStartFrame := LIndex * AHopFrames;
      LGrains[LIndex].FrameCount := AWindowFrames;
      LGrains[LIndex].PlaybackRate := 1;
      LGrains[LIndex].Gain := 1;
      LGrains[LIndex].Window := gwHann;
    end;
    Result := RenderGrains(LClips, LGrains, DefaultGrainRenderOptions(ASampleRate, AChannels));
  finally
    for LIndex := 0 to High(LClips) do
    begin
      LClips[LIndex].Free;
    end;
  end;
end;

end.
