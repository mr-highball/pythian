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
program pythian_tests_instrumental;

{$mode delphi}
{$H+}

uses
  SysUtils,
  Math,
  pythian.audio,
  pythian.time,
  pythian.progress,
  pythian.music,
  pythian.synth,
  pythian.bus,
  pythian.schedule,
  pythian.effects,
  pythian.wfc.instrumental,
  pythian.wfc.instrumental.starter,
  pythian.wfc.voices,
  wfc_model,
  wfc_sequence,
  wfc_sequence_graph,
  wfc_music,
  wfc_music_sequence,
  wfc_music_ensemble,
  wfc_music_voices_graph;

type
  TCancelReady = class
    Calls: Integer;
    procedure Observe(const AWork: TWorkProgress);
  end;

var
  Checks: Integer;

procedure Check(const ACondition: Boolean; const AMessage: String);
begin
  Inc(Checks);
  if not ACondition then
  begin
    raise EAudio.Create(AMessage);
  end;
end;

procedure TCancelReady.Observe(const AWork: TWorkProgress);
begin
  Inc(Calls);
  if AWork.Stage = 'instrumental_ready' then
  begin
    raise EAbort.Create('Expected final-ready cancellation');
  end;
end;

function NewGraph(const ARate: Integer): TBusGraph;
var
  LSettings: array[0..3] of TBusSettings;
  LIndex: Integer;
begin
  for LIndex := 0 to 3 do
  begin
    LSettings[LIndex] := DefaultBusSettings;
    LSettings[LIndex].SmoothingSeconds := 0;
  end;
  Result := TBusGraph.Create(ARate, LSettings);
  for LIndex := 0 to 2 do
  begin
    Result.AddSend(LIndex, 3, stPostFader, 1, 0);
  end;
  Result.AddEffect(3, TGainEffect.Create(ARate, 0.8, 0));
end;

function FirstLead(const APlan: TInstrumentalPlan): Integer;
var
  LNotes: TNoteSequence;
  LIndex: Integer;
begin
  Result := -1;
  LNotes := APlan.CopyNotes;
  try
    for LIndex := 0 to LNotes.NoteCount - 1 do
    begin
      if LNotes.GateAt(LIndex).Voice = 2 then
      begin
        Exit(LNotes.GateAt(LIndex).Pitch);
      end;
    end;
  finally
    LNotes.Free;
  end;
end;

function LeadToken(const AConfig: TWfcMusicVoicesGraphConfig;
  const APitch: Integer): String;
var
  LIndex: Integer;
  LFrame: TWfcMusicEnsembleFrame;
begin
  Result := '';
  for LIndex := 0 to AConfig.Voices[2].Model.PublicTokenCount - 1 do
  begin
    Result := AConfig.Voices[2].Model.PublicTokenAt(LIndex);
    LFrame := DecodeWfcMusicEnsembleFrame(Result);
    if (LFrame.Voices[0].Action = wmcaAttack) and
      (LFrame.Voices[0].Tones[0].Pitch = APitch) then
    begin
      Exit;
    end;
  end;
  raise EAudio.Create('Required authored lead alternative missing');
end;

procedure Run;
const
  CRate = 8000;
var
  LStarter: TInstrumentalStarter;
  LPlan: TInstrumentalPlan;
  LReplay: TInstrumentalPlan;
  LChanged: TInstrumentalPlan;
  LSaved: TInstrumentalPlan;
  LConfig: TWfcMusicVoicesGraphConfig;
  LOptions: TInstrumentalOptions;
  LReport: TInstrumentalReport;
  LMasks: TVoiceMasks;
  LGraph: TBusGraph;
  LOtherGraph: TBusGraph;
  LPlayer: TScheduledSynth;
  LOtherPlayer: TScheduledSynth;
  LNotes: TNoteSequence;
  LTones: TFrameTones;
  LPasses: TVoiceGraphPasses;
  LMusic: TWfcMusicVoicesGenerated;
  LOtherMusic: TWfcMusicVoicesGenerated;
  LObserver: TCancelReady;
  LModel: TWfcSequenceModel;
  LRole: Integer;
  LIndex: Integer;
  LCell: Integer;
  LPitch: Integer;
  LLeft: Double;
  LRight: Double;
  LOtherLeft: Double;
  LOtherRight: Double;
  LPeak: Double;
  LSum: Double;
  LClip: TAudioClip;
  LFrames: Integer;
  LOffset: Integer;
  LMaximumEnd: Int64;
  LRejected: Boolean;
begin
  LStarter := TInstrumentalStarter.Create;
  LPlan := nil;
  LReplay := nil;
  LChanged := nil;
  LGraph := nil;
  LOtherGraph := nil;
  LPlayer := nil;
  LOtherPlayer := nil;
  LNotes := nil;
  LClip := nil;
  LObserver := TCancelReady.Create;
  LModel := nil;
  try
    LConfig := LStarter.Config;
    LOptions := DefaultInstrumentalOptions;
    LOptions.Session.CellCount := 32;
    LOptions.Session.RequireObservedEnd := False;
    LOptions.SampleRate := CRate;
    LOptions.MaterialOrigin := 'Authored two-phrase starter, not recording-derived';
    SetLength(LOptions.Tempos, 2);
    LOptions.Tempos[0] := MakeTempoChange(0, 500001);
    LOptions.Tempos[1] := MakeTempoChange(16 * 240, 600001);
    LOptions.EffectTailFrames := 80;
    LMasks := LStarter.GuideMasks(32);
    if not TryCreateInstrumentalPlan(LConfig, LStarter.CopyRoles, LOptions, LMasks,
      nil, LPlan, LReport) then
    begin
      raise EAudio.Create('Actual instrumental solve: ' + LReport.Detail);
    end;
    Check(True, 'Actual instrumental solve');
    Check(LReport.Proof.Valid, 'Actual voice graph proof');
    Check(LPlan.RoleCount = 3, 'Three explicit instrument bindings');
    Check(LPlan.ToneCount > 20, 'Real multi-part plan');
    LPasses := LPlan.CopyGraph;
    Check(Length(LPasses) > 5, 'Actual coverage proof passes included');
    for LIndex := 0 to High(LPasses) do
    begin
      Check((LPasses[LIndex].Width = 32) and (LPasses[LIndex].Height = 1) and
        (LPasses[LIndex].Depth = 1), 'Actual pass dimensions');
      if (LIndex >= 2) and (LIndex < 5) then
      begin
        Check(Length(LPasses[LIndex].Dependencies) >= 2, 'Actual voice dependencies');
      end;
      for LCell := 0 to High(LPasses[LIndex].Dependencies) do
      begin
        Check(LPasses[LIndex].Dependencies[LCell] < LIndex, 'Actual topological order');
      end;
    end;
    LPasses[2].Dependencies[0] := -100;
    Check(LPlan.CopyGraph[2].Dependencies[0] >= 0, 'Detached graph inspection');
    LNotes := LPlan.CopyNotes;
    Check(LNotes.FrameAtTick(32 * 240, CRate) = 70400, 'Exact changing-tempo clock');
    LMaximumEnd := 70400;
    for LRole := 0 to 2 do
    begin
      LTones := LPlan.CopyPartTones(LRole);
      Check(Length(LTones) > 0, 'Every role sounds');
      for LIndex := 0 to High(LTones) do
      begin
        Check(LTones[LIndex].Voice.SourceFactory = nil, 'Source-free oscillators');
        LMaximumEnd := Max(LMaximumEnd, LTones[LIndex].StartFrame +
          LTones[LIndex].GateFrames + SynthReleaseFrames(LTones[LIndex].Voice, CRate));
      end;
    end;
    Check(LPlan.FrameCount = LMaximumEnd + 80, 'Release and explicit effect tails');
    Check(TryCreateInstrumentalPlan(LConfig, LStarter.CopyRoles, LOptions, LMasks,
      nil, LReplay, LReport), 'Same-seed replay solve');
    LMusic := LPlan.CopyMusic;
    LOtherMusic := LReplay.CopyMusic;
    for LRole := 0 to High(LMusic.Layers) do
    begin
      for LCell := 0 to High(LMusic.Layers[LRole].Tokens) do
      begin
        Check(LMusic.Layers[LRole].Tokens[LCell] = LOtherMusic.Layers[LRole].Tokens[LCell],
          'Model token replay');
      end;
    end;
    LGraph := NewGraph(CRate);
    LOtherGraph := NewGraph(CRate);
    LPlayer := LPlan.CreatePlayer(LGraph);
    LOtherPlayer := LReplay.CreatePlayer(LOtherGraph);
    LPeak := 0;
    LSum := 0;
    LOffset := 0;
    while LOffset < LPlan.FrameCount do
    begin
      LFrames := Min(997, LPlan.FrameCount - LOffset);
      LClip := RenderScheduledFrames(LOtherPlayer, LFrames);
      for LIndex := 0 to LFrames - 1 do
      begin
        LPlayer.Process(LLeft, LRight);
        LOtherLeft := LClip.SampleAt(LIndex, 0);
        LOtherRight := LClip.SampleAt(LIndex, 1);
        Check((Abs(LLeft - LOtherLeft) < 3E-8) and
          (Abs(LRight - LOtherRight) < 3E-8), 'Primary block/one-frame replay');
        LPeak := Max(LPeak, Max(Abs(LLeft), Abs(LRight)));
        LSum := LSum + LLeft * LLeft + LRight * LRight;
      end;
      FreeAndNil(LClip);
      Inc(LOffset, LFrames);
    end;
    Check((LPeak > 0.01) and (LPeak < 1), 'Audible bounded mix');
    Check((LPlayer.ActiveCount = 0) and (LPlayer.PendingCount = 0), 'All note releases drained');
    Check(Abs(LLeft) + Abs(LRight) < 1E-9, 'Silent final release tail');
    LPitch := 72;
    if FirstLead(LPlan) = LPitch then
    begin
      LPitch := 76;
    end;
    SetLength(LMasks[4], 1);
    LMasks[4][0] := MakeWfcSequenceTokenConstraint(0, [LeadToken(LConfig, LPitch)]);
    Check(TryCreateInstrumentalPlan(LConfig, LStarter.CopyRoles, LOptions, LMasks,
      nil, LChanged, LReport), 'Changed real musical constraint');
    Check(FirstLead(LChanged) = LPitch, 'Constraint reaches instrumental notes');
    Check(FirstLead(LChanged) <> FirstLead(LPlan), 'Changed output note');
    LSaved := LPlan;
    LMasks[0][0] := MakeWfcSequenceTokenConstraint(0,
      [EncodeWfcMusicPitchClassSet(MakeWfcMusicPitchClassSet(12, [0, 4, 7]))]);
    LMasks[4][0] := MakeWfcSequenceTokenConstraint(0, [LeadToken(LConfig, 81)]);
    Check(not TryCreateInstrumentalPlan(LConfig, LStarter.CopyRoles, LOptions,
      LMasks, nil, LPlan, LReport), 'Contradictory harmony/lead rejects');
    Check(LPlan = LSaved, 'Contradiction preserves previous plan');
    Check((LReport.FailedPass <> '') and (LReport.Detail <> ''), 'Actionable pass failure');
    try
      TryCreateInstrumentalPlan(LConfig, LStarter.CopyRoles, LOptions,
        LStarter.GuideMasks(32), nil,
        LPlan, LReport, LObserver.Observe);
      Check(False, 'Ready cancellation did not abort');
    except
      on EAbort do
      begin
        Check(LPlan = LSaved, 'Ready cancellation preserves previous plan');
      end;
    end;
    Check(LObserver.Calls > 0, 'Borrowed callback observed actual work');
    Check(LPlan.RoleAt(0).Instrument = nil, 'No retained instrument pointer');
    FreeAndNil(LStarter);
    LModel := LPlan.CopyModel('harmony');
    Check(LModel.PublicTokenCount > 0, 'Accepted models outlive source material');
    FreeAndNil(LModel);
    FreeAndNil(LPlayer);
    FreeAndNil(LOtherPlayer);
    FreeAndNil(LGraph);
    FreeAndNil(LOtherGraph);
    LGraph := NewGraph(CRate);
    LOtherGraph := NewGraph(CRate);
    LRejected := False;
    try
      LPlayer := LPlan.CreatePlayer(LGraph, 1);
    except
      on EAudio do
      begin
        LRejected := True;
        Check(not LGraph.Failed, 'Rejected admission preserves bus health');
      end;
    end;
    Check(LRejected, 'Voice capacity rejection');
    LPlayer := LPlan.CreatePlayer(LGraph);
    LOtherPlayer := LReplay.CreatePlayer(LOtherGraph);
    for LIndex := 0 to 999 do
    begin
      LPlayer.Process(LLeft, LRight);
      LOtherPlayer.Process(LOtherLeft, LOtherRight);
      Check((LLeft = LOtherLeft) and (LRight = LOtherRight),
        'Prior plan remains playable after failure/cancellation/source disposal');
    end;
    WriteLn('Instrumental runtime: ', Checks, ' checks; roles=3; passes=',
      Length(LPasses), '; frames=', LPlan.FrameCount, '; peak=',
      FloatToStrF(LPeak, ffFixed, 16, 9), '; energy=',
      FloatToStrF(LSum, ffFixed, 16, 9));
  finally
    LClip.Free;
    LNotes.Free;
    LPlayer.Free;
    LOtherPlayer.Free;
    LGraph.Free;
    LOtherGraph.Free;
    LPlan.Free;
    LReplay.Free;
    LChanged.Free;
    LObserver.Free;
    LModel.Free;
    LStarter.Free;
  end;
end;

begin
  Run;
end.
