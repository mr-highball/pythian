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
program pythian_tests_cell_preferences;
{$mode delphi}
{$H+}
uses
  SysUtils, pythian.audio, pythian.progress, pythian.wfc.layers,
  pythian.wfc.generation, pythian.wfc.stream,
  pythian.wfc.voices, pythian.wfc.instrumental.starter,
  wfc, wfc_model, wfc_sequence, wfc_sequence_learn, wfc_sequence_graph, wfc_sequence_text,
  wfc_music_voices_graph;
type
  TProbe = class
    Rows: TLayerPositionPreferences;
    Mutate: Boolean;
    Cancel: Boolean;
    procedure Observe(const AWork: TWorkProgress);
  end;
var
  Checks: Integer;
procedure Check(const ACondition: Boolean; const AMessage: String);
begin
  Inc(Checks);
  if not ACondition then raise Exception.Create(AMessage);
end;
procedure TProbe.Observe(const AWork: TWorkProgress);
begin
  if AWork.Stage <> 'sequence_position_weights_applied' then Exit;
  if Mutate then
  begin
    Rows[0].Position := 999;
    Rows[1].Preferences[0].Token := 'hostile caller edit';
    Rows[1].Preferences[0].Multiplier := 0;
    Mutate := False;
  end;
  if Cancel then raise EAbort.Create('Expected interior preference cancellation');
end;
function RhythmModel: TWfcSequenceModel;
var
  Samples: TWfcSequenceSamples;
begin
  SetLength(Samples, 4);
  Samples[0] := MakeWfcSequenceSample(['rest', 'rest']);
  Samples[1] := MakeWfcSequenceSample(['rest', 'hit']);
  Samples[2] := MakeWfcSequenceSample(['hit', 'rest']);
  Samples[3] := MakeWfcSequenceSample(['hit', 'hit']);
  Result := LearnSequenceModelCorpus(Samples, 1);
end;
function Rows(const ACount: Integer): TLayerPositionPreferences;
var
  I: Integer;
begin
  Result := nil;
  SetLength(Result, ACount);
  for I := 0 to ACount - 1 do
    if I < ACount div 2 then
      Result[I] := MakeLayerPositionPreference(I, [MakeLayerTokenPreference('rest', 1024)])
    else
      Result[I] := MakeLayerPositionPreference(I, [MakeLayerTokenPreference('hit', 1024)]);
end;
procedure ScopeBoundaries(const M: TWfcSequenceModel);
var
  G: TGraph;
  S: TSequencePositionPreferenceScope;
  P: TProbe;
  W: TGraphValueWeights;
  WComposed: TGraphValueWeights;
  V: TGraphValues;
  Mask: TWfcSequenceTokenConstraints;
  Rejected: Boolean;
  Inputs: TLayerPositionPreferences;
  OldInputs: TLayerPositionPreferences;
  RestValue: String;
  BaseWeight, I: Integer;
  Found: Boolean;
begin
  G := TGraph.Create.Reshape(4, 1, 1);
  P := TProbe.Create;
  S := nil;
  try
    G.WrapNeighbors := False;
    ApplySequenceModelToGraph(M, G, wseWhole);
    V := G.CopyRegisteredValues;
    G.SetCellValueWeights(0, 0, 0, [MakeGraphValueWeight(V[0], 3)]);
    G.SetAllowedValues(0, 0, 0, V);
    W := G.CopyCellValueWeights(0, 0, 0);
    Inputs := Rows(4);
    OldInputs := Inputs;
    Inputs := CopyLayerPositionPreferences(Inputs);
    Inputs[0].Preferences[0].Multiplier := 0;
    Check(OldInputs[0].Preferences[0].Multiplier = 1024,
      'Self-assigned copies detach nested preferences from an earlier caller view');
    Inputs := Rows(4);
    P.Rows := Inputs;
    P.Mutate := True;
    S := TSequencePositionPreferenceScope.Create(M, G, Inputs, nil, P.Observe);
    Check((Inputs[0].Position = 999) and (Inputs[1].Preferences[0].Multiplier = 0),
      'Fixture actually mutates caller-owned nested input after copying');
    Check(G.HasCellValueWeights(1, 0, 0) and G.HasCellValueWeights(3, 0, 0),
      'Private preparation survives caller array and nested-record mutation');
    FreeAndNil(S);
    Check((Length(G.CopyCellValueWeights(0, 0, 0)) = Length(W)) and
      (G.CopyCellValueWeights(0, 0, 0)[0].Weight = W[0].Weight) and
      not G.HasCellValueWeights(1, 0, 0), 'Disposal restores original cell priors exactly');
    Check(Length(G.CopyAllowedValues(0, 0, 0)) = Length(V),
      'Public token-domain extraction preserves the caller domain');
    SetLength(Mask, 1);
    Mask[0] := MakeWfcSequenceTokenConstraint(0, ['rest']);
    G.ClearAllowedValues(0, 0, 0);
    IntersectSequenceTokenConstraints(M, G, Mask);
    RestValue := G.CopyAllowedValues(0, 0, 0)[0];
    G.SetAllowedValues(0, 0, 0, V);
    Inputs := [MakeLayerPositionPreference(0, [MakeLayerTokenPreference('rest', 3)])];
    S := TSequencePositionPreferenceScope.Create(M, G, Inputs,
      [MakeLayerTokenPreference('rest', 2)]);
    BaseWeight := G.Rules[RestValue].Weight;
    if RestValue = W[0].Value then BaseWeight := W[0].Weight;
    WComposed := G.CopyCellValueWeights(0, 0, 0);
    Found := False;
    for I := 0 to High(WComposed) do
      if WComposed[I].Value = RestValue then
        Found := WComposed[I].Weight = BaseWeight * 6;
    Check(Found, 'Local and global token multipliers compose with an existing absolute cell prior');
    FreeAndNil(S);
    Inputs := Rows(4);
    P.Cancel := True;
    Rejected := False;
    try S := TSequencePositionPreferenceScope.Create(M, G, Inputs, nil, P.Observe);
    except on E: EAbort do Rejected := True end;
    Check(Rejected and (S = nil) and not G.HasCellValueWeights(1, 0, 0) and
      (G.CopyCellValueWeights(0, 0, 0)[0].Weight = W[0].Weight),
      'Interior cancellation restores already-applied rows without partial publication');
    Check(Length(G.CopyAllowedValues(0, 0, 0)) = Length(V), 'Cancelled extraction preserves domains');
    Inputs := Rows(4);
    Inputs[1].Position := Inputs[0].Position;
    Rejected := False;
    try S := TSequencePositionPreferenceScope.Create(M, G, Inputs);
    except on E: EAudio do Rejected := True end;
    Check(Rejected and not G.HasCellValueWeights(1, 0, 0), 'Duplicate positions reject before changes');
    Inputs := Rows(4);
    ApplySequencePositionPreferences(M, G, Inputs);
    Check(G.HasCellValueWeights(1, 0, 0) and G.HasCellValueWeights(3, 0, 0),
      'Private planning hook retains graph-owned rows after the adapter returns');
    Inputs[1].Preferences[0].Multiplier := 0;
    Check(G.CopyCellValueWeights(1, 0, 0)[0].Weight > 0,
      'Installed planning inputs do not retain caller array ownership');
  finally
    S.Free;
    P.Free;
    G.Free;
  end;
end;
procedure SegmentAndStream(const M: TWfcSequenceModel);
var
  O: TSequenceSegmentOptions;
  C: TSequenceChunkOptions;
  A, B, Baseline: TWfcGeneratedSequenceSegment;
  R: TGraphSolveReport;
  Stream: TLearnedSequenceStream;
  P: TProbe;
  Constraints: TWfcSequenceTokenConstraints;
  Text: String;
  I, Quiet, Busy: Integer;
  Rejected: Boolean;
begin
  Text := EncodeWfcSequenceText(M);
  O := DefaultSequenceSegmentOptions;
  O.CellCount := 64;
  O.Seed := 42;
  Check(TryGenerateSequenceSegment(M, O, MakeWfcSequenceInitialSegmentBoundary(False, 2),
    nil, Baseline, R), 'Actual future-supported default segment solves');
  O.PositionPreferences := Rows(64);
  Check(TryGenerateSequenceSegment(M, O, MakeWfcSequenceInitialSegmentBoundary(False, 2),
    nil, A, R), 'One real bounded sequence supports opposing position preferences');
  Quiet := 0;
  Busy := 0;
  for I := 0 to 63 do
  begin
    if (I < 32) and (A.Tokens[I] = 'rest') then Inc(Quiet);
    if (I >= 32) and (A.Tokens[I] = 'hit') then Inc(Busy);
  end;
  WriteLn('Positioned rhythm choices: quiet=', Quiet, '/32; busy=', Busy, '/32');
  Check((Quiet >= 28) and (Busy >= 28), 'Actual public-token choices follow different local soft priors');
  Check(TryGenerateSequenceSegment(M, O, MakeWfcSequenceInitialSegmentBoundary(False, 2),
    nil, B, R), 'Positioned sequence replays');
  for I := 0 to 63 do
    Check((A.Tokens[I] = B.Tokens[I]) and (A.StateIndices[I] = B.StateIndices[I]),
      'Native/pas2js seeded tokens and authenticated latent states replay');
  SetLength(Constraints, 2);
  Constraints[0] := MakeWfcSequenceTokenConstraint(0, ['hit']);
  Constraints[1] := MakeWfcSequenceTokenConstraint(63, ['rest']);
  Check(TryGenerateSequenceSegment(M, O, MakeWfcSequenceInitialSegmentBoundary(False, 2),
    Constraints, B, R) and (B.Tokens[0] = 'hit') and (B.Tokens[63] = 'rest'),
    'Actual hard future constraints prevail over the opposite local prior');
  O.PositionPreferences := nil;
  Check(TryGenerateSequenceSegment(M, O, MakeWfcSequenceInitialSegmentBoundary(False, 2),
    nil, B, R), 'Removing local priors returns to default solve');
  for I := 0 to 63 do
    Check(B.StateIndices[I] = Baseline.StateIndices[I], 'Default authenticated decisions remain exact');
  Check(EncodeWfcSequenceText(M) = Text, 'Preference execution leaves immutable source frequencies exact');
  O.PositionPreferences := Rows(64);
  for I := 0 to 63 do O.PositionPreferences[I].Preferences[0].Multiplier := 1;
  Check(TryGenerateSequenceSegment(M, O, MakeWfcSequenceInitialSegmentBoundary(False, 2),
    nil, B, R), 'Explicit neutral positioned preferences solve');
  for I := 0 to 63 do
    Check(B.StateIndices[I] = Baseline.StateIndices[I], 'Neutral positioned decisions preserve the exact default');
  Stream := TLearnedSequenceStream.Create(M);
  P := TProbe.Create;
  try
    C := DefaultSequenceChunkOptions;
    C.CellCount := 64;
    C.Seed := 42;
    C.MinimumFollowingCells := 2;
    C.PositionPreferences := Rows(64);
    P.Cancel := True;
    Rejected := False;
    B := A;
    try Stream.TryNext(C, nil, B, R, P.Observe);
    except on E: EAbort do Rejected := True end;
    Check(Rejected and (Stream.CellCount = 0) and (B.StateIndices[0] = A.StateIndices[0]),
      'Stream cancellation preserves cursor and previous caller music');
    Check(Stream.TryNext(C, nil, B, R), 'Cancelled stream can retry the same preferences');
    for I := 0 to 63 do
      Check(B.StateIndices[I] = A.StateIndices[I], 'Stream shares the primary finite positioned implementation');
    Check(Stream.TryNext(C, nil, B, R) and (Stream.CellCount = 128),
      'Continuing frontier accepts another bounded positioned chunk');
  finally
    P.Free;
    Stream.Free;
  end;
end;
procedure HigherOrderFrontier;
var
  Samples: TWfcSequenceSamples;
  M: TWfcSequenceModel;
  Stream: TLearnedSequenceStream;
  O: TSequenceChunkOptions;
  A: TWfcGeneratedSequenceSegment;
  R: TGraphSolveReport;
  Masks: TWfcSequenceTokenConstraints;
begin
  Samples := [MakeWfcSequenceSample(['a', 'x', 'c', 'end']),
    MakeWfcSequenceSample(['b', 'x', 'd', 'end'])];
  M := LearnSequenceModelCorpus(Samples, 3);
  Stream := TLearnedSequenceStream.Create(M);
  try
    O := DefaultSequenceChunkOptions;
    O.CellCount := 2;
    Masks := [MakeWfcSequenceTokenConstraint(0, ['a'])];
    Check(Stream.TryNext(O, Masks, A, R), 'Higher-order initial frontier accepts');
    O.RequireObservedEnd := True;
    O.PositionPreferences := [MakeLayerPositionPreference(0, [MakeLayerTokenPreference('d', 1024)])];
    Masks := [MakeWfcSequenceTokenConstraint(0, ['d'])];
    Check(not Stream.TryNext(O, Masks, A, R) and (Stream.CellCount = 2),
      'Wrong higher-order continuation cannot be rescued by a strong matching preference');
    Check(Stream.TryNext(O, nil, A, R) and (A.Tokens[0] = 'c') and
      (A.Tokens[1] = 'end') and Stream.Completed,
      'Exact higher-order frontier prevails over a different preferred public token');
  finally
    Stream.Free;
    M.Free;
  end;
end;
procedure SparsePositionVocabulary;
var
  Tokens: TWfcModelTokens;
  Samples: TWfcSequenceSamples;
  M: TWfcSequenceModel;
  O: TSequenceSegmentOptions;
  A: TWfcGeneratedSequenceSegment;
  R: TGraphSolveReport;
  I: Integer;
begin
  SetLength(Tokens, 256);
  for I := 0 to High(Tokens) do Tokens[I] := 'choice-' + IntToStr(I);
  Samples := [MakeWfcSequenceSample(Tokens), MakeWfcSequenceSample(Tokens)];
  M := LearnSequenceModelCorpus(Samples, 1);
  try
    O := DefaultSequenceSegmentOptions;
    O.CellCount := 1;
    O.PositionPreferences := [MakeLayerPositionPreference(0,
      [MakeLayerTokenPreference(Tokens[0], 2)])];
    Check(TryGenerateSequenceSegment(M, O, MakeWfcSequenceInitialSegmentBoundary(False),
      nil, A, R) and (A.Tokens[0] = Tokens[0]),
      'A sparse positioned preference must not resolve the unrelated 255-token vocabulary');
  finally
    M.Free;
  end;
end;
procedure SameVoices(const A, B: TWfcMusicVoicesGenerated; const AMessage: String);
var
  I, J: Integer;
begin
  Check(Length(A.Layers) = Length(B.Layers), AMessage + ': provider count');
  for I := 0 to High(A.Layers) do
  begin
    Check(Length(A.Layers[I].Tokens) = Length(B.Layers[I].Tokens), AMessage + ': cells');
    for J := 0 to High(A.Layers[I].Tokens) do
      Check((A.Layers[I].Tokens[J] = B.Layers[I].Tokens[J]) and
        (A.Layers[I].StateIndices[J] = B.Layers[I].StateIndices[J]), AMessage);
  end;
end;
procedure NamedSessions;
var
  Starter: TInstrumentalStarter;
  Source, Restored, Bad: TNamedVoiceSession;
  O: TVoiceSessionOptions;
  Masks: TVoiceMasks;
  Positions, CopyPositions: TLayerPositionPreferences;
  Snapshot: TVoiceAcceptedSnapshot;
  A, B, C: TWfcMusicVoicesGenerated;
  R: TGraphNegotiationReport;
  Selective: TGraphSelectiveNegotiationReport;
  Proof: TWfcMusicVoicesValidationReport;
  Probe: TProbe;
  Replacement: TLayerModelReplacementReport;
  Model: TWfcSequenceModel;
  Rejected: Boolean;
  Token: String;
  I: Integer;
begin
  Starter := TInstrumentalStarter.Create(0);
  Source := nil;
  Restored := nil;
  Bad := nil;
  Model := nil;
  Probe := TProbe.Create;
  try
    O := DefaultVoiceSessionOptions;
    O.CellCount := 8;
    O.RequireObservedEnd := False;
    Source := TNamedVoiceSession.Create(Starter.Config, ['bass', 'harmony-voice', 'lead'], O);
    Masks := Starter.GuideMasks(8);
    for I := 0 to 4 do Source.SetConstraints(Source.ProviderName(I), Masks[I]);
    Check(Source.TryGenerate(A, R, Proof), 'Actual named musical baseline performs its coupled graph');
    Token := Starter.Config.Voices[2].Model.PublicTokenAt(0);
    Positions := [MakeLayerPositionPreference(0, [MakeLayerTokenPreference(Token, 3)]),
      MakeLayerPositionPreference(4, [MakeLayerTokenPreference(Token, 2)])];
    Source.SetPositionPreferences('lead', Positions);
    Positions[0].Preferences[0].Multiplier := 99;
    Positions[1].Position := 7;
    CopyPositions := Source.CopyPositionPreferences('lead');
    Check((CopyPositions[0].Preferences[0].Multiplier = 3) and
      (CopyPositions[1].Position = 4), 'Named setter owns detached position rows and nested preferences');
    CopyPositions[0].Preferences[0].Multiplier := 100;
    Check(Source.CopyPositionPreferences('lead')[0].Preferences[0].Multiplier = 3,
      'Named position getter is detached');
    Source.SetPreferences('lead', [MakeLayerTokenPreference(Token, 2)]);
    Probe.Cancel := True;
    B := A;
    Rejected := False;
    try Source.TryRegenerate(['lead'], 42, B, Selective, Proof, Probe.Observe);
    except on E: EAbort do Rejected := True end;
    Check(Rejected and Source.HasPending('lead'), 'Named cancellation preserves pending positioned edits');
    SameVoices(A, B, 'Cancelled named publication preserves caller music');
    SameVoices(A, Source.CopyAccepted, 'Cancelled named publication preserves accepted music');
    Check(Source.TryRegenerate(['lead'], 42, B, Selective, Proof),
      'Actual named scopes share global and positioned token adaptation');
    Rejected := False;
    Positions := [MakeLayerPositionPreference(8, [MakeLayerTokenPreference(Token, 2)])];
    try Source.SetPositionPreferences('lead', Positions);
    except on E: EAudio do Rejected := True end;
    Check(Rejected and not Source.HasPending('lead') and
      (Length(Source.CopyPositionPreferences('lead')) = 2),
      'Invalid named position replacement preserves accepted controls and pending flags');
    Snapshot := Source.CopyAcceptedSnapshot;
    Check((Snapshot.Version = 2) and (Length(Snapshot.PositionPreferences) = 5) and
      (Snapshot.PositionPreferences[4][0].Preferences[0].Multiplier = 3),
      'Versioned accepted snapshot keeps actual committed position preferences');
    Restored := TNamedVoiceSession.FromAcceptedSnapshot(Snapshot);
    SameVoices(B, Restored.CopyAccepted, 'Restoration retains authenticated music without searching');
    Snapshot.PositionPreferences[4][0].Preferences[0].Multiplier := 99;
    Check(Restored.CopyPositionPreferences('lead')[0].Preferences[0].Multiplier = 3,
      'Restored session detaches nested snapshot controls');
    Snapshot := Restored.CopyAcceptedSnapshot;
    Snapshot.Version := 1;
    Rejected := False;
    try Bad := TNamedVoiceSession.FromAcceptedSnapshot(Snapshot);
    except on E: EAudio do Rejected := True end;
    Check(Rejected and (Bad = nil), 'Old snapshot version cannot silently drop positioned controls');
    Check(Source.TryRegenerate(['lead'], 42, B, Selective, Proof), 'Source selectively regenerates with retained priors');
    Check(Restored.TryRegenerate(['lead'], 42, C, Selective, Proof), 'Restored session regenerates with retained priors');
    SameVoices(B, C, 'Selective positioned musical replay stays exact after restoration');
    Source.SetPositionPreferences('bass', [MakeLayerPositionPreference(1,
      [MakeLayerTokenPreference(Starter.Config.Voices[0].Model.PublicTokenAt(0), 2)])]);
    Model := Source.CopyModel('lead');
    Check(Source.TryReplaceProvider('lead', Model, Source.CopyContract('lead'), 42,
      B, Replacement, Proof), 'Actual provider replacement keeps positioned controls');
    Check(Source.HasPending('bass') and
      (Source.CopyPositionPreferences('bass')[0].Position = 1) and
      (Source.CopyPositionPreferences('lead')[0].Preferences[0].Multiplier = 3),
      'Provider replacement preserves unrelated pending and affected committed position rows');
  finally
    Probe.Free;
    Bad.Free;
    Restored.Free;
    Source.Free;
    Starter.Free;
    Model.Free;
  end;
end;
var
  M: TWfcSequenceModel;
begin
  M := nil;
  try
    try
      M := RhythmModel;
      ScopeBoundaries(M);
      SegmentAndStream(M);
      HigherOrderFrontier;
      NamedSessions;
      SparsePositionVocabulary;
      WriteLn('PASS position preferences: ', Checks, ' checks');
    finally
      M.Free;
    end;
  except
    on E: Exception do
    begin
      WriteLn('FAIL: ', E.ClassName, ': ', E.Message);
      ExitCode := 1;
    end;
  end;
end.
