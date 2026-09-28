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
unit pythian.learning.context.guard;

{$mode delphi}
{$H+}

interface

uses
  pythian.audio, pythian.learning, pythian.learning.journal,
  pythian.learning.selection,
  pythian.learning.context;

const
  MaximumJournalGuardGrains = 32768;
  MaximumJournalGuardChunkGrains = 4096;
  MaximumJournalGuardVisits = 128000000;

type
  TJournalNoveltyReport = record
    ContextAccepted: Boolean;
    FirstRejectedGrain: Integer;
    BaselineRepeatedFour: Integer;
    SelectedRepeatedFour: Integer;
    WorkVisits: Int64;
  end;

  { Borrows a stable pool. Each call commits one complete fixed WFC chunk or
    fails without changing history. The caller binds pool/context source extents
    to verified media. Exact four-window identity uses segment, feature and
    original source frame; hash collisions are always checked against all four. }
  TJournalGlobalRepetitionGuard = class
  private
    FPool: TJournalCandidatePool;
    FMaximumGrains: Integer;
    FBaseline: TJournalContextWindows;
    FSelected: TJournalContextWindows;
    FWorkVisits: Int64;
    FMaximumVisits: Int64;
    function GetGrainCount: Integer;
  public
    constructor Create(const APool: TJournalCandidatePool;
      const AMaximumGrains: Integer;
      const AMaximumVisits: Int64 = MaximumJournalGuardVisits);
    function SelectChunk(const ABaseline: TAcousticIndices;
      const AContext: TJournalContextWindows;
      out AReport: TJournalNoveltyReport): TJournalContextWindows;
    property GrainCount: Integer read GetGrainCount;
    property WorkVisits: Int64 read FWorkVisits;
  end;

implementation

const
  HashCapacity = 131072;

type
  THashSlots = array of Integer;
  TPrefixCounts = array of Integer;

procedure Require(const AValue: Boolean; const AMessage: String);
begin
  if not AValue then raise EAudio.Create(AMessage);
end;

function SameWindow(const ALeft, ARight: TJournalContextWindow): Boolean;
begin
  Result := (ALeft.Candidate.SegmentIndex = ARight.Candidate.SegmentIndex) and
    (ALeft.Candidate.FeatureIndex = ARight.Candidate.FeatureIndex) and
    (ALeft.Candidate.SourceFrame = ARight.Candidate.SourceFrame);
end;

function SameFour(const AWindows: TJournalContextWindows;
  const ALeft, ARight: Integer; var AVisits: Int64): Boolean;
var
  LOffset: Integer;
begin
  Result := True;
  for LOffset := 0 to 3 do
  begin
    Inc(AVisits);
    if not SameWindow(AWindows[ALeft + LOffset],
      AWindows[ARight + LOffset]) then Exit(False);
  end;
end;

function Mix(const AHash, AValue: QWord): QWord;
begin
  Result := AHash xor AValue;
  Result := (Result shl 7) or (Result shr 57);
end;

function FourHash(const AWindows: TJournalContextWindows;
  const AStart: Integer): QWord;
var
  LOffset: Integer;
begin
  Result := QWord(14695981039346656037);
  for LOffset := 0 to 3 do
  begin
    Result := Mix(Result,
      QWord(AWindows[AStart + LOffset].Candidate.SegmentIndex));
    Result := Mix(Result,
      QWord(AWindows[AStart + LOffset].Candidate.FeatureIndex));
    Result := Mix(Result,
      QWord(AWindows[AStart + LOffset].Candidate.SourceFrame));
  end;
end;

procedure ScanPrefix(const AWindows: TJournalContextWindows;
  const AOriginalLength: Integer; const AReference: TPrefixCounts;
  const AStopAtExcess: Boolean; const AMaximumVisits: Int64;
  var AVisits: Int64;
  out ACounts: TPrefixCounts; out AFirstExcess: Integer);
var
  LTable: THashSlots;
  LIndex, LStart, LBucket, LProbe, LOld: Integer;
  LHash: QWord;
  LRepeated: Boolean;
begin
  Require(Length(AWindows) <= MaximumJournalGuardGrains,
    'Guard prefix exceeds grain bound');
  SetLength(LTable, HashCapacity);
  FillChar(LTable[0], HashCapacity * SizeOf(Integer), $FF);
  SetLength(ACounts, Length(AWindows));
  AFirstExcess := -1;
  for LIndex := 0 to High(AWindows) do
  begin
    if LIndex > 0 then ACounts[LIndex] := ACounts[LIndex - 1];
    if LIndex >= 3 then
    begin
      LStart := LIndex - 3;
      LHash := FourHash(AWindows, LStart);
      LBucket := Integer(LHash and (HashCapacity - 1));
      LRepeated := False;
      for LProbe := 0 to HashCapacity - 1 do
      begin
        Inc(AVisits);
        Require(AVisits <= AMaximumVisits,
          'Guard work visits exceeded');
        LOld := LTable[LBucket];
        if LOld < 0 then
        begin
          LTable[LBucket] := LStart;
          Break;
        end;
        if SameFour(AWindows, LOld, LStart, AVisits) then
        begin
          LRepeated := True;
          Break;
        end;
        LBucket := (LBucket + 1) and (HashCapacity - 1);
      end;
      Require(LProbe < HashCapacity, 'Guard hash capacity exceeded');
      Require(AVisits <= AMaximumVisits,
        'Guard work visits exceeded');
      if LRepeated then Inc(ACounts[LIndex]);
    end;
    if AStopAtExcess and (LIndex >= AOriginalLength) and
      (ACounts[LIndex] > AReference[LIndex]) then
    begin
      AFirstExcess := LIndex;
      Exit;
    end;
  end;
end;

constructor TJournalGlobalRepetitionGuard.Create(
  const APool: TJournalCandidatePool; const AMaximumGrains: Integer;
  const AMaximumVisits: Int64);
begin
  inherited Create;
  if (APool = nil) or (AMaximumGrains < 1) or
    (AMaximumGrains > MaximumJournalGuardGrains) or
    (AMaximumVisits < 1) or
    (AMaximumVisits > MaximumJournalGuardVisits) then
    raise EAudio.Create('Guard requires a pool and bounded total grain count');
  FPool := APool;
  FMaximumGrains := AMaximumGrains;
  FMaximumVisits := AMaximumVisits;
end;

function TJournalGlobalRepetitionGuard.GetGrainCount: Integer;
begin
  Result := Length(FSelected);
end;

function TJournalGlobalRepetitionGuard.SelectChunk(
  const ABaseline: TAcousticIndices; const AContext: TJournalContextWindows;
  out AReport: TJournalNoveltyReport): TJournalContextWindows;
var
  LBaseline, LTrial, LSelected: TJournalContextWindows;
  LBaseCounts, LTrialCounts, LSelectedCounts: TPrefixCounts;
  LQuota: array of Integer;
  LOldCount, LNewCount, LIndex, LKey, LTokenCount, LSegmentCount,
    LFirstExcess, LContextExcess: Integer;
  LVisits: Int64;
  LCandidate: TJournalRepresentative;
  LWindow: TJournalContextWindow;
begin
  Result := nil;
  Require((Length(ABaseline) > 0) and
    (Length(ABaseline) <= MaximumJournalGuardChunkGrains) and
    (Length(AContext) = Length(ABaseline)),
    'Guard chunk lengths invalid');
  LOldCount := Length(FBaseline);
  LNewCount := LOldCount + Length(ABaseline);
  Require(LNewCount <= FMaximumGrains, 'Guard total grain bound exceeded');
  LTokenCount := FPool.TokenAt(FPool.SlotCount - 1) + 1;
  LSegmentCount := FPool.SegmentCount;
  SetLength(LQuota, LTokenCount * LSegmentCount);
  LBaseline := Copy(FBaseline, 0, LOldCount);
  SetLength(LBaseline, LNewCount);
  LSelected := Copy(FSelected, 0, LOldCount);
  SetLength(LSelected, LNewCount);
  for LIndex := 0 to High(ABaseline) do
  begin
    LCandidate := FPool.CandidateAt(ABaseline[LIndex]);
    Require(LCandidate.Found and (LCandidate.ValidFrames >= 1) and
      (LCandidate.ValidFrames <= 65536) and
      (LCandidate.SourceFrame >= 0) and (LCandidate.FeatureIndex >= 0) and
      (LCandidate.SegmentIndex >= 0) and
      (LCandidate.SegmentIndex < LSegmentCount),
      'Guard baseline candidate invalid');
    LWindow.Token := FPool.TokenAt(ABaseline[LIndex]);
    LWindow.Candidate := LCandidate;
    LBaseline[LOldCount + LIndex] := LWindow;
    Inc(LQuota[LWindow.Token * LSegmentCount + LCandidate.SegmentIndex]);
    LWindow := AContext[LIndex];
    Require((LWindow.Token = LBaseline[LOldCount + LIndex].Token) and
      LWindow.Candidate.Found and
      (LWindow.Candidate.ValidFrames >= 1) and
      (LWindow.Candidate.ValidFrames <= 65536) and
      (LWindow.Candidate.SourceFrame >= 0) and
      (LWindow.Candidate.FeatureIndex >= 0) and
      (LWindow.Candidate.SegmentIndex >= 0) and
      (LWindow.Candidate.SegmentIndex < LSegmentCount),
      'Guard context candidate or token invalid');
    LKey := LWindow.Token * LSegmentCount +
      LWindow.Candidate.SegmentIndex;
    Dec(LQuota[LKey]);
  end;
  for LIndex := 0 to High(LQuota) do
    Require(LQuota[LIndex] = 0, 'Guard context changes token/source counts');
  LVisits := FWorkVisits;
  ScanPrefix(LBaseline, LOldCount, nil, False, FMaximumVisits, LVisits,
    LBaseCounts, LFirstExcess);
  LTrial := Copy(FSelected, 0, LOldCount);
  SetLength(LTrial, LNewCount);
  for LIndex := 0 to High(AContext) do
    LTrial[LOldCount + LIndex] := AContext[LIndex];
  ScanPrefix(LTrial, LOldCount, LBaseCounts, True, FMaximumVisits, LVisits,
    LTrialCounts, LContextExcess);
  if LContextExcess < 0 then
  begin
    LSelected := LTrial;
    LSelectedCounts := LTrialCounts;
  end
  else
  begin
    for LIndex := 0 to High(ABaseline) do
      LSelected[LOldCount + LIndex] := LBaseline[LOldCount + LIndex];
    ScanPrefix(LSelected, LOldCount, LBaseCounts, True, FMaximumVisits, LVisits,
      LSelectedCounts, LFirstExcess);
    Require(LFirstExcess < 0,
      'Guard baseline fallback exceeds prior repetition prefix');
  end;
  Require((Length(LBaseCounts) = LNewCount) and
    (Length(LSelectedCounts) = LNewCount),
    'Guard prefix scan incomplete');
  AReport.ContextAccepted := LContextExcess < 0;
  AReport.FirstRejectedGrain := LContextExcess;
  AReport.BaselineRepeatedFour := LBaseCounts[LNewCount - 1];
  AReport.SelectedRepeatedFour := LSelectedCounts[LNewCount - 1];
  AReport.WorkVisits := LVisits;
  Result := Copy(LSelected, LOldCount, Length(ABaseline));
  FBaseline := LBaseline;
  FSelected := LSelected;
  FWorkVisits := LVisits;
end;

end.
