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

function Artifact(const ADigest, AGroup: String;
  const AParents: array of String): TJSONObject;
var
  LParents: TJSONArray;
  I: Integer;
begin
  Result := TJSONObject.Create;
  Result.Add('sha256', ADigest);
  Result.Add('group_id', AGroup);
  LParents := TJSONArray.Create;
  Result.Add('parents', LParents);
  for I := 0 to High(AParents) do
  begin
    LParents.Add(AParents[I]);
  end;
end;

function Ledger(const ABinding: TJSONObject; const APredictionDigest: String): TJSONObject;
var
  LArtifacts: TJSONArray;
begin
  Result := TJSONObject(GetJSON('{"format":"pythian-evaluation-ledger",' +
    '"groups":[{"group_id":"authored","group_verified":true,' +
    '"previously_used_for_tuning":false,"partition":"evaluation","sources":["' +
    ABinding.Strings['source_sha256'] + '"]}],"estimators":[{"estimator_sha256":"' +
    ABinding.Strings['estimator_sha256'] + '","training_overlap":"not-applicable"}]}'));
  LArtifacts := TJSONArray.Create;
  Result.Add('artifacts', LArtifacts);
  LArtifacts.Add(Artifact(ABinding.Strings['source_sha256'], 'authored', []));
  LArtifacts.Add(Artifact(ABinding.Strings['preparation_sha256'], '',
    [ABinding.Strings['source_sha256']]));
  LArtifacts.Add(Artifact(ABinding.Strings['annotation_policy_sha256'], '', []));
  LArtifacts.Add(Artifact(ABinding.Strings['estimator_sha256'], '', []));
  LArtifacts.Add(Artifact(ABinding.Strings['reference_sha256'], '',
    [ABinding.Strings['source_sha256'], ABinding.Strings['preparation_sha256'],
    ABinding.Strings['annotation_policy_sha256']]));
  LArtifacts.Add(Artifact(APredictionDigest, '',
    [ABinding.Strings['source_sha256'], ABinding.Strings['preparation_sha256'],
    ABinding.Strings['estimator_sha256']]));
end;

function Annotation(const AOutput, AInput: String): TJSONObject;
begin
  Result := TJSONObject.Create;
  Result.Add('format', 'pythian-evaluation-annotation');
  Result.Add('output', AOutput);
  Result.Add('input_class', AInput);
  Result.Add('scope_id', 'authored-reference-scope');
  Result.Add('purpose', 'primary');
  Result.Add('reference_method', 'authored');
  Result.Add('label_convention', 'Exact policy vocabulary; no implicit category equivalences');
  Result.Add('time_convention', 'Integer absolute source frames, half-open note intervals');
  Result.Add('uncertainty_convention', 'Explicit cell states; events independently complete in scope');
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
    if AMetric = 'notes' then
    begin
      LDocument := Annotation('notes', 'attributed-voice');
    end
    else if AMetric = 'label' then
    begin
      LDocument := Annotation('key', 'tonal-region');
    end
    else if AMetric = 'scalar' then
    begin
      LDocument := Annotation('sound-envelope', 'recorded-sound');
    end
    else
    begin
      LDocument := Annotation('onsets', 'annotated-recording');
    end;
    try
      LBinding.Add('annotation_policy_sha256', Save(ADirectory, 'annotation.txt',
        LDocument.FormatJSON));
    finally
      LDocument.Free;
    end;
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
      LPolicy := '{"metric":"label","unit":"key-root-mode","vocabulary":["C-major","G-major"],' +
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
        '{"frame":300,"state":"value","value":0.5}]';
      LPrediction := '[{"frame":100,"state":"value","value":0.25},' +
        '{"frame":300,"state":"value","value":1}]';
    end
    else
    begin
      LPolicy := '{"metric":"events","unit":"source-frame","vocabulary":[],' +
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
    LDocument := Ledger(LBinding, Result.Strings['prediction_sha256']);
    try
      LHash := Save(ADirectory, 'ledger.json', LDocument.FormatJSON);
    finally
      LDocument.Free;
    end;
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
        LDocument := Ledger(LCase.Objects['binding'], LCase.Strings['prediction_sha256']);
        try
          LCase.Strings['ledger_sha256'] := Save(ADirectory, 'ledger.json', LDocument.FormatJSON);
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

procedure CheckAncestryCases(const ADirectory: String);
var
  LCase: TJSONObject;
  LDocument: TJSONObject;
  LReport: TJSONObject;
  LArtifacts: TJSONArray;
  LGroup: TJSONObject;
  LParentHash: String;
  LPaletteHash: String;
  LRejected: Boolean;
  LReason: String;
  I: Integer;
begin
  LParentHash := Save(ADirectory, 'outside-plan-source.txt', 'Authored separate training input');
  LPaletteHash := Save(ADirectory, 'outside-plan-palette.txt', 'Authored frozen palette parent');
  for I := 0 to 11 do
  begin
    LCase := Fixture(ADirectory, 'label');
    try
      LDocument := ReadDocument(ADirectory + 'ledger.json');
      try
        LArtifacts := LDocument.Arrays['artifacts'];
        { A palette grandparent is outside the immediate evaluation case but
          must remain in the complete ledger. Default: independent training. }
        LGroup := TJSONObject(GetJSON('{"group_id":"outside-plan","group_verified":true,' +
          '"previously_used_for_tuning":false,"partition":"training","sources":["' +
          LParentHash + '"]}'));
        LDocument.Arrays['groups'].Add(LGroup);
        LArtifacts.Insert(0, Artifact(LParentHash, 'outside-plan', []));
        LArtifacts.Insert(1, Artifact(LPaletteHash, '', [LParentHash]));
        LArtifacts.Objects[5].Arrays['parents'].Add(LPaletteHash);
        LDocument.Arrays['estimators'].Objects[0].Strings['training_overlap'] := 'disjoint';
        LCase.Objects['binding'].Strings['estimator_training_overlap'] := 'disjoint';
        LReason := '';
        case I of
          0: ; { Positive: data-derived estimator with disjoint declared training. }
          1:
            begin
              LGroup.Strings['partition'] := 'evaluation';
              LReason := 'Estimator ancestry includes an evaluation';
            end;
          2:
            begin
              LArtifacts.Delete(1);
              LReason := 'Missing evaluation ledger ancestor';
            end;
          3:
            begin
              LArtifacts.Objects[0].Arrays['parents'].Add(LPaletteHash);
              LReason := 'Missing evaluation ledger ancestor';
            end;
          4:
            begin
              LArtifacts.Objects[0].Strings['group_id'] := '';
              LReason := 'Recording artifact cannot hide its family';
            end;
          5:
            begin
              LArtifacts.Objects[6].Arrays['parents'].Add(
                LCase.Objects['binding'].Strings['estimator_sha256']);
              LReason := 'Reference ancestry includes the evaluated estimator';
            end;
          6:
            begin
              LArtifacts.Objects[6].Arrays['parents'].Delete(2);
              LReason := 'Reference ancestry must bind source';
            end;
          7:
            begin
              LArtifacts.Objects[2].Arrays['parents'].Add(LParentHash);
              LReason := 'Prepared source ancestry crosses';
            end;
          8:
            begin
              LArtifacts.Objects[1].Arrays['parents'].Add(LParentHash);
              LReason := 'Artifact parents must be unique';
            end;
          9:
            begin
              LDocument.Arrays['estimators'].Objects[0].Strings['training_overlap'] :=
                'not-applicable';
              LCase.Objects['binding'].Strings['estimator_training_overlap'] := 'not-applicable';
              LReason := 'Data-derived estimator cannot declare';
            end;
          10:
            begin
              LArtifacts.Objects[5].Arrays['parents'].Add(
                LCase.Objects['binding'].Strings['source_sha256']);
              LReason := 'Estimator ancestry includes an evaluation';
            end;
          11:
            begin
              LGroup.Strings['partition'] := 'development';
              LGroup.Booleans['previously_used_for_tuning'] := True;
              LCase.Objects['binding'].Strings['estimator_training_overlap'] := 'unknown';
              LDocument.Arrays['estimators'].Objects[0].Strings['training_overlap'] := 'unknown';
            end;
        end;
        LCase.Strings['ledger_sha256'] := Save(ADirectory, 'ledger.json', LDocument.FormatJSON);
      finally
        LDocument.Free;
      end;
      Save(ADirectory, 'case.json', LCase.FormatJSON);
      if (I = 0) or (I = 11) then
      begin
        LReport := TJSONObject(GetJSON(EvaluateCaseFile(ADirectory + 'case.json')));
        try
          Check(LReport.Booleans['metrics_pass'] and
            (LReport.Booleans['independent_case_pass'] = (I = 0)),
            'Ancestry eligibility differs from declared overlap');
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
            Check(Pos(LReason, E.Message) > 0, 'Ancestry control rejected for wrong reason: ' +
              E.Message);
            LRejected := True;
            WriteLn('Rejected ancestry control ', I, ': ', E.Message);
          end;
        end;
        Check(LRejected, 'Incomplete, contradictory or exposed ancestry accepted');
      end;
    finally
      LCase.Free;
    end;
  end;
end;

procedure CheckPredictionAncestry(const ADirectory: String);
var
  LCase: TJSONObject;
  LBinding: TJSONObject;
  LLedger: TJSONObject;
  LArtifacts: TJSONArray;
  LParents: TJSONArray;
  LReport: TJSONObject;
  LBaselineScores: String;
  LHelper: String;
  LOtherSource: String;
  LReason: String;
  LIndependent: Boolean;
  LRejected: Boolean;
  I: Integer;
begin
  LHelper := Save(ADirectory, 'prediction-helper.txt', 'Declared helper or annotation model');
  LOtherSource := Save(ADirectory, 'prediction-other-source.txt', 'Separate evaluation recording');
  LCase := Fixture(ADirectory, 'label');
  try
    LReport := TJSONObject(GetJSON(EvaluateCaseFile(ADirectory + 'case.json')));
    try
      LBaselineScores := LReport.Objects['scores'].AsJSON;
    finally
      LReport.Free;
    end;
  finally
    LCase.Free;
  end;
  for I := 0 to 17 do
  begin
    LCase := Fixture(ADirectory, 'label');
    try
      LBinding := LCase.Objects['binding'];
      LLedger := ReadDocument(ADirectory + 'ledger.json');
      try
        LArtifacts := LLedger.Arrays['artifacts'];
        LParents := LArtifacts.Objects[5].Arrays['parents'];
        LReason := '';
        LIndependent := I in [0, 8, 15, 17];
        case I of
          0: ; { Exact source/preparation/estimator-only prediction. }
          1:
            begin
              LArtifacts.Delete(5);
              LReason := 'Missing evaluation ledger ancestor';
            end;
          2:
            begin
              LArtifacts.Objects[5].Strings['sha256'] := LHelper;
              LReason := 'Missing evaluation ledger ancestor';
            end;
          3:
            begin
              LParents.Delete(1);
              LReason := 'Prediction ancestry must bind';
            end;
          4:
            begin
              LParents.Delete(2);
              LReason := 'Prediction ancestry must bind';
            end;
          5, 9:
            begin
              LParents.Add(LBinding.Strings['reference_sha256']);
              LReason := 'prediction-depends-on-reference';
              if I = 9 then
              begin
                LBinding.Strings['partition'] := 'development';
                LBinding.Booleans['previously_used_for_tuning'] := True;
                LLedger.Arrays['groups'].Objects[0].Strings['partition'] := 'development';
                LLedger.Arrays['groups'].Objects[0].Booleans['previously_used_for_tuning'] := True;
              end;
            end;
          6:
            begin
              LArtifacts.Insert(5, Artifact(LHelper, '', [LBinding.Strings['reference_sha256']]));
              LParents.Add(LHelper);
              LReason := 'prediction-depends-on-reference';
            end;
          7:
            begin
              { Shared model ancestor, neither artifact consumes the other. }
              LArtifacts.Insert(4, Artifact(LHelper, '', []));
              LArtifacts.Objects[5].Arrays['parents'].Add(LHelper);
              LParents.Add(LHelper);
              LReason := 'prediction-shares-reference-ancestry';
            end;
          8: LParents.Insert(2, TJSONString.Create(LBinding.Strings['annotation_policy_sha256']));
          10, 12, 13:
            begin
              if I = 10 then
              begin
                LArtifacts.Insert(5, Artifact(LHelper, '', []));
              end
              else
              begin
                LArtifacts.Insert(5, Artifact(LHelper, '', [LBinding.Strings['source_sha256']]));
              end;
              LParents.Add(LHelper);
              LLedger.Arrays['estimators'].Add(TJSONObject.Create([
                'estimator_sha256', LHelper, 'training_overlap', 'disjoint']));
              if I = 10 then
              begin
                LLedger.Arrays['estimators'].Objects[1].Strings['training_overlap'] := 'unknown';
                LReason := 'prediction-estimator-training-overlap';
              end
              else if I = 12 then
              begin
                LReason := 'prediction-estimator-uses-evaluation-source';
              end
              else
              begin
                LLedger.Arrays['estimators'].Objects[1].Strings['training_overlap'] := 'not-applicable';
                LReason := 'Data-derived estimator cannot declare';
              end;
            end;
          11:
            begin
              LLedger.Arrays['groups'].Add(TJSONObject(GetJSON(
                '{"group_id":"other","group_verified":true,"previously_used_for_tuning":false,' +
                '"partition":"evaluation","sources":["' + LOtherSource + '"]}')));
              LArtifacts.Insert(0, Artifact(LOtherSource, 'other', []));
              LParents.Insert(0, TJSONString.Create(LOtherSource));
              LReason := 'prediction-uses-additional-evaluation-source';
            end;
          14:
            begin
              LParents.Add(LCase.Strings['prediction_sha256']);
              LReason := 'Missing evaluation ledger ancestor';
            end;
          15:
            begin
              LArtifacts.Insert(5, Artifact(LHelper, '',
                [LBinding.Strings['source_sha256'], LBinding.Strings['preparation_sha256'],
                LBinding.Strings['estimator_sha256']]));
              LParents.Clear;
              LParents.Add(LHelper);
            end;
          16:
            begin
              LArtifacts.Insert(1, Artifact(LHelper, '', []));
              LArtifacts.Objects[2].Arrays['parents'].Add(LHelper);
              LReason := 'prediction-shares-reference-ancestry';
            end;
          17:
            begin
              LLedger.Arrays['groups'].Objects[0].Arrays['sources'].Add(LOtherSource);
              LArtifacts.Insert(0, Artifact(LOtherSource, 'authored', []));
              LArtifacts.Objects[1].Arrays['parents'].Add(LOtherSource);
            end;
        end;
        LCase.Strings['ledger_sha256'] := Save(ADirectory, 'ledger.json', LLedger.FormatJSON);
      finally
        LLedger.Free;
      end;
      Save(ADirectory, 'case.json', LCase.FormatJSON);
      if I in [1..4, 13, 14] then
      begin
        LRejected := False;
        try
          EvaluateCaseFile(ADirectory + 'case.json');
        except
          on E: EAudio do
          begin
            Check(Pos(LReason, E.Message) > 0, 'Prediction control rejected for unrelated reason: ' + E.Message);
            LRejected := True;
          end;
        end;
        Check(LRejected, 'Missing or invalid prediction dependencies accepted');
      end
      else
      begin
        LReport := TJSONObject(GetJSON(EvaluateCaseFile(ADirectory + 'case.json')));
        try
          Check(LReport.Objects['scores'].AsJSON = LBaselineScores,
            'Prediction ancestry changed numeric score denominators');
          Check(LReport.Booleans['metrics_pass'] and
            (LReport.Booleans['prediction_ancestry_independent'] = LIndependent) and
            (LReport.Booleans['independent_eligible'] = LIndependent) and
            (LReport.Booleans['independent_case_pass'] = LIndependent) and
            (LReport.Strings['prediction_ancestry_reason'] = LReason),
            'Prediction ancestry eligibility or reason differs');
          Save(ADirectory, 'prediction-ancestry-' + IntToStr(I) + '.json', LReport.FormatJSON);
        finally
          LReport.Free;
        end;
      end;
    finally
      LCase.Free;
    end;
  end;
  WriteLn('PASS prediction dependency binding, direct/transitive oracle exclusion and unchanged scores');
end;

procedure PublishComparison(const ADirectory: String;
  const ACase, AAnnotation, APolicy, AReference, APrediction: TJSONObject);
var
  LBinding: TJSONObject;
  LLedger: TJSONObject;
begin
  LBinding := ACase.Objects['binding'];
  LBinding.Strings['annotation_policy_sha256'] := Save(ADirectory, 'annotation.txt',
    AAnnotation.FormatJSON);
  LBinding.Strings['scoring_policy_sha256'] := Save(ADirectory, 'policy.json', APolicy.FormatJSON);
  AReference.Strings['annotation_policy_sha256'] := LBinding.Strings['annotation_policy_sha256'];
  AReference.Objects['clock'].Strings['scoring_policy_sha256'] :=
    LBinding.Strings['scoring_policy_sha256'];
  APrediction.Objects['clock'].Strings['scoring_policy_sha256'] :=
    LBinding.Strings['scoring_policy_sha256'];
  LBinding.Strings['reference_sha256'] := Save(ADirectory, 'reference.json', AReference.FormatJSON);
  ACase.Strings['prediction_sha256'] := Save(ADirectory, 'prediction.json', APrediction.FormatJSON);
  LLedger := Ledger(LBinding, ACase.Strings['prediction_sha256']);
  try
    ACase.Strings['ledger_sha256'] := Save(ADirectory, 'ledger.json', LLedger.FormatJSON);
  finally
    LLedger.Free;
  end;
  Save(ADirectory, 'case.json', ACase.FormatJSON);
end;

procedure CheckProviderCases(const ADirectory: String);
const
  COutputs: array[0..11] of String = ('onsets', 'beats', 'tempo', 'key',
    'part-ownership', 'harmony', 'harmony-changes', 'groove-events',
    'groove-accent', 'groove-offset', 'sound-spectrum', 'sound-envelope');
  CInputs: array[0..11] of String = ('annotated-recording', 'annotated-recording',
    'annotated-recording', 'tonal-region', 'attributed-part', 'harmonic-region',
    'harmonic-region', 'attributed-part', 'attributed-part', 'attributed-part',
    'recorded-sound', 'recorded-sound');
  CMetrics: array[0..11] of String = ('events', 'events', 'scalar', 'label',
    'label', 'label', 'events', 'events', 'scalar', 'scalar', 'scalar', 'scalar');
  CUnits: array[0..11] of String = ('source-frame', 'source-frame',
    'microseconds-per-quarter', 'key-root-mode', 'part-note-identity', 'chord-identity',
    'source-frame', 'source-frame', 'normalized-amplitude', 'quarter-note-offset',
    'normalized-band-energy', 'normalized-amplitude');
var
  LCase: TJSONObject;
  LAnnotation: TJSONObject;
  LPolicy: TJSONObject;
  LReference: TJSONObject;
  LPrediction: TJSONObject;
  LReport: TJSONObject;
  LRow: TJSONObject;
  LRejected: Boolean;
  I: Integer;
  J: Integer;
begin
  for I := Low(COutputs) to High(COutputs) do
  begin
    LCase := Fixture(ADirectory, CMetrics[I]);
    LAnnotation := Annotation(COutputs[I], CInputs[I]);
    LPolicy := nil;
    LReference := nil;
    LPrediction := nil;
    try
      LPolicy := ReadDocument(ADirectory + 'policy.json');
      LReference := ReadDocument(ADirectory + 'reference.json');
      LPolicy.Strings['unit'] := CUnits[I];
      LPolicy.Floats['minimum_coverage'] := 0.8;
      LPolicy.Floats['minimum_precision'] := 0.98;
      if I = 1 then
      begin
        LAnnotation.Strings['scope_id'] := 'authored-quarter-note-beats';
        LPolicy.Int64s['tolerance_frames'] := 240; { 30 ms at 8 kHz, independently fixed. }
      end;
      if I = 4 then
      begin
        LPolicy.Arrays['vocabulary'].Strings[0] := 'bass:midi-60';
        LPolicy.Arrays['vocabulary'].Strings[1] := 'lead:midi-60';
        LAnnotation.Strings['scope_id'] := 'independently-attributed-ownership';
      end;
      if I = 5 then
      begin
        LPolicy.Arrays['vocabulary'].Strings[0] := 'C-major';
        LPolicy.Arrays['vocabulary'].Strings[1] := 'C-minor';
      end;
      if CMetrics[I] = 'events' then
      begin
        LReference.Arrays['observations'].Clear;
        LReference.Arrays['observations'].Add(1000);
        LReference.Arrays['observations'].Add(3000);
        LReference.Arrays['observations'].Add(6000);
      end
      else if I = 2 then
      begin
        LReference.Arrays['observations'].Objects[0].Floats['value'] := 500000;
        LReference.Arrays['observations'].Objects[1].Floats['value'] := 600000;
        LPolicy.Floats['scalar_tolerance'] := 10000;
      end;
      for J := 0 to 2 do
      begin
        FreeAndNil(LPrediction);
        LPrediction := ReadDocument(ADirectory + 'prediction.json');
        LPrediction.Delete('observations');
        LPrediction.Add('observations', LReference.Arrays['observations'].Clone);
        if J > 0 then
        begin
          if CMetrics[I] = 'events' then
          begin
            if J = 1 then
            begin
              LPrediction.Arrays['observations'].Int64s[0] := 1500;
            end
            else
            begin
              LPrediction.Arrays['observations'].Delete(0);
            end;
          end
          else
          begin
            LRow := LPrediction.Arrays['observations'].Objects[0];
            if J = 2 then
            begin
              LRow.Delete('value');
              LRow.Strings['state'] := 'unknown';
            end
            else if I = 2 then
            begin
              LRow.Floats['value'] := 700000;
            end
            else
            begin
              LRow.Integers['value'] := 1;
            end;
          end;
        end;
        PublishComparison(ADirectory, LCase, LAnnotation, LPolicy, LReference, LPrediction);
        LReport := TJSONObject(GetJSON(EvaluateCaseFile(ADirectory + 'case.json')));
        try
          Check(LReport.Booleans['metrics_pass'] = (J = 0), 'Provider comparison gate differs');
          Check(LReport.Booleans['independent_case_pass'] = (J = 0),
            'Provider reference-breaking case accepted');
          if (CMetrics[I] <> 'events') and (J > 0) then
          begin
            Check((LReport.Objects['scores'].Integers['wrong'] = Ord(J = 1)) and
              (LReport.Objects['scores'].Integers['unknown_active'] = Ord(J = 2)),
              'Wrong provider output and missing output were conflated');
          end;
          Save(ADirectory, COutputs[I] + '-' + IntToStr(J) + '-report.json', LReport.FormatJSON);
        finally
          LReport.Free;
        end;
        if (I = 1) and (J = 1) then
        begin
          LAnnotation.Strings['purpose'] := 'diagnostic';
          LPolicy.Int64s['tolerance_frames'] := 560; { Diagnostic 70 ms includes the 500-frame error. }
          PublishComparison(ADirectory, LCase, LAnnotation, LPolicy, LReference, LPrediction);
          LReport := TJSONObject(GetJSON(EvaluateCaseFile(ADirectory + 'case.json')));
          try
            Check(LReport.Booleans['metrics_pass'] and
              not LReport.Booleans['independent_case_pass'],
              'Relaxed diagnostic timing became primary acceptance');
          finally
            LReport.Free;
          end;
          LAnnotation.Strings['purpose'] := 'primary';
          LPolicy.Int64s['tolerance_frames'] := 240;
        end;
      end;
      { Preserve a valid evidence graph: this must reject the semantic mismatch,
        not merely an out-of-date document hash. }
      LPolicy.Strings['unit'] := 'wrong-musical-unit';
      PublishComparison(ADirectory, LCase, LAnnotation, LPolicy, LReference, LPrediction);
      LRejected := False;
      try
        EvaluateCaseFile(ADirectory + 'case.json');
      except
        on E: EAudio do
        begin
          Check(Pos('does not match the scoring metric and unit', E.Message) > 0,
            'Provider contract rejected for unrelated reason: ' + E.Message);
          LRejected := True;
        end;
      end;
      Check(LRejected, 'Incompatible provider unit accepted');
    finally
      LPrediction.Free;
      LReference.Free;
      LPolicy.Free;
      LAnnotation.Free;
      LCase.Free;
    end;
  end;
end;

procedure CheckAnnotationFailures(const ADirectory: String);
var
  LCase: TJSONObject;
  LAnnotation: TJSONObject;
  LPolicy: TJSONObject;
  LReference: TJSONObject;
  LPrediction: TJSONObject;
  LReason: String;
  LRejected: Boolean;
  I: Integer;
begin
  for I := 0 to 4 do
  begin
    if I = 4 then
    begin
      LCase := Fixture(ADirectory, 'events');
    end
    else
    begin
      LCase := Fixture(ADirectory, 'scalar');
    end;
    LAnnotation := nil;
    LPolicy := nil;
    LReference := nil;
    LPrediction := nil;
    try
      LAnnotation := ReadDocument(ADirectory + 'annotation.txt');
      LPolicy := ReadDocument(ADirectory + 'policy.json');
      LReference := ReadDocument(ADirectory + 'reference.json');
      LPrediction := ReadDocument(ADirectory + 'prediction.json');
      case I of
        0:
          begin
            LAnnotation.Strings['input_class'] := 'unsupported-input';
            LReason := 'does not match the scoring metric and unit';
          end;
        1:
          begin
            LAnnotation.Strings['reference_method'] := 'evaluated-estimator';
            LReason := 'Unsupported reference method';
          end;
        2:
          begin
            LAnnotation.Strings['scope_id'] := ' ';
            LReason := 'nonempty bounded text';
          end;
        3:
          begin
            LPrediction.Arrays['observations'].Objects[0].Floats['value'] := 1.1;
            LReason := 'Normalized comparison value outside';
          end;
        else
          begin
            LAnnotation.Strings['output'] := 'beats';
            LPolicy.Int64s['tolerance_frames'] := 560;
            LReason := 'Primary beat comparison requires the fixed 30-ms tolerance';
          end;
      end;
      PublishComparison(ADirectory, LCase, LAnnotation, LPolicy, LReference, LPrediction);
      LRejected := False;
      try
        EvaluateCaseFile(ADirectory + 'case.json');
      except
        on E: EAudio do
        begin
          Check(Pos(LReason, E.Message) > 0, 'Annotation control rejected for unrelated reason: ' +
            E.Message);
          LRejected := True;
        end;
      end;
      Check(LRejected, 'Invalid musical annotation contract accepted');
    finally
      LPrediction.Free;
      LReference.Free;
      LPolicy.Free;
      LAnnotation.Free;
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
  CheckPredictionAncestry(ADirectory);
  CheckPhraseCases(ADirectory);
  CheckAncestryCases(ADirectory);
  CheckProviderCases(ADirectory);
  CheckAnnotationFailures(ADirectory);
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
      if I in [8, 9] then
      begin
        LDocument := Ledger(LCase.Objects['binding'], LCase.Strings['prediction_sha256']);
        try
          LCase.Strings['ledger_sha256'] := Save(ADirectory, 'ledger.json', LDocument.FormatJSON);
        finally
          LDocument.Free;
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
