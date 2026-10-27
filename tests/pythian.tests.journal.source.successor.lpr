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
program pythian_tests_journal_source_successor;

{$mode delphi}
{$H+}

uses
  Classes,
  SysUtils,
  Math,
  pythian.audio,
  pythian.analysis,
  pythian.analysis.wave,
  pythian.analysis.journal,
  pythian.learning,
  pythian.learning.journal,
  pythian.learning.selection,
  pythian.learning.context,
  pythian.learning.render.stream,
  pythian.continuity;

type
  TStorage = class(TMemoryStream)
    procedure Commit;
  end;

  TAudioProbe = class
    Samples: TAudioSamples;
    function ReadWindow(const ACandidate: TJournalRepresentative): TAudioSamples;
    procedure WriteAudio(const ASamples: array of Single);
  end;

procedure TStorage.Commit;
begin
end;

function TAudioProbe.ReadWindow(const ACandidate: TJournalRepresentative): TAudioSamples;
var
  LIndex: Integer;
begin
  Result := nil;
  SetLength(Result, ACandidate.ValidFrames);
  for LIndex := 0 to High(Result) do
  begin
    Result[LIndex] := 0.25 * Sin((ACandidate.SourceFrame + LIndex) * 0.23);
  end;
end;

procedure TAudioProbe.WriteAudio(const ASamples: array of Single);
var
  LOffset: Integer;
  LIndex: Integer;
begin
  LOffset := Length(Samples);
  SetLength(Samples, LOffset + Length(ASamples));
  for LIndex := 0 to High(ASamples) do
  begin
    Samples[LOffset + LIndex] := ASamples[LIndex];
  end;
end;

procedure Require(const ACondition: Boolean; const AWhy: String);
begin
  if not ACondition then
  begin
    raise EAudio.Create(AWhy);
  end;
end;

function Feature(const AToken: Integer): TAudioFeature;
begin
  Result := Default(TAudioFeature);
  Result.Rms := 0.1 + AToken * 0.2;
  Result.Peak := Result.Rms;
  Result.ValidFrames := 64;
end;

function MakeJournal(const AStorage: TStorage; const AHashDigit: Char): TFeatureJournal;
var
  LBinding: TFeatureJournalBinding;
  LBatch: TWaveFeatureBatch;
  LFirst: Integer;
  LIndex: Integer;
begin
  LBinding := Default(TFeatureJournalBinding);
  LBinding.SourceSha256 := StringOfChar(AHashDigit, 64);
  LBinding.SampleRate := 8000;
  LBinding.Channels := 1;
  LBinding.FrameCount := 128;
  LBinding.Options := DefaultAnalysisOptions;
  LBinding.Options.WindowFrames := 64;
  LBinding.Options.HopFrames := 16;
  Result := TFeatureJournal.Create(AStorage, LBinding, AStorage.Commit, True);
  try
    LFirst := 0;
    while LFirst < 8 do
    begin
      LBatch := Default(TWaveFeatureBatch);
      LBatch.SourceStartFrame := LFirst * 16;
      LBatch.FirstFeature := LFirst;
      LBatch.NextFeature := LFirst + 4;
      LBatch.Completed := LBatch.NextFeature = 8;
      SetLength(LBatch.Features, 4);
      for LIndex := 0 to 3 do
      begin
        LBatch.Features[LIndex] := Feature((LFirst + LIndex) mod 2);
        LBatch.Features[LIndex].StartFrame := LIndex * 16;
        LBatch.Features[LIndex].ValidFrames := Min(64, 128 - (LFirst + LIndex) * 16);
      end;
      Result.Append(LBatch);
      Inc(LFirst, 4);
    end;
  except
    Result.Free;
    raise;
  end;
end;

function Render(const APool: TJournalCandidatePool;
  const AWindows: TJournalRepresentatives; const ABlockFrames: Integer): TAudioSamples;
var
  LProbe: TAudioProbe;
  LRender: TJournalAudioRenderStream;
  LOne: TJournalContextWindows;
  LIndex: Integer;
begin
  Result := nil;
  LProbe := TAudioProbe.Create;
  LRender := nil;
  try
    LRender := TJournalAudioRenderStream.Create(APool, LProbe.ReadWindow,
      LProbe.WriteAudio, 1, 64, 16, Length(AWindows), ABlockFrames);
    SetLength(LOne, 1);
    for LIndex := 0 to High(AWindows) do
    begin
      LOne[0].Token := LIndex mod 2;
      LOne[0].Candidate := AWindows[LIndex];
      LRender.AppendWindows(LOne);
    end;
    LRender.Finish;
    Result := Copy(LProbe.Samples);
  finally
    LRender.Free;
    LProbe.Free;
  end;
end;

procedure CheckSuccessors;
var
  LStorage: array[0..1] of TStorage;
  LJournal: array[0..1] of TFeatureJournal;
  LSegments: TJournalTrainingSegments;
  LReader: TJournalTrainingReader;
  LPalette: TAcousticPalette;
  LCenters: TAcousticVectors;
  LPool: TJournalCandidatePool;
  LIndex: TJournalSourceSuccessors;
  LStream: TJournalSelectionStream;
  LOther: TJournalSelectionStream;
  LPlain: TJournalSelectionStream;
  LTokens: TAcousticIndices;
  LSlots: TAcousticIndices;
  LWindows: TJournalRepresentatives;
  LPart: TJournalRepresentatives;
  LSplit: TJournalRepresentatives;
  LBefore: TJournalRepresentative;
  LFalls: TJournalRepresentative;
  LChosen: TJournalRepresentative;
  LAudio: TAudioSamples;
  LReplay: TAudioSamples;
  LWeights: TJournalSelectionWeights;
  LSource: Integer;
  LPosition: Integer;
  LOffset: Integer;
  LCount: Int64;
  LVisits: Int64;
  LRejected: Boolean;
begin
  LStorage[0] := nil;
  LStorage[1] := nil;
  LJournal[0] := nil;
  LJournal[1] := nil;
  LReader := nil;
  LPalette := nil;
  LPool := nil;
  LIndex := nil;
  LStream := nil;
  LOther := nil;
  LPlain := nil;
  LSplit := nil;
  try
    SetLength(LSegments, 2);
    for LSource := 0 to 1 do
    begin
      LStorage[LSource] := TStorage.Create;
      LJournal[LSource] := MakeJournal(LStorage[LSource], Chr(Ord('a') + LSource));
      LSegments[LSource] := WholeJournalSegment(LJournal[LSource]);
    end;
    SetLength(LCenters, 2);
    LCenters[0] := AcousticVector(Feature(0));
    LCenters[1] := AcousticVector(Feature(1));
    LPalette := TAcousticPalette.CreateFromCenters(LCenters);
    LReader := TJournalTrainingReader.Create(LSegments);
    LPool := TJournalCandidatePool.Create(LReader, LPalette, 1);
    LIndex := TJournalSourceSuccessors.Create(LReader, LPalette);
    LIndex.RequireCompatible(LPool);
    Require((LIndex.ObservationCount = 16) and (LIndex.SourceCount = 2),
      'Completed multi-batch observations retained exactly once');
    Require(LIndex.StorageBytes < 4096, 'Index retains compact observations');
    SetLength(LWeights, 2);
    LWeights[0] := 1;
    LWeights[1] := 0;
    SetLength(LTokens, 8);
    for LPosition := 0 to High(LTokens) do
    begin
      LTokens[LPosition] := LPosition mod 2;
    end;
    LStream := TJournalSelectionStream.Create(LPool, LWeights, 0, LIndex);
    LOther := TJournalSelectionStream.Create(LPool, LWeights, 0, LIndex);
    LPlain := TJournalSelectionStream.Create(LPool, LWeights, 0);
    LWindows := LStream.SelectWindowsChunk(LTokens);
    LSlots := LPlain.SelectChunk(LTokens);
    Require(LPool.CandidateAt(LSlots[2]).FeatureIndex = 0,
      'Sparse fallback cannot retain the third source window');
    for LPosition := 0 to High(LWindows) do
    begin
      Require((LWindows[LPosition].FeatureIndex = LPosition) and
        (LWindows[LPosition].SourceFrame = LPosition * 16) and
        (LWindows[LPosition].SegmentIndex = 0),
        'Successors extend outside sparse pool without changing tokens or source');
      LPart := LOther.SelectWindowsChunk(Copy(LTokens, LPosition, 1));
      LOffset := Length(LSplit);
      SetLength(LSplit, LOffset + 1);
      LSplit[LOffset] := LPart[0];
      Require(LSplit[LOffset].FeatureIndex = LWindows[LPosition].FeatureIndex,
        'Successor state continues across storage and selection boundaries');
    end;
    Require(LWindows[7].ValidFrames = 16, 'Actual final partial window extent retained');
    LAudio := Render(LPool, LWindows, 7);
    LReplay := Render(LPool, LSplit, 37);
    Require((Length(LAudio) = 176) and (Length(LReplay) = Length(LAudio)) and
      CompareMem(@LAudio[0], @LReplay[0], Length(LAudio) * SizeOf(Single)),
      'Explicit source-contiguous render replays across output block sizes');
    for LPosition := 48 to 79 do
    begin
      Require(Abs(LAudio[LPosition] - 0.25 * Sin(LPosition * 0.23)) < 0.00000002,
        'Contiguous interior preserves original sustained waveform');
    end;
    LFalls := LPool.CandidateAt(LSlots[0]);
    LBefore := LWindows[7];
    LChosen := LIndex.Select(LBefore, LFalls, 0);
    Require(LChosen.FeatureIndex = LFalls.FeatureIndex, 'Selected range endpoint falls back');
    LBefore := LWindows[0];
    LChosen := LIndex.Select(LBefore, LFalls, 0);
    Require(LChosen.FeatureIndex = LFalls.FeatureIndex, 'Different successor token falls back');
    LFalls.SegmentIndex := 1;
    LChosen := LIndex.Select(LBefore, LFalls, 0);
    Require(LChosen.SegmentIndex = 1, 'Fallback source share is preserved');
    LBefore.SourceFrame := 1;
    LRejected := False;
    try
      LIndex.Select(LBefore, LFalls, 0);
    except
      on LException: EAudio do
      begin
        LRejected := True;
      end;
    end;
    Require(LRejected, 'Invalid previous source grid rejects');
    LCount := LStream.SelectedCount;
    LVisits := LStream.SelectionVisits;
    LTokens[0] := 2;
    LRejected := False;
    try
      LStream.SelectWindowsChunk(LTokens);
    except
      on LException: EAudio do
      begin
        LRejected := True;
      end;
    end;
    Require(LRejected and (LCount = LStream.SelectedCount) and
      (LVisits = LStream.SelectionVisits), 'Failed chunk preserves counters');
    LTokens[0] := 0;
    LWindows := LStream.SelectWindowsChunk(LTokens);
    LSplit := LOther.SelectWindowsChunk(LTokens);
    for LPosition := 0 to High(LWindows) do
    begin
      Require(LWindows[LPosition].FeatureIndex = LSplit[LPosition].FeatureIndex,
        'Failed chunk preserves actual predecessor and fallback cursors');
    end;
    Require(not IsExactSourceSuccessor(0, 0, 0, 0, High(Int64), 0, 16),
      'Successor admission rejects overflow');
    WriteLn('PASS exact observed successors, token/range fallback, partial tail, rollback and sustained PCM replay');
  finally
    LPlain.Free;
    LOther.Free;
    LStream.Free;
    LIndex.Free;
    LPool.Free;
    LReader.Free;
    LPalette.Free;
    for LSource := 0 to 1 do
    begin
      LJournal[LSource].Free;
      LStorage[LSource].Free;
    end;
  end;
end;

begin
  CheckSuccessors;
end.
