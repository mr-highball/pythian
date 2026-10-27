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
program pythian_tests_wave_reader_portable;
{$mode delphi}{$H+}

uses
  Classes,
  SysUtils,
  Math,
  pythian.audio,
  pythian.stream.bytes,
  pythian.wave.stream,
  pythian.wave.read;

type
  TShortStream = class(TMemoryStream)
  public
    Fail: Boolean;
    {$ifdef pas2js}
    function Read(ABuffer: TBytes; AOffset, ACount: LongInt): LongInt; override;
    {$else}
    function Read(var ABuffer; ACount: LongInt): LongInt; override;
    {$endif}
  end;

var
  GChecks: Integer;

{$ifdef pas2js}
function TShortStream.Read(ABuffer: TBytes; AOffset, ACount: LongInt): LongInt;
{$else}
function TShortStream.Read(var ABuffer; ACount: LongInt): LongInt;
{$endif}
begin
  if Fail then
  begin
    raise EAudio.Create('fixture read failure');
  end;
  ACount := Min(ACount, 3);
  {$ifdef pas2js}
  Result := inherited Read(ABuffer, AOffset, ACount);
  {$else}
  Result := inherited Read(ABuffer, ACount);
  {$endif}
end;

procedure Check(const ACondition: Boolean; const AMessage: String);
begin
  if not ACondition then
  begin
    raise Exception.Create(AMessage);
  end;
  Inc(GChecks);
end;

procedure Put(var ABytes: TAudioBytes; const AOffset, ACount: Integer; AValue: Int64);
var
  LIndex: Integer;
begin
  for LIndex := 0 to ACount - 1 do
  begin
    ABytes[AOffset + LIndex] := AValue mod 256;
    AValue := AValue div 256;
  end;
end;

function MakeWave(const ABits, ATag: Integer; const AExtensible: Boolean;
  const AWords: array of Int64): TAudioBytes;
var
  LFormat: Integer;
  LData: Integer;
  LIndex: Integer;
  LWidth: Integer;
  LGuid: Integer;
  LBase: TAudioBytes;
begin
  LBase := WavePcm16Header(8000, 1, 0);
  LWidth := ABits div 8;
  LFormat := 16;
  if AExtensible then
  begin
    LFormat := 40;
  end;
  LData := 20 + LFormat;
  SetLength(Result, LData + 8 + Length(AWords) * LWidth +
    (Length(AWords) * LWidth) mod 2);
  for LIndex := 0 to 19 do
  begin
    Result[LIndex] := LBase[LIndex];
  end;
  Put(Result, 4, 4, Length(Result) - 8);
  Put(Result, 16, 4, LFormat);
  if AExtensible then
  begin
    Put(Result, 20, 2, $FFFE);
  end
  else
  begin
    Put(Result, 20, 2, ATag);
  end;
  Put(Result, 22, 2, 1);
  Put(Result, 24, 4, 8000);
  Put(Result, 28, 4, 8000 * LWidth);
  Put(Result, 32, 2, LWidth);
  Put(Result, 34, 2, ABits);
  if AExtensible then
  begin
    Put(Result, 36, 2, 22);
    Put(Result, 38, 2, ABits);
    Put(Result, 40, 4, 4);
    LGuid := 44;
    Put(Result, LGuid, 4, ATag);
    Put(Result, LGuid + 4, 4, $00100000);
    Put(Result, LGuid + 8, 4, Int64(2852126848));
    Put(Result, LGuid + 12, 4, $719B3800);
  end;
  for LIndex := 0 to 3 do
  begin
    Result[LData + LIndex] := LBase[36 + LIndex];
  end;
  Put(Result, LData + 4, 4, Length(AWords) * LWidth);
  for LIndex := 0 to High(AWords) do
  begin
    Put(Result, LData + 8 + LIndex * LWidth, LWidth, AWords[LIndex]);
  end;
end;

procedure CheckFormat(const ABits, ATag: Integer; const AExtensible: Boolean;
  const AWords: array of Int64; const AExpected: array of Double);
var
  LBytes: TAudioBytes;
  LStream: TMemoryStream;
  LReader: TWaveFrameReader;
  LSamples: TAudioSamples;
  LIndex: Integer;
  LRejected: Boolean;
begin
  LBytes := MakeWave(ABits, ATag, AExtensible, AWords);
  LStream := TMemoryStream.Create;
  try
    Check(WriteStreamBytes(LStream, LBytes, 0, Length(LBytes)) = Length(LBytes), 'fixture write');
    LStream.Position := 0;
    LReader := TWaveFrameReader.Create(LStream);
    try
      Check((LReader.FrameCount = Length(AWords)) and
        (LReader.BitsPerSample = ABits) and (LReader.EncodingTag = ATag), 'format geometry');
      LSamples := LReader.ReadFrames(2);
      Check(Length(LSamples) = 2, 'first read');
      for LIndex := 0 to 1 do
      begin
        Check(Abs(LSamples[LIndex] - AExpected[LIndex]) < 1E-7, 'sample values');
      end;
      LReader.SeekFrame(1);
      LSamples := LReader.ReadFrames(10);
      Check((Length(LSamples) = 2) and (Abs(LSamples[1] - AExpected[2]) < 1E-7), 'seek and tail');
      Check(Length(LReader.ReadFrames(1)) = 0, 'EOF');
      LRejected := False;
      try
        LReader.SeekFrame(-1);
      except
        on LException: EAudio do
        begin
          LRejected := True;
        end;
      end;
      Check(LRejected and not LReader.Failed, 'argument preserves reader');
    finally
      LReader.Free;
    end;
  finally
    LStream.Free;
  end;
end;

var
  LStream: TMemoryStream;
  LSink: TStreamAudioSink;
  LWriter: TWavePcm16Writer;
  LReader: TWaveFrameReader;
  LSamples: TAudioSamples;
  LBytes: TAudioBytes;
  LRejected: Boolean;
  LShort: TShortStream;
begin
  CheckFormat(16, 1, False, [32768, 0, 16384], [-1, 0, 0.5]);
  CheckFormat(24, 1, False, [8388608, 0, 4194304], [-1, 0, 0.5]);
  CheckFormat(32, 1, False, [2147483648, 0, 1073741824], [-1, 0, 0.5]);
  CheckFormat(32, 3, False, [3212836864, 0, 1056964608], [-1, 0, 0.5]);
  CheckFormat(24, 1, True, [8388608, 0, 4194304], [-1, 0, 0.5]);
  CheckFormat(32, 3, True, [3212836864, 0, 1056964608], [-1, 0, 0.5]);
  LBytes := WavePcm16Header(8000, 1, 2147483648);
  SetLength(LBytes, 86);
  Put(LBytes, 20, 8, 78);
  Put(LBytes, 28, 8, 6);
  Put(LBytes, 36, 8, 3);
  Put(LBytes, 80, 2, 32768);
  Put(LBytes, 82, 2, 0);
  Put(LBytes, 84, 2, 16384);
  LShort := TShortStream.Create;
  try
    Check(WriteStreamBytes(LShort, LBytes, 0, Length(LBytes)) = Length(LBytes), 'RF64 setup');
    LShort.Position := 0;
    LReader := TWaveFrameReader.Create(LShort);
    try
      Check(LReader.IsRF64 and (LReader.FrameCount = 3), 'RF64 with short reads');
      LSamples := LReader.ReadFrames(3);
      Check((LSamples[0] = -1) and (LSamples[2] = 0.5), 'RF64 samples');
      LShort.Fail := True;
      LRejected := False;
      try
        LReader.SeekFrame(0);
        LReader.ReadFrames(1);
      except
        on LException: EAudio do
        begin
          LRejected := True;
        end;
      end;
      Check(LRejected and LReader.Failed and (LReader.FramePosition = 0), 'I/O failure poisons');
    finally
      LReader.Free;
    end;
  finally
    LShort.Free;
  end;
  LBytes := MakeWave(32, 3, False, [0, 2139095040, 0]);
  LStream := TMemoryStream.Create;
  try
    Check(WriteStreamBytes(LStream, LBytes, 0, Length(LBytes)) = Length(LBytes), 'bad float setup');
    LStream.Position := 0;
    LReader := TWaveFrameReader.Create(LStream);
    try
      LRejected := False;
      try
        LReader.ReadFrames(3);
      except
        on LException: EAudio do
        begin
          LRejected := True;
        end;
      end;
      Check(LRejected and LReader.Failed and (LReader.FramePosition = 0), 'invalid sample poisons reader');
    finally
      LReader.Free;
    end;
  finally
    LStream.Free;
  end;
  LStream := TMemoryStream.Create;
  try
    LSink := TStreamAudioSink.Create(LStream);
    try
      LWriter := TWavePcm16Writer.Create(LSink, 8000, 1, 3);
      try
        LWriter.AppendSamples([-1, 0, 0.5]);
        LWriter.Finish;
      finally
        LWriter.Free;
      end;
    finally
      LSink.Free;
    end;
    LStream.Position := 0;
    LReader := TWaveFrameReader.Create(LStream);
    try
      LSamples := LReader.ReadFrames(3);
      Check((Length(LSamples) = 3) and (LSamples[0] = -1) and
        (LSamples[1] = 0) and (LSamples[2] = 0.5), 'writer reader roundtrip');
    finally
      LReader.Free;
    end;
  finally
    LStream.Free;
  end;
  WriteLn('Portable WAVE: ', GChecks, ' checks passed');
end.
