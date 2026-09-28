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
program pythian_tests_journal_selection_stream;
{$mode delphi}{$H+}
uses SysUtils, Math, pythian.audio, pythian.learning,
  pythian.learning.journal, pythian.learning.selection;

procedure Check(const AOk: Boolean; const AWhy: String);
begin
  if not AOk then raise EAudio.Create(AWhy);
end;

function MakePool: TJournalCandidatePool;
var LSlots: TJournalRepresentatives; LToken,LSegment,LBin,LSlot: Integer;
begin
  SetLength(LSlots,3*3*4);
  for LToken:=0 to 1 do
    for LSegment:=0 to 1 do
      for LBin:=0 to 3 do
      begin
        LSlot:=(LToken*3+LSegment)*4+LBin;
        LSlots[LSlot].Found:=True;
        LSlots[LSlot].SegmentIndex:=LSegment;
        LSlots[LSlot].FeatureIndex:=LSlot*10;
        LSlots[LSlot].SourceFrame:=LSlot*100;
        LSlots[LSlot].ValidFrames:=64;
        LSlots[LSlot].Distance:=0.1;
      end;
  Result:=TJournalCandidatePool.CreateFromCandidates(3,3,4,LSlots);
end;

function Tokens(const ACount:Integer):TAcousticIndices;
var I:Integer;
begin
  Result:=nil;
  SetLength(Result,ACount);
  for I:=0 to High(Result) do Result[I]:=I mod 2;
end;

function Slice(const AData:TAcousticIndices;const AFirst,ACount:Integer):TAcousticIndices;
var I:Integer;
begin
  Result:=nil;
  SetLength(Result,ACount);
  for I:=0 to ACount-1 do Result[I]:=AData[AFirst+I];
end;

procedure Append(var ATarget:TAcousticIndices;const APart:TAcousticIndices);
var LStart,I:Integer;
begin
  LStart:=Length(ATarget);
  SetLength(ATarget,LStart+Length(APart));
  for I:=0 to High(APart) do ATarget[LStart+I]:=APart[I];
end;

procedure Same(const ALeft,ARight:TAcousticIndices;const AWhy:String);
begin
  Check(Length(ALeft)=Length(ARight),AWhy+' length');
  if Length(ALeft)>0 then
    Check(CompareMem(@ALeft[0],@ARight[0],Length(ALeft)*SizeOf(Integer)),AWhy+' bytes');
end;

procedure MustRejectChunk(const AStream:TJournalSelectionStream;
  const AInput:TAcousticIndices;const AWhy:String);
var LRejected:Boolean; LBeforeCount,LBeforeVisits:Int64;
begin
  LBeforeCount:=AStream.SelectedCount;
  LBeforeVisits:=AStream.SelectionVisits;
  LRejected:=False;
  try AStream.SelectChunk(AInput); except on E:EAudio do LRejected:=True; end;
  Check(LRejected,AWhy+' rejected');
  Check((AStream.SelectedCount=LBeforeCount) and
    (AStream.SelectionVisits=LBeforeVisits),AWhy+' counters preserved');
end;

procedure CheckParity(const APool:TJournalCandidatePool);
var LWeights:TJournalSelectionWeights; LTokens,LOne,LChunks,LPart:TAcousticIndices;
  LStream:TJournalSelectionStream; LFirst,LCount,I:Integer;
const CSizes:array[0..4] of Integer=(1,129,2048,7,815);
begin
  LWeights:=nil; SetLength(LWeights,3); LWeights[0]:=3; LWeights[1]:=2;
  LTokens:=Tokens(3000);
  LOne:=APool.Select(LTokens,LWeights,731);
  LStream:=TJournalSelectionStream.Create(APool,LWeights,731);
  try
    LFirst:=0; LChunks:=nil;
    for I:=0 to High(CSizes) do
    begin
      LCount:=CSizes[I];
      LPart:=LStream.SelectChunk(Slice(LTokens,LFirst,LCount));
      Append(LChunks,LPart); Inc(LFirst,LCount);
    end;
    Check(LFirst=3000,'parity split covers input');
    Same(LOne,LChunks,'one-shot/chunk parity');
    Check((LStream.SelectedCount=3000) and
      (LStream.SelectionVisits=3000*3*4),'parity counters');
  finally LStream.Free; end;
  WriteLn('PASS one-shot 3000 byte-identical across five chunks');
end;

procedure CheckLong(const APool:TJournalCandidatePool);
var LWeights:TJournalSelectionWeights; LTokens,LA,LB,LPart:TAcousticIndices;
  LFirst,LCount,I:Integer; SA,SB:TJournalSelectionStream;
begin
  SetLength(LWeights,3); LWeights[0]:=3; LWeights[1]:=2;
  LTokens:=Tokens(8201);
  SA:=TJournalSelectionStream.Create(APool,LWeights,17);
  SB:=TJournalSelectionStream.Create(APool,LWeights,17);
  try
    LA:=nil; LFirst:=0;
    while LFirst<Length(LTokens) do
    begin
      LCount:=Min(2048,Length(LTokens)-LFirst);
      LPart:=SA.SelectChunk(Slice(LTokens,LFirst,LCount));
      Append(LA,LPart); Inc(LFirst,LCount);
    end;
    LB:=nil; LFirst:=0;
    while LFirst<Length(LTokens) do
    begin
      LCount:=Min(511,Length(LTokens)-LFirst);
      LPart:=SB.SelectChunk(Slice(LTokens,LFirst,LCount));
      Append(LB,LPart); Inc(LFirst,LCount);
    end;
    Same(LA,LB,'long partition invariance');
    Check((SA.SelectedCount=8201) and (SB.SelectedCount=8201),
      'long selected count');
    for I:=1 to High(LA) do
      if (LTokens[I]=LTokens[I-1]) and (LA[I] div 4=LA[I-1] div 4) then
        Check(LA[I]<>LA[I-1],'adjacent same-window avoidable repetition');
  finally SB.Free; SA.Free; end;
  WriteLn('PASS 8201 selections across different chunk schedules and boundaries');
end;

procedure CheckBoundary(const APool:TJournalCandidatePool);
var LWeights:TJournalSelectionWeights; LOne,LPart,LJoined,LInput:TAcousticIndices;
  LStream:TJournalSelectionStream; I:Integer;
begin
  SetLength(LWeights,3); LWeights[0]:=1;
  SetLength(LInput,100);
  for I:=0 to High(LInput) do LInput[I]:=0;
  LOne:=APool.Select(LInput,LWeights,731);
  LStream:=TJournalSelectionStream.Create(APool,LWeights,731);
  try
    LWeights[0]:=0; { Caller mutation cannot change fixed stream weights. }
    LJoined:=nil;
    for I:=0 to High(LInput) do
    begin
      LPart:=LStream.SelectChunk(Slice(LInput,I,1));
      Append(LJoined,LPart);
      if I>0 then Check(LJoined[I]<>LJoined[I-1],
        'consecutive same-token chunk boundary avoids repeated window');
    end;
    Same(LOne,LJoined,'one-token boundary parity');
  finally LStream.Free; end;
  WriteLn('PASS previous-slot carry across 100 single-token chunks');
end;

procedure CheckRollback(const APool:TJournalCandidatePool);
var LWeights, LBadWeights:TJournalSelectionWeights;
  LPrefix, LNext, LA, LB, LInvalid:TAcousticIndices;
  SA,SB:TJournalSelectionStream; LRejected:Boolean;
begin
  SetLength(LWeights,3); LWeights[0]:=3; LWeights[1]:=2;
  SA:=TJournalSelectionStream.Create(APool,LWeights,731);
  SB:=TJournalSelectionStream.Create(APool,LWeights,731);
  try
    LPrefix:=Tokens(37);
    Same(SA.SelectChunk(LPrefix),SB.SelectChunk(LPrefix),'rollback prefix');
    LInvalid:=Tokens(6); LInvalid[5]:=2;
    MustRejectChunk(SA,LInvalid,'missing token after five tentative selections');
    LInvalid:=Tokens(3); LInvalid[2]:=-1;
    MustRejectChunk(SA,LInvalid,'invalid token');
    SetLength(LInvalid,MaximumJournalSelectionGrains+1);
    MustRejectChunk(SA,LInvalid,'overlong chunk');
    LNext:=Tokens(23); LA:=SA.SelectChunk(LNext); LB:=SB.SelectChunk(LNext);
    Same(LA,LB,'failed chunk leaves complete cursor intact');
    Check(SA.SelectedCount=60,'rollback count');
  finally SB.Free; SA.Free; end;
  LBadWeights:=Copy(LWeights); LBadWeights[0]:=-1; LRejected:=False;
  try SA:=TJournalSelectionStream.Create(APool,LBadWeights,731);
  except on E:EAudio do LRejected:=True; end;
  Check(LRejected,'negative weight rejected');
  LBadWeights[0]:=4097; LRejected:=False;
  try SA:=TJournalSelectionStream.Create(APool,LBadWeights,731);
  except on E:EAudio do LRejected:=True; end;
  Check(LRejected,'oversize weight rejected');
  LBadWeights[0]:=0; LBadWeights[1]:=0;
  SA:=TJournalSelectionStream.Create(APool,LBadWeights,731);
  try MustRejectChunk(SA,Tokens(2),'all disabled weights'); finally SA.Free; end;
  WriteLn('PASS invalid/missing/weight rejection and full cursor rollback');
end;

procedure CheckBudget;
var LSlots:TJournalRepresentatives; LWeights:TJournalSelectionWeights;
  LTokens:TAcousticIndices; LPool:TJournalCandidatePool;
  LStream:TJournalSelectionStream;
begin
  SetLength(LSlots,2048*32);
  LSlots[0].Found:=True;
  LSlots[0].SegmentIndex:=0;
  LSlots[0].ValidFrames:=64;
  LPool:=TJournalCandidatePool.CreateFromCandidates(1,2048,32,LSlots);
  try
    SetLength(LWeights,2048); LWeights[0]:=1;
    LStream:=TJournalSelectionStream.Create(LPool,LWeights,731);
    try
      SetLength(LTokens,976);
      LStream.SelectChunk(LTokens);
      Check(LStream.SelectionVisits=Int64(976)*2048*32,
        'large geometry visit accounting');
      SetLength(LTokens,1);
      MustRejectChunk(LStream,LTokens,'cumulative 64m visit cap');
    finally LStream.Free; end;
  finally LPool.Free; end;
  WriteLn('PASS cumulative work bound and rollback');
end;

var LPool:TJournalCandidatePool;
begin
  LPool:=MakePool;
  try
    CheckParity(LPool);
    CheckBoundary(LPool);
    CheckLong(LPool);
    CheckRollback(LPool);
  finally LPool.Free; end;
  CheckBudget;
end.
