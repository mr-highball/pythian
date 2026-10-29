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
program JournalRenderProgress;
{$mode delphi}
{$H+}
uses SysUtils, pythian.audio, pythian.progress, pythian.wave, pythian.hash,
  pythian.learning, pythian.learning.journal, pythian.learning.selection,
  pythian.learning.context, pythian.learning.render.stream;
type
  { One distinct exception instance must reach the caller unchanged. }
  EObserverAbort = class(Exception);
  { Owned callback trace, with no dependency on threads, browser or platform I/O. }
  TWorkTrace = array of TWorkProgress;
  { Deterministic source/output receiver and borrowed progress observer. }
  TProbe = class
    Stream: TJournalAudioRenderStream;
    Channels: Integer;
    Samples: TAudioSamples;
    Trace: TWorkTrace;
    Reads: Integer;
    FailAt: Integer;
    Raised: EObserverAbort;
    Reenter: Boolean;
    FaultRead: Boolean;
    FaultWrite: Boolean;
    Rejections: Integer;
    procedure CheckReentry;
    function ReadWindow(const C: TJournalRepresentative): TAudioSamples;
    procedure WriteAudio(const A: array of Single);
    procedure Observe(const P: TWorkProgress);
  end;
var Checks,Aborts: Integer;
procedure Check(const V: Boolean; const Why: String);
begin
  if not V then raise EAudio.Create(Why);
  Inc(Checks);
end;
procedure TProbe.CheckReentry;
var A: TAcousticIndices; W: TJournalContextWindows; Rejected: Boolean;
begin
  if not Reenter or (Stream=nil) then Exit;
  Rejected:=False;
  try Stream.Finish; except on E:EAudio do Rejected:=True; end;
  Check(Rejected,'Finish reentry accepted'); Inc(Rejections);
  SetLength(A,1);A[0]:=0;Rejected:=False;
  try Stream.AppendSelection(A);except on E:EAudio do Rejected:=True;end;
  Check(Rejected,'Selection reentry accepted');Inc(Rejections);
  SetLength(W,0);Rejected:=False;
  try Stream.AppendWindows(W);except on E:EAudio do Rejected:=True;end;
  Check(Rejected,'Window reentry accepted');Inc(Rejections);
end;
function TProbe.ReadWindow(const C:TJournalRepresentative):TAudioSamples;
var I:Integer;
begin
  CheckReentry;Inc(Reads);
  if FaultRead then
  begin Raised:=EObserverAbort.Create('original-source-error');raise Raised;end;
  SetLength(Result,C.ValidFrames*Channels);
  for I:=0 to High(Result) do Result[I]:=(C.FeatureIndex+1)*((I mod 17)-8)/512;
end;
procedure TProbe.WriteAudio(const A:array of Single);
var At,I:Integer;
begin
  CheckReentry;
  if FaultWrite then
  begin Raised:=EObserverAbort.Create('original-output-error');raise Raised;end;
  At:=Length(Samples);SetLength(Samples,At+Length(A));
  for I:=0 to High(A) do Samples[At+I]:=A[I];
end;
procedure TProbe.Observe(const P:TWorkProgress);
var N:Integer;
begin
  CheckReentry;
  Check((P.Done>=0) and (P.Total>0) and (P.Done<=P.Total),'Invalid progress counter');
  if (P.Stage='journal_render_preflight') or (P.Stage='journal_render_grains') then
    Check(P.Units=wuItems,'Expected item unit')
  else Check(P.Units=wuFrames,'Expected frame unit');
  if P.Stage='journal_render_output' then
    Check(P.Done*Channels=Length(Samples),'Output progress precedes successful output');
  N:=Length(Trace);SetLength(Trace,N+1);Trace[N]:=P;
  if (FailAt>0) and (Length(Trace)=FailAt) then
  begin
    Raised:=EObserverAbort.Create('original-render-observer-abort');raise Raised;
  end;
end;
function PoolFor(const WindowFrames:Integer):TJournalCandidatePool;
var A:TJournalRepresentatives;I:Integer;
begin
  SetLength(A,4);
  for I:=0 to 3 do
  begin
    A[I].Found:=True;A[I].SegmentIndex:=I div 2;A[I].FeatureIndex:=I;
    A[I].SourceFrame:=I*WindowFrames;A[I].ValidFrames:=WindowFrames;
  end;
  Result:=TJournalCandidatePool.CreateFromCandidates(1,2,2,A);
end;
procedure Selection(const Count:Integer;out A:TAcousticIndices;out W:TJournalContextWindows;
  const Pool:TJournalCandidatePool);
var I:Integer;
begin
  SetLength(A,Count);SetLength(W,Count);
  for I:=0 to Count-1 do
  begin A[I]:=I mod 4;W[I].Token:=0;W[I].Candidate:=Pool.CandidateAt(A[I]);end;
end;
procedure SameSamples(const A,B:TAudioSamples);
var I:Integer;
begin
  Check(Length(A)=Length(B),'Output sample count drift');
  for I:=0 to High(A) do Check(A[I]=B[I],'Observer changed output samples');
end;
function Complete(const Pool:TJournalCandidatePool;const Channels,WindowFrames,Hop,
  Grains,BlockFrames,Trim:Integer;const Explicit,Observed,Reentry:Boolean;
  out Trace:TWorkTrace):TAudioSamples;
var P:TProbe;A:TAcousticIndices;W:TJournalContextWindows;CB:TWorkProgressCallback;
begin
  P:=TProbe.Create;
  try
    P.Channels:=Channels;P.Reenter:=Reentry;
    P.Stream:=TJournalAudioRenderStream.Create(Pool,P.ReadWindow,P.WriteAudio,
      Channels,WindowFrames,Hop,Grains,BlockFrames,Trim);
    try
      Selection(Grains,A,W,Pool);CB:=nil;if Observed then CB:=P.Observe;
      if Explicit then P.Stream.AppendWindows(W,CB) else P.Stream.AppendSelection(A,CB);
      P.Stream.Finish(CB);
      Check(P.Stream.Finished and not P.Stream.Failed,'Successful renderer terminal state');
      Check(P.Stream.FlushedFrames=Length(P.Samples) div Channels,'Output clock mismatch');
      if Observed then Check(Length(P.Trace)>0,'Missing observer events');
      if Reentry then Check(P.Rejections>0,'No mutating reentry exercised');
      Trace:=P.Trace;Result:=P.Samples;
    finally P.Stream.Free;P.Stream:=nil;end;
  finally P.Free;end;
end;
procedure AbortEvery(const Explicit:Boolean);
var Pool:TJournalCandidatePool;Expected,Actual:TAudioSamples;Trace,Ignored:TWorkTrace;
  P:TProbe;A:TAcousticIndices;W:TJournalContextWindows;I:Integer;Caught,Rejected:Boolean;
begin
  Pool:=PoolFor(2048);
  try
    Expected:=Complete(Pool,2,2048,512,3,257,3069,Explicit,True,False,Trace);
    for I:=1 to Length(Trace) do
    begin
      P:=TProbe.Create;
      try
        P.Channels:=2;P.FailAt:=I;
        P.Stream:=TJournalAudioRenderStream.Create(Pool,P.ReadWindow,P.WriteAudio,2,2048,512,3,257,3069);
        try
          Selection(3,A,W,Pool);Caught:=False;
          try
            if Explicit then P.Stream.AppendWindows(W,P.Observe)
            else P.Stream.AppendSelection(A,P.Observe);
            P.Stream.Finish(P.Observe);
          except
            on E:EObserverAbort do begin Check(E=P.Raised,'Observer exception identity replaced');Caught:=True;end;
          end;
          P.Raised:=nil;Check(Caught,'Observer checkpoint not reached');Inc(Aborts);
          if Trace[I-1].Stage='journal_render_preflight' then
          begin
            Check(not P.Stream.Failed and not P.Stream.Finished,'Preflight abort poisoned state');
            Check((P.Stream.GrainCount=0) and (P.Stream.FlushedFrames=0) and
              (Length(P.Samples)=0) and (P.Reads=0),'Preflight abort changed state/output');
            P.FailAt:=0;
            if Explicit then P.Stream.AppendWindows(W) else P.Stream.AppendSelection(A);
            P.Stream.Finish;SameSamples(Expected,P.Samples);
          end
          else
          begin
            Check(P.Stream.Failed and not P.Stream.Finished,'Post-preflight abort did not poison renderer');
            Rejected:=False;try P.Stream.Finish;except on E:EAudio do Rejected:=True;end;
            Check(Rejected,'Failed Finish accepted');
            Rejected:=False;try P.Stream.AppendSelection(A);except on E:EAudio do Rejected:=True;end;
            Check(Rejected,'Failed append accepted');
          end;
        finally P.Stream.Free;P.Stream:=nil;end;
      finally P.Free;end;
      Actual:=Complete(Pool,2,2048,512,3,257,3069,Explicit,False,False,Ignored);
      SameSamples(Expected,Actual);
    end;
  finally Pool.Free;end;
end;
procedure Constructors;
var Pool:TJournalCandidatePool;P:TProbe;I:Integer;Caught:Boolean;
begin
  Pool:=PoolFor(2048);
  try
    for I:=1 to 4 do
    begin
      P:=TProbe.Create;
      try
        P.Channels:=1;P.FailAt:=I;P.Stream:=nil;Caught:=False;
        try P.Stream:=TJournalAudioRenderStream.Create(Pool,P.ReadWindow,P.WriteAudio,
          1,2048,512,3,257,0,P.Observe);
        except on E:EObserverAbort do begin Check(E=P.Raised,'Constructor exception changed');Caught:=True;end;end;
        P.Raised:=nil;Check(Caught and (P.Stream=nil),'Constructor abort published renderer');Inc(Aborts);
        Check((P.Reads=0) and (Length(P.Samples)=0),'Constructor touched source/output');
      finally P.Stream.Free;P.Free;end;
    end;
  finally Pool.Free;end;
end;
procedure CopyControls;
var A,B,Saved:TAudioSamples;I,J:Integer;Rejected:Boolean;
begin
  SetLength(A,8);for I:=0 to 7 do A[I]:=I+0.25;
  B:=A;CopyAudioSampleRange(A,0,B,2,6);
  for I:=0 to 5 do Check(B[I+2]=I+0.25,'Shared-array backward copy');
  for I:=0 to 7 do A[I]:=I+0.25;
  CopyAudioSampleRange(A,2,A,0,6);
  for I:=0 to 5 do Check(A[I]=I+2.25,'In-place forward copy');
  Saved:=Copy(A);
  for J:=0 to 8 do
  begin
    Rejected:=False;
    try
      case J of
        0:CopyAudioSampleRange(A,-1,A,0,1);
        1:CopyAudioSampleRange(A,0,A,-1,1);
        2:CopyAudioSampleRange(A,0,A,0,-1);
        3:CopyAudioSampleRange(A,8,A,0,1);
        4:CopyAudioSampleRange(A,0,A,8,1);
        5:CopyAudioSampleRange(A,High(Integer),A,0,High(Integer));
        6:CopyAudioSampleRange(A,Low(Integer),A,0,1);
        7:CopyAudioSampleRange(A,0,A,Low(Integer),1);
        8:CopyAudioSampleRange(A,0,A,0,Low(Integer));
      end;
    except on E:EAudio do Rejected:=True;end;
    Check(Rejected,'Invalid copy range accepted');SameSamples(Saved,A);
  end;
  CopyAudioSampleRange(A,8,A,8,0);SameSamples(Saved,A);
  SetLength(B,8);CopyAudioSampleRange(A,0,B,0,8);SameSamples(A,B);
end;
procedure VariantControls;
var Pool:TJournalCandidatePool;A,B:TAudioSamples;Trace,Ignored:TWorkTrace;
  C,I:Integer;Clip:TAudioClip;Bytes:TAudioBytes;Saw128,Saw256:Boolean;
  SawSource,SawMixInterior,SawFlushInterior,SawOutput,SawGrains,SawComplete:Boolean;
begin
  Pool:=PoolFor(2048);
  try
    for C:=1 to 2 do
    begin
      A:=Complete(Pool,C,2048,512,3,257,3069,False,False,False,Ignored);
      B:=Complete(Pool,C,2048,512,3,17,3069,True,True,True,Trace);SameSamples(A,B);
      SawSource:=False;SawMixInterior:=False;SawFlushInterior:=False;
      SawOutput:=False;SawGrains:=False;SawComplete:=False;
      for I:=0 to High(Trace) do
      begin
        if Trace[I].Stage='journal_render_source' then SawSource:=SawSource or (Trace[I].Done=2048);
        if Trace[I].Stage='journal_render_mix' then SawMixInterior:=SawMixInterior or (Trace[I].Done=1024);
        if Trace[I].Stage='journal_render_flush' then SawFlushInterior:=SawFlushInterior or (Trace[I].Done=2048);
        if Trace[I].Stage='journal_render_output' then SawOutput:=SawOutput or (Trace[I].Done=3069);
        if Trace[I].Stage='journal_render_grains' then SawGrains:=SawGrains or (Trace[I].Done=3);
        if Trace[I].Stage='journal_render_complete' then SawComplete:=SawComplete or (Trace[I].Done=3069);
      end;
      Check(SawSource and SawMixInterior and SawFlushInterior,'Missing source/mix/flush interior work');
      Check(SawOutput and SawGrains and SawComplete,'Missing final output/grain/completion work');
      Clip:=TAudioClip.Create(8000,C,A);
      try Bytes:=EncodeWavePcm16(Clip);finally Clip.Free;end;
      WriteLn('PCM',C,'=',Sha256Bytes(Bytes));
    end;
  finally Pool.Free;end;
  Pool:=PoolFor(8);
  try
    A:=Complete(Pool,1,8,4,257,97,0,False,True,False,Trace);
    Saw128:=False;Saw256:=False;
    for I:=0 to High(Trace) do
      if Trace[I].Stage='journal_render_preflight' then
      begin Saw128:=Saw128 or (Trace[I].Done=128);Saw256:=Saw256 or (Trace[I].Done=256);end;
    Check(Saw128 and Saw256,'Missing interior preflight checkpoints');
    B:=Complete(Pool,1,8,4,257,13,0,True,False,False,Ignored);SameSamples(A,B);
  finally Pool.Free;end;
end;

procedure InvalidAndIOControls;
var Pool:TJournalCandidatePool;P:TProbe;A:TAcousticIndices;W:TJournalContextWindows;
  Mode:Integer;Rejected:Boolean;Expected:TAudioSamples;Ignored:TWorkTrace;

  procedure RejectGeometry(const C,Window,Hop,Grains,BlockSize,Trim:Integer);
  var S:TJournalAudioRenderStream;Failed:Boolean;
  begin
    S:=nil;Failed:=False;
    try
      try S:=TJournalAudioRenderStream.Create(Pool,P.ReadWindow,P.WriteAudio,
        C,Window,Hop,Grains,BlockSize,Trim);
      except on E:EAudio do Failed:=True;end;
      Check(Failed,'Invalid renderer geometry accepted');
      Check((P.Reads=0) and (Length(P.Samples)=0),'Invalid geometry touched I/O');
    finally S.Free;end;
  end;

begin
  Pool:=PoolFor(8);
  try
    P:=TProbe.Create;
    try
      P.Channels:=1;
      RejectGeometry(3,8,4,3,3,0);RejectGeometry(1,0,4,3,3,0);
      RejectGeometry(1,8,9,3,3,0);RejectGeometry(1,8,4,0,3,0);
      RejectGeometry(1,8,4,3,0,0);RejectGeometry(1,8,4,3,3,12);
      Rejected:=False;
      try JournalStreamFrames(65536,65536,High(Int64));except on E:EAudio do Rejected:=True;end;
      Check(Rejected,'Output clock overflow accepted');
      P.Stream:=TJournalAudioRenderStream.Create(Pool,P.ReadWindow,P.WriteAudio,1,8,4,3,3);
      try
        Selection(2,A,W,Pool);A[1]:=4;Rejected:=False;
        try P.Stream.AppendSelection(A,P.Observe);except on E:EAudio do Rejected:=True;end;
        Check(Rejected and not P.Stream.Failed,'Invalid slot poisoned renderer');
        W[1].Candidate.SegmentIndex:=2;Rejected:=False;
        try P.Stream.AppendWindows(W,P.Observe);except on E:EAudio do Rejected:=True;end;
        Check(Rejected and not P.Stream.Failed,'Invalid explicit window poisoned renderer');
        Check((P.Reads=0) and (Length(P.Samples)=0) and (P.Stream.GrainCount=0),
          'Invalid preflight changed source/output/clock');
        Selection(3,A,W,Pool);P.Stream.AppendSelection(A);P.Stream.Finish;
        Expected:=Complete(Pool,1,8,4,3,3,0,False,False,False,Ignored);
        SameSamples(Expected,P.Samples);
      finally P.Stream.Free;P.Stream:=nil;end;
    finally P.Free;end;

    for Mode:=0 to 1 do
    begin
      P:=TProbe.Create;
      try
        P.Channels:=1;P.FaultRead:=Mode=0;P.FaultWrite:=Mode=1;
        P.Stream:=TJournalAudioRenderStream.Create(Pool,P.ReadWindow,P.WriteAudio,1,8,4,3,3);
        try
          Selection(3,A,W,Pool);Rejected:=False;
          try P.Stream.AppendWindows(W,P.Observe);
          except on E:EObserverAbort do begin Check(E=P.Raised,'I/O exception identity changed');Rejected:=True;end;end;
          P.Raised:=nil;
          Check(Rejected and P.Stream.Failed and not P.Stream.Finished,'I/O error not terminal');
          Check(Length(P.Samples)=0,'Failed first output published sample data');
          Rejected:=False;try P.Stream.Finish;except on E:EAudio do Rejected:=True;end;
          Check(Rejected,'Failed I/O silently resumed');
        finally P.Stream.Free;P.Stream:=nil;end;
      finally P.Free;end;
    end;
  finally Pool.Free;end;
end;
begin
  try
    CopyControls;Constructors;VariantControls;InvalidAndIOControls;
    AbortEvery(False);AbortEvery(True);
    WriteLn('PASS journal render progress checks=',Checks,' aborts=',Aborts);
  except on E:Exception do begin WriteLn('FAIL ',E.ClassName,': ',E.Message);ExitCode:=1;end;end;
end.
