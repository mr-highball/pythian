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
unit pythian.wfc.context;

{$mode delphi}
{$H+}

interface

uses
  pythian.music.context,
  pythian.time,
  wfc_model,
  wfc_sequence;

const
  WfcMusicContextVersion = 1;
  KeyContextLayerId = 'pythian.context.key.v1';
  TempoContextLayerId = 'pythian.context.tempo.v1';

type
  TContextDimension = (cdKey, cdTempo);

function KeyContextToken(const AKey: TKeyContext): String;
function KeyContextFromToken(const AToken: String): TKeyContext;
function TempoContextToken(const AMicrosecondsPerQuarter: Integer): String;
function TempoContextFromToken(const AToken: String): Integer;

{ Explicit realization policy: a single observed value may hold over an output
  scope. No repeated training observations or changed model are constructed.
  Unknown key remains unknown. Multiple values require timed changes instead. }
function HeldContextToken(const AModel: TWfcSequenceModel;
  const ADimension: TContextDimension): String;

{ Generated tempo cells retain their own PPQ resolution. LengthTicks may end
  within the last used cell, but cannot exceed the supplied provider coverage.
  No implicit repetition, extrapolation or alignment to performance spans. }
function TempoClockFromTokens(const ATempos: TWfcModelTokens;
  const ATicksPerQuarter, AStepTicks, ALengthTicks: Integer): TTempoMap;

{ Independent finite key provider. Unknown values remain explicit. Callers
  choose how changes affect new attacks and notes already sounding. }
function KeyChangesFromTokens(const AKeys: TWfcModelTokens;
  const AStepTicks, ALengthTicks: Integer): TKeyChanges;

{ Each grid is one independent admitted song/excerpt. Same PPQ and step are
  required; no concatenation, normalization, evidence weighting or inference.
  Caller owns the returned actual WFC model. Key and tempo learn independently;
  any required joint relationships must be supplied as separate projections. }
function LearnContextModel(const AGrids: TMusicContextGrids;
  const ADimension: TContextDimension; const AOrder: Integer = 2): TWfcSequenceModel;

{ Builds a new output timeline at tick zero from equally sized generated
  provider sequences. Tempo directly drives the existing exact PPQ clock.
  Does not validate latent WFC paths or transpose/retime recorded audio. }
function MusicContextFromTokens(const AKeys, ATempos: TWfcModelTokens;
  const ATicksPerQuarter, AStepTicks: Integer): TMusicContext;

implementation

uses
  SysUtils,
  pythian.audio,
  pythian.tonal,
  wfc_sequence_learn;

function KeyChangesFromTokens(const AKeys: TWfcModelTokens;
  const AStepTicks, ALengthTicks: Integer): TKeyChanges;
var
  LIndex: Integer;
  LCount: Integer;
  LKey: TKeyContext;
begin
  if (Length(AKeys) < 1) or (Length(AKeys) > MaximumContextCells) or
    (AStepTicks < 1) or (ALengthTicks < 1) or
    (Int64(AStepTicks) * Length(AKeys) < ALengthTicks) then
  begin
    raise EAudio.Create('Key provider cells must cover the complete requested output extent');
  end;
  Result := nil;
  SetLength(Result, Length(AKeys));
  LCount := 0;
  for LIndex := 0 to High(AKeys) do
  begin
    LKey := KeyContextFromToken(AKeys[LIndex]);
    if Int64(LIndex) * AStepTicks >= ALengthTicks then
    begin
      Continue;
    end;
    if (LCount = 0) or not SameKeyContext(Result[LCount - 1].Key, LKey) then
    begin
      Result[LCount].Tick := LIndex * AStepTicks;
      Result[LCount].Key := LKey;
      Inc(LCount);
    end;
  end;
  SetLength(Result, LCount);
end;

function TempoClockFromTokens(const ATempos: TWfcModelTokens;
  const ATicksPerQuarter, AStepTicks, ALengthTicks: Integer): TTempoMap;
var
  LChanges: TTempoChanges;
  LIndex: Integer;
  LCount: Integer;
  LTempo: Integer;
begin
  if (Length(ATempos) < 1) or (Length(ATempos) > MaximumContextCells) or
    (AStepTicks < 1) or (ALengthTicks < 1) or
    (Int64(AStepTicks) * Length(ATempos) < ALengthTicks) then
  begin
    raise EAudio.Create('Tempo provider cells must cover the complete requested output extent');
  end;
  SetLength(LChanges, Length(ATempos));
  LCount := 0;
  for LIndex := 0 to High(ATempos) do
  begin
    LTempo := TempoContextFromToken(ATempos[LIndex]);
    if Int64(LIndex) * AStepTicks >= ALengthTicks then
    begin
      Continue;
    end;
    if (LCount = 0) or (LChanges[LCount - 1].MicrosecondsPerQuarter <> LTempo) then
    begin
      LChanges[LCount] := MakeTempoChange(LIndex * AStepTicks, LTempo);
      Inc(LCount);
    end;
  end;
  SetLength(LChanges, LCount);
  Result := TTempoMap.Create(ATicksPerQuarter, ALengthTicks, LChanges);
end;

function KeyContextToken(const AKey: TKeyContext): String;
begin
  MakeKeyContext(AKey.Root, AKey.Mode);
  if AKey.Root < 0 then
  begin
    Exit(KeyContextLayerId + '.unknown');
  end;
  Result := KeyContextLayerId + '.' + IntToStr(AKey.Root * 2 + Ord(AKey.Mode));
end;

function KeyContextFromToken(const AToken: String): TKeyContext;
var
  LCode: Integer;
begin
  if AToken = KeyContextLayerId + '.unknown' then
  begin
    Exit(MakeKeyContext(-1, dmMajor));
  end;
  LCode := StrToIntDef(Copy(AToken, Length(KeyContextLayerId) + 2, MaxInt), -1);
  if (LCode < 0) or (LCode > 23) then
  begin
    raise EAudio.Create('Unsupported key context token');
  end;
  Result := MakeKeyContext(LCode div 2, TDiatonicMode(LCode mod 2));
  if AToken <> KeyContextToken(Result) then
  begin
    raise EAudio.Create('Key context token is not canonical v1');
  end;
end;

function TempoContextToken(const AMicrosecondsPerQuarter: Integer): String;
begin
  MakeTempoChange(0, AMicrosecondsPerQuarter);
  Result := TempoContextLayerId + '.' + IntToStr(AMicrosecondsPerQuarter);
end;

function TempoContextFromToken(const AToken: String): Integer;
begin
  Result := StrToIntDef(Copy(AToken, Length(TempoContextLayerId) + 2, MaxInt), -1);
  if AToken <> TempoContextToken(Result) then
  begin
    raise EAudio.Create('Tempo context token is not canonical v1');
  end;
end;

function HeldContextToken(const AModel: TWfcSequenceModel;
  const ADimension: TContextDimension): String;
begin
  if (AModel = nil) or not (ADimension in [cdKey, cdTempo]) then
  begin
    raise EAudio.Create('Held context requires a model and known dimension');
  end;
  if AModel.PublicTokenCount <> 1 then
  begin
    raise EAudio.Create('Changing or alternative context values require explicit time scopes');
  end;
  Result := String(AModel.PublicTokenAt(0));
  if ADimension = cdKey then
  begin
    KeyContextFromToken(Result);
  end
  else
  begin
    TempoContextFromToken(Result);
  end;
end;

function LearnContextModel(const AGrids: TMusicContextGrids;
  const ADimension: TContextDimension; const AOrder: Integer): TWfcSequenceModel;
var
  LSamples: TWfcSequenceSamples;
  LTokens: TWfcModelTokens;
  LSample: Integer;
  LCell: Integer;
  LTotal: Int64;
begin
  if (Length(AGrids) < 1) or (Length(AGrids) > WFC_SEQUENCE_MAX_SAMPLE_COUNT) or
    (AOrder < 1) or (AOrder > 4) or not (ADimension in [cdKey, cdTempo]) then
  begin
    raise EAudio.Create('Context learning requires 1..4096 grids, a known dimension and order 1..4');
  end;
  LTotal := 0;
  for LSample := 0 to High(AGrids) do
  begin
    Inc(LTotal, Length(AGrids[LSample].Keys));
    if LTotal > MaximumContextCells then
    begin
      raise EAudio.Create('Context corpus exceeds 65536 observations');
    end;
    ValidateContextGrid(AGrids[LSample]);
    if (AGrids[LSample].TicksPerQuarter <> AGrids[0].TicksPerQuarter) or
      (AGrids[LSample].StepTicks <> AGrids[0].StepTicks) then
    begin
      raise EAudio.Create('Context corpus requires one explicit PPQ and step resolution');
    end;
  end;
  SetLength(LSamples, Length(AGrids));
  for LSample := 0 to High(AGrids) do
  begin
    SetLength(LTokens, Length(AGrids[LSample].Keys));
    for LCell := 0 to High(LTokens) do
    begin
      if ADimension = cdKey then
      begin
        LTokens[LCell] := KeyContextToken(AGrids[LSample].Keys[LCell]);
      end
      else
      begin
        LTokens[LCell] := TempoContextToken(AGrids[LSample].Tempos[LCell]);
      end;
    end;
    LSamples[LSample] := MakeWfcSequenceSample(LTokens);
  end;
  Result := LearnSequenceModelCorpus(LSamples, AOrder, wmbOpen);
end;

function MusicContextFromTokens(const AKeys, ATempos: TWfcModelTokens;
  const ATicksPerQuarter, AStepTicks: Integer): TMusicContext;
var
  LKeys: TKeyChanges;
  LTempos: TTempoChanges;
  LKey: TKeyContext;
  LTempo: Integer;
  LKeyCount: Integer;
  LTempoCount: Integer;
  LIndex: Integer;
  LClock: TTempoMap;
begin
  if (Length(AKeys) < 1) or (Length(AKeys) > MaximumContextCells) or
    (Length(AKeys) <> Length(ATempos)) or (ATicksPerQuarter < 1) or
    (AStepTicks < 1) then
  begin
    raise EAudio.Create('Generated context requires equally sized bounded providers and positive PPQ/step');
  end;
  if Int64(AStepTicks) * Length(AKeys) > High(Integer) then
  begin
    raise EAudio.Create('Generated context exceeds PPQ timeline extent');
  end;
  SetLength(LKeys, Length(AKeys));
  SetLength(LTempos, Length(AKeys));
  LKeyCount := 0;
  LTempoCount := 0;
  for LIndex := 0 to High(AKeys) do
  begin
    LKey := KeyContextFromToken(AKeys[LIndex]);
    LTempo := TempoContextFromToken(ATempos[LIndex]);
    if (LKeyCount = 0) or not SameKeyContext(LKeys[LKeyCount - 1].Key, LKey) then
    begin
      LKeys[LKeyCount].Tick := LIndex * AStepTicks;
      LKeys[LKeyCount].Key := LKey;
      Inc(LKeyCount);
    end;
    if (LTempoCount = 0) or
      (LTempos[LTempoCount - 1].MicrosecondsPerQuarter <> LTempo) then
    begin
      LTempos[LTempoCount] := MakeTempoChange(LIndex * AStepTicks, LTempo);
      Inc(LTempoCount);
    end;
  end;
  SetLength(LKeys, LKeyCount);
  SetLength(LTempos, LTempoCount);
  LClock := TTempoMap.Create(ATicksPerQuarter, AStepTicks * Length(AKeys), LTempos);
  try
    Result := TMusicContext.Create(LClock, LKeys);
  finally
    LClock.Free;
  end;
end;

end.
