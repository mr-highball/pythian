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
unit pythian.tools.pulses;

{$mode delphi}
{$H+}

interface

uses
  fpjson,
  pythian.onset,
  pythian.onset.events,
  pythian.beat,
  pythian.beat.track,
  pythian.pulse.events,
  pythian.passage;

type
  TPreparedPulseEvents = record
    Observations: TBeatObservations;
    ObservationLocations: TPassageIndices;
    LocationIndices: TPassageIndices;
    Track: TBeatTrack;
    Plan: TPulseEventPlan;
  end;

function PreparePulseEvents(const ALocations: TOnsetLocations; const AOnsets: TOnsetEventPlan;
  const ASampleRate, ASourceFrames: Integer): TPreparedPulseEvents;
function PulseEventsJson(const APrepared: TPreparedPulseEvents;
  const ASampleRate: Integer): TJSONObject;

implementation

uses
  Math,
  pythian.audio,
  pythian.tools.beat.report;

function PreparePulseEvents(const ALocations: TOnsetLocations; const AOnsets: TOnsetEventPlan;
  const ASampleRate, ASourceFrames: Integer): TPreparedPulseEvents;
var
  LPrepared: TPreparedPulseEvents;
  LIndex: Integer;
  LLocation: Integer;
  LPeak: Double;
begin
  if (Length(AOnsets.Bounds) < 2) or
    (Length(AOnsets.LocationIndices) <> Length(AOnsets.Bounds)) then
  begin
    raise EAudio.Create('Pulse preparation requires an admitted onset partition');
  end;
  SetLength(LPrepared.Observations, Length(AOnsets.Bounds) - 2);
  SetLength(LPrepared.ObservationLocations, Length(LPrepared.Observations));
  LPeak := 0;
  for LIndex := 0 to High(LPrepared.Observations) do
  begin
    LLocation := AOnsets.LocationIndices[LIndex + 1];
    if (LLocation < 0) or (LLocation >= Length(ALocations)) then
    begin
      raise EAudio.Create('Pulse source location identity is invalid');
    end;
    RequireFinite(ALocations[LLocation].EnergyRise, 'Pulse source energy rise');
    if ALocations[LLocation].EnergyRise <= 0 then
    begin
      raise EAudio.Create('Pulse source energy rise must be positive');
    end;
    LPrepared.ObservationLocations[LIndex] := LLocation;
    LPrepared.Observations[LIndex].Frame := ALocations[LLocation].Frame;
    LPrepared.Observations[LIndex].Weight := Sqrt(ALocations[LLocation].EnergyRise);
    LPeak := Max(LPeak, LPrepared.Observations[LIndex].Weight);
  end;
  for LIndex := 0 to High(LPrepared.Observations) do
  begin
    LPrepared.Observations[LIndex].Weight := LPrepared.Observations[LIndex].Weight / LPeak;
  end;
  LPrepared.Track := TrackBeatGrids(LPrepared.Observations, ASampleRate, ASourceFrames,
    DefaultBeatGridOptions, DefaultBeatTrackOptions(ASampleRate));
  LPrepared.Plan := PlanPulseEvents(LPrepared.Track, LPrepared.Observations,
    ASourceFrames, DefaultPulseEventOptions);
  SetLength(LPrepared.LocationIndices, Length(LPrepared.Track.Frames));
  for LIndex := 0 to High(LPrepared.LocationIndices) do
  begin
    LLocation := LPrepared.Track.ObservationIndices[LIndex];
    LPrepared.LocationIndices[LIndex] := -1;
    if LLocation >= 0 then
    begin
      LPrepared.LocationIndices[LIndex] := LPrepared.ObservationLocations[LLocation];
    end;
  end;
  Result := LPrepared;
end;

function PulseEventsJson(const APrepared: TPreparedPulseEvents;
  const ASampleRate: Integer): TJSONObject;
var
  LDocument: TJSONObject;
  LRows: TJSONArray;
  LRow: TJSONObject;
  LSettings: TJSONObject;
  LGrid: TBeatGridOptions;
  LPolicy: TPulseEventOptions;
  LIndex: Integer;
begin
  LDocument := TJSONObject.Create;
  try
    LPolicy := DefaultPulseEventOptions;
    LGrid := DefaultBeatGridOptions;
    LDocument.Add('version', PulseEventVersion);
    LDocument.Add('minimum_period_ratio', LPolicy.MinimumPeriodRatio);
    LDocument.Add('maximum_period_ratio', LPolicy.MaximumPeriodRatio);
    LDocument.Add('require_aligned_endpoints', LPolicy.RequireAlignedEndpoints);
    LDocument.Add('run_count', APrepared.Plan.RunCount);
    LDocument.Add('selected_count', APrepared.Plan.SelectedCount);
    LDocument.Add('weight_policy', 'Square root of admitted energy rise divided by its maximum');
    LSettings := TJSONObject.Create;
    LDocument.Add('grid_policy', LSettings);
    LSettings.Add('version', BeatGridVersion);
    LSettings.Add('measurement_policy', BeatGridMeasurementPolicy);
    LSettings.Add('minimum_bpm', LGrid.MinimumBpm);
    LSettings.Add('maximum_bpm', LGrid.MaximumBpm);
    LSettings.Add('step_bpm', LGrid.StepBpm);
    LSettings.Add('minimum_separation_bpm', LGrid.MinimumSeparationBpm);
    LSettings.Add('tolerance_seconds', LGrid.ToleranceSeconds);
    LSettings.Add('minimum_matched_weight', LGrid.MinimumMatchedWeight);
    LSettings.Add('minimum_cycles', LGrid.MinimumCycles);
    LSettings.Add('maximum_candidates', LGrid.MaximumCandidates);
    LDocument.Add('track', TrackJson(APrepared.Track, DefaultBeatTrackOptions(ASampleRate)));
    LRows := TJSONArray.Create;
    LDocument.Add('observations', LRows);
    for LIndex := 0 to High(APrepared.Observations) do
    begin
      LRow := TJSONObject.Create;
      LRows.Add(LRow);
      LRow.Add('frame', APrepared.Observations[LIndex].Frame);
      LRow.Add('weight', APrepared.Observations[LIndex].Weight);
      LRow.Add('location_index', APrepared.ObservationLocations[LIndex]);
    end;
    LRows := TJSONArray.Create;
    LDocument.Add('intervals', LRows);
    for LIndex := 0 to High(APrepared.Plan.Decisions) do
    begin
      LRow := TJSONObject.Create;
      LRows.Add(LRow);
      LRow.Add('start_point', LIndex);
      LRow.Add('end_point', LIndex + 1);
      LRow.Add('decision', PulseEventDecisionName(APrepared.Plan.Decisions[LIndex]));
      LRow.Add('run_index', APrepared.Plan.RunIndices[LIndex]);
    end;
    Result := LDocument;
  except
    LDocument.Free;
    raise;
  end;
end;

end.
