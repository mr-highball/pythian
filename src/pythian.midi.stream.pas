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
unit pythian.midi.stream;

{$mode delphi}
{$H+}

interface

uses
  pythian.midi.smf;

type
  TMidiStreamCount = Int64;

const
  MidiStreamVersion = 1;
  MidiStreamBlockBytes = 4096;
  MidiStreamHeaderBytes = 22;
  MaximumMidiStreamCount: TMidiStreamCount = 9007199254740991;
  MaximumMidiTrackBytes: TMidiStreamCount = 4294967295;

type
  EMidiStream = class(EMidiSmf);

  { Immutable caller-owned track summary, made only by a completed counter.
    ByteCount is MTrk data, excluding the 22-byte format-0 file/chunk header.
    EventCount includes the final EOT but excludes generated delay bridges;
    BridgeCount counts those synthetic empty text events separately.

    Signature is a versioned FNV32 logical-event fingerprint, NOT a
    cryptographic commitment or proof of exact replay. Applications requiring
    stronger authentication must supply their own separately trusted proof. }
  TMidiTrackPlan = class
  private
    FEndTick: TMidiStreamCount;
    FByteCount: TMidiStreamCount;
    FEventCount: TMidiStreamCount;
    FBridgeCount: TMidiStreamCount;
    FSignature: Cardinal;
    FValid: Boolean;
    class function NewPlan(const AEndTick, AByteCount, AEventCount,
      ABridgeCount: TMidiStreamCount; const ASignature: Cardinal): TMidiTrackPlan; static;
  public
    property EndTick: TMidiStreamCount read FEndTick;
    property ByteCount: TMidiStreamCount read FByteCount;
    property EventCount: TMidiStreamCount read FEventCount;
    property BridgeCount: TMidiStreamCount read FBridgeCount;
    property Signature: Cardinal read FSignature;
  end;

  { One pass over nondecreasing absolute ticks. Incoming DeltaTicks must be
    exactly zero; the caller cannot submit EOT. Channel/meta/SysEx validation
    follows the existing canonical SMF adapter without its whole-file memory
    policy caps. Payloads still fit the SMF four-byte VLQ and Integer indexing.
    The counter retains no input array or timeline and does not clone payloads.

    Long gaps are represented by FF 01 00 empty text meta events, each at the
    maximum delta. Bridge count is calculated in O(1), without expanding them:
    for positive gap, bridges=(gap-1) div MAX_VLQ, leaving delta 1..MAX_VLQ.
    Signature hashes logical events rather than iterating generated bridges.
    Payload hashing remains linear in supplied payload bytes.

    Finish owns EOT and freezes the counter. Calling Finish again with the
    same end returns a fresh detached plan; further events/different end reject.
    All validation, overflow and allocation failures preserve counter state. }
  TMidiTrackCounter = class
  private
    FLastTick: TMidiStreamCount;
    FByteCount: TMidiStreamCount;
    FEventCount: TMidiStreamCount;
    FBridgeCount: TMidiStreamCount;
    FSignature: Cardinal;
    FFinished: Boolean;
  public
    constructor Create;
    procedure AppendEvent(const AAbsoluteTick: TMidiStreamCount;
      const AEvent: TMidiEvent);
    function Finish(const AEndTick: TMidiStreamCount): TMidiTrackPlan;
    property LastTick: TMidiStreamCount read FLastTick;
    property ByteCount: TMidiStreamCount read FByteCount;
    property EventCount: TMidiStreamCount read FEventCount;
    property BridgeCount: TMidiStreamCount read FBridgeCount;
    property Finished: Boolean read FFinished;
  end;

  { Format-0, one-track, forward-only SMF with explicit status on every event.
    Create copies plan scalars; the caller may free its plan immediately.
    Drain the initially pending 22-byte header, then AdmitEvent only when
    NeedsInput. Each admission validates first and clones only that event.
    ReadBytes accepts any positive Integer maximum, returns at most 4096
    caller-owned bytes, and returns nil on False. Long payloads and synthetic
    delay bridges are serialized incrementally, never assembled as a track.

    Finish must wait for NeedsInput. It validates the complete replay, including
    EOT, before queuing final bytes. Replay mismatches poison Failed, as do
    unexpected processing errors. Invalid arguments/state or admission staging
    allocation failures are retryable. A replay exceeding a plan budget can
    fail early; any already-returned file prefix must be discarded on failure.

    Cancel is terminal and discards pending bytes, without emitting EOT. It
    cannot turn a failed stream into success. Finish is idempotent after its
    successful admission when the same end tick is supplied. Finished becomes
    True only after every final byte is read. Destruction neither drains nor
    publishes, closes, or calls any host. Sequential, non-reentrant by design. }
  TMidiFileStream = class
  private
    FCounter: TMidiTrackCounter;
    FPlanEndTick: TMidiStreamCount;
    FPlanByteCount: TMidiStreamCount;
    FPlanEventCount: TMidiStreamCount;
    FPlanBridgeCount: TMidiStreamCount;
    FPlanSignature: Cardinal;
    FEmittedBytes: TMidiStreamCount;
    FPrefix: array[0..21] of Byte;
    FPrefixCount: Integer;
    FPrefixPosition: Integer;
    FDataPosition: Integer;
    FEvent: TMidiEvent;
    FRemainingBridges: TMidiStreamCount;
    FEventDelta: Cardinal;
    FQueueKind: Integer;
    FEventPrefixReady: Boolean;
    FInputEnded: Boolean;
    FFinished: Boolean;
    FFailed: Boolean;
    FCancelled: Boolean;
    function GetNeedsInput: Boolean;
    procedure RequireInput;
    procedure AddPrefixByte(const AByte: Byte);
    procedure AddPrefixVLQ(AValue: Cardinal);
    procedure AddPrefixBigEndian(AValue: TMidiStreamCount; const ACount: Integer);
    procedure PrepareBridgePrefix;
    procedure PrepareEventPrefix;
    procedure CompleteQueue;
    procedure CheckReplayBudget(const ATick, ABytes, AEvents,
      ABridges: TMidiStreamCount);
  public
    constructor Create(const ATicksPerQuarter: Integer; const APlan: TMidiTrackPlan);
    destructor Destroy; override;
    procedure AdmitEvent(const AAbsoluteTick: TMidiStreamCount;
      const AEvent: TMidiEvent);
    function ReadBytes(const AMaxBytes: Integer; out ABytes: TMidiBytes): Boolean;
    procedure Finish(const AEndTick: TMidiStreamCount);
    procedure Cancel;
    property NeedsInput: Boolean read GetNeedsInput;
    property InputEnded: Boolean read FInputEnded;
    property Finished: Boolean read FFinished;
    property Failed: Boolean read FFailed;
    property Cancelled: Boolean read FCancelled;
    property EmittedBytes: TMidiStreamCount read FEmittedBytes;
  end;

implementation

uses
  SysUtils;

const
  QueueNone = 0;
  QueueHeader = 1;
  QueueEvent = 2;

type
  TPreparedEvent = record
    Tick: TMidiStreamCount;
    ByteCount: TMidiStreamCount;
    EventCount: TMidiStreamCount;
    BridgeCount: TMidiStreamCount;
    AddedBridges: TMidiStreamCount;
    Delta: Cardinal;
    Signature: Cardinal;
  end;

procedure StreamError(const AMessage: String);
begin
  raise EMidiStream.Create('cannot stream Standard MIDI File: ' + AMessage);
end;

procedure CheckCount(const AValue: TMidiStreamCount; const AName: String);
begin
  if (AValue < 0) or (AValue > MaximumMidiStreamCount) then
  begin
    StreamError(AName + ' exceeds the nonnegative exact integer envelope');
  end;
end;

procedure CheckInteger(const AValue: TMidiStreamCount;
  const AMinimum, AMaximum: TMidiStreamCount; const AName: String);
begin
  CheckCount(AValue, AName);
  if (AValue < AMinimum) or (AValue > AMaximum) then
  begin
    StreamError(AName + ' is outside its supported integer range');
  end;
end;

procedure HashByte(var AHash: Cardinal; const AByte: Byte);
{$PUSH}{$Q-}
var
  LValue: Cardinal;
begin
  LValue := AHash xor Cardinal(AByte);
  AHash := (LValue + (LValue shl 1) + (LValue shl 4) +
    (LValue shl 7) + (LValue shl 8) + (LValue shl 24)) and Cardinal($FFFFFFFF);
end;
{$POP}

procedure HashCount(var AHash: Cardinal; AValue: TMidiStreamCount);
var
  LIndex: Integer;
begin
  for LIndex := 0 to 7 do
  begin
    HashByte(AHash, Byte(AValue mod 256));
    AValue := AValue div 256;
  end;
end;

function VLQSize(AValue: Cardinal): Integer;
begin
  Result := 1;
  while AValue >= 128 do
  begin
    AValue := AValue shr 7;
    Inc(Result);
  end;
end;

function ValidateEvent(const AEvent: TMidiEvent; const AOwnedEnd: Boolean): Integer;
var
  LIndex: Integer;
  LChannelLength: Integer;
begin
  CheckInteger(AEvent.DeltaTicks, 0, 0, 'incoming delta ticks');
  CheckInteger(AEvent.Status, 0, 255, 'event status');
  CheckInteger(AEvent.MetaType, 0, 255, 'meta type');
  CheckInteger(Length(AEvent.Data), 0, MaximumMidiVariableLength,
    'payload length');
  Result := Length(AEvent.Data);
  for LIndex := 0 to Result - 1 do
  begin
    CheckInteger(AEvent.Data[LIndex], 0, 255, 'payload byte');
  end;
  if (AEvent.Status >= $80) and (AEvent.Status <= $EF) then
  begin
    if AEvent.MetaType <> 0 then
    begin
      StreamError('channel event has a meta type');
    end;
    if (AEvent.Status and $F0 = $C0) or (AEvent.Status and $F0 = $D0) then
    begin
      LChannelLength := 1;
    end
    else
    begin
      LChannelLength := 2;
    end;
    if Result <> LChannelLength then
    begin
      StreamError('channel event has the wrong payload length');
    end;
    for LIndex := 0 to Result - 1 do
    begin
      if AEvent.Data[LIndex] >= $80 then
      begin
        StreamError('channel data must be seven-bit');
      end;
    end;
    Exit;
  end;
  case AEvent.Status of
    $F0, $F7:
      if AEvent.MetaType <> 0 then
      begin
        StreamError('SysEx event has a meta type');
      end;
    $FF:
      begin
        if AEvent.MetaType >= $80 then
        begin
          StreamError('meta type must be seven-bit');
        end;
        case AEvent.MetaType of
          $2F:
            if not AOwnedEnd or (Result <> 0) then
            begin
              StreamError('Finish owns end-of-track');
            end;
          $51:
            begin
              if Result <> 3 then
              begin
                StreamError('tempo payload must contain three bytes');
              end;
              if (AEvent.Data[0] = 0) and (AEvent.Data[1] = 0) and
                (AEvent.Data[2] = 0) then
              begin
                StreamError('tempo cannot be zero');
              end;
            end;
          $58:
            if Result <> 4 then
            begin
              StreamError('time signature payload must contain four bytes');
            end;
        end;
      end;
  else
    StreamError('unsupported event status');
  end;
end;

function PrepareEvent(const ACounter: TMidiTrackCounter;
  const ATick: TMidiStreamCount; const AEvent: TMidiEvent;
  const AOwnedEnd: Boolean): TPreparedEvent;
var
  LGap: TMidiStreamCount;
  LSize: TMidiStreamCount;
  LLength: Integer;
  LIndex: Integer;
begin
  CheckCount(ATick, 'absolute tick');
  if ATick < ACounter.FLastTick then
  begin
    StreamError('event ticks must not decrease');
  end;
  LLength := ValidateEvent(AEvent, AOwnedEnd);
  LGap := ATick - ACounter.FLastTick;
  Result.AddedBridges := 0;
  if LGap > 0 then
  begin
    Result.AddedBridges := (LGap - 1) div MaximumMidiVariableLength;
  end;
  Result.Delta := Cardinal(LGap - Result.AddedBridges * MaximumMidiVariableLength);
  LSize := Result.AddedBridges * 7 + VLQSize(Result.Delta) + 1 + LLength;
  if AEvent.Status = $FF then
  begin
    Inc(LSize);
  end;
  if AEvent.Status >= $F0 then
  begin
    Inc(LSize, VLQSize(Cardinal(LLength)));
  end;
  if LSize > MaximumMidiTrackBytes - ACounter.FByteCount then
  begin
    StreamError('MTrk byte count exceeds its unsigned 32-bit length');
  end;
  if ACounter.FEventCount = MaximumMidiStreamCount then
  begin
    StreamError('logical event count exceeds exact integer range');
  end;
  if Result.AddedBridges > MaximumMidiStreamCount - ACounter.FBridgeCount then
  begin
    StreamError('bridge count exceeds exact integer range');
  end;
  Result.Tick := ATick;
  Result.ByteCount := ACounter.FByteCount + LSize;
  Result.EventCount := ACounter.FEventCount + 1;
  Result.BridgeCount := ACounter.FBridgeCount + Result.AddedBridges;
  Result.Signature := ACounter.FSignature;
  HashCount(Result.Signature, ATick);
  HashByte(Result.Signature, AEvent.Status);
  HashByte(Result.Signature, AEvent.MetaType);
  HashCount(Result.Signature, LLength);
  for LIndex := 0 to LLength - 1 do
  begin
    HashByte(Result.Signature, AEvent.Data[LIndex]);
  end;
  if AOwnedEnd then
  begin
    HashCount(Result.Signature, Result.ByteCount);
    HashCount(Result.Signature, Result.EventCount);
    HashCount(Result.Signature, Result.BridgeCount);
  end;
end;

procedure CommitPrepared(const ACounter: TMidiTrackCounter; const AValue: TPreparedEvent);
begin
  ACounter.FLastTick := AValue.Tick;
  ACounter.FByteCount := AValue.ByteCount;
  ACounter.FEventCount := AValue.EventCount;
  ACounter.FBridgeCount := AValue.BridgeCount;
  ACounter.FSignature := AValue.Signature;
end;

function EndEvent: TMidiEvent;
begin
  Result := Default(TMidiEvent);
  Result.Status := $FF;
  Result.MetaType := $2F;
end;

class function TMidiTrackPlan.NewPlan(const AEndTick, AByteCount, AEventCount,
  ABridgeCount: TMidiStreamCount; const ASignature: Cardinal): TMidiTrackPlan;
begin
  Result := TMidiTrackPlan.Create;
  Result.FEndTick := AEndTick;
  Result.FByteCount := AByteCount;
  Result.FEventCount := AEventCount;
  Result.FBridgeCount := ABridgeCount;
  Result.FSignature := ASignature;
  Result.FValid := True;
end;

constructor TMidiTrackCounter.Create;
begin
  inherited Create;
  FSignature := Cardinal(2166136261);
  HashCount(FSignature, MidiStreamVersion);
end;

procedure TMidiTrackCounter.AppendEvent(const AAbsoluteTick: TMidiStreamCount;
  const AEvent: TMidiEvent);
var
  LPrepared: TPreparedEvent;
begin
  if FFinished then
  begin
    StreamError('counter is already finished');
  end;
  LPrepared := PrepareEvent(Self, AAbsoluteTick, AEvent, False);
  CommitPrepared(Self, LPrepared);
end;

function TMidiTrackCounter.Finish(const AEndTick: TMidiStreamCount): TMidiTrackPlan;
var
  LPrepared: TPreparedEvent;
begin
  Result := nil;
  CheckCount(AEndTick, 'end tick');
  if FFinished then
  begin
    if AEndTick <> FLastTick then
    begin
      StreamError('finished counter end tick cannot change');
    end;
    Exit(TMidiTrackPlan.NewPlan(FLastTick, FByteCount, FEventCount, FBridgeCount, FSignature));
  end;
  LPrepared := PrepareEvent(Self, AEndTick, EndEvent, True);
  Result := TMidiTrackPlan.NewPlan(LPrepared.Tick, LPrepared.ByteCount,
    LPrepared.EventCount, LPrepared.BridgeCount, LPrepared.Signature);
  CommitPrepared(Self, LPrepared);
  FFinished := True;
end;

constructor TMidiFileStream.Create(const ATicksPerQuarter: Integer;
  const APlan: TMidiTrackPlan);
begin
  inherited Create;
  CheckInteger(ATicksPerQuarter, 1, $7FFF, 'ticks per quarter');
  if (APlan = nil) or not APlan.FValid then
  begin
    StreamError('track plan must come from a completed counter');
  end;
  FPlanEndTick := APlan.EndTick;
  FPlanByteCount := APlan.ByteCount;
  FPlanEventCount := APlan.EventCount;
  FPlanBridgeCount := APlan.BridgeCount;
  FPlanSignature := APlan.Signature;
  FCounter := TMidiTrackCounter.Create;
  AddPrefixByte(Ord('M'));
  AddPrefixByte(Ord('T'));
  AddPrefixByte(Ord('h'));
  AddPrefixByte(Ord('d'));
  AddPrefixBigEndian(6, 4);
  AddPrefixBigEndian(0, 2);
  AddPrefixBigEndian(1, 2);
  AddPrefixBigEndian(ATicksPerQuarter, 2);
  AddPrefixByte(Ord('M'));
  AddPrefixByte(Ord('T'));
  AddPrefixByte(Ord('r'));
  AddPrefixByte(Ord('k'));
  AddPrefixBigEndian(FPlanByteCount, 4);
  FQueueKind := QueueHeader;
end;

destructor TMidiFileStream.Destroy;
begin
  FCounter.Free;
  inherited Destroy;
end;

function TMidiFileStream.GetNeedsInput: Boolean;
begin
  Result := not (FInputEnded or FFailed or FCancelled) and (FQueueKind = QueueNone);
end;

procedure TMidiFileStream.RequireInput;
begin
  if FFailed then
  begin
    StreamError('a previous replay or processing operation failed');
  end;
  if FCancelled then
  begin
    StreamError('stream is cancelled');
  end;
  if not NeedsInput then
  begin
    StreamError('drain pending bytes before admitting input');
  end;
end;

procedure TMidiFileStream.AddPrefixByte(const AByte: Byte);
begin
  FPrefix[FPrefixCount] := AByte;
  Inc(FPrefixCount);
end;

procedure TMidiFileStream.AddPrefixVLQ(AValue: Cardinal);
var
  LBytes: array[0..3] of Byte;
  LCount: Integer;
  LIndex: Integer;
begin
  LCount := 1;
  LBytes[0] := Byte(AValue and $7F);
  while AValue >= 128 do
  begin
    AValue := AValue shr 7;
    LBytes[LCount] := Byte(AValue and $7F) or $80;
    Inc(LCount);
  end;
  for LIndex := LCount - 1 downto 0 do
  begin
    AddPrefixByte(LBytes[LIndex]);
  end;
end;

procedure TMidiFileStream.AddPrefixBigEndian(AValue: TMidiStreamCount;
  const ACount: Integer);
var
  LIndex: Integer;
begin
  for LIndex := ACount - 1 downto 0 do
  begin
    FPrefix[FPrefixCount + LIndex] := Byte(AValue mod 256);
    AValue := AValue div 256;
  end;
  Inc(FPrefixCount, ACount);
end;

procedure TMidiFileStream.PrepareBridgePrefix;
begin
  FPrefixCount := 0;
  FPrefixPosition := 0;
  AddPrefixVLQ(MaximumMidiVariableLength);
  AddPrefixByte($FF);
  AddPrefixByte($01);
  AddPrefixByte(0);
  Dec(FRemainingBridges);
end;

procedure TMidiFileStream.PrepareEventPrefix;
begin
  FPrefixCount := 0;
  FPrefixPosition := 0;
  AddPrefixVLQ(FEventDelta);
  AddPrefixByte(FEvent.Status);
  if FEvent.Status = $FF then
  begin
    AddPrefixByte(FEvent.MetaType);
  end;
  if FEvent.Status >= $F0 then
  begin
    AddPrefixVLQ(Cardinal(Length(FEvent.Data)));
  end;
  FEventPrefixReady := True;
end;

procedure TMidiFileStream.CompleteQueue;
begin
  if FPrefixPosition < FPrefixCount then
  begin
    Exit;
  end;
  if FQueueKind = QueueHeader then
  begin
    FQueueKind := QueueNone;
  end
  else if (FQueueKind = QueueEvent) and (FRemainingBridges = 0) and
    FEventPrefixReady and (FDataPosition = Length(FEvent.Data)) then
  begin
    FEvent.Data := nil;
    FQueueKind := QueueNone;
    if FInputEnded then
    begin
      if FEmittedBytes <> MidiStreamHeaderBytes + FPlanByteCount then
      begin
        StreamError('serialized byte count differs from the track plan');
      end;
      FFinished := True;
    end;
  end;
end;

procedure TMidiFileStream.CheckReplayBudget(const ATick, ABytes, AEvents,
  ABridges: TMidiStreamCount);
begin
  if (ATick > FPlanEndTick) or (ABytes > FPlanByteCount - 4) or
    (AEvents >= FPlanEventCount) or (ABridges > FPlanBridgeCount) then
  begin
    FFailed := True;
    StreamError('event replay exceeds the declared track plan');
  end;
end;

procedure TMidiFileStream.AdmitEvent(const AAbsoluteTick: TMidiStreamCount;
  const AEvent: TMidiEvent);
var
  LPrepared: TPreparedEvent;
  LCopy: TMidiEvent;
  LIndex: Integer;
begin
  RequireInput;
  LPrepared := PrepareEvent(FCounter, AAbsoluteTick, AEvent, False);
  CheckReplayBudget(LPrepared.Tick, LPrepared.ByteCount, LPrepared.EventCount,
    LPrepared.BridgeCount);
  LCopy := Default(TMidiEvent);
  LCopy.Status := AEvent.Status;
  LCopy.MetaType := AEvent.MetaType;
  SetLength(LCopy.Data, Length(AEvent.Data));
  for LIndex := 0 to High(LCopy.Data) do
  begin
    LCopy.Data[LIndex] := AEvent.Data[LIndex];
  end;
  FEvent := LCopy;
  FRemainingBridges := LPrepared.AddedBridges;
  FEventDelta := LPrepared.Delta;
  FPrefixCount := 0;
  FPrefixPosition := 0;
  FDataPosition := 0;
  FEventPrefixReady := False;
  FQueueKind := QueueEvent;
  CommitPrepared(FCounter, LPrepared);
end;

function TMidiFileStream.ReadBytes(const AMaxBytes: Integer;
  out ABytes: TMidiBytes): Boolean;
var
  LLimit: Integer;
  LCount: Integer;
  LAvailable: Integer;
  LIndex: Integer;
begin
  ABytes := nil;
  CheckInteger(AMaxBytes, 1, High(Integer), 'maximum output bytes');
  if FFailed then
  begin
    StreamError('a previous replay or processing operation failed');
  end;
  if FCancelled or FFinished or (FQueueKind = QueueNone) then
  begin
    Exit(False);
  end;
  LLimit := AMaxBytes;
  if LLimit > MidiStreamBlockBytes then
  begin
    LLimit := MidiStreamBlockBytes;
  end;
  SetLength(ABytes, LLimit);
  LCount := 0;
  try
    while (LCount < LLimit) and (FQueueKind <> QueueNone) do
    begin
      if FPrefixPosition < FPrefixCount then
      begin
        LAvailable := FPrefixCount - FPrefixPosition;
        if LAvailable > LLimit - LCount then
        begin
          LAvailable := LLimit - LCount;
        end;
        for LIndex := 0 to LAvailable - 1 do
        begin
          ABytes[LCount + LIndex] := FPrefix[FPrefixPosition + LIndex];
        end;
        Inc(FPrefixPosition, LAvailable);
        Inc(LCount, LAvailable);
        Inc(FEmittedBytes, LAvailable);
      end
      else if FRemainingBridges > 0 then
      begin
        PrepareBridgePrefix;
      end
      else if (FQueueKind = QueueEvent) and not FEventPrefixReady then
      begin
        PrepareEventPrefix;
      end
      else if FDataPosition < Length(FEvent.Data) then
      begin
        LAvailable := Length(FEvent.Data) - FDataPosition;
        if LAvailable > LLimit - LCount then
        begin
          LAvailable := LLimit - LCount;
        end;
        for LIndex := 0 to LAvailable - 1 do
        begin
          ABytes[LCount + LIndex] := FEvent.Data[FDataPosition + LIndex];
        end;
        Inc(FDataPosition, LAvailable);
        Inc(LCount, LAvailable);
        Inc(FEmittedBytes, LAvailable);
      end;
      CompleteQueue;
    end;
    SetLength(ABytes, LCount);
    Result := LCount <> 0;
  except
    ABytes := nil;
    FFailed := True;
    raise;
  end;
end;

procedure TMidiFileStream.Finish(const AEndTick: TMidiStreamCount);
var
  LPrepared: TPreparedEvent;
begin
  CheckCount(AEndTick, 'end tick');
  if FFailed then
  begin
    StreamError('a previous replay or processing operation failed');
  end;
  if FCancelled then
  begin
    StreamError('stream is cancelled');
  end;
  if FInputEnded then
  begin
    if AEndTick <> FPlanEndTick then
    begin
      StreamError('finished stream end tick cannot change');
    end;
    Exit;
  end;
  RequireInput;
  LPrepared := PrepareEvent(FCounter, AEndTick, EndEvent, True);
  if (LPrepared.Tick <> FPlanEndTick) or (LPrepared.ByteCount <> FPlanByteCount) or
    (LPrepared.EventCount <> FPlanEventCount) or (LPrepared.BridgeCount <> FPlanBridgeCount) or
    (LPrepared.Signature <> FPlanSignature) then
  begin
    FFailed := True;
    StreamError('final replay fingerprint or counts differ from the track plan');
  end;
  FEvent := EndEvent;
  FRemainingBridges := LPrepared.AddedBridges;
  FEventDelta := LPrepared.Delta;
  FPrefixCount := 0;
  FPrefixPosition := 0;
  FDataPosition := 0;
  FEventPrefixReady := False;
  FQueueKind := QueueEvent;
  CommitPrepared(FCounter, LPrepared);
  FCounter.FFinished := True;
  FInputEnded := True;
end;

procedure TMidiFileStream.Cancel;
begin
  if FFinished or FCancelled then
  begin
    Exit;
  end;
  FCancelled := True;
  FQueueKind := QueueNone;
  FEvent.Data := nil;
  FRemainingBridges := 0;
  FPrefixCount := 0;
  FPrefixPosition := 0;
end;

end.

