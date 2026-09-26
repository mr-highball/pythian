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
unit pythian.tools.cues;

{$mode delphi}
{$H+}

interface

uses
  fpjson,
  pythian.audio;

type
  TCueFrames = array of Integer;

{ Source audio with bounded decaying sine markers, preserving format/duration.
  Adds exact output identity and gain settings to the borrowed JSON document. }
procedure WriteCueAudition(const AClip: TAudioClip; const AFrames: TCueFrames;
  const AFileName, AInterpretation: String; const ADocument: TJSONObject);

implementation

uses
  SysUtils,
  Math,
  pythian.wave,
  pythian.oscillator,
  pythian.tools.files;

procedure WriteCueAudition(const AClip: TAudioClip; const AFrames: TCueFrames;
  const AFileName, AInterpretation: String; const ADocument: TJSONObject);
var
  LCues: TAudioSamples;
  LSamples: TAudioSamples;
  LSignal: TOscillator;
  LOutput: TAudioClip;
  LBytes: TAudioBytes;
  LIndex: Integer;
  LFrame: Integer;
  LChannel: Integer;
  LOffset: Integer;
  LLength: Integer;
  LFrequency: Double;
  LSourcePeak: Double;
  LCuePeak: Double;
  LSourceGain: Double;
  LCueGain: Double;
  LSettings: TJSONObject;
begin
  LSignal := nil;
  LOutput := nil;
  try
    if not Assigned(AClip) or not Assigned(ADocument) or (Length(AFrames) > 65536) then
    begin
      raise EAudio.Create('Cue audition requires a clip, document and at most 65536 cues');
    end;
    for LIndex := 0 to High(AFrames) do
    begin
      if (AFrames[LIndex] < 0) or (AFrames[LIndex] >= AClip.FrameCount) then
      begin
        raise EAudio.Create('Cue lies outside its source clip');
      end;
    end;
    if Int64(Length(AFrames)) * Max(1, AClip.SampleRate div 125) > 100000000 then
    begin
      raise EAudio.Create('Cue audition exceeds rendering work budget');
    end;
    SetLength(LCues, AClip.FrameCount);
    LLength := Max(1, AClip.SampleRate div 125);
    LFrequency := Min(2000, AClip.SampleRate / 8);
    LSignal := TOscillator.Create(AClip.SampleRate, 731);
    for LIndex := 0 to High(AFrames) do
    begin
      LSignal.Reset(731);
      for LOffset := 0 to Min(LLength, AClip.FrameCount - AFrames[LIndex]) - 1 do
      begin
        LFrame := AFrames[LIndex] + LOffset;
        LCues[LFrame] := LCues[LFrame] +
          LSignal.Next(wsSine, LFrequency) * (1 - LOffset / LLength);
      end;
    end;
    LSamples := AClip.CopySamples;
    LSourcePeak := 0;
    for LIndex := 0 to High(LSamples) do
    begin
      LSourcePeak := Max(LSourcePeak, Abs(LSamples[LIndex]));
    end;
    LCuePeak := 0;
    for LFrame := 0 to High(LCues) do
    begin
      LCuePeak := Max(LCuePeak, Abs(LCues[LFrame]));
    end;
    LSourceGain := 0.7 / Max(1, LSourcePeak);
    LCueGain := 0.25 / Max(1, LCuePeak);
    for LFrame := 0 to AClip.FrameCount - 1 do
    begin
      for LChannel := 0 to AClip.Channels - 1 do
      begin
        LIndex := LFrame * AClip.Channels + LChannel;
        LSamples[LIndex] := LSamples[LIndex] * LSourceGain + LCues[LFrame] * LCueGain;
      end;
    end;
    LOutput := TAudioClip.Create(AClip.SampleRate, AClip.Channels, LSamples);
    LBytes := EncodeWavePcm16(LOutput);
    LSettings := TJSONObject.Create;
    ADocument.Add('audition', LSettings);
    LSettings.Add('file', ExtractFileName(AFileName));
    LSettings.Add('sha256', HashAudioBytes(LBytes));
    LSettings.Add('cue_frames', LLength);
    LSettings.Add('cue_frequency_hz', LFrequency);
    LSettings.Add('source_gain', LSourceGain);
    LSettings.Add('cue_gain', LCueGain);
    LSettings.Add('interpretation', AInterpretation);
    WriteFileBytes(AFileName, LBytes);
  finally
    LOutput.Free;
    LSignal.Free;
  end;
end;

end.

