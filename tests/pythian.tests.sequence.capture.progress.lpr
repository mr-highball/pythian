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
program pythian_tests_sequence_capture_progress;

{$mode delphi}{$H+}

uses SysUtils, pythian.progress, pythian.learning, pythian.wfc.learning,
  pythian.wfc.generation, wfc, wfc_model, wfc_sequence, wfc_sequence_learn,
  wfc_sequence_text;

const
  CStages: array[0..11] of String = ('wfc_sequence_model_rows',
    'wfc_sequence_capture_cells', 'wfc_sequence_path_states',
    'wfc_sequence_path_transitions', 'wfc_sequence_projection_states',
    'wfc_sequence_project_tokens', 'wfc_sequence_capture_ready',
    'wfc_sequence_entry_cells', 'sequence_publication_ready',
    'acoustic_validate_tokens', 'acoustic_project_tokens', 'acoustic_publication_ready');

type
  TObserver = class
  public
    Stage: String;
    Mode: Integer;
    Enabled: Boolean;
    Marker: Exception;
    Calls: Integer;
    procedure Observe(const AWork: TWorkProgress);
  end;

var
  GChecks: Integer;
  GAborts: Integer;

procedure Check(const AValue: Boolean; const AMessage: String);
begin
  Inc(GChecks);
  if not AValue then
    raise Exception.Create(AMessage);
end;

procedure TObserver.Observe(const AWork: TWorkProgress);
var
  LPoint: Boolean;
begin
  Inc(Calls);
  Check((AWork.Units = wuItems) and (AWork.Done >= 0) and
    ((AWork.Total = 0) or (AWork.Done <= AWork.Total)), 'Invalid forwarded phase count');
  LPoint := ((Mode = 0) and (AWork.Done = 0)) or
    ((Mode = 1) and (AWork.Done > 0) and (AWork.Done < AWork.Total)) or
    ((Mode = 2) and (AWork.Total > 0) and (AWork.Done = AWork.Total));
  if Enabled and (AWork.Stage = Stage) and LPoint then
    raise Marker;
end;

function AuthoredModel: TWfcSequenceModel;
begin
  Result := LearnSequenceModelCorpus([MakeWfcSequenceSample([
    AcousticToken(0), AcousticToken(0), AcousticToken(1), AcousticToken(1),
    AcousticToken(2), AcousticToken(2), AcousticToken(0), AcousticToken(1),
    AcousticToken(2), AcousticToken(0)])], 2);
end;

procedure Same(const AExpected, AActual: TWfcModelTokens;
  const AExpectedIndices, AActualIndices: TAcousticIndices);
var
  LIndex: Integer;
begin
  Check((Length(AExpected) = Length(AActual)) and
    (Length(AExpectedIndices) = Length(AActualIndices)), 'Finite replay length differs');
  for LIndex := 0 to High(AExpected) do
    Check(AExpected[LIndex] = AActual[LIndex], 'Finite token replay differs');
  for LIndex := 0 to High(AExpectedIndices) do
    Check(AExpectedIndices[LIndex] = AActualIndices[LIndex], 'Finite acoustic replay differs');
end;

procedure RunTranscript;
var
  LModel: TWfcSequenceModel;
  LOptions: TAcousticGenerationOptions;
  LTokens: TWfcModelTokens;
  LIndices: TAcousticIndices;
  LReport: TGraphSolveReport;
  LSeed: Integer;
  LIndex: Integer;
begin
  LModel := AuthoredModel;
  try
    LOptions := DefaultAcousticGenerationOptions;
    LOptions.FrameCount := 128;
    LOptions.Extent := wseWrap;
    for LSeed := 0 to 2 do
    begin
      LOptions.Seed := 731 + LSeed * 1000;
      Check(TryGenerateTokenSequence(LModel, LOptions, nil, LTokens, LReport), 'Transcript tokens failed');
      Check(TryGenerateAcousticSequence(LModel, LOptions, nil, LIndices, LReport), 'Transcript indices failed');
      WriteLn('seed=', LOptions.Seed, ' count=', Length(LTokens));
      for LIndex := 0 to High(LTokens) do
      begin
        Check(AcousticTokenIndex(LTokens[LIndex]) = LIndices[LIndex], 'Token/index projection differs');
        WriteLn(LIndex, ':', LTokens[LIndex], ':', LIndices[LIndex]);
      end;
    end;
  finally
    LModel.Free;
  end;
end;

procedure RunCancellation;
var
  LModel: TWfcSequenceModel;
  LOptions: TAcousticGenerationOptions;
  LExpected: TWfcModelTokens;
  LExpectedIndices: TAcousticIndices;
  LTokens: TWfcModelTokens;
  LIndices: TAcousticIndices;
  LReport: TGraphSolveReport;
  LObserver: TObserver;
  LOperation: Integer;
  LMode: Integer;
  LStage: String;
  LAborted: Boolean;
  LBefore: String;
begin
  LModel := AuthoredModel;
  LObserver := TObserver.Create;
  try
    LBefore := EncodeWfcSequenceText(LModel);
    LOptions := DefaultAcousticGenerationOptions;
    LOptions.FrameCount := 128;
    LOptions.Extent := wseWrap;
    Check(TryGenerateTokenSequence(LModel, LOptions, nil, LExpected, LReport), 'Token control failed');
    Check(TryGenerateAcousticSequence(LModel, LOptions, nil, LExpectedIndices, LReport), 'Index control failed');
    for LOperation := 0 to 1 do
      for LStage in CStages do
      begin
        if (LOperation = 0) and (Copy(LStage, 1, 9) = 'acoustic_') then
          Continue;
        for LMode := 0 to 2 do
        begin
          if ((Pos('ready', LStage) > 0) and (LMode <> 2)) or
            ((LStage = 'acoustic_validate_tokens') and (LMode = 1)) then
            Continue;
          LTokens := ['retained tokens'];
          LIndices := [19];
          LObserver.Stage := LStage;
          LObserver.Mode := LMode;
          LObserver.Enabled := True;
          LObserver.Marker := Exception.Create('Big Boss original finite capture marker');
          LAborted := False;
          try
            try
              if LOperation = 0 then
                TryGenerateTokenSequence(LModel, LOptions, nil, LTokens, LReport, LObserver.Observe)
              else
                TryGenerateAcousticSequence(LModel, LOptions, nil, LIndices, LReport, LObserver.Observe);
            except
              on LError: Exception do
              begin
                Check(LError = LObserver.Marker, 'Finite original observer exception changed');
                LObserver.Marker := nil;
                LAborted := True;
                Inc(GAborts);
              end;
            end;
          finally
            LObserver.Marker.Free;
            LObserver.Marker := nil;
            LObserver.Enabled := False;
          end;
          Check(LAborted, 'Finite abort not reached: ' + LStage + '/' + IntToStr(LMode));
          Check((Length(LTokens) = 1) and (LTokens[0] = 'retained tokens') and
            (Length(LIndices) = 1) and (LIndices[0] = 19), 'Finite abort published output');
          Check(TryGenerateTokenSequence(LModel, LOptions, nil, LTokens, LReport,
            LObserver.Observe), 'Observed token retry failed');
          Check(TryGenerateAcousticSequence(LModel, LOptions, nil, LIndices, LReport,
            LObserver.Observe), 'Observed index retry failed');
          Same(LExpected, LTokens, LExpectedIndices, LIndices);
          Check(EncodeWfcSequenceText(LModel) = LBefore, 'Finite observer changed borrowed model');
        end;
      end;
    Check(GAborts = 52, 'Finite abort matrix is incomplete');
    LObserver.Free;
    LObserver := nil;
    Check(TryGenerateTokenSequence(LModel, LOptions, nil, LTokens, LReport), 'Borrowed observer retained');
    Same(LExpected, LTokens, LExpectedIndices, LIndices);
    WriteLn('Finite capture: ', GChecks, ' checks; ', GAborts, ' original aborts; exact retry');
  finally
    LObserver.Free;
    LModel.Free;
  end;
end;

begin
  {$ifdef REPLAY_ONLY}
  RunTranscript;
  {$else}
  RunCancellation;
  {$endif}
end.
