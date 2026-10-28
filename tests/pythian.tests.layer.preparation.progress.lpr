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
program pythian_tests_layer_preparation_progress;

{$mode delphi}
{$H+}

uses
  SysUtils, pythian.progress, pythian.learning, pythian.wfc.layers,
  pythian.wfc.generation, pythian.wfc.learning, wfc, wfc_model, wfc_sequence,
  wfc_sequence_learn, wfc_sequence_text, wfc_sequence_graph;

const
  CSolveStages: array[0..2] of String = ('wfc_solve_prepare_visits',
    'wfc_solve_search_visits', 'wfc_solve_commit_visits');
  CCompanionStages: array[0..3] of String = ('layer_wfc_model_rows',
    'layer_wfc_constraint_rows', 'layer_wfc_snapshot_cells', 'layer_wfc_mask_rows');

type
  TObserver = class
  public
    Calls: Integer;
    PrepareTotal: Int64;
    ConstraintTotal: Int64;
    PreferenceTotal: Int64;
    WfcCalls: Integer;
    SolveCalls: Integer;
    WfcModelTotal: Int64;
    WfcSnapshotTotal: Int64;
    AbortStage: String;
    AbortFinal: Boolean;
    MinimumDone: Int64;
    Marker: Exception;
    procedure Observe(const AWork: TWorkProgress);
  end;

var
  GChecks: Integer;
  GAborts: Integer;
  GObserver: TObserver;

procedure Check(const ACondition: Boolean; const AMessage: String);
begin
  Inc(GChecks);
  if not ACondition then
  begin
    raise Exception.Create(AMessage);
  end;
end;

procedure TObserver.Observe(const AWork: TWorkProgress);
var
  LCompanion: Boolean;
  LAbortPoint: Boolean;
begin
  Inc(Calls);
  if Copy(AWork.Stage, 1, 10) = 'wfc_solve_' then
  begin
    Inc(SolveCalls);
    Check((AWork.Pass >= 0) and (AWork.Pass <= 2), 'Solve pass mapping differs');
  end;
  LCompanion := Copy(AWork.Stage, 1, 10) = 'layer_wfc_';
  Check((AWork.Units = wuItems) and (AWork.Done >= 0) and
    (AWork.Total >= 0) and ((AWork.Total = 0) or (AWork.Done <= AWork.Total)),
    'Invalid preparation units or totals');
  if LCompanion then
  begin
    Inc(WfcCalls);
    if AWork.Stage = 'layer_wfc_model_rows' then
    begin
      WfcModelTotal := AWork.Total;
    end;
    if AWork.Stage = 'layer_wfc_snapshot_cells' then
    begin
      WfcSnapshotTotal := AWork.Total;
    end;
  end
  else if (Copy(AWork.Stage, 1, 13) <> 'wfc_sequence_') and
    (Copy(AWork.Stage, 1, 9) <> 'acoustic_') then
  begin
    Check((AWork.Total = 0) or (AWork.Total = AWork.Done),
      'Owned visit total was estimated from companion work');
  end;
  if (AWork.Total > 0) then
  begin
    if AWork.Stage = 'layer_prepare_visits' then
    begin
      PrepareTotal := AWork.Total;
    end;
    if AWork.Stage = 'layer_constraint_visits' then
    begin
      ConstraintTotal := AWork.Total;
    end;
    if AWork.Stage = 'layer_preference_visits' then
    begin
      PreferenceTotal := AWork.Total;
    end;
  end;
  if AbortFinal then
  begin
    LAbortPoint := (AWork.Total > 0) and (AWork.Done = AWork.Total);
  end
  else if LCompanion then
  begin
    LAbortPoint := (AWork.Done > 0) and (AWork.Done < AWork.Total);
  end
  else
  begin
    LAbortPoint := AWork.Total = 0;
  end;
  if (AWork.Stage = AbortStage) and (AWork.Done >= MinimumDone) and LAbortPoint then
  begin
    raise Marker;
  end;
end;

procedure Same(const ALeft, ARight: TLayerSequences);
var
  LLayer: Integer;
  LCell: Integer;
begin
  Check(Length(ALeft) = Length(ARight), 'Layer count differs');
  for LLayer := 0 to High(ALeft) do
  begin
    Check(Length(ALeft[LLayer].Tokens) = Length(ARight[LLayer].Tokens), 'Cell count differs');
    for LCell := 0 to High(ALeft[LLayer].Tokens) do
    begin
      Check((ALeft[LLayer].Tokens[LCell] = ARight[LLayer].Tokens[LCell]) and
        (ALeft[LLayer].StateIndices[LCell] = ARight[LLayer].StateIndices[LCell]),
        'Observed/aborted preparation changed actual WFC token or latent state');
    end;
  end;
end;

function Model(const AFirst, ASecond: String): TWfcSequenceModel;
begin
  Result := LearnSequenceModelCorpus([
    MakeWfcSequenceSample([AFirst, AFirst, ASecond, ASecond, AFirst, ASecond]),
    MakeWfcSequenceSample([ASecond, ASecond, AFirst, AFirst, ASecond, AFirst])], 1);
end;

procedure CheckVisitOracle;
var
  LLayers: TLearnedLayers;
  LOptions: TLayerGenerationOptions;
  LSession: TLearnedLayerSession;
begin
  SetLength(LLayers, 1);
  LLayers[0].Model := Model('a', 'b');
  LSession := nil;
  try
    LOptions := DefaultLayerGenerationOptions;
    LOptions.CellCount := 4;
    LOptions.Extent := wseWrap;
    LSession := TLearnedLayerSession.Create(LLayers, nil, ['a'], LOptions, GObserver.Observe);
    { Two request layer visits, one name and character, one model, three graph
      pass visits, one baseline layer and four baseline cells. Companion
      internals and initial masks are NOT added to that thirteen. }
    Check(GObserver.PrepareTotal = 13, 'Authored construction visit oracle differs');
    Check(GObserver.ConstraintTotal = 8, 'Authored snapshot/reset cell oracle differs');
    Check((GObserver.WfcModelTotal = LLayers[0].Model.StateCount) and
      (GObserver.WfcSnapshotTotal = 4) and (GObserver.WfcCalls > 0),
      'Actual companion model/cell counts did not reach the primary callback');
    LSession.SetPreferences('a', nil, GObserver.Observe);
    Check(GObserver.PreferenceTotal = 2, 'Authored preference-validation oracle differs');
  finally
    LSession.Free;
    LLayers[0].Model.Free;
  end;
end;

procedure CheckDirectGeneration;
var
  LModel: TWfcSequenceModel;
  LOptions: TAcousticGenerationOptions;
  LTokens: TWfcModelTokens;
  LExpectedTokens: TWfcModelTokens;
  LIndices: TAcousticIndices;
  LExpectedIndices: TAcousticIndices;
  LReport: TGraphSolveReport;
  LStage: String;
  LFinal: Boolean;
  LAcoustic: Boolean;
  LAborted: Boolean;
  LIndex: Integer;
begin
  LModel := Model(AcousticToken(0), AcousticToken(1));
  try
    LOptions := DefaultAcousticGenerationOptions;
    LOptions.FrameCount := 128;
    Check(TryGenerateTokenSequence(LModel, LOptions, nil, LExpectedTokens,
      LReport), 'Direct token control failed');
    Check(TryGenerateAcousticSequence(LModel, LOptions, nil, LExpectedIndices,
      LReport), 'Acoustic-index control failed');
    for LAcoustic := False to True do
    begin
      for LStage in CSolveStages do
      begin
        for LFinal := False to True do
        begin
          GObserver.AbortStage := LStage;
          GObserver.AbortFinal := LFinal;
          GObserver.MinimumDone := 1;
          GObserver.Marker := Exception.Create('Big Boss acoustic solve marker');
          LTokens := ['retained'];
          LIndices := [19];
          LAborted := False;
          try
            try
              if LAcoustic then
              begin
                TryGenerateAcousticSequence(LModel, LOptions, nil, LIndices,
                  LReport, GObserver.Observe);
              end
              else
              begin
                TryGenerateTokenSequence(LModel, LOptions, nil, LTokens,
                  LReport, GObserver.Observe);
              end;
            except
              on LException: Exception do
              begin
                Check(LException = GObserver.Marker, 'Direct solve exception changed');
                GObserver.Marker := nil;
                LAborted := True;
                Inc(GAborts);
              end;
            end;
          finally
            GObserver.Marker.Free;
            GObserver.Marker := nil;
            GObserver.AbortStage := '';
          end;
          Check(LAborted and (Length(LTokens) = 1) and
            (LTokens[0] = 'retained') and (Length(LIndices) = 1) and
            (LIndices[0] = 19), 'Direct abort published caller data');
          Check(TryGenerateTokenSequence(LModel, LOptions, nil, LTokens,
            LReport, GObserver.Observe), 'Observed token retry failed');
          Check(TryGenerateAcousticSequence(LModel, LOptions, nil, LIndices,
            LReport, GObserver.Observe), 'Observed index retry failed');
          Check((Length(LTokens) = Length(LExpectedTokens)) and
            (Length(LIndices) = Length(LExpectedIndices)), 'Direct lengths differ');
          for LIndex := 0 to High(LTokens) do
          begin
            Check((LTokens[LIndex] = LExpectedTokens[LIndex]) and
              (LIndices[LIndex] = LExpectedIndices[LIndex]), 'Direct replay differs');
          end;
        end;
      end;
    end;
  finally
    LModel.Free;
  end;
end;
procedure RunCase(const AKind: Integer);
var
  LLayers: TLearnedLayers;
  LMaps: TLayerProjections;
  LOptions: TLayerGenerationOptions;
  LSession: TLearnedLayerSession;
  LControl: TLearnedLayerSession;
  LRetry: TLearnedLayerSession;
  LAssigned: TLearnedLayerSession;
  LBefore: TLayerSequences;
  LAfter: TLayerSequences;
  LExpected: TLayerSequences;
  LReport: TGraphNegotiationReport;
  LSelective: TGraphSelectiveNegotiationReport;
  LMasks: TWfcSequenceTokenConstraints;
  LTexts: array[0..1] of String;
  LBoundary: Integer;
  LLayer: Integer;
  LAborted: Boolean;
  LMask: Integer;
  LStage: String;
  LFinal: Boolean;
  LOperation: Integer;

  procedure AbortOperation(const AOperation: Integer; const AStage: String;
    const AFinal: Boolean; const AMinimum: Int64);
  begin
    GObserver.AbortStage := AStage;
    GObserver.AbortFinal := AFinal;
    GObserver.MinimumDone := AMinimum;
    GObserver.Marker := Exception.Create('Big Boss layer observer marker');
    LAborted := False;
    LAssigned := LSession;
    LAfter := LBefore;
    try
      try
        case AOperation of
          0: LAssigned := TLearnedLayerSession.Create(LLayers, LMaps,
            ['provider', 'voice'], LOptions, GObserver.Observe);
          1: TryGenerateLayers(LLayers, LMaps, LOptions, LAfter, LReport, GObserver.Observe);
          2: LSession.SetConstraints('voice', LMasks, GObserver.Observe);
          3: LSession.SetPreferences('voice', [MakeLayerTokenPreference('x', 7)], GObserver.Observe);
        end;
      except
        on LException: Exception do
        begin
          if LException <> GObserver.Marker then
          begin
            raise;
          end;
          GObserver.Marker := nil;
          LAborted := True;
          Inc(GAborts);
        end;
      end;
    finally
      GObserver.Marker.Free;
      GObserver.Marker := nil;
      GObserver.AbortStage := '';
      if LAssigned <> LSession then
      begin
        LAssigned.Free;
      end;
    end;
    Check(LAborted and (LAssigned = LSession), 'Abort did not preserve assigned session at ' +
      AStage + ' final=' + BoolToStr(AFinal, True));
    Same(LBefore, LAfter);
    Same(LBefore, LSession.CopyAccepted);
    if AOperation = 2 then
    begin
      Check(LSession.TryRegenerate(['provider'], 731, LAfter, LSelective), 'Aborted-mask retry failed');
      Check(LControl.TryRegenerate(['provider'], 731, LExpected, LSelective), 'Control regeneration failed');
      Same(LExpected, LAfter);
      LBefore := LAfter;
    end;
    if AOperation = 3 then
    begin
      Check((Length(LSession.CopyPreferences('voice')) = 1) and
        (LSession.CopyPreferences('voice')[0].Multiplier = 3), 'Aborted preference was published');
    end;
  end;

  procedure AbortSolve(const AOperation: Integer; const AStage: String;
    const AFinal: Boolean; const AMinimum: Int64);
  var
    LTarget: TLearnedLayerSession;
    LReplacement: TLayerModelReplacementReport;
  begin
    LTarget := LSession;
    if AOperation = 1 then
    begin
      LTarget := TLearnedLayerSession.Create(LLayers, LMaps,
        ['provider', 'voice'], LOptions);
    end;
    try
      GObserver.AbortStage := AStage;
      GObserver.AbortFinal := AFinal;
      GObserver.MinimumDone := AMinimum;
      GObserver.Marker := Exception.Create('Big Boss solve cancellation marker');
      LAborted := False;
      LAfter := LBefore;
      try
        try
          case AOperation of
            0: TryGenerateLayers(LLayers, LMaps, LOptions, LAfter, LReport, GObserver.Observe);
            1: LTarget.TryGenerate(LAfter, LReport, GObserver.Observe);
            2: LTarget.TryRegenerate(['provider'], 731, LAfter, LSelective, GObserver.Observe);
            3: LTarget.TryReplaceModel('provider', LLayers[0].Model, 731,
              LAfter, LReplacement, GObserver.Observe);
          end;
        except
          on LException: Exception do
          begin
            Check(LException = GObserver.Marker, 'Original solve exception changed');
            GObserver.Marker := nil;
            LAborted := True;
            Inc(GAborts);
          end;
        end;
      finally
        GObserver.Marker.Free;
        GObserver.Marker := nil;
        GObserver.AbortStage := '';
      end;
      Check(LAborted, 'Solve abort was not reached at ' + AStage);
      Same(LBefore, LAfter);
      if AOperation = 1 then
      begin
        Check(Length(LTarget.CopyAccepted) = 0, 'Cancelled initial solve accepted data');
      end
      else
      begin
        Same(LBefore, LSession.CopyAccepted);
      end;
      case AOperation of
        0: begin
          Check(TryGenerateLayers(LLayers, LMaps, LOptions, LAfter, LReport), 'Finite retry failed');
          Check(TryGenerateLayers(LLayers, LMaps, LOptions, LExpected, LReport), 'Finite control failed');
        end;
        1: begin
          Check(LTarget.TryGenerate(LAfter, LReport), 'Session retry failed');
          Check(TryGenerateLayers(LLayers, LMaps, LOptions, LExpected, LReport), 'Session control failed');
        end;
        2: begin
          Check(LSession.TryRegenerate(['provider'], 731, LAfter, LSelective), 'Regeneration retry failed');
          Check(LControl.TryRegenerate(['provider'], 731, LExpected, LSelective), 'Regeneration control failed');
        end;
        3: begin
          Check(LSession.TryReplaceModel('provider', LLayers[0].Model, 731,
            LAfter, LReplacement), 'Replacement retry failed');
          Check(LControl.TryReplaceModel('provider', LLayers[0].Model, 731,
            LExpected, LReplacement), 'Replacement control failed');
        end;
      end;
      Same(LExpected, LAfter);
      if AOperation >= 2 then
      begin
        LBefore := LAfter;
      end;
    finally
      if LTarget <> LSession then
      begin
        LTarget.Free;
      end;
    end;
  end;
begin
  SetLength(LLayers, 2);
  LLayers[0].Model := Model('a', 'b');
  LLayers[1].Model := Model('x', 'y');
  LLayers[0].Preferences := [MakeLayerTokenPreference('a', 2)];
  LLayers[1].Preferences := [MakeLayerTokenPreference('x', 3)];
  LSession := nil;
  LControl := nil;
  LRetry := nil;
  try
    for LLayer := 0 to 1 do
    begin
      LTexts[LLayer] := EncodeWfcSequenceText(LLayers[LLayer].Model);
    end;
    SetLength(LMaps, 1);
    LMaps[0].Provider := 0;
    LMaps[0].Consumer := 1;
    LMaps[0].Rules := [MakeWfcSequenceProjectionRule('x', ['a']),
      MakeWfcSequenceProjectionRule('y', ['b'])];
    LOptions := DefaultLayerGenerationOptions;
    LOptions.CellCount := 128;
    LOptions.Extent := wseWrap;
    LOptions.Seed := 731;
    if AKind <> 0 then
    begin
      LMaps[0].TimeMapping := ltmStartTick;
      LOptions.Scopes := [MakeLayerScope(64, wseWrap), MakeLayerScope(128, wseWrap)];
      LOptions.TimeGrids := [MakeLayerTimeGrid(0, 8), MakeLayerTimeGrid(0, 4)];
    end;
    if AKind = 2 then
    begin
      for LLayer := 0 to 1 do
      begin
        SetLength(LOptions.TimeGrids[LLayer].Boundaries, LOptions.Scopes[LLayer].CellCount + 1);
        for LBoundary := 0 to High(LOptions.TimeGrids[LLayer].Boundaries) do
        begin
          LOptions.TimeGrids[LLayer].Boundaries[LBoundary] := LBoundary * (8 div (LLayer + 1));
        end;
        LOptions.TimeGrids[LLayer].TicksPerCell := 0;
      end;
    end;
    LSession := TLearnedLayerSession.Create(LLayers, LMaps, ['provider', 'voice'], LOptions);
    LControl := TLearnedLayerSession.Create(LLayers, LMaps, ['provider', 'voice'], LOptions);
    Check(LSession.TryGenerate(LBefore, LReport), 'Initial session solve failed');
    Check(LControl.TryGenerate(LExpected, LReport), 'Initial control solve failed');
    Same(LBefore, LExpected);
    LRetry := TLearnedLayerSession.Create(LLayers, LMaps, ['provider', 'voice'], LOptions, GObserver.Observe);
    Check(LRetry.TryGenerate(LAfter, LReport), 'Observed construction solve failed');
    Same(LBefore, LAfter);
    FreeAndNil(LRetry);
    Check(TryGenerateLayers(LLayers, LMaps, LOptions, LExpected, LReport), 'Unobserved finite solve failed');
    Check(TryGenerateLayers(LLayers, LMaps, LOptions, LAfter, LReport, GObserver.Observe), 'Observed finite solve failed');
    Same(LExpected, LAfter);
    { All three timing layouts exercise the same primary bridge. Generic solve
      final callbacks remain inside WFC rollback, before accepted session capture. }
    for LOperation := 0 to 3 do
    begin
      for LStage in CSolveStages do
      begin
        AbortSolve(LOperation, LStage, False, 0);
        AbortSolve(LOperation, LStage, False, 256);
        AbortSolve(LOperation, LStage, True, 1);
      end;
    end;
    AbortOperation(0, 'layer_prepare_visits', False, 256);
    AbortOperation(0, 'layer_prepare_visits', True, 1);
    AbortOperation(0, 'layer_constraint_visits', True, 1);
    AbortOperation(1, 'layer_prepare_visits', True, 1);
    LMasks := [MakeWfcSequenceTokenConstraint(0, ['x'])];
    AbortOperation(2, 'layer_constraint_visits', False, 256);
    AbortOperation(2, 'layer_constraint_visits', True, 1);
    AbortOperation(3, 'layer_preference_visits', True, 1);
    if AKind = 0 then
    begin
      { Real session mutation covers every generic phase, including final-mask
        rollback after earlier masks have already changed domains. }
      SetLength(LMasks, 128);
      for LMask := 0 to High(LMasks) do
      begin
        LMasks[LMask] := MakeWfcSequenceTokenConstraint(LMask, ['x', 'y']);
      end;
      LMasks[0] := MakeWfcSequenceTokenConstraint(0, ['x']);
      for LStage in CCompanionStages do
      begin
        for LFinal := False to True do
        begin
          AbortOperation(2, LStage, LFinal, 1);
        end;
      end;
    end;
    LRetry := TLearnedLayerSession.Create(LLayers, LMaps, ['provider', 'voice'], LOptions, GObserver.Observe);
    Check(LRetry.TryGenerate(LAfter, LReport), 'Construction retry failed');
    Same(LExpected, LAfter);
    LRetry.SetConstraints('voice', LMasks, GObserver.Observe);
    LRetry.SetConstraints('voice', nil, GObserver.Observe);
    for LLayer := 0 to 1 do
    begin
      Check(LTexts[LLayer] = EncodeWfcSequenceText(LLayers[LLayer].Model), 'Borrowed model changed');
    end;
  finally
    LRetry.Free;
    LControl.Free;
    LSession.Free;
    LLayers[1].Model.Free;
    LLayers[0].Model.Free;
  end;
end;

begin
  GObserver := TObserver.Create;
  try
    CheckVisitOracle;
    CheckDirectGeneration;
    RunCase(0);
    RunCase(1);
    RunCase(2);
    WriteLn('Layer preparation: ', GChecks, ' checks; ', GAborts,
      ' abort/retries; ', GObserver.Calls, ' callbacks (', GObserver.WfcCalls,
      ' companion); ', GObserver.SolveCalls, ' solve callbacks; visit oracles 13/8/2');
  finally
    GObserver.Free;
  end;
end.
