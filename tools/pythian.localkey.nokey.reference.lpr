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
program pythian_localkey_nokey_reference;

{$mode delphi}
{$H+}

uses
  Classes,
  SysUtils,
  fpjson,
  pythian.audio,
  pythian.hash,
  pythian.wave.read;

const
  CRate = 44100;
  CWindowFrames = 441000;
  COriginalNames: array[0..1] of String = (
    'Rain and wind in London 2026 08 28.wav',
    'Sound Effects - Applause after a concert.ogg');
  COriginalBytes: array[0..1] of Int64 = (6050714, 1793175);
  COriginalHashes: array[0..1] of String = (
    '21f958d0842eee1dfa938dc62758eaca3415fe3f54caa15af16288d88d26e59d',
    'a9bed3afd89d66c3ce13edb9f2be2a548ab87a2cc70827624905be90044f8e72');
  CWaveHashes: array[0..1] of String = (
    '21f958d0842eee1dfa938dc62758eaca3415fe3f54caa15af16288d88d26e59d',
    '4d30dcedccb960d838c23103202717909867d6a544a1af41207586f6b1bc7dfb');
  CWindowHashes: array[0..1] of String = (
    '606061791a90bf8d9b00c89bff53bc26b963dcdbea984d0cddc4a7f006d2702b',
    '1f5a2ba792abc78a74cc1609ad0589d5392c660ba843aba54a67c9deb83c0732');
  CSourceFrames: array[0..1] of Int64 = (1512630, 2592389);
  CChannels: array[0..1] of Integer = (2, 1);
  CWindowStarts: array[0..1] of Int64 = (352800, 793800);

procedure Require(const ACondition: Boolean; const AMessage: String);
begin
  if not ACondition then
  begin
    raise EAudio.Create(AMessage);
  end;
end;

procedure CheckHash(const AName: String; const ABytes: Int64;
  const AHash: String);
var
  LFile: TFileStream;
begin
  LFile := TFileStream.Create(AName, fmOpenRead or fmShareDenyWrite);
  try
    Require(LFile.Size = ABytes, 'Original media byte length mismatch');
    Require(Sha256Stream(LFile, LFile.Size) = AHash,
      'Original media SHA256 mismatch');
  finally
    LFile.Free;
  end;
end;

procedure CheckWindow(const ASourceName, AWindowName: String;
  const ASourceHash, AWindowHash: String; const ASourceFrames: Int64;
  const AChannels: Integer; const AWindowStart: Int64);
var
  LSourceFile: TFileStream;
  LWindowFile: TFileStream;
  LSource: TWaveFrameReader;
  LWindow: TWaveFrameReader;
  LSourceSamples: TAudioSamples;
  LWindowSamples: TAudioSamples;
  LRemaining: Int64;
  LTake: Integer;
  I: Integer;
begin
  Require(not SameFileName(ExpandFileName(ASourceName),
    ExpandFileName(AWindowName)), 'Source and window must be separate files');
  LSourceFile := TFileStream.Create(ASourceName, fmOpenRead or fmShareDenyWrite);
  LWindowFile := nil;
  LSource := nil;
  LWindow := nil;
  try
    Require((LSourceFile.Size > 0) and (LSourceFile.Size <= 8000000),
      'Bound WAV source byte length');
    Require(Sha256Stream(LSourceFile, LSourceFile.Size) = ASourceHash,
      'WAV source SHA256 mismatch');
    LSourceFile.Position := 0;
    LSource := TWaveFrameReader.Create(LSourceFile);
    LWindowFile := TFileStream.Create(AWindowName, fmOpenRead or fmShareDenyWrite);
    Require((LWindowFile.Size > 0) and (LWindowFile.Size <= 2000000),
      'Bound review window byte length');
    Require(Sha256Stream(LWindowFile, LWindowFile.Size) = AWindowHash,
      'Review window SHA256 mismatch');
    LWindowFile.Position := 0;
    LWindow := TWaveFrameReader.Create(LWindowFile);
    Require((LSource.SampleRate = CRate) and (LWindow.SampleRate = CRate) and
      (LSource.Channels = AChannels) and (LWindow.Channels = AChannels) and
      (LSource.FrameCount = ASourceFrames) and
      (LWindow.FrameCount = CWindowFrames) and
      (LSource.EncodingTag = 1) and (LWindow.EncodingTag = 1) and
      (LSource.BitsPerSample = 16) and (LWindow.BitsPerSample = 16) and
      (AWindowStart >= 0) and
      (AWindowStart + CWindowFrames <= ASourceFrames),
      'WAV source/window geometry or bounds mismatch');
    LSource.SeekFrame(AWindowStart);
    LRemaining := CWindowFrames;
    while LRemaining > 0 do
    begin
      LTake := 4096;
      if LRemaining < LTake then
      begin
        LTake := LRemaining;
      end;
      LSourceSamples := LSource.ReadFrames(LTake);
      LWindowSamples := LWindow.ReadFrames(LTake);
      Require(Length(LSourceSamples) = LTake * AChannels,
        'Short WAV source read');
      Require(Length(LWindowSamples) = Length(LSourceSamples),
        'Short review window read');
      for I := 0 to High(LSourceSamples) do
      begin
        Require(LSourceSamples[I] = LWindowSamples[I],
          'Review window sample differs from source');
      end;
      Dec(LRemaining, LTake);
    end;
    LSourceFile.Position := 0;
    LWindowFile.Position := 0;
    Require(Sha256Stream(LSourceFile, LSourceFile.Size) = ASourceHash,
      'WAV source changed during check');
    Require(Sha256Stream(LWindowFile, LWindowFile.Size) = AWindowHash,
      'Review window changed during check');
  finally
    LWindow.Free;
    LSource.Free;
    LWindowFile.Free;
    LSourceFile.Free;
  end;
end;

procedure Check(const AIndex: Integer; const AOriginalName, AWaveName,
  AWindowName: String);
var
  LReport: TJSONObject;
begin
  Require((AIndex >= 0) and (AIndex <= 1), 'Unknown reference group');
  CheckHash(AOriginalName, COriginalBytes[AIndex], COriginalHashes[AIndex]);
  CheckWindow(AWaveName, AWindowName, CWaveHashes[AIndex],
    CWindowHashes[AIndex], CSourceFrames[AIndex], CChannels[AIndex],
    CWindowStarts[AIndex]);
  LReport := TJSONObject.Create;
  try
    LReport.Add('policy', 'acoustic-nokey-reference-1');
    LReport.Add('recording', COriginalNames[AIndex]);
    if AIndex = 0 then
      LReport.Add('role', 'development')
    else
      LReport.Add('role', 'independent_evaluation');
    LReport.Add('original_sha256', COriginalHashes[AIndex]);
    LReport.Add('wave_sha256', CWaveHashes[AIndex]);
    LReport.Add('window_sha256', CWindowHashes[AIndex]);
    LReport.Add('source_rate', CRate);
    LReport.Add('source_channels', CChannels[AIndex]);
    LReport.Add('source_frames', CSourceFrames[AIndex]);
    LReport.Add('start_frame', CWindowStarts[AIndex]);
    LReport.Add('end_frame', CWindowStarts[AIndex] + CWindowFrames);
    LReport.Add('label_status', 'reviewed_acoustic_no_key');
    LReport.Add('review_method', 'human_full_10_second_window');
    LReport.Add('review_date', '2026-09-23');
    LReport.Add('reviewed_label', 'no_key');
    WriteLn(LReport.AsJSON);
  finally
    LReport.Free;
  end;
end;

begin
  try
    if (ParamCount = 3) and (ParamStr(1) = 'dev') then
    begin
      Check(0, ParamStr(2), ParamStr(2), ParamStr(3));
    end
    else if (ParamCount = 4) and (ParamStr(1) = 'eval') then
    begin
      Check(1, ParamStr(2), ParamStr(3), ParamStr(4));
    end
    else
    begin
      raise EAudio.Create('Usage: pythian.localkey.nokey.reference ' +
        'dev ORIGINAL.wav WINDOW.wav | eval ORIGINAL.ogg CONVERTED.wav WINDOW.wav');
    end;
  except
    on LError: Exception do
    begin
      WriteLn(StdErr, LError.ClassName, ': ', LError.Message);
      ExitCode := 1;
    end;
  end;
end.
