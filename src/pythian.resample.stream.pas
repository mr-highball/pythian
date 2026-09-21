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
unit pythian.resample.stream;

{$mode delphi}
{$H+}

interface

uses
  pythian.audio;

const
  StreamResampleVersion = 1;
  MaximumStreamKernelWeights = 65536;

type
  { Borrowed sequential input. True supplies one finite frame in Single range;
    False is permanent EOF, not temporary starvation. Mono uses Left only.
    The converter rounds accepted input to native Single PCM. }
  TPcmFrameReader = class
  strict private
    FSampleRate: Integer;
    FChannels: Integer;
  public
    constructor Create(const ASampleRate, AChannels: Integer);
    function ReadFrame(out ALeft, ARight: Double): Boolean; virtual; abstract;
    property SampleRate: Integer read FSampleRate;
    property Channels: Integer read FChannels;
  end;

  { Pulls centered-filter lookahead into a bounded ring. Output starts at source
    time zero and ends at ceil(inputFrames*outputRate/inputRate), with constant
    endpoint extension. No timestamp padding or repeated block-edge extension.
    Reader must outlive converter; both are sequential and not thread-safe.
    Repeating rational phases cache exact Double weights when the entire phase
    table fits AKernelCacheWeights (0 disables). Otherwise compute on demand.
    The cache changes storage/work only, not filter support or coefficients. }
  TSincResampleStream = class
  strict private
    FReader: TPcmFrameReader;
    FOutputRate: Integer;
    FRadius: Integer;
    FCutoff: Double;
    FHistoryFrames: Integer;
    FHistory: TAudioSamples;
    FKernelWeights: array of Double;
    FKernelSums: array of Double;
    FPhaseDivisor: Integer;
    FFirstLeft: Single;
    FFirstRight: Single;
    FLastLeft: Single;
    FLastRight: Single;
    FInputCount: Int64;
    FOutputCount: Int64;
    FCenter: Int64;
    FPhase: Integer;
    FInputEnded: Boolean;
    FCompleted: Boolean;
    FFailed: Boolean;
    FBusy: Boolean;
    function GetKernelCacheWeights: Integer;
    function GetKernelCachePhases: Integer;
    procedure FillThrough(const AFrame: Int64);
    procedure SampleAt(const AFrame: Int64; out ALeft, ARight: Double);
  public
    constructor Create(const AReader: TPcmFrameReader; const AOutputRate: Integer;
      const AKernelCacheWeights: Integer = MaximumStreamKernelWeights);
    { False means drained EOF. Failure and EOF preserve output arguments.
      Input/processing errors poison the converter because input cannot rewind. }
    function ReadFrame(var ALeft, ARight: Double): Boolean;
    { Confirmed accepted input only; a failing reader may consume more internally. }
    property InputFrameCount: Int64 read FInputCount;
    property OutputFrameCount: Int64 read FOutputCount;
    property LookaheadFrames: Integer read FRadius;
    property HistoryFrames: Integer read FHistoryFrames;
    property KernelCacheWeights: Integer read GetKernelCacheWeights;
    property KernelCachePhases: Integer read GetKernelCachePhases;
    property Completed: Boolean read FCompleted;
    property Failed: Boolean read FFailed;
  end;

{ Exact ceiling duration without multiplying a growing frame count by a rate.
  Counts are independent of clip allocation budgets; Int64 overflow rejects. }
function StreamResampleFrameCount(const AInputFrames: Int64;
  const AInputRate, AOutputRate: Integer): Int64;

implementation

uses
  Math,
  pythian.resample;

function StreamResampleFrameCount(const AInputFrames: Int64;
  const AInputRate, AOutputRate: Integer): Int64;
var
  LWhole: Int64;
  LTail: Int64;
begin
  ValidateAudioFormat(AInputRate, 1);
  ValidateAudioFormat(AOutputRate, 1);
  if AInputFrames < 0 then
  begin
    raise EAudio.Create('Streaming resample input length must be nonnegative');
  end;
  LWhole := AInputFrames div AInputRate;
  LTail := ((AInputFrames mod AInputRate) * Int64(AOutputRate) + AInputRate - 1)
    div AInputRate;
  if LWhole > (High(Int64) - LTail) div AOutputRate then
  begin
    raise EAudio.Create('Streaming resample output length exceeds Int64');
  end;
  Result := LWhole * AOutputRate + LTail;
end;

constructor TPcmFrameReader.Create(const ASampleRate, AChannels: Integer);
begin
  inherited Create;
  ValidateAudioFormat(ASampleRate, AChannels);
  FSampleRate := ASampleRate;
  FChannels := AChannels;
end;

constructor TSincResampleStream.Create(const AReader: TPcmFrameReader;
  const AOutputRate, AKernelCacheWeights: Integer);
var
  LStep: Double;
  LDivisor: Integer;
  LRemainder: Integer;
  LPhases: Integer;
  LPhase: Integer;
  LOffset: Integer;
  LBase: Integer;
  LFraction: Double;
  LWeight: Double;
  LSum: Double;
begin
  inherited Create;
  if AReader = nil then
  begin
    raise EAudio.Create('Streaming resampler requires a PCM reader');
  end;
  ValidateAudioFormat(AOutputRate, AReader.Channels);
  if (AKernelCacheWeights < 0) or (AKernelCacheWeights > MaximumStreamKernelWeights) then
  begin
    raise EAudio.Create('Streaming kernel cache exceeds weight budget');
  end;
  LStep := AReader.SampleRate / AOutputRate;
  FRadius := SincTapBudget(LStep) div 2;
  FCutoff := 0.94 / Max(1, LStep);
  if AReader.SampleRate = AOutputRate then
  begin
    FRadius := 0;
  end;
  FReader := AReader;
  FOutputRate := AOutputRate;
  FHistoryFrames := 2 * FRadius + 1;
  SetLength(FHistory, FHistoryFrames * FReader.Channels);
  if (FRadius = 0) or (AKernelCacheWeights = 0) then
  begin
    Exit;
  end;
  FPhaseDivisor := AReader.SampleRate;
  LDivisor := AOutputRate;
  while LDivisor <> 0 do
  begin
    LRemainder := FPhaseDivisor mod LDivisor;
    FPhaseDivisor := LDivisor;
    LDivisor := LRemainder;
  end;
  LPhases := AOutputRate div FPhaseDivisor;
  if Int64(LPhases) * FHistoryFrames > AKernelCacheWeights then
  begin
    Exit;
  end;
  SetLength(FKernelWeights, LPhases * FHistoryFrames);
  SetLength(FKernelSums, LPhases);
  for LPhase := 0 to LPhases - 1 do
  begin
    LFraction := (LPhase * FPhaseDivisor) / AOutputRate;
    LBase := LPhase * FHistoryFrames;
    LSum := 0;
    for LOffset := -FRadius to FRadius do
    begin
      LWeight := SincKernelWeight(LFraction - LOffset, FCutoff, FRadius);
      FKernelWeights[LBase + LOffset + FRadius] := LWeight;
      if LWeight <> 0 then
      begin
        LSum := LSum + LWeight;
      end;
    end;
    FKernelSums[LPhase] := LSum;
  end;
end;

function TSincResampleStream.GetKernelCacheWeights: Integer;
begin
  Result := Length(FKernelWeights);
end;

function TSincResampleStream.GetKernelCachePhases: Integer;
begin
  Result := Length(FKernelSums);
end;

procedure TSincResampleStream.FillThrough(const AFrame: Int64);
var
  LLeft: Double;
  LRight: Double;
  LIndex: Integer;
  LAvailable: Boolean;
begin
  while not FInputEnded and (FInputCount <= AFrame) do
  begin
    LAvailable := FReader.ReadFrame(LLeft, LRight);
    if FFailed then
    begin
      raise EAudio.Create('PCM reader attempted reentrant resampling');
    end;
    if not LAvailable then
    begin
      FInputEnded := True;
      Break;
    end;
    RequireFinite(LLeft, 'Streaming PCM left');
    if FReader.Channels = 1 then
    begin
      LRight := LLeft;
    end;
    RequireFinite(LRight, 'Streaming PCM right');
    if (Abs(LLeft) > MaxSingle) or (Abs(LRight) > MaxSingle) or
      (FInputCount = High(Int64)) then
    begin
      raise EAudio.Create('Streaming PCM sample or frame count exceeds range');
    end;
    LIndex := (FInputCount mod FHistoryFrames) * FReader.Channels;
    FLastLeft := LLeft;
    FLastRight := LRight;
    FHistory[LIndex] := FLastLeft;
    if FReader.Channels = 2 then
    begin
      FHistory[LIndex + 1] := FLastRight;
    end;
    if FInputCount = 0 then
    begin
      FFirstLeft := FLastLeft;
      FFirstRight := FLastRight;
    end;
    Inc(FInputCount);
  end;
end;

procedure TSincResampleStream.SampleAt(const AFrame: Int64; out ALeft, ARight: Double);
var
  LIndex: Integer;
begin
  if AFrame < 0 then
  begin
    ALeft := FFirstLeft;
    ARight := FFirstRight;
  end
  else if AFrame >= FInputCount then
  begin
    ALeft := FLastLeft;
    ARight := FLastRight;
  end
  else
  begin
    LIndex := (AFrame mod FHistoryFrames) * FReader.Channels;
    ALeft := FHistory[LIndex];
    if FReader.Channels = 2 then
    begin
      ARight := FHistory[LIndex + 1];
    end
    else
    begin
      ARight := ALeft;
    end;
  end;
end;

function TSincResampleStream.ReadFrame(var ALeft, ARight: Double): Boolean;
var
  LOffset: Integer;
  LPhase: Integer;
  LNextCenter: Int64;
  LFraction: Double;
  LWeight: Double;
  LSum: Double;
  LLeft: Double;
  LRight: Double;
  LSampleLeft: Double;
  LSampleRight: Double;
  LCached: Boolean;
  LBase: Integer;
begin
  if FBusy then
  begin
    FFailed := True;
    raise EAudio.Create('Streaming resampler is not reentrant');
  end;
  if FFailed then
  begin
    raise EAudio.Create('Streaming resampler failed; create a new input pipeline');
  end;
  if FCompleted then
  begin
    Exit(False);
  end;
  FBusy := True;
  try
    try
      if FCenter > High(Int64) - FRadius - MaximumSourceStep then
      begin
        raise EAudio.Create('Streaming resampler source position exceeds integer range');
      end;
      FillThrough(FCenter + FRadius);
      if FInputEnded and (FCenter >= FInputCount) then
      begin
        FCompleted := True;
        Exit(False);
      end;
      if FOutputCount = High(Int64) then
      begin
        raise EAudio.Create('Streaming resampler output count exceeds integer range');
      end;
      if FRadius = 0 then
      begin
        SampleAt(FCenter, LLeft, LRight);
      end
      else
      begin
        LFraction := FPhase / FOutputRate;
        LSum := 0;
        LBase := 0;
        LCached := Length(FKernelSums) > 0;
        if LCached then
        begin
          LBase := (FPhase div FPhaseDivisor) * FHistoryFrames;
          LSum := FKernelSums[FPhase div FPhaseDivisor];
        end;
        LLeft := 0;
        LRight := 0;
        for LOffset := -FRadius to FRadius do
        begin
          if LCached then
          begin
            LWeight := FKernelWeights[LBase + LOffset + FRadius];
          end
          else
          begin
            LWeight := SincKernelWeight(LFraction - LOffset, FCutoff, FRadius);
          end;
          if LWeight = 0 then
          begin
            Continue;
          end;
          SampleAt(FCenter + LOffset, LSampleLeft, LSampleRight);
          if not LCached then
          begin
            LSum := LSum + LWeight;
          end;
          LLeft := LLeft + LWeight * LSampleLeft;
          LRight := LRight + LWeight * LSampleRight;
        end;
        LLeft := LLeft / LSum;
        LRight := LRight / LSum;
      end;
      RequireFinite(LLeft, 'Resampled stream left');
      RequireFinite(LRight, 'Resampled stream right');
      if (Abs(LLeft) > MaxSingle) or (Abs(LRight) > MaxSingle) then
      begin
        raise EAudio.Create('Resampled stream exceeds Single range');
      end;
      { Only bounded phase arithmetic uses division; total position never
        enters floating point or multiplies a growing count by sample rate. }
      LPhase := FPhase + FReader.SampleRate;
      LNextCenter := FCenter + LPhase div FOutputRate;
      FPhase := LPhase mod FOutputRate;
      FCenter := LNextCenter;
      Inc(FOutputCount);
      ALeft := LLeft;
      ARight := LRight;
      Result := True;
    except
      FFailed := True;
      raise;
    end;
  finally
    FBusy := False;
  end;
end;

end.
