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
unit pythian.wfc.note.events.generation;

{$mode delphi}
{$H+}

interface

uses
  pythian.music,
  pythian.time,
  pythian.wfc.generation,
  pythian.wfc.note.events,
  wfc,
  wfc_model,
  wfc_sequence;

const
  JointNoteEventGenerationVersion = 1;
  MaximumJointNoteEventTrainingSamples = 4096;
  MaximumJointNoteEventTrainingBundles = 65536;

type
  TJointNoteEventSequences = array of TNoteSequence;
  TJointNoteEventSourceLengths = array of Integer;

  TJointNoteEventGenerationStatus = (
    jngNotRun,
    jngSolved,
    jngContradiction,
    jngBacktrackLimit
  );

  TJointNoteEventGenerationReport = record
    Status: TJointNoteEventGenerationStatus;
    Solve: TGraphSolveReport;
    PartA: Integer;
    PartB: Integer;
    QuantumTicks: Integer;
    SourceTicksPerQuarter: Integer;
    SourceTempos: TTempoChanges;
    SourceLengthTicks: TJointNoteEventSourceLengths;
    TrainingBundleCounts: TJointNoteEventSourceLengths;
    GeneratedTokens: TWfcModelTokens;
  end;

  TJointNoteEventWfcModel = class
  private
    FModel: TWfcSequenceModel;
    FPartA: Integer;
    FPartB: Integer;
    FQuantumTicks: Integer;
    FBoundary: TWfcModelBoundary;
    FTicksPerQuarter: Integer;
    FTempos: TTempoChanges;
    FSourceLengthTicks: TJointNoteEventSourceLengths;
    FTrainingBundleCounts: TJointNoteEventSourceLengths;
    function GetSampleCount: Integer;
    function GetStateCount: Integer;
    function GetVocabularyCount: Integer;
    function GetTempos: TTempoChanges;
    function GetSourceLengthTicks: TJointNoteEventSourceLengths;
    function GetTrainingBundleCounts: TJointNoteEventSourceLengths;
  public
    destructor Destroy; override;
    property PartA: Integer read FPartA;
    property PartB: Integer read FPartB;
    property QuantumTicks: Integer read FQuantumTicks;
    property Boundary: TWfcModelBoundary read FBoundary;
    property TicksPerQuarter: Integer read FTicksPerQuarter;
    property Tempos: TTempoChanges read GetTempos;
    property SourceLengthTicks: TJointNoteEventSourceLengths read GetSourceLengthTicks;
    property TrainingBundleCounts: TJointNoteEventSourceLengths read GetTrainingBundleCounts;
    property SampleCount: Integer read GetSampleCount;
    property StateCount: Integer read GetStateCount;
    property VocabularyCount: Integer read GetVocabularyCount;
  end;

{ Encodes each source separately and learns one open-boundary sequence model.
  Every sample must share part IDs, PPQ and the exact tempo map; phrase lengths
  may differ. The returned owned model retains those source-clock fields. }
function LearnJointNoteEventWfcModel(const ASamples: TJointNoteEventSequences;
  const APartA, APartB, AQuantumTicks, AOrder: Integer): TJointNoteEventWfcModel;

{ Generates a bounded bundle-token path on the learned source clock. The caller
  supplies only output extent, graph options, and its output variable. A failed
  solve or decode leaves AOutput untouched; a successful detached sequence is
  transferred to AOutput, replacing and freeing its previous owned sequence.
  Invalid input/resource requests raise without changing AOutput. }
function TryGenerateJointNoteEventSequence(const AModel: TJointNoteEventWfcModel;
  const AOptions: TAcousticGenerationOptions;
  const AOutputLengthTicks: Integer;
  var AOutput: TNoteSequence;
  out AReport: TJointNoteEventGenerationReport): Boolean;

implementation

uses
  SysUtils,
  pythian.audio,
  wfc_sequence_learn;

function SameTempos(const ALeft, ARight: TTempoChanges): Boolean;
var
  LIndex: Integer;
begin
  if Length(ALeft) <> Length(ARight) then
    Exit(False);
  for LIndex := 0 to High(ALeft) do
    if (ALeft[LIndex].Tick <> ARight[LIndex].Tick) or
      (ALeft[LIndex].MicrosecondsPerQuarter <>
        ARight[LIndex].MicrosecondsPerQuarter) then
      Exit(False);
  Result := True;
end;

function ParseOnsetDelta(const AToken: UTF8String): Integer;
var
  LText: String;
  LSeparator: Integer;
  LValue: Integer;
  LDeltaText: String;
begin
  LText := String(AToken);
  LSeparator := Pos('|', LText);
  if LSeparator < 2 then
    raise EAudio.Create('Joint note-event token has no onset separator');
  LDeltaText := Copy(LText, 1, LSeparator - 1);
  if not TryStrToInt(LDeltaText, LValue) or (IntToStr(LValue) <> LDeltaText) or
    (LValue < 0) then
    raise EAudio.Create('Joint note-event token has invalid onset delta');
  Result := LValue;
end;

function TJointNoteEventWfcModel.GetSampleCount: Integer;
begin
  if FModel = nil then
    Exit(0);
  Result := FModel.SampleCount;
end;

function TJointNoteEventWfcModel.GetStateCount: Integer;
begin
  if FModel = nil then
    Exit(0);
  Result := FModel.StateCount;
end;

function TJointNoteEventWfcModel.GetVocabularyCount: Integer;
begin
  if FModel = nil then
    Exit(0);
  Result := FModel.PublicTokenCount;
end;

function TJointNoteEventWfcModel.GetTempos: TTempoChanges;
begin
  Result := Copy(FTempos);
end;

function TJointNoteEventWfcModel.GetSourceLengthTicks: TJointNoteEventSourceLengths;
begin
  Result := Copy(FSourceLengthTicks);
end;

function TJointNoteEventWfcModel.GetTrainingBundleCounts: TJointNoteEventSourceLengths;
begin
  Result := Copy(FTrainingBundleCounts);
end;

destructor TJointNoteEventWfcModel.Destroy;
begin
  FModel.Free;
  inherited Destroy;
end;

function LearnJointNoteEventWfcModel(const ASamples: TJointNoteEventSequences;
  const APartA, APartB, AQuantumTicks, AOrder: Integer): TJointNoteEventWfcModel;
var
  LReference: TJointNoteEventPath;
  LPath: TJointNoteEventPath;
  LSamples: TWfcSequenceSamples;
  LLengths: TJointNoteEventSourceLengths;
  LBundleCounts: TJointNoteEventSourceLengths;
  LCandidate: TJointNoteEventWfcModel;
  LSample: Integer;
  LTotalBundles: Int64;
begin
  if (Length(ASamples) < 1) or
    (Length(ASamples) > MaximumJointNoteEventTrainingSamples) then
    raise EAudio.Create('Joint note-event learning requires 1..4096 source samples');
  if (AOrder < 1) or (AOrder > WFC_SEQUENCE_MAX_ORDER) then
    raise EAudio.Create('Joint note-event order is outside sequence model bounds');
  if AQuantumTicks <> 1 then
    raise EAudio.Create('Joint note-event learning requires the exact one-tick codec');

  SetLength(LSamples, Length(ASamples));
  SetLength(LLengths, Length(ASamples));
  SetLength(LBundleCounts, Length(ASamples));
  LReference := Default(TJointNoteEventPath);
  LTotalBundles := 0;
  for LSample := 0 to High(ASamples) do
  begin
    if ASamples[LSample] = nil then
      raise EAudio.CreateFmt('Joint note-event sample %d is nil', [LSample]);
    if ASamples[LSample].NoteCount = 0 then
      raise EAudio.CreateFmt('Joint note-event sample %d is empty', [LSample]);
    LPath := EncodeJointNoteEvents(ASamples[LSample], APartA, APartB,
      AQuantumTicks);
    if LSample = 0 then
      LReference := LPath
    else
    begin
      if LPath.TicksPerQuarter <> LReference.TicksPerQuarter then
        raise EAudio.CreateFmt('Joint note-event sample %d has incompatible PPQ', [LSample]);
      if (LPath.PartA <> LReference.PartA) or (LPath.PartB <> LReference.PartB) or
        (LPath.QuantumTicks <> LReference.QuantumTicks) then
        raise EAudio.CreateFmt('Joint note-event sample %d has incompatible part metadata',
          [LSample]);
      if not SameTempos(LPath.Tempos, LReference.Tempos) then
        raise EAudio.CreateFmt('Joint note-event sample %d has incompatible tempo map',
          [LSample]);
    end;
    if Length(LPath.Tokens) = 0 then
      raise EAudio.CreateFmt('Joint note-event sample %d has no event bundles', [LSample]);
    LTotalBundles := LTotalBundles + Length(LPath.Tokens);
    if LTotalBundles > MaximumJointNoteEventTrainingBundles then
      raise EAudio.Create('Joint note-event corpus exceeds the 65,536-bundle learning bound');
    LSamples[LSample] := MakeWfcSequenceSample(LPath.Tokens);
    LLengths[LSample] := LPath.LengthTicks;
    LBundleCounts[LSample] := Length(LPath.Tokens);
  end;

  LCandidate := TJointNoteEventWfcModel.Create;
  try
    LCandidate.FModel := LearnSequenceModelCorpus(LSamples, AOrder, wmbOpen);
    LCandidate.FPartA := LReference.PartA;
    LCandidate.FPartB := LReference.PartB;
    LCandidate.FQuantumTicks := LReference.QuantumTicks;
    LCandidate.FBoundary := wmbOpen;
    LCandidate.FTicksPerQuarter := LReference.TicksPerQuarter;
    LCandidate.FTempos := Copy(LReference.Tempos);
    LCandidate.FSourceLengthTicks := Copy(LLengths);
    LCandidate.FTrainingBundleCounts := Copy(LBundleCounts);
    Result := LCandidate;
    LCandidate := nil;
  finally
    LCandidate.Free;
  end;
end;

function BuildPositionConstraints(const AModel: TWfcSequenceModel;
  const AFrameCount: Integer): TWfcSequenceTokenConstraints;
var
  LPosition: Integer;
  LTokenIndex: Integer;
  LToken: TWfcModelToken;
  LDelta: Integer;
  LCount: Integer;
begin
  Result := nil;
  SetLength(Result, AFrameCount);
  for LPosition := 0 to AFrameCount - 1 do
  begin
    Result[LPosition].Position := LPosition;
    LCount := 0;
    for LTokenIndex := 0 to AModel.PublicTokenCount - 1 do
    begin
      LToken := AModel.PublicTokenAt(LTokenIndex);
      LDelta := ParseOnsetDelta(LToken);
      if (LPosition > 0) and (LDelta = 0) then
        Continue;
      SetLength(Result[LPosition].AllowedTokens, LCount + 1);
      Result[LPosition].AllowedTokens[LCount] := LToken;
      Inc(LCount);
    end;
    if LCount = 0 then
      raise EAudio.CreateFmt('No legal event bundle tokens at position %d', [LPosition]);
  end;
end;

function TryGenerateJointNoteEventSequence(const AModel: TJointNoteEventWfcModel;
  const AOptions: TAcousticGenerationOptions;
  const AOutputLengthTicks: Integer;
  var AOutput: TNoteSequence;
  out AReport: TJointNoteEventGenerationReport): Boolean;
var
  LConstraints: TWfcSequenceTokenConstraints;
  LGenerated: TWfcModelTokens;
  LPath: TJointNoteEventPath;
  LCandidate: TNoteSequence;
  LPreviousOutput: TNoteSequence;
  LEmptyGates: TNoteGates;
  LClockCheck: TNoteSequence;
begin
  AReport := Default(TJointNoteEventGenerationReport);
  Result := False;
  if (AModel = nil) or (AModel.FModel = nil) then
    raise EAudio.Create('Joint note-event WFC model is required');
  if (AOutputLengthTicks < 1) then
    raise EAudio.Create('Joint note-event output extent must be positive');
  if (AOptions.FrameCount < 1) or
    (AOptions.FrameCount > MaximumGeneratedAcousticFrames) then
    raise EAudio.Create('Joint note-event frame count exceeds WFC bounds');

  AReport.PartA := AModel.FPartA;
  AReport.PartB := AModel.FPartB;
  AReport.QuantumTicks := AModel.FQuantumTicks;
  AReport.SourceTicksPerQuarter := AModel.FTicksPerQuarter;
  AReport.SourceTempos := Copy(AModel.FTempos);
  AReport.SourceLengthTicks := Copy(AModel.FSourceLengthTicks);
  AReport.TrainingBundleCounts := Copy(AModel.FTrainingBundleCounts);

  SetLength(LEmptyGates, 0);
  LClockCheck := TNoteSequence.Create(AModel.FTicksPerQuarter,
    AOutputLengthTicks, AModel.FTempos, LEmptyGates);
  LClockCheck.Free;

  LConstraints := BuildPositionConstraints(AModel.FModel, AOptions.FrameCount);
  if not TryGenerateTokenSequence(AModel.FModel, AOptions, LConstraints,
    LGenerated, AReport.Solve) then
  begin
    if AReport.Solve.Status = gssBacktrackLimit then
      AReport.Status := jngBacktrackLimit
    else
      AReport.Status := jngContradiction;
    Exit(False);
  end;

  if Length(LGenerated) <> AOptions.FrameCount then
    raise EAudio.Create('Generated event bundle count differs from request');
  LPath := Default(TJointNoteEventPath);
  LPath.TicksPerQuarter := AModel.FTicksPerQuarter;
  LPath.LengthTicks := AOutputLengthTicks;
  LPath.PartA := AModel.FPartA;
  LPath.PartB := AModel.FPartB;
  LPath.QuantumTicks := AModel.FQuantumTicks;
  LPath.Tempos := Copy(AModel.FTempos);
  LPath.Tokens := Copy(LGenerated);
  LCandidate := DecodeJointNoteEvents(LPath);
  try
    AReport.Status := jngSolved;
    AReport.GeneratedTokens := Copy(LGenerated);
    LPreviousOutput := AOutput;
    AOutput := LCandidate;
    LCandidate := nil;
    LPreviousOutput.Free;
    Result := True;
  finally
    LCandidate.Free;
  end;
end;

end.
