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
program RenderProgress;
{$mode delphi}
{$H+}
uses SysUtils, pythian.audio, pythian.progress, pythian.synth,
  pythian.music, pythian.time, pythian.music.render, pythian.granular;
type
  EAbortProbe = class(Exception);
  TProbe = class
    Stage: String;
    Calls: Integer;
    LastDone: Int64;
    Total: Int64;
    AbortStage: String;
    AllocationTotal: Int64;
    procedure Work(const AWork: TWorkProgress);
  end;
var
  Checks: Integer;
procedure Check(const AValue: Boolean; const AText: String);
begin
  Inc(Checks);
  if not AValue then
  begin
    raise Exception.Create(AText);
  end;
end;
procedure TProbe.Work(const AWork: TWorkProgress);
begin
  Check(AWork.Units = wuFrames, 'Frame units');
  if (Stage <> AWork.Stage) or (AWork.Done = 0) then
  begin
    Stage := AWork.Stage;
    LastDone := 0;
    Total := AWork.Total;
  end;
  Check((AWork.Total = Total) and (AWork.Done >= LastDone) and
    (AWork.Done <= AWork.Total), 'Monotonic stage progress');
  LastDone := AWork.Done;
  if Stage = 'synth_allocate_frames' then
  begin
    AllocationTotal := AWork.Total;
  end;
  Inc(Calls);
  if (Stage = AbortStage) and (AWork.Done > 0) and (AWork.Done < AWork.Total) then
  begin
    raise EAbortProbe.Create('original abort');
  end;
end;
procedure Compare(const A, B: TAudioClip);
var
  I: Integer;
  C: Integer;
begin
  Check(A.FrameCount = B.FrameCount, 'Frame count parity');
  for I := 0 to A.FrameCount - 1 do
  begin
    for C := 0 to A.Channels - 1 do
    begin
      if A.SampleAt(I, C) <> B.SampleAt(I, C) then
      begin
        raise Exception.Create('Sample parity');
      end;
    end;
  end;
  Inc(Checks);
end;
var
  Probe: TProbe;
  Tones: TFrameTones;
  Timed: TTones;
  A: TAudioClip;
  B: TAudioClip;
  Sources: TAudioSources;
  Samples: TAudioSamples;
  Grains: TAudioGrains;
  Options: TGrainRenderOptions;
  Notes: TNoteGates;
  Tempos: TTempoChanges;
  Sequence: TNoteSequence;
  Report: TNoteRenderReport;
  I: Integer;
  Failed: Boolean;
begin
  Probe := TProbe.Create;
  try
    SetLength(Tones, 2);
    for I := 0 to 1 do
    begin
      Tones[I].Voice := DefaultSynthVoice;
      Tones[I].StartFrame := I * 2000;
      Tones[I].GateFrames := 12000;
      Tones[I].FrequencyHz := 220 * (I + 1);
      Tones[I].Velocity := 0.6;
    end;
    A := RenderFrameTones(Tones, 8000, 30000);
    try
      B := RenderFrameTones(Tones, 8000, 30000, Probe.Work);
      try
        Compare(A, B);
      finally
        B.Free;
      end;
      Check((Probe.Stage = 'synth_voice_frames') and (Probe.LastDone = Probe.Total) and
        (Probe.Total > 24000) and (Probe.Calls < 20) and (Probe.AllocationTotal = 30000),
        'Synth voice and sparse output work with bounded callbacks');
      Probe.AbortStage := 'synth_voice_frames';
      Failed := False;
      try
        B := RenderFrameTones(Tones, 8000, 30000, Probe.Work);
        B.Free;
      except
        on E: EAbortProbe do
        begin
          Failed := E.Message = 'original abort';
        end;
      end;
      Check(Failed, 'Synth interior abort propagated');
      Probe.AbortStage := '';
      B := RenderFrameTones(Tones, 8000, 30000, Probe.Work);
      try
        Compare(A, B);
      finally
        B.Free;
      end;
    finally
      A.Free;
    end;
    SetLength(Timed, 1);
    Timed[0].Voice := DefaultSynthVoice;
    Timed[0].GateSeconds := 2;
    Timed[0].FrequencyHz := 440;
    Timed[0].Velocity := 0.5;
    A := RenderTones(Timed, 8000, 4);
    try
      B := RenderTones(Timed, 8000, 4, Probe.Work);
      try
        Compare(A, B);
      finally
        B.Free;
      end;
    finally
      A.Free;
    end;
    SetLength(Notes, 2);
    for I := 0 to 1 do
    begin
      Notes[I].StartTick := 0;
      Notes[I].EndTick := 960;
      Notes[I].Pitch := 60 + 7 * I;
      Notes[I].Velocity := 100;
    end;
    SetLength(Tempos, 1);
    Tempos[0] := MakeTempoChange(0, 500000);
    Sequence := TNoteSequence.Create(480, 3840, Tempos, Notes);
    try
      A := RenderNoteSequence(Sequence, 8000, DefaultSynthVoice, Report);
      try
        B := RenderNoteSequence(Sequence, 8000, DefaultSynthVoice, Report, Probe.Work);
        try
          Compare(A, B);
        finally
          B.Free;
        end;
      finally
        A.Free;
      end;
    finally
      Sequence.Free;
    end;
    SetLength(Samples, 40000);
    for I := 0 to High(Samples) do
    begin
      Samples[I] := (I mod 31) / 100;
    end;
    SetLength(Sources, 1);
    Sources[0] := TAudioClip.Create(8000, 1, Samples);
    try
      SetLength(Grains, 2);
      for I := 0 to 1 do
      begin
        Grains[I].SourceIndex := 0;
        Grains[I].FrameCount := 12000;
        Grains[I].OutputStartFrame := I * 5000;
        Grains[I].PlaybackRate := 1;
        Grains[I].Gain := 0.5;
      end;
      Options := DefaultGrainRenderOptions(8000, 1);
      Options.MinimumFrames := 35000;
      A := RenderGrains(Sources, Grains, Options);
      try
        Probe.Calls := 0;
        B := RenderGrains(Sources, Grains, Options, Probe.Work);
        try
          Compare(A, B);
        finally
          B.Free;
        end;
        Check((Probe.Stage = 'grain_output_frames') and (Probe.Total = 35000) and
          (Probe.LastDone = 35000) and (Probe.Calls < 20), 'Grain trailing silence counted');
        Probe.AbortStage := 'grain_mix_frames';
        Failed := False;
        try
          B := RenderGrains(Sources, Grains, Options, Probe.Work);
          B.Free;
        except
          on E: EAbortProbe do
          begin
            Failed := E.Message = 'original abort';
          end;
        end;
        Check(Failed, 'Grain interior abort propagated');
        Probe.AbortStage := 'grain_output_frames';
        Failed := False;
        try
          B := RenderGrains(Sources, Grains, Options, Probe.Work);
          B.Free;
        except
          on E: EAbortProbe do
          begin
            Failed := E.Message = 'original abort';
          end;
        end;
        Check(Failed, 'Grain output abort propagated');
        Probe.AbortStage := '';
        B := RenderGrains(Sources, Grains, Options, Probe.Work);
        try
          Compare(A, B);
        finally
          B.Free;
        end;
      finally
        A.Free;
      end;
    finally
      Sources[0].Free;
    end;
    WriteLn('PASS ', Checks, ' render progress checks');
  finally
    Probe.Free;
  end;
end.
