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
program pythian_example_midi_stream;

{$mode delphi}
{$H+}

uses
  Classes,
  SysUtils,
  pythian.midi.smf,
  pythian.midi.stream;

const
  NoteCount = 16;
  EventCount = 1 + NoteCount * 2;
  EndTick = NoteCount * 240;

{ A deterministic replayable event source. A real host can traverse a score
  twice or retain/replay a spool instead. No complete event/file array is held. }
procedure EventAt(const AIndex: Integer; out ATick: Int64;
  out AEvent: TMidiEvent);
const
  Pitches: array[0..7] of Byte = (60, 64, 67, 72, 69, 65, 62, 67);
var
  LNote: Integer;
begin
  if AIndex = 0 then
  begin
    ATick := 0;
    AEvent := MakeMidiTempoEvent(0, 500000);
    Exit;
  end;
  LNote := (AIndex - 1) div 2;
  ATick := LNote * 240;
  if Odd(AIndex) then
  begin
    AEvent := MakeMidiChannelEvent(0, $90, [Pitches[LNote mod 8], 96]);
  end
  else
  begin
    Inc(ATick, 210);
    AEvent := MakeMidiChannelEvent(0, $80, [Pitches[LNote mod 8], 0]);
  end;
end;

procedure WriteMidi(const APath: String);
var
  LCounter: TMidiTrackCounter;
  LPlan: TMidiTrackPlan;
  LWriter: TMidiFileStream;
  LFile: TFileStream;
  LEvent: TMidiEvent;
  LTick: Int64;
  LIndex: Integer;

  procedure Drain;
  var
    LBytes: TMidiBytes;
  begin
    while LWriter.ReadBytes(1024, LBytes) do
    begin
      LFile.WriteBuffer(LBytes[0], Length(LBytes));
    end;
  end;

begin
  LCounter := TMidiTrackCounter.Create;
  LPlan := nil;
  LWriter := nil;
  LFile := nil;
  try
    for LIndex := 0 to EventCount - 1 do
    begin
      EventAt(LIndex, LTick, LEvent);
      LCounter.AppendEvent(LTick, LEvent);
    end;
    LPlan := LCounter.Finish(EndTick);
    LWriter := TMidiFileStream.Create(480, LPlan);
    FreeAndNil(LPlan);
    LFile := TFileStream.Create(APath, fmCreate);
    Drain;
    for LIndex := 0 to EventCount - 1 do
    begin
      EventAt(LIndex, LTick, LEvent);
      LWriter.AdmitEvent(LTick, LEvent);
      Drain;
    end;
    LWriter.Finish(EndTick);
    Drain;
    if not LWriter.Finished or (LFile.Size <> LWriter.EmittedBytes) then
    begin
      raise Exception.Create('MIDI output did not finish at its planned length');
    end;
    WriteLn('Wrote ', LWriter.EmittedBytes, ' bytes, ', NoteCount,
      ' authored notes: ', APath);
  finally
    LFile.Free;
    LWriter.Free;
    LPlan.Free;
    LCounter.Free;
  end;
end;

begin
  try
    if ParamCount <> 1 then
    begin
      raise Exception.Create('usage: pythian.example.midi.stream OUTPUT.mid');
    end;
    WriteMidi(ParamStr(1));
  except
    on E: Exception do
    begin
      WriteLn(StdErr, E.ClassName, ': ', E.Message);
      Halt(1);
    end;
  end;
end.
