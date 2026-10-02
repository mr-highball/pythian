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
unit pythian.wave.stream;

{$mode delphi}
{$H+}

interface

uses
  Classes,
  pythian.audio;

const
  WaveStreamVersion = 1;
  WaveStreamBlockBytes = 4096;
  MaximumWaveStreamBytes: Int64 = 9007199254740991;
  RiffHeaderBytes = 44;
  Rf64HeaderBytes = 80;

type
  { Borrowed blocks must be consumed synchronously in full or raise. A raising
    sink may have emitted a partial block; physical rollback is not promised. }
  TAudioByteSink = class
  public
    procedure WriteBytes(const ABytes: array of Byte); virtual; abstract;
  end;

  TStreamAudioSink = class(TAudioByteSink)
  strict private
    FStream: TStream;
  public
    constructor Create(const AStream: TStream);
    procedure WriteBytes(const ABytes: array of Byte); override;
  end;

  { Sequential PCM16 RIFF/RF64 writer extracted from WFC's sink contract.
    Borrows its sink; neither destruction nor Finish closes it. Expected length
    is known before the first write. FrameCount includes confirmed blocks only.
    Input/short-Finish errors are recoverable. Sink exceptions poison the writer.
    Calls are sequential and non-reentrant, including callbacks from the sink. }
  TWavePcm16Writer = class
  strict private
    FSink: TAudioByteSink;
    FSampleRate: Integer;
    FChannels: Integer;
    FExpectedFrames: Int64;
    FFrameCount: Int64;
    FFinished: Boolean;
    FFailed: Boolean;
    FWriting: Boolean;
    FIsRF64: Boolean;
    FBuffer: TAudioBytes;
    procedure CheckWritable;
    procedure WriteBuffer(const AFrames: Integer);
    procedure Append(const AClip: TAudioClip; const ASamples: array of Single);
  public
    constructor Create(const ASink: TAudioByteSink; const ASampleRate, AChannels: Integer;
      const AExpectedFrames: Int64);
    procedure AppendClip(const AClip: TAudioClip);
    { Interleaved borrowed samples; callers keep them unchanged until return. }
    procedure AppendSamples(const ASamples: array of Single);
    procedure Finish;
    property SampleRate: Integer read FSampleRate;
    property Channels: Integer read FChannels;
    property ExpectedFrames: Int64 read FExpectedFrames;
    property FrameCount: Int64 read FFrameCount;
    property Finished: Boolean read FFinished;
    property Failed: Boolean read FFailed;
    property IsRF64: Boolean read FIsRF64;
  end;

procedure WriteWavePcm16(const AStream: TStream; const AClip: TAudioClip);
{ Shared header for native streaming and bounded device captures whose final
  frame count becomes known only at stop. Owns validation and RIFF/RF64 choice. }
function WavePcm16Header(const ASampleRate, AChannels: Integer;
  const AFrames: Int64): TAudioBytes;

implementation

uses
  Math;

const
  DWordMaximum: Int64 = 4294967295;

procedure PutLE(var ABytes: TAudioBytes; const AOffset, ACount: Integer; AValue: Int64);
var
  LIndex: Integer;
begin
  for LIndex := 0 to ACount - 1 do
  begin
    ABytes[AOffset + LIndex] := AValue mod 256;
    AValue := AValue div 256;
  end;
end;

procedure PutTag(var ABytes: TAudioBytes; const AOffset: Integer; const ATag: String);
var
  LIndex: Integer;
begin
  for LIndex := 1 to Length(ATag) do
  begin
    ABytes[AOffset + LIndex - 1] := Ord(ATag[LIndex]);
  end;
end;

constructor TStreamAudioSink.Create(const AStream: TStream);
begin
  inherited Create;
  if AStream = nil then
  begin
    raise EAudio.Create('Audio sink requires a stream');
  end;
  FStream := AStream;
end;

procedure TStreamAudioSink.WriteBytes(const ABytes: array of Byte);
begin
  if Length(ABytes) > 0 then
  begin
    {$IFDEF PAS2JS}
    FStream.WriteBuffer(ABytes, Length(ABytes));
    {$ELSE}
    FStream.WriteBuffer(ABytes[0], Length(ABytes));
    {$ENDIF}
  end;
end;

constructor TWavePcm16Writer.Create(const ASink: TAudioByteSink;
  const ASampleRate, AChannels: Integer; const AExpectedFrames: Int64);
begin
  inherited Create;
  if ASink = nil then
  begin
    raise EAudio.Create('WAVE writer requires a sink');
  end;
  FSink := ASink;
  FSampleRate := ASampleRate;
  FChannels := AChannels;
  FExpectedFrames := AExpectedFrames;
  FBuffer := WavePcm16Header(ASampleRate, AChannels, AExpectedFrames);
  FIsRF64 := Length(FBuffer) = Rf64HeaderBytes;
  WriteBuffer(0);
end;

procedure TWavePcm16Writer.CheckWritable;
begin
  if FWriting then
  begin
    raise EAudio.Create('Sink callbacks cannot reenter a WAVE writer');
  end;
  if FFailed then
  begin
    raise EAudio.Create('A previous WAVE sink write failed');
  end;
  if FFinished then
  begin
    raise EAudio.Create('WAVE writer has already finished');
  end;
end;

procedure TWavePcm16Writer.WriteBuffer(const AFrames: Integer);
begin
  FWriting := True;
  try
    try
      FSink.WriteBytes(FBuffer);
    except
      FFailed := True;
      raise;
    end;
    Inc(FFrameCount, AFrames);
  finally
    FWriting := False;
  end;
end;

function WavePcm16Header(const ASampleRate, AChannels: Integer;
  const AFrames: Int64): TAudioBytes;
var
  LDataBytes: Int64;
  LFormatOffset: Integer;
  LDataOffset: Integer;
  LIsRF64: Boolean;
begin
  ValidateAudioFormat(ASampleRate, AChannels);
  if (AFrames < 0) or
    (AFrames > (MaximumWaveStreamBytes - Rf64HeaderBytes) div (AChannels * 2)) then
    raise EAudio.Create('WAVE expected length exceeds exact file-size envelope');
  LIsRF64 := AFrames > (DWordMaximum - 36) div (AChannels * 2);
  LDataBytes := AFrames * AChannels * 2;
  if LIsRF64 then
  begin
    { EBU Tech 3306 v1.1, section 3.4 and Annex A.2. This encodes the RF64
      size extension, not broadcast metadata or multichannel speaker layouts. }
    SetLength(Result, Rf64HeaderBytes);
    PutTag(Result, 0, 'RF64');
    PutLE(Result, 4, 4, DWordMaximum);
    PutTag(Result, 8, 'WAVE');
    PutTag(Result, 12, 'ds64');
    PutLE(Result, 16, 4, 28);
    PutLE(Result, 20, 8, LDataBytes + Rf64HeaderBytes - 8);
    PutLE(Result, 28, 8, LDataBytes);
    PutLE(Result, 36, 8, AFrames);
    PutLE(Result, 44, 4, 0);
    LFormatOffset := 48;
    LDataOffset := 72;
  end
  else
  begin
    SetLength(Result, RiffHeaderBytes);
    PutTag(Result, 0, 'RIFF');
    PutLE(Result, 4, 4, LDataBytes + RiffHeaderBytes - 8);
    PutTag(Result, 8, 'WAVE');
    LFormatOffset := 12;
    LDataOffset := 36;
  end;
  PutTag(Result, LFormatOffset, 'fmt ');
  PutLE(Result, LFormatOffset + 4, 4, 16);
  PutLE(Result, LFormatOffset + 8, 2, 1);
  PutLE(Result, LFormatOffset + 10, 2, AChannels);
  PutLE(Result, LFormatOffset + 12, 4, ASampleRate);
  PutLE(Result, LFormatOffset + 16, 4, ASampleRate * AChannels * 2);
  PutLE(Result, LFormatOffset + 20, 2, AChannels * 2);
  PutLE(Result, LFormatOffset + 22, 2, 16);
  PutTag(Result, LDataOffset, 'data');
  if LIsRF64 then
  begin
    PutLE(Result, LDataOffset + 4, 4, DWordMaximum);
  end
  else
  begin
    PutLE(Result, LDataOffset + 4, 4, LDataBytes);
  end;
end;

procedure TWavePcm16Writer.Append(const AClip: TAudioClip; const ASamples: array of Single);
var
  LCount: Integer;
  LOffset: Integer;
  LFrames: Integer;
  LIndex: Integer;
  LSample: Integer;
begin
  CheckWritable;
  if AClip <> nil then
  begin
    if (AClip.SampleRate <> FSampleRate) or (AClip.Channels <> FChannels) then
    begin
      raise EAudio.Create('Clip format does not match WAVE writer');
    end;
    LCount := AClip.FrameCount;
  end
  else
  begin
    if (Length(ASamples) mod FChannels <> 0) or (Length(ASamples) > MaximumClipSamples) then
    begin
      raise EAudio.Create('Sample block contains a partial frame or exceeds block-input budget');
    end;
    LCount := Length(ASamples) div FChannels;
  end;
  if LCount > FExpectedFrames - FFrameCount then
  begin
    raise EAudio.Create('Append exceeds declared WAVE frame count');
  end;
  if AClip = nil then
  begin
    for LIndex := 0 to High(ASamples) do
    begin
      RequireFinite(ASamples[LIndex], 'Borrowed WAVE sample');
    end;
  end;
  LOffset := 0;
  while LOffset < LCount do
  begin
    LFrames := Min(LCount - LOffset, WaveStreamBlockBytes div (FChannels * 2));
    SetLength(FBuffer, LFrames * FChannels * 2);
    for LIndex := 0 to LFrames * FChannels - 1 do
    begin
      if AClip <> nil then
      begin
        LSample := QuantizePcm16(AClip.SampleAt(LOffset + LIndex div FChannels,
          LIndex mod FChannels));
      end
      else
      begin
        LSample := QuantizePcm16(ASamples[LOffset * FChannels + LIndex]);
      end;
      if LSample < 0 then
      begin
        Inc(LSample, 65536);
      end;
      FBuffer[LIndex * 2] := LSample and $FF;
      FBuffer[LIndex * 2 + 1] := LSample shr 8;
    end;
    WriteBuffer(LFrames);
    Inc(LOffset, LFrames);
  end;
end;

procedure TWavePcm16Writer.AppendClip(const AClip: TAudioClip);
begin
  CheckWritable;
  if AClip = nil then
  begin
    raise EAudio.Create('WAVE append requires a clip');
  end;
  Append(AClip, []);
end;

procedure TWavePcm16Writer.AppendSamples(const ASamples: array of Single);
begin
  Append(nil, ASamples);
end;

procedure TWavePcm16Writer.Finish;
begin
  if FWriting then
  begin
    raise EAudio.Create('Sink callbacks cannot reenter a WAVE writer');
  end;
  if FFailed then
  begin
    raise EAudio.Create('A previous WAVE sink write failed');
  end;
  if FFinished then
  begin
    Exit;
  end;
  if FFrameCount <> FExpectedFrames then
  begin
    raise EAudio.Create('WAVE stream is short of its declared frame count');
  end;
  FFinished := True;
end;

procedure WriteWavePcm16(const AStream: TStream; const AClip: TAudioClip);
var
  LSink: TStreamAudioSink;
  LWriter: TWavePcm16Writer;
begin
  if AClip = nil then
  begin
    raise EAudio.Create('WAVE output requires a clip');
  end;
  LSink := TStreamAudioSink.Create(AStream);
  try
    LWriter := TWavePcm16Writer.Create(LSink, AClip.SampleRate,
      AClip.Channels, AClip.FrameCount);
    try
      LWriter.AppendClip(AClip);
      LWriter.Finish;
    finally
      LWriter.Free;
    end;
  finally
    LSink.Free;
  end;
end;

end.
