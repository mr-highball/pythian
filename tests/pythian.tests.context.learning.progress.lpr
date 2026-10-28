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
program pythian_tests_context_learning_progress;
{$mode delphi}{$H+}

uses
  SysUtils, pythian.audio, pythian.tonal, pythian.music.context,
  pythian.progress, pythian.wfc.context, wfc_sequence, wfc_sequence_text
  {$ifndef PAS2JS}, pythian.wfc.context.archive{$endif};

const
  CStages: array[0..4] of String = ('context_grid_cells', 'context_tokens',
    'context_wfc_token_rows', 'context_wfc_observation_rows', 'context_wfc_model_visits');

type
  TObserver = class
  public
    Calls: Integer;
    ExpectedPass: Integer;
    AbortStage: Integer;
    FinalOnly: Boolean;
    Marker: Exception;
    Last: array[0..4] of Int64;
    Finals: array[0..4] of Integer;
    procedure Reset(const APass: Integer);
    procedure Observe(const AWork: TWorkProgress);
    procedure ObserveLearning(const AWork: TWorkProgress);
  end;

var
  GChecks: Integer;
  GAborts: Integer;
  GObserver: TObserver;

procedure Check(const AValue: Boolean; const AMessage: String);
begin
  Inc(GChecks);
  if not AValue then
    raise Exception.Create(AMessage);
end;

procedure TObserver.Reset(const APass: Integer);
var
  I: Integer;
begin
  ExpectedPass := APass;
  AbortStage := -1;
  for I := 0 to High(Last) do
  begin
    Last[I] := 0;
    Finals[I] := 0;
  end;
end;

procedure TObserver.Observe(const AWork: TWorkProgress);
var
  LStage: Integer;
  I: Integer;
  LFinal: Boolean;
begin
  Inc(Calls);
  Check(AWork.Units = wuItems, 'Context row/visit units differ');
  Check((AWork.Done >= 0) and (AWork.Total >= 0) and
    ((AWork.Total = 0) or (AWork.Done <= AWork.Total)), 'Invalid primary progress');
  LStage := -1;
  for I := 0 to High(CStages) do
    if AWork.Stage = CStages[I] then
      LStage := I;
  Check(LStage >= 0, 'Unexpected context stage');
  { A native bundle learns key before tempo. For its cancellation tests, target
    pass2 only; the preceding fully built key model must also be released. }
  if AWork.Pass <> ExpectedPass then
  begin
    Check((ExpectedPass = 2) and (AWork.Pass = 1), 'Context pass differs');
    Exit;
  end;
  Check(AWork.Done >= Last[LStage], 'Completed context work went backwards');
  Last[LStage] := AWork.Done;
  LFinal := (AWork.Total > 0) and (AWork.Done = AWork.Total);
  if LFinal then
    Inc(Finals[LStage]);
  if (AbortStage = LStage) and (AWork.Done > 0) and
    ((FinalOnly and LFinal) or ((not FinalOnly) and (not LFinal))) then
    raise Marker;
end;

procedure TObserver.ObserveLearning(const AWork: TWorkProgress);
var
  I: Integer;
begin
  { This accepted fixture owns learning phases. The context archive/profile
    fixture owns the newly observable evidence, bytes/hash and publication. }
  for I := 0 to High(CStages) do
  begin
    if AWork.Stage = CStages[I] then
    begin
      Observe(AWork);
      Exit;
    end;
  end;
end;

function Grids: TMusicContextGrids;
var
  I: Integer;
  J: Integer;
begin
  Result := nil;
  SetLength(Result, 2);
  for I := 0 to 1 do
  begin
    Result[I].TicksPerQuarter := 480;
    Result[I].StepTicks := 120;
    Result[I].StartTick := I * 120;
    SetLength(Result[I].Keys, 769 + I);
    SetLength(Result[I].Tempos, 769 + I);
    for J := 0 to High(Result[I].Keys) do
    begin
      Result[I].Keys[J] := MakeKeyContext((J + I) mod 12, dmMajor);
      Result[I].Tempos[J] := 500000 + ((J + I) mod 19);
    end;
  end;
end;

procedure CheckInputs(const AGrids: TMusicContextGrids);
var
  I: Integer;
  J: Integer;
begin
  for I := 0 to 1 do
  begin
    Check((AGrids[I].TicksPerQuarter = 480) and (AGrids[I].StepTicks = 120) and
      (AGrids[I].StartTick = I * 120), 'Grid scope changed');
    for J := 0 to High(AGrids[I].Keys) do
      Check((AGrids[I].Keys[J].Root = ((J + I) mod 12)) and
        (AGrids[I].Keys[J].Mode = dmMajor) and
        (AGrids[I].Tempos[J] = 500000 + ((J + I) mod 19)), 'Source cells changed');
  end;
end;

procedure OriginalException(const AException: Exception; var AExact: Boolean);
begin
  if AException <> GObserver.Marker then
    raise AException;
  GObserver.Marker := nil;
  AExact := True;
  Inc(GAborts);
end;

procedure TestLearning(const ADimension: TContextDimension);
var
  LGrids: TMusicContextGrids;
  LReference: TWfcSequenceModel;
  LObserved: TWfcSequenceModel;
  LStage: Integer;
  LFinal: Boolean;
  LExact: Boolean;
  LText: String;
begin
  LGrids := Grids;
  LReference := LearnContextModel(LGrids, ADimension, 4);
  LObserved := nil;
  try
    LText := EncodeWfcSequenceText(LReference);
    GObserver.Reset(Ord(ADimension) + 1);
    LObserved := LearnContextModel(LGrids, ADimension, 4, GObserver.Observe);
    Check(EncodeWfcSequenceText(LObserved) = LText, 'Observed context model differs');
    for LStage := 0 to 4 do
      Check(GObserver.Finals[LStage] = 1, 'Context phase missed or repeated final');
    for LStage := 0 to 3 do
      Check(GObserver.Last[LStage] = 1539, 'Context row count differs from actual source');
    FreeAndNil(LObserved);
    for LStage := 0 to 4 do
      for LFinal := False to True do
      begin
        GObserver.Reset(Ord(ADimension) + 1);
        GObserver.AbortStage := LStage;
        GObserver.FinalOnly := LFinal;
        GObserver.Marker := Exception.Create('Big Boss original context-learning abort');
        LObserved := LReference;
        LExact := False;
        try
          try
            LObserved := LearnContextModel(LGrids, ADimension, 4, GObserver.Observe);
          except
            on LException: Exception do
              OriginalException(LException, LExact);
          end;
          Check(LExact and (LObserved = LReference), 'Context abort published/wrapped a candidate');
        finally
          GObserver.AbortStage := -1;
          GObserver.Marker.Free;
          GObserver.Marker := nil;
          if LObserved <> LReference then
            LObserved.Free;
          LObserved := nil;
        end;
        CheckInputs(LGrids);
        GObserver.Reset(Ord(ADimension) + 1);
        LObserved := LearnContextModel(LGrids, ADimension, 4, GObserver.Observe);
        try
          Check(EncodeWfcSequenceText(LObserved) = LText, 'Context retry differs');
        finally
          FreeAndNil(LObserved);
        end;
      end;
  finally
    LObserved.Free;
    LReference.Free;
  end;
end;

procedure TestGrid;
var
  LGrids: TMusicContextGrids;
  LFinal: Boolean;
  LExact: Boolean;
begin
  LGrids := Grids;
  for LFinal := False to True do
  begin
    GObserver.Reset(0);
    GObserver.AbortStage := 0;
    GObserver.FinalOnly := LFinal;
    GObserver.Marker := Exception.Create('Big Boss original grid abort');
    LExact := False;
    try
      try
        ValidateContextGrid(LGrids[0], GObserver.Observe);
      except
        on LException: Exception do
          OriginalException(LException, LExact);
      end;
      Check(LExact, 'Grid did not propagate original abort');
    finally
      GObserver.Marker.Free;
      GObserver.Marker := nil;
    end;
    CheckInputs(LGrids);
    GObserver.Reset(0);
    ValidateContextGrid(LGrids[0], GObserver.Observe);
    Check(GObserver.Last[0] = 769, 'Grid retry counts changed');
  end;
end;

procedure TestMalformed;
var
  LGrids: TMusicContextGrids;
  LModel: TWfcSequenceModel;
  LCase: Integer;
  LObserved: Boolean;
  LText: String;
  LFirst: String;
begin
  for LCase := 0 to 3 do
  begin
    LGrids := Grids;
    case LCase of
      0: LGrids := nil;
      1: LGrids[1].TicksPerQuarter := 960;
      2: LGrids[0].Tempos[768] := 0;
      3: LGrids[0].Keys[768].Root := 12;
    end;
    LFirst := '';
    for LObserved := False to True do
    begin
      GObserver.Reset(1);
      LModel := nil;
      LText := '';
      try
        try
          if LObserved then
            LModel := LearnContextModel(LGrids, cdKey, 4, GObserver.Observe)
          else
            LModel := LearnContextModel(LGrids, cdKey, 4);
        except
          on LException: Exception do
            LText := LException.ClassName + ': ' + LException.Message;
        end;
        Check((LText <> '') and (LModel = nil), 'Malformed context published a model');
        if LObserved then
          Check(LText = LFirst, 'Context validation exception/order changed')
        else
          LFirst := LText;
      finally
        LModel.Free;
      end;
    end;
  end;
end;

procedure TestLarge;
var
  LGrids: TMusicContextGrids;
  LReference: TWfcSequenceModel;
  LObserved: TWfcSequenceModel;
  I: Integer;
begin
  SetLength(LGrids, 1);
  LGrids[0].TicksPerQuarter := 480;
  LGrids[0].StepTicks := 120;
  SetLength(LGrids[0].Keys, MaximumContextCells);
  SetLength(LGrids[0].Tempos, MaximumContextCells);
  for I := 0 to MaximumContextCells - 1 do
  begin
    LGrids[0].Keys[I] := MakeKeyContext(I mod 12, dmMajor);
    LGrids[0].Tempos[I] := 500000 + (I mod 1020);
  end;
  LReference := LearnContextModel(LGrids, cdTempo, 4);
  LObserved := nil;
  try
    GObserver.Reset(2);
    LObserved := LearnContextModel(LGrids, cdTempo, 4, GObserver.Observe);
    Check((LObserved.StateCount = 1023) and (LObserved.PublicTokenCount = 1020),
      'Authored admitted context dimensions changed');
    Check(EncodeWfcSequenceText(LObserved) = EncodeWfcSequenceText(LReference),
      'Large context model differs');
    for I := 0 to 3 do
      Check(GObserver.Last[I] = 65536, 'Large owned/generic row count differs');
  finally
    LObserved.Free;
    LReference.Free;
  end;
end;

{$ifndef PAS2JS}
procedure TestBundle;
var
  LEvidence: TContextEvidenceArray;
  LGrids: TMusicContextGrids;
  LReference: TContextLearningBundle;
  LObserved: TContextLearningBundle;
  LBytes: TAudioBytes;
  LObservedBytes: TAudioBytes;
  LStage: Integer;
  LFinal: Boolean;
  LExact: Boolean;
  I: Integer;
begin
  LGrids := Grids;
  SetLength(LEvidence, 2);
  for I := 0 to 1 do
  begin
    LEvidence[I].Name := 'authored context learning';
    LEvidence[I].SourceSha256 := StringOfChar('a', 64);
    LEvidence[I].AdmissionPolicy := 'Authored callback fixture, not recorded musical evidence';
    LEvidence[I].Grid := LGrids[I];
  end;
  LReference := TContextLearningBundle.Create(LEvidence, 4, 4);
  LObserved := nil;
  try
    LBytes := EncodeContextLearning(LReference);
    for LStage := 0 to 4 do
      for LFinal := False to True do
      begin
        GObserver.Reset(2);
        GObserver.AbortStage := LStage;
        GObserver.FinalOnly := LFinal;
        GObserver.Marker := Exception.Create('Big Boss original second-model abort');
        LObserved := LReference;
        LExact := False;
        try
          try
            LObserved := TContextLearningBundle.Create(LEvidence, 4, 4, GObserver.ObserveLearning);
          except
            on LException: Exception do
              OriginalException(LException, LExact);
          end;
          Check(LExact and (LObserved = LReference), 'Bundle abort published/wrapped a candidate');
        finally
          GObserver.AbortStage := -1;
          GObserver.Marker.Free;
          GObserver.Marker := nil;
          if LObserved <> LReference then
            LObserved.Free;
          LObserved := nil;
        end;
        GObserver.Reset(2);
        LObserved := TContextLearningBundle.Create(LEvidence, 4, 4, GObserver.ObserveLearning);
        try
          LObservedBytes := EncodeContextLearning(LObserved);
          Check((Length(LObservedBytes) = Length(LBytes)) and
            CompareMem(@LObservedBytes[0], @LBytes[0], Length(LBytes)),
            'Observed bundle archive differs');
          CheckInputs(LGrids);
        finally
          FreeAndNil(LObserved);
        end;
      end;
  finally
    LObserved.Free;
    LReference.Free;
  end;
end;
{$endif}

begin
  GObserver := TObserver.Create;
  try
    TestGrid;
    TestMalformed;
    TestLearning(cdKey);
    TestLearning(cdTempo);
    TestLarge;
    {$ifndef PAS2JS}TestBundle;{$endif}
    WriteLn('Context learning progress: ', GChecks, ' checks; ', GAborts,
      ' original abort/retries; ', GObserver.Calls, ' callbacks');
  finally
    GObserver.Free;
  end;
end.
