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
program pythian_tests_evaluation_files;

{$mode delphi}
{$H+}

uses
  SysUtils, fpjson, jsonparser, pythian.audio, pythian.wave,
  pythian.tools.files, pythian.tools.evaluate;

procedure Check(const ACondition: Boolean; const AMessage: String);
begin
  if not ACondition then
  begin
    raise Exception.Create(AMessage);
  end;
end;

function Save(const ADirectory, AName, AText: String): String;
begin
  WriteTextFile(ADirectory + AName, AText);
  Result := HashText(AText);
end;

function Fixture(const ADirectory, AMetric: String): TJSONObject;
var
  LBinding: TJSONObject;
  LClock: TJSONObject;
  LFiles: TJSONObject;
  LDocument: TJSONObject;
  LPolicy: String;
  LReference: String;
  LPrediction: String;
  LHash: String;
  LClip: TAudioClip;
  LSamples: TAudioSamples;
  LNotes: String;
  LVocabulary: String;
  I: Integer;
begin
  Result := TJSONObject.Create;
  try
    SetLength(LSamples, 8000);
    LClip := TAudioClip.Create(8000, 1, LSamples);
    try
      SaveWavePcm16(ADirectory + 'source.wav', LClip);
    finally
      LClip.Free;
    end;
    LBinding := TJSONObject.Create;
    Result.Add('format', 'pythian-evaluation-case');
    Result.Add('binding', LBinding);
    LBinding.Add('source_sha256', HashAudioBytes(ReadFileBytes(ADirectory + 'source.wav', 65536)));
    LBinding.Add('preparation_sha256', Save(ADirectory, 'preparation.txt', 'Identity PCM16'));
    LBinding.Add('annotation_policy_sha256', Save(ADirectory, 'annotation.txt',
      'Authored complete reference on absolute source clock, explicit rest/unknown.'));
    LBinding.Add('estimator_sha256', Save(ADirectory, 'estimator.txt',
      'Authored predictions; no learned model.'));
    LNotes := '';
    if AMetric = 'notes' then
    begin
      LVocabulary := '';
      for I := 0 to 127 do
      begin
        if I > 0 then
        begin
          LVocabulary := LVocabulary + ',';
        end;
        LVocabulary := LVocabulary + '"midi-' + IntToStr(I) + '"';
      end;
      LPolicy := '{"metric":"notes","unit":"absolute-MIDI-semitone","vocabulary":[' +
        LVocabulary + '],"tolerance_frames":0,"scalar_tolerance":0,"minimum_coverage":0.8,' +
        '"minimum_precision":0.98,"minimum_f1":0.7,"minimum_reference_coverage":1}';
      LReference := '[{"frame":1600,"state":"value","value":60},' +
        '{"frame":3200,"state":"rest"},{"frame":6400,"state":"value","value":64}]';
      LPrediction := LReference;
      LNotes := '[{"start_frame":1200,"end_frame":2400,"note":60},' +
        '{"start_frame":5600,"end_frame":6800,"note":64}]';
    end
    else if AMetric = 'label' then
    begin
      LPolicy := '{"metric":"label","unit":"authored-category","vocabulary":["a","b"],' +
        '"tolerance_frames":0,"scalar_tolerance":0,"minimum_coverage":0.8,' +
        '"minimum_precision":0.98,"minimum_f1":0,"minimum_reference_coverage":1}';
      LReference := '[{"frame":100,"state":"value","value":0},' +
        '{"frame":300,"state":"rest"},{"frame":900,"state":"value","value":1}]';
      LPrediction := LReference;
    end
    else if AMetric = 'scalar' then
    begin
      LPolicy := '{"metric":"scalar","unit":"normalized-amplitude","vocabulary":[],' +
        '"tolerance_frames":0,"scalar_tolerance":0.25,"minimum_coverage":0.5,' +
        '"minimum_precision":0.5,"minimum_f1":0,"minimum_reference_coverage":1}';
      LReference := '[{"frame":100,"state":"value","value":0},' +
        '{"frame":300,"state":"value","value":1}]';
      LPrediction := '[{"frame":100,"state":"value","value":0.25},' +
        '{"frame":300,"state":"value","value":1.5}]';
    end
    else
    begin
      LPolicy := '{"metric":"events","unit":"authored-onset","vocabulary":[],' +
        '"tolerance_frames":10,"scalar_tolerance":0,"minimum_coverage":1,' +
        '"minimum_precision":1,"minimum_f1":1,"minimum_reference_coverage":1}';
      LReference := '[100,300,900]';
      LPrediction := '[110,290,900]';
    end;
    LBinding.Add('scoring_policy_sha256', Save(ADirectory, 'policy.json', LPolicy));
    LBinding.Add('group_id', 'authored');
    LBinding.Add('sample_rate', 8000);
    LBinding.Add('source_frames', 8000);
    LBinding.Add('first_frame', 0);
    LBinding.Add('end_frame', 8000);
    LBinding.Add('partition', 'evaluation');
    LBinding.Add('group_verified', True);
    LBinding.Add('previously_used_for_tuning', False);
    LBinding.Add('reference_complete', True);
    LBinding.Add('estimator_training_overlap', 'not-applicable');
    LClock := TJSONObject.Create;
    try
      LClock.Add('source_sha256', LBinding.Strings['source_sha256']);
      LClock.Add('preparation_sha256', LBinding.Strings['preparation_sha256']);
      LClock.Add('scoring_policy_sha256', LBinding.Strings['scoring_policy_sha256']);
      LClock.Add('sample_rate', 8000);
      LClock.Add('source_frames', 8000);
      LClock.Add('first_frame', 0);
      LClock.Add('end_frame', 8000);
      LDocument := TJSONObject.Create;
      try
        LDocument.Add('format', 'pythian-evaluation-reference');
        LDocument.Add('clock', LClock.Clone);
        LDocument.Add('annotation_policy_sha256', LBinding.Strings['annotation_policy_sha256']);
        LDocument.Add('observations', GetJSON(LReference));
        if LNotes <> '' then
        begin
          LDocument.Add('notes', GetJSON(LNotes));
        end;
        LBinding.Add('reference_sha256', Save(ADirectory, 'reference.json', LDocument.FormatJSON));
      finally
        LDocument.Free;
      end;
      LDocument := TJSONObject.Create;
      try
        LDocument.Add('format', 'pythian-evaluation-prediction');
        LDocument.Add('clock', LClock.Clone);
        LDocument.Add('estimator_sha256', LBinding.Strings['estimator_sha256']);
        LDocument.Add('observations', GetJSON(LPrediction));
        if LNotes <> '' then
        begin
          LDocument.Add('notes', GetJSON(LNotes));
        end;
        Result.Add('prediction_sha256', Save(ADirectory, 'prediction.json', LDocument.FormatJSON));
      finally
        LDocument.Free;
      end;
    finally
      LClock.Free;
    end;
    LFiles := TJSONObject.Create;
    Result.Add('files', LFiles);
    LFiles.Add('source', 'source.wav');
    LFiles.Add('preparation', 'preparation.txt');
    LFiles.Add('reference', 'reference.json');
    LFiles.Add('annotation_policy', 'annotation.txt');
    LFiles.Add('scoring_policy', 'policy.json');
    LFiles.Add('estimator', 'estimator.txt');
    LFiles.Add('prediction', 'prediction.json');
    LFiles.Add('ledger', 'ledger.json');
    LHash := Save(ADirectory, 'ledger.json', '{"format":"pythian-evaluation-ledger",' +
      '"groups":[{"group_id":"authored","group_verified":true,' +
      '"previously_used_for_tuning":false,"partition":"evaluation","sources":["' +
      LBinding.Strings['source_sha256'] + '"]}],"estimators":[{"estimator_sha256":"' +
      LBinding.Strings['estimator_sha256'] + '","training_overlap":"not-applicable"}]}');
    Result.Add('ledger_sha256', LHash);
    Save(ADirectory, 'case.json', Result.FormatJSON);
  except
    Result.Free;
    raise;
  end;
end;

function ReadDocument(const APath: String): TJSONObject;
var
  LBytes: TAudioBytes;
  LText: String;
begin
  LBytes := ReadFileBytes(APath, 1024 * 1024);
  LText := '';
  if Length(LBytes) > 0 then
  begin
    SetString(LText, PAnsiChar(@LBytes[0]), Length(LBytes));
  end;
  Result := TJSONObject(GetJSON(LText));
end;

procedure CheckPhraseCases(const ADirectory: String);
var
  LCase: TJSONObject;
  LDocument: TJSONObject;
  LReport: TJSONObject;
  LRejected: Boolean;
  I: Integer;
begin
  for I := 0 to 2 do
  begin
    LCase := Fixture(ADirectory, 'notes');
    try
      if I < 2 then
      begin
        LDocument := ReadDocument(ADirectory + 'prediction.json');
        try
          if I = 0 then
          begin
            LDocument.Arrays['notes'].Objects[0].Int64s['end_frame'] := 1800;
          end
          else
          begin
            LDocument.Arrays['observations'].Objects[0].Integers['value'] := 61;
          end;
          LCase.Strings['prediction_sha256'] := Save(ADirectory, 'prediction.json',
            LDocument.FormatJSON);
        finally
          LDocument.Free;
        end;
      end
      else
      begin
        LDocument := ReadDocument(ADirectory + 'policy.json');
        try
          LDocument.Floats['minimum_precision'] := 0.97;
          LCase.Objects['binding'].Strings['scoring_policy_sha256'] :=
            Save(ADirectory, 'policy.json', LDocument.FormatJSON);
        finally
          LDocument.Free;
        end;
      end;
      Save(ADirectory, 'case.json', LCase.FormatJSON);
      if I = 0 then
      begin
        LReport := TJSONObject(GetJSON(EvaluateCaseFile(ADirectory + 'case.json')));
        try
          Check((LReport.Objects['scores'].Floats['coverage'] = 1) and
            (LReport.Objects['scores'].Floats['precision'] = 1) and
            (LReport.Objects['scores'].Floats['onset_f1'] = 1) and
            (LReport.Objects['scores'].Floats['full_note_f1'] = 0.5) and
            not LReport.Booleans['metrics_pass'], 'Cell passes hid note-duration failure');
          Save(ADirectory, 'notes-duration-failure.json', LReport.FormatJSON);
        finally
          LReport.Free;
        end;
      end
      else
      begin
        LRejected := False;
        try
          EvaluateCaseFile(ADirectory + 'case.json');
        except
          on E: EAudio do
          begin
            LRejected := True;
            WriteLn('Rejected phrase control ', I, ': ', E.Message);
          end;
        end;
        Check(LRejected, 'Contradictory note evidence or weakened gate accepted');
      end;
    finally
      LCase.Free;
    end;
  end;
end;

procedure Run(const ADirectory: String);
var
  LCase: TJSONObject;
  LDocument: TJSONObject;
  LReport: TJSONObject;
  LRejected: Boolean;
  LMetric: String;
  LBefore: String;
  I: Integer;
begin
  ForceDirectories(ADirectory);
  CheckPhraseCases(ADirectory);
  for I := 0 to 3 do
  begin
    case I of
      0: LMetric := 'label';
      1: LMetric := 'scalar';
      2: LMetric := 'events';
      else LMetric := 'notes';
    end;
    LCase := Fixture(ADirectory, LMetric);
    try
      LBefore := EvaluateCaseFile(ADirectory + 'case.json');
      Check(LBefore = EvaluateCaseFile(ADirectory + 'case.json'), 'Report replay differs');
      LReport := TJSONObject(GetJSON(LBefore));
      try
        Check(LReport.Booleans['metrics_pass'] and LReport.Booleans['independent_case_pass'],
          'Authored fixture failed declared comparison');
        if I = 0 then
        begin
          Check((LReport.Objects['scores'].Integers['correct'] = 2) and
            (LReport.Objects['scores'].Integers['rest_in_rest'] = 1), 'Label counts differ');
        end
        else if I = 1 then
        begin
          Check((LReport.Objects['scores'].Integers['correct'] = 1) and
            (LReport.Objects['scores'].Integers['wrong'] = 1) and
            (LReport.Objects['scores'].Floats['absolute_error_sum'] = 0.75),
            'Scalar wrong/tolerance boundary differs');
        end
        else if I = 2 then
        begin
          Check((LReport.Objects['scores'].Integers['matches'] = 3) and
            (LReport.Objects['scores'].Int64s['absolute_error_frames'] = 20),
            'Event tolerance boundary differs');
        end
        else
        begin
          Check((LReport.Objects['scores'].Integers['matched_notes'] = 2) and
            (LReport.Objects['scores'].Floats['onset_f1'] = 1) and
            (LReport.Objects['scores'].Floats['full_note_f1'] = 1), 'Phrase gates differ');
        end;
      finally
        LReport.Free;
      end;
      Save(ADirectory, LMetric + '-report.json', LBefore);
    finally
      LCase.Free;
    end;
  end;

  for I := 0 to 10 do
  begin
    LCase := Fixture(ADirectory, 'label');
    try
      case I of
        0: Save(ADirectory, 'policy.json', '{}');
        1: LCase.Objects['files'].Strings['reference'] := 'absent-reference.json';
        2: LCase.Objects['binding'].Integers['sample_rate'] := 16000;
        3: LCase.Objects['binding'].Booleans['previously_used_for_tuning'] := True;
        4: LCase.Objects['binding'].Strings['partition'] := 'development';
        5: LCase.Strings['prediction_sha256'] := '';
        6: Save(ADirectory, 'source.wav', 'not a WAV');
        7: LCase.Strings['ledger_sha256'] := '';
        8:
          begin
            LDocument := ReadDocument(ADirectory + 'prediction.json');
            try
              LDocument.Objects['clock'].Strings['scoring_policy_sha256'] := StringOfChar('0', 64);
              LCase.Strings['prediction_sha256'] := Save(ADirectory, 'prediction.json',
                LDocument.FormatJSON);
            finally
              LDocument.Free;
            end;
          end;
        9:
          begin
            LDocument := ReadDocument(ADirectory + 'prediction.json');
            try
              LDocument.Arrays['observations'].Delete(1);
              LCase.Strings['prediction_sha256'] := Save(ADirectory, 'prediction.json',
                LDocument.FormatJSON);
            finally
              LDocument.Free;
            end;
          end;
        10:
          begin
            LDocument := ReadDocument(ADirectory + 'policy.json');
            try
              LDocument.Floats['minimum_coverage'] := 0;
              LCase.Objects['binding'].Strings['scoring_policy_sha256'] :=
                Save(ADirectory, 'policy.json', LDocument.FormatJSON);
            finally
              LDocument.Free;
            end;
          end;
      end;
      Save(ADirectory, 'case.json', LCase.FormatJSON);
      LRejected := False;
      try
        EvaluateCaseFile(ADirectory + 'case.json');
      except
        on E: Exception do
        begin
          LRejected := True;
          WriteLn('Rejected control ', I, ': ', E.Message);
        end;
      end;
      Check(LRejected, 'Invalid evidence or hidden difficult center accepted');
    finally
      LCase.Free;
    end;
  end;

  LCase := Fixture(ADirectory, 'label');
  try
    LCase.Objects['binding'].Strings['partition'] := 'development';
    LCase.Objects['binding'].Booleans['previously_used_for_tuning'] := True;
    LDocument := ReadDocument(ADirectory + 'ledger.json');
    try
      LDocument.Arrays['groups'].Objects[0].Strings['partition'] := 'development';
      LDocument.Arrays['groups'].Objects[0].Booleans['previously_used_for_tuning'] := True;
      LCase.Strings['ledger_sha256'] := Save(ADirectory, 'ledger.json', LDocument.FormatJSON);
    finally
      LDocument.Free;
    end;
    Save(ADirectory, 'case.json', LCase.FormatJSON);
    LReport := TJSONObject(GetJSON(EvaluateCaseFile(ADirectory + 'case.json')));
    try
      Check(LReport.Booleans['metrics_pass'] and not LReport.Booleans['independent_case_pass'],
        'Passing development scores granted independent acceptance');
      Save(ADirectory, 'development-report.json', LReport.FormatJSON);
    finally
      LReport.Free;
    end;
    LCase.Objects['binding'].Booleans['reference_complete'] := False;
    Save(ADirectory, 'case.json', LCase.FormatJSON);
    LReport := TJSONObject(GetJSON(EvaluateCaseFile(ADirectory + 'case.json')));
    try
      Check(not LReport.Booleans['metrics_pass'], 'Partial annotation accepted');
    finally
      LReport.Free;
    end;
  finally
    LCase.Free;
  end;
  LCase := Fixture(ADirectory, 'label');
  LCase.Free;
  WriteLn('PASS file-bound label/scalar/event/note scoring, replay, evidence, phrase gates and exposure');
end;

begin
  if ParamCount <> 1 then
  begin
    raise Exception.Create('Usage: evaluation-files OUTPUT_DIRECTORY');
  end;
  Run(IncludeTrailingPathDelimiter(ParamStr(1)));
end.
