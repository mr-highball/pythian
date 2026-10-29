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
unit pythian.learning.render.stream;

{$mode delphi}
{$H+}

interface

uses
  pythian.audio,
  pythian.progress,
  pythian.learning,
  pythian.learning.journal,
  pythian.learning.selection,
  pythian.learning.context;

const
  MaximumJournalStreamChunkGrains = 4096;
  MaximumJournalStreamVisits: Int64 = 128000000;

type
  TJournalAudioWrite = procedure(const ASamples: array of Single) of object;
  { Borrows pool and callbacks. Output blocks are borrowed for the callback
    only; copy before retaining. Hann normalization continues across blocks.
    Source/output or post-preflight observer failures poison this stream; earlier
    external writes cannot roll back. Preflight observer failures leave it
    unchanged and retryable. Observers are synchronous and borrowed per call;
    no callback may reenter or mutate this renderer. RTL buffer allocation/copy
    and each bounded source/output I/O callback remain synchronous boundaries.
    Positive OutputFrames trims the ending without a second rendering pass. }
  TJournalAudioRenderStream = class
  private
    FPool: TJournalCandidatePool;
    FReadWindow: TJournalWindowRead;
    FWriteAudio: TJournalAudioWrite;
    FChannels: Integer;
    FWindowFrames: Integer;
    FHopFrames: Integer;
    FExpectedGrains: Int64;
    FGrainCount: Int64;
    FFlushedFrames: Int64;
    FWrittenFrames: Int64;
    FOutputFrames: Int64;
    FMix: array of Double;
    FWeights: array of Double;
    FWindowWeights: array of Double;
    FBlock: TAudioSamples;
    FBlockFrames: Integer;
    FBufferedFrames: Integer;
    FPeak: Double;
    FFailed: Boolean;
    FFinished: Boolean;
    FBusy: Boolean;
    FProgress: TWorkProgressCallback;
    procedure RequireIdle;
    procedure FlushTo(const AFrame: Int64);
    procedure WriteBuffered;
    procedure AppendOne(const ACandidate: TJournalRepresentative);
  public
    constructor Create(const APool: TJournalCandidatePool;
      const AReadWindow: TJournalWindowRead; const AWriteAudio: TJournalAudioWrite;
      const AChannels, AWindowFrames, AHopFrames: Integer;
      const AExpectedGrains: Int64; const ABlockFrames: Integer;
      const AOutputFrames: Int64 = 0;
      const AProgress: TWorkProgressCallback = nil);
    procedure AppendSelection(const ASelection: TAcousticIndices;
      const AProgress: TWorkProgressCallback = nil);
    { Explicit windows are preflighted as a complete block before source reads.
      The host's verified profile/source binding owns physical source extents. }
    procedure AppendWindows(const AWindows: TJournalContextWindows;
      const AProgress: TWorkProgressCallback = nil);
    procedure Finish(const AProgress: TWorkProgressCallback = nil);
    property GrainCount: Int64 read FGrainCount;
    property FlushedFrames: Int64 read FFlushedFrames;
    property Peak: Double read FPeak;
    property Failed: Boolean read FFailed;
    property Finished: Boolean read FFinished;
  end;

function JournalStreamFrames(const AWindowFrames, AHopFrames: Integer;
  const AGrainCount: Int64): Int64;

implementation

uses
  Math,
  pythian.granular;

function JournalStreamFrames(const AWindowFrames, AHopFrames: Integer;
  const AGrainCount: Int64): Int64;
begin
  if (AWindowFrames < 1) or (AWindowFrames > 65536) or
    (AHopFrames < 1) or (AHopFrames > AWindowFrames) or
    (AGrainCount < 1) then
  begin
    raise EAudio.Create('Journal stream geometry or grain count invalid');
  end;
  if AGrainCount - 1 > (High(Int64) - AWindowFrames) div AHopFrames then
  begin
    raise EAudio.Create('Journal stream output clock overflows Int64');
  end;
  Result := (AGrainCount - 1) * AHopFrames + AWindowFrames;
end;

constructor TJournalAudioRenderStream.Create(const APool: TJournalCandidatePool;
  const AReadWindow: TJournalWindowRead; const AWriteAudio: TJournalAudioWrite;
  const AChannels, AWindowFrames, AHopFrames: Integer;
  const AExpectedGrains: Int64; const ABlockFrames: Integer;
  const AOutputFrames: Int64; const AProgress: TWorkProgressCallback);
var
  LFrame: Integer;
begin
  inherited Create;
  if (APool = nil) or not Assigned(AReadWindow) or not Assigned(AWriteAudio) or
    not (AChannels in [1, 2]) or
    (ABlockFrames < 1) or (ABlockFrames > 65536) then
  begin
    raise EAudio.Create('Journal stream requires pool, callbacks, channels and bounded block');
  end;
  FOutputFrames := JournalStreamFrames(AWindowFrames, AHopFrames, AExpectedGrains);
  if (AOutputFrames < 0) or (AOutputFrames > FOutputFrames) or
    ((AOutputFrames > 0) and (AExpectedGrains > 1) and
      (AOutputFrames <= (AExpectedGrains - 2) * AHopFrames + AWindowFrames)) then
  begin
    raise EAudio.Create('Exact output must end within the final required grain');
  end;
  if AOutputFrames > 0 then
  begin
    FOutputFrames := AOutputFrames;
  end;
  FPool := APool;
  FReadWindow := AReadWindow;
  FWriteAudio := AWriteAudio;
  FChannels := AChannels;
  FWindowFrames := AWindowFrames;
  FHopFrames := AHopFrames;
  FExpectedGrains := AExpectedGrains;
  FBlockFrames := ABlockFrames;
  SetLength(FMix, AWindowFrames * FChannels);
  SetLength(FWeights, AWindowFrames);
  SetLength(FWindowWeights, AWindowFrames);
  ReportWork(AProgress, 'journal_render_window', wuFrames, 0, AWindowFrames);
  for LFrame := 0 to AWindowFrames - 1 do
  begin
    FWindowWeights[LFrame] := GrainWindowWeight(gwHann, LFrame, AWindowFrames);
    if ((LFrame + 1) mod 1024 = 0) then
      ReportWork(AProgress, 'journal_render_window', wuFrames, LFrame + 1, AWindowFrames);
  end;
  SetLength(FBlock, ABlockFrames * FChannels);
  ReportWork(AProgress, 'journal_render_window', wuFrames, AWindowFrames, AWindowFrames);
end;

procedure TJournalAudioRenderStream.RequireIdle;
begin
  if FBusy then
    raise EAudio.Create('Journal renderer cannot be reentered from a callback');
end;

procedure TJournalAudioRenderStream.WriteBuffered;
var
  LSamples: TAudioSamples;
begin
  if FBufferedFrames = 0 then
  begin
    Exit;
  end;
  if FBufferedFrames = FBlockFrames then
  begin
    FWriteAudio(FBlock);
  end
  else
  begin
    LSamples := Copy(FBlock, 0, FBufferedFrames * FChannels);
    FWriteAudio(LSamples);
  end;
  Inc(FWrittenFrames, FBufferedFrames);
  FBufferedFrames := 0;
  ReportWork(FProgress, 'journal_render_output', wuFrames, FWrittenFrames, FOutputFrames);
end;

procedure TJournalAudioRenderStream.FlushTo(const AFrame: Int64);
var
  LRing: Integer;
  LChannel: Integer;
  LWeight: Double;
  LValue: Double;
begin
  if (AFrame < FFlushedFrames) or (AFrame > FOutputFrames) then
  begin
    raise EAudio.Create('Journal stream flush extent invalid');
  end;
  ReportWork(FProgress, 'journal_render_flush', wuFrames, FFlushedFrames, FOutputFrames);
  while FFlushedFrames < AFrame do
  begin
    LRing := FFlushedFrames mod FWindowFrames;
    LWeight := Max(1.0, FWeights[LRing]);
    for LChannel := 0 to FChannels - 1 do
    begin
      LValue := FMix[LRing * FChannels + LChannel] / LWeight;
      RequireFinite(LValue, 'Journal stream sample');
      if Abs(LValue) > 1 then
      begin
        raise EAudio.Create('Journal stream exceeds PCM16 headroom');
      end;
      FPeak := Max(FPeak, Abs(LValue));
      FBlock[FBufferedFrames * FChannels + LChannel] := LValue;
      FMix[LRing * FChannels + LChannel] := 0;
    end;
    FWeights[LRing] := 0;
    Inc(FBufferedFrames);
    Inc(FFlushedFrames);
    if FBufferedFrames = FBlockFrames then
    begin
      WriteBuffered;
    end;
    if FFlushedFrames mod 1024 = 0 then
      ReportWork(FProgress, 'journal_render_flush', wuFrames, FFlushedFrames, FOutputFrames);
  end;
  ReportWork(FProgress, 'journal_render_flush', wuFrames, FFlushedFrames, FOutputFrames);
end;

procedure TJournalAudioRenderStream.AppendOne(const ACandidate: TJournalRepresentative);
var
  LSamples: TAudioSamples;
  LStart: Int64;
  LFrame: Integer;
  LChannel: Integer;
  LRing: Integer;
  LWeight: Double;
  LValue: Double;
begin
  ReportWork(FProgress, 'journal_render_source', wuFrames, 0, ACandidate.ValidFrames);
  LSamples := FReadWindow(ACandidate);
  if Length(LSamples) <> ACandidate.ValidFrames * FChannels then
  begin
    raise EAudio.Create('Journal stream callback returned a mismatched window');
  end;
  ReportWork(FProgress, 'journal_render_source', wuFrames,
    ACandidate.ValidFrames, ACandidate.ValidFrames);
  LStart := Int64(FGrainCount) * FHopFrames;
  ReportWork(FProgress, 'journal_render_mix', wuFrames, 0, FWindowFrames);
  for LFrame := 0 to FWindowFrames - 1 do
  begin
    LRing := (LStart + LFrame) mod FWindowFrames;
    LWeight := FWindowWeights[LFrame];
    FWeights[LRing] := FWeights[LRing] + LWeight;
    for LChannel := 0 to FChannels - 1 do
    begin
      LValue := 0;
      if LFrame < ACandidate.ValidFrames then
      begin
        LValue := LSamples[LFrame * FChannels + LChannel];
        RequireFinite(LValue, 'Journal stream source sample');
        if Abs(LValue) > 1 then
        begin
          raise EAudio.Create('Journal stream source exceeds PCM16 headroom');
        end;
      end;
      FMix[LRing * FChannels + LChannel] :=
        FMix[LRing * FChannels + LChannel] + LValue * LWeight;
    end;
    if (LFrame + 1) mod 1024 = 0 then
      ReportWork(FProgress, 'journal_render_mix', wuFrames, LFrame + 1, FWindowFrames);
  end;
  ReportWork(FProgress, 'journal_render_mix', wuFrames, FWindowFrames, FWindowFrames);
  Inc(FGrainCount);
  FlushTo(Min(FGrainCount * FHopFrames, FOutputFrames));
end;

procedure TJournalAudioRenderStream.AppendSelection(const ASelection: TAcousticIndices;
  const AProgress: TWorkProgressCallback);
var
  LSlot: Integer;
  LIndex: Integer;
  LCandidate: TJournalRepresentative;
begin
  RequireIdle;
  if FFailed or FFinished then
  begin
    raise EAudio.Create('Journal stream cannot continue after failure or finish');
  end;
  if (Length(ASelection) < 1) or
    (Length(ASelection) > FExpectedGrains - FGrainCount) or
    (Length(ASelection) > MaximumJournalStreamChunkGrains) or
    (Int64(Length(ASelection)) * FWindowFrames * FChannels > MaximumJournalStreamVisits) then
  begin
    raise EAudio.Create('Journal stream selection count invalid');
  end;
  FBusy := True;
  FProgress := AProgress;
  try
    ReportWork(FProgress, 'journal_render_preflight', wuItems, 0, Length(ASelection));
    for LIndex := 0 to High(ASelection) do
    begin
      LCandidate := FPool.CandidateAt(ASelection[LIndex]);
      if not LCandidate.Found or (LCandidate.ValidFrames < 1) or
        (LCandidate.ValidFrames > FWindowFrames) then
        raise EAudio.Create('Journal stream selection needs admitted source windows');
      if (LIndex + 1) mod 128 = 0 then
        ReportWork(FProgress, 'journal_render_preflight', wuItems, LIndex + 1, Length(ASelection));
    end;
    ReportWork(FProgress, 'journal_render_preflight', wuItems, Length(ASelection), Length(ASelection));
    try
      ReportWork(FProgress, 'journal_render_grains', wuItems, FGrainCount, FExpectedGrains);
      for LSlot in ASelection do
      begin
        AppendOne(FPool.CandidateAt(LSlot));
        ReportWork(FProgress, 'journal_render_grains', wuItems, FGrainCount, FExpectedGrains);
      end;
    except
      FFailed := True;
      raise;
    end;
  finally
    FProgress := nil;
    FBusy := False;
  end;
end;

procedure TJournalAudioRenderStream.AppendWindows(
  const AWindows: TJournalContextWindows; const AProgress: TWorkProgressCallback);
var
  LIndex: Integer;
  LWindow: TJournalContextWindow;
begin
  RequireIdle;
  if FFailed or FFinished then
    raise EAudio.Create('Journal stream cannot continue after failure or finish');
  if (Length(AWindows) < 1) or
    (Length(AWindows) > FExpectedGrains - FGrainCount) or
    (Length(AWindows) > MaximumJournalStreamChunkGrains) or
    (Int64(Length(AWindows)) * FWindowFrames * FChannels > MaximumJournalStreamVisits) then
    raise EAudio.Create('Journal stream explicit window count invalid');
  FBusy := True;
  FProgress := AProgress;
  try
    ReportWork(FProgress, 'journal_render_preflight', wuItems, 0, Length(AWindows));
    for LIndex := 0 to High(AWindows) do
    begin
      LWindow := AWindows[LIndex];
      if (LWindow.Token < 0) or
        (LWindow.Token > FPool.TokenAt(FPool.SlotCount - 1)) or
        not LWindow.Candidate.Found or
        (LWindow.Candidate.SegmentIndex < 0) or
        (LWindow.Candidate.SegmentIndex >= FPool.SegmentCount) or
        (LWindow.Candidate.FeatureIndex < 0) or
        (LWindow.Candidate.SourceFrame < 0) or
        (LWindow.Candidate.ValidFrames < 1) or
        (LWindow.Candidate.ValidFrames > FWindowFrames) then
        raise EAudio.Create('Journal stream explicit window invalid');
      if (LIndex + 1) mod 128 = 0 then
        ReportWork(FProgress, 'journal_render_preflight', wuItems, LIndex + 1, Length(AWindows));
    end;
    ReportWork(FProgress, 'journal_render_preflight', wuItems, Length(AWindows), Length(AWindows));
    try
      ReportWork(FProgress, 'journal_render_grains', wuItems, FGrainCount, FExpectedGrains);
      for LIndex := 0 to High(AWindows) do
      begin
        AppendOne(AWindows[LIndex].Candidate);
        ReportWork(FProgress, 'journal_render_grains', wuItems, FGrainCount, FExpectedGrains);
      end;
    except
      FFailed := True;
      raise;
    end;
  finally
    FProgress := nil;
    FBusy := False;
  end;
end;

procedure TJournalAudioRenderStream.Finish(const AProgress: TWorkProgressCallback);
begin
  RequireIdle;
  if FFailed or FFinished or (FGrainCount <> FExpectedGrains) then
  begin
    raise EAudio.Create('Journal stream is failed, finished or incomplete');
  end;
  FBusy := True;
  FProgress := AProgress;
  try
    try
      FlushTo(FOutputFrames);
      WriteBuffered;
      ReportWork(FProgress, 'journal_render_complete', wuFrames, FWrittenFrames, FOutputFrames);
      FFinished := True;
    except
      FFailed := True;
      raise;
    end;
  finally
    FProgress := nil;
    FBusy := False;
  end;
end;

end.
