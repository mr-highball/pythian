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
unit pythian.alignment;

{$mode delphi}
{$H+}

interface

uses
  pythian.audio;

const
  FeatureAlignmentVersion = 1;
  MaximumFeatureAnchors = 65536;
  MaximumAlignmentCells = 65536;

type
  TFrameAnchors = array of Int64;
  TFeatureAnchor = record
    RequestedFrame: Int64;
    Cell: Integer;
    AlignedFrame: Int64;
    ErrorFrames: Int64;
  end;
  TFeatureAnchors = array of TFeatureAnchor;

{ Absolute frame anchors to the nearest uniform analysis-hop start, ties earlier.
  Arithmetic stays integer above 2^53. Output preserves input order and duplicates.
  Tolerance is explicit and at most floor(hop/2). Out-of-range or over-tolerance
  anchors reject; no clamping or partial mapping. Zero anchors is valid.
  Does not infer beats, transient positions or feature-window uncertainty. }
function AlignFeatureAnchors(const AFrames: TFrameAnchors;
  const AOriginFrame: Int64; const AHopFrames, ACellCount,
  AMaximumErrorFrames: Integer): TFeatureAnchors;

implementation

function AlignFeatureAnchors(const AFrames: TFrameAnchors;
  const AOriginFrame: Int64; const AHopFrames, ACellCount,
  AMaximumErrorFrames: Integer): TFeatureAnchors;
var
  LIndex: Integer;
  LDelta: Int64;
  LCell: Int64;
  LRemainder: Int64;
  LAligned: Int64;
  LCandidate: TFeatureAnchors;
begin
  if (AOriginFrame < 0) or (AHopFrames < 1) or
    (ACellCount < 1) or (ACellCount > MaximumAlignmentCells) or
    (AMaximumErrorFrames < 0) or (AMaximumErrorFrames > AHopFrames div 2) or
    (Length(AFrames) > MaximumFeatureAnchors) then
  begin
    raise EAudio.Create('Feature anchor grid, tolerance or count is outside bounds');
  end;
  if Int64(ACellCount - 1) > (High(Int64) - AOriginFrame) div AHopFrames then
  begin
    raise EAudio.Create('Feature anchor grid exceeds absolute frame range');
  end;
  LCandidate := nil;
  SetLength(LCandidate, Length(AFrames));
  for LIndex := 0 to High(AFrames) do
  begin
    if AFrames[LIndex] < AOriginFrame then
    begin
      raise EAudio.Create('Feature anchor precedes the output grid');
    end;
    LDelta := AFrames[LIndex] - AOriginFrame;
    LCell := LDelta div AHopFrames;
    LRemainder := LDelta mod AHopFrames;
    if LRemainder > AHopFrames div 2 then
    begin
      Inc(LCell);
    end;
    if LCell >= ACellCount then
    begin
      raise EAudio.Create('Nearest feature anchor lies beyond the output grid');
    end;
    LAligned := AOriginFrame + LCell * AHopFrames;
    if Abs(LAligned - AFrames[LIndex]) > AMaximumErrorFrames then
    begin
      raise EAudio.Create('Feature anchor exceeds requested timing tolerance');
    end;
    LCandidate[LIndex].RequestedFrame := AFrames[LIndex];
    LCandidate[LIndex].Cell := LCell;
    LCandidate[LIndex].AlignedFrame := LAligned;
    LCandidate[LIndex].ErrorFrames := LAligned - AFrames[LIndex];
  end;
  Result := LCandidate;
end;

end.
