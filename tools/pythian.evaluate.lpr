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
program pythian_evaluate;

{$mode delphi}
{$H+}

uses
  SysUtils, pythian.tools.evaluate;

begin
  try
    if (ParamCount = 4) and (ParamStr(1) = '--build-part-reference') then
    begin
      WriteLn(BuildPartReferenceFile(ParamStr(2), ParamStr(3), ParamStr(4)));
    end
    else if ParamCount = 1 then
    begin
      WriteLn(EvaluateCaseFile(ParamStr(1)));
    end
    else
    begin
      raise Exception.Create('Usage: pythian.evaluate CASE.json OR ' +
        '--build-part-reference DRAFT.json SHA256 SOURCE.wav (JSON on stdout)');
    end;
  except
    on E: Exception do
    begin
      WriteLn(StdErr, E.Message);
      ExitCode := 1;
    end;
  end;
end.
