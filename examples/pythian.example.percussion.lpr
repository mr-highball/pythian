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
program pythian_example_percussion;

{$mode delphi}
{$H+}

uses
  Classes,
  SysUtils,
  pythian.audio,
  pythian.synth,
  pythian.percussion,
  pythian.wave.stream;

procedure Run;
const
  CNames: array[TPercussionKind] of String = ('kick', 'snare', 'hat');
  CRate = 44100;
var
  LKind: TPercussionKind;
  LKit: TPercussionInstrument;
  LTones: TFrameTones;
  LHit: TFrameTones;
  LClip: TAudioClip;
  LFile: TFileStream;
  LIndex: Integer;
  LLayer: Integer;
  LCount: Integer;
begin
  if ParamCount <> 1 then
  begin
    raise EAudio.Create('Usage: pythian.example.percussion OUTPUT_PREFIX');
  end;
  for LKind := Low(TPercussionKind) to High(TPercussionKind) do
  begin
    LKit := TPercussionInstrument.Create(CRate, DefaultPercussionSettings(LKind, CRate));
    LClip := nil;
    LFile := nil;
    try
      LTones := nil;
      for LIndex := 0 to 3 do
      begin
        LHit := LKit.PlanHit(Int64(LIndex) * (CRate div 2), 110 - LIndex * 10, LIndex + 1);
        LCount := Length(LTones);
        SetLength(LTones, LCount + Length(LHit));
        for LLayer := 0 to High(LHit) do
        begin
          LTones[LCount + LLayer] := LHit[LLayer];
        end;
      end;
      LClip := RenderFrameTones(LTones, CRate, CRate * 2);
      LFile := TFileStream.Create(ParamStr(1) + '-' + CNames[LKind] + '.wav', fmCreate);
      WriteWavePcm16(LFile, LClip);
      WriteLn(CNames[LKind], ': source-free core recipe, four velocity-controlled hits');
    finally
      LFile.Free;
      LClip.Free;
      LKit.Free;
    end;
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
