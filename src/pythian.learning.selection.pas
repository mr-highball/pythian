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

unit pythian.learning.selection;

{$mode delphi}
{$H+}

interface

uses
  pythian.audio,
  pythian.analysis.journal,
  pythian.learning,
  pythian.learning.journal,
  pythian.progress;

const
  MaximumJournalCandidateSlots = 65536;
  MaximumJournalSelectionGrains = 4096;
  MaximumJournalSelectionVisits = 64000000;
  MaximumJournalSuccessorObservations = 1048576;

type
  TJournalSelectionWeights = array of Integer;
  TJournalWindowRead = function(const ACandidate: TJournalRepresentative): TAudioSamples of object;

  { Copies coordinates only; the reader and palette are borrowed during construction.
    Each token/segment has up to 32 temporal bins, with its nearest assigned
    observation retained in each bin. No whole recording or feature array is kept.
    Keep the original source/palette bindings with this pool. Big Boss: optional
    constructor observers are call-scoped, include nested journal decoding and
    may abort before publication. A failed read requires journal/reader reopen;
    allocation and RTL array copies remain synchronous. }
  TJournalCandidatePool = class
  private
    FSlots: TJournalRepresentatives;
    FTokenCount: Integer;
    FSegmentCount: Integer;
    FBins: Integer;
    function GetSlotCount: Integer;
  public
    constructor Create(const AReader: TJournalTrainingReader;
      const APalette: TAcousticPalette; const ABinsPerSegment: Integer = 4;
      const AProgress: TWorkProgressCallback = nil);
    { Restores detached slots without learning. Validates slot geometry only;
      the caller must bind/validate source extents, timebase and palette identity. }
    constructor CreateFromCandidates(const ATokenCount, ASegmentCount,
      ABinsPerSegment: Integer; const ACandidates: TJournalRepresentatives;
      const AProgress: TWorkProgressCallback = nil);
    function CandidateAt(const ASlot: Integer): TJournalRepresentative;
    function TokenAt(const ASlot: Integer): Integer;
    { Returns slot indices, preserving every requested token. Weights 0..4096
      target segment contribution independently of training; zero excludes.
      Smooth weighted rotation considers only segments containing the token.
      These are soft shares, not quotas. Missing eligible tokens reject.
      Seed rotates candidate bins, independently of model generation. A previous
      identical window is skipped when another candidate in that segment exists.
      Selection is repeatable and does not mutate the pool. }
    function Select(const ATokens: TAcousticIndices;
      const AWeights: TJournalSelectionWeights;
      const ASeed: Integer = 731;
      const AProgress: TWorkProgressCallback = nil): TAcousticIndices;
    property SlotCount: Integer read GetSlotCount;
    property SegmentCount: Integer read FSegmentCount;
    property BinsPerSegment: Integer read FBins;
  end;

  TJournalSuccessorSource = record
    Binding: TFeatureJournalBinding;
    FirstFeature: Int64;
    FeatureCount: Int64;
  end;

  { Detaches token/distance observations from completed, verified journals using
    the supplied existing palette. No training, source PCM or feature arrays are
    retained. Host verification binds journal bytes, palette and original ranges.
    The hard observation bound is checked before allocation. }
  TJournalSourceSuccessors = class
  private
    type
      TNode = record
        Token: Integer;
        Distance: Double;
      end;
      TSource = record
        Geometry: TJournalSuccessorSource;
        NodeOffset: Integer;
      end;
    var
      FNodes: array of TNode;
      FSources: array of TSource;
      FTokenCount: Integer;
      FHopFrames: Integer;
      FWindowFrames: Integer;
      FVocabularySha256: String;
      function GetSourceCount: Integer;
      function GetObservationCount: Integer;
      function GetNativeStorageBytes: Int64;
      function NodeAt(const ACandidate: TJournalRepresentative): Integer;
  public
    constructor Create(const AReader: TJournalTrainingReader;
      const APalette: TAcousticPalette;
      const AProgress: TWorkProgressCallback = nil);
    function SourceAt(const AIndex: Integer): TJournalSuccessorSource;
    { Checks pool geometry, candidate coordinates and observed token membership.
      A coordinate-only pool cannot prove source bytes or palette provenance;
      callers separately bind those identities before rendering. }
    procedure RequireCompatible(const APool: TJournalCandidatePool;
      const AProgress: TWorkProgressCallback = nil);
    { Only the exact next observed source hop is eligible. A fallback range
      mismatch, token mismatch or selected-range endpoint keeps the fallback.
      All decisions are deterministic and leave this index unchanged. }
    function Select(const APrevious, AFallback: TJournalRepresentative;
      const ARequestedToken: Integer): TJournalRepresentative;
    property SourceCount: Integer read GetSourceCount;
    property ObservationCount: Integer read GetObservationCount;
    { Native record-layout payload plus stored text bytes, excluding allocator,
      array and object overhead. This is not a heap-usage measurement. pas2js
      raises EAudio because JavaScript objects have no static native layout. }
    property NativeStorageBytes: Int64 read GetNativeStorageBytes;
    property VocabularySha256: String read FVocabularySha256;
  end;

  { Borrows an immutable pool. Each successful chunk continues the same smooth
    weighted segment rotation, per-token/segment bin cursors and last slot.
    Grain and visit budgets apply per call; total counters are checked Int64.
    Failed chunks preserve the cursor and do not publish a partial selection.
    A new instance starts a new sequence; caller keeps the pool alive. }
  TJournalSelectionStream = class
  private
    type
      { A complete private selection, published only after the final observer.
        Credits/cursors detach from accepted arrays before any mutation. }
      TSelectionCandidate = record
        Credits: array of Int64;
        Cursors: array of Integer;
        Previous: Integer;
        SelectedCount: Int64;
        SelectionVisits: Int64;
        PreviousWindow: TJournalRepresentative;
        Slots: TAcousticIndices;
        Windows: TJournalRepresentatives;
      end;
  private
    FPool: TJournalCandidatePool;
    FWeights: TJournalSelectionWeights;
    FCredits: array of Int64;
    FCursors: array of Integer;
    FPrevious: Integer;
    FSelectedCount: Int64;
    FSelectionVisits: Int64;
    FSuccessors: TJournalSourceSuccessors;
    FPreviousWindow: TJournalRepresentative;
    FSelecting: Boolean;
    function PrepareChunk(const ATokens: TAcousticIndices;
      const AWindows: Boolean; const AProgress: TWorkProgressCallback): TSelectionCandidate;
    procedure CommitCandidate(const ACandidate: TSelectionCandidate);
  public
    { Setup reports weight/cursor items and forwards the immutable successor
      compatibility scan. All owned arrays are detached before publication. }
    constructor Create(const APool: TJournalCandidatePool;
      const AWeights: TJournalSelectionWeights; const ASeed: Integer = 731;
      const ASuccessors: TJournalSourceSuccessors = nil;
      const AProgress: TWorkProgressCallback = nil);
    { Observers are borrowed synchronously. journal_select_visits counts actual
      token/segment/bin/window visits, not the conservative SelectionVisits
      budget. Total stays unknown until the final callback, before cursor/result
      publication. Callback failure preserves old outputs/state and exact retry.
      Selecting again during a callback rejects; read-only counters stay old.
      RTL copies are bounded by 65536 cursors/credits and 4096 input tokens. }
    function SelectChunk(const ATokens: TAcousticIndices;
      const AProgress: TWorkProgressCallback = nil): TAcousticIndices;
    { Borrows the optional immutable successor index for this stream's lifetime.
      Consumes the same fallback rotation as SelectChunk; actual windows can
      extend outside the sparse pool, preserving each token and fallback range.
      Failed calls preserve fallback cursors, counters and previous actual window.
      Use one selection method consistently during a sequence. }
    function SelectWindowsChunk(const ATokens: TAcousticIndices;
      const AProgress: TWorkProgressCallback = nil): TJournalRepresentatives;
    property SelectedCount: Int64 read FSelectedCount;
    property SelectionVisits: Int64 read FSelectionVisits;
  end;

{ Materializes only selected windows, once per slot. The callback returns actual
  ValidFrames; EOF is zero-padded to the declared window before Hann overlap-add.
  Returned audio is caller-owned. No source path, cache or model dependency. }
function RenderJournalSelection(const APool: TJournalCandidatePool;
  const ASelection: TAcousticIndices; const AReadWindow: TJournalWindowRead;
  const ASampleRate, AChannels, AWindowFrames, AHopFrames: Integer): TAudioClip;

implementation

uses
  Math,
  pythian.continuity,
  pythian.learning.binding,
  pythian.granular;

{ Big Boss: count real owned loop visits; neither callback nor mutable progress
  state is retained by the pool/selector. The last report precedes publication. }
procedure SelectionVisit(var AVisits: Int64; const AStage: String;
  const AProgress: TWorkProgressCallback);
begin
  Inc(AVisits);
  if (AVisits and 255) = 0 then
  begin
    ReportWork(AProgress, AStage, wuItems, AVisits, 0);
  end;
end;

function RenderJournalSelection(const APool: TJournalCandidatePool;
  const ASelection: TAcousticIndices; const AReadWindow: TJournalWindowRead;
  const ASampleRate, AChannels, AWindowFrames, AHopFrames: Integer): TAudioClip;
var
  LClips: TAudioSources;
  LGrains: TAudioGrains;
  LSamples: TAudioSamples;
  LCandidate: TJournalRepresentative;
  LIndex: Integer;
  LSlot: Integer;
  LFrames: Int64;
begin
  ValidateAudioFormat(ASampleRate, AChannels);
  if (APool = nil) or not Assigned(AReadWindow) or
    (Length(ASelection) < 1) or (Length(ASelection) > MaximumJournalSelectionGrains) or
    (AWindowFrames < 1) or (AWindowFrames > 65536) or
    (AHopFrames < 1) or (AHopFrames > AWindowFrames) then
  begin
    raise EAudio.Create('Journal rendering geometry or callback invalid');
  end;
  LFrames := Int64(Length(ASelection) - 1) * AHopFrames + AWindowFrames;
  if (LFrames * AChannels > MaximumGrainSamples) or
    (Int64(Length(ASelection)) * AWindowFrames * AChannels > MaximumGrainVisits) then
  begin
    raise EAudio.Create('Journal rendering exceeds sample/work budget');
  end;
  for LSlot in ASelection do
  begin
    LCandidate := APool.CandidateAt(LSlot);
    if not LCandidate.Found or (LCandidate.ValidFrames > AWindowFrames) then
    begin
      raise EAudio.Create('Journal rendering requires admitted candidate windows');
    end;
  end;
  SetLength(LClips, APool.SlotCount);
  SetLength(LGrains, Length(ASelection));
  try
    for LIndex := 0 to High(ASelection) do
    begin
      LSlot := ASelection[LIndex];
      LCandidate := APool.CandidateAt(LSlot);
      if LClips[LSlot] = nil then
      begin
        LSamples := AReadWindow(LCandidate);
        if Length(LSamples) <> LCandidate.ValidFrames * AChannels then
        begin
          raise EAudio.Create('Journal render callback returned a mismatched window');
        end;
        SetLength(LSamples, AWindowFrames * AChannels);
        LClips[LSlot] := TAudioClip.Create(ASampleRate, AChannels, LSamples);
      end;
      LGrains[LIndex].SourceIndex := LSlot;
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

constructor TJournalCandidatePool.Create(const AReader: TJournalTrainingReader;
  const APalette: TAcousticPalette; const ABinsPerSegment: Integer;
  const AProgress: TWorkProgressCallback);
var
  LObservation: TJournalTrainingObservation;
  LSegment: TJournalTrainingSegment;
  LBinWidth: Int64;
  LToken: Integer;
  LBin: Integer;
  LSlot: Integer;
  LDistance: Double;
  LRead: Int64;
begin
  inherited Create;
  if (AReader = nil) or (APalette = nil) or
    (ABinsPerSegment < 1) or (ABinsPerSegment > 32) then
  begin
    raise EAudio.Create('Candidate pool requires reader, palette and 1..32 temporal bins');
  end;
  FTokenCount := APalette.Count;
  FSegmentCount := AReader.SegmentCount;
  FBins := ABinsPerSegment;
  if Int64(FTokenCount) * FSegmentCount * FBins > MaximumJournalCandidateSlots then
  begin
    raise EAudio.Create('Journal candidate slot budget exceeded');
  end;
  SetLength(FSlots, FTokenCount * FSegmentCount * FBins);
  AReader.Rewind;
  LRead := 0;
  ReportWork(AProgress, 'candidate_observations', wuObservations, 0, AReader.ObservationCount);
  while AReader.ReadObservation(LObservation, AProgress) do
  begin
    LSegment := AReader.SegmentAt(LObservation.SegmentIndex);
    LBinWidth := (LSegment.FeatureCount - 1) div FBins + 1;
    LBin := (LObservation.FeatureIndex - LSegment.FirstFeature) div LBinWidth;
    LToken := APalette.EncodeFeature(LObservation.Feature);
    LSlot := (LToken * FSegmentCount + LObservation.SegmentIndex) * FBins + LBin;
    LDistance := APalette.FeatureDistance(LObservation.Feature, LToken);
    if not FSlots[LSlot].Found or (LDistance < FSlots[LSlot].Distance) then
    begin
      FSlots[LSlot].Found := True;
      FSlots[LSlot].SegmentIndex := LObservation.SegmentIndex;
      FSlots[LSlot].FeatureIndex := LObservation.FeatureIndex;
      FSlots[LSlot].SourceFrame := LObservation.SourceFrame;
      FSlots[LSlot].ValidFrames := LObservation.Feature.ValidFrames;
      FSlots[LSlot].Distance := LDistance;
    end;
    Inc(LRead);
    if LRead mod 128 = 0 then
    begin
      ReportWork(AProgress, 'candidate_observations', wuObservations, LRead, AReader.ObservationCount);
    end;
  end;
  ReportWork(AProgress, 'candidate_observations', wuObservations, LRead, AReader.ObservationCount);
  ReportWork(AProgress, 'candidate_pool_ready', wuItems, 1, 1);
end;

constructor TJournalCandidatePool.CreateFromCandidates(const ATokenCount,
  ASegmentCount, ABinsPerSegment: Integer; const ACandidates: TJournalRepresentatives;
  const AProgress: TWorkProgressCallback);
var
  LSlot: Integer;
  LCandidate: TJournalRepresentative;
begin
  inherited Create;
  if (ATokenCount < 1) or (ATokenCount > MaximumAcousticVocabulary) or
    (ASegmentCount < 1) or (ASegmentCount > MaximumJournalTrainingSegments) or
    (ABinsPerSegment < 1) or (ABinsPerSegment > 32) or
    (Int64(ATokenCount) * ASegmentCount * ABinsPerSegment > MaximumJournalCandidateSlots) or
    (Length(ACandidates) <> ATokenCount * ASegmentCount * ABinsPerSegment) then
  begin
    raise EAudio.Create('Restored candidate geometry exceeds the pool contract');
  end;
  FTokenCount := ATokenCount;
  FSegmentCount := ASegmentCount;
  FBins := ABinsPerSegment;
  SetLength(FSlots, Length(ACandidates));
  ReportWork(AProgress, 'candidate_restore_slots', wuItems, 0, Length(FSlots));
  for LSlot := 0 to High(FSlots) do
  begin
    if (LSlot > 0) and (LSlot mod 256 = 0) then
    begin
      ReportWork(AProgress, 'candidate_restore_slots', wuItems, LSlot, Length(FSlots));
    end;
    LCandidate := ACandidates[LSlot];
    if not LCandidate.Found then
    begin
      Continue;
    end;
    RequireFinite(LCandidate.Distance, 'Restored candidate distance');
    if (LCandidate.SegmentIndex <> (LSlot div FBins) mod FSegmentCount) or
      (LCandidate.SourceFrame < 0) or (LCandidate.FeatureIndex < 0) or
      (LCandidate.ValidFrames < 1) or (LCandidate.ValidFrames > 65536) or
      (LCandidate.Distance < 0) or (LCandidate.Distance > Length(TAcousticVector)) then
    begin
      raise EAudio.Create('Restored candidate is outside its declared pool slot');
    end;
    FSlots[LSlot] := LCandidate;
  end;
  ReportWork(AProgress, 'candidate_restore_slots', wuItems, Length(FSlots), Length(FSlots));
  ReportWork(AProgress, 'candidate_pool_ready', wuItems, 1, 1);
end;

function TJournalCandidatePool.GetSlotCount: Integer;
begin
  Result := Length(FSlots);
end;

function TJournalCandidatePool.CandidateAt(const ASlot: Integer): TJournalRepresentative;
begin
  if (ASlot < 0) or (ASlot >= Length(FSlots)) then
  begin
    raise EAudio.Create('Journal candidate slot out of bounds');
  end;
  Result := FSlots[ASlot];
end;

function TJournalCandidatePool.TokenAt(const ASlot: Integer): Integer;
begin
  CandidateAt(ASlot);
  Result := ASlot div (FSegmentCount * FBins);
end;

function TJournalCandidatePool.Select(const ATokens: TAcousticIndices;
  const AWeights: TJournalSelectionWeights; const ASeed: Integer;
  const AProgress: TWorkProgressCallback): TAcousticIndices;
var
  LStream: TJournalSelectionStream;
  LSelection: TAcousticIndices;
begin
  if (Length(ATokens) < 1) or (Length(ATokens) > MaximumJournalSelectionGrains) or
    (Length(AWeights) <> FSegmentCount) or (ASeed < 0) or
    (Int64(Length(ATokens)) * FSegmentCount * FBins > MaximumJournalSelectionVisits) then
  begin
    raise EAudio.Create('Journal selection geometry or work budget invalid');
  end;
  LStream := TJournalSelectionStream.Create(Self, AWeights, ASeed, nil, AProgress);
  try
    LSelection := LStream.SelectChunk(ATokens, AProgress);
  finally
    LStream.Free;
  end;
  Result := LSelection;
end;

constructor TJournalSourceSuccessors.Create(const AReader: TJournalTrainingReader;
  const APalette: TAcousticPalette; const AProgress: TWorkProgressCallback);
var
  LSegment: TJournalTrainingSegment;
  LObservation: TJournalTrainingObservation;
  LIndex: Integer;
  LOffset: Integer;
  LNode: Integer;
  LRead: Integer;
begin
  inherited Create;
  if (AReader = nil) or (APalette = nil) or
    (AReader.ObservationCount < 1) or
    (AReader.ObservationCount > MaximumJournalSuccessorObservations) then
  begin
    raise EAudio.Create('Successor index requires reader, palette and bounded observations');
  end;
  FTokenCount := APalette.Count;
  SetLength(FSources, AReader.SegmentCount);
  LOffset := 0;
  ReportWork(AProgress, 'successor_sources', wuItems, 0, AReader.SegmentCount);
  for LIndex := 0 to AReader.SegmentCount - 1 do
  begin
    LSegment := AReader.SegmentAt(LIndex);
    FSources[LIndex].Geometry.Binding := LSegment.Journal.Binding;
    FSources[LIndex].Geometry.FirstFeature := LSegment.FirstFeature;
    FSources[LIndex].Geometry.FeatureCount := LSegment.FeatureCount;
    FSources[LIndex].NodeOffset := LOffset;
    Inc(LOffset, Integer(LSegment.FeatureCount));
    ReportWork(AProgress, 'successor_sources', wuItems, LIndex + 1, AReader.SegmentCount);
  end;
  FHopFrames := FSources[0].Geometry.Binding.Options.HopFrames;
  FWindowFrames := FSources[0].Geometry.Binding.Options.WindowFrames;
  FVocabularySha256 := AcousticVocabularySha256(APalette,
    FSources[0].Geometry.Binding.Options, FSources[0].Geometry.Binding.SampleRate,
    FSources[0].Geometry.Binding.Channels);
  SetLength(FNodes, Integer(AReader.ObservationCount));
  AReader.Rewind;
  LRead := 0;
  ReportWork(AProgress, 'successor_observations', wuObservations, 0, AReader.ObservationCount);
  while AReader.ReadObservation(LObservation, AProgress) do
  begin
    LNode := FSources[LObservation.SegmentIndex].NodeOffset +
      Integer(LObservation.FeatureIndex -
        FSources[LObservation.SegmentIndex].Geometry.FirstFeature);
    FNodes[LNode].Token := APalette.EncodeFeature(LObservation.Feature);
    FNodes[LNode].Distance := APalette.FeatureDistance(LObservation.Feature,
      FNodes[LNode].Token);
    Inc(LRead);
    if LRead mod 128 = 0 then
    begin
      ReportWork(AProgress, 'successor_observations', wuObservations, LRead, AReader.ObservationCount);
    end;
  end;
  if (LRead <> Length(FNodes)) or (LOffset <> Length(FNodes)) then
  begin
    raise EAudio.Create('Successor index did not consume every declared observation');
  end;
  ReportWork(AProgress, 'successor_observations', wuObservations, LRead, AReader.ObservationCount);
  ReportWork(AProgress, 'successor_index_ready', wuItems, 1, 1);
end;

function TJournalSourceSuccessors.GetSourceCount: Integer;
begin
  Result := Length(FSources);
end;

function TJournalSourceSuccessors.GetObservationCount: Integer;
begin
  Result := Length(FNodes);
end;

function TJournalSourceSuccessors.GetNativeStorageBytes: Int64;
{$ifdef pas2js}
begin
  raise EAudio.Create('Static native successor storage size is unavailable on pas2js');
end;
{$else}
var
  LSource: TSource;
begin
  Result := Int64(Length(FNodes)) * SizeOf(TNode) +
    Int64(Length(FSources)) * SizeOf(TSource) + Length(FVocabularySha256);
  for LSource in FSources do
  begin
    Inc(Result, Length(LSource.Geometry.Binding.SourceSha256));
  end;
end;
{$endif}

function TJournalSourceSuccessors.SourceAt(const AIndex: Integer): TJournalSuccessorSource;
begin
  if (AIndex < 0) or (AIndex >= SourceCount) then
  begin
    raise EAudio.Create('Successor source index out of bounds');
  end;
  Result := FSources[AIndex].Geometry;
end;

function TJournalSourceSuccessors.NodeAt(const ACandidate: TJournalRepresentative): Integer;
var
  LSource: TSource;
  LOffset: Int64;
begin
  Result := -1;
  if not ACandidate.Found or (ACandidate.SegmentIndex < 0) or
    (ACandidate.SegmentIndex >= SourceCount) then
  begin
    Exit;
  end;
  LSource := FSources[ACandidate.SegmentIndex];
  if (ACandidate.FeatureIndex < LSource.Geometry.FirstFeature) or
    (ACandidate.FeatureIndex >= LSource.Geometry.FirstFeature + LSource.Geometry.FeatureCount) or
    (ACandidate.SourceFrame < 0) or
    (ACandidate.SourceFrame >= LSource.Geometry.Binding.FrameCount) then
  begin
    Exit;
  end;
  LOffset := ACandidate.FeatureIndex - LSource.Geometry.FirstFeature;
  if (ACandidate.SourceFrame mod FHopFrames <> 0) or
    (ACandidate.SourceFrame div FHopFrames <> ACandidate.FeatureIndex) or
    (ACandidate.ValidFrames <> Min(Int64(FWindowFrames),
      LSource.Geometry.Binding.FrameCount - ACandidate.SourceFrame)) then
  begin
    Exit;
  end;
  Result := LSource.NodeOffset + Integer(LOffset);
end;

procedure TJournalSourceSuccessors.RequireCompatible(const APool: TJournalCandidatePool;
  const AProgress: TWorkProgressCallback);
var
  LSlot: Integer;
  LNode: Integer;
  LCandidate: TJournalRepresentative;
begin
  if (APool = nil) or (APool.FTokenCount <> FTokenCount) or
    (APool.SegmentCount <> SourceCount) then
  begin
    raise EAudio.Create('Successor index and fallback pool geometry differ');
  end;
  ReportWork(AProgress, 'journal_successor_compatibility', wuItems, 0, APool.SlotCount);
  for LSlot := 0 to APool.SlotCount - 1 do
  begin
    LCandidate := APool.CandidateAt(LSlot);
    if LCandidate.Found then
    begin
      LNode := NodeAt(LCandidate);
      if (LNode < 0) or (FNodes[LNode].Token <> APool.TokenAt(LSlot)) then
      begin
        raise EAudio.Create('Fallback candidate differs from its observed successor index');
      end;
    end;
    if ((LSlot + 1) and 255) = 0 then
    begin
      ReportWork(AProgress, 'journal_successor_compatibility', wuItems,
        LSlot + 1, APool.SlotCount);
    end;
  end;
  ReportWork(AProgress, 'journal_successor_compatibility', wuItems,
    APool.SlotCount, APool.SlotCount);
end;

function TJournalSourceSuccessors.Select(const APrevious,
  AFallback: TJournalRepresentative; const ARequestedToken: Integer): TJournalRepresentative;
var
  LNode: Integer;
  LNext: Integer;
  LSource: TSource;
  LCandidate: TJournalRepresentative;
begin
  LNode := NodeAt(AFallback);
  if (LNode < 0) or (FNodes[LNode].Token <> ARequestedToken) then
  begin
    raise EAudio.Create('Successor fallback does not match its requested observed token');
  end;
  Result := AFallback;
  if not APrevious.Found then
  begin
    Exit;
  end;
  LNode := NodeAt(APrevious);
  if LNode < 0 then
  begin
    raise EAudio.Create('Previous successor window leaves its declared source range');
  end;
  if APrevious.SegmentIndex <> AFallback.SegmentIndex then
  begin
    Exit;
  end;
  LSource := FSources[APrevious.SegmentIndex];
  LNext := LNode + 1;
  if LNext >= LSource.NodeOffset + LSource.Geometry.FeatureCount then
  begin
    Exit;
  end;
  LCandidate := Default(TJournalRepresentative);
  LCandidate.Found := True;
  LCandidate.SegmentIndex := APrevious.SegmentIndex;
  LCandidate.FeatureIndex := APrevious.FeatureIndex + 1;
  LCandidate.SourceFrame := LCandidate.FeatureIndex * FHopFrames;
  LCandidate.ValidFrames := Integer(Min(Int64(FWindowFrames),
    LSource.Geometry.Binding.FrameCount - LCandidate.SourceFrame));
  LCandidate.Distance := FNodes[LNext].Distance;
  if IsExactSourceSuccessor(APrevious.SegmentIndex, LCandidate.SegmentIndex,
    FNodes[LNext].Token, ARequestedToken, APrevious.SourceFrame,
    LCandidate.SourceFrame, FHopFrames) then
  begin
    Result := LCandidate;
  end;
end;

constructor TJournalSelectionStream.Create(const APool: TJournalCandidatePool;
  const AWeights: TJournalSelectionWeights; const ASeed: Integer;
  const ASuccessors: TJournalSourceSuccessors; const AProgress: TWorkProgressCallback);
var
  LIndex: Integer;
  LVisits: Int64;
begin
  inherited Create;
  if (APool = nil) or (ASeed < 0) then
  begin
    raise EAudio.Create('Journal selection stream requires a pool and nonnegative seed');
  end;
  if Length(AWeights) <> APool.FSegmentCount then
  begin
    raise EAudio.Create('Journal selection stream weights disagree with segments');
  end;
  FWeights := Copy(AWeights);
  LVisits := 0;
  ReportWork(AProgress, 'journal_select_prepare', wuItems, 0, 0);
  for LIndex := 0 to High(FWeights) do
  begin
    if (FWeights[LIndex] < 0) or (FWeights[LIndex] > 4096) then
    begin
      raise EAudio.Create('Journal selection weights must be 0..4096');
    end;
    SelectionVisit(LVisits, 'journal_select_prepare', AProgress);
  end;
  FPool := APool;
  if ASuccessors <> nil then
  begin
    ASuccessors.RequireCompatible(APool, AProgress);
  end;
  FSuccessors := ASuccessors;
  FPreviousWindow := Default(TJournalRepresentative);
  SetLength(FCredits, APool.FSegmentCount);
  SetLength(FCursors, APool.FTokenCount * APool.FSegmentCount);
  for LIndex := 0 to High(FCursors) do
  begin
    FCursors[LIndex] := (Int64(ASeed) + LIndex) mod APool.FBins;
    SelectionVisit(LVisits, 'journal_select_prepare', AProgress);
  end;
  FPrevious := -1;
  ReportWork(AProgress, 'journal_select_prepare', wuItems, LVisits, LVisits);
end;

function TJournalSelectionStream.PrepareChunk(const ATokens: TAcousticIndices;
  const AWindows: Boolean; const AProgress: TWorkProgressCallback): TSelectionCandidate;
var
  LTokens: TAcousticIndices;
  LEligible: array of Boolean;
  LIndex: Integer;
  LSegment: Integer;
  LBin: Integer;
  LBase: Integer;
  LSlot: Integer;
  LSelected: Integer;
  LChosen: Integer;
  LCursor: Integer;
  LTotalWeight: Int64;
  LWork: Int64;
  LVisits: Int64;
begin
  LWork := Int64(Length(ATokens)) * FPool.FSegmentCount * FPool.FBins;
  if (Length(ATokens) < 1) or
    (Length(ATokens) > MaximumJournalSelectionGrains) or
    (LWork > MaximumJournalSelectionVisits) or
    (LWork > High(Int64) - FSelectionVisits) or
    (FSelectedCount > High(Int64) - Length(ATokens)) then
  begin
    raise EAudio.Create('Journal selection stream chunk or work budget invalid');
  end;
  LTokens := Copy(ATokens);
  LVisits := 0;
  ReportWork(AProgress, 'journal_select_visits', wuItems, 0, 0);
  for LIndex := 0 to High(LTokens) do
  begin
    if (LTokens[LIndex] < 0) or (LTokens[LIndex] >= FPool.FTokenCount) then
    begin
      raise EAudio.Create('Journal selection token out of bounds');
    end;
    SelectionVisit(LVisits, 'journal_select_visits', AProgress);
  end;
  Result := Default(TSelectionCandidate);
  Result.Credits := Copy(FCredits);
  Result.Cursors := Copy(FCursors);
  Result.Previous := FPrevious;
  Result.PreviousWindow := FPreviousWindow;
  Result.SelectedCount := FSelectedCount + Length(LTokens);
  Result.SelectionVisits := FSelectionVisits + LWork;
  SetLength(LEligible, FPool.FSegmentCount);
  SetLength(Result.Slots, Length(LTokens));
  for LIndex := 0 to High(LTokens) do
  begin
    LTotalWeight := 0;
    LSelected := -1;
    for LSegment := 0 to FPool.FSegmentCount - 1 do
    begin
      SelectionVisit(LVisits, 'journal_select_visits', AProgress);
      LEligible[LSegment] := False;
      LBase := (LTokens[LIndex] * FPool.FSegmentCount + LSegment) * FPool.FBins;
      if FWeights[LSegment] > 0 then
      begin
        for LBin := 0 to FPool.FBins - 1 do
        begin
          SelectionVisit(LVisits, 'journal_select_visits', AProgress);
          if FPool.FSlots[LBase + LBin].Found then
          begin
            LEligible[LSegment] := True;
            Break;
          end;
        end;
      end;
      if LEligible[LSegment] then
      begin
        Inc(LTotalWeight, FWeights[LSegment]);
        Inc(Result.Credits[LSegment], FWeights[LSegment]);
        if (LSelected < 0) or (Result.Credits[LSegment] > Result.Credits[LSelected]) then
        begin
          LSelected := LSegment;
        end;
      end;
    end;
    if LSelected < 0 then
    begin
      raise EAudio.Create('Generated token has no candidate in an enabled segment');
    end;
    Dec(Result.Credits[LSelected], LTotalWeight);
    LCursor := LTokens[LIndex] * FPool.FSegmentCount + LSelected;
    LBase := LCursor * FPool.FBins;
    LChosen := -1;
    for LBin := 0 to FPool.FBins - 1 do
    begin
      SelectionVisit(LVisits, 'journal_select_visits', AProgress);
      LSlot := LBase + (Result.Cursors[LCursor] + LBin) mod FPool.FBins;
      if FPool.FSlots[LSlot].Found then
      begin
        LChosen := LSlot;
        if LSlot <> Result.Previous then
        begin
          Break;
        end;
      end;
    end;
    Result.Slots[LIndex] := LChosen;
    Result.Cursors[LCursor] := (LChosen - LBase + 1) mod FPool.FBins;
    Result.Previous := LChosen;
  end;
  if AWindows then
  begin
    SetLength(Result.Windows, Length(Result.Slots));
    for LIndex := 0 to High(Result.Slots) do
    begin
      Result.Windows[LIndex] := FPool.CandidateAt(Result.Slots[LIndex]);
      if FSuccessors <> nil then
      begin
        Result.Windows[LIndex] := FSuccessors.Select(Result.PreviousWindow,
          Result.Windows[LIndex], LTokens[LIndex]);
      end;
      Result.PreviousWindow := Result.Windows[LIndex];
      SelectionVisit(LVisits, 'journal_select_visits', AProgress);
    end;
  end;
  ReportWork(AProgress, 'journal_select_visits', wuItems, LVisits, LVisits);
end;

procedure TJournalSelectionStream.CommitCandidate(const ACandidate: TSelectionCandidate);
begin
  FCredits := ACandidate.Credits;
  FCursors := ACandidate.Cursors;
  FPrevious := ACandidate.Previous;
  FSelectedCount := ACandidate.SelectedCount;
  FSelectionVisits := ACandidate.SelectionVisits;
  FPreviousWindow := ACandidate.PreviousWindow;
end;

function TJournalSelectionStream.SelectChunk(const ATokens: TAcousticIndices;
  const AProgress: TWorkProgressCallback): TAcousticIndices;
var
  LCandidate: TSelectionCandidate;
begin
  if FSelecting then
  begin
    raise EAudio.Create('Journal selection cannot reenter an active selection');
  end;
  FSelecting := True;
  try
    LCandidate := PrepareChunk(ATokens, False, AProgress);
    CommitCandidate(LCandidate);
    Result := LCandidate.Slots;
  finally
    FSelecting := False;
  end;
end;

function TJournalSelectionStream.SelectWindowsChunk(const ATokens: TAcousticIndices;
  const AProgress: TWorkProgressCallback): TJournalRepresentatives;
var
  LCandidate: TSelectionCandidate;
begin
  if FSelecting then
  begin
    raise EAudio.Create('Journal selection cannot reenter an active selection');
  end;
  FSelecting := True;
  try
    LCandidate := PrepareChunk(ATokens, True, AProgress);
    CommitCandidate(LCandidate);
    Result := LCandidate.Windows;
  finally
    FSelecting := False;
  end;
end;


end.
