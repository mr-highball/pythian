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
program pythian_tests_wfc_joint;

{$mode delphi}
{$H+}

uses
  SysUtils,
  fpjson,
  jsonparser,
  pythian.audio,
  pythian.activity,
  pythian.analysis,
  pythian.corpus,
  pythian.continuity,
  pythian.granular,
  pythian.learning,
  pythian.wfc.generation,
  pythian.wfc.joint,
  pythian.wfc.joint.archive,
  pythian.wfc.corpus,
  pythian.corpus.archive,
  pythian.tools.files,
  pythian.tests.corpus.fixture,
  wfc,
  wfc_music_arrangement,
  wfc_model,
  wfc_sequence,
  wfc_sequence_text;

procedure Check(const ACondition: Boolean; const AMessage: String);
begin
  if not ACondition then
  begin
    raise Exception.Create(AMessage);
  end;
end;

procedure CheckJoint;
var
  LOriginal: TAcousticCorpusData;
  LCorpus: TAcousticCorpusData;
  LSources: TAudioSources;
  LInfos: TAcousticSourceInfos;
  LModel: TWfcSequenceModel;
  LDecoded: TWfcSequenceModel;
  LOptions: TAcousticGenerationOptions;
  LActivity: TActivityOptions;
  LConstraints: TJointConstraints;
  LSequence: TJointSequence;
  LReplay: TJointSequence;
  LReport: TGraphSolveReport;
  LPlanner: TCorpusGrainPlanner;
  LPlanOptions: TContinuityOptions;
  LPlanReport: TContinuityReport;
  LGrains: TAudioGrains;
  LRecording: TAcousticRecording;
  LMeasured: TAcousticActivity;
  LIndex: Integer;
  LToken: Integer;
  LAction: TAcousticAction;
  LHistory: TWfcSequenceHistoryItem;
  LExpectedCount: Integer;
  LExpectedStart: Integer;
  LExpectedEnd: Integer;
  LRejected: Boolean;
  LOldToken: Integer;
  LOldAction: TAcousticAction;
begin
  LOriginal := CreateCorpusFixture(LSources);
  LCorpus := nil;
  LModel := nil;
  LDecoded := nil;
  LPlanner := nil;
  try
    SetLength(LInfos, LOriginal.SourceCount);
    for LIndex := 0 to High(LInfos) do
    begin
      LInfos[LIndex] := LOriginal.SourceInfoAt(LIndex);
    end;
    { One acoustic token deliberately contains both onset and sustain frames. }
    LCorpus := TrainAcousticCorpus(LSources, LInfos, LOriginal.Options, 1);
    LActivity := DefaultActivityOptions;
    LActivity.MinimumFlux := 1;
    LModel := LearnJointAcousticModel(LCorpus, LActivity, 2);
    Check((LModel.SampleCount = 2) and (LModel.ObservationCount = 16) and
      (LModel.StateCount = 3) and (LModel.PublicTokenCount = 2),
      'Joint observations retain two independent eight-frame recordings');
    for LIndex := 0 to LModel.StateCount - 1 do
    begin
      DecodeJointAcousticToken(LModel.ProjectStateToken(LIndex), LToken, LAction);
      Check(LToken = 0, 'Single acoustic vocabulary retained');
      LHistory := LModel.HistoryItemAt(LIndex, 0);
      LExpectedStart := 0;
      LExpectedEnd := 0;
      if LHistory.Kind <> wshToken then
      begin
        Check(LAction = aaOnset, 'Each independent recording starts with onset');
        LExpectedCount := 2;
        LExpectedStart := 2;
      end
      else
      begin
        Check(LAction = aaSustain, 'Stationary tones sustain after onset');
        DecodeJointAcousticToken(LModel.PublicTokenAt(LHistory.TokenIndex), LToken, LAction);
        LExpectedCount := 2;
        if LAction = aaSustain then
        begin
          LExpectedCount := 12;
          LExpectedEnd := 2;
        end;
      end;
      Check((LModel.StateObservationCountAt(LIndex) = LExpectedCount) and
        (LModel.StartCountAt(LIndex) = LExpectedStart) and
        (LModel.EndCountAt(LIndex) = LExpectedEnd), 'Independent paired n-gram/boundary counts');
    end;
    LDecoded := DecodeWfcSequenceText(EncodeWfcSequenceText(LModel));
    Check(EncodeWfcSequenceText(LDecoded) = EncodeWfcSequenceText(LModel),
      'Actual paired WFC model round-trip');
    LOptions := DefaultAcousticGenerationOptions;
    LOptions.FrameCount := 8;
    LOptions.Extent := wseWhole;
    SetLength(LConstraints, 2);
    LConstraints[0].Position := 0;
    LConstraints[0].AcousticToken := 0;
    LConstraints[0].AllowedActions := [aaOnset];
    LConstraints[1].Position := 1;
    LConstraints[1].AcousticToken := 0;
    LConstraints[1].AllowedActions := [aaSustain];
    Check(TryGenerateJointSequence(LDecoded, LOptions, LConstraints, LSequence, LReport),
      'Solve simultaneous acoustic and rhythm locks');
    Check(TryGenerateJointSequence(LDecoded, LOptions, LConstraints, LReplay, LReport),
      'Replay paired solve');
    LPlanOptions := DefaultContinuityOptions;
    LPlanOptions.CandidatesPerToken := 1;
    LPlanOptions.Activity := LActivity;
    LPlanner := TCorpusGrainPlanner.Create(LCorpus, LSources, LPlanOptions);
    LGrains := LPlanner.PlanActions(LSequence.Tokens, LSequence.Actions, LPlanReport);
    for LIndex := 0 to High(LGrains) do
    begin
      Check((LReplay.Tokens[LIndex] = LSequence.Tokens[LIndex]) and
        (LReplay.Actions[LIndex] = LSequence.Actions[LIndex]), 'Exact paired sequence replay');
      LRecording := LCorpus.RecordingAt(LGrains[LIndex].SourceIndex);
      LMeasured := AnalyzeAcousticActivity(LRecording.Features, LCorpus.Options,
        LRecording.Info.FrameCount, LActivity);
      LToken := LGrains[LIndex].SourceStartFrame div LCorpus.Options.HopFrames;
      Check((LRecording.Tokens[LToken] = LSequence.Tokens[LIndex]) and
        (LMeasured.Actions[LToken] = LSequence.Actions[LIndex]),
        'Recorded coordinate independently satisfies both generated projections');
    end;
    Check(LGrains[0].SourceStartFrame = 0,
      'Action-specific candidate pool retains onset with one-candidate budget');
    LOldToken := LSequence.Tokens[0];
    LOldAction := LSequence.Actions[0];
    LConstraints[0].AllowedActions := [aaSilence];
    Check(not TryGenerateJointSequence(LDecoded, LOptions, LConstraints, LSequence, LReport),
      'Unobserved pair contradicts instead of relaxing lock');
    Check((LReport.Status = gssContradiction) and
      (LSequence.Tokens[0] = LOldToken) and (LSequence.Actions[0] = LOldAction),
      'Contradiction preserves both previous output arrays');
    LConstraints[0].AllowedActions := [aaOnset];
    LConstraints[1].Position := 0;
    LConstraints[1].AllowedActions := [aaSustain];
    Check(not TryGenerateJointSequence(LDecoded, LOptions, LConstraints, LSequence, LReport),
      'Duplicate-position constraints intersect rather than overwrite');
    LSequence.Actions[0] := aaSilence;
    LRejected := False;
    try
      LGrains := LPlanner.PlanActions(LSequence.Tokens, LSequence.Actions, LPlanReport);
    except
      on EAudio do
      begin
        LRejected := True;
      end;
    end;
    Check(LRejected and (LGrains[0].SourceStartFrame = 0),
      'Impossible action-aware plan preserves prior grain assignment');
    LRejected := False;
    LToken := 77;
    LAction := aaSilence;
    try
      DecodeJointAcousticToken('pythian.joint.v1.00/wr1:a', LToken, LAction);
    except
      on EAudio do
      begin
        LRejected := True;
      end;
    end;
    Check(LRejected and (LToken = 77) and (LAction = aaSilence),
      'Noncanonical pair rejected before output publication');
  finally
    LPlanner.Free;
    LDecoded.Free;
    LModel.Free;
    LCorpus.Free;
    LOriginal.Free;
    ReleaseFixtureSources(LSources);
  end;
end;

procedure CheckPublishedChunks(const AModel: TWfcSequenceModel; const ARoot: TJSONObject);
var
  LChunks: TJSONArray;
  LChunk: TJSONObject;
  LEvents: TJSONArray;
  LStates: TJSONArray;
  LPrevious: Integer;
  LState: Integer;
  LOffset: Integer;
  LIndex: Integer;
  LCell: Integer;
  LToken: Integer;
  LAction: TAcousticAction;
begin
  LChunks := ARoot.Arrays['chunks'];
  LEvents := ARoot.Arrays['grains'];
  LOffset := 0;
  LPrevious := -1;
  Check(LChunks.Count > 0, 'Published stream has chunks');
  for LIndex := 0 to LChunks.Count - 1 do
  begin
    LChunk := LChunks.Objects[LIndex];
    LStates := LChunk.Arrays['states'];
    Check((LStates.Count = LChunk.Integers['cell_count']) and (LStates.Count > 0) and
      (LChunk.Integers['start_cell'] = LOffset) and
      (LChunk.Integers['previous_state'] = LPrevious), 'Chunk coverage and predecessor identity');
    Check(LChunk.Int64s['seed'] = Int64(WfcMusicArrangementSectionSeed(
      ARoot.Int64s['seed'], LIndex)), 'Actual arrangement section seed');
    Check(LChunk.Booleans['require_observed_end'] = (LIndex = LChunks.Count - 1),
      'Only final chunk requires observed end');
    for LCell := 0 to LStates.Count - 1 do
    begin
      LState := LStates.Integers[LCell];
      Check((LState >= 0) and (LState < AModel.StateCount), 'Known latent state');
      if LPrevious < 0 then
      begin
        Check(AModel.StartCountAt(LState) > 0, 'Observed initial state');
      end
      else
      begin
        Check(AModel.StatesCompatible(LPrevious, LState), 'Every transition including chunk seam');
      end;
      Check(LOffset < LEvents.Count, 'State has a recorded grain');
      DecodeJointAcousticToken(AModel.ProjectStateToken(LState), LToken, LAction);
      Check((LEvents.Objects[LOffset].Integers['token'] = LToken) and
        (LEvents.Objects[LOffset].Integers['activity'] = Ord(LAction)),
        'Rendered grain projects the exact retained latent state');
      LPrevious := LState;
      Inc(LOffset);
    end;
  end;
  Check((LOffset = LEvents.Count) and (AModel.EndCountAt(LPrevious) > 0),
    'Complete stream has exact coverage and an observed end');
  WriteLn('Published stream chunks=', LChunks.Count, ' cells=', LOffset,
    '; every latent transition and grain projection verified');
end;

procedure CheckPublished;
var
  LBytes: TAudioBytes;
  LAttachment: TAudioBytes;
  LContract: UTF8String;
  LStoredOptions: TActivityOptions;
  LText: UTF8String;
  LDocument: TJSONData;
  LPrevious: TJSONData;
  LRoot: TJSONObject;
  LJoint: TJSONObject;
  LPolicy: TJSONObject;
  LEvents: TJSONArray;
  LCorpus: TAcousticCorpusData;
  LModel: TWfcSequenceModel;
  LActivity: TAcousticActivity;
  LActions: array of TAcousticActions;
  LTokens: array of TAcousticIndices;
  LOptions: TActivityOptions;
  LRecording: TAcousticRecording;
  LSource: Integer;
  LIndex: Integer;
  LFrame: Integer;
  LOnsets: Integer;
  LSustains: Integer;
  LSilences: Integer;
  LPattern: String;
begin
  LBytes := ReadFileBytes(ParamStr(1), MaximumCorpusArchiveBytes);
  LCorpus := DecodeAcousticArchive(LBytes, LContract, LAttachment);
  LCorpus.Free;
  if LContract = WfcJointAttachmentContract then
  begin
    LCorpus := DecodeWfcJointCorpus(LBytes, LModel, LStoredOptions);
  end
  else
  begin
    LCorpus := DecodeWfcAcousticCorpus(LBytes, LModel);
  end;
  LDocument := nil;
  try
    LBytes := ReadFileBytes(ParamStr(2), 16 * 1024 * 1024);
    Check(Length(LBytes) > 0, 'Published mapping is nonempty');
    SetString(LText, PAnsiChar(@LBytes[0]), Length(LBytes));
    LDocument := GetJSON(LText);
    LRoot := TJSONObject(LDocument);
    Check(HashAudioBytes(ReadFileBytes(ParamStr(1), MaximumCorpusArchiveBytes)) =
      LRoot.Strings['archive_sha256'], 'Mapping binds exact archive bytes');
    Check(HashAudioBytes(ReadFileBytes(ParamStr(3), MaximumClipSamples * 2 + 44)) =
      LRoot.Strings['output_sha256'], 'Mapping binds exact audible output bytes');
    LJoint := LRoot.Objects['joint'];
    Check(HashText(LJoint.Strings['model_text']) = LJoint.Strings['model_sha256'],
      'Mapping binds actual paired WFC model text');
    LPolicy := LJoint.Objects['activity'];
    LOptions := DefaultActivityOptions;
    LOptions.MinimumFlux := LPolicy.Floats['minimum_flux'];
    LOptions.AdaptiveMultiplier := LPolicy.Floats['adaptive_multiplier'];
    LOptions.HistoryFeatures := LPolicy.Integers['history_features'];
    LOptions.PeakRadius := LPolicy.Integers['peak_radius'];
    LOptions.MinimumSeparationFeatures := LPolicy.Integers['minimum_separation_features'];
    LOptions.MaximumSegmentFeatures := LPolicy.Integers['maximum_segment_features'];
    if LContract = WfcJointAttachmentContract then
    begin
      Check((EncodeWfcSequenceText(LModel) = LJoint.Strings['model_text']) and
        LJoint.Booleans['loaded_without_learning'], 'Published mapping binds loaded paired model');
      Check((LOptions.MinimumFlux = LStoredOptions.MinimumFlux) and
        (LOptions.AdaptiveMultiplier = LStoredOptions.AdaptiveMultiplier) and
        (LOptions.HistoryFeatures = LStoredOptions.HistoryFeatures) and
        (LOptions.PeakRadius = LStoredOptions.PeakRadius) and
        (LOptions.MinimumSeparationFeatures = LStoredOptions.MinimumSeparationFeatures) and
        (LOptions.MaximumSegmentFeatures = LStoredOptions.MaximumSegmentFeatures),
        'Published generation uses the complete stored activity policy');
    end;
    SetLength(LActions, LCorpus.SourceCount);
    SetLength(LTokens, LCorpus.SourceCount);
    for LSource := 0 to LCorpus.SourceCount - 1 do
    begin
      LRecording := LCorpus.RecordingAt(LSource);
      LActivity := AnalyzeAcousticActivity(LRecording.Features, LCorpus.Options,
        LRecording.Info.FrameCount, LOptions);
      LActions[LSource] := LActivity.Actions;
      LTokens[LSource] := LRecording.Tokens;
    end;
    LEvents := LRoot.Arrays['grains'];
    if ParamCount = 4 then
    begin
      LBytes := ReadFileBytes(ParamStr(4), 16 * 1024 * 1024);
      Check(Length(LBytes) > 0, 'Previous mapping is nonempty');
      SetString(LText, PAnsiChar(@LBytes[0]), Length(LBytes));
      LPrevious := GetJSON(LText);
      try
        Check(LEvents.AsJSON = TJSONObject(LPrevious).Arrays['grains'].AsJSON,
          'Every saved-model grain choice equals the earlier derived-model mapping');
      finally
        LPrevious.Free;
      end;
      WriteLn('All grain fields match the previous derived-model mapping');
    end;
    LOnsets := 0;
    LSustains := 0;
    LSilences := 0;
    for LIndex := 0 to LEvents.Count - 1 do
    begin
      LSource := LEvents.Objects[LIndex].Integers['source_index'];
      LFrame := LEvents.Objects[LIndex].Integers['source_start_frame'];
      Check((LSource >= 0) and (LSource < LCorpus.SourceCount) and
        (LFrame >= 0) and (LFrame mod LCorpus.Options.HopFrames = 0),
        'Published source coordinate belongs to feature grid');
      LFrame := LFrame div LCorpus.Options.HopFrames;
      Check(LFrame < Length(LTokens[LSource]), 'Published coordinate within recording');
      Check((LTokens[LSource][LFrame] = LEvents.Objects[LIndex].Integers['token']) and
        (Ord(LActions[LSource][LFrame]) = LEvents.Objects[LIndex].Integers['activity']),
        'Every published grain independently matches acoustic and activity observations');
      case LActions[LSource][LFrame] of
        aaOnset:
        begin
          Inc(LOnsets);
        end;
        aaSustain:
        begin
          Inc(LSustains);
        end;
        aaSilence:
        begin
          Inc(LSilences);
        end;
      end;
    end;
    LPattern := LJoint.Strings['pattern'];
    Check((Length(LPattern) > 0) and (Length(LPattern) <= LEvents.Count), 'Pattern bounds');
    for LIndex := 1 to Length(LPattern) do
    begin
      LFrame := LEvents.Objects[LIndex - 1].Integers['activity'];
      case LPattern[LIndex] of
        '?': Check(True, 'Unconstrained activity');
        'a': Check(LFrame = Ord(aaOnset), 'Published onset lock');
        'h': Check(LFrame = Ord(aaSustain), 'Published sustain lock');
        'r': Check(LFrame = Ord(aaSilence), 'Published silence lock');
      else
        Check(False, 'Invalid published pattern');
      end;
    end;
    if LRoot.Find('chunks') <> nil then
    begin
      CheckPublishedChunks(LModel, LRoot);
    end;
    WriteLn('Published grains=', LEvents.Count, ' onset=', LOnsets,
      ' sustain=', LSustains, ' silence=', LSilences);
  finally
    LDocument.Free;
    LModel.Free;
    LCorpus.Free;
  end;
end;

begin
  try
    CheckJoint;
    if (ParamCount = 3) or (ParamCount = 4) then
    begin
      CheckPublished;
    end
    else if ParamCount <> 0 then
    begin
      raise EAudio.Create('Optional arguments: CORPUS.pyac MAPPING.json OUTPUT.wav [PREVIOUS_MAPPING.json]');
    end;
    WriteLn('Joint WFC counts, locks, replay, failure preservation and grain activity checks passed');
  except
    on LException: Exception do
    begin
      WriteLn(StdErr, LException.ClassName, ': ', LException.Message);
      Halt(1);
    end;
  end;
end.
