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
program pythian_tests_pulse_events;

{$mode delphi}
{$H+}

uses
  SysUtils,
  pythian.audio,
  pythian.beat,
  pythian.beat.track,
  pythian.passage,
  pythian.pulse.events
  {$ifdef WFC_EVENT_CHECKS}
  , pythian.analysis,
  pythian.learning,
  pythian.wfc.events,
  pythian.wfc.generation,
  wfc,
  wfc_model,
  wfc_sequence
  {$endif}
  ;

procedure Check(const ACondition: Boolean; const AMessage: String);
begin
  if not ACondition then
  begin
    raise Exception.Create(AMessage);
  end;
end;

procedure MakeTrack(out ATrack: TBeatTrack; out AObservations: TBeatObservations);
const
  CFrames: array[0..7] of Integer = (100, 500, 900, 1300, 3300, 3700, 4100, 4500);
var
  LIndex: Integer;
begin
  ATrack := Default(TBeatTrack);
  SetLength(ATrack.Windows, 3);
  for LIndex := 0 to 2 do
  begin
    ATrack.Windows[LIndex].OwnerStartFrame := LIndex * 1600;
    ATrack.Windows[LIndex].OwnerEndFrame := (LIndex + 1) * 1600;
    ATrack.Windows[LIndex].SelectedCandidate := -1;
    if LIndex <> 1 then
    begin
      SetLength(ATrack.Windows[LIndex].Analysis.Candidates, 1);
      ATrack.Windows[LIndex].Analysis.Candidates[0].PeriodFrames := 400;
      ATrack.Windows[LIndex].SelectedCandidate := 0;
      ATrack.Windows[LIndex].StartsNewPath := True;
    end;
  end;
  SetLength(ATrack.Frames, 8);
  SetLength(ATrack.GridFrames, 8);
  SetLength(ATrack.FrameWindows, 8);
  SetLength(ATrack.ObservationIndices, 8);
  SetLength(AObservations, 8);
  for LIndex := 0 to 7 do
  begin
    ATrack.Frames[LIndex] := CFrames[LIndex];
    ATrack.GridFrames[LIndex] := CFrames[LIndex];
    ATrack.FrameWindows[LIndex] := (LIndex div 4) * 2;
    ATrack.ObservationIndices[LIndex] := LIndex;
    AObservations[LIndex].Frame := CFrames[LIndex];
    AObservations[LIndex].Weight := 1;
  end;
end;

procedure CheckAdmission;
var
  LTrack: TBeatTrack;
  LObservations: TBeatObservations;
  LPlan: TPulseEventPlan;
  LOptions: TPulseEventOptions;
  LRejected: Boolean;
begin
  MakeTrack(LTrack, LObservations);
  LOptions := DefaultPulseEventOptions;
  LPlan := PlanPulseEvents(LTrack, LObservations, 4800, LOptions);
  Check((LPlan.SelectedCount = 6) and (LPlan.RunCount = 2) and
    (LPlan.Decisions[3] = pedPathBreak) and (LPlan.RunIndices[3] = -1) and
    (LPlan.RunIndices[2] = 0) and (LPlan.RunIndices[4] = 1),
    'A missing tracking window creates independent runs and excludes the gap');
  Check((LPlan.Bounds[0] = 100) and (LPlan.Bounds[7] = 4500),
    'No unobserved source prefix or suffix becomes a pulse interval');
  LPlan.Bounds[0] := 77;
  Check(LTrack.Frames[0] = 100, 'Returned plan owns its boundaries');
  LTrack.ObservationIndices[1] := 0;
  LRejected := False;
  try
    LPlan := PlanPulseEvents(LTrack, LObservations, 4800, LOptions);
  except
    on EAudio do
    begin
      LRejected := True;
    end;
  end;
  Check(LRejected and (LPlan.Bounds[0] = 77),
    'Invalid source observation identity preserves the previous result');

  MakeTrack(LTrack, LObservations);
  LTrack.Windows[2].StartsNewPath := False;
  LPlan := PlanPulseEvents(LTrack, LObservations, 4800, LOptions);
  Check(LPlan.Decisions[3] = pedPathBreak, 'Missing window is a break even without restart flag');
  SetLength(LTrack.Windows[1].Analysis.Candidates, 1);
  LTrack.Windows[1].Analysis.Candidates[0].PeriodFrames := 400;
  LTrack.Windows[1].SelectedCandidate := 0;
  LTrack.Windows[1].JoinUncertain := True;
  LPlan := PlanPulseEvents(LTrack, LObservations, 4800, LOptions);
  Check(LPlan.Decisions[3] = pedUncertainJoin,
    'Uncertain join in a skipped point-owner window remains an exclusion');

  MakeTrack(LTrack, LObservations);
  LTrack.Frames[1] := 250;
  LObservations[1].Frame := 250;
  LTrack.Frames[2] := 950;
  LObservations[2].Frame := 950;
  LPlan := PlanPulseEvents(LTrack, LObservations, 4800, LOptions);
  Check((LPlan.Decisions[0] = pedDuration) and (LPlan.Decisions[1] = pedDuration) and
    (LPlan.Decisions[2] = pedSelected) and (LTrack.SeamIssues = 0),
    'Final short/long aligned intervals are checked independently of raw seam flags');

  MakeTrack(LTrack, LObservations);
  LTrack.ObservationIndices[1] := -1;
  LPlan := PlanPulseEvents(LTrack, LObservations, 4800, LOptions);
  Check((LPlan.Decisions[0] = pedUnaligned) and (LPlan.Decisions[1] = pedUnaligned),
    'Both endpoints need source evidence under the default policy');
  LOptions.RequireAlignedEndpoints := False;
  LPlan := PlanPulseEvents(LTrack, LObservations, 4800, LOptions);
  Check(LPlan.SelectedCount = 6, 'Explicit predicted-endpoint opt-in');
  LTrack.Frames := nil;
  LTrack.GridFrames := nil;
  LTrack.FrameWindows := nil;
  LTrack.ObservationIndices := nil;
  LPlan := PlanPulseEvents(LTrack, LObservations, 4800, LOptions);
  Check((Length(LPlan.Bounds) = 0) and (LPlan.SelectedCount = 0) and (LPlan.RunCount = 0),
    'No pulses yield no invented training intervals');
end;

{$ifdef WFC_EVENT_CHECKS}
procedure CheckLearning;
var
  LTrack: TBeatTrack;
  LObservations: TBeatObservations;
  LPlan: TPulseEventPlan;
  LFeatures: TAudioFeatures;
  LPalette: TAcousticPalette;
  LSplitModel: TWfcSequenceModel;
  LFlatModel: TWfcSequenceModel;
  LSymbols: TAcousticEventSymbols;
  LTraining: TAcousticEventCorpus;
  LFlat: TAcousticEventCorpus;
  LConstraints: TWfcSequenceTokenConstraints;
  LOptions: TAcousticGenerationOptions;
  LReport: TGraphSolveReport;
  LGenerated: TWfcModelTokens;
  LIndex: Integer;
  LRejected: Boolean;
begin
  MakeTrack(LTrack, LObservations);
  LPlan := PlanPulseEvents(LTrack, LObservations, 4800, DefaultPulseEventOptions);
  SetLength(LFeatures, 2);
  LFeatures[0].Rms := 0.1;
  LFeatures[0].Chroma[0] := 1;
  LFeatures[1].Rms := 0.4;
  LFeatures[1].Chroma[7] := 1;
  LPalette := TAcousticPalette.Create(LFeatures, 2);
  LSplitModel := nil;
  LFlatModel := nil;
  try
    SetLength(LSymbols, 7);
    for LIndex := 0 to 6 do
    begin
      if LIndex <> 3 then
      begin
        LSymbols[LIndex] := AcousticEventSymbol(LIndex div 4, 400, 400, True);
      end;
    end;
    LTraining := PartitionAcousticEvents(LSymbols, LPlan.RunIndices);
    Check((Length(LTraining) = 2) and (Length(LTraining[0]) = 3) and
      (Length(LTraining[1]) = 3), 'Gap is omitted and runs remain separate training samples');
    LSplitModel := LearnAcousticEventModel(LTraining, LPalette, 2);
    SetLength(LFlat, 1);
    SetLength(LFlat[0], 6);
    for LIndex := 0 to 2 do
    begin
      LFlat[0][LIndex] := LTraining[0][LIndex];
      LFlat[0][LIndex + 3] := LTraining[1][LIndex];
    end;
    LFlatModel := LearnAcousticEventModel(LFlat, LPalette, 2);
    SetLength(LConstraints, 3);
    for LIndex := 0 to 2 do
    begin
      LConstraints[LIndex].Position := LIndex;
      SetLength(LConstraints[LIndex].AllowedTokens, 1);
      LConstraints[LIndex].AllowedTokens[0] :=
        AcousticEventToken(LSymbols[(LIndex div 2) * 4]);
    end;
    LOptions := DefaultAcousticGenerationOptions;
    LOptions.FrameCount := 3;
    LOptions.Seed := 731;
    LOptions.Extent := wseFragment;
    Check(TryGenerateTokenSequence(LFlatModel, LOptions, LConstraints, LGenerated, LReport),
      'Control: flattening runs teaches the artificial A,A,B transition');
    Check(not TryGenerateTokenSequence(LSplitModel, LOptions, LConstraints, LGenerated, LReport),
      'Actual WFC cannot cross the excluded source gap in the split model');
    Check(LGenerated[2] = LConstraints[2].AllowedTokens[0], 'Failed solve preserves prior tokens');
    LPlan.RunIndices[4] := 0;
    LRejected := False;
    try
      LTraining := PartitionAcousticEvents(LSymbols, LPlan.RunIndices);
    except
      on EAudio do
      begin
        LRejected := True;
      end;
    end;
    Check(LRejected and (Length(LTraining) = 2), 'A run cannot resume across an excluded interval');
  finally
    LFlatModel.Free;
    LSplitModel.Free;
    LPalette.Free;
  end;
end;
{$endif}

begin
  try
    CheckAdmission;
    {$ifdef WFC_EVENT_CHECKS}
    CheckLearning;
    {$endif}
    WriteLn('Pulse events: final interval admission, gaps, provenance, ownership and enabled WFC checks pass');
  except
    on LException: Exception do
    begin
      WriteLn(StdErr, LException.ClassName, ': ', LException.Message);
      Halt(1);
    end;
  end;
end.

