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
program pythian_tests_sequence_stream_progress;

{$mode delphi}
{$H+}

uses
  SysUtils, pythian.audio, pythian.progress, pythian.wfc.generation,
  pythian.wfc.stream, wfc, wfc_model, wfc_sequence, wfc_sequence_learn,
  wfc_sequence_text, wfc_sequence_graph;

type
  { Stateless publication and retained cursor publication have different owners. }
  TScenario = (scInitial, scContinue, scEnd, scDirect, scCopy, scJoin, scFinite);
  { Discover only actual emitted start/interior/final points, then require the
    publication and interior checkpoints promised by each public boundary. }
  TPoint = record
    Stage: String;
    Kind: Integer;
  end;
  TPoints = array of TPoint;
  { Borrowed callback with original caller exceptions and hostile reentry probes. }
  TObserver = class
  public
    Points: TPoints;
    Discover: Boolean;
    Enabled: Boolean;
    Target: TPoint;
    Marker: Exception;
    Raised: Boolean;
    Calls: Integer;
    CheckCursor: Boolean;
    CheckedReentry: Boolean;
    Cursor: Int64;
    Completed: Boolean;
    Stream: TLearnedSequenceStream;
    procedure Observe(const AWork: TWorkProgress);
  end;

var
  GChecks: Integer;
  GAborts: Integer;
  GScenario: TScenario;
  GModel: TWfcSequenceModel;
  GModelText: String;
  GPrefix: TWfcGeneratedSequenceSegment;
  GSuffix: TWfcGeneratedSequenceSegment;
  GPrefixText: String;
  GSuffixText: String;
  GOutput: TWfcGeneratedSequenceSegment;
  GTokens: TWfcModelTokens;
  GObserver: TObserver;

procedure Check(const ACondition: Boolean; const AMessage: String);
begin
  Inc(GChecks);
  if not ACondition then
  begin
    raise Exception.Create(AMessage);
  end;
end;

function MakeModel: TWfcSequenceModel;
var
  LSamples: TWfcSequenceSamples;
  LTokens: TWfcModelTokens;
  LSample: Integer;
  LBit: Integer;
begin
  SetLength(LSamples, 16);
  SetLength(LTokens, 4);
  for LSample := 0 to High(LSamples) do
  begin
    for LBit := 0 to 3 do
    begin
      LTokens[LBit] := 'a';
      if ((LSample shr LBit) and 1) <> 0 then
      begin
        LTokens[LBit] := 'b';
      end;
    end;
    LSamples[LSample] := MakeWfcSequenceSample(LTokens);
  end;
  Result := LearnSequenceModelCorpus(LSamples, 3);
end;

function Evidence(const AValue: TWfcGeneratedSequenceSegment): String;
var
  LIndex: Integer;
begin
  Result := BoolToStr(AValue.Boundary.HasPrevious, True) + ':' +
    IntToStr(AValue.Boundary.PreviousState) + ':' +
    BoolToStr(AValue.Boundary.RequireObservedEnd, True) + '|';
  for LIndex := 0 to High(AValue.Tokens) do
  begin
    Result := Result + AValue.Tokens[LIndex] + '=' +
      IntToStr(AValue.StateIndices[LIndex]) + '|';
  end;
end;

function OutputEvidence: String;
var
  LIndex: Integer;
begin
  Result := Evidence(GOutput);
  for LIndex := 0 to High(GTokens) do
  begin
    Result := Result + GTokens[LIndex] + ';';
  end;
end;

function StreamEvidence(const AStream: TLearnedSequenceStream): String;
begin
  Result := IntToStr(AStream.CellCount) + ':' + BoolToStr(AStream.Completed, True);
end;

procedure ResetOutputs;
begin
  GOutput := Default(TWfcGeneratedSequenceSegment);
  GOutput.Boundary := MakeWfcSequenceInitialSegmentBoundary(False);
  SetLength(GOutput.Tokens, 1);
  SetLength(GOutput.StateIndices, 1);
  GOutput.Tokens[0] := 'old caller chunk';
  GOutput.StateIndices[0] := -19;
  GTokens := nil;
  SetLength(GTokens, 1);
  GTokens[0] := 'old caller tokens';
end;

procedure CheckInputs;
begin
  Check(EncodeWfcSequenceText(GModel) = GModelText, 'Borrowed model changed');
  Check(Evidence(GPrefix) = GPrefixText, 'Borrowed prefix changed');
  Check(Evidence(GSuffix) = GSuffixText, 'Borrowed suffix changed');
end;

function Prepare: TLearnedSequenceStream;
var
  LOptions: TSequenceChunkOptions;
  LChunk: TWfcGeneratedSequenceSegment;
  LReport: TGraphSolveReport;
begin
  Result := TLearnedSequenceStream.Create(GModel);
  try
    if GScenario in [scContinue, scEnd] then
    begin
      LOptions := DefaultSequenceChunkOptions;
      LOptions.CellCount := 3;
      Check(Result.TryNext(LOptions, nil, LChunk, LReport), 'Prelude failed');
    end;
  except
    Result.Free;
    raise;
  end;
end;

procedure Run(const AStream: TLearnedSequenceStream; const AProgress: TWorkProgressCallback);
var
  LOptions: TSequenceChunkOptions;
  LSegment: TSequenceSegmentOptions;
  LFinite: TAcousticGenerationOptions;
  LReport: TGraphSolveReport;
  LProof: TWfcSequenceGraphValidationReport;
  LMask: TWfcSequenceTokenConstraints;
begin
  LOptions := DefaultSequenceChunkOptions;
  LOptions.CellCount := 257;
  LOptions.Seed := 1731;
  LOptions.RequireObservedEnd := GScenario = scEnd;
  LSegment := DefaultSequenceSegmentOptions;
  LSegment.CellCount := 257;
  LSegment.Seed := 1731;
  case GScenario of
    scInitial, scContinue, scEnd:
      Check(AStream.TryNext(LOptions, nil, GOutput, LReport, AProgress), 'Stream solve failed');
    scDirect:
    begin
      SetLength(LMask, 2);
      LMask[0] := MakeWfcSequenceTokenConstraint(0, ['a', 'b']);
      LMask[1] := MakeWfcSequenceTokenConstraint(0, ['b']);
      Check(TryGenerateSequenceSegment(GModel, LSegment,
        MakeWfcSequenceInitialSegmentBoundary(False), LMask, GOutput, LReport, AProgress),
        'Direct shared segment failed');
      Check(GOutput.Tokens[0] = 'b', 'Repeated mask rows lost their intersection');
    end;
    scCopy: GOutput := CopySequenceSegment(GPrefix, AProgress);
    scJoin: GOutput := JoinSequenceSegments(GPrefix, GSuffix, 128, AProgress);
    scFinite:
    begin
      LFinite := DefaultAcousticGenerationOptions;
      LFinite.FrameCount := 257;
      LFinite.Seed := 1731;
      LFinite.Extent := wseWhole;
      Check(TryGenerateTokenSequence(GModel, LFinite, nil, GTokens, LReport, AProgress),
        'Finite sequence failed');
    end;
  end;
  if GScenario <> scFinite then
  begin
    Check(ValidateSequenceSegmentStatePath(GModel, GOutput.StateIndices,
      GOutput.Boundary, LProof), 'Published segment fails independent latent-path proof');
  end;
end;

procedure TObserver.Observe(const AWork: TWorkProgress);
var
  LPoint: TPoint;
  LIndex: Integer;
  LFound: Boolean;
  LRejected: Boolean;
  LOptions: TSequenceChunkOptions;
  LChunk: TWfcGeneratedSequenceSegment;
  LReport: TGraphSolveReport;
begin
  Inc(Calls);
  Check((AWork.Units = wuItems) and (AWork.Done >= 0) and (AWork.Total >= 0) and
    ((AWork.Total = 0) or (AWork.Done <= AWork.Total)) and
    (AWork.Pass >= 0), 'Invalid forwarded segment measurement');
  if CheckCursor then
  begin
    Check((Stream.CellCount = Cursor) and (Stream.Completed = Completed),
      'Cursor/completion published while callback could still abort');
    if not CheckedReentry then
    begin
      CheckedReentry := True;
      LRejected := False;
      try
        Stream.Reset;
      except
        on E: EAudio do
        begin
          LRejected := Pos('reenter', E.Message) > 0;
        end;
      end;
      Check(LRejected, 'Observer reset its active stream');
      LRejected := False;
      LOptions := DefaultSequenceChunkOptions;
      try
        Stream.TryNext(LOptions, nil, LChunk, LReport);
      except
        on E: EAudio do
        begin
          LRejected := Pos('reenter', E.Message) > 0;
        end;
      end;
      Check(LRejected, 'Observer reentered its active stream');
    end;
  end;
  LPoint.Stage := AWork.Stage;
  LPoint.Kind := 0;
  if AWork.Done > 0 then
  begin
    LPoint.Kind := 1;
    if (AWork.Total > 0) and (AWork.Done = AWork.Total) then
    begin
      LPoint.Kind := 2;
    end;
  end;
  if Discover then
  begin
    LFound := False;
    for LIndex := 0 to High(Points) do
    begin
      if (Points[LIndex].Stage = LPoint.Stage) and (Points[LIndex].Kind = LPoint.Kind) then
      begin
        LFound := True;
      end;
    end;
    if not LFound then
    begin
      SetLength(Points, Length(Points) + 1);
      Points[High(Points)] := LPoint;
    end;
  end;
  if Enabled and (Target.Stage = LPoint.Stage) and (Target.Kind = LPoint.Kind) then
  begin
    Raised := True;
    raise Marker;
  end;
end;

procedure RequirePoint(const APoints: TPoints; const AStage: String; const AKind: Integer);
var
  LPoint: TPoint;
  LFound: Boolean;
begin
  LFound := False;
  for LPoint in APoints do
  begin
    if (LPoint.Stage = AStage) and (LPoint.Kind = AKind) then
    begin
      LFound := True;
    end;
  end;
  Check(LFound, 'Required segment checkpoint missing: ' + AStage);
end;

procedure Exercise(const AScenario: TScenario);
var
  LStream: TLearnedSequenceStream;
  LExpectedOutput: String;
  LExpectedStream: String;
  LBeforeOutput: String;
  LBeforeStream: String;
  LPoints: TPoints;
  LIndex: Integer;
  LCalls: Integer;
begin
  GScenario := AScenario;
  LStream := Prepare;
  try
    ResetOutputs;
    GObserver.Points := nil;
    GObserver.Discover := True;
    Run(LStream, GObserver.Observe);
    GObserver.Discover := False;
    LExpectedOutput := OutputEvidence;
    LExpectedStream := StreamEvidence(LStream);
    LPoints := Copy(GObserver.Points);
    Check(Length(LPoints) > 0, 'Missing operation observation');
    if AScenario in [scInitial, scContinue, scEnd, scDirect] then
    begin
      RequirePoint(LPoints, 'sequence_segment_publication_ready', 2);
      RequirePoint(LPoints, 'wfc_sequence_capture_cells', 1);
    end;
    if AScenario in [scInitial, scContinue, scEnd] then
    begin
      RequirePoint(LPoints, 'sequence_stream_chunk_ready', 0);
      RequirePoint(LPoints, 'sequence_stream_chunk_ready', 2);
    end;
    case AScenario of
      scCopy:
      begin
        RequirePoint(LPoints, 'sequence_segment_copy_visits', 1);
        RequirePoint(LPoints, 'sequence_segment_copy_ready', 2);
      end;
      scJoin:
      begin
        RequirePoint(LPoints, 'sequence_segment_join_visits', 1);
        RequirePoint(LPoints, 'sequence_segment_join_ready', 2);
      end;
      scFinite:
      begin
        RequirePoint(LPoints, 'sequence_publication_ready', 2);
        RequirePoint(LPoints, 'wfc_sequence_capture_cells', 1);
      end;
    end;
  finally
    LStream.Free;
  end;
  for LIndex := 0 to High(LPoints) do
  begin
    LStream := Prepare;
    try
      ResetOutputs;
      LBeforeOutput := OutputEvidence;
      LBeforeStream := StreamEvidence(LStream);
      GObserver.Target := LPoints[LIndex];
      GObserver.Raised := False;
      GObserver.CheckedReentry := False;
      GObserver.CheckCursor := AScenario in [scInitial, scContinue, scEnd];
      GObserver.Stream := LStream;
      GObserver.Cursor := LStream.CellCount;
      GObserver.Completed := LStream.Completed;
      GObserver.Enabled := True;
      if (LIndex mod 2) = 0 then
      begin
        GObserver.Marker := EAudio.Create('original audio cancellation');
      end
      else
      begin
        GObserver.Marker := Exception.Create('original caller cancellation');
      end;
      try
        try
          Run(LStream, GObserver.Observe);
        except
          on E: Exception do
          begin
            Check(E = GObserver.Marker, 'Cancellation exception identity changed: ' + E.Message);
            GObserver.Marker := nil;
          end;
        end;
      finally
        GObserver.Enabled := False;
        GObserver.CheckCursor := False;
        GObserver.Marker.Free;
        GObserver.Marker := nil;
      end;
      Check(GObserver.Raised, 'Discovered checkpoint disappeared');
      Inc(GAborts);
      Check(OutputEvidence = LBeforeOutput, 'Cancellation published partial caller output');
      Check(StreamEvidence(LStream) = LBeforeStream, 'Cancellation advanced stream state');
      if AScenario in [scInitial, scContinue, scEnd] then
      begin
        Check(GObserver.CheckedReentry, 'Stream reentry probes did not execute');
      end;
      CheckInputs;
      LCalls := GObserver.Calls;
      Run(LStream, nil);
      Check(GObserver.Calls = LCalls, 'Observer retained after call');
      Check(OutputEvidence = LExpectedOutput, 'Same-session seeded retry changed output');
      Check(StreamEvidence(LStream) = LExpectedStream, 'Same-session retry changed cursor');
    finally
      GObserver.Stream := nil;
      LStream.Free;
    end;
  end;
  WriteLn('sequence scenario ', Ord(AScenario), ': ', Length(LPoints), ' original abort/retries');
end;

procedure Setup;
var
  LOptions: TSequenceSegmentOptions;
  LReport: TGraphSolveReport;
begin
  GModel := MakeModel;
  GModelText := EncodeWfcSequenceText(GModel);
  LOptions := DefaultSequenceSegmentOptions;
  LOptions.CellCount := 257;
  Check(TryGenerateSequenceSegment(GModel, LOptions,
    MakeWfcSequenceInitialSegmentBoundary(False), nil, GPrefix, LReport), 'Prefix setup');
  LOptions.CellCount := 129;
  LOptions.Seed := 1731;
  Check(TryGenerateSequenceSegment(GModel, LOptions,
    MakeWfcSequenceContinuingSegmentBoundary(GPrefix.StateIndices[127], True),
    nil, GSuffix, LReport), 'Suffix setup');
  GPrefixText := Evidence(GPrefix);
  GSuffixText := Evidence(GSuffix);
end;

procedure CopyAndContractControls;
var
  LCopy: TWfcGeneratedSequenceSegment;
  LBad: TWfcGeneratedSequenceSegment;
  LBefore: String;
  LRejected: Boolean;
  LOptions: TSequenceSegmentOptions;
  LStreamOptions: TSequenceChunkOptions;
  LMask: TWfcSequenceTokenConstraints;
  LReport: TGraphSolveReport;
  LStream: TLearnedSequenceStream;
begin
  LCopy := CopySequenceSegment(GPrefix);
  LCopy.Tokens[0] := 'detached';
  LCopy.StateIndices[0] := -1;
  LCopy := JoinSequenceSegments(GPrefix, GSuffix, 128);
  LCopy.Tokens[0] := 'detached';
  LCopy.StateIndices[128] := -1;
  CheckInputs;
  ResetOutputs;
  LBefore := OutputEvidence;
  LBad := GSuffix;
  LBad.Boundary.PreviousState := -1;
  LRejected := False;
  try
    GOutput := JoinSequenceSegments(GPrefix, LBad, 128);
  except
    on E: EAudio do
    begin
      LRejected := True;
    end;
  end;
  Check(LRejected and (OutputEvidence = LBefore), 'Malformed seam changed previous output');
  SetLength(LMask, 2);
  LMask[0] := MakeWfcSequenceTokenConstraint(0, ['a', 'b']);
  LMask[1] := MakeWfcSequenceTokenConstraint(0, ['b']);
  LOptions := DefaultSequenceSegmentOptions;
  LOptions.CellCount := 1;
  Check(TryGenerateSequenceSegment(GModel, LOptions,
    MakeWfcSequenceInitialSegmentBoundary(False), LMask, GOutput, LReport),
    'Shared segment silently tightened repeated-row policy');
  Check(GOutput.Tokens[0] = 'b', 'One-cell repeated-row intersection changed');
  LStream := TLearnedSequenceStream.Create(GModel);
  try
    LStreamOptions := DefaultSequenceChunkOptions;
    LStreamOptions.CellCount := 1;
    LBefore := Evidence(GOutput);
    LRejected := False;
    try
      LStream.TryNext(LStreamOptions, LMask, GOutput, LReport);
    except
      on E: EAudio do
      begin
        LRejected := True;
      end;
    end;
    Check(LRejected and (LStream.CellCount = 0) and
      (Evidence(GOutput) = LBefore), 'Ordinary stream lost its original row-count policy');
  finally
    LStream.Free;
  end;
end;

var
  LScenario: TScenario;
begin
  GObserver := TObserver.Create;
  try
    Setup;
    for LScenario := Low(TScenario) to High(TScenario) do
    begin
      Exercise(LScenario);
    end;
    CopyAndContractControls;
    CheckInputs;
    WriteLn('shared sequence publication: ', GChecks, ' checks; ', GAborts,
      ' original abort/retries; ', GObserver.Calls, ' callbacks');
  finally
    GModel.Free;
    GObserver.Free;
  end;
end.
