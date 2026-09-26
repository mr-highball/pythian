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
unit pythian.articulation;

{$mode delphi}
{$H+}

interface

uses
  pythian.audio,
  pythian.time,
  pythian.music;

const
  ArticulationVersion = 1;
  MaximumArticulationGates = 65536;
  MaximumArticulationSamples = 16000000;
  MaximumArticulationVisits = 64000000;

type
  TArticulationGate = record
    StartFrame: Integer;
    EndFrame: Integer;
    Gain: Double;
  end;
  TArticulationGates = array of TArticulationGate;

  { Detached immutable output envelope. Gates are half-open; fades are inside
    the gates. Overlapping gates use maximum gain, never additive gain. }
  TArticulationPlan = class
  strict private
    FSampleRate: Integer;
    FFrameCount: Integer;
    FAttackFrames: Integer;
    FReleaseFrames: Integer;
    FGates: TArticulationGates;
    function GetGateCount: Integer;
  public
    constructor Create(const ASampleRate, AFrameCount, AAttackFrames,
      AReleaseFrames: Integer; const AGates: TArticulationGates);
    function GateAt(const AIndex: Integer): TArticulationGate;
    property SampleRate: Integer read FSampleRate;
    property FrameCount: Integer read FFrameCount;
    property AttackFrames: Integer read FAttackFrames;
    property ReleaseFrames: Integer read FReleaseFrames;
    property GateCount: Integer read GetGateCount;
  end;

{ a starts/retriggers, h extends the current gate, r ends it and silences the
  cell. Leading h or h after r rejects. One character is one explicit PPQ cell.
  Both absolute boundaries floor through the clock, then the start is subtracted.
  Sub-frame cells reject. The clock and all sources remain borrowed. }
function PlanGridArticulation(const AClock: TTempoMap; const AStartTick,
  AGridTicks: Integer; const APattern: String; const ASampleRate, AAttackFrames,
  AReleaseFrames: Integer): TArticulationPlan;

{ Pitch, track, voice and channel do not select source audio. All note gates
  modulate one clip with velocity/127. Sub-frame notes are omitted and counted.
  Failure clears ASubFrameNotes. Both endpoints use the same floor clock as
  synthesis. Output length includes the whole sequence, including trailing rests. }
function PlanNoteArticulation(const ASequence: TNoteSequence;
  const ASampleRate, AAttackFrames, AReleaseFrames: Integer;
  out ASubFrameNotes: Integer): TArticulationPlan;

{ Applies the envelope after reconstruction. Output frame i reads input frame i:
  no retiming, source looping, pitch change, beat inference or added release tail.
  Source must cover the complete plan. Output is detached and caller-owned. }
function RenderArticulatedClip(const ASource: TAudioClip;
  const APlan: TArticulationPlan): TAudioClip;

implementation

uses
  Math;

procedure ValidateExtent(const ASampleRate: Integer; const AFrames: Int64;
  const AAttackFrames, AReleaseFrames: Integer);
begin
  ValidateAudioFormat(ASampleRate, 1);
  if (AFrames < 0) or (AFrames > MaximumArticulationSamples) or
    (AAttackFrames < 0) or (AAttackFrames > MaximumArticulationSamples) or
    (AReleaseFrames < 0) or (AReleaseFrames > MaximumArticulationSamples) then
  begin
    raise EAudio.Create('Articulation extent or fade exceeds its frame budget');
  end;
end;

constructor TArticulationPlan.Create(const ASampleRate, AFrameCount,
  AAttackFrames, AReleaseFrames: Integer; const AGates: TArticulationGates);
var
  LIndex: Integer;
  LGate: TArticulationGate;
  LVisits: Int64;
begin
  inherited Create;
  ValidateExtent(ASampleRate, AFrameCount, AAttackFrames, AReleaseFrames);
  if Length(AGates) > MaximumArticulationGates then
  begin
    raise EAudio.Create('Articulation gate count exceeds its budget');
  end;
  LVisits := 0;
  for LIndex := 0 to High(AGates) do
  begin
    LGate := AGates[LIndex];
    RequireFinite(LGate.Gain, 'Articulation gain');
    if (LGate.StartFrame < 0) or (LGate.EndFrame <= LGate.StartFrame) or
      (LGate.EndFrame > AFrameCount) or (LGate.Gain < 0) or (LGate.Gain > 1) then
    begin
      raise EAudio.Create('Articulation gate outside time or gain bounds');
    end;
    Inc(LVisits, LGate.EndFrame - LGate.StartFrame);
    if LVisits > MaximumArticulationVisits then
    begin
      raise EAudio.Create('Articulation exceeds gate-frame visit budget');
    end;
  end;
  FSampleRate := ASampleRate;
  FFrameCount := AFrameCount;
  FAttackFrames := AAttackFrames;
  FReleaseFrames := AReleaseFrames;
  FGates := Copy(AGates);
end;

function TArticulationPlan.GetGateCount: Integer;
begin
  Result := Length(FGates);
end;

function TArticulationPlan.GateAt(const AIndex: Integer): TArticulationGate;
begin
  if (AIndex < 0) or (AIndex >= GateCount) then
  begin
    raise EAudio.Create('Articulation gate index out of bounds');
  end;
  Result := FGates[AIndex];
end;

function PlanGridArticulation(const AClock: TTempoMap; const AStartTick,
  AGridTicks: Integer; const APattern: String; const ASampleRate, AAttackFrames,
  AReleaseFrames: Integer): TArticulationPlan;
var
  LGates: TArticulationGates;
  LCount: Integer;
  LIndex: Integer;
  LEndTick: Int64;
  LOrigin: Int64;
  LStart: Int64;
  LEnd: Int64;
  LFrames: Int64;
  LActive: Boolean;
begin
  if AClock = nil then
  begin
    raise EAudio.Create('Articulation tempo map is required');
  end;
  if (AStartTick < 0) or (AGridTicks < 1) or (Length(APattern) < 1) or
    (Length(APattern) > MaximumArticulationGates) then
  begin
    raise EAudio.Create('Articulation grid or pattern outside bounds');
  end;
  LEndTick := Int64(AStartTick) + Int64(AGridTicks) * Length(APattern);
  if LEndTick > AClock.LengthTicks then
  begin
    raise EAudio.Create('Articulation pattern extends beyond tempo map');
  end;
  LOrigin := AClock.FrameAtTick(AStartTick, ASampleRate);
  LFrames := AClock.FrameAtTick(LEndTick, ASampleRate) - LOrigin;
  ValidateExtent(ASampleRate, LFrames, AAttackFrames, AReleaseFrames);
  LGates := nil;
  SetLength(LGates, Length(APattern));
  LCount := 0;
  LActive := False;
  LStart := 0;
  for LIndex := 1 to Length(APattern) do
  begin
    LEnd := AClock.FrameAtTick(AStartTick + LIndex * AGridTicks, ASampleRate) - LOrigin;
    if LEnd <= LStart then
    begin
      raise EAudio.Create('Articulation grid cell is shorter than one output frame');
    end;
    case APattern[LIndex] of
      'a':
        begin
          LGates[LCount].StartFrame := LStart;
          LGates[LCount].EndFrame := LEnd;
          LGates[LCount].Gain := 1;
          Inc(LCount);
          LActive := True;
        end;
      'h':
        begin
          if not LActive then
          begin
            raise EAudio.Create('Articulation hold requires a preceding attack');
          end;
          LGates[LCount - 1].EndFrame := LEnd;
        end;
      'r':
        begin
          LActive := False;
        end;
    else
      raise EAudio.Create('Articulation pattern accepts only a, h and r');
    end;
    LStart := LEnd;
  end;
  SetLength(LGates, LCount);
  Result := TArticulationPlan.Create(ASampleRate, LFrames, AAttackFrames,
    AReleaseFrames, LGates);
end;

function PlanNoteArticulation(const ASequence: TNoteSequence;
  const ASampleRate, AAttackFrames, AReleaseFrames: Integer;
  out ASubFrameNotes: Integer): TArticulationPlan;
var
  LGates: TArticulationGates;
  LNote: TNoteGate;
  LIndex: Integer;
  LCount: Integer;
  LOmitted: Integer;
  LFrames: Int64;
  LStart: Int64;
  LEnd: Int64;
begin
  ASubFrameNotes := 0;
  if ASequence = nil then
  begin
    raise EAudio.Create('Articulation note sequence is required');
  end;
  LFrames := ASequence.FrameAtTick(ASequence.LengthTicks, ASampleRate);
  ValidateExtent(ASampleRate, LFrames, AAttackFrames, AReleaseFrames);
  LGates := nil;
  SetLength(LGates, Min(ASequence.NoteCount, MaximumArticulationGates));
  LCount := 0;
  LOmitted := 0;
  for LIndex := 0 to ASequence.NoteCount - 1 do
  begin
    LNote := ASequence.GateAt(LIndex);
    LStart := ASequence.FrameAtTick(LNote.StartTick, ASampleRate);
    LEnd := ASequence.FrameAtTick(LNote.EndTick, ASampleRate);
    if LStart = LEnd then
    begin
      Inc(LOmitted);
      Continue;
    end;
    if LCount = MaximumArticulationGates then
    begin
      raise EAudio.Create('Articulation note count exceeds its budget');
    end;
    LGates[LCount].StartFrame := LStart;
    LGates[LCount].EndFrame := LEnd;
    LGates[LCount].Gain := LNote.Velocity / 127;
    Inc(LCount);
  end;
  SetLength(LGates, LCount);
  Result := TArticulationPlan.Create(ASampleRate, LFrames, AAttackFrames,
    AReleaseFrames, LGates);
  ASubFrameNotes := LOmitted;
end;

function RenderArticulatedClip(const ASource: TAudioClip;
  const APlan: TArticulationPlan): TAudioClip;
var
  LGains: array of Double;
  LSamples: TAudioSamples;
  LGate: TArticulationGate;
  LIndex: Integer;
  LFrame: Integer;
  LChannel: Integer;
  LWeight: Double;
begin
  if (ASource = nil) or (APlan = nil) then
  begin
    raise EAudio.Create('Articulation source and plan are required');
  end;
  if (ASource.SampleRate <> APlan.SampleRate) or
    (ASource.FrameCount < APlan.FrameCount) or
    (APlan.FrameCount > MaximumArticulationSamples div ASource.Channels) then
  begin
    raise EAudio.Create('Articulation source format, coverage or output budget mismatch');
  end;
  SetLength(LGains, APlan.FrameCount);
  for LIndex := 0 to APlan.GateCount - 1 do
  begin
    LGate := APlan.GateAt(LIndex);
    for LFrame := LGate.StartFrame to LGate.EndFrame - 1 do
    begin
      LWeight := 1;
      if APlan.AttackFrames > 0 then
      begin
        LWeight := Min(LWeight, (LFrame - LGate.StartFrame) / APlan.AttackFrames);
      end;
      if APlan.ReleaseFrames > 0 then
      begin
        LWeight := Min(LWeight, (LGate.EndFrame - 1 - LFrame) / APlan.ReleaseFrames);
      end;
      LGains[LFrame] := Max(LGains[LFrame], LWeight * LGate.Gain);
    end;
  end;
  LSamples := nil;
  SetLength(LSamples, APlan.FrameCount * ASource.Channels);
  for LFrame := 0 to APlan.FrameCount - 1 do
  begin
    for LChannel := 0 to ASource.Channels - 1 do
    begin
      LSamples[LFrame * ASource.Channels + LChannel] :=
        ASource.SampleAt(LFrame, LChannel) * LGains[LFrame];
    end;
  end;
  Result := TAudioClip.Create(ASource.SampleRate, ASource.Channels, LSamples);
end;

end.

