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
program pythian_example_notes;

{$mode delphi}
{$H+}

uses
  Classes,
  SysUtils,
  pythian.audio,
  pythian.time,
  pythian.music,
  pythian.music.render,
  pythian.midi.smf,
  pythian.midi.notes,
  pythian.midi.export,
  pythian.synth,
  pythian.oscillator,
  pythian.wave,
  pythian.hash;

procedure WriteBytes(const APath: String; const ABytes: TMidiBytes);
var
  LFile: TFileStream;
begin
  LFile := TFileStream.Create(APath, fmCreate);
  try
    if Length(ABytes) > 0 then
    begin
      LFile.WriteBuffer(ABytes[0], Length(ABytes));
    end;
  finally
    LFile.Free;
  end;
end;

procedure Run(const APrefix: String);
const
  Melody: array[0..3] of Integer = (60, 64, 67, 65);
var
  LGates: TNoteGates;
  LTempos: TTempoChanges;
  LVoices: TNoteVoices;
  LSource: TNoteSequence;
  LDecoded: TNoteSequence;
  LOriginalAudio: TAudioClip;
  LDecodedAudio: TAudioClip;
  LMidi: TMidiBytes;
  LOriginalWave: TAudioBytes;
  LDecodedWave: TAudioBytes;
  LImportReport: TMidiNoteReport;
  LRenderReport: TNoteRenderReport;
  LIndex: Integer;
  LVoice: Integer;
begin
  LSource := nil;
  LDecoded := nil;
  LOriginalAudio := nil;
  LDecodedAudio := nil;
  try
    SetLength(LTempos, 2);
    LTempos[0] := MakeTempoChange(0, 500001);
    LTempos[1] := MakeTempoChange(960, 600001);
    SetLength(LGates, 8);
    SetLength(LVoices, 2);
    for LVoice := 0 to 1 do
    begin
      LVoices[LVoice] := DefaultSynthVoice;
      LVoices[LVoice].Gain := 0.2;
      LVoices[LVoice].Pan := -0.4 + 0.8 * LVoice;
      { Fade each note independently when the other part remains active. }
      LVoices[LVoice].Envelope.ReleaseSeconds := 0.005;
      for LIndex := 0 to 3 do
      begin
        LGates[LVoice * 4 + LIndex] := Default(TNoteGate);
        LGates[LVoice * 4 + LIndex].StartTick := LIndex * 480;
        LGates[LVoice * 4 + LIndex].EndTick := (LIndex + 1) * 480;
        LGates[LVoice * 4 + LIndex].Pitch := Melody[LIndex] - 24 * (1 - LVoice);
        LGates[LVoice * 4 + LIndex].Velocity := 96;
        LGates[LVoice * 4 + LIndex].Voice := LVoice;
        LGates[LVoice * 4 + LIndex].Channel := -1;
      end;
    end;
    LVoices[0].Shape := wsTriangle;
    LVoices[1].Shape := wsSine;
    LSource := TNoteSequence.Create(480, 1920, LTempos, LGates);
    LMidi := EncodeMidiNotes(LSource, [0, 1]);
    LDecoded := DecodeMidiNotes(LMidi, DefaultMidiNoteOptions, LImportReport);
    if (LDecoded.NoteCount <> LSource.NoteCount) or
      (LDecoded.LengthTicks <> LSource.LengthTicks) then
    begin
      raise EAudio.Create('MIDI round trip changed notes or extent');
    end;
    LOriginalAudio := RenderNoteSequence(LSource, 44100, LVoices, LRenderReport);
    if LRenderReport.RenderedNotes <> 8 then
    begin
      raise EAudio.Create('Source notes did not all render');
    end;
    LDecodedAudio := RenderNoteSequence(LDecoded, 44100, LVoices, LRenderReport);
    if LRenderReport.RenderedNotes <> 8 then
    begin
      raise EAudio.Create('Decoded notes did not all render');
    end;
    LOriginalWave := EncodeWavePcm16(LOriginalAudio);
    LDecodedWave := EncodeWavePcm16(LDecodedAudio);
    if Length(LOriginalWave) <> Length(LDecodedWave) then
    begin
      raise EAudio.Create('MIDI round trip changed rendered byte extent');
    end;
    for LIndex := 0 to High(LOriginalWave) do
    begin
      if LOriginalWave[LIndex] <> LDecodedWave[LIndex] then
      begin
        raise EAudio.Create('MIDI round trip changed rendered audio');
      end;
    end;
    WriteBytes(APrefix + '.mid', LMidi);
    WriteBytes(APrefix + '.wav', LOriginalWave);
    WriteLn('Native notes: 8 gates, 2 explicit channels, 2 tempos; ',
      LOriginalAudio.FrameCount, ' stereo frames; exact MIDI/audio round trip');
    WriteLn('MIDI SHA256 ', Sha256Bytes(LMidi));
    WriteLn('WAV SHA256 ', Sha256Bytes(LOriginalWave));
  finally
    LDecodedAudio.Free;
    LOriginalAudio.Free;
    LDecoded.Free;
    LSource.Free;
  end;
end;

begin
  try
    if ParamCount <> 1 then
    begin
      raise EAudio.Create('Usage: pythian.example.notes OUTPUT_PREFIX');
    end;
    Run(ParamStr(1));
  except
    on E: Exception do
    begin
      WriteLn(StdErr, E.ClassName, ': ', E.Message);
      Halt(1);
    end;
  end;
end.
