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
unit pythian.tools.events;

{$mode delphi}
{$H+}

interface

uses
  fpjson, pythian.audio, pythian.onset;

function ReadLocations(const ADocument: TJSONObject; const ASource: TAudioClip;
  const ASourceHash: String): TOnsetLocations;

implementation

uses
  Math, pythian.analysis;

function ReadLocations(const ADocument: TJSONObject; const ASource: TAudioClip;
  const ASourceHash: String): TOnsetLocations;
var
  LRows: TJSONArray;
  LRow: TJSONObject;
  LLocations: TOnsetLocations;
  LAnalysis: TAnalysisOptions;
  LFeatureCount: Integer;
  LWork: Int64;
  LIndex: Integer;
begin
  if (ADocument.Integers['version'] <> OnsetLocationVersion) or
    (ADocument.Strings['source_sha256'] <> ASourceHash) or
    (ADocument.Integers['sample_rate'] <> ASource.SampleRate) or
    (ADocument.Integers['source_frames'] <> ASource.FrameCount) or
    (ADocument.Integers['channels'] <> ASource.Channels) then
  begin
    raise EAudio.Create('Onset report does not identify this exact source and supported contract');
  end;
  LAnalysis.WindowFrames := ADocument.Integers['analysis_window'];
  LAnalysis.HopFrames := ADocument.Integers['analysis_hop'];
  LAnalysis.SilenceRms := ADocument.Floats['silence_rms'];
  PlanAudioAnalysis(ASource.FrameCount, ASource.Channels, LAnalysis, LFeatureCount, LWork);
  LRows := ADocument.Arrays['locations'];
  if LRows.Count > MaximumAnalysisFrames then
  begin
    raise EAudio.Create('Onset report exceeds the candidate budget');
  end;
  SetLength(LLocations, LRows.Count);
  for LIndex := 0 to LRows.Count - 1 do
  begin
    LRow := LRows.Objects[LIndex];
    LLocations[LIndex].FeatureIndex := LRow.Integers['feature_index'];
    LLocations[LIndex].WindowStartFrame := LRow.Integers['window_start'];
    LLocations[LIndex].WindowFrameCount := LRow.Integers['window_frames'];
    LLocations[LIndex].Frame := LRow.Integers['frame'];
    LLocations[LIndex].EnergyRise := LRow.Floats['energy_rise'];
    LLocations[LIndex].Resolved := LRow.Booleans['resolved'];
    LLocations[LIndex].ContextClipped := LRow.Booleans['context_clipped'];
    LLocations[LIndex].SearchBoundary := LRow.Booleans['search_boundary'];
    if (LLocations[LIndex].FeatureIndex < 0) or
      (LLocations[LIndex].FeatureIndex >= LFeatureCount) or
      (LLocations[LIndex].WindowStartFrame <>
        Int64(LLocations[LIndex].FeatureIndex) * LAnalysis.HopFrames) or
      (LLocations[LIndex].WindowFrameCount <> Min(LAnalysis.WindowFrames,
        ASource.FrameCount - LLocations[LIndex].WindowStartFrame)) then
    begin
      raise EAudio.Create('Onset report location does not match its declared analysis grid');
    end;
  end;
  Result := LLocations;
end;

end.
