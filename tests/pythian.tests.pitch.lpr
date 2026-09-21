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

program pythian_tests_pitch;

{$mode delphi}
{$H+}

uses
  Classes,
  SysUtils,
  Math,
  pythian.audio,
  pythian.time,
  pythian.music.grid.frames,
  pythian.pitch,
  pythian.pitch.cells,
  pythian.pitch.track,
  pythian.pitch.evaluate,
  pythian.pitch.regions,
  pythian.wave;

procedure Check(const ACondition: Boolean; const AMessage: String);
begin
  if not ACondition then
  begin
    raise EAudio.Create(AMessage);
  end;
end;

function Signal(const AFrequency: Double; const AKind: Integer): TAudioSamples;
var
  LIndex: Integer;
  LPhase: Double;
  LRandom: Cardinal;
  LResult: TAudioSamples;
begin
  SetLength(LResult, 1024);
  LRandom := 731;
  for LIndex := 0 to High(LResult) do
  begin
    LPhase := 2 * Pi * AFrequency * LIndex / 8000;
    case AKind of
      0:
      begin
        LResult[LIndex] := 0.4 * Sin(LPhase);
      end;
      1:
      begin
        LResult[LIndex] := 0.35 * Sin(LPhase) + 0.8 * Sin(2 * LPhase);
      end;
      2:
      begin
        LResult[LIndex] := 0.4 * Sin(2 * LPhase) + 0.4 * Sin(3 * LPhase);
      end;
      3:
      begin
        LResult[LIndex] := 0.3 + 0.15 * Sin(LPhase);
      end;
      4:
      begin
        LResult[LIndex] := 0.3;
      end;
      else
      begin
        LRandom := Cardinal((QWord(LRandom) * 1664525 + 1013904223) and $FFFFFFFF);
        LResult[LIndex] := (LRandom / 4294967296.0 - 0.5) * 0.8;
      end;
    end;
  end;
  Result := LResult;
end;

procedure Run;
const
  CFrequencies: array[0..3] of Double = (110, 220, 445, 880);
var
  LOptions: TPitchOptions;
  LEstimate: TPitchEstimate;
  LOther: TPitchEstimate;
  LSamples: TAudioSamples;
  LStereo: TAudioSamples;
  LFrequency: Double;
  LKind: Integer;
  LIndex: Integer;
  LRejected: Boolean;
  LMaximumError: Double;
begin
  LOptions := DefaultPitchOptions;
  LMaximumError := 0;
  for LFrequency in CFrequencies do
  begin
    for LKind := 0 to 3 do
    begin
      LSamples := Signal(LFrequency, LKind);
      LEstimate := EstimatePitch(LSamples, 8000, 1, 0, LOptions);
      Check(LEstimate.Status = psEstimated, 'Known periodic waveform admitted');
      LMaximumError := Max(LMaximumError, Abs(1200 * Log2(LEstimate.FrequencyHz / LFrequency)));
      Check(Abs(1200 * Log2(LEstimate.FrequencyHz / LFrequency)) < 6,
        'Fundamental estimate within six cents, including missing/dominant harmonics');
      LOther := EstimatePitchCentered(LSamples, 8000, 1, 0, LOptions);
      Check((LOther.Status = psEstimated) and
        (Abs(1200 * Log2(LOther.FrequencyHz / LFrequency)) < 6),
        'Centered integration retains supported stationary harmonic/range controls');
    end;
  end;
  LSamples := Signal(445, 0);
  LEstimate := EstimatePitch(LSamples, 8000, 1, 0, LOptions);
  Check((AdmitPitchNote(LEstimate, 25) = 69) and (AdmitPitchNote(LEstimate, 10) = -1),
    'Tuning tolerance retains an explicit unknown');
  SetLength(LStereo, Length(LSamples) * 2);
  for LIndex := 0 to High(LSamples) do
  begin
    LStereo[LIndex * 2] := LSamples[LIndex];
    LStereo[LIndex * 2 + 1] := -LSamples[LIndex];
  end;
  LEstimate := EstimatePitch(LStereo, 8000, 2, 0, LOptions);
  LOther := EstimatePitch(LStereo, 8000, 2, 1, LOptions);
  Check(LEstimate.FrequencyHz = LOther.FrequencyHz, 'Explicit stereo channel avoids downmix cancellation');
  LEstimate := EstimatePitch(Signal(220, 4), 8000, 1, 0, LOptions);
  Check((LEstimate.Status = psSilence) and (AdmitPitchNote(LEstimate, 25) = -1),
    'DC is not a pitched note');
  LEstimate := EstimatePitch(Signal(220, 5), 8000, 1, 0, LOptions);
  Check((LEstimate.Status = psNoPeriod) and (LEstimate.FrequencyHz = 0),
    'Weak noisy estimate does not force a pitch');
  LOther := LEstimate;
  SetLength(LSamples, 16);
  LRejected := False;
  try
    LEstimate := EstimatePitch(LSamples, 8000, 1, 0, LOptions);
  except
    on EAudio do
    begin
      LRejected := True;
    end;
  end;
  Check(LRejected and (LEstimate.Status = LOther.Status), 'Insufficient range coverage preserves prior result');
  WriteLn('Periodic pitch, harmonic ambiguity fixtures, tuning, stereo and unknowns pass; max cents error ',
    LMaximumError:0:6);
end;

procedure CheckCentered;
var
  LSamples: TAudioSamples;
  LReverse: TAudioSamples;
  LStereo: TAudioSamples;
  LEstimate: TPitchEstimate;
  LOther: TPitchEstimate;
  LPrefix: TPitchEstimate;
  LFrames: Integer;
  LDirection: Integer;
  LFrame: Integer;
  LTime: Double;
  LPhase: Double;
  LExpected: Double;
  LMaximumCents: Double;
  LRejected: Boolean;
begin
  LMaximumCents := 0;
  for LFrames := 512 to 513 do
  begin
    SetLength(LSamples, LFrames);
    SetLength(LReverse, LFrames);
    for LDirection := -1 to 1 do
    begin
      for LFrame := 0 to LFrames - 1 do
      begin
        LTime := (900 + LFrame) / 8000;
        LPhase := 0.71 + 2 * Pi * (220 * LTime + 0.5 * LDirection * 156.25 * Sqr(LTime));
        LSamples[LFrame] := 0.2 * Sin(LPhase) + 0.1 * Sin(2 * LPhase) +
          0.05 * Sin(3 * LPhase);
      end;
      LEstimate := EstimatePitchCentered(LSamples, 8000, 1, 0, DefaultPitchOptions);
      ValidatePitchEstimate(LEstimate, 8000, DefaultPitchOptions);
      Check(LEstimate.Status = psEstimated, 'Centered stationary/up/down chirp is periodic');
      LExpected := 220 + LDirection * 156.25 * (900 + (LFrames - 1) / 2) / 8000;
      LMaximumCents := Max(LMaximumCents, Abs(1200 * Log2(LEstimate.FrequencyHz / LExpected)));
      Check(Abs(1200 * Log2(LEstimate.FrequencyHz / LExpected)) < 3,
        'Centered chirp measurement agrees with analytic center frequency within three cents');
      LPrefix := EstimatePitch(LSamples, 8000, 1, 0, DefaultPitchOptions);
      if LDirection <> 0 then
      begin
        Check(Abs(LPrefix.FrequencyHz - LExpected) > 1,
          'Prefix control exposes timing bias against the same center reference');
      end;
      for LFrame := 0 to LFrames - 1 do
      begin
        LReverse[LFrame] := LSamples[LFrames - 1 - LFrame];
      end;
      LOther := EstimatePitchCentered(LReverse, 8000, 1, 0, DefaultPitchOptions);
      Check((LOther.Status = LEstimate.Status) and
        (Abs(LOther.FrequencyHz - LEstimate.FrequencyHz) < 1E-9) and
        (Abs(LOther.NormalizedDifference - LEstimate.NormalizedDifference) < 1E-12),
        'Time reversal preserves centered periodic evidence for even and odd windows');
    end;
  end;
  SetLength(LStereo, Length(LSamples) * 2);
  for LFrame := 0 to High(LSamples) do
  begin
    LStereo[2 * LFrame] := 0.1 + 0.5 * LSamples[LFrame];
    LStereo[2 * LFrame + 1] := -LSamples[LFrame];
  end;
  LOther := EstimatePitchCentered(LStereo, 8000, 2, 0, DefaultPitchOptions);
  Check(Abs(LOther.FrequencyHz - LEstimate.FrequencyHz) < 1E-4,
    'Centered frequency is independent of DC and nonzero gain');
  LOther := EstimatePitchCentered(LStereo, 8000, 2, 1, DefaultPitchOptions);
  Check(Abs(LOther.FrequencyHz - LEstimate.FrequencyHz) < 1E-9,
    'Centered measurement keeps explicit stereo channel selection');
  LEstimate := EstimatePitchCentered(Signal(220, 4), 8000, 1, 0, DefaultPitchOptions);
  Check(LEstimate.Status = psSilence, 'Centered DC-only source remains silence');
  LEstimate := EstimatePitchCentered(Signal(220, 5), 8000, 1, 0, DefaultPitchOptions);
  Check(LEstimate.Status = psNoPeriod, 'Centered noise remains unadmitted');
  LEstimate := EstimatePitchCentered(Copy(Signal(220, 0), 0, 294),
    8000, 1, 0, DefaultPitchOptions);
  Check((LEstimate.Status = psEstimated) and (Abs(LEstimate.FrequencyHz - 220) < 1),
    'Minimum valid centered window includes the largest lag and interpolation neighbor');
  LOther := LEstimate;
  LRejected := False;
  try
    LEstimate := EstimatePitchCentered(Copy(LSamples, 0, 16), 8000, 1, 0, DefaultPitchOptions);
  except
    on EAudio do
    begin
      LRejected := True;
    end;
  end;
  Check(LRejected and (LEstimate.Status = LOther.Status),
    'Centered invalid geometry preserves prior estimate');
  WriteLn('Centered pitch: analytic center, time reversal, stereo/DC/gain and unknowns pass; max cents ',
    LMaximumCents:0:6);
end;

procedure CheckBoundaryContext;
var
  LEvidence: TPitchTrackEvidence;
  LTrack: TPitchTrack;
  LOptions: TPitchBoundaryOptions;
  LSummary: TPitchBoundarySummary;
  LOther: TPitchBoundarySummary;
  LLower: TPitchEstimate;
  LUpper: TPitchEstimate;
  LSilence: TPitchEstimate;
  LZeros: TAudioSamples;
  LRejected: Boolean;
  I: Integer;
begin
  LEvidence := Default(TPitchTrackEvidence);
  LEvidence.WindowFrames := 294;
  LEvidence.Options := DefaultPitchTrackOptions(8000);
  SetLength(LEvidence.Estimates, 40);
  LLower := EstimatePitch(Signal(220, 0), 8000, 1, 0, LEvidence.Options.Pitch);
  LUpper := EstimatePitch(Signal(440, 0), 8000, 1, 0, LEvidence.Options.Pitch);
  SetLength(LZeros, 294);
  LSilence := EstimatePitch(LZeros, 8000, 1, 0, LEvidence.Options.Pitch);
  for I := 0 to 39 do
  begin
    LEvidence.Estimates[I] := LLower;
    if I >= 20 then
    begin
      LEvidence.Estimates[I] := LUpper;
    end;
  end;
  LOptions := DefaultPitchBoundaryOptions(8000);
  Check((LOptions.ContextFrames = 640) and (LOptions.GapFrames = 160),
    'Boundary context defaults retain the declared physical windows');
  LTrack := TPitchTrack.CreateFromEvidence(LEvidence, 8000, 1, 3414);
  try
    LSummary := SummarizePitchBoundary(LTrack, 1747, LOptions);
    Check(LSummary.CompleteContext and LSummary.Qualified and
      (LSummary.Left.Note = 57) and (LSummary.Right.Note = 69) and
      (LSummary.Left.WindowCount = 6) and (LSummary.Right.WindowCount = 6) and
      (LSummary.LocalWindows = 5) and (LSummary.UnresolvedWindows = 0),
      'Known pitch change qualifies with half-open sides and inclusive gap endpoints');
    LSummary.Left.Votes[0].EnergyShare := 0;
    LOther := SummarizePitchBoundary(LTrack, 1747, LOptions);
    Check((LOther.Left.Votes[0].EnergyShare = 1) and
      (LTrack.EstimateAt(0).NearestMidi = 57), 'Boundary evidence is detached and preserves its track');
    LSummary := SummarizePitchBoundary(LTrack, 0, LOptions);
    Check(not LSummary.CompleteContext and not LSummary.Qualified and
      (LSummary.Left.Note = -1) and (LSummary.Right.Note = -1) and
      (Length(LSummary.Left.Votes) = 0), 'Missing outer context remains explicitly unknown');
    LSummary := SummarizePitchBoundary(LTrack, LTrack.FrameCount, LOptions);
    Check(not LSummary.CompleteContext, 'Clip endpoint is a valid incomplete query');
    LOptions.GapFrames := 0;
    LSummary := SummarizePitchBoundary(LTrack, 1747, LOptions);
    Check(LSummary.Qualified and (LSummary.LocalWindows = 1),
      'Zero inner gap uses the exact central window and distinct half-open sides');
    LOptions := DefaultPitchBoundaryOptions(8000);
    LOptions.Regions.MinimumPeriodicWindows := 7;
    LSummary := SummarizePitchBoundary(LTrack, 1747, LOptions);
    Check(not LSummary.Qualified and (LSummary.Left.Decision = prdInsufficientPeriodicity),
      'Caller region policy controls side admission');
    LOptions.Regions.MinimumEnergyShare := 0.5;
    LRejected := False;
    try
      LSummary := SummarizePitchBoundary(LTrack, 0, LOptions);
    except
      on EAudio do
      begin
        LRejected := True;
      end;
    end;
    Check(LRejected and (LSummary.Frame = 1747),
      'Invalid region policy rejects before incomplete-context return and preserves result');
    LOptions := DefaultPitchBoundaryOptions(8000);
    LOptions.GapFrames := LOptions.ContextFrames;
    LRejected := False;
    try
      LSummary := SummarizePitchBoundary(LTrack, 1747, LOptions);
    except
      on EAudio do
      begin
        LRejected := True;
      end;
    end;
    Check(LRejected, 'Empty side windows reject');
    LOptions := DefaultPitchBoundaryOptions(8000);
    LRejected := False;
    try
      LSummary := SummarizePitchBoundary(LTrack, High(Integer), LOptions);
    except
      on EAudio do
      begin
        LRejected := True;
      end;
    end;
    Check(LRejected, 'Outside-clip frame rejects without overflowing context arithmetic');
  finally
    LTrack.Free;
  end;
  for I := 0 to 39 do
  begin
    LEvidence.Estimates[I] := LLower;
    LEvidence.Estimates[I].AcRms := 0.01 + (I mod 3) * 0.1;
  end;
  LTrack := TPitchTrack.CreateFromEvidence(LEvidence, 8000, 1, 3414);
  try
    LSummary := SummarizePitchBoundary(LTrack, 1747, LOptions);
    Check(LSummary.CompleteContext and not LSummary.Qualified and
      (LSummary.Left.Note = 57) and (LSummary.Right.Note = 57),
      'Same periodic pitch with changing energy does not qualify an attack');
  finally
    LTrack.Free;
  end;
  LEvidence.Estimates[20] := LSilence;
  LTrack := TPitchTrack.CreateFromEvidence(LEvidence, 8000, 1, 3414);
  try
    LSummary := SummarizePitchBoundary(LTrack, 1747, LOptions);
    Check(LSummary.Qualified and (LSummary.UnresolvedWindows = 1) and
      (LSummary.Left.Note = LSummary.Right.Note), 'Interrupted same-pitch context qualifies a cue');
  finally
    LTrack.Free;
  end;
  WriteLn('Pitch boundary context: ownership, geometry, unknowns, configurable admission and cues pass');
end;

procedure CheckRegions;
var
  LEvidence: TPitchTrackEvidence;
  LTrack: TPitchTrack;
  LRegions: TPitchRegions;
  LSummary: TPitchRegionSummaries;
  LGate: TPitchRegion;
  LLower: TPitchEstimate;
  LUpper: TPitchEstimate;
  LRejected: Boolean;
  I: Integer;
begin
  LEvidence := Default(TPitchTrackEvidence);
  LEvidence.WindowFrames := 294;
  LEvidence.Options := DefaultPitchTrackOptions(8000);
  SetLength(LEvidence.Estimates, 12);
  LLower := EstimatePitch(Signal(220, 0), 8000, 1, 0, LEvidence.Options.Pitch);
  LUpper := EstimatePitch(Signal(440, 0), 8000, 1, 0, LEvidence.Options.Pitch);
  LLower.AcRms := 0.04;
  LUpper.AcRms := 0.3;
  for I := 0 to 11 do
  begin
    LEvidence.Estimates[I] := LUpper;
    if I < 4 then
    begin
      LEvidence.Estimates[I] := LLower;
    end;
  end;
  SetLength(LRegions, 1);
  LRegions[0].StartFrame := 0;
  LRegions[0].EndFrame := 1174;
  LTrack := TPitchTrack.CreateFromEvidence(LEvidence, 8000, 1, 1174);
  try
    LSummary := SummarizePitchRegions(LTrack, LRegions, DefaultPitchRegionOptions);
    Check((LSummary[0].Note = 69) and (LSummary[0].PeriodicWindows = 12) and
      (Length(LSummary[0].Votes) = 2) and (LSummary[0].Votes[1].EnergyShare > 0.99),
      'Region inference retains weak subharmonic votes but selects the dominant supported note');
    Check(LTrack.EstimateAt(0).NearestMidi = 57, 'Region inference preserves raw physical pitch');
    LGate := GatePitchRegion(LSummary[0]);
    Check((LGate.StartFrame = 0) and (LGate.EndFrame = 1067),
      'Pitch gate retains the event attack and ends at the last supporting bin');
    LGate := GatePitchRegion(LSummary[0], 200);
    Check(LGate.EndFrame = 1174, 'Pitch gate padding clips to the original candidate interval');
    LRejected := False;
    try
      LGate := GatePitchRegion(LSummary[0], -1);
    except
      on EAudio do
      begin
        LRejected := True;
      end;
    end;
    Check(LRejected, 'Negative pitch gate padding rejects');
    SetLength(LRegions, 2);
    LRegions[0].EndFrame := 427;
    LRegions[1].StartFrame := 427;
    LRegions[1].EndFrame := 1174;
    LSummary := SummarizePitchRegions(LTrack, LRegions, DefaultPitchRegionOptions);
    Check((LSummary[0].Note = 57) and (LSummary[1].Note = 69),
      'Explicit event boundary preserves a real octave change regardless of relative level');
    LGate := GatePitchRegion(LSummary[0]);
    Check((LGate.StartFrame = 0) and (LGate.EndFrame = 427),
      'Gating preserves supported octave transition');
    LGate := GatePitchRegion(LSummary[1]);
    Check((LGate.StartFrame = 427) and (LGate.EndFrame = 1067),
      'Gating retains the upper octave attack');
    LRegions[1].StartFrame := 426;
    LRejected := False;
    try
      LSummary := SummarizePitchRegions(LTrack, LRegions, DefaultPitchRegionOptions);
    except
      on EAudio do
      begin
        LRejected := True;
      end;
    end;
    Check(LRejected, 'Overlapping pitch regions reject');
  finally
    LTrack.Free;
  end;
  SetLength(LRegions, 1);
  LRegions[0].EndFrame := 1174;
  for I := 0 to 11 do
  begin
    LEvidence.Estimates[I] := LUpper;
    if I >= 8 then
    begin
      LEvidence.Estimates[I] := EstimatePitch(Signal(0, 0), 8000, 1, 0,
        LEvidence.Options.Pitch);
    end;
  end;
  LTrack := TPitchTrack.CreateFromEvidence(LEvidence, 8000, 1, 1174);
  try
    LSummary := SummarizePitchRegions(LTrack, LRegions, DefaultPitchRegionOptions);
    LGate := GatePitchRegion(LSummary[0]);
    Check((LGate.StartFrame = 0) and (LGate.EndFrame = 747),
      'Trailing silence does not extend the supported pitch gate');
    SetLength(LRegions, 2);
    LRegions[0].EndFrame := 427;
    LRegions[1].StartFrame := 427;
    LRegions[1].EndFrame := 1174;
    LSummary := SummarizePitchRegions(LTrack, LRegions, DefaultPitchRegionOptions);
    Check((LSummary[0].Note = 69) and (LSummary[1].Note = 69),
      'Repeated same-note events remain distinct summaries');
    LGate := GatePitchRegion(LSummary[1]);
    Check((LGate.StartFrame = 427) and (LGate.EndFrame = 747),
      'Repeated note retains its own attack and supported ending');
    LSummary[1].Votes[0].SupportEndFrame := 1175;
    LRejected := False;
    try
      LGate := GatePitchRegion(LSummary[1]);
    except
      on EAudio do
      begin
        LRejected := True;
      end;
    end;
    Check(LRejected, 'Malformed detached support cannot extend a gate outside its region');
  finally
    LTrack.Free;
  end;
  SetLength(LRegions, 1);
  LRegions[0].EndFrame := 1174;
  for I := 0 to 11 do
  begin
    LEvidence.Estimates[I] := LUpper;
    LEvidence.Estimates[I].CentsError := 35;
    if Odd(I) then
    begin
      LEvidence.Estimates[I].CentsError := -35;
    end;
    LEvidence.Estimates[I].FrequencyHz := 440 * Power(2,
      LEvidence.Estimates[I].CentsError / 1200);
    LEvidence.Estimates[I].PeriodFrames := 8000 / LEvidence.Estimates[I].FrequencyHz;
  end;
  LTrack := TPitchTrack.CreateFromEvidence(LEvidence, 8000, 1, 1174);
  try
    LSummary := SummarizePitchRegions(LTrack, LRegions, DefaultPitchRegionOptions);
    Check((LSummary[0].Note = 69) and (LSummary[0].RawAdmittedWindows = 0) and
      (Abs(LSummary[0].Votes[0].MeanCents) < 1E-10) and
      (Abs(LSummary[0].Votes[0].CentsDeviation - 35) < 1E-10) and
      (LTrack.NoteAt(0) = -1), 'Regional tuning aggregates vibrato without altering raw admission');
  finally
    LTrack.Free;
  end;
  for I := 0 to 11 do
  begin
    LEvidence.Estimates[I].CentsError := 35;
    LEvidence.Estimates[I].AcRms := 0.03 + I * 0.017;
    LEvidence.Estimates[I].FrequencyHz := 440 * Power(2,
      LEvidence.Estimates[I].CentsError / 1200);
    LEvidence.Estimates[I].PeriodFrames := 8000 / LEvidence.Estimates[I].FrequencyHz;
  end;
  LTrack := TPitchTrack.CreateFromEvidence(LEvidence, 8000, 1, 1174);
  try
    LSummary := SummarizePitchRegions(LTrack, LRegions, DefaultPitchRegionOptions);
    Check((LSummary[0].Note = -1) and (LSummary[0].Decision = prdOutsideTuning) and
      (LSummary[0].Votes[0].CentsDeviation = 0),
      'Sustained off-grid tuning is not silently widened by region inference');
  finally
    LTrack.Free;
  end;
  for I := 0 to 11 do
  begin
    LEvidence.Estimates[I] := LUpper;
    if I < 6 then
    begin
      LEvidence.Estimates[I] := LLower;
      LEvidence.Estimates[I].AcRms := LUpper.AcRms;
    end;
  end;
  LTrack := TPitchTrack.CreateFromEvidence(LEvidence, 8000, 1, 1174);
  try
    LSummary := SummarizePitchRegions(LTrack, LRegions, DefaultPitchRegionOptions);
    Check((LSummary[0].Note = -1) and (LSummary[0].Decision = prdAmbiguousPitch),
      'Competing supported registers remain ambiguous in an unsplit region');
  finally
    LTrack.Free;
  end;
  for I := 0 to 11 do
  begin
    LEvidence.Estimates[I] := EstimatePitch(Signal(0, 0), 8000, 1, 0, LEvidence.Options.Pitch);
  end;
  LTrack := TPitchTrack.CreateFromEvidence(LEvidence, 8000, 1, 1174);
  try
    LSummary := SummarizePitchRegions(LTrack, LRegions, DefaultPitchRegionOptions);
    Check((LSummary[0].Note = -1) and (Length(LSummary[0].Votes) = 0) and
      (LSummary[0].Decision = prdInsufficientPeriodicity), 'Silent regions cannot invent note votes');
    LRejected := False;
    try
      LGate := GatePitchRegion(LSummary[0]);
    except
      on EAudio do
      begin
        LRejected := True;
      end;
    end;
    Check(LRejected, 'An unknown region cannot invent a note gate');
    LRegions[0].EndFrame := 100;
    LSummary := SummarizePitchRegions(LTrack, LRegions, DefaultPitchRegionOptions);
    Check(LSummary[0].Decision = prdNoWindows, 'Regions without window centers remain unmeasured');
    WriteLn('Pitch regions: independent events, energy votes, tuning, silence and bounded support gates pass');
  finally
    LTrack.Free;
  end;
end;

procedure CheckEvaluation;
const
  CLabels: array[0..19] of Integer =
    (69, 69, 69, -1, 69, 69, -1, 72, 72, 72, 72, -1, 69, 69, 69, 69, -1, -1, -1, -1);
var
  LEvidence: TPitchTrackEvidence;
  LA: TPitchEstimate;
  LC: TPitchEstimate;
  LSilence: TPitchEstimate;
  LTrack: TPitchTrack;
  LReferences: TPitchReferenceNotes;
  LOptions: TPitchEvaluationOptions;
  LResult: TPitchEvaluation;
  LNoteResult: TPitchNoteEvaluation;
  LFrameResult: TPitchIntervalFrameEvaluation;
  LActual: TPitchReferenceNotes;
  LRuns: TPitchRuns;
  LRejected: Boolean;
  I: Integer;

  procedure Reference(const AIndex, AStart, AEnd, ANote: Integer);
  begin
    LReferences[AIndex].StartFrame := 10000 + AStart;
    LReferences[AIndex].EndFrame := 10000 + AEnd;
    LReferences[AIndex].Note := ANote;
  end;

begin
  LEvidence := Default(TPitchTrackEvidence);
  LEvidence.Options := DefaultPitchTrackOptions(8000);
  LEvidence.WindowFrames := 294;
  LA := EstimatePitch(Signal(440, 0), 8000, 1, 0, LEvidence.Options.Pitch);
  LC := EstimatePitch(Signal(523.2511306, 0), 8000, 1, 0, LEvidence.Options.Pitch);
  LSilence := EstimatePitch(Signal(0, 0), 8000, 1, 0, LEvidence.Options.Pitch);
  SetLength(LEvidence.Estimates, Length(CLabels));
  for I := 0 to High(CLabels) do
  begin
    LEvidence.Estimates[I] := LSilence;
    if CLabels[I] = 69 then
    begin
      LEvidence.Estimates[I] := LA;
    end
    else if CLabels[I] = 72 then
    begin
      LEvidence.Estimates[I] := LC;
    end;
  end;
  LTrack := TPitchTrack.CreateFromEvidence(LEvidence, 8000, 1, 1814);
  try
    SetLength(LReferences, 5);
    Reference(0, 107, 347, 69);
    Reference(1, 427, 587, 69);
    Reference(2, 667, 987, 71);
    Reference(3, 1067, 1187, 69);
    Reference(4, 1187, 1387, 69);
    LOptions := DefaultPitchEvaluationOptions(8000);
    LOptions.OnsetToleranceFrames := 20;
    LOptions.MinimumOffsetToleranceFrames := 20;
    LOptions.NoteEdgeFrames := 0;
    LResult := EvaluatePitchTrack(LTrack, LReferences, 10000, LOptions);
    Check((LResult.WindowCount = 20) and (LResult.ReferenceActive = 13) and
      (LResult.ReferenceRest = 7) and (LResult.ReferenceAmbiguous = 0),
      'Evaluation uses absolute reference coordinates and complete center accounting');
    Check((LResult.CorrectPitch = 7) and (LResult.WrongPitch = 4) and
      (LResult.UnknownActive = 2) and (LResult.SilenceActive = 0) and
      (LResult.SilenceRest = 7) and (LResult.FalsePitchInRest = 0),
      'Evaluation separates correct, wrong, rejected short runs and silence');
    Check(LTrack.NoteAt(4) = 69, 'Raw short-run candidate remains available');
    Check((LResult.UnknownShortRun = 2) and (LResult.UnknownNoPeriod = 0) and
      (LResult.UnknownOutsideRange = 0) and (LResult.UnknownTuning = 0) and
      (LResult.WrongOctave = 0), 'Rejection reasons do not mislabel short runs as no period');
    Check((LResult.ReferenceNotes = 5) and (LResult.EstimatedNotes = 3) and
      (LResult.ConsecutiveRepeatedReferences = 2) and (LResult.MatchedOnsets = 2) and
      (LResult.MatchedNotes = 1) and (LResult.MatchedOnsetErrorFrames = 0) and
      (LResult.MatchedOffsetErrorFrames = 200),
      'One merged repeated note cannot match two references; offset failure remains visible');
    Check((Abs(PitchCoverage(LResult) - 7 / 13) < 1E-12) and
      (Abs(PitchPrecision(LResult) - 7 / 11) < 1E-12) and
      (NoteF1(LResult.MatchedOnsets, 5, 3) = 0.5) and
      (NoteF1(LResult.MatchedNotes, 5, 3) = 0.25), 'Independent expected evaluation ratios');
    Check(Abs(NoteF1(78, 95, 134) - Double(0.681222707423580786)) < 1E-12,
      'Note F1 retains Double precision on every target');
    LRuns := LTrack.CopyRuns;
    SetLength(LActual, Length(LRuns));
    for I := 0 to High(LRuns) do
    begin
      LActual[I].StartFrame := 10000 + LRuns[I].StartFrame;
      LActual[I].EndFrame := 10000 + LRuns[I].EndFrame;
      LActual[I].Note := LRuns[I].Note;
    end;
    LNoteResult := EvaluatePitchNoteIntervals(LActual, LReferences, 10000, 11814, LOptions);
    Check((LNoteResult.ReferenceNotes = LResult.ReferenceNotes) and
      (LNoteResult.EstimatedNotes = LResult.EstimatedNotes) and
      (LNoteResult.MatchedOnsets = LResult.MatchedOnsets) and
      (LNoteResult.MatchedNotes = LResult.MatchedNotes) and
      (LNoteResult.MatchedOffsetErrorFrames = LResult.MatchedOffsetErrorFrames),
      'Explicit note intervals share the track scoring contract without raw evidence fabrication');
    LFrameResult := EvaluatePitchIntervalFrames(LTrack, LActual, LReferences, 10000);
    Check((LFrameResult.ReferenceActive = 13) and (LFrameResult.ReferenceRest = 7) and
      (LFrameResult.CorrectPitch = 7) and (LFrameResult.WrongPitch = 4) and
      (LFrameResult.UnknownActive = 2) and (LFrameResult.UnknownRest = 7) and
      (LFrameResult.PitchCoverage = PitchCoverage(LResult)) and
      (LFrameResult.PitchPrecision = PitchPrecision(LResult)),
      'Interval frame scoring retains pitch accounting, treating unlabeled gaps as unknown');
    LActual[0].EndFrame := LActual[1].StartFrame + 1;
    LRejected := False;
    try
      LFrameResult := EvaluatePitchIntervalFrames(LTrack, LActual, LReferences, 10000);
    except
      on EAudio do
      begin
        LRejected := True;
      end;
    end;
    Check(LRejected, 'Overlapping inferred intervals reject instead of hiding competing labels');
    LActual[0].EndFrame := 10000 + LRuns[0].EndFrame;

    Reference(1, 147, 307, 69);
    LResult := EvaluatePitchTrack(LTrack, LReferences, 10000, LOptions);
    Check((LResult.ReferenceAmbiguous = 2) and (LResult.AmbiguousAdmitted = 2),
      'Overlapping reference notes are explicitly ambiguous');
    LFrameResult := EvaluatePitchIntervalFrames(LTrack, LActual, LReferences, 10000);
    Check((LFrameResult.ReferenceAmbiguous = 2) and (LFrameResult.AmbiguousAdmitted = 2),
      'Inferred frame scoring excludes ambiguous reference centers');
    LFrameResult := EvaluatePitchIntervalFrames(LTrack, LActual, nil, 10000);
    Check((LFrameResult.FalsePitchInRest = 11) and (LFrameResult.UnknownRest = 9) and
      (LFrameResult.PitchCoverage = 0) and (LFrameResult.PitchPrecision = 0),
      'Empty references retain false inferred pitch and safe zero ratios');
    LResult := EvaluatePitchTrack(LTrack, nil, 10000, LOptions);
    Check((LResult.ReferenceRest = 20) and (LResult.FalsePitchInRest = 11) and
      (LResult.UnknownRest = 2) and (LResult.SilenceRest = 7) and
      (PitchPrecision(LResult) = 0) and (PitchCoverage(LResult) = 0),
      'Empty reference retains false pitch admissions rather than dividing by zero');

    Reference(1, 427, 587, 0);
    LResult := EvaluatePitchTrack(LTrack, LReferences, 10000, LOptions);
    Check((LResult.ReferenceOutsideRange = 2) and (LResult.ReferenceActive = 13),
      'Unsupported reference range remains in coverage');
    Reference(1, 0, 80, 69);
    LRejected := False;
    try
      LResult := EvaluatePitchTrack(LTrack, LReferences, 10000, LOptions);
    except
      on EAudio do
      begin
        LRejected := True;
      end;
    end;
    Check(LRejected, 'Unsorted absolute reference notes reject');
    WriteLn('Phrase evaluation: raw/inferred frame coverage, ambiguity, rests and one-to-one boundaries pass');
  finally
    LTrack.Free;
  end;
end;

procedure WriteSource(const APath: String; const ATranspose: Integer = 0;
  const AChanging: Boolean = False);
const
  CNotes: array[0..7] of Integer = (60, 62, 64, 67, 69, 67, 64, 60);
var
  LSamples: TAudioSamples;
  LClip: TAudioClip;
  LEvidence: TPitchCellEvidence;
  LNotes: TPitchNotes;
  LSummary: TPitchCellSummary;
  LExpected: Integer;
  LStream: TFileStream;
  LBytes: TAudioBytes;
  LCell: Integer;
  LFrame: Integer;
  LPhase: Double;
  LStart: Integer;
  LWidth: Integer;
  LOffset: Integer;
  LClock: TTempoMap;
  LGrid: TMusicGridFrames;
begin
  LOffset := Ord(AChanging) * 97;
  SetLength(LSamples, LOffset + 32 * 2000 + Ord(AChanging) * 16 * 400);
  for LCell := 0 to 31 do
  begin
    if LCell mod 16 = 15 then
    begin
      Continue;
    end;
    LWidth := 2000;
    LStart := LOffset + LCell * 2000;
    if AChanging and (LCell >= 16) then
    begin
      LWidth := 2400;
      Inc(LStart, (LCell - 16) * 400);
    end;
    for LFrame := 0 to LWidth - 1 do
    begin
      LPhase := 2 * Pi * 440 * Power(2, (CNotes[LCell mod 8] + ATranspose - 69) / 12) * LFrame / 8000;
      LSamples[LStart + LFrame] := 0.3 * Sin(LPhase) +
        0.15 * Sin(2 * LPhase) + 0.1 * Sin(3 * LPhase);
    end;
  end;
  LClip := TAudioClip.Create(8000, 1, LSamples);
  LClock := nil;
  LGrid := nil;
  try
    if AChanging then
    begin
      LClock := TTempoMap.Create(480, 32 * 240,
        [MakeTempoChange(0, 500000), MakeTempoChange(16 * 240, 600000)]);
      LGrid := TMusicGridFrames.Create(LClock, 8000, LClip.FrameCount, LOffset, 0, 240, 32);
      LEvidence := MeasurePitchCells(LClip, LGrid, 0, DefaultPitchOptions, 25);
      LNotes := AdmitPitchCells(LEvidence, LGrid, 1);
      LSummary := SummarizePitchCells(LEvidence, LGrid, 1);
    end
    else
    begin
      LEvidence := MeasurePitchCells(LClip, 500000, 480, 240, 0, DefaultPitchOptions, 25);
      LNotes := AdmitPitchCells(LEvidence, 8000, 1, LClip.FrameCount, 500000, 480, 240);
      LSummary := SummarizePitchCells(LEvidence, 8000, 1, LClip.FrameCount, 500000, 480, 240);
    end;
    Check(Length(LNotes) = 32, 'Complete measured pitch grid');
    Check((LSummary.Cells = 32) and (LSummary.AdmittedPitch = 30) and
      (LSummary.MeasuredSilence = 2) and (LSummary.UncertainPitch = 0) and
      (LSummary.Unmeasured = 0) and (LSummary.KnownRuns = 2) and
      (LSummary.LongestKnownRun = 15), 'Pitch summary preserves measured silence and source run boundaries');
    for LCell := 0 to 31 do
    begin
      LExpected := CNotes[LCell mod 8] + ATranspose;
      if LCell in [15, 31] then
      begin
        LExpected := -1;
      end;
      Check(LNotes[LCell] = LExpected, 'Native pitch-cell measurement matches independent source notes');
    end;
    LBytes := EncodeWavePcm16(LClip);
    LStream := TFileStream.Create(APath, fmCreate);
    try
      LStream.WriteBuffer(LBytes[0], Length(LBytes));
    finally
      LStream.Free;
    end;
  finally
    LGrid.Free;
    LClock.Free;
    LClip.Free;
  end;
end;

procedure WriteRepeatedSource(const APath: String);
var
  LSamples: TAudioSamples;
  LClip: TAudioClip;
  LTrack: TPitchTrack;
  LFrame: Integer;
  LTime: Double;
begin
  SetLength(LSamples, 32000);
  for LFrame := 0 to High(LSamples) do
  begin
    LTime := LFrame / 8000;
    LSamples[LFrame] := (0.35 + 0.2 * Exp(-12 * Frac(2 * LTime))) *
      Sin(2 * Pi * 440 * LTime);
  end;
  LClip := TAudioClip.Create(8000, 1, LSamples);
  LTrack := nil;
  try
    LTrack := TPitchTrack.Create(LClip, 0, DefaultPitchTrackOptions(8000));
    Check(LTrack.RunCount = 1, 'Continuous periodic source has one stable pitch run despite energy pulses');
    SaveWavePcm16(APath, LClip);
    WriteLn('Four-second continuous A4 with recurring energy rises; one dense pitch run, no silent gaps');
  finally
    LTrack.Free;
    LClip.Free;
  end;
end;

procedure CheckArticulation;
const
  CStarts: array[0..6] of Integer = (100, 240, 400, 500, 650, 800, 1000);
  CEnds: array[0..6] of Integer = (240, 400, 500, 650, 800, 1000, 1200);
var
  LSource: TTimedPitchSpans;
  LOutput: TTimedPitchSpans;
  LAttacks: TPitchAttackTicks;
  LIndex: Integer;
  LRejected: Boolean;
begin
  SetLength(LSource, 4);
  LSource[0].Kind := pskPitch;
  LSource[0].Note := 60;
  LSource[0].StartTick := 100;
  LSource[0].EndTick := 500;
  LSource[1].Kind := pskUnknown;
  LSource[1].Note := -1;
  LSource[1].StartTick := 500;
  LSource[1].EndTick := 650;
  LSource[2] := LSource[0];
  LSource[2].StartTick := 650;
  LSource[2].EndTick := 1000;
  LSource[3].Kind := pskSilence;
  LSource[3].Note := -1;
  LSource[3].StartTick := 1000;
  LSource[3].EndTick := 1200;
  LAttacks := [50, 100, 240, 400, 500, 550, 650, 800, 1000, 1100, 1250];
  LOutput := RearticulatePitchSpans(LSource, LAttacks);
  Check(Length(LOutput) = 7, 'Only three interior pitched attacks add spans');
  for LIndex := 0 to High(LOutput) do
  begin
    Check((LOutput[LIndex].StartTick = CStarts[LIndex]) and
      (LOutput[LIndex].EndTick = CEnds[LIndex]), 'Independent articulation partition');
    if not (LIndex in [3, 6]) then
    begin
      Check((LOutput[LIndex].Kind = pskPitch) and (LOutput[LIndex].Note = 60),
        'Same-pitch repeats retain the measured note');
    end;
  end;
  Check((LOutput[3].Kind = pskUnknown) and (LOutput[6].Kind = pskSilence),
    'Attack cues do not manufacture pitches in unresolved or silent intervals');
  Check((LSource[0].EndTick = 500) and (LSource[2].EndTick = 1000),
    'Articulation leaves source spans intact');
  LAttacks[3] := LAttacks[2];
  LRejected := False;
  try
    LOutput := RearticulatePitchSpans(LSource, LAttacks);
  except
    on EAudio do
    begin
      LRejected := True;
    end;
  end;
  Check(LRejected and (Length(LOutput) = 7) and (LOutput[0].EndTick = 240),
    'Collapsed/duplicate attacks reject without replacing accepted spans');
  WriteLn('Pitch articulation retains repeated attacks, exact extent and unknown/silent gaps');
end;

procedure CheckTimedTrack(const ATrack: TPitchTrack);
var
  LClock: TTempoMap;
  LCoarse: TTempoMap;
  LSpans: TPitchSpans;
  LTimed: TTimedPitchSpans;
  LIndex: Integer;
  LCount: Integer;
  LFirst: Integer;
  LLast: Integer;
  LRejected: Boolean;

  function ExpectedTick(const AFrame: Integer): Integer;
  var
    LFrame: Integer;
  begin
    LFrame := AFrame - 97;
    if LFrame <= 20000 then
    begin
      Result := (LFrame * 3 + 24) div 25;
    end
    else
    begin
      Result := 2400 + ((LFrame - 20000) * 2 + 24) div 25;
    end;
  end;

begin
  LClock := TTempoMap.Create(480, 3600,
    [MakeTempoChange(0, 500000), MakeTempoChange(2400, 750000)]);
  LCoarse := nil;
  try
    LSpans := ATrack.CopySpans;
    LTimed := ATrack.TimedSpans(LClock, 97, 480, 3600);
    LCount := 0;
    for LIndex := 0 to High(LSpans) do
    begin
      LFirst := Max(4097, LSpans[LIndex].StartFrame);
      LLast := Min(35097, LSpans[LIndex].EndFrame);
      if LLast <= LFirst then
      begin
        Continue;
      end;
      Check((LTimed[LCount].StartTick = ExpectedTick(LFirst)) and
        (LTimed[LCount].EndTick = ExpectedTick(LLast)) and
        (LTimed[LCount].Kind = LSpans[LIndex].Kind) and
        (LTimed[LCount].Note = LSpans[LIndex].Note),
        'Independent rational clock maps every pitch/silence/unknown boundary through tempo changes');
      Inc(LCount);
    end;
    Check((LCount = Length(LTimed)) and (LTimed[0].StartTick = 480) and
      (LTimed[High(LTimed)].EndTick = 3600), 'Explicit clock scope clips only evidence endpoints');
    LCoarse := TTempoMap.Create(1, 8, [MakeTempoChange(0, 500000)]);
    LRejected := False;
    try
      ATrack.TimedSpans(LCoarse, 0, 0, 8);
    except
      on EAudio do
      begin
        LRejected := True;
      end;
    end;
    Check(LRejected, 'Sub-tick spans reject rather than merge pitch and unknown evidence');
    Check(Length(ATrack.TimedSpans(LClock, 97, 480, 3600)) = LCount,
      'Rejected normalization preserves source evidence');
    WriteLn('Dense source spans normalize through changing tempo, source offset and clipped scope');
  finally
    LCoarse.Free;
    LClock.Free;
  end;
end;

procedure RunTrack(const APath: String);
const
  CStarts: array[0..5] of Integer = (800, 4400, 10400, 20400, 24000, 31200);
  CEnds: array[0..5] of Integer = (4000, 10000, 20000, 23600, 30400, 37600);
  CNotes: array[0..5] of Integer = (60, 64, 67, 67, 62, 60);
var
  LSamples: TAudioSamples;
  LClip: TAudioClip;
  LTrack: TPitchTrack;
  LRejectedTrack: TPitchTrack;
  LOptions: TPitchTrackOptions;
  LRun: TPitchRun;
  LDetached: TPitchRuns;
  LStored: TPitchTrackEvidence;
  LReloaded: TPitchTrack;
  LExtended: TPitchTrack;
  LExtendedReplay: TPitchTrack;
  LIndex: Integer;
  LFrame: Integer;
  LPhase: Double;
  LGain: Double;
  LValue: Double;
  LError: Integer;
  LMaximumError: Integer;
  LBytes: TAudioBytes;
  LStream: TFileStream;
  LRejected: Boolean;
begin
  SetLength(LSamples, 40000 * 2);
  for LIndex := 0 to High(CNotes) do
  begin
    for LFrame := CStarts[LIndex] to CEnds[LIndex] - 1 do
    begin
      LPhase := 2 * Pi * 440 * Power(2, (CNotes[LIndex] - 69) / 12) *
        (LFrame - CStarts[LIndex]) / 8000;
      LGain := Min(1, Min((LFrame - CStarts[LIndex]) / 80,
        (CEnds[LIndex] - 1 - LFrame) / 80));
      LValue := LGain * (0.3 * Sin(LPhase) + 0.15 * Sin(2 * LPhase) + 0.1 * Sin(3 * LPhase));
      LSamples[LFrame * 2] := LValue;
      LSamples[LFrame * 2 + 1] := -LValue;
    end;
  end;
  LClip := TAudioClip.Create(8000, 2, LSamples);
  LTrack := nil;
  LRejectedTrack := nil;
  LReloaded := nil;
  LExtended := nil;
  LExtendedReplay := nil;
  try
    LOptions := DefaultPitchTrackOptions(8000);
    LTrack := TPitchTrack.Create(LClip, 1, LOptions);
    CheckTimedTrack(LTrack);
    Check(LTrack.RunCount = Length(CNotes), 'Six independent performed notes, including repeated pitch');
    LMaximumError := 0;
    for LIndex := 0 to High(CNotes) do
    begin
      LRun := LTrack.RunAt(LIndex);
      Check(LRun.Note = CNotes[LIndex], 'Measured stable run matches independent performed pitch');
      LError := Max(Abs(LRun.StartFrame - CStarts[LIndex]), Abs(LRun.EndFrame - CEnds[LIndex]));
      LMaximumError := Max(LMaximumError, LError);
      Check(LError <= LTrack.WindowFrames + LOptions.HopFrames,
        'Measured run boundaries stay within the declared analysis resolution');
      Check(LRun.EndFrame - LRun.StartFrame = LRun.WindowCount * LOptions.HopFrames,
        'Run extent retains every admitted measurement bin');
    end;
    LDetached := LTrack.CopyRuns;
    LDetached[0].Note := 127;
    Check(LTrack.RunAt(0).Note = 60, 'Detached pitch runs cannot mutate accepted evidence');
    LStored := LTrack.CopyEvidence;
    LReloaded := TPitchTrack.CreateFromEvidence(LStored, 8000, 2, 40000);
    Check(LReloaded.RunCount = LTrack.RunCount, 'Saved dense evidence replays without PCM');
    for LIndex := 0 to LTrack.RunCount - 1 do
    begin
      Check((LReloaded.RunAt(LIndex).Note = LTrack.RunAt(LIndex).Note) and
        (LReloaded.RunAt(LIndex).StartFrame = LTrack.RunAt(LIndex).StartFrame) and
        (LReloaded.RunAt(LIndex).EndFrame = LTrack.RunAt(LIndex).EndFrame),
        'Evidence replay preserves every admitted run extent');
    end;
    LStored.Estimates[0].AcRms := 1;
    LRejected := False;
    try
      LRejectedTrack := TPitchTrack.CreateFromEvidence(LStored, 8000, 2, 40000);
    except
      on EAudio do
      begin
        LRejected := True;
      end;
    end;
    Check(LRejected and (LRejectedTrack = nil) and (LTrack.EstimateAt(0).AcRms = 0),
      'Forged silence diagnostics reject and detached evidence preserves original measurements');
    LOptions.HopFrames := 0;
    LRejected := False;
    try
      LRejectedTrack := TPitchTrack.Create(LClip, 0, LOptions);
    except
      on EAudio do
      begin
        LRejected := True;
      end;
    end;
    Check(LRejected and (LRejectedTrack = nil) and (LTrack.RunCount = 6),
      'Invalid measurement geometry preserves prior track');
    LOptions := DefaultPitchTrackOptions(8000);
    LExtended := TPitchTrack.Create(LClip, 1, LOptions, 881);
    Check((LExtended.WindowFrames = 881) and
      (LExtended.WindowCount = 1 + (40000 - 881) div LOptions.HopFrames),
      'Explicit odd window controls complete-window geometry without changing the hop');
    CheckTimedTrack(LExtended);
    Check(LExtended.RunCount = Length(CNotes), 'Longer integration retains six performed notes');
    LStored := LExtended.CopyEvidence;
    LExtendedReplay := TPitchTrack.CreateFromEvidence(LStored, 8000, 2, 40000);
    Check(LExtendedReplay.WindowFrames = 881, 'Saved evidence retains the explicit window');
    for LIndex := 0 to High(CNotes) do
    begin
      Check((LExtended.RunAt(LIndex).Note = CNotes[LIndex]) and
        (LExtendedReplay.RunAt(LIndex).Note = CNotes[LIndex]) and
        (LExtendedReplay.RunAt(LIndex).StartFrame = LExtended.RunAt(LIndex).StartFrame) and
        (LExtendedReplay.RunAt(LIndex).EndFrame = LExtended.RunAt(LIndex).EndFrame),
        'Explicit-window replay retains performed pitches and bin extents');
    end;
    LRejected := False;
    try
      LRejectedTrack := TPitchTrack.Create(LClip, 1, LOptions, 293);
    except
      on EAudio do
      begin
        LRejected := True;
      end;
    end;
    Check(LRejected and (LRejectedTrack = nil), 'Explicit window must cover minimum pitch');
    LStored.WindowFrames := 0;
    LRejected := False;
    try
      LRejectedTrack := TPitchTrack.CreateFromEvidence(LStored, 8000, 2, 40000);
    except
      on EAudio do
      begin
        LRejected := True;
      end;
    end;
    Check(LRejected and (LRejectedTrack = nil), 'Saved evidence cannot request automatic geometry');
    if APath <> '' then
    begin
      LBytes := EncodeWavePcm16(LClip);
      LStream := TFileStream.Create(APath, fmCreate);
      try
        LStream.WriteBuffer(LBytes[0], Length(LBytes));
      finally
        LStream.Free;
      end;
    end;
    WriteLn('Dense monophonic track: six measured durations, repeated-note separation, ',
      'selected-channel evidence; maximum boundary error ', LMaximumError, ' frames at 8000 Hz');
  finally
    LExtendedReplay.Free;
    LExtended.Free;
    LReloaded.Free;
    LRejectedTrack.Free;
    LTrack.Free;
    LClip.Free;
  end;
end;

procedure CheckWindowResolution;
const
  CNotes: array[0..3] of Integer = (69, 72, 76, 79);
var
  LSamples: TAudioSamples;
  LClip: TAudioClip;
  LShort: TPitchTrack;
  LLong: TPitchTrack;
  LFrame: Integer;
  LFrequency: Double;
  LRun: TPitchRun;
  LShortBins: Integer;
  LLongBins: Integer;
begin
  SetLength(LSamples, 12 * 480);
  for LFrame := 0 to High(LSamples) do
  begin
    LFrequency := 440 * Power(2, (CNotes[(LFrame div 480) mod 4] - 69) / 12);
    LSamples[LFrame] := 0.4 * Sin(2 * Pi * LFrequency * (LFrame mod 480) / 8000);
  end;
  LClip := TAudioClip.Create(8000, 1, LSamples);
  LShort := nil;
  LLong := nil;
  try
    LShort := TPitchTrack.Create(LClip, 0, DefaultPitchTrackOptions(8000));
    LLong := TPitchTrack.Create(LClip, 0, DefaultPitchTrackOptions(8000), 880);
    LShortBins := 0;
    LLongBins := 0;
    for LRun in LShort.CopyRuns do
    begin
      Check(LRun.Note in [69, 72, 76, 79], 'Short-window rapid-note run matches authored vocabulary');
      Inc(LShortBins, LRun.WindowCount);
    end;
    for LRun in LLong.CopyRuns do
    begin
      Inc(LLongBins, LRun.WindowCount);
    end;
    Check((LShortBins > 0) and (LLongBins < LShortBins),
      'Longer integration trades away stable coverage of rapid 60 ms notes');
    WriteLn('Rapid-note resolution: default stable bins=', LShortBins,
      '; 110 ms stable bins=', LLongBins, '; window policy remains caller-controlled');
  finally
    LLong.Free;
    LShort.Free;
    LClip.Free;
  end;
end;

procedure CheckRecording(const APath: String; const AReferenceNote, AChannel: Integer;
  const AWindowFrames: Integer = 0);
var
  LClip: TAudioClip;
  LTrack: TPitchTrack;
  LSpans: TPitchSpans;
  LSpan: TPitchSpan;
  LCorrect: Integer;
  LWrong: Integer;
  LUnknown: Integer;
  LSilence: Integer;
begin
  Check((AReferenceNote >= 0) and (AReferenceNote <= 127), 'Invalid reference note');
  LClip := LoadWave(APath);
  LTrack := nil;
  LCorrect := 0;
  LWrong := 0;
  LUnknown := 0;
  LSilence := 0;
  try
    LTrack := TPitchTrack.Create(LClip, AChannel, DefaultPitchTrackOptions(LClip.SampleRate),
      AWindowFrames);
    LSpans := LTrack.CopySpans;
    for LSpan in LSpans do
    begin
      case LSpan.Kind of
        pskPitch:
        begin
          if LSpan.Note = AReferenceNote then
          begin
            Inc(LCorrect, LSpan.WindowCount);
          end
          else
          begin
            Inc(LWrong, LSpan.WindowCount);
            WriteLn('Unexpected stable note ', LSpan.Note, ': ', LSpan.WindowCount,
              ' windows at source frames ', LSpan.StartFrame, '..', LSpan.EndFrame);
          end;
        end;
        pskSilence:
        begin
          Inc(LSilence, LSpan.WindowCount);
        end;
        pskUnknown:
        begin
          Inc(LUnknown, LSpan.WindowCount);
        end;
      end;
    end;
    WriteLn(ExtractFileName(APath), ': reference=', AReferenceNote,
      '; channel=', AChannel, '; windows=', LTrack.WindowCount,
      '; correct=', LCorrect, '; wrong=', LWrong,
      '; unknown=', LUnknown, '; silence=', LSilence,
      '; hop_frames=', LTrack.Options.HopFrames, '; sample_rate=', LClip.SampleRate,
      '; window_frames=', LTrack.WindowFrames);
    Check(LCorrect + LWrong + LUnknown + LSilence = LTrack.WindowCount,
      'Recording span accounting mismatch');
    Check(LCorrect >= LTrack.Options.MinimumRunWindows, 'No stable reference-note coverage');
    Check(LWrong = 0, 'Recording admits a stable pitch different from the independent reference');
  finally
    LTrack.Free;
    LClip.Free;
  end;
end;

begin
  try
    if (ParamCount = 2) and (ParamStr(1) = 'repeated') then
    begin
      WriteRepeatedSource(ParamStr(2));
      Halt(0);
    end;
    if (ParamCount = 2) and (ParamStr(1) = 'changing') then
    begin
      WriteSource(ParamStr(2), 0, True);
      WriteLn('Changing source clock and frame offset retain 30 known pitches and two measured silent cells');
      Halt(0);
    end;
    if (ParamCount in [4, 5]) and (ParamStr(1) = 'recording') then
    begin
      if ParamCount = 5 then
      begin
        CheckRecording(ParamStr(2), StrToInt(ParamStr(3)), StrToInt(ParamStr(4)),
          StrToInt(ParamStr(5)));
      end
      else
      begin
        CheckRecording(ParamStr(2), StrToInt(ParamStr(3)), StrToInt(ParamStr(4)));
      end;
      Halt(0);
    end;
    Check(ParamCount <= 3, 'Usage: pythian.tests.pitch [CONTROLLED_SOURCE.wav [OCTAVE_SOURCE.wav [RUN_SOURCE.wav]]]; recording INPUT.wav REFERENCE_MIDI CHANNEL [WINDOW_FRAMES]');
    Run;
    CheckCentered;
    CheckArticulation;
    RunTrack(ParamStr(3));
    CheckWindowResolution;
    CheckEvaluation;
    CheckRegions;
    CheckBoundaryContext;
    if ParamCount >= 1 then
    begin
      WriteSource(ParamStr(1));
    end;
    if ParamCount >= 2 then
    begin
      WriteSource(ParamStr(2), 12);
    end;
  except
    on LException: Exception do
    begin
      WriteLn(StdErr, LException.ClassName, ': ', LException.Message);
      Halt(1);
    end;
  end;
end.
