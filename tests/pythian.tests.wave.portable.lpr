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
program pythian_tests_wave_portable;

{$mode delphi}
{$H+}

uses SysUtils, Math, Classes, pythian.audio, pythian.wave.stream;

type
  TByteCollector = class(TAudioByteSink)
    Bytes: TAudioBytes;
    procedure WriteBytes(const ABytes: array of Byte); override;
  end;

procedure TByteCollector.WriteBytes(const ABytes: array of Byte);
var I, LStart: Integer;
begin
  LStart := Length(Bytes);
  SetLength(Bytes, LStart + Length(ABytes));
  for I := 0 to High(ABytes) do Bytes[LStart + I] := ABytes[I];
end;

procedure Check(const AValue: Boolean; const AMessage: String);
begin
  if not AValue then raise Exception.Create(AMessage);
end;

function Hex(const ABytes: array of Byte): String;
var I: Integer;
begin
  Result := '';
  for I := 0 to High(ABytes) do Result := Result + IntToHex(ABytes[I], 2);
end;

var
  LSink: TByteCollector;
  LWriter: TWavePcm16Writer;
  LStream: TMemoryStream;
  LStreamSink: TStreamAudioSink;
  LSamples: TAudioSamples;
  LHeader, LBytes: TAudioBytes;
  LFailed: Boolean;
  I: Integer;
begin
  LSamples := [-2, -1, -0.5, -1 / 65536, 0, 1 / 65536, 0.5, 1, 2];
  LHeader := WavePcm16Header(44100, 1, Length(LSamples));
  Check(Hex(LHeader) = '524946463600000057415645666D7420100000000100010044AC000088580100020010006461746112000000',
    'Canonical nine-frame mono PCM header');
  LSink := TByteCollector.Create;
  try
    LWriter := TWavePcm16Writer.Create(LSink, 44100, 1, Length(LSamples));
    try
      LWriter.AppendSamples(LSamples);
      LWriter.Finish;
    finally LWriter.Free end;
    Check(Hex(Copy(LSink.Bytes, RiffHeaderBytes, 18)) =
      '0080008000C0FFFF000001000040FF7FFF7F', 'PCM clipping and half-away quantization');
    for I := 0 to High(LSamples) do
      Check(SmallInt(LSink.Bytes[RiffHeaderBytes + I * 2] or
        (Word(LSink.Bytes[RiffHeaderBytes + I * 2 + 1]) shl 8)) = QuantizePcm16(LSamples[I]),
        'Capture quantizer and primary writer agree');
    LStream := TMemoryStream.Create;
    try
      LStreamSink := TStreamAudioSink.Create(LStream);
      try
        LWriter := TWavePcm16Writer.Create(LStreamSink, 44100, 1, Length(LSamples));
        try LWriter.AppendSamples(LSamples); LWriter.Finish finally LWriter.Free end;
      finally LStreamSink.Free end;
      SetLength(LBytes, LStream.Size);
      LStream.Position := 0;
      {$IFDEF PAS2JS}
      LStream.ReadBuffer(LBytes, Length(LBytes));
      {$ELSE}
      LStream.ReadBuffer(LBytes[0], Length(LBytes));
      {$ENDIF}
      Check(Hex(LBytes) = Hex(LSink.Bytes), 'Platform stream adapter preserves exact bytes');
    finally LStream.Free end;
    WriteLn('PCM ', Hex(LSink.Bytes));
  finally LSink.Free end;
  LHeader := WavePcm16Header(384000, 2, Int64(1073741815));
  Check((Length(LHeader) = Rf64HeaderBytes) and
    (Hex(Copy(LHeader, 0, 8)) = '52463634FFFFFFFF'), 'RF64 boundary header');
  Check(Hex(LHeader) = '52463634FFFFFFFF57415645647336341C0000002400000001000000' +
    'DCFFFFFF00000000F7FFFF3F0000000000000000666D7420100000000100020000DC0500' +
    '007017000400100064617461FFFFFFFF', 'RF64 exact ds64 extent and source geometry');
  WriteLn('RF64 ', Hex(LHeader));
  for I := 0 to 4 do
  begin
    LFailed := False;
    try
      case I of
        0: LHeader := WavePcm16Header(0, 1, 1);
        1: LHeader := WavePcm16Header(44100, 0, 1);
        2: LHeader := WavePcm16Header(44100, 1, -1);
        3: LHeader := WavePcm16Header(44100, 2, MaximumWaveStreamBytes);
        4: QuantizePcm16(NaN);
      end;
    except on EAudio do LFailed := True end;
    Check(LFailed, 'Invalid primary encoding input rejects');
  end;
  Check(Length(WavePcm16Header(8000, 1, 0)) = RiffHeaderBytes, 'Empty bounded RIFF header');
  WriteLn('PASS shared native/pas2js PCM and RIFF/RF64 contract');
end.
