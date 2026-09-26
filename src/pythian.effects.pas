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
unit pythian.effects;

{$mode delphi}
{$H+}

interface

uses
  pythian.audio,
  pythian.biquad,
  pythian.dynamics;

const
  MaximumEffects = 32;
  MaximumEffectVisits = 200000000;

type
  TEffectChain = class;
  TAudioEffect = class abstract
  private
    FOwner: TEffectChain;
    FSampleRate: Integer;
  public
    constructor Create(const ASampleRate: Integer);
    procedure Reset; virtual; abstract;
    procedure Process(const ALeft, ARight: Double; out AOutputLeft, AOutputRight: Double);
      virtual; abstract;
    function FrameCost: Integer; virtual; abstract;
    property SampleRate: Integer read FSampleRate;
  end;

  TBiquadEffect = class(TAudioEffect)
  private
    FFilter: TBiquadFilter;
  public
    constructor Create(const ASampleRate: Integer; const ASettings: TBiquadSettings);
    destructor Destroy; override;
    procedure Reset; override;
    procedure SetSettings(const ASettings: TBiquadSettings);
    procedure Process(const ALeft, ARight: Double; out AOutputLeft, AOutputRight: Double); override;
    function FrameCost: Integer; override;
  end;

  TCompressorEffect = class(TAudioEffect)
  private
    FCompressor: TStereoCompressor;
  public
    constructor Create(const ASampleRate: Integer; const ASettings: TCompressorSettings);
    destructor Destroy; override;
    procedure Reset; override;
    procedure Process(const ALeft, ARight: Double; out AOutputLeft, AOutputRight: Double); override;
    function FrameCost: Integer; override;
  end;

  TLimiterEffect = class(TAudioEffect)
  private
    FLimiter: TStereoPeakLimiter;
  public
    constructor Create(const ASampleRate: Integer; const ACeilingDb, AReleaseSeconds: Double);
    destructor Destroy; override;
    procedure Reset; override;
    procedure Process(const ALeft, ARight: Double; out AOutputLeft, AOutputRight: Double); override;
    function FrameCost: Integer; override;
  end;

  TGainEffect = class(TAudioEffect)
  private
    FGain: TGainSmoother;
  public
    constructor Create(const ASampleRate: Integer; const AInitialGain, ASmoothingSeconds: Double);
    destructor Destroy; override;
    procedure SetTarget(const AGain: Double);
    procedure Reset; override;
    procedure Process(const ALeft, ARight: Double; out AOutputLeft, AOutputRight: Double); override;
    function FrameCost: Integer; override;
  end;

  { Owns effects after successful Add. Processing failure poisons the chain:
    earlier stages may have advanced, so Reset is required before reuse.
    Invalid input rejected before stages does not poison. Calls are not reentrant. }
  TEffectChain = class
  private
    FSampleRate: Integer;
    FEffects: array of TAudioEffect;
    FCost: Integer;
    FFailed: Boolean;
    FBusy: Boolean;
  public
    constructor Create(const ASampleRate: Integer);
    destructor Destroy; override;
    procedure Add(const AEffect: TAudioEffect);
    procedure Reset;
    procedure Process(const ALeft, ARight: Double; out AOutputLeft, AOutputRight: Double);
    property SampleRate: Integer read FSampleRate;
    property FrameCost: Integer read FCost;
    property Failed: Boolean read FFailed;
  end;

{ Borrows source/chain; continues chain history. Returns owned stereo output.
  TailFrames explicitly process zeros after input. Bounds checked before processing. }
function RenderEffectClip(const ASource: TAudioClip; const AChain: TEffectChain;
  const ATailFrames: Integer = 0): TAudioClip;

implementation

uses
  Math;

constructor TAudioEffect.Create(const ASampleRate: Integer);
begin
  inherited Create;
  ValidateAudioFormat(ASampleRate, 2);
  FSampleRate := ASampleRate;
end;

constructor TBiquadEffect.Create(const ASampleRate: Integer; const ASettings: TBiquadSettings);
begin
  inherited Create(ASampleRate);
  FFilter := TBiquadFilter.Create(ASampleRate, ASettings, 2);
end;

destructor TBiquadEffect.Destroy;
begin
  FFilter.Free;
  inherited;
end;

procedure TBiquadEffect.Reset;
begin
  FFilter.Reset;
end;

procedure TBiquadEffect.SetSettings(const ASettings: TBiquadSettings);
begin
  FFilter.SetSettings(ASettings);
end;

procedure TBiquadEffect.Process(const ALeft, ARight: Double;
  out AOutputLeft, AOutputRight: Double);
begin
  FFilter.ProcessStereo(ALeft, ARight, AOutputLeft, AOutputRight);
end;

function TBiquadEffect.FrameCost: Integer;
begin
  Result := 2;
end;

constructor TCompressorEffect.Create(const ASampleRate: Integer;
  const ASettings: TCompressorSettings);
begin
  inherited Create(ASampleRate);
  FCompressor := TStereoCompressor.Create(ASampleRate, ASettings);
end;

destructor TCompressorEffect.Destroy;
begin
  FCompressor.Free;
  inherited;
end;

procedure TCompressorEffect.Reset;
begin
  FCompressor.Reset;
end;

procedure TCompressorEffect.Process(const ALeft, ARight: Double;
  out AOutputLeft, AOutputRight: Double);
begin
  FCompressor.Process(ALeft, ARight, AOutputLeft, AOutputRight);
end;

function TCompressorEffect.FrameCost: Integer;
begin
  Result := 2;
end;

constructor TLimiterEffect.Create(const ASampleRate: Integer;
  const ACeilingDb, AReleaseSeconds: Double);
begin
  inherited Create(ASampleRate);
  FLimiter := TStereoPeakLimiter.Create(ASampleRate, ACeilingDb, AReleaseSeconds);
end;

destructor TLimiterEffect.Destroy;
begin
  FLimiter.Free;
  inherited;
end;

procedure TLimiterEffect.Reset;
begin
  FLimiter.Reset;
end;

procedure TLimiterEffect.Process(const ALeft, ARight: Double;
  out AOutputLeft, AOutputRight: Double);
begin
  FLimiter.Process(ALeft, ARight, AOutputLeft, AOutputRight);
end;

function TLimiterEffect.FrameCost: Integer;
begin
  Result := 2;
end;

constructor TGainEffect.Create(const ASampleRate: Integer;
  const AInitialGain, ASmoothingSeconds: Double);
begin
  inherited Create(ASampleRate);
  FGain := TGainSmoother.Create(ASampleRate, AInitialGain, ASmoothingSeconds);
end;

destructor TGainEffect.Destroy;
begin
  FGain.Free;
  inherited;
end;

procedure TGainEffect.Reset;
begin
  FGain.Reset;
end;

procedure TGainEffect.SetTarget(const AGain: Double);
begin
  FGain.SetTarget(AGain);
end;

procedure TGainEffect.Process(const ALeft, ARight: Double;
  out AOutputLeft, AOutputRight: Double);
var
  LGain: Double;
  LLeft: Double;
  LRight: Double;
begin
  RequireFinite(ALeft, 'Gain input');
  RequireFinite(ARight, 'Gain input');
  LGain := FGain.Next;
  LLeft := ALeft * LGain;
  LRight := ARight * LGain;
  AOutputLeft := LLeft;
  AOutputRight := LRight;
end;

function TGainEffect.FrameCost: Integer;
begin
  Result := 2;
end;

constructor TEffectChain.Create(const ASampleRate: Integer);
begin
  inherited Create;
  ValidateAudioFormat(ASampleRate, 2);
  FSampleRate := ASampleRate;
  FCost := 1;
end;

destructor TEffectChain.Destroy;
var
  LIndex: Integer;
begin
  for LIndex := 0 to High(FEffects) do
  begin
    FEffects[LIndex].FOwner := nil;
    FEffects[LIndex].Free;
  end;
  inherited;
end;

procedure TEffectChain.Add(const AEffect: TAudioEffect);
var
  LCost: Integer;
begin
  if FBusy or FFailed then
  begin
    raise EAudio.Create('Effect chain must be idle and healthy before adding effects');
  end;
  if AEffect = nil then
  begin
    raise EAudio.Create('Effect is required');
  end;
  if (AEffect.FOwner <> nil) or (AEffect.SampleRate <> FSampleRate) or
    (Length(FEffects) >= MaximumEffects) then
  begin
    raise EAudio.Create('Effect is already owned, mismatched, or exceeds chain capacity');
  end;
  LCost := AEffect.FrameCost;
  if (LCost < 1) or (LCost > 1000000) then
  begin
    raise EAudio.Create('Invalid effect frame cost');
  end;
  SetLength(FEffects, Length(FEffects) + 1);
  FEffects[High(FEffects)] := AEffect;
  AEffect.FOwner := Self;
  Inc(FCost, LCost);
end;

procedure TEffectChain.Reset;
var
  LIndex: Integer;
begin
  if FBusy then
  begin
    raise EAudio.Create('Cannot reset an active effect chain');
  end;
  FFailed := True;
  FBusy := True;
  try
    for LIndex := 0 to High(FEffects) do
    begin
      FEffects[LIndex].Reset;
    end;
    FFailed := False;
  finally
    FBusy := False;
  end;
end;

procedure TEffectChain.Process(const ALeft, ARight: Double;
  out AOutputLeft, AOutputRight: Double);
var
  LLeft: Double;
  LRight: Double;
  LNextLeft: Double;
  LNextRight: Double;
  LIndex: Integer;
begin
  if FBusy or FFailed then
  begin
    raise EAudio.Create('Effect chain is active or requires Reset after failure');
  end;
  RequireFinite(ALeft, 'Effect input');
  RequireFinite(ARight, 'Effect input');
  if (Abs(ALeft) > MaximumDynamicsMagnitude) or (Abs(ARight) > MaximumDynamicsMagnitude) then
  begin
    raise EAudio.Create('Effect input exceeds magnitude bound');
  end;
  LLeft := ALeft;
  LRight := ARight;
  FBusy := True;
  try
    try
      for LIndex := 0 to High(FEffects) do
      begin
        FEffects[LIndex].Process(LLeft, LRight, LNextLeft, LNextRight);
        RequireFinite(LNextLeft, 'Effect output');
        RequireFinite(LNextRight, 'Effect output');
        if (Abs(LNextLeft) > MaximumDynamicsMagnitude) or
          (Abs(LNextRight) > MaximumDynamicsMagnitude) then
        begin
          raise EAudio.Create('Effect output exceeds magnitude bound');
        end;
        LLeft := LNextLeft;
        LRight := LNextRight;
      end;
      AOutputLeft := LLeft;
      AOutputRight := LRight;
    except
      FFailed := True;
      raise;
    end;
  finally
    FBusy := False;
  end;
end;

function RenderEffectClip(const ASource: TAudioClip; const AChain: TEffectChain;
  const ATailFrames: Integer): TAudioClip;
var
  LFrames: Int64;
  LFrame: Integer;
  LInputLeft: Double;
  LInputRight: Double;
  LLeft: Double;
  LRight: Double;
  LSamples: TAudioSamples;
begin
  if (ASource = nil) or (AChain = nil) then
  begin
    raise EAudio.Create('Effect rendering requires source and chain');
  end;
  LFrames := Int64(ASource.FrameCount) + ATailFrames;
  if (ASource.SampleRate <> AChain.SampleRate) or (ATailFrames < 0) or
    (LFrames > MaximumClipSamples div 2) or
    (LFrames * AChain.FrameCost > MaximumEffectVisits) or AChain.Failed or AChain.FBusy then
  begin
    raise EAudio.Create('Effect render format, size, work, or chain state is invalid');
  end;
  SetLength(LSamples, LFrames * 2);
  try
    for LFrame := 0 to LFrames - 1 do
    begin
      LInputLeft := 0;
      LInputRight := 0;
      if LFrame < ASource.FrameCount then
      begin
        LInputLeft := ASource.SampleAt(LFrame, 0);
        LInputRight := LInputLeft;
        if ASource.Channels = 2 then
        begin
          LInputRight := ASource.SampleAt(LFrame, 1);
        end;
      end;
      AChain.Process(LInputLeft, LInputRight, LLeft, LRight);
      if (Abs(LLeft) > MaxSingle) or (Abs(LRight) > MaxSingle) then
      begin
        { Processing consumed the frame; a failed render requires an explicit reset. }
        AChain.FFailed := True;
        raise EAudio.Create('Effect render output exceeds Single range');
      end;
      LSamples[LFrame * 2] := LLeft;
      LSamples[LFrame * 2 + 1] := LRight;
    end;
    Result := TAudioClip.Create(ASource.SampleRate, 2, LSamples);
  except
    AChain.FFailed := True;
    raise;
  end;
end;

end.
