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
program StudioProgressConformance;

{$mode delphi}
{$H+}

uses SysUtils, pythian.audio, pythian.tools.studio.progress;

var
  GChecks: Integer;

procedure Check(const ACondition: Boolean; const AMessage: String);
begin
  Inc(GChecks);
  if not ACondition then raise Exception.Create(AMessage);
end;

procedure Boundaries;
var
  LGate: TStudioRenderProgressGate;
  LRejected: Boolean;
begin
  LGate := Default(TStudioRenderProgressGate);
  Check(LGate.Accept('streaming', 0, 100, 0, False), 'Initial frame status missing');
  Check(LGate.Accept('wfc_model_construct_visits', 0, 0, 0, True),
    'First detailed WFC work missing');
  Check(not LGate.Accept('wfc_model_apply_visits', 1, 1, 1, True),
    'A fine phase boundary bypassed the shared publication interval');
  Check(not LGate.Accept('streaming', 1, 100, 1000, False),
    'Coarse frames used a second publication clock');
  Check(LGate.Accept('wfc_solve_search_visits', 257, 0, 2000, True),
    'Real unknown-total work was not eligible after the interval');
  Check(LGate.Accept('streaming', 100, 100, 2001, False),
    'Final exact output count was throttled');
  Check(not LGate.Accept('streaming', 100, 100, 2002, False),
    'Duplicate final status needlessly consumed an event');
  LRejected := False;
  try
    LGate.Accept('streaming', 1, 100, 1999, False);
  except
    on EAudio do LRejected := True;
  end;
  Check(LRejected, 'Backward publication clock accepted');
  Check(LGate.Accept('wfc_solve_search_visits', 513, 0, 4001, True),
    'Rejected clock changed later valid activity');
end;

procedure WholeDay;
const
  CTicks = 24 * 60 * 60 * 4;
var
  LGate: TStudioRenderProgressGate;
  LTick: Integer;
  LPhase: Integer;
  LAt: QWord;
  LPublished: Integer;
  LStage: String;
begin
  LGate := Default(TStudioRenderProgressGate);
  LPublished := 0;
  for LTick := 0 to CTicks - 1 do
  begin
    LAt := QWord(LTick) * 250;
    { An adversarial caller supplies four fine boundaries and coarse frames
      every250ms. This is more frequent than a real long-playback pull. }
    for LPhase := 0 to 3 do
    begin
      case LPhase of
        0: LStage := 'wfc_solve_search_visits';
        1: LStage := 'sequence_segment_publication_ready';
        2: LStage := 'wfc_sequence_mask_rows';
      else LStage := 'audio_pull_ready';
      end;
      if LGate.Accept(LStage, LTick + 1, LTick + 1, LAt, True) then
        Inc(LPublished);
    end;
    if LGate.Accept('streaming', LTick, CTicks, LAt, False) then
      Inc(LPublished);
  end;
  Check(LGate.Accept('streaming', CTicks, CTicks, QWord(CTicks) * 250, False),
    '24-hour simulation lost its final frame status');
  Inc(LPublished);
  Check((LPublished > 1) and (LPublished < 100000),
    '24-hour rendering exhausted the unchanged native job event limit');
  WriteLn('24-hour rendering: ', CTicks * 5, ' offered statuses, ',
    LPublished, ' published, existing limit100000');
end;

procedure SlowPublication;
var
  LGate: TStudioRenderProgressGate;
  LRejected: Boolean;
begin
  LGate := Default(TStudioRenderProgressGate);
  LRejected := False;
  try LGate.PublishedAt(1000); except on EAudio do LRejected := True end;
  Check(LRejected, 'Completion without an accepted publication is invalid');
  Check(LGate.Accept('instrumental_prepare', 0, 1, 1000, True), 'First instrumental work');
  LGate.PublishedAt(11000);
  Check(not LGate.Accept('wfc_model_ready', 1, 1, 11001, True),
    'Slow durable publication itself made a fine endpoint eligible');
  Check(not LGate.Accept('voice_constraints_ready', 1, 1, 12000, True),
    'Changing a fine stage bypassed the completed-publication interval');
  Check(not LGate.Accept('instrumental_render', 4096, 10000, 13000, True),
    'Slow storage backs off fine publications');
  Check(not LGate.Accept('instrumental_render', 4096, 10000, 40999, True),
    'Storage backoff has an explicit bounded interval');
  Check(LGate.Accept('instrumental_render', 4096, 10000, 41000, True),
    'Real work remains visible within thirty seconds after publication');
  LRejected := False;
  try LGate.PublishedAt(40999); except on EAudio do LRejected := True end;
  Check(LRejected, 'Backward completion time is invalid');
  LGate.PublishedAt(41000);
  Check(not LGate.Accept('instrumental_ready', 1, 1, 41000, True),
    'A nested ready endpoint is not a terminal job transition');
  Check(LGate.Accept('instrumental_render', 8192, 10000, 43000, True),
    'Fast publication restores the ordinary two-second interval');
end;

procedure GenerateWorkflow;
var
  LView: TStudioGenerationProgress;
  LGate: TStudioRenderProgressGate;
  LRejected: Boolean;
begin
  LView := Default(TStudioGenerationProgress);
  LView.Observe('instrumental_prepare', 0, 1);
  LView.Observe('playlist_selection_progress', 30000, 135000);
  LView.Observe('estimate_pitch', 0, 100);
  LView.Observe('analyze_audio', 100, 100);
  LView.Observe('playlist_prepare_music', 1, 2);
  Check((LView.Phase = 1) and (LView.Done = 30000) and
    (LView.Total = 135000), 'Nested analyses and next recording preserve cumulative selection');
  LRejected := False;
  try LView.Observe('playlist_selection_progress', 0, 135000);
  except on EAudio do LRejected := True end;
  Check(LRejected and (LView.Done = 30000), 'Cumulative selection cannot reset');
  LRejected := False;
  try LView.Observe('playlist_selection_progress', 30001, 200000);
  except on EAudio do LRejected := True end;
  Check(LRejected and (LView.Total = 135000), 'Selection denominator stays fixed');
  LView.Observe('playlist_selection_progress', 135000, 135000);
  LView.Observe('playlist_learn_music', 0, 1);
  Check((LView.Phase = 2) and (LView.Total = 0), 'Planning has no invented work percentage');
  LView.Observe('playlist_selection_progress', 0, 135000);
  Check(LView.Phase = 2, 'Earlier nested stage cannot move workflow backwards');
  LView.Observe('instrumental_render', 100, 700);
  LView.Observe('instrument_stream_ready', 20, 20);
  Check((LView.Phase = 3) and (LView.Done = 100) and (LView.Total = 700),
    'A completed nested pull does not reset whole-performance progress');
  LView.Observe('instrumental_render', 700, 700);
  Check(LView.Phase = 3, 'Finished PCM is not a saved job');
  LView.Observe('instrumental_save', 0, 1);
  Check((LView.Phase = 4) and (LView.Total = 0), 'Final save remains a real separate phase');
  LView.Observe('instrumental_publish', 0, 8);
  LView.Observe('instrumental_publish', 3, 8);
  LView.Observe('instrumental_stream_plan', 0, 100);
  Check((LView.Phase = 4) and (LView.Done = 3) and (LView.Total = 8),
    'Confirmed saved outputs preserve cumulative finalization progress');
  LView.Observe('instrumental_publish', 7, 8);
  LView.Observe('instrumental_save', 0, 1);
  Check((LView.Done = 7) and (LView.Total = 8),
    'Seven saved audio outputs leave final publication unfinished until job success');
  LGate := Default(TStudioRenderProgressGate);
  Check(LGate.Accept('start', 0, 1, 0, True), 'Workflow publication initialized');
  LGate.PublishedAt(10000);
  Check(LGate.Accept('instrumental_save', 0, 1, 10000, True, True),
    'A workflow boundary is published even on slow storage');
end;

begin
  Boundaries;
  WholeDay;
  SlowPublication;
  GenerateWorkflow;
  WriteLn('PASS ', GChecks, ' Studio rendering publication checks');
end.
