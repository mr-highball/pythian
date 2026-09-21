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
unit pythian.source.wavetable;

{$mode delphi}
{$H+}

interface

uses
  pythian.audio,
  pythian.automation,
  pythian.source;

const
  MaximumTableHarmonics = 128;
  MaximumTableSize = 8192;
  MaximumWavetableCycleFrames = 8192;
  MaximumHarmonicFitFrames = 65536;
  MaximumHarmonicFitWork = 134217728;
  MaximumWavetableTrajectoryRecipes = 32;
  MaximumWavetableTrajectoryWork = 16777216;

type
  TWavetableCoefficients = array of Double;
  TWavetableCycleRecipe = record
    Sine: TWavetableCoefficients;
    Cosine: TWavetableCoefficients;
    Mean: Double; { Measured DC, excluded from the periodic source recipe. }
  end;
  TWavetableCycleRecipes = array of TWavetableCycleRecipe;

  TWavetableMagnitudeShape = record
    Recipe: TWavetableCycleRecipe; { Nonnegative sine magnitudes, unit cycle RMS. }
    CycleRms: Double; { Full periodic model, not finite-window or perceptual RMS. }
  end;

  THarmonicFit = record
    Recipe: TWavetableCycleRecipe;
    FrequencyHz: Double;
    AcRms: Double;
    ResidualRms: Double;
    RelativeError: Double; { Residual / AC RMS; zero for constant input (no evidence). }
  end;

  THarmonicPhaseFit = record
    Recipe: TWavetableCycleRecipe;
    MinimumHz: Double; { Minimum adjacent-sample phase increment * sample rate. }
    MaximumHz: Double;
    AcRms: Double;
    ResidualRms: Double;
    RelativeError: Double;
  end;

  { Owns precomputed harmonic-limited single-cycle tables. Coefficient index zero
    is harmonic one; missing sine/cosine coefficients mean zero. No DC term.
    Sources borrow the tables, retain phase and crossfade adjacent harmonic caps. }
  TWavetableSourceFactory = class(TAudioSourceFactory)
  private
    FTables: array of TAudioSamples;
    FCaps: array of Integer;
    FSize: Integer;
    FTargets: array of TWavetableSourceFactory;
    FMorph: TAutomationCurve;
    FMagnitudeRms: Double;
    FShapeCorrelations: array of Double;
    procedure Initialize(const ASine, ACosine: array of Double; const ATableSize: Integer);
    procedure InitializeTrajectory(const ARecipes: array of TWavetableCycleRecipe;
      const APosition: TAutomationCurve; const ATableSize: Integer);
  public
    constructor Create(const ASine, ACosine: array of Double; const ATableSize: Integer = 2048);
    { Owns two table banks and a cloned note-relative 0..1 control. Linear
      amplitude interpolation preserves declared phase; recipe means are excluded.
      Both banks share phase and retain their independent harmonic caps. }
    constructor CreateMorph(const AFrom, ATo: TWavetableCycleRecipe;
      const AMorph: TAutomationCurve; const ATableSize: Integer = 2048);
    { Owns 2..32 banks and a cloned note-relative recipe-index control in
      0..Count-1. Fractional indices interpolate adjacent banks at shared phase;
      only two banks are read per frame. Caller supplies phase-compatible recipes
      and control coordinates at the playback sample rate. No pitch inference,
      phase alignment, gain normalization or gate-dependent retiming is implied.
      Construction is bounded by MaximumWavetableTrajectoryWork harmonic terms. }
    constructor CreateTrajectory(const ARecipes: array of TWavetableCycleRecipe;
      const APosition: TAutomationCurve; const ATableSize: Integer = 2048);
    { Factors each recipe into nonnegative zero-phase harmonic shape and level.
      Shape interpolation is renormalized analytically at every frame to the
      caller's target cycle RMS (0,16]. DC and recorded phase are discarded.
      Nyquist caps still attenuate partials; omitted energy is never boosted back.
      This is spectral/dynamics separation, not perceptual loudness matching. }
    constructor CreateMagnitudeTrajectory(const ARecipes: array of TWavetableCycleRecipe;
      const APosition: TAutomationCurve; const ATargetRms: Double;
      const ATableSize: Integer = 2048);
    destructor Destroy; override;
    function CreateSource(const ASampleRate: Integer; const ASeed: Cardinal): TAudioSource; override;
    function FrameCost(const ASampleRate: Integer): Integer; override;
    function Channels: Integer; override;
  end;

{ The caller declares one half-open period in one channel; no pitch/cycle
  detection, endpoint duplication, windowing, normalization or phase alignment.
  Returns detached Fourier coefficients, index zero = harmonic one. Harmonics
  must be strictly below the selected cycle's Nyquist and fit the factory bounds.
  Construction is bounded to 8192 frames * 128 harmonics. Failure preserves a
  previously assigned recipe; successful arrays belong to the caller. }
function AnalyzeWavetableCycle(const AClip: TAudioClip;
  const AStartFrame, AFrameCount, AChannel, AHarmonics: Integer): TWavetableCycleRecipe;

{ Detached magnitude-only shape and its independent full-period level. Missing
  coefficients are zero. Rejects empty/silent/nonfinite recipes and coefficients
  outside the factory's magnitude limit. Scaling avoids squaring tiny inputs.
  Raw fitted phase, DC and finite-window residual evidence remain caller-owned. }
function FactorWavetableMagnitudes(const ARecipe: TWavetableCycleRecipe): TWavetableMagnitudeShape;

{ Fit DC and real harmonic sinusoids jointly at a caller-supplied fundamental.
  The interval need not contain an integer number of periods. Phase zero is its
  first frame. Streaming QR avoids assuming orthogonal finite-window harmonics.
  At least four periods, strict source Nyquist, bounded work and numerical rank
  are required. Residual includes noise, drift and unmodelled harmonics; it is
  evidence, not automatic voice/pitch admission. No normalization or windowing.
  Arrays are detached; failure preserves a previously assigned fit. }
function FitWavetableHarmonics(const AClip: TAudioClip;
  const AStartFrame, AFrameCount, AChannel, AHarmonics: Integer;
  const AFrequencyHz: Double): THarmonicFit;
{ Shared geometry/work admission for callers retaining measured fit evidence. }
function HarmonicFitWork(const AFrameCount, ASampleRate, AHarmonics: Integer;
  const AFrequencyHz: Double): Int64;

{ Fit constant harmonic coefficients along a caller-declared changing phase path.
  One unwrapped fundamental phase in cycles per input frame, starting at zero.
  Phases must increase strictly, cover at least four cycles, and keep every
  adjacent increment * harmonic count strictly below half a cycle. These are
  discrete sampling bounds, not a proof of continuous-time FM bandwidth.
  The selected interval length is Length(APhaseCycles). No pitch/phase inference,
  phase normalization or evolving coefficient fit is implied. Input is borrowed
  for this synchronous call; output arrays are detached. }
function FitWavetableHarmonicsByPhase(const AClip: TAudioClip;
  const AStartFrame, AChannel, AHarmonics: Integer;
  const APhaseCycles: array of Double): THarmonicPhaseFit;
function PhaseHarmonicFitWork(const APhaseCycles: array of Double;
  const ASampleRate, AHarmonics: Integer): Int64;

implementation

uses
  Math;

function FactorWavetableMagnitudes(const ARecipe: TWavetableCycleRecipe): TWavetableMagnitudeShape;
var
  LShape: TWavetableMagnitudeShape;
  LIndex: Integer;
  LCount: Integer;
  LScale: Double;
  LPower: Double;
  LSine: Double;
  LCosine: Double;
begin
  LCount := Max(Length(ARecipe.Sine), Length(ARecipe.Cosine));
  if (LCount < 1) or (LCount > MaximumTableHarmonics) then
  begin
    raise EAudio.Create('Magnitude shape requires 1..128 harmonics');
  end;
  RequireFinite(ARecipe.Mean, 'Magnitude recipe DC');
  LScale := 0;
  for LIndex := 0 to High(ARecipe.Sine) do
  begin
    RequireFinite(ARecipe.Sine[LIndex], 'Magnitude sine coefficient');
    LScale := Max(LScale, Abs(ARecipe.Sine[LIndex]));
  end;
  for LIndex := 0 to High(ARecipe.Cosine) do
  begin
    RequireFinite(ARecipe.Cosine[LIndex], 'Magnitude cosine coefficient');
    LScale := Max(LScale, Abs(ARecipe.Cosine[LIndex]));
  end;
  if (LScale = 0) or (LScale > 16) then
  begin
    raise EAudio.Create('Magnitude shape requires nonzero coefficients within magnitude limit 16');
  end;
  LShape := Default(TWavetableMagnitudeShape);
  SetLength(LShape.Recipe.Sine, LCount);
  SetLength(LShape.Recipe.Cosine, LCount);
  LPower := 0;
  for LIndex := 0 to LCount - 1 do
  begin
    LSine := 0;
    LCosine := 0;
    if LIndex < Length(ARecipe.Sine) then
    begin
      LSine := ARecipe.Sine[LIndex] / LScale;
    end;
    if LIndex < Length(ARecipe.Cosine) then
    begin
      LCosine := ARecipe.Cosine[LIndex] / LScale;
    end;
    LShape.Recipe.Sine[LIndex] := Sqrt(Sqr(LSine) + Sqr(LCosine));
    LPower := LPower + Sqr(LSine) + Sqr(LCosine);
  end;
  LPower := Sqrt(0.5 * LPower);
  LShape.CycleRms := LScale * LPower;
  if LShape.CycleRms = 0 then
  begin
    raise EAudio.Create('Magnitude level is below representable positive RMS');
  end;
  for LIndex := 0 to LCount - 1 do
  begin
    LShape.Recipe.Sine[LIndex] := LShape.Recipe.Sine[LIndex] / LPower;
  end;
  Result := LShape;
end;

function HarmonicFitWork(const AFrameCount, ASampleRate, AHarmonics: Integer;
  const AFrequencyHz: Double): Int64;
var
  LTerms: Integer;
begin
  ValidateAudioFormat(ASampleRate, 1);
  RequireFinite(AFrequencyHz, 'Harmonic fit fundamental');
  if (AFrameCount < 16) or (AFrameCount > MaximumHarmonicFitFrames) or
    (AHarmonics < 1) or (AHarmonics > MaximumTableHarmonics) or
    (AFrequencyHz <= 0) or (AFrequencyHz >= ASampleRate / 2) then
  begin
    raise EAudio.Create('Invalid bounded harmonic fit interval or frequency');
  end;
  LTerms := 2 * AHarmonics + 1;
  Result := Int64(AFrameCount) * (Int64(LTerms) * LTerms + 6 * LTerms);
  if ((AFrameCount - 1) * AFrequencyHz / ASampleRate < 4) or
    (AHarmonics * AFrequencyHz >= ASampleRate / 2) or
    (LTerms >= AFrameCount) or (Result > MaximumHarmonicFitWork) then
  begin
    raise EAudio.Create('Harmonic fit needs four periods, independent sub-Nyquist terms and bounded work');
  end;
end;

function PhaseHarmonicFitWork(const APhaseCycles: array of Double;
  const ASampleRate, AHarmonics: Integer): Int64;
var
  LTerms: Integer;
  LFrame: Integer;
  LStep: Double;
begin
  ValidateAudioFormat(ASampleRate, 1);
  if (Length(APhaseCycles) < 16) or (Length(APhaseCycles) > MaximumHarmonicFitFrames) or
    (AHarmonics < 1) or (AHarmonics > MaximumTableHarmonics) then
  begin
    raise EAudio.Create('Invalid bounded phase-fit interval or harmonic count');
  end;
  LTerms := 2 * AHarmonics + 1;
  Result := Int64(Length(APhaseCycles)) * (Int64(LTerms) * LTerms + 6 * LTerms);
  if (LTerms >= Length(APhaseCycles)) or (Result > MaximumHarmonicFitWork) then
  begin
    raise EAudio.Create('Phase fit requires independent terms and bounded work');
  end;
  RequireFinite(APhaseCycles[0], 'Initial harmonic-fit phase');
  if APhaseCycles[0] <> 0 then
  begin
    raise EAudio.Create('Harmonic-fit phase must start at zero cycles');
  end;
  for LFrame := 1 to High(APhaseCycles) do
  begin
    RequireFinite(APhaseCycles[LFrame], 'Harmonic-fit phase');
    if APhaseCycles[LFrame] <= APhaseCycles[LFrame - 1] then
    begin
      raise EAudio.Create('Harmonic-fit phases must increase strictly');
    end;
    LStep := APhaseCycles[LFrame] - APhaseCycles[LFrame - 1];
    if LStep >= 0.5 / AHarmonics then
    begin
      raise EAudio.Create('Harmonic-fit phase increment reaches sampled harmonic Nyquist');
    end;
  end;
  if APhaseCycles[High(APhaseCycles)] < 4 then
  begin
    raise EAudio.Create('Harmonic phase fit requires at least four cycles');
  end;
end;

function FitHarmonicBasis(const AClip: TAudioClip;
  const AStartFrame, AFrameCount, AChannel, AHarmonics: Integer;
  const AFrequencyHz: Double; const APhaseCycles: array of Double;
  const AUsePhase: Boolean): THarmonicFit;
var
  LFit: THarmonicFit;
  LMatrix: array of Double;
  LRow: array of Double;
  LRhs: array of Double;
  LCoefficients: array of Double;
  LTerms: Integer;
  LFrame: Integer;
  LHarmonic: Integer;
  LColumn: Integer;
  LNext: Integer;
  LBase: Integer;
  LAngle: Double;
  LSample: Double;
  LValue: Double;
  LRadius: Double;
  LCosine: Double;
  LSine: Double;
  LOld: Double;
  LMean: Double;
  LVariance: Double;
  LDelta: Double;
  LError: Double;
begin
  if AClip = nil then
  begin
    raise EAudio.Create('Harmonic fitting requires a source clip');
  end;
  if AUsePhase then
  begin
    PhaseHarmonicFitWork(APhaseCycles, AClip.SampleRate, AHarmonics);
  end
  else
  begin
    HarmonicFitWork(AFrameCount, AClip.SampleRate, AHarmonics, AFrequencyHz);
  end;
  if (AStartFrame < 0) or
    (Int64(AStartFrame) + AFrameCount > AClip.FrameCount) or
    (AChannel < 0) or (AChannel >= AClip.Channels) then
  begin
    raise EAudio.Create('Invalid bounded harmonic fit interval, channel or frequency');
  end;
  LTerms := 2 * AHarmonics + 1;
  LFit := Default(THarmonicFit);
  LFit.FrequencyHz := AFrequencyHz;
  SetLength(LMatrix, LTerms * LTerms);
  SetLength(LRow, LTerms);
  SetLength(LRhs, LTerms);
  SetLength(LCoefficients, LTerms);
  LMean := 0;
  LVariance := 0;
  for LFrame := 0 to AFrameCount - 1 do
  begin
    LSample := AClip.SampleAt(AStartFrame + LFrame, AChannel);
    LDelta := LSample - LMean;
    LMean := LMean + LDelta / (LFrame + 1);
    LVariance := LVariance + LDelta * (LSample - LMean);
    LRow[0] := 1;
    for LHarmonic := 1 to AHarmonics do
    begin
      if AUsePhase then
      begin
        LAngle := 2 * Pi * LHarmonic * APhaseCycles[LFrame];
      end
      else
      begin
        LAngle := 2 * Pi * LHarmonic * AFrequencyHz * LFrame / AClip.SampleRate;
      end;
      LRow[2 * LHarmonic - 1] := Sin(LAngle);
      LRow[2 * LHarmonic] := Cos(LAngle);
    end;
    { Append one observation with Givens rotations. Only the triangular factor
      and transformed right-hand side are retained; no normal equations. }
    LValue := LSample;
    for LColumn := 0 to LTerms - 1 do
    begin
      if LRow[LColumn] = 0 then
      begin
        Continue;
      end;
      LBase := LColumn * LTerms;
      LOld := LMatrix[LBase + LColumn];
      LRadius := Sqrt(Sqr(LOld) + Sqr(LRow[LColumn]));
      LCosine := LOld / LRadius;
      LSine := LRow[LColumn] / LRadius;
      LMatrix[LBase + LColumn] := LRadius;
      for LNext := LColumn + 1 to LTerms - 1 do
      begin
        LOld := LMatrix[LBase + LNext];
        LMatrix[LBase + LNext] := LCosine * LOld + LSine * LRow[LNext];
        LRow[LNext] := -LSine * LOld + LCosine * LRow[LNext];
      end;
      LOld := LRhs[LColumn];
      LRhs[LColumn] := LCosine * LOld + LSine * LValue;
      LValue := -LSine * LOld + LCosine * LValue;
    end;
  end;
  for LColumn := LTerms - 1 downto 0 do
  begin
    LBase := LColumn * LTerms;
    if LMatrix[LBase + LColumn] <= Sqrt(AFrameCount) * 1E-8 then
    begin
      raise EAudio.Create('Harmonic fit basis is numerically rank deficient');
    end;
    LValue := LRhs[LColumn];
    for LNext := LColumn + 1 to LTerms - 1 do
    begin
      LValue := LValue - LMatrix[LBase + LNext] * LCoefficients[LNext];
    end;
    LCoefficients[LColumn] := LValue / LMatrix[LBase + LColumn];
    RequireFinite(LCoefficients[LColumn], 'Harmonic fit coefficient');
    if (LColumn > 0) and (Abs(LCoefficients[LColumn]) > 16) then
    begin
      raise EAudio.Create('Harmonic fit coefficient exceeds factory magnitude limit 16');
    end;
  end;
  LFit.Recipe.Mean := LCoefficients[0];
  SetLength(LFit.Recipe.Sine, AHarmonics);
  SetLength(LFit.Recipe.Cosine, AHarmonics);
  for LHarmonic := 1 to AHarmonics do
  begin
    LFit.Recipe.Sine[LHarmonic - 1] := LCoefficients[2 * LHarmonic - 1];
    LFit.Recipe.Cosine[LHarmonic - 1] := LCoefficients[2 * LHarmonic];
  end;
  LError := 0;
  for LFrame := 0 to AFrameCount - 1 do
  begin
    LValue := LFit.Recipe.Mean;
    for LHarmonic := 1 to AHarmonics do
    begin
      if AUsePhase then
      begin
        LAngle := 2 * Pi * LHarmonic * APhaseCycles[LFrame];
      end
      else
      begin
        LAngle := 2 * Pi * LHarmonic * AFrequencyHz * LFrame / AClip.SampleRate;
      end;
      LValue := LValue + LFit.Recipe.Sine[LHarmonic - 1] * Sin(LAngle) +
        LFit.Recipe.Cosine[LHarmonic - 1] * Cos(LAngle);
    end;
    LError := LError + Sqr(AClip.SampleAt(AStartFrame + LFrame, AChannel) - LValue);
  end;
  LFit.AcRms := Sqrt(Max(0, LVariance) / AFrameCount);
  LFit.ResidualRms := Sqrt(LError / AFrameCount);
  if LFit.AcRms > 0 then
  begin
    LFit.RelativeError := LFit.ResidualRms / LFit.AcRms;
  end;
  Result := LFit;
end;

function FitWavetableHarmonics(const AClip: TAudioClip;
  const AStartFrame, AFrameCount, AChannel, AHarmonics: Integer;
  const AFrequencyHz: Double): THarmonicFit;
begin
  Result := FitHarmonicBasis(AClip, AStartFrame, AFrameCount, AChannel,
    AHarmonics, AFrequencyHz, [], False);
end;

function FitWavetableHarmonicsByPhase(const AClip: TAudioClip;
  const AStartFrame, AChannel, AHarmonics: Integer;
  const APhaseCycles: array of Double): THarmonicPhaseFit;
var
  LFit: THarmonicFit;
  LResult: THarmonicPhaseFit;
  LFrame: Integer;
  LFrequency: Double;
begin
  LFit := FitHarmonicBasis(AClip, AStartFrame, Length(APhaseCycles), AChannel,
    AHarmonics, 0, APhaseCycles, True);
  LResult := Default(THarmonicPhaseFit);
  LResult.Recipe := LFit.Recipe;
  LResult.AcRms := LFit.AcRms;
  LResult.ResidualRms := LFit.ResidualRms;
  LResult.RelativeError := LFit.RelativeError;
  LResult.MinimumHz := AClip.SampleRate;
  for LFrame := 1 to High(APhaseCycles) do
  begin
    LFrequency := (APhaseCycles[LFrame] - APhaseCycles[LFrame - 1]) * AClip.SampleRate;
    LResult.MinimumHz := Min(LResult.MinimumHz, LFrequency);
    LResult.MaximumHz := Max(LResult.MaximumHz, LFrequency);
  end;
  Result := LResult;
end;

function AnalyzeWavetableCycle(const AClip: TAudioClip;
  const AStartFrame, AFrameCount, AChannel, AHarmonics: Integer): TWavetableCycleRecipe;
var
  LFrame: Integer;
  LHarmonic: Integer;
  LAngle: Double;
  LSample: Double;
  LSine: Double;
  LCosine: Double;
  LRecipe: TWavetableCycleRecipe;
begin
  LRecipe.Sine := nil;
  LRecipe.Cosine := nil;
  LRecipe.Mean := 0;
  if AClip = nil then
  begin
    raise EAudio.Create('Wavetable cycle requires a source clip');
  end;
  if (AStartFrame < 0) or (AFrameCount < 3) or
    (AFrameCount > MaximumWavetableCycleFrames) or
    (Int64(AStartFrame) + AFrameCount > AClip.FrameCount) or
    (AChannel < 0) or (AChannel >= AClip.Channels) or
    (AHarmonics < 1) or (AHarmonics > MaximumTableHarmonics) or
    (2 * Int64(AHarmonics) >= AFrameCount) then
  begin
    raise EAudio.Create('Wavetable cycle requires an in-range channel/period and 1..128 harmonics below cycle Nyquist');
  end;
  for LFrame := 0 to AFrameCount - 1 do
  begin
    LRecipe.Mean := LRecipe.Mean + AClip.SampleAt(AStartFrame + LFrame, AChannel);
  end;
  LRecipe.Mean := LRecipe.Mean / AFrameCount;
  SetLength(LRecipe.Sine, AHarmonics);
  SetLength(LRecipe.Cosine, AHarmonics);
  for LHarmonic := 1 to AHarmonics do
  begin
    LSine := 0;
    LCosine := 0;
    for LFrame := 0 to AFrameCount - 1 do
    begin
      LSample := AClip.SampleAt(AStartFrame + LFrame, AChannel) - LRecipe.Mean;
      LAngle := 2 * Pi * LHarmonic * LFrame / AFrameCount;
      LSine := LSine + LSample * Sin(LAngle);
      LCosine := LCosine + LSample * Cos(LAngle);
    end;
    LSine := 2 * LSine / AFrameCount;
    LCosine := 2 * LCosine / AFrameCount;
    if (Abs(LSine) > 16) or (Abs(LCosine) > 16) then
    begin
      raise EAudio.Create('Measured wavetable coefficient exceeds factory magnitude limit 16');
    end;
    LRecipe.Sine[LHarmonic - 1] := LSine;
    LRecipe.Cosine[LHarmonic - 1] := LCosine;
  end;
  Result := LRecipe;
end;

type
  TWavetableSource = class(TAudioSource)
  private
    FDefinition: TWavetableSourceFactory;
    FSampleRate: Integer;
    FPhase: Double;
    FFrame: Int64;
    function Lookup(const ADefinition: TWavetableSourceFactory; const ALevel: Integer): Double;
    function Sample(const ADefinition: TWavetableSourceFactory; const AFrequencyHz: Double): Double;
  public
    constructor Create(const ADefinition: TWavetableSourceFactory; const ASampleRate: Integer);
    procedure Reset; override;
    function ReadFrame(const AFrequencyHz: Double; out ALeft, ARight: Double): Boolean; override;
  end;

constructor TWavetableSourceFactory.Create(const ASine, ACosine: array of Double;
  const ATableSize: Integer);
begin
  inherited Create;
  Initialize(ASine, ACosine, ATableSize);
end;

constructor TWavetableSourceFactory.CreateMorph(const AFrom, ATo: TWavetableCycleRecipe;
  const AMorph: TAutomationCurve; const ATableSize: Integer);
begin
  inherited Create;
  InitializeTrajectory([AFrom, ATo], AMorph, ATableSize);
end;

constructor TWavetableSourceFactory.CreateTrajectory(
  const ARecipes: array of TWavetableCycleRecipe;
  const APosition: TAutomationCurve; const ATableSize: Integer);
begin
  inherited Create;
  InitializeTrajectory(ARecipes, APosition, ATableSize);
end;

constructor TWavetableSourceFactory.CreateMagnitudeTrajectory(
  const ARecipes: array of TWavetableCycleRecipe;
  const APosition: TAutomationCurve; const ATargetRms: Double; const ATableSize: Integer);
var
  LShapes: TWavetableCycleRecipes;
  LShape: TWavetableMagnitudeShape;
  LIndex: Integer;
  LHarmonic: Integer;
  LCorrelation: Double;
begin
  inherited Create;
  RequireFinite(ATargetRms, 'Magnitude trajectory target cycle RMS');
  if (Length(ARecipes) < 2) or
    (Length(ARecipes) > MaximumWavetableTrajectoryRecipes) or
    (ATargetRms <= 0) or (ATargetRms > 16) then
  begin
    raise EAudio.Create('Magnitude trajectory requires 2..32 recipes and target cycle RMS in (0,16]');
  end;
  SetLength(LShapes, Length(ARecipes));
  for LIndex := 0 to High(ARecipes) do
  begin
    LShape := FactorWavetableMagnitudes(ARecipes[LIndex]);
    LShapes[LIndex] := LShape.Recipe;
  end;
  SetLength(FShapeCorrelations, High(LShapes));
  for LIndex := 0 to High(FShapeCorrelations) do
  begin
    LCorrelation := 0;
    for LHarmonic := 0 to Min(High(LShapes[LIndex].Sine), High(LShapes[LIndex + 1].Sine)) do
    begin
      LCorrelation := LCorrelation + 0.5 * LShapes[LIndex].Sine[LHarmonic] *
        LShapes[LIndex + 1].Sine[LHarmonic];
    end;
    FShapeCorrelations[LIndex] := Max(0, Min(1, LCorrelation));
  end;
  InitializeTrajectory(LShapes, APosition, ATableSize);
  FMagnitudeRms := ATargetRms;
end;

procedure TWavetableSourceFactory.InitializeTrajectory(
  const ARecipes: array of TWavetableCycleRecipe;
  const APosition: TAutomationCurve; const ATableSize: Integer);
var
  LIndex: Integer;
  LCount: Integer;
  LCap: Integer;
  LWork: Int64;
begin
  if (Length(ARecipes) < 2) or
    (Length(ARecipes) > MaximumWavetableTrajectoryRecipes) or (APosition = nil) then
  begin
    raise EAudio.Create('Wavetable trajectory requires 2..32 recipes and a position curve');
  end;
  if (APosition.Minimum < 0) or (APosition.Maximum > High(ARecipes)) then
  begin
    raise EAudio.Create('Wavetable trajectory control exceeds recipe indices');
  end;
  if (ATableSize < 256) or (ATableSize > MaximumTableSize) or
    ((ATableSize and (ATableSize - 1)) <> 0) then
  begin
    raise EAudio.Create('Wavetable trajectory requires a 256..8192 power-of-two table');
  end;
  LWork := 0;
  for LIndex := 0 to High(ARecipes) do
  begin
    LCount := Max(Length(ARecipes[LIndex].Sine), Length(ARecipes[LIndex].Cosine));
    if (LCount < 1) or (LCount > MaximumTableHarmonics) or
      (LCount >= ATableSize div 2) then
    begin
      raise EAudio.Create('Wavetable trajectory harmonic count exceeds table bounds');
    end;
    LCap := 1;
    while LCap < LCount do
    begin
      LCap := LCap * 2;
    end;
    while LCap > 0 do
    begin
      Inc(LWork, Int64(ATableSize) * Min(LCap, LCount));
      LCap := LCap div 2;
    end;
  end;
  if LWork > MaximumWavetableTrajectoryWork then
  begin
    raise EAudio.Create('Wavetable trajectory construction exceeds harmonic-work budget');
  end;
  Initialize(ARecipes[0].Sine, ARecipes[0].Cosine, ATableSize);
  SetLength(FTargets, High(ARecipes));
  for LIndex := 1 to High(ARecipes) do
  begin
    FTargets[LIndex - 1] := TWavetableSourceFactory.Create(
      ARecipes[LIndex].Sine, ARecipes[LIndex].Cosine, ATableSize);
  end;
  FMorph := APosition.Clone;
end;

destructor TWavetableSourceFactory.Destroy;
var
  LIndex: Integer;
begin
  FMorph.Free;
  for LIndex := 0 to High(FTargets) do
  begin
    FTargets[LIndex].Free;
  end;
  inherited;
end;

procedure TWavetableSourceFactory.Initialize(const ASine, ACosine: array of Double;
  const ATableSize: Integer);
var
  LCount: Integer;
  LCap: Integer;
  LLevel: Integer;
  LFrame: Integer;
  LHarmonic: Integer;
  LValue: Double;
  LAngle: Double;
begin
  LCount := Max(Length(ASine), Length(ACosine));
  if (LCount < 1) or (LCount > MaximumTableHarmonics) or
    (ATableSize < 256) or (ATableSize > MaximumTableSize) or
    ((ATableSize and (ATableSize - 1)) <> 0) or (LCount >= ATableSize div 2) then
  begin
    raise EAudio.Create('Wavetable requires 1..128 harmonics below a 256..8192 power-of-two table Nyquist');
  end;
  for LHarmonic := 0 to High(ASine) do
  begin
    RequireFinite(ASine[LHarmonic], 'Sine coefficient');
    if Abs(ASine[LHarmonic]) > 16 then
    begin
      raise EAudio.Create('Wavetable coefficient magnitude must be at most 16');
    end;
  end;
  for LHarmonic := 0 to High(ACosine) do
  begin
    RequireFinite(ACosine[LHarmonic], 'Cosine coefficient');
    if Abs(ACosine[LHarmonic]) > 16 then
    begin
      raise EAudio.Create('Wavetable coefficient magnitude must be at most 16');
    end;
  end;
  FSize := ATableSize;
  LCap := 1;
  LLevel := 2;
  while LCap < LCount do
  begin
    LCap := LCap * 2;
    Inc(LLevel);
  end;
  SetLength(FTables, LLevel);
  SetLength(FCaps, LLevel);
  for LLevel := 0 to High(FTables) do
  begin
    FCaps[LLevel] := LCap;
    SetLength(FTables[LLevel], FSize);
    for LFrame := 0 to FSize - 1 do
    begin
      LValue := 0;
      for LHarmonic := 1 to Min(LCap, LCount) do
      begin
        LAngle := 2 * Pi * LHarmonic * LFrame / FSize;
        if LHarmonic <= Length(ASine) then
        begin
          LValue := LValue + ASine[LHarmonic - 1] * Sin(LAngle);
        end;
        if LHarmonic <= Length(ACosine) then
        begin
          LValue := LValue + ACosine[LHarmonic - 1] * Cos(LAngle);
        end;
      end;
      FTables[LLevel][LFrame] := LValue;
    end;
    LCap := LCap div 2;
  end;
end;

function TWavetableSourceFactory.Channels: Integer;
begin
  Result := 1;
end;

function TWavetableSourceFactory.FrameCost(const ASampleRate: Integer): Integer;
begin
  ValidateAudioFormat(ASampleRate, 1);
  Result := 4;
  if FMorph <> nil then
  begin
    Result := 12 + FMorph.Depth;
    if Length(FTargets) > 1 then
    begin
      Inc(Result, 2);
    end;
    if FMagnitudeRms > 0 then
    begin
      Inc(Result, 8);
    end;
  end;
end;

function TWavetableSourceFactory.CreateSource(const ASampleRate: Integer;
  const ASeed: Cardinal): TAudioSource;
begin
  ValidateAudioFormat(ASampleRate, 1);
  Result := TWavetableSource.Create(Self, ASampleRate);
end;

constructor TWavetableSource.Create(const ADefinition: TWavetableSourceFactory;
  const ASampleRate: Integer);
begin
  inherited Create;
  FDefinition := ADefinition;
  FSampleRate := ASampleRate;
  Reset;
end;

procedure TWavetableSource.Reset;
begin
  FPhase := 0;
  FFrame := 0;
end;

function TWavetableSource.Lookup(const ADefinition: TWavetableSourceFactory;
  const ALevel: Integer): Double;
var
  LPosition: Double;
  LIndex: Integer;
  LNext: Integer;
  LFraction: Double;
begin
  LPosition := FPhase * ADefinition.FSize;
  LIndex := Trunc(LPosition);
  LFraction := LPosition - LIndex;
  LNext := (LIndex + 1) mod ADefinition.FSize;
  Result := (1 - LFraction) * ADefinition.FTables[ALevel][LIndex] +
    LFraction * ADefinition.FTables[ALevel][LNext];
end;

function TWavetableSource.Sample(const ADefinition: TWavetableSourceFactory;
  const AFrequencyHz: Double): Double;
var
  LLevel: Integer;
  LBudget: Double;
  LWeight: Double;
begin
  LLevel := 0;
  LWeight := 1;
  if AFrequencyHz > 0 then
  begin
    { Compare products before division, also admitting tiny nonzero frequencies. }
    while (LLevel < High(ADefinition.FCaps) - 1) and
      (AFrequencyHz * ADefinition.FCaps[LLevel] > FSampleRate * 0.5) do
    begin
      Inc(LLevel);
    end;
    if AFrequencyHz * (2 * ADefinition.FCaps[LLevel]) > FSampleRate * 0.5 then
    begin
      LBudget := (FSampleRate * 0.5) / AFrequencyHz;
      LWeight := Max(0, Min(1, LBudget / ADefinition.FCaps[LLevel] - 1));
    end;
  end;
  Result := LWeight * Lookup(ADefinition, LLevel) +
    (1 - LWeight) * Lookup(ADefinition, LLevel + 1);
end;

function TWavetableSource.ReadFrame(const AFrequencyHz: Double;
  out ALeft, ARight: Double): Boolean;
var
  LFrom: Double;
  LTo: Double;
  LMorph: Double;
  LIndex: Integer;
begin
  FDefinition.ValidateRange(AFrequencyHz, AFrequencyHz, FSampleRate);
  if (FDefinition.FMorph <> nil) and (FFrame = High(Int64)) then
  begin
    raise EAudio.Create('Wavetable morph frame clock exhausted');
  end;
  if FDefinition.FMorph <> nil then
  begin
    LMorph := FDefinition.FMorph.ValueAt(FFrame);
    LIndex := Min(Trunc(LMorph), High(FDefinition.FTargets));
    LMorph := LMorph - LIndex;
    if LIndex = 0 then
    begin
      LFrom := Sample(FDefinition, AFrequencyHz);
    end
    else
    begin
      LFrom := Sample(FDefinition.FTargets[LIndex - 1], AFrequencyHz);
    end;
    LTo := Sample(FDefinition.FTargets[LIndex], AFrequencyHz);
    ALeft := (1 - LMorph) * LFrom + LMorph * LTo;
    if FDefinition.FMagnitudeRms > 0 then
    begin
      { Nonnegative unit-RMS magnitude shapes have correlation in [0,1].
        Their convex mixture has squared RMS in [1/2,1], so this correction
        cannot amplify a cancellation or restore energy removed by pitch caps. }
      ALeft := ALeft * FDefinition.FMagnitudeRms / Sqrt(Sqr(1 - LMorph) +
        Sqr(LMorph) + 2 * LMorph * (1 - LMorph) * FDefinition.FShapeCorrelations[LIndex]);
    end;
    Inc(FFrame);
  end
  else
  begin
    ALeft := Sample(FDefinition, AFrequencyHz);
  end;
  ARight := ALeft;
  FPhase := Frac(FPhase + AFrequencyHz / FSampleRate);
  Result := True;
end;

end.
