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
unit pythian.music.context;

{$mode delphi}
{$H+}

interface

uses
  pythian.time,
  pythian.tonal;

const
  MusicContextVersion = 1;
  MaximumContextCells = 65536;
  MaximumKeyChanges = 65536;

type
  { Root=-1, Mode=dmMajor is the canonical unknown value; no inference occurs. }
  TKeyContext = record
    Root: Integer;
    Mode: TDiatonicMode;
  end;
  TKeyChange = record
    Tick: Integer;
    Key: TKeyContext;
  end;
  TKeyChanges = array of TKeyChange;
  TKeyContexts = array of TKeyContext;
  TContextTempos = array of Integer;
  { Cells cover [StartTick, StartTick + Count*StepTicks). Each value holds for
    the entire cell. Original source offsets are retained, not joined in time. }
  TMusicContextGrid = record
    TicksPerQuarter: Integer;
    StartTick: Integer;
    StepTicks: Integer;
    Keys: TKeyContexts;
    Tempos: TContextTempos;
  end;
  TMusicContextGrids = array of TMusicContextGrid;

  TMusicContext = class
  strict private
    FClock: TTempoMap;
    FKeys: TKeyChanges;
  public
    { Owns detached copies. An explicit key value at tick zero is required. }
    constructor Create(const AClock: TTempoMap; const AKeys: TKeyChanges);
    destructor Destroy; override;
    function CopyClock: TTempoMap;
    function CopyKeys: TKeyChanges;
    function KeyAtTick(const ATick: Integer): TKeyContext;
    { Rejects changes inside cells, including redundant declared changes.
      No implicit quantization, majority vote, inferred meter or downbeat. }
    function Grid(const AStartTick, AStepTicks, ACellCount: Integer): TMusicContextGrid;
  end;

function MakeKeyContext(const ARoot: Integer; const AMode: TDiatonicMode): TKeyContext;
function SameKeyContext(const ALeft, ARight: TKeyContext): Boolean;
{ Explicit diatonic arrangement: retain scale degree and octave relative to the
  source tonic. Both keys must be known, the input must belong to its declared
  scale, and the result must remain in MIDI range. No chromatic approximation. }
function MapDiatonicPitch(const APitch: Integer;
  const ASourceKey, ATargetKey: TKeyContext): Integer;
procedure ValidateContextGrid(const AGrid: TMusicContextGrid);

implementation

uses
  pythian.audio;

function MapDiatonicPitch(const APitch: Integer;
  const ASourceKey, ATargetKey: TKeyContext): Integer;
const
  CSteps: array[TDiatonicMode, 0..6] of Integer =
    ((0, 2, 4, 5, 7, 9, 11), (0, 2, 3, 5, 7, 8, 10));
var
  LRelative: Integer;
  LClass: Integer;
  LOctave: Integer;
  LDegree: Integer;
begin
  MakeKeyContext(ASourceKey.Root, ASourceKey.Mode);
  MakeKeyContext(ATargetKey.Root, ATargetKey.Mode);
  if (ASourceKey.Root < 0) or (ATargetKey.Root < 0) or
    (APitch < 0) or (APitch > 127) then
  begin
    raise EAudio.Create('Diatonic mapping requires known keys and a MIDI source pitch');
  end;
  LRelative := APitch - ASourceKey.Root;
  LClass := ((LRelative mod 12) + 12) mod 12;
  LOctave := (LRelative - LClass) div 12;
  for LDegree := 0 to 6 do
  begin
    if CSteps[ASourceKey.Mode, LDegree] = LClass then
    begin
      Result := ATargetKey.Root + LOctave * 12 + CSteps[ATargetKey.Mode, LDegree];
      if (Result < 0) or (Result > 127) then
      begin
        raise EAudio.Create('Mapped diatonic pitch exceeds MIDI range');
      end;
      Exit;
    end;
  end;
  raise EAudio.Create('Source pitch does not belong to its declared diatonic scale');
end;

function MakeKeyContext(const ARoot: Integer; const AMode: TDiatonicMode): TKeyContext;
begin
  if (ARoot < -1) or (ARoot > 11) or
    not (AMode in [dmMajor, dmNaturalMinor]) or
    ((ARoot = -1) and (AMode <> dmMajor)) then
  begin
    raise EAudio.Create('Key context requires root 0..11 and a supported mode, or canonical unknown');
  end;
  Result.Root := ARoot;
  Result.Mode := AMode;
end;

function SameKeyContext(const ALeft, ARight: TKeyContext): Boolean;
begin
  Result := (ALeft.Root = ARight.Root) and (ALeft.Mode = ARight.Mode);
end;

procedure ValidateGridExtent(const APPQ, AStart, AStep, ACount: Integer);
begin
  if (APPQ < 1) or (AStart < 0) or (AStep < 1) or
    (ACount < 1) or (ACount > MaximumContextCells) then
  begin
    raise EAudio.Create('Context grid requires positive PPQ/step/count and nonnegative start');
  end;
  if Int64(AStart) + Int64(AStep) * ACount > High(Integer) then
  begin
    raise EAudio.Create('Context grid exceeds the PPQ timeline extent');
  end;
end;

procedure ValidateContextGrid(const AGrid: TMusicContextGrid);
var
  LIndex: Integer;
begin
  ValidateGridExtent(AGrid.TicksPerQuarter, AGrid.StartTick,
    AGrid.StepTicks, Length(AGrid.Keys));
  if Length(AGrid.Tempos) <> Length(AGrid.Keys) then
  begin
    raise EAudio.Create('Context key and tempo grids must have the same cell count');
  end;
  for LIndex := 0 to High(AGrid.Keys) do
  begin
    MakeKeyContext(AGrid.Keys[LIndex].Root, AGrid.Keys[LIndex].Mode);
    MakeTempoChange(0, AGrid.Tempos[LIndex]);
  end;
end;

constructor TMusicContext.Create(const AClock: TTempoMap; const AKeys: TKeyChanges);
var
  LIndex: Integer;
begin
  inherited Create;
  if (AClock = nil) or (Length(AKeys) < 1) or
    (Length(AKeys) > MaximumKeyChanges) then
  begin
    raise EAudio.Create('Music context requires a clock and 1..65536 key changes');
  end;
  if AKeys[0].Tick <> 0 then
  begin
    raise EAudio.Create('Key context must begin at tick zero, using unknown when necessary');
  end;
  for LIndex := 0 to High(AKeys) do
  begin
    MakeKeyContext(AKeys[LIndex].Key.Root, AKeys[LIndex].Key.Mode);
    if (AKeys[LIndex].Tick < 0) or (AKeys[LIndex].Tick > AClock.LengthTicks) then
    begin
      raise EAudio.Create('Key change exceeds the context timeline');
    end;
    if (LIndex > 0) and (AKeys[LIndex].Tick <= AKeys[LIndex - 1].Tick) then
    begin
      raise EAudio.Create('Key changes must strictly increase');
    end;
  end;
  FKeys := Copy(AKeys);
  FClock := TTempoMap.Create(AClock.TicksPerQuarter, AClock.LengthTicks, AClock.CopyChanges);
end;

destructor TMusicContext.Destroy;
begin
  FClock.Free;
  inherited Destroy;
end;

function TMusicContext.CopyClock: TTempoMap;
begin
  Result := TTempoMap.Create(FClock.TicksPerQuarter, FClock.LengthTicks, FClock.CopyChanges);
end;

function TMusicContext.CopyKeys: TKeyChanges;
begin
  Result := Copy(FKeys);
end;

function TMusicContext.KeyAtTick(const ATick: Integer): TKeyContext;
var
  LLow: Integer;
  LHigh: Integer;
  LMiddle: Integer;
begin
  if (ATick < 0) or (ATick > FClock.LengthTicks) then
  begin
    raise EAudio.Create('Key query outside the context timeline');
  end;
  LLow := 0;
  LHigh := High(FKeys);
  while LLow < LHigh do
  begin
    LMiddle := LLow + (LHigh - LLow + 1) div 2;
    if FKeys[LMiddle].Tick <= ATick then
    begin
      LLow := LMiddle;
    end
    else
    begin
      LHigh := LMiddle - 1;
    end;
  end;
  Result := FKeys[LLow].Key;
end;

function TMusicContext.Grid(const AStartTick, AStepTicks,
  ACellCount: Integer): TMusicContextGrid;
var
  LCandidate: TMusicContextGrid;
  LEndTick: Integer;
  LIndex: Integer;
  LTempo: Integer;
  LTick: Integer;
  LChange: TTempoChange;

  procedure CheckBoundary(const ATick: Integer);
  begin
    if (ATick > AStartTick) and (ATick < LEndTick) and
      ((ATick - AStartTick) mod AStepTicks <> 0) then
    begin
      raise EAudio.Create('Context change falls inside a requested cell; refine the grid explicitly');
    end;
  end;

begin
  ValidateGridExtent(FClock.TicksPerQuarter, AStartTick, AStepTicks, ACellCount);
  LEndTick := AStartTick + AStepTicks * ACellCount;
  if LEndTick > FClock.LengthTicks then
  begin
    raise EAudio.Create('Requested context grid exceeds the source timeline');
  end;
  for LIndex := 0 to High(FKeys) do
  begin
    CheckBoundary(FKeys[LIndex].Tick);
  end;
  for LIndex := 0 to FClock.ChangeCount - 1 do
  begin
    CheckBoundary(FClock.ChangeAt(LIndex).Tick);
  end;
  LCandidate := Default(TMusicContextGrid);
  LCandidate.TicksPerQuarter := FClock.TicksPerQuarter;
  LCandidate.StartTick := AStartTick;
  LCandidate.StepTicks := AStepTicks;
  SetLength(LCandidate.Keys, ACellCount);
  SetLength(LCandidate.Tempos, ACellCount);
  LTempo := 0;
  for LIndex := 0 to ACellCount - 1 do
  begin
    LTick := AStartTick + LIndex * AStepTicks;
    while LTempo + 1 < FClock.ChangeCount do
    begin
      LChange := FClock.ChangeAt(LTempo + 1);
      if LChange.Tick > LTick then
      begin
        Break;
      end;
      Inc(LTempo);
    end;
    LCandidate.Keys[LIndex] := KeyAtTick(LTick);
    LCandidate.Tempos[LIndex] := FClock.ChangeAt(LTempo).MicrosecondsPerQuarter;
  end;
  Result := LCandidate;
end;

end.
