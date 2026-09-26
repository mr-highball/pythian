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
program pythian_example_instrument;

{$mode delphi}
{$H+}

uses
  Classes, SysUtils, pythian.audio, pythian.wave, pythian.time, pythian.music,
  pythian.music.render, pythian.synth, pythian.oscillator, pythian.instrument,
  pythian.automation, pythian.envelope, pythian.midi.smf, pythian.midi.notes;

function MakeEnvelope: TGateEnvelope;
const
  CFrames: array[0..4] of Int64 = (0, 220, 1323, 3087, 4410);
  CLevels: array[0..4] of Double = (0, 1, 0.3, 0.8, 0.55);
var
  LPoints: TAutomationPoints;
  LHeld: TAutomationCurve;
  LRelease: TAutomationCurve;
  I: Integer;
begin
  LHeld := nil;
  LRelease := nil;
  try
    SetLength(LPoints, 5);
    for I := 0 to 4 do
    begin
      LPoints[I].Frame := CFrames[I];
      LPoints[I].Value := CLevels[I];
      LPoints[I].Transition := atLinear;
    end;
    LHeld := TAutomationCurve.Create(LPoints);
    SetLength(LPoints, 3);
    LPoints[0].Value := 1;
    LPoints[1].Frame := 1102;
    LPoints[1].Value := 0.2;
    LPoints[2].Frame := 3528;
    LPoints[2].Value := 0;
    LRelease := TAutomationCurve.Create(LPoints);
    Result := TGateEnvelope.Create(LHeld, LRelease, 3528);
  finally
    LRelease.Free;
    LHeld.Free;
  end;
end;

function ReadNotes(const APath: String): TNoteSequence;
var
  LStream: TFileStream;
  LBytes: TMidiBytes;
  LReport: TMidiNoteReport;
begin
  LStream := TFileStream.Create(APath, fmOpenRead or fmShareDenyWrite);
  try
    if (LStream.Size < 1) or (LStream.Size > DefaultMidiReadLimits.MaxFileBytes) then
    begin
      raise EAudio.Create('Instrument MIDI exceeds file size bound');
    end;
    SetLength(LBytes, Integer(LStream.Size));
    LStream.ReadBuffer(LBytes[0], Length(LBytes));
  finally
    LStream.Free;
  end;
  Result := DecodeMidiNotes(LBytes, DefaultMidiNoteOptions, LReport);
end;

procedure Render(const APath, AMidi: String);
const
  CRoots: array[0..7] of Integer = (48, 48, 53, 53, 55, 55, 48, 48);
  CMelody: array[0..7] of Integer = (60, 64, 65, 69, 67, 71, 64, 60);
  CTouch: array[0..3] of Integer = (64, 88, 112, 88);
var
  LZones: TInstrumentZones;
  LInstrument: TInstrument;
  LSequence: TNoteSequence;
  LTempos: TTempoChanges;
  LGates: TNoteGates;
  LReport: TNoteRenderReport;
  LClip: TAudioClip;
  LEnvelope: TGateEnvelope;
  I: Integer;
begin
  LInstrument := nil;
  LSequence := nil;
  LClip := nil;
  LEnvelope := nil;
  try
    if (AMidi <> '') and SameFileName(ExpandFileName(APath), ExpandFileName(AMidi)) then
    begin
      raise EAudio.Create('Instrument output must differ from its MIDI input');
    end;
    LEnvelope := MakeEnvelope;
    SetLength(LZones, 3);
    for I := 0 to 2 do
    begin
      LZones[I].MinimumKey := 60;
      LZones[I].MaximumKey := 127;
      LZones[I].MinimumVelocity := 1;
      LZones[I].MaximumVelocity := 127;
      LZones[I].Voice := DefaultSynthVoice;
      LZones[I].Voice.Envelope.ReleaseSeconds := 0.08;
      LZones[I].Voice.Gain := 0.2;
      LZones[I].Voice.Pan := 0.3;
    end;
    LZones[0].MinimumKey := 0;
    LZones[0].MaximumKey := 59;
    LZones[0].Voice.Shape := wsTriangle;
    LZones[0].Voice.Pan := -0.3;
    LZones[0].Voice.GateEnvelope := LEnvelope;
    LZones[1].MaximumVelocity := 95;
    LZones[1].Voice.Shape := wsSine;
    LZones[2].MinimumVelocity := 80;
    LZones[2].Voice.Shape := wsSquare;
    LZones[2].Voice.Gain := 0.09;
    LZones[2].Voice.CutoffHz := 3200;
    LZones[2].Voice.GateEnvelope := LEnvelope;
    LInstrument := TInstrument.Create(LZones);
    SetLength(LGates, 16);
    for I := 0 to 7 do
    begin
      LGates[I].StartTick := I * 240;
      LGates[I].EndTick := (I + 1) * 240;
      LGates[I].Pitch := CRoots[I];
      LGates[I].Velocity := 80;
      LGates[I].Channel := -1;
      LGates[I + 8].StartTick := I * 240;
      LGates[I + 8].EndTick := I * 240 + 180;
      LGates[I + 8].Pitch := CMelody[I];
      LGates[I + 8].Velocity := CTouch[I mod 4];
      LGates[I + 8].Channel := -1;
    end;
    SetLength(LTempos, 1);
    LTempos[0] := MakeTempoChange(0, 500000);
    if AMidi = '' then
    begin
      LSequence := TNoteSequence.Create(480, 1920, LTempos, LGates);
    end
    else
    begin
      LSequence := ReadNotes(AMidi);
    end;
    LClip := RenderNoteSequence(LSequence, 44100, LInstrument, LReport);
    if (LReport.SubFrameNotes <> 0) or (LReport.RenderedNotes <> LSequence.NoteCount) or
      ((AMidi = '') and ((LReport.RenderedNotes <> 16) or (LReport.RenderedTones <> 20))) then
    begin
      raise EAudio.Create('Instrument phrase did not retain its note/layer count');
    end;
    SaveWavePcm16(APath, LClip);
    WriteLn('Instrument consumer: ', LReport.RenderedNotes, ' notes / ',
      LReport.RenderedTones, ' layers / ', LClip.FrameCount, ' stereo frames');
  finally
    LClip.Free;
    LSequence.Free;
    LInstrument.Free;
    LEnvelope.Free;
  end;
end;

begin
  try
    if (ParamCount < 1) or (ParamCount > 2) then
    begin
      raise EAudio.Create('Usage: pythian.example.instrument OUTPUT.wav [NOTES.mid]');
    end;
    Render(ParamStr(1), ParamStr(2));
  except
    on LException: Exception do
    begin
      WriteLn(StdErr, LException.Message);
      Halt(1);
    end;
  end;
end.
