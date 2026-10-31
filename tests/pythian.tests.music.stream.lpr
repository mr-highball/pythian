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
program InstrumentMusicStreamConformance;

{$mode delphi}
{$H+}

uses SysUtils, Math, pythian.audio, pythian.source, pythian.synth,
  pythian.instrument, pythian.bus, pythian.echo, pythian.chord,
  pythian.music.stream, pythian.progress;

type
  TProbeFactory = class;
  TProbeSource = class(TAudioSource)
    Factory: TProbeFactory;
    Frames: Integer;
    constructor Create(const AFactory: TProbeFactory);
    destructor Destroy; override;
    procedure Reset; override;
    procedure NoteOff; override;
    function ReadFrame(const AFrequencyHz: Double; out ALeft, ARight: Double): Boolean; override;
  end;
  TProbeFactory = class(TAudioSourceFactory)
    Created: Integer;
    Destroyed: Integer;
    OffCount: Integer;
    OffFrame: Integer;
    Fail: Boolean;
    Cost: Integer;
    function CreateSource(const ASampleRate: Integer; const ASeed: Cardinal): TAudioSource; override;
    function FrameCost(const ASampleRate: Integer): Integer; override;
    function Channels: Integer; override;
  end;
  TObserver = class
    Stream: TInstrumentMusicStream;
    AbortStage: String;
    Reenter: Boolean;
    Rejected: Integer;
    procedure Receive(const AProgress: TWorkProgress);
  end;

var
  GChecks: Integer;

procedure Check(const AValue: Boolean; const AMessage: String);
begin
  Inc(GChecks);
  if not AValue then raise Exception.Create(AMessage);
end;

constructor TProbeSource.Create(const AFactory: TProbeFactory);
begin
  inherited Create;
  Factory := AFactory;
  Inc(Factory.Created);
end;

destructor TProbeSource.Destroy;
begin
  Inc(Factory.Destroyed);
  inherited Destroy;
end;

procedure TProbeSource.Reset;
begin
  Frames := 0;
end;

procedure TProbeSource.NoteOff;
begin
  Inc(Factory.OffCount);
  Factory.OffFrame := Frames;
end;

function TProbeSource.ReadFrame(const AFrequencyHz: Double;
  out ALeft, ARight: Double): Boolean;
begin
  Inc(Frames);
  ALeft := Sin(Frames * 0.17) * 0.1;
  ARight := ALeft * 0.5;
  Result := True;
end;

function TProbeFactory.CreateSource(const ASampleRate: Integer;
  const ASeed: Cardinal): TAudioSource;
begin
  Result := nil;
  if not Fail then Result := TProbeSource.Create(Self);
end;

function TProbeFactory.FrameCost(const ASampleRate: Integer): Integer;
begin
  Result := Max(1, Cost);
end;

function TProbeFactory.Channels: Integer;
begin
  Result := 2;
end;

procedure TObserver.Receive(const AProgress: TWorkProgress);
begin
  if Reenter then
  begin
    try
      Stream.Stop;
      raise Exception.Create('Reentrant Stop accepted');
    except
      on EAudio do Inc(Rejected);
    end;
  end;
  if AProgress.Stage = AbortStage then raise EAudio.Create('Caller cancelled');
end;

function Graph(const ARate: Integer; const AEcho: Boolean = False): TBusGraph;
var
  LSettings: array[0..0] of TBusSettings;
  LEcho: TEchoSettings;
begin
  LSettings[0] := DefaultBusSettings;
  Result := TBusGraph.Create(ARate, LSettings);
  if AEcho then
  begin
    LEcho := DefaultEchoSettings(ARate);
    LEcho.DelayFrames := 47;
    LEcho.Feedback := 0.65;
    LEcho.WetGain := 0.3;
    Result.AddEffect(0, TEchoEffect.Create(ARate, LEcho));
  end;
end;

function Instrument(const AFactory: TAudioSourceFactory = nil): TInstrument;
var
  LZone: TInstrumentZone;
begin
  LZone := Default(TInstrumentZone);
  LZone.MaximumKey := 127;
  LZone.MinimumVelocity := 1;
  LZone.MaximumVelocity := 127;
  LZone.Voice := DefaultSynthVoice;
  LZone.Voice.SourceFactory := AFactory;
  LZone.Voice.Envelope.AttackSeconds := 0.002;
  LZone.Voice.Envelope.DecaySeconds := 0.003;
  LZone.Voice.Envelope.SustainLevel := 0.6;
  LZone.Voice.Envelope.ReleaseSeconds := 0.005;
  Result := TInstrument.Create([LZone]);
end;

function Binding(const AInstrument: TInstrument; const AGate: Int64 = 0): TInstrumentStreamBinding;
begin
  Result := Default(TInstrumentStreamBinding);
  Result.Instrument := AInstrument;
  Result.MaximumTones := 1;
  Result.GateFrames := AGate;
end;

function Frame(const AAction: TChordAction): TChordFrame;
begin
  Result := nil;
  SetLength(Result, 1);
  Result[0].Action := AAction;
  if AAction <> caRest then
  begin
    SetLength(Result[0].Tones, 1);
    Result[0].Tones[0].Pitch := 60;
    Result[0].Tones[0].Velocity := 90;
  end;
end;

function Render(const ASplit: Boolean; const APull: Integer): TAudioSamples;
var
  LInstrument: TInstrument;
  LGraph: TBusGraph;
  LStream: TInstrumentMusicStream;
  LOptions: TInstrumentStreamOptions;
  LSamples: TAudioSamples;
  LFrame: TChordFrame;
  LAt, I: Integer;
begin
  Result := nil;
  LInstrument := Instrument;
  LGraph := Graph(8000, True);
  LOptions := DefaultInstrumentStreamOptions(1600);
  LOptions.TailFrames := 400;
  LStream := TInstrumentMusicStream.Create([Binding(LInstrument)], LGraph, LOptions);
  try
    SetLength(Result, 4000);
    LAt := 0;
    while LStream.State = issReady do
    begin
      if LStream.NeedsInput then
      begin
        if LStream.AdmittedFrames = 0 then
        begin
          LFrame := Frame(caAttack);
          if ASplit then LStream.AdmitFrame(LFrame, 320)
          else LStream.AdmitFrame(LFrame, 1600);
          { Caller-owned nested arrays must not become retained stream state. }
          LFrame[0].Tones[0].Pitch := 72;
        end
        else LStream.AdmitFrame(Frame(caHold), 640);
      end;
      if LStream.ReadSamples(APull, LSamples) then
      begin
        Check(Length(LSamples) <= InstrumentStreamBlockFrames * 2, 'Bounded PCM block');
        for I := 0 to High(LSamples) do
        begin
          Result[LAt] := LSamples[I];
          Inc(LAt);
        end;
      end;
    end;
    Check((LStream.State = issCompleted) and (LAt = Length(Result)) and
      (LStream.Position = 2000), 'Exact music plus release/effect tail extent');
  finally
    LStream.Free;
    LGraph.Free;
    LInstrument.Free;
  end;
end;

procedure Continuity;
var
  LWhole, LSplit, LPulls: TAudioSamples;
  I: Integer;
  LEnergy: Double;
begin
  LWhole := Render(False, 2048);
  LSplit := Render(True, 173);
  LPulls := Render(True, 1);
  LEnergy := 0;
  for I := 0 to High(LWhole) do
  begin
    Check((LWhole[I] = LSplit[I]) and (LWhole[I] = LPulls[I]),
      'Holds, oscillators, envelopes and echo survive planning/pull boundaries exactly');
    if I >= 3280 then LEnergy := LEnergy + Abs(LWhole[I]);
  end;
  Check(LEnergy > 0.0001, 'Real echo history sounds after note release');
end;

procedure OneShots;
var
  LFactory: TProbeFactory;
  LInstrument: TInstrument;
  LGraph: TBusGraph;
  LStream: TInstrumentMusicStream;
  LSamples: TAudioSamples;
begin
  LFactory := TProbeFactory.Create;
  LInstrument := Instrument(LFactory);
  LGraph := Graph(8000);
  LStream := TInstrumentMusicStream.Create([Binding(LInstrument, 200)], LGraph,
    DefaultInstrumentStreamOptions(400));
  try
    LStream.AdmitFrame(Frame(caAttack), 100);
    while LStream.ReadSamples(41, LSamples) do ;
    LStream.AdmitFrame(Frame(caRest), 300);
    while LStream.ReadSamples(31, LSamples) do ;
    Check((LFactory.Created = 1) and (LFactory.OffCount = 1) and
      (LFactory.OffFrame = 200), 'A percussion rest does not choke the previous one-shot');
    Check(LFactory.Destroyed = 1, 'Natural one-shot and release retire their playback source');
  finally
    LStream.Free;
    LGraph.Free;
    LInstrument.Free;
    LFactory.Free;
  end;
end;

procedure AdmissionAndControl;
var
  LFactory, LBadFactory: TProbeFactory;
  LInstrument, LBadInstrument: TInstrument;
  LGraph: TBusGraph;
  LStream: TInstrumentMusicStream;
  LObserver: TObserver;
  LFrame: TChordFrame;
  LSamples: TAudioSamples;
  LRejected: Boolean;
  LBefore: Int64;
begin
  LFactory := TProbeFactory.Create;
  LBadFactory := TProbeFactory.Create;
  LInstrument := Instrument(LFactory);
  LBadInstrument := Instrument(LBadFactory);
  LGraph := Graph(8000);
  LObserver := TObserver.Create;
  LStream := TInstrumentMusicStream.Create([Binding(LInstrument), Binding(LBadInstrument)],
    LGraph, DefaultInstrumentStreamOptions(1000));
  LObserver.Stream := LStream;
  try
    LFrame := Frame(caAttack);
    SetLength(LFrame, 2);
    LStream.AdmitFrame(LFrame, 320);
    while LStream.ReadSamples(173, LSamples) do ;
    LFrame[1] := Frame(caAttack)[0];
    LBadFactory.Fail := True;
    LRejected := False;
    try LStream.AdmitFrame(LFrame, 320);
    except on EAudio do LRejected := True end;
    Check(LRejected and LStream.NeedsInput and (LStream.AdmittedFrames = 320) and
      (LStream.State = issReady), 'A failed second layer preserves the musical cursor');
    Check((LFactory.Created = 2) and (LFactory.Destroyed = 1) and
      (LFactory.OffCount = 0), 'Failed multi-instrument admission preserves the sounding predecessor');
    LBadFactory.Fail := False;
    LObserver.AbortStage := 'schedule_batch_ready';
    LRejected := False;
    try LStream.AdmitFrame(LFrame, 320, LObserver.Receive);
    except on EAudio do LRejected := True end;
    Check(LRejected and (LStream.AdmittedFrames = 320) and (LFactory.OffCount = 0),
      'Cancelled source staging does not release the current sound');
    LObserver.AbortStage := '';
    LObserver.Reenter := True;
    LStream.AdmitFrame(LFrame, 320, LObserver.Receive);
    Check(LObserver.Rejected > 0, 'Admission callbacks cannot stop or reenter the stream');
    LObserver.Reenter := False;
    Check(LStream.ReadSamples(17, LSamples), 'Admitted audio can be pulled');
    LBefore := LStream.Position;
    LStream.Pause;
    Check(not LStream.ReadSamples(17, LSamples) and (LSamples = nil) and
      (LStream.Position = LBefore), 'Pause freezes the clock and returns no PCM');
    LStream.Resume;
    Check(LStream.ReadSamples(17, LSamples) and (LStream.Position = LBefore + 17),
      'Resume continues the same source and clock');
    LStream.Stop;
    Check((LStream.State = issStopped) and (LStream.Voices = 0) and
      not LStream.ReadSamples(17, LSamples), 'Stop discards future output and releases owned voices');
    Check((LFactory.Created = LFactory.Destroyed) and
      (LBadFactory.Created = LBadFactory.Destroyed), 'Staging, cancellation and Stop leave no sources');
  finally
    LStream.Free;
    LObserver.Free;
    LGraph.Free;
    LInstrument.Free;
    LBadInstrument.Free;
    LFactory.Free;
    LBadFactory.Free;
  end;
end;

procedure LongClockAndFailure;
var
  LInstrument: TInstrument;
  LGraph: TBusGraph;
  LStream: TInstrumentMusicStream;
  LOptions: TInstrumentStreamOptions;
  LObserver: TObserver;
  LSamples: TAudioSamples;
  LRejected: Boolean;
begin
  LInstrument := Instrument;
  LGraph := Graph(48000);
  LOptions := DefaultInstrumentStreamOptions(Int64(48000) * 86400);
  LOptions.TailFrames := 48000;
  LObserver := TObserver.Create;
  LStream := TInstrumentMusicStream.Create([Binding(LInstrument)], LGraph, LOptions);
  LObserver.Stream := LStream;
  try
    LRejected := False;
    try LStream.AdmitFrame(Frame(caAttack), 0);
    except on EAudio do LRejected := True end;
    Check(LRejected and LStream.NeedsInput, 'An empty interval cannot bypass musical progress');
    LStream.AdmitFrame(Frame(caAttack), LOptions.MusicFrames);
    Check((LStream.FrameCount = Int64(4147248000)) and (LStream.Voices = 1),
      'A24-hour gate plus release uses exact wide clocks and one live voice');
    Check(LStream.ReadSamples(65536, LSamples) and
      (Length(LSamples) <= InstrumentStreamBlockFrames * 2),
      'Long planning never allocates full-duration PCM');
    LObserver.AbortStage := 'instrument_stream_ready';
    LRejected := False;
    try LStream.ReadSamples(512, LSamples, LObserver.Receive);
    except on EAudio do LRejected := True end;
    Check(LRejected and (LStream.State = issFailed) and (LSamples = nil) and
      (LStream.Position = InstrumentStreamBlockFrames),
      'Cancelled post-render publication is terminal and exposes no partial failed block');
    LRejected := False;
    try LStream.ReadSamples(1, LSamples);
    except on EAudio do LRejected := True end;
    Check(LRejected, 'Failed processing cannot silently resume with an advanced source');
  finally
    LStream.Free;
    LObserver.Free;
    LGraph.Free;
    LInstrument.Free;
  end;
end;

procedure CombinedWorkLimit;
var
  LFactory: TProbeFactory;
  LInstrument: TInstrument;
  LGraph: TBusGraph;
  LStream: TInstrumentMusicStream;
  LOptions: TInstrumentStreamOptions;
  LSamples: TAudioSamples;
  LRejected: Boolean;
begin
  LFactory := TProbeFactory.Create;
  LFactory.Cost := MaximumRenderVisits - 16;
  LInstrument := Instrument(LFactory);
  LGraph := Graph(8000);
  LOptions := DefaultInstrumentStreamOptions(1000);
  LOptions.WorkLimit := MaximumRenderVisits;
  LStream := TInstrumentMusicStream.Create([Binding(LInstrument)], LGraph, LOptions);
  try
    LStream.AdmitFrame(Frame(caAttack), 1000);
    LRejected := False;
    try LStream.ReadSamples(1, LSamples);
    except on EAudio do LRejected := True end;
    Check(LRejected and (LStream.State = issFailed) and (LStream.Position = 0) and
      (LSamples = nil), 'Voice plus bus work cannot bypass the pull budget by forcing one frame');
  finally
    LStream.Free;
    LGraph.Free;
    LInstrument.Free;
    LFactory.Free;
  end;
end;

begin
  Continuity;
  OneShots;
  AdmissionAndControl;
  LongClockAndFailure;
  CombinedWorkLimit;
  WriteLn('PASS ', GChecks, ' continuous instrument stream checks');
end.
