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
unit pythian.tools.studio.preparation;
{$mode delphi}{$H+}

interface

uses
  Classes,
  fpjson, pythian.tools.json,
  pythian.progress,
  pythian.wave.read;

const
  MaximumStudioPreparedBytes: Int64 = 4294967296;
  MaximumStudioPreparationVisits: Int64 = 100000000000;

type
  TStudioPreparationPlan = record
    OutputFrames: Int64;
    OutputBytesUpperBound: Int64;
    VisitsUpperBound: Int64;
  end;

  TStudioPreparedRange = class
  private
    FStream: TFileStream;
    FWave: TWaveFrameReader;
    FReceipt: TJSONObject;
    FRecipeSha256: String;
  public
    destructor Destroy; override;
    procedure Verify(const AProgress: TWorkProgressCallback = nil);
    property Wave: TWaveFrameReader read FWave;
    property Receipt: TJSONObject read FReceipt;
    property RecipeSha256: String read FRecipeSha256;
  end;

function CanonicalStudioPreparationConfig(const AConfig: TJSONObject): TJSONObject;
function PlanStudioPreparation(const AInputFrames: Int64; const AInputRate,
  AInputChannels: Integer; const AConfig: TJSONObject): TStudioPreparationPlan;
function BuildStudioPreparationRecipe(const ASnapshot, AConfig: TJSONObject): TJSONObject;
function PrepareStudioRange(const ACacheRoot: String; const AOriginal: TWaveFrameReader;
  const ASnapshot, AConfig: TJSONObject; const AProgress: TWorkProgressCallback = nil): TStudioPreparedRange;

implementation

uses
  SysUtils,
  Math,
  jsonparser,
  pythian.audio,
  pythian.hash,
  pythian.resample,
  pythian.resample.stream,
  pythian.wave.resample,
  pythian.wave.stream;

type
  TPreparationProgress = class
    Callback: TWorkProgressCallback;
    Stage: String;
    procedure Verify(const AWork: TWorkProgress);
  end;

procedure Need(const ACondition: Boolean; const AMessage: String); forward;

procedure TPreparationProgress.Verify(const AWork: TWorkProgress);
begin
  ReportWork(Callback, Stage, wuBytes, AWork.Done, AWork.Total);
end;

function PlanStudioPreparation(const AInputFrames: Int64; const AInputRate,
  AInputChannels: Integer; const AConfig: TJSONObject): TStudioPreparationPlan;
var
  LConfig: TJSONObject;
  LRate: Integer;
  LChannels: Integer;
  LVisitsPerFrame: Int64;
begin
  ValidateAudioFormat(AInputRate, AInputChannels);
  Need(AInputFrames > 0, 'Preparation range must contain audio');
  LConfig := CanonicalStudioPreparationConfig(AConfig);
  try
    LRate := LConfig.Integers['sample_rate'];
    LChannels := LConfig.Integers['channels'];
    Result.OutputFrames := StreamResampleFrameCount(AInputFrames, AInputRate, LRate);
    Need(Result.OutputFrames <= (MaximumStudioPreparedBytes - Rf64HeaderBytes) div
      (LChannels * 2), 'Prepared WAV exceeds byte budget');
    Result.OutputBytesUpperBound := Result.OutputFrames * LChannels * 2 + Rf64HeaderBytes;
    LVisitsPerFrame := AInputChannels;
    if LRate <> AInputRate then
    begin
      LVisitsPerFrame := LVisitsPerFrame * SincTapBudget(AInputRate / LRate);
    end;
    Need(Result.OutputFrames <= MaximumStudioPreparationVisits div LVisitsPerFrame,
      'Preparation exceeds filter work budget');
    Result.VisitsUpperBound := Result.OutputFrames * LVisitsPerFrame;
  finally
    LConfig.Free;
  end;
end;

procedure Need(const ACondition: Boolean; const AMessage: String);
begin
  if not ACondition then
  begin
    raise EAudio.Create(AMessage);
  end;
end;

function CanonicalStudioPreparationConfig(const AConfig: TJSONObject): TJSONObject;
var
  LRate: Int64;
  LChannels: Int64;
  LGain: Double;
  LValue: TJSONData;
  LIndex: Integer;
begin
  Need(AConfig <> nil, 'Preparation needs configuration');
  Need(AConfig.Count = 3, 'Preparation configuration requires rate, channels and gain');
  for LIndex := 0 to AConfig.Count - 1 do
  begin
    Need((AConfig.Names[LIndex] = 'sample_rate') or (AConfig.Names[LIndex] = 'channels') or
      (AConfig.Names[LIndex] = 'gain'), 'Unknown preparation configuration field');
  end;
  LValue := AConfig.Find('sample_rate');
  Need((LValue <> nil) and (LValue.JSONType = jtNumber) and
    (TJSONNumber(LValue).NumberType in [ntInteger, ntInt64]), 'Preparation rate must be integer');
  LRate := LValue.AsInt64;
  LValue := AConfig.Find('channels');
  Need((LValue <> nil) and (LValue.JSONType = jtNumber) and
    (TJSONNumber(LValue).NumberType in [ntInteger, ntInt64]), 'Preparation channels must be integer');
  LChannels := LValue.AsInt64;
  LValue := AConfig.Find('gain');
  Need((LValue <> nil) and (LValue.JSONType = jtNumber), 'Preparation gain must be numeric');
  LGain := LValue.AsFloat;
  RequireFinite(LGain, 'Preparation gain');
  Need((LRate >= 8000) and (LRate <= 192000) and (LChannels in [1, 2]) and
    (LGain > 0) and (LGain <= 1), 'Preparation format or gain outside supported bounds');
  Result := TJSONObject.Create;
  Result.Add('sample_rate', LRate);
  Result.Add('channels', LChannels);
  Result.Add('gain', LGain);
end;

function BuildStudioPreparationRecipe(const ASnapshot, AConfig: TJSONObject): TJSONObject;
var
  LConfig: TJSONObject;
begin
  Need(ASnapshot <> nil, 'Preparation needs source snapshot');
  LConfig := CanonicalStudioPreparationConfig(AConfig);
  Result := TJSONObject.Create;
  try
    Result.Add('version', 1);
    Result.Add('policy', 'studio-range-sinc-pcm16-v1');
    Result.Add('source_snapshot', ASnapshot.Clone);
    Result.Add('config', LConfig);
  except
    Result.Free;
    raise;
  end;
end;

function RecipeHash(const AText: String): String;
var
  LBytes: TAudioBytes;
  LIndex: Integer;
begin
  SetLength(LBytes, Length(AText));
  for LIndex := 1 to Length(AText) do
  begin
    LBytes[LIndex - 1] := Ord(AText[LIndex]);
  end;
  Result := Sha256Bytes(LBytes);
end;

destructor TStudioPreparedRange.Destroy;
begin
  FWave.Free;
  FStream.Free;
  FReceipt.Free;
  inherited Destroy;
end;

procedure TStudioPreparedRange.Verify(const AProgress: TWorkProgressCallback);
var
  LPosition: Int64;
  LProgress: TPreparationProgress;
  LHash: String;
begin
  Need((FStream <> nil) and (FWave <> nil) and (FReceipt <> nil),
    'Prepared range is not open');
  LPosition := FWave.FramePosition;
  LProgress := TPreparationProgress.Create;
  LProgress.Callback := AProgress;
  LProgress.Stage := 'prepare_verify_bytes';
  try
    Need((FReceipt.Get('recipe_sha256', '') = FRecipeSha256) and
      (FReceipt.Find('recipe') <> nil) and
      (RecipeHash(FReceipt.Objects['recipe'].AsJSON) = FRecipeSha256),
      'Prepared recipe identity differs');
    FStream.Position := 0;
    Need(FStream.Size = FReceipt.Int64s['prepared_bytes'], 'Prepared WAV size differs');
    LHash := Sha256Stream(FStream, FStream.Size, LProgress.Verify);
    Need(LHash = FReceipt.Strings['prepared_sha256'], 'Prepared WAV hash differs');
    Need((FWave.SampleRate = FReceipt.Integers['sample_rate']) and
      (FWave.Channels = FReceipt.Integers['channels']) and
      (FWave.FrameCount = FReceipt.Int64s['prepared_frames']) and
      (FWave.BitsPerSample = 16) and (FWave.EncodingTag = 1), 'Prepared geometry differs');
  finally
    FWave.SeekFrame(LPosition);
    LProgress.Free;
  end;
end;

function LoadReceipt(const APath: String): TJSONObject;
var
  LFile: TFileStream;
  LText: String;
  LData: TJSONData;
begin
  LFile := TFileStream.Create(APath, fmOpenRead or fmShareDenyWrite);
  try
    Need((LFile.Size > 0) and (LFile.Size <= 1048576), 'Preparation receipt exceeds limit');
    SetLength(LText, LFile.Size);
    LFile.ReadBuffer(LText[1], Length(LText));
  finally
    LFile.Free;
  end;
  LData := ParseNativeJSON(LText);
  if LData.JSONType <> jtObject then
  begin
    LData.Free;
    raise EAudio.Create('Invalid preparation receipt');
  end;
  Result := TJSONObject(LData);
end;

function OpenCached(const ADirectory, ARecipeHash: String; const ARecipe: TJSONObject;
  const AFrames: Int64; const AProgress: TPreparationProgress): TStudioPreparedRange;
var
  LHash: String;
begin
  Result := TStudioPreparedRange.Create;
  try
    Result.FRecipeSha256 := ARecipeHash;
    Result.FReceipt := LoadReceipt(ADirectory + PathDelim + 'receipt.json');
    Need((Result.FReceipt.Get('recipe_sha256', '') = ARecipeHash) and
      (Result.FReceipt.Find('recipe') <> nil) and
      (Result.FReceipt.Objects['recipe'].AsJSON = ARecipe.AsJSON), 'Prepared recipe differs');
    Result.FStream := TFileStream.Create(ADirectory + PathDelim + 'audio.wav',
      fmOpenRead or fmShareDenyWrite);
    Need((Result.FStream.Size = Result.FReceipt.Int64s['prepared_bytes']) and
      (Result.FStream.Size <= MaximumStudioPreparedBytes), 'Prepared WAV size differs');
    LHash := Sha256Stream(Result.FStream, Result.FStream.Size, AProgress.Verify);
    Need(LHash = Result.FReceipt.Strings['prepared_sha256'], 'Prepared WAV hash differs');
    Result.FStream.Position := 0;
    Result.FWave := TWaveFrameReader.Create(Result.FStream);
    Need((Result.FWave.SampleRate = ARecipe.Objects['config'].Integers['sample_rate']) and
      (Result.FWave.Channels = ARecipe.Objects['config'].Integers['channels']) and
      (Result.FWave.BitsPerSample = 16) and (Result.FWave.EncodingTag = 1) and
      (Result.FWave.FrameCount = AFrames) and
      (Result.FReceipt.Int64s['prepared_frames'] = AFrames) and
      (Result.FReceipt.Int64s['frame_count'] = AFrames) and
      (Result.FReceipt.Int64s['bytes'] = Result.FStream.Size) and
      (Result.FReceipt.Integers['sample_rate'] = Result.FWave.SampleRate) and
      (Result.FReceipt.Integers['channels'] = Result.FWave.Channels) and
      (Result.FReceipt.Integers['clipped_samples'] = 0), 'Prepared WAV geometry differs');
  except
    Result.Free;
    raise;
  end;
end;

function PrepareStudioRange(const ACacheRoot: String; const AOriginal: TWaveFrameReader;
  const ASnapshot, AConfig: TJSONObject; const AProgress: TWorkProgressCallback): TStudioPreparedRange;
var
  LRecipe: TJSONObject;
  LRecipeHash: String;
  LStart: Int64;
  LEnd: Int64;
  LFrames: Int64;
  LBytes: Int64;
  LPlan: TStudioPreparationPlan;
  LRate: Integer;
  LChannels: Integer;
  LGain: Double;
  LRoot: String;
  LFinal: String;
  LStage: String;
  LGuid: TGUID;
  LReader: TWavePcmReader;
  LResampler: TSincResampleStream;
  LOutput: TFileStream;
  LSink: TStreamAudioSink;
  LWriter: TWavePcm16Writer;
  LSamples: TAudioSamples;
  LLeft: Double;
  LRight: Double;
  LValue: Double;
  LPeak: Double;
  LOutputPeak: Double;
  LCount: Integer;
  LChannel: Integer;
  LDone: Int64;
  LDigest: String;
  LReceipt: TJSONObject;
  LText: String;
  LProgress: TPreparationProgress;
begin
  Result := nil;
  Need((AOriginal <> nil) and not AOriginal.Failed, 'Preparation requires a healthy source');
  LRecipe := BuildStudioPreparationRecipe(ASnapshot, AConfig);
  LProgress := TPreparationProgress.Create;
  LProgress.Callback := AProgress;
  LProgress.Stage := 'prepare_verify_bytes';
  LStage := '';
  try
    LStart := ASnapshot.Int64s['start_frame'];
    LEnd := ASnapshot.Int64s['end_frame'];
    Need((ASnapshot.Integers['sample_rate'] = AOriginal.SampleRate) and
      (ASnapshot.Integers['channels'] = AOriginal.Channels) and
      (ASnapshot.Int64s['frame_count'] = AOriginal.FrameCount) and
      (LStart >= 0) and (LEnd > LStart) and (LEnd <= AOriginal.FrameCount),
      'Preparation source geometry or range differs from snapshot');
    LRate := LRecipe.Objects['config'].Integers['sample_rate'];
    LChannels := LRecipe.Objects['config'].Integers['channels'];
    LGain := LRecipe.Objects['config'].Floats['gain'];
    LPlan := PlanStudioPreparation(LEnd - LStart, AOriginal.SampleRate,
      AOriginal.Channels, AConfig);
    LFrames := LPlan.OutputFrames;
    LRecipeHash := RecipeHash(LRecipe.AsJSON);
    LRoot := IncludeTrailingPathDelimiter(ExpandFileName(ACacheRoot));
    Need(ForceDirectories(LRoot), 'Could not create preparation cache');
    LFinal := LRoot + LRecipeHash;
    if DirectoryExists(LFinal) then
    begin
      Result := OpenCached(LFinal, LRecipeHash, LRecipe, LFrames, LProgress);
      Exit;
    end;
    Need(CreateGUID(LGuid) = 0, 'Could not create preparation stage');
    LStage := LRoot + GUIDToString(LGuid) + '.partial';
    Need(CreateDir(LStage), 'Could not create preparation stage');
    LReader := nil;
    LResampler := nil;
    LOutput := nil;
    LSink := nil;
    LWriter := nil;
    try
      LReader := TWavePcmReader.CreateRange(AOriginal, LStart, LEnd);
      LResampler := TSincResampleStream.Create(LReader, LRate);
      LOutput := TFileStream.Create(LStage + PathDelim + 'audio.wav', fmCreate or fmShareExclusive);
      LSink := TStreamAudioSink.Create(LOutput);
      LWriter := TWavePcm16Writer.Create(LSink, LRate, LChannels, LFrames);
      SetLength(LSamples, 4096 * LChannels);
      LDone := 0;
      LCount := 0;
      LPeak := 0;
      LOutputPeak := 0;
      ReportWork(AProgress, 'prepare_audio', wuFrames, 0, LFrames);
      while LResampler.ReadFrame(LLeft, LRight) do
      begin
        if LChannels = 1 then
        begin
          LLeft := LLeft * 0.5 + LRight * 0.5;
        end;
        for LChannel := 0 to LChannels - 1 do
        begin
          if LChannel = 0 then LValue := LLeft else LValue := LRight;
          LPeak := Max(LPeak, Abs(LValue));
          LValue := LValue * LGain;
          LOutputPeak := Max(LOutputPeak, Abs(LValue));
          Need((LValue >= -1) and (LValue <= 1), 'Prepared audio is too loud. Lower preparation volume.');
          LSamples[LCount] := LValue;
          Inc(LCount);
        end;
        Inc(LDone);
        if LCount = Length(LSamples) then
        begin
          LWriter.AppendSamples(LSamples);
          LCount := 0;
          ReportWork(AProgress, 'prepare_audio', wuFrames, LDone, LFrames);
        end;
      end;
      Need((LDone = LFrames) and (LResampler.InputFrameCount = LEnd - LStart),
        'Prepared frame count differs from declared mapping');
      SetLength(LSamples, LCount);
      LWriter.AppendSamples(LSamples);
      LWriter.Finish;
      ReportWork(AProgress, 'prepare_audio', wuFrames, LFrames, LFrames);
      FreeAndNil(LWriter);
      FreeAndNil(LSink);
      LOutput.Position := 0;
      LProgress.Stage := 'prepare_hash_bytes';
      LDigest := Sha256Stream(LOutput, LOutput.Size, LProgress.Verify);
      LProgress.Stage := 'prepare_verify_bytes';
      LBytes := LOutput.Size;
    finally
      LWriter.Free;
      LSink.Free;
      LOutput.Free;
      LResampler.Free;
      LReader.Free;
    end;
    LReceipt := TJSONObject.Create;
    try
      LReceipt.Add('recipe_sha256', LRecipeHash);
      LReceipt.Add('recipe', LRecipe.Clone);
      LReceipt.Add('prepared_sha256', LDigest);
      LReceipt.Add('prepared_bytes', LBytes);
      LReceipt.Add('prepared_frames', LFrames);
      LReceipt.Add('bytes', LBytes);
      LReceipt.Add('frame_count', LFrames);
      LReceipt.Add('sample_rate', LRate);
      LReceipt.Add('channels', LChannels);
      LReceipt.Add('original_start_frame', LStart);
      LReceipt.Add('original_rate', AOriginal.SampleRate);
      LReceipt.Add('mapping', 'original_start + output_frame * original_rate / prepared_rate');
      LReceipt.Add('rounding', 'ceil output frame count');
      LReceipt.Add('filter', 'centered Blackman sinc; constant selected-range endpoints; no extra tail');
      LReceipt.Add('layout', 'mono duplicated to stereo; stereo averaged to mono');
      LReceipt.Add('quantization', 'PCM16, nearest with halves away from zero');
      LReceipt.Add('peak_before_gain', LPeak);
      LReceipt.Add('peak_after_gain', LOutputPeak);
      LReceipt.Add('clipped_samples', 0);
      LText := LReceipt.AsJSON + #10;
      LOutput := TFileStream.Create(LStage + PathDelim + 'receipt.json', fmCreate or fmShareExclusive);
      try
        LOutput.WriteBuffer(LText[1], Length(LText));
      finally
        LOutput.Free;
      end;
    finally
      LReceipt.Free;
    end;
    Result := OpenCached(LStage, LRecipeHash, LRecipe, LFrames, LProgress);
    Result.Free;
    Result := nil;
    Need(RenameFile(LStage, LFinal), 'Could not publish prepared range');
    LStage := '';
    LProgress.Callback := nil;
    Result := OpenCached(LFinal, LRecipeHash, LRecipe, LFrames, LProgress);
  finally
    if LStage <> '' then
    begin
      DeleteFile(LStage + PathDelim + 'audio.wav');
      DeleteFile(LStage + PathDelim + 'receipt.json');
      RemoveDir(LStage);
    end;
    LProgress.Free;
    LRecipe.Free;
  end;
end;

end.
