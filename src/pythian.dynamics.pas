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
unit pythian.dynamics;

{$mode delphi}
{$H+}

interface

const
  DynamicsVersion = 1;
  MaximumDynamicsMagnitude = 1E100;

type
  TCompressorSettings = record
    ThresholdDb: Double;
    Ratio: Double;
    KneeDb: Double;
    AttackSeconds: Double;
    ReleaseSeconds: Double;
    MakeupDb: Double;
  end;

  { Stereo-linked feed-forward peak compressor. Attack/release smooth positive
    gain reduction in dB. Times are one-pole time constants, zero is immediate. }
  TStereoCompressor = class
  strict private
    FSampleRate: Integer;
    FSettings: TCompressorSettings;
    FAttack: Double;
    FRelease: Double;
    FReductionDb: Double;
  public
    constructor Create(const ASampleRate: Integer; const ASettings: TCompressorSettings);
    procedure Reset;
    procedure SetSettings(const ASettings: TCompressorSettings);
    procedure Process(const ALeft, ARight: Double; out AOutputLeft, AOutputRight: Double);
    { Detector magnitude is external and nonnegative; channel linking remains shared. }
    procedure ProcessSidechain(const ALeft, ARight, ADetectorMagnitude: Double;
      out AOutputLeft, AOutputRight: Double);
    property ReductionDb: Double read FReductionDb;
  end;

  { Immediate linked sample-peak limiting, exponential linear-gain recovery.
    Zero latency; no intersample/true-peak guarantee and no lookahead. }
  TStereoPeakLimiter = class
  strict private
    FCeiling: Double;
    FRelease: Double;
    FGain: Double;
  public
    constructor Create(const ASampleRate: Integer; const ACeilingDb: Double = -1;
      const AReleaseSeconds: Double = 0.05);
    procedure Reset;
    procedure Process(const ALeft, ARight: Double; out AOutputLeft, AOutputRight: Double);
    property Gain: Double read FGain;
  end;

  { Generic gain target smoothing. A Next call advances one sample interval. }
  TGainSmoother = class
  strict private
    FInitial: Double;
    FCurrent: Double;
    FTarget: Double;
    FCoefficient: Double;
  public
    constructor Create(const ASampleRate: Integer; const AInitialGain, ATimeSeconds: Double);
    procedure Reset;
    procedure SetTarget(const AGain: Double);
    function Next: Double;
    property Current: Double read FCurrent;
  end;

function DefaultCompressorSettings: TCompressorSettings;
procedure ValidateCompressor(const ASettings: TCompressorSettings);
function CompressorReductionDb(const AInputDb: Double;
  const ASettings: TCompressorSettings): Double;

implementation

uses
  Math,
  pythian.audio;

procedure CheckMagnitude(const AValue: Double);
begin
  RequireFinite(AValue, 'Dynamics sample');
  if Abs(AValue) > MaximumDynamicsMagnitude then
  begin
    raise EAudio.Create('Dynamics sample exceeds magnitude bound');
  end;
end;

function TimeCoefficient(const ASampleRate: Integer; const ASeconds: Double): Double;
begin
  ValidateAudioFormat(ASampleRate, 1);
  RequireFinite(ASeconds, 'Dynamics time');
  if (ASeconds < 0) or (ASeconds > 60) then
  begin
    raise EAudio.Create('Dynamics time must be 0..60 seconds');
  end;
  Result := 0;
  if ASeconds > 0 then
  begin
    { Avoid reciprocal overflow for subnormal positive time constants. }
    if ASeconds * ASampleRate > 1E-6 then
    begin
      Result := Exp(-1 / (ASeconds * ASampleRate));
    end;
  end;
end;

function DefaultCompressorSettings: TCompressorSettings;
begin
  Result.ThresholdDb := -14;
  Result.Ratio := 4;
  Result.KneeDb := 6;
  Result.AttackSeconds := 0.005;
  Result.ReleaseSeconds := 0.15;
  Result.MakeupDb := 0;
end;

procedure ValidateCompressor(const ASettings: TCompressorSettings);
begin
  RequireFinite(ASettings.ThresholdDb, 'Compressor threshold');
  RequireFinite(ASettings.Ratio, 'Compressor ratio');
  RequireFinite(ASettings.KneeDb, 'Compressor knee');
  RequireFinite(ASettings.AttackSeconds, 'Compressor attack');
  RequireFinite(ASettings.ReleaseSeconds, 'Compressor release');
  RequireFinite(ASettings.MakeupDb, 'Compressor makeup');
  if (ASettings.ThresholdDb < -120) or (ASettings.ThresholdDb > 24) or
    (ASettings.Ratio < 1) or (ASettings.Ratio > 100) or
    (ASettings.KneeDb < 0) or (ASettings.KneeDb > 48) or
    (ASettings.AttackSeconds < 0) or (ASettings.AttackSeconds > 60) or
    (ASettings.ReleaseSeconds < 0) or (ASettings.ReleaseSeconds > 60) or
    (ASettings.MakeupDb < -24) or (ASettings.MakeupDb > 48) then
  begin
    raise EAudio.Create('Compressor settings outside threshold/ratio/knee/time/makeup bounds');
  end;
end;

function StaticReduction(const AInputDb: Double; const ASettings: TCompressorSettings): Double;
var
  LOver: Double;
  LSlope: Double;
begin
  LOver := AInputDb - ASettings.ThresholdDb;
  LSlope := 1 - 1 / ASettings.Ratio;
  if LOver <= -ASettings.KneeDb / 2 then
  begin
    Exit(0);
  end;
  if (ASettings.KneeDb > 0) and (LOver < ASettings.KneeDb / 2) then
  begin
    Exit(LSlope * Sqr(LOver + ASettings.KneeDb / 2) / (2 * ASettings.KneeDb));
  end;
  Result := LSlope * LOver;
end;

function CompressorReductionDb(const AInputDb: Double;
  const ASettings: TCompressorSettings): Double;
begin
  ValidateCompressor(ASettings);
  RequireFinite(AInputDb, 'Detector level');
  if Abs(AInputDb) > 2000 then
  begin
    raise EAudio.Create('Detector level magnitude must be at most 2000 dB');
  end;
  Result := StaticReduction(AInputDb, ASettings);
end;

constructor TStereoCompressor.Create(const ASampleRate: Integer;
  const ASettings: TCompressorSettings);
begin
  inherited Create;
  ValidateAudioFormat(ASampleRate, 2);
  FSampleRate := ASampleRate;
  SetSettings(ASettings);
  Reset;
end;

procedure TStereoCompressor.Reset;
begin
  FReductionDb := 0;
end;

procedure TStereoCompressor.SetSettings(const ASettings: TCompressorSettings);
var
  LAttack: Double;
  LRelease: Double;
begin
  ValidateCompressor(ASettings);
  LAttack := TimeCoefficient(FSampleRate, ASettings.AttackSeconds);
  LRelease := TimeCoefficient(FSampleRate, ASettings.ReleaseSeconds);
  FSettings := ASettings;
  FAttack := LAttack;
  FRelease := LRelease;
end;

procedure TStereoCompressor.Process(const ALeft, ARight: Double;
  out AOutputLeft, AOutputRight: Double);
begin
  CheckMagnitude(ALeft);
  CheckMagnitude(ARight);
  ProcessSidechain(ALeft, ARight, Max(Abs(ALeft), Abs(ARight)), AOutputLeft, AOutputRight);
end;

procedure TStereoCompressor.ProcessSidechain(const ALeft, ARight,
  ADetectorMagnitude: Double; out AOutputLeft, AOutputRight: Double);
var
  LDetectorDb: Double;
  LTarget: Double;
  LCoefficient: Double;
  LReduction: Double;
  LGain: Double;
  LLeft: Double;
  LRight: Double;
begin
  CheckMagnitude(ALeft);
  CheckMagnitude(ARight);
  CheckMagnitude(ADetectorMagnitude);
  if ADetectorMagnitude < 0 then
  begin
    raise EAudio.Create('Sidechain magnitude must be nonnegative');
  end;
  LDetectorDb := -300;
  if ADetectorMagnitude > 1E-15 then
  begin
    LDetectorDb := 20 * Log10(ADetectorMagnitude);
  end;
  LTarget := StaticReduction(LDetectorDb, FSettings);
  LCoefficient := FRelease;
  if LTarget > FReductionDb then
  begin
    LCoefficient := FAttack;
  end;
  LReduction := LCoefficient * FReductionDb + (1 - LCoefficient) * LTarget;
  LGain := Power(10, (FSettings.MakeupDb - LReduction) / 20);
  LLeft := ALeft * LGain;
  LRight := ARight * LGain;
  CheckMagnitude(LLeft);
  CheckMagnitude(LRight);
  FReductionDb := LReduction;
  AOutputLeft := LLeft;
  AOutputRight := LRight;
end;

constructor TStereoPeakLimiter.Create(const ASampleRate: Integer;
  const ACeilingDb, AReleaseSeconds: Double);
begin
  inherited Create;
  RequireFinite(ACeilingDb, 'Limiter ceiling');
  if (ACeilingDb < -60) or (ACeilingDb > 0) then
  begin
    raise EAudio.Create('Limiter ceiling must be -60..0 dBFS');
  end;
  FRelease := TimeCoefficient(ASampleRate, AReleaseSeconds);
  FCeiling := Power(10, ACeilingDb / 20);
  Reset;
end;

procedure TStereoPeakLimiter.Reset;
begin
  FGain := 1;
end;

procedure TStereoPeakLimiter.Process(const ALeft, ARight: Double;
  out AOutputLeft, AOutputRight: Double);
var
  LPeak: Double;
  LGain: Double;
  LLeft: Double;
  LRight: Double;
begin
  CheckMagnitude(ALeft);
  CheckMagnitude(ARight);
  LPeak := Max(Abs(ALeft), Abs(ARight));
  LGain := 1 - FRelease * (1 - FGain);
  if LPeak > FCeiling then
  begin
    LGain := Min(LGain, FCeiling / LPeak);
  end;
  LLeft := Max(-FCeiling, Min(FCeiling, ALeft * LGain));
  LRight := Max(-FCeiling, Min(FCeiling, ARight * LGain));
  FGain := LGain;
  AOutputLeft := LLeft;
  AOutputRight := LRight;
end;

constructor TGainSmoother.Create(const ASampleRate: Integer;
  const AInitialGain, ATimeSeconds: Double);
begin
  inherited Create;
  FCoefficient := TimeCoefficient(ASampleRate, ATimeSeconds);
  SetTarget(AInitialGain);
  FInitial := AInitialGain;
  Reset;
end;

procedure TGainSmoother.Reset;
begin
  FCurrent := FInitial;
  FTarget := FInitial;
end;

procedure TGainSmoother.SetTarget(const AGain: Double);
begin
  RequireFinite(AGain, 'Target gain');
  if (AGain < 0) or (AGain > 16) then
  begin
    raise EAudio.Create('Target gain must be 0..16');
  end;
  FTarget := AGain;
end;

function TGainSmoother.Next: Double;
begin
  FCurrent := FTarget + FCoefficient * (FCurrent - FTarget);
  Result := FCurrent;
end;

end.
