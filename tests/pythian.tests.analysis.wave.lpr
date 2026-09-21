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

program pythian_tests_analysis_wave;

{$mode delphi}
{$H+}

uses
  Classes,
  SysUtils,
  Math,
  pythian.audio,
  pythian.analysis,
  pythian.analysis.wave,
  pythian.wave,
  pythian.wave.read,
  pythian.wave.stream;

type
  TLongZeroStream = class(TStream)
  private
    FHeader: TMemoryStream;
    FPosition: Int64;
    FSize: Int64;
  public
    constructor Create(const AFrames: Int64);
    destructor Destroy; override;
    function Read(var ABuffer; ACount: LongInt): LongInt; override;
    function Write(const ABuffer; ACount: LongInt): LongInt; override;
    function Seek(const AOffset: Int64; AOrigin: TSeekOrigin): Int64; override;
  end;

  ESourceFailure = class(Exception);
  TCountStream = class(TMemoryStream)
  public
    BytesRead: Integer;
    FailAt: Int64;
    function Read(var ABuffer; ACount: LongInt): LongInt; override;
  end;

  TInvalidSource = class(TAudioAnalysisSource)
  public
    NonFinite: Boolean;
    procedure ReadWindow(const AStartFrame, AValidFrames: Integer;
      var ASamples: TAudioSamples); override;
  end;

procedure Check(const ACondition: Boolean; const AMessage: String);
begin
  if not ACondition then
  begin
    raise Exception.Create(AMessage);
  end;
end;

constructor TLongZeroStream.Create(const AFrames: Int64);
var
  LSink: TStreamAudioSink;
  LWriter: TWavePcm16Writer;
begin
  inherited Create;
  FHeader := TMemoryStream.Create;
  LSink := TStreamAudioSink.Create(FHeader);
  try
    LWriter := TWavePcm16Writer.Create(LSink, 8000, 1, AFrames);
    LWriter.Free; { Virtual zero payload is supplied by Read. }
  finally
    LSink.Free;
  end;
  FSize := FHeader.Size + AFrames * 2;
end;

destructor TLongZeroStream.Destroy;
begin
  FHeader.Free;
  inherited Destroy;
end;

function TLongZeroStream.Read(var ABuffer; ACount: LongInt): LongInt;
begin
  Result := Min(Int64(ACount), FSize - FPosition);
  if FPosition < FHeader.Size then
  begin
    Result := Min(Int64(Result), FHeader.Size - FPosition);
    FHeader.Position := FPosition;
    Result := FHeader.Read(ABuffer, Result);
  end
  else if Result > 0 then
  begin
    FillChar(ABuffer, Result, 0);
  end;
  Inc(FPosition, Result);
end;

function TLongZeroStream.Write(const ABuffer; ACount: LongInt): LongInt;
begin
  Result := 0;
  raise EAudio.Create('Virtual source is read-only');
end;

function TLongZeroStream.Seek(const AOffset: Int64; AOrigin: TSeekOrigin): Int64;
begin
  Result := FPosition;
  case AOrigin of
    soBeginning: Result := AOffset;
    soCurrent: Result := FPosition + AOffset;
    soEnd: Result := FSize + AOffset;
  end;
  if (Result < 0) or (Result > FSize) then
  begin
    raise EAudio.Create('Virtual seek outside source');
  end;
  FPosition := Result;
end;

function TCountStream.Read(var ABuffer; ACount: LongInt): LongInt;
begin
  if (FailAt > 0) and (Position >= FailAt) then
  begin
    raise ESourceFailure.Create('Deliberate analysis input failure');
  end;
  if ACount > 13 then
  begin
    ACount := 13;
  end;
  Result := inherited Read(ABuffer, ACount);
  Inc(BytesRead, Result);
end;

procedure TInvalidSource.ReadWindow(const AStartFrame, AValidFrames: Integer;
  var ASamples: TAudioSamples);
var
  LBits: Cardinal;
begin
  SetLength(ASamples, AValidFrames);
  FillChar(ASamples[0], Length(ASamples) * SizeOf(Single), 0);
  if NonFinite then
  begin
    LBits := $7F800000;
    Move(LBits, ASamples[0], SizeOf(LBits));
  end
  else
  begin
    SetLength(ASamples, AValidFrames - 1);
  end;
end;

procedure SameFeatures(const ALeft, ARight: TAudioFeatures);
var
  LIndex: Integer;
  LPitch: Integer;
begin
  Check(Length(ALeft) = Length(ARight), 'Feature count parity');
  for LIndex := 0 to High(ALeft) do
  begin
    Check((ALeft[LIndex].StartFrame = ARight[LIndex].StartFrame) and
      (ALeft[LIndex].ValidFrames = ARight[LIndex].ValidFrames) and
      (ALeft[LIndex].Rms = ARight[LIndex].Rms) and
      (ALeft[LIndex].Peak = ARight[LIndex].Peak) and
      (ALeft[LIndex].CentroidHz = ARight[LIndex].CentroidHz) and
      (ALeft[LIndex].Flux = ARight[LIndex].Flux) and
      (ALeft[LIndex].Silent = ARight[LIndex].Silent), 'Exact feature field parity');
    for LPitch := 0 to 11 do
    begin
      Check(ALeft[LIndex].Chroma[LPitch] = ARight[LIndex].Chroma[LPitch],
        'Exact chroma parity');
    end;
  end;
end;

procedure CheckBatches(const AReader: TWaveFrameReader;
  const AOptions: TAnalysisOptions; const AExpected: TAudioFeatures);
var
  LBatch: TWaveFeatureBatch;
  LActual: TAudioFeatures;
  LNext: Int64;
  LSize: Integer;
  LIndex: Integer;
  LPosition: Integer;
begin
  for LSize in [1, 7, 31] do
  begin
    SetLength(LActual, Length(AExpected));
    LNext := 0;
    repeat
      AReader.SeekFrame(0); { No in-memory history is required to resume. }
      LBatch := AnalyzeWaveBatch(AReader, AOptions, LNext, LSize);
      Check((LBatch.FirstFeature = LNext) and
        (Length(LBatch.Features) <= LSize), 'Batch identity and bound');
      for LIndex := 0 to High(LBatch.Features) do
      begin
        LPosition := LNext + LIndex;
        LActual[LPosition] := LBatch.Features[LIndex];
        LActual[LPosition].StartFrame := LBatch.SourceStartFrame +
          LBatch.Features[LIndex].StartFrame;
      end;
      Check(LBatch.NextFeature = LNext + Length(LBatch.Features),
        'Context observation never counted twice');
      LNext := LBatch.NextFeature;
    until LBatch.Completed;
    Check(LNext = Length(AExpected), 'Complete observation coverage');
    SameFeatures(AExpected, LActual);
    LBatch := AnalyzeWaveBatch(AReader, AOptions, LNext, LSize);
    Check(LBatch.Completed and (Length(LBatch.Features) = 0) and
      (LBatch.NextFeature = LNext), 'Repeated completed resume is empty');
  end;
end;

procedure CheckLongCoordinates;
const
  CFrames = Int64(High(Integer)) + 123;
var
  LStream: TLongZeroStream;
  LReader: TWaveFrameReader;
  LOptions: TAnalysisOptions;
  LBatch: TWaveFeatureBatch;
  LBandBatch: TWaveBandFeatureBatch;
  LFirst: Int64;
  LRejected: Boolean;
begin
  LStream := TLongZeroStream.Create(CFrames);
  try
    LReader := TWaveFrameReader.Create(LStream);
    try
      LOptions := DefaultAnalysisOptions;
      LOptions.WindowFrames := 128;
      LOptions.HopFrames := 64;
      LFirst := CFrames div 64;
      LBatch := AnalyzeWaveBatch(LReader, LOptions, LFirst, 7);
      Check((LBatch.SourceStartFrame > High(Integer)) and LBatch.Completed and
        (Length(LBatch.Features) = 1) and (LBatch.NextFeature = LFirst + 1),
        'RF64 batch beyond 32-bit source coordinates');
      Check((LBatch.Features[0].ValidFrames = CFrames mod 64) and
        (LBatch.Features[0].Flux = 0) and LBatch.Features[0].Silent,
        'Real EOF tail remains unpadded in valid count');
      LBandBatch := AnalyzeWaveBandBatch(LReader, LOptions,
        TAnalysisBandEdges.Create(0, 250, 2000, 4000), LFirst, 7);
      Check((LBandBatch.Batch.SourceStartFrame = LBatch.SourceStartFrame) and
        LBandBatch.Batch.Completed and (Length(LBandBatch.Bands[2].PositiveFlux) = 1) and
        (LBandBatch.Bands[2].PositiveFlux[0] = 0), 'RF64 bands beyond 32-bit coordinates');
      LRejected := False;
      try
        LBatch := AnalyzeWaveBatch(LReader, LOptions, LFirst + 2, 7);
      except
        on EAudio do LRejected := True;
      end;
      Check(LRejected and LBatch.Completed and (Length(LBatch.Features) = 1),
        'Rejected resume preserves accepted result');
    finally
      LReader.Free;
    end;
  finally
    LStream.Free;
  end;
end;

procedure CheckBands;
const
  CBinCounts: array[0..2] of Integer = (4, 28, 33);
var
  LSamples: TAudioSamples;
  LClip: TAudioClip;
  LBytes: TAudioBytes;
  LStream: TCountStream;
  LReader: TWaveFrameReader;
  LOptions: TAnalysisOptions;
  LEdges: TAnalysisBandEdges;
  LWhole: TAudioBandAnalysis;
  LBatch: TWaveBandFeatureBatch;
  LBand: Integer;
  LIndex: Integer;
  LNext: Int64;
  LSum: Double;
  LRejected: Boolean;
begin
  SetLength(LSamples, 600);
  LSamples[128] := 0.5;
  LSamples[129] := -0.5;
  LSamples[384] := 1;
  LSamples[385] := -1;
  LEdges := TAnalysisBandEdges.Create(0, 250, 2000, 4000);
  LOptions := DefaultAnalysisOptions;
  LOptions.WindowFrames := 128;
  LOptions.HopFrames := 128;
  LClip := TAudioClip.Create(8000, 2, LSamples);
  try
    LWhole := AnalyzeAudioBands(LClip, LOptions, LEdges);
    SameFeatures(AnalyzeAudio(LClip, LOptions), LWhole.Features);
    for LBand := 0 to 2 do
    begin
      { A centered impulse has constant FFT magnitude; periodic Hann is one
        at this sample. Antiphase channels must not cancel. }
      Check(Abs(LWhole.Bands[LBand].Magnitude[0] - 0.5 * CBinCounts[LBand]) < 1E-12,
        'Independent impulse spectrum and band-edge assignment');
      Check(Abs(LWhole.Bands[LBand].PositiveFlux[0] - CBinCounts[LBand] / 65) < 1E-12,
        'Full-spectrum normalized band flux');
      Check(Abs(LWhole.Bands[LBand].PositiveFlux[1] - CBinCounts[LBand] / 130) < 1E-12,
        'Rising impulse compares preceding spectrum');
    end;
    for LIndex := 0 to High(LWhole.Features) do
    begin
      LSum := 0;
      for LBand := 0 to 2 do
      begin
        LSum := LSum + LWhole.Bands[LBand].PositiveFlux[LIndex];
      end;
      Check(Abs(LSum - LWhole.Features[LIndex].Flux) < 1E-12,
        'Band partition sums to aggregate flux including silent tail');
    end;
    LBytes := EncodeWavePcm16(LClip);
  finally
    LClip.Free;
  end;
  { Quantization is outside the band contract; compare batch to decoded PCM. }
  LClip := DecodeWave(LBytes);
  LStream := TCountStream.Create;
  try
    LWhole := AnalyzeAudioBands(LClip, LOptions, LEdges);
    LStream.WriteBuffer(LBytes[0], Length(LBytes));
    LStream.Position := 0;
    LReader := TWaveFrameReader.Create(LStream);
    try
      LNext := 0;
      repeat
        LReader.SeekFrame(0);
        LBatch := AnalyzeWaveBandBatch(LReader, LOptions, LEdges, LNext, 1);
        Check((Length(LBatch.Batch.Features) = 1) and
          (LBatch.Batch.SourceStartFrame = LNext * 128), 'Bounded band batch coordinates');
        for LBand := 0 to 2 do
        begin
          Check((LBatch.Bands[LBand].Magnitude[0] = LWhole.Bands[LBand].Magnitude[LNext]) and
            (LBatch.Bands[LBand].PositiveFlux[0] = LWhole.Bands[LBand].PositiveFlux[LNext]),
            'Exact resumed band values including predecessor context');
        end;
        LNext := LBatch.Batch.NextFeature;
      until LBatch.Batch.Completed;
      LStream.BytesRead := 0;
      LBatch := AnalyzeWaveBandBatch(LReader, LOptions, LEdges, LNext, 1);
      Check(LBatch.Batch.Completed and (Length(LBatch.Bands) = 3) and
        (Length(LBatch.Bands[0].Magnitude) = 0) and (LStream.BytesRead = 0),
        'Empty completed band batch preserves metadata without reads');
      for LIndex := 0 to 3 do
      begin
        LEdges := TAnalysisBandEdges.Create(0, 250, 2000, 4000);
        case LIndex of
          0: LEdges[1] := 0;
          1: LEdges[3] := 4001;
          2: LEdges[1] := NaN;
          3: SetLength(LEdges, MaximumAnalysisBands + 2);
        end;
        LRejected := False;
        try
          LBatch := AnalyzeWaveBandBatch(LReader, LOptions, LEdges, 0, 1);
        except
          on EAudio do LRejected := True;
        end;
        Check(LRejected and LBatch.Batch.Completed and (LStream.BytesRead = 0),
          'Invalid bands preserve assigned result and reject before reads');
      end;
    finally
      LReader.Free;
    end;
  finally
    LStream.Free;
    LClip.Free;
  end;
  WriteLn('Spectral bands: analytic bins/flux, stereo, bounded resume and rejection pass');
end;

procedure Run;
var
  LSamples: TAudioSamples;
  LBytes: TAudioBytes;
  LClip: TAudioClip;
  LDecoded: TAudioClip;
  LStream: TCountStream;
  LReader: TWaveFrameReader;
  LOptions: TAnalysisOptions;
  LExpected: TAudioFeatures;
  LActual: TAudioFeatures;
  LIndex: Integer;
  LHop: Integer;
  LRejected: Boolean;
  LBad: TInvalidSource;
begin
  CheckBands;
  CheckLongCoordinates;
  SetLength(LSamples, 1001 * 2);
  for LIndex := 0 to 1000 do
  begin
    LSamples[LIndex * 2] := 0;
    if LIndex < 400 then
    begin
      LSamples[LIndex * 2] := 0.5 * Sin(2 * Pi * 440 * LIndex / 8000);
    end;
    LSamples[LIndex * 2 + 1] := -LSamples[LIndex * 2];
  end;
  LSamples[1600] := 0.75;
  LClip := TAudioClip.Create(8000, 2, LSamples);
  try
    LBytes := EncodeWavePcm16(LClip);
  finally
    LClip.Free;
  end;
  LDecoded := DecodeWave(LBytes);
  LStream := TCountStream.Create;
  try
    LStream.WriteBuffer(LBytes[0], Length(LBytes));
    LStream.Position := 0;
    LReader := TWaveFrameReader.Create(LStream);
    try
      LOptions := DefaultAnalysisOptions;
      LOptions.WindowFrames := 128;
      for LHop in [1, 47, 128] do
      begin
        LOptions.HopFrames := LHop;
        LExpected := AnalyzeAudio(LDecoded, LOptions);
        LReader.SeekFrame(300);
        LStream.BytesRead := 0;
        LActual := AnalyzeWave(LReader, LOptions);
        SameFeatures(LExpected, LActual);
        Check(LReader.FramePosition = 1001, 'Analysis consumes full audio from zero');
        Check(LStream.BytesRead = 1001 * 4, 'Overlapping samples read only once');
        Check(LActual[0].Rms > 0.1, 'Antiphase stereo retains energy');
        CheckBatches(LReader, LOptions, LExpected);
      end;
      LReader.SeekFrame(7);
      LOptions.HopFrames := 0;
      LRejected := False;
      try
        LActual := AnalyzeWave(LReader, LOptions);
      except
        on EAudio do LRejected := True;
      end;
      Check(LRejected and (LReader.FramePosition = 7), 'Invalid plan preserves reader');
      SameFeatures(LExpected, LActual);
      LOptions.HopFrames := 47;
      LStream.FailAt := 44 + 128 * 4 + 26;
      LRejected := False;
      try
        LActual := AnalyzeWave(LReader, LOptions);
      except
        on ESourceFailure do LRejected := True;
      end;
      Check(LRejected and LReader.Failed and (LReader.FramePosition = 128),
        'Late source failure preserves last confirmed reader position');
      SameFeatures(LExpected, LActual);
    finally
      LReader.Free;
    end;
    Check(LStream.Size = Length(LBytes), 'Reader borrows stream');
  finally
    LStream.Free;
    LDecoded.Free;
  end;
  LBad := TInvalidSource.Create(8000, 1, 64);
  try
    LOptions.WindowFrames := 64;
    LOptions.HopFrames := 64;
    for LIndex := 0 to 1 do
    begin
      LBad.NonFinite := LIndex = 1;
      LRejected := False;
      try
        LActual := AnalyzeAudioSource(LBad, LOptions);
      except
        on EAudio do LRejected := True;
      end;
      Check(LRejected, 'Reject invalid custom source window');
      SameFeatures(LExpected, LActual);
    end;
  finally
    LBad.Free;
  end;
  WriteLn('WAV window analysis exact parity, overlap reuse and failure checks pass');
end;

procedure CompareWaveFiles(const AReference, ACandidate: String);
var
  LClip: TAudioClip;
  LStream: TFileStream;
  LReader: TWaveFrameReader;
  LOptions: TAnalysisOptions;
begin
  LClip := nil;
  LStream := nil;
  LReader := nil;
  try
    LClip := LoadWave(AReference);
    LStream := TFileStream.Create(ACandidate, fmOpenRead or fmShareDenyWrite);
    LReader := TWaveFrameReader.Create(LStream);
    Check((LReader.SampleRate = LClip.SampleRate) and (LReader.Channels = LClip.Channels) and
      (LReader.FrameCount = LClip.FrameCount), 'Comparison source geometry');
    LOptions := DefaultAnalysisOptions;
    SameFeatures(AnalyzeAudio(LClip, LOptions), AnalyzeWave(LReader, LOptions));
    WriteLn('Reference clip and candidate WAV have identical measured features');
  finally
    LReader.Free;
    LStream.Free;
    LClip.Free;
  end;
end;

begin
  try
    Run;
    if ParamCount = 2 then
    begin
      CompareWaveFiles(ParamStr(1), ParamStr(2));
    end
    else if ParamCount <> 0 then
    begin
      raise EAudio.Create('Optional usage: pythian.tests.analysis.wave REFERENCE.wav CANDIDATE.wav');
    end;
  except
    on LException: Exception do
    begin
      WriteLn(StdErr, LException.ClassName, ': ', LException.Message);
      Halt(1);
    end;
  end;
end.
