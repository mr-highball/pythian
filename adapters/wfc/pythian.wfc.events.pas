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
unit pythian.wfc.events;

{$mode delphi}
{$H+}

interface

uses
  pythian.learning,
  pythian.passage,
  wfc_sequence;

const
  WfcEventAdapterVersion = 1;
  MaximumEventDurationClass = 4096;

type
  TAcousticEventSymbol = record
    AcousticIndex: Integer;
    DurationClass: Integer;
    StartsAtOnset: Boolean;
  end;
  TAcousticEventSymbols = array of TAcousticEventSymbol;
  TAcousticEventCorpus = array of TAcousticEventSymbols;

{ Duration classes use nearest positive frame quantum, with half ties upward.
  Actual source/output durations stay unquantized. One corpus must share the
  palette, sample rate and duration quantum; those remain caller-owned metadata. }
function AcousticEventSymbol(const AAcousticIndex, AFrames, AQuantumFrames: Integer;
  const AStartsAtOnset: Boolean): TAcousticEventSymbol;
function AcousticEventToken(const ASymbol: TAcousticEventSymbol): String;
function ParseAcousticEventToken(const AToken: String): TAcousticEventSymbol;
function LearnAcousticEventModel(const ACorpus: TAcousticEventCorpus;
  const APalette: TAcousticPalette; const AOrder: Integer = 2): TWfcSequenceModel;

{ Independent admission of saved vocabulary, state observations and run boundary
  counts. Uses no learning, clustering or FFT. The model must be open, order 1..4. }
procedure ValidateAcousticEventModel(const ACorpus: TAcousticEventCorpus;
  const APalette: TAcousticPalette; const AModel: TWfcSequenceModel);

{ Split chronological symbols into independent training samples. -1 excludes
  an interval; admitted runs must be dense, ordered and contiguous. Excluded
  symbols are ignored. An empty admission returns an empty corpus. }
function PartitionAcousticEvents(const ASymbols: TAcousticEventSymbols;
  const ARunIndices: TPassageIndices): TAcousticEventCorpus;

implementation

uses
  SysUtils,
  Math,
  pythian.audio,
  wfc_model,
  wfc_sequence_learn;

const
  CPrefix = 'pythian.event.v1.';

function PartitionAcousticEvents(const ASymbols: TAcousticEventSymbols;
  const ARunIndices: TPassageIndices): TAcousticEventCorpus;
var
  LCorpus: TAcousticEventCorpus;
  LCounts: TPassageIndices;
  LRun: Integer;
  LLastRun: Integer;
  LPrevious: Integer;
  LIndex: Integer;
begin
  if (Length(ASymbols) <> Length(ARunIndices)) or (Length(ASymbols) > 65536) then
  begin
    raise EAudio.Create('Event run shape exceeds bounds');
  end;
  SetLength(LCounts, Min(Length(ASymbols), WFC_SEQUENCE_MAX_SAMPLE_COUNT));
  LLastRun := -1;
  LPrevious := -1;
  for LIndex := 0 to High(ARunIndices) do
  begin
    LRun := ARunIndices[LIndex];
    if (LRun < -1) or (LRun >= Length(LCounts)) then
    begin
      raise EAudio.Create('Event run index exceeds bounds');
    end;
    if LRun >= 0 then
    begin
      if LRun <> LPrevious then
      begin
        if LRun <> LLastRun + 1 then
        begin
          raise EAudio.Create('Event runs must be dense, ordered and contiguous');
        end;
        LLastRun := LRun;
      end;
      Inc(LCounts[LRun]);
    end;
    LPrevious := LRun;
  end;
  SetLength(LCorpus, LLastRun + 1);
  for LRun := 0 to High(LCorpus) do
  begin
    SetLength(LCorpus[LRun], LCounts[LRun]);
    LCounts[LRun] := 0;
  end;
  for LIndex := 0 to High(ASymbols) do
  begin
    LRun := ARunIndices[LIndex];
    if LRun >= 0 then
    begin
      AcousticEventToken(ASymbols[LIndex]);
      LCorpus[LRun][LCounts[LRun]] := ASymbols[LIndex];
      Inc(LCounts[LRun]);
    end;
  end;
  Result := LCorpus;
end;

procedure ValidateSymbol(const ASymbol: TAcousticEventSymbol);
begin
  if (ASymbol.AcousticIndex < 0) or
    (ASymbol.AcousticIndex >= MaximumAcousticVocabulary) or
    (ASymbol.DurationClass < 1) or (ASymbol.DurationClass > MaximumEventDurationClass) then
  begin
    raise EAudio.Create('Acoustic event symbol exceeds its vocabulary bounds');
  end;
end;

function AcousticEventSymbol(const AAcousticIndex, AFrames, AQuantumFrames: Integer;
  const AStartsAtOnset: Boolean): TAcousticEventSymbol;
var
  LSymbol: TAcousticEventSymbol;
begin
  if (AFrames < 1) or (AFrames > MaximumClipSamples) or
    (AQuantumFrames < 1) or (AQuantumFrames > MaximumClipSamples) then
  begin
    raise EAudio.Create('Acoustic event duration and quantum require bounded positive frames');
  end;
  LSymbol.AcousticIndex := AAcousticIndex;
  LSymbol.DurationClass := Max(1, (Int64(AFrames) * 2 + AQuantumFrames) div
    (Int64(AQuantumFrames) * 2));
  LSymbol.StartsAtOnset := AStartsAtOnset;
  ValidateSymbol(LSymbol);
  Result := LSymbol;
end;

function AcousticEventToken(const ASymbol: TAcousticEventSymbol): String;
begin
  ValidateSymbol(ASymbol);
  Result := CPrefix + IntToStr(ASymbol.AcousticIndex) + '.' +
    IntToStr(ASymbol.DurationClass) + '.' + IntToStr(Ord(ASymbol.StartsAtOnset));
end;

function ParseAcousticEventToken(const AToken: String): TAcousticEventSymbol;
var
  LRest: String;
  LFields: array[0..2] of String;
  LField: Integer;
  LSeparator: Integer;
  LSymbol: TAcousticEventSymbol;
begin
  if (Length(AToken) > 80) or (Copy(AToken, 1, Length(CPrefix)) <> CPrefix) then
  begin
    raise EAudio.Create('Token is outside the acoustic event v1 contract');
  end;
  LRest := Copy(AToken, Length(CPrefix) + 1, Length(AToken));
  for LField := 0 to 1 do
  begin
    LSeparator := Pos('.', LRest);
    if LSeparator = 0 then
    begin
      raise EAudio.Create('Acoustic event token lacks a field');
    end;
    LFields[LField] := Copy(LRest, 1, LSeparator - 1);
    Delete(LRest, 1, LSeparator);
  end;
  LFields[2] := LRest;
  if not TryStrToInt(LFields[0], LSymbol.AcousticIndex) or
    not TryStrToInt(LFields[1], LSymbol.DurationClass) or
    ((LFields[2] <> '0') and (LFields[2] <> '1')) then
  begin
    raise EAudio.Create('Acoustic event token has invalid numeric fields');
  end;
  LSymbol.StartsAtOnset := LFields[2] = '1';
  if AcousticEventToken(LSymbol) <> AToken then
  begin
    raise EAudio.Create('Acoustic event token is not canonical');
  end;
  Result := LSymbol;
end;

function LearnAcousticEventModel(const ACorpus: TAcousticEventCorpus;
  const APalette: TAcousticPalette; const AOrder: Integer): TWfcSequenceModel;
var
  LSamples: TWfcSequenceSamples;
  LTokens: TWfcModelTokens;
  LSample: Integer;
  LIndex: Integer;
  LTotal: Int64;
begin
  if APalette = nil then
  begin
    raise EAudio.Create('Acoustic event learning requires a shared palette');
  end;
  if (Length(ACorpus) < 1) or (Length(ACorpus) > WFC_SEQUENCE_MAX_SAMPLE_COUNT) or
    (AOrder < 1) or (AOrder > 4) then
  begin
    raise EAudio.Create('Acoustic event learning supports 1..4096 samples and orders 1..4');
  end;
  LTotal := 0;
  for LSample := 0 to High(ACorpus) do
  begin
    if Length(ACorpus[LSample]) = 0 then
    begin
      raise EAudio.Create('Acoustic event learning samples cannot be empty');
    end;
    Inc(LTotal, Length(ACorpus[LSample]));
  end;
  if LTotal > 65536 then
  begin
    raise EAudio.Create('Acoustic event corpus exceeds the observation budget');
  end;
  SetLength(LSamples, Length(ACorpus));
  for LSample := 0 to High(ACorpus) do
  begin
    SetLength(LTokens, Length(ACorpus[LSample]));
    for LIndex := 0 to High(LTokens) do
    begin
      if ACorpus[LSample][LIndex].AcousticIndex >= APalette.Count then
      begin
        raise EAudio.Create('Acoustic event is outside the shared palette');
      end;
      LTokens[LIndex] := AcousticEventToken(ACorpus[LSample][LIndex]);
    end;
    LSamples[LSample] := MakeWfcSequenceSample(LTokens);
  end;
  Result := LearnSequenceModelCorpus(LSamples, AOrder, wmbOpen);
end;

type
  TEventModelKey = record
    Key: QWord;
    Index: Integer;
  end;
  TEventModelKeys = array of TEventModelKey;

procedure SortEventKeys(var AKeys: TEventModelKeys);
var
  LScratch: TEventModelKeys;

  procedure SortRange(const AFirst, ALast: Integer);
  var
    LMiddle: Integer;
    LLeft: Integer;
    LRight: Integer;
    I: Integer;
  begin
    if AFirst >= ALast then
    begin
      Exit;
    end;
    LMiddle := AFirst + (ALast - AFirst) div 2;
    SortRange(AFirst, LMiddle);
    SortRange(LMiddle + 1, ALast);
    LLeft := AFirst;
    LRight := LMiddle + 1;
    for I := AFirst to ALast do
    begin
      if (LLeft <= LMiddle) and
        ((LRight > ALast) or (AKeys[LLeft].Key <= AKeys[LRight].Key)) then
      begin
        LScratch[I] := AKeys[LLeft];
        Inc(LLeft);
      end
      else
      begin
        LScratch[I] := AKeys[LRight];
        Inc(LRight);
      end;
    end;
    for I := AFirst to ALast do
    begin
      AKeys[I] := LScratch[I];
    end;
  end;

begin
  SetLength(LScratch, Length(AKeys));
  SortRange(0, High(AKeys));
end;

function FindEventKey(const AKeys: TEventModelKeys; const AKey: QWord): Integer;
var
  LFirst: Integer;
  LLast: Integer;
  LMiddle: Integer;
begin
  LFirst := 0;
  LLast := High(AKeys);
  while LFirst <= LLast do
  begin
    LMiddle := LFirst + (LLast - LFirst) div 2;
    if AKeys[LMiddle].Key = AKey then
    begin
      Exit(AKeys[LMiddle].Index);
    end;
    if AKeys[LMiddle].Key < AKey then
    begin
      LFirst := LMiddle + 1;
    end
    else
    begin
      LLast := LMiddle - 1;
    end;
  end;
  Result := -1;
end;

function EventSymbolCode(const ASymbol: TAcousticEventSymbol): Integer;
begin
  ValidateSymbol(ASymbol);
  Result := (ASymbol.AcousticIndex * MaximumEventDurationClass +
    ASymbol.DurationClass - 1) * 2 + Ord(ASymbol.StartsAtOnset);
end;

procedure ValidateAcousticEventModel(const ACorpus: TAcousticEventCorpus;
  const APalette: TAcousticPalette; const AModel: TWfcSequenceModel);
var
  LTokenKeys: TEventModelKeys;
  LStateKeys: TEventModelKeys;
  LCounts: TPassageIndices;
  LStarts: TPassageIndices;
  LEnds: TPassageIndices;
  LTokens: TPassageIndices;
  LSeen: array of Boolean;
  LHistory: TWfcSequenceHistoryItem;
  LSymbol: TAcousticEventSymbol;
  LKey: QWord;
  LBase: QWord;
  LTotal: Integer;
  LState: Integer;
  LToken: Integer;
  LPosition: Integer;
  I: Integer;
  J: Integer;
  K: Integer;
begin
  if (APalette = nil) or (AModel = nil) then
  begin
    raise EAudio.Create('Event model admission requires palette and model');
  end;
  if (Length(ACorpus) < 1) or (Length(ACorpus) > WFC_SEQUENCE_MAX_SAMPLE_COUNT) or
    (AModel.SampleCount <> Length(ACorpus)) or (AModel.Boundary <> wmbOpen) or
    (AModel.Order < 1) or (AModel.Order > 4) or
    (AModel.PublicTokenCount > WFC_SEQUENCE_MAX_STATE_COUNT) then
  begin
    raise EAudio.Create('Event model shape disagrees with training contract');
  end;
  LTotal := 0;
  for I := 0 to High(ACorpus) do
  begin
    if (Length(ACorpus[I]) < 1) or (Length(ACorpus[I]) > 65536 - LTotal) or
      (AModel.SampleLengthAt(I) <> Length(ACorpus[I])) then
    begin
      raise EAudio.Create('Event model run length or observation budget disagrees');
    end;
    Inc(LTotal, Length(ACorpus[I]));
  end;
  if AModel.ObservationCount <> LTotal then
  begin
    raise EAudio.Create('Event model observation total disagrees');
  end;
  SetLength(LTokenKeys, AModel.PublicTokenCount);
  SetLength(LSeen, AModel.PublicTokenCount);
  for I := 0 to High(LTokenKeys) do
  begin
    LSymbol := ParseAcousticEventToken(AModel.PublicTokenAt(I));
    if LSymbol.AcousticIndex >= APalette.Count then
    begin
      raise EAudio.Create('Saved event token is outside palette');
    end;
    LTokenKeys[I].Key := EventSymbolCode(LSymbol);
    LTokenKeys[I].Index := I;
  end;
  SortEventKeys(LTokenKeys);
  LBase := AModel.PublicTokenCount + 1;
  SetLength(LStateKeys, AModel.StateCount);
  SetLength(LCounts, AModel.StateCount);
  SetLength(LStarts, AModel.StateCount);
  SetLength(LEnds, AModel.StateCount);
  for I := 0 to High(LStateKeys) do
  begin
    LKey := 0;
    for J := 0 to AModel.HistorySize - 1 do
    begin
      LKey := LKey * LBase;
      LHistory := AModel.HistoryItemAt(I, J);
      if LHistory.Kind = wshToken then
      begin
        Inc(LKey, LHistory.TokenIndex + 1);
      end;
    end;
    LStateKeys[I].Key := LKey * LBase + AModel.StateEmittedTokenIndexAt(I) + 1;
    LStateKeys[I].Index := I;
  end;
  { At most four base-1025 digits fit QWord. Sorted observed keys avoid an
    alphabet^order allocation and retain deterministic bounded lookup. }
  SortEventKeys(LStateKeys);
  for I := 1 to High(LStateKeys) do
  begin
    if LStateKeys[I - 1].Key = LStateKeys[I].Key then
    begin
      raise EAudio.Create('Duplicate saved event state');
    end;
  end;
  for I := 0 to High(ACorpus) do
  begin
    SetLength(LTokens, Length(ACorpus[I]));
    for J := 0 to High(LTokens) do
    begin
      LToken := FindEventKey(LTokenKeys, EventSymbolCode(ACorpus[I][J]));
      if LToken < 0 then
      begin
        raise EAudio.Create('Measured event is absent from saved vocabulary');
      end;
      LTokens[J] := LToken;
      LSeen[LToken] := True;
      LKey := 0;
      for K := 0 to AModel.Order - 1 do
      begin
        LKey := LKey * LBase;
        LPosition := J - AModel.Order + 1 + K;
        if LPosition >= 0 then
        begin
          Inc(LKey, LTokens[LPosition] + 1);
        end;
      end;
      LState := FindEventKey(LStateKeys, LKey);
      if LState < 0 then
      begin
        raise EAudio.Create('Measured event history is absent from saved model');
      end;
      Inc(LCounts[LState]);
      if J = 0 then
      begin
        Inc(LStarts[LState]);
      end;
      if J = High(LTokens) then
      begin
        Inc(LEnds[LState]);
      end;
    end;
  end;
  for I := 0 to AModel.StateCount - 1 do
  begin
    if (LCounts[I] <> AModel.StateObservationCountAt(I)) or
      (LStarts[I] <> AModel.StartCountAt(I)) or (LEnds[I] <> AModel.EndCountAt(I)) then
    begin
      raise EAudio.Create('Saved event state or boundary counts disagree with admitted runs');
    end;
  end;
  for I := 0 to High(LSeen) do
  begin
    if not LSeen[I] then
    begin
      raise EAudio.Create('Saved event vocabulary contains an unobserved token');
    end;
  end;
end;

end.
