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
program pythian_onsets;

{$mode delphi}
{$H+}

uses
  SysUtils,
  Math,
  fpjson,
  pythian.audio,
  pythian.wave,
  pythian.tools.cues,
  pythian.analysis,
  pythian.activity,
  pythian.onset,
  pythian.tools.files;

procedure WriteAudition(const AClip: TAudioClip; const ALocations: TOnsetLocations;
  const AFileName: String; const ADocument: TJSONObject);
var
  LFrames: TCueFrames;
  LIndex: Integer;
  LCount: Integer;
begin
  SetLength(LFrames, Length(ALocations));
  LCount := 0;
  for LIndex := 0 to High(ALocations) do
  begin
    if ALocations[LIndex].Resolved then
    begin
      LFrames[LCount] := ALocations[LIndex].Frame;
      Inc(LCount);
    end;
  end;
  SetLength(LFrames, LCount);
  WriteCueAudition(AClip, LFrames, AFileName,
    'Resolved energy-rise locations marked by decaying sine cues; source duration and channels retained',
    ADocument);
end;

procedure Run(const AInput, AOutput, AAudition: String;
  const AOverrideAnalysis, AMeasureValleys: Boolean; const AAnalysis: TAnalysisOptions);
var
  LClip: TAudioClip;
  LSourceHash: String;
  LFeatures: TAudioFeatures;
  LLocations: TOnsetLocations;
  LAnalysis: TAnalysisOptions;
  LActivity: TActivityOptions;
  LOptions: TOnsetLocationOptions;
  LDocument: TJSONObject;
  LSettings: TJSONObject;
  LRows: TJSONArray;
  LRow: TJSONObject;
  LIndex: Integer;
  LResolved: Integer;
  LClipped: Integer;
  LValleyOptions: TEnvelopeValleyOptions;
  LValleys: TEnvelopeValleys;
begin
  if SameFileName(ExpandFileName(AInput), ExpandFileName(AOutput)) then
  begin
    raise EAudio.Create('Onset report must not overwrite the source WAV');
  end;
  if (AAudition <> '') and
    (SameFileName(ExpandFileName(AInput), ExpandFileName(AAudition)) or
    SameFileName(ExpandFileName(AOutput), ExpandFileName(AAudition))) then
  begin
    raise EAudio.Create('Onset audition, report and source require distinct filenames');
  end;
  LClip := nil;
  LDocument := nil;
  try
    LClip := LoadWaveSource(AInput, LSourceHash);
    if AMeasureValleys then
    begin
      LValleyOptions := DefaultEnvelopeValleyOptions(LClip.SampleRate);
      LValleys := MeasureEnvelopeValleys(LClip, LValleyOptions);
    end;
    LAnalysis := DefaultOnsetAnalysisOptions(LClip.SampleRate);
    if AOverrideAnalysis then
    begin
      LAnalysis := AAnalysis;
    end;
    LActivity := DefaultActivityOptions;
    LOptions := DefaultOnsetLocationOptions(LClip.SampleRate);
    LFeatures := AnalyzeAudio(LClip, LAnalysis);
    LLocations := LocalizeAcousticOnsets(LClip, LFeatures, LAnalysis, LActivity, LOptions);
    LDocument := TJSONObject.Create;
    LDocument.Add('version', OnsetLocationVersion);
    LDocument.Add('source', ExtractFileName(AInput));
    LDocument.Add('source_sha256', LSourceHash);
    LDocument.Add('sample_rate', LClip.SampleRate);
    LDocument.Add('source_frames', LClip.FrameCount);
    LDocument.Add('channels', LClip.Channels);
    LDocument.Add('analysis_window', LAnalysis.WindowFrames);
    LDocument.Add('analysis_hop', LAnalysis.HopFrames);
    LDocument.Add('silence_rms', LAnalysis.SilenceRms);
    LSettings := TJSONObject.Create;
    LDocument.Add('activity_policy', LSettings);
    LSettings.Add('minimum_flux', LActivity.MinimumFlux);
    LSettings.Add('adaptive_multiplier', LActivity.AdaptiveMultiplier);
    LSettings.Add('history_features', LActivity.HistoryFeatures);
    LSettings.Add('peak_radius', LActivity.PeakRadius);
    LSettings.Add('minimum_separation_features', LActivity.MinimumSeparationFeatures);
    LSettings.Add('maximum_segment_features', LActivity.MaximumSegmentFeatures);
    LDocument.Add('energy_window_frames', LOptions.EnergyWindowFrames);
    LDocument.Add('minimum_energy_rise', LOptions.MinimumEnergyRise);
    LDocument.Add('minimum_contrast', LOptions.MinimumContrast);
    LDocument.Add('interpretation',
      'Local energy-rise timing estimates; unresolved spectral changes remain candidates; no beat inference');
    LRows := TJSONArray.Create;
    LDocument.Add('locations', LRows);
    LResolved := 0;
    LClipped := 0;
    for LIndex := 0 to High(LLocations) do
    begin
      LRow := TJSONObject.Create;
      LRows.Add(LRow);
      LRow.Add('feature_index', LLocations[LIndex].FeatureIndex);
      LRow.Add('window_start', LLocations[LIndex].WindowStartFrame);
      LRow.Add('window_frames', LLocations[LIndex].WindowFrameCount);
      LRow.Add('resolved', LLocations[LIndex].Resolved);
      LRow.Add('frame', LLocations[LIndex].Frame);
      LRow.Add('context_clipped', LLocations[LIndex].ContextClipped);
      LRow.Add('search_boundary', LLocations[LIndex].SearchBoundary);
      LRow.Add('before_rms', LLocations[LIndex].BeforeRms);
      LRow.Add('after_rms', LLocations[LIndex].AfterRms);
      LRow.Add('energy_rise', LLocations[LIndex].EnergyRise);
      LRow.Add('contrast', LLocations[LIndex].Contrast);
      if LLocations[LIndex].Resolved then
      begin
        Inc(LResolved);
        if LLocations[LIndex].ContextClipped then
        begin
          Inc(LClipped);
        end;
      end;
    end;
    LDocument.Add('candidates', Length(LLocations));
    LDocument.Add('resolved', LResolved);
    LDocument.Add('resolved_with_clipped_context', LClipped);
    if AMeasureValleys then
    begin
      LSettings := TJSONObject.Create;
      LDocument.Add('envelope_valley_policy', LSettings);
      LSettings.Add('energy_window_frames', LValleyOptions.EnergyWindowFrames);
      LSettings.Add('hop_frames', LValleyOptions.HopFrames);
      LSettings.Add('minimum_radius_points', LValleyOptions.MinimumRadiusPoints);
      LSettings.Add('peak_radius_points', LValleyOptions.PeakRadiusPoints);
      LSettings.Add('minimum_peak_rms', LValleyOptions.MinimumPeakRms);
      LSettings.Add('minimum_depth', LValleyOptions.MinimumDepth);
      LSettings.Add('interpretation', 'Complete-window RMS valleys with flanking peaks; modulation and noise may qualify; no note-attack admission or pitch ownership');
      LRows := TJSONArray.Create;
      LDocument.Add('envelope_valleys', LRows);
      for LIndex := 0 to High(LValleys) do
      begin
        LRow := TJSONObject.Create;
        LRows.Add(LRow);
        LRow.Add('frame', LValleys[LIndex].Frame);
        LRow.Add('left_peak_frame', LValleys[LIndex].LeftPeakFrame);
        LRow.Add('right_peak_frame', LValleys[LIndex].RightPeakFrame);
        LRow.Add('rms', LValleys[LIndex].Rms);
        LRow.Add('left_peak_rms', LValleys[LIndex].LeftPeakRms);
        LRow.Add('right_peak_rms', LValleys[LIndex].RightPeakRms);
        LRow.Add('depth', LValleys[LIndex].Depth);
      end;
    end;
    if AAudition <> '' then
    begin
      WriteAudition(LClip, LLocations, AAudition, LDocument);
    end;
    WriteTextFile(AOutput, LDocument.FormatJSON);
    WriteLn(Length(LLocations), ' original candidates; ', LResolved,
      ' energy-rise locations; ', LClipped, ' with clipped context');
  finally
    LDocument.Free;
    LClip.Free;
  end;
end;

procedure Main;
var
  LAnalysis: TAnalysisOptions;
  LOverride: Boolean;
  LValleys: Boolean;
  LAudition: String;
  LArgument: Integer;
begin
  if ParamCount < 2 then
  begin
    raise EAudio.Create('Usage: pythian.onsets INPUT.wav OUTPUT.json ' +
      '[WINDOW_FRAMES HOP_FRAMES] [--valleys] [--audition OUTPUT.wav]');
  end;
  LAnalysis := DefaultAnalysisOptions;
  LOverride := False;
  LValleys := False;
  LAudition := '';
  LArgument := 3;
  if (LArgument <= ParamCount) and (Copy(ParamStr(LArgument), 1, 2) <> '--') then
  begin
    LAnalysis.WindowFrames := StrToInt(ParamStr(LArgument));
    LAnalysis.HopFrames := StrToInt(ParamStr(LArgument + 1));
    LOverride := True;
    Inc(LArgument, 2);
  end;
  while LArgument <= ParamCount do
  begin
    if (ParamStr(LArgument) = '--valleys') and not LValleys then
    begin
      LValleys := True;
      Inc(LArgument);
    end
    else if (ParamStr(LArgument) = '--audition') and (LAudition = '') and
      (LArgument < ParamCount) then
    begin
      LAudition := ParamStr(LArgument + 1);
      if LAudition = '' then
      begin
        raise EAudio.Create('Audition output filename must not be empty');
      end;
      Inc(LArgument, 2);
    end
    else
    begin
      raise EAudio.Create('Unknown, duplicate or incomplete onset option');
    end;
  end;
  Run(ParamStr(1), ParamStr(2), LAudition, LOverride, LValleys, LAnalysis);
end;

begin
  try
    Main;
  except
    on LException: Exception do
    begin
      WriteLn(StdErr, LException.ClassName, ': ', LException.Message);
      Halt(1);
    end;
  end;
end.
