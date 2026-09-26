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
unit pythian.source.sample;

{$mode delphi}
{$H+}

interface

uses
  pythian.audio,
  pythian.source;

type
  TSamplePlayback = (spOneShot, spLoop, spSustainLoop);
  TSampleQuality = (sqLinear, sqSinc);

  { Owns a detached copy of [StartFrame, EndFrame) from the supplied clip.
    RootHz plays at original speed, accounting for source/output sample rates.
    Create loops the entire region; CreateLoopRegion adds an intro and tail.
    Sustain NoteOff completes the current traversal; it does not wrap again.
    Sources borrow this factory's region. }
  TSampleSourceFactory = class(TAudioSourceFactory)
  private
    FClip: TAudioClip;
    FRootHz: Double;
    FMaximumStep: Double;
    FPlayback: TSamplePlayback;
    FQuality: TSampleQuality;
    FHasLoopRegion: Boolean;
    FLoopStart: Integer;
    FLoopEnd: Integer;
    procedure Initialize(const AClip: TAudioClip; const AStartFrame, AEndFrame: Integer;
      const ARootHz: Double; const APlayback: TSamplePlayback;
      const AQuality: TSampleQuality; const AMaximumStep: Double);
  public
    constructor Create(const AClip: TAudioClip; const AStartFrame, AEndFrame: Integer;
      const ARootHz: Double; const APlayback: TSamplePlayback = spOneShot;
      const AQuality: TSampleQuality = sqSinc; const AMaximumStep: Double = 8);
    { All frame coordinates refer to the original clip. Plays the region's intro
      once, loops [LoopStart, LoopEnd), then follows its tail after sustain release.
      spLoop ignores note-off. Original Create retains its whole-region behavior. }
    constructor CreateLoopRegion(const AClip: TAudioClip;
      const AStartFrame, AEndFrame, ALoopStart, ALoopEnd: Integer;
      const ARootHz: Double; const APlayback: TSamplePlayback = spSustainLoop;
      const AQuality: TSampleQuality = sqSinc; const AMaximumStep: Double = 8);
    destructor Destroy; override;
    function CreateSource(const ASampleRate: Integer; const ASeed: Cardinal): TAudioSource; override;
    procedure ValidateRange(const AMinimumHz, AMaximumHz: Double;
      const ASampleRate: Integer); override;
    function FrameCost(const ASampleRate: Integer): Integer; override;
    function Channels: Integer; override;
  end;

implementation

uses
  Math,
  pythian.sample.sequence,
  pythian.resample;

type
  TSampleSource = class(TAudioSource)
  private
    FDefinition: TSampleSourceFactory;
    FSampleRate: Integer;
    FPosition: Double;
    FStep: Double;
    FReleased: Boolean;
    FSampler: TSincSampler;
    FSequence: TSampleLoopSequence;
    FMaximumRadius: Integer;
  public
    constructor Create(const ADefinition: TSampleSourceFactory; const ASampleRate: Integer);
    destructor Destroy; override;
    procedure Reset; override;
    procedure NoteOff; override;
    function ReadFrame(const AFrequencyHz: Double; out ALeft, ARight: Double): Boolean; override;
  end;

constructor TSampleSourceFactory.Create(const AClip: TAudioClip;
  const AStartFrame, AEndFrame: Integer; const ARootHz: Double;
  const APlayback: TSamplePlayback; const AQuality: TSampleQuality;
  const AMaximumStep: Double);
begin
  inherited Create;
  Initialize(AClip, AStartFrame, AEndFrame, ARootHz, APlayback, AQuality, AMaximumStep);
end;

constructor TSampleSourceFactory.CreateLoopRegion(const AClip: TAudioClip;
  const AStartFrame, AEndFrame, ALoopStart, ALoopEnd: Integer;
  const ARootHz: Double; const APlayback: TSamplePlayback;
  const AQuality: TSampleQuality; const AMaximumStep: Double);
begin
  inherited Create;
  if (ALoopStart < AStartFrame) or (ALoopEnd <= ALoopStart) or
    (ALoopEnd > AEndFrame) or not (APlayback in [spLoop, spSustainLoop]) then
  begin
    raise EAudio.Create('Interior loop requires contained nonempty bounds and loop playback');
  end;
  Initialize(AClip, AStartFrame, AEndFrame, ARootHz, APlayback, AQuality, AMaximumStep);
  FLoopStart := ALoopStart - AStartFrame;
  FLoopEnd := ALoopEnd - AStartFrame;
  FHasLoopRegion := True;
end;

procedure TSampleSourceFactory.Initialize(const AClip: TAudioClip;
  const AStartFrame, AEndFrame: Integer; const ARootHz: Double;
  const APlayback: TSamplePlayback; const AQuality: TSampleQuality;
  const AMaximumStep: Double);
var
  LSamples: TAudioSamples;
  LFrame: Integer;
  LChannel: Integer;
begin
  if AClip = nil then
  begin
    raise EAudio.Create('Sample source requires a clip');
  end;
  RequireFinite(ARootHz, 'Sample root frequency');
  RequireFinite(AMaximumStep, 'Maximum sample step');
  if (AStartFrame < 0) or (AEndFrame <= AStartFrame) or (AEndFrame > AClip.FrameCount) or
    (ARootHz <= 0) or (ARootHz > MaximumSampleRate) or
    (AMaximumStep <= 0) or (AMaximumStep > MaximumSourceStep) or
    not (APlayback in [spOneShot, spLoop, spSustainLoop]) or
    not (AQuality in [sqLinear, sqSinc]) then
  begin
    raise EAudio.Create('Sample region/root/playback/step outside source contract');
  end;
  SetLength(LSamples, (AEndFrame - AStartFrame) * AClip.Channels);
  for LFrame := AStartFrame to AEndFrame - 1 do
  begin
    for LChannel := 0 to AClip.Channels - 1 do
    begin
      LSamples[(LFrame - AStartFrame) * AClip.Channels + LChannel] :=
        AClip.SampleAt(LFrame, LChannel);
    end;
  end;
  FClip := TAudioClip.Create(AClip.SampleRate, AClip.Channels, LSamples);
  FRootHz := ARootHz;
  FMaximumStep := AMaximumStep;
  FPlayback := APlayback;
  FQuality := AQuality;
end;

destructor TSampleSourceFactory.Destroy;
begin
  FClip.Free;
  inherited;
end;

procedure TSampleSourceFactory.ValidateRange(const AMinimumHz, AMaximumHz: Double;
  const ASampleRate: Integer);
begin
  inherited;
  if (AMaximumHz / FRootHz) * (FClip.SampleRate / ASampleRate) > FMaximumStep then
  begin
    raise EAudio.Create('Sample pitch range exceeds configured source-step bound');
  end;
end;

function TSampleSourceFactory.FrameCost(const ASampleRate: Integer): Integer;
begin
  ValidateAudioFormat(ASampleRate, Channels);
  if FQuality = sqSinc then
  begin
    Result := Channels * SincTapBudget(FMaximumStep);
  end
  else
  begin
    Result := Channels * 2;
  end;
end;

function TSampleSourceFactory.Channels: Integer;
begin
  Result := FClip.Channels;
end;

function TSampleSourceFactory.CreateSource(const ASampleRate: Integer;
  const ASeed: Cardinal): TAudioSource;
begin
  ValidateAudioFormat(ASampleRate, Channels);
  Result := TSampleSource.Create(Self, ASampleRate);
end;

constructor TSampleSource.Create(const ADefinition: TSampleSourceFactory;
  const ASampleRate: Integer);
var
  LBoundary: TSampleBoundary;
begin
  inherited Create;
  FDefinition := ADefinition;
  FSampleRate := ASampleRate;
  FMaximumRadius := 1;
  if FDefinition.FHasLoopRegion then
  begin
    FSequence := TSampleLoopSequence.Create(FDefinition.FClip,
      FDefinition.FLoopStart, FDefinition.FLoopEnd);
  end;
  if FDefinition.FQuality = sqSinc then
  begin
    FMaximumRadius := SincTapBudget(FDefinition.FMaximumStep) div 2;
    LBoundary := sbClamp;
    if FDefinition.FPlayback <> spOneShot then
    begin
      LBoundary := sbWrap;
    end;
    if FSequence <> nil then
    begin
      FSampler := TSincSampler.CreateLoopSequence(FSequence, 0);
    end
    else
    begin
      FSampler := TSincSampler.Create(FDefinition.FClip, 0, LBoundary);
    end;
  end;
  Reset;
end;

destructor TSampleSource.Destroy;
begin
  FSampler.Free;
  FSequence.Free;
  inherited;
end;

procedure TSampleSource.Reset;
begin
  FPosition := 0;
  FStep := -1;
  FReleased := False;
  if FSequence <> nil then
  begin
    FSequence.Reset;
  end;
end;

procedure TSampleSource.NoteOff;
begin
  if (FSequence <> nil) and (FDefinition.FPlayback = spSustainLoop) and not FReleased then
  begin
    FSequence.ReleaseAt(FPosition);
  end;
  FReleased := True;
end;

function TSampleSource.ReadFrame(const AFrequencyHz: Double;
  out ALeft, ARight: Double): Boolean;
var
  LStep: Double;
  LFrame: Integer;
  LNext: Integer;
  LFraction: Double;
  LClip: TAudioClip;
  LEndFrame: Integer;
begin
  FDefinition.ValidateRange(AFrequencyHz, AFrequencyHz, FSampleRate);
  LClip := FDefinition.FClip;
  ALeft := 0;
  ARight := 0;
  LEndFrame := LClip.FrameCount;
  if FSequence <> nil then
  begin
    LEndFrame := FSequence.EndFrame;
  end;
  if FPosition >= LEndFrame then
  begin
    Exit(False);
  end;
  LStep := (AFrequencyHz / FDefinition.FRootHz) * (LClip.SampleRate / FSampleRate);
  if FSampler <> nil then
  begin
    if LStep <> FStep then
    begin
      FSampler.SetSourceStep(LStep);
    end;
    FSampler.ReadFrame(FPosition, ALeft, ARight);
  end
  else
  begin
    LFrame := Floor(FPosition);
    LFraction := FPosition - LFrame;
    LNext := LFrame + 1;
    if FSequence <> nil then
    begin
      LFrame := FSequence.FrameAt(LFrame);
      LNext := FSequence.FrameAt(LNext);
    end
    else if LNext = LClip.FrameCount then
    begin
      if FDefinition.FPlayback = spOneShot then
      begin
        LNext := LFrame;
      end
      else
      begin
        LNext := 0;
      end;
    end;
    ALeft := (1 - LFraction) * LClip.SampleAt(LFrame, 0) +
      LFraction * LClip.SampleAt(LNext, 0);
    ARight := ALeft;
    if LClip.Channels = 2 then
    begin
      ARight := (1 - LFraction) * LClip.SampleAt(LFrame, 1) +
        LFraction * LClip.SampleAt(LNext, 1);
    end;
  end;
  FStep := LStep;
  FPosition := FPosition + LStep;
  if FSequence <> nil then
  begin
    FPosition := FSequence.RebasePosition(FPosition, FMaximumRadius);
  end
  else if (FDefinition.FPlayback = spLoop) or
    ((FDefinition.FPlayback = spSustainLoop) and not FReleased) then
  begin
    FPosition := FPosition - Floor(FPosition / LClip.FrameCount) * LClip.FrameCount;
  end;
  Result := True;
end;

end.
