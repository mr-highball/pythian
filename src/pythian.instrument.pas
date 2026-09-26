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
unit pythian.instrument;

{$mode delphi}
{$H+}

interface

uses
  pythian.synth;

const
  InstrumentVersion = 1;
  MaximumInstrumentZones = 256;
  MaximumInstrumentLayers = 16;

type
  TInstrumentZone = record
    MinimumKey: Integer;
    MaximumKey: Integer;
    MinimumVelocity: Integer;
    MaximumVelocity: Integer;
    Voice: TSynthVoice;
  end;
  TInstrumentZones = array of TInstrumentZone;
  TInstrumentZoneIndices = array of Integer;

  { Detached immutable zone records, in caller order. Factories, automation and
    gated envelopes remain borrowed during planning/rendering. Playing tones
    clone automation/envelopes; factories retain their own source lifetime rules. Overlaps layer
    every matching voice; no matching zone is an explicit admission error. }
  TInstrument = class
  strict private
    FZones: TInstrumentZones;
  public
    constructor Create(const AZones: TInstrumentZones);
    function CopyZones: TInstrumentZones;
    function SelectZones(const AKey, AVelocity: Integer): TInstrumentZoneIndices;
    function PlanNote(const AKey, AVelocity, ASampleRate: Integer;
      const AStartFrame, AGateFrames: Int64; const ASeed: Cardinal): TFrameTones;
  end;

implementation

uses
  pythian.audio,
  pythian.oscillator;

constructor TInstrument.Create(const AZones: TInstrumentZones);
var
  LCounts: array[0..127, 1..127] of Byte;
  LZone: TInstrumentZone;
  LKey: Integer;
  LVelocity: Integer;
begin
  inherited Create;
  if (Length(AZones) < 1) or (Length(AZones) > MaximumInstrumentZones) then
  begin
    raise EAudio.Create('Instrument requires 1..256 zones');
  end;
  FillChar(LCounts, SizeOf(LCounts), 0);
  for LZone in AZones do
  begin
    if (LZone.MinimumKey < 0) or (LZone.MaximumKey > 127) or
      (LZone.MinimumKey > LZone.MaximumKey) or (LZone.MinimumVelocity < 1) or
      (LZone.MaximumVelocity > 127) or
      (LZone.MinimumVelocity > LZone.MaximumVelocity) then
    begin
      raise EAudio.Create('Instrument zone key/velocity range is invalid');
    end;
    for LKey := LZone.MinimumKey to LZone.MaximumKey do
    begin
      for LVelocity := LZone.MinimumVelocity to LZone.MaximumVelocity do
      begin
        if LCounts[LKey, LVelocity] = MaximumInstrumentLayers then
        begin
          raise EAudio.Create('Instrument overlap exceeds 16 layers per note');
        end;
        Inc(LCounts[LKey, LVelocity]);
      end;
    end;
  end;
  FZones := Copy(AZones);
end;

function TInstrument.CopyZones: TInstrumentZones;
begin
  Result := Copy(FZones);
end;

function TInstrument.SelectZones(const AKey, AVelocity: Integer): TInstrumentZoneIndices;
var
  LCandidate: TInstrumentZoneIndices;
  LIndex: Integer;
  LCount: Integer;
  LZone: TInstrumentZone;
begin
  if (AKey < 0) or (AKey > 127) or (AVelocity < 1) or (AVelocity > 127) then
  begin
    raise EAudio.Create('Instrument note requires key 0..127 and velocity 1..127');
  end;
  SetLength(LCandidate, MaximumInstrumentLayers);
  LCount := 0;
  for LIndex := 0 to High(FZones) do
  begin
    LZone := FZones[LIndex];
    if (AKey >= LZone.MinimumKey) and (AKey <= LZone.MaximumKey) and
      (AVelocity >= LZone.MinimumVelocity) and (AVelocity <= LZone.MaximumVelocity) then
    begin
      LCandidate[LCount] := LIndex;
      Inc(LCount);
    end;
  end;
  if LCount = 0 then
  begin
    raise EAudio.Create('Instrument has no zone for the requested key and velocity');
  end;
  SetLength(LCandidate, LCount);
  Result := LCandidate;
end;

function TInstrument.PlanNote(const AKey, AVelocity, ASampleRate: Integer;
  const AStartFrame, AGateFrames: Int64; const ASeed: Cardinal): TFrameTones;
var
  LIndices: TInstrumentZoneIndices;
  LCandidate: TFrameTones;
  LIndex: Integer;
begin
  ValidateAudioFormat(ASampleRate, 2);
  LIndices := SelectZones(AKey, AVelocity);
  SetLength(LCandidate, Length(LIndices));
  for LIndex := 0 to High(LIndices) do
  begin
    LCandidate[LIndex] := Default(TFrameTone);
    LCandidate[LIndex].StartFrame := AStartFrame;
    LCandidate[LIndex].GateFrames := AGateFrames;
    LCandidate[LIndex].FrequencyHz := MidiFrequency(AKey);
    LCandidate[LIndex].Velocity := AVelocity / 127;
    LCandidate[LIndex].Voice := FZones[LIndices[LIndex]].Voice;
    LCandidate[LIndex].Seed := ASeed;
    ValidateFrameTone(LCandidate[LIndex], ASampleRate);
    SynthFrameCost(LCandidate[LIndex].Voice, ASampleRate);
  end;
  Result := LCandidate;
end;

end.
