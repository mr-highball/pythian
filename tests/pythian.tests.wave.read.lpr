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
program pythian_tests_wave_read;

{$mode delphi}
{$H+}

uses
  Classes,
  SysUtils,
  Math,
  pythian.audio,
  pythian.wave,
  pythian.wave.read,
  pythian.wave.stream;

type
  ESourceFailure = class(Exception);

  TShortStream = class(TMemoryStream)
  public
    MaximumRead: Integer;
    FailAfter: Integer;
    ReadCalls: Integer;
    Reenter: TWaveFrameReader;
    function Read(var ABuffer; ACount: LongInt): LongInt; override;
  end;

  THeaderSink = class(TAudioByteSink)
  public
    Bytes: TAudioBytes;
    procedure WriteBytes(const ABytes: array of Byte); override;
  end;

  { Virtual large file: actual writer header, zero payload except last frame.
    Never allocates the declared multi-gigabyte extent. }
  TVirtualWave = class(TStream)
  public
    Header: TAudioBytes;
    FileSize: Int64;
    Cursor: Int64;
    BytesRead: Integer;
    function GetSize: Int64; override;
    function Seek(const AOffset: Int64; AOrigin: TSeekOrigin): Int64; override;
    function Read(var ABuffer; ACount: LongInt): LongInt; override;
    function Write(const ABuffer; ACount: LongInt): LongInt; override;
  end;

procedure Check(const AValue: Boolean; const AMessage: String);
begin
  if not AValue then
  begin
    raise Exception.Create(AMessage);
  end;
end;

function TShortStream.Read(var ABuffer; ACount: LongInt): LongInt;
begin
  Inc(ReadCalls);
  if (FailAfter > 0) and (ReadCalls >= FailAfter) then
  begin
    raise ESourceFailure.Create('Deliberate partial source failure');
  end;
  if Reenter <> nil then
  begin
    Reenter.SeekFrame(0);
  end;
  if (MaximumRead > 0) and (ACount > MaximumRead) then
  begin
    ACount := MaximumRead;
  end;
  Result := inherited Read(ABuffer, ACount);
end;

procedure THeaderSink.WriteBytes(const ABytes: array of Byte);
begin
  Check(Length(Bytes) = 0, 'Only a header is expected from large writer fixture');
  SetLength(Bytes, Length(ABytes));
  Move(ABytes[0], Bytes[0], Length(ABytes));
end;

function TVirtualWave.GetSize: Int64;
begin
  Result := FileSize;
end;

function TVirtualWave.Seek(const AOffset: Int64; AOrigin: TSeekOrigin): Int64;
begin
  case AOrigin of
    soBeginning: Cursor := AOffset;
    soCurrent: Cursor := Cursor + AOffset;
    soEnd: Cursor := FileSize + AOffset;
  end;
  Check((Cursor >= 0) and (Cursor <= FileSize), 'Virtual stream seek extent');
  Result := Cursor;
end;

function TVirtualWave.Read(var ABuffer; ACount: LongInt): LongInt;
type
  TBytes = array[0..4095] of Byte;
var
  LPosition: Int64;
  I: Integer;
begin
  Check((ACount >= 0) and (ACount <= 4096), 'Reader uses a bounded byte buffer');
  Result := ACount;
  if Result > FileSize - Cursor then
  begin
    Result := FileSize - Cursor;
  end;
  for I := 0 to Result - 1 do
  begin
    LPosition := Cursor + I;
    TBytes(ABuffer)[I] := 0;
    if LPosition < Length(Header) then
    begin
      TBytes(ABuffer)[I] := Header[LPosition];
    end
    else if LPosition = FileSize - 3 then
    begin
      TBytes(ABuffer)[I] := $40;
    end
    else if LPosition = FileSize - 1 then
    begin
      TBytes(ABuffer)[I] := $C0;
    end;
  end;
  Inc(Cursor, Result);
  Inc(BytesRead, Result);
end;

function TVirtualWave.Write(const ABuffer; ACount: LongInt): LongInt;
begin
  Result := 0;
  raise Exception.Create('Virtual WAVE is read-only');
end;

procedure PutLE(var ABytes: TAudioBytes; const AOffset, AWidth: Integer; AValue: Int64);
var
  I: Integer;
begin
  for I := 0 to AWidth - 1 do
  begin
    ABytes[AOffset + I] := AValue and $FF;
    AValue := AValue shr 8;
  end;
end;

function StreamOf(const ABytes: TAudioBytes): TShortStream;
begin
  Result := TShortStream.Create;
  try
    Result.WriteBuffer(ABytes[0], Length(ABytes));
    Result.Position := 0;
    Result.MaximumRead := 3;
  except
    Result.Free;
    raise;
  end;
end;

procedure CheckBlocks;
var
  LSource: TAudioClip;
  LBytes: TAudioBytes;
  LStream: TShortStream;
  LReader: TWaveFrameReader;
  LSamples: TAudioSamples;
  LBlock: TAudioSamples;
  LOffset: Integer;
  LRejected: Boolean;
  I: Integer;
begin
  LReader := nil;
  LStream := nil;
  SetLength(LSamples, 2800);
  for I := 0 to High(LSamples) do
  begin
    LSamples[I] := ((I mod 101) - 50) / 64;
  end;
  LSource := TAudioClip.Create(44100, 2, LSamples);
  try
    LBytes := EncodeWavePcm16(LSource);
    LStream := StreamOf(LBytes);
    LReader := TWaveFrameReader.Create(LStream);
    LOffset := 0;
    repeat
      LBlock := LReader.ReadFrames(137);
      for I := 0 to High(LBlock) do
      begin
        Check(LBlock[I] = LSamples[LOffset + I], 'Independent PCM16 values survive short/block reads');
      end;
      Inc(LOffset, Length(LBlock));
    until Length(LBlock) = 0;
    Check((LOffset = Length(LSamples)) and (LReader.FramePosition = 1400),
      'Short final block and EOF preserve exact frame count');
    LRejected := False;
    try
      LReader.ReadFrames(0);
    except
      on EAudio do
      begin
        LRejected := True;
      end;
    end;
    Check(LRejected and not LReader.Failed, 'Invalid block request is recoverable');
    LReader.SeekFrame(1399);
    LBlock := LReader.ReadFrames;
    Check((Length(LBlock) = 2) and (LBlock[0] = LSamples[2798]), 'Frame seek and bounded final read');
    LReader.SeekFrame(0);
    LBlock := Copy(LSamples, 0, 2);
    LStream.ReadCalls := 0;
    LStream.FailAfter := 2;
    LRejected := False;
    try
      LBlock := LReader.ReadFrames(20);
    except
      on ESourceFailure do
      begin
        LRejected := True;
      end;
    end;
    Check(LRejected and LReader.Failed and (LReader.FramePosition = 0) and
      (Length(LBlock) = 2) and (LBlock[0] = LSamples[0]),
      'Partial source failure retains exception, prior result and confirmed frame position');
    FreeAndNil(LReader);
    LStream.FailAfter := 0;
    LStream.Position := 0;
    LReader := TWaveFrameReader.Create(LStream);
    LStream.Reenter := LReader;
    LRejected := False;
    try
      LBlock := LReader.ReadFrames(1);
    except
      on EAudio do
      begin
        LRejected := True;
      end;
    end;
    Check(LRejected and LReader.Failed and (LReader.FramePosition = 0),
      'Source callbacks cannot reenter the reader');
    LStream.Reenter := nil;
  finally
    LReader.Free;
    LStream.Free;
    LSource.Free;
  end;
end;

procedure CheckLargeRF64;
const
  CFrames: Int64 = 2147483651;
var
  LSink: THeaderSink;
  LWriter: TWavePcm16Writer;
  LStream: TVirtualWave;
  LReader: TWaveFrameReader;
  LBlock: TAudioSamples;
begin
  LSink := THeaderSink.Create;
  LWriter := nil;
  LStream := nil;
  LReader := nil;
  try
    LWriter := TWavePcm16Writer.Create(LSink, 48000, 2, CFrames);
    Check(LWriter.IsRF64, 'Actual writer must choose RF64');
    LStream := TVirtualWave.Create;
    LStream.Header := Copy(LSink.Bytes);
    LStream.FileSize := 80 + CFrames * 4;
    LReader := TWaveFrameReader.Create(LStream);
    Check(LReader.IsRF64 and (LReader.FrameCount = CFrames) and (LStream.BytesRead = 80),
      'RF64 scan reads structural fields without reading a large payload');
    LReader.SeekFrame(CFrames - 1);
    LBlock := LReader.ReadFrames(8);
    Check((Length(LBlock) = 2) and (LBlock[0] = 0.5) and (LBlock[1] = -0.5) and
      (LReader.FramePosition = CFrames), '64-bit seek addresses final stereo frame beyond 4 GB');
    Check(LStream.BytesRead = 84, 'Large-file check uses bounded reads only');
  finally
    LReader.Free;
    LStream.Free;
    LWriter.Free;
    LSink.Free;
  end;
end;

procedure CheckRF64Table;
var
  LSource: TAudioClip;
  LDecoded: TAudioClip;
  LRiff: TAudioBytes;
  LRf64: TAudioBytes;
  LBad: TAudioBytes;
  LRejected: Boolean;
  I: Integer;
begin
  LSource := TAudioClip.Create(8000, 1, [0, 0.5, -0.5, 0.25]);
  LDecoded := nil;
  try
    LRiff := EncodeWavePcm16(LSource);
    SetLength(LRf64, Length(LRiff) + 60);
    Move(LRiff[0], LRf64[0], 12);
    PutLE(LRf64, 0, 4, $34364652);
    PutLE(LRf64, 4, 4, $FFFFFFFF);
    PutLE(LRf64, 12, 4, $34367364);
    PutLE(LRf64, 16, 4, 40);
    PutLE(LRf64, 20, 8, Length(LRf64) - 8);
    PutLE(LRf64, 28, 8, 8);
    PutLE(LRf64, 36, 8, 4);
    PutLE(LRf64, 44, 4, 1);
    PutLE(LRf64, 48, 4, $4B4E554A);
    PutLE(LRf64, 52, 8, 3);
    PutLE(LRf64, 60, 4, $4B4E554A);
    PutLE(LRf64, 64, 4, $FFFFFFFF);
    LRf64[68] := 1;
    LRf64[69] := 2;
    LRf64[70] := 3;
    Move(LRiff[12], LRf64[72], Length(LRiff) - 12);
    PutLE(LRf64, 100, 4, $FFFFFFFF);
    LDecoded := DecodeWave(LRf64);
    for I := 0 to 3 do
    begin
      Check(LDecoded.SampleAt(I, 0) = LSource.SampleAt(I, 0),
        'RF64 size table and odd unknown chunk preserve all samples');
    end;
    FreeAndNil(LDecoded);
    { Non-sentinel 32-bit fields take precedence over ds64 replacement sizes. }
    LBad := Copy(LRf64);
    PutLE(LBad, 4, 4, Length(LBad) - 8);
    PutLE(LBad, 100, 4, 8);
    FillChar(LBad[28], 8, $FF);
    LDecoded := DecodeWave(LBad);
    Check(LDecoded.FrameCount = 4, 'RF64 normal 32-bit size fields remain authoritative');
    FreeAndNil(LDecoded);
    for I := 0 to 2 do
    begin
      LBad := Copy(LRf64);
      case I of
        0: PutLE(LBad, 48, 4, $44434241);
        1: PutLE(LBad, 36, 8, 5);
        2: PutLE(LBad, 44, 4, 4097);
      end;
      LRejected := False;
      try
        LDecoded := DecodeWave(LBad);
      except
        on EAudio do
        begin
          LRejected := True;
        end;
      end;
      Check(LRejected and (LDecoded = nil),
        'RF64 missing table entry, sample-count disagreement or oversized table rejects');
    end;
  finally
    LDecoded.Free;
    LSource.Free;
  end;
end;

function ExtensibleWave(const ABits, AValidBits, AEncoding, AChannels: Integer;
  const AWords: array of Int64): TAudioBytes;
var
  LSize: Integer;
  I: Integer;
begin
  Result := nil;
  LSize := Length(AWords) * (ABits div 8);
  SetLength(Result, 68 + LSize + (LSize mod 2));
  PutLE(Result, 0, 4, $46464952);
  PutLE(Result, 4, 4, Length(Result) - 8);
  PutLE(Result, 8, 4, $45564157);
  PutLE(Result, 12, 4, $20746D66);
  PutLE(Result, 16, 4, 40);
  PutLE(Result, 20, 2, $FFFE);
  PutLE(Result, 22, 2, AChannels);
  PutLE(Result, 24, 4, 8000);
  PutLE(Result, 28, 4, 8000 * AChannels * (ABits div 8));
  PutLE(Result, 32, 2, AChannels * (ABits div 8));
  PutLE(Result, 34, 2, ABits);
  PutLE(Result, 36, 2, 22);
  PutLE(Result, 38, 2, AValidBits);
  if AChannels = 1 then
  begin
    PutLE(Result, 40, 4, 4);
  end
  else
  begin
    PutLE(Result, 40, 4, 3);
  end;
  PutLE(Result, 44, 4, AEncoding);
  PutLE(Result, 48, 4, $00100000);
  PutLE(Result, 52, 4, $AA000080);
  PutLE(Result, 56, 4, $719B3800);
  PutLE(Result, 60, 4, $61746164);
  PutLE(Result, 64, 4, LSize);
  for I := 0 to High(AWords) do
  begin
    PutLE(Result, 68 + I * (ABits div 8), ABits div 8, AWords[I]);
  end;
end;

procedure ExpectSamples(const ABytes: TAudioBytes; const ABits, AValidBits,
  AEncoding, AChannels: Integer; const ASamples: array of Single);
var
  LStream: TShortStream;
  LReader: TWaveFrameReader;
  LClip: TAudioClip;
  LBlock: TAudioSamples;
  I: Integer;
  J: Integer;
begin
  LStream := StreamOf(ABytes);
  LReader := nil;
  LClip := nil;
  try
    LReader := TWaveFrameReader.Create(LStream);
    Check((LReader.FormatTag = $FFFE) and (LReader.EncodingTag = AEncoding) and
      (LReader.BitsPerSample = ABits) and (LReader.ValidBitsPerSample = AValidBits) and
      (LReader.Channels = AChannels) and
      (LReader.FrameCount = Length(ASamples) div AChannels), 'Extensible format metadata');
    LClip := DecodeWave(ABytes);
    for I := 0 to LClip.FrameCount - 1 do
    begin
      LBlock := LReader.ReadFrames(1);
      for J := 0 to AChannels - 1 do
      begin
        Check((LBlock[J] = ASamples[I * AChannels + J]) and
          (LClip.SampleAt(I, J) = ASamples[I * AChannels + J]),
          'Extensible PCM/float scales and preserves channel order');
      end;
    end;
    LReader.SeekFrame(LReader.FrameCount - 1);
    LBlock := LReader.ReadFrames(7);
    Check((Length(LBlock) = AChannels) and
      (LBlock[0] = ASamples[Length(ASamples) - AChannels]), 'Extensible final-frame seek');
  finally
    LClip.Free;
    LReader.Free;
    LStream.Free;
  end;
end;

procedure CheckExtensible;
var
  LBytes: TAudioBytes;
  LBad: TAudioBytes;
  LAlternate: TAudioBytes;
  LStream: TShortStream;
  LReader: TWaveFrameReader;
  LClip: TAudioClip;
  LBlock: TAudioSamples;
  LRejected: Boolean;
  I: Integer;
begin
  ExpectSamples(ExtensibleWave(8, 4, 1, 1, [$00, $80, $F0]),
    8, 4, 1, 1, [-1, 0, 0.875]);
  ExpectSamples(ExtensibleWave(16, 12, 1, 1, [$8000, $FFF0, $7FF0]),
    16, 12, 1, 1, [-1, -1 / 2048, 2047 / 2048]);
  ExpectSamples(ExtensibleWave(24, 20, 1, 2, [$800000, $7FFFF0, $FFFFF0, $400000]),
    24, 20, 1, 2, [-1, 524287 / 524288, -1 / 524288, 0.5]);
  ExpectSamples(ExtensibleWave(32, 24, 1, 2, [$80000000, $7FFFFF00, $FFFFFF00, $40000000]),
    32, 24, 1, 2, [-1, 8388607 / 8388608, -1 / 8388608, 0.5]);
  ExpectSamples(ExtensibleWave(32, 32, 1, 1, [$80000000, $40000000]),
    32, 32, 1, 1, [-1, 0.5]);
  ExpectSamples(ExtensibleWave(32, 32, 3, 2, [$3FC00000, $C0000000, 0, $BF000000]),
    32, 32, 3, 2, [1.5, -2, 0, -0.5]);
  LBytes := ExtensibleWave(16, 16, 1, 1, [$4000, $C000]);
  PutLE(LBytes, 40, 4, 0);
  ExpectSamples(LBytes, 16, 16, 1, 1, [0.5, -0.5]);
  { A real RF64 header around the same extensible format and payload. }
  SetLength(LAlternate, Length(LBytes) + 36);
  Move(LBytes[0], LAlternate[0], 12);
  Move(LBytes[12], LAlternate[48], Length(LBytes) - 12);
  PutLE(LAlternate, 0, 4, $34364652);
  PutLE(LAlternate, 4, 4, $FFFFFFFF);
  PutLE(LAlternate, 12, 4, $34367364);
  PutLE(LAlternate, 16, 4, 28);
  PutLE(LAlternate, 20, 8, Length(LAlternate) - 8);
  PutLE(LAlternate, 28, 8, 4);
  PutLE(LAlternate, 36, 8, 2);
  PutLE(LAlternate, 100, 4, $FFFFFFFF);
  ExpectSamples(LAlternate, 16, 16, 1, 1, [0.5, -0.5]);
  { Data before format remains supported; neither parse order owns decoding. }
  LAlternate := Copy(LBytes);
  Move(LBytes[60], LAlternate[12], 12);
  Move(LBytes[12], LAlternate[24], 48);
  ExpectSamples(LAlternate, 16, 16, 1, 1, [0.5, -0.5]);
  for I := 0 to 12 do
  begin
    LBad := Copy(LBytes);
    case I of
      0: PutLE(LBad, 36, 2, 21);
      1: PutLE(LBad, 36, 2, 23);
      2: PutLE(LBad, 38, 2, 0);
      3: PutLE(LBad, 38, 2, 17);
      4: PutLE(LBad, 40, 4, 8);
      5: PutLE(LBad, 44, 4, $10001);
      6: PutLE(LBad, 48, 4, 0);
      7: PutLE(LBad, 52, 4, 0);
      8: PutLE(LBad, 56, 4, 0);
      9: PutLE(LBad, 16, 4, 18);
      10: PutLE(LBad, 44, 4, 3);
      11: LBad := ExtensibleWave(32, 24, 3, 1, [0]);
      12: LBad := ExtensibleWave(16, 16, 1, 3, [0, 0, 0]);
    end;
    LRejected := False;
    LClip := nil;
    try
      try
        LClip := DecodeWave(LBad);
      except
        on EAudio do
        begin
          LRejected := True;
        end;
      end;
      Check(LRejected and (LClip = nil), 'Invalid extensible format must reject');
    finally
      LClip.Free;
    end;
  end;
  for I := 0 to 2 do
  begin
    case I of
      0: LBad := ExtensibleWave(24, 20, 1, 1, [0, 1]);
      1: LBad := ExtensibleWave(32, 32, 3, 1, [0, $7F800000]);
      2: LBad := ExtensibleWave(32, 32, 3, 1, [0, $7FC00001]);
    end;
    LStream := StreamOf(LBad);
    LReader := nil;
    try
      LReader := TWaveFrameReader.Create(LStream);
      LBlock := LReader.ReadFrames(1);
      LRejected := False;
      try
        LBlock := LReader.ReadFrames(1);
      except
        on EAudio do
        begin
          LRejected := True;
        end;
      end;
      Check(LRejected and LReader.Failed and (LReader.FramePosition = 1) and
        (Length(LBlock) = 1) and (LBlock[0] = 0),
        'Invalid padding/float preserves published samples and poisons the reader');
    finally
      LReader.Free;
      LStream.Free;
    end;
  end;
end;

procedure WriteExtensibleFixtures(const AInput, APrefix: String);
var
  LSource: TAudioClip;
  LStream: TFileStream;
  LWords: array of Int64;
  LBytes: TAudioBytes;
  LSample: Single;
  LFloatBits: Cardinal;
  LBits: Integer;
  LEncoding: Integer;
  LVariant: Integer;
  I: Integer;
begin
  LSource := LoadWave(AInput);
  try
    SetLength(LWords, LSource.FrameCount * LSource.Channels);
    for LVariant := 0 to 3 do
    begin
      LBits := 16 + Min(LVariant, 2) * 8;
      LEncoding := 1;
      for I := 0 to High(LWords) do
      begin
        LSample := LSource.SampleAt(I div LSource.Channels, I mod LSource.Channels);
        if LVariant = 3 then
        begin
          LEncoding := 3;
          Move(LSample, LFloatBits, SizeOf(LFloatBits));
          LWords[I] := LFloatBits;
        end
        else
        begin
          Check(LSample * 32768 = Round(LSample * 32768), 'Fixture source must be PCM16 exact');
          LWords[I] := (Round(LSample * 32768) and $FFFF) shl (LBits - 16);
        end;
      end;
      if LVariant = 3 then
      begin
        LBytes := ExtensibleWave(LBits, LBits, LEncoding, LSource.Channels, LWords);
      end
      else
      begin
        LBytes := ExtensibleWave(LBits, 16, LEncoding, LSource.Channels, LWords);
      end;
      PutLE(LBytes, 24, 4, LSource.SampleRate);
      PutLE(LBytes, 28, 4, LSource.SampleRate * LSource.Channels * (LBits div 8));
      LStream := TFileStream.Create(APrefix + '-' + IntToStr(LVariant) + '.wav', fmCreate);
      try
        LStream.WriteBuffer(LBytes[0], Length(LBytes));
      finally
        LStream.Free;
      end;
    end;
  finally
    LSource.Free;
  end;
end;

procedure CheckFloatFailure;
var
  LSource: TAudioClip;
  LBytes: TAudioBytes;
  LStream: TShortStream;
  LReader: TWaveFrameReader;
  LBlock: TAudioSamples;
  LRejected: Boolean;
begin
  LSource := TAudioClip.Create(8000, 1, [0, 0, 0, 0]);
  LStream := nil;
  LReader := nil;
  try
    LBytes := EncodeWavePcm16(LSource);
    { Four PCM16 zeros become two float32 words without changing data bytes. }
    PutLE(LBytes, 20, 2, 3);
    PutLE(LBytes, 28, 4, 32000);
    PutLE(LBytes, 32, 2, 4);
    PutLE(LBytes, 34, 2, 32);
    PutLE(LBytes, 48, 4, $7F800000);
    LStream := StreamOf(LBytes);
    LReader := TWaveFrameReader.Create(LStream);
    LBlock := LReader.ReadFrames(1);
    Check((Length(LBlock) = 1) and (LBlock[0] = 0), 'Float validation is deferred until requested samples');
    LRejected := False;
    try
      LBlock := LReader.ReadFrames(1);
    except
      on EAudio do
      begin
        LRejected := True;
      end;
    end;
    Check(LRejected and LReader.Failed and (LReader.FramePosition = 1) and
      (Length(LBlock) = 1) and (LBlock[0] = 0), 'Nonfinite float does not publish a partial block');
  finally
    LReader.Free;
    LStream.Free;
    LSource.Free;
  end;
end;

begin
  try
    CheckBlocks;
    CheckLargeRF64;
    CheckRF64Table;
    CheckFloatFailure;
    CheckExtensible;
    if ParamCount = 2 then
    begin
      WriteExtensibleFixtures(ParamStr(1), ParamStr(2));
    end
    else if ParamCount <> 0 then
    begin
      raise EAudio.Create('Optional usage: pythian.tests.wave.read INPUT_PCM16.wav OUTPUT_PREFIX');
    end;
    WriteLn('Bounded WAVE/RF64 reads, extensible PCM/float, seeks and deferred failure checks passed');
  except
    on LException: Exception do
    begin
      WriteLn(StdErr, LException.ClassName, ': ', LException.Message);
      Halt(1);
    end;
  end;
end.
