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
program pythian.tests.wfc.joint.archive;

{$mode delphi}
{$H+}

uses
  SysUtils,
  pythian.audio,
  pythian.activity,
  pythian.corpus,
  pythian.corpus.archive,
  pythian.continuity,
  pythian.granular,
  pythian.wave,
  pythian.wfc.joint,
  pythian.wfc.joint.archive,
  pythian.wfc.generation,
  pythian.tests.corpus.fixture,
  wfc,
  wfc_model,
  wfc_sequence,
  wfc_sequence_learn,
  wfc_text_codec,
  wfc_sequence_text;

procedure Check(const ACondition: Boolean; const AMessage: String);
begin
  if not ACondition then
  begin
    raise EAudio.Create(AMessage);
  end;
end;

procedure CheckReject(const ABytes: TAudioBytes; const AMessage: String);
var
  LCorpus: TAcousticCorpusData;
  LModel: TWfcSequenceModel;
  LActivity: TActivityOptions;
  LRejected: Boolean;
begin
  LModel := nil;
  LActivity := DefaultActivityOptions;
  LRejected := False;
  try
    LCorpus := DecodeWfcJointCorpus(ABytes, LModel, LActivity);
    LCorpus.Free;
    LModel.Free;
  except
    on EAudio do
    begin
      LRejected := True;
    end;
  end;
  Check(LRejected and (LModel = nil) and (LActivity.HistoryFeatures = 0) and
    (LActivity.MinimumFlux = 0), AMessage);
end;

procedure CheckArchives;
var
  LCorpus: TAcousticCorpusData;
  LLoaded: TAcousticCorpusData;
  LExtracted: TAcousticCorpusData;
  LSources: TAudioSources;
  LModel: TWfcSequenceModel;
  LReloaded: TWfcSequenceModel;
  LWrong: TWfcSequenceModel;
  LActivity: TActivityOptions;
  LStoredActivity: TActivityOptions;
  LMeasured: TAcousticActivity;
  LRecording: TAcousticRecording;
  LBytes: TAudioBytes;
  LReplayBytes: TAudioBytes;
  LAttachment: TAudioBytes;
  LBad: TAudioBytes;
  LWave: TAudioBytes;
  LReplayWave: TAudioBytes;
  LContract: UTF8String;
  LOptions: TAcousticGenerationOptions;
  LPlanOptions: TContinuityOptions;
  LPlanner: TCorpusGrainPlanner;
  LGrains: TAudioGrains;
  LClip: TAudioClip;
  LContinuityReport: TContinuityReport;
  LSequence: TJointSequence;
  LReplay: TJointSequence;
  LReport: TGraphSolveReport;
  LSamples: TWfcSequenceSamples;
  LTokens: TWfcModelTokens;
  LText: String;
  LOrder: Integer;
  LIndex: Integer;
  LSource: Integer;
  LRejected: Boolean;
begin
  LCorpus := CreateCorpusFixture(LSources);
  try
    LActivity := DefaultActivityOptions;
    LActivity.MinimumFlux := 1;
    LActivity.AdaptiveMultiplier := 0.75;
    LActivity.HistoryFeatures := 7;
    LActivity.PeakRadius := 1;
    LActivity.MinimumSeparationFeatures := 2;
    LActivity.MaximumSegmentFeatures := 5;
    for LOrder := 1 to 4 do
    begin
      LModel := LearnJointAcousticModel(LCorpus, LActivity, LOrder);
      try
        LBytes := EncodeWfcJointCorpus(LCorpus, LModel, LActivity);
        LLoaded := DecodeWfcJointCorpus(LBytes, LReloaded, LStoredActivity);
        try
          Check((LStoredActivity.MinimumFlux = 1) and
            (LStoredActivity.AdaptiveMultiplier = 0.75) and
            (LStoredActivity.HistoryFeatures = 7) and (LStoredActivity.PeakRadius = 1) and
            (LStoredActivity.MinimumSeparationFeatures = 2) and
            (LStoredActivity.MaximumSegmentFeatures = 5), 'All custom activity options survive');
          Check(EncodeWfcSequenceText(LModel) = EncodeWfcSequenceText(LReloaded),
            'Actual saved model round-trip for every supported order');
          LReplayBytes := EncodeWfcJointCorpus(LLoaded, LReloaded, LStoredActivity);
          Check((Length(LBytes) = Length(LReplayBytes)) and
            (CompareByte(LBytes[0], LReplayBytes[0], Length(LBytes)) = 0),
            'Canonical joint archive byte round-trip');
          LOptions := DefaultAcousticGenerationOptions;
          LOptions.FrameCount := 8;
          LOptions.Extent := wseWhole;
          Check(TryGenerateJointSequence(LModel, LOptions, nil, LSequence, LReport),
            'Original paired generation');
          Check(TryGenerateJointSequence(LReloaded, LOptions, nil, LReplay, LReport),
            'Loaded paired generation');
          for LIndex := 0 to High(LSequence.Tokens) do
          begin
            Check((LSequence.Tokens[LIndex] = LReplay.Tokens[LIndex]) and
              (LSequence.Actions[LIndex] = LReplay.Actions[LIndex]), 'Exact paired token replay');
          end;
          LPlanOptions := DefaultContinuityOptions;
          LPlanOptions.Activity := LStoredActivity;
          LPlanner := TCorpusGrainPlanner.Create(LLoaded, LSources, LPlanOptions);
          try
            LGrains := LPlanner.PlanActions(LReplay.Tokens, LReplay.Actions, LContinuityReport);
            LPlanner.ValidateGrainActions(LReplay.Actions, LGrains);
            LClip := RenderGrains(LSources, LGrains, DefaultGrainRenderOptions(8192, 1));
            try
              LReplayWave := EncodeWavePcm16(LClip);
            finally
              LClip.Free;
            end;
          finally
            LPlanner.Free;
          end;
          LPlanOptions.Activity := LActivity;
          LPlanner := TCorpusGrainPlanner.Create(LCorpus, LSources, LPlanOptions);
          try
            LGrains := LPlanner.PlanActions(LSequence.Tokens, LSequence.Actions, LContinuityReport);
            LClip := RenderGrains(LSources, LGrains, DefaultGrainRenderOptions(8192, 1));
            try
              LWave := EncodeWavePcm16(LClip);
            finally
              LClip.Free;
            end;
          finally
            LPlanner.Free;
          end;
          Check((Length(LWave) = Length(LReplayWave)) and
            (CompareByte(LWave[0], LReplayWave[0], Length(LWave)) = 0),
            'Exact action-aware audio replay using stored activity policy');
        finally
          LReloaded.Free;
          LLoaded.Free;
        end;
      finally
        LModel.Free;
      end;
    end;
    LExtracted := DecodeAcousticArchive(LBytes, LContract, LAttachment);
    try
      Check(LContract = WfcJointAttachmentContract, 'Distinct opaque core attachment');
      { Every adversarial envelope below has a freshly valid outer digest. }
      LBad := Copy(LAttachment);
      LBad[4] := 2;
      CheckReject(EncodeAcousticArchive(LExtracted, LContract, LBad), 'Unknown pair version rejects');
      LBad := Copy(LAttachment);
      LBad[8] := 2;
      CheckReject(EncodeAcousticArchive(LExtracted, LContract, LBad), 'Unknown activity version rejects');
      LBad := Copy(LAttachment);
      LBad[28] := 0;
      CheckReject(EncodeAcousticArchive(LExtracted, LContract, LBad), 'Invalid stored policy rejects');
      LBad := Copy(LAttachment);
      LBad[18] := $F8;
      LBad[19] := $7F;
      CheckReject(EncodeAcousticArchive(LExtracted, LContract, LBad), 'Nonfinite policy rejects');
      LBad := Copy(LAttachment);
      SetLength(LBad, Length(LBad) + 1);
      CheckReject(EncodeAcousticArchive(LExtracted, LContract, LBad), 'Trailing attachment data rejects');
      LBad := Copy(LAttachment, 0, 47);
      CheckReject(EncodeAcousticArchive(LExtracted, LContract, LBad), 'Truncated attachment rejects');
      CheckReject(EncodeAcousticArchive(LExtracted, 'pythian.wfc.sequence.v1', LAttachment),
        'Acoustic-only attachment cannot be treated as joint');
      LText := '';
      SetLength(LText, Length(LAttachment) - 48);
      Move(LAttachment[48], LText[1], Length(LText));
      Check(Pos(WfcTextEncodeToken('wr1:a', 'fixture'), LText) > 0,
        'Tampering fixture must contain the escaped onset token');
      LText := StringReplace(LText, WfcTextEncodeToken('wr1:a', 'fixture'),
        WfcTextEncodeToken('wr1:r', 'fixture'), [rfReplaceAll]);
      LWrong := DecodeWfcSequenceText(LText);
      LWrong.Free;
      LBad := Copy(LAttachment);
      Move(LText[1], LBad[48], Length(LText));
      CheckReject(EncodeAcousticArchive(LExtracted, LContract, LBad),
        'Structurally valid WFC text with wrong activity observations rejects');
    finally
      LExtracted.Free;
    end;

    { Keep the same observed alphabet and total lengths but alter the true
      within-recording pair frequencies. This is a valid learned WFC model. }
    SetLength(LSamples, LCorpus.SourceCount);
    for LSource := 0 to LCorpus.SourceCount - 1 do
    begin
      LRecording := LCorpus.RecordingAt(LSource);
      LMeasured := AnalyzeAcousticActivity(LRecording.Features, LCorpus.Options,
        LRecording.Info.FrameCount, LActivity);
      SetLength(LTokens, Length(LRecording.Tokens));
      for LIndex := 0 to High(LTokens) do
      begin
        LTokens[LIndex] := JointAcousticToken(LRecording.Tokens[LIndex], LMeasured.Actions[LIndex]);
      end;
      LTokens[4] := LTokens[0];
      LSamples[LSource] := MakeWfcSequenceSample(LTokens);
    end;
    LWrong := LearnSequenceModelCorpus(LSamples, 1, wmbOpen);
    try
      LRejected := False;
      try
        LBad := EncodeWfcJointCorpus(LCorpus, LWrong, LActivity);
      except
        on EAudio do
        begin
          LRejected := True;
        end;
      end;
      Check(LRejected, 'Independent admission rejects changed frequencies before saving');
    finally
      LWrong.Free;
    end;
  finally
    LCorpus.Free;
    ReleaseFixtureSources(LSources);
  end;
end;

begin
  try
    CheckArchives;
    WriteLn('Joint archive admission, custom policy and audio replay checks passed');
  except
    on LException: Exception do
    begin
      WriteLn(StdErr, LException.Message);
      Halt(1);
    end;
  end;
end.
