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
unit pythian.wfc.instrumental.edit.stream;

{$mode delphi}
{$H+}

interface

uses pythian.progress, pythian.music.decisions, pythian.wfc.layers,
  pythian.wfc.percussion, pythian.wfc.instrumental.edit,
  pythian.wfc.instrumental.policy,
  wfc_sequence, wfc_music_voices_graph;

const InstrumentalPassageStreamVersion = 1;

type
  TInstrumentalPassageStreamState = (ipesReady, ipesRunning, ipesCompleted,
    ipesRejected, ipesFailed);
  { Big Boss: the existing finite editor proves a bounded future window before
    this iterator returns only its original journal prefix. Future selected
    choices are provisional and discarded; kept future accompaniment remains
    a hard domain. No seed retry, relaxed constraint, audio assembly or learning.

    Reader and immutable models are borrowed and must outlive the iterator.
    Configuration, controls and definition arrays are detached. The reader must
    start at zero; it reads ahead by at most one bounded window plus one original
    chunk. A caller may lower the 256-cell ceiling for its resource budget;
    actual model-state capacity can reduce it further. The caller binds its complete journal to an accepted source receipt
    and publishes only after Completed. Returned prefixes keep original chunk
    sizes. False/exception preserves AAfter; rejection/cancellation is terminal.
    Progress callbacks must not mutate inputs or reenter the iterator. }
  TInstrumentalPassageStream = class
  private
    FConfig: TWfcMusicVoicesGraphConfig;
    FNames: TLayerNames;
    FDrums: TPercussionDefinitions;
    FContext: TWfcSequenceModel;
    FReader: TMusicDecisionReader;
    FEdit: TInstrumentalPassageEdit;
    FPolicies: TInstrumentalProviderPolicies;
    FTicksPerQuarter: Integer;
    FStepTicks: Integer;
    FTotalCells: Int64;
    FPosition: Int64;
    FState: TInstrumentalPassageStreamState;
    FBusy: Boolean;
    FEnded: Boolean;
    FBuffered: array of TMusicDecisionChunk;
    FBufferedCells: Integer;
    FWindowLimit: Integer;
    FMaximumWindowCells: Integer;
    FMaximumBufferedCells: Integer;
    FSourcePrevious: TMusicDecisionChunk;
    FCandidatePrevious: TMusicDecisionChunk;
    procedure Fill(const AProgress: TWorkProgressCallback);
  public
    constructor Create(const AConfig: TWfcMusicVoicesGraphConfig;
      const ANames: TLayerNames; const ADrums: TPercussionDefinitions;
      const AContext: TWfcSequenceModel; const AReader: TMusicDecisionReader;
      const ATotalCells: Int64; const AEdit: TInstrumentalPassageEdit;
      const AMaximumCells: Integer = MaximumMusicDecisionCells;
      const APolicies: TInstrumentalProviderPolicies = nil;
      const ATicksPerQuarter: Integer = 480; const AStepTicks: Integer = 240);
    function TryNext(var AAfter: TMusicDecisionChunk;
      out AReport: TInstrumentalPassageReport;
      const AProgress: TWorkProgressCallback = nil): Boolean;
    property State: TInstrumentalPassageStreamState read FState;
    property Position: Int64 read FPosition;
    property WindowLimit: Integer read FWindowLimit;
    property MaximumWindowCells: Integer read FMaximumWindowCells;
    property MaximumBufferedCells: Integer read FMaximumBufferedCells;
  end;

implementation

uses SysUtils, Math, pythian.audio, pythian.chord, pythian.time,
  wfc_music_arrangement;

procedure Need(const AValue: Boolean; const AMessage: String);
begin
  if not AValue then raise EAudio.Create(AMessage);
end;

constructor TInstrumentalPassageStream.Create(const AConfig: TWfcMusicVoicesGraphConfig;
  const ANames: TLayerNames; const ADrums: TPercussionDefinitions;
  const AContext: TWfcSequenceModel; const AReader: TMusicDecisionReader;
  const ATotalCells: Int64; const AEdit: TInstrumentalPassageEdit;
  const AMaximumCells: Integer; const APolicies: TInstrumentalProviderPolicies;
  const ATicksPerQuarter: Integer; const AStepTicks: Integer);
var
  LStates: Int64;
  I: Integer;
  procedure CountModel(const AModel: TWfcSequenceModel);
  begin
    Need((AModel <> nil) and (AModel.StateCount > 0), 'Musical edit needs an actual model');
    Inc(LStates, AModel.StateCount);
  end;
begin
  inherited Create;
  Need((AMaximumCells = Trunc(AMaximumCells)) and (AMaximumCells > 0) and
    (AMaximumCells <= MaximumMusicDecisionCells), 'Musical edit window must be 1..256 cells');
  Need((AReader <> nil) and (AReader.CellCount = 0) and (AReader.FrameCount = 0),
    'Musical edit needs a fresh borrowed decision reader');
  RequireExactTimingCounter(ATotalCells, 'Retained musical extent');
  Need(ATotalCells > 0, 'Retained musical extent must be positive');
  RequireExactTimingCounter(AEdit.StartFrame, 'Musical edit start frame');
  RequireExactTimingCounter(AEdit.EndFrame, 'Musical edit end frame');
  Need(AEdit.EndFrame > AEdit.StartFrame, 'Musical edit needs a nonempty range');
  ValidateWfcMusicVoicesGraphConfig(AConfig);
  Need(Length(ANames) = Length(AConfig.Voices), 'Musical edit role layout differs');
  LStates := 0;
  CountModel(AConfig.HarmonyModel);
  CountModel(AConfig.RhythmModel);
  for I := 0 to High(AConfig.Voices) do CountModel(AConfig.Voices[I].Model);
  for I := 0 to High(ADrums) do CountModel(ADrums[I].Model);
  if AContext <> nil then CountModel(AContext);
  FWindowLimit := Min(Int64(AMaximumCells), MaximumLayerStateCells div LStates);
  Need(FWindowLimit > 0, 'Musical edit exceeds its bounded state-cell budget');
  FConfig := CopyWfcMusicVoicesGraphConfig(AConfig);
  FNames := Copy(ANames);
  FDrums := CopyPercussionDefinitions(ADrums);
  FContext := AContext;
  FReader := AReader;
  FTotalCells := ATotalCells;
  FEdit := AEdit;
  FEdit.Parts := Copy(AEdit.Parts);
  FEdit.Controls := Copy(AEdit.Controls);
  FPolicies := CopyInstrumentalPolicies(APolicies);
  FTicksPerQuarter := ATicksPerQuarter;
  FStepTicks := AStepTicks;
  FState := ipesReady;
end;

procedure TInstrumentalPassageStream.Fill(const AProgress: TWorkProgressCallback);
var
  LChunk: TMusicDecisionChunk;
  LCount: Integer;
begin
  while not FEnded and (FBufferedCells <= FWindowLimit) do
  begin
    LChunk := Default(TMusicDecisionChunk);
    if not FReader.TryNext(LChunk, AProgress) then
    begin
      FEnded := True;
      Need(FReader.CellCount = FTotalCells, 'Saved musical extent differs from its journal');
      Need(FEdit.EndFrame <= FReader.FrameCount, 'Musical edit range exceeds its saved music');
      Break;
    end;
    Need(FReader.CellCount <= FTotalCells, 'Saved journal exceeds its declared musical extent');
    LCount := Length(FBuffered);
    SetLength(FBuffered, LCount + 1);
    FBuffered[LCount] := LChunk;
    Inc(FBufferedCells, Length(LChunk.Cells));
    FMaximumBufferedCells := Max(FMaximumBufferedCells, FBufferedCells);
  end;
end;

function TInstrumentalPassageStream.TryNext(var AAfter: TMusicDecisionChunk;
  out AReport: TInstrumentalPassageReport;
  const AProgress: TWorkProgressCallback): Boolean;
var
  LCurrent: TMusicDecisionChunk;
  LWindow: TMusicDecisionChunk;
  LCandidate: TMusicDecisionChunk;
  LPrefix: TMusicDecisionChunk;
  LNext: TMusicDecisionChunk;
  LEdges: TInstrumentalPassageEdges;
  LEdit: TInstrumentalPassageEdit;
  LReport: TInstrumentalPassageReport;
  LFrame: Int64;
  LPrefixCells: Integer;
  LUsed: Integer;
  LChanged: Boolean;
  I: Integer;
  J: Integer;
begin
  Result := False;
  AReport := Default(TInstrumentalPassageReport);
  Need(not FBusy, 'Musical edit iterator cannot reenter');
  if FState in [ipesCompleted, ipesRejected, ipesFailed] then Exit;
  FBusy := True;
  try
    try
      Fill(AProgress);
      if Length(FBuffered) = 0 then
      begin
        FState := ipesCompleted;
        Exit;
      end;
      LCurrent := FBuffered[0];
      Need(LCurrent.FirstCell = FPosition, 'Musical edit prefix clock differs');
      LPrefixCells := Length(LCurrent.Cells);
      LPrefix := CopyMusicDecisionChunk(LCurrent);
      if (LCurrent.StartFrame < FEdit.EndFrame) and
        (LCurrent.StartFrame + MusicDecisionFrameCount(LCurrent) > FEdit.StartFrame) then
      begin
        Need(LPrefixCells <= FWindowLimit, 'Recorded musical chunk exceeds the edit state budget');
        LWindow := CopyMusicDecisionChunk(LCurrent);
        LUsed := 1;
        while (LUsed < Length(FBuffered)) and
          (Length(FBuffered[LUsed].Cells) <= FWindowLimit - Length(LWindow.Cells)) do
        begin
          LWindow := AppendMusicDecisionChunk(LWindow, FBuffered[LUsed], AProgress);
          Inc(LUsed);
        end;
        LNext := Default(TMusicDecisionChunk);
        if LUsed < Length(FBuffered) then LNext := FBuffered[LUsed];
        LEdges := RetainedInstrumentalPassageEdges(FSourcePrevious, LNext);
        LEdges.CandidatePrevious := FCandidatePrevious;
        LEdges.FollowingCells := Min(Int64(High(Integer)),
          FTotalCells - LWindow.FirstCell - Length(LWindow.Cells));
        LEdit := FEdit;
        LEdit.Seed := WfcMusicArrangementSectionSeed(FEdit.Seed, LCurrent.FirstCell);
        FMaximumWindowCells := Max(FMaximumWindowCells, Length(LWindow.Cells));
        ReportWork(AProgress, 'instrumental_edit_window', wuItems,
          0, Length(LWindow.Cells));
        if not TryEditInstrumentalPassageChunk(FConfig, FNames, FDrums, FContext,
          LWindow, LEdges, LEdit, LCandidate, LReport, AProgress,
          FPolicies, FTicksPerQuarter, FStepTicks) then
        begin
          AReport := LReport;
          FState := ipesRejected;
          Exit;
        end;
        LPrefix := SliceMusicDecisionChunk(LCandidate, 0, LPrefixCells, AProgress);
        AReport := LReport;
        AReport.ChangedCells := 0;
        AReport.ChangedProviders := 0;
        AReport.ActualStartFrame := 0;
        AReport.ActualEndFrame := 0;
        LFrame := LCurrent.StartFrame;
        for I := 0 to LPrefixCells - 1 do
        begin
          if not SameMusicDecisionFrame(LPrefix.Cells[I].Parts, LCurrent.Cells[I].Parts) then
            Inc(AReport.ChangedCells);
          if (LFrame < FEdit.EndFrame) and
            (LFrame + LCurrent.Cells[I].FrameCount > FEdit.StartFrame) then
          begin
            if AReport.ActualEndFrame = 0 then AReport.ActualStartFrame := LFrame;
            AReport.ActualEndFrame := LFrame + LCurrent.Cells[I].FrameCount;
          end;
          Inc(LFrame, LCurrent.Cells[I].FrameCount);
        end;
        for I := 0 to High(LPrefix.Providers) do
        begin
          LChanged := False;
          for J := 0 to LPrefixCells - 1 do
            LChanged := LChanged or
              (LPrefix.Providers[I].Tokens[J] <> LCurrent.Providers[I].Tokens[J]) or
              (LPrefix.Providers[I].States[J] <> LCurrent.Providers[I].States[J]);
          if LChanged then Inc(AReport.ChangedProviders);
        end;
      end;
      if FPosition > 0 then
        LPrefix.Previous := CopyChordFrame(FCandidatePrevious.Cells[High(FCandidatePrevious.Cells)].Parts);
      ValidateMusicDecisionChunk(LPrefix, AProgress);
      ReportWork(AProgress, 'instrumental_edit_prefix', wuItems,
        FPosition + LPrefixCells, FTotalCells);
      FSourcePrevious := LCurrent;
      FCandidatePrevious := CopyMusicDecisionChunk(LPrefix);
      Inc(FPosition, LPrefixCells);
      Dec(FBufferedCells, LPrefixCells);
      for I := 0 to High(FBuffered) - 1 do FBuffered[I] := FBuffered[I + 1];
      SetLength(FBuffered, Length(FBuffered) - 1);
      FState := ipesRunning;
      if FEnded and (Length(FBuffered) = 0) then FState := ipesCompleted;
      AAfter := LPrefix;
      Result := True;
    except
      FState := ipesFailed;
      raise;
    end;
  finally
    FBusy := False;
  end;
end;

end.
