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
unit pythian.filter;

{$mode delphi}
{$H+}

interface

type
  TFilterKind = (fkLowPass, fkHighPass);

  TOnePoleFilter = class
  strict private
    FCoefficient: Double;
    FState: Double;
    FKind: TFilterKind;
    FSampleRate: Integer;
  public
    constructor Create(const ASampleRate: Integer; const ACutoffHz: Double;
      const AKind: TFilterKind = fkLowPass);
    procedure Reset;
    { Updates the coefficient while retaining history; rejected input preserves both. }
    procedure SetCutoff(const ACutoffHz: Double);
    function Process(const AInput: Double): Double;
  end;

implementation

uses
  Math,
  pythian.audio;

constructor TOnePoleFilter.Create(const ASampleRate: Integer;
  const ACutoffHz: Double; const AKind: TFilterKind);
begin
  inherited Create;
  ValidateAudioFormat(ASampleRate, 1);
  FSampleRate := ASampleRate;
  if not (AKind in [fkLowPass, fkHighPass]) then
  begin
    raise EAudio.Create('Unknown filter kind');
  end;
  FKind := AKind;
  SetCutoff(ACutoffHz);
end;

procedure TOnePoleFilter.SetCutoff(const ACutoffHz: Double);
begin
  RequireFinite(ACutoffHz, 'Cutoff');
  if (ACutoffHz <= 0) or (ACutoffHz >= FSampleRate * 0.5) then
  begin
    raise EAudio.Create('Cutoff must be positive and below Nyquist');
  end;
  FCoefficient := 1 - Exp(-2 * Pi * ACutoffHz / FSampleRate);
end;

procedure TOnePoleFilter.Reset;
begin
  FState := 0;
end;

function TOnePoleFilter.Process(const AInput: Double): Double;
begin
  RequireFinite(AInput, 'Filter input');
  FState := FCoefficient * AInput + (1 - FCoefficient) * FState;
  Result := FState;
  if FKind = fkHighPass then
  begin
    Result := AInput - FState;
  end;
end;

end.
