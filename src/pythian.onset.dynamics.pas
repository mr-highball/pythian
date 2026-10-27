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

unit pythian.onset.dynamics;

{$mode delphi}
{$H+}

interface

uses
  pythian.audio,
  pythian.progress,
  pythian.passage,
  pythian.rhythm.admission;

const
  OnsetDynamicsVersion = 1;
  MaximumDynamicsSamples = 16777216;

type
  TOnsetRmsValues = array of Double;
  TOnsetDynamics = record
    WindowFrames: Integer; { Zero means unavailable, with an empty Rms array. }
    Rms: TOnsetRmsValues;
  end;

procedure ValidateOnsetDynamics(const AData: TOnsetDynamics;
  const AOnsetCount, AChannels: Integer;
  const AProgress: TWorkProgressCallback = nil);
{ Forward source windows, shortened at EOF; stereo energy is averaged before
  the square root, without phase-cancelling downmix. No loudness/voice inference. }
function MeasureOnsetDynamics(const AClip: TAudioClip; const AFrames: TPassageBounds;
  const AWindowFrames: Integer;
  const AProgress: TWorkProgressCallback = nil): TOnsetDynamics;
{ Relative to the maximum RMS among accepted onsets, four equal amplitude bands.
  0 = no admitted onset; 1..4 = onset intensity. Zero RMS uses the lowest band.
  All-zero admitted evidence rejects. No rejected onset sets the reference. }
function OnsetIntensityPattern(const AAdmission: TRhythmAdmission;
  const AData: TOnsetDynamics;
  const AProgress: TWorkProgressCallback = nil): String;
{ Explicit realization policy, not recovered MIDI velocity: scale an authored
  velocity by band / 4, rounded down, with a minimum nonzero attack velocity. }
function IntensityVelocity(const AVelocity, ABand: Integer): Integer;

implementation

uses
  Math;

procedure ObserveDynamics(const AProgress: TWorkProgressCallback;
  const AStage: String; const ADone, ATotal: Integer);
begin
  if Assigned(AProgress) and ((ADone = 0) or (ADone = ATotal) or
    ((ADone mod 256) = 0)) then
  begin
    ReportWork(AProgress, AStage, wuItems, ADone, ATotal);
  end;
end;

procedure ValidateOnsetDynamics(const AData: TOnsetDynamics;
  const AOnsetCount, AChannels: Integer;
  const AProgress: TWorkProgressCallback);
var
  LValue: Double;
  LVisited: Integer;
begin
  if (AOnsetCount < 0) or (AOnsetCount > 65536) or
    not (AChannels in [1, 2]) then
  begin
    raise EAudio.Create('Onset dynamics geometry exceeds bounds');
  end;
  if AData.WindowFrames = 0 then
  begin
    if Length(AData.Rms) <> 0 then
    begin
      raise EAudio.Create('Unavailable dynamics must not contain measurements');
    end;
    Exit;
  end;
  if (AData.WindowFrames < 1) or (AData.WindowFrames > 65536) or
    (Length(AData.Rms) <> AOnsetCount) or
    (Int64(AOnsetCount) * AData.WindowFrames * AChannels > MaximumDynamicsSamples) then
  begin
    raise EAudio.Create('Onset dynamics count/window/work exceeds bounds');
  end;
  LVisited := 0;
  ObserveDynamics(AProgress, 'dynamics_validate_values', 0, Length(AData.Rms));
  for LValue in AData.Rms do
  begin
    RequireFinite(LValue, 'Onset RMS');
    if (LValue < 0) or (LValue > 3.4028234663852886e38) then
    begin
      raise EAudio.Create('Onset RMS outside finite source sample range');
    end;
    Inc(LVisited);
    ObserveDynamics(AProgress, 'dynamics_validate_values', LVisited, Length(AData.Rms));
  end;
end;

function MeasureOnsetDynamics(const AClip: TAudioClip; const AFrames: TPassageBounds;
  const AWindowFrames: Integer;
  const AProgress: TWorkProgressCallback): TOnsetDynamics;
var
  LResult: TOnsetDynamics;
  LIndex: Integer;
  LFrame: Integer;
  LChannel: Integer;
  LCount: Integer;
  LSum: Double;
  LSample: Double;
  LFramesTotal: Int64;
  LFramesDone: Int64;
begin
  if (AClip = nil) or (AWindowFrames < 1) or (Length(AFrames) > 65536) then
  begin
    raise EAudio.Create('Onset dynamics requires a clip and bounded nonzero window');
  end;
  LResult := Default(TOnsetDynamics);
  LResult.WindowFrames := AWindowFrames;
  SetLength(LResult.Rms, Length(AFrames));
  ValidateOnsetDynamics(LResult, Length(AFrames), AClip.Channels, AProgress);
  LFramesTotal := 0;
  ObserveDynamics(AProgress, 'dynamics_validate_onsets', 0, Length(AFrames));
  for LIndex := 0 to High(AFrames) do
  begin
    if (AFrames[LIndex] < 0) or (AFrames[LIndex] >= AClip.FrameCount) or
      ((LIndex > 0) and (AFrames[LIndex] <= AFrames[LIndex - 1])) then
    begin
      raise EAudio.Create('Dynamics onset frames must be strictly ordered within source');
    end;
    Inc(LFramesTotal, Min(AWindowFrames, AClip.FrameCount - AFrames[LIndex]));
    ObserveDynamics(AProgress, 'dynamics_validate_onsets', LIndex + 1, Length(AFrames));
  end;
  LFramesDone := 0;
  ReportWork(AProgress, 'dynamics_window_frames', wuFrames, 0, LFramesTotal);
  ObserveDynamics(AProgress, 'dynamics_windows', 0, Length(AFrames));
  for LIndex := 0 to High(AFrames) do
  begin
    LCount := Min(AWindowFrames, AClip.FrameCount - AFrames[LIndex]);
    LSum := 0;
    for LFrame := AFrames[LIndex] to AFrames[LIndex] + LCount - 1 do
    begin
      for LChannel := 0 to AClip.Channels - 1 do
      begin
        LSample := AClip.SampleAt(LFrame, LChannel);
        LSum := LSum + LSample * LSample;
      end;
      Inc(LFramesDone);
      if Assigned(AProgress) and ((LFramesDone mod 1024) = 0) then
      begin
        ReportWork(AProgress, 'dynamics_window_frames', wuFrames, LFramesDone, LFramesTotal);
      end;
    end;
    LResult.Rms[LIndex] := Sqrt(LSum / (LCount * AClip.Channels));
    ObserveDynamics(AProgress, 'dynamics_windows', LIndex + 1, Length(AFrames));
  end;
  ReportWork(AProgress, 'dynamics_window_frames', wuFrames, LFramesDone, LFramesTotal);
  Result := LResult;
end;

function OnsetIntensityPattern(const AAdmission: TRhythmAdmission;
  const AData: TOnsetDynamics;
  const AProgress: TWorkProgressCallback): String;
var
  LReference: Double;
  LIndex: Integer;
  LCell: Integer;
  LBand: Integer;
  LPattern: String;
begin
  ValidateOnsetDynamics(AData, Length(AAdmission.Decisions), 1, AProgress);
  if (AData.WindowFrames = 0) or
    (Length(AAdmission.Cells) <> Length(AAdmission.Decisions)) or
    (Length(AAdmission.Pattern) < 1) or (Length(AAdmission.Pattern) > 65536) then
  begin
    raise EAudio.Create('Intensity projection requires measured, aligned admission');
  end;
  LReference := 0;
  ObserveDynamics(AProgress, 'dynamics_reference', 0, Length(AAdmission.Decisions));
  for LIndex := 0 to High(AAdmission.Decisions) do
  begin
    if AAdmission.Decisions[LIndex] = rodAccepted then
    begin
      LReference := Max(LReference, AData.Rms[LIndex]);
    end;
    ObserveDynamics(AProgress, 'dynamics_reference', LIndex + 1,
      Length(AAdmission.Decisions));
  end;
  if LReference = 0 then
  begin
    raise EAudio.Create('Accepted onsets have no nonzero intensity reference');
  end;
  LPattern := StringOfChar('0', Length(AAdmission.Pattern));
  ObserveDynamics(AProgress, 'dynamics_projection', 0, Length(AAdmission.Decisions));
  for LIndex := 0 to High(AAdmission.Decisions) do
  begin
    ObserveDynamics(AProgress, 'dynamics_projection', LIndex, Length(AAdmission.Decisions));
    if AAdmission.Decisions[LIndex] <> rodAccepted then
    begin
      Continue;
    end;
    LCell := AAdmission.Cells[LIndex];
    if (LCell < 0) or (LCell >= Length(LPattern)) or (LPattern[LCell + 1] <> '0') or
      (AAdmission.Pattern[LCell + 1] <> 'x') then
    begin
      raise EAudio.Create('Intensity admission contains an invalid or duplicate accepted cell');
    end;
    LBand := 1;
    while (LBand < 4) and (AData.Rms[LIndex] / LReference > LBand / 4) do
    begin
      Inc(LBand);
    end;
    LPattern[LCell + 1] := Chr(Ord('0') + LBand);
  end;
  ObserveDynamics(AProgress, 'dynamics_projection', Length(AAdmission.Decisions),
    Length(AAdmission.Decisions));
  ObserveDynamics(AProgress, 'dynamics_projection_cells', 0, Length(LPattern));
  for LCell := 1 to Length(LPattern) do
  begin
    if ((AAdmission.Pattern[LCell] = 'x') <> (LPattern[LCell] <> '0')) or
      not (AAdmission.Pattern[LCell] in ['x', '.']) then
    begin
      raise EAudio.Create('Intensity projection disagrees with admitted onset pattern');
    end;
    ObserveDynamics(AProgress, 'dynamics_projection_cells', LCell, Length(LPattern));
  end;
  Result := LPattern;
end;

function IntensityVelocity(const AVelocity, ABand: Integer): Integer;
begin
  if (AVelocity < 1) or (AVelocity > 127) or (ABand < 1) or (ABand > 4) then
  begin
    raise EAudio.Create('Intensity realization requires velocity 1..127 and band 1..4');
  end;
  Result := Max(1, AVelocity * ABand div 4);
end;

end.
