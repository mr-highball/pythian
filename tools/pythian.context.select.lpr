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

program pythian_context_select;

{$mode delphi}
{$H+}

uses
  SysUtils,
  pythian.audio,
  pythian.wfc.context,
  pythian.wfc.context.archive,
  pythian.wfc.context.profile,
  pythian.tools.progress,
  pythian.tools.files;

procedure Run;
var
  LKey: TContextProfile;
  LTempo: TContextProfile;
  LResult: TContextProfile;
  LBundle: TContextLearningBundle;
  LOutput: String;
  LProgress: TConsoleWorkProgress;
  LKeyIdentity: String;
  LTempoIdentity: String;
  LBytes: TAudioBytes;
begin
  if ParamCount <> 3 then
  begin
    raise EAudio.Create('Usage: pythian.context.select --source INPUT.ptc OUTPUT.pcp; or KEY.pcp TEMPO.pcp OUTPUT.pcp');
  end;
  LOutput := ExpandFileName(ParamStr(3));
  if (CompareText(LOutput, ExpandFileName(ParamStr(2))) = 0) or
    ((ParamStr(1) <> '--source') and
    (CompareText(LOutput, ExpandFileName(ParamStr(1))) = 0)) then
  begin
    raise EAudio.Create('Context profile output must not replace either input');
  end;
  LKey := nil;
  LTempo := nil;
  LResult := nil;
  LBundle := nil;
  LProgress := TConsoleWorkProgress.Create;
  try
    if ParamStr(1) = '--source' then
    begin
      LBundle := DecodeContextLearning(ReadFileBytes(ParamStr(2), MaximumContextArchiveBytes),
        LProgress.Observe);
      LResult := TContextProfile.Create(LBundle, LProgress.Observe);
    end
    else
    begin
      LKey := DecodeContextProfile(ReadFileBytes(ParamStr(1), MaximumContextProfileBytes),
        LProgress.Observe);
      LTempo := DecodeContextProfile(ReadFileBytes(ParamStr(2), MaximumContextProfileBytes),
        LProgress.Observe);
      LResult := SelectContextProfile(LKey, LTempo, LProgress.Observe);
    end;
    LKeyIdentity := LResult.ProviderIdentity(cdKey, LProgress.Observe);
    LTempoIdentity := LResult.ProviderIdentity(cdTempo, LProgress.Observe);
    LBytes := EncodeContextProfile(LResult, LProgress.Observe);
    { All observable work precedes the existing file publication boundary. }
    WriteFileBytes(ParamStr(3), LBytes);
    WriteLn('Profile ', LResult.Identity);
    WriteLn('Key bundle ', LKeyIdentity);
    WriteLn('Tempo bundle ', LTempoIdentity);
    WriteLn('PPQ ', LResult.TicksPerQuarter, '; step ', LResult.StepTicks,
      '; depth ', LResult.Depth, '; nodes ', LResult.NodeCount);
  finally
    LBundle.Free;
    LResult.Free;
    LTempo.Free;
    LKey.Free;
    LProgress.Free;
  end;
end;

begin
  try
    Run;
  except
    on LException: Exception do
    begin
      WriteLn(StdErr, LException.ClassName, ': ', LException.Message);
      Halt(1);
    end;
  end;
end.
