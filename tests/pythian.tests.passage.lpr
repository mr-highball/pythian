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
program pythian_tests_passage;

{$mode delphi}
{$H+}

uses
  SysUtils,
  Math,
  pythian.audio,
  pythian.wave,
  pythian.passage,
  pythian.analysis,
  pythian.corpus,
  pythian.granular,
  pythian.tests.corpus.fixture;

procedure Check(const AValue: Boolean; const AMessage: String);
begin
  if not AValue then
  begin
    raise Exception.Create(AMessage);
  end;
end;

procedure PutNumber(var ABytes: TAudioBytes; const AOffset: Integer;
  const AValue: Cardinal);
var
  LIndex: Integer;
begin
  for LIndex := 0 to 3 do
  begin
    ABytes[AOffset + LIndex] := (AValue shr (8 * LIndex)) and $FF;
  end;
end;

function AcidFixture: TAudioBytes;
const
  CHeader: AnsiString = 'RIFF';
  CWave: AnsiString = 'WAVEacid';
var
  LIndex: Integer;
begin
  Result := nil;
  SetLength(Result, 44);
  for LIndex := 1 to 4 do
  begin
    Result[LIndex - 1] := Ord(CHeader[LIndex]);
  end;
  for LIndex := 1 to 8 do
  begin
    Result[LIndex + 7] := Ord(CWave[LIndex]);
  end;
  PutNumber(Result, 4, 36);
  PutNumber(Result, 16, 24);
  PutNumber(Result, 24, 60);
  PutNumber(Result, 32, 80);
  PutNumber(Result, 36, $00040004);
  PutNumber(Result, 40, $430C0000);
end;

procedure RejectMetadata(const ABytes: TAudioBytes);
var
  LRejected: Boolean;
begin
  LRejected := False;
  try
    ReadWaveLoopInfo(ABytes);
  except
    on EAudio do
    begin
      LRejected := True;
    end;
  end;
  Check(LRejected, 'Malformed metadata admitted');
end;

procedure RejectGrid(const AInfo: TWaveLoopInfo; const AFrames: Integer);
var
  LRejected: Boolean;
begin
  LRejected := False;
  try
    LoopBarBounds(AInfo, AFrames, 44100);
  except
    on EAudio do
    begin
      LRejected := True;
    end;
  end;
  Check(LRejected, 'Invalid musical grid admitted');
end;

procedure CheckMetadata;
var
  LBytes: TAudioBytes;
  LInfo: TWaveLoopInfo;
  LBounds: TPassageBounds;
  LIndex: Integer;
begin
  LBytes := AcidFixture;
  LInfo := ReadWaveLoopInfo(LBytes);
  Check(LInfo.Found and (LInfo.Flags = 0) and (LInfo.RootNote = 60) and
    (LInfo.BeatCount = 80) and (LInfo.MeterNumerator = 4) and
    (LInfo.MeterDenominator = 4) and (LInfo.TempoBpm = 140), 'ACID fields');
  LBounds := LoopBarBounds(LInfo, 1512000, 44100);
  Check(Length(LBounds) = 21, 'Twenty full bars');
  for LIndex := 0 to 20 do
  begin
    Check(LBounds[LIndex] = LIndex * 75600, 'Exact bar boundary');
  end;
  RejectGrid(LInfo, 1512100);
  LInfo.Flags := 1;
  RejectGrid(LInfo, 1512000);
  LInfo.Flags := 0;
  LInfo.BeatCount := 79;
  RejectGrid(LInfo, 1512000);
  LInfo.BeatCount := 12;
  LInfo.MeterNumerator := 6;
  LInfo.MeterDenominator := 8;
  LInfo.TempoBpm := 120;
  LBounds := LoopBarBounds(LInfo, 132300, 44100);
  Check((Length(LBounds) = 3) and (LBounds[1] = 66150), '6/8 meter beat unit');
  LBounds := LoopBarBounds(LInfo, 132301, 44100);
  Check((LBounds[1] = 66150) and (LBounds[2] = 132301),
    'Fractional bar boundaries retain exact source end');
  LInfo.MeterDenominator := 3;
  RejectGrid(LInfo, 132300);

  PutNumber(LBytes, 40, $7F800000);
  RejectMetadata(LBytes);
  PutNumber(LBytes, 40, $7FC00000);
  RejectMetadata(LBytes);
  LBytes := AcidFixture;
  SetLength(LBytes, 54);
  LBytes[44] := Ord('J');
  LBytes[45] := Ord('U');
  LBytes[46] := Ord('N');
  LBytes[47] := Ord('K');
  PutNumber(LBytes, 48, 1);
  PutNumber(LBytes, 4, 46);
  LInfo := ReadWaveLoopInfo(LBytes);
  Check(LInfo.Found, 'Padded odd unknown chunk');
  SetLength(LBytes, 53);
  PutNumber(LBytes, 4, 45);
  RejectMetadata(LBytes);
  LBytes := AcidFixture;
  SetLength(LBytes, 76);
  Move(LBytes[12], LBytes[44], 32);
  PutNumber(LBytes, 4, 68);
  RejectMetadata(LBytes);
  LBytes := AcidFixture;
  SetLength(LBytes, 42);
  PutNumber(LBytes, 4, 34);
  PutNumber(LBytes, 16, 22);
  RejectMetadata(LBytes);
  LBytes := AcidFixture;
  SetLength(LBytes, 43);
  PutNumber(LBytes, 4, 35);
  RejectMetadata(LBytes);
  LBytes := AcidFixture;
  SetLength(LBytes, 12);
  PutNumber(LBytes, 4, 4);
  LInfo := ReadWaveLoopInfo(LBytes);
  Check(not LInfo.Found, 'Absent metadata');
  RejectGrid(LInfo, 1512000);
end;

procedure CheckRendering;
var
  LSamples: TAudioSamples;
  LSource: TAudioClip;
  LOutput: TAudioClip;
  LBounds: TPassageBounds;
  LIndices: TPassageIndices;
  LFrame: Integer;
  LChannel: Integer;
  LRejected: Boolean;
begin
  SetLength(LSamples, 48);
  for LFrame := 0 to 23 do
  begin
    LSamples[LFrame * 2] := (LFrame + 1) / 32;
    LSamples[LFrame * 2 + 1] := -LSamples[LFrame * 2];
  end;
  LSource := TAudioClip.Create(8000, 2, LSamples);
  try
    LBounds := TPassageBounds.Create(0, 8, 16, 24);
    LIndices := TPassageIndices.Create(0, 1, 2);
    LOutput := RenderPassages(LSource, LBounds, LIndices, 0);
    try
      for LFrame := 0 to 23 do
      begin
        for LChannel := 0 to 1 do
        begin
          Check(LOutput.SampleAt(LFrame, LChannel) =
            LSource.SampleAt(LFrame, LChannel), 'Unity full-source reconstruction');
        end;
      end;
    finally
      LOutput.Free;
    end;
    LIndices := TPassageIndices.Create(1, 2, 0, 0);
    LOutput := RenderPassages(LSource, LBounds, LIndices, 2);
    try
      Check(LOutput.FrameCount = 32, 'Repeated passage extent');
      Check(LOutput.SampleAt(7, 0) = LSource.SampleAt(15, 0), 'Contiguous join left');
      Check(LOutput.SampleAt(8, 0) = LSource.SampleAt(16, 0), 'Contiguous join right');
      Check((LOutput.SampleAt(15, 0) = 0) and
        (LOutput.SampleAt(16, 0) = 0), 'Jump edges fade inside bars');
      Check(LOutput.SampleAt(18, 1) = LSource.SampleAt(2, 1), 'Stereo interior');
      LIndices[0] := 3;
      LRejected := False;
      try
        RenderPassages(LSource, LBounds, LIndices, 0).Free;
      except
        on EAudio do
        begin
          LRejected := True;
        end;
      end;
      Check(LRejected and (LOutput.FrameCount = 32), 'Invalid index preserves prior clip');
    finally
      LOutput.Free;
    end;
  finally
    LSource.Free;
  end;
end;

procedure CheckMeasurements;
var
  LSources: TAudioSources;
  LCorpus: TAcousticCorpusData;
  LRecording: TAcousticRecording;
  LFeatures: TAudioFeatures;
  LExpected: Double;
begin
  LCorpus := CreateCorpusFixture(LSources);
  try
    LRecording := LCorpus.RecordingAt(0);
    LFeatures := MeasurePassages(LCorpus, 0, TPassageBounds.Create(16, 48, 256));
    LExpected := Sqrt((Sqr(LRecording.Features[0].Rms) +
      Sqr(LRecording.Features[1].Rms)) / 2);
    Check(Abs(LFeatures[0].Rms - LExpected) < 1E-12, 'Partial-hop RMS weighting');
    LExpected := (LRecording.Features[0].Flux + LRecording.Features[1].Flux) / 2;
    Check(Abs(LFeatures[0].Flux - LExpected) < 1E-12, 'Partial-hop flux weighting');
    Check((LFeatures[0].StartFrame = 16) and (LFeatures[0].ValidFrames = 32) and
      (LFeatures[1].StartFrame = 48) and (LFeatures[1].ValidFrames = 208),
      'Exact passage measurement extents');
  finally
    LCorpus.Free;
    ReleaseFixtureSources(LSources);
  end;
end;

begin
  try
    CheckMetadata;
    CheckRendering;
    CheckMeasurements;
    WriteLn('Passage metadata, musical grid, measured aggregation and stereo rendering pass');
  except
    on LException: Exception do
    begin
      WriteLn(StdErr, LException.ClassName, ': ', LException.Message);
      Halt(1);
    end;
  end;
end.
