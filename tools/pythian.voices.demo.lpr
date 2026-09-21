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
program pythian_voices_demo;

{$mode delphi}
{$H+}

uses
  Classes,
  SysUtils,
  fpjson,
  pythian.audio,
  pythian.articulation,
  pythian.pitch.track,
  pythian.time,
  pythian.chord.stream,
  pythian.wave,
  pythian.wave.stream,
  pythian.music,
  pythian.music.context,
  pythian.tonal,
  pythian.onset.dynamics,
  pythian.midi.chord,
  pythian.midi.smf,
  pythian.midi.notes,
  pythian.music.render,
  pythian.synth,
  pythian.envelope,
  pythian.source.wavetable,
  pythian.oscillator,
  pythian.wfc.music,
  pythian.wfc.context,
  pythian.wfc.context.profile,
  pythian.wfc.style,
  pythian.wfc.performance,
  pythian.wfc.grid,
  pythian.pitch,
  pythian.wfc.pitch,
  pythian.wfc.layers,
  pythian.tools.files,
  wfc,
  wfc_model,
  wfc_sequence,
  wfc_sequence_graph,
  wfc_sequence_text,
  wfc_sequence_analyze,
  wfc_training,
  wfc_training_text,
  wfc_music,
  wfc_music_midi,
  wfc_music_text,
  wfc_music_sequence,
  wfc_music_ensemble,
  wfc_music_ensemble_training,
  wfc_music_ensemble_graph,
  wfc_music_ensemble_audio,
  wfc_music_audio,
  wfc_music_voices_training,
  wfc_music_voices_graph,
  wfc_music_voices_stream,
  wfc_music_arrangement;

const
  CRate = 44100;
  CPpq = 480;
  CQuantum = 240;
  CCells = 64;
  CTempoChangeCell = 35;
  CTempoBefore = 500001;
  CTempoAfter = 600001;
  CVoiceNames: array[0..2] of String = ('bass', 'chords', 'melody');

type
  TVoiceCellLengths = array of Integer;

procedure Require(const ACondition: Boolean; const AMessage: String);
begin
  if not ACondition then
  begin
    raise EAudio.Create(AMessage);
  end;
end;

function ResolveContext(const AProfileName: String; const ASeed: TGraphSeed;
  const ADocument: TJSONObject; const AUseStyle, ACouplePitch: Boolean;
  const ARhythmLocks, AIntensityLocks, APitchLock, AStyleExtent: String;
  out ARhythm, AIntensity: String; out APitches: TPitchNotes): TMusicContextGrid;
var
  LProfile: TContextProfile;
  LContext: TMusicContext;
  LLayers: TLearnedLayers;
  LGenerated: TLayerSequences;
  LOptions: TLayerGenerationOptions;
  LReport: TGraphNegotiationReport;
  LGrid: TMusicContextGrid;
  LRows: TJSONArray;
  LRow: TJSONObject;
  LTokens: TJSONArray;
  LStates: TJSONArray;
  LLayer: Integer;
  LCell: Integer;
  LStyle: TWaveStyleProfile;
  LPinCount: Integer;
  LSession: TLearnedLayerSession;
  LRhythmConstraints: TWfcSequenceTokenConstraints;
  LBefore: TLayerSequences;
  LSelective: TGraphSelectiveNegotiationReport;
  LEdit: TJSONObject;
  LIndices: TJSONArray;
  LBaselineRhythm: String;
  LHasDynamics: Boolean;
  LIntensityConstraints: TWfcSequenceTokenConstraints;
  LRoots: TLayerNames;
  LPreservedLayers: Integer;
  LBaselineIntensity: String;
  LPitchLayer: Integer;
  LOnsetLayer: Integer;
  LIntensityLayer: Integer;
  LPitchConstraints: TWfcSequenceTokenConstraints;
  LPitchCell: Integer;
  LPitchNote: Integer;
  LSeparator: Integer;
  LPitchRows: TJSONArray;
  LDefinition: TStyleGrid;
  LGridOptions: TStyleGridOptions;
  LCaptured: TStyleGridResult;
  LRhythmValues: TGridValueLocks;
  LIntensityValues: TGridValueLocks;
  LPitchValues: TGridValueLocks;
  LPreferences: TLayerTokenPreferences;
  LScopeAnalysis: TWfcSequenceDomainAnalysis;
  LPreferenceRows: TJSONArray;
  LPreferenceRow: TJSONObject;
  LPreference: TLayerTokenPreference;
begin
  ARhythm := '';
  AIntensity := '';
  APitches := nil;
  LPitchLayer := -1;
  LPitchCell := -1;
  LPitchNote := -1;
  LOnsetLayer := 2;
  LIntensityLayer := 3;
  LHasDynamics := False;
  LGrid := Default(TMusicContextGrid);
  LGrid.TicksPerQuarter := CPpq;
  LGrid.StepTicks := CQuantum;
  if AProfileName = '' then
  begin
    SetLength(LGrid.Keys, CCells);
    SetLength(LGrid.Tempos, CCells);
    for LCell := 0 to CCells - 1 do
    begin
      LGrid.Keys[LCell] := MakeKeyContext(0, dmMajor);
      LGrid.Tempos[LCell] := CTempoBefore;
      if LCell >= CTempoChangeCell then
      begin
        LGrid.Tempos[LCell] := CTempoAfter;
      end;
    end;
    Exit(LGrid);
  end;
  LProfile := nil;
  LStyle := nil;
  LContext := nil;
  LDefinition := nil;
  SetLength(LLayers, 2);
  try
    if AUseStyle then
    begin
      LStyle := DecodeWaveStyle(ReadFileBytes(AProfileName, MaximumStyleBytes));
      LGridOptions := DefaultStyleGridOptions;
      LGridOptions.CellCount := CCells;
      LGridOptions.Seed := ASeed;
      LGridOptions.CouplePitch := ACouplePitch;
      LGridOptions.Extent := wseWhole;
      if LStyle.HasPitch then
      begin
        LGridOptions.Extent := wseFragment;
      end;
      if AStyleExtent = 'prefix' then
      begin
        LGridOptions.Extent := wsePrefix;
      end
      else if AStyleExtent = 'fragment' then
      begin
        LGridOptions.Extent := wseFragment;
      end
      else if AStyleExtent = 'whole' then
      begin
        LGridOptions.Extent := wseWhole;
      end;
      LDefinition := TStyleGrid.Create(LStyle, LGridOptions);
      LProfile := LStyle.CopyContext;
      LOnsetLayer := LDefinition.ProviderIndex(gpOnsets);
      LIntensityLayer := LDefinition.ProviderIndex(gpIntensity);
      LPitchLayer := LDefinition.ProviderIndex(gpPitch);
      LHasDynamics := LIntensityLayer >= 0;
      if LHasDynamics then
      begin
        ADocument.Add('dynamics_policy', 'Measured forward-window RMS relative to each source admitted-onset maximum; joint onset/intensity history; authored velocity scaled by intensity band / 4');
      end;
      if LPitchLayer >= 0 then
      begin
        ADocument.Add('pitch_policy', 'Saved measured absolute-pitch model supplies melody; independent histories by default, observed coupling when requested; authored bass/chords, rhythm gates and timbre; no pitch transposition or voice separation');
      end;
      if ACouplePitch then
      begin
        ADocument.Add('coupled_pitch', True);
        ADocument.Add('pitch_rhythm_policy', 'Observed pitch/onset/intensity runs provide all three consumer passes; edits regenerate their shared provider and consumers; unknown pitch gaps are never joined');
      end;
      if APitchLock <> '' then
      begin
        Require(LPitchLayer >= 0, 'Pitch lock requires a measured pitch style');
        LSeparator := Pos(':', APitchLock);
        Require(LSeparator > 1, 'Pitch lock must be CELL:NOTE with zero-based cell');
        LPitchCell := StrToInt(Copy(APitchLock, 1, LSeparator - 1));
        LPitchNote := StrToInt(Copy(APitchLock, LSeparator + 1, MaxInt));
        Require((LPitchCell >= 0) and (LPitchCell < CCells), 'Pitch lock cell outside 0..63');
        SetLength(LPitchValues, 1);
        LPitchValues[0] := MakeGridValueLock(LPitchCell, LPitchNote);
        LPitchConstraints := LDefinition.ValueConstraints(gpPitch, LPitchValues);
        ADocument.Add('pitch_lock', APitchLock);
      end;
      ADocument.Add('wave_style_sha256', LStyle.Identity);
      ADocument.Add('rhythm_locks', ARhythmLocks);
      if LPitchLayer >= 0 then
      begin
        ADocument.Add('rhythm_realization_policy', 'Generated onset cells trigger measured-pitch melody and authored accompaniment for one cell; other cells are arranged rests, not inferred source silence');
      end
      else
      begin
        ADocument.Add('rhythm_realization_policy', 'Generated onset cells trigger all authored voices for one cell; other cells are arranged rests, not inferred source silence');
      end;
      FreeAndNil(LStyle);
      Require((ARhythmLocks = '') or (Length(ARhythmLocks) = CCells),
        'Rhythm locks must contain exactly 64 x, dot or question-mark cells');
      SetLength(LRhythmValues, Length(ARhythmLocks));
      LPinCount := 0;
      for LCell := 1 to Length(ARhythmLocks) do
      begin
        Require(ARhythmLocks[LCell] in ['x', '.', '?'], 'Unknown rhythm lock character');
        if ARhythmLocks[LCell] = '?' then
        begin
          Continue;
        end;
        if ARhythmLocks[LCell] = 'x' then
        begin
          LRhythmValues[LPinCount] := MakeGridValueLock(LCell - 1, 1);
        end
        else
        begin
          LRhythmValues[LPinCount] := MakeGridValueLock(LCell - 1, 0);
        end;
        Inc(LPinCount);
      end;
      SetLength(LRhythmValues, LPinCount);
      LRhythmConstraints := LDefinition.ValueConstraints(gpOnsets, LRhythmValues);
      Require((AIntensityLocks = '') or LHasDynamics, 'Intensity locks require measured dynamics');
      Require((AIntensityLocks = '') or (Length(AIntensityLocks) = CCells),
        'Intensity locks must contain exactly 64 digits 0..4 or question marks');
      if LHasDynamics then
      begin
        ADocument.Add('intensity_locks', AIntensityLocks);
      end;
      SetLength(LIntensityValues, Length(AIntensityLocks));
      LPinCount := 0;
      for LCell := 1 to Length(AIntensityLocks) do
      begin
        Require(AIntensityLocks[LCell] in ['0'..'4', '?'], 'Unknown intensity lock character');
        if AIntensityLocks[LCell] = '?' then
        begin
          Continue;
        end;
        LIntensityValues[LPinCount] := MakeGridValueLock(LCell - 1,
          Ord(AIntensityLocks[LCell]) - Ord('0'));
        Inc(LPinCount);
      end;
      SetLength(LIntensityValues, LPinCount);
      if LHasDynamics then
      begin
        LIntensityConstraints := LDefinition.ValueConstraints(gpIntensity, LIntensityValues);
      end;
    end
    else
    begin
      LProfile := DecodeContextProfile(ReadFileBytes(AProfileName, MaximumContextProfileBytes));
    end;
    Require((LProfile.TicksPerQuarter = CPpq) and (LProfile.StepTicks = CQuantum),
      'Voice context requires PPQ 480 and step 240; no implicit normalization');
    ADocument.Add('context_profile_sha256', LProfile.Identity);
    if AUseStyle then
    begin
      if LPitchLayer >= 0 then
      begin
        ADocument.Add('context_policy', 'Actual saved key/tempo/onset, optional intensity and measured pitch passes; rebuild dependent voice stack with measured absolute melody and authored accompaniment');
      end
      else if LHasDynamics then
      begin
        ADocument.Add('context_policy', 'Four actual key/tempo/onset/joint-intensity passes, then rebuild authored diatonic voices under measured timing and intensity; no WAV voice extraction');
      end
      else
      begin
        ADocument.Add('context_policy', 'Three actual key/tempo/onset passes, then rebuild authored diatonic voices under generated onset timing; no WAV voice extraction');
      end;
    end
    else
    begin
      ADocument.Add('context_policy', 'Two actual provider passes, then rebuild authored diatonic voice training; no WAV voice extraction');
    end;
    ADocument.Add('context_key_provider_sha256', LProfile.ProviderIdentity(cdKey));
    ADocument.Add('context_tempo_provider_sha256', LProfile.ProviderIdentity(cdTempo));
    if not AUseStyle then
    begin
      LLayers[0].Model := LProfile.CopyModel(cdKey);
      LLayers[1].Model := LProfile.CopyModel(cdTempo);
    end;
    FreeAndNil(LProfile);
    LOptions := DefaultLayerGenerationOptions;
    LOptions.CellCount := CCells;
    LOptions.Seed := ASeed;
    LOptions.Extent := wseWhole;
    if LPitchLayer >= 0 then
    begin
      LOptions.Extent := wseFragment;
      ADocument.Add('provider_extent', 'fragment; unknown pitch cells separate observed source runs');
    end;
    if AStyleExtent <> '' then
    begin
      if AStyleExtent = 'prefix' then
      begin
        LOptions.Extent := wsePrefix;
      end
      else if AStyleExtent = 'fragment' then
      begin
        LOptions.Extent := wseFragment;
      end
      else
      begin
        LOptions.Extent := wseWhole;
      end;
      if ADocument.Find('provider_extent') <> nil then
      begin
        ADocument.Strings['provider_extent'] := AStyleExtent;
      end
      else
      begin
        ADocument.Add('provider_extent', AStyleExtent);
      end;
    end;
    if AUseStyle then
    begin
      LSession := LDefinition.CreateSession;
      try
        if not LSession.TryGenerate(LGenerated, LReport) then
        begin
          for LLayer := 0 to LDefinition.ProviderCount - 1 do
          begin
            if not LDefinition.AnalyzeProvider(LLayer, nil, LScopeAnalysis) then
            begin
              raise EAudio.CreateFmt('Saved style provider "%s" cannot supply %d cells ' +
                'at the requested extent: %s. Select a supported style scope or use ' +
                'duration generation when the style provides measured durations.',
                [LDefinition.ProviderName(LLayer), CCells, DescribeSequenceAnalyzeIssue(LScopeAnalysis.Issue)]);
            end;
          end;
          if LPitchLayer >= 0 then
          begin
            raise EAudio.Create('Saved style generation failed for the requested cell scope. ' +
              'Inspect the pitch-run summaries and whole/prefix/fragment extent. ' +
              'Inspect the admitted duration scope for dense styles.');
          end;
          raise EAudio.Create('Initial saved style generation failed');
        end;
        if (Length(LRhythmConstraints) > 0) or (Length(LIntensityConstraints) > 0) or
          (Length(LPitchConstraints) > 0) then
        begin
          LBefore := LSession.CopyAccepted;
          SetLength(LRoots, 1);
          LPreservedLayers := 3;
          LRoots[0] := 'intensity';
          if (Length(LRhythmConstraints) = 0) and (Length(LIntensityConstraints) = 0) then
          begin
            LRoots[0] := 'pitch';
            LPreservedLayers := LPitchLayer;
          end;
          if Length(LRhythmConstraints) > 0 then
          begin
            LSession.SetConstraints('onsets', LRhythmConstraints);
            LRoots[0] := 'onsets';
            LPreservedLayers := 2;
          end;
          if Length(LIntensityConstraints) > 0 then
          begin
            LSession.SetConstraints('intensity', LIntensityConstraints);
          end;
          if Length(LPitchConstraints) > 0 then
          begin
            LSession.SetConstraints('pitch', LPitchConstraints);
          end;
          if ACouplePitch then
          begin
            LRoots[0] := 'pitch-rhythm';
            LPreservedLayers := 2;
            LSession.SetConstraints('pitch-rhythm',
              LDefinition.CoupledConstraints(LRhythmValues, LIntensityValues, LPitchValues));
          end;
          if not LSession.TryRegenerate(LRoots, ASeed, LGenerated, LSelective) then
          begin
            raise EAudio.CreateFmt('Selective style regeneration failed with negotiation status %d',
              [Ord(LSelective.Search.Status)]);
          end;
          for LLayer := 0 to LPreservedLayers - 1 do
          begin
            for LCell := 0 to CCells - 1 do
            begin
              Require((LBefore[LLayer].Tokens[LCell] = LGenerated[LLayer].Tokens[LCell]) and
                (LBefore[LLayer].StateIndices[LCell] = LGenerated[LLayer].StateIndices[LCell]),
                'Selective onset regeneration changed an independent accepted context');
            end;
          end;
          LEdit := TJSONObject.Create;
          ADocument.Add('selective_regeneration', LEdit);
          if LPitchLayer >= 0 then
          begin
            LEdit.Add('policy', 'Actual WFC selective regeneration of edited providers; independent accepted passes retained; dependent voice stack rebuilt with measured melody');
          end
          else if LHasDynamics then
          begin
            LEdit.Add('policy', 'Actual WFC selective regeneration of edited onset/intensity root and dependents; independent accepted passes retained; authored voice stack rebuilt');
          end
          else
          begin
            LEdit.Add('policy', 'Actual WFC selective regeneration of onsets; accepted key/tempo retained; dependent authored voice stack rebuilt');
          end;
          LEdit.Add('independent_context_states_preserved', True);
          if LHasDynamics then
          begin
            LEdit.Add('onset_states_preserved', LPreservedLayers >= 3);
          end;
          LEdit.Add('status_ordinal', Ord(LSelective.Search.Status));
          LIndices := TJSONArray.Create;
          LEdit.Add('active_pass_indices', LIndices);
          for LLayer := 0 to High(LSelective.ActivePassIndices) do
          begin
            LIndices.Add(LSelective.ActivePassIndices[LLayer]);
          end;
          LIndices := TJSONArray.Create;
          LEdit.Add('requested_root_indices', LIndices);
          for LLayer := 0 to High(LSelective.RequestedRootIndices) do
          begin
            LIndices.Add(LSelective.RequestedRootIndices[LLayer]);
          end;
          LBaselineRhythm := StringOfChar('.', CCells);
          for LCell := 0 to CCells - 1 do
          begin
            if LBefore[LOnsetLayer].Tokens[LCell] = RhythmOnsetToken then
            begin
              LBaselineRhythm[LCell + 1] := 'x';
            end;
          end;
          LEdit.Add('baseline_onset_pattern', LBaselineRhythm);
          if LPitchLayer >= 0 then
          begin
            LPitchRows := TJSONArray.Create;
            LEdit.Add('baseline_pitch_notes', LPitchRows);
            for LCell := 0 to CCells - 1 do
            begin
              LPitchRows.Add(DecodePitchNoteToken(LBefore[LPitchLayer].Tokens[LCell]));
            end;
          end;
          if LHasDynamics then
          begin
            LBaselineIntensity := StringOfChar('0', CCells);
            for LCell := 0 to CCells - 1 do
            begin
              LBaselineIntensity[LCell + 1] := Chr(Ord('0') + DecodeStyleIntensityToken(LBefore[LIntensityLayer].Tokens[LCell]));
            end;
            LEdit.Add('baseline_intensity_pattern', LBaselineIntensity);
          end;
        end;
      finally
        LSession.Free;
      end;
    end
    else if not TryGenerateLayers(LLayers, nil, LOptions, LGenerated, LReport) then
    begin
      raise EAudio.CreateFmt('Bounded context generation failed with negotiation status %d',
        [Ord(LReport.Status)]);
    end;
    if AUseStyle then
    begin
      LCaptured := LDefinition.Capture(LGenerated);
      LGrid := LCaptured.Context;
    end
    else
    begin
      LContext := MusicContextFromTokens(LGenerated[0].Tokens, LGenerated[1].Tokens,
        CPpq, CQuantum);
      LGrid := LContext.Grid(0, CQuantum, CCells);
    end;
    Require(LGrid.Keys[0].Root >= 0,
      'Authored voice realization requires a known key; select a known key provider');
    for LCell := 1 to CCells - 1 do
    begin
      Require(SameKeyContext(LGrid.Keys[0], LGrid.Keys[LCell]),
        'Authored voice realization requires a constant key; modulation needs a scoped voice policy');
    end;
    ADocument.Add('context_key_root', LGrid.Keys[0].Root);
    ADocument.Add('context_key_mode_ordinal', Ord(LGrid.Keys[0].Mode));
    LRows := TJSONArray.Create;
    ADocument.Add('context_passes', LRows);
    for LLayer := 0 to High(LGenerated) do
    begin
      LRow := TJSONObject.Create;
      LRows.Add(LRow);
      LRow.Add('dimension', LLayer);
      if ACouplePitch then
      begin
        LRow.Add('name', LDefinition.ProviderName(LLayer));
      end;
      if AUseStyle then
      begin
        LRow.Add('model', LDefinition.ModelText(LLayer));
        LPreferences := LDefinition.CopyPreferences(LLayer);
      end
      else
      begin
        LRow.Add('model', EncodeWfcSequenceText(LLayers[LLayer].Model));
        LPreferences := nil;
      end;
      LPreferenceRows := TJSONArray.Create;
      LRow.Add('generation_preferences', LPreferenceRows);
      for LPreference in LPreferences do
      begin
        LPreferenceRow := TJSONObject.Create;
        LPreferenceRows.Add(LPreferenceRow);
        LPreferenceRow.Add('token', LPreference.Token);
        LPreferenceRow.Add('multiplier', LPreference.Multiplier);
      end;
      LTokens := TJSONArray.Create;
      LStates := TJSONArray.Create;
      LRow.Add('tokens', LTokens);
      LRow.Add('states', LStates);
      for LCell := 0 to CCells - 1 do
      begin
        LTokens.Add(LGenerated[LLayer].Tokens[LCell]);
        LStates.Add(LGenerated[LLayer].StateIndices[LCell]);
      end;
    end;
    if AUseStyle then
    begin
      if LPitchLayer >= 0 then
      begin
        APitches := LCaptured.Pitches;
        LPitchRows := TJSONArray.Create;
        ADocument.Add('generated_pitch_notes', LPitchRows);
        for LCell := 0 to CCells - 1 do
        begin
          LPitchRows.Add(APitches[LCell]);
        end;
      end;
      ARhythm := StringOfChar('.', CCells);
      for LCell := 0 to CCells - 1 do
      begin
        if LCaptured.Onsets[LCell] then
        begin
          ARhythm[LCell + 1] := 'x';
        end;
      end;
      Require(Pos('x', ARhythm) > 0, 'Generated onset pattern has no attacks for this voice consumer');
      ADocument.Add('generated_onset_pattern', ARhythm);
      if LHasDynamics then
      begin
        AIntensity := StringOfChar('0', CCells);
        for LCell := 0 to CCells - 1 do
        begin
          AIntensity[LCell + 1] := Chr(Ord('0') + LCaptured.Intensities[LCell]);
        end;
        ADocument.Add('generated_intensity_pattern', AIntensity);
      end;
    end;
    Result := LGrid;
  finally
    for LLayer := 0 to High(LLayers) do
    begin
      LLayers[LLayer].Model.Free;
    end;
    LDefinition.Free;
    LContext.Free;
    LProfile.Free;
    LStyle.Free;
  end;
end;

{ The authored source uses C-major diatonic pitches. Preserve its scale degrees
  and octave/register, lowering degrees 3/6/7 for natural minor, then add root.
  This is an explicit symbolic arrangement policy, not a learned WAV voice. }
function ResolveDurationStyle(const APath: String; const ASeed: TGraphSeed;
  const ACount, ATempoCells, AKeyCells: Integer; const ADurationLock, APitchLock, ATempoLock, AKeyLock: String;
  const ADocument: TJSONObject; out ARhythm: String; out APitches: TPitchNotes;
  out ALengths: TVoiceCellLengths; out APlaybackClock: TTempoMap): TMusicContextGrid;
var
  LStyle: TWaveStyleProfile;
  LPerformance: TStylePerformance;
  LPlan: TStylePerformancePlan;
  LSpans: TTimedPitchSpans;
  LOptions: TStylePerformanceOptions;
  LSession: TLearnedLayerSession;
  LGenerated: TLayerSequences;
  LBefore: TLayerSequences;
  LReport: TGraphNegotiationReport;
  LSelective: TGraphSelectiveNegotiationReport;
  LDurations: TPerformanceValueLocks;
  LPitchLocks: TPerformanceValueLocks;
  LIndex: Integer;
  LLayer: Integer;
  LPosition: Integer;
  LSeparator: Integer;
  LTempoCell: Integer;
  LCumulativeTicks: Integer;
  LTick: Integer;
  LKey: TKeyContext;
  LKeyCell: Integer;
  LKeyText: String;
  LKeyMode: TDiatonicMode;
  LTempo: Integer;
  LRows: TJSONArray;
  LRow: TJSONObject;
  LTokens: TJSONArray;
  LStates: TJSONArray;
  LAnalysis: TWfcSequenceDomainAnalysis;
  LProvider: TPerformanceProvider;
  LProviderName: String;

  function ParseLock(const AText: String): TPerformanceValueLocks;
  var
    LSeparator: Integer;
  begin
    Result := nil;
    if AText = '' then
    begin
      Exit;
    end;
    LSeparator := Pos(':', AText);
    Require(LSeparator > 1, 'Performance lock requires CELL:VALUE');
    SetLength(Result, 1);
    Result[0] := MakePerformanceValueLock(StrToInt(Copy(AText, 1, LSeparator - 1)),
      StrToInt(Copy(AText, LSeparator + 1, MaxInt)));
  end;

begin
  Require((ACount >= 1) and (ACount <= CCells), 'Duration spans must be 1..64');
  APlaybackClock := nil;
  LStyle := nil;
  LPerformance := nil;
  LPlan := nil;
  LSession := nil;
  try
    LStyle := DecodeWaveStyle(ReadFileBytes(APath, MaximumStyleBytes));
    LOptions := DefaultStylePerformanceOptions;
    LOptions.Seed := ASeed;
    LOptions.SpanCount := ACount;
    LOptions.KeyCells := AKeyCells;
    LOptions.TempoCells := ATempoCells;
    LPerformance := TStylePerformance.Create(LStyle, LOptions);
    Require(LPerformance.TicksPerQuarter = CPpq, 'Duration voices require the explicit 480 PPQ timebase');
    LSession := LPerformance.CreateSession;
    if not LSession.TryGenerate(LGenerated, LReport) then
    begin
      if LReport.Status = gnsContradiction then
      begin
        for LProvider := Low(TPerformanceProvider) to High(TPerformanceProvider) do
        begin
          if not LPerformance.AnalyzeProvider(LProvider, nil, LAnalysis) then
          begin
            case LProvider of
              ppKey:
                begin
                  LProviderName := 'key';
                end;
              ppTempo:
                begin
                  LProviderName := 'tempo';
                end;
              ppPerformance:
                begin
                  LProviderName := 'performance';
                end;
            end;
            raise EAudio.Create('Saved ' + LProviderName + ' prefix is structurally infeasible: ' +
              DescribeSequenceAnalyzeIssue(LAnalysis.Issue));
          end;
        end;
      end;
      if LReport.Status = gnsSolverBacktrackLimit then
      begin
        raise EAudio.Create('Saved performance search reached its solver backtrack limit');
      end;
      if LReport.Status = gnsPassBacktrackLimit then
      begin
        raise EAudio.Create('Saved performance search reached its pass backtrack limit');
      end;
      raise EAudio.Create('Saved performance passes contradict the requested scope');
    end;
    if (ADurationLock <> '') or (APitchLock <> '') then
    begin
      LDurations := ParseLock(ADurationLock);
      LPitchLocks := ParseLock(APitchLock);
      LBefore := LSession.CopyAccepted;
      LSession.SetConstraints('performance', LPerformance.PerformanceConstraints(LDurations, LPitchLocks));
      Require(LSession.TryRegenerate(['performance'], ASeed, LGenerated, LSelective),
        'Duration provider edit cannot satisfy the saved model');
      for LLayer := 0 to 1 do
      begin
        for LPosition := 0 to High(LBefore[LLayer].StateIndices) do
        begin
          Require(LBefore[LLayer].StateIndices[LPosition] = LGenerated[LLayer].StateIndices[LPosition],
            'Performance edit changed accepted base context');
        end;
      end;
      ADocument.Add('duration_lock', ADurationLock);
      ADocument.Add('pitch_lock', APitchLock);
      ADocument.Add('context_states_preserved', True);
      ADocument.Add('regenerated_provider_pass', LSelective.ActivePassIndices[0]);
    end;
    if ATempoLock <> '' then
    begin
      LSeparator := Pos(':', ATempoLock);
      Require(LSeparator > 1, 'Tempo lock requires CELL:MICROSECONDS_PER_QUARTER');
      LTempoCell := StrToInt(Copy(ATempoLock, 1, LSeparator - 1));
      Require((LTempoCell >= 0) and (LTempoCell < ATempoCells), 'Tempo lock outside provider scope');
      LTempo := StrToInt(Copy(ATempoLock, LSeparator + 1, MaxInt));
      LBefore := LSession.CopyAccepted;
      LSession.SetConstraints('tempo', LPerformance.TempoConstraints(
        [MakePerformanceValueLock(LTempoCell, LTempo)]));
      Require(LSession.TryRegenerate(['tempo'], ASeed, LGenerated, LSelective),
        'Tempo edit cannot satisfy the saved provider model');
      for LLayer := 0 to 2 do
      begin
        if LLayer = 1 then
        begin
          Continue;
        end;
        for LPosition := 0 to High(LBefore[LLayer].StateIndices) do
        begin
          Require(LBefore[LLayer].StateIndices[LPosition] = LGenerated[LLayer].StateIndices[LPosition],
            'Tempo edit changed accepted key or performance');
        end;
      end;
      ADocument.Add('tempo_lock', ATempoLock);
      ADocument.Add('performance_states_preserved', True);
      ADocument.Add('regenerated_tempo_pass', LSelective.ActivePassIndices[0]);
    end;
    if AKeyLock <> '' then
    begin
      LSeparator := Pos(':', AKeyLock);
      Require(LSeparator > 1, 'Key lock requires CELL:ROOT:major|minor');
      LKeyCell := StrToInt(Copy(AKeyLock, 1, LSeparator - 1));
      Require((LKeyCell >= 0) and (LKeyCell < AKeyCells), 'Key lock outside provider scope');
      LKeyText := Copy(AKeyLock, LSeparator + 1, MaxInt);
      LSeparator := Pos(':', LKeyText);
      Require(LSeparator > 1, 'Key lock requires ROOT:major|minor');
      LKeyMode := dmMajor;
      if Copy(LKeyText, LSeparator + 1, MaxInt) = 'minor' then
      begin
        LKeyMode := dmNaturalMinor;
      end
      else
      begin
        Require(Copy(LKeyText, LSeparator + 1, MaxInt) = 'major', 'Key mode must be major or minor');
      end;
      LKey := MakeKeyContext(StrToInt(Copy(LKeyText, 1, LSeparator - 1)), LKeyMode);
      LBefore := LSession.CopyAccepted;
      LSession.SetConstraints('key', LPerformance.KeyConstraints([MakePerformanceKeyLock(LKeyCell, LKey)]));
      Require(LSession.TryRegenerate(['key'], ASeed, LGenerated, LSelective),
        'Key edit cannot satisfy the saved provider model');
      for LLayer := 1 to 2 do
      begin
        for LPosition := 0 to High(LBefore[LLayer].StateIndices) do
        begin
          Require(LBefore[LLayer].StateIndices[LPosition] = LGenerated[LLayer].StateIndices[LPosition],
            'Key edit changed accepted tempo or performance');
        end;
      end;
      ADocument.Add('key_lock', AKeyLock);
      ADocument.Add('key_edit_independent_states_preserved', True);
      ADocument.Add('regenerated_key_pass', LSelective.ActivePassIndices[0]);
    end;
    LPlan := LPerformance.Capture(LGenerated);
    LSpans := LPlan.CopySpans;
    APlaybackClock := LPlan.CopyClock;
    ADocument.Add('duration_key_cells', AKeyCells);
    ADocument.Add('duration_key_step_ticks', LPerformance.StepTicks);
    ADocument.Add('wave_style_sha256', LPerformance.StyleIdentity);
    ADocument.Add('duration_tempo_cells', ATempoCells);
    ADocument.Add('duration_tempo_step_ticks', LPerformance.StepTicks);
    ADocument.Add('context_policy', 'Key and tempo have independent finite provider scopes; a zero scope explicitly holds a single-valued model; performance retains its own span count');
    LRows := TJSONArray.Create;
    ADocument.Add('duration_providers', LRows);
    for LLayer := 0 to 2 do
    begin
      LRow := TJSONObject.Create;
      LRows.Add(LRow);
      LRow.Add('model_sha256', HashText(LPerformance.ModelText(TPerformanceProvider(LLayer))));
      LTokens := TJSONArray.Create;
      LStates := TJSONArray.Create;
      LRow.Add('tokens', LTokens);
      LRow.Add('states', LStates);
      for LIndex := 0 to High(LGenerated[LLayer].Tokens) do
      begin
        LTokens.Add(String(LGenerated[LLayer].Tokens[LIndex]));
        LStates.Add(LGenerated[LLayer].StateIndices[LIndex]);
      end;
    end;
    Result := Default(TMusicContextGrid);
    Result.TicksPerQuarter := CPpq;
    Result.StepTicks := CQuantum; { Logical voice-model lattice, not realized duration. }
    SetLength(Result.Keys, ACount);
    SetLength(Result.Tempos, ACount);
    SetLength(APitches, ACount);
    SetLength(ALengths, ACount);
    ARhythm := StringOfChar('.', ACount);
    LTick := 0;
    LRows := TJSONArray.Create;
    ADocument.Add('performance_spans', LRows);
    for LIndex := 0 to ACount - 1 do
    begin
      LTick := LSpans[LIndex].StartTick;
      ALengths[LIndex] := LSpans[LIndex].EndTick - LTick;
      LTempo := TempoContextFromToken(LGenerated[1].Tokens[0]);
      if ATempoCells > 0 then
      begin
        LPosition := LTick div LPerformance.StepTicks;
        LTempo := TempoContextFromToken(LGenerated[1].Tokens[LPosition]);
      end;
      Result.Tempos[LIndex] := LTempo;
      APitches[LIndex] := LSpans[LIndex].Note;
      if LSpans[LIndex].Kind = pskPitch then
      begin
        ARhythm[LIndex + 1] := 'x';
      end;
      LRow := TJSONObject.Create;
      LRows.Add(LRow);
      LRow.Add('token', String(LGenerated[2].Tokens[LIndex]));
      LRow.Add('start_tick', LTick);
      LRow.Add('end_tick', LSpans[LIndex].EndTick);
      LRow.Add('kind_ordinal', Ord(LSpans[LIndex].Kind));
      LRow.Add('note', LSpans[LIndex].Note);
    end;
    Require(Pos('x', ARhythm) > 0, 'No pitched performance spans for accompaniment');
    LCumulativeTicks := 0;
    for LIndex := 0 to ACount - 1 do
    begin
      Result.Keys[LIndex] := LPlan.KeyAtTick(LCumulativeTicks);
      Require(Result.Keys[LIndex].Root >= 0, 'Authored accompaniment requires known key at each performance span');
      LRow := ADocument.Arrays['performance_spans'].Objects[LIndex];
      LRow.Add('key_root', Result.Keys[LIndex].Root);
      LRow.Add('key_mode_ordinal', Ord(Result.Keys[LIndex].Mode));
      Inc(LCumulativeTicks, ALengths[LIndex]);
    end;
    LKey := Result.Keys[0];
    ADocument.Add('key_policy', 'Key at each new performance attack maps authored bass/chord scale degrees; sounding notes retain pitch until their original gate ends; measured melody retains absolute MIDI pitch');
    ADocument.Add('context_key_root', LKey.Root);
    ADocument.Add('context_key_mode_ordinal', Ord(LKey.Mode));
    ADocument.Add('duration_ticks_per_quarter', LStyle.DurationTicksPerQuarter);
    ADocument.Add('duration_policy', 'Measured joint pitch/kind/duration spans guide all voices; unknown/silence spans are arranged rests; bass/chord pitches, intensity and timbre remain authored; cumulative PPQ boundaries drive audio and MIDI');
  finally
    LPlan.Free;
    LSession.Free;
    LPerformance.Free;
    LStyle.Free;
  end;
end;

function ContextPitch(const APitch: Integer; const AKey: TKeyContext): Integer;
begin
  Result := MapDiatonicPitch(APitch, MakeKeyContext(0, dmMajor), AKey);
end;

function TrainingFrame(const ASample, ACell: Integer;
  const AKey: TKeyContext): TWfcMusicEnsembleFrame;
const
  CRoots: array[0..1, 0..3] of Integer = ((60, 65, 67, 60), (60, 57, 65, 67));
  CMelody: array[0..1, 0..3] of Integer = ((0, 1, 2, 1), (2, 1, 0, 2));
var
  LTones: TWfcMusicTones;
  LRoot: Integer;
  LThird: Integer;
  LPitch: Integer;
  LAction: TWfcMusicCellAction;
  LVoice: Integer;
  LTone: Integer;
begin
  Result := Default(TWfcMusicEnsembleFrame);
  LRoot := CRoots[ASample, ACell div 8];
  LThird := 4;
  if LRoot = 57 then
  begin
    LThird := 3;
  end;
  SetLength(Result.Voices, 3);
  SetLength(LTones, 1);
  LPitch := LRoot - 24;
  if (ACell div 2) mod 2 = 1 then
  begin
    Inc(LPitch, 7);
  end;
  LTones[0] := MakeWfcMusicTone(LPitch, 105);
  LAction := wmcaHold;
  if ACell mod 2 = 0 then
  begin
    LAction := wmcaAttack;
  end;
  Result.Voices[0] := MakeWfcMusicVoiceCell(LAction, LTones);
  SetLength(LTones, 3);
  LTones[0] := MakeWfcMusicTone(LRoot, 78);
  LTones[1] := MakeWfcMusicTone(LRoot + LThird, 70);
  LTones[2] := MakeWfcMusicTone(LRoot + 7, 74);
  LAction := wmcaHold;
  if ACell mod 8 = 0 then
  begin
    LAction := wmcaAttack;
  end;
  Result.Voices[1] := MakeWfcMusicVoiceCell(LAction, LTones);
  if ACell mod 8 = 7 then
  begin
    Result.Voices[2] := MakeWfcMusicRestVoiceCell;
  end
  else
  begin
    LPitch := LRoot + 12;
    case CMelody[ASample, (ACell div 2) mod 4] of
      1:
      begin
        Inc(LPitch, LThird);
      end;
      2:
      begin
        Inc(LPitch, 7);
      end;
    end;
    SetLength(LTones, 1);
    LTones[0] := MakeWfcMusicTone(LPitch, 96 - 10 * ASample);
    LAction := wmcaHold;
    if ACell mod 2 = 0 then
    begin
      LAction := wmcaAttack;
    end;
    Result.Voices[2] := MakeWfcMusicVoiceCell(LAction, LTones);
  end;
  for LVoice := 0 to High(Result.Voices) do
  begin
    for LTone := 0 to High(Result.Voices[LVoice].Tones) do
    begin
      Result.Voices[LVoice].Tones[LTone].Pitch :=
        ContextPitch(Result.Voices[LVoice].Tones[LTone].Pitch, AKey);
    end;
  end;
end;

function StyleGuideFrame(const ACell: Integer; const AKey: TKeyContext;
  const APattern, AIntensity: String; const APitches: TPitchNotes): TWfcMusicEnsembleFrame;
var
  LCell: Integer;
  LVoice: Integer;
  LTone: Integer;
begin
  LCell := ACell;
  { Use the prior melody pitch at its authored rest cell when an admitted onset
    requests an attack. Pitches/voicings remain authored arrangement material. }
  if LCell mod 8 = 7 then
  begin
    Dec(LCell);
  end;
  if LCell < 32 then
  begin
    Result := TrainingFrame(1, LCell, AKey);
  end
  else
  begin
    Result := TrainingFrame(0, LCell - 32, AKey);
  end;
  if Length(APitches) > 0 then
  begin
    Result.Voices[2].Tones[0].Pitch := APitches[ACell];
  end;
  for LVoice := 0 to High(Result.Voices) do
  begin
    if APattern[ACell + 1] = 'x' then
    begin
      Result.Voices[LVoice].Action := wmcaAttack;
      if AIntensity <> '' then
      begin
        for LTone := 0 to High(Result.Voices[LVoice].Tones) do
        begin
          Result.Voices[LVoice].Tones[LTone].Velocity := IntensityVelocity(
            Result.Voices[LVoice].Tones[LTone].Velocity,
            Ord(AIntensity[ACell + 1]) - Ord('0'));
        end;
      end;
    end
    else
    begin
      Result.Voices[LVoice] := MakeWfcMusicRestVoiceCell;
    end;
  end;
end;

function ScoreForFrames(const AFrames: TWfcMusicEnsembleFrames;
  const ATempos: TContextTempos): TWfcMusicScore;
var
  LTracks: TWfcMusicTracks;
  LVoices: TWfcMusicVoices;
  LMeters: TWfcMusicMeterChanges;
  LTempos: TWfcMusicTempoChanges;
  LSpans: TWfcMusicSpanEvents;
  LVoice: Integer;
  LCell: Integer;
  LCount: Integer;
  LPadded: TWfcMusicEnsembleFrames;
  LPaddedCount: Integer;
begin
  SetLength(LTracks, 1);
  LTracks[0] := MakeWfcMusicTrack('native-voices', 'Native independent voices');
  SetLength(LVoices, 3);
  for LVoice := 0 to 2 do
  begin
    LVoices[LVoice] := MakeWfcMusicVoice(0, CVoiceNames[LVoice]);
  end;
  SetLength(LMeters, 1);
  LMeters[0] := MakeWfcMusicMeterChange(0, 4, 4);
  Require(Length(ATempos) = Length(AFrames), 'Score tempo cells must match voice frames');
  SetLength(LTempos, Length(ATempos));
  LCount := 0;
  for LCell := 0 to High(ATempos) do
  begin
    if (LCell = 0) or (ATempos[LCell] <> ATempos[LCell - 1]) then
    begin
      LTempos[LCount] := MakeWfcMusicTempoChange(LCell * CQuantum, ATempos[LCell]);
      Inc(LCount);
    end;
  end;
  SetLength(LTempos, LCount);
  LPaddedCount := ((Length(AFrames) + 7) div 8) * 8;
  LPadded := Copy(AFrames);
  SetLength(LPadded, LPaddedCount);
  for LCell := Length(AFrames) to LPaddedCount - 1 do
  begin
    SetLength(LPadded[LCell].Voices, 3);
    for LVoice := 0 to 2 do
    begin
      LPadded[LCell].Voices[LVoice] := MakeWfcMusicRestVoiceCell;
    end;
  end;
  LSpans := RebuildWfcMusicEnsembleSpans(LPadded, CQuantum);
  Result := TWfcMusicScore.Create(CPpq, 12, LPaddedCount * CQuantum,
    LTracks, LVoices, LMeters, LTempos, LSpans);
end;

function LearnModels(const ADocument: TJSONObject;
  const AKeys: TKeyContexts; const ARhythm, AIntensity: String;
  const APitches: TPitchNotes; const ADuration: Boolean): TWfcMusicVoicesGraphConfig;
var
  LFrames: TWfcMusicEnsembleFrames;
  LScore: TWfcMusicScore;
  LBundle: TWfcMusicVoicesTrainingBundle;
  LTraining: TWfcTrainingDocument;
  LRoles: TWfcMusicVoiceTrainingRoles;
  LSelections: TWfcMusicEnsembleTrainingSelections;
  LConfig: TWfcMusicVoicesGraphConfig;
  LModel: TWfcSequenceModel;
  LModelsJson: TJSONArray;
  LRow: TJSONObject;
  LModelText: String;
  LIndex: Integer;
  LCellCount: Integer;
  LTempos: TContextTempos;
  LOrder: Integer;
begin
  LScore := nil;
  LBundle := nil;
  LTraining := nil;
  LModel := nil;
  LConfig := Default(TWfcMusicVoicesGraphConfig);
  SetLength(LConfig.Voices, 3);
  try
    try
      LCellCount := CCells;
      if ARhythm <> '' then
      begin
        LCellCount := Length(ARhythm);
      end;
      Require(Length(AKeys) = LCellCount, 'Voice key contexts must cover every logical cell');
      { A one-span performance has no second observed history position. }
      LOrder := 2;
      if LCellCount = 1 then
      begin
        LOrder := 1;
      end;
      SetLength(LFrames, LCellCount);
      SetLength(LTempos, LCellCount);
      for LIndex := 0 to High(LFrames) do
      begin
        if ARhythm = '' then
        begin
          LFrames[LIndex] := TrainingFrame(LIndex div 32, LIndex mod 32, AKeys[LIndex]);
        end
        else
        begin
          LFrames[LIndex] := StyleGuideFrame(LIndex, AKeys[LIndex], ARhythm, AIntensity, APitches);
        end;
        LTempos[LIndex] := CTempoBefore;
      end;
      LScore := ScoreForFrames(LFrames, LTempos);
      ADocument.Add('training_score', EncodeWfcMusicText(LScore));
      SetLength(LRoles, 3);
      for LIndex := 0 to 2 do
      begin
        LRoles[LIndex].Id := CVoiceNames[LIndex];
        LRoles[LIndex].SourceVoiceIndex := LIndex;
        LRoles[LIndex].Order := LOrder;
      end;
      SetLength(LSelections, 2);
      LSelections[0] := MakeWfcMusicEnsembleTrainingSelection('phrase-a', 0, 32 * CQuantum);
      LSelections[1] := MakeWfcMusicEnsembleTrainingSelection('phrase-b', 32 * CQuantum, 32 * CQuantum);
      if ARhythm <> '' then
      begin
        SetLength(LSelections, 1);
        LSelections[0] := MakeWfcMusicEnsembleTrainingSelection('arranged-wave-rhythm', 0, LCellCount * CQuantum);
      end;
      if ARhythm = '' then
      begin
        LBundle := BuildWfcMusicVoicesTrainingBundle(LScore, LRoles, LSelections, CQuantum, LOrder, LOrder,
          MakeWfcTrainingMetadata('Pythian independent voices', 'MIT', 'Two authored native phrases'));
      end
      else if ADuration then
      begin
        LBundle := BuildWfcMusicVoicesTrainingBundle(LScore, LRoles, LSelections, CQuantum, LOrder, LOrder,
          MakeWfcTrainingMetadata('Pythian independent voices', 'MIT',
          'Saved measured performance controls melody and voice gates; bass/chord pitches and synthesis are authored; logical score padding is excluded from training'));
      end
      else if Length(APitches) > 0 then
      begin
        LBundle := BuildWfcMusicVoicesTrainingBundle(LScore, LRoles, LSelections, CQuantum, LOrder, LOrder,
          MakeWfcTrainingMetadata('Pythian independent voices', 'MIT',
          'Saved WAV pitch model supplies melody; authored accompaniment arranged under measured onset/intensity controls'));
      end
      else
      begin
        LBundle := BuildWfcMusicVoicesTrainingBundle(LScore, LRoles, LSelections, CQuantum, LOrder, LOrder,
          MakeWfcTrainingMetadata('Pythian independent voices', 'MIT',
          'Authored pitches and voicings arranged under saved WAV-derived onset timing'));
      end;
      LModelsJson := TJSONArray.Create;
      ADocument.Add('models', LModelsJson);
      for LIndex := 0 to 4 do
      begin
        case LIndex of
          0:
          begin
            LTraining := LBundle.CopyHarmonyDocument;
          end;
          1:
          begin
            LTraining := LBundle.CopyRhythmDocument;
          end;
        else
          LTraining := LBundle.CopyVoiceDocument(LIndex - 2);
        end;
        LModelText := LearnWfcTrainingModelText(LTraining);
        LModel := DecodeWfcSequenceText(LModelText);
        LRow := TJSONObject.Create;
        LModelsJson.Add(LRow);
        LRow.Add('index', LIndex);
        LRow.Add('name', WfcMusicVoicesPassLabel(LIndex));
        LRow.Add('training_document', EncodeWfcTrainingText(LTraining));
        LRow.Add('model', LModelText);
        LRow.Add('sha256', HashText(LModelText));
        LRow.Add('public_tokens', LModel.PublicTokenCount);
        LRow.Add('states', LModel.StateCount);
        case LIndex of
          0:
          begin
            LConfig.HarmonyModel := LModel;
          end;
          1:
          begin
            LConfig.RhythmModel := LModel;
          end;
        else
          LConfig.Voices[LIndex - 2].Model := LModel;
        end;
        LModel := nil;
        FreeAndNil(LTraining);
      end;
      LConfig.StepsPerOctave := 12;
      LConfig.HarmonyMode := wmehmExact;
      LConfig.Voices[0].MinPitch := ContextPitch(33, AKeys[0]);
      LConfig.Voices[0].MaxPitch := ContextPitch(50, AKeys[0]);
      LConfig.Voices[1].MinPitch := ContextPitch(57, AKeys[0]);
      LConfig.Voices[1].MaxPitch := ContextPitch(74, AKeys[0]);
      LConfig.Voices[2].MinPitch := ContextPitch(69, AKeys[0]);
      LConfig.Voices[2].MaxPitch := ContextPitch(86, AKeys[0]);
      for LIndex := 1 to High(AKeys) do
      begin
        if ContextPitch(33, AKeys[LIndex]) < LConfig.Voices[0].MinPitch then
        begin
          LConfig.Voices[0].MinPitch := ContextPitch(33, AKeys[LIndex]);
        end;
        if ContextPitch(50, AKeys[LIndex]) > LConfig.Voices[0].MaxPitch then
        begin
          LConfig.Voices[0].MaxPitch := ContextPitch(50, AKeys[LIndex]);
        end;
        if ContextPitch(57, AKeys[LIndex]) < LConfig.Voices[1].MinPitch then
        begin
          LConfig.Voices[1].MinPitch := ContextPitch(57, AKeys[LIndex]);
        end;
        if ContextPitch(74, AKeys[LIndex]) > LConfig.Voices[1].MaxPitch then
        begin
          LConfig.Voices[1].MaxPitch := ContextPitch(74, AKeys[LIndex]);
        end;
        if ContextPitch(69, AKeys[LIndex]) < LConfig.Voices[2].MinPitch then
        begin
          LConfig.Voices[2].MinPitch := ContextPitch(69, AKeys[LIndex]);
        end;
        if ContextPitch(86, AKeys[LIndex]) > LConfig.Voices[2].MaxPitch then
        begin
          LConfig.Voices[2].MaxPitch := ContextPitch(86, AKeys[LIndex]);
        end;
      end;
      SetLength(LConfig.PairConstraints, 2);
      LConfig.PairConstraints[0].LowerVoice := 0;
      LConfig.PairConstraints[0].UpperVoice := 1;
      LConfig.PairConstraints[0].MinGap := 7;
      LConfig.PairConstraints[0].MaxGap := 40;
      LConfig.PairConstraints[0].RestPolicy := wmvprSuspend;
      LConfig.PairConstraints[1].LowerVoice := 1;
      LConfig.PairConstraints[1].UpperVoice := 2;
      LConfig.PairConstraints[1].MinGap := 0;
      LConfig.PairConstraints[1].MaxGap := 24;
      LConfig.PairConstraints[1].RestPolicy := wmvprSuspend;
      if Length(APitches) > 0 then
      begin
        LConfig.Voices[2].MinPitch := 0;
        LConfig.Voices[2].MaxPitch := 127;
        SetLength(LConfig.PairConstraints, 1);
        ADocument.Add('melody_register_policy', 'Preserve measured absolute MIDI pitch; allow melody/chord crossing; retain authored bass/chord spacing');
      end;
      ValidateWfcMusicVoicesGraphConfig(LConfig);
      Result := LConfig;
    except
      for LIndex := 0 to High(LConfig.Voices) do
      begin
        LConfig.Voices[LIndex].Model.Free;
      end;
      LConfig.RhythmModel.Free;
      LConfig.HarmonyModel.Free;
      raise;
    end;
  finally
    LModel.Free;
    LTraining.Free;
    LBundle.Free;
    LScore.Free;
  end;
end;

function VoiceGuideTokens(const AModel: TWfcSequenceModel;
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
  LTokens := nil;
  LGuideFrame := Default(TWfcMusicEnsembleFrame);
  SetLength(LGuideFrame.Voices, 1);
  LGuideFrame.Voices[0] := AGuide;
  LGuideClasses := EncodeWfcMusicPitchClassSet(
    ProjectWfcMusicEnsembleFrameToPitchClassSet(LGuideFrame, 12));
  for LIndex := 0 to AModel.PublicTokenCount - 1 do
  begin
    LFrame := DecodeWfcMusicEnsembleFrame(AModel.PublicTokenAt(LIndex));
    Require(Length(LFrame.Voices) = 1, 'Intensity mask requires a singleton voice model');
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

function PlanPhrase(const AModels: TWfcMusicVoicesGraphConfig; const ASeed: TGraphSeed;
  const ADocument: TJSONObject; const AKeys: TKeyContexts;
  const ARhythm, AIntensity: String; const APitches: TPitchNotes;
  const AExactGuidePitches: Boolean): TWfcMusicVoicesGenerated;
var
  LGraph: TGraph;
  LBoundaries: TWfcMusicVoicesBoundaries;
  LGuide: TWfcMusicEnsembleFrame;
  LOptions: TGraphNegotiationOptions;
  LReport: TGraphNegotiationReport;
  LProof: TWfcMusicVoicesValidationReport;
  LGenerated: TWfcMusicVoicesGenerated;
  LIndex: Integer;
  LVoice: Integer;
  LCell: Integer;
  LCellCount: Integer;
begin
  LCellCount := CCells;
  if ARhythm <> '' then
  begin
    LCellCount := Length(ARhythm);
  end;
  Require(Length(AKeys) = LCellCount, 'Voice key contexts must cover every planned cell');
  SetLength(LBoundaries, WfcMusicVoicesModelCount(AModels));
  for LIndex := 0 to High(LBoundaries) do
  begin
    LBoundaries[LIndex] := MakeWfcSequenceInitialSegmentBoundary(True);
  end;
  LGraph := BuildWfcMusicVoicesSegmentGraph(AModels, LCellCount, ASeed, LBoundaries);
  try
    for LCell := 0 to LCellCount - 1 do
    begin
      if ARhythm <> '' then
      begin
        LGuide := StyleGuideFrame(LCell, AKeys[LCell], ARhythm, AIntensity, APitches);
      end
      else if LCell < 32 then
      begin
        LGuide := TrainingFrame(1, LCell, AKeys[LCell]);
      end
      else
      begin
        LGuide := TrainingFrame(0, LCell - 32, AKeys[LCell]);
      end;
      IntersectSequenceAllowedTokens(AModels.HarmonyModel, LGraph.PassGraph[0], LCell,
        [EncodeWfcMusicPitchClassSet(ProjectWfcMusicEnsembleFrameToPitchClassSet(LGuide, 12))]);
      IntersectSequenceAllowedTokens(AModels.RhythmModel, LGraph.PassGraph[1], LCell,
        [EncodeWfcMusicRhythmFrame(ProjectWfcMusicEnsembleFrameToRhythm(LGuide))]);
      if (AIntensity <> '') or (Length(APitches) > 0) then
      begin
        for LVoice := 0 to High(AModels.Voices) do
        begin
          IntersectSequenceAllowedTokens(AModels.Voices[LVoice].Model,
            LGraph.PassGraph[LVoice + 2], LCell,
            VoiceGuideTokens(AModels.Voices[LVoice].Model, LGuide.Voices[LVoice],
              (Length(APitches) > 0) and ((LVoice = 2) or AExactGuidePitches), Length(APitches) > 0));
        end;
      end;
    end;
    LOptions := DefaultGraphNegotiationOptions;
    LOptions.SolveOptions.MaxBacktracks := 512;
    LOptions.MaxPassBacktracks := 32;
    if not LGraph.TrySolveNegotiated(LOptions, LReport) then
    begin
      raise EAudio.CreateFmt('Bounded independent-voice phrase planning failed: status %d, pass %d, pass backtracks %d',
        [Ord(LReport.Status), LReport.FinalReport.FailedPassIndex, LReport.PassBacktracks]);
    end;
    Require(CaptureSolvedWfcMusicVoices(AModels, LGraph, LBoundaries, LGenerated, LProof),
      'Independent voice plan failed its musical/path proof');
    ADocument.Add('planning', 'Bounded independent-voice graph with shared harmony/rhythm guide, then streamed realization');
    if Length(APitches) > 0 then
    begin
      if AExactGuidePitches then
      begin
        ADocument.Add('accompaniment_policy', 'Changing-key mode pins authored bass/chord scale degrees and octaves per attack through actual voice models; measured melody keeps absolute pitch');
      end
      else
      begin
        ADocument.Add('accompaniment_policy', 'Authored bass/chord pitch-class contributions fixed per cell; actual voice models retain compatible voicings; measured melody keeps absolute pitch');
      end;
    end;
    ADocument.Add('plan_max_backtracks', LOptions.SolveOptions.MaxBacktracks);
    ADocument.Add('plan_max_pass_backtracks', LOptions.MaxPassBacktracks);
    ADocument.Add('plan_checked_models', LProof.CheckedModels);
    ADocument.Add('plan_checked_cells', LProof.CheckedCells);
    Result := LGenerated;
  finally
    LGraph.Free;
  end;
end;

procedure Drain(const ARenderer: TChordStreamRenderer;
  const AReference: TWfcMusicEnsembleAudioRenderer; const AWriter: TWavePcm16Writer);
var
  LSamples: TAudioSamples;
  LReference: TWfcMusicPcm16Samples;
  LNativeMore: Boolean;
  LReferenceMore: Boolean;
  LIndex: Integer;
begin
  repeat
    LNativeMore := ARenderer.ReadSamples(997, LSamples);
    if AReference <> nil then
    begin
      LReferenceMore := AReference.ReadSamples(997, LReference);
      Require((LNativeMore = LReferenceMore) and
        (Length(LSamples) = Length(LReference)), 'Reference output block differs');
      for LIndex := 0 to High(LSamples) do
      begin
        Require(LSamples[LIndex] = LReference[LIndex] / 32768,
          'Generated ensemble PCM differs from the actual WFC renderer');
      end;
    end;
    if LNativeMore then
    begin
      AWriter.AppendSamples(LSamples);
    end;
  until not LNativeMore;
end;

function SynthesisVoices: TNoteVoices;
var
  LIndex: Integer;
begin
  Result := nil;
  SetLength(Result, 3);
  for LIndex := 0 to 2 do
  begin
    Result[LIndex] := DefaultSynthVoice;
    Result[LIndex].OscillatorQuality := oqPolynomial;
    Result[LIndex].Envelope.ReleaseSeconds := 0.12;
  end;
  Result[0].Shape := wsTriangle;
  Result[0].Gain := 0.28;
  Result[0].CutoffHz := 1500;
  Result[0].Envelope.AttackSeconds := 0.005;
  Result[0].Envelope.DecaySeconds := 0.08;
  Result[0].Envelope.SustainLevel := 0.65;
  Result[1].Shape := wsSaw;
  Result[1].Gain := 0.12;
  Result[1].Pan := -0.35;
  Result[1].CutoffHz := 1700;
  Result[1].Envelope.AttackSeconds := 0.04;
  Result[1].Envelope.DecaySeconds := 0.2;
  Result[1].Envelope.SustainLevel := 0.45;
  Result[2].Shape := wsSquare;
  Result[2].Gain := 0.18;
  Result[2].Pan := 0.35;
  Result[2].CutoffHz := 3200;
  Result[2].Envelope.AttackSeconds := 0.006;
  Result[2].Envelope.DecaySeconds := 0.1;
  Result[2].Envelope.SustainLevel := 0.5;
end;

function EncodeFrameMidi(const AFrames: TWfcMusicEnsembleFrames;
  const ATempos: TContextTempos; const ALengths: TVoiceCellLengths): TAudioBytes;
var
  LOptions: TChordMidiOptions;
  LTiming: TChordMidiTiming;
  LCounter: TChordMidiCounter;
  LPlan: TChordMidiPlan;
  LStream: TChordMidiStream;
  LMemory: TMemoryStream;
  LFrame: TChordFrame;
  LCell: Integer;

  procedure PrepareFrame;
  begin
    LFrame := ProjectWfcChordFrame(AFrames[LCell]);
    LTiming := Default(TChordMidiTiming);
    if (LCell > 0) and (ATempos[LCell] <> ATempos[LCell - 1]) then
    begin
      LTiming.TempoMicrosecondsPerQuarter := ATempos[LCell];
    end;
  end;

  procedure DrainMidi;
  var
    LBlock: TMidiBytes;
  begin
    while LStream.ReadBytes(997, LBlock) do
    begin
      LMemory.WriteBuffer(LBlock[0], Length(LBlock));
    end;
  end;

begin
  Result := nil;
  Require((Length(AFrames) > 0) and (Length(AFrames) <= CCells + MaximumLayerCells), 'MIDI frame extent');
  Require((Length(ATempos) = Length(AFrames)) and (Length(ALengths) = Length(AFrames)),
    'MIDI tempo/duration cells must cover the frame sequence');
  LOptions := DefaultChordMidiOptions([0, 1, 2]);
  LOptions.TicksPerQuarter := CPpq;
  LOptions.TempoMicrosecondsPerQuarter := ATempos[0];
  LCounter := TChordMidiCounter.Create(LOptions);
  LPlan := nil;
  LStream := nil;
  LMemory := nil;
  try
    for LCell := 0 to High(AFrames) do
    begin
      PrepareFrame;
      LCounter.AdmitFrame(LFrame, ALengths[LCell], LTiming);
    end;
    LPlan := LCounter.Finish;
    LStream := TChordMidiStream.Create(LPlan);
    FreeAndNil(LPlan);
    FreeAndNil(LCounter);
    LMemory := TMemoryStream.Create;
    DrainMidi;
    for LCell := 0 to High(AFrames) do
    begin
      PrepareFrame;
      LStream.AdmitFrame(LFrame, ALengths[LCell], LTiming);
      DrainMidi;
    end;
    LStream.EndInput;
    DrainMidi;
    Require(LStream.Finished and (LStream.EmittedBytes = LMemory.Size), 'MIDI stream extent');
    SetLength(Result, LMemory.Size);
    LMemory.Position := 0;
    if Length(Result) > 0 then
    begin
      LMemory.ReadBuffer(Result[0], Length(Result));
    end;
  finally
    LMemory.Free;
    LStream.Free;
    LPlan.Free;
    LCounter.Free;
  end;
end;

procedure VerifyMidi(const ASequence: TNoteSequence; const ABytes: TMidiBytes);
var
  LDecoded: TNoteSequence;
  LReport: TMidiNoteReport;
  LSourceClock: TTempoMap;
  LDecodedClock: TTempoMap;
  LUsed: array of Boolean;
  LSource: TNoteGate;
  LCandidate: TNoteGate;
  LIndex: Integer;
  LMatch: Integer;
  LFound: Boolean;
begin
  LDecoded := DecodeMidiNotes(ABytes, DefaultMidiNoteOptions, LReport);
  LSourceClock := nil;
  LDecodedClock := nil;
  try
    Require((LDecoded.NoteCount = ASequence.NoteCount) and
      (LDecoded.LengthTicks = ASequence.LengthTicks) and
      (LDecoded.TicksPerQuarter = ASequence.TicksPerQuarter), 'MIDI round-trip extent');
    LSourceClock := ASequence.CopyClock;
    LDecodedClock := LDecoded.CopyClock;
    Require(LSourceClock.ChangeCount = LDecodedClock.ChangeCount, 'MIDI tempo count');
    for LIndex := 0 to LSourceClock.ChangeCount - 1 do
    begin
      Require((LSourceClock.ChangeAt(LIndex).Tick = LDecodedClock.ChangeAt(LIndex).Tick) and
        (LSourceClock.ChangeAt(LIndex).MicrosecondsPerQuarter =
          LDecodedClock.ChangeAt(LIndex).MicrosecondsPerQuarter), 'MIDI tempo mapping');
    end;
    SetLength(LUsed, LDecoded.NoteCount);
    for LIndex := 0 to ASequence.NoteCount - 1 do
    begin
      LSource := ASequence.GateAt(LIndex);
      LFound := False;
      for LMatch := 0 to LDecoded.NoteCount - 1 do
      begin
        LCandidate := LDecoded.GateAt(LMatch);
        if not LUsed[LMatch] and (LCandidate.StartTick = LSource.StartTick) and
          (LCandidate.EndTick = LSource.EndTick) and (LCandidate.Pitch = LSource.Pitch) and
          (LCandidate.Velocity = LSource.Velocity) and (LCandidate.Channel = LSource.Voice) then
        begin
          LUsed[LMatch] := True;
          LFound := True;
          Break;
        end;
      end;
      Require(LFound, 'MIDI round trip lost a generated note or voice channel');
    end;
  finally
    LDecodedClock.Free;
    LSourceClock.Free;
    LDecoded.Free;
  end;
end;

procedure Run(const AOutput: String; const ASeed: TGraphSeed;
  const ASegmentCells: Integer; const AVerify: Boolean; const AProfileName: String;
  const AUseStyle, ACouplePitch: Boolean; const ARhythmLocks, AIntensityLocks, APitchLock: String;
  const ADurationSpans, ADurationTempoCells, ADurationKeyCells: Integer; const ADurationLock, AStyleExtent, ADurationTempoLock, ADurationKeyLock: String);
var
  LModels: TWfcMusicVoicesGraphConfig;
  LConfig: TWfcMusicVoicesStreamConfig;
  LStream: TWfcMusicVoicesStream;
  LSegment: TWfcMusicVoicesSegment;
  LFrontier: TWfcMusicVoicesStreamFrontier;
  LRenderer: TChordStreamRenderer;
  LClock: TIncrementalTempoClock;
  LReference: TWfcMusicEnsembleAudioRenderer;
  LReferenceCaps: TWfcMusicEnsembleAudioVoiceCapacities;
  LCapacities: TChordCapacities;
  LMemory: TMemoryStream;
  LSink: TStreamAudioSink;
  LWriter: TWavePcm16Writer;
  LScore: TWfcMusicScore;
  LSequence: TNoteSequence;
  LStereo: TAudioClip;
  LVoices: TNoteVoices;
  LRenderStyle: TWaveStyleProfile;
  LTimbreFactory: TWavetableSourceFactory;
  LTimbreRecipe: TWavetableCycleRecipe;
  LMeasuredEnvelope: TGateEnvelope;
  LRenderReport: TNoteRenderReport;
  LFrames: TWfcMusicEnsembleFrames;
  LAllFrames: TWfcMusicEnsembleFrames;
  LPlaybackFrames: TWfcMusicEnsembleFrames;
  LPlaybackTempos: TContextTempos;
  LPlaybackLengths: TVoiceCellLengths;
  LPlaybackClock: TTempoMap;
  LParts: TTimedWfcEnsembleFrames;
  LPart: Integer;
  LPartCount: Integer;
  LPartRows: TJSONArray;
  LPartRow: TJSONObject;
  LPlan: TWfcMusicVoicesGenerated;
  LReport: TGraphNegotiationReport;
  LValidation: TWfcSequenceGraphValidationReport;
  LGenerated: TWfcGeneratedSequenceSegment;
  LModel: TWfcSequenceModel;
  LStep: TWfcMusicArrangementStep;
  LDocument: TJSONObject;
  LSegments: TJSONArray;
  LRow: TJSONObject;
  LLayers: TJSONArray;
  LLayer: TJSONObject;
  LTokens: TJSONArray;
  LStates: TJSONArray;
  LFrameRows: TJSONArray;
  LVoiceRows: TJSONArray;
  LBytes: TAudioBytes;
  LMidiBytes: TAudioBytes;
  LMidiExpected: TAudioBytes;
  LMidiIndex: Integer;
  LExpected: Int64;
  LCell: Integer;
  LModelIndex: Integer;
  LVoice: Integer;
  LGlobalCell: Integer;
  LTempo: Integer;
  LContinuedHolds: Integer;
  LContextGrid: TMusicContextGrid;
  LTempoRows: TJSONArray;
  LRhythm: String;
  LIntensity: String;
  LPitches: TPitchNotes;
  LCellCount: Integer;
  LLengths: TVoiceCellLengths;
  LTotalTicks: Integer;
  LGatePlan: TArticulationPlan;
  LGated: TAudioClip;
  LSubFrame: Integer;
begin
  Require((ASegmentCells >= 1) and (ASegmentCells <= 32), 'Segment cells must be 1..32');
  if AProfileName <> '' then
  begin
    Require(not SameFileName(ExpandFileName(AProfileName), ExpandFileName(AOutput)) and
      not SameFileName(ExpandFileName(AProfileName), ExpandFileName(AOutput + '.json')) and
      not SameFileName(ExpandFileName(AProfileName), ExpandFileName(AOutput + '.mid')) and
      not SameFileName(ExpandFileName(AProfileName), ExpandFileName(AOutput + '.preview.wav')),
      'Voice outputs must not replace the context profile');
  end;
  LModels := Default(TWfcMusicVoicesGraphConfig);
  LStream := nil;
  LSegment := nil;
  LRenderer := nil;
  LClock := nil;
  LPlaybackClock := nil;
  LReference := nil;
  LMemory := nil;
  LSink := nil;
  LWriter := nil;
  LScore := nil;
  LSequence := nil;
  LStereo := nil;
  LRenderStyle := nil;
  LTimbreFactory := nil;
  LMeasuredEnvelope := nil;
  LDocument := TJSONObject.Create;
  try
    if AProfileName = '' then
    begin
      LDocument.Add('contract', 'pythian.voices.demo.v1');
      LDocument.Add('source', 'Native symbolic training score; no recorded audio or external music');
      LDocument.Add('guide', 'Authored C-Am-F-G-C-F-G-C harmony and rhythm; voices selected by independent learned models');
    end
    else if AUseStyle then
    begin
      LDocument.Add('contract', 'pythian.voices.wave-style.demo.v1');
      LDocument.Add('source', 'WAV-derived onset presence and selected context; pitches, voicings and one-cell gates are authored');
      LDocument.Add('guide', 'Authored diatonic harmony and independent voices arranged under a saved generated onset pattern');
    end
    else
    begin
      LDocument.Add('contract', 'pythian.voices.context.demo.v1');
      LDocument.Add('source', 'Authored symbolic voice training adapted to saved key context; tempo from saved provider');
      LDocument.Add('guide', 'Authored I-vi-IV-V-I-IV-V-I scale-degree pattern mapped to selected major/natural-minor key');
    end;
    LDocument.Add('seed', Int64(ASeed));
    LDocument.Add('cells', CCells);
    LDocument.Add('segment_cells', ASegmentCells);
    LDocument.Add('sample_rate', CRate);
    LDocument.Add('ticks_per_quarter', CPpq);
    LDocument.Add('quantum_ticks', CQuantum);
    if ADurationSpans > 0 then
    begin
      LContextGrid := ResolveDurationStyle(AProfileName, ASeed, ADurationSpans,
        ADurationTempoCells, ADurationKeyCells, ADurationLock, APitchLock, ADurationTempoLock, ADurationKeyLock, LDocument, LRhythm, LPitches, LLengths, LPlaybackClock);
      LDocument.Strings['source'] := 'Saved measured pitch/kind/duration spans; authored accompaniment and synthesis';
      LDocument.Strings['guide'] := 'Measured pitched spans guide melody and voice gates; unknown/silence spans are arranged rests';
    end
    else
    begin
      LContextGrid := ResolveContext(AProfileName, ASeed, LDocument, AUseStyle, ACouplePitch,
        ARhythmLocks, AIntensityLocks, APitchLock, AStyleExtent, LRhythm, LIntensity, LPitches);
      SetLength(LLengths, CCells);
      for LCell := 0 to CCells - 1 do
      begin
        LLengths[LCell] := CQuantum;
      end;
    end;
    LCellCount := Length(LLengths);
    LDocument.Integers['cells'] := LCellCount;
    LTotalTicks := 0;
    for LCell := 0 to LCellCount - 1 do
    begin
      Inc(LTotalTicks, LLengths[LCell]);
    end;
    if AProfileName = '' then
    begin
      LDocument.Add('tempo_change_cell', CTempoChangeCell);
      LDocument.Add('tempo_before', CTempoBefore);
      LDocument.Add('tempo_after', CTempoAfter);
    end
    else
    begin
      LTempoRows := TJSONArray.Create;
      LDocument.Add('tempo_cells', LTempoRows);
      for LCell := 0 to LCellCount - 1 do
      begin
        LTempoRows.Add(LContextGrid.Tempos[LCell]);
      end;
    end;
    LDocument.Add('voices_training_version', WFC_MUSIC_VOICES_TRAINING_VERSION);
    LDocument.Add('voices_graph_version', WFC_MUSIC_VOICES_GRAPH_VERSION);
    LDocument.Add('voices_stream_version', WFC_MUSIC_VOICES_STREAM_VERSION);
    LDocument.Add('chord_stream_version', ChordStreamVersion);
    LDocument.Add('synthesis_version', SynthesisVersion);
    LModels := LearnModels(LDocument, LContextGrid.Keys, LRhythm, LIntensity, LPitches,
      ADurationSpans > 0);
    LCapacities := WfcIndependentVoiceCapacities([LModels.Voices[0].Model,
      LModels.Voices[1].Model, LModels.Voices[2].Model]);
    Require((LCapacities[0] = 1) and (LCapacities[1] = 3) and (LCapacities[2] = 1),
      'Complete voice vocabularies must retain bass, full chords and melody');
    LConfig := DefaultWfcMusicVoicesStreamConfig(LModels, CQuantum, LCellCount * CQuantum, ASeed);
    LConfig.SegmentCellCount := ASegmentCells;
    LConfig.RequireObservedEnd := True;
    LDocument.Add('stream_max_backtracks', LConfig.Search.SolveOptions.MaxBacktracks);
    LDocument.Add('stream_max_pass_backtracks', LConfig.Search.MaxPassBacktracks);
    LPlan := PlanPhrase(LModels, ASeed, LDocument, LContextGrid.Keys, LRhythm, LIntensity, LPitches, ADurationKeyCells > 0);
    LStream := TWfcMusicVoicesStream.Create(LConfig);
    for LCell := 0 to LCellCount - 1 do
    begin
      for LModelIndex := 0 to 4 do
      begin
        LStream.IntersectAllowedTokens(LModelIndex, LCell, [LPlan.Layers[LModelIndex].Tokens[LCell]]);
      end;
    end;
    LClock := TIncrementalTempoClock.Create(CPpq, CRate);
    for LCell := 0 to LCellCount - 1 do
    begin
      LClock.Advance(LLengths[LCell], LContextGrid.Tempos[LCell]);
    end;
    LExpected := LClock.Snapshot.FrameCount;
    if LPlaybackClock <> nil then
    begin
      LExpected := LPlaybackClock.FrameAtTick(LTotalTicks, CRate);
    end;
    Require((ADurationSpans = 0) or (LExpected <= 120 * CRate), 'Duration voice output exceeds 120 seconds');
    FreeAndNil(LClock);
    LClock := TIncrementalTempoClock.Create(CPpq, CRate);
    LRenderer := TChordStreamRenderer.Create(DefaultChordStreamOptions(CRate), LCapacities);
    if AVerify then
    begin
      SetLength(LReferenceCaps, 3);
      for LVoice := 0 to 2 do
      begin
        LReferenceCaps[LVoice] := LCapacities[LVoice];
      end;
      LReference := TWfcMusicEnsembleAudioRenderer.Create(DefaultWfcMusicAudioOptions,
        CPpq, LReferenceCaps);
    end;
    LMemory := TMemoryStream.Create;
    LSink := TStreamAudioSink.Create(LMemory);
    LWriter := TWavePcm16Writer.Create(LSink, CRate, 1, LExpected);
    LSegments := TJSONArray.Create;
    LDocument.Add('segments', LSegments);
    LFrameRows := TJSONArray.Create;
    LDocument.Add('frames', LFrameRows);
    SetLength(LAllFrames, LCellCount);
    LGlobalCell := 0;
    LContinuedHolds := 0;
    LPartCount := 0;
    LPartRows := TJSONArray.Create;
    LDocument.Add('playback_parts', LPartRows);
    if LPlaybackClock <> nil then
    begin
      SetLength(LPlaybackFrames, LCellCount + LPlaybackClock.ChangeCount);
      SetLength(LPlaybackTempos, Length(LPlaybackFrames));
      SetLength(LPlaybackLengths, Length(LPlaybackFrames));
    end;
    repeat
      LFrontier := LStream.CopyFrontier;
      LStep := LStream.Next(LSegment, LReport);
      if LStep = wmaspCompleted then
      begin
        Break;
      end;
      Require(LStep = wmaspProduced, 'Independent voice generation stopped: ' + LStream.Failure);
      try
        Require((LSegment.StartTick = LGlobalCell * CQuantum) and
          (LSegment.Seed = WfcMusicArrangementSectionSeed(ASeed, LSegment.Index)) and
          (LReport.Status = gnsSolved), 'Segment timing/seed/solver provenance');
        LRow := TJSONObject.Create;
        LSegments.Add(LRow);
        LRow.Add('index', LSegment.Index);
        LRow.Add('start_tick', LSegment.StartTick);
        if ADurationSpans > 0 then
        begin
          LRow.Add('realized_start_tick', LClock.Snapshot.TickCount);
        end;
        LRow.Add('cell_count', LSegment.CellCount);
        LRow.Add('seed', Int64(LSegment.Seed));
        LRow.Add('signature', Int64(LSegment.Signature));
        LLayers := TJSONArray.Create;
        LRow.Add('layers', LLayers);
        for LModelIndex := 0 to 4 do
        begin
          LGenerated := LSegment.CopyGenerated(LModelIndex);
          LModel := WfcMusicVoicesModelAt(LModels, LModelIndex);
          Require(LGenerated.Boundary.HasPrevious = LFrontier.HasPrevious,
            'Independent model lost predecessor presence');
          if LFrontier.HasPrevious then
          begin
            Require(LGenerated.Boundary.PreviousState = LFrontier.StateIndices[LModelIndex],
              'Independent model lost its exact preceding latent state');
          end;
          Require(ValidateSequenceSegmentStatePath(LModel, LGenerated.StateIndices,
            LGenerated.Boundary, LValidation), 'Independent model has an invalid latent path');
          LLayer := TJSONObject.Create;
          LLayers.Add(LLayer);
          LLayer.Add('model_index', LModelIndex);
          LLayer.Add('has_previous', LGenerated.Boundary.HasPrevious);
          LLayer.Add('previous_state', LGenerated.Boundary.PreviousState);
          LLayer.Add('observed_end', LGenerated.Boundary.RequireObservedEnd);
          LTokens := TJSONArray.Create;
          LLayer.Add('tokens', LTokens);
          LStates := TJSONArray.Create;
          LLayer.Add('states', LStates);
          for LCell := 0 to High(LGenerated.Tokens) do
          begin
            Require(LModel.ProjectStateToken(LGenerated.StateIndices[LCell]) =
              LGenerated.Tokens[LCell], 'Independent state emission differs from token');
            Require((LGenerated.Tokens[LCell] = LPlan.Layers[LModelIndex].Tokens[LGlobalCell + LCell]) and
              (LGenerated.StateIndices[LCell] = LPlan.Layers[LModelIndex].StateIndices[LGlobalCell + LCell]),
              'Independent stream differs from the finite learned plan');
            LTokens.Add(LGenerated.Tokens[LCell]);
            LStates.Add(LGenerated.StateIndices[LCell]);
          end;
        end;
        LFrames := LSegment.CopyFrames;
        Require(Length(LFrames) = LSegment.CellCount, 'Independent frame count differs from segment');
        if LFrontier.HasPrevious then
        begin
          for LVoice := 0 to 2 do
          begin
            if LFrames[0].Voices[LVoice].Action = wmcaHold then
            begin
              Inc(LContinuedHolds);
            end;
          end;
        end;
        for LCell := 0 to High(LFrames) do
        begin
          LTempo := LContextGrid.Tempos[LGlobalCell];
          if AUseStyle then
          begin
            for LVoice := 0 to High(LFrames[LCell].Voices) do
            begin
              if LRhythm[LGlobalCell + 1] = 'x' then
              begin
                Require(LFrames[LCell].Voices[LVoice].Action = wmcaAttack,
                  'Generated voice lost its measured rhythm attack');
              end
              else
              begin
                Require(LFrames[LCell].Voices[LVoice].Action = wmcaRest,
                  'Generated voice violates the declared empty-cell arrangement');
              end;
            end;
          end;
          LAllFrames[LGlobalCell] := LFrames[LCell];
          LFrameRows.Add(EncodeWfcMusicEnsembleFrame(LFrames[LCell]));
          if LPlaybackClock <> nil then
          begin
            LParts := TimeWfcEnsembleFrame(LFrames[LCell], LPlaybackClock,
              LClock.Snapshot.TickCount, LLengths[LGlobalCell]);
            for LPart := 0 to High(LParts) do
            begin
              LPlaybackFrames[LPartCount] := LParts[LPart].Frame;
              LPlaybackTempos[LPartCount] := LParts[LPart].Timing.MicrosecondsPerQuarter;
              LPlaybackLengths[LPartCount] := LParts[LPart].Timing.LengthTicks;
              LPartRow := TJSONObject.Create;
              LPartRows.Add(LPartRow);
              LPartRow.Add('source_cell', LGlobalCell);
              LPartRow.Add('start_tick', LParts[LPart].Timing.StartTick);
              LPartRow.Add('length_ticks', LParts[LPart].Timing.LengthTicks);
              LPartRow.Add('tempo_us', LParts[LPart].Timing.MicrosecondsPerQuarter);
              LPartRow.Add('frame', EncodeWfcMusicEnsembleFrame(LParts[LPart].Frame));
              AdmitWfcEnsembleFrame(LRenderer, LClock, LParts[LPart].Frame,
                LParts[LPart].Timing.LengthTicks, LParts[LPart].Timing.MicrosecondsPerQuarter);
              if LReference <> nil then
              begin
                LReference.AdmitFrame(LParts[LPart].Frame, LParts[LPart].Timing.LengthTicks,
                  LParts[LPart].Timing.MicrosecondsPerQuarter);
              end;
              Drain(LRenderer, LReference, LWriter);
              Inc(LPartCount);
            end;
          end
          else
          begin
            AdmitWfcEnsembleFrame(LRenderer, LClock, LFrames[LCell], LLengths[LGlobalCell], LTempo);
            if LReference <> nil then
            begin
              LReference.AdmitFrame(LFrames[LCell], LLengths[LGlobalCell], LTempo);
            end;
            Drain(LRenderer, LReference, LWriter);
          end;
          Inc(LGlobalCell);
        end;
      finally
        FreeAndNil(LSegment);
      end;
    until False;
    LRenderer.EndInput;
    if LReference <> nil then
    begin
      LReference.EndInput;
    end;
    Drain(LRenderer, LReference, LWriter);
    Require((LGlobalCell = LCellCount) and LRenderer.Finished and
      (LRenderer.EmittedFrames = LExpected) and (LClock.Snapshot.TickCount = LTotalTicks),
      'Final native preview extent');
    LWriter.Finish;
    if LPlaybackClock <> nil then
    begin
      SetLength(LPlaybackFrames, LPartCount);
      SetLength(LPlaybackTempos, LPartCount);
      SetLength(LPlaybackLengths, LPartCount);
      LScore := ScoreForFrames(LPlaybackFrames, LPlaybackTempos);
    end
    else
    begin
      LScore := ScoreForFrames(LAllFrames, LContextGrid.Tempos);
    end;
    if ADurationSpans > 0 then
    begin
      LSequence := ProjectRetimedWfcNotes(LScore, CQuantum, LPlaybackLengths);
      LDocument.Add('score_time_policy', 'WFC score uses logical equal cells and trailing rests to complete its required measure; training selections exclude padding; realized native notes/MIDI/audio use only the requested measured cell lengths');
    end
    else
    begin
      LSequence := ProjectWfcNotes(LScore);
    end;
    if LPlaybackClock <> nil then
    begin
      LMidiBytes := EncodeFrameMidi(LPlaybackFrames, LPlaybackTempos, LPlaybackLengths);
    end
    else
    begin
      LMidiBytes := EncodeFrameMidi(LAllFrames, LContextGrid.Tempos, LLengths);
    end;
    if AVerify then
    begin
      VerifyMidi(LSequence, LMidiBytes);
      if ADurationSpans = 0 then
      begin
        LMidiExpected := EncodeWfcMusicMidi(LScore);
        Require(Length(LMidiBytes) = Length(LMidiExpected), 'Actual WFC MIDI byte extent');
        for LMidiIndex := 0 to High(LMidiBytes) do
        begin
          Require(LMidiBytes[LMidiIndex] = LMidiExpected[LMidiIndex], 'Actual WFC MIDI bytes');
        end;
      end;
    end;
    Require(LSequence.FrameAtTick(LSequence.LengthTicks, CRate) = LExpected,
      'Complete score clock disagrees with the streamed native clock');
    LVoices := SynthesisVoices;
    if AUseStyle then
    begin
      LRenderStyle := DecodeWaveStyle(ReadFileBytes(AProfileName, MaximumStyleBytes));
      Require(LRenderStyle.Identity = LDocument.Get('wave_style_sha256', ''),
        'Style changed between musical planning and timbre rendering');
      if LRenderStyle.HasTimbre then
      begin
        LTimbreFactory := LRenderStyle.CopyTimbreFactory(CRate);
        for LVoice := 0 to High(LVoices) do
        begin
          LVoices[LVoice].SourceFactory := LTimbreFactory;
        end;
        if LRenderStyle.HasTimbreTrajectory then
        begin
          LDocument.Add('timbre_policy', 'Saved weighted unit-RMS magnitude shapes on union frame knots; note-relative timing; independent envelope/gain controls; preview retains reference oscillators');
          LDocument.Add('timbre_reference_rms', 0.1);
          LDocument.Strings['source'] := 'Saved measured musical behavior and spectral trajectories; authored accompaniment, envelopes and mixing';
        end
        else
        begin
          LTimbreRecipe := LRenderStyle.CopyTimbreRecipe;
          LDocument.Add('timbre_policy', 'Saved weighted harmonic magnitudes, zero sine phase; same recipe for all voices; independent envelope/gain controls; preview retains reference oscillators');
          LDocument.Add('timbre_harmonic_count', Length(LTimbreRecipe.Sine));
          LDocument.Strings['source'] := 'Saved measured musical behavior and stationary harmonic timbre; authored accompaniment, envelopes and mixing';
        end;
      end;
      if LRenderStyle.HasEnvelope then
      begin
        LMeasuredEnvelope := LRenderStyle.CopyGateEnvelope(CRate);
        for LVoice := 0 to High(LVoices) do
        begin
          LVoices[LVoice].GateEnvelope := LMeasuredEnvelope;
        end;
        LDocument.Add('envelope_policy', 'Saved weighted normalized held levels and relative releases; shared across voices; declared source gates; learned silent/unknown spans retain articulation priority');
        LDocument.Add('envelope_release_frames', LMeasuredEnvelope.ReleaseFrames);
        LDocument.Strings['source'] := 'Saved measured musical behavior and amplitude envelope; optional saved stationary timbre; authored accompaniment and mixing';
      end;
    end;
    LVoiceRows := TJSONArray.Create;
    LDocument.Add('synthesis_voices', LVoiceRows);
    for LVoice := 0 to High(LVoices) do
    begin
      LRow := TJSONObject.Create;
      LVoiceRows.Add(LRow);
      LRow.Add('voice_index', LVoice);
      LRow.Add('role', CVoiceNames[LVoice]);
      LRow.Add('midi_channel', LVoice);
      LRow.Add('capacity', LCapacities[LVoice]);
      LRow.Add('minimum_pitch', LModels.Voices[LVoice].MinPitch);
      LRow.Add('maximum_pitch', LModels.Voices[LVoice].MaxPitch);
      LRow.Add('wave_shape', Ord(LVoices[LVoice].Shape));
      LRow.Add('saved_timbre', LTimbreFactory <> nil);
      LRow.Add('saved_envelope', LMeasuredEnvelope <> nil);
      LRow.Add('oscillator_quality', Ord(LVoices[LVoice].OscillatorQuality));
      LRow.Add('gain', LVoices[LVoice].Gain);
      LRow.Add('pan', LVoices[LVoice].Pan);
      LRow.Add('cutoff_hz', LVoices[LVoice].CutoffHz);
      LRow.Add('filter_kind', Ord(LVoices[LVoice].FilterKind));
      LRow.Add('filter_model', Ord(LVoices[LVoice].FilterModel));
      LRow.Add('attack_seconds', LVoices[LVoice].Envelope.AttackSeconds);
      LRow.Add('decay_seconds', LVoices[LVoice].Envelope.DecaySeconds);
      LRow.Add('sustain_level', LVoices[LVoice].Envelope.SustainLevel);
      LRow.Add('release_seconds', LVoices[LVoice].Envelope.ReleaseSeconds);
    end;
    LStereo := RenderNoteSequence(LSequence, CRate, LVoices, LRenderReport);
    if ADurationSpans > 0 then
    begin
      LGatePlan := PlanNoteArticulation(LSequence, CRate, 44, 44, LSubFrame);
      try
        LGated := RenderArticulatedClip(LStereo, LGatePlan);
        LStereo.Free;
        LStereo := LGated;
      finally
        LGatePlan.Free;
      end;
      LDocument.Add('gate_policy', 'All generated voices use learned span boundaries; native articulation suppresses release tails in unknown/silent intervals');
      LDocument.Add('realized_length_ticks', LTotalTicks);
    end;
    Require((LRenderReport.SubFrameNotes = 0) and
      (LRenderReport.RenderedNotes = LRenderReport.SourceNotes), 'Every generated note must render');
    LDocument.Add('generated_score', EncodeWfcMusicText(LScore));
    LDocument.Add('preview_frames', LExpected);
    LDocument.Add('stereo_frames', LStereo.FrameCount);
    LDocument.Add('rendered_notes', LRenderReport.RenderedNotes);
    LDocument.Add('continued_voice_holds', LContinuedHolds);
    LDocument.Add('preview_verified_against_wfc', AVerify);
    LDocument.Add('midi_export_version', ChordMidiVersion);
    LDocument.Add('midi_export_kind', 'chord_frames');
    LDocument.Add('midi_verified_against_wfc', AVerify and (ADurationSpans = 0));
    LDocument.Add('midi_verified_by_round_trip', AVerify);
    LDocument.Add('midi_sha256', HashAudioBytes(LMidiBytes));
    LBytes := EncodeWavePcm16(LStereo);
    LDocument.Add('stereo_sha256', HashAudioBytes(LBytes));
    WriteFileBytes(AOutput, LBytes);
    SetLength(LBytes, LMemory.Size);
    LMemory.Position := 0;
    LMemory.ReadBuffer(LBytes[0], Length(LBytes));
    LDocument.Add('preview_sha256', HashAudioBytes(LBytes));
    WriteFileBytes(AOutput + '.preview.wav', LBytes);
    WriteFileBytes(AOutput + '.mid', LMidiBytes);
    WriteTextFile(AOutput + '.json', LDocument.FormatJSON);
    WriteLn('Independent voices: five learned models, ', LGlobalCell, ' cells, ',
      LSegments.Count, ' segments, ', LContinuedHolds, ' continued voice holds');
    WriteLn('Native preview ', LExpected, ' frames; stereo ', LStereo.FrameCount,
      ' frames / ', LRenderReport.RenderedNotes, ' notes; actual WFC PCM verification: ', AVerify);
  finally
    LStereo.Free;
    LMeasuredEnvelope.Free;
    LTimbreFactory.Free;
    LRenderStyle.Free;
    LSequence.Free;
    LScore.Free;
    LWriter.Free;
    LSink.Free;
    LMemory.Free;
    LReference.Free;
    LRenderer.Free;
    LClock.Free;
    LPlaybackClock.Free;
    LSegment.Free;
    LStream.Free;
    for LVoice := 0 to High(LModels.Voices) do
    begin
      LModels.Voices[LVoice].Model.Free;
    end;
    LModels.RhythmModel.Free;
    LModels.HarmonyModel.Free;
    LDocument.Free;
  end;
end;

procedure Main;
var
  LSeed: QWord;
  LSegment: Integer;
  LCount: Integer;
  LVerify: Boolean;
  LProfileName: String;
  LUseStyle: Boolean;
  LCouplePitch: Boolean;
  LRhythmLocks: String;
  LIntensityLocks: String;
  LPitchLock: String;
  LDurationSpans: Integer;
  LDurationTempoCells: Integer;
  LDurationKeyCells: Integer;
  LDurationKeyLock: String;
  LDurationLock: String;
  LDurationTempoLock: String;
  LStyleExtent: String;
begin
  LCount := ParamCount;
  LVerify := (LCount > 0) and (ParamStr(LCount) = '--verify');
  Dec(LCount, Ord(LVerify));
  LCouplePitch := False;
  LRhythmLocks := '';
  LIntensityLocks := '';
  LPitchLock := '';
  LDurationSpans := 0;
  LDurationTempoCells := 0;
  LDurationKeyCells := 0;
  LDurationKeyLock := '';
  LDurationLock := '';
  LDurationTempoLock := '';
  LStyleExtent := '';
  while (LCount >= 2) and ((ParamStr(LCount) = '--coupled-pitch') or
    ((LCount >= 3) and ((ParamStr(LCount - 1) = '--rhythm-locks') or
    (ParamStr(LCount - 1) = '--intensity-locks') or
    (ParamStr(LCount - 1) = '--pitch-lock') or
    (ParamStr(LCount - 1) = '--duration-spans') or
    (ParamStr(LCount - 1) = '--duration-tempo-cells') or
    (ParamStr(LCount - 1) = '--duration-key-cells') or
    (ParamStr(LCount - 1) = '--duration-key-lock') or
    (ParamStr(LCount - 1) = '--duration-tempo-lock') or
    (ParamStr(LCount - 1) = '--duration-lock') or
    (ParamStr(LCount - 1) = '--style-extent')))) do
  begin
    if ParamStr(LCount) = '--coupled-pitch' then
    begin
      Require(not LCouplePitch, 'Duplicate coupled-pitch option');
      LCouplePitch := True;
      Dec(LCount);
      Continue;
    end;
    if ParamStr(LCount - 1) = '--style-extent' then
    begin
      Require(LStyleExtent = '', 'Duplicate style extent');
      LStyleExtent := ParamStr(LCount);
      Require((LStyleExtent = 'whole') or (LStyleExtent = 'prefix') or
        (LStyleExtent = 'fragment'), 'Style extent must be whole, prefix or fragment');
    end
    else if ParamStr(LCount - 1) = '--duration-spans' then
    begin
      Require(LDurationSpans = 0, 'Duplicate duration span count');
      LDurationSpans := StrToInt(ParamStr(LCount));
      Require((LDurationSpans >= 1) and (LDurationSpans <= CCells), 'Duration spans must be 1..64');
    end
    else if ParamStr(LCount - 1) = '--duration-tempo-cells' then
    begin
      Require(LDurationTempoCells = 0, 'Duplicate duration tempo scope');
      LDurationTempoCells := StrToInt(ParamStr(LCount));
      Require((LDurationTempoCells >= 1) and (LDurationTempoCells <= MaximumLayerCells),
        'Duration tempo cells must be 1..1024');
    end
    else if ParamStr(LCount - 1) = '--duration-key-cells' then
    begin
      Require(LDurationKeyCells = 0, 'Duplicate duration key scope');
      LDurationKeyCells := StrToInt(ParamStr(LCount));
      Require((LDurationKeyCells >= 1) and (LDurationKeyCells <= MaximumLayerCells),
        'Duration key cells must be 1..1024');
    end
    else if ParamStr(LCount - 1) = '--duration-key-lock' then
    begin
      Require(LDurationKeyLock = '', 'Duplicate duration key lock');
      LDurationKeyLock := ParamStr(LCount);
      Require(LDurationKeyLock <> '', 'Key lock requires CELL:ROOT:major|minor');
    end
    else if ParamStr(LCount - 1) = '--duration-tempo-lock' then
    begin
      Require(LDurationTempoLock = '', 'Duplicate duration tempo lock');
      LDurationTempoLock := ParamStr(LCount);
      Require(LDurationTempoLock <> '', 'Tempo lock must specify CELL:MICROSECONDS_PER_QUARTER');
    end
    else if ParamStr(LCount - 1) = '--duration-lock' then
    begin
      Require(LDurationLock = '', 'Duplicate duration lock');
      LDurationLock := ParamStr(LCount);
    end
    else if ParamStr(LCount - 1) = '--rhythm-locks' then
    begin
      Require(LRhythmLocks = '', 'Duplicate rhythm mask');
      LRhythmLocks := ParamStr(LCount);
    end
    else if ParamStr(LCount - 1) = '--pitch-lock' then
    begin
      Require(LPitchLock = '', 'Duplicate pitch lock');
      LPitchLock := ParamStr(LCount);
    end
    else
    begin
      Require(LIntensityLocks = '', 'Duplicate intensity mask');
      LIntensityLocks := ParamStr(LCount);
    end;
    Dec(LCount, 2);
  end;
  LProfileName := '';
  LUseStyle := (LCount >= 3) and (ParamStr(LCount - 1) = '--style');
  if (LCount >= 3) and ((ParamStr(LCount - 1) = '--context') or LUseStyle) then
  begin
    LProfileName := ParamStr(LCount);
    Dec(LCount, 2);
  end;
  Require((LCount >= 1) and (LCount <= 3),
    'Usage: pythian.voices.demo OUTPUT.wav [SEED [SEGMENT_CELLS]] ' +
    '[--context PROFILE.pcp | --style PROFILE.pys [--style-extent whole|prefix|fragment] ' +
    '[--rhythm-locks PATTERN] [--intensity-locks PATTERN] [--pitch-lock CELL:NOTE] ' +
    '[--coupled-pitch] [--duration-spans COUNT [--duration-tempo-cells COUNT [--duration-tempo-lock CELL:US]] [--duration-key-cells COUNT [--duration-key-lock CELL:ROOT:major|minor]] [--duration-lock CELL:TICKS]]] [--verify]');
  Require((LRhythmLocks = '') or LUseStyle, 'Rhythm locks require a WAV style profile');
  Require((LIntensityLocks = '') or LUseStyle, 'Intensity locks require a WAV style profile');
  Require((LPitchLock = '') or LUseStyle, 'Pitch lock requires a WAV style profile');
  Require(not LCouplePitch or LUseStyle, 'Coupled pitch requires a WAV style profile');
  Require((LDurationSpans = 0) or (LUseStyle and not LCouplePitch and
    (LRhythmLocks = '') and (LIntensityLocks = '')),
    'Duration voices require a style and use their own measured performance controls');
  Require((LDurationKeyCells = 0) or (LDurationSpans > 0), 'Key scope requires duration spans');
  Require((LDurationKeyLock = '') or (LDurationKeyCells > 0), 'Key lock requires explicit key cells');
  Require((LDurationTempoLock = '') or (LDurationTempoCells > 0), 'Tempo lock requires explicit tempo cells');
  Require((LDurationTempoCells = 0) or (LDurationSpans > 0), 'Tempo scope requires duration spans');
  Require((LDurationLock = '') or (LDurationSpans > 0), 'Duration lock requires duration spans');
  Require((LStyleExtent = '') or (LUseStyle and (LDurationSpans = 0)),
    'Style extent applies to cell-style providers; duration mode has explicit prefix semantics');
  LSeed := 731;
  LSegment := 5;
  if LCount >= 2 then
  begin
    Require(TryStrToQWord(ParamStr(2), LSeed) and (LSeed <= High(TGraphSeed)),
      'Seed must fit the companion seed type');
  end;
  if LCount = 3 then
  begin
    LSegment := StrToInt(ParamStr(3));
  end;
  Run(ParamStr(1), LSeed, LSegment, LVerify, LProfileName, LUseStyle, LCouplePitch, LRhythmLocks, LIntensityLocks, LPitchLock, LDurationSpans, LDurationTempoCells, LDurationKeyCells, LDurationLock, LStyleExtent, LDurationTempoLock, LDurationKeyLock);
end;

begin
  try
    Main;
  except
    on LException: Exception do
    begin
      WriteLn(StdErr, LException.ClassName, ': ', LException.Message);
      if not (LException is EAudio) then
      begin
        DumpExceptionBackTrace(StdErr);
      end;
      ExitCode := 1;
    end;
  end;
end.
