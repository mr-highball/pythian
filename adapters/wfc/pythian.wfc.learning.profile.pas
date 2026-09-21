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

unit pythian.wfc.learning.profile;

{$mode delphi}
{$H+}

interface

uses
  fpjson,
  pythian.analysis,
  pythian.analysis.journal,
  pythian.learning,
  pythian.learning.selection,
  pythian.learning.context,
  wfc_sequence;

const
  MaximumJournalProfileBytes = 16 * 1024 * 1024;

type
  TJournalProfileContribution = record
    ProfileSha256: String;
    ModelSha256: String;
    Weight: Integer;
  end;
  TJournalProfileContributions = array of TJournalProfileContribution;

  TJournalProfileSource = record
    Name: UTF8String;
    Binding: TFeatureJournalBinding;
    CacheSha256: String;
    FirstFeature: Int64;
    FeatureCount: Int64;
    Multiplicity: Integer;
  end;

  { Owns a detached palette, candidate pool and actual companion model.
    Loads the current journal report/model pair without source/cache reads or
    learning. Checks binding digests, model/sample geometry and candidate extents.
    This establishes internal consistency, not proof of claimed measurements.
    Callers verify explicit source bytes before rendering. Accessors are borrowed. }
  TJournalModelProfile = class
  private
    FPalette: TAcousticPalette;
    FPool: TJournalCandidatePool;
    FContexts: TJournalContextPool;
    FModel: TWfcSequenceModel;
    FSources: array of TJournalProfileSource;
    FOptions: TAnalysisOptions;
    FSampleRate: Integer;
    FChannels: Integer;
    FVocabularySha256: String;
    FModelSha256: String;
    FReportText: UTF8String;
    FModelText: UTF8String;
    FLineage: TJournalProfileContributions;
    function GetSourceCount: Integer;
    procedure ReadContexts(const ARoot: TJSONObject);
  public
    constructor Create(const AReportText, AModelText: UTF8String);
    destructor Destroy; override;
    function SourceAt(const AIndex: Integer): TJournalProfileSource;
    function CopyTrainingLineage: TJournalProfileContributions;
    function EncodeReport: UTF8String;
    function EncodeModel: UTF8String;
    { Returns a detached profile carrying contexts in the current report contract.
      Requires exact vocabulary and source/range bindings; no model retraining. }
    function WithContexts(const AContexts: TJournalContextPool): TJournalModelProfile;
    { Exact ordered palette/timebase and companion order/boundary compatibility.
      This does not merge models or establish semantic musical compatibility. }
    procedure RequireCompatible(const AOther: TJournalModelProfile);
    property Palette: TAcousticPalette read FPalette;
    property Pool: TJournalCandidatePool read FPool;
    property Contexts: TJournalContextPool read FContexts;
    property Model: TWfcSequenceModel read FModel;
    property Options: TAnalysisOptions read FOptions;
    property SampleRate: Integer read FSampleRate;
    property Channels: Integer read FChannels;
    property SourceCount: Integer read GetSourceCount;
    property VocabularySha256: String read FVocabularySha256;
    property ModelSha256: String read FModelSha256;
  end;

{ Caller owns the JSON object. Context source indices refer to the profile's
  existing source bindings; no separate file format or historical reader. }
function JournalContextJson(const AContexts: TJournalContextPool): TJSONObject;

implementation

uses
  SysUtils,
  Math,
  jsonparser,
  pythian.audio,
  pythian.corpus,
  pythian.hash,
  pythian.learning.binding,
  pythian.learning.journal,
  pythian.wfc.learning,
  wfc_model,
  wfc_sequence_text;

procedure CheckJsonEnvelope(const AText: UTF8String);
var
  LIndex: Integer;
  LDepth: Integer;
  LPunctuation: Integer;
  LString: Boolean;
  LEscaped: Boolean;
begin
  LDepth := 0;
  LPunctuation := 0;
  LString := False;
  LEscaped := False;
  for LIndex := 1 to Length(AText) do
  begin
    if LString then
    begin
      if LEscaped then
      begin
        LEscaped := False;
      end
      else if AText[LIndex] = '\' then
      begin
        LEscaped := True;
      end
      else if AText[LIndex] = '"' then
      begin
        LString := False;
      end;
      Continue;
    end;
    case AText[LIndex] of
      '"':
        begin
          LString := True;
        end;
      '{', '[':
        begin
          Inc(LDepth);
        end;
      '}', ']':
        begin
          Dec(LDepth);
        end;
    end;
    if AText[LIndex] in ['{', '}', '[', ']', ':', ','] then
    begin
      Inc(LPunctuation);
    end;
    if (LDepth < 0) or (LDepth > 8) or (LPunctuation > 1000000) then
    begin
      raise EAudio.Create('Journal profile JSON exceeds nesting or structure budget');
    end;
  end;
  if LString or (LDepth <> 0) then
  begin
    raise EAudio.Create('Journal profile JSON has an incomplete container or string');
  end;
end;

function ObjectValue(const AData: TJSONData): TJSONObject;
var
  LIndex: Integer;
  LOther: Integer;
begin
  if (AData = nil) or (AData.JSONType <> jtObject) or (AData.Count > 64) then
  begin
    raise EAudio.Create('Journal profile requires a bounded JSON object');
  end;
  Result := TJSONObject(AData);
  for LIndex := 0 to Result.Count - 1 do
  begin
    for LOther := 0 to LIndex - 1 do
    begin
      if Result.Names[LIndex] = Result.Names[LOther] then
      begin
        raise EAudio.Create('Duplicate journal profile member');
      end;
    end;
  end;
end;

function Member(const AObject: TJSONObject; const AName: String;
  const AType: TJSONType): TJSONData;
begin
  Result := AObject.Find(AName);
  if (Result = nil) or (Result.JSONType <> AType) then
  begin
    raise EAudio.Create('Missing or invalid journal profile member: ' + AName);
  end;
end;

function IntegerValue(const AObject: TJSONObject; const AName: String;
  const AMinimum, AMaximum: Int64): Int64;
begin
  if not TryStrToInt64(Member(AObject, AName, jtNumber).AsJSON, Result) or
    (Result < AMinimum) or (Result > AMaximum) then
  begin
    raise EAudio.Create('Journal profile integer out of range: ' + AName);
  end;
end;

function RealValue(const AData: TJSONData): Double;
begin
  if (AData = nil) or (AData.JSONType <> jtNumber) then
  begin
    raise EAudio.Create('Journal profile real value required');
  end;
  Result := AData.AsFloat;
  RequireFinite(Result, 'Journal profile real');
end;

function TextValue(const AObject: TJSONObject; const AName: String): UTF8String;
begin
  Result := Member(AObject, AName, jtString).AsString;
  ValidateCorpusText(Result);
end;

function DigestValue(const AObject: TJSONObject; const AName: String): String;
var
  LIndex: Integer;
begin
  Result := TextValue(AObject, AName);
  if Length(Result) <> 64 then
  begin
    raise EAudio.Create('Journal profile digest length invalid');
  end;
  for LIndex := 1 to Length(Result) do
  begin
    if not (Result[LIndex] in ['0'..'9', 'a'..'f']) then
    begin
      raise EAudio.Create('Journal profile digest must be lowercase hexadecimal');
    end;
  end;
end;

function ReadContributions(const ARoot: TJSONObject;
  const AName: String; const AMaximum: Integer): TJournalProfileContributions;
var
  LArray: TJSONArray;
  LRow: TJSONObject;
  LIndex: Integer;
  LOther: Integer;
begin
  Result := nil;
  LArray := TJSONArray(Member(ARoot, AName, jtArray));
  if (LArray.Count < 1) or (LArray.Count > AMaximum) then
  begin
    raise EAudio.Create('Journal profile lineage exceeds entry budget');
  end;
  SetLength(Result, LArray.Count);
  for LIndex := 0 to High(Result) do
  begin
    LRow := ObjectValue(LArray.Items[LIndex]);
    Result[LIndex].ProfileSha256 := DigestValue(LRow, 'profile_sha256');
    Result[LIndex].ModelSha256 := DigestValue(LRow, 'model_sha256');
    Result[LIndex].Weight := IntegerValue(LRow, 'weight', 1, 4096);
    for LOther := 0 to LIndex - 1 do
    begin
      if Result[LOther].ProfileSha256 = Result[LIndex].ProfileSha256 then
      begin
        raise EAudio.Create('Journal profile lineage has duplicate identities');
      end;
    end;
  end;
end;

constructor TJournalModelProfile.Create(const AReportText, AModelText: UTF8String);
var
  LData: TJSONData;
  LRoot: TJSONObject;
  LRow: TJSONObject;
  LArray: TJSONArray;
  LCentersJson: TJSONArray;
  LCenters: TAcousticVectors;
  LCandidates: TJournalRepresentatives;
  LBytes: TAudioBytes;
  LSource: TJournalProfileSource;
  LOtherSource: TJournalProfileSource;
  LCandidate: TJournalRepresentative;
  LIndex: Integer;
  LOther: Integer;
  LComponent: Integer;
  LSourceIndex: Integer;
  LSlot: Integer;
  LToken: Integer;
  LBins: Integer;
  LSample: Integer;
  LReplica: Integer;
  LTotalFeatures: Int64;
  LRaw: Int64;
  LWeighted: Int64;
  LSamples: Integer;
  LFoundTokens: array[0..MaximumAcousticVocabulary - 1] of Boolean;
  LParents: TJournalProfileContributions;
begin
  inherited Create;
  if (Length(AReportText) < 1) or (Length(AReportText) > MaximumJournalProfileBytes) or
    (Length(AModelText) < 1) or (Length(AModelText) > MaximumJournalProfileBytes) then
  begin
    raise EAudio.Create('Journal profile/model text exceeds byte budget');
  end;
  CheckJsonEnvelope(AReportText);
  LData := GetJSON(AReportText);
  try
    LRoot := ObjectValue(LData);
    if (TextValue(LRoot, 'contract') <> 'pythian.acoustic.journal-learning') or
      (IntegerValue(LRoot, 'analysis_version', 1, High(Integer)) <> AnalysisVersion) or
      (IntegerValue(LRoot, 'learning_version', 1, High(Integer)) <> AcousticLearningVersion) then
    begin
      raise EAudio.Create('Journal profile measurement contract differs');
    end;
    FSampleRate := IntegerValue(LRoot, 'sample_rate', 1, MaximumSampleRate);
    FChannels := IntegerValue(LRoot, 'channels', 1, 2);
    FOptions.WindowFrames := IntegerValue(LRoot, 'window_frames', 1, 65536);
    FOptions.HopFrames := IntegerValue(LRoot, 'hop_frames', 1, 65536);
    FOptions.SilenceRms := RealValue(Member(LRoot, 'silence_rms', jtNumber));
    LCentersJson := TJSONArray(Member(LRoot, 'palette', jtArray));
    if (LCentersJson.Count < 1) or (LCentersJson.Count > MaximumAcousticVocabulary) then
    begin
      raise EAudio.Create('Journal profile palette size invalid');
    end;
    SetLength(LCenters, LCentersJson.Count);
    for LIndex := 0 to High(LCenters) do
    begin
      if (LCentersJson.Items[LIndex].JSONType <> jtArray) or
        (LCentersJson.Items[LIndex].Count <> Length(TAcousticVector)) then
      begin
        raise EAudio.Create('Journal profile palette vector shape invalid');
      end;
      for LComponent := 0 to High(TAcousticVector) do
      begin
        LCenters[LIndex][LComponent] := RealValue(LCentersJson.Items[LIndex].Items[LComponent]);
      end;
    end;
    FPalette := TAcousticPalette.CreateFromCenters(LCenters);
    FVocabularySha256 := AcousticVocabularySha256(FPalette, FOptions, FSampleRate, FChannels);
    if FVocabularySha256 <> DigestValue(LRoot, 'vocabulary_sha256') then
    begin
      raise EAudio.Create('Journal profile vocabulary/timebase binding differs');
    end;
    SetLength(LBytes, Length(AModelText));
    Move(AModelText[1], LBytes[0], Length(LBytes));
    FModelSha256 := Sha256Bytes(LBytes);
    if (FModelSha256 <> DigestValue(LRoot, 'model_sha256')) or
      (AcousticModelBindingSha256(FVocabularySha256, FModelSha256) <>
        DigestValue(LRoot, 'model_binding_sha256')) then
    begin
      raise EAudio.Create('Journal profile serialized model binding differs');
    end;
    FModel := DecodeWfcSequenceText(AModelText);
    if (FModel.Order < 1) or (FModel.Order > 4) or (FModel.Boundary <> wmbOpen) or
      (FModel.Order <> IntegerValue(LRoot, 'order', 1, 4)) or
      (FModel.StateCount <> IntegerValue(LRoot, 'wfc_states', 1, 1024)) then
    begin
      raise EAudio.Create('Journal profile companion model shape differs');
    end;
    LArray := TJSONArray(Member(LRoot, 'sources', jtArray));
    if (LArray.Count < 1) or (LArray.Count > MaximumCorpusSources) then
    begin
      raise EAudio.Create('Journal profile requires 1..32 declared sources');
    end;
    SetLength(FSources, LArray.Count);
    LRaw := 0;
    LWeighted := 0;
    LSamples := 0;
    for LIndex := 0 to High(FSources) do
    begin
      LRow := ObjectValue(LArray.Items[LIndex]);
      LSource := Default(TJournalProfileSource);
      LSource.Name := TextValue(LRow, 'source');
      if LSource.Name = '' then
      begin
        raise EAudio.Create('Journal profile source name required');
      end;
      LSource.Binding.SourceSha256 := DigestValue(LRow, 'source_sha256');
      LSource.CacheSha256 := DigestValue(LRow, 'cache_sha256');
      LSource.Binding.SampleRate := FSampleRate;
      LSource.Binding.Channels := FChannels;
      LSource.Binding.Options := FOptions;
      LSource.Binding.FrameCount := IntegerValue(LRow, 'source_frames', 1, High(Int64));
      LTotalFeatures := (LSource.Binding.FrameCount - 1) div FOptions.HopFrames + 1;
      LSource.FirstFeature := IntegerValue(LRow, 'first_feature', 0, LTotalFeatures - 1);
      LSource.FeatureCount := IntegerValue(LRow, 'observations', 1,
        LTotalFeatures - LSource.FirstFeature);
      LSource.Multiplicity := IntegerValue(LRow, 'multiplicity', 1, 4096);
      if (LSource.FeatureCount > (High(Integer) - LWeighted) div LSource.Multiplicity) or
        (LSource.Multiplicity > 4096 - LSamples) then
      begin
        raise EAudio.Create('Journal profile training counts exceed companion limits');
      end;
      Inc(LRaw, LSource.FeatureCount);
      Inc(LWeighted, LSource.FeatureCount * LSource.Multiplicity);
      Inc(LSamples, LSource.Multiplicity);
      for LOther := 0 to LIndex - 1 do
      begin
        LOtherSource := FSources[LOther];
        if LSource.Binding.SourceSha256 = LOtherSource.Binding.SourceSha256 then
        begin
          if (LSource.Binding.FrameCount <> LOtherSource.Binding.FrameCount) or
            ((LSource.FirstFeature < LOtherSource.FirstFeature + LOtherSource.FeatureCount) and
            (LOtherSource.FirstFeature < LSource.FirstFeature + LSource.FeatureCount)) then
          begin
            raise EAudio.Create('Journal profile source geometry conflicts or ranges overlap');
          end;
        end;
      end;
      FSources[LIndex] := LSource;
    end;
    if (LRaw <> IntegerValue(LRoot, 'raw_observations', 1, High(Integer))) or
      (LWeighted <> IntegerValue(LRoot, 'weighted_observations', 1, High(Integer))) or
      (LWeighted <> IntegerValue(LRoot, 'wfc_observations', 1, High(Integer))) or
      (LWeighted <> FModel.ObservationCount) or (LSamples <> FModel.SampleCount) or
      (LSamples <> IntegerValue(LRoot, 'wfc_samples', 1, 4096)) then
    begin
      raise EAudio.Create('Journal profile observation/sample counts differ');
    end;
    LSample := 0;
    for LIndex := 0 to High(FSources) do
    begin
      for LReplica := 1 to FSources[LIndex].Multiplicity do
      begin
        if FModel.SampleLengthAt(LSample) <> FSources[LIndex].FeatureCount then
        begin
          raise EAudio.Create('Journal profile recording boundary differs from model');
        end;
        Inc(LSample);
      end;
    end;
    LBins := IntegerValue(LRoot, 'candidate_bins_per_segment', 1, 32);
    SetLength(LCandidates, FPalette.Count * SourceCount * LBins);
    FillChar(LFoundTokens, SizeOf(LFoundTokens), 0);
    LArray := TJSONArray(Member(LRoot, 'candidates', jtArray));
    if LArray.Count > Length(LCandidates) then
    begin
      raise EAudio.Create('Journal profile candidate count exceeds slot budget');
    end;
    for LIndex := 0 to LArray.Count - 1 do
    begin
      LRow := ObjectValue(LArray.Items[LIndex]);
      LSlot := IntegerValue(LRow, 'slot', 0, High(LCandidates));
      LSourceIndex := IntegerValue(LRow, 'source_index', 0, SourceCount - 1);
      LSource := FSources[LSourceIndex];
      LToken := IntegerValue(LRow, 'token', 0, FPalette.Count - 1);
      LCandidate := Default(TJournalRepresentative);
      LCandidate.Found := True;
      LCandidate.SegmentIndex := LSourceIndex;
      LCandidate.FeatureIndex := IntegerValue(LRow, 'feature_index',
        LSource.FirstFeature, LSource.FirstFeature + LSource.FeatureCount - 1);
      LCandidate.SourceFrame := IntegerValue(LRow, 'source_frame', 0,
        LSource.Binding.FrameCount - 1);
      LCandidate.ValidFrames := IntegerValue(LRow, 'valid_frames', 1, FOptions.WindowFrames);
      LCandidate.Distance := RealValue(Member(LRow, 'center_distance', jtNumber));
      if LCandidates[LSlot].Found or
        (LToken <> LSlot div (SourceCount * LBins)) or
        (LCandidate.SourceFrame mod FOptions.HopFrames <> 0) or
        (LCandidate.FeatureIndex <> LCandidate.SourceFrame div FOptions.HopFrames) or
        (LCandidate.ValidFrames <> Min(Int64(FOptions.WindowFrames),
          LSource.Binding.FrameCount - LCandidate.SourceFrame)) or
        ((LCandidate.FeatureIndex - LSource.FirstFeature) div
          ((LSource.FeatureCount - 1) div LBins + 1) <> LSlot mod LBins) then
      begin
        raise EAudio.Create('Journal profile candidate grid/bin/extent is inconsistent');
      end;
      LCandidates[LSlot] := LCandidate;
      LFoundTokens[LToken] := True;
    end;
    FPool := TJournalCandidatePool.CreateFromCandidates(FPalette.Count, SourceCount, LBins, LCandidates);
    ReadContexts(LRoot);
    for LIndex := 0 to FModel.PublicTokenCount - 1 do
    begin
      LToken := AcousticTokenIndex(FModel.PublicTokenAt(LIndex));
      if (LToken < 0) or (LToken >= FPalette.Count) or not LFoundTokens[LToken] then
      begin
        raise EAudio.Create('Journal profile model token has no bound candidate');
      end;
    end;
    if (LRoot.Find('training_lineage') = nil) <> (LRoot.Find('blend_parents') = nil) then
    begin
      raise EAudio.Create('Journal blend requires parents and training lineage together');
    end;
    if LRoot.Find('training_lineage') <> nil then
    begin
      FLineage := ReadContributions(LRoot, 'training_lineage', 64);
      LParents := ReadContributions(LRoot, 'blend_parents', 2);
      LSamples := 0;
      for LIndex := 0 to High(FLineage) do
      begin
        Inc(LSamples, FLineage[LIndex].Weight);
      end;
      if (Length(LParents) = 0) or (LSamples > FModel.SampleCount) then
      begin
        raise EAudio.Create('Journal blend lineage exceeds sample evidence');
      end;
    end
    else
    begin
      SetLength(LBytes, Length(AReportText));
      Move(AReportText[1], LBytes[0], Length(LBytes));
      SetLength(FLineage, 1);
      FLineage[0].ProfileSha256 := Sha256Bytes(LBytes);
      FLineage[0].ModelSha256 := FModelSha256;
      FLineage[0].Weight := 1;
    end;
    FReportText := AReportText;
    FModelText := AModelText;
  finally
    LData.Free;
  end;
end;

function TJournalModelProfile.CopyTrainingLineage: TJournalProfileContributions;
begin
  Result := Copy(FLineage);
end;

function JournalContextJson(const AContexts: TJournalContextPool): TJSONObject;
var
  LArray: TJSONArray;
  LRow: TJSONObject;
  LTokens: TJSONArray;
  LDistances: TJSONArray;
  LWindow: TJournalContextWindow;
  LIndex: Integer;
  LOffset: Integer;
begin
  if (AContexts = nil) or (AContexts.Count < 1) then
  begin
    raise EAudio.Create('Context serialization requires a nonempty pool');
  end;
  Result := TJSONObject.Create;
  try
    Result.Add('vocabulary_sha256', AContexts.VocabularySha256);
    LArray := TJSONArray.Create;
    Result.Add('contexts', LArray);
    for LIndex := 0 to AContexts.Count - 1 do
    begin
      LWindow := AContexts.WindowAt(LIndex, 0);
      LRow := TJSONObject.Create;
      LArray.Add(LRow);
      LRow.Add('source_index', LWindow.Candidate.SegmentIndex);
      LRow.Add('first_feature', LWindow.Candidate.FeatureIndex);
      LTokens := TJSONArray.Create;
      LDistances := TJSONArray.Create;
      LRow.Add('tokens', LTokens);
      LRow.Add('center_distances', LDistances);
      for LOffset := 0 to AContexts.ContextLength(LIndex) - 1 do
      begin
        LWindow := AContexts.WindowAt(LIndex, LOffset);
        LTokens.Add(LWindow.Token);
        LDistances.Add(LWindow.Candidate.Distance);
      end;
    end;
  except
    Result.Free;
    raise;
  end;
end;

procedure TJournalModelProfile.ReadContexts(const ARoot: TJSONObject);
var
  LObject: TJSONObject;
  LRow: TJSONObject;
  LArray: TJSONArray;
  LTokens: TJSONArray;
  LDistances: TJSONArray;
  LSources: TJournalContextSources;
  LContexts: TJournalContextSets;
  LSource: TJournalProfileSource;
  LWindow: TJournalContextWindow;
  LIndex: Integer;
  LOffset: Integer;
  LSourceIndex: Integer;
  LCount: Integer;
  LFirst: Int64;
  LToken: Int64;
begin
  if ARoot.Find('source_contexts') = nil then
  begin
    Exit;
  end;
  LObject := ObjectValue(ARoot.Find('source_contexts'));
  if DigestValue(LObject, 'vocabulary_sha256') <> FVocabularySha256 then
  begin
    raise EAudio.Create('Saved source context vocabulary binding differs');
  end;
  LArray := TJSONArray(Member(LObject, 'contexts', jtArray));
  if (LArray.Count < 1) or (LArray.Count > MaximumJournalContexts) then
  begin
    raise EAudio.Create('Saved source context count exceeds bounds');
  end;
  SetLength(LSources, SourceCount);
  for LIndex := 0 to High(LSources) do
  begin
    LSources[LIndex].Binding := FSources[LIndex].Binding;
    LSources[LIndex].FirstFeature := FSources[LIndex].FirstFeature;
    LSources[LIndex].FeatureCount := FSources[LIndex].FeatureCount;
  end;
  SetLength(LContexts, LArray.Count);
  LCount := 0;
  for LIndex := 0 to High(LContexts) do
  begin
    LRow := ObjectValue(LArray.Items[LIndex]);
    LSourceIndex := IntegerValue(LRow, 'source_index', 0, SourceCount - 1);
    LSource := FSources[LSourceIndex];
    LTokens := TJSONArray(Member(LRow, 'tokens', jtArray));
    LDistances := TJSONArray(Member(LRow, 'center_distances', jtArray));
    if (LTokens.Count < 1) or (LTokens.Count > MaximumJournalContextGrains) or
      (LTokens.Count <> LDistances.Count) or (LTokens.Count > LSource.FeatureCount) or
      (LTokens.Count > MaximumJournalContextWindows - LCount) then
    begin
      raise EAudio.Create('Saved context window arrays or source range invalid');
    end;
    Inc(LCount, LTokens.Count);
    LFirst := IntegerValue(LRow, 'first_feature', LSource.FirstFeature,
      LSource.FirstFeature + LSource.FeatureCount - LTokens.Count);
    SetLength(LContexts[LIndex], LTokens.Count);
    for LOffset := 0 to LTokens.Count - 1 do
    begin
      if (LTokens.Items[LOffset].JSONType <> jtNumber) or
        not TryStrToInt64(LTokens.Items[LOffset].AsJSON, LToken) or
        (LToken < 0) or (LToken >= FPalette.Count) then
      begin
        raise EAudio.Create('Saved context token is outside the vocabulary');
      end;
      LWindow := Default(TJournalContextWindow);
      LWindow.Token := LToken;
      LWindow.Candidate.Found := True;
      LWindow.Candidate.SegmentIndex := LSourceIndex;
      LWindow.Candidate.FeatureIndex := LFirst + LOffset;
      LWindow.Candidate.SourceFrame := LWindow.Candidate.FeatureIndex * FOptions.HopFrames;
      LWindow.Candidate.ValidFrames := Min(Int64(FOptions.WindowFrames),
        LSource.Binding.FrameCount - LWindow.Candidate.SourceFrame);
      LWindow.Candidate.Distance := RealValue(LDistances.Items[LOffset]);
      LContexts[LIndex][LOffset] := LWindow;
    end;
  end;
  FContexts := TJournalContextPool.CreateFromContexts(FPalette, FPool, LSources, LContexts);
end;

function TJournalModelProfile.WithContexts(const AContexts: TJournalContextPool): TJournalModelProfile;
var
  LRoot: TJSONObject;
  LSource: TJournalContextSource;
  LIndex: Integer;
begin
  Result := nil;
  if (AContexts = nil) or (AContexts.VocabularySha256 <> FVocabularySha256) or
    (AContexts.SourceCount <> SourceCount) then
  begin
    raise EAudio.Create('Attached contexts require exact vocabulary and source bindings');
  end;
  for LIndex := 0 to SourceCount - 1 do
  begin
    LSource := AContexts.SourceAt(LIndex);
    if (LSource.Binding.SourceSha256 <> FSources[LIndex].Binding.SourceSha256) or
      (LSource.Binding.FrameCount <> FSources[LIndex].Binding.FrameCount) or
      (LSource.FirstFeature <> FSources[LIndex].FirstFeature) or
      (LSource.FeatureCount <> FSources[LIndex].FeatureCount) then
    begin
      raise EAudio.Create('Attached contexts have different source identities or ranges');
    end;
  end;
  LRoot := TJSONObject(GetJSON(FReportText));
  try
    LRoot.Delete('source_contexts');
    LRoot.Add('source_contexts', JournalContextJson(AContexts));
    Result := TJournalModelProfile.Create(LRoot.FormatJSON, FModelText);
  finally
    LRoot.Free;
  end;
end;

function TJournalModelProfile.EncodeReport: UTF8String;
begin
  Result := FReportText;
end;

function TJournalModelProfile.EncodeModel: UTF8String;
begin
  Result := FModelText;
end;

destructor TJournalModelProfile.Destroy;
begin
  FContexts.Free;
  FModel.Free;
  FPool.Free;
  FPalette.Free;
  inherited Destroy;
end;

function TJournalModelProfile.GetSourceCount: Integer;
begin
  Result := Length(FSources);
end;

function TJournalModelProfile.SourceAt(const AIndex: Integer): TJournalProfileSource;
begin
  if (AIndex < 0) or (AIndex >= SourceCount) then
  begin
    raise EAudio.Create('Journal profile source index out of bounds');
  end;
  Result := FSources[AIndex];
end;

procedure TJournalModelProfile.RequireCompatible(const AOther: TJournalModelProfile);
begin
  if (AOther = nil) or (FVocabularySha256 <> AOther.FVocabularySha256) or
    (FModel.Order <> AOther.FModel.Order) or (FModel.Boundary <> AOther.FModel.Boundary) then
  begin
    raise EAudio.Create('Journal profiles require identical vocabulary/timebase and model order');
  end;
end;

end.
