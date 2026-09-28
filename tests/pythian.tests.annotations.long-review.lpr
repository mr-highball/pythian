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
program pythian_tests_annotations_long_review;

{$mode delphi}
{$H+}

uses
  Classes, SysUtils, fpjson, pythian.audio, pythian.hash,
  pythian.tools.annotations.catalog, pythian.tools.annotations.review;

const
  CRate = 8000;
  CSeconds = 7201;
  CFrames = CRate * CSeconds;
  CDataBytes = CFrames * 2;

procedure Need(const ACondition: Boolean; const AMessage: String);
begin
  if not ACondition then
    raise Exception.Create(AMessage);
end;

procedure WriteU16(const AStream: TStream; const AValue: Word);
var
  LBytes: array[0..1] of Byte;
begin
  LBytes[0] := Byte(AValue);
  LBytes[1] := Byte(AValue shr 8);
  AStream.WriteBuffer(LBytes, SizeOf(LBytes));
end;

procedure WriteU32(const AStream: TStream; const AValue: Cardinal);
var
  LBytes: array[0..3] of Byte;
begin
  LBytes[0] := Byte(AValue);
  LBytes[1] := Byte(AValue shr 8);
  LBytes[2] := Byte(AValue shr 16);
  LBytes[3] := Byte(AValue shr 24);
  AStream.WriteBuffer(LBytes, SizeOf(LBytes));
end;

procedure WriteLongWav(const APath: String);
var
  LOutput: TFileStream;
  LBuffer: array[0..65535] of Byte;
  LRemaining: Int64;
  LCount: Integer;
begin
  FillChar(LBuffer, SizeOf(LBuffer), 0);
  LOutput := TFileStream.Create(APath, fmCreate);
  try
    LOutput.WriteBuffer('RIFF', 4);
    WriteU32(LOutput, Cardinal(36 + CDataBytes));
    LOutput.WriteBuffer('WAVEfmt ', 8);
    WriteU32(LOutput, 16);
    WriteU16(LOutput, 1);
    WriteU16(LOutput, 1);
    WriteU32(LOutput, CRate);
    WriteU32(LOutput, CRate * 2);
    WriteU16(LOutput, 2);
    WriteU16(LOutput, 16);
    LOutput.WriteBuffer('data', 4);
    WriteU32(LOutput, Cardinal(CDataBytes));
    LRemaining := CDataBytes;
    while LRemaining > 0 do
    begin
      LCount := SizeOf(LBuffer);
      if LRemaining < LCount then
        LCount := Integer(LRemaining);
      LOutput.WriteBuffer(LBuffer[0], LCount);
      Dec(LRemaining, LCount);
    end;
  finally
    LOutput.Free;
  end;
end;

procedure WriteJson(const APath: String; const AObject: TJSONObject);
var
  LOutput: TFileStream;
  LText: String;
begin
  LText := AObject.AsJSON + LineEnding;
  LOutput := TFileStream.Create(APath, fmCreate);
  try
    LOutput.WriteBuffer(LText[1], Length(LText));
  finally
    LOutput.Free;
  end;
end;

function HashFile(const APath: String): String;
var
  LInput: TFileStream;
begin
  LInput := TFileStream.Create(APath, fmOpenRead or fmShareDenyWrite);
  try
    Result := Sha256Stream(LInput, LInput.Size);
  finally
    LInput.Free;
  end;
end;

procedure CommitPresence(const ACatalog, AHash, AId: String;
  const ARevision: Integer; const AStart: Int64);
var
  LTransaction: TJSONObject;
  LChange: TJSONObject;
  LEvent: TJSONObject;
begin
  LTransaction := TJSONObject.Create;
  try
    LTransaction.Add('version', 1);
    LTransaction.Add('source_sha256', AHash);
    LTransaction.Add('expected_revision', ARevision);
    LTransaction.Add('reviewer', 'long-review-fixture');
    LChange := TJSONObject.Create;
    LTransaction.Add('change', LChange);
    LChange.Add('label_id', AId);
    LChange.Add('type', 'presence');
    LChange.Add('value', 'rest');
    LChange.Add('status', 'approved');
    LChange.Add('start_frame', AStart);
    LChange.Add('end_frame', AStart + CRate);
    LChange.Add('part', '');
    LChange.Add('proposal_id', '');
    LEvent := CommitCatalogReview(ACatalog, LTransaction);
    try
      Need(LEvent.Integers['revision'] = ARevision + 1,
        'review revision did not advance');
    finally
      LEvent.Free;
    end;
  finally
    LTransaction.Free;
  end;
end;

var
  LRoot: String;
  LInbox: String;
  LCatalog: String;
  LSource: String;
  LCatalogSource: String;
  LHash: String;
  LManifest: TJSONObject;
  LTracks: TJSONArray;
  LTrack: TJSONObject;
  LReport: TJSONObject;
  LStart: QWord;
  LFirstMs: QWord;
  LSecondMs: QWord;
  LWritable: Boolean;
  LWriteStream: TFileStream;
  LTamperByte: Byte;
  LRejected: Boolean;
begin
  if (ParamCount = 2) and (ParamStr(1) = 'tamper-cold') then
  begin
    LRoot := ExpandFileName(ParamStr(2));
    LInbox := IncludeTrailingPathDelimiter(LRoot) + 'inbox';
    LCatalog := IncludeTrailingPathDelimiter(LRoot) + 'catalog';
    LSource := IncludeTrailingPathDelimiter(LInbox) + 'two-hour.wav';
    Need(FileExists(LSource) and
      FileExists(IncludeTrailingPathDelimiter(LInbox) + 'manifest.json'),
      'cold tamper requires an isolated generated long-review fixture');
    LHash := HashFile(LSource);
    LCatalogSource := IncludeTrailingPathDelimiter(LCatalog) +
      'sources' + PathDelim + LHash + '.wav';
    Need(FileExists(LCatalogSource), 'isolated catalog copy is absent');
    Need(FileExists(IncludeTrailingPathDelimiter(LCatalog) +
      'reviews' + PathDelim + LHash + PathDelim + '00000002.json'),
      'two successful reviews must precede cold tamper');
    LWriteStream := TFileStream.Create(LCatalogSource,
      fmOpenReadWrite or fmShareExclusive);
    try
      LWriteStream.Position := 44;
      LTamperByte := 1;
      LWriteStream.WriteBuffer(LTamperByte, 1);
    finally
      LWriteStream.Free;
    end;
    LRejected := False;
    try
      CommitPresence(LCatalog, LHash, 'tampered-third', 2, CRate * 2);
    except
      on EAudio do
        LRejected := True;
    end;
    Need(LRejected and not FileExists(
      IncludeTrailingPathDelimiter(LCatalog) + 'reviews' + PathDelim +
      LHash + PathDelim + '00000003.json'),
      'cold same-size source tamper produced a review event');
    WriteLn('PASS cold same-size tamper rejected with no third event');
    Halt(0);
  end;
  Need(ParamCount = 1, 'Usage: long-review-fixture BUILD_DIR');
  LRoot := ExpandFileName(ParamStr(1));
  LInbox := IncludeTrailingPathDelimiter(LRoot) + 'inbox';
  LCatalog := IncludeTrailingPathDelimiter(LRoot) + 'catalog';
  Need(ForceDirectories(LInbox), 'could not create inbox');
  LSource := IncludeTrailingPathDelimiter(LInbox) + 'two-hour.wav';
  WriteLongWav(LSource);
  LHash := HashFile(LSource);
  LManifest := TJSONObject.Create;
  try
    LManifest.Add('version', 1);
    LTracks := TJSONArray.Create;
    LManifest.Add('tracks', LTracks);
    LTrack := TJSONObject.Create;
    LTracks.Add(LTrack);
    LTrack.Add('file', 'two-hour.wav');
    LTrack.Add('sha256', LHash);
    LTrack.Add('source_group', 'long_review_control');
    LTrack.Add('clock_id', '');
    LTrack.Add('partition', 'development');
    LTrack.Add('title', 'Pascal two-hour silent control');
    LTrack.Add('provenance', 'Pascal-authored zero PCM16');
    LTrack.Add('license', 'MIT');
    WriteJson(IncludeTrailingPathDelimiter(LInbox) + 'manifest.json',
      LManifest);
  finally
    LManifest.Free;
  end;
  LReport := ImportLabelInbox(LInbox, LCatalog);
  try
    Need((LReport.Integers['imported'] = 1) and
      (LReport.Integers['failed'] = 0), 'two-hour import failed');
  finally
    LReport.Free;
  end;
  LCatalogSource := IncludeTrailingPathDelimiter(LCatalog) +
    'sources' + PathDelim + LHash + '.wav';
  LStart := GetTickCount64;
  CommitPresence(LCatalog, LHash, 'first-second', 0, 0);
  LFirstMs := GetTickCount64 - LStart;
  {$IFDEF MSWINDOWS}
  LWritable := True;
  try
    LWriteStream := TFileStream.Create(LCatalogSource,
      fmOpenWrite or fmShareDenyNone);
    LWriteStream.Free;
  except
    on EFOpenError do
      LWritable := False;
  end;
  Need(not LWritable, 'verified source allowed a concurrent writer');
  Need(not RenameFile(LCatalogSource, LCatalogSource + '.moved'),
    'verified source allowed path replacement');
  {$ENDIF}
  LStart := GetTickCount64;
  CommitPresence(LCatalog, LHash, 'second-second', 1, CRate);
  LSecondMs := GetTickCount64 - LStart;
  Need(LSecondMs < LFirstMs,
    'second review did not reuse the verified source handle');
  WriteLn('PASS long review source=', LHash, ' bytes=',
    44 + CDataBytes, ' duration_s=', CSeconds,
    ' first_ms=', LFirstMs, ' second_ms=', LSecondMs);
end.
