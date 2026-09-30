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
program pythian_example_provider_extensions;

{$mode delphi}
{$H+}

uses
  Classes, SysUtils, pythian.audio, pythian.wave, pythian.hash,
  pythian.wfc.layers, pythian.wfc.providers, pythian.wfc.provider.codecs,
  pythian.wfc.provider.contracts, pythian.wfc.semantic.style,
  pythian.example.provider.extension.units, wfc;

{ Mechanical first-party control. No inferred acoustic truth, outside-use,
  listening, hard-real-time or direct-write atomicity claim. }
function ParseSeed(const AText: String): Integer;
var
  LIndex: Integer;
  LValue: Int64;
begin
  if (Length(AText) < 1) or (Length(AText) > 10) then
  begin
    raise EAudio.Create('SEED requires unsigned decimal 0..2147483647');
  end;
  for LIndex := 1 to Length(AText) do
  begin
    if not (AText[LIndex] in ['0'..'9']) then
    begin
      raise EAudio.Create('SEED requires unsigned decimal 0..2147483647');
    end;
  end;
  if not TryStrToInt64(AText, LValue) or (LValue > High(Integer)) then
  begin
    raise EAudio.Create('SEED exceeds 2147483647');
  end;
  Result := Integer(LValue);
end;

procedure RequireFreshPath(const APath: String);
begin
  if (Trim(APath) = '') or (Pos(#0, APath) <> 0) or FileExists(APath) or
    DirectoryExists(APath) or not DirectoryExists(ExtractFilePath(APath)) then
  begin
    raise EAudio.Create('Publication requires fresh files in an existing parent');
  end;
end;

procedure SaveBytes(const APath: String; const ABytes: TAudioBytes);
var
  LStream: TFileStream;
begin
  LStream := TFileStream.Create(APath, fmCreate);
  try
    if Length(ABytes) > 0 then
    begin
      LStream.WriteBuffer(ABytes[0], Length(ABytes));
    end;
  finally
    LStream.Free;
  end;
end;

function LoadBytes(const APath: String): TAudioBytes;
var
  LStream: TFileStream;
begin
  Result := nil;
  LStream := TFileStream.Create(APath, fmOpenRead or fmShareDenyWrite);
  try
    if LStream.Size > MaximumSemanticStyleBytes then
    begin
      raise EAudio.Create('Saved style exceeds its format bound');
    end;
    SetLength(Result, LStream.Size);
    if Length(Result) > 0 then
    begin
      LStream.ReadBuffer(Result[0], Length(Result));
    end;
  finally
    LStream.Free;
  end;
end;

procedure Run;
var
  LPath: String;
  LStem: String;
  LStylePath: String;
  LReferencePath: array[0..1] of String;
  LSeed: Integer;
  LCodec: TCallerHarmonicCodec;
  LRegistry: TProviderCodecRegistry;
  LStyle: TSemanticStyle;
  LOther: TSemanticStyle;
  LReloadedStyle: TSemanticStyle;
  LSession: TCompatibleProviderSession;
  LSequences: TLayerSequences;
  LReport: TGraphNegotiationReport;
  LBinding: TProviderCodecBinding;
  LChoices: TStyleProviderChoices;
  LReference: array[0..1] of TAudioBytes;
  LStyleBytes: TAudioBytes;
  LRendered: TAudioClip;
  LReloaded: TAudioClip;
  LExpected: TAudioClip;
  LFrame: Integer;
  LChannel: Integer;
  LIndex: Integer;
begin
  if (ParamCount < 1) or (ParamCount > 2) then
  begin
    raise EAudio.Create('Usage: pythian.example.provider.extensions FRESH.wav [SEED:0..2147483647]');
  end;
  LSeed := 731;
  if ParamCount = 2 then
  begin
    LSeed := ParseSeed(ParamStr(2));
  end;
  if not SameText(ExtractFileExt(ParamStr(1)), '.wav') then
  begin
    raise EAudio.Create('OUTPUT requires .wav extension');
  end;
  LPath := ExpandFileName(ParamStr(1));
  LStem := ChangeFileExt(LPath, '');
  LStylePath := LStem + '.pys';
  for LIndex := 0 to 1 do
  begin
    LReferencePath[LIndex] := LStem + '-authored-' + IntToStr(LIndex) + '.wav';
    RequireFreshPath(LReferencePath[LIndex]);
  end;
  RequireFreshPath(LPath);
  RequireFreshPath(LStylePath);
  LCodec := TCallerHarmonicCodec.Create;
  LRegistry := nil;
  LStyle := nil;
  LOther := nil;
  try
    LRegistry := TProviderCodecRegistry.Create;
    RegisterHarmonicCodec(LRegistry, LCodec);
    LRegistry.Seal;
    LStyle := CreateHarmonicSourceStyle(0, LRegistry, LReference[0]);
    LOther := CreateHarmonicSourceStyle(1, LRegistry, LReference[1]);
    if Sha256Bytes(LReference[0]) = Sha256Bytes(LReference[1]) then
    begin
      raise EAudio.Create('Authored controls did not produce distinct WAV bytes');
    end;
    LStyleBytes := LStyle.Encode;
  finally
    LOther.Free;
    LStyle.Free;
    LRegistry.Free;
    LCodec.Free;
  end;
  { No registry or codec survives source-style creation. Persist data only.
    Admission on actual saved bytes receives a fresh explicit registration. }
  SaveBytes(LStylePath, LStyleBytes);
  LSession := nil;
  try
    LCodec := TCallerHarmonicCodec.Create;
    LRegistry := nil;
    LReloadedStyle := nil;
    try
      LRegistry := TProviderCodecRegistry.Create;
      RegisterHarmonicCodec(LRegistry, LCodec);
      LRegistry.Seal;
      LReloadedStyle := DecodeSemanticStyle(LoadBytes(LStylePath), LRegistry);
      if Sha256Bytes(LReloadedStyle.Encode) <> Sha256Bytes(LStyleBytes) then
      begin
        raise EAudio.Create('Actual saved style changed its detached data');
      end;
      LSession := LReloadedStyle.CreateSession(LSeed, LRegistry);
      LBinding := LSession.CopyContract('balance').CodecBinding;
      LChoices := LSession.CopyChoices('balance');
    finally
      LReloadedStyle.Free;
      LRegistry.Free;
      LCodec.Free;
    end;
    LSequences := nil;
    if not LSession.TryGenerate(LSequences, LReport) then
    begin
      raise EAudio.Create('Dependent harmonic WFC generation failed');
    end;
    LRendered := RenderHarmonicSequences(LSequences, LBinding, LChoices);
    try
      SaveWavePcm16(LPath, LRendered);
      LReloaded := LoadWave(LPath);
      try
        if (LReloaded.SampleRate <> 16000) or (LReloaded.Channels <> 2) or
          (LReloaded.FrameCount <> 16000) then
        begin
          raise EAudio.Create('Actual saved harmonic WAV geometry differs');
        end;
        LExpected := DecodeWave(EncodeWavePcm16(LRendered));
        try
          for LFrame := 0 to LReloaded.FrameCount - 1 do
          begin
            for LChannel := 0 to 1 do
            begin
              if LReloaded.SampleAt(LFrame, LChannel) <>
                LExpected.SampleAt(LFrame, LChannel) then
              begin
                raise EAudio.Create('Actual saved harmonic PCM differs from expectation');
              end;
            end;
          end;
        finally
          LExpected.Free;
        end;
      finally
        LReloaded.Free;
      end;
    finally
      LRendered.Free;
    end;
    for LIndex := 0 to 1 do
    begin
      SaveBytes(LReferencePath[LIndex], LReference[LIndex]);
    end;
    WriteLn('Caller harmonic balance: dependent WFC generated after registry release; ',
      '16000 stereo frames at 16000 Hz saved/reloaded with exact PCM agreement.');
    WriteLn('Two authored control WAVs and current saved style accompany OUTPUT; ',
      'direct writes may leave partial new files on I/O failure.');
  finally
    LSession.Free;
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
