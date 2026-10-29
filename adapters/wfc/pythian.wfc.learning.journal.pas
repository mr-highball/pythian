(*
MIT License

Copyright (c) 2021 mr-highball
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

unit pythian.wfc.learning.journal;

{$mode delphi}
{$H+}

interface

uses
  pythian.learning,
  pythian.learning.journal,
  pythian.progress,
  wfc_sequence;

{ Counts the companion's open-boundary sequence states without retaining token
  sequences. History crosses storage batches and resets only at declared
  segments. Positive segment multiplicity exactly repeats that segment's state,
  start and end evidence. Existing companion state/sample/Integer limits apply.
  Reader and palette are borrowed and remain caller-owned. Big Boss: a call-scoped
  optional observer covers preparation, nested journal reads and the companion's
  existing model builder. No partial model is returned on callback failure. }
function LearnJournalAcousticModel(const AReader: TJournalTrainingReader;
  const APalette: TAcousticPalette; const AOrder: Integer = 2;
  const AProgress: TWorkProgressCallback = nil): TWfcSequenceModel;

implementation

uses
  pythian.audio,
  pythian.wfc.learning,
  pythian.wfc.progress,
  wfc_model;

function LearnJournalAcousticModel(const AReader: TJournalTrainingReader;
  const APalette: TAcousticPalette; const AOrder: Integer;
  const AProgress: TWorkProgressCallback): TWfcSequenceModel;
var
  LStates: TWfcSequenceStates;
  LStateCounts: TWfcModelIntegerArray;
  LStartCounts: TWfcModelIntegerArray;
  LEndCounts: TWfcModelIntegerArray;
  LLengths: TWfcSequenceSampleLengths;
  LTokens: TWfcModelTokens;
  LHistory: TWfcSequenceHistory;
  LTokenMap: array[0..MaximumAcousticVocabulary - 1] of Integer;
  LKeys: array[0..2047] of Integer;
  LValues: array[0..2047] of Integer;
  LObservation: TJournalTrainingObservation;
  LSegment: TJournalTrainingSegment;
  LSegmentIndex: Integer;
  LSampleCount: Integer;
  LIndex: Integer;
  LRepeat: Integer;
  LHistoryIndex: Integer;
  LPaletteToken: Integer;
  LPublicToken: Integer;
  LKey: Integer;
  LSlot: Integer;
  LStateIndex: Integer;
  LWeight: Integer;
  LPosition: Int64;
  LObserved: Int64;
  LRead: Int64;
  LWork: TWfcObservedWork;
  LModel: TWfcSequenceModel;
begin
  if (AReader = nil) or (APalette = nil) or (AOrder < 1) or (AOrder > 4) then
  begin
    raise EAudio.Create('Journal WFC learning requires a reader, palette and order 1..4');
  end;
  if AReader.WeightedObservationCount > High(Integer) then
  begin
    raise EAudio.Create('Weighted journal observations exceed companion Integer counts');
  end;
  LModel := nil;
  LWork := TWfcObservedWork.Create(AProgress, 'journal_wfc_visits');
  try
    LTokens := nil;
    LStates := nil;
    LSampleCount := 0;
    for LIndex := 0 to AReader.SegmentCount - 1 do
    begin
      LWork.Visit;
      LSegment := AReader.SegmentAt(LIndex);
      if (LSegment.FeatureCount > High(Integer)) or
        (LSegment.Multiplicity > WFC_SEQUENCE_MAX_SAMPLE_COUNT - LSampleCount) then
      begin
        raise EAudio.Create('Journal segment length or multiplicity exceeds companion limits');
      end;
      Inc(LSampleCount, LSegment.Multiplicity);
    end;
    SetLength(LLengths, LSampleCount);
    LSampleCount := 0;
    for LIndex := 0 to AReader.SegmentCount - 1 do
    begin
      LSegment := AReader.SegmentAt(LIndex);
      for LRepeat := 1 to LSegment.Multiplicity do
      begin
        LWork.Visit;
        LLengths[LSampleCount] := LSegment.FeatureCount;
        Inc(LSampleCount);
      end;
    end;
    for LIndex := 0 to High(LKeys) do
    begin
      LKeys[LIndex] := -1;
    end;
    for LIndex := 0 to High(LTokenMap) do
    begin
      LTokenMap[LIndex] := -1;
    end;
    SetLength(LHistory, AOrder - 1);
    LSegmentIndex := -1;
    LObserved := 0;
    LRead := 0;
    AReader.Rewind;
    ReportWork(AProgress, 'journal_wfc_observations', wuObservations, 0, AReader.ObservationCount);
    while AReader.ReadObservation(LObservation, AProgress) do
    begin
      LWork.Visit;
      Inc(LRead);
      if LRead mod 128 = 0 then
      begin
        ReportWork(AProgress, 'journal_wfc_observations', wuObservations, LRead, AReader.ObservationCount);
      end;
      if LObservation.SegmentIndex <> LSegmentIndex then
      begin
        LSegmentIndex := LObservation.SegmentIndex;
        LSegment := AReader.SegmentAt(LSegmentIndex);
        for LHistoryIndex := 0 to High(LHistory) do
        begin
          LHistory[LHistoryIndex] := MakeWfcSequenceBosHistoryItem;
        end;
      end;
      LPaletteToken := APalette.EncodeFeature(LObservation.Feature);
      LPublicToken := LTokenMap[LPaletteToken];
      if LPublicToken < 0 then
      begin
        LPublicToken := Length(LTokens);
        SetLength(LTokens, LPublicToken + 1);
        LTokens[LPublicToken] := AcousticToken(LPaletteToken);
        LTokenMap[LPaletteToken] := LPublicToken;
      end;
      LKey := 0;
      for LHistoryIndex := 0 to High(LHistory) do
      begin
        LKey := LKey * 33;
        if LHistory[LHistoryIndex].Kind = wshBos then
        begin
          Inc(LKey, 32);
        end
        else
        begin
          Inc(LKey, LHistory[LHistoryIndex].TokenIndex);
        end;
      end;
      LKey := LKey * 33 + LPublicToken;
      LSlot := LKey mod Length(LKeys);
      while (LKeys[LSlot] <> -1) and (LKeys[LSlot] <> LKey) do
      begin
        LWork.Visit;
        LSlot := (LSlot + 1) mod Length(LKeys);
      end;
      if LKeys[LSlot] = -1 then
      begin
        LStateIndex := Length(LStates);
        if LStateIndex >= WFC_SEQUENCE_MAX_STATE_COUNT then
        begin
          raise EAudio.Create('Journal learning exceeds companion state budget; choose a smaller vocabulary or order');
        end;
        LKeys[LSlot] := LKey;
        LValues[LSlot] := LStateIndex;
        SetLength(LStates, LStateIndex + 1);
        LStates[LStateIndex].History := Copy(LHistory);
        LStates[LStateIndex].EmittedTokenIndex := LPublicToken;
        SetLength(LStateCounts, LStateIndex + 1);
        SetLength(LStartCounts, LStateIndex + 1);
        SetLength(LEndCounts, LStateIndex + 1);
      end
      else
      begin
        LStateIndex := LValues[LSlot];
      end;
      LWeight := LObservation.Multiplicity;
      Inc(LStateCounts[LStateIndex], LWeight);
      Inc(LObserved, LWeight);
      LPosition := LObservation.FeatureIndex - LSegment.FirstFeature;
      if LPosition = 0 then
      begin
        Inc(LStartCounts[LStateIndex], LWeight);
      end;
      if LPosition = LSegment.FeatureCount - 1 then
      begin
        Inc(LEndCounts[LStateIndex], LWeight);
      end;
      for LHistoryIndex := 0 to High(LHistory) - 1 do
      begin
        LHistory[LHistoryIndex] := LHistory[LHistoryIndex + 1];
      end;
      if Length(LHistory) > 0 then
      begin
        LHistory[High(LHistory)] := MakeWfcSequenceTokenHistoryItem(LPublicToken);
      end;
    end;
    if LObserved <> AReader.WeightedObservationCount then
    begin
      raise EAudio.Create('Journal WFC weighted observation count differs');
    end;
    ReportWork(AProgress, 'journal_wfc_observations', wuObservations,
      AReader.ObservationCount, AReader.ObservationCount);
    LModel := TWfcSequenceModel.Create(AOrder, LLengths, LTokens, LStates,
      LStateCounts, LStartCounts, LEndCounts, wmbOpen, WfcSequenceWorkObserver(LWork));
    LWork.Finish;
    ReportWork(AProgress, 'journal_wfc_model_ready', wuItems, 1, 1);
    Result := LModel;
    LModel := nil;
  finally
    LModel.Free;
    LWork.Free;
  end;
end;

end.
