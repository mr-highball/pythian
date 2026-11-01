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
program InstrumentalDensityConformance;
{$mode delphi}
{$H+}
uses SysUtils, pythian.audio, pythian.bus, pythian.synth, pythian.instrument,
  pythian.chord, pythian.percussion, pythian.music.form, pythian.music.decisions,
  pythian.music.stream, pythian.progress, pythian.wfc.instrumental,
  pythian.wfc.instrumental.stream, pythian.wfc.percussion, pythian.wfc.providers,
  wfc_model, wfc_sequence, wfc_sequence_learn, wfc_music, wfc_music_sequence,
  wfc_music_ensemble, wfc_music_ensemble_graph, wfc_music_voices_graph;

type
  TChunks = array of TMusicDecisionChunk;
  TCapture = class
    Chunks: TChunks;
    CancelDensity: Boolean;
    procedure Keep(const AChunk: TMusicDecisionChunk);
    procedure Observe(const AWork: TWorkProgress);
  end;
  TRendered = record
    Mix: TAudioSamples;
    Chunks: TChunks;
  end;

var
  GChecks: Integer;
  GModels: array[0..4] of TWfcSequenceModel;
  GConfig: TWfcMusicVoicesGraphConfig;
  GRoles: TInstrumentalRoles;
  GDrums: TPercussionDefinitions;
  GInstrument: TInstrument;

procedure Check(const AValue: Boolean; const AMessage: String);
begin
  Inc(GChecks);
  if not AValue then raise EAudio.Create(AMessage);
end;

procedure TCapture.Keep(const AChunk: TMusicDecisionChunk);
begin
  SetLength(Chunks, Length(Chunks) + 1);
  Chunks[High(Chunks)] := CopyMusicDecisionChunk(AChunk);
end;

procedure TCapture.Observe(const AWork: TWorkProgress);
begin
  if CancelDensity and (AWork.Stage = 'instrumental_density_cells_ready') then
    raise EAudio.Create('Stopped density preparation');
end;

procedure Setup;
var
  LSamples: array[0..4] of TWfcSequenceSamples;
  LFrame: TWfcMusicEnsembleFrame;
  LContext: TMusicalContextCell;
  LZones: TInstrumentZones;
  LAction: TWfcMusicCellAction;
  I, J, K: Integer;
begin
  for I := 0 to 4 do
  begin
    SetLength(LSamples[I], 2);
    for J := 0 to 1 do SetLength(LSamples[I][J].Tokens, 8);
  end;
  SetLength(LFrame.Voices, 1);
  for J := 0 to 1 do
    for K := 0 to 7 do
    begin
      LAction := wmcaHold;
      if (J = 1) or (K = 0) then LAction := wmcaAttack;
      LFrame.Voices[0] := MakeWfcMusicVoiceCell(LAction, [MakeWfcMusicTone(60, 80)]);
      LSamples[0][J].Tokens[K] := EncodeWfcMusicPitchClassSet(
        ProjectWfcMusicEnsembleFrameToPitchClassSet(LFrame, 12));
      LSamples[1][J].Tokens[K] := EncodeWfcMusicRhythmFrame(
        ProjectWfcMusicEnsembleFrameToRhythm(LFrame));
      LSamples[2][J].Tokens[K] := EncodeWfcMusicEnsembleFrame(LFrame);
      LContext.Frame := LFrame;
      LContext.DrivenRole := 0;
      LSamples[3][J].Tokens[K] := EncodeMusicalContextToken(LContext);
      if LAction = wmcaAttack then LSamples[4][J].Tokens[K] := PercussionToken(90)
      else LSamples[4][J].Tokens[K] := PercussionToken(0);
    end;
  for I := 0 to 4 do GModels[I] := LearnSequenceModelCorpus(LSamples[I], 1);
  GConfig := Default(TWfcMusicVoicesGraphConfig);
  GConfig.StepsPerOctave := 12;
  GConfig.HarmonyMode := wmehmExact;
  GConfig.HarmonyModel := GModels[0];
  GConfig.RhythmModel := GModels[1];
  SetLength(GConfig.Voices, 1);
  GConfig.Voices[0].Model := GModels[2];
  GConfig.Voices[0].MinPitch := 60;
  GConfig.Voices[0].MaxPitch := 60;
  SetLength(LZones, 1);
  LZones[0] := Default(TInstrumentZone);
  LZones[0].MaximumKey := 127;
  LZones[0].MinimumVelocity := 1;
  LZones[0].MaximumVelocity := 127;
  LZones[0].Voice := DefaultSynthVoice;
  LZones[0].Voice.Gain := 0.1;
  GInstrument := TInstrument.Create(LZones);
  SetLength(GRoles, 1);
  GRoles[0].Name := 'lead';
  GRoles[0].InstrumentId := 'authored-density-tone';
  GRoles[0].Instrument := GInstrument;
  SetLength(GDrums, 1);
  GDrums[0].Name := 'kick';
  GDrums[0].Origin := 'Authored hit/rest alternatives';
  GDrums[0].Model := GModels[4];
  GDrums[0].Settings := DefaultPercussionSettings(pkKick, 8000);
  GDrums[0].OutputBus := 1;
  GDrums[0].Enabled := True;
  GDrums[0].HitWeight := 1;
end;

function Render(const AContext, AReturn: Boolean; const APull: Integer;
  const AFirstDensity, ASecondDensity: Integer;
  const ACancel: Boolean = False; const AGuide: Boolean = False): TRendered;
var
  LBus: TBusGraph;
  LSettings: array[0..2] of TBusSettings;
  LStream: TInstrumentalMusicStream;
  LOptions: TInstrumentalStreamOptions;
  LForm: TMusicForm;
  LContext: TWfcSequenceModel;
  LCapture: TCapture;
  LBlock: TAudioSamples;
  I, LAt: Integer;
  LStopped: Boolean;
  LAttack: String;
begin
  Result := Default(TRendered);
  for I := 0 to 2 do
  begin
    LSettings[I] := DefaultBusSettings;
    LSettings[I].SmoothingSeconds := 0;
  end;
  LBus := TBusGraph.Create(8000, LSettings);
  LCapture := TCapture.Create;
  LStream := nil;
  try
    LBus.AddSend(0, 2, stPostFader, 0.25, 0);
    LBus.AddSend(1, 2, stPostFader, 0.25, 0);
    SetLength(LForm, 2 + Ord(AReturn));
    for I := 0 to High(LForm) do
    begin
      LForm[I].Section := 'Density experiment';
      LForm[I].Name := 'Section ' + IntToStr(I);
      LForm[I].Cells := 32;
      LForm[I].RepeatFrom := -1;
    end;
    LForm[0].DensityOffset := AFirstDensity;
    LForm[1].DensityOffset := ASecondDensity;
    if AReturn then
    begin
      LForm[2].RepeatFrom := 0;
      LForm[2].DensityOffset := 50;
      LForm[2].Keep := ['harmony', 'rhythm', 'lead', 'kick'];
    end;
    LOptions := DefaultInstrumentalStreamOptions(8000 * 8 * Length(LForm));
    LOptions.TailFrames := 800;
    LContext := nil;
    if AContext then LContext := GModels[3];
    LCapture.CancelDensity := ACancel;
    LStream := TInstrumentalMusicStream.Create(GConfig, GRoles, GDrums, LBus,
      LOptions, LContext, LCapture.Keep, LForm);
    if AGuide then
    begin
      Check(not AContext, 'The direct voice guide fixture has no competing context');
      LAttack := '';
      for I := 0 to GModels[1].PublicTokenCount - 1 do
        if DecodeWfcMusicRhythmFrame(GModels[1].PublicTokenAt(I)).Actions[0] = wmcaAttack then
          LAttack := GModels[1].PublicTokenAt(I);
      Check(LAttack <> '', 'The hard guide uses an actual public attack token');
      for I := 0 to 31 do LStream.IntersectFutureTokens(1, I, [LAttack]);
    end;
    { Caller mutation after construction must not alter pending section rows. }
    LForm[0].DensityOffset := 999;
    SetLength(Result.Mix, LStream.FrameCount * 2);
    LAt := 0;
    LStopped := False;
    try
      while LStream.ReadSamples(APull, LBlock, LCapture.Observe) do
      begin
        if LAt = 0 then
          Check(LStream.LastVoicePlanningCells >= 32,
            'Density preserves the real bounded future planning window');
        for I := 0 to High(LBlock) do Result.Mix[LAt + I] := LBlock[I];
        Inc(LAt, Length(LBlock));
      end;
    except on E: EAudio do
      if E.Message = 'Stopped density preparation' then LStopped := True else raise;
    end;
    Result.Chunks := LCapture.Chunks;
    if ACancel then
      Check(LStopped and (Length(Result.Chunks) = 0) and
        (LStream.State = issFailed), 'Cancelled density preparation publishes no partial music')
    else
      Check((LStream.State = issCompleted) and (LAt = Length(Result.Mix)),
        'Section density performs the complete original musical clock');
  finally
    LStream.Free;
    LCapture.Free;
    LBus.Free;
  end;
end;

function Attacks(const ARendered: TRendered; const ASection, APart: Integer): Integer;
var
  LChunk: TMusicDecisionChunk;
  I: Integer;
begin
  Result := 0;
  for LChunk in ARendered.Chunks do
    for I := 0 to High(LChunk.Cells) do
      if (LChunk.FirstCell + I >= ASection * 32) and
        (LChunk.FirstCell + I < (ASection + 1) * 32) and
        (LChunk.Cells[I].Parts[APart].Action = caAttack) then Inc(Result);
end;

function SameAudio(const ALeft, ARight: TAudioSamples): Boolean;
var I: Integer;
begin
  Result := False;
  if Length(ALeft) <> Length(ARight) then Exit;
  for I := 0 to High(ALeft) do if ALeft[I] <> ARight[I] then Exit;
  Result := True;
end;

procedure Run;
var
  LResult, LReplay, LNeutral, LReverse, LCancelled, LGuided: TRendered;
  LContext: Boolean;
  I, J, K, LPart: Integer;
begin
  Setup;
  try
    for LContext := False to True do
    begin
      LResult := Render(LContext, True, 2048, -50, 50);
      LReplay := Render(LContext, True, 173, -50, 50);
      Check(SameAudio(LResult.Mix, LReplay.Mix),
        'Positioned density replays exactly across different PCM pulls');
      for LPart := 0 to 1 do
      begin
        WriteLn('Context=', LContext, ', part=', LPart, ': ',
          Attacks(LResult, 0, LPart), ' / ', Attacks(LResult, 1, LPart), ' attacks');
        Check(Attacks(LResult, 1, LPart) > Attacks(LResult, 0, LPart),
          'Sparse/busy sections change actual pitched and drum attack counts');
      end;
      for I := 0 to 1 do
        for J := 0 to High(LResult.Chunks[I].Providers) do
          for K := 0 to 15 do
            Check(LResult.Chunks[I].Providers[J].Tokens[K] =
              LResult.Chunks[I + 4].Providers[J].Tokens[K],
              'Hard retained musical providers override the busy return preference');
      LNeutral := Render(LContext, False, 2048, 0, 0);
      LReverse := Render(LContext, False, 2048, 50, -50);
      Check(not SameAudio(LNeutral.Mix, LReverse.Mix),
        'Actual density choices change synthesized PCM with identical energy and instruments');
      for LPart := 0 to 1 do
        Check(Attacks(LReverse, 0, LPart) > Attacks(LReverse, 1, LPart),
          'Reversed positioned controls reverse the section activity contrast');
      LCancelled := Render(LContext, False, 2048, -50, 50, True);
    end;
    LGuided := Render(False, False, 2048, -50, 50, False, True);
    Check(Attacks(LGuided, 0, 0) = 32,
      'A hard authored rhythm guide overrides the sparse section preference');
  finally
    GInstrument.Free;
    for I := 0 to 4 do GModels[I].Free;
  end;
end;

begin
  try
    Run;
    WriteLn('PASS ', GChecks, ' instrumental density checks');
  except on E: Exception do
  begin
    WriteLn('FAIL: ', E.ClassName, ': ', E.Message);
    ExitCode := 1;
  end end;
end.
