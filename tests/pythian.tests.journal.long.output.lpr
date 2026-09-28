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
program pythian_tests_journal_long_output;

{$mode delphi}
{$H+}

uses
  Classes, SysUtils, fpjson, jsonparser, pythian.audio, pythian.hash,
  pythian.wave.read, pythian.tools.journal.learning;

function DigestFile(const APath: String): String;
var
  LStream: TFileStream;
begin
  LStream := TFileStream.Create(APath, fmOpenRead or fmShareDenyWrite);
  try
    Result := Sha256Stream(LStream, LStream.Size);
  finally
    LStream.Free;
  end;
end;

function ReadJson(const APath: String): TJSONObject;
var
  LStream: TStringStream;
begin
  LStream := TStringStream.Create('');
  try
    LStream.LoadFromFile(APath);
    Result := TJSONObject(GetJSON(LStream.DataString));
  finally
    LStream.Free;
  end;
end;

procedure Check(const ACondition: Boolean; const AMessage: String);
begin
  if not ACondition then raise Exception.Create(AMessage);
end;

procedure VerifyPhysicalSourceUse;
const
  LHashes: array[0..2] of String = (
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
    'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb');
  LOneRecording: array[0..2] of Integer = (1200, 1000, 0);
  LTwoRecordings: array[0..2] of Integer = (1200, 1000, 1);
var
  LRejected: Boolean;
begin
  Check(DistinctUsedJournalSourceRecordings(LHashes, LOneRecording) = 1,
    'Two used ranges of one WAV counted as two recordings');
  LRejected := False;
  try
    RequireLongReplayAcceptanceSourceUse(LHashes, LOneRecording,
      Int64(180) * 16000, 16000);
  except
    on EAudio do LRejected := True;
  end;
  Check(LRejected, '180-second duplicate-range source gate did not reject');
  RequireLongReplayAcceptanceSourceUse(LHashes, LOneRecording,
    Int64(179) * 16000, 16000);
  Check(DistinctUsedJournalSourceRecordings(LHashes, LTwoRecordings) = 2,
    'Two distinct used WAV hashes not counted');
  RequireLongReplayAcceptanceSourceUse(LHashes, LTwoRecordings,
    Int64(180) * 16000, 16000);
end;

procedure Verify(const APrefix: String; const AReport: TJSONObject);
var
  LStream: TFileStream;
  LWave: TWaveFrameReader;
  LMap, LSources, LChunks: TJSONArray;
  LRow: TJSONObject;
  LIndex, LSourceIndex, LUsed, LCount: Integer;
  LFrame, LSourceFrames: Int64;
begin
  LStream := TFileStream.Create(APrefix + '.wav', fmOpenRead or fmShareDenyWrite);
  try
    LWave := TWaveFrameReader.Create(LStream);
    try
      Check(LWave.FrameCount = AReport.Get('audition_frames', Int64(-1)),
        'WAV frame count differs from report');
      Check(LWave.SampleRate = AReport.Get('sample_rate', -1), 'WAV rate differs');
      Check(LWave.Channels = AReport.Get('channels', -1), 'WAV channels differ');
    finally
      LWave.Free;
    end;
  finally
    LStream.Free;
  end;
  Check(DigestFile(APrefix + '.wav') = AReport.Get('audition_sha256', ''),
    'WAV hash differs from report');
  LMap := TJSONArray(AReport.Find('grain_map'));
  LSources := TJSONArray(AReport.Find('sources'));
  LChunks := TJSONArray(AReport.Find('chunk_schedule'));
  LCount := AReport.Get('grains', -1);
  Check((LCount = LMap.Count) and (LCount = 4000), 'Grain map count differs');
  Check(AReport.Get('join_count', -1) = LCount - 1, 'Total join count differs');
  Check(AReport.Get('cross_chunk_joins', -1) = LChunks.Count - 1,
    'Cross-chunk join count differs');
  Check(AReport.Get('within_chunk_joins', -1) =
    LCount - LChunks.Count, 'Within-chunk join count differs');
  LUsed := 0;
  for LIndex := 0 to LSources.Count - 1 do
    if TJSONObject(LSources.Items[LIndex]).Get('generated_grains', 0) > 0 then
      Inc(LUsed);
  Check((LUsed >= 2) and (LUsed =
    AReport.Get('source_recordings_used', -1)), 'Source use differs');
  for LIndex := 0 to LMap.Count - 1 do
  begin
    LRow := TJSONObject(LMap.Items[LIndex]);
    Check(LRow.Get('grain', -1) = LIndex, 'Grain order differs');
    LSourceIndex := LRow.Get('source_index', -1);
    Check((LSourceIndex >= 0) and (LSourceIndex < LSources.Count),
      'Grain source outside profile');
    LFrame := LRow.Get('source_frame', Int64(-1));
    LSourceFrames := TJSONObject(LSources.Items[LSourceIndex]).Get(
      'source_frames', Int64(-1));
    Check((LFrame >= 0) and (LFrame < LSourceFrames),
      'Grain frame outside source');
  end;
end;

var
  LFirst, LSecond, LThird: TJSONObject;
begin
  VerifyPhysicalSourceUse;
  if ParamCount <> 3 then
    raise Exception.Create('Usage: long-output PREFIX_WIN64 PREFIX_WIN32 PREFIX_BLOCK_VARIANT');
  LFirst := ReadJson(ParamStr(1) + '.json');
  LSecond := ReadJson(ParamStr(2) + '.json');
  LThird := ReadJson(ParamStr(3) + '.json');
  try
    Verify(ParamStr(1), LFirst);
    Verify(ParamStr(2), LSecond);
    Verify(ParamStr(3), LThird);
    Check(DigestFile(ParamStr(1) + '.wav') = DigestFile(ParamStr(2) + '.wav'),
      'Win32/Win64 WAV replay differs');
    Check(DigestFile(ParamStr(1) + '.wav') = DigestFile(ParamStr(3) + '.wav'),
      'PCM block-size WAV replay differs');
    Check(DigestFile(ParamStr(1) + '.wfcs') = DigestFile(ParamStr(2) + '.wfcs'),
      'Win32/Win64 model differs');
    Check(DigestFile(ParamStr(1) + '.wfcs') = DigestFile(ParamStr(3) + '.wfcs'),
      'PCM block-size model differs');
    Check(LFirst.AsJSON = LSecond.AsJSON, 'Win32/Win64 report differs');
    LFirst.Delete('block_frames');
    LThird.Delete('block_frames');
    Check(LFirst.AsJSON = LThird.AsJSON, 'Block-size report differs beyond block_frames');
    WriteLn('Checked long replay WAV/frame/map/source/join identity on both targets and block sizes');
  finally
    LThird.Free;
    LSecond.Free;
    LFirst.Free;
  end;
end.
