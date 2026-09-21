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
unit pythian.beat.wave;

{$mode delphi}
{$H+}

interface

uses
  pythian.audio,
  pythian.analysis,
  pythian.activity,
  pythian.onset,
  pythian.onset.events,
  pythian.beat;

type
  TWaveBeatEvidence = record
    AnalysisOptions: TAnalysisOptions;
    ActivityOptions: TActivityOptions;
    LocationOptions: TOnsetLocationOptions;
    EventOptions: TOnsetEventOptions;
    Locations: TOnsetLocations;
    Events: TOnsetEventPlan;
    Observations: TBeatObservations;
    Grid: TBeatGridAnalysis;
  end;

{ Shared native onset-localization and pulse-ranking path. Retains every policy
  and admission decision. Source bytes/identity and candidate selection belong
  to the caller. No meter, downbeat or automatic confidence admission. }
function MeasureWaveBeats(const AClip: TAudioClip;
  const AOptions: TBeatGridOptions): TWaveBeatEvidence;

implementation

uses
  Math;

function MeasureWaveBeats(const AClip: TAudioClip;
  const AOptions: TBeatGridOptions): TWaveBeatEvidence;
var
  LResult: TWaveBeatEvidence;
  LFeatures: TAudioFeatures;
  LPeak: Double;
  LIndex: Integer;
  LPoint: Integer;
begin
  if AClip = nil then
  begin
    raise EAudio.Create('Beat measurement requires a WAV clip');
  end;
  LResult := Default(TWaveBeatEvidence);
  LResult.Grid := EstimateBeatGrids(nil, AClip.SampleRate, AClip.FrameCount, AOptions);
  LResult.AnalysisOptions := DefaultOnsetAnalysisOptions(AClip.SampleRate);
  LResult.ActivityOptions := DefaultActivityOptions;
  LResult.LocationOptions := DefaultOnsetLocationOptions(AClip.SampleRate);
  LResult.EventOptions := DefaultOnsetEventOptions(AClip.SampleRate);
  LFeatures := AnalyzeAudio(AClip, LResult.AnalysisOptions);
  LResult.Locations := LocalizeAcousticOnsets(AClip, LFeatures, LResult.AnalysisOptions,
    LResult.ActivityOptions, LResult.LocationOptions);
  LResult.Events := PlanOnsetEvents(LResult.Locations, AClip.FrameCount, LResult.EventOptions);
  SetLength(LResult.Observations, Length(LResult.Events.Bounds) - 2);
  LPeak := 0;
  for LIndex := 0 to High(LResult.Observations) do
  begin
    LPoint := LResult.Events.LocationIndices[LIndex + 1];
    LResult.Observations[LIndex].Frame := LResult.Locations[LPoint].Frame;
    LResult.Observations[LIndex].Weight := Sqrt(LResult.Locations[LPoint].EnergyRise);
    LPeak := Max(LPeak, LResult.Observations[LIndex].Weight);
  end;
  if LPeak > 0 then
  begin
    for LIndex := 0 to High(LResult.Observations) do
    begin
      LResult.Observations[LIndex].Weight := LResult.Observations[LIndex].Weight / LPeak;
    end;
  end;
  LResult.Grid := EstimateBeatGrids(LResult.Observations,
    AClip.SampleRate, AClip.FrameCount, AOptions);
  Result := LResult;
end;

end.
