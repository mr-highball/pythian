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

unit pythian.learning.continuity;

{$mode delphi}
{$H+}

interface

uses
  pythian.audio,
  pythian.learning,
  pythian.learning.journal,
  pythian.learning.selection,
  pythian.learning.context,
  pythian.granular;

type
  TJournalSelectionLocks = array of Boolean;
  TJournalJoinOptions = record
    Passes: Integer;
    ProbeFrames: Integer;
    { Zero keeps global swaps; positive values bound forward output grain positions. }
    SwapRadius: Integer;
    SeamWeight: Double;
    SourceSwitchWeight: Double;
    CenterWeight: Double;
  end;
  TJournalJoinReport = record
    GrainCount: Integer;
    SourceSwitches: Integer;
    RepeatedWindows: Integer;
    ContiguousLinks: Integer;
    MeanSeamError: Double;
    MeanCenterError: Double;
    TotalCost: Double;
    AcceptedEdits: Integer;
    Passes: Integer;
    { Conservative planned probe-sample work, not measured visits or elapsed time. }
    ProbeWorkBound: Int64;
  end;

  { Borrows the pool for its lifetime. Reads each populated candidate once during
    construction through a source-bound callback returning exactly ValidFrames.
    Copies only incoming/outgoing probe samples; real EOF is zero-padded.
    Plan improves a feasible selection through same-segment substitutions and
    equal-token swaps. Per-token/segment counts, locked positions and the global
    immediate-repeat ceiling of the initial selection are hard constraints.
    This bounded local search does not promise a global optimum or a phrase model. }
  TJournalJoinPlanner = class
  private
    FPool: TJournalCandidatePool;
    FProbes: array of TGrainJoinProbe;
    FOptions: TJournalJoinOptions;
    FHop: Integer;
    FChannels: Integer;
    FProbeCount: Integer;
    procedure ValidateSelection(const ASelection: TAcousticIndices);
    function EdgeCost(const ALeft, ARight: Integer): Double;
    function SameSource(const ALeft, ARight: Integer): Boolean;
  public
    constructor Create(const APool: TJournalCandidatePool;
      const AReadWindow: TJournalWindowRead; const AWindowFrames, AHopFrames,
      AChannels: Integer; const AOptions: TJournalJoinOptions);
    function Evaluate(const ASelection: TAcousticIndices): TJournalJoinReport;
    function Plan(const AInitial: TAcousticIndices; const ALocked: TJournalSelectionLocks;
      out AReport: TJournalJoinReport): TAcousticIndices;
  end;


  TJournalContextJoinOptions = record
    Passes: Integer;
    ProbeFrames: Integer;
    { Forward distance in original source-contiguous chunks, not grains. }
    SwapRadius: Integer;
  end;
  TJournalContextJoinMetrics = record
    MeanSeamError: Double;
    MeanAssembledSeamError: Double;
    AssembledBoundaries: Integer;
    ContiguousLinks: Integer;
    RepeatedWindows: Integer;
  end;
  TJournalContextJoinReport = record
    Before: TJournalContextJoinMetrics;
    After: TJournalContextJoinMetrics;
    ChunkCount: Integer;
    AcceptedSwaps: Integer;
    Passes: Integer;
    WorkBound: Int64;
  end;

function DefaultJournalContextJoinOptions: TJournalContextJoinOptions;
{ Refines whole contiguous chunks with identical token sequences and lengths.
  Preserves every selected token/window multiplicity and all locked positions.
  Reads each distinct coordinate once. Accepts only lower total probe mismatch,
  nonincreasing assembled-boundary mean and nonincreasing immediate repeats.
  Reports sampled acoustic costs, not dense or perceptual quality guarantees. }
function PlanJournalContextJoins(const AInitial: TJournalContextWindows;
  const ALocked: TJournalContextLocks; const AReadWindow: TJournalWindowRead;
  const AWindowFrames, AHopFrames, AChannels: Integer;
  const AOptions: TJournalContextJoinOptions;
  out AReport: TJournalContextJoinReport): TJournalContextWindows;

function DefaultJournalJoinOptions: TJournalJoinOptions;

implementation

uses
  Math;


function DefaultJournalContextJoinOptions: TJournalContextJoinOptions;
begin
  Result.Passes := 4;
  Result.ProbeFrames := 64;
  Result.SwapRadius := 8;
end;

function PlanJournalContextJoins(const AInitial: TJournalContextWindows;
  const ALocked: TJournalContextLocks; const AReadWindow: TJournalWindowRead;
  const AWindowFrames, AHopFrames, AChannels: Integer;
  const AOptions: TJournalContextJoinOptions;
  out AReport: TJournalContextJoinReport): TJournalContextWindows;
type
  TChunk = record
    First: Integer;
    Count: Integer;
    Locked: Boolean;
  end;
  TTotals = record
    AllError: Double;
    AssembledError: Double;
    Assembled: Integer;
    Repeats: Integer;
  end;
var
  LChunks: array of TChunk;
  LWindows: TJournalContextWindows;
  LProbes: array of TGrainJoinProbe;
  LPath: TAcousticIndices;
  LProbeIds: TAcousticIndices;
  LSamples: TAudioSamples;
  LTotal: TTotals;
  LTrial: TTotals;
  LEdges: array[0..3] of Integer;
  LEdgeCount: Integer;
  LCount: Integer;
  LUnique: Integer;
  LProbeCount: Integer;
  LIndex: Integer;
  LOther: Integer;
  LOffset: Integer;
  LPass: Integer;
  LLeft: Integer;
  LRight: Integer;
  LEdge: Integer;
  LFound: Integer;
  LSaved: Integer;
  LEdits: Integer;
  LCompatible: Boolean;
  LWork: Int64;

  function SameCoordinate(const A, B: TJournalContextWindow): Boolean;
  begin
    Result := (A.Candidate.SegmentIndex = B.Candidate.SegmentIndex) and
      (A.Candidate.SourceFrame = B.Candidate.SourceFrame);
  end;

  function Contiguous(const A, B: TJournalContextWindow): Boolean;
  begin
    Result := (A.Candidate.SegmentIndex = B.Candidate.SegmentIndex) and
      (B.Candidate.SourceFrame - A.Candidate.SourceFrame = AHopFrames);
  end;

  function IdAt(const APosition: Integer; const ASwapped: Boolean): Integer;
  var
    LPosition: Integer;
  begin
    LPosition := APosition;
    if ASwapped then
    begin
      if (APosition >= LChunks[LLeft].First) and
        (APosition < LChunks[LLeft].First + LChunks[LLeft].Count) then
      begin
        LPosition := LChunks[LRight].First + APosition - LChunks[LLeft].First;
      end
      else if (APosition >= LChunks[LRight].First) and
        (APosition < LChunks[LRight].First + LChunks[LRight].Count) then
      begin
        LPosition := LChunks[LLeft].First + APosition - LChunks[LRight].First;
      end;
    end;
    Result := LPath[LPosition];
  end;

  procedure AddEdge(var ATotals: TTotals; const APosition, ASign: Integer;
    const ASwapped: Boolean);
  var
    LA: Integer;
    LB: Integer;
    LError: Double;
  begin
    LA := IdAt(APosition, ASwapped);
    LB := IdAt(APosition + 1, ASwapped);
    LError := NormalizedGrainJoinError(LProbes[LProbeIds[LA]].Outgoing,
      LProbes[LProbeIds[LB]].Incoming);
    ATotals.AllError := ATotals.AllError + ASign * LError;
    if not Contiguous(AInitial[LA], AInitial[LB]) then
    begin
      Inc(ATotals.Assembled, ASign);
      ATotals.AssembledError := ATotals.AssembledError + ASign * LError;
    end;
    if SameCoordinate(AInitial[LA], AInitial[LB]) then
    begin
      Inc(ATotals.Repeats, ASign);
    end;
  end;

  function Measure: TTotals;
  var
    LPosition: Integer;
  begin
    Result := Default(TTotals);
    for LPosition := 0 to High(LPath) - 1 do
    begin
      AddEdge(Result, LPosition, 1, False);
    end;
  end;

  function Metrics(const ATotals: TTotals): TJournalContextJoinMetrics;
  begin
    Result.MeanSeamError := ATotals.AllError / Max(1, Length(LPath) - 1);
    Result.MeanAssembledSeamError := ATotals.AssembledError /
      Max(1, ATotals.Assembled);
    if Result.MeanSeamError < 0 then
    begin
      Result.MeanSeamError := 0;
    end;
    if Result.MeanAssembledSeamError < 0 then
    begin
      Result.MeanAssembledSeamError := 0;
    end;
    Result.AssembledBoundaries := ATotals.Assembled;
    Result.ContiguousLinks := Length(LPath) - 1 - ATotals.Assembled;
    Result.RepeatedWindows := ATotals.Repeats;
  end;

  procedure IncludeEdge(const APosition: Integer);
  var
    LPosition: Integer;
  begin
    if (APosition < 0) or (APosition >= Length(LPath) - 1) then
    begin
      Exit;
    end;
    for LPosition := 0 to LEdgeCount - 1 do
    begin
      if LEdges[LPosition] = APosition then
      begin
        Exit;
      end;
    end;
    LEdges[LEdgeCount] := APosition;
    Inc(LEdgeCount);
  end;

begin
  AReport := Default(TJournalContextJoinReport);
  if (Length(AInitial) < 1) or (Length(AInitial) > MaximumJournalSelectionGrains) or
    ((Length(ALocked) <> 0) and (Length(ALocked) <> Length(AInitial))) or
    not Assigned(AReadWindow) or (AWindowFrames < 1) or (AWindowFrames > 65536) or
    (AHopFrames < 1) or (AHopFrames > AWindowFrames) or
    (AChannels < 1) or (AChannels > 2) or
    (AOptions.Passes < 1) or (AOptions.Passes > 8) or
    (AOptions.ProbeFrames < 1) or (AOptions.ProbeFrames > 64) or
    (AOptions.SwapRadius < 1) or (AOptions.SwapRadius > 64) then
  begin
    raise EAudio.Create('Context boundary geometry or policy invalid');
  end;
  SetLength(LChunks, Length(AInitial));
  LCount := 0;
  for LIndex := 0 to High(AInitial) do
  begin
    if not AInitial[LIndex].Candidate.Found or (AInitial[LIndex].Token < 0) or
      (AInitial[LIndex].Candidate.SegmentIndex < 0) or
      (AInitial[LIndex].Candidate.SourceFrame < 0) or
      (AInitial[LIndex].Candidate.ValidFrames < 1) or
      (AInitial[LIndex].Candidate.ValidFrames > AWindowFrames) then
    begin
      raise EAudio.Create('Context boundary selection contains an invalid window');
    end;
    if (LIndex = 0) or not Contiguous(AInitial[LIndex - 1], AInitial[LIndex]) then
    begin
      LChunks[LCount].First := LIndex;
      Inc(LCount);
    end;
    Inc(LChunks[LCount - 1].Count);
    LChunks[LCount - 1].Locked := LChunks[LCount - 1].Locked or
      ((Length(ALocked) <> 0) and ALocked[LIndex]);
  end;
  SetLength(LChunks, LCount);
  LProbeCount := Max(1, Min(AOptions.ProbeFrames, AWindowFrames - AHopFrames));
  { Deduplication, complete sample validation, token comparisons/swaps, paired
    before/after edge probes and initial/final reporting are all preflighted. }
  LWork := Int64(Length(AInitial)) * Length(AInitial) +
    Int64(Length(AInitial)) * AWindowFrames * AChannels +
    Int64(Length(AInitial)) * Min(AOptions.SwapRadius, LCount - 1) * AOptions.Passes * 3 +
    Int64(LCount) * Min(AOptions.SwapRadius, LCount - 1) * AOptions.Passes *
      8 * LProbeCount * AChannels +
    Int64(Length(AInitial)) * 4 * LProbeCount * AChannels;
  if LWork > MaximumJournalSelectionVisits then
  begin
    raise EAudio.Create('Context boundary refinement exceeds work budget');
  end;
  AReport.WorkBound := LWork;
  AReport.ChunkCount := LCount;
  SetLength(LWindows, Length(AInitial));
  SetLength(LProbes, Length(AInitial));
  SetLength(LPath, Length(AInitial));
  SetLength(LProbeIds, Length(AInitial));
  LUnique := 0;
  for LIndex := 0 to High(AInitial) do
  begin
    LFound := -1;
    for LOther := 0 to LUnique - 1 do
    begin
      if SameCoordinate(AInitial[LIndex], LWindows[LOther]) then
      begin
        if (AInitial[LIndex].Token <> LWindows[LOther].Token) or
          (AInitial[LIndex].Candidate.ValidFrames <> LWindows[LOther].Candidate.ValidFrames) then
        begin
          raise EAudio.Create('Context boundary coordinate has conflicting observations');
        end;
        LFound := LOther;
        Break;
      end;
    end;
    if LFound < 0 then
    begin
      LFound := LUnique;
      Inc(LUnique);
      LWindows[LFound] := AInitial[LIndex];
      LSamples := AReadWindow(AInitial[LIndex].Candidate);
      if Length(LSamples) <> AInitial[LIndex].Candidate.ValidFrames * AChannels then
      begin
        raise EAudio.Create('Context boundary callback returned mismatched samples');
      end;
      LProbes[LFound] := ExtractGrainJoinProbe(LSamples, AWindowFrames,
        AHopFrames, AChannels, AOptions.ProbeFrames);
    end;
    LPath[LIndex] := LIndex;
    LProbeIds[LIndex] := LFound;
  end;
  LTotal := Measure;
  AReport.Before := Metrics(LTotal);
  for LPass := 1 to AOptions.Passes do
  begin
    LEdits := 0;
    for LLeft := 0 to LCount - 2 do
    begin
      if LChunks[LLeft].Locked then
      begin
        Continue;
      end;
      for LRight := LLeft + 1 to Min(LCount - 1, LLeft + AOptions.SwapRadius) do
      begin
        if LChunks[LRight].Locked or (LChunks[LLeft].Count <> LChunks[LRight].Count) then
        begin
          Continue;
        end;
        LCompatible := True;
        for LOffset := 0 to LChunks[LLeft].Count - 1 do
        begin
          if AInitial[LChunks[LLeft].First + LOffset].Token <>
            AInitial[LChunks[LRight].First + LOffset].Token then
          begin
            LCompatible := False;
            Break;
          end;
        end;
        if not LCompatible then
        begin
          Continue;
        end;
        LEdgeCount := 0;
        IncludeEdge(LChunks[LLeft].First - 1);
        IncludeEdge(LChunks[LLeft].First + LChunks[LLeft].Count - 1);
        IncludeEdge(LChunks[LRight].First - 1);
        IncludeEdge(LChunks[LRight].First + LChunks[LRight].Count - 1);
        LTrial := LTotal;
        for LEdge := 0 to LEdgeCount - 1 do
        begin
          AddEdge(LTrial, LEdges[LEdge], -1, False);
          AddEdge(LTrial, LEdges[LEdge], 1, True);
        end;
        if (LTrial.AllError < LTotal.AllError - 1E-12) and
          (LTrial.AssembledError / Max(1, LTrial.Assembled) <=
            LTotal.AssembledError / Max(1, LTotal.Assembled) + 1E-12) and
          (LTrial.Repeats <= LTotal.Repeats) then
        begin
          for LOffset := 0 to LChunks[LLeft].Count - 1 do
          begin
            LSaved := LPath[LChunks[LLeft].First + LOffset];
            LPath[LChunks[LLeft].First + LOffset] := LPath[LChunks[LRight].First + LOffset];
            LPath[LChunks[LRight].First + LOffset] := LSaved;
          end;
          LTotal := LTrial;
          Inc(LEdits);
        end;
      end;
    end;
    Inc(AReport.AcceptedSwaps, LEdits);
    AReport.Passes := LPass;
    if LEdits = 0 then
    begin
      Break;
    end;
  end;
  AReport.After := Metrics(Measure);
  Result := nil;
  SetLength(Result, Length(AInitial));
  for LIndex := 0 to High(Result) do
  begin
    Result[LIndex] := AInitial[LPath[LIndex]];
  end;
end;

function DefaultJournalJoinOptions: TJournalJoinOptions;
begin
  Result.Passes := 4;
  Result.ProbeFrames := 16;
  Result.SwapRadius := 0;
  Result.SeamWeight := 1;
  Result.SourceSwitchWeight := 0.2;
  Result.CenterWeight := 0.05;
end;

constructor TJournalJoinPlanner.Create(const APool: TJournalCandidatePool;
  const AReadWindow: TJournalWindowRead; const AWindowFrames, AHopFrames,
  AChannels: Integer; const AOptions: TJournalJoinOptions);
var
  LSlot: Integer;
  LCandidate: TJournalRepresentative;
  LSamples: TAudioSamples;
begin
  inherited Create;
  RequireFinite(AOptions.SeamWeight, 'Join seam weight');
  RequireFinite(AOptions.SourceSwitchWeight, 'Join source-switch weight');
  RequireFinite(AOptions.CenterWeight, 'Join center weight');
  if (APool = nil) or not Assigned(AReadWindow) or
    (AWindowFrames < 1) or (AWindowFrames > 65536) or
    (AHopFrames < 1) or (AHopFrames > AWindowFrames) or
    (AChannels < 1) or (AChannels > 2) or
    (AOptions.Passes < 1) or (AOptions.Passes > 8) or
    (AOptions.ProbeFrames < 1) or (AOptions.ProbeFrames > 64) or
    (AOptions.SwapRadius < 0) or (AOptions.SwapRadius >= MaximumJournalSelectionGrains) or
    (AOptions.SeamWeight < 0) or (AOptions.SeamWeight > 16) or
    (AOptions.SourceSwitchWeight < 0) or (AOptions.SourceSwitchWeight > 16) or
    (AOptions.CenterWeight < 0) or (AOptions.CenterWeight > 16) then
  begin
    raise EAudio.Create('Journal join options or source geometry invalid');
  end;
  if Int64(APool.SlotCount) * AWindowFrames * AChannels > MaximumGrainVisits then
  begin
    raise EAudio.Create('Journal join candidate read budget exceeded');
  end;
  FPool := APool;
  FOptions := AOptions;
  FHop := AHopFrames;
  FChannels := AChannels;
  FProbeCount := Max(1, Min(FOptions.ProbeFrames, AWindowFrames - FHop));
  SetLength(FProbes, FPool.SlotCount);
  for LSlot := 0 to FPool.SlotCount - 1 do
  begin
    LCandidate := FPool.CandidateAt(LSlot);
    if not LCandidate.Found then
    begin
      Continue;
    end;
    if (LCandidate.ValidFrames < 1) or (LCandidate.ValidFrames > AWindowFrames) then
    begin
      raise EAudio.Create('Journal candidate exceeds the join window');
    end;
    LSamples := AReadWindow(LCandidate);
    if Length(LSamples) <> LCandidate.ValidFrames * FChannels then
    begin
      raise EAudio.Create('Journal window callback returned an incomplete or mismatched window');
    end;
    FProbes[LSlot] := ExtractGrainJoinProbe(LSamples, AWindowFrames, FHop,
      FChannels, FOptions.ProbeFrames);
  end;
end;

procedure TJournalJoinPlanner.ValidateSelection(const ASelection: TAcousticIndices);
var
  LSlot: Integer;
begin
  if (Length(ASelection) < 1) or (Length(ASelection) > MaximumJournalSelectionGrains) then
  begin
    raise EAudio.Create('Journal join selection requires 1..4096 grains');
  end;
  for LSlot in ASelection do
  begin
    if not FPool.CandidateAt(LSlot).Found then
    begin
      raise EAudio.Create('Journal join selection contains an empty candidate');
    end;
  end;
end;

function TJournalJoinPlanner.SameSource(const ALeft, ARight: Integer): Boolean;
begin
  Result := FPool.CandidateAt(ALeft).SegmentIndex = FPool.CandidateAt(ARight).SegmentIndex;
end;

function TJournalJoinPlanner.EdgeCost(const ALeft, ARight: Integer): Double;
begin
  Result := FOptions.SeamWeight * NormalizedGrainJoinError(
    FProbes[ALeft].Outgoing, FProbes[ARight].Incoming);
  if not SameSource(ALeft, ARight) then
  begin
    Result := Result + FOptions.SourceSwitchWeight;
  end;
end;

function TJournalJoinPlanner.Evaluate(const ASelection: TAcousticIndices): TJournalJoinReport;
var
  LIndex: Integer;
  LCurrent: TJournalRepresentative;
  LPrevious: TJournalRepresentative;
begin
  ValidateSelection(ASelection);
  Result := Default(TJournalJoinReport);
  Result.GrainCount := Length(ASelection);
  LPrevious := Default(TJournalRepresentative);
  for LIndex := 0 to High(ASelection) do
  begin
    LCurrent := FPool.CandidateAt(ASelection[LIndex]);
    Result.MeanCenterError := Result.MeanCenterError + LCurrent.Distance;
    Result.TotalCost := Result.TotalCost + FOptions.CenterWeight * LCurrent.Distance;
    if LIndex > 0 then
    begin
      Result.MeanSeamError := Result.MeanSeamError + NormalizedGrainJoinError(
        FProbes[ASelection[LIndex - 1]].Outgoing, FProbes[ASelection[LIndex]].Incoming);
      Result.TotalCost := Result.TotalCost + EdgeCost(ASelection[LIndex - 1], ASelection[LIndex]);
      if LPrevious.SegmentIndex <> LCurrent.SegmentIndex then
      begin
        Inc(Result.SourceSwitches);
      end
      else if LPrevious.SourceFrame = LCurrent.SourceFrame then
      begin
        Inc(Result.RepeatedWindows);
      end
      else if LPrevious.SourceFrame + FHop = LCurrent.SourceFrame then
      begin
        Inc(Result.ContiguousLinks);
      end;
    end;
    LPrevious := LCurrent;
  end;
  Result.MeanCenterError := Result.MeanCenterError / Result.GrainCount;
  if Result.GrainCount > 1 then
  begin
    Result.MeanSeamError := Result.MeanSeamError / (Result.GrainCount - 1);
  end;
end;

function TJournalJoinPlanner.Plan(const AInitial: TAcousticIndices;
  const ALocked: TJournalSelectionLocks; out AReport: TJournalJoinReport): TAcousticIndices;
var
  LPath: TAcousticIndices;
  LBaseline: TJournalJoinReport;
  LRepeats: Integer;
  LEdits: Integer;
  LBeforePass: Integer;
  LPass: Integer;
  LIndex: Integer;
  LOther: Integer;
  LBin: Integer;
  LBase: Integer;
  LSlot: Integer;
  LWork: Int64;
  LPairs: Int64;
  LPairLeft: Integer;
  LPairRight: Integer;

  function LastPartner(const APosition: Integer): Integer;
  begin
    Result := High(AInitial);
    if FOptions.SwapRadius > 0 then
    begin
      Result := Min(Result, APosition + FOptions.SwapRadius);
    end;
  end;

  function Locked(const APosition: Integer): Boolean;
  begin
    Result := (Length(ALocked) <> 0) and ALocked[APosition];
  end;

  procedure TryEdit(const APosition, ANewSlot, AOther, AOtherSlot: Integer);
  var
    LEdges: array[0..3] of Integer;
    LEdgeCount: Integer;
    LOldSlot: Integer;
    LOldOther: Integer;
    LOldCost: Double;
    LNewCost: Double;
    LOldRepeats: Integer;
    LNewRepeats: Integer;

    procedure AddEdge(const AEdge: Integer);
    var
      LExisting: Integer;
    begin
      if (AEdge < 1) or (AEdge >= Length(LPath)) then
      begin
        Exit;
      end;
      for LExisting := 0 to LEdgeCount - 1 do
      begin
        if LEdges[LExisting] = AEdge then
        begin
          Exit;
        end;
      end;
      LEdges[LEdgeCount] := AEdge;
      Inc(LEdgeCount);
    end;

    procedure Measure(out ACost: Double; out ARepeats: Integer);
    var
      LEdge: Integer;
      LItem: Integer;
    begin
      ACost := FOptions.CenterWeight * FPool.CandidateAt(LPath[APosition]).Distance;
      if AOther >= 0 then
      begin
        ACost := ACost + FOptions.CenterWeight * FPool.CandidateAt(LPath[AOther]).Distance;
      end;
      ARepeats := 0;
      for LItem := 0 to LEdgeCount - 1 do
      begin
        LEdge := LEdges[LItem];
        ACost := ACost + EdgeCost(LPath[LEdge - 1], LPath[LEdge]);
        if LPath[LEdge - 1] = LPath[LEdge] then
        begin
          Inc(ARepeats);
        end;
      end;
    end;

  begin
    LOldSlot := LPath[APosition];
    if (ANewSlot = LOldSlot) and
      ((AOther < 0) or (AOtherSlot = LPath[AOther])) then
    begin
      Exit;
    end;
    LEdgeCount := 0;
    AddEdge(APosition);
    AddEdge(APosition + 1);
    if AOther >= 0 then
    begin
      AddEdge(AOther);
      AddEdge(AOther + 1);
    end;
    Measure(LOldCost, LOldRepeats);
    LOldOther := -1;
    if AOther >= 0 then
    begin
      LOldOther := LPath[AOther];
      LPath[AOther] := AOtherSlot;
    end;
    LPath[APosition] := ANewSlot;
    Measure(LNewCost, LNewRepeats);
    if (LNewCost < LOldCost - 1E-12) and
      (LRepeats - LOldRepeats + LNewRepeats <= LBaseline.RepeatedWindows) then
    begin
      Inc(LRepeats, LNewRepeats - LOldRepeats);
      Inc(LEdits);
    end
    else
    begin
      LPath[APosition] := LOldSlot;
      if AOther >= 0 then
      begin
        LPath[AOther] := LOldOther;
      end;
    end;
  end;

begin
  AReport := Default(TJournalJoinReport);
  ValidateSelection(AInitial);
  if (Length(ALocked) <> 0) and (Length(ALocked) <> Length(AInitial)) then
  begin
    raise EAudio.Create('Journal join locks must match the selection');
  end;
  { Global equal-token/different-segment pair counts remain invariant. With a
    local radius, segment assignments inside the neighborhood can change, so
    conservatively count ALL equal-token pairs there, including locked ones. }
  LPairs := 0;
  for LIndex := 0 to High(AInitial) do
  begin
    for LOther := LIndex + 1 to LastPartner(LIndex) do
    begin
      if (FPool.TokenAt(AInitial[LIndex]) = FPool.TokenAt(AInitial[LOther])) and
        ((FOptions.SwapRadius > 0) or not SameSource(AInitial[LIndex], AInitial[LOther])) then
      begin
        Inc(LPairs);
      end;
    end;
  end;
  { At most eight edge evaluations per proposal, plus endpoint evaluations. }
  LWork := Int64(FOptions.Passes) * FPool.BinsPerSegment *
    (Length(AInitial) + LPairs * 2) * 8 * FProbeCount * FChannels +
    Int64(Length(AInitial)) * 4 * FProbeCount * FChannels;
  if LWork > MaximumGrainVisits then
  begin
    raise EAudio.Create('Journal join search exceeds probe-work budget');
  end;
  LBaseline := Evaluate(AInitial);
  LPath := Copy(AInitial);
  LRepeats := LBaseline.RepeatedWindows;
  LEdits := 0;
  LPass := 0;
  repeat
    Inc(LPass);
    LBeforePass := LEdits;
    for LIndex := 0 to High(LPath) do
    begin
      if Locked(LIndex) then
      begin
        Continue;
      end;
      LBase := (LPath[LIndex] div FPool.BinsPerSegment) * FPool.BinsPerSegment;
      for LBin := 0 to FPool.BinsPerSegment - 1 do
      begin
        LSlot := LBase + LBin;
        if FPool.CandidateAt(LSlot).Found then
        begin
          TryEdit(LIndex, LSlot, -1, -1);
        end;
      end;
      for LOther := LIndex + 1 to LastPartner(LIndex) do
      begin
        if not Locked(LOther) and
          (FPool.TokenAt(LPath[LIndex]) = FPool.TokenAt(LPath[LOther])) and
          not SameSource(LPath[LIndex], LPath[LOther]) then
        begin
          LPairLeft := LPath[LIndex];
          LPairRight := LPath[LOther];
          { Swap source assignments while trying alternate windows on each side.
            Exact-window swaps alone can be trapped by the no-new-repeat rule. }
          LBase := (LPairRight div FPool.BinsPerSegment) * FPool.BinsPerSegment;
          for LBin := 0 to FPool.BinsPerSegment - 1 do
          begin
            LSlot := LBase + LBin;
            if FPool.CandidateAt(LSlot).Found then
            begin
              TryEdit(LIndex, LSlot, LOther, LPairLeft);
            end;
          end;
          LBase := (LPairLeft div FPool.BinsPerSegment) * FPool.BinsPerSegment;
          for LBin := 0 to FPool.BinsPerSegment - 1 do
          begin
            LSlot := LBase + LBin;
            if FPool.CandidateAt(LSlot).Found then
            begin
              TryEdit(LIndex, LPairRight, LOther, LSlot);
            end;
          end;
        end;
      end;
    end;
  until (LPass = FOptions.Passes) or (LEdits = LBeforePass);
  AReport := Evaluate(LPath);
  AReport.AcceptedEdits := LEdits;
  AReport.Passes := LPass;
  AReport.ProbeWorkBound := LWork;
  Result := LPath;
end;

end.
