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
unit pythian.tools.studio.progress;

{$mode delphi}
{$H+}

interface

const
  StudioRenderStatusIntervalMilliseconds = 2000;

type
  { One rendering publication clock for coarse output frames and nested WFC
    phases. The host supplies monotonic milliseconds and still checks control
    on every callback. Start, first detailed work and final output survive;
    fine phase boundaries share the two-second cadence. A24-hour stream then
    needs fewer than100000 events, without changing that existing job limit.
    Initialize with Default; this record owns no clock, callback or job file. }
  TStudioRenderProgressGate = record
  private
    FPublished: Boolean;
    FObservedAudio: Boolean;
    FLastAt: QWord;
    FLastStage: String;
    FLastDone: Int64;
    FLastTotal: Int64;
  public
    function Accept(const AStage: String; const ADone, ATotal: Int64;
      const AAt: QWord; const AAudioWork: Boolean): Boolean;
  end;

implementation

uses pythian.audio;

function TStudioRenderProgressGate.Accept(const AStage: String;
  const ADone, ATotal: Int64; const AAt: QWord;
  const AAudioWork: Boolean): Boolean;
var
  LFinalOutput: Boolean;
begin
  if FPublished and (AAt < FLastAt) then
  begin
    raise EAudio.Create('Studio progress requires a monotonic host clock');
  end;
  LFinalOutput := not AAudioWork and (ATotal > 0) and (ADone = ATotal);
  if LFinalOutput then
  begin
    Result := not FPublished or (FLastStage <> AStage) or
      (FLastDone <> ADone) or (FLastTotal <> ATotal);
  end
  else
  begin
    Result := not FPublished or (AAudioWork and not FObservedAudio) or
      (AAt - FLastAt >= StudioRenderStatusIntervalMilliseconds);
  end;
  if Result then
  begin
    FPublished := True;
    FObservedAudio := FObservedAudio or AAudioWork;
    FLastAt := AAt;
    FLastStage := AStage;
    FLastDone := ADone;
    FLastTotal := ATotal;
  end;
end;

end.
