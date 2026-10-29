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
  pythian.progress,
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
  TVoicePreferences = array of TLayerTokenPreferences;
  { Detached pending-state flags prepared with the accepted music snapshot. }
  TVoiceDirtyFlags = array of Boolean;
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
    FPreferences: TVoicePreferences;
    FCommittedPreferences: TVoicePreferences;
    FDirty: TVoiceDirtyFlags;
    FBusy: Boolean;
    FAccepted: TWfcMusicVoicesGenerated;
    FContracts: TProviderContracts;
    procedure CheckIdle;
    function IndexOf(const AName: String): Integer;
    function NegotiationOptions: TGraphNegotiationOptions;
    procedure ApplyMask(const AIndex: Integer;
      const AMask: TWfcSequenceTokenConstraints;
      const AProgress: TWorkProgressCallback = nil);
  public
    constructor Create(const AConfig: TWfcMusicVoicesGraphConfig;
      const ARoleNames: array of String; const AOptions: TVoiceSessionOptions;
      const AContracts: TProviderContracts = nil;
      const AProgress: TWorkProgressCallback = nil);
    destructor Destroy; override;
    function ProviderCount: Integer;
    function ProviderName(const AIndex: Integer): String;
    function ProofPassCount: Integer;
    function CopyProvider(const AName: String;
      const AProgress: TWorkProgressCallback = nil): TStyleProviderDescription;
    function CopyModel(const AName: String;
      const AProgress: TWorkProgressCallback = nil): TWfcSequenceModel;
    function CopyContract(const AName: String): TProviderContract;
    { Candidate graph/model replacement. Pending edits outside its actual
      dependency closure remain pending; accepted unrelated state stays exact. }
    function TryReplaceProvider(const AName: String; const AModel: TWfcSequenceModel;
      const AContract: TProviderContract; const ASeed: TGraphSeed;
      var AGenerated: TWfcMusicVoicesGenerated;
      out AReport: TLayerModelReplacementReport;
      out AProof: TWfcMusicVoicesValidationReport;
      const AProgress: TWorkProgressCallback = nil): Boolean;
    procedure SetConstraints(const AName: String;
      const AMask: TWfcSequenceTokenConstraints;
      const AProgress: TWorkProgressCallback = nil);
    function CopyConstraints(const AName: String;
      const AProgress: TWorkProgressCallback = nil): TWfcSequenceTokenConstraints;
    function HasPending(const AName: String): Boolean;
    procedure SetPreferences(const AName: String; const APreferences: TLayerTokenPreferences;
      const AProgress: TWorkProgressCallback = nil);
    function CopyPreferences(const AName: String;
      const AProgress: TWorkProgressCallback = nil): TLayerTokenPreferences;
    function CopyAccepted(const AProgress: TWorkProgressCallback = nil): TWfcMusicVoicesGenerated;
    { Borrowed progress; capture/copies/readiness run in the graph commit guard.
      Cancellation preserves accepted music, pending edits and caller output. }
    function TryGenerate(var AGenerated: TWfcMusicVoicesGenerated;
      out AReport: TGraphNegotiationReport;
      out AProof: TWfcMusicVoicesValidationReport;
      const AProgress: TWorkProgressCallback = nil): Boolean;
    function TryRegenerate(const ARoots: array of String; const ASeed: TGraphSeed;
      var AGenerated: TWfcMusicVoicesGenerated;
      out AReport: TGraphSelectiveNegotiationReport;
      out AProof: TWfcMusicVoicesValidationReport;
      const AProgress: TWorkProgressCallback = nil): Boolean;
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
  pythian.wfc.progress;

type
  TNamedVoicePublication = class;
  { The publication receiver is borrowed for exactly one solve/capture scope. }
  TObservedVoiceGraph = class(TGraph)
  protected
    function DoValidateCommit(out AFailedPassIndex,
      AFailedEntryIndex: Integer): Boolean; override;
  public
    Publication: TNamedVoicePublication;
  end;
  TNamedPreferenceChange = record
    Group: TGraphRuleGroup;
    Original: Integer;
    Preferred: Integer;
  end;
  TNamedPreferenceScope = class
  private
    FChanges: array of TNamedPreferenceChange;
    FApplied: Boolean;
  public
    constructor Create(const ASession: TNamedVoiceSession; const AActive: TGraphPassIndices;
      const AProgress: TWorkProgressCallback = nil);
    procedure UseOriginal(const AWork: TWfcObservedWork = nil);
    procedure UsePreferred(const AWork: TWfcObservedWork = nil);
    destructor Destroy; override;
  end;

{ Stages detached accepted/caller music and committed edit state before the
  graph accepts. Private replacement graphs may explicitly defer capture until
  their temporary preservation masks have been restored. }
  TNamedVoicePublication = class
  private
    FSession: TNamedVoiceSession;
    FGraph: TObservedVoiceGraph;
    FActive: TGraphPassIndices;
    FCallback: TWorkProgressCallback;
    FPreferences: TNamedPreferenceScope;
    FGuarded: Boolean;
    FCommitted: TVoiceMasks;
    FCommittedPreferences: TVoicePreferences;
    FDirty: TVoiceDirtyFlags;
  public
    Captured: TWfcMusicVoicesGenerated;
    CallerCopy: TWfcMusicVoicesGenerated;
    Proof: TWfcMusicVoicesValidationReport;
    constructor Create(const ASession: TNamedVoiceSession;
      const AActive: TGraphPassIndices; const AGuarded: Boolean;
      const AProgress: TWorkProgressCallback);
    destructor Destroy; override;
    procedure Capture;
    procedure Publish(var AGenerated: TWfcMusicVoicesGenerated);
  end;

procedure VisitVoice(const AWork: TWfcObservedWork); inline;
begin
  if AWork <> nil then
  begin
    AWork.Visit;
  end;
end;

constructor TNamedPreferenceScope.Create(const ASession: TNamedVoiceSession;
  const AActive: TGraphPassIndices; const AProgress: TWorkProgressCallback);
var
  LIndex: Integer;
  LCount: Integer;
  LPass: TGraph;
  LModel: TWfcSequenceModel;
  LPreference: TLayerTokenPreference;
  LValue: TGraphValue;
  LDomain: TGraphValues;
  LHadDomain: Boolean;
  LWork: TWfcObservedWork;
  LBridge: TWfcSolveProgressBridge;
  LMask: TWfcSequenceTokenConstraints;
begin
  inherited Create;
  LWork := TWfcObservedWork.Create(AProgress, 'voice_weight_visits');
  try
    for LIndex in AActive do
    begin
      LWork.Visit;
      if (LIndex >= ASession.ProviderCount) or
        (Length(ASession.FPreferences[LIndex]) = 0) then
      begin
        Continue;
      end;
      LPass := ASession.FGraph.PassGraph[LIndex];
      LModel := WfcMusicVoicesModelAt(ASession.FConfig, LIndex);
      LBridge := TWfcSolveProgressBridge.Create(AProgress, LIndex + 1);
      try
        LHadDomain := LPass.HasAllowedValues(0, 0, 0);
        LDomain := LPass.CopyAllowedValues(0, 0, 0);
        try
          for LPreference in ASession.FPreferences[LIndex] do
          begin
            LWork.Visit;
            LPass.ClearAllowedValues(0, 0, 0);
            SetLength(LMask, 1);
            LMask[0].Position := 0;
            SetLength(LMask[0].AllowedTokens, 1);
            LMask[0].AllowedTokens[0] := LPreference.Token;
            IntersectSequenceTokenConstraints(LModel, LPass, LMask,
              LBridge.SequenceWorkObserver());
            for LValue in LPass.CopyAllowedValues(0, 0, 0) do
            begin
              LCount := Length(FChanges);
              SetLength(FChanges, LCount + 1);
              FChanges[LCount].Group := LPass.Rules[LValue];
              FChanges[LCount].Original := FChanges[LCount].Group.Weight;
              FChanges[LCount].Preferred := Integer(Int64(FChanges[LCount].Original) *
                LPreference.Multiplier);
              LWork.Visit;
            end;
          end;
        finally
          LPass.ClearAllowedValues(0, 0, 0);
          if LHadDomain then
          begin
            LPass.SetAllowedValues(0, 0, 0, LDomain);
          end;
        end;
      finally
        LBridge.Free;
      end;
    end;
    UsePreferred(LWork);
    LWork.Finish;
  finally
    LWork.Free;
  end;
end;

procedure TNamedPreferenceScope.UsePreferred(const AWork: TWfcObservedWork);
var
  LIndex: Integer;
begin
  FApplied := True;
  for LIndex := 0 to High(FChanges) do
  begin
    FChanges[LIndex].Group.Weight := FChanges[LIndex].Preferred;
    VisitVoice(AWork);
  end;
end;

procedure TNamedPreferenceScope.UseOriginal(const AWork: TWfcObservedWork);
var
  LIndex: Integer;
begin
  for LIndex := 0 to High(FChanges) do
  begin
    FChanges[LIndex].Group.Weight := FChanges[LIndex].Original;
    VisitVoice(AWork);
  end;
  FApplied := False;
end;

destructor TNamedPreferenceScope.Destroy;
begin
  if FApplied then
  begin
    UseOriginal;
  end;
  inherited Destroy;
end;

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

function CopyMask(const AMask: TWfcSequenceTokenConstraints;
  const AProgress: TWorkProgressCallback = nil;
  const APass: Integer = 0): TWfcSequenceTokenConstraints;
var
  LCandidate: TWfcSequenceTokenConstraints;
  LIndex: Integer;
  LToken: Integer;
  LWork: TWfcObservedWork;
begin
  LWork := TWfcObservedWork.Create(AProgress, 'voice_mask_copy_visits', APass);
  try
    SetLength(LCandidate, Length(AMask));
    for LIndex := 0 to High(AMask) do
    begin
      LCandidate[LIndex].Position := AMask[LIndex].Position;
      SetLength(LCandidate[LIndex].AllowedTokens, Length(AMask[LIndex].AllowedTokens));
      for LToken := 0 to High(AMask[LIndex].AllowedTokens) do
      begin
        LCandidate[LIndex].AllowedTokens[LToken] := AMask[LIndex].AllowedTokens[LToken];
        LWork.Visit;
      end;
      LWork.Visit;
    end;
    LWork.Finish;
    Result := LCandidate;
  finally
    LWork.Free;
  end;
end;

function CopyVoicePreferences(const AValue: TLayerTokenPreferences;
  const AProgress: TWorkProgressCallback = nil;
  const APass: Integer = 0): TLayerTokenPreferences;
var
  LCandidate: TLayerTokenPreferences;
  LIndex: Integer;
  LWork: TWfcObservedWork;
begin
  LWork := TWfcObservedWork.Create(AProgress, 'voice_preference_copy_visits', APass);
  try
    SetLength(LCandidate, Length(AValue));
    for LIndex := 0 to High(AValue) do
    begin
      LCandidate[LIndex] := AValue[LIndex];
      LWork.Visit;
    end;
    LWork.Finish;
    Result := LCandidate;
  finally
    LWork.Free;
  end;
end;

function CopyGenerated(const AValue: TWfcMusicVoicesGenerated;
  const AProgress: TWorkProgressCallback = nil): TWfcMusicVoicesGenerated;
var
  LCandidate: TWfcMusicVoicesGenerated;
  LIndex: Integer;
  LItem: Integer;
  LVoice: Integer;
  LTone: Integer;
  LWork: TWfcObservedWork;
begin
  LWork := TWfcObservedWork.Create(AProgress, 'voice_copy_generated_visits');
  try
    LCandidate := Default(TWfcMusicVoicesGenerated);
    SetLength(LCandidate.Layers, Length(AValue.Layers));
    for LIndex := 0 to High(AValue.Layers) do
    begin
      LCandidate.Layers[LIndex] := AValue.Layers[LIndex];
      LCandidate.Layers[LIndex].Tokens := nil;
      LCandidate.Layers[LIndex].StateIndices := nil;
      SetLength(LCandidate.Layers[LIndex].Tokens, Length(AValue.Layers[LIndex].Tokens));
      for LItem := 0 to High(AValue.Layers[LIndex].Tokens) do
      begin
        LCandidate.Layers[LIndex].Tokens[LItem] := AValue.Layers[LIndex].Tokens[LItem];
        LWork.Visit;
      end;
      SetLength(LCandidate.Layers[LIndex].StateIndices, Length(AValue.Layers[LIndex].StateIndices));
      for LItem := 0 to High(AValue.Layers[LIndex].StateIndices) do
      begin
        LCandidate.Layers[LIndex].StateIndices[LItem] := AValue.Layers[LIndex].StateIndices[LItem];
        LWork.Visit;
      end;
      LWork.Visit;
    end;
    SetLength(LCandidate.Frames, Length(AValue.Frames));
    for LIndex := 0 to High(AValue.Frames) do
    begin
      LCandidate.Frames[LIndex] := AValue.Frames[LIndex];
      LCandidate.Frames[LIndex].Voices := nil;
      SetLength(LCandidate.Frames[LIndex].Voices, Length(AValue.Frames[LIndex].Voices));
      for LVoice := 0 to High(AValue.Frames[LIndex].Voices) do
      begin
        LCandidate.Frames[LIndex].Voices[LVoice] := AValue.Frames[LIndex].Voices[LVoice];
        LCandidate.Frames[LIndex].Voices[LVoice].Tones := nil;
        SetLength(LCandidate.Frames[LIndex].Voices[LVoice].Tones,
          Length(AValue.Frames[LIndex].Voices[LVoice].Tones));
        for LTone := 0 to High(AValue.Frames[LIndex].Voices[LVoice].Tones) do
        begin
          LCandidate.Frames[LIndex].Voices[LVoice].Tones[LTone] :=
            AValue.Frames[LIndex].Voices[LVoice].Tones[LTone];
          LWork.Visit;
        end;
        LWork.Visit;
      end;
      LWork.Visit;
    end;
    SetLength(LCandidate.Coverage, Length(AValue.Coverage));
    for LIndex := 0 to High(AValue.Coverage) do
    begin
      LCandidate.Coverage[LIndex] := AValue.Coverage[LIndex];
      LCandidate.Coverage[LIndex].Suppliers := nil;
      SetLength(LCandidate.Coverage[LIndex].Suppliers, Length(AValue.Coverage[LIndex].Suppliers));
      for LItem := 0 to High(AValue.Coverage[LIndex].Suppliers) do
      begin
        LCandidate.Coverage[LIndex].Suppliers[LItem] := AValue.Coverage[LIndex].Suppliers[LItem];
        LWork.Visit;
      end;
      LWork.Visit;
    end;
    LWork.Finish;
    Result := LCandidate;
  finally
    LWork.Free;
  end;
end;

constructor TNamedVoicePublication.Create(const ASession: TNamedVoiceSession;
  const AActive: TGraphPassIndices; const AGuarded: Boolean;
  const AProgress: TWorkProgressCallback);
begin
  inherited Create;
  FSession := ASession;
  if not (ASession.FGraph is TObservedVoiceGraph) then
  begin
    raise EAudio.Create('Voice publication requires its owned commit graph');
  end;
  FGraph := TObservedVoiceGraph(ASession.FGraph);
  if FGraph.Publication <> nil then
  begin
    raise EAudio.Create('Voice publication cannot be re-entered');
  end;
  FActive := Copy(AActive);
  FCallback := AProgress;
  FGuarded := AGuarded;
  FPreferences := TNamedPreferenceScope.Create(ASession, AActive, AProgress);
  FGraph.Publication := Self;
  ReportWork(FCallback, 'voice_publication_ready', wuItems, 0, 1);
end;

destructor TNamedVoicePublication.Destroy;
begin
  if (FGraph <> nil) and (FGraph.Publication = Self) then
  begin
    FGraph.Publication := nil;
  end;
  FPreferences.Free;
  inherited Destroy;
end;

procedure TNamedVoicePublication.Capture;
var
  LIndex: Integer;
  LWork: TWfcObservedWork;
  LBridge: TWfcSolveProgressBridge;
begin
  LWork := nil;
  LBridge := nil;
  try
    LWork := TWfcObservedWork.Create(FCallback, 'voice_capture_weight_visits');
    FPreferences.UseOriginal(LWork);
    LWork.Finish;
    FreeAndNil(LWork);
    LBridge := TWfcSolveProgressBridge.Create(FCallback);
    if not CaptureSolvedWfcMusicVoices(FSession.FConfig, FGraph,
      FSession.FBoundaries, Captured, Proof, LBridge.PreparationWorkObserver()) then
    begin
      raise EAudio.Create('Solved voice graph failed its independent musical/path proof: ' +
        Proof.Issue.Detail);
    end;
    CallerCopy := CopyGenerated(Captured, FCallback);
    FCommitted := Copy(FSession.FCommitted);
    FCommittedPreferences := Copy(FSession.FCommittedPreferences);
    FDirty := Copy(FSession.FDirty);
    LWork := TWfcObservedWork.Create(FCallback, 'voice_commit_visits');
    for LIndex in FActive do
    begin
      if LIndex < Length(FSession.FNames) then
      begin
        FCommitted[LIndex] := CopyMask(FSession.FPending[LIndex], FCallback, LIndex + 1);
        FCommittedPreferences[LIndex] :=
          CopyVoicePreferences(FSession.FPreferences[LIndex], FCallback, LIndex + 1);
        FDirty[LIndex] := False;
      end;
      LWork.Visit;
    end;
    LWork.Finish;
    ReportWork(FCallback, 'voice_publication_ready', wuItems, 1, 1);
  finally
    { No callbacks while restoring a rejected attempt or unwinding an observer. }
    FPreferences.UsePreferred;
    LBridge.Free;
    LWork.Free;
  end;
end;

procedure TNamedVoicePublication.Publish(var AGenerated: TWfcMusicVoicesGenerated);
begin
  { Only ownership assignments remain after graph acceptance. }
  FSession.FCommitted := FCommitted;
  FSession.FCommittedPreferences := FCommittedPreferences;
  FSession.FDirty := FDirty;
  FSession.FAccepted := Captured;
  AGenerated := CallerCopy;
end;

function TObservedVoiceGraph.DoValidateCommit(out AFailedPassIndex,
  AFailedEntryIndex: Integer): Boolean;
begin
  Result := inherited DoValidateCommit(AFailedPassIndex, AFailedEntryIndex);
  if Result and (Publication <> nil) and Publication.FGuarded then
  begin
    Publication.Capture;
  end;
end;

procedure TNamedVoiceSession.CheckIdle;
begin
  if FBusy then
  begin
    raise EAudio.Create('Voice operation cannot be re-entered');
  end;
end;

constructor TNamedVoiceSession.Create(const AConfig: TWfcMusicVoicesGraphConfig;
  const ARoleNames: array of String; const AOptions: TVoiceSessionOptions;
  const AContracts: TProviderContracts; const AProgress: TWorkProgressCallback);
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
  LProgressBridge: TWfcSolveProgressBridge;
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
  LProgressBridge := TWfcSolveProgressBridge.Create(AProgress);
  try
    WfcIndependentVoiceCapacities(LModels, AProgress);
    ValidateWfcMusicVoicesGraphConfig(AConfig,
      WfcPreparationWorkObserver(LProgressBridge));
    FOptions := AOptions;
    FConfig := CopyWfcMusicVoicesGraphConfig(AConfig,
      WfcPreparationWorkObserver(LProgressBridge));
    { Never own caller pointers, including when cloning a later model fails. }
    FConfig.HarmonyModel := nil;
    FConfig.RhythmModel := nil;
    for LIndex := 0 to High(FConfig.Voices) do
    begin
      FConfig.Voices[LIndex].Model := nil;
    end;
    ReportWork(AProgress, 'voice_session_clone_models', wuItems, 0, Length(FNames));
    for LIndex := 0 to High(FNames) do
    begin
      LModel := CloneWfcSequenceModel(WfcMusicVoicesModelAt(AConfig, LIndex), AProgress);
      case LIndex of
        0: FConfig.HarmonyModel := LModel;
        1: FConfig.RhythmModel := LModel;
      else
        FConfig.Voices[LIndex - 2].Model := LModel;
      end;
      ReportWork(AProgress, 'voice_session_clone_models', wuItems,
        LIndex + 1, Length(FNames), LIndex + 1);
    end;
    SetLength(FBoundaries, Length(FNames));
    for LIndex := 0 to High(FBoundaries) do
    begin
      FBoundaries[LIndex] := MakeWfcSequenceInitialSegmentBoundary(AOptions.RequireObservedEnd);
    end;
    FGraph := BuildWfcMusicVoicesSegmentGraph(FConfig, AOptions.CellCount,
      AOptions.Seed, FBoundaries, WfcPreparationWorkObserver(LProgressBridge),
      TObservedVoiceGraph);
    SetLength(FBaseline, Length(FNames));
    SetLength(FHasBaseline, Length(FNames));
    SetLength(FPending, Length(FNames));
    SetLength(FCommitted, Length(FNames));
    SetLength(FPreferences, Length(FNames));
    SetLength(FCommittedPreferences, Length(FNames));
    SetLength(FDirty, Length(FNames));
    for LIndex := 0 to High(FNames) do
    begin
      ReportWork(AProgress, 'voice_session_snapshot_cells', wuItems,
        0, AOptions.CellCount, LIndex + 1);
      LPass := FGraph.PassGraph[LIndex];
      SetLength(FBaseline[LIndex], AOptions.CellCount);
      SetLength(FHasBaseline[LIndex], AOptions.CellCount);
      for LCell := 0 to AOptions.CellCount - 1 do
      begin
        FHasBaseline[LIndex][LCell] := LPass.HasAllowedValues(LCell, 0, 0);
        FBaseline[LIndex][LCell] := LPass.CopyAllowedValues(LCell, 0, 0);
        if ((LCell + 1) mod 64 = 0) or (LCell + 1 = AOptions.CellCount) then
        begin
          ReportWork(AProgress, 'voice_session_snapshot_cells', wuItems,
            LCell + 1, AOptions.CellCount, LIndex + 1);
        end;
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
      LExpected := ProviderContractFromDescription(
        CopyProvider(FNames[LIndex], AProgress), LDomain);
      FContracts[LIndex] := LExpected;
      if Length(AContracts) <> 0 then
      begin
        ValidateProviderContract(WfcMusicVoicesModelAt(FConfig, LIndex),
          AContracts[LIndex], nil, nil, AProgress);
        RequireCompatibleProvider(LExpected, AContracts[LIndex], AProgress);
        FContracts[LIndex] := CopyProviderContract(AContracts[LIndex]);
      end;
    end;
    ReportWork(AProgress, 'voice_session_ready', wuItems, 1, 1);
  finally
    LProgressBridge.Free;
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

function TNamedVoiceSession.CopyModel(const AName: String;
  const AProgress: TWorkProgressCallback): TWfcSequenceModel;
begin
  Result := CloneWfcSequenceModel(WfcMusicVoicesModelAt(FConfig, IndexOf(AName)), AProgress);
end;

function TNamedVoiceSession.CopyContract(const AName: String): TProviderContract;
begin
  Result := CopyProviderContract(FContracts[IndexOf(AName)]);
end;

function TNamedVoiceSession.TryReplaceProvider(const AName: String;
  const AModel: TWfcSequenceModel; const AContract: TProviderContract;
  const ASeed: TGraphSeed; var AGenerated: TWfcMusicVoicesGenerated;
  out AReport: TLayerModelReplacementReport;
  out AProof: TWfcMusicVoicesValidationReport;
  const AProgress: TWorkProgressCallback): Boolean;
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
  LPublication: TNamedVoicePublication;
  LWork: TWfcObservedWork;
begin
  CheckIdle;
  AReport := Default(TLayerModelReplacementReport);
  AReport.ReplacedLayerIndex := -1;
  AProof := Default(TWfcMusicVoicesValidationReport);
  if Length(FAccepted.Layers) = 0 then
  begin
    raise EAudio.Create('Provider replacement requires an accepted named voice result');
  end;
  LReplaced := IndexOf(AName);
  Result := False;
  LCandidate := nil;
  LPublication := nil;
  LWork := nil;
  FBusy := True;
  try
    LWork := TWfcObservedWork.Create(AProgress, 'voice_replacement_visits');
    ValidateProviderContract(AModel, AContract, nil, nil, AProgress);
    RequireCompatibleProvider(FContracts[LReplaced], AContract, AProgress);
    AReport.ReplacedLayerIndex := LReplaced;
    LConfig := CopyWfcMusicVoicesGraphConfig(FConfig, LWork.PreparationWorkObserver());
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
    LCandidate := TNamedVoiceSession.Create(LConfig, LNames, LOptions, LContracts, AProgress);
    LCandidate.FGraph.ResolveRegenerationScope([WfcMusicVoicesPassLabel(LReplaced)],
      AReport.RootLayerIndices, AReport.AffectedLayerIndices);
    SetLength(LActive, Length(FNames));
    for LIndex in AReport.AffectedLayerIndices do
    begin
      if LIndex < Length(FNames) then
      begin
        LActive[LIndex] := True;
      end;
      LWork.Visit;
    end;
    for LIndex := 0 to High(FNames) do
    begin
      if LActive[LIndex] then
      begin
        LCandidate.SetConstraints(FNames[LIndex], FPending[LIndex], AProgress);
        LCandidate.SetPreferences(FNames[LIndex], FPreferences[LIndex], AProgress);
      end
      else
      begin
        LCandidate.SetConstraints(FNames[LIndex], FCommitted[LIndex], AProgress);
        LCandidate.SetPreferences(FNames[LIndex], FCommittedPreferences[LIndex], AProgress);
      end;
      LCandidate.ApplyMask(LIndex, LCandidate.FPending[LIndex], AProgress);
      if not LActive[LIndex] then
      begin
        SetLength(AReport.PreservedLayerIndices, Length(AReport.PreservedLayerIndices) + 1);
        AReport.PreservedLayerIndices[High(AReport.PreservedLayerIndices)] := LIndex;
        for LCell := 0 to FOptions.CellCount - 1 do
        begin
          LCandidate.FGraph.PassGraph[LIndex].SetAllowedValues(LCell, 0, 0,
            [FGraph.PassGraph[LIndex].Entry[LCell, 0, 0].Value]);
          LWork.Visit;
        end;
      end;
      LWork.Visit;
    end;
    LPublication := TNamedVoicePublication.Create(LCandidate,
      AReport.AffectedLayerIndices, False, AProgress);
    Result := LCandidate.FGraph.TrySolveNegotiated(LCandidate.NegotiationOptions,
      AReport.Search, LWork.SolveObserver());
    if not Result then
    begin
      Exit;
    end;
    { This graph is private. Restore its ordinary domains and original weights
      before the same independent proof used by live guarded publication. }
    LPublication.FPreferences.UseOriginal;
    for LIndex in AReport.PreservedLayerIndices do
    begin
      LCandidate.ApplyMask(LIndex, FCommitted[LIndex], AProgress);
    end;
    LPublication.Capture;
    LPublication.Publish(LPublished);
    AProof := LPublication.Proof;
    FreeAndNil(LPublication);
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
        LWork.Visit;
      end;
      LCandidate.FCommitted[LIndex] := CopyMask(FCommitted[LIndex], AProgress, LIndex + 1);
      LCandidate.FPending[LIndex] := CopyMask(FPending[LIndex], AProgress, LIndex + 1);
      LCandidate.FPreferences[LIndex] :=
        CopyVoicePreferences(FPreferences[LIndex], AProgress, LIndex + 1);
      LCandidate.FCommittedPreferences[LIndex] :=
        CopyVoicePreferences(FCommittedPreferences[LIndex], AProgress, LIndex + 1);
      LCandidate.FDirty[LIndex] := FDirty[LIndex];
      LWork.Visit;
    end;
    LWork.Finish;
    ReportWork(AProgress, 'voice_replacement_ready', wuItems, 1, 1);
    { No callbacks after this ownership swap. Candidate destruction releases the
      old graph/models; caller inputs and unrelated pending edits stay owned. }
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
    FPreferences := LCandidate.FPreferences;
    FCommittedPreferences := LCandidate.FCommittedPreferences;
    FDirty := LCandidate.FDirty;
    FAccepted := LCandidate.FAccepted;
    FContracts := LCandidate.FContracts;
    FOptions := LOptions;
    AGenerated := LPublished;
  finally
    LPublication.Free;
    LCandidate.Free;
    LWork.Free;
    FBusy := False;
  end;
end;

function TNamedVoiceSession.CopyProvider(const AName: String;
  const AProgress: TWorkProgressCallback): TStyleProviderDescription;
var
  LIndex: Integer;
  LPair: Integer;
  LCount: Integer;
  LCandidate: TStyleProviderDescription;
  LWork: TWfcObservedWork;
begin
  CheckIdle;
  LIndex := IndexOf(AName);
  LWork := nil;
  FBusy := True;
  try
    LWork := TWfcObservedWork.Create(AProgress, 'voice_provider_visits', LIndex + 1);
    LCandidate := Default(TStyleProviderDescription);
    LCandidate.Name := AName;
    LCandidate.Preferences := CopyVoicePreferences(FPreferences[LIndex], AProgress, LIndex + 1);
    LCandidate.TicksPerQuarter := FOptions.TicksPerQuarter;
    LCandidate.Timing := sptUniform;
    LCandidate.StepTicks := FOptions.StepTicks;
    LCandidate.Scope.CellCount := FOptions.CellCount;
    LCandidate.Scope.Extent := wsePrefix;
    if FOptions.RequireObservedEnd then
    begin
      LCandidate.Scope.Extent := wseWhole;
    end;
    case LIndex of
      0: LCandidate.Vocabulary := spvHarmony;
      1:
      begin
        LCandidate.Vocabulary := spvRhythm;
        LCandidate.RoleOrder := Copy(FNames, 2, Length(FNames) - 2);
      end;
    else
      LCandidate.Vocabulary := spvVoice;
      LCandidate.RoleId := AName;
      LCandidate.PitchIdentity := spiAbsoluteMidi;
      LCandidate.MinimumPitch := FConfig.Voices[LIndex - 2].MinPitch;
      LCandidate.MaximumPitch := FConfig.Voices[LIndex - 2].MaxPitch;
      SetLength(LCandidate.Dependencies, 2);
      LCandidate.Dependencies[0].Name := 'harmony';
      LCandidate.Dependencies[1].Name := 'rhythm';
      for LPair := 0 to High(FConfig.PairConstraints) do
      begin
        LWork.Visit;
        if FConfig.PairConstraints[LPair].UpperVoice = LIndex - 2 then
        begin
          LCount := Length(LCandidate.Dependencies);
          SetLength(LCandidate.Dependencies, LCount + 1);
          LCandidate.Dependencies[LCount].Name :=
            FNames[FConfig.PairConstraints[LPair].LowerVoice + 2];
        end;
      end;
    end;
    LCandidate.Choices := CopyStyleProviderChoices(WfcMusicVoicesModelAt(FConfig, LIndex),
      LCandidate.Vocabulary, AProgress);
    LWork.Finish;
    ReportWork(AProgress, 'voice_provider_ready', wuItems, 1, 1, LIndex + 1);
    Result := LCandidate;
  finally
    LWork.Free;
    FBusy := False;
  end;
end;

procedure TNamedVoiceSession.SetConstraints(const AName: String;
  const AMask: TWfcSequenceTokenConstraints; const AProgress: TWorkProgressCallback);
var
  LIndex: Integer;
  LItem: Integer;
  LOther: Integer;
  LCandidate: TWfcSequenceTokenConstraints;
  LWork: TWfcObservedWork;
begin
  CheckIdle;
  LIndex := IndexOf(AName);
  if Length(AMask) > FOptions.CellCount then
  begin
    raise EAudio.Create('Too many voice mask positions');
  end;
  LWork := nil;
  FBusy := True;
  try
    LWork := TWfcObservedWork.Create(AProgress, 'voice_constraint_visits', LIndex + 1);
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
        LWork.Visit;
      end;
      LWork.Visit;
    end;
    ValidateSequenceTokenConstraints(WfcMusicVoicesModelAt(FConfig, LIndex),
      FOptions.CellCount, AMask, LWork.SequenceWorkObserver());
    LCandidate := CopyMask(AMask, AProgress, LIndex + 1);
    LWork.Finish;
    ReportWork(AProgress, 'voice_constraints_ready', wuItems, 1, 1, LIndex + 1);
    FPending[LIndex] := LCandidate;
    FDirty[LIndex] := True;
  finally
    LWork.Free;
    FBusy := False;
  end;
end;

function TNamedVoiceSession.CopyConstraints(const AName: String;
  const AProgress: TWorkProgressCallback): TWfcSequenceTokenConstraints;
var
  LIndex: Integer;
begin
  CheckIdle;
  LIndex := IndexOf(AName);
  FBusy := True;
  try
    Result := CopyMask(FPending[LIndex], AProgress, LIndex + 1);
  finally
    FBusy := False;
  end;
end;

function TNamedVoiceSession.HasPending(const AName: String): Boolean;
begin
  Result := FDirty[IndexOf(AName)];
end;

procedure TNamedVoiceSession.SetPreferences(const AName: String;
  const APreferences: TLayerTokenPreferences; const AProgress: TWorkProgressCallback);
var
  LIndex: Integer;
  LOther: Integer;
  LState: Integer;
  LRole: Integer;
  LMultiplier: Integer;
  LTotal: Int64;
  LModel: TWfcSequenceModel;
  LCandidate: TLayerTokenPreferences;
  LWork: TWfcObservedWork;
begin
  CheckIdle;
  LRole := IndexOf(AName);
  LModel := WfcMusicVoicesModelAt(FConfig, LRole);
  LWork := nil;
  FBusy := True;
  try
    LWork := TWfcObservedWork.Create(AProgress, 'voice_preference_visits', LRole + 1);
    if Length(APreferences) > 0 then
    begin
      if (Length(APreferences) > MaximumLayerPreferences) or
        (Int64(LModel.StateCount) * LModel.StateCount * (LModel.Order + 1) *
          (Length(APreferences) + 1) > MaximumLayerPreferencePreparationWork) then
      begin
        raise EAudio.Create('Named preference count or preparation work exceeds budget');
      end;
      for LIndex := 0 to High(APreferences) do
      begin
        if (LModel.FindPublicToken(APreferences[LIndex].Token) < 0) or
          (APreferences[LIndex].Multiplier < 1) or
          (APreferences[LIndex].Multiplier > MaximumLayerPreferenceMultiplier) then
        begin
          raise EAudio.Create('Named preference requires a known token and multiplier in 1..1024');
        end;
        for LOther := 0 to LIndex - 1 do
        begin
          if APreferences[LOther].Token = APreferences[LIndex].Token then
          begin
            raise EAudio.Create('Duplicate named preference token');
          end;
          LWork.Visit;
        end;
        LWork.Visit;
      end;
      LTotal := 0;
      for LState := 0 to LModel.StateCount - 1 do
      begin
        LMultiplier := 1;
        for LIndex := 0 to High(APreferences) do
        begin
          if LModel.ProjectStateToken(LState) = APreferences[LIndex].Token then
          begin
            LMultiplier := APreferences[LIndex].Multiplier;
          end;
          LWork.Visit;
        end;
        Inc(LTotal, Int64(LModel.StateObservationCountAt(LState)) * LMultiplier);
        if LTotal > High(Integer) then
        begin
          raise EAudio.Create('Named preferred weight sum exceeds signed 32-bit budget');
        end;
        LWork.Visit;
      end;
    end;
    LCandidate := CopyVoicePreferences(APreferences, AProgress, LRole + 1);
    LWork.Finish;
    ReportWork(AProgress, 'voice_preferences_ready', wuItems, 1, 1, LRole + 1);
    FPreferences[LRole] := LCandidate;
    FDirty[LRole] := True;
  finally
    LWork.Free;
    FBusy := False;
  end;
end;

function TNamedVoiceSession.CopyPreferences(const AName: String;
  const AProgress: TWorkProgressCallback): TLayerTokenPreferences;
var
  LIndex: Integer;
begin
  CheckIdle;
  LIndex := IndexOf(AName);
  FBusy := True;
  try
    Result := CopyVoicePreferences(FPreferences[LIndex], AProgress, LIndex + 1);
  finally
    FBusy := False;
  end;
end;

function TNamedVoiceSession.CopyAccepted(
  const AProgress: TWorkProgressCallback): TWfcMusicVoicesGenerated;
begin
  CheckIdle;
  FBusy := True;
  try
    Result := CopyGenerated(FAccepted, AProgress);
  finally
    FBusy := False;
  end;
end;

procedure TNamedVoiceSession.ApplyMask(const AIndex: Integer;
  const AMask: TWfcSequenceTokenConstraints; const AProgress: TWorkProgressCallback);
var
  LCell: Integer;
  LPass: TGraph;
  LWork: TWfcObservedWork;
begin
  LPass := FGraph.PassGraph[AIndex];
  LWork := TWfcObservedWork.Create(AProgress, 'voice_mask_visits', AIndex + 1);
  try
    for LCell := 0 to FOptions.CellCount - 1 do
    begin
      LPass.ClearAllowedValues(LCell, 0, 0);
      if FHasBaseline[AIndex][LCell] then
      begin
        LPass.SetAllowedValues(LCell, 0, 0, FBaseline[AIndex][LCell]);
      end;
      LWork.Visit;
    end;
    IntersectSequenceTokenConstraints(WfcMusicVoicesModelAt(FConfig, AIndex),
      LPass, AMask, LWork.SequenceWorkObserver());
    LWork.Finish;
  finally
    LWork.Free;
  end;
end;

function TNamedVoiceSession.NegotiationOptions: TGraphNegotiationOptions;
begin
  Result := DefaultGraphNegotiationOptions;
  Result.SolveOptions.MaxBacktracks := FOptions.MaxBacktracks;
  Result.MaxPassBacktracks := FOptions.MaxPassBacktracks;
end;



function TNamedVoiceSession.TryGenerate(var AGenerated: TWfcMusicVoicesGenerated;
  out AReport: TGraphNegotiationReport; out AProof: TWfcMusicVoicesValidationReport;
  const AProgress: TWorkProgressCallback): Boolean;
var
  LActive: TGraphPassIndices;
  LIndex: Integer;
  LPublication: TNamedVoicePublication;
  LWork: TWfcObservedWork;
begin
  CheckIdle;
  AReport := Default(TGraphNegotiationReport);
  AProof := Default(TWfcMusicVoicesValidationReport);
  if Length(FAccepted.Layers) <> 0 then
  begin
    raise EAudio.Create('Voice session already accepted; use named regeneration');
  end;
  Result := False;
  LPublication := nil;
  LWork := nil;
  FBusy := True;
  try
    LWork := TWfcObservedWork.Create(AProgress, 'voice_generate_visits');
    SetLength(LActive, Length(FNames));
    for LIndex := 0 to High(FNames) do
    begin
      LActive[LIndex] := LIndex;
      ApplyMask(LIndex, FPending[LIndex], AProgress);
      LWork.Visit;
    end;
    LWork.Finish;
    LPublication := TNamedVoicePublication.Create(Self, LActive, True, AProgress);
    Result := FGraph.TrySolveNegotiated(NegotiationOptions, AReport, LWork.SolveObserver());
    if Result then
    begin
      LPublication.Publish(AGenerated);
    end;
  finally
    if LPublication <> nil then
    begin
      AProof := LPublication.Proof;
    end;
    LPublication.Free;
    LWork.Free;
    try
      if not Result then
      begin
        for LIndex := 0 to High(FNames) do
        begin
          ApplyMask(LIndex, FCommitted[LIndex]);
        end;
      end;
    finally
      FBusy := False;
    end;
  end;
end;

function TNamedVoiceSession.TryRegenerate(const ARoots: array of String;
  const ASeed: TGraphSeed; var AGenerated: TWfcMusicVoicesGenerated;
  out AReport: TGraphSelectiveNegotiationReport;
  out AProof: TWfcMusicVoicesValidationReport;
  const AProgress: TWorkProgressCallback): Boolean;
var
  LLabels: TGraphPassLabels;
  LRoots: TGraphPassIndices;
  LActive: TGraphPassIndices;
  LIndex: Integer;
  LPublication: TNamedVoicePublication;
  LWork: TWfcObservedWork;
begin
  CheckIdle;
  AReport := Default(TGraphSelectiveNegotiationReport);
  AProof := Default(TWfcMusicVoicesValidationReport);
  if (Length(FAccepted.Layers) = 0) or (Length(ARoots) < 1) or
    (Length(ARoots) > MaximumLearnedLayers) then
  begin
    raise EAudio.Create('Voice regeneration requires acceptance and 1..8 named roots');
  end;
  Result := False;
  LPublication := nil;
  LWork := nil;
  FBusy := True;
  try
    LWork := TWfcObservedWork.Create(AProgress, 'voice_regenerate_visits');
    SetLength(LLabels, Length(ARoots));
    for LIndex := 0 to High(ARoots) do
    begin
      LLabels[LIndex] := WfcMusicVoicesPassLabel(IndexOf(ARoots[LIndex]));
      LWork.Visit;
    end;
    FGraph.ResolveRegenerationScope(LLabels, LRoots, LActive);
    for LIndex in LActive do
    begin
      if LIndex < Length(FNames) then
      begin
        ApplyMask(LIndex, FPending[LIndex], AProgress);
      end;
      LWork.Visit;
    end;
    LWork.Finish;
    FGraph.Seed := ASeed;
    LPublication := TNamedVoicePublication.Create(Self, LActive, True, AProgress);
    Result := FGraph.TryRegenerateNegotiatedFrom(LLabels, NegotiationOptions, AReport,
      LWork.SolveObserver());
    if Result then
    begin
      LPublication.Publish(AGenerated);
    end;
  finally
    if LPublication <> nil then
    begin
      AProof := LPublication.Proof;
    end;
    LPublication.Free;
    LWork.Free;
    try
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
    finally
      FBusy := False;
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
