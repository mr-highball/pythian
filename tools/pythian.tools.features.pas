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

unit pythian.tools.features;

{$mode delphi}
{$H+}

interface

procedure CacheWaveFeatures(const AInput, AOutput: String;
  const ABatchFeatures, AMaximumBatches: Integer);

implementation

uses
  Classes,
  SysUtils,
  fpjson,
  {$ifdef MSWINDOWS}
  Windows,
  {$else}
  BaseUnix,
  Unix,
  {$endif}
  pythian.audio,
  pythian.analysis,
  pythian.analysis.wave,
  pythian.analysis.journal,
  pythian.wave.read,
  pythian.hash;

type
  { OPEN_ALWAYS / O_CREAT opens without truncating; an exclusive lock prevents
    competing cache writers. The handle is owned here, outside the core. }
  TFeatureCacheFile = class(THandleStream)
  private
    FOwnsHandle: Boolean;
  public
    constructor Create(const APath: String);
    destructor Destroy; override;
    procedure Commit;
  end;

constructor TFeatureCacheFile.Create(const APath: String);
var
  LHandle: THandle;
begin
  {$ifdef MSWINDOWS}
  LHandle := CreateFileW(PWideChar(UnicodeString(APath)), GENERIC_READ or GENERIC_WRITE,
    0, nil, OPEN_ALWAYS, FILE_ATTRIBUTE_NORMAL, 0);
  if LHandle = INVALID_HANDLE_VALUE then
  begin
    RaiseLastOSError;
  end;
  {$else}
  LHandle := fpOpen(PChar(APath), O_RDWR or O_CREAT, &600);
  if LHandle < 0 then
  begin
    RaiseLastOSError;
  end;
  if fpFlock(LHandle, LOCK_EX or LOCK_NB) <> 0 then
  begin
    FileClose(LHandle);
    raise EAudio.Create('Feature cache is already in use');
  end;
  {$endif}
  inherited Create(LHandle);
  FOwnsHandle := True;
end;

destructor TFeatureCacheFile.Destroy;
begin
  if FOwnsHandle then
  begin
    FileClose(Handle);
  end;
  inherited Destroy;
end;

procedure TFeatureCacheFile.Commit;
begin
  if not FileFlush(Handle) then
  begin
    raise EAudio.Create('Feature cache flush failed');
  end;
end;

procedure CacheWaveFeatures(const AInput, AOutput: String;
  const ABatchFeatures, AMaximumBatches: Integer);
var
  LInput: TFileStream;
  LReader: TWaveFrameReader;
  LFile: TFeatureCacheFile;
  LJournal: TFeatureJournal;
  LBinding: TFeatureJournalBinding;
  LBatch: TWaveFeatureBatch;
  LDocument: TJSONObject;
  LSize: Int64;
  LResume: Int64;
  LRecovered: Int64;
  LPrefixBytes: Int64;
  LCount: Integer;
  LPlanned: Integer;
  LWork: Int64;
begin
  if SameFileName(ExpandFileName(AInput), ExpandFileName(AOutput)) then
  begin
    raise EAudio.Create('Feature cache must differ from its WAV source');
  end;
  if (ABatchFeatures < 1) or (ABatchFeatures > MaximumFeatureJournalBatch) or
    (AMaximumBatches < 0) then
  begin
    raise EAudio.Create('Cache batch features must be 1..4096; maximum batches must be nonnegative');
  end;
  LInput := nil;
  LReader := nil;
  LFile := nil;
  LJournal := nil;
  LDocument := nil;
  try
    LInput := TFileStream.Create(AInput, fmOpenRead or fmShareDenyWrite);
    LReader := TWaveFrameReader.Create(LInput);
    LBinding := Default(TFeatureJournalBinding);
    LBinding.SampleRate := LReader.SampleRate;
    LBinding.Channels := LReader.Channels;
    LBinding.FrameCount := LReader.FrameCount;
    LBinding.Options := DefaultAnalysisOptions;
    PlanAudioAnalysis(ABatchFeatures * LBinding.Options.HopFrames + 1,
      LBinding.Channels, LBinding.Options, LPlanned, LWork);
    LSize := LInput.Size;
    LInput.Position := 0;
    LBinding.SourceSha256 := Sha256Stream(LInput, LSize);
    LFile := TFeatureCacheFile.Create(AOutput);
    LJournal := TFeatureJournal.Create(LFile, LBinding, LFile.Commit, LFile.Size = 0);
    LRecovered := LJournal.TailBytes;
    LJournal.RecoverTail;
    LPrefixBytes := LFile.Size;
    LResume := LJournal.NextFeature;
    LCount := 0;
    while not LJournal.Completed and
      ((AMaximumBatches = 0) or (LCount < AMaximumBatches)) do
    begin
      LBatch := AnalyzeWaveBatch(LReader, LBinding.Options, LJournal.NextFeature, ABatchFeatures);
      LJournal.Append(LBatch);
      Inc(LCount);
    end;
    LInput.Position := 0;
    if (LInput.Size <> LSize) or (Sha256Stream(LInput, LSize) <> LBinding.SourceSha256) then
    begin
      { Known source change invalidates only this invocation's appended work. }
      FreeAndNil(LJournal);
      LFile.Size := LPrefixBytes;
      LFile.Commit;
      raise EAudio.Create('WAV source changed; this invocation''s appended observations were removed');
    end;
    LDocument := TJSONObject.Create;
    LDocument.Add('contract', 'pythian.feature.journal');
    LDocument.Add('source_sha256', LBinding.SourceSha256);
    LDocument.Add('analysis_version', AnalysisVersion);
    LDocument.Add('source_frames', LBinding.FrameCount);
    LDocument.Add('sample_rate', LBinding.SampleRate);
    LDocument.Add('channels', LBinding.Channels);
    LDocument.Add('resumed_at', LResume);
    LDocument.Add('next_feature', LJournal.NextFeature);
    LDocument.Add('total_features', LJournal.TotalFeatures);
    LDocument.Add('completed', LJournal.Completed);
    LDocument.Add('batches_appended', LCount);
    LDocument.Add('incomplete_tail_bytes_removed', LRecovered);
    LDocument.Add('batch_features', ABatchFeatures);
    LDocument.Add('cache_bytes', LFile.Size);
    LDocument.Add('policy', 'Source-bound feature cache; checked batches committed before progress advances; no palette or WFC model trained');
    WriteLn(LDocument.FormatJSON);
  finally
    LDocument.Free;
    LJournal.Free;
    LFile.Free;
    LReader.Free;
    LInput.Free;
  end;
end;

end.

