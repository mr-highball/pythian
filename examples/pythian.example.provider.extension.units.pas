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
unit pythian.example.provider.extension.units;

{$mode delphi}
{$H+}

interface

uses
  pythian.audio, pythian.wfc.provider.codecs, pythian.wfc.providers,
  pythian.wfc.layers, pythian.wfc.semantic.style;

type
  TCallerHarmonicCodec = class(TProviderCodec)
  public
    function CanonicalConfiguration(const AConfiguration: TAudioBytes): TAudioBytes; override;
    function Decode(const AConfiguration: TAudioBytes;
      const AToken: String): TProviderCodecChoice; override;
    function Encode(const AConfiguration: TAudioBytes;
      const AChoice: TProviderCodecChoice): String; override;
  end;

function MakeHarmonicCodecBinding(const ADenominator: Integer): TProviderCodecBinding;
function HarmonicCodecDeclaration: TProviderCodecDeclaration;
procedure RegisterHarmonicCodec(const ARegistry: TProviderCodecRegistry;
  const ACodec: TCallerHarmonicCodec);
function HarmonicToken(const ANumerator, ADenominator: Integer): String;
function HarmonicChoiceMix(const ABinding: TProviderCodecBinding;
  const AChoice: TProviderCodecChoice): Double;
function CreateHarmonicSourceStyle(const AVariant: Integer;
  const ARegistry: TProviderCodecRegistry; out AReferenceWav: TAudioBytes): TSemanticStyle;
function RenderHarmonicSequences(const ASequences: TLayerSequences;
  const ABinding: TProviderCodecBinding; const AChoices: TStyleProviderChoices): TAudioClip;

implementation

uses
  SysUtils, pythian.hash, pythian.wave, pythian.time, pythian.synth, pythian.oscillator,
  pythian.wfc.pitch, pythian.wfc.style, pythian.wfc.provider.contracts,
  pythian.example.extension.units, wfc_sequence, wfc_sequence_learn, wfc_sequence_text, wfc_sequence_graph;

const
  CIdentity = 'org.pythian.example/harmonic-balance';
  CUnits = 'second-harmonic-numerator';
  CUnknown = 'no-unknown-token';
  CClock = 'explicit-ppq-grid';
  CCells = 8;
  CRate = 16000;
  CFramesPerCell = 2000;
  CFrames = CCells * CFramesPerCell;
  CDenominator = 100;

function AsBytes(const AText: String): TAudioBytes;
var
  LIndex: Integer;
begin
  Result := nil;
  SetLength(Result, Length(AText));
  for LIndex := 1 to Length(AText) do
  begin
    Result[LIndex - 1] := Ord(AText[LIndex]);
  end;
end;

function AsText(const ABytes: TAudioBytes): String;
var
  LIndex: Integer;
begin
  if Length(ABytes) > 32 then
  begin
    raise EAudio.Create('Harmonic codec bytes exceed its canonical bound');
  end;
  SetLength(Result, Length(ABytes));
  for LIndex := 0 to High(ABytes) do
  begin
    Result[LIndex + 1] := Char(ABytes[LIndex]);
  end;
end;

function CanonicalNumber(const AText: String; const AMaximum: Integer): Integer;
var
  LIndex: Integer;
begin
  if (Length(AText) < 1) or (Length(AText) > 4) then
  begin
    raise EAudio.Create('Harmonic codec requires bounded canonical decimal');
  end;
  if (Length(AText) > 1) and (AText[1] = '0') then
  begin
    raise EAudio.Create('Harmonic codec rejects leading zeroes');
  end;
  Result := 0;
  for LIndex := 1 to Length(AText) do
  begin
    if not (AText[LIndex] in ['0'..'9']) then
    begin
      raise EAudio.Create('Harmonic codec requires unsigned canonical decimal');
    end;
    Result := Result * 10 + Ord(AText[LIndex]) - Ord('0');
  end;
  if Result > AMaximum then
  begin
    raise EAudio.Create('Harmonic value exceeds its declared denominator');
  end;
end;

function Denominator(const AConfiguration: TAudioBytes): Integer;
var
  LText: String;
begin
  LText := AsText(AConfiguration);
  if Copy(LText, 1, 12) <> 'denominator=' then
  begin
    raise EAudio.Create('Harmonic configuration requires denominator=N');
  end;
  Result := CanonicalNumber(Copy(LText, 13, MaxInt), 1000);
  if Result < 1 then
  begin
    raise EAudio.Create('Harmonic denominator must be 1..1000');
  end;
end;

function MakeHarmonicCodecBinding(const ADenominator: Integer): TProviderCodecBinding;
begin
  if (ADenominator < 1) or (ADenominator > 1000) then
  begin
    raise EAudio.Create('Harmonic denominator must be 1..1000');
  end;
  Result := Default(TProviderCodecBinding);
  Result.Identity := CIdentity;
  Result.Version := 1;
  Result.Configuration := AsBytes('denominator=' + IntToStr(ADenominator));
  Result.Units := CUnits;
  Result.UnknownMeaning := CUnknown;
  Result.ClockMeaning := CClock;
end;

function HarmonicCodecDeclaration: TProviderCodecDeclaration;
begin
  Result := Default(TProviderCodecDeclaration);
  Result.Identity := CIdentity;
  Result.Version := 1;
  Result.Units := CUnits;
  Result.UnknownMeaning := CUnknown;
  Result.ClockMeaning := CClock;
  { Bounded caller policy weights, not measured CPU execution guarantees. }
  Result.ConfigurationWork := 32;
  Result.DecodeWork := 48;
  Result.EncodeWork := 48;
  Result.MaximumPayloadBytes := 4;
  Result.MaximumTokenBytes := 8;
end;

procedure RegisterHarmonicCodec(const ARegistry: TProviderCodecRegistry;
  const ACodec: TCallerHarmonicCodec);
begin
  if (ARegistry = nil) or (ACodec = nil) then
  begin
    raise EAudio.Create('Harmonic registration needs caller-owned registry and codec');
  end;
  ARegistry.RegisterCodec(HarmonicCodecDeclaration, ACodec);
end;

function HarmonicToken(const ANumerator, ADenominator: Integer): String;
begin
  if (ADenominator < 1) or (ADenominator > 1000) or
    (ANumerator < 0) or (ANumerator > ADenominator) then
  begin
    raise EAudio.Create('Harmonic numerator/denominator is outside declared bounds');
  end;
  Result := 'mix:' + IntToStr(ANumerator);
end;

function TCallerHarmonicCodec.CanonicalConfiguration(
  const AConfiguration: TAudioBytes): TAudioBytes;
begin
  Result := AsBytes('denominator=' + IntToStr(Denominator(AConfiguration)));
end;

function TCallerHarmonicCodec.Decode(const AConfiguration: TAudioBytes;
  const AToken: String): TProviderCodecChoice;
var
  LDenominator: Integer;
  LNumerator: Integer;
begin
  LDenominator := Denominator(AConfiguration);
  if (Length(AToken) > 8) or (Copy(AToken, 1, 4) <> 'mix:') then
  begin
    raise EAudio.Create('Harmonic token requires mix:N');
  end;
  LNumerator := CanonicalNumber(Copy(AToken, 5, MaxInt), LDenominator);
  Result := Default(TProviderCodecChoice);
  Result.Bytes := AsBytes(IntToStr(LNumerator));
  Result.IsUnknown := False;
end;

function TCallerHarmonicCodec.Encode(const AConfiguration: TAudioBytes;
  const AChoice: TProviderCodecChoice): String;
var
  LDenominator: Integer;
  LNumerator: Integer;
begin
  LDenominator := Denominator(AConfiguration);
  if AChoice.IsUnknown then
  begin
    raise EAudio.Create('Harmonic codec has no unknown token');
  end;
  LNumerator := CanonicalNumber(AsText(AChoice.Bytes), LDenominator);
  Result := HarmonicToken(LNumerator, LDenominator);
end;

function HarmonicChoiceMix(const ABinding: TProviderCodecBinding;
  const AChoice: TProviderCodecChoice): Double;
var
  LDenominator: Integer;
begin
  if (ABinding.Identity <> CIdentity) or (ABinding.Version <> 1) or
    (ABinding.Units <> CUnits) or (ABinding.UnknownMeaning <> CUnknown) or
    (ABinding.ClockMeaning <> CClock) or AChoice.IsUnknown then
  begin
    raise EAudio.Create('Unsupported harmonic meaning or unknown choice');
  end;
  LDenominator := Denominator(ABinding.Configuration);
  Result := CanonicalNumber(AsText(AChoice.Bytes), LDenominator) / LDenominator;
end;

function FindChoice(const AChoices: TStyleProviderChoices;
  const AToken: String): TProviderCodecChoice;
var
  LChoice: TStyleProviderChoice;
begin
  for LChoice in AChoices do
  begin
    if LChoice.Token = AToken then
    begin
      Exit(CopyProviderCodecChoice(LChoice.CallerValue));
    end;
  end;
  raise EAudio.Create('Generated harmonic token missing from admitted snapshot');
end;

function RenderHarmonicSequences(const ASequences: TLayerSequences;
  const ABinding: TProviderCodecBinding; const AChoices: TStyleProviderChoices): TAudioClip;
var
  LTones: TFrameTones;
  LFactories: array of TCallerHarmonicFactory;
  LPitch: TStyleProviderChoice;
  LIntensity: TStyleProviderChoice;
  LIndex: Integer;
begin
  if Length(ASequences) <> 3 then
  begin
    raise EAudio.Create('Harmonic renderer needs pitch, balance and intensity sequences');
  end;
  for LIndex := 0 to 2 do
  begin
    if Length(ASequences[LIndex].Tokens) <> CCells then
    begin
      raise EAudio.Create('Harmonic sequence requires exactly eight cells');
    end;
  end;
  SetLength(LTones, CCells);
  SetLength(LFactories, CCells);
  try
    for LIndex := 0 to CCells - 1 do
    begin
      LPitch := DecodeStyleProviderChoice(spvPitch, ASequences[0].Tokens[LIndex]);
      LIntensity := DecodeStyleProviderChoice(spvIntensity, ASequences[2].Tokens[LIndex]);
      LFactories[LIndex] := TCallerHarmonicFactory.Create(HarmonicChoiceMix(ABinding,
        FindChoice(AChoices, ASequences[1].Tokens[LIndex])));
      LTones[LIndex].StartFrame := Int64(LIndex) * CFramesPerCell;
      LTones[LIndex].GateFrames := 1600;
      LTones[LIndex].FrequencyHz := MidiFrequency(LPitch.Note);
      LTones[LIndex].Velocity := 0.6;
      LTones[LIndex].Seed := Cardinal(731 + LIndex);
      LTones[LIndex].Voice := DefaultSynthVoice;
      LTones[LIndex].Voice.SourceFactory := LFactories[LIndex];
      LTones[LIndex].Voice.Gain := LIntensity.Intensity / 4;
      LTones[LIndex].Voice.Envelope.ReleaseSeconds := 0.02;
    end;
    Result := RenderFrameTones(LTones, CRate, CFrames);
    if (Result.FrameCount <> CFrames) or (Result.SampleRate <> CRate) or
      (Result.Channels <> 2) then
    begin
      Result.Free;
      Result := nil;
      raise EAudio.Create('Harmonic release exceeds its declared cell extent');
    end;
  finally
    for LIndex := 0 to High(LFactories) do
    begin
      LFactories[LIndex].Free;
    end;
  end;
end;

function CreateHarmonicSourceStyle(const AVariant: Integer;
  const ARegistry: TProviderCodecRegistry; out AReferenceWav: TAudioBytes): TSemanticStyle;
const
  CNotes: array[0..2] of Integer = (60, 64, 67);
  CMixes: array[0..2] of Integer = (0, 35, 100);
  CPatterns: array[0..1, 0..7] of Integer =
    ((0, 1, 2, 0, 2, 1, 0, 2), (0, 1, 2, 2, 0, 2, 1, 1));
var
  LDefinition: TSemanticStyleDefinition;
  LSequences: TLayerSequences;
  LCodec: TCallerHarmonicCodec;
  LChoices: TStyleProviderChoices;
  LBinding: TProviderCodecBinding;
  LClip: TAudioClip;
  LDescription: TStyleProviderDescription;
  LSource: TSemanticSource;
  LSourceEvidence: TProviderSourceEvidence;
  LSamples: TWfcSequenceSamples;
  LModel: TWfcSequenceModel;
  LProvider: Integer;
  LCell: Integer;
  LType: Integer;
begin
  if (AVariant < 0) or (AVariant > 1) then
  begin
    raise EAudio.Create('Authored harmonic variant must be zero or one');
  end;
  LBinding := MakeHarmonicCodecBinding(CDenominator);
  SetLength(LChoices, 3);
  LCodec := TCallerHarmonicCodec.Create;
  try
    for LCell := 0 to 2 do
    begin
      LChoices[LCell].Token := HarmonicToken(CMixes[LCell], CDenominator);
      LChoices[LCell].CallerValue := LCodec.Decode(LBinding.Configuration, LChoices[LCell].Token);
    end;
  finally
    LCodec.Free;
  end;
  SetLength(LSequences, 3);
  for LProvider := 0 to 2 do
  begin
    SetLength(LSequences[LProvider].Tokens, CCells);
  end;
  for LCell := 0 to CCells - 1 do
  begin
    LType := CPatterns[AVariant, LCell];
    LSequences[0].Tokens[LCell] := String(PitchNoteToken(CNotes[LType]));
    LSequences[1].Tokens[LCell] := HarmonicToken(CMixes[LType], CDenominator);
    LSequences[2].Tokens[LCell] := String(StyleIntensityToken(3));
  end;
  LClip := RenderHarmonicSequences(LSequences, LBinding, LChoices);
  try
    AReferenceWav := EncodeWavePcm16(LClip);
  finally
    LClip.Free;
  end;
  LDefinition := Default(TSemanticStyleDefinition);
  LSource := Default(TSemanticSource);
  LSource.Sha256 := Sha256Bytes(AReferenceWav);
  LSource.GroupId := 'authored-harmonic-control-' + IntToStr(AVariant);
  LSource.Split := ssTraining;
  LSource.Exposure := [seTraining, seVocabulary];
  LSource.SampleRate := CRate;
  LSource.FrameCount := CFrames;
  LSource.ExternalRequirement := 'First-party authored control WAV; not measured acoustic truth';
  LSource.OriginSha256 := LSource.Sha256;
  LSource.OriginSampleRate := CRate;
  LSource.OriginFrameCount := CFrames;
  LSource.OriginEndFrame := CFrames;
  LSource.PreparationEvidence := AsBytes('identity: authored two-harmonic PCM16 control');
  LSource.PreparationSha256 := SemanticPreparationIdentity(LSource);
  SetLength(LDefinition.Sources, 1);
  LDefinition.Sources[0] := LSource;
  SetLength(LDefinition.Runs, 1);
  LDefinition.Runs[0].Identity := 'authored-run-' + IntToStr(AVariant);
  LDefinition.Runs[0].EndFrame := CFrames;
  LDefinition.Runs[0].TicksPerQuarter := 480;
  LDefinition.Runs[0].TempoChanges := [MakeTempoChange(0, 500000)];
  SetLength(LDefinition.Runs[0].Tokens, 3);
  SetLength(LDefinition.Runs[0].Weights, 3);
  SetLength(LDefinition.Runs[0].TimeGrids, 3);
  SetLength(LDefinition.Runs[0].ProviderEvidence, 3);
  SetLength(LDefinition.Providers, 3);
  for LProvider := 0 to 2 do
  begin
    LDescription := Default(TStyleProviderDescription);
    case LProvider of
      0:
      begin
        LDescription.Name := 'pitch';
        LDescription.Vocabulary := spvPitch;
      end;
      1:
      begin
        LDescription.Name := 'balance';
        LDescription.Vocabulary := spvCaller;
        LDescription.CodecBinding := CopyProviderCodecBinding(LBinding);
      end;
      2:
      begin
        LDescription.Name := 'intensity';
        LDescription.Vocabulary := spvIntensity;
      end;
    end;
    LDescription.TicksPerQuarter := 480;
    LDescription.Timing := sptUniform;
    LDescription.StepTicks := 120;
    LDescription.Scope := MakeLayerScope(CCells, wseWhole);
    LDefinition.Providers[LProvider].Contract := ProviderContractFromDescription(
      LDescription, 'first-party-authored-harmonic-control');
    LSourceEvidence := Default(TProviderSourceEvidence);
    LSourceEvidence.SourceSha256 := LSource.Sha256;
    LSourceEvidence.MeasurementIdentity := 'authored-control-declaration-v1';
    LSourceEvidence.ConversionIdentity := 'exact-480ppq-120bpm-16000hz';
    LSourceEvidence.SampleRate := CRate;
    LSourceEvidence.SourceFrames := CFrames;
    LSourceEvidence.SourceTicksPerQuarter := 480;
    LSourceEvidence.SourceLengthTicks := 960;
    LSourceEvidence.TempoChanges := [MakeTempoChange(0, 500000)];
    SetLength(LSourceEvidence.OriginalTicks, CCells + 1);
    SetLength(LSourceEvidence.OriginalFrames, CCells + 1);
    for LCell := 0 to CCells do
    begin
      LSourceEvidence.OriginalTicks[LCell] := LCell * 120;
      LSourceEvidence.OriginalFrames[LCell] := LCell * CFramesPerCell;
    end;
    LDefinition.Providers[LProvider].Contract.Source := LSourceEvidence;
    LDefinition.Providers[LProvider].ExtractionPolicy :=
      'Authored control parameters and exact clock; no acoustic extraction/inference';
    LDefinition.Runs[0].Tokens[LProvider] := Copy(LSequences[LProvider].Tokens);
    LDefinition.Runs[0].Weights[LProvider] := 1;
    LDefinition.Runs[0].TimeGrids[LProvider] := MakeLayerTimeGrid(0, 120);
    LDefinition.Runs[0].ProviderEvidence[LProvider] := 'authored exact parameter/clock ledger';
    LSamples := nil;
    SetLength(LSamples, 1);
    LSamples[0] := MakeWfcSequenceSample(LDefinition.Runs[0].Tokens[LProvider]);
    LModel := LearnSequenceModelCorpus(LSamples, 1);
    try
      LDefinition.Providers[LProvider].ModelText := EncodeWfcSequenceText(LModel);
      LDefinition.Providers[LProvider].VocabularySha256 := SemanticVocabularyIdentity(
        LDefinition.Providers[LProvider].ModelText, LDefinition.Providers[LProvider].Contract);
    finally
      LModel.Free;
    end;
  end;
  SetLength(LDefinition.Projections, 1);
  LDefinition.Projections[0].Provider := 0;
  LDefinition.Projections[0].Consumer := 1;
  LDefinition.Projections[0].TimeMapping := ltmWholeCell;
  SetLength(LDefinition.Projections[0].Rules, 3);
  for LCell := 0 to 2 do
  begin
    LDefinition.Projections[0].Rules[LCell] := MakeWfcSequenceProjectionRule(
      HarmonicToken(CMixes[LCell], CDenominator), [String(PitchNoteToken(CNotes[LCell]))]);
  end;
  Result := TSemanticStyle.CreateSource(LDefinition, ARegistry);
end;

end.
