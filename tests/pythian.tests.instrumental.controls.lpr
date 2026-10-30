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
program pythian_tests_instrumental_controls;
{$mode delphi}
{$H+}
uses
  SysUtils,
  pythian.audio,
  pythian.bus,
  pythian.schedule,
  pythian.music,
  pythian.music.controls,
  pythian.music.pattern,
  pythian.instrument,
  pythian.synth,
  pythian.pitch.track,
  pythian.wfc.instrumental,
  pythian.wfc.instrumental.controls,
  pythian.wfc.instrumental.starter,
  pythian.wfc.voices,
  pythian.wfc.layers,
  pythian.wfc.musical.context,
  pythian.wfc.percussion,
  wfc_model,
  wfc_sequence,
  wfc_sequence_learn,
  wfc_music,
  wfc_music_sequence,
  wfc_music_ensemble,
  wfc_music_ensemble_graph,
  wfc_music_voices_graph;

var
  Checks: Integer;

procedure Check(const ACondition: Boolean; const ADetail: String);
begin
  Inc(Checks);
  if not ACondition then raise EAudio.Create(ADetail);
end;

function RenderPart(const APlan: TInstrumentalPlan; const APart: Integer;
  const AMinimumFrames: Int64 = 0): TAudioSamples;
var
  LSettings: array[0..6] of TBusSettings;
  LGraph: TBusGraph;
  LPlayer: TScheduledSynth;
  LIndex: Integer;
  LLeft: Double;
  LRight: Double;
  LFrames: Int64;
begin
  Result := nil;
  for LIndex := 0 to 6 do
  begin
    LSettings[LIndex] := Default(TBusSettings);
    if (LIndex = APart) or (LIndex = 6) then LSettings[LIndex].Gain := 1;
  end;
  LGraph := TBusGraph.Create(APlan.SampleRate, LSettings);
  LPlayer := nil;
  try
    for LIndex := 0 to 5 do LGraph.AddSend(LIndex, 6, stPostFader, 1, 0);
    LPlayer := APlan.CreatePlayer(LGraph);
    LFrames := APlan.FrameCount;
    if AMinimumFrames > LFrames then LFrames := AMinimumFrames;
    SetLength(Result, LFrames * 2);
    for LIndex := 0 to Integer(LFrames) - 1 do
    begin
      LPlayer.Process(LLeft, LRight);
      Result[2 * LIndex] := LLeft;
      Result[2 * LIndex + 1] := LRight;
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
  begin
    if ALeft[LIndex] <> ARight[LIndex] then Exit;
  end;
  Result := True;
end;

procedure AudibleDensity;
var
  LSamples: array[0..2] of TWfcSequenceSamples;
  LModels: array[0..2] of TWfcSequenceModel;
  LConfig: TWfcMusicVoicesGraphConfig;
  LFrame: TWfcMusicEnsembleFrame;
  LAction: TWfcMusicCellAction;
  LRoles: TInstrumentalRoles;
  LZones: TInstrumentZones;
  LInstrument: TInstrument;
  LOptions: TInstrumentalOptions;
  LParts: TMusicalPartControls;
  LControls: TInstrumentalGraphControls;
  LBase: TVoiceMasks;
  LSparse: TInstrumentalPlan;
  LDense: TInstrumentalPlan;
  LReport: TInstrumentalReport;
  LNotes: TNoteSequence;
  LSparseCount: Integer;
  LDenseCount: Integer;
  LProvider: Integer;
  LPhrase: Integer;
  LCell: Integer;
begin
  LInstrument := nil;
  LSparse := nil;
  LDense := nil;
  for LProvider := 0 to 2 do LModels[LProvider] := nil;
  try
    for LProvider := 0 to 2 do
    begin
      SetLength(LSamples[LProvider], 2);
      for LPhrase := 0 to 1 do SetLength(LSamples[LProvider][LPhrase].Tokens, 8);
    end;
    SetLength(LFrame.Voices, 1);
    for LPhrase := 0 to 1 do
      for LCell := 0 to 7 do
      begin
        LAction := wmcaHold;
        if (LPhrase = 1) or (LCell = 0) then LAction := wmcaAttack;
        LFrame.Voices[0] := MakeWfcMusicVoiceCell(LAction, [MakeWfcMusicTone(60, 80)]);
        LSamples[0][LPhrase].Tokens[LCell] := EncodeWfcMusicPitchClassSet(
          ProjectWfcMusicEnsembleFrameToPitchClassSet(LFrame, 12));
        LSamples[1][LPhrase].Tokens[LCell] := EncodeWfcMusicRhythmFrame(
          ProjectWfcMusicEnsembleFrameToRhythm(LFrame));
        LSamples[2][LPhrase].Tokens[LCell] := EncodeWfcMusicEnsembleFrame(LFrame);
      end;
    for LProvider := 0 to 2 do
      LModels[LProvider] := LearnSequenceModelCorpus(LSamples[LProvider], 1);
    LConfig := Default(TWfcMusicVoicesGraphConfig);
    LConfig.StepsPerOctave := 12;
    LConfig.HarmonyMode := wmehmExact;
    LConfig.HarmonyModel := LModels[0];
    LConfig.RhythmModel := LModels[1];
    SetLength(LConfig.Voices, 1);
    LConfig.Voices[0].Model := LModels[2];
    LConfig.Voices[0].MinPitch := 60;
    LConfig.Voices[0].MaxPitch := 60;
    SetLength(LZones, 1);
    LZones[0] := Default(TInstrumentZone);
    LZones[0].MaximumKey := 127;
    LZones[0].MinimumVelocity := 1;
    LZones[0].MaximumVelocity := 127;
    LZones[0].Voice := DefaultSynthVoice;
    LZones[0].Voice.Gain := 0.1;
    LInstrument := TInstrument.Create(LZones);
    SetLength(LRoles, 1);
    LRoles[0].Name := 'lead';
    LRoles[0].InstrumentId := 'authored-tone';
    LRoles[0].Instrument := LInstrument;
    LOptions := DefaultInstrumentalOptions;
    LOptions.SampleRate := 8000;
    LOptions.Session.CellCount := 8;
    LOptions.Session.Seed := 731;
    LOptions.Session.RequireObservedEnd := False;
    LOptions.MaterialOrigin := 'Authored sparse/dense symbolic alternatives';
    SetLength(LParts, 1);
    LParts[0] := DefaultMusicalPartControl;
    SetLength(LBase, 3);
    SetLength(LBase[1], 1);
    LBase[1][0] := MakeWfcSequenceTokenConstraint(0, [LSamples[1][0].Tokens[0]]);
    LParts[0].ActivityBias := -100;
    LControls := CompileInstrumentalControls(LConfig, 8, 0, 0, LParts, LBase);
    Check(TryCreateInstrumentalPlan(LConfig, LRoles, LOptions, LControls.Masks,
      LControls.Preferences, LSparse, LReport), 'Sparse rhythm preference performs');
    LParts[0].ActivityBias := 100;
    LControls := CompileInstrumentalControls(LConfig, 8, 0, 0, LParts, LBase);
    Check(TryCreateInstrumentalPlan(LConfig, LRoles, LOptions, LControls.Masks,
      LControls.Preferences, LDense, LReport), 'Dense rhythm preference performs');
    LNotes := LSparse.CopyNotes;
    try LSparseCount := LNotes.NoteCount; finally LNotes.Free end;
    LNotes := LDense.CopyNotes;
    try LDenseCount := LNotes.NoteCount; finally LNotes.Free end;
    Check(LDenseCount > LSparseCount, 'Upstream activity changes actual performed attack count');
    Check(not SameAudio(RenderPart(LSparse, 0), RenderPart(LDense, 0)),
      'Sparse/dense symbolic choices produce different instrumental PCM');
    WriteLn('Authored density pair: ', LSparseCount, ' / ', LDenseCount, ' attacks');
  finally
    LDense.Free;
    LSparse.Free;
    LInstrument.Free;
    for LProvider := 0 to 2 do LModels[LProvider].Free;
  end;
end;

procedure Run;
var
  LStarter: TInstrumentalStarter;
  LPlan: TInstrumentalPlan;
  LPerformed: TInstrumentalPlan;
  LFree: TInstrumentalPlan;
  LOptions: TInstrumentalOptions;
  LReport: TInstrumentalReport;
  LParts: TMusicalPartControls;
  LControls: TInstrumentalGraphControls;
  LOther: TInstrumentalGraphControls;
  LBase: TVoiceMasks;
  LDrums: TPercussionDefinitions;
  LModel: TWfcSequenceModel;
  LTokens: TWfcModelTokens;
  LFrame: TWfcMusicEnsembleFrame;
  LRhythm: TWfcMusicRhythmFrame;
  LNotes: TNoteSequence;
  LOtherNotes: TNoteSequence;
  LBefore: TAudioSamples;
  LAfter: TAudioSamples;
  LRole: Integer;
  LCell: Integer;
  LToken: Integer;
  LCount: Integer;
  LRaised: Boolean;
  LFound: Boolean;
  LJointStarter: TInstrumentalStarter;
  LContext: TMusicalContextPlan;
  LPattern: TPitchPattern;
  LNames: TLayerNames;
  LPreferences: TLayerTokenPreferences;
begin
  LStarter := TInstrumentalStarter.Create;
  LPlan := nil;
  LPerformed := nil;
  LFree := nil;
  LNotes := nil;
  LOtherNotes := nil;
  LJointStarter := nil;
  LContext := nil;
  LOptions := DefaultInstrumentalOptions;
  LOptions.SampleRate := 8000;
  LOptions.Session.CellCount := 8;
  LOptions.Session.RequireObservedEnd := False;
  LOptions.Session.Seed := 731;
  LOptions.MaterialOrigin := 'Authored control fixture';
  SetLength(LParts, 3);
  for LRole := 0 to 2 do LParts[LRole] := DefaultMusicalPartControl;
  try
    LBase := LStarter.GuideMasks(8);
    LControls := CompileInstrumentalControls(LStarter.Config, 8, 0, 0, LParts, LBase);
    Check((Length(LControls.Masks) = 5) and (Length(LControls.Preferences) = 0),
      'Actual guide controls with no redundant neutral preference edits');
    Check((Length(LControls.Masks[0]) = 8) and (Length(LControls.Masks[1]) = 8) and
      (Length(LControls.Masks[4]) = 0), 'Neutral controls preserve guide and free role');
    Check(Length(LControls.Preferences) = 0, 'Neutral preference vector is absent');
    LControls.Masks[0][0].AllowedTokens[0] := 'detached';
    Check(LBase[0][0].AllowedTokens[0] <> 'detached', 'Compiled masks do not alias guide');
    LControls := CompileInstrumentalControls(LStarter.Config, 8, 0, 0, LParts, LBase);
    LDrums := LStarter.CopyPercussion(8000);
    Check(TryCreateInstrumentalPlan(LStarter.Config, LStarter.CopyRoles, LOptions,
      LControls.Masks, LControls.Preferences, LPlan, LReport, nil, LDrums),
      'Actual six-part neutral graph performs');
    LParts[2].MinimumPitch := 72;
    LParts[2].MaximumPitch := 79;
    LControls := CompileInstrumentalControls(LStarter.Config, 8, 0, 0, LParts, LBase);
    Check(Length(LControls.Masks[4]) = 8, 'Hard role pitch range compiles every cell');
    LModel := LStarter.Config.Voices[2].Model;
    for LCell := 0 to 7 do
    begin
      LFound := False;
      for LToken := 0 to High(LControls.Masks[4][LCell].AllowedTokens) do
      begin
        LFrame := DecodeWfcMusicEnsembleFrame(LControls.Masks[4][LCell].AllowedTokens[LToken]);
        for LCount := 0 to High(LFrame.Voices[0].Tones) do
          Check((LFrame.Voices[0].Tones[LCount].Pitch >= 72) and
            (LFrame.Voices[0].Tones[LCount].Pitch <= 79), 'Every hard-range choice stays in range');
        LFound := LFound or (LModel.FindPublicToken(LControls.Masks[4][LCell].AllowedTokens[LToken]) >= 0);
      end;
      Check(LFound, 'Range choices are actual model tokens');
    end;
    LParts[2] := DefaultMusicalPartControl;
    LParts[2].ActivityBias := 60;
    LControls := CompileInstrumentalControls(LStarter.Config, 8, 0, 40, LParts, LBase);
    Check((Length(LControls.Preferences[0]) > 0) and
      (Length(LControls.Preferences[1]) > 0), 'Actual root and upstream rhythm preferences');
    LRhythm := DecodeWfcMusicRhythmFrame(LControls.Preferences[1][0].Token);
    Check((LControls.Preferences[1][0].Multiplier = 19) and
      (LRhythm.Actions[2] = wmcaAttack), 'Activity weights the rhythm before it pins the voice');
    Check(Length(LControls.Preferences[4]) = 0, 'Activity is not double-counted downstream');
    Check(Length(LControls.Preferences[2]) = 0, 'Other role preferences remain neutral');

    LParts[2] := DefaultMusicalPartControl;
    LParts[2].Expression.VelocityPercent := 50;
    LParts[2].Expression.GatePercent := 25;
    LControls := CompileInstrumentalControls(LStarter.Config, 8, 0, 0, LParts, LBase);
    SetLength(LOptions.Expression, 3);
    for LRole := 0 to 2 do LOptions.Expression[LRole] := LParts[LRole].Expression;
    Check(TryCreateInstrumentalPlan(LStarter.Config, LStarter.CopyRoles, LOptions,
      LControls.Masks, LControls.Preferences, LPerformed, LReport, nil, LDrums),
      'Expression uses actual instrumental planning');
    for LRole := 0 to High(LPlan.CopyGraph) do
    begin
      if LPlan.CopyGraph[LRole].IsProof then Continue;
      LTokens := LPlan.CopyPassTokens(LRole);
      Check(Length(LTokens) = Length(LPerformed.CopyPassTokens(LRole)), 'Same symbolic extent');
      for LCell := 0 to High(LTokens) do
        Check(LTokens[LCell] = LPerformed.CopyPassTokens(LRole)[LCell],
          'Expression preserves exact WFC decisions');
    end;
    LNotes := LPlan.CopyNotes;
    LOtherNotes := LPerformed.CopyNotes;
    Check(LNotes.NoteCount = LOtherNotes.NoteCount, 'Expression retains note identities');
    for LCell := 0 to LNotes.NoteCount - 1 do
    begin
      Check(LNotes.GateAt(LCell).StartTick = LOtherNotes.GateAt(LCell).StartTick,
        'Expression retains actual attack time');
      if LNotes.GateAt(LCell).Voice = 2 then
        Check(LOtherNotes.GateAt(LCell).Velocity < LNotes.GateAt(LCell).Velocity,
          'Lead velocity is performed differently')
      else
        Check((LOtherNotes.GateAt(LCell).EndTick = LNotes.GateAt(LCell).EndTick) and
          (LOtherNotes.GateAt(LCell).Velocity = LNotes.GateAt(LCell).Velocity),
          'Unchanged pitched roles retain exact performance');
    end;
    LBefore := RenderPart(LPlan, 2);
    Check(LPerformed.FrameCount <= LPlan.FrameCount, 'Shorter gates cannot extend the release tail');
    LAfter := RenderPart(LPerformed, 2, LPlan.FrameCount);
    Check(not SameAudio(LBefore, LAfter), 'Expression changes actual synthesized lead PCM');
    LBefore := RenderPart(LPlan, 0);
    LAfter := RenderPart(LPerformed, 0, LPlan.FrameCount);
    Check(SameAudio(LBefore, LAfter), 'Unchanged bass PCM remains exact');
    LBefore := RenderPart(LPlan, 3);
    LAfter := RenderPart(LPerformed, 3, LPlan.FrameCount);
    Check(SameAudio(LBefore, LAfter), 'Unchanged percussion PCM remains exact');

    LOther := LControls;
    LParts[2].MinimumPitch := 0;
    LParts[2].MaximumPitch := 0;
    LRaised := False;
    try LOther := CompileInstrumentalControls(LStarter.Config, 8, 0, 0, LParts, LBase);
    except on E: EAudio do LRaised := True end;
    Check(LRaised, 'Unavailable hard pitch bounds reject without a solve or relaxation');
    Check(Length(LOther.Masks[0]) = 8, 'Failed compilation preserves preceding controls');

    LParts[2] := DefaultMusicalPartControl;
    LControls := CompileInstrumentalControls(LStarter.Config, 8, 0, 0, LParts, nil);
    Check((Length(LControls.Masks) = 0) and (Length(LControls.Preferences) = 0),
      'Neutral free controls do not stage empty edits on every provider');
    LParts[2].ActivityBias := 50;
    LControls := CompileInstrumentalControls(LStarter.Config, 8, 0, 40, LParts, nil);
    LOptions.Expression := nil;
    Check(TryCreateInstrumentalPlan(LStarter.Config, LStarter.CopyRoles, LOptions,
      LControls.Masks, LControls.Preferences, LFree, LReport, nil, LDrums),
      'Available vocabulary can generate with free harmony/rhythm and soft preferences');
    SetLength(LPattern, 4);
    SetLength(LNames, 3);
    for LCell := 0 to 3 do
    begin
      LPattern[LCell].Kind := pskPitch;
      LPattern[LCell].Note := 60;
      LPattern[LCell].Velocity := 80;
      LPattern[LCell].Attack := True;
    end;
    LJointStarter := TInstrumentalStarter.Create(0, False, LPattern, 2);
    for LRole := 0 to 2 do
    begin
      LParts[LRole] := DefaultMusicalPartControl;
      LNames[LRole] := LJointStarter.CopyRoles[LRole].Name;
    end;
    LParts[2].ActivityBias := 100;
    LControls := CompileInstrumentalControls(LJointStarter.Config, 8, 0, 100, LParts, nil);
    LContext := TMusicalContextPlan.Create(LJointStarter.ContextModel, LNames,
      LOptions.Session, LControls.Masks, LControls.Preferences);
    LPreferences := LContext.CopyPreferences;
    LFound := False;
    for LToken := 0 to High(LPreferences) do
    begin
      Check(LPreferences[LToken].Multiplier <= MaximumLayerPreferenceMultiplier,
        'Legal UI preferences fit the actual joint-context weight budget');
      LFound := LFound or (LPreferences[LToken].Multiplier = 961);
    end;
    Check(LFound, 'Maximum root and selected-part preferences both reach joint context');
  finally
    LContext.Free;
    LJointStarter.Free;
    LOtherNotes.Free;
    LNotes.Free;
    LFree.Free;
    LPerformed.Free;
    LPlan.Free;
    LStarter.Free;
  end;
end;

begin
  try
    Run;
    AudibleDensity;
    WriteLn('PASS instrumental controls: ', Checks, ' checks');
  except
    on E: Exception do
    begin
      WriteLn(E.ClassName, ': ', E.Message);
      {$IFDEF PAS2JS}
      raise;
      {$ELSE}
      ExitCode := 1;
      {$ENDIF}
    end;
  end;
end.
