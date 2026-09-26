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
unit pythian.wfc.joint.archive;

{$mode delphi}
{$H+}

interface

uses
  pythian.audio,
  pythian.activity,
  pythian.corpus,
  wfc_sequence;

const
  WfcJointAttachmentContract = 'pythian.wfc.joint.v1';

{ Checks actual saved state/sample/boundary counts against the paired measured
  corpus. Recomputes activity from features, with no FFT, clustering or learning. }
procedure ValidateWfcJointCorpusModel(const ACorpus: TAcousticCorpusData;
  const AModel: TWfcSequenceModel; const AActivity: TActivityOptions);

{ Saves an already trained model after independent admission. No learning.
  The corpus archive remains unchanged; the attachment contains exact activity
  options and the actual WFC text model under a distinct versioned contract. }
function EncodeWfcJointCorpus(const ACorpus: TAcousticCorpusData;
  const AModel: TWfcSequenceModel; const AActivity: TActivityOptions): TAudioBytes;

{ Returns detached, caller-owned corpus/model and the stored activity policy.
  Use that policy for action-aware planning. Failure sets model=nil and clears
  activity options; no partial object escapes. Core validates the outer digest. }
function DecodeWfcJointCorpus(const ABytes: TAudioBytes;
  out AModel: TWfcSequenceModel; out AActivity: TActivityOptions): TAcousticCorpusData;

implementation

uses
  pythian.corpus.archive,
  pythian.learning,
  pythian.wfc.joint,
  wfc_model,
  wfc_sequence_text;

const
  JointHeaderBytes = 48;
  PairCount = MaximumAcousticVocabulary * 3;
  PairAlphabet = PairCount + 1;

type
  TStateKey = record
    Key: Integer;
    State: Integer;
  end;
  TStateKeys = array of TStateKey;

procedure SortKeys(var AKeys: TStateKeys);
var
  LScratch: TStateKeys;

  procedure SortRange(const AFirst, ALast: Integer);
  var
    LMiddle: Integer;
    LLeft: Integer;
    LRight: Integer;
    LIndex: Integer;
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
    for LIndex := AFirst to ALast do
    begin
      if (LLeft <= LMiddle) and
        ((LRight > ALast) or (AKeys[LLeft].Key <= AKeys[LRight].Key)) then
      begin
        LScratch[LIndex] := AKeys[LLeft];
        Inc(LLeft);
      end
      else
      begin
        LScratch[LIndex] := AKeys[LRight];
        Inc(LRight);
      end;
    end;
    for LIndex := AFirst to ALast do
    begin
      AKeys[LIndex] := LScratch[LIndex];
    end;
  end;

begin
  SetLength(LScratch, Length(AKeys));
  SortRange(0, High(AKeys));
end;

function FindState(const AKeys: TStateKeys; const AKey: Integer): Integer;
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
      Exit(AKeys[LMiddle].State);
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

procedure ValidateWfcJointCorpusModel(const ACorpus: TAcousticCorpusData;
  const AModel: TWfcSequenceModel; const AActivity: TActivityOptions);
var
  LKeys: TStateKeys;
  LCounts: array of Integer;
  LStarts: array of Integer;
  LEnds: array of Integer;
  LCodes: array of Integer;
  LSeen: array[0..PairCount - 1] of Boolean;
  LRecording: TAcousticRecording;
  LActivity: TAcousticActivity;
  LHistory: TWfcSequenceHistoryItem;
  LAction: TAcousticAction;
  LIndex: Integer;
  LToken: Integer;
  LKey: Integer;
  LState: Integer;
  LSource: Integer;
  LFrame: Integer;
  LPosition: Integer;
  LHistoryIndex: Integer;
  LCode: Integer;
begin
  if (ACorpus = nil) or (AModel = nil) then
  begin
    raise EAudio.Create('Joint corpus and model are required');
  end;
  ValidateActivityOptions(AActivity);
  if (AModel.Order < 1) or (AModel.Order > 4) or
    (AModel.Boundary <> wmbOpen) or
    (AModel.SampleCount <> ACorpus.SourceCount) or
    (AModel.ObservationCount <> ACorpus.FeatureCount) or
    (AModel.StateCount > ACorpus.FeatureCount) or
    (AModel.PublicTokenCount > PairCount) then
  begin
    raise EAudio.Create('Joint model shape disagrees with measured corpus');
  end;
  FillChar(LSeen, SizeOf(LSeen), 0);
  SetLength(LCodes, AModel.PublicTokenCount);
  for LIndex := 0 to AModel.PublicTokenCount - 1 do
  begin
    DecodeJointAcousticToken(AModel.PublicTokenAt(LIndex), LToken, LAction);
    if LToken >= ACorpus.PaletteCount then
    begin
      raise EAudio.Create('Joint token is outside the persisted palette');
    end;
    LCodes[LIndex] := LToken * 3 + Ord(LAction) + 1;
  end;
  SetLength(LKeys, AModel.StateCount);
  SetLength(LCounts, AModel.StateCount);
  SetLength(LStarts, AModel.StateCount);
  SetLength(LEnds, AModel.StateCount);
  for LState := 0 to AModel.StateCount - 1 do
  begin
    LKey := 0;
    for LHistoryIndex := 0 to AModel.HistorySize - 1 do
    begin
      LKey := LKey * PairAlphabet;
      LHistory := AModel.HistoryItemAt(LState, LHistoryIndex);
      if LHistory.Kind = wshToken then
      begin
        Inc(LKey, LCodes[LHistory.TokenIndex]);
      end;
    end;
    LKey := LKey * PairAlphabet + LCodes[AModel.StateEmittedTokenIndexAt(LState)];
    LKeys[LState].Key := LKey;
    LKeys[LState].State := LState;
  end;
  { A dense 97^4 lookup would cost hundreds of MiB. Sorted observed keys need
    O(states) storage and deterministic O(log states) lookup, including hostile
    collision patterns. Four base-97 digits fit signed Integer. }
  SortKeys(LKeys);
  for LIndex := 1 to High(LKeys) do
  begin
    if LKeys[LIndex - 1].Key = LKeys[LIndex].Key then
    begin
      raise EAudio.Create('Duplicate joint acoustic/activity state');
    end;
  end;
  for LSource := 0 to ACorpus.SourceCount - 1 do
  begin
    LRecording := ACorpus.RecordingAt(LSource);
    if AModel.SampleLengthAt(LSource) <> Length(LRecording.Tokens) then
    begin
      raise EAudio.Create('Joint sample length disagrees with recording boundary');
    end;
    LActivity := AnalyzeAcousticActivity(LRecording.Features, ACorpus.Options,
      LRecording.Info.FrameCount, AActivity);
    for LFrame := 0 to High(LRecording.Tokens) do
    begin
      LKey := 0;
      for LHistoryIndex := 0 to AModel.Order - 1 do
      begin
        LKey := LKey * PairAlphabet;
        LPosition := LFrame - AModel.Order + 1 + LHistoryIndex;
        if LPosition >= 0 then
        begin
          LCode := LRecording.Tokens[LPosition] * 3 + Ord(LActivity.Actions[LPosition]) + 1;
          Inc(LKey, LCode);
        end;
      end;
      LSeen[LRecording.Tokens[LFrame] * 3 + Ord(LActivity.Actions[LFrame])] := True;
      LState := FindState(LKeys, LKey);
      if LState < 0 then
      begin
        raise EAudio.Create('Measured paired observation is missing from joint model');
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
      raise EAudio.Create('Joint observation or boundary counts disagree with corpus');
    end;
  end;
  for LIndex := 0 to High(LCodes) do
  begin
    if not LSeen[LCodes[LIndex] - 1] then
    begin
      raise EAudio.Create('Joint vocabulary contains an unobserved pair');
    end;
  end;
end;

procedure PutNumber(var ABytes: TAudioBytes; const AOffset, AValue: Integer);
var
  LIndex: Integer;
begin
  for LIndex := 0 to 3 do
  begin
    ABytes[AOffset + LIndex] := (Cardinal(AValue) shr (8 * LIndex)) and $FF;
  end;
end;

function GetNumber(const ABytes: TAudioBytes; const AOffset: Integer): Integer;
var
  LBits: Cardinal;
  LIndex: Integer;
begin
  LBits := 0;
  for LIndex := 0 to 3 do
  begin
    LBits := LBits or (Cardinal(ABytes[AOffset + LIndex]) shl (8 * LIndex));
  end;
  if LBits > High(Integer) then
  begin
    raise EAudio.Create('Joint attachment integer exceeds signed range');
  end;
  Result := LBits;
end;

procedure PutReal(var ABytes: TAudioBytes; const AOffset: Integer; const AValue: Double);
var
  LBits: QWord;
  LIndex: Integer;
begin
  Move(AValue, LBits, SizeOf(LBits));
  for LIndex := 0 to 7 do
  begin
    ABytes[AOffset + LIndex] := (LBits shr (8 * LIndex)) and $FF;
  end;
end;

function GetReal(const ABytes: TAudioBytes; const AOffset: Integer): Double;
var
  LBits: QWord;
  LIndex: Integer;
begin
  LBits := 0;
  for LIndex := 0 to 7 do
  begin
    LBits := LBits or (QWord(ABytes[AOffset + LIndex]) shl (8 * LIndex));
  end;
  Move(LBits, Result, SizeOf(Result));
end;

function EncodeWfcJointCorpus(const ACorpus: TAcousticCorpusData;
  const AModel: TWfcSequenceModel; const AActivity: TActivityOptions): TAudioBytes;
var
  LBytes: TAudioBytes;
  LText: String;
begin
  ValidateWfcJointCorpusModel(ACorpus, AModel, AActivity);
  LText := EncodeWfcSequenceText(AModel);
  if Length(LText) > MaximumCorpusAttachmentBytes - JointHeaderBytes then
  begin
    raise EAudio.Create('Joint model text exceeds attachment byte budget');
  end;
  SetLength(LBytes, JointHeaderBytes + Length(LText));
  LBytes[0] := Ord('J');
  LBytes[1] := Ord('N');
  LBytes[2] := Ord('T');
  LBytes[3] := Ord('1');
  PutNumber(LBytes, 4, JointAcousticVersion);
  PutNumber(LBytes, 8, AcousticActivityVersion);
  PutReal(LBytes, 12, AActivity.MinimumFlux);
  PutReal(LBytes, 20, AActivity.AdaptiveMultiplier);
  PutNumber(LBytes, 28, AActivity.HistoryFeatures);
  PutNumber(LBytes, 32, AActivity.PeakRadius);
  PutNumber(LBytes, 36, AActivity.MinimumSeparationFeatures);
  PutNumber(LBytes, 40, AActivity.MaximumSegmentFeatures);
  PutNumber(LBytes, 44, Length(LText));
  if Length(LText) > 0 then
  begin
    Move(LText[1], LBytes[JointHeaderBytes], Length(LText));
  end;
  Result := EncodeAcousticArchive(ACorpus, WfcJointAttachmentContract, LBytes);
end;

function DecodeWfcJointCorpus(const ABytes: TAudioBytes;
  out AModel: TWfcSequenceModel; out AActivity: TActivityOptions): TAcousticCorpusData;
var
  LCorpus: TAcousticCorpusData;
  LModel: TWfcSequenceModel;
  LActivity: TActivityOptions;
  LContract: UTF8String;
  LBytes: TAudioBytes;
  LText: String;
  LLength: Integer;
begin
  AModel := nil;
  AActivity := Default(TActivityOptions);
  LModel := nil;
  LCorpus := DecodeAcousticArchive(ABytes, LContract, LBytes);
  try
    if (LContract <> WfcJointAttachmentContract) or
      (Length(LBytes) < JointHeaderBytes) then
    begin
      raise EAudio.Create('Archive does not contain a supported joint attachment');
    end;
    if (LBytes[0] <> Ord('J')) or (LBytes[1] <> Ord('N')) or
      (LBytes[2] <> Ord('T')) or (LBytes[3] <> Ord('1')) or
      (GetNumber(LBytes, 4) <> JointAcousticVersion) or
      (GetNumber(LBytes, 8) <> AcousticActivityVersion) then
    begin
      raise EAudio.Create('Unsupported joint token or activity policy version');
    end;
    LActivity.MinimumFlux := GetReal(LBytes, 12);
    LActivity.AdaptiveMultiplier := GetReal(LBytes, 20);
    LActivity.HistoryFeatures := GetNumber(LBytes, 28);
    LActivity.PeakRadius := GetNumber(LBytes, 32);
    LActivity.MinimumSeparationFeatures := GetNumber(LBytes, 36);
    LActivity.MaximumSegmentFeatures := GetNumber(LBytes, 40);
    ValidateActivityOptions(LActivity);
    LLength := GetNumber(LBytes, 44);
    if LLength <> Length(LBytes) - JointHeaderBytes then
    begin
      raise EAudio.Create('Joint model text length disagrees with attachment extent');
    end;
    SetLength(LText, LLength);
    if LLength > 0 then
    begin
      Move(LBytes[JointHeaderBytes], LText[1], LLength);
    end;
    LModel := DecodeWfcSequenceText(LText);
    ValidateWfcJointCorpusModel(LCorpus, LModel, LActivity);
    if EncodeWfcSequenceText(LModel) <> LText then
    begin
      raise EAudio.Create('Joint attachment requires canonical WFC model text');
    end;
    Result := LCorpus;
    AModel := LModel;
    AActivity := LActivity;
  except
    LModel.Free;
    LCorpus.Free;
    raise;
  end;
end;

end.
