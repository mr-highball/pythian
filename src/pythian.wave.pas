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
unit pythian.wave;

{$mode delphi}
{$H+}

interface

uses
  Classes,
  pythian.audio,
  pythian.progress;

const
  WaveContractVersion = 1;
  MaximumWaveBytes = 256000044;

type
  TWaveLoopInfo = record
    Found: Boolean;
    Flags: Cardinal;
    RootNote: Word;
    BeatCount: Cardinal;
    MeterNumerator: Word;
    MeterDenominator: Word;
    TempoBpm: Single;
  end;

{ Reads optional ACID metadata from a structurally valid RIFF envelope.
  Audio validation remains DecodeWave's responsibility. Duplicate/short ACID
  chunks and nonfinite tempo reject. Metadata is a source declaration, not a
  measured beat/downbeat annotation. Flag bit 0 denotes one-shot; bit 1 root validity. }
function ReadWaveLoopInfo(const ABytes: TAudioBytes): TWaveLoopInfo;

{ RIFF/RF64 little-endian PCM8/16/24/32 and IEEE float32, mono/stereo.
  Unknown chunks are skipped with padding; malformed and ambiguous input fails.
  Decoding owns no caller data. Supported extensible PCM/float is retained;
  compressed formats are rejected.
  Shares the bounded frame reader; full clips retain MaximumClipSamples. }
function DecodeWave(const ABytes: TAudioBytes): TAudioClip;
function EncodeWavePcm16(const AClip: TAudioClip;
  const AProgress: TWorkProgressCallback = nil): TAudioBytes;
function LoadWave(const AFileName: String): TAudioClip;
procedure SaveWavePcm16(const AFileName: String; const AClip: TAudioClip;
  const AProgress: TWorkProgressCallback = nil);

implementation

uses
  SysUtils,
  pythian.ieee754,
  pythian.binary,
  pythian.stream.bytes,
  pythian.wave.stream,
  pythian.wave.read;

function HasTag(const ABytes: TAudioBytes; const AOffset: Integer;
  const ATag: String): Boolean;
var
  LIndex: Integer;
begin
  Result := False;
  if (AOffset < 0) or (AOffset > Length(ABytes) - 4) then
  begin
    Exit;
  end;
  for LIndex := 1 to 4 do
  begin
    if ABytes[AOffset + LIndex - 1] <> Ord(ATag[LIndex]) then
    begin
      Exit;
    end;
  end;
  Result := True;
end;

function ReadWaveLoopInfo(const ABytes: TAudioBytes): TWaveLoopInfo;
var
  LOffset: Integer;
  LSize: Int64;
  LNext: Int64;
  LWord: Cardinal;
  LInfo: TWaveLoopInfo;
begin
  LInfo := Default(TWaveLoopInfo);
  if (Length(ABytes) < 12) or (Length(ABytes) > MaximumWaveBytes) or
    not HasTag(ABytes, 0, 'RIFF') or not HasTag(ABytes, 8, 'WAVE') then
  begin
    raise EAudio.Create('Loop metadata requires bounded RIFF/WAVE');
  end;
  if ReadUnsignedLE(ABytes, 4, 4) + 8 <> Length(ABytes) then
  begin
    raise EAudio.Create('Loop metadata RIFF length mismatch');
  end;
  LOffset := 12;
  while LOffset < Length(ABytes) do
  begin
    if Length(ABytes) - LOffset < 8 then
    begin
      raise EAudio.Create('Truncated loop metadata chunk header');
    end;
    LSize := ReadUnsignedLE(ABytes, LOffset + 4, 4);
    LNext := Int64(LOffset) + 8 + LSize + (LSize mod 2);
    if LNext > Length(ABytes) then
    begin
      raise EAudio.Create('Loop metadata chunk exceeds RIFF');
    end;
    if HasTag(ABytes, LOffset, 'acid') then
    begin
      if LInfo.Found or (LSize < 24) then
      begin
        raise EAudio.Create('Duplicate or short ACID metadata');
      end;
      LInfo.Found := True;
      LInfo.Flags := ReadUnsignedLE(ABytes, LOffset + 8, 4);
      LInfo.RootNote := ReadUnsignedLE(ABytes, LOffset + 12, 2);
      LInfo.BeatCount := ReadUnsignedLE(ABytes, LOffset + 20, 4);
      LInfo.MeterDenominator := ReadUnsignedLE(ABytes, LOffset + 24, 2);
      LInfo.MeterNumerator := ReadUnsignedLE(ABytes, LOffset + 26, 2);
      LWord := ReadUnsignedLE(ABytes, LOffset + 28, 4);
      LInfo.TempoBpm := DecodeFloat32Bits(LWord);
      RequireFinite(LInfo.TempoBpm, 'ACID tempo');
    end;
    LOffset := LNext;
  end;
  Result := LInfo;
end;

function ReadWaveClip(const AStream: TStream): TAudioClip;
var
  LReader: TWaveFrameReader;
begin
  LReader := TWaveFrameReader.Create(AStream);
  try
    if LReader.FrameCount > MaximumClipSamples div LReader.Channels then
    begin
      raise EAudio.Create('Decoded WAVE exceeds sample budget; use bounded frame reads');
    end;
    Result := LReader.ReadClip(0, Integer(LReader.FrameCount));
  finally
    LReader.Free;
  end;
end;

function DecodeWave(const ABytes: TAudioBytes): TAudioClip;
var
  LStream: TAudioBytesReadStream;
begin
  if (Length(ABytes) < 12) or (Length(ABytes) > MaximumWaveBytes) then
  begin
    raise EAudio.Create('WAVE size outside decoder budget');
  end;
  LStream := TAudioBytesReadStream.Create(ABytes);
  try
    Result := ReadWaveClip(LStream);
  finally
    LStream.Free;
  end;
end;

function EncodeWavePcm16(const AClip: TAudioClip;
  const AProgress: TWorkProgressCallback): TAudioBytes;
var
  LStream: TMemoryStream;
  LOffset: Integer;
  LCount: Integer;
begin
  Result := nil;
  LStream := TMemoryStream.Create;
  try
    WriteWavePcm16(LStream, AClip, AProgress);
    SetLength(Result, LStream.Size);
    LStream.Position := 0;
    LOffset := 0;
    ReportWork(AProgress, 'encode_wave_bytes', wuBytes, 0, Length(Result));
    while LOffset < Length(Result) do
    begin
      LCount := Length(Result) - LOffset;
      if LCount > 65536 then
      begin
        LCount := 65536;
      end;
      if ReadStreamBytes(LStream, Result, LOffset, LCount) <> LCount then
      begin
        raise EAudio.Create('Encoded WAVE stream ended before its declared size');
      end;
      Inc(LOffset, LCount);
      ReportWork(AProgress, 'encode_wave_bytes', wuBytes, LOffset, Length(Result));
    end;
  finally
    LStream.Free;
  end;
end;

function LoadWave(const AFileName: String): TAudioClip;
{$ifndef pas2js}
var
  LStream: TFileStream;
{$endif}
begin
  {$ifdef pas2js}
  raise EAudio.Create('Filename WAV I/O is native-only; supply explicit WAV bytes');
  {$else}
  LStream := TFileStream.Create(AFileName, fmOpenRead or fmShareDenyWrite);
  try
    Result := ReadWaveClip(LStream);
  finally
    LStream.Free;
  end;
  {$endif}
end;

procedure SaveWavePcm16(const AFileName: String; const AClip: TAudioClip;
  const AProgress: TWorkProgressCallback);
{$ifndef pas2js}
var
  LStream: TFileStream;
{$endif}
begin
  {$ifdef pas2js}
  raise EAudio.Create('Filename WAV I/O is native-only; use encoded WAV bytes');
  {$else}
  if AClip = nil then
  begin
    raise EAudio.Create('WAVE output requires a clip');
  end;
  LStream := TFileStream.Create(AFileName, fmCreate);
  try
    WriteWavePcm16(LStream, AClip, AProgress);
  finally
    LStream.Free;
  end;
  {$endif}
end;

end.
