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
  pythian.tonal, pythian.pitch.track, pythian.pitch.regions;

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

procedure Run;
var
  LClip: TAudioClip;
  LMeasured, LReplay: TMusicalObservations;
  LSpan: TPitchSpan;
  LProbe: TProbe;
  LTrack: TPitchTrack;
  LRegions: TPitchRegions;
  LSummaries: TPitchRegionSummaries;
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
  Run;
  WriteLn('PASS musical observations: ', GChecks, ' checks');
end.
