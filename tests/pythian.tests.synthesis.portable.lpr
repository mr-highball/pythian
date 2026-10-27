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
program SynthesisPortable;
{$mode delphi}
{$H+}
uses
  SysUtils,
  {$ifndef pas2js}Classes, Math,{$endif}
  pythian.audio,
  pythian.progress,
  pythian.synth,
  pythian.oscillator,
  pythian.source,
  pythian.source.sample,
  pythian.instrument,
  pythian.music,
  pythian.time,
  pythian.music.render,
  pythian.granular;
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
procedure EmitClip(const AName: String; const AClip: TAudioClip);
var
  I: Integer;
  C: Integer;
  LFormat: TFormatSettings;
begin
  {$ifdef pas2js}
  LFormat := TFormatSettings.Create;
  {$else}
  LFormat := DefaultFormatSettings;
  {$endif}
  LFormat.DecimalSeparator := '.';
  WriteLn('case ', AName, ' ', AClip.SampleRate, ' ', AClip.Channels, ' ', AClip.FrameCount);
  for I := 0 to AClip.FrameCount - 1 do
  begin
    for C := 0 to AClip.Channels - 1 do
    begin
      WriteLn('sample ', AName, ' ', I, ' ', C, ' ', FloatToStr(AClip.SampleAt(I, C), LFormat));
    end;
  end;
end;

{$ifndef pas2js}
procedure CompareLogs(const AFirst, ASecond: String);
var
  A: TStringList;
  B: TStringList;
  PA: TStringList;
  PB: TStringList;
  I: Integer;
  J: Integer;
  VA: Double;
  VB: Double;
  CaseIndex: Integer;
  FrameIndex: Integer;
  ChannelIndex: Integer;
  Frames: Integer;
  Channels: Integer;
  ExpectedName: String;
  LFormat: TFormatSettings;
begin
  LFormat := DefaultFormatSettings;
  LFormat.DecimalSeparator := '.';
  A := TStringList.Create;
  B := TStringList.Create;
  PA := TStringList.Create;
  PB := TStringList.Create;
  try
    A.LoadFromFile(AFirst);
    B.LoadFromFile(ASecond);
    Check((A.Count > 0) and (A.Count = B.Count), 'Cross-target row count');
    CaseIndex := 0;
    FrameIndex := 0;
    ChannelIndex := 0;
    Frames := 0;
    Channels := 0;
    ExpectedName := '';
    PA.Delimiter := ' ';
    PA.StrictDelimiter := True;
    PB.Delimiter := ' ';
    PB.StrictDelimiter := True;
    for I := 0 to A.Count - 1 do
    begin
      PA.DelimitedText := A[I];
      PB.DelimitedText := B[I];
      Check(PA.Count = PB.Count, 'Cross-target row shape');
      if (PA.Count > 0) and (PA[0] = 'sample') then
      begin
        Check((PA.Count = 5) and (CaseIndex >= 1) and (CaseIndex <= 4) and
          (FrameIndex < Frames), 'Sample row shape');
        Check((PA[1] = ExpectedName) and (PA[2] = IntToStr(FrameIndex)) and
          (PA[3] = IntToStr(ChannelIndex)), 'Sample row order');
        for J := 0 to 3 do
        begin
          Check(PA[J] = PB[J], 'Sample identity or clock mismatch');
        end;
        VA := StrToFloat(PA[4], LFormat);
        VB := StrToFloat(PB[4], LFormat);
        Check(not IsNan(VA) and not IsInfinite(VA) and not IsNan(VB) and
          not IsInfinite(VB), 'Nonfinite sample rejected');
        Check(Abs(VA - VB) <= 1E-6 * Max(1, Max(Abs(VA), Abs(VB))),
          'Sample exceeds predeclared cross-target tolerance');
        Inc(ChannelIndex);
        if ChannelIndex = Channels then
        begin
          ChannelIndex := 0;
          Inc(FrameIndex);
        end;
      end
      else
      begin
        Check(A[I] = B[I], 'Case identity or geometry mismatch');
        if (PA.Count > 0) and (PA[0] = 'case') then
        begin
          Check((PA.Count = 5) and (FrameIndex = Frames) and
            (ChannelIndex = 0) and (CaseIndex < 4), 'Case boundary');
          Inc(CaseIndex);
          case CaseIndex of
            1: ExpectedName := 'frame-tones-noise-731';
            2: ExpectedName := 'chord-clock';
            3: ExpectedName := 'grains-sinc';
            4: ExpectedName := 'instrument-owned-source';
          end;
          Check(PA[1] = ExpectedName, 'Expected case identity');
          Check((PA[2] = '8000') and TryStrToInt(PA[3], Channels) and
            TryStrToInt(PA[4], Frames) and (Channels in [1, 2]) and (Frames > 0),
            'Case geometry');
          case CaseIndex of
            1: Check((Channels = 2) and (Frames = 30000), 'Tone geometry');
            2: Check((Channels = 2) and (Frames = 32000), 'Chord geometry');
            3: Check((Channels = 1) and (Frames = 35000), 'Grain geometry');
            4: Check((Channels = 2) and (Frames = 1771), 'Instrument geometry');
          end;
          FrameIndex := 0;
          ChannelIndex := 0;
        end
        else
        begin
          Check((A[I] = 'pass synthesis-portable') and (I = A.Count - 1) and
            (CaseIndex = 4) and (FrameIndex = Frames) and (ChannelIndex = 0),
            'Final case or pass marker missing');
        end;
      end;
    end;
    Check((A[A.Count - 1] = 'pass synthesis-portable') and (CaseIndex = 4),
      'Final pass marker required');
  finally
    PB.Free;
    PA.Free;
    B.Free;
    A.Free;
  end;
  WriteLn('PASS cross-target synthesis comparison');
end;
{$endif}

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
  Zones: TInstrumentZones;
  Instrument: TInstrument;
  Indices: TInstrumentZoneIndices;
  Factory: TSampleSourceFactory;
  Plan: TFrameTones;
begin
  {$ifndef pas2js}
  if (ParamCount = 3) and (ParamStr(1) = '--compare') then
  begin
    CompareLogs(ParamStr(2), ParamStr(3));
    Exit;
  end;
  {$endif}
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
      Tones[I].Seed := 731 + I;
    end;
    Tones[1].Voice.Shape := wsNoise;
    A := RenderFrameTones(Tones, 8000, 30000);
    try
      EmitClip('frame-tones-noise-731', A);
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
        EmitClip('chord-clock', A);
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
        Grains[I].OutputStartFrame := I * 18000;
        Grains[I].PlaybackRate := 0.5;
        Grains[I].Gain := 0.5;
      end;
      Options := DefaultGrainRenderOptions(8000, 1);
      Options.MinimumFrames := 35000;
      Options.Interpolation := giSinc;
      A := RenderGrains(Sources, Grains, Options);
      try
        EmitClip('grains-sinc', A);
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
    SetLength(Samples, 4);
    Samples[0] := 0.5;
    Samples[1] := 0.25;
    Samples[2] := -0.5;
    Samples[3] := -0.25;
    A := TAudioClip.Create(8000, 1, Samples);
    try
      Factory := TSampleSourceFactory.Create(A, 0, 4, 440, spSustainLoop, sqLinear);
    finally
      A.Free;
    end;
    try
      SetLength(Zones, 2);
      for I := 0 to 1 do
      begin
        Zones[I].MinimumKey := 60;
        Zones[I].MaximumKey := 72;
        Zones[I].MinimumVelocity := 1;
        Zones[I].MaximumVelocity := 127;
        Zones[I].Voice := DefaultSynthVoice;
        Zones[I].Voice.SourceFactory := Factory;
      end;
      Instrument := TInstrument.Create(Zones);
      try
        Zones[0].MinimumKey := 0;
        Indices := Instrument.SelectZones(69, 100);
        Check((Length(Indices) = 2) and (Indices[0] = 0) and (Indices[1] = 1),
          'Owned instrument zones and ordered layers');
        Plan := Instrument.PlanNote(69, 100, 8000, 11, 800, 731);
      finally
        Instrument.Free;
      end;
      Check((Length(Plan) = 2) and (Plan[0].StartFrame = 11) and
        (Plan[0].GateFrames = 800), 'Instrument note clock');
      A := RenderFrameTones(Plan, 8000, 1200);
      try
        EmitClip('instrument-owned-source', A);
      finally
        A.Free;
      end;
      SetLength(Zones, 17);
      for I := 0 to 16 do
      begin
        Zones[I] := Zones[1];
      end;
      Failed := False;
      try
        Instrument := TInstrument.Create(Zones);
        Instrument.Free;
      except
        on EAudio do
        begin
          Failed := True;
        end;
      end;
      Check(Failed, 'Instrument rejects layer overflow');
      Zones[0].MinimumKey := 80;
      Zones[0].MaximumKey := 60;
      Failed := False;
      try
        Instrument := TInstrument.Create(Zones);
        Instrument.Free;
      except
        on EAudio do
        begin
          Failed := True;
        end;
      end;
      Check(Failed, 'Instrument rejects invalid range');
    finally
      Factory.Free;
    end;
    WriteLn('pass synthesis-portable');
  finally
    Probe.Free;
  end;
end.
