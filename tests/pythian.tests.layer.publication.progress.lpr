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
program pythian_tests_layer_publication_progress;

{$mode delphi}
{$H+}

uses
  SysUtils, pythian.progress, pythian.wfc.layers,
  wfc, wfc_model, wfc_sequence, wfc_sequence_learn, wfc_sequence_graph;

type
  TObserver = class
  public
    Stage: String;
    FinalPoint: Boolean;
    CaptureStarted: Boolean;
    PublicationReady: Boolean;
    Marker: Exception;
    CloneTotal: Int64;
    Calls: Integer;
    procedure Observe(const AWork: TWorkProgress);
  end;

var
  GChecks: Integer;
  GAborts: Integer;
  GObserver: TObserver;
  GLayers: TLearnedLayers;
  GMaps: TLayerProjections;
  GOptions: TLayerGenerationOptions;
  GReplacement: TWfcSequenceModel;

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
  LPoint: Boolean;
  LGate: Boolean;
begin
  Inc(Calls);
  Check((AWork.Units = wuItems) and (AWork.Done >= 0) and (AWork.Total >= 0) and
    ((AWork.Total = 0) or (AWork.Done <= AWork.Total)) and
    (AWork.Pass >= 0) and (AWork.Pass <= 3), 'Invalid measured layer progress');
  if AWork.Stage = 'layer_capture_weight_visits' then
  begin
    CaptureStarted := True;
  end;
  if AWork.Stage = 'layer_publication_ready' then
  begin
    PublicationReady := True;
  end;
  if (AWork.Stage = 'layer_clone_visits') and (AWork.Total > 0) then
  begin
    CloneTotal := AWork.Total;
  end;
  LGate := True;
  if Copy(Stage, 1, 13) = 'wfc_sequence_' then
  begin
    LGate := CaptureStarted;
  end;
  if Stage = 'wfc_solve_commit_visits' then
  begin
    LGate := PublicationReady;
  end;
  if FinalPoint then
  begin
    LPoint := (AWork.Total > 0) and (AWork.Done = AWork.Total);
  end
  else
  begin
    LPoint := (AWork.Done > 0) and
      ((AWork.Total = 0) or (AWork.Done < AWork.Total));
  end;
  if (Stage = AWork.Stage) and LGate and LPoint then
  begin
    raise Marker;
  end;
end;

procedure Same(const ALeft, ARight: TLayerSequences);
var
  LLayer: Integer;
  LCell: Integer;
begin
  Check(Length(ALeft) = Length(ARight), 'Layer count changed');
  for LLayer := 0 to High(ALeft) do
  begin
    Check((ALeft[LLayer].Boundary = ARight[LLayer].Boundary) and
      (ALeft[LLayer].Extent = ARight[LLayer].Extent) and
      (Length(ALeft[LLayer].Tokens) = Length(ARight[LLayer].Tokens)) and
      (Length(ALeft[LLayer].StateIndices) = Length(ARight[LLayer].StateIndices)),
      'Captured metadata changed');
    for LCell := 0 to High(ALeft[LLayer].Tokens) do
    begin
      Check((ALeft[LLayer].Tokens[LCell] = ARight[LLayer].Tokens[LCell]) and
        (ALeft[LLayer].StateIndices[LCell] = ARight[LLayer].StateIndices[LCell]),
        'Token or latent-state replay changed');
    end;
  end;
end;

function Model(const AFirst, ASecond: String): TWfcSequenceModel;
begin
  Result := LearnSequenceModelCorpus([
    MakeWfcSequenceSample([AFirst, AFirst, ASecond, ASecond, AFirst, ASecond]),
    MakeWfcSequenceSample([ASecond, ASecond, AFirst, AFirst, ASecond, AFirst])], 1);
end;

function Session: TLearnedLayerSession;
begin
  Result := TLearnedLayerSession.Create(GLayers, GMaps, ['base', 'lead', 'pad'], GOptions);
end;

procedure Prepare(const AKind: Integer);
var
  LLayer: Integer;
  LTick: Integer;
begin
  SetLength(GLayers, 3);
  GLayers[0].Model := Model('a', 'b');
  GLayers[1].Model := Model('x', 'y');
  GLayers[2].Model := Model('m', 'n');
  GLayers[0].Preferences := [MakeLayerTokenPreference('a', 2)];
  GLayers[1].Preferences := [MakeLayerTokenPreference('x', 3)];
  GLayers[2].Preferences := [MakeLayerTokenPreference('m', 5)];
  GReplacement := LearnSequenceModelCorpus([
    MakeWfcSequenceSample(['a', 'a', 'a', 'a', 'b', 'a'])], 1);
  GMaps := nil;
  SetLength(GMaps, 1);
  GMaps[0].Consumer := 1;
  GMaps[0].Provider := 0;
  GMaps[0].Rules := [MakeWfcSequenceProjectionRule('x', ['a']),
    MakeWfcSequenceProjectionRule('y', ['b'])];
  GOptions := DefaultLayerGenerationOptions;
  GOptions.CellCount := 65;
  GOptions.Extent := wseWrap;
  GOptions.Seed := 731;
  if AKind > 0 then
  begin
    GMaps[0].TimeMapping := ltmStartTick;
    GOptions.Scopes := [MakeLayerScope(33, wseWrap), MakeLayerScope(65, wseWrap),
      MakeLayerScope(65, wseWrap)];
    GOptions.TimeGrids := [MakeLayerTimeGrid(0, 2), MakeLayerTimeGrid(0, 1),
      MakeLayerTimeGrid(0, 1)];
  end;
  if AKind = 2 then
  begin
    for LLayer := 0 to 2 do
    begin
      SetLength(GOptions.TimeGrids[LLayer].Boundaries,
        GOptions.Scopes[LLayer].CellCount + 1);
      for LTick := 0 to High(GOptions.TimeGrids[LLayer].Boundaries) do
      begin
        GOptions.TimeGrids[LLayer].Boundaries[LTick] := LTick * (1 + Ord(LLayer = 0));
      end;
      GOptions.TimeGrids[LLayer].TicksPerCell := 0;
    end;
  end;
end;

procedure Release;
var
  LLayer: Integer;
begin
  GReplacement.Free;
  for LLayer := 0 to High(GLayers) do
  begin
    GLayers[LLayer].Model.Free;
  end;
  GLayers := nil;
end;

procedure PendingEdits(const ASession: TLearnedLayerSession);
var
  LAccepted: TLayerSequences;
begin
  LAccepted := ASession.CopyAccepted;
  ASession.SetConstraints('lead', [MakeWfcSequenceTokenConstraint(0,
    [LAccepted[1].Tokens[0]])]);
  ASession.SetPreferences('pad', [MakeLayerTokenPreference('n', 7)]);
end;

function Operate(const AOperation: Integer; const ASession: TLearnedLayerSession;
  var AOutput: TLayerSequences; const ACallback: TWorkProgressCallback): Boolean;
var
  LReport: TGraphNegotiationReport;
  LSelective: TGraphSelectiveNegotiationReport;
  LReplacement: TLayerModelReplacementReport;
begin
  case AOperation of
    0: Result := TryGenerateLayers(GLayers, GMaps, GOptions, AOutput, LReport, ACallback);
    1: Result := ASession.TryGenerate(AOutput, LReport, ACallback);
    2: Result := ASession.TryRegenerate(['lead'], 913, AOutput, LSelective, ACallback);
    3: Result := ASession.TryReplaceModel('base', GReplacement, 47,
      AOutput, LReplacement, ACallback);
  else
    {$ifndef REPLAY_ONLY}
    AOutput := ASession.CopyAccepted(ACallback);
    {$else}
    AOutput := ASession.CopyAccepted;
    {$endif}
    Result := True;
  end;
end;

procedure AbortAndRetry(const AOperation: Integer; const AStage: String;
  const AFinal: Boolean);
var
  LTarget: TLearnedLayerSession;
  LControl: TLearnedLayerSession;
  LBefore: TLayerSequences;
  LOutput: TLayerSequences;
  LExpected: TLayerSequences;
  LReport: TGraphNegotiationReport;
  LAborted: Boolean;
begin
  LTarget := Session;
  LControl := nil;
  try
    LControl := Session;
    Check(LControl.TryGenerate(LExpected, LReport), 'Control initial generation failed');
    if AOperation >= 2 then
    begin
      Check(LTarget.TryGenerate(LBefore, LReport), 'Target initial generation failed');
      Same(LBefore, LExpected);
    end;
    if AOperation = 2 then
    begin
      PendingEdits(LTarget);
      PendingEdits(LControl);
    end;
    LOutput := LExpected;
    GObserver.CaptureStarted := AOperation = 3;
    GObserver.PublicationReady := False;
    GObserver.Stage := AStage;
    GObserver.FinalPoint := AFinal;
    GObserver.Marker := Exception.Create('Big Boss retained publication marker');
    LAborted := False;
    try
      try
        Operate(AOperation, LTarget, LOutput, GObserver.Observe);
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
      GObserver.Stage := '';
    end;
    Check(LAborted, 'Abort not reached: '+IntToStr(AOperation)+' '+AStage);
    Same(LExpected, LOutput);
    Same(LBefore, LTarget.CopyAccepted);
    if AOperation = 2 then
    begin
      Check(LTarget.CopyPreferences('pad')[0].Multiplier = 7,
        'Abort discarded a pending preference edit');
    end;
    Check(Operate(AOperation, LTarget, LOutput, GObserver.Observe), 'Same-session retry failed');
    if AOperation = 1 then
    begin
      Same(LExpected, LOutput);
    end
    else
    begin
      Check(Operate(AOperation, LControl, LExpected, nil), 'Independent retry control failed');
      Same(LExpected, LOutput);
    end;
    if AOperation >= 1 then
    begin
      Same(LExpected, LTarget.CopyAccepted);
      LOutput[0].Tokens[0] := 'caller edit';
      LOutput[0].StateIndices[0] := -99;
      LOutput[0].Boundary := TWfcModelBoundary(1 - Ord(LOutput[0].Boundary));
      Same(LExpected, LTarget.CopyAccepted);
    end;
  finally
    LControl.Free;
    LTarget.Free;
  end;
end;

procedure Replay(const AKind: Integer);
var
  LSession: TLearnedLayerSession;
  LOutput: TLayerSequences;
  LOperation: Integer;
  LLayer: Integer;
  LCell: Integer;
begin
  LSession := Session;
  try
    for LOperation := 1 to 3 do
    begin
      if LOperation = 2 then
      begin
        PendingEdits(LSession);
      end;
      if LOperation = 3 then
      begin
        LSession.SetConstraints('lead', nil);
      end;
      Check(Operate(LOperation, LSession, LOutput, nil), 'Replay operation failed');
      for LLayer := 0 to High(LOutput) do
      begin
        Write(AKind, '/', LOperation, '/', LLayer, ':', Ord(LOutput[LLayer].Boundary),
          '/', Ord(LOutput[LLayer].Extent), ':');
        for LCell := 0 to High(LOutput[LLayer].Tokens) do
        begin
          Write(LOutput[LLayer].Tokens[LCell], '=', LOutput[LLayer].StateIndices[LCell], ',');
        end;
        WriteLn;
      end;
    end;
  finally
    LSession.Free;
  end;
end;

procedure Run(const AKind: Integer);
const
  CStages: array[0..5] of String = ('layer_capture_visits', 'layer_relation_visits',
    'layer_clone_visits', 'layer_capture_ready', 'layer_publication_ready',
    'wfc_sequence_project_tokens');
var
  LOperation: Integer;
  LStage: String;
begin
  Prepare(AKind);
  try
    {$ifdef REPLAY_ONLY}
    Replay(AKind);
    {$else}
    for LOperation := 0 to 3 do
    begin
      for LStage in CStages do
      begin
        if (LOperation = 0) and (LStage = 'layer_clone_visits') then
        begin
          Continue;
        end;
        AbortAndRetry(LOperation, LStage, True);
      end;
      if LOperation > 0 then
      begin
        AbortAndRetry(LOperation, 'layer_clone_visits', False);
      end;
      if LOperation < 3 then
      begin
        AbortAndRetry(LOperation, 'layer_capture_weight_visits', True);
        AbortAndRetry(LOperation, 'wfc_solve_commit_visits', True);
      end;
    end;
    AbortAndRetry(4, 'layer_clone_visits', False);
    AbortAndRetry(4, 'layer_clone_visits', True);
    Check(GObserver.CloneTotal = 3 + 2 * (195 - 32 * Ord(AKind > 0)),
      'Exact clone visit oracle differs');
    {$endif}
  finally
    Release;
  end;
end;

begin
  GObserver := TObserver.Create;
  try
    Run(0);
    Run(1);
    Run(2);
    {$ifndef REPLAY_ONLY}
    WriteLn('Layer publication: ', GChecks, ' checks; ', GAborts,
      ' original abort/retries; ', GObserver.Calls, ' measured callbacks');
    {$endif}
  finally
    GObserver.Free;
  end;
end.
