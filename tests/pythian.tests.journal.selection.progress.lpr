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
program pythian_tests_journal_selection_progress;

{$mode delphi}
{$H+}

uses
  Classes, SysUtils, Math,
  pythian.audio, pythian.progress, pythian.analysis, pythian.analysis.wave,
  pythian.analysis.journal, pythian.learning, pythian.learning.journal,
  pythian.learning.selection;

type
  TStorage = class(TMemoryStream)
    procedure Commit;
  end;

  { Borrows the active selector only while Observe runs. Assigned result fields
    deliberately contain old caller data throughout all cancellation callbacks. }
  TProbe = class
    Stream: TJournalSelectionStream;
    Calls: Integer;
    AbortAt: Integer;
    Raised: Exception;
    BeforeCount: Int64;
    BeforeVisits: Int64;
    LastStage: String;
    LastDone: Int64;
    SawInterior: Boolean;
    SawFinal: Boolean;
    Slots: TAcousticIndices;
    OldSlots: TAcousticIndices;
    Windows: TJournalRepresentatives;
    OldWindows: TJournalRepresentatives;
    procedure Reset(const AStream: TJournalSelectionStream; const AAbortAt: Integer);
    procedure Observe(const AProgress: TWorkProgress);
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

procedure SameSlots(const ALeft, ARight: TAcousticIndices);
var
  LIndex: Integer;
begin
  Check(Length(ALeft) = Length(ARight), 'Selection length changed');
  for LIndex := 0 to High(ALeft) do
  begin
    Check(ALeft[LIndex] = ARight[LIndex], 'Selection slot changed');
  end;
end;

procedure SameWindows(const ALeft, ARight: TJournalRepresentatives);
var
  LIndex: Integer;
begin
  Check(Length(ALeft) = Length(ARight), 'Window count changed');
  for LIndex := 0 to High(ALeft) do
  begin
    Check((ALeft[LIndex].Found = ARight[LIndex].Found) and
      (ALeft[LIndex].SegmentIndex = ARight[LIndex].SegmentIndex) and
      (ALeft[LIndex].FeatureIndex = ARight[LIndex].FeatureIndex) and
      (ALeft[LIndex].SourceFrame = ARight[LIndex].SourceFrame) and
      (ALeft[LIndex].ValidFrames = ARight[LIndex].ValidFrames) and
      (ALeft[LIndex].Distance = ARight[LIndex].Distance), 'Source window changed');
  end;
end;

function Tokens(const ACount: Integer): TAcousticIndices;
var
  LIndex: Integer;
begin
  Result := nil;
  SetLength(Result, ACount);
  for LIndex := 0 to High(Result) do
  begin
    Result[LIndex] := LIndex mod 4;
  end;
end;

procedure TStorage.Commit;
begin
end;

procedure TProbe.Reset(const AStream: TJournalSelectionStream; const AAbortAt: Integer);
begin
  Stream := AStream;
  Calls := 0;
  AbortAt := AAbortAt;
  Raised := nil;
  LastStage := '';
  LastDone := 0;
  SawInterior := False;
  SawFinal := False;
  SetLength(Slots, 2);
  Slots[0] := -101;
  Slots[1] := 77;
  OldSlots := Copy(Slots);
  SetLength(Windows, 1);
  Windows[0] := Default(TJournalRepresentative);
  Windows[0].SourceFrame := 777;
  Windows[0].Distance := 0.125;
  OldWindows := Copy(Windows);
  if Stream <> nil then
  begin
    BeforeCount := Stream.SelectedCount;
    BeforeVisits := Stream.SelectionVisits;
  end;
end;

procedure TProbe.Observe(const AProgress: TWorkProgress);
var
  LRejected: Boolean;
  LAction: Integer;
begin
  Inc(Calls);
  Check((AProgress.Units = wuItems) and (AProgress.Pass = 0), 'Wrong progress units/pass');
  Check((AProgress.Done >= 0) and ((AProgress.Total = 0) or
    (AProgress.Done <= AProgress.Total)), 'Invalid work geometry');
  if LastStage = AProgress.Stage then
  begin
    Check(AProgress.Done >= LastDone, 'Stage work moved backwards');
  end;
  LastStage := AProgress.Stage;
  LastDone := AProgress.Done;
  SawInterior := SawInterior or ((AProgress.Done > 0) and
    ((AProgress.Total = 0) or (AProgress.Done < AProgress.Total)));
  SawFinal := SawFinal or ((AProgress.Done > 0) and (AProgress.Done = AProgress.Total));
  SameSlots(Slots, OldSlots);
  SameWindows(Windows, OldWindows);
  if Stream <> nil then
  begin
    Check((Stream.SelectedCount = BeforeCount) and
      (Stream.SelectionVisits = BeforeVisits), 'Observer saw partial cursor publication');
    for LAction := 0 to 1 do
    begin
      LRejected := False;
      try
        if LAction = 0 then
        begin
          Stream.SelectChunk(Tokens(1));
        end
        else
        begin
          Stream.SelectWindowsChunk(Tokens(1));
        end;
      except
        on EAudio do
        begin
          LRejected := True;
        end;
      end;
      Check(LRejected, 'Selection reentry was accepted');
    end;
  end;
  if Calls = AbortAt then
  begin
    if Odd(Calls) then
    begin
      Raised := EAudio.Create('Original selection abort');
    end
    else
    begin
      Raised := Exception.Create('Original caller abort');
    end;
    raise Raised;
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
        LBatch.Features[LIndex] := Feature((LFirst + LIndex) mod 4);
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

procedure Prime(const AStream: TJournalSelectionStream; const AWindows: Boolean);
begin
  if AWindows then
  begin
    AStream.SelectWindowsChunk(Tokens(4));
  end
  else
  begin
    AStream.SelectChunk(Tokens(4));
  end;
end;

procedure CheckSelection(const APool: TJournalCandidatePool;
  const AIndex: TJournalSourceSuccessors; const AWindows: Boolean);
var
  LStream: TJournalSelectionStream;
  LControl: TJournalSelectionStream;
  LProbe: TProbe;
  LWeights: TJournalSelectionWeights;
  LTokens: TAcousticIndices;
  LExpectedSlots: TAcousticIndices;
  LExpectedWindows: TJournalRepresentatives;
  LPoints: Integer;
  LAbort: Integer;
  LCalls: Integer;
  LCaught: Boolean;
begin
  SetLength(LWeights, 3);
  LWeights[0] := 3;
  LWeights[1] := 1;
  LWeights[2] := 2;
  LTokens := Tokens(513);
  LProbe := TProbe.Create;
  try
    LPoints := 0;
    LAbort := 0;
    repeat
      LStream := TJournalSelectionStream.Create(APool, LWeights, 731, AIndex);
      LControl := TJournalSelectionStream.Create(APool, LWeights, 731, AIndex);
      try
        Prime(LStream, AWindows);
        Prime(LControl, AWindows);
        if AWindows then
        begin
          LExpectedWindows := LControl.SelectWindowsChunk(LTokens);
        end
        else
        begin
          LExpectedSlots := LControl.SelectChunk(LTokens);
        end;
        LProbe.Reset(LStream, LAbort);
        LCaught := False;
        try
          if AWindows then
          begin
            LProbe.Windows := LStream.SelectWindowsChunk(LTokens, LProbe.Observe);
          end
          else
          begin
            LProbe.Slots := LStream.SelectChunk(LTokens, LProbe.Observe);
          end;
        except
          on LException: Exception do
          begin
            Check(LException = LProbe.Raised, 'Original observer exception replaced');
            LProbe.Raised := nil;
            LCaught := True;
          end;
        end;
        if LAbort = 0 then
        begin
          Check(not LCaught and LProbe.SawInterior and LProbe.SawFinal,
            'Selection did not expose interior/final work');
          LPoints := LProbe.Calls;
        end
        else
        begin
          Check(LCaught and (LProbe.Calls = LAbort), 'Expected checkpoint abort absent');
          SameSlots(LProbe.Slots, LProbe.OldSlots);
          SameWindows(LProbe.Windows, LProbe.OldWindows);
          Check((LStream.SelectedCount = LProbe.BeforeCount) and
            (LStream.SelectionVisits = LProbe.BeforeVisits), 'Failed selection changed counters');
          if AWindows then
          begin
            LProbe.Windows := LStream.SelectWindowsChunk(LTokens);
          end
          else
          begin
            LProbe.Slots := LStream.SelectChunk(LTokens);
          end;
          Inc(GAborts);
        end;
        if AWindows then
        begin
          SameWindows(LProbe.Windows, LExpectedWindows);
        end
        else
        begin
          SameSlots(LProbe.Slots, LExpectedSlots);
        end;
        Check((LStream.SelectedCount = LControl.SelectedCount) and
          (LStream.SelectionVisits = LControl.SelectionVisits), 'Retry counters differ');
        LCalls := LProbe.Calls;
        if AWindows then
        begin
          SameWindows(LStream.SelectWindowsChunk(Tokens(7)), LControl.SelectWindowsChunk(Tokens(7)));
        end
        else
        begin
          SameSlots(LStream.SelectChunk(Tokens(7)), LControl.SelectChunk(Tokens(7)));
        end;
        Check(LCalls = LProbe.Calls, 'Selector retained a borrowed observer');
        SameSlots(LTokens, Tokens(513));
      finally
        LControl.Free;
        LStream.Free;
      end;
      Inc(LAbort);
    until LAbort > LPoints;
  finally
    LProbe.Free;
  end;
end;

procedure CheckSetupAndBatch(const APool: TJournalCandidatePool;
  const AIndex: TJournalSourceSuccessors);
var
  LWeights: TJournalSelectionWeights;
  LExpected: TAcousticIndices;
  LProbe: TProbe;
  LStream: TJournalSelectionStream;
  LMode: Integer;
  LPoints: Integer;
  LAbort: Integer;
  LCaught: Boolean;
begin
  SetLength(LWeights, 3);
  LWeights[0] := 1;
  LWeights[1] := 2;
  LWeights[2] := 0;
  LExpected := APool.Select(Tokens(513), LWeights);
  LProbe := TProbe.Create;
  try
    for LMode := 0 to 2 do
    begin
      LPoints := 0;
      LAbort := 0;
      repeat
        LProbe.Reset(nil, LAbort);
        LStream := nil;
        LCaught := False;
        try
          case LMode of
            0: AIndex.RequireCompatible(APool, LProbe.Observe);
            1: LStream := TJournalSelectionStream.Create(APool, LWeights, 731, AIndex, LProbe.Observe);
            2: LProbe.Slots := APool.Select(Tokens(513), LWeights, 731, LProbe.Observe);
          end;
        except
          on LException: Exception do
          begin
            Check(LException = LProbe.Raised, 'Setup/batch replaced original observer exception');
            LProbe.Raised := nil;
            LCaught := True;
          end;
        end;
        try
          if LAbort = 0 then
          begin
            Check(not LCaught and LProbe.SawInterior and LProbe.SawFinal,
              'Setup/batch did not expose real interior/final work');
            LPoints := LProbe.Calls;
            if LMode = 2 then
            begin
              SameSlots(LExpected, LProbe.Slots);
            end;
          end
          else
          begin
            Check(LCaught and (LProbe.Calls = LAbort), 'Expected setup/batch abort absent');
            SameSlots(LProbe.Slots, LProbe.OldSlots);
            SameWindows(LProbe.Windows, LProbe.OldWindows);
            AIndex.RequireCompatible(APool);
            SameSlots(LExpected, APool.Select(Tokens(513), LWeights));
            Inc(GAborts);
          end;
        finally
          LStream.Free;
        end;
        Inc(LAbort);
      until LAbort > LPoints;
    end;
  finally
    LProbe.Free;
  end;
end;

procedure CheckLargeSetup;
var
  LSlots: TJournalRepresentatives;
  LWeights: TJournalSelectionWeights;
  LPool: TJournalCandidatePool;
  LStream: TJournalSelectionStream;
  LProbe: TProbe;
  LIndex: Integer;
  LAbort: Integer;
  LPoints: Integer;
  LCaught: Boolean;
begin
  SetLength(LSlots, 4 * 129);
  SetLength(LWeights, 129);
  for LIndex := 0 to High(LWeights) do
  begin
    LWeights[LIndex] := 1;
  end;
  LPool := TJournalCandidatePool.CreateFromCandidates(4, 129, 1, LSlots);
  LProbe := TProbe.Create;
  try
    LPoints := 0;
    LAbort := 0;
    repeat
      LProbe.Reset(nil, LAbort);
      LStream := nil;
      LCaught := False;
      try
        LStream := TJournalSelectionStream.Create(LPool, LWeights, 731, nil, LProbe.Observe);
      except
        on LException: Exception do
        begin
          Check(LException = LProbe.Raised, 'Cursor preparation replaced observer exception');
          LProbe.Raised := nil;
          LCaught := True;
        end;
      end;
      try
        if LAbort = 0 then
        begin
          Check(not LCaught and LProbe.SawInterior and LProbe.SawFinal,
            'Large cursor preparation lacks interior/final work');
          LPoints := LProbe.Calls;
          Check(LPoints = 4, '645 setup visits should report 0/256/512/645');
        end
        else
        begin
          Check(LCaught and (LProbe.Calls = LAbort), 'Cursor checkpoint abort absent');
          Inc(GAborts);
        end;
      finally
        LStream.Free;
      end;
      Inc(LAbort);
    until LAbort > LPoints;
  finally
    LProbe.Free;
    LPool.Free;
  end;
end;

procedure Run;
var
  LStorage: array[0..2] of TStorage;
  LJournal: array[0..2] of TFeatureJournal;
  LSegments: TJournalTrainingSegments;
  LCenters: TAcousticVectors;
  LReader: TJournalTrainingReader;
  LPalette: TAcousticPalette;
  LPool: TJournalCandidatePool;
  LIndex: TJournalSourceSuccessors;
  LSource: Integer;
  LMetricRejected: Boolean;
  LNativeBytes: Int64;
begin
  for LSource := 0 to 2 do
  begin
    LStorage[LSource] := nil;
    LJournal[LSource] := nil;
  end;
  LReader := nil;
  LPalette := nil;
  LPool := nil;
  LIndex := nil;
  try
    SetLength(LSegments, 3);
    for LSource := 0 to 2 do
    begin
      LStorage[LSource] := TStorage.Create;
      LJournal[LSource] := MakeJournal(LStorage[LSource], Chr(Ord('a') + LSource));
      LSegments[LSource] := WholeJournalSegment(LJournal[LSource]);
    end;
    SetLength(LCenters, 4);
    for LSource := 0 to 3 do
    begin
      LCenters[LSource] := AcousticVector(Feature(LSource));
    end;
    LPalette := TAcousticPalette.CreateFromCenters(LCenters);
    LReader := TJournalTrainingReader.Create(LSegments);
    LPool := TJournalCandidatePool.Create(LReader, LPalette, 32);
    LIndex := TJournalSourceSuccessors.Create(LReader, LPalette);
    LMetricRejected := False;
    LNativeBytes := 0;
    try
      LNativeBytes := LIndex.NativeStorageBytes;
    except
      on EAudio do
      begin
        LMetricRejected := True;
      end;
    end;
    {$ifdef pas2js}
    Check(LMetricRejected, 'pas2js invented a native object-layout memory measure');
    {$else}
    Check(not LMetricRejected and (LNativeBytes >= LIndex.ObservationCount * 12),
      'Native storage omits retained scalar payload');
    {$endif}
    CheckSetupAndBatch(LPool, LIndex);
    CheckSelection(LPool, nil, False);
    CheckSelection(LPool, nil, True);
    CheckSelection(LPool, LIndex, False);
    CheckSelection(LPool, LIndex, True);
  finally
    LIndex.Free;
    LPool.Free;
    LReader.Free;
    LPalette.Free;
    for LSource := 0 to 2 do
    begin
      LJournal[LSource].Free;
      LStorage[LSource].Free;
    end;
  end;
end;

begin
  try
    Run;
    CheckLargeSetup;
    WriteLn('PASS ', GChecks, ' selection progress checks; ', GAborts, ' original abort/retries');
  except
    on LException: Exception do
    begin
      WriteLn(LException.ClassName, ': ', LException.Message);
      ExitCode := 1;
    end;
  end;
end.
