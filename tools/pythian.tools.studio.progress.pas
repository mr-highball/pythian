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
  StudioSlowStatusIntervalMilliseconds = 30000;

type
  { Big Boss: workflow steps are not an elapsed-time estimate. Only explicit
    orchestration boundaries advance them; nested algorithms cannot reset them.
    Selection time is cumulative across recordings, including cached windows. }
  TStudioGenerationProgress = record
    Phase: Integer;
    Done: Int64;
    Total: Int64;
    Units: String;
    procedure Observe(const AStage: String; const ADone, ATotal: Int64);
  end;

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
    FInterval: QWord;
    FLastStage: String;
    FLastDone: Int64;
    FLastTotal: Int64;
  public
    function Accept(const AStage: String; const ADone, ATotal: Int64;
      const AAt: QWord; const AAudioWork: Boolean;
      const AForce: Boolean = False): Boolean;
    { The host reports completion of its durable publication. Publication time
      is not useful processing time and must not satisfy the next interval. }
    procedure PublishedAt(const AAt: QWord);
  end;

implementation

uses pythian.audio;

procedure TStudioGenerationProgress.Observe(const AStage: String;
  const ADone, ATotal: Int64);
var
  LPhase: Integer;
  LUnits: String;
begin
  LPhase := 0;
  LUnits := '';
  if AStage = 'instrumental_prepare' then LPhase := 1
  else if AStage = 'playlist_selection_progress' then
  begin
    LPhase := 1;
    LUnits := 'milliseconds';
  end
  else if (AStage = 'playlist_learn_music') or
    (AStage = 'instrumental_plan_begin') then LPhase := 2
  else if AStage = 'instrumental_render' then
  begin
    LPhase := 3;
    LUnits := 'frames';
  end
  else if AStage = 'instrumental_save' then LPhase := 4
  else if AStage = 'instrumental_publish' then
  begin
    LPhase := 4;
    LUnits := 'save_steps';
  end;
  if (LPhase = 0) or (LPhase < Phase) then Exit;
  if LPhase > Phase then
  begin
    Phase := LPhase;
    Done := 0;
    Total := 0;
    Units := '';
  end;
  if LUnits = '' then Exit;
  if (ADone < 0) or (ATotal <= 0) or (ADone > ATotal) or
    ((Total > 0) and ((ATotal <> Total) or (ADone < Done))) then
    raise EAudio.Create('Invalid cumulative Generate progress');
  Done := ADone;
  Total := ATotal;
  Units := LUnits;
end;

procedure TStudioRenderProgressGate.PublishedAt(const AAt: QWord);
var LCost: QWord;
begin
  if not FPublished or (AAt < FLastAt) then
  begin
    raise EAudio.Create('Studio publication completion requires an accepted monotonic clock');
  end;
  { Big Boss: a slow durable close must not dominate useful work. Spend at
    least four times its measured cost between fine publications, bounded
    to thirty seconds. Cancellation and terminal transitions are separate. }
  LCost := AAt - FLastAt;
  if LCost >= StudioSlowStatusIntervalMilliseconds div 4 then
    FInterval := StudioSlowStatusIntervalMilliseconds
  else FInterval := LCost * 4;
  if FInterval < StudioRenderStatusIntervalMilliseconds then
    FInterval := StudioRenderStatusIntervalMilliseconds;
  FLastAt := AAt;
end;

function TStudioRenderProgressGate.Accept(const AStage: String;
  const ADone, ATotal: Int64; const AAt: QWord;
  const AAudioWork: Boolean; const AForce: Boolean): Boolean;
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
    Result := AForce or not FPublished or (AAudioWork and not FObservedAudio) or
      ((AAt - FLastAt >= StudioRenderStatusIntervalMilliseconds) and
       (AAt - FLastAt >= FInterval));
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
