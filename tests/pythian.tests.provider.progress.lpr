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
program pythian_tests_provider_progress;

{$mode delphi}
{$H+}

uses
  SysUtils, pythian.audio, pythian.hash, pythian.progress, pythian.time,
  pythian.chord.stream, pythian.wfc.music,
  pythian.wfc.provider.codecs, pythian.wfc.providers,
  pythian.wfc.provider.contracts, pythian.wfc.layers,
  wfc, wfc_model, wfc_sequence, wfc_sequence_learn, wfc_sequence_text,
  wfc_music, wfc_music_sequence, wfc_music_ensemble, wfc_music_ensemble_graph;

const
  CModelChoices = 128;
  CCells = 1024;
  CRegistryEntries = 64;

type
  TEchoCodec = class(TProviderCodec)
  public
    Configurations: Integer;
    function CanonicalConfiguration(const AConfiguration: TAudioBytes): TAudioBytes; override;
    function Decode(const AConfiguration: TAudioBytes;
      const AToken: String): TProviderCodecChoice; override;
    function Encode(const AConfiguration: TAudioBytes;
      const AChoice: TProviderCodecChoice): String; override;
  end;
  TAbortPoint = (apInterior, apFinal, apStart, apSpentDispatch);
  TObserver = class
  public
    Calls: Integer;
    ByteCalls: Integer;
    GridTotal: Int64;
    SourceTotal: Int64;
    ChoiceTotal: Int64;
    RegistryTotal: Int64;
    CapacityTotal: Int64;
    ComparedBytes: Int64;
    ComparedTotal: Int64;
    Stage: String;
    Point: TAbortPoint;
    Minimum: Int64;
    Marker: Exception;
    procedure Observe(const AWork: TWorkProgress);
  end;

var
  GChecks: Integer;
  GAborts: Integer;
  GObserver: TObserver;
  GCodec: TEchoCodec;
  GRegistry: TProviderCodecRegistry;
  GModel: TWfcSequenceModel;
  GContract: TProviderContract;
  GExpected: TStyleProviderChoices;
  GModelText: String;
  GConfigurationHash: String;

procedure Check(const ACondition: Boolean; const AMessage: String);
begin
  Inc(GChecks);
  if not ACondition then
  begin
    raise EAudio.Create(AMessage);
  end;
end;

function Bytes(const AText: String): TAudioBytes;
begin
  Result := nil;
  SetLength(Result, Length(AText));
  if Length(Result) > 0 then
  begin
    Move(AText[1], Result[0], Length(Result));
  end;
end;

function TEchoCodec.CanonicalConfiguration(const AConfiguration: TAudioBytes): TAudioBytes;
begin
  Inc(Configurations);
  Result := Copy(AConfiguration);
end;

function TEchoCodec.Decode(const AConfiguration: TAudioBytes;
  const AToken: String): TProviderCodecChoice;
begin
  Result := Default(TProviderCodecChoice);
  Result.Bytes := Bytes(AToken);
end;

function TEchoCodec.Encode(const AConfiguration: TAudioBytes;
  const AChoice: TProviderCodecChoice): String;
begin
  Result := '';
  SetLength(Result, Length(AChoice.Bytes));
  if Length(Result) > 0 then
  begin
    Move(AChoice.Bytes[0], Result[1], Length(Result));
  end;
end;

procedure TObserver.Observe(const AWork: TWorkProgress);
var
  LAbort: Boolean;
begin
  Inc(Calls);
  Check((AWork.Done >= 0) and (AWork.Total >= 0) and
    ((AWork.Total = 0) or (AWork.Done <= AWork.Total)), 'Invalid provider work count');
  if AWork.Units = wuBytes then
  begin
    Inc(ByteCalls);
  end;
  if AWork.Stage = 'provider_grid_boundaries' then GridTotal := AWork.Total;
  if AWork.Stage = 'provider_source_boundaries' then SourceTotal := AWork.Total;
  if AWork.Stage = 'provider_decode_choices' then ChoiceTotal := AWork.Total;
  if AWork.Stage = 'provider_registry_entries' then RegistryTotal := AWork.Total;
  if AWork.Stage = 'provider_voice_capacity_visits' then CapacityTotal := AWork.Total;
  if AWork.Stage = 'provider_codec_compare_bytes' then
  begin
    ComparedBytes := AWork.Done;
    ComparedTotal := AWork.Total;
  end;
  LAbort := False;
  case Point of
    apInterior: LAbort := (AWork.Done > 0) and
      ((AWork.Total = 0) or (AWork.Done < AWork.Total));
    apFinal: LAbort := (AWork.Total > 0) and (AWork.Done = AWork.Total);
    apStart: LAbort := AWork.Done = 0;
    apSpentDispatch: LAbort := (AWork.Total = 0) and (AWork.Done >= Minimum);
  end;
  if (Marker <> nil) and (AWork.Stage = Stage) and (AWork.Done >= Minimum) and LAbort then
  begin
    raise Marker;
  end;
end;

procedure SameChoices(const ALeft, ARight: TStyleProviderChoices);
var
  I: Integer;
begin
  Check(Length(ALeft) = Length(ARight), 'Provider choice count changed');
  for I := 0 to High(ALeft) do
  begin
    Check((ALeft[I].Token = ARight[I].Token) and
      (ALeft[I].CallerValue.IsUnknown = ARight[I].CallerValue.IsUnknown) and
      (Sha256Bytes(ALeft[I].CallerValue.Bytes) = Sha256Bytes(ARight[I].CallerValue.Bytes)),
      'Provider choice identity changed');
  end;
end;

function Declaration(const AIndex: Integer): TProviderCodecDeclaration;
begin
  Result := Default(TProviderCodecDeclaration);
  Result.Identity := 'test.example/progress-' + IntToStr(AIndex);
  Result.Version := 1;
  Result.Units := 'authored-ascii-value';
  Result.UnknownMeaning := 'explicit-no-unknown';
  Result.ClockMeaning := 'explicit-ppq-grid';
  Result.ConfigurationWork := 3;
  Result.DecodeWork := 5;
  Result.EncodeWork := 7;
  Result.MaximumPayloadBytes := 4096;
  Result.MaximumTokenBytes := 4096;
end;

procedure Prepare;
var
  LDeclaration: TProviderCodecDeclaration;
  LTokens: TWfcModelTokens;
  I: Integer;
begin
  for I := 0 to CRegistryEntries - 1 do
  begin
    GRegistry.RegisterCodec(Declaration(I), GCodec);
  end;
  GRegistry.Seal;
  LDeclaration := Declaration(CRegistryEntries - 1);
  GContract := Default(TProviderContract);
  GContract.Name := 'authored-provider';
  GContract.Vocabulary := spvCaller;
  GContract.CodecBinding.Identity := LDeclaration.Identity;
  GContract.CodecBinding.Version := LDeclaration.Version;
  GContract.CodecBinding.Units := LDeclaration.Units;
  GContract.CodecBinding.UnknownMeaning := LDeclaration.UnknownMeaning;
  GContract.CodecBinding.ClockMeaning := LDeclaration.ClockMeaning;
  SetLength(GContract.CodecBinding.Configuration, MaximumProviderCodecConfigurationBytes);
  for I := 0 to High(GContract.CodecBinding.Configuration) do
  begin
    GContract.CodecBinding.Configuration[I] := $51;
  end;
  GContract.UnknownPolicy := LDeclaration.UnknownMeaning;
  GContract.MusicalDomain := 'authored-clock';
  GContract.TicksPerQuarter := 120;
  GContract.Scope := MakeLayerScope(CCells, wseWrap);
  GContract.TimeGrid := MakeLayerTimeGrid(0, 4);
  GContract.Source.SourceSha256 := StringOfChar('a', 64);
  GContract.Source.MeasurementIdentity := 'authored-frame-oracle';
  GContract.Source.SampleRate := 8000;
  GContract.Source.SourceFrames := (CCells * 400 + 2) div 3;
  GContract.Source.SourceTicksPerQuarter := 120;
  GContract.Source.SourceLengthTicks := CCells * 4;
  GContract.Source.TempoChanges := [MakeTempoChange(0, 500000)];
  SetLength(GContract.Source.OriginalTicks, CCells + 1);
  SetLength(GContract.Source.OriginalFrames, CCells + 1);
  for I := 0 to CCells do
  begin
    GContract.Source.OriginalTicks[I] := I * 4;
    GContract.Source.OriginalFrames[I] := I * 400 div 3;
  end;
  SetLength(LTokens, CModelChoices * 2);
  for I := 0 to High(LTokens) do LTokens[I] := 'v:' + IntToStr(I mod CModelChoices);
  GModel := LearnSequenceModelCorpus([MakeWfcSequenceSample(LTokens)], 1);
  GModelText := EncodeWfcSequenceText(GModel);
  GConfigurationHash := Sha256Bytes(GContract.CodecBinding.Configuration);
  GExpected := AdmitProviderContract(GModel, GContract, GRegistry);
end;

procedure CheckAdmissionBudget;
var
  LAdmission: TProviderCodecAdmission;
  LChoices: TStyleProviderChoices;
  LTokenBytes: UInt64;
  I: Integer;
begin
  LAdmission := TProviderCodecAdmission.Create(GRegistry);
  try
    LChoices := AdmitProviderContract(GModel, GContract, GRegistry, LAdmission, GObserver.Observe);
    SameChoices(GExpected, LChoices);
    LTokenBytes := 0;
    for I := 0 to High(GExpected) do Inc(LTokenBytes, Length(GExpected[I].Token));
    Check(LAdmission.RemainingDispatches = MaximumProviderCodecDispatches - (1 + 2 * CModelChoices),
      'Observation changed reserved dispatches');
    Check(LAdmission.RemainingDeclaredWork = MaximumProviderCodecDeclaredWork - (3 + 12 * CModelChoices),
      'Observation changed declared work');
    Check(LAdmission.RemainingPayloadBytes = MaximumProviderCodecPayloadBytes - LTokenBytes,
      'Observation changed accepted payload accounting');
    Check(LAdmission.RemainingProcessedBytes = MaximumProviderCodecProcessedBytes -
      (2 * (1 + CModelChoices) * UInt64(MaximumProviderCodecConfigurationBytes) + 4 * LTokenBytes),
      'Observation changed configuration/token/output accounting');
    Check((GObserver.GridTotal = CCells + 1) and (GObserver.SourceTotal = CCells + 1) and
      (GObserver.ChoiceTotal = CModelChoices) and (GObserver.RegistryTotal = CRegistryEntries),
      'Authored source/grid/vocabulary/registry count oracle differs');
  finally
    LAdmission.Free;
  end;
end;

procedure AbortAndRetry(const AOperation: Integer; const AStage: String;
  const APoint: TAbortPoint; const AMinimum: Int64 = 1);
var
  LAdmission: TProviderCodecAdmission;
  LChoices: TStyleProviderChoices;
  LLayers: TLearnedLayers;
  LOptions: TLayerGenerationOptions;
  LSession: TCompatibleProviderSession;
  LExact: Boolean;
begin
  LAdmission := TProviderCodecAdmission.Create(GRegistry);
  LChoices := CloneStyleProviderChoices(GExpected);
  SetLength(LLayers, 1);
  LLayers[0].Model := GModel;
  LOptions := DefaultLayerGenerationOptions;
  LSession := nil;
  GObserver.Stage := AStage;
  GObserver.Point := APoint;
  GObserver.Minimum := AMinimum;
  GObserver.Marker := Exception.Create('Big Boss provider observer marker');
  LExact := False;
  try
    try
      case AOperation of
        0: LChoices := AdmitProviderContract(GModel, GContract, GRegistry, LAdmission, GObserver.Observe);
        1: LChoices := CloneStyleProviderChoices(GExpected, GObserver.Observe);
        2: LSession := TCompatibleProviderSession.Create(LLayers, nil, [GContract], LOptions,
          GRegistry, LAdmission, GObserver.Observe);
        3: RequireCompatibleProvider(GContract, GContract, GObserver.Observe);
      end;
    except
      on LException: Exception do
      begin
        if LException <> GObserver.Marker then raise;
        GObserver.Marker := nil;
        LExact := True;
        Inc(GAborts);
      end;
    end;
    GObserver.Marker.Free;
    GObserver.Marker := nil;
    Check(LExact, 'Original observer exception did not escape at ' + AStage);
    Check(LSession = nil, 'Aborted constructor assigned a partial session');
    SameChoices(GExpected, LChoices);
    Check((EncodeWfcSequenceText(GModel) = GModelText) and
      (Sha256Bytes(GContract.CodecBinding.Configuration) = GConfigurationHash),
      'Aborted admission changed borrowed inputs');
    { Retry uses a fresh admission when repeated work can exhaust the original
      aggregate budget. The separate spent-budget checks below keep that policy explicit. }
    case AOperation of
      0: SameChoices(GExpected, AdmitProviderContract(GModel, GContract, GRegistry, nil, GObserver.Observe));
      1: SameChoices(GExpected, CloneStyleProviderChoices(GExpected, GObserver.Observe));
      2:
      begin
        LSession := TCompatibleProviderSession.Create(LLayers, nil, [GContract], LOptions,
          GRegistry, nil, GObserver.Observe);
        SameChoices(GExpected, LSession.CopyChoices(GContract.Name, GObserver.Observe));
      end;
      3: RequireCompatibleProvider(GContract, GContract, GObserver.Observe);
    end;
  finally
    GObserver.Marker.Free;
    GObserver.Marker := nil;
    GObserver.Stage := '';
    LSession.Free;
    LAdmission.Free;
  end;
end;

procedure CheckSpentBindingBudget;
var
  LAdmission: TProviderCodecAdmission;
  LBefore: Integer;
  LExact: Boolean;
begin
  LAdmission := TProviderCodecAdmission.Create(GRegistry);
  LBefore := GCodec.Configurations;
  GObserver.Stage := 'provider_codec_dispatches';
  GObserver.Point := apSpentDispatch;
  GObserver.Minimum := 1;
  GObserver.Marker := Exception.Create('Big Boss spent-budget marker');
  LExact := False;
  try
    try
      LAdmission.ValidateBinding(GContract.CodecBinding, GObserver.Observe);
    except
      on LException: Exception do
      begin
        if LException <> GObserver.Marker then raise;
        GObserver.Marker := nil;
        LExact := True;
        Inc(GAborts);
      end;
    end;
    Check(LExact, 'Final binding checkpoint did not abort');
    Check((LAdmission.RemainingDispatches = MaximumProviderCodecDispatches - 1) and
      (LAdmission.RemainingDeclaredWork = MaximumProviderCodecDeclaredWork - 3) and
      (LAdmission.RemainingProcessedBytes = MaximumProviderCodecProcessedBytes -
        2 * MaximumProviderCodecConfigurationBytes), 'Abort refunded spent admission work');
    LAdmission.ValidateBinding(GContract.CodecBinding, GObserver.Observe);
    Check((GCodec.Configurations = LBefore + 2) and
      (LAdmission.RemainingDispatches = MaximumProviderCodecDispatches - 2),
      'Aborted binding was cached or retry reset its aggregate budget');
  finally
    GObserver.Marker.Free;
    GObserver.Marker := nil;
    GObserver.Stage := '';
    LAdmission.Free;
  end;
end;

procedure MeasureClockResidual;
var
  LChanges: TTempoChanges;
  LClock: TTempoMap;
  LStart: QWord;
  I: Integer;
begin
  SetLength(LChanges, MaximumTempoChanges);
  for I := 0 to High(LChanges) do LChanges[I] := MakeTempoChange(I, 500000 + (I mod 2));
  LStart := GetTickCount64;
  LClock := TTempoMap.Create(480, MaximumTempoChanges, LChanges);
  try
    Check(LClock.ChangeCount = MaximumTempoChanges, 'Clock residual did not use the actual maximum');
    WriteLn('Primary clock residual ', MaximumTempoChanges, ' changes: ',
      GetTickCount64 - LStart, ' ms (one local observation, not a latency guarantee)');
  finally
    LClock.Free;
  end;
end;

procedure CheckDecodeBudget(const ATextAbort: Boolean);
var
  LAdmission: TProviderCodecAdmission;
  LChoice: TProviderCodecChoice;
  LToken: String;
  LExact: Boolean;
  LBefore: Integer;
begin
  LAdmission := TProviderCodecAdmission.Create(GRegistry);
  LBefore := GCodec.Configurations;
  LChoice := Default(TProviderCodecChoice);
  LChoice.Bytes := Bytes('sentinel');
  LToken := 'v:0';
  GObserver.Stage := 'provider_codec_dispatches';
  GObserver.Point := apSpentDispatch;
  GObserver.Minimum := 2;
  if ATextAbort then
  begin
    LToken := StringOfChar('a', 4000);
    GObserver.Stage := 'text_validate_bytes';
    GObserver.Minimum := 1024;
  end;
  GObserver.Marker := Exception.Create('Big Boss decode-budget marker');
  LExact := False;
  try
    try
      LChoice := LAdmission.DecodeChoice(GContract.CodecBinding, LToken, GObserver.Observe);
    except
      on LException: Exception do
      begin
        if LException <> GObserver.Marker then raise;
        GObserver.Marker := nil;
        LExact := True;
        Inc(GAborts);
      end;
    end;
    Check(LExact, 'Original decode/text abort did not escape');
    Check(Sha256Bytes(LChoice.Bytes) = Sha256Bytes(Bytes('sentinel')),
      'Partial decoded choice was assigned');
    if ATextAbort then
    begin
      Check(LAdmission.RemainingDispatches = MaximumProviderCodecDispatches - 1,
        'Text validation dispatched a decoder before admission');
    end
    else
    begin
      Check((LAdmission.RemainingDispatches = MaximumProviderCodecDispatches - 2) and
        (LAdmission.RemainingDeclaredWork = MaximumProviderCodecDeclaredWork - 8) and
        (LAdmission.RemainingPayloadBytes = MaximumProviderCodecPayloadBytes - Length(LToken)),
        'Decode abort refunded spent work or changed payload reservation');
    end;
    LChoice := LAdmission.DecodeChoice(GContract.CodecBinding, LToken, GObserver.Observe);
    Check((GCodec.Configurations = LBefore + 1) and
      (Sha256Bytes(LChoice.Bytes) = Sha256Bytes(Bytes(LToken))),
      'Retry changed the admitted configuration or decoded value');
    if ATextAbort then
    begin
      Check(LAdmission.RemainingDispatches = MaximumProviderCodecDispatches - 3,
        'Text-aborted retry reset the aggregate dispatch budget');
    end
    else
    begin
      Check((LAdmission.RemainingDispatches = MaximumProviderCodecDispatches - 4) and
        (LAdmission.RemainingDeclaredWork = MaximumProviderCodecDeclaredWork - 20) and
        (LAdmission.RemainingPayloadBytes = MaximumProviderCodecPayloadBytes - 2 * Length(LToken)) and
        (LAdmission.RemainingProcessedBytes = MaximumProviderCodecProcessedBytes -
          (5 * MaximumProviderCodecConfigurationBytes + 6 * Length(LToken))),
        'Decode retry lost monotonic budget accounting');
    end;
  finally
    GObserver.Marker.Free;
    GObserver.Marker := nil;
    GObserver.Stage := '';
    LAdmission.Free;
  end;
end;

procedure CheckRegistrationAbort;
var
  LRegistry: TProviderCodecRegistry;
  I: Integer;
  LExact: Boolean;
begin
  LRegistry := TProviderCodecRegistry.Create;
  try
    for I := 0 to 30 do LRegistry.RegisterCodec(Declaration(I), GCodec);
    GObserver.Stage := 'provider_registry_entries';
    GObserver.Point := apFinal;
    GObserver.Minimum := 1;
    GObserver.Marker := Exception.Create('Big Boss registry marker');
    LExact := False;
    try
      LRegistry.RegisterCodec(Declaration(31), GCodec, GObserver.Observe);
    except
      on LException: Exception do
      begin
        if LException <> GObserver.Marker then raise;
        GObserver.Marker := nil;
        LExact := True;
        Inc(GAborts);
      end;
    end;
    Check(LExact and (LRegistry.Count = 31), 'Aborted registry entry was published');
    LRegistry.RegisterCodec(Declaration(31), GCodec, GObserver.Observe);
    Check(LRegistry.Count = 32, 'Registry registration retry failed');
  finally
    GObserver.Marker.Free;
    GObserver.Marker := nil;
    GObserver.Stage := '';
    LRegistry.Free;
  end;
end;

procedure CheckVoiceCapacity;
var
  LTokens: TWfcModelTokens;
  LModel: TWfcSequenceModel;
  LCapacities: TChordCapacities;
  LContract: TProviderContract;
  LChoices: TStyleProviderChoices;
  LText: String;
  LStart: QWord;
  LExact: Boolean;
  LFinal: Boolean;
  LKind: Integer;
  I: Integer;
begin
  SetLength(LTokens, 2048);
  for I := 0 to High(LTokens) do
  begin
    LTokens[I] := EncodeWfcMusicEnsembleFrame(MakeWfcMusicEnsembleFrame([
      MakeWfcMusicVoiceCell(wmcaAttack, [MakeWfcMusicTone(I mod 128, 80 + (I div 128) mod 8)])]));
  end;
  LModel := LearnSequenceModelCorpus([MakeWfcSequenceSample(LTokens)], 1);
  try
    Check((LModel.PublicTokenCount = 1024) and (LModel.StateCount = 1024),
      'Voice residual did not exercise the supported maximum state/vocabulary case');
    LText := EncodeWfcSequenceText(LModel);
    for LKind := 0 to 1 do
      for LFinal := False to True do
      begin
        LCapacities := [7];
        GObserver.Stage := 'provider_voice_capacity_visits';
        GObserver.Minimum := 256;
        GObserver.Point := apSpentDispatch;
        if LFinal then GObserver.Point := apFinal;
        GObserver.Marker := Exception.Create('Big Boss capacity marker');
        LExact := False;
        try
          if LKind = 0 then
            LCapacities := WfcEnsembleCapacities(LModel, GObserver.Observe)
          else
            LCapacities := WfcIndependentVoiceCapacities([LModel], GObserver.Observe);
        except
          on LException: Exception do
          begin
            if LException <> GObserver.Marker then raise;
            GObserver.Marker := nil;
            LExact := True;
            Inc(GAborts);
          end;
        end;
        Check(LExact and (Length(LCapacities) = 1) and (LCapacities[0] = 7),
          'Capacity abort published partial output');
        if LKind = 0 then
          LCapacities := WfcEnsembleCapacities(LModel, GObserver.Observe)
        else
          LCapacities := WfcIndependentVoiceCapacities([LModel], GObserver.Observe);
        Check((Length(LCapacities) = 1) and (LCapacities[0] = 1) and
          (GObserver.CapacityTotal = 3 * 1024 + 1), 'Capacity retry/visit oracle differs');
      end;
    GObserver.Stage := '';
    LStart := GetTickCount64;
    ValidateWfcMusicEnsembleModel(LModel, 1);
    WriteLn('Companion voice-model residual 1024 states: ', GetTickCount64 - LStart,
      ' ms (one local observation, not a latency guarantee)');
    LContract := CopyProviderContract(GContract);
    LContract.Vocabulary := spvVoice;
    LContract.CodecBinding := Default(TProviderCodecBinding);
    LContract.UnknownPolicy := ProviderUnknownPolicy(spvVoice);
    LContract.PitchBasis := ppbAbsoluteMidi;
    LContract.RoleId := 'authored-voice';
    LContract.Scope := MakeLayerScope(256, wseWrap);
    SetLength(LContract.Source.OriginalTicks, 257);
    SetLength(LContract.Source.OriginalFrames, 257);
    LChoices := AdmitProviderContract(LModel, LContract, nil, nil, GObserver.Observe);
    Check((Length(LChoices) = 1024) and (GObserver.CapacityTotal = 3073) and
      (EncodeWfcSequenceText(LModel) = LText), 'Real voice admission or borrowed model changed');
  finally
    GObserver.Marker.Free;
    GObserver.Marker := nil;
    GObserver.Stage := '';
    LModel.Free;
  end;
end;

procedure CheckExplicitPartition;
var
  LSaved: TProviderContract;
  LGrid: TLayerTimeGrid;
  LStart: QWord;
begin
  LStart := GetTickCount64;
  LGrid := MakeLayerTimePartition(GContract.Source.OriginalTicks);
  Check(Length(LGrid.Boundaries) = 1025, 'Partition residual did not use the actual maximum');
  WriteLn('Owned partition residual 1025 boundaries: ', GetTickCount64 - LStart,
    ' ms (one local observation, not a latency guarantee)');
  LSaved := GContract;
  try
    GContract.TimeGrid := LGrid;
    AbortAndRetry(0, 'provider_grid_boundaries', apFinal);
  finally
    GContract := LSaved;
  end;
end;

procedure CheckComparisonCounts;
var
  LOther: TProviderCodecBinding;
  LCalls: Integer;
  LMatches: Boolean;
  LExact: Boolean;
begin
  LOther := CopyProviderCodecBinding(GContract.CodecBinding);
  LCalls := GObserver.Calls;
  Check(SameProviderCodecBinding(GContract.CodecBinding, LOther, GObserver.Observe),
    'Identical configuration differs');
  Check((GObserver.Calls - LCalls = 66) and
    (GObserver.ComparedBytes = 65536) and (GObserver.ComparedTotal = 65536),
    '64-KiB comparison cadence/count oracle differs');
  LOther.Configuration[0] := $52;
  LCalls := GObserver.Calls;
  Check(not SameProviderCodecBinding(GContract.CodecBinding, LOther, GObserver.Observe),
    'Different first byte was accepted');
  Check((GObserver.Calls - LCalls = 2) and (GObserver.ComparedBytes = 1) and
    (GObserver.ComparedTotal = 1), 'Early mismatch claimed unvisited comparison bytes');
  GObserver.Stage := 'provider_codec_compare_bytes';
  GObserver.Point := apFinal;
  GObserver.Minimum := 1;
  GObserver.Marker := Exception.Create('Big Boss comparison marker');
  LMatches := True;
  LExact := False;
  try
    try
      LMatches := SameProviderCodecBinding(GContract.CodecBinding, LOther, GObserver.Observe);
    except
      on LException: Exception do
      begin
        if LException <> GObserver.Marker then raise;
        GObserver.Marker := nil;
        LExact := True;
        Inc(GAborts);
      end;
    end;
    Check(LExact and LMatches, 'Aborted mismatch published a Boolean result');
    Check(not SameProviderCodecBinding(GContract.CodecBinding, LOther, GObserver.Observe),
      'Mismatch retry changed its result');
  finally
    GObserver.Marker.Free;
    GObserver.Marker := nil;
    GObserver.Stage := '';
  end;
end;

var
  LPoint: TAbortPoint;
  LStage: String;
const
  CAdmissionStages: array[0..5] of String = ('provider_grid_boundaries',
    'provider_source_boundaries', 'provider_registry_entries',
    'provider_codec_compare_bytes', 'provider_decode_choices', 'provider_validate_choices');
begin
  GObserver := TObserver.Create;
  GCodec := TEchoCodec.Create;
  GRegistry := TProviderCodecRegistry.Create;
  try
    Prepare;
    CheckAdmissionBudget;
    for LStage in CAdmissionStages do
      for LPoint := apInterior to apFinal do AbortAndRetry(0, LStage, LPoint);
    AbortAndRetry(0, 'provider_source_clock', apFinal);
    AbortAndRetry(1, 'provider_clone_choices', apInterior);
    AbortAndRetry(1, 'provider_clone_choices', apFinal);
    AbortAndRetry(2, 'provider_session_contracts', apFinal);
    AbortAndRetry(2, 'provider_session_inputs', apStart, 0);
    AbortAndRetry(3, 'provider_compare_boundaries', apInterior);
    AbortAndRetry(3, 'provider_compare_boundaries', apFinal);
    CheckSpentBindingBudget;
    CheckDecodeBudget(False);
    CheckDecodeBudget(True);
    CheckRegistrationAbort;
    CheckVoiceCapacity;
    CheckExplicitPartition;
    CheckComparisonCounts;
    MeasureClockResidual;
    WriteLn('Provider progress: ', GChecks, ' checks; ', GAborts,
      ' original abort/retries; ', GObserver.Calls, ' callbacks (', GObserver.ByteCalls, ' bytes)');
  finally
    GModel.Free;
    GRegistry.Free;
    GCodec.Free;
    GObserver.Free;
  end;
end.
