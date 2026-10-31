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
unit pythian.tools.studio.instrumental.output;
{$mode delphi}
{$H+}

interface

uses fpjson, pythian.audio, pythian.bus, pythian.wave.stream,
  pythian.tools.listen.assets, pythian.progress;

const
  StudioInstrumentalOutputCount = 7;
  StudioInstrumentalTailSeconds = 1;
  StudioInstrumentalOutputReserve: Int64 = 268435456;
  StudioInstrumentalStemBuses: array[0..5] of Integer = (6, 7, 8, 9, 10, 11);

type
  { One shared graph and seven bounded PCM sinks. Sources0..5 feed their own
    stem buses6..11 and master12. Each stem/master has its own limiter: stems
    remain independently playable without claiming nonlinear master summation.
    The performer borrows Graph and must be destroyed before this owner. }
  TStudioInstrumentalOutput = class
  private
    FGraph: TBusGraph;
    FAssets: array[0..6] of TListeningAssetWriter;
    FWriters: array[0..6] of TWavePcm16Writer;
    FFailed: Boolean;
    FFinished: Boolean;
    FSeed: Cardinal;
  public
    constructor Create(const ACatalogRoot, AJobId: String; const ASampleRate: Integer;
      const AFrames: Int64; const ALevels: TJSONArray; const ASeed: Cardinal);
    destructor Destroy; override;
    procedure Append(const AMaster: TAudioSamples; const AStems: TBusSampleBlocks);
    function Finish(const AProgress: TWorkProgressCallback = nil): TJSONObject;
    property Graph: TBusGraph read FGraph;
  end;

{ Owned estimate, no payload allocation. Includes all seven retained files,
  primary RIFF/RF64 headers and a fixed metadata/free-space reserve. }
function StudioInstrumentalOutputEstimate(const ADurationMs: Int64): TJSONObject;
{ Native host volume check, before learning/rendering. Does not reserve space
  against other writers; later I/O failures remain normal terminal job errors. }
procedure AdmitStudioInstrumentalOutput(const ACatalogRoot: String; const ADurationMs: Int64);

implementation

uses Classes, SysUtils, pythian.effects, pythian.tools.studio.instrumental.config
  {$IFDEF MSWINDOWS}, Windows{$ENDIF}
  {$IFDEF UNIX}, Unix, BaseUnix{$ENDIF};

const
  CPartNames: array[0..5] of String = ('Bass', 'Harmony', 'Lead', 'Kick', 'Snare', 'Hat');

function StudioInstrumentalOutputEstimate(const ADurationMs: Int64): TJSONObject;
var
  LFrames, LBytes: Int64;
begin
  if (ADurationMs < 2000) or (ADurationMs > 86400000) then
    raise EAudio.Create('Track length must be2seconds to24hours');
  LFrames := ADurationMs * StudioInstrumentalRate div 1000 +
    StudioInstrumentalTailSeconds * StudioInstrumentalRate;
  LBytes := WavePcm16ByteCount(StudioInstrumentalRate, 2, LFrames);
  Result := TJSONObject.Create;
  Result.Add('sample_rate', StudioInstrumentalRate);
  Result.Add('channels', 2);
  Result.Add('bits_per_sample', 16);
  Result.Add('music_frames', ADurationMs * StudioInstrumentalRate div 1000);
  Result.Add('tail_frames', Int64(StudioInstrumentalTailSeconds) * StudioInstrumentalRate);
  Result.Add('frame_count', LFrames);
  Result.Add('wav_bytes_each', LBytes);
  Result.Add('retained_outputs', StudioInstrumentalOutputCount);
  Result.Add('audio_bytes', LBytes * StudioInstrumentalOutputCount);
  Result.Add('required_free_bytes', LBytes * StudioInstrumentalOutputCount + StudioInstrumentalOutputReserve);
  Result.Add('lookahead_cells', 16);
  Result.Add('pcm_block_frames', 2048);
  Result.Add('storage_note', 'Mix plus six stems; retained musical decisions and analysis caches are additional. Space is checked again when the native job starts.');
end;

procedure AdmitStudioInstrumentalOutput(const ACatalogRoot: String; const ADurationMs: Int64);
var
  LEstimate: TJSONObject;
  LRoot: String;
  LFree: Int64;
  {$IFDEF MSWINDOWS}
  LTotal: Int64;
  {$ENDIF}
  {$IFDEF UNIX}
  LInfo: TStatfs;
  {$ENDIF}
begin
  LEstimate := StudioInstrumentalOutputEstimate(ADurationMs);
  try
    EnsureListeningAssetStorage(ACatalogRoot);
    LRoot := ListeningAssetDirectory(ACatalogRoot);
    LFree := -1;
    {$IFDEF MSWINDOWS}
    if not GetDiskFreeSpaceEx(PChar(LRoot), LFree, LTotal, nil) then
      raise EAudio.Create('Could not check available audio storage');
    {$ENDIF}
    {$IFDEF UNIX}
    if fpStatFS(PChar(LRoot), @LInfo) <> 0 then
      raise EAudio.Create('Could not check available audio storage');
    LFree := Int64(LInfo.bavail) * Int64(LInfo.bsize);
    {$ENDIF}
    if (LFree >= 0) and (LFree < LEstimate.Int64s['required_free_bytes']) then
      raise EAudio.Create('Not enough space for the mix and six stems. Choose a shorter track or free audio storage.');
  finally
    LEstimate.Free;
  end;
end;

constructor TStudioInstrumentalOutput.Create(const ACatalogRoot, AJobId: String;
  const ASampleRate: Integer; const AFrames: Int64; const ALevels: TJSONArray;
  const ASeed: Cardinal);
var
  LSettings: array[0..12] of TBusSettings;
  I: Integer;
begin
  inherited Create;
  if (ALevels = nil) or (ALevels.Count <> 6) then
    raise EAudio.Create('Instrumental output requires six part levels');
  FSeed := ASeed;
  for I := 0 to 12 do
  begin
    LSettings[I] := Default(TBusSettings);
    if I < 6 then LSettings[I].Gain := ALevels.Integers[I] / 100
    else LSettings[I].Gain := 0.7;
  end;
  FGraph := TBusGraph.Create(ASampleRate, LSettings);
  for I := 0 to 5 do
  begin
    FGraph.AddSend(I, I + 6, stPostFader, 1, 0);
    FGraph.AddSend(I, 12, stPostFader, 1, 0);
    FGraph.AddEffect(I + 6, TLimiterEffect.Create(ASampleRate, -1, 0.08));
  end;
  FGraph.AddEffect(12, TLimiterEffect.Create(ASampleRate, -1, 0.08));
  for I := 0 to 6 do
  begin
    FAssets[I] := TListeningAssetWriter.Create(ACatalogRoot, AJobId + '-part-' + IntToStr(I));
    FWriters[I] := TWavePcm16Writer.Create(FAssets[I], ASampleRate, 2, AFrames);
  end;
end;

destructor TStudioInstrumentalOutput.Destroy;
var
  I: Integer;
begin
  for I := 0 to 6 do
  begin
    FWriters[I].Free;
    FAssets[I].Free;
  end;
  FGraph.Free;
  inherited Destroy;
end;

procedure TStudioInstrumentalOutput.Append(const AMaster: TAudioSamples;
  const AStems: TBusSampleBlocks);
var
  I: Integer;
begin
  if FFailed or FFinished then raise EAudio.Create('Instrumental output is closed or failed');
  if (Length(AStems) <> 6) or (Length(AMaster) = 0) then
    raise EAudio.Create('Instrumental output requires matching master and six stem blocks');
  for I := 0 to 5 do
    if Length(AStems[I]) <> Length(AMaster) then
      raise EAudio.Create('Instrumental output blocks have different clocks');
  try
    for I := 0 to 5 do FWriters[I].AppendSamples(AStems[I]);
    FWriters[6].AppendSamples(AMaster);
  except
    FFailed := True;
    raise;
  end;
end;

function TStudioInstrumentalOutput.Finish(const AProgress: TWorkProgressCallback): TJSONObject;
var
  LAsset, LRow: TJSONObject;
  LParts, LOutputs: TJSONArray;
  I: Integer;
begin
  if FFailed or FFinished then raise EAudio.Create('Instrumental output is closed or failed');
  Result := TJSONObject.Create;
  try
    try
      { Validate every completed writer before publishing the first asset. }
      for I := 0 to 6 do FWriters[I].Finish;
      LParts := TJSONArray.Create;
      Result.Add('parts', LParts);
      LOutputs := TJSONArray.Create;
      Result.Add('outputs', LOutputs);
      for I := 0 to 6 do
      begin
        ReportWork(AProgress, 'instrumental_publish', wuItems, I, 8);
        LAsset := FAssets[I].Finish;
        try
          LRow := TJSONObject.Create;
          if I < 6 then LParts.Add(LRow) else LOutputs.Add(LRow);
          LRow.Add('storage', 'listening');
          LRow.Add('wav_sha256', LAsset.Strings['sha256']);
          LRow.Add('wav_bytes', LAsset.Int64s['bytes']);
          LRow.Add('sample_rate', LAsset.Integers['sample_rate']);
          LRow.Add('channels', LAsset.Integers['channels']);
          LRow.Add('frame_count', LAsset.Int64s['frames']);
          LRow.Add('seed', Int64(FSeed));
          LRow.Add('status', 'verified');
          if I < 6 then
          begin
            LRow.Add('name', CPartNames[I]);
            LRow.Add('part_index', I);
          end;
        finally LAsset.Free; end;
        { Seven confirmed audio outputs; the eighth step is final reference,
          metadata and review publication. Only terminal job success closes it. }
        ReportWork(AProgress, 'instrumental_publish', wuItems, I + 1, 8);
      end;
      FFinished := True;
    except
      FFailed := True;
      raise;
    end;
  except
    Result.Free;
    raise;
  end;
end;
end.
