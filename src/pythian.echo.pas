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
unit pythian.echo;

{$mode delphi}
{$H+}

interface

uses
  pythian.effects,
  pythian.biquad;

type
  TEchoSettings = record
    DelayFrames: Integer;
    CutoffHz: Double;
    Feedback: Double;
    DryGain: Double;
    WetGain: Double;
  end;

  { Independent stereo delay lines, followed by a fixed Butterworth low-pass.
    Filtered delay feeds both the wet return and the feedback input.
    Processing failure after filter advancement requires Reset. }
  TEchoEffect = class(TAudioEffect)
  strict private
    FSettings: TEchoSettings;
    FLeft: array of Double;
    FRight: array of Double;
    FPosition: Integer;
    FFilter: TBiquadFilter;
    FFailed: Boolean;
  public
    constructor Create(const ASampleRate: Integer; const ASettings: TEchoSettings);
    destructor Destroy; override;
    procedure Reset; override;
    procedure Process(const ALeft, ARight: Double;
      out AOutputLeft, AOutputRight: Double); override;
    function FrameCost: Integer; override;
    property Failed: Boolean read FFailed;
  end;

function DefaultEchoSettings(const ASampleRate: Integer): TEchoSettings;

implementation

uses
  Math,
  pythian.audio,
  pythian.dynamics;

procedure CheckMagnitude(const AValue: Double);
begin
  RequireFinite(AValue, 'Echo sample');
  if Abs(AValue) > MaximumDynamicsMagnitude then
  begin
    raise EAudio.Create('Echo sample exceeds magnitude bound');
  end;
end;

function DefaultEchoSettings(const ASampleRate: Integer): TEchoSettings;
begin
  ValidateAudioFormat(ASampleRate, 2);
  { Exact ceiling of three eighths of a second, including very low rates. }
  Result.DelayFrames := (ASampleRate * 3 + 7) div 8;
  Result.CutoffHz := Min(1800, ASampleRate * 0.25);
  Result.Feedback := 0.23;
  Result.DryGain := 1;
  Result.WetGain := 0.23;
end;

constructor TEchoEffect.Create(const ASampleRate: Integer; const ASettings: TEchoSettings);
var
  LFilter: TBiquadSettings;
begin
  inherited Create(ASampleRate);
  RequireFinite(ASettings.Feedback, 'Echo feedback');
  RequireFinite(ASettings.DryGain, 'Echo dry gain');
  RequireFinite(ASettings.WetGain, 'Echo wet gain');
  if (ASettings.DelayFrames < 1) or (ASettings.DelayFrames > ASampleRate * 10) or
    (Abs(ASettings.Feedback) >= 1) or
    (ASettings.DryGain < 0) or (ASettings.DryGain > 16) or
    (ASettings.WetGain < 0) or (ASettings.WetGain > 16) then
  begin
    raise EAudio.Create('Invalid echo delay, feedback, or gains');
  end;
  LFilter := DefaultBiquadSettings;
  LFilter.FrequencyHz := ASettings.CutoffHz;
  FFilter := TBiquadFilter.Create(ASampleRate, LFilter, 2);
  SetLength(FLeft, ASettings.DelayFrames);
  SetLength(FRight, ASettings.DelayFrames);
  FSettings := ASettings;
end;

destructor TEchoEffect.Destroy;
begin
  FFilter.Free;
  inherited;
end;

procedure TEchoEffect.Reset;
var
  LIndex: Integer;
begin
  FFailed := True;
  for LIndex := 0 to High(FLeft) do
  begin
    FLeft[LIndex] := 0;
    FRight[LIndex] := 0;
  end;
  FPosition := 0;
  FFilter.Reset;
  FFailed := False;
end;

procedure TEchoEffect.Process(const ALeft, ARight: Double;
  out AOutputLeft, AOutputRight: Double);
var
  LFilteredLeft: Double;
  LFilteredRight: Double;
  LNextLeft: Double;
  LNextRight: Double;
  LOutputLeft: Double;
  LOutputRight: Double;
begin
  if FFailed then
  begin
    raise EAudio.Create('Echo requires Reset after failure');
  end;
  CheckMagnitude(ALeft);
  CheckMagnitude(ARight);
  try
    FFilter.ProcessStereo(FLeft[FPosition], FRight[FPosition],
      LFilteredLeft, LFilteredRight);
    LNextLeft := ALeft + FSettings.Feedback * LFilteredLeft;
    LNextRight := ARight + FSettings.Feedback * LFilteredRight;
    LOutputLeft := FSettings.DryGain * ALeft + FSettings.WetGain * LFilteredLeft;
    LOutputRight := FSettings.DryGain * ARight + FSettings.WetGain * LFilteredRight;
    CheckMagnitude(LNextLeft);
    CheckMagnitude(LNextRight);
    CheckMagnitude(LOutputLeft);
    CheckMagnitude(LOutputRight);
    FLeft[FPosition] := LNextLeft;
    FRight[FPosition] := LNextRight;
    Inc(FPosition);
    if FPosition = Length(FLeft) then
    begin
      FPosition := 0;
    end;
    AOutputLeft := LOutputLeft;
    AOutputRight := LOutputRight;
  except
    FFailed := True;
    raise;
  end;
end;

function TEchoEffect.FrameCost: Integer;
begin
  Result := 6;
end;

end.

