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
program pythian_tests_voice_publication_progress;

{$mode delphi}
{$H+}

uses
  SysUtils, pythian.audio, pythian.progress, pythian.wfc.voices,
  pythian.wfc.layers, pythian.wfc.providers, pythian.wfc.provider.contracts,
  wfc, wfc_model, wfc_sequence, wfc_sequence_learn, wfc_sequence_text,
  wfc_music, wfc_music_sequence, wfc_music_ensemble, wfc_music_ensemble_graph,
  wfc_music_voices_graph;

type
  { Each public boundary must preserve its caller's previous managed result. }
  TOperation = (opGenerate, opRegenerate, opReplace, opCopyAccepted,
    opSetMask, opSetPreferences, opCopyMask, opCopyPreferences, opProvider);
  { Record real emitted start/interior/final points, including the final solver
    checkpoint after guarded capture. No invented progress point is tested. }
  TAbortPoint = record
    Stage: String;
    Point: Integer;
    AfterReady: Boolean;
  end;
  TAbortPoints = array of TAbortPoint;
  { The callback is borrowed. It can raise an original caller exception and
    attempts mutation/state-copy reentry while its session is busy. }
  TObserver = class
  public
    Points: TAbortPoints;
    Discover: Boolean;
    Enabled: Boolean;
    Raised: Boolean;
    Ready: Boolean;
    CaptureStarted: Boolean;
    Target: TAbortPoint;
    Marker: Exception;
    Calls: Integer;
    Reentry: Boolean;
    ReentryChecked: Boolean;
    Session: TNamedVoiceSession;
    procedure Observe(const AWork: TWorkProgress);
  end;

var
  GChecks: Integer;
  GAborts: Integer;
  GConfig: TWfcMusicVoicesGraphConfig;
  GReplacement: TWfcSequenceModel;
  GContract: TProviderContract;
  GModelBytes: array[0..4] of String;
  GObserver: TObserver;
  GOperation: TOperation;
  GOutput: TWfcMusicVoicesGenerated;
  GMaskResult: TWfcSequenceTokenConstraints;
  GPreferenceResult: TLayerTokenPreferences;
  GProviderResult: TStyleProviderDescription;
  GProposedMask: TWfcSequenceTokenConstraints;
  GProposedPreferences: TLayerTokenPreferences;

procedure Check(const AValue: Boolean; const AMessage: String);
begin
  Inc(GChecks);
  if not AValue then
  begin
    raise Exception.Create(AMessage);
  end;
end;

procedure FreeConfig(var AConfig: TWfcMusicVoicesGraphConfig); forward;

function MakeConfig: TWfcMusicVoicesGraphConfig;
var
  LVoice: Integer;
  LChoice: Integer;
  LNext: Integer;
  LTokens: TWfcModelTokens;
  LSamples: TWfcSequenceSamples;
  LFrame: TWfcMusicEnsembleFrame;
begin
  Result := Default(TWfcMusicVoicesGraphConfig);
  try
    Result.StepsPerOctave := 12;
    Result.HarmonyMode := wmehmExact;
    Result.HarmonyModel := LearnSequenceModel([EncodeWfcMusicPitchClassSet(
      MakeWfcMusicPitchClassSet(12, [0]))], 1);
    Result.RhythmModel := LearnSequenceModel([EncodeWfcMusicRhythmFrame(
      MakeWfcMusicRhythmFrame([wmcaAttack, wmcaAttack]))], 1);
    SetLength(Result.Voices, 2);
    SetLength(LTokens, 17);
    SetLength(LFrame.Voices, 1);
    LFrame.Voices[0].Action := wmcaAttack;
    SetLength(LFrame.Voices[0].Tones, 1);
    for LVoice := 0 to 1 do
    begin
      for LChoice := 0 to High(LTokens) do
      begin
        LFrame.Voices[0].Tones[0] := MakeWfcMusicTone(48 + 12 * LVoice, LChoice + 1);
        LTokens[LChoice] := EncodeWfcMusicEnsembleFrame(LFrame);
      end;
      { Every pair is an authored admissible transition. A single ascending
        training run cannot support the deliberately selected alternate start. }
      SetLength(LSamples, Length(LTokens) * Length(LTokens));
      for LChoice := 0 to High(LTokens) do
      begin
        for LNext := 0 to High(LTokens) do
        begin
          LSamples[LChoice * Length(LTokens) + LNext] :=
            MakeWfcSequenceSample([LTokens[LChoice], LTokens[LNext]]);
        end;
      end;
      Result.Voices[LVoice].Model := LearnSequenceModelCorpus(LSamples, 1);
      Result.Voices[LVoice].MinPitch := 48 + 12 * LVoice;
      Result.Voices[LVoice].MaxPitch := 48 + 12 * LVoice;
    end;
    SetLength(Result.PairConstraints, 1);
    Result.PairConstraints[0].LowerVoice := 0;
    Result.PairConstraints[0].UpperVoice := 1;
    Result.PairConstraints[0].MinGap := 12;
    Result.PairConstraints[0].MaxGap := 12;
    Result.PairConstraints[0].RestPolicy := wmvprSuspend;
  except
    FreeConfig(Result);
    raise;
  end;
end;

procedure FreeConfig(var AConfig: TWfcMusicVoicesGraphConfig);
var
  LVoice: Integer;
begin
  for LVoice := 0 to High(AConfig.Voices) do
  begin
    AConfig.Voices[LVoice].Model.Free;
  end;
  AConfig.HarmonyModel.Free;
  AConfig.RhythmModel.Free;
  AConfig := Default(TWfcMusicVoicesGraphConfig);
end;

function Evidence(const AValue: TWfcMusicVoicesGenerated): String;
var
  LLayer: Integer;
  LCell: Integer;
begin
  Result := '';
  for LLayer := 0 to High(AValue.Layers) do
    for LCell := 0 to High(AValue.Layers[LLayer].Tokens) do
      Result := Result + AValue.Layers[LLayer].Tokens[LCell] + '=' +
        IntToStr(AValue.Layers[LLayer].StateIndices[LCell]) + '|';
  for LCell := 0 to High(AValue.Frames) do
    Result := Result + EncodeWfcMusicEnsembleFrame(AValue.Frames[LCell]);
  for LLayer := 0 to High(AValue.Coverage) do
  begin
    Result := Result + 'C' + IntToStr(AValue.Coverage[LLayer].PitchClass);
    for LCell := 0 to High(AValue.Coverage[LLayer].Suppliers) do
      Result := Result + ':' + IntToStr(AValue.Coverage[LLayer].Suppliers[LCell]);
  end;
end;


function MaskEvidence(const AMask: TWfcSequenceTokenConstraints): String;
var
  LRow: Integer;
  LToken: Integer;
begin
  Result := '';
  for LRow := 0 to High(AMask) do
  begin
    Result := Result + IntToStr(AMask[LRow].Position) + ':';
    for LToken := 0 to High(AMask[LRow].AllowedTokens) do
    begin
      Result := Result + AMask[LRow].AllowedTokens[LToken] + '|';
    end;
    Result := Result + ';';
  end;
end;

function PreferenceEvidence(const AValue: TLayerTokenPreferences): String;
var
  LIndex: Integer;
begin
  Result := '';
  for LIndex := 0 to High(AValue) do
  begin
    Result := Result + AValue[LIndex].Token + ':' +
      IntToStr(AValue[LIndex].Multiplier) + '|';
  end;
end;

function FullEvidence(const AValue: TWfcMusicVoicesGenerated): String;
var
  LIndex: Integer;
begin
  Result := Evidence(AValue);
  for LIndex := 0 to High(AValue.Layers) do
  begin
    Result := Result + BoolToStr(AValue.Layers[LIndex].Boundary.HasPrevious, True) +
      ':' + IntToStr(AValue.Layers[LIndex].Boundary.PreviousState) + ':' +
      BoolToStr(AValue.Layers[LIndex].Boundary.RequireObservedEnd, True);
  end;
end;

function StateEvidence(const ASession: TNamedVoiceSession): String;
var
  LName: String;
  LIndex: Integer;
  LModel: TWfcSequenceModel;
begin
  Result := FullEvidence(ASession.CopyAccepted);
  for LIndex := 0 to ASession.ProviderCount - 1 do
  begin
    LName := ASession.ProviderName(LIndex);
    Result := Result + LName + MaskEvidence(ASession.CopyConstraints(LName)) +
      PreferenceEvidence(ASession.CopyPreferences(LName)) +
      BoolToStr(ASession.HasPending(LName), True);
    LModel := ASession.CopyModel(LName);
    try
      Result := Result + EncodeWfcSequenceText(LModel);
    finally
      LModel.Free;
    end;
  end;
end;

function OutputEvidence: String;
var
  LIndex: Integer;
begin
  Result := FullEvidence(GOutput) + MaskEvidence(GMaskResult) +
    PreferenceEvidence(GPreferenceResult) + GProviderResult.Name +
    PreferenceEvidence(GProviderResult.Preferences);
  for LIndex := 0 to High(GProviderResult.Choices) do
  begin
    Result := Result + GProviderResult.Choices[LIndex].Token;
  end;
end;

procedure ResetOutputs;
begin
  GOutput := Default(TWfcMusicVoicesGenerated);
  SetLength(GOutput.Layers, 1);
  SetLength(GOutput.Layers[0].Tokens, 1);
  GOutput.Layers[0].Tokens[0] := 'caller music';
  SetLength(GOutput.Layers[0].StateIndices, 1);
  GOutput.Layers[0].StateIndices[0] := -71;
  GMaskResult := nil;
  SetLength(GMaskResult, 1);
  GMaskResult[0].Position := -81;
  SetLength(GMaskResult[0].AllowedTokens, 1);
  GMaskResult[0].AllowedTokens[0] := 'caller mask';
  GPreferenceResult := nil;
  SetLength(GPreferenceResult, 1);
  GPreferenceResult[0].Token := 'caller preference';
  GPreferenceResult[0].Multiplier := -91;
  GProviderResult := Default(TStyleProviderDescription);
  GProviderResult.Name := 'caller provider';
  SetLength(GProviderResult.Choices, 1);
  GProviderResult.Choices[0].Token := 'caller choice';
end;

procedure CheckInputs;
var
  LIndex: Integer;
begin
  Check(EncodeWfcSequenceText(GConfig.HarmonyModel) = GModelBytes[0], 'Harmony input changed');
  Check(EncodeWfcSequenceText(GConfig.RhythmModel) = GModelBytes[1], 'Rhythm input changed');
  for LIndex := 0 to 1 do
  begin
    Check(EncodeWfcSequenceText(GConfig.Voices[LIndex].Model) = GModelBytes[LIndex + 2],
      'Voice input changed');
  end;
  Check(EncodeWfcSequenceText(GReplacement) = GModelBytes[4], 'Replacement input changed');
end;

procedure RunOperation(const ASession: TNamedVoiceSession;
  const AProgress: TWorkProgressCallback);
var
  LReport: TGraphNegotiationReport;
  LSelective: TGraphSelectiveNegotiationReport;
  LReplacement: TLayerModelReplacementReport;
  LProof: TWfcMusicVoicesValidationReport;
begin
  case GOperation of
    opGenerate:
    begin
      Check(ASession.TryGenerate(GOutput, LReport, LProof, AProgress), 'Initial solve rejected');
      Check(LProof.Valid, 'Initial independent proof failed');
    end;
    opRegenerate:
    begin
      Check(ASession.TryRegenerate(['lead'], 1731, GOutput, LSelective, LProof, AProgress),
        'Selective solve rejected');
      Check(LProof.Valid, 'Selective independent proof failed');
    end;
    opReplace:
    begin
      Check(ASession.TryReplaceProvider('lead', GReplacement, GContract, 2731, GOutput,
        LReplacement, LProof, AProgress), 'Replacement solve rejected');
      Check(LProof.Valid, 'Replacement independent proof failed');
    end;
    opCopyAccepted: GOutput := ASession.CopyAccepted(AProgress);
    opSetMask: ASession.SetConstraints('lead', GProposedMask, AProgress);
    opSetPreferences: ASession.SetPreferences('lead', GProposedPreferences, AProgress);
    opCopyMask: GMaskResult := ASession.CopyConstraints('lead', AProgress);
    opCopyPreferences: GPreferenceResult := ASession.CopyPreferences('lead', AProgress);
    opProvider: GProviderResult := ASession.CopyProvider('lead', AProgress);
  end;
end;

function Prepare: TNamedVoiceSession;
var
  LOptions: TVoiceSessionOptions;
  LMask: TWfcSequenceTokenConstraints;
  LPreferences: TLayerTokenPreferences;
  LMusic: TWfcMusicVoicesGenerated;
  LReport: TGraphNegotiationReport;
  LProof: TWfcMusicVoicesValidationReport;
begin
  LOptions := DefaultVoiceSessionOptions;
  LOptions.CellCount := 33;
  if GOperation in [opSetMask, opCopyMask] then
  begin
    LOptions.CellCount := 257;
  end;
  LOptions.RequireObservedEnd := False;
  Result := TNamedVoiceSession.Create(GConfig, ['bass', 'lead'], LOptions);
  try
    SetLength(LPreferences, 1);
    LPreferences[0].Token := GConfig.Voices[1].Model.PublicTokenAt(0);
    LPreferences[0].Multiplier := 7;
    Result.SetPreferences('lead', LPreferences);
    if GOperation in [opRegenerate, opReplace, opCopyAccepted] then
    begin
      Check(Result.TryGenerate(LMusic, LReport, LProof), 'Preparation solve rejected');
    end;
    SetLength(LMask, 1);
    LMask[0].Position := 0;
    SetLength(LMask[0].AllowedTokens, 1);
    LMask[0].AllowedTokens[0] := GConfig.Voices[0].Model.PublicTokenAt(0);
    Result.SetConstraints('bass', LMask);
    LMask[0].AllowedTokens[0] := GConfig.Voices[1].Model.PublicTokenAt(16);
    Result.SetConstraints('lead', LMask);
    LPreferences[0].Multiplier := 3;
    Result.SetPreferences('lead', LPreferences);
    if GOperation = opCopyMask then
    begin
      Result.SetConstraints('lead', GProposedMask);
    end;
    if GOperation in [opCopyPreferences, opProvider] then
    begin
      Result.SetPreferences('lead', GProposedPreferences);
    end;
  except
    Result.Free;
    raise;
  end;
end;

procedure TObserver.Observe(const AWork: TWorkProgress);
var
  LPoint: TAbortPoint;
  LIndex: Integer;
  LFound: Boolean;
  LRelevant: Boolean;
  LRejected: Boolean;
begin
  Inc(Calls);
  Check((AWork.Done >= 0) and (AWork.Total >= 0) and
    ((AWork.Total = 0) or (AWork.Done <= AWork.Total)) and
    (AWork.Pass >= 0), 'Invalid progress count');
  Check(AWork.Units in [wuItems, wuBytes], 'Unexpected progress unit');
  if AWork.Stage = 'voice_capture_weight_visits' then
  begin
    CaptureStarted := True;
  end;
  if (AWork.Stage = 'voice_publication_ready') and (AWork.Done = 1) then
  begin
    Ready := True;
  end;
  if Reentry and not ReentryChecked then
  begin
    ReentryChecked := True;
    LRejected := False;
    try
      Session.SetPreferences('lead', nil);
    except
      on E: EAudio do LRejected := Pos('re-entered', E.Message) > 0;
    end;
    Check(LRejected, 'Observer could mutate its running session');
    LRejected := False;
    try
      Session.CopyAccepted;
    except
      on E: EAudio do LRejected := Pos('re-entered', E.Message) > 0;
    end;
    Check(LRejected, 'Observer could copy an intermediate accepted state');
    Check(Session.ProviderCount = 4, 'Bounded read failed during observation');
  end;
  LRelevant := (Copy(AWork.Stage, 1, 6) = 'voice_') and
    (Copy(AWork.Stage, 1, 14) <> 'voice_session_');
  LRelevant := LRelevant or (CaptureStarted and
    (Copy(AWork.Stage, 1, 4) = 'wfc_')) or
    (AWork.Stage = 'wfc_solve_commit_visits');
  if not LRelevant then
  begin
    Exit;
  end;
  LPoint.Stage := AWork.Stage;
  LPoint.AfterReady := Ready;
  LPoint.Point := 0;
  if AWork.Done > 0 then
  begin
    LPoint.Point := 1;
    if (AWork.Total > 0) and (AWork.Done = AWork.Total) then
    begin
      LPoint.Point := 2;
    end;
  end;
  if Discover then
  begin
    LFound := False;
    for LIndex := 0 to High(Points) do
    begin
      if (Points[LIndex].Stage = LPoint.Stage) and
        (Points[LIndex].Point = LPoint.Point) and
        (Points[LIndex].AfterReady = LPoint.AfterReady) then
      begin
        LFound := True;
      end;
    end;
    if not LFound then
    begin
      SetLength(Points, Length(Points) + 1);
      Points[High(Points)] := LPoint;
    end;
  end;
  if Enabled and (Target.Stage = LPoint.Stage) and
    (Target.Point = LPoint.Point) and (Target.AfterReady = LPoint.AfterReady) then
  begin
    Raised := True;
    raise Marker;
  end;
end;

procedure RequirePoint(const APoints: TAbortPoints; const AStage: String;
  const APoint: Integer; const AAfterReady: Boolean = False);
var
  LIndex: Integer;
  LFound: Boolean;
begin
  LFound := False;
  for LIndex := 0 to High(APoints) do
  begin
    if (APoints[LIndex].Stage = AStage) and
      ((APoint < 0) or (APoints[LIndex].Point = APoint)) and
      (APoints[LIndex].AfterReady = AAfterReady) then
    begin
      LFound := True;
    end;
  end;
  Check(LFound, 'Required checkpoint missing: ' + AStage);
end;

procedure Exercise(const AOperation: TOperation);
var
  LSession: TNamedVoiceSession;
  LExpectedState: String;
  LExpectedOutput: String;
  LBeforeState: String;
  LBeforeOutput: String;
  LPoints: TAbortPoints;
  LIndex: Integer;
  LCalls: Integer;
begin
  GOperation := AOperation;
  GObserver.Points := nil;
  GObserver.Discover := True;
  GObserver.Ready := False;
  GObserver.CaptureStarted := False;
  LSession := Prepare;
  try
    ResetOutputs;
    RunOperation(LSession, GObserver.Observe);
    LExpectedState := StateEvidence(LSession);
    LExpectedOutput := OutputEvidence;
    LPoints := Copy(GObserver.Points);
    Check(Length(LPoints) > 0, 'No real observable checkpoints');
    if AOperation in [opGenerate, opRegenerate, opReplace] then
    begin
      RequirePoint(LPoints, 'voice_publication_ready', 2, True);
      RequirePoint(LPoints, 'voice_copy_generated_visits', 1);
      RequirePoint(LPoints, 'voice_commit_visits', 2);
      RequirePoint(LPoints, 'voice_capture_weight_visits', 2);
    end;
    if AOperation in [opGenerate, opRegenerate] then
    begin
      RequirePoint(LPoints, 'wfc_solve_commit_visits', -1, True);
    end;
    case AOperation of
      opReplace: RequirePoint(LPoints, 'voice_replacement_ready', 2, True);
      opCopyAccepted: RequirePoint(LPoints, 'voice_copy_generated_visits', 1);
      opSetMask:
      begin
        RequirePoint(LPoints, 'voice_constraint_visits', 1);
        RequirePoint(LPoints, 'voice_constraints_ready', 2);
      end;
      opCopyMask: RequirePoint(LPoints, 'voice_mask_copy_visits', 1);
      opSetPreferences:
      begin
        RequirePoint(LPoints, 'voice_preference_visits', 1);
        RequirePoint(LPoints, 'voice_preferences_ready', 2);
      end;
      opProvider: RequirePoint(LPoints, 'voice_provider_ready', 2);
    end;

  finally
    LSession.Free;
    GObserver.Discover := False;
  end;
  for LIndex := 0 to High(LPoints) do
  begin
    LSession := Prepare;
    try
      ResetOutputs;
      LBeforeState := StateEvidence(LSession);
      LBeforeOutput := OutputEvidence;
      GObserver.Target := LPoints[LIndex];
      GObserver.Raised := False;
      GObserver.Ready := False;
      GObserver.CaptureStarted := False;
      GObserver.Enabled := True;
      GObserver.Reentry := True;
      GObserver.ReentryChecked := False;
      GObserver.Session := LSession;
      if (LIndex mod 2) = 0 then
      begin
        GObserver.Marker := EAudio.Create('original audio observer abort');
      end
      else
      begin
        GObserver.Marker := Exception.Create('original caller observer abort');
      end;
      try
        try
          RunOperation(LSession, GObserver.Observe);
        except
          on E: Exception do
          begin
            Check(E = GObserver.Marker, 'Observer exception identity changed: ' + E.Message);
            GObserver.Marker := nil;
          end;
        end;
      finally
        GObserver.Enabled := False;
        GObserver.Reentry := False;
        GObserver.Marker.Free;
        GObserver.Marker := nil;
      end;
      Check(GObserver.Raised, 'Real checkpoint was not reached: ' + LPoints[LIndex].Stage);
      Check(GObserver.ReentryChecked, 'Reentry checks did not execute');
      Inc(GAborts);
      Check(StateEvidence(LSession) = LBeforeState, 'Abort changed session at ' +
        LPoints[LIndex].Stage);
      Check(OutputEvidence = LBeforeOutput, 'Abort changed caller output at ' +
        LPoints[LIndex].Stage);
      CheckInputs;
      LCalls := GObserver.Calls;
      RunOperation(LSession, nil);
      Check(GObserver.Calls = LCalls, 'Observer retained after operation');
      Check(StateEvidence(LSession) = LExpectedState, 'Same-session retry changed state at ' +
        LPoints[LIndex].Stage);
      Check(OutputEvidence = LExpectedOutput, 'Same-session retry changed output at ' +
        LPoints[LIndex].Stage);
    finally
      LSession.Free;
      GObserver.Session := nil;
    end;
  end;
  WriteLn('voice operation ', Ord(AOperation), ': ', Length(LPoints), ' original abort/retries');
end;

procedure OwnedCopies;
var
  LSession: TNamedVoiceSession;
  LBefore: String;
  LCopy: TWfcMusicVoicesGenerated;
  LMask: TWfcSequenceTokenConstraints;
  LPreferences: TLayerTokenPreferences;
  LProvider: TStyleProviderDescription;
begin
  GOperation := opCopyAccepted;
  LSession := Prepare;
  try
    LBefore := StateEvidence(LSession);
    LCopy := LSession.CopyAccepted;
    LCopy.Layers[0].Tokens[0] := 'detached';
    LCopy.Layers[0].StateIndices[0] := -1;
    LCopy.Frames[0].Voices[0].Tones[0].Velocity := 0;
    LCopy.Coverage[0].Suppliers[0] := -1;
    LMask := LSession.CopyConstraints('lead');
    LMask[0].AllowedTokens[0] := 'detached';
    LPreferences := LSession.CopyPreferences('lead');
    LPreferences[0].Multiplier := 1;
    LProvider := LSession.CopyProvider('lead');
    LProvider.Choices[0].Voice.Tones[0].Velocity := 0;
    LProvider.Preferences[0].Multiplier := 1;
    Check(StateEvidence(LSession) = LBefore, 'Returned managed snapshots alias session state');
  finally
    LSession.Free;
  end;
end;

procedure Setup;
var
  LIndex: Integer;
  LSamples: TWfcSequenceSamples;
  LSession: TNamedVoiceSession;
begin
  GConfig := MakeConfig;
  GModelBytes[0] := EncodeWfcSequenceText(GConfig.HarmonyModel);
  GModelBytes[1] := EncodeWfcSequenceText(GConfig.RhythmModel);
  GModelBytes[2] := EncodeWfcSequenceText(GConfig.Voices[0].Model);
  GModelBytes[3] := EncodeWfcSequenceText(GConfig.Voices[1].Model);
  { A different empirical weight model with the same supported vocabulary. }
  SetLength(LSamples, 290);
  for LIndex := 0 to 288 do
  begin
    LSamples[LIndex] := MakeWfcSequenceSample([
      GConfig.Voices[1].Model.PublicTokenAt(LIndex div 17),
      GConfig.Voices[1].Model.PublicTokenAt(LIndex mod 17)]);
  end;
  LSamples[289] := MakeWfcSequenceSample([
    GConfig.Voices[1].Model.PublicTokenAt(0), GConfig.Voices[1].Model.PublicTokenAt(0)]);
  GReplacement := LearnSequenceModelCorpus(LSamples, 1);
  GModelBytes[4] := EncodeWfcSequenceText(GReplacement);
  Check(GModelBytes[4] <> GModelBytes[3], 'Replacement must differ from the source model');
  GOperation := opGenerate;
  LSession := Prepare;
  try
    GContract := LSession.CopyContract('lead');
  finally
    LSession.Free;
  end;
  SetLength(GProposedMask, 257);
  for LIndex := 0 to High(GProposedMask) do
  begin
    GProposedMask[LIndex].Position := LIndex;
    SetLength(GProposedMask[LIndex].AllowedTokens, 2);
    GProposedMask[LIndex].AllowedTokens[0] := GConfig.Voices[1].Model.PublicTokenAt(0);
    GProposedMask[LIndex].AllowedTokens[1] := GConfig.Voices[1].Model.PublicTokenAt(1);
  end;
  SetLength(GProposedPreferences, 17);
  for LIndex := 0 to High(GProposedPreferences) do
  begin
    GProposedPreferences[LIndex].Token := GConfig.Voices[1].Model.PublicTokenAt(LIndex);
    GProposedPreferences[LIndex].Multiplier := 4;
  end;
end;

var
  LOperation: TOperation;
begin
  GObserver := TObserver.Create;
  try
    Setup;
    for LOperation := Low(TOperation) to High(TOperation) do
    begin
      Exercise(LOperation);
    end;
    OwnedCopies;
    CheckInputs;
    WriteLn('named voice publication: ', GChecks, ' checks; ', GAborts,
      ' original abort/retries; ', GObserver.Calls, ' callbacks');
  finally
    GReplacement.Free;
    FreeConfig(GConfig);
    GObserver.Free;
  end;
end.
