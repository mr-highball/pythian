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
unit pythian.synth;

{$mode delphi}
{$H+}

interface

uses
  pythian.audio,
  pythian.automation,
  pythian.source,
  pythian.biquad,
  pythian.oscillator,
  pythian.envelope,
  pythian.filter;

const
  SynthesisVersion = 1;
  MaximumRenderVisits = 100000000;
  MaximumToneEvents = 65536;

type
  TVoiceFilterModel = (vfmOnePole, vfmBiquad);
  { Optional immutable curves borrowed for synchronous rendering. Frame zero is
    note-on. Nil uses the voice/tone value; gain is a multiplier and cents add
    to the selected base frequency. Pan/cutoff/frequency curves are absolute. }
  TVoiceAutomation = record
    FrequencyHz: TAutomationCurve;
    PitchCents: TAutomationCurve;
    GainMultiplier: TAutomationCurve;
    Pan: TAutomationCurve;
    CutoffHz: TAutomationCurve;
  end;

  TSynthVoice = record
    Shape: TWaveShape;
    OscillatorQuality: TOscillatorQuality;
    Envelope: TAdsr;
    { Optional borrowed definition replacing ADSR; playing/scheduled notes clone it. }
    GateEnvelope: TGateEnvelope;
    CutoffHz: Double;
    FilterKind: TFilterKind;
    FilterModel: TVoiceFilterModel;
    BiquadKind: TBiquadKind;
    BiquadQ: Double;
    BiquadGainDb: Double;
    Pan: Double;
    Gain: Double;
    Automation: TVoiceAutomation;
    { Borrowed reusable definition; nil uses Shape/OscillatorQuality. }
    SourceFactory: TAudioSourceFactory;
  end;

  TTone = record
    StartSeconds: Double;
    GateSeconds: Double;
    FrequencyHz: Double;
    Velocity: Double;
    Voice: TSynthVoice;
    Seed: Cardinal;
  end;
  TTones = array of TTone;

  TFrameTone = record
    StartFrame: Int64;
    GateFrames: Int64;
    FrequencyHz: Double;
    Velocity: Double;
    Voice: TSynthVoice;
    Seed: Cardinal;
  end;
  TFrameTones = array of TFrameTone;


  { Shared stateful note renderer. Automation is copied; SourceFactory is borrowed. }
  TPlayingTone = class
  private
    type
      TFilter = class
      private
        FOnePole: TOnePoleFilter;
        FBiquad: TBiquadFilter;
      public
        constructor Create(const ASampleRate: Integer; const AVoice: TSynthVoice);
        destructor Destroy; override;
        procedure SetCutoff(const ACutoffHz: Double);
        function Process(const AInput: Double): Double;
      end;
  private
    FTone: TTone;
    FSampleRate: Integer;
    FFrame: Int64;
    FGateFrames: Int64;
    FFrameCount: Int64;
    FSource: TAudioSource;
    FEnvelope: TGateEnvelope;
    FOscillator: TOscillator;
    FFilter: TFilter;
    FRightFilter: TFilter;
    FLeft: Double;
    FRight: Double;
    FCutoff: Double;
    FNoteOff: Boolean;
    FFailed: Boolean;
    procedure Initialize(const ASampleRate: Integer; const ATone: TTone;
      const AGateFrames, AFrameCount: Int64);
    procedure NotifyGate;
    function ReadValues(out AValue, ARightValue, ALeftPan, ARightPan: Double): Boolean;
    function GetFinished: Boolean;
  public
    constructor Create(const ASampleRate: Integer; const ATone: TFrameTone);
    { Bounded offline compatibility: fractional envelope gate, integer source gate/end. }
    constructor CreatePrepared(const ASampleRate: Integer; const ATone: TTone;
      const AGateFrames, AFrameCount: Int64);
    destructor Destroy; override;
    procedure Release;
    function ReadFrame(out ALeft, ARight: Double): Boolean;
    property Frame: Int64 read FFrame;
    property FrameCount: Int64 read FFrameCount;
    property Finished: Boolean read GetFinished;
    property Failed: Boolean read FFailed;
  end;

{ Voice duration is at most one day; absolute starts use checked Int64 frames. }
function ValidateFrameTone(const ATone: TFrameTone; const ASampleRate: Integer): Int64;
{ Policy work: source plus gate envelope and each evaluated automation curve.
  Scheduling reserves a separate 16 units for voice processing overhead. }
function SynthFrameCost(const AVoice: TSynthVoice; const ASampleRate: Integer): Integer;
function SynthReleaseFrames(const AVoice: TSynthVoice; const ASampleRate: Integer): Int64;

function DefaultSynthVoice: TSynthVoice;
{ Offline stereo rendering: per-note phase/filter state, equal-power pan,
  explicit seed. Output length includes release, and silence may be appended. }
function RenderTones(const ATones: TTones; const ASampleRate: Integer;
  const AMinimumSeconds: Double = 0): TAudioClip;
{ Exact integer placement and gate duration; release alone rounds up to frames. }
function RenderFrameTones(const ATones: TFrameTones; const ASampleRate: Integer;
  const AMinimumFrames: Int64 = 0): TAudioClip;

implementation

uses
  Math,
  pythian.time;

function DefaultSynthVoice: TSynthVoice;
begin
  Result.Shape := wsTriangle;
  Result.OscillatorQuality := oqNaive;
  Result.Envelope := DefaultAdsr;
  Result.GateEnvelope := nil;
  Result.CutoffHz := 1800;
  Result.FilterKind := fkLowPass;
  Result.FilterModel := vfmOnePole;
  Result.BiquadKind := bkLowPass;
  Result.BiquadQ := Sqrt(0.5);
  Result.BiquadGainDb := 0;
  Result.Pan := 0;
  Result.Gain := 0.32;
  Result.Automation.FrequencyHz := nil;
  Result.Automation.PitchCents := nil;
  Result.Automation.GainMultiplier := nil;
  Result.Automation.Pan := nil;
  Result.Automation.CutoffHz := nil;
  Result.SourceFactory := nil;
end;

type
  TPreparedTone = record
    Tone: TTone;
    StartFrame: Integer;
    FrameCount: Integer;
    GateFrames: Integer;
  end;
  TPreparedTones = array of TPreparedTone;

function VoiceBiquadSettings(const AVoice: TSynthVoice; const AFrequency: Double): TBiquadSettings;
begin
  Result.Kind := AVoice.BiquadKind;
  Result.Q := AVoice.BiquadQ;
  Result.GainDb := AVoice.BiquadGainDb;
  Result.FrequencyHz := AFrequency;
end;

constructor TPlayingTone.TFilter.Create(const ASampleRate: Integer; const AVoice: TSynthVoice);
begin
  inherited Create;
  if AVoice.FilterModel = vfmBiquad then
  begin
    FBiquad := TBiquadFilter.Create(ASampleRate, VoiceBiquadSettings(AVoice, AVoice.CutoffHz));
  end
  else
  begin
    FOnePole := TOnePoleFilter.Create(ASampleRate, AVoice.CutoffHz, AVoice.FilterKind);
  end;
end;

destructor TPlayingTone.TFilter.Destroy;
begin
  FBiquad.Free;
  FOnePole.Free;
  inherited;
end;

procedure TPlayingTone.TFilter.SetCutoff(const ACutoffHz: Double);
begin
  if FBiquad <> nil then
  begin
    FBiquad.SetFrequency(ACutoffHz);
  end
  else
  begin
    FOnePole.SetCutoff(ACutoffHz);
  end;
end;

function TPlayingTone.TFilter.Process(const AInput: Double): Double;
begin
  if FBiquad <> nil then
  begin
    Result := FBiquad.Process(AInput);
  end
  else
  begin
    Result := FOnePole.Process(AInput);
  end;
end;

procedure ValidateCurve(const ACurve: TAutomationCurve; const AMinimum, AMaximum: Double;
  const AOpenMinimum, AOpenMaximum: Boolean; const AName: String);
begin
  if ACurve = nil then
  begin
    Exit;
  end;
  if (ACurve.Minimum < AMinimum) or (ACurve.Maximum > AMaximum) or
    (AOpenMinimum and (ACurve.Minimum = AMinimum)) or
    (AOpenMaximum and (ACurve.Maximum = AMaximum)) then
  begin
    raise EAudio.Create(AName + ' automation outside synthesis range');
  end;
end;

procedure ValidateTone(const ATone: TTone; const ASampleRate: Integer);
var
  LMaximumFrequency: Double;
  LMinimumFrequency: Double;
begin
  if ATone.Voice.GateEnvelope = nil then
  begin
    ValidateAdsr(ATone.Voice.Envelope);
  end
  else
  begin
    SynthReleaseFrames(ATone.Voice, ASampleRate);
  end;
  if (ATone.Voice.SourceFactory = nil) and
    (not (ATone.Voice.Shape in [wsSine, wsTriangle, wsSaw, wsSquare, wsNoise]) or
    not (ATone.Voice.OscillatorQuality in [oqNaive, oqPolynomial])) then
  begin
    raise EAudio.Create('Invalid voice oscillator configuration');
  end;
  if (ATone.Voice.FilterModel = vfmOnePole) and
    not (ATone.Voice.FilterKind in [fkLowPass, fkHighPass]) then
  begin
    raise EAudio.Create('Invalid voice one-pole filter kind');
  end;
  RequireFinite(ATone.FrequencyHz, 'Tone frequency');
  RequireFinite(ATone.Velocity, 'Velocity');
  RequireFinite(ATone.Voice.CutoffHz, 'Cutoff');
  RequireFinite(ATone.Voice.Pan, 'Pan');
  RequireFinite(ATone.Voice.Gain, 'Gain');
  if (ATone.FrequencyHz < 0) or (ATone.FrequencyHz >= ASampleRate * 0.5) or
    (ATone.Velocity < 0) or (ATone.Velocity > 1) or
    (Abs(ATone.Voice.Pan) > 1) or (ATone.Voice.Gain < 0) or
    (ATone.Voice.Gain > 1) or (ATone.Voice.CutoffHz <= 0) or
    (ATone.Voice.CutoffHz >= ASampleRate * 0.5) then
  begin
    raise EAudio.Create('Tone parameters outside synthesis contract');
  end;
  ValidateCurve(ATone.Voice.Automation.FrequencyHz, 0, ASampleRate * 0.5,
    False, True, 'Frequency');
  ValidateCurve(ATone.Voice.Automation.PitchCents, -19200, 19200,
    False, False, 'Pitch');
  ValidateCurve(ATone.Voice.Automation.GainMultiplier, 0, 16,
    False, False, 'Gain');
  ValidateCurve(ATone.Voice.Automation.Pan, -1, 1, False, False, 'Pan');
  ValidateCurve(ATone.Voice.Automation.CutoffHz, 0, ASampleRate * 0.5,
    True, True, 'Cutoff');
  if not (ATone.Voice.FilterModel in [vfmOnePole, vfmBiquad]) then
  begin
    raise EAudio.Create('Unknown voice filter model');
  end;
  if ATone.Voice.FilterModel = vfmBiquad then
  begin
    DesignBiquad(ASampleRate, VoiceBiquadSettings(ATone.Voice, ATone.Voice.CutoffHz));
    if ATone.Voice.Automation.CutoffHz <> nil then
    begin
      DesignBiquad(ASampleRate, VoiceBiquadSettings(ATone.Voice,
        ATone.Voice.Automation.CutoffHz.Minimum));
      DesignBiquad(ASampleRate, VoiceBiquadSettings(ATone.Voice,
        ATone.Voice.Automation.CutoffHz.Maximum));
    end;
  end;
  LMaximumFrequency := ATone.FrequencyHz;
  LMinimumFrequency := ATone.FrequencyHz;
  if ATone.Voice.Automation.FrequencyHz <> nil then
  begin
    LMaximumFrequency := ATone.Voice.Automation.FrequencyHz.Maximum;
    LMinimumFrequency := ATone.Voice.Automation.FrequencyHz.Minimum;
  end;
  if ATone.Voice.Automation.PitchCents <> nil then
  begin
    LMaximumFrequency := FrequencyWithCents(LMaximumFrequency,
      ATone.Voice.Automation.PitchCents.Maximum);
    LMinimumFrequency := FrequencyWithCents(LMinimumFrequency,
      ATone.Voice.Automation.PitchCents.Minimum);
    if LMaximumFrequency >= ASampleRate * 0.5 then
    begin
      raise EAudio.Create('Combined frequency/pitch automation reaches Nyquist');
    end;
  end;
  if ATone.Voice.SourceFactory <> nil then
  begin
    ATone.Voice.SourceFactory.ValidateRange(LMinimumFrequency, LMaximumFrequency, ASampleRate);
  end;
end;


function SynthFrameCost(const AVoice: TSynthVoice; const ASampleRate: Integer): Integer;

  function CurveWork(const ACurve: TAutomationCurve): Integer;
  begin
    Result := 0;
    if ACurve <> nil then
    begin
      { Match the gate-envelope convention. Depth includes the bounded point
        lookup or LFO leaf and every affine evaluation, not CPU cycles. }
      Result := 16 * ACurve.Depth;
    end;
  end;

begin
  ValidateAudioFormat(ASampleRate, 2);
  Result := 1;
  if AVoice.SourceFactory <> nil then
  begin
    ValidateAudioFormat(ASampleRate, AVoice.SourceFactory.Channels);
    Result := AVoice.SourceFactory.FrameCost(ASampleRate);
    if (Result < 1) or (Result > MaximumRenderVisits) then
    begin
      raise EAudio.Create('Source frame cost outside rendering budget');
    end;
  end;
  if AVoice.GateEnvelope <> nil then
  begin
    Inc(Result, AVoice.GateEnvelope.FrameCost);
  end;
  Inc(Result, CurveWork(AVoice.Automation.FrequencyHz));
  Inc(Result, CurveWork(AVoice.Automation.PitchCents));
  Inc(Result, CurveWork(AVoice.Automation.GainMultiplier));
  Inc(Result, CurveWork(AVoice.Automation.Pan));
  Inc(Result, CurveWork(AVoice.Automation.CutoffHz));
  if Result > MaximumRenderVisits then
  begin
    raise EAudio.Create('Source, envelope and automation frame cost exceed rendering budget');
  end;
end;

function SynthReleaseFrames(const AVoice: TSynthVoice; const ASampleRate: Integer): Int64;
begin
  ValidateAudioFormat(ASampleRate, 2);
  if AVoice.GateEnvelope <> nil then
  begin
    Result := AVoice.GateEnvelope.ReleaseFrames;
  end
  else
  begin
    ValidateAdsr(AVoice.Envelope);
    if AVoice.Envelope.ReleaseSeconds > 86400 then
    begin
      raise EAudio.Create('Voice release exceeds one-day duration bound');
    end;
    Result := SampleFramesFromSeconds(AVoice.Envelope.ReleaseSeconds, ASampleRate);
  end;
  if Result > Int64(ASampleRate) * 86400 then
  begin
    raise EAudio.Create('Voice release exceeds one-day duration bound');
  end;
end;

function FrameToneValue(const ATone: TFrameTone; const ASampleRate: Integer): TTone;
begin
  Result := Default(TTone);
  Result.FrequencyHz := ATone.FrequencyHz;
  Result.Velocity := ATone.Velocity;
  Result.Voice := ATone.Voice;
  Result.Seed := ATone.Seed;
  Result.GateSeconds := ATone.GateFrames / ASampleRate;
end;

function ValidateFrameTone(const ATone: TFrameTone; const ASampleRate: Integer): Int64;
var
  LTone: TTone;
  LMaximumFrames: Int64;
begin
  ValidateAudioFormat(ASampleRate, 2);
  LTone := FrameToneValue(ATone, ASampleRate);
  ValidateTone(LTone, ASampleRate);
  LMaximumFrames := Int64(ASampleRate) * 86400;
  if (ATone.StartFrame < 0) or (ATone.GateFrames < 0) or
    (ATone.GateFrames > LMaximumFrames) then
  begin
    raise EAudio.Create('Voice time exceeds nonnegative one-day duration bound');
  end;
  Result := ATone.GateFrames + SynthReleaseFrames(ATone.Voice, ASampleRate);
  if (Result > LMaximumFrames) or (ATone.StartFrame > High(Int64) - Result) then
  begin
    raise EAudio.Create('Voice end exceeds duration or absolute frame bound');
  end;
end;

function CopyCurve(const ACurve: TAutomationCurve): TAutomationCurve;
begin
  Result := nil;
  if ACurve <> nil then
  begin
    Result := ACurve.Clone;
  end;
end;

procedure TPlayingTone.Initialize(const ASampleRate: Integer; const ATone: TTone;
  const AGateFrames, AFrameCount: Int64);
var
  LChannels: Integer;
begin
  FSampleRate := ASampleRate;
  FTone := ATone;
  FTone.Voice.GateEnvelope := nil;
  FTone.Voice.Automation := Default(TVoiceAutomation);
  FTone.Voice.Automation.FrequencyHz := CopyCurve(ATone.Voice.Automation.FrequencyHz);
  FTone.Voice.Automation.PitchCents := CopyCurve(ATone.Voice.Automation.PitchCents);
  FTone.Voice.Automation.GainMultiplier := CopyCurve(ATone.Voice.Automation.GainMultiplier);
  FTone.Voice.Automation.Pan := CopyCurve(ATone.Voice.Automation.Pan);
  FTone.Voice.Automation.CutoffHz := CopyCurve(ATone.Voice.Automation.CutoffHz);
  if ATone.Voice.GateEnvelope <> nil then
  begin
    FEnvelope := ATone.Voice.GateEnvelope.Clone;
  end;
  FGateFrames := AGateFrames;
  FFrameCount := AFrameCount;
  LChannels := 1;
  if ATone.Voice.SourceFactory = nil then
  begin
    FOscillator := TOscillator.Create(ASampleRate, ATone.Seed, ATone.Voice.OscillatorQuality);
  end
  else
  begin
    LChannels := ATone.Voice.SourceFactory.Channels;
    FSource := ATone.Voice.SourceFactory.CreateSource(ASampleRate, ATone.Seed);
    if FSource = nil then
    begin
      raise EAudio.Create('Source factory returned no playback instance');
    end;
  end;
  FFilter := TFilter.Create(ASampleRate, ATone.Voice);
  if LChannels = 2 then
  begin
    FRightFilter := TFilter.Create(ASampleRate, ATone.Voice);
  end;
  FLeft := Cos((FTone.Voice.Pan + 1) * Pi / 4);
  FRight := Sin((FTone.Voice.Pan + 1) * Pi / 4);
  FCutoff := FTone.Voice.CutoffHz;
end;

constructor TPlayingTone.CreatePrepared(const ASampleRate: Integer; const ATone: TTone;
  const AGateFrames, AFrameCount: Int64);
var
  LMaximumGateSeconds: Double;
begin
  inherited Create;
  ValidateAudioFormat(ASampleRate, 2);
  ValidateTone(ATone, ASampleRate);
  SynthFrameCost(ATone.Voice, ASampleRate);
  RequireFinite(ATone.GateSeconds, 'Prepared envelope gate');
  { Compare like precision: a stored Double gate may round above an x87 quotient. }
  LMaximumGateSeconds := AFrameCount / ASampleRate;
  if (AGateFrames < 0) or (AGateFrames > AFrameCount) or
    (AFrameCount > MaximumClipSamples div 2) or (ATone.GateSeconds < 0) or
    (ATone.GateSeconds > LMaximumGateSeconds) then
  begin
    raise EAudio.Create('Prepared voice gate or duration exceeds offline bounds');
  end;
  Initialize(ASampleRate, ATone, AGateFrames, AFrameCount);
end;

constructor TPlayingTone.Create(const ASampleRate: Integer; const ATone: TFrameTone);
var
  LCount: Int64;
begin
  inherited Create;
  LCount := ValidateFrameTone(ATone, ASampleRate);
  SynthFrameCost(ATone.Voice, ASampleRate);
  Initialize(ASampleRate, FrameToneValue(ATone, ASampleRate), ATone.GateFrames, LCount);
end;

destructor TPlayingTone.Destroy;
begin
  FEnvelope.Free;
  FRightFilter.Free;
  FFilter.Free;
  FSource.Free;
  FOscillator.Free;
  FTone.Voice.Automation.CutoffHz.Free;
  FTone.Voice.Automation.Pan.Free;
  FTone.Voice.Automation.GainMultiplier.Free;
  FTone.Voice.Automation.PitchCents.Free;
  FTone.Voice.Automation.FrequencyHz.Free;
  inherited;
end;

function TPlayingTone.GetFinished: Boolean;
begin
  Result := FFrame >= FFrameCount;
end;

procedure TPlayingTone.Release;
begin
  if FFailed then
  begin
    raise EAudio.Create('Failed voice cannot be released or reused');
  end;
  if FFrame < FGateFrames then
  begin
    FGateFrames := FFrame;
    FTone.GateSeconds := FGateFrames / FSampleRate;
    if FEnvelope <> nil then
    begin
      FFrameCount := FGateFrames + FEnvelope.ReleaseFrames;
    end
    else
    begin
      FFrameCount := FGateFrames + SampleFramesFromSeconds(FTone.Voice.Envelope.ReleaseSeconds, FSampleRate);
    end;
  end;
end;

procedure TPlayingTone.NotifyGate;
begin
  if not FNoteOff and (FFrame >= FGateFrames) then
  begin
    if FSource <> nil then
    begin
      FSource.NoteOff;
    end;
    FNoteOff := True;
  end;
end;

function TPlayingTone.ReadValues(out AValue, ARightValue, ALeftPan, ARightPan: Double): Boolean;
var
  LFrequency: Double;
  LNextCutoff: Double;
  LPan: Double;
  LSourceLeft: Double;
  LSourceRight: Double;
  LValue: Double;
  LRightValue: Double;
  LGain: Double;
  LEnvelope: Double;
begin
  if FFailed then
  begin
    raise EAudio.Create('Failed voice cannot be reused');
  end;
  try
    NotifyGate;
    if Finished then
    begin
      AValue := 0;
      ARightValue := 0;
      ALeftPan := FLeft;
      ARightPan := FRight;
      Exit(False);
    end;
    LFrequency := FTone.FrequencyHz;
    if FTone.Voice.Automation.FrequencyHz <> nil then
    begin
      LFrequency := FTone.Voice.Automation.FrequencyHz.ValueAt(FFrame);
    end;
    if FTone.Voice.Automation.PitchCents <> nil then
    begin
      LFrequency := FrequencyWithCents(LFrequency,
        FTone.Voice.Automation.PitchCents.ValueAt(FFrame));
    end;
    if FTone.Voice.Automation.CutoffHz <> nil then
    begin
      LNextCutoff := FTone.Voice.Automation.CutoffHz.ValueAt(FFrame);
      if LNextCutoff <> FCutoff then
      begin
        FFilter.SetCutoff(LNextCutoff);
        if FRightFilter <> nil then
        begin
          FRightFilter.SetCutoff(LNextCutoff);
        end;
        FCutoff := LNextCutoff;
      end;
    end;
    if FTone.Voice.Automation.Pan <> nil then
    begin
      LPan := FTone.Voice.Automation.Pan.ValueAt(FFrame);
      FLeft := Cos((LPan + 1) * Pi / 4);
      FRight := Sin((LPan + 1) * Pi / 4);
    end;
    if FSource = nil then
    begin
      LSourceLeft := FOscillator.Next(FTone.Voice.Shape, LFrequency);
      LSourceRight := LSourceLeft;
    end
    else
    begin
      if not FSource.ReadFrame(LFrequency, LSourceLeft, LSourceRight) then
      begin
        LSourceLeft := 0;
        LSourceRight := 0;
      end;
      RequireFinite(LSourceLeft, 'Source left sample');
      RequireFinite(LSourceRight, 'Source right sample');
    end;
    LValue := FFilter.Process(LSourceLeft);
    if FEnvelope <> nil then
    begin
      LEnvelope := FEnvelope.ValueAt(FFrame, FGateFrames);
      LValue := LValue * LEnvelope * FTone.Voice.Gain * FTone.Velocity;
    end
    else
    begin
      LValue := LValue * EnvelopeAt(FTone.Voice.Envelope,
        FFrame / FSampleRate, FTone.GateSeconds) * FTone.Voice.Gain * FTone.Velocity;
    end;
    LRightValue := LValue;
    if FRightFilter <> nil then
    begin
      if FEnvelope <> nil then
      begin
        LRightValue := FRightFilter.Process(LSourceRight) * LEnvelope *
          FTone.Voice.Gain * FTone.Velocity;
      end
      else
      begin
        LRightValue := FRightFilter.Process(LSourceRight) * EnvelopeAt(FTone.Voice.Envelope,
          FFrame / FSampleRate, FTone.GateSeconds) * FTone.Voice.Gain * FTone.Velocity;
      end;
    end;
    if FTone.Voice.Automation.GainMultiplier <> nil then
    begin
      LGain := FTone.Voice.Automation.GainMultiplier.ValueAt(FFrame);
      LValue := LValue * LGain;
      LRightValue := LRightValue * LGain;
    end;
    RequireFinite(LValue, 'Voice left output');
    RequireFinite(LRightValue, 'Voice right output');
    Inc(FFrame);
    NotifyGate;
    AValue := LValue;
    ARightValue := LRightValue;
    ALeftPan := FLeft;
    ARightPan := FRight;
    Result := True;
  except
    FFailed := True;
    raise;
  end;
end;

function TPlayingTone.ReadFrame(out ALeft, ARight: Double): Boolean;
var
  LValue: Double;
  LRightValue: Double;
  LLeftPan: Double;
  LRightPan: Double;
begin
  Result := ReadValues(LValue, LRightValue, LLeftPan, LRightPan);
  ALeft := LValue * LLeftPan;
  ARight := LRightValue * LRightPan;
end;

function RenderPrepared(const ATones: TPreparedTones; const ASampleRate,
  AMinimumFrames: Integer): TAudioClip;
var
  LSamples: TAudioSamples;
  LVoice: TPlayingTone;
  LIndex: Integer;
  LFrame: Integer;
  LStart: Integer;
  LFrames: Integer;
  LVisits: Int64;
  LValue: Double;
  LRightValue: Double;
  LLeftPan: Double;
  LRightPan: Double;
begin
  LFrames := AMinimumFrames;
  LVisits := 0;
  for LIndex := 0 to High(ATones) do
  begin
    LFrames := Max(LFrames, ATones[LIndex].StartFrame + ATones[LIndex].FrameCount);
    Inc(LVisits, Int64(ATones[LIndex].FrameCount) *
      SynthFrameCost(ATones[LIndex].Tone.Voice, ASampleRate));
    if LVisits > MaximumRenderVisits then
    begin
      raise EAudio.Create('Tone rendering exceeds visit budget');
    end;
  end;
  SetLength(LSamples, LFrames * 2);
  for LIndex := 0 to High(ATones) do
  begin
    LVoice := TPlayingTone.CreatePrepared(ASampleRate, ATones[LIndex].Tone,
      ATones[LIndex].GateFrames, ATones[LIndex].FrameCount);
    try
      LStart := ATones[LIndex].StartFrame;
      for LFrame := 0 to ATones[LIndex].FrameCount - 1 do
      begin
        LVoice.ReadValues(LValue, LRightValue, LLeftPan, LRightPan);
        { Preserve the offline path's Single accumulation and expression ordering. }
        LSamples[(LStart + LFrame) * 2] := LSamples[(LStart + LFrame) * 2] + LValue * LLeftPan;
        LSamples[(LStart + LFrame) * 2 + 1] :=
          LSamples[(LStart + LFrame) * 2 + 1] + LRightValue * LRightPan;
      end;
    finally
      LVoice.Free;
    end;
  end;
  Result := TAudioClip.Create(ASampleRate, 2, LSamples);
end;

function RenderTones(const ATones: TTones; const ASampleRate: Integer;
  const AMinimumSeconds: Double): TAudioClip;
var
  LPrepared: TPreparedTones;
  LTone: TTone;
  LIndex: Integer;
  LEnd: Double;
begin
  ValidateAudioFormat(ASampleRate, 2);
  RequireFinite(AMinimumSeconds, 'Minimum duration');
  if (AMinimumSeconds < 0) or
    (AMinimumSeconds > MaximumClipSamples / (2 * ASampleRate)) then
  begin
    raise EAudio.Create('Render duration outside sample budget');
  end;
  if Length(ATones) > MaximumToneEvents then
  begin
    raise EAudio.Create('Too many tone events');
  end;
  SetLength(LPrepared, Length(ATones));
  for LIndex := 0 to High(ATones) do
  begin
    LTone := ATones[LIndex];
    ValidateTone(LTone, ASampleRate);
    RequireFinite(LTone.StartSeconds, 'Tone start');
    RequireFinite(LTone.GateSeconds, 'Tone gate');
    if (LTone.StartSeconds < 0) or (LTone.GateSeconds < 0) then
    begin
      raise EAudio.Create('Tone time must be nonnegative');
    end;
    if LTone.Voice.GateEnvelope <> nil then
    begin
      LEnd := LTone.StartSeconds + LTone.GateSeconds +
        SynthReleaseFrames(LTone.Voice, ASampleRate) / ASampleRate;
    end
    else
    begin
      LEnd := LTone.StartSeconds + LTone.GateSeconds + LTone.Voice.Envelope.ReleaseSeconds;
    end;
    if LEnd > (MaximumClipSamples div 2 - 1) / ASampleRate then
    begin
      raise EAudio.Create('Tone exceeds output sample budget');
    end;
    LPrepared[LIndex].Tone := LTone;
    LPrepared[LIndex].StartFrame := SampleFramesFromSeconds(LTone.StartSeconds, ASampleRate, frFloor);
    LPrepared[LIndex].GateFrames := SampleFramesFromSeconds(LTone.GateSeconds, ASampleRate);
    if LTone.Voice.GateEnvelope <> nil then
    begin
      LPrepared[LIndex].FrameCount := LPrepared[LIndex].GateFrames +
        SynthReleaseFrames(LTone.Voice, ASampleRate);
    end
    else
    begin
      LPrepared[LIndex].FrameCount :=
        SampleFramesFromSeconds(LTone.GateSeconds + LTone.Voice.Envelope.ReleaseSeconds, ASampleRate);
    end;
  end;
  Result := RenderPrepared(LPrepared, ASampleRate, SampleFramesFromSeconds(AMinimumSeconds, ASampleRate));
end;

function RenderFrameTones(const ATones: TFrameTones; const ASampleRate: Integer;
  const AMinimumFrames: Int64): TAudioClip;
var
  LPrepared: TPreparedTones;
  LIndex: Integer;
  LReleaseFrames: Int64;
  LTone: TTone;
begin
  ValidateAudioFormat(ASampleRate, 2);
  if (AMinimumFrames < 0) or (AMinimumFrames > MaximumClipSamples div 2) then
  begin
    raise EAudio.Create('Render duration outside sample budget');
  end;
  if Length(ATones) > MaximumToneEvents then
  begin
    raise EAudio.Create('Too many tone events');
  end;
  SetLength(LPrepared, Length(ATones));
  for LIndex := 0 to High(ATones) do
  begin
    LTone := Default(TTone);
    LTone.FrequencyHz := ATones[LIndex].FrequencyHz;
    LTone.Velocity := ATones[LIndex].Velocity;
    LTone.Voice := ATones[LIndex].Voice;
    LTone.Seed := ATones[LIndex].Seed;
    ValidateTone(LTone, ASampleRate);
    if (ATones[LIndex].StartFrame < 0) or (ATones[LIndex].GateFrames < 0) or
      (ATones[LIndex].StartFrame > MaximumClipSamples div 2) or
      (ATones[LIndex].GateFrames > MaximumClipSamples div 2) then
    begin
      raise EAudio.Create('Tone exceeds output sample budget');
    end;
    LReleaseFrames := SynthReleaseFrames(LTone.Voice, ASampleRate);
    if ATones[LIndex].StartFrame + ATones[LIndex].GateFrames + LReleaseFrames >
      MaximumClipSamples div 2 then
    begin
      raise EAudio.Create('Tone exceeds output sample budget');
    end;
    LTone.GateSeconds := ATones[LIndex].GateFrames / ASampleRate;
    LPrepared[LIndex].Tone := LTone;
    LPrepared[LIndex].StartFrame := ATones[LIndex].StartFrame;
    LPrepared[LIndex].GateFrames := ATones[LIndex].GateFrames;
    LPrepared[LIndex].FrameCount := ATones[LIndex].GateFrames + LReleaseFrames;
  end;
  Result := RenderPrepared(LPrepared, ASampleRate, AMinimumFrames);
end;

end.
