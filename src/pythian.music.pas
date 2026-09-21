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
unit pythian.music;

{$mode delphi}
{$H+}

interface

uses
  pythian.time;

const
  NoteSequenceVersion = 1;
  MaximumNoteGates = 200000;

type
  { Note-on/off gate in PPQ ticks, not a pedal-extended performance duration.
    Track and voice retain source indices; Channel=-1 means not specified. }
  TNoteGate = record
    StartTick: Integer;
    EndTick: Integer;
    Pitch: Integer;
    Velocity: Integer;
    Track: Integer;
    Voice: Integer;
    Channel: Integer;
  end;
  TNoteGates = array of TNoteGate;

  TNoteSequence = class
  strict private
    FClock: TTempoMap;
    FGates: TNoteGates;
    function GetNoteCount: Integer;
    function GetTicksPerQuarter: Integer;
    function GetLengthTicks: Integer;
  public
    constructor Create(const ATicksPerQuarter, ALengthTicks: Integer;
      const ATempos: TTempoChanges; const AGates: TNoteGates);
    destructor Destroy; override;
    function GateAt(const AIndex: Integer): TNoteGate;
    function CopyGates: TNoteGates;
    function CopyClock: TTempoMap;
    function FrameAtTick(const ATick, ASampleRate: Integer;
      const ARounding: TFrameRounding = frFloor): Int64;
    property NoteCount: Integer read GetNoteCount;
    property TicksPerQuarter: Integer read GetTicksPerQuarter;
    property LengthTicks: Integer read GetLengthTicks;
  end;

implementation

uses
  pythian.audio;

constructor TNoteSequence.Create(const ATicksPerQuarter, ALengthTicks: Integer;
  const ATempos: TTempoChanges; const AGates: TNoteGates);
var
  LIndex: Integer;
  LGate: TNoteGate;
begin
  inherited Create;
  if Length(AGates) > MaximumNoteGates then
  begin
    raise EAudio.Create('Note sequence exceeds gate budget');
  end;
  for LIndex := 0 to High(AGates) do
  begin
    LGate := AGates[LIndex];
    if (LGate.StartTick < 0) or (LGate.EndTick <= LGate.StartTick) or
      (LGate.EndTick > ALengthTicks) or (LGate.Pitch < 0) or (LGate.Pitch > 127) or
      (LGate.Velocity < 1) or (LGate.Velocity > 127) or (LGate.Track < 0) or
      (LGate.Voice < 0) or (LGate.Channel < -1) or (LGate.Channel > 15) then
    begin
      raise EAudio.Create('Note gate has invalid time, pitch, velocity or source coordinates');
    end;
  end;
  FClock := TTempoMap.Create(ATicksPerQuarter, ALengthTicks, ATempos);
  FGates := Copy(AGates);
end;

destructor TNoteSequence.Destroy;
begin
  FClock.Free;
  inherited Destroy;
end;

function TNoteSequence.GetNoteCount: Integer;
begin
  Result := Length(FGates);
end;

function TNoteSequence.GetTicksPerQuarter: Integer;
begin
  Result := FClock.TicksPerQuarter;
end;

function TNoteSequence.GetLengthTicks: Integer;
begin
  Result := FClock.LengthTicks;
end;

function TNoteSequence.GateAt(const AIndex: Integer): TNoteGate;
begin
  if (AIndex < 0) or (AIndex >= NoteCount) then
  begin
    raise EAudio.Create('Note gate index out of bounds');
  end;
  Result := FGates[AIndex];
end;

function TNoteSequence.CopyGates: TNoteGates;
begin
  Result := Copy(FGates);
end;

function TNoteSequence.CopyClock: TTempoMap;
begin
  Result := TTempoMap.Create(TicksPerQuarter, LengthTicks, FClock.CopyChanges);
end;

function TNoteSequence.FrameAtTick(const ATick, ASampleRate: Integer;
  const ARounding: TFrameRounding): Int64;
begin
  Result := FClock.FrameAtTick(ATick, ASampleRate, ARounding);
end;

end.
