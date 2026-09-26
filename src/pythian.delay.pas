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
unit pythian.delay;

{$mode delphi}
{$H+}

interface

type
  { Read-before-push delay line. Delay is 1..MaximumFrames; fractional reads
    linearly interpolate adjacent past samples. Reads never advance history. }
  TFractionalDelayLine = class
  strict private
    FBuffer: array of Double;
    FPosition: Integer;
    FMaximumFrames: Integer;
  public
    constructor Create(const AMaximumFrames: Integer);
    procedure Reset;
    function Read(const ADelayFrames: Double): Double;
    procedure Push(const AInput: Double);
    property MaximumFrames: Integer read FMaximumFrames;
  end;

  TDelay = class
  strict private
    FLine: TFractionalDelayLine;
    FDelayFrames: Integer;
    FFeedback: Double;
    FWet: Double;
  public
    constructor Create(const ADelayFrames: Integer; const AFeedback, AWet: Double);
    destructor Destroy; override;
    procedure Reset;
    function Process(const AInput: Double): Double;
  end;

implementation

uses
  Math,
  pythian.audio;

constructor TFractionalDelayLine.Create(const AMaximumFrames: Integer);
begin
  inherited Create;
  if (AMaximumFrames < 1) or (AMaximumFrames > MaximumSampleRate * 10) then
  begin
    raise EAudio.Create('Fractional delay capacity must be 1..3840000 frames');
  end;
  FMaximumFrames := AMaximumFrames;
  SetLength(FBuffer, AMaximumFrames + 1);
end;

procedure TFractionalDelayLine.Reset;
var
  LIndex: Integer;
begin
  for LIndex := 0 to High(FBuffer) do
  begin
    FBuffer[LIndex] := 0;
  end;
  FPosition := 0;
end;

function TFractionalDelayLine.Read(const ADelayFrames: Double): Double;
var
  LWhole: Integer;
  LRecent: Integer;
  LOlder: Integer;
  LFraction: Double;
begin
  RequireFinite(ADelayFrames, 'Fractional delay distance');
  if (ADelayFrames < 1) or (ADelayFrames > FMaximumFrames) then
  begin
    raise EAudio.Create('Fractional delay distance exceeds allocated history');
  end;
  LWhole := Trunc(ADelayFrames);
  LFraction := ADelayFrames - LWhole;
  LRecent := FPosition - LWhole;
  if LRecent < 0 then
  begin
    Inc(LRecent, Length(FBuffer));
  end;
  if LFraction = 0 then
  begin
    Exit(FBuffer[LRecent]);
  end;
  LOlder := LRecent - 1;
  if LOlder < 0 then
  begin
    Inc(LOlder, Length(FBuffer));
  end;
  Result := (1 - LFraction) * FBuffer[LRecent] + LFraction * FBuffer[LOlder];
  RequireFinite(Result, 'Fractional delay interpolation');
end;

procedure TFractionalDelayLine.Push(const AInput: Double);
begin
  RequireFinite(AInput, 'Fractional delay input');
  FBuffer[FPosition] := AInput;
  Inc(FPosition);
  if FPosition = Length(FBuffer) then
  begin
    FPosition := 0;
  end;
end;

constructor TDelay.Create(const ADelayFrames: Integer; const AFeedback, AWet: Double);
begin
  inherited Create;
  RequireFinite(AFeedback, 'Feedback');
  RequireFinite(AWet, 'Wet gain');
  if (ADelayFrames < 1) or (ADelayFrames > MaximumSampleRate * 10) or
    (Abs(AFeedback) >= 1) or (AWet < 0) or (AWet > 1) then
  begin
    raise EAudio.Create('Invalid delay length, feedback, or wet gain');
  end;
  FLine := TFractionalDelayLine.Create(ADelayFrames);
  FDelayFrames := ADelayFrames;
  FFeedback := AFeedback;
  FWet := AWet;
end;

destructor TDelay.Destroy;
begin
  FLine.Free;
  inherited Destroy;
end;

procedure TDelay.Reset;
begin
  FLine.Reset;
end;

function TDelay.Process(const AInput: Double): Double;
var
  LDelayed: Double;
  LNext: Double;
begin
  RequireFinite(AInput, 'Delay input');
  LDelayed := FLine.Read(FDelayFrames);
  LNext := AInput + LDelayed * FFeedback;
  Result := AInput + LDelayed * FWet;
  RequireFinite(LNext, 'Delay feedback result');
  RequireFinite(Result, 'Delay output');
  FLine.Push(LNext);
end;

end.
