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
unit pythian.wfc.semantic.style;

{$mode delphi}
{$H+}

interface

uses
  pythian.audio, pythian.time, pythian.wfc.layers, pythian.wfc.provider.contracts,
  pythian.wfc.voices, pythian.wfc.instrument, wfc_model, wfc_sequence,
  wfc_music_voices_graph, wfc_music_ensemble_graph;

const
  MaximumSemanticStyleBytes = 32 * 1024 * 1024;
  MaximumSemanticStyleRuns = 256;

type
  TSemanticSplit = (ssUnassigned, ssTraining, ssValidation, ssTest);
  TSemanticExposure = (seVocabulary, seTraining, seCalibration, seEvaluation);
  TSemanticExposures = set of TSemanticExposure;
  TSemanticSource = record
    Sha256: String;
    GroupId: String;
    Split: TSemanticSplit;
    Exposure: TSemanticExposures;
    SampleRate: Integer;
    FrameCount: Integer;
    ExternalRequirement: String;
    { Direct mapping of this prepared asset to a contiguous original interval.
      PreparationEvidence retains the caller's transformation/audit record. }
    OriginSha256: String;
    OriginSampleRate: Integer;
    OriginFrameCount: Int64;
    OriginStartFrame: Int64;
    OriginEndFrame: Int64;
    PreparationEvidence: TAudioBytes;
    PreparationSha256: String;
  end;
  TSemanticSources = array of TSemanticSource;
  TSemanticProvider = record
    Contract: TProviderContract;
    ModelText: String;
    ExtractionPolicy: String;
    VocabularySha256: String;
    VocabularyAncestor: String;
    Preferences: TLayerTokenPreferences;
    Constraints: TWfcSequenceTokenConstraints;
  end;
  TSemanticProviders = array of TSemanticProvider;
  TSemanticRun = record
    SourceIndex: Integer;
    Identity: String;
    StartFrame: Integer;
    EndFrame: Integer;
    { Exactly the uncovered frames since this source's preceding run, or zero
      for its first run. Runs never concatenate across a gap or source. }
    GapBeforeFrames: Integer;
    TicksPerQuarter: Integer;
    TempoChanges: TTempoChanges;
    TimeGrids: TLayerTimeGrids;
    Tokens: array of TWfcModelTokens;
    Weights: array of Integer;
  end;
  TSemanticRuns = array of TSemanticRun;
  TSemanticSound = record
    RoleId: String;
    Timbre: TAudioBytes;
    Envelope: TAudioBytes;
  end;
  TSemanticSounds = array of TSemanticSound;
  TSemanticVoiceRange = record
    MinimumPitch: Integer;
    MaximumPitch: Integer;
  end;
  TSemanticStyleDefinition = record
    Providers: TSemanticProviders;
    Sources: TSemanticSources;
    Runs: TSemanticRuns;
    Projections: TLayerProjections;
    NamedVoices: Boolean;
    HarmonyMode: TWfcMusicEnsembleHarmonyMode;
    VoiceRanges: array of TSemanticVoiceRange;
    VoicePairs: TWfcMusicVoicePairConstraints;
    Sounds: TSemanticSounds;
  end;

  { Immutable, self-contained models/evidence. ExternalRequirement identifies
    source bytes required to repeat measurement, never an automatic file lookup.
    Current encoding only; all returned records/bytes/sessions are detached. }
  TSemanticStyle = class
  private
    FDefinition: TSemanticStyleDefinition;
    FBytes: TAudioBytes;
    FIdentity: String;
    FDepth: Integer;
    procedure Finish(const ADefinition: TSemanticStyleDefinition; const AParent: TAudioBytes);
  public
    constructor CreateSource(const ADefinition: TSemanticStyleDefinition);
    { Only preferences/constraints may change in this derivation. Models, source
      contributions and observed relationships retain their frozen ancestry. }
    constructor CreateDerived(const AParent: TSemanticStyle;
      const ADefinition: TSemanticStyleDefinition);
    function CopyDefinition: TSemanticStyleDefinition;
    function Encode: TAudioBytes;
    function CreateSession(const ASeed: Integer): TCompatibleProviderSession;
    function CreateVoiceSession(const ASeed: Integer): TNamedVoiceSession;
    function CreateInstrument(const ARoleId: String; const AZones: TStyleInstrumentZones;
      const ASampleRate: Integer): TStyleInstrument;
    property Identity: String read FIdentity;
    property Depth: Integer read FDepth;
  end;

function SemanticVocabularyIdentity(const AModelText: String): String;
function SemanticPreparationIdentity(const ASource: TSemanticSource): String;
procedure SemanticRunOriginRange(const ASource: TSemanticSource; const ARun: TSemanticRun;
  out AStartFrame, AEndFrame: Int64);
function DecodeSemanticStyle(const ABytes: TAudioBytes): TSemanticStyle;

implementation

uses
  Classes, SysUtils, pythian.hash, pythian.wfc.providers, wfc,
  pythian.wfc.style, pythian.wfc.context.profile, pythian.wfc.context.archive,
  pythian.wfc.context, wfc_sequence_learn, wfc_sequence_text;

type
  TOriginPosition = record
    Frame: Int64;
    Fraction: Integer;
    Divisor: Integer;
  end;
  TStyleIO = class
  private
    FStream: TMemoryStream;
    FReading: Boolean;
  public
    constructor Create(const ABytes: TAudioBytes; const AReading: Boolean);
    destructor Destroy; override;
    function N(const AValue: Integer = 0): Integer;
    function Q(const AValue: Int64 = 0): Int64;
    function Count(const AValue, AMaximum: Integer): Integer;
    function Text(const AValue: String = ''): String;
    function Blob(const AValue: TAudioBytes): TAudioBytes;
    function Bytes: TAudioBytes;
    procedure EndOfInput;
  end;

constructor TStyleIO.Create(const ABytes: TAudioBytes; const AReading: Boolean);
begin
  inherited Create;
  FStream := TMemoryStream.Create;
  FReading := AReading;
  if Length(ABytes) > MaximumSemanticStyleBytes then
  begin
    raise EAudio.Create('Semantic archive exceeds 32 MiB');
  end;
  if AReading and (Length(ABytes) > 0) then
  begin
    FStream.WriteBuffer(ABytes[0], Length(ABytes));
    FStream.Position := 0;
  end;
end;

destructor TStyleIO.Destroy;
begin
  FStream.Free;
  inherited Destroy;
end;

function TStyleIO.N(const AValue: Integer): Integer;
var
  LBytes: array[0..3] of Byte;
  LBits: Cardinal;
  LIndex: Integer;
begin
  Result := AValue;
  if FReading then
  begin
    if FStream.Size - FStream.Position < 4 then
    begin
      raise EAudio.Create('Truncated semantic number');
    end;
    FStream.ReadBuffer(LBytes, 4);
    LBits := 0;
    for LIndex := 0 to 3 do
    begin
      LBits := LBits or (Cardinal(LBytes[LIndex]) shl (8 * LIndex));
    end;
    Move(LBits, Result, 4);
  end
  else
  begin
    Move(AValue, LBits, 4);
    for LIndex := 0 to 3 do
    begin
      LBytes[LIndex] := Byte((LBits shr (8 * LIndex)) and 255);
    end;
    FStream.WriteBuffer(LBytes, 4);
  end;
end;

function TStyleIO.Q(const AValue: Int64): Int64;
var
  LBytes: array[0..7] of Byte;
  LBits: QWord;
  LIndex: Integer;
begin
  Result := AValue;
  if FReading then
  begin
    if FStream.Size - FStream.Position < 8 then
    begin
      raise EAudio.Create('Truncated semantic wide number');
    end;
    FStream.ReadBuffer(LBytes, 8);
    LBits := 0;
    for LIndex := 0 to 7 do
    begin
      LBits := LBits or (QWord(LBytes[LIndex]) shl (8 * LIndex));
    end;
    Move(LBits, Result, 8);
  end
  else
  begin
    Move(AValue, LBits, 8);
    for LIndex := 0 to 7 do
    begin
      LBytes[LIndex] := Byte((LBits shr (8 * LIndex)) and 255);
    end;
    FStream.WriteBuffer(LBytes, 8);
  end;
end;

function TStyleIO.Count(const AValue, AMaximum: Integer): Integer;
begin
  Result := N(AValue);
  if (Result < 0) or (Result > AMaximum) then
  begin
    raise EAudio.Create('Semantic count or enum exceeds contract');
  end;
end;

function TStyleIO.Blob(const AValue: TAudioBytes): TAudioBytes;
var
  LCount: Integer;
begin
  Result := nil;
  LCount := Count(Length(AValue), MaximumSemanticStyleBytes);
  if FReading then
  begin
    if LCount > FStream.Size - FStream.Position then
    begin
      raise EAudio.Create('Truncated semantic blob');
    end;
    SetLength(Result, LCount);
    if LCount > 0 then
    begin
      FStream.ReadBuffer(Result[0], LCount);
    end;
  end
  else
  begin
    Result := AValue;
    if LCount > 0 then
    begin
      FStream.WriteBuffer(AValue[0], LCount);
    end;
    if FStream.Size > MaximumSemanticStyleBytes then
    begin
      raise EAudio.Create('Semantic archive exceeds 32 MiB');
    end;
  end;
end;

function TStyleIO.Text(const AValue: String): String;
var
  LBytes: TAudioBytes;
begin
  LBytes := nil;
  if not FReading then
  begin
    SetLength(LBytes, Length(AValue));
    if Length(AValue) > 0 then
    begin
      Move(AValue[1], LBytes[0], Length(AValue));
    end;
  end;
  LBytes := Blob(LBytes);
  if Length(LBytes) > 1024 * 1024 then
  begin
    raise EAudio.Create('Semantic text exceeds 1 MiB');
  end;
  SetLength(Result, Length(LBytes));
  if Length(LBytes) > 0 then
  begin
    Move(LBytes[0], Result[1], Length(LBytes));
  end;
end;

function TStyleIO.Bytes: TAudioBytes;
begin
  Result := nil;
  SetLength(Result, FStream.Size);
  if FStream.Size > 0 then
  begin
    Move(FStream.Memory^, Result[0], FStream.Size);
  end;
end;

procedure TStyleIO.EndOfInput;
begin
  if FReading and (FStream.Position <> FStream.Size) then
  begin
    raise EAudio.Create('Trailing semantic payload');
  end;
end;

procedure ContractIO(const AIO: TStyleIO; var AContract: TProviderContract);
var
  LIndex: Integer;
begin
  AContract.Name := AIO.Text(AContract.Name);
  AContract.Vocabulary := TStyleProviderVocabulary(AIO.Count(Ord(AContract.Vocabulary), Ord(High(TStyleProviderVocabulary))));
  AContract.RoleId := AIO.Text(AContract.RoleId);
  SetLength(AContract.RoleOrder, AIO.Count(Length(AContract.RoleOrder), 6));
  for LIndex := 0 to High(AContract.RoleOrder) do
  begin
    AContract.RoleOrder[LIndex] := AIO.Text(AContract.RoleOrder[LIndex]);
  end;
  AContract.PitchBasis := TProviderPitchBasis(AIO.Count(Ord(AContract.PitchBasis), Ord(High(TProviderPitchBasis))));
  AContract.KeyReference := AIO.Text(AContract.KeyReference);
  AContract.PaletteIdentity := AIO.Text(AContract.PaletteIdentity);
  AContract.MusicalDomain := AIO.Text(AContract.MusicalDomain);
  AContract.TicksPerQuarter := AIO.N(AContract.TicksPerQuarter);
  AContract.Scope.CellCount := AIO.N(AContract.Scope.CellCount);
  AContract.Scope.Extent := TWfcSequenceExtent(AIO.Count(Ord(AContract.Scope.Extent), Ord(High(TWfcSequenceExtent))));
  AContract.TimeGrid.OriginTick := AIO.N(AContract.TimeGrid.OriginTick);
  AContract.TimeGrid.TicksPerCell := AIO.N(AContract.TimeGrid.TicksPerCell);
  SetLength(AContract.TimeGrid.Boundaries, AIO.Count(Length(AContract.TimeGrid.Boundaries), 1025));
  for LIndex := 0 to High(AContract.TimeGrid.Boundaries) do
  begin
    AContract.TimeGrid.Boundaries[LIndex] := AIO.N(AContract.TimeGrid.Boundaries[LIndex]);
  end;
  AContract.UnknownPolicy := AIO.Text(AContract.UnknownPolicy);
  AContract.Source.SourceSha256 := AIO.Text(AContract.Source.SourceSha256);
  AContract.Source.MeasurementIdentity := AIO.Text(AContract.Source.MeasurementIdentity);
  AContract.Source.ConversionIdentity := AIO.Text(AContract.Source.ConversionIdentity);
  AContract.Source.SampleRate := AIO.N(AContract.Source.SampleRate);
  AContract.Source.SourceFrames := AIO.N(AContract.Source.SourceFrames);
  AContract.Source.FrameOffset := AIO.N(AContract.Source.FrameOffset);
  AContract.Source.SourceTicksPerQuarter := AIO.N(AContract.Source.SourceTicksPerQuarter);
  AContract.Source.SourceLengthTicks := AIO.N(AContract.Source.SourceLengthTicks);
  AContract.Source.SourceStartTick := AIO.N(AContract.Source.SourceStartTick);
  SetLength(AContract.Source.TempoChanges, AIO.Count(Length(AContract.Source.TempoChanges), 4096));
  for LIndex := 0 to High(AContract.Source.TempoChanges) do
  begin
    AContract.Source.TempoChanges[LIndex].Tick := AIO.N(AContract.Source.TempoChanges[LIndex].Tick);
    AContract.Source.TempoChanges[LIndex].MicrosecondsPerQuarter := AIO.N(AContract.Source.TempoChanges[LIndex].MicrosecondsPerQuarter);
  end;
  SetLength(AContract.Source.OriginalTicks, AIO.Count(Length(AContract.Source.OriginalTicks), 1025));
  for LIndex := 0 to High(AContract.Source.OriginalTicks) do
  begin
    AContract.Source.OriginalTicks[LIndex] := AIO.N(AContract.Source.OriginalTicks[LIndex]);
  end;
  SetLength(AContract.Source.OriginalFrames, AIO.Count(Length(AContract.Source.OriginalFrames), 1025));
  for LIndex := 0 to High(AContract.Source.OriginalFrames) do
  begin
    AContract.Source.OriginalFrames[LIndex] := AIO.N(AContract.Source.OriginalFrames[LIndex]);
  end;
end;

procedure DefinitionIO(const AIO: TStyleIO; var ADefinition: TSemanticStyleDefinition);
var
  LIndex: Integer;
  LItem: Integer;
  LCell: Integer;
  LExposure: TSemanticExposure;
  LFlags: Integer;
begin
  SetLength(ADefinition.Providers, AIO.Count(Length(ADefinition.Providers), 8));
  for LIndex := 0 to High(ADefinition.Providers) do
  begin
    ContractIO(AIO, ADefinition.Providers[LIndex].Contract);
    ADefinition.Providers[LIndex].ModelText := AIO.Text(ADefinition.Providers[LIndex].ModelText);
    ADefinition.Providers[LIndex].ExtractionPolicy := AIO.Text(ADefinition.Providers[LIndex].ExtractionPolicy);
    ADefinition.Providers[LIndex].VocabularySha256 := AIO.Text(ADefinition.Providers[LIndex].VocabularySha256);
    ADefinition.Providers[LIndex].VocabularyAncestor := AIO.Text(ADefinition.Providers[LIndex].VocabularyAncestor);
    SetLength(ADefinition.Providers[LIndex].Preferences, AIO.Count(Length(ADefinition.Providers[LIndex].Preferences), 1024));
    for LItem := 0 to High(ADefinition.Providers[LIndex].Preferences) do
    begin
      ADefinition.Providers[LIndex].Preferences[LItem].Token := AIO.Text(ADefinition.Providers[LIndex].Preferences[LItem].Token);
      ADefinition.Providers[LIndex].Preferences[LItem].Multiplier := AIO.N(ADefinition.Providers[LIndex].Preferences[LItem].Multiplier);
    end;
    SetLength(ADefinition.Providers[LIndex].Constraints, AIO.Count(Length(ADefinition.Providers[LIndex].Constraints), 1024));
    for LItem := 0 to High(ADefinition.Providers[LIndex].Constraints) do
    begin
      ADefinition.Providers[LIndex].Constraints[LItem].Position := AIO.N(ADefinition.Providers[LIndex].Constraints[LItem].Position);
      SetLength(ADefinition.Providers[LIndex].Constraints[LItem].AllowedTokens, AIO.Count(Length(ADefinition.Providers[LIndex].Constraints[LItem].AllowedTokens), 4096));
      for LCell := 0 to High(ADefinition.Providers[LIndex].Constraints[LItem].AllowedTokens) do
      begin
        ADefinition.Providers[LIndex].Constraints[LItem].AllowedTokens[LCell] := AIO.Text(ADefinition.Providers[LIndex].Constraints[LItem].AllowedTokens[LCell]);
      end;
    end;
  end;
  SetLength(ADefinition.Sources, AIO.Count(Length(ADefinition.Sources), 32));
  for LIndex := 0 to High(ADefinition.Sources) do
  begin
    ADefinition.Sources[LIndex].Sha256 := AIO.Text(ADefinition.Sources[LIndex].Sha256);
    ADefinition.Sources[LIndex].GroupId := AIO.Text(ADefinition.Sources[LIndex].GroupId);
    ADefinition.Sources[LIndex].Split := TSemanticSplit(AIO.Count(Ord(ADefinition.Sources[LIndex].Split), 3));
    LFlags := 0;
    for LExposure in ADefinition.Sources[LIndex].Exposure do
    begin
      LFlags := LFlags or (1 shl Ord(LExposure));
    end;
    LFlags := AIO.Count(LFlags, 15);
    ADefinition.Sources[LIndex].Exposure := [];
    for LExposure := Low(TSemanticExposure) to High(TSemanticExposure) do
    begin
      if LFlags and (1 shl Ord(LExposure)) <> 0 then
      begin
        Include(ADefinition.Sources[LIndex].Exposure, LExposure);
      end;
    end;
    ADefinition.Sources[LIndex].SampleRate := AIO.N(ADefinition.Sources[LIndex].SampleRate);
    ADefinition.Sources[LIndex].FrameCount := AIO.N(ADefinition.Sources[LIndex].FrameCount);
    ADefinition.Sources[LIndex].ExternalRequirement := AIO.Text(ADefinition.Sources[LIndex].ExternalRequirement);
    ADefinition.Sources[LIndex].OriginSha256 := AIO.Text(ADefinition.Sources[LIndex].OriginSha256);
    ADefinition.Sources[LIndex].OriginSampleRate := AIO.N(ADefinition.Sources[LIndex].OriginSampleRate);
    ADefinition.Sources[LIndex].OriginFrameCount := AIO.Q(ADefinition.Sources[LIndex].OriginFrameCount);
    ADefinition.Sources[LIndex].OriginStartFrame := AIO.Q(ADefinition.Sources[LIndex].OriginStartFrame);
    ADefinition.Sources[LIndex].OriginEndFrame := AIO.Q(ADefinition.Sources[LIndex].OriginEndFrame);
    ADefinition.Sources[LIndex].PreparationEvidence := AIO.Blob(ADefinition.Sources[LIndex].PreparationEvidence);
    ADefinition.Sources[LIndex].PreparationSha256 := AIO.Text(ADefinition.Sources[LIndex].PreparationSha256);
  end;
  SetLength(ADefinition.Runs, AIO.Count(Length(ADefinition.Runs), MaximumSemanticStyleRuns));
  for LIndex := 0 to High(ADefinition.Runs) do
  begin
    ADefinition.Runs[LIndex].SourceIndex := AIO.N(ADefinition.Runs[LIndex].SourceIndex);
    ADefinition.Runs[LIndex].Identity := AIO.Text(ADefinition.Runs[LIndex].Identity);
    ADefinition.Runs[LIndex].StartFrame := AIO.N(ADefinition.Runs[LIndex].StartFrame);
    ADefinition.Runs[LIndex].EndFrame := AIO.N(ADefinition.Runs[LIndex].EndFrame);
    ADefinition.Runs[LIndex].GapBeforeFrames := AIO.N(ADefinition.Runs[LIndex].GapBeforeFrames);
    ADefinition.Runs[LIndex].TicksPerQuarter := AIO.N(ADefinition.Runs[LIndex].TicksPerQuarter);
    SetLength(ADefinition.Runs[LIndex].TempoChanges, AIO.Count(Length(ADefinition.Runs[LIndex].TempoChanges), 4096));
    for LItem := 0 to High(ADefinition.Runs[LIndex].TempoChanges) do
    begin
      ADefinition.Runs[LIndex].TempoChanges[LItem].Tick := AIO.N(ADefinition.Runs[LIndex].TempoChanges[LItem].Tick);
      ADefinition.Runs[LIndex].TempoChanges[LItem].MicrosecondsPerQuarter := AIO.N(ADefinition.Runs[LIndex].TempoChanges[LItem].MicrosecondsPerQuarter);
    end;
    SetLength(ADefinition.Runs[LIndex].TimeGrids, AIO.Count(Length(ADefinition.Runs[LIndex].TimeGrids), 8));
    for LItem := 0 to High(ADefinition.Runs[LIndex].TimeGrids) do
    begin
      ADefinition.Runs[LIndex].TimeGrids[LItem].OriginTick := AIO.N(ADefinition.Runs[LIndex].TimeGrids[LItem].OriginTick);
      ADefinition.Runs[LIndex].TimeGrids[LItem].TicksPerCell := AIO.N(ADefinition.Runs[LIndex].TimeGrids[LItem].TicksPerCell);
      SetLength(ADefinition.Runs[LIndex].TimeGrids[LItem].Boundaries, AIO.Count(Length(ADefinition.Runs[LIndex].TimeGrids[LItem].Boundaries), 1025));
      for LCell := 0 to High(ADefinition.Runs[LIndex].TimeGrids[LItem].Boundaries) do
      begin
        ADefinition.Runs[LIndex].TimeGrids[LItem].Boundaries[LCell] := AIO.N(ADefinition.Runs[LIndex].TimeGrids[LItem].Boundaries[LCell]);
      end;
    end;
    SetLength(ADefinition.Runs[LIndex].Tokens, AIO.Count(Length(ADefinition.Runs[LIndex].Tokens), 8));
    SetLength(ADefinition.Runs[LIndex].Weights, AIO.Count(Length(ADefinition.Runs[LIndex].Weights), 8));
    for LItem := 0 to High(ADefinition.Runs[LIndex].Weights) do
    begin
      ADefinition.Runs[LIndex].Weights[LItem] := AIO.Count(ADefinition.Runs[LIndex].Weights[LItem], 64);
    end;
    for LItem := 0 to High(ADefinition.Runs[LIndex].Tokens) do
    begin
      SetLength(ADefinition.Runs[LIndex].Tokens[LItem], AIO.Count(Length(ADefinition.Runs[LIndex].Tokens[LItem]), 1024));
      for LCell := 0 to High(ADefinition.Runs[LIndex].Tokens[LItem]) do
      begin
        ADefinition.Runs[LIndex].Tokens[LItem][LCell] := AIO.Text(ADefinition.Runs[LIndex].Tokens[LItem][LCell]);
      end;
    end;
  end;
  SetLength(ADefinition.Projections, AIO.Count(Length(ADefinition.Projections), 64));
  for LIndex := 0 to High(ADefinition.Projections) do
  begin
    ADefinition.Projections[LIndex].Provider := AIO.N(ADefinition.Projections[LIndex].Provider);
    ADefinition.Projections[LIndex].Consumer := AIO.N(ADefinition.Projections[LIndex].Consumer);
    ADefinition.Projections[LIndex].TimeMapping := TLayerTimeMapping(AIO.Count(Ord(ADefinition.Projections[LIndex].TimeMapping), 2));
    SetLength(ADefinition.Projections[LIndex].Rules, AIO.Count(Length(ADefinition.Projections[LIndex].Rules), 4096));
    for LItem := 0 to High(ADefinition.Projections[LIndex].Rules) do
    begin
      ADefinition.Projections[LIndex].Rules[LItem].TargetToken := AIO.Text(ADefinition.Projections[LIndex].Rules[LItem].TargetToken);
      SetLength(ADefinition.Projections[LIndex].Rules[LItem].SourceTokens, AIO.Count(Length(ADefinition.Projections[LIndex].Rules[LItem].SourceTokens), 4096));
      for LCell := 0 to High(ADefinition.Projections[LIndex].Rules[LItem].SourceTokens) do
      begin
        ADefinition.Projections[LIndex].Rules[LItem].SourceTokens[LCell] := AIO.Text(ADefinition.Projections[LIndex].Rules[LItem].SourceTokens[LCell]);
      end;
    end;
  end;
  ADefinition.NamedVoices := AIO.Count(Ord(ADefinition.NamedVoices), 1) <> 0;
  ADefinition.HarmonyMode := TWfcMusicEnsembleHarmonyMode(AIO.Count(Ord(ADefinition.HarmonyMode), 1));
  SetLength(ADefinition.VoiceRanges, AIO.Count(Length(ADefinition.VoiceRanges), 6));
  for LIndex := 0 to High(ADefinition.VoiceRanges) do
  begin
    ADefinition.VoiceRanges[LIndex].MinimumPitch := AIO.N(ADefinition.VoiceRanges[LIndex].MinimumPitch);
    ADefinition.VoiceRanges[LIndex].MaximumPitch := AIO.N(ADefinition.VoiceRanges[LIndex].MaximumPitch);
  end;
  SetLength(ADefinition.VoicePairs, AIO.Count(Length(ADefinition.VoicePairs), 15));
  for LIndex := 0 to High(ADefinition.VoicePairs) do
  begin
    ADefinition.VoicePairs[LIndex].LowerVoice := AIO.N(ADefinition.VoicePairs[LIndex].LowerVoice);
    ADefinition.VoicePairs[LIndex].UpperVoice := AIO.N(ADefinition.VoicePairs[LIndex].UpperVoice);
    ADefinition.VoicePairs[LIndex].MinGap := AIO.N(ADefinition.VoicePairs[LIndex].MinGap);
    ADefinition.VoicePairs[LIndex].MaxGap := AIO.N(ADefinition.VoicePairs[LIndex].MaxGap);
    ADefinition.VoicePairs[LIndex].RestPolicy := TWfcMusicVoicePairRestPolicy(AIO.Count(Ord(ADefinition.VoicePairs[LIndex].RestPolicy), 1));
  end;
  SetLength(ADefinition.Sounds, AIO.Count(Length(ADefinition.Sounds), 6));
  for LIndex := 0 to High(ADefinition.Sounds) do
  begin
    ADefinition.Sounds[LIndex].RoleId := AIO.Text(ADefinition.Sounds[LIndex].RoleId);
    ADefinition.Sounds[LIndex].Timbre := AIO.Blob(ADefinition.Sounds[LIndex].Timbre);
    ADefinition.Sounds[LIndex].Envelope := AIO.Blob(ADefinition.Sounds[LIndex].Envelope);
  end;
end;

function DefinitionBytes(const ADefinition: TSemanticStyleDefinition): TAudioBytes;
var
  LIO: TStyleIO;
  LDefinition: TSemanticStyleDefinition;
begin
  LDefinition := ADefinition;
  LIO := TStyleIO.Create(nil, False);
  try
    DefinitionIO(LIO, LDefinition);
    Result := LIO.Bytes;
  finally
    LIO.Free;
  end;
end;

function ReadDefinition(const ABytes: TAudioBytes): TSemanticStyleDefinition;
var
  LIO: TStyleIO;
begin
  Result := Default(TSemanticStyleDefinition);
  LIO := TStyleIO.Create(ABytes, True);
  try
    DefinitionIO(LIO, Result);
    LIO.EndOfInput;
  finally
    LIO.Free;
  end;
end;

function SemanticVocabularyIdentity(const AModelText: String): String;
var
  LModel: TWfcSequenceModel;
  LIO: TStyleIO;
  LIndex: Integer;
begin
  LModel := DecodeWfcSequenceText(AModelText);
  LIO := nil;
  try
    LIO := TStyleIO.Create(nil, False);
    for LIndex := 0 to LModel.PublicTokenCount - 1 do
    begin
      LIO.Text(LModel.PublicTokenAt(LIndex));
    end;
    Result := Sha256Bytes(LIO.Bytes);
  finally
    LIO.Free;
    LModel.Free;
  end;
end;

procedure Require(const ACondition: Boolean; const AMessage: String);
begin
  if not ACondition then
  begin
    raise EAudio.Create(AMessage);
  end;
end;

procedure CheckIdentity(const AValue: String);
var
  LIndex: Integer;
begin
  Require(Length(AValue) = 64, 'Semantic identity requires SHA256');
  for LIndex := 1 to Length(AValue) do
  begin
    Require(AValue[LIndex] in ['0'..'9', 'a'..'f'], 'Semantic identity is not canonical SHA256');
  end;
end;

procedure ValidateOriginGeometry(const ASource: TSemanticSource);
begin
  CheckIdentity(ASource.Sha256);
  CheckIdentity(ASource.OriginSha256);
  ValidateAudioFormat(ASource.SampleRate, 1);
  ValidateAudioFormat(ASource.OriginSampleRate, 1);
  Require((ASource.FrameCount > 0) and (ASource.OriginFrameCount > 0) and
    (ASource.OriginStartFrame >= 0) and
    (ASource.OriginEndFrame > ASource.OriginStartFrame) and
    (ASource.OriginEndFrame <= ASource.OriginFrameCount),
    'Semantic preparation origin interval or clock is invalid');
  Require((Length(ASource.PreparationEvidence) > 0) and
    (Length(ASource.PreparationEvidence) <= 65536),
    'Semantic preparation requires bounded retained evidence');
  if ASource.Sha256 = ASource.OriginSha256 then
  begin
    Require((ASource.SampleRate = ASource.OriginSampleRate) and
      (ASource.FrameCount = ASource.OriginFrameCount) and
      (ASource.OriginStartFrame = 0) and
      (ASource.OriginEndFrame = ASource.OriginFrameCount),
      'Original source must retain its identity clock and full interval');
  end;
end;

function SemanticPreparationIdentity(const ASource: TSemanticSource): String;
var
  LIO: TStyleIO;
begin
  ValidateOriginGeometry(ASource);
  LIO := TStyleIO.Create(nil, False);
  try
    LIO.Text('pythian.semantic.preparation');
    LIO.Text(ASource.Sha256);
    LIO.N(ASource.SampleRate);
    LIO.N(ASource.FrameCount);
    LIO.Text(ASource.OriginSha256);
    LIO.N(ASource.OriginSampleRate);
    LIO.Q(ASource.OriginFrameCount);
    LIO.Q(ASource.OriginStartFrame);
    LIO.Q(ASource.OriginEndFrame);
    LIO.Blob(ASource.PreparationEvidence);
    Result := Sha256Bytes(LIO.Bytes);
  finally
    LIO.Free;
  end;
end;

procedure ValidatePreparation(const ASource: TSemanticSource);
begin
  CheckIdentity(ASource.PreparationSha256);
  Require(ASource.PreparationSha256 = SemanticPreparationIdentity(ASource),
    'Semantic preparation evidence or mapped source binding differs');
end;

function MapOriginPosition(const ASource: TSemanticSource; const AFrame: Integer): TOriginPosition;
var
  LSpan: Int64;
  LRemainderProduct: Int64;
begin
  LSpan := ASource.OriginEndFrame - ASource.OriginStartFrame;
  { Both products are bounded without multiplying a long original interval by
    the complete prepared frame index. The remainder factors fit Integer. }
  LRemainderProduct := (LSpan mod ASource.FrameCount) * AFrame;
  Result.Frame := ASource.OriginStartFrame +
    (LSpan div ASource.FrameCount) * AFrame +
    LRemainderProduct div ASource.FrameCount;
  Result.Fraction := LRemainderProduct mod ASource.FrameCount;
  Result.Divisor := ASource.FrameCount;
end;

function MapOriginFrame(const ASource: TSemanticSource; const AFrame: Integer;
  const ARoundUp: Boolean): Int64;
var
  LPosition: TOriginPosition;
begin
  LPosition := MapOriginPosition(ASource, AFrame);
  Result := LPosition.Frame;
  if ARoundUp and (LPosition.Fraction <> 0) then
  begin
    Inc(Result);
  end;
end;

function OriginBefore(const ALeft, ARight: TOriginPosition): Boolean;
begin
  if ALeft.Frame <> ARight.Frame then
  begin
    Result := ALeft.Frame < ARight.Frame;
  end
  else
  begin
    Result := Int64(ALeft.Fraction) * ARight.Divisor <
      Int64(ARight.Fraction) * ALeft.Divisor;
  end;
end;

procedure SemanticRunOriginRange(const ASource: TSemanticSource; const ARun: TSemanticRun;
  out AStartFrame, AEndFrame: Int64);
begin
  ValidatePreparation(ASource);
  Require((ARun.StartFrame >= 0) and (ARun.EndFrame > ARun.StartFrame) and
    (ARun.EndFrame <= ASource.FrameCount), 'Observed run cannot map outside its source');
  AStartFrame := MapOriginFrame(ASource, ARun.StartFrame, False);
  AEndFrame := MapOriginFrame(ASource, ARun.EndFrame, True);
end;

function LoadLayers(const ADefinition: TSemanticStyleDefinition): TLearnedLayers;
var
  LIndex: Integer;
begin
  Result := nil;
  SetLength(Result, Length(ADefinition.Providers));
  try
    for LIndex := 0 to High(Result) do
    begin
      Result[LIndex].Model := DecodeWfcSequenceText(ADefinition.Providers[LIndex].ModelText);
      Result[LIndex].Constraints := ADefinition.Providers[LIndex].Constraints;
      Result[LIndex].Preferences := ADefinition.Providers[LIndex].Preferences;
    end;
  except
    for LIndex := 0 to High(Result) do
    begin
      Result[LIndex].Model.Free;
    end;
    raise;
  end;
end;

procedure FreeLayers(const ALayers: TLearnedLayers);
var
  LIndex: Integer;
begin
  for LIndex := 0 to High(ALayers) do
  begin
    ALayers[LIndex].Model.Free;
  end;
end;

function Contracts(const ADefinition: TSemanticStyleDefinition): TProviderContracts;
var
  LIndex: Integer;
begin
  Result := nil;
  SetLength(Result, Length(ADefinition.Providers));
  for LIndex := 0 to High(Result) do
  begin
    Result[LIndex] := CopyProviderContract(ADefinition.Providers[LIndex].Contract);
  end;
end;

function VoiceConfig(const ADefinition: TSemanticStyleDefinition;
  const ALayers: TLearnedLayers): TWfcMusicVoicesGraphConfig;
var
  LIndex: Integer;
begin
  Result := Default(TWfcMusicVoicesGraphConfig);
  Require(ADefinition.NamedVoices and (Length(ALayers) >= 3) and
    (Length(ADefinition.VoiceRanges) = Length(ALayers) - 2), 'Semantic named voice layout is incomplete');
  Require(Length(ADefinition.Projections) = 0, 'Named voice dependencies are defined by its actual config');
  Result.StepsPerOctave := 12;
  Result.HarmonyMode := ADefinition.HarmonyMode;
  Result.HarmonyModel := ALayers[0].Model;
  Result.RhythmModel := ALayers[1].Model;
  Result.PairConstraints := Copy(ADefinition.VoicePairs);
  SetLength(Result.Voices, Length(ALayers) - 2);
  for LIndex := 0 to High(Result.Voices) do
  begin
    Result.Voices[LIndex].Model := ALayers[LIndex + 2].Model;
    Result.Voices[LIndex].MinPitch := ADefinition.VoiceRanges[LIndex].MinimumPitch;
    Result.Voices[LIndex].MaxPitch := ADefinition.VoiceRanges[LIndex].MaximumPitch;
  end;
end;

function TSemanticStyle.CreateSession(const ASeed: Integer): TCompatibleProviderSession;
var
  LLayers: TLearnedLayers;
  LOptions: TLayerGenerationOptions;
begin
  Require(not FDefinition.NamedVoices, 'Named semantic graph requires CreateVoiceSession');
  LLayers := LoadLayers(FDefinition);
  try
    LOptions := DefaultLayerGenerationOptions;
    LOptions.Seed := ASeed;
    Result := TCompatibleProviderSession.Create(LLayers, FDefinition.Projections,
      Contracts(FDefinition), LOptions);
  finally
    FreeLayers(LLayers);
  end;
end;

function TSemanticStyle.CreateVoiceSession(const ASeed: Integer): TNamedVoiceSession;
var
  LLayers: TLearnedLayers;
  LConfig: TWfcMusicVoicesGraphConfig;
  LNames: TLayerNames;
  LOptions: TVoiceSessionOptions;
  LIndex: Integer;
  LSession: TNamedVoiceSession;
begin
  LLayers := LoadLayers(FDefinition);
  try
    LConfig := VoiceConfig(FDefinition, LLayers);
    SetLength(LNames, Length(LConfig.Voices));
    for LIndex := 0 to High(LNames) do
    begin
      LNames[LIndex] := FDefinition.Providers[LIndex + 2].Contract.RoleId;
    end;
    LOptions := DefaultVoiceSessionOptions;
    LOptions.Seed := ASeed;
    LOptions.CellCount := FDefinition.Providers[0].Contract.Scope.CellCount;
    LOptions.TicksPerQuarter := FDefinition.Providers[0].Contract.TicksPerQuarter;
    LOptions.StepTicks := FDefinition.Providers[0].Contract.TimeGrid.TicksPerCell;
    LOptions.RequireObservedEnd := FDefinition.Providers[0].Contract.Scope.Extent = wseWhole;
    LSession := TNamedVoiceSession.Create(LConfig, LNames, LOptions, Contracts(FDefinition));
    try
      for LIndex := 0 to High(LLayers) do
      begin
        LSession.SetConstraints(LSession.ProviderName(LIndex), LLayers[LIndex].Constraints);
        LSession.SetPreferences(LSession.ProviderName(LIndex), LLayers[LIndex].Preferences);
      end;
      Result := LSession;
    except
      LSession.Free;
      raise;
    end;
  finally
    FreeLayers(LLayers);
  end;
end;

function RunBoundary(const ARun: TSemanticRun; const AProvider, ACell: Integer): Integer;
var
  LValue: Int64;
begin
  if Length(ARun.TimeGrids[AProvider].Boundaries) > 0 then
  begin
    Result := ARun.TimeGrids[AProvider].Boundaries[ACell];
  end
  else
  begin
    LValue := Int64(ARun.TimeGrids[AProvider].OriginTick) +
      Int64(ACell) * ARun.TimeGrids[AProvider].TicksPerCell;
    Require((LValue >= 0) and (LValue <= High(Integer)), 'Observed run boundary overflows tick domain');
    Result := Integer(LValue);
  end;
end;

procedure ValidateRunClock(const ARun: TSemanticRun; const ASource: TSemanticSource);
var
  LProvider: Integer;
  LCell: Integer;
  LMaximum: Integer;
  LClock: TTempoMap;
begin
  Require(Length(ARun.TimeGrids) = Length(ARun.Tokens), 'Observed run requires an explicit grid per provider');
  LMaximum := 0;
  for LProvider := 0 to High(ARun.Tokens) do
  begin
    if Length(ARun.Tokens[LProvider]) = 0 then
    begin
      Require((ARun.TimeGrids[LProvider].OriginTick = 0) and
        (ARun.TimeGrids[LProvider].TicksPerCell = 0) and
        (Length(ARun.TimeGrids[LProvider].Boundaries) = 0), 'Absent observed provider must omit its grid');
      Continue;
    end;
    if Length(ARun.TimeGrids[LProvider].Boundaries) = 0 then
    begin
      Require((ARun.TimeGrids[LProvider].OriginTick >= 0) and
        (ARun.TimeGrids[LProvider].TicksPerCell > 0), 'Observed uniform grid is invalid');
    end
    else
    begin
      Require((Length(ARun.TimeGrids[LProvider].Boundaries) = Length(ARun.Tokens[LProvider]) + 1) and
        (ARun.TimeGrids[LProvider].OriginTick = 0) and (ARun.TimeGrids[LProvider].TicksPerCell = 0),
        'Observed partition geometry is invalid');
    end;
    for LCell := 0 to High(ARun.Tokens[LProvider]) do
    begin
      Require((RunBoundary(ARun, LProvider, LCell) >= 0) and
        (RunBoundary(ARun, LProvider, LCell + 1) > RunBoundary(ARun, LProvider, LCell)),
        'Observed provider boundaries must strictly increase');
    end;
    if RunBoundary(ARun, LProvider, Length(ARun.Tokens[LProvider])) > LMaximum then
    begin
      LMaximum := RunBoundary(ARun, LProvider, Length(ARun.Tokens[LProvider]));
    end;
  end;
  LClock := TTempoMap.Create(ARun.TicksPerQuarter, LMaximum, ARun.TempoChanges);
  try
    Require(LClock.FrameAtTick(LMaximum, ASource.SampleRate) = ARun.EndFrame - ARun.StartFrame,
      'Observed PPQ/tempo clock does not reproduce its original source-frame extent');
  finally
    LClock.Free;
  end;
end;

procedure ValidateMappedRun(const ADefinition: TSemanticStyleDefinition;
  const ALayers: TLearnedLayers; const ARun: TSemanticRun);
var
  LSubset: TLearnedLayers;
  LNames: TLayerNames;
  LIndices: array of Integer;
  LMaps: TLayerProjections;
  LOptions: TLayerGenerationOptions;
  LIndex: Integer;
  LNew: Integer;
  LCell: Integer;
  LMap: TLayerProjection;
  LSession: TLearnedLayerSession;
  LGenerated: TLayerSequences;
  LReport: TGraphNegotiationReport;
begin
  LSubset := nil;
  LMaps := nil;
  LOptions := DefaultLayerGenerationOptions;
  SetLength(LIndices, Length(ALayers));
  for LIndex := 0 to High(ALayers) do
  begin
    LIndices[LIndex] := -1;
    if Length(ARun.Tokens[LIndex]) = 0 then
    begin
      Continue;
    end;
    LNew := Length(LSubset);
    LIndices[LIndex] := LNew;
    SetLength(LSubset, LNew + 1);
    SetLength(LNames, LNew + 1);
    SetLength(LOptions.Scopes, LNew + 1);
    SetLength(LOptions.TimeGrids, LNew + 1);
    LNames[LNew] := ADefinition.Providers[LIndex].Contract.Name;
    LSubset[LNew].Model := ALayers[LIndex].Model;
    LOptions.Scopes[LNew] := MakeLayerScope(Length(ARun.Tokens[LIndex]), wseWhole);
    LOptions.TimeGrids[LNew] := ARun.TimeGrids[LIndex];
    SetLength(LSubset[LNew].Constraints, Length(ARun.Tokens[LIndex]));
    for LCell := 0 to High(ARun.Tokens[LIndex]) do
    begin
      LSubset[LNew].Constraints[LCell] := MakeWfcSequenceTokenConstraint(LCell, [ARun.Tokens[LIndex][LCell]]);
    end;
  end;
  for LMap in ADefinition.Projections do
  begin
    Require((LIndices[LMap.Provider] < 0) = (LIndices[LMap.Consumer] < 0),
      'Observed joint provider pair must be present or absent together');
    if LIndices[LMap.Provider] < 0 then
    begin
      Continue;
    end;
    Require(ARun.Weights[LMap.Provider] = ARun.Weights[LMap.Consumer], 'Observed mapped contributions must remain paired');
    LNew := Length(LMaps);
    SetLength(LMaps, LNew + 1);
    LMaps[LNew] := LMap;
    LMaps[LNew].Provider := LIndices[LMap.Provider];
    LMaps[LNew].Consumer := LIndices[LMap.Consumer];
  end;
  LSession := TLearnedLayerSession.Create(LSubset, LMaps, LNames, LOptions);
  try
    Require(LSession.TryGenerate(LGenerated, LReport), 'Observed run violates actual mapped projection/coverage relationships');
  finally
    LSession.Free;
  end;
end;

function ObservedPair(const ARun: TSemanticRun; const AProjection: TLayerProjection;
  const ASource, ATarget: String): Boolean;
var
  LProviderCell: Integer;
  LConsumerCell: Integer;
  LMapped: Boolean;
begin
  Result := False;
  for LConsumerCell := 0 to High(ARun.Tokens[AProjection.Consumer]) do
  begin
    for LProviderCell := 0 to High(ARun.Tokens[AProjection.Provider]) do
    begin
      case AProjection.TimeMapping of
        ltmCellIndex: LMapped := LProviderCell = LConsumerCell;
        ltmStartTick: LMapped :=
          (RunBoundary(ARun, AProjection.Provider, LProviderCell) <= RunBoundary(ARun, AProjection.Consumer, LConsumerCell)) and
          (RunBoundary(ARun, AProjection.Provider, LProviderCell + 1) > RunBoundary(ARun, AProjection.Consumer, LConsumerCell));
      else
        LMapped := (RunBoundary(ARun, AProjection.Provider, LProviderCell) < RunBoundary(ARun, AProjection.Consumer, LConsumerCell + 1)) and
          (RunBoundary(ARun, AProjection.Provider, LProviderCell + 1) > RunBoundary(ARun, AProjection.Consumer, LConsumerCell));
      end;
      if LMapped and (ARun.Tokens[AProjection.Provider][LProviderCell] = ASource) and
        (ARun.Tokens[AProjection.Consumer][LConsumerCell] = ATarget) then
      begin
        Exit(True);
      end;
    end;
  end;
end;

procedure ValidateContextSources(const AContext: TContextProfile;
  const ASources: TSemanticSources; const ADepth: Integer);
var
  LDimension: TContextDimension;
  LBundle: TContextLearningBundle;
  LEvidence: TContextEvidenceArray;
  LSource: Integer;
  LOther: Integer;
  LFound: Boolean;
  LParent: TContextProfile;
begin
  Require(ADepth <= 8, 'Embedded context ancestry exceeds exposure audit bound');
  for LDimension := Low(TContextDimension) to High(TContextDimension) do
  begin
    LBundle := AContext.CopyBundle(LDimension);
    try
      LEvidence := LBundle.CopyEvidence;
      for LSource := 0 to High(LEvidence) do
      begin
        LFound := False;
        for LOther := 0 to High(ASources) do
        begin
          if LEvidence[LSource].SourceSha256 = ASources[LOther].Sha256 then
          begin
            LFound := (ASources[LOther].Split = ssTraining) and
              ([seTraining, seVocabulary] <= ASources[LOther].Exposure);
          end;
        end;
        Require(LFound, 'Embedded context selection or ancestry lacks source/exposure binding');
      end;
    finally
      LBundle.Free;
    end;
    if AContext.IsSelection then
    begin
      LParent := AContext.CopyParent(LDimension);
      try
        ValidateContextSources(LParent, ASources, ADepth + 1);
      finally
        LParent.Free;
      end;
    end;
  end;
end;

procedure ValidateSoundAncestry(const ASound: TWaveStyleProfile;
  const ASources: TSemanticSources; const ADepth: Integer);
var
  LSource: Integer;
  LOther: Integer;
  LSide: Integer;
  LFound: Boolean;
  LContext: TContextProfile;
  LParent: TWaveStyleProfile;
begin
  Require(ADepth <= 8, 'Embedded sound ancestry exceeds exposure audit bound');
  for LSource := 0 to ASound.SourceCount - 1 do
  begin
    LFound := False;
    for LOther := 0 to High(ASources) do
    begin
      if ASound.EvidenceAt(LSource).Source.Sha256 = ASources[LOther].Sha256 then
      begin
        LFound := (ASources[LOther].Split = ssTraining) and
          ([seTraining, seVocabulary] <= ASources[LOther].Exposure) and
          (ASources[LOther].SampleRate = ASound.EvidenceAt(LSource).Source.SampleRate) and
          (ASources[LOther].FrameCount = ASound.EvidenceAt(LSource).Source.FrameCount);
      end;
    end;
    Require(LFound, 'Embedded sound contribution or ancestry lacks source/exposure binding');
  end;
  LContext := ASound.CopyContext;
  try
    ValidateContextSources(LContext, ASources, 1);
  finally
    LContext.Free;
  end;
  for LSide := 0 to 1 do
  begin
    LParent := ASound.CopyParent(LSide);
    if LParent <> nil then
    begin
      try
        ValidateSoundAncestry(LParent, ASources, ADepth + 1);
      finally
        LParent.Free;
      end;
    end;
  end;
end;

procedure ValidateDefinition(const AStyle: TSemanticStyle);
var
  LDefinition: TSemanticStyleDefinition;
  LLayers: TLearnedLayers;
  LModel: TWfcSequenceModel;
  LSamples: TWfcSequenceSamples;
  LSource: Integer;
  LRun: Integer;
  LProvider: Integer;
  LOther: Integer;
  LWeight: Integer;
  LCount: Integer;
  LCell: Integer;
  LRule: Integer;
  LAlternative: Integer;
  LProjection: TLayerProjection;
  LFound: Boolean;
  LTotal: Int64;
  LPreviousEnds: array of Integer;
  LOriginStarts: array of TOriginPosition;
  LOriginEnds: array of TOriginPosition;
  LOtherSource: Integer;
  LGrid: TCompatibleProviderSession;
  LVoices: TNamedVoiceSession;
  LSound: TWaveStyleProfile;
  LSoundBytes: TAudioBytes;
  LSide: Integer;
  LContract: TProviderContract;
  LConfig: TWfcMusicVoicesGraphConfig;
  LOptions: TVoiceSessionOptions;
  LNames: TLayerNames;
  LMask: TWfcSequenceTokenConstraints;
  LGenerated: TWfcMusicVoicesGenerated;
  LReport: TGraphNegotiationReport;
  LProof: TWfcMusicVoicesValidationReport;
begin
  LDefinition := AStyle.FDefinition;
  Require((Length(LDefinition.Providers) > 0) and (Length(LDefinition.Sources) > 0) and
    (Length(LDefinition.Runs) > 0), 'Semantic style requires providers, sources and observed runs');
  SetLength(LPreviousEnds, Length(LDefinition.Sources));
  SetLength(LOriginStarts, Length(LDefinition.Runs));
  SetLength(LOriginEnds, Length(LDefinition.Runs));
  for LSource := 0 to High(LDefinition.Sources) do
  begin
    LPreviousEnds[LSource] := -1;
    CheckIdentity(LDefinition.Sources[LSource].Sha256);
    Require((Length(LDefinition.Sources[LSource].GroupId) in [1..255]) and
      (Length(LDefinition.Sources[LSource].ExternalRequirement) in [1..255]) and
      (LDefinition.Sources[LSource].FrameCount > 0), 'Semantic source requires group, geometry and external requirement');
    ValidateAudioFormat(LDefinition.Sources[LSource].SampleRate, 1);
    ValidatePreparation(LDefinition.Sources[LSource]);
    Require(not ((LDefinition.Sources[LSource].Split in [ssValidation, ssTest]) and
      (LDefinition.Sources[LSource].Exposure * [seTraining, seVocabulary] <> [])),
      'Held-out source cannot contribute training or frozen vocabulary');
    for LOther := 0 to LSource - 1 do
    begin
      Require(LDefinition.Sources[LOther].Sha256 <> LDefinition.Sources[LSource].Sha256,
        'Duplicate semantic source identity');
      Require((LDefinition.Sources[LOther].GroupId <> LDefinition.Sources[LSource].GroupId) or
        ((LDefinition.Sources[LOther].Split = LDefinition.Sources[LSource].Split) and
        (LDefinition.Sources[LOther].Exposure = LDefinition.Sources[LSource].Exposure)),
        'Recording group crosses declared split or hides exposure');
      if LDefinition.Sources[LOther].OriginSha256 = LDefinition.Sources[LSource].OriginSha256 then
      begin
        Require((LDefinition.Sources[LOther].GroupId = LDefinition.Sources[LSource].GroupId) and
          (LDefinition.Sources[LOther].OriginSampleRate = LDefinition.Sources[LSource].OriginSampleRate) and
          (LDefinition.Sources[LOther].OriginFrameCount = LDefinition.Sources[LSource].OriginFrameCount),
          'Original recording identity has conflicting group or geometry');
      end;
    end;
  end;
  for LSource := 0 to High(LDefinition.Sources) do
  begin
    for LOther := 0 to High(LDefinition.Sources) do
    begin
      if LDefinition.Sources[LSource].OriginSha256 = LDefinition.Sources[LOther].Sha256 then
      begin
        Require((LDefinition.Sources[LOther].OriginSha256 = LDefinition.Sources[LOther].Sha256) and
          (LDefinition.Sources[LSource].GroupId = LDefinition.Sources[LOther].GroupId) and
          (LDefinition.Sources[LSource].OriginSampleRate = LDefinition.Sources[LOther].SampleRate) and
          (LDefinition.Sources[LSource].OriginFrameCount = LDefinition.Sources[LOther].FrameCount),
          'Preparation must map directly to the declared original recording');
      end;
    end;
  end;
  for LRun := 0 to High(LDefinition.Runs) do
  begin
    LSource := LDefinition.Runs[LRun].SourceIndex;
    Require((LSource >= 0) and (LSource < Length(LDefinition.Sources)), 'Run source index is absent');
    Require((Length(LDefinition.Runs[LRun].Identity) in [1..255]) and
      (LDefinition.Runs[LRun].StartFrame >= 0) and
      (LDefinition.Runs[LRun].EndFrame > LDefinition.Runs[LRun].StartFrame) and
      (LDefinition.Runs[LRun].EndFrame <= LDefinition.Sources[LSource].FrameCount),
      'Observed run identity or source interval is invalid');
    for LOther := 0 to LRun - 1 do
    begin
      Require(LDefinition.Runs[LOther].Identity <> LDefinition.Runs[LRun].Identity, 'Duplicate run identity');
    end;
    if LPreviousEnds[LSource] < 0 then
    begin
      Require(LDefinition.Runs[LRun].GapBeforeFrames = 0, 'First run cannot claim a preceding run gap');
    end
    else
    begin
      Require((LDefinition.Runs[LRun].StartFrame >= LPreviousEnds[LSource]) and
        (LDefinition.Runs[LRun].GapBeforeFrames = LDefinition.Runs[LRun].StartFrame - LPreviousEnds[LSource]),
        'Run overlaps or loses its independent gap boundary');
    end;
    LPreviousEnds[LSource] := LDefinition.Runs[LRun].EndFrame;
    LOriginStarts[LRun] := MapOriginPosition(LDefinition.Sources[LSource],
      LDefinition.Runs[LRun].StartFrame);
    LOriginEnds[LRun] := MapOriginPosition(LDefinition.Sources[LSource],
      LDefinition.Runs[LRun].EndFrame);
    Require((Length(LDefinition.Runs[LRun].Tokens) = Length(LDefinition.Providers)) and
      (Length(LDefinition.Runs[LRun].Weights) = Length(LDefinition.Providers)),
      'Observed run must explicitly include or omit every provider');
    for LProvider := 0 to High(LDefinition.Providers) do
    begin
      Require((Length(LDefinition.Runs[LRun].Tokens[LProvider]) = 0) =
        (LDefinition.Runs[LRun].Weights[LProvider] = 0), 'Absent run dimension needs zero contribution');
      if LDefinition.Runs[LRun].Weights[LProvider] > 0 then
      begin
        Require((LDefinition.Sources[LSource].Split = ssTraining) and
          ([seTraining, seVocabulary] <= LDefinition.Sources[LSource].Exposure),
          'Contributing run lacks explicit training/vocabulary exposure');
      end;
    end;
    ValidateRunClock(LDefinition.Runs[LRun], LDefinition.Sources[LSource]);
  end;
  for LRun := 0 to High(LDefinition.Runs) do
  begin
    LSource := LDefinition.Runs[LRun].SourceIndex;
    for LOther := 0 to LRun - 1 do
    begin
      LOtherSource := LDefinition.Runs[LOther].SourceIndex;
      if (LDefinition.Sources[LSource].OriginSha256 <>
        LDefinition.Sources[LOtherSource].OriginSha256) or
        not OriginBefore(LOriginStarts[LRun], LOriginEnds[LOther]) or
        not OriginBefore(LOriginStarts[LOther], LOriginEnds[LRun]) then
      begin
        Continue;
      end;
      for LProvider := 0 to High(LDefinition.Providers) do
      begin
        Require((LDefinition.Runs[LRun].Weights[LProvider] = 0) or
          (LDefinition.Runs[LOther].Weights[LProvider] = 0),
          'Overlapping original material contributes twice to a provider; use explicit run weights');
      end;
    end;
  end;
  LLayers := LoadLayers(LDefinition);
  try
    for LProvider := 0 to High(LLayers) do
    begin
      LContract := LDefinition.Providers[LProvider].Contract;
      ValidateProviderContract(LLayers[LProvider].Model, LContract);
      Require((Length(LDefinition.Providers[LProvider].ExtractionPolicy) > 0) and
        (Length(LDefinition.Providers[LProvider].ExtractionPolicy) <= 4096), 'Provider extraction policy is required');
      Require(LDefinition.Providers[LProvider].VocabularySha256 =
        SemanticVocabularyIdentity(LDefinition.Providers[LProvider].ModelText), 'Frozen provider vocabulary identity differs');
      if LContract.Source.SourceSha256 <> '' then
      begin
        LFound := False;
        for LSource := 0 to High(LDefinition.Sources) do
        begin
          if LDefinition.Sources[LSource].Sha256 = LContract.Source.SourceSha256 then
          begin
            LFound := (LDefinition.Sources[LSource].SampleRate = LContract.Source.SampleRate) and
              (LDefinition.Sources[LSource].FrameCount = LContract.Source.SourceFrames);
          end;
        end;
        Require(LFound, 'Provider source clock is not bound to the source ledger');
      end;
      LSamples := nil;
      LTotal := 0;
      for LRun := 0 to High(LDefinition.Runs) do
      begin
        Inc(LTotal, Int64(Length(LDefinition.Runs[LRun].Tokens[LProvider])) * LDefinition.Runs[LRun].Weights[LProvider]);
        Require((LTotal <= 4096) and
          (LTotal * LTotal * (LLayers[LProvider].Model.Order + 1) <= 16777216),
          'Semantic replay exceeds explicit learning-work budget');
        for LWeight := 1 to LDefinition.Runs[LRun].Weights[LProvider] do
        begin
          LCount := Length(LSamples);
          SetLength(LSamples, LCount + 1);
          LSamples[LCount] := MakeWfcSequenceSample(LDefinition.Runs[LRun].Tokens[LProvider]);
        end;
      end;
      Require(Length(LSamples) > 0, 'Provider has no independently retained training runs');
      LModel := LearnSequenceModelCorpus(LSamples, LLayers[LProvider].Model.Order);
      try
        Require(EncodeWfcSequenceText(LModel) = LDefinition.Providers[LProvider].ModelText,
          'Saved model does not replay exact source/run contributions');
      finally
        LModel.Free;
      end;
    end;
    if LDefinition.NamedVoices then
    begin
      LVoices := AStyle.CreateVoiceSession(731);
      LVoices.Free;
      LConfig := VoiceConfig(LDefinition, LLayers);
      SetLength(LNames, Length(LConfig.Voices));
      for LProvider := 0 to High(LNames) do
      begin
        LNames[LProvider] := LDefinition.Providers[LProvider + 2].Contract.RoleId;
      end;
      for LRun := 0 to High(LDefinition.Runs) do
      begin
        LCount := Length(LDefinition.Runs[LRun].Tokens[0]);
        Require(LCount > 0, 'Named voice observation requires joint harmony/rhythm/role rows');
        LOptions := DefaultVoiceSessionOptions;
        LOptions.CellCount := LCount;
        LOptions.RequireObservedEnd := True;
        LVoices := TNamedVoiceSession.Create(LConfig, LNames, LOptions);
        try
          for LProvider := 0 to High(LLayers) do
          begin
            Require(Length(LDefinition.Runs[LRun].Tokens[LProvider]) = LCount,
              'Named observed joint rows cannot be reconstructed from marginal runs');
            Require(LDefinition.Runs[LRun].Weights[LProvider] = LDefinition.Runs[LRun].Weights[0],
              'Named observed joint rows require matching contribution weights');
            SetLength(LMask, LCount);
            for LCell := 0 to LCount - 1 do
            begin
              Require((RunBoundary(LDefinition.Runs[LRun], LProvider, LCell) =
                RunBoundary(LDefinition.Runs[LRun], 0, LCell)) and
                (RunBoundary(LDefinition.Runs[LRun], LProvider, LCell + 1) =
                RunBoundary(LDefinition.Runs[LRun], 0, LCell + 1)),
                'Named observed joint rows require aligned timing');
              LMask[LCell] := MakeWfcSequenceTokenConstraint(LCell,
                [LDefinition.Runs[LRun].Tokens[LProvider][LCell]]);
            end;
            LVoices.SetConstraints(LVoices.ProviderName(LProvider), LMask);
          end;
          Require(LVoices.TryGenerate(LGenerated, LReport, LProof),
            'Observed joint run violates retained named harmony/rhythm/role relationships');
        finally
          LVoices.Free;
        end;
      end;
    end
    else
    begin
      Require((Length(LDefinition.VoiceRanges) = 0) and (Length(LDefinition.VoicePairs) = 0),
        'Generic style cannot silently ignore named voice constraints');
      LGrid := AStyle.CreateSession(731);
      LGrid.Free;
      for LRun := 0 to High(LDefinition.Runs) do
      begin
        ValidateMappedRun(LDefinition, LLayers, LDefinition.Runs[LRun]);
      end;
      LTotal := 0;
      for LProjection in LDefinition.Projections do
      begin
        for LRule := 0 to High(LProjection.Rules) do
        begin
          for LAlternative := 0 to High(LProjection.Rules[LRule].SourceTokens) do
          begin
            LFound := False;
            for LRun := 0 to High(LDefinition.Runs) do
            begin
              Inc(LTotal, Int64(Length(LDefinition.Runs[LRun].Tokens[LProjection.Provider])) *
                Length(LDefinition.Runs[LRun].Tokens[LProjection.Consumer]));
              Require(LTotal <= 16777216, 'Mapped co-observation audit exceeds work budget');
              if ObservedPair(LDefinition.Runs[LRun], LProjection,
                LProjection.Rules[LRule].SourceTokens[LAlternative], LProjection.Rules[LRule].TargetToken) then
              begin
                LFound := True;
              end;
            end;
            Require(LFound, 'Projection alternative has no retained co-observed run row');
          end;
        end;
      end;
    end;
  finally
    FreeLayers(LLayers);
  end;
  for LProvider := 0 to High(LDefinition.Sounds) do
  begin
    LFound := False;
    for LOther := 0 to High(LDefinition.Providers) do
    begin
      if (LDefinition.Providers[LOther].Contract.Vocabulary = spvVoice) and
        (LDefinition.Providers[LOther].Contract.RoleId = LDefinition.Sounds[LProvider].RoleId) then
      begin
        LFound := True;
      end;
    end;
    Require(LFound, 'Sound binding requires a declared semantic voice role');
    for LOther := 0 to LProvider - 1 do
    begin
      Require(LDefinition.Sounds[LOther].RoleId <> LDefinition.Sounds[LProvider].RoleId, 'Duplicate sound role');
    end;
    Require((Length(LDefinition.Sounds[LProvider].Timbre) > 0) or
      (Length(LDefinition.Sounds[LProvider].Envelope) > 0), 'Empty sound binding must be omitted');
    for LSide := 0 to 1 do
    begin
      if LSide = 0 then
      begin
        LSoundBytes := LDefinition.Sounds[LProvider].Timbre;
      end
      else
      begin
        LSoundBytes := LDefinition.Sounds[LProvider].Envelope;
      end;
      if Length(LSoundBytes) = 0 then
      begin
        Continue;
      end;
      LSound := DecodeWaveStyle(LSoundBytes);
      try
        Require(((LSide = 0) and LSound.HasTimbre) or ((LSide = 1) and LSound.HasEnvelope),
          'Embedded sound profile lacks requested capability');
        ValidateSoundAncestry(LSound, LDefinition.Sources, 1);
      finally
        LSound.Free;
      end;
    end;
  end;
end;

procedure TSemanticStyle.Finish(const ADefinition: TSemanticStyleDefinition; const AParent: TAudioBytes);
var
  LIO: TStyleIO;
  LBody: TAudioBytes;
begin
  FDefinition := ReadDefinition(DefinitionBytes(ADefinition));
  ValidateDefinition(Self);
  LIO := TStyleIO.Create(nil, False);
  try
    LIO.Text('pythian.semantic.style.v1');
    LIO.Blob(AParent);
    LIO.Blob(DefinitionBytes(FDefinition));
    LBody := LIO.Bytes;
    LIO.Text(Sha256Bytes(LBody));
    FBytes := LIO.Bytes;
    FIdentity := Sha256Bytes(FBytes);
  finally
    LIO.Free;
  end;
end;

constructor TSemanticStyle.CreateSource(const ADefinition: TSemanticStyleDefinition);
var
  LProvider: Integer;
begin
  inherited Create;
  for LProvider := 0 to High(ADefinition.Providers) do
  begin
    Require(ADefinition.Providers[LProvider].VocabularyAncestor = '',
      'Source style must establish its own frozen vocabulary ancestry');
  end;
  FDepth := 1;
  Finish(ADefinition, nil);
end;

constructor TSemanticStyle.CreateDerived(const AParent: TSemanticStyle;
  const ADefinition: TSemanticStyleDefinition);
var
  LBaseline: TSemanticStyleDefinition;
  LCandidate: TSemanticStyleDefinition;
  LIndex: Integer;
begin
  inherited Create;
  Require((AParent <> nil) and (AParent.Depth < 8), 'Semantic derivation requires parent and depth below eight');
  LBaseline := AParent.CopyDefinition;
  LCandidate := ReadDefinition(DefinitionBytes(ADefinition));
  Require(Length(LCandidate.Providers) = Length(LBaseline.Providers), 'Derived provider inventory differs');
  for LIndex := 0 to High(LCandidate.Providers) do
  begin
    LBaseline.Providers[LIndex].Preferences := nil;
    LBaseline.Providers[LIndex].Constraints := nil;
    LBaseline.Providers[LIndex].VocabularyAncestor := '';
    LCandidate.Providers[LIndex].Preferences := nil;
    LCandidate.Providers[LIndex].Constraints := nil;
    LCandidate.Providers[LIndex].VocabularyAncestor := '';
  end;
  Require(Sha256Bytes(DefinitionBytes(LBaseline)) = Sha256Bytes(DefinitionBytes(LCandidate)),
    'Preference/lock derivation cannot rewrite evidence, models, vocabulary, sound or dependencies');
  LCandidate := ReadDefinition(DefinitionBytes(ADefinition));
  for LIndex := 0 to High(LCandidate.Providers) do
  begin
    LCandidate.Providers[LIndex].VocabularyAncestor := AParent.Identity;
  end;
  FDepth := AParent.Depth + 1;
  Finish(LCandidate, AParent.Encode);
end;

function TSemanticStyle.CopyDefinition: TSemanticStyleDefinition;
begin
  Result := ReadDefinition(DefinitionBytes(FDefinition));
end;

function TSemanticStyle.Encode: TAudioBytes;
begin
  Result := Copy(FBytes);
end;

function DecodeAt(const ABytes: TAudioBytes; const ADepth: Integer): TSemanticStyle;
var
  LIO: TStyleIO;
  LParentBytes: TAudioBytes;
  LDefinitionBytes: TAudioBytes;
  LDefinition: TSemanticStyleDefinition;
  LHash: String;
  LBodyLength: Integer;
  LParent: TSemanticStyle;
  LResult: TSemanticStyle;
begin
  Require(ADepth <= 8, 'Semantic ancestry exceeds eight nodes');
  LIO := TStyleIO.Create(ABytes, True);
  LParent := nil;
  LResult := nil;
  try
    Require(LIO.Text = 'pythian.semantic.style.v1', 'Unsupported semantic format; regenerate development artifact');
    LParentBytes := LIO.Blob(nil);
    LDefinitionBytes := LIO.Blob(nil);
    LBodyLength := LIO.FStream.Position;
    LHash := LIO.Text;
    LIO.EndOfInput;
    Require(LHash = Sha256Bytes(Copy(ABytes, 0, LBodyLength)), 'Semantic payload digest mismatch');
    LDefinition := ReadDefinition(LDefinitionBytes);
    if Length(LParentBytes) = 0 then
    begin
      LResult := TSemanticStyle.CreateSource(LDefinition);
    end
    else
    begin
      LParent := DecodeAt(LParentBytes, ADepth + 1);
      LResult := TSemanticStyle.CreateDerived(LParent, LDefinition);
    end;
    Require(Sha256Bytes(LResult.Encode) = Sha256Bytes(ABytes), 'Noncanonical semantic archive or ancestry');
    Result := LResult;
    LResult := nil;
  finally
    LResult.Free;
    LParent.Free;
    LIO.Free;
  end;
end;

function DecodeSemanticStyle(const ABytes: TAudioBytes): TSemanticStyle;
begin
  Result := DecodeAt(ABytes, 1);
end;

function TSemanticStyle.CreateInstrument(const ARoleId: String;
  const AZones: TStyleInstrumentZones; const ASampleRate: Integer): TStyleInstrument;
var
  LIndex: Integer;
  LZone: Integer;
  LZones: TStyleInstrumentZones;
  LTimbre: TWaveStyleProfile;
  LEnvelope: TWaveStyleProfile;
begin
  for LIndex := 0 to High(FDefinition.Sounds) do
  begin
    if FDefinition.Sounds[LIndex].RoleId <> ARoleId then
    begin
      Continue;
    end;
    LTimbre := nil;
    LEnvelope := nil;
    try
      if Length(FDefinition.Sounds[LIndex].Timbre) > 0 then
      begin
        LTimbre := DecodeWaveStyle(FDefinition.Sounds[LIndex].Timbre);
      end;
      if Length(FDefinition.Sounds[LIndex].Envelope) > 0 then
      begin
        LEnvelope := DecodeWaveStyle(FDefinition.Sounds[LIndex].Envelope);
      end;
      LZones := Copy(AZones);
      for LZone := 0 to High(LZones) do
      begin
        Require((LZones[LZone].Timbre = nil) and (LZones[LZone].Envelope = nil),
          'Explicit semantic sound binding cannot silently override supplied profile selections');
        LZones[LZone].Timbre := LTimbre;
        LZones[LZone].Envelope := LEnvelope;
      end;
      Result := TStyleInstrument.Create(LZones, ASampleRate);
      Exit;
    finally
      LTimbre.Free;
      LEnvelope.Free;
    end;
  end;
  raise EAudio.Create('Semantic style has no saved sound binding for role');
end;

end.
