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
unit pythian.corpus;

{$mode delphi}
{$H+}

interface

uses
  pythian.audio,
  pythian.analysis,
  pythian.learning,
  pythian.granular;

const
  AcousticCorpusVersion = 1;
  MaximumCorpusSources = 32;
  MaximumCorpusTextBytes = 4096;

type
  TAcousticSourceInfo = record
    Name: UTF8String;
    Sha256: String;
    Provenance: UTF8String;
    SampleRate: Integer;
    Channels: Integer;
    FrameCount: Integer;
  end;
  TAcousticSourceInfos = array of TAcousticSourceInfo;
  TAcousticRecording = record
    Info: TAcousticSourceInfo;
    Features: TAudioFeatures;
    Tokens: TAcousticIndices;
  end;
  TAcousticRecordings = array of TAcousticRecording;

  { Immutable measured corpus. Audio remains external and is identified by
    exact-file SHA256. All recordings share a format, options and palette. }
  TAcousticCorpusData = class
  strict private
    FOptions: TAnalysisOptions;
    FPalette: TAcousticPalette;
    FRecordings: TAcousticRecordings;
    FRepresentatives: TAudioGrains;
    FFeatureCount: Integer;
    function GetSourceCount: Integer;
    function GetPaletteCount: Integer;
  public
    constructor Create(const AOptions: TAnalysisOptions;
      const ACenters: TAcousticVectors; const ARecordings: TAcousticRecordings);
    destructor Destroy; override;
    function CopyPalette: TAcousticPalette;
    function SourceInfoAt(const AIndex: Integer): TAcousticSourceInfo;
    function RecordingAt(const AIndex: Integer): TAcousticRecording;
    function PlanGrains(const AIndices: TAcousticIndices): TAudioGrains;
    property Options: TAnalysisOptions read FOptions;
    property SourceCount: Integer read GetSourceCount;
    property PaletteCount: Integer read GetPaletteCount;
    property FeatureCount: Integer read FFeatureCount;
  end;

procedure ValidateCorpusText(const AText: UTF8String);
procedure ValidateSourceInfo(const AInfo: TAcousticSourceInfo);
function TrainAcousticCorpus(const ASources: TAudioSources;
  const AInfo: TAcousticSourceInfos; const AOptions: TAnalysisOptions;
  const AMaximumTokens: Integer = 16): TAcousticCorpusData;

implementation

uses
  Math,
  SysUtils;

procedure ValidateCorpusText(const AText: UTF8String);
begin
  if (Length(AText) > MaximumCorpusTextBytes) or (Pos(#0, AText) <> 0) or
    (UTF8Encode(UTF8Decode(AText)) <> AText) then
  begin
    raise EAudio.Create('Corpus text must be bounded UTF-8 without NUL bytes');
  end;
end;

procedure ValidateSourceInfo(const AInfo: TAcousticSourceInfo);
var
  LIndex: Integer;
begin
  ValidateAudioFormat(AInfo.SampleRate, AInfo.Channels);
  ValidateCorpusText(AInfo.Name);
  ValidateCorpusText(AInfo.Provenance);
  if (AInfo.Name = '') or (Length(AInfo.Sha256) <> 64) or
    (AInfo.FrameCount < 1) or
    (Int64(AInfo.FrameCount) * AInfo.Channels > MaximumClipSamples) then
  begin
    raise EAudio.Create('Invalid corpus source identity or extent');
  end;
  for LIndex := 1 to Length(AInfo.Sha256) do
  begin
    if not (AInfo.Sha256[LIndex] in ['0'..'9', 'a'..'f']) then
    begin
      raise EAudio.Create('Source SHA256 must be lowercase hexadecimal');
    end;
  end;
end;

procedure ValidateFeature(const AFeature: TAudioFeature;
  const AInfo: TAcousticSourceInfo; const AOptions: TAnalysisOptions; const AIndex: Integer);
var
  LSum: Double;
  LIndex: Integer;
begin
  AcousticVector(AFeature);
  RequireFinite(AFeature.Peak, 'Feature peak');
  if (AFeature.StartFrame <> Int64(AIndex) * AOptions.HopFrames) or
    (AFeature.ValidFrames <> Min(AOptions.WindowFrames, AInfo.FrameCount -
      AFeature.StartFrame)) or (AFeature.ValidFrames < 1) or
    (AFeature.Peak < 0) or (AFeature.Peak > MaxSingle) or
    (AFeature.Rms > AFeature.Peak + 1E-9 * Max(1, AFeature.Peak)) or
    (AFeature.CentroidHz > AInfo.SampleRate / 2 + 1E-6) or
    (AFeature.Silent <> (AFeature.Rms <= AOptions.SilenceRms)) then
  begin
    raise EAudio.Create('Invalid persisted feature extent or measurement');
  end;
  LSum := 0;
  for LIndex := 0 to 11 do
  begin
    LSum := LSum + AFeature.Chroma[LIndex];
  end;
  if ((LSum <> 0) and (Abs(LSum - 1) > 1E-9)) or
    (AFeature.Silent and ((LSum <> 0) or (AFeature.CentroidHz <> 0) or
      (AFeature.Flux <> 0))) then
  begin
    raise EAudio.Create('Persisted chroma or silence measurements are inconsistent');
  end;
end;

constructor TAcousticCorpusData.Create(const AOptions: TAnalysisOptions;
  const ACenters: TAcousticVectors; const ARecordings: TAcousticRecordings);
var
  LIndex: Integer;
  LFrame: Integer;
  LOther: Integer;
  LCount: Integer;
  LOffset: Integer;
  LToken: Integer;
  LWork: Int64;
  LTotalWork: Int64;
  LSamples: Int64;
  LFlat: TAudioFeatures;
  LTokens: TAcousticIndices;
  LRepresentatives: TAcousticIndices;
begin
  inherited Create;
  if (Length(ARecordings) < 1) or (Length(ARecordings) > MaximumCorpusSources) then
  begin
    raise EAudio.Create('Corpus requires 1..32 recordings');
  end;
  LTotalWork := 0;
  LSamples := 0;
  for LIndex := 0 to High(ARecordings) do
  begin
    ValidateSourceInfo(ARecordings[LIndex].Info);
    for LOther := 0 to LIndex - 1 do
    begin
      if ARecordings[LIndex].Info.Sha256 = ARecordings[LOther].Info.Sha256 then
      begin
        raise EAudio.Create('Duplicate source hashes would reweight the corpus');
      end;
    end;
    if (ARecordings[LIndex].Info.SampleRate <> ARecordings[0].Info.SampleRate) or
      (ARecordings[LIndex].Info.Channels <> ARecordings[0].Info.Channels) then
    begin
      raise EAudio.Create('Corpus sources must share sample rate and channels');
    end;
    PlanAudioAnalysis(ARecordings[LIndex].Info.FrameCount,
      ARecordings[LIndex].Info.Channels, AOptions, LCount, LWork);
    Inc(LTotalWork, LWork);
    Inc(LSamples, Int64(ARecordings[LIndex].Info.FrameCount) *
      ARecordings[LIndex].Info.Channels);
    if (Length(ARecordings[LIndex].Features) <> LCount) or
      (Length(ARecordings[LIndex].Tokens) <> LCount) or
      (LCount > MaximumAnalysisFrames - FFeatureCount) or
      (LTotalWork > MaximumAnalysisWork) or (LSamples > MaximumClipSamples) then
    begin
      raise EAudio.Create('Corpus measurements or aggregate budgets are invalid');
    end;
    Inc(FFeatureCount, LCount);
  end;
  FOptions := AOptions;
  FPalette := TAcousticPalette.CreateFromCenters(ACenters);
  SetLength(FRecordings, Length(ARecordings));
  SetLength(LFlat, FFeatureCount);
  LOffset := 0;
  for LIndex := 0 to High(ARecordings) do
  begin
    LTokens := FPalette.Encode(ARecordings[LIndex].Features);
    FRecordings[LIndex].Info := ARecordings[LIndex].Info;
    FRecordings[LIndex].Features := Copy(ARecordings[LIndex].Features);
    FRecordings[LIndex].Tokens := Copy(ARecordings[LIndex].Tokens);
    for LFrame := 0 to High(LTokens) do
    begin
      ValidateFeature(ARecordings[LIndex].Features[LFrame],
        ARecordings[LIndex].Info, AOptions, LFrame);
      if LTokens[LFrame] <> ARecordings[LIndex].Tokens[LFrame] then
      begin
        raise EAudio.Create('Persisted tokens disagree with the shared palette');
      end;
      LFlat[LOffset + LFrame] := ARecordings[LIndex].Features[LFrame];
    end;
    Inc(LOffset, Length(LTokens));
  end;
  LRepresentatives := FPalette.RepresentativeFrames(LFlat);
  SetLength(FRepresentatives, FPalette.Count);
  for LToken := 0 to High(LRepresentatives) do
  begin
    FRepresentatives[LToken].SourceIndex := -1;
    if LRepresentatives[LToken] < 0 then
    begin
      Continue;
    end;
    LFrame := LRepresentatives[LToken];
    LIndex := 0;
    while LFrame >= Length(FRecordings[LIndex].Features) do
    begin
      Dec(LFrame, Length(FRecordings[LIndex].Features));
      Inc(LIndex);
    end;
    FRepresentatives[LToken].SourceIndex := LIndex;
    FRepresentatives[LToken].SourceStartFrame :=
      FRecordings[LIndex].Features[LFrame].StartFrame;
    FRepresentatives[LToken].FrameCount :=
      FRecordings[LIndex].Features[LFrame].ValidFrames;
    FRepresentatives[LToken].PlaybackRate := 1;
    FRepresentatives[LToken].Gain := 1;
    FRepresentatives[LToken].Window := gwHann;
  end;
end;

destructor TAcousticCorpusData.Destroy;
begin
  FPalette.Free;
  inherited Destroy;
end;

function TAcousticCorpusData.GetSourceCount: Integer;
begin
  Result := Length(FRecordings);
end;

function TAcousticCorpusData.GetPaletteCount: Integer;
begin
  Result := FPalette.Count;
end;

function TAcousticCorpusData.CopyPalette: TAcousticPalette;
begin
  Result := TAcousticPalette.CreateFromCenters(FPalette.CopyCenters);
end;

function TAcousticCorpusData.SourceInfoAt(const AIndex: Integer): TAcousticSourceInfo;
begin
  if (AIndex < 0) or (AIndex >= SourceCount) then
  begin
    raise EAudio.Create('Corpus source index out of bounds');
  end;
  Result := FRecordings[AIndex].Info;
end;

function TAcousticCorpusData.RecordingAt(const AIndex: Integer): TAcousticRecording;
begin
  Result.Info := SourceInfoAt(AIndex);
  Result.Features := Copy(FRecordings[AIndex].Features);
  Result.Tokens := Copy(FRecordings[AIndex].Tokens);
end;

function TAcousticCorpusData.PlanGrains(const AIndices: TAcousticIndices): TAudioGrains;
var
  LIndex: Integer;
  LToken: Integer;
begin
  if Length(AIndices) > MaximumGrainCount then
  begin
    raise EAudio.Create('Corpus reconstruction exceeds grain count budget');
  end;
  Result := nil;
  SetLength(Result, Length(AIndices));
  for LIndex := 0 to High(AIndices) do
  begin
    LToken := AIndices[LIndex];
    if (LToken < 0) or (LToken >= PaletteCount) then
    begin
      raise EAudio.Create('Corpus reconstruction token is outside palette');
    end;
    if FRepresentatives[LToken].SourceIndex < 0 then
    begin
      raise EAudio.Create('Corpus token has no recorded exemplar');
    end;
    if Int64(LIndex) * FOptions.HopFrames + FRepresentatives[LToken].FrameCount >
      MaximumGrainSamples div FRecordings[0].Info.Channels then
    begin
      raise EAudio.Create('Corpus reconstruction exceeds sample budget');
    end;
    Result[LIndex] := FRepresentatives[LToken];
    Result[LIndex].OutputStartFrame := LIndex * FOptions.HopFrames;
  end;
end;

function TrainAcousticCorpus(const ASources: TAudioSources;
  const AInfo: TAcousticSourceInfos; const AOptions: TAnalysisOptions;
  const AMaximumTokens: Integer): TAcousticCorpusData;
var
  LRecordings: TAcousticRecordings;
  LFlat: TAudioFeatures;
  LPalette: TAcousticPalette;
  LIndex: Integer;
  LFrame: Integer;
  LTotal: Integer;
  LOther: Integer;
  LCount: Integer;
  LOffset: Integer;
  LSamples: Int64;
  LWork: Int64;
  LTotalWork: Int64;
begin
  if (Length(ASources) < 1) or (Length(ASources) > MaximumCorpusSources) or
    (Length(ASources) <> Length(AInfo)) then
  begin
    raise EAudio.Create('Sources and identities must have matching bounded lengths');
  end;
  LTotal := 0;
  LSamples := 0;
  LTotalWork := 0;
  for LIndex := 0 to High(ASources) do
  begin
    ValidateSourceInfo(AInfo[LIndex]);
    for LOther := 0 to LIndex - 1 do
    begin
      if AInfo[LIndex].Sha256 = AInfo[LOther].Sha256 then
      begin
        raise EAudio.Create('Duplicate source hashes would reweight the corpus');
      end;
    end;
    if (ASources[LIndex] = nil) or
      (ASources[LIndex].SampleRate <> AInfo[LIndex].SampleRate) or
      (ASources[LIndex].Channels <> AInfo[LIndex].Channels) or
      (ASources[LIndex].FrameCount <> AInfo[LIndex].FrameCount) or
      (AInfo[LIndex].SampleRate <> AInfo[0].SampleRate) or
      (AInfo[LIndex].Channels <> AInfo[0].Channels) then
    begin
      raise EAudio.Create('Source clips disagree with corpus identities or format');
    end;
    PlanAudioAnalysis(AInfo[LIndex].FrameCount, AInfo[LIndex].Channels,
      AOptions, LCount, LWork);
    Inc(LTotal, LCount);
    Inc(LTotalWork, LWork);
    Inc(LSamples, Int64(AInfo[LIndex].FrameCount) * AInfo[LIndex].Channels);
  end;
  if (LTotal > MaximumAnalysisFrames) or (LTotalWork > MaximumAnalysisWork) or
    (LSamples > MaximumClipSamples) then
  begin
    raise EAudio.Create('Training corpus exceeds aggregate frame, sample or FFT budget');
  end;
  SetLength(LRecordings, Length(ASources));
  SetLength(LFlat, LTotal);
  LOffset := 0;
  for LIndex := 0 to High(ASources) do
  begin
    LRecordings[LIndex].Info := AInfo[LIndex];
    LRecordings[LIndex].Features := AnalyzeAudio(ASources[LIndex], AOptions);
    for LFrame := 0 to High(LRecordings[LIndex].Features) do
    begin
      LFlat[LOffset + LFrame] := LRecordings[LIndex].Features[LFrame];
    end;
    Inc(LOffset, Length(LRecordings[LIndex].Features));
  end;
  LPalette := TAcousticPalette.Create(LFlat, AMaximumTokens);
  try
    for LIndex := 0 to High(LRecordings) do
    begin
      LRecordings[LIndex].Tokens := LPalette.Encode(LRecordings[LIndex].Features);
    end;
    Result := TAcousticCorpusData.Create(AOptions, LPalette.CopyCenters, LRecordings);
  finally
    LPalette.Free;
  end;
end;

end.
