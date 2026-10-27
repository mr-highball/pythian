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
program pythian_tests_reference_progress;
{$mode delphi}
{$H+}
uses
  Classes, SysUtils, fpjson, jsonparser, pythian.audio, pythian.progress,
  pythian.hash, pythian.wave, pythian.tools.annotations.catalog,
  pythian.tools.annotations.review, pythian.tools.annotations.export,
  pythian.tools.annotations.reference;
type
  EProbe = class(Exception);
  TProbe = class
    AbortStage: String;
    RaisedObject: Exception;
    Centers: Int64;
    HashStarts: Integer;
    procedure Observe(const AWork: TWorkProgress);
  end;
var
  LChecks: Integer;
procedure Check(const AValue: Boolean; const AMessage: String);
begin
  Inc(LChecks);
  if not AValue then
    raise Exception.Create(AMessage);
end;
procedure TProbe.Observe(const AWork: TWorkProgress);
begin
  if AWork.Stage = 'reference_centers' then
  begin
    Check((AWork.Units = wuItems) and (AWork.Total = 800) and
    (AWork.Done >= Centers) and (AWork.Done <= AWork.Total) and
    (AWork.Done - Centers <= 256), 'center count/cadence');
    Centers := AWork.Done;
  end
  else if AWork.Stage = 'verify_audio_bytes' then
  begin
    Check((AWork.Units = wuBytes) and (AWork.Done <= AWork.Total), 'hash count');
    if AWork.Done = 0 then
      Inc(HashStarts);
  end
  else
    raise Exception.Create('Unexpected reference progress');
  if (AWork.Stage = AbortStage) and (AWork.Done > 0) and (AWork.Done < AWork.Total) then
  begin
    RaisedObject := EProbe.Create('reference callback');
    raise RaisedObject;
  end;
end;
procedure WriteText(const APath: String; const AText: UTF8String);
var
  LFile: TFileStream;
begin
  LFile := TFileStream.Create(APath, fmCreate);
  try
    if Length(AText) > 0 then
      LFile.WriteBuffer(AText[1], Length(AText));
  finally
    LFile.Free;
  end;
end;
function HashFile(const APath: String): String;
var
  LFile: TFileStream;
begin
  LFile := TFileStream.Create(APath, fmOpenRead or fmShareDenyWrite);
  try
    Result := Sha256Stream(LFile, LFile.Size);
  finally
    LFile.Free;
  end;
end;
var
  LRoot: String;
  LInbox: String;
  LCatalog: String;
  LSource: String;
  LPacket: String;
  LPlan: String;
  LSourceHash: String;
  LPacketHash: String;
  LSamples: TAudioSamples;
  LClip: TAudioClip;
  LManifest: TJSONObject;
  LTrack: TJSONObject;
  LTransaction: TJSONObject;
  LChange: TJSONObject;
  LResult: TJSONObject;
  LPlanData: TJSONObject;
  LTracks: TJSONArray;
  LReference: UTF8String;
  LObserved: UTF8String;
  LProbe: TProbe;
  LIndex: Integer;
  LRejected: Boolean;
begin
  Check(ParamCount = 1, 'fresh E output root required');
  LRoot := IncludeTrailingPathDelimiter(ExpandFileName(ParamStr(1)));
  LInbox := LRoot + 'inbox';
  LCatalog := LRoot + 'catalog';
  Check(ForceDirectories(LInbox), 'inbox');
  LSource := LInbox + PathDelim + 'authored.wav';
  LPacket := LRoot + 'packet.json';
  LPlan := LRoot + 'plan.json';
  SetLength(LSamples, 80000);
  for LIndex := 0 to High(LSamples) do
    LSamples[LIndex] := (LIndex mod 20 - 10) / 32;
  LClip := TAudioClip.Create(8000, 1, LSamples);
  try
    SaveWavePcm16(LSource, LClip);
  finally
    LClip.Free;
  end;
  LSourceHash := HashFile(LSource);
  LManifest := TJSONObject.Create;
  try
    LManifest.Add('version', 1);
    LTracks := TJSONArray.Create;
    LManifest.Add('tracks', LTracks);
    LTrack := TJSONObject.Create;
    LTracks.Add(LTrack);
    LTrack.Add('file', 'authored.wav');
    LTrack.Add('sha256', LSourceHash);
    LTrack.Add('source_group', 'authored-control');
    LTrack.Add('clock_id', '');
    LTrack.Add('partition', 'development');
    LTrack.Add('title', 'Authored test');
    LTrack.Add('provenance', 'Pascal-authored test samples');
    LTrack.Add('license', 'MIT');
    WriteText(LInbox + PathDelim + 'manifest.json', LManifest.AsJSON);
  finally
    LManifest.Free;
  end;
  LResult := ImportLabelInbox(LInbox, LCatalog);
  try
    Check((LResult.Integers['imported'] = 1) and (LResult.Integers['failed'] = 0), 'import');
  finally
    LResult.Free;
  end;
  LTransaction := TJSONObject.Create;
  try
    LTransaction.Add('version', 1);
    LTransaction.Add('source_sha256', LSourceHash);
    LTransaction.Add('expected_revision', 0);
    LTransaction.Add('reviewer', 'authored-test');
    LChange := TJSONObject.Create;
    LTransaction.Add('change', LChange);
    LChange.Add('label_id', 'control-presence');
    LChange.Add('type', 'presence');
    LChange.Add('value', 'audible');
    LChange.Add('status', 'approved');
    LChange.Add('start_frame', 0);
    LChange.Add('end_frame', 40000);
    LChange.Add('part', '');
    LChange.Add('proposal_id', '');
    LResult := CommitCatalogReview(LCatalog, LTransaction);
    try
      Check(LResult.Integers['revision'] = 1, 'authored review');
    finally
      LResult.Free;
    end;
  finally
    LTransaction.Free;
  end;
  LResult := ExportReviewedCatalog(LCatalog, LPacket);
  LResult.Free;
  LPacketHash := HashFile(LPacket);
  LPlanData := TJSONObject.Create;
  try
    LPlanData.Add('format', 'pythian-reviewed-presence-reference-plan');
    LPlanData.Add('version', 1);
    LPlanData.Add('packet_sha256', LPacketHash);
    LPlanData.Add('source_sha256', LSourceHash);
    LPlanData.Add('preparation_sha256', StringOfChar('1', 64));
    LPlanData.Add('scoring_policy_sha256', StringOfChar('2', 64));
    LPlanData.Add('annotation_policy_sha256', StringOfChar('3', 64));
    LPlanData.Add('source_group', 'authored-control');
    LPlanData.Add('part', '');
    LPlanData.Add('partition', 'development');
    LPlanData.Add('first_frame', 0);
    LPlanData.Add('end_frame', 80000);
    LPlanData.Add('first_center', 0);
    LPlanData.Add('hop_frames', 100);
    WriteText(LPlan, LPlanData.AsJSON);
  finally
    LPlanData.Free;
  end;
  LReference := BuildReviewedPresenceReference(LPlan, LPacket, LSource);
  LProbe := TProbe.Create;
  try
    LObserved := BuildReviewedPresenceReference(LPlan, LPacket, LSource, LProbe.Observe);
    Check((LReference = LObserved) and (LProbe.Centers = 800) and (LProbe.HashStarts = 4), 'parity and phases');
  finally
    LProbe.Free;
  end;
  for LIndex := 0 to 1 do
  begin
    LProbe := TProbe.Create;
    try
      if LIndex = 0 then
        LProbe.AbortStage := 'reference_centers'
      else
        LProbe.AbortStage := 'verify_audio_bytes';
      LRejected := False;
      try
        LObserved := BuildReviewedPresenceReference(LPlan, LPacket, LSource, LProbe.Observe);
      except
        on LException: EProbe do
          LRejected := LException = LProbe.RaisedObject;
      end;
      Check(LRejected, 'interior abort and original exception');
    finally
      LProbe.Free;
    end;
    Check(BuildReviewedPresenceReference(LPlan, LPacket, LSource) = LReference, 'retry parity');
    Check((HashFile(LSource) = LSourceHash) and (HashFile(LPacket) = LPacketHash), 'inputs unchanged');
  end;
  WriteLn('PASS ', LChecks, ' reviewed reference progress checks; authored test labels only');
end.
