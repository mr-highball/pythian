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
program pythian_tests_bus;

{$mode delphi}
{$H+}

uses
  SysUtils,
  Math,
  pythian.audio,
  pythian.effects,
  pythian.echo,
  pythian.bus;

type
  TRejectEffect = class(TAudioEffect)
  public
    Reject: Boolean;
    RejectReset: Boolean;
    Reenter: TBusGraph;
    procedure Reset; override;
    procedure Process(const ALeft, ARight: Double;
      out AOutputLeft, AOutputRight: Double); override;
    function FrameCost: Integer; override;
  end;

procedure TRejectEffect.Reset;
begin
  if RejectReset then
  begin
    raise EAudio.Create('Deliberate reset failure');
  end;
  Reject := False;
  Reenter := nil;
end;

procedure TRejectEffect.Process(const ALeft, ARight: Double;
  out AOutputLeft, AOutputRight: Double);
begin
  if Reenter <> nil then
  begin
    Reenter.SetBusGain(0, 1);
  end;
  if Reject then
  begin
    raise EAudio.Create('Deliberate bus failure');
  end;
  AOutputLeft := ALeft;
  AOutputRight := ARight;
end;

function TRejectEffect.FrameCost: Integer;
begin
  Result := 1;
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

procedure CheckEcho;
var
  LSettings: TEchoSettings;
  LEcho: TEchoEffect;
  LExpected: array[0..79] of Double;
  LIndex: Integer;
  LB0: Double;
  LA2: Double;
  LLeft: Double;
  LRight: Double;
  LInput: Double;
  LRejected: Boolean;
begin
  LSettings := DefaultEchoSettings(8000);
  Check(LSettings.DelayFrames = 3000, 'Precursor delay default');
  LSettings.DelayFrames := 4;
  LSettings.CutoffHz := 2000;
  LSettings.DryGain := 0;
  LSettings.WetGain := 1;
  LSettings.Feedback := 0.5;
  LEcho := TEchoEffect.Create(8000, LSettings);
  try
    LB0 := 0.5 / (1 + Sqrt(0.5));
    LA2 := (1 - Sqrt(0.5)) / (1 + Sqrt(0.5));
    for LIndex := 0 to High(LExpected) do
    begin
      { Independent closed-loop difference equation at a quarter-rate cutoff:
        (1+a2*z^-2)y = b0*z^-4*(1+2*z^-1+z^-2)*(x+feedback*y). }
      LExpected[LIndex] := 0;
      if LIndex >= 2 then
      begin
        LExpected[LIndex] := -LA2 * LExpected[LIndex - 2];
      end;
      if (LIndex = 4) or (LIndex = 6) then
      begin
        LExpected[LIndex] := LExpected[LIndex] + LB0;
      end;
      if LIndex = 5 then
      begin
        LExpected[LIndex] := LExpected[LIndex] + 2 * LB0;
      end;
      if LIndex >= 4 then
      begin
        LExpected[LIndex] := LExpected[LIndex] + 0.5 * LB0 * LExpected[LIndex - 4];
      end;
      if LIndex >= 5 then
      begin
        LExpected[LIndex] := LExpected[LIndex] + LB0 * LExpected[LIndex - 5];
      end;
      if LIndex >= 6 then
      begin
        LExpected[LIndex] := LExpected[LIndex] + 0.5 * LB0 * LExpected[LIndex - 6];
      end;
      LInput := 0;
      if LIndex = 0 then
      begin
        LInput := 1;
      end;
      if LIndex = 3 then
      begin
        LLeft := 7;
        LRight := 8;
        LRejected := False;
        try
          LEcho.Process(0, NaN, LLeft, LRight);
        except
          on EAudio do
          begin
            LRejected := True;
          end;
        end;
        Check(LRejected and not LEcho.Failed, 'Invalid echo input preserves history');
        Check((LLeft = 7) and (LRight = 8), 'Rejected echo output preserved');
      end;
      LEcho.Process(LInput, -0.5 * LInput, LLeft, LRight);
      Near(LLeft, LExpected[LIndex], 1E-14, 'Filtered feedback recurrence');
      Near(LRight, -0.5 * LExpected[LIndex], 1E-14, 'Independent stereo echo');
    end;
    LEcho.Reset;
    for LIndex := 0 to High(LExpected) do
    begin
      LLeft := 0;
      LRight := 0;
      if LIndex = 0 then
      begin
        LLeft := 1;
        LRight := -0.5;
      end;
      LEcho.Process(LLeft, LRight, LRight, LLeft);
      Near(LRight, LExpected[LIndex], 1E-14, 'Echo reset and crossed in-place left');
      Near(LLeft, -0.5 * LExpected[LIndex], 1E-14, 'Echo reset and crossed in-place right');
    end;
  finally
    LEcho.Free;
  end;
  LSettings.Feedback := 1;
  LRejected := False;
  try
    LEcho := TEchoEffect.Create(8000, LSettings);
    LEcho.Free;
  except
    on EAudio do
    begin
      LRejected := True;
    end;
  end;
  Check(LRejected, 'Non-decaying echo feedback rejected');
end;

procedure CheckRouting;
var
  LSettings: array[0..3] of TBusSettings;
  LInputs: array[0..3] of TStereoFrame;
  LGraph: TBusGraph;
  LIndex: Integer;
  LLeft: Double;
  LRight: Double;
  LRejected: Boolean;
begin
  for LIndex := 0 to 3 do
  begin
    LSettings[LIndex] := DefaultBusSettings;
    LSettings[LIndex].SmoothingSeconds := 0;
  end;
  LSettings[0].Gain := 0.5;
  LSettings[1].Gain := 0.25;
  LSettings[2].Gain := 0.4;
  LSettings[3].Gain := 0.5;
  LInputs[0].Left := 0.2;
  LInputs[0].Right := -0.4;
  LInputs[1].Left := 0.1;
  LInputs[1].Right := 0.2;
  LInputs[2].Left := 0.01;
  LInputs[2].Right := -0.02;
  LInputs[3].Left := 0.1;
  LInputs[3].Right := -0.1;
  LGraph := TBusGraph.Create(8000, LSettings);
  try
    LGraph.AddEffect(0, TGainEffect.Create(8000, 2, 0));
    LGraph.AddEffect(1, TGainEffect.Create(8000, 3, 0));
    LGraph.AddEffect(2, TGainEffect.Create(8000, 5, 0));
    LGraph.AddEffect(3, TGainEffect.Create(8000, 7, 0));
    LGraph.AddSend(0, 2, stPreFader, 0.25, 0);
    LGraph.AddSend(0, 3, stPostFader, 0.3, 0);
    LGraph.AddSend(1, 2, stPostFader, 0.5, 0);
    LGraph.AddSend(2, 3, stPostFader, 0.2, 0);
    LGraph.Process(LInputs, LLeft, LRight);
    Near(LLeft, 0.7665, 1E-12, 'Ordered bus sums, effects and pre/post taps left');
    Near(LRight, -0.973, 1E-12, 'Ordered bus sums, effects and pre/post taps right');
    LGraph.SetBusGain(0, 0);
    LGraph.Process(LInputs, LLeft, LRight);
    Near(LLeft, 0.5565, 1E-12, 'Pre-fader send survives fader mute left');
    Near(LRight, -0.553, 1E-12, 'Pre-fader send survives fader mute right');
    LRejected := False;
    try
      LGraph.AddSend(2, 0, stPostFader, 1, 0);
    except
      on EAudio do
      begin
        LRejected := True;
      end;
    end;
    Check(LRejected and not LGraph.Failed, 'Cycle/backward edge rejected before mutation');
    LGraph.Reset;
    LGraph.Process(LInputs, LInputs[0].Right, LInputs[0].Left);
    Near(LInputs[0].Right, 0.7665, 1E-12, 'Reset and input/output aliasing');
    Near(LInputs[0].Left, -0.973, 1E-12, 'Reset and input/output aliasing right');
  finally
    LGraph.Free;
  end;
end;

procedure CheckSmoothingAndFailure;
var
  LSettings: array[0..1] of TBusSettings;
  LInputs: array[0..1] of TStereoFrame;
  LGraph: TBusGraph;
  LReject: TRejectEffect;
  LIndex: Integer;
  LSend: Integer;
  LLeft: Double;
  LRight: Double;
  LRejected: Boolean;
begin
  LSettings[0] := DefaultBusSettings;
  LSettings[1] := DefaultBusSettings;
  LSettings[1].SmoothingSeconds := 0;
  LInputs[0].Left := 1;
  LInputs[0].Right := -0.5;
  LInputs[1].Left := 0;
  LInputs[1].Right := 0;
  LGraph := TBusGraph.Create(1000, LSettings);
  try
    LSend := LGraph.AddSend(0, 1, stPostFader, 1, 0.015);
    LReject := TRejectEffect.Create(1000);
    LGraph.AddEffect(1, LReject);
    LGraph.SetBusGain(0, 0);
    LGraph.SetSendGain(LSend, 0);
    for LIndex := 1 to 35 do
    begin
      if LIndex = 10 then
      begin
        LInputs[1].Right := NaN;
        LRejected := False;
        try
          LGraph.Process(LInputs, LLeft, LRight);
        except
          on EAudio do
          begin
            LRejected := True;
          end;
        end;
        Check(LRejected and not LGraph.Failed, 'All bus inputs validate before state advances');
        LInputs[1].Right := 0;
      end;
      LGraph.Process(LInputs, LLeft, LRight);
      Near(LLeft, Exp(-LIndex / 35) * Exp(-LIndex / 15), 1E-13,
        'Separate music/send time constants');
      Near(LRight, -0.5 * LLeft, 1E-13, 'Smoothed gains preserve stereo');
    end;
    LReject.Reject := True;
    LLeft := 7;
    LRight := 8;
    LRejected := False;
    try
      LGraph.Process(LInputs, LLeft, LRight);
    except
      on EAudio do
      begin
        LRejected := True;
      end;
    end;
    Check(LRejected and LGraph.Failed, 'Downstream failure poisons graph');
    Check((LLeft = 7) and (LRight = 8), 'Failure preserves caller outputs');
    LReject.Reject := False;
    LRejected := False;
    try
      LGraph.Process(LInputs, LLeft, LRight);
    except
      on EAudio do
      begin
        LRejected := True;
      end;
    end;
    Check(LRejected, 'Graph requires reset despite removing cause');
    LReject.RejectReset := True;
    LRejected := False;
    try
      LGraph.Reset;
    except
      on EAudio do
      begin
        LRejected := True;
      end;
    end;
    Check(LRejected and LGraph.Failed, 'Partial reset cannot reopen graph');
    LReject.RejectReset := False;
    LGraph.Reset;
    LGraph.Process(LInputs, LLeft, LRight);
    Near(LLeft, 1, 1E-13, 'Reset restores initial bus/send gains');
    LReject.Reenter := LGraph;
    LRejected := False;
    try
      LGraph.Process(LInputs, LLeft, LRight);
    except
      on EAudio do
      begin
        LRejected := True;
      end;
    end;
    Check(LRejected and LGraph.Failed, 'Stage callback cannot change active graph');
    LGraph.Reset;
  finally
    LGraph.Free;
  end;
end;

function CreateMusicGraph: TBusGraph;
var
  LSettings: array[0..4] of TBusSettings;
  LEcho: TEchoSettings;
  LIndex: Integer;
begin
  for LIndex := 0 to High(LSettings) do
  begin
    LSettings[LIndex] := DefaultBusSettings;
    LSettings[LIndex].SmoothingSeconds := 0;
  end;
  LSettings[3].Gain := 0.4;
  Result := TBusGraph.Create(8000, LSettings);
  try
    LEcho := DefaultEchoSettings(8000);
    LEcho.DelayFrames := 4;
    LEcho.CutoffHz := 2000;
    LEcho.DryGain := 0;
    Result.AddEffect(1, TEchoEffect.Create(8000, LEcho));
    Result.AddSend(0, 1, stPostFader, 1, 0);
    Result.AddSend(0, 2, stPostFader, 1, 0);
    Result.AddSend(1, 2, stPostFader, 1, 0);
    Result.AddSend(2, 4, stPostFader, 1, 0);
    Result.AddSend(3, 4, stPostFader, 1, 0);
  except
    Result.Free;
    raise;
  end;
end;

procedure CheckMusicReturn;
var
  LGraph: TBusGraph;
  LReference: TBusGraph;
  LInputs: array[0..4] of TStereoFrame;
  LBus: Integer;
  LFrame: Integer;
  LLeft: Double;
  LRight: Double;
  LReferenceLeft: Double;
  LReferenceRight: Double;
begin
  for LBus := 0 to High(LInputs) do
  begin
    LInputs[LBus].Left := 0;
    LInputs[LBus].Right := 0;
  end;
  LInputs[3].Right := 0.25;
  LGraph := CreateMusicGraph;
  LReference := nil;
  try
    LReference := CreateMusicGraph;
    for LFrame := 0 to 30 do
    begin
      LInputs[0].Left := 0;
      if LFrame = 0 then
      begin
        LInputs[0].Left := 1;
      end;
      if LFrame = 2 then
      begin
        LGraph.SetBusGain(2, 0);
      end;
      if LFrame = 9 then
      begin
        LGraph.SetBusGain(2, 1);
      end;
      LGraph.Process(LInputs, LLeft, LRight);
      LReference.Process(LInputs, LReferenceLeft, LReferenceRight);
      Near(LRight, 0.1, 1E-15, 'Effects bypass music return control');
      if (LFrame >= 2) and (LFrame < 9) then
      begin
        Near(LLeft, 0, 0, 'Music return mute includes echo');
      end
      else
      begin
        Near(LLeft, LReferenceLeft, 0, 'Music return mute retains continuing echo history');
      end;
      if LFrame = 9 then
      begin
        Check(Abs(LLeft) > 1E-5, 'Echo is still sounding after return unmutes');
      end;
    end;
  finally
    LReference.Free;
    LGraph.Free;
  end;
end;

procedure CheckClipContinuity;
var
  LSettings: array[0..1] of TBusSettings;
  LEchoSettings: TEchoSettings;
  LGraph: TBusGraph;
  LWhole: TAudioClip;
  LFirst: TAudioClip;
  LSecond: TAudioClip;
  LRendered: TAudioClip;
  LPart: TAudioClip;
  LOverflow: TAudioClip;
  LPrevious: TAudioClip;
  LSamples: TAudioSamples;
  LIndex: Integer;
  LChannel: Integer;
  LRejected: Boolean;
begin
  LSettings[0] := DefaultBusSettings;
  LSettings[1] := DefaultBusSettings;
  LEchoSettings := DefaultEchoSettings(8000);
  LEchoSettings.DelayFrames := 80;
  LEchoSettings.Feedback := 0.7;
  LEchoSettings.WetGain := 0.6;
  SetLength(LSamples, 512 * 2);
  for LIndex := 0 to 511 do
  begin
    LSamples[LIndex * 2] := 0.2 * Sin(2 * Pi * LIndex / 31);
    LSamples[LIndex * 2 + 1] := -0.3 * Sin(2 * Pi * LIndex / 43);
  end;
  LWhole := TAudioClip.Create(8000, 2, LSamples);
  LFirst := nil;
  LSecond := nil;
  LRendered := nil;
  LPart := nil;
  LGraph := nil;
  LOverflow := nil;
  try
    LFirst := TAudioClip.Create(8000, 2, Copy(LSamples, 0, 202));
    LSecond := TAudioClip.Create(8000, 2, Copy(LSamples, 202, Length(LSamples) - 202));
    LGraph := TBusGraph.Create(8000, LSettings);
    LGraph.AddEffect(0, TEchoEffect.Create(8000, LEchoSettings));
    LGraph.AddSend(0, 1, stPostFader, 1, 0);
    LRendered := RenderBusClips([LWhole, nil], LGraph, 240);
    Check(LRendered.FrameCount = 752, 'Explicit graph tail frames');
    Check(Abs(LRendered.SampleAt(600, 0)) > 1E-6, 'Echo tail retained after input ends');
    LGraph.Reset;
    LPart := RenderBusClips([LFirst, nil], LGraph);
    for LIndex := 0 to 100 do
    begin
      for LChannel := 0 to 1 do
      begin
        Check(LPart.SampleAt(LIndex, LChannel) = LRendered.SampleAt(LIndex, LChannel),
          'First block exact replay');
      end;
    end;
    FreeAndNil(LPart);
    LPart := RenderBusClips([LSecond, nil], LGraph, 240);
    for LIndex := 0 to LPart.FrameCount - 1 do
    begin
      for LChannel := 0 to 1 do
      begin
        Check(LPart.SampleAt(LIndex, LChannel) = LRendered.SampleAt(LIndex + 101, LChannel),
          'Split-block sample identity including echo tail');
      end;
    end;
    LPrevious := LPart;
    LRejected := False;
    try
      LPart := RenderBusClips([LWhole, nil], LGraph, High(Integer));
    except
      on EAudio do
      begin
        LRejected := True;
      end;
    end;
    Check(LRejected and not LGraph.Failed and (LPart = LPrevious),
      'Render budget rejects without state/output mutation');
    SetLength(LSamples, 1);
    LSamples[0] := MaxSingle;
    LOverflow := TAudioClip.Create(8000, 1, LSamples);
    LGraph.AddEffect(1, TGainEffect.Create(8000, 16, 0));
    LRejected := False;
    try
      LPart := RenderBusClips([LOverflow, nil], LGraph);
    except
      on EAudio do
      begin
        LRejected := True;
      end;
    end;
    Check(LRejected and LGraph.Failed and (LPart = LPrevious),
      'Single overflow poisons graph and preserves old clip');
  finally
    LOverflow.Free;
    LGraph.Free;
    LPart.Free;
    LRendered.Free;
    LSecond.Free;
    LFirst.Free;
    LWhole.Free;
  end;
end;

begin
  try
    CheckEcho;
    CheckRouting;
    CheckSmoothingAndFailure;
    CheckMusicReturn;
    CheckClipContinuity;
    WriteLn('Filtered echo, bus routing, smoothing, recovery and block-continuity checks passed');
  except
    on LException: Exception do
    begin
      WriteLn(StdErr, LException.ClassName, ': ', LException.Message);
      Halt(1);
    end;
  end;
end.
