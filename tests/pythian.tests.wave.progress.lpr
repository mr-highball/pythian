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
program pythian_tests_wave_progress;
{$mode delphi}
{$H+}
uses
  SysUtils, Classes, pythian.audio, pythian.progress, pythian.wave,
  pythian.wave.stream, pythian.stream.bytes;
type
  EProbe = class(Exception);
  TProbe = class
    Stage: String;
    AbortStage: String;
    AtHeader: Boolean;
    Reenter: Boolean;
    Writer: TWavePcm16Writer;
    RaisedObject: Exception;
    LastWrite: Int64;
    LastBytes: Int64;
    LastItems: Int64;
    Calls: Integer;
    procedure Observe(const AProgress: TWorkProgress);
  end;
  TProbeSink = class(TAudioByteSink)
    Stream: TMemoryStream;
    FailNext: Boolean;
    RaisedObject: Exception;
    constructor Create;
    destructor Destroy; override;
    procedure WriteBytes(const ABytes: array of Byte); override;
  end;
var
  Checks: Integer;
procedure Check(const AValue: Boolean; const AMessage: String);
begin
  Inc(Checks);
  if not AValue then
    raise Exception.Create(AMessage);
end;
procedure TProbe.Observe(const AProgress: TWorkProgress);
var
  LPrevious: Int64;
begin
  Inc(Calls);
  Check((AProgress.Done >= 0) and (AProgress.Done <= AProgress.Total), 'progress bounds');
  if AProgress.Stage = 'write_wave_pcm16' then
  begin
    Check(AProgress.Units = wuFrames, 'write unit');
    LPrevious := LastWrite;
    Check(AProgress.Done >= LPrevious, 'write monotonic');
    Check(AProgress.Done - LPrevious <= 2048, 'write block bounded');
    LastWrite := AProgress.Done;
  end
  else if AProgress.Stage = 'validate_wave_samples' then
  begin
    Check(AProgress.Units = wuItems, 'validation unit');
    if AProgress.Done = 0 then
      LastItems := 0;
    Check((AProgress.Done >= LastItems) and (AProgress.Done - LastItems <= 4096), 'validation cadence');
    LastItems := AProgress.Done;
  end
  else if AProgress.Stage = 'encode_wave_bytes' then
  begin
    Check(AProgress.Units = wuBytes, 'readback unit');
    Check((AProgress.Done >= LastBytes) and (AProgress.Done - LastBytes <= 65536), 'readback cadence');
    LastBytes := AProgress.Done;
  end
  else
    raise Exception.Create('Unknown progress stage');
  if Reenter and (Writer <> nil) and (AProgress.Stage = 'write_wave_pcm16') and
    (AProgress.Done > 0) then
    Writer.Finish;
  if (AProgress.Stage = AbortStage) and
    ((AtHeader and (AProgress.Done = 0)) or
    ((AProgress.Done > 0) and (AProgress.Done < AProgress.Total))) then
  begin
    RaisedObject := EProbe.Create('original observer');
    raise RaisedObject;
  end;
end;
constructor TProbeSink.Create;
begin
  inherited Create;
  Stream := TMemoryStream.Create;
end;
destructor TProbeSink.Destroy;
begin
  Stream.Free;
  inherited Destroy;
end;
procedure TProbeSink.WriteBytes(const ABytes: array of Byte);
begin
  if FailNext then
  begin
    RaisedObject := EProbe.Create('original sink');
    raise RaisedObject;
  end;
  Check(WriteStreamBytes(Stream, ABytes, 0, Length(ABytes)) = Length(ABytes), 'sink write');
end;
procedure SameBytes(const A, B: TAudioBytes);
var
  LIndex: Integer;
begin
  Check(Length(A) = Length(B), 'byte length');
  for LIndex := 0 to High(A) do
    if A[LIndex] <> B[LIndex] then
      raise Exception.Create('byte mismatch');
  Inc(Checks);
end;
procedure TestFormat(const AChannels: Integer; const ADirectory: String);
var
  LSamples: TAudioSamples;
  LFirst: TAudioSamples;
  LSecond: TAudioSamples;
  LClip: TAudioClip;
  LExpected: TAudioBytes;
  LActual: TAudioBytes;
  LStream: TMemoryStream;
  LSink: TProbeSink;
  LProbe: TProbe;
  LWriter: TWavePcm16Writer;
  LIndex: Integer;
  LRejected: Boolean;
  LStage: Integer;
  {$ifndef pas2js}
  LFile: TFileStream;
  {$endif}
begin
  SetLength(LSamples, 40000 * AChannels);
  for LIndex := 0 to High(LSamples) do
    LSamples[LIndex] := (LIndex mod 127 - 63) / 128;
  LClip := TAudioClip.Create(8000, AChannels, LSamples);
  LProbe := TProbe.Create;
  try
    LExpected := EncodeWavePcm16(LClip);
    LActual := EncodeWavePcm16(LClip, LProbe.Observe);
    SameBytes(LExpected, LActual);
    Check((LProbe.LastWrite = 40000) and (LProbe.LastBytes = Length(LExpected)), 'encode endpoints');
    Check(LProbe.Calls < 50, 'encode bounded calls');
    LProbe.Free;
    LProbe := TProbe.Create;
    LStream := TMemoryStream.Create;
    try
      WriteWavePcm16(LStream, LClip, LProbe.Observe);
      Check(LStream.Size = Length(LExpected), 'stream length');
      LStream.Position := 0;
      SetLength(LActual, LStream.Size);
      Check(ReadStreamBytes(LStream, LActual, 0, Length(LActual)) = Length(LActual), 'read stream');
      SameBytes(LExpected, LActual);
    finally
      LStream.Free;
    end;
    LProbe.Free;
    LProbe := TProbe.Create;
    LSink := TProbeSink.Create;
    try
      LWriter := TWavePcm16Writer.Create(LSink, 8000, AChannels, 40000, LProbe.Observe);
      try
        try
          LWriter.Finish;
        except
          on EAudio do
          begin
          end;
        end;
        Check(not LWriter.Failed, 'short finish recoverable');
        SetLength(LFirst, 18000 * AChannels);
        SetLength(LSecond, 22000 * AChannels);
        for LIndex := 0 to High(LFirst) do
          LFirst[LIndex] := LSamples[LIndex];
        for LIndex := 0 to High(LSecond) do
          LSecond[LIndex] := LSamples[Length(LFirst) + LIndex];
        LWriter.AppendSamples(LFirst);
        LWriter.AppendSamples(LSecond);
        LWriter.Finish;
        Check(LWriter.Finished and (LWriter.FrameCount = 40000), 'chunked append');
      finally
        LWriter.Free;
      end;
      LSink.Stream.Position := 0;
      SetLength(LActual, LSink.Stream.Size);
      Check(ReadStreamBytes(LSink.Stream, LActual, 0, Length(LActual)) = Length(LActual), 'read sink');
      SameBytes(LExpected, LActual);
    finally
      LSink.Free;
    end;
    {$ifndef pas2js}
    LProbe.Free;
    LProbe := TProbe.Create;
    SaveWavePcm16(IncludeTrailingPathDelimiter(ADirectory) + 'wave-progress-' + IntToStr(AChannels) + '.wav', LClip, LProbe.Observe);
    LFile := TFileStream.Create(IncludeTrailingPathDelimiter(ADirectory) + 'wave-progress-' + IntToStr(AChannels) + '.wav', fmOpenRead);
    try
      SetLength(LActual, LFile.Size);
      Check(ReadStreamBytes(LFile, LActual, 0, Length(LActual)) = Length(LActual), 'read saved file');
      SameBytes(LExpected, LActual);
    finally
      LFile.Free;
    end;
    {$endif}
    for LStage := 0 to 2 do
    begin
      LProbe.Free;
      LProbe := TProbe.Create;
      case LStage of
        0: LProbe.AbortStage := 'validate_wave_samples';
        1: LProbe.AbortStage := 'write_wave_pcm16';
        2: LProbe.AbortStage := 'encode_wave_bytes';
      end;
      LRejected := False;
      if LStage = 2 then
      begin
        try
          LActual := EncodeWavePcm16(LClip, LProbe.Observe);
        except
          on LException: EProbe do
            LRejected := LException = LProbe.RaisedObject;
        end;
      end
      else
      begin
        LSink := TProbeSink.Create;
        try
          LWriter := TWavePcm16Writer.Create(LSink, 8000, AChannels, 40000, LProbe.Observe);
          try
            try
              LWriter.AppendSamples(LSamples);
            except
              on LException: EProbe do
                LRejected := LException = LProbe.RaisedObject;
            end;
            Check(LWriter.Failed, 'observer poisons writer');
            if LStage = 0 then
              Check(LWriter.FrameCount = 0, 'validation has no PCM');
            if LStage = 1 then
              Check(LWriter.FrameCount = 4096 div (AChannels * 2), 'confirmed block retained');
            try
              LWriter.Finish;
              LRejected := False;
            except
              on EAudio do
              begin
              end;
            end;
            try
              LWriter.AppendSamples([]);
              LRejected := False;
            except
              on EAudio do
              begin
              end;
            end;
          finally
            LWriter.Free;
          end;
        finally
          LSink.Free;
        end;
      end;
      Check(LRejected, 'original observer propagated and writer unusable');
    end;
    SameBytes(LExpected, EncodeWavePcm16(LClip));
  finally
    LProbe.Free;
    LClip.Free;
  end;
end;
procedure TestWriterFailures;
var
  LSink: TProbeSink;
  LProbe: TProbe;
  LWriter: TWavePcm16Writer;
  LSamples: TAudioSamples;
  LBad: TAudioSamples;
  LRejected: Boolean;
  LMode: Integer;
begin
  SetLength(LSamples, 10000);
  SetLength(LBad, 1);
  for LMode := 0 to 4 do
  begin
    LSink := TProbeSink.Create;
    LProbe := TProbe.Create;
    try
      if LMode = 4 then
      begin
        LWriter := TWavePcm16Writer.Create(LSink, 8000, 1, 0, LProbe.Observe);
        try
          LWriter.Finish;
          Check(LWriter.Finished and (LSink.Stream.Size = 44), 'zero-frame writer succeeds');
        finally
          LWriter.Free;
        end;
      end
      else if LMode = 0 then
      begin
        LProbe.AbortStage := 'write_wave_pcm16';
        LProbe.AtHeader := True;
        LRejected := False;
        try
          LWriter := TWavePcm16Writer.Create(LSink, 8000, 1, 0, LProbe.Observe);
          LWriter.Free;
        except
          on LException: EProbe do
            LRejected := LException = LProbe.RaisedObject;
        end;
        Check(LRejected and (LSink.Stream.Size = 44), 'zero-frame header abort propagates');
      end
      else
      begin
        LWriter := TWavePcm16Writer.Create(LSink, 8000, 2, 5000, LProbe.Observe);
        try
          if LMode = 1 then
          begin
            LRejected := False;
            try
              LWriter.AppendSamples(LBad);
            except
              on EAudio do
                LRejected := True;
            end;
            Check(LRejected and not LWriter.Failed, 'invalid frame recoverable');
            LWriter.AppendSamples(LSamples);
            LWriter.Finish;
            Check(LWriter.FrameCount = 5000, 'retry after invalid frame');
          end
          else
          begin
            LProbe.Writer := LWriter;
            LProbe.Reenter := LMode = 2;
            LSink.FailNext := LMode = 3;
            LRejected := False;
            try
              LWriter.AppendSamples(LSamples);
            except
              on LException: EProbe do
                LRejected := LException = LSink.RaisedObject;
              on EAudio do
                LRejected := LMode = 2;
            end;
            Check(LRejected and LWriter.Failed, 'sink or reentry abort poisons writer');
            if LMode = 2 then
              Check(LWriter.FrameCount = 1024, 'reentry retains confirmed block')
            else
              Check(LWriter.FrameCount = 0, 'failed sink does not confirm block');
            LRejected := False;
            try
              LWriter.Finish;
            except
              on EAudio do
                LRejected := True;
            end;
            Check(LRejected, 'poisoned finish rejects');
          end;
        finally
          LWriter.Free;
        end;
      end;
    finally
      LProbe.Free;
      LSink.Free;
    end;
  end;
end;

begin
  {$ifndef pas2js}
  Check(ParamCount = 1, 'E output root argument required');
  {$endif}
  TestWriterFailures;
  TestFormat(1, ParamStr(1));
  TestFormat(2, ParamStr(1));
  WriteLn('PASS ', Checks, ' wave progress checks');
end.
