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
unit pythian.beat.pulse;

{$mode delphi}
{$H+}

interface

uses
  pythian.beat,
  pythian.beat.track;

const
  MaximumBeatPulseAlternatives = 32;
  MaximumBeatPulseStoredFrames = 65536;

type
  TBeatPulseAlternativeKind = (bpakGrid, bpakExplicit);
  TBeatPulseAlternative = record
    Kind: TBeatPulseAlternativeKind;
    SourceId: String;
    WindowIndex: Integer;
    OwnerStartFrame: Integer;
    OwnerEndFrame: Integer;
    AlternativeIndex: Integer;
    BaseGridIndex: Integer;
    Score: Double;
    { Explicit positions are source frames. ParentSeedFrames has one element per
      output: a rendered base-grid frame or -1 for a boundary birth. Every
      unparented rendered seed must occur in DroppedSeedFrames. }
    Frames: TBeatFrames;
    ParentSeedFrames: TBeatFrames;
    DroppedSeedFrames: TBeatFrames;
  end;
  TBeatPulseAlternatives = array of TBeatPulseAlternative;
  TBeatPulseWindow = record
    SourceWindowIndex: Integer;
    AnalysisStartFrame: Integer;
    AnalysisEndFrame: Integer;
    OwnerStartFrame: Integer;
    OwnerEndFrame: Integer;
    FirstObservationFrame: Integer;
    LastObservationFrame: Integer;
    StartsNewPath: Boolean;
    JoinUncertain: Boolean;
    GridCandidates: TBeatGridCandidates;
    Alternatives: TBeatPulseAlternatives;
    SelectedAlternative: Integer;
  end;
  TBeatPulseWindows = array of TBeatPulseWindow;
  TBeatPulseTrack = record
    SourceId: String;
    SampleRate: Integer;
    SourceFrames: Integer;
    SupportToleranceFrames: Integer;
    Windows: TBeatPulseWindows;
  end;
  TBeatPulseFlags = array of Boolean;
  TBeatPulseClock = record
    SourceId: String;
    SampleRate: Integer;
    SourceFrames: Integer;
    RawFrames: TBeatFrames;
    SeedFrames: TBeatFrames;
    FrameWindows: TBeatFrames;
    AlternativeIndices: TBeatFrames;
    RunIds: TBeatFrames;
    GapBefore: TBeatPulseFlags;
  end;

{ Copies the accepted grid pool in place, retaining every rank and selection.
  ASourceId is caller-bound source identity; this unit does not hash audio.
  Owners must partition [0,ASourceFrames). No existing v1 type is changed. }
function WrapBeatTrackWindows(const AWindows: TBeatTrackWindows;
  const ASourceId: String; const ASampleRate, ASourceFrames,
  ASupportToleranceFrames: Integer): TBeatPulseTrack;

{ Appends one explicit alternative to an owner. The base grid, exact rendered
  seed complement, boundary births, order, ownership, identity and budgets are
  checked before a detached result is returned. Invalid input leaves ATrack
  untouched. A score is a caller-supplied ordering value, not confidence. }
function AppendBeatPulseAlternative(const ATrack: TBeatPulseTrack;
  const AWindowIndex: Integer;
  const AAlternative: TBeatPulseAlternative): TBeatPulseTrack;

{ Selects an existing alternative without fitting or path optimization. }
function SelectBeatPulseAlternative(const ATrack: TBeatPulseTrack;
  const AWindowIndex, AAlternativeIndex: Integer): TBeatPulseTrack;

{ Renders selected grid or explicit source frames with detached output. }
function BeatPulseAlternativeFrames(const ATrack: TBeatPulseTrack;
  const AWindowIndex, AAlternativeIndex: Integer): TBeatFrames;

{ Builds a raw, selected pulse clock. Dropped seeds mark a discontinuity before
  the next pulse; gaps, restarts, uncertain joins and mixed explicit seams do
  likewise. No missing pulse is silently reinterpreted as a slower beat. }
function SelectedBeatPulseClock(const ATrack: TBeatPulseTrack): TBeatPulseClock;

implementation

uses
  Math,
  SysUtils,
  pythian.audio;

type
  TBeatPulseFrameBlocks = array of TBeatFrames;

procedure Need(const ACondition: Boolean; const AMessage: String);
begin
  if not ACondition then
  begin
    raise EAudio.Create(AMessage);
  end;
end;

procedure CheckTrackPolicy(const ATrack: TBeatPulseTrack);
begin
  ValidateAudioFormat(ATrack.SampleRate, 1);
  Need((Length(ATrack.SourceId) > 0) and (Length(ATrack.SourceId) <= 128) and
    (ATrack.SourceFrames > 0) and
    (ATrack.SourceFrames <= MaximumClipSamples) and
    (Length(ATrack.Windows) > 0) and
    (Length(ATrack.Windows) <= MaximumBeatTrackWindows) and
    (ATrack.SupportToleranceFrames >= 0) and
    (ATrack.SupportToleranceFrames <= ATrack.SampleRate div 5),
    'Pulse track source, window count or support tolerance is invalid');
end;

function FrameIndex(const AFrames: TBeatFrames; const AFrame: Integer): Integer;
var
  LLeft: Integer;
  LRight: Integer;
  LMiddle: Integer;
begin
  LLeft := 0;
  LRight := Length(AFrames) - 1;
  while LLeft <= LRight do
  begin
    LMiddle := LLeft + (LRight - LLeft) div 2;
    if AFrames[LMiddle] = AFrame then
    begin
      Exit(LMiddle);
    end;
    if AFrames[LMiddle] < AFrame then
    begin
      LLeft := LMiddle + 1;
    end
    else
    begin
      LRight := LMiddle - 1;
    end;
  end;
  Result := -1;
end;

procedure CheckWindowGeometry(const ATrack: TBeatPulseTrack;
  const AWindowIndex: Integer);
var
  LWindow: TBeatPulseWindow;
begin
  LWindow := ATrack.Windows[AWindowIndex];
  Need((LWindow.AnalysisStartFrame >= 0) and
    (LWindow.AnalysisStartFrame < LWindow.AnalysisEndFrame) and
    (LWindow.AnalysisEndFrame <= ATrack.SourceFrames) and
    (LWindow.OwnerStartFrame >= LWindow.AnalysisStartFrame) and
    (LWindow.OwnerEndFrame > LWindow.OwnerStartFrame) and
    (LWindow.OwnerEndFrame <= LWindow.AnalysisEndFrame),
    'Pulse analysis window or owner lies outside source bounds');
  if Length(LWindow.GridCandidates) > 0 then
  begin
    Need((LWindow.FirstObservationFrame >= LWindow.AnalysisStartFrame) and
      (LWindow.LastObservationFrame >= LWindow.FirstObservationFrame) and
      (LWindow.LastObservationFrame < LWindow.AnalysisEndFrame) and
      (LWindow.LastObservationFrame < ATrack.SourceFrames),
      'Pulse observation span lies outside analysis window');
  end;
end;

function GridFrames(const ATrack: TBeatPulseTrack;
  const AWindowIndex, AGridIndex: Integer): TBeatFrames;
var
  LWindow: TBeatPulseWindow;
  LStart: Integer;
  LEnd: Integer;
begin
  CheckWindowGeometry(ATrack, AWindowIndex);
  LWindow := ATrack.Windows[AWindowIndex];
  Need((AGridIndex >= 0) and (AGridIndex < Length(LWindow.GridCandidates)),
    'Pulse base grid index is invalid');
  LStart := Max(LWindow.OwnerStartFrame,
    LWindow.FirstObservationFrame - ATrack.SupportToleranceFrames);
  LEnd := Min(LWindow.OwnerEndFrame,
    LWindow.LastObservationFrame + ATrack.SupportToleranceFrames + 1);
  if LEnd <= LStart then
  begin
    Exit(nil);
  end;
  Result := BeatGridFrames(LWindow.GridCandidates[AGridIndex], LStart, LEnd);
end;

procedure CheckAlternativeIdentity(const ATrack: TBeatPulseTrack;
  const AWindowIndex, AAlternativeIndex: Integer;
  const AAlternative: TBeatPulseAlternative);
var
  LWindow: TBeatPulseWindow;
begin
  LWindow := ATrack.Windows[AWindowIndex];
  Need((AAlternative.SourceId = ATrack.SourceId) and
    (AAlternative.WindowIndex = AWindowIndex) and
    (AAlternative.OwnerStartFrame = LWindow.OwnerStartFrame) and
    (AAlternative.OwnerEndFrame = LWindow.OwnerEndFrame) and
    (AAlternative.AlternativeIndex = AAlternativeIndex),
    'Pulse alternative identity differs from its source owner');
  Need((AAlternative.BaseGridIndex >= 0) and
    (AAlternative.BaseGridIndex < Length(LWindow.GridCandidates)),
    'Pulse alternative base grid index is invalid');
  RequireFinite(AAlternative.Score, 'Pulse alternative score');
  Need((AAlternative.Score >= 0) and (AAlternative.Score <= 1),
    'Pulse alternative score exceeds bounds');
end;

procedure CheckExplicit(const ATrack: TBeatPulseTrack;
  const AWindowIndex, AAlternativeIndex: Integer;
  const AAlternative: TBeatPulseAlternative);
var
  LSeeds: TBeatFrames;
  LUsed: TBeatPulseFlags;
  LWindow: TBeatPulseWindow;
  LPeriod: Integer;
  LSeedIndex: Integer;
  LPrevious: Integer;
  LUsedCount: Integer;
  LPreviousParent: Integer;
  LIndex: Integer;
begin
  Need(AAlternative.Kind = bpakExplicit, 'Expected explicit pulse alternative');
  CheckAlternativeIdentity(ATrack, AWindowIndex, AAlternativeIndex, AAlternative);
  LWindow := ATrack.Windows[AWindowIndex];
  Need((Length(AAlternative.Frames) > 0) and
    (Length(AAlternative.Frames) = Length(AAlternative.ParentSeedFrames)),
    'Explicit pulse positions and lineage differ in length');
  Need(Int64(Length(AAlternative.Frames)) * 2 +
    Length(AAlternative.DroppedSeedFrames) <= MaximumBeatPulseStoredFrames,
    'Explicit pulse frame storage exceeds budget');
  LSeeds := GridFrames(ATrack, AWindowIndex, AAlternative.BaseGridIndex);
  SetLength(LUsed, Length(LSeeds));
  LPeriod := Ceil(LWindow.GridCandidates[AAlternative.BaseGridIndex].PeriodFrames);
  LPrevious := LWindow.OwnerStartFrame - 1;
  LPreviousParent := -1;
  LUsedCount := 0;
  for LIndex := 0 to High(AAlternative.Frames) do
  begin
    Need((AAlternative.Frames[LIndex] > LPrevious) and
      (AAlternative.Frames[LIndex] < LWindow.OwnerEndFrame) and
      (AAlternative.Frames[LIndex] < ATrack.SourceFrames),
      'Explicit pulse frames must increase inside their owner');
    LPrevious := AAlternative.Frames[LIndex];
    if AAlternative.ParentSeedFrames[LIndex] = -1 then
    begin
      Need((FrameIndex(LSeeds, AAlternative.Frames[LIndex]) < 0) and
        ((AAlternative.Frames[LIndex] - LWindow.OwnerStartFrame <= LPeriod) or
         (LWindow.OwnerEndFrame - 1 - AAlternative.Frames[LIndex] <= LPeriod)),
        'Birth pulse must be new and within one period of an owner edge');
    end
    else
    begin
      LSeedIndex := FrameIndex(LSeeds, AAlternative.ParentSeedFrames[LIndex]);
      Need((LSeedIndex >= 0) and not LUsed[LSeedIndex] and
        (AAlternative.ParentSeedFrames[LIndex] > LPreviousParent),
        'Pulse parent seed is missing, reused or out of order');
      LUsed[LSeedIndex] := True;
      LPreviousParent := AAlternative.ParentSeedFrames[LIndex];
      Inc(LUsedCount);
    end;
  end;
  LPrevious := -1;
  for LIndex := 0 to High(AAlternative.DroppedSeedFrames) do
  begin
    Need(AAlternative.DroppedSeedFrames[LIndex] > LPrevious,
      'Dropped seed frames must increase without duplicates');
    LPrevious := AAlternative.DroppedSeedFrames[LIndex];
    LSeedIndex := FrameIndex(LSeeds, LPrevious);
    Need((LSeedIndex >= 0) and not LUsed[LSeedIndex] and
      (FrameIndex(AAlternative.Frames, LPrevious) < 0),
      'Dropped seed is absent, reused or retained as an output');
    LUsed[LSeedIndex] := True;
    Inc(LUsedCount);
  end;
  Need(LUsedCount = Length(LSeeds),
    'Every base-grid seed must be parented or explicitly dropped');
end;

function CloneTrack(const ATrack: TBeatPulseTrack): TBeatPulseTrack;
var
  LWindow: Integer;
  LAlternative: Integer;
begin
  Result := ATrack;
  Result.Windows := Copy(ATrack.Windows);
  for LWindow := 0 to High(Result.Windows) do
  begin
    Result.Windows[LWindow].GridCandidates :=
      Copy(ATrack.Windows[LWindow].GridCandidates);
    Result.Windows[LWindow].Alternatives :=
      Copy(ATrack.Windows[LWindow].Alternatives);
    for LAlternative := 0 to High(Result.Windows[LWindow].Alternatives) do
    begin
      Result.Windows[LWindow].Alternatives[LAlternative].Frames :=
        Copy(ATrack.Windows[LWindow].Alternatives[LAlternative].Frames);
      Result.Windows[LWindow].Alternatives[LAlternative].ParentSeedFrames :=
        Copy(ATrack.Windows[LWindow].Alternatives[LAlternative].ParentSeedFrames);
      Result.Windows[LWindow].Alternatives[LAlternative].DroppedSeedFrames :=
        Copy(ATrack.Windows[LWindow].Alternatives[LAlternative].DroppedSeedFrames);
    end;
  end;
end;

function StoredFrameCount(const ATrack: TBeatPulseTrack): Int64;
var
  LWindow: Integer;
  LAlternative: Integer;
begin
  Result := 0;
  for LWindow := 0 to High(ATrack.Windows) do
  begin
    for LAlternative := 0 to High(ATrack.Windows[LWindow].Alternatives) do
    begin
      if ATrack.Windows[LWindow].Alternatives[LAlternative].Kind = bpakExplicit then
      begin
        Inc(Result, Length(ATrack.Windows[LWindow].Alternatives[LAlternative].Frames));
        Inc(Result, Length(ATrack.Windows[LWindow].Alternatives[LAlternative].ParentSeedFrames));
        Inc(Result, Length(ATrack.Windows[LWindow].Alternatives[LAlternative].DroppedSeedFrames));
      end;
    end;
  end;
end;

function WrapBeatTrackWindows(const AWindows: TBeatTrackWindows;
  const ASourceId: String; const ASampleRate, ASourceFrames,
  ASupportToleranceFrames: Integer): TBeatPulseTrack;
var
  LWindow: Integer;
  LGrid: Integer;
  LEnd: Integer;
begin
  ValidateAudioFormat(ASampleRate, 1);
  Need((Length(ASourceId) > 0) and (Length(ASourceId) <= 128) and
    (ASourceFrames > 0) and (ASourceFrames <= MaximumClipSamples) and
    (Length(AWindows) > 0) and (Length(AWindows) <= MaximumBeatTrackWindows) and
    (ASupportToleranceFrames >= 0) and
    (ASupportToleranceFrames <= ASampleRate div 5),
    'Pulse source or window budget is invalid');
  Result := Default(TBeatPulseTrack);
  Result.SourceId := ASourceId;
  Result.SampleRate := ASampleRate;
  Result.SourceFrames := ASourceFrames;
  Result.SupportToleranceFrames := ASupportToleranceFrames;
  SetLength(Result.Windows, Length(AWindows));
  LEnd := 0;
  for LWindow := 0 to High(AWindows) do
  begin
    Need((AWindows[LWindow].OwnerStartFrame = LEnd) and
      (AWindows[LWindow].OwnerEndFrame > LEnd) and
      (AWindows[LWindow].OwnerEndFrame <= ASourceFrames) and
      (AWindows[LWindow].StartFrame <= AWindows[LWindow].OwnerStartFrame) and
      (AWindows[LWindow].EndFrame >= AWindows[LWindow].OwnerEndFrame) and
      (AWindows[LWindow].EndFrame <= ASourceFrames) and
      (Length(AWindows[LWindow].Analysis.Candidates) <= MaximumBeatPulseAlternatives) and
      (AWindows[LWindow].SelectedCandidate >= -1) and
      (AWindows[LWindow].SelectedCandidate <
        Length(AWindows[LWindow].Analysis.Candidates)),
      'Pulse owner, candidate count or selection is invalid');
    LEnd := AWindows[LWindow].OwnerEndFrame;
    Result.Windows[LWindow].SourceWindowIndex := LWindow;
    Result.Windows[LWindow].AnalysisStartFrame := AWindows[LWindow].StartFrame;
    Result.Windows[LWindow].AnalysisEndFrame := AWindows[LWindow].EndFrame;
    Result.Windows[LWindow].OwnerStartFrame := AWindows[LWindow].OwnerStartFrame;
    Result.Windows[LWindow].OwnerEndFrame := LEnd;
    Result.Windows[LWindow].FirstObservationFrame :=
      AWindows[LWindow].Analysis.FirstObservationFrame;
    Result.Windows[LWindow].LastObservationFrame :=
      AWindows[LWindow].Analysis.LastObservationFrame;
    Result.Windows[LWindow].StartsNewPath := AWindows[LWindow].StartsNewPath;
    Result.Windows[LWindow].JoinUncertain := AWindows[LWindow].JoinUncertain;
    Result.Windows[LWindow].GridCandidates :=
      Copy(AWindows[LWindow].Analysis.Candidates);
    CheckWindowGeometry(Result, LWindow);
    Result.Windows[LWindow].SelectedAlternative := AWindows[LWindow].SelectedCandidate;
    SetLength(Result.Windows[LWindow].Alternatives,
      Length(Result.Windows[LWindow].GridCandidates));
    for LGrid := 0 to High(Result.Windows[LWindow].GridCandidates) do
    begin
      RequireFinite(Result.Windows[LWindow].GridCandidates[LGrid].Bpm,
        'Pulse grid BPM');
      Need((Result.Windows[LWindow].GridCandidates[LGrid].Bpm >= 20) and
        (Result.Windows[LWindow].GridCandidates[LGrid].Bpm <= 400),
        'Pulse grid BPM exceeds bounds');
      BeatGridFrames(Result.Windows[LWindow].GridCandidates[LGrid], 0, 0);
      Need(Abs(Result.Windows[LWindow].GridCandidates[LGrid].PeriodFrames -
        ASampleRate * 60 / Result.Windows[LWindow].GridCandidates[LGrid].Bpm) <=
        1E-6 * Max(1.0, Result.Windows[LWindow].GridCandidates[LGrid].PeriodFrames),
        'Pulse grid period differs from source sample clock');
      Result.Windows[LWindow].Alternatives[LGrid].Kind := bpakGrid;
      Result.Windows[LWindow].Alternatives[LGrid].SourceId := ASourceId;
      Result.Windows[LWindow].Alternatives[LGrid].WindowIndex := LWindow;
      Result.Windows[LWindow].Alternatives[LGrid].OwnerStartFrame :=
        AWindows[LWindow].OwnerStartFrame;
      Result.Windows[LWindow].Alternatives[LGrid].OwnerEndFrame := LEnd;
      Result.Windows[LWindow].Alternatives[LGrid].AlternativeIndex := LGrid;
      Result.Windows[LWindow].Alternatives[LGrid].BaseGridIndex := LGrid;
      Result.Windows[LWindow].Alternatives[LGrid].Score :=
        Result.Windows[LWindow].GridCandidates[LGrid].Score;
      CheckAlternativeIdentity(Result, LWindow, LGrid,
        Result.Windows[LWindow].Alternatives[LGrid]);
    end;
  end;
  Need(LEnd = ASourceFrames, 'Pulse owners do not cover the source');
end;

function AppendBeatPulseAlternative(const ATrack: TBeatPulseTrack;
  const AWindowIndex: Integer;
  const AAlternative: TBeatPulseAlternative): TBeatPulseTrack;
var
  LCount: Integer;
  LNewStorage: Int64;
begin
  CheckTrackPolicy(ATrack);
  Need((AWindowIndex >= 0) and (AWindowIndex < Length(ATrack.Windows)),
    'Pulse window index is invalid');
  LCount := Length(ATrack.Windows[AWindowIndex].Alternatives);
  Need(LCount < MaximumBeatPulseAlternatives,
    'Pulse alternative count exceeds budget');
  LNewStorage := StoredFrameCount(ATrack) +
    Int64(Length(AAlternative.Frames)) +
    Length(AAlternative.ParentSeedFrames) +
    Length(AAlternative.DroppedSeedFrames);
  Need(LNewStorage <= MaximumBeatPulseStoredFrames,
    'Pulse alternative frame storage exceeds budget');
  CheckExplicit(ATrack, AWindowIndex, LCount, AAlternative);
  Result := CloneTrack(ATrack);
  SetLength(Result.Windows[AWindowIndex].Alternatives, LCount + 1);
  Result.Windows[AWindowIndex].Alternatives[LCount] := AAlternative;
  Result.Windows[AWindowIndex].Alternatives[LCount].Frames :=
    Copy(AAlternative.Frames);
  Result.Windows[AWindowIndex].Alternatives[LCount].ParentSeedFrames :=
    Copy(AAlternative.ParentSeedFrames);
  Result.Windows[AWindowIndex].Alternatives[LCount].DroppedSeedFrames :=
    Copy(AAlternative.DroppedSeedFrames);
end;

function SelectBeatPulseAlternative(const ATrack: TBeatPulseTrack;
  const AWindowIndex, AAlternativeIndex: Integer): TBeatPulseTrack;
begin
  CheckTrackPolicy(ATrack);
  Need((AWindowIndex >= 0) and (AWindowIndex < Length(ATrack.Windows)),
    'Pulse selection window is invalid');
  Need((AAlternativeIndex >= -1) and
    (AAlternativeIndex < Length(ATrack.Windows[AWindowIndex].Alternatives)),
    'Pulse selection alternative is invalid');
  if AAlternativeIndex >= 0 then
  begin
    CheckAlternativeIdentity(ATrack, AWindowIndex, AAlternativeIndex,
      ATrack.Windows[AWindowIndex].Alternatives[AAlternativeIndex]);
  end;
  Result := CloneTrack(ATrack);
  Result.Windows[AWindowIndex].SelectedAlternative := AAlternativeIndex;
end;

function BeatPulseAlternativeFrames(const ATrack: TBeatPulseTrack;
  const AWindowIndex, AAlternativeIndex: Integer): TBeatFrames;
var
  LAlternative: TBeatPulseAlternative;
begin
  CheckTrackPolicy(ATrack);
  Need((AWindowIndex >= 0) and (AWindowIndex < Length(ATrack.Windows)) and
    (AAlternativeIndex >= 0) and
    (AAlternativeIndex < Length(ATrack.Windows[AWindowIndex].Alternatives)),
    'Pulse render index is invalid');
  LAlternative := ATrack.Windows[AWindowIndex].Alternatives[AAlternativeIndex];
  CheckAlternativeIdentity(ATrack, AWindowIndex, AAlternativeIndex,
    LAlternative);
  case LAlternative.Kind of
    bpakGrid:
      begin
        Need(LAlternative.BaseGridIndex = AAlternativeIndex,
          'Grid alternative rank has changed');
        Result := GridFrames(ATrack, AWindowIndex, AAlternativeIndex);
      end;
    bpakExplicit:
      begin
        CheckExplicit(ATrack, AWindowIndex, AAlternativeIndex, LAlternative);
        Result := Copy(LAlternative.Frames);
      end;
  else
    raise EAudio.Create('Pulse alternative kind is invalid');
  end;
end;

function SelectedBeatPulseClock(const ATrack: TBeatPulseTrack): TBeatPulseClock;
var
  LBlocks: TBeatPulseFrameBlocks;
  LWindow: Integer;
  LPoint: Integer;
  LWrite: Integer;
  LCount: Integer;
  LChoice: Integer;
  LDrop: Integer;
  LRun: Integer;
  LGap: Boolean;
  LPendingGap: Boolean;
  LPreviousWindow: Integer;
  LPreviousExplicit: Boolean;
  LAlternative: TBeatPulseAlternative;
  LEnd: Integer;
  LDropBoundary: Integer;
begin
  CheckTrackPolicy(ATrack);
  Need(StoredFrameCount(ATrack) <= MaximumBeatPulseStoredFrames,
    'Selected pulse clock storage budget is invalid');
  SetLength(LBlocks, Length(ATrack.Windows));
  LCount := 0;
  LEnd := 0;
  for LWindow := 0 to High(ATrack.Windows) do
  begin
    Need((ATrack.Windows[LWindow].SourceWindowIndex = LWindow) and
      (ATrack.Windows[LWindow].OwnerStartFrame = LEnd) and
      (ATrack.Windows[LWindow].OwnerEndFrame > LEnd) and
      (ATrack.Windows[LWindow].OwnerEndFrame <= ATrack.SourceFrames) and
      (Length(ATrack.Windows[LWindow].Alternatives) <=
        MaximumBeatPulseAlternatives),
      'Selected pulse owner identity is invalid');
    CheckWindowGeometry(ATrack, LWindow);
    LEnd := ATrack.Windows[LWindow].OwnerEndFrame;
    LChoice := ATrack.Windows[LWindow].SelectedAlternative;
    Need((LChoice >= -1) and
      (LChoice < Length(ATrack.Windows[LWindow].Alternatives)),
      'Selected pulse alternative is invalid');
    if LChoice < 0 then
    begin
      Continue;
    end;
    LBlocks[LWindow] := BeatPulseAlternativeFrames(ATrack, LWindow, LChoice);
    Need(Length(LBlocks[LWindow]) <= MaximumBeatFrames - LCount,
      'Selected pulse clock exceeds output budget');
    Inc(LCount, Length(LBlocks[LWindow]));
  end;
  Need(LEnd = ATrack.SourceFrames,
    'Selected pulse owners do not cover source');
  Result := Default(TBeatPulseClock);
  Result.SourceId := ATrack.SourceId;
  Result.SampleRate := ATrack.SampleRate;
  Result.SourceFrames := ATrack.SourceFrames;
  SetLength(Result.RawFrames, LCount);
  SetLength(Result.SeedFrames, LCount);
  SetLength(Result.FrameWindows, LCount);
  SetLength(Result.AlternativeIndices, LCount);
  SetLength(Result.RunIds, LCount);
  SetLength(Result.GapBefore, LCount);
  LWrite := 0;
  LRun := 0;
  LPreviousWindow := -1;
  LPreviousExplicit := False;
  LPendingGap := False;
  for LWindow := 0 to High(ATrack.Windows) do
  begin
    LChoice := ATrack.Windows[LWindow].SelectedAlternative;
    if LChoice < 0 then
    begin
      LPendingGap := True;
      Continue;
    end;
    LAlternative := ATrack.Windows[LWindow].Alternatives[LChoice];
    LDrop := 0;
    for LPoint := 0 to High(LBlocks[LWindow]) do
    begin
      LGap := LPendingGap;
      if LPoint = 0 then
      begin
        LGap := LGap or ATrack.Windows[LWindow].StartsNewPath or
          ATrack.Windows[LWindow].JoinUncertain or
          (LPreviousWindow >= 0) and
          ((LWindow <> LPreviousWindow + 1) or LPreviousExplicit or
           (LAlternative.Kind = bpakExplicit));
      end;
      if LAlternative.Kind = bpakExplicit then
      begin
        LDropBoundary := LAlternative.ParentSeedFrames[LPoint];
        if LDropBoundary < 0 then
        begin
          LDropBoundary := LBlocks[LWindow][LPoint];
        end;
        while (LDrop < Length(LAlternative.DroppedSeedFrames)) and
          (LAlternative.DroppedSeedFrames[LDrop] <= LDropBoundary) do
        begin
          LGap := True;
          Inc(LDrop);
        end;
        Result.SeedFrames[LWrite] := LAlternative.ParentSeedFrames[LPoint];
      end
      else
      begin
        Result.SeedFrames[LWrite] := LBlocks[LWindow][LPoint];
      end;
      Need((LWrite = 0) or
        (LBlocks[LWindow][LPoint] > Result.RawFrames[LWrite - 1]),
        'Selected pulse clock is not strictly increasing');
      if (LWrite > 0) and LGap then
      begin
        Inc(LRun);
      end;
      Result.RawFrames[LWrite] := LBlocks[LWindow][LPoint];
      Result.FrameWindows[LWrite] := LWindow;
      Result.AlternativeIndices[LWrite] := LChoice;
      Result.RunIds[LWrite] := LRun;
      Result.GapBefore[LWrite] := (LWrite > 0) and LGap;
      LPendingGap := False;
      Inc(LWrite);
    end;
    if Length(LBlocks[LWindow]) > 0 then
    begin
      LPreviousWindow := LWindow;
      LPreviousExplicit := LAlternative.Kind = bpakExplicit;
    end;
    if Length(LBlocks[LWindow]) = 0 then
    begin
      LPendingGap := True;
    end;
    if (LAlternative.Kind = bpakExplicit) and
      (LDrop < Length(LAlternative.DroppedSeedFrames)) then
    begin
      LPendingGap := True;
    end;
  end;
end;

end.
