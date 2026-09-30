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
program pythian_example_wfc_provider;

{$mode delphi}
{$H+}

{ Caller-owned, first-party authored provider example. No recorded source,
  inference, inferred musical role, learned-style or outside-consumer acceptance
  is claimed. The sample corpus and provider definition below belong to this
  caller; canonical Pythian pitch codecs are reused without a built-in provider.

  Usage: pythian.example.wfc.provider OUTPUT.wav [GAIN [SEED]]
  GAIN: finite 0..1, dot decimal, default 0.25.
  SEED: unsigned decimal 0..4294967295, default 731 (zero is explicit/replayable).
  Output: PCM16, 16000 Hz, stereo, 16000 frames, exactly one second.

  All arguments, directory checks, generation and rendering validate before
  opening the output. Existing output files are rejected; choose a fresh path.
  Direct SaveWavePcm16 is not a transaction: an I/O failure during writing can
  leave a partial new file. Concurrent writers to that path are unsupported.
  Reload verifies the actual saved WAV, not an in-memory encode/decode substitute.
  No playback, power-loss atomicity or hard-real-time guarantee is implied. }

uses
  SysUtils,
  pythian.audio,
  pythian.wave,
  pythian.synth,
  pythian.oscillator,
  pythian.wfc.pitch,
  pythian.wfc.providers,
  pythian.wfc.provider.contracts,
  pythian.wfc.layers,
  wfc,
  wfc_model,
  wfc_sequence,
  wfc_sequence_learn;

const
  CCellCount = 8;
  CSampleRate = 16000;
  CTicksPerQuarter = 480;
  CStepTicks = 120;
  CFramesPerCell = 2000; { 120 ticks at 480 PPQ / 120 BPM / 16000 Hz. }
  CFrameCount = CCellCount * CFramesPerCell;

function ReadGain(const AText: String): Double;
var
  LFormat: TFormatSettings;
begin
  LFormat := DefaultFormatSettings;
  LFormat.DecimalSeparator := '.';
  LFormat.ThousandSeparator := #0;
  if not TryStrToFloat(AText, Result, LFormat) then
  begin
    raise EAudio.Create('GAIN must be a finite dot-decimal number in 0..1');
  end;
  RequireFinite(Result, 'GAIN');
  if (Result < 0) or (Result > 1) then
  begin
    raise EAudio.Create('GAIN must be in 0..1');
  end;
end;

function ReadSeed(const AText: String): TGraphSeed;
var
  LValue: Int64;
  LIndex: Integer;
begin
  if (Length(AText) < 1) or (Length(AText) > 10) then
  begin
    raise EAudio.Create('SEED must be unsigned decimal in 0..4294967295');
  end;
  for LIndex := 1 to Length(AText) do
  begin
    if not (AText[LIndex] in ['0'..'9']) then
    begin
      raise EAudio.Create('SEED must be unsigned decimal in 0..4294967295');
    end;
  end;
  if not TryStrToInt64(AText, LValue) or (LValue > High(Cardinal)) then
  begin
    raise EAudio.Create('SEED must be unsigned decimal in 0..4294967295');
  end;
  Result := TGraphSeed(LValue);
end;

function OutputPath(const AText: String): String;
var
  LDirectory: String;
begin
  if (Trim(AText) = '') or (Pos(#0, AText) <> 0) or
    not SameText(ExtractFileExt(AText), '.wav') then
  begin
    raise EAudio.Create('OUTPUT must be a nonempty .wav file path');
  end;
  Result := ExpandFileName(AText);
  LDirectory := ExtractFilePath(Result);
  if FileExists(Result) or DirectoryExists(Result) or not DirectoryExists(LDirectory) then
  begin
    raise EAudio.Create('OUTPUT needs an existing parent directory and a fresh file path');
  end;
end;

function AuthoredSample(const ANotes: array of Integer): TWfcSequenceSample;
var
  LTokens: TWfcModelTokens;
  LIndex: Integer;
begin
  SetLength(LTokens, Length(ANotes));
  for LIndex := 0 to High(ANotes) do
  begin
    LTokens[LIndex] := String(PitchNoteToken(ANotes[LIndex]));
  end;
  Result := MakeWfcSequenceSample(LTokens);
end;

function RenderProvider(const AGain: Double; const ASeed: TGraphSeed): TAudioClip;
var
  LSamples: TWfcSequenceSamples;
  LModel: TWfcSequenceModel;
  LDescription: TStyleProviderDescription;
  LContracts: TProviderContracts;
  LLayers: TLearnedLayers;
  LProjections: TLayerProjections;
  LOptions: TLayerGenerationOptions;
  LSession: TCompatibleProviderSession;
  LSequences: TLayerSequences;
  LReport: TGraphNegotiationReport;
  LChoice: TStyleProviderChoice;
  LTones: TFrameTones;
  LIndex: Integer;
begin
  SetLength(LSamples, 2);
  LSamples[0] := AuthoredSample([60, 64, 67, 72, 67, 64, 62, 60]);
  LSamples[1] := AuthoredSample([60, 62, 65, 69, 65, 62, 64, 60]);
  LModel := LearnSequenceModelCorpus(LSamples, 2);
  try
    LDescription := Default(TStyleProviderDescription);
    LDescription.Name := 'caller.melody';
    LDescription.Vocabulary := spvPitch;
    LDescription.TicksPerQuarter := CTicksPerQuarter;
    LDescription.Timing := sptUniform;
    LDescription.StepTicks := CStepTicks;
    LDescription.Scope := MakeLayerScope(CCellCount, wseWhole);
    LDescription.PitchIdentity := spiAbsoluteMidi;
    LDescription.MinimumPitch := 60;
    LDescription.MaximumPitch := 72;
    LDescription.Choices := CopyStyleProviderChoices(LModel, LDescription.Vocabulary);
    SetLength(LDescription.Preferences, 1);
    LDescription.Preferences[0] := MakeLayerTokenPreference(String(PitchNoteToken(69)), 3);

    SetLength(LContracts, 1);
    LContracts[0] := ProviderContractFromDescription(LDescription,
      'caller-authored-480ppq-120bpm');
    { Empty Source is intentional: this model has no measured recording claim. }
    SetLength(LLayers, 1);
    LLayers[0].Model := LModel;
    LLayers[0].Preferences := Copy(LDescription.Preferences);
    LProjections := nil; { This independent caller provider has no required inputs. }
    LOptions := DefaultLayerGenerationOptions;
    LOptions.CellCount := CCellCount;
    LOptions.Extent := wseWhole;
    LOptions.Seed := ASeed;
    LOptions.MaxBacktracks := 64;
    LOptions.MaxPassBacktracks := 16;
    LSession := TCompatibleProviderSession.Create(LLayers, LProjections,
      LContracts, LOptions);
    try
      LSequences := nil;
      if not LSession.TryGenerate(LSequences, LReport) then
      begin
        raise EAudio.Create('Bounded caller provider generation failed; no WAV written');
      end;
      if (Length(LSequences) <> 1) or (Length(LSequences[0].Tokens) <> CCellCount) then
      begin
        raise EAudio.Create('Provider returned an unexpected sequence extent');
      end;
      SetLength(LTones, CCellCount);
      for LIndex := 0 to CCellCount - 1 do
      begin
        LChoice := DecodeStyleProviderChoice(LDescription.Vocabulary,
          LSequences[0].Tokens[LIndex]);
        if LChoice.Dimensions <> [scdPitch] then
        begin
          raise EAudio.Create('Caller pitch provider returned unexpected dimensions');
        end;
        LTones[LIndex].StartFrame := Int64(LIndex) * CFramesPerCell;
        LTones[LIndex].GateFrames := CFramesPerCell * 4 div 5;
        LTones[LIndex].FrequencyHz := MidiFrequency(LChoice.Note);
        LTones[LIndex].Velocity := 0.7;
        LTones[LIndex].Voice := DefaultSynthVoice;
        { RenderFrameTones includes release rather than truncating it. Keep the
          release inside the remaining 400 frames of this one-second grid. }
        LTones[LIndex].Voice.Envelope.ReleaseSeconds := 0.02;
        LTones[LIndex].Voice.Gain := AGain;
        LTones[LIndex].Seed := ASeed xor Cardinal(LIndex + 1);
        WriteLn('cell ', LIndex, ': MIDI ', LChoice.Note);
      end;
      Result := RenderFrameTones(LTones, CSampleRate, CFrameCount);
    finally
      LSession.Free;
    end;
  finally
    LModel.Free;
  end;
end;

procedure Run;
var
  LPath: String;
  LGain: Double;
  LSeed: TGraphSeed;
  LClip: TAudioClip;
  LReloaded: TAudioClip;
begin
  if (ParamCount < 1) or (ParamCount > 3) then
  begin
    raise EAudio.Create('Usage: pythian.example.wfc.provider OUTPUT.wav [GAIN [SEED]]');
  end;
  LGain := 0.25;
  LSeed := 731;
  if ParamCount >= 2 then
  begin
    LGain := ReadGain(ParamStr(2));
  end;
  if ParamCount = 3 then
  begin
    LSeed := ReadSeed(ParamStr(3));
  end;
  LPath := OutputPath(ParamStr(1));
  LClip := RenderProvider(LGain, LSeed);
  try
    if (LClip.SampleRate <> CSampleRate) or (LClip.FrameCount <> CFrameCount) or
      (LClip.Channels <> 2) then
    begin
      raise EAudio.Create('Rendered geometry differs from the declared output');
    end;
    SaveWavePcm16(LPath, LClip);
    LReloaded := LoadWave(LPath);
    try
      if (LReloaded.SampleRate <> CSampleRate) or (LReloaded.FrameCount <> CFrameCount) or
        (LReloaded.Channels <> 2) then
      begin
        raise EAudio.Create('Actual saved WAV reload changed rate/frame/channel geometry');
      end;
      WriteLn('Caller provider saved and reloaded ', LReloaded.FrameCount,
        ' stereo frames at ', LReloaded.SampleRate, ' Hz; seed ', LSeed);
    finally
      LReloaded.Free;
    end;
  finally
    LClip.Free;
  end;
end;

begin
  try
    Run;
  except
    on LException: Exception do
    begin
      WriteLn(StdErr, LException.ClassName, ': ', LException.Message);
      ExitCode := 1;
    end;
  end;
end.
