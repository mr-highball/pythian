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
program pythian_tests_studio_preparation;
{$mode delphi}{$H+}

uses
  Classes, SysUtils, fpjson,
  pythian.audio, pythian.progress, pythian.wave.stream, pythian.wave.read,
  pythian.wave.resample,
  pythian.tools.studio.preparation;

type
  TProbe = class
    Abort: Boolean;
    AudioCalls: Integer;
    procedure Observe(const AProgress: TWorkProgress);
  end;

var
  GChecks: Integer;

procedure Check(const ACondition: Boolean; const AMessage: String);
begin
  Inc(GChecks);
  if not ACondition then raise Exception.Create(AMessage);
end;

procedure TProbe.Observe(const AProgress: TWorkProgress);
begin
  if AProgress.Stage = 'prepare_audio' then Inc(AudioCalls);
  if Abort and (AProgress.Stage = 'prepare_audio') and (AProgress.Done > 0) then
  begin
    raise Exception.Create('abort preparation');
  end;
end;

procedure CaseSource(const ARoot: String; const ARate, AChannels: Integer);
var
  LSamples: TAudioSamples;
  LClip: TAudioClip;
  LStream: TFileStream;
  LCorrupt: TFileStream;
  LWave: TWaveFrameReader;
  LSnapshot: TJSONObject;
  LConfig: TJSONObject;
  LPrepared: TStudioPreparedRange;
  LAgain: TStudioPreparedRange;
  LProbe: TProbe;
  LIndex: Integer;
  LStart: Integer;
  LEnd: Integer;
  LExpected: Integer;
  LActual: TAudioSamples;
  LHash: String;
  LFailed: Boolean;
  LMarker: String;
  LCountBefore: Integer;
  LByte: Byte;
  LSearch: TSearchRec;
  LSmall: TWavePcmReader;
  LLarge: TWavePcmReader;
  LFirst: TAudioSamples;
  LLeft: Double;
  LRight: Double;
  LReceiptText: TStringList;
  LReceiptOriginal: String;
  LPlan: TStudioPreparationPlan;
begin
  ForceDirectories(ARoot);
  LStart := ARate div 10;
  LEnd := ARate div 5;
  SetLength(LSamples, (LEnd + 100) * AChannels);
  for LIndex := 0 to High(LSamples) do
  begin
    if (LIndex div AChannels >= LStart) and (LIndex div AChannels < LEnd) then
      LSamples[LIndex] := 0.5
    else
      LSamples[LIndex] := -1;
  end;
  LClip := TAudioClip.Create(ARate, AChannels, LSamples);
  try
    LStream := TFileStream.Create(ARoot + '/original.wav', fmCreate);
    try WriteWavePcm16(LStream, LClip); finally LStream.Free; end;
  finally LClip.Free; end;
  LStream := TFileStream.Create(ARoot + '/original.wav', fmOpenRead);
  try
    LWave := TWaveFrameReader.Create(LStream);
    try
      SetLength(LFirst, (LEnd - LStart) * AChannels);
      LSmall := TWavePcmReader.CreateRange(LWave, LStart, LEnd, 3);
      try
        for LIndex := 0 to LEnd - LStart - 1 do
        begin
          Check(LSmall.ReadFrame(LLeft, LRight), 'small block frame');
          LFirst[LIndex * AChannels] := LLeft;
          if AChannels = 2 then LFirst[LIndex * AChannels + 1] := LRight;
        end;
        Check(not LSmall.ReadFrame(LLeft, LRight), 'range stops at selected endpoint');
      finally
        LSmall.Free;
      end;
      LLarge := TWavePcmReader.CreateRange(LWave, LStart, LEnd, 4096);
      try
        for LIndex := 0 to LEnd - LStart - 1 do
        begin
          Check(LLarge.ReadFrame(LLeft, LRight) and
            (LLeft = LFirst[LIndex * AChannels]) and
            ((AChannels = 1) or (LRight = LFirst[LIndex * AChannels + 1])),
            'range reader block-size identity');
        end;
      finally
        LLarge.Free;
      end;
      LWave.SeekFrame(LWave.FrameCount);
      LSmall := TWavePcmReader.Create(LWave, 3);
      try
        Check(not LSmall.ReadFrame(LLeft, LRight), 'remaining reader at EOF stays empty');
      finally
        LSmall.Free;
      end;
      LSmall := TWavePcmReader.CreateRange(LWave, LStart, LStart, 3);
      try
        Check(not LSmall.ReadFrame(LLeft, LRight), 'empty internal range stays empty');
      finally
        LSmall.Free;
      end;
      LSnapshot := TJSONObject.Create;
      LConfig := TJSONObject.Create;
      LProbe := TProbe.Create;
      try
        LSnapshot.Add('source_sha256', StringOfChar('a', 64));
        LSnapshot.Add('sample_rate', ARate);
        LSnapshot.Add('channels', AChannels);
        LSnapshot.Add('frame_count', LWave.FrameCount);
        LSnapshot.Add('start_frame', LStart);
        LSnapshot.Add('end_frame', LEnd);
        LSnapshot.Add('source_group', 'first-party');
        LSnapshot.Add('partition', 'training');
        LConfig.Add('sample_rate', 48000);
        LConfig.Add('channels', 2);
        LConfig.Add('gain', 0.5);
        LPlan := PlanStudioPreparation(LEnd - LStart, ARate, AChannels, LConfig);
        Check((LPlan.OutputFrames = 4800) and (LPlan.OutputBytesUpperBound = 19280) and
          (LPlan.VisitsUpperBound >= LPlan.OutputFrames * AChannels),
          'shared preparation plan geometry and work');
        LFailed := False;
        try
          LPlan := PlanStudioPreparation(High(Int64), ARate, AChannels, LConfig);
        except
          on LException: EAudio do LFailed := True;
        end;
        Check(LFailed, 'oversize preparation plan rejected before allocation');
        LProbe.Abort := True;
        LFailed := False;
        try
          LPrepared := PrepareStudioRange(ARoot + '/cache', LWave, LSnapshot, LConfig, LProbe.Observe);
          LPrepared.Free;
        except on E: Exception do LFailed := E.Message = 'abort preparation'; end;
        Check(LFailed, 'callback cancellation');
        LIndex := FindFirst(ARoot + '/cache/*.partial', faAnyFile, LSearch);
        if LIndex = 0 then FindClose(LSearch);
        Check(LIndex <> 0, 'cancelled preparation removes stage');
        LProbe.Abort := False;
        LPrepared := PrepareStudioRange(ARoot + '/cache', LWave, LSnapshot, LConfig, LProbe.Observe);
        try
          LExpected := 4800;
          Check((LPrepared.Wave.FrameCount = LExpected) and (LPrepared.Wave.SampleRate = 48000) and
            (LPrepared.Wave.Channels = 2), 'prepared geometry');
          LActual := LPrepared.Wave.ReadFrames(LExpected);
          for LIndex := 0 to High(LActual) do
          begin
            Check(Abs(LActual[LIndex] - 0.25) < 0.00004, 'constant selected range does not leak outside');
          end;
          LHash := LPrepared.RecipeSha256;
          LMarker := LPrepared.Receipt.Strings['prepared_sha256'];
          LPrepared.Wave.SeekFrame(12);
          LPrepared.Verify;
          Check(LPrepared.Wave.FramePosition = 12, 'verification restores playback clock');
          LCountBefore := LProbe.AudioCalls;
          LAgain := PrepareStudioRange(ARoot + '/cache', LWave, LSnapshot, LConfig, LProbe.Observe);
          try
            Check((LAgain.RecipeSha256 = LHash) and
              (LAgain.Receipt.Strings['prepared_sha256'] = LMarker), 'cache reuse identity');
            Check(LProbe.AudioCalls = LCountBefore, 'verified reuse does not reconvert');
          finally LAgain.Free; end;
        finally LPrepared.Free; end;
        LReceiptText := TStringList.Create;
        try
          LReceiptText.LoadFromFile(ARoot + '/cache/' + LHash + '/receipt.json');
          LReceiptOriginal := LReceiptText.Text;
          LReceiptText.Text := StringReplace(LReceiptOriginal, 'studio-range-sinc-pcm16-v1',
            'studio-range-sinc-pcm16-v2', []);
          LReceiptText.SaveToFile(ARoot + '/cache/' + LHash + '/receipt.json');
          LFailed := False;
          try
            LPrepared := PrepareStudioRange(ARoot + '/cache', LWave, LSnapshot, LConfig);
            LPrepared.Free;
          except
            on LException: EAudio do LFailed := True;
          end;
          Check(LFailed, 'corrupt cached recipe rejects');
          LReceiptText.Text := LReceiptOriginal;
          LReceiptText.SaveToFile(ARoot + '/cache/' + LHash + '/receipt.json');
        finally
          LReceiptText.Free;
        end;
        LCorrupt := TFileStream.Create(ARoot + '/cache/' + LHash + '/audio.wav', fmOpenReadWrite);
        try
          LCorrupt.Position := LCorrupt.Size - 1;
          LCorrupt.ReadBuffer(LByte, 1);
          LByte := LByte xor 1;
          LCorrupt.Position := LCorrupt.Size - 1;
          LCorrupt.WriteBuffer(LByte, 1);
        finally
          LCorrupt.Free;
        end;
        LFailed := False;
        try
          LPrepared := PrepareStudioRange(ARoot + '/cache', LWave, LSnapshot, LConfig);
          LPrepared.Free;
        except on E: EAudio do LFailed := True; end;
        Check(LFailed, 'corrupt cached bytes reject');
      finally LProbe.Free; LConfig.Free; LSnapshot.Free; end;
    finally LWave.Free; end;
  finally LStream.Free; end;
end;

procedure HeadroomCheck(const ARoot: String);
var
  LBytes: TAudioBytes;
  LStream: TFileStream;
  LWave: TWaveFrameReader;
  LSnapshot: TJSONObject;
  LConfig: TJSONObject;
  LPrepared: TStudioPreparedRange;
  LFailed: Boolean;
  LIndex: Integer;
begin
  Check(ForceDirectories(ARoot), 'headroom root');
  LBytes := WavePcm16Header(8000, 1, 0);
  SetLength(LBytes, 44 + 400);
  LBytes[4] := 180;
  LBytes[5] := 1;
  LBytes[20] := 3;
  LBytes[28] := 0;
  LBytes[29] := 125;
  LBytes[32] := 4;
  LBytes[34] := 32;
  LBytes[40] := 144;
  LBytes[41] := 1;
  for LIndex := 0 to 99 do
  begin
    LBytes[44 + LIndex * 4 + 2] := $C0;
    LBytes[44 + LIndex * 4 + 3] := $3F;
  end;
  LStream := TFileStream.Create(ARoot + '/float.wav', fmCreate);
  try
    LStream.WriteBuffer(LBytes[0], Length(LBytes));
  finally
    LStream.Free;
  end;
  LStream := TFileStream.Create(ARoot + '/float.wav', fmOpenRead);
  try
    LWave := TWaveFrameReader.Create(LStream);
    try
      LSnapshot := TJSONObject.Create;
      LConfig := TJSONObject.Create;
      try
        LSnapshot.Add('source_sha256', StringOfChar('b', 64));
        LSnapshot.Add('sample_rate', 8000);
        LSnapshot.Add('channels', 1);
        LSnapshot.Add('frame_count', 100);
        LSnapshot.Add('start_frame', 0);
        LSnapshot.Add('end_frame', 100);
        LConfig.Add('sample_rate', 8000);
        LConfig.Add('channels', 1);
        LConfig.Add('gain', 1.0);
        LFailed := False;
        try
          LPrepared := PrepareStudioRange(ARoot + '/cache', LWave, LSnapshot, LConfig);
          LPrepared.Free;
        except
          on LException: EAudio do LFailed := True;
        end;
        Check(LFailed, 'out-of-headroom float requires explicit lower gain');
        LConfig.Floats['gain'] := 0.5;
        LPrepared := PrepareStudioRange(ARoot + '/cache', LWave, LSnapshot, LConfig);
        try
          Check((LPrepared.Receipt.Floats['peak_before_gain'] = 1.5) and
            (LPrepared.Receipt.Floats['peak_after_gain'] = 0.75) and
            (LPrepared.Receipt.Integers['clipped_samples'] = 0), 'explicit gain and peak receipt');
        finally
          LPrepared.Free;
        end;
      finally
        LConfig.Free;
        LSnapshot.Free;
      end;
    finally
      LWave.Free;
    end;
  finally
    LStream.Free;
  end;
end;

var
  LRoot: String;
begin
  Check(ParamCount = 1, 'fresh root argument required');
  LRoot := ExpandFileName(ParamStr(1));
  Check(not DirectoryExists(LRoot), 'fresh root');
  CaseSource(LRoot + '/stereo', 44100, 2);
  CaseSource(LRoot + '/mono', 48000, 1);
  HeadroomCheck(LRoot + '/headroom');
  WriteLn('PASS ', GChecks, ' prepared range checks');
end.
