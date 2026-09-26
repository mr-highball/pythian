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
  pythian.audio;

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
  Decoding owns no caller data. Extensible/compressed formats are rejected.
  Shares the bounded frame reader; full clips retain MaximumClipSamples. }
function DecodeWave(const ABytes: TAudioBytes): TAudioClip;
function EncodeWavePcm16(const AClip: TAudioClip): TAudioBytes;
function LoadWave(const AFileName: String): TAudioClip;
procedure SaveWavePcm16(const AFileName: String; const AClip: TAudioClip);

implementation

uses
  SysUtils,
  pythian.wave.stream,
  pythian.wave.read;

function ReadLE(const ABytes: TAudioBytes; const AOffset, ACount: Integer): Int64;
var
  LIndex: Integer;
begin
  if (AOffset < 0) or (AOffset > Length(ABytes) - ACount) then
  begin
    raise EAudio.Create('Truncated WAVE field');
  end;
  Result := 0;
  for LIndex := ACount - 1 downto 0 do
  begin
    Result := Result * 256 + ABytes[AOffset + LIndex];
  end;
end;

function HasTag(const ABytes: TAudioBytes; const AOffset: Integer;
  const ATag: AnsiString): Boolean;
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
  if ReadLE(ABytes, 4, 4) + 8 <> Length(ABytes) then
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
    LSize := ReadLE(ABytes, LOffset + 4, 4);
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
      LInfo.Flags := ReadLE(ABytes, LOffset + 8, 4);
      LInfo.RootNote := ReadLE(ABytes, LOffset + 12, 2);
      LInfo.BeatCount := ReadLE(ABytes, LOffset + 20, 4);
      LInfo.MeterDenominator := ReadLE(ABytes, LOffset + 24, 2);
      LInfo.MeterNumerator := ReadLE(ABytes, LOffset + 26, 2);
      LWord := ReadLE(ABytes, LOffset + 28, 4);
      Move(LWord, LInfo.TempoBpm, SizeOf(LWord));
      RequireFinite(LInfo.TempoBpm, 'ACID tempo');
    end;
    LOffset := LNext;
  end;
  Result := LInfo;
end;

type
  TWaveBytesView = class(TCustomMemoryStream)
  strict private
    FBytes: TAudioBytes;
  public
    constructor Create(const ABytes: TAudioBytes);
    function Write(const ABuffer; ACount: LongInt): LongInt; override;
  end;

constructor TWaveBytesView.Create(const ABytes: TAudioBytes);
begin
  inherited Create;
  FBytes := ABytes;
  if Length(FBytes) > 0 then
  begin
    SetPointer(@FBytes[0], Length(FBytes));
  end
  else
  begin
    SetPointer(nil, 0);
  end;
end;

function TWaveBytesView.Write(const ABuffer; ACount: LongInt): LongInt;
begin
  Result := 0;
  raise EAudio.Create('WAVE byte view is read-only');
end;

function ReadWaveClip(const AStream: TStream): TAudioClip;
var
  LReader: TWaveFrameReader;
  LSamples: TAudioSamples;
  LBlock: TAudioSamples;
  LOffset: Integer;
begin
  LReader := TWaveFrameReader.Create(AStream);
  try
    if LReader.FrameCount > MaximumClipSamples div LReader.Channels then
    begin
      raise EAudio.Create('Decoded WAVE exceeds sample budget; use bounded frame reads');
    end;
    SetLength(LSamples, Integer(LReader.FrameCount) * LReader.Channels);
    LOffset := 0;
    while LOffset < Length(LSamples) do
    begin
      LBlock := LReader.ReadFrames(MaximumWaveReadFrames);
      if Length(LBlock) = 0 then
      begin
        raise EAudio.Create('WAVE reader ended before declared frame extent');
      end;
      Move(LBlock[0], LSamples[LOffset], Length(LBlock) * SizeOf(Single));
      Inc(LOffset, Length(LBlock));
    end;
    Result := TAudioClip.Create(LReader.SampleRate, LReader.Channels, LSamples);
  finally
    LReader.Free;
  end;
end;

function DecodeWave(const ABytes: TAudioBytes): TAudioClip;
var
  LStream: TWaveBytesView;
begin
  if (Length(ABytes) < 12) or (Length(ABytes) > MaximumWaveBytes) then
  begin
    raise EAudio.Create('WAVE size outside decoder budget');
  end;
  LStream := TWaveBytesView.Create(ABytes);
  try
    Result := ReadWaveClip(LStream);
  finally
    LStream.Free;
  end;
end;

function EncodeWavePcm16(const AClip: TAudioClip): TAudioBytes;
var
  LStream: TMemoryStream;
begin
  Result := nil;
  LStream := TMemoryStream.Create;
  try
    WriteWavePcm16(LStream, AClip);
    SetLength(Result, LStream.Size);
    LStream.Position := 0;
    LStream.ReadBuffer(Result[0], Length(Result));
  finally
    LStream.Free;
  end;
end;

function LoadWave(const AFileName: String): TAudioClip;
var
  LStream: TFileStream;
begin
  LStream := TFileStream.Create(AFileName, fmOpenRead or fmShareDenyWrite);
  try
    Result := ReadWaveClip(LStream);
  finally
    LStream.Free;
  end;
end;

procedure SaveWavePcm16(const AFileName: String; const AClip: TAudioClip);
var
  LStream: TFileStream;
begin
  if AClip = nil then
  begin
    raise EAudio.Create('WAVE output requires a clip');
  end;
  LStream := TFileStream.Create(AFileName, fmCreate);
  try
    WriteWavePcm16(LStream, AClip);
  finally
    LStream.Free;
  end;
end;

end.
