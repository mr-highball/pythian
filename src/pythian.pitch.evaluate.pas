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
unit pythian.pitch.evaluate;

{$mode delphi}
{$H+}

interface

uses
  pythian.pitch.track;

const
  MaximumPitchReferenceNotes = 4096;
  MaximumPitchEvaluationPairs = 16777216;
  MaximumPitchReferenceFrame: Int64 = 9007199254740991;

type
  TPitchReferenceNote = record
    StartFrame: Int64;
    EndFrame: Int64;
    Note: Integer;
  end;
  TPitchReferenceNotes = array of TPitchReferenceNote;
  TPitchEvaluationOptions = record
    OnsetToleranceFrames: Integer;
    MinimumOffsetToleranceFrames: Integer;
    OffsetDurationFraction: Double;
    NoteEdgeFrames: Integer;
  end;
  TPitchNoteEvaluation = record
    ReferenceNotes: Integer;
    EstimatedNotes: Integer;
    MatchedOnsets: Integer;
    MatchedNotes: Integer;
    MatchedOnsetErrorFrames: Int64;
    MatchedOffsetErrorFrames: Int64;
  end;
  TPitchIntervalFrameEvaluation = record
    WindowCount: Integer;
    ReferenceActive: Integer;
    ReferenceRest: Integer;
    ReferenceAmbiguous: Integer;
    ReferenceOutsideRange: Integer;
    CorrectPitch: Integer;
    WrongPitch: Integer;
    WrongOctave: Integer;
    UnknownActive: Integer;
    FalsePitchInRest: Integer;
    UnknownRest: Integer;
    AmbiguousAdmitted: Integer;
    PitchCoverage: Double;
    PitchPrecision: Double;
  end;
  TPitchEvaluation = record
    WindowCount: Integer;
    ReferenceActive: Integer;
    ReferenceRest: Integer;
    ReferenceAmbiguous: Integer;
    ReferenceOutsideRange: Integer;
    CorrectPitch: Integer;
    WrongPitch: Integer;
    WrongOctave: Integer;
    UnknownActive: Integer;
    UnknownNoPeriod: Integer;
    UnknownOutsideRange: Integer;
    UnknownTuning: Integer;
    { UnknownTuning includes tuning tolerance and unsupported MIDI range. }
    UnknownShortRun: Integer;
    SilenceActive: Integer;
    FalsePitchInRest: Integer;
    UnknownRest: Integer;
    SilenceRest: Integer;
    AmbiguousAdmitted: Integer;
    ReferenceNotes: Integer;
    EstimatedNotes: Integer;
    ConsecutiveRepeatedReferences: Integer;
    MatchedOnsets: Integer;
    MatchedNotes: Integer;
    MatchedOnsetErrorFrames: Int64;
    MatchedOffsetErrorFrames: Int64;
  end;

function DefaultPitchEvaluationOptions(const ASampleRate: Integer): TPitchEvaluationOptions;
{ Evaluate explicit inferred note intervals without manufacturing raw pitch
  measurements. Both arrays use the same absolute frame timeline. Applies the
  common edge exclusion and ordered one-to-one matching used by track evaluation.
  Sorted overlaps are allowed; callers evaluate each attributed voice separately. }
function EvaluatePitchNoteIntervals(const AActual, AReferences: TPitchReferenceNotes;
  const AStartFrame, AEndFrame: Int64;
  const AOptions: TPitchEvaluationOptions): TPitchNoteEvaluation;
{ Score inferred monophonic intervals at the track's window centers, using only
  its geometry and supported frequency range, never its measured pitch labels.
  Both note arrays use absolute frames. Actual intervals must not overlap;
  ambiguous reference overlaps are reported and excluded, as in track scoring.
  Gaps mean unknown, not measured silence. No note-edge exclusion applies to
  frame scores. Inputs remain borrowed and unchanged. }
function EvaluatePitchIntervalFrames(const ATrack: TPitchTrack;
  const AActual, AReferences: TPitchReferenceNotes;
  const ASourceStartFrame: Int64): TPitchIntervalFrameEvaluation;
{ References use absolute frames at the track's rate; ASourceStartFrame maps
  local measured bins to that timeline. Sorted references may overlap: ambiguous
  centers are reported separately and excluded from pitch precision/coverage.
  Stable spans, not pre-run-filter candidates, supply estimated labels.
  Note matching is maximum ordered one-to-one matching, with exact semitone
  identity. A common edge exclusion applies to both reference and run intervals.
  Error sums are for onset-only matched pairs, including offset failures.
  Inputs remain borrowed and unchanged; no annotations enter pitch estimation. }
function EvaluatePitchTrack(const ATrack: TPitchTrack;
  const AReferences: TPitchReferenceNotes; const ASourceStartFrame: Int64;
  const AOptions: TPitchEvaluationOptions): TPitchEvaluation;
function PitchCoverage(const AResult: TPitchEvaluation): Double;
function PitchPrecision(const AResult: TPitchEvaluation): Double;
function NoteF1(const AMatched, AReference, AEstimated: Integer): Double;

implementation

uses
  Math,
  pythian.audio,
  pythian.pitch,
  pythian.oscillator;

type
  TMatchScore = record
    Count: Integer;
    OnsetError: Int64;
    OffsetError: Int64;
  end;
  TMatchScores = array of TMatchScore;

function DefaultPitchEvaluationOptions(const ASampleRate: Integer): TPitchEvaluationOptions;
begin
  ValidateAudioFormat(ASampleRate, 1);
  Result.OnsetToleranceFrames := Round(ASampleRate * 0.05);
  Result.MinimumOffsetToleranceFrames := Result.OnsetToleranceFrames;
  Result.OffsetDurationFraction := 0.2;
  Result.NoteEdgeFrames := Round(ASampleRate * 0.11);
end;

function Better(const ALeft, ARight: TMatchScore): TMatchScore;
begin
  if (ALeft.Count > ARight.Count) or
    ((ALeft.Count = ARight.Count) and (ALeft.OnsetError < ARight.OnsetError)) or
    ((ALeft.Count = ARight.Count) and (ALeft.OnsetError = ARight.OnsetError) and
      (ALeft.OffsetError <= ARight.OffsetError)) then
  begin
    Result := ALeft;
  end
  else
  begin
    Result := ARight;
  end;
end;

function MatchNotes(const AActual, AReference: TPitchReferenceNotes;
  const AOptions: TPitchEvaluationOptions; const AOffsets: Boolean): TMatchScore;
var
  LPrevious: TMatchScores;
  LCurrent: TMatchScores;
  LSwap: TMatchScores;
  LCandidate: TMatchScore;
  LOnsetError: Int64;
  LOffsetError: Int64;
  LOffsetLimit: Double;
  I: Integer;
  J: Integer;
begin
  if Int64(Length(AActual)) * Length(AReference) > MaximumPitchEvaluationPairs then
  begin
    raise EAudio.Create('Pitch note matching exceeds pair budget');
  end;
  SetLength(LPrevious, Length(AReference) + 1);
  SetLength(LCurrent, Length(AReference) + 1);
  for I := 1 to Length(AActual) do
  begin
    LCurrent[0] := Default(TMatchScore);
    for J := 1 to Length(AReference) do
    begin
      LCurrent[J] := Better(LPrevious[J], LCurrent[J - 1]);
      LOnsetError := Abs(AActual[I - 1].StartFrame - AReference[J - 1].StartFrame);
      LOffsetError := Abs(AActual[I - 1].EndFrame - AReference[J - 1].EndFrame);
      LOffsetLimit := Max(AOptions.MinimumOffsetToleranceFrames,
        (AReference[J - 1].EndFrame - AReference[J - 1].StartFrame) *
        AOptions.OffsetDurationFraction);
      if (AActual[I - 1].Note = AReference[J - 1].Note) and
        (LOnsetError <= AOptions.OnsetToleranceFrames) and
        (not AOffsets or (LOffsetError <= LOffsetLimit)) then
      begin
        LCandidate := LPrevious[J - 1];
        Inc(LCandidate.Count);
        Inc(LCandidate.OnsetError, LOnsetError);
        Inc(LCandidate.OffsetError, LOffsetError);
        LCurrent[J] := Better(LCurrent[J], LCandidate);
      end;
    end;
    LSwap := LPrevious;
    LPrevious := LCurrent;
    LCurrent := LSwap;
  end;
  Result := LPrevious[Length(AReference)];
end;

procedure ValidateNoteIntervals(const ANotes: TPitchReferenceNotes;
  const ANonoverlapping: Boolean);
var
  I: Integer;
begin
  for I := 0 to High(ANotes) do
  begin
    if (ANotes[I].StartFrame < 0) or (ANotes[I].EndFrame <= ANotes[I].StartFrame) or
      (ANotes[I].EndFrame > MaximumPitchReferenceFrame) or
      (ANotes[I].Note < 0) or (ANotes[I].Note > 127) or
      ((I > 0) and (ANotes[I].StartFrame < ANotes[I - 1].StartFrame)) then
    begin
      raise EAudio.Create('Note evaluation requires sorted valid absolute intervals');
    end;
    if ANonoverlapping and (I > 0) and
      (ANotes[I].StartFrame < ANotes[I - 1].EndFrame) then
    begin
      raise EAudio.Create('Frame evaluation requires nonoverlapping inferred notes');
    end;
  end;
end;

function EvaluatePitchIntervalFrames(const ATrack: TPitchTrack;
  const AActual, AReferences: TPitchReferenceNotes;
  const ASourceStartFrame: Int64): TPitchIntervalFrameEvaluation;
var
  LActualIndex: Integer;
  LNote: Integer;
  LReferenceNote: Integer;
  LCount: Integer;
  LCenter: Int64;
  I: Integer;
  J: Integer;
begin
  Result := Default(TPitchIntervalFrameEvaluation);
  if (ATrack = nil) or (ASourceStartFrame < 0) or
    (Length(AActual) > MaximumPitchTrackWindows) or
    (Length(AReferences) > MaximumPitchReferenceNotes) then
  begin
    raise EAudio.Create('Interval frame evaluation requires a track and bounded notes');
  end;
  if (ASourceStartFrame > MaximumPitchReferenceFrame - ATrack.FrameCount) or
    (Int64(ATrack.WindowCount) * Length(AReferences) > MaximumPitchEvaluationPairs) then
  begin
    raise EAudio.Create('Interval frame evaluation exceeds coordinate or work bounds');
  end;
  ValidateNoteIntervals(AActual, True);
  ValidateNoteIntervals(AReferences, False);
  LActualIndex := 0;
  Result.WindowCount := ATrack.WindowCount;
  for I := 0 to ATrack.WindowCount - 1 do
  begin
    LCenter := ASourceStartFrame + Int64(I) * ATrack.Options.HopFrames +
      ATrack.WindowFrames div 2;
    while (LActualIndex < Length(AActual)) and
      (AActual[LActualIndex].EndFrame <= LCenter) do
    begin
      Inc(LActualIndex);
    end;
    LNote := -1;
    if (LActualIndex < Length(AActual)) and
      (AActual[LActualIndex].StartFrame <= LCenter) then
    begin
      LNote := AActual[LActualIndex].Note;
    end;
    LCount := 0;
    LReferenceNote := -1;
    for J := 0 to High(AReferences) do
    begin
      if (AReferences[J].StartFrame <= LCenter) and (AReferences[J].EndFrame > LCenter) then
      begin
        Inc(LCount);
        LReferenceNote := AReferences[J].Note;
      end;
    end;
    if LCount > 1 then
    begin
      Inc(Result.ReferenceAmbiguous);
      if LNote >= 0 then
      begin
        Inc(Result.AmbiguousAdmitted);
      end;
    end
    else if LCount = 1 then
    begin
      Inc(Result.ReferenceActive);
      if (MidiFrequency(LReferenceNote) < ATrack.Options.Pitch.MinimumHz) or
        (MidiFrequency(LReferenceNote) > ATrack.Options.Pitch.MaximumHz) then
      begin
        Inc(Result.ReferenceOutsideRange);
      end;
      if LNote < 0 then
      begin
        Inc(Result.UnknownActive);
      end
      else if LNote = LReferenceNote then
      begin
        Inc(Result.CorrectPitch);
      end
      else
      begin
        Inc(Result.WrongPitch);
        if Abs(LNote - LReferenceNote) mod 12 = 0 then
        begin
          Inc(Result.WrongOctave);
        end;
      end;
    end
    else
    begin
      Inc(Result.ReferenceRest);
      if LNote >= 0 then
      begin
        Inc(Result.FalsePitchInRest);
      end
      else
      begin
        Inc(Result.UnknownRest);
      end;
    end;
  end;
  if Result.ReferenceActive > 0 then
  begin
    Result.PitchCoverage := Result.CorrectPitch / Result.ReferenceActive;
  end;
  LCount := Result.CorrectPitch + Result.WrongPitch + Result.FalsePitchInRest;
  if LCount > 0 then
  begin
    Result.PitchPrecision := Result.CorrectPitch / LCount;
  end;
end;

function EvaluatePitchNoteIntervals(const AActual, AReferences: TPitchReferenceNotes;
  const AStartFrame, AEndFrame: Int64;
  const AOptions: TPitchEvaluationOptions): TPitchNoteEvaluation;
var
  LActual: TPitchReferenceNotes;
  LReferences: TPitchReferenceNotes;
  LMatch: TMatchScore;

  function SelectInterior(const ANotes: TPitchReferenceNotes): TPitchReferenceNotes;
  var
    LCount: Integer;
    I: Integer;
  begin
    Result := nil;
    ValidateNoteIntervals(ANotes, False);
    SetLength(Result, Length(ANotes));
    LCount := 0;
    for I := 0 to High(ANotes) do
    begin
      if (ANotes[I].StartFrame >= AStartFrame + AOptions.NoteEdgeFrames) and
        (ANotes[I].EndFrame <= AEndFrame - AOptions.NoteEdgeFrames) then
      begin
        Result[LCount] := ANotes[I];
        Inc(LCount);
      end;
    end;
    SetLength(Result, LCount);
  end;

begin
  Result := Default(TPitchNoteEvaluation);
  if (AStartFrame < 0) or (AEndFrame <= AStartFrame) or
    (AEndFrame > MaximumPitchReferenceFrame) or
    (Length(AReferences) > MaximumPitchReferenceNotes) or
    (Length(AActual) > MaximumPitchTrackWindows) or
    (AOptions.OnsetToleranceFrames < 0) or
    (AOptions.MinimumOffsetToleranceFrames < 0) or (AOptions.NoteEdgeFrames < 0) then
  begin
    raise EAudio.Create('Note evaluation coordinates, counts or tolerances are invalid');
  end;
  RequireFinite(AOptions.OffsetDurationFraction, 'Offset duration tolerance');
  if (AOptions.OffsetDurationFraction < 0) or (AOptions.OffsetDurationFraction > 1) then
  begin
    raise EAudio.Create('Note evaluation offset fraction exceeds its bound');
  end;
  LActual := SelectInterior(AActual);
  LReferences := SelectInterior(AReferences);
  Result.ReferenceNotes := Length(LReferences);
  Result.EstimatedNotes := Length(LActual);
  LMatch := MatchNotes(LActual, LReferences, AOptions, False);
  Result.MatchedOnsets := LMatch.Count;
  Result.MatchedOnsetErrorFrames := LMatch.OnsetError;
  Result.MatchedOffsetErrorFrames := LMatch.OffsetError;
  LMatch := MatchNotes(LActual, LReferences, AOptions, True);
  Result.MatchedNotes := LMatch.Count;
end;

function EvaluatePitchTrack(const ATrack: TPitchTrack;
  const AReferences: TPitchReferenceNotes; const ASourceStartFrame: Int64;
  const AOptions: TPitchEvaluationOptions): TPitchEvaluation;
var
  LSpans: TPitchSpans;
  LRuns: TPitchRuns;
  LReferences: TPitchReferenceNotes;
  LActual: TPitchReferenceNotes;
  LReference: TPitchReferenceNote;
  LMatch: TMatchScore;
  LSpan: Integer;
  LCenter: Int64;
  LEnd: Int64;
  LCount: Integer;
  LReferenceNote: Integer;
  LKind: TPitchSpanKind;
  LNote: Integer;
  LEstimate: TPitchEstimate;
  I: Integer;
  J: Integer;
begin
  Result := Default(TPitchEvaluation);
  if (ATrack = nil) or (ASourceStartFrame < 0) or
    (Length(AReferences) > MaximumPitchReferenceNotes) then
  begin
    raise EAudio.Create('Pitch evaluation requires a track and bounded references');
  end;
  if (ASourceStartFrame > MaximumPitchReferenceFrame - ATrack.FrameCount) or
    (AOptions.OnsetToleranceFrames < 0) or
    (AOptions.MinimumOffsetToleranceFrames < 0) or (AOptions.NoteEdgeFrames < 0) then
  begin
    raise EAudio.Create('Pitch evaluation coordinates or tolerances are invalid');
  end;
  RequireFinite(AOptions.OffsetDurationFraction, 'Offset duration tolerance');
  if (AOptions.OffsetDurationFraction < 0) or (AOptions.OffsetDurationFraction > 1) or
    (Int64(ATrack.WindowCount) * Length(AReferences) > MaximumPitchEvaluationPairs) then
  begin
    raise EAudio.Create('Pitch evaluation exceeds fraction or frame/reference pair bound');
  end;
  LEnd := ASourceStartFrame + ATrack.FrameCount;
  SetLength(LReferences, Length(AReferences));
  LCount := 0;
  for I := 0 to High(AReferences) do
  begin
    LReference := AReferences[I];
    if (LReference.StartFrame < 0) or (LReference.EndFrame <= LReference.StartFrame) or
      (LReference.EndFrame > MaximumPitchReferenceFrame) or
      (LReference.Note < 0) or (LReference.Note > 127) or
      ((I > 0) and (LReference.StartFrame < AReferences[I - 1].StartFrame)) then
    begin
      raise EAudio.Create('Pitch reference notes require sorted valid absolute intervals');
    end;
    if (LReference.StartFrame >= ASourceStartFrame + AOptions.NoteEdgeFrames) and
      (LReference.EndFrame <= LEnd - AOptions.NoteEdgeFrames) then
    begin
      if (LCount > 0) and (LReferences[LCount - 1].Note = LReference.Note) then
      begin
        Inc(Result.ConsecutiveRepeatedReferences);
      end;
      LReferences[LCount] := LReference;
      Inc(LCount);
    end;
  end;
  SetLength(LReferences, LCount);
  LSpans := ATrack.CopySpans;
  LSpan := 0;
  Result.WindowCount := ATrack.WindowCount;
  for I := 0 to ATrack.WindowCount - 1 do
  begin
    while (LSpan < High(LSpans)) and
      (I >= LSpans[LSpan].FirstWindow + LSpans[LSpan].WindowCount) do
    begin
      Inc(LSpan);
    end;
    LKind := LSpans[LSpan].Kind;
    LNote := LSpans[LSpan].Note;
    LCenter := ASourceStartFrame + Int64(I) * ATrack.Options.HopFrames +
      ATrack.WindowFrames div 2;
    LCount := 0;
    LReferenceNote := -1;
    for J := 0 to High(AReferences) do
    begin
      if (AReferences[J].StartFrame <= LCenter) and (AReferences[J].EndFrame > LCenter) then
      begin
        Inc(LCount);
        LReferenceNote := AReferences[J].Note;
      end;
    end;
    if LCount > 1 then
    begin
      Inc(Result.ReferenceAmbiguous);
      if LKind = pskPitch then
      begin
        Inc(Result.AmbiguousAdmitted);
      end;
    end
    else if LCount = 1 then
    begin
      Inc(Result.ReferenceActive);
      if (MidiFrequency(LReferenceNote) < ATrack.Options.Pitch.MinimumHz) or
        (MidiFrequency(LReferenceNote) > ATrack.Options.Pitch.MaximumHz) then
      begin
        Inc(Result.ReferenceOutsideRange);
      end;
      case LKind of
        pskPitch:
          begin
            if LNote = LReferenceNote then
            begin
              Inc(Result.CorrectPitch);
            end
            else
            begin
              Inc(Result.WrongPitch);
              if Abs(LNote - LReferenceNote) mod 12 = 0 then
              begin
                Inc(Result.WrongOctave);
              end;
            end;
          end;
        pskSilence:
          begin
            Inc(Result.SilenceActive);
          end;
        pskUnknown:
          begin
            Inc(Result.UnknownActive);
            LEstimate := ATrack.EstimateAt(I);
            case LEstimate.Status of
              psSilence:
                begin
                  raise EAudio.Create('Unknown pitch span cannot contain measured silence');
                end;
              psNoPeriod:
                begin
                  Inc(Result.UnknownNoPeriod);
                end;
              psOutsideRange:
                begin
                  Inc(Result.UnknownOutsideRange);
                end;
              psEstimated:
                begin
                  if ATrack.NoteAt(I) < 0 then
                  begin
                    Inc(Result.UnknownTuning);
                  end
                  else
                  begin
                    Inc(Result.UnknownShortRun);
                  end;
                end;
            end;
          end;
      end;
    end
    else
    begin
      Inc(Result.ReferenceRest);
      case LKind of
        pskPitch:
          begin
            Inc(Result.FalsePitchInRest);
          end;
        pskSilence:
          begin
            Inc(Result.SilenceRest);
          end;
        pskUnknown:
          begin
            Inc(Result.UnknownRest);
          end;
      end;
    end;
  end;
  LRuns := ATrack.CopyRuns;
  SetLength(LActual, Length(LRuns));
  LCount := 0;
  for I := 0 to High(LRuns) do
  begin
    LReference.StartFrame := ASourceStartFrame + LRuns[I].StartFrame;
    LReference.EndFrame := ASourceStartFrame + LRuns[I].EndFrame;
    LReference.Note := LRuns[I].Note;
    if (LReference.StartFrame >= ASourceStartFrame + AOptions.NoteEdgeFrames) and
      (LReference.EndFrame <= LEnd - AOptions.NoteEdgeFrames) then
    begin
      LActual[LCount] := LReference;
      Inc(LCount);
    end;
  end;
  SetLength(LActual, LCount);
  Result.ReferenceNotes := Length(LReferences);
  Result.EstimatedNotes := Length(LActual);
  LMatch := MatchNotes(LActual, LReferences, AOptions, False);
  Result.MatchedOnsets := LMatch.Count;
  Result.MatchedOnsetErrorFrames := LMatch.OnsetError;
  Result.MatchedOffsetErrorFrames := LMatch.OffsetError;
  LMatch := MatchNotes(LActual, LReferences, AOptions, True);
  Result.MatchedNotes := LMatch.Count;
end;

function PitchCoverage(const AResult: TPitchEvaluation): Double;
begin
  Result := 0;
  if AResult.ReferenceActive > 0 then
  begin
    Result := AResult.CorrectPitch / AResult.ReferenceActive;
  end;
end;

function PitchPrecision(const AResult: TPitchEvaluation): Double;
var
  LAdmitted: Integer;
begin
  LAdmitted := AResult.CorrectPitch + AResult.WrongPitch + AResult.FalsePitchInRest;
  Result := 0;
  if LAdmitted > 0 then
  begin
    Result := AResult.CorrectPitch / LAdmitted;
  end;
end;

function NoteF1(const AMatched, AReference, AEstimated: Integer): Double;
begin
  if (AMatched < 0) or (AReference < AMatched) or (AEstimated < AMatched) then
  begin
    raise EAudio.Create('Note counts are inconsistent');
  end;
  Result := 0;
  if (AReference > 0) or (AEstimated > 0) then
  begin
    { Keep intermediates Double: an untyped 2.0 literal can select Single
      arithmetic on SSE targets before assignment to the Double result. }
    Result := AMatched;
    Result := Result * 2;
    Result := Result / (Int64(AReference) + AEstimated);
  end;
end;

end.
