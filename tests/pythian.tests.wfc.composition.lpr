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
program pythian_tests_wfc_composition;

{$mode delphi}
{$H+}

uses
  Classes,
  SysUtils,
  pythian.audio,
  pythian.music,
  pythian.music.compose,
  pythian.time,
  pythian.wfc.compose;

const
  CSourceText: array[0..7] of String = (
    'C Am F G C Am F G C Am F G F G C C',
    'C F Am G C F Am G C F Am G F G C C',
    'C Am F G C F Am G C Am F G F G C C',
    'C F Am G C Am F G C F Am G F G C C',
    'C Am Em G C Am F G C Am Em G F G C C',
    'C F Em G C F Am G C F Em G F G C C',
    'C Am F G F Am F G C Am F G F G C C',
    'C F Am G F Am F G C F Am G F G C C');
  CCandidateTokensHash = 'bb56f52d7a2ca2cb2bd6f0f2d5f3094ecab38810b6b5076587b080de3c438c86';
  CCandidateEventHash = 'bb69726e127085102952321e173e543f4e131de227c3d904394547b463fe3008';

procedure Check(const ACondition: Boolean; const AMessage: String);
begin
  if not ACondition then
    raise Exception.Create(AMessage);
end;

function SameGate(const ALeft, ARight: TNoteGate): Boolean;
begin
  Result := (ALeft.StartTick = ARight.StartTick) and
    (ALeft.EndTick = ARight.EndTick) and
    (ALeft.Pitch = ARight.Pitch) and
    (ALeft.Velocity = ARight.Velocity) and
    (ALeft.Track = ARight.Track) and
    (ALeft.Voice = ARight.Voice) and
    (ALeft.Channel = ARight.Channel);
end;

function ChordFromText(const AText: String): TCompositionChord;
begin
  if AText = 'C' then
    Exit(ccC);
  if AText = 'Am' then
    Exit(ccAm);
  if AText = 'F' then
    Exit(ccF);
  if AText = 'G' then
    Exit(ccG);
  if AText = 'Em' then
    Exit(ccEm);
  raise Exception.Create('Invalid fixture chord ' + AText);
end;

function BuildSources: TCompositionChordSources;
var
  LWords: TStringList;
  LSource: Integer;
  LBar: Integer;
begin
  Result := nil;
  SetLength(Result, Length(CSourceText));
  LWords := TStringList.Create;
  try
    for LSource := 0 to High(CSourceText) do
    begin
      LWords.Delimiter := ' ';
      LWords.StrictDelimiter := True;
      LWords.DelimitedText := CSourceText[LSource];
      Check(LWords.Count = WfcCompositionChordBars,
        'Frozen source phrase does not have 16 bars');
      for LBar := 0 to WfcCompositionChordBars - 1 do
        Result[LSource][LBar] := ChordFromText(LWords[LBar]);
    end;
  finally
    LWords.Free;
  end;
end;

procedure Run;
var
  LSources: TCompositionChordSources;
  LOutput: TNoteSequence;
  LReport: TWfcCompositionReport;
  LCoreReport: TCompositionScaffoldReport;
  LBefore: TNoteSequence;
  LBeforeGates: TNoteGates;
  LBeforeClock: TTempoMap;
  LAfterClock: TTempoMap;
  LBeforeChanges: TTempoChanges;
  LAfterChanges: TTempoChanges;
  LIndex: Integer;
  LSuccess: Boolean;
begin
  LSources := BuildSources;
  LOutput := GenerateSourceFreeComposition(1731, LCoreReport);
  LBefore := LOutput;
  try
    LSuccess := TryGenerateWfcChordComposition(LSources, 1731, LOutput, LReport);
    Check(LSuccess, 'Frozen chord candidate failed: ' + String(LReport.Text));
    Check(LReport.Status = wcsSolved, 'Candidate report is not solved');
    Check(LReport.SourceCount = 8, 'Unexpected frozen source count');
    Check(LReport.ModelStateCount = 13, 'Unexpected frozen model state count');
    Check(LReport.ModelVocabularyCount = 5, 'Unexpected chord vocabulary size');
    Check(LReport.SourceHash =
      'af907d53dc497a2d5c433395cc1ef3cdcc4bcbcf54551e2f40db68421082687b',
      'Frozen source hash changed');
    Check(LReport.HasLegalWholePath and LReport.HasNovelWholePath and
      LReport.SolveCalled, 'Reachability or WFC solve was not recorded');
    Check(LReport.ReachabilityWork = 2171,
      'Frozen reachability work changed');
    Check(LReport.ModelTextHash =
      '37790abbc7c7fec4685f4c8b23b30e4f7b8c2b4ba4d0698555288f15cce05343',
      'Frozen WFC model text hash changed');
    Check(LReport.TokenHash = CCandidateTokensHash,
      'Frozen candidate token hash changed');
    Check(LReport.FullSourceCopy = False,
      'Candidate copied a complete frozen source');
    Check(LReport.ChangedBarCount = 3,
      'Candidate changed-bar count differs from frozen result');
    Check((LReport.ChangedBassPitchCount = 8) and
      (LReport.ChangedMelodyPitchCount = 9),
      'Candidate projected pitch changes differ from frozen result');
    Check(LReport.GeneratedScheduleText =
      'C Am F G | C Am Em G | F G F G | F G C C',
      'Candidate schedule differs from frozen chord path');
    Check(LReport.PhraseUnionMatchCounts[0] = 9,
      'Phrase 1 source-union match count changed');
    Check(LReport.PhraseUnionMatchCounts[1] = 2,
      'Phrase 2 source-union match count changed');
    Check(LReport.PhraseUnionMatchCounts[2] = 0,
      'Novel phrase 3 unexpectedly matched a frozen source phrase');
    Check(LReport.PhraseUnionMatchCounts[3] = 8,
      'Phrase 4 source-union match count changed');
    Check(LOutput <> LBefore,
      'Successful generation did not replace the owned prior sequence');
    Check(LOutput.NoteCount = 97, 'Candidate event count changed');
    Check(LReport.EventLedgerHash = CCandidateEventHash,
      'Candidate projected event-ledger hash changed');
    Write(String(LReport.Text));
  finally
    LOutput.Free;
  end;

  LOutput := GenerateSourceFreeComposition(1731, LCoreReport);
  LBefore := LOutput;
  try
    LBeforeGates := LOutput.CopyGates;
    LBeforeClock := LOutput.CopyClock;
    try
      LBeforeChanges := LBeforeClock.CopyChanges;
    finally
      LBeforeClock.Free;
    end;
    LSources[0][15] := ccEm;
    LSuccess := TryGenerateWfcChordComposition(LSources, 1731, LOutput, LReport);
    Check(not LSuccess, 'Invalid source set unexpectedly generated a result');
    Check(LReport.Status = wcsInvalidSources,
      'Invalid source set has unexpected status');
    Check(not LReport.SolveCalled,
      'Invalid source set reached WFC solve');
    Check(LOutput = LBefore,
      'Failure replaced the caller-owned prior sequence');
    Check(LOutput.NoteCount = Length(LBeforeGates),
      'Failure changed the caller-owned gate count');
    for LIndex := 0 to High(LBeforeGates) do
      Check(SameGate(LOutput.GateAt(LIndex), LBeforeGates[LIndex]),
        'Failure mutated a caller-owned note gate');
    LAfterClock := LOutput.CopyClock;
    try
      LAfterChanges := LAfterClock.CopyChanges;
      Check(Length(LAfterChanges) = Length(LBeforeChanges),
        'Failure changed the caller-owned tempo count');
      for LIndex := 0 to High(LBeforeChanges) do
        Check((LAfterChanges[LIndex].Tick = LBeforeChanges[LIndex].Tick) and
          (LAfterChanges[LIndex].MicrosecondsPerQuarter =
            LBeforeChanges[LIndex].MicrosecondsPerQuarter),
          'Failure mutated the caller-owned tempo map');
    finally
      LAfterClock.Free;
    end;
    WriteLn('failure_preservation=PASS');
  finally
    LOutput.Free;
  end;
end;

begin
  try
    Run;
    WriteLn('wfc_chord_composition_adapter_test=PASS');
  except
    on E: Exception do
    begin
      WriteLn(StdErr, 'wfc_chord_composition_adapter_test=FAIL ',
        E.ClassName, ': ', E.Message);
      ExitCode := 1;
    end;
  end;
end.
