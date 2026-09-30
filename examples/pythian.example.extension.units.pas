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
unit pythian.example.extension.units;

{$mode delphi}
{$H+}

interface

uses
  pythian.audio, pythian.source, pythian.effects, pythian.synth;

const
  CallerSourceFrameCost = 64;
  CallerDelayFrameCost = 16;
  MaximumCallerDelayFrames = 2048;
  CallerExampleSampleRate = 16000;
  CallerExampleFrames = 16000;
  CallerExampleDelayFrames = 240;

type
  { Optional caller-owned instrumentation, not a global or an audio callback.
    Keep this observer alive until every factory/source/effect using it is freed. }
  TCallerExtensionProbe = class
  public
    SourcesCreated: Integer;
    SourcesDestroyed: Integer;
    SourceResets: Integer;
    SourceNoteOffs: Integer;
    SourceFrames: Int64;
    SourceWeightedWork: Int64;
    MaximumSourceFrameWork: Integer;
    EffectResets: Integer;
    EffectFrames: Int64;
    EffectWeightedWork: Int64;
    MaximumEffectFrameWork: Integer;
  end;

  { Immutable caller definition; no built-in source factory is wrapped.
    Two sine harmonics share a seeded phase, with a caller-selected second mix.
    ValidateRange requires both harmonics strictly below Nyquist. }
  TCallerHarmonicFactory = class(TAudioSourceFactory)
  private
    FSecondMix: Double;
    FProbe: TCallerExtensionProbe;
  public
    constructor Create(const ASecondMix: Double;
      const AProbe: TCallerExtensionProbe = nil);
    function CreateSource(const ASampleRate: Integer; const ASeed: Cardinal): TAudioSource;
      override;
    procedure ValidateRange(const AMinimumHz, AMaximumHz: Double;
      const ASampleRate: Integer); override;
    function FrameCost(const ASampleRate: Integer): Integer; override;
    function Channels: Integer; override;
  end;

  { Finite feed-forward cross-stereo delay. Dry input plus Wet times the opposite
    channel delayed by DelayFrames. No feedback. Reset clears all history.
    Exactly DelayFrames zero frames after the WHOLE input flush its finite tail.
    A chain owns this instance only after successful Add/AddEffect. }
  TCallerStereoDelay = class(TAudioEffect)
  private
    FDelayFrames: Integer;
    FWet: Double;
    FBuffer: array of Double;
    FPosition: Integer;
    FProbe: TCallerExtensionProbe;
  public
    constructor Create(const ASampleRate, ADelayFrames: Integer; const AWet: Double;
      const AProbe: TCallerExtensionProbe = nil);
    procedure Reset; override;
    procedure Process(const ALeft, ARight: Double; out AOutputLeft, AOutputRight: Double);
      override;
    function FrameCost: Integer; override;
    property DelayFrames: Integer read FDelayFrames;
  end;

{ Factory remains borrowed, including while the detached tone records exist. }
function MakeCallerTones(const AFactory: TAudioSourceFactory; const ASeed: Cardinal): TFrameTones;
{ Each helper returns an owned clip and owns its temporary scheduler/stream and
  delay instances. Factory/probe remain borrowed. No file I/O or playback. }
function RenderCallerScheduled(const AFactory: TAudioSourceFactory; const ASeed: Cardinal;
  const AWet: Double; const AProbe: TCallerExtensionProbe = nil): TAudioClip;
function RenderCallerStreamed(const AFactory: TAudioSourceFactory; const ASeed: Cardinal;
  const AWet: Double; const ABlockFrames: Integer;
  const AProbe: TCallerExtensionProbe = nil): TAudioClip;

implementation

uses
  SysUtils, Math, pythian.bus, pythian.schedule, pythian.synth.stream;

type
  TCallerHarmonicSource = class(TAudioSource)
  private
    FSampleRate: Integer;
    FSecondMix: Double;
    FInitialPhase: Double;
    FPhase: Double;
    FReleased: Boolean;
    FProbe: TCallerExtensionProbe;
  public
    constructor Create(const ASampleRate: Integer; const ASeed: Cardinal;
      const ASecondMix: Double; const AProbe: TCallerExtensionProbe);
    destructor Destroy; override;
    procedure Reset; override;
    procedure NoteOff; override;
    function ReadFrame(const AFrequencyHz: Double; out ALeft, ARight: Double): Boolean;
      override;
  end;

constructor TCallerHarmonicFactory.Create(const ASecondMix: Double;
  const AProbe: TCallerExtensionProbe);
begin
  inherited Create;
  RequireFinite(ASecondMix, 'Caller second harmonic mix');
  if (ASecondMix < 0) or (ASecondMix > 1) then
  begin
    raise EAudio.Create('Caller second harmonic mix must be in 0..1');
  end;
  FSecondMix := ASecondMix;
  FProbe := AProbe;
end;

function TCallerHarmonicFactory.CreateSource(const ASampleRate: Integer;
  const ASeed: Cardinal): TAudioSource;
begin
  ValidateAudioFormat(ASampleRate, 1);
  Result := TCallerHarmonicSource.Create(ASampleRate, ASeed, FSecondMix, FProbe);
end;

procedure TCallerHarmonicFactory.ValidateRange(const AMinimumHz, AMaximumHz: Double;
  const ASampleRate: Integer);
begin
  inherited ValidateRange(AMinimumHz, AMaximumHz, ASampleRate);
  if AMaximumHz * 2 >= ASampleRate * 0.5 then
  begin
    raise EAudio.Create('Caller second harmonic requires fundamental below one-quarter sample rate');
  end;
end;

function TCallerHarmonicFactory.FrameCost(const ASampleRate: Integer): Integer;
begin
  ValidateAudioFormat(ASampleRate, 1);
  Result := CallerSourceFrameCost;
end;

function TCallerHarmonicFactory.Channels: Integer;
begin
  Result := 1;
end;

constructor TCallerHarmonicSource.Create(const ASampleRate: Integer; const ASeed: Cardinal;
  const ASecondMix: Double; const AProbe: TCallerExtensionProbe);
begin
  inherited Create;
  FSampleRate := ASampleRate;
  FSecondMix := ASecondMix;
  FInitialPhase := (ASeed mod 1024) / 1024;
  FProbe := AProbe;
  if FProbe <> nil then
  begin
    Inc(FProbe.SourcesCreated);
  end;
  Reset;
end;

destructor TCallerHarmonicSource.Destroy;
begin
  if FProbe <> nil then
  begin
    Inc(FProbe.SourcesDestroyed);
  end;
  inherited Destroy;
end;

procedure TCallerHarmonicSource.Reset;
begin
  FPhase := FInitialPhase;
  FReleased := False;
  if FProbe <> nil then
  begin
    Inc(FProbe.SourceResets);
  end;
end;

procedure TCallerHarmonicSource.NoteOff;
begin
  if not FReleased then
  begin
    FReleased := True;
    if FProbe <> nil then
    begin
      Inc(FProbe.SourceNoteOffs);
    end;
  end;
  { Native ADSR owns amplitude release; this notification must not cut its tail. }
end;

function TCallerHarmonicSource.ReadFrame(const AFrequencyHz: Double;
  out ALeft, ARight: Double): Boolean;
var
  LAngle: Double;
  LValue: Double;
  LWork: Integer;
begin
  RequireFinite(AFrequencyHz, 'Caller source frequency');
  if (AFrequencyHz < 0) or (AFrequencyHz * 2 >= FSampleRate * 0.5) then
  begin
    raise EAudio.Create('Caller source frequency is outside its two-harmonic range');
  end;
  LWork := 6; { Finite/range validation, policy weights rather than CPU cycles. }
  LAngle := 2 * Pi * FPhase;
  Inc(LWork, 2);
  LValue := (Sin(LAngle) + FSecondMix * Sin(2 * LAngle)) / (1 + FSecondMix);
  Inc(LWork, 38); { Two bounded sine calls at weight16 plus scalar arithmetic. }
  FPhase := FPhase + AFrequencyHz / FSampleRate;
  if FPhase >= 1 then
  begin
    FPhase := FPhase - 1;
  end;
  Inc(LWork, 6); { Advance and conditional wrap. }
  ALeft := LValue;
  ARight := LValue;
  Result := True;
  Inc(LWork, 3);
  if FProbe <> nil then
  begin
    Inc(FProbe.SourceFrames);
    Inc(FProbe.SourceWeightedWork, LWork);
    FProbe.MaximumSourceFrameWork := Max(FProbe.MaximumSourceFrameWork, LWork);
  end;
end;

constructor TCallerStereoDelay.Create(const ASampleRate, ADelayFrames: Integer;
  const AWet: Double; const AProbe: TCallerExtensionProbe);
begin
  inherited Create(ASampleRate);
  RequireFinite(AWet, 'Caller delay wet gain');
  if (ADelayFrames < 1) or (ADelayFrames > MaximumCallerDelayFrames) or
    (AWet < 0) or (AWet > 1) then
  begin
    raise EAudio.Create('Caller delay requires 1..2048 frames and wet gain in 0..1');
  end;
  FDelayFrames := ADelayFrames;
  FWet := AWet;
  FProbe := AProbe;
  SetLength(FBuffer, ADelayFrames * 2);
  Reset;
end;

procedure TCallerStereoDelay.Reset;
var
  LIndex: Integer;
begin
  for LIndex := 0 to High(FBuffer) do
  begin
    FBuffer[LIndex] := 0;
  end;
  FPosition := 0;
  if FProbe <> nil then
  begin
    Inc(FProbe.EffectResets);
  end;
end;

procedure TCallerStereoDelay.Process(const ALeft, ARight: Double;
  out AOutputLeft, AOutputRight: Double);
var
  LLeft: Double;
  LRight: Double;
  LWork: Integer;
begin
  RequireFinite(ALeft, 'Caller delay input');
  RequireFinite(ARight, 'Caller delay input');
  LWork := 2;
  LLeft := ALeft + FWet * FBuffer[FPosition * 2 + 1];
  LRight := ARight + FWet * FBuffer[FPosition * 2];
  Inc(LWork, 8);
  FBuffer[FPosition * 2] := ALeft;
  FBuffer[FPosition * 2 + 1] := ARight;
  Inc(FPosition);
  if FPosition = FDelayFrames then
  begin
    FPosition := 0;
  end;
  Inc(LWork, 4);
  AOutputLeft := LLeft;
  AOutputRight := LRight;
  if FProbe <> nil then
  begin
    Inc(FProbe.EffectFrames);
    Inc(FProbe.EffectWeightedWork, LWork);
    FProbe.MaximumEffectFrameWork := Max(FProbe.MaximumEffectFrameWork, LWork);
  end;
end;

function TCallerStereoDelay.FrameCost: Integer;
begin
  Result := CallerDelayFrameCost;
end;

function MakeCallerTones(const AFactory: TAudioSourceFactory; const ASeed: Cardinal): TFrameTones;
var
  LIndex: Integer;
begin
  if (AFactory = nil) or (ASeed > High(Cardinal) - 2) then
  begin
    raise EAudio.Create('Caller tones need a factory and seed in 0..4294967293');
  end;
  Result := nil;
  SetLength(Result, 3);
  for LIndex := 0 to High(Result) do
  begin
    Result[LIndex].StartFrame := 512 + LIndex * 5120;
    Result[LIndex].GateFrames := 4096;
    Result[LIndex].FrequencyHz := 220 + LIndex * 55;
    Result[LIndex].Velocity := 0.6;
    Result[LIndex].Seed := ASeed + Cardinal(LIndex);
    Result[LIndex].Voice := DefaultSynthVoice;
    Result[LIndex].Voice.SourceFactory := AFactory;
    Result[LIndex].Voice.Envelope.ReleaseSeconds := 0.02;
    Result[LIndex].Voice.Pan := -0.4 + LIndex * 0.4;
  end;
end;

procedure AddOwnedDelay(const AGraph: TBusGraph; const AWet: Double;
  const AProbe: TCallerExtensionProbe);
var
  LDelay: TCallerStereoDelay;
begin
  LDelay := TCallerStereoDelay.Create(CallerExampleSampleRate, CallerExampleDelayFrames,
    AWet, AProbe);
  try
    AGraph.AddEffect(0, LDelay);
    LDelay := nil;
  finally
    LDelay.Free;
  end;
end;

function RenderCallerScheduled(const AFactory: TAudioSourceFactory; const ASeed: Cardinal;
  const AWet: Double; const AProbe: TCallerExtensionProbe): TAudioClip;
var
  LSettings: array[0..0] of TBusSettings;
  LGraph: TBusGraph;
  LSynth: TScheduledSynth;
  LTones: TFrameTones;
  LIndex: Integer;
  LId: Int64;
begin
  LTones := MakeCallerTones(AFactory, ASeed);
  LSettings[0] := DefaultBusSettings;
  LSettings[0].SmoothingSeconds := 0;
  LGraph := TBusGraph.Create(CallerExampleSampleRate, LSettings);
  try
    AddOwnedDelay(LGraph, AWet, AProbe);
    LSynth := TScheduledSynth.Create(LGraph, 3, 1024);
    try
      for LIndex := 0 to High(LTones) do
      begin
        if LSynth.TrySchedule(LTones[LIndex], 0, 1, LId) <> srScheduled then
        begin
          raise EAudio.Create('Caller scheduled example exceeded its declared admission bound');
        end;
      end;
      Result := RenderScheduledFrames(LSynth, CallerExampleFrames + CallerExampleDelayFrames);
    finally
      LSynth.Free;
    end;
  finally
    LGraph.Free;
  end;
end;

function RenderCallerStreamed(const AFactory: TAudioSourceFactory; const ASeed: Cardinal;
  const AWet: Double; const ABlockFrames: Integer;
  const AProbe: TCallerExtensionProbe): TAudioClip;
var
  LStream: TFrameToneStream;
  LChain: TEffectChain;
  LDelay: TCallerStereoDelay;
  LBlock: TAudioSamples;
  LResult: TAudioSamples;
  LInput: TAudioClip;
  LProcessed: TAudioClip;
  LFrames: Integer;
  LOffset: Integer;
  LIndex: Integer;
  LTones: TFrameTones;
begin
  if (ABlockFrames < 1) or (ABlockFrames > SynthStreamBlockFrames) then
  begin
    raise EAudio.Create('Caller streamed block size must be in 1..2048');
  end;
  LTones := MakeCallerTones(AFactory, ASeed);
  LStream := TFrameToneStream.Create(LTones, CallerExampleSampleRate, CallerExampleFrames, 3, 1024);
  try
    LChain := TEffectChain.Create(CallerExampleSampleRate);
    try
      LDelay := TCallerStereoDelay.Create(CallerExampleSampleRate, CallerExampleDelayFrames,
        AWet, AProbe);
      try
        LChain.Add(LDelay);
        LDelay := nil;
      finally
        LDelay.Free;
      end;
      LOffset := 0;
      SetLength(LResult, (CallerExampleFrames + CallerExampleDelayFrames) * 2);
      while LStream.ReadSamples(ABlockFrames, LBlock) do
      begin
        LInput := TAudioClip.Create(CallerExampleSampleRate, 2, LBlock);
        try
          { Continue one chain across blocks; never reset or append a tail here. }
          LProcessed := RenderEffectClip(LInput, LChain);
          try
            for LIndex := 0 to LProcessed.FrameCount - 1 do
            begin
              LResult[LOffset] := LProcessed.SampleAt(LIndex, 0);
              LResult[LOffset + 1] := LProcessed.SampleAt(LIndex, 1);
              Inc(LOffset, 2);
            end;
          finally
            LProcessed.Free;
          end;
        finally
          LInput.Free;
        end;
      end;
      LBlock := nil;
      LInput := TAudioClip.Create(CallerExampleSampleRate, 2, LBlock);
      try
        { Exactly one full finite delay tail after the complete source stream. }
        LProcessed := RenderEffectClip(LInput, LChain, CallerExampleDelayFrames);
        try
          LFrames := LProcessed.FrameCount;
          for LIndex := 0 to LFrames - 1 do
          begin
            LResult[LOffset] := LProcessed.SampleAt(LIndex, 0);
            LResult[LOffset + 1] := LProcessed.SampleAt(LIndex, 1);
            Inc(LOffset, 2);
          end;
        finally
          LProcessed.Free;
        end;
      finally
        LInput.Free;
      end;
      if LOffset <> Length(LResult) then
      begin
        raise EAudio.Create('Caller streamed output extent differs from its finite-tail contract');
      end;
      Result := TAudioClip.Create(CallerExampleSampleRate, 2, LResult);
    finally
      LChain.Free;
    end;
  finally
    LStream.Free;
  end;
end;

end.
