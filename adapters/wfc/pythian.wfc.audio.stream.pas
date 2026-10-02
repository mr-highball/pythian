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
unit pythian.wfc.audio.stream;

{$mode delphi}
{$H+}

interface

uses
  pythian.audio,
  pythian.learning,
  pythian.learning.journal,
  pythian.learning.selection,
  pythian.learning.render.stream,
  pythian.wfc.learning.profile,
  pythian.wfc.stream;

const
  MaximumSessionPullFrames = 65536;
  MaximumSessionBufferedFrames = 131072;
  SessionChunkGrains = 128;

type
  TAudioSessionState = (assReady, assPaused, assCompleted, assStopped, assFailed);
  TAudioSessionGrain = procedure(const AOrdinal: Int64; const AToken: Integer;
    const ACandidate: TJournalRepresentative) of object;

  { Borrows an immutable verified profile and source reader. All state is owned
    here; calls must be serialized and callbacks must not reenter. No WAV or
    whole-output ledger is required. ReadFrames returns owned PCM and at most
    one fixed 128-grain solve per call. Short positive blocks are normal.
    Pause applies backpressure; Stop discards pending audio. A failed pull
    returns no partial block and permanently fails the session. Earlier blocks
    remain identifiable by Position and the caller's bound profile/seed. }
  TJournalAudioSession = class
  private
    FProfile: TJournalModelProfile;
    FSequence: TLearnedSequenceStream;
    FSelector: TJournalSelectionStream;
    FRender: TJournalAudioRenderStream;
    FOnGrain: TAudioSessionGrain;
    FSlots: TAcousticIndices;
    FTokens: TAcousticIndices;
    FSlotIndex: Integer;
    FSeed: Integer;
    FChunkIndex: Int64;
    FTotalGrains: Int64;
    FTotalFrames: Int64;
    FPosition: Int64;
    FQueue: TAudioSamples;
    FQueueOffset: Integer;
    FQueueFrames: Integer;
    FState: TAudioSessionState;
    FBusy: Boolean;
    FFailure: String;
    procedure ReceiveAudio(const ASamples: array of Single);
    procedure GenerateChunk;
    procedure RequireIdle;
  public
    constructor Create(const AProfile: TJournalModelProfile;
      const AReadWindow: TJournalWindowRead; const AWeights: TJournalSelectionWeights;
      const ASeed: Integer; const ATotalFrames: Int64;
      const AOnGrain: TAudioSessionGrain = nil);
    destructor Destroy; override;
    function ReadFrames(const AMaximumFrames: Integer): TAudioSamples;
    procedure Pause;
    procedure Resume;
    procedure Stop;
    property State: TAudioSessionState read FState;
    property Position: Int64 read FPosition;
    property TotalFrames: Int64 read FTotalFrames;
    property TotalGrains: Int64 read FTotalGrains;
    property Failure: String read FFailure;
  end;

implementation

uses
  SysUtils,
  Math,
  wfc,
  wfc_sequence,
  wfc_sequence_graph,
  pythian.wfc.learning;

constructor TJournalAudioSession.Create(const AProfile: TJournalModelProfile;
  const AReadWindow: TJournalWindowRead; const AWeights: TJournalSelectionWeights;
  const ASeed: Integer; const ATotalFrames: Int64;
  const AOnGrain: TAudioSessionGrain);
var
  LRemaining: Int64;
begin
  inherited Create;
  if (AProfile = nil) or not Assigned(AReadWindow) or
    (ASeed < 0) or (ATotalFrames < 1) then
  begin
    raise EAudio.Create('Audio session requires profile, reader, seed and positive frame count');
  end;
  FProfile := AProfile;
  FSeed := ASeed;
  FTotalFrames := ATotalFrames;
  LRemaining := Max(Int64(0), ATotalFrames - AProfile.Options.WindowFrames);
  FTotalGrains := LRemaining div AProfile.Options.HopFrames + 1;
  if LRemaining mod AProfile.Options.HopFrames <> 0 then
  begin
    Inc(FTotalGrains);
  end;
  FOnGrain := AOnGrain;
  FSequence := TLearnedSequenceStream.Create(AProfile.Model);
  FSelector := TJournalSelectionStream.Create(AProfile.Pool, AWeights, ASeed);
  SetLength(FQueue, MaximumSessionBufferedFrames * AProfile.Channels);
  FRender := TJournalAudioRenderStream.Create(AProfile.Pool, AReadWindow,
    ReceiveAudio, AProfile.Channels, AProfile.Options.WindowFrames,
    AProfile.Options.HopFrames, FTotalGrains, Min(4096, AProfile.Options.HopFrames),
    ATotalFrames);
end;

destructor TJournalAudioSession.Destroy;
begin
  FRender.Free;
  FSelector.Free;
  FSequence.Free;
  inherited Destroy;
end;

procedure TJournalAudioSession.RequireIdle;
begin
  if FBusy then
  begin
    raise EAudio.Create('Audio session calls cannot reenter');
  end;
end;

procedure TJournalAudioSession.ReceiveAudio(const ASamples: array of Single);
var
  LFrames: Integer;
  LChannels: Integer;
begin
  LChannels := FProfile.Channels;
  LFrames := Length(ASamples) div LChannels;
  if (Length(ASamples) mod LChannels <> 0) or
    (LFrames > MaximumSessionBufferedFrames - FQueueFrames) then
  begin
    raise EAudio.Create('Audio session output exceeded its bounded queue');
  end;
  if FQueueOffset + FQueueFrames + LFrames > MaximumSessionBufferedFrames then
  begin
    if FQueueFrames > 0 then
    begin
      Move(FQueue[FQueueOffset * LChannels], FQueue[0],
        FQueueFrames * LChannels * SizeOf(Single));
    end;
    FQueueOffset := 0;
  end;
  if LFrames > 0 then
  begin
    Move(ASamples[0], FQueue[(FQueueOffset + FQueueFrames) * LChannels],
      Length(ASamples) * SizeOf(Single));
    Inc(FQueueFrames, LFrames);
  end;
end;

procedure TJournalAudioSession.GenerateChunk;
var
  LOptions: TSequenceChunkOptions;
  LChunk: TWfcGeneratedSequenceSegment;
  LReport: TGraphSolveReport;
  LCount: Integer;
  LIndex: Integer;
begin
  LCount := Min(Int64(SessionChunkGrains), FTotalGrains - FSequence.CellCount);
  LOptions := DefaultSequenceChunkOptions;
  LOptions.CellCount := LCount;
  { Big Boss: fixed chunks and modulo-2^32 seed progression are independent of
    consumer block size. A failed declared seed is never replaced. }
  LOptions.Seed := (QWord(FSeed) + QWord(FChunkIndex mod 4294967296)) and $FFFFFFFF;
  if not FSequence.TryNext(LOptions, nil, LChunk, LReport) then
  begin
    raise EAudio.CreateFmt('WFC could not continue seed %d at chunk %d; no seed substitution',
      [LOptions.Seed, FChunkIndex]);
  end;
  SetLength(FTokens, LCount);
  for LIndex := 0 to LCount - 1 do
  begin
    FTokens[LIndex] := AcousticTokenIndex(LChunk.Tokens[LIndex]);
  end;
  FSlots := FSelector.SelectChunk(FTokens);
  FSlotIndex := 0;
  Inc(FChunkIndex);
end;

function TJournalAudioSession.ReadFrames(const AMaximumFrames: Integer): TAudioSamples;
var
  LDone: Integer;
  LCount: Integer;
  LGrains: Integer;
  LSolved: Boolean;
  LOne: TAcousticIndices;
  LOutput: TAudioSamples;
  LCandidate: TJournalRepresentative;
begin
  RequireIdle;
  if (AMaximumFrames < 1) or (AMaximumFrames > MaximumSessionPullFrames) then
  begin
    raise EAudio.Create('Audio session pull requires 1..65536 frames');
  end;
  Result := nil;
  if FState = assFailed then
  begin
    raise EAudio.Create(FFailure);
  end;
  if FState <> assReady then
  begin
    Exit;
  end;
  SetLength(LOutput, AMaximumFrames * FProfile.Channels);
  SetLength(LOne, 1);
  LDone := 0;
  LGrains := 0;
  LSolved := False;
  FBusy := True;
  try
    try
      while LDone < AMaximumFrames do
      begin
        if FQueueFrames > 0 then
        begin
          LCount := Min(AMaximumFrames - LDone, FQueueFrames);
          Move(FQueue[FQueueOffset * FProfile.Channels],
            LOutput[LDone * FProfile.Channels], LCount * FProfile.Channels * SizeOf(Single));
          Inc(FQueueOffset, LCount);
          Dec(FQueueFrames, LCount);
          Inc(LDone, LCount);
          Continue;
        end;
        if FRender.Finished then
        begin
          Break;
        end;
        if FRender.GrainCount = FTotalGrains then
        begin
          FRender.Finish;
          Continue;
        end;
        if LGrains = SessionChunkGrains then
        begin
          Break;
        end;
        if FSlotIndex = Length(FSlots) then
        begin
          if LSolved then
          begin
            Break;
          end;
          GenerateChunk;
          LSolved := True;
        end;
        LOne[0] := FSlots[FSlotIndex];
        FRender.AppendSelection(LOne);
        if Assigned(FOnGrain) then
        begin
          LCandidate := FProfile.Pool.CandidateAt(LOne[0]);
          FOnGrain(FRender.GrainCount - 1, FTokens[FSlotIndex], LCandidate);
        end;
        Inc(FSlotIndex);
        Inc(LGrains);
      end;
      if FPosition + LDone = FTotalFrames then
      begin
        if not FRender.Finished then
        begin
          FRender.Finish;
        end;
        FState := assCompleted;
      end;
      SetLength(LOutput, LDone * FProfile.Channels);
      Inc(FPosition, LDone);
      Result := LOutput;
    except
      on LException: Exception do
      begin
        FFailure := LException.Message;
        FState := assFailed;
        FQueueFrames := 0;
        raise;
      end;
    end;
  finally
    FBusy := False;
  end;
end;

procedure TJournalAudioSession.Pause;
begin
  RequireIdle;
  if FState = assReady then
  begin
    FState := assPaused;
  end;
end;

procedure TJournalAudioSession.Resume;
begin
  RequireIdle;
  if FState = assPaused then
  begin
    FState := assReady;
  end;
end;

procedure TJournalAudioSession.Stop;
begin
  RequireIdle;
  if FState in [assReady, assPaused] then
  begin
    FState := assStopped;
    FQueueFrames := 0;
  end;
end;

end.
