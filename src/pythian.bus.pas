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
unit pythian.bus;

{$mode delphi}
{$H+}

interface

uses
  pythian.audio,
  pythian.effects,
  pythian.dynamics;

const
  BusContractVersion = 1;
  MaximumBuses = 32;
  MaximumBusSends = 1024;

type
  TStereoFrame = record
    Left: Double;
    Right: Double;
  end;
  TBusFrames = array of TStereoFrame;
  TBusClips = array of TAudioClip;
  TBusSettings = record
    Gain: Double;
    SmoothingSeconds: Double;
  end;
  TSendTap = (stPreFader, stPostFader);

  { Buses are ordered inputs/submixes followed by the master (last index).
    Sends point only to larger indices. Delayed feedback belongs inside effects.
    The graph owns its chains, stages and gain smoothers. One calling thread. }
  TBusGraph = class
  private
    type
      TBus = record
        Chain: TEffectChain;
        Gain: TGainSmoother;
      end;
      TSend = record
        Source: Integer;
        Destination: Integer;
        Tap: TSendTap;
        Gain: TGainSmoother;
      end;
  private
    FSampleRate: Integer;
    FBuses: array of TBus;
    FSends: array of TSend;
    FBusy: Boolean;
    FFailed: Boolean;
    procedure RequireReady;
    procedure CheckBus(const ABus: Integer);
    function GetBusCount: Integer;
    function GetFrameCost: Integer;
  public
    constructor Create(const ASampleRate: Integer; const ASettings: array of TBusSettings);
    destructor Destroy; override;
    procedure AddEffect(const ABus: Integer; const AEffect: TAudioEffect);
    function AddSend(const ASource, ADestination: Integer; const ATap: TSendTap;
      const AInitialGain, ASmoothingSeconds: Double): Integer;
    procedure SetBusGain(const ABus: Integer; const AGain: Double);
    procedure SetSendGain(const ASend: Integer; const AGain: Double);
    procedure Reset;
    procedure Process(const AInputs: array of TStereoFrame;
      out AOutputLeft, AOutputRight: Double);
    property SampleRate: Integer read FSampleRate;
    property BusCount: Integer read GetBusCount;
    property FrameCost: Integer read GetFrameCost;
    property Failed: Boolean read FFailed;
  end;

function DefaultBusSettings: TBusSettings;
{ All clips start at this call's first frame; nil/short clips supply zeros.
  Continues graph history and returns owned stereo master output. }
function RenderBusClips(const AClips: array of TAudioClip; const AGraph: TBusGraph;
  const ATailFrames: Integer = 0): TAudioClip;

implementation

uses
  Math;

procedure CheckMagnitude(const AValue: Double);
begin
  RequireFinite(AValue, 'Bus sample');
  if Abs(AValue) > MaximumDynamicsMagnitude then
  begin
    raise EAudio.Create('Bus sample exceeds magnitude bound');
  end;
end;

function DefaultBusSettings: TBusSettings;
begin
  Result.Gain := 1;
  Result.SmoothingSeconds := 0.035;
end;

constructor TBusGraph.Create(const ASampleRate: Integer;
  const ASettings: array of TBusSettings);
var
  LIndex: Integer;
begin
  inherited Create;
  ValidateAudioFormat(ASampleRate, 2);
  if (Length(ASettings) < 1) or (Length(ASettings) > MaximumBuses) then
  begin
    raise EAudio.Create('Bus count must be 1..32');
  end;
  FSampleRate := ASampleRate;
  SetLength(FBuses, Length(ASettings));
  for LIndex := 0 to High(FBuses) do
  begin
    FBuses[LIndex].Gain := TGainSmoother.Create(ASampleRate,
      ASettings[LIndex].Gain, ASettings[LIndex].SmoothingSeconds);
    FBuses[LIndex].Chain := TEffectChain.Create(ASampleRate);
  end;
end;

destructor TBusGraph.Destroy;
var
  LIndex: Integer;
begin
  for LIndex := 0 to High(FSends) do
  begin
    FSends[LIndex].Gain.Free;
  end;
  for LIndex := 0 to High(FBuses) do
  begin
    FBuses[LIndex].Chain.Free;
    FBuses[LIndex].Gain.Free;
  end;
  inherited;
end;

procedure TBusGraph.RequireReady;
begin
  if FBusy or FFailed then
  begin
    raise EAudio.Create('Bus graph is active or requires Reset after failure');
  end;
end;

procedure TBusGraph.CheckBus(const ABus: Integer);
begin
  if (ABus < 0) or (ABus >= Length(FBuses)) then
  begin
    raise EAudio.Create('Bus index outside graph');
  end;
end;

function TBusGraph.GetBusCount: Integer;
begin
  Result := Length(FBuses);
end;

function TBusGraph.GetFrameCost: Integer;
var
  LIndex: Integer;
begin
  { Includes scans of the send list; cost is a policy weight, not CPU cycles. }
  Result := Length(FBuses) * (3 + Length(FSends)) + Length(FSends) * 3;
  for LIndex := 0 to High(FBuses) do
  begin
    Inc(Result, FBuses[LIndex].Chain.FrameCost);
  end;
end;

procedure TBusGraph.AddEffect(const ABus: Integer; const AEffect: TAudioEffect);
begin
  RequireReady;
  CheckBus(ABus);
  FBusy := True;
  try
    FBuses[ABus].Chain.Add(AEffect);
  finally
    FBusy := False;
  end;
end;

function TBusGraph.AddSend(const ASource, ADestination: Integer; const ATap: TSendTap;
  const AInitialGain, ASmoothingSeconds: Double): Integer;
var
  LIndex: Integer;
  LGain: TGainSmoother;
begin
  RequireReady;
  CheckBus(ASource);
  CheckBus(ADestination);
  if (ASource >= ADestination) or
    not (ATap in [stPreFader, stPostFader]) or (Length(FSends) >= MaximumBusSends) then
  begin
    raise EAudio.Create('Send must point forward with a valid tap within capacity');
  end;
  for LIndex := 0 to High(FSends) do
  begin
    if (FSends[LIndex].Source = ASource) and
      (FSends[LIndex].Destination = ADestination) and (FSends[LIndex].Tap = ATap) then
    begin
      raise EAudio.Create('Duplicate bus send');
    end;
  end;
  LGain := TGainSmoother.Create(FSampleRate, AInitialGain, ASmoothingSeconds);
  try
    Result := Length(FSends);
    SetLength(FSends, Result + 1);
    FSends[Result].Source := ASource;
    FSends[Result].Destination := ADestination;
    FSends[Result].Tap := ATap;
    FSends[Result].Gain := LGain;
    LGain := nil;
  finally
    LGain.Free;
  end;
end;

procedure TBusGraph.SetBusGain(const ABus: Integer; const AGain: Double);
begin
  RequireReady;
  CheckBus(ABus);
  FBuses[ABus].Gain.SetTarget(AGain);
end;

procedure TBusGraph.SetSendGain(const ASend: Integer; const AGain: Double);
begin
  RequireReady;
  if (ASend < 0) or (ASend >= Length(FSends)) then
  begin
    raise EAudio.Create('Send index outside graph');
  end;
  FSends[ASend].Gain.SetTarget(AGain);
end;

procedure TBusGraph.Reset;
var
  LIndex: Integer;
begin
  if FBusy then
  begin
    raise EAudio.Create('Cannot reset an active bus graph');
  end;
  FFailed := True;
  FBusy := True;
  try
    for LIndex := 0 to High(FBuses) do
    begin
      FBuses[LIndex].Chain.Reset;
      FBuses[LIndex].Gain.Reset;
    end;
    for LIndex := 0 to High(FSends) do
    begin
      FSends[LIndex].Gain.Reset;
    end;
    FFailed := False;
  finally
    FBusy := False;
  end;
end;

procedure TBusGraph.Process(const AInputs: array of TStereoFrame;
  out AOutputLeft, AOutputRight: Double);
var
  LFrames: array[0..MaximumBuses - 1] of TStereoFrame;
  LBus: Integer;
  LSend: Integer;
  LDestination: Integer;
  LGain: Double;
  LPreLeft: Double;
  LPreRight: Double;
  LPostLeft: Double;
  LPostRight: Double;
  LSendLeft: Double;
  LSendRight: Double;
begin
  RequireReady;
  if Length(AInputs) <> Length(FBuses) then
  begin
    raise EAudio.Create('Exactly one stereo input per bus is required');
  end;
  { Validate and detach every input before any stage advances. }
  for LBus := 0 to High(FBuses) do
  begin
    CheckMagnitude(AInputs[LBus].Left);
    CheckMagnitude(AInputs[LBus].Right);
    LFrames[LBus] := AInputs[LBus];
  end;
  FBusy := True;
  try
    try
      for LBus := 0 to High(FBuses) do
      begin
        FBuses[LBus].Chain.Process(LFrames[LBus].Left, LFrames[LBus].Right,
          LPreLeft, LPreRight);
        LGain := FBuses[LBus].Gain.Next;
        LPostLeft := LPreLeft * LGain;
        LPostRight := LPreRight * LGain;
        CheckMagnitude(LPostLeft);
        CheckMagnitude(LPostRight);
        for LSend := 0 to High(FSends) do
        begin
          if FSends[LSend].Source <> LBus then
          begin
            Continue;
          end;
          LGain := FSends[LSend].Gain.Next;
          if FSends[LSend].Tap = stPreFader then
          begin
            LSendLeft := LPreLeft * LGain;
            LSendRight := LPreRight * LGain;
          end
          else
          begin
            LSendLeft := LPostLeft * LGain;
            LSendRight := LPostRight * LGain;
          end;
          LDestination := FSends[LSend].Destination;
          LFrames[LDestination].Left := LFrames[LDestination].Left + LSendLeft;
          LFrames[LDestination].Right := LFrames[LDestination].Right + LSendRight;
          CheckMagnitude(LFrames[LDestination].Left);
          CheckMagnitude(LFrames[LDestination].Right);
        end;
      end;
      AOutputLeft := LPostLeft;
      AOutputRight := LPostRight;
    except
      FFailed := True;
      raise;
    end;
  finally
    FBusy := False;
  end;
end;

function RenderBusClips(const AClips: array of TAudioClip; const AGraph: TBusGraph;
  const ATailFrames: Integer): TAudioClip;
var
  LFrames: Int64;
  LBus: Integer;
  LFrame: Integer;
  LInputs: TBusFrames;
  LSamples: TAudioSamples;
  LLeft: Double;
  LRight: Double;
begin
  if AGraph = nil then
  begin
    raise EAudio.Create('Bus rendering requires a graph');
  end;
  AGraph.RequireReady;
  if (Length(AClips) <> AGraph.BusCount) or (ATailFrames < 0) then
  begin
    raise EAudio.Create('Bus clip count or tail length is invalid');
  end;
  LFrames := 0;
  for LBus := 0 to High(AClips) do
  begin
    if AClips[LBus] = nil then
    begin
      Continue;
    end;
    if AClips[LBus].SampleRate <> AGraph.SampleRate then
    begin
      raise EAudio.Create('Bus clip sample rate must match graph');
    end;
    if AClips[LBus].FrameCount > LFrames then
    begin
      LFrames := AClips[LBus].FrameCount;
    end;
  end;
  Inc(LFrames, ATailFrames);
  if (LFrames > MaximumClipSamples div 2) or
    (LFrames * AGraph.FrameCost > MaximumEffectVisits) then
  begin
    raise EAudio.Create('Bus render exceeds output size or weighted work bound');
  end;
  SetLength(LInputs, AGraph.BusCount);
  SetLength(LSamples, LFrames * 2);
  try
    for LFrame := 0 to LFrames - 1 do
    begin
      for LBus := 0 to High(AClips) do
      begin
        LInputs[LBus].Left := 0;
        LInputs[LBus].Right := 0;
        if (AClips[LBus] <> nil) and (LFrame < AClips[LBus].FrameCount) then
        begin
          LInputs[LBus].Left := AClips[LBus].SampleAt(LFrame, 0);
          LInputs[LBus].Right := LInputs[LBus].Left;
          if AClips[LBus].Channels = 2 then
          begin
            LInputs[LBus].Right := AClips[LBus].SampleAt(LFrame, 1);
          end;
        end;
      end;
      AGraph.Process(LInputs, LLeft, LRight);
      if (Abs(LLeft) > MaxSingle) or (Abs(LRight) > MaxSingle) then
      begin
        raise EAudio.Create('Bus render output exceeds Single range');
      end;
      LSamples[LFrame * 2] := LLeft;
      LSamples[LFrame * 2 + 1] := LRight;
    end;
    Result := TAudioClip.Create(AGraph.SampleRate, 2, LSamples);
  except
    AGraph.FFailed := True;
    raise;
  end;
end;

end.

