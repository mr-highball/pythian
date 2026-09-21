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

unit pythian.wfc.style;

{$mode delphi}
{$H+}

interface

uses
  pythian.audio,
  pythian.time,
  pythian.music.grid.frames,
  pythian.analysis,
  pythian.corpus,
  pythian.passage,
  pythian.rhythm.admission,
  pythian.onset.dynamics,
  pythian.pitch,
  pythian.pitch.cells,
  pythian.pitch.track,
  pythian.source.wavetable,
  pythian.automation,
  pythian.envelope,
  pythian.wfc.context.profile,
  pythian.wfc.layers,
  wfc_sequence;

const
  WaveStyleVersion = 1;
  MaximumStyleBytes = 32 * 1024 * 1024;
  MaximumStyleSources = 32;
  MaximumStyleDepth = 8;
  MaximumStyleNodes = 63;
  MaximumStyleWeight = 64;
  MaximumStyleCells = 65536;
  RhythmOnsetToken = 'pythian.rhythm.onset.v1.1';
  RhythmEmptyToken = 'pythian.rhythm.onset.v1.0';

type
  TStylePreferenceProvider = (sppKey, sppTempo, sppPerformance,
    sppRhythm, sppIntensity, sppPitch, sppPitchRhythm);
  TStyleGenerationPreferences = array[TStylePreferenceProvider] of TLayerTokenPreferences;
  TEnvelopeStyleEvidence = record
    StartFrame: Integer;
    FrameCount: Integer;
    Channel: Integer;
    WindowFrames: Integer;
    GateFrame: Integer;
    MaximumTailRatio: Double;
    MinimumRms: Double;
    Policy: UTF8String;
    RmsPoints: TAutomationPoints;
  end;

  THarmonicStyleEvidence = record
    StartFrame: Integer;
    FrameCount: Integer; { Zero means unavailable. }
    Channel: Integer;
    MaximumRelativeError: Double;
    MinimumAcRms: Double;
    Policy: UTF8String;
    Fit: THarmonicFit;
  end;
  THarmonicStyleKnots = array of THarmonicStyleEvidence;
  TTimbreTrajectoryEvidence = record
    OriginFrame: Integer; { Caller-declared note-relative time zero in the source. }
    Knots: THarmonicStyleKnots; { Ordered by window center; empty means unavailable. }
  end;

  TRhythmStyleEvidence = record
    Source: TAcousticSourceInfo;
    OnsetReportSha256: String;
    Analysis: TAnalysisOptions;
    OnsetVersion: Integer;
    Policy: UTF8String;
    TempoMicroseconds: Integer;
    SourceStartTick: Integer;
    SourceFrameOffset: Integer;
    SourceCellCount: Integer; { Zero with empty changes requests the complete constant-clock scope. }
    SourceClock: TTempoChanges; { Explicit finite source clock, including any prefix history. }
    MaximumErrorFrames: Integer;
    OnsetFrames: TPassageBounds;
    Dynamics: TOnsetDynamics;
    Pitch: TPitchCellEvidence;
    Duration: TPitchTrackEvidence;
    DurationArticulateOnsets: Boolean; { Explicit source-onset ownership in known pitch spans. }
    Timbre: THarmonicStyleEvidence;
    TimbreTrajectory: TTimbreTrajectoryEvidence;
    Envelope: TEnvelopeStyleEvidence;
  end;

  { Owns admitted evidence, selected context and actual weighted WFC models.
    Rhythm/joint intensity and pitch have separate source-weight vectors.
    Each source remains an independent training sample. Integer relative weights
    repeat samples, not concatenate recordings.
    Full ordered parent archives preserve repeated derivation. This is measured
    onset behavior and optional monophonic duration evidence, not isolated voices
    or complete musical style. }
  TWaveStyleProfile = class
  private
    FContext: TContextProfile;
    FEvidence: array of TRhythmStyleEvidence;
    FAdmissions: array of TRhythmAdmission;
    FRhythmWeights: array of Integer;
    FPitchWeights: array of Integer;
    FTimbreWeights: array of Integer;
    FHasTimbre: Boolean;
    FHasTimbreTrajectory: Boolean;
    FEnvelopeWeights: array of Integer;
    FHasEnvelope: Boolean;
    FModel: TWfcSequenceModel;
    FJointModel: TWfcSequenceModel;
    FPitchModel: TWfcSequenceModel;
    FPitchRhythmModel: TWfcSequenceModel;
    FDurationModel: TWfcSequenceModel;
    FHasDuration: Boolean;
    FHasDynamics: Boolean;
    FHasPitch: Boolean;
    FHasPitchRhythm: Boolean;
    FOrder: Integer;
    FDepth: Integer;
    FNodeCount: Integer;
    FBytes: TAudioBytes;
    FIdentity: String;
    FParentIds: array[0..1] of String;
    FGenerationPreferences: TStyleGenerationPreferences;
    procedure AssignGenerationPreferences(const APreferences: TStyleGenerationPreferences);
    procedure SavePreferred(const AParent: TWaveStyleProfile);
    procedure InheritGenerationPreferences(const ALeft, ARight: TWaveStyleProfile;
      const AKeySide, ATempoSide, ALeftRhythmWeight, ARightRhythmWeight,
      ALeftPitchWeight, ARightPitchWeight: Integer);
    procedure Learn;
    procedure SaveSource;
    procedure SaveBlend(const ALeft, ARight: TWaveStyleProfile;
      const AKeySide, ATempoSide, ALeftWeight, ARightWeight,
      ALeftPitchWeight, ARightPitchWeight, ALeftTimbreWeight, ARightTimbreWeight,
      ALeftEnvelopeWeight, ARightEnvelopeWeight: Integer);
    procedure BuildBlend(const ALeft, ARight: TWaveStyleProfile;
      const AKeySide, ATempoSide, ALeftWeight, ARightWeight,
      ALeftPitchWeight, ARightPitchWeight, ALeftTimbreWeight, ARightTimbreWeight: Integer;
      const ALeftEnvelopeWeight: Integer = -1; const ARightEnvelopeWeight: Integer = -1);
    function GetSourceCount: Integer;
  public
    constructor CreateSource(const AContext: TContextProfile;
      const AEvidence: TRhythmStyleEvidence; const AOrder: Integer = 3);
    { Complete replacement of output preferences, not training weights.
      Owns a detached definition and retains the parent archive in its lineage. }
    constructor CreatePreferred(const AParent: TWaveStyleProfile;
      const APreferences: TStyleGenerationPreferences);
    function CopyGenerationPreferences: TStyleGenerationPreferences;
    function HasGenerationPreferences: Boolean;
    constructor CreateBlend(const ALeft, ARight: TWaveStyleProfile;
      const AKeySide, ATempoSide, ALeftWeight, ARightWeight: Integer);
    { Rhythm weights also govern its observed joint intensity model.
      Pitch weights are independent; both zero explicitly omits generated pitch. }
    constructor CreateBlendDimensions(const ALeft, ARight: TWaveStyleProfile;
      const AKeySide, ATempoSide, ALeftRhythmWeight, ARightRhythmWeight,
      ALeftPitchWeight, ARightPitchWeight: Integer);
    { Independent stationary timbre weights; both zero omit timbre. Existing
      convenience blends follow rhythm weights when any selected parent has it. }
    constructor CreateBlendLayers(const ALeft, ARight: TWaveStyleProfile;
      const AKeySide, ATempoSide, ALeftRhythmWeight, ARightRhythmWeight,
      ALeftPitchWeight, ARightPitchWeight, ALeftTimbreWeight, ARightTimbreWeight: Integer;
      const ALeftEnvelopeWeight: Integer = -1; const ARightEnvelopeWeight: Integer = -1);
    destructor Destroy; override;
    function CopyContext: TContextProfile;
    function CopyRhythmModel: TWfcSequenceModel;
    function CopyIntensityModel: TWfcSequenceModel;
    function CopyPitchModel: TWfcSequenceModel;
    function CopyPitchRhythmModel: TWfcSequenceModel;
    function CopyDurationModel: TWfcSequenceModel;
    function CopyDurationTrack(const AIndex: Integer): TPitchTrack;
    { Scoped source-frame endpoints map to the first PPQ tick whose floor frame
      reaches that boundary. Round endpoints, never each duration. }
    function CopyTimedDurationSpans(const AIndex: Integer): TTimedPitchSpans;
    function DurationTicksPerQuarter: Integer;
    function PitchNotesAt(const AIndex: Integer): TPitchNotes;
    function IntensityPatternAt(const AIndex: Integer): String;
    function EvidenceAt(const AIndex: Integer): TRhythmStyleEvidence;
    function AdmissionAt(const AIndex: Integer): TRhythmAdmission;
    function RhythmWeightAt(const AIndex: Integer): Integer;
    function PitchWeightAt(const AIndex: Integer): Integer;
    function TimbreWeightAt(const AIndex: Integer): Integer;
    { Weighted mean harmonic magnitudes, all rendered with sine phase zero.
      Missing measured higher harmonics contribute zero. No loudness scaling,
      DC, recording phase, attack envelope or inferred role is transferred. }
    function CopyTimbreRecipe: TWavetableCycleRecipe;
    { Static styles keep their existing magnitude/amplitude recipe. If any active
      source has a trajectory, all contributing spectra become unit-RMS magnitude
      shapes. Their independently normalized shapes are averaged with timbre
      weights on the union of output-frame knots, then continuously normalized by
      the magnitude source. No time stretching or measured envelope is applied.
      Output is bounded to 32 union knots; caller owns the detached factory. }
    function CopyTimbreFactory(const AOutputRate: Integer;
      const ATrajectoryRms: Double = 0.1): TWavetableSourceFactory;
    function EnvelopeWeightAt(const AIndex: Integer): Integer;
    { Peak-normalized held levels and gate-relative release shapes are averaged
      independently on the union of retimed frame knots. No time stretching. }
    function CopyGateEnvelope(const AOutputRate: Integer): TGateEnvelope;
    function ParentIdentity(const ASide: Integer): String;
    function Encode: TAudioBytes;
    property Identity: String read FIdentity;
    property SourceCount: Integer read GetSourceCount;
    property Order: Integer read FOrder;
    property Depth: Integer read FDepth;
    property NodeCount: Integer read FNodeCount;
    property HasDynamics: Boolean read FHasDynamics;
    property HasPitch: Boolean read FHasPitch;
    property HasPitchRhythm: Boolean read FHasPitchRhythm;
    property HasDuration: Boolean read FHasDuration;
    property HasTimbre: Boolean read FHasTimbre;
    property HasTimbreTrajectory: Boolean read FHasTimbreTrajectory;
    property HasEnvelope: Boolean read FHasEnvelope;
  end;

{ Checks bounded ancestry, digests, source clock binding, native quantization
  replay and canonical actual weighted model text before publishing a result.
  Does not reopen source WAV/onset files or execute descriptive policies. }
function DecodeWaveStyle(const ABytes: TAudioBytes): TWaveStyleProfile;
function StyleIntensityToken(const ABand: Integer): UTF8String;
function DecodeStyleIntensityToken(const AToken: UTF8String): Integer;

{ Caller owns the detached exact clock/grid. Explicit clocks retain finite scope;
  the constant-clock shorthand keeps the complete-source admission contract. }
function CreateStyleSourceClock(const AEvidence: TRhythmStyleEvidence;
  const APpq, AStep: Integer): TTempoMap;
function CreateStyleSourceGrid(const AEvidence: TRhythmStyleEvidence;
  const APpq, AStep: Integer): TMusicGridFrames;

implementation

uses
  Classes,
  SysUtils,
  Math,
  pythian.hash,
  pythian.tonal,
  pythian.music.context,
  pythian.music.context.admission,
  pythian.onset,
  pythian.wfc.pitch,
  pythian.wfc.context,
  pythian.wfc.context.archive,
  wfc_model,
  wfc_sequence_learn,
  wfc_sequence_text;

const
  StyleMagic = $54535950; { PYST, current development format only }
  StyleDynamicsCapability = 1;
  StylePitchCapability = 2;
  StyleDurationCapability = 4;
  StyleDurationOnsetsCapability = 8;
  StyleTimbreCapability = 16;
  StyleEnvelopeCapability = 32;
  StyleTrajectoryCapability = 64;
  IntensityPrefix = 'pythian.rhythm.intensity.v1.';

type
  TStyleCursor = record
    Bytes: TAudioBytes;
    Offset: Integer;
    Limit: Integer;
    procedure Need(const ACount: Integer);
    function Number: Integer;
    function Blob(const AMaximum: Integer): TAudioBytes;
    function Text(const AMaximum: Integer): UTF8String;
    function RealValue: Double;
  end;

function CreateStyleSourceClock(const AEvidence: TRhythmStyleEvidence;
  const APpq, AStep: Integer): TTempoMap;
var
  LScope: TWaveContextScope;
  LCount: Integer;
  LChanges: TTempoChanges;
  LEnd: Int64;
begin
  if Length(AEvidence.SourceClock) = 0 then
  begin
    if (AEvidence.SourceCellCount <> 0) or (AEvidence.SourceFrameOffset <> 0) then
    begin
      raise EAudio.Create('A finite or offset source grid requires an explicit tempo map');
    end;
    LScope := WaveContextScope(AEvidence.Source.SampleRate, AEvidence.Source.FrameCount,
      AEvidence.TempoMicroseconds, APpq, AStep, MakeKeyContext(-1, dmMajor),
      AEvidence.SourceStartTick);
    LCount := Length(LScope.Grid.Keys);
    LChanges := [MakeTempoChange(0, AEvidence.TempoMicroseconds)];
  end
  else
  begin
    LCount := AEvidence.SourceCellCount;
    LChanges := AEvidence.SourceClock;
    if (LCount < 1) or (LCount > MaximumStyleCells) or (AStep < 1) or
      (AEvidence.SourceStartTick < 0) or
      (LChanges[0].MicrosecondsPerQuarter <> AEvidence.TempoMicroseconds) then
    begin
      raise EAudio.Create('Explicit style source clock requires bounded cells and matching initial tempo');
    end;
  end;
  LEnd := Int64(AEvidence.SourceStartTick) + Int64(LCount) * AStep;
  if LEnd > High(Integer) then
  begin
    raise EAudio.Create('Style source clock exceeds tick extent');
  end;
  Result := TTempoMap.Create(APpq, LEnd, LChanges);
end;

function CreateStyleSourceGrid(const AEvidence: TRhythmStyleEvidence;
  const APpq, AStep: Integer): TMusicGridFrames;
var
  LClock: TTempoMap;
begin
  LClock := CreateStyleSourceClock(AEvidence, APpq, AStep);
  try
    Result := TMusicGridFrames.Create(LClock, AEvidence.Source.SampleRate,
      AEvidence.Source.FrameCount, AEvidence.SourceFrameOffset, AEvidence.SourceStartTick,
      AStep, (LClock.LengthTicks - AEvidence.SourceStartTick) div AStep);
  finally
    LClock.Free;
  end;
end;

function StyleIntensityToken(const ABand: Integer): UTF8String;
begin
  if not (ABand in [0..4]) then
  begin
    raise EAudio.Create('Style intensity band must be 0..4');
  end;
  Result := IntensityPrefix + UTF8String(IntToStr(ABand));
end;

function DecodeStyleIntensityToken(const AToken: UTF8String): Integer;
begin
  for Result := 0 to 4 do
  begin
    if AToken = StyleIntensityToken(Result) then
    begin
      Exit;
    end;
  end;
  raise EAudio.Create('Unknown style intensity token');
end;

procedure PutNumber(const AStream: TMemoryStream; const AValue: Integer);
var
  LBytes: array[0..3] of Byte;
  LIndex: Integer;
begin
  if (AValue < 0) or (AStream.Size > MaximumStyleBytes - 68) then
  begin
    raise EAudio.Create('Style integer/archive exceeds bounds');
  end;
  for LIndex := 0 to 3 do
  begin
    LBytes[LIndex] := (Cardinal(AValue) shr (8 * LIndex)) and $FF;
  end;
  AStream.WriteBuffer(LBytes[0], 4);
end;

procedure PutBlob(const AStream: TMemoryStream; const ABytes: TAudioBytes);
begin
  if AStream.Size + Length(ABytes) > MaximumStyleBytes - 68 then
  begin
    raise EAudio.Create('Style archive exceeds 32 MiB');
  end;
  PutNumber(AStream, Length(ABytes));
  if Length(ABytes) > 0 then
  begin
    AStream.WriteBuffer(ABytes[0], Length(ABytes));
  end;
end;

procedure PutText(const AStream: TMemoryStream; const AText: UTF8String);
var
  LBytes: TAudioBytes;
begin
  SetLength(LBytes, Length(AText));
  if Length(AText) > 0 then
  begin
    Move(AText[1], LBytes[0], Length(AText));
  end;
  PutBlob(AStream, LBytes);
end;

function FinishArchive(const AStream: TMemoryStream): TAudioBytes;
var
  LBytes: TAudioBytes;
  LHash: String;
  LSize: Integer;
begin
  LSize := Integer(AStream.Size);
  SetLength(LBytes, LSize);
  if LSize > 0 then
  begin
    Move(AStream.Memory^, LBytes[0], LSize);
  end;
  LHash := Sha256Bytes(LBytes);
  SetLength(LBytes, LSize + 64);
  Move(LHash[1], LBytes[LSize], 64);
  Result := LBytes;
end;

procedure PutReal(const AStream: TMemoryStream; const AValue: Double);
var
  LBits: QWord;
  LBytes: TAudioBytes;
  LIndex: Integer;
begin
  RequireFinite(AValue, 'Style analysis threshold');
  Move(AValue, LBits, 8);
  SetLength(LBytes, 8);
  for LIndex := 0 to 7 do
  begin
    LBytes[LIndex] := (LBits shr (8 * LIndex)) and $FF;
  end;
  PutBlob(AStream, LBytes);
end;

procedure TStyleCursor.Need(const ACount: Integer);
begin
  if (ACount < 0) or (ACount > Limit - Offset) then
  begin
    raise EAudio.Create('Style field exceeds payload');
  end;
end;

function TStyleCursor.Number: Integer;
var
  LBits: Cardinal;
  LIndex: Integer;
begin
  Need(4);
  LBits := 0;
  for LIndex := 0 to 3 do
  begin
    LBits := LBits or (Cardinal(Bytes[Offset + LIndex]) shl (8 * LIndex));
  end;
  Inc(Offset, 4);
  if LBits > High(Integer) then
  begin
    raise EAudio.Create('Style integer exceeds signed range');
  end;
  Result := Integer(LBits);
end;

function TStyleCursor.Blob(const AMaximum: Integer): TAudioBytes;
var
  LCount: Integer;
begin
  LCount := Number;
  if LCount > AMaximum then
  begin
    raise EAudio.Create('Style field exceeds declared budget');
  end;
  Need(LCount);
  Result := Copy(Bytes, Offset, LCount);
  Inc(Offset, LCount);
end;

function TStyleCursor.Text(const AMaximum: Integer): UTF8String;
var
  LBytes: TAudioBytes;
begin
  LBytes := Blob(AMaximum);
  Result := '';
  SetLength(Result, Length(LBytes));
  if Length(LBytes) > 0 then
  begin
    Move(LBytes[0], Result[1], Length(LBytes));
  end;
end;

function TStyleCursor.RealValue: Double;
var
  LBytes: TAudioBytes;
  LBits: QWord;
  LIndex: Integer;
begin
  LBytes := Blob(8);
  if Length(LBytes) <> 8 then
  begin
    raise EAudio.Create('Style real field requires eight bytes');
  end;
  LBits := 0;
  for LIndex := 0 to 7 do
  begin
    LBits := LBits or (QWord(LBytes[LIndex]) shl (8 * LIndex));
  end;
  if (LBits and QWord($7FF0000000000000)) = QWord($7FF0000000000000) then
  begin
    raise EAudio.Create('Nonfinite style analysis threshold');
  end;
  Move(LBits, Result, 8);
end;

procedure PutHarmonicEvidence(const AStream: TMemoryStream; const AEvidence: THarmonicStyleEvidence);
var
  LIndex: Integer;
begin
  PutNumber(AStream, AEvidence.StartFrame);
  PutNumber(AStream, AEvidence.FrameCount);
  PutNumber(AStream, AEvidence.Channel);
  PutReal(AStream, AEvidence.MaximumRelativeError);
  PutReal(AStream, AEvidence.MinimumAcRms);
  PutText(AStream, AEvidence.Policy);
  PutReal(AStream, AEvidence.Fit.FrequencyHz);
  PutReal(AStream, AEvidence.Fit.AcRms);
  PutReal(AStream, AEvidence.Fit.ResidualRms);
  PutReal(AStream, AEvidence.Fit.RelativeError);
  PutReal(AStream, AEvidence.Fit.Recipe.Mean);
  PutNumber(AStream, Length(AEvidence.Fit.Recipe.Sine));
  for LIndex := 0 to High(AEvidence.Fit.Recipe.Sine) do
  begin
    PutReal(AStream, AEvidence.Fit.Recipe.Sine[LIndex]);
    PutReal(AStream, AEvidence.Fit.Recipe.Cosine[LIndex]);
  end;
end;

function ReadHarmonicEvidence(var ACursor: TStyleCursor): THarmonicStyleEvidence;
var
  LEvidence: THarmonicStyleEvidence;
  LCount: Integer;
  LIndex: Integer;
begin
  LEvidence := Default(THarmonicStyleEvidence);
  LEvidence.StartFrame := ACursor.Number;
  LEvidence.FrameCount := ACursor.Number;
  if LEvidence.FrameCount = 0 then
  begin
    raise EAudio.Create('Present timbre requires a measured interval');
  end;
  LEvidence.Channel := ACursor.Number;
  LEvidence.MaximumRelativeError := ACursor.RealValue;
  LEvidence.MinimumAcRms := ACursor.RealValue;
  LEvidence.Policy := ACursor.Text(4096);
  LEvidence.Fit.FrequencyHz := ACursor.RealValue;
  LEvidence.Fit.AcRms := ACursor.RealValue;
  LEvidence.Fit.ResidualRms := ACursor.RealValue;
  LEvidence.Fit.RelativeError := ACursor.RealValue;
  LEvidence.Fit.Recipe.Mean := ACursor.RealValue;
  LCount := ACursor.Number;
  if (LCount < 1) or (LCount > MaximumTableHarmonics) then
  begin
    raise EAudio.Create('Timbre harmonic count exceeds bounds');
  end;
  ACursor.Need(LCount * 16);
  SetLength(LEvidence.Fit.Recipe.Sine, LCount);
  SetLength(LEvidence.Fit.Recipe.Cosine, LCount);
  for LIndex := 0 to LCount - 1 do
  begin
    LEvidence.Fit.Recipe.Sine[LIndex] := ACursor.RealValue;
    LEvidence.Fit.Recipe.Cosine[LIndex] := ACursor.RealValue;
  end;
  Result := LEvidence;
end;

procedure PutEvidence(const AStream: TMemoryStream; const AEvidence: TRhythmStyleEvidence);
var
  LIndex: Integer;
begin
  PutNumber(AStream, Ord(AEvidence.Dynamics.WindowFrames > 0) * StyleDynamicsCapability +
    Ord(AEvidence.Pitch.WindowFrames > 0) * StylePitchCapability +
    Ord(AEvidence.Duration.WindowFrames > 0) * StyleDurationCapability +
    Ord(AEvidence.DurationArticulateOnsets) * StyleDurationOnsetsCapability +
    Ord(AEvidence.Timbre.FrameCount > 0) * StyleTimbreCapability +
    Ord(AEvidence.Envelope.FrameCount > 0) * StyleEnvelopeCapability +
    Ord(Length(AEvidence.TimbreTrajectory.Knots) > 0) * StyleTrajectoryCapability);
  PutText(AStream, AEvidence.Source.Name);
  PutText(AStream, AEvidence.Source.Sha256);
  PutText(AStream, AEvidence.Source.Provenance);
  PutNumber(AStream, AEvidence.Source.SampleRate);
  PutNumber(AStream, AEvidence.Source.Channels);
  PutNumber(AStream, AEvidence.Source.FrameCount);
  PutText(AStream, AEvidence.OnsetReportSha256);
  PutNumber(AStream, AEvidence.Analysis.WindowFrames);
  PutNumber(AStream, AEvidence.Analysis.HopFrames);
  PutReal(AStream, AEvidence.Analysis.SilenceRms);
  PutNumber(AStream, AEvidence.OnsetVersion);
  PutText(AStream, AEvidence.Policy);
  PutNumber(AStream, AEvidence.TempoMicroseconds);
  PutNumber(AStream, AEvidence.SourceStartTick);
  PutNumber(AStream, AEvidence.SourceFrameOffset);
  PutNumber(AStream, AEvidence.SourceCellCount);
  PutNumber(AStream, Length(AEvidence.SourceClock));
  for LIndex := 0 to High(AEvidence.SourceClock) do
  begin
    PutNumber(AStream, AEvidence.SourceClock[LIndex].Tick);
    PutNumber(AStream, AEvidence.SourceClock[LIndex].MicrosecondsPerQuarter);
  end;
  PutNumber(AStream, AEvidence.MaximumErrorFrames);
  PutNumber(AStream, Length(AEvidence.OnsetFrames));
  for LIndex := 0 to High(AEvidence.OnsetFrames) do
  begin
    PutNumber(AStream, AEvidence.OnsetFrames[LIndex]);
  end;
  if AEvidence.Dynamics.WindowFrames > 0 then
  begin
    PutNumber(AStream, OnsetDynamicsVersion);
    PutNumber(AStream, AEvidence.Dynamics.WindowFrames);
    for LIndex := 0 to High(AEvidence.Dynamics.Rms) do
    begin
      PutReal(AStream, AEvidence.Dynamics.Rms[LIndex]);
    end;
  end;
  if AEvidence.Pitch.WindowFrames > 0 then
  begin
    PutNumber(AStream, PitchCellsVersion);
    PutNumber(AStream, PitchEstimatorVersion);
    PutNumber(AStream, AEvidence.Pitch.WindowFrames);
    PutNumber(AStream, AEvidence.Pitch.Channel);
    PutReal(AStream, AEvidence.Pitch.Options.MinimumHz);
    PutReal(AStream, AEvidence.Pitch.Options.MaximumHz);
    PutReal(AStream, AEvidence.Pitch.Options.DifferenceThreshold);
    PutReal(AStream, AEvidence.Pitch.Options.SilenceRms);
    PutReal(AStream, AEvidence.Pitch.MaximumCents);
    PutNumber(AStream, Length(AEvidence.Pitch.Cells));
    for LIndex := 0 to High(AEvidence.Pitch.Cells) do
    begin
      PutNumber(AStream, Ord(AEvidence.Pitch.Cells[LIndex].Measured));
      if AEvidence.Pitch.Cells[LIndex].Measured then
      begin
        PutNumber(AStream, Ord(AEvidence.Pitch.Cells[LIndex].Estimate.Status));
        PutReal(AStream, AEvidence.Pitch.Cells[LIndex].Estimate.FrequencyHz);
        PutReal(AStream, AEvidence.Pitch.Cells[LIndex].Estimate.PeriodFrames);
        PutReal(AStream, AEvidence.Pitch.Cells[LIndex].Estimate.NormalizedDifference);
        PutReal(AStream, AEvidence.Pitch.Cells[LIndex].Estimate.AcRms);
        PutReal(AStream, AEvidence.Pitch.Cells[LIndex].Estimate.CentsError);
        PutNumber(AStream, AEvidence.Pitch.Cells[LIndex].Estimate.NearestMidi + 1024);
      end;
    end;
  end;
  if AEvidence.Duration.WindowFrames > 0 then
  begin
    PutNumber(AStream, PitchEstimatorVersion);
    PutNumber(AStream, AEvidence.Duration.WindowFrames);
    PutNumber(AStream, AEvidence.Duration.Channel);
    PutNumber(AStream, AEvidence.Duration.Options.HopFrames);
    PutNumber(AStream, AEvidence.Duration.Options.MinimumRunWindows);
    PutReal(AStream, AEvidence.Duration.Options.MaximumCents);
    PutReal(AStream, AEvidence.Duration.Options.Pitch.MinimumHz);
    PutReal(AStream, AEvidence.Duration.Options.Pitch.MaximumHz);
    PutReal(AStream, AEvidence.Duration.Options.Pitch.DifferenceThreshold);
    PutReal(AStream, AEvidence.Duration.Options.Pitch.SilenceRms);
    PutNumber(AStream, Length(AEvidence.Duration.Estimates));
    for LIndex := 0 to High(AEvidence.Duration.Estimates) do
    begin
      PutNumber(AStream, Ord(AEvidence.Duration.Estimates[LIndex].Status));
      PutReal(AStream, AEvidence.Duration.Estimates[LIndex].FrequencyHz);
      PutReal(AStream, AEvidence.Duration.Estimates[LIndex].PeriodFrames);
      PutReal(AStream, AEvidence.Duration.Estimates[LIndex].NormalizedDifference);
      PutReal(AStream, AEvidence.Duration.Estimates[LIndex].AcRms);
      PutReal(AStream, AEvidence.Duration.Estimates[LIndex].CentsError);
      PutNumber(AStream, AEvidence.Duration.Estimates[LIndex].NearestMidi + 1024);
    end;
  end;
  if AEvidence.Timbre.FrameCount > 0 then
  begin
    PutHarmonicEvidence(AStream, AEvidence.Timbre);
  end;
  if AEvidence.Envelope.FrameCount > 0 then
  begin
    PutNumber(AStream, AEvidence.Envelope.StartFrame);
    PutNumber(AStream, AEvidence.Envelope.FrameCount);
    PutNumber(AStream, AEvidence.Envelope.Channel);
    PutNumber(AStream, AEvidence.Envelope.WindowFrames);
    PutNumber(AStream, AEvidence.Envelope.GateFrame);
    PutReal(AStream, AEvidence.Envelope.MaximumTailRatio);
    PutReal(AStream, AEvidence.Envelope.MinimumRms);
    PutText(AStream, AEvidence.Envelope.Policy);
    PutNumber(AStream, Length(AEvidence.Envelope.RmsPoints));
    for LIndex := 0 to High(AEvidence.Envelope.RmsPoints) do
    begin
      PutNumber(AStream, AEvidence.Envelope.RmsPoints[LIndex].Frame);
      PutReal(AStream, AEvidence.Envelope.RmsPoints[LIndex].Value);
    end;
  end;
  if Length(AEvidence.TimbreTrajectory.Knots) > 0 then
  begin
    PutNumber(AStream, AEvidence.TimbreTrajectory.OriginFrame);
    PutNumber(AStream, Length(AEvidence.TimbreTrajectory.Knots));
    for LIndex := 0 to High(AEvidence.TimbreTrajectory.Knots) do
    begin
      PutHarmonicEvidence(AStream, AEvidence.TimbreTrajectory.Knots[LIndex]);
    end;
  end;
end;

function EnvelopeFromEvidence(const AEvidence: TEnvelopeStyleEvidence;
  const ASource: TAcousticSourceInfo; const AOutputRate: Integer): TGateEnvelope;
var
  LTrace: TEnvelopeTrace;
begin
  if (AEvidence.StartFrame < 0) or
    (Int64(AEvidence.StartFrame) + AEvidence.FrameCount > ASource.FrameCount) or
    (AEvidence.Channel < 0) or (AEvidence.Channel >= ASource.Channels) or
    (AEvidence.Policy = '') then
  begin
    raise EAudio.Create('Envelope evidence requires a source interval, channel and policy');
  end;
  ValidateCorpusText(AEvidence.Policy);
  LTrace := TEnvelopeTrace.CreateMeasured(ASource.SampleRate, AEvidence.StartFrame,
    AEvidence.FrameCount, AEvidence.Channel, AEvidence.WindowFrames, AEvidence.RmsPoints);
  try
    Result := LTrace.CreateGateEnvelope(AEvidence.GateFrame, AOutputRate,
      AEvidence.MaximumTailRatio, AEvidence.MinimumRms);
  finally
    LTrace.Free;
  end;
end;

procedure ValidateEnvelope(const AEvidence: TEnvelopeStyleEvidence;
  const ASource: TAcousticSourceInfo);
var
  LEnvelope: TGateEnvelope;
begin
  if AEvidence.FrameCount = 0 then
  begin
    if (Length(AEvidence.RmsPoints) <> 0) or (AEvidence.Policy <> '') then
    begin
      raise EAudio.Create('Unavailable envelope must have no points or policy');
    end;
    Exit;
  end;
  LEnvelope := EnvelopeFromEvidence(AEvidence, ASource, ASource.SampleRate);
  LEnvelope.Free;
end;

procedure ValidateTimbre(const AEvidence: THarmonicStyleEvidence;
  const ASource: TAcousticSourceInfo);
var
  LIndex: Integer;
  LRatio: Double;
begin
  if AEvidence.FrameCount = 0 then
  begin
    if (Length(AEvidence.Fit.Recipe.Sine) <> 0) or
      (Length(AEvidence.Fit.Recipe.Cosine) <> 0) or (AEvidence.Policy <> '') or
      (AEvidence.Fit.FrequencyHz <> 0) then
    begin
      raise EAudio.Create('Unavailable timbre must have no recipe or policy');
    end;
    Exit;
  end;
  HarmonicFitWork(AEvidence.FrameCount, ASource.SampleRate,
    Length(AEvidence.Fit.Recipe.Sine), AEvidence.Fit.FrequencyHz);
  if (AEvidence.StartFrame < 0) or
    (Int64(AEvidence.StartFrame) + AEvidence.FrameCount > ASource.FrameCount) or
    (AEvidence.Channel < 0) or (AEvidence.Channel >= ASource.Channels) or
    (Length(AEvidence.Fit.Recipe.Sine) <> Length(AEvidence.Fit.Recipe.Cosine)) then
  begin
    raise EAudio.Create('Timbre evidence requires an in-range source interval and paired coefficients');
  end;
  ValidateCorpusText(AEvidence.Policy);
  RequireFinite(AEvidence.MaximumRelativeError, 'Timbre error policy');
  RequireFinite(AEvidence.MinimumAcRms, 'Timbre AC policy');
  RequireFinite(AEvidence.Fit.Recipe.Mean, 'Timbre fitted DC');
  RequireFinite(AEvidence.Fit.AcRms, 'Timbre AC RMS');
  RequireFinite(AEvidence.Fit.ResidualRms, 'Timbre residual RMS');
  RequireFinite(AEvidence.Fit.RelativeError, 'Timbre relative error');
  if (AEvidence.Policy = '') or (AEvidence.MaximumRelativeError < 0) or
    (AEvidence.MaximumRelativeError > 1) or (AEvidence.MinimumAcRms < 0) or
    (AEvidence.Fit.AcRms <= AEvidence.MinimumAcRms) or
    (AEvidence.Fit.ResidualRms < 0) or (AEvidence.Fit.RelativeError < 0) or
    (AEvidence.Fit.RelativeError > AEvidence.MaximumRelativeError) then
  begin
    raise EAudio.Create('Timbre evidence does not meet its declared AC/error admission');
  end;
  LRatio := AEvidence.Fit.ResidualRms / AEvidence.Fit.AcRms;
  if Abs(LRatio - AEvidence.Fit.RelativeError) > 1E-12 then
  begin
    raise EAudio.Create('Timbre residual ratio disagrees with measured RMS');
  end;
  for LIndex := 0 to High(AEvidence.Fit.Recipe.Sine) do
  begin
    RequireFinite(AEvidence.Fit.Recipe.Sine[LIndex], 'Timbre sine coefficient');
    RequireFinite(AEvidence.Fit.Recipe.Cosine[LIndex], 'Timbre cosine coefficient');
    if (Abs(AEvidence.Fit.Recipe.Sine[LIndex]) > 16) or
      (Abs(AEvidence.Fit.Recipe.Cosine[LIndex]) > 16) or
      (Sqr(AEvidence.Fit.Recipe.Sine[LIndex]) +
        Sqr(AEvidence.Fit.Recipe.Cosine[LIndex]) > 256) then
    begin
      raise EAudio.Create('Timbre harmonic magnitude exceeds factory limit 16');
    end;
  end;
end;

procedure ValidateTimbreTrajectory(const AEvidence: TTimbreTrajectoryEvidence;
  const ASource: TAcousticSourceInfo);
var
  LIndex: Integer;
  LCenter: Int64;
  LPrevious: Int64;
  LWork: Int64;
  LShape: TWavetableMagnitudeShape;
begin
  if Length(AEvidence.Knots) = 0 then
  begin
    if AEvidence.OriginFrame <> 0 then
    begin
      raise EAudio.Create('Unavailable timbre trajectory must have no origin');
    end;
    Exit;
  end;
  if (Length(AEvidence.Knots) < 2) or
    (Length(AEvidence.Knots) > MaximumWavetableTrajectoryRecipes) or
    (AEvidence.OriginFrame < 0) or
    (AEvidence.OriginFrame > AEvidence.Knots[0].StartFrame) then
  begin
    raise EAudio.Create('Timbre trajectory requires 2..32 knots after its declared origin');
  end;
  LWork := 0;
  LPrevious := -1;
  for LIndex := 0 to High(AEvidence.Knots) do
  begin
    ValidateTimbre(AEvidence.Knots[LIndex], ASource);
    if (AEvidence.Knots[LIndex].FrameCount = 0) or
      (AEvidence.Knots[LIndex].Channel <> AEvidence.Knots[0].Channel) or
      (AEvidence.Knots[LIndex].Fit.FrequencyHz <> AEvidence.Knots[0].Fit.FrequencyHz) then
    begin
      raise EAudio.Create('Trajectory knots require measured intervals with one channel and declared fundamental');
    end;
    LCenter := 2 * Int64(AEvidence.Knots[LIndex].StartFrame) +
      AEvidence.Knots[LIndex].FrameCount - 1;
    if LCenter <= LPrevious then
    begin
      raise EAudio.Create('Trajectory window centers must strictly increase');
    end;
    LPrevious := LCenter;
    Inc(LWork, HarmonicFitWork(AEvidence.Knots[LIndex].FrameCount, ASource.SampleRate,
      Length(AEvidence.Knots[LIndex].Fit.Recipe.Sine), AEvidence.Knots[LIndex].Fit.FrequencyHz));
    if LWork > MaximumHarmonicFitWork then
    begin
      raise EAudio.Create('Trajectory evidence exceeds cumulative harmonic-fit work');
    end;
    LShape := FactorWavetableMagnitudes(AEvidence.Knots[LIndex].Fit.Recipe);
    if LShape.CycleRms <= 0 then
    begin
      raise EAudio.Create('Trajectory knot has no modeled harmonic level');
    end;
  end;
end;

function EvidenceIdentity(const AEvidence: TRhythmStyleEvidence): String;
var
  LStream: TMemoryStream;
begin
  LStream := TMemoryStream.Create;
  try
    PutEvidence(LStream, AEvidence);
    Result := Sha256Bytes(FinishArchive(LStream));
  finally
    LStream.Free;
  end;
end;

function CloneEvidence(const AEvidence: TRhythmStyleEvidence): TRhythmStyleEvidence;
var
  LIndex: Integer;
begin
  Result := AEvidence;
  Result.SourceClock := Copy(AEvidence.SourceClock);
  Result.OnsetFrames := Copy(AEvidence.OnsetFrames);
  Result.Dynamics.Rms := Copy(AEvidence.Dynamics.Rms);
  Result.Pitch.Cells := Copy(AEvidence.Pitch.Cells);
  Result.Duration.Estimates := Copy(AEvidence.Duration.Estimates);
  Result.Timbre.Fit.Recipe.Sine := Copy(AEvidence.Timbre.Fit.Recipe.Sine);
  Result.Timbre.Fit.Recipe.Cosine := Copy(AEvidence.Timbre.Fit.Recipe.Cosine);
  Result.Envelope.RmsPoints := Copy(AEvidence.Envelope.RmsPoints);
  Result.TimbreTrajectory.Knots := Copy(AEvidence.TimbreTrajectory.Knots);
  for LIndex := 0 to High(Result.TimbreTrajectory.Knots) do
  begin
    Result.TimbreTrajectory.Knots[LIndex].Fit.Recipe.Sine :=
      Copy(AEvidence.TimbreTrajectory.Knots[LIndex].Fit.Recipe.Sine);
    Result.TimbreTrajectory.Knots[LIndex].Fit.Recipe.Cosine :=
      Copy(AEvidence.TimbreTrajectory.Knots[LIndex].Fit.Recipe.Cosine);
  end;
end;

constructor TWaveStyleProfile.CreateSource(const AContext: TContextProfile;
  const AEvidence: TRhythmStyleEvidence; const AOrder: Integer);
var
  LInfo: TAcousticSourceInfo;
  LBundle: TContextLearningBundle;
  LContextEvidence: TContextEvidenceArray;
  LIndex: Integer;
  LFeatureCount: Integer;
  LAnalysisWork: Int64;
  LDurationTrack: TPitchTrack;
  LClock: TTempoMap;
  LGrid: TMusicGridFrames;
  LChange: Integer;
  LTick: Integer;
begin
  inherited Create;
  if (AContext = nil) or (AOrder < 1) or (AOrder > 4) then
  begin
    raise EAudio.Create('Source style requires context and order 1..4');
  end;
  ValidateSourceInfo(AEvidence.Source);
  ValidateTimbre(AEvidence.Timbre, AEvidence.Source);
  ValidateTimbreTrajectory(AEvidence.TimbreTrajectory, AEvidence.Source);
  if (AEvidence.Timbre.FrameCount > 0) and (Length(AEvidence.TimbreTrajectory.Knots) > 0) then
  begin
    raise EAudio.Create('A source selects stationary or trajectory timbre, not both');
  end;
  ValidateEnvelope(AEvidence.Envelope, AEvidence.Source);
  if AEvidence.DurationArticulateOnsets and (AEvidence.Duration.WindowFrames <= 0) then
  begin
    raise EAudio.Create('Onset-assisted duration requires dense pitch evidence');
  end;
  if AEvidence.Duration.WindowFrames > 0 then
  begin
    if AEvidence.Pitch.WindowFrames = 0 then
    begin
      raise EAudio.Create('Duration evidence requires the source pitch capability');
    end;
    LDurationTrack := TPitchTrack.CreateFromEvidence(AEvidence.Duration,
      AEvidence.Source.SampleRate, AEvidence.Source.Channels, AEvidence.Source.FrameCount);
    LDurationTrack.Free;
  end
  else if Length(AEvidence.Duration.Estimates) > 0 then
  begin
    raise EAudio.Create('Unavailable duration evidence must have no estimates');
  end;
  ValidateOnsetDynamics(AEvidence.Dynamics, Length(AEvidence.OnsetFrames), AEvidence.Source.Channels);
  PlanAudioAnalysis(AEvidence.Source.FrameCount, AEvidence.Source.Channels,
    AEvidence.Analysis, LFeatureCount, LAnalysisWork);
  if AEvidence.OnsetVersion <> OnsetLocationVersion then
  begin
    raise EAudio.Create('Unsupported style onset measurement version');
  end;
  LInfo := AEvidence.Source;
  LInfo.Sha256 := AEvidence.OnsetReportSha256;
  ValidateSourceInfo(LInfo);
  ValidateCorpusText(AEvidence.Policy);
  if AEvidence.Policy = '' then
  begin
    raise EAudio.Create('Style requires an explicit onset admission policy');
  end;
  FContext := DecodeContextProfile(EncodeContextProfile(AContext));
  FOrder := AOrder;
  FDepth := 1;
  FNodeCount := 1;
  SetLength(FEvidence, 1);
  SetLength(FAdmissions, 1);
  SetLength(FRhythmWeights, 1);
  SetLength(FPitchWeights, 1);
  SetLength(FTimbreWeights, 1);
  FTimbreWeights[0] := Ord((AEvidence.Timbre.FrameCount > 0) or
    (Length(AEvidence.TimbreTrajectory.Knots) > 0));
  SetLength(FEnvelopeWeights, 1);
  FEnvelopeWeights[0] := Ord(AEvidence.Envelope.FrameCount > 0);
  FPitchWeights[0] := Ord(AEvidence.Pitch.WindowFrames > 0);
  FEvidence[0] := CloneEvidence(AEvidence);
  FRhythmWeights[0] := 1;
  LClock := CreateStyleSourceClock(AEvidence, FContext.TicksPerQuarter, FContext.StepTicks);
  LGrid := nil;
  LBundle := nil;
  try
    LGrid := TMusicGridFrames.Create(LClock, AEvidence.Source.SampleRate,
      AEvidence.Source.FrameCount, AEvidence.SourceFrameOffset, AEvidence.SourceStartTick,
      FContext.StepTicks, (LClock.LengthTicks - AEvidence.SourceStartTick) div FContext.StepTicks);
    FAdmissions[0] := AdmitWaveRhythm(LGrid, AEvidence.MaximumErrorFrames, AEvidence.OnsetFrames);
    AdmitPitchCells(AEvidence.Pitch, LGrid, AEvidence.Source.Channels);
    LBundle := FContext.CopyBundle(cdTempo);
    LContextEvidence := LBundle.CopyEvidence;
    if (Length(LContextEvidence) <> 1) or
      (LContextEvidence[0].SourceSha256 <> AEvidence.Source.Sha256) or
      (LContextEvidence[0].SourceFrameOffset <> AEvidence.SourceFrameOffset) or
      (LContextEvidence[0].Grid.StartTick <> AEvidence.SourceStartTick) or
      (Length(LContextEvidence[0].Grid.Tempos) <> Length(FAdmissions[0].Pattern)) then
    begin
      raise EAudio.Create('Rhythm origin requires matching source context, frame offset, start tick and scope');
    end;
    LChange := 0;
    for LIndex := 0 to High(LContextEvidence[0].Grid.Tempos) do
    begin
      LTick := AEvidence.SourceStartTick + LIndex * FContext.StepTicks;
      while (LChange + 1 < LClock.ChangeCount) and
        (LClock.ChangeAt(LChange + 1).Tick <= LTick) do
      begin
        Inc(LChange);
      end;
      if (LContextEvidence[0].Grid.Tempos[LIndex] <>
        LClock.ChangeAt(LChange).MicrosecondsPerQuarter) or
        ((LChange + 1 < LClock.ChangeCount) and
          (LClock.ChangeAt(LChange + 1).Tick < LTick + FContext.StepTicks)) then
      begin
        raise EAudio.Create('Rhythm source tempo map must match complete admitted context cells');
      end;
    end;
  finally
    LBundle.Free;
    LGrid.Free;
    LClock.Free;
  end;
  Learn;
  SaveSource;
end;

function Gcd(const ALeft, ARight: Integer): Integer;
var
  LLeft: Integer;
  LRight: Integer;
  LNext: Integer;
begin
  LLeft := ALeft;
  LRight := ARight;
  while LRight <> 0 do
  begin
    LNext := LLeft mod LRight;
    LLeft := LRight;
    LRight := LNext;
  end;
  Result := LLeft;
end;

procedure NormalizeStyleWeights(var AWeights: array of Integer);
var
  LDivisor: Integer;
  LIndex: Integer;
begin
  LDivisor := 0;
  for LIndex := 0 to High(AWeights) do
  begin
    LDivisor := Gcd(LDivisor, AWeights[LIndex]);
  end;
  if LDivisor = 0 then
  begin
    Exit;
  end;
  for LIndex := 0 to High(AWeights) do
  begin
    AWeights[LIndex] := AWeights[LIndex] div LDivisor;
    if AWeights[LIndex] > MaximumStyleWeight then
    begin
      raise EAudio.Create('Normalized source weights exceed 0..64 in a musical dimension');
    end;
  end;
end;

constructor TWaveStyleProfile.CreateBlend(const ALeft, ARight: TWaveStyleProfile;
  const AKeySide, ATempoSide, ALeftWeight, ARightWeight: Integer);
var
  LLeftPitchWeight: Integer;
  LRightPitchWeight: Integer;
  LLeftTimbreWeight: Integer;
  LRightTimbreWeight: Integer;
begin
  inherited Create;
  if (ALeft = nil) or (ARight = nil) then
  begin
    raise EAudio.Create('Style blend requires two parents');
  end;
  LLeftPitchWeight := 0;
  LRightPitchWeight := 0;
  if ((ALeftWeight > 0) and ALeft.HasPitch) or
    ((ARightWeight > 0) and ARight.HasPitch) then
  begin
    LLeftPitchWeight := ALeftWeight;
    LRightPitchWeight := ARightWeight;
  end;
  LLeftTimbreWeight := 0;
  LRightTimbreWeight := 0;
  if ((ALeftWeight > 0) and ALeft.HasTimbre) or
    ((ARightWeight > 0) and ARight.HasTimbre) then
  begin
    LLeftTimbreWeight := ALeftWeight;
    LRightTimbreWeight := ARightWeight;
  end;
  BuildBlend(ALeft, ARight, AKeySide, ATempoSide, ALeftWeight, ARightWeight,
    LLeftPitchWeight, LRightPitchWeight, LLeftTimbreWeight, LRightTimbreWeight);
end;

constructor TWaveStyleProfile.CreateBlendDimensions(const ALeft, ARight: TWaveStyleProfile;
  const AKeySide, ATempoSide, ALeftRhythmWeight, ARightRhythmWeight,
  ALeftPitchWeight, ARightPitchWeight: Integer);
var
  LLeftTimbreWeight: Integer;
  LRightTimbreWeight: Integer;
begin
  inherited Create;
  if (ALeft = nil) or (ARight = nil) then
  begin
    raise EAudio.Create('Style blend requires two parents');
  end;
  LLeftTimbreWeight := 0;
  LRightTimbreWeight := 0;
  if ((ALeftRhythmWeight > 0) and ALeft.HasTimbre) or
    ((ARightRhythmWeight > 0) and ARight.HasTimbre) then
  begin
    LLeftTimbreWeight := ALeftRhythmWeight;
    LRightTimbreWeight := ARightRhythmWeight;
  end;
  BuildBlend(ALeft, ARight, AKeySide, ATempoSide, ALeftRhythmWeight, ARightRhythmWeight,
    ALeftPitchWeight, ARightPitchWeight, LLeftTimbreWeight, LRightTimbreWeight);
end;

constructor TWaveStyleProfile.CreateBlendLayers(const ALeft, ARight: TWaveStyleProfile;
  const AKeySide, ATempoSide, ALeftRhythmWeight, ARightRhythmWeight,
  ALeftPitchWeight, ARightPitchWeight, ALeftTimbreWeight, ARightTimbreWeight: Integer;
  const ALeftEnvelopeWeight, ARightEnvelopeWeight: Integer);
begin
  inherited Create;
  BuildBlend(ALeft, ARight, AKeySide, ATempoSide, ALeftRhythmWeight, ARightRhythmWeight,
    ALeftPitchWeight, ARightPitchWeight, ALeftTimbreWeight, ARightTimbreWeight,
    ALeftEnvelopeWeight, ARightEnvelopeWeight);
end;

procedure TWaveStyleProfile.BuildBlend(const ALeft, ARight: TWaveStyleProfile;
  const AKeySide, ATempoSide, ALeftWeight, ARightWeight,
  ALeftPitchWeight, ARightPitchWeight, ALeftTimbreWeight, ARightTimbreWeight: Integer;
  const ALeftEnvelopeWeight, ARightEnvelopeWeight: Integer);
var
  LParents: array[0..1] of TWaveStyleProfile;
  LFactors: array[0..1] of Integer;
  LPitchFactors: array[0..1] of Integer;
  LTimbreFactors: array[0..1] of Integer;
  LEnvelopeFactors: array[0..1] of Integer;
  LSide: Integer;
  LIndex: Integer;
  LFound: Integer;
  LOther: Integer;
  LCount: Integer;
  LRhythmWeight: Integer;
  LPitchWeight: Integer;
  LTimbreWeight: Integer;
  LEnvelopeWeight: Integer;
begin
  if (ALeft = nil) or (ARight = nil) or not (AKeySide in [0, 1]) or
    not (ATempoSide in [0, 1]) or (ALeftWeight < 0) or (ARightWeight < 0) or
    (ALeftWeight > 64) or (ARightWeight > 64) or
    (ALeftWeight + ARightWeight = 0) or
    (ALeftPitchWeight < 0) or (ARightPitchWeight < 0) or
    (ALeftPitchWeight > 64) or (ARightPitchWeight > 64) or
    (ALeftTimbreWeight < 0) or (ARightTimbreWeight < 0) or
    (ALeftTimbreWeight > 64) or (ARightTimbreWeight > 64) then
  begin
    raise EAudio.Create('Blend requires two parents, context sides 0/1, weights 0..64 and active rhythm');
  end;
  if ((ALeftPitchWeight > 0) and not ALeft.HasPitch) or
    ((ARightPitchWeight > 0) and not ARight.HasPitch) then
  begin
    raise EAudio.Create('Selected pitch parent has no active measured pitch model');
  end;
  if ((ALeftTimbreWeight > 0) and not ALeft.HasTimbre) or
    ((ARightTimbreWeight > 0) and not ARight.HasTimbre) then
  begin
    raise EAudio.Create('Selected timbre parent has no admitted harmonic evidence');
  end;
  if (ALeft.FOrder <> ARight.FOrder) or
    (ALeft.FContext.TicksPerQuarter <> ARight.FContext.TicksPerQuarter) or
    (ALeft.FContext.StepTicks <> ARight.FContext.StepTicks) then
  begin
    raise EAudio.Create('Style blend requires equal PPQ, cell step and model order');
  end;
  FDepth := Max(ALeft.Depth, ARight.Depth) + 1;
  FNodeCount := ALeft.NodeCount + ARight.NodeCount + 1;
  if (FDepth > MaximumStyleDepth) or (FNodeCount > MaximumStyleNodes) then
  begin
    raise EAudio.Create('Style blend exceeds bounded ancestry');
  end;
  LParents[0] := ALeft;
  LParents[1] := ARight;
  LEnvelopeFactors[0] := ALeftEnvelopeWeight;
  LEnvelopeFactors[1] := ARightEnvelopeWeight;
  if (ALeftEnvelopeWeight = -1) and (ARightEnvelopeWeight = -1) then
  begin
    LEnvelopeFactors[0] := 0;
    LEnvelopeFactors[1] := 0;
    if ((ALeftWeight > 0) and ALeft.HasEnvelope) or
      ((ARightWeight > 0) and ARight.HasEnvelope) then
    begin
      LEnvelopeFactors[0] := ALeftWeight;
      LEnvelopeFactors[1] := ARightWeight;
    end;
  end;
  for LSide := 0 to 1 do
  begin
    if (LEnvelopeFactors[LSide] < 0) or (LEnvelopeFactors[LSide] > 64) or
      ((LEnvelopeFactors[LSide] > 0) and not LParents[LSide].HasEnvelope) then
    begin
      raise EAudio.Create('Envelope weights require 0..64 and evidence for every active parent');
    end;
  end;
  LFactors[0] := ALeftWeight;
  LFactors[1] := ARightWeight;
  LPitchFactors[0] := ALeftPitchWeight;
  LPitchFactors[1] := ARightPitchWeight;
  LTimbreFactors[0] := ALeftTimbreWeight;
  LTimbreFactors[1] := ARightTimbreWeight;
  FContext := SelectContextProfile(LParents[AKeySide].FContext, LParents[ATempoSide].FContext);
  FOrder := ALeft.FOrder;
  FParentIds[0] := ALeft.Identity;
  FParentIds[1] := ARight.Identity;
  for LSide := 0 to 1 do
  begin
    for LIndex := 0 to LParents[LSide].SourceCount - 1 do
    begin
      LRhythmWeight := LFactors[LSide] * LParents[LSide].FRhythmWeights[LIndex];
      LPitchWeight := LPitchFactors[LSide] * LParents[LSide].FPitchWeights[LIndex];
      LTimbreWeight := LTimbreFactors[LSide] * LParents[LSide].FTimbreWeights[LIndex];
      LEnvelopeWeight := LEnvelopeFactors[LSide] * LParents[LSide].FEnvelopeWeights[LIndex];
      if (LRhythmWeight = 0) and (LPitchWeight = 0) and (LTimbreWeight = 0) and
        (LEnvelopeWeight = 0) then
      begin
        Continue;
      end;
      LFound := -1;
      for LOther := 0 to High(FEvidence) do
      begin
        if FEvidence[LOther].Source.Sha256 =
          LParents[LSide].FEvidence[LIndex].Source.Sha256 then
        begin
          if EvidenceIdentity(FEvidence[LOther]) <>
            EvidenceIdentity(LParents[LSide].FEvidence[LIndex]) then
          begin
            raise EAudio.Create('Repeated source has conflicting measurements; normalize explicitly');
          end;
          LFound := LOther;
          Break;
        end;
      end;
      if LFound < 0 then
      begin
        LCount := Length(FEvidence);
        if LCount = MaximumStyleSources then
        begin
          raise EAudio.Create('Style blend exceeds 32 distinct active sources');
        end;
        SetLength(FEvidence, LCount + 1);
        SetLength(FAdmissions, LCount + 1);
        SetLength(FRhythmWeights, LCount + 1);
        SetLength(FPitchWeights, LCount + 1);
        SetLength(FTimbreWeights, LCount + 1);
        SetLength(FEnvelopeWeights, LCount + 1);
        FEvidence[LCount] := LParents[LSide].EvidenceAt(LIndex);
        FAdmissions[LCount] := LParents[LSide].AdmissionAt(LIndex);
        LFound := LCount;
      end;
      Inc(FRhythmWeights[LFound], LRhythmWeight);
      Inc(FPitchWeights[LFound], LPitchWeight);
      Inc(FTimbreWeights[LFound], LTimbreWeight);
      Inc(FEnvelopeWeights[LFound], LEnvelopeWeight);
    end;
  end;
  NormalizeStyleWeights(FRhythmWeights);
  NormalizeStyleWeights(FPitchWeights);
  NormalizeStyleWeights(FTimbreWeights);
  NormalizeStyleWeights(FEnvelopeWeights);
  Learn;
  InheritGenerationPreferences(ALeft, ARight, AKeySide, ATempoSide, ALeftWeight, ARightWeight,
    ALeftPitchWeight, ARightPitchWeight);
  SaveBlend(ALeft, ARight, AKeySide, ATempoSide, ALeftWeight, ARightWeight,
    ALeftPitchWeight, ARightPitchWeight, ALeftTimbreWeight, ARightTimbreWeight,
    LEnvelopeFactors[0], LEnvelopeFactors[1]);
end;

procedure TWaveStyleProfile.Learn;
var
  LSamples: TWfcSequenceSamples;
  LJointSamples: TWfcSequenceSamples;
  LJointTokens: TWfcModelTokens;
  LIntensity: String;
  LPitchTracks: TPitchTracks;
  LPitchPatterns: TPitchRhythmPatterns;
  LDurationTracks: TTimedPitchTracks;
  LDurationWeights: array of Integer;
  LDurationCount: Integer;
  LTokens: TWfcModelTokens;
  LTotal: Int64;
  LCount: Integer;
  LSource: Integer;
  LRepeat: Integer;
  LCell: Integer;
begin
  LCount := 0;
  LTotal := 0;
  FHasDynamics := False;
  FHasPitch := False;
  FHasTimbre := False;
  FHasTimbreTrajectory := False;
  FHasEnvelope := False;
  for LSource := 0 to High(FEvidence) do
  begin
    if FEnvelopeWeights[LSource] > 0 then
    begin
      if FEvidence[LSource].Envelope.FrameCount = 0 then
      begin
        raise EAudio.Create('Active envelope source has no measured evidence');
      end;
      FHasEnvelope := True;
    end;
    if FTimbreWeights[LSource] > 0 then
    begin
      if (FEvidence[LSource].Timbre.FrameCount = 0) and
        (Length(FEvidence[LSource].TimbreTrajectory.Knots) = 0) then
      begin
        raise EAudio.Create('Active timbre source has no harmonic evidence');
      end;
      FHasTimbre := True;
      FHasTimbreTrajectory := FHasTimbreTrajectory or
        (Length(FEvidence[LSource].TimbreTrajectory.Knots) > 0);
    end;
    if FPitchWeights[LSource] > 0 then
    begin
      if FEvidence[LSource].Pitch.WindowFrames = 0 then
      begin
        raise EAudio.Create('Active pitch source has no pitch evidence');
      end;
      FHasPitch := True;
    end;
    if FRhythmWeights[LSource] = 0 then
    begin
      Continue;
    end;
    if LCount = 0 then
    begin
      FHasDynamics := FEvidence[LSource].Dynamics.WindowFrames > 0;
    end;
    if (FEvidence[LSource].Dynamics.WindowFrames > 0) <> FHasDynamics then
    begin
      raise EAudio.Create('Active rhythm sources must agree on measured dynamics availability');
    end;
    Inc(LCount, FRhythmWeights[LSource]);
    Inc(LTotal, Int64(FRhythmWeights[LSource]) * Length(FAdmissions[LSource].Pattern));
  end;
  if (LCount < 1) or (LCount > WFC_SEQUENCE_MAX_SAMPLE_COUNT) or
    (LTotal > MaximumStyleCells) then
  begin
    raise EAudio.Create('Weighted rhythm learning exceeds sample/cell budget');
  end;
  SetLength(LSamples, LCount);
  if FHasDynamics then
  begin
    SetLength(LJointSamples, LCount);
  end;
  LCount := 0;
  for LSource := 0 to High(FEvidence) do
  begin
    if FRhythmWeights[LSource] = 0 then
    begin
      Continue;
    end;
    SetLength(LTokens, Length(FAdmissions[LSource].Pattern));
    if FHasDynamics then
    begin
      LIntensity := IntensityPatternAt(LSource);
      SetLength(LJointTokens, Length(LTokens));
      for LCell := 0 to High(LJointTokens) do
      begin
        LJointTokens[LCell] := StyleIntensityToken(Ord(LIntensity[LCell + 1]) - Ord('0'));
      end;
    end;
    for LCell := 0 to High(LTokens) do
    begin
      if FAdmissions[LSource].Pattern[LCell + 1] = 'x' then
      begin
        LTokens[LCell] := RhythmOnsetToken;
      end
      else
      begin
        LTokens[LCell] := RhythmEmptyToken;
      end;
    end;
    for LRepeat := 1 to FRhythmWeights[LSource] do
    begin
      LSamples[LCount] := MakeWfcSequenceSample(LTokens);
      if FHasDynamics then
      begin
        LJointSamples[LCount] := MakeWfcSequenceSample(LJointTokens);
      end;
      Inc(LCount);
    end;
  end;
  FModel := LearnSequenceModelCorpus(LSamples, FOrder);
  if FHasDynamics then
  begin
    FJointModel := LearnSequenceModelCorpus(LJointSamples, FOrder);
  end;
  if FHasPitch then
  begin
    SetLength(LPitchTracks, SourceCount);
    for LSource := 0 to SourceCount - 1 do
    begin
      LPitchTracks[LSource] := PitchNotesAt(LSource);
    end;
    FPitchModel := LearnPitchModel(LPitchTracks, FPitchWeights, FOrder);
    FHasPitchRhythm := True;
    for LSource := 0 to SourceCount - 1 do
    begin
      FHasPitchRhythm := FHasPitchRhythm and
        (FPitchWeights[LSource] = FRhythmWeights[LSource]);
    end;
    if FHasPitchRhythm then
    begin
      SetLength(LPitchPatterns, SourceCount);
      for LSource := 0 to SourceCount - 1 do
      begin
        if FHasDynamics then
        begin
          LPitchPatterns[LSource] := IntensityPatternAt(LSource);
        end
        else
        begin
          LPitchPatterns[LSource] := StringOfChar('0', Length(FAdmissions[LSource].Pattern));
          for LCell := 1 to Length(LPitchPatterns[LSource]) do
          begin
            if FAdmissions[LSource].Pattern[LCell] = 'x' then
            begin
              LPitchPatterns[LSource][LCell] := '5';
            end;
          end;
        end;
      end;
      FPitchRhythmModel := LearnPitchRhythmModel(LPitchTracks, LPitchPatterns, FPitchWeights, FOrder);
    end;
  end;
  FHasDuration := FHasPitch;
  LDurationCount := 0;
  for LSource := 0 to SourceCount - 1 do
  begin
    if FPitchWeights[LSource] = 0 then
    begin
      Continue;
    end;
    if FEvidence[LSource].Duration.WindowFrames = 0 then
    begin
      FHasDuration := False;
    end;
    Inc(LDurationCount);
  end;
  if FHasDuration then
  begin
    SetLength(LDurationTracks, LDurationCount);
    SetLength(LDurationWeights, LDurationCount);
    LDurationCount := 0;
    for LSource := 0 to SourceCount - 1 do
    begin
      if FPitchWeights[LSource] = 0 then
      begin
        Continue;
      end;
      LDurationTracks[LDurationCount] := CopyTimedDurationSpans(LSource);
      LDurationWeights[LDurationCount] := FPitchWeights[LSource];
      Inc(LDurationCount);
    end;
    FDurationModel := LearnPitchDurationModel(LDurationTracks, LDurationWeights, FOrder);
  end;
end;

function OptionalModelText(const AModel: TWfcSequenceModel): UTF8String;
begin
  Result := '';
  if AModel <> nil then
  begin
    Result := EncodeWfcSequenceText(AModel);
  end;
end;

procedure TWaveStyleProfile.AssignGenerationPreferences(
  const APreferences: TStyleGenerationPreferences);
var
  LProvider: TStylePreferenceProvider;
  LModel: TWfcSequenceModel;
  LIndex: Integer;
  LOther: Integer;
  LCopy: TStyleGenerationPreferences;
begin
  LCopy := Default(TStyleGenerationPreferences);
  for LProvider := Low(LProvider) to High(LProvider) do
  begin
    if Length(APreferences[LProvider]) > MaximumLayerPreferences then
    begin
      raise EAudio.Create('Style preference count exceeds layer bounds');
    end;
    if Length(APreferences[LProvider]) = 0 then
    begin
      Continue;
    end;
    LModel := nil;
    try
      case LProvider of
        sppKey: LModel := FContext.CopyModel(cdKey);
        sppTempo: LModel := FContext.CopyModel(cdTempo);
        sppPerformance: LModel := CopyDurationModel;
        sppRhythm: LModel := CopyRhythmModel;
        sppIntensity: LModel := CopyIntensityModel;
        sppPitch: LModel := CopyPitchModel;
        sppPitchRhythm: LModel := CopyPitchRhythmModel;
      end;
      for LIndex := 0 to High(APreferences[LProvider]) do
      begin
        if (APreferences[LProvider][LIndex].Multiplier < 1) or
          (APreferences[LProvider][LIndex].Multiplier > MaximumLayerPreferenceMultiplier) or
          (LModel.FindPublicToken(APreferences[LProvider][LIndex].Token) < 0) then
        begin
          raise EAudio.Create('Style preference requires a supported token and positive bounded multiplier');
        end;
        for LOther := 0 to LIndex - 1 do
        begin
          if APreferences[LProvider][LOther].Token = APreferences[LProvider][LIndex].Token then
          begin
            raise EAudio.Create('Duplicate style preference token');
          end;
        end;
      end;
      LCopy[LProvider] := Copy(APreferences[LProvider]);
    finally
      LModel.Free;
    end;
  end;
  FGenerationPreferences := LCopy;
end;

function TWaveStyleProfile.CopyGenerationPreferences: TStyleGenerationPreferences;
var
  LProvider: TStylePreferenceProvider;
begin
  Result := Default(TStyleGenerationPreferences);
  for LProvider := Low(LProvider) to High(LProvider) do
  begin
    Result[LProvider] := Copy(FGenerationPreferences[LProvider]);
  end;
end;

function TWaveStyleProfile.HasGenerationPreferences: Boolean;
var
  LProvider: TStylePreferenceProvider;
begin
  for LProvider := Low(LProvider) to High(LProvider) do
  begin
    if Length(FGenerationPreferences[LProvider]) > 0 then
    begin
      Exit(True);
    end;
  end;
  Result := False;
end;

constructor TWaveStyleProfile.CreatePreferred(const AParent: TWaveStyleProfile;
  const APreferences: TStyleGenerationPreferences);
var
  LIndex: Integer;
begin
  inherited Create;
  if (AParent = nil) then
  begin
    raise EAudio.Create('Preferred style requires a parent');
  end;
  if (AParent.Depth >= MaximumStyleDepth) or (AParent.NodeCount >= MaximumStyleNodes) then
  begin
    raise EAudio.Create('Preferred style exceeds bounded ancestry');
  end;
  FContext := AParent.CopyContext;
  FOrder := AParent.Order;
  FDepth := AParent.Depth + 1;
  FNodeCount := AParent.NodeCount + 1;
  FParentIds[0] := AParent.Identity;
  SetLength(FEvidence, AParent.SourceCount);
  SetLength(FAdmissions, AParent.SourceCount);
  for LIndex := 0 to AParent.SourceCount - 1 do
  begin
    FEvidence[LIndex] := AParent.EvidenceAt(LIndex);
    FAdmissions[LIndex] := AParent.AdmissionAt(LIndex);
  end;
  FRhythmWeights := Copy(AParent.FRhythmWeights);
  FPitchWeights := Copy(AParent.FPitchWeights);
  FTimbreWeights := Copy(AParent.FTimbreWeights);
  FEnvelopeWeights := Copy(AParent.FEnvelopeWeights);
  Learn;
  AssignGenerationPreferences(APreferences);
  SavePreferred(AParent);
end;

procedure TWaveStyleProfile.InheritGenerationPreferences(
  const ALeft, ARight: TWaveStyleProfile;
  const AKeySide, ATempoSide, ALeftRhythmWeight, ARightRhythmWeight,
  ALeftPitchWeight, ARightPitchWeight: Integer);
var
  LParents: array[0..1] of TWaveStyleProfile;
  LWeights: array[0..1] of Integer;
  LRhythmWeights: array[0..1] of Integer;
  LPreferences: TStyleGenerationPreferences;
  LPreference: TLayerTokenPreference;
  LSide: Integer;
  LIndex: Integer;
  LFound: Integer;
  LProvider: TStylePreferenceProvider;
  LActive: Boolean;
begin
  LParents[0] := ALeft;
  LParents[1] := ARight;
  LWeights[0] := ALeftPitchWeight;
  LWeights[1] := ARightPitchWeight;
  LRhythmWeights[0] := ALeftRhythmWeight;
  LRhythmWeights[1] := ARightRhythmWeight;
  LPreferences := Default(TStyleGenerationPreferences);
  LPreferences[sppKey] := Copy(LParents[AKeySide].FGenerationPreferences[sppKey]);
  LPreferences[sppTempo] := Copy(LParents[ATempoSide].FGenerationPreferences[sppTempo]);
  for LProvider := sppPerformance to High(LProvider) do
  begin
    for LSide := 0 to 1 do
    begin
      LActive := LWeights[LSide] > 0;
      if LProvider in [sppRhythm, sppIntensity] then
      begin
        LActive := LRhythmWeights[LSide] > 0;
      end
      else if LProvider = sppPitchRhythm then
      begin
        LActive := LActive and (LRhythmWeights[LSide] > 0);
      end;
      if not LActive then
      begin
        Continue;
      end;
      for LPreference in LParents[LSide].FGenerationPreferences[LProvider] do
      begin
        LFound := -1;
        for LIndex := 0 to High(LPreferences[LProvider]) do
        begin
          if LPreferences[LProvider][LIndex].Token = LPreference.Token then
          begin
            LFound := LIndex;
            Break;
          end;
        end;
        if LFound >= 0 then
        begin
          if LPreferences[LProvider][LFound].Multiplier <> LPreference.Multiplier then
          begin
            raise EAudio.Create('Conflicting generation preferences; clear or align the parent settings');
          end;
        end
        else
        begin
          LIndex := Length(LPreferences[LProvider]);
          if LIndex = MaximumLayerPreferences then
          begin
            raise EAudio.Create('Blended preference count exceeds layer bounds');
          end;
          SetLength(LPreferences[LProvider], LIndex + 1);
          LPreferences[LProvider][LIndex] := LPreference;
        end;
      end;
    end;
  end;
  AssignGenerationPreferences(LPreferences);
end;

procedure TWaveStyleProfile.SavePreferred(const AParent: TWaveStyleProfile);
var
  LStream: TMemoryStream;
  LProvider: TStylePreferenceProvider;
  LPreference: TLayerTokenPreference;
begin
  LStream := TMemoryStream.Create;
  try
    PutNumber(LStream, StyleMagic);
    PutNumber(LStream, WaveStyleVersion);
    PutNumber(LStream, 2); { Output-preference derivation in the current format. }
    PutNumber(LStream, FOrder);
    PutBlob(LStream, AParent.FBytes);
    for LProvider := Low(LProvider) to High(LProvider) do
    begin
      PutNumber(LStream, Length(FGenerationPreferences[LProvider]));
      for LPreference in FGenerationPreferences[LProvider] do
      begin
        PutText(LStream, LPreference.Token);
        PutNumber(LStream, LPreference.Multiplier);
      end;
    end;
    PutText(LStream, EncodeWfcSequenceText(FModel));
    PutText(LStream, OptionalModelText(FJointModel));
    PutText(LStream, OptionalModelText(FPitchModel));
    PutText(LStream, OptionalModelText(FPitchRhythmModel));
    PutText(LStream, OptionalModelText(FDurationModel));
    FBytes := FinishArchive(LStream);
    FIdentity := Sha256Bytes(FBytes);
  finally
    LStream.Free;
  end;
end;

procedure TWaveStyleProfile.SaveSource;
var
  LStream: TMemoryStream;
begin
  LStream := TMemoryStream.Create;
  try
    PutNumber(LStream, StyleMagic);
    PutNumber(LStream, WaveStyleVersion);
    PutNumber(LStream, 0);
    PutNumber(LStream, FOrder);
    PutBlob(LStream, EncodeContextProfile(FContext));
    PutEvidence(LStream, FEvidence[0]);
    PutText(LStream, EncodeWfcSequenceText(FModel));
    PutText(LStream, OptionalModelText(FJointModel));
    PutText(LStream, OptionalModelText(FPitchModel));
    PutText(LStream, OptionalModelText(FPitchRhythmModel));
    PutText(LStream, OptionalModelText(FDurationModel));
    FBytes := FinishArchive(LStream);
    FIdentity := Sha256Bytes(FBytes);
  finally
    LStream.Free;
  end;
end;

procedure TWaveStyleProfile.SaveBlend(const ALeft, ARight: TWaveStyleProfile;
  const AKeySide, ATempoSide, ALeftWeight, ARightWeight,
  ALeftPitchWeight, ARightPitchWeight, ALeftTimbreWeight, ARightTimbreWeight,
  ALeftEnvelopeWeight, ARightEnvelopeWeight: Integer);
var
  LStream: TMemoryStream;
begin
  LStream := TMemoryStream.Create;
  try
    PutNumber(LStream, StyleMagic);
    PutNumber(LStream, WaveStyleVersion);
    PutNumber(LStream, 1);
    PutNumber(LStream, FOrder);
    PutNumber(LStream, AKeySide);
    PutNumber(LStream, ATempoSide);
    PutNumber(LStream, ALeftWeight);
    PutNumber(LStream, ARightWeight);
    PutNumber(LStream, ALeftPitchWeight);
    PutNumber(LStream, ARightPitchWeight);
    PutNumber(LStream, ALeftTimbreWeight);
    PutNumber(LStream, ARightTimbreWeight);
    PutNumber(LStream, ALeftEnvelopeWeight);
    PutNumber(LStream, ARightEnvelopeWeight);
    PutBlob(LStream, ALeft.FBytes);
    PutBlob(LStream, ARight.FBytes);
    PutText(LStream, EncodeWfcSequenceText(FModel));
    PutText(LStream, OptionalModelText(FJointModel));
    PutText(LStream, OptionalModelText(FPitchModel));
    PutText(LStream, OptionalModelText(FPitchRhythmModel));
    PutText(LStream, OptionalModelText(FDurationModel));
    FBytes := FinishArchive(LStream);
    FIdentity := Sha256Bytes(FBytes);
  finally
    LStream.Free;
  end;
end;

destructor TWaveStyleProfile.Destroy;
begin
  FDurationModel.Free;
  FPitchRhythmModel.Free;
  FPitchModel.Free;
  FJointModel.Free;
  FModel.Free;
  FContext.Free;
  inherited;
end;

function TWaveStyleProfile.GetSourceCount: Integer;
begin
  Result := Length(FEvidence);
end;

function TWaveStyleProfile.EvidenceAt(const AIndex: Integer): TRhythmStyleEvidence;
begin
  if (AIndex < 0) or (AIndex >= SourceCount) then
  begin
    raise EAudio.Create('Style evidence index outside source table');
  end;
  Result := CloneEvidence(FEvidence[AIndex]);
end;

function TWaveStyleProfile.AdmissionAt(const AIndex: Integer): TRhythmAdmission;
begin
  if (AIndex < 0) or (AIndex >= SourceCount) then
  begin
    raise EAudio.Create('Style admission index outside source table');
  end;
  Result := FAdmissions[AIndex];
  Result.Cells := Copy(Result.Cells);
  Result.FrameErrors := Copy(Result.FrameErrors);
  Result.Decisions := Copy(Result.Decisions);
end;

function TWaveStyleProfile.RhythmWeightAt(const AIndex: Integer): Integer;
begin
  if (AIndex < 0) or (AIndex >= SourceCount) then
  begin
    raise EAudio.Create('Style weight index outside source table');
  end;
  Result := FRhythmWeights[AIndex];
end;

function TWaveStyleProfile.PitchWeightAt(const AIndex: Integer): Integer;
begin
  if (AIndex < 0) or (AIndex >= SourceCount) then
  begin
    raise EAudio.Create('Style pitch weight index outside source table');
  end;
  Result := FPitchWeights[AIndex];
end;

function TWaveStyleProfile.ParentIdentity(const ASide: Integer): String;
begin
  if not (ASide in [0, 1]) or (FDepth = 1) then
  begin
    raise EAudio.Create('Style parent is unavailable');
  end;
  Result := FParentIds[ASide];
end;

function TWaveStyleProfile.TimbreWeightAt(const AIndex: Integer): Integer;
begin
  if (AIndex < 0) or (AIndex >= SourceCount) then
  begin
    raise EAudio.Create('Timbre weight index outside source table');
  end;
  Result := FTimbreWeights[AIndex];
end;

function TWaveStyleProfile.EnvelopeWeightAt(const AIndex: Integer): Integer;
begin
  if (AIndex < 0) or (AIndex >= SourceCount) then
  begin
    raise EAudio.Create('Envelope weight index outside source table');
  end;
  Result := FEnvelopeWeights[AIndex];
end;

function TWaveStyleProfile.CopyGateEnvelope(const AOutputRate: Integer): TGateEnvelope;
var
  LEnvelopes: array of TGateEnvelope;
  I: Integer;
begin
  if not FHasEnvelope then
  begin
    raise EAudio.Create('Style has no active measured envelope');
  end;
  SetLength(LEnvelopes, SourceCount);
  try
    for I := 0 to SourceCount - 1 do
    begin
      if FEnvelopeWeights[I] > 0 then
      begin
        LEnvelopes[I] := EnvelopeFromEvidence(FEvidence[I].Envelope, FEvidence[I].Source,
          AOutputRate);
      end;
    end;
    Result := TGateEnvelope.Blend(LEnvelopes, FEnvelopeWeights);
  finally
    for I := 0 to High(LEnvelopes) do
    begin
      LEnvelopes[I].Free;
    end;
  end;
end;

function TWaveStyleProfile.CopyTimbreRecipe: TWavetableCycleRecipe;
var
  LRecipe: TWavetableCycleRecipe;
  LSource: Integer;
  LHarmonic: Integer;
  LCount: Integer;
  LTotal: Integer;
  LWeight: Double;
begin
  if not FHasTimbre or FHasTimbreTrajectory then
  begin
    raise EAudio.Create('Style requires stationary timbre; use its factory for trajectories');
  end;
  LCount := 0;
  LTotal := 0;
  for LSource := 0 to SourceCount - 1 do
  begin
    if FTimbreWeights[LSource] > 0 then
    begin
      LCount := Max(LCount, Length(FEvidence[LSource].Timbre.Fit.Recipe.Sine));
      Inc(LTotal, FTimbreWeights[LSource]);
    end;
  end;
  LRecipe := Default(TWavetableCycleRecipe);
  SetLength(LRecipe.Sine, LCount);
  SetLength(LRecipe.Cosine, LCount);
  for LSource := 0 to SourceCount - 1 do
  begin
    if FTimbreWeights[LSource] = 0 then
    begin
      Continue;
    end;
    LWeight := FTimbreWeights[LSource];
    for LHarmonic := 0 to High(FEvidence[LSource].Timbre.Fit.Recipe.Sine) do
    begin
      LRecipe.Sine[LHarmonic] := LRecipe.Sine[LHarmonic] + LWeight * Sqrt(
        Sqr(FEvidence[LSource].Timbre.Fit.Recipe.Sine[LHarmonic]) +
        Sqr(FEvidence[LSource].Timbre.Fit.Recipe.Cosine[LHarmonic]));
    end;
  end;
  for LHarmonic := 0 to High(LRecipe.Sine) do
  begin
    LRecipe.Sine[LHarmonic] := LRecipe.Sine[LHarmonic] / LTotal;
  end;
  Result := LRecipe;
end;

function TWaveStyleProfile.CopyTimbreFactory(const AOutputRate: Integer;
  const ATrajectoryRms: Double): TWavetableSourceFactory;
type
  TPreparedShape = record
    Frames: array of Int64;
    Recipes: TWavetableCycleRecipes;
  end;
var
  LPrepared: array of TPreparedShape;
  LFrames: array[0..MaximumWavetableTrajectoryRecipes - 1] of Int64;
  LCount: Integer;
  LSource: Integer;
  LKnot: Integer;
  LHarmonic: Integer;
  LIndex: Integer;
  LTotal: Integer;
  LMaximumHarmonics: Integer;
  LFrame: Int64;
  LWeight: Double;
  LValue: Double;
  LRecipes: TWavetableCycleRecipes;
  LRecipe: TWavetableCycleRecipe;
  LShape: TWavetableMagnitudeShape;
  LPoints: TAutomationPoints;
  LCurve: TAutomationCurve;

  procedure AddFrame(const AFrame: Int64);
  var
    LAt: Integer;
    LMove: Integer;
  begin
    LAt := 0;
    while (LAt < LCount) and (LFrames[LAt] < AFrame) do
    begin
      Inc(LAt);
    end;
    if (LAt < LCount) and (LFrames[LAt] = AFrame) then
    begin
      Exit;
    end;
    if LCount = MaximumWavetableTrajectoryRecipes then
    begin
      raise EAudio.Create('Blended timbre exceeds 32 output-frame knots; select compatible evidence');
    end;
    for LMove := LCount downto LAt + 1 do
    begin
      LFrames[LMove] := LFrames[LMove - 1];
    end;
    LFrames[LAt] := AFrame;
    Inc(LCount);
  end;

begin
  ValidateAudioFormat(AOutputRate, 1);
  if not FHasTimbreTrajectory then
  begin
    LRecipe := CopyTimbreRecipe;
    Exit(TWavetableSourceFactory.Create(LRecipe.Sine, LRecipe.Cosine));
  end;
  RequireFinite(ATrajectoryRms, 'Style trajectory reference RMS');
  if (ATrajectoryRms <= 0) or (ATrajectoryRms > 16) then
  begin
    raise EAudio.Create('Style trajectory reference RMS must be in (0,16]');
  end;
  SetLength(LPrepared, SourceCount);
  LCount := 0;
  LTotal := 0;
  LMaximumHarmonics := 0;
  for LSource := 0 to SourceCount - 1 do
  begin
    if FTimbreWeights[LSource] = 0 then
    begin
      Continue;
    end;
    Inc(LTotal, FTimbreWeights[LSource]);
    LIndex := Length(FEvidence[LSource].TimbreTrajectory.Knots);
    if LIndex = 0 then
    begin
      SetLength(LPrepared[LSource].Frames, 1);
      SetLength(LPrepared[LSource].Recipes, 1);
      LShape := FactorWavetableMagnitudes(FEvidence[LSource].Timbre.Fit.Recipe);
      LPrepared[LSource].Recipes[0] := LShape.Recipe;
      LMaximumHarmonics := Max(LMaximumHarmonics, Length(LShape.Recipe.Sine));
      Continue;
    end;
    SetLength(LPrepared[LSource].Frames, LIndex);
    SetLength(LPrepared[LSource].Recipes, LIndex);
    for LKnot := 0 to LIndex - 1 do
    begin
      LFrame := (2 * (Int64(FEvidence[LSource].TimbreTrajectory.Knots[LKnot].StartFrame) -
        FEvidence[LSource].TimbreTrajectory.OriginFrame) +
        FEvidence[LSource].TimbreTrajectory.Knots[LKnot].FrameCount - 1) *
        AOutputRate div (2 * FEvidence[LSource].Source.SampleRate);
      if (LKnot > 0) and (LFrame <= LPrepared[LSource].Frames[LKnot - 1]) then
      begin
        raise EAudio.Create('Timbre knot centers collapse at the requested output rate');
      end;
      LPrepared[LSource].Frames[LKnot] := LFrame;
      AddFrame(LFrame);
      LShape := FactorWavetableMagnitudes(
        FEvidence[LSource].TimbreTrajectory.Knots[LKnot].Fit.Recipe);
      LPrepared[LSource].Recipes[LKnot] := LShape.Recipe;
      LMaximumHarmonics := Max(LMaximumHarmonics, Length(LShape.Recipe.Sine));
    end;
  end;
  SetLength(LRecipes, LCount);
  SetLength(LPoints, LCount);
  for LKnot := 0 to LCount - 1 do
  begin
    LPoints[LKnot].Frame := LFrames[LKnot];
    LPoints[LKnot].Value := LKnot;
    LPoints[LKnot].Transition := atLinear;
    SetLength(LRecipes[LKnot].Sine, LMaximumHarmonics);
    SetLength(LRecipes[LKnot].Cosine, LMaximumHarmonics);
    for LSource := 0 to SourceCount - 1 do
    begin
      if FTimbreWeights[LSource] = 0 then
      begin
        Continue;
      end;
      LIndex := 0;
      while (LIndex < High(LPrepared[LSource].Frames)) and
        (LPrepared[LSource].Frames[LIndex + 1] <= LFrames[LKnot]) do
      begin
        Inc(LIndex);
      end;
      LWeight := 0;
      if (LIndex < High(LPrepared[LSource].Frames)) and
        (LFrames[LKnot] > LPrepared[LSource].Frames[LIndex]) then
      begin
        LWeight := (LFrames[LKnot] - LPrepared[LSource].Frames[LIndex]) /
          (LPrepared[LSource].Frames[LIndex + 1] - LPrepared[LSource].Frames[LIndex]);
      end;
      LRecipe := Default(TWavetableCycleRecipe);
      SetLength(LRecipe.Sine, LMaximumHarmonics);
      for LHarmonic := 0 to LMaximumHarmonics - 1 do
      begin
        LValue := 0;
        if LHarmonic < Length(LPrepared[LSource].Recipes[LIndex].Sine) then
        begin
          LValue := (1 - LWeight) * LPrepared[LSource].Recipes[LIndex].Sine[LHarmonic];
        end;
        if (LWeight > 0) and
          (LHarmonic < Length(LPrepared[LSource].Recipes[LIndex + 1].Sine)) then
        begin
          LValue := LValue + LWeight * LPrepared[LSource].Recipes[LIndex + 1].Sine[LHarmonic];
        end;
        LRecipe.Sine[LHarmonic] := LValue;
      end;
      LShape := FactorWavetableMagnitudes(LRecipe);
      for LHarmonic := 0 to LMaximumHarmonics - 1 do
      begin
        LRecipes[LKnot].Sine[LHarmonic] := LRecipes[LKnot].Sine[LHarmonic] +
          LShape.Recipe.Sine[LHarmonic] * (FTimbreWeights[LSource] / LTotal);
      end;
    end;
  end;
  LCurve := TAutomationCurve.Create(LPoints);
  try
    Result := TWavetableSourceFactory.CreateMagnitudeTrajectory(LRecipes, LCurve, ATrajectoryRms);
  finally
    LCurve.Free;
  end;
end;

function TWaveStyleProfile.CopyContext: TContextProfile;
begin
  Result := DecodeContextProfile(EncodeContextProfile(FContext));
end;

function TWaveStyleProfile.CopyRhythmModel: TWfcSequenceModel;
begin
  Result := DecodeWfcSequenceText(EncodeWfcSequenceText(FModel));
end;

function TWaveStyleProfile.CopyIntensityModel: TWfcSequenceModel;
begin
  if not FHasDynamics then
  begin
    raise EAudio.Create('Style has no measured onset dynamics');
  end;
  Result := DecodeWfcSequenceText(EncodeWfcSequenceText(FJointModel));
end;

function TWaveStyleProfile.CopyPitchModel: TWfcSequenceModel;
begin
  if not FHasPitch then
  begin
    raise EAudio.Create('Style has no admitted monophonic pitch model');
  end;
  Result := DecodeWfcSequenceText(EncodeWfcSequenceText(FPitchModel));
end;

function TWaveStyleProfile.CopyPitchRhythmModel: TWfcSequenceModel;
begin
  if not FHasPitchRhythm then
  begin
    raise EAudio.Create('Observed pitch/rhythm requires identical source weights in both dimensions');
  end;
  Result := DecodeWfcSequenceText(EncodeWfcSequenceText(FPitchRhythmModel));
end;

function TWaveStyleProfile.CopyDurationModel: TWfcSequenceModel;
begin
  if not FHasDuration then
  begin
    raise EAudio.Create('Duration generation requires dense evidence for every active pitch source');
  end;
  Result := DecodeWfcSequenceText(EncodeWfcSequenceText(FDurationModel));
end;

function TWaveStyleProfile.CopyDurationTrack(const AIndex: Integer): TPitchTrack;
var
  LEvidence: TRhythmStyleEvidence;
begin
  LEvidence := EvidenceAt(AIndex);
  if LEvidence.Duration.WindowFrames = 0 then
  begin
    raise EAudio.Create('Source has no dense duration evidence');
  end;
  Result := TPitchTrack.CreateFromEvidence(LEvidence.Duration,
    LEvidence.Source.SampleRate, LEvidence.Source.Channels, LEvidence.Source.FrameCount);
end;

function TWaveStyleProfile.CopyTimedDurationSpans(const AIndex: Integer): TTimedPitchSpans;
var
  LEvidence: TRhythmStyleEvidence;
  LTrack: TPitchTrack;
  LClock: TTempoMap;
  LGrid: TMusicGridFrames;
  LSpans: TTimedPitchSpans;
  LAttacks: TPitchAttackTicks;
  LOnset: Integer;
  LCount: Integer;
  LFirst: Integer;
  LLast: Integer;
begin
  LEvidence := EvidenceAt(AIndex);
  LTrack := CopyDurationTrack(AIndex);
  LClock := nil;
  LGrid := nil;
  try
    LClock := CreateStyleSourceClock(LEvidence, FContext.TicksPerQuarter, FContext.StepTicks);
    LSpans := LTrack.TimedSpans(LClock, LEvidence.SourceFrameOffset,
      LEvidence.SourceStartTick, LClock.LengthTicks);
    if LEvidence.DurationArticulateOnsets then
    begin
      LGrid := CreateStyleSourceGrid(LEvidence, FContext.TicksPerQuarter, FContext.StepTicks);
      LFirst := LGrid.BoundaryAt(0);
      LLast := LGrid.BoundaryAt(LGrid.CellCount);
      SetLength(LAttacks, Length(LEvidence.OnsetFrames));
      LCount := 0;
      for LOnset := 0 to High(LEvidence.OnsetFrames) do
      begin
        if (LEvidence.OnsetFrames[LOnset] < LFirst) or
          (LEvidence.OnsetFrames[LOnset] >= LLast) then
        begin
          Continue;
        end;
        LAttacks[LCount] := LClock.NextGridTick(
          LEvidence.OnsetFrames[LOnset] - LEvidence.SourceFrameOffset,
          LEvidence.Source.SampleRate, 1);
        Inc(LCount);
      end;
      SetLength(LAttacks, LCount);
      LSpans := RearticulatePitchSpans(LSpans, LAttacks);
    end;
    Result := LSpans;
  finally
    LGrid.Free;
    LClock.Free;
    LTrack.Free;
  end;
end;

function TWaveStyleProfile.DurationTicksPerQuarter: Integer;
begin
  Result := FContext.TicksPerQuarter;
end;

function TWaveStyleProfile.PitchNotesAt(const AIndex: Integer): TPitchNotes;
var
  LEvidence: TRhythmStyleEvidence;
  LGrid: TMusicGridFrames;
begin
  LEvidence := EvidenceAt(AIndex);
  LGrid := CreateStyleSourceGrid(LEvidence, FContext.TicksPerQuarter, FContext.StepTicks);
  try
    Result := AdmitPitchCells(LEvidence.Pitch, LGrid, LEvidence.Source.Channels);
  finally
    LGrid.Free;
  end;
end;

function TWaveStyleProfile.IntensityPatternAt(const AIndex: Integer): String;
begin
  if (AIndex < 0) or (AIndex >= SourceCount) then
  begin
    raise EAudio.Create('Intensity source index outside style');
  end;
  Result := OnsetIntensityPattern(FAdmissions[AIndex], FEvidence[AIndex].Dynamics);
end;

function TWaveStyleProfile.Encode: TAudioBytes;
begin
  Result := Copy(FBytes);
end;

function DecodeAt(const ABytes: TAudioBytes; const ADepth: Integer;
  var ANodes: Integer): TWaveStyleProfile;
var
  LCursor: TStyleCursor;
  LHash: String;
  LKind: Integer;
  LOrder: Integer;
  LKeySide: Integer;
  LTempoSide: Integer;
  LLeftWeight: Integer;
  LRightWeight: Integer;
  LLeftPitchWeight: Integer;
  LRightPitchWeight: Integer;
  LCount: Integer;
  LLeftTimbreWeight: Integer;
  LRightTimbreWeight: Integer;
  LIndex: Integer;
  LLeftEnvelopeWeight: Integer;
  LRightEnvelopeWeight: Integer;
  LEvidence: TRhythmStyleEvidence;
  LContext: TContextProfile;
  LLeft: TWaveStyleProfile;
  LRight: TWaveStyleProfile;
  LResult: TWaveStyleProfile;
  LModelText: UTF8String;
  LJointText: UTF8String;
  LPitchText: UTF8String;
  LPitchRhythmText: UTF8String;
  LDurationText: UTF8String;
  LValue: Integer;
  LCapabilities: Integer;
  LPreferences: TStyleGenerationPreferences;
  LProvider: TStylePreferenceProvider;
begin
  Inc(ANodes);
  if (ADepth > MaximumStyleDepth) or (ANodes > MaximumStyleNodes) or
    (Length(ABytes) < 80) or (Length(ABytes) > MaximumStyleBytes) then
  begin
    raise EAudio.Create('Style payload/ancestry exceeds bounds');
  end;
  SetLength(LHash, 64);
  Move(ABytes[Length(ABytes) - 64], LHash[1], 64);
  if LHash <> Sha256Bytes(Copy(ABytes, 0, Length(ABytes) - 64)) then
  begin
    raise EAudio.Create('Style payload digest mismatch');
  end;
  LCursor.Bytes := ABytes;
  LCursor.Offset := 0;
  LCursor.Limit := Length(ABytes) - 64;
  if LCursor.Number <> StyleMagic then
  begin
    raise EAudio.Create('Unsupported development style archive; regenerate from source evidence');
  end;
  if LCursor.Number <> WaveStyleVersion then
  begin
    raise EAudio.Create('Unknown style archive version');
  end;
  LKind := LCursor.Number;
  LOrder := LCursor.Number;
  if (LOrder < 1) or (LOrder > 4) then
  begin
    raise EAudio.Create('Style model order must be 1..4');
  end;
  LContext := nil;
  LLeft := nil;
  LRight := nil;
  LResult := nil;
  try
    if LKind = 0 then
    begin
      LContext := DecodeContextProfile(LCursor.Blob(MaximumContextProfileBytes));
      LEvidence := Default(TRhythmStyleEvidence);
      LCapabilities := LCursor.Number;
      if LCapabilities > StyleDynamicsCapability + StylePitchCapability +
        StyleDurationCapability + StyleDurationOnsetsCapability + StyleTimbreCapability +
        StyleEnvelopeCapability + StyleTrajectoryCapability then
      begin
        raise EAudio.Create('Unknown style source capability');
      end;
      LEvidence.DurationArticulateOnsets := (LCapabilities and StyleDurationOnsetsCapability) <> 0;
      LEvidence.Source.Name := LCursor.Text(MaximumCorpusTextBytes);
      LEvidence.Source.Sha256 := LCursor.Text(64);
      LEvidence.Source.Provenance := LCursor.Text(MaximumCorpusTextBytes);
      LEvidence.Source.SampleRate := LCursor.Number;
      LEvidence.Source.Channels := LCursor.Number;
      LEvidence.Source.FrameCount := LCursor.Number;
      LEvidence.OnsetReportSha256 := LCursor.Text(64);
      LEvidence.Analysis.WindowFrames := LCursor.Number;
      LEvidence.Analysis.HopFrames := LCursor.Number;
      LEvidence.Analysis.SilenceRms := LCursor.RealValue;
      LEvidence.OnsetVersion := LCursor.Number;
      LEvidence.Policy := LCursor.Text(MaximumCorpusTextBytes);
      LEvidence.TempoMicroseconds := LCursor.Number;
      LEvidence.SourceStartTick := LCursor.Number;
      LEvidence.SourceFrameOffset := LCursor.Number;
      LEvidence.SourceCellCount := LCursor.Number;
      LCount := LCursor.Number;
      if LCount > MaximumTempoChanges then
      begin
        raise EAudio.Create('Style source tempo map exceeds change budget');
      end;
      LCursor.Need(LCount * 8);
      SetLength(LEvidence.SourceClock, LCount);
      for LIndex := 0 to LCount - 1 do
      begin
        LEvidence.SourceClock[LIndex].Tick := LCursor.Number;
        LEvidence.SourceClock[LIndex].MicrosecondsPerQuarter := LCursor.Number;
      end;
      LEvidence.MaximumErrorFrames := LCursor.Number;
      LCount := LCursor.Number;
      if LCount > 65536 then
      begin
        raise EAudio.Create('Style onset count exceeds bounds');
      end;
      LCursor.Need(LCount * 4);
      SetLength(LEvidence.OnsetFrames, LCount);
      for LIndex := 0 to LCount - 1 do
      begin
        LEvidence.OnsetFrames[LIndex] := LCursor.Number;
      end;
      if (LCapabilities and StyleDynamicsCapability) <> 0 then
      begin
        if LCursor.Number <> OnsetDynamicsVersion then
        begin
          raise EAudio.Create('Unsupported onset dynamics measurement policy');
        end;
        LEvidence.Dynamics.WindowFrames := LCursor.Number;
        if LEvidence.Dynamics.WindowFrames < 1 then
        begin
          raise EAudio.Create('Dynamic source requires a nonzero measurement window');
        end;
        LCursor.Need(LCount * 12);
        SetLength(LEvidence.Dynamics.Rms, LCount);
        for LIndex := 0 to LCount - 1 do
        begin
          LEvidence.Dynamics.Rms[LIndex] := LCursor.RealValue;
        end;
      end;
      if (LCapabilities and StylePitchCapability) <> 0 then
      begin
        if (LCursor.Number <> PitchCellsVersion) or (LCursor.Number <> PitchEstimatorVersion) then
        begin
          raise EAudio.Create('Unsupported pitch evidence/estimator version');
        end;
        LEvidence.Pitch.WindowFrames := LCursor.Number;
        if LEvidence.Pitch.WindowFrames < 1 then
        begin
          raise EAudio.Create('Pitch source requires a measurement window');
        end;
        LEvidence.Pitch.Channel := LCursor.Number;
        LEvidence.Pitch.Options.MinimumHz := LCursor.RealValue;
        LEvidence.Pitch.Options.MaximumHz := LCursor.RealValue;
        LEvidence.Pitch.Options.DifferenceThreshold := LCursor.RealValue;
        LEvidence.Pitch.Options.SilenceRms := LCursor.RealValue;
        LEvidence.Pitch.MaximumCents := LCursor.RealValue;
        LCount := LCursor.Number;
        if LCount > MaximumPitchCells then
        begin
          raise EAudio.Create('Pitch evidence cell count exceeds bounds');
        end;
        LCursor.Need(LCount * 4);
        SetLength(LEvidence.Pitch.Cells, LCount);
        for LIndex := 0 to LCount - 1 do
        begin
          LValue := LCursor.Number;
          if not (LValue in [0, 1]) then
          begin
            raise EAudio.Create('Invalid pitch measurement availability');
          end;
          LEvidence.Pitch.Cells[LIndex].Measured := LValue = 1;
          if LValue = 1 then
          begin
            LValue := LCursor.Number;
            if LValue > Ord(High(TPitchStatus)) then
            begin
              raise EAudio.Create('Unknown pitch measurement status');
            end;
            LEvidence.Pitch.Cells[LIndex].Estimate.Status := TPitchStatus(LValue);
            LEvidence.Pitch.Cells[LIndex].Estimate.FrequencyHz := LCursor.RealValue;
            LEvidence.Pitch.Cells[LIndex].Estimate.PeriodFrames := LCursor.RealValue;
            LEvidence.Pitch.Cells[LIndex].Estimate.NormalizedDifference := LCursor.RealValue;
            LEvidence.Pitch.Cells[LIndex].Estimate.AcRms := LCursor.RealValue;
            LEvidence.Pitch.Cells[LIndex].Estimate.CentsError := LCursor.RealValue;
            LValue := LCursor.Number;
            if LValue > 2048 then
            begin
              raise EAudio.Create('Pitch nearest note exceeds diagnostic bounds');
            end;
            LEvidence.Pitch.Cells[LIndex].Estimate.NearestMidi := LValue - 1024;
          end;
        end;
      end;
      if (LCapabilities and StyleDurationCapability) <> 0 then
      begin
        if LCursor.Number <> PitchEstimatorVersion then
        begin
          raise EAudio.Create('Unsupported dense pitch measurement policy');
        end;
        LEvidence.Duration.WindowFrames := LCursor.Number;
        if LEvidence.Duration.WindowFrames < 1 then
        begin
          raise EAudio.Create('Duration evidence requires a measurement window');
        end;
        LEvidence.Duration.Channel := LCursor.Number;
        LEvidence.Duration.Options.HopFrames := LCursor.Number;
        LEvidence.Duration.Options.MinimumRunWindows := LCursor.Number;
        LEvidence.Duration.Options.MaximumCents := LCursor.RealValue;
        LEvidence.Duration.Options.Pitch.MinimumHz := LCursor.RealValue;
        LEvidence.Duration.Options.Pitch.MaximumHz := LCursor.RealValue;
        LEvidence.Duration.Options.Pitch.DifferenceThreshold := LCursor.RealValue;
        LEvidence.Duration.Options.Pitch.SilenceRms := LCursor.RealValue;
        LCount := LCursor.Number;
        if LCount > MaximumPitchTrackWindows then
        begin
          raise EAudio.Create('Duration measurement count exceeds bounds');
        end;
        LCursor.Need(LCount * 68);
        SetLength(LEvidence.Duration.Estimates, LCount);
        for LIndex := 0 to LCount - 1 do
        begin
          LValue := LCursor.Number;
          if LValue > Ord(High(TPitchStatus)) then
          begin
            raise EAudio.Create('Unknown duration measurement status');
          end;
          LEvidence.Duration.Estimates[LIndex].Status := TPitchStatus(LValue);
          LEvidence.Duration.Estimates[LIndex].FrequencyHz := LCursor.RealValue;
          LEvidence.Duration.Estimates[LIndex].PeriodFrames := LCursor.RealValue;
          LEvidence.Duration.Estimates[LIndex].NormalizedDifference := LCursor.RealValue;
          LEvidence.Duration.Estimates[LIndex].AcRms := LCursor.RealValue;
          LEvidence.Duration.Estimates[LIndex].CentsError := LCursor.RealValue;
          LValue := LCursor.Number;
          if LValue > 2048 then
          begin
            raise EAudio.Create('Duration nearest note exceeds diagnostic bounds');
          end;
          LEvidence.Duration.Estimates[LIndex].NearestMidi := LValue - 1024;
        end;
      end;
      if (LCapabilities and StyleTimbreCapability) <> 0 then
      begin
        LEvidence.Timbre.StartFrame := LCursor.Number;
        LEvidence.Timbre.FrameCount := LCursor.Number;
        if LEvidence.Timbre.FrameCount = 0 then
        begin
          raise EAudio.Create('Present timbre requires a measured interval');
        end;
        LEvidence.Timbre.Channel := LCursor.Number;
        LEvidence.Timbre.MaximumRelativeError := LCursor.RealValue;
        LEvidence.Timbre.MinimumAcRms := LCursor.RealValue;
        LEvidence.Timbre.Policy := LCursor.Text(4096);
        LEvidence.Timbre.Fit.FrequencyHz := LCursor.RealValue;
        LEvidence.Timbre.Fit.AcRms := LCursor.RealValue;
        LEvidence.Timbre.Fit.ResidualRms := LCursor.RealValue;
        LEvidence.Timbre.Fit.RelativeError := LCursor.RealValue;
        LEvidence.Timbre.Fit.Recipe.Mean := LCursor.RealValue;
        LCount := LCursor.Number;
        if (LCount < 1) or (LCount > MaximumTableHarmonics) then
        begin
          raise EAudio.Create('Timbre harmonic count exceeds bounds');
        end;
        LCursor.Need(LCount * 16);
        SetLength(LEvidence.Timbre.Fit.Recipe.Sine, LCount);
        SetLength(LEvidence.Timbre.Fit.Recipe.Cosine, LCount);
        for LIndex := 0 to LCount - 1 do
        begin
          LEvidence.Timbre.Fit.Recipe.Sine[LIndex] := LCursor.RealValue;
          LEvidence.Timbre.Fit.Recipe.Cosine[LIndex] := LCursor.RealValue;
        end;
      end;
      if (LCapabilities and StyleEnvelopeCapability) <> 0 then
      begin
        LEvidence.Envelope.StartFrame := LCursor.Number;
        LEvidence.Envelope.FrameCount := LCursor.Number;
        LEvidence.Envelope.Channel := LCursor.Number;
        LEvidence.Envelope.WindowFrames := LCursor.Number;
        LEvidence.Envelope.GateFrame := LCursor.Number;
        LEvidence.Envelope.MaximumTailRatio := LCursor.RealValue;
        LEvidence.Envelope.MinimumRms := LCursor.RealValue;
        LEvidence.Envelope.Policy := LCursor.Text(4096);
        LCount := LCursor.Number;
        if (LCount < 2) or (LCount > MaximumAutomationPoints - 2) or
          (LEvidence.Envelope.FrameCount = 0) then
        begin
          raise EAudio.Create('Envelope evidence exceeds point or interval bounds');
        end;
        LCursor.Need(LCount * 12);
        SetLength(LEvidence.Envelope.RmsPoints, LCount);
        for LIndex := 0 to LCount - 1 do
        begin
          LEvidence.Envelope.RmsPoints[LIndex].Frame := LCursor.Number;
          LEvidence.Envelope.RmsPoints[LIndex].Value := LCursor.RealValue;
          LEvidence.Envelope.RmsPoints[LIndex].Transition := atLinear;
        end;
      end;
      if (LCapabilities and StyleTrajectoryCapability) <> 0 then
      begin
        LEvidence.TimbreTrajectory.OriginFrame := LCursor.Number;
        LCount := LCursor.Number;
        if (LCount < 2) or (LCount > MaximumWavetableTrajectoryRecipes) then
        begin
          raise EAudio.Create('Saved timbre trajectory exceeds knot bounds');
        end;
        SetLength(LEvidence.TimbreTrajectory.Knots, LCount);
        for LIndex := 0 to LCount - 1 do
        begin
          LEvidence.TimbreTrajectory.Knots[LIndex] := ReadHarmonicEvidence(LCursor);
        end;
      end;
      LResult := TWaveStyleProfile.CreateSource(LContext, LEvidence, LOrder);
    end
    else if LKind = 1 then
    begin
      LKeySide := LCursor.Number;
      LTempoSide := LCursor.Number;
      LLeftWeight := LCursor.Number;
      LRightWeight := LCursor.Number;
      LLeftPitchWeight := LCursor.Number;
      LRightPitchWeight := LCursor.Number;
      LLeftTimbreWeight := LCursor.Number;
      LRightTimbreWeight := LCursor.Number;
      LLeftEnvelopeWeight := LCursor.Number;
      LRightEnvelopeWeight := LCursor.Number;
      LLeft := DecodeAt(LCursor.Blob(MaximumStyleBytes), ADepth + 1, ANodes);
      LRight := DecodeAt(LCursor.Blob(MaximumStyleBytes), ADepth + 1, ANodes);
      LResult := TWaveStyleProfile.CreateBlendLayers(LLeft, LRight,
        LKeySide, LTempoSide, LLeftWeight, LRightWeight, LLeftPitchWeight, LRightPitchWeight,
        LLeftTimbreWeight, LRightTimbreWeight, LLeftEnvelopeWeight, LRightEnvelopeWeight);
      if LResult.Order <> LOrder then
      begin
        raise EAudio.Create('Style blend order disagrees with parents');
      end;
    end
    else
    begin
      if LKind <> 2 then
      begin
        raise EAudio.Create('Unknown style node kind');
      end;
      LLeft := DecodeAt(LCursor.Blob(MaximumStyleBytes), ADepth + 1, ANodes);
      LPreferences := Default(TStyleGenerationPreferences);
      for LProvider := Low(LProvider) to High(LProvider) do
      begin
        LCount := LCursor.Number;
        if (LCount < 0) or (LCount > MaximumLayerPreferences) then
        begin
          raise EAudio.Create('Saved preference count exceeds layer bounds');
        end;
        SetLength(LPreferences[LProvider], LCount);
        for LIndex := 0 to LCount - 1 do
        begin
          LPreferences[LProvider][LIndex].Token := LCursor.Text(MaximumStyleBytes);
          LPreferences[LProvider][LIndex].Multiplier := LCursor.Number;
        end;
      end;
      LResult := TWaveStyleProfile.CreatePreferred(LLeft, LPreferences);
      if LResult.Order <> LOrder then
      begin
        raise EAudio.Create('Preferred style order disagrees with parent');
      end;
    end;
    LModelText := LCursor.Text(262144);
    LJointText := LCursor.Text(262144);
    LPitchText := LCursor.Text(262144);
    LPitchRhythmText := LCursor.Text(262144);
    LDurationText := LCursor.Text(262144);
    if (LJointText <> OptionalModelText(LResult.FJointModel)) or
      (LPitchText <> OptionalModelText(LResult.FPitchModel)) or
      (LPitchRhythmText <> OptionalModelText(LResult.FPitchRhythmModel)) or
      (LDurationText <> OptionalModelText(LResult.FDurationModel)) then
    begin
      raise EAudio.Create('Style optional model/evidence replay differs');
    end;
    if (LCursor.Offset <> LCursor.Limit) or
      (LModelText <> EncodeWfcSequenceText(LResult.FModel)) or
      (LResult.Identity <> Sha256Bytes(ABytes)) then
    begin
      raise EAudio.Create('Style evidence/model/canonical archive replay differs');
    end;
    Result := LResult;
    LResult := nil;
  finally
    LResult.Free;
    LRight.Free;
    LLeft.Free;
    LContext.Free;
  end;
end;

function DecodeWaveStyle(const ABytes: TAudioBytes): TWaveStyleProfile;
var
  LNodes: Integer;
begin
  LNodes := 0;
  Result := DecodeAt(ABytes, 1, LNodes);
end;

end.
