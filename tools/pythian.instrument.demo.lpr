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
program pythian_instrument_demo;
{$mode delphi}{$H+}
uses
  SysUtils, Math, pythian.audio, pythian.wave, pythian.oscillator,
  pythian.synth, pythian.source.sample, pythian.instrument, pythian.time,
  pythian.music, pythian.music.render, pythian.midi.notes, pythian.midi.export;
procedure Run(const APath: String);
const
  CKeys: array[0..7] of Integer = (48, 55, 60, 64, 67, 64, 60, 55);
  CVelocities: array[0..2] of Integer = (48, 72, 112);
var
  LFactories: array[0..3] of TSampleSourceFactory;
  LZones: TInstrumentZones;
  LMap: TInstrument;
  LData: TAudioSamples;
  LClip: TAudioClip;
  LGates: TNoteGates;
  LTempos: TTempoChanges;
  LSequence: TNoteSequence;
  LDecoded: TNoteSequence;
  LImportReport: TMidiNoteReport;
  LRenderReport: TNoteRenderReport;
  LRoot: Double;
  LTime: Double;
  LLevel: Double;
  LSignal: Double;
  LKey: Integer;
  LCount: Integer;
  I: Integer;
  J: Integer;
begin
  for I := 0 to High(LFactories) do
  begin
    LFactories[I] := nil;
  end;
  LMap := nil;
  LSequence := nil;
  LDecoded := nil;
  try
    SetLength(LZones, 4);
    for I := 0 to 3 do
    begin
      LKey := 48 + (I mod 2) * 24;
      LRoot := MidiFrequency(LKey);
      SetLength(LData, 12000);
      for J := 0 to High(LData) do
      begin
        LTime := J / 24000;
        LLevel := Exp(-5 * LTime);
        if J < 120 then
        begin
          LLevel := LLevel * J / 120;
        end;
        LSignal := Sin(2 * Pi * LRoot * LTime);
        if I >= 2 then
        begin
          LSignal := 0.65 * LSignal + 0.25 * Sin(4 * Pi * LRoot * LTime) +
            0.1 * Sin(6 * Pi * LRoot * LTime);
        end;
        LData[J] := LLevel * LSignal;
      end;
      LClip := TAudioClip.Create(24000, 1, LData);
      try
        LFactories[I] := TSampleSourceFactory.Create(LClip, 0, LClip.FrameCount,
          LRoot, spOneShot, sqSinc, 2);
      finally
        LClip.Free;
      end;
      LZones[I].MinimumKey := 36 + (I mod 2) * 24;
      LZones[I].MaximumKey := LZones[I].MinimumKey + 23;
      LZones[I].MinimumVelocity := 1;
      LZones[I].MaximumVelocity := 79;
      if I >= 2 then
      begin
        LZones[I].MinimumVelocity := 64;
        LZones[I].MaximumVelocity := 127;
      end;
      LZones[I].Voice := DefaultSynthVoice;
      LZones[I].Voice.SourceFactory := LFactories[I];
      LZones[I].Voice.Gain := 0.3;
      LZones[I].Voice.CutoffHz := 8000;
      LZones[I].Voice.Envelope.ReleaseSeconds := 0.08;
      LZones[I].Voice.Pan := -0.25 + (I mod 2) * 0.5;
    end;
    LMap := TInstrument.Create(LZones);
    SetLength(LGates, 24);
    for I := 0 to 2 do
    begin
      for J := 0 to 7 do
      begin
        LCount := I * 8 + J;
        LGates[LCount].StartTick := (I * 10 + J) * 240;
        LGates[LCount].EndTick := LGates[LCount].StartTick + 192;
        LGates[LCount].Pitch := CKeys[J];
        LGates[LCount].Velocity := CVelocities[I];
        LGates[LCount].Channel := -1;
      end;
    end;
    SetLength(LTempos, 1);
    LTempos[0] := MakeTempoChange(0, 500000);
    LSequence := TNoteSequence.Create(480, 7200, LTempos, LGates);
    LDecoded := DecodeMidiNotes(EncodeMidiNotes(LSequence, [0]),
      DefaultMidiNoteOptions, LImportReport);
    LClip := RenderNoteSequence(LDecoded, 24000, LMap, LRenderReport);
    try
      if (LRenderReport.RenderedNotes <> 24) or (LRenderReport.RenderedTones <> 32) or
        (LClip.FrameCount <> 180000) then
      begin
        raise EAudio.Create('Instrument MIDI audition changed note, layer or frame extent');
      end;
      SaveWavePcm16(APath, LClip);
      WriteLn('Instrument MIDI audition: 24 notes, ', LRenderReport.RenderedTones, ' layers, ',
        LClip.FrameCount, ' stereo frames; soft / overlap / bright');
    finally
      LClip.Free;
    end;
  finally
    LDecoded.Free;
    LSequence.Free;
    LMap.Free;
    for I := 0 to High(LFactories) do
    begin
      LFactories[I].Free;
    end;
  end;
end;
begin
  try
    if ParamCount <> 1 then
    begin
      raise Exception.Create('Usage: pythian.instrument.demo OUTPUT.wav');
    end;
    Run(ParamStr(1));
  except
    on LException: Exception do
    begin
      WriteLn(StdErr, LException.Message);
      Halt(1);
    end;
  end;
end.
