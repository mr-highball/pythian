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
unit pythian.delay.modulated;

{$mode delphi}
{$H+}

interface

uses
  pythian.automation,
  pythian.delay,
  pythian.effects;

type
  TModulatedDelaySettings = record
    MaximumDelayFrames: Integer;
    Feedback: Double;
    DryGain: Double;
    WetGain: Double;
  end;

  { Independent stereo feedback lines and owning delay-control clones.
    Curves are in frames relative to effect Reset, not note-on. Both channels
    and the control clock commit together after all validation succeeds. }
  TModulatedDelayEffect = class(TAudioEffect)
  strict private
    FSettings: TModulatedDelaySettings;
    FLeft: TFractionalDelayLine;
    FRight: TFractionalDelayLine;
    FLeftDelay: TAutomationCurve;
    FRightDelay: TAutomationCurve;
    FFrame: Int64;
  public
    constructor Create(const ASampleRate: Integer; const ASettings: TModulatedDelaySettings;
      const ALeftDelay, ARightDelay: TAutomationCurve);
    destructor Destroy; override;
    procedure Reset; override;
    procedure Process(const ALeft, ARight: Double;
      out AOutputLeft, AOutputRight: Double); override;
    function FrameCost: Integer; override;
    property ProcessedFrames: Int64 read FFrame;
  end;

implementation

uses
  Math,
  pythian.audio,
  pythian.dynamics;

procedure CheckMagnitude(const AValue: Double);
begin
  RequireFinite(AValue, 'Modulated delay sample');
  if Abs(AValue) > MaximumDynamicsMagnitude then
  begin
    raise EAudio.Create('Modulated delay sample exceeds magnitude bound');
  end;
end;

constructor TModulatedDelayEffect.Create(const ASampleRate: Integer;
  const ASettings: TModulatedDelaySettings; const ALeftDelay, ARightDelay: TAutomationCurve);
begin
  inherited Create(ASampleRate);
  RequireFinite(ASettings.Feedback, 'Modulated delay feedback');
  RequireFinite(ASettings.DryGain, 'Modulated delay dry gain');
  RequireFinite(ASettings.WetGain, 'Modulated delay wet gain');
  if (ASettings.MaximumDelayFrames < 1) or
    (ASettings.MaximumDelayFrames > ASampleRate * 10) or
    (Abs(ASettings.Feedback) >= 1) or
    (ASettings.DryGain < 0) or (ASettings.DryGain > 16) or
    (ASettings.WetGain < 0) or (ASettings.WetGain > 16) or
    (ALeftDelay = nil) or (ARightDelay = nil) then
  begin
    raise EAudio.Create('Invalid modulated delay capacity, feedback, gains or controls');
  end;
  if (ALeftDelay.Minimum < 1) or (ARightDelay.Minimum < 1) or
    (ALeftDelay.Maximum > ASettings.MaximumDelayFrames) or
    (ARightDelay.Maximum > ASettings.MaximumDelayFrames) then
  begin
    raise EAudio.Create('Entire delay-control excursion must fit the allocated history');
  end;
  FSettings := ASettings;
  FLeftDelay := ALeftDelay.Clone;
  FRightDelay := ARightDelay.Clone;
  FLeft := TFractionalDelayLine.Create(ASettings.MaximumDelayFrames);
  FRight := TFractionalDelayLine.Create(ASettings.MaximumDelayFrames);
end;

destructor TModulatedDelayEffect.Destroy;
begin
  FRight.Free;
  FLeft.Free;
  FRightDelay.Free;
  FLeftDelay.Free;
  inherited Destroy;
end;

procedure TModulatedDelayEffect.Reset;
begin
  FLeft.Reset;
  FRight.Reset;
  FFrame := 0;
end;

procedure TModulatedDelayEffect.Process(const ALeft, ARight: Double;
  out AOutputLeft, AOutputRight: Double);
var
  LDelayedLeft: Double;
  LDelayedRight: Double;
  LNextLeft: Double;
  LNextRight: Double;
  LOutputLeft: Double;
  LOutputRight: Double;
begin
  CheckMagnitude(ALeft);
  CheckMagnitude(ARight);
  if FFrame = High(Int64) then
  begin
    raise EAudio.Create('Modulated delay control clock exhausted');
  end;
  LDelayedLeft := FLeft.Read(FLeftDelay.ValueAt(FFrame));
  LDelayedRight := FRight.Read(FRightDelay.ValueAt(FFrame));
  LNextLeft := ALeft + FSettings.Feedback * LDelayedLeft;
  LNextRight := ARight + FSettings.Feedback * LDelayedRight;
  LOutputLeft := FSettings.DryGain * ALeft + FSettings.WetGain * LDelayedLeft;
  LOutputRight := FSettings.DryGain * ARight + FSettings.WetGain * LDelayedRight;
  CheckMagnitude(LNextLeft);
  CheckMagnitude(LNextRight);
  CheckMagnitude(LOutputLeft);
  CheckMagnitude(LOutputRight);
  FLeft.Push(LNextLeft);
  FRight.Push(LNextRight);
  Inc(FFrame);
  AOutputLeft := LOutputLeft;
  AOutputRight := LOutputRight;
end;

function TModulatedDelayEffect.FrameCost: Integer;
begin
  Result := 6 + FLeftDelay.Depth + FRightDelay.Depth;
end;

end.

