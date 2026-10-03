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
program pythian_tests_progress_portable;
{$mode delphi}
{$H+}
uses SysUtils, pythian.audio, pythian.progress;
type
  TObserver = class
    Last: TWorkProgress;
    Abort: Boolean;
    procedure Receive(const AProgress: TWorkProgress);
  end;
procedure TObserver.Receive(const AProgress: TWorkProgress);
begin
  Last := AProgress;
  if Abort then raise EAudio.Create('Caller cancelled');
end;
var P: TObserver; Rejected: Boolean;
begin
  P := TObserver.Create;
  try
    ReportWork(P.Receive, 'large-file', wuBytes, Int64(2147483648), Int64(4294967296), 3);
    if (P.Last.Done <> Int64(2147483648)) or (P.Last.Total <> Int64(4294967296)) or
      (P.Last.Pass <> 3) or (WorkUnitName(P.Last.Units) <> 'bytes') then
      raise Exception.Create('Callback truncated a large source count');
    ReportWork(P.Receive, 'discover', wuItems, 123, 0);
    if (P.Last.Done <> 123) or (P.Last.Total <> 0) then
      raise Exception.Create('Unknown total changed');
    P.Abort := True; Rejected := False;
    try ReportWork(P.Receive, 'stop', wuFrames, 1, 2)
    except on EAudio do Rejected := True end;
    if not Rejected then raise Exception.Create('Callback exception swallowed');
    P.Abort := False; Rejected := False;
    try ReportWork(P.Receive, 'invalid', wuFrames, 3, 2)
    except on EAudio do Rejected := True end;
    if not Rejected then raise Exception.Create('Invalid progress accepted');
    WriteLn('PASS portable progress: large counts, unknown totals and exception propagation');
  finally P.Free end;
end.