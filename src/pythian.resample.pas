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
unit pythian.resample;

{$mode delphi}
{$H+}

interface

uses
  pythian.audio,
  pythian.sample.sequence;

const
  ResampleVersion = 1;
  MaximumSourceStep = 64;
  MaximumResampleVisits = 250000000;

type
  TSampleBoundary = (sbClamp, sbWrap);
  { Borrows an immutable clip. Fixed-rate, centered Blackman-windowed sinc;
    edge samples extend constantly. Mono returns the same value in both outputs.
    SourceStep is source frames per output frame, not a frequency in Hz. }
  TSincSampler = class
  strict private
    FSource: TAudioClip;
    FCutoff: Double;
    FRadius: Integer;
    FBoundary: TSampleBoundary;
    FLoopSequence: TSampleLoopSequence;
  public
    constructor Create(const ASource: TAudioClip; const ASourceStep: Double;
      const ABoundary: TSampleBoundary = sbClamp);
    { Borrows the loop sequence and its clip; both must outlive this sampler. }
    constructor CreateLoopSequence(const ASequence: TSampleLoopSequence;
      const ASourceStep: Double);
    procedure SetSourceStep(const ASourceStep: Double);
    procedure ReadFrame(const APosition: Double; out ALeft, ARight: Double);
    property Radius: Integer read FRadius;
  end;

{ Conservative multiply/accumulate budget per output frame and channel. }
function SincTapBudget(const ASourceStep: Double): Integer;
{ Shared fixed-support kernel. Caller supplies the validated cutoff/radius
  from the sampler policy: 0.94/max(1,step), ceil(64/cutoff). }
function SincKernelWeight(const ADistance, ACutoff: Double; const ARadius: Integer): Double;
{ Ceiling duration in output frames; validates format, scalar-sample and work
  budgets before allocation. Equal rates make an exact detached copy. }
procedure PlanResample(const ASourceFrames, AChannels, ASourceRate, AOutputRate: Integer;
  out AOutputFrames: Integer; out AVisits: Int64);
function ResampleClip(const ASource: TAudioClip; const AOutputRate: Integer): TAudioClip;

implementation

uses
  Math;

function FilterCutoff(const ASourceStep: Double): Double;
begin
  RequireFinite(ASourceStep, 'Source step');
  if (ASourceStep < 0) or (ASourceStep > MaximumSourceStep) then
  begin
    raise EAudio.Create('Source step must be 0..64');
  end;
  Result := 0.94 / Max(1, ASourceStep);
end;

function SincTapBudget(const ASourceStep: Double): Integer;
begin
  Result := 2 * Ceil(64 / FilterCutoff(ASourceStep)) + 1;
end;

function SincKernelWeight(const ADistance, ACutoff: Double; const ARadius: Integer): Double;
var
  LAngle: Double;
begin
  if Abs(ADistance) >= ARadius then
  begin
    Exit(0);
  end;
  LAngle := Pi * ACutoff * ADistance;
  if Abs(LAngle) < 1E-12 then
  begin
    Result := ACutoff;
  end
  else
  begin
    Result := ACutoff * Sin(LAngle) / LAngle;
  end;
  Result := Result * (0.42 + 0.5 * Cos(Pi * ADistance / ARadius) +
    0.08 * Cos(2 * Pi * ADistance / ARadius));
end;

constructor TSincSampler.Create(const ASource: TAudioClip; const ASourceStep: Double;
  const ABoundary: TSampleBoundary);
begin
  inherited Create;
  if ASource = nil then
  begin
    raise EAudio.Create('Sinc sampler requires a source');
  end;
  if ASource.FrameCount = 0 then
  begin
    raise EAudio.Create('Sinc sampler requires nonempty source frames');
  end;
  if not (ABoundary in [sbClamp, sbWrap]) then
  begin
    raise EAudio.Create('Unknown sample boundary');
  end;
  SetSourceStep(ASourceStep);
  FSource := ASource;
  FBoundary := ABoundary;
end;

procedure TSincSampler.SetSourceStep(const ASourceStep: Double);
var
  LCutoff: Double;
begin
  LCutoff := FilterCutoff(ASourceStep);
  FRadius := Ceil(64 / LCutoff);
  FCutoff := LCutoff;
end;

constructor TSincSampler.CreateLoopSequence(const ASequence: TSampleLoopSequence;
  const ASourceStep: Double);
begin
  inherited Create;
  if ASequence = nil then
  begin
    raise EAudio.Create('Sinc sampler requires a loop sequence');
  end;
  SetSourceStep(ASourceStep);
  FSource := ASequence.Source;
  FLoopSequence := ASequence;
end;

procedure TSincSampler.ReadFrame(const APosition: Double; out ALeft, ARight: Double);
var
  LCenter: Integer;
  LIndex: Integer;
  LFrame: Integer;
  LDistance: Double;
  LWeight: Double;
  LSum: Double;
  LLeft: Double;
  LRight: Double;
  LEndFrame: Integer;
begin
  RequireFinite(APosition, 'Source position');
  LEndFrame := FSource.FrameCount;
  if FLoopSequence <> nil then
  begin
    LEndFrame := FLoopSequence.EndFrame;
  end;
  if (APosition < 0) or (APosition >= LEndFrame) then
  begin
    raise EAudio.Create('Sinc position outside source duration');
  end;
  LCenter := Floor(APosition);
  LSum := 0;
  LLeft := 0;
  LRight := 0;
  for LIndex := LCenter - FRadius to LCenter + FRadius do
  begin
    LDistance := APosition - LIndex;
    if Abs(LDistance) >= FRadius then
    begin
      Continue;
    end;
    LWeight := SincKernelWeight(LDistance, FCutoff, FRadius);
    if FLoopSequence <> nil then
    begin
      LFrame := FLoopSequence.FrameAt(LIndex);
    end
    else if FBoundary = sbWrap then
    begin
      LFrame := LIndex mod FSource.FrameCount;
      if LFrame < 0 then
      begin
        Inc(LFrame, FSource.FrameCount);
      end;
    end
    else
    begin
      LFrame := Max(0, Min(FSource.FrameCount - 1, LIndex));
    end;
    LSum := LSum + LWeight;
    LLeft := LLeft + LWeight * FSource.SampleAt(LFrame, 0);
    if FSource.Channels = 2 then
    begin
      LRight := LRight + LWeight * FSource.SampleAt(LFrame, 1);
    end;
  end;
  { Per-phase DC normalization; no peak normalization or clipping. }
  ALeft := LLeft / LSum;
  if FSource.Channels = 2 then
  begin
    ARight := LRight / LSum;
  end
  else
  begin
    ARight := ALeft;
  end;
end;

procedure PlanResample(const ASourceFrames, AChannels, ASourceRate, AOutputRate: Integer;
  out AOutputFrames: Integer; out AVisits: Int64);
var
  LFrames: Int64;
  LVisits: Int64;
  LTaps: Integer;
begin
  AOutputFrames := 0;
  AVisits := 0;
  ValidateAudioFormat(ASourceRate, AChannels);
  ValidateAudioFormat(AOutputRate, AChannels);
  if (ASourceFrames < 0) or (ASourceFrames > MaximumClipSamples div AChannels) then
  begin
    raise EAudio.Create('Resampling source exceeds sample budget');
  end;
  LFrames := (Int64(ASourceFrames) * AOutputRate + ASourceRate - 1) div ASourceRate;
  if LFrames > MaximumClipSamples div AChannels then
  begin
    raise EAudio.Create('Resampling output exceeds sample budget');
  end;
  LTaps := 1;
  if AOutputRate <> ASourceRate then
  begin
    LTaps := SincTapBudget(ASourceRate / AOutputRate);
  end;
  LVisits := LFrames * AChannels * LTaps;
  if LVisits > MaximumResampleVisits then
  begin
    raise EAudio.Create('Resampling exceeds tap-visit budget');
  end;
  AOutputFrames := LFrames;
  AVisits := LVisits;
end;

function ResampleClip(const ASource: TAudioClip; const AOutputRate: Integer): TAudioClip;
var
  LFrames: Integer;
  LVisits: Int64;
  LFrame: Integer;
  LLeft: Double;
  LRight: Double;
  LPosition: Double;
  LSamples: TAudioSamples;
  LSampler: TSincSampler;
begin
  if ASource = nil then
  begin
    raise EAudio.Create('Resampling requires a source');
  end;
  PlanResample(ASource.FrameCount, ASource.Channels, ASource.SampleRate, AOutputRate,
    LFrames, LVisits);
  if ASource.SampleRate = AOutputRate then
  begin
    Exit(TAudioClip.Create(AOutputRate, ASource.Channels, ASource.CopySamples));
  end;
  SetLength(LSamples, LFrames * ASource.Channels);
  if LFrames > 0 then
  begin
    LSampler := TSincSampler.Create(ASource, ASource.SampleRate / AOutputRate);
    try
      for LFrame := 0 to LFrames - 1 do
      begin
        { Integer product preserves exact anchors and avoids accumulated drift. }
        LPosition := (Int64(LFrame) * ASource.SampleRate) / AOutputRate;
        LSampler.ReadFrame(LPosition, LLeft, LRight);
        if (Abs(LLeft) > MaxSingle) or (Abs(LRight) > MaxSingle) then
        begin
          raise EAudio.Create('Resampled audio exceeds Single range');
        end;
        LSamples[LFrame * ASource.Channels] := LLeft;
        if ASource.Channels = 2 then
        begin
          LSamples[LFrame * 2 + 1] := LRight;
        end;
      end;
    finally
      LSampler.Free;
    end;
  end;
  Result := TAudioClip.Create(AOutputRate, ASource.Channels, LSamples);
end;

end.
