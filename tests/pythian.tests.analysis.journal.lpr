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

program pythian_tests_analysis_journal;

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
  pythian.wave,
  pythian.wave.read,
  pythian.hash;

type
  TFaultStream = class(TMemoryStream)
  public
    FailAfter: Int64;
    FailFlush: Boolean;
    Flushes: Integer;
    function Write(const ABuffer; ACount: LongInt): LongInt; override;
    procedure Commit;
  end;

procedure Check(const ACondition: Boolean; const AMessage: String);
begin
  if not ACondition then
  begin
    raise Exception.Create(AMessage);
  end;
end;

function TFaultStream.Write(const ABuffer; ACount: LongInt): LongInt;
begin
  if (FailAfter >= 0) and (Position + ACount > FailAfter) then
  begin
    Result := Max(Int64(0), FailAfter - Position);
    if Result > 0 then
    begin
      inherited Write(ABuffer, Result);
    end;
    raise EWriteError.Create('Injected partial journal write');
  end;
  Result := inherited Write(ABuffer, ACount);
end;

procedure TFaultStream.Commit;
begin
  Inc(Flushes);
  if FailFlush then
  begin
    raise EWriteError.Create('Injected commit failure');
  end;
end;

function Snapshot(const AStream: TMemoryStream): TAudioBytes;
begin
  Result := nil;
  SetLength(Result, AStream.Size);
  if Length(Result) > 0 then
  begin
    Move(AStream.Memory^, Result[0], Length(Result));
  end;
end;

procedure Restore(const AStream: TFaultStream; const ABytes: TAudioBytes;
  const ALength: Integer);
begin
  AStream.FailAfter := -1;
  AStream.FailFlush := False;
  AStream.Size := 0;
  AStream.WriteBuffer(ABytes[0], ALength);
end;

procedure Run;
var
  LSamples: TAudioSamples;
  LBytes: TAudioBytes;
  LComplete: TAudioBytes;
  LClip: TAudioClip;
  LWaveStream: TMemoryStream;
  LReader: TWaveFrameReader;
  LStorage: TFaultStream;
  LJournal: TFeatureJournal;
  LBinding: TFeatureJournalBinding;
  LChanged: TFeatureJournalBinding;
  LFirst: TWaveFeatureBatch;
  LSecond: TWaveFeatureBatch;
  LRead: TWaveFeatureBatch;
  LExpected: TAudioFeatures;
  LActual: TAudioFeatures;
  LPrefix: Integer;
  LSecondEnd: Integer;
  LIndex: Integer;
  LPitch: Integer;
  LCase: Integer;
  LCut: Integer;
  LRejected: Boolean;
  LBeforeHash: String;
  LPosition: Integer;
begin
  SetLength(LSamples, 1001);
  for LIndex := 0 to High(LSamples) do
  begin
    LSamples[LIndex] := 0.6 * Sin(2 * Pi * 440 * LIndex / 8000);
    if (LIndex > 300) and (LIndex < 650) then
    begin
      LSamples[LIndex] := 0;
    end;
  end;
  LClip := TAudioClip.Create(8000, 1, LSamples);
  try
    LBytes := EncodeWavePcm16(LClip);
  finally
    LClip.Free;
  end;
  LWaveStream := TMemoryStream.Create;
  LStorage := TFaultStream.Create;
  LReader := nil;
  LJournal := nil;
  try
    LStorage.FailAfter := -1;
    LWaveStream.WriteBuffer(LBytes[0], Length(LBytes));
    LWaveStream.Position := 0;
    LReader := TWaveFrameReader.Create(LWaveStream);
    LBinding := Default(TFeatureJournalBinding);
    LBinding.SourceSha256 := Sha256Bytes(LBytes);
    LBinding.SampleRate := 8000;
    LBinding.Channels := 1;
    LBinding.FrameCount := 1001;
    LBinding.Options := DefaultAnalysisOptions;
    LBinding.Options.WindowFrames := 128;
    LBinding.Options.HopFrames := 47;
    LExpected := AnalyzeWave(LReader, LBinding.Options);
    LFirst := AnalyzeWaveBatch(LReader, LBinding.Options, 0, 7);
    LSecond := AnalyzeWaveBatch(LReader, LBinding.Options, 7, 7);
    LJournal := TFeatureJournal.Create(LStorage, LBinding, LStorage.Commit, True);
    LJournal.Append(LFirst);
    LPrefix := LStorage.Size;
    Check((LStorage.Flushes = 2) and (LJournal.NextFeature = 7), 'Header and batch commit');
    LRejected := False;
    try
      LJournal.Append(LFirst);
    except
      on EAudio do LRejected := True;
    end;
    Check(LRejected and not LJournal.Failed and (LStorage.Size = LPrefix),
      'Duplicate observation range rejects without writes');
    LStorage.FailAfter := LPrefix + 200;
    LRejected := False;
    try
      LJournal.Append(LSecond);
    except
      on EWriteError do LRejected := True;
    end;
    Check(LRejected and LJournal.Failed and (LJournal.NextFeature = 7),
      'Partial write poisons without advancing progress');
    FreeAndNil(LJournal);
    LStorage.FailAfter := -1;
    LJournal := TFeatureJournal.Create(LStorage, LBinding, LStorage.Commit, False);
    Check((LJournal.NextFeature = 7) and (LJournal.TailBytes = 200) and
      (LStorage.Size = LPrefix + 200), 'Open finds incomplete tail without mutation');
    LJournal.RecoverTail;
    Check((LStorage.Size = LPrefix) and (LJournal.TailBytes = 0), 'Recovery retains accepted prefix');
    LStorage.FailFlush := True;
    LRejected := False;
    try
      LJournal.Append(LSecond);
    except
      on EWriteError do LRejected := True;
    end;
    Check(LRejected and LJournal.Failed and (LJournal.NextFeature = 7),
      'Commit failure leaves caller progress unacknowledged');
    LSecondEnd := LStorage.Size;
    FreeAndNil(LJournal);
    LStorage.FailFlush := False;
    LJournal := TFeatureJournal.Create(LStorage, LBinding, LStorage.Commit, False);
    Check((LJournal.NextFeature = 14) and (LJournal.TailBytes = 0),
      'Reopen accepts complete in-doubt record exactly once');
    while not LJournal.Completed do
    begin
      LRead := AnalyzeWaveBatch(LReader, LBinding.Options, LJournal.NextFeature, 5);
      LJournal.Append(LRead);
    end;
    SetLength(LActual, Length(LExpected));
    while LJournal.ReadNext(LRead) do
    begin
      for LIndex := 0 to High(LRead.Features) do
      begin
        LPosition := LRead.FirstFeature + LIndex;
        LActual[LPosition] := LRead.Features[LIndex];
        LActual[LPosition].StartFrame := LRead.SourceStartFrame + LRead.Features[LIndex].StartFrame;
      end;
    end;
    for LIndex := 0 to High(LExpected) do
    begin
      Check((LActual[LIndex].StartFrame = LExpected[LIndex].StartFrame) and
        (LActual[LIndex].ValidFrames = LExpected[LIndex].ValidFrames) and
        (LActual[LIndex].Rms = LExpected[LIndex].Rms) and
        (LActual[LIndex].Peak = LExpected[LIndex].Peak) and
        (LActual[LIndex].Flux = LExpected[LIndex].Flux) and
        (LActual[LIndex].CentroidHz = LExpected[LIndex].CentroidHz) and
        (LActual[LIndex].Silent = LExpected[LIndex].Silent), 'Journal feature round trip');
      for LPitch := 0 to 11 do
      begin
        Check(LActual[LIndex].Chroma[LPitch] = LExpected[LIndex].Chroma[LPitch],
          'Journal chroma round trip');
      end;
    end;
    LComplete := Snapshot(LStorage);
    FreeAndNil(LJournal);
    LBeforeHash := Sha256Bytes(LComplete);
    for LCase := 0 to 2 do
    begin
      LChanged := LBinding;
      case LCase of
        0: LChanged.SourceSha256[1] := 'f';
        1: Inc(LChanged.Options.HopFrames);
        2: Inc(LChanged.FrameCount);
      end;
      if LCase = 0 then
      begin
        if LBinding.SourceSha256[1] = 'f' then
        begin
          LChanged.SourceSha256[1] := 'a';
        end;
      end;
      LRejected := False;
      try
        LJournal := TFeatureJournal.Create(LStorage, LChanged, LStorage.Commit, False);
      except
        on EAudio do LRejected := True;
      end;
      FreeAndNil(LJournal);
      Check(LRejected and (Sha256Bytes(Snapshot(LStorage)) = LBeforeHash),
        'Changed source or options rejects without altering cache');
    end;
    for LCase := 0 to 2 do
    begin
      case LCase of
        0: LCut := LPrefix + 1;
        1: LCut := LPrefix + 141;
        2: LCut := LSecondEnd - 1;
      end;
      Restore(LStorage, LComplete, LCut);
      LJournal := TFeatureJournal.Create(LStorage, LBinding, LStorage.Commit, False);
      Check((LJournal.NextFeature = 7) and (LJournal.TailBytes = LCut - LPrefix),
        'Incomplete header, payload and digest retain same prefix');
      LJournal.RecoverTail;
      Check(LStorage.Size = LPrefix, 'Only incomplete tail removed');
      FreeAndNil(LJournal);
    end;
    LComplete[LPrefix + 145] := LComplete[LPrefix + 145] xor 1;
    Restore(LStorage, LComplete, Length(LComplete));
    LBeforeHash := Sha256Bytes(Snapshot(LStorage));
    LRejected := False;
    try
      LJournal := TFeatureJournal.Create(LStorage, LBinding, LStorage.Commit, False);
    except
      on EAudio do LRejected := True;
    end;
    Check(LRejected and (Sha256Bytes(Snapshot(LStorage)) = LBeforeHash),
      'Complete corrupt record rejects and is never silently repaired');
    WriteLn('Journal commits, restart, partial recovery, integrity, binding and feature parity PASS');
  finally
    LJournal.Free;
    LReader.Free;
    LStorage.Free;
    LWaveStream.Free;
  end;
end;

begin
  try
    Run;
  except
    on LException: Exception do
    begin
      WriteLn(StdErr, LException.ClassName, ': ', LException.Message);
      Halt(1);
    end;
  end;
end.
