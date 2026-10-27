(* MIT License
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
SOFTWARE. *)
program pythian_tests_corpus_portability_qa;
{$mode delphi}{$H+}{$codepage utf8}

uses
  SysUtils,
  pythian.audio,
  pythian.corpus.text,
  pythian.corpus.intake;

const
  CAccentText: TCorpusText = 'é';
  CWhitespaceIdentity: TCorpusText = ' style﻿';
  CBmpRecording: TCorpusText = '';
  CAstralRecording: TCorpusText = '𐀀';

var
  GChecks: Integer;

procedure Check(const ACondition: Boolean; const AMessage: String);
begin
  if not ACondition then
  begin
    raise Exception.Create(AMessage);
  end;
  Inc(GChecks);
end;

procedure RejectText(const AText: TCorpusText; const AMessage: String);
var
  LRejected: Boolean;
begin
  LRejected := False;
  try
    ValidateCorpusText(AText);
  except
    on LException: EAudio do
    begin
      LRejected := True;
    end;
  end;
  Check(LRejected, AMessage);
end;

function Definition: TCorpusIntakeDefinition;
begin
  Result := Default(TCorpusIntakeDefinition);
  Result.StyleId := 'style';
  SetLength(Result.Families, 1);
  SetLength(Result.Sources, 1);
  with Result.Families[0] do
  begin
    Id := 'family';
    WorkId := 'work';
    IdentityEvidence := 'caller';
    Partition := cpTraining;
    Verified := True;
  end;
  with Result.Sources[0] do
  begin
    Id := 'source';
    Path := 'source.wav';
    Sha256 := StringOfChar('a', 64);
    RecordingId := 'record';
    SampleRate := 8000;
    Channels := 1;
    FrameCount := 16000;
    Acquisition := 'caller';
    LicenseNotice := 'MIT';
    PreparationPolicy := 'unchanged';
    PreparationSha256 := StringOfChar('b', 64);
    PreparationAccepted := True;
    PeakCeiling := 0.9;
    Parent := -1;
    ParentEndFrame := FrameCount;
    ParentGain := 1;
  end;
end;

var
  LDefinition: TCorpusIntakeDefinition;
  LCopy: TCorpusIntakeDefinition;
  LPlan: TCorpusIntakePlan;
  LOther: TCorpusIntakePlan;
  LRows: TCorpusRecordingContributions;
  LRanges: TCorpusIntakeRanges;
  LRejected: Boolean;
  LText: TCorpusText;
begin
  ValidateCorpusText(StringOfChar('a', 4096));
  Inc(GChecks);
  RejectText(StringOfChar('a', 4097), 'byte limit');
  LText := StringOfChar('a', 4094);
  LText := LText + CAccentText;
  {$ifdef pas2js}
  Check(Length(LText) = 4095, 'multibyte fixture UTF-16 length');
  {$else}
  Check(Length(LText) = 4096, 'multibyte fixture UTF-8 byte length');
  {$endif}
  ValidateCorpusText(LText);
  Inc(GChecks);
  RejectText(LText + 'a', 'multibyte byte limit');
  RejectText('a' + #0 + 'b', 'NUL');
  ValidateCorpusText('é');
  ValidateCorpusText('é');
  Check(CompareCorpusText('é', 'é') <> 0, 'normalization changes identity');
  ValidateCorpusText('￿');
  ValidateCorpusText('􏿿');
  {$ifdef pas2js}
  LText := #$D800;
  RejectText(LText, 'unpaired high surrogate');
  LText := #$DC00;
  RejectText(LText, 'unpaired low surrogate');
  {$else}
  RejectText(#$C0#$80, 'overlong UTF-8');
  RejectText(#$ED#$A0#$80, 'surrogate UTF-8');
  RejectText(#$F4#$90#$80#$80, 'out of range UTF-8');
  RejectText(#$FF, 'invalid UTF-8');
  {$endif}
  Check(CompareCorpusText('', '𐀀') < 0, 'UTF-8 scalar ordering');
  LDefinition := Definition;
  LDefinition.StyleId := CWhitespaceIdentity;
  LPlan := TCorpusIntakePlan.Create(LDefinition);
  try
    LCopy := LPlan.CopyDefinition;
    Check(LCopy.StyleId = CWhitespaceIdentity, 'non-ASCII whitespace identity');
  finally
    LPlan.Free;
  end;
  LDefinition.StyleId := ' style';
  LRejected := False;
  try
    LPlan := TCorpusIntakePlan.Create(LDefinition);
    LPlan.Free;
  except
    on LException: EAudio do
    begin
      LRejected := True;
    end;
  end;
  Check(LRejected, 'leading ASCII whitespace rejected');
  LDefinition.StyleId := 'style' + #9;
  LRejected := False;
  try
    LPlan := TCorpusIntakePlan.Create(LDefinition);
    LPlan.Free;
  except
    on LException: EAudio do
    begin
      LRejected := True;
    end;
  end;
  Check(LRejected, 'trailing ASCII control rejected');
  LDefinition := Definition;
  SetLength(LDefinition.Families, 2);
  LDefinition.Families[1] := LDefinition.Families[0];
  LDefinition.Families[1].Id := 'family-2';
  LDefinition.Families[1].WorkId := 'work-2';
  LDefinition.Families[1].Partition := cpDevelopment;
  SetLength(LDefinition.Sources, 3);
  LDefinition.Sources[0].RecordingId := CAstralRecording;
  LDefinition.Sources[1] := LDefinition.Sources[0];
  LDefinition.Sources[1].Id := 'derivative';
  LDefinition.Sources[1].Sha256 := StringOfChar('c', 64);
  LDefinition.Sources[1].Parent := 0;
  LDefinition.Sources[1].ParentFirstFrame := 4000;
  LDefinition.Sources[1].ParentEndFrame := 12000;
  LDefinition.Sources[1].FrameCount := 8000;
  LDefinition.Sources[2] := LDefinition.Sources[0];
  LDefinition.Sources[2].Id := 'other';
  LDefinition.Sources[2].RecordingId := CBmpRecording;
  LDefinition.Sources[2].Family := 1;
  LDefinition.Sources[2].Sha256 := StringOfChar('d', 64);
  SetLength(LDefinition.Ranges, 4);
  LDefinition.Ranges[0].EndFrame := 8000;
  LDefinition.Ranges[0].SongId := 'é';
  LDefinition.Ranges[0].BoundaryEvidence := 'review';
  LDefinition.Ranges[0].Multiplicity := 2;
  LDefinition.Ranges[1] := LDefinition.Ranges[0];
  LDefinition.Ranges[1].BoundaryEvidence := 'other evidence';
  LDefinition.Ranges[2].Source := 1;
  LDefinition.Ranges[2].EndFrame := 8000;
  LDefinition.Ranges[2].Multiplicity := 1;
  LDefinition.Ranges[3].Source := 2;
  LDefinition.Ranges[3].EndFrame := 4000;
  LDefinition.Ranges[3].SongId := 'é';
  LDefinition.Ranges[3].BoundaryEvidence := 'review';
  LDefinition.Ranges[3].Multiplicity := 1;
  LPlan := TCorpusIntakePlan.Create(LDefinition);
  try
    LDefinition.Sources[0].RecordingId := 'mutated';
    LCopy := LPlan.CopyDefinition;
    Check(LCopy.Sources[0].RecordingId = CAstralRecording, 'input detached');
    LCopy.Sources[0].RecordingId := 'changed';
    LCopy := LPlan.CopyDefinition;
    Check(LCopy.Sources[0].RecordingId = CAstralRecording, 'output detached');
    LRows := LPlan.Contributions;
    Check((Length(LRows) = 2) and (LRows[0].RecordingId = CBmpRecording) and
      (LRows[1].RecordingId = CAstralRecording), 'portable recording order');
    Check((LRows[1].UniqueFrames = 12000) and (LRows[1].UnknownBoundaryFrames = 8000) and
      (LRows[1].DeclaredRows = 3) and (LRows[1].DistinctDeclarations = 2) and
      (LRows[1].DeclaredWeightedFrames = 24000), 'derivative union and duplicate');
    WriteLn('ordered=', LRows[0].RecordingId, ',', LRows[1].RecordingId,
      ';unique=', LRows[0].UniqueFrames, ',', LRows[1].UniqueFrames,
      ';weighted=', LRows[0].DeclaredWeightedFrames, ',', LRows[1].DeclaredWeightedFrames);
  finally
    LPlan.Free;
  end;
  LDefinition := Definition;
  SetLength(LDefinition.Ranges, 2);
  LDefinition.Ranges[0].EndFrame := 8000;
  LDefinition.Ranges[0].SongId := 'song';
  LDefinition.Ranges[0].BoundaryEvidence := 'review';
  LDefinition.Ranges[0].Multiplicity := 3;
  LDefinition.Ranges[1] := LDefinition.Ranges[0];
  LPlan := TCorpusIntakePlan.Create(LDefinition);
  try
    LRanges := LPlan.TrainingRanges;
    Check((Length(LRanges) = 1) and (LRanges[0].Multiplicity = 3), 'duplicate training');
    LCopy := LPlan.CopyDefinition;
    LCopy.Families[0].PreviouslyUsed := True;
    LCopy.Families[0].PriorExposure := [cpDevelopment];
    LOther := TCorpusIntakePlan.Create(LCopy);
    try
      RequireIntakeHistory(LPlan, LOther);
      LRejected := False;
      try
        RequireIntakeHistory(LOther, LPlan);
      except
        on LException: EAudio do
        begin
          LRejected := True;
        end;
      end;
      Check(LRejected, 'history exposure cannot disappear');
    finally
      LOther.Free;
    end;
  finally
    LPlan.Free;
  end;
  LDefinition := Definition;
  LDefinition.Sources[0].FrameCount := MaximumIntakeFrame;
  LDefinition.Sources[0].ParentEndFrame := MaximumIntakeFrame;
  SetLength(LDefinition.Ranges, 1);
  LDefinition.Ranges[0].EndFrame := MaximumIntakeFrame;
  LDefinition.Ranges[0].Multiplicity := 2;
  LPlan := TCorpusIntakePlan.Create(LDefinition);
  try
    LRejected := False;
    try
      LPlan.Contributions;
    except
      on LException: EAudio do
      begin
        LRejected := True;
      end;
    end;
    Check(LRejected, 'weighted product overflow');
  finally
    LPlan.Free;
  end;
  LDefinition.Ranges[0].Multiplicity := 1;
  SetLength(LDefinition.Ranges, 2);
  LDefinition.Ranges[1] := LDefinition.Ranges[0];
  LDefinition.Ranges[1].FirstFrame := 1;
  LPlan := TCorpusIntakePlan.Create(LDefinition);
  try
    LRejected := False;
    try
      LPlan.Contributions;
    except
      on LException: EAudio do
      begin
        LRejected := True;
      end;
    end;
    Check(LRejected, 'weighted sum overflow');
  finally
    LPlan.Free;
  end;
  LDefinition.Ranges[0].EndFrame := MaximumIntakeFrame - 1;
  LDefinition.Ranges[1].FirstFrame := MaximumIntakeFrame - 1;
  LPlan := TCorpusIntakePlan.Create(LDefinition);
  try
    LRows := LPlan.Contributions;
    Check(LRows[0].DeclaredWeightedFrames = MaximumIntakeFrame, 'exact sum boundary');
  finally
    LPlan.Free;
  end;
  LDefinition := Definition;
  LDefinition.Families[0].Partition := cpEvaluation;
  LDefinition.Families[0].PriorExposure := [cpTraining];
  LRejected := False;
  try
    LPlan := TCorpusIntakePlan.Create(LDefinition);
    LPlan.Free;
  except
    on LException: EAudio do
    begin
      LRejected := True;
    end;
  end;
  Check(LRejected, 'evaluation exposure rejected');
  WriteLn('PASS portability');
end.
