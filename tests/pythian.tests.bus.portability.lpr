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
program pythian_tests_bus_portability;

{$mode delphi}
{$H+}

uses
  SysUtils, Math, pythian.audio, pythian.bus, pythian.schedule,
  pythian.effects, pythian.ieee754;

type
  { An owned test effect drives the actual render conversion boundary, including
    values unreachable from ordinary normalized musical material. }
  TForcedEffect = class(TAudioEffect)
  public
    Value: Double;
    Channel: Integer;
    procedure Reset; override;
    procedure Process(const ALeft, ARight: Double;
      out AOutputLeft, AOutputRight: Double); override;
    function FrameCost: Integer; override;
  end;

var
  GChecks: Integer;

procedure Check(const ACondition: Boolean; const AMessage: String);
begin
  Inc(GChecks);
  if not ACondition then
  begin
    raise Exception.Create(AMessage);
  end;
end;

procedure TForcedEffect.Reset;
begin
end;

procedure TForcedEffect.Process(const ALeft, ARight: Double;
  out AOutputLeft, AOutputRight: Double);
begin
  AOutputLeft := 0.25;
  AOutputRight := 0.25;
  if Channel = 0 then
  begin
    AOutputLeft := Value;
  end
  else
  begin
    AOutputRight := Value;
  end;
end;

function TForcedEffect.FrameCost: Integer;
begin
  Result := 1;
end;

procedure Exercise(const AValue: Double; const AReject, AExact: Boolean;
  const AChannel: Integer; const AScheduled: Boolean);
var
  LGraph: TBusGraph;
  LEffect: TForcedEffect;
  LSynth: TScheduledSynth;
  LClip: TAudioClip;
  LRejected: Boolean;
begin
  LGraph := TBusGraph.Create(48000, [DefaultBusSettings]);
  LSynth := nil;
  LClip := nil;
  try
    LEffect := TForcedEffect.Create(48000);
    LEffect.Channel := AChannel;
    LEffect.Value := AValue;
    LGraph.AddEffect(0, LEffect);
    if AScheduled then
    begin
      LSynth := TScheduledSynth.Create(LGraph);
    end;
    LRejected := False;
    try
      if AScheduled then
      begin
        LClip := RenderScheduledFrames(LSynth, 1);
      end
      else
      begin
        LClip := RenderBusClips([nil], LGraph, 1);
      end;
    except
      on E: EAudio do
      begin
        LRejected := True;
      end;
    end;
    Check(LRejected = AReject, 'Wrong Float32 render admission');
    if AReject then
    begin
      Check(LClip = nil, 'Failed render returned a partial clip');
      if AScheduled then
      begin
        Check(LSynth.Failed, 'Scheduled conversion failure did not poison its epoch');
      end
      else
      begin
        Check(LGraph.Failed, 'Bus conversion failure did not require reset');
      end;
      LEffect.Value := 0.25;
      if AScheduled then
      begin
        LSynth.Reset;
        Check(not LSynth.Failed and (LSynth.NextFrame = 0), 'Scheduled reset failed');
        LClip := RenderScheduledFrames(LSynth, 1);
      end
      else
      begin
        LGraph.Reset;
        Check(not LGraph.Failed, 'Bus reset failed');
        LClip := RenderBusClips([nil], LGraph, 1);
      end;
      Check((LClip.SampleAt(0, 0) = 0.25) and (LClip.SampleAt(0, 1) = 0.25),
        'Reset recovery changed valid audio');
    end
    else
    begin
      Check((LClip.FrameCount = 1) and (LClip.Channels = 2) and
        (LClip.SampleRate = 48000), 'Successful clip shape changed');
      Check(not IsNan(LClip.SampleAt(0, AChannel)) and
        not IsInfinite(LClip.SampleAt(0, AChannel)) and
        (Abs(LClip.SampleAt(0, AChannel)) <= MaximumFiniteFloat32),
        'Successful clip exceeded finite Float32 range');
      if AExact then
      begin
        Check(LClip.SampleAt(0, AChannel) = AValue, 'Exact finite Float32 extremum changed');
      end;
    end;
  finally
    LClip.Free;
    LSynth.Free;
    LGraph.Free;
  end;
end;

var
  LValues: array[0..11] of Double;
  LIndex: Integer;
  LChannel: Integer;
  LMode: Integer;
begin
  LValues[0] := 0;
  LValues[1] := 1;
  LValues[2] := -1;
  LValues[3] := MaximumFiniteFloat32;
  LValues[4] := -MaximumFiniteFloat32;
  LValues[5] := MaximumFiniteFloat32 * (1 - 1E-12);
  LValues[6] := -MaximumFiniteFloat32 * (1 - 1E-12);
  LValues[7] := MaximumFiniteFloat32 * (1 + 1E-12);
  LValues[8] := -MaximumFiniteFloat32 * (1 + 1E-12);
  LValues[9] := NaN;
  LValues[10] := Infinity;
  LValues[11] := NegInfinity;
  for LMode := 0 to 1 do
  begin
    for LChannel := 0 to 1 do
    begin
      for LIndex := 0 to High(LValues) do
      begin
        Exercise(LValues[LIndex], LIndex >= 7, LIndex in [3, 4],
          LChannel, LMode = 1);
      end;
    end;
  end;
  WriteLn('bus/scheduled portability: ', GChecks,
    ' checks; 48 scalar/channel/render cases including terminal reset');
end.
