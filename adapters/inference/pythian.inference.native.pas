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
unit pythian.inference.native;

{$mode delphi}
{$H+}

interface

uses
  pythian.audio,
  pythian.inference.observation;

const
  NativeInferenceEstimator = InferenceEstimator;
  NativeInferenceMinimumLag = 7;
  NativeInferenceMaximumLag = 512;
  NativeInferenceSilenceRms = 1.0E-8;

type
  { Bounded normalized periodic support. Values are neither probabilities nor
    admitted notes; multiple bins may support the same periodic signal. }
  TNativeInferenceBackend = class(TInferenceBackend)
  public
    function Activate(const AWindow: TAudioSamples): TPitchSalience; override;
    function EstimatorIdentity: String; override;
  end;

{ Bin zero is MIDI 24; each of the 360 bins advances by 0.2 semitones.
  The covered centers are MIDI 24 through MIDI 95.8 inclusive. }
function NativeInferenceBinFrequencyHz(const AIndex: Integer): Double;

implementation

uses
  Math,
  SysUtils;

const
  CWindowFrames = 1024;
  CBinsPerSemitone = 5;
  CFirstMidiNote = 24;

function NativeInferenceBinFrequencyHz(const AIndex: Integer): Double;
var
  LMidiNote: Double;
begin
  if (AIndex < Low(TPitchSalience)) or (AIndex > High(TPitchSalience)) then
  begin
    raise EAudio.Create('Native inference bin is outside 0..359');
  end;
  LMidiNote := CFirstMidiNote + AIndex / CBinsPerSemitone;
  Result := 440.0 * Power(2.0, (LMidiNote - 69.0) / 12.0);
end;

function TNativeInferenceBackend.EstimatorIdentity: String;
begin
  Result := NativeInferenceEstimator;
end;

function TNativeInferenceBackend.Activate(
  const AWindow: TAudioSamples): TPitchSalience;
var
  LCentered: array[0..CWindowFrames - 1] of Double;
  LPrefixEnergy: array[0..CWindowFrames] of Double;
  LCorrelation: array[0..NativeInferenceMaximumLag] of Double;
  LMean: Double;
  LTotalEnergy: Double;
  LLeftEnergy: Double;
  LRightEnergy: Double;
  LDot: Double;
  LNorm: Double;
  LScore: Double;
  LFrequency: Double;
  LLag: Double;
  LFraction: Double;
  LValue: Single;
  LSample: Integer;
  LLagIndex: Integer;
  LBaseLag: Integer;
  LBin: Integer;
begin
  if Length(AWindow) <> CWindowFrames then
  begin
    raise EAudio.Create('Native inference requires exactly 1024 samples');
  end;

  LMean := 0;
  for LSample := 0 to CWindowFrames - 1 do
  begin
    LValue := AWindow[LSample];
    RequireFinite(LValue, 'Native inference sample');
    LMean := LMean + LValue;
  end;
  LMean := LMean / CWindowFrames;

  LPrefixEnergy[0] := 0;
  for LSample := 0 to CWindowFrames - 1 do
  begin
    LCentered[LSample] := AWindow[LSample] - LMean;
    LPrefixEnergy[LSample + 1] := LPrefixEnergy[LSample] +
      Sqr(LCentered[LSample]);
  end;
  LTotalEnergy := LPrefixEnergy[CWindowFrames];
  if LTotalEnergy <= CWindowFrames * Sqr(NativeInferenceSilenceRms) then
  begin
    Result := Default(TPitchSalience);
    Exit;
  end;

  { One bounded shared autocorrelation pass covers all possible bin lags.
    Prefix energy supplies both overlap norms without rescanning each bin. }
  for LLagIndex := NativeInferenceMinimumLag to NativeInferenceMaximumLag do
  begin
    LDot := 0;
    for LSample := 0 to CWindowFrames - LLagIndex - 1 do
    begin
      LDot := LDot + LCentered[LSample] * LCentered[LSample + LLagIndex];
    end;
    LLeftEnergy := LPrefixEnergy[CWindowFrames - LLagIndex];
    LRightEnergy := LTotalEnergy - LPrefixEnergy[LLagIndex];
    if (LLeftEnergy <= 0) or (LRightEnergy <= 0) then
    begin
      LCorrelation[LLagIndex] := 0;
    end
    else
    begin
      LNorm := Sqrt(LLeftEnergy * LRightEnergy);
      LCorrelation[LLagIndex] := LDot / LNorm;
      if LCorrelation[LLagIndex] < -1 then
      begin
        LCorrelation[LLagIndex] := -1;
      end
      else if LCorrelation[LLagIndex] > 1 then
      begin
        LCorrelation[LLagIndex] := 1;
      end;
    end;
  end;

  for LBin := Low(Result) to High(Result) do
  begin
    LFrequency := NativeInferenceBinFrequencyHz(LBin);
    LLag := InferenceRate / LFrequency;
    LBaseLag := Trunc(LLag);
    LFraction := LLag - LBaseLag;
    { Magnitude also retains anti-periodic half-cycle support, exposing octave
      alternatives instead of silently choosing one interpretation. }
    LScore := Abs(LCorrelation[LBaseLag] * (1 - LFraction) +
      LCorrelation[LBaseLag + 1] * LFraction);
    if LScore < 0 then
    begin
      LScore := 0;
    end
    else if LScore > 1 then
    begin
      LScore := 1;
    end;
    Result[LBin] := LScore;
  end;
end;

end.
