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
program pythian_tests_analysis_portable;
{$mode delphi}{$H+}

uses
  Classes,
  SysUtils,
  Math,
  pythian.audio,
  pythian.fourier,
  pythian.hash,
  pythian.wave,
  pythian.wave.read,
  pythian.stream.bytes,
  pythian.analysis,
  pythian.analysis.wave;

const
  CTolerance = 1E-6;

var
  GChecks: Integer;

procedure Check(const ACondition: Boolean; const AMessage: String);
begin
  if not ACondition then
  begin
    raise Exception.Create(AMessage);
  end;
  Inc(GChecks);
end;

function Near(const ALeft, ARight: Double): Boolean;
begin
  Result := Abs(ALeft - ARight) <= CTolerance * Max(1.0, Max(Abs(ALeft), Abs(ARight)));
end;

procedure CompareFeature(const AWhole, ABatch: TAudioFeature; const AOrigin: Int64);
var
  LIndex: Integer;
begin
  Check((AWhole.StartFrame = AOrigin + ABatch.StartFrame) and
    (AWhole.ValidFrames = ABatch.ValidFrames) and (AWhole.Silent = ABatch.Silent),
    'batch coordinates/flags');
  Check(Near(AWhole.Rms, ABatch.Rms) and Near(AWhole.Peak, ABatch.Peak) and
    Near(AWhole.CentroidHz, ABatch.CentroidHz) and Near(AWhole.Flux, ABatch.Flux),
    'batch acoustic fields');
  for LIndex := 0 to 11 do
  begin
    Check(Near(AWhole.Chroma[LIndex], ABatch.Chroma[LIndex]), 'batch chroma');
  end;
end;

procedure TestFourier;
var
  LReal: TFourierValues;
  LImaginary: TFourierValues;
  LAlias: TFourierValues;
  LIndex: Integer;
  LRejected: Boolean;
begin
  SetLength(LReal, 8);
  for LIndex := 0 to 7 do
  begin
    LReal[LIndex] := LIndex / 8;
  end;
  LRejected := False;
  try
    Fourier(LReal, LReal);
  except
    on LException: EAudio do
    begin
      LRejected := True;
    end;
  end;
  Check(LRejected and (LReal[7] = 0.875), 'same variable rejection preserves input');
  LAlias := LReal;
  LImaginary := LReal;
  Fourier(LReal, LImaginary);
  Check((LAlias[7] = 0.875) and (LAlias[0] = 0), 'shared input alias preserved');
  Fourier(LReal, LImaginary, True);
  for LIndex := 0 to 7 do
  begin
    Check((Abs(LReal[LIndex] - LIndex / 8) < 1E-10) and
      (Abs(LImaginary[LIndex] - LIndex / 8) < 1E-10), 'FFT roundtrip');
  end;
end;

{$ifndef pas2js}
procedure CompareLogs(const ANativePath, AJsPath: String);
var
  LNative: TStringList;
  LJs: TStringList;
  LLeft: TStringList;
  LRight: TStringList;
  LNativeRows: Integer;
  LJsRows: Integer;
  LRow: Integer;
  LField: Integer;
  LLeftValue: Double;
  LRightValue: Double;
  LFormat: TFormatSettings;

  procedure Extract(const APath: String; const ADestination: TStringList);
  var
    LSource: TStringList;
    LLine: Integer;
  begin
    LSource := TStringList.Create;
    try
      LSource.LoadFromFile(APath);
      for LLine := 0 to LSource.Count - 1 do
      begin
        if Copy(LSource[LLine], 1, 8) = 'FEATURE ' then
        begin
          ADestination.Add(LSource[LLine]);
        end;
      end;
    finally
      LSource.Free;
    end;
  end;

begin
  LNative := TStringList.Create;
  LJs := TStringList.Create;
  LLeft := TStringList.Create;
  LRight := TStringList.Create;
  try
    Extract(ANativePath, LNative);
    Extract(AJsPath, LJs);
    LNativeRows := LNative.Count;
    LJsRows := LJs.Count;
    Check((LNativeRows = 8) and (LJsRows = 8), 'comparison requires eight feature rows');
    LFormat := DefaultFormatSettings;
    LFormat.DecimalSeparator := '.';
    LLeft.Delimiter := ' ';
    LRight.Delimiter := ' ';
    LLeft.StrictDelimiter := True;
    LRight.StrictDelimiter := True;
    for LRow := 0 to 7 do
    begin
      LLeft.DelimitedText := LNative[LRow];
      LRight.DelimitedText := LJs[LRow];
      Check((LLeft.Count = 20) and (LRight.Count = 20) and
        (LLeft[0] = 'FEATURE') and (LRight[0] = 'FEATURE'), 'malformed feature row');
      for LField := 1 to 3 do
      begin
        Check((StrToInt64(LLeft[LField]) = StrToInt64(LRight[LField])),
          'feature geometry differs');
      end;
      for LField := 4 to 19 do
      begin
        LLeftValue := StrToFloat(LLeft[LField], LFormat);
        LRightValue := StrToFloat(LRight[LField], LFormat);
        Check(not IsNan(LLeftValue) and not IsInfinite(LLeftValue) and
          not IsNan(LRightValue) and not IsInfinite(LRightValue) and
          Near(LLeftValue, LRightValue), 'feature value differs or is nonfinite');
      end;
    end;
    WriteLn('PASS native/pas2js feature comparison');
  finally
    LRight.Free;
    LLeft.Free;
    LJs.Free;
    LNative.Free;
  end;
end;
{$endif}

var
  LInput: TAudioSamples;
  LClip: TAudioClip;
  LDecoded: TAudioClip;
  LBytes: TAudioBytes;
  LStream: TAudioBytesReadStream;
  LReader: TWaveFrameReader;
  LOptions: TAnalysisOptions;
  LWhole: TAudioFeatures;
  LBatch: TWaveFeatureBatch;
  LIndex: Integer;
  LNext: Int64;
  LRow: Integer;
  LChannel: Integer;
begin
  {$ifndef pas2js}
  if ParamCount > 0 then
  begin
    Check((ParamCount = 3) and (ParamStr(1) = '--compare'),
      'usage: --compare native.log pas2js.log');
    CompareLogs(ParamStr(2), ParamStr(3));
    Exit;
  end;
  {$endif}
  TestFourier;
  SetLength(LInput, 128);
  for LIndex := 0 to 127 do
  begin
    if LIndex < 48 then
    begin
      case LIndex mod 4 of
        0: LInput[LIndex] := -1;
        1: LInput[LIndex] := -0.5;
        2: LInput[LIndex] := 0;
        3: LInput[LIndex] := 0.5;
      end;
    end
    else if LIndex < 96 then
    begin
      case LIndex mod 4 of
        0, 2: LInput[LIndex] := 0;
        1: LInput[LIndex] := 0.25;
        3: LInput[LIndex] := -0.25;
      end;
    end;
  end;
  LClip := TAudioClip.Create(8000, 1, LInput);
  try
    LBytes := EncodeWavePcm16(LClip);
    Check(Sha256Bytes(LBytes) = '63a6d184b85e18793ac135b7f1f6a5c108c2ec66ee9331db88b7d353d6f07868',
      'independent PCM/WAV SHA256');
    LDecoded := DecodeWave(LBytes);
    try
      for LIndex := 0 to 127 do
      begin
        Check(LDecoded.SampleAt(LIndex, 0) = LInput[LIndex], 'exact PCM decode');
      end;
    finally
      LDecoded.Free;
    end;
    LStream := TAudioBytesReadStream.Create(LBytes);
    try
      LReader := TWaveFrameReader.Create(LStream);
      try
        LOptions := DefaultAnalysisOptions;
        LOptions.WindowFrames := 64;
        LOptions.HopFrames := 16;
        LWhole := AnalyzeWave(LReader, LOptions);
        Check((Length(LWhole) = 8) and Near(LWhole[0].Rms, Sqrt(18.5 / 64)) and
          (LWhole[0].Peak = 1), 'fixed analytical RMS and peak');
        Check(LWhole[7].Silent and (LWhole[7].Rms = 0), 'fixed final silence');
        LNext := 0;
        while LNext < Length(LWhole) do
        begin
          LBatch := AnalyzeWaveBatch(LReader, LOptions, LNext, 3);
          Check((LBatch.FirstFeature = LNext) and (Length(LBatch.Features) > 0),
            'batch progression');
          for LIndex := 0 to High(LBatch.Features) do
          begin
            CompareFeature(LWhole[LNext + LIndex], LBatch.Features[LIndex], LBatch.SourceStartFrame);
          end;
          LNext := LBatch.NextFeature;
        end;
        Check(LBatch.Completed, 'batch completion');
        for LRow := 0 to High(LWhole) do
        begin
          Write('FEATURE ', LWhole[LRow].StartFrame, ' ', LWhole[LRow].ValidFrames,
            ' ', Ord(LWhole[LRow].Silent), ' ', LWhole[LRow].Rms:0:12,
            ' ', LWhole[LRow].Peak:0:12, ' ', LWhole[LRow].CentroidHz:0:12,
            ' ', LWhole[LRow].Flux:0:12);
          for LChannel := 0 to 11 do
          begin
            Write(' ', LWhole[LRow].Chroma[LChannel]:0:12);
          end;
          WriteLn;
        end;
      finally
        LReader.Free;
      end;
    finally
      LStream.Free;
    end;
  finally
    LClip.Free;
  end;
  WriteLn('PASS ', GChecks, ' analysis portability checks');
end.
