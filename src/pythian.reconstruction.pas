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
unit pythian.reconstruction;

{$mode delphi}
{$H+}

interface

uses
  pythian.audio,
  pythian.analysis,
  pythian.learning,
  pythian.granular;

const
  AcousticReconstructionVersion = 1;

{ Plan nearest-centroid exemplar grains, keeping exact source coordinates.
  The caller supplies features from ASource and tokens from APalette.
  AIndices may come from WFC or another caller; this unit has no solver types.
  Partial final analysis windows retain their actual valid length. }
function PlanAcousticGrains(const ASource: TAudioClip; const AFeatures: TAudioFeatures;
  const APalette: TAcousticPalette; const AIndices: TAcousticIndices;
  const AHopFrames: Integer): TAudioGrains;

implementation

function PlanAcousticGrains(const ASource: TAudioClip; const AFeatures: TAudioFeatures;
  const APalette: TAcousticPalette; const AIndices: TAcousticIndices;
  const AHopFrames: Integer): TAudioGrains;
var
  LRepresentatives: TAcousticIndices;
  LIndex: Integer;
  LFeatureIndex: Integer;
begin
  if (ASource = nil) or (APalette = nil) then
  begin
    raise EAudio.Create('Reconstruction requires a source clip and acoustic palette');
  end;
  if (AHopFrames < 1) or (Length(AIndices) > MaximumGrainCount) or
    (Length(AFeatures) = 0) or (Length(AFeatures) > MaximumAnalysisFrames) then
  begin
    raise EAudio.Create('Invalid acoustic reconstruction extent');
  end;
  for LIndex := 0 to High(AFeatures) do
  begin
    if (AFeatures[LIndex].StartFrame < 0) or (AFeatures[LIndex].ValidFrames < 1) or
      (Int64(AFeatures[LIndex].StartFrame) + AFeatures[LIndex].ValidFrames >
      ASource.FrameCount) then
    begin
      raise EAudio.Create('Acoustic feature extends outside reconstruction source');
    end;
  end;
  LRepresentatives := APalette.RepresentativeFrames(AFeatures);
  for LIndex := 0 to High(AIndices) do
  begin
    if (AIndices[LIndex] < 0) or (AIndices[LIndex] >= APalette.Count) then
    begin
      raise EAudio.Create('Reconstruction token does not belong to the palette');
    end;
    LFeatureIndex := LRepresentatives[AIndices[LIndex]];
    if LFeatureIndex < 0 then
    begin
      raise EAudio.Create('Reconstruction token has no source exemplar');
    end;
    if Int64(LIndex) * AHopFrames + AFeatures[LFeatureIndex].ValidFrames >
      MaximumGrainSamples div ASource.Channels then
    begin
      raise EAudio.Create('Acoustic reconstruction exceeds output sample budget');
    end;
  end;
  Result := nil;
  SetLength(Result, Length(AIndices));
  for LIndex := 0 to High(AIndices) do
  begin
    LFeatureIndex := LRepresentatives[AIndices[LIndex]];
    Result[LIndex].SourceIndex := 0;
    Result[LIndex].SourceStartFrame := AFeatures[LFeatureIndex].StartFrame;
    Result[LIndex].OutputStartFrame := LIndex * AHopFrames;
    Result[LIndex].FrameCount := AFeatures[LFeatureIndex].ValidFrames;
    Result[LIndex].PlaybackRate := 1;
    Result[LIndex].Gain := 1;
    Result[LIndex].Window := gwHann;
  end;
end;

end.
