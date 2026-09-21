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
unit pythian.midi.notes;

{$mode delphi}
{$H+}

interface

uses
  pythian.music,
  pythian.midi.smf;

const
  MidiNoteImportVersion = 1;
  MaximumMidiImportEvents = 262144;

type
  TMidiNoteOptions = record
    AllowOverlapsFIFO: Boolean;
    CloseDanglingNotes: Boolean;
    IgnoreUnsupportedEvents: Boolean;
    IncludePercussion: Boolean;
  end;

  TMidiNoteReport = record
    SourceTracks: Integer;
    SourceEvents: Integer;
    NoteCount: Integer;
    IgnoredPerformanceEvents: Integer;
    IgnoredSystemEvents: Integer;
    IgnoredMetadataEvents: Integer;
    ExcludedPercussionNotes: Integer;
    DiscardedReleaseVelocities: Integer;
    OverlappingNotesPairedFIFO: Integer;
    ClosedDanglingNotes: Integer;
    ZeroLengthNotes: Integer;
    RedundantTempoEvents: Integer;
    UsedDefaultTempo: Boolean;
  end;

function DefaultMidiNoteOptions: TMidiNoteOptions;
{ Note-only projection. Raw events remain available through pythian.midi.smf.
  Global order is (tick, track, event); note pairing uses (channel, pitch).
  Conflicting simultaneous tempos and device/port routing metadata reject.
  Defaults reject ambiguous/dangling notes and unsupported performance data.
  The returned sequence is detached and caller-owned; failure clears AReport. }
function DecodeMidiNotes(const ABytes: TMidiBytes; const AOptions: TMidiNoteOptions;
  out AReport: TMidiNoteReport): TNoteSequence;

implementation

uses
  Math,
  pythian.audio,
  pythian.time;

type
  TMidiPosition = record
    Tick: Integer;
    Track: Integer;
    EventIndex: Integer;
  end;
  TMidiPositions = array of TMidiPosition;

function DefaultMidiNoteOptions: TMidiNoteOptions;
begin
  Result := Default(TMidiNoteOptions);
  Result.IncludePercussion := True;
end;

function BeforeOrEqual(const ALeft, ARight: TMidiPosition): Boolean;
begin
  if ALeft.Tick <> ARight.Tick then
  begin
    Exit(ALeft.Tick < ARight.Tick);
  end;
  if ALeft.Track <> ARight.Track then
  begin
    Exit(ALeft.Track < ARight.Track);
  end;
  Result := ALeft.EventIndex <= ARight.EventIndex;
end;

procedure SortPositions(var APositions: TMidiPositions);
var
  LScratch: TMidiPositions;

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
      if BeforeOrEqual(APositions[LLeft], APositions[LRight]) then
      begin
        LScratch[LNext] := APositions[LLeft];
        Inc(LLeft);
      end
      else
      begin
        LScratch[LNext] := APositions[LRight];
        Inc(LRight);
      end;
      Inc(LNext);
    end;
    while LLeft <= LMiddle do
    begin
      LScratch[LNext] := APositions[LLeft];
      Inc(LLeft);
      Inc(LNext);
    end;
    while LRight <= ALast do
    begin
      LScratch[LNext] := APositions[LRight];
      Inc(LRight);
      Inc(LNext);
    end;
    for LIndex := AFirst to ALast do
    begin
      APositions[LIndex] := LScratch[LIndex];
    end;
  end;

begin
  SetLength(LScratch, Length(APositions));
  SortRange(0, High(APositions));
end;

function DecodeMidiNotes(const ABytes: TMidiBytes; const AOptions: TMidiNoteOptions;
  out AReport: TMidiNoteReport): TNoteSequence;
var
  LFile: TMidiFile;
  LLimits: TMidiReadLimits;
  LReport: TMidiNoteReport;
  LPositions: TMidiPositions;
  LEvent: TMidiEvent;
  LTempos: TTempoChanges;
  LGates: TNoteGates;
  LNextGate: array of Integer;
  LHead: array[0..15, 0..127] of Integer;
  LTail: array[0..15, 0..127] of Integer;
  LIndex: Integer;
  LTrack: Integer;
  LEventIndex: Integer;
  LCount: Integer;
  LGateCount: Integer;
  LNoteCapacity: Integer;
  LTick: Int64;
  LLength: Integer;
  LChannel: Integer;
  LPitch: Integer;
  LKind: Integer;
  LGate: Integer;
  LTempo: Integer;
  LTempoCount: Integer;
  LLastTempoTick: Integer;
  LLastTempoValue: Integer;
begin
  AReport := Default(TMidiNoteReport);
  LReport := Default(TMidiNoteReport);
  LReport.UsedDefaultTempo := True;
  LLimits := DefaultMidiReadLimits;
  LLimits.MaxEvents := MaximumMidiImportEvents;
  LFile := DecodeMidiFileWithLimits(ABytes, LLimits);
  LReport.SourceTracks := Length(LFile.Tracks);
  LReport.SourceEvents := LReport.SourceTracks;
  LNoteCapacity := 0;
  for LTrack := 0 to High(LFile.Tracks) do
  begin
    Inc(LReport.SourceEvents, Length(LFile.Tracks[LTrack].Events));
    for LEventIndex := 0 to High(LFile.Tracks[LTrack].Events) do
    begin
      LEvent := LFile.Tracks[LTrack].Events[LEventIndex];
      if ((LEvent.Status and $F0) = $90) and (LEvent.Data[1] > 0) then
      begin
        Inc(LNoteCapacity);
      end;
    end;
  end;
  if LNoteCapacity > MaximumNoteGates then
  begin
    raise EAudio.Create('MIDI source exceeds note-gate budget');
  end;
  SetLength(LPositions, LReport.SourceEvents - LReport.SourceTracks);
  LCount := 0;
  LLength := 0;
  for LTrack := 0 to High(LFile.Tracks) do
  begin
    LTick := 0;
    for LEventIndex := 0 to High(LFile.Tracks[LTrack].Events) do
    begin
      Inc(LTick, LFile.Tracks[LTrack].Events[LEventIndex].DeltaTicks);
      if LTick > High(Integer) then
      begin
        raise EAudio.Create('MIDI absolute tick exceeds sequence range');
      end;
      LPositions[LCount].Tick := LTick;
      LPositions[LCount].Track := LTrack;
      LPositions[LCount].EventIndex := LEventIndex;
      Inc(LCount);
    end;
    Inc(LTick, LFile.Tracks[LTrack].EndDeltaTicks);
    if LTick > High(Integer) then
    begin
      raise EAudio.Create('MIDI end tick exceeds sequence range');
    end;
    LLength := Max(LLength, Integer(LTick));
  end;
  SortPositions(LPositions);
  SetLength(LGates, LNoteCapacity);
  SetLength(LNextGate, LNoteCapacity);
  for LChannel := 0 to 15 do
  begin
    for LPitch := 0 to 127 do
    begin
      LHead[LChannel, LPitch] := -1;
      LTail[LChannel, LPitch] := -1;
    end;
  end;
  { Reserve once: a hostile sequence of tempo events must not induce quadratic
    array copies. The final immutable map receives only the populated prefix. }
  SetLength(LTempos, Min(Length(LPositions) + 1, MaximumTempoChanges));
  LTempoCount := 1;
  LTempos[0] := MakeTempoChange(0, 500000);
  LLastTempoTick := -1;
  LLastTempoValue := 0;
  LGateCount := 0;
  for LIndex := 0 to High(LPositions) do
  begin
    LTrack := LPositions[LIndex].Track;
    LTick := LPositions[LIndex].Tick;
    LEvent := LFile.Tracks[LTrack].Events[LPositions[LIndex].EventIndex];
    if LEvent.Status < $F0 then
    begin
      LChannel := LEvent.Status and $0F;
      LKind := LEvent.Status and $F0;
      if (LKind <> $80) and (LKind <> $90) then
      begin
        if not AOptions.IgnoreUnsupportedEvents then
        begin
          raise EAudio.Create('Performance MIDI events need an explicit ignore-and-report policy');
        end;
        Inc(LReport.IgnoredPerformanceEvents);
        Continue;
      end;
      if (LKind = $80) and (LEvent.Data[1] <> 0) then
      begin
        Inc(LReport.DiscardedReleaseVelocities);
      end;
      if (LChannel = 9) and not AOptions.IncludePercussion then
      begin
        if (LKind = $90) and (LEvent.Data[1] > 0) then
        begin
          Inc(LReport.ExcludedPercussionNotes);
        end;
        Continue;
      end;
      LPitch := LEvent.Data[0];
      if (LKind = $90) and (LEvent.Data[1] > 0) then
      begin
        if LHead[LChannel, LPitch] >= 0 then
        begin
          if not AOptions.AllowOverlapsFIFO then
          begin
            raise EAudio.Create('Overlapping channel/pitch notes require explicit FIFO pairing');
          end;
          Inc(LReport.OverlappingNotesPairedFIFO);
        end;
        LGates[LGateCount].StartTick := LTick;
        LGates[LGateCount].EndTick := -1;
        LGates[LGateCount].Pitch := LPitch;
        LGates[LGateCount].Velocity := LEvent.Data[1];
        LGates[LGateCount].Track := LTrack;
        LGates[LGateCount].Voice := LTrack * 16 + LChannel;
        LGates[LGateCount].Channel := LChannel;
        LNextGate[LGateCount] := -1;
        if LTail[LChannel, LPitch] >= 0 then
        begin
          LNextGate[LTail[LChannel, LPitch]] := LGateCount;
        end
        else
        begin
          LHead[LChannel, LPitch] := LGateCount;
        end;
        LTail[LChannel, LPitch] := LGateCount;
        Inc(LGateCount);
      end
      else
      begin
        LGate := LHead[LChannel, LPitch];
        if LGate < 0 then
        begin
          raise EAudio.Create('MIDI note-off has no corresponding note-on');
        end;
        LGates[LGate].EndTick := LTick;
        LHead[LChannel, LPitch] := LNextGate[LGate];
        if LHead[LChannel, LPitch] < 0 then
        begin
          LTail[LChannel, LPitch] := -1;
        end;
      end;
    end
    else if LEvent.Status = $FF then
    begin
      case LEvent.MetaType of
        $09, $20, $21, $54:
        begin
          raise EAudio.Create('Device, channel-prefix, port or SMPTE-offset metadata is unsupported');
        end;
        $51:
        begin
          LTempo := (Integer(LEvent.Data[0]) shl 16) or
            (Integer(LEvent.Data[1]) shl 8) or LEvent.Data[2];
          if LLastTempoTick = LTick then
          begin
            if LLastTempoValue <> LTempo then
            begin
              raise EAudio.Create('MIDI tracks disagree on tempo at the same tick');
            end;
            Inc(LReport.RedundantTempoEvents);
            Continue;
          end;
          LLastTempoTick := LTick;
          LLastTempoValue := LTempo;
          if LTick = 0 then
          begin
            LTempos[0] := MakeTempoChange(0, LTempo);
            LReport.UsedDefaultTempo := False;
          end
          else if LTempos[LTempoCount - 1].MicrosecondsPerQuarter = LTempo then
          begin
            Inc(LReport.RedundantTempoEvents);
          end
          else
          begin
            if LTempoCount = Length(LTempos) then
            begin
              raise EAudio.Create('MIDI source exceeds tempo-change budget');
            end;
            LTempos[LTempoCount] := MakeTempoChange(LTick, LTempo);
            Inc(LTempoCount);
          end;
        end;
        $00..$08, $58, $59:
        begin
          Inc(LReport.IgnoredMetadataEvents);
        end;
      else
        if not AOptions.IgnoreUnsupportedEvents then
        begin
          raise EAudio.Create('Opaque MIDI metadata needs an explicit ignore-and-report policy');
        end;
        Inc(LReport.IgnoredMetadataEvents);
      end;
    end
    else
    begin
      if not AOptions.IgnoreUnsupportedEvents then
      begin
        raise EAudio.Create('System-exclusive MIDI needs an explicit ignore-and-report policy');
      end;
      Inc(LReport.IgnoredSystemEvents);
    end;
  end;
  LCount := 0;
  for LGate := 0 to LGateCount - 1 do
  begin
    if LGates[LGate].EndTick < 0 then
    begin
      if not AOptions.CloseDanglingNotes then
      begin
        raise EAudio.Create('MIDI source contains an unclosed note gate');
      end;
      LGates[LGate].EndTick := LLength;
      Inc(LReport.ClosedDanglingNotes);
    end;
    if LGates[LGate].EndTick = LGates[LGate].StartTick then
    begin
      Inc(LReport.ZeroLengthNotes);
    end
    else
    begin
      LGates[LCount] := LGates[LGate];
      Inc(LCount);
    end;
  end;
  SetLength(LGates, LCount);
  LReport.NoteCount := LCount;
  SetLength(LTempos, LTempoCount);
  Result := TNoteSequence.Create(LFile.TicksPerQuarter, LLength, LTempos, LGates);
  AReport := LReport;
end;

end.
