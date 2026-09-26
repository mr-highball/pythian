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
program pythian_tests_midi_stream;

{$mode delphi}
{$H+}

uses
  SysUtils,
  pythian.midi.smf,
  pythian.midi.stream
  {$IFDEF WFC_MIDI_STREAM_CHECKS}
  , wfc_midi_smf,
  wfc_midi_stream
  {$ENDIF};

type
  TAbsoluteTicks = array of Int64;

procedure Check(const ACondition: Boolean; const AMessage: String);
begin
  if not ACondition then
  begin
    raise Exception.Create(AMessage);
  end;
end;

procedure Append(var ATarget: TMidiBytes; const ABytes: TMidiBytes);
var
  LOffset: Integer;
  LIndex: Integer;
begin
  LOffset := Length(ATarget);
  SetLength(ATarget, LOffset + Length(ABytes));
  for LIndex := 0 to High(ABytes) do
  begin
    ATarget[LOffset + LIndex] := ABytes[LIndex];
  end;
end;

procedure SameBytes(const ALeft, ARight: TMidiBytes);
var
  LIndex: Integer;
begin
  Check(Length(ALeft) = Length(ARight), 'byte extent mismatch');
  for LIndex := 0 to High(ALeft) do
  begin
    Check(ALeft[LIndex] = ARight[LIndex], 'byte mismatch at ' + IntToStr(LIndex));
  end;
end;

procedure Drain(const AWriter: TMidiFileStream; const ABlock: Integer;
  var AOutput: TMidiBytes);
var
  LBytes: TMidiBytes;
begin
  while AWriter.ReadBytes(ABlock, LBytes) do
  begin
    Check((Length(LBytes) > 0) and (Length(LBytes) <= ABlock) and
      (Length(LBytes) <= MidiStreamBlockBytes), 'output block bounds');
    Append(AOutput, LBytes);
  end;
  Check(LBytes = nil, 'False must return nil');
end;

function Plan(const AEvents: TMidiEvents; const ATicks: TAbsoluteTicks;
  const AEnd: Int64): TMidiTrackPlan;
var
  LCounter: TMidiTrackCounter;
  LIndex: Integer;
begin
  LCounter := TMidiTrackCounter.Create;
  try
    for LIndex := 0 to High(AEvents) do
    begin
      LCounter.AppendEvent(ATicks[LIndex], AEvents[LIndex]);
    end;
    Result := LCounter.Finish(AEnd);
  finally
    LCounter.Free;
  end;
end;

function Render(const AEvents: TMidiEvents; const ATicks: TAbsoluteTicks;
  const AEnd: Int64; const ABlock: Integer): TMidiBytes;
var
  LPlan: TMidiTrackPlan;
  LWriter: TMidiFileStream;
  LEvent: TMidiEvent;
  LIndex: Integer;
  LSize: Int64;
begin
  Result := nil;
  LPlan := Plan(AEvents, ATicks, AEnd);
  LWriter := nil;
  try
    LSize := LPlan.ByteCount + MidiStreamHeaderBytes;
    LWriter := TMidiFileStream.Create(480, LPlan);
    FreeAndNil(LPlan);
    Check(not LWriter.NeedsInput, 'header starts pending');
    Drain(LWriter, ABlock, Result);
    Check(LWriter.NeedsInput and (LWriter.EmittedBytes = 22), 'header extent');
    for LIndex := 0 to High(AEvents) do
    begin
      LEvent := AEvents[LIndex];
      LEvent.Data := Copy(AEvents[LIndex].Data);
      LWriter.AdmitEvent(ATicks[LIndex], LEvent);
      if Length(LEvent.Data) > 0 then
      begin
        LEvent.Data[0] := LEvent.Data[0] xor $7F;
      end;
      Drain(LWriter, ABlock, Result);
    end;
    LWriter.Finish(AEnd);
    LWriter.Finish(AEnd);
    Check(LWriter.InputEnded and not LWriter.Finished, 'EOT must still drain');
    Drain(LWriter, ABlock, Result);
    Check(LWriter.Finished and not LWriter.NeedsInput and
      (LWriter.EmittedBytes = LSize), 'completed exact planned length');
  finally
    LWriter.Free;
    LPlan.Free;
  end;
end;

{$IFDEF WFC_MIDI_STREAM_CHECKS}
procedure CheckCompanion(const AEvents: TMidiEvents;
  const ATicks: TAbsoluteTicks; const AEnd: Int64; const AExpected: TMidiBytes);
var
  LCounter: TWfcMidiTrackCounter;
  LPlan: TWfcMidiTrackPlan;
  LNativePlan: TMidiTrackPlan;
  LWriter: TWfcMidiFileStream;
  LEvent: TWfcMidiEvent;
  LBytes: TWfcMidiBytes;
  LOutput: TMidiBytes;
  LIndex: Integer;
  LByte: Integer;

  procedure DrainCompanion;
  begin
    while LWriter.ReadBytes(137, LBytes) do
    begin
      Append(LOutput, LBytes);
    end;
  end;

begin
  LCounter := TWfcMidiTrackCounter.Create;
  LPlan := nil;
  LNativePlan := nil;
  LWriter := nil;
  LOutput := nil;
  try
    for LIndex := 0 to High(AEvents) do
    begin
      LEvent := Default(TWfcMidiEvent);
      LEvent.Status := AEvents[LIndex].Status;
      LEvent.MetaType := AEvents[LIndex].MetaType;
      SetLength(LEvent.Data, Length(AEvents[LIndex].Data));
      for LByte := 0 to High(LEvent.Data) do
      begin
        LEvent.Data[LByte] := AEvents[LIndex].Data[LByte];
      end;
      LCounter.AppendEvent(ATicks[LIndex], LEvent);
    end;
    LPlan := LCounter.Finish(AEnd);
    LNativePlan := Plan(AEvents, ATicks, AEnd);
    Check((LPlan.ByteCount = LNativePlan.ByteCount) and
      (LPlan.EventCount = LNativePlan.EventCount) and
      (LPlan.BridgeCount = LNativePlan.BridgeCount) and
      (LPlan.Signature = LNativePlan.Signature), 'actual WFC plan parity');
    LWriter := TWfcMidiFileStream.Create(480, LPlan);
    DrainCompanion;
    for LIndex := 0 to High(AEvents) do
    begin
      LEvent := Default(TWfcMidiEvent);
      LEvent.Status := AEvents[LIndex].Status;
      LEvent.MetaType := AEvents[LIndex].MetaType;
      LEvent.Data := Copy(AEvents[LIndex].Data);
      LWriter.AdmitEvent(ATicks[LIndex], LEvent);
      DrainCompanion;
    end;
    LWriter.Finish(AEnd);
    DrainCompanion;
    Check(LWriter.Finished, 'actual WFC completion');
    SameBytes(AExpected, LOutput);
  finally
    LWriter.Free;
    LNativePlan.Free;
    LPlan.Free;
    LCounter.Free;
  end;
end;
{$ENDIF}

procedure CheckCanonical;
const
  Blocks: array[0..3] of Integer = (1, 137, 4096, 65536);
var
  LEvents: TMidiEvents;
  LTicks: TAbsoluteTicks;
  LFile: TMidiFile;
  LDecoded: TMidiFile;
  LExpected: TMidiBytes;
  LActual: TMidiBytes;
  LData: TMidiBytes;
  LPlan: TMidiTrackPlan;
  LIndex: Integer;
  LEnd: Int64;
begin
  SetLength(LEvents, 5);
  SetLength(LTicks, 5);
  LEvents[0] := MakeMidiTempoEvent(0, 500001);
  LEvents[1] := MakeMidiTimeSignatureEvent(0, 4, 2, 24, 8);
  LEvents[2] := MakeMidiChannelEvent(0, $90, [60, 100]);
  SetLength(LData, 16384);
  for LIndex := 0 to High(LData) do
  begin
    LData[LIndex] := Byte(LIndex mod 128);
  end;
  LEvents[3] := MakeMidiSystemExclusiveEvent(0, $F0, LData);
  LEvents[4] := MakeMidiChannelEvent(0, $80, [60, 0]);
  LTicks[0] := 0;
  LTicks[1] := 0;
  LTicks[2] := 128;
  LTicks[3] := 128;
  LTicks[4] := 128 + Int64(MaximumMidiVariableLength) * 2 + 1;
  LEnd := LTicks[4] + MaximumMidiVariableLength;
  LFile := Default(TMidiFile);
  LFile.TicksPerQuarter := 480;
  SetLength(LFile.Tracks, 1);
  SetLength(LFile.Tracks[0].Events, 7);
  for LIndex := 0 to 3 do
  begin
    LFile.Tracks[0].Events[LIndex] := LEvents[LIndex];
  end;
  LFile.Tracks[0].Events[2].DeltaTicks := 128;
  LFile.Tracks[0].Events[4] := MakeMidiMetaEvent(MaximumMidiVariableLength, $01, []);
  LFile.Tracks[0].Events[5] := MakeMidiMetaEvent(MaximumMidiVariableLength, $01, []);
  LFile.Tracks[0].Events[6] := LEvents[4];
  LFile.Tracks[0].Events[6].DeltaTicks := 1;
  LFile.Tracks[0].EndDeltaTicks := MaximumMidiVariableLength;
  LExpected := EncodeMidiFile(LFile);
  LPlan := Plan(LEvents, LTicks, LEnd);
  try
    Check((LPlan.BridgeCount = 2) and (LPlan.EventCount = 6),
      'logical events and long-gap bridges');
  finally
    LPlan.Free;
  end;
  for LIndex := 0 to High(Blocks) do
  begin
    LActual := Render(LEvents, LTicks, LEnd, Blocks[LIndex]);
    SameBytes(LExpected, LActual);
  end;
  LDecoded := DecodeMidiFile(LActual);
  Check((Length(LDecoded.Tracks[0].Events) = 7) and
    (LDecoded.Tracks[0].EndDeltaTicks = MaximumMidiVariableLength),
    'native decoder accepts generated bridges and EOT');
  {$IFDEF WFC_MIDI_STREAM_CHECKS}
  CheckCompanion(LEvents, LTicks, LEnd, LExpected);
  {$ENDIF}
  LEvents := nil;
  LTicks := nil;
  LFile.Tracks[0].Events := nil;
  LFile.Tracks[0].EndDeltaTicks := 0;
  LExpected := EncodeMidiFile(LFile);
  SameBytes(LExpected, Render(LEvents, LTicks, 0, 1));
  {$IFDEF WFC_MIDI_STREAM_CHECKS}
  CheckCompanion(LEvents, LTicks, 0, LExpected);
  {$ENDIF}
  SetLength(LFile.Tracks[0].Events, 1);
  LFile.Tracks[0].Events[0] := MakeMidiMetaEvent(MaximumMidiVariableLength, $01, []);
  LFile.Tracks[0].EndDeltaTicks := 1;
  LEnd := Int64(MaximumMidiVariableLength) + 1;
  LExpected := EncodeMidiFile(LFile);
  SameBytes(LExpected, Render(LEvents, LTicks, LEnd, 1));
  {$IFDEF WFC_MIDI_STREAM_CHECKS}
  CheckCompanion(LEvents, LTicks, LEnd, LExpected);
  {$ENDIF}
end;

procedure CheckLifecycle;
var
  LCounter: TMidiTrackCounter;
  LPlan: TMidiTrackPlan;
  LAgain: TMidiTrackPlan;
  LInvalid: TMidiTrackPlan;
  LWriter: TMidiFileStream;
  LEvent: TMidiEvent;
  LOutput: TMidiBytes;
  LBytes: TMidiBytes;
  LRejected: Boolean;
  LBefore: Int64;
begin
  LCounter := TMidiTrackCounter.Create;
  LPlan := nil;
  LAgain := nil;
  LInvalid := nil;
  LWriter := nil;
  LOutput := nil;
  try
    LEvent := MakeMidiChannelEvent(0, $90, [60, 100]);
    LCounter.AppendEvent(10, LEvent);
    LBefore := LCounter.ByteCount;
    LRejected := False;
    try
      LCounter.AppendEvent(9, LEvent);
    except
      on EMidiStream do LRejected := True;
    end;
    Check(LRejected and (LCounter.ByteCount = LBefore) and
      (LCounter.LastTick = 10), 'invalid counter admission preserves state');
    LPlan := LCounter.Finish(20);
    LAgain := LCounter.Finish(20);
    Check((LAgain <> LPlan) and (LAgain.Signature = LPlan.Signature),
      'repeated Finish returns detached plans');
    LRejected := False;
    try
      LCounter.AppendEvent(20, LEvent);
    except
      on EMidiStream do LRejected := True;
    end;
    Check(LRejected, 'finished counter rejects further input');
    LWriter := TMidiFileStream.Create(480, LPlan);
    Drain(LWriter, 17, LOutput);
    LEvent.DeltaTicks := 1;
    LRejected := False;
    try
      LWriter.AdmitEvent(10, LEvent);
    except
      on EMidiStream do LRejected := True;
    end;
    Check(LRejected and LWriter.NeedsInput and not LWriter.Failed,
      'invalid delta is retryable');
    LEvent.DeltaTicks := 0;
    LEvent.Data[0] := 61;
    LWriter.AdmitEvent(10, LEvent);
    Drain(LWriter, 17, LOutput);
    LRejected := False;
    try
      LWriter.Finish(20);
    except
      on EMidiStream do LRejected := True;
    end;
    Check(LRejected and LWriter.Failed and not LWriter.Finished,
      'same-size changed replay fails final fingerprint');
    LWriter.Cancel;
    Check(LWriter.Failed, 'cancel does not heal failed replay');
    FreeAndNil(LWriter);
    LWriter := TMidiFileStream.Create(480, LPlan);
    LWriter.Cancel;
    Check(LWriter.Cancelled and not LWriter.Finished and not LWriter.NeedsInput,
      'cancel is terminal without successful EOT');
    Check(not LWriter.ReadBytes(32, LBytes) and (LBytes = nil),
      'cancel drops pending header');
    LRejected := False;
    try
      LWriter.Finish(20);
    except
      on EMidiStream do LRejected := True;
    end;
    Check(LRejected, 'cancel rejects Finish');
    FreeAndNil(LWriter);
    LInvalid := TMidiTrackPlan.Create;
    LRejected := False;
    try
      LWriter := TMidiFileStream.Create(480, LInvalid);
    except
      on EMidiStream do LRejected := True;
    end;
    Check(LRejected, 'default-constructed plan cannot be used');
  finally
    LWriter.Free;
    LInvalid.Free;
    LAgain.Free;
    LPlan.Free;
    LCounter.Free;
  end;
end;

procedure CheckCountEnvelope;
var
  LCounter: TMidiTrackCounter;
  LPlan: TMidiTrackPlan;
  LRejected: Boolean;
begin
  LCounter := TMidiTrackCounter.Create;
  LPlan := nil;
  try
    LRejected := False;
    try
      LPlan := LCounter.Finish(MaximumMidiStreamCount + 1);
    except
      on EMidiStream do LRejected := True;
    end;
    Check(LRejected and not LCounter.Finished and (LCounter.ByteCount = 0),
      'out-of-envelope end preserves counter');
    LPlan := LCounter.Finish(MaximumMidiStreamCount);
    Check((LPlan.EventCount = 1) and (LPlan.BridgeCount = 33554432) and
      (LPlan.ByteCount < MaximumMidiTrackBytes),
      'maximum tick counted without expanding millions of bridges');
  finally
    LPlan.Free;
    LCounter.Free;
  end;
end;

begin
  try
    CheckCanonical;
    CheckLifecycle;
    CheckCountEnvelope;
    WriteLn('MIDI streaming: canonical bytes, bridges, ownership and lifecycle passed');
    {$IFDEF WFC_MIDI_STREAM_CHECKS}
    WriteLn('Actual WFC streaming: complete byte and plan parity passed');
    {$ENDIF}
  except
    on E: Exception do
    begin
      WriteLn(StdErr, E.ClassName, ': ', E.Message);
      Halt(1);
    end;
  end;
end.
