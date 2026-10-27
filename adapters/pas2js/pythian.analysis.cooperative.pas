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
unit pythian.analysis.cooperative;

{$mode delphi}
{$H+}

interface

uses
  JS,
  pythian.analysis,
  pythian.analysis.wave,
  pythian.wave.read;

type
  TCooperativeAnalysisState = (casIdle, casRunning, casCompleted, casCancelled,
    casFailed);
  TAnalysisBatchCallback = procedure(const ABatch: TWaveFeatureBatch) of object;
  TAnalysisFinishedCallback = procedure(const AState: TCooperativeAnalysisState;
    const AError: String) of object;

  { pas2js host adapter: one bounded primary analysis batch per timer turn.
    Borrows an immutable reader/source until terminal notification or destruction.
    Does not retain emitted batches. The host stages/publishes results and owns
    durable checkpoints. Callback exceptions fail the job; no further batch runs.
    A terminal callback exception also propagates to the host after recording
    failure; it never causes a second terminal notification.
    Only Cancel may re-enter from callbacks; do not free the job in a callback.
    Destruction clears its pending timer. Cancel is observed between batches;
    an individual FFT batch is synchronous, with no promised millisecond bound.
    This does not make other bulk APIs asynchronous or survive page suspension. }
  TCooperativeWaveAnalysis = class
  private
    FReader: TWaveFrameReader;
    FOptions: TAnalysisOptions;
    FMaximumFeatures: Integer;
    FNextFeature: Int64;
    FState: TCooperativeAnalysisState;
    FCancel: Boolean;
    FTimer: JSValue;
    FPending: Boolean;
    FError: String;
    FOnBatch: TAnalysisBatchCallback;
    FOnFinished: TAnalysisFinishedCallback;
    procedure QueueTurn;
    procedure RunTurn;
  public
    constructor Create(const AReader: TWaveFrameReader;
      const AOptions: TAnalysisOptions; const AMaximumFeatures: Integer;
      const AOnBatch: TAnalysisBatchCallback;
      const AOnFinished: TAnalysisFinishedCallback);
    destructor Destroy; override;
    { One start per instance. The first batch is deferred, including empty input. }
    procedure Start;
    procedure Cancel;
    property State: TCooperativeAnalysisState read FState;
    { Advances only after the host's batch callback returns successfully. }
    property NextFeature: Int64 read FNextFeature;
    property ErrorMessage: String read FError;
  end;

implementation

uses
  SysUtils,
  pythian.audio;

type
  TDeferredCallback = procedure of object;

function Defer(const ACallback: TDeferredCallback; const ADelay: Integer): JSValue;
  external name 'setTimeout';
procedure ClearDeferred(const ATimer: JSValue); external name 'clearTimeout';

constructor TCooperativeWaveAnalysis.Create(const AReader: TWaveFrameReader;
  const AOptions: TAnalysisOptions; const AMaximumFeatures: Integer;
  const AOnBatch: TAnalysisBatchCallback;
  const AOnFinished: TAnalysisFinishedCallback);
var
  LFeatures: Integer;
  LWork: Int64;
begin
  inherited Create;
  if (AReader = nil) or not Assigned(AOnBatch) or not Assigned(AOnFinished) then
  begin
    raise EAudio.Create('Cooperative analysis requires reader and callbacks');
  end;
  if AReader.Failed or (AMaximumFeatures < 1) or (AMaximumFeatures > 64) then
  begin
    raise EAudio.Create('Cooperative analysis batch must contain 1..64 features');
  end;
  PlanAudioAnalysis(0, AReader.Channels, AOptions, LFeatures, LWork);
  FReader := AReader;
  FOptions := AOptions;
  FMaximumFeatures := AMaximumFeatures;
  FOnBatch := AOnBatch;
  FOnFinished := AOnFinished;
end;

destructor TCooperativeWaveAnalysis.Destroy;
begin
  if FPending then
  begin
    ClearDeferred(FTimer);
  end;
  inherited Destroy;
end;

procedure TCooperativeWaveAnalysis.QueueTurn;
begin
  FTimer := Defer(RunTurn, 0);
  FPending := True;
end;

procedure TCooperativeWaveAnalysis.Start;
begin
  if FState <> casIdle then
  begin
    raise EAudio.Create('Cooperative analysis already started');
  end;
  FState := casRunning;
  try
    QueueTurn;
  except
    on E: Exception do
    begin
      FState := casFailed;
      FError := E.Message;
      raise;
    end;
  end;
end;

procedure TCooperativeWaveAnalysis.Cancel;
begin
  if FState = casRunning then
  begin
    FCancel := True;
  end;
end;

procedure TCooperativeWaveAnalysis.RunTurn;
var
  LBatch: TWaveFeatureBatch;
begin
  FPending := False;
  try
    if FCancel then
    begin
      FState := casCancelled;
    end
    else
    begin
      LBatch := AnalyzeWaveBatch(FReader, FOptions, FNextFeature, FMaximumFeatures);
      FOnBatch(LBatch);
      FNextFeature := LBatch.NextFeature;
      if FCancel then
      begin
        FState := casCancelled;
      end
      else if LBatch.Completed then
      begin
        FState := casCompleted;
      end
      else
      begin
        QueueTurn;
      end;
    end;
  except
    on E: Exception do
    begin
      FState := casFailed;
      FError := E.Message;
    end;
  end;
  if FState <> casRunning then
  begin
    try
      FOnFinished(FState, FError);
    except
      on E: Exception do
      begin
        FState := casFailed;
        FError := E.Message;
        raise;
      end;
    end;
  end;
end;

end.
