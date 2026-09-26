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
program pythian.articulate;

{$mode delphi}
{$H+}

uses
  SysUtils,
  fpjson,
  pythian.audio,
  pythian.wave,
  pythian.time,
  pythian.music,
  pythian.articulation,
  pythian.midi.smf,
  pythian.midi.notes,
  pythian.tools.files;

procedure ProtectInput(const AInput, AOutput: String);
begin
  if SameFileName(ExpandFileName(AInput), ExpandFileName(AOutput)) or
    SameFileName(ExpandFileName(AInput), ExpandFileName(AOutput + '.json')) or
    SameFileName(ExpandFileName(AInput + '.json'), ExpandFileName(AOutput)) then
  begin
    raise EAudio.Create('Articulation output must differ from every input');
  end;
end;

procedure Run;
var
  LSource: TAudioClip;
  LOutput: TAudioClip;
  LPlan: TArticulationPlan;
  LClock: TTempoMap;
  LSequence: TNoteSequence;
  LTempos: TTempoChanges;
  LDocument: TJSONObject;
  LGates: TJSONArray;
  LItem: TJSONObject;
  LGate: TArticulationGate;
  LBytes: TAudioBytes;
  LMidi: TMidiBytes;
  LImport: TMidiNoteReport;
  LSourceHash: String;
  LJson: String;
  LPattern: String;
  LAttack: Integer;
  LRelease: Integer;
  LBaseArgs: Integer;
  LTempo: Integer;
  LGrid: Integer;
  LLength: Int64;
  LOmitted: Integer;
  LIndex: Integer;
begin
  if ParamCount < 4 then
  begin
    raise EAudio.Create('Usage: pythian.articulate INPUT.wav OUTPUT.wav ' +
      'grid MICROSECONDS_PER_QUARTER GRID_TICKS PATTERN [ATTACK_FRAMES RELEASE_FRAMES] ' +
      'or INPUT.wav OUTPUT.wav midi INPUT.mid [ATTACK_FRAMES RELEASE_FRAMES]');
  end;
  if ParamStr(3) = 'grid' then
  begin
    LBaseArgs := 6;
  end
  else if ParamStr(3) = 'midi' then
  begin
    LBaseArgs := 4;
    ProtectInput(ParamStr(4), ParamStr(2));
  end
  else
  begin
    raise EAudio.Create('Articulation mode must be grid or midi');
  end;
  if (ParamCount <> LBaseArgs) and (ParamCount <> LBaseArgs + 2) then
  begin
    raise EAudio.Create('Articulation requires all mode arguments and an optional fade pair');
  end;
  ProtectInput(ParamStr(1), ParamStr(2));
  LSource := LoadWaveSource(ParamStr(1), LSourceHash);
  LPlan := nil;
  LDocument := nil;
  try
    LAttack := (LSource.SampleRate + 199) div 200;
    LRelease := (LSource.SampleRate + 99) div 100;
    if ParamCount > LBaseArgs then
    begin
      LAttack := StrToInt(ParamStr(LBaseArgs + 1));
      LRelease := StrToInt(ParamStr(LBaseArgs + 2));
    end;
    LDocument := TJSONObject.Create;
    LDocument.Add('articulation_version', ArticulationVersion);
    LDocument.Add('mode', ParamStr(3));
    LDocument.Add('source_sha256', LSourceHash);
    LDocument.Add('source_frames', LSource.FrameCount);
    LDocument.Add('sample_rate', LSource.SampleRate);
    LDocument.Add('channels', LSource.Channels);
    LDocument.Add('attack_frames', LAttack);
    LDocument.Add('release_frames', LRelease);
    LDocument.Add('input_frame_mapping', 'identity');
    LDocument.Add('overlap', 'maximum');
    LOmitted := 0;
    if ParamStr(3) = 'grid' then
    begin
      LTempo := StrToInt(ParamStr(4));
      LGrid := StrToInt(ParamStr(5));
      LPattern := ParamStr(6);
      if (LGrid < 1) or (Length(LPattern) < 1) or
        (Length(LPattern) > MaximumArticulationGates) then
      begin
        raise EAudio.Create('Grid ticks or pattern length outside bounds');
      end;
      LLength := Int64(LGrid) * Length(LPattern);
      if LLength > High(Integer) then
      begin
        raise EAudio.Create('Articulation grid exceeds PPQ tick range');
      end;
      SetLength(LTempos, 1);
      LTempos[0] := MakeTempoChange(0, LTempo);
      LClock := TTempoMap.Create(480, LLength, LTempos);
      try
        LPlan := PlanGridArticulation(LClock, 0, LGrid, LPattern,
          LSource.SampleRate, LAttack, LRelease);
      finally
        LClock.Free;
      end;
      LDocument.Add('ticks_per_quarter', 480);
      LDocument.Add('microseconds_per_quarter', LTempo);
      LDocument.Add('grid_ticks', LGrid);
      LDocument.Add('pattern', LPattern);
    end
    else
    begin
      LBytes := ReadFileBytes(ParamStr(4), DefaultMidiReadLimits.MaxFileBytes);
      LDocument.Add('midi_sha256', HashAudioBytes(LBytes));
      LMidi := nil;
      SetLength(LMidi, Length(LBytes));
      if Length(LBytes) > 0 then
      begin
        Move(LBytes[0], LMidi[0], Length(LBytes));
      end;
      LSequence := DecodeMidiNotes(LMidi, DefaultMidiNoteOptions, LImport);
      try
        LPlan := PlanNoteArticulation(LSequence, LSource.SampleRate,
          LAttack, LRelease, LOmitted);
        LDocument.Add('source_notes', LSequence.NoteCount);
        LDocument.Add('ticks_per_quarter', LSequence.TicksPerQuarter);
        LDocument.Add('ignored_metadata_events', LImport.IgnoredMetadataEvents);
        LDocument.Add('discarded_release_velocities', LImport.DiscardedReleaseVelocities);
        LDocument.Add('zero_length_notes', LImport.ZeroLengthNotes);
        LDocument.Add('used_default_tempo', LImport.UsedDefaultTempo);
      finally
        LSequence.Free;
      end;
    end;
    LDocument.Add('sub_frame_notes', LOmitted);
    LDocument.Add('output_frames', LPlan.FrameCount);
    LGates := TJSONArray.Create;
    LDocument.Add('gates', LGates);
    for LIndex := 0 to LPlan.GateCount - 1 do
    begin
      LGate := LPlan.GateAt(LIndex);
      LItem := TJSONObject.Create;
      LGates.Add(LItem);
      LItem.Add('start_frame', LGate.StartFrame);
      LItem.Add('end_frame', LGate.EndFrame);
      LItem.Add('gain', LGate.Gain);
    end;
    LOutput := RenderArticulatedClip(LSource, LPlan);
    try
      LBytes := EncodeWavePcm16(LOutput);
    finally
      LOutput.Free;
    end;
    LDocument.Add('output_sha256', HashAudioBytes(LBytes));
    LJson := LDocument.FormatJSON;
    WriteFileBytes(ParamStr(2), LBytes);
    WriteTextFile(ParamStr(2) + '.json', LJson);
    WriteLn('Articulated ', LPlan.FrameCount, ' frames through ', LPlan.GateCount,
      ' gates; omitted sub-frame notes: ', LOmitted);
    WriteLn('Output clock is explicit; source sample positions are unchanged.');
  finally
    LDocument.Free;
    LPlan.Free;
    LSource.Free;
  end;
end;

begin
  try
    Run;
  except
    on LException: Exception do
    begin
      WriteLn(StdErr, LException.ClassName, ': ', LException.Message);
      Halt(1);
    end;
  end;
end.
