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
program pythian.tests.alignment;

{$mode delphi}
{$H+}

uses
  SysUtils,
  pythian.audio,
  pythian.alignment;

procedure Check(const ACondition: Boolean; const AMessage: String);
begin
  if not ACondition then
  begin
    raise EAudio.Create(AMessage);
  end;
end;

procedure Run;
const
  Offsets: array[0..4] of Integer = (0, 3, 4, 9, 14);
  Cells: array[0..4] of Integer = (0, 0, 1, 1, 2);
  Errors: array[0..4] of Integer = (0, -3, 2, -3, -2);
var
  LFrames: TFrameAnchors;
  LAnchors: TFeatureAnchors;
  LOrigin: Int64;
  LIndex: Integer;
  LRejected: Boolean;
begin
  LOrigin := (Int64(1) shl 53) + 37;
  SetLength(LFrames, 5);
  for LIndex := 0 to High(LFrames) do
  begin
    LFrames[LIndex] := LOrigin + Offsets[LIndex];
  end;
  LAnchors := AlignFeatureAnchors(LFrames, LOrigin, 6, 4, 3);
  for LIndex := 0 to High(LFrames) do
  begin
    Check((LAnchors[LIndex].RequestedFrame = LFrames[LIndex]) and
      (LAnchors[LIndex].Cell = Cells[LIndex]) and
      (LAnchors[LIndex].ErrorFrames = Errors[LIndex]) and
      (LAnchors[LIndex].AlignedFrame = LOrigin + 6 * Cells[LIndex]),
      'Independent absolute integer anchors above 2^53 and earlier half-hop ties');
  end;
  LRejected := False;
  try
    LAnchors := AlignFeatureAnchors(LFrames, LOrigin, 6, 4, 2);
  except
    on EAudio do
    begin
      LRejected := True;
    end;
  end;
  Check(LRejected and (Length(LAnchors) = 5) and (LAnchors[1].ErrorFrames = -3),
    'Tolerance rejection preserves previously assigned map');
  SetLength(LFrames, 1);
  LFrames[0] := LOrigin + 22;
  LRejected := False;
  try
    LAnchors := AlignFeatureAnchors(LFrames, LOrigin, 6, 4, 3);
  except
    on EAudio do
    begin
      LRejected := True;
    end;
  end;
  Check(LRejected, 'Out-of-grid nearest cell rejects without clamping');
  LFrames[0] := High(Int64);
  LAnchors := AlignFeatureAnchors(LFrames, High(Int64) - 4, 2, 3, 1);
  Check((LAnchors[0].Cell = 2) and (LAnchors[0].AlignedFrame = High(Int64)),
    'Highest representable frame remains exact');
  LRejected := False;
  try
    LAnchors := AlignFeatureAnchors(LFrames, High(Int64) - 1, 2, 2, 1);
  except
    on EAudio do
    begin
      LRejected := True;
    end;
  end;
  Check(LRejected, 'Grid overflow rejected before arithmetic');
  SetLength(LFrames, 2);
  LFrames[0] := 2;
  LFrames[1] := 3;
  LAnchors := AlignFeatureAnchors(LFrames, 0, 5, 2, 2);
  Check((LAnchors[0].ErrorFrames = -2) and (LAnchors[1].ErrorFrames = 2),
    'Odd-hop nearest sides preserve inclusive tolerance');
  LAnchors := AlignFeatureAnchors(nil, 0, 1, 1, 0);
  Check(Length(LAnchors) = 0, 'Empty anchor list remains empty');
end;

begin
  try
    Run;
    WriteLn('Integer feature alignment, ties, tolerance and overflow checks passed');
  except
    on LException: Exception do
    begin
      WriteLn(StdErr, LException.Message);
      Halt(1);
    end;
  end;
end.

