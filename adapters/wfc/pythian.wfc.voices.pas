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
unit pythian.wfc.voices;

{$mode delphi}
{$H+}

interface

uses
  wfc,
  wfc_model,
  wfc_sequence,
  wfc_sequence_graph,
  wfc_music_ensemble,
  wfc_music_voices_graph,
  pythian.wfc.layers,
  pythian.wfc.providers,
  pythian.wfc.provider.contracts;

type
  TVoiceSessionOptions = record
    CellCount: Integer;
    TicksPerQuarter: Integer;
    StepTicks: Integer;
    Seed: TGraphSeed;
    RequireObservedEnd: Boolean;
    MaxBacktracks: Integer;
    MaxPassBacktracks: Integer;
  end;
  TVoiceMasks = array of TWfcSequenceTokenConstraints;
  { Owns clones of all models and the actual independent-voice graph. Public
    names are harmony, rhythm and caller-declared role names. Masks are staged;
    selective regeneration applies only edits in the requested WFC descendant
    closure. Unrelated pending edits stay pending, and accepted states stay exact.
    Coverage witnesses are proof passes, not additional musical providers. }
  TNamedVoiceSession = class
  private
    FConfig: TWfcMusicVoicesGraphConfig;
    FNames: TLayerNames;
    FOptions: TVoiceSessionOptions;
    FGraph: TGraph;
    FBoundaries: TWfcMusicVoicesBoundaries;
    FBaseline: array of TLayerDomains;
    FHasBaseline: array of TLayerDomainFlags;
    FPending: TVoiceMasks;
    FCommitted: TVoiceMasks;
    FDirty: array of Boolean;
    FAccepted: TWfcMusicVoicesGenerated;
    FContracts: TProviderContracts;
    function IndexOf(const AName: String): Integer;
    function NegotiationOptions: TGraphNegotiationOptions;
    procedure ApplyMask(const AIndex: Integer;
      const AMask: TWfcSequenceTokenConstraints);
    procedure Publish(const AActive: TGraphPassIndices;
      var AGenerated: TWfcMusicVoicesGenerated;
      out AProof: TWfcMusicVoicesValidationReport);
  public
    constructor Create(const AConfig: TWfcMusicVoicesGraphConfig;
      const ARoleNames: array of String; const AOptions: TVoiceSessionOptions;
      const AContracts: TProviderContracts = nil);
    destructor Destroy; override;
    function ProviderCount: Integer;
    function ProviderName(const AIndex: Integer): String;
    function ProofPassCount: Integer;
    function CopyProvider(const AName: String): TStyleProviderDescription;
    function CopyModel(const AName: String): TWfcSequenceModel;
    function CopyContract(const AName: String): TProviderContract;
    { Candidate graph/model replacement. Pending edits outside its actual
      dependency closure remain pending; accepted unrelated state stays exact. }
    function TryReplaceProvider(const AName: String; const AModel: TWfcSequenceModel;
      const AContract: TProviderContract; const ASeed: TGraphSeed;
      var AGenerated: TWfcMusicVoicesGenerated;
      out AReport: TLayerModelReplacementReport;
      out AProof: TWfcMusicVoicesValidationReport): Boolean;
    procedure SetConstraints(const AName: String;
      const AMask: TWfcSequenceTokenConstraints);
    function CopyConstraints(const AName: String): TWfcSequenceTokenConstraints;
    function HasPending(const AName: String): Boolean;
    function CopyAccepted: TWfcMusicVoicesGenerated;
    function TryGenerate(var AGenerated: TWfcMusicVoicesGenerated;
      out AReport: TGraphNegotiationReport;
      out AProof: TWfcMusicVoicesValidationReport): Boolean;
    function TryRegenerate(const ARoots: array of String; const ASeed: TGraphSeed;
      var AGenerated: TWfcMusicVoicesGenerated;
      out AReport: TGraphSelectiveNegotiationReport;
      out AProof: TWfcMusicVoicesValidationReport): Boolean;
  end;

function DefaultVoiceSessionOptions: TVoiceSessionOptions;
{ Exact action, chord cardinality and velocities; optional absolute MIDI pitches
  or 12-TET pitch classes. No inferred roles, automatic octave remapping or
  relaxation if the returned vocabulary is empty. Borrows the model only here. }
function VoiceChoiceTokens(const AModel: TWfcSequenceModel;
  const AGuide: TWfcMusicVoiceCell; const ARequirePitch,
  ARequirePitchClasses: Boolean): TWfcModelTokens;

implementation

uses
  SysUtils,
  pythian.audio,
  pythian.wfc.music,
  wfc_sequence_text;

function DefaultVoiceSessionOptions: TVoiceSessionOptions;
begin
  Result := Default(TVoiceSessionOptions);
  Result.CellCount := 32;
  Result.TicksPerQuarter := 480;
  Result.StepTicks := 240;
  Result.Seed := 731;
  Result.RequireObservedEnd := True;
  Result.MaxBacktracks := 512;
  Result.MaxPassBacktracks := 32;
end;

function CopyMask(const AMask: TWfcSequenceTokenConstraints): TWfcSequenceTokenConstraints;
var
  LIndex: Integer;
begin
  Result := Copy(AMask);
  for LIndex := 0 to High(Result) do
  begin
    Result[LIndex].AllowedTokens := Copy(AMask[LIndex].AllowedTokens);
  end;
end;

function CopyGenerated(const AValue: TWfcMusicVoicesGenerated): TWfcMusicVoicesGenerated;
var
  LIndex: Integer;
  LVoice: Integer;
begin
  Result := Default(TWfcMusicVoicesGenerated);
  Result.Layers := Copy(AValue.Layers);
  for LIndex := 0 to High(Result.Layers) do
  begin
    Result.Layers[LIndex].Tokens := Copy(AValue.Layers[LIndex].Tokens);
    Result.Layers[LIndex].StateIndices := Copy(AValue.Layers[LIndex].StateIndices);
  end;
  Result.Frames := Copy(AValue.Frames);
  for LIndex := 0 to High(Result.Frames) do
  begin
    Result.Frames[LIndex].Voices := Copy(AValue.Frames[LIndex].Voices);
    for LVoice := 0 to High(Result.Frames[LIndex].Voices) do
    begin
      Result.Frames[LIndex].Voices[LVoice].Tones :=
        Copy(AValue.Frames[LIndex].Voices[LVoice].Tones);
    end;
  end;
  Result.Coverage := Copy(AValue.Coverage);
  for LIndex := 0 to High(Result.Coverage) do
  begin
    Result.Coverage[LIndex].Suppliers := Copy(AValue.Coverage[LIndex].Suppliers);
  end;
end;

constructor TNamedVoiceSession.Create(const AConfig: TWfcMusicVoicesGraphConfig;
  const ARoleNames: array of String; const AOptions: TVoiceSessionOptions;
  const AContracts: TProviderContracts);
var
  LIndex: Integer;
  LOther: Integer;
  LCell: Integer;
  LStates: Int64;
  LOrder: Integer;
  LModel: TWfcSequenceModel;
  LModels: array of TWfcSequenceModel;
  LPass: TGraph;
  LExpected: TProviderContract;
  LDomain: String;
begin
  inherited Create;
  if (Length(AConfig.Voices) < 1) or
    (Length(AConfig.Voices) + 2 > MaximumLearnedLayers) or
    (Length(ARoleNames) <> Length(AConfig.Voices)) then
  begin
    raise EAudio.Create('Named voices require 1..6 explicitly named roles');
  end;
  if (AConfig.StepsPerOctave <> 12) or (AOptions.CellCount < 1) or
    (AOptions.CellCount > MaximumLayerCells) or (AOptions.TicksPerQuarter < 1) or
    (AOptions.StepTicks < 1) or
    (Int64(AOptions.StepTicks) * AOptions.CellCount > High(Integer)) or
    (AOptions.MaxBacktracks < 0) or (AOptions.MaxPassBacktracks < 0) then
  begin
    raise EAudio.Create('Named voices require bounded cells, MIDI pitches and explicit PPQ timing');
  end;
  SetLength(FNames, Length(ARoleNames) + 2);
  FNames[0] := 'harmony';
  FNames[1] := 'rhythm';
  for LIndex := 0 to High(ARoleNames) do
  begin
    FNames[LIndex + 2] := ARoleNames[LIndex];
  end;
  LStates := 0;
  LOrder := 1;
  for LIndex := 0 to High(FNames) do
  begin
    if (Length(FNames[LIndex]) < 1) or (Length(FNames[LIndex]) > 128) or
      (Trim(FNames[LIndex]) <> FNames[LIndex]) then
    begin
      raise EAudio.Create('Role names require 1..128 characters without surrounding spaces');
    end;
    for LOther := 1 to Length(FNames[LIndex]) do
    begin
      if Ord(FNames[LIndex][LOther]) < 32 then
      begin
        raise EAudio.Create('Role names cannot contain control characters');
      end;
    end;
    for LOther := 0 to LIndex - 1 do
    begin
      if FNames[LIndex] = FNames[LOther] then
      begin
        raise EAudio.Create('Role names must be unique, including harmony and rhythm');
      end;
    end;
    LModel := WfcMusicVoicesModelAt(AConfig, LIndex);
    if (LModel = nil) or (LModel.StateCount > MaximumLayerStateCells) or
      (LModel.PublicTokenCount > 4096) or (LModel.Order > 64) then
    begin
      raise EAudio.Create('Voice model exceeds the bounded vocabulary/state/order contract');
    end;
    Inc(LStates, LModel.StateCount);
    if LModel.Order > LOrder then
    begin
      LOrder := LModel.Order;
    end;
  end;
  if (LStates * AOptions.CellCount > MaximumLayerStateCells) or
    (LStates * LStates * (LOrder + 1) > MaximumLayerProjectionWork) then
  begin
    raise EAudio.Create('Named voice state/cell or graph preparation budget exceeded');
  end;
  SetLength(LModels, Length(AConfig.Voices));
  for LIndex := 0 to High(LModels) do
  begin
    if (AConfig.Voices[LIndex].MinPitch < 0) or
      (AConfig.Voices[LIndex].MaxPitch > 127) then
    begin
      raise EAudio.Create('Named voice ranges use absolute MIDI pitches 0..127');
    end;
    LModels[LIndex] := AConfig.Voices[LIndex].Model;
  end;
  WfcIndependentVoiceCapacities(LModels);
  ValidateWfcMusicVoicesGraphConfig(AConfig);
  FOptions := AOptions;
  FConfig := CopyWfcMusicVoicesGraphConfig(AConfig);
  { Never own caller pointers, including when cloning a later model fails. }
  FConfig.HarmonyModel := nil;
  FConfig.RhythmModel := nil;
  for LIndex := 0 to High(FConfig.Voices) do
  begin
    FConfig.Voices[LIndex].Model := nil;
  end;
  FConfig.HarmonyModel := DecodeWfcSequenceText(EncodeWfcSequenceText(AConfig.HarmonyModel));
  FConfig.RhythmModel := DecodeWfcSequenceText(EncodeWfcSequenceText(AConfig.RhythmModel));
  for LIndex := 0 to High(FConfig.Voices) do
  begin
    FConfig.Voices[LIndex].Model := DecodeWfcSequenceText(
      EncodeWfcSequenceText(AConfig.Voices[LIndex].Model));
  end;
  SetLength(FBoundaries, Length(FNames));
  for LIndex := 0 to High(FBoundaries) do
  begin
    FBoundaries[LIndex] := MakeWfcSequenceInitialSegmentBoundary(AOptions.RequireObservedEnd);
  end;
  FGraph := BuildWfcMusicVoicesSegmentGraph(FConfig, AOptions.CellCount,
    AOptions.Seed, FBoundaries);
  SetLength(FBaseline, Length(FNames));
  SetLength(FHasBaseline, Length(FNames));
  SetLength(FPending, Length(FNames));
  SetLength(FCommitted, Length(FNames));
  SetLength(FDirty, Length(FNames));
  for LIndex := 0 to High(FNames) do
  begin
    LPass := FGraph.PassGraph[LIndex];
    SetLength(FBaseline[LIndex], AOptions.CellCount);
    SetLength(FHasBaseline[LIndex], AOptions.CellCount);
    for LCell := 0 to AOptions.CellCount - 1 do
    begin
      FHasBaseline[LIndex][LCell] := LPass.HasAllowedValues(LCell, 0, 0);
      FBaseline[LIndex][LCell] := LPass.CopyAllowedValues(LCell, 0, 0);
    end;
  end;
  if (Length(AContracts) <> 0) and (Length(AContracts) <> Length(FNames)) then
  begin
    raise EAudio.Create('Named voices need one semantic contract per musical provider');
  end;
  LDomain := 'voice-session';
  if Length(AContracts) <> 0 then
  begin
    LDomain := AContracts[0].MusicalDomain;
  end;
  SetLength(FContracts, Length(FNames));
  for LIndex := 0 to High(FNames) do
  begin
    LExpected := ProviderContractFromDescription(CopyProvider(FNames[LIndex]), LDomain);
    FContracts[LIndex] := LExpected;
    if Length(AContracts) <> 0 then
    begin
      ValidateProviderContract(WfcMusicVoicesModelAt(FConfig, LIndex), AContracts[LIndex]);
      RequireCompatibleProvider(LExpected, AContracts[LIndex]);
      FContracts[LIndex] := CopyProviderContract(AContracts[LIndex]);
    end;
  end;
end;

destructor TNamedVoiceSession.Destroy;
var
  LIndex: Integer;
begin
  FGraph.Free;
  for LIndex := 0 to High(FConfig.Voices) do
  begin
    FConfig.Voices[LIndex].Model.Free;
  end;
  FConfig.RhythmModel.Free;
  FConfig.HarmonyModel.Free;
  inherited Destroy;
end;

function TNamedVoiceSession.IndexOf(const AName: String): Integer;
begin
  for Result := 0 to High(FNames) do
  begin
    if FNames[Result] = AName then
    begin
      Exit;
    end;
  end;
  raise EAudio.CreateFmt('Unknown musical role "%s"', [AName]);
end;

function TNamedVoiceSession.ProviderCount: Integer;
begin
  Result := Length(FNames);
end;

function TNamedVoiceSession.ProviderName(const AIndex: Integer): String;
begin
  if (AIndex < 0) or (AIndex >= Length(FNames)) then
  begin
    raise EAudio.Create('Voice provider index out of range');
  end;
  Result := FNames[AIndex];
end;

function TNamedVoiceSession.ProofPassCount: Integer;
begin
  Result := FGraph.TotalPassCount - Length(FNames);
end;

function TNamedVoiceSession.CopyModel(const AName: String): TWfcSequenceModel;
begin
  Result := DecodeWfcSequenceText(EncodeWfcSequenceText(
    WfcMusicVoicesModelAt(FConfig, IndexOf(AName))));
end;

function TNamedVoiceSession.CopyContract(const AName: String): TProviderContract;
begin
  Result := CopyProviderContract(FContracts[IndexOf(AName)]);
end;

function TNamedVoiceSession.TryReplaceProvider(const AName: String;
  const AModel: TWfcSequenceModel; const AContract: TProviderContract;
  const ASeed: TGraphSeed; var AGenerated: TWfcMusicVoicesGenerated;
  out AReport: TLayerModelReplacementReport;
  out AProof: TWfcMusicVoicesValidationReport): Boolean;
var
  LIndex: Integer;
  LReplaced: Integer;
  LCell: Integer;
  LActive: array of Boolean;
  LConfig: TWfcMusicVoicesGraphConfig;
  LOldConfig: TWfcMusicVoicesGraphConfig;
  LOldGraph: TGraph;
  LOptions: TVoiceSessionOptions;
  LNames: TLayerNames;
  LContracts: TProviderContracts;
  LCandidate: TNamedVoiceSession;
  LPublished: TWfcMusicVoicesGenerated;
begin
  AReport := Default(TLayerModelReplacementReport);
  AReport.ReplacedLayerIndex := -1;
  AProof := Default(TWfcMusicVoicesValidationReport);
  if Length(FAccepted.Layers) = 0 then
  begin
    raise EAudio.Create('Provider replacement requires an accepted named voice result');
  end;
  LReplaced := IndexOf(AName);
  ValidateProviderContract(AModel, AContract);
  RequireCompatibleProvider(FContracts[LReplaced], AContract);
  AReport.ReplacedLayerIndex := LReplaced;
  LConfig := CopyWfcMusicVoicesGraphConfig(FConfig);
  case LReplaced of
    0: LConfig.HarmonyModel := AModel;
    1: LConfig.RhythmModel := AModel;
  else
    LConfig.Voices[LReplaced - 2].Model := AModel;
  end;
  LNames := Copy(FNames, 2, Length(FNames) - 2);
  LContracts := Copy(FContracts);
  LContracts[LReplaced] := CopyProviderContract(AContract);
  LOptions := FOptions;
  LOptions.Seed := ASeed;
  LCandidate := TNamedVoiceSession.Create(LConfig, LNames, LOptions, LContracts);
  try
    LCandidate.FGraph.ResolveRegenerationScope([WfcMusicVoicesPassLabel(LReplaced)],
      AReport.RootLayerIndices, AReport.AffectedLayerIndices);
    SetLength(LActive, Length(FNames));
    for LIndex in AReport.AffectedLayerIndices do
    begin
      if LIndex < Length(FNames) then
      begin
        LActive[LIndex] := True;
      end;
    end;
    for LIndex := 0 to High(FNames) do
    begin
      if LActive[LIndex] then
      begin
        LCandidate.SetConstraints(FNames[LIndex], FPending[LIndex]);
      end
      else
      begin
        LCandidate.SetConstraints(FNames[LIndex], FCommitted[LIndex]);
      end;
      LCandidate.ApplyMask(LIndex, LCandidate.FPending[LIndex]);
      if not LActive[LIndex] then
      begin
        SetLength(AReport.PreservedLayerIndices, Length(AReport.PreservedLayerIndices) + 1);
        AReport.PreservedLayerIndices[High(AReport.PreservedLayerIndices)] := LIndex;
        for LCell := 0 to FOptions.CellCount - 1 do
        begin
          LCandidate.FGraph.PassGraph[LIndex].SetAllowedValues(LCell, 0, 0,
            [FGraph.PassGraph[LIndex][LCell, 0, 0].Value]);
        end;
      end;
    end;
    Result := LCandidate.FGraph.TrySolveNegotiated(LCandidate.NegotiationOptions, AReport.Search);
    if not Result then
    begin
      Exit;
    end;
    for LIndex in AReport.PreservedLayerIndices do
    begin
      LCandidate.ApplyMask(LIndex, FCommitted[LIndex]);
    end;
    LCandidate.Publish(AReport.AffectedLayerIndices, LPublished, AProof);
    for LIndex in AReport.PreservedLayerIndices do
    begin
      for LCell := 0 to FOptions.CellCount - 1 do
      begin
        if (LCandidate.FAccepted.Layers[LIndex].StateIndices[LCell] <>
          FAccepted.Layers[LIndex].StateIndices[LCell]) or
          (LCandidate.FAccepted.Layers[LIndex].Tokens[LCell] <> FAccepted.Layers[LIndex].Tokens[LCell]) then
        begin
          raise EAudio.Create('Candidate provider replacement changed an unrelated accepted state');
        end;
      end;
      LCandidate.FCommitted[LIndex] := CopyMask(FCommitted[LIndex]);
      LCandidate.FPending[LIndex] := CopyMask(FPending[LIndex]);
      LCandidate.FDirty[LIndex] := FDirty[LIndex];
    end;
    { All potentially failing work is complete. Swap ownership, then let candidate
      destruction release the old graph/models. Caller inputs always remain owned. }
    LOldGraph := FGraph;
    FGraph := LCandidate.FGraph;
    LCandidate.FGraph := LOldGraph;
    LOldConfig := FConfig;
    FConfig := LCandidate.FConfig;
    LCandidate.FConfig := LOldConfig;
    FBaseline := LCandidate.FBaseline;
    FHasBaseline := LCandidate.FHasBaseline;
    FCommitted := LCandidate.FCommitted;
    FPending := LCandidate.FPending;
    FDirty := LCandidate.FDirty;
    FAccepted := LCandidate.FAccepted;
    FContracts := LCandidate.FContracts;
    FOptions := LOptions;
    AGenerated := LPublished;
  finally
    LCandidate.Free;
  end;
end;

function TNamedVoiceSession.CopyProvider(const AName: String): TStyleProviderDescription;
var
  LIndex: Integer;
  LPair: Integer;
  LCount: Integer;
begin
  LIndex := IndexOf(AName);
  Result := Default(TStyleProviderDescription);
  Result.Name := AName;
  Result.TicksPerQuarter := FOptions.TicksPerQuarter;
  Result.Timing := sptUniform;
  Result.StepTicks := FOptions.StepTicks;
  Result.Scope.CellCount := FOptions.CellCount;
  Result.Scope.Extent := wsePrefix;
  if FOptions.RequireObservedEnd then
  begin
    Result.Scope.Extent := wseWhole;
  end;
  case LIndex of
    0: Result.Vocabulary := spvHarmony;
    1:
    begin
      Result.Vocabulary := spvRhythm;
      Result.RoleOrder := Copy(FNames, 2, Length(FNames) - 2);
    end;
  else
    Result.Vocabulary := spvVoice;
    Result.RoleId := AName;
    Result.PitchIdentity := spiAbsoluteMidi;
    Result.MinimumPitch := FConfig.Voices[LIndex - 2].MinPitch;
    Result.MaximumPitch := FConfig.Voices[LIndex - 2].MaxPitch;
    SetLength(Result.Dependencies, 2);
    Result.Dependencies[0].Name := 'harmony';
    Result.Dependencies[1].Name := 'rhythm';
    for LPair := 0 to High(FConfig.PairConstraints) do
    begin
      if FConfig.PairConstraints[LPair].UpperVoice = LIndex - 2 then
      begin
        LCount := Length(Result.Dependencies);
        SetLength(Result.Dependencies, LCount + 1);
        Result.Dependencies[LCount].Name :=
          FNames[FConfig.PairConstraints[LPair].LowerVoice + 2];
      end;
    end;
  end;
  Result.Choices := CopyStyleProviderChoices(WfcMusicVoicesModelAt(FConfig, LIndex),
    Result.Vocabulary);
end;

procedure TNamedVoiceSession.SetConstraints(const AName: String;
  const AMask: TWfcSequenceTokenConstraints);
var
  LIndex: Integer;
  LItem: Integer;
  LOther: Integer;
begin
  LIndex := IndexOf(AName);
  if Length(AMask) > FOptions.CellCount then
  begin
    raise EAudio.Create('Too many voice mask positions');
  end;
  for LItem := 0 to High(AMask) do
  begin
    if Length(AMask[LItem].AllowedTokens) >
      WfcMusicVoicesModelAt(FConfig, LIndex).PublicTokenCount then
    begin
      raise EAudio.Create('Voice mask exceeds the vocabulary size');
    end;
    for LOther := 0 to LItem - 1 do
    begin
      if AMask[LItem].Position = AMask[LOther].Position then
      begin
        raise EAudio.Create('Duplicate voice mask position');
      end;
    end;
  end;
  ValidateSequenceTokenConstraints(WfcMusicVoicesModelAt(FConfig, LIndex),
    FOptions.CellCount, AMask);
  FPending[LIndex] := CopyMask(AMask);
  FDirty[LIndex] := True;
end;

function TNamedVoiceSession.CopyConstraints(const AName: String): TWfcSequenceTokenConstraints;
begin
  Result := CopyMask(FPending[IndexOf(AName)]);
end;

function TNamedVoiceSession.HasPending(const AName: String): Boolean;
begin
  Result := FDirty[IndexOf(AName)];
end;

function TNamedVoiceSession.CopyAccepted: TWfcMusicVoicesGenerated;
begin
  Result := CopyGenerated(FAccepted);
end;

procedure TNamedVoiceSession.ApplyMask(const AIndex: Integer;
  const AMask: TWfcSequenceTokenConstraints);
var
  LCell: Integer;
  LPass: TGraph;
begin
  LPass := FGraph.PassGraph[AIndex];
  for LCell := 0 to FOptions.CellCount - 1 do
  begin
    LPass.ClearAllowedValues(LCell, 0, 0);
    if FHasBaseline[AIndex][LCell] then
    begin
      LPass.SetAllowedValues(LCell, 0, 0, FBaseline[AIndex][LCell]);
    end;
  end;
  IntersectSequenceTokenConstraints(WfcMusicVoicesModelAt(FConfig, AIndex), LPass, AMask);
end;

function TNamedVoiceSession.NegotiationOptions: TGraphNegotiationOptions;
begin
  Result := DefaultGraphNegotiationOptions;
  Result.SolveOptions.MaxBacktracks := FOptions.MaxBacktracks;
  Result.MaxPassBacktracks := FOptions.MaxPassBacktracks;
end;

procedure TNamedVoiceSession.Publish(const AActive: TGraphPassIndices;
  var AGenerated: TWfcMusicVoicesGenerated;
  out AProof: TWfcMusicVoicesValidationReport);
var
  LCandidate: TWfcMusicVoicesGenerated;
  LOutput: TWfcMusicVoicesGenerated;
  LIndex: Integer;
begin
  if not CaptureSolvedWfcMusicVoices(FConfig, FGraph, FBoundaries, LCandidate, AProof) then
  begin
    raise EAudio.Create('Solved voice graph failed its independent musical/path proof: ' +
      AProof.Issue.Detail);
  end;
  LOutput := CopyGenerated(LCandidate);
  for LIndex in AActive do
  begin
    if LIndex < Length(FNames) then
    begin
      FCommitted[LIndex] := CopyMask(FPending[LIndex]);
      FDirty[LIndex] := False;
    end;
  end;
  FAccepted := LCandidate;
  AGenerated := LOutput;
end;

function TNamedVoiceSession.TryGenerate(var AGenerated: TWfcMusicVoicesGenerated;
  out AReport: TGraphNegotiationReport;
  out AProof: TWfcMusicVoicesValidationReport): Boolean;
var
  LActive: TGraphPassIndices;
  LIndex: Integer;
begin
  AReport := Default(TGraphNegotiationReport);
  AProof := Default(TWfcMusicVoicesValidationReport);
  if Length(FAccepted.Layers) <> 0 then
  begin
    raise EAudio.Create('Voice session already accepted; use named regeneration');
  end;
  Result := False;
  SetLength(LActive, Length(FNames));
  try
    for LIndex := 0 to High(FNames) do
    begin
      LActive[LIndex] := LIndex;
      ApplyMask(LIndex, FPending[LIndex]);
    end;
    Result := FGraph.TrySolveNegotiated(NegotiationOptions, AReport);
    if Result then
    begin
      Publish(LActive, AGenerated, AProof);
    end;
  finally
    if not Result then
    begin
      for LIndex := 0 to High(FNames) do
      begin
        ApplyMask(LIndex, FCommitted[LIndex]);
      end;
    end;
  end;
end;

function TNamedVoiceSession.TryRegenerate(const ARoots: array of String;
  const ASeed: TGraphSeed; var AGenerated: TWfcMusicVoicesGenerated;
  out AReport: TGraphSelectiveNegotiationReport;
  out AProof: TWfcMusicVoicesValidationReport): Boolean;
var
  LLabels: TGraphPassLabels;
  LRoots: TGraphPassIndices;
  LActive: TGraphPassIndices;
  LIndex: Integer;
begin
  AReport := Default(TGraphSelectiveNegotiationReport);
  AProof := Default(TWfcMusicVoicesValidationReport);
  if (Length(FAccepted.Layers) = 0) or (Length(ARoots) < 1) or
    (Length(ARoots) > MaximumLearnedLayers) then
  begin
    raise EAudio.Create('Voice regeneration requires acceptance and 1..8 named roots');
  end;
  SetLength(LLabels, Length(ARoots));
  for LIndex := 0 to High(ARoots) do
  begin
    LLabels[LIndex] := WfcMusicVoicesPassLabel(IndexOf(ARoots[LIndex]));
  end;
  FGraph.ResolveRegenerationScope(LLabels, LRoots, LActive);
  Result := False;
  try
    for LIndex in LActive do
    begin
      if LIndex < Length(FNames) then
      begin
        ApplyMask(LIndex, FPending[LIndex]);
      end;
    end;
    FGraph.Seed := ASeed;
    Result := FGraph.TryRegenerateNegotiatedFrom(LLabels, NegotiationOptions, AReport);
    if Result then
    begin
      Publish(LActive, AGenerated, AProof);
    end;
  finally
    if not Result then
    begin
      for LIndex in LActive do
      begin
        if LIndex < Length(FNames) then
        begin
          ApplyMask(LIndex, FCommitted[LIndex]);
        end;
      end;
    end;
  end;
end;

function VoiceChoiceTokens(const AModel: TWfcSequenceModel;
  const AGuide: TWfcMusicVoiceCell; const ARequirePitch,
  ARequirePitchClasses: Boolean): TWfcModelTokens;
var
  LTokens: TWfcModelTokens;
  LFrame: TWfcMusicEnsembleFrame;
  LIndex: Integer;
  LTone: Integer;
  LMatches: Boolean;
  LGuideFrame: TWfcMusicEnsembleFrame;
  LGuideClasses: UTF8String;
begin
  if (AModel = nil) or (AModel.PublicTokenCount > 4096) or
    (Length(AGuide.Tones) > 4096) then
  begin
    raise EAudio.Create('Voice choices require a bounded model');
  end;
  WfcIndependentVoiceCapacities([AModel]);
  LTokens := nil;
  LGuideFrame := Default(TWfcMusicEnsembleFrame);
  SetLength(LGuideFrame.Voices, 1);
  LGuideFrame.Voices[0] := AGuide;
  LGuideClasses := EncodeWfcMusicPitchClassSet(
    ProjectWfcMusicEnsembleFrameToPitchClassSet(LGuideFrame, 12));
  for LIndex := 0 to AModel.PublicTokenCount - 1 do
  begin
    LFrame := DecodeWfcMusicEnsembleFrame(AModel.PublicTokenAt(LIndex));
    if Length(LFrame.Voices) <> 1 then
    begin
      raise EAudio.Create('Voice choices require singleton voice frames');
    end;
    LMatches := (LFrame.Voices[0].Action = AGuide.Action) and
      (Length(LFrame.Voices[0].Tones) = Length(AGuide.Tones));
    if LMatches and ARequirePitchClasses then
    begin
      LMatches := EncodeWfcMusicPitchClassSet(
        ProjectWfcMusicEnsembleFrameToPitchClassSet(LFrame, 12)) = LGuideClasses;
    end;
    if LMatches then
    begin
      for LTone := 0 to High(AGuide.Tones) do
      begin
        if (LFrame.Voices[0].Tones[LTone].Velocity <> AGuide.Tones[LTone].Velocity) or
          (ARequirePitch and (LFrame.Voices[0].Tones[LTone].Pitch <> AGuide.Tones[LTone].Pitch)) then
        begin
          LMatches := False;
          Break;
        end;
      end;
    end;
    if LMatches then
    begin
      SetLength(LTokens, Length(LTokens) + 1);
      LTokens[High(LTokens)] := AModel.PublicTokenAt(LIndex);
    end;
  end;
  Result := LTokens;
end;

end.
