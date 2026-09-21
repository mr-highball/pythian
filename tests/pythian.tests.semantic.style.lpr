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
program pythian_tests_semantic_style;

{$mode delphi}
{$H+}

uses
  Classes, SysUtils, Math, pythian.audio, pythian.hash, pythian.analysis, pythian.onset, pythian.time,
  pythian.wave, pythian.synth, pythian.envelope, pythian.source.wavetable,
  pythian.music.context, pythian.tonal, pythian.wfc.context,
  pythian.wfc.context.profile, pythian.wfc.context.archive, pythian.wfc.style,
  pythian.wfc.semantic.style, pythian.wfc.provider.contracts, pythian.wfc.providers,
  pythian.wfc.layers, pythian.wfc.voices, pythian.wfc.instrument,
  wfc, wfc_model, wfc_sequence, wfc_sequence_learn, wfc_sequence_text, wfc_sequence_graph,
  wfc_music, wfc_music_sequence, wfc_music_ensemble, wfc_music_ensemble_graph, wfc_music_voices_graph;

procedure Check(const ACondition: Boolean; const AMessage: String);
begin
  if not ACondition then
  begin
    raise EAudio.Create(AMessage);
  end;
end;

procedure SaveFixture(const ASuffix: String; const ABytes: TAudioBytes);
var
  LStream: TFileStream;
begin
  if ParamCount = 0 then
  begin
    Exit;
  end;
  LStream := TFileStream.Create(ParamStr(1) + ASuffix, fmCreate);
  try
    if Length(ABytes) > 0 then
    begin
      LStream.WriteBuffer(ABytes[0], Length(ABytes));
    end;
  finally
    LStream.Free;
  end;
end;

procedure LearnProviders(var ADefinition: TSemanticStyleDefinition);
var
  LProvider: Integer;
  LRun: Integer;
  LWeight: Integer;
  LCount: Integer;
  LOrder: Integer;
  LSamples: TWfcSequenceSamples;
  LModel: TWfcSequenceModel;
begin
  LOrder := 1;
  if ADefinition.NamedVoices then
  begin
    { A hold requires predecessor context. Order one admits structural
      rest-to-hold edges even when the observed run is attack/hold/rest. }
    LOrder := 2;
  end;
  for LProvider := 0 to High(ADefinition.Providers) do
  begin
    LSamples := nil;
    for LRun := 0 to High(ADefinition.Runs) do
    begin
      for LWeight := 1 to ADefinition.Runs[LRun].Weights[LProvider] do
      begin
        LCount := Length(LSamples);
        SetLength(LSamples, LCount + 1);
        LSamples[LCount] := MakeWfcSequenceSample(ADefinition.Runs[LRun].Tokens[LProvider]);
      end;
    end;
    LModel := LearnSequenceModelCorpus(LSamples, LOrder);
    try
      ADefinition.Providers[LProvider].ModelText := EncodeWfcSequenceText(LModel);
      ADefinition.Providers[LProvider].VocabularySha256 :=
        SemanticVocabularyIdentity(ADefinition.Providers[LProvider].ModelText);
    finally
      LModel.Free;
    end;
  end;
end;

function Provider(const AName: String; const AVocabulary: TStyleProviderVocabulary;
  const ACells: Integer): TSemanticProvider;
begin
  Result := Default(TSemanticProvider);
  Result.Contract.Name := AName;
  Result.Contract.Vocabulary := AVocabulary;
  Result.Contract.MusicalDomain := 'controlled-semantic-fixture';
  Result.Contract.TicksPerQuarter := 480;
  Result.Contract.Scope := MakeLayerScope(ACells, wseWhole);
  Result.Contract.TimeGrid := MakeLayerTimeGrid(0, 240);
  Result.Contract.UnknownPolicy := ProviderUnknownPolicy(AVocabulary);
  Result.ExtractionPolicy := 'Caller-authored controlled observations; no recorded inference claim';
end;

function Source(const AIndex: Integer): TSemanticSource;
begin
  Result := Default(TSemanticSource);
  Result.Sha256 := StringOfChar(Char(Ord('a') + AIndex), 64);
  Result.GroupId := 'controlled-group-' + IntToStr(AIndex);
  Result.Split := ssTraining;
  Result.Exposure := [seTraining, seVocabulary];
  Result.SampleRate := 1000;
  Result.FrameCount := 2000;
  Result.ExternalRequirement := 'Controlled symbolic fixture declarations';
  Result.OriginSha256 := Result.Sha256;
  Result.OriginSampleRate := Result.SampleRate;
  Result.OriginFrameCount := Result.FrameCount;
  Result.OriginEndFrame := Result.FrameCount;
  Result.PreparationEvidence := [Ord('i'), Ord('d'), Ord('e'), Ord('n'), Ord('t'), Ord('i'), Ord('t'), Ord('y')];
  Result.PreparationSha256 := SemanticPreparationIdentity(Result);
end;

function GridDefinition: TSemanticStyleDefinition;
var
  LRun: Integer;
  LCell: Integer;
begin
  Result := Default(TSemanticStyleDefinition);
  SetLength(Result.Providers, 3);
  Result.Providers[0] := Provider('tempo', spvTempo, 2);
  Result.Providers[1] := Provider('onsets', spvOnsets, 2);
  Result.Providers[2] := Provider('key', spvKey, 2);
  SetLength(Result.Sources, 2);
  Result.Sources[0] := Source(0);
  Result.Sources[1] := Source(1);
  SetLength(Result.Runs, 3);
  for LRun := 0 to 2 do
  begin
    Result.Runs[LRun].Identity := 'independent-run-' + IntToStr(LRun);
    Result.Runs[LRun].SourceIndex := Ord(LRun = 2);
    if LRun = 1 then
    begin
      Result.Runs[LRun].StartFrame := 600;
      Result.Runs[LRun].GapBeforeFrames := 100;
    end;
    Result.Runs[LRun].EndFrame := Result.Runs[LRun].StartFrame + 500;
    SetLength(Result.Runs[LRun].Tokens, 3);
    SetLength(Result.Runs[LRun].Weights, 3);
    Result.Runs[LRun].TicksPerQuarter := 480;
    Result.Runs[LRun].TempoChanges := [MakeTempoChange(0, 500000)];
    SetLength(Result.Runs[LRun].TimeGrids, 3);
    for LCell := 0 to 2 do
    begin
      Result.Runs[LRun].Weights[LCell] := 1;
      SetLength(Result.Runs[LRun].Tokens[LCell], 2);
      Result.Runs[LRun].TimeGrids[LCell] := MakeLayerTimeGrid(0, 240);
    end;
    for LCell := 0 to 1 do
    begin
      Result.Runs[LRun].Tokens[2][LCell] := KeyContextToken(MakeKeyContext(-1, dmMajor));
      if LRun = 1 then
      begin
        Result.Runs[LRun].Tokens[0][LCell] := TempoContextToken(600000);
        Result.Runs[LRun].Tokens[1][LCell] := RhythmEmptyToken;
      end
      else
      begin
        Result.Runs[LRun].Tokens[0][LCell] := TempoContextToken(500000);
        Result.Runs[LRun].Tokens[1][LCell] := RhythmOnsetToken;
      end;
    end;
  end;
  SetLength(Result.Projections, 1);
  Result.Projections[0].Provider := 0;
  Result.Projections[0].Consumer := 1;
  Result.Projections[0].TimeMapping := ltmWholeCell;
  SetLength(Result.Projections[0].Rules, 2);
  Result.Projections[0].Rules[0] := MakeWfcSequenceProjectionRule(RhythmOnsetToken, [TempoContextToken(500000)]);
  Result.Projections[0].Rules[1] := MakeWfcSequenceProjectionRule(RhythmEmptyToken, [TempoContextToken(600000)]);
  LearnProviders(Result);
end;

procedure SetPreparation(var ASource: TSemanticSource; const AEvidence: String);
begin
  SetLength(ASource.PreparationEvidence, Length(AEvidence));
  if Length(AEvidence) > 0 then
  begin
    Move(AEvidence[1], ASource.PreparationEvidence[0], Length(AEvidence));
  end;
  ASource.PreparationSha256 := SemanticPreparationIdentity(ASource);
end;

function DerivativeDefinition: TSemanticStyleDefinition;
begin
  Result := GridDefinition;
  Result.Sources[0].FrameCount := 4000;
  Result.Sources[0].OriginFrameCount := 4000;
  Result.Sources[0].OriginEndFrame := 4000;
  SetPreparation(Result.Sources[0], 'Identity original controlled recording');
  Result.Sources[1].GroupId := Result.Sources[0].GroupId;
  Result.Sources[1].SampleRate := 2000;
  Result.Sources[1].FrameCount := 4000;
  Result.Sources[1].OriginSha256 := Result.Sources[0].Sha256;
  Result.Sources[1].OriginSampleRate := 1000;
  Result.Sources[1].OriginFrameCount := 4000;
  Result.Sources[1].OriginStartFrame := 1100;
  Result.Sources[1].OriginEndFrame := 3100;
  SetPreparation(Result.Sources[1], 'Crop original frames 1100..3100; linear resample 1000 Hz to 2000 Hz');
  Result.Runs[2].EndFrame := 1000;
end;

procedure SameGrid(const ALeft, ARight: TSemanticStyle);
var
  LLeft: TCompatibleProviderSession;
  LRight: TCompatibleProviderSession;
  LBefore: TLayerSequences;
  LAfter: TLayerSequences;
  LReport: TGraphNegotiationReport;
  LSeed: Integer;
  LProvider: Integer;
  LCell: Integer;
begin
  for LSeed := 1 to 8 do
  begin
    LLeft := ALeft.CreateSession(LSeed);
    LRight := nil;
    try
      LRight := ARight.CreateSession(LSeed);
      Check(LLeft.TryGenerate(LBefore, LReport), 'Source/derived semantic graph generates');
      Check(LRight.TryGenerate(LAfter, LReport), 'Reloaded semantic graph generates');
      for LProvider := 0 to High(LBefore) do
      begin
        for LCell := 0 to High(LBefore[LProvider].Tokens) do
        begin
          Check((LBefore[LProvider].Tokens[LCell] = LAfter[LProvider].Tokens[LCell]) and
            (LBefore[LProvider].StateIndices[LCell] = LAfter[LProvider].StateIndices[LCell]),
            'Semantic archive retains exact actual generation states');
        end;
      end;
    finally
      LRight.Free;
      LLeft.Free;
    end;
  end;
end;

procedure PreparationChecks;
var
  LDefinition: TSemanticStyleDefinition;
  LCopy: TSemanticStyleDefinition;
  LSource: TSemanticStyle;
  LDerived: TSemanticStyle;
  LLoaded: TSemanticStyle;
  LCandidate: TSemanticStyle;
  LWideSource: TSemanticSource;
  LWideRun: TSemanticRun;
  LStart: Int64;
  LEnd: Int64;
  LReason: String;
  LRejected: Boolean;
  I: Integer;
begin
  LSource := nil;
  LDerived := nil;
  LLoaded := nil;
  LCandidate := nil;
  try
    LDefinition := DerivativeDefinition;
    LSource := TSemanticStyle.CreateSource(LDefinition);
    LDefinition.Sources[1].PreparationEvidence[0] := 0;
    LLoaded := DecodeSemanticStyle(LSource.Encode);
    LCopy := LLoaded.CopyDefinition;
    SemanticRunOriginRange(LCopy.Sources[1], LCopy.Runs[2], LStart, LEnd);
    Check((LStart = 1100) and (LEnd = 1600) and
      (LCopy.Sources[1].PreparationEvidence[0] = Ord('C')) and
      (LCopy.Sources[1].OriginSha256 = LCopy.Sources[0].Sha256) and
      (LCopy.Sources[1].Exposure = [seTraining, seVocabulary]),
      'Detached preparation evidence, original clock, range and exposure survive reload');
    SameGrid(LSource, LLoaded);
    LDerived := TSemanticStyle.CreateDerived(LLoaded, LCopy);
    FreeAndNil(LLoaded);
    LLoaded := DecodeSemanticStyle(LDerived.Encode);
    LCopy := LLoaded.CopyDefinition;
    Check(LCopy.Sources[1].PreparationSha256 = SemanticPreparationIdentity(LCopy.Sources[1]),
      'Derived source keeps the exact preparation binding');
    SemanticRunOriginRange(LCopy.Sources[1], LCopy.Runs[2], LStart, LEnd);
    Check((LStart = 1100) and (LEnd = 1600), 'Derived origin range survives reload');
    SameGrid(LDerived, LLoaded);
    SaveFixture('-derivative-source.pysg', LSource.Encode);
    SaveFixture('-derivative-derived.pysg', LDerived.Encode);
    for I := 0 to 12 do
    begin
      LDefinition := LSource.CopyDefinition;
      case I of
        0:
          begin
            LDefinition.Sources[1].OriginStartFrame := 100;
            LDefinition.Sources[1].OriginEndFrame := 2100;
            SetPreparation(LDefinition.Sources[1], 'Declared overlapping crop and resampling');
            LReason := 'Overlapping original material';
          end;
        1:
          begin
            LDefinition.Sources[1].PreparationEvidence := nil;
            LReason := 'requires bounded retained evidence';
          end;
        2:
          begin
            LDefinition.Sources[1].PreparationSha256 := StringOfChar('0', 64);
            LReason := 'mapped source binding differs';
          end;
        3:
          begin
            Inc(LDefinition.Sources[1].OriginStartFrame);
            LReason := 'mapped source binding differs';
          end;
        4:
          begin
            LDefinition.Sources[1].GroupId := 'hidden-recording-family';
            LReason := 'conflicting group or geometry';
          end;
        5:
          begin
            LDefinition.Sources[1].OriginSampleRate := 2000;
            SetPreparation(LDefinition.Sources[1], 'Contradictory original sample rate');
            LReason := 'conflicting group or geometry';
          end;
        6:
          begin
            Inc(LDefinition.Sources[1].OriginFrameCount);
            SetPreparation(LDefinition.Sources[1], 'Contradictory original frame extent');
            LReason := 'conflicting group or geometry';
          end;
        7:
          begin
            LDefinition.Sources[1].Split := ssTest;
            LDefinition.Sources[1].Exposure := [seEvaluation];
            LReason := 'crosses declared split or hides exposure';
          end;
        8:
          begin
            LDefinition.Sources[1].OriginSha256 := LDefinition.Sources[1].Sha256;
            LReason := 'Original source must retain';
          end;
        9:
          begin
            LDefinition.Sources[1].OriginEndFrame := 5000;
            LReason := 'origin interval or clock is invalid';
          end;
        10:
          begin
            LDefinition.Sources[1].PreparationEvidence[0] := 0;
            LReason := 'mapped source binding differs';
          end;
        11:
          begin
            LDefinition.Sources[1].PreparationSha256 := '';
            LReason := 'requires SHA256';
          end;
        12:
          begin
            LDefinition.Sources[0].OriginSha256 := StringOfChar('c', 64);
            SetPreparation(LDefinition.Sources[0], 'Intermediate asset incorrectly called original');
            LReason := 'map directly to the declared original';
          end;
      end;
      LRejected := False;
      try
        LCandidate := TSemanticStyle.CreateSource(LDefinition);
      except
        on E: EAudio do
        begin
          Check(Pos(LReason, E.Message) > 0, 'Preparation rejected for unrelated reason: ' + E.Message);
          LRejected := True;
        end;
      end;
      Check(LRejected and (LCandidate = nil), 'Invalid derivative evidence must reject before publication');
    end;
    LDefinition := LSource.CopyDefinition;
    SetPreparation(LDefinition.Sources[1], 'Rewritten preparation audit');
    LRejected := False;
    try
      LCandidate := TSemanticStyle.CreateDerived(LSource, LDefinition);
    except
      on EAudio do LRejected := True;
    end;
    Check(LRejected and (LCandidate = nil), 'Control derivation cannot rewrite preparation ancestry');
    LDefinition := LSource.CopyDefinition;
    LDefinition.Runs[0].Weights := [2, 2, 2];
    LearnProviders(LDefinition);
    LCandidate := TSemanticStyle.CreateSource(LDefinition);
    Check(LCandidate.CopyDefinition.Runs[0].Weights[0] = 2,
      'Intentional repeated contribution remains an explicit run weight');
    FreeAndNil(LCandidate);

    LDefinition := LSource.CopyDefinition;
    for I := 0 to 1 do
    begin
      LDefinition.Sources[I].OriginSha256 := StringOfChar('c', 64);
      LDefinition.Sources[I].OriginFrameCount := 10000;
    end;
    LDefinition.Sources[0].OriginEndFrame := 6002;
    LDefinition.Sources[1].OriginStartFrame := 1650;
    LDefinition.Sources[1].OriginEndFrame := 3850;
    SetPreparation(LDefinition.Sources[0], 'Controlled linear mapping 6002 original frames to 4000 prepared frames');
    SetPreparation(LDefinition.Sources[1], 'Controlled adjacent linear mapping at fractional original boundary');
    LDefinition.Runs[2].StartFrame := 1;
    LDefinition.Runs[2].EndFrame := 1001;
    LCandidate := TSemanticStyle.CreateSource(LDefinition);
    SemanticRunOriginRange(LDefinition.Sources[0], LDefinition.Runs[1], LStart, LEnd);
    Check(LEnd = 1651, 'Public origin range rounds its fractional end outward');
    SemanticRunOriginRange(LDefinition.Sources[1], LDefinition.Runs[2], LStart, LEnd);
    Check(LStart = 1650, 'Exact adjacent ranges can share one covering frame');
    FreeAndNil(LCandidate);
    LDefinition.Runs[2].StartFrame := 0;
    LDefinition.Runs[2].EndFrame := 1000;
    LRejected := False;
    try
      LCandidate := TSemanticStyle.CreateSource(LDefinition);
    except
      on E: EAudio do
      begin
        Check(Pos('Overlapping original material', E.Message) > 0,
          'Fractional overlap rejected for unrelated reason: ' + E.Message);
        LRejected := True;
      end;
    end;
    Check(LRejected and (LCandidate = nil), 'A fractional original-frame overlap still rejects');

    LDefinition := DerivativeDefinition;
    LDefinition.Projections := nil;
    LDefinition.Sources[1].OriginStartFrame := 0;
    LDefinition.Sources[1].OriginEndFrame := 2000;
    SetPreparation(LDefinition.Sources[1], 'Same original interval, distinct provider observations');
    for I := 0 to 1 do
    begin
      LDefinition.Runs[I].Tokens[2] := nil;
      LDefinition.Runs[I].Weights[2] := 0;
      LDefinition.Runs[I].TimeGrids[2] := Default(TLayerTimeGrid);
      LDefinition.Runs[2].Tokens[I] := nil;
      LDefinition.Runs[2].Weights[I] := 0;
      LDefinition.Runs[2].TimeGrids[I] := Default(TLayerTimeGrid);
    end;
    LearnProviders(LDefinition);
    LCandidate := TSemanticStyle.CreateSource(LDefinition);
    Check(LCandidate.CopyDefinition.Runs[2].Weights[2] = 1,
      'Overlapping observations of distinct unconnected providers are not duplicate contributions');
    FreeAndNil(LCandidate);

    LWideSource := Source(2);
    LWideSource.OriginSha256 := StringOfChar('d', 64);
    LWideSource.OriginFrameCount := High(Int64);
    LWideSource.OriginEndFrame := High(Int64);
    LWideSource.FrameCount := High(Integer);
    SetPreparation(LWideSource, 'Controlled extreme clock arithmetic; not a measured recording');
    LWideRun := Default(TSemanticRun);
    LWideRun.StartFrame := High(Integer) - 1;
    LWideRun.EndFrame := High(Integer);
    SemanticRunOriginRange(LWideSource, LWideRun, LStart, LEnd);
    Check((LEnd = High(Int64)) and (LStart < LEnd) and (LStart > 0),
      'Wide original coordinates do not overflow intermediate multiplication');
    LWideSource.OriginStartFrame := High(Int64) - 100000;
    SetPreparation(LWideSource, 'Controlled late original interval arithmetic');
    SemanticRunOriginRange(LWideSource, LWideRun, LStart, LEnd);
    Check((LStart = High(Int64) - 1) and (LEnd = High(Int64)),
      'Subframe mapped boundaries round outward at a wide original offset');
  finally
    LCandidate.Free;
    LLoaded.Free;
    LDerived.Free;
    LSource.Free;
  end;
end;

procedure GridChecks;
var
  LDefinition: TSemanticStyleDefinition;
  LSource: TSemanticStyle;
  LLoaded: TSemanticStyle;
  LDerived: TSemanticStyle;
  LCandidate: TSemanticStyle;
  LBytes: TAudioBytes;
  LCase: Integer;
  LRun: Integer;
  LCell: Integer;
  LRejected: Boolean;
begin
  LSource := nil;
  LLoaded := nil;
  LDerived := nil;
  LCandidate := nil;
  try
    LDefinition := GridDefinition;
    LSource := TSemanticStyle.CreateSource(LDefinition);
    SaveFixture('-source.pysg', LSource.Encode);
    LDefinition.Runs[0].Tokens[0][0] := 'mutated caller array';
    LLoaded := DecodeSemanticStyle(LSource.Encode);
    Check(LLoaded.Identity = LSource.Identity, 'Canonical source identity round-trip');
    Check(LLoaded.CopyDefinition.Runs[1].GapBeforeFrames = 100, 'Independent source gap retained');
    SameGrid(LSource, LLoaded);
    LDefinition := LSource.CopyDefinition;
    SetLength(LDefinition.Providers[0].Preferences, 1);
    LDefinition.Providers[0].Preferences[0] := MakeLayerTokenPreference(TempoContextToken(600000), 8);
    SetLength(LDefinition.Providers[0].Constraints, 1);
    LDefinition.Providers[0].Constraints[0] := MakeWfcSequenceTokenConstraint(0, [TempoContextToken(600000)]);
    LDerived := TSemanticStyle.CreateDerived(LSource, LDefinition);
    SaveFixture('-derived.pysg', LDerived.Encode);
    FreeAndNil(LLoaded);
    LLoaded := DecodeSemanticStyle(LDerived.Encode);
    SameGrid(LDerived, LLoaded);
    Check((LLoaded.Depth = 2) and
      (LLoaded.CopyDefinition.Providers[0].VocabularyAncestor = LSource.Identity), 'Frozen vocabulary ancestry binds actual parent');
    FreeAndNil(LLoaded);
    LCandidate := TSemanticStyle.CreateDerived(LDerived, LDerived.CopyDefinition);
    LLoaded := DecodeSemanticStyle(LCandidate.Encode);
    SameGrid(LCandidate, LLoaded);
    Check((LLoaded.Depth = 3) and
      (LLoaded.CopyDefinition.Providers[0].VocabularyAncestor = LDerived.Identity),
      'Second derivation retains complete frozen parent chain');
    FreeAndNil(LCandidate);
    LBytes := LDerived.Encode;
    LBytes[High(LBytes)] := LBytes[High(LBytes)] xor 1;
    LRejected := False;
    try
      LCandidate := DecodeSemanticStyle(LBytes);
    except
      on EAudio do LRejected := True;
    end;
    Check(LRejected and (LCandidate = nil), 'Corruption cannot publish partial semantic style');
    SetLength(LBytes, 20);
    LRejected := False;
    try
      LCandidate := DecodeSemanticStyle(LBytes);
    except
      on EAudio do
      begin
        LRejected := True;
      end;
    end;
    Check(LRejected and (LCandidate = nil), 'Truncated archive rejects before publication');
    for LCase := 0 to 11 do
    begin
      LDefinition := LSource.CopyDefinition;
      case LCase of
        0: LDefinition.Providers[1].Contract.TicksPerQuarter := 960;
        1: LDefinition.Sources[0].Split := ssTest;
        2: LDefinition.Sources[0].Exposure := [];
        3: LDefinition.Runs[1].GapBeforeFrames := 0;
        4: LDefinition.Providers[0].VocabularySha256 := StringOfChar('0', 64);
        5: LDefinition.Runs[0].Weights[0] := 2;
        6: LDefinition.Providers[0].ExtractionPolicy := '';
        7: LDefinition.Providers[0].Contract.UnknownPolicy := 'invented-unknown';
        9:
        begin
          LDefinition.Sources[1].GroupId := LDefinition.Sources[0].GroupId;
          Include(LDefinition.Sources[1].Exposure, seCalibration);
        end;
        10: Inc(LDefinition.Runs[0].EndFrame);
        11: SetLength(LDefinition.Providers, 9);
        8:
        begin
          for LRun := 0 to High(LDefinition.Runs) do
          begin
            for LCell := 0 to 1 do
            begin
              if LRun = 1 then
              begin
                LDefinition.Runs[LRun].Tokens[1][LCell] := RhythmOnsetToken;
              end
              else
              begin
                LDefinition.Runs[LRun].Tokens[1][LCell] := RhythmEmptyToken;
              end;
            end;
          end;
          LearnProviders(LDefinition);
        end;
      end;
      LRejected := False;
      try
        LCandidate := TSemanticStyle.CreateSource(LDefinition);
      except
        on Exception do LRejected := True;
      end;
      Check(LRejected and (LCandidate = nil), 'Invalid contract/exposure/run/joint evidence rejected');
    end;
    LDefinition := LSource.CopyDefinition;
    LDefinition.Sources[0].ExternalRequirement := 'laundered acquisition declaration';
    LRejected := False;
    try
      LCandidate := TSemanticStyle.CreateDerived(LSource, LDefinition);
    except
      on EAudio do LRejected := True;
    end;
    Check(LRejected, 'Derivation cannot rewrite original contribution or source requirements');
  finally
    LCandidate.Free;
    LLoaded.Free;
    LDerived.Free;
    LSource.Free;
  end;
end;

procedure MappedChecks;
var
  LDefinition: TSemanticStyleDefinition;
  LStyle: TSemanticStyle;
  LLoaded: TSemanticStyle;
  LRun: Integer;
  LRejected: Boolean;
begin
  LStyle := nil;
  LLoaded := nil;
  try
    LDefinition := GridDefinition;
    LDefinition.Providers[0].Contract.Scope.CellCount := 1;
    LDefinition.Providers[0].Contract.TimeGrid := MakeLayerTimeGrid(0, 480);
    LDefinition.Providers[1].Contract.TimeGrid := MakeLayerTimePartition([0, 120, 480]);
    for LRun := 0 to High(LDefinition.Runs) do
    begin
      SetLength(LDefinition.Runs[LRun].Tokens[0], 1);
      LDefinition.Runs[LRun].TimeGrids[0] := MakeLayerTimeGrid(0, 480);
      LDefinition.Runs[LRun].TimeGrids[1] := MakeLayerTimePartition([0, 120, 480]);
    end;
    LearnProviders(LDefinition);
    LStyle := TSemanticStyle.CreateSource(LDefinition);
    LLoaded := DecodeSemanticStyle(LStyle.Encode);
    SameGrid(LStyle, LLoaded);
    FreeAndNil(LLoaded);
    FreeAndNil(LStyle);

    LDefinition := GridDefinition;
    SetLength(LDefinition.Runs, 1);
    LDefinition.Runs[0].Tokens[0] := [TempoContextToken(500000), TempoContextToken(600000)];
    LDefinition.Runs[0].Tokens[1] := [RhythmOnsetToken];
    LDefinition.Runs[0].TimeGrids[0] := MakeLayerTimePartition([0, 120, 480]);
    LDefinition.Runs[0].TimeGrids[1] := MakeLayerTimeGrid(0, 480);
    LDefinition.Providers[0].Contract.TimeGrid := LDefinition.Runs[0].TimeGrids[0];
    LDefinition.Providers[1].Contract.TimeGrid := LDefinition.Runs[0].TimeGrids[1];
    LDefinition.Providers[1].Contract.Scope.CellCount := 1;
    LDefinition.Projections[0].TimeMapping := ltmStartTick;
    SetLength(LDefinition.Projections[0].Rules, 1);
    LearnProviders(LDefinition);
    LStyle := TSemanticStyle.CreateSource(LDefinition);
    LLoaded := DecodeSemanticStyle(LStyle.Encode);
    SameGrid(LStyle, LLoaded);
    FreeAndNil(LLoaded);
    FreeAndNil(LStyle);
    LDefinition.Projections[0].TimeMapping := ltmWholeCell;
    LRejected := False;
    try
      LStyle := TSemanticStyle.CreateSource(LDefinition);
    except
      on EAudio do
      begin
        LRejected := True;
      end;
    end;
    Check(LRejected, 'Whole-span evidence must include every overlapping provider cell');
  finally
    LLoaded.Free;
    LStyle.Free;
  end;
end;

function VoiceToken(const AAction: TWfcMusicCellAction): String;
var
  LFrame: TWfcMusicEnsembleFrame;
begin
  LFrame := Default(TWfcMusicEnsembleFrame);
  SetLength(LFrame.Voices, 1);
  LFrame.Voices[0].Action := AAction;
  if AAction <> wmcaRest then
  begin
    SetLength(LFrame.Voices[0].Tones, 1);
    LFrame.Voices[0].Tones[0] := MakeWfcMusicTone(60, 90);
  end;
  Result := EncodeWfcMusicEnsembleFrame(LFrame);
end;

function SoundProfile: TWaveStyleProfile;
var
  LSamples: TAudioSamples;
  LClip: TAudioClip;
  LDecoded: TAudioClip;
  LBytes: TAudioBytes;
  LTrace: TEnvelopeTrace;
  LEvidence: TRhythmStyleEvidence;
  LContextEvidence: TContextEvidenceArray;
  LBundle: TContextLearningBundle;
  LContext: TContextProfile;
  LIndex: Integer;
  LLevel: Double;
begin
  LClip := nil;
  LDecoded := nil;
  LTrace := nil;
  LBundle := nil;
  LContext := nil;
  try
    SetLength(LSamples, 2000);
    for LIndex := 0 to High(LSamples) do
    begin
      LSamples[LIndex] := 0.2 * Sin(2 * Pi * 50 * LIndex / 1000);
      if LIndex < 96 then
      begin
        LLevel := 0;
        case LIndex div 16 of
          1, 3: LLevel := 0.5;
          2: LLevel := 1;
          4: LLevel := 0.25;
        end;
        LSamples[LIndex] := LLevel * (1 - 2 * (LIndex mod 2));
      end;
    end;
    LClip := TAudioClip.Create(1000, 1, LSamples);
    LBytes := EncodeWavePcm16(LClip);
    SaveFixture('-sound.wav', LBytes);
    LDecoded := DecodeWave(LBytes);
    LEvidence := Default(TRhythmStyleEvidence);
    LEvidence.Source.Name := 'Native semantic sound fixture';
    LEvidence.Source.Sha256 := Sha256Bytes(LBytes);
    LEvidence.Source.Provenance := 'Controlled authored waveform; not recorded accuracy evidence';
    LEvidence.Source.SampleRate := 1000;
    LEvidence.Source.Channels := 1;
    LEvidence.Source.FrameCount := 2000;
    LEvidence.OnsetReportSha256 := StringOfChar('c', 64);
    LEvidence.Analysis := DefaultAnalysisOptions;
    LEvidence.OnsetVersion := OnsetLocationVersion;
    LEvidence.Policy := 'Declared exact fixture onset coordinates';
    LEvidence.TempoMicroseconds := 500000;
    LEvidence.OnsetFrames := [0, 500, 1000, 1500];
    LEvidence.Timbre.StartFrame := 128;
    LEvidence.Timbre.FrameCount := 200;
    LEvidence.Timbre.MaximumRelativeError := 0.001;
    LEvidence.Timbre.MinimumAcRms := 0.00001;
    LEvidence.Timbre.Policy := 'Controlled 50-Hz stationary window';
    LEvidence.Timbre.Fit := FitWavetableHarmonics(LDecoded, 128, 200, 0, 3, 50);
    LTrace := TEnvelopeTrace.Create(LDecoded, 0, 96, 0, 16);
    LEvidence.Envelope.FrameCount := 96;
    LEvidence.Envelope.WindowFrames := 16;
    LEvidence.Envelope.GateFrame := 39;
    LEvidence.Envelope.MaximumTailRatio := 0.01;
    LEvidence.Envelope.MinimumRms := 0.00001;
    LEvidence.Envelope.Policy := 'Controlled 16-frame amplitude regions with gate39';
    LEvidence.Envelope.RmsPoints := LTrace.CopyRmsPoints;
    SetLength(LContextEvidence, 1);
    LContextEvidence[0].Name := LEvidence.Source.Name;
    LContextEvidence[0].SourceSha256 := LEvidence.Source.Sha256;
    LContextEvidence[0].AdmissionPolicy := 'Declared controlled 120-BPM source clock';
    LContextEvidence[0].Grid.TicksPerQuarter := 480;
    LContextEvidence[0].Grid.StepTicks := 240;
    SetLength(LContextEvidence[0].Grid.Keys, 8);
    SetLength(LContextEvidence[0].Grid.Tempos, 8);
    for LIndex := 0 to 7 do
    begin
      LContextEvidence[0].Grid.Keys[LIndex] := MakeKeyContext(0, dmMajor);
      LContextEvidence[0].Grid.Tempos[LIndex] := 500000;
    end;
    LBundle := TContextLearningBundle.Create(LContextEvidence);
    LContext := TContextProfile.Create(LBundle);
    Result := TWaveStyleProfile.CreateSource(LContext, LEvidence);
    SaveFixture('-sound.pys', Result.Encode);
  finally
    LContext.Free;
    LBundle.Free;
    LTrace.Free;
    LDecoded.Free;
    LClip.Free;
  end;
end;

function NestedSound(const ASource: TWaveStyleProfile): TWaveStyleProfile;
var
  LContext: TContextProfile;
  LForeign: TContextProfile;
  LSelected: TContextProfile;
  LBundle: TContextLearningBundle;
  LEvidence: TContextEvidenceArray;
  LAlternative: TWaveStyleProfile;
  LPreferred: TWaveStyleProfile;
  LParent: TWaveStyleProfile;
  LPreferences: TStyleGenerationPreferences;
  LRejected: Boolean;
begin
  LContext := nil;
  LForeign := nil;
  LSelected := nil;
  LBundle := nil;
  LAlternative := nil;
  LPreferred := nil;
  LParent := nil;
  try
    Check(ASource.CopyParent(0) = nil, 'Source style explicitly has no parent');
    LRejected := False;
    try
      LParent := ASource.CopyParent(2);
    except
      on EAudio do
      begin
        LRejected := True;
      end;
    end;
    Check(LRejected, 'Parent side outside zero/one rejects');
    LPreferences := Default(TStyleGenerationPreferences);
    LPreferred := TWaveStyleProfile.CreatePreferred(ASource, LPreferences);
    Check(LPreferred.CopyParent(1) = nil, 'Preference derivation has no second parent');
    LParent := LPreferred.CopyParent(0);
    FreeAndNil(LPreferred);
    Check(LParent.Identity = ASource.Identity, 'Copied PYS parent outlives child');
    FreeAndNil(LParent);
    LContext := ASource.CopyContext;
    LBundle := LContext.CopyBundle(cdKey);
    LEvidence := LBundle.CopyEvidence;
    FreeAndNil(LBundle);
    LEvidence[0].SourceSha256 := StringOfChar('d', 64);
    LEvidence[0].Name := 'Independent controlled key reference';
    LBundle := TContextLearningBundle.Create(LEvidence);
    LForeign := TContextProfile.Create(LBundle);
    LSelected := SelectContextProfile(LForeign, LContext);
    LAlternative := TWaveStyleProfile.CreateSource(LSelected, ASource.EvidenceAt(0));
    Result := TWaveStyleProfile.CreateBlendLayers(ASource, LAlternative,
      0, 0, 1, 0, 0, 0, 1, 0, 1, 0);
    LParent := Result.CopyParent(1);
    Check(LParent.Identity = LAlternative.Identity, 'Current blend exposes exact unselected parent');
  finally
    LParent.Free;
    LPreferred.Free;
    LAlternative.Free;
    LSelected.Free;
    LForeign.Free;
    LBundle.Free;
    LContext.Free;
  end;
end;

procedure VoiceAndSoundChecks;
var
  LDefinition: TSemanticStyleDefinition;
  LSource: TSemanticStyle;
  LLoaded: TSemanticStyle;
  LSound: TWaveStyleProfile;
  LBaseSound: TWaveStyleProfile;
  LSession: TNamedVoiceSession;
  LGenerated: TWfcMusicVoicesGenerated;
  LReport: TGraphNegotiationReport;
  LProof: TWfcMusicVoicesValidationReport;
  LZones: TStyleInstrumentZones;
  LInstrument: TStyleInstrument;
  LReloadedInstrument: TStyleInstrument;
  LBefore: TAudioClip;
  LAfter: TAudioClip;
  LCase: Integer;
  LRejected: Boolean;
  LSavedBytes: TAudioBytes;
begin
  LSource := nil;
  LLoaded := nil;
  LSound := nil;
  LBaseSound := nil;
  LSession := nil;
  LInstrument := nil;
  LReloadedInstrument := nil;
  LBefore := nil;
  LAfter := nil;
  try
    LBaseSound := SoundProfile;
    LSound := NestedSound(LBaseSound);
    FreeAndNil(LBaseSound);
    LDefinition := Default(TSemanticStyleDefinition);
    LDefinition.NamedVoices := True;
    LDefinition.HarmonyMode := wmehmExact;
    SetLength(LDefinition.Providers, 3);
    LDefinition.Providers[0] := Provider('harmony', spvHarmony, 3);
    LDefinition.Providers[1] := Provider('rhythm', spvRhythm, 3);
    LDefinition.Providers[1].Contract.RoleOrder := ['solo'];
    LDefinition.Providers[2] := Provider('solo', spvVoice, 3);
    LDefinition.Providers[2].Contract.RoleId := 'solo';
    LDefinition.Providers[2].Contract.PitchBasis := ppbAbsoluteMidi;
    SetLength(LDefinition.VoiceRanges, 1);
    LDefinition.VoiceRanges[0].MinimumPitch := 60;
    LDefinition.VoiceRanges[0].MaximumPitch := 60;
    SetLength(LDefinition.Sources, 2);
    LDefinition.Sources[0] := Source(0);
    LDefinition.Sources[0].Sha256 := LSound.EvidenceAt(0).Source.Sha256;
    LDefinition.Sources[0].OriginSha256 := LDefinition.Sources[0].Sha256;
    LDefinition.Sources[0].PreparationSha256 := SemanticPreparationIdentity(LDefinition.Sources[0]);
    LDefinition.Sources[0].ExternalRequirement := 'Native sound fixture PCM16 plus authored semantic declarations';
    LDefinition.Sources[1] := Source(3);
    LDefinition.Sources[1].ExternalRequirement := 'Independent controlled key-reference declarations';
    SetLength(LDefinition.Runs, 1);
    LDefinition.Runs[0].Identity := 'authored-joint-run';
    LDefinition.Runs[0].EndFrame := 750;
    LDefinition.Runs[0].TicksPerQuarter := 480;
    LDefinition.Runs[0].TempoChanges := [MakeTempoChange(0, 500000)];
    LDefinition.Runs[0].TimeGrids := [MakeLayerTimeGrid(0, 240), MakeLayerTimeGrid(0, 240), MakeLayerTimeGrid(0, 240)];
    SetLength(LDefinition.Runs[0].Tokens, 3);
    LDefinition.Runs[0].Weights := [1, 1, 1];
    LDefinition.Runs[0].Tokens[0] := [EncodeWfcMusicPitchClassSet(MakeWfcMusicPitchClassSet(12, [0])),
      EncodeWfcMusicPitchClassSet(MakeWfcMusicPitchClassSet(12, [0])),
      EncodeWfcMusicPitchClassSet(MakeWfcMusicPitchClassSet(12, []))];
    LDefinition.Runs[0].Tokens[1] := [EncodeWfcMusicRhythmFrame(MakeWfcMusicRhythmFrame([wmcaAttack])),
      EncodeWfcMusicRhythmFrame(MakeWfcMusicRhythmFrame([wmcaHold])),
      EncodeWfcMusicRhythmFrame(MakeWfcMusicRhythmFrame([wmcaRest]))];
    LDefinition.Runs[0].Tokens[2] := [VoiceToken(wmcaAttack), VoiceToken(wmcaHold), VoiceToken(wmcaRest)];
    LearnProviders(LDefinition);
    SetLength(LDefinition.Sounds, 1);
    LDefinition.Sounds[0].RoleId := 'solo';
    LDefinition.Sounds[0].Timbre := LSound.Encode;
    LDefinition.Sounds[0].Envelope := LSound.Encode;
    FreeAndNil(LSound);
    LSource := TSemanticStyle.CreateSource(LDefinition);
    SaveFixture('-voices.pysg', LSource.Encode);
    LLoaded := DecodeSemanticStyle(LSource.Encode);
    LSession := LLoaded.CreateVoiceSession(731);
    Check(LSession.TryGenerate(LGenerated, LReport, LProof) and LProof.Valid,
      'Reloaded named harmonic/rhythm/role graph independently proves generation');
    Check((LGenerated.Frames[0].Voices[0].Tones[0].Pitch = 60) and
      (LGenerated.Frames[1].Voices[0].Action = wmcaHold), 'Joint role notes and holds retained');
    SetLength(LZones, 1);
    LZones[0].Zone.MinimumKey := 60;
    LZones[0].Zone.MaximumKey := 60;
    LZones[0].Zone.MinimumVelocity := 1;
    LZones[0].Zone.MaximumVelocity := 127;
    LZones[0].Zone.Voice := DefaultSynthVoice;
    LInstrument := LSource.CreateInstrument('solo', LZones, 8000);
    LReloadedInstrument := LLoaded.CreateInstrument('solo', LZones, 8000);
    LSavedBytes := LSource.Encode;
    FreeAndNil(LSource);
    FreeAndNil(LLoaded);
    LBefore := RenderFrameTones(LInstrument.PlanNote(60, 90, 0, 400, 71), 8000);
    LAfter := RenderFrameTones(LReloadedInstrument.PlanNote(60, 90, 0, 400, 71), 8000);
    Check(Sha256Bytes(EncodeWavePcm16(LBefore)) = Sha256Bytes(EncodeWavePcm16(LAfter)),
      'Owned reloaded measured sound renders byte-identically after styles are freed');
    SaveFixture('-sound-original.wav', EncodeWavePcm16(LBefore));
    SaveFixture('-sound-reloaded.wav', EncodeWavePcm16(LAfter));
    for LCase := 0 to 2 do
    begin
      LLoaded := DecodeSemanticStyle(LSavedBytes);
      LDefinition := LLoaded.CopyDefinition;
      FreeAndNil(LLoaded);
      if LCase = 0 then
      begin
        LDefinition.Runs[0].Tokens[1][0] := EncodeWfcMusicRhythmFrame(MakeWfcMusicRhythmFrame([wmcaRest]));
        LearnProviders(LDefinition);
      end
      else if LCase = 1 then
      begin
        LDefinition.Sounds[0].RoleId := 'undeclared';
      end
      else
      begin
        SetLength(LDefinition.Sources, 1);
      end;
      LRejected := False;
      try
        LSource := TSemanticStyle.CreateSource(LDefinition);
      except
        on Exception do LRejected := True;
      end;
      Check(LRejected, 'Invalid joint row or undeclared sound role rejects');
    end;
  finally
    LAfter.Free;
    LBefore.Free;
    LReloadedInstrument.Free;
    LInstrument.Free;
    LSession.Free;
    LLoaded.Free;
    LSource.Free;
    LSound.Free;
    LBaseSound.Free;
  end;
end;

begin
  Check(ParamCount <= 1, 'Usage: pythian.tests.semantic.style [OUTPUT_PREFIX]');
  PreparationChecks;
  GridChecks;
  MappedChecks;
  VoiceAndSoundChecks;
  WriteLn('Semantic styles: independent evidence, joint replay, exposure/ancestry, owned consumers and sound round-trip pass');
end.
