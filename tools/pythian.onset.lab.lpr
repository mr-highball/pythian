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
program pythian_onset_lab;

{$mode delphi}
{$H+}

uses
  SysUtils,
  Math,
  fpjson,
  pythian.audio,
  pythian.wave,
  pythian.oscillator,
  pythian.analysis,
  pythian.activity,
  pythian.onset,
  pythian.tools.files;

const
  CRate = 44100;
  CFrames = 88200;
  CEvents: array[0..3] of Integer = (5093, 19117, 42071, 65003);
  CTolerance = 1102;
  CNames: array[0..4] of String =
    ('square', 'slow-sine', 'percussion-bed', 'pitch-change', 'close-percussion');

type
  TFramePositions = array of Integer;

function MakeCase(const ACase: Integer; out ATruth: TFramePositions): TAudioClip;
var
  LSamples: TAudioSamples;
  LSignal: TOscillator;
  LNoise: TOscillator;
  LBed: TOscillator;
  LFrame: Integer;
  LEvent: Integer;
  LAge: Integer;
  LValue: Double;
  LBackground: Double;
  LEnvelope: Double;
  LFrequency: Double;
  LOffset: Integer;
  LEvents: TFramePositions;
begin
  LSignal := nil;
  LNoise := nil;
  LBed := nil;
  try
    LSignal := TOscillator.Create(CRate, 731);
    LNoise := TOscillator.Create(CRate, 177);
    LBed := TOscillator.Create(CRate, 991);
    LOffset := 0;
    if ACase in [2, 3] then
    begin
      LOffset := 1;
    end;
    if ACase = 4 then
    begin
      SetLength(LEvents, Length(CEvents) * 2);
      for LEvent := 0 to High(CEvents) do
      begin
        LEvents[LEvent * 2] := CEvents[LEvent];
        LEvents[LEvent * 2 + 1] := CEvents[LEvent] + 2646;
      end;
    end
    else
    begin
      SetLength(LEvents, Length(CEvents));
      for LEvent := 0 to High(CEvents) do
      begin
        LEvents[LEvent] := CEvents[LEvent];
      end;
    end;
    SetLength(ATruth, Length(LEvents) + LOffset);
    if LOffset = 1 then
    begin
      ATruth[0] := 0;
    end;
    for LEvent := 0 to High(LEvents) do
    begin
      ATruth[LEvent + LOffset] := LEvents[LEvent];
    end;
    SetLength(LSamples, CFrames * 2);
    LEvent := -1;
    for LFrame := 0 to CFrames - 1 do
    begin
      if (LEvent < High(LEvents)) and (LFrame = LEvents[LEvent + 1]) then
      begin
        Inc(LEvent);
        if ACase <> 3 then
        begin
          LSignal.Reset(731);
          LNoise.Reset(177 + LEvent);
        end;
      end;
      LValue := 0;
      LBackground := 0;
      LAge := -1;
      if LEvent >= 0 then
      begin
        LAge := LFrame - LEvents[LEvent];
      end;
      case ACase of
        0:
        begin
          if (LAge >= 0) and (LAge < 4410) then
          begin
            LValue := 0.3 * LSignal.Next(wsSquare, 220);
          end;
        end;
        1:
        begin
          if (LAge >= 0) and (LAge < 4410) then
          begin
            LEnvelope := Min(1, LAge / 882);
            LValue := 0.3 * LEnvelope * LSignal.Next(wsSine, 440);
          end;
        end;
        2, 4:
        begin
          if ACase = 2 then
          begin
            LBackground := 0.05 * LBed.Next(wsSine, 110);
          end;
          if (LAge >= 0) and (LAge < 2205) then
          begin
            LValue := 0.55 * (1 - LAge / 2205) * LNoise.Next(wsNoise, 0);
          end;
        end;
        3:
        begin
          LFrequency := 220;
          if LEvent >= 0 then
          begin
            LFrequency := 330 + LEvent * 110;
          end;
          LValue := 0.3 * LSignal.Next(wsSquare, LFrequency);
        end;
      end;
      LSamples[LFrame * 2] := LBackground + LValue;
      LSamples[LFrame * 2 + 1] := LBackground - LValue;
    end;
    Result := TAudioClip.Create(CRate, 2, LSamples);
  finally
    LBed.Free;
    LNoise.Free;
    LSignal.Free;
  end;
end;

function PositionsJson(const APositions: TFramePositions): TJSONArray;
var
  LIndex: Integer;
begin
  Result := TJSONArray.Create;
  for LIndex := 0 to High(APositions) do
  begin
    Result.Add(APositions[LIndex]);
  end;
end;

function Metrics(const ATruth, APredictions: TFramePositions): TJSONObject;
var
  LReference: Integer;
  LPrediction: Integer;
  LBest: Integer;
  LError: Integer;
  LSum: Int64;
  LMatched: Integer;
  LMatches: TJSONArray;
  LMisses: TJSONArray;
  LMatch: TJSONObject;
begin
  { These laboratory references have disjoint tolerance intervals. Selecting
    the closest prediction per reference is therefore one-to-one; duplicate
    predictions count as false positives. No general overlapping-event matcher
    or inferred annotation is hidden in this controlled benchmark. }
  for LReference := 1 to High(ATruth) do
  begin
    if ATruth[LReference] - ATruth[LReference - 1] <= CTolerance * 2 then
    begin
      raise EAudio.Create('Laboratory reference tolerance intervals must be disjoint');
    end;
  end;
  Result := TJSONObject.Create;
  LMatches := TJSONArray.Create;
  Result.Add('matches', LMatches);
  LMisses := TJSONArray.Create;
  Result.Add('missed_reference_frames', LMisses);
  LMatched := 0;
  LSum := 0;
  for LReference := 0 to High(ATruth) do
  begin
    LBest := -1;
    LError := CTolerance + 1;
    for LPrediction := 0 to High(APredictions) do
    begin
      if Abs(APredictions[LPrediction] - ATruth[LReference]) < LError then
      begin
        LBest := LPrediction;
        LError := Abs(APredictions[LPrediction] - ATruth[LReference]);
      end;
    end;
    if LBest >= 0 then
    begin
      Inc(LMatched);
      Inc(LSum, LError);
      LMatch := TJSONObject.Create;
      LMatches.Add(LMatch);
      LMatch.Add('reference_frame', ATruth[LReference]);
      LMatch.Add('prediction_frame', APredictions[LBest]);
      LMatch.Add('error_frames', APredictions[LBest] - ATruth[LReference]);
    end
    else
    begin
      LMisses.Add(ATruth[LReference]);
    end;
  end;
  Result.Add('references', Length(ATruth));
  Result.Add('predictions', Length(APredictions));
  Result.Add('matched', LMatched);
  Result.Add('missed', Length(ATruth) - LMatched);
  Result.Add('false_positive', Length(APredictions) - LMatched);
  if LMatched > 0 then
  begin
    Result.Add('mean_absolute_error_frames', LSum / LMatched);
  end
  else
  begin
    Result.Add('mean_absolute_error_frames', TJSONNull.Create);
  end;
end;

procedure Run(const APrefix: String; const AAnalysis: TAnalysisOptions);
var
  LRaw: TAudioClip;
  LClip: TAudioClip;
  LBytes: TAudioBytes;
  LTruth: TFramePositions;
  LCoarse: TFramePositions;
  LRefined: TFramePositions;
  LFeatures: TAudioFeatures;
  LActivity: TAcousticActivity;
  LLocations: TOnsetLocations;
  LOptions: TOnsetLocationOptions;
  LDocument: TJSONObject;
  LCases: TJSONArray;
  LCaseJson: TJSONObject;
  LWindows: TJSONArray;
  LWindow: TJSONObject;
  LCoarseMetrics: TJSONObject;
  LRefinedMetrics: TJSONObject;
  LCase: Integer;
  LIndex: Integer;
  LCount: Integer;
  LName: String;
  LFeatureCount: Integer;
  LWork: Int64;
begin
  PlanAudioAnalysis(CFrames, 2, AAnalysis, LFeatureCount, LWork);
  LDocument := TJSONObject.Create;
  try
    LOptions := DefaultOnsetLocationOptions(CRate);
    LDocument.Add('version', 1);
    LDocument.Add('sample_rate', CRate);
    LDocument.Add('analysis_window', AAnalysis.WindowFrames);
    LDocument.Add('analysis_hop', AAnalysis.HopFrames);
    LDocument.Add('energy_window', LOptions.EnergyWindowFrames);
    LDocument.Add('tolerance_frames', CTolerance);
    LDocument.Add('reference', 'Authored source event starts; slow attacks may rise later; not beat annotations');
    LDocument.Add('baseline', 'Feature-window starts treated as points; original window coverage is not scored');
    LCases := TJSONArray.Create;
    LDocument.Add('cases', LCases);
    for LCase := 0 to High(CNames) do
    begin
      LRaw := MakeCase(LCase, LTruth);
      LClip := nil;
      try
        LBytes := EncodeWavePcm16(LRaw);
        LClip := DecodeWave(LBytes);
        LName := APrefix + '-' + CNames[LCase] + '.wav';
        WriteFileBytes(LName, LBytes);
        LFeatures := AnalyzeAudio(LClip, AAnalysis);
        LActivity := AnalyzeAcousticActivity(LFeatures, AAnalysis, LClip.FrameCount,
          DefaultActivityOptions);
        LLocations := LocalizeAcousticOnsets(LClip, LFeatures, AAnalysis,
          DefaultActivityOptions, LOptions);
        SetLength(LCoarse, Length(LActivity.Actions));
        LCount := 0;
        for LIndex := 0 to High(LActivity.Actions) do
        begin
          if LActivity.Actions[LIndex] = aaOnset then
          begin
            LCoarse[LCount] := LFeatures[LIndex].StartFrame;
            Inc(LCount);
          end;
        end;
        SetLength(LCoarse, LCount);
        SetLength(LRefined, Length(LLocations));
        LCount := 0;
        LCaseJson := TJSONObject.Create;
        LCases.Add(LCaseJson);
        LCaseJson.Add('name', CNames[LCase]);
        LCaseJson.Add('source_file', ExtractFileName(LName));
        LCaseJson.Add('source_sha256', HashAudioBytes(LBytes));
        LCaseJson.Add('reference_frames', PositionsJson(LTruth));
        LWindows := TJSONArray.Create;
        LCaseJson.Add('locations', LWindows);
        for LIndex := 0 to High(LLocations) do
        begin
          if LLocations[LIndex].Resolved then
          begin
            LRefined[LCount] := LLocations[LIndex].Frame;
            Inc(LCount);
          end;
          LWindow := TJSONObject.Create;
          LWindows.Add(LWindow);
          LWindow.Add('feature_index', LLocations[LIndex].FeatureIndex);
          LWindow.Add('window_start', LLocations[LIndex].WindowStartFrame);
          LWindow.Add('window_frames', LLocations[LIndex].WindowFrameCount);
          LWindow.Add('frame', LLocations[LIndex].Frame);
          LWindow.Add('resolved', LLocations[LIndex].Resolved);
          LWindow.Add('context_clipped', LLocations[LIndex].ContextClipped);
          LWindow.Add('search_boundary', LLocations[LIndex].SearchBoundary);
          LWindow.Add('energy_rise', LLocations[LIndex].EnergyRise);
          LWindow.Add('contrast', LLocations[LIndex].Contrast);
        end;
        SetLength(LRefined, LCount);
        LCoarseMetrics := Metrics(LTruth, LCoarse);
        LRefinedMetrics := Metrics(LTruth, LRefined);
        LCaseJson.Add('coarse', LCoarseMetrics);
        LCaseJson.Add('localized', LRefinedMetrics);
        WriteLn(CNames[LCase], ': references=', Length(LTruth),
          ' coarse=', LCoarseMetrics.Get('matched', 0), '/', Length(LCoarse),
          ' localized=', LRefinedMetrics.Get('matched', 0), '/', Length(LRefined),
          ' unresolved=', Length(LLocations) - Length(LRefined));
      finally
        LClip.Free;
        LRaw.Free;
      end;
    end;
    WriteTextFile(APrefix + '.json', LDocument.FormatJSON);
  finally
    LDocument.Free;
  end;
end;

var
  LAnalysis: TAnalysisOptions;
begin
  try
    if (ParamCount <> 1) and (ParamCount <> 3) then
    begin
      raise EAudio.Create('Usage: pythian.onset.lab OUTPUT_PREFIX [WINDOW_FRAMES HOP_FRAMES]');
    end;
    LAnalysis := DefaultAnalysisOptions;
    if ParamCount = 3 then
    begin
      LAnalysis.WindowFrames := StrToInt(ParamStr(2));
      LAnalysis.HopFrames := StrToInt(ParamStr(3));
    end;
    Run(ParamStr(1), LAnalysis);
  except
    on LException: Exception do
    begin
      WriteLn(StdErr, LException.ClassName, ': ', LException.Message);
      Halt(1);
    end;
  end;
end.
