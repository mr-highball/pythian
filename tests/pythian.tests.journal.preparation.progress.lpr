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
program pythian_tests_journal_preparation_progress;

{$mode delphi}
{$H+}

uses
  Classes, SysUtils, Math, pythian.audio, pythian.progress, pythian.analysis,
  pythian.analysis.wave, pythian.analysis.journal, pythian.learning,
  pythian.learning.journal, pythian.learning.selection, pythian.learning.context,
  pythian.wfc.learning.journal, pythian.hash, wfc_sequence, wfc_sequence_text;

type
  { Big Boss: no file or listener; real primary journal reads and constructors
    execute on native and actual pas2js using the same completed byte stream. }
  TStorage = class(TMemoryStream)
    procedure Commit;
  end;

  TOperation = (opPartition, opReader, opCandidates, opRestoreCandidates,
    opSuccessors, opContexts, opRestoreContexts, opModel);

  { Keeps exact exception identity and observed stage bounds. Reentry attempts
    must reject before changing the borrowed active reader. }
  TProbe = class
    Calls: Integer;
    AbortAt: Integer;
    Raised: Exception;
    LastStage: String;
    SawDecode: Boolean;
    SawPairs: Boolean;
    SawObservations: Boolean;
    SawSort: Boolean;
    SawCompanion: Boolean;
    Reader: TJournalTrainingReader;
    ReentryChecks: Integer;
    procedure Observe(const AWork: TWorkProgress);
    procedure Reset(const AAbortAt: Integer);
  end;

  { Owns baseline detached outputs; each attempt reopens exactly the same journal
    bytes after releasing any poisoned readers. Results publish only on success. }
  TFixture = class
    Storage: TStorage;
    Binding: TFeatureJournalBinding;
    Journal: TFeatureJournal;
    Segments: TJournalTrainingSegments;
    Reader: TJournalTrainingReader;
    Palette: TAcousticPalette;
    Pool: TJournalCandidatePool;
    Contexts: TJournalContextPool;
    Successors: TJournalSourceSuccessors;
    Slots: TJournalRepresentatives;
    Sources: TJournalContextSources;
    Windows: TJournalContextSets;
    ModelText: String;
    Output: TObject;
    Selected: TJournalTrainingSegments;
    constructor Create;
    destructor Destroy; override;
    procedure Reopen(const AMany: Boolean = False);
    procedure Run(const AOperation: TOperation; const AWork: TWorkProgressCallback);
    procedure Compare(const AOperation: TOperation);
  end;

var
  GChecks: Integer;
  GAborts: Integer;

procedure Check(const ACondition: Boolean; const AWhy: String);
begin
  if not ACondition then
  begin
    raise EAudio.Create(AWhy);
  end;
  Inc(GChecks);
end;

procedure TStorage.Commit;
begin
end;

procedure TProbe.Reset(const AAbortAt: Integer);
begin
  Calls := 0;
  AbortAt := AAbortAt;
  Raised := nil;
  LastStage := '';
  SawDecode := False;
  SawPairs := False;
  SawObservations := False;
  SawSort := False;
  SawCompanion := False;
  Reader := nil;
  ReentryChecks := 0;
end;

procedure TProbe.Observe(const AWork: TWorkProgress);
var
  LRejected: Boolean;
begin
  Inc(Calls);
  Check((AWork.Done >= 0) and (AWork.Total >= 0) and
    ((AWork.Total = 0) or (AWork.Done <= AWork.Total)), 'Truthful stage bounds');
  LastStage := AWork.Stage;
  if (AWork.Stage = 'journal_decode') and (AWork.Done > 0) and
    (AWork.Done < AWork.Total) then SawDecode := True;
  if (AWork.Stage = 'training_overlap_pairs') and (AWork.Done > 0) and
    (AWork.Done < AWork.Total) then SawPairs := True;
  if (Pos('_observations', AWork.Stage) > 0) and (AWork.Done > 0) and
    (AWork.Done < AWork.Total) then SawObservations := True;
  if (AWork.Stage = 'context_sort_comparisons') and (AWork.Done > 0) then SawSort := True;
  if Pos('wfc_sequence_', AWork.Stage) = 1 then SawCompanion := True;
  if Reader <> nil then
  begin
    LRejected := False;
    try
      Reader.Rewind;
    except
      on E: EAudio do LRejected := Pos('already active', E.Message) > 0;
    end;
    Check(LRejected, 'Nested read observer cannot rewind its active reader');
    Inc(ReentryChecks);
  end;
  if Calls = AbortAt then
  begin
    Raised := Exception.Create('Original preparation callback cancellation');
    raise Raised;
  end;
end;

function MeasuredFeature(const AIndex: Integer): TAudioFeature;
var
  LToken: Integer;
begin
  LToken := (AIndex div 3) mod 4;
  Result := Default(TAudioFeature);
  Result.Rms := 0.125 + LToken * 0.125;
  Result.Peak := Result.Rms;
  Result.CentroidHz := 220 + LToken * 220;
  Result.Flux := LToken * 0.125;
  Result.Chroma[LToken * 3] := 1;
  Result.ValidFrames := Min(64, 4800 - AIndex * 16);
end;

constructor TFixture.Create;
var
  LBatch: TWaveFeatureBatch;
  LCenters: TAcousticVectors;
  LModel: TWfcSequenceModel;
  I: Integer;
  J: Integer;
begin
  inherited Create;
  Storage := TStorage.Create;
  Binding := Default(TFeatureJournalBinding);
  Binding.SourceSha256 := StringOfChar('a', 64);
  Binding.SampleRate := 8000;
  Binding.Channels := 1;
  Binding.FrameCount := 4800;
  Binding.Options := DefaultAnalysisOptions;
  Binding.Options.WindowFrames := 64;
  Binding.Options.HopFrames := 16;
  Journal := TFeatureJournal.Create(Storage, Binding, Storage.Commit, True);
  LBatch := Default(TWaveFeatureBatch);
  LBatch.NextFeature := 300;
  LBatch.Completed := True;
  SetLength(LBatch.Features, 300);
  for I := 0 to 299 do
  begin
    LBatch.Features[I] := MeasuredFeature(I);
    LBatch.Features[I].StartFrame := I * 16;
  end;
  Journal.Append(LBatch);
  SetLength(LCenters, 4);
  for I := 0 to 3 do LCenters[I] := AcousticVector(MeasuredFeature(I * 3));
  Palette := TAcousticPalette.CreateFromCenters(LCenters);
  Reopen;
  Pool := TJournalCandidatePool.Create(Reader, Palette, 2);
  Contexts := TJournalContextPool.Create(Reader, Palette, Pool, 8);
  Successors := TJournalSourceSuccessors.Create(Reader, Palette);
  LModel := LearnJournalAcousticModel(Reader, Palette, 2);
  try
    ModelText := EncodeWfcSequenceText(LModel);
  finally
    LModel.Free;
  end;
  SetLength(Slots, Pool.SlotCount);
  for I := 0 to High(Slots) do Slots[I] := Pool.CandidateAt(I);
  SetLength(Sources, Contexts.SourceCount);
  for I := 0 to High(Sources) do Sources[I] := Contexts.SourceAt(I);
  { Reverse the supplied order: restore must sort canonically without mutating
    the caller's arrays or changing equal-distance/order behavior. }
  SetLength(Windows, Contexts.Count);
  for I := 0 to High(Windows) do
  begin
    SetLength(Windows[I], Contexts.ContextLength(High(Windows) - I));
    for J := 0 to High(Windows[I]) do
      Windows[I][J] := Contexts.WindowAt(High(Windows) - I, J);
  end;
end;

destructor TFixture.Destroy;
begin
  Output.Free;
  Successors.Free;
  Contexts.Free;
  Pool.Free;
  Palette.Free;
  Reader.Free;
  Journal.Free;
  Storage.Free;
  inherited Destroy;
end;

procedure TFixture.Reopen(const AMany: Boolean);
var
  I: Integer;
begin
  FreeAndNil(Output);
  FreeAndNil(Reader);
  FreeAndNil(Journal);
  Journal := TFeatureJournal.Create(Storage, Binding, Storage.Commit, False);
  if AMany then SetLength(Segments, 64) else SetLength(Segments, 3);
  for I := 0 to High(Segments) do
  begin
    Segments[I] := WholeJournalSegment(Journal);
    if AMany then
    begin
      Segments[I].FirstFeature := I * 4;
      Segments[I].FeatureCount := 4;
    end
    else
    begin
      Segments[I].FirstFeature := I * 100;
      Segments[I].FeatureCount := 100;
    end;
  end;
  Segments[0].Multiplicity := 2;
  Reader := TJournalTrainingReader.Create(Segments);
  Selected := Copy(Segments, 0, 1);
end;

procedure TFixture.Run(const AOperation: TOperation; const AWork: TWorkProgressCallback);
var
  LPlan: TJournalPartitionPlan;
  I: Integer;
begin
  case AOperation of
    opPartition:
      begin
        SetLength(LPlan, Length(Segments));
        for I := 0 to High(LPlan) do
        begin
          LPlan[I].Segment := Segments[I];
          LPlan[I].GroupId := 'same-source';
          LPlan[I].Partition := jpDevelopment;
        end;
        Selected := SelectJournalPartition(LPlan, jpDevelopment, AWork);
      end;
    opReader: Output := TJournalTrainingReader.Create(Segments, AWork);
    opCandidates: Output := TJournalCandidatePool.Create(Reader, Palette, 2, AWork);
    opRestoreCandidates:
      Output := TJournalCandidatePool.CreateFromCandidates(4, 3, 2, Slots, AWork);
    opSuccessors: Output := TJournalSourceSuccessors.Create(Reader, Palette, AWork);
    opContexts: Output := TJournalContextPool.Create(Reader, Palette, Pool, 8, AWork);
    opRestoreContexts:
      Output := TJournalContextPool.CreateFromContexts(Palette, Pool, Sources, Windows, AWork);
    opModel: Output := LearnJournalAcousticModel(Reader, Palette, 2, AWork);
  end;
end;

procedure SameCandidate(const A, B: TJournalRepresentative);
begin
  Check((A.Found = B.Found) and (A.SegmentIndex = B.SegmentIndex) and
    (A.FeatureIndex = B.FeatureIndex) and (A.SourceFrame = B.SourceFrame) and
    (A.ValidFrames = B.ValidFrames) and (A.Distance = B.Distance),
    'Detached candidate must replay exactly');
end;

function StorageHash(const AStorage: TStorage): String;
var
  LPosition: Int64;
begin
  LPosition := AStorage.Position;
  try
    AStorage.Position := 0;
    Result := Sha256Stream(AStorage, AStorage.Size);
  finally
    AStorage.Position := LPosition;
  end;
end;

procedure TFixture.Compare(const AOperation: TOperation);
var
  I: Integer;
  J: Integer;
  LPool: TJournalCandidatePool;
  LContexts: TJournalContextPool;
  LIndex: TJournalSourceSuccessors;
  LObservation: TJournalTrainingObservation;
  LPrevious: TJournalRepresentative;
  LCurrent: TJournalRepresentative;
begin
  case AOperation of
    opPartition: Check(Length(Selected) = 64, 'All selected segments publish together');
    opReader: Check((TJournalTrainingReader(Output).SegmentCount = 64) and
      (TJournalTrainingReader(Output).ObservationCount = 256) and
      (TJournalTrainingReader(Output).WeightedObservationCount = 260), 'Reader preflight totals');
    opCandidates, opRestoreCandidates:
      begin
        LPool := TJournalCandidatePool(Output);
        Check(LPool.SlotCount = Pool.SlotCount, 'Pool geometry unchanged');
        for I := 0 to Pool.SlotCount - 1 do SameCandidate(LPool.CandidateAt(I), Pool.CandidateAt(I));
      end;
    opContexts, opRestoreContexts:
      begin
        LContexts := TJournalContextPool(Output);
        Check((LContexts.Count = Contexts.Count) and
          (LContexts.WindowCount = Contexts.WindowCount) and
          (LContexts.VocabularySha256 = Contexts.VocabularySha256), 'Context geometry unchanged');
        for I := 0 to Contexts.Count - 1 do
        begin
          Check(LContexts.ContextLength(I) = Contexts.ContextLength(I), 'Context extent unchanged');
          for J := 0 to Contexts.ContextLength(I) - 1 do
          begin
            Check(LContexts.WindowAt(I, J).Token = Contexts.WindowAt(I, J).Token, 'Context token unchanged');
            SameCandidate(LContexts.WindowAt(I, J).Candidate, Contexts.WindowAt(I, J).Candidate);
          end;
        end;
      end;
    opSuccessors:
      begin
        LIndex := TJournalSourceSuccessors(Output);
        Check((LIndex.ObservationCount = 300) and (LIndex.SourceCount = 3) and
          (LIndex.VocabularySha256 = Successors.VocabularySha256), 'Successor identity unchanged');
        LIndex.RequireCompatible(Pool);
        Reader.Rewind;
        LPrevious := Default(TJournalRepresentative);
        while Reader.ReadObservation(LObservation) do
        begin
          LCurrent := Default(TJournalRepresentative);
          LCurrent.Found := True;
          LCurrent.SegmentIndex := LObservation.SegmentIndex;
          LCurrent.FeatureIndex := LObservation.FeatureIndex;
          LCurrent.SourceFrame := LObservation.SourceFrame;
          LCurrent.ValidFrames := LObservation.Feature.ValidFrames;
          SameCandidate(LIndex.Select(LPrevious, LCurrent, Palette.EncodeFeature(LObservation.Feature)),
            Successors.Select(LPrevious, LCurrent, Palette.EncodeFeature(LObservation.Feature)));
          LPrevious := LCurrent;
        end;
      end;
    opModel: Check(EncodeWfcSequenceText(TWfcSequenceModel(Output)) = ModelText, 'Exact WFC model replay');
  end;
end;

procedure AllCheckpoints;
var
  LFixture: TFixture;
  LProbe: TProbe;
  LOperation: TOperation;
  LCalls: Integer;
  I: Integer;
  LCaught: Boolean;
  LSize: Int64;
  LHash: String;
begin
  LFixture := TFixture.Create;
  LProbe := TProbe.Create;
  try
    LSize := LFixture.Storage.Size;
    LHash := StorageHash(LFixture.Storage);
    for LOperation := Low(TOperation) to High(TOperation) do
    begin
      LFixture.Reopen(LOperation in [opReader, opPartition]);
      LProbe.Reset(0);
      LFixture.Run(LOperation, LProbe.Observe);
      LFixture.Compare(LOperation);
      Check(StorageHash(LFixture.Storage) = LHash, 'Complete borrowed journal bytes unchanged');
      if LOperation in [opReader, opPartition] then Check(LProbe.SawPairs, 'Interior overlap preflight');
      if LOperation in [opCandidates, opSuccessors, opContexts, opModel] then
      begin
        Check(LProbe.SawDecode, 'Nested journal decode callback reaches real consumer');
        Check(LProbe.SawObservations, 'Interior construction observations');
      end;
      if LOperation = opRestoreContexts then Check(LProbe.SawSort, 'Actual reverse anchor sorting');
      if LOperation = opModel then Check(LProbe.SawCompanion, 'Existing companion model builder forwarded');
      LCalls := LProbe.Calls;
      Check((LCalls > 1) and (LCalls < 2048), 'Bounded constructor callback count');
      for I := 1 to LCalls do
      begin
        LFixture.Reopen(LOperation in [opReader, opPartition]);
        LProbe.Reset(I);
        LCaught := False;
        try
          LFixture.Run(LOperation, LProbe.Observe);
        except
          on E: Exception do
          begin
            LCaught := True;
            Check(E = LProbe.Raised, 'Original cancellation exception propagates');
          end;
        end;
        Check(LCaught and (LProbe.Calls = I), 'Every selected checkpoint aborts');
        Check(LFixture.Output = nil, 'No constructor result publishes after abort');
        Check(Length(LFixture.Selected) = 1, 'No partial partition result publishes');
        Check(LFixture.Storage.Size = LSize, 'Borrowed journal extent unchanged');
        Inc(GAborts);
      end;
      LFixture.Reopen(LOperation in [opReader, opPartition]);
      LFixture.Run(LOperation, nil);
      LFixture.Compare(LOperation);
      WriteLn('Preparation operation ', Ord(LOperation), ': ', LCalls, ' original aborts and exact retry');
    end;
    Check(LFixture.Windows[0][0].Candidate.FeatureIndex >
      LFixture.Windows[High(LFixture.Windows)][0].Candidate.FeatureIndex,
      'Caller reverse context order remains unchanged');
  finally
    LProbe.Free;
    LFixture.Free;
  end;
end;

procedure SubstantialJournal;
const
  CObservations = 32768;
var
  LFixture: TFixture;
  LProbe: TProbe;
  LBatch: TWaveFeatureBatch;
  LSuccessors: TJournalSourceSuccessors;
  LFirst: Integer;
  I: Integer;
begin
  LFixture := TFixture.Create;
  LProbe := TProbe.Create;
  LSuccessors := nil;
  try
    FreeAndNil(LFixture.Reader);
    FreeAndNil(LFixture.Journal);
    LFixture.Storage.Size := 0;
    LFixture.Binding.FrameCount := CObservations * 16;
    LFixture.Journal := TFeatureJournal.Create(LFixture.Storage, LFixture.Binding,
      LFixture.Storage.Commit, True);
    LFirst := 0;
    while LFirst < CObservations do
    begin
      LBatch := Default(TWaveFeatureBatch);
      LBatch.FirstFeature := LFirst;
      LBatch.NextFeature := LFirst + 512;
      LBatch.SourceStartFrame := LFirst * 16;
      LBatch.Completed := LBatch.NextFeature = CObservations;
      SetLength(LBatch.Features, 512);
      for I := 0 to 511 do
      begin
        LBatch.Features[I] := MeasuredFeature((LFirst + I) mod 12);
        LBatch.Features[I].StartFrame := I * 16;
        LBatch.Features[I].ValidFrames := Min(64, (CObservations - LFirst - I) * 16);
      end;
      LFixture.Journal.Append(LBatch);
      Inc(LFirst, 512);
    end;
    SetLength(LFixture.Segments, 1);
    LFixture.Segments[0] := WholeJournalSegment(LFixture.Journal);
    LFixture.Reader := TJournalTrainingReader.Create(LFixture.Segments);
    LProbe.Reset(0);
    LSuccessors := TJournalSourceSuccessors.Create(LFixture.Reader, LFixture.Palette, LProbe.Observe);
    Check((LSuccessors.ObservationCount = CObservations) and LProbe.SawDecode and
      LProbe.SawObservations, 'Substantial completed journal exposes real interior work');
    WriteLn('Substantial journal: ', CObservations, ' observations / ', LFixture.Storage.Size,
      ' bytes / ', LProbe.Calls, ' callbacks');
  finally
    LSuccessors.Free;
    LProbe.Free;
    LFixture.Free;
  end;
end;

procedure ReadCancellation;
var
  LFixture: TFixture;
  LProbe: TProbe;
  LObservation: TJournalTrainingObservation;
  LRejected: Boolean;
begin
  LFixture := TFixture.Create;
  LProbe := TProbe.Create;
  try
    LFixture.Reopen;
    LProbe.Reset(0);
    LProbe.Reader := LFixture.Reader;
    LFixture.Reader.OnWorkProgress := LProbe.Observe;
    Check(LFixture.Reader.ReadObservation(LObservation), 'Detailed callback through ordinary read');
    Check(LProbe.ReentryChecks > 0, 'Reader reentry rejected at actual nested callbacks');
    LFixture.Reopen;
    LProbe.Reset(1);
    LFixture.Reader.OnWorkProgress := LProbe.Observe;
    LObservation.SourceFrame := -77;
    LRejected := False;
    try
      LFixture.Reader.ReadObservation(LObservation);
    except
      on E: Exception do
      begin
        LRejected := True;
        Check(E = LProbe.Raised, 'Ordinary read preserves original cancellation');
      end;
    end;
    Check(LRejected and (LObservation.SourceFrame = -77), 'Read does not publish partial observation');
    LRejected := False;
    try
      LFixture.Reader.Rewind;
    except
      on E: EAudio do LRejected := Pos('failed', E.Message) > 0;
    end;
    Check(LRejected and LFixture.Journal.Failed, 'Nested cancellation poisons both read cursors');
    LFixture.Reopen;
    Check(LFixture.Reader.ReadObservation(LObservation) and
      (LObservation.SourceFrame = 0), 'Same unchanged bytes reopen and retry');
  finally
    LProbe.Free;
    LFixture.Free;
  end;
end;

begin
  AllCheckpoints;
  ReadCancellation;
  SubstantialJournal;
  WriteLn('Journal preparation: ', GChecks, ' checks / ', GAborts, ' original aborts');
end.
