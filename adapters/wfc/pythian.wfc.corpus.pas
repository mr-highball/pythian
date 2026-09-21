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
unit pythian.wfc.corpus;

{$mode delphi}
{$H+}

interface

uses
  pythian.audio,
  pythian.corpus,
  wfc_sequence;

const
  WfcCorpusAttachmentContract = 'pythian.wfc.sequence.v1';

{ Trains the actual companion model once and packages it with the corpus. }
function EncodeWfcAcousticCorpus(const ACorpus: TAcousticCorpusData;
  const AOrder: Integer = 2): TAudioBytes;
{ Loads without FFT, clustering or model learning. Independently checks every
  stored state count and sample boundary against the measured token corpus.
  Both returned objects are caller-owned. Failure sets AModel=nil. }
function DecodeWfcAcousticCorpus(const ABytes: TAudioBytes;
  out AModel: TWfcSequenceModel): TAcousticCorpusData;
procedure ValidateWfcCorpusModel(const ACorpus: TAcousticCorpusData;
  const AModel: TWfcSequenceModel);

implementation

uses
  pythian.corpus.archive,
  pythian.learning,
  pythian.wfc.learning,
  wfc_model,
  wfc_sequence_text;

procedure ValidateWfcCorpusModel(const ACorpus: TAcousticCorpusData;
  const AModel: TWfcSequenceModel);
const
  CAlphabet = MaximumAcousticVocabulary + 1;
var
  LLookup: array of Integer;
  LCounts: array of Integer;
  LStarts: array of Integer;
  LEnds: array of Integer;
  LSeen: array[0..MaximumAcousticVocabulary - 1] of Boolean;
  LRecording: TAcousticRecording;
  LHistory: TWfcSequenceHistoryItem;
  LKeyCount: Integer;
  LKey: Integer;
  LIndex: Integer;
  LSource: Integer;
  LFrame: Integer;
  LHistoryIndex: Integer;
  LPosition: Integer;
  LState: Integer;
  LToken: Integer;
begin
  if (ACorpus = nil) or (AModel = nil) then
  begin
    raise EAudio.Create('Corpus and companion model are required');
  end;
  if (AModel.Order < 1) or (AModel.Order > 4) or
    (AModel.Boundary <> wmbOpen) or
    (AModel.SampleCount <> ACorpus.SourceCount) or
    (AModel.ObservationCount <> ACorpus.FeatureCount) then
  begin
    raise EAudio.Create('Companion model shape disagrees with corpus');
  end;
  FillChar(LSeen, SizeOf(LSeen), 0);
  for LIndex := 0 to AModel.PublicTokenCount - 1 do
  begin
    if AcousticTokenIndex(AModel.PublicTokenAt(LIndex)) >= ACorpus.PaletteCount then
    begin
      raise EAudio.Create('Companion token is outside the persisted palette');
    end;
  end;
  LKeyCount := 1;
  for LIndex := 1 to AModel.Order do
  begin
    LKeyCount := LKeyCount * CAlphabet;
  end;
  { At most 33^4 entries (~4.6 MiB); no search/relearning and no quadratic scan. }
  SetLength(LLookup, LKeyCount);
  for LIndex := 0 to High(LLookup) do
  begin
    LLookup[LIndex] := -1;
  end;
  SetLength(LCounts, AModel.StateCount);
  SetLength(LStarts, AModel.StateCount);
  SetLength(LEnds, AModel.StateCount);
  for LState := 0 to AModel.StateCount - 1 do
  begin
    LKey := 0;
    for LHistoryIndex := 0 to AModel.HistorySize - 1 do
    begin
      LHistory := AModel.HistoryItemAt(LState, LHistoryIndex);
      LKey := LKey * CAlphabet;
      if LHistory.Kind = wshToken then
      begin
        Inc(LKey, AcousticTokenIndex(AModel.PublicTokenAt(LHistory.TokenIndex)) + 1);
      end;
    end;
    LKey := LKey * CAlphabet +
      AcousticTokenIndex(AModel.ProjectStateToken(LState)) + 1;
    if LLookup[LKey] >= 0 then
    begin
      raise EAudio.Create('Duplicate companion acoustic state');
    end;
    LLookup[LKey] := LState;
  end;
  for LSource := 0 to ACorpus.SourceCount - 1 do
  begin
    LRecording := ACorpus.RecordingAt(LSource);
    if AModel.SampleLengthAt(LSource) <> Length(LRecording.Tokens) then
    begin
      raise EAudio.Create('Companion sample length disagrees with recording boundary');
    end;
    for LFrame := 0 to High(LRecording.Tokens) do
    begin
      LSeen[LRecording.Tokens[LFrame]] := True;
      LKey := 0;
      for LHistoryIndex := 0 to AModel.Order - 1 do
      begin
        LKey := LKey * CAlphabet;
        LPosition := LFrame - AModel.Order + 1 + LHistoryIndex;
        if LPosition >= 0 then
        begin
          Inc(LKey, LRecording.Tokens[LPosition] + 1);
        end;
      end;
      LState := LLookup[LKey];
      if LState < 0 then
      begin
        raise EAudio.Create('Corpus observation is missing from companion model');
      end;
      Inc(LCounts[LState]);
      if LFrame = 0 then
      begin
        Inc(LStarts[LState]);
      end;
      if LFrame = High(LRecording.Tokens) then
      begin
        Inc(LEnds[LState]);
      end;
    end;
  end;
  for LState := 0 to AModel.StateCount - 1 do
  begin
    if (LCounts[LState] <> AModel.StateObservationCountAt(LState)) or
      (LStarts[LState] <> AModel.StartCountAt(LState)) or
      (LEnds[LState] <> AModel.EndCountAt(LState)) then
    begin
      raise EAudio.Create('Companion observation/boundary counts disagree with corpus');
    end;
  end;
  for LIndex := 0 to AModel.PublicTokenCount - 1 do
  begin
    LToken := AcousticTokenIndex(AModel.PublicTokenAt(LIndex));
    if not LSeen[LToken] then
    begin
      raise EAudio.Create('Companion vocabulary contains an unobserved token');
    end;
  end;
end;

function EncodeWfcAcousticCorpus(const ACorpus: TAcousticCorpusData;
  const AOrder: Integer): TAudioBytes;
var
  LSequences: TAcousticCorpus;
  LPalette: TAcousticPalette;
  LModel: TWfcSequenceModel;
  LIndex: Integer;
  LText: String;
  LBytes: TAudioBytes;
begin
  if ACorpus = nil then
  begin
    raise EAudio.Create('Corpus is required');
  end;
  SetLength(LSequences, ACorpus.SourceCount);
  for LIndex := 0 to High(LSequences) do
  begin
    LSequences[LIndex] := ACorpus.RecordingAt(LIndex).Tokens;
  end;
  LPalette := ACorpus.CopyPalette;
  try
    LModel := LearnAcousticModel(LSequences, LPalette, AOrder);
    try
      ValidateWfcCorpusModel(ACorpus, LModel);
      LText := EncodeWfcSequenceText(LModel);
      SetLength(LBytes, Length(LText));
      if Length(LBytes) > 0 then
      begin
        Move(LText[1], LBytes[0], Length(LBytes));
      end;
      Result := EncodeAcousticArchive(ACorpus, WfcCorpusAttachmentContract, LBytes);
    finally
      LModel.Free;
    end;
  finally
    LPalette.Free;
  end;
end;

function DecodeWfcAcousticCorpus(const ABytes: TAudioBytes;
  out AModel: TWfcSequenceModel): TAcousticCorpusData;
var
  LCorpus: TAcousticCorpusData;
  LModel: TWfcSequenceModel;
  LContract: UTF8String;
  LBytes: TAudioBytes;
  LText: String;
begin
  AModel := nil;
  LModel := nil;
  LCorpus := DecodeAcousticArchive(ABytes, LContract, LBytes);
  try
    if LContract <> WfcCorpusAttachmentContract then
    begin
      raise EAudio.Create('Archive does not contain a supported WFC acoustic model');
    end;
    SetLength(LText, Length(LBytes));
    if Length(LText) > 0 then
    begin
      Move(LBytes[0], LText[1], Length(LBytes));
    end;
    LModel := DecodeWfcSequenceText(LText);
    ValidateWfcCorpusModel(LCorpus, LModel);
    Result := LCorpus;
    AModel := LModel;
  except
    LModel.Free;
    LCorpus.Free;
    raise;
  end;
end;

end.
