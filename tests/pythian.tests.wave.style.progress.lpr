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
program pythian_tests_wave_style_progress;

{$mode delphi}{$H+}

uses
  Classes, SysUtils, Math,
  pythian.audio, pythian.analysis, pythian.progress, pythian.hash,
  pythian.time, pythian.music.grid.frames, pythian.music.context,
  pythian.tonal, pythian.onset, pythian.onset.dynamics,
  pythian.pitch, pythian.pitch.cells, pythian.pitch.track,
  pythian.automation, pythian.envelope, pythian.source,
  pythian.source.wavetable, pythian.tools.files,
  pythian.wfc.context, pythian.wfc.context.profile,
  pythian.wfc.context.archive, pythian.wfc.style,
  wfc_sequence, wfc_sequence_text;

type
  TObserver = class
  public
    Stages: TStringList;
    Started: TStringList;
    MaximumMs: TStringList;
    AbortStage: String;
    AbortMinimum: Int64;
    InteriorOnly: Boolean;
    CompletionOnly: Boolean;
    Marker: Exception;
    Calls: Integer;
    constructor Create;
    destructor Destroy; override;
    procedure Observe(const AWork: TWorkProgress);
  end;

var
  GChecks: Integer;
  GObserver: TObserver;
  GEvidence: TRhythmStyleEvidence;
  GTrajectoryEvidence: TRhythmStyleEvidence;
  GContext: TContextProfile;
  GLeft: TWaveStyleProfile;
  GRight: TWaveStyleProfile;
  GNested: TWaveStyleProfile;
  GTrajectory: TWaveStyleProfile;
  GArchive: TAudioBytes;
  GPreferences: TStyleGenerationPreferences;

procedure Check(const ACondition: Boolean; const AMessage: String);
begin
  Inc(GChecks);
  if not ACondition then
  begin
    raise Exception.Create(AMessage);
  end;
end;

constructor TObserver.Create;
begin
  inherited Create;
  Stages := TStringList.Create;
  Stages.Sorted := True;
  Stages.Duplicates := dupIgnore;
  Started := TStringList.Create;
  MaximumMs := TStringList.Create;
end;

destructor TObserver.Destroy;
begin
  Marker.Free;
  MaximumMs.Free;
  Started.Free;
  Stages.Free;
  inherited Destroy;
end;

procedure TObserver.Observe(const AWork: TWorkProgress);
var
  LElapsed: QWord;
begin
  Inc(Calls);
  if (AWork.Done < 0) or (AWork.Total < 0) or
    ((AWork.Total > 0) and (AWork.Done > AWork.Total)) then
    raise Exception.Create('Invalid work counts');
  Stages.Add(AWork.Stage);
  if (AWork.Units = wuItems) and (AWork.Total = 1) then
  begin
    if AWork.Done = 0 then
      Started.Values[AWork.Stage] := UIntToStr(GetTickCount64)
    else if Started.Values[AWork.Stage] <> '' then
    begin
      LElapsed := GetTickCount64 - StrToQWord(Started.Values[AWork.Stage]);
      if LElapsed > StrToQWordDef(MaximumMs.Values[AWork.Stage], 0) then
        MaximumMs.Values[AWork.Stage] := UIntToStr(LElapsed)
      else if MaximumMs.Values[AWork.Stage] = '' then
        MaximumMs.Values[AWork.Stage] := '0';
    end;
  end;
  if (AWork.Stage = 'wave_context_cells') or
    (AWork.Stage = 'wave_rhythm_tokens') or (AWork.Stage = 'wave_intensity_tokens') then
  begin
    if AWork.Total <> 600 then
    begin
      raise Exception.Create('False source-cell total');
    end;
  end;
  if (AWork.Stage = AbortStage) and (AWork.Done >= AbortMinimum) and
    (not CompletionOnly or ((AWork.Total > 0) and (AWork.Done = AWork.Total))) and
    (not InteriorOnly or (AWork.Total = 0) or (AWork.Done < AWork.Total)) then
  begin
    raise Marker;
  end;
end;

function Pitch(const ANote: Integer): TPitchEstimate;
begin
  Result := Default(TPitchEstimate);
  Result.Status := psEstimated;
  Result.FrequencyHz := 440 * Power(2, (ANote - 69) / 12);
  Result.PeriodFrames := 1000 / Result.FrequencyHz;
  Result.AcRms := 0.1;
  Result.NearestMidi := ANote;
  Result.CentsError := 100 * (69 + 12 * Log2(Result.FrequencyHz / 440) - ANote);
end;

procedure Prepare;
const
  CCells = 600;
var
  LCells: TContextEvidenceArray;
  LBundle: TContextLearningBundle;
  LClip: TAudioClip;
  LTrace: TEnvelopeTrace;
  LSamples: TAudioSamples;
  LIndex: Integer;
begin
  GEvidence := Default(TRhythmStyleEvidence);
  GEvidence.Source.Name := 'Authored profile callback source';
  GEvidence.Source.Sha256 := HashText(GEvidence.Source.Name);
  GEvidence.Source.Provenance := 'Declared fixture, no recorded accuracy claim';
  GEvidence.Source.SampleRate := 1000;
  GEvidence.Source.Channels := 1;
  GEvidence.Source.FrameCount := CCells * 250;
  GEvidence.OnsetReportSha256 := HashText('Authored onsets');
  GEvidence.Analysis := DefaultAnalysisOptions;
  GEvidence.OnsetVersion := OnsetLocationVersion;
  GEvidence.Policy := 'Authored constant clock and pitch declarations';
  GEvidence.TempoMicroseconds := 500000;
  SetLength(GEvidence.OnsetFrames, CCells div 2);
  GEvidence.Pitch.WindowFrames := 40;
  GEvidence.Pitch.Options := DefaultPitchOptions;
  GEvidence.Pitch.Options.MaximumHz := 440;
  GEvidence.Pitch.MaximumCents := 25;
  SetLength(GEvidence.Pitch.Cells, CCells);
  GEvidence.Duration.WindowFrames := 40;
  GEvidence.Duration.Options := DefaultPitchTrackOptions(1000);
  GEvidence.Duration.Options.Pitch := GEvidence.Pitch.Options;
  GEvidence.Duration.Options.HopFrames := 20;
  GEvidence.DurationArticulateOnsets := True;
  SetLength(GEvidence.Duration.Estimates, 1 +
    (GEvidence.Source.FrameCount - GEvidence.Duration.WindowFrames) div 20);
  GEvidence.Dynamics.WindowFrames := 16;
  SetLength(GEvidence.Dynamics.Rms, Length(GEvidence.OnsetFrames));
  SetLength(LCells, 1);
  LCells[0].Name := GEvidence.Source.Name;
  LCells[0].SourceSha256 := GEvidence.Source.Sha256;
  LCells[0].AdmissionPolicy := GEvidence.Policy;
  LCells[0].Grid.TicksPerQuarter := 480;
  LCells[0].Grid.StepTicks := 240;
  SetLength(LCells[0].Grid.Keys, CCells);
  SetLength(LCells[0].Grid.Tempos, CCells);
  for LIndex := 0 to CCells - 1 do
  begin
    LCells[0].Grid.Keys[LIndex] := MakeKeyContext(0, dmMajor);
    LCells[0].Grid.Tempos[LIndex] := 500000;
    GEvidence.Pitch.Cells[LIndex].Measured := True;
    GEvidence.Pitch.Cells[LIndex].Estimate := Pitch(60 + (LIndex div 2) mod 3);
  end;
  for LIndex := 0 to High(GEvidence.OnsetFrames) do
  begin
    GEvidence.OnsetFrames[LIndex] := LIndex * 500;
    GEvidence.Dynamics.Rms[LIndex] := 0.1 + 0.05 * (LIndex mod 3);
  end;
  for LIndex := 0 to High(GEvidence.Duration.Estimates) do
  begin
    GEvidence.Duration.Estimates[LIndex] := Pitch(60 + (LIndex div 25) mod 3);
  end;
  SetLength(LSamples, 96);
  for LIndex := 0 to High(LSamples) do
  begin
    if (LIndex >= 16) and (LIndex < 64) then
    begin
      LSamples[LIndex] := 0.5 * (1 - 2 * (LIndex mod 2));
    end;
  end;
  LClip := TAudioClip.Create(1000, 1, LSamples);
  LTrace := nil;
  LBundle := nil;
  try
    LTrace := TEnvelopeTrace.Create(LClip, 0, 96, 0, 16);
    GEvidence.Envelope.FrameCount := 96;
    GEvidence.Envelope.WindowFrames := 16;
    GEvidence.Envelope.GateFrame := 39;
    GEvidence.Envelope.MaximumTailRatio := 0.01;
    GEvidence.Envelope.MinimumRms := 1E-5;
    GEvidence.Envelope.Policy := 'Authored envelope with a silent tail';
    GEvidence.Envelope.RmsPoints := LTrace.CopyRmsPoints;
    GEvidence.Timbre.FrameCount := 512;
    GEvidence.Timbre.Policy := 'Authored stationary harmonic evidence';
    GEvidence.Timbre.MaximumRelativeError := 0.01;
    GEvidence.Timbre.MinimumAcRms := 1E-5;
    GEvidence.Timbre.Fit.FrequencyHz := 10;
    GEvidence.Timbre.Fit.AcRms := Sqrt(0.005);
    SetLength(GEvidence.Timbre.Fit.Recipe.Sine, 16);
    SetLength(GEvidence.Timbre.Fit.Recipe.Cosine, 16);
    GEvidence.Timbre.Fit.Recipe.Sine[0] := 0.1;
    LBundle := TContextLearningBundle.Create(LCells);
    GContext := TContextProfile.Create(LBundle);
  finally
    LBundle.Free;
    LTrace.Free;
    LClip.Free;
  end;
end;

function ContextForSource(const AEvidence: TRhythmStyleEvidence): TContextProfile;
var
  LBundle: TContextLearningBundle;
  LCells: TContextEvidenceArray;
begin
  LBundle := GContext.CopyBundle(cdTempo);
  try
    LCells := LBundle.CopyEvidence;
  finally
    LBundle.Free;
  end;
  LCells[0].Name := AEvidence.Source.Name;
  LCells[0].SourceSha256 := AEvidence.Source.Sha256;
  LBundle := TContextLearningBundle.Create(LCells);
  try
    Result := TContextProfile.Create(LBundle);
  finally
    LBundle.Free;
  end;
end;

function Exercise(const AOperation: Integer;
  const ACallback: TWorkProgressCallback): String;
var
  LStyle: TWaveStyleProfile;
  LModel: TWfcSequenceModel;
  LContext: TContextProfile;
  LTrack: TPitchTrack;
  LFactory: TWavetableSourceFactory;
  LEnvelope: TGateEnvelope;
  LClock: TTempoMap;
  LGrid: TMusicGridFrames;
  LEvidence: TRhythmStyleEvidence;
begin
  LStyle := nil;
  LModel := nil;
  LContext := nil;
  LTrack := nil;
  LFactory := nil;
  LEnvelope := nil;
  LClock := nil;
  LGrid := nil;
  Result := '';
  try
    case AOperation of
      0: LStyle := TWaveStyleProfile.CreateSource(GContext, GEvidence, 2, ACallback);
      1: LStyle := TWaveStyleProfile.CreateBlend(GLeft, GRight, 0, 1, 1, 2, ACallback);
      2: LStyle := TWaveStyleProfile.CreatePreferred(GNested, GPreferences, ACallback);
      3: LStyle := DecodeWaveStyle(GArchive, ACallback);
      4: Result := Sha256Bytes(GNested.Encode(ACallback));
      5: LStyle := GNested.CopyParent(0, ACallback);
      6: LContext := GNested.CopyContext(ACallback);
      7: LModel := GNested.CopyRhythmModel(ACallback);
      8: LModel := GNested.CopyIntensityModel(ACallback);
      9: LModel := GNested.CopyPitchModel(ACallback);
      10: LModel := GNested.CopyPitchRhythmModel(ACallback);
      11: LModel := GNested.CopyDurationModel(ACallback);
      12: LTrack := GNested.CopyDurationTrack(0, ACallback);
      13: Result := IntToStr(Length(GNested.CopyTimedDurationSpans(0, ACallback)));
      14: Result := IntToStr(Length(GNested.PitchNotesAt(0, ACallback)));
      15: Result := GNested.IntensityPatternAt(0, ACallback);
      16:
        begin
          LEvidence := GNested.EvidenceAt(0, ACallback);
          Result := IntToStr(Length(LEvidence.Duration.Estimates));
          LEvidence.Duration.Estimates[0].AcRms := 1;
        end;
      17: Result := GNested.AdmissionAt(0, ACallback).Pattern;
      18: Result := IntToStr(Length(GNested.CopyGenerationPreferences(ACallback)[sppRhythm]));
      19: Result := IntToStr(Length(GNested.CopyTimbreRecipe(ACallback).Sine));
      20: LFactory := GNested.CopyTimbreFactory(1000, 0.1, ACallback);
      21: LEnvelope := GNested.CopyGateEnvelope(1000, ACallback);
      22: LClock := CreateStyleSourceClock(GEvidence, 480, 240, ACallback);
      23: LGrid := CreateStyleSourceGrid(GEvidence, 480, 240, ACallback);
      24: LStyle := TWaveStyleProfile.CreateSource(GContext, GTrajectoryEvidence, 2, ACallback);
      25: LFactory := GTrajectory.CopyTimbreFactory(1000, 0.1, ACallback);
    end;
    if LStyle <> nil then
    begin
      Result := Sha256Bytes(LStyle.Encode);
    end;
    if LModel <> nil then
    begin
      Result := EncodeWfcSequenceText(LModel);
    end;
    if LContext <> nil then
    begin
      Result := Sha256Bytes(EncodeContextProfile(LContext));
    end;
    if LTrack <> nil then
    begin
      Result := IntToStr(LTrack.RunCount);
    end;
    if LFactory <> nil then
    begin
      Result := IntToStr(LFactory.Channels);
    end;
    if LEnvelope <> nil then
    begin
      Result := FloatToStr(LEnvelope.ValueAt(30, 39));
    end;
    if LClock <> nil then
    begin
      Result := IntToStr(LClock.LengthTicks);
    end;
    if LGrid <> nil then
    begin
      Result := IntToStr(LGrid.CellCount);
    end;
  finally
    LGrid.Free;
    LClock.Free;
    LEnvelope.Free;
    LFactory.Free;
    LTrack.Free;
    LContext.Free;
    LModel.Free;
    LStyle.Free;
  end;
end;

procedure AbortAndRetry(const AOperation: Integer; const AStage: String;
  const AMinimum: Int64; const AInterior: Boolean;
  const ACompletion: Boolean = False);
var
  LBefore: String;
  LExpected: String;
  LRejected: Boolean;
begin
  LBefore := Sha256Bytes(GNested.Encode);
  LExpected := Exercise(AOperation, nil);
  GObserver.AbortStage := AStage;
  GObserver.AbortMinimum := AMinimum;
  GObserver.InteriorOnly := AInterior;
  GObserver.CompletionOnly := ACompletion;
  GObserver.Marker := Exception.Create('Big Boss original observer exception');
  LRejected := False;
  try
    try
      Exercise(AOperation, GObserver.Observe);
    except
      on LException: Exception do
      begin
        if LException <> GObserver.Marker then
        begin
          raise;
        end;
        GObserver.Marker := nil;
        LRejected := True;
      end;
    end;
  finally
    GObserver.Marker.Free;
    GObserver.Marker := nil;
    GObserver.AbortStage := '';
  end;
  Check(LRejected, 'Missing original abort: ' + AStage);
  Check(Exercise(AOperation, GObserver.Observe) = LExpected, 'Retry differs: ' + AStage);
  Check(Sha256Bytes(GNested.Encode) = LBefore, 'Borrowed parent changed: ' + AStage);
end;

procedure AudioParity(const AProfile: TWaveStyleProfile);
var
  LA: TWavetableSourceFactory;
  LB: TWavetableSourceFactory;
  LSourceA: TAudioSource;
  LSourceB: TAudioSource;
  LLeftA: Double;
  LRightA: Double;
  LLeftB: Double;
  LRightB: Double;
  LIndex: Integer;
begin
  LA := AProfile.CopyTimbreFactory(1000);
  LB := nil;
  LSourceA := nil;
  LSourceB := nil;
  try
    LB := AProfile.CopyTimbreFactory(1000, 0.1, GObserver.Observe);
    LSourceA := LA.CreateSource(1000, 42);
    LSourceB := LB.CreateSource(1000, 42);
    for LIndex := 0 to 2047 do
    begin
      Check(LSourceA.ReadFrame(50, LLeftA, LRightA) =
        LSourceB.ReadFrame(50, LLeftB, LRightB), 'Observed audio lifetime');
      Check((LLeftA = LLeftB) and (LRightA = LRightB), 'Observed PCM differs');
    end;
  finally
    LSourceB.Free;
    LSourceA.Free;
    LB.Free;
    LA.Free;
  end;
end;

function ReplayedSourceIdentity(const AContext: TContextProfile;
  const AEvidence: TRhythmStyleEvidence): String;
var
  LStyle: TWaveStyleProfile;
begin
  LStyle := TWaveStyleProfile.CreateSource(AContext, AEvidence, 2);
  try
    Result := LStyle.Identity;
  finally
    LStyle.Free;
  end;
end;

var
  LIndex: Integer;
  LKnot: Integer;
  LOtherEvidence: TRhythmStyleEvidence;
  LOtherContext: TContextProfile;
  LBase: TWaveStyleProfile;
  LPreferred: TWaveStyleProfile;
  LContextHash: String;
begin
  GObserver := TObserver.Create;
  LOtherContext := nil;
  LBase := nil;
  LPreferred := nil;
  try
    Prepare;
    LContextHash := Sha256Bytes(EncodeContextProfile(GContext));
    GLeft := TWaveStyleProfile.CreateSource(GContext, GEvidence, 2);
    LOtherEvidence := GLeft.EvidenceAt(0);
    { Distinct source and matching context; no new inference or recording. }
    LOtherEvidence.Source.Name := 'Authored second callback source';
    LOtherEvidence.Source.Sha256 := HashText(LOtherEvidence.Source.Name);
    LOtherContext := ContextForSource(LOtherEvidence);
    GRight := TWaveStyleProfile.CreateSource(LOtherContext, LOtherEvidence, 2);
    SetLength(GPreferences[sppRhythm], 2);
    GPreferences[sppRhythm][0].Token := RhythmOnsetToken;
    GPreferences[sppRhythm][0].Multiplier := 2;
    GPreferences[sppRhythm][1].Token := RhythmEmptyToken;
    GPreferences[sppRhythm][1].Multiplier := 3;
    LBase := TWaveStyleProfile.CreateBlend(GLeft, GRight, 0, 1, 1, 2);
    LPreferred := TWaveStyleProfile.CreatePreferred(LBase, GPreferences);
    GNested := TWaveStyleProfile.CreateBlend(LPreferred, GLeft, 1, 0, 2, 1);
    Check(GNested.SourceCount = 2, 'Fixture requires distinct source evidence');
    GArchive := GNested.Encode;
    GTrajectoryEvidence := GLeft.EvidenceAt(0);
    GTrajectoryEvidence.Timbre := Default(THarmonicStyleEvidence);
    SetLength(GTrajectoryEvidence.TimbreTrajectory.Knots, 16);
    for LKnot := 0 to 15 do
    begin
      GTrajectoryEvidence.TimbreTrajectory.Knots[LKnot] := GEvidence.Timbre;
      GTrajectoryEvidence.TimbreTrajectory.Knots[LKnot].StartFrame := LKnot * 500;
      GTrajectoryEvidence.TimbreTrajectory.Knots[LKnot].Fit.Recipe.Sine :=
        Copy(GEvidence.Timbre.Fit.Recipe.Sine);
      GTrajectoryEvidence.TimbreTrajectory.Knots[LKnot].Fit.Recipe.Sine[0] := 0;
      GTrajectoryEvidence.TimbreTrajectory.Knots[LKnot].Fit.Recipe.Sine[LKnot] := 0.1;
    end;
    GTrajectory := TWaveStyleProfile.CreateSource(GContext, GTrajectoryEvidence, 2);
    for LIndex := 0 to 25 do
    begin
      Check(Exercise(LIndex, nil) = Exercise(LIndex, GObserver.Observe),
        'Observed operation differs: ' + IntToStr(LIndex));
    end;
    AbortAndRetry(0, 'wave_context_cells', 256, True);
    AbortAndRetry(0, 'wave_rhythm_tokens', 256, True);
    AbortAndRetry(0, 'wave_intensity_tokens', 256, True);
    AbortAndRetry(0, 'wave_archive_fields', 4096, True);
    AbortAndRetry(0, 'wave_archive_hash', 65536, True);
    AbortAndRetry(1, 'wave_blend_sources', 1, True);
    AbortAndRetry(2, 'wave_preference_tokens', 1, False);
    AbortAndRetry(3, 'wave_archive_input', 4096, True);
    AbortAndRetry(3, 'wave_archive_blob', 65536, True);
    AbortAndRetry(3, 'wave_archive_nodes', GNested.NodeCount, False, True);
    AbortAndRetry(4, 'wave_archive_copy', 65536, True);
    AbortAndRetry(5, 'wave_parent_copy', 1, False);
    AbortAndRetry(6, 'wave_context_copy', 1, False);
    AbortAndRetry(7, 'wave_model_copy', 1, False);
    AbortAndRetry(12, 'wave_duration_track', 1, False);
    AbortAndRetry(13, 'wave_duration_onsets', 256, True);
    AbortAndRetry(16, 'wave_evidence_components', 3, True);
    AbortAndRetry(17, 'wave_admission_copy', 1, True);
    AbortAndRetry(18, 'wave_preference_copy', 1, True);
    AbortAndRetry(20, 'wave_timbre_factory', 1, False);
    AbortAndRetry(21, 'wave_envelope_blend', 1, False);
    AbortAndRetry(22, 'wave_source_clock', 1, False);
    AbortAndRetry(23, 'wave_source_grid', 1, False);
    AbortAndRetry(24, 'wave_timbre_knots', 1, True);
    AbortAndRetry(25, 'wave_trajectory_coefficients', 256, True);
    AbortAndRetry(25, 'wave_timbre_factory', 1, False);
    AudioParity(GNested);
    AudioParity(GTrajectory);
    { Replay actual returned evidence, not just the profiles' cached archives. }
    Check(ReplayedSourceIdentity(GContext, GEvidence) = GLeft.Identity,
      'Borrowed source record changed');
    Check(ReplayedSourceIdentity(GContext, GLeft.EvidenceAt(0)) = GLeft.Identity,
      'Borrowed left evidence changed');
    Check(ReplayedSourceIdentity(LOtherContext, GRight.EvidenceAt(0)) = GRight.Identity,
      'Borrowed right evidence changed');
    Check(ReplayedSourceIdentity(GContext, GNested.EvidenceAt(0)) = GLeft.Identity,
      'Nested left evidence changed');
    Check(ReplayedSourceIdentity(LOtherContext, GNested.EvidenceAt(1)) = GRight.Identity,
      'Nested right evidence changed');
    Check(Sha256Bytes(EncodeContextProfile(GContext)) = LContextHash,
      'Borrowed context changed');
    if ParamCount = 1 then
    begin
      WriteFileBytes(ParamStr(1) + '.source.pys', GLeft.Encode);
      WriteFileBytes(ParamStr(1) + '.nested.pys', GArchive);
      WriteFileBytes(ParamStr(1) + '.trajectory.pys', GTrajectory.Encode);
    end;
    WriteLn('Wave profile progress: ', GChecks, ' checks, ', GObserver.Stages.Count,
      ' stages; exact models/archives/PCM, original aborts, borrowed inputs and retries pass');
    WriteLn('Reported synchronous call intervals (ms; local fixture, no latency bound):');
    Write(GObserver.MaximumMs.Text);
  finally
    LPreferred.Free;
    LBase.Free;
    LOtherContext.Free;
    GTrajectory.Free;
    GNested.Free;
    GRight.Free;
    GLeft.Free;
    GContext.Free;
    GObserver.Free;
  end;
end.
