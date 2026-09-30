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
program pythian_tests_corpus_intake_files;

{$mode delphi}
{$H+}

uses
  Classes, SysUtils, Math, fpjson,
  pythian.audio, pythian.wave, pythian.analysis, pythian.learning,
  pythian.learning.journal, pythian.corpus.intake,
  pythian.tools.files, pythian.tools.corpus.intake,
  pythian.wfc.learning, pythian.wfc.learning.journal, pythian.wfc.generation,
  wfc, wfc_sequence, wfc_sequence_text;

var
  LDirectory: String;
  LChecks: Integer;

procedure Check(const ACondition: Boolean; const AMessage: String);
begin
  if not ACondition then raise Exception.Create(AMessage);
  Inc(LChecks);
end;

function Bytes(const AName: String): TAudioBytes;
begin Result := ReadFileBytes(LDirectory + AName, 4 * 1024 * 1024); end;

function FileText(const AName: String): UTF8String;
var B: TAudioBytes;
begin
  B := Bytes(AName); Result := '';
  if Length(B) > 0 then SetString(Result, PAnsiChar(@B[0]), Length(B));
end;

procedure RejectJSON(const AText: String);
var P: TCorpusIntakePlan; LRejected: Boolean;
begin
  P := nil; LRejected := False;
  WriteTextFile(LDirectory + 'invalid.json', AText);
  try
    try P := ReadCorpusIntake(LDirectory + 'invalid.json');
    except on E: Exception do LRejected := True; end;
  finally P.Free; end;
  Check(LRejected, 'Malformed intake JSON accepted');
end;

procedure RejectAdmission(const D: TCorpusIntakeDefinition);
var P: TCorpusIntakePlan; A: TCorpusAdmission; LRejected: Boolean;
begin
  P := nil; A := nil; LRejected := False;
  try
    try
      P := TCorpusIntakePlan.Create(D); A := TCorpusAdmission.Create(P, LDirectory);
    except on E: Exception do LRejected := True; end;
  finally A.Free; P.Free; end;
  Check(LRejected, 'Invalid bytes/preparation admitted');
end;

procedure CheckActualSegments(const P: TCorpusIntakePlan);
var
  A: TCorpusAdmission;
  Reader: TJournalTrainingReader;
  Palette: TAcousticPalette;
  Model, Reloaded: TWfcSequenceModel;
  Segments: TJournalTrainingSegments;
  Observation: TJournalTrainingObservation;
  Options: TAcousticGenerationOptions;
  Solve: TGraphSolveReport;
  Generated, Replayed: TAcousticIndices;
  Expected: array[0..MaximumAcousticVocabulary, 0..MaximumAcousticVocabulary - 1] of Integer;
  H: TWfcSequenceHistoryItem;
  LastSegment, Previous, Current, StatePrevious, StateCurrent, I, J, StartTotal, EndTotal: Integer;
begin
  A := nil; Reader := nil; Palette := nil; Model := nil; Reloaded := nil;
  FillChar(Expected, SizeOf(Expected), 0);
  try
    A := TCorpusAdmission.Create(P, LDirectory);
    Segments := A.TrainingSegments(DefaultAnalysisOptions);
    Check(Length(Segments) = 2, 'Unknown span entered training');
    Reader := TJournalTrainingReader.Create(Segments);
    Palette := TAcousticPalette.CreateFromReader(Reader, 16);
    Model := LearnJournalAcousticModel(Reader, Palette, 2);
    Check(Model.SampleCount = 2, 'Learner did not retain song segments');
    Reader.Rewind; LastSegment := -1; Previous := MaximumAcousticVocabulary;
    while Reader.ReadObservation(Observation) do
    begin
      if Observation.SegmentIndex <> LastSegment then Previous := MaximumAcousticVocabulary;
      if Observation.SegmentIndex = 0 then
        Check(Observation.SourceFrame + DefaultAnalysisOptions.WindowFrames <= 6000,
          'Left measurement crosses unknown span')
      else
        Check(Observation.SourceFrame - DefaultAnalysisOptions.HopFrames >= 10000,
          'Right flux context crosses unknown span');
      Current := Palette.EncodeFeature(Observation.Feature);
      Inc(Expected[Previous, Current], Observation.Multiplicity);
      Previous := Current; LastSegment := Observation.SegmentIndex;
    end;
    StartTotal := 0; EndTotal := 0;
    for I := 0 to Model.StateCount - 1 do
    begin
      H := Model.HistoryItemAt(I, 0);
      if H.Kind = wshBos then StatePrevious := MaximumAcousticVocabulary
      else StatePrevious := AcousticTokenIndex(Model.PublicTokenAt(H.TokenIndex));
      StateCurrent := AcousticTokenIndex(Model.ProjectStateToken(I));
      Check(Model.StateObservationCountAt(I) = Expected[StatePrevious, StateCurrent],
        'Actual model has missing or cross-segment transition mass');
      Expected[StatePrevious, StateCurrent] := 0;
      Inc(StartTotal, Model.StartCountAt(I)); Inc(EndTotal, Model.EndCountAt(I));
    end;
    for I := 0 to MaximumAcousticVocabulary do
      for J := 0 to MaximumAcousticVocabulary - 1 do
        if Expected[I, J] <> 0 then raise Exception.Create('A within-song transition was lost');
    Check((StartTotal = 2) and (EndTotal = 2), 'Actual start/end history reset counts');
    Reloaded := DecodeWfcSequenceText(EncodeWfcSequenceText(Model));
    Check(EncodeWfcSequenceText(Model) = EncodeWfcSequenceText(Reloaded), 'Saved model replay');
    Options := DefaultAcousticGenerationOptions;
    Options.Seed := 731; Options.FrameCount := 2; Options.Extent := wseWhole;
    Check(TryGenerateAcousticSequence(Model, Options, nil, Generated, Solve), 'Original model cannot generate');
    Check(TryGenerateAcousticSequence(Reloaded, Options, nil, Replayed, Solve), 'Reloaded model cannot replay');
    Check(Length(Generated) = Length(Replayed), 'Replay lengths differ');
    for I := 0 to High(Generated) do Check(Generated[I] = Replayed[I], 'Fixed-seed saved-model replay differs');
  finally
    Reloaded.Free; Model.Free; Palette.Free; Reader.Free; A.Free;
  end;
end;

var
  P, Q: TCorpusIntakePlan;
  A: TCorpusAdmission;
  D, E: TCorpusIntakeDefinition;
  O: TJSONObject;
  LBaseline, LText, LModelHash: String;
  LOriginal, LMutated, LWaveBytes: TAudioBytes;
  LClip, LChild: TAudioClip;
  LSamples, LCrop: TAudioSamples;
  LRejected: Boolean;
  I, J: Integer;
begin
  P := nil; Q := nil; A := nil;
  try
    try
      if ParamCount <> 1 then raise Exception.Create('Supply the Pascal-generated example directory');
      LDirectory := IncludeTrailingPathDelimiter(ExpandFileName(ParamStr(1)));
      P := ReadCorpusIntake(LDirectory + 'example-0.json');
      LBaseline := EncodeCorpusIntake(P); D := P.CopyDefinition;
      CheckActualSegments(P);
      for I := 0 to 2 do
      begin
        Q := ReadCorpusIntake(LDirectory + 'example-' + IntToStr(I) + '.json');
        try
          A := TCorpusAdmission.Create(Q, LDirectory); A.Free; A := nil;
          LearnCorpusIntake(LDirectory + 'example-' + IntToStr(I) + '.json', LDirectory + 'accepted-' + IntToStr(I));
          if I = 0 then LModelHash := HashAudioBytes(Bytes('accepted-0.wfcs'))
          else Check(HashAudioBytes(Bytes('accepted-' + IntToStr(I) + '.wfcs')) = LModelHash,
            'Style label changes dispatch or learning');
        finally Q.Free; Q := nil; end;
      end;
      Q := ReadCorpusIntake(LDirectory + 'accepted-0.json');
      try
        Check(EncodeCorpusIntake(Q) = LBaseline, 'Published contract roundtrip');
        A := TCorpusAdmission.Create(Q, LDirectory); A.Free; A := nil;
      finally Q.Free; Q := nil; end;
      LearnCorpusIntake(LDirectory + 'accepted-0.json', LDirectory + 'replayed');
      Check(HashAudioBytes(Bytes('replayed.wfcs')) = LModelHash, 'Reloaded intake learning replay differs');
      Check(FileText('replayed.audit.json') = FileText('accepted-0.audit.json'), 'Audit replay differs');
      for I := 0 to 5 do
      begin
        if I = 1 then
        begin
          RejectJSON(Copy(LBaseline, 1, Length(LBaseline) - 1) + ',"version":1}');
          Continue;
        end;
        O := TJSONObject(GetJSON(LBaseline));
        try
          case I of
            0: O.Add('unknown_field', True);
            2: begin O.Delete('version'); O.Add('version', 2); end;
            3: begin O.Delete('version'); O.Add('version', 1.5); end;
            4: O.Delete('families');
            5: begin O.Delete('coordinate_units'); O.Add('coordinate_units', 'seconds'); end;
          end;
          RejectJSON(O.AsJSON);
        finally O.Free; end;
      end;
      RejectJSON(StringOfChar('[', 20) + StringOfChar(']', 20));
      RejectJSON('{} trailing');
      E := P.CopyDefinition; E.Sources[0].PreparationSha256 := StringOfChar('a', 64); RejectAdmission(E);
      E := P.CopyDefinition; E.Sources[0].SampleRate := 16000; RejectAdmission(E);
      E := P.CopyDefinition; E.Sources[0].Path := 'missing.wav'; RejectAdmission(E);
      E := P.CopyDefinition; E.Sources[0].PeakCeiling := 0.1; RejectAdmission(E);
      LOriginal := Bytes('source-0.wav'); LMutated := Copy(LOriginal);
      LMutated[High(LMutated)] := LMutated[High(LMutated)] xor 1;
      WriteFileBytes(LDirectory + 'source-0.wav', LMutated);
      try
        RejectAdmission(P.CopyDefinition);
        LRejected := False;
        try LearnCorpusIntake(LDirectory + 'example-0.json', LDirectory + 'bad-source');
        except on EError: Exception do LRejected := True; end;
        Check(LRejected and not FileExists(LDirectory + 'bad-source.json') and
          not FileExists(LDirectory + 'bad-source.wfcs') and
          not DirectoryExists(LDirectory + 'bad-source.publishing'), 'Failed admission published artifacts');
      finally WriteFileBytes(LDirectory + 'source-0.wav', LOriginal); end;
      LRejected := False;
      try LearnCorpusIntake(LDirectory + 'example-0.json', LDirectory + 'accepted-0');
      except on EError: Exception do LRejected := True; end;
      Check(LRejected and (HashAudioBytes(Bytes('accepted-0.wfcs')) = LModelHash), 'Existing valid output was replaced');
      ForceDirectories(LDirectory + 'reserved.publishing');
      WriteTextFile(LDirectory + 'reserved.publishing/intake.json', 'other publisher');
      LRejected := False;
      try LearnCorpusIntake(LDirectory + 'example-0.json', LDirectory + 'reserved');
      except on EError: Exception do LRejected := True; end;
      Check(LRejected and (FileText('reserved.publishing/intake.json') = 'other publisher'), 'Foreign staging was modified');
      LClip := LoadWaveSource(LDirectory + 'source-0.wav', LText);
      try LSamples := LClip.CopySamples; finally LClip.Free; end;
      SetLength(LCrop, 6000);
      for J := 0 to High(LCrop) do LCrop[J] := LSamples[J] * 0.5;
      LChild := TAudioClip.Create(8000, 1, LCrop);
      try LWaveBytes := EncodeWavePcm16(LChild); finally LChild.Free; end;
      WriteFileBytes(LDirectory + 'crop.wav', LWaveBytes);
      E := P.CopyDefinition; SetLength(E.Sources, 3); E.Sources[2] := E.Sources[0];
      with E.Sources[2] do
      begin
        Id := 'prepared-crop'; Path := 'crop.wav'; Sha256 := HashAudioBytes(LWaveBytes);
        FrameCount := 6000; Parent := 0; ParentFirstFrame := 0; ParentEndFrame := 6000; ParentGain := 0.5;
        PreparationPolicy := 'Exact [0,6000) crop with uniform gain 0.5; PCM16 re-encoding';
        PreparationSha256 := HashText(PreparationPolicy);
      end;
      Q := TCorpusIntakePlan.Create(E);
      try A := TCorpusAdmission.Create(Q, LDirectory); A.Free; A := nil; Check(True, 'Supported parent crop/gain');
      finally Q.Free; Q := nil; end;
      E.Sources[2].ParentGain := 0.75; RejectAdmission(E);
      E.Sources[2].ParentGain := 0.5; E.Sources[2].SampleRate := 16000; RejectAdmission(E);
      E := P.CopyDefinition; E.Families[1].Partition := cpEvaluation;
      E.Families[1].PreviouslyUsed := True; RejectAdmission(E);
      ForceDirectories(LDirectory + 'relocated');
      LearnCorpusIntake(LDirectory + 'example-0.json', LDirectory + 'relocated/accepted');
      Q := ReadCorpusIntake(LDirectory + 'relocated/accepted.json');
      try A := TCorpusAdmission.Create(Q, LDirectory + 'relocated'); A.Free; A := nil;
      finally Q.Free; Q := nil; end;
      Check(HashAudioBytes(Bytes('relocated/accepted.wfcs')) = LModelHash, 'Publication relocation changed model');
      WriteLn('Corpus intake files/learner: ', LChecks, ' checks passed');
    finally A.Free; Q.Free; P.Free; end;
  except on EError: Exception do begin WriteLn(StdErr, EError.Message); Halt(1); end; end;
end.
