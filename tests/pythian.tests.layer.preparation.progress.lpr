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
  SysUtils, pythian.progress, pythian.wfc.layers, wfc, wfc_sequence,
  wfc_sequence_learn, wfc_sequence_text, wfc_sequence_graph;

type
  TObserver = class
  public
    Calls: Integer;
    PrepareTotal: Int64;
    ConstraintTotal: Int64;
    PreferenceTotal: Int64;
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
begin
  Inc(Calls);
  Check((AWork.Units = wuItems) and (AWork.Done >= 0) and
    ((AWork.Total = 0) or (AWork.Total = AWork.Done)), 'Invalid owned-visit units or totals');
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
  if (AWork.Stage = AbortStage) and (AWork.Done >= MinimumDone) and
    (((not AbortFinal) and (AWork.Total = 0)) or
      (AbortFinal and (AWork.Total > 0))) then
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
    LSession.SetPreferences('a', nil, GObserver.Observe);
    Check(GObserver.PreferenceTotal = 2, 'Authored preference-validation oracle differs');
  finally
    LSession.Free;
    LLayers[0].Model.Free;
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
    Check(LAborted and (LAssigned = LSession), 'Abort did not preserve assigned session');
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
    AbortOperation(0, 'layer_prepare_visits', False, 256);
    AbortOperation(0, 'layer_prepare_visits', True, 1);
    AbortOperation(0, 'layer_constraint_visits', True, 1);
    AbortOperation(1, 'layer_prepare_visits', True, 1);
    LMasks := [MakeWfcSequenceTokenConstraint(0, ['x'])];
    AbortOperation(2, 'layer_constraint_visits', False, 256);
    AbortOperation(2, 'layer_constraint_visits', True, 1);
    AbortOperation(3, 'layer_preference_visits', True, 1);
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
    RunCase(0);
    RunCase(1);
    RunCase(2);
    WriteLn('Layer preparation: ', GChecks, ' checks; ', GAborts,
      ' abort/retries; ', GObserver.Calls, ' aggregated callbacks; visit oracles 13/8/2');
  finally
    GObserver.Free;
  end;
end.
