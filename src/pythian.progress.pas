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
unit pythian.progress;

{$mode delphi}
{$H+}

interface

type
  TWorkUnit = (wuItems, wuBytes, wuFrames, wuObservations, wuMilliseconds);
  TWorkProgress = record
    Stage: String;
    Done, Total: Int64;
    Units: TWorkUnit;
    Pass: Integer;
  end;
  { Synchronous, borrowed callback. Raise to abort; exceptions propagate.
    Do not re-enter the operation or mutate its input. Total=0 means unknown
    (or empty), never a percentage. Counts describe THIS stage/pass, not overall
    success. Hosts own scheduling, throttling, UI and final publication. Callbacks
    do not yield a browser event loop; schedule bulk work off the UI thread.
    No timestamps, threads, I/O or devices belong to this portable contract. }
  TWorkProgressCallback = procedure(const AProgress: TWorkProgress) of object;
  { Caller-owned accumulation for compound operations. No automatic reset.
    Invalid or excessive charges reject before changing Used. }
  TWorkBudget = class
  private
    FMaximum, FUsed: Int64;
    FName: String;
    function GetRemaining: Int64;
  public
    constructor Create(const AMaximum: Int64; const AName: String);
    procedure Charge(const AUnits: Int64);
    property Maximum: Int64 read FMaximum;
    property Used: Int64 read FUsed;
    property Remaining: Int64 read GetRemaining;
  end;

procedure ReportWork(const ACallback: TWorkProgressCallback; const AStage: String;
  const AUnits: TWorkUnit; const ADone, ATotal: Int64; const APass: Integer = 0);
function WorkUnitName(const AUnits: TWorkUnit): String;

implementation

uses pythian.audio;

constructor TWorkBudget.Create(const AMaximum: Int64; const AName: String);
begin
  inherited Create;
  if not ((AMaximum > 0) and (AMaximum <= 9007199254740991) and
    (AMaximum = Trunc(AMaximum)) and (Length(AName) > 0) and (Length(AName) <= 255)) then
    raise EAudio.Create('Work budget requires a positive exact maximum and bounded name');
  FMaximum := AMaximum; FName := AName;
end;

function TWorkBudget.GetRemaining: Int64;
begin Result := FMaximum - FUsed end;

procedure TWorkBudget.Charge(const AUnits: Int64);
begin
  if not ((AUnits >= 0) and (AUnits <= Remaining) and (AUnits = Trunc(AUnits))) then
    raise EAudio.Create(FName + ' exceeds its declared aggregate work budget');
  Inc(FUsed, AUnits);
end;

procedure ReportWork(const ACallback: TWorkProgressCallback; const AStage: String;
  const AUnits: TWorkUnit; const ADone, ATotal: Int64; const APass: Integer);
var LProgress: TWorkProgress;
begin
  if not Assigned(ACallback) then Exit;
  if (ADone < 0) or (ATotal < 0) or ((ATotal > 0) and (ADone > ATotal)) or
    (APass < 0) then raise EAudio.Create('Invalid work progress');
  LProgress.Stage := AStage;
  LProgress.Done := ADone; LProgress.Total := ATotal;
  LProgress.Units := AUnits; LProgress.Pass := APass;
  ACallback(LProgress);
end;

function WorkUnitName(const AUnits: TWorkUnit): String;
begin
  case AUnits of
    wuBytes: Result := 'bytes';
    wuFrames: Result := 'frames';
    wuObservations: Result := 'observations';
    wuMilliseconds: Result := 'milliseconds';
  else Result := 'items';
  end;
end;

end.
