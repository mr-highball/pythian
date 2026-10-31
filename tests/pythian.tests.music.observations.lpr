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

program pythian_tests_music_observations;
{$mode delphi}
{$H+}
uses SysUtils, Math, pythian.audio, pythian.progress, pythian.music.observations,
  pythian.tonal, pythian.pitch.track, pythian.pitch.regions,
  pythian.music.sound, pythian.music.proposal, pythian.chord,
  pythian.synth, pythian.automation;

type
  ECancelled = class(Exception);
  TProbe = class
    procedure Observe(const AProgress: TWorkProgress);
  end;

var
  GChecks: Integer;

procedure Check(const ACondition: Boolean; const AMessage: String);
begin
  Inc(GChecks);
  if not ACondition then raise Exception.Create(AMessage);
end;

procedure TProbe.Observe(const AProgress: TWorkProgress);
begin
  if AProgress.Stage = 'musical_pitch_channel' then
    raise ECancelled.Create('Requested cancellation');
end;

function Tone(const ASeconds, AChannels: Integer; const ASilentLeft: Boolean): TAudioClip;
var
  LSamples: TAudioSamples;
  I: Integer;
begin
  SetLength(LSamples, 8000 * ASeconds * AChannels);
  for I := 0 to 8000 * ASeconds - 1 do
  begin
    if not ASilentLeft then LSamples[I * AChannels] := 0.2 * Sin(2 * Pi * 261.625565 * I / 8000);
    if AChannels = 2 then LSamples[I * 2 + 1] := 0.2 * Sin(2 * Pi * 440 * I / 8000);
  end;
  Result := TAudioClip.Create(8000, AChannels, LSamples);
end;

procedure RunSound;
var
  LSound, LReplay: TMusicalSound;
  LVoice, LOriginal, LApplied: TSynthVoice;
  LFailed: Boolean;
  LCurve: TAutomationCurve;
begin
  Check(ProposeMusicalSound(1200, 0.05, 0.2, LSound), 'Nonsilent sound suggestion available');
  Check((LSound.CutoffHz = 2400) and (LSound.SustainPercent = 25), 'Explicit brightness and dynamics mapping');
  Check(ProposeMusicalSound(1200, 0.05, 0.2, LReplay) and
    (LSound.CutoffHz = LReplay.CutoffHz) and (LSound.SustainPercent = LReplay.SustainPercent), 'Sound mapping deterministic');
  LVoice := DefaultSynthVoice;
  LOriginal := LVoice;
  LApplied := ApplyMusicalSound(LVoice, LSound, 24000);
  Check((LApplied.CutoffHz = 2400) and (LApplied.Envelope.SustainLevel = 0.25), 'Actual shared voice controls changed');
  Check((LVoice.CutoffHz = LOriginal.CutoffHz) and
    (LVoice.Envelope.SustainLevel = LOriginal.Envelope.SustainLevel), 'Source voice remains unchanged');
  Check((LApplied.Gain = LVoice.Gain) and (LApplied.Shape = LVoice.Shape) and
    (LApplied.Envelope.AttackSeconds = LVoice.Envelope.AttackSeconds), 'Other sound choices remain explicit');
  Check(not ProposeMusicalSound(0, 0, 0, LReplay), 'Silence does not invent a sound suggestion');
  Check((LReplay.CutoffHz = 0) and (LReplay.SustainPercent = 0), 'Unavailable proposal is empty');
  Check(ProposeMusicalSound(1E100, 0, 0.2, LReplay) and
    (LReplay.CutoffHz = 10000) and (LReplay.SustainPercent = 0), 'Extreme finite observations remain bounded');
  Check(ProposeMusicalSound(0, 0.2, 0.2, LReplay) and
    (LReplay.CutoffHz = 100) and (LReplay.SustainPercent = 100), 'Low brightness and steady dynamics endpoints');
  LFailed := False;
  try ProposeMusicalSound(100, 0.3, 0.2, LReplay);
  except on E: EAudio do LFailed := True end;
  Check(LFailed, 'Inverted observed dynamics rejected');
  LFailed := False;
  try ProposeMusicalSound(NaN, 0.1, 0.2, LReplay);
  except on E: EAudio do LFailed := True end;
  Check(LFailed, 'Nonfinite observations rejected');
  LFailed := False;
  LSound.CutoffHz := 6000;
  try LApplied := ApplyMusicalSound(LVoice, LSound, 8000);
  except on E: EAudio do LFailed := True end;
  Check(LFailed and (LApplied.CutoffHz = 2400), 'Rate-incompatible control preserves accepted voice');
  LSound.CutoffHz := 2400;
  LSound.SustainPercent := 101;
  LFailed := False;
  try LApplied := ApplyMusicalSound(LVoice, LSound, 24000);
  except on E: EAudio do LFailed := True end;
  Check(LFailed and (LApplied.Envelope.SustainLevel = 0.25), 'Invalid controls preserve previous result');
  LSound.SustainPercent := 25;
  LCurve := TAutomationCurve.CreateLfo(100, alsSine);
  try
    LVoice.Automation.CutoffHz := LCurve;
    LFailed := False;
    try LApplied := ApplyMusicalSound(LVoice, LSound, 24000);
    except on E: EAudio do LFailed := True end;
    Check(LFailed, 'Existing automation is not silently overridden');
  finally LCurve.Free end;
end;

procedure Run;
var
  LClip: TAudioClip;
  LMeasured, LReplay: TMusicalObservations;
  LSpan: TPitchSpan;
  LProbe: TProbe;
  LTrack: TPitchTrack;
  LRegions: TPitchRegions;
  LSummaries: TPitchRegionSummaries;
  LGrid, LCopyGrid: TProposedMusicalGrid;
  LFailed: Boolean;
  LPitched: Integer;
  LEnd: Integer;
  I: Integer;
begin
  LClip := Tone(1, 1, False);
  try
    LMeasured := MeasureMusicalObservations(LClip);
    LReplay := MeasureMusicalObservations(LClip);
    Check(LMeasured.Tonal.CandidateCount = 24, 'Tonal alternatives available');
    Check(LMeasured.Tonal.Fits[0].Root = LReplay.Tonal.Fits[0].Root, 'Tonal replay');
    Check(LMeasured.Tonal.ScoreGap = LReplay.Tonal.ScoreGap, 'Fit score replay');
    Check((LMeasured.MeanCentroidHz > 200) and (LMeasured.MeanCentroidHz < 350), 'Tone centroid');
    Check(Length(LMeasured.ChannelPitches) = 1, 'Mono channel count');
    LPitched := 0;
    for LSpan in LMeasured.ChannelPitches[0] do
    begin
      if LSpan.Kind = pskPitch then
      begin
        Inc(LPitched);
        Check(LSpan.Note = 60, 'Controlled tone suggests middle C');
      end;
      Check((LSpan.StartFrame >= 0) and (LSpan.EndFrame <= 8000), 'Pitch extent bounded');
    end;
    Check(LPitched > 0, 'Controlled tone has pitches');
    Check(LMeasured.MaximumRms >= LMeasured.MinimumRms, 'RMS extent ordered');
    LGrid := ProposeMusicalGrid(LMeasured, 8000, 8000, 500000);
    Check((Length(LGrid.Frames) = 4) and (Length(LGrid.RoleNames) = 3),
      'Portable complete eighth-note grid with three explicit proposed roles');
    Check(LGrid.Known[1] and (LGrid.Frames[1][0].Tones[0].Pitch in [36..47]) and
      (LGrid.PitchOrigins[1] = mppPeriodic) and (LGrid.Frames[1][2].Tones[0].Pitch = 60),
      'Measured C supplies periodic lead and an explicitly arranged spectral bass');
    LCopyGrid := CopyProposedMusicalGrid(LGrid);
    LCopyGrid.Frames[0][0].Tones[0].Pitch := 1;
    LCopyGrid.RoleOrigins[0] := 'changed';
    Check((LGrid.Frames[0][0].Tones[0].Pitch <> 1) and
      (LGrid.RoleOrigins[0] <> 'changed'), 'Portable nested proposal copies detach');
    LCopyGrid := ProposeMusicalGrid(LMeasured, 8000, 8000, 500001);
    Check(Length(LCopyGrid.Frames) = 3, 'Incomplete fractional final cell is omitted, never rounded into the source');
    LCopyGrid := CopyProposedMusicalGrid(LGrid);
    LCopyGrid.Frames[0][0].Action := caHold;
    LFailed := False;
    try ValidateProposedMusicalGrid(LCopyGrid);
    except on E: EAudio do LFailed := True end;
    Check(LFailed, 'Proposal cannot begin with an invented held note');
    Check(Length(LMeasured.ChannelPitches[0]) = Length(LReplay.ChannelPitches[0]), 'Span count replay');
    LTrack := TPitchTrack.Create(LClip, 0, DefaultPitchTrackOptions(8000));
    try
      SetLength(LRegions, 2);
      LRegions[0].StartFrame := 0;
      LRegions[0].EndFrame := 4000;
      LRegions[1].StartFrame := 4000;
      LRegions[1].EndFrame := 8000;
      LSummaries := SummarizePitchRegions(LTrack, LRegions, DefaultPitchRegionOptions);
      Check((Length(LSummaries) = 2) and (LSummaries[0].Note = 60) and
        (LSummaries[1].Note = 60), 'Portable primary pitch-region summaries retain controlled pitches');
      Check((Length(LSummaries[0].Votes) = 1) and (Length(LSummaries[1].Votes) = 1),
        'Region vote buffers reset independently');
      Check(LSummaries[1].Votes[0].WindowCount = LSummaries[1].PeriodicWindows,
        'Region votes do not accumulate previous regions');
    finally
      LTrack.Free;
    end;
    LProbe := TProbe.Create;
    try
      LFailed := False;
      try
        LReplay := MeasureMusicalObservations(LClip, LProbe.Observe);
      except
        on E: ECancelled do LFailed := True;
      end;
      Check(LFailed, 'Cancellation propagates');
      Check(LReplay.Tonal.ScoreGap = LMeasured.Tonal.ScoreGap, 'Failed call preserves previous result');
    finally
      LProbe.Free;
    end;
  finally
    LClip.Free;
  end;
  LClip := Tone(1, 1, True);
  try
    LMeasured := MeasureMusicalObservations(LClip);
    Check(LMeasured.Tonal.CandidateCount = 0, 'Silence invents no key');
    Check(LMeasured.MeanCentroidHz = 0, 'Silence has zero brightness');
    LGrid := ProposeMusicalGrid(LMeasured, 8000, 8000, 500000);
    Check(not LGrid.HasSound, 'Silence invents no sound recipe');
    for I := 0 to High(LGrid.Frames) do
      Check(LGrid.Known[I] and (LGrid.PitchOrigins[I] = mppSilence) and
        (LGrid.Frames[I][0].Action = caRest) and (LGrid.Drums[I][0] = 0),
        'Measured silence remains known rest with no invented pitched/drum events');
    for LSpan in LMeasured.ChannelPitches[0] do
      Check(LSpan.Kind = pskSilence, 'Silence distinguished from unknown');
  finally
    LClip.Free;
  end;
  LClip := Tone(9, 2, True);
  try
    LMeasured := MeasureMusicalObservations(LClip);
    Check(LMeasured.PitchFrames = 64000, 'Pitch limited to eight seconds');
    Check(Length(LMeasured.ChannelPitches) = 2, 'Stereo channels kept separate');
    Check(LMeasured.Features[High(LMeasured.Features)].StartFrame > 64000, 'Spectrum covers beyond pitch bound');
    LGrid := ProposeMusicalGrid(LMeasured, 8000, 72000, 500000, 1);
    Check((Length(LGrid.Frames) = 36) and (LGrid.PitchOrigins[34] = mppSpectral),
      'Beyond eight seconds remains explicit spectral proposal, never claimed periodic transcription');
    for I := 0 to 1 do
    begin
      LPitched := 0;
      LEnd := 0;
      for LSpan in LMeasured.ChannelPitches[I] do
      begin
        Check(LSpan.StartFrame >= LEnd, 'Pitch spans ordered without fabricated edge coverage');
        Check(LSpan.EndFrame <= 64000, 'Stereo pitch extent bounded');
        LEnd := LSpan.EndFrame;
        if LSpan.Kind = pskPitch then
        begin
          Inc(LPitched);
          Check((I = 1) and (LSpan.Note = 69), 'Right-channel A kept separate from silent left');
        end;
      end;
      if I = 0 then Check(LPitched = 0, 'Silent left is not downmixed')
      else Check(LPitched > 0, 'Right-channel evidence available');
    end;
  finally
    LClip.Free;
  end;
  LClip := TAudioClip.Create(8000, 1, [0.1, -0.1]);
  try
    LMeasured := MeasureMusicalObservations(LClip);
    Check((Length(LMeasured.ChannelPitches) = 1) and
      (Length(LMeasured.ChannelPitches[0]) = 0), 'Very short audio keeps spectral evidence without inventing pitches');
    Check(Length(LMeasured.Features) = 1, 'Very short spectral window retained');
  finally
    LClip.Free;
  end;
  LClip := Tone(31, 1, True);
  try
    LFailed := False;
    try
      LMeasured := MeasureMusicalObservations(LClip);
    except
      on E: EAudio do LFailed := True;
    end;
    Check(LFailed, 'Oversize observation rejected before analysis');
  finally
    LClip.Free;
  end;
  LFailed := False;
  try
    LMeasured := MeasureMusicalObservations(nil);
  except
    on E: EAudio do LFailed := True;
  end;
  Check(LFailed, 'Nil source rejected');
end;

begin
  RunSound;
  Run;
  WriteLn('PASS musical observations: ', GChecks, ' checks');
end.
