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
program pythian_tests_wfc_reviewed_catalog;

{$mode delphi}
{$H+}

uses
  Classes,
  SysUtils,
  Math,
  fpjson,
  pythian.audio,
  pythian.hash,
  pythian.pitch.track,
  pythian.wave.stream,
  pythian.wfc.admitted.pitch,
  pythian.wfc.admitted.pitch.journal,
  pythian.wfc.reviewed.catalog,
  pythian.tools.annotations.catalog,
  pythian.tools.annotations.export,
  pythian.tools.annotations.review;

const
  CRate = 8000;
  CFrames = 8000;

procedure Check(const ACondition: Boolean; const AMessage: String);
begin
  if not ACondition then
  begin
    raise Exception.Create(AMessage);
  end;
end;

procedure WriteText(const APath, AText: String);
var
  LFile: TFileStream;
begin
  LFile := TFileStream.Create(APath, fmCreate);
  try
    LFile.WriteBuffer(AText[1], Length(AText));
  finally
    LFile.Free;
  end;
end;

function WriteWave(const APath: String; const AAmplitude: Single): String;
var
  LFile: TFileStream;
  LSink: TStreamAudioSink;
  LWriter: TWavePcm16Writer;
  LSamples: TAudioSamples;
  LIndex: Integer;
begin
  SetLength(LSamples, CFrames);
  for LIndex := 0 to High(LSamples) do
  begin
    LSamples[LIndex] := AAmplitude * Sin(2 * Pi * 220 * LIndex / CRate);
  end;
  LFile := TFileStream.Create(APath, fmCreate);
  LSink := TStreamAudioSink.Create(LFile);
  LWriter := TWavePcm16Writer.Create(LSink, CRate, 1, CFrames);
  try
    LWriter.AppendSamples(LSamples);
    LWriter.Finish;
    LFile.Position := 0;
    Result := Sha256Stream(LFile, LFile.Size);
  finally
    LWriter.Free;
    LSink.Free;
    LFile.Free;
  end;
end;

procedure AddManifestTrack(const ATracks: TJSONArray; const AFile, AHash,
  AGroup, APartition: String);
var
  LTrack: TJSONObject;
begin
  LTrack := TJSONObject.Create;
  LTrack.Add('file', AFile);
  LTrack.Add('sha256', AHash);
  LTrack.Add('title', AGroup);
  LTrack.Add('source_group', AGroup);
  LTrack.Add('partition', APartition);
  LTrack.Add('provenance', 'Artificial adapter check');
  LTrack.Add('license', 'Local fixture');
  ATracks.Add(LTrack);
end;

procedure Review(const ACatalogRoot, AHash, AId, AType, AValue: String;
  const AStart, AEnd, ARevision, APitch: Integer);
var
  LTransaction: TJSONObject;
  LChange: TJSONObject;
  LReport: TJSONObject;
begin
  LTransaction := TJSONObject.Create;
  LTransaction.Add('version', 1);
  LTransaction.Add('source_sha256', AHash);
  LTransaction.Add('expected_revision', ARevision);
  LTransaction.Add('reviewer', 'operator-test');
  LChange := TJSONObject.Create;
  LChange.Add('label_id', AId);
  LChange.Add('type', AType);
  LChange.Add('value', AValue);
  LChange.Add('status', 'approved');
  LChange.Add('start_frame', AStart);
  LChange.Add('end_frame', AEnd);
  LChange.Add('part', 'lead');
  LChange.Add('proposal_id', '');
  if AType = 'note' then
  begin
    LChange.Add('pitch_midi', APitch);
  end;
  LTransaction.Add('change', LChange);
  try
    LReport := CommitCatalogReview(ACatalogRoot, LTransaction);
    LReport.Free;
  finally
    LTransaction.Free;
  end;
end;

procedure Run(const ARoot: String);
var
  LInbox: String;
  LCatalog: String;
  LPacketPath: String;
  LHashA: String;
  LHashB: String;
  LHashEval: String;
  LManifest: TJSONObject;
  LTracks: TJSONArray;
  LReport: TJSONObject;
  LSourceA: TAdmittedNoteSource;
  LSourceB: TAdmittedNoteSource;
  LJournal: TAdmittedPitchJournal;
  LReloaded: TAdmittedPitchJournal;
  LModel: TAdmittedPitchDurationModel;
  LRejected: Boolean;
begin
  LInbox := IncludeTrailingPathDelimiter(ARoot) + 'inbox';
  LCatalog := IncludeTrailingPathDelimiter(ARoot) + 'catalog';
  Check(ForceDirectories(LInbox), 'Could not create test inbox');
  Check(ForceDirectories(LCatalog), 'Could not create test catalog');
  LHashA := WriteWave(IncludeTrailingPathDelimiter(LInbox) + 'a.wav', 0.1);
  LHashB := WriteWave(IncludeTrailingPathDelimiter(LInbox) + 'b.wav', 0.2);
  LHashEval := WriteWave(IncludeTrailingPathDelimiter(LInbox) + 'eval.wav', 0.3);
  LManifest := TJSONObject.Create;
  LTracks := TJSONArray.Create;
  LManifest.Add('version', 1);
  LManifest.Add('tracks', LTracks);
  AddManifestTrack(LTracks, 'a.wav', LHashA, 'session-a', 'training');
  AddManifestTrack(LTracks, 'b.wav', LHashB, 'session-b', 'training');
  AddManifestTrack(LTracks, 'eval.wav', LHashEval, 'session-eval', 'evaluation');
  try
    WriteText(IncludeTrailingPathDelimiter(LInbox) + 'manifest.json',
      LManifest.AsJSON);
  finally
    LManifest.Free;
  end;
  LReport := ImportLabelInbox(LInbox, LCatalog);
  try
    Check(LReport.Integers['imported'] = 3, 'Three sources must import');
  finally
    LReport.Free;
  end;
  Review(LCatalog, LHashA, 'pitch-later', 'note', 'C4', 4000, 6000, 0, 60);
  Review(LCatalog, LHashA, 'unknown', 'presence', 'unknown', 3000, 4000, 1, -1);
  Review(LCatalog, LHashA, 'rest', 'presence', 'rest', 2000, 3000, 2, -1);
  Review(LCatalog, LHashA, 'pitch-first', 'note', 'E4', 0, 2000, 3, 64);
  Review(LCatalog, LHashB, 'pitch-b', 'note', 'G4', 0, 2000, 0, 67);
  Review(LCatalog, LHashEval, 'held-out', 'note', 'A4', 0, 2000, 0, 69);
  LPacketPath := IncludeTrailingPathDelimiter(ARoot) + 'reviewed.json';
  LReport := ExportReviewedCatalog(LCatalog, LPacketPath);
  LReport.Free;
  LSourceA := ReadReviewedNoteSource(LPacketPath,
    IncludeTrailingPathDelimiter(LInbox) + 'a.wav', 'lead');
  Check(Length(LSourceA.Spans) = 4, 'Selected rest and unknown retained');
  Check((LSourceA.Spans[0].Kind = pskPitch) and
    (LSourceA.Spans[0].Note = 64) and
    (LSourceA.Spans[1].Kind = pskSilence) and
    (LSourceA.Spans[2].Kind = pskUnknown) and
    (LSourceA.Spans[3].Note = 60),
    'Reviewed spans must sort by source frame and preserve kind');
  LSourceB := ReadReviewedNoteSource(LPacketPath,
    IncludeTrailingPathDelimiter(LInbox) + 'b.wav', 'lead');
  LRejected := False;
  try
    ReadReviewedNoteSource(LPacketPath,
      IncludeTrailingPathDelimiter(LInbox) + 'eval.wav', 'lead');
  except
    on E: EAudio do
    begin
      LRejected := Pos('training partition', E.Message) > 0;
    end;
  end;
  Check(LRejected, 'Held-out source must not enter training');
  WriteWave(IncludeTrailingPathDelimiter(LInbox) + 'unlisted.wav', 0.4);
  LRejected := False;
  try
    ReadReviewedNoteSource(LPacketPath,
      IncludeTrailingPathDelimiter(LInbox) + 'unlisted.wav', 'lead');
  except
    on E: EAudio do
    begin
      LRejected := Pos('absent from catalog packet', E.Message) > 0;
    end;
  end;
  Check(LRejected, 'Unlisted WAV must not enter reviewed training');
  LJournal := TAdmittedPitchJournal.Create(1);
  LReloaded := TAdmittedPitchJournal.Create(1);
  try
    LJournal.AppendSource(LSourceA, LJournal.PolicyIdentity);
    LJournal.AppendSource(LSourceB, LJournal.PolicyIdentity);
    Check((LJournal.SourceCount = 2) and (LJournal.SpanCount = 5),
      'Reviewed spans must enter journal');
    LReloaded.ReplaceFromText(LJournal.EncodeText);
    Check(LReloaded.JournalSha256 = LJournal.JournalSha256,
      'Reviewed journal replay must be exact');
    LModel := LReloaded.Rebuild;
    try
      Check((LModel.SourceCount = 2) and (LModel.GroupCount = 2),
        'Two reviewed groups must reach Pascal learner');
    finally
      LModel.Free;
    end;
  finally
    LReloaded.Free;
    LJournal.Free;
  end;
  WriteLn('reviewed catalog to Pascal WFC learner: passed');
end;

var
  LGuid: TGUID;
begin
  if ParamCount <> 1 then
  begin
    raise Exception.Create('Expected ignored build fixture root');
  end;
  Check(CreateGUID(LGuid) = 0, 'Could not create fixture identity');
  Run(IncludeTrailingPathDelimiter(ParamStr(1)) + GUIDToString(LGuid));
end.
