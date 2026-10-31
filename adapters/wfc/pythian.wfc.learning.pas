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
unit pythian.wfc.learning;

{$mode delphi}
{$H+}

interface

uses
  pythian.learning,
  pythian.progress,
  wfc_model,
  wfc_sequence;

const
  WfcAcousticAdapterVersion = 1;

type
  TAcousticCorpus = array of TAcousticIndices;
  TWeightedSequenceSample = record
    Tokens: TWfcModelTokens;
    Weight: Integer;
  end;
  TWeightedSequenceSamples = array of TWeightedSequenceSample;

{ Whole-sample multiplicity: repeats evidence without joining sample boundaries.
  Zero excludes a sample. This changes training counts, never generation prefs.
  Inputs are borrowed synchronously; positive samples require 1..64 copies.
  The caller supplies a bounded observation budget, at most 1048576; actual
  companion sample/state limits still apply. No partial model is published. }
function LearnWeightedSequenceModel(const ASamples: TWeightedSequenceSamples;
  const AOrder: Integer; const AMaximumObservations: Integer = 65536;
  const AProgress: TWorkProgressCallback = nil): TWfcSequenceModel;

{ Each recording/excerpt remains a separate sample: no cross-file transition.
  All sequences must use one shared palette; the caller retains that palette. }
function LearnAcousticModel(const ACorpus: TAcousticCorpus;
  const APalette: TAcousticPalette; const AOrder: Integer = 2): TWfcSequenceModel;
function AcousticToken(const AIndex: Integer): String;
function AcousticTokenIndex(const AToken: String): Integer;

implementation

uses
  SysUtils,
  pythian.audio,
  pythian.wfc.progress,
  wfc_sequence_learn;

function LearnWeightedSequenceModel(const ASamples: TWeightedSequenceSamples;
  const AOrder, AMaximumObservations: Integer;
  const AProgress: TWorkProgressCallback): TWfcSequenceModel;
var
  LExpanded: TWfcSequenceSamples;
  LCount: Integer;
  I: Integer;
  J: Integer;
  LAt: Integer;
  LTotal: Int64;
  LBridge: TWfcSolveProgressBridge;
begin
  if (Length(ASamples) < 1) or (Length(ASamples) > WFC_SEQUENCE_MAX_SAMPLE_COUNT) or
    (AOrder < 1) or (AOrder > WFC_SEQUENCE_MAX_ORDER) or (AMaximumObservations < 1) or
    (AMaximumObservations > 1048576) or (AOrder <> Trunc(AOrder)) or
    (AMaximumObservations <> Trunc(AMaximumObservations)) then
  begin
    raise EAudio.Create('Weighted learning requires bounded samples, observations and a supported integer order');
  end;
  LCount := 0;
  LTotal := 0;
  for I := 0 to High(ASamples) do
  begin
    ReportWork(AProgress, 'wfc_weighted_admission', wuItems, I, Length(ASamples));
    if (ASamples[I].Weight < 0) or (ASamples[I].Weight > 64) or
      (ASamples[I].Weight <> Trunc(ASamples[I].Weight)) then
    begin
      raise EAudio.Create('Training multiplicity must be an integer 0..64');
    end;
    if ASamples[I].Weight = 0 then
    begin
      Continue;
    end;
    if (Length(ASamples[I].Tokens) = 0) or
      (LCount > WFC_SEQUENCE_MAX_SAMPLE_COUNT - ASamples[I].Weight) then
    begin
      raise EAudio.Create('Weighted sample count exceeds companion limit or includes empty material');
    end;
    Inc(LCount, ASamples[I].Weight);
    Inc(LTotal, Int64(Length(ASamples[I].Tokens)) * ASamples[I].Weight);
    if LTotal > AMaximumObservations then
    begin
      raise EAudio.Create('Weighted musical observations exceed the declared model budget');
    end;
  end;
  if LCount = 0 then
  begin
    raise EAudio.Create('Learning requires a positive training contribution');
  end;
  SetLength(LExpanded, LCount);
  LAt := 0;
  for I := 0 to High(ASamples) do
  begin
    for J := 1 to ASamples[I].Weight do
    begin
      ReportWork(AProgress, 'wfc_weighted_samples', wuItems, LAt, LCount);
      LExpanded[LAt] := MakeWfcSequenceSample(ASamples[I].Tokens);
      Inc(LAt);
    end;
  end;
  LBridge := TWfcSolveProgressBridge.Create(AProgress);
  try
    Result := LearnSequenceModelCorpus(LExpanded, AOrder, wmbOpen,
      LBridge.SequenceWorkObserver());
  finally
    LBridge.Free;
  end;
end;

function AcousticToken(const AIndex: Integer): String;
begin
  if (AIndex < 0) or (AIndex >= MaximumAcousticVocabulary) then
  begin
    raise EAudio.Create('Acoustic token index outside vocabulary budget');
  end;
  Result := 'pythian.acoustic.v1.' + IntToStr(AIndex);
end;

function LearnAcousticModel(const ACorpus: TAcousticCorpus;
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
    raise EAudio.Create('Shared acoustic palette is required');
  end;
  if (Length(ACorpus) < 1) or (Length(ACorpus) > WFC_SEQUENCE_MAX_SAMPLE_COUNT) or
    (AOrder < 1) or (AOrder > 4) then
  begin
    raise EAudio.Create('Acoustic model supports 1..4096 samples and orders 1..4');
  end;
  LTotal := 0;
  for LSample := 0 to High(ACorpus) do
  begin
    Inc(LTotal, Length(ACorpus[LSample]));
  end;
  if LTotal > 65536 then
  begin
    raise EAudio.Create('Acoustic corpus exceeds observation budget');
  end;
  SetLength(LSamples, Length(ACorpus));
  for LSample := 0 to High(ACorpus) do
  begin
    if Length(ACorpus[LSample]) = 0 then
    begin
      raise EAudio.Create('Acoustic learning samples cannot be empty');
    end;
    SetLength(LTokens, Length(ACorpus[LSample]));
    for LIndex := 0 to High(LTokens) do
    begin
      if (ACorpus[LSample][LIndex] < 0) or (ACorpus[LSample][LIndex] >= APalette.Count) then
      begin
        raise EAudio.Create('Acoustic token is not in the shared palette');
      end;
      LTokens[LIndex] := AcousticToken(ACorpus[LSample][LIndex]);
    end;
    LSamples[LSample] := MakeWfcSequenceSample(LTokens);
  end;
  Result := LearnSequenceModelCorpus(LSamples, AOrder, wmbOpen);
end;

function AcousticTokenIndex(const AToken: String): Integer;
var
  LIndex: Integer;
begin
  for LIndex := 0 to MaximumAcousticVocabulary - 1 do
  begin
    if AToken = AcousticToken(LIndex) then
    begin
      Exit(LIndex);
    end;
  end;
  raise EAudio.Create('Token does not belong to the acoustic v1 contract');
end;

end.
