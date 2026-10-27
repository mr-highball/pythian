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
program pythian_tests_pitch_learning_progress;

{$mode delphi}
{$H+}

uses
  SysUtils,
  Math,
  pythian.audio,
  pythian.analysis,
  pythian.onset,
  pythian.progress,
  pythian.pitch,
  pythian.pitch.cells,
  pythian.pitch.track,
  pythian.tonal,
  pythian.tools.files,
  pythian.music.context,
  pythian.wfc.context,
  pythian.wfc.context.profile,
  pythian.wfc.context.archive,
  pythian.wfc.pitch,
  pythian.wfc.style,
  wfc_sequence,
  wfc_sequence_text;

type
  TObserver = class
  public
    AbortStage: String;
    Marker: Exception;
    ValidationTotal: Int64;
    WeightedTotal: Int64;
    Calls: Integer;
    PitchPasses: Integer;
    AbortPitchPass: Integer;
    SawDuration: Boolean;
    procedure Observe(const AProgress: TWorkProgress);
  end;

var
  LChecks: Integer;
  LNotes: TPitchTracks;
  LPatterns: TPitchRhythmPatterns;
  LTimed: TTimedPitchTracks;
  LMeasured: TMeasuredPitchTracks;
  LWeights: array of Integer;
  LObserver: TObserver;

procedure Check(const ACondition: Boolean; const AMessage: String);
begin
  Inc(LChecks);
  if not ACondition then
  begin
    raise Exception.Create(AMessage);
  end;
end;

procedure TObserver.Observe(const AProgress: TWorkProgress);
begin
  Inc(Calls);
  if (AProgress.Done < 0) or (AProgress.Total < 0) or
    ((AProgress.Total > 0) and (AProgress.Done > AProgress.Total)) then
  begin
    raise Exception.Create('Invalid progress counts');
  end;
  if (AProgress.Stage = 'pitch_validate_cells') and (AProgress.Done = 0) then
  begin
    Inc(PitchPasses);
  end;
  if AProgress.Stage = 'pitch_duration_spans' then
  begin
    SawDuration := True;
  end;
  if (AProgress.Stage = AbortStage) and (AProgress.Done >= 256) and
    (AProgress.Total = 0) and
    ((AbortPitchPass = 0) or (PitchPasses = AbortPitchPass)) then
  begin
    raise Marker;
  end;
  if (AProgress.Stage = 'pitch_validate_cells') and (AProgress.Total > 0) then
  begin
    ValidationTotal := AProgress.Done;
  end;
  if ((AProgress.Stage = 'pitch_weighted_cells') or
    (AProgress.Stage = 'pitch_duration_weighted')) and (AProgress.Total > 0) then
  begin
    WeightedTotal := AProgress.Done;
  end;
end;

function Learn(const AVariant: Integer; const AObserved: Boolean): String;
var
  LModel: TWfcSequenceModel;
  LCallback: TWorkProgressCallback;
begin
  LCallback := nil;
  if AObserved then
  begin
    LCallback := LObserver.Observe;
  end;
  LModel := nil;
  try
    case AVariant of
      0:
        begin
          LModel := LearnPitchModel(LNotes, LWeights, 2, LCallback);
        end;
      1:
        begin
          LModel := LearnPitchRhythmModel(LNotes, LPatterns, LWeights, 2, LCallback);
        end;
      2:
        begin
          LModel := LearnPitchDurationModel(LTimed, LWeights, 2, LCallback);
        end;
      3:
        begin
          LModel := LearnPitchDurationModel(LMeasured, LWeights, 2, LCallback);
        end;
    end;
    Result := EncodeWfcSequenceText(LModel);
  finally
    LModel.Free;
  end;
end;

procedure AbortAndRetry(const AVariant: Integer; const AStage, AExpected: String);
var
  LRejected: Boolean;
begin
  LRejected := False;
  LObserver.AbortStage := AStage;
  LObserver.Marker := Exception.Create('owned observer marker');
  try
    try
      Learn(AVariant, True);
    except
      on LException: Exception do
      begin
        if LException <> LObserver.Marker then
        begin
          raise;
        end;
        LRejected := True;
        LObserver.Marker := nil;
      end;
    end;
  finally
    LObserver.Marker.Free;
    LObserver.Marker := nil;
    LObserver.AbortStage := '';
  end;
  Check(LRejected, 'Expected original exception at ' + AStage);
  Check(Learn(AVariant, True) = AExpected, 'Retry differs after ' + AStage);
end;

function SameBytes(const ALeft, ARight: TAudioBytes): Boolean;
var
  LIndex: Integer;
begin
  Result := Length(ALeft) = Length(ARight);
  if not Result then
  begin
    Exit;
  end;
  for LIndex := 0 to High(ALeft) do
  begin
    if ALeft[LIndex] <> ARight[LIndex] then
    begin
      Exit(False);
    end;
  end;
end;

function DeclaredPitch(const ANote: Integer): TPitchEstimate;
begin
  Result := Default(TPitchEstimate);
  Result.Status := psEstimated;
  Result.FrequencyHz := 440 * Power(2, (ANote - 69) / 12);
  Result.PeriodFrames := 1000 / Result.FrequencyHz;
  Result.AcRms := 0.1;
  Result.NearestMidi := ANote;
  Result.CentsError := 100 * (69 + 12 * Log2(Result.FrequencyHz / 440) - ANote);
end;

function SourceBytes(const AContext: TContextProfile;
  const AEvidence: TRhythmStyleEvidence; const AObserved: Boolean): TAudioBytes;
var
  LProfile: TWaveStyleProfile;
  LCallback: TWorkProgressCallback;
begin
  LCallback := nil;
  if AObserved then
  begin
    LCallback := LObserver.Observe;
  end;
  LObserver.PitchPasses := 0;
  LObserver.SawDuration := False;
  LProfile := TWaveStyleProfile.CreateSource(AContext, AEvidence, 2, LCallback);
  try
    Check(LProfile.HasPitch and LProfile.HasPitchRhythm and LProfile.HasDuration,
      'Real source must exercise pitch, paired rhythm and duration learning');
    Result := LProfile.Encode;
  finally
    LProfile.Free;
  end;
end;

procedure RetainedSourceChecks;
const
  CCells = 600;
var
  LEvidence: TRhythmStyleEvidence;
  LContextEvidence: TContextEvidenceArray;
  LBundle: TContextLearningBundle;
  LContext: TContextProfile;
  LUnpublished: TWaveStyleProfile;
  LExpected: TAudioBytes;
  LContextBefore: TAudioBytes;
  LIndex: Integer;
  LVariant: Integer;
  LRejected: Boolean;
begin
  LEvidence := Default(TRhythmStyleEvidence);
  LEvidence.Source.Name := 'Declared pitch progress source';
  LEvidence.Source.Sha256 := HashText(LEvidence.Source.Name);
  LEvidence.Source.Provenance := 'Authored callback fixture; no recorded musical accuracy claim';
  LEvidence.Source.SampleRate := 1000;
  LEvidence.Source.Channels := 1;
  LEvidence.Source.FrameCount := CCells * 250;
  LEvidence.OnsetReportSha256 := HashText('Declared source onsets');
  LEvidence.Analysis := DefaultAnalysisOptions;
  LEvidence.OnsetVersion := OnsetLocationVersion;
  LEvidence.Policy := 'Explicit source clock and authored pitch declarations';
  LEvidence.TempoMicroseconds := 500000;
  SetLength(LEvidence.OnsetFrames, CCells div 2);
  LEvidence.Pitch.WindowFrames := 40;
  LEvidence.Pitch.Options := DefaultPitchOptions;
  LEvidence.Pitch.Options.MaximumHz := 440;
  LEvidence.Pitch.MaximumCents := 25;
  SetLength(LEvidence.Pitch.Cells, CCells);
  LEvidence.Duration.WindowFrames := 40;
  LEvidence.Duration.Options := DefaultPitchTrackOptions(1000);
  LEvidence.Duration.Options.Pitch := LEvidence.Pitch.Options;
  LEvidence.Duration.Options.HopFrames := 20;
  SetLength(LEvidence.Duration.Estimates,
    1 + (LEvidence.Source.FrameCount - LEvidence.Duration.WindowFrames) div 20);
  SetLength(LContextEvidence, 1);
  LContextEvidence[0].Name := LEvidence.Source.Name;
  LContextEvidence[0].SourceSha256 := LEvidence.Source.Sha256;
  LContextEvidence[0].AdmissionPolicy := LEvidence.Policy;
  LContextEvidence[0].Grid.TicksPerQuarter := 480;
  LContextEvidence[0].Grid.StepTicks := 240;
  SetLength(LContextEvidence[0].Grid.Keys, CCells);
  SetLength(LContextEvidence[0].Grid.Tempos, CCells);
  for LIndex := 0 to CCells - 1 do
  begin
    LContextEvidence[0].Grid.Keys[LIndex] := MakeKeyContext(0, dmMajor);
    LContextEvidence[0].Grid.Tempos[LIndex] := 500000;
    LEvidence.Pitch.Cells[LIndex].Measured := True;
    LEvidence.Pitch.Cells[LIndex].Estimate := DeclaredPitch(60 + (LIndex div 2) mod 3);
  end;
  for LIndex := 0 to High(LEvidence.OnsetFrames) do
  begin
    LEvidence.OnsetFrames[LIndex] := LIndex * 500;
  end;
  for LIndex := 0 to High(LEvidence.Duration.Estimates) do
  begin
    LEvidence.Duration.Estimates[LIndex] := DeclaredPitch(60 + (LIndex div 25) mod 3);
  end;
  LBundle := TContextLearningBundle.Create(LContextEvidence);
  LContext := nil;
  try
    LContext := TContextProfile.Create(LBundle);
    LContextBefore := EncodeContextProfile(LContext);
    LExpected := SourceBytes(LContext, LEvidence, False);
    Check(SameBytes(SourceBytes(LContext, LEvidence, True), LExpected),
      'Retained source nil/observed archive bytes differ');
    Check((LObserver.PitchPasses = 2) and LObserver.SawDuration,
      'Retained source did not forward all three pitch-learning paths');
    for LVariant := 0 to 2 do
    begin
      LObserver.AbortStage := 'pitch_encode_cells';
      LObserver.AbortPitchPass := LVariant + 1;
      if LVariant = 2 then
      begin
        LObserver.AbortStage := 'pitch_duration_spans';
        LObserver.AbortPitchPass := 0;
      end;
      LObserver.PitchPasses := 0;
      LObserver.Marker := Exception.Create('retained source marker');
      LRejected := False;
      LUnpublished := nil;
      try
        try
          LUnpublished := TWaveStyleProfile.CreateSource(LContext, LEvidence, 2,
            LObserver.Observe);
        except
          on LException: Exception do
          begin
            if LException <> LObserver.Marker then
            begin
              raise;
            end;
            LRejected := True;
            LObserver.Marker := nil;
          end;
        end;
        Check(LRejected and (LUnpublished = nil),
          'Retained source must propagate the original exception without publication');
      finally
        LUnpublished.Free;
        LObserver.Marker.Free;
        LObserver.Marker := nil;
        LObserver.AbortStage := '';
        LObserver.AbortPitchPass := 0;
      end;
      Check(SameBytes(EncodeContextProfile(LContext), LContextBefore),
        'Retained source changed borrowed context');
      Check(SameBytes(SourceBytes(LContext, LEvidence, True), LExpected),
        'Retained source changed borrowed evidence or retry result');
    end;
  finally
    LContext.Free;
    LBundle.Free;
  end;
end;

var
  LEvidence: TPitchTrackEvidence;
  LVariant: Integer;
  LIndex: Integer;
  LSource: Integer;
  LExpected: String;
  LRejected: Boolean;
begin
  LObserver := TObserver.Create;
  try
    SetLength(LNotes, 2);
    SetLength(LPatterns, 2);
    SetLength(LTimed, 2);
    SetLength(LMeasured, 2);
    SetLength(LWeights, 2);
    LWeights[0] := 2;
    LWeights[1] := 0;
    LEvidence := Default(TPitchTrackEvidence);
    LEvidence.WindowFrames := 294;
    LEvidence.Options := DefaultPitchTrackOptions(8000);
    LEvidence.Options.HopFrames := 80;
    SetLength(LEvidence.Estimates, 600);
    for LSource := 0 to 1 do
    begin
      SetLength(LNotes[LSource], 600);
      LPatterns[LSource] := StringOfChar('3', 600);
      SetLength(LTimed[LSource], 600);
      for LIndex := 0 to 599 do
      begin
        LNotes[LSource][LIndex] := 60 + (LIndex mod 3);
        if LIndex mod 31 = 0 then
        begin
          LNotes[LSource][LIndex] := -1;
        end;
        LTimed[LSource][LIndex].Kind := pskPitch;
        LTimed[LSource][LIndex].Note := 60 + (LIndex mod 3);
        LTimed[LSource][LIndex].StartTick := LIndex;
        LTimed[LSource][LIndex].EndTick := LIndex + 1;
        LEvidence.Estimates[LIndex].NearestMidi := -1;
        if LIndex mod 2 = 0 then
        begin
          LEvidence.Estimates[LIndex].Status := psSilence
        end
        else
        begin
          LEvidence.Estimates[LIndex].Status := psNoPeriod;
          LEvidence.Estimates[LIndex].AcRms := 1;
        end;
      end;
      LMeasured[LSource] := TPitchTrack.CreateFromEvidence(LEvidence, 8000, 1, 294 + 599 * 80);
    end;
    for LVariant := 0 to 3 do
    begin
      LExpected := Learn(LVariant, False);
      Check(Learn(LVariant, True) = LExpected, 'Observed model differs');
      if LVariant < 2 then
      begin
        Check(LObserver.ValidationTotal = 1200, 'Raw validation excludes zero-weight source');
        Check(LObserver.WeightedTotal = 1160, 'Weighted observations differ');
        AbortAndRetry(LVariant, 'pitch_validate_cells', LExpected);
        AbortAndRetry(LVariant, 'pitch_scan_cells', LExpected);
        AbortAndRetry(LVariant, 'pitch_encode_cells', LExpected);
        AbortAndRetry(LVariant, 'pitch_weighted_cells', LExpected);
      end
      else
      begin
        Check(LObserver.WeightedTotal = 1200, 'Duration weighted observations differ');
        AbortAndRetry(LVariant, 'pitch_duration_spans', LExpected);
        AbortAndRetry(LVariant, 'pitch_duration_weighted', LExpected);
        if LVariant = 3 then
        begin
          AbortAndRetry(LVariant, 'pitch_measured_spans', LExpected);
        end;
      end;
    end;
    Check((LNotes[0][0] = -1) and (LNotes[1][599] = 62) and
      (LTimed[0][599].EndTick = 600) and (LMeasured[0].WindowCount = 600),
      'Borrowed inputs changed');
    LExpected := Learn(0, False);
    for LIndex := 0 to 599 do
    begin
      if LNotes[0][LIndex] = -1 then
      begin
        LNotes[0][LIndex] := 60;
      end;
    end;
    Check(Learn(0, False) <> LExpected, 'Unknown cells must separate runs');
    LNotes[1][0] := 128;
    LRejected := False;
    try
      Learn(0, False);
    except
      on LException: Exception do
      begin
        LRejected := True;
      end;
    end;
    Check(LRejected, 'Invalid zero-weight source must still be validated');
    RetainedSourceChecks;
    Check(LObserver.Calls < 2000, 'Progress cadence must remain aggregated');
    WriteLn('Pitch learning progress: ', LChecks, ' checks passed');
  finally
    for LSource := 0 to High(LMeasured) do
    begin
      LMeasured[LSource].Free;
    end;
    LObserver.Free;
  end;
end.
