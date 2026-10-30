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

program pythian_tests_music_pattern;
{$mode delphi}
{$H+}
uses SysUtils, pythian.audio, pythian.music.pattern, pythian.pitch.track;

var Checks: Integer;

procedure Check(const ACondition: Boolean; const AMessage: String);
begin
  Inc(Checks);
  if not ACondition then raise EAudio.Create(AMessage);
end;

procedure Run;
var
  LSpans: TPitchSpans;
  LPattern, LPrevious: TPitchPattern;
  LFailed: Boolean;
  I: Integer;
begin
  SetLength(LSpans, 4);
  for I := 0 to 3 do
  begin
    LSpans[I] := Default(TPitchSpan);
    LSpans[I].Kind := pskUnknown;
    LSpans[I].Note := -1;
    LSpans[I].StartFrame := I * 2000;
    LSpans[I].EndFrame := (I + 1) * 2000;
  end;
  LSpans[0].Kind := pskPitch;
  LSpans[0].Note := 60;
  LSpans[0].StartFrame := 400;
  LSpans[2].Kind := pskSilence;
  LSpans[3].Kind := pskPitch;
  LSpans[3].Note := 62;
  LPattern := QuantizePitchPattern(LSpans, 8000, 8000, 500000, 90);
  Check(Length(LPattern) = 4, 'Exact complete cells');
  Check((LPattern[0].Note = 60) and LPattern[0].Attack and
    (LPattern[0].Velocity = 90), 'Explicit velocity and accepted pitch');
  Check((LPattern[1].Kind = pskUnknown) and (LPattern[1].Note = -1),
    'Unknown is not a rest');
  Check(LPattern[2].Kind = pskSilence, 'Measured silence preserved');
  Check((LPattern[3].Note = 62) and LPattern[3].Attack, 'New stable span starts anew');
  LSpans[3].EndFrame := 7500;
  LPattern := QuantizePitchPattern(LSpans, 8000, 7500, 500000);
  Check(Length(LPattern) = 3, 'Incomplete final cell excluded');
  LPrevious := Copy(LPattern);
  LFailed := False;
  try
    LPattern := QuantizePitchPattern(nil, 8000, 100, 500000);
  except on E: EAudio do LFailed := True;
  end;
  Check(LFailed and (Length(LPattern) = Length(LPrevious)), 'Too-short request preserves previous result');
  LPattern := QuantizePitchPattern(nil, 8000, 8000, 500000);
  for I := 0 to High(LPattern) do
    Check((LPattern[I].Kind = pskUnknown) and not LPattern[I].Attack,
      'Unmeasured time never becomes silence or an attack');
  LFailed := False;
  try
    LPattern := QuantizePitchPattern(nil, 8000, 8000000, 500000);
  except on E: EAudio do LFailed := True;
  end;
  Check(LFailed, 'Excessive cell extent rejected');
  LSpans[1].StartFrame := 1000;
  LFailed := False;
  try
    LPattern := QuantizePitchPattern(LSpans, 8000, 8000, 500000);
  except on E: EAudio do LFailed := True;
  end;
  Check(LFailed, 'Overlapping source spans rejected');
  SetLength(LPattern, 2);
  for I := 0 to 1 do
  begin
    LPattern[I] := Default(TPitchPatternCell);
    LPattern[I].Kind := pskPitch;
    LPattern[I].Note := 60;
    LPattern[I].Velocity := 80;
    LPattern[I].Attack := I = 0;
  end;
  ValidatePitchPattern(LPattern);
  Check(True, 'A genuine held note is valid');
  LPattern[1].Note := 62;
  LFailed := False;
  try
    ValidatePitchPattern(LPattern);
  except on E: EAudio do LFailed := True;
  end;
  Check(LFailed, 'A changed pitch cannot silently masquerade as a held note');
  LPattern[1].Kind := pskUnknown;
  LFailed := False;
  try
    ValidatePitchPattern(LPattern);
  except on E: EAudio do LFailed := True;
  end;
  Check(LFailed, 'Unknown cells cannot retain hidden note or velocity');
end;

begin
  Run;
  WriteLn('PASS portable music pattern: ', Checks, ' checks');
end.
