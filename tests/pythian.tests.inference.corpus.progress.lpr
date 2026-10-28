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
program pythian_tests_inference_corpus_progress;

{$mode delphi}{$H+}

uses
  Classes, SysUtils,
  pythian.audio, pythian.progress,
  pythian.inference.observation, pythian.inference.corpus;

const
  CReadStages: array[0..2] of String = (
    'inference_corpus_read_rows', 'verify_audio_bytes', 'inference_verify_rows');

type
  TStopPoint = (spStart, spInterior, spFinal);
  TTraceRow = record
    Entry: Integer;
    Observation: TInferenceObservation;
  end;
  TTrace = array of TTraceRow;
  TObserver = class
  public
    Stage: String;
    Point: TStopPoint;
    Ordinal: Integer;
    Marker: Exception;
    Reader: TInferenceCorpusReader;
    ReentryStage: String;
    CatchReentry: Boolean;
    Reentered: Boolean;
    RejectedReentry: Boolean;
    RequireOrdinal: Boolean;
    Calls: Integer;
    LastVisits: Int64;
    FinalVisits: Int64;
    ReadRows: array[0..2] of Int64;
    destructor Destroy; override;
    procedure Observe(const AWork: TWorkProgress);
  end;

var
  GChecks: Integer;
  GAborts: Integer;
  GDirectory: String;
  GEntries: TInferenceCorpusEntries;
  GTrace: TTrace;
  GHashes: array[0..2] of String;
  GHashBytes: array[0..2] of Int64;

procedure Check(const AValue: Boolean; const AMessage: String);
begin
  Inc(GChecks);
  if not AValue then
  begin
    raise Exception.Create(AMessage);
  end;
end;

destructor TObserver.Destroy;
begin
  Marker.Free;
  inherited Destroy;
end;

procedure TObserver.Observe(const AWork: TWorkProgress);
var
  LStop: Boolean;
  LIndex: Integer;
  LBatch: TInferenceBatch;
begin
  Inc(Calls);
  Check((AWork.Done >= 0) and (AWork.Total >= 0), 'Negative work');
  Check((AWork.Total = 0) or (AWork.Done <= AWork.Total), 'Work exceeds total');
  if AWork.Stage = 'inference_corpus_metadata_visits' then
  begin
    Check((AWork.Pass = 0) and (AWork.Units = wuItems), 'Metadata scope/units');
    Check(AWork.Done >= LastVisits, 'Metadata count regressed');
    LastVisits := AWork.Done;
    if AWork.Total > 0 then
    begin
      Check(AWork.Done = AWork.Total, 'Metadata invented a traversal total');
      FinalVisits := AWork.Total;
    end;
  end
  else if RequireOrdinal then
  begin
    Check((AWork.Pass >= 1) and (AWork.Pass <= 3), 'Missing actual entry ordinal');
    if AWork.Stage = 'verify_audio_bytes' then
    begin
      Check((AWork.Units = wuBytes) and
        (AWork.Total = GHashBytes[AWork.Pass - 1]), 'Actual artifact byte scope differs');
    end
    else
    begin
      Check((AWork.Units = wuObservations) and (AWork.Total = 100), 'Actual row scope differs');
      if AWork.Stage = 'inference_corpus_read_rows' then
      begin
        Check(AWork.Done >= ReadRows[AWork.Pass - 1], 'Read count regressed');
        ReadRows[AWork.Pass - 1] := AWork.Done;
      end;
    end;
  end;
  if (Reader <> nil) and (AWork.Stage = ReentryStage) and not Reentered then
  begin
    Reentered := True;
    LIndex := 739;
    LBatch := nil;
    if not CatchReentry then
    begin
      Reader.ReadBatch(LIndex, LBatch);
    end
    else
    begin
      try
        Reader.ReadBatch(LIndex, LBatch);
      except
        on LError: EAudio do
        begin
          Check(Pos('cannot reenter', LError.Message) > 0, 'Wrong reentry error');
          RejectedReentry := True;
        end;
      end;
      Check(RejectedReentry and (LIndex = 739) and (Length(LBatch) = 0),
        'Reentry mutated a nested caller slot');
    end;
  end;
  if (Marker = nil) or (AWork.Stage <> Stage) or
    ((Ordinal > 0) and (AWork.Pass <> Ordinal)) then
  begin
    Exit;
  end;
  case Point of
    spStart: LStop := AWork.Done = 0;
    spInterior: LStop := (AWork.Done > 0) and
      ((AWork.Total = 0) or (AWork.Done < AWork.Total));
    spFinal: LStop := (AWork.Total > 0) and (AWork.Done = AWork.Total);
  end;
  if LStop then
  begin
    raise Marker;
  end;
end;

function MakeEntry(const AIndex: Integer; const AName: String;
  const AFrames, AStart, AEnd: Int64): TInferenceCorpusEntry;
begin
  Result := Default(TInferenceCorpusEntry);
  Result.GroupId := 'group-' + IntToStr(AIndex);
  Result.SourceId := 'source-' + IntToStr(AIndex);
  Result.ArtifactFile := GDirectory + AName + '.pinf';
  Result.Identity.Estimator := InferenceEstimator;
  Result.Identity.Request := DefaultInferenceRequest(LowerCase(IntToHex(AIndex, 64)), AEnd);
  Result.Identity.Request.ScopeStart16k := AStart;
  Result.Identity.Request.InputEnd16k := AFrames;
  Result.Identity.Request.FirstCenter16k := AStart;
  Result.Identity.SourceRate := InferenceRate;
  Result.Identity.SourceChannels := 1;
  Result.Identity.SourceFrames := AFrames;
  Result.Identity.ObservationCount := InferenceCount(Result.Identity.Request);
end;

procedure WriteArtifact(const AEntry: TInferenceCorpusEntry; const AIndex: Integer);
var
  LSink: TInferenceFileSink;
  LBatch: TInferenceBatch;
  LRow: Integer;
begin
  LSink := TInferenceFileSink.Create(AEntry.ArtifactFile);
  try
    LSink.Start(AEntry.Identity);
    SetLength(LBatch, 1);
    for LRow := 0 to AEntry.Identity.ObservationCount - 1 do
    begin
      LBatch[0] := Default(TInferenceObservation);
      LBatch[0].Center16k := AEntry.Identity.Request.FirstCenter16k + LRow * 160;
      LBatch[0].AcRms := 0.125;
      LBatch[0].Salience[0] := LRow / 1024;
      LBatch[0].Salience[359] := (AIndex + 1) / 16;
      LSink.Append(LBatch);
    end;
    LSink.Complete;
  finally
    LSink.Free;
  end;
end;

procedure AppendTrace(var ATrace: TTrace; const AIndex: Integer;
  const ABatch: TInferenceBatch);
var
  LStart: Integer;
  LIndex: Integer;
begin
  LStart := Length(ATrace);
  SetLength(ATrace, LStart + Length(ABatch));
  for LIndex := 0 to High(ABatch) do
  begin
    ATrace[LStart + LIndex].Entry := AIndex;
    ATrace[LStart + LIndex].Observation := ABatch[LIndex];
  end;
end;

procedure Collect(const AReader: TInferenceCorpusReader; var ATrace: TTrace;
  const AObserver: TWorkProgressCallback = nil);
var
  LIndex: Integer;
  LBatch: TInferenceBatch;
begin
  LIndex := -1;
  LBatch := nil;
  while AReader.ReadBatch(LIndex, LBatch, AObserver) do
  begin
    Check((LIndex >= 0) and (LIndex < 3), 'Returned entry scope');
    Check((Length(LBatch) > 0) and (Length(LBatch) <= InferenceMaximumBatch), 'Bounded batch');
    AppendTrace(ATrace, LIndex, LBatch);
  end;
  Check((LIndex = -1) and (Length(LBatch) = 0), 'EOF output contract');
end;

procedure CheckTrace(const ATrace: TTrace);
var
  LIndex: Integer;
begin
  Check(Length(ATrace) = Length(GTrace), 'Replay lost observations');
  for LIndex := 0 to High(GTrace) do
  begin
    Check(ATrace[LIndex].Entry = GTrace[LIndex].Entry, 'Replay changed source/scope');
    Check(CompareMem(@ATrace[LIndex].Observation, @GTrace[LIndex].Observation,
      SizeOf(TInferenceObservation)), 'Replay changed original observation bits');
  end;
end;

procedure CheckExclusive;
var
  LEntry: TInferenceCorpusEntry;
  LFile: TFileStream;
begin
  for LEntry in GEntries do
  begin
    LFile := TFileStream.Create(LEntry.ArtifactFile, fmOpenRead or fmShareExclusive);
    LFile.Free;
  end;
end;

procedure CheckFailed(const AReader: TInferenceCorpusReader;
  var AIndex: Integer; var ABatch: TInferenceBatch);
var
  LIndex: Integer;
  LBatch: TInferenceBatch;
  LRejected: Boolean;
begin
  LIndex := AIndex;
  LBatch := Copy(ABatch);
  LRejected := False;
  try
    AReader.ReadBatch(AIndex, ABatch);
  except
    on LError: EAudio do
    begin
      Check(Pos('must be reopened', LError.Message) > 0, 'Wrong failed-cursor error');
      LRejected := True;
    end;
  end;
  Check(LRejected and (AIndex = LIndex), 'Failed cursor silently skipped an entry');
  Check(Length(ABatch) = Length(LBatch), 'Failed cursor changed caller batch length');
  if Length(LBatch) > 0 then
  begin
    Check(CompareMem(@ABatch[0], @LBatch[0], Length(LBatch) * SizeOf(TInferenceObservation)),
      'Failed cursor changed caller data');
  end;
  CheckExclusive;
end;

procedure CheckReadAbort(const AStage: String; const APoint: TStopPoint;
  const AOrdinal: Integer; const AReentry: Boolean = False);
var
  LReader: TInferenceCorpusReader;
  LObserver: TObserver;
  LIndex: Integer;
  LBeforeIndex: Integer;
  LBatch: TInferenceBatch;
  LBefore: TInferenceBatch;
  LStopped: Boolean;
  LTrace: TTrace;
begin
  LReader := TInferenceCorpusReader.Create(GEntries);
  LObserver := TObserver.Create;
  try
    LObserver.RequireOrdinal := True;
    LObserver.Stage := AStage;
    LObserver.Point := APoint;
    LObserver.Ordinal := AOrdinal;
    if AReentry then
    begin
      LObserver.Reader := LReader;
      LObserver.ReentryStage := AStage;
    end
    else
    begin
      LObserver.Marker := Exception.Create('original-corpus-marker');
    end;
    LIndex := 719;
    SetLength(LBatch, 1);
    LBatch[0].Center16k := -123;
    LStopped := False;
    while not LStopped do
    begin
      LBeforeIndex := LIndex;
      LBefore := Copy(LBatch);
      try
        if not LReader.ReadBatch(LIndex, LBatch, LObserver.Observe) then
        begin
          Break;
        end;
      except
        on LError: Exception do
        begin
          if AReentry then
          begin
            Check((LError is EAudio) and (Pos('cannot reenter', LError.Message) > 0),
              'Wrong escaping reentry failure');
          end
          else
          begin
            Check(LError = LObserver.Marker, 'Original callback identity lost');
            LObserver.Marker := nil;
          end;
          LStopped := True;
          Inc(GAborts);
        end;
      end;
    end;
    Check(LStopped and (LIndex = LBeforeIndex), 'Read abort published entry index');
    Check(Length(LBatch) = Length(LBefore), 'Read abort published batch extent');
    Check(CompareMem(@LBatch[0], @LBefore[0], Length(LBatch) * SizeOf(TInferenceObservation)),
      'Read abort changed caller observation data');
    CheckFailed(LReader, LIndex, LBatch);
  finally
    LObserver.Free;
    LReader.Free;
  end;
  LTrace := nil;
  LReader := TInferenceCorpusReader.Create(GEntries);
  try
    Collect(LReader, LTrace);
    CheckTrace(LTrace);
  finally
    LReader.Free;
  end;
end;

procedure CheckMetadata(const APoint: TStopPoint);
var
  LEntries: TInferenceCorpusEntries;
  LReader: TInferenceCorpusReader;
  LObserver: TObserver;
  LIndex: Integer;
  LStopped: Boolean;
begin
  SetLength(LEntries, 40);
  for LIndex := 0 to High(LEntries) do
  begin
    LEntries[LIndex] := MakeEntry(LIndex + 1, 'metadata-' + IntToStr(LIndex), 16000, 0, 16000);
  end;
  LReader := nil;
  LObserver := TObserver.Create;
  try
    LObserver.Stage := 'inference_corpus_metadata_visits';
    LObserver.Point := APoint;
    LObserver.Marker := Exception.Create('original-metadata-marker');
    LStopped := False;
    try
      LReader := TInferenceCorpusReader.Create(LEntries, LObserver.Observe);
    except
      on LError: Exception do
      begin
        Check(LError = LObserver.Marker, 'Metadata replaced original callback exception');
        LObserver.Marker := nil;
        LStopped := True;
        Inc(GAborts);
      end;
    end;
    Check(LStopped and (LReader = nil), 'Metadata published a partial reader');
  finally
    LObserver.Free;
    LReader.Free;
  end;
end;

procedure CheckBorrowAndReentry;
var
  LReader: TInferenceCorpusReader;
  LObserver: TObserver;
  LTrace: TTrace;
  LIndex: Integer;
  LBatch: TInferenceBatch;
  LStage: String;
begin
  LObserver := TObserver.Create;
  LReader := TInferenceCorpusReader.Create(GEntries, LObserver.Observe);
  LObserver.Free;
  try
    LTrace := nil;
    Collect(LReader, LTrace);
    CheckTrace(LTrace);
  finally
    LReader.Free;
  end;
  LReader := TInferenceCorpusReader.Create(GEntries);
  try
    LObserver := TObserver.Create;
    try
      LObserver.RequireOrdinal := True;
      LIndex := -1;
      LBatch := nil;
      Check(LReader.ReadBatch(LIndex, LBatch, LObserver.Observe), 'Borrowed read returned no batch');
    finally
      LObserver.Free;
    end;
    LTrace := nil;
    AppendTrace(LTrace, LIndex, LBatch);
    Collect(LReader, LTrace);
    CheckTrace(LTrace);
  finally
    LReader.Free;
  end;
  for LStage in CReadStages do
  begin
    LReader := TInferenceCorpusReader.Create(GEntries);
    LObserver := TObserver.Create;
    try
      LObserver.Reader := LReader;
      LObserver.ReentryStage := LStage;
      LObserver.CatchReentry := True;
      LObserver.RequireOrdinal := True;
      LTrace := nil;
      Collect(LReader, LTrace, LObserver.Observe);
      Check(LObserver.Reentered and LObserver.RejectedReentry, 'Reentry control was not exercised');
      CheckTrace(LTrace);
    finally
      LObserver.Free;
      LReader.Free;
    end;
  end;
end;

procedure CheckFileHashAbort(const APoint: TStopPoint);
var
  LObserver: TObserver;
  LDigest: String;
  LStopped: Boolean;
begin
  LObserver := TObserver.Create;
  try
    LObserver.Stage := 'verify_audio_bytes';
    LObserver.Point := APoint;
    LObserver.Marker := Exception.Create('original-file-hash-marker');
    LDigest := 'prior-digest';
    LStopped := False;
    try
      LDigest := HashInferenceFile(GEntries[0].ArtifactFile, LObserver.Observe);
    except
      on LError: Exception do
      begin
        Check(LError = LObserver.Marker, 'File hash replaced original callback exception');
        LObserver.Marker := nil;
        LStopped := True;
        Inc(GAborts);
      end;
    end;
    Check(LStopped and (LDigest = 'prior-digest'), 'File hash published a cancelled digest');
  finally
    LObserver.Free;
  end;
end;

procedure CheckMaximumMetadata;
var
  LEntries: TInferenceCorpusEntries;
  LIndex: Integer;
  LObserver: TObserver;
  LReader: TInferenceCorpusReader;
  LStarted: QWord;
begin
  SetLength(LEntries, InferenceCorpusMaximumEntries);
  for LIndex := 0 to High(LEntries) do
  begin
    LEntries[LIndex] := MakeEntry(LIndex + 1, 'maximum-' + IntToStr(LIndex), 16000, 0, 16000);
  end;
  LObserver := TObserver.Create;
  LStarted := GetTickCount64;
  try
    LReader := TInferenceCorpusReader.Create(LEntries, LObserver.Observe);
    try
      Check(LReader.EntryCount = 4096, 'Maximum declared metadata count differs');
      Check((LObserver.Calls > 2) and (LObserver.FinalVisits > 0), 'Maximum work never reported');
      WriteLn('maximum_metadata_visits=', LObserver.FinalVisits,
        ' callbacks=', LObserver.Calls, ' local_ms=', GetTickCount64 - LStarted);
    finally
      LReader.Free;
    end;
  finally
    LObserver.Free;
  end;
end;

procedure Run;
var
  LIndex: Integer;
  LFile: TFileStream;
  LReader: TInferenceCorpusReader;
  LObserver: TObserver;
  LTrace: TTrace;
  LPoint: TStopPoint;
  LStage: String;
begin
  Check(ParamCount = 1, 'Supply a fresh isolated artifact directory');
  GDirectory := IncludeTrailingPathDelimiter(ExpandFileName(ParamStr(1)));
  ForceDirectories(GDirectory);
  SetLength(GEntries, 3);
  GEntries[0] := MakeEntry(1, 'scope-a0', 32000, 0, 16000);
  GEntries[1] := MakeEntry(1, 'scope-a1', 32000, 16000, 32000);
  GEntries[2] := MakeEntry(2, 'source-b', 16000, 0, 16000);
  for LIndex := 0 to High(GEntries) do
  begin
    WriteArtifact(GEntries[LIndex], LIndex);
    GHashes[LIndex] := HashInferenceFile(GEntries[LIndex].ArtifactFile);
    LFile := TFileStream.Create(GEntries[LIndex].ArtifactFile, fmOpenRead or fmShareDenyWrite);
    try
      GHashBytes[LIndex] := LFile.Size - 64;
    finally
      LFile.Free;
    end;
  end;
  LReader := TInferenceCorpusReader.Create(GEntries);
  try
    Collect(LReader, GTrace);
  finally
    LReader.Free;
  end;
  Check(Length(GTrace) = 300, 'Frozen authored corpus count');
  LObserver := TObserver.Create;
  LReader := TInferenceCorpusReader.Create(GEntries);
  try
    LObserver.RequireOrdinal := True;
    LTrace := nil;
    Collect(LReader, LTrace, LObserver.Observe);
    CheckTrace(LTrace);
    for LIndex := 0 to 2 do
    begin
      Check(LObserver.ReadRows[LIndex] = 100, 'Entry final row count absent');
    end;
  finally
    LReader.Free;
    LObserver.Free;
  end;
  for LPoint := Low(TStopPoint) to High(TStopPoint) do
  begin
    CheckMetadata(LPoint);
    CheckFileHashAbort(LPoint);
    for LStage in CReadStages do
    begin
      for LIndex := 1 to 3 do
      begin
        CheckReadAbort(LStage, LPoint, LIndex);
      end;
    end;
  end;
  CheckReadAbort('verify_audio_bytes', spStart, 1, True);
  CheckBorrowAndReentry;
  CheckMaximumMetadata;
  for LIndex := 0 to 2 do
  begin
    Check(HashInferenceFile(GEntries[LIndex].ArtifactFile) = GHashes[LIndex], 'Artifact changed');
    WriteLn('artifact', LIndex, '=', GHashes[LIndex]);
  end;
  CheckExclusive;
  WriteLn('PASS checks=', GChecks, ' original_aborts=', GAborts,
    ' exact corpus replay, private batches, failure/reopen, borrowed observers and reentry');
end;

begin
  try
    Run;
  except
    on LError: Exception do
    begin
      WriteLn(StdErr, LError.ClassName, ': ', LError.Message);
      ExitCode := 1;
    end;
  end;
end.
