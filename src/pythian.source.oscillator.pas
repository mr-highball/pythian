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
unit pythian.source.oscillator;

{$mode delphi}
{$H+}

interface

uses
  pythian.source,
  pythian.oscillator,
  pythian.additive;

type
  TWaveSourceFactory = class(TAudioSourceFactory)
  strict private
    FShape: TWaveShape;
    FQuality: TOscillatorQuality;
  public
    constructor Create(const AShape: TWaveShape; const AQuality: TOscillatorQuality = oqPolynomial);
    function CreateSource(const ASampleRate: Integer; const ASeed: Cardinal): TAudioSource; override;
    function FrameCost(const ASampleRate: Integer): Integer; override;
    function Channels: Integer; override;
  end;

  TAdditiveSourceFactory = class(TAudioSourceFactory)
  strict private
    FPartials: TAdditivePartials;
  public
    constructor Create(const APartials: TAdditivePartials);
    function CreateSource(const ASampleRate: Integer; const ASeed: Cardinal): TAudioSource; override;
    function FrameCost(const ASampleRate: Integer): Integer; override;
    function Channels: Integer; override;
  end;

  TFmSourceMode = (fsmFrequency, fsmPhase);
  TFmSourceFactory = class(TAudioSourceFactory)
  strict private
    FMode: TFmSourceMode;
    FRatio: Double;
    FDepth: Double;
  public
    { Modulator = played frequency * ratio. Depth is Hz for FM, radians for PM. }
    constructor Create(const AMode: TFmSourceMode; const AModulatorRatio, ADepth: Double);
    function CreateSource(const ASampleRate: Integer; const ASeed: Cardinal): TAudioSource; override;
    procedure ValidateRange(const AMinimumHz, AMaximumHz: Double;
      const ASampleRate: Integer); override;
    function FrameCost(const ASampleRate: Integer): Integer; override;
    function Channels: Integer; override;
  end;

implementation

uses
  pythian.audio,
  pythian.modulation;

type
  TWaveSource = class(TAudioSource)
  private
    FOscillator: TOscillator;
    FShape: TWaveShape;
    FSeed: Cardinal;
  public
    constructor Create(const ARate: Integer; const ASeed: Cardinal;
      const AShape: TWaveShape; const AQuality: TOscillatorQuality);
    destructor Destroy; override;
    procedure Reset; override;
    function ReadFrame(const AFrequencyHz: Double; out ALeft, ARight: Double): Boolean; override;
  end;

  TAdditiveSource = class(TAudioSource)
  private
    FOscillator: TAdditiveOscillator;
  public
    constructor Create(const ARate: Integer; const APartials: TAdditivePartials);
    destructor Destroy; override;
    procedure Reset; override;
    function ReadFrame(const AFrequencyHz: Double; out ALeft, ARight: Double): Boolean; override;
  end;

  TFmSource = class(TAudioSource)
  private
    FOscillator: TFmOscillator;
    FMode: TFmSourceMode;
    FRatio: Double;
    FDepth: Double;
  public
    constructor Create(const ARate: Integer; const AMode: TFmSourceMode;
      const ARatio, ADepth: Double);
    destructor Destroy; override;
    procedure Reset; override;
    function ReadFrame(const AFrequencyHz: Double; out ALeft, ARight: Double): Boolean; override;
  end;

constructor TWaveSource.Create(const ARate: Integer; const ASeed: Cardinal;
  const AShape: TWaveShape; const AQuality: TOscillatorQuality);
begin
  inherited Create;
  FShape := AShape;
  FSeed := ASeed;
  FOscillator := TOscillator.Create(ARate, ASeed, AQuality);
end;

destructor TWaveSource.Destroy;
begin
  FOscillator.Free;
  inherited;
end;

procedure TWaveSource.Reset;
begin
  FOscillator.Reset(FSeed);
end;

function TWaveSource.ReadFrame(const AFrequencyHz: Double; out ALeft, ARight: Double): Boolean;
begin
  ALeft := FOscillator.Next(FShape, AFrequencyHz);
  ARight := ALeft;
  Result := True;
end;

constructor TWaveSourceFactory.Create(const AShape: TWaveShape; const AQuality: TOscillatorQuality);
begin
  inherited Create;
  if not (AShape in [wsSine, wsTriangle, wsSaw, wsSquare, wsNoise]) or
    not (AQuality in [oqNaive, oqPolynomial]) then
  begin
    raise EAudio.Create('Unknown oscillator shape or quality');
  end;
  FShape := AShape;
  FQuality := AQuality;
end;

function TWaveSourceFactory.CreateSource(const ASampleRate: Integer;
  const ASeed: Cardinal): TAudioSource;
begin
  Result := TWaveSource.Create(ASampleRate, ASeed, FShape, FQuality);
end;

function TWaveSourceFactory.FrameCost(const ASampleRate: Integer): Integer;
begin
  ValidateAudioFormat(ASampleRate, 1);
  Result := 1;
end;

function TWaveSourceFactory.Channels: Integer;
begin
  Result := 1;
end;

constructor TAdditiveSource.Create(const ARate: Integer; const APartials: TAdditivePartials);
begin
  inherited Create;
  FOscillator := TAdditiveOscillator.Create(ARate, APartials);
end;

destructor TAdditiveSource.Destroy;
begin
  FOscillator.Free;
  inherited;
end;

procedure TAdditiveSource.Reset;
begin
  FOscillator.Reset;
end;

function TAdditiveSource.ReadFrame(const AFrequencyHz: Double; out ALeft, ARight: Double): Boolean;
begin
  ALeft := FOscillator.Next(AFrequencyHz);
  ARight := ALeft;
  Result := True;
end;

constructor TAdditiveSourceFactory.Create(const APartials: TAdditivePartials);
var
  LValidation: TAdditiveOscillator;
begin
  inherited Create;
  LValidation := TAdditiveOscillator.Create(48000, APartials);
  LValidation.Free;
  FPartials := Copy(APartials);
end;

function TAdditiveSourceFactory.CreateSource(const ASampleRate: Integer;
  const ASeed: Cardinal): TAudioSource;
begin
  Result := TAdditiveSource.Create(ASampleRate, FPartials);
end;

function TAdditiveSourceFactory.FrameCost(const ASampleRate: Integer): Integer;
begin
  ValidateAudioFormat(ASampleRate, 1);
  Result := Length(FPartials);
end;

function TAdditiveSourceFactory.Channels: Integer;
begin
  Result := 1;
end;

constructor TFmSource.Create(const ARate: Integer; const AMode: TFmSourceMode;
  const ARatio, ADepth: Double);
begin
  inherited Create;
  FOscillator := TFmOscillator.Create(ARate);
  FMode := AMode;
  FRatio := ARatio;
  FDepth := ADepth;
end;

destructor TFmSource.Destroy;
begin
  FOscillator.Free;
  inherited;
end;

procedure TFmSource.Reset;
begin
  FOscillator.Reset;
end;

function TFmSource.ReadFrame(const AFrequencyHz: Double; out ALeft, ARight: Double): Boolean;
begin
  RequireFinite(AFrequencyHz, 'Source frequency');
  if AFrequencyHz < 0 then
  begin
    raise EAudio.Create('Source frequency must be nonnegative');
  end;
  if FMode = fsmFrequency then
  begin
    ALeft := FOscillator.NextFm(AFrequencyHz, AFrequencyHz * FRatio, FDepth);
  end
  else
  begin
    ALeft := FOscillator.NextPm(AFrequencyHz, AFrequencyHz * FRatio, FDepth);
  end;
  ARight := ALeft;
  Result := True;
end;

constructor TFmSourceFactory.Create(const AMode: TFmSourceMode;
  const AModulatorRatio, ADepth: Double);
begin
  inherited Create;
  RequireFinite(AModulatorRatio, 'Modulator ratio');
  RequireFinite(ADepth, 'Modulation depth');
  if not (AMode in [fsmFrequency, fsmPhase]) or
    (AModulatorRatio < 0) or (AModulatorRatio > 256) or
    ((AMode = fsmPhase) and (Abs(ADepth) > MaximumPmIndex)) or
    ((AMode = fsmFrequency) and (Abs(ADepth) > MaximumSampleRate)) then
  begin
    raise EAudio.Create('FM source definition outside mode/ratio/depth bounds');
  end;
  FMode := AMode;
  FRatio := AModulatorRatio;
  FDepth := ADepth;
end;

procedure TFmSourceFactory.ValidateRange(const AMinimumHz, AMaximumHz: Double;
  const ASampleRate: Integer);
begin
  inherited;
  if (AMaximumHz * FRatio >= ASampleRate * 0.5) or
    ((FMode = fsmFrequency) and (Abs(FDepth) >= ASampleRate * 0.5 - AMaximumHz)) then
  begin
    raise EAudio.Create('FM source range exceeds carrier/modulator limits');
  end;
end;

function TFmSourceFactory.CreateSource(const ASampleRate: Integer;
  const ASeed: Cardinal): TAudioSource;
begin
  ValidateRange(0, 0, ASampleRate);
  Result := TFmSource.Create(ASampleRate, FMode, FRatio, FDepth);
end;

function TFmSourceFactory.FrameCost(const ASampleRate: Integer): Integer;
begin
  ValidateAudioFormat(ASampleRate, 1);
  Result := 2;
end;

function TFmSourceFactory.Channels: Integer;
begin
  Result := 1;
end;

end.

