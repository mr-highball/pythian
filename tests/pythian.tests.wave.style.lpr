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

program pythian_tests_wave_style;

{$mode delphi}
{$H+}

uses
  SysUtils,
  Math,
  fpjson,
  jsonparser,
  pythian.audio,
  pythian.analysis,
  pythian.hash,
  pythian.onset,
  pythian.onset.dynamics,
  pythian.pitch,
  pythian.pitch.cells,
  pythian.pitch.track,
  pythian.source.wavetable,
  pythian.source,
  pythian.time,
  pythian.wfc.pitch,
  pythian.passage,
  pythian.tonal,
  pythian.music.context,
  pythian.music.grid.frames,
  pythian.music,
  pythian.music.render,
  pythian.synth,
  pythian.envelope,
  pythian.automation,
  pythian.wave,
  pythian.articulation,
  pythian.midi.notes,
  pythian.rhythm.admission,
  pythian.wfc.context,
  pythian.wfc.context.archive,
  pythian.wfc.context.profile,
  pythian.wfc.style,
  pythian.wfc.instrument,
  pythian.wfc.performance,
  pythian.wfc.grid,
  pythian.wfc.layers,
  pythian.wfc.providers,
  pythian.tools.files,
  wfc,
  wfc_model,
  wfc_sequence,
  wfc_sequence_graph,
  wfc_sequence_learn,
  wfc_sequence_text,
  wfc_sequence_analyze,
  wfc_music_sequence,
  wfc_music_ensemble;

procedure Check(const AValue: Boolean; const AMessage: String);
begin
  if not AValue then
  begin
    raise EAudio.Create(AMessage);
  end;
end;

procedure ProviderChoiceChecks;
var
  LChoice: TStyleProviderChoice;
  LChoices: TStyleProviderChoices;
  LModel: TWfcSequenceModel;
  LRejected: Boolean;
begin
  LChoice := DecodeStyleProviderChoice(spvKey, 'pythian.context.key.v1.unknown');
  Check((LChoice.Dimensions = [scdKey]) and (LChoice.Key.Root = -1),
    'An explicitly unknown key remains unknown');
  LChoice := DecodeStyleProviderChoice(spvOnsets, RhythmEmptyToken);
  Check((LChoice.Dimensions = [scdOnset]) and not LChoice.Onset,
    'No onset does not report silence or any pitch evidence');
  LChoice := DecodeStyleProviderChoice(spvPitchRhythm, 'pythian.pitch.rhythm.v1.60.5');
  Check((LChoice.Dimensions = [scdPitch, scdOnset]) and LChoice.Onset and
    (LChoice.Note = 60) and (LChoice.Intensity = -1),
    'Joint onset without dynamics does not invent an intensity');
  LChoice := DecodeStyleProviderChoice(spvPerformance, 'pythian.pitch.span.v1.1.-1.240');
  Check((LChoice.PitchKind = pskSilence) and (LChoice.Note = -1) and
    (LChoice.DurationTicks = 240), 'Silence retains a duration without claiming a note');
  LChoice := DecodeStyleProviderChoice(spvPerformance, 'pythian.pitch.span.v1.2.-1.240');
  Check(LChoice.PitchKind = pskUnknown, 'Unknown and silence remain distinct');
  LRejected := False;
  try
    LChoice := DecodeStyleProviderChoice(spvPitch, 'pythian.pitch.midi.v1.060');
  except
    on EAudio do
    begin
      LRejected := True;
    end;
  end;
  Check(LRejected and (LChoice.PitchKind = pskUnknown) and (LChoice.DurationTicks = 240),
    'Noncanonical choice rejects without replacing caller value');
  LModel := LearnSequenceModel(['pythian.pitch.midi.v1.60', RhythmOnsetToken], 1);
  try
    SetLength(LChoices, 1);
    LChoices[0] := LChoice;
    LRejected := False;
    try
      LChoices := CopyStyleProviderChoices(LModel, spvPitch);
    except
      on EAudio do
      begin
        LRejected := True;
      end;
    end;
    Check(LRejected and (Length(LChoices) = 1) and
      (LChoices[0].PitchKind = pskUnknown), 'Mixed vocabulary rejects atomically');
  finally
    LModel.Free;
  end;
end;

procedure GridApiChecks(const APath: String);
var
  LStyle: TWaveStyleProfile;
  LDefinition: TStyleGrid;
  LSession: TLearnedLayerSession;
  LReplaySession: TLearnedLayerSession;
  LOptions: TStyleGridOptions;
  LGenerated: TLayerSequences;
  LBefore: TLayerSequences;
  LMixed: TLayerSequences;
  LReplay: TLayerSequences;
  LPlan: TStyleGridResult;
  LFresh: TStyleGridResult;
  LReport: TGraphNegotiationReport;
  LSelective: TGraphSelectiveNegotiationReport;
  LAnalysis: TWfcSequenceDomainAnalysis;
  LPreferences: TLayerTokenPreferences;
  LMask: TWfcSequenceTokenConstraints;
  LLocks: TGridValueLocks;
  LRejected: Boolean;
  LIndex: Integer;
  LCell: Integer;
  LPitch: Integer;
  LCase: Integer;
  LDescription: TStyleProviderDescription;
  LChoice: TStyleProviderChoice;
  LJointIndex: Integer;
begin
  LStyle := nil;
  LDefinition := nil;
  LSession := nil;
  LReplaySession := nil;
  try
    LStyle := DecodeWaveStyle(ReadFileBytes(APath, MaximumStyleBytes));
    Check(LStyle.HasPitchRhythm and LStyle.HasDynamics,
      'Grid API fixture requires observed pitch/onset/intensity evidence');
    LOptions := DefaultStyleGridOptions;
    LOptions.CellCount := 64;
    LOptions.CouplePitch := True;
    LDefinition := TStyleGrid.Create(LStyle, LOptions);
    FreeAndNil(LStyle);
    Check((LDefinition.ProviderCount = 6) and
      (LDefinition.ProviderIndex(gpPitchRhythm) = 2) and
      (LDefinition.ProviderName(5) = 'pitch'), 'Stable named provider order');
    LDescription := LDefinition.CopyProvider(4);
    Check((LDescription.Name = 'intensity') and (LDescription.Vocabulary = spvIntensity) and
      (LDescription.Timing = sptUniform) and (LDescription.TicksPerQuarter = 480) and
      (LDescription.StepTicks = 240) and (LDescription.Scope.CellCount = 64) and
      (LDescription.Scope.Extent = wseFragment), 'Description retains musical grid and scope');
    Check((Length(LDescription.Dependencies) = 2) and
      (LDescription.Dependencies[0].Name = 'onsets') and
      (LDescription.Dependencies[1].Name = 'pitch-rhythm') and
      (LDescription.Dependencies[1].TimeMapping = ltmCellIndex),
      'Description names both actual conjunctive providers');
    LDescription.Dependencies[0].Name := 'mutated';
    LDescription.Choices[0].Token := 'mutated';
    Check((LDefinition.CopyProvider(4).Dependencies[0].Name = 'onsets') and
      (LDefinition.CopyProvider(4).Choices[0].Token <> 'mutated'),
      'Provider descriptions detach nested arrays');
    LRejected := False;
    try
      LDescription := LDefinition.CopyProvider(-1);
    except
      on EAudio do
      begin
        LRejected := True;
      end;
    end;
    Check(LRejected and (LDescription.Name = 'intensity') and
      (LDescription.Choices[0].Token = 'mutated'), 'Invalid inspection preserves caller snapshot');
    for LIndex := 0 to LDefinition.ProviderCount - 1 do
    begin
      Check(LDefinition.AnalyzeProvider(LIndex, nil, LAnalysis) and
        (Length(LAnalysis.Positions) = 64), 'Explicit grid scope is feasible');
      LPreferences := LDefinition.CopyProvider(LIndex).Preferences;
      if Length(LPreferences) > 0 then
      begin
        LPreferences[0].Multiplier := 0;
        Check(LDefinition.CopyPreferences(LIndex)[0].Multiplier > 0,
          'Provider description preferences are detached');
      end;
    end;
    LSession := LDefinition.CreateSession;
    LReplaySession := LDefinition.CreateSession;
    Check(LSession.TryGenerate(LGenerated, LReport), 'Grid solves after source release');
    Check(LReplaySession.TryGenerate(LReplay, LReport), 'Independent grid replay solves');
    for LIndex := 0 to High(LGenerated) do
    begin
      for LCell := 0 to 63 do
      begin
        Check((LGenerated[LIndex].Tokens[LCell] = LReplay[LIndex].Tokens[LCell]) and
          (LGenerated[LIndex].StateIndices[LCell] = LReplay[LIndex].StateIndices[LCell]),
          'Separate owned sessions replay every token and latent state');
      end;
    end;
    LPlan := LDefinition.Capture(LGenerated);
    { A host discovers one complete observed joint choice without decoding a
      token or inventing an independent combination of musical dimensions. }
    LJointIndex := LDefinition.ProviderIndex(gpPitchRhythm);
    LDescription := LDefinition.CopyProvider(LJointIndex);
    LCase := -1;
    for LIndex := 0 to High(LDescription.Choices) do
    begin
      LChoice := LDescription.Choices[LIndex];
      if (LChoice.Note <> LPlan.Pitches[0]) and LChoice.Onset then
      begin
        LCase := LIndex;
        Break;
      end;
    end;
    Check(LCase >= 0, 'Fixture supplies a discovered alternate pitch/onset choice');
    LChoice := LDescription.Choices[LCase];
    SetLength(LMask, 1);
    LMask[0] := MakeWfcSequenceTokenConstraint(0, [LChoice.Token]);
    LReplaySession.SetPreferences(LDescription.Name,
      [MakeLayerTokenPreference(LChoice.Token, 4)]);
    LReplaySession.SetConstraints(LDescription.Name, LMask);
    Check(LReplaySession.TryRegenerate([LDescription.Name], 731, LReplay, LSelective),
      'Discovered joint choice drives actual preferences and a hard lock');
    LFresh := LDefinition.Capture(LReplay);
    Check((LFresh.Pitches[0] = LChoice.Note) and (LFresh.Onsets[0] = LChoice.Onset) and
      (LFresh.Intensities[0] = LChoice.Intensity), 'Discovered musical values reach capture');
    for LIndex := 0 to 1 do
    begin
      for LCell := 0 to 63 do
      begin
        Check(LReplay[LIndex].StateIndices[LCell] = LGenerated[LIndex].StateIndices[LCell],
          'Discovered edit preserves independent base states');
      end;
    end;
    Check((Length(LPlan.Onsets) = 64) and (Length(LPlan.Pitches) = 64) and
      (Length(LPlan.Intensities) = 64), 'Typed capture preserves scope and capabilities');
    for LCell := 0 to 63 do
    begin
      Check(SameKeyContext(LPlan.Context.Keys[LCell],
        KeyContextFromToken(LGenerated[0].Tokens[LCell])) and
        (LPlan.Context.Tempos[LCell] = TempoContextFromToken(LGenerated[1].Tokens[LCell])),
        'Typed capture agrees with independently decoded base context');
      Check((LPlan.Onsets[LCell] = (LGenerated[3].Tokens[LCell] = RhythmOnsetToken)) and
        (LPlan.Intensities[LCell] = DecodeStyleIntensityToken(LGenerated[4].Tokens[LCell])) and
        (LPlan.Pitches[LCell] = DecodePitchNoteToken(LGenerated[5].Tokens[LCell])),
        'Typed capture agrees with independently decoded musical values');
    end;
    LPlan.Context.Keys[0].Root := 11;
    LPlan.Pitches[0] := 127;
    LFresh := LDefinition.Capture(LGenerated);
    Check((LFresh.Pitches[0] <> 127) and (LFresh.Context.Keys[0].Root <> 11),
      'Captured arrays detach from source, session and future captures');

    LMask := LDefinition.KeyConstraints([MakeGridKeyLock(0, LFresh.Context.Keys[0])]);
    LSession.SetConstraints('key', LMask);
    LMask := LDefinition.ValueConstraints(gpTempo,
      [MakeGridValueLock(0, LFresh.Context.Tempos[0])]);
    LSession.SetConstraints('tempo', LMask);
    Check(LSession.TryRegenerate(['key', 'tempo'], LOptions.Seed, LGenerated, LSelective),
      'Typed key and tempo locks solve');
    LBefore := LSession.CopyAccepted;
    LPlan := LDefinition.Capture(LBefore);
    LPitch := LDefinition.ProviderIndex(gpPitch);
    { The maintained two-note source contains MIDI 60/62; force a real change. }
    SetLength(LLocks, 1);
    if LPlan.Pitches[0] = 60 then
    begin
      LLocks[0] := MakeGridValueLock(0, 62);
    end
    else
    begin
      LLocks[0] := MakeGridValueLock(0, 60);
    end;
    LSession.SetConstraints('pitch', LDefinition.ValueConstraints(gpPitch, LLocks));
    LSession.SetConstraints('pitch-rhythm', LDefinition.CoupledConstraints(nil, nil, LLocks));
    Check(LSession.TryRegenerate(['pitch-rhythm'], LOptions.Seed, LGenerated, LSelective),
      'Coupled typed pitch edit solves through actual WFC');
    LFresh := LDefinition.Capture(LGenerated);
    Check(LFresh.Pitches[0] = LLocks[0].Value, 'Typed hard pitch lock reaches capture');
    for LIndex := 0 to 1 do
    begin
      for LCell := 0 to 63 do
      begin
        Check((LBefore[LIndex].Tokens[LCell] = LGenerated[LIndex].Tokens[LCell]) and
          (LBefore[LIndex].StateIndices[LCell] = LGenerated[LIndex].StateIndices[LCell]),
          'Coupled edit preserves independent base states');
      end;
    end;
    LMixed := Copy(LBefore, 0, Length(LBefore));
    LMixed[LPitch] := LGenerated[LPitch];
    LRejected := False;
    try
      LFresh := LDefinition.Capture(LMixed);
    except
      on EAudio do
      begin
        LRejected := True;
      end;
    end;
    Check(LRejected, 'Individually valid paths cannot invent a joint relationship');
    Check((Length(LFresh.Pitches) = 64) and (LFresh.Pitches[0] = LLocks[0].Value),
      'Rejected joint capture preserves the previous assigned result');
    for LCase := 0 to 1 do
    begin
      LMixed := LSession.CopyAccepted;
      if LCase = 0 then
      begin
        LMixed[0].Tokens[0] := 'tampered';
      end
      else
      begin
        LMixed[0].StateIndices[0] := -1;
      end;
      LRejected := False;
      try
        LFresh := LDefinition.Capture(LMixed);
      except
        on EAudio do
        begin
          LRejected := True;
        end;
      end;
      Check(LRejected, 'Capture rejects mismatched tokens and invalid latent paths');
      Check((Length(LFresh.Pitches) = 64) and (LFresh.Pitches[0] = LLocks[0].Value),
        'Rejected path capture preserves the previous assigned result');
    end;
    for LCase := 0 to 5 do
    begin
      LRejected := False;
      try
        case LCase of
          0:
          begin
            LMask := LDefinition.ValueConstraints(gpPitch,
              [MakeGridValueLock(0, 60), MakeGridValueLock(0, 62)]);
          end;
          1:
          begin
            LMask := LDefinition.ValueConstraints(gpOnsets, [MakeGridValueLock(64, 1)]);
          end;
          2:
          begin
            LMask := LDefinition.ValueConstraints(gpOnsets, [MakeGridValueLock(0, 2)]);
          end;
          3:
          begin
            LMask := LDefinition.ValueConstraints(gpPitch, [MakeGridValueLock(0, -1)]);
          end;
          4:
          begin
            LMask := LDefinition.CoupledConstraints([MakeGridValueLock(0, 1)],
              [MakeGridValueLock(0, 0)], nil);
          end;
          5:
          begin
            LMask := LDefinition.KeyConstraints([
              MakeGridKeyLock(-1, LPlan.Context.Keys[0])]);
          end;
        end;
      except
        on EAudio do
        begin
          LRejected := True;
        end;
      end;
      Check(LRejected, 'Typed invalid/contradictory lock rejects before session mutation');
    end;
    LFresh := LDefinition.Capture(LSession.CopyAccepted);
    Check(LFresh.Pitches[0] = LLocks[0].Value, 'Rejected helper calls preserve accepted edit');
    FreeAndNil(LDefinition);
    Check(LSession.TryRegenerate(['pitch-rhythm'], LOptions.Seed, LGenerated, LSelective),
      'Session survives definition release');
    Check((Length(LFresh.Context.Keys) = 64) and
      (LFresh.Pitches[0] = LLocks[0].Value), 'Captured values survive both owners');
    WriteLn('Owned grid API: replay, context/typed controls, coupled edits, independent states, ' +
      'capture rejection and detached lifetimes pass');
  finally
    LReplaySession.Free;
    LSession.Free;
    LDefinition.Free;
    LStyle.Free;
  end;
end;

procedure PerformanceApiChecks(const AHeld, AChanging, ASingle: String);
var
  LStyle: TWaveStyleProfile;
  LDefinition: TStylePerformance;
  LLimited: TStylePerformance;
  LSession: TLearnedLayerSession;
  LLimitedSession: TLearnedLayerSession;
  LPlan: TStylePerformancePlan;
  LEdited: TStylePerformancePlan;
  LOptions: TStylePerformanceOptions;
  LGenerated: TLayerSequences;
  LBefore: TLayerSequences;
  LMask: TWfcSequenceTokenConstraints;
  LReport: TGraphNegotiationReport;
  LSelective: TGraphSelectiveNegotiationReport;
  LSpans: TTimedPitchSpans;
  LKeys: TKeyChanges;
  LClock: TTempoMap;
  LRejected: Boolean;
  LIndex: Integer;
  LCase: Integer;
  LAnalysis: TWfcSequenceDomainAnalysis;
  LDescription: TStyleProviderDescription;
  LChoice: TStyleProviderChoice;
  LFound: Boolean;
begin
  LStyle := nil;
  LDefinition := nil;
  LLimited := nil;
  LSession := nil;
  LLimitedSession := nil;
  LPlan := nil;
  LEdited := nil;
  try
    LStyle := DecodeWaveStyle(ReadFileBytes(AHeld, MaximumStyleBytes));
    LOptions := DefaultStylePerformanceOptions;
    LOptions.SpanCount := 3;
    LDefinition := TStylePerformance.Create(LStyle, LOptions);
    LOptions.KeyCells := 1;
    LOptions.TempoCells := 1;
    LLimited := TStylePerformance.Create(LStyle, LOptions);
    FreeAndNil(LStyle);
    LDescription := LDefinition.CopyProvider(ppKey);
    Check((LDescription.Timing = sptHeld) and (LDescription.StepTicks = 0) and
      (LDescription.Scope.CellCount = 1) and (Length(LDescription.Dependencies) = 0),
      'Held description does not invent a finite one-cell musical extent or dependency');
    LDescription := LLimited.CopyProvider(ppKey);
    Check((LDescription.Timing = sptUniform) and (LDescription.StepTicks = LLimited.StepTicks),
      'One timed context cell differs from a held value');
    LDescription := LDefinition.CopyProvider(ppPerformance);
    Check((LDescription.Timing = sptGeneratedSpans) and (LDescription.StepTicks = 0) and
      (LDescription.Scope.CellCount = 3) and (LDescription.TicksPerQuarter = 480) and
      (LDescription.Vocabulary = spvPerformance), 'Performance description retains cumulative timing');
    LFound := False;
    for LChoice in LDescription.Choices do
    begin
      Check(LChoice.Dimensions = [scdPitch, scdDuration], 'Performance choice has explicit dimensions');
      if (LChoice.PitchKind = pskPitch) and (LChoice.Note = 69) and
        (LChoice.DurationTicks = 316) then
      begin
        LFound := True;
      end;
    end;
    Check(LFound, 'Performance exposes observed joint pitch/duration alternatives');
    Check(LDefinition.AnalyzeProvider(ppPerformance, nil, LAnalysis) and
      (Length(LAnalysis.Positions) = 3), 'Provider analysis uses its explicit performance scope');
    Check(LDefinition.AnalyzeProvider(ppKey, nil, LAnalysis) and
      (Length(LAnalysis.Positions) = 1), 'Held context analysis retains its independent one-cell scope');
    LSession := LDefinition.CreateSession;
    Check(LSession.TryGenerate(LGenerated, LReport), 'Owned definition generates after source style release');
    LPlan := LDefinition.Capture(LGenerated);
    LSpans := LPlan.CopySpans;
    Check((Length(LSpans) = 3) and (LSpans[1].Note = 48) and
      (LSpans[1].EndTick - LSpans[1].StartTick = 288), 'Measured bassoon enters native performance plan');
    LSpans[1].Note := 127;
    Check(LPlan.CopySpans[1].Note = 48, 'Plan spans are detached');
    LMask := LDefinition.PerformanceConstraints([MakePerformanceValueLock(1, 316)],
      [MakePerformanceValueLock(1, 69)]);
    Check(Length(LMask) = 1, 'Joint pitch/duration control uses one cell constraint');
    LBefore := LSession.CopyAccepted;
    LSession.SetConstraints('performance', LMask);
    Check(LSession.TryRegenerate(['performance'], 731, LGenerated, LSelective), 'Typed performance edit solves');
    Check((LGenerated[0].StateIndices[0] = LBefore[0].StateIndices[0]) and
      (LGenerated[1].StateIndices[0] = LBefore[1].StateIndices[0]), 'Typed edit retains base latent state');
    LEdited := LDefinition.Capture(LGenerated);
    Check((LEdited.CopySpans[1].Note = 69) and (LPlan.CopySpans[1].Note = 48),
      'Edited and previously captured plans remain independent');
    FreeAndNil(LEdited);
    LRejected := False;
    try
      LMask := LDefinition.PerformanceConstraints([MakePerformanceValueLock(1, 316)],
        [MakePerformanceValueLock(1, 48)]);
    except
      on EAudio do
      begin
        LRejected := True;
      end;
    end;
    Check(LRejected and (Length(LMask) = 1), 'Unobserved joint alternative preserves prior mask');
    for LCase := 0 to 1 do
    begin
      LGenerated := LSession.CopyAccepted;
      if LCase = 0 then
      begin
        LGenerated[2].Tokens[0] := 'forged-performance-token';
      end
      else
      begin
        LGenerated[2].StateIndices[0] := -1;
      end;
      LRejected := False;
      try
        LPlan := LDefinition.Capture(LGenerated);
      except
        on EAudio do
        begin
          LRejected := True;
        end;
      end;
      Check(LRejected and (LPlan.CopySpans[1].Note = 48), 'Forged model path/token preserves accepted plan');
    end;
    LBefore := LSession.CopyAccepted;
    LSession.SetConstraints('performance', LDefinition.PerformanceConstraints(nil,
      [MakePerformanceValueLock(0, 69)]));
    Check(not LDefinition.AnalyzeProvider(ppPerformance,
      LDefinition.PerformanceConstraints(nil, [MakePerformanceValueLock(0, 69)]), LAnalysis),
      'Provider analysis exposes a structurally infeasible prefix lock');
    Check(not LSession.TryRegenerate(['performance'], 731, LGenerated, LSelective),
      'Observed pitch at incompatible prefix position rejects');
    LGenerated := LSession.CopyAccepted;
    for LIndex := 0 to High(LBefore[2].StateIndices) do
    begin
      Check(LBefore[2].StateIndices[LIndex] = LGenerated[2].StateIndices[LIndex],
        'Failed typed edit retains accepted provider history');
    end;
    LLimitedSession := LLimited.CreateSession;
    Check(LLimitedSession.TryGenerate(LGenerated, LReport), 'Short provider models have a valid symbolic prefix');
    LRejected := False;
    try
      LPlan := LLimited.Capture(LGenerated);
    except
      on EAudio do
      begin
        LRejected := True;
      end;
    end;
    Check(LRejected and (LPlan.CopySpans[1].Note = 48), 'Insufficient musical coverage preserves prior plan');
    FreeAndNil(LLimitedSession);
    FreeAndNil(LLimited);
    FreeAndNil(LDefinition);
    LSession.SetConstraints('performance', nil);
    Check(LSession.TryRegenerate(['performance'], 731, LGenerated, LSelective),
      'Session owns its models and recovers after definition release');
    FreeAndNil(LSession);
    LClock := LPlan.CopyClock;
    try
      Check((LClock.LengthTicks = 432) and (LClock.FrameAtTick(432, 44100) = 19845),
        'Detached plan clock survives definition and session release');
      LSpans := LPlan.CopySpans;
      LSpans[0].StartTick := 1;
      LRejected := False;
      try
        LPlan := TStylePerformancePlan.Create(LSpans, LClock, LPlan.CopyKeys);
      except
        on EAudio do
        begin
          LRejected := True;
        end;
      end;
      Check(LRejected and (LPlan.CopySpans[1].Note = 48), 'Invalid public plan preserves prior result');
    finally
      LClock.Free;
    end;
    FreeAndNil(LPlan);

    LClock := TTempoMap.Create(96, 7, [MakeTempoChange(0, 500000)]);
    try
      SetLength(LSpans, 1);
      LSpans[0].StartTick := 0;
      LSpans[0].EndTick := 7;
      LSpans[0].Kind := pskUnknown;
      LSpans[0].Note := -1;
      SetLength(LKeys, 1);
      LKeys[0].Key := MakeKeyContext(-1, dmMajor);
      LPlan := TStylePerformancePlan.Create(LSpans, LClock, LKeys);
      Check((LPlan.KeyAtTick(0).Root = -1) and (LPlan.CopySpans[0].Kind = pskUnknown),
        'Native plan admits unknown context/performance and independent PPQ');
    finally
      LClock.Free;
    end;
    FreeAndNil(LPlan);
    if (AChanging = '') and (ASingle = '') then
    begin
      WriteLn('Public performance API: detached ownership, joint edits, actual paths, coverage and recovery pass');
      Exit;
    end;
    LStyle := DecodeWaveStyle(ReadFileBytes(AChanging, MaximumStyleBytes));
    LOptions := DefaultStylePerformanceOptions;
    LOptions.KeyCells := 32;
    LOptions.TempoCells := 32;
    LDefinition := TStylePerformance.Create(LStyle, LOptions);
    FreeAndNil(LStyle);
    LSession := LDefinition.CreateSession;
    Check(LSession.TryGenerate(LGenerated, LReport), 'Independent changing provider scopes solve');
    LDescription := LDefinition.CopyProvider(ppTempo);
    Check((LDescription.Timing = sptUniform) and (LDescription.Scope.CellCount = 32) and
      (LDescription.StepTicks = LDefinition.StepTicks), 'Changing context retains its own uniform scope');
    LBefore := LSession.CopyAccepted;
    LSession.SetConstraints('key', LDefinition.KeyConstraints(
      [MakePerformanceKeyLock(3, MakeKeyContext(2, dmNaturalMinor))]));
    LSession.SetConstraints('tempo', LDefinition.TempoConstraints([MakePerformanceValueLock(3, 600000)]));
    Check(LSession.TryRegenerate(['key'], 731, LGenerated, LSelective), 'Pending typed provider edits solve together');
    for LIndex := 0 to High(LBefore[2].StateIndices) do
    begin
      Check(LBefore[2].StateIndices[LIndex] = LGenerated[2].StateIndices[LIndex],
        'Changing context retains measured performance latent state');
    end;
    LPlan := LDefinition.Capture(LGenerated);
    Check(SameKeyContext(LPlan.KeyAtTick(720), MakeKeyContext(2, dmNaturalMinor)),
      'Captured key has its independent PPQ boundary');
    LClock := LPlan.CopyClock;
    try
      Check(LClock.Intervals(720, 1)[0].MicrosecondsPerQuarter = 600000,
        'Captured tempo has its independent PPQ boundary');
    finally
      LClock.Free;
    end;
    FreeAndNil(LPlan);
    FreeAndNil(LSession);
    FreeAndNil(LDefinition);

    LStyle := DecodeWaveStyle(ReadFileBytes(ASingle, MaximumStyleBytes));
    LOptions := DefaultStylePerformanceOptions;
    LOptions.SpanCount := 1;
    LDefinition := TStylePerformance.Create(LStyle, LOptions);
    FreeAndNil(LStyle);
    LSession := LDefinition.CreateSession;
    LMask := LDefinition.PerformanceConstraints([MakePerformanceValueLock(0, 3812)],
      [MakePerformanceValueLock(0, 69)]);
    Check(Length(LMask) = 1, 'One-span joint control stays within one-cell scope');
    LSession.SetConstraints('performance', LMask);
    Check(LSession.TryGenerate(LGenerated, LReport), 'One-span joint control generates');
    LPlan := LDefinition.Capture(LGenerated);
    Check((LPlan.SpanCount = 1) and (LPlan.CopySpans[0].Note = 69), 'Single measured span is reusable');
    WriteLn('Public performance API: detached ownership, typed joint/context edits, actual paths, coverage and recovery pass');
  finally
    LEdited.Free;
    LPlan.Free;
    LLimitedSession.Free;
    LSession.Free;
    LLimited.Free;
    LDefinition.Free;
    LStyle.Free;
  end;
end;

procedure MappedAdmissionChecks;
var
  LClock: TTempoMap;
  LGrid: TMusicGridFrames;
  LAdmission: TRhythmAdmission;
begin
  LClock := TTempoMap.Create(480, 960,
    [MakeTempoChange(0, 500000), MakeTempoChange(480, 1000000)]);
  LGrid := nil;
  try
    LGrid := TMusicGridFrames.Create(LClock, 1000, 1600, 37, 0, 240, 4);
    LAdmission := AdmitWaveRhythm(LGrid, 2, [36, 37, 286, 537, 1037, 1537, 1599]);
    Check((LAdmission.Pattern = 'xxxx') and (LAdmission.Accepted = 4) and
      (LAdmission.FrameErrors[2] = 1) and (LAdmission.Decisions[0] = rodOutsideScope) and
      (LAdmission.Decisions[5] = rodOutsideScope) and
      (LAdmission.Decisions[6] = rodOutsideScope),
      'Changing tempo and offset preserve nearest-cell and outside-scope decisions');
  finally
    LGrid.Free;
    LClock.Free;
  end;
end;

procedure ChangingPitchContext(const ASource, APrefix: String);
var
  LClip: TAudioClip;
  LHash: String;
  LEvidence: TContextEvidenceArray;
  LBundle: TContextLearningBundle;
  LProfile: TContextProfile;
  LCell: Integer;
begin
  LClip := LoadWaveSource(ASource, LHash);
  LBundle := nil;
  LProfile := nil;
  try
    Check((LClip.SampleRate = 8000) and (LClip.Channels = 1) and
      (LClip.FrameCount = 70497), 'Independent changing-pitch fixture geometry');
    SetLength(LEvidence, 1);
    LEvidence[0].Name := ExtractFileName(ASource);
    LEvidence[0].SourceSha256 := LHash;
    LEvidence[0].SourceFrameOffset := 97;
    LEvidence[0].AdmissionPolicy := 'Authored harmonic pitch fixture; independent 120-to-100 BPM clock; source offset 97';
    LEvidence[0].Grid.TicksPerQuarter := 480;
    LEvidence[0].Grid.StepTicks := 240;
    SetLength(LEvidence[0].Grid.Keys, 32);
    SetLength(LEvidence[0].Grid.Tempos, 32);
    for LCell := 0 to 31 do
    begin
      LEvidence[0].Grid.Keys[LCell] := MakeKeyContext(0, dmMajor);
      LEvidence[0].Grid.Tempos[LCell] := 500000;
      if LCell >= 16 then
      begin
        LEvidence[0].Grid.Tempos[LCell] := 600000;
      end;
    end;
    LBundle := TContextLearningBundle.Create(LEvidence);
    LProfile := TContextProfile.Create(LBundle);
    WriteFileBytes(APrefix + '.pcp', EncodeContextProfile(LProfile));
  finally
    LProfile.Free;
    LBundle.Free;
    LClip.Free;
  end;
end;

procedure ModulationSource(const ASourceStyle, AOutput: String);
var
  LSource: TWaveStyleProfile;
  LOutput: TWaveStyleProfile;
  LOriginal: TContextProfile;
  LKeyProfile: TContextProfile;
  LSelected: TContextProfile;
  LBundle: TContextLearningBundle;
  LKeyBundle: TContextLearningBundle;
  LEvidence: TContextEvidenceArray;
  LCell: Integer;
begin
  LSource := nil;
  LOutput := nil;
  LOriginal := nil;
  LKeyProfile := nil;
  LSelected := nil;
  LBundle := nil;
  LKeyBundle := nil;
  try
    LSource := DecodeWaveStyle(ReadFileBytes(ASourceStyle, MaximumStyleBytes));
    Check(LSource.SourceCount = 1, 'Modulation fixture requires one preserved source');
    LOriginal := LSource.CopyContext;
    LBundle := LOriginal.CopyBundle(cdKey);
    LEvidence := LBundle.CopyEvidence;
    Check((Length(LEvidence) = 1) and (Length(LEvidence[0].Grid.Keys) = 32),
      'Modulation fixture uses the independent 32-cell context');
    LEvidence[0].AdmissionPolicy :=
      'Caller-authored output arrangement: C major then D natural minor; not measured source-key evidence';
    for LCell := 0 to 31 do
    begin
      LEvidence[0].Grid.Keys[LCell] := MakeKeyContext(0, dmMajor);
      if LCell >= 16 then
      begin
        LEvidence[0].Grid.Keys[LCell] := MakeKeyContext(2, dmNaturalMinor);
      end;
    end;
    LKeyBundle := TContextLearningBundle.Create(LEvidence);
    LKeyProfile := TContextProfile.Create(LKeyBundle);
    LSelected := SelectContextProfile(LKeyProfile, LOriginal);
    LOutput := TWaveStyleProfile.CreateSource(LSelected, LSource.EvidenceAt(0));
    WriteFileBytes(AOutput, LOutput.Encode);
    WriteLn('Saved caller-authored modulation provider with unchanged measured source evidence');
  finally
    LOutput.Free;
    LSelected.Free;
    LKeyProfile.Free;
    LKeyBundle.Free;
    LBundle.Free;
    LOriginal.Free;
    LSource.Free;
  end;
end;

procedure ChangingPitchStyle(const APath: String);
const
  CNotes: array[0..7] of Integer = (60, 62, 64, 67, 69, 67, 64, 60);
var
  LStyle: TWaveStyleProfile;
  LContext: TContextProfile;
  LCandidate: TWaveStyleProfile;
  LEvidence: TRhythmStyleEvidence;
  LGrid: TMusicGridFrames;
  LNotes: TPitchNotes;
  LSummary: TPitchCellSummary;
  LCell: Integer;
  LExpected: Integer;
  LRejected: Boolean;
  LTrack: TPitchTrack;
  LRaw: TPitchSpans;
  LTimed: TTimedPitchSpans;
  LStart: Integer;
  LEnd: Integer;
  LDense: TPitchTrackEvidence;
  LTimedTracks: TTimedPitchTracks;
  LDurationModel: TWfcSequenceModel;
  LFoundBefore: Boolean;
  LFoundAfter: Boolean;

  function ExpectedTick(const AFrame: Integer): Integer;
  begin
    if AFrame <= 32097 then
    begin
      Result := ((AFrame - 97) * 3 + 24) div 25;
    end
    else
    begin
      Result := 3840 + (AFrame - 32097 + 9) div 10;
    end;
  end;
begin
  LStyle := DecodeWaveStyle(ReadFileBytes(APath, MaximumStyleBytes));
  LGrid := nil;
  LContext := nil;
  LCandidate := nil;
  try
    LEvidence := LStyle.EvidenceAt(0);
    Check((LEvidence.SourceFrameOffset = 97) and (LEvidence.SourceCellCount = 32) and
      (Length(LEvidence.SourceClock) = 2) and (LEvidence.SourceClock[1].Tick = 3840) and
      (LEvidence.SourceClock[1].MicrosecondsPerQuarter = 600000),
      'Saved finite source clock retains changing tempo and physical origin');
    LGrid := CreateStyleSourceGrid(LEvidence, 480, 240);
    LSummary := SummarizePitchCells(LEvidence.Pitch, LGrid, 1);
    Check((LSummary.AdmittedPitch = 30) and (LSummary.MeasuredSilence = 2) and
      (LSummary.UncertainPitch = 0), 'Changing clock preserves measured pitch/silence evidence');
    LNotes := LStyle.PitchNotesAt(0);
    for LCell := 0 to 31 do
    begin
      LExpected := CNotes[LCell mod 8];
      if LCell in [15, 31] then
      begin
        LExpected := -1;
      end;
      Check(LNotes[LCell] = LExpected, 'Every saved pitch matches independent source content');
    end;
    if LStyle.HasDuration then
    begin
      LTrack := LStyle.CopyDurationTrack(0);
      try
        LRaw := LTrack.CopySpans;
        LTimed := LStyle.CopyTimedDurationSpans(0);
        Check(Length(LRaw) = Length(LTimed), 'Whole local scope retains each measured dense interval');
        for LCell := 0 to High(LRaw) do
        begin
          LStart := Max(97, LRaw[LCell].StartFrame);
          LEnd := Min(70497, LRaw[LCell].EndFrame);
          Check((LTimed[LCell].StartTick = ExpectedTick(LStart)) and
            (LTimed[LCell].EndTick = ExpectedTick(LEnd)) and
            (LTimed[LCell].Kind = LRaw[LCell].Kind) and (LTimed[LCell].Note = LRaw[LCell].Note),
            'Persisted dense spans follow independent piecewise source-clock arithmetic');
        end;
        WriteLn('Saved dense intervals normalize to PPQ ticks through both source tempos');
      finally
        LTrack.Free;
      end;
    end;
    LContext := LStyle.CopyContext;
    if LStyle.HasDuration then
    begin
      LEvidence.DurationArticulateOnsets := True;
      LEvidence.OnsetFrames := [1097, 33297];
      LEvidence.Dynamics := Default(TOnsetDynamics);
      LEvidence.Policy := 'Authored interior attack coordinates for source-clock mapping verification';
      LCandidate := TWaveStyleProfile.CreateSource(LContext, LEvidence);
      LTimed := LCandidate.CopyTimedDurationSpans(0);
      Check(Length(LTimed) = Length(LRaw) + 2, 'Both authored interior attacks split known spans');
      LFoundBefore := False;
      LFoundAfter := False;
      for LCell := 0 to High(LTimed) do
      begin
        LFoundBefore := LFoundBefore or (LTimed[LCell].StartTick = ExpectedTick(1097));
        LFoundAfter := LFoundAfter or (LTimed[LCell].StartTick = ExpectedTick(33297));
      end;
      Check(LFoundBefore and LFoundAfter, 'Attack mapping follows both source tempos and physical offset');
      FreeAndNil(LCandidate);
      LEvidence.OnsetFrames := [1096, 1097];
      LRejected := False;
      try
        LCandidate := TWaveStyleProfile.CreateSource(LContext, LEvidence);
      except
        on EAudio do
        begin
          LRejected := True;
        end;
      end;
      Check(LRejected and (LCandidate = nil), 'Distinct physical attacks collapsing to one PPQ tick reject');
      LEvidence.Duration := Default(TPitchTrackEvidence);
      LRejected := False;
      try
        LCandidate := TWaveStyleProfile.CreateSource(LContext, LEvidence);
      except
        on EAudio do
        begin
          LRejected := True;
        end;
      end;
      Check(LRejected and (LCandidate = nil), 'Articulation capability requires measured duration evidence');
      LEvidence.Duration.WindowFrames := -1;
      LRejected := False;
      try
        LCandidate := TWaveStyleProfile.CreateSource(LContext, LEvidence);
      except
        on EAudio do
        begin
          LRejected := True;
        end;
      end;
      Check(LRejected and (LCandidate = nil), 'Negative window cannot masquerade as an articulation capability');
      WriteLn('Articulation maps both source tempos and offset; collapsed attacks and missing duration reject');
      LEvidence := LStyle.EvidenceAt(0);
      LDense := LEvidence.Duration;
      LEvidence.Duration.Options.HopFrames := 2 * LDense.Options.HopFrames;
      LExpected := 1 + (LEvidence.Source.FrameCount - LDense.WindowFrames) div
        LEvidence.Duration.Options.HopFrames;
      LEvidence.Duration.Estimates := nil;
      SetLength(LEvidence.Duration.Estimates, LExpected);
      for LCell := 0 to LExpected - 1 do
      begin
        LEvidence.Duration.Estimates[LCell] := LDense.Estimates[LCell * 2];
      end;
      LCandidate := TWaveStyleProfile.CreateSource(LContext, LEvidence);
      LDurationModel := nil;
      try
        SetLength(LTimedTracks, 2);
        LTimedTracks[0] := LStyle.CopyTimedDurationSpans(0);
        LTimedTracks[1] := LCandidate.CopyTimedDurationSpans(0);
        LDurationModel := LearnPitchDurationModel(LTimedTracks, [1, 1], 2);
        Check(LCandidate.HasDuration and (LDurationModel <> nil),
          'Different measurement hops share musical duration units in the normalized corpus');
        WriteLn('80/160-frame measurement hops learn through the shared PPQ timebase');
      finally
        LDurationModel.Free;
        FreeAndNil(LCandidate);
      end;
      LEvidence := LStyle.EvidenceAt(0);
    end;
    LEvidence.SourceClock[1].MicrosecondsPerQuarter := 599999;
    LRejected := False;
    try
      LCandidate := TWaveStyleProfile.CreateSource(LContext, LEvidence);
    except
      on EAudio do
      begin
        LRejected := True;
      end;
    end;
    Check(LRejected and (LStyle.EvidenceAt(0).SourceClock[1].MicrosecondsPerQuarter = 600000),
      'Mismatched clock rejects and detached evidence cannot mutate the accepted source');
    WriteLn('Saved changing-clock pitch: 30 exact notes, two silent cells, origin and clock binding pass');
  finally
    LCandidate.Free;
    LContext.Free;
    LGrid.Free;
    LStyle.Free;
  end;
end;

procedure AdmissionChecks;
var
  LAdmission: TRhythmAdmission;
  LPrior: String;
  LRejected: Boolean;
begin
  LAdmission := AdmitWaveRhythm(1000, 2000, 500000, 480, 240, 100,
    [0, 125, 249, 250, 500, 750, 1750, 1980]);
  Check((LAdmission.Pattern = 'xxxx...x') and (LAdmission.Accepted = 5),
    'Independent admitted onset pattern');
  Check((LAdmission.Cells[1] = 0) and (LAdmission.FrameErrors[1] = -125) and
    (LAdmission.Decisions[1] = rodTooFar) and
    (LAdmission.Decisions[3] = rodCollision) and
    (LAdmission.Decisions[7] = rodOutsideScope), 'Tie/error/collision/end decisions');
  LPrior := LAdmission.Pattern;
  LRejected := False;
  try
    LAdmission := AdmitWaveRhythm(1000, 2000, 500000, 480, 240, 100, [500, 400]);
  except
    on EAudio do
    begin
      LRejected := True;
    end;
  end;
  Check(LRejected and (LAdmission.Pattern = LPrior), 'Invalid onset order preserves prior result');
end;

function SourceStyle(const AIndex: Integer; const ADynamics: Boolean = False;
  const AStartTick: Integer = 0): TWaveStyleProfile;
var
  LEvidence: TRhythmStyleEvidence;
  LContextEvidence: TContextEvidenceArray;
  LBundle: TContextLearningBundle;
  LContext: TContextProfile;
  LCell: Integer;
  LStepFrames: Integer;
  LOriginFrames: Integer;
begin
  LEvidence := Default(TRhythmStyleEvidence);
  LEvidence.Source.Name := 'Authored rhythm fixture ' + IntToStr(AIndex);
  LEvidence.Source.Sha256 := HashText(LEvidence.Source.Name);
  LEvidence.Source.Provenance := 'Native declared onset fixture; not recorded-music accuracy evidence';
  LEvidence.Source.SampleRate := 1000;
  LEvidence.Source.Channels := 1;
  LStepFrames := 250 + 50 * AIndex;
  LOriginFrames := LStepFrames * AStartTick div 240;
  LEvidence.Source.FrameCount := LOriginFrames + LStepFrames * 8;
  LEvidence.SourceStartTick := AStartTick;
  LEvidence.OnsetReportSha256 := HashText('Declared fixture onsets ' + IntToStr(AIndex));
  LEvidence.Analysis := DefaultAnalysisOptions;
  LEvidence.OnsetVersion := OnsetLocationVersion;
  LEvidence.Policy := 'Exact authored frame coordinates, no quantization error';
  LEvidence.TempoMicroseconds := 500000 + AIndex * 100000;
  if AIndex = 0 then
  begin
    LEvidence.OnsetFrames := [0, 500, 1000, 1500];
  end
  else
  begin
    LEvidence.OnsetFrames := [0, 300, 600, 900, 1500, 1800];
  end;
  for LCell := 0 to High(LEvidence.OnsetFrames) do
  begin
    Inc(LEvidence.OnsetFrames[LCell], LOriginFrames);
  end;
  if ADynamics then
  begin
    LEvidence.Dynamics.WindowFrames := 20;
    SetLength(LEvidence.Dynamics.Rms, Length(LEvidence.OnsetFrames));
    for LCell := 0 to High(LEvidence.Dynamics.Rms) do
    begin
      LEvidence.Dynamics.Rms[LCell] := (1 + LCell mod 4) / 4;
    end;
  end;
  SetLength(LContextEvidence, 1);
  LContextEvidence[0].Name := LEvidence.Source.Name;
  LContextEvidence[0].SourceSha256 := LEvidence.Source.Sha256;
  LContextEvidence[0].AdmissionPolicy := 'Explicit source clock declaration';
  LContextEvidence[0].Grid.TicksPerQuarter := 480;
  LContextEvidence[0].Grid.StepTicks := 240;
  LContextEvidence[0].Grid.StartTick := AStartTick;
  SetLength(LContextEvidence[0].Grid.Keys, 8);
  SetLength(LContextEvidence[0].Grid.Tempos, 8);
  for LCell := 0 to 7 do
  begin
    LContextEvidence[0].Grid.Keys[LCell] := MakeKeyContext(AIndex * 2, TDiatonicMode(AIndex));
    LContextEvidence[0].Grid.Tempos[LCell] := LEvidence.TempoMicroseconds;
  end;
  LBundle := TContextLearningBundle.Create(LContextEvidence);
  LContext := nil;
  try
    LContext := TContextProfile.Create(LBundle);
    Result := TWaveStyleProfile.CreateSource(LContext, LEvidence);
  finally
    LContext.Free;
    LBundle.Free;
  end;
end;

procedure GridCapabilityChecks;
var
  LBase: TWaveStyleProfile;
  LStyle: TWaveStyleProfile;
  LDefinition: TStyleGrid;
  LSession: TLearnedLayerSession;
  LBundle: TContextLearningBundle;
  LContext: TContextProfile;
  LEvidence: TContextEvidenceArray;
  LSource: TRhythmStyleEvidence;
  LOptions: TStyleGridOptions;
  LGenerated: TLayerSequences;
  LPlan: TStyleGridResult;
  LReport: TGraphNegotiationReport;
  LCase: Integer;
  LCell: Integer;
  LRejected: Boolean;
begin
  for LCase := 0 to 1 do
  begin
    LBase := nil;
    LStyle := nil;
    LDefinition := nil;
    LSession := nil;
    LBundle := nil;
    LContext := nil;
    try
      LBase := SourceStyle(0, LCase = 1);
      SetLength(LEvidence, 1);
      LEvidence[0] := Default(TContextEvidence);
      LEvidence[0].Name := 'Authored changing grid context';
      LEvidence[0].SourceSha256 := LBase.EvidenceAt(0).Source.Sha256;
      LEvidence[0].AdmissionPolicy := 'Explicit unknown and changing context control';
      LEvidence[0].Grid.TicksPerQuarter := 480;
      LEvidence[0].Grid.StepTicks := 240;
      SetLength(LEvidence[0].Grid.Keys, 8);
      SetLength(LEvidence[0].Grid.Tempos, 8);
      for LCell := 0 to 7 do
      begin
        LEvidence[0].Grid.Keys[LCell] := MakeKeyContext(-1, dmMajor);
        LEvidence[0].Grid.Tempos[LCell] := 500000;
        if LCell >= 4 then
        begin
          LEvidence[0].Grid.Keys[LCell] := MakeKeyContext(2, dmNaturalMinor);
          LEvidence[0].Grid.Tempos[LCell] := 600000;
        end;
      end;
      LBundle := TContextLearningBundle.Create(LEvidence);
      LContext := TContextProfile.Create(LBundle);
      LSource := LBase.EvidenceAt(0);
      LSource.SourceClock := [MakeTempoChange(0, 500000), MakeTempoChange(960, 600000)];
      LSource.SourceCellCount := 8;
      LSource.Source.FrameCount := 2200;
      LSource.OnsetFrames := [0, 500, 1000, 1600];
      LStyle := TWaveStyleProfile.CreateSource(LContext, LSource);
      LOptions := DefaultStyleGridOptions;
      LOptions.CellCount := 8;
      LOptions.Extent := wseWhole;
      LDefinition := TStyleGrid.Create(LStyle, LOptions);
      Check((LDefinition.ProviderCount = 3 + LCase) and
        (LDefinition.ProviderIndex(gpPitch) = -1) and
        (LDefinition.ProviderIndex(gpPitchRhythm) = -1),
        'Missing optional capabilities are explicit');
      LSession := LDefinition.CreateSession;
      FreeAndNil(LStyle);
      Check(LSession.TryGenerate(LGenerated, LReport), 'Small non-pitch grid scope solves');
      LPlan := LDefinition.Capture(LGenerated);
      Check((Length(LPlan.Pitches) = 0) and
        (Length(LPlan.Intensities) = 8 * LCase), 'Capture does not invent missing providers');
      Check((LPlan.Context.Keys[0].Root = -1) and
        (LPlan.Context.Keys[7].Root = 2) and
        (LPlan.Context.Tempos[0] = 500000) and (LPlan.Context.Tempos[7] = 600000),
        'Reusable grid preserves unknown/changing context rejected by authored voice policy');
      LRejected := False;
      try
        LDefinition.ValueConstraints(gpPitch, [MakeGridValueLock(0, 60)]);
      except
        on EAudio do
        begin
          LRejected := True;
        end;
      end;
      Check(LRejected, 'Absent provider cannot silently accept a lock');
    finally
      LSession.Free;
      LDefinition.Free;
      LStyle.Free;
      LContext.Free;
      LBundle.Free;
      LBase.Free;
    end;
  end;
  WriteLn('Grid capability controls: optional providers, eight-cell scope, unknown/changing context pass');
end;

function TimbreSource(const AIndex: Integer): TWaveStyleProfile;
var
  LBase: TWaveStyleProfile;
  LContext: TContextProfile;
  LEvidence: TRhythmStyleEvidence;
  LSamples: TAudioSamples;
  LClip: TAudioClip;
  LFrame: Integer;
  LAngle: Double;
  LGain: Double;
begin
  LBase := SourceStyle(AIndex);
  LContext := nil;
  LClip := nil;
  try
    LEvidence := LBase.EvidenceAt(0);
    SetLength(LSamples, LEvidence.Source.FrameCount);
    LGain := 0.2;
    if AIndex = 1 then
    begin
      LGain := -0.6;
    end;
    for LFrame := 0 to High(LSamples) do
    begin
      LAngle := 2 * Pi * 50 * (LFrame - 7) / LEvidence.Source.SampleRate;
      LSamples[LFrame] := 0.03 + LGain * Sin(LAngle) + 0.5 * LGain * Cos(3 * LAngle);
    end;
    LClip := TAudioClip.Create(LEvidence.Source.SampleRate, 1, LSamples);
    LEvidence.Timbre.StartFrame := 7;
    LEvidence.Timbre.FrameCount := 197;
    LEvidence.Timbre.Channel := 0;
    LEvidence.Timbre.MaximumRelativeError := 0.00001;
    LEvidence.Timbre.MinimumAcRms := 0.00001;
    LEvidence.Timbre.Policy := 'Controlled phase-opposed stationary tones at declared 50 Hz';
    LEvidence.Timbre.Fit := FitWavetableHarmonics(LClip, 7, 197, 0, 3, 50);
    LContext := LBase.CopyContext;
    Result := TWaveStyleProfile.CreateSource(LContext, LEvidence);
  finally
    LClip.Free;
    LContext.Free;
    LBase.Free;
  end;
end;

function EnvelopeSource(const AIndex: Integer): TWaveStyleProfile;
var
  LBase: TWaveStyleProfile;
  LContext: TContextProfile;
  LEvidence: TRhythmStyleEvidence;
  LClip: TAudioClip;
  LTrace: TEnvelopeTrace;
  LSamples: TAudioSamples;
  LLevel: Double;
  I: Integer;
begin
  LBase := TimbreSource(AIndex);
  LContext := nil;
  LClip := nil;
  LTrace := nil;
  try
    LEvidence := LBase.EvidenceAt(0);
    SetLength(LSamples, 96 + 16 * AIndex);
    for I := 0 to High(LSamples) do
    begin
      LLevel := 0;
      case I div 16 of
        1, 3: LLevel := 0.5 - AIndex * 0.25;
        2: LLevel := 1;
        4: LLevel := 0.25 - AIndex * 0.125;
      end;
      LSamples[I] := LLevel * (1 - 2 * (I mod 2));
    end;
    LClip := TAudioClip.Create(LEvidence.Source.SampleRate, 1, LSamples);
    LTrace := TEnvelopeTrace.Create(LClip, 0, Length(LSamples), 0, 16);
    LEvidence.Envelope.FrameCount := Length(LSamples);
    LEvidence.Envelope.WindowFrames := 16;
    LEvidence.Envelope.GateFrame := 39;
    LEvidence.Envelope.MaximumTailRatio := 0.01;
    LEvidence.Envelope.MinimumRms := 1E-5;
    LEvidence.Envelope.Policy := 'Controlled piecewise amplitudes; declared gate 39';
    LEvidence.Envelope.RmsPoints := LTrace.CopyRmsPoints;
    LContext := LBase.CopyContext;
    Result := TWaveStyleProfile.CreateSource(LContext, LEvidence);
  finally
    LTrace.Free;
    LClip.Free;
    LContext.Free;
    LBase.Free;
  end;
end;

procedure InstrumentChecks;
var
  LLeft: TWaveStyleProfile;
  LRight: TWaveStyleProfile;
  LBlend: TWaveStyleProfile;
  LSecond: TWaveStyleProfile;
  LLoaded: TWaveStyleProfile;
  LBefore: TStyleInstrument;
  LAfter: TStyleInstrument;
  LBad: TStyleInstrument;
  LZones: TStyleInstrumentZones;
  LBindings: TStyleInstruments;
  LCurve: TAutomationCurve;
  LEnvelope: TGateEnvelope;
  LFactory: TWavetableSourceFactory;
  LPoints: TAutomationPoints;
  LRecipe: TWavetableCycleRecipe;
  LExpected: TFrameTones;
  LActual: TFrameTones;
  LBeforeClip: TAudioClip;
  LAfterClip: TAudioClip;
  LExpectedClip: TAudioClip;
  LReport: TNoteRenderReport;
  LIdentity: String;
  LRejected: Boolean;
  LDifference: Double;
  I: Integer;
  J: Integer;
begin
  LLeft := nil;
  LRight := nil;
  LBlend := nil;
  LSecond := nil;
  LLoaded := nil;
  LBefore := nil;
  LAfter := nil;
  LBad := nil;
  LCurve := nil;
  LEnvelope := nil;
  LFactory := nil;
  LBeforeClip := nil;
  LAfterClip := nil;
  LExpectedClip := nil;
  try
    LLeft := EnvelopeSource(0);
    LRight := EnvelopeSource(1);
    LBlend := TWaveStyleProfile.CreateBlendLayers(LLeft, LRight,
      0, 0, 1, 0, 0, 0, 1, 1, 1, 1);
    LSecond := TWaveStyleProfile.CreateBlendLayers(LBlend, LLeft,
      0, 0, 1, 0, 0, 0, 1, 0, 1, 1);
    LLoaded := DecodeWaveStyle(LSecond.Encode);
    LIdentity := LLoaded.Identity;
    SetLength(LPoints, 1);
    LPoints[0].Value := 0.75;
    LCurve := TAutomationCurve.Create(LPoints);
    LEnvelope := LLeft.CopyGateEnvelope(44100);
    LRecipe := LLoaded.CopyTimbreRecipe;
    LFactory := TWavetableSourceFactory.Create(LRecipe.Sine, LRecipe.Cosine);
    SetLength(LZones, 2);
    for I := 0 to 1 do
    begin
      LZones[I].Zone.MinimumKey := 48 + I * 12;
      LZones[I].Zone.MaximumKey := 59 + I * 12;
      LZones[I].Zone.MinimumVelocity := 1;
      LZones[I].Zone.MaximumVelocity := 127;
      LZones[I].Zone.Voice := DefaultSynthVoice;
      LZones[I].Zone.Voice.Gain := 0.2;
      LZones[I].Zone.Voice.Pan := -1 + 2 * I;
      LZones[I].Zone.Voice.Automation.GainMultiplier := LCurve;
      LZones[I].Zone.Voice.GateEnvelope := LEnvelope;
      LZones[I].Timbre := LLoaded;
    end;
    LZones[1].Envelope := LLoaded;
    LBefore := TStyleInstrument.Create(LZones, 44100);
    LZones[1].Envelope := LRight;
    LAfter := TStyleInstrument.Create(LZones, 44100);
    Check((LBefore.TimbreIdentity(0) = LIdentity) and
      (LBefore.TimbreIdentity(1) = LIdentity) and
      (LBefore.EnvelopeIdentity(0) = '') and
      (LBefore.EnvelopeIdentity(1) = LIdentity), 'Independent instrument provenance');
    Check((Length(LBefore.SelectZones(48, 1)) = 1) and
      (LBefore.SelectZones(71, 127)[0] = 1), 'Instrument key boundaries');
    LActual := LBefore.PlanNote(48, 96, 0, 1720, 1);
    LExpected := Copy(LActual);
    LExpected[0].Voice := LZones[0].Zone.Voice;
    LExpected[0].Voice.SourceFactory := LFactory;
    LExpectedClip := RenderFrameTones(LExpected, 44100, 7000);

    { Disjoint velocity zones and overlapping layers use the same core contract. }
    LZones[1].Zone.MinimumKey := 48;
    LZones[1].Zone.MaximumKey := 59;
    LZones[0].Zone.MaximumVelocity := 80;
    LZones[1].Zone.MinimumVelocity := 81;
    LBad := TStyleInstrument.Create(LZones, 44100);
    Check((LBad.SelectZones(48, 80)[0] = 0) and
      (LBad.SelectZones(48, 81)[0] = 1), 'Instrument velocity boundaries');
    FreeAndNil(LBad);
    LZones[1].Zone.MinimumVelocity := 80;
    LBad := TStyleInstrument.Create(LZones, 44100);
    Check(Length(LBad.PlanNote(48, 80, 0, 1720, 1)) = 2, 'Instrument layered overlap');
    FreeAndNil(LBad);
    LZones[1].Zone.Voice.Gain := -1;
    LRejected := False;
    try
      LBad := TStyleInstrument.Create(LZones, 44100);
    except
      on EAudio do
      begin
        LRejected := True;
      end;
    end;
    Check(LRejected and (LBad = nil), 'Partially constructed instrument rejected safely');
    FreeAndNil(LLeft);
    FreeAndNil(LRight);
    FreeAndNil(LBlend);
    FreeAndNil(LSecond);
    FreeAndNil(LLoaded);
    FreeAndNil(LCurve);
    FreeAndNil(LEnvelope);
    FreeAndNil(LFactory);
    LZones := nil;

    LBeforeClip := RenderFrameTones(LActual, 44100, 7000);
    for I := 0 to LBeforeClip.FrameCount - 1 do
    begin
      for J := 0 to 1 do
      begin
        Check(LBeforeClip.SampleAt(I, J) = LExpectedClip.SampleAt(I, J),
          'Instrument sound equals independently constructed source after inputs freed');
      end;
    end;
    FreeAndNil(LBeforeClip);
    for J := 0 to 1 do
    begin
      LBeforeClip := RenderFrameTones(LBefore.PlanNote(48 + J * 12, 96, 0, 1720, 1),
        44100, 7000);
      LAfterClip := RenderFrameTones(LAfter.PlanNote(48 + J * 12, 96, 0, 1720, 1),
        44100, 7000);
      LDifference := 0;
      Check(LBeforeClip.FrameCount = LAfterClip.FrameCount, 'Instrument comparison extent');
      for I := 0 to LBeforeClip.FrameCount - 1 do
      begin
        LDifference := Max(LDifference,
          Abs(LBeforeClip.SampleAt(I, J) - LAfterClip.SampleAt(I, J)));
      end;
      Check(((J = 0) and (LDifference = 0)) or ((J = 1) and (LDifference > 0.001)),
        'Envelope edit changes only the selected instrument zone');
      FreeAndNil(LAfterClip);
      FreeAndNil(LBeforeClip);
    end;
    SetLength(LBindings, 1);
    LBindings[0] := LBefore;
    LRejected := False;
    try
      LActual := PlanStyleNoteTones(nil, 48000, LBindings, LReport);
    except
      on EAudio do
      begin
        LRejected := True;
      end;
    end;
    Check(LRejected and (Length(LActual) = 1) and (LReport.RenderedTones = 0),
      'Rate mismatch preserves prior instrument plan and resets report');
    WriteLn('Style instruments: independent zone choices, saved second blend, owned resources and exact unaffected audio pass');
  finally
    LExpectedClip.Free;
    LAfterClip.Free;
    LBeforeClip.Free;
    LFactory.Free;
    LEnvelope.Free;
    LCurve.Free;
    LBad.Free;
    LAfter.Free;
    LBefore.Free;
    LLoaded.Free;
    LSecond.Free;
    LBlend.Free;
    LRight.Free;
    LLeft.Free;
  end;
end;

procedure EnvelopeChecks(const APrefix: String);
var
  LLeft: TWaveStyleProfile;
  LRight: TWaveStyleProfile;
  LBlend: TWaveStyleProfile;
  LSecond: TWaveStyleProfile;
  LLoaded: TWaveStyleProfile;
  LOmitted: TWaveStyleProfile;
  LBad: TWaveStyleProfile;
  LEnvelope: TGateEnvelope;
  LOtherEnvelope: TGateEnvelope;
  LTones: TFrameTones;
  LRendered: TAudioClip;
  LEdited: TAudioClip;
  LRightDifference: Double;
  I: Integer;
  LEvidence: TRhythmStyleEvidence;
  LContext: TContextProfile;
  LBefore: TWfcSequenceModel;
  LAfter: TWfcSequenceModel;
  LBytes: TAudioBytes;
  LIdentity: String;
  LRejected: Boolean;
begin
  LLeft := nil;
  LRight := nil;
  LBlend := nil;
  LSecond := nil;
  LLoaded := nil;
  LOmitted := nil;
  LBad := nil;
  LEnvelope := nil;
  LOtherEnvelope := nil;
  LRendered := nil;
  LEdited := nil;
  LContext := nil;
  LBefore := nil;
  LAfter := nil;
  try
    LLeft := EnvelopeSource(0);
    LRight := EnvelopeSource(1);
    LBlend := TWaveStyleProfile.CreateBlendLayers(LLeft, LRight, 0, 0,
      1, 0, 0, 0, 1, 0, 1, 3);
    Check((LBlend.EnvelopeWeightAt(1) = 3) and (LBlend.TimbreWeightAt(1) = 0) and
      (LBlend.RhythmWeightAt(1) = 0), 'A source may contribute only envelope evidence');
    LEnvelope := LBlend.CopyGateEnvelope(2000);
    Check((Abs(LEnvelope.ValueAt(46, 78) - 0.3125) < 1E-12) and
      (Abs(LEnvelope.ValueAt(110, 78) - 0.3125) < 1E-12) and
      (LEnvelope.ReleaseFrames = 146), 'Weighted held/release curves preserve absolute time and longest tail');
    FreeAndNil(LEnvelope);
    LSecond := TWaveStyleProfile.CreateBlendLayers(LBlend, LLeft, 0, 0,
      1, 0, 0, 0, 1, 0, 1, 1);
    Check((LSecond.EnvelopeWeightAt(0) = 2) and (LSecond.EnvelopeWeightAt(1) = 3),
      'Second envelope derivation coalesces independent source weights');
    LBefore := LLeft.CopyRhythmModel;
    LAfter := LSecond.CopyRhythmModel;
    Check(EncodeWfcSequenceText(LBefore) = EncodeWfcSequenceText(LAfter),
      'Envelope blend preserves the actual rhythm model');
    LBytes := LSecond.Encode;
    LIdentity := LSecond.Identity;
    if APrefix <> '' then
    begin
      WriteFileBytes(APrefix + '-envelope.pys', LBytes);
    end;
    FreeAndNil(LSecond);
    FreeAndNil(LBlend);
    FreeAndNil(LRight);
    LLoaded := DecodeWaveStyle(LBytes);
    Check(LLoaded.Identity = LIdentity, 'Envelope second blend survives full saved replay');
    LEvidence := LLoaded.EvidenceAt(0);
    LEvidence.Envelope.RmsPoints[1].Value := 0.9;
    LEnvelope := LLoaded.CopyGateEnvelope(2000);
    Check((Abs(LEnvelope.ValueAt(46, 78) - 0.35) < 1E-12) and
      (Abs(LEnvelope.ValueAt(110, 78) - 0.35) < 1E-12), 'Detached envelope evidence and independent weighted arithmetic');
    LOmitted := TWaveStyleProfile.CreateBlendLayers(LLoaded, LLeft, 0, 0,
      1, 0, 0, 0, 1, 0, 0, 0);
    Check(not LOmitted.HasEnvelope, 'Explicit zero weights omit the envelope dimension');
    LRejected := False;
    try
      LBad := TWaveStyleProfile.CreateBlendLayers(LLoaded, LOmitted, 0, 0,
        1, 0, 0, 0, 1, 0, 0, 1);
    except
      on EAudio do
      begin
        LRejected := True;
      end;
    end;
    Check(LRejected and (LBad = nil), 'Missing selected envelope rejects before publication');
    LEvidence := LLeft.EvidenceAt(0);
    Inc(LEvidence.Envelope.RmsPoints[0].Frame);
    LContext := LLeft.CopyContext;
    LRejected := False;
    try
      LBad := TWaveStyleProfile.CreateSource(LContext, LEvidence);
    except
      on EAudio do
      begin
        LRejected := True;
      end;
    end;
    Check(LRejected and (LBad = nil), 'Forged RMS coordinates reject during source admission');
    FreeAndNil(LLoaded);
    Check(Abs(LEnvelope.ValueAt(110, 78) - 0.35) < 1E-12,
      'Rendered envelope survives release of its saved profile');
    LOtherEnvelope := LLeft.CopyGateEnvelope(2000);
    FreeAndNil(LLeft);
    SetLength(LTones, 2);
    for I := 0 to 1 do
    begin
      LTones[I].Voice := DefaultSynthVoice;
      LTones[I].Voice.CutoffHz := 800;
      LTones[I].Voice.Pan := I * 2 - 1;
      LTones[I].Voice.GateEnvelope := LOtherEnvelope;
      LTones[I].GateFrames := 78;
      LTones[I].FrequencyHz := 100;
      LTones[I].Velocity := 1;
    end;
    LTones[1].Voice.GateEnvelope := LEnvelope;
    LRendered := RenderFrameTones(LTones, 2000, 300);
    LTones[1].Voice.GateEnvelope := LOtherEnvelope;
    LEdited := RenderFrameTones(LTones, 2000, 300);
    LRightDifference := 0;
    for I := 0 to 299 do
    begin
      Check(Abs(LRendered.SampleAt(I, 0) - LEdited.SampleAt(I, 0)) < 1E-12,
        'A per-voice envelope edit preserves the independent left voice');
      LRightDifference := Max(LRightDifference,
        Abs(LRendered.SampleAt(I, 1) - LEdited.SampleAt(I, 1)));
    end;
    Check(LRightDifference > 0.001, 'Independent saved envelope bindings change the selected voice');
    WriteLn('Saved envelopes: independent weights, unequal tails, second derivation, raw evidence, ownership and rejection pass');
  finally
    LAfter.Free;
    LBefore.Free;
    LContext.Free;
    LEdited.Free;
    LRendered.Free;
    LOtherEnvelope.Free;
    LEnvelope.Free;
    LBad.Free;
    LOmitted.Free;
    LLoaded.Free;
    LSecond.Free;
    LBlend.Free;
    LRight.Free;
    LLeft.Free;
  end;
end;

function TrajectorySource(const AIndex: Integer): TWaveStyleProfile;
var
  LBase: TWaveStyleProfile;
  LContext: TContextProfile;
  LEvidence: TRhythmStyleEvidence;
  LClip: TAudioClip;
  LSamples: TAudioSamples;
  LFrame: Integer;
  LKnot: Integer;
  LHarmonic: Integer;
begin
  LBase := EnvelopeSource(AIndex);
  LContext := nil;
  LClip := nil;
  try
    LEvidence := LBase.EvidenceAt(0);
    LEvidence.Timbre := Default(THarmonicStyleEvidence);
    LEvidence.TimbreTrajectory.OriginFrame := 7;
    SetLength(LEvidence.TimbreTrajectory.Knots, 2);
    SetLength(LSamples, LEvidence.Source.FrameCount);
    for LFrame := 0 to High(LSamples) do
    begin
      LHarmonic := 1 + AIndex;
      if LFrame >= 207 + 100 * AIndex then
      begin
        LHarmonic := 3 - 2 * AIndex;
      end;
      LSamples[LFrame] := 0.03 + (0.2 + AIndex * 0.4) *
        Sin(2 * Pi * LHarmonic * 50 * LFrame / 1000);
    end;
    LClip := TAudioClip.Create(1000, 1, LSamples);
    for LKnot := 0 to 1 do
    begin
      LEvidence.TimbreTrajectory.Knots[LKnot].StartFrame := 7 + 200 * LKnot + 100 * AIndex;
      LEvidence.TimbreTrajectory.Knots[LKnot].FrameCount := 101;
      LEvidence.TimbreTrajectory.Knots[LKnot].MaximumRelativeError := 1E-5;
      LEvidence.TimbreTrajectory.Knots[LKnot].MinimumAcRms := 1E-5;
      LEvidence.TimbreTrajectory.Knots[LKnot].Policy := 'Authored changing harmonics; fixed 50 Hz; declared origin';
      LEvidence.TimbreTrajectory.Knots[LKnot].Fit := FitWavetableHarmonics(LClip,
        LEvidence.TimbreTrajectory.Knots[LKnot].StartFrame, 101, 0, 3, 50);
    end;
    LContext := LBase.CopyContext;
    Result := TWaveStyleProfile.CreateSource(LContext, LEvidence);
  finally
    LClip.Free;
    LContext.Free;
    LBase.Free;
  end;
end;

procedure TrajectoryChecks(const APrefix: String);
var
  LLeft: TWaveStyleProfile;
  LRight: TWaveStyleProfile;
  LBlend: TWaveStyleProfile;
  LSecond: TWaveStyleProfile;
  LLoaded: TWaveStyleProfile;
  LBad: TWaveStyleProfile;
  LContext: TContextProfile;
  LEvidence: TRhythmStyleEvidence;
  LFactory: TWavetableSourceFactory;
  LBoundFactory: TWavetableSourceFactory;
  LExpectedFactory: TWavetableSourceFactory;
  LSource: TAudioSource;
  LExpected: TAudioSource;
  LBeforeModel: TWfcSequenceModel;
  LAfterModel: TWfcSequenceModel;
  LBeforeEnvelope: TGateEnvelope;
  LAfterEnvelope: TGateEnvelope;
  LRecipes: TWavetableCycleRecipes;
  LPoints: TAutomationPoints;
  LCurve: TAutomationCurve;
  LBytes: TAudioBytes;
  LIdentity: String;
  LValue: Double;
  LReference: Double;
  LRightSample: Double;
  LA: Double;
  LB: Double;
  LNormA: Double;
  LNormB: Double;
  I: Integer;
  LRejected: Boolean;
  LSeedKnot: THarmonicStyleEvidence;
begin
  LLeft := nil;
  LRight := nil;
  LBlend := nil;
  LSecond := nil;
  LLoaded := nil;
  LBad := nil;
  LContext := nil;
  LFactory := nil;
  LBoundFactory := nil;
  LExpectedFactory := nil;
  LSource := nil;
  LExpected := nil;
  LBeforeModel := nil;
  LAfterModel := nil;
  LBeforeEnvelope := nil;
  LAfterEnvelope := nil;
  LCurve := nil;
  try
    LLeft := TrajectorySource(0);
    LRight := TrajectorySource(1);
    LBlend := TWaveStyleProfile.CreateBlendLayers(LLeft, LRight, 0, 0, 1, 0, 0, 0, 1, 3, 1, 0);
    LSecond := TWaveStyleProfile.CreateBlendLayers(LBlend, LLeft, 0, 0, 1, 0, 0, 0, 1, 1, 0, 1);
    Check(LSecond.HasTimbreTrajectory and (LSecond.TimbreWeightAt(0) = 2) and
      (LSecond.TimbreWeightAt(1) = 3) and (LSecond.EnvelopeWeightAt(1) = 0),
      'Trajectory second blend retains independent timbre/envelope weights');
    LBeforeModel := LLeft.CopyRhythmModel;
    LAfterModel := LSecond.CopyRhythmModel;
    Check(EncodeWfcSequenceText(LBeforeModel) = EncodeWfcSequenceText(LAfterModel),
      'Trajectory-only blending preserves the actual rhythm model');
    LBeforeEnvelope := LLeft.CopyGateEnvelope(2000);
    LAfterEnvelope := LSecond.CopyGateEnvelope(2000);
    for I := 0 to 299 do
    begin
      Check(LBeforeEnvelope.ValueAt(I, 78) = LAfterEnvelope.ValueAt(I, 78),
        'Trajectory blending preserves the independently selected measured envelope');
    end;
    LBytes := LSecond.Encode;
    LIdentity := LSecond.Identity;
    if APrefix <> '' then
    begin
      WriteFileBytes(APrefix + '-trajectory.pys', LBytes);
    end;
    FreeAndNil(LSecond);
    FreeAndNil(LBlend);
    FreeAndNil(LRight);
    LLoaded := DecodeWaveStyle(LBytes);
    Check((LLoaded.Identity = LIdentity) and (LLoaded.Depth = 3) and
      (LLoaded.SourceCount = 2) and LLoaded.HasTimbreTrajectory,
      'Saved trajectory reblend survives parent release with canonical identity');
    LEvidence := LLoaded.EvidenceAt(0);
    Check((LEvidence.TimbreTrajectory.OriginFrame = 7) and
      (LEvidence.TimbreTrajectory.Knots[1].StartFrame = 207) and
      (LEvidence.TimbreTrajectory.Knots[1].Fit.RelativeError < 1E-5),
      'Raw trajectory fit, origin and residual survive encoding');
    LEvidence.TimbreTrajectory.Knots[0].Fit.Recipe.Sine[0] := 16;
    LFactory := LLoaded.CopyTimbreFactory(2000, 0.2);
    SetLength(LRecipes, 4);
    SetLength(LPoints, 4);
    for I := 0 to 3 do
    begin
      LPoints[I].Frame := 100 + 200 * I;
      LPoints[I].Value := I;
      LPoints[I].Transition := atLinear;
      LA := Min(1, Max(0, I / 2));
      LB := Min(1, Max(0, (I - 1) / 2));
      LNormA := Sqrt((Sqr(1 - LA) + Sqr(LA)) / 2);
      LNormB := Sqrt((Sqr(1 - LB) + Sqr(LB)) / 2);
      SetLength(LRecipes[I].Sine, 3);
      LRecipes[I].Sine[0] := (2 * (1 - LA) / LNormA + 3 * LB / LNormB) / 5;
      LRecipes[I].Sine[1] := 3 * (1 - LB) / LNormB / 5;
      LRecipes[I].Sine[2] := 2 * LA / LNormA / 5;
    end;
    LCurve := TAutomationCurve.Create(LPoints);
    LExpectedFactory := TWavetableSourceFactory.CreateMagnitudeTrajectory(LRecipes, LCurve, 0.2);
    LSource := LFactory.CreateSource(2000, 1);
    LExpected := LExpectedFactory.CreateSource(2000, 2);
    FreeAndNil(LLoaded);
    for I := 0 to 999 do
    begin
      LSource.ReadFrame(50, LValue, LRightSample);
      LExpected.ReadFrame(50, LReference, LRightSample);
      Check(Abs(LValue - LReference) < 1E-7,
        'Detached saved factory matches authored union-knot weighted shapes');
    end;
    LRejected := False;
    try
      LFactory := LLeft.CopyTimbreFactory(1);
    except
      on EAudio do
      begin
        LRejected := True;
      end;
    end;
    Check(LRejected and (LFactory.Channels = 1), 'Collapsed retimed knots preserve accepted factory');
    LEvidence := LLeft.EvidenceAt(0);
    LEvidence.TimbreTrajectory.Knots[1].Fit.FrequencyHz := 51;
    LContext := LLeft.CopyContext;
    LRejected := False;
    try
      LBad := TWaveStyleProfile.CreateSource(LContext, LEvidence);
    except
      on EAudio do
      begin
        LRejected := True;
      end;
    end;
    Check(LRejected and (LBad = nil), 'Undeclared pitch changes reject trajectory admission');
    LEvidence := LLeft.EvidenceAt(0);
    LSeedKnot := LEvidence.TimbreTrajectory.Knots[0];
    SetLength(LEvidence.TimbreTrajectory.Knots, 32);
    for I := 0 to 31 do
    begin
      LEvidence.TimbreTrajectory.Knots[I] := LSeedKnot;
      LEvidence.TimbreTrajectory.Knots[I].StartFrame := 7 + 2 * I;
    end;
    LBad := TWaveStyleProfile.CreateSource(LContext, LEvidence);
    LBoundFactory := LBad.CopyTimbreFactory(2000);
    Check(LBoundFactory.Channels = 1, 'Exactly 32 trajectory knots remain renderable');
    LLoaded := DecodeWaveStyle(LBad.Encode);
    Check(Length(LLoaded.EvidenceAt(0).TimbreTrajectory.Knots) = 32,
      'Maximum knot count survives canonical source decoding');
    FreeAndNil(LLoaded);
    LRight := TrajectorySource(1);
    LEvidence := LRight.EvidenceAt(0);
    LEvidence.TimbreTrajectory.Knots[0].StartFrame := 8;
    LEvidence.TimbreTrajectory.Knots[1].StartFrame := 10;
    FreeAndNil(LContext);
    LContext := LRight.CopyContext;
    LSecond := TWaveStyleProfile.CreateSource(LContext, LEvidence);
    LBlend := TWaveStyleProfile.CreateBlendLayers(LBad, LSecond, 0, 0, 1, 0, 0, 0, 1, 1, 0, 0);
    LRejected := False;
    try
      LBoundFactory := LBlend.CopyTimbreFactory(2000);
    except
      on EAudio do
      begin
        LRejected := True;
      end;
    end;
    Check(LRejected and (LBoundFactory.Channels = 1),
      'Oversized union rejects without decimating evidence or replacing a factory');
    WriteLn('Saved trajectories: raw evidence, union shapes, independent weights, second blend and ownership pass');
  finally
    LCurve.Free;
    LAfterEnvelope.Free;
    LBeforeEnvelope.Free;
    LAfterModel.Free;
    LBeforeModel.Free;
    LExpected.Free;
    LSource.Free;
    LExpectedFactory.Free;
    LBoundFactory.Free;
    LFactory.Free;
    LContext.Free;
    LBad.Free;
    LLoaded.Free;
    LSecond.Free;
    LBlend.Free;
    LRight.Free;
    LLeft.Free;
  end;
end;

procedure TimbreChecks(const APrefix: String);
var
  LLeft: TWaveStyleProfile;
  LRight: TWaveStyleProfile;
  LBlend: TWaveStyleProfile;
  LSecond: TWaveStyleProfile;
  LLoaded: TWaveStyleProfile;
  LOmitted: TWaveStyleProfile;
  LBad: TWaveStyleProfile;
  LContext: TContextProfile;
  LEvidence: TRhythmStyleEvidence;
  LRecipe: TWavetableCycleRecipe;
  LBytes: TAudioBytes;
  LBefore: TWfcSequenceModel;
  LAfter: TWfcSequenceModel;
  LRejected: Boolean;
  LIdentity: String;
begin
  LLeft := nil;
  LRight := nil;
  LBlend := nil;
  LSecond := nil;
  LLoaded := nil;
  LOmitted := nil;
  LBad := nil;
  LContext := nil;
  LBefore := nil;
  LAfter := nil;
  try
    LLeft := TimbreSource(0);
    LRight := TimbreSource(1);
    LBlend := TWaveStyleProfile.CreateBlendLayers(LLeft, LRight, 0, 0, 1, 0, 0, 0, 1, 3);
    Check((LBlend.SourceCount = 2) and (LBlend.RhythmWeightAt(1) = 0) and
      (LBlend.PitchWeightAt(1) = 0) and (LBlend.TimbreWeightAt(1) = 3),
      'A source can contribute only timbre');
    LRecipe := LBlend.CopyTimbreRecipe;
    Check((Abs(LRecipe.Sine[0] - 0.5) < 1E-7) and
      (Abs(LRecipe.Sine[2] - 0.25) < 1E-7) and
      (LRecipe.Cosine[0] = 0) and (LRecipe.Mean = 0),
      'Phase-opposed measurements blend magnitudes without cancellation or DC');
    LSecond := TWaveStyleProfile.CreateBlendLayers(LBlend, LLeft, 0, 0, 1, 0, 0, 0, 1, 1);
    Check((LSecond.TimbreWeightAt(0) = 2) and (LSecond.TimbreWeightAt(1) = 3) and
      (LSecond.Depth = 3) and (LSecond.NodeCount = 5), 'Second timbre derivation coalesces evidence and retains ancestry');
    LBefore := LLeft.CopyRhythmModel;
    LAfter := LSecond.CopyRhythmModel;
    Check(EncodeWfcSequenceText(LBefore) = EncodeWfcSequenceText(LAfter),
      'Independent timbre blend retains exact actual rhythm model');
    LBytes := LSecond.Encode;
    if APrefix <> '' then
    begin
      WriteFileBytes(APrefix + '-timbre.pys', LBytes);
    end;
    LIdentity := LSecond.Identity;
    FreeAndNil(LSecond);
    FreeAndNil(LBlend);
    FreeAndNil(LRight);
    LLoaded := DecodeWaveStyle(LBytes);
    LRecipe := LLoaded.CopyTimbreRecipe;
    Check((LLoaded.Identity = LIdentity) and (Abs(LRecipe.Sine[0] - 0.44) < 1E-7),
      'Saved second blend owns its evidence after parents are released');
    LEvidence := LLoaded.EvidenceAt(0);
    LEvidence.Timbre.Fit.Recipe.Sine[0] := 15;
    LRecipe.Sine[0] := 15;
    LRecipe := LLoaded.CopyTimbreRecipe;
    Check(Abs(LRecipe.Sine[0] - 0.44) < 1E-7, 'Returned evidence and recipe arrays are detached');
    LOmitted := TWaveStyleProfile.CreateBlendLayers(LLoaded, LLeft, 0, 0, 1, 0, 0, 0, 0, 0);
    Check(not LOmitted.HasTimbre, 'Explicit zero weights omit timbre');
    LRejected := False;
    try
      LBad := TWaveStyleProfile.CreateBlendLayers(LLoaded, LOmitted, 0, 0, 1, 0, 0, 0, 0, 1);
    except
      on EAudio do
      begin
        LRejected := True;
      end;
    end;
    Check(LRejected and (LBad = nil), 'Missing selected timbre rejects without a candidate');
    LEvidence := LLeft.EvidenceAt(0);
    LEvidence.Timbre.Fit.RelativeError := 0.9;
    LContext := LLeft.CopyContext;
    LRejected := False;
    try
      LBad := TWaveStyleProfile.CreateSource(LContext, LEvidence);
    except
      on EAudio do
      begin
        LRejected := True;
      end;
    end;
    Check(LRejected and (LBad = nil), 'Invalid timbre residual/admission evidence rejects');
    WriteLn('Stationary timbre: weighted magnitudes, independent models, saved second derivation, ownership and rejection pass');
  finally
    LAfter.Free;
    LBefore.Free;
    LContext.Free;
    LBad.Free;
    LOmitted.Free;
    LLoaded.Free;
    LSecond.Free;
    LBlend.Free;
    LRight.Free;
    LLeft.Free;
  end;
end;

procedure PhaseStyleChecks;
var
  LLeft: TWaveStyleProfile;
  LRight: TWaveStyleProfile;
  LBlend: TWaveStyleProfile;
  LReblend: TWaveStyleProfile;
  LLoaded: TWaveStyleProfile;
  LAdmission: TRhythmAdmission;
begin
  LAdmission := AdmitWaveRhythm(1000, 2125, 500000, 480, 240, 1000,
    [124, 125, 375, 2124], 120);
  Check((LAdmission.Pattern = 'xx......') and
    (LAdmission.Decisions[0] = rodOutsideScope) and
    (LAdmission.Decisions[3] = rodOutsideScope),
    'Leading and trailing onsets remain outside a shifted source scope');
  LLeft := nil;
  LRight := nil;
  LBlend := nil;
  LReblend := nil;
  LLoaded := nil;
  try
    LLeft := SourceStyle(0, True, 120);
    LRight := SourceStyle(1, True);
    LBlend := TWaveStyleProfile.CreateBlend(LLeft, LRight, 0, 1, 2, 1);
    LReblend := TWaveStyleProfile.CreateBlend(LBlend, LLeft, 0, 0, 2, 1);
    LLoaded := DecodeWaveStyle(LReblend.Encode);
    Check((LLoaded.Identity = LReblend.Identity) and
      (LLoaded.EvidenceAt(0).SourceStartTick = 120) and
      (LLoaded.EvidenceAt(1).SourceStartTick = 0) and
      (LLoaded.AdmissionAt(0).Pattern = 'x.x.x.x.') and
      (LLoaded.Depth = 3), 'Independent source origins survive weighted second derivation');
  finally
    LLoaded.Free;
    LReblend.Free;
    LBlend.Free;
    LRight.Free;
    LLeft.Free;
  end;
end;

procedure PhaseArchiveChecks(const AShifted, AZero, AReblend: String);
var
  LShifted: TWaveStyleProfile;
  LZero: TWaveStyleProfile;
  LReblend: TWaveStyleProfile;
  LNotes: TPitchNotes;
  LEvidence: TRhythmStyleEvidence;
  LSummary: TPitchCellSummary;
  LContext: TContextProfile;
begin
  LShifted := nil;
  LZero := nil;
  LReblend := nil;
  try
    LShifted := DecodeWaveStyle(ReadFileBytes(AShifted, MaximumStyleBytes));
    LZero := DecodeWaveStyle(ReadFileBytes(AZero, MaximumStyleBytes));
    LReblend := DecodeWaveStyle(ReadFileBytes(AReblend, MaximumStyleBytes));
    Check((LShifted.EvidenceAt(0).Source.Sha256 = LZero.EvidenceAt(0).Source.Sha256) and
      (LShifted.EvidenceAt(0).SourceStartTick > 0) and (LZero.EvidenceAt(0).SourceStartTick = 0) and
      (LShifted.AdmissionAt(0).Accepted = 7) and (LZero.AdmissionAt(0).Accepted = 0),
      'Selected phase changes admission of the same measured recording');
    LNotes := LShifted.PitchNotesAt(0);
    LEvidence := LShifted.EvidenceAt(0);
    LContext := LShifted.CopyContext;
    try
      LSummary := SummarizePitchCells(LEvidence.Pitch, LEvidence.Source.SampleRate,
        LEvidence.Source.Channels, LEvidence.Source.FrameCount, LEvidence.TempoMicroseconds,
        LContext.TicksPerQuarter, LContext.StepTicks, LEvidence.SourceStartTick);
      Check((LSummary.Cells = 15) and (LSummary.AdmittedPitch = 11) and
        (LSummary.UncertainPitch = 4) and (LSummary.Unmeasured = 0) and
        (LSummary.MeasuredSilence = 0) and (LSummary.KnownRuns = 5) and
        (LSummary.LongestKnownRun = 5), 'Non-periodic decay windows remain uncertain, not silent');
    finally
      LContext.Free;
    end;
    Check((Length(LNotes) = 15) and (LNotes[0] = 60) and (LNotes[2] = 64) and
      (LNotes[4] = 67) and (LNotes[6] = 72),
      'Known shifted phrase pitches are measured in the aligned source windows');
    Check((LReblend.SourceCount = 2) and (LReblend.Depth = 3) and
      (LReblend.EvidenceAt(0).SourceStartTick = LShifted.EvidenceAt(0).SourceStartTick) and
      (LReblend.EvidenceAt(1).SourceStartTick <> LReblend.EvidenceAt(0).SourceStartTick),
      'Second derivation retains independently aligned source evidence');
    WriteLn('Phase changes onset admission, aligns measured pitch windows and survives second derivation');
  finally
    LReblend.Free;
    LZero.Free;
    LShifted.Free;
  end;
end;

procedure CompareWeightedModel(const AStyle: TWaveStyleProfile);
const
  CPatterns: array[0..2] of String = ('x.x.x.x.', 'x.x.x.x.', 'xxxx.xx.');
var
  LSamples: TWfcSequenceSamples;
  LTokens: TWfcModelTokens;
  LExpected: TWfcSequenceModel;
  LActual: TWfcSequenceModel;
  LSample: Integer;
  LCell: Integer;
begin
  SetLength(LSamples, 3);
  for LSample := 0 to 2 do
  begin
    SetLength(LTokens, 8);
    for LCell := 0 to 7 do
    begin
      if CPatterns[LSample][LCell + 1] = 'x' then
      begin
        LTokens[LCell] := RhythmOnsetToken;
      end
      else
      begin
        LTokens[LCell] := RhythmEmptyToken;
      end;
    end;
    LSamples[LSample] := MakeWfcSequenceSample(LTokens);
  end;
  LExpected := LearnSequenceModelCorpus(LSamples, 3);
  LActual := nil;
  try
    LActual := AStyle.CopyRhythmModel;
    Check(EncodeWfcSequenceText(LExpected) = EncodeWfcSequenceText(LActual),
      'Weights preserve complete independent samples and exact actual WFC counts');
  finally
    LActual.Free;
    LExpected.Free;
  end;
end;

procedure Rehash(var ABytes: TAudioBytes);
var
  LHash: String;
begin
  LHash := Sha256Bytes(Copy(ABytes, 0, Length(ABytes) - 64));
  Move(LHash[1], ABytes[Length(ABytes) - 64], 64);
end;

procedure Reject(const ABytes: TAudioBytes; var APrior: TWaveStyleProfile);
var
  LPrior: TWaveStyleProfile;
  LRejected: Boolean;
begin
  LPrior := APrior;
  LRejected := False;
  try
    APrior := DecodeWaveStyle(ABytes);
  except
    on EAudio do
    begin
      LRejected := True;
    end;
  end;
  Check(LRejected and (APrior = LPrior), 'Invalid style preserves prior assignment');
end;

procedure DynamicsChecks;
const
  CPatterns: array[0..2] of String = ('10203040', '10203040', '12340120');
var
  LClip: TAudioClip;
  LPcm: TAudioSamples;
  LMeasured: TOnsetDynamics;
  LAdmission: TRhythmAdmission;
  LPattern: String;
  LSource: TWaveStyleProfile;
  LOther: TWaveStyleProfile;
  LFirst: TWaveStyleProfile;
  LDerived: TWaveStyleProfile;
  LLoaded: TWaveStyleProfile;
  LPlain: TWaveStyleProfile;
  LExpected: TWfcSequenceModel;
  LActual: TWfcSequenceModel;
  LSamples: TWfcSequenceSamples;
  LTokens: TWfcModelTokens;
  LEvidence: TRhythmStyleEvidence;
  LBad: TAudioBytes;
  LIndex: Integer;
  LCell: Integer;
  LRejected: Boolean;
begin
  SetLength(LPcm, 16);
  for LIndex := 0 to 7 do
  begin
    LPcm[LIndex * 2] := (LIndex div 2 + 1) / 4;
    LPcm[LIndex * 2 + 1] := -LPcm[LIndex * 2];
  end;
  LClip := TAudioClip.Create(8, 2, LPcm);
  try
    LMeasured := MeasureOnsetDynamics(LClip, [0, 2, 4, 6, 7], 2);
    Check((LMeasured.Rms[0] = 0.25) and (LMeasured.Rms[1] = 0.5) and
      (LMeasured.Rms[2] = 0.75) and (LMeasured.Rms[3] = 1) and
      (LMeasured.Rms[4] = 1), 'Stereo energy survives opposite phases and shortened EOF window');
    LAdmission := AdmitWaveRhythm(8, 8, 500000, 480, 240, 0, [0, 2, 4, 6, 7]);
    LMeasured.Rms[4] := 100;
    LPattern := OnsetIntensityPattern(LAdmission, LMeasured);
    Check(LPattern = '1234', 'Only accepted RMS sets reference; exact amplitude-band boundaries');
    LMeasured.Rms[0] := -1;
    LRejected := False;
    try
      LPattern := OnsetIntensityPattern(LAdmission, LMeasured);
    except
      on EAudio do
      begin
        LRejected := True;
      end;
    end;
    Check(LRejected and (LPattern = '1234'), 'Invalid dynamics preserves prior pattern');
    Check((IntensityVelocity(105, 1) = 26) and (IntensityVelocity(1, 1) = 1),
      'Explicit bounded authored velocity mapping');
  finally
    LClip.Free;
  end;
  LSource := nil;
  LOther := nil;
  LFirst := nil;
  LDerived := nil;
  LLoaded := nil;
  LPlain := nil;
  LExpected := nil;
  LActual := nil;
  try
    LSource := SourceStyle(0, True);
    LOther := SourceStyle(1, True);
    LFirst := TWaveStyleProfile.CreateBlend(LSource, LOther, 0, 0, 1, 1);
    LDerived := TWaveStyleProfile.CreateBlend(LFirst, LSource, 0, 0, 1, 1);
    FreeAndNil(LSource);
    FreeAndNil(LOther);
    FreeAndNil(LFirst);
    LLoaded := DecodeWaveStyle(LDerived.Encode);
    Check(LLoaded.HasDynamics and
      (LLoaded.IntensityPatternAt(0) = CPatterns[0]) and
      (LLoaded.IntensityPatternAt(1) = CPatterns[2]), 'Saved repeated dynamic derivation');
    LEvidence := LLoaded.EvidenceAt(0);
    LEvidence.Dynamics.Rms[0] := 99;
    Check(LLoaded.IntensityPatternAt(0) = CPatterns[0], 'Detached RMS ownership');
    SetLength(LSamples, 3);
    for LIndex := 0 to 2 do
    begin
      SetLength(LTokens, 8);
      for LCell := 0 to 7 do
      begin
        LTokens[LCell] := StyleIntensityToken(Ord(CPatterns[LIndex][LCell + 1]) - Ord('0'));
      end;
      LSamples[LIndex] := MakeWfcSequenceSample(LTokens);
    end;
    LExpected := LearnSequenceModelCorpus(LSamples, 3);
    LActual := LLoaded.CopyIntensityModel;
    Check(EncodeWfcSequenceText(LExpected) = EncodeWfcSequenceText(LActual),
      'Exact weighted joint timing/intensity model preserves independent samples');
    LBad := LLoaded.Encode;
    LBad[Length(LBad) - 65] := LBad[Length(LBad) - 65] xor 1;
    Rehash(LBad);
    Reject(LBad, LLoaded);
    LPlain := SourceStyle(1);
    LRejected := False;
    try
      LFirst := TWaveStyleProfile.CreateBlend(LLoaded, LPlain, 0, 0, 1, 1);
    except
      on EAudio do
      begin
        LRejected := True;
      end;
    end;
    Check(LRejected, 'Measured and unavailable active evidence cannot silently blend');
    LFirst := TWaveStyleProfile.CreateBlend(LPlain, LLoaded, 0, 0, 1, 0);
    FreeAndNil(LDerived);
    LDerived := DecodeWaveStyle(LFirst.Encode);
    Check(not LDerived.HasDynamics,
      'Zero-weight measured parent retains lineage without inventing active measurements');
    WriteLn('Native RMS, accepted intensity admission, weighted joint model, saved reblend and unknown handling pass');
  finally
    LActual.Free;
    LExpected.Free;
    LPlain.Free;
    LLoaded.Free;
    LDerived.Free;
    LFirst.Free;
    LOther.Free;
    LSource.Free;
  end;
end;

procedure PreferenceArchiveChecks(const ABase: TWaveStyleProfile; const APrefix: String);
var
  LPreferred: TWaveStyleProfile;
  LLoaded: TWaveStyleProfile;
  LBlend: TWaveStyleProfile;
  LNext: TWaveStyleProfile;
  LConflict: TWaveStyleProfile;
  LCandidate: TWaveStyleProfile;
  LContext: TContextProfile;
  LModel: TWfcSequenceModel;
  LDefinition: TStylePerformance;
  LSession: TLearnedLayerSession;
  LPlan: TStylePerformancePlan;
  LPreferences: TStyleGenerationPreferences;
  LCopy: TStyleGenerationPreferences;
  LBytes: TAudioBytes;
  LBad: TAudioBytes;
  LOptions: TStylePerformanceOptions;
  LSequences: TLayerSequences;
  LReport: TGraphNegotiationReport;
  LBaseIdentity: String;
  LModelText: String;
  LProvider: TStylePreferenceProvider;
  LOffset: Integer;
  LIndex: Integer;
  LRejected: Boolean;
begin
  LPreferred := nil;
  LLoaded := nil;
  LBlend := nil;
  LNext := nil;
  LConflict := nil;
  LCandidate := nil;
  LContext := nil;
  LModel := nil;
  LDefinition := nil;
  LSession := nil;
  LPlan := nil;
  LBaseIdentity := ABase.Identity;
  try
    LPreferences := Default(TStyleGenerationPreferences);
    LContext := ABase.CopyContext;
    LModel := LContext.CopyModel(cdKey);
    LPreferences[sppKey] := [MakeLayerTokenPreference(LModel.PublicTokenAt(0), 4)];
    FreeAndNil(LModel);
    LModel := LContext.CopyModel(cdTempo);
    LPreferences[sppTempo] := [MakeLayerTokenPreference(LModel.PublicTokenAt(0), 8)];
    FreeAndNil(LModel);
    if not ABase.HasDuration then
    begin
      LModel := ABase.CopyRhythmModel;
      LPreferences[sppRhythm] := [MakeLayerTokenPreference(LModel.PublicTokenAt(0), 4)];
      FreeAndNil(LModel);
    end;
    if ABase.HasDuration then
    begin
      LModel := ABase.CopyDurationModel;
      LModelText := EncodeWfcSequenceText(LModel);
      LPreferences[sppPerformance] := [MakeLayerTokenPreference(LModel.PublicTokenAt(0), 16)];
      FreeAndNil(LModel);
    end;
    LPreferred := TWaveStyleProfile.CreatePreferred(ABase, LPreferences);
    Check((LPreferred.ParentIdentity(0) = ABase.Identity) and
      (LPreferred.ParentIdentity(1) = '') and (LPreferred.Depth = ABase.Depth + 1) and
      (LPreferred.NodeCount = ABase.NodeCount + 1), 'Preferred lineage includes unchanged parent');
    LPreferences[sppKey][0].Token := 'caller mutation';
    LCopy := LPreferred.CopyGenerationPreferences;
    Check(LCopy[sppKey][0].Token <> 'caller mutation', 'Preference input is detached');
    LCopy[sppKey][0].Multiplier := 0;
    Check(LPreferred.CopyGenerationPreferences[sppKey][0].Multiplier = 4, 'Preference output detaches');
    LBytes := LPreferred.Encode;
    LLoaded := DecodeWaveStyle(LBytes);
    Check(LLoaded.Identity = LPreferred.Identity, 'Preferred canonical reload');
    for LIndex := 0 to ABase.SourceCount - 1 do
    begin
      Check((LLoaded.RhythmWeightAt(LIndex) = ABase.RhythmWeightAt(LIndex)) and
        (LLoaded.PitchWeightAt(LIndex) = ABase.PitchWeightAt(LIndex)) and
        (LLoaded.EvidenceAt(LIndex).Source.Sha256 = ABase.EvidenceAt(LIndex).Source.Sha256),
        'Preferences retain source identity and training weights');
    end;
    LBlend := TWaveStyleProfile.CreateBlend(LLoaded, ABase, 0, 0, 1, 1);
    LNext := TWaveStyleProfile.CreateBlend(LBlend, ABase, 0, 0, 1, 1);
    FreeAndNil(LLoaded);
    LLoaded := DecodeWaveStyle(LNext.Encode);
    Check((LLoaded.Identity = LNext.Identity) and
      (LLoaded.CopyGenerationPreferences[sppKey][0].Multiplier = 4) and
      (LLoaded.CopyGenerationPreferences[sppTempo][0].Multiplier = 8),
      'Preferences survive saved blend and reblend');
    if not ABase.HasDuration then
    begin
      Check(LLoaded.CopyGenerationPreferences[sppRhythm][0].Multiplier = 4,
        'Rhythm preferences follow active rhythm parents');
    end;
    FreeAndNil(LCandidate);
    LCandidate := TWaveStyleProfile.CreateBlend(LPreferred, ABase, 1, 1, 1, 1);
    Check((Length(LCandidate.CopyGenerationPreferences[sppKey]) = 0) and
      (Length(LCandidate.CopyGenerationPreferences[sppTempo]) = 0),
      'Key/tempo preferences follow selected context parents');
    FreeAndNil(LCandidate);
    if ABase.HasDuration then
    begin
      Check(LLoaded.CopyGenerationPreferences[sppPerformance][0].Multiplier = 16,
        'Active performance preferences survive reblend');
      Check(Length(LLoaded.CopyGenerationPreferences[sppPerformance]) = 1,
        'Repeated ancestry does not multiply output preference entries');
      LModel := LLoaded.CopyDurationModel;
      Check(EncodeWfcSequenceText(LModel) = LModelText, 'Same-source reblend preserves duration counts');
      FreeAndNil(LModel);
      LModel := LPreferred.CopyDurationModel;
      Check(EncodeWfcSequenceText(LModel) = LModelText, 'Preference derivation preserves duration counts');
      FreeAndNil(LModel);
      LOptions := DefaultStylePerformanceOptions;
      LOptions.SpanCount := 8;
      LDefinition := TStylePerformance.Create(LLoaded, LOptions);
      LSession := LDefinition.CreateSession;
      Check(LSession.CopyPreferences('performance')[0].Multiplier = 16,
        'Saved performance preference reaches actual named pass');
      Check(LSession.CopyPreferences('key')[0].Multiplier = 4, 'Saved key preference reaches pass');
      Check(LSession.CopyPreferences('tempo')[0].Multiplier = 8, 'Saved tempo preference reaches pass');
      Check(LSession.TryGenerate(LSequences, LReport), 'Saved preferred performance solves');
      LPlan := LDefinition.Capture(LSequences);
      Check(LPlan.SpanCount = 8, 'Preferred performance captures valid musical timing');
      LCopy := LPreferred.CopyGenerationPreferences;
      LCopy[sppPerformance][0].Multiplier := 8;
      LConflict := TWaveStyleProfile.CreatePreferred(ABase, LCopy);
      LRejected := False;
      try
        LCandidate := TWaveStyleProfile.CreateBlend(LPreferred, LConflict, 0, 0, 1, 1);
      except
        on EAudio do
        begin
          LRejected := True;
        end;
      end;
      Check(LRejected and (LCandidate = nil), 'Conflicting active preferences reject rather than average');
      LCandidate := TWaveStyleProfile.CreateBlendDimensions(LPreferred, LConflict, 0, 0, 1, 1, 1, 0);
      Check(LCandidate.CopyGenerationPreferences[sppPerformance][0].Multiplier = 16,
        'Inactive pitch parent does not contribute conflicting performance preferences');
      FreeAndNil(LCandidate);
      LCopy := Default(TStyleGenerationPreferences);
      for LProvider := sppRhythm to High(LProvider) do
      begin
        case LProvider of
          sppRhythm: LModel := ABase.CopyRhythmModel;
          sppIntensity: LModel := ABase.CopyIntensityModel;
          sppPitch: LModel := ABase.CopyPitchModel;
          sppPitchRhythm: LModel := ABase.CopyPitchRhythmModel;
        else
          raise EAudio.Create('Unexpected grid preference provider');
        end;
        LCopy[LProvider] := [MakeLayerTokenPreference(LModel.PublicTokenAt(0), Ord(LProvider) + 1)];
        FreeAndNil(LModel);
      end;
      FreeAndNil(LConflict);
      LConflict := TWaveStyleProfile.CreatePreferred(ABase, LCopy);
      LCandidate := TWaveStyleProfile.CreateBlend(LConflict, ABase, 0, 0, 1, 1);
      FreeAndNil(LConflict);
      LConflict := DecodeWaveStyle(LCandidate.Encode);
      for LProvider := sppRhythm to High(LProvider) do
      begin
        Check(LConflict.CopyGenerationPreferences[LProvider][0].Multiplier = Ord(LProvider) + 1,
          'Every supported grid provider preserves its own preferences through blend/reload');
      end;
      FreeAndNil(LCandidate);
      FreeAndNil(LDefinition);
      LRejected := False;
      try
        LDefinition := TStylePerformance.Create(LConflict, LOptions);
      except
        on EAudio do
        begin
          LRejected := True;
        end;
      end;
      Check(LRejected and (LDefinition = nil), 'Duration-only API rejects unconsumed grid preferences');
      if APrefix <> '' then
      begin
        WriteFileBytes(APrefix + '.grid-preferred.pys', LConflict.Encode);
      end;
    end;
    LCopy := Default(TStyleGenerationPreferences);
    LCandidate := TWaveStyleProfile.CreatePreferred(LPreferred, LCopy);
    Check(not LCandidate.HasGenerationPreferences, 'Explicit clearing produces a replayable derived style');
    FreeAndNil(LCandidate);
    LCopy[sppKey] := [MakeLayerTokenPreference('not a key token', 2)];
    LRejected := False;
    try
      LCandidate := TWaveStyleProfile.CreatePreferred(ABase, LCopy);
    except
      on EAudio do
      begin
        LRejected := True;
      end;
    end;
    Check(LRejected and (ABase.Identity = LBaseIdentity), 'Unknown preference rejects without parent mutation');
    LBad := Copy(LBytes);
    LOffset := 20 + Length(ABase.Encode); { Four header integers, parent blob length and bytes. }
    LBad[LOffset] := 1;
    LBad[LOffset + 1] := 4; { 1025 key preferences, beyond the bounded table. }
    Rehash(LBad);
    LRejected := False;
    try
      LCandidate := DecodeWaveStyle(LBad);
    except
      on EAudio do
      begin
        LRejected := True;
      end;
    end;
    Check(LRejected and (LCandidate = nil), 'Intact digest cannot authorize oversized preference table');
    if APrefix <> '' then
    begin
      WriteFileBytes(APrefix + '.preferred.pys', LPreferred.Encode);
      WriteFileBytes(APrefix + '.preferred-reblend.pys', LLoaded.Encode);
    end;
    WriteLn('Saved preferences: duration=', ABase.HasDuration,
      '; lineage, counts, ownership, canonical reload, parent selection and repeated blends pass');
  finally
    LPlan.Free;
    LSession.Free;
    LDefinition.Free;
    LModel.Free;
    LContext.Free;
    LCandidate.Free;
    LConflict.Free;
    LNext.Free;
    LBlend.Free;
    LLoaded.Free;
    LPreferred.Free;
  end;
end;

procedure PreferenceFileChecks(const AInput, APrefix: String);
var
  LStyle: TWaveStyleProfile;
begin
  LStyle := DecodeWaveStyle(ReadFileBytes(AInput, MaximumStyleBytes));
  try
    PreferenceArchiveChecks(LStyle, APrefix);
  finally
    LStyle.Free;
  end;
end;

procedure Run(const APrefix: String);
var
  LA: TWaveStyleProfile;
  LB: TWaveStyleProfile;
  LFirst: TWaveStyleProfile;
  LSecond: TWaveStyleProfile;
  LLoaded: TWaveStyleProfile;
  LNext: TWaveStyleProfile;
  LContextA: TContextProfile;
  LContextB: TContextProfile;
  LABytes: TAudioBytes;
  LBytes: TAudioBytes;
  LBad: TAudioBytes;
  LFirstId: String;
  LEvidence: TRhythmStyleEvidence;
  LAdmission: TRhythmAdmission;
  LRejected: Boolean;
  LIndex: Integer;
begin
  LA := nil;
  LB := nil;
  LFirst := nil;
  LSecond := nil;
  LLoaded := nil;
  LNext := nil;
  LContextA := nil;
  LContextB := nil;
  try
    AdmissionChecks;
    GridCapabilityChecks;
    TimbreChecks(APrefix);
    TrajectoryChecks(APrefix);
    EnvelopeChecks(APrefix);
    InstrumentChecks;
    LA := SourceStyle(0);
    LB := SourceStyle(1);
    PreferenceArchiveChecks(LA, APrefix);
    Check((LA.AdmissionAt(0).Pattern = 'x.x.x.x.') and
      (LB.AdmissionAt(0).Pattern = 'xxxx.xx.'), 'Source rhythm learning matches authored clocks');
    LEvidence := LA.EvidenceAt(0);
    LEvidence.OnsetFrames[0] := 10;
    LAdmission := LA.AdmissionAt(0);
    LAdmission.Cells[0] := 7;
    Check((LA.EvidenceAt(0).OnsetFrames[0] = 0) and
      (LA.AdmissionAt(0).Cells[0] = 0), 'Detached style evidence/admission ownership');
    if APrefix <> '' then
    begin
      WriteFileBytes(APrefix + '.a.pys', LA.Encode);
      WriteFileBytes(APrefix + '.b.pys', LB.Encode);
    end;
    LABytes := LA.Encode;
    LFirst := TWaveStyleProfile.CreateBlend(LA, LB, 0, 0, 1, 1);
    LFirstId := LFirst.Identity;
    LBytes := LFirst.Encode;
    FreeAndNil(LFirst);
    FreeAndNil(LB);
    FreeAndNil(LA);
    LFirst := DecodeWaveStyle(LBytes);
    LA := DecodeWaveStyle(LABytes);
    LSecond := TWaveStyleProfile.CreateBlend(LFirst, LA, 0, 0, 1, 1);
    Check((LSecond.SourceCount = 2) and (LSecond.RhythmWeightAt(0) = 2) and
      (LSecond.RhythmWeightAt(1) = 1) and (LSecond.ParentIdentity(0) = LFirstId) and
      (LSecond.ParentIdentity(1) = LA.Identity), 'Second derivation retains lineage and 2:1 rhythm weights');
    CompareWeightedModel(LSecond);
    LContextA := LA.CopyContext;
    LContextB := LSecond.CopyContext;
    Check((LContextA.ProviderIdentity(cdKey) = LContextB.ProviderIdentity(cdKey)) and
      (LContextA.ProviderIdentity(cdTempo) = LContextB.ProviderIdentity(cdTempo)),
      'Rhythm blending preserves selected independent key/tempo providers');
    LBytes := LSecond.Encode;
    LLoaded := DecodeWaveStyle(LBytes);
    Check(LLoaded.Identity = LSecond.Identity, 'Canonical saved derived style replay');
    Check((LBytes[0] = Ord('P')) and (LBytes[1] = Ord('Y')) and
      (LBytes[2] = Ord('S')) and (LBytes[3] = Ord('T')) and
      (LBytes[4] = WaveStyleVersion), 'One current style format contract');
    LBad := Copy(LBytes);
    LBad[3] := Ord('1');
    Rehash(LBad);
    Reject(LBad, LLoaded);
    LBad := Copy(LBytes, 0, Length(LBytes) - 1);
    Reject(LBad, LLoaded);
    LBad := Copy(LBytes);
    { Blend coefficient fields: offset 24 left, 28 right. Both zero is invalid,
      even with an intact outer digest. }
    for LIndex := 24 to 31 do
    begin
      LBad[LIndex] := 0;
    end;
    Rehash(LBad);
    Reject(LBad, LLoaded);
    if APrefix <> '' then
    begin
      WriteFileBytes(APrefix + '.blend.pys', LFirst.Encode);
      WriteFileBytes(APrefix + '.reblend.pys', LLoaded.Encode);
    end;
    LNext := TWaveStyleProfile.CreateBlend(LA, LA, 0, 0, 1, 1);
    for LIndex := 1 to 4 do
    begin
      FreeAndNil(LLoaded);
      LLoaded := TWaveStyleProfile.CreateBlend(LNext, LNext, 0, 0, 1, 1);
      FreeAndNil(LNext);
      LNext := LLoaded;
      LLoaded := nil;
    end;
    Check(LNext.NodeCount = 63, 'Complete repeated parent appearances count toward ancestry');
    LRejected := False;
    try
      LLoaded := TWaveStyleProfile.CreateBlend(LNext, LNext, 0, 0, 1, 1);
    except
      on EAudio do
      begin
        LRejected := True;
      end;
    end;
    Check(LRejected and (LLoaded = nil), 'Excessive ancestry rejects before publication');
    WriteLn('Native rhythm admission, weighted actual model counts, saved reblending, ownership and failure bounds pass');
  finally
    LContextB.Free;
    LContextA.Free;
    LLoaded.Free;
    LNext.Free;
    LSecond.Free;
    LFirst.Free;
    LB.Free;
    LA.Free;
  end;
end;

function OutputDocument(const AOutput: String): TJSONObject;
var
  LBytes: TAudioBytes;
  LText: String;
  LJson: TJSONData;
begin
  LBytes := ReadFileBytes(AOutput + '.json', 16 * 1024 * 1024);
  SetLength(LText, Length(LBytes));
  if Length(LBytes) > 0 then
  begin
    Move(LBytes[0], LText[1], Length(LBytes));
  end;
  LJson := GetJSON(LText);
  if not (LJson is TJSONObject) then
  begin
    LJson.Free;
    raise EAudio.Create('Style output report must be an object');
  end;
  Result := TJSONObject(LJson);
end;

procedure CheckOutput(const AStyleName, AOutput: String);
var
  LStyle: TWaveStyleProfile;
  LModel: TWfcSequenceModel;
  LDocument: TJSONObject;
  LFrames: TJSONArray;
  LFrame: TWfcMusicEnsembleFrame;
  LPattern: String;
  LLocks: String;
  LAttacks: Integer;
  LCell: Integer;
  LVoice: Integer;
  LEdit: TJSONObject;
  LHasPins: Boolean;
  LIntensity: String;
  LIntensityLocks: String;
  LTone: Integer;
  LBaseVelocity: Integer;
  LExpectedVelocity: Integer;
  LPitchLayer: Integer;
  LPitchStates: TWfcSequenceStateIndices;
  LPitchValidation: TWfcSequenceGraphValidationReport;
  LCoupled: Boolean;
  LOnsetLayer: Integer;
  LIntensityLayer: Integer;
  LPair: TPitchRhythmCell;
  LExtent: TWfcSequenceExtent;
  LExtentName: String;
  LLayer: Integer;
  LPreferences: TStyleGenerationPreferences;
  LProvider: TStylePreferenceProvider;
  LPreferenceRows: TJSONArray;
  LPreferenceIndex: Integer;
begin
  LStyle := nil;
  LModel := nil;
  LDocument := nil;
  try
    LStyle := DecodeWaveStyle(ReadFileBytes(AStyleName, MaximumStyleBytes));
    LModel := LStyle.CopyRhythmModel;
    LDocument := OutputDocument(AOutput);
    LExtentName := LDocument.Get('provider_extent', '');
    LExtent := wseFragment;
    if (LExtentName = 'prefix') or (LExtentName = 'whole') or (LExtentName = 'fragment') then
    begin
      if LExtentName = 'prefix' then
      begin
        LExtent := wsePrefix;
      end
      else if LExtentName = 'whole' then
      begin
        LExtent := wseWhole;
      end;
      for LLayer := 0 to LDocument.Arrays['context_passes'].Count - 1 do
      begin
        FreeAndNil(LModel);
        LModel := DecodeWfcSequenceText(LDocument.Arrays['context_passes'].Objects[LLayer].Get('model', ''));
        SetLength(LPitchStates, 64);
        for LCell := 0 to 63 do
        begin
          LPitchStates[LCell] := LDocument.Arrays['context_passes'].Objects[LLayer].Arrays['states'].Integers[LCell];
        end;
        Check(ValidateSequenceStatePath(LModel, LPitchStates, LExtent, LPitchValidation),
          'Every provider satisfies the explicitly requested source extent');
      end;
      FreeAndNil(LModel);
      LModel := LStyle.CopyRhythmModel;
    end;
    LCoupled := LDocument.Get('coupled_pitch', False);
    LOnsetLayer := 2 + Ord(LCoupled);
    LIntensityLayer := LOnsetLayer + 1;
    LPreferences := LStyle.CopyGenerationPreferences;
    for LLayer := 0 to LDocument.Arrays['context_passes'].Count - 1 do
    begin
      if LLayer = 0 then
      begin
        LProvider := sppKey;
      end
      else if LLayer = 1 then
      begin
        LProvider := sppTempo;
      end
      else if LCoupled and (LLayer = 2) then
      begin
        LProvider := sppPitchRhythm;
      end
      else if LLayer = LOnsetLayer then
      begin
        LProvider := sppRhythm;
      end
      else if LStyle.HasDynamics and (LLayer = LIntensityLayer) then
      begin
        LProvider := sppIntensity;
      end
      else
      begin
        Check(LStyle.HasPitch, 'Only a measured pitch pass may follow the grid providers');
        LProvider := sppPitch;
      end;
      LPreferenceRows := LDocument.Arrays['context_passes'].Objects[LLayer].Arrays['generation_preferences'];
      Check(LPreferenceRows.Count = Length(LPreferences[LProvider]),
        'Every saved preference reaches its corresponding generated provider');
      for LPreferenceIndex := 0 to LPreferenceRows.Count - 1 do
      begin
        Check((LPreferenceRows.Objects[LPreferenceIndex].Get('token', '') =
          LPreferences[LProvider][LPreferenceIndex].Token) and
          (LPreferenceRows.Objects[LPreferenceIndex].Get('multiplier', 0) =
          LPreferences[LProvider][LPreferenceIndex].Multiplier),
          'Generated provider retains the exact ordered saved settings');
      end;
    end;
    Check((LDocument.Get('contract', '') = 'pythian.voices.wave-style.demo.v1') and
      (LDocument.Get('wave_style_sha256', '') = LStyle.Identity), 'Actual saved style/output binding');
    Check((LDocument.Arrays['context_passes'].Count = 3 + Ord(LStyle.HasDynamics) + Ord(LStyle.HasPitch) + Ord(LCoupled)) and
      (LDocument.Arrays['context_passes'].Objects[LOnsetLayer].Get('model', '') =
      EncodeWfcSequenceText(LModel)), 'Actual weighted rhythm model reaches the provider passes');
    LPattern := LDocument.Get('generated_onset_pattern', '');
    LLocks := LDocument.Get('rhythm_locks', '');
    LIntensity := LDocument.Get('generated_intensity_pattern', '');
    LIntensityLocks := LDocument.Get('intensity_locks', '');
    if LStyle.HasDynamics then
    begin
      FreeAndNil(LModel);
      LModel := LStyle.CopyIntensityModel;
      Check((Length(LIntensity) = 64) and
        (LDocument.Arrays['context_passes'].Objects[LIntensityLayer].Get('model', '') =
        EncodeWfcSequenceText(LModel)), 'Saved joint intensity model reaches its actual pass');
      Check((LIntensityLocks = '') or (Length(LIntensityLocks) = 64), 'Complete intensity mask');
    end;
    Check((LLocks = '') or (Length(LLocks) = 64), 'Complete optional rhythm mask');
    if LStyle.HasPitch then
    begin
      LPitchLayer := 3 + Ord(LStyle.HasDynamics) + Ord(LCoupled);
      FreeAndNil(LModel);
      LModel := LStyle.CopyPitchModel;
      Check(LDocument.Arrays['context_passes'].Objects[LPitchLayer].Get('model', '') =
        EncodeWfcSequenceText(LModel), 'Saved pitch model reaches the actual pass');
      Check(LDocument.Arrays['generated_pitch_notes'].Count = 64, 'Complete generated pitch cells');
      SetLength(LPitchStates, 64);
      for LCell := 0 to 63 do
      begin
        LPitchStates[LCell] := LDocument.Arrays['context_passes'].Objects[LPitchLayer].Arrays['states'].Integers[LCell];
        Check(DecodePitchNoteToken(LModel.ProjectStateToken(LPitchStates[LCell])) =
          LDocument.Arrays['generated_pitch_notes'].Integers[LCell], 'Pitch output matches actual latent-state projection');
      end;
      Check(ValidateSequenceStatePath(LModel, LPitchStates, LExtent, LPitchValidation),
        'Saved pitch pass has an actual valid latent path');
    end;
    if LCoupled then
    begin
      Check(LStyle.HasPitchRhythm, 'Coupled output requires stored measured relationships');
      FreeAndNil(LModel);
      LModel := LStyle.CopyPitchRhythmModel;
      Check(LDocument.Arrays['context_passes'].Objects[2].Get('model', '') =
        EncodeWfcSequenceText(LModel), 'Saved pitch/rhythm model is the actual provider');
      SetLength(LPitchStates, 64);
      for LCell := 0 to 63 do
      begin
        LPitchStates[LCell] := LDocument.Arrays['context_passes'].Objects[2].Arrays['states'].Integers[LCell];
        LPair := DecodePitchRhythmToken(LModel.ProjectStateToken(LPitchStates[LCell]));
        Check((LPair.Note = LDocument.Arrays['generated_pitch_notes'].Integers[LCell]) and
          ((LPair.Level > 0) = (LPattern[LCell + 1] = 'x')),
          'Every pitch/onset pair comes from the solved observed joint vocabulary');
        if LStyle.HasDynamics then
        begin
          Check(LPair.Level = Ord(LIntensity[LCell + 1]) - Ord('0'),
            'Joint observed intensity reaches the consumer');
        end;
      end;
      Check(ValidateSequenceStatePath(LModel, LPitchStates, LExtent, LPitchValidation),
        'Coupled pitch/rhythm history follows an actual observed-run model path');
    end;
    LHasPins := not LCoupled and ((Pos('x', LLocks) > 0) or (Pos('.', LLocks) > 0));
    if LHasPins then
    begin
      LEdit := LDocument.Objects['selective_regeneration'];
      Check(LEdit.Get('independent_context_states_preserved', False) and
        (LEdit.Arrays['active_pass_indices'].Count = 1 + Ord(LStyle.HasDynamics)) and
        (LEdit.Arrays['active_pass_indices'].Integers[0] = 2) and
        (LEdit.Arrays['requested_root_indices'].Count = 1) and
        (LEdit.Arrays['requested_root_indices'].Integers[0] = 2) and
        (Length(LEdit.Get('baseline_onset_pattern', '')) = 64),
        'Actual selective scope contains only the edited onset provider');
      if LStyle.HasDynamics then
      begin
        Check(LEdit.Arrays['active_pass_indices'].Integers[1] = 3, 'Onset edit includes dependent joint intensity');
      end;
    end;
    LFrames := LDocument.Arrays['frames'];
    Check((Length(LPattern) = 64) and (LFrames.Count = 64), 'Complete aligned rhythm/voice cells');
    LAttacks := 0;
    for LCell := 0 to 63 do
    begin
      if LStyle.HasDynamics then
      begin
        Check((LIntensity[LCell + 1] in ['0'..'4']) and
          ((LIntensity[LCell + 1] <> '0') = (LPattern[LCell + 1] = 'x')),
          'Joint intensity preserves observed onset presence');
        if (LIntensityLocks <> '') and (LIntensityLocks[LCell + 1] <> '?') then
        begin
          Check(LIntensityLocks[LCell + 1] = LIntensity[LCell + 1], 'Intensity pin reaches generated result');
        end;
      end;
      if (LLocks <> '') and (LLocks[LCell + 1] <> '?') then
      begin
        Check(LLocks[LCell + 1] = LPattern[LCell + 1], 'Explicit rhythm pin reaches the output');
      end;
      LFrame := DecodeWfcMusicEnsembleFrame(LFrames.Strings[LCell]);
      Check(Length(LFrame.Voices) = 3, 'Every cell retains three independent roles');
      if LStyle.HasPitch and (LPattern[LCell + 1] = 'x') then
      begin
        Check((Length(LFrame.Voices[2].Tones) = 1) and
          (LFrame.Voices[2].Tones[0].Pitch = LDocument.Arrays['generated_pitch_notes'].Integers[LCell]),
          'Measured pitch pass controls every realized melody attack');
      end;
      for LVoice := 0 to 2 do
      begin
        if LPattern[LCell + 1] = 'x' then
        begin
          Check((LFrame.Voices[LVoice].Action = wmcaAttack) and
            (Length(LFrame.Voices[LVoice].Tones) > 0), 'Measured onset drives realized voice attacks');
          if LStyle.HasDynamics then
          begin
            for LTone := 0 to High(LFrame.Voices[LVoice].Tones) do
            begin
              case LVoice of
                0:
                begin
                  LBaseVelocity := 105;
                end;
                1:
                begin
                  case LTone of
                    0:
                    begin
                      LBaseVelocity := 78;
                    end;
                    1:
                    begin
                      LBaseVelocity := 70;
                    end;
                    else
                    begin
                      LBaseVelocity := 74;
                    end;
                  end;
                end;
                else
                begin
                  LBaseVelocity := 86;
                  if LCell >= 32 then
                  begin
                    LBaseVelocity := 96;
                  end;
                end;
              end;
              LExpectedVelocity := LBaseVelocity * (Ord(LIntensity[LCell + 1]) - Ord('0')) div 4;
              Check(LFrame.Voices[LVoice].Tones[LTone].Velocity = LExpectedVelocity,
                'Every realized voice tone follows measured intensity and authored balance');
            end;
          end;
        end
        else
        begin
          Check(LFrame.Voices[LVoice].Action = wmcaRest, 'Declared empty-cell arrangement');
        end;
      end;
      if LPattern[LCell + 1] = 'x' then
      begin
        Inc(LAttacks);
      end;
    end;
    Check(LDocument.Get('rendered_notes', 0) = LAttacks * 5,
      'Each admitted attack realizes bass, full triad and melody');
    Check(LDocument.Get('preview_verified_against_wfc', False) and
      LDocument.Get('midi_verified_against_wfc', False) and
      LDocument.Get('midi_verified_by_round_trip', False), 'Actual preview and MIDI verification completed');
    Check(HashAudioBytes(ReadFileBytes(AOutput, 128 * 1024 * 1024)) =
      LDocument.Get('stereo_sha256', ''), 'Actual stereo output hash');
    Check(HashAudioBytes(ReadFileBytes(AOutput + '.mid', 16 * 1024 * 1024)) =
      LDocument.Get('midi_sha256', ''), 'Actual MIDI output hash');
    Check(HashAudioBytes(ReadFileBytes(AOutput + '.preview.wav', 128 * 1024 * 1024)) =
      LDocument.Get('preview_sha256', ''), 'Actual preview output hash');
    WriteLn('Saved style/model binding, rhythm pins, ', LAttacks,
      ' onset-driven voice attacks and actual audio/MIDI hashes pass');
  finally
    LDocument.Free;
    LModel.Free;
    LStyle.Free;
  end;
end;

procedure CheckControls(const ABefore, AAfter: String; const AIntensityOnly: Boolean = False;
  const APitchOnly: Boolean = False; const ACoupled: Boolean = False;
  const APreferenceOnly: Boolean = False);
var
  LBefore: TJSONObject;
  LAfter: TJSONObject;
  LLayer: Integer;
begin
  LBefore := OutputDocument(ABefore);
  LAfter := nil;
  try
    LAfter := OutputDocument(AAfter);
    for LLayer := 0 to 1 + Ord(AIntensityOnly) + 2 * Ord(APitchOnly) do
    begin
      Check(LBefore.Arrays['context_passes'].Objects[LLayer].AsJSON =
        LAfter.Arrays['context_passes'].Objects[LLayer].AsJSON,
        'Rhythm change preserves independent key/tempo models, tokens and latent states');
    end;
    Check((LBefore.Arrays['tempo_cells'].AsJSON = LAfter.Arrays['tempo_cells'].AsJSON) and
      (LBefore.Get('stereo_sha256', '') <> LAfter.Get('stereo_sha256', '')),
      'Controlled style variation changes realized audio while preserving its clock');
    if APreferenceOnly then
    begin
      Check(LBefore.Arrays['context_passes'].Count = LAfter.Arrays['context_passes'].Count,
        'Preference variation preserves provider count');
      for LLayer := 0 to LBefore.Arrays['context_passes'].Count - 1 do
      begin
        Check(LBefore.Arrays['context_passes'].Objects[LLayer].Get('model', '') =
          LAfter.Arrays['context_passes'].Objects[LLayer].Get('model', ''),
          'Saved generation preferences do not rewrite any provider training counts');
      end;
      Check(LBefore.Arrays['context_passes'].AsJSON <> LAfter.Arrays['context_passes'].AsJSON,
        'Preference variation reaches generated providers');
    end
    else if ACoupled then
    begin
      Check(LBefore.Get('coupled_pitch', False) and LAfter.Get('coupled_pitch', False) and
        (LBefore.Arrays['generated_pitch_notes'].AsJSON <>
        LAfter.Arrays['generated_pitch_notes'].AsJSON) and
        (LAfter.Arrays['generated_pitch_notes'].Integers[0] = 62) and
        (LAfter.Objects['selective_regeneration'].Arrays['active_pass_indices'].AsJSON = '[2, 3, 4, 5]') and
        (LAfter.Objects['selective_regeneration'].Arrays['requested_root_indices'].AsJSON = '[2]'),
        'Coupled pitch edit regenerates the observed provider and its three consumers');
    end
    else if APitchOnly then
    begin
      Check((LBefore.Arrays['generated_pitch_notes'].AsJSON <>
        LAfter.Arrays['generated_pitch_notes'].AsJSON) and
        (LAfter.Arrays['generated_pitch_notes'].Integers[1] = 72) and
        (LAfter.Objects['selective_regeneration'].Arrays['active_pass_indices'].AsJSON = '[4]'),
        'Pitch edit changes measured melody while only pitch pass regenerates');
    end
    else if AIntensityOnly then
    begin
      Check((LBefore.Get('generated_onset_pattern', '') = LAfter.Get('generated_onset_pattern', '')) and
        (LBefore.Get('generated_intensity_pattern', '') <> LAfter.Get('generated_intensity_pattern', '')) and
        LAfter.Objects['selective_regeneration'].Get('onset_states_preserved', False) and
        (LAfter.Objects['selective_regeneration'].Arrays['active_pass_indices'].Count = 1) and
        (LAfter.Objects['selective_regeneration'].Arrays['active_pass_indices'].Integers[0] = 3),
        'Only intensity regenerated while accepted onset timing and latent states were preserved');
    end
    else
    begin
      Check(LBefore.Get('generated_onset_pattern', '') <> LAfter.Get('generated_onset_pattern', ''),
        'Rhythm edit changed onset timing');
    end;
    if LAfter.Find('selective_regeneration') <> nil then
    begin
      Check(LAfter.Objects['selective_regeneration'].Get('baseline_onset_pattern', '') =
        LBefore.Get('generated_onset_pattern', ''), 'Edited session starts from the compared accepted rhythm');
    end;
    if APreferenceOnly then
    begin
      WriteLn('Saved preferences preserve every training model and base context while changing audible output');
    end
    else if ACoupled then
    begin
      WriteLn('Coupled pitch edit preserves exact key/tempo and regenerates observed consumer closure');
    end
    else if APitchOnly then
    begin
      WriteLn('Pitch edit preserves exact key/tempo/onset/intensity state and changes audible output');
    end
    else if AIntensityOnly then
    begin
      WriteLn('Intensity edit preserves exact key/tempo/onset state and changes audible output');
    end
    else
    begin
      WriteLn('Changed measured rhythm preserves exact key/tempo provider state and changes audible output');
    end;
  finally
    LAfter.Free;
    LBefore.Free;
  end;
end;

procedure PitchArchiveChecks(const ALeftName, ARightName, ABlendName, AReblendName: String);
const
  CNotes: array[0..7] of Integer = (60, 62, 64, 67, 69, 67, 64, 60);
var
  LLeft: TWaveStyleProfile;
  LRight: TWaveStyleProfile;
  LBlend: TWaveStyleProfile;
  LReblend: TWaveStyleProfile;
  LOther: TWaveStyleProfile;
  LReloaded: TWaveStyleProfile;
  LContext: TContextProfile;
  LOnsetOnly: TWaveStyleProfile;
  LExpected: TWfcSequenceModel;
  LActual: TWfcSequenceModel;
  LTracks: TPitchTracks;
  LNotes: TPitchNotes;
  LPatterns: TPitchRhythmPatterns;
  LEvidence: TRhythmStyleEvidence;
  LSource: Integer;
  LCell: Integer;
  LRejected: Boolean;
  LIdentity: String;
begin
  LLeft := nil;
  LRight := nil;
  LBlend := nil;
  LReblend := nil;
  LOther := nil;
  LReloaded := nil;
  LContext := nil;
  LOnsetOnly := nil;
  LExpected := nil;
  LActual := nil;
  try
    LLeft := DecodeWaveStyle(ReadFileBytes(ALeftName, MaximumStyleBytes));
    LRight := DecodeWaveStyle(ReadFileBytes(ARightName, MaximumStyleBytes));
    LBlend := DecodeWaveStyle(ReadFileBytes(ABlendName, MaximumStyleBytes));
    LReblend := DecodeWaveStyle(ReadFileBytes(AReblendName, MaximumStyleBytes));
    Check((LReblend.SourceCount = 2) and
      (LReblend.Depth = 3) and (LReblend.NodeCount = 5) and
      (LReblend.ParentIdentity(0) = LBlend.Identity) and
      (LReblend.ParentIdentity(1) = LLeft.Identity) and
      (LBlend.ParentIdentity(1) = LRight.Identity) and
      (LReblend.RhythmWeightAt(0) = 2) and (LReblend.RhythmWeightAt(1) = 1),
      'Saved pitch second derivation retains complete parents and normalized weights');
    Check((LReblend.PitchWeightAt(0) = 2) and (LReblend.PitchWeightAt(1) = 1),
      'Whole-style blending applies weights to both available dimensions');
    SetLength(LTracks, 2);
    for LSource := 0 to 1 do
    begin
      LEvidence := LReblend.EvidenceAt(LSource);
      Check(LEvidence.Source.Sha256 = HashAudioBytes(ReadFileBytes(
        ExtractFilePath(ALeftName) + LEvidence.Source.Name, 16 * 1024 * 1024)),
        'Pitch source identity binds actual decoded WAV bytes');
      SetLength(LTracks[LSource], 32);
      LNotes := LReblend.PitchNotesAt(LSource);
      Check(Length(LNotes) = 32, 'Complete measured pitch source cells');
      for LCell := 0 to 31 do
      begin
        LTracks[LSource][LCell] := CNotes[LCell mod 8] + 12 * LSource;
        if LCell in [15, 31] then
        begin
          LTracks[LSource][LCell] := -1;
        end;
        Check(LNotes[LCell] = LTracks[LSource][LCell],
          'Both actual WAV pitch tracks agree with independent authored note references');
      end;
    end;
    LExpected := LearnPitchModel(LTracks, [2, 1], 3);
    LActual := LReblend.CopyPitchModel;
    Check(EncodeWfcSequenceText(LExpected) = EncodeWfcSequenceText(LActual),
      'Reblended saved pitch model equals independently specified weighted run corpus');
    Check(LLeft.HasPitchRhythm and LRight.HasPitchRhythm and
      LBlend.HasPitchRhythm and LReblend.HasPitchRhythm,
      'Matched source weights retain observed pitch/rhythm through repeated blends');
    SetLength(LPatterns, 2);
    for LSource := 0 to 1 do
    begin
      LPatterns[LSource] := LReblend.IntensityPatternAt(LSource);
    end;
    FreeAndNil(LExpected);
    FreeAndNil(LActual);
    LExpected := LearnPitchRhythmModel(LTracks, LPatterns, [2, 1], 3);
    LActual := LReblend.CopyPitchRhythmModel;
    Check(EncodeWfcSequenceText(LExpected) = EncodeWfcSequenceText(LActual),
      'Saved paired model retains weighted aligned runs through a second derivation');
    LEvidence := LLeft.EvidenceAt(0);
    LIdentity := LLeft.Identity;
    LEvidence.Pitch.Cells[0].Estimate.NearestMidi := 127;
    Check((LLeft.PitchNotesAt(0)[0] = 60) and (LLeft.Identity = LIdentity),
      'Pitch evidence is detached from the saved profile');
    LContext := LLeft.CopyContext;
    LRejected := False;
    try
      LOther := TWaveStyleProfile.CreateSource(LContext, LEvidence, 3);
    except
      on EAudio do
      begin
        LRejected := True;
      end;
    end;
    Check(LRejected and (LOther = nil), 'Pitch/frequency disagreement rejects before publishing');
    LEvidence := LLeft.EvidenceAt(0);
    LEvidence.Dynamics := Default(TOnsetDynamics);
    LOther := TWaveStyleProfile.CreateSource(LContext, LEvidence, 3);
    LReloaded := DecodeWaveStyle(LOther.Encode);
    Check(LReloaded.HasPitch and LReloaded.HasPitchRhythm and not LReloaded.HasDynamics,
      'Pitch capability remains independent of onset intensity capability');
    FreeAndNil(LReloaded);
    FreeAndNil(LOther);
    LOnsetOnly := SourceStyle(0, True);
    LRejected := False;
    try
      LOther := TWaveStyleProfile.CreateBlend(LLeft, LOnsetOnly, 0, 0, 1, 1);
    except
      on EAudio do
      begin
        LRejected := True;
      end;
    end;
    Check(LRejected and (LOther = nil), 'Measured and unavailable active pitch cannot silently blend');
    LOther := TWaveStyleProfile.CreateBlend(LLeft, LOnsetOnly, 0, 0, 0, 1);
    LReloaded := DecodeWaveStyle(LOther.Encode);
    Check(not LReloaded.HasPitch and
      (LReloaded.ParentIdentity(0) = LLeft.Identity),
      'Zero-weight pitch ancestor is retained without claiming active pitch');
    WriteLn('Two WAV ground truths, weighted pitch reblend, lineage, detached evidence and capability failures pass');
  finally
    LActual.Free;
    LExpected.Free;
    LOnsetOnly.Free;
    LContext.Free;
    LReloaded.Free;
    LOther.Free;
    LReblend.Free;
    LBlend.Free;
    LRight.Free;
    LLeft.Free;
  end;
end;

procedure DimensionArchiveChecks(const ARhythmName, ALowName, AHighName,
  ASelectedName, AReblendName: String);
const
  CNotes: array[0..7] of Integer = (60, 62, 64, 67, 69, 67, 64, 60);
var
  LRhythm: TWaveStyleProfile;
  LLow: TWaveStyleProfile;
  LHigh: TWaveStyleProfile;
  LSelected: TWaveStyleProfile;
  LReblend: TWaveStyleProfile;
  LOther: TWaveStyleProfile;
  LReloaded: TWaveStyleProfile;
  LNoIntensity: TWaveStyleProfile;
  LContext: TContextProfile;
  LEvidence: TRhythmStyleEvidence;
  LActual: TWfcSequenceModel;
  LExpected: TWfcSequenceModel;
  LTracks: TPitchTracks;
  LCell: Integer;
  LSource: Integer;
  LRejected: Boolean;
  LBad: TAudioBytes;
begin
  LRhythm := nil;
  LLow := nil;
  LHigh := nil;
  LSelected := nil;
  LReblend := nil;
  LOther := nil;
  LReloaded := nil;
  LNoIntensity := nil;
  LContext := nil;
  LActual := nil;
  LExpected := nil;
  try
    LRhythm := DecodeWaveStyle(ReadFileBytes(ARhythmName, MaximumStyleBytes));
    LLow := DecodeWaveStyle(ReadFileBytes(ALowName, MaximumStyleBytes));
    LHigh := DecodeWaveStyle(ReadFileBytes(AHighName, MaximumStyleBytes));
    LSelected := DecodeWaveStyle(ReadFileBytes(ASelectedName, MaximumStyleBytes));
    LReblend := DecodeWaveStyle(ReadFileBytes(AReblendName, MaximumStyleBytes));
    Check(LRhythm.HasDynamics and not LRhythm.HasPitch, 'Independent rhythm/intensity source');
    Check(not LSelected.HasPitchRhythm and not LReblend.HasPitchRhythm,
      'Independent source weights cannot manufacture observed cross-source joint relationships');
    Check((LSelected.SourceCount = 2) and
      (LSelected.RhythmWeightAt(0) = 1) and (LSelected.RhythmWeightAt(1) = 0) and
      (LSelected.PitchWeightAt(0) = 0) and (LSelected.PitchWeightAt(1) = 1) and
      (LSelected.ParentIdentity(0) = LRhythm.Identity) and
      (LSelected.ParentIdentity(1) = LHigh.Identity), 'Independent dimension selection and lineage');
    Check((LReblend.SourceCount = 3) and (LReblend.Depth = 3) and (LReblend.NodeCount = 5) and
      (LReblend.RhythmWeightAt(0) = 1) and (LReblend.RhythmWeightAt(1) = 0) and
      (LReblend.RhythmWeightAt(2) = 0) and (LReblend.PitchWeightAt(0) = 0) and
      (LReblend.PitchWeightAt(1) = 1) and (LReblend.PitchWeightAt(2) = 2) and
      (LReblend.ParentIdentity(0) = LSelected.Identity) and
      (LReblend.ParentIdentity(1) = LLow.Identity),
      'Saved second derivation preserves rhythm while blending pitches 1:2');
    LActual := LReblend.CopyRhythmModel;
    LExpected := LRhythm.CopyRhythmModel;
    Check(EncodeWfcSequenceText(LActual) = EncodeWfcSequenceText(LExpected),
      'Pitch blending preserves the exact measured rhythm model');
    FreeAndNil(LActual);
    FreeAndNil(LExpected);
    LActual := LReblend.CopyIntensityModel;
    LExpected := LRhythm.CopyIntensityModel;
    Check(EncodeWfcSequenceText(LActual) = EncodeWfcSequenceText(LExpected),
      'Pitch blending preserves the exact joint onset/intensity model');
    FreeAndNil(LActual);
    FreeAndNil(LExpected);
    LActual := LSelected.CopyPitchModel;
    LExpected := LHigh.CopyPitchModel;
    Check(EncodeWfcSequenceText(LActual) = EncodeWfcSequenceText(LExpected),
      'Zero pitch weight excludes rhythm-source pitch evidence');
    FreeAndNil(LActual);
    FreeAndNil(LExpected);
    SetLength(LTracks, 2);
    for LSource := 0 to 1 do
    begin
      SetLength(LTracks[LSource], 32);
      for LCell := 0 to 31 do
      begin
        LTracks[LSource][LCell] := CNotes[LCell mod 8] + 12 * (1 - LSource);
        if LCell in [15, 31] then
        begin
          LTracks[LSource][LCell] := -1;
        end;
      end;
    end;
    LActual := LReblend.CopyPitchModel;
    LExpected := LearnPitchModel(LTracks, [1, 2], 3);
    Check(EncodeWfcSequenceText(LActual) = EncodeWfcSequenceText(LExpected),
      'Actual pitch reblend equals independently specified weighted note runs');
    LBad := LReblend.Encode;
    { Current blend layout: pitch parent coefficients begin at byte 32. }
    LBad[32] := 65;
    Rehash(LBad);
    Reject(LBad, LReblend);
    LRejected := False;
    try
      LOther := TWaveStyleProfile.CreateBlendDimensions(LRhythm, LHigh, 0, 0, 1, 0, 1, 0);
    except
      on EAudio do
      begin
        LRejected := True;
      end;
    end;
    Check(LRejected and (LOther = nil), 'Explicit unavailable pitch selection rejects');
    LOther := TWaveStyleProfile.CreateBlendDimensions(LSelected, LLow, 0, 0, 1, 0, 0, 0);
    LReloaded := DecodeWaveStyle(LOther.Encode);
    Check(not LReloaded.HasPitch and (LReloaded.SourceCount = 1) and
      (LReloaded.ParentIdentity(0) = LSelected.Identity),
      'Explicit pitch omission prunes inactive sources but retains full parent ancestry');
    FreeAndNil(LReloaded);
    FreeAndNil(LOther);
    LEvidence := LHigh.EvidenceAt(0);
    LEvidence.Dynamics := Default(TOnsetDynamics);
    LContext := LHigh.CopyContext;
    LNoIntensity := TWaveStyleProfile.CreateSource(LContext, LEvidence, 3);
    LOther := TWaveStyleProfile.CreateBlendDimensions(LRhythm, LNoIntensity, 0, 0, 1, 0, 0, 1);
    LReloaded := DecodeWaveStyle(LOther.Encode);
    Check(LReloaded.HasPitch and LReloaded.HasDynamics,
      'Pitch-only source does not need the independent rhythm source intensity capability');
    WriteLn('Independent dimension weights, exact unchanged rhythm/intensity models, saved pitch reblend and capability failures pass');
  finally
    LExpected.Free;
    LActual.Free;
    LContext.Free;
    LReloaded.Free;
    LOther.Free;
    LNoIntensity.Free;
    LReblend.Free;
    LSelected.Free;
    LHigh.Free;
    LLow.Free;
    LRhythm.Free;
  end;
end;

procedure DimensionOutputChecks(const ABefore, AAfter: String);
var
  LBefore: TJSONObject;
  LAfter: TJSONObject;
  LLayer: Integer;
begin
  LBefore := OutputDocument(ABefore);
  LAfter := nil;
  try
    LAfter := OutputDocument(AAfter);
    for LLayer := 0 to 3 do
    begin
      Check(LBefore.Arrays['context_passes'].Objects[LLayer].AsJSON =
        LAfter.Arrays['context_passes'].Objects[LLayer].AsJSON,
        'Selecting a different pitch source preserves all four independent provider models/states');
    end;
    Check((LBefore.Get('generated_onset_pattern', '') = LAfter.Get('generated_onset_pattern', '')) and
      (LBefore.Get('generated_intensity_pattern', '') = LAfter.Get('generated_intensity_pattern', '')) and
      (LBefore.Arrays['tempo_cells'].AsJSON = LAfter.Arrays['tempo_cells'].AsJSON) and
      (LBefore.Arrays['generated_pitch_notes'].AsJSON <> LAfter.Arrays['generated_pitch_notes'].AsJSON) and
      (LBefore.Get('stereo_sha256', '') <> LAfter.Get('stereo_sha256', '')),
      'Independent pitch-source selection changes measured melody/audio while timing/intensity stay fixed');
    WriteLn('Different saved pitch source changes audible melody while key/tempo/onset/intensity states remain exact');
  finally
    LAfter.Free;
    LBefore.Free;
  end;
end;

procedure DurationArticulationChecks(const APlainName, AArtName, AReblendName,
  ABeforeName, AAfterName: String);
var
  LPlain: TWaveStyleProfile;
  LArt: TWaveStyleProfile;
  LReblend: TWaveStyleProfile;
  LRejectedStyle: TWaveStyleProfile;
  LPlainSpans: TTimedPitchSpans;
  LArtSpans: TTimedPitchSpans;
  LEvidence: TRhythmStyleEvidence;
  LTrack: TPitchTrack;
  LBefore: TJSONObject;
  LAfter: TJSONObject;
  LModelBefore: TWfcSequenceModel;
  LModelAfter: TWfcSequenceModel;
  LIndex: Integer;
  LDuration: Integer;
  LRejected: Boolean;
begin
  LPlain := nil;
  LArt := nil;
  LReblend := nil;
  LRejectedStyle := nil;
  LTrack := nil;
  LBefore := nil;
  LAfter := nil;
  LModelBefore := nil;
  LModelAfter := nil;
  try
    LPlain := DecodeWaveStyle(ReadFileBytes(APlainName, MaximumStyleBytes));
    LArt := DecodeWaveStyle(ReadFileBytes(AArtName, MaximumStyleBytes));
    LReblend := DecodeWaveStyle(ReadFileBytes(AReblendName, MaximumStyleBytes));
    Check(not LPlain.EvidenceAt(0).DurationArticulateOnsets and
      LArt.EvidenceAt(0).DurationArticulateOnsets, 'Saved articulation policy is explicit');
    LPlainSpans := LPlain.CopyTimedDurationSpans(0);
    LArtSpans := LArt.CopyTimedDurationSpans(0);
    LEvidence := LArt.EvidenceAt(0);
    LTrack := LArt.CopyDurationTrack(0);
    Check((LTrack.RunCount = 1) and (Length(LPlainSpans) = 1) and
      (Length(LArtSpans) = 8) and (Length(LEvidence.OnsetFrames) = 7),
      'Seven admitted source attacks split a continuous pitch into eight durations');
    Check((LArtSpans[0].StartTick = LPlainSpans[0].StartTick) and
      (LArtSpans[7].EndTick = LPlainSpans[0].EndTick), 'Articulation retains measured extent');
    for LIndex := 0 to High(LArtSpans) do
    begin
      Check((LArtSpans[LIndex].Kind = pskPitch) and (LArtSpans[LIndex].Note = 69),
        'Repeated attacks retain independently authored A4 reference pitch');
      if LIndex > 0 then
      begin
        { Independently computed source clock: 8000 Hz, 500000 us, PPQ 480. }
        Check((LArtSpans[LIndex].StartTick = (LEvidence.OnsetFrames[LIndex - 1] * 3 + 24) div 25) and
          (LArtSpans[LIndex - 1].EndTick = LArtSpans[LIndex].StartTick),
          'Every new gate begins at its own measured source-onset PPQ boundary');
      end;
    end;
    Check((LReblend.SourceCount = 2) and (LReblend.Depth = 3) and
      (LReblend.NodeCount = 5) and LReblend.EvidenceAt(0).DurationArticulateOnsets and
      (LReblend.EvidenceAt(0).Source.Sha256 = LEvidence.Source.Sha256) and
      (LReblend.PitchWeightAt(0) = 2) and (LReblend.PitchWeightAt(1) = 1),
      'Second blend preserves per-source articulation policy, provenance and weights');
    LModelBefore := LPlain.CopyPitchModel;
    LModelAfter := LArt.CopyPitchModel;
    Check(EncodeWfcSequenceText(LModelBefore) = EncodeWfcSequenceText(LModelAfter),
      'Articulation leaves the centered-pitch model unchanged');
    FreeAndNil(LModelBefore);
    FreeAndNil(LModelAfter);
    LModelBefore := LPlain.CopyDurationModel;
    LModelAfter := LArt.CopyDurationModel;
    Check(EncodeWfcSequenceText(LModelBefore) <> EncodeWfcSequenceText(LModelAfter),
      'Articulation changes the actual learned duration model');
    LRejected := False;
    try
      LRejectedStyle := TWaveStyleProfile.CreateBlend(LPlain, LArt, 0, 0, 1, 1);
    except
      on EAudio do
      begin
        LRejected := True;
      end;
    end;
    Check(LRejected and (LRejectedStyle = nil),
      'Conflicting policies for the same source identity are not silently combined');
    LBefore := OutputDocument(ABeforeName);
    LAfter := OutputDocument(AAfterName);
    for LIndex := 0 to 1 do
    begin
      Check(LBefore.Arrays['duration_providers'].Objects[LIndex].AsJSON =
        LAfter.Arrays['duration_providers'].Objects[LIndex].AsJSON,
        'Controlled articulation comparison preserves accepted key and tempo');
    end;
    Check((LBefore.Arrays['performance_spans'].Count = 1) and
      (LAfter.Arrays['performance_spans'].Count = 8) and
      (LBefore.Get('stereo_frames', 0) = 175113) and
      (LAfter.Get('stereo_frames', 0) = 175113) and
      (LBefore.Get('stereo_sha256', '') <> LAfter.Get('stereo_sha256', '')),
      'Sustained and rearticulated auditions differ over the same measured extent');
    for LIndex := 0 to 7 do
    begin
      LDuration := DecodePitchDurationToken(LAfter.Arrays['duration_providers'].Objects[2].
        Arrays['tokens'].Strings[LIndex]).Duration;
      Check(LDuration = LArtSpans[LIndex].EndTick - LArtSpans[LIndex].StartTick,
        'Controlled generated performance retains every measured attack duration');
    end;
    WriteLn('Saved onset policy: one sustained pitch becomes eight measured attacks; exact source extent, base context and second-blend lineage pass');
  finally
    LModelAfter.Free;
    LModelBefore.Free;
    LAfter.Free;
    LBefore.Free;
    LTrack.Free;
    LRejectedStyle.Free;
    LReblend.Free;
    LArt.Free;
    LPlain.Free;
  end;
end;

procedure DurationArchiveChecks(const ALeftName, ARightName, AReblendName, ASlowName: String);
var
  LLeft: TWaveStyleProfile;
  LRight: TWaveStyleProfile;
  LReblend: TWaveStyleProfile;
  LSlow: TWaveStyleProfile;
  LStripped: TWaveStyleProfile;
  LMixed: TWaveStyleProfile;
  LBadSource: TWaveStyleProfile;
  LContext: TContextProfile;
  LTracks: TMeasuredPitchTracks;
  LTimed: TTimedPitchTracks;
  LExpected: TWfcSequenceModel;
  LActual: TWfcSequenceModel;
  LSlowModel: TWfcSequenceModel;
  LEvidence: TRhythmStyleEvidence;
  LBytes: TAudioBytes;
  LIndex: Integer;
  LRejected: Boolean;
begin
  LLeft := nil;
  LRight := nil;
  LReblend := nil;
  LSlow := nil;
  LStripped := nil;
  LMixed := nil;
  LBadSource := nil;
  LContext := nil;
  LExpected := nil;
  LActual := nil;
  LSlowModel := nil;
  SetLength(LTracks, 2);
  try
    LLeft := DecodeWaveStyle(ReadFileBytes(ALeftName, MaximumStyleBytes));
    LRight := DecodeWaveStyle(ReadFileBytes(ARightName, MaximumStyleBytes));
    LReblend := DecodeWaveStyle(ReadFileBytes(AReblendName, MaximumStyleBytes));
    LSlow := DecodeWaveStyle(ReadFileBytes(ASlowName, MaximumStyleBytes));
    Check(LReblend.HasDuration and (LReblend.SourceCount = 2) and
      (LReblend.Depth = 3) and (LReblend.NodeCount = 5) and
      (LReblend.PitchWeightAt(0) = 2) and (LReblend.PitchWeightAt(1) = 1) and
      (LReblend.ParentIdentity(1) = LLeft.Identity), 'Duration second derivation retains source weights and parents');
    LTracks[0] := LLeft.CopyDurationTrack(0);
    LTracks[1] := LRight.CopyDurationTrack(0);
    Check(LTracks[0].RunCount = 6, 'Saved dense evidence retains the six-note performance');
    SetLength(LTimed, 2);
    LTimed[0] := LLeft.CopyTimedDurationSpans(0);
    LTimed[1] := LRight.CopyTimedDurationSpans(0);
    LExpected := LearnPitchDurationModel(LTimed, [2, 1], 3);
    LActual := LReblend.CopyDurationModel;
    LSlowModel := LSlow.CopyDurationModel;
    Check((EncodeWfcSequenceText(LExpected) = EncodeWfcSequenceText(LActual)) and
      (EncodeWfcSequenceText(LSlowModel) = EncodeWfcSequenceText(LActual)),
      'Saved duration model follows exact weighted sources and survives independent tempo selection');
    Check(LSlow.DurationTicksPerQuarter = 480,
      'Selecting output tempo preserves the musical duration timebase');
    for LIndex := 0 to 1 do
    begin
      LEvidence := LReblend.EvidenceAt(LIndex);
      Check(HashAudioBytes(ReadFileBytes(ExtractFilePath(ALeftName) + LEvidence.Source.Name,
        16 * 1024 * 1024)) = LEvidence.Source.Sha256, 'Dense source archive binds actual source bytes');
    end;
    LBytes := LReblend.Encode;
    LBytes[Length(LBytes) - 65] := Ord('x');
    Rehash(LBytes);
    Reject(LBytes, LReblend);
    LEvidence := LLeft.EvidenceAt(0);
    LEvidence.Duration.Estimates[0].AcRms := 1;
    LContext := LLeft.CopyContext;
    LRejected := False;
    try
      LBadSource := TWaveStyleProfile.CreateSource(LContext, LEvidence, 3);
    except
      on EAudio do
      begin
        LRejected := True;
      end;
    end;
    Check(LRejected and (LBadSource = nil) and
      (LLeft.EvidenceAt(0).Duration.Estimates[0].AcRms = 0),
      'Forged silence evidence rejects while the original remains detached');
    FreeAndNil(LContext);
    LContext := LRight.CopyContext;
    LEvidence := LRight.EvidenceAt(0);
    LEvidence.Duration := Default(TPitchTrackEvidence);
    LStripped := TWaveStyleProfile.CreateSource(LContext, LEvidence, 3);
    LMixed := TWaveStyleProfile.CreateBlend(LLeft, LStripped, 0, 0, 1, 1);
    Check(LMixed.HasPitch and not LMixed.HasDuration,
      'Unavailable dense evidence remains explicit without discarding ordinary pitch support');
    LRejected := False;
    FreeAndNil(LSlowModel);
    try
      LSlowModel := LMixed.CopyDurationModel;
    except
      on EAudio do
      begin
        LRejected := True;
      end;
    end;
    Check(LRejected and (LSlowModel = nil), 'Incomplete duration coverage cannot generate a duration model');
    WriteLn('Dense archive replay, weighted second derivation, independent tempo, forged evidence and capability scope pass');
  finally
    LSlowModel.Free;
    LActual.Free;
    LExpected.Free;
    LTracks[1].Free;
    LTracks[0].Free;
    LContext.Free;
    LBadSource.Free;
    LMixed.Free;
    LStripped.Free;
    LSlow.Free;
    LReblend.Free;
    LRight.Free;
    LLeft.Free;
  end;
end;

procedure DurationOutputChecks(const AStyleName, AOutput: String);
var
  LStyle: TWaveStyleProfile;
  LContext: TContextProfile;
  LModels: array[0..2] of TWfcSequenceModel;
  LDocument: TJSONObject;
  LClock: TTempoMap;
  LClip: TAudioClip;
  LTempos: TTempoChanges;
  LStates: TWfcSequenceStateIndices;
  LValidation: TWfcSequenceGraphValidationReport;
  LRow: TJSONObject;
  LSpan: TPitchDurationCell;
  LPcm: TAudioSamples;
  LEstimate: TPitchEstimate;
  LPitchOptions: TPitchOptions;
  LHash: String;
  LLayer: Integer;
  LIndex: Integer;
  LCumulativeTicks: Integer;
  LTick: Integer;
  LEndTick: Integer;
  LStart: Integer;
  LEnd: Integer;
  LFrame: Integer;
  LWindow: Integer;
  LNoteCount: Integer;
  LSpanCount: Integer;
  LExtent: TWfcSequenceExtent;
  LProviderExtent: TWfcSequenceExtent;
  LProviderCount: Integer;
  LTempoPosition: Integer;
  LHoldContext: Boolean;
begin
  LStyle := nil;
  LContext := nil;
  LDocument := nil;
  LClock := nil;
  LClip := nil;
  for LLayer := 0 to 2 do
  begin
    LModels[LLayer] := nil;
  end;
  try
    LStyle := DecodeWaveStyle(ReadFileBytes(AStyleName, MaximumStyleBytes));
    LContext := LStyle.CopyContext;
    LModels[0] := LContext.CopyModel(cdKey);
    LModels[1] := LContext.CopyModel(cdTempo);
    LModels[2] := LStyle.CopyDurationModel;
    LDocument := OutputDocument(AOutput);
    Check((LDocument.Get('wave_style_sha256', '') = LStyle.Identity) and
      (LDocument.Arrays['provider_passes'].Count = 3), 'Saved style binds three actual provider passes');
    Check(LDocument.Get('model_sha256', '') = HashText(EncodeWfcSequenceText(LModels[2])),
      'Rendered duration model identity matches saved style');
    LSpanCount := LDocument.Arrays['spans'].Count;
    LExtent := wseFragment;
    if LDocument.Get('sequence_extent', '') = 'prefix' then
    begin
      LExtent := wsePrefix;
    end
    else
    begin
      Check(LDocument.Get('sequence_extent', '') = 'fragment', 'Declared WFC sequence extent');
    end;
    Check((LSpanCount >= 1) and (LSpanCount <= 1024), 'Bounded generated span extent');
    LHoldContext := LDocument.Get('context_mode', '') = 'hold';
    Check(LHoldContext or (LDocument.Get('context_mode', '') = 'sequence'),
      'Explicit output context policy');
    if LHoldContext then
    begin
      HeldContextToken(LModels[0], cdKey);
      HeldContextToken(LModels[1], cdTempo);
    end;
    for LLayer := 0 to 2 do
    begin
      LRow := LDocument.Arrays['provider_passes'].Objects[LLayer];
      LProviderCount := LSpanCount;
      LProviderExtent := LExtent;
      if LHoldContext and (LLayer < 2) then
      begin
        LProviderCount := 1;
        LProviderExtent := wsePrefix;
        Check(LRow.Get('sequence_extent', '') = 'prefix', 'Held provider starts in observed history');
      end
      else
      begin
        Check(LRow.Get('sequence_extent', '') = LDocument.Get('sequence_extent', ''),
          'Sequence provider retains requested extent');
      end;
      SetLength(LStates, LProviderCount);
      Check((LRow.Get('model_sha256', '') = HashText(EncodeWfcSequenceText(LModels[LLayer]))) and
        (LRow.Arrays['states'].Count = LProviderCount), 'Actual saved provider model and extent');
      for LIndex := 0 to LProviderCount - 1 do
      begin
        LStates[LIndex] := LRow.Arrays['states'].Integers[LIndex];
        Check(String(LModels[LLayer].ProjectStateToken(LStates[LIndex])) =
          LRow.Arrays['tokens'].Strings[LIndex], 'Provider token is its actual solved-state projection');
      end;
      Check(ValidateSequenceStatePath(LModels[LLayer], LStates, LProviderExtent, LValidation),
        'Actual WFC validates every saved provider state path');
    end;
    SetLength(LTempos, LSpanCount);
    LCumulativeTicks := 0;
    LTick := 0;
    for LIndex := 0 to LSpanCount - 1 do
    begin
      LSpan := DecodePitchDurationToken(LModels[2].ProjectStateToken(LStates[LIndex]));
      LRow := LDocument.Arrays['spans'].Objects[LIndex];
      Inc(LCumulativeTicks, LSpan.Duration);
      LEndTick := LRow.Get('end_tick', -1);
      Check((LRow.Get('start_tick', -1) = LTick) and (LEndTick > LTick) and
        (LRow.Get('token', '') = String(LModels[2].ProjectStateToken(LStates[LIndex]))),
        'Duration output preserves span identity and cumulative boundaries');
      Check(LEndTick = LCumulativeTicks, 'Output accumulates normalized PPQ duration tokens exactly');
      LTempoPosition := LIndex;
      if LHoldContext then
      begin
        LTempoPosition := 0;
      end;
      LTempos[LIndex] := MakeTempoChange(LTick, TempoContextFromToken(
        LDocument.Arrays['provider_passes'].Objects[1].Arrays['tokens'].Strings[LTempoPosition]));
      LTick := LEndTick;
    end;
    if LHoldContext then
    begin
      Check(LDocument.Get('context_hold_end_tick', -1) = LTick,
        'Explicit held context covers the exact generated endpoint');
    end;
    LClock := TTempoMap.Create(LContext.TicksPerQuarter, LTick, LTempos);
    LClip := LoadWaveSource(AOutput, LHash);
    Check((LDocument.Get('output_sha256', '') = LHash) and
      (LClip.FrameCount = LClock.FrameAtTick(LTick, LClip.SampleRate)),
      'Actual WAV extent/hash follows the solved tempo clock');
    LNoteCount := 0;
    for LIndex := 0 to LSpanCount - 1 do
    begin
      LSpan := DecodePitchDurationToken(LModels[2].ProjectStateToken(LStates[LIndex]));
      LRow := LDocument.Arrays['spans'].Objects[LIndex];
      LStart := LClock.FrameAtTick(LRow.Get('start_tick', -1), LClip.SampleRate);
      LEnd := LClock.FrameAtTick(LRow.Get('end_tick', -1), LClip.SampleRate);
      if LSpan.Kind = pskPitch then
      begin
        LPitchOptions := DefaultPitchOptions;
        LWindow := Min(LEnd - LStart,
          2 * (Ceil(LClip.SampleRate / LPitchOptions.MinimumHz) + 1));
        Check(LWindow >= 8, 'Pitched span permits an independent PCM measurement');
        { Duration limits the lowest measurable frequency. Do not tune the
          estimator to the expected note or include neighboring pitch spans. }
        LPitchOptions.MinimumHz := Max(LPitchOptions.MinimumHz,
          LClip.SampleRate / (LWindow div 2 - 2));
        SetLength(LPcm, LWindow);
        LStart := (LStart + LEnd - LWindow) div 2;
        for LFrame := 0 to LWindow - 1 do
        begin
          LPcm[LFrame] := LClip.SampleAt(LStart + LFrame, 0);
        end;
        LEstimate := EstimatePitch(LPcm, LClip.SampleRate, 1, 0, LPitchOptions);
        Check(AdmitPitchNote(LEstimate, 25) = LSpan.Note,
          Format('Audible pitch differs at span %d: expected %d, measured %d (%.3f Hz)',
            [LIndex, LSpan.Note, AdmitPitchNote(LEstimate, 25), LEstimate.FrequencyHz]));
        Inc(LNoteCount);
      end
      else
      begin
        for LFrame := LStart to LEnd - 1 do
        begin
          Check((LClip.SampleAt(LFrame, 0) = 0) and (LClip.SampleAt(LFrame, 1) = 0),
            'Unknown/silent span policy holds after synthesis release tails');
        end;
      end;
    end;
    Check((LNoteCount > 0) and (LDocument.Arrays['notes'].Count = LNoteCount),
      'Every generated pitched span is represented in audible output');
    WriteLn('Saved duration/style binding, three WFC paths, exact tempo/gate timing and ',
      LNoteCount, ' audible pitches pass');
  finally
    LClip.Free;
    LClock.Free;
    LDocument.Free;
    for LLayer := 0 to 2 do
    begin
      LModels[LLayer].Free;
    end;
    LContext.Free;
    LStyle.Free;
  end;
end;

procedure DurationControls(const ABefore, AAfter: String; const ATempoOnly: Boolean;
  const AExpectedLock: String = '0:384');
var
  LBefore: TJSONObject;
  LAfter: TJSONObject;
  LLayer: Integer;
  LSeparator: Integer;
  LCell: Integer;
  LDuration: Integer;
begin
  LBefore := OutputDocument(ABefore);
  LAfter := nil;
  try
    LAfter := OutputDocument(AAfter);
    Check(LBefore.Arrays['provider_passes'].Objects[0].AsJSON =
      LAfter.Arrays['provider_passes'].Objects[0].AsJSON, 'Duration/tempo edit preserves accepted key provider');
    if ATempoOnly then
    begin
      LLayer := 2;
      Check((LBefore.Arrays['notes'].AsJSON = LAfter.Arrays['notes'].AsJSON) and
        (LBefore.Get('tempo_us', 0) = 500000) and (LAfter.Get('tempo_us', 0) = 750000) and
        (Abs(Int64(LAfter.Get('frames', 0)) * 2 - Int64(LBefore.Get('frames', 0)) * 3) <= 2),
        'Selecting slower tempo retains notes and applies the requested 3:2 time scale');
    end
    else
    begin
      LLayer := 1;
      LSeparator := Pos(':', AExpectedLock);
      Check(LSeparator > 1, 'Expected duration control must specify CELL:TICKS');
      LCell := StrToInt(Copy(AExpectedLock, 1, LSeparator - 1));
      LDuration := StrToInt(Copy(AExpectedLock, LSeparator + 1, MaxInt));
      Check((LCell >= 0) and (LCell < LAfter.Arrays['spans'].Count), 'Expected duration cell');
      Check(LAfter.Get('context_states_preserved', False) and (LAfter.Get('regenerated_pass', -1) = 2) and
        (LAfter.Get('duration_lock', '') = AExpectedLock) and
        (DecodePitchDurationToken(LAfter.Arrays['spans'].Objects[LCell].Get('token', '')).Duration = LDuration),
        'Duration pin regenerates only the performance pass and reaches an observed duration');
    end;
    Check((LBefore.Arrays['provider_passes'].Objects[LLayer].AsJSON =
      LAfter.Arrays['provider_passes'].Objects[LLayer].AsJSON) and
      (LBefore.Get('output_sha256', '') <> LAfter.Get('output_sha256', '')),
      'Independent accepted provider remains exact while realized audio changes');
    WriteLn('Saved duration and tempo controls preserve independent states and change actual audio');
  finally
    LAfter.Free;
    LBefore.Free;
  end;
end;

procedure DurationVoiceOutput(const AStyleName, AOutput: String; const ARequireTimedHold: Boolean = False);
var
  LStyle: TWaveStyleProfile;
  LContext: TContextProfile;
  LModels: array[0..2] of TWfcSequenceModel;
  LVoiceModel: TWfcSequenceModel;
  LDocument: TJSONObject;
  LRow: TJSONObject;
  LStates: TWfcSequenceStateIndices;
  LProof: TWfcSequenceGraphValidationReport;
  LClip: TAudioClip;
  LMidi: TNoteSequence;
  LClock: TTempoMap;
  LImport: TMidiNoteReport;
  LSpan: TPitchDurationCell;
  LFrame: TWfcMusicEnsembleFrame;
  LSingleton: TWfcMusicEnsembleFrame;
  LHash: String;
  LBytes: TAudioBytes;
  LLayer: Integer;
  LIndex: Integer;
  LSegment: Integer;
  LPosition: Integer;
  LCount: Integer;
  LProviderCount: Integer;
  LCumulativeTicks: Integer;
  LTick: Integer;
  LEndTick: Integer;
  LVoice: Integer;
  LTone: Integer;
  LNote: Integer;
  LMatches: Integer;
  LNoteCount: Integer;
  LTempoCells: Integer;
  LKeyCells: Integer;
  LKeyStep: Integer;
  LAtKey: TKeyContext;
  LTempoStep: Integer;
  LTempoValue: Integer;
  LPreviousTempo: Integer;
  LChangeCount: Integer;
  LPart: TJSONObject;
  LPartFrame: TWfcMusicEnsembleFrame;
  LPartCell: Integer;
  LPartTick: Integer;
  LPartEnd: Integer;
  LHoldCount: Integer;
  LExpectedAction: TWfcMusicCellAction;
  LStartFrame: Integer;
  LEndFrame: Integer;
  LPcmFrame: Integer;
  LEnergy: Double;
begin
  LStyle := nil;
  LContext := nil;
  LDocument := nil;
  LClip := nil;
  LMidi := nil;
  LClock := nil;
  LVoiceModel := nil;
  for LLayer := 0 to 2 do
  begin
    LModels[LLayer] := nil;
  end;
  try
    LStyle := DecodeWaveStyle(ReadFileBytes(AStyleName, MaximumStyleBytes));
    LContext := LStyle.CopyContext;
    LModels[0] := LContext.CopyModel(cdKey);
    LModels[1] := LContext.CopyModel(cdTempo);
    LModels[2] := LStyle.CopyDurationModel;
    LDocument := OutputDocument(AOutput);
    LCount := LDocument.Get('cells', 0);
    LKeyCells := LDocument.Get('duration_key_cells', 0);
    LKeyStep := LDocument.Get('duration_key_step_ticks', LContext.StepTicks);
    Check((LKeyCells >= 0) and (LKeyCells <= 1024) and
      (LKeyStep = LContext.StepTicks), 'Key provider retains its independent grid resolution');
    LTempoCells := LDocument.Get('duration_tempo_cells', 0);
    LTempoStep := LDocument.Get('duration_tempo_step_ticks', LContext.StepTicks);
    Check((LTempoCells >= 0) and (LTempoCells <= 1024) and
      (LTempoStep = LContext.StepTicks), 'Tempo provider retains its explicit grid resolution');
    Check((LCount >= 1) and (LCount <= 64) and
      (LDocument.Get('wave_style_sha256', '') = LStyle.Identity) and
      (LDocument.Arrays['performance_spans'].Count = LCount),
      'Duration voice source identity and explicit span extent');
    Check((LDocument.Arrays['duration_providers'].Count = 3) and
      (LDocument.Arrays['models'].Count = 5), 'Three saved providers feed five dependent voice models');
    for LLayer := 0 to 2 do
    begin
      LProviderCount := 1;
      if (LLayer = 0) and (LKeyCells > 0) then
      begin
        LProviderCount := LKeyCells;
      end;
      if (LLayer = 1) and (LTempoCells > 0) then
      begin
        LProviderCount := LTempoCells;
      end;
      if LLayer = 2 then
      begin
        LProviderCount := LCount;
      end;
      LRow := LDocument.Arrays['duration_providers'].Objects[LLayer];
      Check((LRow.Get('model_sha256', '') = HashText(EncodeWfcSequenceText(LModels[LLayer]))) and
        (LRow.Arrays['states'].Count = LProviderCount), 'Saved provider model/count binding');
      SetLength(LStates, LProviderCount);
      for LIndex := 0 to LProviderCount - 1 do
      begin
        LStates[LIndex] := LRow.Arrays['states'].Integers[LIndex];
        Check(String(LModels[LLayer].ProjectStateToken(LStates[LIndex])) =
          LRow.Arrays['tokens'].Strings[LIndex], 'Provider tokens are actual state projections');
      end;
      Check(ValidateSequenceStatePath(LModels[LLayer], LStates, wsePrefix, LProof),
        'Actual saved provider prefix path');
    end;
    Check(KeyContextFromToken(LDocument.Arrays['duration_providers'].Objects[0].Arrays['tokens'].Strings[0]).Root =
      LDocument.Get('context_key_root', -2), 'Initial saved key supplies accompaniment context');
    for LLayer := 0 to 4 do
    begin
      LRow := LDocument.Arrays['models'].Objects[LLayer];
      LVoiceModel := DecodeWfcSequenceText(LRow.Get('model', ''));
      Check(LRow.Get('sha256', '') = HashText(EncodeWfcSequenceText(LVoiceModel)),
        'Voice model hash');
      SetLength(LStates, LCount);
      LPosition := 0;
      for LSegment := 0 to LDocument.Arrays['segments'].Count - 1 do
      begin
        LRow := LDocument.Arrays['segments'].Objects[LSegment].Arrays['layers'].Objects[LLayer];
        for LIndex := 0 to LRow.Arrays['states'].Count - 1 do
        begin
          Check(LPosition < LCount, 'Voice state count remains bounded');
          LStates[LPosition] := LRow.Arrays['states'].Integers[LIndex];
          Check(String(LVoiceModel.ProjectStateToken(LStates[LPosition])) =
            LRow.Arrays['tokens'].Strings[LIndex], 'Voice state projects its reported token');
          LFrame := DecodeWfcMusicEnsembleFrame(LDocument.Arrays['frames'].Strings[LPosition]);
          if LLayer >= 2 then
          begin
            LSingleton := DecodeWfcMusicEnsembleFrame(LRow.Arrays['tokens'].Strings[LIndex]);
            Check((Length(LSingleton.Voices) = 1) and
              (LSingleton.Voices[0].Action = LFrame.Voices[LLayer - 2].Action) and
              (Length(LSingleton.Voices[0].Tones) = Length(LFrame.Voices[LLayer - 2].Tones)),
              'Actual independent voice token reaches the combined frame');
            for LTone := 0 to High(LSingleton.Voices[0].Tones) do
            begin
              Check((LSingleton.Voices[0].Tones[LTone].Pitch = LFrame.Voices[LLayer - 2].Tones[LTone].Pitch) and
                (LSingleton.Voices[0].Tones[LTone].Velocity = LFrame.Voices[LLayer - 2].Tones[LTone].Velocity),
                'Combined voice retains independent pitch/velocity');
            end;
          end;
          Inc(LPosition);
        end;
      end;
      Check((LPosition = LCount) and
        ValidateSequenceStatePath(LVoiceModel, LStates, wseWhole, LProof),
        'Every independent voice/harmony/rhythm path retains complete learned boundaries');
      FreeAndNil(LVoiceModel);
    end;
    LClip := LoadWaveSource(AOutput, LHash);
    Check(LDocument.Get('stereo_sha256', '') = LHash, 'Actual stereo WAV binding');
    LBytes := ReadFileBytes(AOutput + '.mid', 16777216);
    Check(LDocument.Get('midi_sha256', '') = HashAudioBytes(LBytes), 'Actual MIDI binding');
    LMidi := DecodeMidiNotes(LBytes, DefaultMidiNoteOptions, LImport);
    LClock := LMidi.CopyClock;
    Check(LClock.TicksPerQuarter = LContext.TicksPerQuarter, 'Saved PPQ reaches exported MIDI');
    LProviderCount := Max(1, LTempoCells);
    LChangeCount := 0;
    LPreviousTempo := 0;
    for LIndex := 0 to LProviderCount - 1 do
    begin
      LTick := LIndex * LTempoStep;
      if LTick >= LMidi.LengthTicks then
      begin
        Break;
      end;
      LTempoValue := TempoContextFromToken(LDocument.Arrays['duration_providers'].
        Objects[1].Arrays['tokens'].Strings[LIndex]);
      if LTempoValue <> LPreviousTempo then
      begin
        Check((LChangeCount < LClock.ChangeCount) and
          (LClock.ChangeAt(LChangeCount).Tick = LTick) and
          (LClock.ChangeAt(LChangeCount).MicrosecondsPerQuarter = LTempoValue),
          'Every MIDI tempo change occurs at its independently generated provider cell');
        Inc(LChangeCount);
      end;
      LPreviousTempo := LTempoValue;
    end;
    Check(LChangeCount = LClock.ChangeCount, 'MIDI contains no undeclared tempo changes');
    if LTempoCells > 0 then
    begin
      Check(Int64(LTempoCells) * LTempoStep >= LMidi.LengthTicks,
        'Finite provider coverage includes the complete performance');
    end;
    LBytes := ReadFileBytes(AOutput + '.preview.wav', 33554432);
    Check((LDocument.Get('preview_sha256', '') = HashAudioBytes(LBytes)) and
      LDocument.Get('preview_verified_against_wfc', False), 'Actual independent WFC preview binding');
    LCumulativeTicks := 0;
    LTick := 0;
    LNoteCount := 0;
    for LIndex := 0 to LCount - 1 do
    begin
      LRow := LDocument.Arrays['performance_spans'].Objects[LIndex];
      LSpan := DecodePitchDurationToken(LDocument.Arrays['duration_providers'].Objects[2].
        Arrays['tokens'].Strings[LIndex]);
      Inc(LCumulativeTicks, LSpan.Duration);
      LEndTick := LRow.Get('end_tick', -1);
      Check((LRow.Get('start_tick', -1) = LTick) and (LEndTick > LTick), 'Contiguous realized boundaries');
      Check(LEndTick = LCumulativeTicks, 'Voice timing accumulates normalized PPQ duration tokens exactly');
      LPosition := 0;
      if LKeyCells > 0 then
      begin
        Check(Int64(LKeyCells) * LKeyStep >= LMidi.LengthTicks, 'Finite key scope covers output');
        LPosition := LTick div LKeyStep;
      end;
      LAtKey := KeyContextFromToken(LDocument.Arrays['duration_providers'].Objects[0].
        Arrays['tokens'].Strings[LPosition]);
      Check((LAtKey.Root >= 0) and (LRow.Get('key_root', LAtKey.Root) = LAtKey.Root) and
        (LRow.Get('key_mode_ordinal', Ord(LAtKey.Mode)) = Ord(LAtKey.Mode)),
        'Each performance attack uses the key at its actual PPQ start');
      LFrame := DecodeWfcMusicEnsembleFrame(LDocument.Arrays['frames'].Strings[LIndex]);
      Check(Length(LFrame.Voices) = 3, 'Three realized voices');
      for LVoice := 0 to 2 do
      begin
        if LSpan.Kind = pskPitch then
        begin
          Check(LFrame.Voices[LVoice].Action = wmcaAttack, 'Measured pitch span starts every arranged voice');
          if LVoice = 2 then
          begin
            Check((Length(LFrame.Voices[LVoice].Tones) = 1) and
              (LFrame.Voices[LVoice].Tones[0].Pitch = LSpan.Note), 'Measured melody pitch survives accompaniment');
          end;
          for LTone := 0 to High(LFrame.Voices[LVoice].Tones) do
          begin
            LMatches := 0;
            for LNote := 0 to LMidi.NoteCount - 1 do
            begin
              if (LMidi.GateAt(LNote).Channel = LVoice) and
                (LMidi.GateAt(LNote).Pitch = LFrame.Voices[LVoice].Tones[LTone].Pitch) and
                (LMidi.GateAt(LNote).Velocity = LFrame.Voices[LVoice].Tones[LTone].Velocity) and
                (LMidi.GateAt(LNote).StartTick = LTick) and
                (LMidi.GateAt(LNote).EndTick = LEndTick) then
              begin
                Inc(LMatches);
              end;
            end;
            Check(LMatches = 1, 'Every bass/chord/melody MIDI gate uses the measured span endpoints');
            Inc(LNoteCount);
          end;
        end
        else
        begin
          Check((LFrame.Voices[LVoice].Action = wmcaRest) and
            (Length(LFrame.Voices[LVoice].Tones) = 0), 'Unknown/silence is explicitly arranged rest');
        end;
      end;
      LStartFrame := LMidi.FrameAtTick(LTick, LClip.SampleRate);
      LEndFrame := LMidi.FrameAtTick(LEndTick, LClip.SampleRate);
      LEnergy := 0;
      for LPcmFrame := LStartFrame to LEndFrame - 1 do
      begin
        LEnergy := LEnergy + Sqr(LClip.SampleAt(LPcmFrame, 0)) + Sqr(LClip.SampleAt(LPcmFrame, 1));
      end;
      if LSpan.Kind = pskPitch then
      begin
        Check(LEnergy > 0, 'Pitched performance span is audible');
      end
      else
      begin
        Check(LEnergy = 0, 'Unknown/silent intervals contain no synthesized release tails');
      end;
      LTick := LEndTick;
    end;
    Check((LMidi.NoteCount = LNoteCount) and (LMidi.LengthTicks = LTick) and
      (LDocument.Get('realized_length_ticks', -1) = LTick) and
      (LClip.FrameCount = LMidi.FrameAtTick(LTick, LClip.SampleRate)),
      'Native MIDI and stereo audio cover the exact measured timeline without logical padding');
    LPartTick := 0;
    LHoldCount := 0;
    if LDocument.Find('playback_parts') <> nil then
    begin
      for LIndex := 0 to LDocument.Arrays['playback_parts'].Count - 1 do
      begin
        LPart := LDocument.Arrays['playback_parts'].Objects[LIndex];
        LPartCell := LPart.Get('source_cell', -1);
        Check((LPartCell >= 0) and (LPartCell < LCount), 'Playback part belongs to a learned span');
        LRow := LDocument.Arrays['performance_spans'].Objects[LPartCell];
        LPartEnd := LPart.Get('start_tick', -1) + LPart.Get('length_ticks', 0);
        Check((LPart.Get('start_tick', -1) = LPartTick) and (LPartEnd > LPartTick) and
          (LPartTick >= LRow.Get('start_tick', -1)) and (LPartEnd <= LRow.Get('end_tick', -1)),
          'Playback partitions cover source spans contiguously without cropping their gates');
        LPartFrame := DecodeWfcMusicEnsembleFrame(LPart.Get('frame', ''));
        LFrame := DecodeWfcMusicEnsembleFrame(LDocument.Arrays['frames'].Strings[LPartCell]);
        Check(Length(LPartFrame.Voices) = Length(LFrame.Voices), 'Playback retains all voices');
        for LVoice := 0 to High(LFrame.Voices) do
        begin
          LExpectedAction := LFrame.Voices[LVoice].Action;
          if (LPartTick > LRow.Get('start_tick', -1)) and (LExpectedAction = wmcaAttack) then
          begin
            LExpectedAction := wmcaHold;
            Inc(LHoldCount);
          end;
          Check((LPartFrame.Voices[LVoice].Action = LExpectedAction) and
            (Length(LPartFrame.Voices[LVoice].Tones) = Length(LFrame.Voices[LVoice].Tones)),
            'Tempo subdivisions hold existing notes without adding attacks');
          for LTone := 0 to High(LFrame.Voices[LVoice].Tones) do
          begin
            Check((LPartFrame.Voices[LVoice].Tones[LTone].Pitch =
              LFrame.Voices[LVoice].Tones[LTone].Pitch) and
              (LPartFrame.Voices[LVoice].Tones[LTone].Velocity =
              LFrame.Voices[LVoice].Tones[LTone].Velocity), 'Playback retains pitch and velocity');
          end;
        end;
        LPosition := 0;
        if LTempoCells > 0 then
        begin
          LPosition := LPartTick div LTempoStep;
        end;
        Check(LPart.Get('tempo_us', 0) = TempoContextFromToken(LDocument.Arrays['duration_providers'].
          Objects[1].Arrays['tokens'].Strings[LPosition]), 'Playback part uses the generated tempo at its tick');
        Check(LMidi.FrameAtTick(LPartEnd, LClip.SampleRate) >=
          LMidi.FrameAtTick(LPartTick, LClip.SampleRate), 'Playback clock remains monotonic');
        LPartTick := LPartEnd;
      end;
      Check(LPartTick = LTick, 'Playback partitions retain complete performance extent');
    end;
    if ARequireTimedHold then
    begin
      Check((LTempoCells > 0) and (LChangeCount > 1) and (LHoldCount > 0),
        'Timed fixture must exercise a real tempo change inside a sounding span');
      WriteLn('Independent tempo cells change inside sounding spans without reattacking notes');
    end;
    WriteLn('Three saved providers, five actual voice paths, ', LNoteCount,
      ' exact MIDI gates and audible/silent performance spans pass');
  finally
    LClock.Free;
    LMidi.Free;
    LClip.Free;
    LVoiceModel.Free;
    LDocument.Free;
    LContext.Free;
    LStyle.Free;
    for LLayer := 0 to 2 do
    begin
      LModels[LLayer].Free;
    end;
  end;
end;

procedure DurationKeyEdit(const ABefore, AAfter: String);
var
  LBefore: TJSONObject;
  LAfter: TJSONObject;
  LBeforeFrame: TWfcMusicEnsembleFrame;
  LAfterFrame: TWfcMusicEnsembleFrame;
  LBeforeKey: TKeyContext;
  LAfterKey: TKeyContext;
  LPreviousKey: TKeyContext;
  LCurrentKey: TKeyContext;
  LCell: Integer;
  LVoice: Integer;
  LTone: Integer;
  LPosition: Integer;
  LTick: Integer;
  LEnd: Integer;
  LStep: Integer;
  LChangeTick: Integer;
  LChanged: Integer;
  LHeld: Integer;
  LExpected: Integer;
begin
  LBefore := OutputDocument(ABefore);
  LAfter := nil;
  try
    LAfter := OutputDocument(AAfter);
    Check((LAfter.Get('key_lock', '') = '3:2:minor') and
      LAfter.Get('key_edit_independent_states_preserved', False) and
      (LAfter.Get('regenerated_key_pass', -1) = 0),
      'Selective key pin edits only the named key provider');
    Check((LBefore.Arrays['duration_providers'].Objects[1].AsJSON =
      LAfter.Arrays['duration_providers'].Objects[1].AsJSON) and
      (LBefore.Arrays['duration_providers'].Objects[2].AsJSON =
      LAfter.Arrays['duration_providers'].Objects[2].AsJSON),
      'Key edit retains exact accepted tempo and measured performance states');
    LStep := LAfter.Get('duration_key_step_ticks', 0);
    Check((LStep > 0) and (LBefore.Get('duration_key_step_ticks', 0) = LStep) and
      (LBefore.Arrays['frames'].Count = LAfter.Arrays['frames'].Count), 'Comparable key scopes and voice counts');
    LChanged := 0;
    LHeld := 0;
    for LCell := 0 to LAfter.Arrays['frames'].Count - 1 do
    begin
      LTick := LAfter.Arrays['performance_spans'].Objects[LCell].Get('start_tick', -1);
      LEnd := LAfter.Arrays['performance_spans'].Objects[LCell].Get('end_tick', -1);
      Check((LTick = LBefore.Arrays['performance_spans'].Objects[LCell].Get('start_tick', -2)) and
        (LEnd = LBefore.Arrays['performance_spans'].Objects[LCell].Get('end_tick', -2)),
        'Key edit preserves musical gate timing');
      LPosition := LTick div LStep;
      LBeforeKey := KeyContextFromToken(LBefore.Arrays['duration_providers'].Objects[0].Arrays['tokens'].Strings[LPosition]);
      LAfterKey := KeyContextFromToken(LAfter.Arrays['duration_providers'].Objects[0].Arrays['tokens'].Strings[LPosition]);
      LBeforeFrame := DecodeWfcMusicEnsembleFrame(LBefore.Arrays['frames'].Strings[LCell]);
      LAfterFrame := DecodeWfcMusicEnsembleFrame(LAfter.Arrays['frames'].Strings[LCell]);
      for LVoice := 0 to 2 do
      begin
        Check((LBeforeFrame.Voices[LVoice].Action = LAfterFrame.Voices[LVoice].Action) and
          (Length(LBeforeFrame.Voices[LVoice].Tones) = Length(LAfterFrame.Voices[LVoice].Tones)),
          'Key edit preserves voice attacks/rests and chord sizes');
        for LTone := 0 to High(LBeforeFrame.Voices[LVoice].Tones) do
        begin
          LExpected := LBeforeFrame.Voices[LVoice].Tones[LTone].Pitch;
          if LVoice < 2 then
          begin
            LExpected := MapDiatonicPitch(LExpected, LBeforeKey, LAfterKey);
          end;
          Check((LAfterFrame.Voices[LVoice].Tones[LTone].Pitch = LExpected) and
            (LAfterFrame.Voices[LVoice].Tones[LTone].Velocity =
              LBeforeFrame.Voices[LVoice].Tones[LTone].Velocity),
            'New attack mapping at cell ' + IntToStr(LCell) + ', voice ' + IntToStr(LVoice) +
            ', tone ' + IntToStr(LTone) + ': expected ' + IntToStr(LExpected) +
            ', actual ' + IntToStr(LAfterFrame.Voices[LVoice].Tones[LTone].Pitch));
          if LExpected <> LBeforeFrame.Voices[LVoice].Tones[LTone].Pitch then
          begin
            Inc(LChanged);
          end;
        end;
      end;
      for LPosition := 1 to LAfter.Get('duration_key_cells', 0) - 1 do
      begin
        LChangeTick := LPosition * LStep;
        if (LChangeTick <= LTick) or (LChangeTick >= LEnd) then
        begin
          Continue;
        end;
        LPreviousKey := KeyContextFromToken(LAfter.Arrays['duration_providers'].Objects[0].
          Arrays['tokens'].Strings[LPosition - 1]);
        LCurrentKey := KeyContextFromToken(LAfter.Arrays['duration_providers'].Objects[0].
          Arrays['tokens'].Strings[LPosition]);
        if not SameKeyContext(LPreviousKey, LCurrentKey) and
          (LAfterFrame.Voices[0].Action = wmcaAttack) then
        begin
          Inc(LHeld);
          Check(SameKeyContext(LBeforeKey, LAfterKey) and
            (LBefore.Arrays['frames'].Strings[LCell] = LAfter.Arrays['frames'].Strings[LCell]),
            'Notes sounding across the edited key change keep their original pitch');
        end;
      end;
    end;
    Check((LChanged > 0) and (LHeld > 0) and
      (LBefore.Get('stereo_frames', 0) = LAfter.Get('stereo_frames', -1)) and
      (LBefore.Get('stereo_sha256', '') <> LAfter.Get('stereo_sha256', '')) and
      (LBefore.Get('midi_sha256', '') <> LAfter.Get('midi_sha256', '')),
      'Key edit changes audible accompaniment while retaining time and existing sounding notes');
    WriteLn('Selective key edit maps ', LChanged, ' new accompaniment tones; melody, tempo and held notes remain exact');
  finally
    LAfter.Free;
    LBefore.Free;
  end;
end;

procedure DurationTempoEdit(const ABefore, AAfter, ALock: String);
var
  LBefore: TJSONObject;
  LAfter: TJSONObject;
  LColon: Integer;
  LCell: Integer;
  LTempo: Integer;
begin
  LBefore := OutputDocument(ABefore);
  LAfter := nil;
  try
    LAfter := OutputDocument(AAfter);
    LColon := Pos(':', ALock);
    Check(LColon > 1, 'Tempo pin identifies its own provider cell');
    LCell := StrToInt(Copy(ALock, 1, LColon - 1));
    LTempo := StrToInt(Copy(ALock, LColon + 1, MaxInt));
    Check((LAfter.Get('tempo_lock', '') = ALock) and
      LAfter.Get('performance_states_preserved', False) and
      (LAfter.Get('regenerated_tempo_pass', -1) = 1) and
      (TempoContextFromToken(LAfter.Arrays['duration_providers'].Objects[1].
        Arrays['tokens'].Strings[LCell]) = LTempo), 'Selective tempo edit reaches its actual provider token');
    Check((LBefore.Arrays['duration_providers'].Objects[0].AsJSON =
      LAfter.Arrays['duration_providers'].Objects[0].AsJSON) and
      (LBefore.Arrays['duration_providers'].Objects[2].AsJSON =
      LAfter.Arrays['duration_providers'].Objects[2].AsJSON) and
      (LBefore.Arrays['frames'].AsJSON = LAfter.Arrays['frames'].AsJSON) and
      (LBefore.Arrays['performance_spans'].AsJSON = LAfter.Arrays['performance_spans'].AsJSON),
      'Tempo edit preserves key, performance and all logical voice frames');
    Check((LBefore.Get('stereo_sha256', '') <> LAfter.Get('stereo_sha256', '')) and
      (LBefore.Get('midi_sha256', '') <> LAfter.Get('midi_sha256', '')),
      'Selective timed context edit changes actual audio and MIDI');
    WriteLn('Tempo pass edit preserves every key/performance/voice state and changes playback timing');
  finally
    LAfter.Free;
    LBefore.Free;
  end;
end;

procedure CheckChangingOutput(const APath: String);
var
  LDocument: TJSONObject;
  LTokens: TJSONArray;
  LIndex: Integer;
  LChanged: Boolean;
begin
  LDocument := OutputDocument(APath);
  try
    LTokens := LDocument.Arrays['context_passes'].Objects[1].Arrays['tokens'];
    LChanged := False;
    for LIndex := 1 to LTokens.Count - 1 do
    begin
      LChanged := LChanged or (LTokens.Strings[LIndex] <> LTokens.Strings[0]);
    end;
    Check(LChanged, 'Saved source clock must reach generation as changing tempo');
    WriteLn('Actual generated voice clock retains tempo changes');
  finally
    LDocument.Free;
  end;
end;

procedure TimbreVoiceOutput(const AStyleName, AOutput: String);
var
  LStyle: TWaveStyleProfile;
  LDocument: TJSONObject;
  LRow: TJSONObject;
  LRecipe: TWavetableCycleRecipe;
  LFactory: TWavetableSourceFactory;
  LEnvelope: TGateEnvelope;
  LSequence: TNoteSequence;
  LImport: TMidiNoteReport;
  LReport: TNoteRenderReport;
  LVoices: TNoteVoices;
  LClip: TAudioClip;
  LGated: TAudioClip;
  LPlan: TArticulationPlan;
  LBytes: TAudioBytes;
  LIndex: Integer;
  LVoice: Integer;
  LMaximum: Integer;
  LRate: Integer;
  LSubFrame: Integer;
  LActual: TAudioClip;
  LEncodedReplay: TAudioClip;
  LActualHash: String;
  LMaximumError: Double;
  LChannel: Integer;
begin
  DurationVoiceOutput(AStyleName, AOutput);
  LStyle := nil;
  LDocument := nil;
  LFactory := nil;
  LEnvelope := nil;
  LSequence := nil;
  LClip := nil;
  LGated := nil;
  LPlan := nil;
  try
    LStyle := DecodeWaveStyle(ReadFileBytes(AStyleName, MaximumStyleBytes));
    LDocument := OutputDocument(AOutput);
    Check(LStyle.HasTimbre, 'Output checker requires saved measured timbre');
    LRate := LDocument.Get('sample_rate', 0);
    if LStyle.HasEnvelope then
    begin
      LEnvelope := LStyle.CopyGateEnvelope(LRate);
      Check(LDocument.Get('envelope_release_frames', -1) = LEnvelope.ReleaseFrames,
        'Reported envelope tail matches the admitted saved recipe');
    end;
    LRecipe := LStyle.CopyTimbreRecipe;
    LFactory := TWavetableSourceFactory.Create(LRecipe.Sine, LRecipe.Cosine);
    LSequence := DecodeMidiNotes(ReadFileBytes(AOutput + '.mid', 16 * 1024 * 1024),
      DefaultMidiNoteOptions, LImport);
    LMaximum := 0;
    for LIndex := 0 to LSequence.NoteCount - 1 do
    begin
      LMaximum := Max(LMaximum, LSequence.GateAt(LIndex).Voice);
    end;
    Check(LMaximum < MaximumNoteVoices, 'MIDI voice map stays bounded');
    SetLength(LVoices, LMaximum + 1);
    for LIndex := 0 to LMaximum do
    begin
      LVoices[LIndex] := DefaultSynthVoice;
    end;
    for LIndex := 0 to LSequence.NoteCount - 1 do
    begin
      LVoice := LSequence.GateAt(LIndex).Voice;
      Check(LVoice mod 16 < LDocument.Arrays['synthesis_voices'].Count,
        'MIDI channel has a reported synthesis binding');
      LRow := LDocument.Arrays['synthesis_voices'].Objects[LVoice mod 16];
      Check(LRow.Get('saved_timbre', False) and
        (LRow.Get('filter_kind', -1) = Ord(LVoices[LVoice].FilterKind)) and
        (LRow.Get('filter_model', -1) = Ord(LVoices[LVoice].FilterModel)),
        'Measured timbre and supported native filter reach every voice');
      LVoices[LVoice].SourceFactory := LFactory;
      Check(LRow.Get('saved_envelope', False) = LStyle.HasEnvelope,
        'Reported voice envelope binding agrees with saved evidence');
      LVoices[LVoice].GateEnvelope := LEnvelope;
      LVoices[LVoice].Gain := LRow.Get('gain', 0.0);
      LVoices[LVoice].Pan := LRow.Get('pan', 0.0);
      LVoices[LVoice].CutoffHz := LRow.Get('cutoff_hz', 0.0);
      LVoices[LVoice].Envelope.AttackSeconds := LRow.Get('attack_seconds', 0.0);
      LVoices[LVoice].Envelope.DecaySeconds := LRow.Get('decay_seconds', 0.0);
      LVoices[LVoice].Envelope.SustainLevel := LRow.Get('sustain_level', 0.0);
      LVoices[LVoice].Envelope.ReleaseSeconds := LRow.Get('release_seconds', 0.0);
    end;
    LRate := LDocument.Get('sample_rate', 0);
    LClip := RenderNoteSequence(LSequence, LRate, LVoices, LReport);
    LPlan := PlanNoteArticulation(LSequence, LRate, 44, 44, LSubFrame);
    LGated := RenderArticulatedClip(LClip, LPlan);
    LBytes := EncodeWavePcm16(LGated);
    LActual := LoadWaveSource(AOutput, LActualHash);
    LEncodedReplay := nil;
    try
      LEncodedReplay := DecodeWave(LBytes);
      LMaximumError := 0;
      Check((LActual.FrameCount = LEncodedReplay.FrameCount) and
        (LActual.Channels = LEncodedReplay.Channels) and
        (LActualHash = LDocument.Get('stereo_sha256', '')), 'Re-render geometry and published WAV binding');
      for LIndex := 0 to LActual.FrameCount - 1 do
      begin
        for LChannel := 0 to LActual.Channels - 1 do
        begin
          LMaximumError := Max(LMaximumError,
            Abs(LActual.SampleAt(LIndex, LChannel) - LEncodedReplay.SampleAt(LIndex, LChannel)));
        end;
      end;
      { MIDI can reorder simultaneous notes from the projected score. The native
        renderer accumulates each tone into Single samples, so equivalent note
        orders can differ at PCM16 rounding boundaries. }
      Check((LSubFrame = 0) and (LReport.RenderedNotes = LSequence.NoteCount) and
        (LMaximumError <= 1 / 32768),
        'Saved timbre plus exported MIDI independently reproduce complete audio within one PCM16 step');
      WriteLn('Saved timbre voice output: actual models, MIDI and complete re-render pass; maximum PCM difference=', LMaximumError);
    finally
      LEncodedReplay.Free;
      LActual.Free;
    end;
  finally
    LPlan.Free;
    LGated.Free;
    LClip.Free;
    LSequence.Free;
    LFactory.Free;
    LEnvelope.Free;
    LDocument.Free;
    LStyle.Free;
  end;
end;

procedure InstrumentReplay(const ABefore, AAfter: String; const ATolerance: Double);
const
  CSuffixes: array[0..3] of String = ('', '.bass.wav', '.chords.wav', '.melody.wav');
  CNames: array[0..5] of String = ('midi_sha256', 'notes', 'ticks_per_quarter',
    'length_ticks', 'sample_rate', 'frames');
  CPartNames: array[0..7] of String = ('timbre_style_sha256', 'envelope_style_sha256',
    'gain', 'pan', 'cutoff_hz', 'frames', 'channel', 'note_count');
var
  LBefore: TJSONObject;
  LAfter: TJSONObject;
  LFirst: TAudioClip;
  LSecond: TAudioClip;
  LHash: String;
  LName: String;
  LError: Double;
  I: Integer;
  J: Integer;
  K: Integer;
begin
  LBefore := OutputDocument(ABefore);
  LAfter := nil;
  LFirst := nil;
  LSecond := nil;
  try
    LAfter := OutputDocument(AAfter);
    for LName in CNames do
    begin
      Check(LBefore.Find(LName).AsJSON = LAfter.Find(LName).AsJSON,
        'Streaming retains musical ' + LName);
    end;
    for I := 0 to 2 do
    begin
      for LName in CPartNames do
      begin
        Check(LBefore.Arrays['parts'].Objects[I].Find(LName).AsJSON =
          LAfter.Arrays['parts'].Objects[I].Find(LName).AsJSON,
          'Streaming retains instrument ' + LName);
      end;
    end;
    LError := 0;
    for I := 0 to 3 do
    begin
      LFirst := LoadWaveSource(ABefore + CSuffixes[I], LHash);
      LSecond := LoadWaveSource(AAfter + CSuffixes[I], LHash);
      Check((LFirst.FrameCount = LSecond.FrameCount) and
        (LFirst.Channels = 2) and (LSecond.Channels = 2) and
        (LFirst.SampleRate = LSecond.SampleRate), 'Streaming retains complete WAV geometry');
      for J := 0 to LFirst.FrameCount - 1 do
      begin
        for K := 0 to 1 do
        begin
          LError := Max(LError, Abs(LFirst.SampleAt(J, K) - LSecond.SampleAt(J, K)));
          Check(Abs(LSecond.SampleAt(J, K)) < 0.99, 'Compared instrument WAV retains headroom');
        end;
      end;
      FreeAndNil(LSecond);
      FreeAndNil(LFirst);
    end;
    Check(LError <= ATolerance, 'Stream sample error exceeds declared comparison bound');
    WriteLn('Instrument stream replay: complete mix/stems, unchanged notes/bindings; maximum PCM error ',
      LError:0:12);
  finally
    LSecond.Free;
    LFirst.Free;
    LAfter.Free;
    LBefore.Free;
  end;
end;

procedure InstrumentControls(const ABefore, AAfter: String; const ATimbre: Boolean = False);
const
  CParts: array[0..2] of String = ('bass', 'chords', 'melody');
  CFields: array[0..7] of String = ('contract', 'sample_rate', 'midi_sha256',
    'notes_sha256', 'notes', 'ticks_per_quarter', 'length_ticks', 'release_policy');
  CPartFields: array[0..4] of String = ('name', 'channel',
    'gain', 'pan', 'cutoff_hz');
var
  LBefore: TJSONObject;
  LAfter: TJSONObject;
  LBeforeClip: TAudioClip;
  LAfterClip: TAudioClip;
  LBeforeHash: String;
  LAfterHash: String;
  LField: String;
  LBeforePart: TJSONObject;
  LAfterPart: TJSONObject;
  I: Integer;
  J: Integer;
  K: Integer;
  LPeak: Double;
  LPreservedBinding: String;
  LChangedBinding: String;
begin
  LPreservedBinding := 'timbre_style_sha256';
  LChangedBinding := 'envelope_style_sha256';
  if ATimbre then
  begin
    LPreservedBinding := 'envelope_style_sha256';
    LChangedBinding := 'timbre_style_sha256';
  end;
  LBefore := OutputDocument(ABefore);
  LAfter := nil;
  LBeforeClip := nil;
  LAfterClip := nil;
  try
    LAfter := OutputDocument(AAfter);
    for LField in CFields do
    begin
      Check(LBefore.Find(LField).AsJSON = LAfter.Find(LField).AsJSON,
        'Instrument envelope edit preserves ' + LField);
    end;
    LBeforeHash := HashAudioBytes(ReadFileBytes(ABefore + '.mid', 16 * 1024 * 1024));
    LAfterHash := HashAudioBytes(ReadFileBytes(AAfter + '.mid', 16 * 1024 * 1024));
    Check((LBeforeHash = LAfterHash) and (LBeforeHash = LBefore.Get('midi_sha256', '')),
      'Actual MIDI bytes preserve all notes, clocks and metadata');
    for I := 0 to 2 do
    begin
      LBeforePart := LBefore.Arrays['parts'].Objects[I];
      LAfterPart := LAfter.Arrays['parts'].Objects[I];
      Check((LBeforePart.Get('note_count', 0) > 0) and
        (LBeforePart.Get('note_count', 0) = LAfterPart.Get('note_count', 0)),
        'Each compared role contains sounding notes');
      for LField in CPartFields do
      begin
        Check(LBeforePart.Find(LField).AsJSON = LAfterPart.Find(LField).AsJSON,
          'Instrument edit preserves part ' + LField);
      end;
      Check(LBeforePart.Get(LPreservedBinding, '') = LAfterPart.Get(LPreservedBinding, ''),
        'Instrument edit preserves its independent ' + LPreservedBinding);
      LBeforeClip := LoadWaveSource(ABefore + '.' + CParts[I] + '.wav', LBeforeHash);
      LAfterClip := LoadWaveSource(AAfter + '.' + CParts[I] + '.wav', LAfterHash);
      Check((LBeforeHash = LBeforePart.Get('wave_sha256', '')) and
        (LAfterHash = LAfterPart.Get('wave_sha256', '')), 'Part hashes match actual WAV bytes');
      if I < 2 then
      begin
        Check((LBeforeHash = LAfterHash) and
          (LBeforePart.AsJSON = LAfterPart.AsJSON), 'Bass/chord stems and bindings are identical');
      end
      else
      begin
        Check((LBeforeHash <> LAfterHash) and
          (LBeforePart.Get(LChangedBinding, '') <>
            LAfterPart.Get(LChangedBinding, '')), 'Selected melody binding changes its stem');
      end;
      LPeak := 0;
      for J := 0 to LBeforeClip.FrameCount - 1 do
      begin
        for K := 0 to LBeforeClip.Channels - 1 do
        begin
          LPeak := Max(LPeak, Abs(LBeforeClip.SampleAt(J, K)));
        end;
      end;
      Check(LPeak > 0.001, 'Preserved stems must contain audible signal');
      FreeAndNil(LAfterClip);
      FreeAndNil(LBeforeClip);
    end;
    LBeforeHash := HashAudioBytes(ReadFileBytes(ABefore, MaximumWaveBytes));
    LAfterHash := HashAudioBytes(ReadFileBytes(AAfter, MaximumWaveBytes));
    Check((LBeforeHash = LBefore.Get('wave_sha256', '')) and
      (LAfterHash = LAfter.Get('wave_sha256', '')) and (LBeforeHash <> LAfterHash),
      'Independent instrument selection reaches the actual mixed output');
    WriteLn('Instrument ', LChangedBinding,
      ' edit: sounding bass/chord stems, independent binding and MIDI unchanged; melody and mix change');
  finally
    LAfterClip.Free;
    LBeforeClip.Free;
    LAfter.Free;
    LBefore.Free;
  end;
end;

procedure TimbreControls(const ABefore, AAfter: String);
const
  CNames: array[0..4] of String =
    ('duration_providers', 'performance_spans', 'models', 'segments', 'frames');
var
  LBefore: TJSONObject;
  LAfter: TJSONObject;
  LName: String;
begin
  LBefore := OutputDocument(ABefore);
  LAfter := nil;
  try
    LAfter := OutputDocument(AAfter);
    for LName in CNames do
    begin
      Check(LBefore.Find(LName).AsJSON = LAfter.Find(LName).AsJSON,
        'Timbre selection preserves musical ' + LName);
    end;
    Check((LBefore.Get('midi_sha256', '') = LAfter.Get('midi_sha256', '')) and
      (LBefore.Get('preview_sha256', '') = LAfter.Get('preview_sha256', '')) and
      (LBefore.Get('stereo_sha256', '') <> LAfter.Get('stereo_sha256', '')),
      'Only synthesis changes: identical generated MIDI/reference preview and different native timbre audio');
    WriteLn('Timbre controls retain exact context/performance/voice states, MIDI and preview while changing audio');
  finally
    LAfter.Free;
    LBefore.Free;
  end;
end;

procedure DurationVoiceControls(const ABefore, AAfter, ALock: String);
var
  LBefore: TJSONObject;
  LAfter: TJSONObject;
  LColon: Integer;
  LCell: Integer;
  LCumulativeTicks: Integer;
  LBeforeTempo: Integer;
  LAfterTempo: Integer;
begin
  LBefore := OutputDocument(ABefore);
  LAfter := nil;
  try
    LAfter := OutputDocument(AAfter);
    Check(LBefore.Arrays['duration_providers'].Objects[0].AsJSON =
      LAfter.Arrays['duration_providers'].Objects[0].AsJSON, 'Voice edit preserves accepted key provider');
    if ALock <> '' then
    begin
      Check((LBefore.Arrays['duration_providers'].Objects[1].AsJSON =
        LAfter.Arrays['duration_providers'].Objects[1].AsJSON) and
        LAfter.Get('context_states_preserved', False) and
        (LAfter.Get('regenerated_provider_pass', -1) = 2) and
        (LAfter.Get('duration_lock', '') = ALock), 'Selective performance edit preserves base context');
      LColon := Pos(':', ALock);
      Check(LColon > 1, 'Expected duration control has a cell and tick count');
      LCell := StrToInt(Copy(ALock, 1, LColon - 1));
      LCumulativeTicks := StrToInt(Copy(ALock, LColon + 1, MaxInt));
      Check(DecodePitchDurationToken(LAfter.Arrays['duration_providers'].Objects[2].
        Arrays['tokens'].Strings[LCell]).Duration = LCumulativeTicks,
        'Selected performance token satisfies the requested duration');
    end
    else
    begin
      LBeforeTempo := TempoContextFromToken(LBefore.Arrays['duration_providers'].Objects[1].
        Arrays['tokens'].Strings[0]);
      LAfterTempo := TempoContextFromToken(LAfter.Arrays['duration_providers'].Objects[1].
        Arrays['tokens'].Strings[0]);
      Check((LBeforeTempo > 0) and (LAfterTempo > 0) and (LBeforeTempo <> LAfterTempo),
        'Expected independent held tempo selection');
      Check((LBefore.Arrays['duration_providers'].Objects[2].AsJSON =
        LAfter.Arrays['duration_providers'].Objects[2].AsJSON) and
        (LBefore.Arrays['frames'].AsJSON = LAfter.Arrays['frames'].AsJSON) and
        (Abs(Int64(LAfter.Get('stereo_frames', 0)) * LBeforeTempo -
          Int64(LBefore.Get('stereo_frames', 0)) * LAfterTempo) <=
          Int64(LBeforeTempo) + LAfterTempo),
        'Held tempo change preserves performance/voices and applies the selected clock ratio');
    end;
    Check((LBefore.Get('stereo_sha256', '') <> LAfter.Get('stereo_sha256', '')) and
      (LBefore.Get('midi_sha256', '') <> LAfter.Get('midi_sha256', '')),
      'Performance/tempo control changes actual stereo audio and MIDI');
    WriteLn('Duration-driven voice controls preserve independent context and change audio/MIDI');
  finally
    LAfter.Free;
    LBefore.Free;
  end;
end;

procedure EnvelopeControls(const ABeforeStyle, AAfterStyle, ABefore, AAfter: String);
var
  LBefore: TWaveStyleProfile;
  LAfter: TWaveStyleProfile;
  LBeforeRecipe: TWavetableCycleRecipe;
  LAfterRecipe: TWavetableCycleRecipe;
  I: Integer;
begin
  LBefore := nil;
  LAfter := nil;
  try
    LBefore := DecodeWaveStyle(ReadFileBytes(ABeforeStyle, MaximumStyleBytes));
    LAfter := DecodeWaveStyle(ReadFileBytes(AAfterStyle, MaximumStyleBytes));
    Check(LBefore.HasEnvelope and LAfter.HasEnvelope, 'Both envelope variants retain saved evidence');
    LBeforeRecipe := LBefore.CopyTimbreRecipe;
    LAfterRecipe := LAfter.CopyTimbreRecipe;
    Check((Length(LBeforeRecipe.Sine) = Length(LAfterRecipe.Sine)) and
      (LBeforeRecipe.Mean = LAfterRecipe.Mean), 'Envelope edit preserves timbre extent and DC');
    for I := 0 to High(LBeforeRecipe.Sine) do
    begin
      Check((LBeforeRecipe.Sine[I] = LAfterRecipe.Sine[I]) and
        (LBeforeRecipe.Cosine[I] = LAfterRecipe.Cosine[I]),
        'Envelope edit preserves every stationary timbre coefficient');
    end;
    TimbreControls(ABefore, AAfter);
    WriteLn('Envelope-only edit retains exact stationary timbre and musical decisions while changing audio');
  finally
    LAfter.Free;
    LBefore.Free;
  end;
end;

begin
  try
    if (ParamCount = 3) and (ParamStr(1) = 'timbre-voices') then
    begin
      TimbreVoiceOutput(ParamStr(2), ParamStr(3));
    end
    else if (ParamCount = 5) and (ParamStr(1) = 'envelope-controls') then
    begin
      EnvelopeControls(ParamStr(2), ParamStr(3), ParamStr(4), ParamStr(5));
    end
    else if (ParamCount = 3) and (ParamStr(1) = 'instrument-timbre-controls') then
    begin
      InstrumentControls(ParamStr(2), ParamStr(3), True);
    end
    else if (ParamCount = 3) and (ParamStr(1) = 'instrument-controls') then
    begin
      InstrumentControls(ParamStr(2), ParamStr(3));
    end
    else if (ParamCount = 3) and (ParamStr(1) = 'instrument-replay') then
    begin
      InstrumentReplay(ParamStr(2), ParamStr(3), 0);
    end
    else if (ParamCount = 3) and (ParamStr(1) = 'instrument-offline') then
    begin
      InstrumentReplay(ParamStr(2), ParamStr(3), 1 / 32768);
    end
    else if (ParamCount = 3) and (ParamStr(1) = 'timbre-controls') then
    begin
      TimbreControls(ParamStr(2), ParamStr(3));
    end
    else if (ParamCount = 3) and (ParamStr(1) = 'modulation-source') then
    begin
      ModulationSource(ParamStr(2), ParamStr(3));
    end
    else if (ParamCount = 3) and (ParamStr(1) = 'changing-pitch-context') then
    begin
      ChangingPitchContext(ParamStr(2), ParamStr(3));
    end
    else if (ParamCount = 2) and (ParamStr(1) = 'changing-pitch-style') then
    begin
      ChangingPitchStyle(ParamStr(2));
    end
    else if (ParamCount = 3) and (ParamStr(1) = 'duration-key-edit') then
    begin
      DurationKeyEdit(ParamStr(2), ParamStr(3));
    end
    else if (ParamCount = 4) and (ParamStr(1) = 'duration-tempo-edit') then
    begin
      DurationTempoEdit(ParamStr(2), ParamStr(3), ParamStr(4));
    end
    else if (ParamCount = 3) and (ParamStr(1) = 'duration-timed-voices') then
    begin
      DurationVoiceOutput(ParamStr(2), ParamStr(3), True);
    end
    else if (ParamCount = 3) and (ParamStr(1) = 'duration-voices') then
    begin
      DurationVoiceOutput(ParamStr(2), ParamStr(3));
    end
    else if (ParamCount = 4) and (ParamStr(1) = 'duration-voice-controls') then
    begin
      DurationVoiceControls(ParamStr(2), ParamStr(3), ParamStr(4));
    end
    else if (ParamCount = 3) and (ParamStr(1) = 'duration-voice-tempo') then
    begin
      DurationVoiceControls(ParamStr(2), ParamStr(3), '');
    end
    else if (ParamCount = 4) and (ParamStr(1) = 'phase-style') then
    begin
      PhaseArchiveChecks(ParamStr(2), ParamStr(3), ParamStr(4));
    end
    else if (ParamCount = 3) and (ParamStr(1) = 'preferences') then
    begin
      PreferenceFileChecks(ParamStr(2), ParamStr(3));
    end
    else if (ParamCount = 2) and (ParamStr(1) = 'grid-api') then
    begin
      ProviderChoiceChecks;
      GridCapabilityChecks;
      GridApiChecks(ParamStr(2));
    end
    else if (ParamCount in [2, 4]) and (ParamStr(1) = 'performance-api') then
    begin
      PerformanceApiChecks(ParamStr(2), ParamStr(3), ParamStr(4));
    end
    else if (ParamCount = 6) and (ParamStr(1) = 'duration-articulation') then
    begin
      DurationArticulationChecks(ParamStr(2), ParamStr(3), ParamStr(4), ParamStr(5), ParamStr(6));
    end
    else if (ParamCount = 5) and (ParamStr(1) = 'duration-style') then
    begin
      DurationArchiveChecks(ParamStr(2), ParamStr(3), ParamStr(4), ParamStr(5));
    end
    else if (ParamCount = 3) and (ParamStr(1) = 'duration-output') then
    begin
      DurationOutputChecks(ParamStr(2), ParamStr(3));
    end
    else if (ParamCount = 4) and (ParamStr(1) = 'duration-controls') then
    begin
      DurationControls(ParamStr(2), ParamStr(3), False, ParamStr(4));
    end
    else if (ParamCount = 3) and ((ParamStr(1) = 'duration-controls') or
      (ParamStr(1) = 'duration-tempo-controls')) then
    begin
      DurationControls(ParamStr(2), ParamStr(3), ParamStr(1) = 'duration-tempo-controls');
    end
    else if (ParamCount = 6) and (ParamStr(1) = 'dimensions') then
    begin
      DimensionArchiveChecks(ParamStr(2), ParamStr(3), ParamStr(4), ParamStr(5), ParamStr(6));
    end
    else if (ParamCount = 3) and (ParamStr(1) = 'dimension-controls') then
    begin
      DimensionOutputChecks(ParamStr(2), ParamStr(3));
    end
    else if (ParamCount = 5) and (ParamStr(1) = 'pitch-style') then
    begin
      PitchArchiveChecks(ParamStr(2), ParamStr(3), ParamStr(4), ParamStr(5));
    end
    else if (ParamCount = 3) and ((ParamStr(1) = 'output') or
      (ParamStr(1) = 'changing-output')) then
    begin
      CheckOutput(ParamStr(2), ParamStr(3));
      if ParamStr(1) = 'changing-output' then
      begin
        CheckChangingOutput(ParamStr(3));
      end;
    end
    else if (ParamCount = 3) and ((ParamStr(1) = 'controls') or
      (ParamStr(1) = 'intensity-controls') or (ParamStr(1) = 'pitch-controls') or
      (ParamStr(1) = 'coupled-controls') or (ParamStr(1) = 'preference-controls')) then
    begin
      CheckControls(ParamStr(2), ParamStr(3), ParamStr(1) = 'intensity-controls',
        ParamStr(1) = 'pitch-controls', ParamStr(1) = 'coupled-controls',
        ParamStr(1) = 'preference-controls');
    end
    else
    begin
      Check(ParamCount <= 1, 'Usage: pythian.tests.wave.style [OUTPUT_PREFIX]; output STYLE.pys OUTPUT.wav; controls|intensity-controls|pitch-controls|coupled-controls|dimension-controls BEFORE.wav AFTER.wav; pitch-style LEFT.pys RIGHT.pys BLEND.pys REBLEND.pys; dimensions RHYTHM.pys LOW.pys HIGH.pys SELECTED.pys REBLEND.pys; duration-style LEFT.pys RIGHT.pys REBLEND.pys SLOW.pys; duration-output STYLE.pys OUTPUT.wav; duration-controls|duration-tempo-controls BEFORE.wav AFTER.wav');
      Run(ParamStr(1));
      MappedAdmissionChecks;
      PhaseStyleChecks;
      DynamicsChecks;
    end;
  except
    on LException: Exception do
    begin
      WriteLn(StdErr, LException.ClassName, ': ', LException.Message);
      ExitCode := 1;
    end;
  end;
end.
