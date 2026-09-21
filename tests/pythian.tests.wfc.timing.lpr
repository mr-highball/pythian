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
program pythian.tests.wfc.timing;

{$mode delphi}
{$H+}

uses
  SysUtils,
  fpjson,
  jsonparser,
  pythian.audio,
  pythian.wave,
  pythian.articulation,
  pythian.activity,
  pythian.learning,
  pythian.corpus,
  pythian.corpus.archive,
  pythian.alignment,
  pythian.wfc.generation,
  pythian.wfc.joint,
  pythian.wfc.joint.archive,
  pythian.wfc.timing,
  pythian.tools.files,
  wfc,
  wfc_model,
  wfc_sequence,
  wfc_sequence_learn;

procedure Check(const ACondition: Boolean; const AMessage: String);
begin
  if not ACondition then
  begin
    raise EAudio.Create(AMessage);
  end;
end;

procedure CheckTiming;
var
  LGates: TArticulationGates;
  LArticulation: TArticulationPlan;
  LPlan: TJointAttackPlan;
  LTokens: TWfcModelTokens;
  LSamples: TWfcSequenceSamples;
  LModel: TWfcSequenceModel;
  LSequence: TJointSequence;
  LGeneration: TAcousticGenerationOptions;
  LSolve: TGraphSolveReport;
  LIndex: Integer;
  LRejected: Boolean;
begin
  SetLength(LGates, 4);
  LGates[0].StartFrame := 0;
  LGates[0].EndFrame := 25;
  LGates[0].Gain := 1;
  LGates[1].StartFrame := 100;
  LGates[1].EndFrame := 125;
  LGates[1].Gain := 0.5;
  LGates[2] := LGates[1];
  LGates[2].EndFrame := 150;
  LGates[3].StartFrame := 5;
  LGates[3].EndFrame := 7;
  LGates[3].Gain := 0;
  LArticulation := TArticulationPlan.Create(100, 200, 1, 1, LGates);
  try
    LPlan := PlanJointAttacks(LArticulation, 10, 0);
    Check((LPlan.CellCount = 20) and (Length(LPlan.Anchors) = 3) and
      (Length(LPlan.Constraints) = 2), 'Coincident attacks deduplicate; zero-gain gates omitted');
    Check((LPlan.Constraints[0].Position = 0) and (LPlan.Constraints[1].Position = 10) and
      (LPlan.Constraints[1].AllowedActions = [aaOnset]), 'Exact source-label locks at output attacks');
  finally
    LArticulation.Free;
  end;
  LGates[2].StartFrame := 104;
  LArticulation := TArticulationPlan.Create(100, 200, 1, 1, LGates);
  try
    LRejected := False;
    try
      LPlan := PlanJointAttacks(LArticulation, 10, 5);
    except
      on EAudio do
      begin
        LRejected := True;
      end;
    end;
    Check(LRejected and (Length(LPlan.Constraints) = 2) and
      (LPlan.Anchors[2].RequestedFrame = 100), 'Distinct attack collision preserves previous plan');
  finally
    LArticulation.Free;
  end;
  SetLength(LSamples, 1);
  SetLength(LTokens, 30);
  for LIndex := 0 to High(LTokens) do
  begin
    if LIndex mod 3 = 0 then
    begin
      LTokens[LIndex] := JointAcousticToken(0, aaOnset);
    end
    else
    begin
      LTokens[LIndex] := JointAcousticToken(0, aaSustain);
    end;
  end;
  LSamples[0] := MakeWfcSequenceSample(LTokens);
  LModel := LearnSequenceModelCorpus(LSamples, 2, wmbOpen);
  try
    LGeneration := DefaultAcousticGenerationOptions;
    LGeneration.FrameCount := LPlan.CellCount;
    Check(TryGenerateJointSequence(LModel, LGeneration, LPlan.Constraints, LSequence, LSolve),
      'Actual WFC accepts the mapped attack constraints');
    Check((LSequence.Actions[0] = aaOnset) and (LSequence.Actions[10] = aaOnset),
      'Generated observations honor both timed locks');
  finally
    LModel.Free;
  end;
  for LIndex := 0 to High(LTokens) do
  begin
    LTokens[LIndex] := JointAcousticToken(0, aaSustain);
  end;
  LSamples[0] := MakeWfcSequenceSample(LTokens);
  LModel := LearnSequenceModelCorpus(LSamples, 2, wmbOpen);
  try
    Check(not TryGenerateJointSequence(LModel, LGeneration, LPlan.Constraints, LSequence, LSolve),
      'Unobserved onset lock is not relaxed');
    Check((LSolve.Status = gssContradiction) and (LSequence.Actions[10] = aaOnset),
      'Contradiction preserves the previous generated sequence');
  finally
    LModel.Free;
  end;
end;

procedure CheckPublished;
const
  ExpectedCells: array[0..3] of Integer = (0, 43, 86, 129);
  ExpectedErrors: array[0..3] of Integer = (0, -68, -136, -204);
var
  LBytes: TAudioBytes;
  LText: UTF8String;
  LDocument: TJSONData;
  LRoot: TJSONObject;
  LTiming: TJSONObject;
  LAnchors: TJSONArray;
  LGrains: TJSONArray;
  LCorpus: TAcousticCorpusData;
  LModel: TWfcSequenceModel;
  LActivity: TActivityOptions;
  LMeasured: TAcousticActivity;
  LRecording: TAcousticRecording;
  LActions: array of TAcousticActions;
  LTokens: array of TAcousticIndices;
  LClip: TAudioClip;
  LIndex: Integer;
  LFrame: Integer;
  LSource: Integer;
  LChannel: Integer;
  LRestFrames: Integer;
  LActiveEnergy: Double;
begin
  LBytes := ReadFileBytes(ParamStr(1), MaximumCorpusArchiveBytes);
  LCorpus := DecodeWfcJointCorpus(LBytes, LModel, LActivity);
  LDocument := nil;
  LClip := nil;
  try
    LBytes := ReadFileBytes(ParamStr(2), 16 * 1024 * 1024);
    Check(Length(LBytes) > 0, 'Timed metadata exists');
    SetString(LText, PAnsiChar(@LBytes[0]), Length(LBytes));
    LDocument := GetJSON(LText);
    LRoot := TJSONObject(LDocument);
    Check(HashAudioBytes(ReadFileBytes(ParamStr(1), MaximumCorpusArchiveBytes)) =
      LRoot.Strings['archive_sha256'], 'Exact joint archive binding');
    LBytes := ReadFileBytes(ParamStr(3), MaximumWaveBytes);
    Check(HashAudioBytes(LBytes) = LRoot.Strings['output_sha256'], 'Exact timed WAV binding');
    LClip := DecodeWave(LBytes);
    Check((LClip.SampleRate = 44100) and (LClip.Channels = 2) and (LClip.FrameCount = 176400),
      'Exact four-second stereo output');
    LTiming := LRoot.Objects['timing'];
    Check((LTiming.Strings['pattern'] = 'ahrrahrrahrrahrr') and
      (LTiming.Integers['microseconds_per_quarter'] = 500000) and
      (LTiming.Integers['grid_ticks'] = 240) and
      (LTiming.Integers['analysis_cells'] = 173), 'Explicit musical and analysis grids');
    LAnchors := LTiming.Arrays['anchors'];
    LGrains := LRoot.Arrays['grains'];
    Check((LAnchors.Count = 4) and (LGrains.Count = 173), 'Four requests, 173 generated cells');
    for LIndex := 0 to 3 do
    begin
      Check((LAnchors.Objects[LIndex].Int64s['requested_frame'] = Int64(LIndex) * 44100) and
        (LAnchors.Objects[LIndex].Integers['cell'] = ExpectedCells[LIndex]) and
        (LAnchors.Objects[LIndex].Int64s['error_frames'] = ExpectedErrors[LIndex]) and
        (LAnchors.Objects[LIndex].Int64s['aligned_frame'] = Int64(ExpectedCells[LIndex]) * 1024),
        'Independent clock-to-hop anchor and signed error');
      Check(LGrains.Objects[ExpectedCells[LIndex]].Integers['activity'] = Ord(aaOnset),
        'Actual recorded onset candidate at every constrained analysis cell');
    end;
    SetLength(LActions, LCorpus.SourceCount);
    SetLength(LTokens, LCorpus.SourceCount);
    for LSource := 0 to LCorpus.SourceCount - 1 do
    begin
      LRecording := LCorpus.RecordingAt(LSource);
      LMeasured := AnalyzeAcousticActivity(LRecording.Features, LCorpus.Options,
        LRecording.Info.FrameCount, LActivity);
      LActions[LSource] := LMeasured.Actions;
      LTokens[LSource] := LRecording.Tokens;
    end;
    for LIndex := 0 to LGrains.Count - 1 do
    begin
      LSource := LGrains.Objects[LIndex].Integers['source_index'];
      LFrame := LGrains.Objects[LIndex].Integers['source_start_frame'];
      Check((LSource >= 0) and (LSource < LCorpus.SourceCount) and
        (LFrame >= 0) and (LFrame mod 1024 = 0), 'Stored source coordinates are on feature grid');
      LFrame := LFrame div 1024;
      Check((LFrame < Length(LTokens[LSource])) and
        (LTokens[LSource][LFrame] = LGrains.Objects[LIndex].Integers['token']) and
        (Ord(LActions[LSource][LFrame]) = LGrains.Objects[LIndex].Integers['activity']),
        'Every source grain independently matches stored acoustic/activity measurements');
    end;
    LRestFrames := 0;
    LActiveEnergy := 0;
    for LFrame := 0 to LClip.FrameCount - 1 do
    begin
      for LChannel := 0 to 1 do
      begin
        if LFrame mod 44100 >= 22050 then
        begin
          Check(LClip.SampleAt(LFrame, LChannel) = 0, 'Every requested output rest is exactly silent');
        end
        else
        begin
          LActiveEnergy := LActiveEnergy + Sqr(LClip.SampleAt(LFrame, LChannel));
          if (LFrame mod 44100 = 0) or (LFrame mod 44100 = 22049) then
          begin
            Check(LClip.SampleAt(LFrame, LChannel) = 0, 'Gate fade endpoints are exactly zero');
          end;
        end;
      end;
      if LFrame mod 44100 >= 22050 then
      begin
        Inc(LRestFrames);
      end;
    end;
    Check((LRestFrames = 88200) and (LActiveEnergy > 1), 'Exact rest coverage and audible active energy');
    WriteLn('Published timing: 4 anchors, 173 source labels and 88200 exact rest frames verified');
  finally
    LClip.Free;
    LDocument.Free;
    LModel.Free;
    LCorpus.Free;
  end;
end;

begin
  try
    CheckTiming;
    if ParamCount = 3 then
    begin
      CheckPublished;
    end
    else if ParamCount <> 0 then
    begin
      raise EAudio.Create('Optional arguments: JOINT.pyac MAPPING.json OUTPUT.wav');
    end;
    WriteLn('Timed WFC locks, collisions, replay and failure checks passed');
  except
    on LException: Exception do
    begin
      WriteLn(StdErr, LException.Message);
      Halt(1);
    end;
  end;
end.
