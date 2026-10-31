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
unit pythian.music.stream;

{$mode delphi}
{$H+}

interface

uses pythian.audio, pythian.chord, pythian.instrument, pythian.bus,
  pythian.schedule, pythian.progress;

const
  InstrumentMusicStreamVersion = 1;
  InstrumentStreamBlockFrames = 2048;

type
  TInstrumentStreamState = (issReady, issPaused, issCompleted, issStopped, issFailed);
  TInstrumentStreamBinding = record
    Instrument: TInstrument;
    Bus: Integer;
    MaximumTones: Integer;
    { Zero sustains until attack/rest/end. Positive frames make independent
      one-shots: later attacks/rests do not cut their natural gate/release. }
    GateFrames: Int64;
  end;
  TInstrumentStreamBindings = array of TInstrumentStreamBinding;
  TInstrumentStreamOptions = record
    MusicFrames: Int64;
    TailFrames: Int64;
    VoiceLimit: Integer;
    WorkLimit: Integer;
    Seed: Cardinal;
  end;

  { Big Boss: bounded stereo performance of native rest/attack/hold frames.
    Instruments/factories and the bus graph are borrowed and immutable except
    for deliberate external bus controls between calls. Graph processing is
    exclusive to this stream; no reset occurs at musical/planning boundaries.
    A hold keeps the actual playing voices, oscillator/filter/envelope/source
    state and effect history. Only one input interval and a bounded PCM pull
    are retained. No full score, note ledger or duration-sized PCM is allocated.

    Admit only at NeedsInput. Bad admission, staging failure and cancelled
    preparation preserve the last input and scheduler. A scheduler publication
    failure or any processing/observer failure during ReadSamples is terminal.
    Earlier delivered PCM remains identifiable by Position. ReadSamples never
    returns a partial failed block. Pause preserves every clock/state; Stop
    discards future output. Calls/observers must not reenter or mutate bindings. }
  TInstrumentMusicStream = class
  private
    FBindings: TInstrumentStreamBindings;
    FCapacities: TChordCapacities;
    FPrevious: TChordFrame;
    FOptions: TInstrumentStreamOptions;
    FGraph: TBusGraph;
    FSynth: TScheduledSynth;
    FState: TInstrumentStreamState;
    FBusy: Boolean;
    FEnded: Boolean;
    FAdmittedFrames: Int64;
    FRemainingFrames: Int64;
    FPosition: Int64;
    FFrameCount: Int64;
    FPeakVoices: Integer;
    procedure RequireIdle;
    procedure RequireReady;
    procedure EndMusic(const AProgress: TWorkProgressCallback);
    function GetNeedsInput: Boolean;
    function GetSampleRate: Integer;
    function GetVoices: Integer;
  public
    constructor Create(const ABindings: TInstrumentStreamBindings;
      const AGraph: TBusGraph; const AOptions: TInstrumentStreamOptions);
    destructor Destroy; override;
    procedure AdmitFrame(const AFrame: TChordFrame; const AFrameCount: Int64;
      const AProgress: TWorkProgressCallback = nil);
    { At most2048 frames and the primary weighted-work bound. False/nil means
      input is needed, paused/stopped, or complete; inspect State/NeedsInput.
      The final input automatically releases held notes before TailFrames. }
    function ReadSamples(const AMaximumFrames: Integer; out ASamples: TAudioSamples;
      const AProgress: TWorkProgressCallback = nil): Boolean;
    { One performance supplies master plus detached selected bus taps. Each
      output has the same bounded frame extent. Failure publishes neither.
      Copy work also counts toward the pull budget. }
    function ReadOutputs(const AMaximumFrames: Integer; const AOutputBuses: array of Integer;
      out ASamples: TAudioSamples; out AOutputs: TBusSampleBlocks;
      const AProgress: TWorkProgressCallback = nil): Boolean;
    { Non-mutating extent/bus preflight for adapters before musical admission. }
    procedure ValidatePull(const AMaximumFrames: Integer; const AOutputBuses: array of Integer);
    procedure Pause;
    procedure Resume;
    procedure Stop;
    property State: TInstrumentStreamState read FState;
    property NeedsInput: Boolean read GetNeedsInput;
    property Position: Int64 read FPosition;
    property AdmittedFrames: Int64 read FAdmittedFrames;
    property FrameCount: Int64 read FFrameCount;
    property SampleRate: Integer read GetSampleRate;
    property Voices: Integer read GetVoices;
    property PeakVoices: Integer read FPeakVoices;
  end;

function DefaultInstrumentStreamOptions(const AMusicFrames: Int64): TInstrumentStreamOptions;

implementation

uses Math, SysUtils, pythian.synth, pythian.time;

function DefaultInstrumentStreamOptions(const AMusicFrames: Int64): TInstrumentStreamOptions;
begin
  Result := Default(TInstrumentStreamOptions);
  Result.MusicFrames := AMusicFrames;
  Result.VoiceLimit := 128;
  Result.WorkLimit := 1000000;
  Result.Seed := 731;
end;

constructor TInstrumentMusicStream.Create(const ABindings: TInstrumentStreamBindings;
  const AGraph: TBusGraph; const AOptions: TInstrumentStreamOptions);
var
  LIndex: Integer;
  LMaximumFrames: Int64;
begin
  inherited Create;
  if (AGraph = nil) or (Length(ABindings) < 1) or
    (Length(ABindings) > MaximumChordVoices) then
  begin
    raise EAudio.Create('Instrument stream requires a bus graph and ordered instruments');
  end;
  LMaximumFrames := Int64(AGraph.SampleRate) * 86400;
  RequireExactTimingCounter(AOptions.MusicFrames, 'Instrument music length');
  RequireExactTimingCounter(AOptions.TailFrames, 'Instrument tail length');
  if (AOptions.MusicFrames < 1) or (AOptions.MusicFrames > LMaximumFrames) or
    (AOptions.TailFrames < 0) or (AOptions.TailFrames > LMaximumFrames) then
  begin
    raise EAudio.Create('Instrument music and tail lengths each have a one-day bound');
  end;
  FGraph := AGraph;
  FOptions := AOptions;
  FFrameCount := AOptions.MusicFrames + AOptions.TailFrames;
  FBindings := Copy(ABindings);
  SetLength(FCapacities, Length(FBindings));
  SetLength(FPrevious, Length(FBindings));
  for LIndex := 0 to High(FBindings) do
  begin
    if (FBindings[LIndex].Instrument = nil) or
      (FBindings[LIndex].Bus < 0) or (FBindings[LIndex].Bus >= AGraph.BusCount) or
      (FBindings[LIndex].GateFrames < 0) or
      (FBindings[LIndex].GateFrames > LMaximumFrames) then
    begin
      raise EAudio.Create('Instrument stream binding is invalid');
    end;
    FCapacities[LIndex] := FBindings[LIndex].MaximumTones;
  end;
  ValidateChordTransition(FPrevious, FPrevious, FCapacities);
  FSynth := TScheduledSynth.Create(AGraph, AOptions.VoiceLimit, AOptions.WorkLimit);
end;

destructor TInstrumentMusicStream.Destroy;
begin
  FSynth.Free;
  inherited Destroy;
end;

procedure TInstrumentMusicStream.RequireIdle;
begin
  if FBusy then
  begin
    raise EAudio.Create('Instrument stream calls cannot reenter');
  end;
end;

procedure TInstrumentMusicStream.RequireReady;
begin
  RequireIdle;
  if FState <> issReady then
  begin
    raise EAudio.Create('Instrument stream is paused or terminal');
  end;
end;

function TInstrumentMusicStream.GetNeedsInput: Boolean;
begin
  Result := (FState = issReady) and not FEnded and (FRemainingFrames = 0) and
    (FAdmittedFrames < FOptions.MusicFrames);
end;

function TInstrumentMusicStream.GetSampleRate: Integer;
begin
  Result := FGraph.SampleRate;
end;

function TInstrumentMusicStream.GetVoices: Integer;
begin
  Result := 0;
  if FSynth <> nil then Result := FSynth.ScheduledCount;
end;

procedure TInstrumentMusicStream.AdmitFrame(const AFrame: TChordFrame;
  const AFrameCount: Int64; const AProgress: TWorkProgressCallback);
var
  LPrepared: TScheduledTones;
  LPart: TFrameTones;
  LFrame: TChordFrame;
  LRelease: array of Integer;
  LVoice: Integer;
  LTone: Integer;
  LLayer: Integer;
  LCount: Integer;
  LGate: Int64;
  LId: Int64;
  LSeed: Cardinal;
  LResult: TScheduleResult;
begin
  RequireReady;
  if not NeedsInput then
  begin
    raise EAudio.Create('Drain the current instrument interval before admitting another');
  end;
  RequireExactTimingCounter(AFrameCount, 'Instrument interval length');
  if (AFrameCount < 1) or (AFrameCount > FOptions.MusicFrames - FAdmittedFrames) then
  begin
    raise EAudio.Create('Instrument interval exceeds the declared musical extent');
  end;
  FBusy := True;
  LPrepared := nil;
  LRelease := nil;
  try
    try
      ValidateChordTransition(AFrame, FPrevious, FCapacities);
      LFrame := CopyChordFrame(AFrame);
      for LVoice := 0 to High(LFrame) do
      begin
        ReportWork(AProgress, 'instrument_stream_prepare', wuItems, LVoice, Length(LFrame));
        if LFrame[LVoice].Action = caHold then Continue;
        if FBindings[LVoice].GateFrames = 0 then
        begin
          LCount := Length(LRelease);
          SetLength(LRelease, LCount + 1);
          LRelease[LCount] := LVoice;
        end;
        if LFrame[LVoice].Action <> caAttack then Continue;
        LGate := FBindings[LVoice].GateFrames;
        if LGate = 0 then LGate := FOptions.MusicFrames - FAdmittedFrames;
        for LTone := 0 to High(LFrame[LVoice].Tones) do
        begin
          { Absolute musical time/role/tone identity, independent of PCM pulls. }
          LSeed := FOptions.Seed xor Cardinal(FAdmittedFrames mod Int64(4294967296)) xor
            Cardinal(LVoice * 4099 + LTone * 131);
          LPart := FBindings[LVoice].Instrument.PlanNote(LFrame[LVoice].Tones[LTone].Pitch,
            LFrame[LVoice].Tones[LTone].Velocity, SampleRate, FAdmittedFrames, LGate, LSeed);
          LCount := Length(LPrepared);
          if Length(LPart) > MaximumScheduledVoices - LCount then
          begin
            raise EAudio.Create('Instrument frame exceeds the layered voice budget');
          end;
          SetLength(LPrepared, LCount + Length(LPart));
          for LLayer := 0 to High(LPart) do
          begin
            LPrepared[LCount + LLayer].Tone := LPart[LLayer];
            LPrepared[LCount + LLayer].Bus := FBindings[LVoice].Bus;
            LPrepared[LCount + LLayer].Group := LVoice;
          end;
        end;
      end;
      LResult := FSynth.TryScheduleBatch(LPrepared, LRelease, LId, AProgress);
      if LResult <> srScheduled then
      begin
        raise EAudio.Create('Instrument frame exceeds its active voice or work budget');
      end;
      FPrevious := LFrame;
      Inc(FAdmittedFrames, AFrameCount);
      FRemainingFrames := AFrameCount;
      FPeakVoices := Max(FPeakVoices, FSynth.ScheduledCount);
    except
      if FSynth.Failed then FState := issFailed;
      raise;
    end;
  finally
    FBusy := False;
  end;
end;

procedure TInstrumentMusicStream.EndMusic(const AProgress: TWorkProgressCallback);
var
  LRelease: array of Integer;
  LVoice: Integer;
  LCount: Integer;
  LId: Int64;
begin
  LRelease := nil;
  for LVoice := 0 to High(FBindings) do
  begin
    if FBindings[LVoice].GateFrames = 0 then
    begin
      LCount := Length(LRelease);
      SetLength(LRelease, LCount + 1);
      LRelease[LCount] := LVoice;
    end;
  end;
  FSynth.TryScheduleBatch([], LRelease, LId, AProgress);
  FEnded := True;
end;

function TInstrumentMusicStream.ReadSamples(const AMaximumFrames: Integer;
  out ASamples: TAudioSamples; const AProgress: TWorkProgressCallback): Boolean;
var
  LOutputs: TBusSampleBlocks;
begin
  Result := ReadOutputs(AMaximumFrames, [], ASamples, LOutputs, AProgress);
end;

procedure TInstrumentMusicStream.ValidatePull(const AMaximumFrames: Integer;
  const AOutputBuses: array of Integer);
var
  I: Integer;
begin
  RequireIdle;
  if (AMaximumFrames < 1) or (AMaximumFrames > 65536) then
    raise EAudio.Create('Instrument pull must request1..65536 frames');
  if Length(AOutputBuses) > MaximumBuses then
    raise EAudio.Create('Instrument output taps exceed the bus bound');
  for I := 0 to High(AOutputBuses) do
    if (AOutputBuses[I] < 0) or (AOutputBuses[I] >= FGraph.BusCount) then
      raise EAudio.Create('Instrument output tap is outside the graph');
end;

function TInstrumentMusicStream.ReadOutputs(const AMaximumFrames: Integer;
  const AOutputBuses: array of Integer; out ASamples: TAudioSamples;
  out AOutputs: TBusSampleBlocks; const AProgress: TWorkProgressCallback): Boolean;
var
  LCount: Integer;
  LIndex: Integer;
  LLimit: Integer;
  LLeft: Double;
  LRight: Double;
  LSamples: TAudioSamples;
  LOutputs: TBusSampleBlocks;
  LTap: Integer;
  LFrame: TStereoFrame;
begin
  RequireIdle;
  ASamples := nil;
  AOutputs := nil;
  Result := False;
  ValidatePull(AMaximumFrames, AOutputBuses);
  if FState = issFailed then
  begin
    raise EAudio.Create('Instrument stream processing previously failed');
  end;
  if FState <> issReady then Exit;
  if NeedsInput then Exit;
  FBusy := True;
  try
    try
      if not FEnded and (FRemainingFrames = 0) then EndMusic(AProgress);
      LLimit := MaximumRenderVisits div Max(Int64(1),
        Int64(FSynth.ReservedWork) + FGraph.FrameCost + 2 * Length(AOutputBuses));
      if LLimit < 1 then
        raise EAudio.Create('Instrument and effect work exceeds the per-pull budget');
      LCount := Min(AMaximumFrames, Min(InstrumentStreamBlockFrames, LLimit));
      LCount := Min(Int64(LCount), FFrameCount - FPosition);
      if not FEnded then LCount := Min(Int64(LCount), FRemainingFrames);
      SetLength(LSamples, LCount * 2);
      SetLength(LOutputs, Length(AOutputBuses));
      for LTap := 0 to High(LOutputs) do SetLength(LOutputs[LTap], LCount * 2);
      ReportWork(AProgress, 'instrument_stream_render', wuFrames, FPosition, FFrameCount);
      for LIndex := 0 to LCount - 1 do
      begin
        FSynth.Process(LLeft, LRight);
        LSamples[LIndex * 2] := LLeft;
        LSamples[LIndex * 2 + 1] := LRight;
        for LTap := 0 to High(LOutputs) do
        begin
          LFrame := FGraph.LastOutput(AOutputBuses[LTap]);
          LOutputs[LTap][LIndex * 2] := LFrame.Left;
          LOutputs[LTap][LIndex * 2 + 1] := LFrame.Right;
        end;
        if ((LIndex + 1) mod 256 = 0) then
        begin
          ReportWork(AProgress, 'instrument_stream_render', wuFrames,
            FPosition + LIndex + 1, FFrameCount);
        end;
      end;
      ReportWork(AProgress, 'instrument_stream_ready', wuFrames,
        FPosition + LCount, FFrameCount);
      Inc(FPosition, LCount);
      if not FEnded then Dec(FRemainingFrames, LCount);
      if FPosition = FFrameCount then FState := issCompleted;
      ASamples := LSamples;
      AOutputs := LOutputs;
      Result := LCount > 0;
    except
      FState := issFailed;
      raise;
    end;
  finally
    FBusy := False;
  end;
end;

procedure TInstrumentMusicStream.Pause;
begin
  RequireIdle;
  if FState = issReady then FState := issPaused;
end;

procedure TInstrumentMusicStream.Resume;
begin
  RequireIdle;
  if FState = issPaused then FState := issReady;
end;

procedure TInstrumentMusicStream.Stop;
begin
  RequireIdle;
  if FState in [issReady, issPaused] then
  begin
    FBusy := True;
    try
      FState := issStopped;
      FreeAndNil(FSynth);
    finally
      FBusy := False;
    end;
  end;
end;

end.
