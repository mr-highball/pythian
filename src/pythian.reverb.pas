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

unit pythian.reverb;

{$mode delphi}
{$H+}

interface

uses
  pythian.delay,
  pythian.effects;

const
  ReverbCombCount = 4;
  ReverbDiffuserCount = 2;

type
  TReverbSettings = record
    CombFrames: array[0..1, 0..ReverbCombCount - 1] of Integer;
    DiffuserFrames: array[0..1, 0..ReverbDiffuserCount - 1] of Integer;
    DecaySeconds: Double;
    Damping: Double;
    Diffusion: Double;
    DryGain: Double;
    WetGain: Double;
    Width: Double;
  end;

  { Four parallel damped combs and two true allpasses per channel. Owns all
    histories and copies settings. Process allocates no memory; both channels
    commit together. Reset clears the tail. Feed zeros to continue a tail.
    Independent stereo excitation; Width affects only the final wet mix. }
  TReverbEffect = class(TAudioEffect)
  strict private
    FSettings: TReverbSettings;
    FComb: array[0..1, 0..ReverbCombCount - 1] of TFractionalDelayLine;
    FDiffuser: array[0..1, 0..ReverbDiffuserCount - 1] of TFractionalDelayLine;
    FFeedback: array[0..1, 0..ReverbCombCount - 1] of Double;
    FDamped: array[0..1, 0..ReverbCombCount - 1] of Double;
  public
    constructor Create(const ASampleRate: Integer; const ASettings: TReverbSettings);
    destructor Destroy; override;
    procedure Reset; override;
    procedure Process(const ALeft, ARight: Double;
      out AOutputLeft, AOutputRight: Double); override;
    function FrameCost: Integer; override;
  end;

{ Authored starting delays scaled to sample rate; no measured room model.
  DecaySeconds controls low-frequency comb feedback, not exact network RT60. }
function DefaultReverbSettings(const ASampleRate: Integer): TReverbSettings;

implementation

uses
  Math,
  pythian.audio,
  pythian.dynamics;

procedure CheckMagnitude(const AValue: Double);
begin
  RequireFinite(AValue, 'Reverb sample');
  if Abs(AValue) > MaximumDynamicsMagnitude then
  begin
    raise EAudio.Create('Reverb sample exceeds magnitude bound');
  end;
end;

function DefaultReverbSettings(const ASampleRate: Integer): TReverbSettings;
const
  CCombMilliseconds: array[0..3] of Double = (29.7, 37.1, 41.1, 43.7);
  CDiffuserMilliseconds: array[0..1] of Double = (5.1, 1.7);
var
  LChannel: Integer;
  LIndex: Integer;
begin
  ValidateAudioFormat(ASampleRate, 2);
  Result := Default(TReverbSettings);
  for LChannel := 0 to 1 do
  begin
    for LIndex := 0 to ReverbCombCount - 1 do
    begin
      Result.CombFrames[LChannel, LIndex] :=
        Max(1, Floor(ASampleRate * (CCombMilliseconds[LIndex] + 1.3 * LChannel) / 1000 + 0.5));
    end;
    for LIndex := 0 to ReverbDiffuserCount - 1 do
    begin
      Result.DiffuserFrames[LChannel, LIndex] :=
        Max(1, Floor(ASampleRate * (CDiffuserMilliseconds[LIndex] + 0.4 * LChannel) / 1000 + 0.5));
    end;
  end;
  Result.DecaySeconds := 1.5;
  Result.Damping := 0.35;
  Result.Diffusion := 0.6;
  Result.DryGain := 1;
  Result.WetGain := 0.3;
  Result.Width := 1;
end;

constructor TReverbEffect.Create(const ASampleRate: Integer; const ASettings: TReverbSettings);
var
  LChannel: Integer;
  LIndex: Integer;
  LMaximum: Integer;
begin
  inherited Create(ASampleRate);
  RequireFinite(ASettings.DecaySeconds, 'Reverb decay');
  RequireFinite(ASettings.Damping, 'Reverb damping');
  RequireFinite(ASettings.Diffusion, 'Reverb diffusion');
  RequireFinite(ASettings.DryGain, 'Reverb dry gain');
  RequireFinite(ASettings.WetGain, 'Reverb wet gain');
  RequireFinite(ASettings.Width, 'Reverb width');
  if (ASettings.DecaySeconds < 0.05) or (ASettings.DecaySeconds > 30) or
    (ASettings.Damping < 0) or (ASettings.Damping > 0.99) or
    (Abs(ASettings.Diffusion) > 0.9) or
    (ASettings.DryGain < 0) or (ASettings.DryGain > 16) or
    (ASettings.WetGain < 0) or (ASettings.WetGain > 16) or
    (ASettings.Width < 0) or (ASettings.Width > 1) then
  begin
    raise EAudio.Create('Invalid reverb decay, damping, diffusion, mix or width');
  end;
  LMaximum := Max(1, ASampleRate div 2);
  for LChannel := 0 to 1 do
  begin
    for LIndex := 0 to ReverbCombCount - 1 do
    begin
      if (ASettings.CombFrames[LChannel, LIndex] < 1) or
        (ASettings.CombFrames[LChannel, LIndex] > LMaximum) then
      begin
        raise EAudio.Create('Reverb comb delay exceeds half-second capacity');
      end;
    end;
    for LIndex := 0 to ReverbDiffuserCount - 1 do
    begin
      if (ASettings.DiffuserFrames[LChannel, LIndex] < 1) or
        (ASettings.DiffuserFrames[LChannel, LIndex] > LMaximum) then
      begin
        raise EAudio.Create('Reverb diffuser delay exceeds half-second capacity');
      end;
    end;
  end;
  FSettings := ASettings;
  for LChannel := 0 to 1 do
  begin
    for LIndex := 0 to ReverbCombCount - 1 do
    begin
      FFeedback[LChannel, LIndex] := Power(10,
        -3 * (ASettings.CombFrames[LChannel, LIndex] / ASampleRate) / ASettings.DecaySeconds);
      FComb[LChannel, LIndex] :=
        TFractionalDelayLine.Create(ASettings.CombFrames[LChannel, LIndex]);
    end;
    for LIndex := 0 to ReverbDiffuserCount - 1 do
    begin
      FDiffuser[LChannel, LIndex] :=
        TFractionalDelayLine.Create(ASettings.DiffuserFrames[LChannel, LIndex]);
    end;
  end;
end;

destructor TReverbEffect.Destroy;
var
  LChannel: Integer;
  LIndex: Integer;
begin
  for LChannel := 0 to 1 do
  begin
    for LIndex := 0 to ReverbCombCount - 1 do
    begin
      FComb[LChannel, LIndex].Free;
    end;
    for LIndex := 0 to ReverbDiffuserCount - 1 do
    begin
      FDiffuser[LChannel, LIndex].Free;
    end;
  end;
  inherited Destroy;
end;

procedure TReverbEffect.Reset;
var
  LChannel: Integer;
  LIndex: Integer;
begin
  for LChannel := 0 to 1 do
  begin
    for LIndex := 0 to ReverbCombCount - 1 do
    begin
      FComb[LChannel, LIndex].Reset;
      FDamped[LChannel, LIndex] := 0;
    end;
    for LIndex := 0 to ReverbDiffuserCount - 1 do
    begin
      FDiffuser[LChannel, LIndex].Reset;
    end;
  end;
end;

procedure TReverbEffect.Process(const ALeft, ARight: Double;
  out AOutputLeft, AOutputRight: Double);
var
  LInput: array[0..1] of Double;
  LWet: array[0..1] of Double;
  LOutput: array[0..1] of Double;
  LNextComb: array[0..1, 0..ReverbCombCount - 1] of Double;
  LNextDamped: array[0..1, 0..ReverbCombCount - 1] of Double;
  LNextDiffuser: array[0..1, 0..ReverbDiffuserCount - 1] of Double;
  LDelayed: Double;
  LDirect: Double;
  LCross: Double;
  LChannel: Integer;
  LIndex: Integer;
begin
  CheckMagnitude(ALeft);
  CheckMagnitude(ARight);
  LInput[0] := ALeft;
  LInput[1] := ARight;
  for LChannel := 0 to 1 do
  begin
    LWet[LChannel] := 0;
    for LIndex := 0 to ReverbCombCount - 1 do
    begin
      LDelayed := FComb[LChannel, LIndex].Read(FSettings.CombFrames[LChannel, LIndex]);
      LNextDamped[LChannel, LIndex] := (1 - FSettings.Damping) * LDelayed +
        FSettings.Damping * FDamped[LChannel, LIndex];
      LNextComb[LChannel, LIndex] := LInput[LChannel] +
        FFeedback[LChannel, LIndex] * LNextDamped[LChannel, LIndex];
      CheckMagnitude(LNextDamped[LChannel, LIndex]);
      CheckMagnitude(LNextComb[LChannel, LIndex]);
      LWet[LChannel] := LWet[LChannel] + LDelayed / ReverbCombCount;
    end;
    for LIndex := 0 to ReverbDiffuserCount - 1 do
    begin
      LDelayed := FDiffuser[LChannel, LIndex].Read(FSettings.DiffuserFrames[LChannel, LIndex]);
      LNextDiffuser[LChannel, LIndex] := LWet[LChannel] + FSettings.Diffusion * LDelayed;
      LWet[LChannel] := LDelayed - FSettings.Diffusion * LNextDiffuser[LChannel, LIndex];
      CheckMagnitude(LNextDiffuser[LChannel, LIndex]);
      CheckMagnitude(LWet[LChannel]);
    end;
  end;
  LDirect := (1 + FSettings.Width) / 2;
  LCross := (1 - FSettings.Width) / 2;
  for LChannel := 0 to 1 do
  begin
    LOutput[LChannel] := FSettings.DryGain * LInput[LChannel] +
      FSettings.WetGain * (LDirect * LWet[LChannel] + LCross * LWet[1 - LChannel]);
    CheckMagnitude(LOutput[LChannel]);
  end;
  { Every value to be pushed has passed validation. No allocation or callbacks
    occur during this commit, so a rejected frame leaves all histories intact. }
  for LChannel := 0 to 1 do
  begin
    for LIndex := 0 to ReverbCombCount - 1 do
    begin
      FComb[LChannel, LIndex].Push(LNextComb[LChannel, LIndex]);
      FDamped[LChannel, LIndex] := LNextDamped[LChannel, LIndex];
    end;
    for LIndex := 0 to ReverbDiffuserCount - 1 do
    begin
      FDiffuser[LChannel, LIndex].Push(LNextDiffuser[LChannel, LIndex]);
    end;
  end;
  AOutputLeft := LOutput[0];
  AOutputRight := LOutput[1];
end;

function TReverbEffect.FrameCost: Integer;
begin
  Result := 40;
end;

end.
