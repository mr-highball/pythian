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
unit pythian.wfc.event.corpus;

{$mode delphi}
{$H+}

interface

uses
  pythian.corpus, pythian.learning, pythian.passage, pythian.wfc.events,
  wfc_sequence, wfc_model;

const
  RecordedEventLearningVersion = 1;
  MaximumRecordedEvents = 65536;
  MaximumEventSelectionWork = 16777216;

type
  TEventOnsetFlags = array of Boolean;
  TRecordedEventInput = record
    SourceIndex: Integer;
    Bounds: TPassageBounds;
    RunIndices: TPassageIndices;
    StartsAtOnset: TEventOnsetFlags;
  end;
  TRecordedEventInputs = array of TRecordedEventInput;
  TRecordedEventMember = record
    Passage: TRecordedPassage;
    IntervalIndex: Integer;
    RunIndex: Integer;
    Token: String;
  end;
  TRecordedEventMembers = array of TRecordedEventMember;

  { Owns a shared event palette, actual WFC model and detached source members.
    Inputs name each source at most once; runs retain their boundaries. The
    measured corpus is borrowed only during construction. Excluded intervals
    train neither palette nor model and cannot be selected for reconstruction.
    Model and Palette accessors return borrowed immutable definitions. }
  TRecordedEventLearning = class
  strict private
    FPalette: TAcousticPalette;
    FModel: TWfcSequenceModel;
    FMembers: TRecordedEventMembers;
    FInfo: TAcousticSourceInfos;
    FInputs: TRecordedEventInputs;
    FQuantumFrames: Integer;
    FRunCount: Integer;
    function GetMemberCount: Integer;
    function GetSourceCount: Integer;
    procedure Initialize(const ACorpus: TAcousticCorpusData;
      const AInputs: TRecordedEventInputs; const AQuantumFrames, APaletteSize, AOrder: Integer;
      const ACenters: TAcousticVectors; const AModel: TWfcSequenceModel);
  public
    constructor Create(const ACorpus: TAcousticCorpusData;
      const AInputs: TRecordedEventInputs; const AQuantumFrames: Integer;
      const APaletteSize: Integer = 8; const AOrder: Integer = 2);
    { Reconstruct measured members against exact supplied centers, independently
      admit model counts, then clone the model. No clustering or WFC learning. }
    constructor CreateFromModel(const ACorpus: TAcousticCorpusData;
      const AInputs: TRecordedEventInputs; const AQuantumFrames: Integer;
      const ACenters: TAcousticVectors; const AModel: TWfcSequenceModel);
    destructor Destroy; override;
    function MemberAt(const AIndex: Integer): TRecordedEventMember;
    function SourceInfoAt(const AIndex: Integer): TAcousticSourceInfo;
    function CopyInputs: TRecordedEventInputs;
    { Retain a matching source neighbor within the same admitted run, otherwise
      choose a matching member deterministically. No musical quality inference. }
    function SelectMembers(const ATokens: TWfcModelTokens;
      const ASeed: Cardinal): TPassageIndices;
    property Palette: TAcousticPalette read FPalette;
    property Model: TWfcSequenceModel read FModel;
    property QuantumFrames: Integer read FQuantumFrames;
    property RunCount: Integer read FRunCount;
    property MemberCount: Integer read GetMemberCount;
    property SourceCount: Integer read GetSourceCount;
  end;

implementation

uses
  pythian.audio, pythian.analysis, wfc_sequence_text;

type
  TFeatureSets = array of TAudioFeatures;

constructor TRecordedEventLearning.Create(const ACorpus: TAcousticCorpusData;
  const AInputs: TRecordedEventInputs; const AQuantumFrames: Integer;
  const APaletteSize: Integer; const AOrder: Integer);
begin
  inherited Create;
  Initialize(ACorpus, AInputs, AQuantumFrames, APaletteSize, AOrder, nil, nil);
end;

constructor TRecordedEventLearning.CreateFromModel(const ACorpus: TAcousticCorpusData;
  const AInputs: TRecordedEventInputs; const AQuantumFrames: Integer;
  const ACenters: TAcousticVectors; const AModel: TWfcSequenceModel);
begin
  inherited Create;
  if AModel = nil then
  begin
    raise EAudio.Create('Saved event learning requires a model');
  end;
  Initialize(ACorpus, AInputs, AQuantumFrames, Length(ACenters), AModel.Order,
    ACenters, AModel);
end;

procedure TRecordedEventLearning.Initialize(const ACorpus: TAcousticCorpusData;
  const AInputs: TRecordedEventInputs; const AQuantumFrames, APaletteSize, AOrder: Integer;
  const ACenters: TAcousticVectors; const AModel: TWfcSequenceModel);
var
  LFeatures: TFeatureSets;
  LAdmitted: TAudioFeatures;
  LSymbols: TAcousticEventSymbols;
  LClasses: TAcousticIndices;
  LTraining: TAcousticEventCorpus;
  LRuns: TAcousticEventCorpus;
  LInput: TRecordedEventInput;
  LCount: Integer;
  LTotal: Integer;
  LRun: Integer;
  I: Integer;
  J: Integer;
  K: Integer;
begin
  if (ACorpus = nil) or (Length(AInputs) < 1) or
    (Length(AInputs) > MaximumCorpusSources) or (AQuantumFrames < 1) or
    (AQuantumFrames > MaximumClipSamples) or (APaletteSize < 1) or
    (APaletteSize > MaximumAcousticVocabulary) or (AOrder < 1) or (AOrder > 4) then
  begin
    raise EAudio.Create('Recorded event learning request exceeds bounds');
  end;
  FQuantumFrames := AQuantumFrames;
  SetLength(FInfo, ACorpus.SourceCount);
  for I := 0 to High(FInfo) do
  begin
    FInfo[I] := ACorpus.SourceInfoAt(I);
  end;
  LTotal := 0;
  for I := 0 to High(AInputs) do
  begin
    LInput := AInputs[I];
    if (LInput.SourceIndex < 0) or (LInput.SourceIndex >= ACorpus.SourceCount) or
      (Length(LInput.Bounds) < 2) or (Length(LInput.Bounds) > MaximumPassages + 1) or
      (Length(LInput.RunIndices) <> High(LInput.Bounds)) or
      (Length(LInput.StartsAtOnset) <> High(LInput.Bounds)) then
    begin
      raise EAudio.Create('Recorded event source or interval shape is invalid');
    end;
    for J := 0 to I - 1 do
    begin
      if AInputs[J].SourceIndex = LInput.SourceIndex then
      begin
        raise EAudio.Create('Repeated event source requires an explicit weighting policy');
      end;
    end;
    Inc(LTotal, Length(LInput.RunIndices));
    if LTotal > MaximumRecordedEvents then
    begin
      raise EAudio.Create('Recorded event inputs exceed interval budget');
    end;
  end;
  SetLength(LFeatures, Length(AInputs));
  SetLength(LAdmitted, LTotal);
  LCount := 0;
  for I := 0 to High(AInputs) do
  begin
    LInput := AInputs[I];
    LFeatures[I] := MeasurePassages(ACorpus, LInput.SourceIndex, LInput.Bounds);
    SetLength(LSymbols, Length(LFeatures[I]));
    for J := 0 to High(LSymbols) do
    begin
      LSymbols[J] := AcousticEventSymbol(0, 1, 1, False);
      if LInput.RunIndices[J] >= 0 then
      begin
        LAdmitted[LCount] := LFeatures[I][J];
        Inc(LCount);
      end;
    end;
    LRuns := PartitionAcousticEvents(LSymbols, LInput.RunIndices);
    if Length(LRuns) = 0 then
    begin
      raise EAudio.Create('Every event input requires at least one admitted run');
    end;
    Inc(FRunCount, Length(LRuns));
    if FRunCount > WFC_SEQUENCE_MAX_SAMPLE_COUNT then
    begin
      raise EAudio.Create('Recorded event corpus exceeds training run budget');
    end;
  end;
  SetLength(LAdmitted, LCount);
  if AModel = nil then
  begin
    FPalette := TAcousticPalette.Create(LAdmitted, APaletteSize);
  end
  else
  begin
    FPalette := TAcousticPalette.CreateFromCenters(ACenters);
  end;
  SetLength(FMembers, LCount);
  SetLength(LTraining, FRunCount);
  LCount := 0;
  LRun := 0;
  for I := 0 to High(AInputs) do
  begin
    LInput := AInputs[I];
    LClasses := FPalette.Encode(LFeatures[I]);
    SetLength(LSymbols, Length(LClasses));
    for J := 0 to High(LClasses) do
    begin
      if LInput.RunIndices[J] < 0 then
      begin
        Continue;
      end;
      LSymbols[J] := AcousticEventSymbol(LClasses[J],
        LInput.Bounds[J + 1] - LInput.Bounds[J], AQuantumFrames,
        LInput.StartsAtOnset[J]);
      FMembers[LCount].Passage.SourceIndex := LInput.SourceIndex;
      FMembers[LCount].Passage.StartFrame := LInput.Bounds[J];
      FMembers[LCount].Passage.FrameCount := LInput.Bounds[J + 1] - LInput.Bounds[J];
      FMembers[LCount].IntervalIndex := J;
      FMembers[LCount].RunIndex := LRun + LInput.RunIndices[J];
      FMembers[LCount].Token := AcousticEventToken(LSymbols[J]);
      Inc(LCount);
    end;
    LRuns := PartitionAcousticEvents(LSymbols, LInput.RunIndices);
    for K := 0 to High(LRuns) do
    begin
      LTraining[LRun + K] := LRuns[K];
    end;
    Inc(LRun, Length(LRuns));
  end;
  if AModel = nil then
  begin
    FModel := LearnAcousticEventModel(LTraining, FPalette, AOrder);
  end
  else
  begin
    ValidateAcousticEventModel(LTraining, FPalette, AModel);
    FModel := DecodeWfcSequenceText(EncodeWfcSequenceText(AModel));
  end;
  FInputs := Copy(AInputs);
  for I := 0 to High(FInputs) do
  begin
    FInputs[I].Bounds := Copy(AInputs[I].Bounds);
    FInputs[I].RunIndices := Copy(AInputs[I].RunIndices);
    FInputs[I].StartsAtOnset := Copy(AInputs[I].StartsAtOnset);
  end;
end;

function TRecordedEventLearning.CopyInputs: TRecordedEventInputs;
var
  LInputs: TRecordedEventInputs;
  I: Integer;
begin
  LInputs := Copy(FInputs);
  for I := 0 to High(LInputs) do
  begin
    LInputs[I].Bounds := Copy(FInputs[I].Bounds);
    LInputs[I].RunIndices := Copy(FInputs[I].RunIndices);
    LInputs[I].StartsAtOnset := Copy(FInputs[I].StartsAtOnset);
  end;
  Result := LInputs;
end;

destructor TRecordedEventLearning.Destroy;
begin
  FModel.Free;
  FPalette.Free;
  inherited Destroy;
end;

function TRecordedEventLearning.GetMemberCount: Integer;
begin
  Result := Length(FMembers);
end;

function TRecordedEventLearning.GetSourceCount: Integer;
begin
  Result := Length(FInfo);
end;

function TRecordedEventLearning.MemberAt(const AIndex: Integer): TRecordedEventMember;
begin
  if (AIndex < 0) or (AIndex >= MemberCount) then
  begin
    raise EAudio.Create('Recorded event member index outside corpus');
  end;
  Result := FMembers[AIndex];
end;

function TRecordedEventLearning.SourceInfoAt(const AIndex: Integer): TAcousticSourceInfo;
begin
  if (AIndex < 0) or (AIndex >= SourceCount) then
  begin
    raise EAudio.Create('Recorded event source index outside corpus');
  end;
  Result := FInfo[AIndex];
end;

function TRecordedEventLearning.SelectMembers(const ATokens: TWfcModelTokens;
  const ASeed: Cardinal): TPassageIndices;
var
  LResult: TPassageIndices;
  LCandidates: TPassageIndices;
  LPrevious: Integer;
  LSelected: Integer;
  LCount: Integer;
  I: Integer;
  J: Integer;
begin
  if (Length(ATokens) < 1) or (Length(ATokens) > 1024) or
    (Int64(Length(ATokens)) * MemberCount > MaximumEventSelectionWork) then
  begin
    raise EAudio.Create('Event member selection exceeds bounded search work');
  end;
  SetLength(LResult, Length(ATokens));
  SetLength(LCandidates, MemberCount);
  LPrevious := -1;
  for I := 0 to High(ATokens) do
  begin
    ParseAcousticEventToken(ATokens[I]);
    LSelected := -1;
    if (LPrevious >= 0) and (LPrevious + 1 < MemberCount) and
      (FMembers[LPrevious + 1].Token = ATokens[I]) and
      (FMembers[LPrevious + 1].RunIndex = FMembers[LPrevious].RunIndex) then
    begin
      LSelected := LPrevious + 1;
    end;
    if LSelected < 0 then
    begin
      LCount := 0;
      for J := 0 to High(FMembers) do
      begin
        if FMembers[J].Token = ATokens[I] then
        begin
          LCandidates[LCount] := J;
          Inc(LCount);
        end;
      end;
      if LCount = 0 then
      begin
        raise EAudio.Create('Generated event has no matching recorded member');
      end;
      LSelected := LCandidates[(QWord(ASeed) + QWord(I) * 2654435761) mod QWord(LCount)];
    end;
    LResult[I] := LSelected;
    LPrevious := LSelected;
  end;
  Result := LResult;
end;

end.
