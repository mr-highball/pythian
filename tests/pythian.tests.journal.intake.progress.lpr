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
program pythian_tests_journal_intake_progress;

{$mode delphi}
{$H+}

uses
  Classes, SysUtils, Math, pythian.audio, pythian.progress,
  pythian.analysis, pythian.analysis.wave, pythian.analysis.journal,
  pythian.stream.bytes, pythian.hash;

type
  TStorage = class(TAudioBytesStream)
    MaximumTransfer: Integer;
    MaximumRequest: Integer;
    Flushes: Integer;
    FailFlush: Boolean;
    Raised: Exception;
    constructor Create;
    procedure Commit;
    {$ifdef pas2js}
    function Read(ABuffer: TBytes; AOffset, ACount: LongInt): LongInt; override;
    function Write(const ABuffer: TBytes; AOffset, ACount: LongInt): LongInt; override;
    {$else}
    function Read(var ABuffer; ACount: LongInt): LongInt; override;
    function Write(const ABuffer; ACount: LongInt): LongInt; override;
    {$endif}
  end;

  TProbe = class
    Calls: Integer;
    AbortAt: Integer;
    Raised: Exception;
    Journal: TFeatureJournal;
    BeforeNext: Int64;
    Reentry: Integer;
    Reentered: Boolean;
    WriteAdmitted: Boolean;
    LastDone: Int64;
    SawValidation: Boolean;
    SawEncoding: Boolean;
    SawDecoding: Boolean;
    SawTransfer: Boolean;
    SawHash: Boolean;
    SawCommit: Boolean;
    procedure Observe(const AWork: TWorkProgress);
  end;

var
  GChecks: Integer;
  GAborts: Integer;

procedure Check(const ACondition: Boolean; const AMessage: String);
begin
  if not ACondition then
  begin
    raise EAudio.Create(AMessage);
  end;
  Inc(GChecks);
end;

procedure TStorage.Commit;
begin
  if FailFlush then
  begin
    Raised := Exception.Create('Original journal commit failure');
    raise Raised;
  end;
  Inc(Flushes);
end;

constructor TStorage.Create;
begin
  inherited Create(1048576);
end;

{$ifdef pas2js}
function TStorage.Read(ABuffer: TBytes; AOffset, ACount: LongInt): LongInt;
begin
  MaximumRequest := Max(MaximumRequest, ACount);
  if MaximumTransfer > 0 then
  begin
    ACount := Min(ACount, MaximumTransfer);
  end;
  Result := inherited Read(ABuffer, AOffset, ACount);
end;
function TStorage.Write(const ABuffer: TBytes; AOffset, ACount: LongInt): LongInt;
begin
  MaximumRequest := Max(MaximumRequest, ACount);
  if MaximumTransfer > 0 then
  begin
    ACount := Min(ACount, MaximumTransfer);
  end;
  Result := inherited Write(ABuffer, AOffset, ACount);
end;
{$else}
function TStorage.Read(var ABuffer; ACount: LongInt): LongInt;
begin
  MaximumRequest := Max(MaximumRequest, ACount);
  if MaximumTransfer > 0 then
  begin
    ACount := Min(ACount, MaximumTransfer);
  end;
  Result := inherited Read(ABuffer, ACount);
end;
function TStorage.Write(const ABuffer; ACount: LongInt): LongInt;
begin
  MaximumRequest := Max(MaximumRequest, ACount);
  if MaximumTransfer > 0 then
  begin
    ACount := Min(ACount, MaximumTransfer);
  end;
  Result := inherited Write(ABuffer, ACount);
end;
{$endif}

function Binding: TFeatureJournalBinding;
begin
  Result := Default(TFeatureJournalBinding);
  Result.SourceSha256 := StringOfChar('a', 64);
  Result.SampleRate := 8000;
  Result.Channels := 1;
  Result.FrameCount := 8320;
  Result.Options := DefaultAnalysisOptions;
  Result.Options.WindowFrames := 64;
  Result.Options.HopFrames := 16;
  Result.Options.SilenceRms := 0;
end;

function Batch: TWaveFeatureBatch;
var
  LIndex: Integer;
begin
  Result := Default(TWaveFeatureBatch);
  Result.NextFeature := 520;
  Result.Completed := True;
  SetLength(Result.Features, 520);
  for LIndex := 0 to High(Result.Features) do
  begin
    Result.Features[LIndex] := Default(TAudioFeature);
    Result.Features[LIndex].StartFrame := LIndex * 16;
    Result.Features[LIndex].ValidFrames := Min(64, 8320 - LIndex * 16);
    Result.Features[LIndex].Rms := 0.125;
    Result.Features[LIndex].Peak := 0.25;
    Result.Features[LIndex].Chroma[LIndex mod 12] := 1;
  end;
end;

function Snapshot(const AStorage: TStorage): TAudioBytes;
begin
  Result := nil;
  SetLength(Result, AStorage.Size);
  AStorage.Position := 0;
  ReadStreamBytesExact(AStorage, Result, 0, Length(Result));
end;

procedure Restore(const AStorage: TStorage; const ABytes: TAudioBytes);
begin
  AStorage.Size := 0;
  AStorage.Position := 0;
  WriteStreamBytesExact(AStorage, ABytes, 0, Length(ABytes));
end;

procedure TProbe.Observe(const AWork: TWorkProgress);
var
  LBatch: TWaveFeatureBatch;
  LRejected: Boolean;
begin
  Inc(Calls);
  if Journal <> nil then
  begin
    Check(Journal.NextFeature = BeforeNext, 'Observer saw partial journal publication');
  end;
  Check((AWork.Done >= 0) and (AWork.Total >= 0) and
    ((AWork.Total = 0) or (AWork.Done <= AWork.Total)) and
    (AWork.Pass = 0), 'Invalid stage-local progress');
  LastDone := AWork.Done;
  WriteAdmitted := WriteAdmitted or (AWork.Stage = 'write_bytes');
  SawValidation := SawValidation or ((AWork.Stage = 'journal_validate') and
    (AWork.Done = 128) and (AWork.Total = 520) and (AWork.Units = wuObservations));
  SawEncoding := SawEncoding or ((AWork.Stage = 'journal_encode') and (AWork.Done = 128));
  SawDecoding := SawDecoding or ((AWork.Stage = 'journal_decode') and (AWork.Done = 128));
  SawTransfer := SawTransfer or (((AWork.Stage = 'read_bytes') or
    (AWork.Stage = 'write_bytes')) and (AWork.Done > 0) and
    (AWork.Done < AWork.Total) and (AWork.Units = wuBytes));
  SawHash := SawHash or ((AWork.Stage = 'verify_audio_bytes') and
    (AWork.Done > 0) and (AWork.Done < AWork.Total) and (AWork.Units = wuBytes));
  SawCommit := SawCommit or ((AWork.Stage = 'journal_commit') and
    (AWork.Done = 1) and (AWork.Total = 1) and (AWork.Units = wuItems));
  if (Journal <> nil) and (Reentry > 0) and not Reentered and
    ((AWork.Stage = 'journal_encode') or (AWork.Stage = 'journal_decode')) and
    (AWork.Done = 128) then
  begin
    Reentered := True;
    LRejected := False;
    try
      case Reentry of
        1: Journal.Rewind;
        2: Journal.ReadNext(LBatch);
        3: Journal.Append(Batch);
        4: Journal.RecoverTail;
      end;
    except
      on EAudio do
      begin
        LRejected := True;
      end;
    end;
    Check(LRejected, 'Mutating journal reentry was accepted');
  end;
  if Calls = AbortAt then
  begin
    Raised := Exception.Create('Original journal observer abort');
    raise Raised;
  end;
end;

procedure CheckTransfer;
var
  LStorage: TStorage;
  LProbe: TProbe;
  LInput: TAudioBytes;
  LOutput: TAudioBytes;
  LIndex: Integer;
begin
  SetLength(LInput, 70000);
  for LIndex := 0 to High(LInput) do
  begin
    LInput[LIndex] := LIndex mod 251;
  end;
  SetLength(LOutput, Length(LInput));
  LStorage := TStorage.Create;
  LProbe := TProbe.Create;
  try
    LStorage.MaximumTransfer := 7;
    WriteStreamBytesExact(LStorage, LInput, 0, Length(LInput), LProbe.Observe);
    Check((LProbe.Calls = 80) and (LProbe.LastDone = 70000) and
      (LStorage.MaximumRequest <= 65536), 'Short write progress or chunk bound differs');
    FreeAndNil(LProbe);
    LProbe := TProbe.Create;
    LStorage.Position := 0;
    LStorage.MaximumRequest := 0;
    ReadStreamBytesExact(LStorage, LOutput, 0, Length(LOutput), LProbe.Observe);
    Check((LProbe.Calls = 80) and (LProbe.LastDone = 70000) and
      (LStorage.MaximumRequest <= 65536), 'Short read progress or chunk bound differs');
    for LIndex := 0 to High(LInput) do
    begin
      Check(LInput[LIndex] = LOutput[LIndex], 'Short-transfer bytes changed');
    end;
  finally
    LProbe.Free;
    LStorage.Free;
  end;
end;

procedure CheckOperation(const AMode: Integer; const AFull: TAudioBytes);
var
  LStorage: TStorage;
  LJournal: TFeatureJournal;
  LProbe: TProbe;
  LBatch: TWaveFeatureBatch;
  LHeaderHash: String;
  LAbort: Integer;
  LCalls: Integer;
  LRejected: Boolean;
  LWriteAdmitted: Boolean;
  LFailedRejected: Boolean;
  LIndex: Integer;
begin
  LCalls := 0;
  LAbort := 0;
  repeat
    LStorage := TStorage.Create;
    LProbe := TProbe.Create;
    LJournal := nil;
    try
      LProbe.AbortAt := LAbort;
      if AMode = 1 then
      begin
        LJournal := TFeatureJournal.Create(LStorage, Binding, LStorage.Commit, True);
        LHeaderHash := Sha256Bytes(Snapshot(LStorage));
      end
      else if AMode > 1 then
      begin
        Restore(LStorage, AFull);
        if AMode = 3 then
        begin
          LJournal := TFeatureJournal.Create(LStorage, Binding, LStorage.Commit, False);
        end;
      end;
      LBatch := Default(TWaveFeatureBatch);
      LProbe.Journal := LJournal;
      if LJournal <> nil then
      begin
        LProbe.BeforeNext := LJournal.NextFeature;
      end;
      LBatch.FirstFeature := 777;
      LBatch.NextFeature := 888;
      SetLength(LBatch.Features, 1);
      LBatch.Features[0].Rms := 9;
      LRejected := False;
      try
        case AMode of
          0: LJournal := TFeatureJournal.Create(LStorage, Binding, LStorage.Commit,
               True, LProbe.Observe);
          1: LJournal.Append(Batch, LProbe.Observe);
          2: LJournal := TFeatureJournal.Create(LStorage, Binding, LStorage.Commit,
               False, LProbe.Observe);
          3: Check(LJournal.ReadNext(LBatch, LProbe.Observe), 'Expected one journal batch');
        end;
      except
        on LException: Exception do
        begin
          Check((LAbort > 0) and (LException = LProbe.Raised), 'Original exception changed');
          LProbe.Raised := nil;
          LRejected := True;
          Inc(GAborts);
        end;
      end;
      LWriteAdmitted := LProbe.WriteAdmitted;
      if LAbort = 0 then
      begin
        LCalls := LProbe.Calls;
        Check(LCalls > 0, 'Operation did not report progress');
        if AMode = 1 then
        begin
          Check(LProbe.SawValidation and LProbe.SawEncoding and LProbe.SawTransfer and
            LProbe.SawHash and LProbe.SawCommit, 'Missing real append interior');
        end;
        if AMode > 1 then
        begin
          Check(LProbe.SawValidation and LProbe.SawDecoding and LProbe.SawTransfer and
            LProbe.SawHash, 'Missing real decode interior');
        end;
        if AMode = 3 then
        begin
          Check((LBatch.FirstFeature = 0) and (LBatch.NextFeature = 520) and
            LBatch.Completed and (LBatch.SourceStartFrame = 0) and
            (Length(LBatch.Features) = 520), 'Decoded batch geometry differs');
          for LIndex := 0 to High(LBatch.Features) do
          begin
            Check((LBatch.Features[LIndex].Rms = 0.125) and
              (LBatch.Features[LIndex].Chroma[LIndex mod 12] = 1) and
              (LBatch.Features[LIndex].StartFrame = LIndex * 16) and
              (LBatch.Features[LIndex].ValidFrames = Min(64, 8320 - LIndex * 16)),
              'Decoded source observation changed');
          end;
        end;
      end
      else
      begin
        Check(LRejected and (LProbe.Calls = LAbort), 'Observer abort did not stop immediately');
      end;
      FreeAndNil(LProbe);
      if (AMode = 1) and LRejected then
      begin
        Check(LJournal.NextFeature = 0, 'Failed append published a prefix');
        Check(LJournal.Failed = LWriteAdmitted, 'Preparation/write failure scopes differ');
        if not LJournal.Failed then
        begin
          Check(Sha256Bytes(Snapshot(LStorage)) = LHeaderHash, 'Preparation changed storage');
          LJournal.Append(Batch);
        end;
      end;
      if (AMode = 3) and LRejected then
      begin
        Check(LJournal.Failed and (LBatch.FirstFeature = 777) and
          (LBatch.NextFeature = 888) and (Length(LBatch.Features) = 1) and
          (LBatch.Features[0].Rms = 9), 'Read abort published partial caller data');
      end;
      if (LJournal <> nil) and LJournal.Failed then
      begin
        LFailedRejected := False;
        try
          LJournal.ReadNext(LBatch);
        except
          on EAudio do
          begin
            LFailedRejected := True;
          end;
        end;
        Check(LFailedRejected, 'Failed journal resumed without reopening');
      end;
      if LRejected and ((AMode = 0) or (AMode = 2)) then
      begin
        Check(LJournal = nil, 'Failed constructor published an instance');
      end;
      FreeAndNil(LJournal);
      if LStorage.Size > 0 then
      begin
        LJournal := TFeatureJournal.Create(LStorage, Binding, LStorage.Commit, False);
        if LJournal.TailBytes > 0 then
        begin
          LJournal.RecoverTail;
        end;
        if not LJournal.Completed then
        begin
          LJournal.Append(Batch);
        end;
        Check(Sha256Bytes(Snapshot(LStorage)) = Sha256Bytes(AFull), 'Fresh reopen/retry bytes drift');
      end;
    finally
      LProbe.Free;
      LJournal.Free;
      LStorage.Free;
    end;
    Inc(LAbort);
  until LAbort > LCalls;
end;

procedure CheckReentry(const AFull: TAudioBytes);
var
  LStorage: TStorage;
  LJournal: TFeatureJournal;
  LProbe: TProbe;
  LBatch: TWaveFeatureBatch;
  LMode: Integer;
  LAction: Integer;
  LHash: String;
  LRejected: Boolean;
begin
  for LMode := 0 to 1 do
    for LAction := 1 to 4 do
    begin
      LStorage := TStorage.Create;
      LJournal := nil;
      LProbe := TProbe.Create;
      try
        if LMode = 1 then
        begin
          Restore(LStorage, AFull);
        end;
        LJournal := TFeatureJournal.Create(LStorage, Binding, LStorage.Commit, LMode = 0);
        LHash := Sha256Bytes(Snapshot(LStorage));
        LProbe.Journal := LJournal;
        LProbe.BeforeNext := LJournal.NextFeature;
        LProbe.Reentry := LAction;
        LRejected := False;
        try
          if LMode = 0 then
          begin
            LJournal.Append(Batch, LProbe.Observe);
          end
          else
          begin
            LJournal.ReadNext(LBatch, LProbe.Observe);
          end;
        except
          on EAudio do
          begin
            LRejected := True;
          end;
        end;
        Check(LRejected and LProbe.Reentered and LJournal.Failed and
          (Sha256Bytes(Snapshot(LStorage)) = LHash), 'Reentry accepted data or changed storage');
      finally
        LProbe.Free;
        LJournal.Free;
        LStorage.Free;
      end;
    end;
end;

procedure CheckRecoveryAndCommit(const AFull: TAudioBytes);
var
  LStorage: TStorage;
  LJournal: TFeatureJournal;
  LProbe: TProbe;
  LPartial: TAudioBytes;
  LAbort: Integer;
  LRejected: Boolean;
begin
  LPartial := Copy(AFull, 0, Length(AFull) - 10);
  for LAbort := 0 to 2 do
  begin
    LStorage := TStorage.Create;
    LProbe := TProbe.Create;
    LJournal := nil;
    try
      Restore(LStorage, LPartial);
      LJournal := TFeatureJournal.Create(LStorage, Binding, LStorage.Commit, False);
      Check((LJournal.NextFeature = 0) and (LJournal.TailBytes > 0),
        'Incomplete record was treated as committed');
      LProbe.AbortAt := LAbort;
      LRejected := False;
      try
        LJournal.RecoverTail(LProbe.Observe);
      except
        on LException: Exception do
        begin
          Check((LAbort > 0) and (LException = LProbe.Raised),
            'Recovery replaced observer exception');
          LProbe.Raised := nil;
          LRejected := True;
          Inc(GAborts);
        end;
      end;
      Check(LRejected = (LAbort > 0), 'Recovery abort did not propagate');
      if LAbort > 0 then
      begin
        Check(LJournal.Failed and (LJournal.NextFeature = 0),
          'Recovery abort accepted metadata');
      end
      else
      begin
        Check((LProbe.Calls = 2) and (LStorage.Size = 172) and
          (LJournal.TailBytes = 0), 'Recovery progress or prefix changed');
      end;
      FreeAndNil(LProbe);
      FreeAndNil(LJournal);
      LJournal := TFeatureJournal.Create(LStorage, Binding, LStorage.Commit, False);
      if LJournal.TailBytes > 0 then
      begin
        LJournal.RecoverTail;
      end;
      LJournal.Append(Batch);
      Check(Sha256Bytes(Snapshot(LStorage)) = Sha256Bytes(AFull),
        'Recovery retry changed complete bytes');
    finally
      LProbe.Free;
      LJournal.Free;
      LStorage.Free;
    end;
  end;
  LStorage := TStorage.Create;
  LProbe := TProbe.Create;
  LJournal := nil;
  try
    LJournal := TFeatureJournal.Create(LStorage, Binding, LStorage.Commit, True);
    LStorage.FailFlush := True;
    LRejected := False;
    try
      LJournal.Append(Batch, LProbe.Observe);
    except
      on LException: Exception do
      begin
        Check(LException = LStorage.Raised, 'Commit failure exception changed');
        LStorage.Raised := nil;
        LRejected := True;
      end;
    end;
    Check(LRejected and LJournal.Failed and (LJournal.NextFeature = 0) and
      not LProbe.SawCommit, 'Failed commit published successful metadata');
    FreeAndNil(LJournal);
    LStorage.FailFlush := False;
    LJournal := TFeatureJournal.Create(LStorage, Binding, LStorage.Commit, False);
    Check(LJournal.Completed and (Sha256Bytes(Snapshot(LStorage)) = Sha256Bytes(AFull)),
      'Reopen did not discover fully written bytes after commit failure');
  finally
    LProbe.Free;
    LJournal.Free;
    LStorage.Free;
  end;
end;

procedure Run;
var
  LStorage: TStorage;
  LJournal: TFeatureJournal;
  LBytes: TAudioBytes;
  LMode: Integer;
begin
  CheckTransfer;
  LStorage := TStorage.Create;
  LJournal := nil;
  try
    LJournal := TFeatureJournal.Create(LStorage, Binding, LStorage.Commit, True);
    LJournal.Append(Batch);
    LBytes := Snapshot(LStorage);
    Check(Sha256Bytes(LBytes) =
      '95c3bf82c28af1f9e4d75a06f12deaa9546f94053d5d39219346b820686f4759',
      'Original native full journal bytes changed');
    WriteLn('JOURNAL=', Sha256Bytes(LBytes));
  finally
    LJournal.Free;
    LStorage.Free;
  end;
  for LMode := 0 to 3 do
  begin
    CheckOperation(LMode, LBytes);
  end;
  CheckReentry(LBytes);
  CheckRecoveryAndCommit(LBytes);
end;

begin
  try
    Run;
    WriteLn('PASS journal intake progress checks=', GChecks, ' aborts=', GAborts);
  except
    on LException: Exception do
    begin
      WriteLn(LException.ClassName, ': ', LException.Message);
      ExitCode := 1;
    end;
  end;
end.
