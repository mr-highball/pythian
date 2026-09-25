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
unit pythian.tools.annotations.media;

{$mode delphi}
{$H+}

interface

uses
  Classes,
  fpjson;

{ Source-frame coordinates; no whole-file audio allocation. Waveform calls are
  limited to a window, so clients navigate long recordings by requesting pages. }
function CatalogWaveformRegion(const ACatalogRoot, AHash: String;
  const AStartFrame, AEndFrame: Int64; const ABins: Integer): TJSONObject;
procedure WriteCatalogAudioRegion(const ACatalogRoot, AHash: String;
  const AStartFrame, AEndFrame: Int64; const AOutput: TStream);

implementation

uses
  SysUtils,
  pythian.audio,
  pythian.wave.read,
  pythian.wave.stream,
  pythian.tools.annotations.catalog;

const
  CMaximumWaveformBins = 2048;
  CMaximumWaveformFrames: Int64 = 8388608;
  CMaximumAudioSeconds = 30;
  CMaximumAudioBytes: Int64 = 16777216;
  CReadFrames = 4096;

procedure Need(const ACondition: Boolean; const AMessage: String);
begin
  if not ACondition then
  begin
    raise EAudio.Create(AMessage);
  end;
end;

function OpenCatalogWave(const ACatalogRoot, AHash: String;
  out AStream: TFileStream): TWaveFrameReader;
var
  LTrack: TJSONObject;
  LPath: String;
begin
  AStream := nil;
  LTrack := ReadCatalogTrack(ACatalogRoot, AHash);
  try
    LPath := IncludeTrailingPathDelimiter(ExpandFileName(ACatalogRoot)) +
      'sources' + PathDelim + AHash + '.wav';
    AStream := TFileStream.Create(LPath, fmOpenRead or fmShareDenyWrite);
    try
      Need(AStream.Size = LTrack.Int64s['source_bytes'],
        'Catalog WAV byte count differs from source record');
      Result := TWaveFrameReader.Create(AStream);
      try
        Need((Result.SampleRate = LTrack.Integers['sample_rate']) and
          (Result.Channels = LTrack.Integers['channels']) and
          (Result.FrameCount = LTrack.Int64s['frame_count']),
          'Catalog WAV geometry differs from source record');
      except
        Result.Free;
        raise;
      end;
    except
      FreeAndNil(AStream);
      raise;
    end;
  finally
    LTrack.Free;
  end;
end;

procedure CheckRegion(const AReader: TWaveFrameReader;
  const AStartFrame, AEndFrame: Int64);
begin
  Need((AStartFrame >= 0) and (AEndFrame > AStartFrame) and
    (AEndFrame <= AReader.FrameCount),
    'Region lies outside catalog source frames');
end;

function CatalogWaveformRegion(const ACatalogRoot, AHash: String;
  const AStartFrame, AEndFrame: Int64; const ABins: Integer): TJSONObject;
var
  LStream: TFileStream;
  LReader: TWaveFrameReader;
  LSpan: Int64;
  LRows: TJSONArray;
  LRow: TJSONObject;
  LIndex: Integer;
  LBinStart: Int64;
  LBinEnd: Int64;
  LRemaining: Int64;
  LCount: Integer;
  LSample: Integer;
  LSamples: TAudioSamples;
  LLow: Single;
  LHigh: Single;
begin
  Need((ABins > 0) and (ABins <= CMaximumWaveformBins),
    'Waveform bin count exceeds bound');
  LReader := OpenCatalogWave(ACatalogRoot, AHash, LStream);
  try
    CheckRegion(LReader, AStartFrame, AEndFrame);
    LSpan := AEndFrame - AStartFrame;
    Need((LSpan <= CMaximumWaveformFrames) and (ABins <= LSpan),
      'Waveform frame span exceeds page bound or has empty bins');
    LReader.SeekFrame(AStartFrame);
    Result := TJSONObject.Create;
    try
      Result.Add('version', 1);
      Result.Add('source_sha256', AHash);
      Result.Add('sample_rate', LReader.SampleRate);
      Result.Add('source_channels', LReader.Channels);
      Result.Add('start_frame', AStartFrame);
      Result.Add('end_frame', AEndFrame);
      LRows := TJSONArray.Create;
      Result.Add('bins', LRows);
      for LIndex := 0 to ABins - 1 do
      begin
        LBinStart := AStartFrame + (LSpan * LIndex) div ABins;
        LBinEnd := AStartFrame + (LSpan * (LIndex + 1)) div ABins;
        LRemaining := LBinEnd - LBinStart;
        LLow := 1.0;
        LHigh := -1.0;
        while LRemaining > 0 do
        begin
          LCount := CReadFrames;
          if LRemaining < LCount then
          begin
            LCount := Integer(LRemaining);
          end;
          LSamples := LReader.ReadFrames(LCount);
          Need(Length(LSamples) = LCount * LReader.Channels,
            'Short catalog WAV read');
          for LSample := 0 to High(LSamples) do
          begin
            if LSamples[LSample] < LLow then
            begin
              LLow := LSamples[LSample];
            end;
            if LSamples[LSample] > LHigh then
            begin
              LHigh := LSamples[LSample];
            end;
          end;
          Dec(LRemaining, LCount);
        end;
        LRow := TJSONObject.Create;
        LRows.Add(LRow);
        LRow.Add('start_frame', LBinStart);
        LRow.Add('end_frame', LBinEnd);
        LRow.Add('min', LLow);
        LRow.Add('max', LHigh);
      end;
    except
      Result.Free;
      raise;
    end;
  finally
    LReader.Free;
    LStream.Free;
  end;
end;

procedure WriteCatalogAudioRegion(const ACatalogRoot, AHash: String;
  const AStartFrame, AEndFrame: Int64; const AOutput: TStream);
var
  LStream: TFileStream;
  LReader: TWaveFrameReader;
  LSink: TStreamAudioSink;
  LWriter: TWavePcm16Writer;
  LRemaining: Int64;
  LCount: Integer;
  LSamples: TAudioSamples;
begin
  Need(AOutput <> nil, 'Audio region requires an output stream');
  LReader := OpenCatalogWave(ACatalogRoot, AHash, LStream);
  try
    CheckRegion(LReader, AStartFrame, AEndFrame);
    LRemaining := AEndFrame - AStartFrame;
    Need((LRemaining <= Int64(LReader.SampleRate) * CMaximumAudioSeconds) and
      (LRemaining * LReader.Channels * 2 <= CMaximumAudioBytes),
      'Audio region exceeds duration or byte bound');
    LReader.SeekFrame(AStartFrame);
    LSink := TStreamAudioSink.Create(AOutput);
    try
      LWriter := TWavePcm16Writer.Create(LSink, LReader.SampleRate,
        LReader.Channels, LRemaining);
      try
        while LRemaining > 0 do
        begin
          LCount := CReadFrames;
          if LRemaining < LCount then
          begin
            LCount := Integer(LRemaining);
          end;
          LSamples := LReader.ReadFrames(LCount);
          Need(Length(LSamples) = LCount * LReader.Channels,
            'Short catalog WAV read');
          LWriter.AppendSamples(LSamples);
          Dec(LRemaining, LCount);
        end;
        LWriter.Finish;
      finally
        LWriter.Free;
      end;
    finally
      LSink.Free;
    end;
  finally
    LReader.Free;
    LStream.Free;
  end;
end;

end.
