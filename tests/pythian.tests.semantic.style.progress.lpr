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
program pythian_tests_semantic_style_progress;

{$mode delphi}
{$H+}

uses
  Classes, SysUtils, pythian.audio, pythian.hash, pythian.progress, pythian.time,
  pythian.music.context, pythian.tonal, pythian.wfc.style,
  pythian.wfc.context, pythian.wfc.layers, pythian.wfc.providers,
  pythian.wfc.provider.contracts, pythian.wfc.provider.codecs,
  pythian.wfc.semantic.style, pythian.example.provider.extension.units,
  wfc, wfc_model, wfc_sequence, wfc_sequence_learn, wfc_sequence_text,
  wfc_sequence_graph;

const
  CCells = 128;

type
  TOperation = (opSource, opDerived, opBlend, opReblend, opDecode, opEncode,
    opDefinition, opParent, opSession);
  TObserver = class
  public
    Calls: Integer;
    AbortStage: String;
    MinimumDone: Int64;
    RequireInterior: Boolean;
    Marker: Exception;
    procedure Observe(const AWork: TWorkProgress);
  end;

var
  GChecks: Integer;
  GObserver: TObserver;
  GDefinition: TSemanticStyleDefinition;
  GLeft: TSemanticStyle;
  GRight: TSemanticStyle;
  GBlend: TSemanticStyle;
  GReblend: TSemanticStyle;
  GArchive: TAudioBytes;
  GRecipe: TSemanticBlendRecipe;
  GRegistry: TProviderCodecRegistry;
  GExpected: array[TOperation] of String;

procedure Check(const ACondition: Boolean; const AMessage: String);
begin
  Inc(GChecks);
  if not ACondition then
  begin
    raise EAudio.Create(AMessage);
  end;
end;

procedure TObserver.Observe(const AWork: TWorkProgress);
begin
  Inc(Calls);
  Check((AWork.Done >= 0) and (AWork.Total >= 0) and
    ((AWork.Total = 0) or (AWork.Done <= AWork.Total)), 'Invalid work counts');
  if (AWork.Stage = AbortStage) and (AWork.Done >= MinimumDone) and
    (not RequireInterior or ((AWork.Done > 0) and
    ((AWork.Total = 0) or (AWork.Done < AWork.Total)))) then
  begin
    raise Marker;
  end;
end;

function Definition(const AVariant: Integer;
  const ACells: Integer = CCells): TSemanticStyleDefinition;
var
  LProvider: Integer;
  LRun: Integer;
  LCell: Integer;
  LSource: Integer;
  LIndex: Integer;
  LSamples: TWfcSequenceSamples;
  LModel: TWfcSequenceModel;
begin
  Result := Default(TSemanticStyleDefinition);
  SetLength(Result.Sources, 2);
  for LSource := 0 to 1 do
  begin
    with Result.Sources[LSource] do
    begin
      Sha256 := StringOfChar(Char(Ord('a') + AVariant * 2 + LSource), 64);
      GroupId := 'authored-progress-' + IntToStr(AVariant) + '-' + IntToStr(LSource);
      Split := ssTraining;
      Exposure := [seTraining, seVocabulary];
      SampleRate := 1000;
      FrameCount := ACells * 500 + 6000;
      ExternalRequirement := 'Authored symbolic declarations; no acoustic truth claim';
      OriginSha256 := Sha256;
      OriginSampleRate := SampleRate;
      OriginFrameCount := FrameCount;
      OriginEndFrame := FrameCount;
      SetLength(PreparationEvidence, 65536);
      for LIndex := 0 to High(PreparationEvidence) do
      begin
        PreparationEvidence[LIndex] := LIndex mod 251;
      end;
      PreparationSha256 := SemanticPreparationIdentity(Result.Sources[LSource]);
    end;
  end;
  SetLength(Result.Providers, 3);
  for LProvider := 0 to 2 do
  begin
    with Result.Providers[LProvider] do
    begin
      Contract.TicksPerQuarter := 480;
      Contract.Scope := MakeLayerScope(ACells, wseWhole);
      Contract.TimeGrid := MakeLayerTimeGrid(0, 240);
      Contract.MusicalDomain := 'authored-progress-fixture';
      case LProvider of
        0:
        begin
          Contract.Name := 'tempo';
          Contract.Vocabulary := spvTempo;
        end;
        1:
        begin
          Contract.Name := 'onsets';
          Contract.Vocabulary := spvOnsets;
        end;
        2:
        begin
          Contract.Name := 'key';
          Contract.Vocabulary := spvKey;
        end;
      end;
      Contract.UnknownPolicy := ProviderUnknownPolicy(Contract.Vocabulary);
      ExtractionPolicy := 'Caller-authored mechanical control, no inferred labels';
    end;
  end;
  SetLength(Result.Runs, 3);
  for LRun := 0 to 2 do
  begin
    with Result.Runs[LRun] do
    begin
      Identity := 'run-' + IntToStr(AVariant) + '-' + IntToStr(LRun);
      SourceIndex := Ord(LRun = 2);
      if LRun = 1 then
      begin
        StartFrame := ACells * 250 + 1000;
        GapBeforeFrames := 1000;
      end;
      EndFrame := StartFrame + ACells * 250;
      TicksPerQuarter := 480;
      TempoChanges := [MakeTempoChange(0, 500000)];
      SetLength(Tokens, 3);
      SetLength(Weights, 3);
      SetLength(TimeGrids, 3);
      for LProvider := 0 to 2 do
      begin
        Weights[LProvider] := 1;
        TimeGrids[LProvider] := MakeLayerTimeGrid(0, 240);
        SetLength(Tokens[LProvider], ACells);
      end;
      for LCell := 0 to ACells - 1 do
      begin
        Tokens[2][LCell] := KeyContextToken(MakeKeyContext(-1, dmMajor));
        if LRun = 1 then
        begin
          Tokens[0][LCell] := TempoContextToken(600000);
          Tokens[1][LCell] := RhythmEmptyToken;
        end
        else
        begin
          Tokens[0][LCell] := TempoContextToken(500000);
          Tokens[1][LCell] := RhythmOnsetToken;
        end;
      end;
    end;
  end;
  for LProvider := 0 to 2 do
  begin
    SetLength(LSamples, 3);
    for LRun := 0 to 2 do
    begin
      LSamples[LRun] := MakeWfcSequenceSample(Result.Runs[LRun].Tokens[LProvider]);
    end;
    LModel := LearnSequenceModelCorpus(LSamples, 1);
    try
      Result.Providers[LProvider].ModelText := EncodeWfcSequenceText(LModel);
      Result.Providers[LProvider].VocabularySha256 := SemanticVocabularyIdentity(
        Result.Providers[LProvider].ModelText, Result.Providers[LProvider].Contract);
    finally
      LModel.Free;
    end;
  end;
  SetLength(Result.Projections, 1);
  Result.Projections[0].Provider := 0;
  Result.Projections[0].Consumer := 1;
  Result.Projections[0].TimeMapping := ltmWholeCell;
  SetLength(Result.Projections[0].Rules, 2);
  Result.Projections[0].Rules[0] := MakeWfcSequenceProjectionRule(
    RhythmOnsetToken, [TempoContextToken(500000)]);
  Result.Projections[0].Rules[1] := MakeWfcSequenceProjectionRule(
    RhythmEmptyToken, [TempoContextToken(600000)]);
end;

function Execute(const AOperation: TOperation; const AObserved: Boolean): String;
var
  LCallback: TWorkProgressCallback;
  LStyle: TSemanticStyle;
  LDefinition: TSemanticStyleDefinition;
  LSession: TCompatibleProviderSession;
  LSequences: TLayerSequences;
  LReport: TGraphNegotiationReport;
  LProvider: Integer;
  LCell: Integer;
begin
  Result := '';
  LCallback := nil;
  if AObserved then
  begin
    LCallback := GObserver.Observe;
  end;
  LStyle := nil;
  LSession := nil;
  try
    case AOperation of
      opSource: LStyle := TSemanticStyle.CreateSource(GDefinition, GRegistry, nil, LCallback);
      opDerived: LStyle := TSemanticStyle.CreateDerived(GLeft, GLeft.CopyDefinition,
        GRegistry, nil, LCallback);
      opBlend: LStyle := TSemanticStyle.CreateBlend(GLeft, GRight, GRecipe,
        GRegistry, nil, LCallback);
      opReblend: LStyle := TSemanticStyle.CreateBlend(GBlend, GRight, GRecipe,
        GRegistry, nil, LCallback);
      opDecode: LStyle := DecodeSemanticStyle(GArchive, GRegistry, nil, LCallback);
      opEncode: Result := Sha256Bytes(GReblend.Encode(LCallback));
      opDefinition:
      begin
        LDefinition := GLeft.CopyDefinition(LCallback);
        LStyle := TSemanticStyle.CreateSource(LDefinition, GRegistry);
      end;
      opParent: LStyle := GReblend.CopyParent(0, GRegistry, nil, LCallback);
      opSession:
      begin
        LSession := GLeft.CreateSession(731, GRegistry, nil, LCallback);
        Check(LSession.TryGenerate(LSequences, LReport), 'Observed session cannot generate');
        for LProvider := 0 to High(LSequences) do
        begin
          for LCell := 0 to High(LSequences[LProvider].Tokens) do
          begin
            Result := Result + LSequences[LProvider].Tokens[LCell] + '@' +
              IntToStr(LSequences[LProvider].StateIndices[LCell]) + ';';
          end;
        end;
      end;
    end;
    if LStyle <> nil then
    begin
      Result := Sha256Bytes(LStyle.Encode);
    end;
  finally
    LSession.Free;
    LStyle.Free;
  end;
end;

procedure AbortAndRetry(const AOperation: TOperation; const AStage: String;
  const AMinimumDone: Int64; const AInterior: Boolean = True);
var
  LExpected: String;
  LLeft: String;
  LRight: String;
  LExact: Boolean;
begin
  LExpected := GExpected[AOperation];
  LLeft := Sha256Bytes(GLeft.Encode);
  LRight := Sha256Bytes(GRight.Encode);
  GObserver.AbortStage := AStage;
  GObserver.MinimumDone := AMinimumDone;
  GObserver.RequireInterior := AInterior;
  GObserver.Marker := Exception.Create('semantic observer marker');
  LExact := False;
  try
    Execute(AOperation, True);
  except
    on LException: Exception do
    begin
      LExact := LException = GObserver.Marker;
    end;
  end;
  if not LExact then
  begin
    GObserver.Marker.Free;
  end;
  GObserver.Marker := nil;
  GObserver.AbortStage := '';
  Check(LExact, 'Original callback exception not propagated at ' + AStage);
  Check(Execute(AOperation, True) = LExpected, 'Retry differs at ' + AStage);
  Check((Sha256Bytes(GLeft.Encode) = LLeft) and (Sha256Bytes(GRight.Encode) = LRight),
    'Borrowed parents changed at ' + AStage);
end;

var
  LOtherDefinition: TSemanticStyleDefinition;
  LSavedDefinition: TSemanticStyleDefinition;
  LOperation: TOperation;
  LProvider: Integer;
  LCodec: TCallerHarmonicCodec;
  LCaller: TSemanticStyle;
  LSavedLeft: TSemanticStyle;
  LRetry: TSemanticStyle;
  LReference: TAudioBytes;
begin
  GObserver := TObserver.Create;
  try
    GDefinition := Definition(0);
    LOtherDefinition := Definition(1);
    GLeft := TSemanticStyle.CreateSource(GDefinition);
    GRight := TSemanticStyle.CreateSource(LOtherDefinition);
    SetLength(GRecipe.Providers, 3);
    for LProvider := 0 to 2 do
    begin
      GRecipe.Providers[LProvider].LeftWeight := 1;
      GRecipe.Providers[LProvider].RightWeight := 1;
    end;
    GBlend := TSemanticStyle.CreateBlend(GLeft, GRight, GRecipe);
    GReblend := TSemanticStyle.CreateBlend(GBlend, GRight, GRecipe);
    GArchive := GReblend.Encode;
    for LOperation := Low(TOperation) to High(TOperation) do
    begin
      GExpected[LOperation] := Execute(LOperation, False);
      Check(GExpected[LOperation] = Execute(LOperation, True),
        'Nil/observed archive or session differs');
    end;
    AbortAndRetry(opSource, 'semantic_validate_sources', 1);
    AbortAndRetry(opSource, 'semantic_validate_runs', 1);
    AbortAndRetry(opSource, 'semantic_validate_providers', 1);
    AbortAndRetry(opSource, 'semantic_validate_clock_cells', 256);
    AbortAndRetry(opSource, 'semantic_prepare_constraints', 256);
    AbortAndRetry(opSource, 'semantic_validate_pairs', 4096);
    AbortAndRetry(opSource, 'semantic_archive_output', 65536);
    AbortAndRetry(opSource, 'verify_audio_bytes', 8192);
    AbortAndRetry(opBlend, 'semantic_blend_sources', 1);
    AbortAndRetry(opBlend, 'semantic_blend_runs', 1);
    AbortAndRetry(opBlend, 'semantic_blend_providers', 1);
    AbortAndRetry(opBlend, 'semantic_relearn_providers', 1);
    AbortAndRetry(opDecode, 'semantic_archive_input', 65536);
    AbortAndRetry(opDecode, 'semantic_archive_blob', 65536);
    AbortAndRetry(opDecode, 'semantic_ancestry_node', 1, False);
    AbortAndRetry(opEncode, 'semantic_archive_copy', 65536);
    AbortAndRetry(opSession, 'semantic_load_providers', 1);
    AbortAndRetry(opSession, 'semantic_prepare_session', 2, False);

    { A 128-cell definition contains fewer than one 4096-field checkpoint.
      Exercise a larger source alone without exceeding the blend work budget. }
    LSavedDefinition := GDefinition;
    GDefinition := Definition(0, 512);
    GExpected[opSource] := Execute(opSource, False);
    try
      AbortAndRetry(opSource, 'semantic_archive_fields', 4096);
    finally
      GDefinition := LSavedDefinition;
    end;

    LCodec := TCallerHarmonicCodec.Create;
    GRegistry := TProviderCodecRegistry.Create;
    LCaller := nil;
    try
      RegisterHarmonicCodec(GRegistry, LCodec);
      GRegistry.Seal;
      LCaller := CreateHarmonicSourceStyle(0, GRegistry, LReference);
      LSavedLeft := GLeft;
      GLeft := LCaller;
      try
        GExpected[opSession] := Execute(opSession, False);
        AbortAndRetry(opSession, 'semantic_prepare_session', 2, False);
        LRetry := CreateHarmonicSourceStyle(0, GRegistry, LReference);
        try
          Check(LRetry.Identity = LCaller.Identity, 'Borrowed caller registry changed');
        finally
          LRetry.Free;
        end;
      finally
        GLeft := LSavedLeft;
      end;
    finally
      LCaller.Free;
      GRegistry.Free;
      GRegistry := nil;
      LCodec.Free;
    end;
    WriteLn('Semantic progress: ', GChecks, ' checks; ', GObserver.Calls, ' callbacks');
  finally
    GReblend.Free;
    GBlend.Free;
    GRight.Free;
    GLeft.Free;
    GObserver.Free;
  end;
end.
