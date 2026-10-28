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
program pythian_inference_corpus_audit;

{$mode delphi}
{$H+}

uses
  Classes,
  SysUtils,
  fpjson, pythian.tools.json,
  jsonparser,
  pythian.text,
  pythian.progress,
  pythian.tools.progress,
  pythian.wave.read,
  pythian.inference.observation,
  pythian.inference.corpus;

type
  TCorpusSourceBinding = record
    SourceId: String;
    FileName: String;
    Sha256: String;
    SourceRate: Integer;
    SourceChannels: Integer;
    SourceFrames: Int64;
  end;
  TCorpusSourceBindings = array of TCorpusSourceBinding;

function RequireField(const AObject: TJSONObject; const AName: String;
  const AKind: TJSONType): TJSONData;
begin
  Result := AObject.Find(AName);
  if (Result = nil) or (Result.JSONType <> AKind) then
  begin
    raise Exception.Create('Invalid corpus manifest field: ' + AName);
  end;
end;

function RequiredString(const AObject: TJSONObject; const AName: String): String;
begin
  Result := RequireField(AObject, AName, jtString).AsString;
  if Result = '' then
  begin
    raise Exception.Create('Empty corpus manifest field: ' + AName);
  end;
end;

function RequiredInt64(const AObject: TJSONObject; const AName: String): Int64;
var
  LValue: TJSONData;
begin
  LValue := RequireField(AObject, AName, jtNumber);
  if not TryStrToInt64(LValue.AsJSON, Result) then
  begin
    raise Exception.Create('Corpus integer field is not exact: ' + AName);
  end;
end;

function RequiredInteger(const AObject: TJSONObject; const AName: String): Integer;
var
  LValue: Int64;
begin
  LValue := RequiredInt64(AObject, AName);
  if (LValue < Low(Integer)) or (LValue > High(Integer)) then
  begin
    raise Exception.Create('Corpus integer field is out of range: ' + AName);
  end;
  Result := LValue;
end;

procedure ValidateSource(const AEntry: TJSONObject;
  var ABindings: TCorpusSourceBindings; out ARate, AChannels: Integer;
  out AFrames: Int64; const AProgress: TWorkProgressCallback);
var
  LSource: String;
  LFileName: String;
  LHash: String;
  LIndex: Integer;
  LStream: TFileStream;
  LWave: TWaveFrameReader;
begin
  LSource := RequiredString(AEntry, 'source_id');
  LFileName := RequiredString(AEntry, 'source_wav');
  LHash := RequiredString(AEntry, 'source_sha256');
  for LIndex := 0 to High(ABindings) do
  begin
    if ABindings[LIndex].SourceId = LSource then
    begin
      if (ABindings[LIndex].FileName <> LFileName) or
        (ABindings[LIndex].Sha256 <> LHash) then
      begin
        raise Exception.Create('One source ID has conflicting WAV identity');
      end;
      ARate := ABindings[LIndex].SourceRate;
      AChannels := ABindings[LIndex].SourceChannels;
      AFrames := ABindings[LIndex].SourceFrames;
      Exit;
    end;
  end;
  if not FileExists(LFileName) then
  begin
    raise Exception.Create('Corpus source WAV is missing: ' + LFileName);
  end;
  if HashInferenceFile(LFileName, AProgress) <> LHash then
  begin
    raise Exception.Create('Corpus source WAV SHA-256 differs: ' + LSource);
  end;
  LStream := TFileStream.Create(LFileName, fmOpenRead or fmShareDenyWrite);
  try
    LWave := TWaveFrameReader.Create(LStream);
    try
      ARate := LWave.SampleRate;
      AChannels := LWave.Channels;
      AFrames := LWave.FrameCount;
    finally
      LWave.Free;
    end;
  finally
    LStream.Free;
  end;
  SetLength(ABindings, Length(ABindings) + 1);
  ABindings[High(ABindings)].SourceId := LSource;
  ABindings[High(ABindings)].FileName := LFileName;
  ABindings[High(ABindings)].Sha256 := LHash;
  ABindings[High(ABindings)].SourceRate := ARate;
  ABindings[High(ABindings)].SourceChannels := AChannels;
  ABindings[High(ABindings)].SourceFrames := AFrames;
end;

function ParseEntry(const AData: TJSONData; const AEstimator: String;
  const APolicy: String; var ABindings: TCorpusSourceBindings;
  const AProgress: TWorkProgressCallback):
  TInferenceCorpusEntry;
var
  LObject: TJSONObject;
  LRate, LChannels: Integer;
  LFrames: Int64;
begin
  if AData.JSONType <> jtObject then
  begin
    raise Exception.Create('Corpus manifest entry is not an object');
  end;
  LObject := TJSONObject(AData);
  ValidateSource(LObject, ABindings, LRate, LChannels, LFrames, AProgress);
  Result := Default(TInferenceCorpusEntry);
  Result.GroupId := RequiredString(LObject, 'group_id');
  Result.SourceId := RequiredString(LObject, 'source_id');
  Result.ArtifactFile := RequiredString(LObject, 'artifact');
  Result.Identity.Estimator := AEstimator;
  Result.Identity.Request.SourceHash :=
    RequiredString(LObject, 'source_sha256');
  Result.Identity.Request.Policy := APolicy;
  Result.Identity.Request.Channel :=
    RequiredInteger(LObject, 'channel');
  Result.Identity.Request.ScopeStart16k :=
    RequiredInt64(LObject, 'scope_start16k');
  Result.Identity.Request.ScopeEnd16k :=
    RequiredInt64(LObject, 'scope_end16k');
  Result.Identity.Request.InputStart16k :=
    RequiredInt64(LObject, 'input_start16k');
  Result.Identity.Request.InputEnd16k :=
    RequiredInt64(LObject, 'input_end16k');
  Result.Identity.Request.FirstCenter16k :=
    RequiredInt64(LObject, 'first_center16k');
  Result.Identity.Request.Hop16k :=
    RequiredInteger(LObject, 'hop16k');
  Result.Identity.Request.BatchSize :=
    RequiredInteger(LObject, 'batch_size');
  Result.Identity.SourceRate := RequiredInteger(LObject, 'source_rate');
  Result.Identity.SourceChannels :=
    RequiredInteger(LObject, 'source_channels');
  Result.Identity.SourceFrames :=
    RequiredInt64(LObject, 'source_frames');
  if (Result.Identity.SourceRate <> LRate) or
    (Result.Identity.SourceChannels <> LChannels) or
    (Result.Identity.SourceFrames <> LFrames) then
  begin
    raise Exception.Create('Corpus manifest WAV geometry differs from source');
  end;
  ValidateInferenceRequest(Result.Identity.Request);
  Result.Identity.ObservationCount :=
    InferenceCount(Result.Identity.Request);
  if (Result.Identity.SourceRate < 1) or
    (Result.Identity.SourceChannels < 1) or
    (Result.Identity.SourceFrames < 1) then
  begin
    raise Exception.Create('Invalid corpus source geometry');
  end;
end;

function LoadEntries(const AFileName: String;
  var ABindings: TCorpusSourceBindings;
  const AProgress: TWorkProgressCallback): TInferenceCorpusEntries;
var
  LFile: TStringList;
  LRoot: TJSONData;
  LObject: TJSONObject;
  LItems: TJSONArray;
  LEstimator: String;
  LPolicy: String;
  LIndex: Integer;
  LText: TScalarText;
begin
  Result := nil;
  LFile := TStringList.Create;
  LRoot := nil;
  try
    ReportWork(AProgress, 'inference_manifest_load', wuItems, 0, 1);
    LFile.LoadFromFile(AFileName);
    ReportWork(AProgress, 'inference_manifest_load', wuItems, 1, 1);
    LText := LFile.Text;
    LRoot := ParseNativeJSON(LText, Length(LText), 0, AProgress);
    if LRoot.JSONType <> jtObject then
    begin
      raise Exception.Create('Corpus manifest root is not an object');
    end;
    LObject := TJSONObject(LRoot);
    if RequiredString(LObject, 'format') <> 'pythian.raw-corpus.v1' then
    begin
      raise Exception.Create('Unsupported corpus manifest format');
    end;
    LEstimator := RequiredString(LObject, 'estimator');
    LPolicy := RequiredString(LObject, 'policy');
    LItems := TJSONArray(RequireField(LObject, 'entries', jtArray));
    if (LItems.Count < 2) or (LItems.Count > 1024) then
    begin
      raise Exception.Create('Corpus manifest entry count is outside bounds');
    end;
    SetLength(Result, LItems.Count);
    ReportWork(AProgress, 'inference_manifest_entries', wuItems, 0, LItems.Count);
    for LIndex := 0 to LItems.Count - 1 do
    begin
      Result[LIndex] := ParseEntry(LItems.Items[LIndex],
        LEstimator, LPolicy, ABindings, AProgress);
      ReportWork(AProgress, 'inference_manifest_entries', wuItems,
        LIndex + 1, LItems.Count);
    end;
  finally
    LRoot.Free;
    LFile.Free;
  end;
end;

procedure AuditCorpus(const AManifestFile: String);
var
  LBindings: TCorpusSourceBindings;
  LEntries: TInferenceCorpusEntries;
  LReader: TInferenceCorpusReader;
  LBatch: TInferenceBatch;
  LCounts: array of Int64;
  LEntryIndex: Integer;
  LIndex: Integer;
  LTotal: Int64;
  LReport: TJSONObject;
  LRows: TJSONArray;
  LRow: TJSONObject;
  LProgress: TConsoleWorkProgress;
  LFormatted: TJSONStringType;
begin
  LBindings := nil;
  LReader := nil;
  LProgress := TConsoleWorkProgress.Create;
  try
    LEntries := LoadEntries(AManifestFile, LBindings, LProgress.Observe);
    SetLength(LCounts, Length(LEntries));
    LReader := TInferenceCorpusReader.Create(LEntries, LProgress.Observe);
    LTotal := 0;
    LEntryIndex := -1;
    LBatch := nil;
    while LReader.ReadBatch(LEntryIndex, LBatch, LProgress.Observe) do
    begin
      if (LEntryIndex < 0) or (LEntryIndex >= Length(LEntries)) or
        (Length(LBatch) < 1) or (Length(LBatch) > InferenceMaximumBatch) then
      begin
        raise Exception.Create('Invalid corpus reader batch');
      end;
      Inc(LCounts[LEntryIndex], Length(LBatch));
      Inc(LTotal, Length(LBatch));
    end;
    LReport := TJSONObject.Create;
    try
      LReport.Add('format', 'pythian.raw-corpus.audit.v1');
      LReport.Add('manifest_sha256', HashInferenceFile(AManifestFile, LProgress.Observe));
      LReport.Add('source_count', Length(LBindings));
      LReport.Add('scope_count', Length(LEntries));
      LReport.Add('observation_count', LTotal);
      LRows := TJSONArray.Create;
      LReport.Add('entries', LRows);
      ReportWork(LProgress.Observe, 'inference_audit_entries', wuItems, 0, Length(LEntries));
      for LIndex := 0 to High(LEntries) do
      begin
        if LCounts[LIndex] <> LEntries[LIndex].Identity.ObservationCount then
        begin
          raise Exception.Create('Corpus scope observation count differs');
        end;
        LRow := TJSONObject.Create;
        { Own the row before any later hash/progress callback can raise. }
        LRows.Add(LRow);
        LRow.Add('group_id', LEntries[LIndex].GroupId);
        LRow.Add('source_id', LEntries[LIndex].SourceId);
        LRow.Add('scope_start16k',
          LEntries[LIndex].Identity.Request.ScopeStart16k);
        LRow.Add('scope_end16k',
          LEntries[LIndex].Identity.Request.ScopeEnd16k);
        LRow.Add('observations', LCounts[LIndex]);
        LRow.Add('artifact_sha256',
          HashInferenceFile(LEntries[LIndex].ArtifactFile, LProgress.Observe));
        ReportWork(LProgress.Observe, 'inference_audit_entries', wuItems,
          LIndex + 1, Length(LEntries));
      end;
      { The report has at most1024 fixed-schema rows. RTL pretty formatting and
        stdout are synchronous platform residuals; no second JSON writer exists. }
      ReportWork(LProgress.Observe, 'inference_audit_format', wuItems, 0, 1);
      LFormatted := LReport.FormatJSON;
      ReportWork(LProgress.Observe, 'inference_audit_format', wuItems, 1, 1);
      ReportWork(LProgress.Observe, 'inference_audit_ready', wuItems, 1, 1);
      WriteLn(LFormatted);
    finally
      LReport.Free;
    end;
  finally
    LReader.Free;
    LProgress.Free;
  end;
end;

begin
  try
    if (ParamCount <> 2) or (ParamStr(1) <> 'audit') then
    begin
      raise Exception.Create('Usage: pythian.inference.corpus.audit audit MANIFEST.json');
    end;
    AuditCorpus(ParamStr(2));
  except
    on LError: Exception do
    begin
      WriteLn(StdErr, LError.ClassName, ': ', LError.Message);
      ExitCode := 1;
    end;
  end;
end.
