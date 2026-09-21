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
program pythian_sources_demo;

{$mode delphi}
{$H+}

uses
  Classes,
  SysUtils,
  Math,
  pythian.audio,
  pythian.automation,
  pythian.envelope,
  pythian.wave,
  pythian.wave.read,
  pythian.hash,
  pythian.source,
  pythian.source.oscillator,
  pythian.source.sample,
  pythian.source.wavetable,
  pythian.pitch,
  pythian.oscillator,
  pythian.additive,
  pythian.music,
  pythian.music.render,
  pythian.midi.smf,
  pythian.midi.notes,
  pythian.synth;

function RenderCycleMidi(const APath: String;
  const AFactory: TAudioSourceFactory;
  const AEnvelope: TGateEnvelope = nil): TAudioClip;
var
  LStream: TFileStream;
  LBytes: TMidiBytes;
  LSequence: TNoteSequence;
  LImport: TMidiNoteReport;
  LReport: TNoteRenderReport;
  LVoice: TSynthVoice;
  LTones: TFrameTones;
begin
  LStream := TFileStream.Create(APath, fmOpenRead or fmShareDenyWrite);
  try
    if (LStream.Size < 1) or (LStream.Size > DefaultMidiReadLimits.MaxFileBytes) then
    begin
      raise EAudio.Create('Cycle audition MIDI exceeds file size bound');
    end;
    SetLength(LBytes, Integer(LStream.Size));
    LStream.ReadBuffer(LBytes[0], Length(LBytes));
  finally
    LStream.Free;
  end;
  LSequence := DecodeMidiNotes(LBytes, DefaultMidiNoteOptions, LImport);
  try
    LVoice := DefaultSynthVoice;
    LVoice.SourceFactory := AFactory;
    LVoice.GateEnvelope := AEnvelope;
    LVoice.CutoffHz := 12000;
    LVoice.Gain := 0.3;
    LVoice.Envelope.AttackSeconds := 0.005;
    LVoice.Envelope.ReleaseSeconds := 0;
    LTones := PlanNoteTones(LSequence, 48000, LVoice, LReport);
    if (LReport.SubFrameNotes <> 0) or (LReport.RenderedNotes <> LSequence.NoteCount) or
      (LImport.ZeroLengthNotes <> 0) then
    begin
      raise EAudio.Create('Cycle audition requires every MIDI note to have a positive output gate');
    end;
    Result := RenderFrameTones(LTones, 48000,
      Integer(LSequence.FrameAtTick(LSequence.LengthTicks, 48000)));
    WriteLn('MIDI SHA256: ', Sha256Bytes(LBytes));
    if AEnvelope = nil then
    begin
      WriteLn('MIDI audition: ', LReport.RenderedNotes, ' notes, ', Result.FrameCount,
        ' stereo frames; one measured periodic voice for all notes, zero release tail.');
    end
    else
    begin
      WriteLn('MIDI audition: ', LReport.RenderedNotes, ' notes, ', Result.FrameCount,
        ' stereo frames; shared measured amplitude envelope, release frames=',
        AEnvelope.ReleaseFrames, '.');
    end;
  finally
    LSequence.Free;
  end;
end;

function ReadCycle(const AInput: String; const AStart: Int64;
  const ACount, AChannel, AHarmonics: Integer; const AFrequency: String = '';
  const AMaximumError: Double = 0): TWavetableCycleRecipe;
var
  LStream: TFileStream;
  LReader: TWaveFrameReader;
  LInput: TAudioClip;
  LRecipe: TWavetableCycleRecipe;
  LHash: String;
  LSourceRate: Integer;
  LFit: THarmonicFit;
  LPitch: TPitchEstimate;
  LFrequency: Double;
  LFormat: TFormatSettings;
  LMaximum: Integer;
  LIndex: Integer;
  LPitchFrames: Integer;
  LReadCount: Integer;
  LAutomatic: Boolean;
begin
  LMaximum := MaximumWavetableCycleFrames;
  LFormat := DefaultFormatSettings;
  LFormat.DecimalSeparator := '.';
  if AFrequency <> '' then
  begin
    LMaximum := MaximumHarmonicFitFrames;
    RequireFinite(AMaximumError, 'Maximum harmonic fit relative error');
    if (AMaximumError < 0) or (AMaximumError > 1) then
    begin
      raise EAudio.Create('Maximum harmonic fit relative error must be in 0..1');
    end;
  end;
  if (AStart < 0) or (ACount < 3) or (ACount > LMaximum) then
  begin
    raise EAudio.Create('Periodic source interval exceeds frame bounds');
  end;
  LReadCount := ACount;
  LPitchFrames := ACount;
  LAutomatic := (AFrequency = 'auto') or (Copy(AFrequency, 1, 5) = 'auto:');
  if Copy(AFrequency, 1, 5) = 'auto:' then
  begin
    LPitchFrames := StrToInt(Copy(AFrequency, 6, Length(AFrequency)));
  end;
  if LAutomatic then
  begin
    if (LPitchFrames < 16) or (LPitchFrames > MaximumPitchWindowFrames) then
    begin
      raise EAudio.Create('Automatic harmonic frequency requires 16..8192 pitch frames');
    end;
    LReadCount := Max(LReadCount, LPitchFrames);
  end;
  LStream := TFileStream.Create(AInput, fmOpenRead or fmShareDenyWrite);
  try
    LHash := Sha256Stream(LStream, LStream.Size);
    WriteLn('Source SHA256: ', LHash);
    LStream.Position := 0;
    LReader := TWaveFrameReader.Create(LStream);
    try
      LSourceRate := LReader.SampleRate;
      if (AStart > LReader.FrameCount) or (LReadCount > LReader.FrameCount - AStart) then
      begin
        raise EAudio.Create('Selected cycle exceeds WAV frames');
      end;
      LReader.SeekFrame(AStart);
      LInput := TAudioClip.Create(LReader.SampleRate, LReader.Channels,
        LReader.ReadFrames(LReadCount));
      try
        if AFrequency = '' then
        begin
          LRecipe := AnalyzeWavetableCycle(LInput, 0, ACount, AChannel, AHarmonics);
        end
        else
        begin
          if LAutomatic then
          begin
            LPitch := EstimatePitch(Copy(LInput.CopySamples, 0,
              LPitchFrames * LInput.Channels), LInput.SampleRate,
              LInput.Channels, AChannel, DefaultPitchOptions);
            if LPitch.Status <> psEstimated then
            begin
              raise EAudio.Create('Harmonic fit interval has no admitted periodic frequency');
            end;
            LFrequency := LPitch.FrequencyHz;
            WriteLn('Frequency evidence: start=', AStart, ' frames=', LPitchFrames,
              ' channel=', AChannel, ' normalized difference=',
              LPitch.NormalizedDifference:0:12);
          end
          else
          begin
            LFrequency := StrToFloat(AFrequency, LFormat);
          end;
          LFit := FitWavetableHarmonics(LInput, 0, ACount, AChannel, AHarmonics, LFrequency);
          WriteLn('Harmonic fit: frequency=', LFit.FrequencyHz:0:12,
            ' AC RMS=', LFit.AcRms:0:12, ' residual RMS=', LFit.ResidualRms:0:12,
            ' relative error=', LFit.RelativeError:0:12);
          if (LFit.AcRms <= DefaultPitchOptions.SilenceRms) or
            (LFit.RelativeError > AMaximumError) then
          begin
            raise EAudio.Create('Harmonic fit lacks AC evidence or exceeds the declared relative error');
          end;
          LRecipe := LFit.Recipe;
          for LIndex := 0 to High(LRecipe.Sine) do
          begin
            WriteLn('Harmonic ', LIndex + 1, ': sine=', LRecipe.Sine[LIndex]:0:12,
              ' cosine=', LRecipe.Cosine[LIndex]:0:12);
          end;
        end;
      finally
        LInput.Free;
      end;
    finally
      LReader.Free;
    end;
  finally
    LStream.Free;
  end;
  WriteLn('Selected interval: start=', AStart, ' frames=', ACount,
    ' channel=', AChannel, ' harmonics=', AHarmonics, ' source rate=', LSourceRate,
    ' removed DC=', LRecipe.Mean:0:9);
  Result := LRecipe;
end;

procedure RequireSeparateOutput(const AOutput, AInput: String);
begin
  if SameText(ExpandFileName(AOutput), ExpandFileName(AInput)) then
  begin
    raise EAudio.Create('Cycle/MIDI input and output paths must differ');
  end;
end;

procedure RenderEnvelope;
var
  LStream: TFileStream;
  LReader: TWaveFrameReader;
  LClip: TAudioClip;
  LOutput: TAudioClip;
  LTrace: TEnvelopeTrace;
  LEnvelope: TGateEnvelope;
  LFactory: TWaveSourceFactory;
  LStart: Int64;
  LCount: Integer;
  LGate: Integer;
  LPoints: TAutomationPoints;
  LTones: TFrameTones;
  LFormat: TFormatSettings;
  LMaximumTail: Double;
  I: Integer;
begin
  RequireSeparateOutput(ParamStr(1), ParamStr(3));
  if ParamCount = 11 then
  begin
    RequireSeparateOutput(ParamStr(1), ParamStr(11));
  end;
  LStart := StrToInt64(ParamStr(4));
  LCount := StrToInt(ParamStr(5));
  LGate := StrToInt(ParamStr(6));
  LFormat := DefaultFormatSettings;
  LFormat.DecimalSeparator := '.';
  LMaximumTail := StrToFloat(ParamStr(9), LFormat);
  if (LStart < 0) or (LCount < 1) or (LCount > MaximumEnvelopeFrames) then
  begin
    raise EAudio.Create('Envelope selection exceeds frame bounds');
  end;
  LTrace := nil;
  LEnvelope := nil;
  LFactory := nil;
  LOutput := nil;
  try
    LStream := TFileStream.Create(ParamStr(3), fmOpenRead or fmShareDenyWrite);
    try
      WriteLn('Envelope source SHA256: ', Sha256Stream(LStream, LStream.Size));
      LStream.Position := 0;
      LReader := TWaveFrameReader.Create(LStream);
      try
        if (LStart > LReader.FrameCount) or (LCount > LReader.FrameCount - LStart) then
        begin
          raise EAudio.Create('Envelope selection exceeds WAV extent');
        end;
        LReader.SeekFrame(LStart);
        LClip := TAudioClip.Create(LReader.SampleRate, LReader.Channels,
          LReader.ReadFrames(LCount));
        try
          LTrace := TEnvelopeTrace.Create(LClip, 0, LCount,
            StrToInt(ParamStr(7)), StrToInt(ParamStr(8)));
        finally
          LClip.Free;
        end;
      finally
        LReader.Free;
      end;
    finally
      LStream.Free;
    end;
    WriteLn('Envelope selection: start=', LStart, ' frames=', LCount,
      ' source rate=', LTrace.SampleRate, ' channel=', LTrace.Channel,
      ' window=', LTrace.WindowFrames, ' declared gate=', LGate,
      ' maximum tail/gate RMS=', LMaximumTail:0:9);
    LPoints := LTrace.CopyRmsPoints;
    WriteLn('Envelope peak window RMS=', LTrace.PeakRms:0:12,
      '; rectangular nonoverlapping windows; final partial window excludes padding.');
    for I := 0 to High(LPoints) do
    begin
      WriteLn('RMS frame=', LPoints[I].Frame, ' value=', LPoints[I].Value:0:12);
    end;
    LEnvelope := LTrace.CreateGateEnvelope(LGate, 48000, LMaximumTail);
    LFactory := TWaveSourceFactory.Create(wsSine);
    if ParamCount = 11 then
    begin
      LOutput := RenderCycleMidi(ParamStr(11), LFactory, LEnvelope);
    end
    else
    begin
      SetLength(LTones, 1);
      LTones[0].Voice := DefaultSynthVoice;
      LTones[0].Voice.SourceFactory := LFactory;
      LTones[0].Voice.GateEnvelope := LEnvelope;
      LTones[0].Voice.Gain := 0.3;
      LTones[0].Voice.CutoffHz := 12000;
      LTones[0].GateFrames := Int64(LGate) * 48000 div LTrace.SampleRate;
      LTones[0].FrequencyHz := 440;
      LTones[0].Velocity := 1;
      LOutput := RenderFrameTones(LTones, 48000);
    end;
    SaveWavePcm16(ParamStr(1), LOutput);
    WriteLn('Measured envelope audition: ', LOutput.FrameCount,
      ' stereo 48000-Hz frames; peak-normalized envelope applied to a sine source.');
    WriteLn('Gate is caller-declared; no instrument separation, note-boundary inference or timbre learning.');
  finally
    LOutput.Free;
    LFactory.Free;
    LEnvelope.Free;
    LTrace.Free;
  end;
end;

procedure RenderCycle(const AOutput, AInput, AMidi: String; const AStart: Int64;
  const ACount, AChannel, AHarmonics: Integer; const AFrequency: String = '';
  const AMaximumError: Double = 0);
const
  CNotes: array[0..7] of Integer = (48, 55, 60, 64, 67, 72, 76, 79);
var
  LOutput: TAudioClip;
  LFactory: TWavetableSourceFactory;
  LRecipe: TWavetableCycleRecipe;
  LTones: TFrameTones;
  LIndex: Integer;
begin
  RequireSeparateOutput(AOutput, AInput);
  if AMidi <> '' then
  begin
    RequireSeparateOutput(AOutput, AMidi);
  end;
  LRecipe := ReadCycle(AInput, AStart, ACount, AChannel, AHarmonics,
    AFrequency, AMaximumError);
  LFactory := TWavetableSourceFactory.Create(LRecipe.Sine, LRecipe.Cosine);
  try
    SetLength(LTones, Length(CNotes));
    for LIndex := 0 to High(LTones) do
    begin
      LTones[LIndex].Voice := DefaultSynthVoice;
      LTones[LIndex].Voice.SourceFactory := LFactory;
      LTones[LIndex].Voice.CutoffHz := 12000;
      LTones[LIndex].Voice.Gain := 0.45;
      LTones[LIndex].Voice.Envelope.AttackSeconds := 0.005;
      LTones[LIndex].Voice.Envelope.ReleaseSeconds := 0.08;
      LTones[LIndex].StartFrame := LIndex * 24000;
      LTones[LIndex].GateFrames := 16800;
      LTones[LIndex].FrequencyHz := MidiFrequency(CNotes[LIndex]);
      LTones[LIndex].Velocity := 1;
      LTones[LIndex].Seed := 731;
    end;
    if AMidi = '' then
    begin
      LOutput := RenderFrameTones(LTones, 48000, 192000);
    end
    else
    begin
      LOutput := RenderCycleMidi(AMidi, LFactory);
    end;
    try
      SaveWavePcm16(AOutput, LOutput);
    finally
      LOutput.Free;
    end;
  finally
    LFactory.Free;
  end;
  if AMidi = '' then
  begin
    WriteLn('Four seconds / eight authored notes, stereo 48000 Hz; harmonics measured from the selected WAV interval.');
  end;
  WriteLn('The interval is caller-selected; no inferred voice roles or automatic amplitude normalization.');
end;

procedure RenderHarmonics;
var
  LMidi: String;
  LFormat: TFormatSettings;
begin
  LMidi := '';
  if ParamCount = 11 then
  begin
    LMidi := ParamStr(11);
  end;
  LFormat := DefaultFormatSettings;
  LFormat.DecimalSeparator := '.';
  RenderCycle(ParamStr(1), ParamStr(3), LMidi, StrToInt64(ParamStr(4)),
    StrToInt(ParamStr(5)), StrToInt(ParamStr(6)), StrToInt(ParamStr(7)),
    ParamStr(8), StrToFloat(ParamStr(9), LFormat));
end;

procedure RenderTrajectory(const AMagnitude: Boolean = False);
var
  LStream: TFileStream;
  LReader: TWaveFrameReader;
  LInput: TAudioClip;
  LOutput: TAudioClip;
  LFactory: TWavetableSourceFactory;
  LCurve: TAutomationCurve;
  LRecipes: TWavetableCycleRecipes;
  LPoints: TAutomationPoints;
  LFit: THarmonicFit;
  LShape: TWavetableMagnitudeShape;
  LTones: TFrameTones;
  LFormat: TFormatSettings;
  LStart: Int64;
  LSpan: Int64;
  LHop: Integer;
  LWindow: Integer;
  LKnots: Integer;
  LChannel: Integer;
  LHarmonics: Integer;
  LRate: Integer;
  LIndex: Integer;
  LHarmonic: Integer;
  LFrame: Integer;
  LMidiArgument: Integer;
  LFrequency: Double;
  LMaximumError: Double;
  LAngle: Double;
  LSine: Double;
  LCosine: Double;
  LPeak: Double;
  LTargetRms: Double;
begin
  RequireSeparateOutput(ParamStr(1), ParamStr(3));
  LMidiArgument := 13 + Ord(AMagnitude);
  if ParamCount = LMidiArgument then
  begin
    RequireSeparateOutput(ParamStr(1), ParamStr(LMidiArgument));
  end;
  LStart := StrToInt64(ParamStr(4));
  LHop := StrToInt(ParamStr(5));
  LWindow := StrToInt(ParamStr(6));
  LKnots := StrToInt(ParamStr(7));
  LChannel := StrToInt(ParamStr(8));
  LHarmonics := StrToInt(ParamStr(9));
  LFormat := DefaultFormatSettings;
  LFormat.DecimalSeparator := '.';
  LFrequency := StrToFloat(ParamStr(10), LFormat);
  LMaximumError := StrToFloat(ParamStr(11), LFormat);
  LTargetRms := 0;
  if AMagnitude then
  begin
    LTargetRms := StrToFloat(ParamStr(12), LFormat);
    RequireFinite(LTargetRms, 'Trajectory target cycle RMS');
    if (LTargetRms <= 0) or (LTargetRms > 16) then
    begin
      raise EAudio.Create('Magnitude trajectory target cycle RMS must be in (0,16]');
    end;
  end;
  RequireFinite(LMaximumError, 'Trajectory relative-error limit');
  if (LStart < 0) or (LHop < 1) or (LWindow < 16) or
    (LKnots < 2) or (LKnots > MaximumWavetableTrajectoryRecipes) or
    (LMaximumError < 0) or (LMaximumError > 1) then
  begin
    raise EAudio.Create('Trajectory requires positive geometry, 2..32 knots and error limit 0..1');
  end;
  LSpan := Int64(LKnots - 1) * LHop + LWindow;
  if LSpan > MaximumHarmonicFitFrames then
  begin
    raise EAudio.Create('Trajectory source span exceeds 65536 frames');
  end;
  LInput := nil;
  LOutput := nil;
  LFactory := nil;
  LCurve := nil;
  try
    LStream := TFileStream.Create(ParamStr(3), fmOpenRead or fmShareDenyWrite);
    try
      WriteLn('Trajectory source SHA256: ', Sha256Stream(LStream, LStream.Size));
      LStream.Position := 0;
      LReader := TWaveFrameReader.Create(LStream);
      try
        LRate := LReader.SampleRate;
        if (LStart > LReader.FrameCount) or (LSpan > LReader.FrameCount - LStart) or
          (LChannel < 0) or (LChannel >= LReader.Channels) then
        begin
          raise EAudio.Create('Trajectory selection exceeds WAV extent/channel');
        end;
        if HarmonicFitWork(LWindow, LRate, LHarmonics, LFrequency) * LKnots >
          MaximumHarmonicFitWork then
        begin
          raise EAudio.Create('Trajectory fitting exceeds cumulative harmonic-work budget');
        end;
        LReader.SeekFrame(LStart);
        LInput := TAudioClip.Create(LRate, LReader.Channels, LReader.ReadFrames(Integer(LSpan)));
      finally
        LReader.Free;
      end;
    finally
      LStream.Free;
    end;
    WriteLn('Trajectory selection: start=', LStart, ' hop=', LHop, ' window=', LWindow,
      ' knots=', LKnots, ' channel=', LChannel, ' rate=', LRate,
      ' fundamental=', LFrequency:0:12, ' max relative residual=', LMaximumError:0:9);
    SetLength(LRecipes, LKnots);
    SetLength(LPoints, LKnots);
    for LIndex := 0 to LKnots - 1 do
    begin
      LFit := FitWavetableHarmonics(LInput, LIndex * LHop, LWindow, LChannel,
        LHarmonics, LFrequency);
      WriteLn('Knot ', LIndex, ': start=', LStart + Int64(LIndex) * LHop,
        ' AC RMS=', LFit.AcRms:0:12, ' relative residual=', LFit.RelativeError:0:12);
      if (LFit.AcRms < 1E-5) or (LFit.RelativeError > LMaximumError) then
      begin
        raise EAudio.Create('Trajectory knot lacks AC evidence or exceeds its residual limit');
      end;
      LRecipes[LIndex] := LFit.Recipe;
      if AMagnitude then
      begin
        LShape := FactorWavetableMagnitudes(LFit.Recipe);
        WriteLn('Knot ', LIndex, ': modeled cycle RMS=', LShape.CycleRms:0:12);
      end;
      { Local fits start at phase zero in each window. Express every recipe at
        the selection's first frame using the caller-declared fixed fundamental.
        This coordinate rotation is not estimated phase/drift alignment. }
      if not AMagnitude then
      begin
        for LHarmonic := 0 to High(LRecipes[LIndex].Sine) do
        begin
          LAngle := 2 * Pi * Frac((LHarmonic + 1) * LFrequency * LIndex * LHop / LRate);
          LSine := LFit.Recipe.Sine[LHarmonic];
          LCosine := LFit.Recipe.Cosine[LHarmonic];
          LRecipes[LIndex].Sine[LHarmonic] := LSine * Cos(LAngle) + LCosine * Sin(LAngle);
          LRecipes[LIndex].Cosine[LHarmonic] := LCosine * Cos(LAngle) - LSine * Sin(LAngle);
        end;
      end;
      LPoints[LIndex].Frame := (2 * Int64(LIndex) * LHop + LWindow - 1) * 48000 div (2 * LRate);
      LPoints[LIndex].Value := LIndex;
      LPoints[LIndex].Transition := atLinear;
    end;
    LCurve := TAutomationCurve.Create(LPoints);
    if AMagnitude then
    begin
      LFactory := TWavetableSourceFactory.CreateMagnitudeTrajectory(LRecipes, LCurve, LTargetRms);
    end
    else
    begin
      LFactory := TWavetableSourceFactory.CreateTrajectory(LRecipes, LCurve);
    end;
    if ParamCount = LMidiArgument then
    begin
      LOutput := RenderCycleMidi(ParamStr(LMidiArgument), LFactory);
    end
    else
    begin
      SetLength(LTones, 3);
      for LIndex := 0 to High(LTones) do
      begin
        LTones[LIndex].Voice := DefaultSynthVoice;
        LTones[LIndex].Voice.SourceFactory := LFactory;
        LTones[LIndex].Voice.Gain := 0.3;
        LTones[LIndex].Voice.CutoffHz := 12000;
        LTones[LIndex].Voice.Envelope.AttackSeconds := 0.005;
        LTones[LIndex].Voice.Envelope.ReleaseSeconds := 0.08;
        LTones[LIndex].GateFrames := LSpan * 48000 div LRate;
        LTones[LIndex].StartFrame := LIndex * (LTones[LIndex].GateFrames + 4800);
        LTones[LIndex].FrequencyHz := LFrequency * Power(2, LIndex / 2);
        LTones[LIndex].Velocity := 1;
      end;
      LOutput := RenderFrameTones(LTones, 48000);
    end;
    LPeak := 0;
    for LFrame := 0 to LOutput.FrameCount - 1 do
    begin
      LPeak := Max(LPeak, Max(Abs(LOutput.SampleAt(LFrame, 0)), Abs(LOutput.SampleAt(LFrame, 1))));
    end;
    if LPeak > 1 then
    begin
      raise EAudio.Create('Trajectory audition exceeds PCM headroom');
    end;
    SaveWavePcm16(ParamStr(1), LOutput);
    WriteLn('Trajectory audition: ', LOutput.FrameCount, ' stereo 48000-Hz frames; peak=', LPeak:0:9);
    if AMagnitude then
    begin
      WriteLn('Magnitude shape at window centers; target full-model cycle RMS=', LTargetRms:0:9,
        '; phase/DC discarded, pitch-cap attenuation retained.');
      WriteLn('Separate harmonic level, not perceptual loudness; no automatic note inference or saved style trajectory.');
    end
    else
    begin
      WriteLn('Caller-declared fixed pitch/windows; linear signed coefficients at window centers, DC excluded.');
      WriteLn('No automatic phase tracking, loudness separation, note inference or saved style trajectory.');
    end;
  finally
    LOutput.Free;
    LFactory.Free;
    LCurve.Free;
    LInput.Free;
  end;
end;

procedure RenderMorph;
var
  LFrom: TWavetableCycleRecipe;
  LTo: TWavetableCycleRecipe;
  LPoints: TAutomationPoints;
  LCurve: TAutomationCurve;
  LFactory: TWavetableSourceFactory;
  LOutput: TAudioClip;
  LFrames: Int64;
begin
  RequireSeparateOutput(ParamStr(1), ParamStr(3));
  RequireSeparateOutput(ParamStr(1), ParamStr(8));
  RequireSeparateOutput(ParamStr(1), ParamStr(15));
  LFrames := StrToInt64(ParamStr(13));
  if LFrames < 1 then
  begin
    raise EAudio.Create('Morph duration requires positive output frames');
  end;
  LFrom := ReadCycle(ParamStr(3), StrToInt64(ParamStr(4)), StrToInt(ParamStr(5)),
    StrToInt(ParamStr(6)), StrToInt(ParamStr(7)));
  LTo := ReadCycle(ParamStr(8), StrToInt64(ParamStr(9)), StrToInt(ParamStr(10)),
    StrToInt(ParamStr(11)), StrToInt(ParamStr(12)));
  SetLength(LPoints, 2);
  LPoints[0].Transition := atLinear;
  LPoints[1].Frame := LFrames;
  LPoints[1].Value := 1;
  LCurve := TAutomationCurve.Create(LPoints);
  try
    LFactory := TWavetableSourceFactory.CreateMorph(LFrom, LTo, LCurve);
  finally
    LCurve.Free;
  end;
  try
    LOutput := RenderCycleMidi(ParamStr(15), LFactory);
    try
      SaveWavePcm16(ParamStr(1), LOutput);
    finally
      LOutput.Free;
    end;
  finally
    LFactory.Free;
  end;
  WriteLn('Linear waveform morph from first to second cycle over ', LFrames,
    ' output frames per note, then hold; stereo 48000 Hz.');
  WriteLn('Declared cycle phases/amplitudes retained; no alignment, normalization or inferred timbre trajectory.');
end;

procedure RenderDemo(const AFileName: String);
var
  LFactories: array[0..4] of TAudioSourceFactory;
  LPartials: TAdditivePartials;
  LSine: array of Double;
  LSampleData: TAudioSamples;
  LSampleClip: TAudioClip;
  LOscillator: TOscillator;
  LTones: TFrameTones;
  LClip: TAudioClip;
  LIndex: Integer;
  LFrame: Integer;
  LTime: Double;
  LNoise: Double;
  LLevel: Double;
begin
  for LIndex := 0 to High(LFactories) do
  begin
    LFactories[LIndex] := nil;
  end;
  try
    LFactories[0] := TWaveSourceFactory.Create(wsSaw);
    SetLength(LPartials, 3);
    LPartials[0].Ratio := 1;
    LPartials[0].Gain := 0.7;
    LPartials[1].Ratio := 2.76;
    LPartials[1].Gain := 0.2;
    LPartials[2].Ratio := 5.4;
    LPartials[2].Gain := 0.1;
    LFactories[1] := TAdditiveSourceFactory.Create(LPartials);
    LFactories[2] := TFmSourceFactory.Create(fsmPhase, 1.5, 3);
    SetLength(LSine, 32);
    for LIndex := 0 to High(LSine) do
    begin
      if LIndex mod 2 = 0 then
      begin
        LSine[LIndex] := 0.8 / (LIndex + 1);
      end;
    end;
    LFactories[3] := TWavetableSourceFactory.Create(LSine, []);
    SetLength(LSampleData, 4000 * 2);
    LOscillator := TOscillator.Create(16000, 731);
    try
      for LFrame := 0 to 3999 do
      begin
        LTime := LFrame / 16000;
        LNoise := LOscillator.Next(wsNoise, 0);
        LLevel := 0.5 * Exp(-20 * LTime) * Min(1, LFrame / 32);
        LSampleData[LFrame * 2] := LLevel *
          (0.7 * Sin(2 * Pi * 220 * LTime) + 0.3 * LNoise);
        LSampleData[LFrame * 2 + 1] := LLevel *
          (0.7 * Sin(2 * Pi * 330 * LTime) + 0.3 * LNoise);
      end;
    finally
      LOscillator.Free;
    end;
    LSampleClip := TAudioClip.Create(16000, 2, LSampleData);
    try
      LFactories[4] := TSampleSourceFactory.Create(LSampleClip, 0, 4000, 220,
        spOneShot, sqSinc, 1);
    finally
      LSampleClip.Free;
    end;
    SetLength(LTones, 10);
    for LIndex := 0 to High(LTones) do
    begin
      LTones[LIndex].Voice := DefaultSynthVoice;
      LTones[LIndex].Voice.SourceFactory := LFactories[LIndex div 2];
      LTones[LIndex].Voice.CutoffHz := 12000;
      LTones[LIndex].Voice.Gain := 0.45;
      LTones[LIndex].Voice.Envelope.AttackSeconds := 0.005;
      LTones[LIndex].Voice.Envelope.ReleaseSeconds := 0.08;
      LTones[LIndex].StartFrame := (LIndex div 2) * 48000 + (LIndex mod 2) * 21600;
      LTones[LIndex].GateFrames := 16800;
      LTones[LIndex].FrequencyHz := 220 + (LIndex mod 2) * 110;
      LTones[LIndex].Velocity := 1;
      LTones[LIndex].Seed := 731;
    end;
    LClip := RenderFrameTones(LTones, 48000, 240000);
    try
      SaveWavePcm16(AFileName, LClip);
    finally
      LClip.Free;
    end;
  finally
    for LIndex := 0 to High(LFactories) do
    begin
      LFactories[LIndex].Free;
    end;
  end;
end;

begin
  try
    if (ParamStr(2) = '--trajectory-shape') and ((ParamCount = 12) or
      ((ParamCount = 14) and (ParamStr(13) = '--midi'))) then
    begin
      RenderTrajectory(True);
    end
    else if (ParamStr(2) = '--trajectory') and ((ParamCount = 11) or
      ((ParamCount = 13) and (ParamStr(12) = '--midi'))) then
    begin
      RenderTrajectory;
    end
    else if (ParamStr(2) = '--envelope') and ((ParamCount = 9) or
      ((ParamCount = 11) and (ParamStr(10) = '--midi'))) then
    begin
      RenderEnvelope;
    end
    else if (ParamStr(2) = '--harmonics') and ((ParamCount = 9) or
      ((ParamCount = 11) and (ParamStr(10) = '--midi'))) then
    begin
      RenderHarmonics;
    end
    else if (ParamCount = 15) and (ParamStr(2) = '--morph-cycle') and (ParamStr(14) = '--midi') then
    begin
      RenderMorph;
    end
    else if (ParamCount = 9) and (ParamStr(2) = '--cycle') and (ParamStr(8) = '--midi') then
    begin
      RenderCycle(ParamStr(1), ParamStr(3), ParamStr(9), StrToInt64(ParamStr(4)),
        StrToInt(ParamStr(5)), StrToInt(ParamStr(6)), StrToInt(ParamStr(7)));
    end
    else if (ParamCount = 7) and (ParamStr(2) = '--cycle') then
    begin
      RenderCycle(ParamStr(1), ParamStr(3), '', StrToInt64(ParamStr(4)),
        StrToInt(ParamStr(5)), StrToInt(ParamStr(6)), StrToInt(ParamStr(7)));
    end
    else if ParamCount = 1 then
    begin
      RenderDemo(ParamStr(1));
      WriteLn('5 seconds, stereo 48000 Hz. Two notes per one-second section:');
      WriteLn('Polynomial saw; additive; phase modulation; wavetable; stereo sample.');
      WriteLn('All sources use the same tone renderer, envelope, filter and pan path.');
    end
    else
    begin
      WriteLn('Usage: pythian.sources.demo OUTPUT.wav');
      WriteLn('   or: pythian.sources.demo OUTPUT.wav --envelope INPUT.wav START COUNT GATE CHANNEL WINDOW MAX_TAIL_RATIO [--midi NOTES.mid]');
      WriteLn('   or: pythian.sources.demo OUTPUT.wav --cycle INPUT.wav START_FRAME FRAME_COUNT CHANNEL HARMONICS [--midi NOTES.mid]');
      WriteLn('   or: pythian.sources.demo OUTPUT.wav --harmonics INPUT.wav START COUNT CHANNEL HARMONICS HZ|auto[:PITCH_FRAMES] MAX_RELATIVE_ERROR [--midi NOTES.mid]');
      WriteLn('   or: pythian.sources.demo OUTPUT.wav --morph-cycle FROM.wav START COUNT CHANNEL HARMONICS TO.wav START COUNT CHANNEL HARMONICS MORPH_FRAMES --midi NOTES.mid');
      WriteLn('   or: pythian.sources.demo OUTPUT.wav --trajectory INPUT.wav START HOP WINDOW KNOTS CHANNEL HARMONICS HZ MAX_RELATIVE_ERROR [--midi NOTES.mid]');
      WriteLn('   or: pythian.sources.demo OUTPUT.wav --trajectory-shape INPUT.wav START HOP WINDOW KNOTS CHANNEL HARMONICS HZ MAX_RELATIVE_ERROR TARGET_RMS [--midi NOTES.mid]');
      Halt(2);
    end;
  except
    on LException: Exception do
    begin
      WriteLn(StdErr, LException.ClassName, ': ', LException.Message);
      Halt(1);
    end;
  end;
end.
