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
program pythian_tests_schedule;

{$mode delphi}
{$H+}

uses
  SysUtils,
  Math,
  pythian.audio,
  pythian.time,
  pythian.source,
  pythian.automation,
  pythian.synth,
  pythian.bus,
  pythian.echo,
  pythian.schedule,
  pythian.synth.stream,
  pythian.synth.resample,
  pythian.resample,
  pythian.resample.stream,
  pythian.music,
  pythian.music.render;

type
  TProbeFactory = class;
  TProbeSource = class(TAudioSource)
  private
    FFactory: TProbeFactory;
    FRead: Integer;
  public
    constructor Create(const AFactory: TProbeFactory);
    destructor Destroy; override;
    procedure Reset; override;
    procedure NoteOff; override;
    function ReadFrame(const AFrequencyHz: Double; out ALeft, ARight: Double): Boolean; override;
  end;
  TProbeFactory = class(TAudioSourceFactory)
  public
    Created: Integer;
    Destroyed: Integer;
    OffCount: Integer;
    OffFrame: Integer;
    FailCreate: Boolean;
    FailRead: Boolean;
    Reenter: TScheduledSynth;
    function CreateSource(const ASampleRate: Integer; const ASeed: Cardinal): TAudioSource; override;
    function FrameCost(const ASampleRate: Integer): Integer; override;
    function Channels: Integer; override;
  end;

constructor TProbeSource.Create(const AFactory: TProbeFactory);
begin
  inherited Create;
  FFactory := AFactory;
  Inc(FFactory.Created);
end;

destructor TProbeSource.Destroy;
begin
  Inc(FFactory.Destroyed);
  inherited;
end;

procedure TProbeSource.Reset;
begin
  FRead := 0;
end;

procedure TProbeSource.NoteOff;
begin
  Inc(FFactory.OffCount);
  FFactory.OffFrame := FRead;
end;

function TProbeSource.ReadFrame(const AFrequencyHz: Double;
  out ALeft, ARight: Double): Boolean;
begin
  if FFactory.FailRead then
  begin
    raise EAudio.Create('Deliberate source failure');
  end;
  if FFactory.Reenter <> nil then
  begin
    FFactory.Reenter.CancelFuture(0, FFactory.Reenter.NextFrame);
  end;
  Inc(FRead);
  ALeft := 1;
  ARight := -0.5;
  Result := True;
end;

function TProbeFactory.CreateSource(const ASampleRate: Integer;
  const ASeed: Cardinal): TAudioSource;
begin
  Result := nil;
  if not FailCreate then
  begin
    Result := TProbeSource.Create(Self);
  end;
end;

function TProbeFactory.FrameCost(const ASampleRate: Integer): Integer;
begin
  Result := 1;
end;

function TProbeFactory.Channels: Integer;
begin
  Result := 2;
end;

procedure Check(const ACondition: Boolean; const AMessage: String);
begin
  if not ACondition then
  begin
    raise Exception.Create(AMessage);
  end;
end;

procedure Near(const AActual, AExpected, ATolerance: Double; const AMessage: String);
begin
  Check(not IsNan(AActual) and (Abs(AActual - AExpected) <= ATolerance), AMessage);
end;

function MakeGraph(const AEcho: Boolean = False): TBusGraph;
var
  LSettings: array[0..0] of TBusSettings;
  LEcho: TEchoSettings;
begin
  LSettings[0] := DefaultBusSettings;
  Result := TBusGraph.Create(8000, LSettings);
  try
    if AEcho then
    begin
      LEcho := DefaultEchoSettings(8000);
      LEcho.DelayFrames := 16;
      LEcho.Feedback := 0.5;
      LEcho.WetGain := 0.5;
      Result.AddEffect(0, TEchoEffect.Create(8000, LEcho));
    end;
  except
    Result.Free;
    raise;
  end;
end;

function Tone(const AStart, AGate: Int64; const AFrequency: Double = 440): TFrameTone;
begin
  Result := Default(TFrameTone);
  Result.Voice := DefaultSynthVoice;
  Result.Voice.Gain := 0.4;
  Result.Voice.Envelope.AttackSeconds := 0.002;
  Result.Voice.Envelope.DecaySeconds := 0.003;
  Result.Voice.Envelope.SustainLevel := 0.6;
  Result.Voice.Envelope.ReleaseSeconds := 0.002;
  Result.StartFrame := AStart;
  Result.GateFrames := AGate;
  Result.FrequencyHz := AFrequency;
  Result.Velocity := 0.8;
  Result.Seed := 731;
end;

function Admit(const ASynth: TScheduledSynth; const ATone: TFrameTone;
  const AGroup: Integer): Int64;
begin
  Result := -1;
  Check(ASynth.TrySchedule(ATone, 0, AGroup, Result) = srScheduled, 'Voice admission');
end;

procedure CheckOwnershipAndFrames;
const
  CStart: Int64 = 9007199254740993;
var
  LFactory: TProbeFactory;
  LGraph: TBusGraph;
  LSynth: TScheduledSynth;
  LTone: TFrameTone;
  LCurve: TAutomationCurve;
  LPoints: TAutomationPoints;
  LId: Int64;
  LOldId: Int64;
  LLeft: Double;
  LRight: Double;
  LIndex: Integer;
  LRejected: Boolean;
begin
  LFactory := TProbeFactory.Create;
  LGraph := nil;
  LSynth := nil;
  LCurve := nil;
  try
    LGraph := MakeGraph;
    LSynth := TScheduledSynth.Create(LGraph, 1, 1000, CStart);
    LTone := Tone(CStart + 2, 3);
    LTone.Voice.SourceFactory := LFactory;
    LTone.Voice.Envelope.AttackSeconds := 0;
    LTone.Voice.Envelope.DecaySeconds := 0;
    LTone.Voice.Envelope.SustainLevel := 1;
    LTone.Voice.Envelope.ReleaseSeconds := 0;
    SetLength(LPoints, 1);
    LPoints[0].Frame := 0;
    LPoints[0].Value := 0.5;
    LPoints[0].Transition := atHold;
    LCurve := TAutomationCurve.Create(LPoints);
    LTone.Voice.Automation.GainMultiplier := LCurve;
    LId := Admit(LSynth, LTone, 7);
    LOldId := LId;
    LId := 999;
    Check(LSynth.TrySchedule(LTone, 0, 7, LId) = srVoiceLimit, 'Pending voice reserves capacity');
    Check((LId = 999) and (LFactory.Created = 1), 'Rejected admission preserves ID and avoids source');
    FreeAndNil(LCurve);
    LTone.Voice.Automation.GainMultiplier := nil;
    Check((LSynth.PendingCount = 1) and (LSynth.ActiveCount = 0), 'Pending count before first frame');
    for LIndex := 0 to 4 do
    begin
      LSynth.Process(LLeft, LRight);
      if LIndex < 2 then
      begin
        Near(LLeft, 0, 0, 'Exact high Int64 start silence');
      end
      else
      begin
        Check(LLeft > 0, 'Copied curve remains usable after caller destruction');
        Near(LRight, -0.5 * LLeft, 1E-14, 'Stereo source histories');
        if LIndex = 2 then
        begin
          Near(LLeft, (1 - Exp(-2 * Pi * 1800 / 8000)) * 0.4 * 0.8 * 0.5 * Sqrt(0.5),
            1E-13, 'Independent initial filter/pan/owned-gain sample');
          Check((LSynth.ActiveCount = 1) and (LSynth.PendingCount = 0), 'Committed count');
        end;
      end;
    end;
    Check(LSynth.NextFrame = CStart + 5, 'Absolute frame increments remain exact');
    Check((LFactory.OffCount = 1) and (LFactory.OffFrame = 3), 'Zero-release source note-off at gate');
    Check((LFactory.Destroyed = 1) and (LSynth.ScheduledCount = 0) and
      (LSynth.ReservedWork = 0), 'Final-frame cleanup returns capacity');
    LRejected := False;
    try
      LSynth.CancelFuture(7, CStart + 4);
    except
      on EAudio do
      begin
        LRejected := True;
      end;
    end;
    Check(LRejected and not LSynth.Failed, 'Cannot cancel committed frame region');
    LSynth.Reset;
    LTone.StartFrame := 0;
    LId := Admit(LSynth, LTone, 7);
    Check(LId > LOldId, 'Reset does not reuse voice IDs');
    Check(not LSynth.ReleaseVoice(LOldId), 'Stale voice ID cannot release replacement');
    Check(LSynth.ReleaseVoice(LId) and (LSynth.ScheduledCount = 0), 'Pending ID release cancels');
  finally
    LCurve.Free;
    LSynth.Free;
    LGraph.Free;
    LFactory.Free;
  end;
end;

procedure CheckCancellation;
var
  LGraph: TBusGraph;
  LReferenceGraph: TBusGraph;
  LSynth: TScheduledSynth;
  LReference: TScheduledSynth;
  LFrame: Integer;
  LLeft: Double;
  LRight: Double;
  LExpectedLeft: Double;
  LExpectedRight: Double;
begin
  LGraph := MakeGraph(True);
  LReferenceGraph := nil;
  LSynth := nil;
  LReference := nil;
  try
    LReferenceGraph := MakeGraph(True);
    LSynth := TScheduledSynth.Create(LGraph);
    LReference := TScheduledSynth.Create(LReferenceGraph);
    Admit(LSynth, Tone(0, 80), 1);
    Admit(LReference, Tone(0, 80), 1);
    Admit(LSynth, Tone(50, 20, 550), 1);
    Admit(LReference, Tone(50, 20, 550), 1);
    Admit(LSynth, Tone(100, 20, 660), 1);
    Admit(LSynth, Tone(100, 20, 880), 2);
    Admit(LReference, Tone(100, 20, 880), 2);
    for LFrame := 0 to 399 do
    begin
      if LFrame = 40 then
      begin
        Check(LSynth.CancelFuture(1, 60) = 1, 'Future cancellation selects group and pivot');
        Check((LSynth.ActiveCount = 1) and (LSynth.PendingCount = 2),
          'Cancellation preserves committed and earlier pending notes');
        Admit(LSynth, Tone(90, 20, 330), 1);
        Admit(LReference, Tone(90, 20, 330), 1);
      end;
      LSynth.Process(LLeft, LRight);
      LReference.Process(LExpectedLeft, LExpectedRight);
      Near(LLeft, LExpectedLeft, 0, 'Cancellation/replacement preserves committed and echo samples');
      Near(LRight, LExpectedRight, 0, 'Cancellation/replacement stereo replay');
      if LFrame = 160 then
      begin
        Check((LSynth.ScheduledCount = 0) and (Abs(LLeft) > 1E-8),
          'Bus tail continues after voice cleanup');
      end;
    end;
  finally
    LReference.Free;
    LSynth.Free;
    LReferenceGraph.Free;
    LGraph.Free;
  end;
end;

procedure CheckStopGroup;
var
  LGraph: TBusGraph;
  LReferenceGraph: TBusGraph;
  LSynth: TScheduledSynth;
  LReference: TScheduledSynth;
  LFrame: Integer;
  LLeft: Double;
  LRight: Double;
  LExpectedLeft: Double;
  LExpectedRight: Double;
begin
  LGraph := MakeGraph(True);
  LReferenceGraph := nil;
  LSynth := nil;
  LReference := nil;
  try
    LReferenceGraph := MakeGraph(True);
    LSynth := TScheduledSynth.Create(LGraph);
    LReference := TScheduledSynth.Create(LReferenceGraph);
    Admit(LSynth, Tone(0, 80), 1);
    Admit(LReference, Tone(0, 10), 1);
    Admit(LSynth, Tone(10, 30, 550), 1);
    Admit(LSynth, Tone(15, 30, 880), 2);
    Admit(LReference, Tone(15, 30, 880), 2);
    for LFrame := 0 to 199 do
    begin
      if LFrame = 10 then
      begin
        Check(LSynth.StopGroup(1) = 2, 'Stop releases committed and drops exact-cursor pending');
      end;
      LSynth.Process(LLeft, LRight);
      LReference.Process(LExpectedLeft, LExpectedRight);
      Near(LLeft, LExpectedLeft, 0, 'Early attack release agrees with independent shortened gate');
      Near(LRight, LExpectedRight, 0, 'Stop preserves other group and bus history');
    end;
  finally
    LReference.Free;
    LSynth.Free;
    LReferenceGraph.Free;
    LGraph.Free;
  end;
end;

procedure CheckFailureAndBudget;
var
  LFactory: TProbeFactory;
  LGraph: TBusGraph;
  LSynth: TScheduledSynth;
  LTone: TFrameTone;
  LId: Int64;
  LLeft: Double;
  LRight: Double;
  LRejected: Boolean;
begin
  LFactory := TProbeFactory.Create;
  LGraph := nil;
  LSynth := nil;
  try
    LGraph := MakeGraph;
    LSynth := TScheduledSynth.Create(LGraph, 2, 17);
    LTone := Tone(0, 4);
    LTone.Voice.SourceFactory := LFactory;
    Admit(LSynth, LTone, 1);
    LId := 999;
    Check(LSynth.TrySchedule(LTone, 0, 1, LId) = srWorkLimit, 'Reserved source work limit');
    Check((LId = 999) and (LFactory.Created = 1), 'Work rejection avoids source allocation');
    LSynth.Reset;
    LFactory.FailCreate := True;
    LRejected := False;
    try
      LSynth.TrySchedule(LTone, 0, 1, LId);
    except
      on EAudio do
      begin
        LRejected := True;
      end;
    end;
    Check(LRejected and (LId = 999) and not LSynth.Failed and
      (LSynth.ScheduledCount = 0), 'Failed source construction preserves scheduler');
    LFactory.FailCreate := False;
    Admit(LSynth, LTone, 1);
    LFactory.FailRead := True;
    LLeft := 7;
    LRight := 8;
    LRejected := False;
    try
      LSynth.Process(LLeft, LRight);
    except
      on EAudio do
      begin
        LRejected := True;
      end;
    end;
    Check(LRejected and LSynth.Failed and (LSynth.NextFrame = 0),
      'Source failure poisons scheduler without advancing cursor');
    Check((LLeft = 7) and (LRight = 8), 'Processing failure preserves caller output');
    LFactory.FailRead := False;
    LRejected := False;
    try
      LSynth.Process(LLeft, LRight);
    except
      on EAudio do
      begin
        LRejected := True;
      end;
    end;
    Check(LRejected, 'Removing source failure requires explicit recovery');
    LSynth.Reset;
    Check((LSynth.ReservedWork = 0) and (LSynth.ScheduledCount = 0) and not LSynth.Failed,
      'Reset recovers scheduler and discards failed voice state');
    Admit(LSynth, LTone, 1);
    LFactory.Reenter := LSynth;
    LRejected := False;
    try
      LSynth.Process(LLeft, LRight);
    except
      on EAudio do
      begin
        LRejected := True;
      end;
    end;
    Check(LRejected and LSynth.Failed, 'Source callbacks cannot mutate active scheduler');
    LFactory.Reenter := nil;
    LSynth.Reset;
    Check(LFactory.Created = LFactory.Destroyed, 'All admitted sources released exactly once');
  finally
    LSynth.Free;
    LGraph.Free;
    LFactory.Free;
  end;
end;

procedure CheckAtomicReplacement;
var
  LGraph: TBusGraph;
  LReferenceGraph: TBusGraph;
  LSynth: TScheduledSynth;
  LReference: TScheduledSynth;
  LFactory: TProbeFactory;
  LReplacements: TFrameTones;
  LId: Int64;
  LRejected: Boolean;
  LFrame: Integer;
  LLeft: Double;
  LRight: Double;
  LExpectedLeft: Double;
  LExpectedRight: Double;
begin
  LGraph := MakeGraph(True);
  LReferenceGraph := nil;
  LSynth := nil;
  LReference := nil;
  LFactory := nil;
  try
    LReferenceGraph := MakeGraph(True);
    LSynth := TScheduledSynth.Create(LGraph, 3);
    LReference := TScheduledSynth.Create(LReferenceGraph, 3);
    LFactory := TProbeFactory.Create;
    Admit(LSynth, Tone(0, 80), 1);
    Admit(LReference, Tone(0, 80), 1);
    Admit(LSynth, Tone(50, 30, 550), 1);
    Admit(LSynth, Tone(60, 30, 660), 1);
    Admit(LReference, Tone(50, 30, 550), 1);
    Admit(LReference, Tone(60, 30, 660), 1);
    SetLength(LReplacements, 2);
    LReplacements[0] := Tone(45, 30, 330);
    LReplacements[0].Voice.SourceFactory := LFactory;
    LReplacements[1] := Tone(65, 30, 220);
    LReplacements[1].Voice.CutoffHz := 8000;
    LId := 999;
    LRejected := False;
    try
      LSynth.TryReplaceFuture(1, 40, 0, LReplacements, LId);
    except
      on EAudio do
      begin
        LRejected := True;
      end;
    end;
    Check(LRejected and (LSynth.ScheduledCount = 3) and (LId = 999),
      'Invalid batch preserves complete old schedule');
    LReplacements[1] := Tone(65, 30, 220);
    LReplacements[1].Voice.SourceFactory := LFactory;
    LFactory.FailCreate := True;
    LReplacements[0].Voice.SourceFactory := nil;
    LRejected := False;
    try
      LSynth.TryReplaceFuture(1, 40, 0, LReplacements, LId);
    except
      on EAudio do
      begin
        LRejected := True;
      end;
    end;
    Check(LRejected and not LSynth.Failed and (LSynth.ScheduledCount = 3) and (LId = 999),
      'Failure after first candidate construction preserves old schedule');
    for LFrame := 0 to 119 do
    begin
      LSynth.Process(LLeft, LRight);
      LReference.Process(LExpectedLeft, LExpectedRight);
      Near(LLeft, LExpectedLeft, 0, 'Failed replacement preserves original future audio');
      Near(LRight, LExpectedRight, 0, 'Failed replacement preserves original future stereo');
    end;
    LSynth.Reset;
    LReference.Reset;
    Admit(LSynth, Tone(0, 80), 1);
    Admit(LReference, Tone(0, 80), 1);
    Admit(LSynth, Tone(50, 30, 550), 1);
    Admit(LSynth, Tone(60, 30, 660), 1);
    LReplacements[1].Voice.SourceFactory := nil;
    for LFrame := 0 to 199 do
    begin
      if LFrame = 40 then
      begin
        Check(LSynth.TryReplaceFuture(1, 40, 0, LReplacements, LId) = srScheduled,
          'Replacement uses capacity released by removed future notes');
        Check((LId = 7) and (LSynth.ScheduledCount = 3) and (LSynth.ActiveCount = 1),
          'Failed candidates consume neither IDs nor committed voices');
        Admit(LReference, LReplacements[0], 1);
        Admit(LReference, LReplacements[1], 1);
      end;
      LSynth.Process(LLeft, LRight);
      LReference.Process(LExpectedLeft, LExpectedRight);
      Near(LLeft, LExpectedLeft, 0, 'Atomic replacement preserves committed source and echo');
      Near(LRight, LExpectedRight, 0, 'Atomic replacement stereo identity');
    end;
  finally
    LReference.Free;
    LSynth.Free;
    LFactory.Free;
    LReferenceGraph.Free;
    LGraph.Free;
  end;
end;

procedure CheckTempoPublication(const AAccept: Boolean);
var
  LGraph: TBusGraph;
  LReferenceGraph: TBusGraph;
  LSynth: TScheduledSynth;
  LReference: TScheduledSynth;
  LClock: TTempoMap;
  LCandidate: TTempoMap;
  LTempos: TTempoChanges;
  LReplacements: TFrameTones;
  LPivot: Integer;
  LId: Int64;
  LRejected: Boolean;
  LFrame: Integer;
  LLeft: Double;
  LRight: Double;
  LExpectedLeft: Double;
  LExpectedRight: Double;
begin
  LGraph := MakeGraph(True);
  LReferenceGraph := nil;
  LSynth := nil;
  LReference := nil;
  LClock := nil;
  LCandidate := nil;
  try
    LReferenceGraph := MakeGraph(True);
    LSynth := TScheduledSynth.Create(LGraph, 5);
    LReference := TScheduledSynth.Create(LReferenceGraph, 5);
    SetLength(LTempos, 1);
    LTempos[0] := MakeTempoChange(0, 1000);
    LClock := TTempoMap.Create(4, 48, LTempos);
    { Deliberately short musical time: 8 frames/quarter before the pivot,
      12 afterwards. Reference frames below are independent integer values. }
    Admit(LSynth, Tone(0, 60), 1);
    Admit(LReference, Tone(0, 60), 1);
    Admit(LSynth, Tone(24, 40, 550), 1);
    Admit(LReference, Tone(24, 40, 550), 1);
    Admit(LSynth, Tone(32, 16, 660), 1);
    Admit(LSynth, Tone(64, 16, 770), 1);
    Admit(LSynth, Tone(70, 12, 880), 2);
    if AAccept then
    begin
      Admit(LReference, Tone(32, 24, 660), 1);
      Admit(LReference, Tone(80, 24, 770), 1);
    end
    else
    begin
      Admit(LReference, Tone(32, 16, 660), 1);
      Admit(LReference, Tone(64, 16, 770), 1);
    end;
    Admit(LReference, Tone(70, 12, 880), 2);
    for LFrame := 0 to 199 do
    begin
      if LFrame = 7 then
      begin
        LPivot := LClock.NextGridTick(LSynth.NextFrame + 5, 8000, 16);
        Check(LPivot = 16, 'Tempo pivot lies on the next four-quarter bar');
        LCandidate := LClock.WithTempoFrom(LPivot, 1500, 8000, LSynth.NextFrame + 5);
        SetLength(LReplacements, 2);
        LReplacements[0] := Tone(LCandidate.FrameAtTick(16, 8000),
          LCandidate.FrameAtTick(24, 8000) - LCandidate.FrameAtTick(16, 8000), 660);
        LReplacements[1] := Tone(LCandidate.FrameAtTick(32, 8000),
          LCandidate.FrameAtTick(40, 8000) - LCandidate.FrameAtTick(32, 8000), 770);
        if not AAccept then
        begin
          LReplacements[1].Voice.CutoffHz := 8000;
        end;
        LRejected := False;
        LId := -1;
        try
          Check(LSynth.TryReplaceFuture(1, LClock.FrameAtTick(LPivot, 8000),
            0, LReplacements, LId) = srScheduled, 'Tempo replacement admission');
          { Publish only after admission; no fallible work between these steps. }
          LClock.Free;
          LClock := LCandidate;
          LCandidate := nil;
        except
          on EAudio do
          begin
            LRejected := True;
          end;
        end;
        Check(LRejected <> AAccept, 'Expected tempo admission outcome');
        if AAccept then
        begin
          Check(LClock.FrameAtTick(32, 8000) = 80, 'Admitted tempo is published');
        end
        else
        begin
          Check((LClock.FrameAtTick(32, 8000) = 64) and (LId = -1),
            'Rejected tempo preserves clock and IDs');
        end;
      end;
      LSynth.Process(LLeft, LRight);
      LReference.Process(LExpectedLeft, LExpectedRight);
      Near(LLeft, LExpectedLeft, 0, 'Tempo edit preserves gates, other group and echo');
      Near(LRight, LExpectedRight, 0, 'Tempo edit stereo agrees with independent schedule');
    end;
  finally
    LCandidate.Free;
    LClock.Free;
    LReference.Free;
    LSynth.Free;
    LReferenceGraph.Free;
    LGraph.Free;
  end;
end;

procedure CheckBlocksAndOffline;
var
  LGraph: TBusGraph;
  LSynth: TScheduledSynth;
  LTones: TFrameTones;
  LOffline: TAudioClip;
  LWhole: TAudioClip;
  LPart: TAudioClip;
  LIndex: Integer;
  LChannel: Integer;
  LRejected: Boolean;
  LPrevious: TAudioClip;
begin
  LGraph := MakeGraph;
  LSynth := nil;
  LOffline := nil;
  LWhole := nil;
  LPart := nil;
  try
    LSynth := TScheduledSynth.Create(LGraph);
    SetLength(LTones, 2);
    LTones[0] := Tone(7, 80);
    LTones[1] := Tone(30, 60, 550);
    LOffline := RenderFrameTones(LTones, 8000, 200);
    Admit(LSynth, LTones[0], 0);
    Admit(LSynth, LTones[1], 0);
    LWhole := RenderScheduledFrames(LSynth, 200);
    for LIndex := 0 to 199 do
    begin
      for LChannel := 0 to 1 do
      begin
        Near(LWhole.SampleAt(LIndex, LChannel), LOffline.SampleAt(LIndex, LChannel),
          3E-8, 'Shared offline/streaming signal within Single accumulation rounding');
      end;
    end;
    LSynth.Reset;
    Admit(LSynth, LTones[0], 0);
    Admit(LSynth, LTones[1], 0);
    LPart := RenderScheduledFrames(LSynth, 37);
    for LIndex := 0 to 36 do
    begin
      Check(LPart.SampleAt(LIndex, 0) = LWhole.SampleAt(LIndex, 0), 'First streamed block');
    end;
    FreeAndNil(LPart);
    LPart := RenderScheduledFrames(LSynth, 163);
    for LIndex := 0 to 162 do
    begin
      for LChannel := 0 to 1 do
      begin
        Check(LPart.SampleAt(LIndex, LChannel) = LWhole.SampleAt(37 + LIndex, LChannel),
          'Exact output across arbitrary block boundary');
      end;
    end;
    LPrevious := LPart;
    LRejected := False;
    try
      LPart := RenderScheduledFrames(LSynth, High(Integer));
    except
      on EAudio do
      begin
        LRejected := True;
      end;
    end;
    Check(LRejected and not LSynth.Failed and (LSynth.NextFrame = 200) and
      (LPart = LPrevious), 'Clip preflight preserves cursor and old output');
  finally
    LPart.Free;
    LWhole.Free;
    LOffline.Free;
    LSynth.Free;
    LGraph.Free;
  end;
end;

procedure CheckAutomationWork;
var
  LCurve: TAutomationCurve;
  LNext: TAutomationCurve;
  LPoints: TAutomationPoints;
  LFactory: TProbeFactory;
  LGraph: TBusGraph;
  LSynth: TScheduledSynth;
  LStream: TFrameToneStream;
  LOriginal: TFrameTones;
  LReplacement: TFrameTones;
  LReference: TAudioClip;
  LActual: TAudioClip;
  LSamples: TAudioSamples;
  LId: Int64;
  LRejected: Boolean;
  LCreated: Integer;
  I: Integer;
begin
  LCurve := nil;
  LFactory := nil;
  LGraph := nil;
  LSynth := nil;
  LStream := nil;
  LReference := nil;
  LActual := nil;
  try
    SetLength(LPoints, 1);
    LPoints[0].Value := 0.5;
    LCurve := TAutomationCurve.Create(LPoints);
    for I := 2 to MaximumAutomationDepth do
    begin
      LNext := TAutomationCurve.CreateAffine(LCurve, 1, 0);
      LCurve.Free;
      LCurve := LNext;
    end;
    LFactory := TProbeFactory.Create;
    SetLength(LOriginal, 1);
    LOriginal[0] := Tone(2, 8);
    LOriginal[0].Voice.Envelope.ReleaseSeconds := 0;
    LOriginal[0].Voice.SourceFactory := LFactory;
    LReference := RenderFrameTones(LOriginal, 8000, 16);
    LReplacement := Copy(LOriginal);
    { Five independent evaluations, even when definitions share one object.
      Five depth-eight curves cost 640, source 1, scheduling overhead 16. }
    LReplacement[0].Voice.Automation.FrequencyHz := LCurve;
    LReplacement[0].Voice.Automation.PitchCents := LCurve;
    LReplacement[0].Voice.Automation.GainMultiplier := LCurve;
    LReplacement[0].Voice.Automation.Pan := LCurve;
    LReplacement[0].Voice.Automation.CutoffHz := LCurve;
    LGraph := MakeGraph;
    LSynth := TScheduledSynth.Create(LGraph, 1, 656);
    Admit(LSynth, LOriginal[0], 7);
    LCreated := LFactory.Created;
    LId := 999;
    Check(LSynth.TryReplaceFuture(7, 0, 0, LReplacement, LId) = srWorkLimit,
      'Automation work rejects replacement one unit below its reservation');
    Check((LId = 999) and (LFactory.Created = LCreated) and
      (LSynth.ScheduledCount = 1) and (LSynth.ReservedWork = 17) and
      (LSynth.NextFrame = 0) and not LSynth.Failed,
      'Automation work rejection preserves old voices, output ID and cursor');
    LActual := RenderScheduledFrames(LSynth, 16);
    for I := 0 to 15 do
    begin
      Near(LActual.SampleAt(I, 0), LReference.SampleAt(I, 0), 3E-8,
        'Rejected automated replacement preserves pending left audio');
      Near(LActual.SampleAt(I, 1), LReference.SampleAt(I, 1), 3E-8,
        'Rejected automated replacement preserves pending right audio');
    end;
    FreeAndNil(LSynth);
    LSynth := TScheduledSynth.Create(LGraph, 1, 657);
    Admit(LSynth, LReplacement[0], 7);
    Check(LSynth.ReservedWork = 657, 'Exact automated reservation is admitted');
    FreeAndNil(LSynth);
    LCreated := LFactory.Created;
    LRejected := False;
    try
      LStream := TFrameToneStream.Create(LReplacement, 8000, 0, 1, 656);
    except
      on EAudio do
      begin
        LRejected := True;
      end;
    end;
    Check(LRejected and (LStream = nil) and (LFactory.Created = LCreated),
      'Tone-stream preflight includes automation before source construction');
    LStream := TFrameToneStream.Create(LReplacement, 8000, 0, 1, 657);
    Check((LStream.PeakFrameWork = 657) and LStream.ReadSamples(16, LSamples) and
      LStream.Finished, 'Exact automated tone-stream budget remains renderable');
    LCreated := LFactory.Created;
    LReplacement[0].GateFrames := MaximumRenderVisits div 641 + 1;
    LRejected := False;
    try
      FreeAndNil(LActual);
      LActual := RenderFrameTones(LReplacement, 8000);
    except
      on EAudio do
      begin
        LRejected := True;
      end;
    end;
    Check(LRejected and (LActual = nil) and (LFactory.Created = LCreated),
      'Whole-clip automation work rejects before playback construction');
    WriteLn('Automation work: exact admission, atomic rejection, preserved audio and stream/offline bounds pass');
  finally
    LActual.Free;
    LReference.Free;
    LStream.Free;
    LSynth.Free;
    LGraph.Free;
    LFactory.Free;
    LCurve.Free;
  end;
end;

procedure CheckToneStream;
const
  CStarts: array[0..3] of Integer = (4096, 3, 2048, 4096);
var
  LTones: TFrameTones;
  LStream: TFrameToneStream;
  LOther: TFrameToneStream;
  LBad: TFrameToneStream;
  LClip: TAudioClip;
  LSamples: TAudioSamples;
  LCollected: TAudioSamples;
  LCurve: TAutomationCurve;
  LPoints: TAutomationPoints;
  LFactory: TProbeFactory;
  LSequence: TNoteSequence;
  LGates: TNoteGates;
  LTempos: TTempoChanges;
  LReport: TNoteRenderReport;
  LRead: Integer;
  LPosition: Integer;
  LRejected: Boolean;
  I: Integer;
begin
  LStream := nil;
  LOther := nil;
  LBad := nil;
  LClip := nil;
  LCurve := nil;
  LFactory := nil;
  LSequence := nil;
  try
    SetLength(LPoints, 2);
    LPoints[0].Value := 0.25;
    LPoints[0].Transition := atLinear;
    LPoints[1].Frame := 3000;
    LPoints[1].Value := 1;
    LCurve := TAutomationCurve.Create(LPoints);
    SetLength(LTones, 4);
    for I := 0 to High(LTones) do
    begin
      LTones[I].Voice := DefaultSynthVoice;
      LTones[I].Voice.Gain := 0.1;
      LTones[I].Voice.Automation.GainMultiplier := LCurve;
      LTones[I].Voice.Envelope.ReleaseSeconds := 0.025;
      LTones[I].Voice.Pan := -0.6 + I * 0.3;
      LTones[I].StartFrame := CStarts[I];
      LTones[I].GateFrames := 2200;
      LTones[I].FrequencyHz := 110 + I * 110;
      LTones[I].Velocity := 0.8;
      LTones[I].Seed := I + 1;
    end;
    LClip := RenderFrameTones(LTones, 8000, 7000);
    LStream := TFrameToneStream.Create(LTones, 8000, 7000, 3);
    LOther := TFrameToneStream.Create(LTones, 8000, 7000, 3);
    Check((LStream.PeakVoices = 3) and (LStream.FrameCount = 7000),
      'Stream preflight includes release overlap, unsorted starts and trailing silence');
    LTones[0].StartFrame := 0;
    LTones[0].Voice.Gain := 1;
    SetLength(LCollected, LClip.FrameCount * 2);
    LPosition := 0;
    while LStream.ReadSamples(2048, LSamples) do
    begin
      for I := 0 to High(LSamples) do
      begin
        LCollected[LPosition] := LSamples[I];
        Near(LSamples[I], LClip.SampleAt(LPosition div 2, LPosition mod 2), 2E-7,
          'Stream Double accumulation agrees with offline Single accumulation');
        Inc(LPosition);
      end;
    end;
    Check((LPosition = Length(LCollected)) and LStream.Finished and
      (LSamples = nil), 'Stream drains exact extent and returns nil at EOF');
    LPosition := 0;
    LRead := 1;
    while LOther.ReadSamples(LRead, LSamples) do
    begin
      for I := 0 to High(LSamples) do
      begin
        Check(LSamples[I] = LCollected[LPosition], 'Stream read partition is byte-exact');
        Inc(LPosition);
      end;
      LRead := 17 + (LRead * 13 mod 2000);
    end;
    Check(LPosition = Length(LCollected), 'Irregular block extent');
    FreeAndNil(LStream);
    FreeAndNil(LOther);
    LFactory := TProbeFactory.Create;
    SetLength(LTones, 2);
    for I := 0 to 1 do
    begin
      LTones[I] := Default(TFrameTone);
      LTones[I].Voice := DefaultSynthVoice;
      LTones[I].Voice.Envelope.ReleaseSeconds := 0;
      LTones[I].Voice.SourceFactory := LFactory;
      LTones[I].GateFrames := 8;
      LTones[I].StartFrame := I * 8;
      LTones[I].FrequencyHz := 220;
      LTones[I].Velocity := 1;
    end;
    LStream := TFrameToneStream.Create(LTones, 8000, 0, 1);
    Check(LFactory.Created = 0, 'Future source objects are not created during preflight');
    LRejected := False;
    try
      LStream.ReadSamples(0, LSamples);
    except
      on EAudio do
      begin
        LRejected := True;
      end;
    end;
    Check(LRejected and not LStream.Failed and (LStream.EmittedFrames = 0),
      'Invalid stream read is retryable without advancing');
    LStream.ReadSamples(16, LSamples);
    Check((Length(LSamples) = 32) and LStream.Finished and
      (LFactory.Created = 2) and (LFactory.Destroyed = 2),
      'Release end before simultaneous start allows one-slot reuse');
    FreeAndNil(LStream);
    LTones[1].StartFrame := 7;
    LRejected := False;
    try
      LBad := TFrameToneStream.Create(LTones, 8000, 0, 1);
    except
      on EAudio do
      begin
        LRejected := True;
      end;
    end;
    Check(LRejected and (LBad = nil) and (LFactory.Created = 2),
      'Late overlap rejects before creating any sources');
    LRejected := False;
    try
      LBad := TFrameToneStream.Create(LTones, 8000, 0, 2, 1);
    except
      on EAudio do
      begin
        LRejected := True;
      end;
    end;
    Check(LRejected and (LBad = nil), 'Concurrent weighted work is bounded');
    LStream := TFrameToneStream.Create(LTones, 8000);
    LStream.ReadSamples(3, LSamples);
    LFactory.FailRead := True;
    LRejected := False;
    try
      LStream.ReadSamples(3, LSamples);
    except
      on EAudio do
      begin
        LRejected := True;
      end;
    end;
    Check(LRejected and LStream.Failed and (LSamples = nil) and
      (LStream.EmittedFrames = 3), 'Source failure poisons stream without publishing partial block');
    FreeAndNil(LStream);

    { Long musical planning owns events, not full PCM storage. The unchanged
      offline renderer must still reject this extent before allocating audio. }
    SetLength(LGates, 1);
    LGates[0].Pitch := 60;
    LGates[0].Velocity := 96;
    LGates[0].Channel := -1;
    LGates[0].EndTick := 1;
    SetLength(LTempos, 1);
    LTempos[0] := MakeTempoChange(0, 500000);
    LSequence := TNoteSequence.Create(1, 10000, LTempos, LGates);
    LTones := PlanNoteTones(LSequence, 8000, DefaultSynthVoice, LReport);
    LStream := TFrameToneStream.Create(LTones, 8000, LSequence.FrameAtTick(10000, 8000));
    Check((LStream.FrameCount = 40000000) and (LStream.PeakVoices = 1),
      'Long sequence admits without allocating the 40-million-frame timeline');
    LStream.ReadSamples(17, LSamples);
    Check(Length(LSamples) = 34, 'Long sequence starts with bounded storage');
    LRejected := False;
    try
      FreeAndNil(LClip);
      LClip := RenderNoteSequence(LSequence, 8000, DefaultSynthVoice, LReport);
    except
      on EAudio do
      begin
        LRejected := True;
      end;
    end;
    Check(LRejected and (LClip = nil), 'Offline full-clip sample budget is unchanged');
    WriteLn('Tone streams: exact block replay, release overlap, lazy sources, bounded work, failure and long planning pass');
  finally
    LSequence.Free;
    LBad.Free;
    LOther.Free;
    LStream.Free;
    LFactory.Free;
    LCurve.Free;
    LClip.Free;
  end;
end;

procedure CheckTonePcmReader;
var
  LTones: TFrameTones;
  LStream: TFrameToneStream;
  LReader: TTonePcmReader;
  LConverter: TSincResampleStream;
  LClip: TAudioClip;
  LReference: TAudioClip;
  LBlock: TAudioSamples;
  LLeft: Double;
  LRight: Double;
  LCount: Integer;
  LRejected: Boolean;
  I: Integer;
begin
  LStream := nil;
  LReader := nil;
  LConverter := nil;
  LClip := nil;
  LReference := nil;
  try
    SetLength(LTones, 1);
    LTones[0].Voice := DefaultSynthVoice;
    LTones[0].Voice.Envelope.ReleaseSeconds := 0;
    LTones[0].FrequencyHz := 300;
    LTones[0].GateFrames := 1234;
    LTones[0].Velocity := 1;
    LClip := RenderFrameTones(LTones, 16000);
    LReference := ResampleClip(LClip, 11025);
    LStream := TFrameToneStream.Create(LTones, 16000);
    LReader := TTonePcmReader.Create(LStream, 17);
    LConverter := TSincResampleStream.Create(LReader, 11025);
    LLeft := 0;
    LRight := 0;
    LCount := 0;
    while LConverter.ReadFrame(LLeft, LRight) do
    begin
      Near(LLeft, LReference.SampleAt(LCount, 0), 2E-8,
        'Tone reader and bounded conversion match offline left PCM');
      Near(LRight, LReference.SampleAt(LCount, 1), 2E-8,
        'Tone reader and bounded conversion match offline right PCM');
      Inc(LCount);
    end;
    Check((LCount = 851) and (LCount = LReference.FrameCount) and
      (LReader.FramesRead = 1234) and (LConverter.InputFrameCount = 1234),
      'Tone conversion drains fractional-ratio duration and final partial block');
    LLeft := 71;
    LRight := 72;
    Check(not LReader.ReadFrame(LLeft, LRight) and (LLeft = 71) and (LRight = 72),
      'Tone reader EOF preserves arguments');
    FreeAndNil(LConverter);
    FreeAndNil(LReader);
    Check(LStream.Finished, 'Borrowed stream survives reader destruction');
    FreeAndNil(LStream);
    LStream := TFrameToneStream.Create(LTones, 16000);
    LStream.ReadSamples(3, LBlock);
    LReader := TTonePcmReader.Create(LStream, 17);
    Check(LReader.ReadFrame(LLeft, LRight), 'Reader attaches at current stream position');
    Near(LLeft, LClip.SampleAt(3, 0), 2E-8, 'Reader starts at the remaining suffix');
    LStream.ReadSamples(1, LBlock);
    for I := 0 to 1 do
    begin
      LLeft := 71;
      LRight := 72;
      LRejected := False;
      try
        LReader.ReadFrame(LLeft, LRight);
      except
        on EAudio do
        begin
          LRejected := True;
        end;
      end;
      Check(LRejected and (LLeft = 71) and (LRight = 72),
        'External advance poisons buffered reader and preserves output arguments');
    end;
    WriteLn('Tone PCM reader: bounded conversion, suffix, ownership, EOF and failure pass');
  finally
    LReference.Free;
    LClip.Free;
    LConverter.Free;
    LReader.Free;
    LStream.Free;
  end;
end;

begin
  try
    CheckAutomationWork;
    CheckTonePcmReader;
    CheckToneStream;
    CheckOwnershipAndFrames;
    CheckCancellation;
    CheckStopGroup;
    CheckFailureAndBudget;
    CheckAtomicReplacement;
    CheckTempoPublication(False);
    CheckTempoPublication(True);
    WriteLn('Tempo candidate admission/publication and independent audio reference passed');
    CheckBlocksAndOffline;
    WriteLn('Scheduled voices, exact cancellation, release, ownership, recovery and blocks passed');
  except
    on LException: Exception do
    begin
      WriteLn(StdErr, LException.ClassName, ': ', LException.Message);
      Halt(1);
    end;
  end;
end.
