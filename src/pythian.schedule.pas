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
unit pythian.schedule;

{$mode delphi}
{$H+}

interface

uses
  pythian.audio,
  pythian.synth,
  pythian.bus;

const
  ScheduleContractVersion = 1;
  MaximumScheduledVoices = 4096;

type
  TScheduleResult = (srScheduled, srVoiceLimit, srWorkLimit);

  { Owns admitted voices; borrows graph and factories. NextFrame is the next
    unrendered absolute frame. Pending starts >= NextFrame are cancellable.
    Graph processing/reset is exclusive to this scheduler while in use. }
  TScheduledSynth = class
  private
    type
      TSlot = record
        Id: Int64;
        StartFrame: Int64;
        Bus: Integer;
        Group: Integer;
        Cost: Integer;
        Voice: TPlayingTone;
      end;
      TSlots = array of TSlot;
  private
    FGraph: TBusGraph;
    FSlots: TSlots;
    FInputs: TBusFrames;
    FCount: Integer;
    FReservedWork: Integer;
    FWorkLimit: Integer;
    FNextFrame: Int64;
    FLastId: Int64;
    FBusy: Boolean;
    FFailed: Boolean;
    procedure RequireReady;
    procedure Drop(const AIndex: Integer);
    procedure Compact;
    function GetActiveCount: Integer;
    function GetPendingCount: Integer;
    function StopSelected(const AGroup: Integer; const AId: Int64;
      const AById: Boolean): Integer;
  public
    constructor Create(const AGraph: TBusGraph; const AVoiceLimit: Integer = 128;
      const AWorkLimit: Integer = 1000000; const AStartFrame: Int64 = 0);
    destructor Destroy; override;
    function TrySchedule(const ATone: TFrameTone; const ABus, AGroup: Integer;
      out AId: Int64): TScheduleResult;
    function CancelFuture(const AGroup: Integer; const AFromFrame: Int64): Integer;
    { Build a complete future replacement before publishing; failed admission
      or source construction preserves all existing notes and bus history. }
    function TryReplaceFuture(const AGroup: Integer; const AFromFrame: Int64;
      const ABus: Integer; const ATones: TFrameTones; out AFirstId: Int64): TScheduleResult;
    { Drop pending notes and release committed notes using their native envelope. }
    function StopGroup(const AGroup: Integer): Integer;
    function ReleaseVoice(const AId: Int64): Boolean;
    procedure Process(out ALeft, ARight: Double);
    { Explicitly clears voices and graph history. IDs are never reused. }
    procedure Reset(const AStartFrame: Int64 = 0);
    property NextFrame: Int64 read FNextFrame;
    property ScheduledCount: Integer read FCount;
    property ActiveCount: Integer read GetActiveCount;
    property PendingCount: Integer read GetPendingCount;
    property ReservedWork: Integer read FReservedWork;
    property Failed: Boolean read FFailed;
  end;

function RenderScheduledFrames(const ASynth: TScheduledSynth;
  const AFrames: Integer): TAudioClip;

implementation

uses
  Math,
  pythian.dynamics,
  pythian.effects;

constructor TScheduledSynth.Create(const AGraph: TBusGraph; const AVoiceLimit,
  AWorkLimit: Integer; const AStartFrame: Int64);
begin
  inherited Create;
  if (AGraph = nil) or (AVoiceLimit < 1) or (AVoiceLimit > MaximumScheduledVoices) or
    (AWorkLimit < 1) or (AWorkLimit > MaximumRenderVisits) or (AStartFrame < 0) then
  begin
    raise EAudio.Create('Scheduler graph, capacity, work, or start is invalid');
  end;
  if AGraph.Failed then
  begin
    raise EAudio.Create('Scheduler requires a healthy bus graph');
  end;
  FGraph := AGraph;
  FNextFrame := AStartFrame;
  FWorkLimit := AWorkLimit;
  SetLength(FSlots, AVoiceLimit);
  SetLength(FInputs, AGraph.BusCount);
end;

destructor TScheduledSynth.Destroy;
var
  LIndex: Integer;
begin
  for LIndex := 0 to High(FSlots) do
  begin
    FSlots[LIndex].Voice.Free;
  end;
  inherited;
end;

procedure TScheduledSynth.RequireReady;
begin
  if FBusy or FFailed or FGraph.Failed then
  begin
    raise EAudio.Create('Scheduler is active or requires Reset after failure');
  end;
end;

procedure TScheduledSynth.Drop(const AIndex: Integer);
var
  LVoice: TPlayingTone;
begin
  LVoice := FSlots[AIndex].Voice;
  FSlots[AIndex].Voice := nil;
  Dec(FReservedWork, FSlots[AIndex].Cost);
  LVoice.Free;
end;

procedure TScheduledSynth.Compact;
var
  LRead: Integer;
  LWrite: Integer;
begin
  LWrite := 0;
  for LRead := 0 to FCount - 1 do
  begin
    if FSlots[LRead].Voice <> nil then
    begin
      if LWrite <> LRead then
      begin
        FSlots[LWrite] := FSlots[LRead];
        FSlots[LRead].Voice := nil;
      end;
      Inc(LWrite);
    end;
  end;
  FCount := LWrite;
end;

function TScheduledSynth.GetActiveCount: Integer;
var
  LIndex: Integer;
begin
  Result := 0;
  for LIndex := 0 to FCount - 1 do
  begin
    if (FSlots[LIndex].Voice <> nil) and (FSlots[LIndex].StartFrame < FNextFrame) then
    begin
      Inc(Result);
    end;
  end;
end;

function TScheduledSynth.GetPendingCount: Integer;
begin
  Result := FCount - GetActiveCount;
end;

function TScheduledSynth.TrySchedule(const ATone: TFrameTone; const ABus, AGroup: Integer;
  out AId: Int64): TScheduleResult;
var
  LFrames: Int64;
  LCost: Integer;
  LVoice: TPlayingTone;
begin
  RequireReady;
  if (ABus < 0) or (ABus >= FGraph.BusCount) or (ATone.StartFrame < FNextFrame) then
  begin
    raise EAudio.Create('Scheduled bus or start is outside the unrendered timeline');
  end;
  FBusy := True;
  LVoice := nil;
  try
    LFrames := ValidateFrameTone(ATone, FGraph.SampleRate);
    if LFrames = 0 then
    begin
      raise EAudio.Create('Scheduled voice must span at least one frame');
    end;
    LCost := SynthFrameCost(ATone.Voice, FGraph.SampleRate) + 16;
    if FCount = Length(FSlots) then
    begin
      Exit(srVoiceLimit);
    end;
    if Int64(FReservedWork) + LCost > FWorkLimit then
    begin
      Exit(srWorkLimit);
    end;
    if FLastId = High(Int64) then
    begin
      raise EAudio.Create('Voice identity space exhausted');
    end;
    LVoice := TPlayingTone.Create(FGraph.SampleRate, ATone);
    Inc(FLastId);
    FSlots[FCount].Id := FLastId;
    FSlots[FCount].StartFrame := ATone.StartFrame;
    FSlots[FCount].Bus := ABus;
    FSlots[FCount].Group := AGroup;
    FSlots[FCount].Cost := LCost;
    FSlots[FCount].Voice := LVoice;
    LVoice := nil;
    Inc(FCount);
    Inc(FReservedWork, LCost);
    AId := FLastId;
    Result := srScheduled;
  finally
    LVoice.Free;
    FBusy := False;
  end;
end;

function TScheduledSynth.CancelFuture(const AGroup: Integer; const AFromFrame: Int64): Integer;
var
  LIndex: Integer;
begin
  RequireReady;
  if AFromFrame < FNextFrame then
  begin
    raise EAudio.Create('Cancellation cannot include committed frames');
  end;
  Result := 0;
  FBusy := True;
  try
    try
      for LIndex := 0 to FCount - 1 do
      begin
        if (FSlots[LIndex].Group = AGroup) and (FSlots[LIndex].StartFrame >= AFromFrame) then
        begin
          Drop(LIndex);
          Inc(Result);
        end;
      end;
      Compact;
    except
      FFailed := True;
      raise;
    end;
  finally
    FBusy := False;
  end;
end;

function TScheduledSynth.TryReplaceFuture(const AGroup: Integer; const AFromFrame: Int64;
  const ABus: Integer; const ATones: TFrameTones; out AFirstId: Int64): TScheduleResult;
var
  LCandidate: TSlots;
  LOld: TSlots;
  LCosts: array of Integer;
  LIndex: Integer;
  LKept: Integer;
  LCount: Integer;
  LOldCount: Integer;
  LWork: Int64;
  LFrames: Int64;
  LCommitted: Boolean;
begin
  RequireReady;
  if (AFromFrame < FNextFrame) or (ABus < 0) or (ABus >= FGraph.BusCount) then
  begin
    raise EAudio.Create('Replacement pivot or bus is outside the future timeline');
  end;
  if Length(ATones) > Length(FSlots) then
  begin
    Exit(srVoiceLimit);
  end;
  FBusy := True;
  LCommitted := False;
  LKept := 0;
  LCount := 0;
  try
    LWork := 0;
    for LIndex := 0 to FCount - 1 do
    begin
      if (FSlots[LIndex].Group <> AGroup) or (FSlots[LIndex].StartFrame < AFromFrame) then
      begin
        Inc(LKept);
        Inc(LWork, FSlots[LIndex].Cost);
      end;
    end;
    if LKept + Length(ATones) > Length(FSlots) then
    begin
      Exit(srVoiceLimit);
    end;
    SetLength(LCosts, Length(ATones));
    for LIndex := 0 to High(ATones) do
    begin
      LFrames := ValidateFrameTone(ATones[LIndex], FGraph.SampleRate);
      if (ATones[LIndex].StartFrame < AFromFrame) or (LFrames = 0) then
      begin
        raise EAudio.Create('Replacement notes must begin at/after pivot and span a frame');
      end;
      LCosts[LIndex] := SynthFrameCost(ATones[LIndex].Voice, FGraph.SampleRate) + 16;
      Inc(LWork, LCosts[LIndex]);
    end;
    if LWork > FWorkLimit then
    begin
      Exit(srWorkLimit);
    end;
    if FLastId > High(Int64) - Length(ATones) then
    begin
      raise EAudio.Create('Replacement exhausts voice identity space');
    end;
    SetLength(LCandidate, Length(FSlots));
    for LIndex := 0 to FCount - 1 do
    begin
      if (FSlots[LIndex].Group <> AGroup) or (FSlots[LIndex].StartFrame < AFromFrame) then
      begin
        LCandidate[LCount] := FSlots[LIndex];
        Inc(LCount);
      end;
    end;
    for LIndex := 0 to High(ATones) do
    begin
      LCandidate[LCount].Id := FLastId + LIndex + 1;
      LCandidate[LCount].StartFrame := ATones[LIndex].StartFrame;
      LCandidate[LCount].Bus := ABus;
      LCandidate[LCount].Group := AGroup;
      LCandidate[LCount].Cost := LCosts[LIndex];
      LCandidate[LCount].Voice := TPlayingTone.Create(FGraph.SampleRate, ATones[LIndex]);
      Inc(LCount);
    end;
    LOld := FSlots;
    LOldCount := FCount;
    FSlots := LCandidate;
    FCount := LCount;
    FReservedWork := LWork;
    Inc(FLastId, Length(ATones));
    LCommitted := True;
    try
      for LIndex := 0 to LOldCount - 1 do
      begin
        if (LOld[LIndex].Group = AGroup) and (LOld[LIndex].StartFrame >= AFromFrame) then
        begin
          LOld[LIndex].Voice.Free;
        end;
      end;
    except
      { Custom source destructors must not raise. Publication is already committed. }
      FFailed := True;
      raise;
    end;
    AFirstId := 0;
    if Length(ATones) > 0 then
    begin
      AFirstId := FLastId - Length(ATones) + 1;
    end;
    Result := srScheduled;
  finally
    if not LCommitted then
    begin
      for LIndex := LKept to LCount - 1 do
      begin
        LCandidate[LIndex].Voice.Free;
      end;
    end;
    FBusy := False;
  end;
end;

function TScheduledSynth.StopSelected(const AGroup: Integer; const AId: Int64;
  const AById: Boolean): Integer;
var
  LIndex: Integer;
begin
  RequireReady;
  Result := 0;
  FBusy := True;
  try
    try
      for LIndex := 0 to FCount - 1 do
      begin
        if (AById and (FSlots[LIndex].Id = AId)) or
          (not AById and (FSlots[LIndex].Group = AGroup)) then
        begin
          if FSlots[LIndex].StartFrame >= FNextFrame then
          begin
            Drop(LIndex);
          end
          else
          begin
            FSlots[LIndex].Voice.Release;
          end;
          Inc(Result);
        end;
      end;
      Compact;
    except
      FFailed := True;
      raise;
    end;
  finally
    FBusy := False;
  end;
end;

function TScheduledSynth.StopGroup(const AGroup: Integer): Integer;
begin
  Result := StopSelected(AGroup, 0, False);
end;

function TScheduledSynth.ReleaseVoice(const AId: Int64): Boolean;
begin
  Result := StopSelected(0, AId, True) <> 0;
end;

procedure CheckSample(const AValue: Double);
begin
  RequireFinite(AValue, 'Scheduled sample');
  if Abs(AValue) > MaximumDynamicsMagnitude then
  begin
    raise EAudio.Create('Scheduled sample exceeds magnitude bound');
  end;
end;

procedure TScheduledSynth.Process(out ALeft, ARight: Double);
var
  LIndex: Integer;
  LBus: Integer;
  LLeft: Double;
  LRight: Double;
begin
  RequireReady;
  if FNextFrame = High(Int64) then
  begin
    raise EAudio.Create('Scheduler cannot advance beyond Int64 timeline');
  end;
  FBusy := True;
  try
    try
      for LBus := 0 to High(FInputs) do
      begin
        FInputs[LBus].Left := 0;
        FInputs[LBus].Right := 0;
      end;
      for LIndex := 0 to FCount - 1 do
      begin
        if FSlots[LIndex].StartFrame <= FNextFrame then
        begin
          FSlots[LIndex].Voice.ReadFrame(LLeft, LRight);
          CheckSample(LLeft);
          CheckSample(LRight);
          LBus := FSlots[LIndex].Bus;
          FInputs[LBus].Left := FInputs[LBus].Left + LLeft;
          FInputs[LBus].Right := FInputs[LBus].Right + LRight;
          CheckSample(FInputs[LBus].Left);
          CheckSample(FInputs[LBus].Right);
        end;
      end;
      FGraph.Process(FInputs, LLeft, LRight);
      for LIndex := 0 to FCount - 1 do
      begin
        if FSlots[LIndex].Voice.Finished then
        begin
          Drop(LIndex);
        end;
      end;
      Compact;
      Inc(FNextFrame);
      ALeft := LLeft;
      ARight := LRight;
    except
      FFailed := True;
      raise;
    end;
  finally
    FBusy := False;
  end;
end;

procedure TScheduledSynth.Reset(const AStartFrame: Int64);
var
  LIndex: Integer;
begin
  if FBusy or (AStartFrame < 0) then
  begin
    raise EAudio.Create('Reset requires idle scheduler and nonnegative start');
  end;
  FBusy := True;
  FFailed := True;
  try
    for LIndex := 0 to FCount - 1 do
    begin
      if FSlots[LIndex].Voice <> nil then
      begin
        Drop(LIndex);
      end;
    end;
    Compact;
    FGraph.Reset;
    FNextFrame := AStartFrame;
    FFailed := False;
  finally
    FBusy := False;
  end;
end;

function RenderScheduledFrames(const ASynth: TScheduledSynth;
  const AFrames: Integer): TAudioClip;
var
  LSamples: TAudioSamples;
  LFrame: Integer;
  LCost: Int64;
  LLeft: Double;
  LRight: Double;
begin
  if ASynth = nil then
  begin
    raise EAudio.Create('Scheduled rendering requires a synthesizer');
  end;
  ASynth.RequireReady;
  LCost := Int64(ASynth.ReservedWork) + Length(ASynth.FSlots) + ASynth.FGraph.FrameCost;
  if (AFrames < 0) or (AFrames > MaximumClipSamples div 2) or
    (ASynth.NextFrame > High(Int64) - AFrames) or
    (Int64(AFrames) * LCost > MaximumEffectVisits) then
  begin
    raise EAudio.Create('Scheduled clip exceeds frame or weighted work bound');
  end;
  SetLength(LSamples, AFrames * 2);
  try
    for LFrame := 0 to AFrames - 1 do
    begin
      ASynth.Process(LLeft, LRight);
      if (Abs(LLeft) > MaxSingle) or (Abs(LRight) > MaxSingle) then
      begin
        raise EAudio.Create('Scheduled clip exceeds Single magnitude');
      end;
      LSamples[LFrame * 2] := LLeft;
      LSamples[LFrame * 2 + 1] := LRight;
    end;
    Result := TAudioClip.Create(ASynth.FGraph.SampleRate, 2, LSamples);
  except
    ASynth.FFailed := True;
    raise;
  end;
end;

end.
