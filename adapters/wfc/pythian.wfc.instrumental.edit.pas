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
unit pythian.wfc.instrumental.edit;

{$mode delphi}
{$H+}

interface

uses pythian.audio, pythian.chord, pythian.progress, pythian.music.controls,
  pythian.music.decisions, pythian.wfc.layers, pythian.wfc.percussion,
  wfc, wfc_model, wfc_sequence, wfc_music_ensemble, wfc_music_voices_graph;

const
  InstrumentalPassageEditVersion = 1;

type
  TInstrumentalPartSelection = array of Boolean;
  TInstrumentalPassageEdges = record
    SourcePrevious: TMusicDecisionChunk;
    SourceNext: TMusicDecisionChunk;
    CandidatePrevious: TMusicDecisionChunk;
    FollowingCells: Integer;
  end;
  TInstrumentalPassageEdit = record
    StartFrame: Int64;
    EndFrame: Int64;
    Parts: TInstrumentalPartSelection;
    Harmony: Boolean;
    Rhythm: Boolean;
    Controls: TMusicalPartControls;
    Tonic: Integer;
    TonicBias: Integer;
    Seed: TGraphSeed;
    MaxBacktracks: Integer;
    MaxPassBacktracks: Integer;
  end;
  TInstrumentalPassageReport = record
    Group: String;
    Detail: String;
    ChangedCells: Integer;
    ChangedProviders: Integer;
    ActualStartFrame: Int64;
    ActualEndFrame: Int64;
    ActivePasses: TLayerNames;
  end;

{ Adjacent chunks are borrowed immutable. Single-chunk edits start from the
  recorded predecessor. Streaming callers replace CandidatePrevious with their
  actual preceding candidate and declare remaining structural support. }
function RetainedInstrumentalPassageEdges(const APrevious, ANext: TMusicDecisionChunk):
  TInstrumentalPassageEdges;

{ Big Boss: edits one bounded recorded planning chunk through the same ordered
  context, named-voice and rhythm-conditioned drum graphs as initial generation.
  Models are immutable and borrowed. Source provider order is optional context,
  harmony, rhythm, ordered roles, ordered drums. Edges contain actual original
  neighbors and the actual preceding candidate, not invented token history.
  Empty Previous is allowed only at cell zero. Outside-scope seams are held;
  internal planning chunks continue the candidate. Unrequested providers and cells
  outside the overlapping musical steps retain exact states/tokens/parts.

  This is musical orchestration over primary WFC builders, assignment restore,
  dependency closure and independent captures, not a second solver. It does not
  learn or silently relax constraints. False/exception preserves AAfter and inputs.
  It does not publish a journal or authorize unauthenticated stored observations.
  Native callers bind the complete source journal to its accepted job receipt. }
function TryEditInstrumentalPassageChunk(const AConfig: TWfcMusicVoicesGraphConfig;
  const ARoleNames: TLayerNames; const ADrums: TPercussionDefinitions;
  const AContext: TWfcSequenceModel; const ABefore: TMusicDecisionChunk;
  const AEdges: TInstrumentalPassageEdges;
  const AEdit: TInstrumentalPassageEdit; var AAfter: TMusicDecisionChunk;
  out AReport: TInstrumentalPassageReport;
  const AProgress: TWorkProgressCallback = nil): Boolean;

implementation

uses SysUtils, pythian.time, pythian.percussion, pythian.wfc.music,
  pythian.wfc.progress, pythian.wfc.voices,
  pythian.wfc.instrumental.controls, pythian.wfc.musical.context,
  wfc_sequence_graph;

type
  TEditFlags = array of Boolean;
  TEditModels = array of TWfcSequenceModel;
  TEditBoundaries = array of TWfcSequenceSegmentBoundary;
  TEditKeys = array of TGraphValues;
  TEditProjections = array of TWfcModelTokens;

procedure AddToken(var ATokens: TWfcModelTokens; const AToken: String);
begin
  SetLength(ATokens, Length(ATokens) + 1);
  ATokens[High(ATokens)] := AToken;
end;

procedure AddRoot(var ARoots: TGraphPassLabels; const AName: String);
begin
  SetLength(ARoots, Length(ARoots) + 1);
  ARoots[High(ARoots)] := AName;
end;

procedure Need(const ACondition: Boolean; const AMessage: String);
begin
  if not ACondition then
  begin
    raise EAudio.Create(AMessage);
  end;
end;

function RetainedInstrumentalPassageEdges(const APrevious, ANext: TMusicDecisionChunk):
  TInstrumentalPassageEdges;
begin
  Result := Default(TInstrumentalPassageEdges);
  Result.SourcePrevious := APrevious;
  Result.SourceNext := ANext;
  Result.CandidatePrevious := APrevious;
end;

function ContainsToken(const ATokens: TWfcModelTokens; const AToken: String): Boolean;
var
  LToken: String;
begin
  for LToken in ATokens do
  begin
    if LToken = AToken then
    begin
      Exit(True);
    end;
  end;
  Result := False;
end;

function MaskAllows(const AMasks: TVoiceMasks; const AProvider, ACell: Integer;
  const AToken: String): Boolean;
var
  LMask: TWfcSequenceTokenConstraint;
begin
  Result := True;
  if AProvider >= Length(AMasks) then
  begin
    Exit;
  end;
  for LMask in AMasks[AProvider] do
  begin
    if (LMask.Position = ACell) and not ContainsToken(LMask.AllowedTokens, AToken) then
    begin
      Exit(False);
    end;
  end;
end;

function TryEditInstrumentalPassageChunk(const AConfig: TWfcMusicVoicesGraphConfig;
  const ARoleNames: TLayerNames; const ADrums: TPercussionDefinitions;
  const AContext: TWfcSequenceModel; const ABefore: TMusicDecisionChunk;
  const AEdges: TInstrumentalPassageEdges;
  const AEdit: TInstrumentalPassageEdit; var AAfter: TMusicDecisionChunk;
  out AReport: TInstrumentalPassageReport;
  const AProgress: TWorkProgressCallback): Boolean;
var
  LModels: TEditModels;
  LNames: TLayerNames;
  LBoundaries: TEditBoundaries;
  LSourceBoundaries: TEditBoundaries;
  LResetPasses: TGraphPassIndices;
  LKeepNext: Boolean;
  LEditableProviders: TEditFlags;
  LEditableCells: TEditFlags;
  LCandidate: TMusicDecisionChunk;
  LCompiled: TInstrumentalGraphControls;
  LProjections: TEditProjections;
  LGraph: TGraph;
  LPass: TGraph;
  LBridge: TWfcSolveProgressBridge;
  LAssignments: TGraphAssignmentSnapshot;
  LKeys: TEditKeys;
  LVoiceBoundaries: TWfcMusicVoicesBoundaries;
  LGenerated: TWfcMusicVoicesGenerated;
  LProof: TWfcMusicVoicesValidationReport;
  LSequence: TWfcGeneratedSequenceSegment;
  LSequenceProof: TWfcSequenceGraphValidationReport;
  LSearch: TGraphNegotiationOptions;
  LSearchReport: TGraphSelectiveNegotiationReport;
  LRoots: TGraphPassLabels;
  LCanonicalRoots: TGraphPassIndices;
  LActive: TGraphPassIndices;
  LDrumTokens: TWfcModelTokens;
  LTokens: TWfcModelTokens;
  LMask: TWfcSequenceTokenConstraints;
  LPrefs: TLayerTokenPreferences;
  LContextMasks: TVoiceMasks;
  LFrame: TChordFrame;
  LChanges: array of TSequencePreferenceScope;
  LProvider: Integer;
  LCell: Integer;
  LToken: Integer;
  LRole: Integer;
  LIndex: Integer;
  LCount: Integer;
  LOffset: Integer;
  LNamedCount: Integer;
  LDrumOffset: Integer;
  LWeight: Integer;
  LPreference: TLayerTokenPreference;
  LPosition: Int64;
  LStates: Int64;
  LAllowed: Boolean;
  LAny: Boolean;
  LChanged: Boolean;
  procedure RestorePreferences;
  var
    I: Integer;
  begin
    for I := High(LChanges) downto 0 do
    begin
      LChanges[I].Free;
    end;
    LChanges := nil;
  end;
  procedure RestoreRows(const AFirst, ACount: Integer; const AForCandidate: Boolean = False);
  var
    P: Integer;
    C: Integer;
    R: Integer;
    LReset: Boolean;
  begin
    LAssignments := LGraph.CaptureAssignments(MaximumLayerStateCells,
      MaximumSessionSnapshotTextUnits, LBridge.SolveObserver());
    SetLength(LKeys, ACount);
    for P := 0 to ACount - 1 do
    begin
      LKeys[P] := LGraph.PassGraph[P].CopyRegisteredValues;
      Need(Length(LKeys[P]) = LModels[AFirst + P].StateCount,
        'Retained model differs from registered latent states');
      LReset := False;
      if AForCandidate then
      begin
        for R in LResetPasses do
          LReset := LReset or (P = R);
      end;
      if LReset then Continue;
      for C := 0 to High(ABefore.Cells) do
      begin
        LAssignments.Passes[P].Cells[C].Value :=
          LKeys[P][ABefore.Providers[AFirst + P].States[C]];
        LAssignments.Passes[P].Cells[C].Empty := False;
        LAssignments.Passes[P].Cells[C].Generated := True;
      end;
    end;
    LGraph.RestoreAssignments(LAssignments, MaximumLayerStateCells,
      MaximumSessionSnapshotTextUnits, LBridge.SolveObserver());
  end;
  procedure HoldSeamsAndScope(const AFirst, ACount: Integer);
  var
    P: Integer;
    C: Integer;
    S: Integer;
    LValues: TGraphValues;
    LDomain: TGraphValues;
    LOriginal: String;
  begin
    for P := 0 to ACount - 1 do
    begin
      LPass := LGraph.PassGraph[P];
      for C := 0 to High(ABefore.Cells) do
      begin
        if LEditableCells[C] and LEditableProviders[AFirst + P] then
        begin
          Continue;
        end;
        LOriginal := LKeys[P][ABefore.Providers[AFirst + P].States[C]];
        LDomain := LPass.CopyAllowedValues(C, 0, 0);
        LValues := nil;
        if not LPass.HasAllowedValues(C, 0, 0) or ContainsGraphValue(LDomain, LOriginal) then
          LValues := [LOriginal];
        LPass.SetAllowedValues(C, 0, 0, LValues);
      end;
      if not LKeepNext then
      begin
        Continue;
      end;
      C := High(ABefore.Cells);
      LDomain := LPass.CopyAllowedValues(C, 0, 0);
      LValues := nil;
      for S := 0 to LModels[AFirst + P].StateCount - 1 do
      begin
        if LModels[AFirst + P].StatesCompatible(S, AEdges.SourceNext.Providers[AFirst + P].States[0]) and
          (not LPass.HasAllowedValues(C, 0, 0) or ContainsGraphValue(LDomain, LKeys[P][S])) then
        begin
          SetLength(LValues, Length(LValues) + 1);
          LValues[High(LValues)] := LKeys[P][S];
        end;
      end;
      LPass.SetAllowedValues(C, 0, 0, LValues);
    end;
  end;
  procedure ApplyPreferences(const ALocal: Integer; const APreferences: TLayerTokenPreferences);
  begin
    SetLength(LChanges, Length(LChanges) + 1);
    LChanges[High(LChanges)] := TSequencePreferenceScope.Create(LModels[LProvider],
      LGraph.PassGraph[ALocal], APreferences, AProgress);
  end;
  procedure KeepSequence(const AProvider: Integer; const ASequence: TWfcGeneratedSequenceSegment);
  var
    C: Integer;
  begin
    for C := 0 to High(ABefore.Cells) do
    begin
      LCandidate.Providers[AProvider].Tokens[C] := ASequence.Tokens[C];
      LCandidate.Providers[AProvider].States[C] := ASequence.StateIndices[C];
    end;
  end;
  procedure RequireCaptured(const AFirst, ACount: Integer);
  var
    P: Integer;
    C: Integer;
  begin
    for P := 0 to ACount - 1 do
    begin
      Need(CaptureSolvedSequenceSegment(LModels[AFirst + P], LGraph.PassGraph[P],
        LSourceBoundaries[AFirst + P], LSequence, LSequenceProof,
        LBridge.SequenceWorkObserver()), 'Retained provider failed its independent path proof');
      for C := 0 to High(ABefore.Cells) do
      begin
        Need((LSequence.Tokens[C] = ABefore.Providers[AFirst + P].Tokens[C]) and
          (LSequence.StateIndices[C] = ABefore.Providers[AFirst + P].States[C]),
          'Restored provider differs from recorded decisions');
      end;
    end;
  end;
  procedure OpenSequence(const AProvider: Integer; const AForCandidate: Boolean);
  var
    LBoundary: TWfcSequenceSegmentBoundary;
  begin
    LGraph := TGraph.Create;
    LGraph.WrapNeighbors := False;
    LGraph.Reshape(Length(ABefore.Cells), 1, 1);
    LGraph.CurrentPass := LNames[AProvider];
    LBoundary := LSourceBoundaries[AProvider];
    LResetPasses := nil;
    if AForCandidate then
    begin
      LBoundary := LBoundaries[AProvider];
      if LEditableProviders[AProvider] then LResetPasses := [0];
    end;
    ApplySequenceModelSegmentToGraph(LModels[AProvider], LGraph, LBoundary,
      WfcPreparationWorkObserver(LBridge));
    RestoreRows(AProvider, 1, AForCandidate);
  end;
  function Regenerate(const ARoots: TGraphPassLabels): Boolean;
  var
    P: Integer;
  begin
    LGraph.ResolveRegenerationScope(ARoots, LCanonicalRoots, LActive);
    for P in LActive do
    begin
      SetLength(AReport.ActivePasses, Length(AReport.ActivePasses) + 1);
      AReport.ActivePasses[High(AReport.ActivePasses)] :=
        AReport.Group + '/' + LGraph.PassGraph[P].CurrentPass;
    end;
    LGraph.Seed := AEdit.Seed;
    Result := LGraph.TryRegenerateNegotiatedFrom(ARoots, LSearch, LSearchReport,
      LBridge.SolveObserver());
    if not Result then
    begin
      AReport.Detail := 'Requested choices do not fit ' + AReport.Group +
        ' while the other parts and passage boundaries are retained';
    end;
  end;
begin
  Result := False;
  AReport := Default(TInstrumentalPassageReport);
  LGraph := nil;
  LBridge := nil;
  LOffset := 0;
  RequireExactTimingCounter(AEdit.StartFrame, 'Musical edit start frame');
  RequireExactTimingCounter(AEdit.EndFrame, 'Musical edit end frame');
  if AContext <> nil then
  begin
    LOffset := 1;
  end;
  LNamedCount := 2 + Length(ARoleNames);
  LDrumOffset := LOffset + LNamedCount;
  Need((AEdit.StartFrame >= 0) and (AEdit.EndFrame > AEdit.StartFrame) and
    (Length(ARoleNames) = Length(AConfig.Voices)) and
    (Length(AEdit.Parts) = Length(ARoleNames) + Length(ADrums)) and
    (Length(AEdit.Controls) = Length(ARoleNames)) and
    (AEdit.MaxBacktracks >= 0) and (AEdit.MaxBacktracks <= 65536) and
    (AEdit.MaxPassBacktracks >= 0) and (AEdit.MaxPassBacktracks <= 1024),
    'Passage editing needs a positive range and matching explicit parts/controls');
  ValidateMusicDecisionChunk(ABefore, AProgress);
  Need((AEdges.FollowingCells >= 0) and
    (AEdges.FollowingCells = Trunc(AEdges.FollowingCells)), 'Invalid remaining musical extent');
  Need((Length(AEdges.SourcePrevious.Cells) = 0) = (ABefore.FirstCell = 0),
    'A continued musical edit needs its original predecessor');
  Need((Length(AEdges.CandidatePrevious.Cells) = 0) = (ABefore.FirstCell = 0),
    'A continued musical edit needs its actual preceding candidate');
  if ABefore.FirstCell > 0 then
  begin
    ValidateMusicDecisionChunk(AEdges.SourcePrevious, AProgress);
    ValidateMusicDecisionChunk(AEdges.CandidatePrevious, AProgress);
    Need((AEdges.SourcePrevious.FirstCell + Length(AEdges.SourcePrevious.Cells) = ABefore.FirstCell) and
      (AEdges.SourcePrevious.StartFrame + MusicDecisionFrameCount(AEdges.SourcePrevious) = ABefore.StartFrame) and
      SameMusicDecisionFrame(AEdges.SourcePrevious.Cells[High(AEdges.SourcePrevious.Cells)].Parts,
        ABefore.Previous), 'Original predecessor differs from the saved musical clock/parts');
    Need((AEdges.CandidatePrevious.FirstCell + Length(AEdges.CandidatePrevious.Cells) = ABefore.FirstCell) and
      (AEdges.CandidatePrevious.StartFrame + MusicDecisionFrameCount(AEdges.CandidatePrevious) = ABefore.StartFrame),
      'Candidate predecessor differs from the saved musical clock');
  end;
  LKeepNext := False;
  if Length(AEdges.SourceNext.Cells) > 0 then
  begin
    ValidateMusicDecisionChunk(AEdges.SourceNext, AProgress);
    Need((AEdges.SourceNext.FirstCell = ABefore.FirstCell + Length(ABefore.Cells)) and
      (AEdges.SourceNext.StartFrame = ABefore.StartFrame + MusicDecisionFrameCount(ABefore)) and
      SameMusicDecisionFrame(ABefore.Cells[High(ABefore.Cells)].Parts, AEdges.SourceNext.Previous),
      'Original successor differs from the saved musical clock/parts');
    LKeepNext := AEdit.EndFrame <= AEdges.SourceNext.StartFrame;
  end;
  Need(Length(ABefore.Providers) = LDrumOffset + Length(ADrums),
    'Retained provider layout differs from the saved musical models');
  LAny := AEdit.Harmony or AEdit.Rhythm;
  for LAllowed in AEdit.Parts do
  begin
    LAny := LAny or LAllowed;
  end;
  Need(LAny, 'Choose at least one musical part to change');
  Need(AEdit.Harmony or (AEdit.TonicBias = 0),
    'Allow harmony changes before choosing a chord-root preference');
  for LRole := 0 to High(AEdit.Controls) do
  begin
    Need(AEdit.Parts[LRole] or
      ((AEdit.Controls[LRole].MinimumPitch = 0) and
      (AEdit.Controls[LRole].MaximumPitch = 127)),
      'Select a pitched part before requesting a new pitch range');
    Need(AEdit.Rhythm or (AEdit.Controls[LRole].ActivityBias = 0),
      'Allow rhythm changes before choosing an activity preference');
    Need((AEdit.Controls[LRole].Expression.VelocityPercent = 100) and
      (AEdit.Controls[LRole].Expression.GatePercent = 100),
      'Passage graph edits keep performed expression; use the performance controls separately');
  end;
  SetLength(LEditableCells, Length(ABefore.Cells));
  LPosition := ABefore.StartFrame;
  LAny := False;
  for LCell := 0 to High(ABefore.Cells) do
  begin
    LEditableCells[LCell] := (LPosition < AEdit.EndFrame) and
      (LPosition + ABefore.Cells[LCell].FrameCount > AEdit.StartFrame);
    if LEditableCells[LCell] then
    begin
      if not LAny then
      begin
        AReport.ActualStartFrame := LPosition;
      end;
      AReport.ActualEndFrame := LPosition + ABefore.Cells[LCell].FrameCount;
      LAny := True;
    end;
    Inc(LPosition, ABefore.Cells[LCell].FrameCount);
  end;
  if not LAny then
  begin
    LCandidate := CopyMusicDecisionChunk(ABefore);
    if ABefore.FirstCell > 0 then
      LCandidate.Previous := CopyChordFrame(AEdges.CandidatePrevious.Cells[High(AEdges.CandidatePrevious.Cells)].Parts);
    ValidateMusicDecisionChunk(LCandidate, AProgress);
    AAfter := LCandidate;
    Exit(True);
  end;
  SetLength(LModels, Length(ABefore.Providers));
  SetLength(LNames, Length(LModels));
  SetLength(LEditableProviders, Length(LModels));
  SetLength(LBoundaries, Length(LModels));
  SetLength(LSourceBoundaries, Length(LModels));
  if AContext <> nil then
  begin
    LModels[0] := AContext;
    LNames[0] := MusicalContextPassName;
    LEditableProviders[0] := AEdit.Harmony or AEdit.Rhythm;
    for LRole := 0 to High(ARoleNames) do
    begin
      LEditableProviders[0] := LEditableProviders[0] or AEdit.Parts[LRole];
    end;
  end;
  for LProvider := 0 to LNamedCount - 1 do
  begin
    LModels[LOffset + LProvider] := WfcMusicVoicesModelAt(AConfig, LProvider);
    if LProvider = 0 then
    begin
      LNames[LOffset] := 'harmony';
      LEditableProviders[LOffset] := AEdit.Harmony;
    end
    else if LProvider = 1 then
    begin
      LNames[LOffset + 1] := 'rhythm';
      LEditableProviders[LOffset + 1] := AEdit.Rhythm;
    end
    else
    begin
      LNames[LOffset + LProvider] := ARoleNames[LProvider - 2];
      LEditableProviders[LOffset + LProvider] := AEdit.Parts[LProvider - 2];
    end;
  end;
  for LIndex := 0 to High(ADrums) do
  begin
    LModels[LDrumOffset + LIndex] := ADrums[LIndex].Model;
    LNames[LDrumOffset + LIndex] := ADrums[LIndex].Name;
    LEditableProviders[LDrumOffset + LIndex] := AEdit.Parts[Length(ARoleNames) + LIndex];
  end;
  Need((ABefore.FirstCell = 0) or
    ((Length(AEdges.SourcePrevious.Providers) = Length(LModels)) and
    (Length(AEdges.CandidatePrevious.Providers) = Length(LModels))),
    'Musical predecessor layouts differ');
  Need((Length(AEdges.SourceNext.Cells) = 0) or
    (Length(AEdges.SourceNext.Providers) = Length(LModels)),
    'Musical edit successor layout differs');
  LStates := 0;
  for LProvider := 0 to High(LModels) do
  begin
    ReportWork(AProgress, 'instrumental_edit_validate', wuItems, LProvider, Length(LModels));
    Need((LModels[LProvider] <> nil) and
      (ABefore.Providers[LProvider].Key = LNames[LProvider]), 'Retained provider identity differs');
    Inc(LStates, LModels[LProvider].StateCount);
    LSourceBoundaries[LProvider] := MakeWfcSequenceInitialSegmentBoundary(False);
    LBoundaries[LProvider] := MakeWfcSequenceInitialSegmentBoundary(False);
    if ABefore.FirstCell > 0 then
    begin
      Need((AEdges.SourcePrevious.Providers[LProvider].Key = LNames[LProvider]) and
        (AEdges.CandidatePrevious.Providers[LProvider].Key = LNames[LProvider]),
        'Retained predecessor identity differs');
      LSourceBoundaries[LProvider] := MakeWfcSequenceContinuingSegmentBoundary(
        AEdges.SourcePrevious.Providers[LProvider].States[High(AEdges.SourcePrevious.Cells)], False);
      LBoundaries[LProvider] := MakeWfcSequenceContinuingSegmentBoundary(
        AEdges.CandidatePrevious.Providers[LProvider].States[High(AEdges.CandidatePrevious.Cells)], False);
    end;
    LBoundaries[LProvider].MinimumFollowingCells := AEdges.FollowingCells;
    Need(ValidateSequenceSegmentStatePath(LModels[LProvider], ABefore.Providers[LProvider].States,
      LSourceBoundaries[LProvider], LSequenceProof), 'Recorded musical provider has an invalid latent path');
    for LCell := 0 to High(ABefore.Cells) do
    begin
      Need(LModels[LProvider].ProjectStateToken(ABefore.Providers[LProvider].States[LCell]) =
        ABefore.Providers[LProvider].Tokens[LCell], 'Recorded musical token differs from its latent state');
    end;
    if Length(AEdges.SourceNext.Cells) > 0 then
    begin
      Need((AEdges.SourceNext.Providers[LProvider].Key = LNames[LProvider]) and
        LModels[LProvider].StatesCompatible(ABefore.Providers[LProvider].States[High(ABefore.Cells)],
          AEdges.SourceNext.Providers[LProvider].States[0]), 'Recorded musical successor seam is invalid');
    end;
  end;
  Need(LStates * Length(ABefore.Cells) <= MaximumLayerStateCells,
    'Musical edit exceeds its bounded state-cell budget');
  LCandidate := CopyMusicDecisionChunk(ABefore);
  if ABefore.FirstCell > 0 then
    LCandidate.Previous := CopyChordFrame(AEdges.CandidatePrevious.Cells[High(AEdges.CandidatePrevious.Cells)].Parts);
  LCompiled := CompileInstrumentalControls(AConfig, Length(ABefore.Cells), AEdit.Tonic,
    AEdit.TonicBias, AEdit.Controls, nil, AProgress);
  LSearch := DefaultGraphNegotiationOptions;
  LSearch.SolveOptions.MaxBacktracks := AEdit.MaxBacktracks;
  LSearch.MaxPassBacktracks := AEdit.MaxPassBacktracks;
  LBridge := TWfcSolveProgressBridge.Create(AProgress);
  try
    { Context is the existing upstream group, not an invented joint Cartesian
      model. Filter its choices against every held musical part before solving. }
    if AContext <> nil then
    begin
      AReport.Group := 'musical context';
      OpenSequence(0, False);
      RequireCaptured(0, 1);
      for LCell := 0 to High(ABefore.Cells) do
      begin
        LContextMasks := BindMusicalContextTokens([ABefore.Providers[0].Tokens[LCell]],
          Length(ARoleNames), nil, True);
        for LIndex := 0 to LNamedCount - 1 do
        begin
          Need(LContextMasks[LIndex][0].AllowedTokens[0] =
            ABefore.Providers[LOffset + LIndex].Tokens[LCell],
            'Recorded context differs from the accepted musical parts');
        end;
      end;
      FreeAndNil(LGraph);
      OpenSequence(0, True);
      SetLength(LProjections, AContext.PublicTokenCount);
      LPrefs := nil;
      for LToken := 0 to AContext.PublicTokenCount - 1 do
      begin
        if (LToken mod 32) = 0 then
        begin
          ReportWork(AProgress, 'instrumental_edit_context', wuItems,
            LToken, AContext.PublicTokenCount);
        end;
        LContextMasks := BindMusicalContextTokens([AContext.PublicTokenAt(LToken)],
          Length(ARoleNames), nil, True);
        SetLength(LProjections[LToken], LNamedCount);
        LWeight := 1;
        for LIndex := 0 to LNamedCount - 1 do
        begin
          LProjections[LToken][LIndex] := LContextMasks[LIndex][0].AllowedTokens[0];
          if LIndex < Length(LCompiled.Preferences) then
          begin
            for LPreference in LCompiled.Preferences[LIndex] do
            begin
              if LPreference.Token = LProjections[LToken][LIndex] then
              begin
                Need(LWeight <= MaximumLayerPreferenceMultiplier div LPreference.Multiplier,
                  'Combined musical context preference exceeds its bound');
                LWeight := LWeight * LPreference.Multiplier;
              end;
            end;
          end;
        end;
        if LWeight > 1 then
        begin
          SetLength(LPrefs, Length(LPrefs) + 1);
          LPrefs[High(LPrefs)] := MakeLayerTokenPreference(AContext.PublicTokenAt(LToken), LWeight);
        end;
      end;
      HoldSeamsAndScope(0, 1);
      for LCell := 0 to High(ABefore.Cells) do
      begin
        ReportWork(AProgress, 'instrumental_edit_context_masks', wuItems,
          LCell, Length(ABefore.Cells));
        LTokens := nil;
        for LToken := 0 to AContext.PublicTokenCount - 1 do
        begin
          LAllowed := True;
          for LIndex := 0 to LNamedCount - 1 do
          begin
            if not LEditableCells[LCell] or not LEditableProviders[LOffset + LIndex] then
            begin
              LAllowed := LAllowed and (LProjections[LToken][LIndex] =
                ABefore.Providers[LOffset + LIndex].Tokens[LCell]);
            end
            else
            begin
              LAllowed := LAllowed and MaskAllows(LCompiled.Masks, LIndex, LCell,
                LProjections[LToken][LIndex]);
            end;
          end;
          for LIndex := 0 to High(ADrums) do
          begin
            if not LEditableProviders[LDrumOffset + LIndex] then
            begin
              LAllowed := LAllowed and ContainsToken(AllowedPercussionRhythms(AConfig.RhythmModel,
                ADrums[LIndex], ABefore.Providers[LDrumOffset + LIndex].Tokens[LCell]),
                LProjections[LToken][1]);
            end;
          end;
          if LAllowed then
          begin
            AddToken(LTokens, AContext.PublicTokenAt(LToken));
          end;
        end;
        IntersectSequenceAllowedTokens(AContext, LGraph, LCell, LTokens);
      end;
      LProvider := 0;
      ApplyPreferences(0, LPrefs);
      if LEditableProviders[0] then
      begin
        if not Regenerate([MusicalContextPassName]) then
        begin
          Exit;
        end;
        RestorePreferences;
        Need(CaptureSolvedSequenceSegment(AContext, LGraph, LBoundaries[0], LSequence,
          LSequenceProof, LBridge.SequenceWorkObserver()), 'Edited context failed its independent path proof');
        KeepSequence(0, LSequence);
      end;
      RestorePreferences;
      FreeAndNil(LGraph);
    end;

    AReport.Group := 'saved pitched parts';
    SetLength(LVoiceBoundaries, LNamedCount);
    for LIndex := 0 to LNamedCount - 1 do
    begin
      LVoiceBoundaries[LIndex] := LSourceBoundaries[LOffset + LIndex];
    end;
    LGraph := BuildWfcMusicVoicesSegmentGraph(AConfig, Length(ABefore.Cells), AEdit.Seed,
      LVoiceBoundaries, WfcPreparationWorkObserver(LBridge));
    RestoreRows(LOffset, LNamedCount);
    LRoots := nil;
    for LIndex := LNamedCount to LGraph.TotalPassCount - 1 do
    begin
      AddRoot(LRoots, LGraph.PassGraph[LIndex].CurrentPass);
    end;
    if Length(LRoots) > 0 then
    begin
      Need(Regenerate(LRoots), 'Recorded pitched parts have invalid harmonic coverage');
    end;
    Need(CaptureSolvedWfcMusicVoices(AConfig, LGraph, LVoiceBoundaries, LGenerated,
      LProof, WfcPreparationWorkObserver(LBridge)), 'Recorded pitched parts failed musical validation: ' + LProof.Issue.Detail);
    SetLength(LDrumTokens, Length(ADrums));
    for LCell := 0 to High(ABefore.Cells) do
    begin
      for LIndex := 0 to High(ADrums) do
      begin
        LDrumTokens[LIndex] := ABefore.Providers[LDrumOffset + LIndex].Tokens[LCell];
      end;
      LFrame := AppendPercussionDecisions(ProjectWfcChordFrame(LGenerated.Frames[LCell]),
        LDrumTokens, ADrums);
      Need(SameMusicDecisionFrame(LFrame, ABefore.Cells[LCell].Parts),
        'Recorded performed parts differ from actual provider decisions');
    end;
    FreeAndNil(LGraph);
    AReport.Group := 'pitched parts';
    for LIndex := 0 to LNamedCount - 1 do
      LVoiceBoundaries[LIndex] := LBoundaries[LOffset + LIndex];
    LGraph := BuildWfcMusicVoicesSegmentGraph(AConfig, Length(ABefore.Cells), AEdit.Seed,
      LVoiceBoundaries, WfcPreparationWorkObserver(LBridge));
    LRoots := nil;
    for LIndex := 0 to LNamedCount - 1 do
      if LEditableProviders[LOffset + LIndex] then
        AddRoot(LRoots, LGraph.PassGraph[LIndex].CurrentPass);
    for LIndex := LNamedCount to LGraph.TotalPassCount - 1 do
      AddRoot(LRoots, LGraph.PassGraph[LIndex].CurrentPass);
    LResetPasses := nil;
    if Length(LRoots) > 0 then
      LGraph.ResolveRegenerationScope(LRoots, LCanonicalRoots, LResetPasses);
    RestoreRows(LOffset, LNamedCount, True);
    HoldSeamsAndScope(LOffset, LNamedCount);
    LContextMasks := nil;
    if AContext <> nil then
    begin
      SetLength(LTokens, Length(ABefore.Cells));
      for LCell := 0 to High(LTokens) do
      begin
        LTokens[LCell] := LCandidate.Providers[0].Tokens[LCell];
      end;
      LContextMasks := BindMusicalContextTokens(LTokens, Length(ARoleNames), nil, True);
    end;
    for LIndex := 0 to LNamedCount - 1 do
    begin
      LPass := LGraph.PassGraph[LIndex];
      LProvider := LOffset + LIndex;
      for LCell := 0 to High(ABefore.Cells) do
      begin
        if AContext <> nil then
        begin
          IntersectSequenceAllowedTokens(LModels[LProvider], LPass, LCell,
            LContextMasks[LIndex][LCell].AllowedTokens);
        end;
        if LEditableCells[LCell] and LEditableProviders[LProvider] and
          (LIndex < Length(LCompiled.Masks)) then
        begin
          LMask := LCompiled.Masks[LIndex];
          for LCount := 0 to High(LMask) do
          begin
            if LMask[LCount].Position = LCell then
            begin
              IntersectSequenceAllowedTokens(LModels[LProvider], LPass, LCell,
                LMask[LCount].AllowedTokens);
            end;
          end;
        end;
      end;
      if LIndex < Length(LCompiled.Preferences) then
      begin
        ApplyPreferences(LIndex, LCompiled.Preferences[LIndex]);
      end;
    end;
    if Length(LRoots) > 0 then
    begin
      if not Regenerate(LRoots) then
      begin
        Exit;
      end;
    end;
    RestorePreferences;
    Need(CaptureSolvedWfcMusicVoices(AConfig, LGraph, LVoiceBoundaries, LGenerated,
      LProof, WfcPreparationWorkObserver(LBridge)), 'Edited pitched parts failed independent musical validation');
    for LIndex := 0 to LNamedCount - 1 do
    begin
      KeepSequence(LOffset + LIndex, LGenerated.Layers[LIndex]);
    end;
    FreeAndNil(LGraph);

    for LIndex := 0 to High(ADrums) do
    begin
      LProvider := LDrumOffset + LIndex;
      AReport.Group := ADrums[LIndex].Name;
      OpenSequence(LProvider, False);
      RequireCaptured(LProvider, 1);
      for LCell := 0 to High(ABefore.Cells) do
      begin
        Need(ContainsToken(AllowedPercussionRhythms(AConfig.RhythmModel, ADrums[LIndex],
          ABefore.Providers[LProvider].Tokens[LCell]), ABefore.Providers[LOffset + 1].Tokens[LCell]),
          'Recorded drum part differs from its accepted rhythm');
      end;
      FreeAndNil(LGraph);
      OpenSequence(LProvider, True);
      HoldSeamsAndScope(LProvider, 1);
      for LCell := 0 to High(ABefore.Cells) do
      begin
        LTokens := nil;
        for LToken := 0 to LModels[LProvider].PublicTokenCount - 1 do
        begin
          if (ADrums[LIndex].Enabled or
            (PercussionVelocity(LModels[LProvider].PublicTokenAt(LToken)) = 0)) and
            ContainsToken(AllowedPercussionRhythms(AConfig.RhythmModel, ADrums[LIndex],
            LModels[LProvider].PublicTokenAt(LToken)),
            LCandidate.Providers[LOffset + 1].Tokens[LCell]) then
          begin
            AddToken(LTokens, LModels[LProvider].PublicTokenAt(LToken));
          end;
        end;
        IntersectSequenceAllowedTokens(LModels[LProvider], LGraph, LCell, LTokens);
        for LCount := 0 to High(ADrums[LIndex].Constraints) do
        begin
          if ADrums[LIndex].Constraints[LCount].Position = ABefore.FirstCell + LCell then
          begin
            IntersectSequenceAllowedTokens(LModels[LProvider], LGraph, LCell,
              ADrums[LIndex].Constraints[LCount].AllowedTokens);
          end;
        end;
      end;
      if LEditableProviders[LProvider] then
      begin
        ApplyPreferences(0, PercussionPreferences(ADrums[LIndex]));
        if not Regenerate([ADrums[LIndex].Name]) then
        begin
          Exit;
        end;
      end;
      RestorePreferences;
      Need(CaptureSolvedSequenceSegment(LModels[LProvider], LGraph, LBoundaries[LProvider],
        LSequence, LSequenceProof, LBridge.SequenceWorkObserver()),
        'Edited drum part failed its independent path/domain proof');
      KeepSequence(LProvider, LSequence);
      FreeAndNil(LGraph);
    end;

    for LCell := 0 to High(ABefore.Cells) do
    begin
      for LIndex := 0 to High(ADrums) do
      begin
        LDrumTokens[LIndex] := LCandidate.Providers[LDrumOffset + LIndex].Tokens[LCell];
      end;
      LCandidate.Cells[LCell].Parts :=
        AppendPercussionDecisions(ProjectWfcChordFrame(LGenerated.Frames[LCell]), LDrumTokens, ADrums);
      LChanged := not SameMusicDecisionFrame(LCandidate.Cells[LCell].Parts, ABefore.Cells[LCell].Parts);
      if LChanged then
      begin
        Need(LEditableCells[LCell], 'Musical edit changed an outside-range decision');
        Inc(AReport.ChangedCells);
      end;
      for LRole := 0 to High(AEdit.Parts) do
      begin
        if not LEditableCells[LCell] or not AEdit.Parts[LRole] then
        begin
          Need(SameMusicDecisionFrame([LCandidate.Cells[LCell].Parts[LRole]],
            [ABefore.Cells[LCell].Parts[LRole]]), 'Musical edit changed an unrequested part');
        end;
      end;
    end;
    for LProvider := 0 to High(LModels) do
    begin
      LChanged := False;
      for LCell := 0 to High(ABefore.Cells) do
      begin
        LAny := (LCandidate.Providers[LProvider].States[LCell] <>
          ABefore.Providers[LProvider].States[LCell]) or
          (LCandidate.Providers[LProvider].Tokens[LCell] <> ABefore.Providers[LProvider].Tokens[LCell]);
        Need(not LAny or (LEditableProviders[LProvider] and LEditableCells[LCell]),
          'Musical edit changed a retained provider state');
        LChanged := LChanged or LAny;
      end;
      if LChanged then
      begin
        Inc(AReport.ChangedProviders);
      end;
    end;
    ValidateMusicDecisionChunk(LCandidate, AProgress);
    ReportWork(AProgress, 'instrumental_edit_ready', wuItems, 1, 1);
    AAfter := LCandidate;
    AReport.Detail := '';
    Result := True;
  finally
    RestorePreferences;
    LGraph.Free;
    LBridge.Free;
  end;
end;

end.
