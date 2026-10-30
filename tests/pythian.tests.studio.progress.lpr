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
  Check(LGate.Accept('instrumental_render', 4096, 10000, 13000, True),
    'Real work after the interval remains visible');
  LRejected := False;
  try LGate.PublishedAt(12999); except on EAudio do LRejected := True end;
  Check(LRejected, 'Backward completion time is invalid');
  LGate.PublishedAt(14000);
  Check(not LGate.Accept('instrumental_ready', 1, 1, 14000, True),
    'A nested ready endpoint is not a terminal job transition');
end;

begin
  Boundaries;
  WholeDay;
  SlowPublication;
  WriteLn('PASS ', GChecks, ' Studio rendering publication checks');
end.
