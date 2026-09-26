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
program pythian_tests_midi_chord;

{$mode delphi}
{$H+}

uses
  SysUtils,
  pythian.chord,
  pythian.midi.smf,
  pythian.midi.stream,
  pythian.midi.chord
  {$IFDEF WFC_CHORD_MIDI_CHECKS}
  , pythian.wfc.music,
  wfc_music_sequence,
  wfc_music_ensemble,
  wfc_midi_smf,
  wfc_music_ensemble_midi
  {$ENDIF};

type
  TFrames = array of TChordFrame;
  TLengths = array of Int64;
  TTimings = array of TChordMidiTiming;

procedure Check(const ACondition: Boolean; const AMessage: String);
begin
  if not ACondition then
  begin
    raise Exception.Create(AMessage);
  end;
end;

procedure SameBytes(const ALeft, ARight: TMidiBytes);
var
  LIndex: Integer;
begin
  Check(Length(ALeft) = Length(ARight), 'byte extent');
  for LIndex := 0 to High(ALeft) do
  begin
    Check(ALeft[LIndex] = ARight[LIndex], 'byte mismatch at ' + IntToStr(LIndex));
  end;
end;

procedure Append(var AOutput: TMidiBytes; const ABlock: TMidiBytes);
var
  LIndex: Integer;
  LOffset: Integer;
begin
  LOffset := Length(AOutput);
  SetLength(AOutput, LOffset + Length(ABlock));
  for LIndex := 0 to High(ABlock) do
  begin
    AOutput[LOffset + LIndex] := ABlock[LIndex];
  end;
end;

function Voice(const AAction: TChordAction; const APitches, AVelocities: array of Integer): TChordVoice;
var
  LIndex: Integer;
begin
  Result := Default(TChordVoice);
  Result.Action := AAction;
  Check(Length(APitches) = Length(AVelocities), 'fixture arity');
  SetLength(Result.Tones, Length(APitches));
  for LIndex := 0 to High(APitches) do
  begin
    Result.Tones[LIndex].Pitch := APitches[LIndex];
    Result.Tones[LIndex].Velocity := AVelocities[LIndex];
  end;
end;

procedure Fixture(out AFrames: TFrames; out ALengths: TLengths; out ATimings: TTimings);
var
  LIndex: Integer;
begin
  SetLength(AFrames, 4);
  SetLength(ALengths, 4);
  SetLength(ATimings, 4);
  for LIndex := 0 to 3 do
  begin
    SetLength(AFrames[LIndex], 2);
    ALengths[LIndex] := 120;
    ATimings[LIndex] := Default(TChordMidiTiming);
    if LIndex in [0, 3] then
    begin
      AFrames[LIndex][0] := Voice(caAttack, [48, 55], [80, 70]);
    end
    else
    begin
      AFrames[LIndex][0] := Voice(caHold, [48, 55], [80, 70]);
    end;
  end;
  AFrames[0][1] := Voice(caAttack, [60], [90]);
  AFrames[1][1] := Voice(caAttack, [62], [90]);
  AFrames[2][1] := Voice(caRest, [], []);
  AFrames[3][1] := Voice(caAttack, [64], [90]);
  ATimings[1].TempoMicrosecondsPerQuarter := 600000;
  ATimings[1].MeterNumerator := 3;
  ATimings[1].MeterDenominatorPower := 2;
  ATimings[3].TempoMicrosecondsPerQuarter := 600000;
end;

function Plan(const AFrames: TFrames; const ALengths: TLengths;
  const ATimings: TTimings; const AOptions: TChordMidiOptions): TChordMidiPlan;
var
  LCounter: TChordMidiCounter;
  LIndex: Integer;
begin
  LCounter := TChordMidiCounter.Create(AOptions);
  try
    for LIndex := 0 to High(AFrames) do
    begin
      LCounter.AdmitFrame(AFrames[LIndex], ALengths[LIndex], ATimings[LIndex]);
    end;
    Result := LCounter.Finish;
  finally
    LCounter.Free;
  end;
end;

procedure Drain(const AStream: TChordMidiStream; const ABlockSize: Integer; var ABytes: TMidiBytes);
var
  LBlock: TMidiBytes;
begin
  while AStream.ReadBytes(ABlockSize, LBlock) do
  begin
    Check((Length(LBlock) > 0) and (Length(LBlock) <= ABlockSize) and
      (Length(LBlock) <= MidiStreamBlockBytes), 'bounded output');
    Append(ABytes, LBlock);
  end;
  Check(LBlock = nil, 'False returns nil');
end;

function Render(const AFrames: TFrames; const ALengths: TLengths;
  const ATimings: TTimings; const AOptions: TChordMidiOptions;
  const ABlockSize: Integer): TMidiBytes;
var
  LPlan: TChordMidiPlan;
  LStream: TChordMidiStream;
  LFrame: TChordFrame;
  LIndex: Integer;
  LVoice: Integer;
  LExpected: Int64;
begin
  Result := nil;
  LPlan := Plan(AFrames, ALengths, ATimings, AOptions);
  LStream := nil;
  try
    LExpected := LPlan.ByteCount + MidiStreamHeaderBytes;
    LStream := TChordMidiStream.Create(LPlan);
    FreeAndNil(LPlan);
    Check(not LStream.NeedsInput, 'header/timing initially pending');
    Drain(LStream, ABlockSize, Result);
    for LIndex := 0 to High(AFrames) do
    begin
      Check(LStream.NeedsInput, 'frame boundary ready');
      LFrame := Copy(AFrames[LIndex]);
      for LVoice := 0 to High(LFrame) do
      begin
        LFrame[LVoice].Tones := Copy(AFrames[LIndex][LVoice].Tones);
      end;
      LStream.AdmitFrame(LFrame, ALengths[LIndex], ATimings[LIndex]);
      if Length(LFrame[0].Tones) > 0 then
      begin
        LFrame[0].Tones[0].Pitch := 0;
      end;
      Drain(LStream, ABlockSize, Result);
    end;
    LStream.EndInput;
    LStream.EndInput;
    Check(LStream.InputEnded and not LStream.Finished, 'final offs/EOT still pending');
    Drain(LStream, ABlockSize, Result);
    Check(LStream.Finished and (LStream.EmittedBytes = LExpected), 'complete planned file');
  finally
    LStream.Free;
    LPlan.Free;
  end;
end;

{$IFDEF WFC_CHORD_MIDI_CHECKS}
function CompanionFrame(const AFrame: TChordFrame): TWfcMusicEnsembleFrame;
var
  LVoice: Integer;
  LTone: Integer;
begin
  Result := Default(TWfcMusicEnsembleFrame);
  SetLength(Result.Voices, Length(AFrame));
  for LVoice := 0 to High(AFrame) do
  begin
    case AFrame[LVoice].Action of
      caRest: Result.Voices[LVoice].Action := wmcaRest;
      caAttack: Result.Voices[LVoice].Action := wmcaAttack;
      caHold: Result.Voices[LVoice].Action := wmcaHold;
    end;
    SetLength(Result.Voices[LVoice].Tones, Length(AFrame[LVoice].Tones));
    for LTone := 0 to High(AFrame[LVoice].Tones) do
    begin
      Result.Voices[LVoice].Tones[LTone].Pitch := AFrame[LVoice].Tones[LTone].Pitch;
      Result.Voices[LVoice].Tones[LTone].Velocity := AFrame[LVoice].Tones[LTone].Velocity;
    end;
  end;
end;

procedure CheckCompanion(const AFrames: TFrames; const ALengths: TLengths;
  const ATimings: TTimings; const AOptions: TChordMidiOptions; const AExpected: TMidiBytes);
var
  LCounter: TWfcMusicEnsembleMidiCounter;
  LPlan: TWfcMusicEnsembleMidiPlan;
  LNativePlan: TChordMidiPlan;
  LStream: TWfcMusicEnsembleMidiStream;
  LOptions: TWfcMusicEnsembleMidiOptions;
  LTiming: TWfcMusicEnsembleMidiTiming;
  LFrame: TWfcMusicEnsembleFrame;
  LNativeFrame: TChordFrame;
  LBlock: TWfcMidiBytes;
  LOutput: TMidiBytes;
  LIndex: Integer;
  LVoice: Integer;
  LTone: Integer;

  procedure DrainCompanion;
  begin
    while LStream.ReadBytes(13, LBlock) do
    begin
      Append(LOutput, LBlock);
    end;
  end;

  procedure ReadFrame(const AIndex: Integer);
  begin
    LFrame := CompanionFrame(AFrames[AIndex]);
    LTiming.TempoMicrosecondsPerQuarter := ATimings[AIndex].TempoMicrosecondsPerQuarter;
    LTiming.MeterNumerator := ATimings[AIndex].MeterNumerator;
    LTiming.MeterDenominatorPower := ATimings[AIndex].MeterDenominatorPower;
  end;

begin
  LOptions := DefaultWfcMusicEnsembleMidiOptions(AOptions.Channels);
  LOptions.TicksPerQuarter := AOptions.TicksPerQuarter;
  LOptions.TempoMicrosecondsPerQuarter := AOptions.TempoMicrosecondsPerQuarter;
  LOptions.MeterNumerator := AOptions.MeterNumerator;
  LOptions.MeterDenominatorPower := AOptions.MeterDenominatorPower;
  LCounter := TWfcMusicEnsembleMidiCounter.Create(LOptions);
  LPlan := nil;
  LNativePlan := nil;
  LStream := nil;
  LOutput := nil;
  try
    for LIndex := 0 to High(AFrames) do
    begin
      ReadFrame(LIndex);
      LCounter.AdmitFrame(LFrame, ALengths[LIndex], LTiming);
      LNativeFrame := ProjectWfcChordFrame(LFrame);
      for LVoice := 0 to High(LNativeFrame) do
      begin
        Check(LNativeFrame[LVoice].Action = AFrames[LIndex][LVoice].Action, 'bridge action');
        for LTone := 0 to High(LNativeFrame[LVoice].Tones) do
        begin
          Check((LNativeFrame[LVoice].Tones[LTone].Pitch = AFrames[LIndex][LVoice].Tones[LTone].Pitch) and
            (LNativeFrame[LVoice].Tones[LTone].Velocity = AFrames[LIndex][LVoice].Tones[LTone].Velocity),
            'bridge tone');
        end;
      end;
      if Length(LNativeFrame[0].Tones) > 0 then
      begin
        LNativeFrame[0].Tones[0].Pitch := 0;
        Check(LFrame.Voices[0].Tones[0].Pitch = AFrames[LIndex][0].Tones[0].Pitch,
          'bridge payload detached');
      end;
    end;
    LPlan := LCounter.Finish;
    LNativePlan := Plan(AFrames, ALengths, ATimings, AOptions);
    Check((LPlan.EndTick = LNativePlan.EndTick) and (LPlan.ByteCount = LNativePlan.ByteCount) and
      (LPlan.EventCount = LNativePlan.EventCount) and (LPlan.BridgeCount = LNativePlan.BridgeCount) and
      (LPlan.Signature = LNativePlan.Signature), 'actual WFC complete plan parity');
    LStream := TWfcMusicEnsembleMidiStream.Create(LPlan);
    DrainCompanion;
    for LIndex := 0 to High(AFrames) do
    begin
      ReadFrame(LIndex);
      LStream.AdmitFrame(LFrame, ALengths[LIndex], LTiming);
      DrainCompanion;
    end;
    LStream.EndInput;
    DrainCompanion;
    Check(LStream.Finished, 'actual WFC completion');
    SameBytes(AExpected, LOutput);
  finally
    LStream.Free;
    LNativePlan.Free;
    LPlan.Free;
    LCounter.Free;
  end;
end;
{$ENDIF}

procedure CheckCanonical;
var
  LFrames: TFrames;
  LLengths: TLengths;
  LTimings: TTimings;
  LOptions: TChordMidiOptions;
  LFile: TMidiFile;
  LBytes: TMidiBytes;
begin
  Fixture(LFrames, LLengths, LTimings);
  LOptions := DefaultChordMidiOptions([5, 2]);
  LOptions.TicksPerQuarter := 120;
  LFile := Default(TMidiFile);
  LFile.TicksPerQuarter := 120;
  SetLength(LFile.Tracks, 1);
  SetLength(LFile.Tracks[0].Events, 19);
  LFile.Tracks[0].Events[0] := MakeMidiTempoEvent(0, 500000);
  LFile.Tracks[0].Events[1] := MakeMidiTimeSignatureEvent(0, 4, 2, 24, 8);
  LFile.Tracks[0].Events[2] := MakeMidiChannelEvent(0, $95, [48, 80]);
  LFile.Tracks[0].Events[3] := MakeMidiChannelEvent(0, $95, [55, 70]);
  LFile.Tracks[0].Events[4] := MakeMidiChannelEvent(0, $92, [60, 90]);
  LFile.Tracks[0].Events[5] := MakeMidiTempoEvent(120, 600000);
  LFile.Tracks[0].Events[6] := MakeMidiTimeSignatureEvent(0, 3, 2, 24, 8);
  LFile.Tracks[0].Events[7] := MakeMidiChannelEvent(0, $82, [60, 0]);
  LFile.Tracks[0].Events[8] := MakeMidiChannelEvent(0, $92, [62, 90]);
  LFile.Tracks[0].Events[9] := MakeMidiChannelEvent(120, $82, [62, 0]);
  LFile.Tracks[0].Events[10] := MakeMidiTempoEvent(120, 600000);
  LFile.Tracks[0].Events[11] := MakeMidiChannelEvent(0, $85, [48, 0]);
  LFile.Tracks[0].Events[12] := MakeMidiChannelEvent(0, $85, [55, 0]);
  LFile.Tracks[0].Events[13] := MakeMidiChannelEvent(0, $95, [48, 80]);
  LFile.Tracks[0].Events[14] := MakeMidiChannelEvent(0, $95, [55, 70]);
  LFile.Tracks[0].Events[15] := MakeMidiChannelEvent(0, $92, [64, 90]);
  LFile.Tracks[0].Events[16] := MakeMidiChannelEvent(120, $85, [48, 0]);
  LFile.Tracks[0].Events[17] := MakeMidiChannelEvent(0, $85, [55, 0]);
  LFile.Tracks[0].Events[18] := MakeMidiChannelEvent(0, $82, [64, 0]);
  LBytes := EncodeMidiFile(LFile);
  SameBytes(LBytes, Render(LFrames, LLengths, LTimings, LOptions, 1));
  SameBytes(LBytes, Render(LFrames, LLengths, LTimings, LOptions, 7));
  SameBytes(LBytes, Render(LFrames, LLengths, LTimings, LOptions, 5000));
  {$IFDEF WFC_CHORD_MIDI_CHECKS}
  CheckCompanion(LFrames, LLengths, LTimings, LOptions, LBytes);
  {$ENDIF}
  LFrames := nil;
  LLengths := nil;
  LTimings := nil;
  SetLength(LFile.Tracks[0].Events, 2);
  LBytes := EncodeMidiFile(LFile);
  SameBytes(LBytes, Render(LFrames, LLengths, LTimings, LOptions, 1));
  {$IFDEF WFC_CHORD_MIDI_CHECKS}
  CheckCompanion(LFrames, LLengths, LTimings, LOptions, LBytes);
  {$ENDIF}
end;

procedure CheckLifecycle;
var
  LFrames: TFrames;
  LLengths: TLengths;
  LTimings: TTimings;
  LOptions: TChordMidiOptions;
  LCounter: TChordMidiCounter;
  LPlan: TChordMidiPlan;
  LInvalid: TChordMidiPlan;
  LStream: TChordMidiStream;
  LBytes: TMidiBytes;
  LBlock: TMidiBytes;
  LRejected: Boolean;
  LBefore: Int64;
begin
  Fixture(LFrames, LLengths, LTimings);
  LOptions := DefaultChordMidiOptions([5, 2]);
  LCounter := TChordMidiCounter.Create(LOptions);
  LPlan := nil;
  LInvalid := nil;
  LStream := nil;
  LBytes := nil;
  try
    LCounter.AdmitFrame(LFrames[0], 120);
    LFrames[1][0].Tones[0].Velocity := 81;
    LRejected := False;
    try
      LCounter.AdmitFrame(LFrames[1], 120);
    except
      on EChordMidi do LRejected := True;
    end;
    Check(LRejected and (LCounter.TickCount = 120) and not LCounter.Failed,
      'invalid hold is retryable without advancing');
    LFrames[1][0].Tones[0].Velocity := 80;
    LPlan := LCounter.Finish;
    LOptions := LPlan.CopyOptions;
    LOptions.Channels[0] := 9;
    Check(LPlan.CopyOptions.Channels[0] = 5, 'plan options detached');
    LStream := TChordMidiStream.Create(LPlan);
    Drain(LStream, 4096, LBytes);
    LFrames[0][0].Tones[0].Velocity := 81;
    LStream.AdmitFrame(LFrames[0], 120);
    Drain(LStream, 4096, LBytes);
    LBefore := LStream.EmittedBytes;
    LStream.EndInput;
    LRejected := False;
    try
      LStream.ReadBytes(4096, LBlock);
    except
      on EMidiStream do LRejected := True;
    end;
    Check(LRejected and LStream.Failed and (LBlock = nil) and
      (LStream.EmittedBytes = LBefore), 'failed coalesced final read publishes no bytes');
    FreeAndNil(LStream);
    LStream := TChordMidiStream.Create(LPlan);
    LStream.Cancel;
    Check(LStream.Cancelled and not LStream.Finished and not LStream.NeedsInput,
      'cancellation terminal');
    Check(not LStream.ReadBytes(10, LBlock) and (LBlock = nil), 'cancel drops header');
    FreeAndNil(LStream);
    LInvalid := TChordMidiPlan.Create;
    LRejected := False;
    try
      LStream := TChordMidiStream.Create(LInvalid);
    except
      on EChordMidi do LRejected := True;
    end;
    Check(LRejected, 'default plan is invalid');
  finally
    LStream.Free;
    LInvalid.Free;
    LPlan.Free;
    LCounter.Free;
  end;
end;

procedure CheckLongHold;
var
  LFrames: TFrames;
  LLengths: TLengths;
  LTimings: TTimings;
  LOptions: TChordMidiOptions;
  LFile: TMidiFile;
  LBytes: TMidiBytes;
  LPlan: TChordMidiPlan;
begin
  SetLength(LFrames, 2);
  SetLength(LFrames[0], 1);
  SetLength(LFrames[1], 1);
  LFrames[0][0] := Voice(caAttack, [60], [100]);
  LFrames[1][0] := Voice(caHold, [60], [100]);
  SetLength(LLengths, 2);
  LLengths[0] := MaximumMidiVariableLength;
  LLengths[1] := 1;
  SetLength(LTimings, 2);
  LOptions := DefaultChordMidiOptions([0]);
  LFile := Default(TMidiFile);
  LFile.TicksPerQuarter := 480;
  SetLength(LFile.Tracks, 1);
  SetLength(LFile.Tracks[0].Events, 5);
  LFile.Tracks[0].Events[0] := MakeMidiTempoEvent(0, 500000);
  LFile.Tracks[0].Events[1] := MakeMidiTimeSignatureEvent(0, 4, 2, 24, 8);
  LFile.Tracks[0].Events[2] := MakeMidiChannelEvent(0, $90, [60, 100]);
  LFile.Tracks[0].Events[3] := MakeMidiMetaEvent(MaximumMidiVariableLength, $01, []);
  LFile.Tracks[0].Events[4] := MakeMidiChannelEvent(1, $80, [60, 0]);
  LBytes := EncodeMidiFile(LFile);
  SameBytes(LBytes, Render(LFrames, LLengths, LTimings, LOptions, 1));
  {$IFDEF WFC_CHORD_MIDI_CHECKS}
  CheckCompanion(LFrames, LLengths, LTimings, LOptions, LBytes);
  {$ENDIF}
  LLengths[0] := MaximumMidiStreamCount - 1;
  LPlan := Plan(LFrames, LLengths, LTimings, LOptions);
  try
    Check((LPlan.EndTick = MaximumMidiStreamCount) and (LPlan.BridgeCount = 33554432),
      'wide held duration counted without event expansion');
  finally
    LPlan.Free;
  end;
end;

procedure CheckFullChannels;
var
  LFrames: TFrames;
  LLengths: TLengths;
  LTimings: TTimings;
  LChannels: TChordMidiChannels;
  LOptions: TChordMidiOptions;
  LFile: TMidiFile;
  LBytes: TMidiBytes;
  LVoice: Integer;
  LPitch: Integer;
  LEvent: Integer;
begin
  SetLength(LFrames, 1);
  SetLength(LFrames[0], 16);
  SetLength(LLengths, 1);
  LLengths[0] := 1;
  SetLength(LTimings, 1);
  SetLength(LChannels, 16);
  LFile := Default(TMidiFile);
  LFile.TicksPerQuarter := 480;
  SetLength(LFile.Tracks, 1);
  SetLength(LFile.Tracks[0].Events, 4098);
  LFile.Tracks[0].Events[0] := MakeMidiTempoEvent(0, 500000);
  LFile.Tracks[0].Events[1] := MakeMidiTimeSignatureEvent(0, 4, 2, 24, 8);
  for LVoice := 0 to 15 do
  begin
    LChannels[LVoice] := 15 - LVoice;
    LFrames[0][LVoice].Action := caAttack;
    SetLength(LFrames[0][LVoice].Tones, 128);
    for LPitch := 0 to 127 do
    begin
      LFrames[0][LVoice].Tones[LPitch].Pitch := LPitch;
      LFrames[0][LVoice].Tones[LPitch].Velocity := 127;
      LEvent := 2 + LVoice * 128 + LPitch;
      LFile.Tracks[0].Events[LEvent] := MakeMidiChannelEvent(0,
        Byte($90 + LChannels[LVoice]), [Byte(LPitch), 127]);
      LFile.Tracks[0].Events[LEvent + 2048] := MakeMidiChannelEvent(0,
        Byte($80 + LChannels[LVoice]), [Byte(LPitch), 0]);
    end;
  end;
  LFile.Tracks[0].Events[2050].DeltaTicks := 1;
  LOptions := DefaultChordMidiOptions(LChannels);
  LBytes := EncodeMidiFile(LFile);
  SameBytes(LBytes, Render(LFrames, LLengths, LTimings, LOptions, 5000));
  {$IFDEF WFC_CHORD_MIDI_CHECKS}
  CheckCompanion(LFrames, LLengths, LTimings, LOptions, LBytes);
  {$ENDIF}
end;

begin
  try
    CheckCanonical;
    CheckLifecycle;
    CheckLongHold;
    CheckFullChannels;
    WriteLn('Chord MIDI: canonical bytes, timing, holds, ownership, failure and wide counts passed');
    {$IFDEF WFC_CHORD_MIDI_CHECKS}
    WriteLn('Actual WFC chord MIDI: complete bytes/plan parity and detached frame bridge passed');
    {$ENDIF}
  except
    on E: Exception do
    begin
      WriteLn(StdErr, E.ClassName, ': ', E.Message);
      Halt(1);
    end;
  end;
end.
