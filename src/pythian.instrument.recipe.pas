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
unit pythian.instrument.recipe;
{$mode delphi}
{$H+}

interface

uses pythian.audio, pythian.text, pythian.source, pythian.source.oscillator,
  pythian.source.wavetable, pythian.source.sample, pythian.additive,
  pythian.automation, pythian.synth, pythian.instrument;

const InstrumentRecipeVersion = 1;

type
  TInstrumentSourceKind = (iskOscillator, iskAdditive, iskWavetable,
    iskFm, iskPm, iskSample);
  TInstrumentCurveKind = (ickPoints, ickLfo);
  TInstrumentControlTarget = (ictFrequencyHz, ictPitchCents,
    ictGainMultiplier, ictPan, ictCutoffHz);
  TInstrumentCurvePoint = record
    Seconds: Double;
    Value: Double;
    Transition: TAutomationTransition;
  end;
  TInstrumentCurvePoints = array of TInstrumentCurvePoint;
  { Time is note-relative seconds. LFO output is Offset + Scale * bipolar LFO.
    Point times use the primary floor sample clock; collapsed knots reject. }
  TInstrumentCurveRecipe = record
    Kind: TInstrumentCurveKind;
    Points: TInstrumentCurvePoints;
    LfoHz: Double;
    LfoPhaseCycles: Double;
    LfoShape: TAutomationLfoShape;
    Scale: Double;
    Offset: Double;
  end;
  TInstrumentControlRecipe = record
    Target: TInstrumentControlTarget;
    Curve: TInstrumentCurveRecipe;
  end;
  TInstrumentControlRecipes = array of TInstrumentControlRecipe;
  TInstrumentSourceRecipe = record
    Kind: TInstrumentSourceKind;
    Partials: TAdditivePartials;
    Tables: TWavetableCycleRecipes;
    TableSize: Integer;
    TableMotion: TInstrumentCurveRecipe;
    ModulatorRatio: Double;
    ModulationDepth: Double; { Hz for FM, radians for PM. }
    SampleId: TScalarText;
    SampleStartFrame: Integer;
    SampleEndFrame: Integer; { -1 explicitly selects the registered clip end. }
    SampleLoopStart: Integer;
    SampleLoopEnd: Integer;
    SampleHasLoop: Boolean;
    SampleRootHz: Double;
    SamplePlayback: TSamplePlayback;
    SampleQuality: TSampleQuality;
    SampleMaximumStep: Double;
  end;
  TInstrumentGateRecipe = record
    Enabled: Boolean;
    Held: TInstrumentCurveRecipe;
    Release: TInstrumentCurveRecipe;
    ReleaseSeconds: Double;
  end;
  TInstrumentZoneRecipe = record
    MinimumKey, MaximumKey: Integer;
    MinimumVelocity, MaximumVelocity: Integer;
    { Reuse primary numeric voice settings. Runtime pointers must all be nil;
      Source, Controls and Gate provide detached definitions instead. }
    Voice: TSynthVoice;
    Source: TInstrumentSourceRecipe;
    Controls: TInstrumentControlRecipes;
    Gate: TInstrumentGateRecipe;
  end;
  TInstrumentZoneRecipes = array of TInstrumentZoneRecipe;
  TInstrumentRecipe = record
    Id: TScalarText;
    Caption: TScalarText;
    Origin: TScalarText;
    Zones: TInstrumentZoneRecipes;
  end;
  TInstrumentRecipes = array of TInstrumentRecipe;
  TInstrumentSampleBinding = record
    Id: TScalarText;
    Clip: TAudioClip; { Borrowed only during recipe construction. }
  end;
  TInstrumentSampleBindings = array of TInstrumentSampleBinding;

  { Big Boss: one owned realization of a detached recipe through primary source
    factories, curves, envelopes and instrument planning. No DSP is copied here.
    Registered sample regions are copied by the primary sample factory. The bank
    must outlive its plans and players; sources can borrow its wavetable/sample
    storage. The exposed instrument is immutable and borrowed by the caller. }
  TRecipeInstrument = class
  private
    FRecipe: TInstrumentRecipe;
    FInstrument: TInstrument;
    FZones: TInstrumentZones;
    FFactories: array of TAudioSourceFactory;
    FSampleRate: Integer;
  public
    constructor Create(const ARecipe: TInstrumentRecipe; const ASampleRate: Integer;
      const ASamples: TInstrumentSampleBindings = nil);
    destructor Destroy; override;
    function CopyRecipe: TInstrumentRecipe;
    property Instrument: TInstrument read FInstrument;
    property SampleRate: Integer read FSampleRate;
  end;

function DefaultInstrumentCurve: TInstrumentCurveRecipe;
function DefaultInstrumentZoneRecipe: TInstrumentZoneRecipe;
function CopyInstrumentRecipe(const ARecipe: TInstrumentRecipe): TInstrumentRecipe;
{ Owns the returned primary curve; caller frees it after its consumer clones it. }
function CreateInstrumentCurve(const ARecipe: TInstrumentCurveRecipe;
  const ASampleRate: Integer): TAutomationCurve;

implementation

uses SysUtils, pythian.oscillator, pythian.time, pythian.envelope;

function DefaultInstrumentCurve: TInstrumentCurveRecipe;
begin
  Result := Default(TInstrumentCurveRecipe);
  Result.LfoHz := 1;
  Result.Scale := 1;
end;

function DefaultInstrumentZoneRecipe: TInstrumentZoneRecipe;
begin
  Result := Default(TInstrumentZoneRecipe);
  Result.MaximumKey := 96;
  Result.MinimumVelocity := 1;
  Result.MaximumVelocity := 127;
  Result.Voice := DefaultSynthVoice;
  Result.Source.TableSize := 2048;
  Result.Source.ModulatorRatio := 1;
  Result.Source.SampleEndFrame := -1;
  Result.Source.SampleRootHz := 440;
  Result.Source.SampleQuality := sqSinc;
  Result.Source.SampleMaximumStep := 8;
  Result.Source.TableMotion := DefaultInstrumentCurve;
  Result.Gate.Held := DefaultInstrumentCurve;
  Result.Gate.Release := DefaultInstrumentCurve;
end;

function CopyInstrumentRecipe(const ARecipe: TInstrumentRecipe): TInstrumentRecipe;
var I, J: Integer;
begin
  for I := 0 to High(ARecipe.Zones) do
    with ARecipe.Zones[I].Voice do
      if (SourceFactory <> nil) or (GateEnvelope <> nil) or
        (Automation.FrequencyHz <> nil) or (Automation.PitchCents <> nil) or
        (Automation.GainMultiplier <> nil) or (Automation.Pan <> nil) or
        (Automation.CutoffHz <> nil) then
        raise EAudio.Create('Instrument recipe cannot borrow runtime voice definitions');
  Result := ARecipe;
  Result.Zones := Copy(ARecipe.Zones);
  for I := 0 to High(Result.Zones) do
  begin
    Result.Zones[I].Source.Partials := Copy(ARecipe.Zones[I].Source.Partials);
    Result.Zones[I].Source.Tables := Copy(ARecipe.Zones[I].Source.Tables);
    for J := 0 to High(Result.Zones[I].Source.Tables) do
    begin
      Result.Zones[I].Source.Tables[J].Sine := Copy(ARecipe.Zones[I].Source.Tables[J].Sine);
      Result.Zones[I].Source.Tables[J].Cosine := Copy(ARecipe.Zones[I].Source.Tables[J].Cosine);
    end;
    Result.Zones[I].Source.TableMotion.Points := Copy(ARecipe.Zones[I].Source.TableMotion.Points);
    Result.Zones[I].Controls := Copy(ARecipe.Zones[I].Controls);
    for J := 0 to High(Result.Zones[I].Controls) do
      Result.Zones[I].Controls[J].Curve.Points := Copy(ARecipe.Zones[I].Controls[J].Curve.Points);
    Result.Zones[I].Gate.Held.Points := Copy(ARecipe.Zones[I].Gate.Held.Points);
    Result.Zones[I].Gate.Release.Points := Copy(ARecipe.Zones[I].Gate.Release.Points);
  end;
end;

function CreateInstrumentCurve(const ARecipe: TInstrumentCurveRecipe;
  const ASampleRate: Integer): TAutomationCurve;
var LPoints: TAutomationPoints; LPeriod, LPhase: Int64; I: Integer; LLfo: TAutomationCurve;
begin
  ValidateAudioFormat(ASampleRate, 1);
  case ARecipe.Kind of
    ickPoints:
      begin
        if (Length(ARecipe.Points) < 1) or (Length(ARecipe.Points) > MaximumAutomationPoints) then
          raise EAudio.Create('Instrument curve needs bounded explicit points');
        SetLength(LPoints, Length(ARecipe.Points));
        for I := 0 to High(LPoints) do
        begin
          LPoints[I].Frame := SampleFramesFromSeconds(ARecipe.Points[I].Seconds, ASampleRate, frFloor);
          LPoints[I].Value := ARecipe.Points[I].Value;
          LPoints[I].Transition := ARecipe.Points[I].Transition;
        end;
        Result := TAutomationCurve.Create(LPoints);
      end;
    ickLfo:
      begin
        RequireFinite(ARecipe.LfoHz, 'Instrument LFO frequency');
        RequireFinite(ARecipe.LfoPhaseCycles, 'Instrument LFO phase');
        if (ARecipe.LfoHz <= 0) or (ARecipe.LfoPhaseCycles < 0) or
          (ARecipe.LfoPhaseCycles >= 1) then
          raise EAudio.Create('Instrument LFO needs positive Hz and phase in [0,1)');
        LPeriod := SampleFramesFromSeconds(1 / ARecipe.LfoHz, ASampleRate, frFloor);
        LPhase := Trunc(LPeriod * ARecipe.LfoPhaseCycles);
        LLfo := TAutomationCurve.CreateLfo(LPeriod, ARecipe.LfoShape, LPhase);
        try Result := TAutomationCurve.CreateAffine(LLfo, ARecipe.Scale, ARecipe.Offset)
        finally LLfo.Free end;
      end;
  else raise EAudio.Create('Unsupported instrument curve kind');
  end;
end;

function BuildSource(const AZone: TInstrumentZoneRecipe; const ARate: Integer;
  const ASamples: TInstrumentSampleBindings): TAudioSourceFactory;
var LCurve: TAutomationCurve; LClip: TAudioClip; I, LEnd: Integer;
begin
  case AZone.Source.Kind of
    iskOscillator:
      Result := TWaveSourceFactory.Create(AZone.Voice.Shape, AZone.Voice.OscillatorQuality);
    iskAdditive: Result := TAdditiveSourceFactory.Create(AZone.Source.Partials);
    iskWavetable:
      begin
        if (Length(AZone.Source.Tables) < 1) or
          (Length(AZone.Source.Tables) > MaximumWavetableTrajectoryRecipes) then
          raise EAudio.Create('Instrument wavetable needs1..32 explicit cycle recipes');
        if Length(AZone.Source.Tables) = 1 then
          Result := TWavetableSourceFactory.Create(AZone.Source.Tables[0].Sine,
            AZone.Source.Tables[0].Cosine, AZone.Source.TableSize)
        else
        begin
          LCurve := CreateInstrumentCurve(AZone.Source.TableMotion, ARate);
          try Result := TWavetableSourceFactory.CreateTrajectory(AZone.Source.Tables,
            LCurve, AZone.Source.TableSize)
          finally LCurve.Free end;
        end;
      end;
    iskFm: Result := TFmSourceFactory.Create(fsmFrequency,
      AZone.Source.ModulatorRatio, AZone.Source.ModulationDepth);
    iskPm: Result := TFmSourceFactory.Create(fsmPhase,
      AZone.Source.ModulatorRatio, AZone.Source.ModulationDepth);
    iskSample:
      begin
        if AZone.Source.SampleId = '' then raise EAudio.Create('Sampler needs an explicit registered sample');
        LClip := nil;
        for I := 0 to High(ASamples) do
          if CompareScalarText(ASamples[I].Id, AZone.Source.SampleId, 256) = 0 then
          begin
            if LClip <> nil then raise EAudio.Create('Sampler binding is ambiguous');
            LClip := ASamples[I].Clip;
            if LClip = nil then raise EAudio.Create('Registered instrument sample is empty');
          end;
        if LClip = nil then raise EAudio.Create('Instrument sample is not registered');
        LEnd := AZone.Source.SampleEndFrame;
        if LEnd = -1 then LEnd := LClip.FrameCount;
        if AZone.Source.SampleHasLoop then
          Result := TSampleSourceFactory.CreateLoopRegion(LClip,
            AZone.Source.SampleStartFrame, LEnd, AZone.Source.SampleLoopStart,
            AZone.Source.SampleLoopEnd, AZone.Source.SampleRootHz,
            AZone.Source.SamplePlayback, AZone.Source.SampleQuality,
            AZone.Source.SampleMaximumStep)
        else Result := TSampleSourceFactory.Create(LClip,
          AZone.Source.SampleStartFrame, LEnd, AZone.Source.SampleRootHz,
          AZone.Source.SamplePlayback, AZone.Source.SampleQuality,
          AZone.Source.SampleMaximumStep);
      end;
  else raise EAudio.Create('Unsupported instrument source kind');
  end;
end;

constructor TRecipeInstrument.Create(const ARecipe: TInstrumentRecipe;
  const ASampleRate: Integer; const ASamples: TInstrumentSampleBindings);
var I, J: Integer; LReleaseFrames: Int64; LSeen: set of TInstrumentControlTarget;
  LCurve, LHeld, LRelease: TAutomationCurve; LTone: TFrameTone;
begin
  inherited Create;
  ValidateAudioFormat(ASampleRate, 2);
  ValidateScalarText(ARecipe.Id, 256, False);
  ValidateScalarText(ARecipe.Caption, 512, False);
  ValidateScalarText(ARecipe.Origin, 4096, False);
  if (ARecipe.Id = '') or (ARecipe.Caption = '') or (ARecipe.Origin = '') or
    (Length(ARecipe.Zones) < 1) or (Length(ARecipe.Zones) > MaximumInstrumentZones) then
    raise EAudio.Create('Instrument recipe needs identity, origin and bounded zones');
  FRecipe := CopyInstrumentRecipe(ARecipe);
  FSampleRate := ASampleRate;
  SetLength(FZones, Length(FRecipe.Zones));
  SetLength(FFactories, Length(FZones));
  for I := 0 to High(FZones) do
  begin
    FZones[I].MinimumKey := FRecipe.Zones[I].MinimumKey;
    FZones[I].MaximumKey := FRecipe.Zones[I].MaximumKey;
    FZones[I].MinimumVelocity := FRecipe.Zones[I].MinimumVelocity;
    FZones[I].MaximumVelocity := FRecipe.Zones[I].MaximumVelocity;
    FZones[I].Voice := FRecipe.Zones[I].Voice;
    FFactories[I] := BuildSource(FRecipe.Zones[I], ASampleRate, ASamples);
    FZones[I].Voice.SourceFactory := FFactories[I];
    LSeen := [];
    for J := 0 to High(FRecipe.Zones[I].Controls) do
    begin
      if not (FRecipe.Zones[I].Controls[J].Target in [Low(TInstrumentControlTarget)..High(TInstrumentControlTarget)]) or
        (FRecipe.Zones[I].Controls[J].Target in LSeen) then
        raise EAudio.Create('Instrument control target must be supported and unique per zone');
      Include(LSeen, FRecipe.Zones[I].Controls[J].Target);
      LCurve := CreateInstrumentCurve(FRecipe.Zones[I].Controls[J].Curve, ASampleRate);
      case FRecipe.Zones[I].Controls[J].Target of
        ictFrequencyHz: FZones[I].Voice.Automation.FrequencyHz := LCurve;
        ictPitchCents: FZones[I].Voice.Automation.PitchCents := LCurve;
        ictGainMultiplier: FZones[I].Voice.Automation.GainMultiplier := LCurve;
        ictPan: FZones[I].Voice.Automation.Pan := LCurve;
        ictCutoffHz: FZones[I].Voice.Automation.CutoffHz := LCurve;
      end;
    end;
    if FRecipe.Zones[I].Gate.Enabled then
    begin
      LReleaseFrames := SampleFramesFromSeconds(FRecipe.Zones[I].Gate.ReleaseSeconds, ASampleRate, frFloor);
      LHeld := CreateInstrumentCurve(FRecipe.Zones[I].Gate.Held, ASampleRate);
      LRelease := nil;
      try
        if (LReleaseFrames > 0) or (Length(FRecipe.Zones[I].Gate.Release.Points) > 0) or
          (FRecipe.Zones[I].Gate.Release.Kind = ickLfo) then
          LRelease := CreateInstrumentCurve(FRecipe.Zones[I].Gate.Release, ASampleRate);
        FZones[I].Voice.GateEnvelope := TGateEnvelope.Create(LHeld, LRelease,
          LReleaseFrames);
      finally LRelease.Free; LHeld.Free end;
    end;
  end;
  FInstrument := TInstrument.Create(FZones);
  LTone := Default(TFrameTone);
  LTone.GateFrames := 1;
  LTone.Velocity := 1;
  for I := 0 to High(FZones) do
  begin
    LTone.Voice := FZones[I].Voice;
    { Primary PlanNote owns admission for the actual played key. A zone may span
      the MIDI domain without promising that Nyquist permits every key at every
      output rate. Validate its definition here, not every hypothetical note. }
    LTone.FrequencyHz := MidiFrequency(FZones[I].MinimumKey);
    ValidateFrameTone(LTone, ASampleRate);
    SynthFrameCost(LTone.Voice, ASampleRate);
  end;
end;

destructor TRecipeInstrument.Destroy;
var I: Integer;
begin
  FInstrument.Free;
  for I := 0 to High(FZones) do
  begin
    FZones[I].Voice.GateEnvelope.Free;
    FZones[I].Voice.Automation.FrequencyHz.Free;
    FZones[I].Voice.Automation.PitchCents.Free;
    FZones[I].Voice.Automation.GainMultiplier.Free;
    FZones[I].Voice.Automation.Pan.Free;
    FZones[I].Voice.Automation.CutoffHz.Free;
  end;
  for I := 0 to High(FFactories) do FFactories[I].Free;
  inherited Destroy;
end;

function TRecipeInstrument.CopyRecipe: TInstrumentRecipe;
begin
  Result := CopyInstrumentRecipe(FRecipe);
end;

end.
