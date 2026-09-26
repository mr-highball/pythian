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
unit pythian.envelope;

{$mode delphi}
{$H+}

interface

uses
  pythian.audio,
  pythian.automation;

const
  MaximumEnvelopeFrames = 1048576;

type
  TAdsr = record
    AttackSeconds: Double;
    DecaySeconds: Double;
    SustainLevel: Double;
    ReleaseSeconds: Double;
  end;

  { Owns cloned curves in output-frame coordinates. Held is note-relative;
    Release is a multiplier relative to note-off. Both remain in 0..1.
    Release starts at one and is zero at ReleaseFrames. Nil release is allowed
    only for an immediate cut. No implicit sample-rate or gate-length scaling. }
  TGateEnvelope = class
  strict private
    FHeld: TAutomationCurve;
    FRelease: TAutomationCurve;
    FReleaseFrames: Int64;
    FFrameCost: Integer;
  public
    constructor Create(const AHeld, ARelease: TAutomationCurve;
      const AReleaseFrames: Int64);
    destructor Destroy; override;
    function Clone: TGateEnvelope;
    function ValueAt(const AFrame, AGateFrames: Int64): Double;
    { Exact union of linear held/release knots in one output-frame timebase.
      Independent weighted means of held levels and relative release shapes.
      Positive release tails only; bounded to 32 sources and 4096 union knots. }
    class function Blend(const AEnvelopes: array of TGateEnvelope;
      const AWeights: array of Integer): TGateEnvelope; static;
    property ReleaseFrames: Int64 read FReleaseFrames;
    property FrameCost: Integer read FFrameCost;
  end;

  { Detached rectangular-window RMS evidence from one selected channel/region.
    Point coordinates are window centers relative to StartFrame. RMS includes DC.
    A trace alone does not identify an instrument, note-on or note-off. }
  TEnvelopeTrace = class
  strict private
    FPoints: TAutomationPoints;
    FSampleRate: Integer;
    FStartFrame: Integer;
    FFrameCount: Integer;
    FChannel: Integer;
    FWindowFrames: Integer;
    FPeakRms: Double;
    procedure SetMeasured(const ASampleRate, AStartFrame, AFrameCount,
      AChannel, AWindowFrames: Integer; const APoints: TAutomationPoints);
  public
    constructor Create(const AClip: TAudioClip;
      const AStartFrame, AFrameCount, AChannel, AWindowFrames: Integer);
    { Validates detached previously measured window evidence; does not reopen WAV. }
    constructor CreateMeasured(const ASampleRate, AStartFrame, AFrameCount,
      AChannel, AWindowFrames: Integer; const APoints: TAutomationPoints);
    function CopyRmsPoints: TAutomationPoints;
    { Normalize held levels by peak RMS. Release ratios are relative to RMS at
      the declared gate; rising tails above that level reject. Last window/gate
      RMS must meet MaximumTailRatio before the explicit endpoint is set to zero.
      Retiming floors absolute coordinates; collapsed knots reject. }
    function CreateGateEnvelope(const AGateFrame, AOutputRate: Integer;
      const AMaximumTailRatio: Double; const AMinimumRms: Double = 1E-5): TGateEnvelope;
    property SampleRate: Integer read FSampleRate;
    property StartFrame: Integer read FStartFrame;
    property FrameCount: Integer read FFrameCount;
    property Channel: Integer read FChannel;
    property WindowFrames: Integer read FWindowFrames;
    property PeakRms: Double read FPeakRms;
  end;

function DefaultAdsr: TAdsr;
procedure ValidateAdsr(const AEnvelope: TAdsr);
{ Time is relative to note-on; gate seconds is the note-off time. Release
  starts from the actual attack/decay/sustain value at note-off. }
function EnvelopeAt(const AEnvelope: TAdsr; const ATime, AGateSeconds: Double): Double;

implementation

uses
  Math;

procedure TEnvelopeTrace.SetMeasured(const ASampleRate, AStartFrame, AFrameCount,
  AChannel, AWindowFrames: Integer; const APoints: TAutomationPoints);
var
  LCount: Integer;
  I: Integer;
  LStart: Integer;
  LValid: Integer;
begin
  ValidateAudioFormat(ASampleRate, 1);
  if (AStartFrame < 0) or (AStartFrame > MaximumClipSamples) or
    (AFrameCount < 1) or (AFrameCount > MaximumEnvelopeFrames) or
    (AFrameCount > MaximumClipSamples - AStartFrame) or not (AChannel in [0, 1]) or
    (AWindowFrames < 4) or (AWindowFrames > 65536) then
  begin
    raise EAudio.Create('Measured envelope geometry exceeds bounds');
  end;
  LCount := (AFrameCount - 1) div AWindowFrames + 1;
  if (LCount < 2) or (LCount > MaximumAutomationPoints - 2) or (Length(APoints) <> LCount) then
  begin
    raise EAudio.Create('Measured envelope window count disagrees with geometry');
  end;
  FPeakRms := 0;
  for I := 0 to LCount - 1 do
  begin
    LStart := I * AWindowFrames;
    LValid := Min(AWindowFrames, AFrameCount - LStart);
    RequireFinite(APoints[I].Value, 'Measured envelope RMS');
    if (APoints[I].Frame <> LStart + (LValid - 1) div 2) or
      (APoints[I].Value < 0) or (APoints[I].Value > MaximumAutomationMagnitude) or
      (APoints[I].Transition <> atLinear) then
    begin
      raise EAudio.Create('Measured envelope points disagree with RMS geometry or bounds');
    end;
    FPeakRms := Max(FPeakRms, APoints[I].Value);
  end;
  FSampleRate := ASampleRate;
  FStartFrame := AStartFrame;
  FFrameCount := AFrameCount;
  FChannel := AChannel;
  FWindowFrames := AWindowFrames;
  FPoints := Copy(APoints);
end;

constructor TEnvelopeTrace.CreateMeasured(const ASampleRate, AStartFrame, AFrameCount,
  AChannel, AWindowFrames: Integer; const APoints: TAutomationPoints);
begin
  inherited Create;
  SetMeasured(ASampleRate, AStartFrame, AFrameCount, AChannel, AWindowFrames, APoints);
end;

class function TGateEnvelope.Blend(const AEnvelopes: array of TGateEnvelope;
  const AWeights: array of Integer): TGateEnvelope;
var
  LCurves: array of TAutomationCurve;
  LPoints: TAutomationPoints;
  LInput: TAutomationPoints;
  LHeld: TAutomationCurve;
  LRelease: TAutomationCurve;
  LCount: Integer;
  LTotal: Integer;
  LSource: Integer;
  LIndex: Integer;
  LKind: Integer;
  LEnd: Int64;
  LValue: Double;

  procedure AddFrame(const AFrame: Int64);
  var
    LLow: Integer;
    LHigh: Integer;
    LMiddle: Integer;
    I: Integer;
  begin
    LLow := 0;
    LHigh := LCount;
    while LLow < LHigh do
    begin
      LMiddle := (LLow + LHigh) div 2;
      if LPoints[LMiddle].Frame < AFrame then
      begin
        LLow := LMiddle + 1;
      end
      else
      begin
        LHigh := LMiddle;
      end;
    end;
    if (LLow < LCount) and (LPoints[LLow].Frame = AFrame) then
    begin
      Exit;
    end;
    if LCount = MaximumAutomationPoints then
    begin
      raise EAudio.Create('Envelope blend exceeds 4096 union knots');
    end;
    for I := LCount downto LLow + 1 do
    begin
      LPoints[I] := LPoints[I - 1];
    end;
    LPoints[LLow].Frame := AFrame;
    LPoints[LLow].Transition := atLinear;
    Inc(LCount);
  end;

begin
  if (Length(AEnvelopes) < 1) or (Length(AEnvelopes) > 32) or
    (Length(AEnvelopes) <> Length(AWeights)) then
  begin
    raise EAudio.Create('Envelope blend requires 1..32 paired sources and weights');
  end;
  LTotal := 0;
  LEnd := 0;
  for LSource := 0 to High(AWeights) do
  begin
    if (AWeights[LSource] < 0) or (AWeights[LSource] > 64) then
    begin
      raise EAudio.Create('Envelope weights must be in 0..64');
    end;
    if AWeights[LSource] = 0 then
    begin
      Continue;
    end;
    if (AEnvelopes[LSource] = nil) or (AEnvelopes[LSource].FReleaseFrames = 0) then
    begin
      raise EAudio.Create('Active envelope blend sources require positive release tails');
    end;
    Inc(LTotal, AWeights[LSource]);
    LEnd := Max(LEnd, AEnvelopes[LSource].FReleaseFrames);
  end;
  if LTotal = 0 then
  begin
    raise EAudio.Create('Envelope blend requires an active source');
  end;
  SetLength(LCurves, Length(AEnvelopes));
  LHeld := nil;
  LRelease := nil;
  try
    for LKind := 0 to 1 do
    begin
      SetLength(LPoints, MaximumAutomationPoints);
      LCount := 0;
      AddFrame(0);
      for LSource := 0 to High(AEnvelopes) do
      begin
        if AWeights[LSource] = 0 then
        begin
          Continue;
        end;
        if LKind = 0 then
        begin
          LCurves[LSource] := AEnvelopes[LSource].FHeld;
        end
        else
        begin
          LCurves[LSource] := AEnvelopes[LSource].FRelease;
        end;
        LInput := LCurves[LSource].CopyPoints;
        for LIndex := 0 to High(LInput) do
        begin
          if (LIndex < High(LInput)) and (LInput[LIndex].Transition <> atLinear) then
          begin
            raise EAudio.Create('Envelope blend requires linear point curves');
          end;
          if (LKind = 0) or (LInput[LIndex].Frame <= AEnvelopes[LSource].FReleaseFrames) then
          begin
            AddFrame(LInput[LIndex].Frame);
          end;
        end;
        if LKind = 1 then
        begin
          AddFrame(AEnvelopes[LSource].FReleaseFrames);
        end;
      end;
      for LIndex := 0 to LCount - 1 do
      begin
        LValue := 0;
        for LSource := 0 to High(AEnvelopes) do
        begin
          if (AWeights[LSource] > 0) and ((LKind = 0) or
            (LPoints[LIndex].Frame < AEnvelopes[LSource].FReleaseFrames)) then
          begin
            LValue := LValue + AWeights[LSource] * LCurves[LSource].ValueAt(LPoints[LIndex].Frame);
          end;
        end;
        LPoints[LIndex].Value := LValue / LTotal;
      end;
      SetLength(LPoints, LCount);
      if LKind = 0 then
      begin
        LHeld := TAutomationCurve.Create(LPoints);
      end
      else
      begin
        LRelease := TAutomationCurve.Create(LPoints);
      end;
    end;
    Result := TGateEnvelope.Create(LHeld, LRelease, LEnd);
  finally
    LRelease.Free;
    LHeld.Free;
  end;
end;

constructor TEnvelopeTrace.Create(const AClip: TAudioClip;
  const AStartFrame, AFrameCount, AChannel, AWindowFrames: Integer);
var
  LCount: Integer;
  LIndex: Integer;
  LStart: Integer;
  LValid: Integer;
  LFrame: Integer;
  LValue: Double;
  LSum: Double;
begin
  inherited Create;
  if AClip = nil then
  begin
    raise EAudio.Create('Envelope trace requires a source clip');
  end;
  if (AStartFrame < 0) or (AStartFrame > AClip.FrameCount) or
    (AFrameCount < 1) or (AFrameCount > MaximumEnvelopeFrames) or
    (AFrameCount > AClip.FrameCount - AStartFrame) or
    (AChannel < 0) or (AChannel >= AClip.Channels) or
    (AWindowFrames < 4) or (AWindowFrames > 65536) then
  begin
    raise EAudio.Create('Envelope source region, channel or window exceeds bounds');
  end;
  LCount := (AFrameCount - 1) div AWindowFrames + 1;
  if (LCount < 2) or (LCount > MaximumAutomationPoints - 2) then
  begin
    raise EAudio.Create('Envelope trace requires 2..4094 measurement windows');
  end;
  FSampleRate := AClip.SampleRate;
  FStartFrame := AStartFrame;
  FFrameCount := AFrameCount;
  FChannel := AChannel;
  FWindowFrames := AWindowFrames;
  SetLength(FPoints, LCount);
  for LIndex := 0 to LCount - 1 do
  begin
    LStart := LIndex * AWindowFrames;
    LValid := Min(AWindowFrames, AFrameCount - LStart);
    LSum := 0;
    for LFrame := 0 to LValid - 1 do
    begin
      LValue := AClip.SampleAt(AStartFrame + LStart + LFrame, AChannel);
      LSum := LSum + LValue * LValue;
    end;
    LValue := Sqrt(LSum / LValid);
    if LValue > MaximumAutomationMagnitude then
    begin
      raise EAudio.Create('Envelope RMS exceeds automation magnitude bound');
    end;
    FPoints[LIndex].Frame := LStart + (LValid - 1) div 2;
    FPoints[LIndex].Value := LValue;
    FPoints[LIndex].Transition := atLinear;
    FPeakRms := Max(FPeakRms, LValue);
  end;
end;

function TEnvelopeTrace.CopyRmsPoints: TAutomationPoints;
begin
  Result := Copy(FPoints);
end;

function TEnvelopeTrace.CreateGateEnvelope(const AGateFrame, AOutputRate: Integer;
  const AMaximumTailRatio, AMinimumRms: Double): TGateEnvelope;
var
  LRaw: TAutomationCurve;
  LHeld: TAutomationCurve;
  LRelease: TAutomationCurve;
  LPoints: TAutomationPoints;
  LGateRms: Double;
  LGate: Int64;
  LEnd: Int64;
  LIndex: Integer;
  LCount: Integer;

  function Retimed(const AFrame: Int64): Int64;
  begin
    Result := AFrame * AOutputRate div FSampleRate;
  end;

  procedure Append(const AFrame: Int64; const AValue: Double);
  begin
    if (LCount > 0) and (AFrame <= LPoints[LCount - 1].Frame) then
    begin
      raise EAudio.Create('Envelope retiming collapses curve points; use a wider analysis window');
    end;
    LPoints[LCount].Frame := AFrame;
    LPoints[LCount].Value := AValue;
    LPoints[LCount].Transition := atLinear;
    Inc(LCount);
  end;

begin
  ValidateAudioFormat(AOutputRate, 1);
  RequireFinite(AMaximumTailRatio, 'Envelope tail ratio');
  RequireFinite(AMinimumRms, 'Envelope minimum RMS');
  if (AGateFrame <= 0) or (AGateFrame >= FPoints[High(FPoints)].Frame) or
    (AMaximumTailRatio < 0) or (AMaximumTailRatio > 1) or
    (AMinimumRms <= 0) or (AMinimumRms > MaximumAutomationMagnitude) or
    (FPeakRms <= AMinimumRms) then
  begin
    raise EAudio.Create('Envelope requires an interior gate, admitted RMS and tail ratio in 0..1');
  end;
  LGate := Retimed(AGateFrame);
  LEnd := Retimed(FFrameCount);
  if (LGate < 1) or (LEnd <= LGate) then
  begin
    raise EAudio.Create('Envelope retiming collapses gate or release');
  end;
  LRaw := TAutomationCurve.Create(FPoints);
  LHeld := nil;
  LRelease := nil;
  try
    LGateRms := LRaw.ValueAt(AGateFrame);
    if (LGateRms <= AMinimumRms) or
      (FPoints[High(FPoints)].Value / LGateRms > AMaximumTailRatio) then
    begin
      raise EAudio.Create('Envelope gate lacks RMS evidence or final window exceeds tail admission');
    end;
    SetLength(LPoints, Length(FPoints) + 2);
    LCount := 0;
    Append(0, FPoints[0].Value / FPeakRms);
    for LIndex := 0 to High(FPoints) do
    begin
      if (FPoints[LIndex].Frame > 0) and (FPoints[LIndex].Frame < AGateFrame) then
      begin
        Append(Retimed(FPoints[LIndex].Frame), FPoints[LIndex].Value / FPeakRms);
      end;
    end;
    Append(LGate, LGateRms / FPeakRms);
    SetLength(LPoints, LCount);
    LHeld := TAutomationCurve.Create(LPoints);
    SetLength(LPoints, Length(FPoints) + 2);
    LCount := 0;
    Append(0, 1);
    for LIndex := 0 to High(FPoints) do
    begin
      if FPoints[LIndex].Frame > AGateFrame then
      begin
        if FPoints[LIndex].Value > LGateRms then
        begin
          raise EAudio.Create('Envelope release rises above the declared gate level');
        end;
        Append(Retimed(FPoints[LIndex].Frame) - LGate, FPoints[LIndex].Value / LGateRms);
      end;
    end;
    Append(LEnd - LGate, 0);
    SetLength(LPoints, LCount);
    LRelease := TAutomationCurve.Create(LPoints);
    Result := TGateEnvelope.Create(LHeld, LRelease, LEnd - LGate);
  finally
    LRelease.Free;
    LHeld.Free;
    LRaw.Free;
  end;
end;

constructor TGateEnvelope.Create(const AHeld, ARelease: TAutomationCurve;
  const AReleaseFrames: Int64);
begin
  inherited Create;
  if (AHeld = nil) or (AReleaseFrames < 0) then
  begin
    raise EAudio.Create('Gated envelope requires a held curve and nonnegative release frames');
  end;
  if (AHeld.Minimum < 0) or (AHeld.Maximum > 1) then
  begin
    raise EAudio.Create('Held envelope curve must remain in 0..1');
  end;
  if AReleaseFrames = 0 then
  begin
    if ARelease <> nil then
    begin
      raise EAudio.Create('Immediate envelope cut requires no release curve');
    end;
  end
  else
  begin
    if ARelease = nil then
    begin
      raise EAudio.Create('Positive envelope release requires a curve');
    end;
    if (ARelease.Minimum < 0) or (ARelease.Maximum > 1) or
      (ARelease.ValueAt(0) <> 1) or (ARelease.ValueAt(AReleaseFrames) <> 0) then
    begin
      raise EAudio.Create('Release curve must stay in 0..1, start at one and end at zero');
    end;
  end;
  FHeld := AHeld.Clone;
  FFrameCost := 16 * AHeld.Depth;
  if ARelease <> nil then
  begin
    FRelease := ARelease.Clone;
    Inc(FFrameCost, 16 * ARelease.Depth);
  end;
  FReleaseFrames := AReleaseFrames;
end;

destructor TGateEnvelope.Destroy;
begin
  FRelease.Free;
  FHeld.Free;
  inherited;
end;

function TGateEnvelope.Clone: TGateEnvelope;
begin
  Result := TGateEnvelope.Create(FHeld, FRelease, FReleaseFrames);
end;

function TGateEnvelope.ValueAt(const AFrame, AGateFrames: Int64): Double;
begin
  if AGateFrames < 0 then
  begin
    raise EAudio.Create('Envelope gate frames must be nonnegative');
  end;
  Result := 0;
  if AFrame < 0 then
  begin
    Exit;
  end;
  if AFrame < AGateFrames then
  begin
    Exit(FHeld.ValueAt(AFrame));
  end;
  if AFrame - AGateFrames < FReleaseFrames then
  begin
    Result := FHeld.ValueAt(AGateFrames) * FRelease.ValueAt(AFrame - AGateFrames);
  end;
end;

function DefaultAdsr: TAdsr;
begin
  Result.AttackSeconds := 0.008;
  Result.DecaySeconds := 0.12;
  Result.SustainLevel := 0.6;
  Result.ReleaseSeconds := 0.12;
end;

procedure ValidateAdsr(const AEnvelope: TAdsr);
begin
  RequireFinite(AEnvelope.AttackSeconds, 'Attack');
  RequireFinite(AEnvelope.DecaySeconds, 'Decay');
  RequireFinite(AEnvelope.SustainLevel, 'Sustain');
  RequireFinite(AEnvelope.ReleaseSeconds, 'Release');
  if (AEnvelope.AttackSeconds < 0) or (AEnvelope.DecaySeconds < 0) or
    (AEnvelope.ReleaseSeconds < 0) or (AEnvelope.SustainLevel < 0) or
    (AEnvelope.SustainLevel > 1) then
  begin
    raise EAudio.Create('ADSR times must be nonnegative; sustain must be 0..1');
  end;
end;

function HeldLevel(const AEnvelope: TAdsr; const ATime: Double): Double;
begin
  if ATime < AEnvelope.AttackSeconds then
  begin
    Exit(ATime / AEnvelope.AttackSeconds);
  end;
  if ATime < AEnvelope.AttackSeconds + AEnvelope.DecaySeconds then
  begin
    Exit(1 - (1 - AEnvelope.SustainLevel) *
      ((ATime - AEnvelope.AttackSeconds) / AEnvelope.DecaySeconds));
  end;
  Result := AEnvelope.SustainLevel;
end;

function EnvelopeAt(const AEnvelope: TAdsr; const ATime, AGateSeconds: Double): Double;
begin
  ValidateAdsr(AEnvelope);
  RequireFinite(ATime, 'Envelope time');
  RequireFinite(AGateSeconds, 'Gate duration');
  if AGateSeconds < 0 then
  begin
    raise EAudio.Create('Gate duration must be nonnegative');
  end;
  Result := 0;
  if (ATime < 0) or (ATime >= AGateSeconds + AEnvelope.ReleaseSeconds) then
  begin
    Exit;
  end;
  if ATime < AGateSeconds then
  begin
    Result := HeldLevel(AEnvelope, ATime);
  end
  else
  begin
    Result := HeldLevel(AEnvelope, AGateSeconds) *
      (1 - (ATime - AGateSeconds) / AEnvelope.ReleaseSeconds);
  end;
end;

end.
