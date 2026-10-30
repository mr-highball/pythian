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

unit pythian.music.pattern;

{$mode delphi}
{$H+}

interface

uses pythian.pitch.track;

const
  MaximumPitchPatternCells = 256;
  PitchPatternPpq = 480;
  PitchPatternStepTicks = 240;

type
  TPitchPatternCell = record
    Kind: TPitchSpanKind;
    Note: Integer;
    Velocity: Integer;
    Attack: Boolean;
  end;
  TPitchPattern = array of TPitchPatternCell;

{ Selected-channel stable-pitch spans sampled at complete eighth-note cell
  centers on an explicit constant clock. The first cell begins at input frame
  zero; no beat phase or attacks are inferred. A changed source span becomes an
  attack suggestion. Unmeasured gaps stay unknown, never measured silence.
  Tempo is microseconds per quarter, matching the primary musical clock. }
function QuantizePitchPattern(const ASpans: TPitchSpans; const ASampleRate,
  AFrameCount, ATempo: Integer; const AVelocity: Integer = 80): TPitchPattern;
procedure ValidatePitchPattern(const APattern: TPitchPattern);

implementation

uses SysUtils, pythian.audio, pythian.time;

procedure ValidatePitchPattern(const APattern: TPitchPattern);
var
  LCell: TPitchPatternCell;
  LIndex: Integer;
begin
  if (Length(APattern) < 1) or (Length(APattern) > MaximumPitchPatternCells) then
  begin
    raise EAudio.Create('Pitch pattern requires 1..256 cells');
  end;
  for LIndex := 0 to High(APattern) do
  begin
    LCell := APattern[LIndex];
    if not (LCell.Kind in [pskPitch, pskSilence, pskUnknown]) then
    begin
      raise EAudio.Create('Pitch pattern has an invalid cell kind');
    end;
    if LCell.Kind = pskPitch then
    begin
      if (LCell.Note < 0) or (LCell.Note > 127) or
        (LCell.Velocity < 1) or (LCell.Velocity > 127) then
      begin
        raise EAudio.Create('Pitched cells require MIDI note 0..127 and velocity 1..127');
      end;
      if (LIndex > 0) and not LCell.Attack and
        ((APattern[LIndex - 1].Kind <> pskPitch) or
         (APattern[LIndex - 1].Note <> LCell.Note) or
         (APattern[LIndex - 1].Velocity <> LCell.Velocity)) then
        raise EAudio.Create('A held cell must continue the preceding note and velocity');
    end
    else if (LCell.Note <> -1) or (LCell.Velocity <> 0) or LCell.Attack then
    begin
      raise EAudio.Create('Unknown/silent cells must omit note, velocity and attack');
    end;
  end;
end;

function QuantizePitchPattern(const ASpans: TPitchSpans; const ASampleRate,
  AFrameCount, ATempo: Integer; const AVelocity: Integer): TPitchPattern;
var
  LClock: TTempoMap;
  LSpan: TPitchSpan;
  LPreviousEnd: Integer;
  LCount: Integer;
  LIndex: Integer;
  LSpanIndex: Integer;
  LPreviousSpan: Integer;
  LCenter: Int64;
begin
  ValidateAudioFormat(ASampleRate, 1);
  if (AFrameCount < 1) or (ATempo < 250000) or (ATempo > 1500000) or
    (AVelocity < 1) or (AVelocity > 127) or
    (Length(ASpans) > MaximumPitchTrackWindows) then
  begin
    raise EAudio.Create('Pitch pattern requires bounded spans and an explicit 40..240 BPM clock');
  end;
  LPreviousEnd := 0;
  for LSpan in ASpans do
  begin
    if not (LSpan.Kind in [pskPitch, pskSilence, pskUnknown]) or
      (LSpan.StartFrame < LPreviousEnd) or (LSpan.EndFrame <= LSpan.StartFrame) or
      (LSpan.EndFrame > AFrameCount) or
      ((LSpan.Kind = pskPitch) and ((LSpan.Note < 0) or (LSpan.Note > 127))) or
      ((LSpan.Kind <> pskPitch) and (LSpan.Note <> -1)) then
    begin
      raise EAudio.Create('Pitch pattern source spans are invalid or overlap');
    end;
    LPreviousEnd := LSpan.EndFrame;
  end;
  LClock := TTempoMap.Create(PitchPatternPpq,
    MaximumPitchPatternCells * PitchPatternStepTicks,
    [MakeTempoChange(0, ATempo)]);
  try
    if LClock.FrameAtTick(LClock.LengthTicks, ASampleRate, frCeiling) < AFrameCount then
    begin
      raise EAudio.Create('Pitch pattern exceeds 256 cells; choose a shorter range');
    end;
    LCount := LClock.NextGridTick(AFrameCount, ASampleRate, PitchPatternStepTicks) div
      PitchPatternStepTicks;
    if LClock.FrameAtTick(LCount * PitchPatternStepTicks, ASampleRate, frCeiling) >
      AFrameCount then
    begin
      Dec(LCount);
    end;
    if LCount = 0 then
    begin
      raise EAudio.Create('Pitch pattern needs at least one complete eighth-note cell');
    end;
    SetLength(Result, LCount);
    LSpanIndex := 0;
    LPreviousSpan := -1;
    for LIndex := 0 to LCount - 1 do
    begin
      Result[LIndex] := Default(TPitchPatternCell);
      Result[LIndex].Kind := pskUnknown;
      Result[LIndex].Note := -1;
      LCenter := (LClock.FrameAtTick(LIndex * PitchPatternStepTicks, ASampleRate) +
        LClock.FrameAtTick((LIndex + 1) * PitchPatternStepTicks, ASampleRate)) div 2;
      while (LSpanIndex < Length(ASpans)) and
        (ASpans[LSpanIndex].EndFrame <= LCenter) do
      begin
        Inc(LSpanIndex);
      end;
      if (LSpanIndex < Length(ASpans)) and (ASpans[LSpanIndex].StartFrame <= LCenter) then
      begin
        Result[LIndex].Kind := ASpans[LSpanIndex].Kind;
        if Result[LIndex].Kind = pskPitch then
        begin
          Result[LIndex].Note := ASpans[LSpanIndex].Note;
          Result[LIndex].Velocity := AVelocity;
          Result[LIndex].Attack := LPreviousSpan <> LSpanIndex;
        end;
        LPreviousSpan := LSpanIndex;
      end
      else
      begin
        LPreviousSpan := -1;
      end;
    end;
    ValidatePitchPattern(Result);
  finally
    LClock.Free;
  end;
end;

end.
