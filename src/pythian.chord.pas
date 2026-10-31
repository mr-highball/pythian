(*
MIT License

Copyright (c) 2021 mr-highball
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
unit pythian.chord;

{$mode delphi}
{$H+}

interface

const
  MaximumChordVoices = 4096;
  MaximumChordTones = 4096;

type
  { A complete voice frame in pitch/velocity space. Time belongs to the consumer.
    Attack starts/restarts all tones; hold retains an identical active voice;
    rest contains no tones. Consumers validate their own capacity and pitch
    contracts before admission. These records contain no renderer or clock. }
  TChordAction = (caRest, caAttack, caHold);
  TChordTone = record
    Pitch: Integer;
    Velocity: Integer;
  end;
  TChordTones = array of TChordTone;
  TChordVoice = record
    Action: TChordAction;
    Tones: TChordTones;
  end;
  TChordFrame = array of TChordVoice;
  TChordCapacities = array of Integer;

{ Shared musical admission contract for previews and full instruments. Previous
  is the last admitted frame, initially one empty rest per declared voice.
  A hold must retain its sounding predecessor's pitches and velocities exactly.
  Validation is read-only; callers publish detached state only after admission. }
procedure ValidateChordTransition(const AFrame, APrevious: TChordFrame;
  const ACapacities: TChordCapacities);
function CopyChordFrame(const AFrame: TChordFrame): TChordFrame;

implementation

uses pythian.audio;

procedure ValidateChordTransition(const AFrame, APrevious: TChordFrame;
  const ACapacities: TChordCapacities);
var
  LVoice: Integer;
  LTone: Integer;
  LCapacity: Integer;
begin
  if (Length(ACapacities) < 1) or (Length(ACapacities) > MaximumChordVoices) or
    (Length(AFrame) <> Length(ACapacities)) or
    (Length(APrevious) <> Length(ACapacities)) then
  begin
    raise EAudio.Create('Chord frame voice count does not match capacities');
  end;
  LCapacity := 0;
  for LVoice := 0 to High(AFrame) do
  begin
    if (ACapacities[LVoice] < 0) or
      (ACapacities[LVoice] > MaximumChordTones - LCapacity) then
    begin
      raise EAudio.Create('Chord capacities exceed the stream tone budget');
    end;
    Inc(LCapacity, ACapacities[LVoice]);
    if not (AFrame[LVoice].Action in [caRest, caAttack, caHold]) then
    begin
      raise EAudio.Create('Unknown chord action');
    end;
    if Length(AFrame[LVoice].Tones) > ACapacities[LVoice] then
    begin
      raise EAudio.Create('Chord exceeds its declared tone capacity');
    end;
    if AFrame[LVoice].Action = caRest then
    begin
      if Length(AFrame[LVoice].Tones) <> 0 then
      begin
        raise EAudio.Create('Chord rest contains tones');
      end;
      Continue;
    end;
    if Length(AFrame[LVoice].Tones) = 0 then
    begin
      raise EAudio.Create('Sounding chord has no tones');
    end;
    if (AFrame[LVoice].Action = caHold) and
      ((APrevious[LVoice].Action = caRest) or
       (Length(AFrame[LVoice].Tones) <> Length(APrevious[LVoice].Tones))) then
    begin
      raise EAudio.Create('Chord hold has no identical active predecessor');
    end;
    for LTone := 0 to High(AFrame[LVoice].Tones) do
    begin
      if (AFrame[LVoice].Tones[LTone].Pitch < 0) or
        (AFrame[LVoice].Tones[LTone].Pitch > 127) or
        (AFrame[LVoice].Tones[LTone].Velocity < 1) or
        (AFrame[LVoice].Tones[LTone].Velocity > 127) then
      begin
        raise EAudio.Create('Chord pitch must be 0..127 and velocity 1..127');
      end;
      if (LTone > 0) and
        (AFrame[LVoice].Tones[LTone - 1].Pitch >= AFrame[LVoice].Tones[LTone].Pitch) then
      begin
        raise EAudio.Create('Chord pitches must be strictly increasing');
      end;
      if (AFrame[LVoice].Action = caHold) and
        ((AFrame[LVoice].Tones[LTone].Pitch <> APrevious[LVoice].Tones[LTone].Pitch) or
         (AFrame[LVoice].Tones[LTone].Velocity <> APrevious[LVoice].Tones[LTone].Velocity)) then
      begin
        raise EAudio.Create('Chord hold changes an active pitch or velocity');
      end;
    end;
  end;
end;

function CopyChordFrame(const AFrame: TChordFrame): TChordFrame;
var
  LVoice: Integer;
begin
  Result := Copy(AFrame);
  for LVoice := 0 to High(Result) do
  begin
    Result[LVoice].Tones := Copy(AFrame[LVoice].Tones);
  end;
end;

end.
