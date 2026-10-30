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
program pythian_tests_percussion_wfc;

{$mode delphi}
{$H+}

uses
  SysUtils,
  Math,
  pythian.audio,
  pythian.time,
  pythian.synth,
  pythian.bus,
  pythian.schedule,
  pythian.progress,
  pythian.wfc.instrumental,
  pythian.wfc.instrumental.starter,
  pythian.wfc.percussion,
  pythian.wfc.layers,
  wfc,
  wfc_model,
  wfc_sequence,
  wfc_sequence_graph,
  wfc_music_voices_graph;

type
  TCancelPercussion = class
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

procedure TCancelPercussion.Observe(const AWork: TWorkProgress);
begin
  if AWork.Stage = 'percussion_ready' then
  begin
    raise EAbort.Create('Expected percussion-ready cancellation');
  end;
end;

function NewGraph(const ARate: Integer): TBusGraph;
var
  LSettings: array[0..6] of TBusSettings;
  LIndex: Integer;
begin
  for LIndex := 0 to 6 do
  begin
    LSettings[LIndex] := DefaultBusSettings;
    LSettings[LIndex].SmoothingSeconds := 0;
  end;
  Result := TBusGraph.Create(ARate, LSettings);
  for LIndex := 0 to 5 do
  begin
    Result.AddSend(LIndex, 6, stPostFader, 1, 0);
  end;
end;

procedure SamePitched(const ABefore, AAfter: TInstrumentalPlan);
var
  LBefore: TWfcMusicVoicesGenerated;
  LAfter: TWfcMusicVoicesGenerated;
  LPass: Integer;
  LCell: Integer;
begin
  LBefore := ABefore.CopyMusic;
  LAfter := AAfter.CopyMusic;
  Check(Length(LBefore.Layers) = Length(LAfter.Layers), 'Pitched provider count unchanged');
  for LPass := 0 to High(LBefore.Layers) do
  begin
    for LCell := 0 to High(LBefore.Layers[LPass].Tokens) do
    begin
      Check(LBefore.Layers[LPass].Tokens[LCell] = LAfter.Layers[LPass].Tokens[LCell],
        'Pitched tokens retained through drum changes');
      Check(LBefore.Layers[LPass].StateIndices[LCell] = LAfter.Layers[LPass].StateIndices[LCell],
        'Pitched latent states retained through drum changes');
    end;
  end;
end;

procedure Run;
const
  CRate = 8000;
var
  LStarter: TInstrumentalStarter;
  LBase: TInstrumentalPlan;
  LWithDrums: TInstrumentalPlan;
  LNoHat: TInstrumentalPlan;
  LSilentDrums: TInstrumentalPlan;
  LSaved: TInstrumentalPlan;
  LConfig: TWfcMusicVoicesGraphConfig;
  LOptions: TInstrumentalOptions;
  LReport: TInstrumentalReport;
  LDrums: TPercussionDefinitions;
  LGraphInfo: TLayerGraphPasses;
  LHits: TPercussionHits;
  LTokens: TWfcModelTokens;
  LMusic: TWfcMusicVoicesGenerated;
  LTones: TFrameTones;
  LGraph: TBusGraph;
  LPlayer: TScheduledSynth;
  LObserver: TCancelPercussion;
  LPart: Integer;
  LIndex: Integer;
  LProofs: Integer;
  LCounts: array[0..2] of Integer;
  LLeft: Double;
  LRight: Double;
  LPeak: Double;
  LRejected: Boolean;
begin
  LStarter := TInstrumentalStarter.Create;
  LBase := nil;
  LWithDrums := nil;
  LNoHat := nil;
  LSilentDrums := nil;
  LGraph := nil;
  LPlayer := nil;
  LObserver := TCancelPercussion.Create;
  try
    LOptions := DefaultInstrumentalOptions;
    LOptions.SampleRate := CRate;
    LOptions.MaterialOrigin := 'Authored pitched and unpitched experiment';
    LOptions.Session.CellCount := 32;
    LOptions.Session.RequireObservedEnd := False;
    LOptions.Tempos[0] := MakeTempoChange(0, 500001);
    LOptions.EffectTailFrames := 80;
    LConfig := LStarter.Config;
    Check(TryCreateInstrumentalPlan(LConfig, LStarter.CopyRoles, LOptions,
      LStarter.GuideMasks(32), nil, LBase, LReport), 'Retained pitched base');
    LDrums := LStarter.CopyPercussion(CRate);
    SetLength(LDrums[0].Constraints, 1);
    LDrums[0].Constraints[0] := MakeWfcSequenceTokenConstraint(0, [PercussionToken(110)]);
    SetLength(LDrums[1].Constraints, 1);
    LDrums[1].Constraints[0] := MakeWfcSequenceTokenConstraint(2, [PercussionToken(110)]);
    SetLength(LDrums[2].Constraints, 1);
    LDrums[2].Constraints[0] := MakeWfcSequenceTokenConstraint(0, [PercussionToken(100)]);
    if not TryCreateInstrumentalPlan(LConfig, LStarter.CopyRoles, LOptions,
      LStarter.GuideMasks(32), nil, LWithDrums, LReport, nil, LDrums) then
    begin
      raise EAudio.Create('Combined drum graph: ' + LReport.Detail);
    end;
    Check(LWithDrums.RoleCount = 6, 'Three pitched and three unpitched roles');
    SamePitched(LBase, LWithDrums);
    LGraphInfo := LWithDrums.CopyGraph;
    Check(Length(LGraphInfo) = 16, 'Twelve pitched and four percussion passes');
    Check((LGraphInfo[12].GroupIndex = 1) and
      (LGraphInfo[12].InputSourcePassIndex = 1), 'Explicit dependent-group input lineage');
    Check(Length(LGraphInfo[12].Dependencies) = 0, 'Input lineage is not a fabricated solver edge');
    LProofs := 0;
    for LIndex := 0 to High(LGraphInfo) do
    begin
      Inc(LProofs, Ord(LGraphInfo[LIndex].IsProof));
      Check((LGraphInfo[LIndex].Width = 32) and (LGraphInfo[LIndex].Height = 1) and
        (LGraphInfo[LIndex].Depth = 1), 'Actual aligned graph dimensions');
      if LIndex > 12 then
      begin
        Check((Length(LGraphInfo[LIndex].Dependencies) = 1) and
          (LGraphInfo[LIndex].Dependencies[0] = 12), 'Only rhythm constrains drum pass');
      end;
    end;
    Check(LProofs = 7, 'Drums create no harmonic-coverage obligation');
    LMusic := LWithDrums.CopyMusic;
    LTokens := LWithDrums.CopyPassTokens(12);
    for LIndex := 0 to High(LTokens) do
    begin
      Check(LTokens[LIndex] = LMusic.Layers[1].Tokens[LIndex], 'Exactly retained rhythm input');
    end;
    LHits := LWithDrums.CopyPercussionHits;
    for LPart := 0 to 2 do
    begin
      LCounts[LPart] := 0;
    end;
    for LIndex := 0 to High(LHits) do
    begin
      Inc(LCounts[LHits[LIndex].Part]);
      Check(LHits[LIndex].StartTick = LHits[LIndex].Cell * LOptions.Session.StepTicks,
        'Shared logical clock');
      Check(LHits[LIndex].GateFrames > 0, 'Physical hit gate');
    end;
    for LPart := 0 to 2 do
    begin
      Check(LCounts[LPart] > 0, 'Each drum has actual generated hits');
      Check(LWithDrums.RoleAt(LPart + 3).IsPercussion, 'Explicit unpitched role');
      LTones := LWithDrums.CopyPartTones(LPart + 3);
      Check(Length(LTones) > 0, 'Actual synthesized drum tones');
    end;
    LDrums[2].Enabled := False;
    LDrums[2].Constraints := nil;
    Check(TryCreateInstrumentalPlan(LConfig, LStarter.CopyRoles, LOptions,
      LStarter.GuideMasks(32), nil, LNoHat, LReport, nil, LDrums), 'Disabled hat graph');
    Check(Length(LNoHat.CopyPartTones(5)) = 0, 'Disabled hat generates silence');
    SamePitched(LWithDrums, LNoHat);
    LSaved := LNoHat;
    SetLength(LDrums[2].Constraints, 1);
    LDrums[2].Constraints[0] := MakeWfcSequenceTokenConstraint(0, [PercussionToken(100)]);
    LRejected := False;
    try
      TryCreateInstrumentalPlan(LConfig, LStarter.CopyRoles, LOptions,
        LStarter.GuideMasks(32), nil, LNoHat, LReport, nil, LDrums);
    except
      on EAudio do
      begin
        LRejected := True;
      end;
    end;
    Check(LRejected and (LNoHat = LSaved), 'Disabled hit lock is rejected, not erased');
    LDrums[2].Constraints := nil;
    LDrums[0].Enabled := False;
    LDrums[0].Constraints := nil;
    LDrums[1].Enabled := False;
    LDrums[1].Constraints := nil;
    Check(TryCreateInstrumentalPlan(LConfig, LStarter.CopyRoles, LOptions,
      LStarter.GuideMasks(32), nil, LSilentDrums, LReport, nil, LDrums), 'Silent drum graph');
    Check(Length(LSilentDrums.CopyPercussionHits) = 0, 'All disabled parts remain silent');
    SamePitched(LWithDrums, LSilentDrums);
    LSaved := LWithDrums;
    LDrums[1].Enabled := True;
    SetLength(LDrums[1].Constraints, 1);
    LDrums[1].Constraints[0] := MakeWfcSequenceTokenConstraint(0, [PercussionToken(110)]);
    Check(not TryCreateInstrumentalPlan(LConfig, LStarter.CopyRoles, LOptions,
      LStarter.GuideMasks(32), nil, LWithDrums, LReport, nil, LDrums),
      'Impossible snare/rhythm lock rejects');
    Check((LWithDrums = LSaved) and (LReport.FailedPass <> ''), 'Rejected group preserves prior plan');
    LDrums := LStarter.CopyPercussion(CRate);
    LRejected := False;
    try
      TryCreateInstrumentalPlan(LConfig, LStarter.CopyRoles, LOptions,
        LStarter.GuideMasks(32), nil, LWithDrums, LReport, LObserver.Observe, LDrums);
    except
      on EAbort do
      begin
        LRejected := True;
      end;
    end;
    Check(LRejected and (LWithDrums = LSaved), 'Percussion-ready cancellation is transactional');
    FreeAndNil(LStarter);
    LGraph := NewGraph(CRate);
    LPlayer := LWithDrums.CreatePlayer(LGraph);
    LPeak := 0;
    for LIndex := 0 to LWithDrums.FrameCount - 1 do
    begin
      LPlayer.Process(LLeft, LRight);
      LPeak := Max(LPeak, Max(Abs(LLeft), Abs(LRight)));
    end;
    Check((LPeak > 0.1) and (LPeak < 1), 'Audible bounded combined instrumental output');
    Check((LPlayer.ActiveCount = 0) and (LPlayer.PendingCount = 0), 'All drum/voice releases complete');
    WriteLn('WFC percussion: ', Checks, ' checks; six roles, sixteen actual passes in two groups; hits=',
      Length(LHits), '; peak=', FloatToStrF(LPeak, ffFixed, 16, 9));
  finally
    LPlayer.Free;
    LGraph.Free;
    LWithDrums.Free;
    LBase.Free;
    LNoHat.Free;
    LSilentDrums.Free;
    LStarter.Free;
    LObserver.Free;
  end;
end;

begin
  Run;
end.
