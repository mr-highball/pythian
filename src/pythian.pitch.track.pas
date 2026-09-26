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

unit pythian.pitch.track;

{$mode delphi}
{$H+}

interface

uses
  pythian.audio,
  pythian.pitch,
  pythian.time;

const
  MaximumPitchTrackWindows = 8192;
  MaximumPitchArticulationEvents = 65536;

type
  TPitchSpanKind = (pskPitch, pskSilence, pskUnknown);
  TPitchRun = record
    Note: Integer;
    FirstWindow: Integer;
    WindowCount: Integer;
    StartFrame: Integer;
    EndFrame: Integer;
  end;
  TPitchRuns = array of TPitchRun;
  TPitchSpan = record
    Kind: TPitchSpanKind;
    Note: Integer; { -1 for silence/unknown; Kind preserves their distinction. }
    FirstWindow: Integer;
    WindowCount: Integer;
    StartFrame: Integer;
    EndFrame: Integer;
  end;
  TPitchSpans = array of TPitchSpan;
  TTimedPitchSpan = record
    Kind: TPitchSpanKind;
    Note: Integer;
    StartTick: Integer;
    EndTick: Integer;
  end;
  TTimedPitchSpans = array of TTimedPitchSpan;
  TPitchAttackTicks = array of Integer;
  TPitchTrackOptions = record
    Pitch: TPitchOptions;
    HopFrames: Integer;
    MinimumRunWindows: Integer;
    MaximumCents: Double;
  end;

  TPitchTrackEvidence = record
    WindowFrames: Integer; { Zero and empty estimates means unavailable. }
    Channel: Integer;
    Options: TPitchTrackOptions;
    Estimates: TPitchEstimates;
  end;

  { Owned immutable measurements. Window centers define hop-sized timing bins.
    These are estimates of stable pitch extent, not exact note-on/off times.
    Unknown windows and rejected short runs never join otherwise separate runs. }
  TPitchTrack = class
  private
    FOptions: TPitchTrackOptions;
    FSampleRate: Integer;
    FFrameCount: Integer;
    FChannel: Integer;
    FWindowFrames: Integer;
    FEstimates: TPitchEstimates;
    FNotes: TPitchNotes;
    FRuns: TPitchRuns;
    FSpans: TPitchSpans;
    function InitializeGeometry(const ASampleRate, AChannels, AFrameCount, AChannel: Integer;
      const AOptions: TPitchTrackOptions; const AWindowFrames: Integer): Integer;
    procedure BuildSpans;
    function GetWindowCount: Integer;
    function GetRunCount: Integer;
  public
    { Zero window selects the minimum covering the requested frequency range.
      Explicit windows trade temporal resolution for longer difference integration;
      they retain the same estimator, hop, admission thresholds and work budget. }
    constructor Create(const AClip: TAudioClip; const AChannel: Integer;
      const AOptions: TPitchTrackOptions; const AWindowFrames: Integer = 0);
    constructor CreateFromEvidence(const AEvidence: TPitchTrackEvidence;
      const ASampleRate, AChannels, AFrameCount: Integer);
    function CopyEvidence: TPitchTrackEvidence;
    function EstimateAt(const AIndex: Integer): TPitchEstimate;
    function NoteAt(const AIndex: Integer): Integer;
    function RunAt(const AIndex: Integer): TPitchRun;
    function CopyRuns: TPitchRuns;
    function CopySpans: TPitchSpans;
    { Intersect measured bins with the explicit source scope, then map physical
      boundaries to the first PPQ tick whose floor frame reaches them. No tempo
      inference, extrapolated evidence, or merging of collapsed intervals. }
    function TimedSpans(const AClock: TTempoMap; const ASourceFrameOffset,
      AStartTick, AEndTick: Integer): TTimedPitchSpans;
    property Options: TPitchTrackOptions read FOptions;
    property SampleRate: Integer read FSampleRate;
    property FrameCount: Integer read FFrameCount;
    property Channel: Integer read FChannel;
    property WindowFrames: Integer read FWindowFrames;
    property WindowCount: Integer read GetWindowCount;
    property RunCount: Integer read GetRunCount;
  end;

function DefaultPitchTrackOptions(const ASampleRate: Integer): TPitchTrackOptions;
{ Explicit attack ownership policy: split only inside known pitched intervals.
  Boundary attacks do not create zero gates; attacks in gaps, unknown or silence
  do not create notes. Inputs must be ordered, non-overlapping and canonical;
  attack ticks must be nonnegative and strictly increasing. No pitch/timing
  inference or merging. Returned spans are detached; failure preserves the
  previously assigned result. Each input/output is bounded to 65536 entries. }
function RearticulatePitchSpans(const ASpans: TTimedPitchSpans;
  const AAttacks: TPitchAttackTicks): TTimedPitchSpans;

implementation

uses
  Math,
  pythian.music.grid.frames;

function RearticulatePitchSpans(const ASpans: TTimedPitchSpans;
  const AAttacks: TPitchAttackTicks): TTimedPitchSpans;
var
  LResult: TTimedPitchSpans;
  LIndex: Integer;
  LAttack: Integer;
  LStart: Integer;
  LCount: Integer;

  procedure Append(const ASpan: TTimedPitchSpan; const AStart, AEnd: Integer);
  begin
    if LCount >= MaximumPitchArticulationEvents then
    begin
      raise EAudio.Create('Articulated pitch spans exceed event budget');
    end;
    LResult[LCount] := ASpan;
    LResult[LCount].StartTick := AStart;
    LResult[LCount].EndTick := AEnd;
    Inc(LCount);
  end;

begin
  if (Length(ASpans) > MaximumPitchArticulationEvents) or
    (Length(AAttacks) > MaximumPitchArticulationEvents) then
  begin
    raise EAudio.Create('Pitch articulation inputs exceed event budget');
  end;
  for LIndex := 0 to High(ASpans) do
  begin
    if not (ASpans[LIndex].Kind in [pskPitch, pskSilence, pskUnknown]) or
      (ASpans[LIndex].StartTick < 0) or
      (ASpans[LIndex].EndTick <= ASpans[LIndex].StartTick) or
      ((ASpans[LIndex].Kind = pskPitch) and
        ((ASpans[LIndex].Note < 0) or (ASpans[LIndex].Note > 127))) or
      ((ASpans[LIndex].Kind <> pskPitch) and (ASpans[LIndex].Note <> -1)) then
    begin
      raise EAudio.Create('Pitch articulation requires canonical positive intervals');
    end;
    if (LIndex > 0) and (ASpans[LIndex].StartTick < ASpans[LIndex - 1].EndTick) then
    begin
      raise EAudio.Create('Pitch articulation intervals must be ordered without overlap');
    end;
  end;
  for LIndex := 0 to High(AAttacks) do
  begin
    if (AAttacks[LIndex] < 0) or
      ((LIndex > 0) and (AAttacks[LIndex] <= AAttacks[LIndex - 1])) then
    begin
      raise EAudio.Create('Pitch attacks must be nonnegative and strictly increasing');
    end;
  end;
  SetLength(LResult, Min(MaximumPitchArticulationEvents, Length(ASpans) + Length(AAttacks)));
  LAttack := 0;
  LCount := 0;
  for LIndex := 0 to High(ASpans) do
  begin
    LStart := ASpans[LIndex].StartTick;
    while (LAttack < Length(AAttacks)) and (AAttacks[LAttack] <= LStart) do
    begin
      Inc(LAttack);
    end;
    while (LAttack < Length(AAttacks)) and (AAttacks[LAttack] < ASpans[LIndex].EndTick) do
    begin
      if ASpans[LIndex].Kind = pskPitch then
      begin
        Append(ASpans[LIndex], LStart, AAttacks[LAttack]);
        LStart := AAttacks[LAttack];
      end;
      Inc(LAttack);
    end;
    Append(ASpans[LIndex], LStart, ASpans[LIndex].EndTick);
  end;
  SetLength(LResult, LCount);
  Result := LResult;
end;

function TPitchTrack.TimedSpans(const AClock: TTempoMap; const ASourceFrameOffset,
  AStartTick, AEndTick: Integer): TTimedPitchSpans;
var
  LGrid: TMusicGridFrames;
  LFirst: Integer;
  LLast: Integer;
  LStart: Integer;
  LEnd: Integer;
  LIndex: Integer;
  LCount: Integer;
begin
  Result := nil;
  if (AStartTick < 0) or (AEndTick <= AStartTick) then
  begin
    raise EAudio.Create('Timed pitch spans require a positive explicit tick scope');
  end;
  LGrid := TMusicGridFrames.Create(AClock, FSampleRate, FFrameCount,
    ASourceFrameOffset, AStartTick, AEndTick - AStartTick, 1);
  try
    LFirst := LGrid.BoundaryAt(0);
    LLast := LGrid.BoundaryAt(1);
    SetLength(Result, Length(FSpans));
    LCount := 0;
    for LIndex := 0 to High(FSpans) do
    begin
      LStart := Max(LFirst, FSpans[LIndex].StartFrame);
      LEnd := Min(LLast, FSpans[LIndex].EndFrame);
      if LEnd <= LStart then
      begin
        Continue;
      end;
      Result[LCount].Kind := FSpans[LIndex].Kind;
      Result[LCount].Note := FSpans[LIndex].Note;
      Result[LCount].StartTick := Max(AStartTick,
        AClock.NextGridTick(LStart - ASourceFrameOffset, FSampleRate, 1));
      Result[LCount].EndTick := Min(AEndTick,
        AClock.NextGridTick(LEnd - ASourceFrameOffset, FSampleRate, 1));
      if Result[LCount].EndTick <= Result[LCount].StartTick then
      begin
        raise EAudio.Create('Pitch span collapses below source PPQ resolution');
      end;
      Inc(LCount);
    end;
    SetLength(Result, LCount);
  finally
    LGrid.Free;
  end;
end;

function DefaultPitchTrackOptions(const ASampleRate: Integer): TPitchTrackOptions;
begin
  ValidateAudioFormat(ASampleRate, 1);
  Result.Pitch := DefaultPitchOptions;
  Result.HopFrames := Max(1, ASampleRate div 100);
  Result.MinimumRunWindows := 3;
  Result.MaximumCents := 25;
end;

function TPitchTrack.InitializeGeometry(const ASampleRate, AChannels,
  AFrameCount, AChannel: Integer; const AOptions: TPitchTrackOptions;
  const AWindowFrames: Integer): Integer;
var
  LWork: Int64;
  LCount: Integer;
begin
  PitchEstimateWork(MaximumPitchWindowFrames, ASampleRate, AChannels,
    AChannel, AOptions.Pitch);
  FWindowFrames := AWindowFrames;
  if FWindowFrames = 0 then
  begin
    FWindowFrames := 2 * (Ceil(ASampleRate / AOptions.Pitch.MinimumHz) + 1);
  end;
  LWork := PitchEstimateWork(FWindowFrames, ASampleRate, AChannels,
    AChannel, AOptions.Pitch);
  RequireFinite(AOptions.MaximumCents, 'Pitch track tuning tolerance');
  if (AOptions.HopFrames < 1) or (AOptions.HopFrames > FWindowFrames) or
    (AOptions.MinimumRunWindows < 1) or
    (AOptions.MinimumRunWindows > MaximumPitchTrackWindows) or
    (AOptions.MaximumCents < 0) or (AOptions.MaximumCents > 50) then
  begin
    raise EAudio.Create('Pitch track hop, minimum run or tuning tolerance exceeds bounds');
  end;
  if AFrameCount < FWindowFrames then
  begin
    raise EAudio.Create('Pitch track source is shorter than one complete window');
  end;
  LCount := 1 + (AFrameCount - FWindowFrames) div AOptions.HopFrames;
  if (LCount > MaximumPitchTrackWindows) or (LWork * LCount > MaximumPitchBatchWork) then
  begin
    raise EAudio.Create('Pitch track exceeds measurement budget; select a shorter excerpt or larger hop');
  end;
  FOptions := AOptions;
  FSampleRate := ASampleRate;
  FFrameCount := AFrameCount;
  FChannel := AChannel;
  Result := LCount;
end;

constructor TPitchTrack.Create(const AClip: TAudioClip; const AChannel: Integer;
  const AOptions: TPitchTrackOptions; const AWindowFrames: Integer);
var
  LCount: Integer;
  LIndex: Integer;
  LFrame: Integer;
  LSamples: TAudioSamples;
begin
  inherited Create;
  if AClip = nil then
  begin
    raise EAudio.Create('Pitch track requires source PCM');
  end;
  LCount := InitializeGeometry(AClip.SampleRate, AClip.Channels, AClip.FrameCount,
    AChannel, AOptions, AWindowFrames);
  SetLength(FEstimates, LCount);
  SetLength(LSamples, FWindowFrames);
  for LIndex := 0 to LCount - 1 do
  begin
    for LFrame := 0 to FWindowFrames - 1 do
    begin
      LSamples[LFrame] := AClip.SampleAt(LIndex * AOptions.HopFrames + LFrame, AChannel);
    end;
    FEstimates[LIndex] := EstimatePitch(LSamples, FSampleRate, 1, 0, AOptions.Pitch);
  end;
  BuildSpans;
end;

constructor TPitchTrack.CreateFromEvidence(const AEvidence: TPitchTrackEvidence;
  const ASampleRate, AChannels, AFrameCount: Integer);
var
  LCount: Integer;
begin
  inherited Create;
  if AEvidence.WindowFrames < 1 then
  begin
    raise EAudio.Create('Saved pitch track requires a positive analysis window');
  end;
  LCount := InitializeGeometry(ASampleRate, AChannels, AFrameCount,
    AEvidence.Channel, AEvidence.Options, AEvidence.WindowFrames);
  if (AEvidence.WindowFrames <> FWindowFrames) or
    (Length(AEvidence.Estimates) <> LCount) then
  begin
    raise EAudio.Create('Saved pitch track windows disagree with source geometry');
  end;
  FEstimates := Copy(AEvidence.Estimates);
  BuildSpans;
end;

function TPitchTrack.CopyEvidence: TPitchTrackEvidence;
begin
  Result.WindowFrames := FWindowFrames;
  Result.Channel := FChannel;
  Result.Options := FOptions;
  Result.Estimates := Copy(FEstimates);
end;

procedure TPitchTrack.BuildSpans;
var
  LCount: Integer;
  LIndex: Integer;
  LStart: Integer;
  LEnd: Integer;
  LRun: TPitchRun;
  LSpan: TPitchSpan;
  LLabels: TPitchNotes;
begin
  LCount := Length(FEstimates);
  SetLength(FNotes, LCount);
  for LIndex := 0 to LCount - 1 do
  begin
    ValidatePitchEstimate(FEstimates[LIndex], FSampleRate, FOptions.Pitch);
    FNotes[LIndex] := AdmitPitchNote(FEstimates[LIndex], FOptions.MaximumCents);
  end;
  LStart := 0;
  LLabels := Copy(FNotes);
  while LStart < LCount do
  begin
    if FNotes[LStart] < 0 then
    begin
      Inc(LStart);
      Continue;
    end;
    LEnd := LStart + 1;
    while (LEnd < LCount) and (FNotes[LEnd] = FNotes[LStart]) do
    begin
      Inc(LEnd);
    end;
    if LEnd - LStart >= FOptions.MinimumRunWindows then
    begin
      LRun.Note := FNotes[LStart];
      LRun.FirstWindow := LStart;
      LRun.WindowCount := LEnd - LStart;
      LRun.StartFrame := LStart * FOptions.HopFrames +
        FWindowFrames div 2 - FOptions.HopFrames div 2;
      LRun.EndFrame := LRun.StartFrame + LRun.WindowCount * FOptions.HopFrames;
      SetLength(FRuns, Length(FRuns) + 1);
      FRuns[High(FRuns)] := LRun;
    end
    else
    begin
      for LIndex := LStart to LEnd - 1 do
      begin
        LLabels[LIndex] := -1;
      end;
    end;
    LStart := LEnd;
  end;
  for LIndex := 0 to LCount - 1 do
  begin
    if FEstimates[LIndex].Status = psSilence then
    begin
      LLabels[LIndex] := -2;
    end;
  end;
  LStart := 0;
  while LStart < LCount do
  begin
    LEnd := LStart + 1;
    while (LEnd < LCount) and (LLabels[LEnd] = LLabels[LStart]) do
    begin
      Inc(LEnd);
    end;
    LSpan.Kind := pskPitch;
    LSpan.Note := LLabels[LStart];
    if LSpan.Note < 0 then
    begin
      LSpan.Kind := pskUnknown;
      if LSpan.Note = -2 then
      begin
        LSpan.Kind := pskSilence;
      end;
      LSpan.Note := -1;
    end;
    LSpan.FirstWindow := LStart;
    LSpan.WindowCount := LEnd - LStart;
    LSpan.StartFrame := LStart * FOptions.HopFrames +
      FWindowFrames div 2 - FOptions.HopFrames div 2;
    LSpan.EndFrame := LSpan.StartFrame + LSpan.WindowCount * FOptions.HopFrames;
    SetLength(FSpans, Length(FSpans) + 1);
    FSpans[High(FSpans)] := LSpan;
    LStart := LEnd;
  end;
end;

function TPitchTrack.GetWindowCount: Integer;
begin
  Result := Length(FNotes);
end;

function TPitchTrack.GetRunCount: Integer;
begin
  Result := Length(FRuns);
end;

function TPitchTrack.EstimateAt(const AIndex: Integer): TPitchEstimate;
begin
  if (AIndex < 0) or (AIndex >= WindowCount) then
  begin
    raise EAudio.Create('Pitch track window index out of bounds');
  end;
  Result := FEstimates[AIndex];
end;

function TPitchTrack.NoteAt(const AIndex: Integer): Integer;
begin
  EstimateAt(AIndex);
  Result := FNotes[AIndex];
end;

function TPitchTrack.RunAt(const AIndex: Integer): TPitchRun;
begin
  if (AIndex < 0) or (AIndex >= RunCount) then
  begin
    raise EAudio.Create('Pitch track run index out of bounds');
  end;
  Result := FRuns[AIndex];
end;

function TPitchTrack.CopyRuns: TPitchRuns;
begin
  Result := Copy(FRuns);
end;

function TPitchTrack.CopySpans: TPitchSpans;
begin
  Result := Copy(FSpans);
end;

end.
