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

unit pythian.learning.journal;

{$mode delphi}
{$H+}

interface

uses
  pythian.analysis,
  pythian.analysis.wave,
  pythian.analysis.journal,
  pythian.learning;

const
  MaximumJournalTrainingSegments = 4096;

type
  TJournalTrainingSegment = record
    Journal: TFeatureJournal;
    FirstFeature: Int64;
    FeatureCount: Int64;
    Multiplicity: Integer;
  end;
  TJournalTrainingSegments = array of TJournalTrainingSegment;

  TJournalPartition = (jpTraining, jpDevelopment, jpEvaluation);
  TJournalPartitionEntry = record
    Segment: TJournalTrainingSegment;
    GroupId: UTF8String;
    Partition: TJournalPartition;
    GroupVerified: Boolean;
    PreviouslyUsed: Boolean;
  end;
  TJournalPartitionPlan = array of TJournalPartitionEntry;

  TJournalTrainingObservation = record
    SegmentIndex: Integer;
    FeatureIndex: Int64;
    SourceFrame: Int64;
    { Measurement window starts at SourceFrame; its local StartFrame is zero. }
    Feature: TAudioFeature;
    Multiplicity: Integer;
  end;

  TJournalRepresentative = record
    Found: Boolean;
    SegmentIndex: Integer;
    FeatureIndex: Int64;
    SourceFrame: Int64;
    ValidFrames: Integer;
    Distance: Double;
  end;
  TJournalRepresentatives = array of TJournalRepresentative;

  TJournalPaletteFit = record
    ObservationCount: Int64;
    WeightedObservationCount: Int64;
    NonSilentCount: Int64;
    MeanSquaredDistance: Double;
    NonSilentMeanSquaredDistance: Double;
    MaximumSquaredDistance: Double;
    WithinLimitCount: Int64;
    TokenCounts: array[0..MaximumAcousticVocabulary - 1] of Int64;
    OccupiedTokens: Integer;
    EffectiveTokens: Double;
    SelfTransitions: Int64;
    LongestRun: Int64;
  end;
  TJournalPaletteFits = array of TJournalPaletteFit;

  { Borrows completed immutable journals. Segments are declared recording/song
    boundaries, never storage batches. Overlapping source ranges reject;
    explicit positive whole-segment multiplicity supplies observation weight.
    All segments share the same rate/channel/analysis contract.
    Rewind and reads control the journals' cursors; do not interleave readers. }
  TJournalTrainingReader = class(TAcousticVectorReader)
  private
    FSegments: TJournalTrainingSegments;
    FSegment: Integer;
    FBatch: TWaveFeatureBatch;
    FBatchIndex: Integer;
    FEmitted: Int64;
    FObservations: Int64;
    FWeightedObservations: Int64;
    FFailed: Boolean;
    function GetSegmentCount: Integer;
  public
    constructor Create(const ASegments: TJournalTrainingSegments);
    procedure Rewind; override;
    function ReadObservation(var AObservation: TJournalTrainingObservation): Boolean;
    function ReadVector(var AVector: TAcousticVector;
      var AMultiplicity: Integer): Boolean; override;
    function SegmentAt(const AIndex: Integer): TJournalTrainingSegment;
    property SegmentCount: Integer read GetSegmentCount;
    property ObservationCount: Int64 read FObservations;
    property WeightedObservationCount: Int64 read FWeightedObservations;
  end;

function WholeJournalSegment(const AJournal: TFeatureJournal;
  const AMultiplicity: Integer = 1): TJournalTrainingSegment;
{ Opt-in selection validates the ENTIRE plan against the reader's shared
  analysis, range, overlap and mass limits before returning detached segments.
  Groups are caller-declared recording families, exact case-sensitive IDs of
  1..256 bytes without surrounding whitespace. Unknown groups are development
  only; previously used groups cannot evaluate. A group or exact source hash
  cannot cross partitions, and one hash cannot have different group IDs or
  source geometry. Different derivatives still require caller duplicate and
  parent-range auditing; hashes/flags do not prove musical independence.
  Empty selections reject. Journals are borrowed, never read or rewound here. }
function SelectJournalPartition(const APlan: TJournalPartitionPlan;
  const APartition: TJournalPartition): TJournalTrainingSegments;
{ One nearest assigned observation per token; unoccupied centers remain unfound.
  Coordinates retain the source identity through the reader's segment binding. }
function FindJournalRepresentatives(const AReader: TJournalTrainingReader;
  const APalette: TAcousticPalette): TJournalRepresentatives;

{ One read pass, detached statistics per declared segment, no learning or model
  mutation. Limit is an explicit squared distance in the current 15-component
  acoustic vector space, finite in [0,15], not musical confidence. Counts and
  errors use distinct observations; multiplicity is reported separately. Runs
  reset at segment boundaries, never storage batches. NonSilentCount=0 means
  absent nonsilent evidence, not an established zero-error fit. Reader is
  borrowed/rewound; callers retain source identity and evaluation protocol. }
function MeasureJournalPaletteFit(const AReader: TJournalTrainingReader;
  const APalette: TAcousticPalette; const AMaximumSquaredDistance: Double): TJournalPaletteFits;

implementation

uses
  SysUtils,
  Math,
  pythian.audio;

function MeasureJournalPaletteFit(const AReader: TJournalTrainingReader;
  const APalette: TAcousticPalette; const AMaximumSquaredDistance: Double): TJournalPaletteFits;
var
  LFits: TJournalPaletteFits;
  LPrevious: array of Integer;
  LRuns: array of Int64;
  LObservation: TJournalTrainingObservation;
  LSegment: TJournalTrainingSegment;
  LIndex: Integer;
  LToken: Integer;
  LDistance: Double;
  LShare: Double;
  LEntropy: Double;
begin
  RequireFinite(AMaximumSquaredDistance, 'Palette fit squared-distance limit');
  if (AReader = nil) or (APalette = nil) or
    (AMaximumSquaredDistance < 0) or (AMaximumSquaredDistance > 15) then
  begin
    raise EAudio.Create('Palette fit requires a reader, palette and distance limit in 0..15');
  end;
  LFits := nil;
  SetLength(LFits, AReader.SegmentCount);
  SetLength(LPrevious, AReader.SegmentCount);
  SetLength(LRuns, AReader.SegmentCount);
  for LIndex := 0 to High(LPrevious) do
  begin
    LPrevious[LIndex] := -1;
  end;
  AReader.Rewind;
  while AReader.ReadObservation(LObservation) do
  begin
    LIndex := LObservation.SegmentIndex;
    LToken := APalette.EncodeFeature(LObservation.Feature);
    LDistance := APalette.FeatureDistance(LObservation.Feature, LToken);
    Inc(LFits[LIndex].ObservationCount);
    Inc(LFits[LIndex].WeightedObservationCount, LObservation.Multiplicity);
    Inc(LFits[LIndex].TokenCounts[LToken]);
    LFits[LIndex].MeanSquaredDistance := LFits[LIndex].MeanSquaredDistance + LDistance;
    LFits[LIndex].MaximumSquaredDistance := Max(LFits[LIndex].MaximumSquaredDistance, LDistance);
    if not LObservation.Feature.Silent then
    begin
      Inc(LFits[LIndex].NonSilentCount);
      LFits[LIndex].NonSilentMeanSquaredDistance :=
        LFits[LIndex].NonSilentMeanSquaredDistance + LDistance;
    end;
    if LDistance <= AMaximumSquaredDistance then
    begin
      Inc(LFits[LIndex].WithinLimitCount);
    end;
    if LToken = LPrevious[LIndex] then
    begin
      Inc(LRuns[LIndex]);
      Inc(LFits[LIndex].SelfTransitions);
    end
    else
    begin
      LRuns[LIndex] := 1;
    end;
    LPrevious[LIndex] := LToken;
    LFits[LIndex].LongestRun := Max(LFits[LIndex].LongestRun, LRuns[LIndex]);
  end;
  for LIndex := 0 to High(LFits) do
  begin
    LSegment := AReader.SegmentAt(LIndex);
    if (LFits[LIndex].ObservationCount <> LSegment.FeatureCount) or
      (LFits[LIndex].WeightedObservationCount <>
       LSegment.FeatureCount * Int64(LSegment.Multiplicity)) then
    begin
      raise EAudio.Create('Palette fit did not read the complete declared segment');
    end;
    LFits[LIndex].MeanSquaredDistance :=
      LFits[LIndex].MeanSquaredDistance / LFits[LIndex].ObservationCount;
    if LFits[LIndex].NonSilentCount > 0 then
    begin
      LFits[LIndex].NonSilentMeanSquaredDistance :=
        LFits[LIndex].NonSilentMeanSquaredDistance / LFits[LIndex].NonSilentCount;
    end;
    LEntropy := 0;
    for LToken := 0 to APalette.Count - 1 do
    begin
      if LFits[LIndex].TokenCounts[LToken] > 0 then
      begin
        Inc(LFits[LIndex].OccupiedTokens);
        LShare := LFits[LIndex].TokenCounts[LToken] / LFits[LIndex].ObservationCount;
        LEntropy := LEntropy - LShare * Ln(LShare);
      end;
    end;
    LFits[LIndex].EffectiveTokens := Exp(LEntropy);
  end;
  Result := LFits;
end;

function FindJournalRepresentatives(const AReader: TJournalTrainingReader;
  const APalette: TAcousticPalette): TJournalRepresentatives;
var
  LObservation: TJournalTrainingObservation;
  LToken: Integer;
  LDistance: Double;
begin
  if (AReader = nil) or (APalette = nil) then
  begin
    raise EAudio.Create('Representative search requires a reader and palette');
  end;
  Result := nil;
  SetLength(Result, APalette.Count);
  for LToken := 0 to High(Result) do
  begin
    Result[LToken].Distance := MaxDouble;
  end;
  AReader.Rewind;
  while AReader.ReadObservation(LObservation) do
  begin
    LToken := APalette.EncodeFeature(LObservation.Feature);
    LDistance := APalette.FeatureDistance(LObservation.Feature, LToken);
    if LDistance < Result[LToken].Distance then
    begin
      Result[LToken].Found := True;
      Result[LToken].SegmentIndex := LObservation.SegmentIndex;
      Result[LToken].FeatureIndex := LObservation.FeatureIndex;
      Result[LToken].SourceFrame := LObservation.SourceFrame;
      Result[LToken].ValidFrames := LObservation.Feature.ValidFrames;
      Result[LToken].Distance := LDistance;
    end;
  end;
end;

function WholeJournalSegment(const AJournal: TFeatureJournal;
  const AMultiplicity: Integer): TJournalTrainingSegment;
begin
  if AJournal = nil then
  begin
    raise EAudio.Create('Training journal is required');
  end;
  Result.Journal := AJournal;
  Result.FirstFeature := 0;
  Result.FeatureCount := AJournal.TotalFeatures;
  Result.Multiplicity := AMultiplicity;
end;

function SelectJournalPartition(const APlan: TJournalPartitionPlan;
  const APartition: TJournalPartition): TJournalTrainingSegments;
var
  LSegments: TJournalTrainingSegments;
  LSelected: TJournalTrainingSegments;
  LValidator: TJournalTrainingReader;
  LBinding: TFeatureJournalBinding;
  LPrevious: TFeatureJournalBinding;
  LIndex: Integer;
  LOther: Integer;
  LCount: Integer;
begin
  if (Ord(APartition) < Ord(Low(TJournalPartition))) or
    (Ord(APartition) > Ord(High(TJournalPartition))) then
  begin
    raise EAudio.Create('Unknown journal partition');
  end;
  if (Length(APlan) < 1) or (Length(APlan) > MaximumJournalTrainingSegments) then
  begin
    raise EAudio.Create('Journal partition plan requires 1..4096 entries');
  end;
  SetLength(LSegments, Length(APlan));
  LCount := 0;
  for LIndex := 0 to High(APlan) do
  begin
    if (Length(APlan[LIndex].GroupId) < 1) or
      (Length(APlan[LIndex].GroupId) > 256) or
      (Trim(APlan[LIndex].GroupId) <> APlan[LIndex].GroupId) then
    begin
      raise EAudio.Create('Journal partition requires an explicit bounded group ID');
    end;
    if (Ord(APlan[LIndex].Partition) < Ord(Low(TJournalPartition))) or
      (Ord(APlan[LIndex].Partition) > Ord(High(TJournalPartition))) then
    begin
      raise EAudio.Create('Unknown journal plan partition');
    end;
    if not APlan[LIndex].GroupVerified and
      (APlan[LIndex].Partition <> jpDevelopment) then
    begin
      raise EAudio.Create('Unverified recording groups are development only');
    end;
    if APlan[LIndex].PreviouslyUsed and
      (APlan[LIndex].Partition = jpEvaluation) then
    begin
      raise EAudio.Create('Previously used recording groups cannot evaluate');
    end;
    LSegments[LIndex] := APlan[LIndex].Segment;
    if APlan[LIndex].Partition = APartition then
    begin
      Inc(LCount);
    end;
  end;
  { Reuse the reader's bounds and same-analysis contract without reading any
    observations. Its constructor's Rewind only resets its own local state. }
  LValidator := TJournalTrainingReader.Create(LSegments);
  LValidator.Free;
  for LIndex := 0 to High(APlan) do
  begin
    LBinding := LSegments[LIndex].Journal.Binding;
    for LOther := 0 to LIndex - 1 do
    begin
      if (APlan[LIndex].GroupId = APlan[LOther].GroupId) and
        (APlan[LIndex].Partition <> APlan[LOther].Partition) then
      begin
        raise EAudio.Create('Recording group crosses journal partitions');
      end;
      LPrevious := LSegments[LOther].Journal.Binding;
      if LBinding.SourceSha256 = LPrevious.SourceSha256 then
      begin
        if (APlan[LIndex].GroupId <> APlan[LOther].GroupId) or
          (LBinding.FrameCount <> LPrevious.FrameCount) then
        begin
          raise EAudio.Create('Same journal source has conflicting identity or geometry');
        end;
      end;
    end;
  end;
  if LCount = 0 then
  begin
    raise EAudio.Create('Requested journal partition is empty');
  end;
  LSelected := nil;
  SetLength(LSelected, LCount);
  LCount := 0;
  for LIndex := 0 to High(APlan) do
  begin
    if APlan[LIndex].Partition = APartition then
    begin
      LSelected[LCount] := LSegments[LIndex];
      Inc(LCount);
    end;
  end;
  Result := LSelected;
end;

constructor TJournalTrainingReader.Create(const ASegments: TJournalTrainingSegments);
const
  CMaximumExactMass = Int64(9007199254740991);
var
  LIndex: Integer;
  LOther: Integer;
  LBinding: TFeatureJournalBinding;
  LBase: TFeatureJournalBinding;
  LPrevious: TFeatureJournalBinding;
  LSegment: TJournalTrainingSegment;
  LMass: Int64;
begin
  inherited Create;
  if (Length(ASegments) < 1) or (Length(ASegments) > MaximumJournalTrainingSegments) then
  begin
    raise EAudio.Create('Journal training requires 1..4096 declared segments');
  end;
  for LIndex := 0 to High(ASegments) do
  begin
    LSegment := ASegments[LIndex];
    if LSegment.Journal = nil then
    begin
      raise EAudio.Create('Training segment requires a journal');
    end;
    if not LSegment.Journal.Completed or (LSegment.FirstFeature < 0) or
      (LSegment.FirstFeature >= LSegment.Journal.TotalFeatures) or
      (LSegment.FeatureCount < 1) or
      (LSegment.FeatureCount > LSegment.Journal.TotalFeatures - LSegment.FirstFeature) or
      (LSegment.Multiplicity < 1) then
    begin
      raise EAudio.Create('Training requires complete journals and valid nonempty segments');
    end;
    LBinding := LSegment.Journal.Binding;
    if LIndex = 0 then
    begin
      LBase := LBinding;
    end
    else if (LBinding.SampleRate <> LBase.SampleRate) or
      (LBinding.Channels <> LBase.Channels) or
      (LBinding.Options.WindowFrames <> LBase.Options.WindowFrames) or
      (LBinding.Options.HopFrames <> LBase.Options.HopFrames) or
      (LBinding.Options.SilenceRms <> LBase.Options.SilenceRms) then
    begin
      raise EAudio.Create('Journal training analysis and timebase contracts differ');
    end;
    for LOther := 0 to LIndex - 1 do
    begin
      LPrevious := ASegments[LOther].Journal.Binding;
      if (LBinding.SourceSha256 = LPrevious.SourceSha256) and
        (LSegment.FirstFeature < ASegments[LOther].FirstFeature + ASegments[LOther].FeatureCount) and
        (ASegments[LOther].FirstFeature < LSegment.FirstFeature + LSegment.FeatureCount) then
      begin
        raise EAudio.Create('Overlapping source observations require explicit multiplicity, not duplicate segments');
      end;
    end;
    if LSegment.FeatureCount > (CMaximumExactMass - FWeightedObservations) div
      LSegment.Multiplicity then
    begin
      raise EAudio.Create('Journal training weighted count exceeds exact mass budget');
    end;
    LMass := LSegment.FeatureCount * LSegment.Multiplicity;
    Inc(FWeightedObservations, LMass);
    Inc(FObservations, LSegment.FeatureCount);
  end;
  FSegments := Copy(ASegments);
  Rewind;
end;

procedure TJournalTrainingReader.Rewind;
begin
  if FFailed then
  begin
    raise EAudio.Create('Journal training reader failed; create a new reader');
  end;
  FSegment := -1;
  FBatch := Default(TWaveFeatureBatch);
  FBatchIndex := 0;
  FEmitted := 0;
end;

function TJournalTrainingReader.ReadObservation(
  var AObservation: TJournalTrainingObservation): Boolean;
var
  LSegment: TJournalTrainingSegment;
  LObservation: TJournalTrainingObservation;
  LIndex: Int64;
begin
  if FFailed then
  begin
    raise EAudio.Create('Journal training reader failed; create a new reader');
  end;
  try
    if FSegment >= Length(FSegments) then
    begin
      Exit(False);
    end;
    if (FSegment < 0) or (FEmitted = FSegments[FSegment].FeatureCount) then
    begin
      Inc(FSegment);
      if FSegment = Length(FSegments) then
      begin
        Exit(False);
      end;
      if not FSegments[FSegment].Journal.Completed then
      begin
        raise EAudio.Create('Training journal is no longer complete');
      end;
      FSegments[FSegment].Journal.Rewind;
      FBatch := Default(TWaveFeatureBatch);
      FBatchIndex := 0;
      FEmitted := 0;
    end;
    LSegment := FSegments[FSegment];
    while True do
    begin
      if FBatchIndex = Length(FBatch.Features) then
      begin
        if not LSegment.Journal.ReadNext(FBatch) then
        begin
          raise EAudio.Create('Training journal ended before its declared segment');
        end;
        FBatchIndex := 0;
      end;
      LIndex := FBatch.FirstFeature + FBatchIndex;
      if LIndex < LSegment.FirstFeature then
      begin
        Inc(FBatchIndex);
        Continue;
      end;
      if LIndex <> LSegment.FirstFeature + FEmitted then
      begin
        raise EAudio.Create('Journal training observation order differs');
      end;
      LObservation := Default(TJournalTrainingObservation);
      LObservation.SegmentIndex := FSegment;
      LObservation.FeatureIndex := LIndex;
      LObservation.SourceFrame := FBatch.SourceStartFrame + FBatch.Features[FBatchIndex].StartFrame;
      LObservation.Feature := FBatch.Features[FBatchIndex];
      LObservation.Feature.StartFrame := 0;
      LObservation.Multiplicity := LSegment.Multiplicity;
      Inc(FBatchIndex);
      Inc(FEmitted);
      AObservation := LObservation;
      Exit(True);
    end;
  except
    FFailed := True;
    raise;
  end;
end;

function TJournalTrainingReader.ReadVector(var AVector: TAcousticVector;
  var AMultiplicity: Integer): Boolean;
var
  LObservation: TJournalTrainingObservation;
begin
  Result := ReadObservation(LObservation);
  if Result then
  begin
    AVector := AcousticVector(LObservation.Feature);
    AMultiplicity := LObservation.Multiplicity;
  end;
end;

function TJournalTrainingReader.GetSegmentCount: Integer;
begin
  Result := Length(FSegments);
end;

function TJournalTrainingReader.SegmentAt(const AIndex: Integer): TJournalTrainingSegment;
begin
  if (AIndex < 0) or (AIndex >= Length(FSegments)) then
  begin
    raise EAudio.Create('Training segment index out of bounds');
  end;
  Result := FSegments[AIndex];
end;

end.
