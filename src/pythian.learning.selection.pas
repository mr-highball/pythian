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
  pythian.learning,
  pythian.learning.journal;

const
  MaximumJournalCandidateSlots = 65536;
  MaximumJournalSelectionGrains = 4096;
  MaximumJournalSelectionVisits = 64000000;

type
  TJournalSelectionWeights = array of Integer;
  TJournalWindowRead = function(const ACandidate: TJournalRepresentative): TAudioSamples of object;

  { Copies coordinates only; the reader and palette are borrowed during construction.
    Each token/segment has up to 32 temporal bins, with its nearest assigned
    observation retained in each bin. No whole recording or feature array is kept.
    Keep the original source/palette bindings with this pool. }
  TJournalCandidatePool = class
  private
    FSlots: TJournalRepresentatives;
    FTokenCount: Integer;
    FSegmentCount: Integer;
    FBins: Integer;
    function GetSlotCount: Integer;
  public
    constructor Create(const AReader: TJournalTrainingReader;
      const APalette: TAcousticPalette; const ABinsPerSegment: Integer = 4);
    { Restores detached slots without learning. Validates slot geometry only;
      the caller must bind/validate source extents, timebase and palette identity. }
    constructor CreateFromCandidates(const ATokenCount, ASegmentCount,
      ABinsPerSegment: Integer; const ACandidates: TJournalRepresentatives);
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
      const ASeed: Integer = 731): TAcousticIndices;
    property SlotCount: Integer read GetSlotCount;
    property SegmentCount: Integer read FSegmentCount;
    property BinsPerSegment: Integer read FBins;
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
  pythian.granular;

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
  const APalette: TAcousticPalette; const ABinsPerSegment: Integer);
var
  LObservation: TJournalTrainingObservation;
  LSegment: TJournalTrainingSegment;
  LBinWidth: Int64;
  LToken: Integer;
  LBin: Integer;
  LSlot: Integer;
  LDistance: Double;
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
  while AReader.ReadObservation(LObservation) do
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
  end;
end;

constructor TJournalCandidatePool.CreateFromCandidates(const ATokenCount,
  ASegmentCount, ABinsPerSegment: Integer; const ACandidates: TJournalRepresentatives);
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
  for LSlot := 0 to High(FSlots) do
  begin
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
  const AWeights: TJournalSelectionWeights; const ASeed: Integer): TAcousticIndices;
var
  LCredits: array of Int64;
  LCursors: array of Integer;
  LEligible: array of Boolean;
  LIndex: Integer;
  LSegment: Integer;
  LBin: Integer;
  LBase: Integer;
  LSlot: Integer;
  LSelected: Integer;
  LChosen: Integer;
  LPrevious: Integer;
  LCursor: Integer;
  LTotalWeight: Int64;
begin
  if (Length(ATokens) < 1) or (Length(ATokens) > MaximumJournalSelectionGrains) or
    (Length(AWeights) <> FSegmentCount) or (ASeed < 0) or
    (Int64(Length(ATokens)) * FSegmentCount * FBins > MaximumJournalSelectionVisits) then
  begin
    raise EAudio.Create('Journal selection geometry or work budget invalid');
  end;
  for LSegment := 0 to High(AWeights) do
  begin
    if (AWeights[LSegment] < 0) or (AWeights[LSegment] > 4096) then
    begin
      raise EAudio.Create('Journal selection weights must be 0..4096');
    end;
  end;
  for LIndex := 0 to High(ATokens) do
  begin
    if (ATokens[LIndex] < 0) or (ATokens[LIndex] >= FTokenCount) then
    begin
      raise EAudio.Create('Journal selection token out of bounds');
    end;
  end;
  Result := nil;
  LCredits := nil;
  LCursors := nil;
  LEligible := nil;
  SetLength(Result, Length(ATokens));
  SetLength(LCredits, FSegmentCount);
  SetLength(LEligible, FSegmentCount);
  SetLength(LCursors, FTokenCount * FSegmentCount);
  for LIndex := 0 to High(LCursors) do
  begin
    LCursors[LIndex] := (Int64(ASeed) + LIndex) mod FBins;
  end;
  LPrevious := -1;
  for LIndex := 0 to High(ATokens) do
  begin
    LTotalWeight := 0;
    LSelected := -1;
    for LSegment := 0 to FSegmentCount - 1 do
    begin
      LEligible[LSegment] := False;
      LBase := (ATokens[LIndex] * FSegmentCount + LSegment) * FBins;
      if AWeights[LSegment] > 0 then
      begin
        for LBin := 0 to FBins - 1 do
        begin
          if FSlots[LBase + LBin].Found then
          begin
            LEligible[LSegment] := True;
            Break;
          end;
        end;
      end;
      if LEligible[LSegment] then
      begin
        Inc(LTotalWeight, AWeights[LSegment]);
        Inc(LCredits[LSegment], AWeights[LSegment]);
        if (LSelected < 0) or (LCredits[LSegment] > LCredits[LSelected]) then
        begin
          LSelected := LSegment;
        end;
      end;
    end;
    if LSelected < 0 then
    begin
      raise EAudio.Create('Generated token has no candidate in an enabled segment');
    end;
    Dec(LCredits[LSelected], LTotalWeight);
    LCursor := ATokens[LIndex] * FSegmentCount + LSelected;
    LBase := LCursor * FBins;
    LChosen := -1;
    for LBin := 0 to FBins - 1 do
    begin
      LSlot := LBase + (LCursors[LCursor] + LBin) mod FBins;
      if FSlots[LSlot].Found then
      begin
        LChosen := LSlot;
        if LSlot <> LPrevious then
        begin
          Break;
        end;
      end;
    end;
    Result[LIndex] := LChosen;
    LCursors[LCursor] := (LChosen - LBase + 1) mod FBins;
    LPrevious := LChosen;
  end;
end;

end.
