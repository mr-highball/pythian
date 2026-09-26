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
program pythian_instrument_style;

{$mode delphi}
{$H+}

uses
  Classes,
  SysUtils,
  Math,
  fpjson,
  pythian.audio,
  pythian.wave.stream,
  pythian.hash,
  pythian.music,
  pythian.music.render,
  pythian.midi.smf,
  pythian.midi.notes,
  pythian.synth,
  pythian.synth.stream,
  pythian.oscillator,
  pythian.wfc.style,
  pythian.wfc.instrument,
  pythian.tools.files;

const
  CRate = 44100;
  CParts: array[0..2] of String = ('bass', 'chords', 'melody');
  CGains: array[0..2] of Double = (0.18, 0.08, 0.14);
  CPans: array[0..2] of Double = (-0.35, 0, 0.35);
  CCutoffs: array[0..2] of Double = (1500, 1700, 3200);

function ReadStyle(const APath: String): TWaveStyleProfile;
begin
  Result := nil;
  if APath <> '-' then
  begin
    Result := DecodeWaveStyle(ReadFileBytes(APath, MaximumStyleBytes));
  end;
end;

function PlanImportedNotes(const ASequence: TNoteSequence;
  const AParts: TStyleInstruments; const ABindingCount: Integer;
  out AReport: TNoteRenderReport): TFrameTones;
var
  LBindings: TStyleInstruments;
  LGate: TNoteGate;
  LIndex: Integer;
begin
  if (ABindingCount < 1) or (ABindingCount > MaximumNoteVoices) then
  begin
    raise EAudio.Create('Imported MIDI exceeds instrument binding budget');
  end;
  SetLength(LBindings, ABindingCount);
  for LIndex := 0 to High(LBindings) do
  begin
    LBindings[LIndex] := AParts[0];
  end;
  for LIndex := 0 to ASequence.NoteCount - 1 do
  begin
    LGate := ASequence.GateAt(LIndex);
    LBindings[LGate.Voice] := AParts[LGate.Channel];
  end;
  Result := PlanStyleNoteTones(ASequence, CRate, LBindings, AReport);
end;

function StreamWave(const ATones: TFrameTones; const AMinimumFrames: Int64;
  const APath: String; const AReadFrames: Integer; const AOutputGain: Double;
  out AFrames: Int64;
  out APeak: Double; out AVoices, AWork: Integer): String;
var
  LRenderer: TFrameToneStream;
  LStream: TFileStream;
  LSink: TStreamAudioSink;
  LWriter: TWavePcm16Writer;
  LSamples: TAudioSamples;
  LSample: Double;
  LIndex: Integer;
begin
  LRenderer := TFrameToneStream.Create(ATones, CRate, AMinimumFrames);
  LStream := nil;
  LSink := nil;
  LWriter := nil;
  try
    AFrames := LRenderer.FrameCount;
    AVoices := LRenderer.PeakVoices;
    AWork := LRenderer.PeakFrameWork;
    APeak := 0;
    LStream := TFileStream.Create(APath, fmCreate);
    LSink := TStreamAudioSink.Create(LStream);
    LWriter := TWavePcm16Writer.Create(LSink, CRate, 2, AFrames);
    while LRenderer.ReadSamples(AReadFrames, LSamples) do
    begin
      for LIndex := 0 to High(LSamples) do
      begin
        LSample := LSamples[LIndex] * AOutputGain;
        if Abs(LSample) > 1 then
        begin
          raise EAudio.Create('Instrument samples exceed PCM16 headroom; reduce --output-gain');
        end;
        LSamples[LIndex] := LSample;
        APeak := Max(APeak, Abs(LSamples[LIndex]));
      end;
      LWriter.AppendSamples(LSamples);
    end;
    LWriter.Finish;
    LStream.Position := 0;
    Result := Sha256Stream(LStream, LStream.Size);
  finally
    LWriter.Free;
    LSink.Free;
    LStream.Free;
    LRenderer.Free;
  end;
end;

procedure PublishWave(const AStagedPath, AOutputPath: String);
var
  LSource: TFileStream;
  LTarget: TFileStream;
begin
  LSource := TFileStream.Create(AStagedPath, fmOpenRead or fmShareDenyWrite);
  try
    LTarget := TFileStream.Create(AOutputPath, fmCreate);
    try
      LTarget.CopyFrom(LSource, LSource.Size);
    finally
      LTarget.Free;
    end;
  finally
    LSource.Free;
  end;
end;

procedure Run;
var
  LSequence: TNoteSequence;
  LInstruments: TStyleInstruments;
  LZones: TStyleInstrumentZones;
  LTimbre: TWaveStyleProfile;
  LEnvelope: TWaveStyleProfile;
  LPlan: TFrameTones;
  LPartPlan: TFrameTones;
  LReport: TNoteRenderReport;
  LMidiReport: TMidiNoteReport;
  LMidiBytes: TAudioBytes;
  LGate: TNoteGate;
  LStaged: array[0..3] of String;
  LOutputs: array[0..5] of String;
  LJson: TJSONObject;
  LPartJson: TJSONObject;
  LPartsJson: TJSONArray;
  LNotesJson: TJSONArray;
  LNoteJson: TJSONObject;
  LNotesText: String;
  LJsonText: String;
  LMinimumFrames: Int64;
  LFrames: Int64;
  LPeak: Double;
  LPeakVoices: Integer;
  LPeakWork: Integer;
  LHash: String;
  LReadFrames: Integer;
  LOutputGain: Double;
  LHasTrajectory: Boolean;
  LReadSelected: Boolean;
  LGainSelected: Boolean;
  LFormat: TFormatSettings;
  I: Integer;
  J: Integer;
  K: Integer;
  LCount: Integer;
begin
  LSequence := nil;
  LTimbre := nil;
  LEnvelope := nil;
  LJson := nil;
  LPartsJson := nil;
  LNotesJson := nil;
  try
    LReadFrames := SynthStreamBlockFrames;
    LOutputGain := 1;
    LReadSelected := False;
    LGainSelected := False;
    LFormat := DefaultFormatSettings;
    LFormat.DecimalSeparator := '.';
    I := 9;
    while I <= ParamCount do
    begin
      if (ParamStr(I) = '--block-frames') and not LReadSelected then
      begin
        LReadFrames := StrToInt(ParamStr(I + 1));
        LReadSelected := True;
      end
      else if (ParamStr(I) = '--output-gain') and not LGainSelected then
      begin
        LOutputGain := StrToFloat(ParamStr(I + 1), LFormat);
        LGainSelected := True;
      end
      else
      begin
        raise EAudio.Create('Unknown or repeated instrument option: ' + ParamStr(I));
      end;
      Inc(I, 2);
    end;
    RequireFinite(LOutputGain, 'Instrument output gain');
    if (LOutputGain < 0) or (LOutputGain > 1) then
    begin
      raise EAudio.Create('Instrument output gain requires 0..1');
    end;
    if (LReadFrames < 1) or (LReadFrames > SynthStreamBlockFrames) then
    begin
      raise EAudio.Create('Instrument read size requires 1..2048 frames');
    end;
    LOutputs[0] := ParamStr(1);
    for I := 0 to 2 do
    begin
      LOutputs[I + 1] := ParamStr(1) + '.' + CParts[I] + '.wav';
    end;
    LOutputs[4] := ParamStr(1) + '.mid';
    LOutputs[5] := ParamStr(1) + '.json';
    for I := 0 to High(LOutputs) do
    begin
      for J := 2 to 8 do
      begin
        if (ParamStr(J) <> '-') and
          SameFileName(ExpandFileName(LOutputs[I]), ExpandFileName(ParamStr(J))) then
        begin
          raise EAudio.Create('Instrument outputs must differ from all MIDI/style inputs');
        end;
      end;
    end;
    LMidiBytes := ReadFileBytes(ParamStr(2), DefaultMidiReadLimits.MaxFileBytes);
    LSequence := DecodeMidiNotes(LMidiBytes, DefaultMidiNoteOptions, LMidiReport);
    if LSequence.NoteCount = 0 then
    begin
      raise EAudio.Create('Instrument audition requires sounding MIDI notes');
    end;
    { MIDI voice indices encode track*16+channel. Bind deliberately by channel,
      then retain the imported note order and seeds in the core frame plans. }
    LCount := 0;
    for I := 0 to LSequence.NoteCount - 1 do
    begin
      LGate := LSequence.GateAt(I);
      if (LGate.Channel < 0) or (LGate.Channel > 2) then
      begin
        raise EAudio.Create('Instrument audition maps only MIDI channels 0/1/2 to bass/chords/melody');
      end;
      if LGate.Voice > LCount then
      begin
        LCount := LGate.Voice;
      end;
    end;
    { Three role instruments own their measured resources; the dense table below
      aliases these across imported tracks and never owns the aliases. }
    SetLength(LInstruments, 3);
    SetLength(LZones, 1);
    LJson := TJSONObject.Create;
    LJson.Add('contract', 'pythian.instrument.style');
    LJson.Add('sample_rate', CRate);
    LJson.Add('render_policy', 'Bounded scheduled stream; stable start/input order; Double mix then Single samples');
    LJson.Add('read_frames', LReadFrames);
    LJson.Add('output_gain', LOutputGain);
    LJson.Add('output_policy', 'Common explicit gain for mix and stems; reject peaks above unity before publication; no automatic normalization');
    LJson.Add('midi_sha256', HashAudioBytes(LMidiBytes));
    LJson.Add('ticks_per_quarter', LSequence.TicksPerQuarter);
    LJson.Add('length_ticks', LSequence.LengthTicks);
    LJson.Add('binding_policy', 'Explicit MIDI channel 0=bass, 1=chords, 2=melody; no role inference');
    LJson.Add('release_policy', 'Natural instrument tails after exact MIDI gates; tails may overlap rests');
    LJson.Add('ownership_policy', 'Source profiles freed before planning; instruments retained through rendering');
    LJson.Add('envelope_policy', 'Saved measured frame curves at output rate; no note-length stretching');
    LPartsJson := TJSONArray.Create;
    LJson.Add('parts', LPartsJson);
    for I := 0 to 2 do
    begin
      LZones[0] := Default(TStyleInstrumentZone);
      LZones[0].Zone.MinimumKey := 0;
      LZones[0].Zone.MaximumKey := 127;
      LZones[0].Zone.MinimumVelocity := 1;
      LZones[0].Zone.MaximumVelocity := 127;
      LZones[0].Zone.Voice := DefaultSynthVoice;
      LZones[0].Zone.Voice.OscillatorQuality := oqPolynomial;
      LZones[0].Zone.Voice.Gain := CGains[I];
      LZones[0].Zone.Voice.Pan := CPans[I];
      LZones[0].Zone.Voice.CutoffHz := CCutoffs[I];
      LZones[0].Zone.Voice.Envelope.ReleaseSeconds := 0.12;
      LTimbre := ReadStyle(ParamStr(3 + I * 2));
      LEnvelope := ReadStyle(ParamStr(4 + I * 2));
      LZones[0].Timbre := LTimbre;
      LZones[0].Envelope := LEnvelope;
      LHasTrajectory := (LTimbre <> nil) and LTimbre.HasTimbreTrajectory;
      LInstruments[I] := TStyleInstrument.Create(LZones, CRate);
      FreeAndNil(LTimbre);
      FreeAndNil(LEnvelope);
      LPartJson := TJSONObject.Create;
      LPartsJson.Add(LPartJson);
      LPartJson.Add('name', CParts[I]);
      LPartJson.Add('channel', I);
      LPartJson.Add('timbre_style_sha256', LInstruments[I].TimbreIdentity(0));
      LPartJson.Add('envelope_style_sha256', LInstruments[I].EnvelopeIdentity(0));
      if LHasTrajectory then
      begin
        LPartJson.Add('timbre_reference_rms', 0.1);
        LPartJson.Add('timbre_policy', 'Saved magnitude trajectory; floored note-relative window centers; independent envelope and gain');
      end;
      LPartJson.Add('gain', CGains[I]);
      LPartJson.Add('pan', CPans[I]);
      LPartJson.Add('cutoff_hz', CCutoffs[I]);
    end;
    { Preserve complete imported notes/clock; the dense library table uses Voice.
      Each used index is track*16+channel, so unused entries map harmlessly to
      bass. All supplied bindings use the same output rate. }
    LNotesJson := TJSONArray.Create;
    LJson.Add('notes', LNotesJson);
    SetLength(LPlan, 0);
    SetLength(LPartPlan, 0);
    LMinimumFrames := LSequence.FrameAtTick(LSequence.LengthTicks, CRate);
    for I := 0 to LSequence.NoteCount - 1 do
    begin
      LGate := LSequence.GateAt(I);
      LNoteJson := TJSONObject.Create;
      LNotesJson.Add(LNoteJson);
      LNoteJson.Add('start_tick', LGate.StartTick);
      LNoteJson.Add('end_tick', LGate.EndTick);
      LNoteJson.Add('pitch', LGate.Pitch);
      LNoteJson.Add('velocity', LGate.Velocity);
      LNoteJson.Add('track', LGate.Track);
      LNoteJson.Add('voice', LGate.Voice);
      LNoteJson.Add('channel', LGate.Channel);
    end;
    LNotesText := LNotesJson.AsJSON;
    LJson.Add('notes_sha256', HashText(LNotesText));
    { Use the shared planner via a temporary dense borrowed table. }
    LPlan := PlanImportedNotes(LSequence, LInstruments, LCount + 1, LReport);
    if (LReport.SubFrameNotes <> 0) or (LReport.RenderedTones <> LSequence.NoteCount) then
    begin
      raise EAudio.Create('Instrument audition requires one sounding tone per imported note');
    end;
    for I := 0 to 2 do
    begin
      SetLength(LPartPlan, Length(LPlan));
      LCount := 0;
      for J := 0 to High(LPlan) do
      begin
        if LSequence.GateAt(J).Channel = I then
        begin
          LPartPlan[LCount] := LPlan[J];
          Inc(LCount);
        end;
      end;
      SetLength(LPartPlan, LCount);
      LStaged[I + 1] := GetTempFileName(ExtractFilePath(ExpandFileName(LOutputs[I + 1])),
        'pythian-');
      LHash := StreamWave(LPartPlan, LMinimumFrames, LStaged[I + 1], LReadFrames,
        LOutputGain, LFrames, LPeak, LPeakVoices, LPeakWork);
      LPartsJson.Objects[I].Add('note_count', LCount);
      LPartsJson.Objects[I].Add('frames', LFrames);
      LPartsJson.Objects[I].Add('wave_sha256', LHash);
      LPartsJson.Objects[I].Add('peak', LPeak);
      LPartsJson.Objects[I].Add('peak_voices', LPeakVoices);
      LPartsJson.Objects[I].Add('peak_frame_work', LPeakWork);
    end;
    LStaged[0] := GetTempFileName(ExtractFilePath(ExpandFileName(LOutputs[0])), 'pythian-');
    LHash := StreamWave(LPlan, LMinimumFrames, LStaged[0], LReadFrames,
      LOutputGain, LFrames, LPeak, LPeakVoices, LPeakWork);
    LJson.Add('note_count', LReport.RenderedNotes);
    LJson.Add('frames', LFrames);
    LJson.Add('wave_sha256', LHash);
    LJson.Add('peak', LPeak);
    LJson.Add('peak_voices', LPeakVoices);
    LJson.Add('peak_frame_work', LPeakWork);
    LJsonText := LJson.FormatJSON;
    { Stage complete encoded streams before replacing accepted outputs. Only
      fixed-size copy buffers are retained. Publication I/O is not transactional
      across the six outputs; a synthesis failure leaves them all unchanged. }
    for I := 0 to 3 do
    begin
      PublishWave(LStaged[I], LOutputs[I]);
    end;
    WriteFileBytes(LOutputs[4], LMidiBytes);
    WriteTextFile(LOutputs[5], LJsonText);
    WriteLn('Instrument roles: ', LReport.RenderedNotes, ' notes, ',
      LFrames, ' stereo frames; peak voices ', LPeakVoices,
      ', peak frame work ', LPeakWork, '; bounded streaming playback');
  finally
    LJson.Free;
    for K := 0 to 3 do
    begin
      if LStaged[K] <> '' then
      begin
        DeleteFile(LStaged[K]);
      end;
    end;
    for K := 0 to High(LInstruments) do
    begin
      LInstruments[K].Free;
    end;
    LEnvelope.Free;
    LTimbre.Free;
    LSequence.Free;
  end;
end;

begin
  try
    if not (ParamCount in [8, 10, 12]) then
    begin
      raise EAudio.Create('Usage: pythian.instrument.style OUTPUT.wav NOTES.mid ' +
        'BASS_TIMBRE.pys BASS_ENVELOPE.pys CHORD_TIMBRE.pys CHORD_ENVELOPE.pys ' +
        'MELODY_TIMBRE.pys MELODY_ENVELOPE.pys [--block-frames 1..2048] ' +
        '[--output-gain 0..1]; ' +
        '- preserves the authored dimension');
    end;
    Run;
  except
    on LException: Exception do
    begin
      WriteLn(StdErr, LException.ClassName, ': ', LException.Message);
      Halt(1);
    end;
  end;
end.
