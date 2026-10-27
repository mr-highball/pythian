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
program pythian_tests_annotations_import_progress;
{$mode delphi}{$H+}

uses
  Classes,
  SysUtils,
  fpjson,
  pythian.audio,
  pythian.hash,
  pythian.progress,
  pythian.wave.stream,
  pythian.tools.annotations.catalog;

type
  TObserver = class
    Stage: String;
    TriggerStart: Integer;
    Starts: Integer;
    TriggerDone: Int64;
    Marker: Exception;
    SeenBytes: Boolean;
    UsePlainException: Boolean;
    procedure Progress(const AWork: TWorkProgress);
  end;

var
  GChecks: Integer;

procedure Check(const ACondition: Boolean; const AMessage: String);
begin
  Inc(GChecks);
  if not ACondition then
  begin
    raise Exception.Create(AMessage);
  end;
end;

procedure TObserver.Progress(const AWork: TWorkProgress);
begin
  Check((AWork.Done >= 0) and (AWork.Done <= AWork.Total), 'truthful progress bounds');
  if (AWork.Stage = Stage) and (AWork.Done = 0) then
  begin
    Inc(Starts);
  end;
  if (AWork.Units = wuBytes) and (AWork.Done > 65536) then
  begin
    SeenBytes := True;
  end;
  if (AWork.Stage = Stage) and (Starts >= TriggerStart) and
    (AWork.Done >= TriggerDone) then
  begin
    if UsePlainException then
    begin
      Marker := Exception.Create('intentional callback cancellation');
    end
    else
    begin
      Marker := EAudio.Create('intentional callback cancellation');
    end;
    raise Marker;
  end;
end;

function HashFile(const APath: String): String;
var
  LStream: TFileStream;
begin
  LStream := TFileStream.Create(APath, fmOpenRead);
  try
    Result := Sha256Stream(LStream, LStream.Size);
  finally
    LStream.Free;
  end;
end;

procedure Prepare(const ARoot: String; out AInbox, AHash: String);
var
  LSamples: TAudioSamples;
  LClip: TAudioClip;
  LStream: TFileStream;
  LManifest: TJSONObject;
  LRows: TJSONArray;
  LRow: TJSONObject;
  LIndex: Integer;
  LText: String;
begin
  AInbox := ARoot + PathDelim + 'inbox';
  Check(ForceDirectories(AInbox), 'create inbox');
  SetLength(LSamples, 80000);
  for LIndex := 0 to High(LSamples) do
  begin
    if LIndex mod 4 = 0 then
    begin
      LSamples[LIndex] := 0.5;
    end;
  end;
  LClip := TAudioClip.Create(8000, 1, LSamples);
  try
    LStream := TFileStream.Create(AInbox + PathDelim + 'source.wav', fmCreate);
    try
      WriteWavePcm16(LStream, LClip);
    finally
      LStream.Free;
    end;
  finally
    LClip.Free;
  end;
  AHash := HashFile(AInbox + PathDelim + 'source.wav');
  LManifest := TJSONObject.Create;
  try
    LManifest.Add('version', 1);
    LRows := TJSONArray.Create;
    LManifest.Add('tracks', LRows);
    LRow := TJSONObject.Create;
    LRows.Add(LRow);
    LRow.Add('file', 'source.wav');
    LRow.Add('sha256', AHash);
    LRow.Add('source_group', 'progress');
    LRow.Add('clock_id', '');
    LRow.Add('partition', 'unassigned');
    LRow.Add('title', 'Authored progress fixture');
    LRow.Add('provenance', 'First-party test');
    LRow.Add('license', 'MIT');
    LRows.Add(LRow.Clone);
    LRows.Add(TJSONObject.Create);
    LText := LManifest.AsJSON;
    LStream := TFileStream.Create(AInbox + PathDelim + 'manifest.json', fmCreate);
    try
      LStream.WriteBuffer(LText[1], Length(LText));
    finally
      LStream.Free;
    end;
  finally
    LManifest.Free;
  end;
end;

procedure CheckNoPartials(const ADirectory: String);
var
  LSearch: TSearchRec;
begin
  if FindFirst(ADirectory + PathDelim + '*.partial', faAnyFile, LSearch) = 0 then
  begin
    FindClose(LSearch);
    raise Exception.Create('partial file remained');
  end;
  Inc(GChecks);
end;

procedure RunAbort(const AInbox, ARoot, AHash, AStage: String;
  const AStart: Integer; const ADone: Int64; const APlainException: Boolean = False;
  const APrepopulate: Boolean = False);
var
  LObserver: TObserver;
  LReport: TJSONObject;
  LCaught: Boolean;
  LSource: String;
  LRecord: String;
  LRecordHash: String;
begin
  LSource := ARoot + PathDelim + 'sources' + PathDelim + AHash + '.wav';
  LRecord := ARoot + PathDelim + 'tracks' + PathDelim + AHash + '.json';
  LRecordHash := '';
  if APrepopulate then
  begin
    LReport := ImportLabelInbox(AInbox, ARoot);
    LReport.Free;
    LRecordHash := HashFile(LRecord);
  end;
  LObserver := TObserver.Create;
  try
    LObserver.Stage := AStage;
    LObserver.TriggerStart := AStart;
    LObserver.TriggerDone := ADone;
    LObserver.UsePlainException := APlainException;
    LCaught := False;
    try
      LReport := ImportLabelInbox(AInbox, ARoot, LObserver.Progress);
      LReport.Free;
    except
      on LException: Exception do
      begin
        LCaught := LException = LObserver.Marker;
      end;
    end;
    Check(LCaught, 'original callback exception object propagated');
    CheckNoPartials(ARoot + PathDelim + 'sources');
    CheckNoPartials(ARoot + PathDelim + 'tracks');
    if FileExists(LRecord) then
    begin
      Check(FileExists(LSource) and (HashFile(LSource) = AHash), 'prior durable record and bytes');
      if APrepopulate then
      begin
        Check(HashFile(LRecord) = LRecordHash, 'prior record bytes unchanged');
      end;
    end;
    LReport := ImportLabelInbox(AInbox, ARoot);
    try
      Check((LReport.Integers['imported'] + LReport.Integers['duplicate'] = 2) and
        (LReport.Integers['failed'] = 1), 'retry succeeds; malformed remains ordinary failure');
    finally
      LReport.Free;
    end;
    Check(FileExists(LSource) and FileExists(LRecord) and (HashFile(LSource) = AHash),
      'retry publishes verified source and record');
    CheckNoPartials(ARoot + PathDelim + 'sources');
    CheckNoPartials(ARoot + PathDelim + 'tracks');
  finally
    LObserver.Free;
  end;
end;

procedure CheckSuccessfulParity(const AInbox, ARoot: String);
var
  LObserver: TObserver;
  LPlain: TJSONObject;
  LObserved: TJSONObject;
begin
  LObserver := TObserver.Create;
  try
    LPlain := ImportLabelInbox(AInbox, ARoot + '-plain');
    try
      LObserved := ImportLabelInbox(AInbox, ARoot + '-observed', LObserver.Progress);
      try
        Check(LPlain.AsJSON = LObserved.AsJSON, 'callback does not alter report');
        Check(LObserver.SeenBytes, 'multi-buffer progress emitted');
      finally
        LObserved.Free;
      end;
    finally
      LPlain.Free;
    end;
  finally
    LObserver.Free;
  end;
end;

var
  LRoot: String;
  LInbox: String;
  LHash: String;
begin
  Check(ParamCount = 1, 'fixture requires fresh output root');
  LRoot := ExpandFileName(ParamStr(1));
  Check(not DirectoryExists(LRoot) and ForceDirectories(LRoot), 'fresh output root');
  Prepare(LRoot, LInbox, LHash);
  CheckSuccessfulParity(LInbox, LRoot + PathDelim + 'parity');
  RunAbort(LInbox, LRoot + PathDelim + 'hash', LHash, 'import_hash_bytes', 1, 65536);
  RunAbort(LInbox, LRoot + PathDelim + 'copy', LHash, 'import_copy_bytes', 1, 65536, True);
  RunAbort(LInbox, LRoot + PathDelim + 'verify-source', LHash, 'import_verify_bytes', 1, 65536);
  RunAbort(LInbox, LRoot + PathDelim + 'verify-stage', LHash, 'import_verify_bytes', 2, 65536);
  RunAbort(LInbox, LRoot + PathDelim + 'item-first', LHash, 'import_items', 1, 0);
  RunAbort(LInbox, LRoot + PathDelim + 'item-duplicate', LHash, 'import_items', 0, 1);
  RunAbort(LInbox, LRoot + PathDelim + 'duplicate-verify', LHash,
    'import_verify_bytes', 1, 65536, True, True);
  WriteLn('PASS ', GChecks, ' import progress checks');
end.
