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
unit pythian.wfc.instrumental;

{$mode delphi}
{$H+}

interface

uses
  pythian.audio,
  pythian.progress,
  pythian.time,
  pythian.music,
  pythian.music.render,
  pythian.synth,
  pythian.instrument,
  pythian.bus,
  pythian.schedule,
  pythian.wfc.voices,
  pythian.wfc.layers,
  pythian.wfc.providers,
  pythian.wfc.percussion,
  pythian.wfc.musical.context,
  wfc,
  wfc_model,
  wfc_sequence,
  wfc_sequence_graph,
  wfc_music_voices_graph;

type
  TInstrumentalRole = record
    Name: String;
    InstrumentId: String;
    Instrument: TInstrument;
    OutputBus: Integer;
    IsPercussion: Boolean;
  end;
  TInstrumentalRoles = array of TInstrumentalRole;
  TInstrumentalOptions = record
    Session: TVoiceSessionOptions;
    SampleRate: Integer;
    Tempos: TTempoChanges;
    EffectTailFrames: Int64;
    MaterialOrigin: String;
    PercussionSeed: TGraphSeed;
  end;
  TInstrumentalReport = record
    ContextSolve: TGraphNegotiationReport;
    Solve: TGraphNegotiationReport;
    Proof: TWfcMusicVoicesValidationReport;
    PercussionSolve: TGraphNegotiationReport;
    FailedPass: String;
    Detail: String;
  end;

  { Big Boss: immutable finite musical plan, owning the real named-voice session
    and native note sequence. Instruments are borrowed during planning; planned
    tones still borrow their factories/automation/envelopes. Keep those resources
    alive through player creation; source factories follow their native lifetime.
    No recorded palette, grain selector, replacement solver or renderer. }
  TInstrumentalPlan = class
  private
    FSession: TNamedVoiceSession;
    FContext: TMusicalContextPlan;
    FDrums: TPercussionPlan;
    FOptions: TInstrumentalOptions;
    FRoles: TInstrumentalRoles;
    FNotes: TNoteSequence;
    FParts: array of TFrameTones;
    FFrameCount: Int64;
    FToneCount: Integer;
    constructor Create;
    procedure CheckRole(const AIndex: Integer);
    function GetSampleRate: Integer;
    function GetMaterialOrigin: String;
    procedure IncludePart(const AIndex: Integer; const ATones: TFrameTones);
    function IsDrumProvider(const AName: String): Boolean;
  public
    destructor Destroy; override;
    function RoleCount: Integer;
    { Binding metadata; Instrument is nil after planning to avoid retaining a
      pointer to an instrument the caller may already have released. }
    function RoleAt(const AIndex: Integer): TInstrumentalRole;
    function CopyGraph: TVoiceGraphPasses;
    function CopyProvider(const AName: String): TStyleProviderDescription;
    function CopyMusic: TWfcMusicVoicesGenerated;
    function CopyPercussionHits: TPercussionHits;
    function CopyPercussionPart(const AIndex: Integer): TPercussionPart;
    function CopyPassTokens(const AIndex: Integer): TWfcModelTokens;
    function CopyPassStates(const AIndex: Integer): TWfcSequenceStateIndices;
    function CopyModel(const AName: String): TWfcSequenceModel;
    function CopyConstraints(const AName: String): TWfcSequenceTokenConstraints;
    function CopyPreferences(const AName: String): TLayerTokenPreferences;
    function CopyNotes: TNoteSequence;
    function CopyPartTones(const AIndex: Integer): TFrameTones;
    { Fresh private scheduler, all notes admitted before return. It exclusively
      borrows the healthy matching-rate bus graph, but does not reset/process it
      during construction. A failed admission disposes only the candidate player.
      Each role uses its declared bus and its role index as scheduler group.
      Use one fresh bus graph per replay/parallel player. }
    function CreatePlayer(const AGraph: TBusGraph;
      const AVoiceLimit: Integer = MaximumScheduledVoices;
      const AWorkLimit: Integer = 1000000): TScheduledSynth;
    property SampleRate: Integer read GetSampleRate;
    property FrameCount: Int64 read FFrameCount;
    property ToneCount: Integer read FToneCount;
    property MaterialOrigin: String read GetMaterialOrigin;
  end;

function DefaultInstrumentalOptions: TInstrumentalOptions;
{ Complete constraints/preferences, indexed harmony, rhythm, then declared roles;
  empty arrays mean none. Uses a private candidate graph, projection and primary
  instrument planner. False reports actual solve/proof failure. Exceptions include
  malformed input and observer cancellation. Either preserves APlan exactly.
  Success replaces/frees the prior plan only after all planning/ready callbacks.
  Existing players own their scheduled voices; borrowed factory rules still apply.
  The observer must not mutate inputs, free APlan or reenter this transaction. }
function TryCreateInstrumentalPlan(const AConfig: TWfcMusicVoicesGraphConfig;
  const ARoles: TInstrumentalRoles; const AOptions: TInstrumentalOptions;
  const AMasks: TVoiceMasks; const APreferences: TVoicePreferences;
  var APlan: TInstrumentalPlan; out AReport: TInstrumentalReport;
  const AProgress: TWorkProgressCallback = nil;
  const APercussion: TPercussionDefinitions = nil;
  const AMusicalContext: TWfcSequenceModel = nil): Boolean;

implementation

uses
  SysUtils,
  pythian.wfc.music;

function DefaultInstrumentalOptions: TInstrumentalOptions;
begin
  Result := Default(TInstrumentalOptions);
  Result.Session := DefaultVoiceSessionOptions;
  Result.SampleRate := 44100;
  Result.PercussionSeed := 1741;
  SetLength(Result.Tempos, 1);
  Result.Tempos[0] := MakeTempoChange(0, 500000);
end;

constructor TInstrumentalPlan.Create;
begin
  inherited Create;
end;

destructor TInstrumentalPlan.Destroy;
begin
  FNotes.Free;
  FSession.Free;
  FContext.Free;
  FDrums.Free;
  inherited Destroy;
end;

function TInstrumentalPlan.GetSampleRate: Integer;
begin
  Result := FOptions.SampleRate;
end;

function TInstrumentalPlan.GetMaterialOrigin: String;
begin
  Result := FOptions.MaterialOrigin;
end;

procedure TInstrumentalPlan.CheckRole(const AIndex: Integer);
begin
  if (AIndex < 0) or (AIndex >= Length(FRoles)) then
  begin
    raise EAudio.Create('Instrumental role index out of range');
  end;
end;

function TInstrumentalPlan.RoleCount: Integer;
begin
  Result := Length(FRoles);
end;

function TInstrumentalPlan.RoleAt(const AIndex: Integer): TInstrumentalRole;
begin
  CheckRole(AIndex);
  Result := FRoles[AIndex];
end;

function TInstrumentalPlan.CopyGraph: TVoiceGraphPasses;
var
  LDrums: TLayerGraphPasses;
  LPitched: TLayerGraphPasses;
  LOffset: Integer;
  LContextCount: Integer;
  LIndex: Integer;
  LDependency: Integer;
begin
  Result := FSession.CopyGraph;
  LContextCount := 0;
  if FContext <> nil then
  begin
    LPitched := Result;
    Result := FContext.CopyGraph;
    LContextCount := Length(Result);
    SetLength(Result, LContextCount + Length(LPitched));
    for LIndex := 0 to High(LPitched) do
    begin
      Result[LContextCount + LIndex] := LPitched[LIndex];
      Result[LContextCount + LIndex].GroupIndex := 1;
      for LDependency := 0 to High(LPitched[LIndex].Dependencies) do
        Result[LContextCount + LIndex].Dependencies[LDependency] :=
          LContextCount + LPitched[LIndex].Dependencies[LDependency];
    end;
    { These are real pinned inputs from the preceding context graph,
      not dependencies that imply cross-group solver backtracking. }
    Result[LContextCount].InputSourcePassIndex := 0;
    Result[LContextCount + 1].InputSourcePassIndex := 0;
    if FContext.DrivenRole >= 0 then
      Result[LContextCount + 2 + FContext.DrivenRole].InputSourcePassIndex := 0;
  end;
  if FDrums <> nil then
  begin
    LDrums := FDrums.CopyGraph;
    LOffset := Length(Result);
    SetLength(Result, LOffset + Length(LDrums));
    for LIndex := 0 to High(LDrums) do
    begin
      Result[LOffset + LIndex] := LDrums[LIndex];
      Result[LOffset + LIndex].GroupIndex := 1 + LContextCount;
      for LDependency := 0 to High(LDrums[LIndex].Dependencies) do
      begin
        Result[LOffset + LIndex].Dependencies[LDependency] :=
          LOffset + LDrums[LIndex].Dependencies[LDependency];
      end;
    end;
    Result[LOffset].InputSourcePassIndex := LContextCount + 1;
  end;
end;

function TInstrumentalPlan.CopyProvider(const AName: String): TStyleProviderDescription;
begin
  if (FContext <> nil) and (AName = MusicalContextPassName) then
    Exit(FContext.CopyProvider);
  Result := FSession.CopyProvider(AName);
end;

function TInstrumentalPlan.CopyMusic: TWfcMusicVoicesGenerated;
begin
  Result := FSession.CopyAccepted;
end;

function TInstrumentalPlan.CopyPercussionHits: TPercussionHits;
begin
  Result := nil;
  if FDrums <> nil then
  begin
    Result := FDrums.CopyHits;
  end;
end;

function TInstrumentalPlan.CopyPercussionPart(const AIndex: Integer): TPercussionPart;
begin
  if FDrums = nil then
  begin
    raise EAudio.Create('Instrumental plan has no percussion');
  end;
  Result := FDrums.PartAt(AIndex);
end;

function TInstrumentalPlan.IsDrumProvider(const AName: String): Boolean;
var
  LIndex: Integer;
begin
  Result := False;
  if FDrums = nil then
  begin
    Exit;
  end;
  if AName = 'percussion.rhythm' then
  begin
    Exit(True);
  end;
  for LIndex := 0 to FDrums.PartCount - 1 do
  begin
    if FDrums.PartAt(LIndex).Name = AName then
    begin
      Exit(True);
    end;
  end;
end;

function TInstrumentalPlan.CopyPassTokens(const AIndex: Integer): TWfcModelTokens;
var
  LMusic: TWfcMusicVoicesGenerated;
  LDrums: TLayerSequences;
  LOffset: Integer;
  LMusicIndex: Integer;
begin
  LMusicIndex := AIndex;
  if FContext <> nil then
  begin
    if AIndex = 0 then Exit(FContext.CopyTokens);
    Dec(LMusicIndex);
  end;
  if (LMusicIndex >= 0) and (LMusicIndex < FSession.ProviderCount) then
  begin
    LMusic := FSession.CopyAccepted;
    Exit(Copy(LMusic.Layers[LMusicIndex].Tokens));
  end;
  LOffset := FSession.ProviderCount + FSession.ProofPassCount;
  if FContext <> nil then Inc(LOffset);
  if (FDrums <> nil) and (AIndex >= LOffset) and
    (AIndex < LOffset + FDrums.PartCount + 1) then
  begin
    LDrums := FDrums.CopySequences;
    Exit(Copy(LDrums[AIndex - LOffset].Tokens));
  end;
  raise EAudio.Create('Instrumental pass has no token model');
end;

function TInstrumentalPlan.CopyPassStates(const AIndex: Integer): TWfcSequenceStateIndices;
var
  LMusic: TWfcMusicVoicesGenerated;
  LDrums: TLayerSequences;
  LOffset: Integer;
  LMusicIndex: Integer;
begin
  LMusicIndex := AIndex;
  if FContext <> nil then
  begin
    if AIndex = 0 then Exit(FContext.CopyStates);
    Dec(LMusicIndex);
  end;
  if (LMusicIndex >= 0) and (LMusicIndex < FSession.ProviderCount) then
  begin
    LMusic := FSession.CopyAccepted;
    Exit(Copy(LMusic.Layers[LMusicIndex].StateIndices));
  end;
  LOffset := FSession.ProviderCount + FSession.ProofPassCount;
  if FContext <> nil then Inc(LOffset);
  if (FDrums <> nil) and (AIndex >= LOffset) and
    (AIndex < LOffset + FDrums.PartCount + 1) then
  begin
    LDrums := FDrums.CopySequences;
    Exit(Copy(LDrums[AIndex - LOffset].StateIndices));
  end;
  raise EAudio.Create('Instrumental pass has no latent model');
end;

function TInstrumentalPlan.CopyModel(const AName: String): TWfcSequenceModel;
begin
  if (FContext <> nil) and (AName = MusicalContextPassName) then
    Exit(FContext.CopyModel);
  if IsDrumProvider(AName) then
  begin
    Result := FDrums.CopyModel(AName);
  end
  else
  begin
    Result := FSession.CopyModel(AName);
  end;
end;

function TInstrumentalPlan.CopyConstraints(const AName: String): TWfcSequenceTokenConstraints;
begin
  if (FContext <> nil) and (AName = MusicalContextPassName) then
    Exit(FContext.CopyConstraints);
  Result := FSession.CopyConstraints(AName);
end;

function TInstrumentalPlan.CopyPreferences(const AName: String): TLayerTokenPreferences;
begin
  if (FContext <> nil) and (AName = MusicalContextPassName) then
    Exit(FContext.CopyPreferences);
  Result := FSession.CopyPreferences(AName);
end;

function TInstrumentalPlan.CopyNotes: TNoteSequence;
begin
  Result := TNoteSequence.Create(FNotes.TicksPerQuarter, FNotes.LengthTicks,
    FOptions.Tempos, FNotes.CopyGates);
end;

function TInstrumentalPlan.CopyPartTones(const AIndex: Integer): TFrameTones;
begin
  CheckRole(AIndex);
  Result := Copy(FParts[AIndex]);
end;

procedure TInstrumentalPlan.IncludePart(const AIndex: Integer; const ATones: TFrameTones);
var
  LTone: TFrameTone;
  LEnd: Int64;
begin
  if Length(ATones) > MaximumScheduledVoices - FToneCount then
  begin
    raise EAudio.Create('Finite instrumental plan exceeds 4096 scheduled tones');
  end;
  FParts[AIndex] := ATones;
  Inc(FToneCount, Length(ATones));
  for LTone in ATones do
  begin
    LEnd := LTone.StartFrame + LTone.GateFrames + SynthReleaseFrames(LTone.Voice, SampleRate);
    if LEnd > FFrameCount then
    begin
      FFrameCount := LEnd;
    end;
  end;
end;

function TInstrumentalPlan.CreatePlayer(const AGraph: TBusGraph;
  const AVoiceLimit, AWorkLimit: Integer): TScheduledSynth;
var
  LCandidate: TScheduledSynth;
  LRole: Integer;
  LTone: TFrameTone;
  LId: Int64;
  LStatus: TScheduleResult;
begin
  if (AGraph = nil) or (AGraph.SampleRate <> SampleRate) then
  begin
    raise EAudio.Create('Instrumental player requires a matching-rate bus graph');
  end;
  for LRole := 0 to High(FRoles) do
  begin
    if FRoles[LRole].OutputBus >= AGraph.BusCount then
    begin
      raise EAudio.Create('Instrumental role bus is outside the graph: ' + FRoles[LRole].Name);
    end;
  end;
  LCandidate := TScheduledSynth.Create(AGraph, AVoiceLimit, AWorkLimit);
  try
    for LRole := 0 to High(FParts) do
    begin
      for LTone in FParts[LRole] do
      begin
        LStatus := LCandidate.TrySchedule(LTone, FRoles[LRole].OutputBus, LRole, LId);
        if LStatus <> srScheduled then
        begin
          raise EAudio.CreateFmt('Instrumental role %s admission failed (schedule status %d)',
            [FRoles[LRole].Name, Ord(LStatus)]);
        end;
      end;
    end;
    Result := LCandidate;
    LCandidate := nil;
  finally
    LCandidate.Free;
  end;
end;

function TryCreateInstrumentalPlan(const AConfig: TWfcMusicVoicesGraphConfig;
  const ARoles: TInstrumentalRoles; const AOptions: TInstrumentalOptions;
  const AMasks: TVoiceMasks; const APreferences: TVoicePreferences;
  var APlan: TInstrumentalPlan; out AReport: TInstrumentalReport;
  const AProgress: TWorkProgressCallback;
  const APercussion: TPercussionDefinitions;
  const AMusicalContext: TWfcSequenceModel): Boolean;
var
  LCandidate: TInstrumentalPlan;
  LPrevious: TInstrumentalPlan;
  LNames: array of String;
  LRole: Integer;
  LIndex: Integer;
  LCount: Integer;
  LLength: Int64;
  LClockCheck: TTempoMap;
  LGenerated: TWfcMusicVoicesGenerated;
  LNotes: TNoteGates;
  LGate: TNoteGate;
  LPartSequence: TNoteSequence;
  LRender: TNoteRenderReport;
  LPartTones: TFrameTones;
  LPasses: TVoiceGraphPasses;
  LRhythmModel: TWfcSequenceModel;
  LDrumPart: TPercussionPart;
  LOther: Integer;
  LBoundMasks: TVoiceMasks;
begin
  Result := False;
  AReport := Default(TInstrumentalReport);
  ValidateAudioFormat(AOptions.SampleRate, 2);
  if AConfig.StepsPerOctave <> 12 then
  begin
    raise EAudio.Create('Instrumental synthesis requires explicit twelve-step MIDI pitch semantics');
  end;
  if (Length(ARoles) < 1) or (Length(ARoles) <> Length(AConfig.Voices)) or
    (Trim(AOptions.MaterialOrigin) = '') or (AOptions.EffectTailFrames < 0) or
    (AOptions.EffectTailFrames > Int64(AOptions.SampleRate) * 86400) then
  begin
    raise EAudio.Create('Instrumental roles, material origin or effect-tail extent is invalid');
  end;
  LLength := Int64(AOptions.Session.CellCount) * AOptions.Session.StepTicks;
  if (AOptions.Session.CellCount < 1) or (AOptions.Session.StepTicks < 1) or
    (LLength > High(Integer)) then
  begin
    raise EAudio.Create('Instrumental graph requires a bounded positive tick extent');
  end;
  LClockCheck := TTempoMap.Create(AOptions.Session.TicksPerQuarter, LLength, AOptions.Tempos);
  LClockCheck.Free;
  if ((Length(AMasks) <> 0) and (Length(AMasks) <> Length(ARoles) + 2)) or
    ((Length(APreferences) <> 0) and (Length(APreferences) <> Length(ARoles) + 2)) then
  begin
    raise EAudio.Create('Instrumental controls must match harmony/rhythm/role order');
  end;
  SetLength(LNames, Length(ARoles));
  for LRole := 0 to High(ARoles) do
  begin
    if (ARoles[LRole].Instrument = nil) or (Trim(ARoles[LRole].InstrumentId) = '') or
      (ARoles[LRole].OutputBus < 0) then
    begin
      raise EAudio.Create('Instrumental role requires an explicit instrument, identity and bus');
    end;
    LNames[LRole] := ARoles[LRole].Name;
    if (Length(APercussion) > 0) and (LNames[LRole] = 'percussion.rhythm') then
    begin
      raise EAudio.Create('Pitched role name conflicts with the percussion input pass');
    end;
    if ARoles[LRole].IsPercussion then
    begin
      raise EAudio.Create('Unpitched roles use the explicit percussion group, not named harmonic voices');
    end;
  end;
  for LRole := 0 to High(APercussion) do
  begin
    if (APercussion[LRole].Name = 'harmony') or
      (APercussion[LRole].Name = 'rhythm') then
    begin
      raise EAudio.Create('Percussion name conflicts with a pitched provider');
    end;
    for LOther := 0 to High(LNames) do
    begin
      if APercussion[LRole].Name = LNames[LOther] then
      begin
        raise EAudio.Create('Percussion and pitched role names must be distinct');
      end;
    end;
  end;
  ReportWork(AProgress, 'instrumental_plan', wuItems, 0, Length(ARoles) + 1);
  LCandidate := TInstrumentalPlan.Create;
  LPartSequence := nil;
  try
    LCandidate.FOptions := AOptions;
    LCandidate.FOptions.Tempos := Copy(AOptions.Tempos);
    LCandidate.FRoles := Copy(ARoles);
    LCandidate.FSession := TNamedVoiceSession.Create(AConfig, LNames,
      AOptions.Session, nil, AProgress);
    for LIndex := 0 to Length(ARoles) + 1 do
    begin
      if Length(AMasks) > 0 then
      begin
        LCandidate.FSession.SetConstraints(LCandidate.FSession.ProviderName(LIndex),
          AMasks[LIndex], AProgress);
      end;
      if Length(APreferences) > 0 then
      begin
        LCandidate.FSession.SetPreferences(LCandidate.FSession.ProviderName(LIndex),
          APreferences[LIndex], AProgress);
      end;
    end;
    if AMusicalContext <> nil then
    begin
      for LRole := 0 to High(LNames) do
        if LNames[LRole] = MusicalContextPassName then
          raise EAudio.Create('The musical-context provider name is reserved for joint context');
      LCandidate.FContext := TMusicalContextPlan.Create(AMusicalContext, LNames,
        AOptions.Session, AMasks, APreferences, AProgress);
      if not LCandidate.FContext.TryGenerate(AReport.ContextSolve, AProgress) then
      begin
        AReport.FailedPass := MusicalContextPassName;
        AReport.Detail := 'Joint harmonic/rhythmic context conflicts with the requested material';
        Exit;
      end;
      LBoundMasks := LCandidate.FContext.BindMasks(AMasks);
      for LIndex := 0 to High(LBoundMasks) do
        LCandidate.FSession.SetConstraints(LCandidate.FSession.ProviderName(LIndex),
          LBoundMasks[LIndex], AProgress);
    end;
    if not LCandidate.FSession.TryGenerate(LGenerated, AReport.Solve, AReport.Proof,
      AProgress) then
    begin
      LIndex := AReport.Solve.FinalReport.FailedPassIndex;
      LPasses := LCandidate.FSession.CopyGraph;
      if (LIndex >= 0) and (LIndex < Length(LPasses)) then
      begin
        AReport.FailedPass := LPasses[LIndex].Name;
      end;
      AReport.Detail := Format('Musical graph status %d at pass %d (%s); %s',
        [Ord(AReport.Solve.Status), LIndex, AReport.FailedPass,
         AReport.Proof.Issue.Detail]);
      Exit;
    end;
    LCandidate.FNotes := ProjectWfcEnsembleNotes(LGenerated.Frames,
      AOptions.Session.StepTicks, AOptions.Session.TicksPerQuarter, AOptions.Tempos);
    LCandidate.FFrameCount := LCandidate.FNotes.FrameAtTick(LLength, AOptions.SampleRate);
    ReportWork(AProgress, 'instrumental_plan', wuItems, 1, Length(ARoles) + 1);
    SetLength(LCandidate.FParts, Length(ARoles));
    for LRole := 0 to High(ARoles) do
    begin
      SetLength(LNotes, LCandidate.FNotes.NoteCount);
      LCount := 0;
      for LIndex := 0 to LCandidate.FNotes.NoteCount - 1 do
      begin
        LGate := LCandidate.FNotes.GateAt(LIndex);
        if LGate.Voice = LRole then
        begin
          LNotes[LCount] := LGate;
          Inc(LCount);
        end;
      end;
      SetLength(LNotes, LCount);
      LPartSequence := TNoteSequence.Create(AOptions.Session.TicksPerQuarter,
        LLength, AOptions.Tempos, LNotes);
      LPartTones := PlanNoteTones(LPartSequence, AOptions.SampleRate,
        ARoles[LRole].Instrument, LRender);
      FreeAndNil(LPartSequence);
      LCandidate.IncludePart(LRole, LPartTones);
      ReportWork(AProgress, 'instrumental_plan', wuItems, LRole + 2, Length(ARoles) + 1);
      LCandidate.FRoles[LRole].Instrument := nil;
    end;
    if Length(APercussion) > 0 then
    begin
      LRhythmModel := LCandidate.FSession.CopyModel('rhythm', AProgress);
      try
        if not TryCreatePercussionPlan(LRhythmModel, LGenerated.Layers[1].Tokens,
          APercussion, AOptions.Session.TicksPerQuarter, AOptions.Session.StepTicks,
          AOptions.SampleRate, AOptions.Tempos, AOptions.PercussionSeed,
          LCandidate.FDrums, AReport.PercussionSolve, AProgress) then
        begin
          LIndex := AReport.PercussionSolve.FinalReport.FailedPassIndex;
          AReport.FailedPass := 'percussion.rhythm';
          if (LIndex > 0) and (LIndex <= Length(APercussion)) then
          begin
            AReport.FailedPass := APercussion[LIndex - 1].Name;
          end;
          AReport.Detail := 'Percussion conflicts with the retained rhythm or reached its search limit: ' +
            AReport.FailedPass;
          Exit;
        end;
      finally
        LRhythmModel.Free;
      end;
      LCount := Length(ARoles);
      SetLength(LCandidate.FRoles, LCount + LCandidate.FDrums.PartCount);
      SetLength(LCandidate.FParts, Length(LCandidate.FRoles));
      for LIndex := 0 to LCandidate.FDrums.PartCount - 1 do
      begin
        LDrumPart := LCandidate.FDrums.PartAt(LIndex);
        LCandidate.FRoles[LCount + LIndex].Name := LDrumPart.Name;
        LCandidate.FRoles[LCount + LIndex].InstrumentId := 'percussion-recipe-v1';
        LCandidate.FRoles[LCount + LIndex].OutputBus := LDrumPart.OutputBus;
        LCandidate.FRoles[LCount + LIndex].IsPercussion := True;
        LCandidate.IncludePart(LCount + LIndex, LCandidate.FDrums.CopyPartTones(LIndex));
      end;
    end;
    if LCandidate.FFrameCount > MaximumTimingInteger - AOptions.EffectTailFrames then
    begin
      raise EAudio.Create('Instrumental audio extent exceeds exact timing bounds');
    end;
    Inc(LCandidate.FFrameCount, AOptions.EffectTailFrames);
    ReportWork(AProgress, 'instrumental_ready', wuItems, 1, 1);
    LPrevious := APlan;
    APlan := LCandidate;
    LCandidate := nil;
    LPrevious.Free;
    Result := True;
  finally
    LPartSequence.Free;
    LCandidate.Free;
  end;
end;

end.
