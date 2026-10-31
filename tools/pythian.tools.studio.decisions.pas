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
unit pythian.tools.studio.decisions;

{$mode delphi}
{$H+}

interface

uses Classes, fpjson, pythian.music.decisions, pythian.progress;

type
  { Native filesystem adapter only. The portable writer owns the format, clock
    continuity and digest. A partial file has no accepted receipt. Finished data
    is content-addressed in the configured generated-artifact store, not source. }
  TStudioDecisionWriter = class
  private
    FFile: TFileStream;
    FWriter: TMusicDecisionWriter;
    FDirectory: String;
    FStage: String;
    FFinished: Boolean;
    FFinishing: Boolean;
    FFailed: Boolean;
  public
    constructor Create(const ACatalogRoot, AJobId: String);
    destructor Destroy; override;
    procedure Append(const AChunk: TMusicDecisionChunk);
    function Finish(const ACells, AMusicFrames: Int64;
      const AProgress: TWorkProgressCallback = nil): TJSONObject;
  end;

{ Opens and hashes the exact completed content-addressed journal before returning.
  Caller owns the returned stream; hash checking uses bounded primary reads. }
function OpenStudioDecisionJournal(const ACatalogRoot: String;
  const AReceipt: TJSONObject; const AProgress: TWorkProgressCallback = nil): TFileStream;

implementation

uses SysUtils, pythian.audio, pythian.hash,
  pythian.tools.listen.assets, pythian.tools.studio.jobs;

function DecisionDirectory(const ACatalogRoot: String): String;
begin
  Result := ListeningAssetDirectory(ACatalogRoot) + PathDelim + 'decisions';
end;

function OpenStudioDecisionJournal(const ACatalogRoot: String;
  const AReceipt: TJSONObject; const AProgress: TWorkProgressCallback): TFileStream;
var
  LHash: String;
  LCheck: array[0..63] of Byte;
  LFile: TFileStream;
begin
  if (AReceipt = nil) or (AReceipt.Strings['format'] <> 'pythian.music.decisions.v1') or
    (AReceipt.Integers['version'] <> MusicDecisionVersion) or
    (AReceipt.Strings['status'] <> 'completed') or
    (AReceipt.Int64s['bytes'] < 1) or (AReceipt.Int64s['music_frames'] < 1) or
    (AReceipt.Int64s['cells'] < 1) then
    raise EAudio.Create('A completed musical decision receipt is required');
  LHash := AReceipt.Strings['sha256'];
  WriteSha256Hex(LCheck, 0, LHash);
  LFile := TFileStream.Create(DecisionDirectory(ACatalogRoot) + PathDelim +
    LHash + '.pmd', fmOpenRead or fmShareDenyWrite);
  try
    if (LFile.Size <> AReceipt.Int64s['bytes']) or
      (Sha256Stream(LFile, LFile.Size, AProgress) <> LHash) then
      raise EAudio.Create('Saved musical decision journal differs from its completed receipt');
    LFile.Position := 0;
    ReportWork(AProgress, 'music_decision_open', wuItems, 1, 1);
  except
    LFile.Free;
    raise;
  end;
  Result := LFile;
end;

constructor TStudioDecisionWriter.Create(const ACatalogRoot, AJobId: String);
begin
  inherited Create;
  { Reuse the job's existing identity/path validation; never accept an arbitrary
    filename from a future browser request. }
  StudioJobDirectory(ACatalogRoot, AJobId);
  EnsureListeningAssetStorage(ACatalogRoot);
  FDirectory := DecisionDirectory(ACatalogRoot);
  if not ForceDirectories(FDirectory) then
    raise EAudio.Create('Could not create musical decision storage');
  FStage := FDirectory + PathDelim + AJobId + '.partial';
  if FileExists(FStage) then
    raise EAudio.Create('Musical decision stage already exists; preserve the previous failure');
  FFile := TFileStream.Create(FStage, fmCreate or fmShareExclusive);
  FWriter := TMusicDecisionWriter.Create(FFile);
end;

destructor TStudioDecisionWriter.Destroy;
begin
  FWriter.Free;
  FFile.Free;
  inherited Destroy;
end;

procedure TStudioDecisionWriter.Append(const AChunk: TMusicDecisionChunk);
begin
  if FFinished or FFinishing or FFailed then
    raise EAudio.Create('Musical decision publication is finished, busy or failed');
  try
    FWriter.Append(AChunk);
  except
    FFailed := True;
    raise;
  end;
end;

function TStudioDecisionWriter.Finish(const ACells, AMusicFrames: Int64;
  const AProgress: TWorkProgressCallback): TJSONObject;
var
  LHash, LFinal: String;
  LReceipt: TJSONObject;
  LExisting: TFileStream;
begin
  if FFinished or FFinishing or FFailed or (FWriter.CellCount <> ACells) or
    (FWriter.FrameCount <> AMusicFrames) then
    raise EAudio.Create('Musical decisions do not cover the completed performance');
  LHash := FWriter.Seal;
  LReceipt := TJSONObject.Create(['format', 'pythian.music.decisions.v1',
    'version', MusicDecisionVersion, 'status', 'completed', 'sha256', LHash,
    'bytes', FWriter.ByteCount, 'cells', ACells, 'music_frames', AMusicFrames]);
  FFinishing := True;
  try
    try
      if not FileFlush(FFile.Handle) then
        raise EAudio.Create('Could not flush completed musical decisions');
      FreeAndNil(FFile);
      LFinal := FDirectory + PathDelim + LHash + '.pmd';
      { A competing identical publisher may win after FileExists. Match the
        existing canonical audio publication rule: failed rename can reuse only
        verified identical content, never a blind overwrite or missing file. }
      if FileExists(LFinal) or not RenameFile(FStage, LFinal) then
      begin
        LExisting := TFileStream.Create(LFinal, fmOpenRead or fmShareDenyWrite);
        try
          if (LExisting.Size <> FWriter.ByteCount) or
            (Sha256Stream(LExisting, LExisting.Size, AProgress) <> LHash) then
            raise EAudio.Create('Existing musical decision content differs');
        finally
          LExisting.Free;
        end;
        if not DeleteFile(FStage) then
          raise EAudio.Create('Could not release duplicate musical decision stage');
      end;
      ReportWork(AProgress, 'music_decision_saved', wuItems, 1, 1);
      FFinished := True;
    except
      FFailed := True;
      LReceipt.Free;
      raise;
    end;
  finally
    FFinishing := False;
  end;
  Result := LReceipt;
end;

end.
