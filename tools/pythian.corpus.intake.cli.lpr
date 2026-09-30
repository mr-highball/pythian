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
program pythian_corpus_intake_cli;

{$mode delphi}
{$H+}

uses
  SysUtils, pythian.corpus.intake, pythian.tools.corpus.intake;

var
  P, H: TCorpusIntakePlan;
  A: TCorpusAdmission;
  LHistory: String;
begin
  P := nil; H := nil; A := nil;
  try
    try
      if (ParamCount = 2) and (ParamStr(1) = 'roundtrip') then
      begin
        P := ReadCorpusIntake(ParamStr(2));
        WriteLn(EncodeCorpusIntake(P));
      end
      else if ((ParamCount = 2) or (ParamCount = 4)) and (ParamStr(1) = 'verify') then
      begin
        P := ReadCorpusIntake(ParamStr(2));
        if ParamCount = 4 then
        begin
          if ParamStr(3) <> '--history' then raise Exception.Create('Expected --history');
          H := ReadCorpusIntake(ParamStr(4)); RequireIntakeHistory(H, P);
        end;
        A := TCorpusAdmission.Create(P, ExtractFilePath(ExpandFileName(ParamStr(2))));
        WriteLn(CorpusIntakeAuditJSON(P));
      end
      else if ((ParamCount = 3) or (ParamCount = 5)) and (ParamStr(1) = 'learn') then
      begin
        LHistory := '';
        if ParamCount = 5 then
        begin
          if ParamStr(4) <> '--history' then raise Exception.Create('Expected --history');
          LHistory := ParamStr(5);
        end;
        LearnCorpusIntake(ParamStr(2), ParamStr(3), LHistory);
        WriteLn('Published verified intake, acoustic vocabulary/WFC model and audit');
      end
      else
        raise Exception.Create('Usage: roundtrip MANIFEST | verify MANIFEST [--history LEDGER] | learn MANIFEST FRESH_PREFIX [--history LEDGER]');
    finally
      A.Free; H.Free; P.Free;
    end;
  except
    on E: Exception do
    begin
      WriteLn(StdErr, E.Message);
      ExitCode := 1;
    end;
  end;
end.
