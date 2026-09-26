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
unit pythian.wave.read;

{$mode delphi}
{$H+}

interface

uses
  Classes,
  pythian.audio;

const
  WaveReadVersion = 1;
  MaximumWaveReadFrames = 65536;
  MaximumWaveReadChunks = 65536;
  MaximumRF64TableEntries = 4096;

type
  { Borrows a seekable stream from its current position through its exact end.
    Construction scans chunk structure without reading the audio payload.
    ReadFrames returns owned interleaved samples; empty means end of audio.
    Calls are sequential/non-reentrant. I/O or sample failures poison the reader;
    argument errors preserve it. No bytes are written; the caller keeps the
    stream open and its content stable. Stream position is controlled here. }
  TWaveFrameReader = class
  strict private
    FStream: TStream;
    FOrigin: Int64;
    FSize: Int64;
    FDataOffset: Int64;
    FFrameCount: Int64;
    FPosition: Int64;
    FSampleRate: Integer;
    FChannels: Integer;
    FTag: Integer;
    FEncodingTag: Integer;
    FBits: Integer;
    FValidBits: Integer;
    FChannelMask: Cardinal;
    FPaddingMask: Int64;
    FWidth: Integer;
    FAlign: Integer;
    FScale: Double;
    FIsRF64: Boolean;
    FBusy: Boolean;
    FFailed: Boolean;
    FBuffer: array[0..4095] of Byte;
    procedure ReadBytes(const ACount: Integer);
    function Number(const AOffset, AWidth: Integer): QWord;
    function SizeNumber(const AOffset: Integer): Int64;
    procedure SeekRelative(const AOffset: Int64);
    procedure Scan;
    procedure CheckReady;
  public
    constructor Create(const AStream: TStream);
    function ReadFrames(const ACount: Integer = 4096): TAudioSamples;
    procedure SeekFrame(const AFrame: Int64);
    property SampleRate: Integer read FSampleRate;
    property Channels: Integer read FChannels;
    property BitsPerSample: Integer read FBits;
    property FormatTag: Integer read FTag;
    property EncodingTag: Integer read FEncodingTag;
    property ValidBitsPerSample: Integer read FValidBits;
    property ChannelMask: Cardinal read FChannelMask;
    property FrameCount: Int64 read FFrameCount;
    property FramePosition: Int64 read FPosition;
    property IsRF64: Boolean read FIsRF64;
    property Failed: Boolean read FFailed;
  end;

implementation

uses
  Math,
  pythian.wave.stream;

const
  RiffTag = $46464952;
  Rf64Tag = $34364652;
  WaveTag = $45564157;
  FormatTagId = $20746D66;
  DataTag = $61746164;
  Ds64Tag = $34367364;
  SizeSentinel = QWord($FFFFFFFF);

type
  TRF64Size = record
    Tag: Cardinal;
    Size: Int64;
    Used: Boolean;
  end;

constructor TWaveFrameReader.Create(const AStream: TStream);
var
  LEnd: Int64;
begin
  inherited Create;
  if AStream = nil then
  begin
    raise EAudio.Create('WAVE reader requires a seekable stream');
  end;
  FStream := AStream;
  FBusy := True;
  try
    FOrigin := FStream.Position;
    LEnd := FStream.Size;
    if (FOrigin < 0) or (LEnd < FOrigin) then
    begin
      raise EAudio.Create('Invalid WAVE stream extent');
    end;
    FSize := LEnd - FOrigin;
    if (FSize < 12) or (FSize > MaximumWaveStreamBytes) then
    begin
      raise EAudio.Create('WAVE stream exceeds exact file-size envelope');
    end;
    Scan;
    SeekRelative(FDataOffset);
  finally
    FBusy := False;
  end;
end;

procedure TWaveFrameReader.ReadBytes(const ACount: Integer);
var
  LRead: Integer;
  LCount: LongInt;
begin
  if (ACount < 0) or (ACount > SizeOf(FBuffer)) then
  begin
    raise EAudio.Create('Internal WAVE read exceeds buffer');
  end;
  LRead := 0;
  while LRead < ACount do
  begin
    LCount := FStream.Read(FBuffer[LRead], ACount - LRead);
    if (LCount <= 0) or (LCount > ACount - LRead) then
    begin
      raise EAudio.Create('Truncated or invalid WAVE stream read');
    end;
    Inc(LRead, LCount);
  end;
end;

function TWaveFrameReader.Number(const AOffset, AWidth: Integer): QWord;
var
  I: Integer;
begin
  Result := 0;
  for I := AWidth - 1 downto 0 do
  begin
    Result := (Result shl 8) or FBuffer[AOffset + I];
  end;
end;

function TWaveFrameReader.SizeNumber(const AOffset: Integer): Int64;
var
  LValue: QWord;
begin
  LValue := Number(AOffset, 8);
  if LValue > QWord(MaximumWaveStreamBytes) then
  begin
    raise EAudio.Create('RF64 size exceeds exact file-size envelope');
  end;
  Result := LValue;
end;

procedure TWaveFrameReader.SeekRelative(const AOffset: Int64);
begin
  if (AOffset < 0) or (AOffset > FSize) then
  begin
    raise EAudio.Create('WAVE seek exceeds container extent');
  end;
  if FStream.Seek(FOrigin + AOffset, soBeginning) <> FOrigin + AOffset then
  begin
    raise EAudio.Create('WAVE stream did not seek to requested position');
  end;
end;

procedure TWaveFrameReader.Scan;
var
  LOffset: Int64;
  LNext: Int64;
  LChunkSize: Int64;
  LRawSize: QWord;
  LRiffSize: Int64;
  LDataSize64: QWord;
  LSampleCount64: QWord;
  LDataSize: Int64;
  LTag: Cardinal;
  LTable: array of TRF64Size;
  LTableCount: Integer;
  LChunkCount: Integer;
  LFormatFound: Boolean;
  LDataFound: Boolean;
  LFound: Boolean;
  LRate: QWord;
  I: Integer;
begin
  SeekRelative(0);
  ReadBytes(12);
  LTag := Number(0, 4);
  FIsRF64 := LTag = Rf64Tag;
  if ((LTag <> RiffTag) and not FIsRF64) or (Number(8, 4) <> WaveTag) then
  begin
    raise EAudio.Create('Expected little-endian RIFF or RF64 WAVE');
  end;
  LRawSize := Number(4, 4);
  LRiffSize := LRawSize;
  LOffset := 12;
  LDataSize64 := 0;
  LSampleCount64 := 0;
  if FIsRF64 then
  begin
    if FSize - LOffset < 36 then
    begin
      raise EAudio.Create('RF64 requires a leading ds64 chunk');
    end;
    ReadBytes(8);
    LChunkSize := Number(4, 4);
    if (Number(0, 4) <> Ds64Tag) or (LChunkSize < 28) or
      (QWord(LChunkSize) = SizeSentinel) or
      (LChunkSize > FSize - 20) then
    begin
      raise EAudio.Create('Invalid leading RF64 ds64 chunk');
    end;
    LNext := 20 + LChunkSize + (LChunkSize mod 2);
    if LNext > FSize then
    begin
      raise EAudio.Create('RF64 ds64 padding exceeds container');
    end;
    ReadBytes(28);
    if LRawSize = SizeSentinel then
    begin
      LRiffSize := SizeNumber(0);
    end;
    LDataSize64 := Number(8, 8);
    LSampleCount64 := Number(16, 8);
    if Number(24, 4) > MaximumRF64TableEntries then
    begin
      raise EAudio.Create('RF64 size table exceeds entry budget');
    end;
    LTableCount := Number(24, 4);
    if 28 + Int64(LTableCount) * 12 > LChunkSize then
    begin
      raise EAudio.Create('RF64 size table exceeds ds64 extent');
    end;
    SetLength(LTable, LTableCount);
    for I := 0 to High(LTable) do
    begin
      ReadBytes(12);
      LTable[I].Tag := Number(0, 4);
      LTable[I].Size := SizeNumber(4);
    end;
    LOffset := LNext;
  end;
  if LRiffSize <> FSize - 8 then
  begin
    raise EAudio.Create('WAVE container length does not match stream extent');
  end;
  LFormatFound := False;
  LDataFound := False;
  LDataSize := 0;
  LChunkCount := Ord(FIsRF64);
  while LOffset < FSize do
  begin
    Inc(LChunkCount);
    if (LChunkCount > MaximumWaveReadChunks) or (FSize - LOffset < 8) then
    begin
      raise EAudio.Create('WAVE chunk budget exceeded or header truncated');
    end;
    SeekRelative(LOffset);
    ReadBytes(8);
    LTag := Number(0, 4);
    LRawSize := Number(4, 4);
    LChunkSize := LRawSize;
    if FIsRF64 and (LRawSize = SizeSentinel) then
    begin
      if LTag = DataTag then
      begin
        if LDataSize64 > QWord(MaximumWaveStreamBytes) then
        begin
          raise EAudio.Create('RF64 data size exceeds exact file-size envelope');
        end;
        LChunkSize := LDataSize64;
      end
      else
      begin
        LFound := False;
        for I := 0 to High(LTable) do
        begin
          if not LTable[I].Used and (LTable[I].Tag = LTag) then
          begin
            LChunkSize := LTable[I].Size;
            LTable[I].Used := True;
            LFound := True;
            Break;
          end;
        end;
        if not LFound then
        begin
          raise EAudio.Create('RF64 sentinel chunk has no size-table entry');
        end;
      end;
    end;
    if LChunkSize > FSize - LOffset - 8 then
    begin
      raise EAudio.Create('WAVE chunk exceeds container boundary');
    end;
    LNext := LOffset + 8 + LChunkSize + (LChunkSize mod 2);
    if LNext > FSize then
    begin
      raise EAudio.Create('WAVE chunk padding exceeds container boundary');
    end;
    if FIsRF64 and (LTag = Ds64Tag) then
    begin
      raise EAudio.Create('Duplicate RF64 ds64 chunk');
    end;
    if LTag = FormatTagId then
    begin
      if LFormatFound or (LChunkSize < 16) then
      begin
        raise EAudio.Create('Duplicate or short WAVE format chunk');
      end;
      ReadBytes(16);
      FTag := Number(0, 2);
      FChannels := Number(2, 2);
      LRate := Number(4, 4);
      if (LRate < 1) or (LRate > MaximumSampleRate) then
      begin
        raise EAudio.Create('Unsupported WAVE sample rate');
      end;
      FSampleRate := LRate;
      ValidateAudioFormat(FSampleRate, FChannels);
      FBits := Number(14, 2);
      if not (FBits in [8, 16, 24, 32]) then
      begin
        raise EAudio.Create('Unsupported WAVE sample container');
      end;
      FWidth := FBits div 8;
      FAlign := FChannels * FWidth;
      if (Number(12, 2) <> QWord(FAlign)) or
        (Number(8, 4) <> QWord(FSampleRate * FAlign)) then
      begin
        raise EAudio.Create('Inconsistent WAVE alignment or byte rate');
      end;
      FEncodingTag := FTag;
      FValidBits := FBits;
      if FTag = $FFFE then
      begin
        if LChunkSize < 40 then
        begin
          raise EAudio.Create('Short extensible WAVE format');
        end;
        ReadBytes(24);
        if (Number(0, 2) < 22) or (18 + Number(0, 2) > QWord(LChunkSize)) then
        begin
          raise EAudio.Create('Extensible WAVE extension exceeds format extent');
        end;
        { Complete standard subtype GUID, not just its low format-tag word. }
        if ((Number(8, 4) <> 1) and (Number(8, 4) <> 3)) or
          (Number(12, 4) <> $00100000) or
          (Number(16, 4) <> $AA000080) or
          (Number(20, 4) <> $719B3800) then
        begin
          raise EAudio.Create('Unsupported extensible WAVE subtype GUID');
        end;
        FEncodingTag := Number(8, 4);
        FValidBits := Number(2, 2);
        FChannelMask := Number(4, 4);
        if (FValidBits < 1) or (FValidBits > FBits) then
        begin
          raise EAudio.Create('Invalid extensible WAVE sample precision');
        end;
        { The clip contract supports mono and left/right stereo. Other speaker
          assignments cannot be flattened without losing their meaning. }
        if (FChannelMask <> 0) and
          not (((FChannels = 1) and (FChannelMask = 4)) or
          ((FChannels = 2) and (FChannelMask = 3))) then
        begin
          raise EAudio.Create('Unsupported extensible WAVE speaker layout');
        end;
      end;
      if not ((FEncodingTag = 1) or
        ((FEncodingTag = 3) and (FBits = 32) and (FValidBits = 32))) then
      begin
        raise EAudio.Create('Unsupported WAVE encoding');
      end;
      FPaddingMask := (Int64(1) shl (FBits - FValidBits)) - 1;
      FScale := Int64(1) shl (FBits - 1);
      LFormatFound := True;
    end;
    if LTag = DataTag then
    begin
      if LDataFound then
      begin
        raise EAudio.Create('Multiple WAVE data chunks are not supported');
      end;
      FDataOffset := LOffset + 8;
      LDataSize := LChunkSize;
      LDataFound := True;
    end;
    LOffset := LNext;
  end;
  if not LFormatFound or not LDataFound then
  begin
    raise EAudio.Create('WAVE requires format and data chunks');
  end;
  if LDataSize mod FAlign <> 0 then
  begin
    raise EAudio.Create('WAVE data does not contain complete frames');
  end;
  FFrameCount := LDataSize div FAlign;
  if FIsRF64 and (LSampleCount64 <> 0) and (LSampleCount64 <> QWord(FFrameCount)) then
  begin
    raise EAudio.Create('RF64 nonzero sample count disagrees with decoded frame extent');
  end;
end;

procedure TWaveFrameReader.CheckReady;
begin
  if FBusy or FFailed then
  begin
    raise EAudio.Create('WAVE reader must be idle and healthy');
  end;
end;

procedure TWaveFrameReader.SeekFrame(const AFrame: Int64);
begin
  CheckReady;
  if (AFrame < 0) or (AFrame > FFrameCount) then
  begin
    raise EAudio.Create('WAVE frame seek outside audio extent');
  end;
  FBusy := True;
  try
    try
      SeekRelative(FDataOffset + AFrame * FAlign);
      FPosition := AFrame;
    except
      FFailed := True;
      raise;
    end;
  finally
    FBusy := False;
  end;
end;

function TWaveFrameReader.ReadFrames(const ACount: Integer): TAudioSamples;
var
  LFrames: Integer;
  LBlockFrames: Integer;
  LDone: Integer;
  LIndex: Integer;
  LValue: Int64;
  LWord: Cardinal;
  LSample: Single;
  LCandidate: TAudioSamples;
begin
  CheckReady;
  if (ACount < 1) or (ACount > MaximumWaveReadFrames) then
  begin
    raise EAudio.Create('WAVE block request must contain 1..65536 frames');
  end;
  LFrames := Min(Int64(ACount), FFrameCount - FPosition);
  LCandidate := nil;
  SetLength(LCandidate, LFrames * FChannels);
  if LFrames = 0 then
  begin
    Exit(LCandidate);
  end;
  FBusy := True;
  try
    try
      SeekRelative(FDataOffset + FPosition * FAlign);
      LDone := 0;
      while LDone < LFrames do
      begin
        LBlockFrames := Min(LFrames - LDone, SizeOf(FBuffer) div FAlign);
        ReadBytes(LBlockFrames * FAlign);
        for LIndex := 0 to LBlockFrames * FChannels - 1 do
        begin
          LValue := Number(LIndex * FWidth, FWidth);
          if FEncodingTag = 3 then
          begin
            LWord := LValue;
            if (LWord and $7F800000) = $7F800000 then
            begin
              raise EAudio.Create('Non-finite WAVE float sample');
            end;
            Move(LWord, LSample, SizeOf(LWord));
          end
          else
          begin
            if (LValue and FPaddingMask) <> 0 then
            begin
              raise EAudio.Create('Nonzero unused bits in extensible WAVE PCM sample');
            end;
            if FBits = 8 then
            begin
              Dec(LValue, 128);
            end
            else if LValue >= (Int64(1) shl (FBits - 1)) then
            begin
              Dec(LValue, Int64(1) shl FBits);
            end;
            LSample := LValue / FScale;
          end;
          LCandidate[LDone * FChannels + LIndex] := LSample;
        end;
        Inc(LDone, LBlockFrames);
      end;
      Inc(FPosition, LFrames);
      Result := LCandidate;
    except
      FFailed := True;
      raise;
    end;
  finally
    FBusy := False;
  end;
end;

end.
