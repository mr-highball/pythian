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
unit pythian.pitch.regions;

{$mode delphi}
{$H+}

interface

uses
  pythian.pitch.track;

const
  MaximumPitchRegions = 4096;

type
  TPitchRegion = record
    StartFrame: Integer;
    EndFrame: Integer;
  end;
  TPitchRegions = array of TPitchRegion;
  TPitchRegionOptions = record
    MinimumPeriodicWindows: Integer;
    MinimumPeriodicCoverage: Double;
    MinimumEnergyShare: Double;
    MaximumMeanCents: Double;
  end;
  TPitchRegionDecision = (prdNoWindows, prdInsufficientPeriodicity,
    prdInsufficientCoverage, prdAmbiguousPitch, prdOutsideTuning, prdAdmitted);
  TPitchRegionVote = record
    Note: Integer;
    WindowCount: Integer;
    { Extent of this note's supporting center-aligned hop bins, clipped to the
      region. It may enclose gaps and is not a physical attack/release estimate. }
    SupportStartFrame: Integer;
    SupportEndFrame: Integer;
    EnergyShare: Double;
    MeanCents: Double;
    CentsDeviation: Double;
  end;
  TPitchRegionVotes = array of TPitchRegionVote;
  TPitchRegionSummary = record
    Region: TPitchRegion;
    WindowCount: Integer;
    PeriodicWindows: Integer;
    RawAdmittedWindows: Integer;
    PeriodicCoverage: Double;
    Votes: TPitchRegionVotes;
    CandidateNote: Integer;
    Note: Integer; { -1 unless admitted; never implies silence. }
    Decision: TPitchRegionDecision;
  end;
  TPitchRegionSummaries = array of TPitchRegionSummary;
  TPitchBoundaryOptions = record
    ContextFrames: Integer;
    GapFrames: Integer;
    Regions: TPitchRegionOptions;
  end;
  TPitchBoundarySummary = record
    Frame: Integer;
    CompleteContext: Boolean;
    Left: TPitchRegionSummary;
    Right: TPitchRegionSummary;
    LocalWindows: Integer;
    UnresolvedWindows: Integer;
    Qualified: Boolean;
  end;

function DefaultPitchRegionOptions: TPitchRegionOptions;
{ Defaults: 80-ms context on each side, excluding the inner 20 ms, and the
  existing region admission policy. All coordinates use the track's rate. }
function DefaultPitchBoundaryOptions(const ASampleRate: Integer): TPitchBoundaryOptions;
{ Summarize evidence around a caller-supplied boundary candidate. Both sides
  must admit a pitch; qualification requires different notes or a central
  silence/no-period estimate. This is a contextual cue, not proof of an attack,
  release, rest, voice identity or calibrated confidence. Missing outer context
  returns CompleteContext=False and unknown sides; no clipped query is invented.
  Side windows are half-open; central window centers include both gap endpoints.
  Frame may be either clip endpoint; invalid frames/options reject even when
  context would be incomplete. The track is borrowed and unchanged; returned
  side votes are detached. Work is bounded by the existing track window limit. }
function SummarizePitchBoundary(const ATrack: TPitchTrack; const AFrame: Integer;
  const AOptions: TPitchBoundaryOptions): TPitchBoundarySummary;
{ Keep the candidate attack, and end at the last supporting pitch bin plus
  caller-supplied padding, clipped to the original interval. This is an inferred
  gate, not proof of physical release or silence. Unknown summaries reject.
  Keep the detached summary unchanged while this function borrows it. }
function GatePitchRegion(const ASummary: TPitchRegionSummary;
  const AEndPaddingFrames: Integer = 0): TPitchRegion;
{ Summarize raw periodic evidence inside caller-supplied, nonoverlapping regions.
  Each window belongs to the region containing its center. Regions may leave gaps.
  RMS-squared weighting ranks equal-tempered notes; tuning is assessed on the
  weighted mean within the winning note, retaining deviation and every note vote.
  Periodic windows outside per-window tuning admission can still contribute.
  This is a separate region inference: it never rewrites raw track estimates.
  A region must represent one candidate musical event. This function discovers
  neither its boundaries nor voice ownership, and does not join adjacent regions.
  Dominance is observed support, not a calibrated probability.
  Inputs remain borrowed; the returned summaries and vote arrays are detached. }
function SummarizePitchRegions(const ATrack: TPitchTrack;
  const ARegions: TPitchRegions; const AOptions: TPitchRegionOptions): TPitchRegionSummaries;

implementation

uses
  Math,
  pythian.audio,
  pythian.pitch;

function DefaultPitchRegionOptions: TPitchRegionOptions;
begin
  Result.MinimumPeriodicWindows := 3;
  Result.MinimumPeriodicCoverage := 0.5;
  Result.MinimumEnergyShare := 0.75;
  Result.MaximumMeanCents := 25;
end;

procedure ValidatePitchRegionOptions(const AOptions: TPitchRegionOptions);
begin
  RequireFinite(AOptions.MinimumPeriodicCoverage, 'Region periodic coverage');
  RequireFinite(AOptions.MinimumEnergyShare, 'Region pitch energy share');
  RequireFinite(AOptions.MaximumMeanCents, 'Region mean tuning tolerance');
  if (AOptions.MinimumPeriodicWindows < 1) or
    (AOptions.MinimumPeriodicWindows > MaximumPitchTrackWindows) or
    (AOptions.MinimumPeriodicCoverage < 0) or (AOptions.MinimumPeriodicCoverage > 1) or
    (AOptions.MinimumEnergyShare <= 0.5) or (AOptions.MinimumEnergyShare > 1) or
    (AOptions.MaximumMeanCents < 0) or (AOptions.MaximumMeanCents > 50) then
  begin
    raise EAudio.Create('Pitch region admission options exceed their bounds');
  end;
end;

function DefaultPitchBoundaryOptions(const ASampleRate: Integer): TPitchBoundaryOptions;
begin
  ValidateAudioFormat(ASampleRate, 1);
  Result.ContextFrames := Max(1, Round(ASampleRate * 0.08));
  Result.GapFrames := Round(ASampleRate * 0.02);
  Result.Regions := DefaultPitchRegionOptions;
end;

function GatePitchRegion(const ASummary: TPitchRegionSummary;
  const AEndPaddingFrames: Integer): TPitchRegion;
var
  LFound: Integer;
  LVote: TPitchRegionVote;
  I: Integer;
begin
  if (ASummary.Decision <> prdAdmitted) or (ASummary.Note < 0) or
    (ASummary.Note > 127) or (ASummary.CandidateNote <> ASummary.Note) or
    (ASummary.Region.StartFrame < 0) or
    (ASummary.Region.EndFrame <= ASummary.Region.StartFrame) or
    (AEndPaddingFrames < 0) or (Length(ASummary.Votes) > 128) then
  begin
    raise EAudio.Create('Pitch gate requires an admitted region and nonnegative padding');
  end;
  Result := ASummary.Region;
  LFound := 0;
  for I := 0 to High(ASummary.Votes) do
  begin
    LVote := ASummary.Votes[I];
    if LVote.Note <> ASummary.Note then
    begin
      Continue;
    end;
    if (LVote.WindowCount < 1) or
      (LVote.SupportStartFrame < ASummary.Region.StartFrame) or
      (LVote.SupportEndFrame <= LVote.SupportStartFrame) or
      (LVote.SupportEndFrame > ASummary.Region.EndFrame) then
    begin
      raise EAudio.Create('Pitch gate support lies outside its region');
    end;
    Inc(LFound);
    Result.EndFrame := Min(Int64(ASummary.Region.EndFrame),
      Int64(LVote.SupportEndFrame) + AEndPaddingFrames);
  end;
  if LFound <> 1 then
  begin
    raise EAudio.Create('Pitch gate requires exactly one matching note vote');
  end;
end;

function SummarizePitchRegions(const ATrack: TPitchTrack;
  const ARegions: TPitchRegions; const AOptions: TPitchRegionOptions): TPitchRegionSummaries;
var
  LResult: TPitchRegionSummaries;
  LCounts: array[0..127] of Integer;
  LFirstSupport: array[0..127] of Integer;
  LLastSupport: array[0..127] of Integer;
  LEnergy: array[0..127] of Double;
  LCents: array[0..127] of Double;
  LVariance: array[0..127] of Double;
  LEstimate: TPitchEstimate;
  LRegion: TPitchRegion;
  LWindow: Integer;
  LFirst: Integer;
  LLast: Integer;
  LCenter: Int64;
  LMaximumRms: Double;
  LWeight: Double;
  LDelta: Double;
  LTotal: Double;
  LBest: Integer;
  LVoteCount: Integer;
  LNote: Integer;
  I: Integer;
  J: Integer;
begin
  if (ATrack = nil) or (Length(ARegions) > MaximumPitchRegions) then
  begin
    raise EAudio.Create('Pitch regions require a track and bounded region count');
  end;
  ValidatePitchRegionOptions(AOptions);
  for I := 0 to High(ARegions) do
  begin
    LRegion := ARegions[I];
    if (LRegion.StartFrame < 0) or (LRegion.EndFrame <= LRegion.StartFrame) or
      (LRegion.EndFrame > ATrack.FrameCount) or
      ((I > 0) and (LRegion.StartFrame < ARegions[I - 1].EndFrame)) then
    begin
      raise EAudio.Create('Pitch regions require ordered nonoverlapping source intervals');
    end;
  end;
  LResult := nil;
  SetLength(LResult, Length(ARegions));
  LWindow := 0;
  for I := 0 to High(ARegions) do
  begin
    LResult[I].Region := ARegions[I];
    LResult[I].CandidateNote := -1;
    LResult[I].Note := -1;
    LResult[I].Decision := prdNoWindows;
    while LWindow < ATrack.WindowCount do
    begin
      LCenter := Int64(LWindow) * ATrack.Options.HopFrames + ATrack.WindowFrames div 2;
      if LCenter >= ARegions[I].StartFrame then
      begin
        Break;
      end;
      Inc(LWindow);
    end;
    LFirst := LWindow;
    LMaximumRms := 0;
    while LWindow < ATrack.WindowCount do
    begin
      LCenter := Int64(LWindow) * ATrack.Options.HopFrames + ATrack.WindowFrames div 2;
      if LCenter >= ARegions[I].EndFrame then
      begin
        Break;
      end;
      LEstimate := ATrack.EstimateAt(LWindow);
      if (LEstimate.Status = psEstimated) and
        (LEstimate.NearestMidi >= 0) and (LEstimate.NearestMidi <= 127) then
      begin
        Inc(LResult[I].PeriodicWindows);
        LMaximumRms := Max(LMaximumRms, LEstimate.AcRms);
        if ATrack.NoteAt(LWindow) >= 0 then
        begin
          Inc(LResult[I].RawAdmittedWindows);
        end;
      end;
      Inc(LWindow);
    end;
    LLast := LWindow;
    LResult[I].WindowCount := LLast - LFirst;
    if LFirst = LLast then
    begin
      Continue;
    end;
    LResult[I].PeriodicCoverage := LResult[I].PeriodicWindows / LResult[I].WindowCount;
    FillChar(LCounts, SizeOf(LCounts), 0);
    FillChar(LEnergy, SizeOf(LEnergy), 0);
    FillChar(LCents, SizeOf(LCents), 0);
    FillChar(LVariance, SizeOf(LVariance), 0);
    LTotal := 0;
    for J := LFirst to LLast - 1 do
    begin
      LEstimate := ATrack.EstimateAt(J);
      LNote := LEstimate.NearestMidi;
      if (LEstimate.Status <> psEstimated) or (LNote < 0) or (LNote > 127) then
      begin
        Continue;
      end;
      { Normalize before squaring to avoid overflowing finite saved RMS values. }
      LWeight := LEstimate.AcRms / LMaximumRms;
      LWeight := LWeight * LWeight;
      if LCounts[LNote] = 0 then
      begin
        LFirstSupport[LNote] := J;
      end;
      LLastSupport[LNote] := J;
      Inc(LCounts[LNote]);
      LEnergy[LNote] := LEnergy[LNote] + LWeight;
      if LWeight > 0 then
      begin
        { Weighted Welford update avoids subtracting nearly equal second moments. }
        LDelta := LEstimate.CentsError - LCents[LNote];
        LCents[LNote] := LCents[LNote] + LWeight / LEnergy[LNote] * LDelta;
        LVariance[LNote] := LVariance[LNote] +
          LWeight * LDelta * (LEstimate.CentsError - LCents[LNote]);
      end;
      LTotal := LTotal + LWeight;
    end;
    LVoteCount := 0;
    LBest := -1;
    for LNote := 0 to 127 do
    begin
      if LCounts[LNote] > 0 then
      begin
        Inc(LVoteCount);
        if (LBest < 0) or (LEnergy[LNote] > LEnergy[LBest]) then
        begin
          LBest := LNote;
        end;
      end;
    end;
    SetLength(LResult[I].Votes, LVoteCount);
    J := 0;
    for LNote := 0 to 127 do
    begin
      if LCounts[LNote] = 0 then
      begin
        Continue;
      end;
      LResult[I].Votes[J].Note := LNote;
      LResult[I].Votes[J].WindowCount := LCounts[LNote];
      LCenter := Int64(LFirstSupport[LNote]) * ATrack.Options.HopFrames +
        ATrack.WindowFrames div 2;
      LResult[I].Votes[J].SupportStartFrame := Max(Int64(ARegions[I].StartFrame),
        LCenter - ATrack.Options.HopFrames div 2);
      LCenter := Int64(LLastSupport[LNote]) * ATrack.Options.HopFrames +
        ATrack.WindowFrames div 2;
      LResult[I].Votes[J].SupportEndFrame := Min(Int64(ARegions[I].EndFrame),
        LCenter + ATrack.Options.HopFrames - ATrack.Options.HopFrames div 2);
      LResult[I].Votes[J].EnergyShare := LEnergy[LNote] / LTotal;
      if LEnergy[LNote] > 0 then
      begin
        LResult[I].Votes[J].MeanCents := LCents[LNote];
        LResult[I].Votes[J].CentsDeviation :=
          Sqrt(Max(Double(0), LVariance[LNote] / LEnergy[LNote]));
      end;
      Inc(J);
    end;
    LResult[I].CandidateNote := LBest;
    LResult[I].Decision := prdInsufficientPeriodicity;
    if LResult[I].PeriodicWindows < AOptions.MinimumPeriodicWindows then
    begin
      Continue;
    end;
    LResult[I].Decision := prdInsufficientCoverage;
    if LResult[I].PeriodicCoverage < AOptions.MinimumPeriodicCoverage then
    begin
      Continue;
    end;
    LResult[I].Decision := prdAmbiguousPitch;
    if LEnergy[LBest] / LTotal < AOptions.MinimumEnergyShare then
    begin
      Continue;
    end;
    LResult[I].Decision := prdOutsideTuning;
    if Abs(LCents[LBest]) > AOptions.MaximumMeanCents then
    begin
      Continue;
    end;
    LResult[I].Note := LBest;
    LResult[I].Decision := prdAdmitted;
  end;
  Result := LResult;
end;

function SummarizePitchBoundary(const ATrack: TPitchTrack; const AFrame: Integer;
  const AOptions: TPitchBoundaryOptions): TPitchBoundarySummary;
var
  LRegions: TPitchRegions;
  LSides: TPitchRegionSummaries;
  LFirst: Integer;
  LLast: Integer;
  LCenter: Int64;
  LIndex: Integer;
begin
  if (ATrack = nil) or (AFrame < 0) or (AFrame > ATrack.FrameCount) then
  begin
    raise EAudio.Create('Pitch boundary requires a track and a frame within its clip');
  end;
  if (AOptions.ContextFrames < 1) or (AOptions.ContextFrames > MaximumClipSamples) or
    (AOptions.GapFrames < 0) or (AOptions.GapFrames >= AOptions.ContextFrames) then
  begin
    raise EAudio.Create('Pitch boundary requires bounded context larger than its inner gap');
  end;
  ValidatePitchRegionOptions(AOptions.Regions);
  Result := Default(TPitchBoundarySummary);
  Result.Frame := AFrame;
  Result.Left.Note := -1;
  Result.Left.CandidateNote := -1;
  Result.Right.Note := -1;
  Result.Right.CandidateNote := -1;
  if (AFrame < AOptions.ContextFrames) or
    (Int64(AFrame) + AOptions.ContextFrames > ATrack.FrameCount) then
  begin
    Exit;
  end;
  Result.CompleteContext := True;
  SetLength(LRegions, 2);
  LRegions[0].StartFrame := AFrame - AOptions.ContextFrames;
  LRegions[0].EndFrame := AFrame - AOptions.GapFrames;
  LRegions[1].StartFrame := AFrame + AOptions.GapFrames;
  LRegions[1].EndFrame := AFrame + AOptions.ContextFrames;
  LSides := SummarizePitchRegions(ATrack, LRegions, AOptions.Regions);
  Result.Left := LSides[0];
  Result.Right := LSides[1];
  LFirst := Max(0, (AFrame - AOptions.GapFrames - ATrack.WindowFrames div 2) div
    ATrack.Options.HopFrames - 1);
  LLast := Min(ATrack.WindowCount - 1,
    (AFrame + AOptions.GapFrames - ATrack.WindowFrames div 2) div ATrack.Options.HopFrames + 1);
  for LIndex := LFirst to LLast do
  begin
    LCenter := Int64(LIndex) * ATrack.Options.HopFrames + ATrack.WindowFrames div 2;
    if Abs(LCenter - AFrame) > AOptions.GapFrames then
    begin
      Continue;
    end;
    Inc(Result.LocalWindows);
    if ATrack.EstimateAt(LIndex).Status in [psSilence, psNoPeriod] then
    begin
      Inc(Result.UnresolvedWindows);
    end;
  end;
  Result.Qualified := (Result.Left.Note >= 0) and (Result.Right.Note >= 0) and
    ((Result.Left.Note <> Result.Right.Note) or (Result.UnresolvedWindows > 0));
end;

end.
