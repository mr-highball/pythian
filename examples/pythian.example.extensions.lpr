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
program pythian_example_extensions;

{$mode delphi}
{$H+}

uses
  SysUtils, Math, pythian.audio, pythian.wave, pythian.example.extension.units;

{ Asset-free caller implementation. Both native scheduled and streamed paths
  run; the streamed WAV is published to a fresh path and reloaded from disk.
  No human listening, outside consumer, hard-real-time or atomic-write claim. }
function Decimal(const AText, AName: String): Double;
var
  LFormat: TFormatSettings;
begin
  LFormat := DefaultFormatSettings;
  LFormat.DecimalSeparator := '.';
  LFormat.ThousandSeparator := #0;
  if not TryStrToFloat(AText, Result, LFormat) then
  begin
    raise EAudio.Create(AName + ' requires a finite dot-decimal value');
  end;
  RequireFinite(Result, AName);
  if (Result < 0) or (Result > 1) then
  begin
    raise EAudio.Create(AName + ' must be in 0..1');
  end;
end;

function Unsigned(const AText: String; const AMaximum: Cardinal): Cardinal;
var
  LValue: Int64;
  LIndex: Integer;
begin
  if (Length(AText) < 1) or (Length(AText) > 10) then
  begin
    raise EAudio.Create('Expected bounded unsigned decimal integer');
  end;
  for LIndex := 1 to Length(AText) do
  begin
    if not (AText[LIndex] in ['0'..'9']) then
    begin
      raise EAudio.Create('Expected bounded unsigned decimal integer');
    end;
  end;
  if not TryStrToInt64(AText, LValue) or (LValue > AMaximum) then
  begin
    raise EAudio.Create('Unsigned value exceeds declared caller bounds');
  end;
  Result := Cardinal(LValue);
end;

procedure Run;
var
  LPath: String;
  LMix: Double;
  LWet: Double;
  LSeed: Cardinal;
  LBlockFrames: Integer;
  LFactory: TCallerHarmonicFactory;
  LScheduled: TAudioClip;
  LStreamed: TAudioClip;
  LReloaded: TAudioClip;
  LExpectedPcm: TAudioClip;
  LFrame: Integer;
  LChannel: Integer;
begin
  if (ParamCount < 1) or (ParamCount > 5) then
  begin
    raise EAudio.Create('Usage: pythian.example.extensions FRESH.wav [MIX [WET [SEED [BLOCK_FRAMES]]]]');
  end;
  LMix := 0.35;
  LWet := 0.3;
  LSeed := 731;
  LBlockFrames := 257;
  if ParamCount >= 2 then
  begin
    LMix := Decimal(ParamStr(2), 'MIX');
  end;
  if ParamCount >= 3 then
  begin
    LWet := Decimal(ParamStr(3), 'WET');
  end;
  if ParamCount >= 4 then
  begin
    LSeed := Unsigned(ParamStr(4), High(Cardinal) - 2);
  end;
  if ParamCount = 5 then
  begin
    LBlockFrames := Integer(Unsigned(ParamStr(5), 2048));
    if LBlockFrames = 0 then
    begin
      raise EAudio.Create('BLOCK_FRAMES must be in 1..2048');
    end;
  end;
  if (Trim(ParamStr(1)) = '') or not SameText(ExtractFileExt(ParamStr(1)), '.wav') then
  begin
    raise EAudio.Create('Publication requires a fresh .wav path');
  end;
  LPath := ExpandFileName(ParamStr(1));
  if FileExists(LPath) or DirectoryExists(LPath) or
    not DirectoryExists(ExtractFilePath(LPath)) then
  begin
    raise EAudio.Create('Publication requires an existing parent and fresh file path');
  end;
  LFactory := TCallerHarmonicFactory.Create(LMix);
  try
    LScheduled := RenderCallerScheduled(LFactory, LSeed, LWet);
    try
      LStreamed := RenderCallerStreamed(LFactory, LSeed, LWet, LBlockFrames);
      try
        if (LScheduled.FrameCount <> LStreamed.FrameCount) or
          (LStreamed.FrameCount <> CallerExampleFrames + CallerExampleDelayFrames) then
        begin
          raise EAudio.Create('Caller paths disagree on declared finite-tail extent');
        end;
        for LFrame := 0 to LStreamed.FrameCount - 1 do
        begin
          for LChannel := 0 to 1 do
          begin
            { Streamed source blocks convert to Single before the caller effect;
              the scheduled bus effect runs before that final conversion. }
            if Abs(LScheduled.SampleAt(LFrame, LChannel) -
              LStreamed.SampleAt(LFrame, LChannel)) > 2 / 32768 then
            begin
              raise EAudio.Create('Scheduled/streamed caller paths differ beyond PCM tolerance');
            end;
          end;
        end;
        SaveWavePcm16(LPath, LStreamed);
        LReloaded := LoadWave(LPath);
        try
          if (LReloaded.SampleRate <> CallerExampleSampleRate) or
            (LReloaded.Channels <> 2) or (LReloaded.FrameCount <> LStreamed.FrameCount) then
          begin
            raise EAudio.Create('Actual saved caller WAV geometry changed');
          end;
          LExpectedPcm := DecodeWave(EncodeWavePcm16(LStreamed));
          try
            for LFrame := 0 to LReloaded.FrameCount - 1 do
            begin
              for LChannel := 0 to 1 do
              begin
                if LReloaded.SampleAt(LFrame, LChannel) <>
                  LExpectedPcm.SampleAt(LFrame, LChannel) then
                begin
                  raise EAudio.Create('Actual saved PCM differs from rendered PCM expectation');
                end;
              end;
            end;
          finally
            LExpectedPcm.Free;
          end;
          WriteLn('Caller source/effect scheduled and streamed; saved/reloaded ',
            LReloaded.FrameCount, ' stereo frames at ', LReloaded.SampleRate,
            ' Hz; full ', CallerExampleDelayFrames, '-frame finite delay tail');
        finally
          LReloaded.Free;
        end;
      finally
        LStreamed.Free;
      end;
    finally
      LScheduled.Free;
    end;
  finally
    LFactory.Free;
  end;
end;

begin
  try
    Run;
  except
    on LException: Exception do
    begin
      WriteLn(StdErr, LException.ClassName, ': ', LException.Message);
      ExitCode := 1;
    end;
  end;
end.
