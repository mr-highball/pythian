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
unit pythian.automation;

{$mode delphi}
{$H+}

interface

const
  AutomationVersion = 1;
  MaximumAutomationPoints = 4096;
  MaximumAutomationMagnitude = 1E12;
  MaximumAutomationDepth = 8;

type
  TAutomationTransition = (atHold, atLinear, atExponential);
  TAutomationKind = (akPoints, akLfo, akAffine);
  TAutomationLfoShape = (alsSine, alsTriangle);
  TAutomationPoint = record
    Frame: Int64;
    Value: Double;
    { Interpolation from this point to the next. }
    Transition: TAutomationTransition;
  end;
  TAutomationPoints = array of TAutomationPoint;

  { Immutable, owning, integer-frame curve: points, periodic controls or affine
    composition. Point curves hold outside their extent. }
  TAutomationCurve = class
  strict private
    FPoints: TAutomationPoints;
    FMinimum: Double;
    FMaximum: Double;
    FKind: TAutomationKind;
    FDepth: Integer;
    FPeriodFrames: Int64;
    FPhaseFrames: Int64;
    FLfoShape: TAutomationLfoShape;
    FSource: TAutomationCurve;
    FScale: Double;
    FOffset: Double;
  public
    constructor Create(const APoints: TAutomationPoints);
    { Bipolar [-1,1], sampled at an exact integer-frame period. Phase is an
      initial forward offset, not a delay. No state or accumulated phase drift. }
    constructor CreateLfo(const APeriodFrames: Int64; const AShape: TAutomationLfoShape;
      const APhaseFrames: Int64 = 0);
    { Owns a clone of Source and evaluates Offset + Scale * Source(Frame).
      Bounds are conservative over the complete source extent. }
    constructor CreateAffine(const ASource: TAutomationCurve; const AScale, AOffset: Double);
    destructor Destroy; override;
    function ValueAt(const AFrame: Int64): Double;
    function Clone: TAutomationCurve;
    { Available for point curves only; generated/composed curves are not flattened. }
    function CopyPoints: TAutomationPoints;
    property Kind: TAutomationKind read FKind;
    property Depth: Integer read FDepth;
    property Minimum: Double read FMinimum;
    property Maximum: Double read FMaximum;
  end;

{ Reusable pitch modulation in cents. No implicit Nyquist clipping. }
function FrequencyWithCents(const AFrequencyHz, ACents: Double): Double;

implementation

uses
  Math,
  pythian.audio;

constructor TAutomationCurve.Create(const APoints: TAutomationPoints);
var
  LIndex: Integer;
begin
  inherited Create;
  FDepth := 1;
  if (Length(APoints) < 1) or (Length(APoints) > MaximumAutomationPoints) then
  begin
    raise EAudio.Create('Automation requires 1..4096 points');
  end;
  FMinimum := APoints[0].Value;
  FMaximum := FMinimum;
  for LIndex := 0 to High(APoints) do
  begin
    RequireFinite(APoints[LIndex].Value, 'Automation value');
    if (APoints[LIndex].Frame < 0) or
      (Abs(APoints[LIndex].Value) > MaximumAutomationMagnitude) then
    begin
      raise EAudio.Create('Automation point outside frame/value bounds');
    end;
    if not (APoints[LIndex].Transition in [atHold, atLinear, atExponential]) then
    begin
      raise EAudio.Create('Unknown automation transition');
    end;
    if LIndex > 0 then
    begin
      if APoints[LIndex].Frame <= APoints[LIndex - 1].Frame then
      begin
        raise EAudio.Create('Automation frames must strictly increase');
      end;
      if (APoints[LIndex - 1].Transition = atExponential) and
        ((APoints[LIndex - 1].Value <= 0) or (APoints[LIndex].Value <= 0)) then
      begin
        raise EAudio.Create('Exponential automation requires positive endpoints');
      end;
    end;
    FMinimum := Min(FMinimum, APoints[LIndex].Value);
    FMaximum := Max(FMaximum, APoints[LIndex].Value);
  end;
  FPoints := Copy(APoints);
end;

constructor TAutomationCurve.CreateLfo(const APeriodFrames: Int64;
  const AShape: TAutomationLfoShape; const APhaseFrames: Int64);
begin
  inherited Create;
  if (APeriodFrames < 4) or (APhaseFrames < 0) or (APhaseFrames >= APeriodFrames) or
    not (AShape in [alsSine, alsTriangle]) then
  begin
    raise EAudio.Create('LFO requires period >=4 frames, phase within period and a supported shape');
  end;
  FKind := akLfo;
  FDepth := 1;
  FPeriodFrames := APeriodFrames;
  FPhaseFrames := APhaseFrames;
  FLfoShape := AShape;
  FMinimum := -1;
  FMaximum := 1;
end;

constructor TAutomationCurve.CreateAffine(const ASource: TAutomationCurve;
  const AScale, AOffset: Double);
var
  LFirst: Double;
  LLast: Double;
begin
  inherited Create;
  if (ASource = nil) or (ASource.Depth >= MaximumAutomationDepth) then
  begin
    raise EAudio.Create('Affine automation requires a source within the depth budget');
  end;
  RequireFinite(AScale, 'Automation scale');
  RequireFinite(AOffset, 'Automation offset');
  if (Abs(AScale) > MaximumAutomationMagnitude) or
    (Abs(AOffset) > MaximumAutomationMagnitude) then
  begin
    raise EAudio.Create('Affine automation coefficients exceed bounds');
  end;
  LFirst := AOffset + AScale * ASource.Minimum;
  LLast := AOffset + AScale * ASource.Maximum;
  FMinimum := Min(LFirst, LLast);
  FMaximum := Max(LFirst, LLast);
  if (Abs(FMinimum) > MaximumAutomationMagnitude) or
    (Abs(FMaximum) > MaximumAutomationMagnitude) then
  begin
    raise EAudio.Create('Affine automation output exceeds bounds');
  end;
  FKind := akAffine;
  FDepth := ASource.Depth + 1;
  FScale := AScale;
  FOffset := AOffset;
  FSource := ASource.Clone;
end;

destructor TAutomationCurve.Destroy;
begin
  FSource.Free;
  inherited Destroy;
end;

function TAutomationCurve.ValueAt(const AFrame: Int64): Double;
var
  LLow: Integer;
  LHigh: Integer;
  LMiddle: Integer;
  LRatio: Double;
  LStart: Double;
  LEnd: Double;
  LPhase: Int64;
begin
  if AFrame < 0 then
  begin
    raise EAudio.Create('Automation frame must be nonnegative');
  end;
  if FKind = akAffine then
  begin
    Result := FOffset + FScale * FSource.ValueAt(AFrame);
    Exit(Max(FMinimum, Min(FMaximum, Result)));
  end;
  if FKind = akLfo then
  begin
    LPhase := AFrame mod FPeriodFrames;
    { Add phase modulo period without overflowing near High(Int64). }
    if LPhase >= FPeriodFrames - FPhaseFrames then
    begin
      LPhase := LPhase - (FPeriodFrames - FPhaseFrames);
    end
    else
    begin
      LPhase := LPhase + FPhaseFrames;
    end;
    LRatio := LPhase / FPeriodFrames;
    if FLfoShape = alsSine then
    begin
      Result := Sin(2 * Pi * LRatio);
    end
    else if LRatio <= 0.25 then
    begin
      Result := 4 * LRatio;
    end
    else if LRatio <= 0.75 then
    begin
      Result := 2 - 4 * LRatio;
    end
    else
    begin
      Result := 4 * LRatio - 4;
    end;
    Exit(Max(FMinimum, Min(FMaximum, Result)));
  end;
  if AFrame <= FPoints[0].Frame then
  begin
    Exit(FPoints[0].Value);
  end;
  if AFrame >= FPoints[High(FPoints)].Frame then
  begin
    Exit(FPoints[High(FPoints)].Value);
  end;
  LLow := 0;
  LHigh := High(FPoints);
  while LHigh - LLow > 1 do
  begin
    LMiddle := LLow + (LHigh - LLow) div 2;
    if FPoints[LMiddle].Frame <= AFrame then
    begin
      LLow := LMiddle;
    end
    else
    begin
      LHigh := LMiddle;
    end;
  end;
  LStart := FPoints[LLow].Value;
  LEnd := FPoints[LHigh].Value;
  if (AFrame = FPoints[LLow].Frame) or (FPoints[LLow].Transition = atHold) then
  begin
    Exit(LStart);
  end;
  LRatio := (AFrame - FPoints[LLow].Frame) /
    (FPoints[LHigh].Frame - FPoints[LLow].Frame);
  case FPoints[LLow].Transition of
    atHold:
    begin
      Result := LStart;
    end;
    atLinear:
    begin
      Result := (1 - LRatio) * LStart + LRatio * LEnd;
    end;
    atExponential:
    begin
      { Log interpolation avoids overflow from dividing extreme positive values. }
      Result := Exp((1 - LRatio) * Ln(LStart) + LRatio * Ln(LEnd));
    end;
  end;
  { Rounding must not violate the bounds used by render preflight. }
  Result := Max(Min(LStart, LEnd), Min(Max(LStart, LEnd), Result));
end;

function TAutomationCurve.CopyPoints: TAutomationPoints;
begin
  if FKind <> akPoints then
  begin
    raise EAudio.Create('Generated automation has no finite point representation; use Clone');
  end;
  Result := Copy(FPoints);
end;

function TAutomationCurve.Clone: TAutomationCurve;
begin
  case FKind of
    akPoints:
    begin
      Result := TAutomationCurve.Create(FPoints);
    end;
    akLfo:
    begin
      Result := TAutomationCurve.CreateLfo(FPeriodFrames, FLfoShape, FPhaseFrames);
    end;
    akAffine:
    begin
      Result := TAutomationCurve.CreateAffine(FSource, FScale, FOffset);
    end;
  end;
end;

function FrequencyWithCents(const AFrequencyHz, ACents: Double): Double;
begin
  RequireFinite(AFrequencyHz, 'Base frequency');
  RequireFinite(ACents, 'Pitch modulation');
  if (AFrequencyHz < 0) or (AFrequencyHz > MaximumSampleRate) or (Abs(ACents) > 19200) then
  begin
    raise EAudio.Create('Pitch modulation requires 0..384000 Hz and +/-19200 cents');
  end;
  Result := AFrequencyHz * Power(2, ACents / 1200);
end;

end.
