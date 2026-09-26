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
program pythian_tests_wfc_activity;

{$mode delphi}
{$H+}

uses
  SysUtils,
  pythian.audio,
  pythian.activity,
  pythian.continuity,
  pythian.corpus,
  pythian.learning,
  pythian.granular,
  pythian.wfc.activity,
  pythian.wfc.corpus,
  pythian.wfc.generation,
  pythian.wfc.learning,
  pythian.tests.corpus.fixture,
  wfc,
  wfc_music,
  wfc_music_sequence,
  wfc_sequence,
  wfc_sequence_text;

procedure Check(const AValue: Boolean; const AMessage: String);
begin
  if not AValue then
  begin
    raise Exception.Create(AMessage);
  end;
end;

procedure CheckRhythmProjection;
var
  LTracks: TWfcMusicTracks;
  LVoices: TWfcMusicVoices;
  LMeters: TWfcMusicMeterChanges;
  LTempos: TWfcMusicTempoChanges;
  LSpans: TWfcMusicSpanEvents;
  LTones: TWfcMusicTones;
  LScore: TWfcMusicScore;
  LActions: TAcousticActions;
  LCells: TWfcMusicRhythmCells;
  LScoreCells: TWfcMusicRhythmCells;
  LIndex: Integer;
begin
  SetLength(LTracks, 1);
  LTracks[0] := MakeWfcMusicTrack('fixture', 'Fixture');
  SetLength(LVoices, 1);
  LVoices[0] := MakeWfcMusicVoice(0, 'voice');
  SetLength(LMeters, 1);
  LMeters[0] := MakeWfcMusicMeterChange(0, 4, 4);
  SetLength(LTempos, 1);
  LTempos[0] := MakeWfcMusicTempoChange(0, 500000);
  SetLength(LTones, 1);
  LTones[0] := MakeWfcMusicTone(60, 100);
  SetLength(LSpans, 4);
  LSpans[0] := MakeWfcMusicRest(0, 0, 2);
  LSpans[1] := MakeWfcMusicSound(0, 2, 2, LTones);
  LSpans[2] := MakeWfcMusicRest(0, 4, 1);
  LSpans[3] := MakeWfcMusicSound(0, 5, 3, LTones);
  LScore := TWfcMusicScore.Create(1, 12, 8, LTracks, LVoices, LMeters, LTempos, LSpans);
  try
    LScoreCells := ProjectWfcMusicMelodyToRhythm(ProjectWfcMusicVoiceToMelodyCells(LScore, 0, 1));
    SetLength(LActions, 8);
    LActions[0] := aaSilence;
    LActions[1] := aaSilence;
    LActions[2] := aaOnset;
    LActions[3] := aaSustain;
    LActions[4] := aaSilence;
    LActions[5] := aaOnset;
    LActions[6] := aaSustain;
    LActions[7] := aaSustain;
    LCells := ProjectAcousticRhythm(LActions);
    for LIndex := 0 to High(LCells) do
    begin
      Check(EncodeWfcMusicRhythmCell(LCells[LIndex]) =
        EncodeWfcMusicRhythmCell(LScoreCells[LIndex]),
        'Acoustic activity uses the actual WFC score rhythm alphabet');
    end;
  finally
    LScore.Free;
  end;
end;

procedure CheckSavedCorpus;
var
  LCorpus: TAcousticCorpusData;
  LLoaded: TAcousticCorpusData;
  LSources: TAudioSources;
  LModel: TWfcSequenceModel;
  LRhythm: TWfcSequenceModel;
  LDecoded: TWfcSequenceModel;
  LOptions: TAcousticGenerationOptions;
  LReport: TGraphSolveReport;
  LIndices: TAcousticIndices;
  LRequested: TAcousticIndices;
  LConstraints: TWfcSequenceTokenConstraints;
  LPlanner: TCorpusGrainPlanner;
  LGrains: TAudioGrains;
  LPlanReport: TContinuityReport;
  LRecording: TAcousticRecording;
  LIndex: Integer;
  LLocked: Integer;
begin
  LCorpus := CreateCorpusFixture(LSources);
  try
    LRhythm := LearnAcousticRhythmModel(LCorpus, DefaultActivityOptions);
    try
      Check((LRhythm.SampleCount = 2) and (LRhythm.ObservationCount = 16),
        'Rhythm learning preserves source boundaries and complete observations');
      LDecoded := DecodeWfcSequenceText(EncodeWfcSequenceText(LRhythm));
      try
        Check(EncodeWfcSequenceText(LDecoded) = EncodeWfcSequenceText(LRhythm),
          'Actual acoustic rhythm model round-trip');
        for LIndex := 0 to LDecoded.PublicTokenCount - 1 do
        begin
          DecodeWfcMusicRhythmCell(LDecoded.PublicTokenAt(LIndex));
        end;
      finally
        LDecoded.Free;
      end;
    finally
      LRhythm.Free;
    end;
    LLoaded := DecodeWfcAcousticCorpus(EncodeWfcAcousticCorpus(LCorpus), LModel);
    try
      LOptions := DefaultAcousticGenerationOptions;
      LOptions.FrameCount := 8;
      Check(TryGenerateAcousticSequence(LModel, LOptions, nil, LIndices, LReport),
        'Generate a native WFC token sequence');
      LLocked := LIndices[2];
      SetLength(LConstraints, 1);
      LConstraints[0] := MakeWfcSequenceTokenConstraint(2, [AcousticToken(LLocked)]);
      Check(TryGenerateAcousticSequence(LModel, LOptions, LConstraints, LIndices, LReport),
        'Generate with an actual caller token lock');
      LRequested := Copy(LIndices);
      LPlanner := TCorpusGrainPlanner.Create(LLoaded, LSources, DefaultContinuityOptions);
      try
        LGrains := LPlanner.Plan(LIndices, LPlanReport);
        Check(LIndices[2] = LLocked, 'Caller lock retained after continuity planning');
        for LIndex := 0 to High(LGrains) do
        begin
          Check(LIndices[LIndex] = LRequested[LIndex], 'Requested WFC tokens remain unchanged');
          LRecording := LLoaded.RecordingAt(LGrains[LIndex].SourceIndex);
          Check(LRecording.Tokens[LGrains[LIndex].SourceStartFrame div
            LLoaded.Options.HopFrames] = LRequested[LIndex],
            'Every selected grain independently matches the requested WFC token');
        end;
      finally
        LPlanner.Free;
      end;
    finally
      LModel.Free;
      LLoaded.Free;
    end;
  finally
    LCorpus.Free;
    ReleaseFixtureSources(LSources);
  end;
end;

begin
  try
    CheckRhythmProjection;
    CheckSavedCorpus;
    WriteLn('WFC activity projection, rhythm learning and continuity locks passed');
  except
    on LException: Exception do
    begin
      WriteLn(StdErr, LException.Message);
      Halt(1);
    end;
  end;
end.
