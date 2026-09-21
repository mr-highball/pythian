(*
MIT License

Copyright (c) 2021 mr-highball
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
program pythian_tests_chord_stream;

{$mode delphi}
{$H+}

uses
  SysUtils,
  pythian.audio,
  pythian.oscillator,
  pythian.chord.stream
  {$IFDEF WFC_CHORD_CHECKS}
  , pythian.time,
  pythian.wfc.music,
  wfc_music,
  wfc_music_sequence,
  wfc_music_ensemble,
  wfc_music_audio,
  wfc_music_ensemble_audio,
  wfc_model,
  wfc_sequence,
  wfc_sequence_learn
  {$ENDIF}
  ;

procedure Check(const ACondition: Boolean; const AMessage: String);
begin
  if not ACondition then
  begin
    raise Exception.Create(AMessage);
  end;
end;

function Scene(const AIndex: Integer): TChordFrame;
begin
  Result := nil;
  SetLength(Result, 2);
  if AIndex < 5 then
  begin
    Result[0].Action := caHold;
    if (AIndex = 0) or (AIndex = 3) then
    begin
      Result[0].Action := caAttack;
    end;
    if AIndex < 3 then
    begin
      SetLength(Result[0].Tones, 2);
      Result[0].Tones[0].Pitch := 69;
      Result[0].Tones[0].Velocity := 127;
      Result[0].Tones[1].Pitch := 76;
      Result[0].Tones[1].Velocity := 90;
    end
    else
    begin
      SetLength(Result[0].Tones, 1);
      Result[0].Tones[0].Pitch := 67;
      Result[0].Tones[0].Velocity := 99;
    end;
  end;
  if (AIndex in [1, 2, 3, 5, 6]) then
  begin
    Result[1].Action := caHold;
    if AIndex in [1, 5] then
    begin
      Result[1].Action := caAttack;
    end;
    SetLength(Result[1].Tones, 1);
    if AIndex < 5 then
    begin
      Result[1].Tones[0].Pitch := 48;
      Result[1].Tones[0].Velocity := 80;
    end
    else
    begin
      Result[1].Tones[0].Pitch := 55;
      Result[1].Tones[0].Velocity := 100;
    end;
  end;
end;

procedure Append(var AOutput: TAudioSamples; const ABlock: TAudioSamples);
var
  LOffset: Integer;
  LIndex: Integer;
begin
  LOffset := Length(AOutput);
  SetLength(AOutput, LOffset + Length(ABlock));
  for LIndex := 0 to High(ABlock) do
  begin
    AOutput[LOffset + LIndex] := ABlock[LIndex];
  end;
end;

procedure Drain(const ARenderer: TChordStreamRenderer; const ABlockSize: Integer;
  var AOutput: TAudioSamples);
var
  LBlock: TAudioSamples;
begin
  while ARenderer.ReadSamples(ABlockSize, LBlock) do
  begin
    Check(Length(LBlock) <= ChordStreamBlockFrames, 'Bounded output blocks');
    Append(AOutput, LBlock);
    LBlock[0] := 1;
  end;
  Check(Length(LBlock) = 0, 'False read clears output');
end;

function GateSample(const AFrame, AStart, AEnd, APitch, AVelocity,
  ARelease: Integer): Integer;
var
  LGain: Integer;
  LSample: Int64;
begin
  Result := 0;
  if (AFrame < AStart) or (AFrame >= AEnd) then
  begin
    Exit;
  end;
  { Finite-gate oracle uses known ends; it has no ring or retrospective updates. }
  LGain := FixedEnvelopeGain(AFrame - AStart, AEnd - AStart, 4, ARelease);
  LSample := Int64(FixedTriangleSample(Integer(
    (Int64(AFrame - AStart) * FixedPhaseIncrement(APitch, 8000)) mod PhaseModulus))) *
    AVelocity;
  LSample := (LSample div 127) * 96;
  LSample := (LSample div 127) * LGain;
  Result := (LSample div EnvelopeScale) div 3;
end;

procedure CheckNative(const ARelease, ABlockSize: Integer);
const
  CLengths: array[0..6] of Integer = (2, 0, 3, 1, 5, 4, 2);
var
  LOptions: TChordStreamOptions;
  LCapacities: TChordCapacities;
  LRenderer: TChordStreamRenderer;
  LFrame: TChordFrame;
  LOutput: TAudioSamples;
  LIndex: Integer;
  LExpected: Integer;
  LRejected: Boolean;
begin
  LOptions := DefaultChordStreamOptions(8000);
  LOptions.AttackFrames := 4;
  LOptions.ReleaseFrames := ARelease;
  SetLength(LCapacities, 2);
  LCapacities[0] := 2;
  LCapacities[1] := 1;
  LRenderer := TChordStreamRenderer.Create(LOptions, LCapacities);
  try
    LCapacities[0] := 0;
    for LIndex := 0 to High(CLengths) do
    begin
      LFrame := Scene(LIndex);
      LRenderer.AdmitFrame(LFrame, CLengths[LIndex]);
      if LIndex = 0 then
      begin
        LFrame[0].Tones[0].Pitch := 100;
        LRejected := False;
        try
          LRenderer.EndInput;
        except
          on EAudio do
          begin
            LRejected := True;
          end;
        end;
        Check(LRejected and not LRenderer.InputEnded, 'Undrained end preserves input');
      end;
      Drain(LRenderer, ABlockSize, LOutput);
      Check(LRenderer.NeedsInput, 'Drained interval permits input');
      if LIndex = 0 then
      begin
        LFrame := Scene(2);
        LFrame[0].Tones[0].Velocity := 1;
        LRejected := False;
        try
          LRenderer.AdmitFrame(LFrame, 1);
        except
          on EAudio do
          begin
            LRejected := True;
          end;
        end;
        Check(LRejected and (LRenderer.FrameCount = 2) and not LRenderer.Failed,
          'Changed hold preserves admitted extent and delayed audio');
        LRejected := False;
        try
          LRenderer.AdmitFrame(Scene(0), High(Int64));
        except
          on EAudio do
          begin
            LRejected := True;
          end;
        end;
        Check(LRejected and (LRenderer.FrameCount = 2), 'Cumulative frame overflow rejects');
      end;
    end;
    LRenderer.EndInput;
    Drain(LRenderer, ABlockSize, LOutput);
    Check(LRenderer.Finished and (LRenderer.FrameCount = 17) and
      (LRenderer.EmittedFrames = 17) and (Length(LOutput) = 17), 'Exact duration without tail');
    for LIndex := 0 to High(LOutput) do
    begin
      LExpected := GateSample(LIndex, 0, 5, 69, 127, ARelease) +
        GateSample(LIndex, 0, 5, 76, 90, ARelease) +
        GateSample(LIndex, 5, 11, 67, 99, ARelease) +
        GateSample(LIndex, 2, 6, 48, 80, ARelease) +
        GateSample(LIndex, 11, 17, 55, 100, ARelease);
      Check(LOutput[LIndex] = LExpected / 32768,
        'Independent finite-gate sample at ' + IntToStr(LIndex));
    end;
  finally
    LRenderer.Free;
  end;
end;

procedure CheckCancel;
var
  LOptions: TChordStreamOptions;
  LCapacities: TChordCapacities;
  LRenderer: TChordStreamRenderer;
  LOutput: TAudioSamples;
begin
  LOptions := DefaultChordStreamOptions(8000);
  SetLength(LCapacities, 2);
  LCapacities[0] := 2;
  LCapacities[1] := 1;
  LRenderer := TChordStreamRenderer.Create(LOptions, LCapacities);
  try
    LRenderer.AdmitFrame(Scene(0), 2);
    Drain(LRenderer, 1, LOutput);
    Check(Length(LOutput) = 0, 'Release window retains pending samples');
    LRenderer.Cancel;
    LRenderer.Cancel;
    Check(not LRenderer.ReadSamples(1, LOutput) and LRenderer.Cancelled and
      not LRenderer.NeedsInput and (LRenderer.EmittedFrames = 0), 'Cancel discards pending audio');
  finally
    LRenderer.Free;
  end;
end;

{$IFDEF WFC_CHORD_CHECKS}
procedure CheckModelCapacities;
var
  LFrame: TWfcMusicEnsembleFrame;
  LTokens: TWfcModelTokens;
  LModel: TWfcSequenceModel;
  LBadModel: TWfcSequenceModel;
  LCapacities: TChordCapacities;
  LRejected: Boolean;
begin
  SetLength(LTokens, 2);
  SetLength(LFrame.Voices, 2);
  LFrame.Voices[0].Action := wmcaAttack;
  SetLength(LFrame.Voices[0].Tones, 1);
  LFrame.Voices[0].Tones[0] := MakeWfcMusicTone(60, 100);
  LTokens[0] := EncodeWfcMusicEnsembleFrame(LFrame);
  SetLength(LFrame.Voices[0].Tones, 3);
  LFrame.Voices[0].Tones[1] := MakeWfcMusicTone(64, 90);
  LFrame.Voices[0].Tones[2] := MakeWfcMusicTone(67, 80);
  LTokens[1] := EncodeWfcMusicEnsembleFrame(LFrame);
  LModel := LearnSequenceModel(LTokens, 2);
  LBadModel := nil;
  try
    LCapacities := WfcEnsembleCapacities(LModel);
    Check((Length(LCapacities) = 2) and (LCapacities[0] = 3) and
      (LCapacities[1] = 0), 'Full vocabulary capacity scan retains silent slots');
    LCapacities[0] := 17;
    LFrame.Voices[0].Tones[2].Pitch := 128;
    LTokens[1] := EncodeWfcMusicEnsembleFrame(LFrame);
    LBadModel := LearnSequenceModel(LTokens, 2);
    LRejected := False;
    try
      LCapacities := WfcEnsembleCapacities(LBadModel);
    except
      on EAudio do
      begin
        LRejected := True;
      end;
    end;
    Check(LRejected and (LCapacities[0] = 17), 'Unsupported vocabulary tone preserves prior capacities');
    LCapacities := WfcEnsembleCapacities(LModel);
    Check(LCapacities[0] = 3, 'Capacity mutation cannot change the learned model');
  finally
    LBadModel.Free;
    LModel.Free;
  end;
  Check(LCapacities[0] = 3, 'Capacities survive model destruction');
end;

procedure CheckCompanion(const ASampleRate, AReleaseMs: Integer);
const
  CTicks: array[0..6] of Integer = (1, 1, 7, 11, 480, 240, 10);
  CTempos: array[0..6] of Integer = (1, 1, 500001, 330001, 500001, 750003, 500001);
var
  LNative: TChordStreamRenderer;
  LClock: TIncrementalTempoClock;
  LCompanion: TWfcMusicEnsembleAudioRenderer;
  LOptions: TWfcMusicAudioOptions;
  LNativeOptions: TChordStreamOptions;
  LCapacities: TChordCapacities;
  LWfcCapacities: TWfcMusicEnsembleAudioVoiceCapacities;
  LFrame: TChordFrame;
  LWfcFrame: TWfcMusicEnsembleFrame;
  LNativeOutput: TAudioSamples;
  LWfcOutput: TAudioSamples;
  LBlock: TWfcMusicPcm16Samples;
  LFloatBlock: TAudioSamples;
  LIndex: Integer;
  LVoice: Integer;
  LTone: Integer;
  LBefore: TTempoClockSnapshot;
  LRejected: Boolean;
begin
  LOptions := DefaultWfcMusicAudioOptions;
  LOptions.SampleRate := ASampleRate;
  LOptions.ReleaseMilliseconds := AReleaseMs;
  LNativeOptions := DefaultChordStreamOptions(ASampleRate);
  LNativeOptions.ReleaseFrames := ASampleRate * AReleaseMs div 1000;
  SetLength(LCapacities, 2);
  LCapacities[0] := 2;
  LCapacities[1] := 1;
  SetLength(LWfcCapacities, 2);
  LWfcCapacities[0] := 2;
  LWfcCapacities[1] := 1;
  LNative := nil;
  LClock := nil;
  LCompanion := nil;
  try
    LNative := TChordStreamRenderer.Create(LNativeOptions, LCapacities);
    LClock := TIncrementalTempoClock.Create(960, ASampleRate);
    LCompanion := TWfcMusicEnsembleAudioRenderer.Create(LOptions, 960, LWfcCapacities);
    for LIndex := 0 to High(CTicks) do
    begin
      LFrame := Scene(LIndex);
      SetLength(LWfcFrame.Voices, Length(LFrame));
      for LVoice := 0 to High(LFrame) do
      begin
        case LFrame[LVoice].Action of
          caRest:
          begin
            LWfcFrame.Voices[LVoice].Action := wmcaRest;
          end;
          caAttack:
          begin
            LWfcFrame.Voices[LVoice].Action := wmcaAttack;
          end;
          caHold:
          begin
            LWfcFrame.Voices[LVoice].Action := wmcaHold;
          end;
        end;
        SetLength(LWfcFrame.Voices[LVoice].Tones, Length(LFrame[LVoice].Tones));
        for LTone := 0 to High(LFrame[LVoice].Tones) do
        begin
          LWfcFrame.Voices[LVoice].Tones[LTone] := MakeWfcMusicTone(
            LFrame[LVoice].Tones[LTone].Pitch, LFrame[LVoice].Tones[LTone].Velocity);
        end;
      end;
      if LIndex = 2 then
      begin
        LBefore := LClock.Snapshot;
        LWfcFrame.Voices[0].Tones[0].Velocity := 1;
        LRejected := False;
        try
          AdmitWfcEnsembleFrame(LNative, LClock, LWfcFrame, CTicks[LIndex], CTempos[LIndex]);
        except
          on EAudio do
          begin
            LRejected := True;
          end;
        end;
        Check(LRejected and (LClock.Snapshot.TickCount = LBefore.TickCount) and
          (LClock.Snapshot.FrameCount = LBefore.FrameCount) and
          (LClock.Snapshot.FractionNumerator = LBefore.FractionNumerator) and
          not LNative.Failed, 'WFC rejection rolls back the complete clock');
        LWfcFrame.Voices[0].Tones[0].Velocity := 127;
      end;
      AdmitWfcEnsembleFrame(LNative, LClock, LWfcFrame, CTicks[LIndex], CTempos[LIndex]);
      LCompanion.AdmitFrame(LWfcFrame, CTicks[LIndex], CTempos[LIndex]);
      if LIndex = 0 then
      begin
        LWfcFrame.Voices[0].Tones[0].Pitch := 100;
      end;
      Drain(LNative, 1939, LNativeOutput);
      while LCompanion.ReadSamples(127, LBlock) do
      begin
        SetLength(LFloatBlock, Length(LBlock));
        for LTone := 0 to High(LBlock) do
        begin
          LFloatBlock[LTone] := LBlock[LTone] / 32768;
        end;
        Append(LWfcOutput, LFloatBlock);
      end;
      Check((LNative.FrameCount = LCompanion.FrameCount) and
        (LClock.Snapshot.TickCount = LCompanion.InputTicks), 'Companion interval clock parity');
    end;
    LNative.EndInput;
    LCompanion.EndInput;
    Drain(LNative, 7, LNativeOutput);
    while LCompanion.ReadSamples(2048, LBlock) do
    begin
      SetLength(LFloatBlock, Length(LBlock));
      for LTone := 0 to High(LBlock) do
      begin
        LFloatBlock[LTone] := LBlock[LTone] / 32768;
      end;
      Append(LWfcOutput, LFloatBlock);
    end;
    Check(LNative.Finished and LCompanion.Finished and
      (Length(LNativeOutput) = Length(LWfcOutput)), 'Companion final extent');
    for LIndex := 0 to High(LNativeOutput) do
    begin
      Check(LNativeOutput[LIndex] = LWfcOutput[LIndex],
        'Actual WFC PCM parity at ' + IntToStr(LIndex));
    end;
    WriteLn('Actual WFC PCM parity: ', ASampleRate, ' Hz, ', AReleaseMs,
      ' ms release, ', Length(LNativeOutput), ' frames');
  finally
    LCompanion.Free;
    LClock.Free;
    LNative.Free;
  end;
end;
{$ENDIF}

begin
  try
    CheckNative(6, 1);
    CheckNative(6, 11);
    CheckNative(0, 11);
    CheckCancel;
    WriteLn('Native chord stream: finite-gate oracle, holds, ownership, rejection and cancel pass');
    {$IFDEF WFC_CHORD_CHECKS}
    CheckModelCapacities;
    CheckCompanion(44100, 20);
    CheckCompanion(48000, 0);
    CheckCompanion(32000, 1000);
    {$ENDIF}
  except
    on LException: Exception do
    begin
      WriteLn(StdErr, LException.ClassName, ': ', LException.Message);
      Halt(1);
    end;
  end;
end.
