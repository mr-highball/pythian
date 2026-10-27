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
program pythian_tests_analysis_cooperative;
{$mode delphi}{$H+}
uses SysUtils, JS, pythian.audio, pythian.analysis, pythian.analysis.wave,
  pythian.wave.read, pythian.wave.stream, pythian.stream.bytes,
  pythian.analysis.cooperative;
type
  TDeferredCallback = procedure of object;
  TFailStream = class(TAudioBytesReadStream)
    FailRead: Boolean;
    function Read(ABuffer: TBytes; AOffset, ACount: LongInt): LongInt; override;
  end;
  TCollector = class(TAudioByteSink)
    Bytes: TAudioBytes;
    procedure WriteBytes(const ABytes: array of Byte); override;
  end;
  TTest = class
    Stream: TFailStream;
    EmptyStream: TFailStream;
    Reader, EmptyReader: TWaveFrameReader;
    Job: TCooperativeWaveAnalysis;
    Expected: TAudioFeatures;
    Options: TAnalysisOptions;
    Mode, Batches, FinishedCalls, Pulses: Integer;
    HostErrors: Integer;
    PulseTimer: JSValue;
    PulsePending: Boolean;
    constructor Create;
    destructor Destroy; override;
    procedure NextCase;
    procedure Batch(const AValue: TWaveFeatureBatch);
    procedure Finished(const AState: TCooperativeAnalysisState; const AError: String);
    procedure Pulse;
    procedure CancelTurn;
    procedure CheckDestroyed;
    procedure CheckFailureStable;
  end;
  TGlobalDeferredCallback = procedure;
  TUncaughtCallback = procedure(const AError: JSValue);
var Checks: Integer;
  Test: TTest;
function Defer(const ACallback: TDeferredCallback; const ADelay: Integer): JSValue;
  external name 'setTimeout';
procedure ClearDeferred(const ATimer: JSValue); external name 'clearTimeout';
function DeferCleanup(const ACallback: TGlobalDeferredCallback; const ADelay: Integer): JSValue;
  external name 'setTimeout';
procedure Cleanup; forward;
procedure OnUncaught(const AError: JSValue); forward;
procedure NodeOnce(const AEvent: String; const ACallback: TUncaughtCallback);
  external name 'process.once';
procedure Check(const ACondition: Boolean; const AMessage: String);
begin
  if not ACondition then raise Exception.Create(AMessage);
  Inc(Checks);
end;
procedure TCollector.WriteBytes(const ABytes: array of Byte);
var I, N: Integer;
begin
  N:=Length(Bytes); SetLength(Bytes,N+Length(ABytes));
  for I:=0 to High(ABytes) do Bytes[N+I]:=ABytes[I];
end;
function TFailStream.Read(ABuffer: TBytes; AOffset, ACount: LongInt): LongInt;
begin
  if FailRead then
  begin
    raise EAudio.Create('Authored reader failure');
  end;
  Result := inherited Read(ABuffer, AOffset, ACount);
end;
function MakeStream(const AFrames: Integer): TFailStream;
var C: TCollector; W: TWavePcm16Writer; S: TAudioSamples; I: Integer;
begin
  SetLength(S,AFrames);
  for I:=0 to High(S) do S[I]:=((I mod 64)-32)/128;
  C:=TCollector.Create;
  try
    W:=TWavePcm16Writer.Create(C,8000,1,AFrames);
    try W.AppendSamples(S); W.Finish finally W.Free end;
    Result:=TFailStream.Create(C.Bytes);
  finally C.Free end;
end;
constructor TTest.Create;
begin
  inherited Create;
  Mode:=-1;
  Options:=DefaultAnalysisOptions; Options.WindowFrames:=256; Options.HopFrames:=128;
  Stream:=MakeStream(2048); Reader:=TWaveFrameReader.Create(Stream);
  EmptyStream:=MakeStream(0); EmptyReader:=TWaveFrameReader.Create(EmptyStream);
  Expected:=AnalyzeWave(Reader,Options);
end;
destructor TTest.Destroy;
begin
  Job.Free; Reader.Free; Stream.Free; EmptyReader.Free; EmptyStream.Free;
  inherited Destroy;
end;
procedure TTest.NextCase;
var Invalid: TCooperativeWaveAnalysis; Rejected: Boolean;
begin
  FreeAndNil(Job); Inc(Mode); Batches:=0; FinishedCalls:=0; Pulses:=0;
  if Mode=7 then
  begin
    Reader.Free;
    Stream.FailRead := False;
    Stream.Position := 0;
    Reader := TWaveFrameReader.Create(Stream);
  end;
  if Mode=8 then
  begin
    Job:=TCooperativeWaveAnalysis.Create(Reader,Options,2,Batch,Finished);
    Job.Start; FreeAndNil(Job);
    Defer(CheckDestroyed,5);
    Exit;
  end;
  if (Mode=4) or (Mode=7) then
    Job:=TCooperativeWaveAnalysis.Create(EmptyReader,Options,2,Batch,Finished)
  else
    Job:=TCooperativeWaveAnalysis.Create(Reader,Options,2,Batch,Finished);
  if Mode=0 then
  begin
    Invalid:=nil; Rejected:=False;
    try Invalid:=TCooperativeWaveAnalysis.Create(Reader,Options,65,Batch,Finished)
    except on EAudio do Rejected:=True end;
    Invalid.Free;
    Check(Rejected,'Oversized turn rejected before scheduling');
  end;
  if Mode=6 then
  begin
    Stream.FailRead := True;
  end;
  if Mode=7 then
  begin
    NodeOnce('uncaughtException', OnUncaught);
  end;
  Job.Start;
  Check((Batches=0) and (FinishedCalls=0),'Start defers the first turn');
  Rejected:=False;
  try Job.Start except on EAudio do Rejected:=True end;
  Check(Rejected,'Second start rejects without replacing pending timer');
  if Mode=1 then Job.Cancel;
  if Mode=0 then begin PulseTimer:=Defer(Pulse,0); PulsePending:=True end;
end;
procedure TTest.Pulse;
begin
  PulsePending:=False; Inc(Pulses);
  if Job.State=casRunning then begin PulseTimer:=Defer(Pulse,0); PulsePending:=True end;
end;
procedure TTest.CancelTurn;
begin
  Job.Cancel;
end;
procedure TTest.Batch(const AValue: TWaveFeatureBatch);
var I,J,K: Integer;
begin
  Inc(Batches);
  Check(Length(AValue.Features)<=2,'Bounded feature storage per turn');
  Check(AValue.FirstFeature=Job.NextFeature,'Cursor commits after callback succeeds');
  if Mode=0 then
  begin
    if Batches>1 then Check(Pulses>0,'Unrelated timer executes between analysis turns');
    for I:=0 to High(AValue.Features) do
    begin
      J:=AValue.FirstFeature+I;
      Check(AValue.SourceStartFrame+AValue.Features[I].StartFrame=Expected[J].StartFrame,
        'Original source frame clock');
      Check(Abs(AValue.Features[I].Rms-Expected[J].Rms)<1e-10,'RMS parity');
      Check(Abs(AValue.Features[I].Flux-Expected[J].Flux)<1e-10,'Overlap flux parity');
      Check(Abs(AValue.Features[I].CentroidHz-Expected[J].CentroidHz)<1e-8,'Centroid parity');
      for K:=0 to 11 do Check(Abs(AValue.Features[I].Chroma[K]-Expected[J].Chroma[K])<1e-10,
        'Chroma parity');
    end;
  end;
  if Mode=2 then Defer(CancelTurn,0);
  if Mode=3 then raise Exception.Create('Authored host rejection');
  if Mode=4 then Check(AValue.Completed and (Length(AValue.Features)=0),'Empty terminal batch');
  if Mode=5 then Job.Cancel;
end;
procedure TTest.Finished(const AState: TCooperativeAnalysisState; const AError: String);
begin
  Inc(FinishedCalls); Check(FinishedCalls=1,'Exactly one terminal callback');
  Check(Job.State=AState,'Published terminal state agrees');
  case Mode of
    0: Check((AState=casCompleted) and (Job.NextFeature=Length(Expected)) and (Pulses>0),
         'Completion follows yielded parity batches');
    1: Check((AState=casCancelled) and (Batches=0) and (Job.NextFeature=0),'Cancel before first read');
    2: Check((AState=casCancelled) and (Batches=1) and (Job.NextFeature=2),
         'External timer cancels before next analysis batch');
    3: Check((AState=casFailed) and (Batches=1) and (Job.NextFeature=0) and
         (AError='Authored host rejection'),'Failed host publication preserves cursor');
    4: Check((AState=casCompleted) and (Batches=1) and (Job.NextFeature=0),'Empty completion deferred');
    5: Check((AState=casCancelled) and (Batches=1) and (Job.NextFeature=2),
         'Callback cancellation commits only its completed batch');
    6: Check((AState=casFailed) and (Batches=0) and (Job.NextFeature=0) and
         (AError='Authored reader failure') and Reader.Failed,
         'Reader failure poisons borrowed reader and publishes no batch');
    7: Check((AState=casCompleted) and (Batches=1), 'Terminal callback begins once');
  end;
  if (Mode<>3) and (Mode<>6) then Check(AError='','Successful/cancelled job has no failure text');
  if PulsePending then begin ClearDeferred(PulseTimer); PulsePending:=False end;
  if Mode=7 then
  begin
    raise Exception.Create('Terminal callback failure');
  end;
  if (Mode=3) or (Mode=6) then
  begin
    Defer(CheckFailureStable,5);
  end
  else
  begin
    Defer(NextCase,0);
  end;
end;
procedure TTest.CheckFailureStable;
begin
  Check((Job.State=casFailed) and (FinishedCalls=1) and
    ((Mode=7) or (Job.NextFeature=0)),
    'Failure remains terminal without a later success or cursor advance');
  if Mode=6 then
  begin
    Check(Reader.Failed and (Batches=0), 'Reader remains poisoned with no later batch');
  end;
  NextCase;
end;
procedure TTest.CheckDestroyed;
begin
  Check((Batches=0) and (FinishedCalls=0),'Destroy clears pending timer and callbacks');
  Check(HostErrors=1, 'Terminal failure reaches host exactly once');
  WriteLn('PASS ',Checks,' cooperative scheduling, parity, cancellation and publication checks');
  { Terminal cleanup is itself deferred so no callback frees its own receiver. }
  DeferCleanup(Cleanup,0);
end;
procedure OnUncaught(const AError: JSValue);
begin
  Inc(Test.HostErrors);
  Check((Test.Job.State=casFailed) and (Test.Job.ErrorMessage='Terminal callback failure') and
    (Test.FinishedCalls=1) and (Test.Batches=1),
    'Terminal callback error reaches host and cannot publish success again');
  Check(String(TJSObject(AError)['fMessage'])='Terminal callback failure',
    'Host receives the original terminal exception');
  Defer(Test.CheckFailureStable,5);
end;
procedure Cleanup;
begin
  FreeAndNil(Test);
end;
begin
  Test:=TTest.Create; Test.NextCase;
end.
