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
program EvaluationProgress;
{$mode delphi}
{$H+}
uses SysUtils, pythian.progress, pythian.evaluation, pythian.evaluation.notes,
  pythian.pitch.evaluate, pythian.pitch.track, pythian.pitch;
type
  EProbe = class(Exception);
  TProbe = class
    AbortStage: String;
    Calls: Integer;
    SawRegion: Boolean;
    SawCandidates: Boolean;
    SawMatching: Boolean;
    SawPitch: Boolean;
    FinalRegion: Int64;
    FinalCandidates: Int64;
    FinalMatching: Int64;
    procedure Work(const AWork: TWorkProgress);
  end;
var
  Count: Integer;
procedure Check(const V: Boolean; const S: String);
begin
  Inc(Count);
  if not V then
  begin
    raise Exception.Create(S);
  end;
end;
procedure TProbe.Work(const AWork: TWorkProgress);
begin
  Inc(Calls);
  Check((AWork.Units = wuItems) and (AWork.Done >= 0) and
    ((AWork.Total = 0) or (AWork.Done <= AWork.Total)), 'Valid measured work');
  if (AWork.Stage = 'evaluation_note_regions') and (AWork.Done >= 4096) then
  begin
    SawRegion := True;
  end;
  if (AWork.Total > 0) and (AWork.Done = AWork.Total) then
  begin
    if AWork.Stage = 'evaluation_note_regions' then
    begin
      FinalRegion := AWork.Done;
    end;
    if AWork.Stage = 'evaluation_note_candidates' then
    begin
      FinalCandidates := AWork.Done;
    end;
    if AWork.Stage = 'evaluation_note_matching' then
    begin
      FinalMatching := AWork.Done;
    end;
  end;
  if (AWork.Stage = 'evaluation_note_candidates') and (AWork.Done >= 4096) then
  begin
    SawCandidates := True;
  end;
  if (AWork.Stage = 'evaluation_note_matching') and (AWork.Done >= 4096) then
  begin
    SawMatching := True;
  end;
  if (AWork.Stage = 'evaluation_pitch_pairs') and (AWork.Done >= 4096) then
  begin
    SawPitch := True;
  end;
  if (AWork.Stage = AbortStage) and (AWork.Done >= 4096) then
  begin
    raise EProbe.Create('original');
  end;
end;
var
  R: TEvaluationNotes;
  P: TEvaluationNotes;
  Regions: TEvaluationNoteRegions;
  Opt: TOverlappingNoteOptions;
  X: TOverlappingNoteEvaluation;
  Y: TOverlappingNoteEvaluation;
  Actual: TPitchReferenceNotes;
  Reference: TPitchReferenceNotes;
  PitchOpt: TPitchEvaluationOptions;
  PX: TPitchNoteEvaluation;
  PY: TPitchNoteEvaluation;
  Probe: TProbe;
  I: Integer;
  Failed: Boolean;
  Evidence: TPitchTrackEvidence;
  Track: TPitchTrack;
  FrameA: TPitchIntervalFrameEvaluation;
  FrameB: TPitchIntervalFrameEvaluation;
  TrackA: TPitchEvaluation;
  TrackB: TPitchEvaluation;
  Stage: String;
begin
  Probe := TProbe.Create;
  try
    SetLength(R, 70);
    SetLength(P, 70);
    SetLength(Regions, 70);
    for I := 0 to 69 do
    begin
      R[I].Id := 'r' + IntToStr(I);
      R[I].StartFrame := 100;
      R[I].EndFrame := 200;
      R[I].Pitch := 60;
      P[I] := R[I];
      P[I].Id := 'p' + IntToStr(I);
      Regions[I].FirstFrame := I * 10;
      Regions[I].EndFrame := (I + 1) * 10;
      Regions[I].State := esValue;
    end;
    Opt := Default(TOverlappingNoteOptions);
    Opt.OffsetFractionDenominator := 1;
    X := EvaluateOverlappingNotes(R, P, Regions, 0, 700, Opt);
    Y := EvaluateOverlappingNotes(R, P, Regions, 0, 700, Opt, MaximumNoteMatchingWork, Probe.Work);
    Check((X.MatchingWork = Y.MatchingWork) and (X.CandidateChecks = Y.CandidateChecks) and
      (Length(X.Onsets.Pairs) = Length(Y.Onsets.Pairs)) and
      (Length(X.FullNotes.Pairs) = Length(Y.FullNotes.Pairs)), 'Note results preserved');
    Check((Probe.FinalRegion = 9800) and (Probe.FinalCandidates = Y.CandidateChecks) and
      (Probe.FinalMatching = Y.MatchingWork), 'Final totals equal actual completed work');
    Check(Probe.SawRegion and Probe.SawCandidates and Probe.SawMatching and
      (Probe.Calls < 10000), 'All dense note phases bounded');
    for I := 0 to 2 do
    begin
      case I of
        0: Stage := 'evaluation_note_regions';
        1: Stage := 'evaluation_note_candidates';
        else Stage := 'evaluation_note_matching';
      end;
      Probe.AbortStage := Stage;
      Failed := False;
      try
        Y := EvaluateOverlappingNotes(R, P, Regions, 0, 700, Opt, MaximumNoteMatchingWork, Probe.Work);
      except
        on E: EProbe do
        begin
          Failed := E.Message = 'original';
        end;
      end;
      Check(Failed, 'Note phase abort preserved');
    end;
    Probe.AbortStage := '';
    Y := EvaluateOverlappingNotes(R, P, Regions, 0, 700, Opt, MaximumNoteMatchingWork, Probe.Work);
    Check(X.MatchingWork = Y.MatchingWork, 'Note retry matches');
    SetLength(Actual, 100);
    SetLength(Reference, 100);
    for I := 0 to 99 do
    begin
      Actual[I].StartFrame := I * 100;
      Actual[I].EndFrame := I * 100 + 50;
      Actual[I].Note := 60;
      Reference[I] := Actual[I];
    end;
    PitchOpt := DefaultPitchEvaluationOptions(8000);
    PitchOpt.NoteEdgeFrames := 0;
    PX := EvaluatePitchNoteIntervals(Actual, Reference, 0, 11000, PitchOpt);
    Probe.Calls := 0;
    PY := EvaluatePitchNoteIntervals(Actual, Reference, 0, 11000, PitchOpt, Probe.Work);
    Check((PX.MatchedNotes = PY.MatchedNotes) and (PX.MatchedOnsets = PY.MatchedOnsets) and
      (PX.MatchedOffsetErrorFrames = PY.MatchedOffsetErrorFrames), 'Pitch results preserved');
    Check(Probe.SawPitch and (Probe.Calls < 20), 'Pitch pair callbacks bounded');
    Probe.AbortStage := 'evaluation_pitch_pairs';
    Failed := False;
    try
      PY := EvaluatePitchNoteIntervals(Actual, Reference, 0, 11000, PitchOpt, Probe.Work);
    except
      on E: EProbe do
      begin
        Failed := E.Message = 'original';
      end;
    end;
    Check(Failed, 'Pitch abort preserved');
    Probe.AbortStage := '';
    PY := EvaluatePitchNoteIntervals(Actual, Reference, 0, 11000, PitchOpt, Probe.Work);
    Check(PX.MatchedNotes = PY.MatchedNotes, 'Pitch retry matches');
    Evidence := Default(TPitchTrackEvidence);
    Evidence.Options := DefaultPitchTrackOptions(8000);
    Evidence.WindowFrames := 294;
    SetLength(Evidence.Estimates, 100);
    for I := 0 to 99 do
    begin
      Evidence.Estimates[I].Status := psSilence;
      Evidence.Estimates[I].NearestMidi := -1;
    end;
    Track := TPitchTrack.CreateFromEvidence(Evidence, 8000, 1,
      294 + 99 * Evidence.Options.HopFrames);
    try
      FrameA := EvaluatePitchIntervalFrames(Track, nil, Reference, 0);
      FrameB := EvaluatePitchIntervalFrames(Track, nil, Reference, 0, Probe.Work);
      Check((FrameA.ReferenceActive = FrameB.ReferenceActive) and
        (FrameA.UnknownActive = FrameB.UnknownActive), 'Interval frame parity');
      TrackA := EvaluatePitchTrack(Track, Reference, 0, PitchOpt);
      TrackB := EvaluatePitchTrack(Track, Reference, 0, PitchOpt, Probe.Work);
      Check((TrackA.ReferenceActive = TrackB.ReferenceActive) and
        (TrackA.UnknownActive = TrackB.UnknownActive), 'Track frame parity');
      Probe.AbortStage := 'evaluation_pitch_frames';
      Failed := False;
      try
        FrameB := EvaluatePitchIntervalFrames(Track, nil, Reference, 0, Probe.Work);
      except
        on E: EProbe do
        begin
          Failed := E.Message = 'original';
        end;
      end;
      Check(Failed, 'Interval scan interior abort');
      Failed := False;
      try
        TrackB := EvaluatePitchTrack(Track, Reference, 0, PitchOpt, Probe.Work);
      except
        on E: EProbe do
        begin
          Failed := E.Message = 'original';
        end;
      end;
      Check(Failed, 'Track scan interior abort');
      Probe.AbortStage := '';
      FrameB := EvaluatePitchIntervalFrames(Track, nil, Reference, 0, Probe.Work);
      Check(FrameA.ReferenceActive = FrameB.ReferenceActive, 'Frame retry matches');
    finally
      Track.Free;
    end;
    WriteLn('PASS ', Count, ' evaluation progress checks');
  finally
    Probe.Free;
  end;
end.
