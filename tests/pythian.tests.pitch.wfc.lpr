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

program pythian_tests_pitch_wfc;

{$mode delphi}
{$H+}

uses
  SysUtils,
  Math,
  fpjson,
  jsonparser,
  pythian.audio,
  pythian.pitch,
  pythian.pitch.track,
  pythian.wfc.pitch,
  pythian.tools.files,
  wfc_model,
  wfc_sequence,
  wfc_sequence_learn,
  wfc_sequence_graph,
  wfc_sequence_text;

procedure Check(const ACondition: Boolean; const AMessage: String);
begin
  if not ACondition then
  begin
    raise EAudio.Create(AMessage);
  end;
end;

procedure Run;
var
  LTracks: TPitchTracks;
  LSamples: TWfcSequenceSamples;
  LActual: TWfcSequenceModel;
  LExpected: TWfcSequenceModel;
  LPrior: TWfcSequenceModel;
  LRejected: Boolean;
begin
  SetLength(LTracks, 2);
  LTracks[0] := [60, 62, -1, 67, 69];
  LTracks[1] := [72, 74];
  LActual := LearnPitchModel(LTracks, [2, 1], 2);
  LExpected := nil;
  try
    SetLength(LSamples, 5);
    LSamples[0] := MakeWfcSequenceSample([PitchNoteToken(60), PitchNoteToken(62)]);
    LSamples[1] := MakeWfcSequenceSample([PitchNoteToken(60), PitchNoteToken(62)]);
    LSamples[2] := MakeWfcSequenceSample([PitchNoteToken(67), PitchNoteToken(69)]);
    LSamples[3] := MakeWfcSequenceSample([PitchNoteToken(67), PitchNoteToken(69)]);
    LSamples[4] := MakeWfcSequenceSample([PitchNoteToken(72), PitchNoteToken(74)]);
    LExpected := LearnSequenceModelCorpus(LSamples, 2);
    Check(EncodeWfcSequenceText(LActual) = EncodeWfcSequenceText(LExpected),
      'Actual weighted pitch learning retains unknown gaps and independent recording boundaries');
    FreeAndNil(LActual);
    FreeAndNil(LExpected);
    LActual := LearnPitchRhythmModel(LTracks, ['40050', '03'], [2, 1], 2);
    LSamples[0] := MakeWfcSequenceSample([PitchRhythmToken(60, 4), PitchRhythmToken(62, 0)]);
    LSamples[1] := MakeWfcSequenceSample([PitchRhythmToken(60, 4), PitchRhythmToken(62, 0)]);
    LSamples[2] := MakeWfcSequenceSample([PitchRhythmToken(67, 5), PitchRhythmToken(69, 0)]);
    LSamples[3] := MakeWfcSequenceSample([PitchRhythmToken(67, 5), PitchRhythmToken(69, 0)]);
    LSamples[4] := MakeWfcSequenceSample([PitchRhythmToken(72, 0), PitchRhythmToken(74, 3)]);
    LExpected := LearnSequenceModelCorpus(LSamples, 2);
    Check(EncodeWfcSequenceText(LActual) = EncodeWfcSequenceText(LExpected),
      'Joint learning retains only observed pitch/onset/intensity pairs and independent runs');
    LPrior := LActual;
    LRejected := False;
    try
      LActual := LearnPitchRhythmModel(LTracks, ['4', '03'], [2, 1], 2);
    except
      on EAudio do
      begin
        LRejected := True;
      end;
    end;
    Check(LRejected and (LActual = LPrior), 'Misaligned joint evidence preserves prior model');
    LTracks[0][0] := 128;
    LPrior := LActual;
    LRejected := False;
    try
      LActual := LearnPitchModel(LTracks, [2, 1]);
    except
      on EAudio do
      begin
        LRejected := True;
      end;
    end;
    Check(LRejected and (LActual = LPrior), 'Invalid source preserves prior model');
    LTracks[0] := [-1, -1];
    LTracks[1] := [-1];
    LRejected := False;
    try
      LActual := LearnPitchModel(LTracks, [1, 1]);
    except
      on EAudio do
      begin
        LRejected := True;
      end;
    end;
    Check(LRejected and (LActual = LPrior), 'Unknown-only evidence cannot invent a model');
    WriteLn('Weighted pitch runs, unknown gaps, source boundaries and failure preservation pass');
  finally
    LExpected.Free;
    LActual.Free;
  end;
end;

function ReadText(const APath: String): String;
var
  LBytes: TAudioBytes;
begin
  LBytes := ReadFileBytes(APath, 16 * 1024 * 1024);
  SetLength(Result, Length(LBytes));
  if Length(LBytes) > 0 then
  begin
    Move(LBytes[0], Result[1], Length(LBytes));
  end;
end;

function ReadDocument(const APath: String): TJSONObject;
var
  LData: TJSONData;
begin
  LData := GetJSON(ReadText(APath));
  if not (LData is TJSONObject) then
  begin
    LData.Free;
    raise EAudio.Create('Expected JSON object');
  end;
  Result := TJSONObject(LData);
end;

procedure CheckOutput(const ASource, APrefix, AOutput: String);
const
  CNotes: array[0..7] of Integer = (60, 62, 64, 67, 69, 67, 64, 60);
var
  LLearned: TJSONObject;
  LRendered: TJSONObject;
  LModel: TWfcSequenceModel;
  LClip: TAudioClip;
  LHash: String;
  LModelText: String;
  LStates: TWfcSequenceStateIndices;
  LValidation: TWfcSequenceGraphValidationReport;
  LSamples: TAudioSamples;
  LOptions: TPitchOptions;
  LEstimate: TPitchEstimate;
  LCell: Integer;
  LExpected: Integer;
  LWindow: Integer;
  LStart: Integer;
  LFrame: Integer;
begin
  LLearned := nil;
  LRendered := nil;
  LModel := nil;
  LClip := nil;
  try
    LLearned := ReadDocument(APrefix + '.json');
    LRendered := ReadDocument(AOutput + '.json');
    Check(LLearned.Get('declared_monophonic', False) and
      (LLearned.Arrays['cells'].Count = 32) and (LLearned.Get('candidate_cells', 0) = 30),
      'Measured source admission covers expected pitched/unknown cells');
    Check(LLearned.Get('source_sha256', '') = HashAudioBytes(ReadFileBytes(ASource, 16 * 1024 * 1024)),
      'Actual input WAV bound to pitch evidence');
    for LCell := 0 to 31 do
    begin
      LExpected := CNotes[LCell mod 8];
      if LCell mod 16 = 15 then
      begin
        LExpected := -1;
      end;
      Check(LLearned.Arrays['cells'].Objects[LCell].Get('candidate_note', -2) = LExpected,
        'WAV-only pitch measurement matches independent authored note reference');
    end;
    LModelText := ReadText(APrefix + '.model.txt');
    Check((LLearned.Get('model', '') = LModelText) and
      (LLearned.Get('model_sha256', '') = HashText(LModelText)) and
      (LRendered.Get('model_sha256', '') = HashText(LModelText)), 'Saved model/evidence/generation binding');
    LModel := DecodeWfcSequenceText(LModelText);
    Check((LRendered.Arrays['notes'].Count = 32) and (LRendered.Arrays['states'].Count = 32),
      'Complete generated pitch path');
    SetLength(LStates, 32);
    for LCell := 0 to 31 do
    begin
      LStates[LCell] := LRendered.Arrays['states'].Integers[LCell];
    end;
    Check(ValidateSequenceStatePath(LModel, LStates, wseFragment, LValidation),
      'Actual companion validates full saved-model latent path');
    LClip := LoadWaveSource(AOutput, LHash);
    Check(LRendered.Get('output_sha256', '') = LHash, 'Actual generated WAV hash');
    LOptions := DefaultPitchOptions;
    LWindow := 2 * (Ceil(LClip.SampleRate / LOptions.MinimumHz) + 1);
    SetLength(LSamples, LWindow);
    for LCell := 0 to 31 do
    begin
      LExpected := LRendered.Arrays['notes'].Integers[LCell];
      Check(DecodePitchNoteToken(LModel.ProjectStateToken(LStates[LCell])) = LExpected,
        'Reported pitch is the actual solved state projection');
      LStart := LCell * 11025 + 5512 - LWindow div 2;
      for LFrame := 0 to LWindow - 1 do
      begin
        LSamples[LFrame] := LClip.SampleAt(LStart + LFrame, 0);
      end;
      LEstimate := EstimatePitch(LSamples, LClip.SampleRate, 1, 0, LOptions);
      Check(AdmitPitchNote(LEstimate, 25) = LExpected, 'Measured rendered audio matches generated pitch');
    end;
    WriteLn('WAV ground truth, source/model hashes, saved WFC path and all 32 audible pitches pass');
  finally
    LClip.Free;
    LModel.Free;
    LRendered.Free;
    LLearned.Free;
  end;
end;

procedure CheckDurationOutput(const ASource, APrefix, AOutput: String);
var
  LSource: TAudioClip;
  LOtherSource: TAudioClip;
  LOutput: TAudioClip;
  LTracks: TMeasuredPitchTracks;
  LOtherTrack: TPitchTrack;
  LTrackOptions: TPitchTrackOptions;
  LSpans: TPitchSpans;
  LTokens: TWfcModelTokens;
  LSamples: TWfcSequenceSamples;
  LExpected: TWfcSequenceModel;
  LActual: TWfcSequenceModel;
  LModel: TWfcSequenceModel;
  LLearned: TJSONObject;
  LRendered: TJSONObject;
  LRow: TJSONObject;
  LCell: TPitchDurationCell;
  LStates: TWfcSequenceStateIndices;
  LValidation: TWfcSequenceGraphValidationReport;
  LPcm: TAudioSamples;
  LEstimate: TPitchEstimate;
  LHash: String;
  LText: String;
  LPriorText: String;
  LSourceIndex: Integer;
  LIndex: Integer;
  LStart: Integer;
  LEnd: Integer;
  LFrame: Integer;
  LWindow: Integer;
  LNotes: Integer;
  LUnknown: Integer;
  LSilence: Integer;
  LTick: Integer;
  LQuantum: Integer;
  LRejected: Boolean;
begin
  LSource := nil;
  LOtherSource := nil;
  LOutput := nil;
  SetLength(LTracks, 2);
  LOtherTrack := nil;
  LExpected := nil;
  LActual := nil;
  LModel := nil;
  LLearned := nil;
  LRendered := nil;
  try
    LSource := LoadWaveSource(ASource, LHash);
    LLearned := ReadDocument(APrefix + '.json');
    LRendered := ReadDocument(AOutput + '.json');
    Check(LLearned.Get('source_sha256', '') = LHash, 'Duration evidence binds actual source WAV');
    LTracks[0] := TPitchTrack.Create(LSource, 1, DefaultPitchTrackOptions(LSource.SampleRate));
    Check((LTracks[0].RunCount = 6) and (LLearned.Get('pitch_run_count', 0) = 6),
      'Duration source retains independently checked six-note performance');
    LSpans := LTracks[0].CopySpans;
    Check(LLearned.Arrays['spans'].Count = Length(LSpans), 'Complete measured interval evidence');
    LUnknown := 0;
    LSilence := 0;
    for LIndex := 0 to High(LSpans) do
    begin
      LRow := LLearned.Arrays['spans'].Objects[LIndex];
      Check((LRow.Get('kind_ordinal', -1) = Ord(LSpans[LIndex].Kind)) and
        (LRow.Get('note', -2) = LSpans[LIndex].Note) and
        (LRow.Get('start_frame', -1) = LSpans[LIndex].StartFrame) and
        (LRow.Get('end_frame', -1) = LSpans[LIndex].EndFrame),
        'Saved evidence retains independently remeasured pitch, silence and unknown intervals');
      if LSpans[LIndex].Kind = pskUnknown then
      begin
        Inc(LUnknown);
      end;
      if LSpans[LIndex].Kind = pskSilence then
      begin
        Inc(LSilence);
      end;
    end;
    Check((LUnknown > 0) and (LSilence > 0), 'Unresolved windows remain distinct from measured silence');
    LOtherSource := LoadWaveSource(ExtractFilePath(ASource) + 'pitch-octave.wav', LHash);
    LTracks[1] := TPitchTrack.Create(LOtherSource, 0, DefaultPitchTrackOptions(LOtherSource.SampleRate));
    SetLength(LSamples, 3);
    for LSourceIndex := 0 to 1 do
    begin
      LSpans := LTracks[LSourceIndex].CopySpans;
      SetLength(LTokens, Length(LSpans));
      for LIndex := 0 to High(LSpans) do
      begin
        LTokens[LIndex] := UTF8String('pythian.pitch.span.v1.' +
          IntToStr(Ord(LSpans[LIndex].Kind)) + '.' + IntToStr(LSpans[LIndex].Note) +
          '.' + IntToStr(LSpans[LIndex].WindowCount));
      end;
      LSamples[LSourceIndex * 2] := MakeWfcSequenceSample(LTokens);
    end;
    LSamples[1] := LSamples[0];
    LActual := LearnPitchDurationModel(LTracks, [2, 1]);
    LExpected := LearnSequenceModelCorpus(LSamples, 2);
    Check(EncodeWfcSequenceText(LActual) = EncodeWfcSequenceText(LExpected),
      'Weighted duration model equals independently assembled recording samples');
    LPriorText := EncodeWfcSequenceText(LActual);
    LTrackOptions := LTracks[0].Options;
    LTrackOptions.HopFrames := LTrackOptions.HopFrames * 2;
    LOtherTrack := TPitchTrack.Create(LSource, 1, LTrackOptions);
    LTracks[1].Free;
    LTracks[1] := LOtherTrack;
    LOtherTrack := nil;
    LRejected := False;
    try
      LOtherTrack := nil;
      LModel := LearnPitchDurationModel(LTracks, [1, 1]);
    except
      on EAudio do
      begin
        LRejected := True;
      end;
    end;
    Check(LRejected and (LModel = nil) and (EncodeWfcSequenceText(LActual) = LPriorText),
      'Incompatible hop timebase rejects without replacing the accepted model');
    LText := ReadText(APrefix + '.model.txt');
    Check((LLearned.Get('model', '') = LText) and
      (LLearned.Get('model_sha256', '') = HashText(LText)) and
      (LRendered.Get('model_sha256', '') = HashText(LText)), 'Duration source/model/output binding');
    FreeAndNil(LExpected);
    SetLength(LSamples, 1);
    LExpected := LearnSequenceModelCorpus(LSamples, 2);
    Check(EncodeWfcSequenceText(LExpected) = LText, 'Saved duration model is actual measured corpus');
    LModel := DecodeWfcSequenceText(LText);
    SetLength(LStates, LRendered.Arrays['states'].Count);
    Check(Length(LStates) = 8, 'Complete generated duration path');
    for LIndex := 0 to High(LStates) do
    begin
      LStates[LIndex] := LRendered.Arrays['states'].Integers[LIndex];
    end;
    Check(ValidateSequenceStatePath(LModel, LStates, wseFragment, LValidation),
      'Actual WFC validates every generated interval transition');
    LOutput := LoadWaveSource(AOutput, LHash);
    Check(LRendered.Get('output_sha256', '') = LHash, 'Actual duration output WAV hash');
    LWindow := 2 * (Ceil(LOutput.SampleRate / DefaultPitchOptions.MinimumHz) + 1);
    SetLength(LPcm, LWindow);
    LNotes := 0;
    LTick := 0;
    LQuantum := LRendered.Get('duration_quantum_ms', 0);
    Check(LQuantum in [10, 20], 'Explicit checked duration timebase');
    for LIndex := 0 to High(LStates) do
    begin
      LCell := DecodePitchDurationToken(LModel.ProjectStateToken(LStates[LIndex]));
      LRow := LRendered.Arrays['spans'].Objects[LIndex];
      Check((LRow.Get('token', '') = String(LModel.ProjectStateToken(LStates[LIndex]))) and
        (LRow.Get('start_tick', -1) = LTick) and
        (LRow.Get('end_tick', -1) = LTick + LCell.Duration * LQuantum),
        'Output span timing follows actual learned duration');
      LStart := Int64(LTick) * LOutput.SampleRate div 1000;
      Inc(LTick, LCell.Duration * LQuantum);
      LEnd := Int64(LTick) * LOutput.SampleRate div 1000;
      if LCell.Kind = pskPitch then
      begin
        Check(LEnd - LStart >= LWindow, 'Generated pitched span supports independent audio measurement');
        LStart := (LStart + LEnd - LWindow) div 2;
        for LFrame := 0 to LWindow - 1 do
        begin
          LPcm[LFrame] := LOutput.SampleAt(LStart + LFrame, 0);
        end;
        LEstimate := EstimatePitch(LPcm, LOutput.SampleRate, 1, 0, DefaultPitchOptions);
        Check(AdmitPitchNote(LEstimate, 25) = LCell.Note,
          'Every audible duration-bearing note matches actual generated pitch');
        Inc(LNotes);
      end
      else
      begin
        for LFrame := LStart to LEnd - 1 do
        begin
          Check((LOutput.SampleAt(LFrame, 0) = 0) and (LOutput.SampleAt(LFrame, 1) = 0),
            'Silent/unknown output policy is enforced after release tails');
        end;
      end;
    end;
    Check((LNotes > 0) and (LOutput.FrameCount = Int64(LTick) * LOutput.SampleRate div 1000),
      'Duration output has exact cumulative clock extent and audible notes');
    WriteLn('Measured duration evidence, weighted corpus, incompatible clocks, saved WFC path, ',
      LNotes, ' audible notes and exact silent/unknown gates pass');
  finally
    LRendered.Free;
    LLearned.Free;
    LModel.Free;
    LActual.Free;
    LExpected.Free;
    LOtherTrack.Free;
    LTracks[1].Free;
    LTracks[0].Free;
    LOutput.Free;
    LOtherSource.Free;
    LSource.Free;
  end;
end;

begin
  try
    Check(ParamCount in [0, 3, 4], 'Usage: pythian.tests.pitch.wfc [SOURCE.wav LEARNED_PREFIX GENERATED.wav] | runs SOURCE.wav LEARNED_PREFIX GENERATED.wav');
    Run;
    if ParamCount = 4 then
    begin
      Check(ParamStr(1) = 'runs', 'Unknown pitch output check mode');
      CheckDurationOutput(ParamStr(2), ParamStr(3), ParamStr(4));
    end;
    if ParamCount = 3 then
    begin
      CheckOutput(ParamStr(1), ParamStr(2), ParamStr(3));
    end;
  except
    on LException: Exception do
    begin
      WriteLn(StdErr, LException.ClassName, ': ', LException.Message);
      Halt(1);
    end;
  end;
end.
