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
program pythian_tests_accepted_snapshot;
{$mode delphi}{$H+}
uses SysUtils, pythian.audio, pythian.progress, pythian.wfc.layers,
  pythian.wfc.voices, pythian.wfc.instrumental.starter,
  wfc, wfc_model, wfc_sequence, wfc_sequence_learn, wfc_sequence_graph, wfc_music_sequence,
  wfc_music_ensemble, wfc_music_voices_graph;

type
  TObserver = class
    RejectStage: String;
    Calls: Integer;
    Voice: TNamedVoiceSession;
    Layer: TLearnedLayerSession;
    TryReentry: Boolean;
    ReentryRejected: Boolean;
    procedure Observe(const AWork: TWorkProgress);
  end;

var Checks: Integer;

procedure Check(const OK: Boolean; const Why: String);
begin
  Inc(Checks);
  if not OK then raise EAudio.Create(Why);
end;

procedure TObserver.Observe(const AWork: TWorkProgress);
var V: TVoiceAcceptedSnapshot; L: TLayerAcceptedSnapshot;
begin
  Inc(Calls);
  Check((Pos('search', AWork.Stage) = 0) and (Pos('learning', AWork.Stage) = 0),
    'Snapshot work does not invoke search or learning');
  if TryReentry then
  begin
    TryReentry := False;
    try
      if Voice <> nil then V := Voice.CopyAcceptedSnapshot
      else L := Layer.CopyAcceptedSnapshot;
    except on EAudio do ReentryRejected := True end;
  end;
  if AWork.Stage = RejectStage then raise EAbort.Create('Expected snapshot abort');
end;

procedure SameSequence(const A, B: TWfcGeneratedSequenceSegment; const Why: String);
var I: Integer;
begin
  Check(Length(A.Tokens) = Length(B.Tokens), Why + ': extent');
  for I := 0 to High(A.Tokens) do
    Check((A.Tokens[I] = B.Tokens[I]) and (A.StateIndices[I] = B.StateIndices[I]),
      Why + ': actual token/state');
end;

procedure Voices;
var
  Starter: TInstrumentalStarter;
  Source, Restored, Previous: TNamedVoiceSession;
  Options: TVoiceSessionOptions;
  Masks: TVoiceMasks;
  Snapshot, Bad, Roundtrip: TVoiceAcceptedSnapshot;
  A, B, Before: TWfcMusicVoicesGenerated;
  Report: TGraphNegotiationReport;
  Selective: TGraphSelectiveNegotiationReport;
  Proof: TWfcMusicVoicesValidationReport;
  Model: TWfcSequenceModel;
  Frame: TWfcMusicEnsembleFrame;
  NewToken: String;
  OldPitch, TargetPitch, I, J, K: Integer;
  Rejected: Boolean;
  Observer: TObserver;
begin
  Starter := TInstrumentalStarter.Create(0);
  Source := nil;
  Restored := nil;
  Model := nil;
  Observer := TObserver.Create;
  try
    Options := DefaultVoiceSessionOptions;
    Options.CellCount := 8;
    Options.Seed := 731;
    Options.RequireObservedEnd := False;
    Source := TNamedVoiceSession.Create(Starter.Config, ['bass', 'harmony-voice', 'lead'], Options);
    Masks := Starter.GuideMasks(8);
    for I := 0 to 4 do Source.SetConstraints(Source.ProviderName(I), Masks[I]);
    Source.SetPreferences('lead', [MakeLayerTokenPreference(
      Starter.Config.Voices[2].Model.PublicTokenAt(0), 2)]);
    Check(Source.TryGenerate(A, Report, Proof), 'Actual named baseline');
    Before := A;
    Observer.Voice := Source;
    Observer.TryReentry := True;
    Snapshot := Source.CopyAcceptedSnapshot(Observer.Observe);
    Check(Observer.ReentryRejected, 'Named snapshot source rejects reentry');
    Check((Snapshot.Config.HarmonyModel = nil) and (Snapshot.Config.Voices[0].Model = nil),
      'Named snapshot contains model text rather than borrowed model pointers');
    Observer.Voice := nil;
    Restored := TNamedVoiceSession.FromAcceptedSnapshot(Snapshot, Observer.Observe);
    Check(Snapshot.Config.HarmonyModel = nil, 'Restoration does not populate borrowed snapshot model fields');
    B := Restored.CopyAccepted;
    for I := 0 to High(A.Layers) do SameSequence(A.Layers[I], B.Layers[I], 'Named restoration');
    Roundtrip := Restored.CopyAcceptedSnapshot;
    for I := 0 to High(Snapshot.Models) do
    begin
      Check(Roundtrip.Models[I] = Snapshot.Models[I], 'Actual named model text survives restoration');
      Check(Length(Roundtrip.Constraints[I]) = Length(Snapshot.Constraints[I]),
        'Committed named mask count survives restoration');
      for J := 0 to High(Snapshot.Constraints[I]) do
      begin
        Check((Roundtrip.Constraints[I][J].Position = Snapshot.Constraints[I][J].Position) and
          (Length(Roundtrip.Constraints[I][J].AllowedTokens) =
            Length(Snapshot.Constraints[I][J].AllowedTokens)), 'Committed named mask extent');
        for K := 0 to High(Snapshot.Constraints[I][J].AllowedTokens) do
          Check(Roundtrip.Constraints[I][J].AllowedTokens[K] =
            Snapshot.Constraints[I][J].AllowedTokens[K], 'Committed named token domain');
      end;
    end;
    Check((Length(Roundtrip.Preferences[4]) = 1) and
      (Roundtrip.Preferences[4][0].Token = Snapshot.Preferences[4][0].Token) and
      (Roundtrip.Preferences[4][0].Multiplier = 2), 'Committed named soft preference restored');
    OldPitch := DecodeWfcMusicEnsembleFrame(B.Layers[4].Tokens[0]).Voices[0].Tones[0].Pitch;
    TargetPitch := 72;
    if OldPitch = TargetPitch then TargetPitch := 76;
    Model := Restored.CopyModel('lead');
    NewToken := '';
    for I := 0 to Model.PublicTokenCount - 1 do
    begin
      Frame := DecodeWfcMusicEnsembleFrame(Model.PublicTokenAt(I));
      if (Frame.Voices[0].Action = wmcaAttack) and
        (Frame.Voices[0].Tones[0].Pitch = TargetPitch) then
      begin NewToken := Model.PublicTokenAt(I); Break end;
    end;
    Check(NewToken <> '', 'Existing alternative Lead choice');
    Restored.SetConstraints('lead', [MakeWfcSequenceTokenConstraint(0, [NewToken])]);
    Check(Restored.TryRegenerate(['lead'], 731, B, Selective, Proof),
      'Restored named session uses ordinary authorized regeneration');
    Check(B.Layers[4].Tokens[0] = NewToken, 'Requested new Lead reaches the actual graph');
    for I := 0 to 3 do SameSequence(A.Layers[I], B.Layers[I], 'Unrelated named provider retained');
    A := Source.CopyAccepted;
    for I := 0 to High(A.Layers) do SameSequence(Before.Layers[I], A.Layers[I], 'Source remains exact');
    for I := 0 to 1 do
    begin
      Previous := Restored;
      if I = 0 then Observer.RejectStage := 'voice_snapshot_decode'
      else Observer.RejectStage := 'voice_snapshot_restored';
      Rejected := False;
      try Restored := TNamedVoiceSession.FromAcceptedSnapshot(Snapshot, Observer.Observe);
      except on EAbort do Rejected := True end;
      Check(Rejected and (Restored = Previous), 'Named restore cancellation preserves caller result');
    end;
    Observer.RejectStage := '';
    Bad := Source.CopyAcceptedSnapshot;
    Bad.Assignments.Passes[0].Cells[0].Value := 'not-a-state';
    Rejected := False;
    try Previous := TNamedVoiceSession.FromAcceptedSnapshot(Bad);
    except on Exception do Rejected := True end;
    Check(Rejected, 'Malformed named assignments reject without a solve');
    Source.SetConstraints('lead', [MakeWfcSequenceTokenConstraint(0, [NewToken])]);
    Rejected := False;
    try Bad := Source.CopyAcceptedSnapshot;
    except on EAudio do Rejected := True end;
    Check(Rejected and Source.HasPending('lead'), 'Named snapshot does not silently drop pending edits');
    Check(Observer.Calls > 0, 'Named restore exposes actual work');
  finally
    Observer.Free;
    Model.Free;
    Restored.Free;
    Source.Free;
    Starter.Free;
  end;
end;

procedure Layers;
var
  Samples: TWfcSequenceSamples;
  Definitions: TLearnedLayers;
  Projections: TLayerProjections;
  Options: TLayerGenerationOptions;
  Source, Restored, Previous: TLearnedLayerSession;
  Snapshot, Bad, Roundtrip: TLayerAcceptedSnapshot;
  A, B, Before: TLayerSequences;
  Report: TGraphNegotiationReport;
  Selective: TGraphSelectiveNegotiationReport;
  Observer: TObserver;
  NewToken: String;
  I, J: Integer;
  Rejected: Boolean;
begin
  Source := nil;
  Restored := nil;
  Observer := TObserver.Create;
  SetLength(Definitions, 3);
  SetLength(Samples, 2);
  for I := 0 to 1 do
  begin
    SetLength(Samples[I].Tokens, 4);
    for J := 0 to 3 do
      if ((I + J) mod 2) = 0 then Samples[I].Tokens[J] := 'a'
      else Samples[I].Tokens[J] := 'b';
  end;
  try
    for I := 0 to 2 do Definitions[I].Model := LearnSequenceModelCorpus(Samples, 1);
    Definitions[0].Preferences := [MakeLayerTokenPreference('a', 3)];
    Definitions[0].Constraints := [MakeWfcSequenceTokenConstraint(0, ['a', 'b'])];
    SetLength(Projections, 1);
    Projections[0].Provider := 0;
    Projections[0].Consumer := 1;
    SetLength(Projections[0].Rules, 2);
    Projections[0].Rules[0] := MakeWfcSequenceProjectionRule('a', ['a']);
    Projections[0].Rules[1] := MakeWfcSequenceProjectionRule('b', ['b']);
    Options := DefaultLayerGenerationOptions;
    Options.CellCount := 4;
    Options.Seed := 731;
    Options.Extent := wsePrefix;
    SetLength(Options.TimeGrids, 3);
    for I := 0 to 2 do Options.TimeGrids[I] := MakeLayerTimePartition([0, 120, 300, 390, 480]);
    Source := TLearnedLayerSession.Create(Definitions, Projections, ['provider', 'dependent', 'other'], Options);
    Check(Source.TryGenerate(A, Report), 'Actual projected layer baseline');
    Before := A;
    Observer.Layer := Source;
    Observer.TryReentry := True;
    Snapshot := Source.CopyAcceptedSnapshot(Observer.Observe);
    Check(Observer.ReentryRejected, 'Layer snapshot source rejects reentry');
    Observer.Layer := nil;
    Restored := TLearnedLayerSession.FromAcceptedSnapshot(Snapshot, Observer.Observe);
    Check(Snapshot.Layers[0].Model = nil, 'Layer model pointers remain detached');
    Roundtrip := Restored.CopyAcceptedSnapshot;
    for I := 0 to 2 do
      Check(Roundtrip.Models[I] = Snapshot.Models[I], 'Actual layer model text survives restoration');
    Check((Length(Roundtrip.Layers[0].Constraints) = 1) and
      (Roundtrip.Layers[0].Constraints[0].Position = 0) and
      (Roundtrip.Layers[0].Constraints[0].AllowedTokens[0] = 'a') and
      (Roundtrip.Layers[0].Constraints[0].AllowedTokens[1] = 'b'), 'Actual layer mask restored');
    Check((Length(Roundtrip.Layers[0].Preferences) = 1) and
      (Roundtrip.Layers[0].Preferences[0].Token = 'a') and
      (Roundtrip.Layers[0].Preferences[0].Multiplier = 3), 'Actual layer soft preference restored');
    B := Restored.CopyAccepted;
    for I := 0 to 2 do
      for J := 0 to 3 do
        Check((A[I].Tokens[J] = B[I].Tokens[J]) and (A[I].StateIndices[J] = B[I].StateIndices[J]),
          'Projected actual token/state restored');
    Snapshot.Options.TimeGrids[0].Boundaries[1] := 111;
    Snapshot.Projections[0].Rules[0].SourceTokens[0] := 'changed';
    Bad := Source.CopyAcceptedSnapshot;
    Check((Bad.Options.TimeGrids[0].Boundaries[1] = 120) and
      (Bad.Projections[0].Rules[0].SourceTokens[0] = 'a'), 'Nested source metadata is detached');
    if B[0].Tokens[0] = 'a' then NewToken := 'b' else NewToken := 'a';
    Restored.SetConstraints('provider', [MakeWfcSequenceTokenConstraint(0, [NewToken])]);
    Check(Restored.TryRegenerate(['provider'], 731, B, Selective), 'Restored layer dependency closure regenerates');
    Check((B[0].Tokens[0] = NewToken) and (B[1].Tokens[0] = NewToken),
      'Actual provider change reaches its projected dependent');
    for J := 0 to 3 do
      Check((B[2].Tokens[J] = A[2].Tokens[J]) and (B[2].StateIndices[J] = A[2].StateIndices[J]),
        'Unrelated layer stays exact');
    A := Source.CopyAccepted;
    for I := 0 to 2 do
      for J := 0 to 3 do
        Check((Before[I].Tokens[J] = A[I].Tokens[J]) and (Before[I].StateIndices[J] = A[I].StateIndices[J]),
          'Restored operations do not mutate source state');
    { Every substituted value is a real model state in a valid temporal path,
      but this consumer belongs to the opposite provider result. Generic value
      validation alone cannot establish this musical projection contract. }
    Roundtrip := Restored.CopyAcceptedSnapshot;
    Bad := Source.CopyAcceptedSnapshot;
    Bad.Assignments.Passes[1].Cells := Copy(Roundtrip.Assignments.Passes[1].Cells);
    Rejected := False;
    try Previous := TLearnedLayerSession.FromAcceptedSnapshot(Bad);
    except on EAudio do Rejected := True end;
    Check(Rejected, 'Known valid states with an incompatible projection fail independent capture');
    Bad := Source.CopyAcceptedSnapshot;
    for I := 0 to 1 do
    begin
      Previous := Restored;
      if I = 0 then Observer.RejectStage := 'layer_snapshot_models'
      else Observer.RejectStage := 'layer_snapshot_restored';
      Rejected := False;
      try Restored := TLearnedLayerSession.FromAcceptedSnapshot(Bad, Observer.Observe);
      except on EAbort do Rejected := True end;
      Check(Rejected and (Previous = Restored), 'Layer cancellation preserves caller result');
    end;
    Observer.RejectStage := '';
    Bad.Assignments.Passes[0].Cells[0].Value := 'not-a-state';
    Rejected := False;
    try Previous := TLearnedLayerSession.FromAcceptedSnapshot(Bad);
    except on Exception do Rejected := True end;
    Check(Rejected, 'Malformed layer assignments reject without solving');
    Source.SetConstraints('provider', [MakeWfcSequenceTokenConstraint(0, [NewToken])]);
    Rejected := False;
    try Bad := Source.CopyAcceptedSnapshot;
    except on EAudio do Rejected := True end;
    Check(Rejected, 'Layer snapshot refuses pending edits rather than dropping them');
  finally
    Observer.Free;
    Restored.Free;
    Source.Free;
    for I := 0 to High(Definitions) do Definitions[I].Model.Free;
  end;
end;

begin
  try
    Voices;
    Layers;
    WriteLn('PASS accepted session snapshots: ', Checks, ' checks');
  except
    on E: Exception do
    begin
      WriteLn(E.ClassName, ': ', E.Message);
      {$IFDEF PAS2JS}raise;{$ELSE}ExitCode := 1;{$ENDIF}
    end;
  end;
end.
