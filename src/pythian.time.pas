(*
MIT License

Copyright (c) 2021 mr-highball
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
unit pythian.time;

{$mode delphi}
{$H+}

interface

uses
  pythian.audio;

const
  MusicTimingVersion = 1;
  IncrementalTimingVersion = 1;
  MaximumTempoChanges = 65536;
  MaximumTempoMicroseconds = $FFFFFF;

type
  TTempoChange = record
    Tick: Integer;
    MicrosecondsPerQuarter: Integer;
  end;
  TTempoChanges = array of TTempoChange;

  TTempoInterval = record
    StartTick: Integer;
    LengthTicks: Integer;
    MicrosecondsPerQuarter: Integer;
  end;
  TTempoIntervals = array of TTempoInterval;

  TMusicTime = record
    WholeMicroseconds: Int64;
    FractionNumerator: Integer;
    Denominator: Integer;
  end;
  TFrameRounding = (frFloor, frCeiling);

  TTempoClockSnapshot = record
    TicksPerQuarter: Integer;
    SampleRate: Integer;
    TickCount: Int64;
    FrameCount: Int64;
    FractionNumerator: Int64;
  end;

  { Incremental exact PPQ clock for streamed intervals. Configuration is fixed;
    tempo can change at every Advance. Fraction is measured in
    1/(ticksPerQuarter*1000000) sample frames. No wall clock or device calls. }
  TIncrementalTempoClock = class
  strict private
    FState: TTempoClockSnapshot;
  public
    constructor Create(const ATicksPerQuarter, ASampleRate: Integer);
    { Returns the interval's sample frames, carrying all fractional history.
      Invalid input or overflow preserves the complete previous state. }
    function Advance(const ALengthTicks, ATempoMicrosecondsPerQuarter: Integer): Int64;
    { Validates configuration and normalized nonnegative state, not its history.
      Caller must bind persisted snapshots to their source timeline. }
    procedure Restore(const ASnapshot: TTempoClockSnapshot);
    procedure Reset;
    property Snapshot: TTempoClockSnapshot read FState;
  end;

  { Immutable PPQ clock. Tick extents fit Integer, while absolute time and sample
    frames use Int64. Fractional microseconds survive every tempo boundary. }
  TTempoMap = class
  strict private
    FTicksPerQuarter: Integer;
    FLengthTicks: Integer;
    FChanges: TTempoChanges;
    FTimes: array of TMusicTime;
    function GetChangeCount: Integer;
  public
    constructor Create(const ATicksPerQuarter, ALengthTicks: Integer;
      const AChanges: TTempoChanges);
    function TimeAtTick(const ATick: Integer): TMusicTime;
    function FrameAtTick(const ATick, ASampleRate: Integer;
      const ARounding: TFrameRounding = frFloor): Int64;
    function ChangeAt(const AIndex: Integer): TTempoChange;
    function CopyChanges: TTempoChanges;
    { Positive contiguous intervals covering exactly the requested range.
      Changes at the exclusive endpoint belong to the following range. }
    function Intervals(const AStartTick, ALengthTicks: Integer): TTempoIntervals;
    { Finds the first grid tick whose floor-quantized frame is at least AFrame.
      Fails if no such grid boundary remains inside this map. }
    function NextGridTick(const AFrame: Int64;
      const ASampleRate, AGridTicks: Integer): Integer;
    { Detached candidate: keep the entire prefix and override tempo from ATick.
      Frames strictly before AFrozenBeforeFrame must remain committed. }
    function WithTempoFrom(const ATick, AMicrosecondsPerQuarter, ASampleRate: Integer;
      const AFrozenBeforeFrame: Int64): TTempoMap;
    property TicksPerQuarter: Integer read FTicksPerQuarter;
    property LengthTicks: Integer read FLengthTicks;
    property ChangeCount: Integer read GetChangeCount;
  end;

function MakeTempoChange(const ATick, AMicrosecondsPerQuarter: Integer): TTempoChange;
function MusicTimeToFrame(const ATime: TMusicTime; const ASampleRate: Integer;
  const ARounding: TFrameRounding = frFloor): Int64;
{ Floating seconds use a binary64 sample product before explicit floor/ceiling.
  This avoids x87 extended intermediates changing integer boundaries on i386.
  Nonnegative input and result at most 2^53-1; this is separate from exact PPQ
  timing and caller-specific clip/voice budgets. }
function SampleFramesFromSeconds(const ASeconds: Double; const ASampleRate: Integer;
  const ARounding: TFrameRounding = frCeiling): Int64;

implementation

uses
  Math;

const
  MicrosecondsPerSecond = 1000000;

function TTempoMap.Intervals(const AStartTick, ALengthTicks: Integer): TTempoIntervals;
var
  LLow: Integer;
  LHigh: Integer;
  LMiddle: Integer;
  LChange: Integer;
  LTick: Integer;
  LEnd: Integer;
  LNext: Integer;
  LCount: Integer;
begin
  Result := nil;
  if (AStartTick < 0) or (ALengthTicks < 1) or
    (Int64(AStartTick) + ALengthTicks > FLengthTicks) then
  begin
    raise EAudio.Create('Tempo intervals require a positive range within the explicit clock');
  end;
  LEnd := AStartTick + ALengthTicks;
  LLow := 0;
  LHigh := High(FChanges);
  while LLow < LHigh do
  begin
    LMiddle := LLow + (LHigh - LLow + 1) div 2;
    if FChanges[LMiddle].Tick <= AStartTick then
    begin
      LLow := LMiddle;
    end
    else
    begin
      LHigh := LMiddle - 1;
    end;
  end;
  LChange := LLow;
  LHigh := LChange;
  while (LHigh < High(FChanges)) and (FChanges[LHigh + 1].Tick < LEnd) do
  begin
    Inc(LHigh);
  end;
  SetLength(Result, LHigh - LChange + 1);
  LTick := AStartTick;
  LCount := 0;
  while LTick < LEnd do
  begin
    LNext := LEnd;
    if LChange < LHigh then
    begin
      LNext := FChanges[LChange + 1].Tick;
    end;
    Result[LCount].StartTick := LTick;
    Result[LCount].LengthTicks := LNext - LTick;
    Result[LCount].MicrosecondsPerQuarter := FChanges[LChange].MicrosecondsPerQuarter;
    LTick := LNext;
    Inc(LChange);
    Inc(LCount);
  end;
end;

function SampleFramesFromSeconds(const ASeconds: Double; const ASampleRate: Integer;
  const ARounding: TFrameRounding): Int64;
const
  CMaximumExactFrames: Int64 = 9007199254740991;
var
  LFrames: Double;
begin
  ValidateAudioFormat(ASampleRate, 1);
  RequireFinite(ASeconds, 'Sample time');
  if (ASeconds < 0) or (ASeconds > CMaximumExactFrames / ASampleRate) or
    not (ARounding in [frFloor, frCeiling]) then
  begin
    raise EAudio.Create('Sample time exceeds its nonnegative exact-integer range');
  end;
  LFrames := ASeconds * ASampleRate;
  if LFrames > CMaximumExactFrames then
  begin
    raise EAudio.Create('Rounded sample time exceeds its exact-integer range');
  end;
  if ARounding = frCeiling then
  begin
    Result := Ceil(LFrames);
  end
  else
  begin
    Result := Floor(LFrames);
  end;
end;

constructor TIncrementalTempoClock.Create(const ATicksPerQuarter, ASampleRate: Integer);
begin
  inherited Create;
  ValidateAudioFormat(ASampleRate, 1);
  if ATicksPerQuarter < 1 then
  begin
    raise EAudio.Create('Incremental clock PPQ must be positive');
  end;
  FState := Default(TTempoClockSnapshot);
  FState.TicksPerQuarter := ATicksPerQuarter;
  FState.SampleRate := ASampleRate;
end;

procedure TIncrementalTempoClock.Reset;
begin
  FState.TickCount := 0;
  FState.FrameCount := 0;
  FState.FractionNumerator := 0;
end;

procedure TIncrementalTempoClock.Restore(const ASnapshot: TTempoClockSnapshot);
begin
  if (ASnapshot.TicksPerQuarter <> FState.TicksPerQuarter) or
    (ASnapshot.SampleRate <> FState.SampleRate) or (ASnapshot.TickCount < 0) or
    (ASnapshot.FrameCount < 0) or (ASnapshot.FractionNumerator < 0) or
    (ASnapshot.FractionNumerator >= Int64(FState.TicksPerQuarter) * MicrosecondsPerSecond) or
    ((ASnapshot.TickCount = 0) and
      ((ASnapshot.FrameCount <> 0) or (ASnapshot.FractionNumerator <> 0))) then
  begin
    raise EAudio.Create('Incremental clock snapshot has incompatible or invalid state');
  end;
  FState := ASnapshot;
end;

function TIncrementalTempoClock.Advance(const ALengthTicks,
  ATempoMicrosecondsPerQuarter: Integer): Int64;
var
  LNumerator: Int64;
  LWholeUs: Int64;
  LTickRemainder: Int64;
  LFrames: Int64;
  LSubFrames: Int64;
  LFraction: Int64;
  LDenominator: Int64;
  LNext: TTempoClockSnapshot;
begin
  MakeTempoChange(0, ATempoMicrosecondsPerQuarter);
  if (ALengthTicks < 0) or (FState.TickCount > High(Int64) - ALengthTicks) then
  begin
    raise EAudio.Create('Incremental clock tick length or total exceeds integer range');
  end;
  { Extracted ensemble clock decomposition: never multiply total elapsed ticks
    by tempo/rate. Per-call ticks * MIDI tempo fits Int64. Whole-second frame
    products stay below 1.4E16 at 384000 Hz; the combined fraction is <5.2E15
    even with High(Integer) PPQ. Only cumulative counters need overflow guards. }
  LDenominator := Int64(FState.TicksPerQuarter) * MicrosecondsPerSecond;
  LNumerator := Int64(ALengthTicks) * ATempoMicrosecondsPerQuarter;
  LWholeUs := LNumerator div FState.TicksPerQuarter;
  LTickRemainder := LNumerator mod FState.TicksPerQuarter;
  LFrames := (LWholeUs div MicrosecondsPerSecond) * FState.SampleRate;
  LSubFrames := (LWholeUs mod MicrosecondsPerSecond) * FState.SampleRate;
  Inc(LFrames, LSubFrames div MicrosecondsPerSecond);
  LFraction := FState.FractionNumerator +
    (LSubFrames mod MicrosecondsPerSecond) * FState.TicksPerQuarter +
    LTickRemainder * FState.SampleRate;
  Inc(LFrames, LFraction div LDenominator);
  if FState.FrameCount > High(Int64) - LFrames then
  begin
    raise EAudio.Create('Incremental clock frame total exceeds integer range');
  end;
  LNext := FState;
  Inc(LNext.TickCount, ALengthTicks);
  Inc(LNext.FrameCount, LFrames);
  LNext.FractionNumerator := LFraction mod LDenominator;
  FState := LNext;
  Result := LFrames;
end;

function MakeTempoChange(const ATick, AMicrosecondsPerQuarter: Integer): TTempoChange;
begin
  if (ATick < 0) or (AMicrosecondsPerQuarter < 1) or
    (AMicrosecondsPerQuarter > MaximumTempoMicroseconds) then
  begin
    raise EAudio.Create('Tempo tick must be nonnegative and tempo must fit MIDI microseconds');
  end;
  Result.Tick := ATick;
  Result.MicrosecondsPerQuarter := AMicrosecondsPerQuarter;
end;

procedure AdvanceTime(var ATime: TMusicTime; const ADeltaTicks, ATempo: Integer);
var
  LNumerator: Int64;
begin
  { Integer tick range * MIDI tempo fits Int64. Carry the exact PPQ remainder,
    as in WFC's audio clock; never round separately at individual segments. }
  LNumerator := Int64(ADeltaTicks) * ATempo + ATime.FractionNumerator;
  Inc(ATime.WholeMicroseconds, LNumerator div ATime.Denominator);
  ATime.FractionNumerator := LNumerator mod ATime.Denominator;
end;

function MusicTimeToFrame(const ATime: TMusicTime; const ASampleRate: Integer;
  const ARounding: TFrameRounding): Int64;
var
  LProduct: Int64;
  LExtra: Int64;
  LDenominator: Int64;
  LSeconds: Int64;
begin
  ValidateAudioFormat(ASampleRate, 1);
  if (ATime.WholeMicroseconds < 0) or (ATime.Denominator < 1) or
    (ATime.FractionNumerator < 0) or (ATime.FractionNumerator >= ATime.Denominator) then
  begin
    raise EAudio.Create('Invalid rational music time');
  end;
  LSeconds := ATime.WholeMicroseconds div MicrosecondsPerSecond;
  { Reserve one complete fractional second plus rounding headroom. }
  if LSeconds > (High(Int64) - ASampleRate) div ASampleRate then
  begin
    raise EAudio.Create('Music time exceeds sample-frame integer range');
  end;
  Result := LSeconds * ASampleRate;
  LProduct := (ATime.WholeMicroseconds mod MicrosecondsPerSecond) * ASampleRate;
  Inc(Result, LProduct div MicrosecondsPerSecond);
  LExtra := (LProduct mod MicrosecondsPerSecond) * ATime.Denominator +
    Int64(ATime.FractionNumerator) * ASampleRate;
  LDenominator := Int64(ATime.Denominator) * MicrosecondsPerSecond;
  Inc(Result, LExtra div LDenominator);
  if (ARounding = frCeiling) and (LExtra mod LDenominator <> 0) then
  begin
    Inc(Result);
  end;
end;

constructor TTempoMap.Create(const ATicksPerQuarter, ALengthTicks: Integer;
  const AChanges: TTempoChanges);
var
  LIndex: Integer;
  LTime: TMusicTime;
begin
  inherited Create;
  if (ATicksPerQuarter < 1) or (ALengthTicks < 0) or
    (Length(AChanges) < 1) or (Length(AChanges) > MaximumTempoChanges) then
  begin
    raise EAudio.Create('Invalid PPQ, timeline extent, or tempo change count');
  end;
  if AChanges[0].Tick <> 0 then
  begin
    raise EAudio.Create('Tempo map must begin at tick zero');
  end;
  for LIndex := 0 to High(AChanges) do
  begin
    MakeTempoChange(AChanges[LIndex].Tick, AChanges[LIndex].MicrosecondsPerQuarter);
    if AChanges[LIndex].Tick > ALengthTicks then
    begin
      raise EAudio.Create('Tempo change exceeds timeline extent');
    end;
    if (LIndex > 0) and (AChanges[LIndex].Tick <= AChanges[LIndex - 1].Tick) then
    begin
      raise EAudio.Create('Tempo changes must have strictly increasing ticks');
    end;
  end;
  FTicksPerQuarter := ATicksPerQuarter;
  FLengthTicks := ALengthTicks;
  FChanges := Copy(AChanges);
  SetLength(FTimes, Length(FChanges));
  LTime := Default(TMusicTime);
  LTime.Denominator := FTicksPerQuarter;
  for LIndex := 0 to High(FChanges) do
  begin
    if LIndex > 0 then
    begin
      AdvanceTime(LTime, FChanges[LIndex].Tick - FChanges[LIndex - 1].Tick,
        FChanges[LIndex - 1].MicrosecondsPerQuarter);
    end;
    FTimes[LIndex] := LTime;
  end;
end;

function TTempoMap.TimeAtTick(const ATick: Integer): TMusicTime;
var
  LLow: Integer;
  LHigh: Integer;
  LMiddle: Integer;
  LIndex: Integer;
begin
  if (ATick < 0) or (ATick > FLengthTicks) then
  begin
    raise EAudio.Create('Tick lies outside tempo-map extent');
  end;
  LLow := 0;
  LHigh := High(FChanges);
  LIndex := 0;
  while LLow <= LHigh do
  begin
    LMiddle := LLow + (LHigh - LLow) div 2;
    if FChanges[LMiddle].Tick <= ATick then
    begin
      LIndex := LMiddle;
      LLow := LMiddle + 1;
    end
    else
    begin
      LHigh := LMiddle - 1;
    end;
  end;
  Result := FTimes[LIndex];
  AdvanceTime(Result, ATick - FChanges[LIndex].Tick,
    FChanges[LIndex].MicrosecondsPerQuarter);
end;

function TTempoMap.FrameAtTick(const ATick, ASampleRate: Integer;
  const ARounding: TFrameRounding): Int64;
begin
  Result := MusicTimeToFrame(TimeAtTick(ATick), ASampleRate, ARounding);
end;

function TTempoMap.GetChangeCount: Integer;
begin
  Result := Length(FChanges);
end;

function TTempoMap.ChangeAt(const AIndex: Integer): TTempoChange;
begin
  if (AIndex < 0) or (AIndex >= ChangeCount) then
  begin
    raise EAudio.Create('Tempo change index out of bounds');
  end;
  Result := FChanges[AIndex];
end;

function TTempoMap.CopyChanges: TTempoChanges;
begin
  Result := Copy(FChanges);
end;

function TTempoMap.NextGridTick(const AFrame: Int64;
  const ASampleRate, AGridTicks: Integer): Integer;
var
  LLow: Int64;
  LHigh: Int64;
  LMiddle: Int64;
  LGridTick: Int64;
begin
  ValidateAudioFormat(ASampleRate, 1);
  if (AFrame < 0) or (AGridTicks < 1) then
  begin
    raise EAudio.Create('Grid frame must be nonnegative and grid ticks positive');
  end;
  if FrameAtTick(FLengthTicks, ASampleRate) < AFrame then
  begin
    raise EAudio.Create('Requested grid boundary is beyond the timeline');
  end;
  LLow := 0;
  LHigh := FLengthTicks;
  while LLow < LHigh do
  begin
    LMiddle := LLow + (LHigh - LLow) div 2;
    if FrameAtTick(LMiddle, ASampleRate) < AFrame then
    begin
      LLow := LMiddle + 1;
    end
    else
    begin
      LHigh := LMiddle;
    end;
  end;
  LGridTick := ((LLow + AGridTicks - 1) div AGridTicks) * AGridTicks;
  if LGridTick > FLengthTicks then
  begin
    raise EAudio.Create('No grid boundary remains inside the timeline');
  end;
  Result := LGridTick;
end;

function TTempoMap.WithTempoFrom(const ATick, AMicrosecondsPerQuarter,
  ASampleRate: Integer; const AFrozenBeforeFrame: Int64): TTempoMap;
var
  LChanges: TTempoChanges;
  LCount: Integer;
begin
  MakeTempoChange(ATick, AMicrosecondsPerQuarter);
  if (AFrozenBeforeFrame < 0) or
    (FrameAtTick(ATick, ASampleRate) < AFrozenBeforeFrame) then
  begin
    raise EAudio.Create('Tempo override would alter committed audio');
  end;
  LCount := 0;
  while (LCount < ChangeCount) and (FChanges[LCount].Tick < ATick) do
  begin
    Inc(LCount);
  end;
  LChanges := Copy(FChanges, 0, LCount);
  SetLength(LChanges, LCount + 1);
  LChanges[LCount] := MakeTempoChange(ATick, AMicrosecondsPerQuarter);
  Result := TTempoMap.Create(FTicksPerQuarter, FLengthTicks, LChanges);
end;

end.
