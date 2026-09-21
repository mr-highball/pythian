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
program pythian_tests_events;

{$mode delphi}
{$H+}

uses
  SysUtils,
  pythian.audio,
  pythian.onset,
  pythian.onset.events,
  pythian.passage
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

procedure CheckPlan;
const
  CFrames: array[0..8] of Integer = (900, 150, 153, 150, 990, -1, 500, 700, 50);
var
  LLocations: TOnsetLocations;
  LOptions: TOnsetEventOptions;
  LPlan: TOnsetEventPlan;
  LSource: TAudioClip;
  LOutput: TAudioClip;
  LSamples: TAudioSamples;
  LIndices: TPassageIndices;
  LIndex: Integer;
  LRejected: Boolean;
begin
  SetLength(LLocations, Length(CFrames));
  for LIndex := 0 to High(LLocations) do
  begin
    LLocations[LIndex].WindowStartFrame := 0;
    LLocations[LIndex].WindowFrameCount := 1000;
    LLocations[LIndex].Frame := CFrames[LIndex];
    LLocations[LIndex].Resolved := CFrames[LIndex] >= 0;
  end;
  LLocations[6].ContextClipped := True;
  LLocations[7].SearchBoundary := True;
  LOptions := DefaultOnsetEventOptions(8000);
  LOptions.MinimumFrames := 20;
  LPlan := PlanOnsetEvents(LLocations, 1000, LOptions);
  Check((Length(LPlan.Bounds) = 5) and (LPlan.Bounds[0] = 0) and
    (LPlan.Bounds[1] = 50) and (LPlan.Bounds[2] = 150) and
    (LPlan.Bounds[3] = 900) and (LPlan.Bounds[4] = 1000), 'Sorted complete partition');
  Check((LPlan.LocationIndices[0] = -1) and (LPlan.LocationIndices[1] = 8) and
    (LPlan.LocationIndices[2] = 1) and (LPlan.LocationIndices[3] = 0) and
    (LPlan.LocationIndices[4] = -1), 'Original location identity and synthetic endpoints');
  Check((LPlan.Decisions[2] = oedTooClose) and (LPlan.Decisions[3] = oedDuplicate) and
    (LPlan.Decisions[4] = oedNearEndpoint) and (LPlan.Decisions[5] = oedUnresolved) and
    (LPlan.Decisions[6] = oedClippedContext) and
    (LPlan.Decisions[7] = oedSearchBoundary), 'Explicit exclusion decisions');

  SetLength(LSamples, 2000);
  for LIndex := 0 to High(LSamples) do
  begin
    LSamples[LIndex] := (LIndex - 1000) / 2000;
  end;
  LSource := TAudioClip.Create(8000, 2, LSamples);
  try
    LIndices := TPassageIndices.Create(0, 1, 2, 3);
    LOutput := RenderPassages(LSource, LPlan.Bounds, LIndices, 0);
    try
      Check(LOutput.FrameCount = 1000, 'Unequal intervals preserve source duration');
      for LIndex := 0 to High(LSamples) do
      begin
        Check(LOutput.SampleAt(LIndex div 2, LIndex mod 2) = LSamples[LIndex],
          'Complete onset partition preserves every stereo sample');
      end;
    finally
      LOutput.Free;
    end;
  finally
    LSource.Free;
  end;

  LPlan.Bounds[1] := 77;
  LLocations[0].Frame := 1000;
  LRejected := False;
  try
    LPlan := PlanOnsetEvents(LLocations, 1000, LOptions);
  except
    on EAudio do
    begin
      LRejected := True;
    end;
  end;
  Check(LRejected and (LPlan.Bounds[1] = 77), 'Invalid location preserves prior managed plan');
  LLocations[0].Frame := 900;
  LOptions.AllowClippedContext := True;
  LOptions.AllowSearchBoundary := True;
  LPlan := PlanOnsetEvents(LLocations, 1000, LOptions);
  Check((Length(LPlan.Bounds) = 7) and (LPlan.Bounds[1] = 50) and
    (LPlan.Bounds[3] = 500) and (LPlan.Bounds[4] = 700), 'Explicit edge-policy opt-in');
  LLocations := nil;
  LPlan := PlanOnsetEvents(LLocations, 10, LOptions);
  Check((Length(LPlan.Bounds) = 2) and (LPlan.Bounds[1] = 10),
    'No candidates retain a complete source shorter than the minimum interval');
end;

{$ifdef WFC_EVENT_CHECKS}
procedure CheckLearning;
var
  LFeatures: TAudioFeatures;
  LPalette: TAcousticPalette;
  LModel: TWfcSequenceModel;
  LTraining: TAcousticEventCorpus;
  LSymbol: TAcousticEventSymbol;
  LA: String;
  LB: String;
  LGenerated: TWfcModelTokens;
  LConstraints: TWfcSequenceTokenConstraints;
  LOptions: TAcousticGenerationOptions;
  LReport: TGraphSolveReport;
  LIndex: Integer;
  LRejected: Boolean;
begin
  SetLength(LFeatures, 2);
  LFeatures[0].Rms := 0.1;
  LFeatures[0].Chroma[0] := 1;
  LFeatures[1].Rms := 0.2;
  LFeatures[1].Chroma[7] := 1;
  LPalette := TAcousticPalette.Create(LFeatures, 2);
  LModel := nil;
  try
    SetLength(LTraining, 1);
    SetLength(LTraining[0], 8);
    for LIndex := 0 to 7 do
    begin
      LTraining[0][LIndex] := AcousticEventSymbol(LIndex mod 2,
        100 + (LIndex mod 2) * 100, 100, True);
    end;
    LA := AcousticEventToken(LTraining[0][0]);
    LB := AcousticEventToken(LTraining[0][1]);
    Check((LA = 'pythian.event.v1.0.1.1') and (LB = 'pythian.event.v1.1.2.1'),
      'Canonical acoustic/duration/onset joint tokens');
    LSymbol := AcousticEventSymbol(0, 150, 100, False);
    Check((LSymbol.DurationClass = 2) and not LSymbol.StartsAtOnset, 'Half-quantum tie upward');
    LSymbol := ParseAcousticEventToken(LB);
    Check((LSymbol.AcousticIndex = 1) and (LSymbol.DurationClass = 2) and
      LSymbol.StartsAtOnset, 'Canonical token round trip');
    LRejected := False;
    try
      ParseAcousticEventToken('pythian.event.v1.01.2.1');
    except
      on EAudio do
      begin
        LRejected := True;
      end;
    end;
    Check(LRejected, 'Noncanonical event token rejected');

    LModel := LearnAcousticEventModel(LTraining, LPalette, 2);
    LOptions := DefaultAcousticGenerationOptions;
    LOptions.FrameCount := 10;
    LOptions.Extent := wseWhole;
    LConstraints := nil;
    Check(TryGenerateTokenSequence(LModel, LOptions, LConstraints, LGenerated, LReport),
      'Actual order-2 event model generates a complete alternating path');
    for LIndex := 0 to High(LGenerated) do
    begin
      if LIndex mod 2 = 0 then
      begin
        Check(LGenerated[LIndex] = LA, 'Observed acoustic/duration pair A');
      end
      else
      begin
        Check(LGenerated[LIndex] = LB, 'Observed acoustic/duration pair B');
      end;
    end;
    SetLength(LConstraints, 1);
    LConstraints[0].Position := 1;
    SetLength(LConstraints[0].AllowedTokens, 1);
    Check(LModel.FindPublicToken(AcousticEventToken(AcousticEventSymbol(0, 200, 100, True))) < 0,
      'Unobserved acoustic/duration combinations are absent from the model');
    LConstraints[0].AllowedTokens[0] := LA;
    Check(not TryGenerateTokenSequence(LModel, LOptions, LConstraints, LGenerated, LReport),
      'A known event at an incompatible position contradicts the actual model');
    Check((Length(LGenerated) = 10) and (LGenerated[1] = LB), 'Failure preserves prior tokens');
    LTraining[0][0].AcousticIndex := 31;
    LRejected := False;
    try
      LearnAcousticEventModel(LTraining, LPalette, 2).Free;
    except
      on EAudio do
      begin
        LRejected := True;
      end;
    end;
    Check(LRejected, 'Training outside the shared palette rejected');
    Check(LModel.PublicTokenCount = 2, 'Caller mutation cannot change the learned model');
  finally
    LModel.Free;
    LPalette.Free;
  end;
end;
{$endif}

begin
  try
    CheckPlan;
    {$ifdef WFC_EVENT_CHECKS}
    CheckLearning;
    {$endif}
    WriteLn('Onset events: boundary decisions, exact source coverage, ownership and enabled WFC checks pass');
  except
    on LException: Exception do
    begin
      WriteLn(StdErr, LException.ClassName, ': ', LException.Message);
      Halt(1);
    end;
  end;
end.
