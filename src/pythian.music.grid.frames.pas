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

unit pythian.music.grid.frames;

{$mode delphi}
{$H+}

interface

uses
  pythian.time;

type
  { Immutable source geometry for a finite PPQ grid. The supplied clock retains
    all history before StartTick; no tempo extrapolation or phase inference.
    SourceFrameOffset is the source frame at clock tick zero. }
  TMusicGridFrames = class
  strict private
    FSampleRate: Integer;
    FSourceFrames: Integer;
    FCount: Integer;
    FBoundaries: array of Integer;
    FEndCeiling: Integer;
  public
    constructor Create(const AClock: TTempoMap; const ASampleRate, ASourceFrames,
      ASourceFrameOffset, AStartTick, AStepTicks, ACellCount: Integer);
    function BoundaryAt(const AIndex: Integer): Integer;
    property SampleRate: Integer read FSampleRate;
    property SourceFrames: Integer read FSourceFrames;
    property CellCount: Integer read FCount;
    property EndFrameCeiling: Integer read FEndCeiling;
  end;

implementation

uses
  pythian.audio,
  pythian.music.context;

constructor TMusicGridFrames.Create(const AClock: TTempoMap; const ASampleRate,
  ASourceFrames, ASourceFrameOffset, AStartTick, AStepTicks, ACellCount: Integer);
var
  LEndTick: Int64;
  LFrame: Int64;
  LIndex: Integer;
begin
  inherited Create;
  ValidateAudioFormat(ASampleRate, 1);
  if (AClock = nil) or (ASourceFrames < 1) or (ASourceFrameOffset < 0) or
    (ASourceFrameOffset >= ASourceFrames) or (AStartTick < 0) or
    (AStepTicks < 1) or (ACellCount < 1) or (ACellCount > MaximumContextCells) then
  begin
    raise EAudio.Create('Source grid requires a clock, source extent and bounded positive cells');
  end;
  LEndTick := Int64(AStartTick) + Int64(AStepTicks) * ACellCount;
  if LEndTick > AClock.LengthTicks then
  begin
    raise EAudio.Create('Source grid exceeds its explicit tempo map');
  end;
  LFrame := AClock.FrameAtTick(LEndTick, ASampleRate, frCeiling) + ASourceFrameOffset;
  if LFrame > ASourceFrames then
  begin
    raise EAudio.Create('Source grid must contain only complete cells within the recording');
  end;
  FEndCeiling := LFrame;
  FSampleRate := ASampleRate;
  FSourceFrames := ASourceFrames;
  FCount := ACellCount;
  SetLength(FBoundaries, ACellCount + 1);
  for LIndex := 0 to ACellCount do
  begin
    LFrame := AClock.FrameAtTick(AStartTick + LIndex * AStepTicks, ASampleRate) +
      ASourceFrameOffset;
    FBoundaries[LIndex] := LFrame;
    if (LIndex > 0) and (FBoundaries[LIndex] <= FBoundaries[LIndex - 1]) then
    begin
      raise EAudio.Create('Source grid contains sub-frame cells');
    end;
  end;
end;

function TMusicGridFrames.BoundaryAt(const AIndex: Integer): Integer;
begin
  if (AIndex < 0) or (AIndex > FCount) then
  begin
    raise EAudio.Create('Source grid boundary index is outside its extent');
  end;
  Result := FBoundaries[AIndex];
end;

end.
