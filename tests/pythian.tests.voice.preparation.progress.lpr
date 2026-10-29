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
program pythian_tests_voice_preparation_progress;

{$mode delphi}{$H+}

uses SysUtils, pythian.progress, pythian.wfc.progress, pythian.wfc.voices,
  wfc, wfc_model, wfc_sequence, wfc_sequence_learn, wfc_sequence_text,
  wfc_music, wfc_music_sequence, wfc_music_ensemble, wfc_music_ensemble_graph,
  wfc_music_voices_graph;

type
  TObserver = class
  public
    Stage: String;
    Point: Integer;
    Enabled: Boolean;
    Marker: Exception;
    Raised: Boolean;
    Calls: Integer;
    SawHarmony, SawRhythm, SawVoice, SawWitness: Boolean;
    procedure Observe(const AWork: TWorkProgress);
  end;

var
  Checks, Aborts: Integer;

procedure Check(const AValue: Boolean; const AMessage: String);
begin
  Inc(Checks);
  if not AValue then raise Exception.Create(AMessage);
end;

procedure TObserver.Observe(const AWork: TWorkProgress);
var
  LMatch: Boolean;
begin
  Inc(Calls);
  Check((AWork.Units = wuItems) and (AWork.Done >= 0) and
    (AWork.Total >= 0) and ((AWork.Total = 0) or
    (AWork.Done <= AWork.Total)) and (AWork.Pass >= 0), 'Invalid forwarded work');
  if AWork.Stage = 'wfc_ensemble_harmony_rows' then
  begin
    Check(AWork.Pass = 1, 'Harmony lost its actual model index');
    SawHarmony := True;
  end;
  if AWork.Stage = 'wfc_ensemble_rhythm_rows' then
  begin
    Check(AWork.Pass = 2, 'Rhythm lost its actual model index');
    SawRhythm := True;
  end;
  if AWork.Stage = 'wfc_ensemble_model_visits' then
  begin
    Check(AWork.Pass in [3, 4], 'Voice lost its actual model index');
    SawVoice := True;
  end;
  if (AWork.Stage = 'wfc_sequence_witness_projection_visits') and
    (AWork.Pass = 5) then SawWitness := True;
  if AWork.Stage = 'wfc_voice_build_visits' then
    Check(AWork.Pass = 0, 'Operation-wide work became a model pass');
  LMatch := ((Point = 0) and (AWork.Done = 0)) or
    ((Point = 1) and (AWork.Done > 0) and
      ((AWork.Total = 0) or (AWork.Done < AWork.Total))) or
    ((Point = 2) and (AWork.Total > 0) and (AWork.Done = AWork.Total));
  if Enabled and (AWork.Stage = Stage) and LMatch then
  begin
    Raised := True;
    raise Marker;
  end;
end;

procedure FreeConfig(var AConfig: TWfcMusicVoicesGraphConfig); forward;

function MakeConfig: TWfcMusicVoicesGraphConfig;
var
  LVoice, LChoice: Integer;
  LTokens: TWfcModelTokens;
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
      Result.Voices[LVoice].Model := LearnSequenceModel(LTokens, 1);
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
    AConfig.Voices[LVoice].Model.Free;
  AConfig.HarmonyModel.Free;
  AConfig.RhythmModel.Free;
  AConfig := Default(TWfcMusicVoicesGraphConfig);
end;

function Evidence(const AValue: TWfcMusicVoicesGenerated): String;
var
  LLayer, LCell: Integer;
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

procedure Exercise;
const
  Stages: array[0..12] of String = ('provider_voice_capacity_visits',
    'wfc_voice_config_visits', 'wfc_voice_config_copy_visits',
    'voice_session_clone_models', 'wfc_voice_build_visits',
    'wfc_model_construct_visits', 'wfc_sequence_projection_visits',
    'voice_session_snapshot_cells', 'provider_decode_choices', 'voice_session_ready',
    'wfc_sequence_model_build_visits', 'wfc_sequence_model_build_visits',
    'wfc_sequence_model_build_visits');
  Points: array[0..12] of Integer = (2, 2, 2, 1, 2, 1, 1, 1, 2, 2, 0, 1, 2);
var
  C: TWfcMusicVoicesGraphConfig;
  Options: TVoiceSessionOptions;
  Base, Candidate: TNamedVoiceSession;
  V: TWfcMusicVoicesGenerated;
  R: TGraphNegotiationReport;
  P: TWfcMusicVoicesValidationReport;
  O: TObserver;
  B: TWfcSolveProgressBridge;
  Expected, Original: String;
  I: Integer;
  ModelCopy: TWfcSequenceModel;
begin
  B := TWfcSolveProgressBridge.Create(nil);
  try
    Check(not Assigned(B.PreparationWorkObserver()), 'Nil receiver became an observer');
    Check(not Assigned(WfcPreparationWorkObserver(nil)), 'Nil bridge became an observer');
  finally
    B.Free;
  end;
  C := MakeConfig;
  Base := nil;
  Candidate := nil;
  O := TObserver.Create;
  try
    Original := EncodeWfcSequenceText(C.Voices[0].Model);
    Options := DefaultVoiceSessionOptions;
    Options.CellCount := 65;
    Options.RequireObservedEnd := False;
    Base := TNamedVoiceSession.Create(C, ['bass', 'lead'], Options);
    Check(Base.TryGenerate(V, R, P), 'Unobserved finite voice solve failed');
    Expected := Evidence(V);
    Candidate := TNamedVoiceSession.Create(C, ['bass', 'lead'], Options, nil, O.Observe);
    Check(O.SawHarmony and O.SawRhythm and O.SawVoice and O.SawWitness,
      'Nested actual pass scopes were not forwarded');
    Check(Candidate.TryGenerate(V, R, P), 'Observed finite voice solve failed');
    Check(Evidence(V) = Expected, 'Observed construction changed exact musical replay');
    FreeAndNil(Candidate);
    for I := 0 to High(Stages) do
    begin
      O.Stage := Stages[I];
      O.Point := Points[I];
      O.Marker := Exception.Create('original voice preparation abort');
      O.Enabled := True;
      O.Raised := False;
      Candidate := Base;
      try
        try
          Candidate := TNamedVoiceSession.Create(C, ['bass', 'lead'], Options, nil, O.Observe);
        except
          on E: Exception do Check(E = O.Marker, 'Construction replaced original observer exception');
        end;
        Check(O.Raised, 'Required construction cancellation was not reached: ' + O.Stage);
        Check(Candidate = Base, 'Failed constructor replaced caller session');
        Inc(Aborts);
      finally
        O.Enabled := False;
        O.Marker := nil;
        if Candidate <> Base then Candidate.Free;
        Candidate := nil;
      end;
      Check(EncodeWfcSequenceText(C.Voices[0].Model) = Original, 'Aborted constructor changed caller model');
      Candidate := TNamedVoiceSession.Create(C, ['bass', 'lead'], Options, nil, O.Observe);
      try
        Check(Candidate.TryGenerate(V, R, P), 'Retry with the same caller inputs failed');
        Check(Evidence(V) = Expected, 'Retry changed exact voices or coverage');
      finally
        FreeAndNil(Candidate);
      end;
      Check(Evidence(Base.CopyAccepted) = Expected, 'Cancellation changed prior accepted owner');
    end;
    { Big Boss: the public copy entry point must preserve its caller result and
      the accepted session at start, real interior work and final publication. }
    for I := 0 to 2 do
    begin
      O.Stage := 'wfc_sequence_model_build_visits';
      O.Point := I;
      O.Marker := Exception.Create('original named model copy abort');
      O.Enabled := True;
      O.Raised := False;
      ModelCopy := C.Voices[0].Model;
      try
        try
          ModelCopy := Base.CopyModel('bass', O.Observe);
        except
          on E: Exception do Check(E = O.Marker, 'CopyModel replaced original exception');
        end;
        Check(O.Raised, 'CopyModel cancellation checkpoint was not reached');
        Check(ModelCopy = C.Voices[0].Model, 'Failed CopyModel replaced caller result');
        Inc(Aborts);
      finally
        O.Enabled := False;
        O.Marker := nil;
        if ModelCopy <> C.Voices[0].Model then ModelCopy.Free;
      end;
      Check(EncodeWfcSequenceText(C.Voices[0].Model) = Original,
        'CopyModel abort changed original model');
      ModelCopy := Base.CopyModel('bass', O.Observe);
      try
        Check(EncodeWfcSequenceText(ModelCopy) = Original, 'CopyModel retry changed model');
      finally
        ModelCopy.Free;
      end;
      Check(Evidence(Base.CopyAccepted) = Expected, 'CopyModel changed accepted session');
    end;
    WriteLn('Voice preparation consumer: ', Checks, ' checks; ', Aborts,
      ' original abort/retries; ', O.Calls, ' actual callbacks');
  finally
    Candidate.Free;
    Base.Free;
    O.Free;
    FreeConfig(C);
  end;
end;

begin
  Exercise;
end.
