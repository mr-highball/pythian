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
unit pythian.tools.files;

{$mode delphi}
{$H+}

interface

uses
  pythian.audio,
  pythian.analysis;

type
  TWaveAnalysisInfo = record
    Sha256: String;
    SampleRate: Integer;
    Channels: Integer;
    FrameCount: Integer;
  end;

{ Bounded samples and hashing, with the existing learner source/work budgets.
  File remains open denying writes where supported; a second digest detects
  ordinary intervening changes. Concurrent source modification is unsupported. }
function AnalyzeWaveSource(const AFileName: String; const AOptions: TAnalysisOptions;
  out AInfo: TWaveAnalysisInfo): TAudioFeatures;

{ Native tool boundary: hashes precisely the bytes passed to the WAV decoder. }
function LoadWaveSource(const AFileName: String; out ASha256: String): TAudioClip;
function HashAudioBytes(const ABytes: TAudioBytes): String;
function HashText(const AText: String): String;
procedure WriteTextFile(const AFileName, AText: String);
function ReadFileBytes(const AFileName: String; const AMaximumBytes: Integer): TAudioBytes;
procedure WriteFileBytes(const AFileName: String; const ABytes: TAudioBytes);

implementation

uses
  Classes,
  SysUtils,
  pythian.hash,
  pythian.wave,
  pythian.wave.read,
  pythian.analysis.wave;

function AnalyzeWaveSource(const AFileName: String; const AOptions: TAnalysisOptions;
  out AInfo: TWaveAnalysisInfo): TAudioFeatures;
var
  LStream: TFileStream;
  LReader: TWaveFrameReader;
  LInfo: TWaveAnalysisInfo;
  LFeatures: TAudioFeatures;
  LSize: Int64;
  LCount: Integer;
  LWork: Int64;
begin
  AInfo := Default(TWaveAnalysisInfo);
  LStream := TFileStream.Create(AFileName, fmOpenRead or fmShareDenyWrite);
  try
    LSize := LStream.Size;
    if (LSize < 12) or (LSize > MaximumWaveBytes) then
    begin
      raise EAudio.Create('WAVE source file exceeds learner size envelope');
    end;
    LReader := TWaveFrameReader.Create(LStream);
    try
      if LReader.FrameCount > MaximumClipSamples div LReader.Channels then
      begin
        raise EAudio.Create('WAVE source exceeds learner sample budget');
      end;
      LInfo.SampleRate := LReader.SampleRate;
      LInfo.Channels := LReader.Channels;
      LInfo.FrameCount := Integer(LReader.FrameCount);
      PlanAudioAnalysis(LInfo.FrameCount, LInfo.Channels, AOptions, LCount, LWork);
      LStream.Position := 0;
      LInfo.Sha256 := Sha256Stream(LStream, LSize);
      LFeatures := AnalyzeWave(LReader, AOptions);
      LStream.Position := 0;
      if (LStream.Size <> LSize) or
        (Sha256Stream(LStream, LSize) <> LInfo.Sha256) then
      begin
        raise EAudio.Create('WAVE source changed during analysis');
      end;
      Result := LFeatures;
      AInfo := LInfo;
    finally
      LReader.Free;
    end;
  finally
    LStream.Free;
  end;
end;

function HashAudioBytes(const ABytes: TAudioBytes): String;
begin
  Result := Sha256Bytes(ABytes);
end;

function ReadFileBytes(const AFileName: String; const AMaximumBytes: Integer): TAudioBytes;
var
  LStream: TFileStream;
begin
  LStream := TFileStream.Create(AFileName, fmOpenRead or fmShareDenyWrite);
  try
    if (AMaximumBytes < 0) or (LStream.Size > AMaximumBytes) then
    begin
      raise EAudio.Create('Input file exceeds byte budget');
    end;
    Result := nil;
    SetLength(Result, LStream.Size);
    if Length(Result) > 0 then
    begin
      LStream.ReadBuffer(Result[0], Length(Result));
    end;
  finally
    LStream.Free;
  end;
end;

procedure WriteFileBytes(const AFileName: String; const ABytes: TAudioBytes);
var
  LStream: TFileStream;
begin
  LStream := TFileStream.Create(AFileName, fmCreate);
  try
    if Length(ABytes) > 0 then
    begin
      LStream.WriteBuffer(ABytes[0], Length(ABytes));
    end;
  finally
    LStream.Free;
  end;
end;

function HashText(const AText: String): String;
var
  LBytes: TAudioBytes;
begin
  SetLength(LBytes, Length(AText));
  if Length(LBytes) > 0 then
  begin
    Move(AText[1], LBytes[0], Length(LBytes));
  end;
  Result := HashAudioBytes(LBytes);
end;

function LoadWaveSource(const AFileName: String; out ASha256: String): TAudioClip;
var
  LStream: TFileStream;
  LBytes: TAudioBytes;
  LHash: String;
begin
  LStream := TFileStream.Create(AFileName, fmOpenRead or fmShareDenyWrite);
  try
    if (LStream.Size < 12) or (LStream.Size > MaximumWaveBytes) then
    begin
      raise EAudio.Create('WAVE source file exceeds decoder size envelope');
    end;
    SetLength(LBytes, LStream.Size);
    LStream.ReadBuffer(LBytes[0], Length(LBytes));
  finally
    LStream.Free;
  end;
  LHash := HashAudioBytes(LBytes);
  Result := DecodeWave(LBytes);
  ASha256 := LHash;
end;

procedure WriteTextFile(const AFileName, AText: String);
var
  LStream: TFileStream;
begin
  LStream := TFileStream.Create(AFileName, fmCreate);
  try
    if Length(AText) > 0 then
    begin
      LStream.WriteBuffer(AText[1], Length(AText));
    end;
  finally
    LStream.Free;
  end;
end;

end.
