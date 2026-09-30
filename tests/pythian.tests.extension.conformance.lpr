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
program pythian_tests_extension_conformance;

{$mode delphi}
{$H+}

uses
  SysUtils, Math, pythian.audio, pythian.source, pythian.effects,
  pythian.wave, pythian.hash, pythian.synth, pythian.synth.stream,
  pythian.bus, pythian.schedule, pythian.example.extension.units;

type
  THighCostFactory = class(TCallerHarmonicFactory)
  public
    function FrameCost(const ASampleRate: Integer): Integer; override;
  end;
  TRejectCreateFactory = class(TCallerHarmonicFactory)
  public
    function CreateSource(const ASampleRate: Integer; const ASeed: Cardinal): TAudioSource;
      override;
  end;
  TNonfiniteSource = class(TAudioSource)
  public
    procedure Reset; override;
    function ReadFrame(const AFrequencyHz: Double; out ALeft, ARight: Double): Boolean;
      override;
  end;
  TNonfiniteFactory = class(TCallerHarmonicFactory)
  public
    function CreateSource(const ASampleRate: Integer; const ASeed: Cardinal): TAudioSource;
      override;
  end;
  THighCostDelay = class(TCallerStereoDelay)
  public
    function FrameCost: Integer; override;
  end;
  TNonfiniteEffect = class(TAudioEffect)
  public
    Calls: Integer;
    procedure Reset; override;
    procedure Process(const ALeft, ARight: Double; out AOutputLeft, AOutputRight: Double);
      override;
    function FrameCost: Integer; override;
  end;

var
  GChecks: Integer;
  GOutput: String;

procedure Check(const ACondition: Boolean; const AMessage: String);
begin
  Inc(GChecks);
  if not ACondition then
  begin
    raise Exception.Create(AMessage);
  end;
end;

function THighCostFactory.FrameCost(const ASampleRate: Integer): Integer;
begin
  Result := 50000; { Deliberate conservative over-declaration, not extra work. }
end;

function TRejectCreateFactory.CreateSource(const ASampleRate: Integer;
  const ASeed: Cardinal): TAudioSource;
begin
  Result := nil;
  raise EAudio.Create('Conformance-only source construction failure');
end;

procedure TNonfiniteSource.Reset;
begin
end;

function TNonfiniteSource.ReadFrame(const AFrequencyHz: Double;
  out ALeft, ARight: Double): Boolean;
begin
  ALeft := NaN;
  ARight := 0;
  Result := True;
end;

function TNonfiniteFactory.CreateSource(const ASampleRate: Integer;
  const ASeed: Cardinal): TAudioSource;
begin
  Result := TNonfiniteSource.Create;
end;

function THighCostDelay.FrameCost: Integer;
begin
  Result := 1000000; { Valid effect declaration; render total must still reject. }
end;

procedure TNonfiniteEffect.Reset;
begin
  Calls := 0;
end;

procedure TNonfiniteEffect.Process(const ALeft, ARight: Double;
  out AOutputLeft, AOutputRight: Double);
begin
  Inc(Calls);
  AOutputLeft := NaN;
  AOutputRight := 0;
end;

function TNonfiniteEffect.FrameCost: Integer;
begin
  Result := 1;
end;

function NewGraph: TBusGraph;
var
  LSettings: array[0..0] of TBusSettings;
begin
  LSettings[0] := DefaultBusSettings;
  LSettings[0].SmoothingSeconds := 0;
  Result := TBusGraph.Create(CallerExampleSampleRate, LSettings);
end;

function OneTone(const AFactory: TAudioSourceFactory): TFrameTone;
begin
  Result := MakeCallerTones(AFactory, 731)[0];
  Result.StartFrame := 4;
  Result.GateFrames := 8;
  Result.Voice.Envelope.AttackSeconds := 0;
  Result.Voice.Envelope.DecaySeconds := 0;
  Result.Voice.Envelope.SustainLevel := 1;
  Result.Voice.Envelope.ReleaseSeconds := 2 / CallerExampleSampleRate;
end;

procedure CheckSource;
var
  LProbe: TCallerExtensionProbe;
  LFactory: TCallerHarmonicFactory;
  LFirst: TAudioSource;
  LSecond: TAudioSource;
  LLeft: Double;
  LRight: Double;
  LOtherLeft: Double;
  LOtherRight: Double;
  LFirstValue: Double;
  LIndex: Integer;
  LFailed: Boolean;
begin
  LProbe := TCallerExtensionProbe.Create;
  try
    LFactory := TCallerHarmonicFactory.Create(0.35, LProbe);
    try
      LFirst := LFactory.CreateSource(16000, 731);
      try
        LSecond := LFactory.CreateSource(16000, 731);
        try
          Check(LFirst <> LSecond, 'Factory shared a mutable playback instance');
          LFirstValue := 0;
          for LIndex := 0 to 127 do
          begin
            LFirst.ReadFrame(220, LLeft, LRight);
            LSecond.ReadFrame(220, LOtherLeft, LOtherRight);
            if LIndex = 0 then
            begin
              LFirstValue := LLeft;
            end;
            Check((LLeft = LRight) and (LLeft = LOtherLeft) and (LRight = LOtherRight),
              'Independent mono source seeded replay');
          end;
          LFirst.Reset;
          LFirst.ReadFrame(220, LLeft, LRight);
          Check(LLeft = LFirstValue, 'Source reset did not restore initial seeded phase');
          LFirst.NoteOff;
          LFirst.NoteOff;
          Check(LProbe.SourceNoteOffs = 1, 'Source NoteOff is not idempotent');
          LLeft := 17;
          LRight := 19;
          LFailed := False;
          try
            LFirst.ReadFrame(NaN, LLeft, LRight);
          except
            on LException: EAudio do
      begin
        LFailed := True;
      end;
          end;
          Check(LFailed and (LLeft = 17) and (LRight = 19), 'Invalid source frequency changed output');
          LFirst.Reset;
          LFirst.ReadFrame(220, LLeft, LRight);
          Check(LLeft = LFirstValue, 'Source invalid-argument recovery differs');
        finally
          LSecond.Free;
        end;
      finally
        LFirst.Free;
      end;
      Check(LProbe.SourcesCreated = LProbe.SourcesDestroyed, 'Caller source lifetime leaked');
      Check((LProbe.MaximumSourceFrameWork > 0) and
        (LProbe.MaximumSourceFrameWork <= LFactory.FrameCost(16000)), 'Source declared cost underestimates policy work');
      LFailed := False;
      try
        LFactory.ValidateRange(0, 4000, 16000);
      except
        on LException: EAudio do
      begin
        LFailed := True;
      end;
      end;
      Check(LFailed, 'Second harmonic at Nyquist admitted');
    finally
      LFactory.Free;
    end;
    LFactory := nil;
    LFailed := False;
    try
      LFactory := TCallerHarmonicFactory.Create(-0.1);
    except
      on LException: EAudio do
      begin
        LFailed := True;
      end;
    end;
    LFactory.Free;
    Check(LFailed, 'Invalid source mix admitted');
  finally
    LProbe.Free;
  end;
end;

procedure CheckTailAndReset;
var
  LProbe: TCallerExtensionProbe;
  LChain: TEffectChain;
  LOtherChain: TEffectChain;
  LDelay: TCallerStereoDelay;
  LSamples: TAudioSamples;
  LInput: TAudioClip;
  LOutput: TAudioClip;
  LLeft: Double;
  LRight: Double;
  LFailed: Boolean;
  LIndex: Integer;
begin
  LProbe := TCallerExtensionProbe.Create;
  try
    LChain := TEffectChain.Create(16000);
    try
      LDelay := TCallerStereoDelay.Create(16000, 3, 0.5, LProbe);
      LChain.Add(LDelay); { Ownership transferred; retain borrowed pointer for checks. }
      LOtherChain := TEffectChain.Create(16000);
      try
        LFailed := False;
        try
          LOtherChain.Add(LDelay);
        except
          on LException: EAudio do
      begin
        LFailed := True;
      end;
        end;
        Check(LFailed, 'Effect instance attached to two owners');
      finally
        LOtherChain.Free;
      end;
      SetLength(LSamples, 16);
      LSamples[14] := 1; { Last input frame left impulse, right zero. }
      LInput := TAudioClip.Create(16000, 2, LSamples);
      try
        LOutput := RenderEffectClip(LInput, LChain, 3);
        try
          Check(LOutput.FrameCount = 11, 'Finite delay tail extent changed');
          Check((LOutput.SampleAt(7, 0) = 1) and (LOutput.SampleAt(10, 1) = 0.5),
            'Last-frame impulse or complete delayed tail was lost');
          for LIndex := 0 to 10 do
          begin
            if LIndex <> 7 then
            begin
              Check(LOutput.SampleAt(LIndex, 0) = 0, 'Unexpected left delay sample');
            end;
            if LIndex <> 10 then
            begin
              Check(LOutput.SampleAt(LIndex, 1) = 0, 'Unexpected right delay sample');
            end;
          end;
        finally
          LOutput.Free;
        end;
      finally
        LInput.Free;
      end;
      LChain.Process(0, 0, LLeft, LRight);
      Check((LLeft = 0) and (LRight = 0), 'Finite tail not fully drained');
      LChain.Process(1, 0, LLeft, LRight);
      LChain.Reset;
      for LIndex := 0 to 3 do
      begin
        LChain.Process(0, 0, LLeft, LRight);
        Check((LLeft = 0) and (LRight = 0), 'Actual chain Reset retained delay history');
      end;
      Check((LProbe.MaximumEffectFrameWork > 0) and
        (LProbe.MaximumEffectFrameWork <= LDelay.FrameCost), 'Effect declared cost underestimates policy work');
    finally
      LChain.Free;
    end;
    LDelay := nil;
    LFailed := False;
    try
      LDelay := TCallerStereoDelay.Create(16000, 0, 0.5);
    except
      on LException: EAudio do
      begin
        LFailed := True;
      end;
    end;
    LDelay.Free;
    Check(LFailed, 'Zero delay admitted');
  finally
    LProbe.Free;
  end;
end;

procedure CheckRenderedReplay;
const
  CBlockSizes: array[0..3] of Integer = (1, 7, 257, 2048);
var
  LProbe: TCallerExtensionProbe;
  LFactory: TCallerHarmonicFactory;
  LChangedFactory: TCallerHarmonicFactory;
  LScheduled: TAudioClip;
  LStreamed: TAudioClip;
  LChanged: TAudioClip;
  LBytes: TAudioBytes;
  LFrame: Integer;
  LChannel: Integer;
  LBlock: Integer;
  LTones: TFrameTones;
  LExpectedSourceFrames: Int64;
  LIndex: Integer;
  LCreatedBefore: Integer;
begin
  LProbe := TCallerExtensionProbe.Create;
  try
    LFactory := TCallerHarmonicFactory.Create(0.35, LProbe);
    try
      LScheduled := RenderCallerScheduled(LFactory, 731, 0.3, LProbe);
      try
        Check((LScheduled.FrameCount = 16240) and (LScheduled.SampleRate = 16000) and
          (LScheduled.Channels = 2), 'Scheduled example geometry');
        LTones := MakeCallerTones(LFactory, 731);
        LExpectedSourceFrames := 0;
        for LIndex := 0 to High(LTones) do
        begin
          Inc(LExpectedSourceFrames, ValidateFrameTone(LTones[LIndex], 16000));
        end;
        Check(LProbe.SourceFrames = LExpectedSourceFrames, 'Complete voice gate/release frame count differs');
        Check((LProbe.SourceNoteOffs = 3) and (LProbe.SourcesDestroyed = 3),
          'Scheduled voices were not notified/released/destroyed');
        for LFrame := 0 to 511 do
        begin
          Check((LScheduled.SampleAt(LFrame, 0) = 0) and
            (LScheduled.SampleAt(LFrame, 1) = 0), 'Scheduled event started before its exact frame');
        end;
        LBytes := nil;
        for LBlock in CBlockSizes do
        begin
          LCreatedBefore := LProbe.SourcesCreated;
          LStreamed := RenderCallerStreamed(LFactory, 731, 0.3, LBlock, LProbe);
          try
            Check(LProbe.SourcesCreated = LCreatedBefore + 3, 'Stream did not own independent playback instances');
            if Length(LBytes) = 0 then
            begin
              LBytes := EncodeWavePcm16(LStreamed);
              SaveWavePcm16(GOutput + '/streamed.wav', LStreamed);
            end
            else
            begin
              Check(Sha256Bytes(EncodeWavePcm16(LStreamed)) = Sha256Bytes(LBytes),
                'Changed read cap changed fixed-seed streamed PCM');
            end;
            for LFrame := 0 to LScheduled.FrameCount - 1 do
            begin
              for LChannel := 0 to 1 do
              begin
                Check(Abs(LScheduled.SampleAt(LFrame, LChannel) -
                  LStreamed.SampleAt(LFrame, LChannel)) <= 2 / 32768,
                  'Scheduled/streamed paths differ beyond documented PCM tolerance');
              end;
            end;
          finally
            LStreamed.Free;
          end;
        end;
        SaveWavePcm16(GOutput + '/scheduled.wav', LScheduled);
        LChangedFactory := TCallerHarmonicFactory.Create(0.8);
        try
          LChanged := RenderCallerStreamed(LChangedFactory, 731, 0.3, 257);
          try
            Check(Sha256Bytes(EncodeWavePcm16(LChanged)) <> Sha256Bytes(LBytes), 'Caller sound parameter had no effect');
            SaveWavePcm16(GOutput + '/changed-source.wav', LChanged);
          finally
            LChanged.Free;
          end;
        finally
          LChangedFactory.Free;
        end;
        LChanged := RenderCallerStreamed(LFactory, 731, 0.8, 257);
        try
          Check(Sha256Bytes(EncodeWavePcm16(LChanged)) <> Sha256Bytes(LBytes), 'Stateful caller effect control had no effect');
          SaveWavePcm16(GOutput + '/changed-effect.wav', LChanged);
        finally
          LChanged.Free;
        end;
        Check(LProbe.SourcesCreated = LProbe.SourcesDestroyed, 'Rendered sources not completely freed');
      finally
        LScheduled.Free;
      end;
    finally
      LFactory.Free;
    end;
  finally
    LProbe.Free;
  end;
end;

procedure CheckAdmissionAndFaults;
var
  LProbe: TCallerExtensionProbe;
  LGood: TCallerHarmonicFactory;
  LHigh: THighCostFactory;
  LReject: TRejectCreateFactory;
  LBad: TNonfiniteFactory;
  LGraph: TBusGraph;
  LSynth: TScheduledSynth;
  LStream: TFrameToneStream;
  LChain: TEffectChain;
  LDelay: THighCostDelay;
  LBadEffect: TNonfiniteEffect;
  LTones: TFrameTones;
  LId: Int64;
  LReplacementId: Int64;
  LReserved: Integer;
  LFailed: Boolean;
  LLeft: Double;
  LRight: Double;
  LSamples: TAudioSamples;
  LInput: TAudioClip;
  LOutput: TAudioClip;
  LCreatedBefore: Integer;
begin
  LProbe := TCallerExtensionProbe.Create;
  try
    LGood := TCallerHarmonicFactory.Create(0.35, LProbe);
    LHigh := THighCostFactory.Create(0.35, LProbe);
    LReject := TRejectCreateFactory.Create(0.35);
    LBad := TNonfiniteFactory.Create(0.35);
    try
      LGraph := NewGraph;
      try
        LSynth := TScheduledSynth.Create(LGraph, 3, 1024);
        try
          LId := 17;
          Check(LSynth.TrySchedule(OneTone(LHigh), 0, 1, LId) = srWorkLimit,
            'High declared source work admitted');
          Check((LProbe.SourcesCreated = 0) and (LSynth.ScheduledCount = 0) and (LId = 17),
            'Over-budget source executed or mutated admission');
          Check(LSynth.TrySchedule(OneTone(LGood), 0, 1, LId) = srScheduled, 'Good source admission');
          LReserved := LSynth.ReservedWork;
          LTones := nil;
          SetLength(LTones, 1);
          LTones[0] := OneTone(LReject);
          LReplacementId := 19;
          LFailed := False;
          try
            LSynth.TryReplaceFuture(1, 0, 0, LTones, LReplacementId);
          except
            on LException: EAudio do
      begin
        LFailed := True;
      end;
          end;
          Check(LFailed and not LSynth.Failed and (LSynth.ScheduledCount = 1) and
            (LSynth.ReservedWork = LReserved) and (LSynth.NextFrame = 0) and
            (LReplacementId = 19), 'Failed source construction changed accepted scheduler');
          LTones[0] := OneTone(LGood);
          Check(LSynth.TryReplaceFuture(1, 0, 0, LTones, LReplacementId) = srScheduled,
            'Safe admission retry failed');
          LSynth.Reset;
          Check((LSynth.ScheduledCount = 0) and (LSynth.NextFrame = 0) and
            not LSynth.Failed, 'Scheduler Reset retained voices/state');
          Check(LSynth.TrySchedule(OneTone(LBad), 0, 1, LId) = srScheduled, 'Bad source fixture admission');
          LSynth.Process(LLeft, LRight);
          LSynth.Process(LLeft, LRight);
          LSynth.Process(LLeft, LRight);
          LSynth.Process(LLeft, LRight);
          LLeft := 17;
          LRight := 19;
          LFailed := False;
          try
            LSynth.Process(LLeft, LRight);
          except
            on LException: EAudio do
      begin
        LFailed := True;
      end;
          end;
          Check(LFailed and LSynth.Failed and (LSynth.NextFrame = 4) and
            (LLeft = 17) and (LRight = 19), 'Nonfinite source contaminated published scheduler output');
          LFailed := False;
          try
            LSynth.Process(LLeft, LRight);
          except
            on LException: EAudio do
      begin
        LFailed := True;
      end;
          end;
          Check(LFailed, 'Poisoned scheduler reused without Reset');
          LSynth.Reset;
          Check(LSynth.TrySchedule(OneTone(LGood), 0, 1, LId) = srScheduled, 'Reset scheduler recovery admission');
          LOutput := RenderScheduledFrames(LSynth, 20);
          LOutput.Free;
          Check(not LSynth.Failed and (LSynth.ScheduledCount = 0), 'Reset scheduler recovery did not complete');
        finally
          LSynth.Free;
        end;
      finally
        LGraph.Free;
      end;
      SetLength(LTones, 1);
      LTones[0] := OneTone(LHigh);
      LCreatedBefore := LProbe.SourcesCreated;
      LStream := nil;
      LFailed := False;
      try
        LStream := TFrameToneStream.Create(LTones, 16000, 20, 3, 1024);
      except
        on LException: EAudio do
      begin
        LFailed := True;
      end;
      end;
      LStream.Free;
      Check(LFailed and (LProbe.SourcesCreated = LCreatedBefore), 'Stream executed over-budget source');
      LTones[0] := OneTone(LGood);
      LStream := TFrameToneStream.Create(LTones, 16000, 20, 3, 1024);
      try
        LFailed := False;
        LSamples := nil;
        try
          LStream.ReadSamples(0, LSamples);
        except
          on LException: EAudio do
      begin
        LFailed := True;
      end;
        end;
        Check(LFailed and not LStream.Failed and (LStream.EmittedFrames = 0), 'Invalid read advanced/poisoned stream');
        Check(LStream.ReadSamples(7, LSamples) and (LStream.EmittedFrames = 7), 'Invalid read retry failed');
      finally
        LStream.Free;
      end;
      LTones[0] := OneTone(LBad);
      LStream := TFrameToneStream.Create(LTones, 16000, 20, 3, 1024);
      try
        LFailed := False;
        try
          LStream.ReadSamples(7, LSamples);
        except
          on LException: EAudio do
      begin
        LFailed := True;
      end;
        end;
        Check(LFailed and LStream.Failed and (LStream.EmittedFrames = 0) and
          (Length(LSamples) = 0), 'Failed source stream published partial samples');
      finally
        LStream.Free;
      end;
      LTones[0] := OneTone(LGood);
      LStream := TFrameToneStream.Create(LTones, 16000, 20, 3, 1024);
      try
        Check(LStream.ReadSamples(7, LSamples), 'Fresh stream recreation failed');
      finally
        LStream.Free;
      end;
      LChain := TEffectChain.Create(16000);
      try
        LDelay := THighCostDelay.Create(16000, 3, 0.5, LProbe);
        LChain.Add(LDelay);
        SetLength(LSamples, 402);
        LInput := TAudioClip.Create(16000, 2, LSamples);
        try
          LFailed := False;
          LOutput := nil;
          LCreatedBefore := LProbe.EffectFrames;
          try
            LOutput := RenderEffectClip(LInput, LChain);
          except
            on LException: EAudio do
      begin
        LFailed := True;
      end;
          end;
          LOutput.Free;
          Check(LFailed and not LChain.Failed and (LProbe.EffectFrames = LCreatedBefore),
            'Over-budget effect processed frames or poisoned a healthy chain');
        finally
          LInput.Free;
        end;
      finally
        LChain.Free;
      end;
      LChain := TEffectChain.Create(16000);
      try
        LChain.Add(TCallerStereoDelay.Create(16000, 3, 0.5));
        LLeft := 17;
        LRight := 19;
        LFailed := False;
        try
          LChain.Process(NaN, 0, LLeft, LRight);
        except
          on LException: EAudio do
      begin
        LFailed := True;
      end;
        end;
        Check(LFailed and not LChain.Failed and (LLeft = 17) and (LRight = 19),
          'Nonfinite input changed healthy chain state/output');
        LBadEffect := TNonfiniteEffect.Create(16000);
        LChain.Add(LBadEffect);
        LFailed := False;
        try
          LChain.Process(1, 0, LLeft, LRight);
        except
          on LException: EAudio do
      begin
        LFailed := True;
      end;
        end;
        Check(LFailed and LChain.Failed and (LLeft = 17) and (LRight = 19) and
          (LBadEffect.Calls = 1), 'Nonfinite effect silently published output');
        LFailed := False;
        try
          LChain.Process(0, 0, LLeft, LRight);
        except
          on LException: EAudio do
      begin
        LFailed := True;
      end;
        end;
        Check(LFailed and (LBadEffect.Calls = 1), 'Poisoned effect chain reused');
        LChain.Reset;
        Check(not LChain.Failed and (LBadEffect.Calls = 0), 'Actual chain Reset did not clear failure');
        { Reset clears history, not a defective implementation: discard this chain. }
      finally
        LChain.Free;
      end;
      Check(LProbe.SourcesCreated = LProbe.SourcesDestroyed, 'Fault/admission source instances leaked');
    finally
      LBad.Free;
      LReject.Free;
      LHigh.Free;
      LGood.Free;
    end;
  finally
    LProbe.Free;
  end;
end;

procedure CheckPublishedFile(const APath: String);
var
  LFactory: TCallerHarmonicFactory;
  LRendered: TAudioClip;
  LExpected: TAudioClip;
  LActual: TAudioClip;
  LFrame: Integer;
  LChannel: Integer;
begin
  LFactory := TCallerHarmonicFactory.Create(0.35);
  try
    LRendered := RenderCallerStreamed(LFactory, 731, 0.3, 257);
    try
      LExpected := DecodeWave(EncodeWavePcm16(LRendered));
      try
        LActual := LoadWave(APath);
        try
          Check((LActual.SampleRate = 16000) and (LActual.Channels = 2) and
            (LActual.FrameCount = 16240), 'Published CLI file geometry');
          for LFrame := 0 to LActual.FrameCount - 1 do
          begin
            for LChannel := 0 to 1 do
            begin
              Check(LActual.SampleAt(LFrame, LChannel) =
                LExpected.SampleAt(LFrame, LChannel), 'Published CLI sample differs from expectation');
            end;
          end;
        finally
          LActual.Free;
        end;
      finally
        LExpected.Free;
      end;
    finally
      LRendered.Free;
    end;
  finally
    LFactory.Free;
  end;
end;

begin
  try
    if (ParamCount < 1) or (ParamCount > 2) then
    begin
      raise Exception.Create('Expected ignored artifact directory [default CLI WAV] [default CLI WAV]');
    end;
    GOutput := ExpandFileName(ParamStr(1));
    ForceDirectories(GOutput);
    CheckSource;
    CheckTailAndReset;
    CheckRenderedReplay;
    CheckAdmissionAndFaults;
    if ParamCount = 2 then
    begin
      CheckPublishedFile(ParamStr(2));
    end;
    WriteLn('Caller source/effect conformance passed: ', GChecks, ' checks');
    WriteLn('Mechanical generated evidence only; outside use and listening remain open.');
  except
    on LException: Exception do
    begin
      WriteLn(StdErr, LException.Message);
      ExitCode := 1;
    end;
  end;
end.
