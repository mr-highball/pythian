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
program pythian_midi_render;

{$mode delphi}
{$H+}

uses
  Classes,
  SysUtils,
  pythian.audio,
  pythian.wave,
  pythian.music,
  pythian.music.render,
  pythian.synth,
  pythian.midi.smf,
  pythian.midi.notes;

procedure Run;
var
  LStream: TFileStream;
  LBytes: TMidiBytes;
  LLimits: TMidiReadLimits;
  LOptions: TMidiNoteOptions;
  LImport: TMidiNoteReport;
  LRender: TNoteRenderReport;
  LSequence: TNoteSequence;
  LClip: TAudioClip;
  LIndex: Integer;
begin
  if ParamCount < 2 then
  begin
    raise EAudio.Create('Usage: pythian.midi.render INPUT.mid OUTPUT.wav ' +
      '[--ignore-performance] [--fifo] [--close-dangling] [--exclude-percussion]');
  end;
  if SameFileName(ExpandFileName(ParamStr(1)), ExpandFileName(ParamStr(2))) then
  begin
    raise EAudio.Create('Input and output paths must differ');
  end;
  LOptions := DefaultMidiNoteOptions;
  for LIndex := 3 to ParamCount do
  begin
    if ParamStr(LIndex) = '--ignore-performance' then
    begin
      LOptions.IgnoreUnsupportedEvents := True;
    end
    else if ParamStr(LIndex) = '--fifo' then
    begin
      LOptions.AllowOverlapsFIFO := True;
    end
    else if ParamStr(LIndex) = '--close-dangling' then
    begin
      LOptions.CloseDanglingNotes := True;
    end
    else if ParamStr(LIndex) = '--exclude-percussion' then
    begin
      LOptions.IncludePercussion := False;
    end
    else
    begin
      raise EAudio.Create('Unknown option: ' + ParamStr(LIndex));
    end;
  end;
  LLimits := DefaultMidiReadLimits;
  LStream := TFileStream.Create(ParamStr(1), fmOpenRead or fmShareDenyWrite);
  try
    if LStream.Size > LLimits.MaxFileBytes then
    begin
      raise EAudio.Create('MIDI source exceeds file byte budget');
    end;
    SetLength(LBytes, LStream.Size);
    if Length(LBytes) > 0 then
    begin
      LStream.ReadBuffer(LBytes[0], Length(LBytes));
    end;
  finally
    LStream.Free;
  end;
  LSequence := DecodeMidiNotes(LBytes, LOptions, LImport);
  try
    LClip := RenderNoteSequence(LSequence, 44100, DefaultSynthVoice, LRender);
    try
      SaveWavePcm16(ParamStr(2), LClip);
      WriteLn('Rendered ', LRender.RenderedNotes, ' notes, ', LClip.FrameCount,
        ' stereo frames at 44100 Hz');
    finally
      LClip.Free;
    end;
  finally
    LSequence.Free;
  end;
  WriteLn('Single-voice note preview; channel 10 uses pitched notes unless excluded.');
  WriteLn('Source tracks/events: ', LImport.SourceTracks, '/', LImport.SourceEvents);
  WriteLn('Ignored performance/system/metadata: ', LImport.IgnoredPerformanceEvents,
    '/', LImport.IgnoredSystemEvents, '/', LImport.IgnoredMetadataEvents);
  WriteLn('FIFO overlaps/closed dangling/zero-length/sub-frame: ',
    LImport.OverlappingNotesPairedFIFO, '/', LImport.ClosedDanglingNotes,
    '/', LImport.ZeroLengthNotes, '/', LRender.SubFrameNotes);
  WriteLn('Excluded percussion/release velocities/redundant tempos: ',
    LImport.ExcludedPercussionNotes, '/', LImport.DiscardedReleaseVelocities,
    '/', LImport.RedundantTempoEvents);
  WriteLn('Used default initial tempo: ', LImport.UsedDefaultTempo);
end;

begin
  try
    Run;
  except
    on LException: Exception do
    begin
      WriteLn(StdErr, LException.Message);
      Halt(1);
    end;
  end;
end.
