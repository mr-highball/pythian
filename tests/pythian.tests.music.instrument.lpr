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
program pythian_music_instrument_test;
{$mode delphi}
{$H+}

uses
  SysUtils, pythian.audio, pythian.time, pythian.music, pythian.music.render,
  pythian.synth, pythian.instrument;

procedure Check(const ACondition: Boolean; const AMessage: String);
begin
  if not ACondition then
  begin
    raise Exception.Create(AMessage);
  end;
end;

procedure Run;
var
  LZones: TInstrumentZones;
  LBindings: TNoteInstruments;
  LLayered: TInstrument;
  LSingle: TInstrument;
  LGates: TNoteGates;
  LTempos: TTempoChanges;
  LSequence: TNoteSequence;
  LPlan: TFrameTones;
  LManual: TFrameTones;
  LReport: TNoteRenderReport;
  LActual: TAudioClip;
  LExpected: TAudioClip;
  LRejected: Boolean;
  I: Integer;
  J: Integer;

  procedure RejectPlan(const AMessage: String);
  begin
    LRejected := False;
    try
      LPlan := PlanNoteTones(LSequence, 8000, LBindings, LReport);
    except
      on EAudio do
      begin
        LRejected := True;
      end;
    end;
    Check(LRejected and (Length(LPlan) = 3) and (LPlan[0].StartFrame = 1000),
      AMessage + ': prior plan');
    Check((LReport.SourceNotes = 0) and (LReport.RenderedNotes = 0) and
      (LReport.SubFrameNotes = 0) and (LReport.RenderedTones = 0),
      AMessage + ': reset report');
  end;

begin
  LLayered := nil;
  LSingle := nil;
  LSequence := nil;
  try
    SetLength(LZones, 2);
    for I := 0 to 1 do
    begin
      LZones[I].MinimumKey := 69;
      LZones[I].MaximumKey := 69;
      LZones[I].MinimumVelocity := 1;
      LZones[I].MaximumVelocity := 127;
      LZones[I].Voice := DefaultSynthVoice;
      LZones[I].Voice.Envelope.ReleaseSeconds := 0;
      LZones[I].Voice.Pan := -0.4 + I * 0.8;
      LZones[I].Voice.Gain := 0.2 + I * 0.1;
    end;
    LLayered := TInstrument.Create(LZones);
    LSingle := TInstrument.Create(Copy(LZones, 1, 1));
    SetLength(LBindings, 2);
    LBindings[0] := LLayered;
    LBindings[1] := LSingle;
    SetLength(LTempos, 2);
    LTempos[0] := MakeTempoChange(0, 500001);
    LTempos[1] := MakeTempoChange(2400, 750001);
    SetLength(LGates, 3);
    for I := 0 to 2 do
    begin
      LGates[I].Pitch := 69;
      LGates[I].Velocity := 72;
      LGates[I].Track := 17;
    end;
    LGates[0].StartTick := 1200;
    LGates[0].EndTick := 3600;
    LGates[1].StartTick := 3600;
    LGates[1].EndTick := 4800;
    LGates[1].Voice := 1;
    LGates[2].EndTick := 1;
    LSequence := TNoteSequence.Create(4800, 4800, LTempos, LGates);
    LPlan := PlanNoteTones(LSequence, 8000, LBindings, LReport);
    Check((LReport.SourceNotes = 3) and (LReport.RenderedNotes = 2) and
      (LReport.SubFrameNotes = 1) and (LReport.RenderedTones = 3), 'Layer counts');
    SetLength(LManual, 3);
    for I := 0 to 2 do
    begin
      LManual[I].StartFrame := 1000;
      LManual[I].GateFrames := 2500;
      LManual[I].FrequencyHz := 440;
      LManual[I].Velocity := 72 / 127;
      LManual[I].Seed := 1;
      LManual[I].Voice := LZones[Ord(I > 0)].Voice;
    end;
    LManual[2].StartFrame := 3500;
    LManual[2].GateFrames := 1500;
    LManual[2].Seed := 2;
    for I := 0 to 2 do
    begin
      Check((LPlan[I].StartFrame = LManual[I].StartFrame) and
        (LPlan[I].GateFrames = LManual[I].GateFrames) and
        (LPlan[I].Seed = LManual[I].Seed), 'Exact endpoints and shared per-note seed');
    end;
    LExpected := RenderFrameTones(LManual, 8000, 5000);
    try
      LActual := RenderNoteSequence(LSequence, 8000, LBindings, LReport);
      try
        Check(LActual.FrameCount = 5000, 'Sequence extent');
        for I := 0 to 4999 do
        begin
          for J := 0 to 1 do
          begin
            Check(LActual.SampleAt(I, J) = LExpected.SampleAt(I, J),
              'Layered sequence PCM equals independent frame plan');
          end;
        end;
      finally
        LActual.Free;
      end;
    finally
      LExpected.Free;
    end;
    LBindings[1] := nil;
    RejectPlan('Missing later instrument');
    LBindings[1] := LSingle;
    FreeAndNil(LSequence);
    LGates[2].Pitch := 68;
    LSequence := TNoteSequence.Create(4800, 4800, LTempos, LGates);
    RejectPlan('Unmapped sub-frame note');
    FreeAndNil(LSequence);
    LGates[2].Pitch := 69;
    LGates[1].Pitch := 68;
    LSequence := TNoteSequence.Create(4800, 4800, LTempos, LGates);
    RejectPlan('Unmapped sounding note');
    FreeAndNil(LSequence);
    FreeAndNil(LLayered);
    FreeAndNil(LSingle);
    Check(LPlan[1].Voice.Pan = LManual[1].Voice.Pan, 'Plan survives instrument release');

    SetLength(LZones, MaximumInstrumentLayers);
    for I := 1 to High(LZones) do
    begin
      LZones[I] := LZones[0];
    end;
    LLayered := TInstrument.Create(LZones);
    SetLength(LBindings, 1);
    LBindings[0] := LLayered;
    SetLength(LGates, MaximumToneEvents div MaximumInstrumentLayers + 1);
    for I := 0 to High(LGates) do
    begin
      LGates[I] := Default(TNoteGate);
      LGates[I].Pitch := 69;
      LGates[I].Velocity := 72;
      LGates[I].EndTick := 2;
    end;
    LSequence := TNoteSequence.Create(4800, 4800, LTempos, LGates);
    RejectPlan('Expanded tone budget');
    FreeAndNil(LSequence);
    SetLength(LGates, Length(LGates) - 1);
    LSequence := TNoteSequence.Create(4800, 4800, LTempos, LGates);
    LPlan := PlanNoteTones(LSequence, 8000, LLayered, LReport);
    Check((Length(LPlan) = MaximumToneEvents) and
      (LReport.RenderedNotes = 4096) and (LReport.RenderedTones = 65536),
      'Exact expanded tone budget accepted');
  finally
    LSequence.Free;
    LSingle.Free;
    LLayered.Free;
  end;
end;

begin
  try
    Run;
    WriteLn('Instrument sequence: tempo boundaries, layered PCM, binding failures and expansion budget passed');
  except
    on LException: Exception do
    begin
      WriteLn(StdErr, LException.Message);
      Halt(1);
    end;
  end;
end.
