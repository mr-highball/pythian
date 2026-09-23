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
program pythian_localkey_reference;

{$mode delphi}
{$H+}

uses
  Classes, SysUtils, fpjson, zipper,
  pythian.audio, pythian.hash, pythian.tools.files;

const
  CPolicyVersion = 'swd-localkey-reference-1';
  CArchiveBytes = 517380038;
  CArchiveSha256 =
    '774b9b874a82af042ee76f38260acab16bf6ef275c6d67363f96ce63167b99f5';
  CReadmeHash =
    '1d0385821cbbb106dfc6fe7af8f5fa5be33f26ef9ca35c852a57366e9f43d75a';
  CHU33NoticeHash =
    'e4c1ab870a2ba89c70ce7a78a0eda142129f3c6ee312aa16dc30cc5535ab65b0';
  CSC06NoticeHash =
    '03a7e9e576489cfb598a790994ea9e8f1ad3403d4919d94be58581d92e2bf89a';
  CSongs: array[0..1] of String = ('02', '16');
  CWaveHashes: array[0..1] of String = (
    '82df858661d662f162ab3bd3066925dc0faefeb3429584c152bc7b5e91c4e0d2',
    'a3e314904d5c694826d85ddf4723b1988d4ef4571df47760c698a22cc094d253');
  CAnnotationHashes: array[0..1, 0..2] of String = (
    ('ad4c542840d8a589b37cdc4975ec18d0e845ca27f850fccc9d3063f268d6f67b',
     'c9b0a2f602e6093826aaf16608ef8890a558feb966d78b74ac0c5bb5bec55320',
     '82985de070baf8d73aedffc7e42fbeeb9300cb87f2252949cfc8ab7adbcf5e5f'),
    ('d5eb38b6919202fd8bcbebc4e366a260bb88f0b2346164fbc68d48c3d2365935',
     'f2cc33fa7a9b048be396b68c879e64b6c7e9457f35f3a4e78b5fef1651d8f319',
     '0f6dc5e14ba66e9f98da860a0b6f3fdeda06e0822f385dba54f901b04c3dcec0'));
  CScoreHashes: array[0..1] of String = (
    'ed0469d2b430cc5799612f769d6aec1cf5cdc2b8b0413e7d41980864f1741ac2',
    'c74c022e105a221b0fd25f2410dd2372649589002c55dcc4b3427587a8644587');
  CEvaluationSongs: array[0..1] of String = ('05', '19');
  CEvaluationWaveHashes: array[0..1] of String = (
    '8bf3910a59742e39349fbd9d6002cfea9f94f738ce674de0e0a35e29af83433f',
    '2e4cb9fd8c22254d25dc9fddb543d063709f326f92ab7691e6013ca652164937');
  CEvaluationAnnotationHashes: array[0..1, 0..2] of String = (
    ('973b18ae3845654720e85db8f37e7021a739feda6fbb7714c0bbe347586fd15a',
     'fbc793493c27aba632ef038c18cb0d218f868bd0d061cbc9d5f1b345f1d4333e',
     '973b18ae3845654720e85db8f37e7021a739feda6fbb7714c0bbe347586fd15a'),
    ('1d87ec699437ab607f291920e06831c9641e606c6a574d4a56268ce283d6a3f8',
     '1d87ec699437ab607f291920e06831c9641e606c6a574d4a56268ce283d6a3f8',
     '2ffae95e1f2a4f3cd964ca6a8bf647b4bfc5623dc875112115abc80d455af33e'));
  CEvaluationScoreHashes: array[0..1] of String = (
    '66cc556d624a645b451d3f40aea63586a8bfb95690c16465c2ca7493099f8708',
    'ff0566b89d17ad746673e04cea678147e22acf53e4009559271cd744920979e9');
  CRowCounts: array[0..1, 0..2] of Integer = ((12, 5, 9), (3, 3, 4));
  CClasses: array[0..3] of String =
    ('unlabelled', 'partial_coverage', 'full_disagreement', 'unanimous');

type
  TRegion = record
    StartText: String;
    EndText: String;
    Key: String;
    First: Int64;
    Limit: Int64;
  end;
  TRegions = array of TRegion;
  TTracks = array[0..2] of TRegions;
  TBoundaries = array of Int64;
  TExpectedEntry = record
    Name: String;
    Sha256: String;
    MaximumBytes: Integer;
  end;
  TExpectedEntries = array of TExpectedEntry;

var
  GAssetRoot: String;
  GOutputRoot: String;

procedure Require(const ACondition: Boolean; const AMessage: String);
begin
  if not ACondition then
  begin
    raise Exception.Create(AMessage);
  end;
end;

function FileHash(const AName: String; const AMaximum: Integer): String;
begin
  Result := HashAudioBytes(ReadFileBytes(AName, AMaximum));
end;

function ArchiveHash(const APath: String): String;
var
  LStream: TFileStream;
begin
  LStream := TFileStream.Create(APath, fmOpenRead or fmShareDenyWrite);
  try
    Require(LStream.Size = CArchiveBytes, 'SWD archive byte count mismatch');
    Result := Sha256Stream(LStream, LStream.Size);
  finally
    LStream.Free;
  end;
end;

procedure AddExpected(var AEntries: TExpectedEntries;
  const AName, AHash: String; const AMaximum: Integer);
var
  LIndex: Integer;
begin
  LIndex := Length(AEntries);
  SetLength(AEntries, LIndex + 1);
  AEntries[LIndex].Name := AName;
  AEntries[LIndex].Sha256 := AHash;
  AEntries[LIndex].MaximumBytes := AMaximum;
end;

function DevelopmentEntries: TExpectedEntries;
var
  LName: String;
  I: Integer;
  J: Integer;
begin
  Result := nil;
  AddExpected(Result, 'README.txt', CReadmeHash, 16384);
  AddExpected(Result, '03_ExtraMaterial/license_HU33.txt',
    CHU33NoticeHash, 1024);
  AddExpected(Result, '03_ExtraMaterial/license_SC06.txt',
    CSC06NoticeHash, 1024);
  for I := Low(CSongs) to High(CSongs) do
  begin
    LName := 'Schubert_D911-' + CSongs[I];
    AddExpected(Result, '01_RawData/audio_wav/' + LName + '_HU33.wav',
      CWaveHashes[I], 16000000);
    for J := 0 to 2 do
    begin
      AddExpected(Result, '02_Annotations/ann_audio_localkey-ann' +
        IntToStr(J + 1) + '/' + LName + '_HU33.csv',
        CAnnotationHashes[I, J], 16384);
    end;
    AddExpected(Result, '02_Annotations/ann_score_localkey-ann2/' +
      LName + '.csv', CScoreHashes[I], 16384);
  end;
  Require(Length(Result) = 13, 'Expected source entry count');
end;

function EvaluationEntries: TExpectedEntries;
var
  LName: String;
  I: Integer;
  J: Integer;
begin
  Result := nil;
  AddExpected(Result, 'README.txt', CReadmeHash, 16384);
  AddExpected(Result, '03_ExtraMaterial/license_HU33.txt',
    CHU33NoticeHash, 1024);
  AddExpected(Result, '03_ExtraMaterial/license_SC06.txt',
    CSC06NoticeHash, 1024);
  for I := Low(CEvaluationSongs) to High(CEvaluationSongs) do
  begin
    LName := 'Schubert_D911-' + CEvaluationSongs[I];
    AddExpected(Result, '01_RawData/audio_wav/' + LName + '_HU33.wav',
      CEvaluationWaveHashes[I], 16000000);
    for J := 0 to 2 do
    begin
      AddExpected(Result, '02_Annotations/ann_audio_localkey-ann' +
        IntToStr(J + 1) + '/' + LName + '_HU33.csv',
        CEvaluationAnnotationHashes[I, J], 16384);
    end;
    AddExpected(Result, '02_Annotations/ann_score_localkey-ann2/' +
      LName + '.csv', CEvaluationScoreHashes[I], 16384);
  end;
  Require(Length(Result) = 13, 'Expected evaluation entry count');
end;

procedure CheckRoleIsolation;
var
  I: Integer;
  J: Integer;
begin
  for I := Low(CSongs) to High(CSongs) do
  begin
    for J := Low(CEvaluationSongs) to High(CEvaluationSongs) do
    begin
      Require(CSongs[I] <> CEvaluationSongs[J],
        'Composition crosses development and evaluation');
      Require(CWaveHashes[I] <> CEvaluationWaveHashes[J],
        'Identical WAV crosses development and evaluation');
    end;
  end;
  Require((CSongs[0] <> CSongs[1]) and
    (CEvaluationSongs[0] <> CEvaluationSongs[1]) and
    (CEvaluationWaveHashes[0] <> CEvaluationWaveHashes[1]),
    'Duplicate composition group or evaluation WAV');
end;

procedure VerifyEvaluation(const AAssetRoot: String);
var
  LExpected: TExpectedEntries;
  LRoot: String;
  I: Integer;
begin
  CheckRoleIsolation;
  LRoot := IncludeTrailingPathDelimiter(AAssetRoot);
  Require(DirectoryExists(LRoot), 'Missing evaluation asset directory');
  LExpected := EvaluationEntries;
  for I := 0 to High(LExpected) do
  begin
    Require(FileHash(LRoot + LExpected[I].Name,
      LExpected[I].MaximumBytes) = LExpected[I].Sha256,
      'Evaluation entry identity mismatch: ' + LExpected[I].Name);
  end;
  for I := Low(CEvaluationSongs) to High(CEvaluationSongs) do
  begin
    WriteLn('role=independent_evaluation composition=Schubert_D911-',
      CEvaluationSongs[I], ' performance=HU33 source_sha256=',
      CEvaluationWaveHashes[I]);
  end;
  WriteLn('PASS: 13 exact evaluation entries; labels not parsed');
end;

procedure ExtractSelected(const AArchivePath, AOutputRoot: String;
  const AExpected: TExpectedEntries; const ARole: String);
var
  LUnzipper: TUnZipper;
  LNames: TStringList;
  LRoot: String;
  LFound: Integer;
  I: Integer;
  J: Integer;
begin
  Require(not DirectoryExists(AOutputRoot), 'Extract only into a fresh directory');
  Require(ArchiveHash(AArchivePath) = CArchiveSha256,
    'SWD archive SHA256 mismatch');
  LUnzipper := TUnZipper.Create;
  LNames := TStringList.Create;
  try
    LUnzipper.FileName := AArchivePath;
    LUnzipper.Examine;
    for I := 0 to High(AExpected) do
    begin
      LFound := 0;
      for J := 0 to LUnzipper.Entries.Count - 1 do
      begin
        if LUnzipper.Entries[J].ArchiveFileName = AExpected[I].Name then
        begin
          Inc(LFound);
          Require(LUnzipper.Entries[J].Size <= AExpected[I].MaximumBytes,
            'Source entry exceeds byte budget: ' + AExpected[I].Name);
        end;
      end;
      Require(LFound = 1, 'Missing or duplicated ZIP entry: ' +
        AExpected[I].Name);
      LNames.Add(AExpected[I].Name);
    end;
    Require(ForceDirectories(AOutputRoot), 'Cannot create output directory');
    LRoot := IncludeTrailingPathDelimiter(AOutputRoot);
    LUnzipper.OutputPath := LRoot;
    LUnzipper.UnZipFiles(AArchivePath, LNames);
    for I := 0 to High(AExpected) do
    begin
      Require(FileHash(LRoot + AExpected[I].Name,
        AExpected[I].MaximumBytes) = AExpected[I].Sha256,
        'Extracted entry identity mismatch: ' + AExpected[I].Name);
    end;
  finally
    LNames.Free;
    LUnzipper.Free;
  end;
  Require(ArchiveHash(AArchivePath) = CArchiveSha256,
    'SWD archive changed during extraction');
  WriteLn('PASS: ', Length(AExpected), ' exact ', ARole,
    ' ZIP entries and notices extracted');
end;

procedure ExtractDevelopment(const AArchivePath, AOutputRoot: String);
begin
  CheckRoleIsolation;
  ExtractSelected(AArchivePath, AOutputRoot, DevelopmentEntries,
    'development');
end;

procedure ExtractEvaluation(const AArchivePath, AOutputRoot: String);
begin
  CheckRoleIsolation;
  ExtractSelected(AArchivePath, AOutputRoot, EvaluationEntries,
    'evaluation');
end;

function TimeFrame(const AText: String; const ARate: Integer): Int64;
var
  LNumerator: Int64;
  LDenominator: Int64;
  LFractionDigits: Integer;
  LDecimal: Boolean;
  I: Integer;
begin
  Require((Length(AText) > 0) and (Length(AText) <= 12), 'Invalid time length');
  Require((ARate > 0) and (ARate <= 384000), 'Invalid reference rate');
  LNumerator := 0;
  LDenominator := 1;
  LFractionDigits := 0;
  LDecimal := False;
  for I := 1 to Length(AText) do
  begin
    if AText[I] = '.' then
    begin
      Require(not LDecimal and (I > 1) and (I < Length(AText)), 'Invalid decimal');
      LDecimal := True;
    end
    else
    begin
      Require(AText[I] in ['0'..'9'], 'Invalid time character');
      LNumerator := LNumerator * 10 + Ord(AText[I]) - Ord('0');
      if LDecimal then
      begin
        Inc(LFractionDigits);
        Require(LFractionDigits <= 3, 'Unsupported time precision');
        LDenominator := LDenominator * 10;
      end;
    end;
  end;
  Require(LNumerator <= 360 * LDenominator, 'Time exceeds bounded source');
  Result := (LNumerator * ARate * 2 + LDenominator) div (2 * LDenominator);
end;

procedure ValidateKey(const AKey: String);
const
  CRoots: array[0..16] of String =
    ('C', 'C#', 'Db', 'D', 'D#', 'Eb', 'E', 'F', 'F#',
     'Gb', 'G', 'G#', 'Ab', 'A', 'A#', 'Bb', 'B');
var
  I: Integer;
begin
  for I := Low(CRoots) to High(CRoots) do
  begin
    if (AKey = CRoots[I] + ':maj') or (AKey = CRoots[I] + ':min') then
    begin
      Exit;
    end;
  end;
  raise Exception.Create('Unsupported reference key: ' + AKey);
end;

function RootIndex(const AKey: String): Integer;
const
  CRoots: array[0..16] of String =
    ('C', 'C#', 'Db', 'D', 'D#', 'Eb', 'E', 'F', 'F#',
     'Gb', 'G', 'G#', 'Ab', 'A', 'A#', 'Bb', 'B');
  CValues: array[0..16] of Integer =
    (0, 1, 1, 2, 3, 3, 4, 5, 6, 6, 7, 8, 8, 9, 10, 10, 11);
var
  LRoot: String;
  I: Integer;
begin
  ValidateKey(AKey);
  LRoot := Copy(AKey, 1, Pos(':', AKey) - 1);
  for I := Low(CRoots) to High(CRoots) do
  begin
    if LRoot = CRoots[I] then
    begin
      Exit(CValues[I]);
    end;
  end;
  raise Exception.Create('Unsupported reference root');
end;

function KeyMode(const AKey: String): String;
begin
  ValidateKey(AKey);
  Result := Copy(AKey, Pos(':', AKey) + 1, MaxInt);
end;

function ReadAnnotation(const AName, AHash: String; const ARate: Integer;
  const AFrames: Int64; const ACount: Integer): TRegions;
var
  LBytes: TAudioBytes;
  LText: String;
  LLine: String;
  LKey: String;
  LLines: TStringList;
  LFirst: Integer;
  LSecond: Integer;
  LCount: Integer;
  I: Integer;
begin
  Result := nil;
  LBytes := ReadFileBytes(AName, 16384);
  Require(HashAudioBytes(LBytes) = AHash, 'Annotation identity mismatch');
  Require(Length(LBytes) > 0, 'Empty reference');
  SetString(LText, PAnsiChar(@LBytes[0]), Length(LBytes));
  LLines := TStringList.Create;
  try
    LLines.Text := LText;
    Require((LLines.Count >= 2) and (LLines.Count <= 65), 'Reference row bound');
    Require(LLines[0] = 'start;end;key', 'Unexpected reference header');
    LCount := LLines.Count - 1;
    Require((ACount < 0) or (LCount = ACount),
      'Unexpected bound reference count');
    SetLength(Result, LCount);
    for I := 0 to LCount - 1 do
    begin
      LLine := LLines[I + 1];
      LFirst := Pos(';', LLine);
      Require(LFirst > 1, 'Missing reference start');
      Result[I].StartText := Copy(LLine, 1, LFirst - 1);
      Delete(LLine, 1, LFirst);
      LSecond := Pos(';', LLine);
      Require(LSecond > 1, 'Missing reference end');
      Result[I].EndText := Copy(LLine, 1, LSecond - 1);
      LKey := Copy(LLine, LSecond + 1, Length(LLine));
      Require((Length(LKey) >= 7) and (LKey[1] = '"') and
        (LKey[Length(LKey)] = '"'), 'Expected quoted key');
      Result[I].Key := Copy(LKey, 2, Length(LKey) - 2);
      ValidateKey(Result[I].Key);
      Result[I].First := TimeFrame(Result[I].StartText, ARate);
      Result[I].Limit := TimeFrame(Result[I].EndText, ARate);
      Require((Result[I].First < Result[I].Limit) and
        (Result[I].Limit <= AFrames), 'Invalid reference interval');
      if I > 0 then
      begin
        Require(Result[I].First >= Result[I - 1].Limit, 'Overlapping reference');
      end;
    end;
  finally
    LLines.Free;
  end;
end;

function Partition(const ATracks: TTracks; const AFrames: Int64): TJSONObject;
var
  LBounds: TBoundaries;
  LCounts: array[0..3] of Int64;
  LRows: TJSONArray;
  LKeys: TJSONArray;
  LRow: TJSONObject;
  LKey: String;
  LFirstKey: String;
  LSwap: Int64;
  LTotal: Int64;
  LCoverage: Integer;
  LClass: Integer;
  LDisagreement: Boolean;
  I: Integer;
  J: Integer;
  K: Integer;
begin
  Require(AFrames > 0, 'Empty partition extent');
  SetLength(LBounds, 2);
  LBounds[0] := 0;
  LBounds[1] := AFrames;
  for I := 0 to 2 do
  begin
    Require(Length(ATracks[I]) <= 64, 'Partition reference bound');
    for J := 0 to High(ATracks[I]) do
    begin
      Require((ATracks[I][J].First >= 0) and
        (ATracks[I][J].First < ATracks[I][J].Limit) and
        (ATracks[I][J].Limit <= AFrames), 'Partition interval bounds');
      SetLength(LBounds, Length(LBounds) + 2);
      LBounds[High(LBounds) - 1] := ATracks[I][J].First;
      LBounds[High(LBounds)] := ATracks[I][J].Limit;
    end;
  end;
  for I := 1 to High(LBounds) do
  begin
    J := I;
    while (J > 0) and (LBounds[J] < LBounds[J - 1]) do
    begin
      LSwap := LBounds[J];
      LBounds[J] := LBounds[J - 1];
      LBounds[J - 1] := LSwap;
      Dec(J);
    end;
  end;
  FillChar(LCounts, SizeOf(LCounts), 0);
  Result := TJSONObject.Create;
  try
    LRows := TJSONArray.Create;
    Result.Add('regions', LRows);
    for I := 0 to High(LBounds) - 1 do
    begin
      if LBounds[I] = LBounds[I + 1] then
      begin
        Continue;
      end;
      LRow := TJSONObject.Create;
      LRows.Add(LRow);
      LRow.Add('start_frame', LBounds[I]);
      LRow.Add('end_frame', LBounds[I + 1]);
      LKeys := TJSONArray.Create;
      LRow.Add('annotator_keys', LKeys);
      LCoverage := 0;
      LFirstKey := '';
      LDisagreement := False;
      for J := 0 to 2 do
      begin
        LKey := '';
        for K := 0 to High(ATracks[J]) do
        begin
          if (ATracks[J][K].First <= LBounds[I]) and
            (ATracks[J][K].Limit >= LBounds[I + 1]) then
          begin
            Require(LKey = '', 'Ambiguous within-annotator overlap');
            LKey := ATracks[J][K].Key;
          end;
        end;
        if LKey = '' then
        begin
          LKeys.Add(TJSONNull.Create);
        end
        else
        begin
          LKeys.Add(LKey);
          Inc(LCoverage);
          if LFirstKey = '' then
          begin
            LFirstKey := LKey;
          end
          else if LFirstKey <> LKey then
          begin
            LDisagreement := True;
          end;
        end;
      end;
      LClass := 0;
      if LCoverage > 0 then
      begin
        LClass := 1;
      end;
      if LCoverage = 3 then
      begin
        LClass := 3;
        if LDisagreement then
        begin
          LClass := 2;
        end;
      end;
      Inc(LCounts[LClass], LBounds[I + 1] - LBounds[I]);
      LRow.Add('coverage', LCoverage);
      LRow.Add('disagreement', LDisagreement);
      LRow.Add('category', CClasses[LClass]);
    end;
    LTotal := 0;
    for I := 0 to 3 do
    begin
      Inc(LTotal, LCounts[I]);
      Result.Add(CClasses[I] + '_frames', LCounts[I]);
    end;
    Require(LTotal = AFrames, 'Reference partition lost source frames');
    Result.Add('partition_frames', LTotal);
  except
    Result.Free;
    raise;
  end;
end;

procedure AttachScoreTransfer(const AReport: TJSONObject; const AScore,
  AAudio: TRegions; const ASourceFrames: Int64;
  const ARequireGap: Boolean);
var
  LRows: TJSONArray;
  LGaps: TJSONArray;
  LParts: TJSONArray;
  LKeys: TJSONArray;
  LRow: TJSONObject;
  LPart: TJSONData;
  LScoreGapMs: Int64;
  LAudioGapMs: Int64;
  LStartFrame: Int64;
  LEndFrame: Int64;
  LTranspose: Integer;
  LThisTranspose: Integer;
  LGapCount: Integer;
  I: Integer;
  J: Integer;
begin
  Require(Length(AScore) = Length(AAudio), 'Score/audio ann2 row count');
  LParts := TJSONArray(AReport.FindPath('regions'));
  Require((LParts <> nil) and (LParts.Count > 0), 'Missing audio partitions');
  LRows := TJSONArray.Create;
  AReport.Add('score_audio_ann2_rows', LRows);
  LGaps := TJSONArray.Create;
  AReport.Add('ann2_score_transferred_ambiguity', LGaps);
  LTranspose := -1;
  LGapCount := 0;
  for I := 0 to High(AScore) do
  begin
    Require(KeyMode(AScore[I].Key) = KeyMode(AAudio[I].Key),
      'Score/audio ann2 mode mismatch');
    LThisTranspose :=
      (RootIndex(AAudio[I].Key) - RootIndex(AScore[I].Key) + 12) mod 12;
    if LTranspose < 0 then
    begin
      LTranspose := LThisTranspose;
    end
    else
    begin
      Require(LThisTranspose = LTranspose,
        'Score/audio ann2 transposition changed');
    end;
    LRow := TJSONObject.Create;
    LRows.Add(LRow);
    LRow.Add('score_start_measure', AScore[I].StartText);
    LRow.Add('score_end_measure', AScore[I].EndText);
    LRow.Add('score_key', AScore[I].Key);
    LRow.Add('audio_start_seconds', AAudio[I].StartText);
    LRow.Add('audio_end_seconds', AAudio[I].EndText);
    LRow.Add('audio_start_frame', AAudio[I].First);
    LRow.Add('audio_end_frame', AAudio[I].Limit);
    LRow.Add('audio_key', AAudio[I].Key);
    if I = High(AScore) then
    begin
      Continue;
    end;
    LScoreGapMs := AScore[I + 1].First - AScore[I].Limit;
    LAudioGapMs := TimeFrame(AAudio[I + 1].StartText, 1000) -
      TimeFrame(AAudio[I].EndText, 1000);
    Require((LScoreGapMs > 2) = (LAudioGapMs > 2),
      'Score/audio ann2 gap presence mismatch');
    if LScoreGapMs <= 2 then
    begin
      Continue;
    end;
    LStartFrame := AAudio[I].Limit;
    LEndFrame := AAudio[I + 1].First;
    Require((LStartFrame >= 0) and (LStartFrame < LEndFrame) and
      (LEndFrame <= ASourceFrames), 'Transferred ambiguity outside source');
    for J := 0 to LParts.Count - 1 do
    begin
      LPart := LParts.Items[J];
      if (TJSONObject(LPart).Get('end_frame', 0) <= LStartFrame) or
        (TJSONObject(LPart).Get('start_frame', 0) >= LEndFrame) then
      begin
        Continue;
      end;
      LKeys := TJSONArray(LPart.FindPath('annotator_keys'));
      Require((LKeys <> nil) and (LKeys.Count = 3) and
        (LKeys.Items[1].JSONType = jtNull),
        'Ann2 labels a score-transferred ambiguity span');
    end;
    LRow := TJSONObject.Create;
    LGaps.Add(LRow);
    LRow.Add('score_start_measure', AScore[I].EndText);
    LRow.Add('score_end_measure', AScore[I + 1].StartText);
    LRow.Add('audio_start_seconds', AAudio[I].EndText);
    LRow.Add('audio_end_seconds', AAudio[I + 1].StartText);
    LRow.Add('start_frame', LStartFrame);
    LRow.Add('end_frame', LEndFrame);
    LRow.Add('label', 'ann2_score_transferred_ambiguous');
    Inc(LGapCount);
  end;
  Require((not ARequireGap) or (LGapCount > 0),
    'No transferred ambiguity intervals');
  if LTranspose > 6 then
  begin
    Dec(LTranspose, 12);
  end;
  AReport.Add('score_to_audio_transposition_semitones', LTranspose);
end;

procedure Controls;
var
  LTracks: TTracks;
  LReport: TJSONObject;
  LRejected: Boolean;
  I: Integer;
begin
  CheckRoleIsolation;
  Require(TimeFrame('0.005', 100) = 1, 'Tie must round upward');
  Require(TimeFrame('0.004', 100) = 0, 'Sub-tie boundary');
  Require(TimeFrame('0.3', 22050) = 6615, 'Original clock conversion');
  Require(TimeFrame('360', 22050) = 7938000,
    'Long reference source bound');
  LRejected := False;
  try
    TimeFrame('0,3', 22050);
  except
    on E: Exception do
    begin
      LRejected := True;
    end;
  end;
  Require(LRejected, 'Locale-specific time must reject');
  for I := 0 to 2 do
  begin
    SetLength(LTracks[I], 1);
    LTracks[I][0].First := 2;
    LTracks[I][0].Limit := 8;
    LTracks[I][0].Key := 'C:maj';
  end;
  LTracks[1][0].Limit := 6;
  LTracks[2][0].First := 4;
  LTracks[2][0].Key := 'D:min';
  LReport := Partition(LTracks, 10);
  try
    Require((LReport.Int64s['unlabelled_frames'] = 4) and
      (LReport.Int64s['partial_coverage_frames'] = 4) and
      (LReport.Int64s['full_disagreement_frames'] = 2) and
      (LReport.Int64s['unanimous_frames'] = 0), 'Coverage/disagreement accounting');
  finally
    LReport.Free;
  end;
  LTracks[1][0].Limit := 8;
  LTracks[2][0].First := 2;
  LTracks[2][0].Key := 'C:maj';
  LReport := Partition(LTracks, 10);
  try
    Require((LReport.Int64s['unlabelled_frames'] = 4) and
      (LReport.Int64s['partial_coverage_frames'] = 0) and
      (LReport.Int64s['full_disagreement_frames'] = 0) and
      (LReport.Int64s['unanimous_frames'] = 6), 'Unanimous coverage accounting');
  finally
    LReport.Free;
  end;
  WriteLn('PASS: exact clocks and separate reference uncertainty');
end;

procedure Preflight(const AIndex: Integer; const AEvaluation: Boolean);
var
  LClip: TAudioClip;
  LHash: String;
  LName: String;
  LOutput: String;
  LTracks: TTracks;
  LScore: TRegions;
  LReport: TJSONObject;
  LAnnotations: TJSONArray;
  LIntervals: TJSONArray;
  LAnnotation: TJSONObject;
  LRow: TJSONObject;
  LStarted: QWord;
  LSong: String;
  LWaveHash: String;
  LScoreHash: String;
  LAnnotationHashes: array[0..2] of String;
  LExpectedRows: array[0..2] of Integer;
  LRole: String;
  LExposure: String;
  I: Integer;
  J: Integer;
begin
  Require((AIndex >= 0) and (AIndex <= 1), 'Unknown reference selection');
  if AEvaluation then
  begin
    CheckRoleIsolation;
    LSong := CEvaluationSongs[AIndex];
    LWaveHash := CEvaluationWaveHashes[AIndex];
    LScoreHash := CEvaluationScoreHashes[AIndex];
    LRole := 'independent_evaluation';
    LExposure := 'all performances and excerpts of D911-05 and D911-19';
    for I := 0 to 2 do
    begin
      LAnnotationHashes[I] := CEvaluationAnnotationHashes[AIndex, I];
      LExpectedRows[I] := -1;
    end;
  end
  else
  begin
    LSong := CSongs[AIndex];
    LWaveHash := CWaveHashes[AIndex];
    LScoreHash := CScoreHashes[AIndex];
    LRole := 'development';
    LExposure := 'all performances and excerpts of D911-02 and D911-16';
    for I := 0 to 2 do
    begin
      LAnnotationHashes[I] := CAnnotationHashes[AIndex, I];
      LExpectedRows[I] := CRowCounts[AIndex, I];
    end;
  end;
  LOutput := GOutputRoot + 'localkey-' + LSong + '.json';
  Require(not FileExists(LOutput), 'Preserve existing reference output');
  LStarted := GetTickCount64;
  LClip := nil;
  LReport := nil;
  try
    Require(FileHash(GAssetRoot + 'README.txt', 16384) = CReadmeHash,
      'README identity');
    Require(FileHash(GAssetRoot + '03_ExtraMaterial/license_HU33.txt', 1024) =
      CHU33NoticeHash, 'HU33 notice identity');
    Require(FileHash(GAssetRoot + '03_ExtraMaterial/license_SC06.txt', 1024) =
      CSC06NoticeHash, 'SC06 notice identity');
    LName := 'Schubert_D911-' + LSong + '_HU33';
    LHash := FileHash(GAssetRoot + '01_RawData/audio_wav/' + LName + '.wav', 16000000);
    Require(LHash = LWaveHash, 'WAV identity mismatch');
    LClip := LoadWaveSource(GAssetRoot + '01_RawData/audio_wav/' + LName + '.wav', LHash);
    Require(LHash = LWaveHash, 'WAV changed during load');
    Require((LClip.SampleRate = 22050) and (LClip.Channels = 1) and
      (LClip.FrameCount <= 360 * 22050),
      'Unexpected source geometry: rate=' + IntToStr(LClip.SampleRate) +
      ' channels=' + IntToStr(LClip.Channels) +
      ' frames=' + IntToStr(LClip.FrameCount));
    for I := 0 to 2 do
    begin
      LTracks[I] := ReadAnnotation(GAssetRoot + '02_Annotations/ann_audio_localkey-ann' +
        IntToStr(I + 1) + '/' + LName + '.csv', LAnnotationHashes[I],
        LClip.SampleRate, LClip.FrameCount, LExpectedRows[I]);
    end;
    LScore := ReadAnnotation(GAssetRoot +
      '02_Annotations/ann_score_localkey-ann2/Schubert_D911-' +
      LSong + '.csv', LScoreHash, 1000, 180000,
      LExpectedRows[1]);
    LReport := Partition(LTracks, LClip.FrameCount);
    AttachScoreTransfer(LReport, LScore, LTracks[1], LClip.FrameCount,
      not AEvaluation);
    LReport.Add('source', LName);
    LReport.Add('source_sha256', LHash);
    LReport.Add('source_rate', LClip.SampleRate);
    LReport.Add('source_channels', LClip.Channels);
    LReport.Add('source_frames', LClip.FrameCount);
    LReport.Add('score_ann2_sha256', LScoreHash);
    LReport.Add('policy', CPolicyVersion);
    LReport.Add('producer', 'pythian.localkey.reference');
    LReport.Add('composition_group', 'Schubert_D911-' + LSong);
    LReport.Add('role', LRole);
    LReport.Add('exposure', LExposure);
    LReport.Add('independent_case_pass', AEvaluation);
    LReport.Add('waveform_predictions', False);
    LReport.Add('verified_nontonal_reference', False);
    LAnnotations := TJSONArray.Create;
    LReport.Add('annotations', LAnnotations);
    for I := 0 to 2 do
    begin
      LAnnotation := TJSONObject.Create;
      LAnnotations.Add(LAnnotation);
      LAnnotation.Add('annotator', I + 1);
      LAnnotation.Add('sha256', LAnnotationHashes[I]);
      LIntervals := TJSONArray.Create;
      LAnnotation.Add('intervals', LIntervals);
      for J := 0 to High(LTracks[I]) do
      begin
        LRow := TJSONObject.Create;
        LIntervals.Add(LRow);
        LRow.Add('start_seconds', LTracks[I][J].StartText);
        LRow.Add('end_seconds', LTracks[I][J].EndText);
        LRow.Add('start_frame', LTracks[I][J].First);
        LRow.Add('end_frame', LTracks[I][J].Limit);
        LRow.Add('key', LTracks[I][J].Key);
      end;
    end;
    Require(GetTickCount64 - LStarted <= 30000, 'Preflight time budget exceeded');
    WriteTextFile(LOutput, LReport.FormatJSON);
    WriteLn('PASS: ', LName, ' frames=', LClip.FrameCount,
      ' elapsed_ms=', GetTickCount64 - LStarted);
  finally
    LReport.Free;
    LClip.Free;
  end;
end;

begin
  try
    Require(ParamCount >= 1,
      'Usage: pythian.localkey.reference controls | extract <archive> <fresh-asset-root> | extract-evaluation <archive> <fresh-asset-root> | development <asset-root> <fresh-output-root> | verify-evaluation <asset-root> | evaluation <asset-root> <fresh-output-root>');
    if (ParamStr(1) = 'controls') and (ParamCount = 1) then
    begin
      Controls;
    end
    else if (ParamStr(1) = 'extract') and (ParamCount = 3) then
    begin
      ExtractDevelopment(ParamStr(2), ParamStr(3));
    end
    else if (ParamStr(1) = 'extract-evaluation') and (ParamCount = 3) then
    begin
      ExtractEvaluation(ParamStr(2), ParamStr(3));
    end
    else if (ParamStr(1) = 'verify-evaluation') and (ParamCount = 2) then
    begin
      VerifyEvaluation(ParamStr(2));
    end
    else if (ParamStr(1) = 'development') and (ParamCount = 3) then
    begin
      GAssetRoot := IncludeTrailingPathDelimiter(ParamStr(2));
      GOutputRoot := IncludeTrailingPathDelimiter(ParamStr(3));
      Require(DirectoryExists(GAssetRoot), 'Missing source directory');
      Require(DirectoryExists(GOutputRoot), 'Missing output directory');
      Require(not FileExists(GOutputRoot + 'localkey-02.json') and
        not FileExists(GOutputRoot + 'localkey-16.json'),
        'Preserve existing reference outputs');
      Preflight(0, False);
      Preflight(1, False);
    end
    else if (ParamStr(1) = 'evaluation') and (ParamCount = 3) then
    begin
      GAssetRoot := IncludeTrailingPathDelimiter(ParamStr(2));
      GOutputRoot := IncludeTrailingPathDelimiter(ParamStr(3));
      Require(DirectoryExists(GAssetRoot), 'Missing evaluation source directory');
      Require(DirectoryExists(GOutputRoot), 'Missing evaluation output directory');
      Require(not FileExists(GOutputRoot + 'localkey-05.json') and
        not FileExists(GOutputRoot + 'localkey-19.json'),
        'Preserve existing evaluation reference outputs');
      Preflight(0, True);
      Preflight(1, True);
    end
    else
    begin
      raise Exception.Create('Unknown local-key reference mode');
    end;
  except
    on LError: Exception do
    begin
      WriteLn(StdErr, LError.ClassName, ': ', LError.Message);
      ExitCode := 1;
    end;
  end;
end.
