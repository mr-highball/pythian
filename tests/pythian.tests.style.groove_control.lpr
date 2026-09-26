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
program pythian_tests_style_groove_control;

{$mode delphi}
{$H+}

uses
  SysUtils,
  pythian.passage,
  pythian.rhythm.admission;

const
  CSampleRate = 48000;
  CTempoMicroseconds = 500000;
  CTicksPerQuarter = 960;
  CStepTicks = 240;
  CMaximumErrorFrames = 500;
  CCellFrames = 6000;
  CSourceFrames = 384000;
  CCellCount = 64;

procedure Check(const ACondition: Boolean; const AMessage: String);
begin
  if not ACondition then
  begin
    raise Exception.Create(AMessage);
  end;
end;

function AuthoredOnsets(const AJitter: Integer; const ABreakCell: Boolean): TPassageBounds;
const
  CBaseCells: array[0..15] of Integer = (0, 4, 8, 12, 16, 21, 24, 29,
    32, 36, 40, 44, 48, 53, 56, 61);
var
  LIndex: Integer;
  LCell: Integer;
  LJitter: Integer;
begin
  Result := nil;
  SetLength(Result, Length(CBaseCells));
  for LIndex := 0 to High(CBaseCells) do
  begin
    LCell := CBaseCells[LIndex];
    if ABreakCell and (LIndex = 5) then
    begin
      LCell := LCell + 1;
    end;
    LJitter := AJitter;
    if (LIndex mod 2) = 1 then
    begin
      LJitter := -AJitter;
    end;
    Result[LIndex] := LCell * CCellFrames + LJitter;
  end;
end;

function SameAdmission(const ALeft, ARight: TRhythmAdmission): Boolean;
var
  LIndex: Integer;
begin
  Result := (ALeft.Pattern = ARight.Pattern) and
    (ALeft.Accepted = ARight.Accepted) and
    (Length(ALeft.Cells) = Length(ARight.Cells)) and
    (Length(ALeft.FrameErrors) = Length(ARight.FrameErrors)) and
    (Length(ALeft.Decisions) = Length(ARight.Decisions));
  if not Result then
  begin
    Exit;
  end;
  for LIndex := 0 to High(ALeft.Cells) do
  begin
    if (ALeft.Cells[LIndex] <> ARight.Cells[LIndex]) or
      (ALeft.FrameErrors[LIndex] <> ARight.FrameErrors[LIndex]) or
      (ALeft.Decisions[LIndex] <> ARight.Decisions[LIndex]) then
    begin
      Exit(False);
    end;
  end;
end;

function Measure(const AOnsets: TPassageBounds): TRhythmAdmission;
begin
  Result := AdmitWaveRhythm(CSampleRate, CSourceFrames,
    CTempoMicroseconds, CTicksPerQuarter, CStepTicks,
    CMaximumErrorFrames, AOnsets);
end;

var
  LReference: TRhythmAdmission;
  LPreserved: TRhythmAdmission;
  LBroken: TRhythmAdmission;
  LReplay: TRhythmAdmission;
begin
  LReference := Measure(AuthoredOnsets(0, False));
  LPreserved := Measure(AuthoredOnsets(240, False));
  LBroken := Measure(AuthoredOnsets(0, True));
  LReplay := Measure(AuthoredOnsets(0, True));

  Check(Length(LReference.Pattern) = CCellCount,
    'Declared 64-cell constant-clock scope');
  Check(LReference.Pattern =
    'x...x...x...x...' + 'x....x..x....x..' +
    'x...x...x...x...' + 'x....x..x....x..',
    'Frozen reference onset occupancy');
  Check(LReference.Accepted = 16, 'All authored reference events admitted');
  Check(LPreserved.Pattern = LReference.Pattern,
    'Alternating +/-5 ms timing jitter preserves admitted cell occupancy');
  Check(LPreserved.Accepted = LReference.Accepted,
    'Preserving control retains admitted event count');
  Check(LBroken.Pattern <> LReference.Pattern,
    'Moving one authored event by one cell breaks onset occupancy');
  Check(LBroken.Accepted = LReference.Accepted,
    'Trait-breaking control retains event count');
  Check(SameAdmission(LBroken, LReplay),
    'Exact replay retains pattern, cells, errors and decisions');

  WriteLn('Reference pattern: ', LReference.Pattern);
  WriteLn('Preserved pattern: ', LPreserved.Pattern);
  WriteLn('Broken pattern:    ', LBroken.Pattern);
  WriteLn('Admitted events: ', LReference.Accepted, '/', Length(LReference.Cells));
  WriteLn('Groove onset-grid preservation, one-cell break and replay pass');
end.
