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
unit pythian.tools.progress;

{$mode delphi}{$H+}

interface

uses
  pythian.progress;

type
  { Native presentation only. Per-stage throttling retains interleaved phase
    counters, starts/resets and completion without logging every core block. }
  TConsoleWorkProgress = class
  private
    type
      TStage = record
        Name: String;
        Units: TWorkUnit;
        Pass: Integer;
        LastDone: Int64;
        LastTotal: Int64;
        EmittedAt: QWord;
      end;
    var
      FStages: array of TStage;
  public
    procedure Observe(const AProgress: TWorkProgress);
  end;

implementation

uses
  SysUtils;

procedure TConsoleWorkProgress.Observe(const AProgress: TWorkProgress);
var
  LIndex: Integer;
  LNow: QWord;
  LEmit: Boolean;
begin
  LIndex := 0;
  while (LIndex < Length(FStages)) and (FStages[LIndex].Name <> AProgress.Stage) do
    Inc(LIndex);
  LEmit := LIndex = Length(FStages);
  if LEmit then
  begin
    SetLength(FStages, LIndex + 1);
    FStages[LIndex].Name := AProgress.Stage;
  end;
  LNow := GetTickCount64;
  LEmit := LEmit or (AProgress.Done = 0) or
    (AProgress.Done < FStages[LIndex].LastDone) or
    (AProgress.Total <> FStages[LIndex].LastTotal) or
    (AProgress.Units <> FStages[LIndex].Units) or
    (AProgress.Pass <> FStages[LIndex].Pass) or
    ((AProgress.Total > 0) and (AProgress.Done = AProgress.Total)) or
    (LNow - FStages[LIndex].EmittedAt >= 250);
  FStages[LIndex].Units := AProgress.Units;
  FStages[LIndex].Pass := AProgress.Pass;
  FStages[LIndex].LastDone := AProgress.Done;
  FStages[LIndex].LastTotal := AProgress.Total;
  if LEmit then
  begin
    Write(StdErr, AProgress.Stage, ' ', AProgress.Done);
    if AProgress.Total > 0 then
      Write(StdErr, '/', AProgress.Total);
    Write(StdErr, ' ', WorkUnitName(AProgress.Units));
    if AProgress.Pass > 0 then
      Write(StdErr, ' pass ', AProgress.Pass);
    WriteLn(StdErr);
    FStages[LIndex].EmittedAt := LNow;
  end;
end;

end.
