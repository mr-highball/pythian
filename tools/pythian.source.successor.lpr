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
program PythianSourceSuccessor;

{$mode delphi}
{$H+}

uses
  Classes, SysUtils, Math, fpjson, pythian.tools.json, jsonparser,
  pythian.audio, pythian.hash, pythian.progress,
  pythian.analysis.journal, pythian.learning.journal,
  pythian.learning.selection, pythian.learning.context,
  pythian.learning.render.stream, pythian.continuity,
  pythian.wave.read, pythian.wave.stream,
  pythian.wfc.learning.profile, pythian.wfc.audio.stream,
  pythian.tools.files;

const
  MaximumComparisonGrains = 6000;
  MaximumComparisonSeconds = 20;
  ComparisonPolicy = 'exact_source_successor_v1;next observed hop only;' +
    'exact requested token and fallback range;unchanged WFC tokens and Hann DSP';

type
  TComparisonAccess = class
    Wave: TWaveFrameReader;
    Origin: Int64;
    RangeFrames: Int64;
    Windows: TJournalContextWindows;
    Deadline: QWord;
    LastProgress: QWord;
    function ReadWindow(const ACandidate: TJournalRepresentative): TAudioSamples;
    procedure Grain(const AOrdinal: Int64; const AToken: Integer;
      const ACandidate: TJournalRepresentative);
    procedure CheckTime;
    procedure HashProgress(const AWork: TWorkProgress);
    procedure RejectJournalWrite;
  end;

procedure Need(const ACondition: Boolean; const AMessage: String);
begin
  if not ACondition then
  begin
    raise EAudio.Create(AMessage);
  end;
end;

procedure TComparisonAccess.CheckTime;
begin
  Need(GetTickCount64 < Deadline, 'Comparison exceeded its 180-second budget');
end;

procedure TComparisonAccess.RejectJournalWrite;
begin
  raise EAudio.Create('Comparison journal is read-only');
end;

procedure TComparisonAccess.HashProgress(const AWork: TWorkProgress);
begin
  CheckTime;
  if GetTickCount64 - LastProgress >= 5000 then
  begin
    WriteLn('verify_source_bytes ', AWork.Done, '/', AWork.Total);
    LastProgress := GetTickCount64;
  end;
end;

function TComparisonAccess.ReadWindow(const ACandidate: TJournalRepresentative): TAudioSamples;
begin
  CheckTime;
  Need(ACandidate.Found and (ACandidate.SegmentIndex = 0) and
    (ACandidate.SourceFrame >= 0) and (ACandidate.ValidFrames > 0) and
    (ACandidate.SourceFrame <= RangeFrames - ACandidate.ValidFrames),
    'Comparison window exceeds the exact selected source range');
  Wave.SeekFrame(Origin + ACandidate.SourceFrame);
  Result := Wave.ReadFrames(ACandidate.ValidFrames);
end;

procedure TComparisonAccess.Grain(const AOrdinal: Int64; const AToken: Integer;
  const ACandidate: TJournalRepresentative);
begin
  Need((AOrdinal = Length(Windows)) and (AOrdinal < MaximumComparisonGrains),
    'Comparison grain ledger exceeds its bound or is out of order');
  SetLength(Windows, Length(Windows) + 1);
  Windows[AOrdinal].Token := AToken;
  Windows[AOrdinal].Candidate := ACandidate;
end;

function FileHash(const APath: String): String;
var
  LStream: TFileStream;
begin
  LStream := TFileStream.Create(APath, fmOpenRead or fmShareDenyWrite);
  try
    Result := Sha256Stream(LStream, LStream.Size);
  finally
    LStream.Free;
  end;
end;

function ReadText(const APath: String): UTF8String;
var
  LBytes: TAudioBytes;
begin
  LBytes := ReadFileBytes(APath, MaximumJournalProfileBytes);
  SetLength(Result, Length(LBytes));
  if Length(LBytes) > 0 then
  begin
    Move(LBytes[0], Result[1], Length(LBytes));
  end;
end;

function ReadObject(const APath: String): TJSONObject;
var
  LData: TJSONData;
begin
  LData := ParseNativeJSON(ReadText(APath));
  if LData.JSONType <> jtObject then
  begin
    LData.Free;
    raise EAudio.Create('Comparison metadata must be a JSON object');
  end;
  Result := TJSONObject(LData);
end;

function SameWindow(const ALeft, ARight: TJournalContextWindow): Boolean;
begin
  Result := (ALeft.Candidate.SegmentIndex = ARight.Candidate.SegmentIndex) and
    (ALeft.Candidate.FeatureIndex = ARight.Candidate.FeatureIndex) and
    (ALeft.Candidate.SourceFrame = ARight.Candidate.SourceFrame);
end;

function WindowLedger(const AWindows: TJournalContextWindows;
  const AOrigin: Int64): TJSONArray;
var
  LIndex: Integer;
  LRow: TJSONObject;
begin
  Result := TJSONArray.Create;
  try
    for LIndex := 0 to High(AWindows) do
    begin
      LRow := TJSONObject.Create;
      Result.Add(LRow);
      LRow.Add('token', AWindows[LIndex].Token);
      LRow.Add('range_index', AWindows[LIndex].Candidate.SegmentIndex);
      LRow.Add('feature_index', AWindows[LIndex].Candidate.FeatureIndex);
      LRow.Add('source_frame', AWindows[LIndex].Candidate.SourceFrame);
      LRow.Add('original_source_frame', AOrigin + AWindows[LIndex].Candidate.SourceFrame);
      LRow.Add('valid_frames', AWindows[LIndex].Candidate.ValidFrames);
    end;
  except
    Result.Free;
    raise;
  end;
end;

function Metrics(const AWindows: TJournalContextWindows;
  const AProfile: TJournalModelProfile): TJSONObject;
var
  LIndex: Integer;
  LPrevious: Integer;
  LOffset: Integer;
  LLinks: Integer;
  LRun: Integer;
  LLongest: Integer;
  LRepeats: Integer;
  LImmediate: Integer;
  LNovel: Integer;
  LSlot: Integer;
  LFound: Boolean;
  LSame: Boolean;
  LCandidate: TJournalRepresentative;
begin
  LLinks := 0;
  LRun := 1;
  LLongest := 1;
  LRepeats := 0;
  LImmediate := 0;
  LNovel := 0;
  for LIndex := 0 to High(AWindows) do
  begin
    if LIndex > 0 then
    begin
      if IsExactSourceSuccessor(AWindows[LIndex - 1].Candidate.SegmentIndex,
        AWindows[LIndex].Candidate.SegmentIndex, AWindows[LIndex].Token,
        AWindows[LIndex].Token, AWindows[LIndex - 1].Candidate.SourceFrame,
        AWindows[LIndex].Candidate.SourceFrame, AProfile.Options.HopFrames) then
      begin
        Inc(LLinks);
        Inc(LRun);
      end
      else
      begin
        LRun := 1;
      end;
      LLongest := Max(LLongest, LRun);
      if SameWindow(AWindows[LIndex - 1], AWindows[LIndex]) then
      begin
        Inc(LImmediate);
      end;
    end;
    LFound := False;
    for LSlot := 0 to AProfile.Pool.SlotCount - 1 do
    begin
      LCandidate := AProfile.Pool.CandidateAt(LSlot);
      if LCandidate.Found and
        (LCandidate.SegmentIndex = AWindows[LIndex].Candidate.SegmentIndex) and
        (LCandidate.SourceFrame = AWindows[LIndex].Candidate.SourceFrame) then
      begin
        LFound := True;
        Break;
      end;
    end;
    if not LFound then
    begin
      Inc(LNovel);
    end;
    if LIndex < 3 then
    begin
      Continue;
    end;
    for LPrevious := 3 to LIndex - 1 do
    begin
      LSame := True;
      for LOffset := 0 to 3 do
      begin
        if not SameWindow(AWindows[LIndex - LOffset], AWindows[LPrevious - LOffset]) then
        begin
          LSame := False;
          Break;
        end;
      end;
      if LSame then
      begin
        Inc(LRepeats);
        Break;
      end;
    end;
  end;
  Result := TJSONObject.Create;
  Result.Add('grains', Length(AWindows));
  Result.Add('contiguous_links', LLinks);
  Result.Add('noncontiguous_links', Max(0, Length(AWindows) - 1 - LLinks));
  Result.Add('longest_contiguous_grains', LLongest);
  Result.Add('longest_source_span_ms',
    (Int64(LLongest - 1) * AProfile.Options.HopFrames + AProfile.Options.WindowFrames) *
    1000.0 / AProfile.SampleRate);
  Result.Add('immediate_repeated_windows', LImmediate);
  Result.Add('repeated_four_window_sequences', LRepeats);
  Result.Add('windows_outside_saved_exemplar_pool', LNovel);
end;

function Render(const AProfile: TJournalModelProfile; const AAccess: TComparisonAccess;
  const ASuccessors: TJournalSourceSuccessors; const ASeed, ABlock: Integer;
  const AFrames: Int64; const APath: String): TJSONObject;
var
  LStream: TFileStream;
  LSink: TStreamAudioSink;
  LWriter: TWavePcm16Writer;
  LSession: TJournalAudioSession;
  LSamples: TAudioSamples;
  LWeights: TJournalSelectionWeights;
  LStart: QWord;
  LIndex: Integer;
  LPeak: Double;
  LSum: Double;
  LCount: Int64;
begin
  Need(not FileExists(APath), 'Comparison output already exists');
  SetLength(LWeights, 1);
  LWeights[0] := 1;
  AAccess.Windows := nil;
  LStream := nil;
  LSink := nil;
  LWriter := nil;
  LSession := nil;
  LPeak := 0;
  LSum := 0;
  LCount := 0;
  LStart := GetTickCount64;
  Result := nil;
  try
    LStream := TFileStream.Create(APath, fmCreate or fmShareExclusive);
    LSink := TStreamAudioSink.Create(LStream);
    LWriter := TWavePcm16Writer.Create(LSink, AProfile.SampleRate, AProfile.Channels, AFrames);
    LSession := TJournalAudioSession.Create(AProfile, AAccess.ReadWindow,
      LWeights, ASeed, AFrames, AAccess.Grain, ASuccessors);
    while LSession.State <> assCompleted do
    begin
      AAccess.CheckTime;
      LSamples := LSession.ReadFrames(ABlock);
      Need(Length(LSamples) > 0, 'Comparison audio session made no progress');
      for LIndex := 0 to High(LSamples) do
      begin
        RequireFinite(LSamples[LIndex], 'Comparison output sample');
        LPeak := Max(LPeak, Abs(LSamples[LIndex]));
        LSum := LSum + Sqr(LSamples[LIndex]);
      end;
      Inc(LCount, Length(LSamples));
      LWriter.AppendSamples(LSamples);
    end;
    LWriter.Finish;
    Need(LPeak <= 1, 'Comparison output would clip PCM16; no gain repair selected');
    Result := Metrics(AAccess.Windows, AProfile);
    Result.Add('frames', LSession.Position);
    Result.Add('seed', ASeed);
    Result.Add('block_frames', ABlock);
    Result.Add('render_elapsed_ms', Int64(GetTickCount64 - LStart));
    Result.Add('linear_peak', LPeak);
    Result.Add('linear_rms', Sqrt(LSum / LCount));
    Result.Add('grain_map', WindowLedger(AAccess.Windows, AAccess.Origin));
  finally
    LSession.Free;
    LWriter.Free;
    LSink.Free;
    LStream.Free;
  end;
  try
    Result.Add('wav_sha256', FileHash(APath));
  except
    Result.Free;
    raise;
  end;
end;

procedure WriteReference(const AProfile: TJournalModelProfile;
  const AAccess: TComparisonAccess; const AFrames: Int64; const APath: String);
var
  LStream: TFileStream;
  LSink: TStreamAudioSink;
  LWriter: TWavePcm16Writer;
  LSamples: TAudioSamples;
  LRemaining: Int64;
begin
  LStream := nil;
  LSink := nil;
  LWriter := nil;
  Need(not FileExists(APath), 'Reference output already exists');
  try
    LStream := TFileStream.Create(APath, fmCreate or fmShareExclusive);
    LSink := TStreamAudioSink.Create(LStream);
    LWriter := TWavePcm16Writer.Create(LSink, AProfile.SampleRate, AProfile.Channels, AFrames);
    AAccess.Wave.SeekFrame(AAccess.Origin);
    LRemaining := AFrames;
    while LRemaining > 0 do
    begin
      AAccess.CheckTime;
      LSamples := AAccess.Wave.ReadFrames(Min(Int64(4096), LRemaining));
      Need(Length(LSamples) > 0, 'Reference ended before the fixed selection');
      LWriter.AppendSamples(LSamples);
      Dec(LRemaining, Length(LSamples) div AProfile.Channels);
    end;
    LWriter.Finish;
  finally
    LWriter.Free;
    LSink.Free;
    LStream.Free;
  end;
end;

procedure Run;
var
  LProfileRoot: TJSONObject;
  LReceipt: TJSONObject;
  LRequest: TJSONObject;
  LReport: TJSONObject;
  LBefore: TJSONObject;
  LAfter: TJSONObject;
  LProfile: TJournalModelProfile;
  LJournalStream: TFileStream;
  LSourceStream: TFileStream;
  LJournal: TFeatureJournal;
  LReader: TJournalTrainingReader;
  LSuccessors: TJournalSourceSuccessors;
  LAccess: TComparisonAccess;
  LSegments: TJournalTrainingSegments;
  LSaved: TJournalProfileSource;
  LSource: TJSONObject;
  LExpected: TJSONArray;
  LOutput: String;
  LJob: String;
  LProfileDir: String;
  LSourcePath: String;
  LSourceHash: String;
  LSeed: Integer;
  LBlock: Integer;
  LFrames: Int64;
  LIndex: Integer;
  LStart: QWord;
  LGate: Boolean;
begin
  Need((ParamCount >= 4) and (ParamCount <= 6),
    'Usage: pythian.source.successor PROFILE_DIR JOB_DIR SOURCE.wav NEW_OUTPUT_DIR [BLOCK_FRAMES] [SEED]');
  LProfileDir := IncludeTrailingPathDelimiter(ExpandFileName(ParamStr(1)));
  LJob := IncludeTrailingPathDelimiter(ExpandFileName(ParamStr(2)));
  LSourcePath := ExpandFileName(ParamStr(3));
  LOutput := IncludeTrailingPathDelimiter(ExpandFileName(ParamStr(4)));
  Need(not DirectoryExists(LOutput) and not FileExists(ExcludeTrailingPathDelimiter(LOutput)),
    'Use a new comparison directory; existing evidence is never replaced');
  LBlock := 4096;
  if ParamCount >= 5 then
  begin
    LBlock := StrToInt(ParamStr(5));
  end;
  LSeed := 731;
  if ParamCount = 6 then
  begin
    LSeed := StrToInt(ParamStr(6));
  end;
  Need((LBlock >= 1) and (LBlock <= MaximumSessionPullFrames), 'Block frames must be 1..65536');
  Need((LSeed = 731) or (LSeed = 1731) or (LSeed = 2731), 'Comparison seeds are fixed at 731/1731/2731');
  LProfileRoot := nil;
  LReceipt := nil;
  LRequest := nil;
  LReport := nil;
  LProfile := nil;
  LJournalStream := nil;
  LSourceStream := nil;
  LJournal := nil;
  LReader := nil;
  LSuccessors := nil;
  LAccess := nil;
  LStart := GetTickCount64;
  try
    LAccess := TComparisonAccess.Create;
    LAccess.Deadline := LStart + 180000;
    LAccess.LastProgress := GetTickCount64;
    LProfileRoot := ReadObject(LProfileDir + 'profile.json');
    LReceipt := ReadObject(LJob + 'seed-0.receipt.json');
    LRequest := ReadObject(LJob + 'request.json');
    Need((LProfileRoot.Strings['format'] = 'pythian.studio.acoustic.profile.v1') and
      (LProfileRoot.Strings['mode'] = 'raw_acoustic') and
      (LProfileRoot.Arrays['sources'].Count = 1), 'Consumer supports one saved raw-acoustic selected range');
    Need((LReceipt.Integers['seed'] = 731) and
      (LRequest.Integers['duration_ms'] <= MaximumComparisonSeconds * 1000),
      'Saved baseline must use seed 731 and at most 20 seconds');
    LFrames := LReceipt.Int64s['frame_count'];
    LProfile := TJournalModelProfile.Create(LProfileRoot.Objects['journal_profile'].AsJSON,
      ReadText(LProfileDir + 'model.wfcs'));
    Need((LProfile.SourceCount = 1) and (LFrames > 0) and
      (LFrames <= Int64(LProfile.SampleRate) * MaximumComparisonSeconds) and
      (LReceipt.Strings['model_sha256'] = LProfile.ModelSha256), 'Saved model/frame identity differs');
    LSaved := LProfile.SourceAt(0);
    LSource := LProfileRoot.Arrays['sources'].Objects[0];
    Need((LSource.Int64s['selected_frames'] = LSaved.Binding.FrameCount) and
      (LSource.Strings['analysis_range_sha256'] = LSaved.Binding.SourceSha256) and
      (LSource.Int64s['end_frame'] - LSource.Int64s['start_frame'] = LSaved.Binding.FrameCount) and
      (LFrames <= LSaved.Binding.FrameCount), 'Saved selected-range binding differs');
    LExpected := LReceipt.Arrays['grain_map'];
    Need((LExpected.Count > 0) and (LExpected.Count <= MaximumComparisonGrains), 'Saved grain map exceeds comparison bound');
    Need(FileHash(LJob + 'analysis' + PathDelim + '0.pyaf') = LSaved.CacheSha256,
      'Saved journal bytes differ from the learned profile');
    LJournalStream := TFileStream.Create(LJob + 'analysis' + PathDelim + '0.pyaf',
      fmOpenRead or fmShareDenyWrite);
    LJournal := TFeatureJournal.Create(LJournalStream, LSaved.Binding,
      LAccess.RejectJournalWrite, False);
    Need(LJournal.Completed and (LJournal.TailBytes = 0), 'Saved journal is incomplete');
    SetLength(LSegments, 1);
    LSegments[0].Journal := LJournal;
    LSegments[0].FirstFeature := LSaved.FirstFeature;
    LSegments[0].FeatureCount := LSaved.FeatureCount;
    LSegments[0].Multiplicity := LSaved.Multiplicity;
    LReader := TJournalTrainingReader.Create(LSegments);
    LSuccessors := TJournalSourceSuccessors.Create(LReader, LProfile.Palette);
    LSuccessors.RequireCompatible(LProfile.Pool);
    LAccess.Origin := LSource.Int64s['start_frame'];
    LAccess.RangeFrames := LSource.Int64s['selected_frames'];
    LSourceStream := TFileStream.Create(LSourcePath, fmOpenRead or fmShareDenyWrite);
    WriteLn('Verifying exact source bytes; no analysis or training');
    LSourceHash := Sha256Stream(LSourceStream, LSourceStream.Size, LAccess.HashProgress);
    Need(LSourceHash = LSource.Strings['source_sha256'], 'Original source bytes differ');
    LSourceStream.Position := 0;
    LAccess.Wave := TWaveFrameReader.Create(LSourceStream);
    Need((LAccess.Wave.SampleRate = LProfile.SampleRate) and
      (LAccess.Wave.Channels = LProfile.Channels) and
      (LAccess.Wave.FrameCount = LSource.Int64s['source_frames']) and
      (LAccess.Origin >= 0) and
      (LAccess.Origin <= LAccess.Wave.FrameCount - LAccess.RangeFrames), 'Original source geometry differs');
    Need(ForceDirectories(ExtractFileDir(ExcludeTrailingPathDelimiter(LOutput))) and
      CreateDir(ExcludeTrailingPathDelimiter(LOutput)), 'Cannot create new comparison directory');
    LReport := TJSONObject.Create;
    LReport.Add('contract', 'pythian.source-successor.comparison.v1');
    LReport.Add('policy', ComparisonPolicy);
    LReport.Add('model_sha256', LProfile.ModelSha256);
    LReport.Add('profile_sha256', FileHash(LProfileDir + 'profile.json'));
    LReport.Add('journal_sha256', LSaved.CacheSha256);
    LReport.Add('source_sha256', LSourceHash);
    LReport.Add('source_bytes_verified', LSourceStream.Size);
    LReport.Add('source_original_start_frame', LAccess.Origin);
    LReport.Add('sample_rate', LProfile.SampleRate);
    LReport.Add('channels', LProfile.Channels);
    LReport.Add('successor_observations', LSuccessors.ObservationCount);
    LReport.Add('successor_storage_bytes', LSuccessors.StorageBytes);
    WriteLn('Rendering unchanged baseline');
    LBefore := Render(LProfile, LAccess, nil, LSeed, LBlock, LFrames, LOutput + 'before.wav');
    LReport.Add('before', LBefore);
    if LSeed = 731 then
    begin
      Need(LBefore.Strings['wav_sha256'] = LReceipt.Strings['wav_sha256'],
        'Baseline PCM differs from the retained failed audition');
      Need(LExpected.Count = Length(LAccess.Windows), 'Baseline grain count differs');
      for LIndex := 0 to LExpected.Count - 1 do
      begin
        Need((LExpected.Objects[LIndex].Integers['token'] = LAccess.Windows[LIndex].Token) and
          (LExpected.Objects[LIndex].Int64s['original_source_frame'] =
            LAccess.Origin + LAccess.Windows[LIndex].Candidate.SourceFrame), 'Baseline grain map differs');
      end;
    end;
    LReport.Add('retained_baseline_exact', LSeed = 731);
    WriteLn('Rendering exact source successors');
    LAfter := Render(LProfile, LAccess, LSuccessors, LSeed, LBlock, LFrames, LOutput + 'after.wav');
    LReport.Add('after', LAfter);
    Need(LBefore.Arrays['grain_map'].Count = LAfter.Arrays['grain_map'].Count, 'Changed grain count');
    for LIndex := 0 to LBefore.Arrays['grain_map'].Count - 1 do
    begin
      Need((LBefore.Arrays['grain_map'].Objects[LIndex].Integers['token'] =
        LAfter.Arrays['grain_map'].Objects[LIndex].Integers['token']) and
        (LBefore.Arrays['grain_map'].Objects[LIndex].Integers['range_index'] =
          LAfter.Arrays['grain_map'].Objects[LIndex].Integers['range_index']),
        'Successor path changed requested tokens or source contributions');
    end;
    WriteReference(LProfile, LAccess, LFrames, LOutput + 'original-reference.wav');
    LReport.Add('original_reference_sha256', FileHash(LOutput + 'original-reference.wav'));
    LGate := (LAfter.Integers['contiguous_links'] > LBefore.Integers['contiguous_links']) and
      (LAfter.Integers['repeated_four_window_sequences'] <= LBefore.Integers['repeated_four_window_sequences']);
    LReport.Add('frozen_mechanism_gate_passed', LGate);
    LReport.Add('musical_acceptance', 'Unreviewed; source continuity metrics do not establish sustained notes or good music');
    LReport.Add('reference_scope', 'First 20 seconds or shorter of the saved selected source range; no gain normalization');
    LReport.Add('input_protection', 'Original source and journal remained open read-only denying writes; saved model, request and receipt were not modified');
    LReport.Add('elapsed_ms', Int64(GetTickCount64 - LStart));
    WriteTextFile(LOutput + 'comparison.json', LReport.AsJSON + LineEnding);
    WriteLn('contiguous_links ', LBefore.Integers['contiguous_links'], ' -> ', LAfter.Integers['contiguous_links']);
    WriteLn('repeated_four_window_sequences ', LBefore.Integers['repeated_four_window_sequences'],
      ' -> ', LAfter.Integers['repeated_four_window_sequences']);
    WriteLn('frozen_mechanism_gate_passed=', LGate);
    if not LGate then
    begin
      ExitCode := 2;
    end;
  finally
    if LAccess <> nil then
    begin
      LAccess.Wave.Free;
    end;
    LAccess.Free;
    LSourceStream.Free;
    LSuccessors.Free;
    LReader.Free;
    LJournal.Free;
    LJournalStream.Free;
    LProfile.Free;
    LReport.Free;
    LRequest.Free;
    LReceipt.Free;
    LProfileRoot.Free;
  end;
end;

begin
  try
    Run;
  except
    on LException: Exception do
    begin
      WriteLn(StdErr, LException.ClassName, ': ', LException.Message);
      ExitCode := 1;
    end;
  end;
end.
