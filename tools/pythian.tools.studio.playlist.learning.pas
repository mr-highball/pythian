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

unit pythian.tools.studio.playlist.learning;

{$mode delphi}
{$H+}

interface

uses fpjson, pythian.progress, pythian.wfc.musical.corpus,
  pythian.tools.studio.&library;

const
  StudioPlaylistLearningPolicy = 'whole-window-uniform-musical-bars-v1';
  StudioPlaylistAnalysisPolicy = 'window-pulse-periodic-bands-first8-v1';
  StudioPlaylistModelCells = 1024;
  StudioPlaylistBlockCells = 8;

{ Worker-only orchestration of shared primary measurements/proposals and WFC
  musical learning. Traverses the complete included time in bounded windows.
  A fixed model budget chooses known musical bars spread across that time;
  original proposal caches retain all windows, including unknowns. Coverage
  distinguishes analyzed audio, retained provider windows and actual model use.
  Cache root is host configuration, never supplied by the browser. }
function LearnStudioPlaylist(const ACatalogRoot, ALibraryRoot, ACacheRoot,
  AJobId: String; const APlaylist: TJSONObject; out AReceipt: TJSONObject;
  const AProgress: TWorkProgressCallback = nil;
  const ALibraryProgress: TStudioLibraryProgress = nil): TMusicalCorpus;

implementation

uses Classes, SysUtils, Math, pythian.audio, pythian.time, pythian.wave.read,
  pythian.hash, pythian.stream.bytes, pythian.music.observations,
  pythian.music.proposal, pythian.music.proposal.codec, pythian.music.pattern,
  pythian.tools.studio.projects, pythian.tools.studio.jobs,
  pythian.tools.studio.&library.discovery;

type
  TFramePositions = array of Int64;
  TSourceMeasurement = record
    AnalyzedFrames: Int64;
    ProposedFrames: Int64;
    CacheHits: Integer;
    MeasuredWindows: Integer;
    RejectedCaches: Integer;
    Windows: Integer;
  end;

procedure Need(const ACondition: Boolean; const AMessage: String);
begin
  if not ACondition then
  begin
    raise EAudio.Create(AMessage);
  end;
end;

function SourceHash(const ACatalogRoot, ALibraryRoot, AJobId: String;
  const AItem: TJSONObject; const AOrdinal: Integer;
  const ALibraryProgress: TStudioLibraryProgress): String;
var
  LEntries: TJSONArray;
  LEntry: TJSONObject;
  LPrepared: TJSONObject;
begin
  if AItem.Strings['kind'] = 'catalog' then Exit(AItem.Strings['id']);
  LEntries := TJSONArray.Create;
  LPrepared := nil;
  try
    LEntry := TJSONObject.Create;
    LEntry.Add('entry_id', AItem.Strings['id']);
    LEntry.Add('entry_snapshot_sha256', AItem.Strings['snapshot_sha256']);
    LEntries.Add(LEntry);
    LPrepared := PrepareStudioLibraryEntries(ACatalogRoot, ALibraryRoot,
      ReserveStudioJobStage(ACatalogRoot, ALibraryRoot, AJobId,
        'playlist-' + IntToStr(AOrdinal)), AItem.Integers['discovery_revision'],
      LEntries, ALibraryProgress);
    Result := LPrepared.Arrays['mappings'].Objects[0].Strings['source_sha256'];
  finally
    LPrepared.Free;
    LEntries.Free;
  end;
end;

function CachedWindow(const ACacheDirectory, AHash: String;
  const AReader: TWaveFrameReader; const AStart: Int64; const AFrames: Integer;
  var AStats: TSourceMeasurement; const AProgress: TWorkProgressCallback): TBoundMusicalProposal;
var
  LKey: String;
  LPath: String;
  LFile: TFileStream;
  LBytes: TAudioBytes;
  LClip: TAudioClip;
  LMeasured: TMusicalObservations;
  LProposal: TBoundMusicalProposal;
  LTempo: Integer;
  LBestChannel: Integer;
  I: Integer;
  LScore: Double;
  LCacheValid: Boolean;
begin
  LKey := StudioTextHash(StudioPlaylistAnalysisPolicy + '|' + MusicalProposalPolicy + '|' +
    AHash + '|' + IntToStr(AStart) + '|' + IntToStr(AFrames));
  LPath := IncludeTrailingPathDelimiter(ACacheDirectory) + LKey + '.pmp';
  LCacheValid := False;
  ReportWork(AProgress, 'playlist_analysis_cache', wuItems, AStats.Windows, 0);
  if FileExists(LPath) then
  begin
    LFile := OpenStudioReadStream(LPath);
    try
      if (LFile.Size > 64) and (LFile.Size <= MaximumMusicalProposalBytes) then
      begin
        SetLength(LBytes, LFile.Size);
        ReadStreamBytesExact(LFile, LBytes, 0, Length(LBytes));
        try
          { Bounded cache decoding has no cancellation callback to accidentally
            reinterpret a cancellation exception as damaged cache evidence. }
          LProposal := DecodeMusicalProposal(LBytes);
          LCacheValid := (LProposal.SourceSha256 = AHash) and
            (LProposal.StartFrame = AStart) and (LProposal.Grid.SourceFrames = AFrames) and
            (LProposal.Grid.SampleRate = AReader.SampleRate) and
            (LProposal.Grid.Policy = MusicalProposalPolicy);
        except
          on E: EAudio do LCacheValid := False;
        end;
      end;
    finally LFile.Free end;
    if LCacheValid then
    begin
      Inc(AStats.CacheHits);
      Exit(LProposal);
    end;
    Inc(AStats.RejectedCaches);
  end;
  ReportWork(AProgress, 'playlist_measure_window', wuFrames, 0, AFrames);
  LClip := AReader.ReadClip(AStart, AFrames, AProgress);
  try
    Need(LClip.FrameCount = AFrames, 'Selected music ended before its saved source extent');
    LMeasured := MeasureMusicalObservations(LClip, AProgress);
    LTempo := 500000;
    LBestChannel := 0;
    LScore := -1;
    for I := 0 to High(LMeasured.ChannelBeats) do
    begin
      if (Length(LMeasured.ChannelBeats[I].Grid.Candidates) > 0) and
        (LMeasured.ChannelBeats[I].Grid.Candidates[0].Score > LScore) then
      begin
        LScore := LMeasured.ChannelBeats[I].Grid.Candidates[0].Score;
        LBestChannel := I;
        LTempo := Round(60000000 / Max(40, Min(240,
          LMeasured.ChannelBeats[I].Grid.Candidates[0].Bpm)));
      end;
    end;
    LProposal := Default(TBoundMusicalProposal);
    LProposal.SourceSha256 := AHash;
    LProposal.StartFrame := AStart;
    LProposal.Grid := ProposeMusicalGrid(LMeasured, AReader.SampleRate,
      AFrames, LTempo, LBestChannel, AProgress);
  finally LClip.Free end;
  LBytes := EncodeMusicalProposal(LProposal, AProgress);
  Need(ForceDirectories(ACacheDirectory), 'Cannot create the private musical analysis cache');
  ReplaceStudioBinary(LPath, LBytes);
  Inc(AStats.MeasuredWindows);
  ReportWork(AProgress, 'playlist_measure_window', wuFrames, AFrames, AFrames);
  Result := LProposal;
end;

function LearnStudioPlaylist(const ACatalogRoot, ALibraryRoot, ACacheRoot,
  AJobId: String; const APlaylist: TJSONObject; out AReceipt: TJSONObject;
  const AProgress: TWorkProgressCallback;
  const ALibraryProgress: TStudioLibraryProgress): TMusicalCorpus;
var
  LPlaylist: TJSONObject;
  LItems: TJSONArray;
  LItem: TJSONObject;
  LSourceMetadata: TJSONObject;
  LClipRow: TJSONObject;
  LRows: TJSONArray;
  LProviderWindows: TJSONArray;
  LProviderWindow: TJSONObject;
  LCells: TJSONArray;
  LRow: TJSONObject;
  LReceipt: TJSONObject;
  LReference: TJSONObject;
  LSources: TMusicalCorpusSources;
  LSelections: TMusicalCorpusSelections;
  LRuns: TMusicalCorpusRuns;
  LCoverage: TMusicalCorpusCoverages;
  LStats: array of TSourceMeasurement;
  LTargets: TFramePositions;
  LInput: TFileStream;
  LReader: TWaveFrameReader;
  LClock: TTempoMap;
  LBound: TBoundMusicalProposal;
  LBlock: TProposedMusicalBlock;
  LMask: TMusicalProposalFlags;
  LCandidate: TMusicalCorpus;
  LCacheBase: String;
  LHash: String;
  LSourceCache: String;
  LSelectedFrames: Int64;
  LSelectionTotal: Int64;
  LSelectionBefore: Int64;
  LBefore: Int64;
  LPosition: Int64;
  LRemaining: Int64;
  LWindowEnd: Int64;
  LUsedFrame: Int64;
  LTotalSourceBytes: Int64;
  LTempoTotal: Double;
  LTempoWeight: Double;
  LWeight: Double;
  I: Integer;
  J: Integer;
  K: Integer;
  R: Integer;
  LStartSelection: Integer;
  LSlots: Integer;
  LTarget: Integer;
  LFrames: Integer;
  LWindowLimit: Integer;
  LCell: Integer;
  LAdmitted: Integer;
  LExcludedItems: Integer;
  LHasSelection: Boolean;
  function ItemFrames(const AItem: TJSONObject): Int64;
  var
    LIndex: Integer;
    LClip: TJSONObject;
  begin
    Result := 0;
    if AItem.Strings['extent'] = 'whole' then Exit(AItem.Int64s['frame_count']);
    for LIndex := 0 to AItem.Arrays['clips'].Count - 1 do
    begin
      LClip := AItem.Arrays['clips'].Objects[LIndex];
      if LClip.Booleans['included'] then
        Inc(Result, LClip.Int64s['end_frame'] - LClip.Int64s['start_frame']);
    end;
  end;
  function Milliseconds(const AFrames: Int64; const ARate: Integer): Int64;
  begin
    Result := (AFrames div ARate) * 1000 + (AFrames mod ARate) * 1000 div ARate;
  end;
  procedure AddSelection(const ASource: Integer; const AStart, AEnd: Int64);
  var LAt: Integer;
  begin
    LAt := Length(LSelections);
    Need(LAt < MaximumMusicalCorpusSelections, 'Playlist contains more than64 included ranges');
    SetLength(LSelections, LAt + 1);
    LSelections[LAt].SourceIndex := ASource;
    LSelections[LAt].StartFrame := AStart;
    LSelections[LAt].EndFrame := AEnd;
  end;
begin
  LPlaylist := CanonicalStudioPlaylist(APlaylist);
  LReceipt := nil;
  LCandidate := nil;
  LInput := nil;
  LReader := nil;
  LSourceMetadata := nil;
  LSelections := nil;
  LRuns := nil;
  try
    LItems := LPlaylist.Arrays['items'];
    LExcludedItems := 0;
    { Big Boss: keep excluded choices in the immutable playlist, but do not
      prepare/hash a recording with no included whole track or clip. }
    for I := LItems.Count - 1 downto 0 do
    begin
      LHasSelection := LItems.Objects[I].Strings['extent'] = 'whole';
      for J := 0 to LItems.Objects[I].Arrays['clips'].Count - 1 do
        LHasSelection := LHasSelection or
          LItems.Objects[I].Arrays['clips'].Objects[J].Booleans['included'];
      if not LHasSelection then
      begin
        LItems.Delete(I);
        Inc(LExcludedItems);
      end;
    end;
    Need(LItems.Count > 0, 'Select a whole track or clip before generating');
    LSelectionTotal := 0;
    LSelectionBefore := 0;
    for I := 0 to LItems.Count - 1 do
      Inc(LSelectionTotal, Milliseconds(ItemFrames(LItems.Objects[I]),
        LItems.Objects[I].Integers['sample_rate']));
    Need(LSelectionTotal > 0, 'Select at least one millisecond of music');
    ReportWork(AProgress, 'playlist_selection_progress', wuMilliseconds, 0, LSelectionTotal);
    Need(ACacheRoot <> '', 'The host musical cache directory is missing');
    LCacheBase := IncludeTrailingPathDelimiter(ExpandFileName(ACacheRoot)) +
      Copy(StudioTextHash(IncludeTrailingPathDelimiter(ExpandFileName(ACatalogRoot))), 1, 16);
    SetLength(LSources, LItems.Count);
    SetLength(LStats, LItems.Count);
    LReceipt := TJSONObject.Create;
    LReceipt.Add('format', 'pythian.studio.playlist.learning.v1');
    LReceipt.Add('policy', StudioPlaylistLearningPolicy);
    LReceipt.Add('proposal_policy', MusicalProposalPolicy);
    LReceipt.Add('analysis_policy', StudioPlaylistAnalysisPolicy);
    LReceipt.Add('experimental', True);
    LReceipt.Add('excluded_playlist_item_count', LExcludedItems);
    LReceipt.Add('model_cell_budget', StudioPlaylistModelCells);
    LReceipt.Add('musical_block_cells', StudioPlaylistBlockCells);
    LReceipt.Add('tempo_policy', 'First-eight-second per-window pulse proposal; explicit120BPM when unavailable. Not whole-track tempo/downbeat truth.');
    LRows := TJSONArray.Create;
    LReceipt.Add('sources', LRows);
    LProviderWindows := TJSONArray.Create;
    LReceipt.Add('provider_windows', LProviderWindows);
    LSlots := Max(1, StudioPlaylistModelCells div StudioPlaylistBlockCells div LItems.Count);
    LTotalSourceBytes := 0;
    for I := 0 to LItems.Count - 1 do
    begin
      ReportWork(AProgress, 'playlist_prepare_music', wuItems, I, LItems.Count);
      LItem := LItems.Objects[I];
      LHash := SourceHash(ACatalogRoot, ALibraryRoot, AJobId, LItem, I, ALibraryProgress);
      for J := 0 to I - 1 do
      begin
        Need(LHash <> LSources[J].Sha256,
          'Two playlist entries contain the same recording. Remove the duplicate and generate again.');
      end;
      LSources[I].Sha256 := LHash;
      FreeAndNil(LSourceMetadata);
      LSourceMetadata := ReadStudioSourceMetadata(ACatalogRoot, LHash);
      LSources[I].GroupId := LSourceMetadata.Strings['source_group'];
      LSources[I].SampleRate := LItem.Integers['sample_rate'];
      LSources[I].FrameCount := LItem.Int64s['frame_count'];
      LSources[I].TrainingWeight := LItem.Integers['influence'];
      LSources[I].Classifications := nil;
      LStartSelection := Length(LSelections);
      if LItem.Strings['extent'] = 'whole' then
        AddSelection(I, 0, LSources[I].FrameCount)
      else
      begin
        for J := 0 to LItem.Arrays['clips'].Count - 1 do
        begin
          LClipRow := LItem.Arrays['clips'].Objects[J];
          if LClipRow.Booleans['included'] then
            AddSelection(I, LClipRow.Int64s['start_frame'], LClipRow.Int64s['end_frame']);
        end;
      end;
      LSelectedFrames := ItemFrames(LItem);
      LRow := TJSONObject.Create;
      LRow.Add('playlist_item', LItem.Clone);
      LRow.Add('source_sha256', LHash);
      LRow.Add('influence', LSources[I].TrainingWeight);
      LRow.Add('sample_rate', LSources[I].SampleRate);
      LRow.Add('included_frames', LSelectedFrames);
      LRow.Add('excluded_frames', LSources[I].FrameCount - LSelectedFrames);
      LRows.Add(LRow);
      if LSelectedFrames = 0 then Continue;
      LInput := OpenStudioSourceAudio(ACatalogRoot, LHash);
      try
        ReportWork(AProgress, 'playlist_verify_recording', wuBytes, 0, LInput.Size, I);
        Need(LInput.Size <= MaximumLibrarySourceBytes, 'Recording exceeds the source byte limit');
        Need(LTotalSourceBytes <= MaximumStudioJobSourceBytes - LInput.Size,
          'Selected recordings exceed the total original byte limit');
        Inc(LTotalSourceBytes, LInput.Size);
        LInput.Position := 0;
        Need(Sha256Stream(LInput, LInput.Size, AProgress) = LHash,
          'Saved recording bytes differ; refresh the library before generating');
        LRow.Add('original_bytes_verified', LInput.Size);
        LInput.Position := 0;
        LReader := TWaveFrameReader.Create(LInput);
        try
          Need((LReader.SampleRate = LSources[I].SampleRate) and
            (LReader.FrameCount = LSources[I].FrameCount), 'Recording differs from its playlist clock');
          SetLength(LTargets, LSlots);
          for J := 0 to LSlots - 1 do
            LTargets[J] := (LSelectedFrames * (2 * J + 1)) div (2 * LSlots);
          LBefore := 0;
          LTarget := 0;
          LWindowLimit := Min(MaximumMusicalObservationFrames,
            LReader.SampleRate * MusicalObservationSeconds);
          LSourceCache := LCacheBase + PathDelim + LHash;
          for J := LStartSelection to High(LSelections) do
          begin
            LPosition := LSelections[J].StartFrame;
            while LPosition < LSelections[J].EndFrame do
            begin
              ReportWork(AProgress, 'playlist_analyze_music', wuFrames,
                LStats[I].AnalyzedFrames, LSelectedFrames, I);
              LRemaining := LSelections[J].EndFrame - LPosition;
              { Every possible40..240BPM clock needs at most0.75s per eighth.
                Keep a final short remainder in a complete observation window. }
              if LRemaining < (Int64(LReader.SampleRate) * 3 + 3) div 4 then Break;
              LFrames := Min(LWindowLimit, LRemaining);
              if (LRemaining > LWindowLimit) and
                (LRemaining - LWindowLimit < (Int64(LReader.SampleRate) * 3 + 3) div 4) then
                LFrames := LRemaining - (Int64(LReader.SampleRate) * 3 + 3) div 4;
              LWindowEnd := LPosition + LFrames;
              LBound := CachedWindow(LSourceCache, LHash, LReader, LPosition, LFrames,
                LStats[I], AProgress);
              Inc(LStats[I].Windows);
              Inc(LStats[I].AnalyzedFrames, LFrames);
              ReportWork(AProgress, 'playlist_selection_progress', wuMilliseconds,
                LSelectionBefore + Milliseconds(LStats[I].AnalyzedFrames,
                  LSources[I].SampleRate), LSelectionTotal, I + 1);
              LClock := TTempoMap.Create(PitchPatternPpq,
                Length(LBound.Grid.Frames) * PitchPatternStepTicks,
                [MakeTempoChange(0, LBound.Grid.TempoMicroseconds)]);
              try
                for K := 0 to High(LBound.Grid.Frames) do
                  if LBound.Grid.Known[K] then
                    Inc(LStats[I].ProposedFrames,
                      LClock.FrameAtTick((K + 1) * PitchPatternStepTicks, LReader.SampleRate, frCeiling) -
                      LClock.FrameAtTick(K * PitchPatternStepTicks, LReader.SampleRate, frCeiling));
                LMask := nil;
                SetLength(LMask, Length(LBound.Grid.Frames));
                LAdmitted := 0;
                while (LTarget < Length(LTargets)) and
                  (LTargets[LTarget] < LBefore + LWindowEnd - LSelections[J].StartFrame) do
                begin
                  LUsedFrame := Max(0, LTargets[LTarget] - LBefore -
                    (LPosition - LSelections[J].StartFrame));
                  LUsedFrame := Min(LUsedFrame,
                    LClock.FrameAtTick(LClock.LengthTicks, LReader.SampleRate) - 1);
                  LCell := Max(0, LClock.NextGridTick(LUsedFrame, LReader.SampleRate,
                    PitchPatternStepTicks) div PitchPatternStepTicks - 1);
                  LBlock := ChooseProposedMusicalBlock(LBound.Grid, LCell,
                    StudioPlaylistBlockCells, LMask);
                  for K := LBlock.FirstCell to LBlock.FirstCell + LBlock.CellCount - 1 do
                    LMask[K] := True;
                  Inc(LAdmitted, LBlock.CellCount);
                  Inc(LTarget);
                end;
                if LAdmitted > 0 then
                begin
                  R := Length(LRuns);
                  Need(R < MaximumMusicalCorpusRuns, 'Representative provider window limit exceeded');
                  SetLength(LRuns, R + 1);
                  LRuns[R].SourceIndex := I;
                  LRuns[R].StartFrame := LPosition;
                  LRuns[R].Grid := LBound.Grid;
                  LRuns[R].AdmittedCells := LMask;
                  LProviderWindow := TJSONObject.Create;
                  LProviderWindow.Add('source_index', I);
                  LProviderWindow.Add('start_frame', LPosition);
                  LProviderWindow.Add('end_frame', LWindowEnd);
                  LProviderWindow.Add('proposal_sha256', Sha256Bytes(EncodeMusicalProposal(LBound)));
                  LCells := TJSONArray.Create;
                  for K := 0 to High(LMask) do
                    if LMask[K] then LCells.Add(K);
                  LProviderWindow.Add('admitted_cells', LCells);
                  LProviderWindows.Add(LProviderWindow);
                  if LReceipt.Find('reference_source') = nil then
                  begin
                    LReference := TJSONObject.Create;
                    LReference.Add('kind', 'catalog');
                    LReference.Add('source_sha256', LHash);
                    LReference.Add('id', LHash);
                    LReference.Add('title', LItem.Strings['title']);
                    LReference.Add('source_group', LSourceMetadata.Strings['source_group']);
                    LReference.Add('clock_id', LSourceMetadata.Strings['clock_id']);
                    LReference.Add('partition', LSourceMetadata.Strings['partition']);
                    LReference.Add('license', LSourceMetadata.Strings['license']);
                    LReference.Add('provenance', LSourceMetadata.Strings['provenance']);
                    LReference.Add('sample_rate', LReader.SampleRate);
                    LReference.Add('start_frame', LPosition);
                    LReference.Add('end_frame', LWindowEnd);
                    LReceipt.Add('reference_source', LReference);
                  end;
                end;
              finally LClock.Free end;
              LPosition := LWindowEnd;
            end;
            Inc(LBefore, LSelections[J].EndFrame - LSelections[J].StartFrame);
          end;
        finally FreeAndNil(LReader) end;
      finally FreeAndNil(LInput) end;
      { Completed selection traversal includes cache hits and sub-window tails.
        The receipt separately records measured, reused and unanalysable time. }
      Inc(LSelectionBefore, Milliseconds(LSelectedFrames, LSources[I].SampleRate));
      ReportWork(AProgress, 'playlist_selection_progress', wuMilliseconds,
        LSelectionBefore, LSelectionTotal, I + 1);
    end;
    Need(Length(LRuns) > 0,
      'No usable musical notes were found. Try tonal music or a longer selection.');
    ReportWork(AProgress, 'playlist_learn_music', wuItems, 0, 1);
    LCandidate := TMusicalCorpus.Create(LSources, LSelections, LRuns, 2, 2, 65536, AProgress);
    LCoverage := LCandidate.CopyCoverage;
    LTempoTotal := 0;
    LTempoWeight := 0;
    for R := 0 to High(LRuns) do
    begin
      LAdmitted := 0;
      for K := 0 to High(LRuns[R].AdmittedCells) do
        if LRuns[R].AdmittedCells[K] then Inc(LAdmitted);
      LWeight := LAdmitted * LSources[LRuns[R].SourceIndex].TrainingWeight;
      LTempoWeight := LTempoWeight + LWeight;
      LTempoTotal := LTempoTotal + LRuns[R].Grid.TempoMicroseconds * LWeight;
    end;
    LReceipt.Add('output_tempo_microseconds', Round(LTempoTotal / LTempoWeight));
    for I := 0 to High(LSources) do
    begin
      LRow := LRows.Objects[I];
      LRow.Add('analyzed_frames', LStats[I].AnalyzedFrames);
      LRow.Add('unanalyzed_frames', LRow.Int64s['included_frames'] - LStats[I].AnalyzedFrames);
      LRow.Add('proposed_frames', LStats[I].ProposedFrames);
      LRow.Add('unknown_or_partial_frames', LStats[I].AnalyzedFrames - LStats[I].ProposedFrames);
      LRow.Add('provider_window_frames', LCoverage[I].ProcessedFrames);
      LRow.Add('model_used_frames', LCoverage[I].ModelUsedFrames);
      LRow.Add('budget_omitted_frames', LStats[I].ProposedFrames - LCoverage[I].ModelUsedFrames);
      LRow.Add('model_cells', LCoverage[I].ModelCells);
      LRow.Add('weighted_cells', LCoverage[I].WeightedCells);
      LRow.Add('windows', LStats[I].Windows);
      LRow.Add('measured_windows', LStats[I].MeasuredWindows);
      LRow.Add('cache_hits', LStats[I].CacheHits);
      LRow.Add('rejected_caches', LStats[I].RejectedCaches);
    end;
    ReportWork(AProgress, 'playlist_learn_music', wuItems, 1, 1);
    AReceipt := LReceipt;
    LReceipt := nil;
    Result := LCandidate;
    LCandidate := nil;
  finally
    LCandidate.Free;
    LReceipt.Free;
    LPlaylist.Free;
    LSourceMetadata.Free;
  end;
end;

end.
