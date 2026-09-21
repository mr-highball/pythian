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
unit pythian.continuity;

{$mode delphi}
{$H+}

interface

uses
  pythian.audio,
  pythian.learning,
  pythian.granular,
  pythian.corpus,
  pythian.activity;

const
  AcousticContinuityVersion = 1;
  MaximumContinuityGrains = 4096;
  MaximumContinuityVisits = 64000000;

type
  TContinuityOptions = record
    BeamWidth: Integer;
    CandidatesPerToken: Integer;
    JoinProbeFrames: Integer;
    CenterWeight: Double;
    SeamWeight: Double;
    JumpWeight: Double;
    SustainJumpWeight: Double;
    Activity: TActivityOptions;
  end;
  TContinuityReport = record
    GrainCount: Integer;
    ContiguousLinks: Integer;
    SourceJumps: Integer;
    SourceSwitches: Integer;
    JumpsIntoSustain: Integer;
    SelectedOnsets: Integer;
    MeanCenterError: Double;
    MeanSeamError: Double;
    TotalCost: Double;
  end;

  { Reusable bounded beam planner. Corpus measurements are copied; source clips
    are borrowed and must remain alive. The caller binds them to corpus hashes.
    Candidate tokens and output positions are hard constraints, never relaxed. }
  TCorpusGrainPlanner = class
  strict private
    type
      TNode = record
        SourceIndex: Integer;
        StartFrame: Integer;
        FrameCount: Integer;
        Token: Integer;
        Action: TAcousticAction;
        CenterError: Double;
      end;
    var
      FSources: TAudioSources;
      FNodes: array of TNode;
      FSourceStarts: array of Integer;
      FPools: array of TAcousticIndices;
      FPaletteCount: Integer;
      FOptions: TContinuityOptions;
      FHopFrames: Integer;
      FWindowFrames: Integer;
      FChannels: Integer;
    procedure ValidateRequest(const AIndices: TAcousticIndices);
    function PlanInternal(const AIndices: TAcousticIndices; const AActions: TAcousticActions;
      out AReport: TContinuityReport): TAudioGrains;
    function Contiguous(const APrevious, ANext: Integer): Boolean;
    function SeamError(const APrevious, ANext: Integer): Double;
    function TransitionCost(const APrevious, ANext: Integer): Double;
  public
    constructor Create(const ACorpus: TAcousticCorpusData; const ASources: TAudioSources;
      const AOptions: TContinuityOptions);
    function Plan(const AIndices: TAcousticIndices;
      out AReport: TContinuityReport): TAudioGrains;
    function PlanActions(const AIndices: TAcousticIndices; const AActions: TAcousticActions;
      out AReport: TContinuityReport): TAudioGrains;
    procedure ValidateGrainActions(const AActions: TAcousticActions; const AGrains: TAudioGrains);
    function Evaluate(const AIndices: TAcousticIndices;
      const AGrains: TAudioGrains): TContinuityReport;
  end;

function DefaultContinuityOptions: TContinuityOptions;
procedure ValidateContinuityOptions(const AOptions: TContinuityOptions);

implementation

uses
  Math,
  pythian.analysis;

type
  TBeamNode = record
    NodeIndex: Integer;
    Parent: Integer;
    Cost: Double;
  end;
  TBeamLayer = record
    Count: Integer;
    Nodes: array[0..31] of TBeamNode;
  end;

function DefaultContinuityOptions: TContinuityOptions;
begin
  Result.BeamWidth := 8;
  Result.CandidatesPerToken := 16;
  Result.JoinProbeFrames := 16;
  Result.CenterWeight := 1;
  Result.SeamWeight := 1;
  Result.JumpWeight := 0.05;
  Result.SustainJumpWeight := 0.2;
  Result.Activity := DefaultActivityOptions;
end;

procedure ValidateContinuityOptions(const AOptions: TContinuityOptions);
begin
  ValidateActivityOptions(AOptions.Activity);
  RequireFinite(AOptions.CenterWeight, 'Center cost weight');
  RequireFinite(AOptions.SeamWeight, 'Seam cost weight');
  RequireFinite(AOptions.JumpWeight, 'Jump cost weight');
  RequireFinite(AOptions.SustainJumpWeight, 'Sustain jump cost weight');
  if (AOptions.BeamWidth < 1) or (AOptions.BeamWidth > 32) or
    (AOptions.CandidatesPerToken < 1) or (AOptions.CandidatesPerToken > 32) or
    (AOptions.JoinProbeFrames < 1) or (AOptions.JoinProbeFrames > 64) or
    (AOptions.CenterWeight < 0) or (AOptions.CenterWeight > 16) or
    (AOptions.SeamWeight < 0) or (AOptions.SeamWeight > 16) or
    (AOptions.JumpWeight < 0) or (AOptions.JumpWeight > 16) or
    (AOptions.SustainJumpWeight < 0) or (AOptions.SustainJumpWeight > 16) then
  begin
    raise EAudio.Create('Continuity options exceed bounded planner contract');
  end;
end;

constructor TCorpusGrainPlanner.Create(const ACorpus: TAcousticCorpusData;
  const ASources: TAudioSources; const AOptions: TContinuityOptions);
var
  LInfo: TAcousticSourceInfo;
  LRecording: TAcousticRecording;
  LActivity: TAcousticActivity;
  LPalette: TAcousticPalette;
  LCenters: TAcousticVectors;
  LVector: TAcousticVector;
  LSource: Integer;
  LFrame: Integer;
  LIndex: Integer;
  LComponent: Integer;
  LToken: Integer;
  LPosition: Integer;
  LCount: Integer;
  LMove: Integer;
  LPool: Integer;
  LPass: Integer;
begin
  inherited Create;
  ValidateContinuityOptions(AOptions);
  if (ACorpus = nil) or (Length(ASources) <> ACorpus.SourceCount) then
  begin
    raise EAudio.Create('Planner requires a corpus and its complete source list');
  end;
  for LSource := 0 to High(ASources) do
  begin
    LInfo := ACorpus.SourceInfoAt(LSource);
    if (ASources[LSource] = nil) or (ASources[LSource].SampleRate <> LInfo.SampleRate) or
      (ASources[LSource].Channels <> LInfo.Channels) or
      (ASources[LSource].FrameCount <> LInfo.FrameCount) then
    begin
      raise EAudio.Create('Planner source format or extent disagrees with corpus');
    end;
  end;
  FSources := Copy(ASources);
  FOptions := AOptions;
  FHopFrames := ACorpus.Options.HopFrames;
  FWindowFrames := ACorpus.Options.WindowFrames;
  FChannels := ACorpus.SourceInfoAt(0).Channels;
  SetLength(FNodes, ACorpus.FeatureCount);
  SetLength(FSourceStarts, ACorpus.SourceCount);
  FPaletteCount := ACorpus.PaletteCount;
  SetLength(FPools, FPaletteCount * 4);
  LPalette := ACorpus.CopyPalette;
  try
    LCenters := LPalette.CopyCenters;
  finally
    LPalette.Free;
  end;
  LIndex := 0;
  for LSource := 0 to ACorpus.SourceCount - 1 do
  begin
    LRecording := ACorpus.RecordingAt(LSource);
    LActivity := AnalyzeAcousticActivity(LRecording.Features, ACorpus.Options,
      LRecording.Info.FrameCount, AOptions.Activity);
    FSourceStarts[LSource] := LIndex;
    for LFrame := 0 to High(LRecording.Features) do
    begin
      LToken := LRecording.Tokens[LFrame];
      FNodes[LIndex].SourceIndex := LSource;
      FNodes[LIndex].StartFrame := LRecording.Features[LFrame].StartFrame;
      FNodes[LIndex].FrameCount := LRecording.Features[LFrame].ValidFrames;
      FNodes[LIndex].Token := LToken;
      FNodes[LIndex].Action := LActivity.Actions[LFrame];
      LVector := AcousticVector(LRecording.Features[LFrame]);
      FNodes[LIndex].CenterError := 0;
      for LComponent := 0 to High(LVector) do
      begin
        FNodes[LIndex].CenterError := FNodes[LIndex].CenterError +
          Sqr(LVector[LComponent] - LCenters[LToken][LComponent]) / 15;
      end;
      { Stable nearest-center seeds. Exact successors are added dynamically so
        long forward passages do not end at this static candidate limit. }
      { Independent action pools prevent nearest-center truncation from
        discarding all candidates of a requested activity class. }
      for LPass := 0 to 1 do
      begin
        LPool := LToken;
        if LPass = 1 then
        begin
          LPool := LToken + (Ord(FNodes[LIndex].Action) + 1) * FPaletteCount;
        end;
        LCount := Length(FPools[LPool]);
        LPosition := 0;
        while (LPosition < LCount) and
          (FNodes[FPools[LPool][LPosition]].CenterError <= FNodes[LIndex].CenterError) do
        begin
          Inc(LPosition);
        end;
        if LPosition < AOptions.CandidatesPerToken then
        begin
          if LCount < AOptions.CandidatesPerToken then
          begin
            Inc(LCount);
            SetLength(FPools[LPool], LCount);
          end;
          for LMove := LCount - 1 downto LPosition + 1 do
          begin
            FPools[LPool][LMove] := FPools[LPool][LMove - 1];
          end;
          FPools[LPool][LPosition] := LIndex;
        end;
      end;
      Inc(LIndex);
    end;
  end;
end;

procedure TCorpusGrainPlanner.ValidateRequest(const AIndices: TAcousticIndices);
var
  LIndex: Integer;
  LVisits: Int64;
begin
  LVisits := Int64(Length(AIndices)) * FOptions.BeamWidth *
    (FOptions.CandidatesPerToken + FOptions.BeamWidth) *
    FOptions.JoinProbeFrames * FChannels;
  if (Length(AIndices) > MaximumContinuityGrains) or
    (LVisits > MaximumContinuityVisits) then
  begin
    raise EAudio.Create('Continuity request exceeds grain or overlap-probe budget');
  end;
  if (Length(AIndices) > 0) and
    (Int64(Length(AIndices) - 1) * FHopFrames + FWindowFrames >
      MaximumGrainSamples div FChannels) then
  begin
    raise EAudio.Create('Continuity request exceeds worst-case output sample budget');
  end;
  for LIndex := 0 to High(AIndices) do
  begin
    if (AIndices[LIndex] < 0) or (AIndices[LIndex] >= FPaletteCount) then
    begin
      raise EAudio.Create('Continuity token is outside the corpus palette');
    end;
    if Length(FPools[AIndices[LIndex]]) = 0 then
    begin
      raise EAudio.Create('Continuity token has no recorded exemplar');
    end;
  end;
end;

function TCorpusGrainPlanner.Contiguous(const APrevious, ANext: Integer): Boolean;
begin
  Result := (FNodes[APrevious].SourceIndex = FNodes[ANext].SourceIndex) and
    (FNodes[APrevious].StartFrame + FHopFrames = FNodes[ANext].StartFrame);
end;

function TCorpusGrainPlanner.SeamError(const APrevious, ANext: Integer): Double;
var
  LPrevious: TNode;
  LNext: TNode;
  LOverlap: Integer;
  LCount: Integer;
  LProbe: Integer;
  LOffset: Integer;
  LPreviousOffset: Integer;
  LChannel: Integer;
  LLeft: TAudioSamples;
  LRight: TAudioSamples;
begin
  if Contiguous(APrevious, ANext) then
  begin
    Exit(0);
  end;
  LPrevious := FNodes[APrevious];
  LNext := FNodes[ANext];
  LOverlap := Min(LPrevious.FrameCount - FHopFrames, LNext.FrameCount);
  LCount := Max(1, Min(FOptions.JoinProbeFrames, LOverlap));
  SetLength(LLeft, LCount * FChannels);
  SetLength(LRight, LCount * FChannels);
  for LProbe := 0 to LCount - 1 do
  begin
    LOffset := 0;
    if LCount > 1 then
    begin
      LOffset := LProbe * (LOverlap - 1) div (LCount - 1);
    end;
    LPreviousOffset := FHopFrames + LOffset;
    if LOverlap <= 0 then
    begin
      LPreviousOffset := LPrevious.FrameCount - 1;
    end;
    for LChannel := 0 to FChannels - 1 do
    begin
      LLeft[LProbe * FChannels + LChannel] := FSources[LPrevious.SourceIndex].SampleAt(
        LPrevious.StartFrame + LPreviousOffset, LChannel);
      LRight[LProbe * FChannels + LChannel] :=
        FSources[LNext.SourceIndex].SampleAt(LNext.StartFrame + LOffset, LChannel);
    end;
  end;
  Result := NormalizedGrainJoinError(LLeft, LRight);
end;

function TCorpusGrainPlanner.TransitionCost(const APrevious, ANext: Integer): Double;
begin
  Result := FOptions.SeamWeight * SeamError(APrevious, ANext);
  if not Contiguous(APrevious, ANext) then
  begin
    Result := Result + FOptions.JumpWeight;
    if FNodes[ANext].Action = aaSustain then
    begin
      Result := Result + FOptions.SustainJumpWeight;
    end;
  end;
end;

function TCorpusGrainPlanner.Plan(const AIndices: TAcousticIndices;
  out AReport: TContinuityReport): TAudioGrains;
begin
  Result := PlanInternal(AIndices, nil, AReport);
end;

function TCorpusGrainPlanner.PlanActions(const AIndices: TAcousticIndices;
  const AActions: TAcousticActions; out AReport: TContinuityReport): TAudioGrains;
begin
  if Length(AIndices) <> Length(AActions) then
  begin
    raise EAudio.Create('One action is required per requested grain');
  end;
  Result := PlanInternal(AIndices, AActions, AReport);
end;

procedure TCorpusGrainPlanner.ValidateGrainActions(const AActions: TAcousticActions;
  const AGrains: TAudioGrains);
var
  LIndex: Integer;
  LNode: Integer;
begin
  if Length(AActions) <> Length(AGrains) then
  begin
    raise EAudio.Create('Action/grain lengths disagree');
  end;
  for LIndex := 0 to High(AGrains) do
  begin
    if (AGrains[LIndex].SourceIndex < 0) or
      (AGrains[LIndex].SourceIndex >= Length(FSources)) or
      (AGrains[LIndex].SourceStartFrame < 0) or
      (AGrains[LIndex].SourceStartFrame mod FHopFrames <> 0) or
      (AGrains[LIndex].SourceStartFrame >= FSources[AGrains[LIndex].SourceIndex].FrameCount) then
    begin
      raise EAudio.Create('Action check requires an exact recorded feature coordinate');
    end;
    LNode := FSourceStarts[AGrains[LIndex].SourceIndex] +
      AGrains[LIndex].SourceStartFrame div FHopFrames;
    if FNodes[LNode].Action <> AActions[LIndex] then
    begin
      raise EAudio.Create('Selected grain disagrees with requested action');
    end;
  end;
end;

function TCorpusGrainPlanner.PlanInternal(const AIndices: TAcousticIndices;
  const AActions: TAcousticActions; out AReport: TContinuityReport): TAudioGrains;
var
  LLayers: array of TBeamLayer;
  LCandidates: array[0..63] of Integer;
  LCandidateCount: Integer;
  LPool: Integer;
  LFrame: Integer;
  LIndex: Integer;
  LOther: Integer;
  LParent: Integer;
  LBestParent: Integer;
  LNode: Integer;
  LNext: Integer;
  LPosition: Integer;
  LCount: Integer;
  LCost: Double;
  LBestCost: Double;
  LDuplicate: Boolean;
begin
  AReport := Default(TContinuityReport);
  ValidateRequest(AIndices);
  for LFrame := 0 to High(AActions) do
  begin
    if not (AActions[LFrame] in [aaSilence, aaOnset, aaSustain]) or
      (Length(FPools[AIndices[LFrame] + (Ord(AActions[LFrame]) + 1) * FPaletteCount]) = 0) then
    begin
      raise EAudio.Create('Requested acoustic/activity pair has no recorded exemplar');
    end;
  end;
  Result := nil;
  SetLength(LLayers, Length(AIndices));
  for LFrame := 0 to High(AIndices) do
  begin
    LPool := AIndices[LFrame];
    if Length(AActions) > 0 then
    begin
      LPool := LPool + (Ord(AActions[LFrame]) + 1) * FPaletteCount;
    end;
    LCandidateCount := Length(FPools[LPool]);
    for LIndex := 0 to LCandidateCount - 1 do
    begin
      LCandidates[LIndex] := FPools[LPool][LIndex];
    end;
    if LFrame > 0 then
    begin
      for LParent := 0 to LLayers[LFrame - 1].Count - 1 do
      begin
        LNode := LLayers[LFrame - 1].Nodes[LParent].NodeIndex;
        LNext := LNode + 1;
        if (LNext >= Length(FNodes)) or
          (FNodes[LNext].SourceIndex <> FNodes[LNode].SourceIndex) or
          (FNodes[LNext].Token <> AIndices[LFrame]) or
          ((Length(AActions) > 0) and (FNodes[LNext].Action <> AActions[LFrame])) then
        begin
          Continue;
        end;
        LDuplicate := False;
        for LIndex := 0 to LCandidateCount - 1 do
        begin
          if LCandidates[LIndex] = LNext then
          begin
            LDuplicate := True;
            Break;
          end;
        end;
        if not LDuplicate then
        begin
          LCandidates[LCandidateCount] := LNext;
          Inc(LCandidateCount);
        end;
      end;
    end;
    for LIndex := 0 to LCandidateCount - 1 do
    begin
      LNode := LCandidates[LIndex];
      LBestParent := -1;
      LBestCost := 0;
      if LFrame > 0 then
      begin
        LBestCost := MaxDouble;
        for LParent := 0 to LLayers[LFrame - 1].Count - 1 do
        begin
          LCost := LLayers[LFrame - 1].Nodes[LParent].Cost +
            TransitionCost(LLayers[LFrame - 1].Nodes[LParent].NodeIndex, LNode);
          if LCost < LBestCost then
          begin
            LBestCost := LCost;
            LBestParent := LParent;
          end;
        end;
      end;
      LBestCost := LBestCost + FOptions.CenterWeight * FNodes[LNode].CenterError;
      LCount := LLayers[LFrame].Count;
      LPosition := 0;
      while (LPosition < LCount) and
        ((LLayers[LFrame].Nodes[LPosition].Cost < LBestCost) or
        ((LLayers[LFrame].Nodes[LPosition].Cost = LBestCost) and
        (LLayers[LFrame].Nodes[LPosition].NodeIndex < LNode))) do
      begin
        Inc(LPosition);
      end;
      if LPosition < FOptions.BeamWidth then
      begin
        if LCount < FOptions.BeamWidth then
        begin
          Inc(LCount);
        end;
        for LOther := LCount - 1 downto LPosition + 1 do
        begin
          LLayers[LFrame].Nodes[LOther] := LLayers[LFrame].Nodes[LOther - 1];
        end;
        LLayers[LFrame].Nodes[LPosition].NodeIndex := LNode;
        LLayers[LFrame].Nodes[LPosition].Cost := LBestCost;
        LLayers[LFrame].Nodes[LPosition].Parent := LBestParent;
        LLayers[LFrame].Count := LCount;
      end;
    end;
  end;
  SetLength(Result, Length(AIndices));
  LParent := 0;
  for LFrame := High(AIndices) downto 0 do
  begin
    LNode := LLayers[LFrame].Nodes[LParent].NodeIndex;
    Result[LFrame].SourceIndex := FNodes[LNode].SourceIndex;
    Result[LFrame].SourceStartFrame := FNodes[LNode].StartFrame;
    Result[LFrame].OutputStartFrame := LFrame * FHopFrames;
    Result[LFrame].FrameCount := FNodes[LNode].FrameCount;
    Result[LFrame].PlaybackRate := 1;
    Result[LFrame].Gain := 1;
    Result[LFrame].Window := gwHann;
    LParent := LLayers[LFrame].Nodes[LParent].Parent;
  end;
  AReport := Evaluate(AIndices, Result);
  if Length(AActions) > 0 then
  begin
    ValidateGrainActions(AActions, Result);
  end;
end;

function TCorpusGrainPlanner.Evaluate(const AIndices: TAcousticIndices;
  const AGrains: TAudioGrains): TContinuityReport;
var
  LFrame: Integer;
  LNode: Integer;
  LPrevious: Integer;
  LGrain: TAudioGrain;
  LSeam: Double;
begin
  Result := Default(TContinuityReport);
  ValidateRequest(AIndices);
  if Length(AGrains) <> Length(AIndices) then
  begin
    raise EAudio.Create('Evaluation requires one grain per requested token');
  end;
  LPrevious := -1;
  for LFrame := 0 to High(AGrains) do
  begin
    LGrain := AGrains[LFrame];
    RequireFinite(LGrain.PlaybackRate, 'Evaluated playback rate');
    RequireFinite(LGrain.Gain, 'Evaluated grain gain');
    if (LGrain.SourceIndex < 0) or (LGrain.SourceIndex >= Length(FSources)) or
      (LGrain.SourceStartFrame < 0) or (LGrain.SourceStartFrame mod FHopFrames <> 0) or
      (LGrain.SourceStartFrame >= FSources[LGrain.SourceIndex].FrameCount) or
      (LGrain.OutputStartFrame <> Int64(LFrame) * FHopFrames) or
      (LGrain.PlaybackRate <> 1) or (LGrain.Gain <> 1) or (LGrain.Window <> gwHann) then
    begin
      raise EAudio.Create('Evaluated plan does not follow corpus grain coordinates');
    end;
    LNode := FSourceStarts[LGrain.SourceIndex] + LGrain.SourceStartFrame div FHopFrames;
    if (LNode >= Length(FNodes)) or (FNodes[LNode].SourceIndex <> LGrain.SourceIndex) or
      (LGrain.FrameCount <> FNodes[LNode].FrameCount) or
      (FNodes[LNode].Token <> AIndices[LFrame]) then
    begin
      raise EAudio.Create('Evaluated grain violates requested token or source extent');
    end;
    Result.MeanCenterError := Result.MeanCenterError + FNodes[LNode].CenterError;
    Result.TotalCost := Result.TotalCost + FOptions.CenterWeight * FNodes[LNode].CenterError;
    if FNodes[LNode].Action = aaOnset then
    begin
      Inc(Result.SelectedOnsets);
    end;
    if LPrevious >= 0 then
    begin
      LSeam := SeamError(LPrevious, LNode);
      Result.MeanSeamError := Result.MeanSeamError + LSeam;
      Result.TotalCost := Result.TotalCost + FOptions.SeamWeight * LSeam;
      if Contiguous(LPrevious, LNode) then
      begin
        Inc(Result.ContiguousLinks);
      end
      else
      begin
        Inc(Result.SourceJumps);
        Result.TotalCost := Result.TotalCost + FOptions.JumpWeight;
        if FNodes[LPrevious].SourceIndex <> FNodes[LNode].SourceIndex then
        begin
          Inc(Result.SourceSwitches);
        end;
        if FNodes[LNode].Action = aaSustain then
        begin
          Inc(Result.JumpsIntoSustain);
          Result.TotalCost := Result.TotalCost + FOptions.SustainJumpWeight;
        end;
      end;
    end;
    LPrevious := LNode;
  end;
  Result.GrainCount := Length(AGrains);
  if Result.GrainCount > 0 then
  begin
    Result.MeanCenterError := Result.MeanCenterError / Result.GrainCount;
  end;
  if Result.GrainCount > 1 then
  begin
    Result.MeanSeamError := Result.MeanSeamError / (Result.GrainCount - 1);
  end;
end;

end.
