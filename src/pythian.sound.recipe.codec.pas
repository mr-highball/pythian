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
unit pythian.sound.recipe.codec;

{$mode delphi}{$H+}

interface

uses pythian.audio, pythian.instrument.recipe, pythian.mix.recipe,
  pythian.progress;

const MaximumSoundRecipeBytes = 4 * 1024 * 1024;

{ Big Boss: detached primary recipes, never runtime pointers or source PCM.
  Fixed little-endian numbers and canonical scalar UTF-8 on native and pas2js.
  Decode validates structure; primary realization validates playable settings
  against the selected rate/sample bindings. These bytes are not a signature.
  Cancellation publishes no result and does not mutate caller definitions. }
function EncodeInstrumentRecipe(const ARecipe: TInstrumentRecipe;
  const AProgress: TWorkProgressCallback = nil): TAudioBytes;
function DecodeInstrumentRecipe(const ABytes: TAudioBytes;
  const AProgress: TWorkProgressCallback = nil): TInstrumentRecipe;
function EncodeStemMixRecipe(const ARecipe: TStemMixRecipe;
  const ASampleRate: Integer;
  const AProgress: TWorkProgressCallback = nil): TAudioBytes;
function DecodeStemMixRecipe(const ABytes: TAudioBytes;
  const ASampleRate: Integer;
  const AProgress: TWorkProgressCallback = nil): TStemMixRecipe;

implementation

uses SysUtils, pythian.binary, pythian.text, pythian.stream.bytes,
  pythian.automation, pythian.additive, pythian.source.wavetable,
  pythian.source.sample, pythian.oscillator, pythian.synth,
  pythian.filter, pythian.biquad, pythian.effects.catalog, pythian.effects.rack;

type
  TRecipeIO = class
  private
    FStream: TAudioBytesStream;
    FWord: TAudioBytes;
    FReading: Boolean;
    FFields: Integer;
    FProgress: TWorkProgressCallback;
    procedure Transfer(const ASize: Integer);
  public
    constructor Create(const ABytes: TAudioBytes; const AReading: Boolean;
      const AProgress: TWorkProgressCallback);
    destructor Destroy; override;
    function N(const AValue: Integer): Integer;
    function Count(const AValue, AMaximum: Integer): Integer;
    function R(const AValue: Double): Double;
    function B(const AValue: Boolean): Boolean;
    function Text(const AValue: TScalarText; const AMaximum: Integer): TScalarText;
    function Finish: TAudioBytes;
  end;

constructor TRecipeIO.Create(const ABytes: TAudioBytes; const AReading: Boolean;
  const AProgress: TWorkProgressCallback);
var LOffset: Integer;
  LBlock: Integer;
begin
  inherited Create;
  FReading := AReading;
  FProgress := AProgress;
  FStream := TAudioBytesStream.Create(MaximumSoundRecipeBytes);
  SetLength(FWord, 8);
  if Length(ABytes) > MaximumSoundRecipeBytes then
  begin
    raise EAudio.Create('Sound recipe exceeds its byte budget');
  end;
  LOffset := 0;
  while AReading and (LOffset < Length(ABytes)) do
  begin
    LBlock := Length(ABytes) - LOffset;
    if LBlock > 65536 then LBlock := 65536;
    WriteStreamBytesExact(FStream, ABytes, LOffset, LBlock);
    Inc(LOffset, LBlock);
    ReportWork(FProgress, 'sound_recipe_input', wuBytes, LOffset, Length(ABytes));
  end;
  FStream.Position := 0;
end;

destructor TRecipeIO.Destroy;
begin
  FStream.Free;
  inherited Destroy;
end;

procedure TRecipeIO.Transfer(const ASize: Integer);
begin
  Inc(FFields);
  if FFields mod 256 = 0 then
  begin
    ReportWork(FProgress, 'sound_recipe_fields', wuItems, FFields, 0);
  end;
  if FReading then
  begin
    ReadStreamBytesExact(FStream, FWord, 0, ASize);
  end
  else
  begin
    WriteStreamBytesExact(FStream, FWord, 0, ASize);
  end;
end;

function TRecipeIO.N(const AValue: Integer): Integer;
begin
  if not FReading then WriteInt32LE(FWord, 0, AValue);
  Transfer(4);
  Result := ReadInt32LE(FWord, 0);
end;

function TRecipeIO.Count(const AValue, AMaximum: Integer): Integer;
begin
  Result := N(AValue);
  if (Result < 0) or (Result > AMaximum) then
  begin
    raise EAudio.Create('Sound recipe count or enum exceeds its contract');
  end;
end;

function TRecipeIO.R(const AValue: Double): Double;
begin
  if not FReading then WriteFloat64LE(FWord, 0, AValue);
  Transfer(8);
  Result := ReadFloat64LE(FWord, 0);
  RequireFinite(Result, 'Sound recipe number');
end;

function TRecipeIO.B(const AValue: Boolean): Boolean;
begin
  Result := Count(Ord(AValue), 1) <> 0;
end;

function TRecipeIO.Text(const AValue: TScalarText; const AMaximum: Integer): TScalarText;
var LBytes: TAudioBytes;
  LCount: Integer;
begin
  LBytes := nil;
  if not FReading then LBytes := EncodeUTF8Text(AValue, AMaximum, True, True);
  LCount := Count(Length(LBytes), AMaximum);
  if FReading then
  begin
    if LCount > FStream.Size - FStream.Position then
    begin
      raise EAudio.Create('Truncated sound recipe text');
    end;
    SetLength(LBytes, LCount);
    ReadStreamBytesExact(FStream, LBytes, 0, LCount);
  end
  else
  begin
    WriteStreamBytesExact(FStream, LBytes, 0, LCount);
  end;
  Result := DecodeUTF8Text(LBytes, AMaximum, True, True);
end;

function TRecipeIO.Finish: TAudioBytes;
begin
  Result := nil;
  if FReading and (FStream.Position <> FStream.Size) then
  begin
    raise EAudio.Create('Trailing sound recipe payload');
  end;
  if not FReading then Result := FStream.Snapshot;
  ReportWork(FProgress, 'sound_recipe_ready', wuItems, 1, 1);
end;

procedure CurveIO(const AIO: TRecipeIO; var ACurve: TInstrumentCurveRecipe);
var I: Integer;
begin
  ACurve.Kind := TInstrumentCurveKind(AIO.Count(Ord(ACurve.Kind), Ord(High(TInstrumentCurveKind))));
  SetLength(ACurve.Points, AIO.Count(Length(ACurve.Points), MaximumAutomationPoints));
  for I := 0 to High(ACurve.Points) do
  begin
    ACurve.Points[I].Seconds := AIO.R(ACurve.Points[I].Seconds);
    ACurve.Points[I].Value := AIO.R(ACurve.Points[I].Value);
    ACurve.Points[I].Transition := TAutomationTransition(AIO.Count(
      Ord(ACurve.Points[I].Transition), Ord(High(TAutomationTransition))));
  end;
  ACurve.LfoHz := AIO.R(ACurve.LfoHz);
  ACurve.LfoPhaseCycles := AIO.R(ACurve.LfoPhaseCycles);
  ACurve.LfoShape := TAutomationLfoShape(AIO.Count(Ord(ACurve.LfoShape), Ord(High(TAutomationLfoShape))));
  ACurve.Scale := AIO.R(ACurve.Scale);
  ACurve.Offset := AIO.R(ACurve.Offset);
end;

procedure SourceIO(const AIO: TRecipeIO; var ASource: TInstrumentSourceRecipe);
var I: Integer;
  J: Integer;
begin
  ASource.Kind := TInstrumentSourceKind(AIO.Count(Ord(ASource.Kind), Ord(High(TInstrumentSourceKind))));
  SetLength(ASource.Partials, AIO.Count(Length(ASource.Partials), MaximumAdditivePartials));
  for I := 0 to High(ASource.Partials) do
  begin
    ASource.Partials[I].Ratio := AIO.R(ASource.Partials[I].Ratio);
    ASource.Partials[I].Gain := AIO.R(ASource.Partials[I].Gain);
    ASource.Partials[I].PhaseCycles := AIO.R(ASource.Partials[I].PhaseCycles);
  end;
  SetLength(ASource.Tables, AIO.Count(Length(ASource.Tables), MaximumWavetableTrajectoryRecipes));
  for I := 0 to High(ASource.Tables) do
  begin
    SetLength(ASource.Tables[I].Sine, AIO.Count(Length(ASource.Tables[I].Sine), MaximumTableHarmonics));
    for J := 0 to High(ASource.Tables[I].Sine) do
    begin
      ASource.Tables[I].Sine[J] := AIO.R(ASource.Tables[I].Sine[J]);
    end;
    SetLength(ASource.Tables[I].Cosine, AIO.Count(Length(ASource.Tables[I].Cosine), MaximumTableHarmonics));
    for J := 0 to High(ASource.Tables[I].Cosine) do
    begin
      ASource.Tables[I].Cosine[J] := AIO.R(ASource.Tables[I].Cosine[J]);
    end;
    ASource.Tables[I].Mean := AIO.R(ASource.Tables[I].Mean);
  end;
  ASource.TableSize := AIO.Count(ASource.TableSize, MaximumTableSize);
  CurveIO(AIO, ASource.TableMotion);
  ASource.ModulatorRatio := AIO.R(ASource.ModulatorRatio);
  ASource.ModulationDepth := AIO.R(ASource.ModulationDepth);
  ASource.SampleId := AIO.Text(ASource.SampleId, 1024);
  ASource.SampleStartFrame := AIO.N(ASource.SampleStartFrame);
  ASource.SampleEndFrame := AIO.N(ASource.SampleEndFrame);
  ASource.SampleLoopStart := AIO.N(ASource.SampleLoopStart);
  ASource.SampleLoopEnd := AIO.N(ASource.SampleLoopEnd);
  ASource.SampleHasLoop := AIO.B(ASource.SampleHasLoop);
  ASource.SampleRootHz := AIO.R(ASource.SampleRootHz);
  ASource.SamplePlayback := TSamplePlayback(AIO.Count(Ord(ASource.SamplePlayback), Ord(High(TSamplePlayback))));
  ASource.SampleQuality := TSampleQuality(AIO.Count(Ord(ASource.SampleQuality), Ord(High(TSampleQuality))));
  ASource.SampleMaximumStep := AIO.R(ASource.SampleMaximumStep);
end;

procedure InstrumentIO(const AIO: TRecipeIO; var ARecipe: TInstrumentRecipe);
var I: Integer;
  J: Integer;
begin
  if AIO.N($31524950) <> $31524950 then
  begin
    raise EAudio.Create('Unsupported instrument recipe format');
  end;
  ARecipe.Id := AIO.Text(ARecipe.Id, 1024);
  ARecipe.Caption := AIO.Text(ARecipe.Caption, 4096);
  ARecipe.Origin := AIO.Text(ARecipe.Origin, 65536);
  SetLength(ARecipe.Zones, AIO.Count(Length(ARecipe.Zones), 256));
  for I := 0 to High(ARecipe.Zones) do
  begin
    with ARecipe.Zones[I] do
    begin
      MinimumKey := AIO.N(MinimumKey);
      MaximumKey := AIO.N(MaximumKey);
      MinimumVelocity := AIO.N(MinimumVelocity);
      MaximumVelocity := AIO.N(MaximumVelocity);
      Voice.Shape := TWaveShape(AIO.Count(Ord(Voice.Shape), Ord(High(TWaveShape))));
      Voice.OscillatorQuality := TOscillatorQuality(AIO.Count(
        Ord(Voice.OscillatorQuality), Ord(High(TOscillatorQuality))));
      Voice.Envelope.AttackSeconds := AIO.R(Voice.Envelope.AttackSeconds);
      Voice.Envelope.DecaySeconds := AIO.R(Voice.Envelope.DecaySeconds);
      Voice.Envelope.SustainLevel := AIO.R(Voice.Envelope.SustainLevel);
      Voice.Envelope.ReleaseSeconds := AIO.R(Voice.Envelope.ReleaseSeconds);
      Voice.CutoffHz := AIO.R(Voice.CutoffHz);
      Voice.FilterKind := TFilterKind(AIO.Count(Ord(Voice.FilterKind), Ord(High(TFilterKind))));
      Voice.FilterModel := TVoiceFilterModel(AIO.Count(Ord(Voice.FilterModel), Ord(High(TVoiceFilterModel))));
      Voice.BiquadKind := TBiquadKind(AIO.Count(Ord(Voice.BiquadKind), Ord(High(TBiquadKind))));
      Voice.BiquadQ := AIO.R(Voice.BiquadQ);
      Voice.BiquadGainDb := AIO.R(Voice.BiquadGainDb);
      Voice.Pan := AIO.R(Voice.Pan);
      Voice.Gain := AIO.R(Voice.Gain);
      SourceIO(AIO, Source);
      SetLength(Controls, AIO.Count(Length(Controls), 64));
      for J := 0 to High(Controls) do
      begin
        Controls[J].Target := TInstrumentControlTarget(AIO.Count(
          Ord(Controls[J].Target), Ord(High(TInstrumentControlTarget))));
        CurveIO(AIO, Controls[J].Curve);
      end;
      Gate.Enabled := AIO.B(Gate.Enabled);
      CurveIO(AIO, Gate.Held);
      CurveIO(AIO, Gate.Release);
      Gate.ReleaseSeconds := AIO.R(Gate.ReleaseSeconds);
    end;
  end;
end;

procedure EffectsIO(const AIO: TRecipeIO; var AEffects: TEffectRecipes);
var I: Integer;
  J: Integer;
begin
  SetLength(AEffects, AIO.Count(Length(AEffects), 256));
  for I := 0 to High(AEffects) do
  begin
    AEffects[I].Bypass := AIO.B(AEffects[I].Bypass);
    AEffects[I].Settings.Kind := TCatalogEffect(AIO.Count(
      Ord(AEffects[I].Settings.Kind), Ord(High(TCatalogEffect))));
    SetLength(AEffects[I].Settings.Values, AIO.Count(Length(AEffects[I].Settings.Values), 64));
    for J := 0 to High(AEffects[I].Settings.Values) do
    begin
      AEffects[I].Settings.Values[J] := AIO.R(AEffects[I].Settings.Values[J]);
    end;
  end;
end;

procedure MixIO(const AIO: TRecipeIO; var ARecipe: TStemMixRecipe);
var I: Integer;
begin
  if AIO.N($31524D50) <> $31524D50 then
  begin
    raise EAudio.Create('Unsupported stem mix recipe format');
  end;
  SetLength(ARecipe.Parts, AIO.Count(Length(ARecipe.Parts), 15));
  for I := 0 to High(ARecipe.Parts) do
  begin
    ARecipe.Parts[I].Gain := AIO.R(ARecipe.Parts[I].Gain);
    ARecipe.Parts[I].Pan := AIO.R(ARecipe.Parts[I].Pan);
    ARecipe.Parts[I].BypassEffects := AIO.B(ARecipe.Parts[I].BypassEffects);
    EffectsIO(AIO, ARecipe.Parts[I].Effects);
  end;
  ARecipe.StemGain := AIO.R(ARecipe.StemGain);
  ARecipe.MasterGain := AIO.R(ARecipe.MasterGain);
  EffectsIO(AIO, ARecipe.MasterEffects);
  ARecipe.BypassEffects := AIO.B(ARecipe.BypassEffects);
  ARecipe.LimitOutputs := AIO.B(ARecipe.LimitOutputs);
  ARecipe.CeilingDb := AIO.R(ARecipe.CeilingDb);
  ARecipe.LimiterReleaseSeconds := AIO.R(ARecipe.LimiterReleaseSeconds);
  ARecipe.TailSeconds := AIO.R(ARecipe.TailSeconds);
end;

function EncodeInstrumentRecipe(const ARecipe: TInstrumentRecipe;
  const AProgress: TWorkProgressCallback): TAudioBytes;
var LIO: TRecipeIO;
  LRecipe: TInstrumentRecipe;
begin
  LRecipe := CopyInstrumentRecipe(ARecipe);
  LIO := TRecipeIO.Create(nil, False, AProgress);
  try
    InstrumentIO(LIO, LRecipe);
    Result := LIO.Finish;
  finally
    LIO.Free;
  end;
end;

function DecodeInstrumentRecipe(const ABytes: TAudioBytes;
  const AProgress: TWorkProgressCallback): TInstrumentRecipe;
var LIO: TRecipeIO;
  LRecipe: TInstrumentRecipe;
begin
  LRecipe := Default(TInstrumentRecipe);
  LIO := TRecipeIO.Create(ABytes, True, AProgress);
  try
    InstrumentIO(LIO, LRecipe);
    LIO.Finish;
    Result := LRecipe;
  finally
    LIO.Free;
  end;
end;

function EncodeStemMixRecipe(const ARecipe: TStemMixRecipe;
  const ASampleRate: Integer; const AProgress: TWorkProgressCallback): TAudioBytes;
var LIO: TRecipeIO;
  LRecipe: TStemMixRecipe;
begin
  ValidateStemMixRecipe(ARecipe, ASampleRate);
  LRecipe := CopyStemMixRecipe(ARecipe);
  LIO := TRecipeIO.Create(nil, False, AProgress);
  try
    MixIO(LIO, LRecipe);
    Result := LIO.Finish;
  finally
    LIO.Free;
  end;
end;

function DecodeStemMixRecipe(const ABytes: TAudioBytes;
  const ASampleRate: Integer; const AProgress: TWorkProgressCallback): TStemMixRecipe;
var LIO: TRecipeIO;
  LRecipe: TStemMixRecipe;
begin
  LRecipe := Default(TStemMixRecipe);
  LIO := TRecipeIO.Create(ABytes, True, AProgress);
  try
    MixIO(LIO, LRecipe);
    ValidateStemMixRecipe(LRecipe, ASampleRate);
    LIO.Finish;
    Result := LRecipe;
  finally
    LIO.Free;
  end;
end;

end.
