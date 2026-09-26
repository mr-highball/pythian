(*
MIT License

Copyright (c) 2021 mr-highball
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
program pythian_tests_wave_stream;

{$mode delphi}
{$H+}

uses
  SysUtils,
  pythian.audio,
  pythian.wave,
  pythian.wave.stream;

type
  ESinkFailure = class(Exception);

  TRecordingSink = class(TAudioByteSink)
  public
    Bytes: TAudioBytes;
    Calls: Integer;
    MaximumBlock: Integer;
    FailOnCall: Integer;
    Reenter: TWavePcm16Writer;
    procedure WriteBytes(const ABytes: array of Byte); override;
  end;

procedure Check(const ACondition: Boolean; const AMessage: String);
begin
  if not ACondition then
  begin
    raise Exception.Create(AMessage);
  end;
end;

procedure TRecordingSink.WriteBytes(const ABytes: array of Byte);
var
  LOffset: Integer;
  LCount: Integer;
begin
  Inc(Calls);
  if Length(ABytes) > MaximumBlock then
  begin
    MaximumBlock := Length(ABytes);
  end;
  LCount := Length(ABytes);
  if (Calls = FailOnCall) and (LCount > 0) then
  begin
    LCount := 1;
  end;
  LOffset := Length(Bytes);
  SetLength(Bytes, LOffset + LCount);
  if LCount > 0 then
  begin
    Move(ABytes[0], Bytes[LOffset], LCount);
  end;
  if Reenter <> nil then
  begin
    Reenter.Finish;
  end;
  if Calls = FailOnCall then
  begin
    raise ESinkFailure.Create('intentional partial sink failure');
  end;
end;

function ReadUnsigned(const ABytes: TAudioBytes; const AOffset, ACount: Integer): Int64;
var
  LIndex: Integer;
begin
  Result := 0;
  for LIndex := ACount - 1 downto 0 do
  begin
    Result := Result * 256 + ABytes[AOffset + LIndex];
  end;
end;

procedure CheckStreaming;
var
  LSink: TRecordingSink;
  LWriter: TWavePcm16Writer;
  LClip: TAudioClip;
  LRejected: Boolean;
  LCalls: Integer;
  LSamples: TAudioSamples;
begin
  LSink := TRecordingSink.Create;
  try
    LWriter := TWavePcm16Writer.Create(LSink, 44100, 2, 2);
    try
      LCalls := LSink.Calls;
      LRejected := False;
      try
        LWriter.AppendSamples([0, 0, 0]);
      except
        on EAudio do
        begin
          LRejected := True;
        end;
      end;
      Check(LRejected and (LSink.Calls = LCalls) and not LWriter.Failed,
        'Partial input frame rejected without writing or poisoning');
      LRejected := False;
      try
        LWriter.Finish;
      except
        on EAudio do
        begin
          LRejected := True;
        end;
      end;
      Check(LRejected and not LWriter.Finished and not LWriter.Failed,
        'Short Finish remains recoverable');
      LWriter.AppendSamples([-1, 0.5]);
      LWriter.AppendSamples([0, 32767 / 32768]);
      LWriter.Finish;
      LCalls := LSink.Calls;
      LWriter.Finish;
      Check(LWriter.Finished and (LWriter.FrameCount = 2) and (LSink.Calls = LCalls),
        'Exact count and idempotent Finish');
      LClip := DecodeWave(LSink.Bytes);
      try
        Check((LClip.Channels = 2) and (LClip.FrameCount = 2), 'Streamed stereo layout');
        Check((LClip.SampleAt(0, 0) = -1) and (LClip.SampleAt(0, 1) = 0.5),
          'Interleaved channel order');
      finally
        LClip.Free;
      end;
    finally
      LWriter.Free;
    end;
    Check(Length(LSink.Bytes) = 52, 'Borrowed sink remains usable after writer release');
  finally
    LSink.Free;
  end;

  LSink := TRecordingSink.Create;
  try
    LWriter := TWavePcm16Writer.Create(LSink, 44100, 2, 2500);
    try
      SetLength(LSamples, 5000);
      LSink.FailOnCall := 3;
      LRejected := False;
      try
        LWriter.AppendSamples(LSamples);
      except
        on ESinkFailure do
        begin
          LRejected := True;
        end;
      end;
      Check(LRejected and LWriter.Failed, 'Original sink exception retained');
      Check((LWriter.FrameCount = 1024) and (Length(LSink.Bytes) = 44 + 4096 + 1),
        'Confirmed frame count excludes physically partial block');
      Check(LSink.MaximumBlock = WaveStreamBlockBytes, 'Streaming buffer stays bounded');
      LCalls := LSink.Calls;
      LRejected := False;
      try
        LWriter.AppendSamples([0, 0]);
      except
        on EAudio do
        begin
          LRejected := True;
        end;
      end;
      Check(LRejected and (LSink.Calls = LCalls), 'Failed writer forbids subsequent writes');
    finally
      LWriter.Free;
    end;
  finally
    LSink.Free;
  end;

  LSink := TRecordingSink.Create;
  try
    LWriter := TWavePcm16Writer.Create(LSink, 44100, 1, 1);
    try
      LSink.Reenter := LWriter;
      LRejected := False;
      try
        LWriter.AppendSamples([0]);
      except
        on EAudio do
        begin
          LRejected := True;
        end;
      end;
      Check(LRejected and LWriter.Failed and (LWriter.FrameCount = 0),
        'Reentrant sink fails without confirming a block');
    finally
      LWriter.Free;
    end;
  finally
    LSink.Free;
  end;
  WriteLn('PASS streaming stereo, recoverable input errors, partial writes, reentrancy and ownership');
end;

procedure CheckLargeHeaders;
const
  CLastRiffFrames: Int64 = (4294967295 - 36) div 4;
var
  LSink: TRecordingSink;
  LWriter: TWavePcm16Writer;
begin
  LSink := TRecordingSink.Create;
  try
    LWriter := TWavePcm16Writer.Create(LSink, 48000, 2, CLastRiffFrames);
    try
      Check(not LWriter.IsRF64 and (Length(LSink.Bytes) = 44), 'Last stereo RIFF extent');
      Check(ReadUnsigned(LSink.Bytes, 4, 4) = CLastRiffFrames * 4 + 36,
        'Unsigned RIFF size near 32-bit boundary');
    finally
      LWriter.Free;
    end;
  finally
    LSink.Free;
  end;
  LSink := TRecordingSink.Create;
  try
    LWriter := TWavePcm16Writer.Create(LSink, 48000, 2, CLastRiffFrames + 1);
    try
      Check(LWriter.IsRF64 and (Length(LSink.Bytes) = 80), 'First RF64 stereo extent');
      Check((LSink.Bytes[0] = Ord('R')) and (LSink.Bytes[3] = Ord('4')),
        'RF64 identifier');
      Check(ReadUnsigned(LSink.Bytes, 4, 4) = 4294967295, 'RIFF size sentinel');
      Check(ReadUnsigned(LSink.Bytes, 20, 8) = (CLastRiffFrames + 1) * 4 + 72,
        'ds64 RIFF size');
      Check(ReadUnsigned(LSink.Bytes, 28, 8) = (CLastRiffFrames + 1) * 4,
        'ds64 PCM byte size');
      Check(ReadUnsigned(LSink.Bytes, 36, 8) = CLastRiffFrames + 1, 'ds64 frame count');
      Check(ReadUnsigned(LSink.Bytes, 76, 4) = 4294967295, 'data size sentinel');
    finally
      LWriter.Free;
    end;
  finally
    LSink.Free;
  end;
  WriteLn('PASS RIFF/RF64 boundary headers without allocating or writing multi-gigabyte audio');
end;

begin
  try
    CheckStreaming;
    CheckLargeHeaders;
  except
    on LException: Exception do
    begin
      WriteLn(StdErr, LException.ClassName, ': ', LException.Message);
      Halt(1);
    end;
  end;
end.
