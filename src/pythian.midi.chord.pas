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

unit pythian.midi.chord;

{$mode delphi}
{$H+}

interface

uses
  pythian.chord,
  pythian.midi.smf,
  pythian.midi.stream;

const
  ChordMidiVersion = 1;

type
  EChordMidi = class(EMidiStream);
  TChordMidiChannels = array of Integer;
  TChordMidiOptions = record
    TicksPerQuarter: Integer;
    TempoMicrosecondsPerQuarter: Integer;
    MeterNumerator: Integer;
    MeterDenominatorPower: Integer;
    Channels: TChordMidiChannels;
  end;
  { Zero tempo / zero numerator mean no change. Denominator must also be zero
    when no meter is supplied. Explicit changes, including repeated values, are
    emitted at the frame start, tempo before meter, before any note events. }
  TChordMidiTiming = record
    TempoMicrosecondsPerQuarter: Integer;
    MeterNumerator: Integer;
    MeterDenominatorPower: Integer;
  end;

  { Implementation cursor shared by the two public transports. Its memory is
    bounded by the active and pending frame, not elapsed ticks/events. Prefer
    Counter and Stream below; neither retains a score or event timeline. }
  TChordMidiEvents = class
  private
    FOptions: TChordMidiOptions;
    FActive: TChordFrame;
    FPending: TChordFrame;
    FTiming: TChordMidiTiming;
    FTick: TMidiStreamCount;
    FEventTick: TMidiStreamCount;
    FPhase: Integer;
    FVoice: Integer;
    FTone: Integer;
    FInputEnded: Boolean;
    FCancelled: Boolean;
    function GetNeedsInput: Boolean;
    function GetFinished: Boolean;
    procedure AdvancePhase;
  public
    constructor Create(const AOptions: TChordMidiOptions);
    procedure AdmitFrame(const AFrame: TChordFrame;
      const ALength: TMidiStreamCount;
      const ATiming: TChordMidiTiming);
    function NextEvent(out ATick: TMidiStreamCount;
      out AEvent: TMidiEvent): Boolean;
    procedure EndInput;
    procedure Cancel;
    property NeedsInput: Boolean read GetNeedsInput;
    property Finished: Boolean read GetFinished;
    property InputEnded: Boolean read FInputEnded;
    property TickCount: TMidiStreamCount read FTick;
  end;

  { Caller-owned immutable configuration and track plan. CopyOptions detaches
    its channel array. The diagnostic signature covers track events, NOT the
    TPQ file header; this wrapper binds TPQ through its immutable options.
    FNV32 is not cryptographic proof: replay the same trusted immutable source.
    ByteCount excludes the 22-byte file/chunk header. }
  TChordMidiPlan = class
  private
    FOptions: TChordMidiOptions;
    FTrack: TMidiTrackPlan;
    class function NewPlan(const AOptions: TChordMidiOptions;
      const ATrack: TMidiTrackPlan): TChordMidiPlan; static;
    procedure RequirePlan;
    function GetEndTick: TMidiStreamCount;
    function GetByteCount: TMidiStreamCount;
    function GetEventCount: TMidiStreamCount;
    function GetBridgeCount: TMidiStreamCount;
    function GetSignature: Cardinal;
  public
    destructor Destroy; override;
    function CopyOptions: TChordMidiOptions;
    property EndTick: TMidiStreamCount read GetEndTick;
    property ByteCount: TMidiStreamCount read GetByteCount;
    property EventCount: TMidiStreamCount read GetEventCount;
    property BridgeCount: TMidiStreamCount read GetBridgeCount;
    property Signature: Cardinal read GetSignature;
  end;

  { Counting pass. Channels must map 1..16 voices uniquely to MIDI 0..15.
    Under General MIDI channel 9 is percussion; mapping it is explicit, never
    silently skipped or selected. No program/bank/tuning messages are invented.
    Tones use sorted unique 12-step MIDI pitches 0..127 and velocities 1..127.
    Positive frame lengths and their sum fit the portable exact-integer range.
    Holds require identical active pitches AND velocities and emit no seam
    events. Rest/attack close previous tones. All offs precede all ons, ordered
    by voice then pitch. Finish closes held notes at the exact accepted end.
    Empty input is valid initial tempo/meter plus EOT at zero.
    Invalid arguments are retryable; processing/capacity failures set Failed. }
  TChordMidiCounter = class
  private
    FOptions: TChordMidiOptions;
    FEvents: TChordMidiEvents;
    FCounter: TMidiTrackCounter;
    FFailed: Boolean;
    procedure Drain;
    function GetTickCount: TMidiStreamCount;
    function GetFinished: Boolean;
  public
    constructor Create(const AOptions: TChordMidiOptions);
    destructor Destroy; override;
    procedure AdmitFrame(const AFrame: TChordFrame;
      const ALength: TMidiStreamCount); overload;
    procedure AdmitFrame(const AFrame: TChordFrame;
      const ALength: TMidiStreamCount;
      const ATiming: TChordMidiTiming); overload;
    function Finish: TChordMidiPlan;
    property TickCount: TMidiStreamCount read GetTickCount;
    property Finished: Boolean read GetFinished;
    property Failed: Boolean read FFailed;
  end;

  { Replay pass. Create copies all plan data; the caller can free the plan.
    Drain initial header/metadata, AdmitFrame only when NeedsInput, and drain
    each frame. EndInput closes voices and verifies the planned track before
    the final EOT can be returned. Publish only after Finished; processing
    failure, cancellation or replay mismatch requires discarding the already-read
    prefix. The stream never owns files, callbacks or publication.
    ReadBytes returns detached blocks <=4096 bytes; False always sets nil.
    Invalid arguments/state remain retryable. Unexpected processing errors
    poison Failed. Cancel is terminal, discards pending data and emits no EOT.
    Same-tick ordering and delay bridges are project encoding policies.
    Sequential/non-reentrant; a plan is not a resumable generation checkpoint. }
  TChordMidiStream = class
  private
    FEvents: TChordMidiEvents;
    FStream: TMidiFileStream;
    FEmittedBytes: TMidiStreamCount;
    FFailed: Boolean;
    FCancelled: Boolean;
    function GetNeedsInput: Boolean;
    function GetFinished: Boolean;
    function GetFailed: Boolean;
    function GetInputEnded: Boolean;
    function GetTickCount: TMidiStreamCount;
    function GetEmittedBytes: TMidiStreamCount;
  public
    constructor Create(const APlan: TChordMidiPlan);
    destructor Destroy; override;
    procedure AdmitFrame(const AFrame: TChordFrame;
      const ALength: TMidiStreamCount); overload;
    procedure AdmitFrame(const AFrame: TChordFrame;
      const ALength: TMidiStreamCount;
      const ATiming: TChordMidiTiming); overload;
    function ReadBytes(const AMaxBytes: Integer; out ABytes: TMidiBytes): Boolean;
    procedure EndInput;
    procedure Cancel;
    property NeedsInput: Boolean read GetNeedsInput;
    property InputEnded: Boolean read GetInputEnded;
    property Finished: Boolean read GetFinished;
    property Failed: Boolean read GetFailed;
    property Cancelled: Boolean read FCancelled;
    property TickCount: TMidiStreamCount read GetTickCount;
    property EmittedBytes: TMidiStreamCount read GetEmittedBytes;
  end;

function DefaultChordMidiOptions(const AChannels: array of Integer):
  TChordMidiOptions;

implementation

uses
  SysUtils;

procedure MidiError(const AMessage: String);
begin
  raise EChordMidi.Create('cannot stream chord MIDI: ' + AMessage);
end;

procedure CheckInteger(const AValue, AMin, AMax: TMidiStreamCount;
  const AName: String);
begin
  if (AValue < AMin) or (AValue > AMax) then
  begin
    MidiError(AName + ' is outside its exact integer range');
  end;
end;

function CloneOptions(const AOptions: TChordMidiOptions):
  TChordMidiOptions;
var
  LIndex: Integer;
begin
  Result := AOptions;
  Result.Channels := nil;
  SetLength(Result.Channels, Length(AOptions.Channels));
  for LIndex := 0 to High(Result.Channels) do
  begin
    Result.Channels[LIndex] := AOptions.Channels[LIndex];
  end;
end;

function CloneFrame(const AFrame: TChordFrame): TChordFrame;
var
  LVoice: Integer;
begin
  Result := nil;
  SetLength(Result, Length(AFrame));
  for LVoice := 0 to High(AFrame) do
  begin
    Result[LVoice].Action := AFrame[LVoice].Action;
    Result[LVoice].Tones := Copy(AFrame[LVoice].Tones);
  end;
end;

procedure ValidateOptions(const AOptions: TChordMidiOptions);
var
  LIndex: Integer;
  LPeer: Integer;
begin
  CheckInteger(AOptions.TicksPerQuarter, 1, 32767, 'ticks per quarter');
  CheckInteger(AOptions.TempoMicrosecondsPerQuarter, 1, $FFFFFF, 'tempo');
  CheckInteger(AOptions.MeterNumerator, 1, 255, 'meter numerator');
  CheckInteger(AOptions.MeterDenominatorPower, 0, 255, 'meter denominator power');
  if (Length(AOptions.Channels) < 1) or (Length(AOptions.Channels) > 16) then
  begin
    MidiError('voice count must fit the 16 MIDI channels');
  end;
  for LIndex := 0 to High(AOptions.Channels) do
  begin
    CheckInteger(AOptions.Channels[LIndex], 0, 15, 'channel');
    for LPeer := 0 to LIndex - 1 do
    begin
      if AOptions.Channels[LIndex] = AOptions.Channels[LPeer] then
      begin
        MidiError('voice channels must be unique');
      end;
    end;
  end;
end;

procedure ValidateTiming(const ATiming: TChordMidiTiming);
begin
  CheckInteger(ATiming.TempoMicrosecondsPerQuarter, 0, $FFFFFF, 'tempo change');
  CheckInteger(ATiming.MeterNumerator, 0, 255, 'meter numerator change');
  CheckInteger(ATiming.MeterDenominatorPower, 0, 255, 'meter denominator power change');
  if (ATiming.MeterNumerator = 0) and (ATiming.MeterDenominatorPower <> 0) then
  begin
    MidiError('absent meter change must have zero denominator power');
  end;
end;

function DefaultChordMidiOptions(const AChannels: array of Integer):
  TChordMidiOptions;
var
  LIndex: Integer;
begin
  Result := Default(TChordMidiOptions);
  Result.TicksPerQuarter := 480;
  Result.TempoMicrosecondsPerQuarter := 500000;
  Result.MeterNumerator := 4;
  Result.MeterDenominatorPower := 2;
  if (Length(AChannels) < 1) or (Length(AChannels) > 16) then
  begin
    MidiError('voice count must fit the 16 MIDI channels');
  end;
  SetLength(Result.Channels, Length(AChannels));
  for LIndex := 0 to High(AChannels) do
  begin
    Result.Channels[LIndex] := AChannels[LIndex];
  end;
  ValidateOptions(Result);
end;

constructor TChordMidiEvents.Create(
  const AOptions: TChordMidiOptions);
var
  LIndex: Integer;
begin
  inherited Create;
  ValidateOptions(AOptions);
  FOptions := CloneOptions(AOptions);
  SetLength(FActive, Length(FOptions.Channels));
  SetLength(FPending, Length(FOptions.Channels));
  for LIndex := 0 to High(FActive) do
  begin
    FActive[LIndex] := Default(TChordVoice);
    FPending[LIndex] := Default(TChordVoice);
  end;
  FTiming.TempoMicrosecondsPerQuarter := FOptions.TempoMicrosecondsPerQuarter;
  FTiming.MeterNumerator := FOptions.MeterNumerator;
  FTiming.MeterDenominatorPower := FOptions.MeterDenominatorPower;
end;

function TChordMidiEvents.GetNeedsInput: Boolean;
begin
  Result := (FPhase = 4) and not FInputEnded and not FCancelled;
end;

function TChordMidiEvents.GetFinished: Boolean;
begin
  Result := (FPhase = 4) and FInputEnded and not FCancelled;
end;

procedure TChordMidiEvents.AdvancePhase;
begin
  Inc(FPhase);
  FVoice := 0;
  FTone := 0;
  if FPhase = 4 then
  begin
    if not FInputEnded then
    begin
      FActive := FPending;
    end
    else
    begin
      FActive := nil;
    end;
    FPending := nil;
  end;
end;

procedure TChordMidiEvents.AdmitFrame(
  const AFrame: TChordFrame; const ALength: TMidiStreamCount;
  const ATiming: TChordMidiTiming);
var
  LIndex: Integer;
  LPeer: Integer;
  LCopy: TChordFrame;
begin
  if not NeedsInput then
  begin
    MidiError('drain the current frame before admission');
  end;
  CheckInteger(ALength, 1, MaximumMidiStreamCount, 'frame length');
  if ALength > MaximumMidiStreamCount - FTick then
  begin
    MidiError('end tick exceeds the portable exact integer envelope');
  end;
  ValidateTiming(ATiming);
  if Length(AFrame) <> Length(FOptions.Channels) then
  begin
    MidiError('frame voice count differs from the channel mapping');
  end;
  for LIndex := 0 to High(AFrame) do
  begin
    CheckInteger(Ord(AFrame[LIndex].Action), Ord(caRest), Ord(caHold), 'voice action');
    if AFrame[LIndex].Action = caRest then
    begin
      if Length(AFrame[LIndex].Tones) <> 0 then
      begin
        MidiError('rest contains tones');
      end;
    end
    else
    begin
      if (Length(AFrame[LIndex].Tones) < 1) or
        (Length(AFrame[LIndex].Tones) > 128) then
      begin
        MidiError('sounding voice must contain 1..128 unique MIDI pitches');
      end;
      for LPeer := 0 to High(AFrame[LIndex].Tones) do
      begin
        CheckInteger(AFrame[LIndex].Tones[LPeer].Pitch, 0, 127, 'pitch');
        CheckInteger(AFrame[LIndex].Tones[LPeer].Velocity, 1, 127, 'velocity');
        if (LPeer > 0) and (AFrame[LIndex].Tones[LPeer - 1].Pitch >=
          AFrame[LIndex].Tones[LPeer].Pitch) then
        begin
          MidiError('tone pitches must be strictly increasing');
        end;
      end;
      if AFrame[LIndex].Action = caHold then
      begin
        if Length(AFrame[LIndex].Tones) <> Length(FActive[LIndex].Tones) then
        begin
          MidiError('hold has no identical active predecessor');
        end;
        for LPeer := 0 to High(AFrame[LIndex].Tones) do
        begin
          if (AFrame[LIndex].Tones[LPeer].Pitch <> FActive[LIndex].Tones[LPeer].Pitch) or
            (AFrame[LIndex].Tones[LPeer].Velocity <> FActive[LIndex].Tones[LPeer].Velocity) then
          begin
            MidiError('hold differs from its active pitches or velocities');
          end;
        end;
      end;
    end;
  end;
  LCopy := CloneFrame(AFrame);
  FPending := LCopy;
  FTiming := ATiming;
  FEventTick := FTick;
  FTick := FTick + ALength;
  FPhase := 0;
  FVoice := 0;
  FTone := 0;
end;

function TChordMidiEvents.NextEvent(out ATick: TMidiStreamCount;
  out AEvent: TMidiEvent): Boolean;
var
  LTempo: Integer;
  LPitch: Integer;
  LVelocity: Integer;
begin
  Result := False;
  AEvent := Default(TMidiEvent);
  ATick := FEventTick;
  if FCancelled then
  begin
    Exit;
  end;
  while FPhase < 4 do
  begin
    case FPhase of
      0:
      begin
        LTempo := FTiming.TempoMicrosecondsPerQuarter;
        if LTempo <> 0 then
        begin
          AEvent := MakeMidiMetaEvent(0, $51,
            [Byte(LTempo shr 16), Byte((LTempo shr 8) and 255), Byte(LTempo and 255)]);
        end;
        AdvancePhase;
        if LTempo <> 0 then
        begin
          Exit(True);
        end;
      end;
      1:
      begin
        if FTiming.MeterNumerator <> 0 then
        begin
          AEvent := MakeMidiMetaEvent(0, $58,
            [Byte(FTiming.MeterNumerator), Byte(FTiming.MeterDenominatorPower), 24, 8]);
        end;
        AdvancePhase;
        if FTiming.MeterNumerator <> 0 then
        begin
          Exit(True);
        end;
      end;
      2:
      begin
        while FVoice < Length(FActive) do
        begin
          if FInputEnded or (FPending[FVoice].Action <> caHold) then
          begin
            if FTone < Length(FActive[FVoice].Tones) then
            begin
              LPitch := FActive[FVoice].Tones[FTone].Pitch;
              AEvent := MakeMidiChannelEvent(0, Byte($80 + FOptions.Channels[FVoice]),
                [Byte(LPitch), 0]);
              Inc(FTone);
              Exit(True);
            end;
          end;
          Inc(FVoice);
          FTone := 0;
        end;
        AdvancePhase;
      end;
      3:
      begin
        if not FInputEnded then
        begin
          while FVoice < Length(FPending) do
          begin
            if FPending[FVoice].Action = caAttack then
            begin
              if FTone < Length(FPending[FVoice].Tones) then
              begin
                LPitch := FPending[FVoice].Tones[FTone].Pitch;
                LVelocity := FPending[FVoice].Tones[FTone].Velocity;
                AEvent := MakeMidiChannelEvent(0, Byte($90 + FOptions.Channels[FVoice]),
                  [Byte(LPitch), Byte(LVelocity)]);
                Inc(FTone);
                Exit(True);
              end;
            end;
            Inc(FVoice);
            FTone := 0;
          end;
        end;
        AdvancePhase;
      end;
    end;
  end;
end;

procedure TChordMidiEvents.EndInput;
begin
  if FCancelled then
  begin
    MidiError('stream was cancelled');
  end;
  if FInputEnded then
  begin
    Exit;
  end;
  if not NeedsInput then
  begin
    MidiError('drain the current frame before ending input');
  end;
  FInputEnded := True;
  FEventTick := FTick;
  FPhase := 2;
  FVoice := 0;
  FTone := 0;
end;

procedure TChordMidiEvents.Cancel;
begin
  FCancelled := True;
  FActive := nil;
  FPending := nil;
end;

class function TChordMidiPlan.NewPlan(
  const AOptions: TChordMidiOptions; const ATrack: TMidiTrackPlan): TChordMidiPlan;
begin
  Result := TChordMidiPlan.Create;
  try
    Result.FOptions := CloneOptions(AOptions);
    Result.FTrack := ATrack;
  except
    Result.Free;
    raise;
  end;
end;

procedure TChordMidiPlan.RequirePlan;
begin
  if FTrack = nil then
  begin
    MidiError('plan must come from a completed chord counter');
  end;
end;

destructor TChordMidiPlan.Destroy;
begin
  FTrack.Free;
  inherited Destroy;
end;

function TChordMidiPlan.CopyOptions: TChordMidiOptions;
begin
  RequirePlan;
  Result := CloneOptions(FOptions);
end;

function TChordMidiPlan.GetEndTick: TMidiStreamCount;
begin
  RequirePlan;
  Result := FTrack.EndTick;
end;

function TChordMidiPlan.GetByteCount: TMidiStreamCount;
begin
  RequirePlan;
  Result := FTrack.ByteCount;
end;

function TChordMidiPlan.GetEventCount: TMidiStreamCount;
begin
  RequirePlan;
  Result := FTrack.EventCount;
end;

function TChordMidiPlan.GetBridgeCount: TMidiStreamCount;
begin
  RequirePlan;
  Result := FTrack.BridgeCount;
end;

function TChordMidiPlan.GetSignature: Cardinal;
begin
  RequirePlan;
  Result := FTrack.Signature;
end;

constructor TChordMidiCounter.Create(
  const AOptions: TChordMidiOptions);
begin
  inherited Create;
  ValidateOptions(AOptions);
  FOptions := CloneOptions(AOptions);
  FCounter := TMidiTrackCounter.Create;
  FEvents := TChordMidiEvents.Create(FOptions);
  Drain;
end;

destructor TChordMidiCounter.Destroy;
begin
  FEvents.Free;
  FCounter.Free;
  inherited Destroy;
end;

procedure TChordMidiCounter.Drain;
var
  LTick: TMidiStreamCount;
  LEvent: TMidiEvent;
begin
  try
    while FEvents.NextEvent(LTick, LEvent) do
    begin
      FCounter.AppendEvent(LTick, LEvent);
    end;
  except
    FFailed := True;
    raise;
  end;
end;

procedure TChordMidiCounter.AdmitFrame(
  const AFrame: TChordFrame; const ALength: TMidiStreamCount);
begin
  AdmitFrame(AFrame, ALength, Default(TChordMidiTiming));
end;

procedure TChordMidiCounter.AdmitFrame(
  const AFrame: TChordFrame; const ALength: TMidiStreamCount;
  const ATiming: TChordMidiTiming);
begin
  if FFailed then
  begin
    MidiError('counter failed');
  end;
  FEvents.AdmitFrame(AFrame, ALength, ATiming);
  Drain;
end;

function TChordMidiCounter.Finish: TChordMidiPlan;
var
  LTrack: TMidiTrackPlan;
begin
  if FFailed then
  begin
    MidiError('counter failed');
  end;
  FEvents.EndInput;
  Drain;
  LTrack := nil;
  try
    try
      LTrack := FCounter.Finish(FEvents.TickCount);
      Result := TChordMidiPlan.NewPlan(FOptions, LTrack);
      LTrack := nil;
    except
      FFailed := True;
      raise;
    end;
  finally
    LTrack.Free;
  end;
end;

function TChordMidiCounter.GetTickCount: TMidiStreamCount;
begin
  Result := FEvents.TickCount;
end;

function TChordMidiCounter.GetFinished: Boolean;
begin
  Result := FCounter.Finished and not FFailed;
end;

constructor TChordMidiStream.Create(const APlan: TChordMidiPlan);
begin
  inherited Create;
  if APlan = nil then
  begin
    MidiError('plan is required');
  end;
  APlan.RequirePlan;
  FEvents := TChordMidiEvents.Create(APlan.FOptions);
  FStream := TMidiFileStream.Create(APlan.FOptions.TicksPerQuarter, APlan.FTrack);
end;

destructor TChordMidiStream.Destroy;
begin
  FStream.Free;
  FEvents.Free;
  inherited Destroy;
end;

function TChordMidiStream.GetNeedsInput: Boolean;
begin
  Result := not Failed and not FCancelled and FStream.NeedsInput and FEvents.NeedsInput;
end;

function TChordMidiStream.GetFinished: Boolean;
begin
  Result := not Failed and not FCancelled and FStream.Finished;
end;

function TChordMidiStream.GetFailed: Boolean;
begin
  Result := FFailed or FStream.Failed;
end;

function TChordMidiStream.GetInputEnded: Boolean;
begin
  Result := FEvents.InputEnded;
end;

function TChordMidiStream.GetTickCount: TMidiStreamCount;
begin
  Result := FEvents.TickCount;
end;

function TChordMidiStream.GetEmittedBytes: TMidiStreamCount;
begin
  Result := FEmittedBytes;
end;

procedure TChordMidiStream.AdmitFrame(
  const AFrame: TChordFrame; const ALength: TMidiStreamCount);
begin
  AdmitFrame(AFrame, ALength, Default(TChordMidiTiming));
end;

procedure TChordMidiStream.AdmitFrame(
  const AFrame: TChordFrame; const ALength: TMidiStreamCount;
  const ATiming: TChordMidiTiming);
begin
  if not NeedsInput then
  begin
    MidiError('stream is not ready for a frame');
  end;
  FEvents.AdmitFrame(AFrame, ALength, ATiming);
end;

function TChordMidiStream.ReadBytes(const AMaxBytes: Integer;
  out ABytes: TMidiBytes): Boolean;
var
  LTick: TMidiStreamCount;
  LEvent: TMidiEvent;
  LBlock: TMidiBytes;
  LLimit: Integer;
  LCount: Integer;
  LIndex: Integer;
begin
  ABytes := nil;
  CheckInteger(AMaxBytes, 1, High(Integer), 'read byte count');
  if Failed then
  begin
    MidiError('stream failed; discard the output prefix');
  end;
  if FCancelled then
  begin
    Exit(False);
  end;
  LLimit := AMaxBytes;
  if LLimit > MidiStreamBlockBytes then
  begin
    LLimit := MidiStreamBlockBytes;
  end;
  LCount := 0;
  try
    while LCount < LLimit do
    begin
      if FStream.ReadBytes(LLimit - LCount, LBlock) then
      begin
        if LCount = 0 then
        begin
          SetLength(ABytes, LLimit);
        end;
        for LIndex := 0 to High(LBlock) do
        begin
          ABytes[LCount + LIndex] := LBlock[LIndex];
        end;
        Inc(LCount, Length(LBlock));
        Continue;
      end;
      if FStream.Finished then
      begin
        Break;
      end;
      if FEvents.NextEvent(LTick, LEvent) then
      begin
        FStream.AdmitEvent(LTick, LEvent);
      end
      else if FEvents.Finished then
      begin
        FStream.Finish(FEvents.TickCount);
      end
      else
      begin
        Break;
      end;
    end;
    SetLength(ABytes, LCount);
    Result := LCount <> 0;
    if Result then
    begin
      Inc(FEmittedBytes, LCount);
    end;
  except
    FFailed := True;
    ABytes := nil;
    raise;
  end;
end;

procedure TChordMidiStream.EndInput;
begin
  if Failed or FCancelled then
  begin
    MidiError('stream failed or was cancelled');
  end;
  if FEvents.InputEnded then
  begin
    Exit;
  end;
  if not NeedsInput then
  begin
    MidiError('drain the current frame before ending input');
  end;
  FEvents.EndInput;
end;

procedure TChordMidiStream.Cancel;
begin
  if Finished then
  begin
    Exit;
  end;
  FCancelled := True;
  FEvents.Cancel;
  FStream.Cancel;
end;

end.
