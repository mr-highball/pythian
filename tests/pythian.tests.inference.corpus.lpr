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
program pythian_tests_inference_corpus;

{$mode delphi}
{$H+}

uses
  Classes,
  SysUtils,
  pythian.audio,
  pythian.hash,
  pythian.inference.observation,
  pythian.inference.corpus;

const
  CRoot = 'build/inference-corpus-fixture';
  CHashA = 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
  CHashB = 'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
  CHashC = 'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc';

type
  TTrace = array of String;

procedure Check(const ACondition: Boolean; const AMessage: String);
begin
  if not ACondition then
    raise EAudio.Create(AMessage);
end;

function ArtifactPath(const AName: String): String;
begin
  Result := IncludeTrailingPathDelimiter(CRoot) + AName + '.pinf';
end;

function MakeIdentity(const AHash: String; const ASourceFrames,
  AScopeStart, AScopeEnd: Int64): TInferenceIdentity;
begin
  Result := Default(TInferenceIdentity);
  Result.Estimator := InferenceEstimator;
  Result.Request := DefaultInferenceRequest(AHash,
    (ASourceFrames * InferenceRate + 15999) div 16000);
  Result.Request.Channel := 0;
  Result.Request.ScopeStart16k := AScopeStart;
  Result.Request.ScopeEnd16k := AScopeEnd;
  Result.Request.InputStart16k := 0;
  Result.Request.InputEnd16k := (ASourceFrames * InferenceRate + 15999) div 16000;
  Result.Request.FirstCenter16k := AScopeStart;
  Result.Request.Hop16k := 160;
  Result.Request.BatchSize := 2;
  Result.SourceRate := InferenceRate;
  Result.SourceChannels := 1;
  Result.SourceFrames := ASourceFrames;
  Result.ObservationCount := InferenceCount(Result.Request);
end;

function MakeEntry(const AGroup, ASource, AName, AHash: String;
  const ASourceFrames, AScopeStart, AScopeEnd: Int64): TInferenceCorpusEntry;
begin
  Result.GroupId := AGroup;
  Result.SourceId := ASource;
  Result.ArtifactFile := ArtifactPath(AName);
  Result.Identity := MakeIdentity(AHash, ASourceFrames, AScopeStart, AScopeEnd);
end;

procedure WriteArtifact(const AEntry: TInferenceCorpusEntry;
  const ABadCenter: Boolean = False);
var
  LSink: TInferenceFileSink;
  LBatch: TInferenceBatch;
  LIndex: Integer;
  LCenter: Int64;
begin
  LSink := TInferenceFileSink.Create(AEntry.ArtifactFile);
  try
    LSink.Start(AEntry.Identity);
    LIndex := 0;
    while LIndex < AEntry.Identity.ObservationCount do
    begin
      SetLength(LBatch, 1);
      LCenter := AEntry.Identity.Request.FirstCenter16k +
        Int64(LIndex) * AEntry.Identity.Request.Hop16k;
      if ABadCenter and (LIndex = 1) then
        Inc(LCenter);
      LBatch[0] := Default(TInferenceObservation);
      LBatch[0].Center16k := LCenter;
      LBatch[0].AcRms := 0.1;
      LBatch[0].Salience[0] := 0.5;
      LSink.Append(LBatch);
      Inc(LIndex);
    end;
    LSink.Complete;
  finally
    LSink.Free;
  end;
end;

procedure WriteBadCenterArtifact(const AEntry: TInferenceCorpusEntry);
var
  LStream: TMemoryStream;
  LHeader: String;
  LHeaderLength: Cardinal;
  LIndex: Int64;
  LObservation: TInferenceObservation;
  LHash: String;
  LFile: TFileStream;
begin
  LHeader := InferenceIdentityText(AEntry.Identity);
  LHeaderLength := Length(LHeader);
  LStream := TMemoryStream.Create;
  try
    LStream.WriteBuffer(LHeaderLength, SizeOf(LHeaderLength));
    LStream.WriteBuffer(LHeader[1], LHeaderLength);
    LIndex := 0;
    while LIndex < AEntry.Identity.ObservationCount do
    begin
      LObservation := Default(TInferenceObservation);
      LObservation.Center16k := AEntry.Identity.Request.FirstCenter16k +
        LIndex * AEntry.Identity.Request.Hop16k;
      if LIndex = 1 then
        Inc(LObservation.Center16k);
      LObservation.AcRms := 0.1;
      LObservation.Salience[0] := 0.5;
      LStream.WriteBuffer(LObservation, SizeOf(LObservation));
      Inc(LIndex);
    end;
    LStream.Position := 0;
    LHash := Sha256Stream(LStream, LStream.Size);
    LStream.Position := LStream.Size;
    LStream.WriteBuffer(LHash[1], Length(LHash));
    LStream.Position := 0;
    LFile := TFileStream.Create(AEntry.ArtifactFile, fmCreate);
    try
      LFile.CopyFrom(LStream, LStream.Size);
    finally
      LFile.Free;
    end;
  finally
    LStream.Free;
  end;
end;

procedure WriteCorruptCopy(const ASource, ADestination: String);
var
  LSource, LDestination: TFileStream;
  LByte: Byte;
begin
  LSource := TFileStream.Create(ASource, fmOpenRead or fmShareDenyWrite);
  try
    LDestination := TFileStream.Create(ADestination, fmCreate);
    try
      LDestination.CopyFrom(LSource, LSource.Size);
      LDestination.Position := LDestination.Size - 1;
      LByte := Ord('0');
      LDestination.WriteBuffer(LByte, SizeOf(LByte));
    finally
      LDestination.Free;
    end;
  finally
    LSource.Free;
  end;
end;

procedure ClearOwnedArtifacts;
var
  LNames: array[0..5] of String;
  LName: String;
begin
  LNames[0] := 'source-a-0.pinf';
  LNames[1] := 'source-a-1.pinf';
  LNames[2] := 'source-b.pinf';
  LNames[3] := 'source-c.pinf';
  LNames[4] := 'bad-center.pinf';
  LNames[5] := 'corrupt-copy.pinf';
  for LName in LNames do
    if FileExists(ArtifactPath(ChangeFileExt(LName, ''))) then
      if not DeleteFile(ArtifactPath(ChangeFileExt(LName, ''))) then
        raise EAudio.Create('Unable to clear a fixture-owned artifact');
end;

function ReadTrace(const AEntries: TInferenceCorpusEntries): TTrace;
var
  LReader: TInferenceCorpusReader;
  LBatch: TInferenceBatch;
  LEntryIndex, LIndex: Integer;
  LCount: Integer;
  LEntry: TInferenceCorpusEntry;
begin
  Result := nil;
  LReader := TInferenceCorpusReader.Create(AEntries);
  try
    while LReader.ReadBatch(LEntryIndex, LBatch) do
    begin
      Check((LEntryIndex >= 0) and (LEntryIndex < LReader.EntryCount),
        'Returned entry index stays in range');
      LEntry := LReader.Entry(LEntryIndex);
      Check((LEntry.GroupId = AEntries[LEntryIndex].GroupId) and
        (LEntry.SourceId = AEntries[LEntryIndex].SourceId) and
        (LEntry.Identity.Request.ScopeStart16k =
          AEntries[LEntryIndex].Identity.Request.ScopeStart16k),
        'Returned entry mapping retains explicit source/group/scope identity');
      Check((Length(LBatch) > 0) and
        (Length(LBatch) <= AEntries[LEntryIndex].Identity.Request.BatchSize),
        'Returned batch obeys scope-local size bound');
      LCount := Length(Result);
      SetLength(Result, LCount + Length(LBatch));
      for LIndex := 0 to High(LBatch) do
        Result[LCount + LIndex] := IntToStr(LEntryIndex) + ':' +
          IntToStr(LBatch[LIndex].Center16k) + ':' +
          FloatToStr(LBatch[LIndex].Salience[0]);
    end;
    Check(not LReader.ReadBatch(LEntryIndex, LBatch),
      'Reader remains exhausted after completion');
  finally
    LReader.Free;
  end;
end;

procedure CheckMetadataRejected(const AEntries: TInferenceCorpusEntries;
  const AMessage: String);
var
  LRejected: Boolean;
  LReader: TInferenceCorpusReader;
begin
  LRejected := False;
  LReader := nil;
  try
    try
      LReader := TInferenceCorpusReader.Create(AEntries);
    except
      on EAudio do
        LRejected := True;
    end;
  finally
    LReader.Free;
  end;
  Check(LRejected, AMessage);
end;

procedure CheckArtifactRejectedBeforeBatch(const AEntry: TInferenceCorpusEntry);
var
  LEntries: TInferenceCorpusEntries;
  LReader: TInferenceCorpusReader;
  LBatch: TInferenceBatch;
  LIndex: Integer;
  LRejected: Boolean;
begin
  SetLength(LEntries, 1);
  LEntries[0] := AEntry;
  LReader := TInferenceCorpusReader.Create(LEntries);
  LBatch := nil;
  LIndex := 99;
  LRejected := False;
  try
    try
      LReader.ReadBatch(LIndex, LBatch);
    except
      on EAudio do
        LRejected := True;
    end;
    Check(LRejected, 'Wrong artifact binding or center sequence rejects');
    Check((Length(LBatch) = 0) and (LIndex = -1),
      'Failed artifact does not expose a batch');
  finally
    LReader.Free;
  end;
end;

procedure Run;
var
  LEntries, LBad: TInferenceCorpusEntries;
  LEntry: TInferenceCorpusEntry;
  LTraceA, LTraceB: TTrace;
  LExpectedTrace: array[0..6] of String;
  LRequest: TInferenceRequest;
  LIndex: Integer;
begin
  ForceDirectories(CRoot);
  ClearOwnedArtifacts;
  SetLength(LEntries, 4);
  LEntries[0] := MakeEntry('g-development', 'source-a', 'source-a-0', CHashA,
    640, 0, 320);
  LEntries[1] := MakeEntry('g-development', 'source-a', 'source-a-1', CHashA,
    640, 320, 640);
  LEntries[2] := MakeEntry('g-development', 'source-b', 'source-b', CHashB,
    320, 0, 320);
  LEntries[3] := MakeEntry('g-challenge', 'source-c', 'source-c', CHashC,
    160, 0, 160);
  for LEntry in LEntries do
    WriteArtifact(LEntry);

  LTraceA := ReadTrace(LEntries);
  LTraceB := ReadTrace(LEntries);
  Check(Length(LTraceA) = 7, 'All source-scope centers are consumed');
  Check(Length(LTraceA) = Length(LTraceB), 'Replay trace lengths match');
  LExpectedTrace[0] := '0:0:0.5';
  LExpectedTrace[1] := '0:160:0.5';
  LExpectedTrace[2] := '1:320:0.5';
  LExpectedTrace[3] := '1:480:0.5';
  LExpectedTrace[4] := '2:0:0.5';
  LExpectedTrace[5] := '2:160:0.5';
  LExpectedTrace[6] := '3:0:0.5';
  for LIndex := 0 to High(LTraceA) do
  begin
    Check(LTraceA[LIndex] = LExpectedTrace[LIndex],
      'Batch rows remain bound to their declared artifact and source clock');
    Check(LTraceA[LIndex] = LTraceB[LIndex],
      'Replay preserves exact source/scope order');
  end;

  LBad := Copy(LEntries);
  LBad[1].Identity.Request.ScopeStart16k := 319;
  LBad[1].Identity.Request.ScopeEnd16k := 639;
  LBad[1].Identity.Request.InputEnd16k := 640;
  LBad[1].Identity.Request.FirstCenter16k := 319;
  LBad[1].Identity.ObservationCount := InferenceCount(LBad[1].Identity.Request);
  CheckMetadataRejected(LBad, 'Overlapping source scopes are rejected');

  LBad := Copy(LEntries);
  LBad[0].Identity.Request.ScopeEnd16k := 321;
  LBad[0].Identity.ObservationCount := InferenceCount(LBad[0].Identity.Request);
  LBad[1].Identity.Request.ScopeStart16k := 321;
  LBad[1].Identity.Request.FirstCenter16k := 321;
  LBad[1].Identity.ObservationCount := InferenceCount(LBad[1].Identity.Request);
  CheckMetadataRejected(LBad, 'Non-final scope hop misalignment rejects');

  LBad := Copy(LEntries);
  LBad[1].Identity.Request.ScopeStart16k := 480;
  LBad[1].Identity.Request.FirstCenter16k := 480;
  LBad[1].Identity.ObservationCount := InferenceCount(LBad[1].Identity.Request);
  CheckMetadataRejected(LBad, 'A missing source scope is rejected');

  LBad := Copy(LEntries);
  LBad[2].Identity.Request.Policy := 'wrong-policy';
  CheckMetadataRejected(LBad, 'Wrong policy rejects before artifact access');

  LBad := Copy(LEntries);
  LBad[2].Identity.Estimator := 'other-estimator';
  CheckMetadataRejected(LBad, 'Wrong estimator rejects before artifact access');

  LBad := Copy(LEntries);
  LBad[3].GroupId := 'g-development';
  LBad[3].SourceId := 'source-a';
  CheckMetadataRejected(LBad, 'Reopened source/group order rejects');

  LBad := Copy(LEntries);
  LBad[0].ArtifactFile := LBad[1].ArtifactFile;
  CheckMetadataRejected(LBad, 'Duplicate artifact binding rejects');

  LBad := Copy(LEntries);
  LBad[2].Identity.Request.SourceHash := CHashC;
  CheckMetadataRejected(LBad, 'Source ID cannot change source hash');

  LEntry := LEntries[2];
  LEntry.Identity.Request.SourceHash := CHashC;
  CheckArtifactRejectedBeforeBatch(LEntry);

  LEntry := MakeEntry('g-development', 'bad-source', 'bad-center', CHashC,
    320, 0, 320);
  WriteBadCenterArtifact(LEntry);
  CheckArtifactRejectedBeforeBatch(LEntry);

  LEntry := LEntries[2];
  LEntry.ArtifactFile := ArtifactPath('corrupt-copy');
  WriteCorruptCopy(LEntries[2].ArtifactFile, LEntry.ArtifactFile);
  CheckArtifactRejectedBeforeBatch(LEntry);

  LRequest := LEntries[0].Identity.Request;
  LRequest.ScopeStart16k := 1;
  LRequest.FirstCenter16k := 1;
  LBad := Copy(LEntries);
  LBad[0].Identity.Request := LRequest;
  LBad[0].Identity.ObservationCount := InferenceCount(LRequest);
  CheckMetadataRejected(LBad, 'Unaligned initial source scope rejects');

  SetLength(LBad, 0);
  CheckMetadataRejected(LBad, 'Empty corpus rejects');
  WriteLn('PASS corpus stream: 4 artifacts, 3 sources, 2 groups, 7 observations');
  WriteLn('PASS replay, source/scope boundary, policy, estimator, binding and center failures');
end;

begin
  try
    Run;
  except
    on E: Exception do
    begin
      WriteLn(StdErr, E.ClassName + ': ' + E.Message);
      ExitCode := 1;
    end;
  end;
end.
