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
unit pythian.wfc.instrument;

{$mode delphi}
{$H+}

interface

uses
  pythian.audio,
  pythian.synth,
  pythian.instrument,
  pythian.music,
  pythian.music.render,
  pythian.source.wavetable,
  pythian.wfc.style;

type
  TStyleInstrumentZone = record
    Zone: TInstrumentZone;
    { Nil preserves the authored source/envelope in Zone.Voice. Non-nil profiles
      must contain the selected capability; borrowed only during construction. }
    Timbre: TWaveStyleProfile;
    Envelope: TWaveStyleProfile;
  end;
  TStyleInstrumentZones = array of TStyleInstrumentZone;

  { Owns measured wavetable factories and cloned automation/gated envelopes.
    Caller-supplied factories without a timbre override remain borrowed: the
    abstract source factory contract has no clone operation.
    The instrument must outlive its plans and playback, because playing
    wavetable sources borrow its tables. Frame controls use SampleRate. }
  TStyleInstrument = class
  private
    FSampleRate: Integer;
    FInstrument: TInstrument;
    FZones: TInstrumentZones;
    FFactories: array of TWavetableSourceFactory;
    FTimbreIds: array of String;
    FEnvelopeIds: array of String;
    procedure CheckZone(const AIndex: Integer);
  public
    constructor Create(const AZones: TStyleInstrumentZones; const ASampleRate: Integer;
      const ATrajectoryRms: Double = 0.1);
    destructor Destroy; override;
    function SelectZones(const AKey, AVelocity: Integer): TInstrumentZoneIndices;
    function PlanNote(const AKey, AVelocity: Integer;
      const AStartFrame, AGateFrames: Int64; const ASeed: Cardinal): TFrameTones;
    function TimbreIdentity(const AZone: Integer): String;
    function EnvelopeIdentity(const AZone: Integer): String;
    property SampleRate: Integer read FSampleRate;
  end;
  TStyleInstruments = array of TStyleInstrument;

{ Dense explicit bindings indexed by TNoteGate.Voice, independent of MIDI
  track/channel. Every binding must exist and use ASampleRate. Returned plans
  borrow instrument resources; no profile, key, clock or gate is modified. }
function PlanStyleNoteTones(const ASequence: TNoteSequence; const ASampleRate: Integer;
  const AInstruments: TStyleInstruments; out AReport: TNoteRenderReport): TFrameTones;

implementation

uses
  pythian.automation,
  pythian.oscillator;

function CloneCurve(const ACurve: TAutomationCurve): TAutomationCurve;
begin
  Result := nil;
  if ACurve <> nil then
  begin
    Result := ACurve.Clone;
  end;
end;

constructor TStyleInstrument.Create(const AZones: TStyleInstrumentZones;
  const ASampleRate: Integer; const ATrajectoryRms: Double);
var
  LIndex: Integer;
  LKey: Integer;
  LZones: TInstrumentZones;
  LValidation: TInstrument;
  LTone: TFrameTone;
begin
  inherited Create;
  ValidateAudioFormat(ASampleRate, 2);
  FSampleRate := ASampleRate;
  if (Length(AZones) < 1) or (Length(AZones) > MaximumInstrumentZones) then
  begin
    raise EAudio.Create('Style instrument requires 1..256 zones');
  end;
  SetLength(LZones, Length(AZones));
  for LIndex := 0 to High(AZones) do
  begin
    LZones[LIndex] := AZones[LIndex].Zone;
    if (AZones[LIndex].Timbre <> nil) and not AZones[LIndex].Timbre.HasTimbre then
    begin
      raise EAudio.Create('Instrument timbre binding requires measured timbre');
    end;
    if (AZones[LIndex].Envelope <> nil) and not AZones[LIndex].Envelope.HasEnvelope then
    begin
      raise EAudio.Create('Instrument envelope binding requires measured envelope');
    end;
  end;
  LValidation := TInstrument.Create(LZones);
  LValidation.Free;

  SetLength(FZones, Length(AZones));
  SetLength(FFactories, Length(AZones));
  SetLength(FTimbreIds, Length(AZones));
  SetLength(FEnvelopeIds, Length(AZones));
  for LIndex := 0 to High(AZones) do
  begin
    FZones[LIndex] := LZones[LIndex];
    { Clear borrowed references before any operation that can fail. Destruction
      releases only successfully cloned definitions and owned factories. }
    FZones[LIndex].Voice.Automation := Default(TVoiceAutomation);
    FZones[LIndex].Voice.GateEnvelope := nil;
    FZones[LIndex].Voice.Automation.FrequencyHz :=
      CloneCurve(LZones[LIndex].Voice.Automation.FrequencyHz);
    FZones[LIndex].Voice.Automation.PitchCents :=
      CloneCurve(LZones[LIndex].Voice.Automation.PitchCents);
    FZones[LIndex].Voice.Automation.GainMultiplier :=
      CloneCurve(LZones[LIndex].Voice.Automation.GainMultiplier);
    FZones[LIndex].Voice.Automation.Pan := CloneCurve(LZones[LIndex].Voice.Automation.Pan);
    FZones[LIndex].Voice.Automation.CutoffHz :=
      CloneCurve(LZones[LIndex].Voice.Automation.CutoffHz);
    if AZones[LIndex].Timbre <> nil then
    begin
      FFactories[LIndex] := AZones[LIndex].Timbre.CopyTimbreFactory(ASampleRate, ATrajectoryRms);
      FZones[LIndex].Voice.SourceFactory := FFactories[LIndex];
      FTimbreIds[LIndex] := AZones[LIndex].Timbre.Identity;
    end;
    if AZones[LIndex].Envelope <> nil then
    begin
      FZones[LIndex].Voice.GateEnvelope :=
        AZones[LIndex].Envelope.CopyGateEnvelope(ASampleRate);
      FEnvelopeIds[LIndex] := AZones[LIndex].Envelope.Identity;
    end
    else if LZones[LIndex].Voice.GateEnvelope <> nil then
    begin
      FZones[LIndex].Voice.GateEnvelope := LZones[LIndex].Voice.GateEnvelope.Clone;
    end;
    { Validate every declared key, including custom factory admission. A sparse
      factory need not have monotonic validity between the endpoints. }
    LTone := Default(TFrameTone);
    LTone.Voice := FZones[LIndex].Voice;
    LTone.GateFrames := 1;
    LTone.Velocity := 1;
    for LKey := FZones[LIndex].MinimumKey to FZones[LIndex].MaximumKey do
    begin
      LTone.FrequencyHz := MidiFrequency(LKey);
      ValidateFrameTone(LTone, ASampleRate);
    end;
    SynthFrameCost(LTone.Voice, ASampleRate);
  end;
  FInstrument := TInstrument.Create(FZones);
end;

destructor TStyleInstrument.Destroy;
var
  LIndex: Integer;
begin
  FInstrument.Free;
  for LIndex := 0 to High(FZones) do
  begin
    FZones[LIndex].Voice.GateEnvelope.Free;
    FZones[LIndex].Voice.Automation.FrequencyHz.Free;
    FZones[LIndex].Voice.Automation.PitchCents.Free;
    FZones[LIndex].Voice.Automation.GainMultiplier.Free;
    FZones[LIndex].Voice.Automation.Pan.Free;
    FZones[LIndex].Voice.Automation.CutoffHz.Free;
  end;
  for LIndex := 0 to High(FFactories) do
  begin
    FFactories[LIndex].Free;
  end;
  inherited Destroy;
end;

procedure TStyleInstrument.CheckZone(const AIndex: Integer);
begin
  if (AIndex < 0) or (AIndex >= Length(FZones)) then
  begin
    raise EAudio.Create('Style instrument zone index outside range');
  end;
end;

function TStyleInstrument.TimbreIdentity(const AZone: Integer): String;
begin
  CheckZone(AZone);
  Result := FTimbreIds[AZone];
end;

function TStyleInstrument.EnvelopeIdentity(const AZone: Integer): String;
begin
  CheckZone(AZone);
  Result := FEnvelopeIds[AZone];
end;

function TStyleInstrument.SelectZones(const AKey, AVelocity: Integer): TInstrumentZoneIndices;
begin
  Result := FInstrument.SelectZones(AKey, AVelocity);
end;

function TStyleInstrument.PlanNote(const AKey, AVelocity: Integer;
  const AStartFrame, AGateFrames: Int64; const ASeed: Cardinal): TFrameTones;
begin
  Result := FInstrument.PlanNote(AKey, AVelocity, FSampleRate, AStartFrame, AGateFrames, ASeed);
end;

function PlanStyleNoteTones(const ASequence: TNoteSequence; const ASampleRate: Integer;
  const AInstruments: TStyleInstruments; out AReport: TNoteRenderReport): TFrameTones;
var
  LBindings: TNoteInstruments;
  LIndex: Integer;
begin
  AReport := Default(TNoteRenderReport);
  if (Length(AInstruments) < 1) or (Length(AInstruments) > MaximumNoteVoices) then
  begin
    raise EAudio.Create('Style rendering requires 1..4096 explicit bindings');
  end;
  SetLength(LBindings, Length(AInstruments));
  for LIndex := 0 to High(AInstruments) do
  begin
    if (AInstruments[LIndex] = nil) or
      (AInstruments[LIndex].SampleRate <> ASampleRate) then
    begin
      raise EAudio.Create('Style instrument binding is missing or uses a different sample rate');
    end;
    LBindings[LIndex] := AInstruments[LIndex].FInstrument;
  end;
  Result := PlanNoteTones(ASequence, ASampleRate, LBindings, AReport);
end;

end.
