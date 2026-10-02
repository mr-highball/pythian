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
  fpjson,
  pythian.wave.read;

{ Shared presentation of the native reader's owned measurements. }
function WaveformBinsJSON(const AOverview: TWaveformOverview): TJSONArray;

{ Source-frame coordinates; no whole-file audio allocation. Exact waveform pages
  have a frame bound. Sampled overviews inspect at most 256 windows of 64 frames
  regardless of span, and explicitly return their sampled extent/read count. }
function CatalogWaveformRegion(const ACatalogRoot, AHash: String;
  const AStartFrame, AEndFrame: Int64; const ABins: Integer;
  const ASampled: Boolean = False): TJSONObject;
procedure WriteCatalogAudioRegion(const ACatalogRoot, AHash: String;
  const AStartFrame, AEndFrame: Int64; const AOutput: TStream);
procedure WriteCatalogBeatCueRegion(const ACatalogRoot, AHash: String;
  const AStartFrame, AEndFrame: Int64; const ACandidate: Integer;
  const AOutput: TStream);

implementation

uses
  SysUtils,
  Math,
  pythian.audio,
  pythian.oscillator,
  pythian.wave.stream,
  pythian.tools.annotations.catalog,
  pythian.tools.annotations.proposal,
  pythian.tools.annotations.review;

const
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

function WaveformBinsJSON(const AOverview: TWaveformOverview): TJSONArray;
var
  LIndex: Integer;
  LRow: TJSONObject;
  LBin: TWaveformBin;
begin
  Result := TJSONArray.Create;
  try
    for LIndex := 0 to High(AOverview.Bins) do
    begin
      LBin := AOverview.Bins[LIndex];
      LRow := TJSONObject.Create;
      Result.Add(LRow);
      LRow.Add('start_frame', LBin.StartFrame);
      LRow.Add('end_frame', LBin.EndFrame);
      LRow.Add('min', LBin.Minimum);
      LRow.Add('max', LBin.Maximum);
      LRow.Add('peak', LBin.Peak);
      LRow.Add('rms', LBin.Rms);
      LRow.Add('sampled_start_frame', LBin.StartFrame);
      LRow.Add('sampled_end_frame', LBin.SampledEndFrame);
    end;
  except
    Result.Free;
    raise;
  end;
end;

function CatalogWaveformRegion(const ACatalogRoot, AHash: String;
  const AStartFrame, AEndFrame: Int64; const ABins: Integer;
  const ASampled: Boolean): TJSONObject;
var
  LStream: TFileStream;
  LReader: TWaveFrameReader;
  LOverview: TWaveformOverview;
begin
  LReader := OpenCatalogWave(ACatalogRoot, AHash, LStream);
  try
    LOverview := LReader.ReadWaveform(AStartFrame, AEndFrame, ABins, ASampled);
    Result := TJSONObject.Create;
    try
      Result.Add('version', 1);
      Result.Add('source_sha256', AHash);
      Result.Add('sample_rate', LReader.SampleRate);
      Result.Add('source_channels', LReader.Channels);
      Result.Add('start_frame', AStartFrame);
      Result.Add('end_frame', AEndFrame);
      if ASampled then
      begin
        Result.Add('sampling', 'uniform_windows');
      end;
      Result.Add('bins', WaveformBinsJSON(LOverview));
      Result.Add('sampled_frame_count', LOverview.SampledFrames);
      Result.Add('payload_read_bytes', LOverview.PayloadBytes);
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

procedure WriteCatalogBeatCueRegion(const ACatalogRoot, AHash: String;
  const AStartFrame, AEndFrame: Int64; const ACandidate: Integer;
  const AOutput: TStream);
var
  LStream: TFileStream;
  LReader: TWaveFrameReader;
  LSink: TStreamAudioSink;
  LWriter: TWavePcm16Writer;
  LTrack: TJSONObject;
  LPacket: TJSONObject;
  LCandidates: TJSONArray;
  LFrames: TJSONArray;
  LCues: TAudioSamples;
  LSignal: TOscillator;
  LRemaining: Int64;
  LPosition: Int64;
  LCueFrame: Int64;
  LCount: Integer;
  LIndex: Integer;
  LOffset: Integer;
  LChannel: Integer;
  LLength: Integer;
  LCuePeak: Single;
  LSamples: TAudioSamples;
begin
  Need(AOutput <> nil, 'Cue audition requires an output stream');
  LTrack := ReadCatalogTrack(ACatalogRoot, AHash);
  try
    Need(CatalogProposalsUnlocked(ACatalogRoot, LTrack),
      'Evaluation proposals require blind review');
    LPacket := ReadCatalogBeatProposals(ACatalogRoot, AHash,
      AStartFrame, AEndFrame);
    try
      LCandidates := LPacket.Arrays['candidates'];
      Need((ACandidate >= 0) and (ACandidate < LCandidates.Count),
        'Cue candidate lies outside saved proposals');
      LFrames := LCandidates.Objects[ACandidate].Arrays['frames'];
      Need(LFrames.Count > 0, 'Selected beat proposal has no cue frames');
      LReader := OpenCatalogWave(ACatalogRoot, AHash, LStream);
      try
        CheckRegion(LReader, AStartFrame, AEndFrame);
        LRemaining := AEndFrame - AStartFrame;
        Need((LRemaining <= Int64(LReader.SampleRate) * CMaximumAudioSeconds) and
          (LRemaining * LReader.Channels * 2 <= CMaximumAudioBytes),
          'Cue region exceeds duration or byte bound');
        SetLength(LCues, Integer(LRemaining));
        LLength := Max(1, LReader.SampleRate div 125);
        LSignal := TOscillator.Create(LReader.SampleRate, 731);
        try
          for LIndex := 0 to LFrames.Count - 1 do
          begin
            LCueFrame := LFrames.Int64s[LIndex] - AStartFrame;
            LSignal.Reset(731);
            for LOffset := 0 to Min(LLength, Length(LCues) - LCueFrame) - 1 do
            begin
              LCues[LCueFrame + LOffset] := LCues[LCueFrame + LOffset] +
                LSignal.Next(wsSine, Min(2000, LReader.SampleRate / 8)) *
                (1 - LOffset / LLength);
            end;
          end;
        finally
          LSignal.Free;
        end;
        LCuePeak := 0;
        for LIndex := 0 to High(LCues) do
        begin
          LCuePeak := Max(LCuePeak, Abs(LCues[LIndex]));
        end;
        Need(LCuePeak > 0, 'Selected beat proposal has no audible cue');
        LReader.SeekFrame(AStartFrame);
        LSink := TStreamAudioSink.Create(AOutput);
        try
          LWriter := TWavePcm16Writer.Create(LSink, LReader.SampleRate,
            LReader.Channels, LRemaining);
          try
            LPosition := 0;
            while LRemaining > 0 do
            begin
              LCount := CReadFrames;
              if LRemaining < LCount then
              begin
                LCount := Integer(LRemaining);
              end;
              LSamples := LReader.ReadFrames(LCount);
              Need(Length(LSamples) = LCount * LReader.Channels,
                'Short catalog WAV read during cue audition');
              for LIndex := 0 to LCount - 1 do
              begin
                for LChannel := 0 to LReader.Channels - 1 do
                begin
                  LSamples[LIndex * LReader.Channels + LChannel] :=
                    LSamples[LIndex * LReader.Channels + LChannel] * 0.7 +
                    LCues[LPosition + LIndex] * (0.25 / LCuePeak);
                end;
              end;
              LWriter.AppendSamples(LSamples);
              Inc(LPosition, LCount);
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
    finally
      LPacket.Free;
    end;
  finally
    LTrack.Free;
  end;
end;

end.
