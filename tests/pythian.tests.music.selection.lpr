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

program MusicSelectionConformance;
{$mode delphi}
{$H+}

uses SysUtils, pythian.audio, pythian.text, pythian.music.selection;

var Checks: Integer;

procedure Check(const ACondition: Boolean; const AMessage: String);
begin
  Inc(Checks);
  if not ACondition then raise Exception.Create(AMessage);
end;

function Selection(const ASource: String; const AWhole: Boolean;
  const AStart, AEnd: Int64; const ALabels: TMusicClassifications): TClassifiedMusicSelection;
begin
  Result := Default(TClassifiedMusicSelection);
  Result.SourceId := ASource;
  Result.WholeRecording := AWhole;
  Result.StartFrame := AStart;
  Result.EndFrame := AEnd;
  Result.Classifications := Copy(ALabels);
end;

procedure Flags(const AFlags: TMusicSelectionFlags; const AExpected: array of Boolean);
var I: Integer;
begin
  Check(Length(AFlags) = Length(AExpected), 'Exactly one flag per original selection');
  for I := 0 to High(AExpected) do
    Check(AFlags[I] = AExpected[I], 'Exact classified inclusion at row' + IntToStr(I));
end;

procedure Reject(const ASelections: TClassifiedMusicSelections; const ALabel: TScalarText);
var
  LFlags: TMusicSelectionFlags;
  LFailed: Boolean;
begin
  LFlags := [True];
  LFailed := False;
  try LFlags := ClassifyMusicSelection(ASelections, ALabel);
  except on E: EAudio do LFailed := True end;
  Check(LFailed, 'Malformed or unsupported classification rejects');
  Flags(LFlags, [True]);
end;

procedure Run;
var
  LRows: TClassifiedMusicSelections;
  LBad: TClassifiedMusicSelections;
  LLabels: TMusicClassifications;
  LMask: TMusicSelectionFlags;
  LMusic: TScalarText;
begin
  LRows := [Selection('a', True, 0, 100, ['lofi']),
    Selection('a', False, 0, 20, ['warm', 'all']),
    Selection('a', False, 40, 60, ['warm']),
    Selection('b', True, 0, 80, ['stoner']),
    Selection('b', False, 10, 30, ['warm', 'bright'])];
  Flags(ClassifyMusicSelection(LRows, 'warm'), [False, True, True, False, True]);
  Flags(ClassifyMusicSelection(LRows, 'lofi'), [True, False, False, False, False]);
  Flags(ClassifyMusicSelection(LRows, 'bright'), [False, False, False, False, True]);
  Flags(ClassifyMusicSelection([LRows[4], LRows[3], LRows[2], LRows[1], LRows[0]], 'warm'),
    [True, False, True, True, False]);
  LLabels := AvailableMusicClassifications(LRows);
  Check((Length(LLabels) = 5) and (LLabels[0] = 'lofi') and (LLabels[1] = 'warm'),
    'Labels retain caller spelling and unique first occurrence');
  LLabels[0] := 'changed';
  Check(LRows[0].Classifications[0] = 'lofi', 'Returned labels do not alias source metadata');
  LMask := ClassifyMusicSelection(LRows, 'warm');
  LMask[1] := False;
  Check(ClassifyMusicSelection(LRows, 'warm')[1], 'Returned flags are detached');

  LBad := Copy(LRows);
  LBad[0].Classifications := ['warm'];
  Flags(ClassifyMusicSelection(LBad, 'warm'), [True, False, False, False, True]);
  Check(LRows[0].Classifications[0] = 'lofi', 'Whole-label edits preserve baseline inputs');
  LBad := Copy(LRows);
  LBad[2].StartFrame := 20;
  LBad[2].EndFrame := 40;
  Flags(ClassifyMusicSelection(LBad, 'warm'), [False, True, True, False, True]);
  LBad[2].StartFrame := 19;
  Reject(LBad, 'warm');
  LBad[0].Classifications := ['warm'];
  Flags(ClassifyMusicSelection(LBad, 'warm'), [True, False, False, False, True]);

  Reject(LRows, 'Warm');
  Reject(LRows, 'missing');
  Reject(LRows, '');
  Reject(LRows, #0);
  Reject(nil, 'warm');
  Check(Length(AvailableMusicClassifications(nil)) = 0, 'Empty library has no invented label');
  Reject([LRows[1]], 'warm');
  LBad := Copy(LRows);
  LBad[1].EndFrame := 101;
  Reject(LBad, 'warm');
  LBad := Copy(LRows);
  LBad[1].StartFrame := -1;
  Reject(LBad, 'warm');
  LBad := Copy(LRows);
  LBad[1].EndFrame := 0;
  Reject(LBad, 'warm');
  LBad := Copy(LRows);
  LBad[1] := LBad[0];
  Reject(LBad, 'lofi');
  LBad := Copy(LRows);
  SetLength(LBad[0].Classifications, MaximumMusicClassifications + 1);
  Reject(LBad, 'warm');

  LMusic := ScalarText($1F3B5);
  LBad := Copy(LRows);
  LBad[0].Classifications := [LMusic];
  Flags(ClassifyMusicSelection(LBad, LMusic), [True, False, False, False, False]);
  LLabels := AvailableMusicClassifications(LBad);
  Check(ScalarTextByteCount(LLabels[0], 4, False) = 4,
    'Supplementary Unicode label keeps its canonical UTF-8 identity');
  LBad[0].Classifications := ['e' + ScalarText($301)];
  Reject(LBad, ScalarText($E9));
  WriteLn('PASS musical classification selection: ', Checks, ' checks');
end;

begin
  Run;
end.
