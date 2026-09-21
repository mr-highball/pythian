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

unit pythian.music.context.admission;

{$mode delphi}
{$H+}

interface

uses
  pythian.audio,
  pythian.analysis,
  pythian.music.grid.frames,
  pythian.music.context,
  pythian.beat,
  pythian.beat.clock,
  pythian.beat.track,
  pythian.time,
  pythian.tonal;

const
  WaveContextAdmissionVersion = 1;

type
  TTonalContextAdmission = record
    Key: TKeyContext;
    SelectedRank: Integer;
    Report: TTonalReport;
  end;

  TTonalKeyRegion = record
    FirstCell: Integer;
    CellCount: Integer;
    Key: TKeyContext;
  end;
  TTonalKeyRegions = array of TTonalKeyRegion;
  TTonalRegionAdmission = record
    Region: TTonalKeyRegion;
    StartFrame: Integer;
    EndFrame: Integer;
    Weights: TPitchClassWeights;
    Tonal: TTonalContextAdmission;
  end;
  TTonalRegionAdmissions = array of TTonalRegionAdmission;

  TWaveContextScope = record
    Grid: TMusicContextGrid;
    StartFrameFloor: Integer;
    StartFrameCeiling: Integer;
    EndFrameFloor: Integer;
    EndFrameCeiling: Integer;
    UnassignedWholeFrames: Integer;
  end;

  TBeatContextAdmission = record
    Scope: TWaveContextScope;
    TempoMicroseconds: Integer;
    PhaseErrorFrames: Double;
    PeriodErrorFrames: Double;
  end;

  TBeatTrackAdmission = record
    SourceStartFrame: Integer;
    SourceEndFrame: Integer;
    Grid: TMusicContextGrid;
    Changes: TTempoChanges;
    BoundaryErrors: TBeatFrames;
  end;

{ Caller selects inclusive pulse indices and declares each interval one quarter.
  Tick zero is the first selected source frame, not a downbeat. No extrapolation
  across gaps, path restarts or uncertain joins. Rounded cumulative microseconds
  prevent interval-rounding drift. The returned clock is relative to the source
  offset; errors are floor-clock frames minus measured frames at every pulse. }
function AdmitBeatTrackRange(const ATrack: TBeatTrack; const ASampleRate,
  ASourceFrames, AFirstPulse, ALastPulse, ATicksPerQuarter, AStepTicks: Integer;
  const AKey: TKeyContext): TBeatTrackAdmission;

{ Reconstruct the explicitly selected clock, then admit inclusive pulse indices
  with the same caller-declared quarter meaning and cumulative rounding as track
  admission. Reject ranges spanning missing windows, restarts, unavailable or
  numerically ambiguous phase segments. Reconstructing from borrowed inputs
  prevents admission of a stale or edited derived clock. Neither a feasible step
  nor successful admission establishes automatic tempo or meter confidence. }
function AdmitBeatClockRange(const AWindows: TBeatClockWindows;
  const AObservations: TBeatObservations; const AOptions: TBeatClockOptions;
  const ASampleRate, ASourceFrames, AFirstPulse, ALastPulse,
  ATicksPerQuarter, AStepTicks: Integer; const AKey: TKeyContext): TBeatTrackAdmission;

{ Records an explicit caller selection; no score threshold or automatic winner.
  Unknown remains unknown even with measured evidence. Known selection requires
  nonzero evidence, but its rank is not a confidence or correctness assertion. }
function AdmitTonalContext(const AWeights: TPitchClassWeights;
  const ASelectedKey: TKeyContext): TTonalContextAdmission;

{ Explicit ordered regions partition the complete source grid. Each region is
  analyzed independently, with window origins reset and final padding at its own
  end: neighboring regions cannot contribute samples. Grid floor boundaries
  define the measured half-open frame ranges. Region labels/boundaries remain
  caller decisions; ranking is not a key-change detector. Unknown is retained,
  and a known key requires nonzero local evidence. Clip/grid are borrowed.
  Aggregate analysis budgets are preflighted before reading samples. }
function AdmitWaveKeyRegions(const AClip: TAudioClip; const AGrid: TMusicGridFrames;
  const ARegions: TTonalKeyRegions; const AOptions: TAnalysisOptions): TTonalRegionAdmissions;

{ Constant caller-declared clock with an explicit source start tick; no downbeat
  inference. Includes only complete cells whose exact end is within the source.
  Reports floor/ceiling sample boundaries and remaining whole frames. Excess
  context/timeline budgets reject rather than silently truncating the grid. }
function WaveContextScope(const ASampleRate, ASourceFrames, ATempoMicroseconds,
  ATicksPerQuarter, AStepTicks: Integer; const AKey: TKeyContext;
  const AStartTick: Integer = 0): TWaveContextScope;

{ Explicit selected pulse hypothesis. Rounds its period to integer microseconds
  and phase to the nearest source PPQ tick, half ties later. Reports signed
  quantization errors; admission does not establish a downbeat or stable tempo. }
function AdmitBeatContext(const ACandidate: TBeatGridCandidate;
  const ASampleRate, ASourceFrames, ATicksPerQuarter, AStepTicks: Integer;
  const AKey: TKeyContext): TBeatContextAdmission;

implementation

uses
  Math;

type
  TRegionAnalysisSource = class(TAudioAnalysisSource)
  private
    FClip: TAudioClip;
    FStart: Integer;
  public
    constructor Create(const AClip: TAudioClip; const AStart, ACount: Integer);
    procedure ReadWindow(const AStartFrame, AValidFrames: Integer;
      var ASamples: TAudioSamples); override;
  end;

constructor TRegionAnalysisSource.Create(const AClip: TAudioClip;
  const AStart, ACount: Integer);
begin
  inherited Create(AClip.SampleRate, AClip.Channels, ACount);
  FClip := AClip;
  FStart := AStart;
end;

procedure TRegionAnalysisSource.ReadWindow(const AStartFrame, AValidFrames: Integer;
  var ASamples: TAudioSamples);
var
  LFrame: Integer;
  LChannel: Integer;
begin
  if (AStartFrame < 0) or (AValidFrames < 1) or
    (AStartFrame > FrameCount - AValidFrames) then
  begin
    raise EAudio.Create('Tonal analysis window exceeds its region');
  end;
  SetLength(ASamples, AValidFrames * Channels);
  for LFrame := 0 to AValidFrames - 1 do
  begin
    for LChannel := 0 to Channels - 1 do
    begin
      ASamples[LFrame * Channels + LChannel] :=
        FClip.SampleAt(FStart + AStartFrame + LFrame, LChannel);
    end;
  end;
end;

function AdmitWaveKeyRegions(const AClip: TAudioClip; const AGrid: TMusicGridFrames;
  const ARegions: TTonalKeyRegions; const AOptions: TAnalysisOptions): TTonalRegionAdmissions;
var
  LCandidate: TTonalRegionAdmissions;
  LSource: TRegionAnalysisSource;
  LFeatures: TAudioFeatures;
  LIndex: Integer;
  LNextCell: Integer;
  LFeatureCount: Integer;
  LTotalFeatures: Int64;
  LWork: Int64;
  LTotalWork: Int64;
begin
  if (AClip = nil) or (AGrid = nil) then
  begin
    raise EAudio.Create('Local tonal admission requires a clip and source grid');
  end;
  if (AGrid.SampleRate <> AClip.SampleRate) or (AGrid.SourceFrames <> AClip.FrameCount) or
    (Length(ARegions) < 1) or (Length(ARegions) > AGrid.CellCount) then
  begin
    raise EAudio.Create('Local tonal regions disagree with source geometry');
  end;
  SetLength(LCandidate, Length(ARegions));
  LNextCell := 0;
  LTotalFeatures := 0;
  LTotalWork := 0;
  for LIndex := 0 to High(ARegions) do
  begin
    MakeKeyContext(ARegions[LIndex].Key.Root, ARegions[LIndex].Key.Mode);
    if (ARegions[LIndex].FirstCell <> LNextCell) or (ARegions[LIndex].CellCount < 1) or
      (ARegions[LIndex].CellCount > AGrid.CellCount - LNextCell) then
    begin
      raise EAudio.Create('Local tonal regions must partition the source grid in order');
    end;
    LCandidate[LIndex].Region := ARegions[LIndex];
    LCandidate[LIndex].StartFrame := AGrid.BoundaryAt(LNextCell);
    Inc(LNextCell, ARegions[LIndex].CellCount);
    LCandidate[LIndex].EndFrame := AGrid.BoundaryAt(LNextCell);
    PlanAudioAnalysis(LCandidate[LIndex].EndFrame - LCandidate[LIndex].StartFrame,
      AClip.Channels, AOptions, LFeatureCount, LWork);
    Inc(LTotalFeatures, LFeatureCount);
    Inc(LTotalWork, LWork);
    if (LTotalFeatures > MaximumAnalysisFrames) or (LTotalWork > MaximumAnalysisWork) then
    begin
      raise EAudio.Create('Local tonal regions exceed aggregate analysis budgets');
    end;
  end;
  if LNextCell <> AGrid.CellCount then
  begin
    raise EAudio.Create('Local tonal regions leave uncovered context cells');
  end;
  for LIndex := 0 to High(LCandidate) do
  begin
    LSource := TRegionAnalysisSource.Create(AClip, LCandidate[LIndex].StartFrame,
      LCandidate[LIndex].EndFrame - LCandidate[LIndex].StartFrame);
    try
      LFeatures := AnalyzeAudioSource(LSource, AOptions);
      LCandidate[LIndex].Weights := FeaturePitchClassWeights(LFeatures, AOptions, LSource.FrameCount);
      LCandidate[LIndex].Tonal := AdmitTonalContext(LCandidate[LIndex].Weights,
        ARegions[LIndex].Key);
    finally
      LSource.Free;
    end;
  end;
  Result := LCandidate;
end;

function AdmitPulseRange(const AFrames: TBeatFrames; const ASampleRate,
  ASourceFrames, AFirstPulse, ALastPulse, ATicksPerQuarter, AStepTicks: Integer;
  const AKey: TKeyContext): TBeatTrackAdmission;
var
  LResult: TBeatTrackAdmission;
  LIndex: Integer;
  LCellsPerBeat: Integer;
  LCell: Integer;
  LTempo: Integer;
  LTime: Int64;
  LPreviousTime: Int64;
  LClock: TTempoMap;
begin
  ValidateAudioFormat(ASampleRate, 1);
  MakeKeyContext(AKey.Root, AKey.Mode);
  if (ASourceFrames < 1) or (ASourceFrames > MaximumClipSamples) or
    (Length(AFrames) > MaximumBeatFrames) or
    (AFirstPulse < 0) or (ALastPulse <= AFirstPulse) or
    (ALastPulse >= Length(AFrames)) or
    (ATicksPerQuarter < 1) or (AStepTicks < 1) then
  begin
    raise EAudio.Create('Track admission requires a valid pulse range, source and clock');
  end;
  if ATicksPerQuarter mod AStepTicks <> 0 then
  begin
    raise EAudio.Create('Track admission step must divide a quarter note');
  end;
  LCellsPerBeat := ATicksPerQuarter div AStepTicks;
  if (Int64(ALastPulse - AFirstPulse) * LCellsPerBeat > MaximumContextCells) or
    (Int64(ALastPulse - AFirstPulse) * ATicksPerQuarter > High(Integer)) then
  begin
    raise EAudio.Create('Track admission exceeds the context or tick budget');
  end;
  LResult := Default(TBeatTrackAdmission);
  LResult.SourceStartFrame := AFrames[AFirstPulse];
  LResult.SourceEndFrame := AFrames[ALastPulse];
  LResult.Grid.TicksPerQuarter := ATicksPerQuarter;
  LResult.Grid.StepTicks := AStepTicks;
  SetLength(LResult.Grid.Keys, (ALastPulse - AFirstPulse) * LCellsPerBeat);
  SetLength(LResult.Grid.Tempos, Length(LResult.Grid.Keys));
  SetLength(LResult.Changes, ALastPulse - AFirstPulse);
  SetLength(LResult.BoundaryErrors, ALastPulse - AFirstPulse + 1);
  LPreviousTime := 0;
  for LIndex := AFirstPulse to ALastPulse do
  begin
    if (AFrames[LIndex] < 0) or (AFrames[LIndex] >= ASourceFrames) then
    begin
      raise EAudio.Create('Selected pulse exceeds source or window bounds');
    end;
    if LIndex > AFirstPulse then
    begin
      if AFrames[LIndex] <= AFrames[LIndex - 1] then
      begin
        raise EAudio.Create('Selected pulse frames and owning windows must be ordered');
      end;
      LTime := (Int64(AFrames[LIndex] - LResult.SourceStartFrame) * 1000000 +
        ASampleRate div 2) div ASampleRate;
      if (LTime - LPreviousTime < 1) or
        (LTime - LPreviousTime > MaximumTempoMicroseconds) then
      begin
        raise EAudio.Create('Selected pulse interval exceeds integer tempo bounds');
      end;
      LTempo := LTime - LPreviousTime;
      LResult.Changes[LIndex - AFirstPulse - 1] :=
        MakeTempoChange((LIndex - AFirstPulse - 1) * ATicksPerQuarter, LTempo);
      for LCell := (LIndex - AFirstPulse - 1) * LCellsPerBeat to
        (LIndex - AFirstPulse) * LCellsPerBeat - 1 do
      begin
        LResult.Grid.Keys[LCell] := AKey;
        LResult.Grid.Tempos[LCell] := LTempo;
      end;
      LPreviousTime := LTime;
    end;
  end;
  ValidateContextGrid(LResult.Grid);
  LClock := TTempoMap.Create(ATicksPerQuarter,
    (ALastPulse - AFirstPulse) * ATicksPerQuarter, LResult.Changes);
  try
    for LIndex := 0 to High(LResult.BoundaryErrors) do
    begin
      LResult.BoundaryErrors[LIndex] := LClock.FrameAtTick(LIndex * ATicksPerQuarter,
        ASampleRate) + LResult.SourceStartFrame - AFrames[AFirstPulse + LIndex];
    end;
  finally
    LClock.Free;
  end;
  Result := LResult;
end;

function AdmitBeatTrackRange(const ATrack: TBeatTrack; const ASampleRate,
  ASourceFrames, AFirstPulse, ALastPulse, ATicksPerQuarter, AStepTicks: Integer;
  const AKey: TKeyContext): TBeatTrackAdmission;
var
  LResult: TBeatTrackAdmission;
  LIndex: Integer;
  LWindow: Integer;
  LPreviousWindow: Integer;
  LCheckWindow: Integer;
begin
  if (Length(ATrack.Frames) <> Length(ATrack.FrameWindows)) or
    (Length(ATrack.Frames) <> Length(ATrack.GridFrames)) then
  begin
    raise EAudio.Create('Track admission requires complete pulse provenance');
  end;
  LResult := AdmitPulseRange(ATrack.Frames, ASampleRate, ASourceFrames,
    AFirstPulse, ALastPulse, ATicksPerQuarter, AStepTicks, AKey);
  LPreviousWindow := -1;
  for LIndex := AFirstPulse to ALastPulse do
  begin
    LWindow := ATrack.FrameWindows[LIndex];
    if (LWindow < 0) or (LWindow >= Length(ATrack.Windows)) then
    begin
      raise EAudio.Create('Selected pulse exceeds window bounds');
    end;
    if (ATrack.Windows[LWindow].SelectedCandidate < 0) or
      (ATrack.Windows[LWindow].SelectedCandidate >=
        Length(ATrack.Windows[LWindow].Analysis.Candidates)) or
      (ATrack.GridFrames[LIndex] < ATrack.Windows[LWindow].OwnerStartFrame) or
      (ATrack.GridFrames[LIndex] >= ATrack.Windows[LWindow].OwnerEndFrame) then
    begin
      raise EAudio.Create('Selected pulse lacks its owned candidate evidence');
    end;
    if LIndex > AFirstPulse then
    begin
      if LWindow < LPreviousWindow then
      begin
        raise EAudio.Create('Selected pulse windows must be ordered');
      end;
      for LCheckWindow := LPreviousWindow + 1 to LWindow do
      begin
        if (ATrack.Windows[LCheckWindow].SelectedCandidate < 0) or
          ATrack.Windows[LCheckWindow].StartsNewPath or ATrack.Windows[LCheckWindow].JoinUncertain then
        begin
          raise EAudio.Create('Select separate pulse ranges around track gaps, restarts or uncertain joins');
        end;
      end;
    end;
    LPreviousWindow := LWindow;
  end;
  Result := LResult;
end;

function AdmitBeatClockRange(const AWindows: TBeatClockWindows;
  const AObservations: TBeatObservations; const AOptions: TBeatClockOptions;
  const ASampleRate, ASourceFrames, AFirstPulse, ALastPulse,
  ATicksPerQuarter, AStepTicks: Integer; const AKey: TKeyContext): TBeatTrackAdmission;
var
  LClock: TBeatClock;
  LResult: TBeatTrackAdmission;
  LStart: Integer;
  LEnd: Integer;
  LIndex: Integer;
begin
  LClock := ReconstructBeatClock(AWindows, AObservations, ASampleRate, ASourceFrames, AOptions);
  LResult := AdmitPulseRange(LClock.Frames, ASampleRate, ASourceFrames,
    AFirstPulse, ALastPulse, ATicksPerQuarter, AStepTicks, AKey);
  for LIndex := LClock.FrameWindows[AFirstPulse] + 1 to LClock.FrameWindows[ALastPulse] do
  begin
    if not AWindows[LIndex].HasPulse or AWindows[LIndex].StartsNewRun then
    begin
      raise EAudio.Create('Select separate clock ranges around missing windows or restarts');
    end;
  end;
  LStart := Min(LClock.RawFrames[AFirstPulse], LClock.Frames[AFirstPulse]);
  LEnd := Max(LClock.RawFrames[ALastPulse], LClock.Frames[ALastPulse]);
  for LIndex := 0 to High(LClock.Segments) do
  begin
    if (LClock.Segments[LIndex].StartFrame < LEnd) and
      (LClock.Segments[LIndex].EndFrame > LStart) and
      (not LClock.Segments[LIndex].Available or LClock.Segments[LIndex].Ambiguous) then
    begin
      raise EAudio.Create('Selected clock range crosses unavailable or ambiguous phase evidence');
    end;
  end;
  Result := LResult;
end;

function AdmitBeatContext(const ACandidate: TBeatGridCandidate;
  const ASampleRate, ASourceFrames, ATicksPerQuarter, AStepTicks: Integer;
  const AKey: TKeyContext): TBeatContextAdmission;
var
  LResult: TBeatContextAdmission;
  LTempo: Double;
  LPeriod: Double;
  LTick: Double;
  LStart: Int64;
begin
  ValidateAudioFormat(ASampleRate, 1);
  RequireFinite(ACandidate.PeriodFrames, 'Selected beat period');
  RequireFinite(ACandidate.PhaseFrame, 'Selected beat phase');
  LTempo := MaximumTempoMicroseconds;
  LPeriod := LTempo * ASampleRate / 1000000;
  if (ATicksPerQuarter < 1) or (ACandidate.PeriodFrames <= 0) or
    (ACandidate.PeriodFrames > LPeriod) or
    (ACandidate.PhaseFrame < 0) or (ACandidate.PhaseFrame >= ACandidate.PeriodFrames) then
  begin
    raise EAudio.Create('Selected beat period/phase exceeds the source clock contract');
  end;
  LTempo := ACandidate.PeriodFrames * 1000000 / ASampleRate;
  LResult := Default(TBeatContextAdmission);
  LResult.TempoMicroseconds := Floor(LTempo + 0.5);
  MakeTempoChange(0, LResult.TempoMicroseconds);
  LPeriod := LResult.TempoMicroseconds;
  LPeriod := LPeriod * ASampleRate / 1000000;
  LTick := ACandidate.PhaseFrame / LPeriod * ATicksPerQuarter;
  LStart := Floor(LTick + 0.5);
  if LStart > High(Integer) then
  begin
    raise EAudio.Create('Selected phase exceeds the source tick extent');
  end;
  LResult.Scope := WaveContextScope(ASampleRate, ASourceFrames, LResult.TempoMicroseconds,
    ATicksPerQuarter, AStepTicks, AKey, Integer(LStart));
  LResult.PhaseErrorFrames := LResult.Scope.StartFrameFloor - ACandidate.PhaseFrame;
  LResult.PeriodErrorFrames := LPeriod - ACandidate.PeriodFrames;
  Result := LResult;
end;

function AdmitTonalContext(const AWeights: TPitchClassWeights;
  const ASelectedKey: TKeyContext): TTonalContextAdmission;
var
  LCandidate: TTonalContextAdmission;
  LIndex: Integer;
begin
  LCandidate := Default(TTonalContextAdmission);
  LCandidate.Key := MakeKeyContext(ASelectedKey.Root, ASelectedKey.Mode);
  LCandidate.SelectedRank := -1;
  LCandidate.Report := RankDiatonicFits(AWeights);
  if ASelectedKey.Root >= 0 then
  begin
    if LCandidate.Report.CandidateCount = 0 then
    begin
      raise EAudio.Create('A measured key selection requires nonzero tonal evidence');
    end;
    for LIndex := 0 to LCandidate.Report.CandidateCount - 1 do
    begin
      if (LCandidate.Report.Fits[LIndex].Root = ASelectedKey.Root) and
        (LCandidate.Report.Fits[LIndex].Mode = ASelectedKey.Mode) then
      begin
        LCandidate.SelectedRank := LIndex;
        Break;
      end;
    end;
    if LCandidate.SelectedRank < 0 then
    begin
      raise EAudio.Create('Selected key is outside the measured candidate vocabulary');
    end;
  end;
  Result := LCandidate;
end;

function WaveContextScope(const ASampleRate, ASourceFrames, ATempoMicroseconds,
  ATicksPerQuarter, AStepTicks: Integer; const AKey: TKeyContext;
  const AStartTick: Integer): TWaveContextScope;
var
  LCandidate: TWaveContextScope;
  LClock: TTempoMap;
  LLow: Integer;
  LHigh: Integer;
  LMiddle: Integer;
  LCount: Integer;
  LEndTick: Integer;
  LIndex: Integer;
begin
  ValidateAudioFormat(ASampleRate, 1);
  MakeKeyContext(AKey.Root, AKey.Mode);
  if (ASourceFrames < 1) or (ASourceFrames > MaximumClipSamples) or
    (ATicksPerQuarter < 1) or (AStepTicks < 1) or (AStartTick < 0) then
  begin
    raise EAudio.Create('WAV context requires bounded source frames and positive PPQ/step');
  end;
  LClock := TTempoMap.Create(ATicksPerQuarter, High(Integer),
    [MakeTempoChange(0, ATempoMicroseconds)]);
  try
    if LClock.FrameAtTick(High(Integer), ASampleRate, frCeiling) <= ASourceFrames then
    begin
      raise EAudio.Create('Declared source clock exceeds supported tick extent');
    end;
    LLow := 0;
    LHigh := High(Integer);
    while LLow < LHigh do
    begin
      LMiddle := LLow + (LHigh - LLow) div 2 + 1;
      if LClock.FrameAtTick(LMiddle, ASampleRate, frCeiling) <= ASourceFrames then
      begin
        LLow := LMiddle;
      end
      else
      begin
        LHigh := LMiddle - 1;
      end;
    end;
    if AStartTick > LLow then
    begin
      raise EAudio.Create('WAV context origin lies beyond the complete source extent');
    end;
    LCount := (LLow - AStartTick) div AStepTicks;
    if (LCount < 1) or (LCount > MaximumContextCells) then
    begin
      raise EAudio.Create('Source clock must admit 1..65536 complete context cells');
    end;
    LEndTick := AStartTick + LCount * AStepTicks;
    LCandidate := Default(TWaveContextScope);
    LCandidate.Grid.TicksPerQuarter := ATicksPerQuarter;
    LCandidate.Grid.StartTick := AStartTick;
    LCandidate.Grid.StepTicks := AStepTicks;
    SetLength(LCandidate.Grid.Keys, LCount);
    SetLength(LCandidate.Grid.Tempos, LCount);
    for LIndex := 0 to LCount - 1 do
    begin
      LCandidate.Grid.Keys[LIndex] := AKey;
      LCandidate.Grid.Tempos[LIndex] := ATempoMicroseconds;
    end;
    LCandidate.StartFrameFloor := Integer(LClock.FrameAtTick(AStartTick, ASampleRate, frFloor));
    LCandidate.StartFrameCeiling := Integer(LClock.FrameAtTick(AStartTick, ASampleRate, frCeiling));
    LCandidate.EndFrameFloor := Integer(LClock.FrameAtTick(LEndTick, ASampleRate, frFloor));
    LCandidate.EndFrameCeiling := Integer(LClock.FrameAtTick(LEndTick, ASampleRate, frCeiling));
    LCandidate.UnassignedWholeFrames := ASourceFrames - LCandidate.EndFrameCeiling;
    ValidateContextGrid(LCandidate.Grid);
    Result := LCandidate;
  finally
    LClock.Free;
  end;
end;

end.
