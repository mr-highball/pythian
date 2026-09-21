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

program pythian_style;

{$mode delphi}
{$H+}

uses
  SysUtils,
  Math,
  fpjson,
  jsonparser,
  pythian.audio,
  pythian.time,
  pythian.music.grid.frames,
  pythian.corpus,
  pythian.onset,
  pythian.onset.events,
  pythian.onset.dynamics,
  pythian.pitch,
  pythian.pitch.cells,
  pythian.pitch.track,
  pythian.source.wavetable,
  pythian.envelope,
  pythian.rhythm.admission,
  pythian.wfc.context,
  pythian.wfc.context.archive,
  pythian.wfc.context.profile,
  pythian.wfc.style,
  pythian.wfc.layers,
  pythian.wfc.providers,
  pythian.wfc.grid,
  pythian.wfc.performance,
  pythian.tools.files,
  pythian.tools.events,
  wfc_sequence,
  wfc_sequence_text;

procedure ProtectOutput(const AOutput, AInput: String);
begin
  if SameFileName(ExpandFileName(AOutput), ExpandFileName(AInput)) then
  begin
    raise EAudio.Create('Style output must not replace an input');
  end;
end;

function ReadJson(const AFileName: String; out ASha256: String): TJSONData;
var
  LBytes: TAudioBytes;
  LText: String;
begin
  LBytes := ReadFileBytes(AFileName, 16 * 1024 * 1024);
  ASha256 := HashAudioBytes(LBytes);
  SetLength(LText, Length(LBytes));
  if Length(LBytes) > 0 then
  begin
    Move(LBytes[0], LText[1], Length(LBytes));
  end;
  Result := GetJSON(LText);
end;

procedure Learn;
var
  LContext: TContextProfile;
  LBundle: TContextLearningBundle;
  LContextEvidence: TContextEvidenceArray;
  LStyle: TWaveStyleProfile;
  LSource: TAudioClip;
  LEvidence: TRhythmStyleEvidence;
  LJson: TJSONData;
  LLocations: TOnsetLocations;
  LPlan: TOnsetEventPlan;
  LIndex: Integer;
  LCount: Integer;
  LOnsetOptions: TOnsetEventOptions;
  LDurationTrack: TPitchTrack;
  LGrid: TMusicGridFrames;
  LClockCount: Integer;
  LUseDurationOnsets: Boolean;
  LWindowFrames: Integer;
  LHasWindow: Boolean;
  LArgument: Integer;
  LProvenance: String;
begin
  LUseDurationOnsets := False;
  LWindowFrames := 0;
  LHasWindow := False;
  LProvenance := '';
  LArgument := 9;
  while LArgument <= ParamCount do
  begin
    if ParamStr(LArgument) = '--articulate-onsets' then
    begin
      if (ParamStr(1) <> 'learn-duration') or LUseDurationOnsets then
      begin
        raise EAudio.Create('Onset articulation requires duration learning and one policy flag');
      end;
      LUseDurationOnsets := True;
    end
    else if ParamStr(LArgument) = '--window-frames' then
    begin
      if (ParamStr(1) <> 'learn-duration') or LHasWindow or
        (LArgument = ParamCount) then
      begin
        raise EAudio.Create('Explicit pitch window requires duration learning and one frame count');
      end;
      Inc(LArgument);
      LWindowFrames := StrToInt(ParamStr(LArgument));
      if (LWindowFrames < 1) or (LWindowFrames > MaximumPitchWindowFrames) then
      begin
        raise EAudio.Create('Explicit pitch window must be 1..8192 frames and cover the frequency range');
      end;
      LHasWindow := True;
    end
    else if (LArgument = ParamCount) and (Copy(ParamStr(LArgument), 1, 2) <> '--') then
    begin
      LProvenance := ParamStr(LArgument);
    end
    else
    begin
      raise EAudio.Create('Unknown learning option; provenance must be the final argument');
    end;
    Inc(LArgument);
  end;
  ProtectOutput(ParamStr(6), ParamStr(2));
  ProtectOutput(ParamStr(6), ParamStr(3));
  ProtectOutput(ParamStr(6), ParamStr(4));
  LContext := nil;
  LBundle := nil;
  LStyle := nil;
  LSource := nil;
  LJson := nil;
  LDurationTrack := nil;
  LGrid := nil;
  try
    LContext := DecodeContextProfile(ReadFileBytes(ParamStr(2), MaximumContextProfileBytes));
    LBundle := LContext.CopyBundle(cdTempo);
    LContextEvidence := LBundle.CopyEvidence;
    if Length(LContextEvidence) <> 1 then
    begin
      raise EAudio.Create('Learning rhythm requires one admitted source tempo provider');
    end;
    LEvidence := Default(TRhythmStyleEvidence);
    LSource := LoadWaveSource(ParamStr(3), LEvidence.Source.Sha256);
    LEvidence.Source.Name := ExtractFileName(ParamStr(3));
    LEvidence.Source.SampleRate := LSource.SampleRate;
    LEvidence.Source.Channels := LSource.Channels;
    LEvidence.Source.FrameCount := LSource.FrameCount;
    if (ParamStr(1) = 'learn-pitch') or (ParamStr(1) = 'learn-duration') then
    begin
      LEvidence.Source.Provenance := LProvenance;
    end
    else if ParamCount = 7 then
    begin
      LEvidence.Source.Provenance := ParamStr(7);
    end;
    if LEvidence.Source.Sha256 <> LContextEvidence[0].SourceSha256 then
    begin
      raise EAudio.Create('WAV does not match the admitted source tempo provider');
    end;
    LJson := ReadJson(ParamStr(4), LEvidence.OnsetReportSha256);
    if not (LJson is TJSONObject) then
    begin
      raise EAudio.Create('Onset evidence must be a JSON object');
    end;
    LLocations := ReadLocations(TJSONObject(LJson), LSource, LEvidence.Source.Sha256);
    LEvidence.Analysis.WindowFrames := TJSONObject(LJson).Integers['analysis_window'];
    LEvidence.Analysis.HopFrames := TJSONObject(LJson).Integers['analysis_hop'];
    LEvidence.Analysis.SilenceRms := TJSONObject(LJson).Floats['silence_rms'];
    LEvidence.OnsetVersion := TJSONObject(LJson).Integers['version'];
    LOnsetOptions := DefaultOnsetEventOptions(LSource.SampleRate);
    LPlan := PlanOnsetEvents(LLocations, LSource.FrameCount,
      LOnsetOptions);
    SetLength(LEvidence.OnsetFrames, Length(LPlan.Bounds));
    LCount := 0;
    for LIndex := 0 to High(LPlan.Bounds) do
    begin
      if LPlan.LocationIndices[LIndex] >= 0 then
      begin
        LEvidence.OnsetFrames[LCount] := LPlan.Bounds[LIndex];
        Inc(LCount);
      end;
    end;
    SetLength(LEvidence.OnsetFrames, LCount);
    LEvidence.Policy := 'Native onset-event v' + IntToStr(OnsetEventVersion) +
      '; minimum_frames=' + IntToStr(LOnsetOptions.MinimumFrames) +
      '; clipped_context=false; search_boundary=false; nearest floor-frame PPQ boundary; earlier half ties; no downbeat or voice inference';
    LEvidence.TempoMicroseconds := LContextEvidence[0].Grid.Tempos[0];
    LEvidence.SourceStartTick := LContextEvidence[0].Grid.StartTick;
    LEvidence.SourceFrameOffset := LContextEvidence[0].SourceFrameOffset;
    LEvidence.SourceCellCount := Length(LContextEvidence[0].Grid.Tempos);
    SetLength(LEvidence.SourceClock, LEvidence.SourceCellCount);
    LEvidence.SourceClock[0] := MakeTempoChange(0, LEvidence.TempoMicroseconds);
    LClockCount := 1;
    for LIndex := 1 to LEvidence.SourceCellCount - 1 do
    begin
      if LContextEvidence[0].Grid.Tempos[LIndex] <>
        LContextEvidence[0].Grid.Tempos[LIndex - 1] then
      begin
        LEvidence.SourceClock[LClockCount] := MakeTempoChange(LEvidence.SourceStartTick +
          LIndex * LContext.StepTicks, LContextEvidence[0].Grid.Tempos[LIndex]);
        Inc(LClockCount);
      end;
    end;
    SetLength(LEvidence.SourceClock, LClockCount);
    LGrid := CreateStyleSourceGrid(LEvidence, LContext.TicksPerQuarter, LContext.StepTicks);
    LEvidence.MaximumErrorFrames := StrToInt(ParamStr(5));
    if (ParamStr(1) = 'learn-dynamics') or (ParamStr(1) = 'learn-pitch') or
      (ParamStr(1) = 'learn-duration') then
    begin
      LEvidence.Dynamics := MeasureOnsetDynamics(LSource, LEvidence.OnsetFrames,
        Max(1, LSource.SampleRate div 50));
      LEvidence.Policy := LEvidence.Policy + '; onset dynamics v1: forward 20ms RMS, stereo mean energy, EOF shortened, four relative amplitude bands';
    end;
    if (ParamStr(1) = 'learn-pitch') or (ParamStr(1) = 'learn-duration') then
    begin
      LEvidence.Pitch := MeasurePitchCells(LSource, LGrid, StrToInt(ParamStr(7)),
        DefaultPitchOptions, 25);
      LEvidence.Policy := LEvidence.Policy +
        '; declared monophonic source; centered periodic pitch cells v1; 25-cent admission; unknowns split runs; same-cell pairing does not infer note-onset ownership';
    end;
    if ParamStr(1) = 'learn-duration' then
    begin
      LDurationTrack := TPitchTrack.Create(LSource, StrToInt(ParamStr(7)),
        DefaultPitchTrackOptions(LSource.SampleRate), LWindowFrames);
      LEvidence.Duration := LDurationTrack.CopyEvidence;
      LEvidence.DurationArticulateOnsets := LUseDurationOnsets;
      LEvidence.Policy := LEvidence.Policy +
        '; dense monophonic pitch spans; center-aligned hop bins; explicit silence and unknown intervals';
      if LUseDurationOnsets then
      begin
        LEvidence.Policy := LEvidence.Policy +
          '; explicit source-onset ownership inside known pitch spans; source-clock PPQ attack boundaries; no new notes in unknown/silence';
      end;
    end;
    LStyle := TWaveStyleProfile.CreateSource(LContext, LEvidence);
    WriteFileBytes(ParamStr(6), LStyle.Encode);
    WriteLn('Saved WAV rhythm/context style ', LStyle.Identity, '; selected source onsets ', LCount,
      '; admitted grid onsets ', LStyle.AdmissionAt(0).Accepted);
  finally
    LGrid.Free;
    LDurationTrack.Free;
    LJson.Free;
    LSource.Free;
    LStyle.Free;
    LBundle.Free;
    LContext.Free;
  end;
end;

procedure RetainPreferences(var AResult: TWaveStyleProfile; const AOriginal: TWaveStyleProfile);
var
  LPreferred: TWaveStyleProfile;
begin
  if not AOriginal.HasGenerationPreferences then
  begin
    Exit;
  end;
  LPreferred := TWaveStyleProfile.CreatePreferred(AResult, AOriginal.CopyGenerationPreferences);
  AResult.Free;
  AResult := LPreferred;
end;

procedure LearnTimbre;
var
  LOriginal: TWaveStyleProfile;
  LResult: TWaveStyleProfile;
  LContext: TContextProfile;
  LEvidence: TRhythmStyleEvidence;
  LClip: TAudioClip;
  LHash: String;
  LFormat: TFormatSettings;
  LFrequency: Double;
  LPitchFrames: Integer;
  LPitch: TPitchEstimate;
  LPolicy: String;
begin
  ProtectOutput(ParamStr(10), ParamStr(2));
  ProtectOutput(ParamStr(10), ParamStr(3));
  LOriginal := nil;
  LResult := nil;
  LContext := nil;
  LClip := nil;
  LFormat := DefaultFormatSettings;
  LFormat.DecimalSeparator := '.';
  try
    LOriginal := DecodeWaveStyle(ReadFileBytes(ParamStr(2), MaximumStyleBytes));
    if (LOriginal.Depth <> 1) or (LOriginal.SourceCount <> 1) then
    begin
      raise EAudio.Create('Timbre measurement augments a source style; measure before blending');
    end;
    LEvidence := LOriginal.EvidenceAt(0);
    LClip := LoadWaveSource(ParamStr(3), LHash);
    if (LHash <> LEvidence.Source.Sha256) or
      (LClip.SampleRate <> LEvidence.Source.SampleRate) or
      (LClip.Channels <> LEvidence.Source.Channels) or
      (LClip.FrameCount <> LEvidence.Source.FrameCount) then
    begin
      raise EAudio.Create('Timbre WAV identity/geometry differs from its source style');
    end;
    LEvidence.Timbre := Default(THarmonicStyleEvidence);
    LEvidence.TimbreTrajectory := Default(TTimbreTrajectoryEvidence);
    LEvidence.Timbre.StartFrame := StrToInt(ParamStr(4));
    LEvidence.Timbre.FrameCount := StrToInt(ParamStr(5));
    LEvidence.Timbre.Channel := StrToInt(ParamStr(6));
    LEvidence.Timbre.MaximumRelativeError := StrToFloat(ParamStr(9), LFormat);
    LEvidence.Timbre.MinimumAcRms := DefaultPitchOptions.SilenceRms;
    LPolicy := 'Declared fundamental ' + ParamStr(8) + ' Hz';
    if (ParamStr(8) = 'auto') or (Copy(ParamStr(8), 1, 5) = 'auto:') then
    begin
      LPitchFrames := LEvidence.Timbre.FrameCount;
      if ParamStr(8) <> 'auto' then
      begin
        LPitchFrames := StrToInt(Copy(ParamStr(8), 6, Length(ParamStr(8))));
      end;
      PitchEstimateWork(LPitchFrames, LClip.SampleRate, LClip.Channels,
        LEvidence.Timbre.Channel, DefaultPitchOptions);
      if (LEvidence.Timbre.StartFrame < 0) or
        (Int64(LEvidence.Timbre.StartFrame) + LPitchFrames > LClip.FrameCount) then
      begin
        raise EAudio.Create('Timbre frequency measurement exceeds source interval');
      end;
      LPitch := EstimatePitch(Copy(LClip.CopySamples,
        LEvidence.Timbre.StartFrame * LClip.Channels, LPitchFrames * LClip.Channels),
        LClip.SampleRate, LClip.Channels, LEvidence.Timbre.Channel, DefaultPitchOptions);
      if LPitch.Status <> psEstimated then
      begin
        raise EAudio.Create('Timbre interval has no admitted periodic frequency');
      end;
      LFrequency := LPitch.FrequencyHz;
      LPolicy := 'Default periodic estimator v1; same start/channel; pitch frames=' +
        IntToStr(LPitchFrames) + '; normalized difference=' +
        FloatToStr(LPitch.NormalizedDifference, LFormat);
    end
    else
    begin
      LFrequency := StrToFloat(ParamStr(8), LFormat);
    end;
    LEvidence.Timbre.Policy := UTF8String('Stationary harmonic QR fit; ' + LPolicy +
      '; caller-selected interval; weighted magnitudes use zero sine phase; no role/envelope inference');
    LEvidence.Timbre.Fit := FitWavetableHarmonics(LClip, LEvidence.Timbre.StartFrame,
      LEvidence.Timbre.FrameCount, LEvidence.Timbre.Channel, StrToInt(ParamStr(7)), LFrequency);
    LContext := LOriginal.CopyContext;
    LResult := TWaveStyleProfile.CreateSource(LContext, LEvidence, LOriginal.Order);
    RetainPreferences(LResult, LOriginal);
    WriteFileBytes(ParamStr(10), LResult.Encode);
    WriteLn('Saved source timbre ', LResult.Identity, '; source ', LHash,
      '; frequency ', LFrequency:0:12, '; relative error ', LEvidence.Timbre.Fit.RelativeError:0:12);
  finally
    LResult.Free;
    LOriginal.Free;
    LContext.Free;
    LClip.Free;
  end;
end;

procedure LearnTrajectory;
var
  LOriginal: TWaveStyleProfile;
  LResult: TWaveStyleProfile;
  LContext: TContextProfile;
  LEvidence: TRhythmStyleEvidence;
  LClip: TAudioClip;
  LHash: String;
  LFormat: TFormatSettings;
  LStart: Integer;
  LHop: Integer;
  LWindow: Integer;
  LCount: Integer;
  LChannel: Integer;
  LHarmonics: Integer;
  LIndex: Integer;
  LFrequency: Double;
  LMaximumError: Double;
begin
  ProtectOutput(ParamStr(13), ParamStr(2));
  ProtectOutput(ParamStr(13), ParamStr(3));
  LOriginal := nil;
  LResult := nil;
  LContext := nil;
  LClip := nil;
  LFormat := DefaultFormatSettings;
  LFormat.DecimalSeparator := '.';
  try
    LOriginal := DecodeWaveStyle(ReadFileBytes(ParamStr(2), MaximumStyleBytes));
    if (LOriginal.Depth <> 1) or (LOriginal.SourceCount <> 1) then
    begin
      raise EAudio.Create('Trajectory measurement augments a source style; measure before blending');
    end;
    LEvidence := LOriginal.EvidenceAt(0);
    LClip := LoadWaveSource(ParamStr(3), LHash);
    if (LHash <> LEvidence.Source.Sha256) or
      (LClip.SampleRate <> LEvidence.Source.SampleRate) or
      (LClip.Channels <> LEvidence.Source.Channels) or
      (LClip.FrameCount <> LEvidence.Source.FrameCount) then
    begin
      raise EAudio.Create('Trajectory WAV identity/geometry differs from its source style');
    end;
    LEvidence.Timbre := Default(THarmonicStyleEvidence);
    LEvidence.TimbreTrajectory := Default(TTimbreTrajectoryEvidence);
    LEvidence.TimbreTrajectory.OriginFrame := StrToInt(ParamStr(4));
    LStart := StrToInt(ParamStr(5));
    LHop := StrToInt(ParamStr(6));
    LWindow := StrToInt(ParamStr(7));
    LCount := StrToInt(ParamStr(8));
    LChannel := StrToInt(ParamStr(9));
    LHarmonics := StrToInt(ParamStr(10));
    LFrequency := StrToFloat(ParamStr(11), LFormat);
    LMaximumError := StrToFloat(ParamStr(12), LFormat);
    RequireFinite(LMaximumError, 'Trajectory residual limit');
    if (LStart < 0) or (LHop < 1) or (LWindow < 16) or
      (LCount < 2) or (LCount > MaximumWavetableTrajectoryRecipes) or
      (LEvidence.TimbreTrajectory.OriginFrame < 0) or
      (LEvidence.TimbreTrajectory.OriginFrame > LStart) or
      (Int64(LStart) + Int64(LCount - 1) * LHop + LWindow > LClip.FrameCount) or
      (LMaximumError < 0) or (LMaximumError > 1) then
    begin
      raise EAudio.Create('Trajectory origin, windows or residual limit exceeds bounds');
    end;
    if HarmonicFitWork(LWindow, LClip.SampleRate, LHarmonics, LFrequency) * LCount >
      MaximumHarmonicFitWork then
    begin
      raise EAudio.Create('Trajectory fitting exceeds cumulative work limit');
    end;
    SetLength(LEvidence.TimbreTrajectory.Knots, LCount);
    for LIndex := 0 to LCount - 1 do
    begin
      LEvidence.TimbreTrajectory.Knots[LIndex].StartFrame := LStart + LIndex * LHop;
      LEvidence.TimbreTrajectory.Knots[LIndex].FrameCount := LWindow;
      LEvidence.TimbreTrajectory.Knots[LIndex].Channel := LChannel;
      LEvidence.TimbreTrajectory.Knots[LIndex].MaximumRelativeError := LMaximumError;
      LEvidence.TimbreTrajectory.Knots[LIndex].MinimumAcRms := DefaultPitchOptions.SilenceRms;
      LEvidence.TimbreTrajectory.Knots[LIndex].Policy :=
        'Declared fixed-pitch harmonic QR windows; raw phase/DC/AC/residual retained; note origin declared; unit-RMS magnitude shapes at window centers; union-knot weighted blending; dynamics independent';
      LEvidence.TimbreTrajectory.Knots[LIndex].Fit := FitWavetableHarmonics(LClip,
        LStart + LIndex * LHop, LWindow, LChannel, LHarmonics, LFrequency);
      WriteLn('Knot ', LIndex, ': start=', LStart + LIndex * LHop,
        ' residual=', LEvidence.TimbreTrajectory.Knots[LIndex].Fit.RelativeError:0:12);
    end;
    LContext := LOriginal.CopyContext;
    LResult := TWaveStyleProfile.CreateSource(LContext, LEvidence, LOriginal.Order);
    RetainPreferences(LResult, LOriginal);
    WriteFileBytes(ParamStr(13), LResult.Encode);
    WriteLn('Saved source trajectory ', LResult.Identity, '; source ', LHash,
      '; knots ', LCount, '; note origin ', LEvidence.TimbreTrajectory.OriginFrame);
  finally
    LResult.Free;
    LOriginal.Free;
    LContext.Free;
    LClip.Free;
  end;
end;

procedure LearnEnvelope;
var
  LOriginal: TWaveStyleProfile;
  LResult: TWaveStyleProfile;
  LContext: TContextProfile;
  LEvidence: TRhythmStyleEvidence;
  LClip: TAudioClip;
  LTrace: TEnvelopeTrace;
  LHash: String;
  LFormat: TFormatSettings;
begin
  ProtectOutput(ParamStr(10), ParamStr(2));
  ProtectOutput(ParamStr(10), ParamStr(3));
  LOriginal := nil;
  LResult := nil;
  LContext := nil;
  LClip := nil;
  LTrace := nil;
  LFormat := DefaultFormatSettings;
  LFormat.DecimalSeparator := '.';
  try
    LOriginal := DecodeWaveStyle(ReadFileBytes(ParamStr(2), MaximumStyleBytes));
    if (LOriginal.Depth <> 1) or (LOriginal.SourceCount <> 1) then
    begin
      raise EAudio.Create('Envelope measurement augments a source style; measure before blending');
    end;
    LEvidence := LOriginal.EvidenceAt(0);
    LClip := LoadWaveSource(ParamStr(3), LHash);
    if (LHash <> LEvidence.Source.Sha256) or
      (LClip.SampleRate <> LEvidence.Source.SampleRate) or
      (LClip.Channels <> LEvidence.Source.Channels) or
      (LClip.FrameCount <> LEvidence.Source.FrameCount) then
    begin
      raise EAudio.Create('Envelope WAV identity/geometry differs from its source style');
    end;
    LEvidence.Envelope := Default(TEnvelopeStyleEvidence);
    LEvidence.Envelope.StartFrame := StrToInt(ParamStr(4));
    LEvidence.Envelope.FrameCount := StrToInt(ParamStr(5));
    LEvidence.Envelope.GateFrame := StrToInt(ParamStr(6));
    LEvidence.Envelope.Channel := StrToInt(ParamStr(7));
    LEvidence.Envelope.WindowFrames := StrToInt(ParamStr(8));
    LEvidence.Envelope.MaximumTailRatio := StrToFloat(ParamStr(9), LFormat);
    LEvidence.Envelope.MinimumRms := 1E-5;
    LEvidence.Envelope.Policy := 'Rectangular nonoverlapping RMS including DC; valid-sample centers; declared gate; peak-normalized held levels and gate-relative release; explicit final-tail admission';
    LTrace := TEnvelopeTrace.Create(LClip, LEvidence.Envelope.StartFrame,
      LEvidence.Envelope.FrameCount, LEvidence.Envelope.Channel, LEvidence.Envelope.WindowFrames);
    LEvidence.Envelope.RmsPoints := LTrace.CopyRmsPoints;
    LContext := LOriginal.CopyContext;
    LResult := TWaveStyleProfile.CreateSource(LContext, LEvidence, LOriginal.Order);
    RetainPreferences(LResult, LOriginal);
    WriteFileBytes(ParamStr(10), LResult.Encode);
    WriteLn('Saved envelope style ', LResult.Identity, '; RMS points ',
      Length(LEvidence.Envelope.RmsPoints), '; peak RMS ', LTrace.PeakRms:0:12);
  finally
    LTrace.Free;
    LClip.Free;
    LContext.Free;
    LResult.Free;
    LOriginal.Free;
  end;
end;

procedure Blend(const ADimensions: Boolean; const ALayers: Boolean = False);
var
  LLeft: TWaveStyleProfile;
  LRight: TWaveStyleProfile;
  LStyle: TWaveStyleProfile;
  LOutput: String;
  LLeftEnvelopeWeight: Integer;
  LRightEnvelopeWeight: Integer;
begin
  LOutput := ParamStr(8);
  if ADimensions then
  begin
    LOutput := ParamStr(10);
  end;
  if ALayers then
  begin
    LOutput := ParamStr(12);
  end;
  LLeftEnvelopeWeight := -1;
  LRightEnvelopeWeight := -1;
  if ALayers and (ParamCount = 14) then
  begin
    LLeftEnvelopeWeight := StrToInt(ParamStr(12));
    LRightEnvelopeWeight := StrToInt(ParamStr(13));
    LOutput := ParamStr(14);
  end;
  ProtectOutput(LOutput, ParamStr(2));
  ProtectOutput(LOutput, ParamStr(3));
  LLeft := nil;
  LRight := nil;
  LStyle := nil;
  try
    LLeft := DecodeWaveStyle(ReadFileBytes(ParamStr(2), MaximumStyleBytes));
    LRight := DecodeWaveStyle(ReadFileBytes(ParamStr(3), MaximumStyleBytes));
    if ALayers then
    begin
      LStyle := TWaveStyleProfile.CreateBlendLayers(LLeft, LRight,
        StrToInt(ParamStr(4)), StrToInt(ParamStr(5)), StrToInt(ParamStr(6)), StrToInt(ParamStr(7)),
        StrToInt(ParamStr(8)), StrToInt(ParamStr(9)), StrToInt(ParamStr(10)), StrToInt(ParamStr(11)),
        LLeftEnvelopeWeight, LRightEnvelopeWeight);
    end
    else if ADimensions then
    begin
      LStyle := TWaveStyleProfile.CreateBlendDimensions(LLeft, LRight,
        StrToInt(ParamStr(4)), StrToInt(ParamStr(5)), StrToInt(ParamStr(6)), StrToInt(ParamStr(7)),
        StrToInt(ParamStr(8)), StrToInt(ParamStr(9)));
    end
    else
    begin
      LStyle := TWaveStyleProfile.CreateBlend(LLeft, LRight,
        StrToInt(ParamStr(4)), StrToInt(ParamStr(5)), StrToInt(ParamStr(6)), StrToInt(ParamStr(7)));
    end;
    WriteFileBytes(LOutput, LStyle.Encode);
    WriteLn('Saved derived style ', LStyle.Identity, '; sources ', LStyle.SourceCount,
      '; depth ', LStyle.Depth, '; nodes ', LStyle.NodeCount);
  finally
    LStyle.Free;
    LRight.Free;
    LLeft.Free;
  end;
end;

procedure Prefer(const AClear: Boolean);
var
  LSource: TWaveStyleProfile;
  LResult: TWaveStyleProfile;
  LPreferences: TStyleGenerationPreferences;
  LProvider: TStylePreferenceProvider;
  LOutput: String;
  LIndex: Integer;
  LFound: Integer;
begin
  if ParamStr(3) = 'key' then
  begin
    LProvider := sppKey;
  end
  else if ParamStr(3) = 'tempo' then
  begin
    LProvider := sppTempo;
  end
  else if ParamStr(3) = 'performance' then
  begin
    LProvider := sppPerformance;
  end
  else if ParamStr(3) = 'rhythm' then
  begin
    LProvider := sppRhythm;
  end
  else if ParamStr(3) = 'intensity' then
  begin
    LProvider := sppIntensity;
  end
  else if ParamStr(3) = 'pitch' then
  begin
    LProvider := sppPitch;
  end
  else if ParamStr(3) = 'pitch-rhythm' then
  begin
    LProvider := sppPitchRhythm;
  end
  else
  begin
    raise EAudio.Create('Preference provider must be key, tempo, performance, rhythm, intensity, pitch or pitch-rhythm');
  end;
  LOutput := ParamStr(ParamCount);
  ProtectOutput(LOutput, ParamStr(2));
  LSource := DecodeWaveStyle(ReadFileBytes(ParamStr(2), MaximumStyleBytes));
  LResult := nil;
  try
    LPreferences := LSource.CopyGenerationPreferences;
    if AClear then
    begin
      LPreferences[LProvider] := nil;
    end
    else
    begin
      LFound := -1;
      for LIndex := 0 to High(LPreferences[LProvider]) do
      begin
        if LPreferences[LProvider][LIndex].Token = ParamStr(4) then
        begin
          LFound := LIndex;
        end;
      end;
      if LFound < 0 then
      begin
        LFound := Length(LPreferences[LProvider]);
        SetLength(LPreferences[LProvider], LFound + 1);
      end;
      LPreferences[LProvider][LFound] := MakeLayerTokenPreference(ParamStr(4), StrToInt(ParamStr(5)));
    end;
    LResult := TWaveStyleProfile.CreatePreferred(LSource, LPreferences);
    WriteFileBytes(LOutput, LResult.Encode);
    WriteLn('Saved generation preferences ', LResult.Identity, '; parent ', LSource.Identity);
  finally
    LResult.Free;
    LSource.Free;
  end;
end;

procedure PrintProvider(const ADescription: TStyleProviderDescription);
const
  CTiming: array[TStyleProviderTiming] of String = ('uniform', 'held', 'generated-spans');
  CPitchKinds: array[TPitchSpanKind] of String = ('pitch', 'silence', 'unknown');
var
  LDependency: TStyleProviderDependency;
  LChoice: TStyleProviderChoice;
  LPreference: TLayerTokenPreference;
begin
  WriteLn('Provider ', ADescription.Name, ': ', CTiming[ADescription.Timing],
    '; PPQ=', ADescription.TicksPerQuarter, '; cells=', ADescription.Scope.CellCount,
    '; step ticks=', ADescription.StepTicks);
  for LDependency in ADescription.Dependencies do
  begin
    WriteLn('  requires ', LDependency.Name, '; mapping=', Ord(LDependency.TimeMapping));
  end;
  for LChoice in ADescription.Choices do
  begin
    Write('  ', LChoice.Token, ' |');
    if scdKey in LChoice.Dimensions then
    begin
      Write(' key-root=', LChoice.Key.Root, ' mode=', Ord(LChoice.Key.Mode));
    end;
    if scdTempo in LChoice.Dimensions then
    begin
      Write(' microseconds/quarter=', LChoice.TempoMicroseconds);
    end;
    if scdOnset in LChoice.Dimensions then
    begin
      Write(' onset=', LChoice.Onset);
    end;
    if scdIntensity in LChoice.Dimensions then
    begin
      Write(' intensity=', LChoice.Intensity);
    end;
    if scdPitch in LChoice.Dimensions then
    begin
      Write(' ', CPitchKinds[LChoice.PitchKind]);
      if LChoice.PitchKind = pskPitch then
      begin
        Write(' MIDI=', LChoice.Note);
      end;
    end;
    if scdDuration in LChoice.Dimensions then
    begin
      Write(' duration-ticks=', LChoice.DurationTicks);
    end;
    WriteLn;
  end;
  for LPreference in ADescription.Preferences do
  begin
    WriteLn('  preference ', LPreference.Token, ' x', LPreference.Multiplier);
  end;
end;

procedure InspectProviders;
var
  LStyle: TWaveStyleProfile;
  LGrid: TStyleGrid;
  LPerformance: TStylePerformance;
  LGridOptions: TStyleGridOptions;
  LPerformanceOptions: TStylePerformanceOptions;
  LIndex: Integer;
  LProvider: TPerformanceProvider;
begin
  if not (((ParamStr(3) = 'grid') or (ParamStr(3) = 'coupled')) and (ParamCount = 4)) and
    not ((ParamStr(3) = 'performance') and (ParamCount = 6)) then
  begin
    raise EAudio.Create('Provider inspection: providers INPUT.pys grid|coupled CELLS; ' +
      'providers INPUT.pys performance SPANS KEY_CELLS TEMPO_CELLS (0 holds context)');
  end;
  LStyle := nil;
  LGrid := nil;
  LPerformance := nil;
  try
    LStyle := DecodeWaveStyle(ReadFileBytes(ParamStr(2), MaximumStyleBytes));
    if ParamStr(3) = 'performance' then
    begin
      LPerformanceOptions := DefaultStylePerformanceOptions;
      LPerformanceOptions.SpanCount := StrToInt(ParamStr(4));
      LPerformanceOptions.KeyCells := StrToInt(ParamStr(5));
      LPerformanceOptions.TempoCells := StrToInt(ParamStr(6));
      LPerformance := TStylePerformance.Create(LStyle, LPerformanceOptions);
    end
    else
    begin
      LGridOptions := DefaultStyleGridOptions;
      LGridOptions.CellCount := StrToInt(ParamStr(4));
      LGridOptions.CouplePitch := ParamStr(3) = 'coupled';
      LGrid := TStyleGrid.Create(LStyle, LGridOptions);
    end;
    WriteLn('Style ', LStyle.Identity);
    WriteLn('Definition vocabulary only; choices may be infeasible at a position or jointly.');
    if LGrid <> nil then
    begin
      for LIndex := 0 to LGrid.ProviderCount - 1 do
      begin
        PrintProvider(LGrid.CopyProvider(LIndex));
      end;
    end
    else
    begin
      for LProvider := Low(LProvider) to High(LProvider) do
      begin
        PrintProvider(LPerformance.CopyProvider(LProvider));
      end;
    end;
  finally
    LPerformance.Free;
    LGrid.Free;
    LStyle.Free;
  end;
end;

procedure Inspect;
var
  LStyle: TWaveStyleProfile;
  LContext: TContextProfile;
  LModel: TWfcSequenceModel;
  LDocument: TJSONObject;
  LSources: TJSONArray;
  LRow: TJSONObject;
  LOnsets: TJSONArray;
  LOnset: TJSONObject;
  LEvidence: TRhythmStyleEvidence;
  LAdmission: TRhythmAdmission;
  LIndex: Integer;
  LOnsetIndex: Integer;
  LPitchNotes: TPitchNotes;
  LPitchSummary: TPitchCellSummary;
  LSummaryRow: TJSONObject;
  LPitchRows: TJSONArray;
  LPitchRow: TJSONObject;
  LDurationTrack: TPitchTrack;
  LSpans: TPitchSpans;
  LTimedSpans: TTimedPitchSpans;
  LSpanIndex: Integer;
  LGrid: TMusicGridFrames;
  LClockRows: TJSONArray;
  LClockRow: TJSONObject;
  LClockIndex: Integer;
  LTrajectoryRows: TJSONArray;
  LTrajectoryRow: TJSONObject;
  LTrajectoryIndex: Integer;
  LTimbre: THarmonicStyleEvidence;
  LShape: TWavetableMagnitudeShape;
  LPreferences: TStyleGenerationPreferences;
  LProvider: TStylePreferenceProvider;
  LPreference: TLayerTokenPreference;
  LPreferenceRows: TJSONArray;
  LPreferenceRow: TJSONObject;
begin
  ProtectOutput(ParamStr(3), ParamStr(2));
  LStyle := nil;
  LContext := nil;
  LModel := nil;
  LDurationTrack := nil;
  LDocument := TJSONObject.Create;
  try
    LStyle := DecodeWaveStyle(ReadFileBytes(ParamStr(2), MaximumStyleBytes));
    LContext := LStyle.CopyContext;
    LModel := LStyle.CopyRhythmModel;
    LDocument.Add('contract', 'pythian.wave-style.v1');
    LDocument.Add('style_sha256', LStyle.Identity);
    LDocument.Add('archive_version', WaveStyleVersion);
    LPreferences := LStyle.CopyGenerationPreferences;
    LPreferenceRows := TJSONArray.Create;
    LDocument.Add('generation_preferences', LPreferenceRows);
    for LProvider := Low(LProvider) to High(LProvider) do
    begin
      for LPreference in LPreferences[LProvider] do
      begin
        LPreferenceRow := TJSONObject.Create;
        LPreferenceRows.Add(LPreferenceRow);
        case LProvider of
          sppKey: LPreferenceRow.Add('provider', 'key');
          sppTempo: LPreferenceRow.Add('provider', 'tempo');
          sppPerformance: LPreferenceRow.Add('provider', 'performance');
          sppRhythm: LPreferenceRow.Add('provider', 'rhythm');
          sppIntensity: LPreferenceRow.Add('provider', 'intensity');
          sppPitch: LPreferenceRow.Add('provider', 'pitch');
          sppPitchRhythm: LPreferenceRow.Add('provider', 'pitch-rhythm');
        end;
        LPreferenceRow.Add('token', LPreference.Token);
        LPreferenceRow.Add('multiplier', LPreference.Multiplier);
      end;
    end;
    LDocument.Add('has_dynamics', LStyle.HasDynamics);
    LDocument.Add('has_pitch', LStyle.HasPitch);
    LDocument.Add('has_pitch_rhythm', LStyle.HasPitchRhythm);
    LDocument.Add('has_duration', LStyle.HasDuration);
    LDocument.Add('has_timbre', LStyle.HasTimbre);
    LDocument.Add('has_timbre_trajectory', LStyle.HasTimbreTrajectory);
    LDocument.Add('has_envelope', LStyle.HasEnvelope);
    LDocument.Add('timbre_policy', 'Weighted mean harmonic magnitudes; missing upper harmonics contribute zero; zero sine phase, no DC/loudness normalization; independent envelope dimension');
    if LStyle.HasTimbreTrajectory then
    begin
      LDocument.Strings['timbre_policy'] := 'Raw fits retained; unit-RMS magnitude shapes on the union of floored note-relative window centers; normalize each source at union knots before weighted mean; continuously normalized interpolation; independent reference level and envelope';
    end;
    if LStyle.HasEnvelope then
    begin
      LDocument.Add('envelope_policy', 'Independent weighted means of peak-normalized held levels and gate-relative release curves; absolute retimed knots, longest active tail, no time stretching');
    end;
    if LStyle.HasDuration then
    begin
      FreeAndNil(LModel);
      LModel := LStyle.CopyDurationModel;
      LDocument.Add('duration_model', EncodeWfcSequenceText(LModel));
      LDocument.Add('duration_ticks_per_quarter', LStyle.DurationTicksPerQuarter);
      LDocument.Add('duration_policy', 'Dense pitch/silence/unknown spans use pitch-source weights; all active pitch sources require dense evidence normalized through their own source clocks to common PPQ ticks');
      FreeAndNil(LModel);
      LModel := LStyle.CopyRhythmModel;
    end;
    if LStyle.HasPitchRhythm then
    begin
      FreeAndNil(LModel);
      LModel := LStyle.CopyPitchRhythmModel;
      LDocument.Add('pitch_rhythm_model', EncodeWfcSequenceText(LModel));
      LDocument.Add('pitch_rhythm_policy', 'Same-source aligned known-pitch runs; equal rhythm/pitch weights; no joining across unknowns or recordings');
      FreeAndNil(LModel);
      LModel := LStyle.CopyRhythmModel;
    end;
    if LStyle.HasDynamics then
    begin
      LDocument.Add('dynamics_version', OnsetDynamicsVersion);
      LDocument.Add('intensity_policy', 'Per-source accepted-onset maximum RMS; four equal amplitude bands; zero token means no admitted onset');
      LModel.Free;
      LModel := nil;
      LModel := LStyle.CopyIntensityModel;
      LDocument.Add('joint_intensity_model', EncodeWfcSequenceText(LModel));
      FreeAndNil(LModel);
      LModel := LStyle.CopyRhythmModel;
    end;
    LDocument.Add('depth', LStyle.Depth);
    if LStyle.HasPitch then
    begin
      FreeAndNil(LModel);
      LModel := LStyle.CopyPitchModel;
      LDocument.Add('pitch_model', EncodeWfcSequenceText(LModel));
      LDocument.Add('pitch_policy', 'Declared monophonic, absolute MIDI notes; unknowns split runs; independent models remain available; has_pitch_rhythm identifies optional observed coupling');
      FreeAndNil(LModel);
      LModel := LStyle.CopyRhythmModel;
    end;
    LDocument.Add('nodes', LStyle.NodeCount);
    if LStyle.Depth > 1 then
    begin
      LDocument.Add('left_parent_sha256', LStyle.ParentIdentity(0));
      LDocument.Add('right_parent_sha256', LStyle.ParentIdentity(1));
    end;
    LDocument.Add('ticks_per_quarter', LContext.TicksPerQuarter);
    LDocument.Add('step_ticks', LContext.StepTicks);
    LDocument.Add('context_profile_sha256', LContext.Identity);
    LDocument.Add('key_provider_sha256', LContext.ProviderIdentity(cdKey));
    LDocument.Add('tempo_provider_sha256', LContext.ProviderIdentity(cdTempo));
    LDocument.Add('rhythm_model', EncodeWfcSequenceText(LModel));
    LDocument.Add('rhythm_weight_policy', 'Integer relative source repetition, reduced by greatest common divisor; longer sources contribute more cells');
    LDocument.Add('dimension_weight_policy', 'Rhythm and its joint intensity share weights; pitch has independent weights; each vector reduces by its own greatest common divisor; zero excludes that dimension');
    LDocument.Add('rhythm_meaning', 'Admitted onset presence; empty cells do not establish silence or voice rests');
    LDocument.Add('voice_roles_learned', False);
    LSources := TJSONArray.Create;
    LDocument.Add('sources', LSources);
    for LIndex := 0 to LStyle.SourceCount - 1 do
    begin
      LEvidence := LStyle.EvidenceAt(LIndex);
      LAdmission := LStyle.AdmissionAt(LIndex);
      LRow := TJSONObject.Create;
      LSources.Add(LRow);
      LRow.Add('name', LEvidence.Source.Name);
      LRow.Add('sha256', LEvidence.Source.Sha256);
      LRow.Add('provenance', LEvidence.Source.Provenance);
      LRow.Add('timbre_weight', LStyle.TimbreWeightAt(LIndex));
      LRow.Add('envelope_weight', LStyle.EnvelopeWeightAt(LIndex));
      if LEvidence.Envelope.FrameCount > 0 then
      begin
        LSummaryRow := TJSONObject.Create;
        LRow.Add('envelope', LSummaryRow);
        LSummaryRow.Add('start_frame', LEvidence.Envelope.StartFrame);
        LSummaryRow.Add('frame_count', LEvidence.Envelope.FrameCount);
        LSummaryRow.Add('channel', LEvidence.Envelope.Channel);
        LSummaryRow.Add('window_frames', LEvidence.Envelope.WindowFrames);
        LSummaryRow.Add('gate_frame', LEvidence.Envelope.GateFrame);
        LSummaryRow.Add('maximum_tail_ratio', LEvidence.Envelope.MaximumTailRatio);
        LSummaryRow.Add('minimum_rms', LEvidence.Envelope.MinimumRms);
        LSummaryRow.Add('policy', LEvidence.Envelope.Policy);
        LPitchRows := TJSONArray.Create;
        LSummaryRow.Add('rms_points', LPitchRows);
        for LOnsetIndex := 0 to High(LEvidence.Envelope.RmsPoints) do
        begin
          LPitchRow := TJSONObject.Create;
          LPitchRows.Add(LPitchRow);
          LPitchRow.Add('frame', LEvidence.Envelope.RmsPoints[LOnsetIndex].Frame);
          LPitchRow.Add('rms', LEvidence.Envelope.RmsPoints[LOnsetIndex].Value);
        end;
      end;
      if LEvidence.Timbre.FrameCount > 0 then
      begin
        LSummaryRow := TJSONObject.Create;
        LRow.Add('timbre', LSummaryRow);
        LSummaryRow.Add('start_frame', LEvidence.Timbre.StartFrame);
        LSummaryRow.Add('frame_count', LEvidence.Timbre.FrameCount);
        LSummaryRow.Add('channel', LEvidence.Timbre.Channel);
        LSummaryRow.Add('policy', LEvidence.Timbre.Policy);
        LSummaryRow.Add('maximum_relative_error', LEvidence.Timbre.MaximumRelativeError);
        LSummaryRow.Add('minimum_ac_rms', LEvidence.Timbre.MinimumAcRms);
        LSummaryRow.Add('frequency_hz', LEvidence.Timbre.Fit.FrequencyHz);
        LSummaryRow.Add('ac_rms', LEvidence.Timbre.Fit.AcRms);
        LSummaryRow.Add('residual_rms', LEvidence.Timbre.Fit.ResidualRms);
        LSummaryRow.Add('relative_error', LEvidence.Timbre.Fit.RelativeError);
        LSummaryRow.Add('fitted_dc', LEvidence.Timbre.Fit.Recipe.Mean);
        LPitchRows := TJSONArray.Create;
        LSummaryRow.Add('harmonics', LPitchRows);
        for LOnsetIndex := 0 to High(LEvidence.Timbre.Fit.Recipe.Sine) do
        begin
          LPitchRow := TJSONObject.Create;
          LPitchRows.Add(LPitchRow);
          LPitchRow.Add('sine', LEvidence.Timbre.Fit.Recipe.Sine[LOnsetIndex]);
          LPitchRow.Add('cosine', LEvidence.Timbre.Fit.Recipe.Cosine[LOnsetIndex]);
        end;
      end;
      if Length(LEvidence.TimbreTrajectory.Knots) > 0 then
      begin
        LSummaryRow := TJSONObject.Create;
        LRow.Add('timbre_trajectory', LSummaryRow);
        LSummaryRow.Add('origin_frame', LEvidence.TimbreTrajectory.OriginFrame);
        LTrajectoryRows := TJSONArray.Create;
        LSummaryRow.Add('knots', LTrajectoryRows);
        for LTrajectoryIndex := 0 to High(LEvidence.TimbreTrajectory.Knots) do
        begin
          LTimbre := LEvidence.TimbreTrajectory.Knots[LTrajectoryIndex];
          LTrajectoryRow := TJSONObject.Create;
          LTrajectoryRows.Add(LTrajectoryRow);
          LTrajectoryRow.Add('start_frame', LTimbre.StartFrame);
          LTrajectoryRow.Add('frame_count', LTimbre.FrameCount);
          LTrajectoryRow.Add('channel', LTimbre.Channel);
          LTrajectoryRow.Add('policy', LTimbre.Policy);
          LTrajectoryRow.Add('frequency_hz', LTimbre.Fit.FrequencyHz);
          LTrajectoryRow.Add('maximum_relative_error', LTimbre.MaximumRelativeError);
          LTrajectoryRow.Add('minimum_ac_rms', LTimbre.MinimumAcRms);
          LTrajectoryRow.Add('ac_rms', LTimbre.Fit.AcRms);
          LTrajectoryRow.Add('residual_rms', LTimbre.Fit.ResidualRms);
          LTrajectoryRow.Add('relative_error', LTimbre.Fit.RelativeError);
          LTrajectoryRow.Add('fitted_dc', LTimbre.Fit.Recipe.Mean);
          LShape := FactorWavetableMagnitudes(LTimbre.Fit.Recipe);
          LTrajectoryRow.Add('modeled_cycle_rms', LShape.CycleRms);
          LPitchRows := TJSONArray.Create;
          LTrajectoryRow.Add('harmonics', LPitchRows);
          for LOnsetIndex := 0 to High(LTimbre.Fit.Recipe.Sine) do
          begin
            LPitchRow := TJSONObject.Create;
            LPitchRows.Add(LPitchRow);
            LPitchRow.Add('sine', LTimbre.Fit.Recipe.Sine[LOnsetIndex]);
            LPitchRow.Add('cosine', LTimbre.Fit.Recipe.Cosine[LOnsetIndex]);
          end;
        end;
      end;
      LRow.Add('onset_report_sha256', LEvidence.OnsetReportSha256);
      LRow.Add('analysis_window', LEvidence.Analysis.WindowFrames);
      LRow.Add('analysis_hop', LEvidence.Analysis.HopFrames);
      LRow.Add('silence_rms', LEvidence.Analysis.SilenceRms);
      LRow.Add('onset_version', LEvidence.OnsetVersion);
      LRow.Add('sample_rate', LEvidence.Source.SampleRate);
      LRow.Add('source_frames', LEvidence.Source.FrameCount);
      LRow.Add('source_tempo_us', LEvidence.TempoMicroseconds);
      LRow.Add('source_start_tick', LEvidence.SourceStartTick);
      LRow.Add('source_frame_offset', LEvidence.SourceFrameOffset);
      LRow.Add('source_cell_count', Length(LAdmission.Pattern));
      LClockRows := TJSONArray.Create;
      LRow.Add('source_clock', LClockRows);
      for LClockIndex := 0 to High(LEvidence.SourceClock) do
      begin
        LClockRow := TJSONObject.Create;
        LClockRows.Add(LClockRow);
        LClockRow.Add('tick', LEvidence.SourceClock[LClockIndex].Tick);
        LClockRow.Add('microseconds_per_quarter', LEvidence.SourceClock[LClockIndex].MicrosecondsPerQuarter);
      end;
      LRow.Add('maximum_error_frames', LEvidence.MaximumErrorFrames);
      LRow.Add('policy', LEvidence.Policy);
      LRow.Add('rhythm_weight', LStyle.RhythmWeightAt(LIndex));
      LRow.Add('pitch_weight', LStyle.PitchWeightAt(LIndex));
      LRow.Add('pattern', LAdmission.Pattern);
      LRow.Add('accepted_onsets', LAdmission.Accepted);
      if LEvidence.Pitch.WindowFrames > 0 then
      begin
        LRow.Add('pitch_estimator_version', PitchEstimatorVersion);
        LRow.Add('pitch_cells_version', PitchCellsVersion);
        LRow.Add('pitch_window_frames', LEvidence.Pitch.WindowFrames);
        LRow.Add('pitch_channel', LEvidence.Pitch.Channel);
        LRow.Add('pitch_minimum_hz', LEvidence.Pitch.Options.MinimumHz);
        LRow.Add('pitch_maximum_hz', LEvidence.Pitch.Options.MaximumHz);
        LRow.Add('pitch_difference_threshold', LEvidence.Pitch.Options.DifferenceThreshold);
        LRow.Add('pitch_silence_ac_rms', LEvidence.Pitch.Options.SilenceRms);
        LRow.Add('pitch_maximum_cents', LEvidence.Pitch.MaximumCents);
        LPitchNotes := LStyle.PitchNotesAt(LIndex);
        LGrid := CreateStyleSourceGrid(LEvidence, LContext.TicksPerQuarter, LContext.StepTicks);
        try
          LPitchSummary := SummarizePitchCells(LEvidence.Pitch, LGrid, LEvidence.Source.Channels);
        finally
          LGrid.Free;
        end;
        LSummaryRow := TJSONObject.Create;
        LRow.Add('pitch_summary', LSummaryRow);
        LSummaryRow.Add('cells', LPitchSummary.Cells);
        LSummaryRow.Add('admitted_pitch', LPitchSummary.AdmittedPitch);
        LSummaryRow.Add('measured_silence', LPitchSummary.MeasuredSilence);
        LSummaryRow.Add('uncertain_pitch', LPitchSummary.UncertainPitch);
        LSummaryRow.Add('unmeasured', LPitchSummary.Unmeasured);
        LSummaryRow.Add('known_runs', LPitchSummary.KnownRuns);
        LSummaryRow.Add('longest_known_run', LPitchSummary.LongestKnownRun);
        LSummaryRow.Add('interpretation', 'Observed source runs; not a confidence score or maximum generatable length');
        LPitchRows := TJSONArray.Create;
        LRow.Add('pitch_cells', LPitchRows);
        for LOnsetIndex := 0 to High(LPitchNotes) do
        begin
          LPitchRow := TJSONObject.Create;
          LPitchRows.Add(LPitchRow);
          LPitchRow.Add('cell', LOnsetIndex);
          LPitchRow.Add('measured', LEvidence.Pitch.Cells[LOnsetIndex].Measured);
          LPitchRow.Add('admitted_note', LPitchNotes[LOnsetIndex]);
          if LEvidence.Pitch.Cells[LOnsetIndex].Measured then
          begin
            LPitchRow.Add('status', Ord(LEvidence.Pitch.Cells[LOnsetIndex].Estimate.Status));
            LPitchRow.Add('frequency_hz', LEvidence.Pitch.Cells[LOnsetIndex].Estimate.FrequencyHz);
            LPitchRow.Add('period_frames', LEvidence.Pitch.Cells[LOnsetIndex].Estimate.PeriodFrames);
            LPitchRow.Add('normalized_difference', LEvidence.Pitch.Cells[LOnsetIndex].Estimate.NormalizedDifference);
            LPitchRow.Add('ac_rms', LEvidence.Pitch.Cells[LOnsetIndex].Estimate.AcRms);
            LPitchRow.Add('nearest_midi', LEvidence.Pitch.Cells[LOnsetIndex].Estimate.NearestMidi);
            LPitchRow.Add('cents_error', LEvidence.Pitch.Cells[LOnsetIndex].Estimate.CentsError);
          end;
        end;
      end;
      if LEvidence.Duration.WindowFrames > 0 then
      begin
        LRow.Add('duration_articulate_onsets', LEvidence.DurationArticulateOnsets);
        LDurationTrack := LStyle.CopyDurationTrack(LIndex);
        LRow.Add('duration_window_frames', LDurationTrack.WindowFrames);
        LRow.Add('duration_hop_frames', LDurationTrack.Options.HopFrames);
        LRow.Add('duration_channel', LDurationTrack.Channel);
        LRow.Add('duration_minimum_run_windows', LDurationTrack.Options.MinimumRunWindows);
        LRow.Add('duration_window_count', LDurationTrack.WindowCount);
        LRow.Add('duration_pitch_run_count', LDurationTrack.RunCount);
        LSpans := LDurationTrack.CopySpans;
        LPitchRows := TJSONArray.Create;
        LRow.Add('duration_spans', LPitchRows);
        for LSpanIndex := 0 to High(LSpans) do
        begin
          LPitchRow := TJSONObject.Create;
          LPitchRows.Add(LPitchRow);
          LPitchRow.Add('kind', Ord(LSpans[LSpanIndex].Kind));
          LPitchRow.Add('note', LSpans[LSpanIndex].Note);
          LPitchRow.Add('first_window', LSpans[LSpanIndex].FirstWindow);
          LPitchRow.Add('window_count', LSpans[LSpanIndex].WindowCount);
          LPitchRow.Add('start_frame', LSpans[LSpanIndex].StartFrame);
          LPitchRow.Add('end_frame', LSpans[LSpanIndex].EndFrame);
        end;
        LTimedSpans := LStyle.CopyTimedDurationSpans(LIndex);
        LPitchRows := TJSONArray.Create;
        LRow.Add('duration_timed_spans', LPitchRows);
        for LSpanIndex := 0 to High(LTimedSpans) do
        begin
          LPitchRow := TJSONObject.Create;
          LPitchRows.Add(LPitchRow);
          LPitchRow.Add('kind', Ord(LTimedSpans[LSpanIndex].Kind));
          LPitchRow.Add('note', LTimedSpans[LSpanIndex].Note);
          LPitchRow.Add('start_tick', LTimedSpans[LSpanIndex].StartTick);
          LPitchRow.Add('end_tick', LTimedSpans[LSpanIndex].EndTick);
        end;
        FreeAndNil(LDurationTrack);
      end;
      if LEvidence.Dynamics.WindowFrames > 0 then
      begin
        LRow.Add('dynamics_window_frames', LEvidence.Dynamics.WindowFrames);
        LRow.Add('intensity_pattern', LStyle.IntensityPatternAt(LIndex));
      end;
      LOnsets := TJSONArray.Create;
      LRow.Add('onsets', LOnsets);
      for LOnsetIndex := 0 to High(LEvidence.OnsetFrames) do
      begin
        LOnset := TJSONObject.Create;
        LOnsets.Add(LOnset);
        LOnset.Add('source_frame', LEvidence.OnsetFrames[LOnsetIndex]);
        if LEvidence.Dynamics.WindowFrames > 0 then
        begin
          LOnset.Add('rms', LEvidence.Dynamics.Rms[LOnsetIndex]);
        end;
        LOnset.Add('grid_cell', LAdmission.Cells[LOnsetIndex]);
        LOnset.Add('frame_error', LAdmission.FrameErrors[LOnsetIndex]);
        LOnset.Add('decision', Ord(LAdmission.Decisions[LOnsetIndex]));
      end;
    end;
    WriteTextFile(ParamStr(3), LDocument.FormatJSON);
    WriteLn('Inspected style ', LStyle.Identity, '; source count ', LStyle.SourceCount);
  finally
    LDurationTrack.Free;
    LDocument.Free;
    LModel.Free;
    LContext.Free;
    LStyle.Free;
  end;
end;

begin
  try
    if ((ParamStr(1) = 'learn') or (ParamStr(1) = 'learn-dynamics')) and (ParamCount in [6, 7]) then
    begin
      Learn;
    end
    else if ((ParamStr(1) = 'learn-pitch') or (ParamStr(1) = 'learn-duration')) and
      (ParamCount >= 8) and (ParamCount <= 12) and
      (ParamStr(8) = '--monophonic') then
    begin
      Learn;
    end
    else if (ParamStr(1) = 'learn-trajectory') and (ParamCount = 13) then
    begin
      LearnTrajectory;
    end
    else if (ParamStr(1) = 'learn-timbre') and (ParamCount = 10) then
    begin
      LearnTimbre;
    end
    else if (ParamStr(1) = 'learn-envelope') and (ParamCount = 10) then
    begin
      LearnEnvelope;
    end
    else if (ParamStr(1) = 'blend-layers') and ((ParamCount = 12) or (ParamCount = 14)) then
    begin
      Blend(True, True);
    end
    else if (ParamStr(1) = 'blend') and (ParamCount = 8) then
    begin
      Blend(False);
    end
    else if (ParamStr(1) = 'blend-dimensions') and (ParamCount = 10) then
    begin
      Blend(True);
    end
    else if (ParamStr(1) = 'prefer') and (ParamCount = 6) then
    begin
      Prefer(False);
    end
    else if (ParamStr(1) = 'clear-preferences') and (ParamCount = 4) then
    begin
      Prefer(True);
    end
    else if ParamStr(1) = 'providers' then
    begin
      InspectProviders;
    end
    else if (ParamStr(1) = 'inspect') and (ParamCount = 3) then
    begin
      Inspect;
    end
    else
    begin
      raise EAudio.Create('Usage: pythian.style learn|learn-dynamics CONTEXT.pcp SOURCE.wav ONSETS.json MAX_ERROR_FRAMES OUTPUT.pys [PROVENANCE]; ' +
        'learn-pitch|learn-duration CONTEXT.pcp SOURCE.wav ONSETS.json MAX_ERROR_FRAMES OUTPUT.pys CHANNEL --monophonic [--articulate-onsets (duration only)] [--window-frames N (duration only)] [PROVENANCE]; ' +
        'blend LEFT.pys RIGHT.pys KEY_SIDE TEMPO_SIDE LEFT_WEIGHT RIGHT_WEIGHT OUTPUT.pys; ' +
        'learn-timbre SOURCE_STYLE.pys SOURCE.wav START COUNT CHANNEL HARMONICS HZ|auto[:PITCH_FRAMES] MAX_ERROR OUTPUT.pys; ' +
        'learn-trajectory SOURCE_STYLE.pys SOURCE.wav ORIGIN START HOP WINDOW KNOTS CHANNEL HARMONICS HZ MAX_ERROR OUTPUT.pys; ' +
        'learn-envelope SOURCE_STYLE.pys SOURCE.wav START COUNT GATE CHANNEL WINDOW MAX_TAIL_RATIO OUTPUT.pys; ' +
        'blend-layers LEFT.pys RIGHT.pys KEY_SIDE TEMPO_SIDE LEFT_RHYTHM RIGHT_RHYTHM LEFT_PITCH RIGHT_PITCH LEFT_TIMBRE RIGHT_TIMBRE [LEFT_ENVELOPE RIGHT_ENVELOPE] OUTPUT.pys; ' +
        'blend-dimensions LEFT.pys RIGHT.pys KEY_SIDE TEMPO_SIDE LEFT_RHYTHM RIGHT_RHYTHM LEFT_PITCH RIGHT_PITCH OUTPUT.pys; ' +
        'prefer INPUT.pys PROVIDER TOKEN MULTIPLIER OUTPUT.pys; ' +
        'clear-preferences INPUT.pys PROVIDER OUTPUT.pys; inspect INPUT.pys OUTPUT.json; ' +
        'providers INPUT.pys grid|coupled CELLS; ' +
        'providers INPUT.pys performance SPANS KEY_CELLS TEMPO_CELLS');
    end;
  except
    on LException: Exception do
    begin
      WriteLn(StdErr, LException.ClassName, ': ', LException.Message);
      Halt(1);
    end;
  end;
end.
