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
unit pythian.midi.export;

{$mode delphi}
{$H+}

interface

uses
  pythian.music,
  pythian.midi.smf,
  pythian.midi.stream;

const
  MidiNoteExportVersion = 1;
  MaximumMidiExportVoiceBindings = 4096;
  MaximumMidiNoteExportBytes = 16 * 1024 * 1024;

type
  EMidiNoteExport = class(EMidiSmf);

  { Detached note/tempo projection into one format-0 track.
    Empty channel table retains each gate's explicit Channel (0..15).
    Otherwise the dense table overrides channels by Gate.Voice, independently
    of Track; every gate needs a binding. No automatic channel assignment,
    percussion remapping, program selection or source metadata reconstruction.
    Simultaneously sounding equal pitches on one output channel reject.

    Rows are ordered by tick, tempo/note-off/note-on, then source ordinal.
    Source note/tempo limits bound storage; this is not a constant-memory planner.
    EventAt returns an independently owned payload and zero incoming DeltaTicks.
    CreateStream returns an owned writer for replaying EventAt in index order.
    Neither returned events nor a stream depend on this object's later lifetime. }
  TNoteMidiExport = class
  strict private
    type
      TRow = record
        Tick: Integer;
        Priority: Integer;
        Ordinal: Integer;
        Status: Byte;
        Data1: Byte;
        Data2: Byte;
        Data3: Byte;
      end;
      TRows = array of TRow;
    var
      FRows: TRows;
      FPlan: TMidiTrackPlan;
      FTicksPerQuarter: Integer;
      FLengthTicks: Integer;
    function GetEventCount: Integer;
    procedure SortRows;
    procedure ValidateOverlap;
  public
    constructor Create(const ASequence: TNoteSequence;
      const AVoiceChannels: array of Integer);
    destructor Destroy; override;
    procedure EventAt(const AIndex: Integer; out AAbsoluteTick: Int64;
      out AEvent: TMidiEvent);
    function CreateStream: TMidiFileStream;
    function Encode: TMidiBytes;
    property EventCount: Integer read GetEventCount;
    property TicksPerQuarter: Integer read FTicksPerQuarter;
    property LengthTicks: Integer read FLengthTicks;
  end;

{ Convenience whole-file encoding; stream with the plan API when the host
  should consume byte blocks. Failure leaves a prior assigned result intact. }
function EncodeMidiNotes(const ASequence: TNoteSequence;
  const AVoiceChannels: array of Integer): TMidiBytes;

implementation

uses
  SysUtils,
  pythian.time;

const
  PriorityTempo = 0;
  PriorityNoteOff = 1;
  PriorityNoteOn = 2;

procedure ExportError(const AMessage: String);
begin
  raise EMidiNoteExport.Create('Cannot export MIDI notes: ' + AMessage);
end;

procedure TNoteMidiExport.SortRows;
var
  LWork: TRows;

  function BeforeOrEqual(const ALeft, ARight: TRow): Boolean;
  begin
    if ALeft.Tick <> ARight.Tick then
    begin
      Exit(ALeft.Tick < ARight.Tick);
    end;
    if ALeft.Priority <> ARight.Priority then
    begin
      Exit(ALeft.Priority < ARight.Priority);
    end;
    Result := ALeft.Ordinal <= ARight.Ordinal;
  end;

  procedure SortRange(const AFirst, ALast: Integer);
  var
    LMiddle: Integer;
    LLeft: Integer;
    LRight: Integer;
    LNext: Integer;
    LIndex: Integer;
  begin
    if AFirst >= ALast then
    begin
      Exit;
    end;
    LMiddle := AFirst + (ALast - AFirst) div 2;
    SortRange(AFirst, LMiddle);
    SortRange(LMiddle + 1, ALast);
    LLeft := AFirst;
    LRight := LMiddle + 1;
    LNext := AFirst;
    while (LLeft <= LMiddle) and (LRight <= ALast) do
    begin
      if BeforeOrEqual(FRows[LLeft], FRows[LRight]) then
      begin
        LWork[LNext] := FRows[LLeft];
        Inc(LLeft);
      end
      else
      begin
        LWork[LNext] := FRows[LRight];
        Inc(LRight);
      end;
      Inc(LNext);
    end;
    while LLeft <= LMiddle do
    begin
      LWork[LNext] := FRows[LLeft];
      Inc(LLeft);
      Inc(LNext);
    end;
    while LRight <= ALast do
    begin
      LWork[LNext] := FRows[LRight];
      Inc(LRight);
      Inc(LNext);
    end;
    for LIndex := AFirst to ALast do
    begin
      FRows[LIndex] := LWork[LIndex];
    end;
  end;

begin
  SetLength(LWork, Length(FRows));
  SortRange(0, High(FRows));
end;

procedure TNoteMidiExport.ValidateOverlap;
var
  LActive: array[0..15, 0..127] of Boolean;
  LIndex: Integer;
  LChannel: Integer;
begin
  FillChar(LActive, SizeOf(LActive), 0);
  for LIndex := 0 to High(FRows) do
  begin
    if FRows[LIndex].Priority = PriorityTempo then
    begin
      Continue;
    end;
    LChannel := FRows[LIndex].Status and $0F;
    if (FRows[LIndex].Priority = PriorityNoteOn) and
      LActive[LChannel, FRows[LIndex].Data1] then
    begin
      ExportError('overlapping equal pitches share an output channel');
    end;
    LActive[LChannel, FRows[LIndex].Data1] :=
      FRows[LIndex].Priority = PriorityNoteOn;
  end;
end;

constructor TNoteMidiExport.Create(const ASequence: TNoteSequence;
  const AVoiceChannels: array of Integer);
var
  LClock: TTempoMap;
  LCounter: TMidiTrackCounter;
  LTempo: TTempoChange;
  LGate: TNoteGate;
  LIndex: Integer;
  LCount: Integer;
  LChannel: Integer;
  LTick: Int64;
  LEvent: TMidiEvent;
begin
  inherited Create;
  if ASequence = nil then
  begin
    ExportError('sequence is required');
  end;
  if (ASequence.TicksPerQuarter < 1) or (ASequence.TicksPerQuarter > $7FFF) then
  begin
    ExportError('PPQ must be 1..32767');
  end;
  if Length(AVoiceChannels) > MaximumMidiExportVoiceBindings then
  begin
    ExportError('voice channel table exceeds 4096 bindings');
  end;
  for LIndex := 0 to High(AVoiceChannels) do
  begin
    if (AVoiceChannels[LIndex] < 0) or (AVoiceChannels[LIndex] > 15) then
    begin
      ExportError('each voice channel must be 0..15');
    end;
  end;
  FTicksPerQuarter := ASequence.TicksPerQuarter;
  FLengthTicks := ASequence.LengthTicks;
  LClock := ASequence.CopyClock;
  try
    SetLength(FRows, LClock.ChangeCount + ASequence.NoteCount * 2);
    LCount := 0;
    for LIndex := 0 to LClock.ChangeCount - 1 do
    begin
      LTempo := LClock.ChangeAt(LIndex);
      FRows[LCount].Tick := LTempo.Tick;
      FRows[LCount].Priority := PriorityTempo;
      FRows[LCount].Ordinal := LCount;
      FRows[LCount].Status := $FF;
      FRows[LCount].Data1 := Byte((LTempo.MicrosecondsPerQuarter shr 16) and $FF);
      FRows[LCount].Data2 := Byte((LTempo.MicrosecondsPerQuarter shr 8) and $FF);
      FRows[LCount].Data3 := Byte(LTempo.MicrosecondsPerQuarter and $FF);
      Inc(LCount);
    end;
    for LIndex := 0 to ASequence.NoteCount - 1 do
    begin
      LGate := ASequence.GateAt(LIndex);
      if Length(AVoiceChannels) = 0 then
      begin
        LChannel := LGate.Channel;
        if LChannel < 0 then
        begin
          ExportError('gate channel is unspecified; supply a voice channel table');
        end;
      end
      else
      begin
        if LGate.Voice >= Length(AVoiceChannels) then
        begin
          ExportError('gate voice has no channel binding');
        end;
        LChannel := AVoiceChannels[LGate.Voice];
      end;
      FRows[LCount].Tick := LGate.StartTick;
      FRows[LCount].Priority := PriorityNoteOn;
      FRows[LCount].Ordinal := LCount;
      FRows[LCount].Status := Byte($90 or LChannel);
      FRows[LCount].Data1 := Byte(LGate.Pitch);
      FRows[LCount].Data2 := Byte(LGate.Velocity);
      Inc(LCount);
      FRows[LCount].Tick := LGate.EndTick;
      FRows[LCount].Priority := PriorityNoteOff;
      FRows[LCount].Ordinal := LCount;
      FRows[LCount].Status := Byte($80 or LChannel);
      FRows[LCount].Data1 := Byte(LGate.Pitch);
      FRows[LCount].Data2 := 0;
      Inc(LCount);
    end;
  finally
    LClock.Free;
  end;
  SortRows;
  ValidateOverlap;
  LCounter := TMidiTrackCounter.Create;
  try
    for LIndex := 0 to High(FRows) do
    begin
      EventAt(LIndex, LTick, LEvent);
      LCounter.AppendEvent(LTick, LEvent);
    end;
    FPlan := LCounter.Finish(FLengthTicks);
  finally
    LCounter.Free;
  end;
end;

destructor TNoteMidiExport.Destroy;
begin
  FPlan.Free;
  inherited Destroy;
end;

function TNoteMidiExport.GetEventCount: Integer;
begin
  Result := Length(FRows);
end;

procedure TNoteMidiExport.EventAt(const AIndex: Integer;
  out AAbsoluteTick: Int64; out AEvent: TMidiEvent);
var
  LRow: TRow;
begin
  if (AIndex < 0) or (AIndex >= EventCount) then
  begin
    ExportError('event index is outside the plan');
  end;
  LRow := FRows[AIndex];
  AAbsoluteTick := LRow.Tick;
  if LRow.Priority = PriorityTempo then
  begin
    AEvent := MakeMidiMetaEvent(0, $51, [LRow.Data1, LRow.Data2, LRow.Data3]);
  end
  else
  begin
    AEvent := MakeMidiChannelEvent(0, LRow.Status, [LRow.Data1, LRow.Data2]);
  end;
end;

function TNoteMidiExport.CreateStream: TMidiFileStream;
begin
  Result := TMidiFileStream.Create(FTicksPerQuarter, FPlan);
end;

function TNoteMidiExport.Encode: TMidiBytes;
var
  LWriter: TMidiFileStream;
  LBytes: TMidiBytes;
  LEvent: TMidiEvent;
  LTick: Int64;
  LIndex: Integer;
  LOffset: Integer;
  LOutput: TMidiBytes;

  procedure Drain;
  begin
    while LWriter.ReadBytes(MidiStreamBlockBytes, LBytes) do
    begin
      if Length(LBytes) > Length(LOutput) - LOffset then
      begin
        ExportError('stream exceeded the planned output length');
      end;
      Move(LBytes[0], LOutput[LOffset], Length(LBytes));
      Inc(LOffset, Length(LBytes));
    end;
  end;

begin
  Result := nil;
  if FPlan.ByteCount + MidiStreamHeaderBytes > MaximumMidiNoteExportBytes then
  begin
    ExportError('whole-file encoding exceeds the native file byte budget');
  end;
  SetLength(LOutput, Integer(FPlan.ByteCount + MidiStreamHeaderBytes));
  LOffset := 0;
  LWriter := CreateStream;
  try
    Drain;
    for LIndex := 0 to EventCount - 1 do
    begin
      EventAt(LIndex, LTick, LEvent);
      LWriter.AdmitEvent(LTick, LEvent);
      Drain;
    end;
    LWriter.Finish(FLengthTicks);
    Drain;
    if not LWriter.Finished or (LOffset <> Length(LOutput)) then
    begin
      ExportError('stream did not complete at the planned length');
    end;
    Result := LOutput;
  finally
    LWriter.Free;
  end;
end;

function EncodeMidiNotes(const ASequence: TNoteSequence;
  const AVoiceChannels: array of Integer): TMidiBytes;
var
  LExport: TNoteMidiExport;
begin
  LExport := TNoteMidiExport.Create(ASequence, AVoiceChannels);
  try
    Result := LExport.Encode;
  finally
    LExport.Free;
  end;
end;

end.
