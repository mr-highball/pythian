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

program pythian_tests_material_instrumental;
{$mode delphi}
{$H+}

uses SysUtils, pythian.audio, pythian.progress, pythian.music.pattern, pythian.pitch.track,
  pythian.wfc.instrumental, pythian.wfc.instrumental.starter,
  pythian.wfc.percussion, pythian.wfc.voices, pythian.wfc.providers,
  pythian.wfc.provider.contracts, pythian.wfc.musical.context,
  wfc_model, wfc_sequence, wfc_music_voices_graph;

type
  TCancelProbe = class
    Stage: String;
    Calls: Integer;
    procedure Observe(const AProgress: TWorkProgress);
  end;

var
  Checks: Integer;

procedure Check(const ACondition: Boolean; const AMessage: String);
begin
  Inc(Checks);
  if not ACondition then raise EAudio.Create(AMessage);
end;

procedure TCancelProbe.Observe(const AProgress: TWorkProgress);
begin
  if AProgress.Stage = Stage then
  begin
    Inc(Calls);
    raise EAbort.Create('Requested material cancellation');
  end;
end;

procedure Run;
const
  CSeeds: array[0..2] of Cardinal = (0, 731, 2147483000);
var
  LSpans: TPitchSpans;
  LPattern: TPitchPattern;
  LStarter: TInstrumentalStarter;
  LPlan: TInstrumentalPlan;
  LReplay: TInstrumentalPlan;
  LOptions: TInstrumentalOptions;
  LReport: TInstrumentalReport;
  LDrums: TPercussionDefinitions;
  LMusic: TWfcMusicVoicesGenerated;
  LTokens, LOther: TWfcModelTokens;
  LGraph: TVoiceGraphPasses;
  LDescription: TStyleProviderDescription;
  LContract: TProviderContract;
  LModel: TWfcSequenceModel;
  LPrevious: TInstrumentalPlan;
  LMasks: TVoiceMasks;
  LProbe: TCancelProbe;
  LSeed: Cardinal;
  I, J: Integer;
  LFailed: Boolean;
begin
  SetLength(LSpans, 4);
  for I := 0 to 3 do
  begin
    LSpans[I] := Default(TPitchSpan);
    LSpans[I].StartFrame := I * 2000;
    LSpans[I].EndFrame := (I + 1) * 2000;
    LSpans[I].Note := -1;
  end;
  LSpans[0].Kind := pskPitch;
  LSpans[0].Note := 60;
  LSpans[0].StartFrame := 400;
  LSpans[1].Kind := pskUnknown;
  LSpans[2].Kind := pskSilence;
  LSpans[3].Kind := pskPitch;
  LSpans[3].Note := 62;
  LPattern := QuantizePitchPattern(LSpans, 8000, 8000, 500000);
  Check(Length(LPattern) = 4, 'Complete explicit eighth-note cells');
  Check((LPattern[0].Note = 60) and LPattern[0].Attack, 'Selected C and attack suggestion');
  Check((LPattern[1].Kind = pskUnknown) and (LPattern[1].Note = -1), 'Unknown stays unknown');
  Check(LPattern[2].Kind = pskSilence, 'Measured silence kept separate');
  Check((LPattern[3].Note = 62) and LPattern[3].Attack, 'Selected D after gap');
  LFailed := False;
  LSpans[1].StartFrame := 1000;
  try
    LPattern := QuantizePitchPattern(LSpans, 8000, 8000, 500000);
  except
    on E: EAudio do LFailed := True;
  end;
  Check(LFailed and (LPattern[1].Kind = pskUnknown), 'Bad source preserves accepted pattern');
  LStarter := TInstrumentalStarter.Create(0, False, LPattern, 2);
  LPlan := nil;
  LReplay := nil;
  try
    LOptions := DefaultInstrumentalOptions;
    LOptions.SampleRate := 8000;
    LOptions.Session.CellCount := 16;
    LOptions.Session.RequireObservedEnd := False;
    LOptions.MaterialOrigin := 'Operator accepted experimental lead motif and authored accompaniment';
    LDrums := LStarter.CopyPercussion(8000);
    Check(Length(LStarter.GuideMasks(16)) = 0, 'Pattern material uses the actual free coupled graph');
    if not TryCreateInstrumentalPlan(LStarter.Config, LStarter.CopyRoles, LOptions,
      nil, nil, LPlan, LReport, nil, LDrums, LStarter.ContextModel) then
      raise EAudio.Create('Pattern plan rejected: ' + LReport.Detail);
    Check(LPlan.RoleCount = 6, 'Actual source-free six-part instrumental plan');
    LMusic := LPlan.CopyMusic;
    Check(Length(LMusic.Frames) = 16, 'Generated complete musical cells');
    for I := 0 to High(LMusic.Frames) do
      for J := 0 to High(LMusic.Frames[I].Voices[2].Tones) do
        Check(LMusic.Frames[I].Voices[2].Tones[J].Pitch in [60, 62],
          'Accepted provider vocabulary reaches the actual lead');
    if not TryCreateInstrumentalPlan(LStarter.Config, LStarter.CopyRoles, LOptions,
      nil, nil, LReplay, LReport, nil, LDrums, LStarter.ContextModel) then
      raise EAudio.Create('Pattern replay rejected: ' + LReport.Detail);
    LGraph := LPlan.CopyGraph;
    Check((Length(LGraph) = 17) and (LGraph[0].Name = MusicalContextPassName),
      'Actual extra context pass, not a decorative graph');
    Check((LGraph[1].GroupIndex = 1) and (LGraph[2].GroupIndex = 1) and
      (LGraph[1].InputSourcePassIndex = 0) and (LGraph[2].InputSourcePassIndex = 0),
      'Both musical inputs bind the preceding paired context graph');
    Check(LGraph[High(LGraph)].GroupIndex = 2, 'Percussion is the third conditional group');
    LDescription := LPlan.CopyProvider(MusicalContextPassName);
    Check((LDescription.Vocabulary = spvMusicalContext) and
      (LDescription.Choices[0].Dimensions = [scdHarmony, scdRhythm]),
      'Actual paired semantic provider choices');
    LContract := ProviderContractFromDescription(LDescription, 'experimental-musical-context');
    LModel := LPlan.CopyModel(MusicalContextPassName);
    try
      ValidateProviderContract(LModel, LContract);
      Check(LModel.PublicTokenCount = Length(LDescription.Choices), 'Reusable provider contract');
    finally
      LModel.Free;
    end;
    for I := 0 to High(LGraph) do
    begin
      if LGraph[I].IsProof then Continue;
      LTokens := LPlan.CopyPassTokens(I);
      LOther := LReplay.CopyPassTokens(I);
      Check(Length(LTokens) = Length(LOther), 'Actual pass length replay');
      for J := 0 to High(LTokens) do
        Check(LTokens[J] = LOther[J], 'Exact provider replay');
    end;
    for LSeed in CSeeds do
    begin
      LOptions.Session.Seed := LSeed;
      Check(TryCreateInstrumentalPlan(LStarter.Config, LStarter.CopyRoles, LOptions,
        nil, nil, LReplay, LReport, nil, LDrums, LStarter.ContextModel),
        'Selected seed solves within original limits: ' + LReport.Detail);
      Check((LReport.Solve.PassBacktracks <= 32) and
        (LReport.ContextSolve.PassBacktracks <= 32), 'Declared bounded search retained');
    end;
    LPrevious := LReplay;
    SetLength(LMasks, 5);
    SetLength(LMasks[0], 1);
    LMasks[0][0] := MakeWfcSequenceTokenConstraint(0, nil);
    Check(not TryCreateInstrumentalPlan(LStarter.Config, LStarter.CopyRoles, LOptions,
      LMasks, nil, LReplay, LReport, nil, LDrums, LStarter.ContextModel),
      'Contradictory harmonic lock is not relaxed');
    Check(LReplay = LPrevious, 'Failed context preserves accepted musical plan');
    LProbe := TCancelProbe.Create;
    try
      for I := 0 to 1 do
      begin
        if I = 0 then LProbe.Stage := 'context_prepare_masks'
        else LProbe.Stage := 'instrumental_ready';
        LFailed := False;
        try
          TryCreateInstrumentalPlan(LStarter.Config, LStarter.CopyRoles, LOptions,
            nil, nil, LReplay, LReport, LProbe.Observe, LDrums, LStarter.ContextModel);
        except
          on E: EAbort do LFailed := True;
        end;
        Check(LFailed and (LReplay = LPrevious), 'Preparation/final cancellation preserves plan');
      end;
      Check(LProbe.Calls = 2, 'Both actual cancellation phases reached');
    finally
      LProbe.Free;
    end;
  finally
    LReplay.Free;
    LPlan.Free;
    LStarter.Free;
  end;
end;

begin
  Run;
  WriteLn('PASS musical material: ', Checks, ' checks');
end.
