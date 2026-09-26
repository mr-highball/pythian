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
program pythian_tests_resample_stream;

{$mode delphi}
{$H+}

uses
  Classes,
  SysUtils,
  Math,
  pythian.audio,
  pythian.wave,
  pythian.wave.read,
  pythian.wave.resample,
  pythian.resample,
  pythian.resample.stream;

type
  TBlockedReader = class(TPcmFrameReader)
  private
    FClip: TAudioClip;
    FBlockFrames: Integer;
    FBlock: TAudioSamples;
    FBlockIndex: Integer;
    FNextFrame: Integer;
  public
    Reads: Integer;
    FailAt: Integer;
    Reenter: TSincResampleStream;
    Inject: Boolean;
    InjectedValue: Double;
    constructor Create(const AClip: TAudioClip; const ABlockFrames: Integer);
    function ReadFrame(out ALeft, ARight: Double): Boolean; override;
  end;

procedure Check(const ACondition: Boolean; const AMessage: String);
begin
  if not ACondition then
  begin
    raise Exception.Create(AMessage);
  end;
end;

constructor TBlockedReader.Create(const AClip: TAudioClip; const ABlockFrames: Integer);
begin
  inherited Create(AClip.SampleRate, AClip.Channels);
  FClip := AClip;
  FBlockFrames := ABlockFrames;
  FailAt := -1;
end;

function TBlockedReader.ReadFrame(out ALeft, ARight: Double): Boolean;
var
  LCount: Integer;
  LIndex: Integer;
  LChannel: Integer;
begin
  if Reads = FailAt then
  begin
    raise EAudio.Create('Deliberate input failure');
  end;
  if Reenter <> nil then
  begin
    ALeft := 0;
    ARight := 0;
    try
      Reenter.ReadFrame(ALeft, ARight);
    except
      on EAudio do
      begin
        { The outer converter must remain poisoned even if a reader swallows it. }
      end;
    end;
  end;
  Inc(Reads);
  if Inject then
  begin
    ALeft := InjectedValue;
    ARight := InjectedValue;
    Exit(True);
  end;
  if FBlockIndex = Length(FBlock) then
  begin
    LCount := Min(FBlockFrames, FClip.FrameCount - FNextFrame);
    if LCount = 0 then
    begin
      Exit(False);
    end;
    SetLength(FBlock, LCount * Channels);
    for LIndex := 0 to LCount - 1 do
    begin
      for LChannel := 0 to Channels - 1 do
      begin
        FBlock[LIndex * Channels + LChannel] := FClip.SampleAt(FNextFrame + LIndex, LChannel);
      end;
    end;
    Inc(FNextFrame, LCount);
    FBlockIndex := 0;
  end;
  ALeft := FBlock[FBlockIndex];
  ARight := ALeft;
  if Channels = 2 then
  begin
    ARight := FBlock[FBlockIndex + 1];
  end;
  Inc(FBlockIndex, Channels);
  Result := True;
end;

function StreamClip(const ASource: TAudioClip; const AOutputRate,
  AInputBlockFrames: Integer): TAudioClip;
var
  LReader: TBlockedReader;
  LStream: TSincResampleStream;
  LReferenceReader: TBlockedReader;
  LReference: TSincResampleStream;
  LSamples: TAudioSamples;
  LFrames: Integer;
  LFrame: Integer;
  LLeft: Double;
  LRight: Double;
  LReferenceLeft: Double;
  LReferenceRight: Double;
begin
  LFrames := (Int64(ASource.FrameCount) * AOutputRate + ASource.SampleRate - 1) div
    ASource.SampleRate;
  SetLength(LSamples, LFrames * ASource.Channels);
  LReader := TBlockedReader.Create(ASource, AInputBlockFrames);
  LStream := nil;
  LReferenceReader := nil;
  LReference := nil;
  try
    LStream := TSincResampleStream.Create(LReader, AOutputRate);
    LReferenceReader := TBlockedReader.Create(ASource, 23);
    LReference := TSincResampleStream.Create(LReferenceReader, AOutputRate, 0);
    Check((LReference.KernelCacheWeights = 0) and
      (LStream.KernelCacheWeights <= MaximumStreamKernelWeights), 'Kernel cache obeys caller memory budget');
    if (ASource.SampleRate = 48000) and (AOutputRate = 16000) then
    begin
      Check((LStream.KernelCachePhases = 1) and
        (LStream.KernelCacheWeights = LStream.HistoryFrames), 'Integer decimation reuses one exact phase');
    end;
    if (ASource.SampleRate = 16000) and (AOutputRate = 16001) then
    begin
      Check(LStream.KernelCachePhases = 0, 'Oversized rational phase table uses bounded uncached fallback');
    end;
    Check(LStream.HistoryFrames <= 8717, 'Fixed bounded history at all supported rates');
    LFrame := 0;
    while LStream.ReadFrame(LLeft, LRight) do
    begin
      Check(LReference.ReadFrame(LReferenceLeft, LReferenceRight) and
        (LLeft = LReferenceLeft) and (LRight = LReferenceRight),
        'Cached and uncached kernels preserve exact Double output across source blocks');
      Check(LFrame < LFrames, 'No extra tail beyond ceiling duration');
      LSamples[LFrame * ASource.Channels] := LLeft;
      if ASource.Channels = 2 then
      begin
        Check(LRight = -LLeft, 'Opposite-polarity stereo history');
        LSamples[LFrame * 2 + 1] := LRight;
      end;
      Inc(LFrame);
      Check(LStream.InputFrameCount <=
        (Int64(LFrame - 1) * ASource.SampleRate) div AOutputRate +
        LStream.LookaheadFrames + 1, 'Input consumption bounded by centered lookahead');
    end;
    Check((LFrame = LFrames) and LStream.Completed and not LStream.Failed and
      (LStream.InputFrameCount = ASource.FrameCount) and
      (LStream.OutputFrameCount = LFrames), 'Exact ceiling output and drained EOF');
    Check(not LReference.ReadFrame(LReferenceLeft, LReferenceRight), 'Uncached reference has the same EOF');
    LLeft := 123;
    LRight := -456;
    Check(not LStream.ReadFrame(LLeft, LRight) and (LLeft = 123) and
      (LRight = -456), 'Repeated EOF preserves outputs');
  finally
    LReference.Free;
    LReferenceReader.Free;
    LStream.Free;
    LReader.Free;
  end;
  Result := TAudioClip.Create(AOutputRate, ASource.Channels, LSamples);
end;

procedure CheckRate(const AInputRate, AOutputRate, AFrames, AChannels: Integer;
  const AFrequency: Double);
var
  LSamples: TAudioSamples;
  LSource: TAudioClip;
  LWhole: TAudioClip;
  LSplit: TAudioClip;
  LOffline: TAudioClip;
  LIndex: Integer;
  LChannel: Integer;
  LError: Double;
  LPower: Double;
  LCount: Integer;
begin
  SetLength(LSamples, AFrames * AChannels);
  for LIndex := 0 to AFrames - 1 do
  begin
    LSamples[LIndex * AChannels] := 0.5 * Cos(2 * Pi * AFrequency * LIndex / AInputRate);
    if AChannels = 2 then
    begin
      LSamples[LIndex * 2 + 1] := -LSamples[LIndex * 2];
    end;
  end;
  LSource := TAudioClip.Create(AInputRate, AChannels, LSamples);
  LWhole := nil;
  LSplit := nil;
  LOffline := nil;
  try
    LWhole := StreamClip(LSource, AOutputRate, Max(1, AFrames));
    LSplit := StreamClip(LSource, AOutputRate, 17);
    LOffline := ResampleClip(LSource, AOutputRate);
    LError := 0;
    LPower := 0;
    LCount := 0;
    for LIndex := 0 to LWhole.FrameCount - 1 do
    begin
      for LChannel := 0 to AChannels - 1 do
      begin
        Check(LWhole.SampleAt(LIndex, LChannel) = LSplit.SampleAt(LIndex, LChannel),
          'Input block boundaries do not change any output sample');
        LError := Max(LError, Abs(LWhole.SampleAt(LIndex, LChannel) -
          LOffline.SampleAt(LIndex, LChannel)));
      end;
      if (LIndex > 256) and (LIndex < LWhole.FrameCount - 256) then
      begin
        LPower := LPower + Sqr(LWhole.SampleAt(LIndex, 0));
        Inc(LCount);
        if (AInputRate = 48000) and (AOutputRate = 16000) and (AFrequency = 1000) then
        begin
          Check(Abs(LWhole.SampleAt(LIndex, 0) -
            0.5 * Cos(2 * Pi * 1000 * LIndex / AOutputRate)) < 2E-6,
            'Independent in-band phase/amplitude oracle');
        end;
      end;
    end;
    Check(LError < 1E-6, 'Shared offline kernel agreement within phase rounding');
    if (AInputRate = 48000) and (AOutputRate = 16000) and (AFrequency = 9000) then
    begin
      Check((LCount > 0) and (Sqrt(LPower / LCount) < 1E-4),
        'Independent above-destination-Nyquist rejection');
    end;
    if (AInputRate = AOutputRate) or (AFrequency = 0) then
    begin
      for LIndex := 0 to LWhole.FrameCount - 1 do
      begin
        Check(LWhole.SampleAt(LIndex, 0) = LSource.SampleAt(
          Min(LIndex, AFrames - 1), 0), 'Identity or constant endpoint extension');
      end;
    end;
    WriteLn(AInputRate, ' -> ', AOutputRate, ' frames=', LWhole.FrameCount,
      ' max_offline_difference=', LError:0:10);
  finally
    LOffline.Free;
    LSplit.Free;
    LWhole.Free;
    LSource.Free;
  end;
end;

procedure CheckWaveInput;
var
  LSamples: TAudioSamples;
  LBytes: TAudioBytes;
  LClip: TAudioClip;
  LMemory: TMemoryStream;
  LWave: TWaveFrameReader;
  LReader: TWavePcmReader;
  LLeft, LRight: Double;
  LBlock, I: Integer;
  LRejected: Boolean;
begin
  SetLength(LSamples, 22);
  for I := 0 to 10 do
  begin
    LSamples[I * 2] := I / 32;
    LSamples[I * 2 + 1] := -LSamples[I * 2];
  end;
  LClip := TAudioClip.Create(16000, 2, LSamples);
  try
    LBytes := EncodeWavePcm16(LClip);
  finally
    LClip.Free;
  end;
  LMemory := TMemoryStream.Create;
  LWave := nil;
  try
    LMemory.WriteBuffer(LBytes[0], Length(LBytes));
    LMemory.Position := 0;
    LWave := TWaveFrameReader.Create(LMemory);
    for LBlock := 1 to 7 do
    begin
      LWave.SeekFrame(3);
      LReader := TWavePcmReader.Create(LWave, LBlock);
      try
        for I := 3 to 10 do
        begin
          Check(LReader.ReadFrame(LLeft, LRight), 'WAVE adapter starts at borrowed position');
          Check((Abs(LLeft - I / 32) < 1 / 32768) and
            (Abs(LRight + I / 32) < 1 / 32768), 'Stereo decode across uneven blocks');
        end;
        Check(not LReader.ReadFrame(LLeft, LRight), 'WAVE adapter exact EOF');
        Check(Abs(LReader.Peak - 10 / 32) < 1 / 32768, 'WAVE adapter consumed peak');
      finally
        LReader.Free;
      end;
    end;
    LWave.SeekFrame(0);
    LReader := TWavePcmReader.Create(LWave, 7);
    try
      Check(LReader.ReadFrame(LLeft, LRight), 'Initial buffered read');
      LWave.SeekFrame(0);
      for I := 1 to 2 do
      begin
        LRejected := False;
        try
          LReader.ReadFrame(LLeft, LRight);
        except
          on EAudio do LRejected := True;
        end;
        Check(LRejected, 'Borrowed position mutation poisons subsequent reads');
      end;
    finally
      LReader.Free;
    end;
  finally
    LWave.Free;
    LMemory.Free;
  end;
end;

procedure CheckFrameCounts;
var
  LRejected: Boolean;
begin
  Check(StreamResampleFrameCount(0, 48000, 16000) = 0, 'Empty duration');
  Check(StreamResampleFrameCount(4, 48000, 16000) = 2, 'Partial output frame ceiling');
  Check(StreamResampleFrameCount(High(Int64), 48000, 48000) = High(Int64),
    'Exact huge identity without intermediate overflow');
  Check(StreamResampleFrameCount(High(Int64), 2, 1) = High(Int64) div 2 + 1,
    'Exact huge odd downsample');
  LRejected := False;
  try
    StreamResampleFrameCount(High(Int64), 1, 2);
  except
    on EAudio do LRejected := True;
  end;
  Check(LRejected, 'Unrepresentable output duration rejects');
end;

procedure CheckFailure;
var
  LSamples: TAudioSamples;
  LSource: TAudioClip;
  LReader: TBlockedReader;
  LStream: TSincResampleStream;
  LLeft: Double;
  LRight: Double;
  LReads: Integer;
  LRejected: Boolean;
  LCase: Integer;
begin
  SetLength(LSamples, 256);
  LSource := TAudioClip.Create(48000, 1, LSamples);
  try
    for LCase := 0 to 3 do
    begin
      LReader := TBlockedReader.Create(LSource, 7);
      LStream := nil;
      try
        LStream := TSincResampleStream.Create(LReader, 44100);
        if LCase = 0 then
        begin
          LReader.FailAt := 10;
        end
        else if LCase = 1 then
        begin
          LReader.Reenter := LStream;
        end
        else
        begin
          LReader.Inject := True;
          if LCase = 2 then
          begin
            LReader.InjectedValue := NaN;
          end
          else
          begin
            LReader.InjectedValue := MaxSingle;
            LReader.InjectedValue := LReader.InjectedValue * 2;
          end;
        end;
        LLeft := 123;
        LRight := -456;
        LRejected := False;
        try
          LStream.ReadFrame(LLeft, LRight);
        except
          on EAudio do
          begin
            LRejected := True;
          end;
        end;
        Check(LRejected and LStream.Failed and (LStream.OutputFrameCount = 0) and
          (LLeft = 123) and (LRight = -456), 'Input failure/value/reentrancy poisons before output');
        LReads := LReader.Reads;
        LRejected := False;
        try
          LStream.ReadFrame(LLeft, LRight);
        except
          on EAudio do
          begin
            LRejected := True;
          end;
        end;
        Check(LRejected and (LReader.Reads = LReads), 'Poisoned converter never consumes again');
      finally
        LStream.Free;
        LReader.Free;
      end;
    end;
  finally
    LSource.Free;
  end;
end;

begin
  try
    CheckFrameCounts;
    CheckWaveInput;
    CheckRate(48000, 16000, 8192, 2, 1000);
    CheckRate(48000, 16000, 8192, 1, 9000);
    CheckRate(44100, 48000, 5000, 2, 1000);
    CheckRate(16000, 16001, 513, 2, 1000);
    CheckRate(12000, 48000, 1024, 1, 1000);
    CheckRate(48000, 48000, 1024, 2, 1000);
    CheckRate(64000, 1000, 1000, 1, 0);
    CheckRate(44100, 48000, 1, 1, 0);
    CheckRate(48000, 16000, 0, 1, 0);
    CheckFailure;
    WriteLn('Continuous sinc history, endpoints, signal, bounded reads and poison checks passed');
  except
    on LException: Exception do
    begin
      WriteLn(StdErr, LException.ClassName, ': ', LException.Message);
      Halt(1);
    end;
  end;
end.
