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
unit pythian.chord.stream;

{$mode delphi}
{$H+}

interface

uses
  pythian.chord,
  pythian.audio;

const
  ChordStreamVersion = 1;
  ChordStreamBlockFrames = 2048;
  MaximumChordStreamVoices = 4096;
  MaximumChordStreamTones = 4096;
  MaximumChordReleaseWork = 16777216;
  caRest = pythian.chord.caRest;
  caAttack = pythian.chord.caAttack;
  caHold = pythian.chord.caHold;

type
  { Preserve the renderer's original public type names as aliases. }
  TChordAction = pythian.chord.TChordAction;
  TChordTone = pythian.chord.TChordTone;
  TChordTones = pythian.chord.TChordTones;
  TChordVoice = pythian.chord.TChordVoice;
  TChordFrame = pythian.chord.TChordFrame;
  TChordCapacities = array of Integer;
  TChordStreamOptions = record
    SampleRate: Integer;
    MasterVolume: Integer;
    AttackFrames: Integer;
    ReleaseFrames: Integer;
  end;

  { Fixed-point mono triangle preview extracted from WFC's ensemble renderer.
    Frame lengths are sample frames; musical clocks belong to the caller.
    Admit only when NeedsInput; drain ReadSamples before the next admission.
    Zero-length intervals still apply attacks, identical holds and rests.
    Input is detached. An identical hold retains phase and attack age.

    Retains ReleaseFrames+1 mixed samples and bounded active chord state.
    This delay permits shaping the end of an unknown-length gate retrospectively.
    EndInput drains exactly the admitted duration, with no appended release tail.
    Cancel discards all unreturned audio. No callbacks or device dependencies.
    Invalid admission is retryable and preserves state. Unexpected processing
    errors poison the renderer. Sequential calls only; no thread safety.

    ReadSamples returns detached, normalized PCM16 values as native samples,
    at most ChordStreamBlockFrames per call. False returns nil; inspect
    NeedsInput/Finished/Cancelled. This is an exact preview contract, with the
    original non-bandlimited triangle sound; use the general synthesizer for
    other waveforms, stereo instruments and post-note-off ADSR tails. }
  TChordStreamRenderer = class
  strict private
    type
      TToneState = record
        Pitch: Integer;
        Velocity: Integer;
        Phase: Integer;
        Increment: Integer;
      end;
      TToneStates = array of TToneState;
      TVoiceState = record
        StartFrame: Int64;
        Tones: TToneStates;
      end;
      TVoiceStates = array of TVoiceState;
    var
      FOptions: TChordStreamOptions;
      FCapacities: TChordCapacities;
      FVoices: TVoiceStates;
      FHeadroom: Integer;
      FFrameCount: Int64;
      FRemainingFrames: Int64;
      FRenderedFrames: Int64;
      FEmittedFrames: Int64;
      FRing: array of Integer;
      FReadIndex: Integer;
      FWriteIndex: Integer;
      FPending: Integer;
      FInputEnded: Boolean;
      FFinished: Boolean;
      FCancelled: Boolean;
      FFailed: Boolean;
      function GetNeedsInput: Boolean;
      procedure CheckActive;
      procedure ValidateFrame(const AFrame: TChordFrame);
      function AttackGain(const AAge: Int64): Integer;
      function ToneSample(const APhase, AVelocity, AGain: Integer): Integer;
      procedure CloseVoice(const AIndex: Integer);
      procedure RenderOne;
  public
    constructor Create(const AOptions: TChordStreamOptions;
      const ACapacities: TChordCapacities);
    procedure AdmitFrame(const AFrame: TChordFrame; const AFrameCount: Int64);
    function ReadSamples(const AMaxFrames: Integer; out ASamples: TAudioSamples): Boolean;
    procedure EndInput;
    procedure Cancel;
    property SampleRate: Integer read FOptions.SampleRate;
    property LatencyFrames: Integer read FOptions.ReleaseFrames;
    property Headroom: Integer read FHeadroom;
    property FrameCount: Int64 read FFrameCount;
    property RenderedFrames: Int64 read FRenderedFrames;
    property EmittedFrames: Int64 read FEmittedFrames;
    property NeedsInput: Boolean read GetNeedsInput;
    property InputEnded: Boolean read FInputEnded;
    property Finished: Boolean read FFinished;
    property Cancelled: Boolean read FCancelled;
    property Failed: Boolean read FFailed;
  end;

function DefaultChordStreamOptions(const ASampleRate: Integer = 44100): TChordStreamOptions;

implementation

uses
  pythian.oscillator;

function DefaultChordStreamOptions(const ASampleRate: Integer): TChordStreamOptions;
begin
  ValidateAudioFormat(ASampleRate, 1);
  Result.SampleRate := ASampleRate;
  Result.MasterVolume := 96;
  Result.AttackFrames := ASampleRate * 5 div 1000;
  Result.ReleaseFrames := ASampleRate * 20 div 1000;
end;

constructor TChordStreamRenderer.Create(const AOptions: TChordStreamOptions;
  const ACapacities: TChordCapacities);
var
  LIndex: Integer;
  LSum: Integer;
begin
  inherited Create;
  ValidateAudioFormat(AOptions.SampleRate, 1);
  if (AOptions.MasterVolume < 0) or (AOptions.MasterVolume > 127) or
    (AOptions.AttackFrames < 0) or (AOptions.AttackFrames > AOptions.SampleRate) or
    (AOptions.ReleaseFrames < 0) or (AOptions.ReleaseFrames > AOptions.SampleRate) then
  begin
    raise EAudio.Create('Chord volume must be 0..127 and envelopes at most one second');
  end;
  if (Length(ACapacities) < 1) or (Length(ACapacities) > MaximumChordStreamVoices) then
  begin
    raise EAudio.Create('Chord voice count exceeds the stream budget');
  end;
  LSum := 0;
  for LIndex := 0 to High(ACapacities) do
  begin
    if (ACapacities[LIndex] < 0) or
      (ACapacities[LIndex] > MaximumChordStreamTones - LSum) then
    begin
      raise EAudio.Create('Chord capacities exceed the stream tone budget');
    end;
    Inc(LSum, ACapacities[LIndex]);
  end;
  if Int64(LSum) * AOptions.ReleaseFrames > MaximumChordReleaseWork then
  begin
    raise EAudio.Create('Chord release work exceeds the stream budget');
  end;
  FHeadroom := LSum;
  if FHeadroom = 0 then
  begin
    FHeadroom := 1;
  end;
  FOptions := AOptions;
  FCapacities := Copy(ACapacities);
  SetLength(FVoices, Length(ACapacities));
  SetLength(FRing, AOptions.ReleaseFrames + 1);
end;

function TChordStreamRenderer.GetNeedsInput: Boolean;
begin
  Result := not (FInputEnded or FCancelled or FFailed) and (FRemainingFrames = 0);
end;

procedure TChordStreamRenderer.CheckActive;
begin
  if FFailed then
  begin
    raise EAudio.Create('A previous chord processing operation failed');
  end;
  if FCancelled then
  begin
    raise EAudio.Create('Chord renderer has been cancelled');
  end;
end;

procedure TChordStreamRenderer.ValidateFrame(const AFrame: TChordFrame);
var
  LVoice: Integer;
  LTone: Integer;
  LAction: Integer;
begin
  if Length(AFrame) <> Length(FVoices) then
  begin
    raise EAudio.Create('Chord frame voice count does not match capacities');
  end;
  for LVoice := 0 to High(AFrame) do
  begin
    LAction := Ord(AFrame[LVoice].Action);
    case LAction of
      Ord(caRest), Ord(caAttack), Ord(caHold):
      begin
      end;
    else
      raise EAudio.Create('Unknown chord action');
    end;
    if Length(AFrame[LVoice].Tones) > FCapacities[LVoice] then
    begin
      raise EAudio.Create('Chord exceeds its declared tone capacity');
    end;
    if AFrame[LVoice].Action = caRest then
    begin
      if Length(AFrame[LVoice].Tones) <> 0 then
      begin
        raise EAudio.Create('Chord rest contains tones');
      end;
      Continue;
    end;
    if Length(AFrame[LVoice].Tones) = 0 then
    begin
      raise EAudio.Create('Sounding chord has no tones');
    end;
    if (AFrame[LVoice].Action = caHold) and
      (Length(AFrame[LVoice].Tones) <> Length(FVoices[LVoice].Tones)) then
    begin
      raise EAudio.Create('Chord hold has no identical active predecessor');
    end;
    for LTone := 0 to High(AFrame[LVoice].Tones) do
    begin
      if (AFrame[LVoice].Tones[LTone].Pitch < 0) or
        (AFrame[LVoice].Tones[LTone].Pitch > 127) or
        (AFrame[LVoice].Tones[LTone].Velocity < 1) or
        (AFrame[LVoice].Tones[LTone].Velocity > 127) then
      begin
        raise EAudio.Create('Chord pitch must be 0..127 and velocity 1..127');
      end;
      if (LTone > 0) and
        (AFrame[LVoice].Tones[LTone - 1].Pitch >= AFrame[LVoice].Tones[LTone].Pitch) then
      begin
        raise EAudio.Create('Chord pitches must be strictly increasing');
      end;
      if AFrame[LVoice].Action = caHold then
      begin
        if (AFrame[LVoice].Tones[LTone].Pitch <> FVoices[LVoice].Tones[LTone].Pitch) or
          (AFrame[LVoice].Tones[LTone].Velocity <> FVoices[LVoice].Tones[LTone].Velocity) then
        begin
          raise EAudio.Create('Chord hold changes an active pitch or velocity');
        end;
      end;
    end;
  end;
end;

function TChordStreamRenderer.AttackGain(const AAge: Int64): Integer;
begin
  Result := EnvelopeScale;
  if (FOptions.AttackFrames > 0) and (AAge < FOptions.AttackFrames) then
  begin
    Result := AAge * EnvelopeScale div FOptions.AttackFrames;
  end;
end;

function TChordStreamRenderer.ToneSample(const APhase, AVelocity, AGain: Integer): Integer;
var
  LSample: Int64;
begin
  LSample := Int64(FixedTriangleSample(APhase)) * AVelocity;
  LSample := (LSample div 127) * FOptions.MasterVolume;
  LSample := (LSample div 127) * AGain;
  Result := (LSample div EnvelopeScale) div FHeadroom;
end;

procedure TChordStreamRenderer.CloseVoice(const AIndex: Integer);
var
  LAge: Int64;
  LCount: Integer;
  LDistance: Integer;
  LRingIndex: Integer;
  LTone: Integer;
  LPhase: Integer;
  LAttack: Integer;
  LGain: Integer;
  LRelease: Integer;
begin
  if (Length(FVoices[AIndex].Tones) = 0) or (FOptions.ReleaseFrames = 0) then
  begin
    Exit;
  end;
  LAge := FRenderedFrames - FVoices[AIndex].StartFrame;
  LCount := FOptions.ReleaseFrames;
  if LAge < LCount then
  begin
    LCount := LAge;
  end;
  LRingIndex := FWriteIndex;
  for LDistance := 1 to LCount do
  begin
    Dec(LRingIndex);
    if LRingIndex < 0 then
    begin
      LRingIndex := High(FRing);
    end;
    LAttack := AttackGain(LAge - LDistance);
    LRelease := Int64(LDistance - 1) * EnvelopeScale div FOptions.ReleaseFrames;
    LGain := LAttack;
    if LRelease < LGain then
    begin
      LGain := LRelease;
    end;
    for LTone := 0 to High(FVoices[AIndex].Tones) do
    begin
      { Rewind only within the retained release window, independent of stream age. }
      LPhase := FVoices[AIndex].Tones[LTone].Phase - Integer(
        (Int64(FVoices[AIndex].Tones[LTone].Increment) * LDistance) mod PhaseModulus);
      if LPhase < 0 then
      begin
        Inc(LPhase, PhaseModulus);
      end;
      FRing[LRingIndex] := FRing[LRingIndex] -
        ToneSample(LPhase, FVoices[AIndex].Tones[LTone].Velocity, LAttack) +
        ToneSample(LPhase, FVoices[AIndex].Tones[LTone].Velocity, LGain);
    end;
  end;
end;

procedure TChordStreamRenderer.AdmitFrame(const AFrame: TChordFrame; const AFrameCount: Int64);
var
  LNext: TVoiceStates;
  LVoice: Integer;
  LTone: Integer;
begin
  CheckActive;
  if not NeedsInput then
  begin
    raise EAudio.Create('Drain the preceding chord frame before admission');
  end;
  if (AFrameCount < 0) or (AFrameCount > High(Int64) - FFrameCount) then
  begin
    raise EAudio.Create('Chord interval or total frame count exceeds Int64 range');
  end;
  ValidateFrame(AFrame);
  { Complete validation and allocations before changing delayed audio or voices. }
  SetLength(LNext, Length(FVoices));
  for LVoice := 0 to High(LNext) do
  begin
    LNext[LVoice].StartFrame := FRenderedFrames;
    SetLength(LNext[LVoice].Tones, Length(AFrame[LVoice].Tones));
    if AFrame[LVoice].Action = caHold then
    begin
      LNext[LVoice].StartFrame := FVoices[LVoice].StartFrame;
    end;
    for LTone := 0 to High(LNext[LVoice].Tones) do
    begin
      if AFrame[LVoice].Action = caHold then
      begin
        LNext[LVoice].Tones[LTone] := FVoices[LVoice].Tones[LTone];
      end
      else
      begin
        LNext[LVoice].Tones[LTone].Pitch := AFrame[LVoice].Tones[LTone].Pitch;
        LNext[LVoice].Tones[LTone].Velocity := AFrame[LVoice].Tones[LTone].Velocity;
        LNext[LVoice].Tones[LTone].Increment :=
          FixedPhaseIncrement(AFrame[LVoice].Tones[LTone].Pitch, FOptions.SampleRate);
      end;
    end;
  end;
  try
    for LVoice := 0 to High(FVoices) do
    begin
      if AFrame[LVoice].Action <> caHold then
      begin
        CloseVoice(LVoice);
      end;
    end;
    FRemainingFrames := AFrameCount;
    Inc(FFrameCount, AFrameCount);
    FVoices := LNext;
  except
    FFailed := True;
    raise;
  end;
end;

procedure TChordStreamRenderer.RenderOne;
var
  LVoice: Integer;
  LTone: Integer;
  LGain: Integer;
  LSample: Integer;
begin
  LSample := 0;
  for LVoice := 0 to High(FVoices) do
  begin
    LGain := AttackGain(FRenderedFrames - FVoices[LVoice].StartFrame);
    for LTone := 0 to High(FVoices[LVoice].Tones) do
    begin
      Inc(LSample, ToneSample(FVoices[LVoice].Tones[LTone].Phase,
        FVoices[LVoice].Tones[LTone].Velocity, LGain));
      FVoices[LVoice].Tones[LTone].Phase :=
        (FVoices[LVoice].Tones[LTone].Phase + FVoices[LVoice].Tones[LTone].Increment) and PhaseMask;
    end;
  end;
  FRing[FWriteIndex] := LSample;
  Inc(FWriteIndex);
  if FWriteIndex = Length(FRing) then
  begin
    FWriteIndex := 0;
  end;
  Inc(FPending);
  Inc(FRenderedFrames);
  Dec(FRemainingFrames);
end;

function TChordStreamRenderer.ReadSamples(const AMaxFrames: Integer;
  out ASamples: TAudioSamples): Boolean;
var
  LCount: Integer;
  LLimit: Integer;
  LSample: Integer;
begin
  ASamples := nil;
  if AMaxFrames < 1 then
  begin
    raise EAudio.Create('Chord output block size must be positive');
  end;
  if FFailed then
  begin
    raise EAudio.Create('A previous chord processing operation failed');
  end;
  if FCancelled or FFinished then
  begin
    Exit(False);
  end;
  LLimit := AMaxFrames;
  if LLimit > ChordStreamBlockFrames then
  begin
    LLimit := ChordStreamBlockFrames;
  end;
  SetLength(ASamples, LLimit);
  LCount := 0;
  try
    while LCount < LLimit do
    begin
      if (FPending > FOptions.ReleaseFrames) or (FInputEnded and (FPending > 0)) then
      begin
        LSample := FRing[FReadIndex];
        if LSample < -32768 then
        begin
          LSample := -32768;
        end;
        if LSample > 32767 then
        begin
          LSample := 32767;
        end;
        ASamples[LCount] := LSample / 32768;
        Inc(LCount);
        Inc(FReadIndex);
        if FReadIndex = Length(FRing) then
        begin
          FReadIndex := 0;
        end;
        Dec(FPending);
        Inc(FEmittedFrames);
      end
      else if FRemainingFrames > 0 then
      begin
        RenderOne;
      end
      else
      begin
        Break;
      end;
    end;
    if FInputEnded and (FPending = 0) then
    begin
      FFinished := True;
    end;
    SetLength(ASamples, LCount);
    Result := LCount <> 0;
  except
    ASamples := nil;
    FFailed := True;
    raise;
  end;
end;

procedure TChordStreamRenderer.EndInput;
var
  LVoice: Integer;
begin
  CheckActive;
  if FInputEnded then
  begin
    Exit;
  end;
  if not NeedsInput then
  begin
    raise EAudio.Create('Drain the current chord frame before ending input');
  end;
  try
    for LVoice := 0 to High(FVoices) do
    begin
      CloseVoice(LVoice);
      FVoices[LVoice].Tones := nil;
    end;
    FInputEnded := True;
    FFinished := FPending = 0;
  except
    FFailed := True;
    raise;
  end;
end;

procedure TChordStreamRenderer.Cancel;
begin
  if FFinished or FFailed or FCancelled then
  begin
    Exit;
  end;
  FCancelled := True;
  FRemainingFrames := 0;
  FPending := 0;
  FVoices := nil;
  FRing := nil;
end;

end.
