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
program pythian_tests_instrumental_reperform;

{$mode delphi}
{$H+}

uses
  SysUtils,
  pythian.audio,
  pythian.progress,
  pythian.bus,
  pythian.schedule,
  pythian.synth,
  pythian.oscillator,
  pythian.instrument,
  pythian.music,
  pythian.time,
  pythian.music.render,
  pythian.music.controls,
  pythian.wfc.instrumental,
  pythian.wfc.instrumental.starter,
  pythian.wfc.voices,
  pythian.wfc.percussion,
  wfc_model,
  wfc_sequence,
  wfc_sequence_text
  {$IFNDEF PAS2JS}
  , pythian.wave
  {$ENDIF}
  ;

type
  TReperformObserver = class
    Plan: TInstrumentalPlan;
    Edit: TInstrumentalSoundEdit;
    ExpectedLead: String;
    RejectStage: String;
    Calls: Integer;
    AttemptReentry: Boolean;
    ReentryRejected: Boolean;
    procedure Observe(const AWork: TWorkProgress);
  end;

var
  Checks: Integer;

procedure Check(const ACondition: Boolean; const ADetail: String);
begin
  Inc(Checks);
  if not ACondition then raise EAudio.Create(ADetail);
end;

procedure TReperformObserver.Observe(const AWork: TWorkProgress);
begin
  Inc(Calls);
  Check((AWork.Stage = 'instrumental_reperform') or
    (AWork.Stage = 'musical_expression') or (AWork.Stage = 'note_voice_plan') or
    (AWork.Stage = 'instrumental_reperform_ready'),
    'Retained performance never constructs, learns or solves a model');
  Check(Plan.RoleAt(2).InstrumentId = ExpectedLead,
    'Borrowed callbacks observe the accepted baseline until publication');
  if AttemptReentry then
  begin
    AttemptReentry := False;
    try
      Plan.Reperform([Edit]);
    except
      on LException: EAudio do
        ReentryRejected := Pos('already in progress', LException.Message) > 0;
    end;
  end;
  if AWork.Stage = RejectStage then raise EAbort.Create('Expected reperformance cancellation');
end;

function NewRenderGraph(const APlan: TInstrumentalPlan; const APart: Integer): TBusGraph;
var
  LSettings: array[0..6] of TBusSettings;
  LIndex: Integer;
begin
  for LIndex := 0 to 6 do
  begin
    LSettings[LIndex] := Default(TBusSettings);
    if (APart = 6) or (LIndex = APart) or (LIndex = 6) then
      LSettings[LIndex].Gain := 1;
  end;
  Result := TBusGraph.Create(APlan.SampleRate, LSettings);
  for LIndex := 0 to 5 do Result.AddSend(LIndex, 6, stPostFader, 1, 0);
end;

function RenderPart(const APlan: TInstrumentalPlan; const APart: Integer;
  const AFrames: Int64): TAudioSamples;
var
  LGraph: TBusGraph;
  LPlayer: TScheduledSynth;
  LIndex: Integer;
  LLeft: Double;
  LRight: Double;
begin
  Result := nil;
  LGraph := NewRenderGraph(APlan, APart);
  LPlayer := nil;
  try
    LPlayer := APlan.CreatePlayer(LGraph);
    SetLength(Result, Integer(AFrames) * 2);
    for LIndex := 0 to Integer(AFrames) - 1 do
    begin
      LPlayer.Process(LLeft, LRight);
      Result[LIndex * 2] := LLeft;
      Result[LIndex * 2 + 1] := LRight;
    end;
  finally
    LPlayer.Free;
    LGraph.Free;
  end;
end;

function SameAudio(const ALeft, ARight: TAudioSamples): Boolean;
var
  LIndex: Integer;
begin
  Result := False;
  if Length(ALeft) <> Length(ARight) then Exit;
  for LIndex := 0 to High(ALeft) do
    if ALeft[LIndex] <> ARight[LIndex] then Exit;
  Result := True;
end;

function GraphRecipe(const APlan: TInstrumentalPlan): String;
var
  LGraph: TVoiceGraphPasses;
  LModel: TWfcSequenceModel;
  LTokens: TWfcModelTokens;
  LStates: TWfcSequenceStateIndices;
  LPass: Integer;
  LCell: Integer;
begin
  Result := '';
  LGraph := APlan.CopyGraph;
  for LPass := 0 to High(LGraph) do
  begin
    Result := Result + LGraph[LPass].Name + ':' + IntToStr(LGraph[LPass].Width) + ':';
    if LGraph[LPass].IsProof then Continue;
    LModel := APlan.CopyModel(LGraph[LPass].Name);
    try
      Result := Result + EncodeWfcSequenceText(LModel);
    finally
      LModel.Free;
    end;
    LTokens := APlan.CopyPassTokens(LPass);
    LStates := APlan.CopyPassStates(LPass);
    for LCell := 0 to High(LTokens) do
      Result := Result + IntToStr(LStates[LCell]) + ':' + LTokens[LCell] + ';';
  end;
end;

procedure Run;
var
  LStarter: TInstrumentalStarter;
  LPlan: TInstrumentalPlan;
  LExpressed: TInstrumentalPlan;
  LOptions: TInstrumentalOptions;
  LReport: TInstrumentalReport;
  LRoles: TInstrumentalRoles;
  LDrums: TPercussionDefinitions;
  LOriginal: array[0..2] of TInstrument;
  LChanged: TInstrument;
  LUnavailable: TInstrument;
  LZones: TInstrumentZones;
  LObserver: TReperformObserver;
  LEdits: array[0..1] of TInstrumentalSoundEdit;
  LBaseline: array[0..6] of TAudioSamples;
  LAfter: TAudioSamples;
  LChangedMix: TAudioSamples;
  LRecipe: String;
  LLeadId: String;
  LFrames: Int64;
  LNotes: TNoteSequence;
  LOtherNotes: TNoteSequence;
  LSelected: TNoteSequence;
  LClock: TTempoMap;
  LGates: TNoteGates;
  LOldPlayer: TScheduledSynth;
  LOldGraph: TBusGraph;
  LLeft: Double;
  LRight: Double;
  LOldPlayerExact: Boolean;
  LStoredLeft: Single;
  LStoredRight: Single;
  LTones: TFrameTones;
  LReferenceTones: TFrameTones;
  LCoreReport: TNoteRenderReport;
  LIndex: Integer;
  LRole: Integer;
  LCalls: Integer;
  LCount: Integer;
  LRejected: Boolean;
  {$IFNDEF PAS2JS}
  LClip: TAudioClip;
  {$ENDIF}
begin
  LStarter := nil;
  LPlan := nil;
  LExpressed := nil;
  LChanged := nil;
  LUnavailable := nil;
  LObserver := nil;
  LNotes := nil;
  LOtherNotes := nil;
  LSelected := nil;
  LClock := nil;
  LOldPlayer := nil;
  LOldGraph := nil;
  for LRole := 0 to 2 do LOriginal[LRole] := nil;
  try
    LStarter := TInstrumentalStarter.Create(0);
    LRoles := LStarter.CopyRoles;
    for LRole := 0 to 2 do
      LOriginal[LRole] := TInstrument.Create(LRoles[LRole].Instrument.CopyZones);
    LZones := LOriginal[2].CopyZones;
    LZones[0].Voice.Shape := wsNoise;
    LChanged := TInstrument.Create(LZones);
    LZones[0].MaximumKey := 0;
    LUnavailable := TInstrument.Create(LZones);
    LOptions := DefaultInstrumentalOptions;
    LOptions.SampleRate := 8000;
    LOptions.Session.CellCount := 8;
    LOptions.Session.Seed := 731;
    LOptions.Session.RequireObservedEnd := False;
    LOptions.MaterialOrigin := 'Authored retained-score synthesis; no recording grains';
    LDrums := LStarter.CopyPercussion(8000);
    Check(TryCreateInstrumentalPlan(LStarter.Config, LRoles, LOptions,
      LStarter.GuideMasks(8), nil, LPlan, LReport, nil, LDrums), 'Six-part baseline accepted');
    LFrames := LPlan.FrameCount;
    LRecipe := GraphRecipe(LPlan);
    LLeadId := LPlan.RoleAt(2).InstrumentId;
    for LRole := 0 to 6 do LBaseline[LRole] := RenderPart(LPlan, LRole, LFrames);
    LOldGraph := NewRenderGraph(LPlan, 6);
    LOldPlayer := LPlan.CreatePlayer(LOldGraph);

    LEdits[0] := Default(TInstrumentalSoundEdit);
    LEdits[0].Role := 2;
    LEdits[0].InstrumentId := 'retained-noise-lead';
    LEdits[0].Instrument := LChanged;
    LEdits[0].Expression := DefaultMusicalExpression;
    LObserver := TReperformObserver.Create;
    LObserver.Plan := LPlan;
    LObserver.Edit := LEdits[0];
    LObserver.ExpectedLead := LLeadId;
    LObserver.AttemptReentry := True;
    LPlan.Reperform([LEdits[0]], LObserver.Observe);
    Check(LObserver.Calls > 0, 'Actual planning reports progress');
    Check(LObserver.ReentryRejected, 'Reentrant mutation rejects');
    Check(LPlan.RoleAt(2).Instrument = nil, 'Borrowed instrument pointer is not retained');
    Check(LPlan.RoleAt(2).InstrumentId = 'retained-noise-lead', 'Changed sound identity published');
    Check(GraphRecipe(LPlan) = LRecipe, 'All actual graph models, tokens and states remain exact');
    for LRole := 0 to 6 do
    begin
      LAfter := RenderPart(LPlan, LRole, LFrames);
      if (LRole = 2) or (LRole = 6) then
        Check(not SameAudio(LBaseline[LRole], LAfter), 'Selected lead and full mix change')
      else
        Check(SameAudio(LBaseline[LRole], LAfter), 'Unselected pitched/drum PCM stays exact');
    end;
    LChangedMix := RenderPart(LPlan, 6, LFrames);
    LOldPlayerExact := True;
    for LIndex := 0 to 1999 do
    begin
      LOldPlayer.Process(LLeft, LRight);
      LStoredLeft := LLeft;
      LStoredRight := LRight;
      LOldPlayerExact := LOldPlayerExact and
        (LStoredLeft = LBaseline[6][LIndex * 2]) and
        (LStoredRight = LBaseline[6][LIndex * 2 + 1]);
    end;
    Check(LOldPlayerExact, 'A player created before the edit retains its original performance');
    LObserver.ExpectedLead := 'retained-noise-lead';
    for LIndex := 0 to 2 do
    begin
      case LIndex of
        0: LObserver.RejectStage := 'instrumental_reperform';
        1: LObserver.RejectStage := 'note_voice_plan';
        2: LObserver.RejectStage := 'instrumental_reperform_ready';
      end;
      LEdits[0].Instrument := LOriginal[2];
      LRejected := False;
      try LPlan.Reperform([LEdits[0]], LObserver.Observe);
      except on EAbort do LRejected := True end;
      Check(LRejected, 'Cancellation before publication propagates');
      Check(GraphRecipe(LPlan) = LRecipe, 'Cancellation retains exact graph');
      Check(SameAudio(LChangedMix, RenderPart(LPlan, 6, LFrames)),
        'Cancellation preserves the complete accepted performance');
    end;
    LObserver.RejectStage := '';
    LEdits[0].Instrument := LChanged;
    LCalls := LObserver.Calls;
    LRejected := False;
    try LPlan.Reperform([LEdits[0], LEdits[0]], LObserver.Observe);
    except on EAudio do LRejected := True end;
    Check(LRejected and (LCalls = LObserver.Calls), 'Duplicate roles reject before callbacks');
    LEdits[1] := LEdits[0];
    LEdits[1].Role := 3;
    LRejected := False;
    try LPlan.Reperform([LEdits[1]]);
    except on EAudio do LRejected := True end;
    Check(LRejected, 'Percussion cannot enter the pitched edit path');

    LEdits[0].Role := 0;
    LEdits[0].InstrumentId := 'candidate-bass';
    LEdits[1].Role := 2;
    LEdits[1].Instrument := LUnavailable;
    LRejected := False;
    try LPlan.Reperform(LEdits);
    except on EAudio do LRejected := True end;
    Check(LRejected, 'A later unavailable instrument rejects the multi-part candidate');
    Check(SameAudio(LChangedMix, RenderPart(LPlan, 6, LFrames)),
      'Earlier successfully planned edits do not leak from a failed candidate');
    Check(LPlan.RoleAt(0).InstrumentId = LRoles[0].InstrumentId,
      'Failed candidate leaves unrelated identity intact');

    LEdits[1].Role := 1;
    LEdits[1].Instrument := LChanged;
    LEdits[1].InstrumentId := 'candidate-harmony';
    LAfter := RenderPart(LPlan, 2, LFrames);
    LPlan.Reperform(LEdits);
    Check(not SameAudio(LBaseline[0], RenderPart(LPlan, 0, LFrames)), 'First selected role changes');
    Check(not SameAudio(LBaseline[1], RenderPart(LPlan, 1, LFrames)), 'Second selected role changes');
    Check(SameAudio(LAfter, RenderPart(LPlan, 2, LFrames)), 'Multi-part edit retains the previously edited Lead');
    Check(SameAudio(LBaseline[3], RenderPart(LPlan, 3, LFrames)), 'Multi-part edit retains the drums');
    for LRole := 0 to 1 do
    begin
      LEdits[LRole].Instrument := LOriginal[LRole];
      LEdits[LRole].InstrumentId := LRoles[LRole].InstrumentId;
    end;
    LPlan.Reperform(LEdits);
    Check(SameAudio(LChangedMix, RenderPart(LPlan, 6, LFrames)),
      'Restoring both selected roles retains the prior full mix exactly');

    LEdits[0].Role := 2;
    LEdits[0].InstrumentId := LLeadId;
    LEdits[0].Instrument := LOriginal[2];
    LEdits[0].Expression.VelocityPercent := 50;
    LEdits[0].Expression.GatePercent := 25;
    LPlan.Reperform([LEdits[0]]);
    LAfter := RenderPart(LPlan, 2, LFrames);
    LNotes := LPlan.CopyScore;
    LOtherNotes := LPlan.CopyNotes;
    Check(LNotes.NoteCount = LOtherNotes.NoteCount, 'Original and performed scores retain note identities');
    LCount := 0;
    for LIndex := 0 to LNotes.NoteCount - 1 do
      if LNotes.GateAt(LIndex).Voice = 2 then
      begin
        Check(LNotes.GateAt(LIndex).Velocity > LOtherNotes.GateAt(LIndex).Velocity,
          'Detached score exposes original velocity before expression');
        Inc(LCount);
      end;
    Check(LCount > 0, 'Original-score inspection covers actual Lead notes');
    FreeAndNil(LNotes);
    FreeAndNil(LOtherNotes);
    LPlan.Reperform([LEdits[0]]);
    Check(SameAudio(LAfter, RenderPart(LPlan, 2, LFrames)),
      'Repeated absolute expression does not compound');
    LEdits[0].Expression := DefaultMusicalExpression;
    LPlan.Reperform([LEdits[0]]);
    Check(SameAudio(LBaseline[6], RenderPart(LPlan, 6, LFrames)),
      'Neutral restoration recovers the exact original full mix');

    SetLength(LOptions.Expression, 3);
    for LRole := 0 to 2 do LOptions.Expression[LRole] := DefaultMusicalExpression;
    LOptions.Expression[2].VelocityPercent := 50;
    Check(TryCreateInstrumentalPlan(LStarter.Config, LRoles, LOptions,
      LStarter.GuideMasks(8), nil, LExpressed, LReport, nil, LDrums),
      'Originally expressed baseline accepts');
    LExpressed.Reperform([LEdits[0]]);
    Check(SameAudio(LBaseline[6], RenderPart(LExpressed, 6, LFrames)),
      'An initially expressed plan retains its original unperformed gates');

    LNotes := LPlan.CopyNotes;
    LTones := PlanNoteVoiceTones(LNotes, 8000, 2, LOriginal[2], LCoreReport);
    Check(LCoreReport.SourceNotes = Length(LTones), 'Primary voice planning counts selected notes');
    SetLength(LGates, LNotes.NoteCount);
    LCount := 0;
    for LIndex := 0 to LNotes.NoteCount - 1 do
      if LNotes.GateAt(LIndex).Voice = 2 then
      begin
        LGates[LCount] := LNotes.GateAt(LIndex);
        Inc(LCount);
      end;
    SetLength(LGates, LCount);
    LClock := LNotes.CopyClock;
    LSelected := TNoteSequence.Create(LNotes.TicksPerQuarter, LNotes.LengthTicks,
      LClock.CopyChanges, LGates);
    LReferenceTones := PlanNoteTones(LSelected, 8000, LOriginal[2], LCoreReport);
    Check(Length(LReferenceTones) = Length(LTones), 'Shared selection agrees with independent score selection');
    for LIndex := 0 to High(LTones) do
    begin
      Check(LTones[LIndex].Seed = Cardinal(LIndex + 1),
        'Selected-voice seeds do not depend on unrelated gates');
      Check((LTones[LIndex].Seed = LReferenceTones[LIndex].Seed) and
        (LTones[LIndex].StartFrame = LReferenceTones[LIndex].StartFrame) and
        (LTones[LIndex].GateFrames = LReferenceTones[LIndex].GateFrames) and
        (LTones[LIndex].FrequencyHz = LReferenceTones[LIndex].FrequencyHz),
        'Consolidated planning preserves selected timing, pitch and note-local randomness');
    end;
    LTones := PlanNoteVoiceTones(LNotes, 8000, 999, LOriginal[2], LCoreReport);
    Check((Length(LTones) = 0) and (LCoreReport.SourceNotes = 0),
      'An absent voice plans a valid empty part');
    LRejected := False;
    try LTones := PlanNoteVoiceTones(LNotes, 8000, -1, LOriginal[2], LCoreReport);
    except on EAudio do LRejected := True end;
    Check(LRejected and (LCoreReport.SourceNotes = 0), 'Invalid selection rejects with a reset report');
    LOtherNotes := LExpressed.CopyNotes;
    Check(LOtherNotes.NoteCount = LNotes.NoteCount, 'Reperformance retains score identities');
    for LIndex := 0 to LNotes.NoteCount - 1 do
      Check((LOtherNotes.GateAt(LIndex).Pitch = LNotes.GateAt(LIndex).Pitch) and
        (LOtherNotes.GateAt(LIndex).StartTick = LNotes.GateAt(LIndex).StartTick),
        'Accepted pitches and attacks stay exact');
    Check(GraphRecipe(LPlan) = LRecipe, 'Repeated edits preserve original model/state receipts');
    {$IFNDEF PAS2JS}
    if ParamCount = 1 then
    begin
      ForceDirectories(ParamStr(1));
      LClip := TAudioClip.Create(8000, 2, LBaseline[6]);
      try SaveWavePcm16(IncludeTrailingPathDelimiter(ParamStr(1)) + 'before.wav', LClip);
      finally LClip.Free end;
      LClip := TAudioClip.Create(8000, 2, LChangedMix);
      try SaveWavePcm16(IncludeTrailingPathDelimiter(ParamStr(1)) + 'after-lead.wav', LClip);
      finally LClip.Free end;
    end;
    {$ENDIF}
  finally
    LOldPlayer.Free;
    LOldGraph.Free;
    LSelected.Free;
    LClock.Free;
    LOtherNotes.Free;
    LNotes.Free;
    LObserver.Free;
    LExpressed.Free;
    LPlan.Free;
    LUnavailable.Free;
    LChanged.Free;
    for LRole := 0 to 2 do LOriginal[LRole].Free;
    LStarter.Free;
  end;
end;

begin
  try
    Run;
    WriteLn('PASS retained instrumental performance: ', Checks, ' checks');
  except
    on LException: Exception do
    begin
      WriteLn(LException.ClassName, ': ', LException.Message);
      {$IFDEF PAS2JS}
      raise;
      {$ELSE}
      ExitCode := 1;
      {$ENDIF}
    end;
  end;
end.
